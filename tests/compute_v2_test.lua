-- Banc hors jeu du lot CALCUL-V2 (30/10) : une machine par étape (shared/content/compute_chain.lua) et la règle du centre
-- de calcul modulaire (shared/content/compute_rack.lua).
-- Lancement : lua5.2 tests/compute_v2_test.lua   (depuis la racine du mod ou d'un worktree)
-- Sections : 1 v1 intacte (fixture 0.6.27) ; 2 une machine par étape ; 3 graphe (présence, débouchés, âge d'usage,
-- recherche) ; 4 baies et centres (données) ; 5 MU ; 6 la règle ; 7 règles de script ; 8 mutants.

package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local function check(cond, label, detail)
  if cond then pass = pass + 1 else
    fail = fail + 1
    print("ECHEC : " .. label .. (detail and (" (" .. tostring(detail) .. ")") or ""))
  end
end
local function section(t) print("== " .. t) end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end

local T = require("shared.content.titanium")
local C = require("shared.content.crafts")
local Sn = require("shared.content.tin")
local B = require("shared.content.bauxite")
local SC = require("shared.content.superconductors")
local Cp = require("shared.content.compute")
local Cv = require("shared.content.compute_chain")
local Cr = require("shared.content.compute_rack")
local FIX = dofile("tests/fixtures/calcul_v1_0627.lua")

local function copy(t, seen)
  if type(t) ~= "table" then return t end
  seen = seen or {}
  if seen[t] then return seen[t] end
  local c = {}
  seen[t] = c
  for k, v in pairs(t) do c[k] = copy(v, seen) end
  return c
end

---------------------------------------------------------------------------------------------------
-- Faits du graphe (fonction de contrôle, jouée sur le vrai module et sur ses mutants)
---------------------------------------------------------------------------------------------------
-- Objets d'autres lots consommés par la v2 : technologie qui les ouvre (false : toujours en jeu).
local EXTERNAL = {
  ["fo-pure-silicon"] = "fo-silicon", ["fo-graphite"] = "fo-arc-smelting", ["fo-crystal-powder"] = "fo-lapidary",
  ["fo-silicon-wafer"] = "fo-silicon", ["fo-glass"] = "fo-glassworks", ["fo-hydrogen"] = "fo-methane-reforming",
  ["fo-printed-circuit-board"] = "fo-printed-circuits", ["fo-tin-plate"] = "fo-printed-circuits",
  ["fo-crystal-oscillator"] = "fo-lapidary", ["fo-aluminium-plate"] = "fo-aluminium", ["fo-coil"] = "fo-electrical-steel",
  ["fo-tungsten-plate"] = false, ["fo-titanium-plate"] = "fo-titanium-processing",
  ["fo-superconducting-tape"] = "fo-superconductors", ["fo-cryostat"] = "fo-cryostat",
  ["fo-liquid-nitrogen"] = "fo-superconductors", ["fo-helium-3"] = "fo-regolith-degassing",
  -- objets v1 (lot CALCUL) : technologie v1 qui les ouvre
  ["fo-photomask"] = "fo-chip-foundry", ["fo-photoresist"] = "fo-chip-foundry", ["fo-crystal-laser"] = "fo-chip-foundry",
  ["fo-heat-sink"] = "fo-chip-foundry", ["fo-dilution-stage"] = "fo-quantum-computing",
}

local function tech_table(CvM)
  local t = {}
  local function add(list, default_epoch)
    for _, x in ipairs(list) do
      t[x.name] = { epoch = x.epoch or default_epoch, prereq = copy(x.prerequisites or {}), unlocks = copy(x.unlocks or {}) }
    end
  end
  add(T.TECHS, 11); add(C.TECHS); add(Sn.TECHS); add(B.TECHS); add(SC.TECHS, 11)
  t["fo-superconductors"].epoch = 12
  add(Cp.TECHS)
  for _, x in ipairs(CvM.TECHS) do
    if x.new then add({ x })
    else
      local v = t[x.name]
      for _, p in ipairs(x.add_prerequisites or {}) do v.prereq[#v.prereq + 1] = p end
      for _, u in ipairs(x.unlocks) do v.unlocks[#v.unlocks + 1] = u end
    end
  end
  return t
end

local function closure(techs, name, acc)
  acc = acc or {}
  if acc[name] then return acc end
  acc[name] = true
  for _, p in ipairs(techs[name] and techs[name].prereq or {}) do closure(techs, p, acc) end
  return acc
end

--- Fautes du graphe v2 (texte) ; vide si tout va. CvM : le module (ou un mutant).
local function graph_faults(CvM)
  local faults = {}
  local function fault(s) faults[#faults + 1] = s end
  local techs = tech_table(CvM)
  local tech_of, epoch_of_recipe = {}, {}
  for _, tn in ipairs({ "fo-chip-foundry", "fo-data-centers", "fo-gpu-computing", "fo-regolith-degassing", "fo-quantum-computing",
                        "fo-wafer-fab", "fo-data-centers-2" }) do
    local t = techs[tn]
    if t then for _, u in ipairs(t.unlocks) do tech_of[u] = tn; epoch_of_recipe[u] = t.epoch end end
  end
  local hidden = {}
  for _, n in ipairs(CvM.HIDE_V1) do hidden[n] = true end
  -- recettes VISIBLES en jeu : v1 non cachées + v2 (procédés et bâtiments)
  local recipes = {}
  for _, r in ipairs(Cp.all_recipes()) do if not hidden[r.name] then recipes[#recipes + 1] = r end end
  for _, r in ipairs(Cp.building_recipes()) do if not hidden[r.name] then recipes[#recipes + 1] = r end end
  for _, r in ipairs(CvM.RECIPES) do recipes[#recipes + 1] = r end
  for _, r in ipairs(CvM.BUILDING_RECIPES) do recipes[#recipes + 1] = r end
  local makers, users = {}, {}
  for _, r in ipairs(recipes) do
    for _, p in ipairs(r.results or {}) do makers[p[1]] = makers[p[1]] or {}; table.insert(makers[p[1]], r.name) end
    for _, i in ipairs(r.ingredients) do users[i[1]] = users[i[1]] or {}; table.insert(users[i[1]], r.name) end
  end
  -- catégories : chaque catégorie v2 servie par une machine du lot (les deux centres partagent fo-dc-cooling)
  local cats = { crafting = true, ["advanced-crafting"] = true, chemistry = true, ["fo-cleanroom"] = true, ["fo-lithography"] = true,
                 ["fo-sintering"] = true, ["fo-arc-smelting"] = true, ["fo-computing"] = true, ["fo-circuit-printing"] = true,
                 ["fo-cryogenics"] = true }
  for _, m in ipairs(CvM.MACHINES) do for _, c in ipairs(m.categories) do cats[c] = true end end
  for _, c in ipairs(CvM.DATA_CENTER.categories) do cats[c] = true end
  for _, r in ipairs(recipes) do
    if not cats[r.category] then fault(r.name .. " : catégorie " .. tostring(r.category) .. " sans machine") end
    for _, i in ipairs(r.ingredients) do
      if not CvM.present(i[1]) then fault(r.name .. " : ingrédient absent du jeu " .. i[1]) end
      if (r.category == "crafting" or r.category == "advanced-crafting") and CvM.is_fluid(i[1]) then fault(r.name .. " : fluide à la main") end
    end
    for _, p in ipairs(r.results or {}) do if not CvM.present(p[1]) then fault(r.name .. " : produit absent du jeu " .. p[1]) end end
    if not tech_of[r.name] then fault(r.name .. " : ouverte par aucune technologie") end
  end
  -- chaque objet v2 : fabriqué, consommé dès son âge, et mène à une baie, un bâtiment ou un objet vanilla
  local own, sink = {}, {}
  for _, it in ipairs(CvM.ITEMS) do own[it.name] = it.epoch end
  for _, f in ipairs(CvM.FLUIDS) do own[f.name] = f.epoch end
  for _, rk in ipairs(CvM.RACKS) do sink[rk.name] = rk.epoch end
  for _, m in ipairs(CvM.MACHINES) do sink[m.name] = m.epoch end
  sink["fo-data-center"] = 10
  local function leads_out(n, seen)
    if sink[n] or not own[n] then return true end
    seen = seen or {}
    if seen[n] then return false end
    seen[n] = true
    for _, rn in ipairs(users[n] or {}) do
      for _, r in ipairs(recipes) do
        if r.name == rn then
          if r.cooling then return true end
          for _, p in ipairs(r.results or {}) do if p[1] ~= n and leads_out(p[1], seen) then return true end end
        end
      end
    end
    return false
  end
  local names = {}
  for n in pairs(own) do names[#names + 1] = n end
  for n in pairs(sink) do names[#names + 1] = n end
  table.sort(names)
  for _, n in ipairs(names) do
    if not makers[n] then fault(n .. " : aucune recette visible ne le fabrique") end
    if own[n] then
      if not users[n] then fault(n .. " : aucun consommateur (impasse)")
      else
        local first = 99
        for _, rn in ipairs(users[n]) do first = math.min(first, epoch_of_recipe[rn] or 99) end
        if first > own[n] then fault(n .. " : âge " .. own[n] .. ", premier usage à l'âge " .. first) end
        if not leads_out(n) then fault(n .. " : ne mène ni à une baie, ni à un bâtiment, ni au vanilla") end
      end
    end
  end
  -- ordre de recherche : chaque ingrédient fo-* d'une recette v2 est ouvert dans la fermeture de sa technologie
  local v2 = {}
  for _, r in ipairs(CvM.RECIPES) do v2[#v2 + 1] = r end
  for _, r in ipairs(CvM.BUILDING_RECIPES) do v2[#v2 + 1] = r end
  for _, r in ipairs(v2) do
    local tn = tech_of[r.name]
    if tn then
      local cl = closure(techs, tn)
      for _, i in ipairs(r.ingredients) do
        local n = i[1]
        if n:find("^fo%-") then
          local ok = false
          for _, m in ipairs(makers[n] or {}) do if tech_of[m] and cl[tech_of[m]] then ok = true end end
          local ext = EXTERNAL[n]
          if ext == false or (ext and cl[ext]) then ok = true end
          if not ok then fault(r.name .. " (" .. tn .. ") : " .. n .. " n'est ouvert par aucune technologie prérequise") end
        end
      end
      if r.epoch and techs[tn].epoch ~= r.epoch then fault(r.name .. " : âge " .. r.epoch .. " ouvert par " .. tn .. " (âge " .. techs[tn].epoch .. ")") end
    end
  end
  for _, x in ipairs(CvM.TECHS) do
    for _, p in ipairs(techs[x.name].prereq) do
      if techs[p] and techs[p].epoch and techs[p].epoch > techs[x.name].epoch then fault(x.name .. " : prérequis " .. p .. " plus tardif") end
      if p:find("^fo%-") and not techs[p] then fault(x.name .. " : prérequis inconnu " .. p) end
    end
  end
  -- une machine par étape : chaque catégorie neuve a UNE machine (sauf fo-dc-cooling : les deux centres), et au moins une recette
  local owner = {}
  for _, m in ipairs(CvM.MACHINES) do
    for _, c in ipairs(m.categories) do
      if owner[c] and c ~= "fo-dc-cooling" then fault("catégorie " .. c .. " : deux machines (" .. owner[c] .. ", " .. m.name .. ")") end
      owner[c] = m.name
    end
  end
  for _, c in ipairs(CvM.NEW_CATEGORIES) do
    local n = 0
    for _, r in ipairs(CvM.RECIPES) do if r.category == c then n = n + 1 end end
    if n == 0 then fault("catégorie " .. c .. " sans recette") end
  end
  -- recettes v2 jamais cachées, jamais un nom v1 réutilisé (sauf la tireuse et le lingot, objets d'X3 non en jeu)
  for _, r in ipairs(v2) do
    if hidden[r.name] then fault(r.name .. " : recette v2 cachée") end
    for _, f in ipairs(FIX) do if f.name == r.name then fault(r.name .. " : nom d'une recette v1") end end
  end
  return faults
end

---------------------------------------------------------------------------------------------------
section("1. La v1 intacte : recettes 0.6.27 figées (fixture), recettes cachées existantes")
---------------------------------------------------------------------------------------------------
local function same_list(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i][1] ~= b[i][1] or a[i][2] ~= b[i][2] then return false end end
  return true
end
local function v1_faults(CpM, CvM)
  local f = {}
  local live = {}
  for _, r in ipairs(CpM.all_recipes()) do live[r.name] = r end
  for _, r in ipairs(CpM.building_recipes()) do live[r.name] = r end
  for _, x in ipairs(FIX) do
    local r = live[x.name]
    if not r then f[#f + 1] = x.name .. " : recette v1 retirée"
    elseif r.category ~= x.category or r.time ~= x.time or not same_list(r.ingredients, x.ingredients) or not same_list(r.results or {}, x.results) then
      f[#f + 1] = x.name .. " : recette v1 modifiée"
    end
  end
  local fixed = {}
  for _, x in ipairs(FIX) do fixed[x.name] = true end
  for _, n in ipairs(CvM.HIDE_V1) do if not fixed[n] then f[#f + 1] = n .. " : cachée mais pas une recette v1" end end
  return f
end
do
  local f = v1_faults(Cp, Cv)
  for _, x in ipairs(f) do print("    " .. x) end
  check(#f == 0, #FIX .. " recettes v1 telles qu'en 0.6.27 (nom, catégorie, durée, ingrédients, produits)", #f .. " écart(s)")
  check(#Cv.HIDE_V1 == 17, #Cv.HIDE_V1 .. " recettes v1 cachées pour un nouveau choix")
  local bld = Cp.building("fo-data-center")
  check(bld.size[1] == 4, "le centre garde son 4 × 4 (pas de F76)")
  check(#Cv.DATA_CENTER.categories == 2 and Cv.DATA_CENTER.categories[1] == "fo-computing",
    "le centre garde la catégorie v1 fo-computing (ses recettes v1 restent valides) et prend fo-dc-cooling")
end

---------------------------------------------------------------------------------------------------
section("2 et 3. Une machine par étape ; graphe en jeu")
---------------------------------------------------------------------------------------------------
do
  local faults = graph_faults(Cv)
  for _, f in ipairs(faults) do print("    " .. f) end
  check(#faults == 0, "graphe v2 sans faute", #faults .. " faute(s)")
  -- les étapes demandées par le DC, chacune dans SA machine
  local STEPS = {
    { "croissance du lingot", "fo-silicon-ingot", "fo-crystal-puller" }, { "sciage", "fo-ingot-sawing", "fo-wire-saw" },
    { "lithographie", "fo-wafer-exposure", "fo-crystal-lithograph" }, { "gravure, dopage", "fo-plasma-etching", "fo-plasma-etcher" },
    { "découpe et test", "fo-die-test-logic", "fo-die-prober" }, { "mise en boîtier", "fo-packaged-processor", "fo-packaging-line" },
    { "pose des composants", "fo-smt-motherboard", "fo-smt-line" }, { "fibre optique", "fo-optical-fiber", "fo-fiber-tower" },
    { "assemblage des baies", "fo-rack-cpu", "fo-rack-integrator" }, { "froid", "fo-water-chilling", "fo-chiller" },
    { "rejet de chaleur", "fo-warm-water-cooling", "fo-cooling-tower" }, { "calcul (refroidissement)", "fo-dc-chilled-water", "fo-data-center" },
    { "grand centre (azote)", "fo-dc-liquid-nitrogen", "fo-data-center-2" }, { "froid quantique", "fo-dilution-mix", "fo-dilution-fridge" },
    { "fabrication quantique", "fo-qlab-quantum-processor", "fo-quantum-lab" },
  }
  local cat_of_machine = {}
  for _, m in ipairs(Cv.MACHINES) do cat_of_machine[m.name] = m.categories end
  cat_of_machine["fo-data-center"] = Cv.DATA_CENTER.categories
  cat_of_machine["fo-crystal-lithograph"] = { "fo-lithography" }
  for _, s in ipairs(STEPS) do
    local r = Cv.recipe(s[2])
    local ok = false
    for _, c in ipairs(cat_of_machine[s[3]] or {}) do if r and r.category == c then ok = true end end
    check(ok, "étape « " .. s[1] .. " » : " .. s[2] .. " dans " .. s[3])
  end
  check(#Cv.MACHINES == 13, #Cv.MACHINES .. " machines neuves (12 étapes + grand centre)")
  check(#Cv.PROVISIONAL == 0, "plus aucun visuel provisoire depuis le lot CALCUL-DESIGN")
  -- âges des technologies
  local want = { ["fo-wafer-fab"] = 10, ["fo-data-centers"] = 10, ["fo-gpu-computing"] = 11, ["fo-data-centers-2"] = 12,
                 ["fo-quantum-computing"] = 13 }
  for _, t in ipairs(Cv.TECHS) do check(want[t.name] == t.epoch, t.name .. " : âge " .. t.epoch) end
end

---------------------------------------------------------------------------------------------------
section("4. Baies et centres : données")
---------------------------------------------------------------------------------------------------
local function rack_faults(CvM, CrM)
  local f = {}
  local rule = {}
  for _, r in ipairs(CrM.RACKS) do rule[r.name] = r end
  local data = {}
  for _, r in ipairs(CvM.RACKS) do
    data[r.name] = r
    if not rule[r.name] then f[#f + 1] = r.name .. " : baie sans règle" elseif rule[r.name].epoch ~= r.epoch then f[#f + 1] = r.name .. " : âge différent" end
  end
  for _, r in ipairs(CrM.RACKS) do if not data[r.name] then f[#f + 1] = r.name .. " : règle sans baie" end end
  if not (CvM.RACK_POLLUTION and CvM.RACK_POLLUTION > 0) then f[#f + 1] = "baies sans effet de pollution (clé d'exclusivité)" end
  local cool = {}
  for _, n in ipairs(CvM.cooling_recipes()) do
    cool[n] = true
    if not CrM.COOLING[n] then f[#f + 1] = n .. " : refroidissement sans règle" end
  end
  for n in pairs(CrM.COOLING) do if not cool[n] then f[#f + 1] = n .. " : règle sans recette" end end
  if CrM.CENTERS["fo-data-center"].slots ~= CvM.DATA_CENTER.slots then f[#f + 1] = "centre : emplacements différents" end
  local big = CvM.machine("fo-data-center-2")
  if not big or CrM.CENTERS["fo-data-center-2"].slots ~= big.slots then f[#f + 1] = "grand centre : emplacements différents" end
  -- dilution (quantique) : seulement au grand centre
  for _, r in ipairs(CvM.RECIPES) do
    if r.cooling and CrM.COOLING[r.name] and CrM.COOLING[r.name].dilution then
      for _, c in ipairs(CvM.DATA_CENTER.categories) do if c == r.category then f[#f + 1] = r.name .. " : dilution au petit centre" end end
    end
  end
  return f
end
do
  local f = rack_faults(Cv, Cr)
  for _, x in ipairs(f) do print("    " .. x) end
  check(#f == 0, "7 baies : une règle chacune, même âge ; refroidissements = règle ; emplacements ; dilution au grand centre seul", #f .. " écart(s)")
  check(#Cv.RACKS == 7, "7 baies (CPU, mémoire, stockage, réseau, refroidissement, GPU, quantique)")
  local v1names = {}
  for _, it in ipairs(Cp.ITEMS) do v1names[it.name] = true end
  check(v1names["fo-server-blade"] and v1names["fo-gpu-blade"], "baies CPU et GPU : noms des objets v1 gardés (objet devenu module)")
end

---------------------------------------------------------------------------------------------------
section("5. MU : baies à ±15 % de la baie v1, variantes à ±5 %")
---------------------------------------------------------------------------------------------------
do
  local blade, gpu = Cp.mu("fo-server-blade", "fo-server-blade"), Cp.mu("fo-gpu-blade", "fo-gpu-blade")
  for _, rk in ipairs(Cv.RACKS) do
    local mu = Cv.mu(rk.name)
    local ref = (rk.name == "fo-gpu-blade") and gpu or ((rk.epoch == 10) and blade or nil)
    if ref then
      check(math.abs(mu - ref) / ref <= 0.15, string.format("%s : %.1f MU contre %.1f (baie v1)", rk.name, mu, ref),
        string.format("%+.1f %%", 100 * (mu - ref) / ref))
    else
      check(mu > Cv.mu("fo-gpu-blade") * 0.5, string.format("%s : %.1f MU (âge %d, sans baie v1)", rk.name, mu, rk.epoch))
    end
  end
  local w, w0 = Cv.mu("fo-silicon-wafer", "fo-ingot-sawing"), Cp.mu("fo-silicon-wafer")
  check(math.abs(w - w0) / w0 <= 0.05, string.format("tranches sciées : %.3f MU contre %.3f (salle blanche)", w, w0))
  local p, p0 = Cv.mu("processing-unit", "fo-packaged-processor"), Cp.mu("processing-unit")
  check(math.abs(p - p0) / p0 <= 0.05, string.format("processeur mis en boîtier : %.2f MU contre %.2f (vanilla)", p, p0))
  for _, it in ipairs(Cv.ITEMS) do
    local ok, mu = pcall(Cv.mu, it.name)
    check(ok and mu > 0, it.name .. " : MU calculable et positif", ok and string.format("%.2f", mu) or mu)
  end
end

---------------------------------------------------------------------------------------------------
section("6. La règle du centre modulaire")
---------------------------------------------------------------------------------------------------
local function C6(t) local c = { cpu = 0, memory = 0, storage = 0, network = 0, cooling = 0, gpu = 0, quantum = 0 }
  for k, v in pairs(t) do c[k] = v end return c end
local W = "fo-dc-chilled-water"

--- Fautes de la règle (texte) ; vide si tout va. R : le module de règle (ou un mutant).
local function rule_faults(R)
  local f = {}
  local function want(cond, s) if not cond then f[#f + 1] = s end end
  -- exemple du plan (âge 10, 6 places : 3 CPU, 1 mémoire, 1 refroidissement, 1 stockage)
  local ex = R.evaluate(C6({ cpu = 3, memory = 1, cooling = 1, storage = 1 }), W, 1, 1, "fo-data-center")
  want(near(ex.compute, 280, 1e-6), "exemple du plan : 280 unités/s (lu " .. ex.compute .. ")")
  want(near(ex.kw, 4050, 1e-6), "exemple du plan : 4,05 MW (lu " .. ex.kw .. ")")
  want(ex.limit == "heat", "exemple du plan : limité par la chaleur")
  local nc = R.evaluate(C6({ cpu = 3, memory = 1, storage = 1 }), W, 1, 1, "fo-data-center")
  want(near(nc.compute, 125, 1e-6), "sans baie de refroidissement : 125 (lu " .. nc.compute .. ")")
  -- refroidissement : sans recette (ou recette arrêtée), le passif seul
  local stop = R.evaluate(C6({ cpu = 3, memory = 1, cooling = 1, storage = 1 }), W, 0, 1, "fo-data-center")
  want(near(stop.compute, 300 * 1500 / 3750, 1e-6), "recette arrêtée (r = 0) : passif seul")
  local none = R.evaluate(C6({ cpu = 3, memory = 1, cooling = 1, storage = 1 }), nil, 1, 1, "fo-data-center")
  want(near(none.compute, stop.compute, 1e-9), "sans recette : passif seul")
  local n2 = R.evaluate(C6({ cpu = 3, memory = 1, cooling = 1, storage = 1 }), "fo-dc-liquid-nitrogen", 1, 1, "fo-data-center-2")
  want(near(n2.cooling, 3000 + 5000, 1e-9), "azote au grand centre : 3 000 passif + 5 000")
  -- GPU bridé EXACTEMENT par la mémoire
  local g0 = R.evaluate(C6({ gpu = 1, cooling = 2 }), W, 1, 1, "fo-data-center")
  want(g0.compute == 0 and g0.limit == "memory", "GPU sans mémoire : 0, limité par la mémoire")
  local g1 = R.evaluate(C6({ gpu = 1, memory = 1, cooling = 1, network = 1, storage = 1 }), W, 1, 1, "fo-data-center")
  want(near(g1.compute, 400, 1e-6), "1 GPU, 1 mémoire (offre 4, demande 3) : 400 (lu " .. g1.compute .. ")")
  local g2 = R.evaluate(C6({ gpu = 2, memory = 1 }), W, 1, 1, "fo-data-center-2")
  want(near(g2.brut, 800 * 4 / 6, 1e-6), "2 GPU, 1 mémoire : brut 533,3 (lu " .. g2.brut .. ")")
  -- quantique : nul sans dilution, nul sans CPU, 2 000 par paire
  local q = { cpu = 1, quantum = 1, memory = 1, cooling = 2, network = 2, storage = 3 }
  want(near(R.evaluate(C6(q), W, 1, 1, "fo-data-center-2").brut, 100, 1e-9), "quantique sans dilution : seul le CPU calcule")
  local qq = R.evaluate(C6(q), "fo-dc-dilution", 1, 1, "fo-data-center-2")
  want(near(qq.brut, 2100, 1e-9), "quantique + CPU de contrôle, dilution : 2 100 brut (lu " .. qq.brut .. ")")
  want(near(R.evaluate(C6({ quantum = 2, memory = 1 }), "fo-dc-dilution", 1, 1, "fo-data-center-2").brut, 0, 1e-9), "quantique sans CPU : 0")
  -- puissance = base + somme ; ordre indifférent
  local all = C6({ cpu = 2, gpu = 1, quantum = 1, memory = 2, storage = 1, network = 1, cooling = 1 })
  local ev = R.evaluate(all, "fo-dc-dilution", 1, 1, "fo-data-center-2")
  want(near(ev.kw, 600 + 2000 + 2500 + 1500 + 600 + 300 + 200 + 150, 1e-9), "puissance = base + somme des baies (lu " .. ev.kw .. ")")
  local a = R.counts({ ["fo-server-blade"] = 2, ["fo-memory-rack"] = 1, ["iron-plate"] = 9 })
  local b = R.counts({ ["fo-memory-rack"] = 1, ["fo-server-blade"] = 2 })
  want(a.cpu == 2 and a.memory == 1 and b.cpu == 2 and b.memory == 1, "comptes : ordre indifférent, objet étranger ignoré")
  -- plafonds
  local cap = R.evaluate(C6({ cpu = 4, memory = 1, cooling = 3, network = 2 }), W, 1, 1, "fo-data-center-2")
  want(near(cap.compute, 200, 1e-9) and cap.limit == "storage", "sans stockage : plafond 200, limité par le stockage")
  local net = R.evaluate(C6({ cpu = 4, memory = 1, cooling = 3, storage = 2 }), W, 1, 1, "fo-data-center-2")
  want(near(net.compute, 300, 1e-9) and net.limit == "network", "sans réseau : export 300, limité par le réseau")
  -- courant
  local half = R.evaluate(C6({ cpu = 1, memory = 1 }), W, 1, 0.5, "fo-data-center")
  want(near(half.compute, 50, 1e-9) and half.limit == "power", "moitié du courant : moitié du calcul")
  want(R.evaluate(C6({ cpu = 1, memory = 1 }), W, 1, 0, "fo-data-center").compute == 0, "sans courant : 0")
  -- monotonie (non décroissant) en e, r, refroidissement, stockage, réseau
  local base = { cpu = 3, gpu = 1, memory = 2, storage = 1, network = 0, cooling = 0 }
  local prev = -1
  for k = 0, 10 do
    local v = R.evaluate(C6(base), W, 1, k / 10, "fo-data-center-2").compute
    if v < prev - 1e-9 then want(false, "monotone en e") end
    prev = v
  end
  -- (stockage et réseau : à refroidissement suffisant ; sous bridage thermique, leur chaleur coûte du calcul : voulu,
  -- une place et des kW de chaleur pour un plafond relevé)
  for _, key in ipairs({ "cooling", "storage", "network" }) do
    prev = -1
    for n = 0, 6 do
      local t = copy(base); t[key] = n
      if key ~= "cooling" then t.cooling = 6 end
      local v = R.evaluate(C6(t), W, 1, 1, "fo-data-center-2").compute
      if v < prev - 1e-9 then want(false, "monotone en " .. key) end
      prev = v
    end
  end
  prev = -1
  for k = 0, 10 do
    local v = R.evaluate(C6({ cpu = 3, memory = 1, cooling = 2, storage = 1, network = 1 }), W, k / 10, 1, "fo-data-center").compute
    if v < prev - 1e-9 then want(false, "monotone en r") end
    prev = v
  end
  -- aucune baie
  local z = R.evaluate(C6({}), W, 1, 1, "fo-data-center")
  want(z.compute == 0 and z.kw == 300 and z.limit == "no-rack", "centre vide : 0, 300 kW de base")
  return f
end
do
  local f = rule_faults(Cr)
  for _, x in ipairs(f) do print("    " .. x) end
  check(#f == 0, "règle du centre : exemple du plan, mémoire, chaleur, quantique, puissance, plafonds, courant, monotonie", #f .. " faute(s)")
end

---------------------------------------------------------------------------------------------------
section("7. Règles de script : part du temps, satisfaction, bonus de recherche")
---------------------------------------------------------------------------------------------------
local function script_faults(R)
  local f = {}
  local function want(cond, s) if not cond then f[#f + 1] = s end end
  -- part du temps : 60 ticks à pleine marche d'une recette de 10 s = 0,1 fabrication
  want(near(R.share(0.1, 10, 1, 60), 1, 1e-9), "part : pleine marche = 1")
  want(near(R.share(0.05, 10, 1, 60), 0.5, 1e-9), "part : moitié = 0,5")
  want(R.share(0.5, 10, 1, 60) == 1, "part bornée à 1")
  want(R.share(-1, 10, 1, 60) == 0 and R.share(0.1, 10, 1, 0) == 0, "part : recul ou fenêtre nulle = 0")
  -- satisfaction : tampon plein = 1, vide = 0, rien demandé = 1
  want(R.satisfaction(100, 100, 100) == 1 and R.satisfaction(0, 100, 100) == 0 and near(R.satisfaction(40, 100, 100), 0.4),
    "satisfaction = énergie / tampon")
  want(R.satisfaction(0, 1, 0) == 1, "aucune baie : satisfaction 1")
  -- bonus de recherche recalé : centre d'âge 10 (280) → +20 à 30 %
  local b = R.lab_bonus(280)
  want(b >= 0.20 and b <= 0.30, string.format("centre d'âge 10 (280 u/s) : +%.0f %% de recherche (cible 20 à 30)", 100 * b))
  want(R.lab_bonus(0) == 0 and R.lab_bonus(-3) == 0 and R.lab_bonus(1e9) == R.LAB_BONUS_CAP, "bonus : nul, jamais négatif, plafonné")
  return f
end
do
  local f = script_faults(Cr)
  for _, x in ipairs(f) do print("    " .. x) end
  check(#f == 0, "règles de script (part, satisfaction, bonus recalé)", #f .. " faute(s)")
  check(near(Cp.lab_modifier(0.9, 0.3, 0), 0.6), "règle v1 du champ partagé reprise telle quelle (base des technologies gardée)")
end

---------------------------------------------------------------------------------------------------
section("8. Mutants : chaque garantie voit sa faute")
---------------------------------------------------------------------------------------------------
do
  local function fresh(modname)
    package.loaded[modname] = nil
    local M = require(modname)
    return M
  end
  local function graph_mutant(label, mutate)
    local M = fresh("shared.content.compute_chain")
    package.loaded["shared.content.compute_chain"] = Cv
    mutate(M)
    local f = graph_faults(M)
    check(#f > 0, "mutant refusé : " .. label, #f == 0 and "aucune faute vue" or f[1])
  end
  graph_mutant("baie de stockage ouverte par aucune technologie", function(M)
    for _, t in ipairs(M.TECHS) do
      local keep = {}
      for _, u in ipairs(t.unlocks) do if u ~= "fo-rack-storage" then keep[#keep + 1] = u end end
      t.unlocks = keep
    end
  end)
  graph_mutant("disque flash sans consommateur", function(M)
    for _, r in ipairs(M.RECIPES) do
      if r.name == "fo-rack-storage" then r.ingredients = { { "fo-motherboard", 1 }, { "processing-unit", 1 }, { "steel-plate", 5 } } end
    end
  end)
  graph_mutant("deux machines pour la même étape", function(M) M.MACHINES[2].categories = { "fo-crystal-pulling" } end)
  graph_mutant("baie GPU ouverte à l'âge 10 (carte graphique de l'âge 11)", function(M)
    for _, t in ipairs(M.TECHS) do
      if t.name == "fo-data-centers" then t.unlocks[#t.unlocks + 1] = "fo-rack-gpu" end
      if t.name == "fo-gpu-computing" then t.unlocks = { "fo-smt-graphics-card" } end
    end
  end)
  graph_mutant("recette v2 cachée", function(M) M.HIDE_V1[#M.HIDE_V1 + 1] = "fo-plasma-etching" end)
  graph_mutant("eau chaude sans tour de refroidissement", function(M)
    local keep = {}
    for _, r in ipairs(M.RECIPES) do if r.name ~= "fo-warm-water-cooling" then keep[#keep + 1] = r end end
    M.RECIPES = keep
  end)
  graph_mutant("fluide à la main", function(M)
    for _, r in ipairs(M.BUILDING_RECIPES) do if r.name == "fo-chiller" then r.ingredients[#r.ingredients + 1] = { "fo-chilled-water", 10 } end end
  end)
  graph_mutant("grand centre sans prérequis de l'azote", function(M)
    for _, t in ipairs(M.TECHS) do if t.name == "fo-data-centers-2" then t.prerequisites = { "fo-gpu-computing" } end end
  end)
  graph_mutant("étape sans recette (catégorie vide)", function(M)
    M.NEW_CATEGORIES[#M.NEW_CATEGORIES + 1] = "fo-orphan"
  end)
  -- v1
  do
    local CpM = copy(Cp)
    CpM.all_recipes = function()
      local l = Cp.all_recipes()
      for _, r in ipairs(l) do if r.name == "fo-compute-classic" then r = copy(r); r.time = 200; l[_] = r end end
      return l
    end
    check(#v1_faults(CpM, Cv) > 0, "mutant refusé : recette v1 modifiée (durée)")
    CpM.all_recipes = function()
      local l = {}
      for _, r in ipairs(Cp.all_recipes()) do if r.name ~= "fo-logic-die" then l[#l + 1] = r end end
      return l
    end
    check(#v1_faults(CpM, Cv) > 0, "mutant refusé : recette v1 retirée")
  end
  -- baies
  do
    local M = fresh("shared.content.compute_chain")
    package.loaded["shared.content.compute_chain"] = Cv
    M.RACK_POLLUTION = 0
    check(#rack_faults(M, Cr) > 0, "mutant refusé : baies sans effet (clé d'exclusivité perdue)")
    local R = fresh("shared.content.compute_rack")
    package.loaded["shared.content.compute_rack"] = Cr
    R.COOLING["fo-dc-chilled-water"].dilution = true
    check(#rack_faults(copy(Cv), R) > 0, "mutant refusé : dilution permise au petit centre")
  end
  -- règle
  local function rule_mutant(label, mutate)
    local R = fresh("shared.content.compute_rack")
    package.loaded["shared.content.compute_rack"] = Cr
    mutate(R)
    local f = rule_faults(R)
    local g = script_faults(R)
    check(#f + #g > 0, "mutant refusé : " .. label, (#f + #g == 0) and "aucune faute vue" or (f[1] or g[1]))
  end
  rule_mutant("le GPU ne demande qu'une part de mémoire", function(R) R.MEM_GPU = 1 end)
  rule_mutant("refroidissement compté sans la recette (r ignoré)", function(R)
    local ev = R.evaluate
    R.evaluate = function(c, recipe, r, e, center) return ev(c, recipe or "fo-dc-chilled-water", 1, e, center) end
  end)
  rule_mutant("quantique sans dilution", function(R) R.COOLING["fo-dc-chilled-water"].dilution = true end)
  rule_mutant("plafond du stockage oublié", function(R) R.STORAGE_PER = 1e9; R.STORAGE_BASE = 1e9 end)
  rule_mutant("export du réseau oublié", function(R) R.NETWORK_BASE = 1e9 end)
  rule_mutant("courant ignoré", function(R)
    local ev = R.evaluate
    R.evaluate = function(c, recipe, r, _, center) return ev(c, recipe, r, 1, center) end
  end)
  rule_mutant("puissance de base oubliée", function(R) R.CENTERS["fo-data-center"].base_kw = 0 end)
  rule_mutant("passif du grand centre = petit", function(R) R.CENTERS["fo-data-center-2"].passive = 1500 end)
  rule_mutant("bonus de recherche de la v1 (+1 % par 5 u/s)", function(R) R.LAB_BONUS_PER_UNIT = 0.01 / 5 end)
  rule_mutant("part du temps non bornée", function(R)
    R.share = function(d, time, speed, ticks) if not ticks or ticks <= 0 then return 0 end return math.max(0, d * time / ((speed or 1) * ticks / 60)) end
  end)
  rule_mutant("comptes : objet étranger compté comme CPU", function(R)
    local ct = R.counts
    R.counts = function(contents) local c = ct(contents); c.cpu = c.cpu + ((contents or {})["iron-plate"] or 0) return c end
  end)
end

print(string.format("[CALCUL-V2] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
