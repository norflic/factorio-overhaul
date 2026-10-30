-- Banc hors jeu du lot CALCUL (30/10) : la chaîne du calcul (shared/content/compute.lua) et ses règles de script.
-- Lancement : lua5.2 tests/compute_test.lua   (depuis la racine du mod ou d'un worktree)
-- Sections : 1 sources (X3, X0, plan) ; 2 présence ; 3 graphe (débouchés, âge d'usage) ; 4 ordre de recherche ;
-- 5 calcul (débits, fenêtres, bonus de recherche) ; 6 MU ; 7 productivité ; 8 mutants.

package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local function check(cond, label, detail)
  if cond then pass = pass + 1 else
    fail = fail + 1
    print("ECHEC : " .. label .. (detail and (" (" .. tostring(detail) .. ")") or ""))
  end
end
local function section(t) print("== " .. t) end

local X3 = require("shared.content.x3")
local T = require("shared.content.titanium")
local C = require("shared.content.crafts")
local Sn = require("shared.content.tin")
local B = require("shared.content.bauxite")
local SC = require("shared.content.superconductors")
local Cp = require("shared.content.compute")

---------------------------------------------------------------------------------------------------
-- Technologies connues (lot + lots dont il dépend) : nom -> { epoch, prereq, unlocks }
---------------------------------------------------------------------------------------------------
local function tech_table(CpM)
  local t = {}
  local function add(list, default_epoch)
    for _, x in ipairs(list) do
      t[x.name] = { epoch = x.epoch or default_epoch, prereq = x.prerequisites or {}, unlocks = x.unlocks or {} }
    end
  end
  add(T.TECHS, 11)
  add(C.TECHS)
  add(Sn.TECHS)
  add(B.TECHS)
  add(SC.TECHS, 11)
  t["fo-superconductors"].epoch = 12
  add(CpM.TECHS)
  return t
end

-- Objets d'AUTRES lots consommés ici : la technologie qui les ouvre (vérifiée contre ses déblocages : une recette qui
-- les produit) ; les objets toujours là (minerais et plaques de world.lua, X1 « déjà en jeu ») : nil.
local EXTERNAL = {
  ["fo-silicon-wafer"] = { "fo-silicon", "fo-silicon-wafer" },
  ["fo-glass"] = { "fo-glassworks", "fo-glass" },
  ["fo-tungsten-plate"] = false,
  ["fo-epoxy-resin"] = { "fo-printed-circuits", "fo-epoxy-resin" },
  ["fo-printed-circuit-board"] = { "fo-printed-circuits", "fo-printed-circuit-board" },
  ["fo-tin-plate"] = { "fo-printed-circuits", "fo-tin-plate" },
  ["fo-aluminium-plate"] = { "fo-aluminium", "fo-hall-heroult" },
  ["fo-cut-crystal"] = { "fo-lapidary", "fo-crystal-cutting" },
  ["fo-resonance-lens"] = { "fo-lapidary", "fo-resonance-lens" },
  ["fo-crystal-oscillator"] = { "fo-lapidary", "fo-crystal-oscillator" },
  ["fo-coil"] = { "fo-electrical-steel", "fo-coil" },
  ["fo-titanium-plate"] = { "fo-titanium-processing", "fo-titanium-plate" },
  ["fo-superconducting-tape"] = { "fo-superconductors", "fo-superconducting-tape" },
  ["fo-cryostat"] = { "fo-cryostat", "fo-cryostat" },
  ["fo-liquid-nitrogen"] = { "fo-superconductors", "fo-air-distillation" },
  ["fo-ilmenite-concentrate"] = { "fo-titanium-processing", "fo-ilmenite-concentrate" },
  ["fo-coke"] = { "fo-titanium-processing", "fo-coke" },
}

local function closure(techs, name, acc)
  acc = acc or {}
  if acc[name] then return acc end
  acc[name] = true
  for _, p in ipairs(techs[name] and techs[name].prereq or {}) do closure(techs, p, acc) end
  return acc
end

local function epoch_of_item(CpM, n)
  for _, it in ipairs(CpM.ITEMS) do if it.name == n then return it.epoch end end
  for _, f in ipairs(CpM.FLUIDS) do if f.name == n then return f.epoch end end
  for _, b in ipairs(CpM.BUILDINGS) do if b.name == n then return b.epoch end end
  return nil
end

--- Fautes du graphe en jeu du lot (texte), vide si tout va. CpM : le module (ou un mutant).
local function graph_faults(CpM)
  local faults = {}
  local function fault(s) faults[#faults + 1] = s end
  local techs = tech_table(CpM)
  local recipes = CpM.all_recipes()
  for _, r in ipairs(CpM.building_recipes()) do recipes[#recipes + 1] = r end
  local tech_of, epoch_of_recipe = {}, {}
  for _, t in ipairs(CpM.TECHS) do
    for _, u in ipairs(t.unlocks) do tech_of[u] = t.name; epoch_of_recipe[u] = t.epoch end
  end
  local makers, users = {}, {}
  for _, r in ipairs(recipes) do
    for _, p in ipairs(r.results or {}) do makers[p[1]] = makers[p[1]] or {}; table.insert(makers[p[1]], r.name) end
    for _, i in ipairs(r.ingredients) do users[i[1]] = users[i[1]] or {}; table.insert(users[i[1]], r.name) end
  end
  -- présence
  for _, r in ipairs(recipes) do
    for _, i in ipairs(r.ingredients) do
      if not CpM.present(i[1]) then fault(r.name .. " : ingrédient absent du jeu " .. i[1]) end
      if r.category == "crafting" and CpM.is_fluid(i[1]) then fault(r.name .. " : fluide en « crafting »") end
    end
    for _, p in ipairs(r.results or {}) do
      if not CpM.present(p[1]) then fault(r.name .. " : produit absent du jeu " .. p[1]) end
    end
    if not tech_of[r.name] then fault(r.name .. " : ouverte par aucune technologie du lot") end
  end
  -- chaque catégorie a sa machine en jeu (lot, CRAFTS, étain, X2, X1, vanilla)
  local cats = { crafting = true, ["advanced-crafting"] = true, chemistry = true, ["fo-cleanroom"] = true,
                 ["fo-circuit-printing"] = true, ["fo-cryogenics"] = true, ["fo-sintering"] = true, ["fo-arc-smelting"] = true }
  for _, b in ipairs(CpM.BUILDINGS) do for _, c in ipairs(CpM.building(b.name).categories) do cats[c] = true end end
  for _, r in ipairs(recipes) do if not cats[r.category] then fault(r.name .. " : catégorie " .. tostring(r.category) .. " sans machine") end end
  -- débouchés : chaque objet du lot a un consommateur DE SON ÂGE (ou plus tôt), et mène au calcul, à un bâtiment ou au vanilla
  local own = {}
  for _, it in ipairs(CpM.ITEMS) do own[it.name] = true end
  for _, f in ipairs(CpM.FLUIDS) do own[f.name] = true end
  local building = {}
  for _, b in ipairs(CpM.BUILDINGS) do building[b.name] = true end
  local function leads_out(n, seen)
    if not own[n] or building[n] then return true end
    seen = seen or {}
    if seen[n] then return false end
    seen[n] = true
    for _, rn in ipairs(users[n] or {}) do
      if CpM.compute_per_craft(rn) > 0 then return true end -- consommé par le centre : rend du calcul
      for _, r in ipairs(recipes) do
        if r.name == rn then
          for _, p in ipairs(r.results or {}) do if p[1] ~= n and leads_out(p[1], seen) then return true end end
        end
      end
    end
    return false
  end
  local names = {}
  for n in pairs(own) do names[#names + 1] = n end
  table.sort(names)
  for _, n in ipairs(names) do
    if not makers[n] then fault(n .. " : aucune recette ne le fabrique") end
    if not users[n] then fault(n .. " : aucun consommateur (impasse)")
    else
      local first = 99
      for _, rn in ipairs(users[n]) do first = math.min(first, epoch_of_recipe[rn] or 99) end
      local ep = epoch_of_item(CpM, n)
      if first > ep then fault(n .. " : âge " .. ep .. ", premier usage à l'âge " .. first .. " (règle « usage-age »)") end
      if not leads_out(n) then fault(n .. " : sa descendance ne mène ni au calcul, ni à un bâtiment, ni au vanilla") end
    end
  end
  -- ordre de recherche : chaque ingrédient fo-* est fabriqué par une technologie de la fermeture des prérequis
  for _, r in ipairs(recipes) do
    local tn = tech_of[r.name]
    if tn then
      local cl = closure(techs, tn)
      for _, i in ipairs(r.ingredients) do
        local n = i[1]
        if n:find("^fo%-") then
          local ok = false
          for _, m in ipairs(makers[n] or {}) do if tech_of[m] and cl[tech_of[m]] then ok = true end end
          local ext = EXTERNAL[n]
          if ext == false then ok = true end
          if ext and cl[ext[1]] then ok = true end
          if not ok then fault(r.name .. " (" .. tn .. ") : " .. n .. " n'est ouvert par aucune technologie prérequise") end
        end
      end
    end
  end
  -- âges des prérequis
  for _, t in ipairs(CpM.TECHS) do
    for _, p in ipairs(t.prerequisites) do
      if techs[p] and techs[p].epoch and techs[p].epoch > t.epoch then fault(t.name .. " : prérequis " .. p .. " d'un âge plus tardif") end
      if p:find("^fo%-") and not techs[p] then fault(t.name .. " : prérequis inconnu " .. p) end
    end
  end
  -- recettes du centre : aucun produit (le calcul n'est pas un objet), des unités par fabrication
  for _, n in ipairs(CpM.compute_recipes()) do
    local r = CpM.recipe(n)
    if #(r.results or {}) > 0 then fault(n .. " : une recette de calcul ne rend rien (calcul non stockable)") end
    if r.category ~= "fo-computing" then fault(n .. " : hors du centre de calcul") end
  end
  return faults
end

---------------------------------------------------------------------------------------------------
section("1. Sources : X3 et X0 tels quels, plan déclaré")
---------------------------------------------------------------------------------------------------
do
  local x3r = {}
  for _, r in ipairs(X3.recipes) do if not x3r[r.name] then x3r[r.name] = r end end
  for _, s in ipairs(Cp.RECIPES) do
    local r = Cp.recipe(s.name)
    if s.src == "x3" then
      local x = x3r[s.name]
      check(x ~= nil and r.ingredients == x.ingredients and r.results == x.results and r.time == x.time and r.category == x.category,
        s.name .. " : recette d'X3 telle quelle")
    elseif s.src == "x0" then
      local x = T.x_recipe(s.name)
      check(x ~= nil and r.ingredients == x.ingredients and r.results == x.results and r.category == x.category,
        s.name .. " : recette de X0 telle quelle")
    else
      check(s.epoch and s.category and s.time and s.ingredients and s.results, s.name .. " : recette du plan complète")
    end
  end
  for _, it in ipairs(Cp.ITEMS) do
    if it.src == "plan" then check(it.fr and it.en, it.name .. " : nom FR et EN (objet du plan)")
    else check(Cp.x_item(it.name) ~= nil, it.name .. " : objet de " .. it.src) end
  end
  local lith = Cp.building("fo-crystal-lithograph")
  check(lith.size[1] == 4 and lith.kw == 3000 and lith.fluid_in == 2 and lith.categories[1] == "fo-lithography",
    "lithographe : 4 × 4, 3 MW, 2 entrées, lithographie (X3)")
  local dc = Cp.building("fo-data-center")
  check(dc.size[1] == 4 and dc.kw == 10000 and dc.fluid_in == 2 and dc.categories[1] == "fo-computing",
    "centre de calcul : 4 × 4, 10 MW, 2 entrées (eau, hélium-3), aucune sortie")
  check(#Cp.X3_DEVIATIONS >= 4, #Cp.X3_DEVIATIONS .. " écarts à X3 déclarés")
  local x0t = nil
  for _, t in ipairs(require("shared.content.epochs").technologies or {}) do if t.name == "fo-regolith-degassing" then x0t = t end end
  check(x0t == nil or (x0t.epoch == 13), "fo-regolith-degassing : technologie de X0 de l'âge 13")
end

---------------------------------------------------------------------------------------------------
section("2 à 4. Graphe en jeu : présence, débouchés, âge d'usage, ordre de recherche")
---------------------------------------------------------------------------------------------------
do
  local faults = graph_faults(Cp)
  for _, f in ipairs(faults) do print("    " .. f) end
  check(#faults == 0, "graphe du lot sans faute", #faults .. " faute(s)")
  -- Chaque étape demandée par le DC existe et se fabrique
  local steps = { "fo-logic-die", "fo-dram-die", "fo-sram-die", "fo-memory-module", "fo-motherboard", "fo-graphics-card",
                  "fo-server-blade", "fo-gpu-blade", "fo-qubit-chip", "fo-dilution-stage", "fo-quantum-processor" }
  for _, n in ipairs(steps) do check(Cp.present(n), "étape « " .. n .. " » en jeu") end
  -- Âges des technologies du lot
  local want = { ["fo-chip-foundry"] = 10, ["fo-data-centers"] = 10, ["fo-gpu-computing"] = 11, ["fo-regolith-degassing"] = 13,
                 ["fo-quantum-computing"] = 13 }
  for _, t in ipairs(Cp.TECHS) do check(want[t.name] == t.epoch, t.name .. " : âge " .. t.epoch) end
  -- Packs : vanilla seulement ; l'âge 13 a au moins autant de packs que l'âge 10 (écart déclaré)
  for _, t in ipairs(Cp.TECHS) do
    local p = Cp.packs(t.epoch)
    local ok = #p >= 6
    for _, n in ipairs(p) do if n:find("^fo%-") then ok = false end end
    check(ok, t.name .. " : " .. #p .. " packs vanilla")
  end
end

---------------------------------------------------------------------------------------------------
section("5. Calcul par script : débits, fenêtres, bonus de recherche")
---------------------------------------------------------------------------------------------------
do
  check(math.abs(Cp.compute_rate("fo-compute-classic") - 100) < 1e-9, "centre classique : 100 unités/s")
  check(math.abs(Cp.compute_rate("fo-compute-accelerated") - 400) < 1e-9, "centre accéléré : 400 unités/s")
  check(math.abs(Cp.compute_rate("fo-compute-quantum") - 2000) < 1e-9, "centre quantique : 2 000 unités/s")
  local cl = Cp.recipe("fo-compute-classic")
  local water = 0
  for _, i in ipairs(cl.ingredients) do if i[1] == "water" then water = i[2] end end
  check(math.abs(water / cl.time - 10) < 1e-9, "refroidissement : 10 eau/s")
  -- Relecture du 30/10 : l'hélium-3 d'UN centre quantique tient dans quelques fours de frittage (3 000 par 600 s en
  -- demandait environ 13, soit 100 minerais d'ilménite par seconde).
  do
    local q, deg = Cp.recipe("fo-compute-quantum"), Cp.recipe("fo-regolith-degassing")
    local need, per = 0, 0
    for _, i in ipairs(q.ingredients) do if i[1] == "fo-helium-3" then need = i[2] / q.time end end
    for _, p in ipairs(deg.results) do if p[1] == "fo-helium-3" then per = p[2] / deg.time end end
    local fb = assert(T.x_building("fo-sintering-furnace"), "four de frittage absent de X0")
    local furnaces = need / (per * fb.speed)
    check(need > 0 and per > 0 and furnaces <= 3, "centre quantique : hélium-3 de 3 fours de frittage au plus",
      string.format("%.2f/s, %.2f four(s)", need, furnaces))
  end
  -- fenêtres
  check(Cp.delta(nil, { recipe = "fo-compute-classic", progress = 3.5 }) == 0, "centre neuf : rien la première fenêtre")
  check(Cp.delta({ recipe = "fo-compute-classic", progress = 1.0 }, { recipe = "fo-compute-accelerated", progress = 1.2 }) == 0,
    "recette changée : rien cette fenêtre")
  check(Cp.delta({ recipe = "fo-compute-classic", progress = 2.0 }, { recipe = "fo-compute-classic", progress = 1.5 }) == 0,
    "recul (centre reconstruit) : rien, jamais négatif")
  check(Cp.delta({ recipe = nil, progress = 0 }, { recipe = nil, progress = 0 }) == 0, "sans recette : rien")
  -- 60 ticks à pleine marche : 1 s / 300 s d'une fabrication = 1/300 → 100 unités
  local d = Cp.delta({ recipe = "fo-compute-classic", progress = 4 + 0.5 }, { recipe = "fo-compute-classic", progress = 4 + 0.5 + 1 / 300 })
  check(math.abs(Cp.rate(d, 60) - 100) < 1e-6, "pleine marche, 60 ticks : 100 unités/s", Cp.rate(d, 60))
  -- passage d'une fabrication à la suivante : products_finished +1, crafting_progress repart de 0 : continu
  local p1 = Cp.progress(7, 0.999)
  local p2 = Cp.progress(8, 0.002)
  check(math.abs((p2 - p1) - 0.003) < 1e-9, "fin de fabrication : avancement continu")
  check(Cp.rate(500, 0) == 0, "fenêtre de 0 tick : 0")
  -- bonus
  check(Cp.lab_bonus(0) == 0 and Cp.lab_bonus(-5) == 0, "aucun calcul : aucun bonus")
  check(math.abs(Cp.lab_bonus(100) - 0.20) < 1e-9, "100 unités/s : +20 % de vitesse de recherche")
  check(Cp.lab_bonus(2000) == Cp.LAB_BONUS_CAP and Cp.lab_bonus(1e9) == Cp.LAB_BONUS_CAP, "plafond +200 %")
  -- base des technologies gardée
  local m, base = Cp.lab_modifier(0.5, 0, 0.2)
  check(math.abs(m - 0.7) < 1e-9 and math.abs(base - 0.5) < 1e-9, "base des technologies 0,5 + calcul 0,2 = 0,7")
  -- une recherche finit entre deux fenêtres : le moteur a ajouté 0,1 au champ (0,7 -> 0,8)
  m, base = Cp.lab_modifier(0.8, 0.2, 0.3)
  check(math.abs(m - 0.9) < 1e-9 and math.abs(base - 0.6) < 1e-9, "recherche finie entre deux fenêtres : base 0,6 gardée")
  m = Cp.lab_modifier(0.9, 0.3, 0)
  check(math.abs(m - 0.6) < 1e-9, "centres arrêtés : retour exact à la base des technologies")
  m, base = Cp.lab_modifier(0.1, 0.3, 0)
  check(m == 0 and base == 0, "jamais sous zéro (effets des technologies recalculés par le moteur)")
end

---------------------------------------------------------------------------------------------------
section("6. MU : le processeur gravé contre le vanilla ; coût des pièces")
---------------------------------------------------------------------------------------------------
do
  local v = Cp.mu("processing-unit")
  local w = Cp.mu("processing-unit", "fo-chip-processor")
  print(string.format("    processeur : vanilla %.2f MU, gravé (puces) %.2f MU (%+.1f %%)", v, w, 100 * (w - v) / v))
  check(math.abs(w - v) / v <= 0.05, "processeur gravé à ±5 % du vanilla (règle des variantes)", string.format("%+.1f %%", 100 * (w - v) / v))
  for _, it in ipairs(Cp.ITEMS) do
    local ok, mu = pcall(Cp.mu, it.name)
    check(ok and mu > 0, it.name .. " : MU calculable et positif", ok and string.format("%.2f", mu) or mu)
    if ok then print(string.format("    âge %2d %-22s %8.2f MU", it.epoch, it.name, mu)) end
  end
  -- ordre de grandeur : la baie d'accélérateurs vaut plus que la baie de serveurs, le processeur quantique plus que la carte
  check(Cp.mu("fo-gpu-blade") > Cp.mu("fo-server-blade") and Cp.mu("fo-quantum-processor") > Cp.mu("fo-graphics-card"),
    "les pièces des âges suivants valent plus")
  -- coût du calcul : MU usé par 1 000 unités, décroissant d'un âge à l'autre
  local per = {}
  for _, n in ipairs(Cp.compute_recipes()) do
    local r = Cp.recipe(n)
    local s = 0
    for _, i in ipairs(r.ingredients) do if i[1] ~= "water" then s = s + Cp.mu(i[1]) * i[2] end end
    per[#per + 1] = s / Cp.compute_per_craft(n) * 1000
    print(string.format("    %-24s %6.2f MU par 1 000 unités", n, per[#per]))
  end
  check(per[1] > per[2] and per[2] > per[3], "le calcul coûte moins cher d'un âge à l'autre")
end

---------------------------------------------------------------------------------------------------
section("7. Productivité")
---------------------------------------------------------------------------------------------------
do
  local prod = Cp.productivity_recipes()
  check(#prod >= 6, #prod .. " recettes éligibles")
  local set = {}
  for _, n in ipairs(prod) do set[n] = true end
  for _, n in ipairs(Cp.compute_recipes()) do check(not set[n], n .. " : jamais en productivité (calcul)") end
  check(not set["fo-data-center"] and not set["fo-crystal-lithograph"], "bâtiments : jamais en productivité")
  -- non réversible : aucun produit d'une recette prod ne refait un de ses ingrédients par le lot
  local all = Cp.all_recipes()
  for _, n in ipairs(prod) do
    local r = Cp.recipe(n)
    local rev = false
    for _, p in ipairs(r.results) do
      for _, r2 in ipairs(all) do
        for _, i2 in ipairs(r2.ingredients) do
          if i2[1] == p[1] then
            for _, p2 in ipairs(r2.results or {}) do for _, i in ipairs(r.ingredients) do if p2[1] == i[1] then rev = true end end end
          end
        end
      end
    end
    check(not rev, n .. " : non réversible")
  end
end

---------------------------------------------------------------------------------------------------
section("8. Mutants : chaque garantie voit sa faute")
---------------------------------------------------------------------------------------------------
do
  local function copy(t, seen)
    if type(t) ~= "table" then return t end
    seen = seen or {}
    if seen[t] then return seen[t] end
    local c = {}
    seen[t] = c
    for k, v in pairs(t) do c[k] = copy(v, seen) end
    return c
  end
  local function mutant(label, mutate)
    package.loaded["shared.content.compute"] = nil
    local M = require("shared.content.compute")
    package.loaded["shared.content.compute"] = Cp
    mutate(M)
    local f = graph_faults(M)
    check(#f > 0, "mutant refusé : " .. label, #f == 0 and "aucune faute vue" or f[1])
  end
  mutant("puce de cache sans consommateur", function(M)
    for _, s in ipairs(M.RECIPES) do
      if s.name == "fo-chip-processor" or s.name == "fo-quantum-processor" then
        local keep = {}
        for _, i in ipairs(s.ingredients) do if i[1] ~= "fo-sram-die" then keep[#keep + 1] = i end end
        s.ingredients = keep
      end
    end
  end)
  mutant("carte graphique consommée seulement à l'âge 13", function(M)
    for _, s in ipairs(M.RECIPES) do
      if s.name == "fo-gpu-blade" then s.ingredients = { { "fo-motherboard", 1 }, { "processing-unit", 1 }, { "fo-memory-module", 2 } } end
      if s.name == "fo-quantum-processor" then s.ingredients[#s.ingredients + 1] = { "fo-graphics-card", 1 } end
    end
  end)
  mutant("calcul accéléré sans prérequis de la carte graphique", function(M)
    for _, t in ipairs(M.TECHS) do
      if t.name == "fo-gpu-computing" then t.prerequisites = { "fo-titanium-processing" } end
    end
  end)
  mutant("recette de calcul qui rend un objet (stockable)", function(M)
    for _, s in ipairs(M.RECIPES) do if s.name == "fo-compute-classic" then s.results = { { "fo-server-blade", 1 } } end end
  end)
  mutant("étage à dilution sans hélium-3 en jeu", function(M)
    local keep = {}
    for _, f in ipairs(M.FLUIDS) do if f.name ~= "fo-helium-3" then keep[#keep + 1] = f end end
    M.FLUIDS = keep
    local p = M.present
    M.present = function(n) if n == "fo-helium-3" then return false end return p(n) end
  end)
  mutant("prérequis d'un âge plus tardif", function(M)
    for _, t in ipairs(M.TECHS) do if t.name == "fo-chip-foundry" then t.prerequisites[#t.prerequisites + 1] = "fo-superconductors" end end
  end)
  mutant("recette du lot sans technologie", function(M)
    for _, t in ipairs(M.TECHS) do
      if t.name == "fo-data-centers" then
        local keep = {}
        for _, u in ipairs(t.unlocks) do if u ~= "fo-motherboard" then keep[#keep + 1] = u end end
        t.unlocks = keep
      end
    end
  end)
  mutant("fluide en « crafting »", function(M)
    for _, s in ipairs(M.RECIPES) do if s.name == "fo-heat-sink" then s.ingredients[#s.ingredients + 1] = { "water", 10 } end end
  end)
  -- Règles de script : la même propriété jouée sur la vraie règle (aucune faute) et sur un mutant (faute vue).
  local function bonus_faults(lm)
    local f = 0
    local m1 = lm(0.5, 0, 0.2)            -- base 0,5 + 0,2
    local m2 = lm(m1 + 0.1, 0.2, 0.2)     -- une recherche +0,1 entre deux fenêtres, même calcul
    local m3 = lm(m2, 0.2, 0)             -- centres arrêtés
    if math.abs(m1 - 0.7) > 1e-9 then f = f + 1 end
    if math.abs(m2 - 0.8) > 1e-9 then f = f + 1 end
    if math.abs(m3 - 0.6) > 1e-9 then f = f + 1 end
    return f
  end
  check(bonus_faults(Cp.lab_modifier) == 0, "règle du bonus : base gardée, part retirée (vraie règle)")
  check(bonus_faults(function(cur, _, new) return (cur or 0) + (new or 0) end) > 0,
    "mutant refusé : part du calcul jamais retirée (le bonus s'empile)")
  check(bonus_faults(function(_, _, new) return new or 0 end) > 0, "mutant refusé : base des technologies écrasée")
  local function rate_faults(rt)
    local f = 0
    if math.abs(rt(100, 60) - 100) > 1e-9 then f = f + 1 end
    if math.abs(rt(100, 120) - 50) > 1e-9 then f = f + 1 end
    return f
  end
  check(rate_faults(Cp.rate) == 0, "débit : unités ramenées à la seconde (vraie règle)")
  check(rate_faults(function(sum) return sum end) > 0, "mutant refusé : débit sans la durée de la fenêtre")
  local function delta_faults(dl)
    local f = 0
    if dl(nil, { recipe = "fo-compute-classic", progress = 9 }) ~= 0 then f = f + 1 end
    if dl({ recipe = "fo-compute-classic", progress = 3 }, { recipe = "fo-compute-classic", progress = 2 }) ~= 0 then f = f + 1 end
    if dl({ recipe = "fo-compute-classic", progress = 1 }, { recipe = "fo-compute-quantum", progress = 1.5 }) ~= 0 then f = f + 1 end
    return f
  end
  check(delta_faults(Cp.delta) == 0, "fenêtre : état inconnu, recul, recette changée ne comptent rien (vraie règle)")
  check(delta_faults(function(prev, now) return ((now and now.progress or 0) - (prev and prev.progress or 0)) * 30000 end) > 0,
    "mutant refusé : calcul compté depuis un état inconnu")
  local _ = copy
end

print(string.format("[CALCUL] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
