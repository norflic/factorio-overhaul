--[[
  Lot NIDS (nuit du 28 au 29/10, D-26 ; remarque du DC : « 25 soldats inactifs qui subissent des attaques au lieu de
  détruire le nid qui les menace »). Règle PURE (tests/nids_test.lua) du NETTOYAGE DES NIDS MENAÇANTS par une faction.

  Ce que la règle décide, à partir de ce que la faction SAIT (carte de connaissance de l'exploration : nids et vers vus
  par ses regards ; aucun nid inconnu n'est une cible) :
    1. SITES  : les nids vus, regroupés (Nd.sites) en sites de nid ; seuls les sites avec au moins un nid sont des cibles ;
    2. MENACE : proximité des biens de la faction (QG, avant-postes ; Nd.W_*) dans la portée d'un site + INCIDENTS subis
       (bâtiments et soldats détruits par la force ennemie, rattachés au site connu le plus proche) ; un site qui a déjà
       frappé est attaqué pour une menace plus faible (Nd.MIN_MENACE_HIT) ;
    3. ARMÉE SUFFISANTE : soldats libres (sans groupe, sans rôle de défense ou d'escorte) moins une GARNISON gardée au QG
       (un quart de l'effectif, 3 au moins) doivent couvrir le besoin du site (Sd.clear_need de la règle des rôles, + 50 %
       par échec précédent) ; sinon la faction ne part pas (elle ne vide jamais sa garnison) ;
    4. ATTENTES : après un échec (repli, délai), le site est laissé 5, 10, 20 puis 40 minutes (même échelle que le frein
       des attaques vaines du chef, C.VAIN_WAIT) ; une victoire efface l'attente ;
    5. SUIVI (Nd.supervise) : l'opération finit quand le moteur ne montre plus aucun nid autour de la cible (« done »),
       se replie si les pertes dépassent Nd.LOSS_MAX (« retreat ») ou dépasse son délai (« timeout »).
  Entrées triées, sorties déterministes : aucun ordre de `pairs`, racines carrées et divisions entières seulement. Aucun
  nom d'objet du jeu (tests/iag_test.lua) : les genres sont des TYPES d'entité (unité, tourelle).
]]

local Sd = require("shared.ai3.soldats")
local K = require("shared.ai3.carte")

local Nd = {}

Nd.REACH = 200            -- un site menace les biens (QG, avant-postes) à moins de 200 tuiles
Nd.W_HQ = 1000            -- poids du QG
Nd.W_OUTPOST = 400        -- poids d'un avant-poste (gisement exploité)
Nd.SITE_R = 48            -- des nids à moins de 48 tuiles du centre d'un site en font partie
Nd.WORM_R = 40            -- vers comptés dans le besoin d'un site : à moins de 40 tuiles de son centre
Nd.ATTR_R = 240           -- un incident est rattaché au site le plus proche, à moins de 240 tuiles
Nd.INC_TTL = 40 * 3600    -- un incident pèse de moins en moins et ne compte plus après 40 min
Nd.MIN_MENACE = 250       -- menace minimale d'un site qui n'a encore rien frappé (nid à ~110 tuiles du QG, ou ~60 d'un avant-poste)
Nd.MIN_MENACE_HIT = 120   -- menace minimale d'un site auquel un incident est rattaché
Nd.KEEP_PM = 250          -- garnison gardée au QG : 25 % de l'effectif (pour mille)...
Nd.KEEP_MIN = 3           -- ... et 3 soldats au moins
Nd.FAIL_PM = 500          -- besoin augmenté de 50 % par échec précédent (pour mille)
Nd.WAIT = 5 * 3600        -- attente après un échec : 5 min, doublée à chaque échec de suite ...
Nd.WAIT_CAP = 40 * 3600   -- ... 40 min au plus (5, 10, 20, 40)
Nd.HOLD_R = 64            -- une attente vaut pour tout site à moins de 64 tuiles de celui qui a échoué
Nd.LOSS_MAX = 400         -- repli quand 40 % des soldats engagés sont morts (pour mille)
Nd.SIEGE_TICKS = 4 * 3600 -- délai d'une opération, + TRAVEL_TICKS_PER_TILE par tuile de distance au QG
Nd.TRAVEL_TICKS_PER_TILE = 20
Nd.SPAWNER_CLEAR_R = 32   -- l'opération est finie quand le moteur ne montre plus de nid à 32 tuiles de la cible
Nd.MAX_INCIDENTS = 24
Nd.INC_W = { unit = 40, turret = 120, default = 60 }
Nd.TURRET_TYPES = { ["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true, ["turret"] = true }

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

--- Poids d'un incident selon le TYPE de l'entité détruite (unité : soldat ; tourelle ; autre bâtiment).
function Nd.incident_w(etype)
  if etype == "unit" or etype == "character" then return Nd.INC_W.unit end
  if Nd.TURRET_TYPES[etype] then return Nd.INC_W.turret end
  return Nd.INC_W.default
end

--- Ajoute un incident { x, y, t, w } à la liste (les plus anciens sortent au-delà de Nd.MAX_INCIDENTS).
function Nd.record_incident(list, x, y, tick, w)
  list[#list + 1] = { x = math.floor(x), y = math.floor(y), t = tick, w = w or Nd.INC_W.default }
  while #list > Nd.MAX_INCIDENTS do table.remove(list, 1) end
  return list
end

---------------------------------------------------------------------------------------------------
-- 1. Sites de nid
---------------------------------------------------------------------------------------------------
--- Sites de nid. nests, worms : listes de points { x, y } (carte de connaissance). Rend { { x, y, sp, wm } } triés par
--- (x, y) : x, y = centre (moyenne arrondie des nids), sp = nids, wm = vers à moins de Nd.WORM_R du centre (rattachés au
--- site le plus proche). Un nid appartient au premier site (dans l'ordre trié) dont l'ancre est à moins de Nd.SITE_R.
function Nd.sites(nests, worms)
  local pts = {}
  for _, p in ipairs(nests or {}) do pts[#pts + 1] = { x = p.x, y = p.y } end
  table.sort(pts, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  local groups = {}
  local r2 = Nd.SITE_R * Nd.SITE_R
  for _, p in ipairs(pts) do
    local hit = nil
    for _, g in ipairs(groups) do
      if d2(g.anchor, p) <= r2 then hit = g break end
    end
    if hit then
      hit.n = hit.n + 1
      hit.sx, hit.sy = hit.sx + p.x, hit.sy + p.y
    else
      groups[#groups + 1] = { anchor = p, n = 1, sx = p.x, sy = p.y }
    end
  end
  local out = {}
  for i, g in ipairs(groups) do
    out[i] = { x = math.floor(g.sx / g.n + 0.5), y = math.floor(g.sy / g.n + 0.5), sp = g.n, wm = 0 }
  end
  local w2 = Nd.WORM_R * Nd.WORM_R
  for _, w in ipairs(worms or {}) do
    local best, bd = nil, nil
    for _, s in ipairs(out) do
      local d = d2(s, w)
      if d <= w2 and (not bd or d < bd) then best, bd = s, d end
    end
    if best then best.wm = best.wm + 1 end
  end
  table.sort(out, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  return out
end

--- Efface de la carte de connaissance les nids (spawners) vus à moins de r tuiles de (x, y) : un site détruit ne redevient
--- pas une cible avant qu'un nouveau regard le revoie (K.record réécrit les points du secteur à chaque regard).
--- Renvoie le nombre de nids effacés.
function Nd.purge(m, x, y, r)
  local n, r2 = 0, r * r
  local x0, x1 = math.floor((x - r) / K.SECTOR), math.floor((x + r) / K.SECTOR)
  local y0, y1 = math.floor((y - r) / K.SECTOR), math.floor((y + r) / K.SECTOR)
  for sy = y0, y1 do
    for sx = x0, x1 do
      local s = m.s[K.key(sx, sy)]
      if s and s.sp then
        local keep = {}
        for _, p in ipairs(s.sp) do
          if (p.x - x) ^ 2 + (p.y - y) ^ 2 <= r2 then n = n + 1 else keep[#keep + 1] = p end
        end
        s.sp = #keep > 0 and keep or nil
      end
    end
  end
  return n
end

--- Nids et vers vus de la carte de connaissance m, dans le rayon r (tuiles) autour d'au moins un des points `around`
--- ({x, y}). Parcours des secteurs par clés triées. Rend nests, worms (listes de { x, y }).
function Nd.known(m, around, r)
  local nests, worms = {}, {}
  local r2 = r * r
  local function near(p)
    for _, a in ipairs(around) do if d2(a, p) <= r2 then return true end end
    return false
  end
  for _, key in ipairs(K.sorted_keys(m.s)) do
    local s = m.s[key]
    for _, p in ipairs(s.sp or {}) do if near(p) then nests[#nests + 1] = { x = p.x, y = p.y } end end
    for _, p in ipairs(s.wm or {}) do if near(p) then worms[#worms + 1] = { x = p.x, y = p.y } end end
  end
  return nests, worms
end

---------------------------------------------------------------------------------------------------
-- 2. Menace
---------------------------------------------------------------------------------------------------
--- Poids d'un incident à l'instant tick (0 si trop ancien).
function Nd.incident_now(inc, tick)
  local age = tick - inc.t
  if age < 0 then age = 0 end
  if age >= Nd.INC_TTL then return 0 end
  return math.floor((inc.w or Nd.INC_W.default) * (Nd.INC_TTL - age) / Nd.INC_TTL)
end

--- Menace de chaque site : proximité des biens + incidents rattachés. assets = { { x, y, w } }, incidents = { { x, y, t,
--- w } }. Écrit site.prox, site.inc, site.menace (entiers) ; renvoie la liste (même ordre).
function Nd.rank(sites, assets, incidents, tick)
  for _, s in ipairs(sites) do s.prox, s.inc = 0, 0 end
  for _, a in ipairs(assets or {}) do
    for _, s in ipairs(sites) do
      local d = math.sqrt(d2(a, s))
      if d < Nd.REACH then s.prox = s.prox + math.floor((a.w or Nd.W_OUTPOST) * (Nd.REACH - d) / Nd.REACH) end
    end
  end
  local a2 = Nd.ATTR_R * Nd.ATTR_R
  for _, inc in ipairs(incidents or {}) do
    local best, bd = nil, nil
    for _, s in ipairs(sites) do
      local d = d2(inc, s)
      if d <= a2 and (not bd or d < bd) then best, bd = s, d end
    end
    if best then best.inc = best.inc + Nd.incident_now(inc, tick) end
  end
  for _, s in ipairs(sites) do s.menace = s.prox + s.inc end
  return sites
end

---------------------------------------------------------------------------------------------------
-- 3. Besoin, garnison, attentes
---------------------------------------------------------------------------------------------------
--- Soldats gardés au QG : un quart de l'effectif, 3 au moins.
function Nd.reserve(total)
  local r = math.floor((total or 0) * Nd.KEEP_PM / 1000 + 0.999)
  if r < Nd.KEEP_MIN then r = Nd.KEEP_MIN end
  return r
end

--- Soldats nécessaires pour un site : la règle des rôles (nids + vers), + Nd.FAIL_PM pour mille par échec précédent.
function Nd.need(site, fails)
  local base = Sd.clear_need((site.sp or 1) + (site.wm or 0))
  local f = fails or 0
  return base + math.floor((base * Nd.FAIL_PM * f + 999) / 1000)
end

--- Attente en cours pour un site (holds = { { x, y, fails, ["until"] } }) : l'entrée à moins de Nd.HOLD_R, ou nil.
function Nd.hold_of(holds, site)
  local r2 = Nd.HOLD_R * Nd.HOLD_R
  for _, h in ipairs(holds or {}) do
    if d2(h, site) <= r2 then return h end
  end
  return nil
end

--- Un échec (repli, délai) contre le site : attente 5, 10, 20, 40 min. Renvoie l'entrée.
function Nd.fail(holds, site, tick)
  local h = Nd.hold_of(holds, site)
  if not h then
    h = { x = site.x, y = site.y, fails = 0, ["until"] = 0 }
    holds[#holds + 1] = h
  end
  h.fails = h.fails + 1
  local wait = Nd.WAIT
  for _ = 2, math.min(h.fails, 8) do wait = wait * 2 end
  if wait > Nd.WAIT_CAP then wait = Nd.WAIT_CAP end
  h["until"] = tick + wait
  h.x, h.y = site.x, site.y
  return h
end

--- Une victoire efface les attentes à moins de Nd.HOLD_R du site.
function Nd.success(holds, site)
  local r2 = Nd.HOLD_R * Nd.HOLD_R
  local keep = {}
  for _, h in ipairs(holds) do if d2(h, site) > r2 then keep[#keep + 1] = h end end
  for i = #holds, 1, -1 do holds[i] = nil end
  for i, h in ipairs(keep) do holds[i] = h end
end

---------------------------------------------------------------------------------------------------
-- 4. Décision
---------------------------------------------------------------------------------------------------
--- Décision de la faction. ctx = { tick, sites (Nd.sites), assets, incidents, holds, total (soldats vivants), idle (soldats
--- libres près du QG : sans rôle d'escorte, de défense ou de nettoyage, hors repos) }.
--- Renvoie decision, why. decision = { x, y, sp, wm, menace, prox, inc, need, reserve, fails } ou nil ; why = { sites,
--- faibles, attente, courts } (comptes, journal et mesure).
function Nd.decide(ctx)
  local why = { sites = 0, faibles = 0, attente = 0, courts = 0 }
  local sites = {}
  for _, s in ipairs(ctx.sites or {}) do
    if (s.sp or 0) > 0 then sites[#sites + 1] = { x = s.x, y = s.y, sp = s.sp, wm = s.wm or 0, seen = s.seen } end
  end
  why.sites = #sites
  if #sites == 0 then return nil, why end
  Nd.rank(sites, ctx.assets, ctx.incidents, ctx.tick)
  table.sort(sites, function(a, b)
    if a.menace ~= b.menace then return a.menace > b.menace end
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)
  local reserve = Nd.reserve(ctx.total)
  local spare = (ctx.idle or 0) - reserve
  for _, s in ipairs(sites) do
    local floor = s.inc > 0 and Nd.MIN_MENACE_HIT or Nd.MIN_MENACE
    if s.menace < floor then
      why.faibles = why.faibles + 1
    else
      local h = Nd.hold_of(ctx.holds, s)
      if h and ctx.tick < h["until"] then
        why.attente = why.attente + 1
      else
        local fails = h and h.fails or 0
        local need = Nd.need(s, fails)
        if spare < need then
          why.courts = why.courts + 1
        else
          s.need, s.reserve, s.fails = need, reserve, fails
          return s, why
        end
      end
    end
  end
  return nil, why
end

---------------------------------------------------------------------------------------------------
-- 5. Suivi d'une opération
---------------------------------------------------------------------------------------------------
--- Délai d'une opération contre une cible à `dist` tuiles du QG.
function Nd.deadline(started, dist)
  return started + Nd.SIEGE_TICKS + math.floor((dist or 0) * Nd.TRAVEL_TICKS_PER_TILE)
end

--- Suivi. op = { engaged (soldats partis), started, dist }, now = { tick, alive (engagés encore vivants), spawners (nids
--- que le moteur montre à moins de Nd.SPAWNER_CLEAR_R de la cible), onsite (engagés vivants à moins de 60 tuiles de la
--- cible) }. Renvoie « done » (plus aucun nid), « retreat » (pertes trop lourdes), « timeout », ou « continue ».
function Nd.supervise(op, now)
  if now.spawners <= 0 then return "done" end
  local lost = (op.engaged or 0) - (now.alive or 0)
  if (op.engaged or 0) > 0 and lost * 1000 >= Nd.LOSS_MAX * op.engaged then return "retreat" end
  if (now.alive or 0) <= 0 then return "retreat" end
  if now.tick >= Nd.deadline(op.started, op.dist) then return "timeout" end
  return "continue"
end

return Nd
