--[[
  Lot BILAN, côté RUNTIME : lit les flux de la force (production et consommation par minute, get_flow_count, comme
  l'onglet « Partie », script/gui/ia1i_stats.lua) et le stock libre de l'équipe, une fois par minute, et rend la
  pondération de la règle pure (shared/ai3/bilan.lua) au cerveau par besoins (script/ai3/cerveau.lua, Ia3.plan).

  - État : f.team.ia3.bilan (nombres et chaînes : global, via l'état du cerveau ; créé ici au premier relevé, jamais en
    on_load).
  - Lecture protégée (pcall) : le moteur simulé des tests hors jeu n'a pas de statistiques de production ; sans relevé, aucune
    pondération (le cerveau décide exactement comme avant).
  - Coût : un relevé par minute et par équipe, au plus Bi.MAX_ITEMS × 2 get_flow_count après filtrage des objets inactifs.
  - Journal : une ligne [FO-BILAN] toutes les 5 minutes par équipe.
  Déterminisme : les statistiques du moteur sont les mêmes chez tous les pairs ; clés triées ; aucun temps mesuré.
]]

local Bi = require("shared.ai3.bilan")

local Bilan = {}

-- Aucun réglage de carte (settings.lua est un fichier de l'intégrateur) : Bilan.ENABLED = false rend le cerveau d'avant.
Bilan.ENABLED = true
Bilan.READ_MAX = 160 -- objets lus au plus par relevé (les clés des compteurs cumulés, triées)

local function sorted_union(a, b)
  local seen, ks = {}, {}
  for _, t in ipairs({ a or {}, b or {} }) do
    for k in pairs(t) do
      if not seen[k] then seen[k] = true ks[#ks + 1] = k end
    end
  end
  table.sort(ks)
  return ks
end

--- Lignes { [objet] = { prod, cons, stock } } des statistiques d'une force, ou nil si elles sont illisibles.
--- Seuls les objets avec un flux récent ou un stock sont gardés (le journal et l'état restent courts).
local function read_rows(force, stock)
  local rows
  local ok = pcall(function()
    local st = force.item_production_statistics
    local idx = defines.flow_precision_index.one_minute
    local names = sorted_union(st.input_counts, st.output_counts)
    rows = {}
    local n = 0
    for _, name in ipairs(names) do
      if n >= Bilan.READ_MAX then break end
      n = n + 1
      local prod = st.get_flow_count({ name = name, input = true, precision_index = idx })
      local cons = st.get_flow_count({ name = name, input = false, precision_index = idx })
      local have = stock[name] or 0
      if prod ~= 0 or cons ~= 0 or have ~= 0 then rows[name] = { prod = prod, cons = cons, stock = have } end
    end
  end)
  if not ok then return nil end
  return rows
end

--- Pondération du bilan pour l'équipe `f` : { [objet] = points de priorité } ({} sans pondération), ou nil si éteint.
--- À appeler à chaque pensée ; ne lit les statistiques qu'une fois par minute (Bi.PERIOD).
function Bilan.think(f, view, tick)
  if not Bilan.ENABLED then return nil end
  local st = f.team and f.team.ia3
  if not st then return nil end
  st.bilan = st.bilan or Bi.new()
  local b = st.bilan
  if Bi.due(b, tick) then
    local force = game and game.forces and game.forces[f.force]
    local rows = force and force.valid ~= false and read_rows(force, view.stock or {}) or nil
    if rows then Bi.update(b, tick, rows) end
  end
  if Bi.log_due(b, tick) then log(Bi.format(f.key or "player", tick, b)) end
  return Bi.weights(b)
end

return Bilan
