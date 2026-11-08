--[[
  Lot TRANCHES-FOREUSES (8/11) : le tracé du tapis des foreuses (Build.plan_drills, script/team/build.lua) se calcule PAR TRANCHES.
  Cause : depuis la 0.6.72 l'essai PONDÉRÉ a son propre budget (la boîte entière, jusqu'à 14 400 états) ; mesuré hors jeu en instructions
  (debug.sethook) : jusqu'à 11 400 états, environ 10 millions d'instructions, 90 ms d'un seul tenant quand l'arrivée est murée, 26 à 31 ms
  quand le tracé traverse un gisement ; et les deux essais EXACTS qui le précèdent, budget partagé de Tv.PLAN_BUDGET (4 000) états, en
  prennent 4 à 5 millions (35 à 50 ms) dans le même appel. Le précédent est le tronc de bus (script/team/liaison.lua, Liaison.plan : p.rs, BUS_CACHE).

  Les trois essais de plan_drills (1 : exact dans la boîte des extrémités + 12 ; 2 : exact avec la marge d'un pas de treillis ; 3 : pondéré sur toute
  la boîte, seulement si le dernier essai exact a dit « trop long ») sont ici une MACHINE À ÉTATS : chaque appel (une pensée du plan) ne fait qu'UNE
  tranche d'au plus Td.SLICE états développés, puis rend « pending » ; le plan est rappelé à la pensée suivante et reprend là où il s'était arrêté.
  La règle du tracé reste shared/team/traversee.lua (Tv.route, ctx.phase_slice / ctx.phase_state : les mêmes phases, le même résultat qu'en un appel,
  tests/tranches_foreuses_test.lua) ; ce fichier ne décide de rien d'autre que l'ordre des essais, qui est celui d'avant.

  État dans global : p.rs_drills = { sig, tick, stage, n2, first, bl, st } (essai en cours : nombres, chaînes, tables de nombres, jamais une fonction ;
  ARCHITECTURE §2) et p.rs_done[sig] = { done, tiles, why, tn, first } (essai FINI : une autre voie du même module, que le plan refait de zéro à chaque
  passe, ne repaie pas le tracé d'une voie finie). Les deux sont jetés par Td.clear quand le plan finit (accepté, refusé, autre attente). Les masques
  lus au moteur restent en mémoire LOCALE (hors sauvegarde) pendant la recherche : sans eux (chargement d'une sauvegarde), ils sont relus une fois.
]]

local Tv = require("shared.team.traversee")

local Td = {}

Td.SLICE = 400        -- états développés au plus par passe (environ 900 à 1 200 instructions chacun : ~0,6 M d'instructions au pire, ~5 ms)
Td.CACHE_TTL = 3600   -- ticks de validité d'une reprise et des masques gardés en mémoire locale
Td.RESTARTS = 4       -- changements de signature tolérés pour un même projet avant de refuser le tapis (« trace instable »)
Td.MAX_BOX = 120      -- côté de boîte au plus d'un essai exact avec marge

local CACHE = {}      -- MÉMOIRE LOCALE (vide au chargement) : masques de la boîte de l'essai en cours, par projet

--- Signature de l'essai : départ s, arrivée a (avec sa direction), tapis, place de la ligne de foreuses (ox, oy, k).
function Td.sig(s, a, belt, tail_dir, place)
  return table.concat({ tostring(s.x), tostring(s.y), tostring(tail_dir), tostring(a.x), tostring(a.y), tostring(a.dir), tostring(belt),
    tostring(place.ox), tostring(place.oy), tostring(place.k) }, ":")
end

--- État de reprise pour `sig` à ce tick : l'essai FINI (p.rs_done[sig], champ done = vrai), l'essai en cours (p.rs_drills), ou nil. L'état périmé ou
--- d'une autre signature est jeté (compté dans p.rs_drills_n : Td.unstable).
function Td.resume(p, sig, tick)
  local dn = p.rs_done and p.rs_done[sig]
  if dn then return dn end
  local rs = p.rs_drills
  if not rs then return nil end
  if rs.sig == sig and tick - (rs.tick or 0) < Td.CACHE_TTL then return rs end
  p.rs_drills = nil
  CACHE[p.id] = nil
  if rs.sig ~= sig then p.rs_drills_n = (p.rs_drills_n or 0) + 1 end
  return nil
end

--- Trop de signatures changées : le tapis est refusé (une recherche qui ne reprend jamais bloquerait le projet).
function Td.unstable(p) return (p.rs_drills_n or 0) > Td.RESTARTS end

--- Fin d'un plan (accepté, refusé, ou autre attente que les tranches) : tout ce qui a été rangé dans le projet est jeté.
function Td.clear(p)
  p.rs_drills, p.rs_done, p.rs_drills_n = nil, nil, nil
  CACHE[p.id] = nil
end

--- Boîte de l'essai `stage` (1, 2 ou 3), ou nil (essai 2 sans objet : marge trop grande). e = { s, a, pitch, box1 }.
local function geometry(stage, e)
  local s, a = e.s, e.a
  if stage == 1 then return e.box1 end
  if stage == 2 then
    -- second essai, marge d'un pas de treillis (contourner une falaise par la brèche voisine ; correction du 27/10)
    local cx0, cy0 = math.min(s.x, a.x) - e.pitch, math.min(s.y, a.y) - e.pitch
    local cx1, cy1 = math.max(s.x, a.x) + e.pitch, math.max(s.y, a.y) + e.pitch
    if cx1 - cx0 <= Td.MAX_BOX and cy1 - cy0 <= Td.MAX_BOX then return { x0 = cx0, y0 = cy0, x1 = cx1, y1 = cy1 } end
    return nil
  end
  -- essai pondéré : la plus grande des deux boîtes des essais exacts qui tient dans 120 tuiles (marge d'un pas de treillis, sinon 12)
  local mg = e.pitch
  if math.max(math.abs(s.x - a.x), math.abs(s.y - a.y)) + 2 * mg > Td.MAX_BOX then mg = 12 end
  return { x0 = math.min(s.x, a.x) - mg, y0 = math.min(s.y, a.y) - mg, x1 = math.max(s.x, a.x) + mg, y1 = math.max(s.y, a.y) + mg }
end

--- Les trois essais du tapis, UNE tranche par appel. e = {
---   p, sig, tick, rsd (Td.resume), s, a, pitch, box1 ({ x0, y0, x1, y1 } du premier essai), topts (options d'un essai exact : belt, sd, kind),
---   weight, max_of(box) (plafond d'états de l'essai pondéré), read(x0, y0, x1, y1) -> masques (relevé moteur), set_masks(m),
---   route(box, opts) -> tiles, info, names | nil, raison } : set_masks pose les masques lus que lit le coût du plan.
--- Rend "pending" (la recherche continue à la pensée suivante), ou tiles, info, names, first (fini), ou nil, raison, nil, first (refus ; `first` : la
--- raison du dernier essai exact quand l'essai pondéré a eu lieu, sinon nil).
function Td.trace(e)
  local p, rs = e.p, e.rsd
  if rs and rs.done then return rs.tiles, rs.why, rs.tn, rs.first end
  local stage = rs and rs.stage or 1
  local n2, first = rs and rs.n2 or nil, rs and rs.first or nil
  local box = geometry(stage, e)
  local function finish(t, why, tn)
    p.rs_drills, p.rs_drills_n = nil, nil
    CACHE[p.id] = nil
    -- l'essai est fini (tracé ou refus) : gardé pour les replans de ce même plan (une autre voie du module en tranches), jeté par Td.clear
    p.rs_done = p.rs_done or {}
    p.rs_done[e.sig] = { done = true, tiles = t, why = (not t) and why or nil, tn = tn, first = first }
    return t, why, tn, first
  end
  if box == nil then return finish(nil, n2 or "aucun chemin", nil) end -- (défensif : l'essai 2 n'est choisi que si sa boîte existe)
  local sigk = e.sig .. "#" .. stage
  -- masques : mémoire locale pendant la recherche (une reprise ne relit pas le moteur), sinon lus
  local c = CACHE[p.id]
  local masks = (c and c.sigk == sigk and e.tick - c.tick < Td.CACHE_TTL) and c.masks or nil
  if not masks then masks = e.read(box.x0, box.y0, box.x1 + 1, box.y1 + 1) end
  e.set_masks(masks)
  -- options de l'essai : le budget d'états des essais exacts est celui du plan (PLAN_BUDGET, son reste passe de l'essai 1 au 2), la boîte entière pour
  -- l'essai pondéré (0.6.72 : budget PROPRE, il était refusé d'emblée par le budget partagé)
  local o = {}
  for k, v in pairs(e.topts) do o[k] = v end -- (copie d'un jeu d'options : l'ordre n'a aucun effet)
  if stage == 3 then
    o.weight, o.max = e.weight, e.max_of(box)
    o.budget = { left = o.max }
  else
    o.budget = { left = (rs and rs.bl) or Tv.PLAN_BUDGET }
  end
  o.no_diag = true -- pas de diagnostic de refus (remplissage de la boîte, ~2 M d'instructions d'un tenant : plus qu'une tranche) ; comme le tronc de bus
  o.phase_slice = Td.SLICE
  o.phase_state = (rs and rs.stage == stage) and rs.st or nil
  local tiles, info, names = e.route(box, o)
  if not tiles and info == "pending" then
    p.rs_drills = { sig = e.sig, tick = e.tick, stage = stage, n2 = n2, first = first, bl = rs and rs.bl or nil, st = names }
    CACHE[p.id] = { sigk = sigk, tick = e.tick, masks = masks }
    return "pending"
  end
  CACHE[p.id] = nil
  if tiles then return finish(tiles, nil, names) end
  -- refus de cet essai : le suivant (ordre d'avant : 1, 2 si sa boîte tient, 3 seulement si le dernier essai exact a dit « trop long »)
  n2 = info
  local nxt
  if stage == 1 then
    nxt = geometry(2, e) and 2 or (n2 == "trop long" and 3 or nil)
  elseif stage == 2 then
    nxt = n2 == "trop long" and 3 or nil
  end
  if not nxt then return finish(nil, n2, nil) end
  p.rs_drills = { sig = e.sig, tick = e.tick, stage = nxt, n2 = n2, first = (nxt == 3) and n2 or nil, bl = o.budget.left, st = nil }
  return "pending"
end

--- Chargement d'une sauvegarde simulé (tests) : la mémoire locale est perdue.
function Td.forget() CACHE = {} end

--- Instantané (tests) : la mémoire locale est-elle vide ?
function Td.cache_empty() return next(CACHE) == nil end

return Td
