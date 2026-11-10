--[[
  Lot SCAN-TRANCHES (directive du DC du 9/11) : HYGIÈNE ÉLECTRIQUE, audit en LECTURE SEULE des poteaux d'une équipe, par impulsions
  (toutes les St.CFG.period ticks) étalées sur une fenêtre de St.CFG.slices ticks successifs, équipes désynchronisées (règle pure :
  shared/team/scan_tranches.lua). Cette première livraison COMPTE et JOURNALISE ([FO-HYGIENE]) ; elle ne retire AUCUNE entité.

  Branchement : requis par script/team/build.lua (Build.Hygiene) ; abonnement statique à on_tick, sortie O(1) hors fenêtre
  (St.rank_at : une division et un reste). Rang d'une équipe = sa place dans l'ordre stable « factions vivantes (ids triés), puis votre
  équipe » (le même ordre que la passe du plan directeur).

  Une impulsion, pour une équipe :
    1. RELEVÉ (première tranche où le jeton des travaux lourds est accordé, script/core/lourd.lua, coût déclaré = chunks de la boîte) :
       les poteaux de la force dans la boîte des chunks générés (script/team/boite_chunks.lua), gardés en données pures
       { unit_number, x, y }, triés par unit_number ;
    2. AUDIT par tranches (St.share sur les tranches restantes, au plus St.CFG.max_per_slice poteaux par tranche ; le poteau est RETROUVÉ
       à sa position et reconnu à son unit_number : un chargement de sauvegarde ne perd rien) :
       (a) SUR GISEMENT : au moins une entité de type « resource » sur l'emprise en tuiles entières du poteau ;
       (b) REDONDANT CANDIDAT = « feuille sans consommateur propre » : au plus UN voisin de fil de cuivre (un sommet de degré ≤ 1 n'est
           jamais un point d'articulation : son retrait ne coupe aucun autre poteau du réseau) ET chaque entité ALIMENTÉE par lui (source
           électrique au prototype, pas un poteau, même electric_network_id, boîte de collision dans son carré d'alimentation) est
           aussi dans le carré d'alimentation d'un AUTRE poteau de la même force et du même réseau. Un poteau isolé (aucun fil, rien
           d'alimenté) est compté candidat : il peut appartenir à un chantier en cours (lecture seule : rien n'est décidé ici).
       Ce qui N'EST PAS mesuré : la connexion des fils après retrait (hors de portée sans simulation ; la feuille s'en passe), la portée
       de fil entre les poteaux restants, les réseaux rouges et verts.
    3. JOURNAL, une ligne à la dernière tranche : « [FO-HYGIENE] <équipe> : impulsion a X.X min : P poteaux releves, S sur gisement,
       R redondants candidats (feuilles sans consommateur propre) ; cout : N tranches » (N = tranches ayant travaillé).
  État : f.team.hygiene (nombres, booléens, liste de triplets de nombres), jamais de fonction ni d'entité.

  Lot SCAN-EVENEMENTS (directive du DC du 9/11, « bannissement du H24 ») : période de 3 min (St.CFG.period = 10 800) ET RÉVEIL événementiel.
  La période est un train de créneaux de stride ticks ; le créneau k appartient au rang k mod n (n équipes) : k < n, c'est la fenêtre
  périodique du rang k ; au-delà, un créneau libre de la VOIE du rang, où une passe ne part qu'à la tranche 0 si un réveil est posé
  (St.due / St.ack sur f.team.scan ; déclencheurs : script/team/scan_reveil.lua). Journal au départ d'une passe de réveil :
  « [FO-SCAN] <équipe> : reveil (<cause>) a X.X min » ; la ligne [FO-HYGIENE] de la passe redit sa cause. Le début d'une passe est le
  tick de sa tranche 0 (t0 = tick - tranche) : une passe de réveil et une passe périodique ont le même moteur.
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local BoiteChunks = require("script.team.boite_chunks")
local Lourd = require("script.core.lourd")
local Profiler = require("script.core.profiler")
local St = require("shared.team.scan_tranches")
local Sr = require("script.team.scan_reveil") -- lot SCAN-EVENEMENTS : réveils (ordre des équipes, état f.team.scan)
local Boxes = require("script.team.boxes_rt") -- lot BOXES (DC 9/11) : relevé des boxes à la tranche 0, poteaux d'une box MAXED sautés à l'audit
local Balises = require("script.team.balises_teinte") -- lot BALISES-TEINTE (DC 10/11) : lueur des balises d'après leurs modules, une tranche par appel

local Hy = {}

Hy.CFG = St.CFG
Hy.MAX_RANKS = 16     -- garde : au-delà, aucune équipe (sortie avant toute lecture de l'état)
Hy.SEEK_R = 0.2       -- tuiles : rayon pour retrouver un poteau à sa position relevée

local function key_of(f) return tostring(f.key or "player") end
local function who(f) return key_of(f) .. ":hygiene" end

--- Identifiants des équipes dans l'ordre stable des rangs : factions vivantes (ids triés), puis « player » si votre équipe existe.
function Hy.ids() return Sr.ids() end

--- Déclencheurs d'une pensée d'équipe (script/team/team.lua, E6 : Build.Hygiene.reveil) : palier de stock, coupure d'énergie, rupture de
--- ressource (script/team/scan_reveil.lua, Sr.think). Rend la première cause posée ou nil.
function Hy.reveil(f, stock, tick) return Sr.think(f, stock, tick) end

local function new_pass(t0, why)
  return { t0 = t0, why = why or "periode", poles = {}, n = 0, sur = 0, red = 0, audited = 0, gone = 0, skipped = 0, cost = 0, dmax = 0,
    r0 = nil, logged = false }
end

--- 1. Relevé des poteaux de la force (jeton des travaux lourds pris d'abord ; faux s'il est refusé : on réessaie à la tranche suivante).
local function releve(f, surface, h, tick, slice)
  local box = BoiteChunks.get(surface)
  if not Lourd.take(tick, who(f), nil, St.box_cost(box)) then return false end
  Profiler.fstart("hyg:releve")
  local q = { type = "electric-pole", force = f.force }
  if box then q.area = { { box.x0 * 32, box.y0 * 32 }, { (box.x1 + 1) * 32, (box.y1 + 1) * 32 } } end
  local poles, dmax = {}, 0
  for _, e in ipairs(surface.find_entities_filtered(q)) do
    if e.valid and e.unit_number then
      poles[#poles + 1] = { e.unit_number, e.position.x, e.position.y }
      local d = e.prototype.supply_area_distance or 0
      if d > dmax then dmax = d end
    end
  end
  table.sort(poles, function(a, b) return a[1] < b[1] end)
  h.poles, h.n, h.dmax, h.r0, h.cost = poles, #poles, dmax, slice, h.cost + 1
  Profiler.fstop("hyg:releve")
  return true
end

--- Le poteau relevé `p` = { unit_number, x, y }, s'il est encore là.
local function pole_at(surface, force, p)
  local found = surface.find_entities_filtered({ position = { p[2], p[3] }, radius = Hy.SEEK_R, type = "electric-pole", force = force })
  for i = 1, #found do
    if found[i].unit_number == p[1] then return found[i] end
  end
  return nil
end

--- (a) Une entité de type « resource » sur l'emprise en tuiles entières du poteau.
local function on_ore(surface, e)
  local bb = e.bounding_box
  local x0, y0, x1, y1 = St.tile_box(bb.left_top.x, bb.left_top.y, bb.right_bottom.x, bb.right_bottom.y)
  return surface.count_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, type = "resource" }) > 0
end

--- Entités ALIMENTÉES par le poteau `e` : source électrique au prototype, pas un poteau, même réseau, dans son carré d'alimentation.
local function fed_by(surface, e, force, d)
  local out = {}
  local net = e.electric_network_id
  if not net then return out end
  local px, py = e.position.x, e.position.y
  for _, c in ipairs(surface.find_entities_filtered({ area = { { px - d, py - d }, { px + d, py + d } }, force = force })) do
    if c.type ~= "electric-pole" and c.prototype.electric_energy_source_prototype and c.electric_network_id == net then out[#out + 1] = c end
  end
  return out
end

--- Un AUTRE poteau de la même force et du même réseau que `e` alimente-t-il aussi `c` (son carré touche la boîte de `c`) ?
local function other_pole_covers(surface, e, c, force, dmax)
  local bb = c.bounding_box
  local x0, y0, x1, y1 = bb.left_top.x, bb.left_top.y, bb.right_bottom.x, bb.right_bottom.y
  local net, un = e.electric_network_id, e.unit_number
  local r = dmax + math.max(x1 - x0, y1 - y0)
  for _, p in ipairs(surface.find_entities_filtered({ position = c.position, radius = r, type = "electric-pole", force = force })) do
    if p.unit_number ~= un and p.electric_network_id == net
      and St.covers(p.position.x, p.position.y, p.prototype.supply_area_distance or 0, x0, y0, x1, y1) then return true end
  end
  return false
end

--- Audit d'un poteau : compteurs (a) sur gisement, (b) redondant candidat (feuille sans consommateur propre).
local function audit(surface, f, h, e)
  if on_ore(surface, e) then h.sur = h.sur + 1 end
  local nb = e.neighbours
  local wires = (nb and nb.copper and #nb.copper) or 0
  if wires > 1 then return end
  local d = e.prototype.supply_area_distance or 0
  local dmax = (h.dmax > d) and h.dmax or d
  for _, c in ipairs(fed_by(surface, e, f.force, d)) do
    if not other_pole_covers(surface, e, c, f.force, dmax) then return end -- consommateur PROPRE : le poteau sert
  end
  h.red = h.red + 1
end

--- 2. Une tranche d'audit : la part de la liste relevée (tranches restantes après le relevé), plafonnée à max_per_slice.
local function slice_step(f, surface, h, slice)
  local eff = Hy.CFG.slices - h.r0 - 1
  local s = slice - h.r0 - 1
  if eff <= 0 or s < 0 or s >= eff or h.n == 0 then return end
  local a, b, skipped = St.share_capped(h.n, s, eff, Hy.CFG.max_per_slice)
  if b < a then return end
  Profiler.fstart("hyg:tranche")
  for i = a, b do
    local boxed = Boxes.skip_at(f, h.poles[i][2], h.poles[i][3]) -- lot BOXES : poteau d'une box MAXED : ni retrouvé ni audité, compté
    local e = (not boxed) and pole_at(surface, f.force, h.poles[i]) or nil
    if e then
      audit(surface, f, h, e)
      h.audited = h.audited + 1
    elseif boxed then
      h.boxed = (h.boxed or 0) + 1 -- lot BOXES
    else
      h.gone = h.gone + 1
    end
  end
  h.skipped, h.cost = h.skipped + skipped, h.cost + 1
  Profiler.fstop("hyg:tranche")
end

--- 3. Journal de l'impulsion (une ligne) ; la liste relevée est rendue (rien à garder jusqu'à l'impulsion suivante).
local function report(f, h, why)
  local extra = ""
  if h.r0 == nil then extra = " ; jeton des travaux lourds refuse sur toute la fenetre : rien releve" end
  if h.skipped > 0 then extra = extra .. string.format(" ; %d non audites (plafond %d par tranche)", h.skipped, Hy.CFG.max_per_slice) end
  if h.gone > 0 then extra = extra .. string.format(" ; %d disparus pendant la passe", h.gone) end
  if h.why and h.why ~= "periode" then extra = extra .. " ; reveil (" .. h.why .. ")" end -- lot SCAN-EVENEMENTS : la cause de la passe
  if (h.boxed or 0) > 0 then extra = extra .. string.format(" ; %d ignores (box MAXED)", h.boxed) end -- lot BOXES
  if why then extra = extra .. " ; " .. why end
  log(string.format("[FO-HYGIENE] %s : impulsion a %.1f min : %d poteaux releves, %d sur gisement, %d redondants candidats (feuilles sans consommateur propre) ; cout : %d tranches%s",
    key_of(f), h.t0 / 3600, h.n, h.sur, h.red, h.cost, extra))
  h.logged, h.poles = true, {}
end

--- Tranche `slice` de l'équipe `f` au tick `tick` (St.window ou la voie de réveil a dit actif). Le début de la passe est le tick de sa
--- tranche 0 ; sa cause est celle servie par St.ack sur f.team.scan pour ce début (« periode » sinon).
function Hy.step(f, surface, tick, slice)
  local t = f.team
  local t0 = tick - slice
  local h = t.hygiene
  if not h or h.t0 ~= t0 then
    if h and not h.logged then report(f, h, "passe interrompue") end
    local sc = t.scan
    h = new_pass(t0, sc and sc.served == t0 and sc.why or nil)
    t.hygiene = h
  end
  if h.logged then return end
  if slice == 0 then Boxes.releve(f, surface, tick) end -- lot BOXES : relevé des boxes au début de l'impulsion (une ligne [FO-BOX])
  Balises.step(f, surface, tick, slice) -- lot BALISES-TEINTE : relevé à la tranche 0, parts St.share ensuite, journal [FO-BALISES]
  local last = (slice == Hy.CFG.slices - 1)
  if h.r0 == nil then
    if not releve(f, surface, h, tick, slice) then
      if last then
        Lourd.drop(who(f))
        report(f, h)
      end
      return
    end
  else
    slice_step(f, surface, h, slice)
  end
  if last then report(f, h) end
end

--- Départ ou suite d'une passe au tick `tick` (tranche `slice`, début t0) pour l'équipe `f` de rang `rank` : rend vrai si la tranche se
--- joue. Créneau périodique (`periodic`) : la passe se joue toujours et la première tranche vue la marque servie (St.ack : un réveil en
--- attente est servi par elle). Créneau de la voie : départ à la tranche 0 seulement, sur St.due ; les tranches suivantes ne se jouent
--- que si c'est bien cette passe qui a commencé (sc.served == t0) : pas de double passe, pas de demi-fenêtre.
local function admit(f, rank, tick, slice, periodic)
  local t0 = tick - slice
  local sc = Sr.state(f)
  if sc.served == t0 then return true end
  if not periodic and slice ~= 0 then return false end
  local due, why = St.due(sc, t0, Hy.CFG, rank)
  if not due then return false end
  St.ack(sc, t0, why)
  if why ~= "periode" then
    log(string.format("[FO-SCAN] %s : reveil (%s) a %.1f min", key_of(f), why, t0 / 3600))
  end
  return true
end

Events.on(defines.events.on_tick, function(e)
  local tick = e.tick
  local k, slice = St.rank_at(tick, Hy.CFG) -- créneau k de la période (k < n : fenêtre périodique du rang k ; sinon voie du rang k mod n)
  if not k then return end
  local ids = Hy.ids()
  local n = #ids
  if n == 0 then return end
  local rank = k % n
  if rank >= Hy.MAX_RANKS then return end
  local f = State.faction(ids[rank + 1])
  if not (f and f.team and f.hq and f.hq.valid) then return end
  if not admit(f, rank, tick, slice, k < n) then return end
  Profiler.start("hygiene")
  Hy.step(f, f.hq.surface, tick, slice)
  Profiler.stop("hygiene")
end)

return Hy
