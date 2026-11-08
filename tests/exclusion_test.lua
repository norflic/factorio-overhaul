--[[
  Lot VIDEO-PLAFONDS, partie d (V99) : banc HORS JEU du réglage d'exclusion de demande (shared/ai3/exclusion.lua, branché par
  Pf.excluded / Pf.gate de shared/ai3/plafonds.lua et trois lignes de shared/ai3/capitalisation.lua). Lancement, depuis la racine
  du mod :
    lua5.2 tests/exclusion_test.lua
  Critères écrits AVANT le code (lead, 7/11) : « un objet exclu n'apparaît dans AUCUN puits ni AUCUNE option, et le refus est écrit ».
  Sections :
     1. Ex.parse : séparateurs, doublons, jetons invalides, plafond d'objets, entrée non textuelle, ordre trié ;
     2. Ex.has, Ex.why, Ex.is_refusal, Ex.due (une ligne de journal par refus et par 10 minutes) ;
     3. réglage VIDE : la décision est la même (nil, {} et chaîne vide : rendus identiques octet pour octet) ;
     4. un PUITS d'objet exclu disparaît (aucun besoin, aucun ordre) ; un puits d'un autre objet reste servi ;
     5. une OPTION d'objet exclu disparaît : minerai (couvrir), laboratoire (labos), pack (chaîne) ; refus « exclu : » écrit ;
     6. un objet exclu au milieu d'une chaîne : sa demande ne se propage pas à l'amont (aucun minerai demandé pour lui) ;
     7. Pf.gate seule (options factices) : retrait, refus, réduction au plafond de sûreté d'une sorte, garde fermée ;
     8. déterminisme (même entrée, même rendu ; ordre des jetons sans effet) ;
     9. mutants : chaque règle retirée fait échouer au moins un contrôle.
  Le décor (relevé vanilla, scènes) est celui de tests/ai3_capitalisation_test.lua, recopié : ce fichier est du TEST et nomme les
  prototypes vanilla ; la règle n'en voit rien (tests/iag_test.lua §8).
]]
package.path = "./?.lua;" .. package.path

local F = require("tests.iag_fixture")
local Ex = require("shared.ai3.exclusion")
local Pf = require("shared.ai3.plafonds")
local Ca = require("shared.ai3.capitalisation")

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[EXCLUSION] ECHEC : " .. msg) end
  end
end
local function slurp(p) local f = assert(io.open(p, "rb")) local x = f:read("*a") f:close() return x end
local function has(s, sub) return type(s) == "string" and s:find(sub, 1, true) ~= nil end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end
local function deep(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = deep(v) end
  return c
end
local function ser(v)
  local t = type(v)
  if t == "table" then
    local ks = {}
    for k in pairs(v) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b)
      local ta, tb = type(a), type(b)
      if ta ~= tb then return ta < tb end
      return a < b
    end)
    local parts = {}
    for _, k in ipairs(ks) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif t == "string" then return string.format("%q", v)
  elseif t == "number" then return string.format("%.12g", v)
  else return tostring(v) end
end

---------------------------------------------------------------------------------------------------
-- Décor : relevé vanilla et scènes (recopiés de tests/ai3_capitalisation_test.lua)
---------------------------------------------------------------------------------------------------
local V_SPEED = { ["stone-furnace"] = 1, ["steel-furnace"] = 2, ["electric-furnace"] = 2, ["assembling-machine-1"] = 0.5,
  ["assembling-machine-2"] = 0.75, ["assembling-machine-3"] = 1.25, ["burner-mining-drill"] = 0.25,
  ["electric-mining-drill"] = 0.5, ["pumpjack"] = 1, ["lab"] = 1, ["chemical-plant"] = 1, ["oil-refinery"] = 1,
  ["centrifuge"] = 1 }
local V_AREA = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 5, ["pumpjack"] = 1 }
local V_SIZE = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 3, ["stone-furnace"] = 2, ["steel-furnace"] = 2 }
local V_KW = { ["stone-furnace"] = 90, ["steel-furnace"] = 90, ["electric-furnace"] = 180, ["burner-mining-drill"] = 150,
  ["electric-mining-drill"] = 90, ["assembling-machine-1"] = 75, ["assembling-machine-2"] = 150,
  ["assembling-machine-3"] = 375, ["lab"] = 60, ["boiler"] = 1800 }
