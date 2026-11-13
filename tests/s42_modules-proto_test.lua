--[[
  Sprint s42, sous-chantier « modules-proto » (chantier 2.1 du DC : « les fours ajoutés par le mod n'acceptent pas les modules »).
  Règle des emplacements par niveau (shared/content/modules.lua, level_slots), contrôle des données finales
  (tests/datastage/modules_slots.lua, le même que le harnais datastage) prouvé sur des tables de synthèse, et branchements
  (lecture du texte des générateurs). Lancement : lua5.2 tests/s42_modules-proto_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(c, msg) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end

local L = require("shared.levels.config")
local CM = require("shared.content.modules")
local MS = dofile("tests/datastage/modules_slots.lua")

-- 1. Règle par niveau : le four en a du niveau 2 au dernier, croissants ; le niveau 1 (four en acier vanilla) reste sans.
local fur, asm, drill, wall = L.by_key.furnace, L.by_key.assembler, L.by_key.drill, L.by_key.wall
check(CM.level_slots(L, fur, 1) == nil, "four niveau 1 = four en acier vanilla : aucun emplacement (comme le jeu)")
check(CM.level_slots(L, fur, 2) == L.MODULE_SLOTS_FIRST + L.MODULE_SLOTS_STEP, "four niveau 2 : premier niveau à emplacements")
do
  local ok, prev = true, 0
  for n = 2, fur.max do
    local s = CM.level_slots(L, fur, n)
    if not s or s <= prev or s ~= CM.level_slots(L, asm, n) then ok = false end
    prev = s or prev
  end
  check(ok, "four niveaux 2 à max : strictement croissants, même échelle que l'assembleur")
end
check(CM.level_slots(L, asm, 1) == L.module_slots(asm, 1) and CM.level_slots(L, drill, 30) == L.module_slots(drill, 30),
  "assembleur et foreuse : règle de L.module_slots inchangée")
check(wall == nil or CM.level_slots(L, wall, 5) == nil, "famille sans modules et hors table : aucun emplacement")
check(CM.MACHINE_SLOTS_MIN >= 1, "minimum des machines de production : au moins un emplacement")

-- 2. Contrôle des données finales sur des tables de synthèse.
local ALL = { "consumption", "speed", "productivity", "pollution" }
local function proto(slots, effects) return { module_specification = slots and { module_slots = slots } or nil, allowed_effects = effects, crafting_categories = { "smelting" } } end
local vanilla = { furnace = { ["steel-furnace"] = proto(nil, nil) }, ["assembling-machine"] = { ["assembling-machine-1"] = proto(nil, nil) } }
local function data(extra_f, extra_a)
  local d = { furnace = { ["steel-furnace"] = proto(nil, nil) }, ["assembling-machine"] = { ["assembling-machine-1"] = proto(nil, nil) } }
  for k, v in pairs(extra_f or {}) do d.furnace[k] = v end
  for k, v in pairs(extra_a or {}) do d["assembling-machine"][k] = v end
  return d
end
local function has(errs, text)
  for _, e in ipairs(errs) do if e:find(text, 1, true) then return true end end
  return false
end
do
  local errs, c = MS.check(data({ ["x-four-2"] = proto(6, ALL), ["x-four-3"] = proto(7, ALL) }, { ["x-machine"] = proto(2, ALL) }), vanilla)
  check(#errs == 0 and c.own == 3 and c.with_slots == 3, "données saines : aucune erreur ; la vanilla sans emplacement n'est pas jugée")
end
do
  local errs = MS.check(data({ ["x-four-2"] = proto(nil, nil) }), vanilla)
  check(#errs == 1 and has(errs, "furnace/x-four-2 : aucun emplacement"), "four du mod sans emplacement : refusé (le défaut de la 0.7.96)")
end
do
  local errs = MS.check(data(nil, { ["x-machine"] = proto(nil, nil) }), vanilla)
  check(#errs == 1 and has(errs, "assembling-machine/x-machine : aucun emplacement"), "machine d'assemblage du mod sans emplacement : refusée")
end
do
  local errs = MS.check(data({ ["x-four-2"] = proto(6, nil) }), vanilla)
  check(#errs == 1 and has(errs, "aucun effet admis"), "emplacements sans allowed_effects : refusé (le moteur n'admet alors aucun module)")
end
do
  local errs = MS.check(data({ ["x-four-2"] = proto(6, { "speed", "consumption", "pollution" }) }), vanilla)
  check(#errs == 1 and has(errs, "productivity"), "four sans l'effet de productivité : refusé")
end
do
  local errs = MS.check(data({ ["x-four-2"] = proto(7, ALL), ["x-four-3"] = proto(6, ALL), ["x-four-10"] = proto(9, ALL) }), vanilla)
  check(#errs == 1 and has(errs, "décroît"), "paliers : un nombre d'emplacements qui décroît est refusé (ordre numérique, 10 après 3)")
end
do
  local refus = { module_specification = { module_slots = 0 }, allowed_effects = {} }
  local errs, c = MS.check(data(nil, { ["x-calcul"] = refus, ["fo-flare-stack"] = proto(nil, nil) }), vanilla)
  check(#errs == 0 and c.declared_none == 1 and c.exempt == 1, "dispenses : refus déclaré dans le prototype (0 et {}), nom dispensé avec sa raison")
  local errs2 = MS.check(data(nil, { ["x-calcul"] = { module_specification = { module_slots = 0 } } }), vanilla)
  check(#errs2 == 1, "un 0 seul (allowed_effects absent) n'est PAS un refus déclaré")
end
do
  local names = {}
  for n in pairs(MS.EXEMPT) do names[#names + 1] = n end
  local ok = true
  for _, n in ipairs(names) do if type(MS.EXEMPT[n]) ~= "string" or #MS.EXEMPT[n] < 10 then ok = false end end
  check(ok and #names <= 3, "dispenses par nom : chacune a sa raison, la liste reste courte (" .. #names .. ")")
end
-- Productivité : recettes de la catégorie d'un four du mod absentes de la limitation.
do
  local d = data({ ["x-four-2"] = proto(6, ALL) })
  d.module = {
    p1 = { effect = { productivity = { bonus = 0.1 } }, limitation = { "a-plate", "b-plate" } },
    s1 = { effect = { speed = { bonus = 0.2 } } },
  }
  d.recipe = {
    ["a-plate"] = { category = "smelting" }, ["b-plate"] = { category = "smelting" }, ["c-plate"] = { category = "smelting" },
    ["cachee"] = { category = "smelting", hidden = true }, ["ailleurs"] = { category = "chemistry" }, ["main"] = {},
  }
  local gaps, nmods = MS.limitation_gaps(d, vanilla)
  check(nmods == 1 and #gaps == 1 and gaps[1].recipe == "c-plate" and gaps[1].module == "p1",
    "limitation : seule la recette de fonte visible hors liste est signalée ; le module de vitesse n'est pas lu")
end

-- 3. Branchements (texte des générateurs et du harnais).
local common = read("prototypes/levels/common.lua")
check(common:find('require("shared.content.modules").level_slots(L, family, n)', 1, true) ~= nil, "niveaux : apply_module_slots lit level_slots")
check(common:find('if p.allowed_effects == nil then p.allowed_effects = { "consumption", "speed", "productivity", "pollution" } end', 1, true) ~= nil,
  "niveaux : effets admis posés quand le modèle n'en déclare pas")
check(read("prototypes/crafts.lua"):find("if not spec.sink then lib.ensure_module_slots(e) end", 1, true) ~= nil, "crafts : machines de production, puits exclus")
check(read("prototypes/titanium.lua"):find("lib.ensure_module_slots(e)", 1, true) ~= nil, "titane : four à coke et concentrateur")
local harness = read("tests/datastage/harness.lua")
check(harness:find("MS.check(modded, vanilla)", 1, true) ~= nil and harness:find("and FO_MODULE_SLOTS_OK", 1, true) ~= nil,
  "harnais datastage : le contrôle entre dans le code de sortie")
check(read("shared/levels/config.lua"):find("modules_from", 1, true) == nil, "shared/levels/config.lua (fichier de l'intégrateur) non touché")

print(string.format("[S42-MODULES-PROTO] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
