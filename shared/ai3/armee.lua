--[[
  Lot ARMEE-ANTICIPATION (retour du DC du 29/10 en jouant la 0.6.18, point 2 : « il y a absolument aucune prévision [...] les
  soldats, ils patrouillent [...] l'idée ça serait vraiment de recruter un maximum de soldats et de faire des raids [...] ils ont
  envoyé quatre soldats dans un endroit trop dangereux [...] il y a 13 soldats et ils devraient tous se regrouper »). PUR (aucune
  API Factorio, aucun nom d'objet), testé hors jeu par tests/armee_test.lua.

  ESTIMER la force qui va venir, avant qu'elle n'arrive :
    * les champs de nids CONNUS (carte de connaissance, K.enemy_points) autour du QG, regroupés (Sd.clusters) ;
    * un champ est MENAÇANT (« chaud ») quand il a au moins un nid et que sa case est POLLUÉE : dans le moteur, ce sont les nids
      qui absorbent la pollution qui forment les vagues ; les unités comptées autour de lui (défenseurs et vague qui se rassemble)
      et un poids par nid (la vague qu'il fabriquera encore) font sa menace ;
    * les unités ennemies déjà en approche autour du QG (hors des champs, sans double compte) s'y ajoutent.
  Poids : celui du regard des PNJ (script/ai3/comportement.lua, M.weight : moyen déchiqueteur = 1). Effectif voulu :
  A.need(poids, force d'un soldat) = ⌈poids × MARGIN / 1000 / force⌉ (force : S.soldier_strength, fusilier de niveau 0 = 1).

  DÉCIDER (rendu à l'appelant, script/ai3/soldats.lua) :
    * ALERTE quand la menace atteint ALERT_W : l'équipe RECRUTE jusqu'au besoin (lu par shared/team/planner.lua, priorité de la
      défense) et ses soldats libres se REGROUPENT en une seule force au point `muster` (entre le QG et la menace) au lieu de
      patrouiller par paires ;
    * RAID contre le champ menaçant le plus proche (à portée Sd.OFFENSE_R) seulement si les soldats libres couvrent le besoin du
      champ (Sd.clear_need du champ entier + ses défenseurs, et au moins FAIL_MULT × la force d'un raid déjà repoussé là) plus une
      petite réserve ; sinon : regroupement et recrutement d'abord, aucune autre expédition (pas de forces dispersées).
  Entrées triées, aucun ordre de `pairs`, racines carrées seulement, aucune trigonométrie.
]]

local Sd = require("shared.ai3.soldats")

local A = {}

A.PERIOD = 600          -- menace réévaluée au plus toutes les 600 ticks par équipe
A.FIELD_R = 32          -- unités comptées autour d'un champ de nids
A.HQ_R = 96             -- unités ennemies en approche comptées autour du QG
A.NEST_W = 2            -- poids d'un nid d'un champ menaçant : la vague qu'il fabriquera encore (supposé, non mesuré)
A.MARGIN = 1500         -- pour mille : 1,5 soldat (fusilier) par unité de poids ennemie
A.ALERT_W = 2           -- menace (poids) qui déclenche l'alerte : environ 10 petits déchiqueteurs ou 2 moyens
A.HOLD = 3 * 3600       -- alerte gardée 3 min après la dernière mesure au-dessus du seuil (pas de clignotement)
A.MUSTER_R = 20         -- point de regroupement : à 20 tuiles du QG vers la menace (au plus au tiers de la distance)
A.RAID_RESERVE = 2      -- raid contre un champ menaçant : réserve gardée au QG (le reste du regroupement part ensemble)
A.FAIL_MULT = 2         -- un raid repoussé (retraite) : la prochaine fois, au moins 2 × la force envoyée
A.FAIL_TICKS = 60 * 3600 -- mémoire d'un raid repoussé
A.MAX_FIELDS = 8        -- champs examinés au plus (les plus proches du QG) : coût borné des recherches d'unités

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

--- Unités en approche du QG : `units` = { { x, y, w } } (triées par l'appelant), sans celles à moins de FIELD_R d'un champ
--- (déjà comptées dans le champ). Rend le poids total et le barycentre { x, y } (nil si aucun poids).
function A.incoming(units, fields)
  local w, sx, sy = 0, 0, 0
  local r2 = A.FIELD_R * A.FIELD_R
  for _, u in ipairs(units or {}) do
    local inside = false
    for _, c in ipairs(fields or {}) do
      if d2(u, c) <= r2 then inside = true break end
    end
    if not inside then
      w = w + (u.w or 0)
      sx, sy = sx + u.x * (u.w or 0), sy + u.y * (u.w or 0)
    end
  end
  if w <= 0 then return 0, nil end
  return w, { x = sx / w, y = sy / w }
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

--- Point de regroupement : vers le barycentre `toward` (pondéré) de la menace, à MUSTER_R tuiles du QG au plus (au tiers de la
--- distance si elle est courte). `home` : point de rassemblement du QG quand la direction est indéfinie.
function A.muster(hq, toward, home)
  if not toward then return { x = home.x, y = home.y } end
  local dx, dy = toward.x - hq.x, toward.y - hq.y
  local d = math.sqrt(dx * dx + dy * dy)
  if d < 1 then return { x = home.x, y = home.y } end
  local r = A.MUSTER_R
  if r > d / 3 then r = d / 3 end
  return { x = hq.x + dx / d * r, y = hq.y + dy / d * r }
end

--- Besoin d'un raid contre le champ `c` (Sd.clusters + units, poids des unités autour de lui) : nettoyage du champ entier et
--- ses défenseurs ; au moins FAIL_MULT × la force d'un raid déjà repoussé à moins de Sd.BLOCK_R (fails = { { x, y, n, until } }).
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

--- Estimation. input = {
---   tick, hq = {x,y}, home = {x,y} (rassemblement du QG), strength (force d'un soldat),
---   fields = { { x, y, k, wide, nests, units (poids), polluted } } (A.fields, complétés par l'appelant),
---   approach = { { x, y, w } } (unités ennemies à moins de HQ_R du QG, triées), fails = { { x, y, n, until } },
---   soldiers (effectif), free (soldats sans groupe) }
--- Rend { threat, incoming, hot = { champs menaçants }, nests, worms, units, need, recruit (effectif à recruter : max(need, besoin
--- du raid + réserve)), alert, muster, raid = { x, y, k, wide, nests, need, reserve, units } | nil }.
function A.estimate(input)
  local hq = input.hq
  local out = { threat = 0, incoming = 0, hot = {}, nests = 0, worms = 0, units = 0, need = 0, alert = false }
  local inc, inc_c = A.incoming(input.approach, input.fields)
  out.incoming = inc
  local w, sx, sy = inc, 0, 0
  if inc_c then sx, sy = inc_c.x * inc, inc_c.y * inc end
  for _, c in ipairs(input.fields or {}) do
    if c.polluted and (c.nests or 0) > 0 then
      local cw = (c.units or 0) + A.NEST_W * c.nests
      out.hot[#out.hot + 1] = c
      out.nests = out.nests + c.nests
      local wm = (c.k or 1) - c.nests - (c.rival or 0)
      if wm > 0 then out.worms = out.worms + wm end
      out.units = out.units + (c.units or 0)
      w = w + cw
      sx, sy = sx + c.x * cw, sy + c.y * cw
    end
  end
  out.threat = w
  out.need = A.need(w, input.strength)
  out.alert = w >= A.ALERT_W
  if out.alert then
    out.muster = A.muster(hq, w > 0 and { x = sx / w, y = sy / w } or nil, input.home or hq)
    -- Raid : le champ menaçant le plus proche à portée d'expédition (hot est trié comme fields : par distance au QG).
    for _, c in ipairs(out.hot) do
      if d2(c, hq) <= Sd.OFFENSE_R * Sd.OFFENSE_R and (c.rival or 0) == 0 then
        out.raid = { x = c.x, y = c.y, k = c.k, wide = c.wide, nests = c.nests, units = c.units or 0,
          need = A.raid_need(c, input.strength, input.fails, input.tick or 0), reserve = A.RAID_RESERVE }
        break
      end
    end
  end
  -- Relecture : l'effectif à RECRUTER couvre aussi le raid visé (son besoin + la réserve). Sans cela, la faction s'armait au seul
  -- besoin de la menace (champ de 2 nids et 4 vers, 6 défenseurs : 15 soldats) alors que le raid en demande 24 + 2 : le raid
  -- restait « différé » pour toujours, le nid grandissait (« recruter un maximum de soldats et de faire des raids », DC 29/10).
  out.recruit = out.need
  if out.raid and out.raid.need + out.raid.reserve > out.recruit then out.recruit = out.raid.need + out.raid.reserve end
  return out
end

--- Relecture : le raid visé (estimé jusqu'à A.PERIOD ticks plus tôt) vise-t-il encore une menace connue ? `clusters` : groupes de
--- menaces candidates du passage (Sd.clusters, après l'oubli des nids détruits). Sans ce contrôle, un champ tout juste nettoyé était
--- visé de nouveau par un raid « fantôme » jusqu'à la réévaluation suivante (marche inutile, nettoyage compté deux fois).
function A.raid_alive(raid, clusters)
  if not raid then return false end
  local r2 = Sd.BLOCK_R * Sd.BLOCK_R
  for _, c in ipairs(clusters or {}) do
    if d2(c, raid) <= r2 then return true end
  end
  return false
end

--- Alerte en cours au tick donné ? st = état de l'équipe (f.armee) ou nil.
function A.alert_on(st, tick)
  return st ~= nil and tick < (st.alert_until or 0)
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
