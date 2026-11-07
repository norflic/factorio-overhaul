--[[
  Sortie de spirale (EFFONDREMENT, demande du lead du 7/11 : partie du DC sur 0.6.58, votre équipe tombée à 2 PNJ, fer libre à 0
  de 133 à 177 min, aucune recrue). Règle PURE, NON BRANCHÉE (le lead tranche ; l'équilibre va au DC).
  La recrue de votre équipe paie son kit et (10 + effectif) plaques de fer AU STOCK LIBRE (script/team/team.lua:1016-1017,
  has_list ; shared/team/org.lua:1083). Sous son effectif de départ, le fer qui arrive (minage à la main, tournées) est pris par
  d'autres avant elle : réservations des tâches (script/team/board.lua:258-264), modules en attente de matière, postes de défense.
  Et, contrairement aux factions (shared/team/planner.lua:943-949), elle n'a ni recrue sans arme sous 2 PNJ, ni minage d'urgence
  (planner.lua:958-960 : « RIEN d'autre de la survie des factions »).
  Sp.decide(s), s = {
    workers      = PNJ de l'équipe,
    floor        = effectif de départ (view.recover_floor),
    iron         = fer LIBRE au coffre (après les réservations),
    recruit_iron = fer d'UNE recrue (kit planifié au livre + 10 + effectif),
    stone_saturated = vrai si la pierre est saturée (cerveau : « sature [… stone] »),
  }
  Rend {
    hold       = plaques de fer gardées pour la recrue : les autres consommateurs voient iron − hold (jamais plus que le besoin
                 d'UNE recrue ; 0 à l'effectif de départ ou au-dessus),
    unarmed    = recrue sans arme (moins de 2 PNJ et pas assez de fer : parité avec les factions, planner.lua:943-947),
    mine       = minage d'urgence du fer (pas assez de fer pour une recrue : parité avec les factions, planner.lua:949),
    stop_stone = plus de collecte de pierre tant que la pierre est saturée et que le fer manque (le temps des PNJ va au fer),
  }.
  Déterminisme : arithmétique seule.
]]

local T = require("shared.team.config") -- (le nom du fer : T.outposts.iron.product, jamais écrit ici)

local Sp = {}

function Sp.decide(s)
  local out = { hold = 0, unarmed = false, mine = false, stop_stone = false }
  local floor = (s and s.floor) or 0
  local workers = (s and s.workers) or 0
  if floor <= 0 or workers >= floor then return out end
  local iron, need = math.max(0, s.iron or 0), math.max(0, s.recruit_iron or 0)
  out.hold = math.min(iron, need)
  local short = iron < need
  out.unarmed = short and workers < 2
  out.mine = short
  out.stop_stone = short and s.stone_saturated == true
  return out
end

--- Fer d'UNE recrue tiré du stock : le kit planifié au livre SANS le fer du stock (les chargeurs au coffre comptent, le pistolet
--- absent se fabrique) ; le fer brut qui en reste, (10 + effectif) compris. Sans livre : le fer écrit dans le coût.
function Sp.recruit_iron(cost, stock, book, iron_name)
  iron_name = iron_name or T.outposts.iron.product
  if not book then
    local n = 0
    for _, it in ipairs(cost or {}) do if it[1] == iron_name then n = n + (it[2] or 0) end end
    return n
  end
  local keys = {}
  for k in next, stock or {} do if k ~= iron_name then keys[#keys + 1] = k end end
  table.sort(keys)
  local s = {}
  for _, k in ipairs(keys) do s[k] = stock[k] end
  return book:plan(cost or {}, s).raw[iron_name] or 0
end

--- La décision depuis une vue du planificateur (shared/team/planner.lua) : votre équipe seulement (view.recover_floor ; nil pour les
--- factions, qui ont leur survie). `iron` : le fer du stock virtuel au début du plan.
function Sp.view(view, book, iron, iron_name)
  local floor = view and view.recover_floor
  if not floor then return Sp.decide(nil) end
  return Sp.decide({ workers = view.workers, floor = floor, iron = iron,
    recruit_iron = Sp.recruit_iron(view.recruit_cost, view.stock, book, iron_name) })
end

--- Fer que voit un autre consommateur que la recrue (tâches, capitalisation, défense) : le fer libre moins la part gardée.
function Sp.iron_for_others(iron, d)
  return math.max(0, (iron or 0) - ((d and d.hold) or 0))
end

return Sp
