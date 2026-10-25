--[[
  RECETTES PAR LOTS (lot MOD-2, décision D-15 du Directeur Créatif, Q-M2 a, 24/10). Lua PUR, testé hors jeu
  (tests/recipe_lots_test.lua).

  Le moteur 1.1.91 ne fait pas plus de 60 fabrications par seconde dans un assembleur ou un four (MOD-0, F191 ; doc :
  « If the time to complete a recipe is shorter than one tick, only one craft can be completed per tick »). Au-delà,
  une recette « lot × 10 » (puis « lot × 100 ») prend le relais : ingrédients, produits et durée multipliés par k,
  même économie (mêmes rapports exacts) ; la machine fait k fois moins de fabrications pour le même débit.

  Ce fichier :
    - nomme les lots (« fo-lot10-<recette> », « fo-lot100-<recette> ») et les relit ;
    - fabrique la table d'un lot à partir de la recette de base (étape data : prototypes/lots.lua) ;
    - choisit le lot d'une machine (étape control : script/modules/lots.lua), en ENTIERS, avec hystérésis.

  Choix du lot (règle `choose`) : W = vitesse de la machine / durée de la recette de BASE = fabrications par seconde
  voulues au lot 1. Un lot k « tient » sous un plafond P si W ≤ P × k.
    - montée : si le lot courant ne tient pas sous R.CAP (60 /s), la machine passe au plus petit lot qui tient ;
    - descente : seulement si un lot plus petit tient sous R.DOWN (45 /s) : bande d'hystérésis 45–60 /s, aucune
      bascule en boucle pour une vitesse qui ne change pas ;
    - aucun lot ne tient (W > 6 000 /s) : le plus grand lot disponible, la machine est plafonnée (dit au panneau).
  Unités : vitesse en millièmes (crafting_speed × 1 000 arrondi), durée en millisecondes (energy × 1 000 arrondi) ;
  W ≤ P × k  ⟺  vitesse_m ≤ P × k × durée_ms (entiers exacts, < 2^53).
]]

local R = {}

R.SIZES = { 10, 100 }          -- lots générés (le lot 1 est la recette de base)
R.PREFIX = "fo-lot"
R.CAP = 60                     -- fabrications par seconde au plus (F191)
R.DOWN = 45                    -- descente : le lot inférieur doit tenir sous 45 /s
R.UINT16 = 65535               -- quantité d'un objet dans une recette (ingrédient ou produit) : uint16

--- Nom du lot k de la recette `base`.
function R.name(base, k)
  return R.PREFIX .. tostring(k) .. "-" .. base
end

--- Relit un nom de lot : base, k ; nil pour une recette ordinaire.
function R.parse(name)
  local k, base = string.match(name or "", "^fo%-lot(%d+)%-(.+)$")
  if not k then return nil end
  return base, tonumber(k)
end

--- Est-ce un nom de lot ?
function R.is_lot(name)
  return R.parse(name) ~= nil
end