local V_MINE = { ["uranium-ore"] = 2 }
local EXEC_AUTO = { ["stone-furnace"] = true, ["steel-furnace"] = true, ["burner-mining-drill"] = true,
  ["electric-mining-drill"] = true, ["assembling-machine-1"] = true, ["assembling-machine-2"] = true }
local ROLES = { main = true, labo = true }

local function vanilla_dump()
  local d = F.dump()
  for _, e in ipairs(d.entities) do
    if V_SPEED[e.name] then e.speed = V_SPEED[e.name] end
    e.mining_area = V_AREA[e.name]
    e.size = V_SIZE[e.name] or 3
    e.energy_kw = V_KW[e.name]
  end
  for _, t in ipairs(sorted_keys(d.techs)) do
    for _, r in ipairs(d.techs[t].unlocks) do if d.recipes[r] then d.recipes[r].enabled = false end end
  end
  for _, r in ipairs(d.resources) do r.mining_time = V_MINE[r.entity] or 1 end
  return d
end
local D = Ca.data(vanilla_dump(), { exec = EXEC_AUTO, exec_roles = ROLES })

local function vin(over)
  local inp = { data = D, state = { techs = { automation = true } }, stock = {}, flows = {},
    machines = {}, drills = {}, labs = {}, deposits = {}, open = {}, sinks = {}, workers = 30, idle = 10,
    can_grow = true, traits = {}, weights = {} }
  for k, v in pairs(over or {}) do inp[k] = v end
  return inp
end
local function pieces() return { ["electronic-circuit"] = 1000 } end

--- Gisement de fer, fours du QG, un puits de plaques de fer (sink) ; `over` remplace des champs.
local function iron_scene(sink, over)
  local inp = vin({
    stock = pieces(),
    deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60 },
      { id = "s2", resource = "iron-ore", tiles = 270, amount = 1e6, dist = 150 } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 2, deposit = "d1" } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 4, where = "qg" } },
    flows = { ["iron-ore"] = { made = 60 }, ["iron-plate"] = { made = 60 } },
    sinks = { { item = "iron-plate", rate = sink } } })
  for k, v in pairs(over or {}) do inp[k] = v end
  return inp
end
--- Un puits de rouages (60/min) : plaques, puis minerai en amont.
local function gear_scene(excl)
  return iron_scene(0, { sinks = { { item = "iron-gear-wheel", rate = 60 } }, excl = excl,
    machines = { { entity = "assembling-machine-1", recipe = "iron-gear-wheel", n = 1, where = "qg" },
      { entity = "stone-furnace", recipe = "iron-plate", n = 4, where = "qg" } } })
end
--- Recherche aux packs rouges, beaucoup de packs : la recherche visée est haute, des laboratoires sont à ajouter.
local function lab_scene(excl)
  return vin({ stock = pieces(), excl = excl,
    flows = { ["iron-plate"] = { made = 150 }, ["copper-plate"] = { made = 75 }, ["automation-science-pack"] = { made = 2400 } },
    machines = { { entity = "assembling-machine-1", recipe = "automation-science-pack", n = 400, where = "qg" },
      { entity = "stone-furnace", recipe = "iron-plate", n = 8, where = "d-fe" } },
    labs = { { entity = "lab", n = 2 } },
    research = { queue = { { tech = "fast-inserter", left = 1e5, time = 15, packs = { { "automation-science-pack", 1 } } } },
      rate = 6000, starved = 0 } })
end

local function decide(CaX, inp, cycles)
  local st, r = {}, nil
  for _ = 1, cycles or 1 do r = CaX.decide(deep(inp), st) end
  return r
end
local function find(res, pred)
  for _, o in ipairs(res.orders) do if pred(o) then return o end end
  return nil
end
local function refus_of(res, key)
  for _, r in ipairs(res.refus) do if r.key == key then return r end end
  return nil
end
local function touches(res, item)
  return find(res, function(o) return o.item == item or o.resource == item end) ~= nil
