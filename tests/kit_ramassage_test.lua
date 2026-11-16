--[[
  Lot n101-ramassage (B2 : deux prises comptent la même matière libre) : un kit d'amélioration (script/ai3/capital.lua, continu_track) est
  taillé à la pensée (E6) sur TOUTE la matière libre au registre (Bm.best) ; sa prise stricte (script/team/board.lua, claim_market) le
  voulait encore entier : une seule unité réservée entre-temps par une autre prise le rendait non prenable jusqu'à la pensée suivante, qui
  le retaillait sur le nouveau libre, de nouveau pris par d'autres. Banc n100-kits (4251870853, player) : tapis rapides lot 40 émis à
  19,8 min, première sortie de fer du kit à 54 min. Règle : un kit marqué `fit` est replanifié à la prise sur la matière libre (au plus
  son nombre, au moins une pièce), sinon il reste non prenable.
  Mutants : sans le drapeau `fit` (l'ancien kit), sans livre (Board.book_of absent) : le kit n'est pas pris.
  Lancement : lua5.2 tests/kit_ramassage_test.lua (racine du mod, quelques secondes).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local M = require("tests.mock_engine")
local ITEM, PLATE = "iron-gear-wheel", "iron-plate" -- données du test (la règle n'en nomme aucun)

local function new_team(seed)
  M.new_game({ patches = { { x = 60, y = 0, name = "iron-ore" } }, p_busy = 0.01, p_nopath = 0.01, p_lost = 0, seed = seed })
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  chest.insert({ name = PLATE, count = 400 })
  M.world().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  M.run_ticks(120)
  return global.fo.pteam.team
end

--- Monde du symptôme : kit taillé sur tout le fer libre, puis une autre prise réserve `stolen` plaques. Rend f, kit, PNJ, réglages.
local function scene(opts)
  local f = new_team(17)
  local Board = require("script.team.board")
  local Registry = require("script.companion.registry")
  local Stock = require("script.team.stock")
  local State = require("script.faction.state")
  local R = require("shared.ai3.registre")
  local Bm = require("shared.team.book_max")
  local tick = game.tick
  local b = Board.get(f)
  b.tasks, b.cooldown, b.hint, b.hinted, b.born, b.hold_left = {}, {}, nil, nil, nil, nil
  -- registre remis à la vérité du coffre, projets en cours rendus
  local reg = f.team.reg or R.new()
  f.team.reg = reg
  for _, id in ipairs(State.sorted_keys(reg.projects)) do R.release(reg, id) end
  local free = Board.view_stock(f, Stock.contents(f), tick, true)
  local book = Board.book_of and Board.book_of(f)
  local avail = {}
  for _, k in ipairs(State.sorted_keys(free)) do avail[k] = math.min(free[k], math.max(0, R.free(reg, k))) end
  avail[ITEM] = 0
  local m, q = Bm.best(book, ITEM, opts.want or 1000, avail)
  local uses = {}
  for _, k in ipairs(State.sorted_keys(q.uses)) do uses[#uses + 1] = { k, q.uses[k] } end
  local kit = { key = "craft:" .. ITEM .. ":amelio", kind = "craft", prio = 47, item = ITEM, count = m, steps = q.crafts, uses = uses,
    tag = "amelio", fit = opts.fit ~= false or nil }
  -- une autre prise, après la taille du kit, réserve une partie du fer
  if (opts.stolen or 0) > 0 then
    R.open(reg, 99999, 50, tick)
    R.request(reg, 99999, { { PLATE, opts.stolen } }, tick)
  end
  Board.add(f, { kit }, tick)
  local agent
  for _, id in ipairs(State.sorted_keys(f.engineers)) do
    local a = Registry.get(id)
    if a and a.entity and a.entity.valid then
      if a.task then Board.release(f, a) end
      a.task, a.bg = nil, nil
      agent = a
      break
    end
  end
  return { f = f, Board = Board, R = R, reg = reg, kit = kit, m = m, agent = agent, tick = tick, book = book }
end

---------------------------------------------------------------------------------------------------
section("1. Kit taillé sur tout le fer libre, une plaque réservée ensuite par une autre prise : le kit est pris, ajusté")
---------------------------------------------------------------------------------------------------
local s = scene({ stolen = 1 })
check(s.book ~= nil, "livre de la force posé sur le tableau (Board.book_of, script/team/team.lua)")
check(s.m == 200, "kit taillé sur les 400 plaques libres : 200 engrenages (" .. tostring(s.m) .. ")")
check(s.R.free(s.reg, PLATE) == 399, "399 plaques libres à la prise (" .. s.R.free(s.reg, PLATE) .. ")")
check(s.agent ~= nil, "un PNJ libre")
local got = s.Board.claim(s.f, s.agent, s.tick + 1)
check(got == s.kit, "le kit est pris par le PNJ libre (" .. tostring(got and got.key) .. ")")
check(s.kit.count == 199, "kit ajusté à la prise : 199 engrenages (" .. tostring(s.kit.count) .. ")")
local need = 0
for _, it in ipairs(s.kit.uses) do if it[1] == PLATE then need = it[2] end end
check(need == 398 and need <= 399, "matière du kit ajusté dans le libre : 398 plaques (" .. need .. ")")
local p = s.reg.projects[s.agent.resa_id or -1]
check(p ~= nil and (p.resa[PLATE] or 0) == 398, "la matière du kit ajusté est réservée pour le PNJ")
check(s.kit.steps and s.kit.steps[1] and s.kit.steps[1].runs == 199, "fabrications du kit replanifiées (199)")

---------------------------------------------------------------------------------------------------
section("2. Mutants : l'ancien kit (sans « fit ») et le tableau sans livre ne sont pas pris")
---------------------------------------------------------------------------------------------------
local s2 = scene({ stolen = 1, fit = false })
local got2 = s2.Board.claim(s2.f, s2.agent, s2.tick + 1)
check(got2 == nil and s2.kit.count == 200, "kit sans « fit » (ancien code) : refusé, 200 inchangé (" .. tostring(got2 and got2.key) .. ")")
local s3 = scene({ stolen = 1 })
local keep = s3.Board.book_of
s3.Board.book_of = nil
local got3 = s3.Board.claim(s3.f, s3.agent, s3.tick + 1)
s3.Board.book_of = keep
check(got3 == nil, "tableau sans livre : kit non pris (" .. tostring(got3 and got3.key) .. ")")

---------------------------------------------------------------------------------------------------
section("3. Bornes : rien de libre, rien de pris ; assez de matière, kit entier ; une replanification par tick")
---------------------------------------------------------------------------------------------------
local s4 = scene({ stolen = 399 })
local calls, book_of = 0, s4.Board.book_of
s4.Board.book_of = function(ff) calls = calls + 1 return book_of(ff) end
local got4 = s4.Board.claim(s4.f, s4.agent, s4.tick + 1)
check(got4 == nil and s4.kit.count == 200, "une seule plaque libre : aucun engrenage faisable, kit non pris et inchangé")
check(s4.kit.fit_at == s4.tick + 1 and calls == 1, "replanification notée au tick de la prise")
local got4b = s4.Board.claim(s4.f, s4.agent, s4.tick + 1)
check(got4b == nil and calls == 1, "même tick : pas de seconde replanification (" .. calls .. ")")
s4.R.release(s4.reg, 99999)
local got4c = s4.Board.claim(s4.f, s4.agent, s4.tick + 2)
s4.Board.book_of = book_of
check(got4c == s4.kit and s4.kit.count == 200 and calls == 1, "le fer rendu : kit pris entier, sans replanification (" .. tostring(s4.kit.count) .. ")")
local s5 = scene({ want = 40, stolen = 1 })
local got5 = s5.Board.claim(s5.f, s5.agent, s5.tick + 1)
check(got5 == s5.kit and s5.kit.count == 40 and s5.kit.fit_at == nil, "kit de 40 dans 399 libres : pris tel quel, sans replanification")

---------------------------------------------------------------------------------------------------
section("4. Lot n102-verrou : pensée sous la retenue d'énergie (capital_continu sauté) : le kit PRIS survit à Board.sync, le libre sort")
---------------------------------------------------------------------------------------------------
-- script/team/team.lua E6 : sous C.survie (centrale saturée ou chaudières à sec) le kit n'est pas réémis ; Board.sync (E1c de la pensée
-- suivante) ne doit jeter que la tâche LIBRE (voulu : aucune plaque dans une amélioration pendant la retenue, ordre du DC du 15/11).
-- Mutant (refusé) : Board.sync sans la garde `t.worker` jette aussi le kit pris (fabrication en cours perdue, matière réservée orpheline).
local s6 = scene({ want = 40 })
local got6 = s6.Board.claim(s6.f, s6.agent, s6.tick + 1)
check(got6 == s6.kit and s6.kit.worker == s6.agent.id, "kit de 40 pris par le PNJ avant la retenue")
s6.Board.sync(s6.f, {}, s6.tick + 2) -- pensée retenue : rien de planifié, continu sauté
local b6 = s6.Board.get(s6.f)
check(b6.tasks[s6.kit.key] == s6.kit and s6.kit.worker == s6.agent.id, "kit pris gardé par Board.sync sous la retenue (" ..
  tostring(b6.tasks[s6.kit.key] and b6.tasks[s6.kit.key].worker) .. ")")
s6.Board.sync(s6.f, {}, s6.tick + 3)
check(s6.Board.get(s6.f).tasks[s6.kit.key] == s6.kit, "toujours gardé à la deuxième pensée retenue")
local s7 = scene({ want = 40 })
local born7 = s7.Board.get(s7.f).tasks[s7.kit.key].created
s7.Board.sync(s7.f, {}, s7.tick + 2)
local b7 = s7.Board.get(s7.f)
check(b7.tasks[s7.kit.key] == nil, "kit LIBRE retiré sous la retenue (voulu : la matière reste à l'énergie)")
check(b7.born[s7.kit.key] == born7, "sa date de naissance est gardée pour un retour à la pensée qui suit (" .. tostring(b7.born[s7.kit.key]) .. ")")

print(string.format("kit_ramassage_test : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
