--[[
  Lot KIT : quelles ENTITÉS donnent un objet quand un ouvrier les mine à la main ? PUR (aucune API Factorio) ; le balayage
  des prototypes du moteur est dans script/team/harvest.lua.

  Avant le lot, le minage à la main cherchait des entités DONT LE NOM EST L'OBJET (le minerai « iron-ore » est l'entité
  « iron-ore »). Le bois n'est pas dans ce cas : un arbre porte un autre nom et donne du bois. Les factions ne reçoivent plus
  les 50 bois du lot PLANDIR (kit égal à celui de votre équipe) : elles coupent des arbres. Aucun nom d'objet ni d'arbre n'est
  écrit ici : tout se lit sur la liste des prototypes { name, type, products = { objet, ... } }.

  H.names(item, protos) :
    - une ressource (type « resource ») porte le nom de l'objet : { objet } (comportement d'avant, minerais inchangés) ;
    - sinon les arbres (type « tree ») dont les produits contiennent l'objet, triés par nom ;
    - sinon une liste vide (rien à récolter).
]]

local H = {}

H.TREE_TYPE = "tree"
H.RESOURCE_TYPE = "resource"

function H.names(item, protos)
  local out = {}
  for _, p in ipairs(protos or {}) do
    if p.type == H.RESOURCE_TYPE and p.name == item then return { item } end
  end
  for _, p in ipairs(protos or {}) do
    if p.type == H.TREE_TYPE then
      for _, prod in ipairs(p.products or {}) do
        if prod == item then out[#out + 1] = p.name break end
      end
    end
  end
  table.sort(out)
  return out
end

--- L'entité de ce nom est-elle une ressource (tuile libre à vérifier avec les ressources seulement) ? Les arbres se
--- comptent comme des « ressources » pour le test de tuile libre du minage.
function H.free_types() return { H.RESOURCE_TYPE, H.TREE_TYPE } end

return H
