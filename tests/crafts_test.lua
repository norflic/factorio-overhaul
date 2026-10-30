--[[
  Tests hors jeu du lot AMELIO-CRAFTS (nuit du 29 au 30/10) : chaînes des âges 2, 3, 6 et 11 en jeu, tirées de X0
  (shared/content/crafts.lua contre shared/content/epochs.lua et shared/content/titanium.lua).

    lua5.2 tests/crafts_test.lua

  Ce que le banc garantit :
    1. tout ce qui vient de X0 est X0 (noms, ingrédients, produits, durées, catégories, bâtiments), écarts marqués ;
    2. aucun ingrédient absent du jeu ; aucune recette « crafting » avec un fluide ;
    3. AUCUNE IMPASSE : chaque objet du lot, et chaque sous-produit de la chaîne du titane, a un consommateur en jeu,
       et toute descendance finit sur un objet vanilla ;
    4. ordre de recherche : chaque ingrédient du mod d'une recette est fabriqué par une recette ouverte par la même
       technologie ou par un de ses prérequis (fermeture transitive) ; âge d'un prérequis <= âge de la technologie ;
    5. les boucles du titane se ferment : par plaque, le béton de Sorel absorbe chlorure de magnésium ET soude à parts
       égales, l'hydrocraquage absorbe l'hydrogène ;
    6. productivité : seulement des recettes « prod » de X0, aucune recette réversible ;
    7. mutants : chaque garantie est cassée une fois et doit être vue.
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(t) print("== " .. t) end

local X = require("shared.content.epochs")
local T = require("shared.content.titanium")
local C = require("shared.content.crafts")

---------------------------------------------------------------------------------------------------
-- Graphe EN JEU des recettes du mod (X1 + ce lot) : { name, ingredients, results, category, unlocked_by }
---------------------------------------------------------------------------------------------------
local function build_graph(Cm)
  local g = { recipes = {}, tech_of = {}, techs = {} }
  local function add(r) g.recipes[#g.recipes + 1] = r end
  for _, rr in ipairs(T.RECIPES) do add(T.process_recipe(rr.name)) end
  for _, b in ipairs(T.BUILDINGS) do
    local r = T.building_recipe(b.name)
    add({ name = b.name, ingredients = r.ingredients, results = { { b.name, 1 } }, category = r.category })
  end
  for _, r in ipairs(Cm.all_recipes()) do add(r) end
  for _, b in ipairs(Cm.BUILDINGS) do
    local r = Cm.building_recipe(b.name)
    add({ name = b.name, ingredients = r.ingredients, results = { { b.name, 1 } }, category = r.category })
  end
  for _, b in ipairs(Cm.POLES or {}) do
    local r = Cm.building_recipe(b.name)
    add({ name = b.name, ingredients = r.ingredients, results = { { b.name, 1 } }, category = r.category })
  end
  for _, b in ipairs(Cm.BEACONS or {}) do
    local r = Cm.building_recipe(b.name)
    add({ name = b.name, ingredients = r.ingredients, results = { { b.name, 1 } }, category = r.category })
  end
  local function addt(t, epoch)
    g.techs[t.name] = { name = t.name, epoch = epoch, prereq = t.prerequisites, unlocks = t.unlocks }
    for _, u in ipairs(t.unlocks) do
      g.tech_of[u] = g.tech_of[u] or {}
      table.insert(g.tech_of[u], t.name)
    end
  end
  for _, t in ipairs(T.TECHS) do addt(t, 11) end
  for _, t in ipairs(Cm.TECHS) do addt(t, t.epoch) end
  return g
end

--- Fermeture des prérequis d'une technologie (prérequis du mod seulement ; les vanilla sont des feuilles).
local function closure(g, name, acc)
  acc = acc or {}
  if acc[name] then return acc end
  acc[name] = true
  local t = g.techs[name]
  for _, p in ipairs(t and t.prereq or {}) do closure(g, p, acc) end
  return acc
end

--- Contrôles du graphe ; renvoie la liste des fautes (texte), vide si tout va.
local function graph_faults(Cm)
  local g = build_graph(Cm)
  local faults = {}
  local function fault(s) faults[#faults + 1] = s end
  local makers, users = {}, {}
  for _, r in ipairs(g.recipes) do
    for _, p in ipairs(r.results or {}) do makers[p[1]] = makers[p[1]] or {}; table.insert(makers[p[1]], r.name) end
    for _, i in ipairs(r.ingredients or {}) do users[i[1]] = users[i[1]] or {}; table.insert(users[i[1]], r.name) end
  end
  -- 2. présence et fluides
  for _, r in ipairs(g.recipes) do
    for _, i in ipairs(r.ingredients) do
      if not Cm.present(i[1]) then fault(r.name .. " : ingrédient absent du jeu " .. i[1]) end
    end
    for _, p in ipairs(r.results or {}) do
      if not Cm.present(p[1]) then fault(r.name .. " : produit absent du jeu " .. p[1]) end
    end
    if r.category == "crafting" then
      for _, i in ipairs(r.ingredients) do
        local x = T.x_item(i[1])
        if (x and x.type == "fluid") or i[1] == "water" then fault(r.name .. " : fluide en « crafting »") end
      end
    end
  end
  -- 3. aucune impasse : tout objet du mod produit a un consommateur ; ses consommateurs mènent à du vanilla.
  -- Objets du mod déjà en jeu avant X1 (tungstène, cristal, méthane : shared/content/world.lua) : leurs recettes et
  -- débouchés sont hors de ce graphe ; un bâtiment posé est un usage final.
  local outside, building = {}, {}
  for _, n in ipairs(T.ALREADY) do outside[n] = true end
  for _, bb in ipairs(T.BUILDINGS) do building[bb.name] = true end
  for _, bb in ipairs(Cm.BUILDINGS) do building[bb.name] = true end
  for _, tt in ipairs(Cm.TILES or {}) do building[tt.name] = true end -- un sol posé : usage final
  for _, bb in ipairs(Cm.BEACONS or {}) do building[bb.name] = true end
  for _, pp in ipairs(Cm.POLES or {}) do building[pp.name] = true end
  local function leads_to_vanilla(name, seen)
    if not name:find("^fo%-") or outside[name] or building[name] then return true end
    seen = seen or {}
    if seen[name] then return false end
    seen[name] = true
    for _, rn in ipairs(users[name] or {}) do
      for _, r in ipairs(g.recipes) do
        if r.name == rn then
          for _, p in ipairs(r.results or {}) do
            if p[1] ~= name and leads_to_vanilla(p[1], seen) then return true end
          end
        end
      end
    end
    return false
  end
  local products = {}
  for _, r in ipairs(g.recipes) do
    for _, p in ipairs(r.results or {}) do
      local is_building = false
      for _, b in ipairs(T.BUILDINGS) do if b.name == p[1] then is_building = true end end
      for _, b in ipairs(Cm.BUILDINGS) do if b.name == p[1] then is_building = true end end
      for _, tt in ipairs(Cm.TILES or {}) do if tt.name == p[1] then is_building = true end end
      for _, bb in ipairs(Cm.BEACONS or {}) do if bb.name == p[1] then is_building = true end end
      for _, pp in ipairs(Cm.POLES or {}) do if pp.name == p[1] then is_building = true end end
      if p[1]:find("^fo%-") and not is_building and not products[p[1]] then products[p[1]] = true end
    end
  end
  local names = {}
  for n in pairs(products) do names[#names + 1] = n end
  table.sort(names)
  -- La plaque de titane est aussi la monnaie de l'âge 11 ; le minerai et la saumure sont minés : ils ont un débouché.
  for _, n in ipairs(names) do
    if not users[n] then fault(n .. " : aucun consommateur en jeu (impasse)")
    elseif not leads_to_vanilla(n) then fault(n .. " : sa descendance ne mène à aucun objet vanilla") end
  end
  -- 4. ordre de recherche
  for _, r in ipairs(g.recipes) do
    for _, tn in ipairs(g.tech_of[r.name] or {}) do
      local cl = closure(g, tn)
      for _, i in ipairs(r.ingredients) do
        -- une torchère (aucun produit) ouverte avant son fluide est sans effet : exemptée
        if i[1]:find("^fo%-") and makers[i[1]] and not outside[i[1]] and #(r.results or {}) > 0 then
          local ok = false
          for _, m in ipairs(makers[i[1]]) do
            for _, mt in ipairs(g.tech_of[m] or {}) do if cl[mt] then ok = true end end
          end
          -- minerais du mod (tungstène, ilménite, saumure, cristal, méthane) : minés, toujours accessibles
          if not ok then fault(r.name .. " (" .. tn .. ") : " .. i[1] .. " n'est fabriqué par aucune technologie prérequise") end
        end
      end
      local t = g.techs[tn]
      for _, p in ipairs(t.prereq) do
        local pt = g.techs[p]
        if pt and pt.epoch > t.epoch then fault(tn .. " : prérequis " .. p .. " d'un âge plus tardif") end
      end
    end
  end
  for _, r in ipairs(Cm.all_recipes()) do
    if not g.tech_of[r.name] then fault(r.name .. " : ouverte par aucune technologie") end
  end
  for _, b in ipairs(Cm.BUILDINGS) do
    if not g.tech_of[b.name] then fault(b.name .. " : bâtiment ouvert par aucune technologie") end
  end
  for _, b in ipairs(Cm.BEACONS or {}) do
    if not g.tech_of[b.name] then fault(b.name .. " : balise ouverte par aucune technologie") end
  end
  for _, b in ipairs(Cm.POLES or {}) do
    if not g.tech_of[b.name] then fault(b.name .. " : poteau ouvert par aucune technologie") end
  end
  -- chaque catégorie d'une recette du lot est faite par une machine en jeu (ou vanilla)
  local cats = { crafting = true, ["crafting-with-fluid"] = true, chemistry = true, ["advanced-crafting"] = true, smelting = true }
  for _, b in ipairs(T.BUILDINGS) do for _, c in ipairs(T.x_building(b.name).categories) do cats[c] = true end end
  for _, b in ipairs(Cm.BUILDINGS) do for _, c in ipairs(T.x_building(b.name).categories) do cats[c] = true end end
  for _, r in ipairs(Cm.all_recipes()) do
    if not cats[r.category] then fault(r.name .. " : catégorie " .. r.category .. " sans machine en jeu") end
  end
  return faults
end

---------------------------------------------------------------------------------------------------
section("1. Ce qui vient de X0 est X0")
---------------------------------------------------------------------------------------------------
for _, n in ipairs(C.ITEMS) do
  local x = T.x_item(n)
  check(x and x.type == "item", n .. " : objet de X0")
  local dup = false
  for _, m in ipairs(T.ITEMS) do if m == n then dup = true end end
  for _, m in ipairs(T.ALREADY) do if m == n then dup = true end end
  check(not dup, n .. " : pas déjà créé par X1 ni par world.lua (aucun doublon)")
end
for _, b in ipairs(C.BUILDINGS) do
  local x = T.x_building(b.name)
  check(x and (x.proto == "assembling-machine" or b.as_assembler) and x.size[1] == x.size[2], b.name .. " : machine carrée de X0")
  check(x and x.size[1] <= X.LIMITS.new_building_side_max, b.name .. " : 10 × 10 au plus")
end
for _, rr in ipairs(C.RECIPES) do
  local x = T.x_recipe(rr.name)
  local r = C.process_recipe(rr.name)
  local drop = {}
  for _, d in ipairs(rr.drop or {}) do drop[d] = true end
  check(x and r.time == x.time and r.category == (rr.category or x.category) and #r.ingredients + #(rr.drop or {}) == #x.ingredients
    and (r.results == x.results or (rr.results ~= nil and type(rr.ecart) == "string")),
    rr.name .. " : durée, catégorie, produits de X0 (écarts marqués seulement)")
  if rr.results then
    -- écart de rendement : mêmes produits que X0, quantités changées seulement
    local same_names = #rr.results == #x.results
    for i, p in ipairs(rr.results) do if not x.results[i] or x.results[i][1] ~= p[1] then same_names = false end end
    check(same_names, rr.name .. " : écart de rendement seulement (mêmes produits que X0)")
  end
  local same, k = true, 0
  for _, ing in ipairs(x.ingredients) do
    if not drop[ing[1]] then
      k = k + 1
      local to = rr.subst and rr.subst[ing[1]]
      if not r.ingredients[k] or r.ingredients[k][1] ~= (to or ing[1]) or r.ingredients[k][2] ~= ing[2] then same = false end
    end
  end
  check(same, rr.name .. " : ingrédients de X0 (substitutions marquées seulement)")
  for _, s in ipairs(r.subst) do
    check(not T.present(s[1]) and not s[2]:find("^fo%-"), rr.name .. " : substitution " .. s[1] .. " -> " .. s[2] .. " (absent -> vanilla)")
  end
  if #(x.results) > 1 then
    local found = false
    for _, p in ipairs(x.results) do if p[1] == rr.main then found = true end end
    check(found, rr.name .. " : produit principal parmi les produits")
  end
end
for _, e in ipairs(C.EXTRA_RECIPES) do
  check(T.x_recipe(e.name) == nil, e.name .. " : hors X0 (aucun nom de X0 repris)")
  check(e.time > X.LIMITS.energy_required_min, e.name .. " : durée > 0,001")
  if e.x3 then
    -- recette du scénario X3 reprise telle quelle
    local X3 = require("shared.content.x3")
    local x3r
    for _, r in ipairs(X3.recipes) do if r.name == e.name then x3r = r end end
    local same = x3r ~= nil and x3r.time == e.time and x3r.category == e.category and #x3r.ingredients == #e.ingredients
      and #x3r.results == #e.results
    for i, ing in ipairs(x3r and x3r.ingredients or {}) do
      local m = e.ingredients[i]
      if not m or m[1] ~= ing[1] or m[2] ~= ing[2] or m.catalyst ~= ing.catalyst then same = false end
    end
    for i, p in ipairs(x3r and x3r.results or {}) do
      local m = e.results[i]
      if not m or m[1] ~= p[1] or m[2] ~= p[2] or m.catalyst ~= p.catalyst then same = false end
    end
    check(same, e.name .. " : recette de X3 reprise telle quelle")
    check(x3r and x3r.variant_of == e.main, e.name .. " : variante de X3 d'un objet du lot (" .. tostring(e.main) .. ")")
  else
    for _, p in ipairs(e.results) do check(not p[1]:find("^fo%-"), e.name .. " : produit vanilla (" .. p[1] .. ")") end
  end
end
for _, t in ipairs(C.TECHS) do
  if t.x0 then
    local x = T.x_tech(t.x0)
    check(x ~= nil, t.name .. " : technologie X0 " .. t.x0)
    if x and t.x0 == t.name then
      check(x.epoch == t.epoch, t.name .. " : âge de X0 (" .. tostring(x and x.epoch) .. ")")
      -- déblocages X0 en jeu : tous repris
      local mine = {}
      for _, u in ipairs(t.unlocks) do mine[u] = true end
      for _, u in ipairs(x.unlocks) do
        if C.present(u) or T.x_recipe(u) and C.present((T.x_recipe(u).results[1] or {})[1] or "") then
          check(mine[u], t.name .. " : déblocage X0 en jeu repris (" .. u .. ")")
        end
      end
      for _, p in ipairs(x.prereq) do
        local mine_p = false
        for _, q in ipairs(t.prerequisites) do if q == p then mine_p = true end end
        check(mine_p, t.name .. " : prérequis X0 repris (" .. p .. ")")
      end
    end
  end
  local packs = C.packs(t.epoch)
  check(#packs >= 2 and packs[1] == "automation-science-pack", t.name .. " : packs vanilla de l'âge " .. t.epoch)
  for _, p in ipairs(packs) do check(not p:find("^fo%-"), t.name .. " : aucun pack du mod (" .. p .. ")") end
  check(C.tech_count(t) >= 10, t.name .. " : au moins 10 unités")
end
for _, t in ipairs(C.TILES) do
  local x = C.x_tile(t.name)
  check(x ~= nil and T.x_item(t.name) and T.x_item(t.name).use == "tile", t.name .. " : sol et objet de X0")
  check(x and x.walking_speed_modifier and x.vehicle_friction_modifier, t.name .. " : modificateurs de X0")
  check(t.layer and t.layer > 0 and t.layer ~= 61 and t.layer ~= 62 and t.layer ~= 64 and t.layer ~= 65,
    t.name .. " : couche libre parmi les sols vanilla posables")
end
for _, b in ipairs(C.BEACONS) do
  local x = T.x_building(b.name)
  check(x and x.proto == "beacon" and x.slots and x.distribution and x.supply_distance and x.kw, b.name .. " : balise de X0 (stats complètes)")
end
do
  local lr = C.building_recipe("fo-lapidary")
  local w, coke, carb = 0, 0, false
  for _, i in ipairs(lr.ingredients) do
    if i[1] == "fo-tungsten-plate" then w = i[2] elseif i[1] == "fo-coke" then coke = i[2] elseif i[1] == "fo-tungsten-carbide" then carb = true end
  end
  check(not carb and w == 15 and coke == 3, "taillerie : carbure déplié en 15 tungstènes et 3 cokes (" .. w .. ", " .. coke .. ")")
end
for _, p in ipairs(C.POLES) do
  local x = T.x_building(p.name)
  check(x and x.proto == "electric-pole" and x.wire_distance and x.wire_distance <= 64 and x.supply_distance,
    p.name .. " : poteau de X0, portée des fils au plus 64 (plafond du moteur)")
end
check(#C.new_categories() == 8, "8 catégories neuves (" .. table.concat(C.new_categories(), ", ") .. ")")

---------------------------------------------------------------------------------------------------
section("2 à 4. Graphe en jeu : présence, impasses, ordre de recherche")
---------------------------------------------------------------------------------------------------
local faults = graph_faults(C)
for _, f in ipairs(faults) do print("    " .. f) end
check(#faults == 0, "graphe en jeu sans faute (" .. #faults .. ")")

---------------------------------------------------------------------------------------------------
section("5. Boucles du titane fermées")
---------------------------------------------------------------------------------------------------
do
  local function amount(r, name, list)
    for _, p in ipairs(r[list]) do if p[1] == name then return p[2] end end
    return 0
  end
  local brine = T.process_recipe("fo-brine-electrolysis")
  local chl = T.process_recipe("fo-chlorination")
  local kroll = T.process_recipe("fo-kroll-reduction")
  local mg = T.process_recipe("fo-magnesium-electrolysis")
  local sorel = C.process_recipe("fo-sorel-concrete")
  local hc = C.process_recipe("fo-hydrocracking")
  -- Par plaque : chlore net = chloration - électrolyse du MgCl2 de Kroll ; électrolyses de saumure b = net / Cl par saumure
  local cl_net = amount(chl, "fo-chlorine", "ingredients") - amount(kroll, "fo-magnesium-chloride", "results") * amount(mg, "fo-chlorine", "results")
  local b = cl_net / amount(brine, "fo-chlorine", "results")
  local mgcl2 = b * amount(brine, "fo-magnesium-chloride", "results")
  local soda = b * amount(brine, "fo-caustic-soda", "results")
  local h2 = b * amount(brine, "fo-hydrogen", "results")
  check(math.abs(b - 0.75) < 1e-9, "0,75 électrolyse de saumure par plaque (" .. b .. ")")
  check(mgcl2 > 0 and soda > 0 and h2 > 0, "sous-produits par plaque : " .. mgcl2 .. " MgCl2, " .. soda .. " soude, " .. h2 .. " H2")
  local s_mg, s_soda = amount(sorel, "fo-magnesium-chloride", "ingredients"), amount(sorel, "fo-caustic-soda", "ingredients")
  check(s_mg > 0 and s_mg / s_soda == mgcl2 / soda,
    "béton de Sorel : chlorure et soude à la proportion où la saumure les laisse (" .. s_mg .. ":" .. s_soda .. ")")
  check(amount(hc, "fo-hydrogen", "ingredients") > 0, "hydrocraquage : consomme l'hydrogène")
  -- Rendement : l'hydrocraquage fait mieux que le craquage vanilla (40 lourde -> 30 légère).
  check(amount(hc, "light-oil", "results") / amount(hc, "heavy-oil", "ingredients") > 30 / 40,
    "hydrocraquage : rendement meilleur que le craquage vanilla (" .. amount(hc, "light-oil", "results") .. " / 40)")
  -- Laitier : le haut fourneau en rend 1 par acier ; le remblai et le ciment le consomment.
  local bf = C.process_recipe("fo-blast-furnace-steel")
  check(amount(bf, "fo-slag", "results") > 0 and amount(C.process_recipe("fo-slag-landfill"), "fo-slag", "ingredients") > 0
    and amount(C.process_recipe("fo-slag-cement"), "fo-slag", "ingredients") > 0, "laitier : deux débouchés (ciment, remblai)")
  -- Remblai de laitier : moins cher en matière que le remblai vanilla (50 pierres), sans être gratuit.
  check(amount(C.process_recipe("fo-slag-landfill"), "fo-slag", "ingredients") >= 10, "remblai : au moins 10 laitiers")
end

---------------------------------------------------------------------------------------------------
section("5 ter. Âges 8 et 10 (étape 4) : hydrogène, dioxyde de carbone, silicium")
---------------------------------------------------------------------------------------------------
do
  local function amount(r, name, list)
    for _, p in ipairs(r[list]) do if p[1] == name then return p[2] end end
    return 0
  end
  local tech_epoch, tech_of = {}, {}
  for _, t in ipairs(C.TECHS) do
    tech_epoch[t.name] = t.epoch
    for _, u in ipairs(t.unlocks) do tech_of[u] = tech_of[u] or {}; table.insert(tech_of[u], t.name) end
  end
  local function first_epoch(recipe)
    local e = 99
    for _, tn in ipairs(tech_of[recipe] or {}) do e = math.min(e, tech_epoch[tn]) end
    return e
  end
  -- Le reformage fait l'hydrogène à l'âge 8 : un consommateur au même âge (hydrocraquage), et la torchère.
  check(first_epoch("fo-methane-reforming") == 8, "reformage : âge 8")
  check(first_epoch("fo-hydrocracking") <= 8, "hydrocraquage : ouvert dès l'âge 8 (" .. first_epoch("fo-hydrocracking") .. ")")
  check(first_epoch("fo-flare-hydrogen") <= 8, "torchère d'hydrogène : ouverte dès l'âge 8")
  local ref = C.process_recipe("fo-methane-reforming")
  local co2 = amount(ref, "fo-carbon-dioxide", "results")
  local carb = C.process_recipe("fo-slag-carbonation")
  check(co2 > 0 and amount(carb, "fo-carbon-dioxide", "ingredients") > 0, "dioxyde de carbone : consommé par la carbonatation")
  check(first_epoch("fo-flare-carbon-dioxide") == first_epoch("fo-methane-reforming"),
    "dioxyde de carbone : torchère ouverte avec le reformage (aucune usine bloquée)")
  -- Silicium : le silicium pur mange l'hydrogène ; le procédé Siemens mange en plus le chlore (catalyseur, perte nette).
  local ps = C.process_recipe("fo-pure-silicon")
  check(amount(ps, "fo-hydrogen", "ingredients") > 0, "silicium pur : consomme l'hydrogène")
  local sm = C.process_recipe("fo-siemens-silicon")
  local cl_in, cl_out = amount(sm, "fo-chlorine", "ingredients"), amount(sm, "fo-chlorine", "results")
  check(cl_in > cl_out and cl_out > 0, "procédé Siemens : perte nette de chlore (" .. cl_in .. " -> " .. cl_out .. ")")
  for _, i in ipairs(sm.ingredients) do if i[1] == "fo-chlorine" then check(i.catalyst == cl_out, "Siemens : catalyseur déclaré = chlore rendu") end end
  check(amount(sm, "fo-metallurgical-silicon", "ingredients") / amount(sm, "fo-pure-silicon", "results")
    < amount(ps, "fo-metallurgical-silicon", "ingredients") / amount(ps, "fo-pure-silicon", "results"),
    "Siemens : moins de silicium métallurgique par silicium pur que la voie de X0")
  -- Écart de rendement du processeur : 1 au lieu de 2 (monnaie de l'âge 10).
  local cp = C.process_recipe("fo-cleanroom-processor")
  check(amount(cp, "processing-unit", "results") == 1, "processeur en salle blanche : 1 processeur (écart à X0, monnaie)")
  check(amount(T.x_recipe("fo-cleanroom-processor"), "processing-unit", "results") == 2, "X0 en donnait 2")
end

---------------------------------------------------------------------------------------------------
section("5 quater. Billettes ρ8 (étape 5) : même matière que la fonte, débit d'une machine")
---------------------------------------------------------------------------------------------------
do
  local function amount(r, name, list)
    for _, p in ipairs(r[list]) do if p[1] == name then return p[2] end end
    return 0
  end
  for _, m in ipairs({ { "iron", "iron-ore", "iron-plate" }, { "copper", "copper-ore", "copper-plate" },
                       { "tungsten", "fo-tungsten-ore", "fo-tungsten-plate" } }) do
    local conc = C.process_recipe("fo-" .. m[1] .. "-concentrate")
    local bil = C.process_recipe("fo-" .. m[1] .. "-plate-r8")
    local cut = C.process_recipe("fo-" .. m[1] .. "-plate-r8-unpacking")
    local ore = amount(conc, m[2], "ingredients") / amount(conc, "fo-" .. m[1] .. "-concentrate", "results")
      * amount(bil, "fo-" .. m[1] .. "-concentrate", "ingredients") / amount(bil, "fo-" .. m[1] .. "-plate-r8", "results")
      * amount(cut, "fo-" .. m[1] .. "-plate-r8", "ingredients")
    local plates = amount(cut, m[3], "results")
    check(ore == plates and plates == 8, m[1] .. " : " .. ore .. " minerais -> " .. plates .. " plaques (même matière que la fonte vanilla)")
  end
  local by = {}
  for _, r in ipairs(C.rates()) do by[r.recipe] = r end
  check(by["fo-iron-plate-r8"] and by["fo-iron-plate-r8"].machine == "fo-arc-furnace", "billette : au four à arc")
  check(by["fo-iron-concentrate"] and by["fo-iron-concentrate"].machine == "fo-ore-concentrator", "concentré : au concentrateur du titane")
  -- Un four à arc fait autant de plaques que N fours en acier vanilla (fonte du fer : 3,2 s, vitesse 2 -> 37,5 / min).
  local arc = by["fo-iron-plate-r8"].per_min * 8
  check(arc / 37.5 > 20, string.format("un four à arc : %.0f plaques / min, %.0f fours en acier", arc, arc / 37.5))
  for _, r in ipairs(C.rates()) do
    check(r.machine ~= nil and r.speed ~= nil, r.recipe .. " : machine de référence (" .. tostring(r.machine) .. ")")
  end
end

---------------------------------------------------------------------------------------------------
section("5 bis. Calcul : chaque variante économise une matière sur la recette vanilla")
---------------------------------------------------------------------------------------------------
do
  local rows = C.bilan()
  local function f(t)
    local o = {}
    for _, m in ipairs(C.RAW_ORDER) do if (t[m] or 0) > 0 then o[#o + 1] = string.format("%s %.2f", m, t[m]) end end
    return #o > 0 and table.concat(o, ", ") or "rien (sous-produit)"
  end
  check(#rows >= 9, #rows .. " variantes chiffrées")
  for _, r in ipairs(rows) do
    print(string.format("    %-26s %-22s variante : %s | vanilla : %s", r.recipe, r.product, f(r.variant), f(r.vanilla)))
    check(#r.saves >= 1, r.recipe .. " : économise au moins une matière (" .. table.concat(r.saves, ", ") .. ")")
    -- Gratuite seulement si elle ne consomme qu'un sous-produit (puits voulu : remblai de laitier).
    local any = false
    for _, m in ipairs(C.RAW_ORDER) do if (r.variant[m] or 0) > 0 then any = true end end
    check(any or r.recipe == "fo-slag-landfill", r.recipe .. " : jamais gratuite, sauf le puits du laitier")
  end
  -- Valeurs attendues (recalcul à la main, BALANCE_SHEET) : acier au haut fourneau 4 fers + 1,5 charbon ; acier
  -- électrique 3 fers + 2 charbons ; polyéthylène 6,67 gaz par plastique (vanilla 10).
  local by = {}
  for _, r in ipairs(rows) do by[r.recipe] = r end
  check(by["fo-blast-furnace-steel"] and math.abs(by["fo-blast-furnace-steel"].variant["fer"] - 4) < 1e-9
    and math.abs(by["fo-blast-furnace-steel"].variant["charbon"] - 1.5) < 1e-9, "acier au haut fourneau : 4 fers + 1,5 charbon")
  check(by["fo-arc-steel"] and math.abs(by["fo-arc-steel"].variant["fer"] - 3) < 1e-9
    and math.abs(by["fo-arc-steel"].variant["charbon"] - 2) < 1e-9, "acier électrique : 3 fers + 2 charbons")
  check(by["fo-polyethylene"] and math.abs(by["fo-polyethylene"].variant["gaz"] - 20 / 3) < 1e-9, "polyéthylène : 6,67 gaz par plastique")
  -- Processeur en salle blanche : 10 circuits verts au lieu de 20 ; le reste (2 rouges, 5 acides) inchangé.
  local cp = by["fo-cleanroom-processor"]
  check(cp and cp.variant["acide"] == 5 and cp.vanilla["acide"] == 5, "processeur : 5 acides, comme vanilla")
  check(cp and cp.vanilla["fer"] - cp.variant["fer"] > 9.99 and cp.vanilla["fer"] - cp.variant["fer"] < 10.01,
    "processeur en salle blanche : 10 fers de moins (10 circuits verts)")
end

---------------------------------------------------------------------------------------------------
section("5 quinquies. Biais : effet des variantes sur les monnaies des niveaux (MU des matières premières)")
---------------------------------------------------------------------------------------------------
do
  local L = require("shared.levels.config")
  local rows = C.currency_impact(L.epoch_materials)
  check(#rows >= 4, #rows .. " variante(s) d'une monnaie")
  local worst = 0
  for _, r in ipairs(rows) do
    print(string.format("    âge %2d %-22s %-26s vanilla %6.2f MU, variante %6.2f MU (%+.0f %%)", r.epoch, r.item, r.recipe,
      r.vanilla_mu, r.variant_mu, 100 * r.delta))
    worst = math.min(worst, r.delta)
  end
  -- Garde-fou : aucune variante ne fait baisser le coût en matière d'une monnaie de plus de 40 % (le processeur de X0 à
  -- 2 par fabrication : environ -65 %, refusé ; à 1 : -33 %, gardé et signalé au DC ; le polyéthylène, -33 % sur le plastique).
  check(worst > -0.40, string.format("aucune monnaie moins chère de plus de 40 %% (pire : %+.0f %%)", 100 * worst))
end

---------------------------------------------------------------------------------------------------
section("6. Productivité")
---------------------------------------------------------------------------------------------------
do
  local prod = C.productivity_recipes()
  check(#prod >= 1, #prod .. " recette(s) éligibles")
  local makes = {}
  for _, r in ipairs(C.all_recipes()) do for _, p in ipairs(r.results) do makes[p[1]] = makes[p[1]] or {}; makes[p[1]][r.name] = true end end
  for _, name in ipairs(prod) do
    local r = C.process_recipe(name)
    check(r.x0 and r.prod, name .. " : « prod » dans X0")
    -- réversible : un produit de r refait un ingrédient de r par une recette du lot
    local rev = false
    for _, p in ipairs(r.results) do
      for _, r2 in ipairs(C.all_recipes()) do
        for _, i2 in ipairs(r2.ingredients) do
          if i2[1] == p[1] then
            for _, p2 in ipairs(r2.results) do
              for _, i in ipairs(r.ingredients) do if p2[1] == i[1] then rev = true end end
            end
          end
        end
      end
    end
    check(not rev, name .. " : non réversible")
  end
  for _, e in ipairs(C.EXTRA_RECIPES) do
    local found = false
    for _, n in ipairs(prod) do if n == e.name then found = true end end
    check(not found, e.name .. " : hors X0, jamais en productivité")
  end
end

---------------------------------------------------------------------------------------------------
section("7. Mutants : chaque garantie du graphe voit sa faute")
---------------------------------------------------------------------------------------------------
do
  local function mutant(label, mutate)
    local Cm = {}
    for k, v in pairs(C) do Cm[k] = v end
    local function deep(t)
      if type(t) ~= "table" then return t end
      local o = {}
      for k, v in pairs(t) do o[k] = deep(v) end
      return o
    end
    Cm.TECHS = deep(C.TECHS)
    Cm.EXTRA_RECIPES = deep(C.EXTRA_RECIPES)
    local extra_by = {}
    Cm.all_recipes = function()
      local out = {}
      for _, rr in ipairs(C.RECIPES) do out[#out + 1] = C.process_recipe(rr.name) end
      for _, e in ipairs(Cm.EXTRA_RECIPES) do
        out[#out + 1] = { name = e.name, category = e.category, time = e.time, ingredients = e.ingredients,
                          results = e.results, x0 = false, subst = {} }
      end
      return out
    end
    mutate(Cm)
    local f = graph_faults(Cm)
    check(#f > 0, "mutant « " .. label .. " » vu (" .. (f[1] or "aucune faute") .. ")")
  end
  mutant("sans remblai ni ciment : le laitier n'a plus de débouché", function(Cm)
    for _, e in ipairs(Cm.EXTRA_RECIPES) do if e.name == "fo-slag-landfill" then e.ingredients = { { "stone", 50 } } end end
    local keep = {}
    for _, rr in ipairs(C.RECIPES) do if rr.name ~= "fo-slag-cement" then keep[#keep + 1] = rr end end
    Cm.all_recipes = (function(prev)
      return function()
        local out = {}
        for _, r in ipairs(prev()) do if r.name ~= "fo-slag-cement" then out[#out + 1] = r end end
        return out
      end
    end)(Cm.all_recipes)
  end)
  mutant("sans composite : la plaque de titane redevient une impasse (état d'avant le lot)", function(Cm)
    Cm.all_recipes = (function(prev)
      return function()
        local out = {}
        for _, r in ipairs(prev()) do if r.name ~= "fo-titanium-composite" and r.name ~= "fo-titanium-lds" then out[#out + 1] = r end end
        return out
      end
    end)(Cm.all_recipes)
  end)
  mutant("composite sans le titane ni le graphite en prérequis", function(Cm)
    for _, t in ipairs(Cm.TECHS) do
      if t.name == "fo-titanium-alloys" then t.prerequisites = { "low-density-structure" } end
    end
  end)
  mutant("tôle magnétique sans le concassage (sable)", function(Cm)
    for _, t in ipairs(Cm.TECHS) do
      if t.name == "fo-electrical-steel" then t.prerequisites = { "fo-arc-smelting", "electric-engine", "plastics" } end
    end
  end)
  mutant("silicium sans le reformage (hydrogène d'aucun prérequis)", function(Cm)
    for _, t in ipairs(Cm.TECHS) do
      if t.name == "fo-silicon" then t.prerequisites = { "fo-electrical-steel", "fo-glassworks", "sulfur-processing" } end
    end
  end)
  mutant("sans carbonatation ni torchère : le dioxyde de carbone devient une impasse", function(Cm)
    Cm.all_recipes = (function(prev)
      return function()
        local out = {}
        for _, r in ipairs(prev()) do if r.name ~= "fo-slag-carbonation" and r.name ~= "fo-flare-carbon-dioxide" then out[#out + 1] = r end end
        return out
      end
    end)(Cm.all_recipes)
  end)
  mutant("prérequis d'un âge plus tardif", function(Cm)
    for _, t in ipairs(Cm.TECHS) do
      if t.name == "fo-coking" then t.prerequisites = { "fo-arc-smelting" } end
    end
  end)
  mutant("recette ouverte par aucune technologie", function(Cm)
    for _, t in ipairs(Cm.TECHS) do
      if t.name == "fo-crushing" then t.unlocks = { "fo-crusher", "fo-slag-cement" } end
    end
  end)
  mutant("ingrédient absent du jeu", function(Cm)
    for _, e in ipairs(Cm.EXTRA_RECIPES) do if e.name == "fo-hydrocracking" then e.ingredients = { { "fo-biopolymer", 1 } } end end
  end)
  mutant("fluide dans une recette « crafting »", function(Cm)
    for _, e in ipairs(Cm.EXTRA_RECIPES) do
      if e.name == "fo-slag-landfill" then e.ingredients = { { "fo-slag", 20 }, { "fo-hydrogen", 10 } } end
    end
  end)
  mutant("catégorie sans machine en jeu", function(Cm)
    for _, e in ipairs(Cm.EXTRA_RECIPES) do if e.name == "fo-hydrocracking" then e.category = "fo-cryogenics" end end
  end)
end

print(string.format("\n[CRAFTS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
