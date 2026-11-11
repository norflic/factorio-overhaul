--[[
  SOL DU MINERAI (lot DECOUPLAGE, directive du DC du 11/11 : « Cesse de concevoir des bandes hybrides qui associent foreuses et fours
  dans un même gabarit »). PUR : aucune API Factorio, aucun nom d'objet (types de prototypes seulement).

  Deux boîtes, une règle :
    BOX_MINAGE    gabarit dont TOUTES les entités sont d'un type de Sm.MINING_TYPES (foreuses, poteaux, convoyeurs, et les tuyaux d'un
                  champ de pétrole) : il peut couvrir les tuiles de ressource ;
    BOX_FONDERIE  tout autre gabarit (un seul four, bras, coffre, assembleur, labo...) : AUCUNE tuile de son emprise ni de ses têtes
                  sur une ressource (tolérance 0).
  Le type d'une entité est lu par Sm.type_of(nom), posé par le moteur (script/team/build.lua : prototypes du jeu) ; sans lecteur,
  aucun type n'est connu et tout gabarit est une BOX_FONDERIE (le plus strict). Lu par shared/team/plan.lua (P.fit).
]]

local Sm = {}

Sm.MINING_TYPES = {
  ["mining-drill"] = true, ["electric-pole"] = true,
  ["transport-belt"] = true, ["underground-belt"] = true, ["splitter"] = true,
  ["pipe"] = true, ["pipe-to-ground"] = true,
}

Sm.type_of = nil -- function(nom d'entité) -> type de prototype ou nil

local MEMO = setmetatable({}, { __mode = "k" }) -- par gabarit : cache LOCAL, jamais dans global (les types ne changent pas en partie)

--- Vrai si le gabarit `g` ({ entities = { { name } } }) est une BOX_MINAGE.
function Sm.mining_box(g)
  local m = MEMO[g]
  if m ~= nil then return m end
  m = true
  for _, e in ipairs(g.entities or {}) do
    if not Sm.MINING_TYPES[Sm.type_of and Sm.type_of(e.name) or false] then m = false break end
  end
  MEMO[g] = m
  return m
end

return Sm
