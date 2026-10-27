--[[
  Lot AUTO « automatisation allumée » (27/10) : banc HORS JEU des règles pures ajoutées par le lot.
  Lancement : lua5.2 tests/auto_test.lua (depuis la racine du mod).

  Sections :
    1. K1 dans le cerveau général (shared/ai3/general.lua, Gen.k1) : une candidate voulue par l'automatisation ne passe
       pas devant un palier (pack ouvert, chaîne courte vers un pack, première consommation d'un pack) ; rien ne bouge
       quand la meilleure n'est pas « auto » ou est elle-même un palier ; chaîne longue : pas un palier ;
    2. tracé du tapis des foreuses (shared/team/plan.lua, P.belt_route) : sans options, résultat d'avant (A* exact) ;
       A* pondéré : chemin trouvé là où l'exact dépasse son plafond, contigu, au plus `weight` fois le coût optimal ;
       plafond = boîte entière : « aucun chemin » au lieu de « trop long » ;
    3. exécutants de l'automatisation (shared/ai3/automatiser.lua, A.exec_entities) : déduits des gabarits (centrale,
       fonderie, foreuses, machines des rangées), triés, sans doublon ;
    4. mutants : chaque règle retirée fait échouer au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path
local Gen = require("shared.ai3.general")
local P = require("shared.team.plan")
local A = require("shared.ai3.automatiser")
local M = require("shared.team.modules")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end

---------------------------------------------------------------------------------------------------
-- 1. K1
---------------------------------------------------------------------------------------------------
-- Catalogue minimal : packs P1 (déjà consommé par la technologie faite T0), P2 (jamais consommé).
local cat = {
  tech_list = { "T0", "TA", "TB", "TC", "TD", "TE" },
  techs = {
    T0 = { ingredients = { { "P1", 1 } } },
    TA = { ingredients = { { "P1", 1 } } }, -- voulue par l'automatisation
    TB = { ingredients = { { "P1", 1 } } }, -- ouvre un pack
    TC = { ingredients = { { "P1", 1 } } }, -- chaîne courte vers un pack
    TD = { ingredients = { { "P1", 1 }, { "P2", 1 } } }, -- première à consommer P2
    TE = { ingredients = { { "P1", 1 } } }, -- chaîne longue vers un pack
  },
  packs = { P1 = true, P2 = true },
}
local state = { techs = { T0 = true } }
local function cand(t, score, cost, why) return { tech = t, score = score, cost = cost, why = why or {} } end
local function run_k1(list, chains)
  Gen.k1(cat, state, list, chains or {})
  local out = {}
  for i, c in ipairs(list) do out[i] = c.tech end
  return table.concat(out, " ")
end

local function k1_cases()
  local r
  -- a. la meilleure est voulue (auto), un palier existe : le moins cher des paliers passe en tête
  r = run_k1({ cand("TA", 900, 500, { { "wanted", "x" } }), cand("TB", 300, 200, { { "pack", "P3" } }), cand("TE", 200, 100, {}) })
  check(r == "TB TA TE", "K1 a : pack ouvert devant la chaîne voulue (" .. r .. ")")
  -- b. la meilleure n'est pas « auto » : rien ne bouge
  r = run_k1({ cand("TE", 900, 500, {}), cand("TB", 300, 200, { { "pack", "P3" } }) })
  check(r == "TE TB", "K1 b : meilleure non voulue, ordre gardé (" .. r .. ")")
  -- c. chaîne courte (3) vers un pack : palier ; chaîne longue (4) : pas un palier
  r = run_k1({ cand("TA", 900, 500, { { "wanted", "x" } }), cand("TC", 300, 50, {}), cand("TE", 250, 10, {}) },
    { TC = { v = 33, target = "TX", len = 3, pack_len = 3 }, TE = { v = 25, target = "TY", len = 4, pack_len = 4 } })
  check(r == "TC TA TE", "K1 c : chaîne courte devant, chaîne longue non (" .. r .. ")")
  -- d. première consommation d'un pack (P2 jamais consommé par une technologie faite)
  r = run_k1({ cand("TA", 900, 500, { { "wanted", "x" } }), cand("TD", 100, 300, {}) })
  check(r == "TD TA", "K1 d : première consommation d'un pack devant (" .. r .. ")")
  -- e. auto par la CHAÎNE (vers un objet voulu) : même règle
  r = run_k1({ cand("TC", 900, 500, {}), cand("TB", 300, 200, { { "pack", "P3" } }) },
    { TC = { v = 25, target = "TA", len = 4, wanted = true } })
  check(r == "TB TC", "K1 e : chaîne voulue (drapeau de chaîne) derrière le palier (" .. r .. ")")
  -- f. la meilleure est auto ET palier : elle reste
  r = run_k1({ cand("TA", 900, 500, { { "wanted", "x" }, { "pack", "P3" } }), cand("TB", 300, 200, { { "pack", "P4" } }) })
  check(r == "TA TB", "K1 f : voulue qui ouvre un pack, gardée (" .. r .. ")")
  -- g. « pack, plus tard » (pack non fabricable ensuite) n'est pas un palier
  r = run_k1({ cand("TA", 900, 500, { { "wanted", "x" } }), cand("TB", 300, 200, { { "pack, plus tard", "P3" } }) })
  check(r == "TA TB", "K1 g : pack pas encore fabricable, pas un palier (" .. r .. ")")
  -- h. égalité de coût entre paliers : le nom départage
  r = run_k1({ cand("TA", 900, 500, { { "wanted", "x" } }), cand("TD", 300, 200, {}), cand("TB", 250, 200, { { "pack", "P3" } }) })
  check(r == "TB TA TD", "K1 h : égalité de coût départagée par le nom (" .. r .. ")")
end
section("1. K1 dans le cerveau général (Gen.k1)")
k1_cases()

-- Gen.chains porte les drapeaux (fixture minimale : point de départ pour les mutants de la section 4)
section("1 bis. drapeaux de chaîne de Gen.chains")
do
  local g_cat = {
    tech_list = { "U1", "U2", "W" },
    techs = {
      U1 = { prerequisites = {}, unlocks = {}, ingredients = { { "P1", 1 } }, bonus = {} },
      U2 = { prerequisites = { "U1" }, unlocks = { "rp" }, ingredients = { { "P1", 1 } }, bonus = {} },
      W = { prerequisites = { "U1" }, unlocks = { "rw" }, ingredients = { { "P1", 1 } }, bonus = {} },
    },
    products = { rp = { "pack2" }, rw = { "obj" } },
    role = { pack2 = "pack" },
    g = { machine = {}, unlocked_by = { rp = "U2", rw = "W" }, recipes = { rp = {}, rw = {} } },
  }
  local ev = { feas = { pack2 = true, obj = true }, tfeas = { U1 = true, U2 = true, W = true } }
  local ch = Gen.chains(g_cat, ev, { techs = {} }, { wanted = { obj = true } })
  check(ch.U1 ~= nil and ch.U1.pack_len == 2, "chaîne vers un pack : pack_len 2 sur le prérequis (" .. tostring(ch.U1 and ch.U1.pack_len) .. ")")
  check(ch.U1 ~= nil and ch.U1.wanted == true, "chaîne vers un objet voulu : drapeau wanted sur le prérequis")
end

---------------------------------------------------------------------------------------------------
-- 2. Tracé du tapis
---------------------------------------------------------------------------------------------------
section("2. tracé du tapis : A* exact, puis pondéré")
local function forest_cost(x, y)
  -- forêt : chaque tuile coûte 2 ; un mur vertical en x = 20 percé en y = 50
  if x == 20 and y ~= 50 then return nil end
  return 2
end
local box = { x0 = 0, y0 = 0, x1 = 60, y1 = 60 }
local s, t = { x = 2, y = 2 }, { x = 58, y = 6 }
local exact, ne = P.belt_route(s, t, P.E, box, forest_cost)
local exact2 = P.belt_route(s, t, P.E, box, forest_cost)
local function same(a, b)
  if not a or not b or #a ~= #b then return false end
  for i = 1, #a do if a[i].x ~= b[i].x or a[i].y ~= b[i].y or a[i].dir ~= b[i].dir then return false end end
  return true
end
check(exact ~= nil and same(exact, exact2), "sans options : A* exact, résultat stable (" .. tostring(ne) .. " nœuds)")
local capped, why = P.belt_route(s, t, P.E, box, forest_cost, { max = 300 })
check(capped == nil and why == "trop long", "plafond de nœuds : « trop long » (" .. tostring(why) .. ")")
local wr, wn = P.belt_route(s, t, P.E, box, forest_cost, { weight = 2, max = 61 * 61 })
local function contiguous(tiles)
  for i = 2, #tiles do
    if math.abs(tiles[i].x - tiles[i - 1].x) + math.abs(tiles[i].y - tiles[i - 1].y) ~= 1 then return false end
  end
  return tiles[1].x == s.x and tiles[1].y == s.y and tiles[#tiles].x == t.x and tiles[#tiles].y == t.y
end
check(wr ~= nil and contiguous(wr), "A* pondéré : chemin contigu de la queue à l'arrivée")
check(wr ~= nil and type(wn) == "number" and type(ne) == "number" and wn < ne, string.format("A* pondéré : moins de nœuds (%s contre %s)", tostring(wn), tostring(ne)))
check(wr ~= nil and exact ~= nil and #wr <= 2 * #exact, string.format("A* pondéré : au plus 2 fois le coût optimal (%s contre %s tuiles)", wr and #wr or -1, exact and #exact or -1))
local function wall_cost(x, y) if x == 20 then return nil end return 1 end
local none, why2 = P.belt_route(s, t, P.E, box, wall_cost, { weight = 2, max = 61 * 61 })
check(none == nil and why2 == "aucun chemin", "boîte entière sans passage : « aucun chemin » (" .. tostring(why2) .. ")")
check(wr ~= nil and wr[#wr].dir == P.E, "dernière tuile tournée vers la direction d'arrivée")

---------------------------------------------------------------------------------------------------
-- 3. Exécutants
---------------------------------------------------------------------------------------------------
section("3. exécutants de l'automatisation (A.exec_entities)")
local ex = A.exec_entities()
local set = {}
local sorted, dup = true, false
for i, n in ipairs(ex) do
  if set[n] then dup = true end
  set[n] = true
  if i > 1 and ex[i - 1] >= n then sorted = false end
end
check(#ex > 0 and sorted and not dup, "liste triée sans doublon (" .. #ex .. " entités)")
for _, name in ipairs(A.MACHINES) do check(set[name] == true, "machine des rangées générées : " .. name) end
local plant = M.GEN[A.PLANT.gen](table.unpack(A.PLANT.args))
local all_plant = true
for _, e in ipairs(plant.entities) do if not set[e.name] then all_plant = false end end
check(all_plant, "toutes les entités du gabarit de la centrale (pompe, chaudière, générateur, poteaux)")
local ore_m
for _, m in ipairs(A.METHODS) do if m.ore then ore_m = m break end end
local dr = ore_m and M.GEN.drills(ore_m.ore, 1)
local all_dr = dr ~= nil
for _, e in ipairs((dr and dr.entities) or {}) do if not set[e.name] then all_dr = false end end
check(all_dr, "toutes les entités des foreuses d'une fonderie à minerai")

---------------------------------------------------------------------------------------------------
-- 4. Mutants
---------------------------------------------------------------------------------------------------
section("4. mutants")
local function mutant(name, apply, undo, body)
  local p0, f0 = passes, failures
  quiet = true
  apply()
  local ok = pcall(body)
  undo()
  quiet = false
  local caught = (failures > f0) or not ok
  passes, failures = p0, f0
  check(caught, "mutant refusé : " .. name)
end
do
  local k1 = Gen.k1
  mutant("Gen.k1 sans effet", function() Gen.k1 = function() end end, function() Gen.k1 = k1 end, k1_cases)
  local near = Gen.K1_NEAR
  mutant("chaîne courte à 4 technologies", function() Gen.K1_NEAR = 4 end, function() Gen.K1_NEAR = near end, k1_cases)
  mutant("chaîne courte à 2 technologies", function() Gen.K1_NEAR = 2 end, function() Gen.K1_NEAR = near end, k1_cases)
  local br = P.belt_route
  mutant("A* pondéré ignoré", function() P.belt_route = function(a, b, c, d, e, o) return br(a, b, c, d, e, o and { max = o.max } or nil) end end,
    function() P.belt_route = br end, function()
      local r1, n1 = P.belt_route(s, t, P.E, box, forest_cost, { weight = 2, max = 61 * 61 })
      check(r1 ~= nil and n1 < ne, "pondéré : moins de nœuds")
    end)
  local ae = A.exec_entities
  mutant("centrale absente des exécutants", function()
    A.exec_entities = function()
      local out = {}
      for _, n in ipairs(ae()) do if n ~= plant.entities[1].name then out[#out + 1] = n end end
      return out
    end
  end, function() A.exec_entities = ae end, function()
    local s2 = {}
    for _, n in ipairs(A.exec_entities()) do s2[n] = true end
    local okp = true
    for _, e in ipairs(plant.entities) do if not s2[e.name] then okp = false end end
    check(okp, "centrale complète")
  end)
end

print(string.format("[AUTO] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