end

--- Tous les contrôles, sur les modules donnés (les mutants rejouent la suite sur un module modifié).
local function run_all(ExX, PfX, CaX, DX)
  D = DX
  -- 1. Ex.parse.
  do
    local set, list, bad = ExX.parse("iron-plate, copper-plate;lab  iron-plate\nz_9")
    check(#list == 4 and list[1] == "copper-plate" and list[2] == "iron-plate" and list[3] == "lab" and list[4] == "z_9",
      "1 : séparateurs virgule, point-virgule, blancs ; doublon retiré ; liste TRIÉE (" .. table.concat(list, "|") .. ")")
    check(set["iron-plate"] and set["lab"] and not set["iron"] and #bad == 0, "1 : ensemble exact, aucun jeton ignoré")
    local _, l2, b2 = ExX.parse("a/b, ok, c.d, e@f, plate-1")
    check(#l2 == 2 and l2[1] == "ok" and l2[2] == "plate-1" and #b2 == 3 and b2[1] == "a/b" and b2[2] == "c.d" and b2[3] == "e@f",
      "1 : jetons invalides ignorés ET dits, dans l'ordre de lecture (" .. table.concat(b2, "|") .. ")")
    for _, v in ipairs({ "", "   ", ",;, ;" }) do
      local s, l, b = ExX.parse(v)
      check(next(s) == nil and #l == 0 and #b == 0, "1 : chaîne vide (« " .. v .. " ») : rien d'exclu")
    end
    for _, v in ipairs({ 12, true, {} }) do
      local s, l = ExX.parse(v)
      check(next(s) == nil and #l == 0, "1 : entrée non textuelle (" .. type(v) .. ") : rien d'exclu")
    end
    local s0, l0 = ExX.parse(nil)
    check(next(s0) == nil and #l0 == 0, "1 : entrée absente : rien d'exclu")
    local many = {}
    for i = 1, ExX.MAX + 10 do many[i] = string.format("objet-%03d", i) end
    local sm, lm, bm = ExX.parse(table.concat(many, " "))
    check(#lm == ExX.MAX and #bm == 10 and sm["objet-001"] and not sm[many[ExX.MAX + 1]],
      "1 : au plus " .. ExX.MAX .. " objets, le reste ignoré et dit (" .. #lm .. ", " .. #bm .. ")")
    local sa, la = ExX.parse("b a c")
    local sb, lb = ExX.parse("c  b\na")
    check(table.concat(la, "|") == "a|b|c" and table.concat(la, "|") == table.concat(lb, "|") and ser(sa) == ser(sb),
      "1 : l'ordre des jetons est sans effet, la liste est triée")
  end

  -- 2. has, why, is_refusal, due.
  do
    local s = ExX.parse("iron-plate")
    check(ExX.has(s, "iron-plate") and not ExX.has(s, "copper-plate") and not ExX.has(s, nil) and not ExX.has(nil, "iron-plate")
      and not ExX.has("iron-plate", "iron-plate") and not ExX.has({ ["iron-plate"] = 1 }, "iron-plate"),
      "2 : Ex.has : vrai seulement pour un objet de l'ensemble (nil, texte, valeur non vraie : non)")
    local w = ExX.why("iron-plate")
    check(has(w, "iron-plate") and has(w, "fo-war-exclusion") and ExX.is_refusal(w) and not ExX.is_refusal("plafond x")
      and not ExX.is_refusal(nil), "2 : motif écrit qui nomme l'objet et le réglage ; Ex.is_refusal le reconnaît (" .. w .. ")")
    check(ExX.due(nil, 100) and not ExX.due(100, 200) and ExX.due(100, 100 + ExX.EVERY) and ExX.due(500, 100),
      "2 : Ex.due : premier refus écrit, puis une fois par 10 minutes ; un tick qui recule (rechargement) rouvre")
  end

  -- 3. Réglage vide : la décision est celle d'avant.
  do
    local base = decide(CaX, iron_scene(90), 3)
    local empty1 = decide(CaX, iron_scene(90, { excl = {} }), 3)
    local empty2 = decide(CaX, iron_scene(90, { excl = (ExX.parse("")) }), 3)
    check(ser(base) == ser(empty1) and ser(base) == ser(empty2), "3 : exclusion nil, {} et chaîne vide : mêmes rendus")
    check(touches(base, "iron-ore"), "3 : le témoin commande bien du minerai de fer (couvrir)")
    local lab0 = decide(CaX, lab_scene(nil), 4)
    check(ser(lab0) == ser(decide(CaX, lab_scene({}), 4)), "3 : même chose sur la scène des laboratoires")
    check(find(lab0, function(o) return o.kind == "labos" end) ~= nil, "3 : le témoin commande bien des laboratoires")
  end

  -- 4. Puits.
  do
    local r = decide(CaX, iron_scene(90, { excl = { ["iron-plate"] = true } }), 3)
    check(r.R["iron-plate"] == nil and #r.orders == 0, "4 : puits de plaques exclu : aucun besoin, aucun ordre")
    local r2 = decide(CaX, iron_scene(90, { excl = { ["iron-plate"] = true },
      sinks = { { item = "iron-plate", rate = 90 }, { item = "iron-gear-wheel", rate = 60 } },
      machines = { { entity = "assembling-machine-1", recipe = "iron-gear-wheel", n = 1, where = "qg" },
        { entity = "stone-furnace", recipe = "iron-plate", n = 4, where = "qg" } } }), 3)
    check((r2.R["iron-gear-wheel"] or 0) > 0, "4 : le puits d'un AUTRE objet reste servi (rouages : " .. tostring(r2.R["iron-gear-wheel"]) .. "/min)")
    local r3 = decide(CaX, iron_scene(90, { excl = { ["copper-plate"] = true } }), 3)
    check(ser(r3) == ser(decide(CaX, iron_scene(90), 3)), "4 : exclure un objet sans demande ne change rien")
  end

  -- 5. Options.
  do
    local r = decide(CaX, iron_scene(90, { excl = { ["iron-ore"] = true } }), 3)
    local rf = refus_of(r, "couvrir:d1")
    check(not touches(r, "iron-ore") and rf and ExX.is_refusal(rf.why) and has(rf.why, "iron-ore"),
      "5 : minerai exclu : aucune foreuse commandée, refus « exclu » sous la clé de l'ordre (" .. tostring(rf and rf.why) .. ")")
    local r2 = decide(CaX, lab_scene({ lab = true }), 4)
    local rl = refus_of(r2, "labos:lab")
    check(find(r2, function(o) return o.kind == "labos" end) == nil and rl and ExX.is_refusal(rl.why) and has(rl.why, "lab"),
      "5 : laboratoire exclu : aucun laboratoire commandé, refus écrit (" .. tostring(rl and rl.why) .. ")")
    local r3 = decide(CaX, lab_scene({ ["automation-science-pack"] = true }), 4)
    check(not touches(r3, "automation-science-pack"), "5 : pack exclu : aucune chaîne ni aucun pack commandé")
  end

  -- 6. Milieu de chaîne : rien en amont pour un objet exclu.
  do
    local ctl = decide(CaX, gear_scene(nil), 3)
    check(touches(ctl, "iron-ore") and (ctl.R["iron-ore"] or 0) > 0, "6 : témoin : les rouages demandent du minerai")
    local r = decide(CaX, gear_scene({ ["iron-plate"] = true }), 3)
    local rf = refus_of(r, "objet:iron-plate")
    check((r.R["iron-ore"] or 0) == 0 and not touches(r, "iron-ore") and rf and ExX.is_refusal(rf.why),
      "6 : plaques exclues : leur demande ne remonte pas au minerai, refus écrit (" .. tostring(rf and rf.why) .. ")")
    local r2 = decide(CaX, gear_scene({ ["iron-gear-wheel"] = true }), 3)
    check(#r2.orders == 0 and r2.R["iron-gear-wheel"] == nil and r2.R["iron-ore"] == nil,
      "6 : rouages exclus (le puits lui-même) : rien, aucun minerai")
  end

  -- 7. Pf.gate seule.
  do
    local refused = {}
    local function refuse(k, kd, it, w) refused[#refused + 1] = k .. "|" .. kd .. "|" .. tostring(it) .. "|" .. w end
    local function opt(key, kind, item, n)
      return { o = { key = key, kind = kind, item = item, n = n },
        mk = function(k) return { key = key, kind = kind, item = item, n = k } end }
    end
    local out = { opt("a", "chaine", "x-1", 3), opt("b", "chaine", "x-2", 1), opt("c", "couvrir", nil, 1), opt("d", "labos", "lab", 40) }
    out[3].o.resource = "x-ore"
    local kept = PfX.gate(out, { ["x-1"] = true, ["x-ore"] = true }, { labos = 20 }, refuse)
    local keys = {}
    for _, c in ipairs(kept) do keys[#keys + 1] = c.o.key .. ":" .. c.o.n end
    check(table.concat(keys, ",") == "b:1,d:5",
      "7 : objets exclus (item, resource) retirés ; labos 40 voulus pour 20 posés -> 5 (" .. table.concat(keys, ",") .. ")")
    check(#refused == 3 and refused[1]:find("^a|chaine|x%-1|exclu : x%-1") and refused[2]:find("^c|couvrir|nil|exclu : x%-ore")
      and refused[3]:find("^plafond:d|labos|nil|plafond labos : 20 posees ou ouvertes %+ 40 voulues > 25 au plus"),
      "7 : trois refus écrits (" .. table.concat(refused, " ; ") .. ")")
    check(kept[1] == out[2], "7 : une option qui passe est la MÊME table")
    refused = {}
    local kept2 = PfX.gate({ opt("d", "labos", "lab", 4) }, nil, { labos = 25 }, refuse)
    check(#kept2 == 0 and #refused == 1, "7 : au plafond : option retirée, refus écrit")
    refused = {}
    local kept3 = PfX.gate({ opt("d", "labos", "lab", 4) }, nil, {}, refuse)
    check(#kept3 == 0 and #refused == 1 and refused[1]:find("entree absente", 1, true),
      "7 : sorte plafonnée sans relevé : garde FERMÉE, motif (" .. tostring(refused[1]) .. ")")
    refused = {}
    local kept4 = PfX.gate({ opt("d", "labos", "lab", 4) }, nil, { labos = 3 }, refuse)
    check(#kept4 == 1 and kept4[1].o.n == 4 and #refused == 0, "7 : sous le plafond : intacte, aucun refus")
    check(#PfX.gate({}, { x = true }, nil, refuse) == 0, "7 : liste vide : liste vide")
  end

  -- 8. Déterminisme.
  do
    local a = ser(decide(CaX, gear_scene({ ["iron-plate"] = true }), 3))
    local b = ser(decide(CaX, gear_scene({ ["iron-plate"] = true }), 3))
    check(a == b, "8 : même entrée, même rendu")
    local c = ser(decide(CaX, gear_scene((ExX.parse("iron-plate iron-ore"))), 3))
    local d = ser(decide(CaX, gear_scene((ExX.parse("iron-ore, iron-plate"))), 3))
    check(c == d, "8 : ordre des jetons sans effet sur la décision")
  end
end

run_all(Ex, Pf, Ca, D)

-- 9. Mutants : un module modifié (texte remplacé) remplace l'original dans le cache, ceux qui en dépendent sont rechargés.
local function load_module(path, mutate)
  local src = slurp(path)
  local i, j = src:find(mutate[1], 1, true)
  assert(i, "texte introuvable : " .. mutate[1])
  src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  return assert(load(src, "@" .. path))()
end
local EXF, PFF, CAF = "shared/ai3/exclusion.lua", "shared/ai3/plafonds.lua", "shared/ai3/capitalisation.lua"
local MUTANTS = {
  { "jetons invalides acceptés", EXF, { 'if not tok:match("^[%w_%-]+$") then', "if false then" } },
  { "plafond du nombre d'objets retiré", EXF, { "if #list >= Ex.MAX then bad[#bad + 1] = tok", "if false then bad[#bad + 1] = tok" } },
  { "liste non triée", EXF, { "table.sort(list)", "" } },
  { "has ignore l'ensemble", EXF, { 'return type(set) == "table" and item ~= nil and set[item] == true', "return false" } },
  { "has lit toute valeur non nulle", EXF, { "set[item] == true", "set[item] ~= nil" } },
  { "motif sans le nom de l'objet", EXF, { 'Ex.WHY .. tostring(item) .. " (reglage "', 'Ex.WHY .. "?" .. " (reglage "' } },
  { "journal sans limite de fréquence", EXF, { "return last == nil or tick - last >= Ex.EVERY or tick < last", "return true" } },
  { "porte : option exclue gardée", PFF, { "if Ex.has(excl, item) then", "if false then" } },
  { "porte : refus d'exclusion non écrit", PFF, { "refuse(o.key, o.kind, o.item, Ex.why(item))", "" } },
  { "porte : plafond de sûreté non appliqué", PFF, { "elseif Pf.HARD_KIND[o.kind] == nil then", "elseif true then" } },
  { "porte : taille non réduite", PFF, { "elseif room > 0 and c.mk then", "elseif false then" } },
  { "porte : sorte plafonnée sans relevé lue comme 0", PFF,
    { "Pf.kind_room(o.kind, o.n, have and have[o.kind])", "Pf.kind_room(o.kind, o.n, (have and have[o.kind]) or 0)" } },
  { "capitalisation : puits exclu encore agrégé", CAF,
    { "if s.item ~= nil and not Pf.excluded(input.excl, s.item) then", "if s.item ~= nil then" } },
  { "capitalisation : recette choisie pour un objet exclu", CAF,
    { "if Pf.excluded(ctx.input.excl, item) then return nil, Pf.excluded_why(item) end", "" } },
  { "capitalisation : porte des options retirée", CAF, { "out = Pf.gate(out, ctx.input.excl,", "local _ = Pf.gate(out, ctx.input.excl," } },
}
local MOD = { [EXF] = "shared.ai3.exclusion", [PFF] = "shared.ai3.plafonds", [CAF] = "shared.ai3.capitalisation" }
local killed = 0
quiet = true
for _, m in ipairs(MUTANTS) do
  local saved = { package.loaded["shared.ai3.exclusion"], package.loaded["shared.ai3.plafonds"], package.loaded["shared.ai3.capitalisation"] }
  local okload, mod = pcall(load_module, m[2], m[3])
  local dead
  if not okload then
    quiet = false
    check(false, "mutant '" .. m[1] .. "' : " .. tostring(mod))
    quiet = true
    dead = false
  else
    if m[2] == EXF then
      package.loaded["shared.ai3.plafonds"], package.loaded["shared.ai3.capitalisation"] = nil, nil
    elseif m[2] == PFF then
      package.loaded["shared.ai3.capitalisation"] = nil
    end
    package.loaded[MOD[m[2]]] = mod
    local p0, f0 = pass, fail
    local okrun, e = pcall(function()
      local ExM = require("shared.ai3.exclusion")
      local PfM = require("shared.ai3.plafonds")
      local CaM = require("shared.ai3.capitalisation")
      local DM = CaM.data(vanilla_dump(), { exec = EXEC_AUTO, exec_roles = ROLES })
      run_all(ExM, PfM, CaM, DM)
    end)
    local nf = fail - f0
    dead = (not okrun) or nf > 0
    pass, fail = p0, f0
    quiet = false
    print(string.format("   %s : %s", m[1], (not okrun) and ("PLANTAGE " .. tostring(e):sub(1, 100)) or (nf .. " contrôle(s) en échec")))
    quiet = true
  end
  package.loaded["shared.ai3.exclusion"], package.loaded["shared.ai3.plafonds"], package.loaded["shared.ai3.capitalisation"] =
    saved[1], saved[2], saved[3]
  if dead then killed = killed + 1 else
    quiet = false
    check(false, "mutant SURVIVANT : " .. m[1])
    quiet = true
  end
end
quiet = false
print(string.format("   mutants refusés : %d / %d", killed, #MUTANTS))
check(killed == #MUTANTS, "tous les mutants sont refusés")

print(string.format("[EXCLUSION] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", pass, fail, killed, #MUTANTS))
os.exit(fail == 0 and 0 or 1)
