--[[
  Lot RETROFIT-GABARITS (décision du DC du 10/11 : « rétrofit glissant à gabarits évolutifs : gérer les emprises distinctes (2×2 → 3×3) »).
  PRIMITIVE PARTAGÉE du remplacement sur place À EMPRISE DIFFÉRENTE. Le remplacement rapide du moteur (fast_replace : script/ai3/capital.lua,
  replace_one) refuse une autre emprise ; la procédure PROUVÉE du lot FOREUSES (script/team/foreuse_swap.lua, swap_one : thermique 2 × 2 ->
  électrique 3 × 3, moteur réel depuis 0.6.13) est extraite ici SANS changer son déroulé, et sert aux deux appelants :
    1. l'ancienne entité n'est plus « possédée » AVANT d'être retirée (sinon on_entity_destroyed compterait une perte d'avant-poste) ;
    2. retrait ; l'ouvrier dégage la place de la nouvelle boîte (arbres, rochers) comme à la pose d'un avant-poste ;
    3. can_place_entity à la position cible (build_check_type au choix de l'appelant : manual pour le rétrofit des boxes), puis
       create_entity{raise_built} (les gestionnaires enregistrent la pièce ; F40 : nil si l'un la détruit) ;
    4. échec : l'ancienne est REPOSÉE à l'identique (place vérifiée d'abord, F70 : create_entity pose par-dessus sans vérifier) ; si elle
       ne se repose pas, l'appelant rend son objet (et son contenu) au stock.
  Le CONTENU (combustible, entrées, sorties, recette) et le STOCK restent à l'appelant : ils dépendent de l'entité (foreuse : combustible
  seul ; four, assembleur : Se.take / Se.give ci-dessous). `keep_owner` : la propriété de l'ancienne (State.owner) passe à la nouvelle.
  Rend (new) ou (nil, back) : back = l'ancienne reposée, ou nil. Aucun nom d'objet du jeu ; rien dans la sauvegarde ; aucun require en événement.
]]

local State = require("script.faction.state")
local RegT = require("script.team.registre_types") -- lot UPS : registre des machines par force et par type (plus de recherche sur toute la surface)

local Se = {}

Se.MOVING = { character = true, unit = true, car = true, ["spider-vehicle"] = true, locomotive = true, ["cargo-wagon"] = true,
  ["fluid-wagon"] = true, ["artillery-wagon"] = true } -- (ce qui bouge n'occupe pas une case : même liste que foreuse_swap.lua)
Se.CLEARED = { "tree", "simple-entity" } -- types dégagés par l'ouvrier avant la pose (arbres, rochers), comme à la pose d'un avant-poste
Se.INVENTORIES = 4 -- indices d'inventaire relevés par Se.take (combustible, entrées, sorties, modules : 1 à 4 dans defines.inventory)

--- Remplace `old` par `to` posée en `place` = { x, y, dir, size (côté de la nouvelle boîte, tuiles), check (build_check_type, facultatif),
--- keep_owner }. Rend (new) ou (nil, back).
function Se.swap(surface, f, old, to, place)
  local pos = { x = old.position.x, y = old.position.y }
  local name, dir, unit = old.name, old.direction, old.unit_number
  local owner = place.keep_owner and State.owner(unit) or nil
  State.disown(unit)
  old.destroy()
  local half = (place.size or 1) / 2
  for _, e in ipairs(surface.find_entities_filtered({ area = { { place.x - half, place.y - half }, { place.x + half, place.y + half } },
      type = Se.CLEARED })) do
    if e.valid then e.destroy() end
  end
  local new
  local args = { name = to, position = { x = place.x, y = place.y }, direction = place.dir or dir, force = f.force, build_check_type = place.check }
  if surface.can_place_entity(args) then
    new = surface.create_entity({ name = to, position = args.position, direction = args.direction, force = f.force, raise_built = true })
    if new and not new.valid then new = nil end
  end
  if new then
    if owner then State.own(new, owner.f, owner.kind, owner.oid) end
    return new
  end
  local back
  if surface.can_place_entity({ name = name, position = pos, direction = dir, force = f.force }) then
    back = surface.create_entity({ name = name, position = pos, direction = dir, force = f.force })
    RegT.note(back) -- lot UPS : pose sans événement, notée au registre des machines
    if back and not back.valid then back = nil end
    if back and owner then State.own(back, owner.f, owner.kind, owner.oid) end
  end
  return nil, back
end

--- Contenu d'une machine (four, assembleur) avant son retrait : { items = { { name, count } } (noms triés), recipe = nom ou nil }.
--- Inventaires 1 à Se.INVENTORIES (combustible, entrées, sorties, modules) ; une entité sans inventaire rend une liste vide.
function Se.take(e)
  local counts, names = {}, {}
  for i = 1, Se.INVENTORIES do
    local inv = e.get_inventory and e.get_inventory(i) or nil
    if inv and inv.valid then
      for name, n in pairs(inv.get_contents()) do
        if not counts[name] then names[#names + 1] = name end
        counts[name] = (counts[name] or 0) + n
      end
    end
  end
  table.sort(names)
  local items = {}
  for _, name in ipairs(names) do items[#items + 1] = { name = name, count = counts[name] } end
  local recipe = nil
  if e.get_recipe then
    local ok, r = pcall(e.get_recipe)
    if ok and r then recipe = r.name end
  end
  return { items = items, recipe = recipe }
end

--- Rend `contents` (Se.take) à l'entité `e` (recette d'abord, puis les objets) ; rend la liste de ce qu'elle n'a pas pris
--- ({ { name, count } }, même ordre) : l'appelant la range au stock (un four électrique ne prend pas le charbon).
function Se.give(e, contents)
  local left = {}
  if not (e and e.valid and contents) then return contents and contents.items or left end
  if contents.recipe and e.set_recipe then pcall(e.set_recipe, contents.recipe) end
  for _, it in ipairs(contents.items or {}) do
    local put = e.insert({ name = it.name, count = it.count }) or 0
    if put < it.count then left[#left + 1] = { name = it.name, count = it.count - put } end
  end
  return left
end

return Se
