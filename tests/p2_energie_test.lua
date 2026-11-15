--[[
  Lot P2-ENERGIE (pilier 2 du DC, 15/11 : « l'énergie suit en continu ») : deux maillons coupés.
  1. Un but du cerveau PAR centrale (shared/ai3/automatiser.lua, A.plant_product + A.goals) : avant, toutes les centrales portaient le
     produit « centrale », A.goals n'en gardait qu'une : les centrales de plus étaient servies à la file, et une centrale rouverte
     bloquée tenait seule le but (banc C3-APRES : centrales 8 et 9 à 0 entité bâtie de 14 à 40 min).
  2. Une pièce dont l'emprise porte une variante d'elle-même (tapis monté en tapis rapide) est bâtie (shared/team/piece_variante.lua).
  Lancer depuis la racine du mod :
    lua5.2 tests/p2_energie_test.lua   -> [P2E] BILAN : N OK, 0 ECHEC(S)
  Mutants : substitution unique dans le source, module rechargé ; la suite doit ÉCHOUER.
]]
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[P2E] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end

local function load_mod(path, name, src)
  local chunk = assert(load(src, "=" .. path))
  package.loaded[name] = nil
  local m = chunk(name)
  package.loaded[name] = m
  return m
end

-- 1. Buts des centrales -------------------------------------------------------------------------------------------------------
local APATH, ANAME = "shared/ai3/automatiser.lua", "shared.ai3.automatiser"
local ASRC = read(APATH)

-- La liste des modules telle que script/ai3/automatisation.lua la bâtit : la première centrale (rouverte, bloquée par un fantôme refusé),
-- puis les centrales de plus (b.extra_plants), en réserve de matériaux.
local function mods_of(A, first, extras)
  local mods = { { id = first.id, product = "centrale", state = first.state, missing = first.missing, reason = first.reason, gain = 0 } }
  for _, p in ipairs(extras) do
    mods[#mods + 1] = { id = p.id, product = A.plant_product(p.id, first.id), state = p.state, missing = p.missing, gain = 0 }
  end
  return mods
end

local function suite_goals(A)
  local bad = {}
  local function want(ok, msg) if not ok then bad[#bad + 1] = msg end end
  local first = { id = 1, state = "bloque", reason = "fantome refuse (transport-belt en 1.5,59.5)", missing = {} }
  local extras = {
    { id = 8, state = "reserve", missing = { { "boiler", 1 }, { "steam-engine", 2 } } },
    { id = 9, state = "reserve", missing = { { "boiler", 1 }, { "offshore-pump", 1 } } },
  }
  local goals = A.goals({}, { mods = mods_of(A, first, extras) }, { capital = 1000 }, nil)
  local by = {}
  for _, g in ipairs(goals) do by[g.key] = g end
  want(by["auto:centrale"] ~= nil, "la premiere centrale garde son but « auto:centrale »")
  want(by["auto:centrale"] and by["auto:centrale"].pids and by["auto:centrale"].pids[1] == 1, "« auto:centrale » vise le projet 1")
  want(by["auto:centrale-8"] ~= nil, "la centrale de plus 8 a son propre but (elle n'attend pas la centrale bloquee)")
  want(by["auto:centrale-9"] ~= nil, "la centrale de plus 9 a son propre but (deux centrales neuves en parallele)")
  want(by["auto:centrale-8"] and by["auto:centrale-8"].pids[1] == 8 and by["auto:centrale-8"].status == "reserve", "but 8 : projet 8, en reserve")
  want(by["auto:centrale-9"] and by["auto:centrale-9"].missing[2][1] == "offshore-pump", "but 9 : les manques du projet 9")
  want(by["auto:centrale-8"] and by["auto:centrale-8"].pile == nil, "centrale de plus : aucune famille de la pile (jamais suspendue)")
  -- nommage stable : le numéro du projet, jamais le rang dans la liste
  want(A.plant_product(1, 1) == "centrale" and A.plant_product(nil, 1) == "centrale", "premiere centrale : « centrale »")
  want(A.plant_product(48, 1) == "centrale-48" and A.plant_product(48, nil) == "centrale-48", "centrale de plus : « centrale-48 »")
  -- la première centrale finie : la seule centrale ouverte a son but
  local goals2 = A.goals({}, { mods = { { id = 8, product = A.plant_product(8, 1), state = "reserve", missing = {}, gain = 0 } } }, nil, nil)
  want(#goals2 == 1 and goals2[1].key == "auto:centrale-8", "une seule centrale de plus ouverte : un but")
  -- un but par produit reste la règle pour les autres modules
  local goals3 = A.goals({}, { mods = { { id = 3, product = "iron-plate", state = "reserve", missing = {}, gain = 0 },
    { id = 4, product = "iron-plate", state = "reserve", missing = {}, gain = 0 } } }, nil, nil)
  want(#goals3 == 1, "deux modules du meme objet : toujours un seul but")
  return bad
end

local A = load_mod(APATH, ANAME, ASRC)
for _, m in ipairs(suite_goals(A)) do check(false, m) end
check(#suite_goals(A) == 0, "buts des centrales")

-- 2. Variante de la pièce -----------------------------------------------------------------------------------------------------
local VPATH, VNAME = "shared/team/piece_variante.lua", "shared.team.piece_variante"
local VSRC = read(VPATH)

local function suite_variante(V)
  local bad = {}
  local function want(ok, msg) if not ok then bad[#bad + 1] = msg end end
  local plan = { type = "transport-belt", group = "transport-belt", x = 1.5, y = 59.5, dir = 0 }
  local occ = { type = "transport-belt", group = "transport-belt", x = 1.5, y = 59.5, dir = 0, own = true }
  want(V.same_piece(plan, occ) == true, "tapis rapide de l'equipe sur la tuile du tapis : adopte")
  want(V.same_piece(plan, { type = "transport-belt", group = "transport-belt", x = 1.5, y = 59.5, dir = 0, own = false }) == false, "autre force : non")
  want(V.same_piece(plan, { type = "transport-belt", group = "transport-belt", x = 1.5, y = 59.5, dir = 2, own = true }) == false, "autre orientation : non")
  want(V.same_piece(plan, { type = "transport-belt", group = "transport-belt", x = 2.5, y = 59.5, dir = 0, own = true }) == false, "autre tuile : non")
  want(V.same_piece(plan, { type = "splitter", group = "transport-belt", x = 1.5, y = 59.5, dir = 0, own = true }) == false, "autre type : non")
  want(V.same_piece(plan, { type = "transport-belt", group = "pipe", x = 1.5, y = 59.5, dir = 0, own = true }) == false, "autre groupe : non")
  want(V.same_piece({ type = "transport-belt", group = "", x = 1.5, y = 59.5 }, occ) == false, "sans groupe de remplacement : non")
  want(V.same_piece({ type = "underground-belt", group = "underground-belt", x = 3.5, y = 4.5, dir = 4, ug = "input" },
    { type = "underground-belt", group = "underground-belt", x = 3.5, y = 4.5, dir = 4, ug = "output", own = true }) == false, "souterrain : entree contre sortie, non")
  want(V.same_piece({ type = "underground-belt", group = "underground-belt", x = 3.5, y = 4.5, dir = 4, ug = "input" },
    { type = "underground-belt", group = "underground-belt", x = 3.5, y = 4.5, dir = 4, ug = "input", own = true }) == true, "souterrain : meme sens, oui")
  want(V.same_piece({ type = "inserter", group = "inserter", x = 0.5, y = 0.5 }, { type = "inserter", group = "inserter", x = 0.5, y = 0.5, own = true }) == true,
    "orientation absente des deux cotes : nord")
  return bad
end

local V = load_mod(VPATH, VNAME, VSRC)
local vb = suite_variante(V)
for _, m in ipairs(vb) do check(false, m) end
check(#vb == 0, "variante de la piece")

-- 2 bis. Priorité de matière de l'alimentation seulement quand l'énergie manque ------------------------------------------------
local NPATH, NNAME = "shared/team/vapeur.lua", "shared.team.vapeur"
local NSRC = read(NPATH)
local function suite_short(N)
  local bad = {}
  local function want(ok, msg) if not ok then bad[#bad + 1] = msg end end
  want(N.energy_short(false, false, 0) == false, "28,7 min de la reference : 5400 kW pour 2254, rien ne manque : pas de priorite")
  want(N.energy_short(false, false, nil) == false, "aucun releve : pas de priorite")
  want(N.energy_short(true, false, 0) == true, "centrale saturee : priorite")
  want(N.energy_short(false, true, 0) == true, "chaudieres a sec (20,8 min) : priorite")
  want(N.energy_short(false, false, 659) == true, "demande nominale manquante : priorite")
  return bad
end
local N = load_mod(NPATH, NNAME, NSRC)
local nb = suite_short(N)
for _, m in ipairs(nb) do check(false, m) end
check(#nb == 0, "priorite de l'alimentation")

-- 3. Mutants ------------------------------------------------------------------------------------------------------------------
local function mutant(path, name, src, from, to, suite, label)
  local a, b = src:find(from, 1, true)
  check(a ~= nil, "mutant " .. label .. " : motif trouve")
  if not a then return end
  local m = load_mod(path, name, src:sub(1, a - 1) .. to .. src:sub(b + 1))
  check(#suite(m) > 0, "mutant " .. label .. " : la suite echoue")
end
mutant(APATH, ANAME, ASRC, 'return "centrale-" .. tostring(id)', 'return "centrale"', suite_goals, "M1 (un seul produit pour toutes les centrales)")
mutant(VPATH, VNAME, VSRC, "if (plan.dir or 0) ~= (occ.dir or 0) then return false end", "", suite_variante, "M2 (orientation ignoree)")
mutant(VPATH, VNAME, VSRC, "plan.group ~= occ.group then return false end", "false then return false end", suite_variante, "M3 (groupe ignore)")
mutant(NPATH, NNAME, NSRC, "return type(missing_kw) == \"number\" and missing_kw > 0", "return true", suite_short, "M4 (priorite toujours, comme avant)")
mutant(NPATH, NNAME, NSRC, "if saturated == true or dry == true then return true end", "", suite_short, "M5 (saturation et sec ignores)")
load_mod(APATH, ANAME, ASRC)
load_mod(VPATH, VNAME, VSRC)
load_mod(NPATH, NNAME, NSRC)

print(string.format("[P2E] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
