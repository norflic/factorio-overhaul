--[[
  Lot INDUSTRIE I4 « lecture générique » : ce que le jeu permet de FABRIQUER ET D'AUTOMATISER, lu dans les prototypes et
  jamais écrit (PUR : aucune API Factorio ; aucun nom d'objet, de machine ou de catégorie, soumis à l'anti-échelle de
  tests/iag_test.lua §8). Un mod qui ajoute une machine, une catégorie de fabrication ou un objet à 3 entrées y entre sans
  une ligne de code : la preuve est tests/industrie_lecture_test.lua (noms permutés, mini-mod inventé) puis le banc
  `ind-lecture` et la copie jetable (tools/autotest/ind/jetable.py).

  Entrée : le relevé des prototypes de shared/ai3/catalogue.lua (General.dump), champs ajoutés par ce lot
    entités de fabrication : w, h (emprise en tuiles), ingredient_count (ingrédients SOLIDES au plus ; absent : le moteur
      n'impose rien, 255 par défaut), fixed_recipe, boxes = { { type = "input" | "output" | "input-output", filter,
      conns = { [0|2|4|6] = {{x, y}} } } } (boîtes à fluide, raccords par direction) ;
    entités du kit (R.KIT_TYPE) : bras = pickup, drop ({x, y}), rot, ext, filters, stack ; tapis = belt_speed ;
      coffre = slots ; poteau = supply, wire.

  L.read(dump, opts) -> fab, machines
    fab[recette] = {
      category, energy (durée d'une fabrication, en s), main (la main la fait : catégorie permise, aucun fluide),
      solides = { {name, amount} }, fluides_in = { ... }, fluides_out = { ... }, produits = { noms }, s = #solides,
      machines = { {entity, item, speed, w, h, par_min, ...} } : machines qui PEUVENT fabriquer la recette ET qu'un patron
        peut poser, du moins rapide au plus rapide (égalité : le nom) ; VIDE si la recette est refusée,
      refus = nil | { code, texte } : raison écrite d'un refus, jamais silencieux,
      sorties_solides = nombre de produits solides,
      patronnable = vrai quand `machines` n'est pas vide et qu'aucune limite du patron n'est franchie }
    Les recettes cachées n'y sont pas (dont les recettes par lots `fo-lot*`, F219) ; opts.known = ensemble des recettes
    connues de l'équipe (absent : toutes les non cachées) ; opts.hand = ensemble des catégories de la main.
    machines = liste des machines de fabrication posables (celles qui ont un objet), triée comme ci-dessus.
  L.summary(fab) -> { total, patronnables, main, refus = { [code] = n }, exemples = { [code] = { recettes } }, par_s = { [s] = n } }
  L.line(sum, nmachines) -> la ligne du journal [FO-IND-LECTURE]
  L.machines_for(entry, usable) -> machines de l'entrée dont l'objet est utilisable (`usable` : fonction, ensemble ou nil)
  L.kit_data(dump) / L.kit(data, usable) -> { bras, bras_long, tapis, coffre, poteau, manque = { clés absentes } } : la
    pièce la moins chère disponible PAR TYPE (prix = coût en ingrédients dépliés des recettes du relevé).

  Limites écrites (L.MAX_SOLIDES, L.MAX_COTE), avec leur raison ; un refus garde le mot « limite » et le nombre.
  Déterminisme : relevé parcouru dans l'ordre des noms ; aucun pairs décisionnel.
]]

local R = require("shared.ai3.reglages")

local L = {}

-- Un patron (shared/team/patrons.lua, lot I5) pose au plus 4 tapis et 4 bras d'entrée : 8 voies solides (PLAN INDUSTRIE §2,
-- tableau « s »). Au-delà : refus écrit (0 cas sur 307 recettes du relevé de référence).
L.MAX_SOLIDES = 8
-- Côté de machine au plus : le lot utile du treillis fait 22 × 22 (P.fit, marge 1 comprise) ; une cellule ajoute une
-- rangée de bras et une de tapis de chaque côté (4 tuiles) : 22 - 4 = 18.
L.MAX_COTE = 18
-- Ingrédients solides quand le moteur ne dit rien (valeur par défaut de `ingredient_count` dans la doc des prototypes).
L.CAP_DEFAUT = 255

-- Prix d'une pièce du kit qu'aucune recette ne fabrique : elle ne passe qu'en dernier recours.
L.SANS_RECETTE = 1e9

L.REFUS = { "sans_entree", "categorie", "entrees_machine", "fluide_entree", "fluide_sortie", "entrees_max", "taille",
  "sans_produit_solide" }

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