---------------------------------------------------------------------------------------------------
-- Tables de recettes (étape data). Formes acceptées : courte { "nom", n } ou longue { type, name, amount… } ;
-- result / result_count ; results ; normal / expensive (false permis).
---------------------------------------------------------------------------------------------------
local function copy(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k, v in pairs(t) do o[k] = copy(v) end
  return o
end
R.copy = copy

--- Ingrédient sous forme longue (copie).
function R.norm_ingredient(i)
  if i.name == nil and i[1] ~= nil then
    return { type = "item", name = i[1], amount = i[2] or 1 }
  end
  local o = copy(i)
  o.type = o.type or "item"
  return o
end

--- Produit sous forme longue (copie).
function R.norm_product(p)
  if p.name == nil and p[1] ~= nil then
    return { type = "item", name = p[1], amount = p[2] or 1 }
  end
  local o = copy(p)
  o.type = o.type or "item"
  if o.amount == nil and o.amount_min == nil then o.amount = 1 end
  return o
end

--- Bloc normalisé d'une définition (recette sans normal/expensive, ou un de ces deux blocs) :
--- { ingredients, results, energy_required, main_product, autres clés recopiées } ; nil si le bloc est `false`.
local BLOCK_KEYS = { "emissions_multiplier", "requester_paste_multiplier", "overload_multiplier",
  "allow_inserter_overload", "show_amount_in_title", "always_show_products", "unlock_results" }
function R.block_of(def)
  if def == false or def == nil then return nil end
  local b = { ingredients = {}, results = {} }
  for _, i in ipairs(def.ingredients or {}) do b.ingredients[#b.ingredients + 1] = R.norm_ingredient(i) end
  if def.results then
    for _, p in ipairs(def.results) do b.results[#b.results + 1] = R.norm_product(p) end
  elseif def.result then
    b.results[1] = { type = "item", name = def.result, amount = def.result_count or 1 }
  end
  b.energy_required = def.energy_required or 0.5
  b.main_product = def.main_product
  for _, k in ipairs(BLOCK_KEYS) do b[k] = def[k] end
  return b
end

local function mul_amount(o, key, k)
  if o[key] ~= nil then o[key] = o[key] * k end
end

--- Bloc du lot k : quantités et durée × k. Renvoie le bloc, ou nil et la raison (quantité d'objet hors uint16).
function R.multiply_block(b, k)
  local o = { ingredients = {}, results = {} }
  for _, i in ipairs(b.ingredients) do
    local n = copy(i)
    mul_amount(n, "amount", k)
    mul_amount(n, "catalyst_amount", k)
    if n.type ~= "fluid" and (n.amount or 0) > R.UINT16 then
      return nil, "ingredient " .. n.name .. " x" .. k .. " = " .. n.amount .. " > " .. R.UINT16
    end
    o.ingredients[#o.ingredients + 1] = n
  end
  for _, p in ipairs(b.results) do
    local n = copy(p)
    mul_amount(n, "amount", k)
    mul_amount(n, "amount_min", k)
    mul_amount(n, "amount_max", k)
    mul_amount(n, "catalyst_amount", k)
    local top = n.amount or n.amount_max or 0
    if n.type ~= "fluid" and top > R.UINT16 then
      return nil, "produit " .. n.name .. " x" .. k .. " = " .. top .. " > " .. R.UINT16
    end
    o.results[#o.results + 1] = n
  end
  o.energy_required = b.energy_required * k
  o.main_product = b.main_product
  for _, key in ipairs(BLOCK_KEYS) do o[key] = b[key] end
  -- Collage dans un coffre demandeur : multiplicateur ramené au lot (30 lots × 100 ferait 30 fois trop).
  local paste = b.requester_paste_multiplier or 30
  o.requester_paste_multiplier = math.max(1, math.floor(paste / k))
  -- Recette « par lot » : jamais fabricable à la main, ni proposée dans les menus.
  o.enabled = false
  o.hidden = true
  o.hide_from_player_crafting = true
  o.allow_decomposition = false
  o.allow_as_intermediate = false
  o.allow_intermediates = false
  return o
end

--- Produit principal d'un bloc : main_product non vide, sinon le produit unique ; nil sinon.
function R.main_product(b)
  if b.main_product and b.main_product ~= "" then
    for _, p in ipairs(b.results) do
      if p.name == b.main_product then return p end
    end
    return { type = "item", name = b.main_product }
  end
  if b.main_product == nil and #b.results == 1 then return b.results[1] end
  return nil
end

--- Plus grande quantité de fluide d'un bloc (ingrédient ou produit), 0 sans fluide.
function R.max_fluid(b)
  local m = 0
  for _, list in ipairs({ b.ingredients, b.results }) do
    for _, x in ipairs(list) do
      if x.type == "fluid" then
        local a = x.amount or x.amount_max or 0
        if a > m then m = a end
      end
    end
  end
  return m
end

--- Table du lot k d'une recette de base (table data.raw.recipe[...] non modifiée). Renvoie la table (sans
--- localised_name ni icônes, posés par prototypes/lots.lua), ou nil et la raison.
function R.lot_recipe(base, k)
  local has_diff = base.normal ~= nil or base.expensive ~= nil
  local r = {
    type = "recipe",
    name = R.name(base.name, k),
    category = base.category or "crafting",
    subgroup = base.subgroup,
    order = base.order,
    crafting_machine_tint = copy(base.crafting_machine_tint),
  }
  if has_diff then
    for _, key in ipairs({ "normal", "expensive" }) do
      local def = base[key]
      if def == false then
        r[key] = false
      elseif def ~= nil then
        local blk, why = R.multiply_block(R.block_of(def), k)
        if not blk then return nil, key .. " : " .. why end
        r[key] = blk
      end
    end
    if r.normal == false and r.expensive == false then return nil, "normal et expensive desactives" end
  else
    local blk, why = R.multiply_block(R.block_of(base), k)
    if not blk then return nil, why end
    for kk, v in pairs(blk) do r[kk] = v end
  end
  return r
end

---------------------------------------------------------------------------------------------------
-- Choix du lot d'une machine (étape control). Entiers seulement.
---------------------------------------------------------------------------------------------------
--- Le lot k tient-il sous le plafond `cap` (fabrications/s) ?
function R.fits(k, cap, speed_m, energy_ms)
  return speed_m <= cap * k * energy_ms
end

--- Lot voulu. cur : lot courant (1, 10, 100) ; speed_m : vitesse en millièmes ; energy_ms : durée de la recette de
--- BASE en millisecondes (≥ 1) ; avail : lots disponibles pour cette machine, triés, 1 compris. Renvoie le lot.
function R.choose(cur, speed_m, energy_ms, avail)
  if energy_ms < 1 then energy_ms = 1 end
  local hi = avail[#avail]
  for _, k in ipairs(avail) do
    if R.fits(k, R.CAP, speed_m, energy_ms) then hi = k break end
  end
  local present = false
  for _, k in ipairs(avail) do if k == cur then present = true end end
  if not present or cur < hi then return hi end
  local lo = avail[#avail]
  for _, k in ipairs(avail) do
    if R.fits(k, R.DOWN, speed_m, energy_ms) then lo = k break end
  end
  if cur > lo then
    if lo < hi then return hi end
    return lo
  end
  return cur
end

--- Fabrications par seconde VOULUES au lot k (texte, centièmes, sans flottant) : pour le panneau.
function R.rate_cents(k, speed_m, energy_ms)
  if energy_ms < 1 then energy_ms = 1 end
  -- W / k en centièmes = speed_m × 100 / (k × energy_ms), arrondi.
  return math.floor((speed_m * 100) / (k * energy_ms) + 0.5)
end

--- Vitesse en millièmes (flottant du moteur → entier), et durée en millisecondes.
function R.milli(x)
  return math.floor(x * 1000 + 0.5)
end

---------------------------------------------------------------------------------------------------
-- Contrôle des données finales (harness de l'étape data, tests) : chaque lot = k × sa recette de base.
---------------------------------------------------------------------------------------------------
local function near(a, b)
  return math.abs(a - b) <= 1e-9 * math.max(1, math.abs(a), math.abs(b))
end

local function cmp_list(errs, where, lb, ll, k, keys)
  if #lb ~= #ll then
    errs[#errs + 1] = where .. " : " .. #ll .. " entrée(s) pour " .. #lb .. " dans la base"
    return
  end
  for i = 1, #lb do
    local b, l = lb[i], ll[i]
    if b.name ~= l.name or (b.type or "item") ~= (l.type or "item") then
      errs[#errs + 1] = where .. "[" .. i .. "] : " .. tostring(l.name) .. " pour " .. tostring(b.name)
    else
      for _, key in ipairs(keys) do
        local bv, lv = b[key], l[key]
        if bv ~= nil or lv ~= nil then
          if bv == nil or lv == nil or not near(lv, bv * k) then
            errs[#errs + 1] = string.format("%s[%d].%s : %s pour %s x %d", where, i, key, tostring(lv), tostring(bv), k)
          end
        end
      end
      if (b.probability or 1) ~= (l.probability or 1) then
        errs[#errs + 1] = where .. "[" .. i .. "].probability : " .. tostring(l.probability) .. " pour " .. tostring(b.probability)
      end
    end
  end
end

--- Contrôle d'un lot (table de recette) contre sa base. Renvoie la liste des écarts (vide : conforme).
function R.verify_lot(lot, base)
  local errs = {}
  local _, k = R.parse(lot.name)
  if not k then return { lot.name .. " : nom de lot illisible" } end
  if (lot.category or "crafting") ~= (base.category or "crafting") then
    errs[#errs + 1] = lot.name .. " : catégorie " .. tostring(lot.category) .. " pour " .. tostring(base.category)
  end
  local pairs_ = {}
  if base.normal ~= nil or base.expensive ~= nil then
    for _, key in ipairs({ "normal", "expensive" }) do
      if base[key] == false or base[key] == nil then
        if lot[key] ~= base[key] then errs[#errs + 1] = lot.name .. "." .. key .. " : devrait être " .. tostring(base[key]) end
      else
        pairs_[#pairs_ + 1] = { key, R.block_of(base[key]), lot[key] }
      end
    end
  else
    pairs_[1] = { "", R.block_of(base), lot }
  end
  for _, p in ipairs(pairs_) do
    local where, bb, lt = lot.name .. (p[1] ~= "" and ("." .. p[1]) or ""), p[2], p[3]
    if type(lt) ~= "table" then
      errs[#errs + 1] = where .. " : bloc absent"
    else
      local lb = R.block_of(lt)
      if not near(lb.energy_required, bb.energy_required * k) then
        errs[#errs + 1] = string.format("%s.energy_required : %s pour %s x %d", where, tostring(lb.energy_required),
          tostring(bb.energy_required), k)
      end
      if lt.hidden ~= true then errs[#errs + 1] = where .. " : non cachée" end
      if lt.enabled ~= false then errs[#errs + 1] = where .. " : active dès le départ" end
      cmp_list(errs, where .. ".ingredients", bb.ingredients, lb.ingredients, k, { "amount", "catalyst_amount" })
      cmp_list(errs, where .. ".results", bb.results, lb.results, k, { "amount", "amount_min", "amount_max", "catalyst_amount" })
    end
  end
  return errs
end

--- Contrôle de toutes les recettes de lots de `recipes` (data.raw.recipe). Renvoie lots, bases, écarts.
function R.verify(recipes)
  local names = {}
  for name in pairs(recipes or {}) do
    if R.is_lot(name) then names[#names + 1] = name end
  end
  table.sort(names)
  local errs, bases, nb = {}, {}, 0
  for _, name in ipairs(names) do
    local base = R.parse(name)
    local b = recipes[base]
    if not b then
      errs[#errs + 1] = name .. " : recette de base « " .. base .. " » absente"
    else
      if not bases[base] then
        bases[base] = true
        nb = nb + 1
      end
      for _, e in ipairs(R.verify_lot(recipes[name], b)) do errs[#errs + 1] = e end
    end
  end
  return #names, nb, errs
end

return R
