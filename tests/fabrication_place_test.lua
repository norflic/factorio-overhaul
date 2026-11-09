--[[
  Lot POSE-PERDUE : shared/team/fabrication_place.lua (règle pure : fabrication sur place, une recette à la fois, file vide entre deux)
  et son câblage dans script/team/worker.lua (étape « craft_now », état « craft_now »).
  Usage, depuis la racine du mod :   lua5.2 tests/fabrication_place_test.lua

  Le cas du banc (0.6.75 A, graine 1618033988, azure, avant-poste 2, PNJ 13 à 53,3 min) : plan du livre = 15 pièces (2 brut
  chacune), 15 boîtes (5 cailloux chacune), 8 machines (3 pièces + 1 boîte + 3 brut) ; inventaire 54 brut, 75 cailloux, 9 pièces portées. L'ancienne
  étape lançait les trois recettes dans le même tick : 15 + 15 + 0 = 30 fabrications (la ligne du journal : « 30 fabrication(s)
  lancee(s) ») et aucune machine. Sections : 1. témoin (l'ancienne chaîne reproduite) ; 2. la règle ; 3. délai ; 4. mutants ;
  5. câblage (lecture du code source de worker.lua).
]]
package.path = "./?.lua;" .. package.path
local ok_n, bad = 0, 0
local function check(name, cond, detail)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[FABRICATION-PLACE] ECHEC : " .. name .. (detail and (" (" .. tostring(detail) .. ")") or "")) end
end
local function section(name) print("== " .. name) end

local function read(p) local h = io.open(p, "rb") if not h then return "" end local s = h:read("*a") h:close() return s end
local function load_rule(mut)
  local src = read("shared/team/fabrication_place.lua")
  if src == "" then return nil end
  if mut then src = mut(src) end
  local chunk = load(src, "=fabrication_place")
  return chunk and chunk() or nil
end

-- Personnage simulé : les mêmes règles que le moteur (et que tests/mock_engine.lua) : les ingrédients sortent de l'inventaire à la
-- mise en file, le produit n'y entre qu'à la fin de la fabrication ; une recette sans ses ingrédients n'est pas mise en file.
local RECETTES = {
  piece = { energy = 0.5, ings = { { "brut", 2 } }, out = "piece" },
  boite = { energy = 0.5, ings = { { "caillou", 5 } }, out = "boite" },
  machine = { energy = 2, ings = { { "piece", 3 }, { "boite", 1 }, { "brut", 3 } }, out = "machine" },
}
local function personnage(inv)
  local e = { inv = inv, queue = {}, tick = 0 }
  setmetatable(e, { __index = function(t, k) if k == "crafting_queue_size" then return #t.queue end end })
  e.begin_crafting = function(a)
    local r = RECETTES[a.recipe]
    local done = 0
    for _ = 1, a.count do
      local ok = true
      for _, ing in ipairs(r.ings) do if (e.inv[ing[1]] or 0) < ing[2] then ok = false end end
      if not ok then break end
      for _, ing in ipairs(r.ings) do e.inv[ing[1]] = e.inv[ing[1]] - ing[2] end
      local prev = e.queue[#e.queue] -- la main fabrique l'une après l'autre : chaque fabrication part à la fin de la précédente
      e.queue[#e.queue + 1] = { out = r.out, due = math.max(e.tick, prev and prev.due or 0) + math.ceil(r.energy * 60) }
      done = done + 1
    end
    return done
  end
  e.avance_temps = function(n) -- (le moteur) : les fabrications échues entrent dans l'inventaire
    e.tick = e.tick + n
    local rest = {}
    for _, q in ipairs(e.queue) do
      if q.due <= e.tick then e.inv[q.out] = (e.inv[q.out] or 0) + 1 else rest[#rest + 1] = q end
    end
    e.queue = rest
  end
  return e
end
local PLAN = { { recipe = "piece", runs = 15 }, { recipe = "boite", runs = 15 }, { recipe = "machine", runs = 8 } }
local function inventaire() return { brut = 54, caillou = 75, piece = 9 } end -- (9 pièces portées depuis le QG : 15 fabriquées + 9 = 24 = 8 x 3)

---------------------------------------------------------------------------------------------------
section("1. Témoin : l'ancienne chaîne (toutes les recettes dans le même tick) ne fabrique aucune machine")
do
  local e = personnage(inventaire())
  local n = 0
  for _, c in ipairs(PLAN) do
    local ok, k = pcall(e.begin_crafting, { count = c.runs, recipe = c.recipe, silent = true })
    if ok and type(k) == "number" then n = n + k end
  end
  check("30 fabrications lancées (15 + 15 + 0), comme la ligne du journal", n == 30, n)
  e.avance_temps(60 * 60)
  check("aucune machine dans l'inventaire : le PNJ arrive sans foreuse (« objets »)", (e.inv.machine or 0) == 0, e.inv.machine)
  check("les pièces et les boîtes, elles, sont là (elles rentrent au QG)", e.inv.piece == 24 and e.inv.boite == 15)
end

---------------------------------------------------------------------------------------------------
section("2. La règle : une recette à la fois, file vide entre deux : toutes les machines sont fabriquées")
local Fp = load_rule()
check("le module shared/team/fabrication_place.lua existe et rend Fp.avance", Fp ~= nil and type(Fp.avance) == "function")
local function derouler(Fp0, e, plan, pas, limite)
  -- la pensée du PNJ toutes les `pas` ticks ; rend le dernier verdict, le nombre de pensées et l'état
  local st = { i = 1, n = 0, t0 = e.tick }
  local r, pensees = nil, 0
  while pensees < limite do
    pensees = pensees + 1
    r = Fp0.avance(e, plan, st, e.tick, 5 * 60 * 60)
    if r == "fini" or r == "delai" then break end
    e.avance_temps(pas)
  end
  return r, pensees, st
end
if Fp then
  local e = personnage(inventaire())
  local r, pensees, st = derouler(Fp, e, PLAN, 6, 10000)
  check("verdict final « fini »", r == "fini", r)
  check("38 fabrications lancées (15 + 15 + 8)", st.n == 38, st.n)
  check("8 machines dans l'inventaire", e.inv.machine == 8, e.inv.machine)
  check("toutes les pièces et les boîtes consommées par les machines sauf les 7 boîtes à poser", e.inv.piece == 0 and e.inv.boite == 7, tostring(e.inv.piece) .. "/" .. tostring(e.inv.boite))
  check("plus rien en file", e.crafting_queue_size == 0)
  check("durée : la somme des énergies (31 s), au pas de pensée près", e.tick >= 31 * 60 and e.tick <= 31 * 60 + 3 * 6, e.tick)
  local nk = 0
  for _ in pairs(st) do nk = nk + 1 end -- (comptage seul : l'ordre ne compte pas)
  check("l'état porté par le PNJ n'est que des données", type(st.i) == "number" and type(st.n) == "number" and type(st.t0) == "number" and nk == 3)
  -- verdicts intermédiaires : « lance » à la mise en file, « attend » tant que la file est occupée
  local e2 = personnage(inventaire())
  local st2 = { i = 1, n = 0, t0 = 0 }
  check("1re pensée : « lance »", Fp.avance(e2, PLAN, st2, 0, 100) == "lance" and st2.i == 2 and st2.n == 15)
  check("file occupée : « attend », rien de plus lancé", Fp.avance(e2, PLAN, st2, 1, 100) == "attend" and st2.i == 2)
  e2.avance_temps(15 * 30)
  check("file vide : la recette suivante part", Fp.avance(e2, PLAN, st2, e2.tick, 100) == "lance" and st2.i == 3 and st2.n == 30)
  -- déterminisme : deux déroulés identiques
  local ea, eb = personnage(inventaire()), personnage(inventaire())
  local _, pa, sa = derouler(Fp, ea, PLAN, 6, 10000)
  local _, pb, sb = derouler(Fp, eb, PLAN, 6, 10000)
  check("déterminisme : même nombre de pensées et même état", pa == pb and sa.n == sb.n and sa.i == sb.i)
  -- une recette impossible (ingrédient absent) ne bloque pas les suivantes : begin_crafting rend 0, on passe
  local e3 = personnage({ brut = 54, caillou = 0 })
  local r3, _, st3 = derouler(Fp, e3, PLAN, 6, 10000)
  check("sans caillou : les boîtes passent à 0, le reste est tenté, verdict « fini »", r3 == "fini" and st3.i == 4 and (e3.inv.boite or 0) == 0)
end

---------------------------------------------------------------------------------------------------
section("3. Délai : une file qui ne se vide jamais ne retient pas le PNJ au-delà du délai")
if Fp then
  local e = personnage(inventaire())
  e.avance_temps = function(n) e.tick = e.tick + n end -- (le moteur n'achève rien : inventaire bloqué)
  local st = { i = 1, n = 0, t0 = 0 }
  check("mise en file", Fp.avance(e, PLAN, st, 0, 100) == "lance")
  check("avant le délai : « attend »", Fp.avance(e, PLAN, st, 100, 100) == "attend")
  check("après le délai : « delai »", Fp.avance(e, PLAN, st, 101, 100) == "delai")
end

---------------------------------------------------------------------------------------------------
section("4. Mutants : la règle cassée est vue")
if Fp then
  -- M1 : plus d'attente de la file vide (la coupe retirée : tout part d'un coup, comme avant)
  local M1 = load_rule(function(src) return (src:gsub("if e%.crafting_queue_size > 0 then", "if false then")) end)
  local e = personnage(inventaire())
  local _, _, st = derouler(M1, e, PLAN, 6, 10000)
  check("M1 (file non attendue) : 0 machine, 30 fabrications : rouge", (e.inv.machine or 0) == 0 and st.n == 30, tostring(e.inv.machine) .. "/" .. tostring(st.n))
  -- M2 : l'index n'avance pas : la même recette repart sans fin
  local M2 = load_rule(function(src) return (src:gsub("st%.i = st%.i %+ 1", "st.i = st.i")) end)
  local e2 = personnage(inventaire())
  local r2 = derouler(M2, e2, PLAN, 6, 200)
  check("M2 (index figé) : jamais « fini » : rouge", r2 ~= "fini", r2)
end

---------------------------------------------------------------------------------------------------
section("5. Câblage : script/team/worker.lua lance une recette à la fois depuis l'état « craft_now »")
do
  local wk = read("script/team/worker.lua")
  check("C1 : worker.lua charge la règle", wk:find('require("shared.team.fabrication_place")', 1, true) ~= nil)
  check("C2 : l'étape « craft_now » existe toujours (programme AUTO-FINANCEMENT et récolte urgente)", wk:find('elseif kind == "craft_now" then', 1, true) ~= nil)
  check("C3 : l'étape passe à l'état « craft_now » (et non plus une attente de ticks fixes)", wk:find('set(agent, "craft_now", tick)', 1, true) ~= nil)
  check("C4 : l'état appelle Fp.avance avec le délai des fabrications", wk:find("Fp.avance(e, step[2], st, tick, CRAFT_TIMEOUT)", 1, true) ~= nil)
  check("C5 : l'étape ne lance plus toutes les recettes dans le même tick", wk:find("for _, c in ipairs(step[2] or {}) do", 1, true) == nil)
  check("C6 : l'état n'avance le programme qu'à « fini » ou « delai »", wk:find('if r == "fini" or r == "delai" then', 1, true) ~= nil)
  check("C7 : le passage en arrière-plan efface l'état de la fabrication sur place", wk:find("agent.craft_i, agent.craft_started, agent.craft_place = nil, nil, nil", 1, true) ~= nil)
end

print(string.format("[FABRICATION-PLACE] %d OK, %d ECHEC", ok_n, bad))
if bad > 0 then os.exit(1) end
