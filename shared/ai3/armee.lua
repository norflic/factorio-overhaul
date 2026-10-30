--[[
  Lot ARMEE-ANTICIPATION (retour du DC du 29/10 en jouant la 0.6.18, point 2 : « il y a absolument aucune prévision [...] les
  soldats, ils patrouillent [...] l'idée ça serait vraiment de recruter un maximum de soldats et de faire des raids [...] ils ont
  envoyé quatre soldats dans un endroit trop dangereux [...] il y a 13 soldats et ils devraient tous se regrouper »). PUR (aucune
  API Factorio, aucun nom d'objet), testé hors jeu par tests/armee_test.lua.

  Lot PREVISION (30/10) : l'ESTIMATION de la vague n'est plus ici. Elle vient de l'estimateur UNIQUE de la menace
  (shared/ai3/prevision.lua, Pv.estimate) et de ses décisions (shared/ai3/prevision_choix.lua, Pc.update) : vague par site à
  partir de la pollution qui ARRIVE aux nids connus, de l'évolution et des prototypes ; alerte d'ÉTAT (hystérésis, aucune
  horloge : l'ancien A.HOLD de 3 min est retiré) ; besoin borné par le plafond ET un budget de fer au-dessus de la réserve de
  production (critique C1 à C4). L'ancien corps (« 2 par nid » + unités trouvées autour du champ, y compris celles qu'aucun œil
  ne voyait) est retiré : un seul estimateur. Ce module garde l'INTERFACE des consommateurs (script/ai3/soldats.lua,
  script/team/team.lua) : threat, need, recruit, alert, muster, raid.

  DÉCIDER (rendu à l'appelant, script/ai3/soldats.lua) :
    * ALERTE tant que le cadre « préparer » de la PREMIÈRE vague est ouvert : l'équipe RECRUTE jusqu'au besoin (lu par
      shared/team/planner.lua) et ses soldats libres se REGROUPENT en une seule force au point `muster` (du côté de la première
      vague ; au QG si elle est insurmontable : repli) au lieu de patrouiller par paires ;
    * RAID contre le champ menaçant le plus proche (à portée Sd.OFFENSE_R) seulement si les soldats libres couvrent son besoin
      (Sd.clear_need du champ entier + défenseurs VUS, au moins FAIL_MULT × la force d'un raid déjà repoussé là) plus une petite
      réserve, ET si la porte de la prévision l'accepte (Pc.raid_gate : vague évitée ≥ ce qu'il engage, aucune autre vague
      imminente pendant le raid).
  Entrées triées, aucun ordre de `pairs`, racines carrées seulement, aucune trigonométrie.
]]

local Sd = require("shared.ai3.soldats")
local Pc = require("shared.ai3.prevision_choix")

local A = {}

A.PERIOD = 600          -- armée réévaluée au plus toutes les 600 ticks par équipe (la prévision, elle, une fois par minute)
A.FIELD_R = 32          -- défenseurs VUS comptés autour d'un champ ; rayon d'un champ pour la porte du raid
A.MARGIN = 1500         -- pour mille : 1,5 soldat (fusilier) par unité de poids ennemie (besoin d'un raid)
A.MUSTER_R = Pc.MUSTER_R
A.RAID_RESERVE = 2      -- raid contre un champ menaçant : réserve gardée au QG (le reste du regroupement part ensemble)
A.FAIL_MULT = 2         -- un raid repoussé (retraite) : la prochaine fois, au moins 2 × la force envoyée
A.FAIL_TICKS = 60 * 3600 -- mémoire d'un raid repoussé
A.MAX_FIELDS = 8        -- champs examinés au plus (les plus proches du QG)

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

--- Soldats nécessaires contre `weight` (poids ennemi) quand un soldat vaut `strength` (fusilier de niveau 0 = 1).
function A.need(weight, strength)
  if not weight or weight <= 0 then return 0 end
  local s = strength or 1
  if s < 0.1 then s = 0.1 end
  return math.ceil(weight * A.MARGIN / 1000 / s - 1e-9)
end

--- Champs examinés : groupes (Sd.clusters) d'au moins un nid, triés par distance au QG (puis x, y), au plus MAX_FIELDS.
function A.fields(clusters, hq)
  local out = {}
  for _, c in ipairs(clusters or {}) do
    if (c.nests or 0) > 0 then out[#out + 1] = c end
  end
  table.sort(out, function(a, b)
    local da, db = d2(a, hq), d2(b, hq)
    if da ~= db then return da < db end
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)
  while #out > A.MAX_FIELDS do out[#out] = nil end
  return out
end

--- Point de regroupement autour du QG (forme d'avant, gardée pour les appelants) : vers `toward`, à MUSTER_R tuiles du QG au
--- plus (au tiers de la distance si elle est courte) ; `home` quand la direction est indéfinie.
function A.muster(hq, toward, home)
  if not toward then return { x = home.x, y = home.y } end
  local p = Pc.muster({ x = hq.x, y = hq.y, tx = toward.x, ty = toward.y })
  if p.x == hq.x and p.y == hq.y then return { x = home.x, y = home.y } end
  return p
end

--- Besoin d'un raid contre le champ `c` (Sd.clusters + units, poids des défenseurs VUS) : nettoyage du champ entier et ses
--- défenseurs ; au moins FAIL_MULT × la force d'un raid déjà repoussé à moins de Sd.BLOCK_R (fails = { { x, y, n, until } }).
function A.raid_need(c, strength, fails, tick)
  local k = c.k or 1
  if (c.wide or 0) > k then k = c.wide end
  local need = Sd.clear_need(k) + A.need(c.units or 0, strength)
  for _, fl in ipairs(fails or {}) do
    if tick < (fl["until"] or 0) and d2(fl, c) <= Sd.BLOCK_R * Sd.BLOCK_R and need < fl.n * A.FAIL_MULT then
      need = fl.n * A.FAIL_MULT
    end
  end
  return need
end

--- Un champ est « chaud » quand au moins un de ses nids envoie des unités vers un de nos sites (estimation de la prévision).
function A.hot(c, est)
  local r2 = A.FIELD_R * A.FIELD_R
  for _, o in ipairs((est and est.sites) or {}) do
    for _, n in ipairs(o.nests or {}) do
      if d2(n, c) <= r2 then return true end
    end
  end
  return false
end

--- Décision de l'armée. input = {
---   tick, hq = {x,y}, home = {x,y} (rassemblement du QG), strength (force d'un soldat),
---   fields = { { x, y, k, wide, nests, units (poids des défenseurs VUS), rival } } (A.fields, complétés par l'appelant),
---   prev = état des décisions de la prévision (Pc.update : alert, army_need, army_cap, muster_site, insurm_first, first,
---   sites), est = estimation (Pv.estimate ou sa copie Prev.slim), fails = { { x, y, n, until } }, free (soldats sans groupe),
---   soldier_value (PV d'un soldat) }
--- Rend { threat (PV de la première vague), hot, nests, worms, units, need, recruit, alert, muster, raid | nil, raid_why }.
function A.estimate(input)
  local hq = input.hq
  local prev = input.prev or {}
  local est = input.est
  local out = { threat = 0, incoming = 0, hot = {}, nests = 0, worms = 0, units = 0, need = 0, alert = false }
  local fs = prev.first and prev.sites and prev.sites[prev.first]
  if fs then out.threat, out.eta = fs.w5 or 0, fs.eta end
  for _, c in ipairs(input.fields or {}) do
    if (c.nests or 0) > 0 and A.hot(c, est) then
      out.hot[#out.hot + 1] = c
      out.nests = out.nests + c.nests
      local wm = (c.k or 1) - c.nests - (c.rival or 0)
      if wm > 0 then out.worms = out.worms + wm end
      out.units = out.units + (c.units or 0)
    end
  end
  out.need = prev.army_need or 0
  out.alert = prev.alert and true or false
  if out.alert then
    if prev.insurm_first then
      out.muster = { x = (input.home or hq).x, y = (input.home or hq).y } -- vague insurmontable : repli groupé au QG
    else
      out.muster = Pc.muster(prev.muster_site) or { x = (input.home or hq).x, y = (input.home or hq).y }
    end
  end
  -- Raid PRÉVENTIF (avec ou sans alerte : c'est la vague évitée qui le justifie) : le champ chaud le plus proche à portée
  -- d'expédition, si la porte de la prévision l'accepte ; jamais pendant une vague insurmontable (repli).
  if not prev.insurm_first then
    for _, c in ipairs(out.hot) do
      if d2(c, hq) <= Sd.OFFENSE_R * Sd.OFFENSE_R and (c.rival or 0) == 0 then
        local need = A.raid_need(c, input.strength, input.fails, input.tick or 0)
        -- Soldats qui RESTENT pendant le raid (les libres moins ceux qui partent) : défense mobile des autres vagues.
        local left = math.max(0, (input.free or 0) - need) * (input.soldier_value or 0)
        local ok, why = Pc.raid_gate(prev, est or { sites = {} }, { x = c.x, y = c.y, r = A.FIELD_R }, need,
          { soldier_value = input.soldier_value, mobile_left = left })
        if ok then
          out.raid = { x = c.x, y = c.y, k = c.k, wide = c.wide, nests = c.nests, units = c.units or 0, need = need,
            reserve = A.RAID_RESERVE }
        end
        out.raid_why = why
        break
      end
    end
  end
  -- L'effectif à RECRUTER couvre aussi le raid visé (son besoin + la réserve), sous le même budget (prev.army_cap : soldats +
  -- recrues payables au-dessus de la réserve de production).
  out.recruit = out.need
  if out.raid and out.raid.need + out.raid.reserve > out.recruit then
    local r = out.raid.need + out.raid.reserve
    local cap = prev.army_cap or r
    if r > cap then r = cap end
    if r > out.recruit then out.recruit = r end
  end
  return out
end

--- Relecture : le raid visé (estimé jusqu'à A.PERIOD ticks plus tôt) vise-t-il encore une menace connue ? `clusters` : groupes de
--- menaces candidates du passage (Sd.clusters, après l'oubli des nids détruits).
function A.raid_alive(raid, clusters)
  if not raid then return false end
  local r2 = Sd.BLOCK_R * Sd.BLOCK_R
  for _, c in ipairs(clusters or {}) do
    if d2(c, raid) <= r2 then return true end
  end
  return false
end

--- Alerte en cours ? st = état de l'équipe (f.armee) ou nil. Alerte d'ÉTAT (lot PREVISION) : vraie tant que la prévision tient
--- le cadre de la première vague ouvert ; aucune horloge.
function A.alert_on(st)
  return st ~= nil and st.alert == true
end

--- Mémoire des raids repoussés : ajoute (x, y, n soldats envoyés) et retire les entrées échues ; rend la nouvelle liste.
function A.record_fail(fails, x, y, n, tick)
  local out = {}
  for _, fl in ipairs(fails or {}) do
    if tick < (fl["until"] or 0) and d2(fl, { x = x, y = y }) > Sd.BLOCK_R * Sd.BLOCK_R then out[#out + 1] = fl end
  end
  out[#out + 1] = { x = x, y = y, n = n, ["until"] = tick + A.FAIL_TICKS }
  return out
end

return A
