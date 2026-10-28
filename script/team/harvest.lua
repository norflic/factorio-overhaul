--[[
  Lot KIT : entités que l'on mine à la main pour obtenir un objet (minerai : l'entité du même nom ; bois : les arbres).
  Règle pure : shared/team/harvest.lua. Ici seulement le balayage des prototypes du moteur, gardé dans une table LOCALE
  (jamais dans `global` : recalculable, identique chez tous les joueurs).
]]

local H = require("shared.team.harvest")

local Harvest = {}

local protos = nil
local cache = {}

local function load_protos()
  if protos then return protos end
  local list = {}
  local ok, res = pcall(function()
    return game.get_filtered_entity_prototypes({ { filter = "type", type = { H.RESOURCE_TYPE, H.TREE_TYPE } } })
  end)
  if ok and res then
    local names = {}
    for name in pairs(res) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
      local p = res[name]
      local prods = {}
      local mp = p.mineable_properties
      if mp and mp.minable then
        for _, prod in ipairs(mp.products or {}) do prods[#prods + 1] = prod.name end
      end
      list[#list + 1] = { name = name, type = p.type, products = prods }
    end
  else
    list = false
  end
  protos = list
  return protos
end

--- Noms d'entités qui donnent `item` (liste triée). Sans la liste des prototypes (moteur simulé des tests hors jeu) : le nom
--- de l'objet lui-même, comme avant le lot.
function Harvest.names(item)
  local c = cache[item]
  if c then return c end
  local list = load_protos()
  if not list then
    c = { item }
  else
    c = H.names(item, list)
  end
  cache[item] = c
  return c
end

--- L'objet a-t-il au moins une entité à mineur (autre que l'absence de prototypes) ?
function Harvest.any(item) return #Harvest.names(item) > 0 end

--- Types qui comptent comme « libre » au test de tuile du minage de `item` (ressources ; les arbres aussi quand l'objet vient
--- d'un arbre).
function Harvest.free_types(item) return H.free_types(item, Harvest.names(item)) end

--- Une AUTRE ressource que celles qui donnent `item` recouvre-t-elle cette tuile ? Le moteur sélectionne alors l'autre
--- entité : relevé en moteur réel (graine 1618033988, kit égal, banc kit-diag) : sur 5 tuiles de charbon du QG d'Azur, un
--- cristal de résonance par-dessus ; les ouvriers n'en tiraient AUCUN charbon (0 sur 50 pendant 91 s, 8 fois), 2 cristaux
--- au coffre, et la faction restait sans combustible, donc sans fonte ni avant-poste pendant 60 min.
function Harvest.foreign_resource(surface, p, item)
  local own = {}
  for _, n in ipairs(Harvest.names(item)) do own[n] = true end
  for _, e in ipairs(surface.find_entities_filtered({ area = { { p.x - 0.5, p.y - 0.5 }, { p.x + 0.5, p.y + 0.5 } }, type = "resource" })) do
    if not own[e.name] then return true end
  end
  return false
end

--- Matières récoltables À PORTÉE de l'équipe : { [objet] = rayon } lu à la dernière relecture des gisements du cerveau
--- (f.team.ia3.reach, script/ai3/cerveau.lua). Vide sans cerveau par besoins.
function Harvest.reachable(f)
  local st = f and f.team and f.team.ia3
  return st and st.reach or {}
end

--- Vide les caches (tests).
function Harvest.reset() protos, cache = nil, {} end

return Harvest
