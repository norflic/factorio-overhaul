--[[
  Tests hors jeu du lot CENTRALE-PRES : une centrale ne se demande qu'avec un poteau OBTENABLE (shared/team/centrale_pole.lua,
  script/team/plant_arms.lua, script/team/build.lua). Usage :   lua5.2 tests/centrale_pole_test.lua

  Défaut mesuré (partie neuve 0.6.70, journal fo-logs/2026-11-08_INTEG-0670/neuve40-b-a627035e, votre équipe) : la centrale de 4
  chaudières n'a jamais été construite. Le gabarit de 4 chaudières ne passe pas M.check avec le petit poteau (machines à vapeur hors de
  l'aire des poteaux dès 3 chaudières) ; template_of cédait au poteau MOYEN (recette fermée) : 34 poteaux moyens réservés, jamais
  couverts, « reserve:materiaux » puis « annule (delai) » à 37 min.

  1. Règle pure (CP.fit, CP.candidates, CP.dead) sur les VRAIS gabarits de shared/team/modules.lua.
  2. Moteur simulé (PA.obtainable, PA.fit, PA.size, PA.dead) : recettes lues aux prototypes et à la force, aucun nom écrit dans l'IA.
  3. Branchement dans build.lua (lecture des sources) et coût mesuré par debug.sethook.
  4. Mutants : chacun refait le défaut et doit faire échouer au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
end
local function section(name) if not quiet then print("== " .. name) end end
local function read_file(path) local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s end

local M = require("shared.team.modules")
local SMALL = "small-electric-pole"
local MEDIUM = M.DEFAULT_POLE

--- Batterie de la règle pure sur un module CP (le vrai ou un mutant).
local function pure(CP)
  section("1. Règle pure sur les vrais gabarits")
  check(CP.valid("steam", SMALL, 1) and CP.valid("steam", SMALL, 2), "gabarit de 1 et 2 chaudieres : valide au petit poteau")
  check(not CP.valid("steam", SMALL, 3) and not CP.valid("steam", SMALL, 4), "gabarit de 3 et 4 chaudieres : INVALIDE au petit poteau (machines hors de l'aire)")
  check(CP.valid("steam", MEDIUM, 4), "gabarit de 4 chaudieres : valide au poteau moyen")
  check(not CP.valid("inconnu", SMALL, 1), "generateur inconnu : invalide")
  local valid = function(pole, n) return CP.valid("steam", pole, n) end
  -- le moyen est fermé : seul le petit est obtenable, la centrale de 4 est ramenée à 2 (défaut de la partie neuve)
  local n, pole, reduced = CP.fit(4, { SMALL }, valid)
  check(n == 2 and pole == SMALL and reduced == true, "4 chaudieres, petit seul : 2 chaudieres au petit poteau (" .. tostring(n) .. ", " .. tostring(pole) .. ")")
  n, pole, reduced = CP.fit(2, { SMALL }, valid)
  check(n == 2 and pole == SMALL and reduced == false, "2 chaudieres tiennent telles quelles")
  -- le moyen est ouvert : comportement d'avant (le petit ne tient pas, le moyen prend la taille demandée)
  n, pole, reduced = CP.fit(4, { SMALL, MEDIUM }, valid)
  check(n == 4 and pole == MEDIUM and reduced == false, "petit puis moyen obtenables : 4 chaudieres au moyen, comme avant")
  n, pole = CP.fit(4, { MEDIUM }, valid)
  check(n == 4 and pole == MEDIUM, "moyen seul : 4 chaudieres")
  -- aucun poteau obtenable : refus avec cause
  local why
  n, why = CP.fit(4, {}, valid)
  check(n == nil and type(why) == "string" and why:find("obtenable", 1, true), "aucun poteau obtenable : refus avec sa cause")
  n, why = CP.fit(4, { SMALL }, function() return false end)
  check(n == nil and type(why) == "string", "aucun gabarit ne tient : refus avec sa cause")
  n = CP.fit(0, { SMALL }, valid)
  check(n == nil, "taille demandee nulle : rien")
  check(CP.fit(0, { SMALL }, function() return true end) == nil, "taille demandee nulle : rien, meme si un gabarit « tient »")
  -- candidats
  local obt = { [SMALL] = true, [MEDIUM] = false }
  local c = CP.candidates(SMALL, MEDIUM, function(x) return obt[x] end)
  check(#c == 1 and c[1] == SMALL, "candidats : le petit seul quand le moyen est ferme")
  c = CP.candidates(nil, MEDIUM, function(x) return obt[x] end)
  check(#c == 0, "candidats : pas de prefere et defaut ferme -> aucun")
  obt[MEDIUM] = true
  c = CP.candidates(SMALL, MEDIUM, function(x) return obt[x] end)
  check(#c == 2 and c[1] == SMALL and c[2] == MEDIUM, "candidats : prefere puis defaut")
  c = CP.candidates(MEDIUM, MEDIUM, function(x) return obt[x] end)
  check(#c == 1, "candidats : pas de doublon")
  -- manques sans issue
  local dead = CP.dead({ { MEDIUM, 34 }, { "steam-engine", 5 }, { "zzz", 0 } }, function(x) return x == "steam-engine" end)
  check(#dead == 1 and dead[1] == MEDIUM, "dead : le poteau moyen seul (l'objet a 0 manquant est ignore)")
  dead = CP.dead({ { "b", 1 }, { "a", 1 } }, function() return false end)
  check(#dead == 2 and dead[1] == "a" and dead[2] == "b", "dead : liste triee")
  check(#CP.dead({}, function() return false end) == 0 and #CP.dead(nil, function() return false end) == 0, "dead : rien a manquer, rien de mort")
end

local CP0 = dofile("shared/team/centrale_pole.lua")
pure(CP0)

---------------------------------------------------------------------------------------------------
-- 2. Moteur simulé : plant_arms.lua
---------------------------------------------------------------------------------------------------
local arms_src = read_file("script/team/plant_arms.lua")
local build_src = read_file("script/team/build.lua")
local recipes = dofile("tests/fixtures/recipes.lua")

local function make_world(open)
  -- open = { [recette] = vrai } : recettes ouvertes à la force ; tout le reste est fermé
  return {
    recipe_prototypes = recipes,
    forces = { f = { recipes = setmetatable({}, { __index = function(_, name)
      if not recipes[name] then return nil end
      return { name = name, enabled = open[name] == true }
    end }) } },
  }
end

local function load_arms(src, chest)
  log = function() end
  package.preload["script.team.stock"] = function() return { count = function(_, item) return chest[item] or 0 end } end
  package.preload["script.team.centrale_mort"] = function() return {} end
  package.loaded["script.team.plant_arms"] = nil
  local fn = assert(load(src, "=plant_arms"))
  return fn()
end

--- Batterie moteur sur un module PA chargé avec le coffre `chest`.
local function engine(mk_arms)
  section("2. Moteur simulé : obtenable, taille, refus")
  local chest = {}
  local PA = mk_arms(chest)
  local f = { key = "player", force = "f", build = { grow = { requests = 3 } } }
  local logs = {}
  log = function(s) logs[#logs + 1] = s end
  -- le départ de la partie neuve : le petit poteau est ouvert, le moyen non
  game = make_world({ [SMALL] = true, ["steam-engine"] = true, ["boiler"] = true })
  PA.reset_producers()
  check(PA.obtainable(f, SMALL), "petit poteau : recette ouverte")
  check(not PA.obtainable(f, MEDIUM), "poteau moyen : recette fermee et coffre vide = non obtenable")
  check(PA.obtainable(f, "coal"), "charbon : matiere naturelle (aucune recette), obtenable")
  chest[MEDIUM] = 1
  check(PA.obtainable(f, MEDIUM), "poteau moyen au coffre : obtenable")
  chest[MEDIUM] = nil
  local n, pole, reduced = PA.fit(f, "steam", 4, SMALL)
  check(n == 2 and pole == SMALL and reduced == true, "PA.fit 4 chaudieres, petit prefere, moyen ferme : 2 au petit (" .. tostring(n) .. ")")
  n, pole = PA.fit(f, "steam", 4, nil)
  check(n == nil, "PA.fit sans prefere, defaut ferme : refus (" .. tostring(n) .. ")")
  -- PA.size : la demande est ramenee, journalisee ; aucune pause
  logs = {}
  n, pole = PA.size(f, "steam", 4, SMALL, 7000, false)
  check(n == 2 and pole == SMALL, "PA.size : 2 chaudieres au petit poteau")
  check(#logs == 1 and logs[1]:find("ramenee a 2", 1, true) and logs[1]:find("NON obtenable", 1, true), "PA.size : journal [FO-ENERGIE] « ramenee a 2 », defaut NON obtenable")
  check((f.build.grow.cool_until or 0) == 0 and f.build.grow.requests == 3, "PA.size : ni pause ni demande rendue quand la centrale part")
  -- refus immédiat : aucun poteau obtenable
  game = make_world({ ["steam-engine"] = true })
  PA.reset_producers()
  logs = {}
  n = PA.size(f, "steam", 4, SMALL, 7000, false)
  check(n == nil, "PA.size : aucun poteau obtenable, refus")
  check(f.build.grow.cool_until and f.build.grow.cool_until >= 7000 + 36000, "refus : pause de dix minutes (C.COOL)")
  check(f.build.grow.requests == 2, "refus : la demande n'a pas eu lieu, rendue au compte des demandes")
  check(#logs == 1 and logs[1]:find("REFUSEE", 1, true) and logs[1]:find("aucune reserve ouverte", 1, true), "refus : journal [FO-ENERGIE] avec la cause")
  -- recherche finie : le moyen s'ouvre, la taille demandée repart au moyen, comme avant
  game = make_world({ [SMALL] = true, [MEDIUM] = true })
  PA.reset_producers()
  n, pole, reduced = PA.fit(f, "steam", 4, SMALL)
  check(n == 4 and pole == MEDIUM and reduced == false, "moyen ouvert a la force : 4 chaudieres au moyen (comme avant le lot)")
  -- manques morts d'une réserve
  game = make_world({ [SMALL] = true })
  PA.reset_producers()
  local dead = PA.dead(f, { { MEDIUM, 34 }, { "coal", 2 }, { SMALL, 4 } })
  check(#dead == 1 and dead[1] == MEDIUM, "PA.dead : le moyen seul est sans issue (charbon naturel, petit ouvert)")
  chest[MEDIUM] = 34
  check(#PA.dead(f, { { MEDIUM, 34 } }) == 0, "PA.dead : le moyen au coffre n'est pas mort")
end

engine(function(chest) return load_arms(arms_src, chest) end)

---------------------------------------------------------------------------------------------------
-- 3. Branchement (sources) et coût
---------------------------------------------------------------------------------------------------
section("3. Branchement dans build.lua, coût")
local function between(src, a_mark, b_mark)
  local a = assert(src:find(a_mark, 1, true), "repere absent : " .. a_mark)
  local b = assert(src:find(b_mark, a, true), "repere absent : " .. b_mark)
  return src:sub(a, b - 1)
end
local wiring = function(bsrc)
  local grow = between(bsrc, "function Build.grow_plant(", "b.projects[id].secours")
  check(grow:find("PlantArms.size(f, first.spec.gen, nb, first.spec.pole, tick, secours)", 1, true) ~= nil, "grow_plant : la taille et le poteau passent par PlantArms.size")
  check(grow:find("if not nb then return nil end", 1, true) ~= nil, "grow_plant : refus immediat sans reserve")
  check(grow:find("pole = pole, plant = true", 1, true) ~= nil, "grow_plant : la demande porte le poteau obtenable choisi")
  check(grow:find("args = { nb }", 1, true) ~= nil, "grow_plant : la demande porte la taille reduite")
  local res = between(bsrc, "-- lot CENTRALE-PRES : une réserve de centrale", "p.reason, p.reserve_next = \"materiaux\", tick + 60")
  check(res:find("PlantArms.dead(f, p.missing)", 1, true) ~= nil and res:find("Build.cancel(f, p.id, cause)", 1, true) ~= nil, "reserve : manque sans issue refuse tout de suite")
  check(res:find("f.build.plant ~= p.id", 1, true) ~= nil and res:find("not p.reopened", 1, true) ~= nil, "reserve : ni la premiere centrale ni un projet rouvert")
end
wiring(build_src)
check(arms_src:find("table.sort(names)", 1, true) ~= nil, "plant_arms : les recettes sont parcourues par noms tries (determinisme)")

-- coût par instructions (debug.sethook), pire cas : refus après essai de toutes les tailles
do
  local chest = {}
  local PA = load_arms(arms_src, chest)
  local f = { key = "player", force = "f", build = { grow = {} } }
  game = make_world({ ["steam-engine"] = true })
  PA.reset_producers()
  log = function() end
  local count = 0
  debug.sethook(function() count = count + 1 end, "", 1000)
  PA.size(f, "steam", 6, SMALL, 1, false)
  debug.sethook()
  io.write(string.format("  cout du refus de 6 chaudieres : environ %d milliers d'instructions\n", count))
  check(count < 5000, "cout : un refus de 6 chaudieres < 5 millions d'instructions (une demande par dix minutes)")
  count = 0
  debug.sethook(function() count = count + 1 end, "", 1000)
  for _ = 1, 100 do PA.dead(f, { { MEDIUM, 34 }, { "steam-engine", 5 } }) end
  debug.sethook()
  io.write(string.format("  cout de 100 PA.dead (index deja construit) : environ %d milliers d'instructions\n", count))
  check(count < 200, "cout : PA.dead par seconde < 2 000 instructions")
end

---------------------------------------------------------------------------------------------------
-- 4. Mutants
---------------------------------------------------------------------------------------------------
local pole_src = read_file("shared/team/centrale_pole.lua")
local function sub(src, a, b)
  local i, j = src:find(a, 1, true)
  assert(i, "mutant : repere absent : " .. a)
  return src:sub(1, i - 1) .. b .. src:sub(j + 1)
end
local mutants = {
  { "cede au defaut sans le tester : candidats sans obtenable (le defaut)", "pure",
    sub(pole_src, "      if obtainable(name) then out[#out + 1] = name end", "      out[#out + 1] = name") },
  { "pas de reduction : refus des qu'un poteau ne tient pas", "pure",
    sub(pole_src, "for n = nb - 1, 1, -1 do", "for n = nb - 1, nb, -1 do") },
  { "reduction a une chaudiere seulement", "pure",
    sub(pole_src, "for n = nb - 1, 1, -1 do", "for n = 1, 1 do") },
  { "valid toujours vrai (le controle M.check est perdu)", "pure",
    sub(pole_src, "return #M.check(g) == 0", "return true") },
  { "dead vide (la reserve dort)", "pure",
    sub(pole_src, "if (m[2] or 0) > 0 and not obtainable(m[1]) then out[#out + 1] = m[1] end", "") },
  { "dead non trie", "pure",
    sub(pole_src, "table.sort(out)\n  return out\nend\n\nreturn CP", "return out\nend\n\nreturn CP") },
  { "taille nulle acceptee", "pure",
    sub(pole_src, "if not nb or nb < 1 then return nil, \"taille demandee nulle\" end", "") },
  { "obtenable toujours vrai (recette fermee ignoree)", "engine",
    sub(arms_src, "    if r and r.enabled then return true end\n  end\n  return false\nend", "    if r and r.enabled then return true end\n  end\n  return true\nend") },
  { "coffre ignore", "engine",
    sub(arms_src, "if Stock.count(f, name) > 0 then return true end\n  local list = producers()", "local list = producers()") },
  { "matiere naturelle jugee non obtenable", "engine",
    sub(arms_src, "if not list then return true end", "if not list then return false end") },
  { "refus sans pause", "engine",
    sub(arms_src, "g.cool_until = math.max(g.cool_until or 0, tick + C.COOL)", "") },
  { "refus qui garde la demande au compte", "engine",
    sub(arms_src, "g.requests = math.max(0, (g.requests or 0) - 1)", "") },
  { "taille sans le poteau prefere (defaut seul)", "engine",
    sub(arms_src, "Cp.candidates(pref, M.DEFAULT_POLE,", "Cp.candidates(nil, M.DEFAULT_POLE,") },
  { "build : la demande ne porte plus le poteau choisi", "wiring",
    sub(build_src, "pole = pole, plant = true }) -- (intégration 0.6.28", "pole = first.spec.pole, plant = true }) -- (intégration 0.6.28") },
  { "build : la demande garde la taille d'origine", "wiring",
    sub(build_src, "  local id = Build.request(f, { gen = first.spec.gen, args = { nb }, feed = true, prio = Build.PRIO + 5, domain = \"infrastructures\",\n    pole = pole,",
      "  local id = Build.request(f, { gen = first.spec.gen, args = { 4 }, feed = true, prio = Build.PRIO + 5, domain = \"infrastructures\",\n    pole = pole,") },
  { "build : la reserve morte n'est plus refusee", "wiring",
    sub(build_src, "PlantArms.dead(f, p.missing)", "{}") },
}
local refused = 0
for _, m in ipairs(mutants) do
  local before = failures
  quiet = true
  local ok = pcall(function()
    if m[2] == "pure" then
      local chunk = assert(load(m[3], "=mutant"))
      pure(chunk())
    elseif m[2] == "engine" then
      engine(function(chest) return load_arms(m[3], chest) end)
    else
      wiring(m[3])
    end
  end)
  quiet = false
  local killed = (failures > before) or not ok
  failures = before
  if killed then refused = refused + 1; passes = passes + 1 else failures = failures + 1; print("  ECHEC : mutant SURVIVANT : " .. m[1]) end
end
print(string.format("  mutants refuses : %d sur %d", refused, #mutants))

print(string.format("[CENTRALE-PRES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
