--[[
  Lot IA-G « le cerveau général » : le CATALOGUE du graphe recettes-technologies-machines-ressources, construit à
  partir d'un RELEVÉ des prototypes (PUR : aucune API Factorio). En jeu, le relevé est lu dans game.*_prototypes par
  script/ai3/general.lua ; hors jeu, les tests le bâtissent depuis les fixtures (recettes, technologies, entités).

  K.build(dump, opts) -> cat = {
    g = catalogue de shared/ai3/graphe.lua (G.new), spec = sa spécification,
    techs = { [nom] = { count, time, ingredients = {{pack, n}}, prerequisites, unlocks, bonus = { [rôle] = n } } },
    tech_list (triée), packs = { [objet] = vrai } (entrées des laboratoires), pack_list, labs = { {entity, item, speed,
    inputs} }, role = { [objet] = "pack" | "machine" | "militaire" | "logistique" }, fuel, products = { [recette] =
    {objets} } (TOUTES les recettes, cachées comprises), item_of = { [entité] = objet qui la pose } }.

  Relevé (dump) :
    recipes   = { [nom] = { category, energy, hidden, enabled, ingredients = {{type,name,amount}}, products = {...} } }
    techs     = { [nom] = { count, time, ingredients = {{pack,n}}, prerequisites, unlocks, effects = {type...},
                            enabled, hidden } }
    entities  = { { name, type (type du moteur), item (objet qui la pose, ou nil), crafting_categories,
                    resource_categories, energy ("electric" | "burner" | "none"), lab_inputs, speed,
                    fluid_in, fluid_out (chaudière, générateur), fluid (pompe) } }
    resources = { { entity, category, products = {{type,name,amount}} } }
    items     = { [nom] = { type (type du moteur), fuel_value } }
  opts = {
    exec = { [entité] = vrai } : machines qu'un EXÉCUTANT sait poser et faire tourner (absente : toutes) ; une machine
           sans exécutant n'existe pas pour l'équipe (ses recettes non plus, si personne d'autre ne les fait) ;
    exec_roles = { [rôle] = vrai } : rôles toujours exécutables (la main, le laboratoire du QG) ;
    labs_unpowered = vrai : le laboratoire du QG avance sans courant (script/ai3/cerveau.lua, revue B2) ;
  }
  Rôles des types du moteur : shared/ai3/reglages.lua (R.ENTITY_ROLE, R.ITEM_ROLE, R.MODIFIER_ROLE), seul fichier nommé.

  Ce que le catalogue DÉDUIT (aucune table écrite à la main) :
    - la main : catégories de fabrication et de minage du personnage ;
    - le combustible : le produit d'une ressource au plus grand pouvoir calorifique (égalité : le nom) ;
    - les packs : les entrées des laboratoires ;
    - l'électricité : pseudo-fluide des générateurs ; l'eau : ressource des pompes ; la vapeur : chaudières ;
    - une technologie invisible ou désactivée (verrou d'époque) n'est pas recherchable par une faction : elle n'entre
      pas au graphe, ses recettes non plus (sauf actives au départ ou débloquées par une autre).
  Déterminisme : relevé parcouru dans l'ordre des noms ; aucun pairs décisionnel.
]]

local G = require("shared.ai3.graphe")
local R = require("shared.ai3.reglages")

local K = {}

K.PUMP = "iag-pompe"
K.BOIL = "iag-chauffe"
K.GEN = "iag-generation"
K.ELEC = "iag-electricite"
K.BOIL_AMOUNT = 60
K.GEN_IN, K.GEN_OUT = 30, 900

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function list_copy(l)
  local out = {}
  for i, v in ipairs(l or {}) do out[i] = v end
  return out
end

--- Rôle d'une entité du relevé (type du moteur -> rôle).
function K.entity_role(e) return R.ENTITY_ROLE[e.type or ""] end

function K.build(dump, opts)
  opts = opts or {}
  local ents = {}
  for _, e in ipairs(dump.entities or {}) do ents[#ents + 1] = e end
  table.sort(ents, function(a, b) return a.name < b.name end)
  local machines, resources, pseudo, hand = {}, {}, {}, {}
  local labs, packs, role, item_of = {}, {}, {}, {}
  local hand_done = false
  local function executable(e, r)
    if (opts.exec_roles or {})[r] then return true end
    if opts.exec == nil then return true end
    return opts.exec[e.name] == true
  end
  for _, e in ipairs(ents) do
    local r = K.entity_role(e)
    if e.item then item_of[e.name] = e.item end
    if r == "main" then
      if not hand_done then
        hand_done = true
        machines[#machines + 1] = { name = e.name, hand = true, crafting_categories = list_copy(e.crafting_categories),
          resource_categories = list_copy(e.resource_categories), energy = "none" }
        for _, c in ipairs(e.crafting_categories or {}) do hand[c] = true end
      end
    elseif r and e.item then
      local is_machine = r == "fabrique" or r == "foreuse" or r == "labo" or r == "pompe" or r == "chauffe" or r == "generateur"
      if is_machine then role[e.item] = "machine" elseif r == "militaire" or r == "logistique" then role[e.item] = r end
      if r == "labo" then
        local inputs = {}
        for _, i in ipairs(e.lab_inputs or {}) do
          inputs[i] = true
          packs[i] = true
        end
        labs[#labs + 1] = { entity = e.name, item = e.item, speed = e.speed or 1, inputs = inputs }
      end
      if is_machine and executable(e, r) then
        local m = { name = e.item, entity = e.name, energy = e.energy or "none" }
        if r == "fabrique" then
          m.crafting_categories = list_copy(e.crafting_categories)
        elseif r == "foreuse" then
          m.resource_categories = list_copy(e.resource_categories)
        elseif r == "labo" then
          m.lab = true
          if opts.labs_unpowered then m.energy = "none" end
        elseif r == "pompe" then
          m.resource_categories = { K.PUMP }
          m.energy = "none"
          if e.fluid then resources[e.fluid] = resources[e.fluid] or { category = K.PUMP } end
        elseif r == "chauffe" and e.fluid_in and e.fluid_out then
          local cat = K.BOIL .. ":" .. e.name
          m.crafting_categories = { cat }
          pseudo[cat] = { category = cat, energy = 1, hidden = false,
            ingredients = { { type = "fluid", name = e.fluid_in, amount = K.BOIL_AMOUNT } },
            products = { { type = "fluid", name = e.fluid_out, amount = K.BOIL_AMOUNT } } }
        elseif r == "generateur" and e.fluid_in then
          local cat = K.GEN .. ":" .. e.name
          m.crafting_categories = { cat }
          m.energy = "none"
          pseudo[cat] = { category = cat, energy = 1, hidden = false,
            ingredients = { { type = "fluid", name = e.fluid_in, amount = K.GEN_IN } },
            products = { { type = "fluid", name = K.ELEC, amount = K.GEN_OUT } } }
        end
        machines[#machines + 1] = m
      end
    end
  end
  -- Ressources : chaque produit d'une ressource minable (entités dans l'ordre des noms ; le premier gagne).
  local res_list = {}
  for _, r in ipairs(dump.resources or {}) do res_list[#res_list + 1] = r end
  table.sort(res_list, function(a, b) return a.entity < b.entity end)
  for _, r in ipairs(res_list) do
    for _, p in ipairs(r.products or {}) do
      if not resources[p.name] then resources[p.name] = { category = r.category } end
    end
  end
  -- Combustible : le produit (objet) d'une ressource qu'un EXÉCUTANT sait extraire (catégorie de minage de la main ou
  -- d'une foreuse exécutable), au plus grand pouvoir calorifique ; `fuels` = tous ces candidats, du meilleur au moins
  -- bon (égalité : le nom). Moteur réel, banc g1 (27/10) : sans la condition d'extraction, le cristal de résonance du
  -- mod (âge 7, pouvoir calorifique supérieur au charbon) était pris pour le combustible des machines de l'âge 1.
  local extract_cats = {}
  for _, m in ipairs(machines) do
    for _, c in ipairs(m.resource_categories or {}) do extract_cats[c] = true end
  end
  local fuels = {}
  for _, name in ipairs(sorted_keys(resources)) do
    local it = (dump.items or {})[name]
    local v = it and it.fuel_value or 0
    if v > 0 and extract_cats[resources[name].category] then fuels[#fuels + 1] = { name, v } end
  end
  table.sort(fuels, function(a, b)
    if a[2] ~= b[2] then return a[2] > b[2] end
    return a[1] < b[1]
  end)
  local fuel = fuels[1] and fuels[1][1] or nil
  local fuel_list = {}
  for i, f in ipairs(fuels) do fuel_list[i] = f[1] end
  -- Rôles des objets par leur type (militaire) ; les packs l'emportent.
  for _, name in ipairs(sorted_keys(dump.items)) do
    local r = R.ITEM_ROLE[dump.items[name].type or ""]
    if r and not role[name] then role[name] = r end
  end
  for _, p in ipairs(sorted_keys(packs)) do role[p] = "pack" end
  -- Technologies recherchables par une faction : visibles et actives (un verrou d'époque est invisible).
  local techs, gtechs = {}, {}
  for _, name in ipairs(sorted_keys(dump.techs)) do
    local t = dump.techs[name]
    if t.enabled ~= false and not t.hidden then
      local bonus = {}
      for _, ty in ipairs(t.effects or {}) do
        local fam = R.MODIFIER_ROLE[ty]
        if fam then bonus[fam] = (bonus[fam] or 0) + 1 end
      end
      techs[name] = { count = t.count or 1, time = t.time or 1, ingredients = t.ingredients or {},
        prerequisites = list_copy(t.prerequisites), unlocks = list_copy(t.unlocks), bonus = bonus }
      gtechs[name] = { count = t.count or 1, ingredients = t.ingredients or {}, prerequisites = list_copy(t.prerequisites),
        unlocks = list_copy(t.unlocks) }
    end
  end
  -- Recettes : une recette inactive au départ et qu'aucune technologie recherchable ne débloque n'existe pas pour
  -- l'équipe (relevé sans le champ `enabled` : tenue pour active, comme les fixtures).
  local unlockable = {}
  for _, name in ipairs(sorted_keys(techs)) do
    for _, r in ipairs(techs[name].unlocks) do unlockable[r] = true end
  end
  local recipes, products = {}, {}
  for _, name in ipairs(sorted_keys(dump.recipes)) do
    local r = dump.recipes[name]
    local ps = {}
    for _, p in ipairs(r.products or {}) do ps[#ps + 1] = p.name end
    products[name] = ps
    if r.enabled ~= false or unlockable[name] then recipes[name] = r end
  end
  local spec = { recipes = recipes, techs = gtechs, machines = machines, resources = resources, pseudo_recipes = pseudo,
    hand_categories = hand, fuel = fuel, electricity = K.ELEC }
  local cat = { g = G.new(spec), spec = spec, techs = techs, tech_list = sorted_keys(techs), packs = packs,
    pack_list = sorted_keys(packs), labs = labs, role = role, fuel = fuel, fuels = fuel_list, products = products,
    item_of = item_of,
    resources = resources, resource_list = sorted_keys(resources) }
  return cat
end

return K