---------------------------------------------------------------------------------------------------
-- Machines de fabrication
---------------------------------------------------------------------------------------------------
local function by_speed(a, b)
  if a.speed ~= b.speed then return a.speed < b.speed end
  return a.entity < b.entity
end

--- Machines de fabrication posables du relevé, triées.
function L.machines(dump)
  local out = {}
  for _, e in ipairs(dump.entities or {}) do
    if R.ENTITY_ROLE[e.type or ""] == "fabrique" and e.item and e.crafting_categories and #e.crafting_categories > 0 then
      local cats = {}
      for _, c in ipairs(e.crafting_categories) do cats[c] = true end
      -- le type dit le plafond quand le moteur ne le dit pas (le four) ; sinon `ingredient_count`, sinon la valeur par défaut
      local cap = R.SOURCE_CAP[e.type] or e.ingredient_count
      out[#out + 1] = { entity = e.name, item = e.item, type = e.type, speed = e.speed or 1, w = e.w, h = e.h,
        cap = cap or L.CAP_DEFAUT, fixed = e.fixed_recipe, energy = e.energy or "none", cats = cats, boxes = e.boxes or {} }
    end
  end
  table.sort(out, by_speed)
  return out
end

--- Les `names` (fluides d'un sens) tiennent-ils dans les boîtes `kind` de la machine ? Une boîte à filtre ne prend que son
--- fluide ; une boîte « input-output » n'est comptée dans aucun sens (prudence).
local function fluids_fit(m, kind, names)
  local left, n_left, free = {}, #names, 0
  for _, nm in ipairs(names) do left[nm] = true end
  for _, b in ipairs(m.boxes) do
    if b.type == kind then
      if b.filter then
        if left[b.filter] then
          left[b.filter] = nil
          n_left = n_left - 1
        end
      else
        free = free + 1
      end
    end
  end
  return n_left <= free
end

local function count_boxes(m, kind)
  local n = 0
  for _, b in ipairs(m.boxes) do if b.type == kind then n = n + 1 end end
  return n
end

local function refus(code, texte) return { code = code, texte = "limite : " .. texte } end

--- Entrée `fab` d'une recette.
function L.entry(name, r, cat_machines, hand)
  local e = { category = r.category, energy = r.energy or 0.5, solides = {}, fluides_in = {}, fluides_out = {}, produits = {},
    machines = {} }
  for _, i in ipairs(r.ingredients or {}) do
    local t = { name = i.name, amount = i.amount or 1 }
    if i.type == "fluid" then e.fluides_in[#e.fluides_in + 1] = t else e.solides[#e.solides + 1] = t end
  end
  local main_amount
  e.sorties_solides = 0
  for _, p in ipairs(r.products or {}) do
    e.produits[#e.produits + 1] = p.name
    if p.type == "fluid" then
      e.fluides_out[#e.fluides_out + 1] = { name = p.name, amount = p.amount or 1 }
    else
      e.sorties_solides = e.sorties_solides + 1
      main_amount = main_amount or p.amount or 1
    end
  end
  e.s = #e.solides
  e.main = (hand ~= nil and hand[r.category] == true) and #e.fluides_in == 0 and #e.fluides_out == 0
  local cands = {}
  for _, m in ipairs(cat_machines or {}) do
    if m.fixed == nil or m.fixed == name then cands[#cands + 1] = m end
  end
  local function fail(rf)
    e.refus = rf
    e.patronnable = false
    return e
  end
  if e.s + #e.fluides_in == 0 then return fail(refus("sans_entree", name .. " n'a aucune entree")) end
  if #cands == 0 then return fail(refus("categorie", "aucune machine pour la categorie " .. tostring(r.category))) end
  local kept, best_cap = {}, 0
  for _, m in ipairs(cands) do
    best_cap = math.max(best_cap, m.cap)
    if m.cap >= e.s then kept[#kept + 1] = m end
  end
  if #kept == 0 then
    return fail(refus("entrees_machine", string.format("%d ingredients solides, les machines de la categorie %s en prennent %d au plus",
      e.s, tostring(r.category), best_cap)))
  end
  local fnames = {}
  for _, f in ipairs(e.fluides_in) do fnames[#fnames + 1] = f.name end
  local fit, max_in = {}, 0
  for _, m in ipairs(kept) do
    max_in = math.max(max_in, count_boxes(m, "input"))
    if fluids_fit(m, "input", fnames) then fit[#fit + 1] = m end
  end
  if #fit == 0 then
    return fail(refus("fluide_entree", string.format("%d fluide(s) en entree, les machines de la categorie %s ont %d boite(s) d'entree au plus",
      #fnames, tostring(r.category), max_in)))
  end
  kept, fit = fit, {}
  local onames, max_out = {}, 0
  for _, f in ipairs(e.fluides_out) do onames[#onames + 1] = f.name end
  for _, m in ipairs(kept) do
    max_out = math.max(max_out, count_boxes(m, "output"))
    if fluids_fit(m, "output", onames) then fit[#fit + 1] = m end
  end
  if #fit == 0 then
    return fail(refus("fluide_sortie", string.format("%d fluide(s) en sortie, les machines de la categorie %s ont %d boite(s) de sortie au plus",
      #onames, tostring(r.category), max_out)))
  end
  if e.s > L.MAX_SOLIDES then
    return fail(refus("entrees_max", string.format("%d entrees solides (%d au plus)", e.s, L.MAX_SOLIDES)))
  end
  kept, fit = fit, {}
  local small
  for _, m in ipairs(kept) do
    local side = math.max(m.w or 1, m.h or 1)
    small = small and math.min(small, side) or side
    if side <= L.MAX_COTE then fit[#fit + 1] = m end
  end
  if #fit == 0 then
    return fail(refus("taille", string.format("la plus petite machine fait %d tuiles de cote (%d au plus)", small or 0, L.MAX_COTE)))
  end
  if e.sorties_solides == 0 then
    return fail(refus("sans_produit_solide", name .. " ne produit aucun objet (sortie en fluide seulement)"))
  end
  for _, m in ipairs(fit) do
    local per_min = 60 * m.speed / math.max(e.energy, 1e-9) * (main_amount or 0)
    e.machines[#e.machines + 1] = { entity = m.entity, item = m.item, type = m.type, speed = m.speed, w = m.w, h = m.h,
      energy = m.energy, boxes = m.boxes, par_min = per_min }
  end
  e.patronnable = true
  return e
end

--- Lecture de toutes les recettes visibles du relevé.
function L.read(dump, opts)
  opts = opts or {}
  local machines = L.machines(dump)
  local by_cat = {}
  for _, m in ipairs(machines) do
    for _, c in ipairs(sorted_keys(m.cats)) do
      by_cat[c] = by_cat[c] or {}
      table.insert(by_cat[c], m)
    end
  end
  local fab = {}
  for _, name in ipairs(sorted_keys(dump.recipes)) do
    local r = dump.recipes[name]
    if not r.hidden and (opts.known == nil or opts.known[name]) then
      fab[name] = L.entry(name, r, by_cat[r.category], opts.hand)
    end
  end
  return fab, machines
end

--- Machines d'une entrée dont l'objet est utilisable (fonction, ensemble ou nil : toutes).
function L.machines_for(entry, usable)
  if usable == nil then return entry.machines end
  local out = {}
  for _, m in ipairs(entry.machines) do
    local ok
    if type(usable) == "function" then ok = usable(m.item) else ok = usable[m.item] end
    if ok then out[#out + 1] = m end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Bilan
---------------------------------------------------------------------------------------------------
function L.summary(fab)
  local sum = { total = 0, patronnables = 0, main = 0, refus = {}, exemples = {}, par_s = {} }
  for _, name in ipairs(sorted_keys(fab)) do
    local e = fab[name]
    sum.total = sum.total + 1
    if e.main then sum.main = sum.main + 1 end
    if e.patronnable then
      sum.patronnables = sum.patronnables + 1
      sum.par_s[e.s] = (sum.par_s[e.s] or 0) + 1
    else
      local c = e.refus.code
      sum.refus[c] = (sum.refus[c] or 0) + 1
      sum.exemples[c] = sum.exemples[c] or {}
      if #sum.exemples[c] < 3 then table.insert(sum.exemples[c], name) end
    end
  end
  return sum
end

--- Ligne du journal [FO-IND-LECTURE] (le préfixe est mis par l'appelant).
function L.line(sum, n_machines)
  local parts = {}
  for _, c in ipairs(sorted_keys(sum.refus)) do
    parts[#parts + 1] = string.format("%s %d (%s)", c, sum.refus[c], table.concat(sum.exemples[c], ","))
  end
  local ss = {}
  for _, s in ipairs(sorted_keys(sum.par_s)) do ss[#ss + 1] = string.format("%d:%d", s, sum.par_s[s]) end
  return string.format("%d recettes lues, %d patronnables (entrees solides:recettes %s), %d faisables a la main, %d machines de fabrication ; refus : %s",
    sum.total, sum.patronnables, table.concat(ss, " "), sum.main, n_machines, #parts > 0 and table.concat(parts, " ; ") or "aucun")
end

---------------------------------------------------------------------------------------------------
-- Kit de logistique : la pièce la moins chère par TYPE
---------------------------------------------------------------------------------------------------
local function reach(v)
  if not v then return nil end
  return math.floor(math.max(math.abs(v.x or v[1] or 0), math.abs(v.y or v[2] or 0)) + 0.5)
end

--- Candidats du kit lus dans le relevé (par type du moteur, R.KIT_TYPE), et le prix de chaque objet.
function L.kit_data(dump)
  local cands = { bras = {}, bras_long = {}, tapis = {}, coffre = {}, poteau = {} }
  for _, e in ipairs(dump.entities or {}) do
    local kind = R.KIT_TYPE[e.type or ""]
    if kind and e.item then
      local c = { entity = e.name, item = e.item, energy = e.energy or "none" }
      if kind == "bras" then
        local rp, rd = reach(e.pickup), reach(e.drop)
        c.reach, c.rot, c.ext, c.stack = rp, e.rot, e.ext, e.stack or 0
        if (e.filters or 0) == 0 and rp and rp == rd then
          if rp == 1 then table.insert(cands.bras, c) elseif rp == 2 then table.insert(cands.bras_long, c) end
        end
      elseif kind == "tapis" then
        c.speed = e.belt_speed
        table.insert(cands.tapis, c)
      elseif kind == "coffre" then
        c.slots = e.slots
        if (e.slots or 0) > 0 then table.insert(cands.coffre, c) end
      else
        c.supply, c.wire = e.supply, e.wire
        table.insert(cands.poteau, c)
      end
    end
  end
  -- Prix : somme des ingrédients dépliés de la recette qui fait l'objet (la première, par nom, non cachée) ; une matière sans
  -- recette vaut 1 ; un cycle vaut 1 à sa deuxième visite.
  local maker = {}
  for _, name in ipairs(sorted_keys(dump.recipes)) do
    local r = dump.recipes[name]
    if not r.hidden then
      for _, p in ipairs(r.products or {}) do if not maker[p.name] then maker[p.name] = name end end
    end
  end
  local memo, busy = {}, {}
  local function price(item)
    if memo[item] then return memo[item] end
    local rn = maker[item]
    if not rn or busy[item] then return 1 end
    busy[item] = true
    local r = dump.recipes[rn]
    local made = 1
    for _, p in ipairs(r.products or {}) do if p.name == item then made = math.max(p.amount or 1, 1e-9) end end
    local total = 0
    for _, i in ipairs(r.ingredients or {}) do total = total + (i.amount or 1) * price(i.name) end
    busy[item] = nil
    memo[item] = total / made
    return memo[item]
  end
  for _, k in ipairs({ "bras", "bras_long", "tapis", "coffre", "poteau" }) do
    -- une pièce qu'aucune recette (non cachée) ne fabrique ne se compte pas parmi les moins chères (moteur réel : le centre de
    -- commandement du mod est un coffre sans recette, il gagnait le choix du coffre)
    for _, c in ipairs(cands[k]) do c.price = maker[c.item] and price(c.item) or L.SANS_RECETTE end
  end
  return { cands = cands }
end

local function cheapest(list, usable)
  local best
  for _, c in ipairs(list) do
    local ok = true
    if usable ~= nil then
      if type(usable) == "function" then ok = usable(c.item) and true or false else ok = usable[c.item] and true or false end
    end
    if ok then
      -- le courant d'abord (un bras à combustible demande un ravitaillement), puis le prix, puis le nom
      local key_c = c.energy == "electric" and 0 or 1
      if not best then
        best = c
      else
        local key_b = best.energy == "electric" and 0 or 1
        if key_c ~= key_b then
          if key_c < key_b then best = c end
        elseif c.price ~= best.price then
          if c.price < best.price then best = c end
        elseif c.entity < best.entity then
          best = c
        end
      end
    end
  end
  return best
end

--- Kit le moins cher parmi les objets utilisables (`usable` : fonction, ensemble ou nil : tous).
function L.kit(data, usable)
  local out, manque = {}, {}
  for _, k in ipairs({ "bras", "bras_long", "tapis", "coffre", "poteau" }) do
    out[k] = cheapest(data.cands[k], usable)
    if not out[k] then manque[#manque + 1] = k end
  end
  out.manque = manque
  return out
end

return L
