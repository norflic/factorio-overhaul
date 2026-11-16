--[[
  Lot n103-churn (B2 : deux prises comptent la même matière libre ; même règle que n101-ramassage, étendue aux kits de PROJET).
  Partie du DC en 0.9.10 (journal vivant, player, projet 79 'auto:migration-2', kits des tapis d'une bande de champ) : le kit est
  taillé à chaque pensée (shared/ai3/projets.lua, P.want_kit, Kit.build) sur TOUT le stock virtuel de fer (libre au registre + en route :
  plaques des sorties que les tournées rapporteront, view.incoming), car le manque (transport-belt 652) le dépasse de loin ; sa prise
  stricte (script/team/board.lua, claim_market) le voulait entier sur le libre du coffre : non prenable, retaillé à la pensée suivante
  (EMIS x8, x12, x16, x52, x30, x30, x48, x50, x58, x62, x66, x76, x74, x78, x82 de 29,1 à 30,3 min ; 12 PNJ libres, « manque
  transport-belt 652 » à 30,0 min ; 97 LIVRE pour 242 EMIS). Règle : le kit de projet est marqué `fit` ; à la prise, ses pièces sont
  replanifiées ensemble sur le libre (Kit.build, un seul kit), t.kit réécrit.
  Valeurs du journal rejouées : x82 tapis = 123 plaques au stock virtuel, 16 plaques libres au coffre ; kit « inserter x7,
  transport-belt x16 » (29,0 min).
  Mutants : le kit sans `fit` (ancien P.want_kit) n'est pas pris ; sans la branche des pièces (ancien refit, un seul objet), t.kit reste
  à x82 (Board.incoming compterait 82 tapis en route pour 10 fabriqués).
  Lancement : lua5.2 tests/kit_projet_ajuste_test.lua (racine du mod, quelques secondes).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local M = require("tests.mock_engine")
-- données du test (la règle n'en nomme aucun)
local BELT, ARM, PLATE, COPPER = "transport-belt", "inserter", "iron-plate", "copper-plate"

local function new_team(seed, chest_items)
  M.new_game({ patches = { { x = 60, y = 0, name = "iron-ore" } }, p_busy = 0.01, p_nopath = 0.01, p_lost = 0, seed = seed })
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs(chest_items) do chest.insert({ name = it[1], count = it[2] }) end
  M.world().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  M.run_ticks(120)
  return global.fo.pteam.team
end

--- Monde du symptôme : coffre `chest`, stock virtuel de la pensée = libre + `incoming` ; le kit du projet est émis par P.want_kit sur ce
--- stock virtuel pour le besoin `want` ; `stolen` plaques réservées ensuite par une autre prise. Rend le monde et le kit émis.
local function scene(opts)
  local f = new_team(17, opts.chest)
  local Board = require("script.team.board")
  local Registry = require("script.companion.registry")
  local Stock = require("script.team.stock")
  local State = require("script.faction.state")
  local R = require("shared.ai3.registre")
  local P = require("shared.ai3.projets")
  local tick = game.tick
  local b = Board.get(f)
  b.tasks, b.cooldown, b.hint, b.hinted, b.born, b.hold_left = {}, {}, nil, nil, nil, nil
  local reg = f.team.reg or R.new()
  f.team.reg = reg
  for _, id in ipairs(State.sorted_keys(reg.projects)) do R.release(reg, id) end
  local free = Board.view_stock(f, Stock.contents(f), tick, true)
  local book = Board.book_of and Board.book_of(f)
  local avail = {}
  for _, k in ipairs(State.sorted_keys(free)) do avail[k] = math.min(free[k], math.max(0, R.free(reg, k))) end
  for _, it in ipairs(opts.incoming or {}) do avail[it[1]] = (avail[it[1]] or 0) + it[2] end
  local E = P.context(avail, book, { open = {} }, {})
  E.tick = tick
  local proj = { id = 79, key = "auto:migration-2", goal = { pids = { 10 } } }
  P.want_kit(E, proj, opts.want, 50, "module")
  local kit = E.tasks[1]
  if kit and opts.fit == false then kit.fit = nil end
  if (opts.stolen or 0) > 0 then
    R.open(reg, 99999, 50, tick)
    R.request(reg, 99999, { { PLATE, opts.stolen } }, tick)
  end
  if kit then Board.add(f, { kit }, tick) end
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
  return { f = f, Board = Board, R = R, reg = reg, kit = kit, agent = agent, tick = tick, book = book, n_tasks = #E.tasks }
end

local function use_of(t, item)
  for _, it in ipairs(t.uses or {}) do if it[1] == item then return it[2] end end
  return 0
end
local function piece(t, item)
  for _, w in ipairs(t.kit or {}) do if w[1] == item then return w[2] end end
  return 0
end

---------------------------------------------------------------------------------------------------
section("1. Journal 30,3 min : kit des tapis x82 taillé sur 123 plaques (16 au coffre, 107 en route) : pris, ajusté à 10")
---------------------------------------------------------------------------------------------------
local s = scene({ chest = { { PLATE, 16 } }, incoming = { { PLATE, 107 } }, want = { { BELT, 652 } } })
check(s.book ~= nil, "livre de la force posé sur le tableau (Board.book_of)")
check(s.kit ~= nil and s.n_tasks == 1 and piece(s.kit, BELT) == 82, "P.want_kit : un kit de 82 tapis (" .. tostring(s.kit and piece(s.kit, BELT)) .. ")")
check(s.kit and use_of(s.kit, PLATE) == 123, "matière du kit à la pensée : 123 plaques (" .. tostring(s.kit and use_of(s.kit, PLATE)) .. ")")
check(s.kit and s.kit.fit == true, "kit de projet marqué « fit »")
check(s.R.free(s.reg, PLATE) == 16, "16 plaques libres au registre à la prise (" .. s.R.free(s.reg, PLATE) .. ")")
local got = s.Board.claim(s.f, s.agent, s.tick + 1)
check(got == s.kit, "le kit est pris par le PNJ libre (" .. tostring(got and got.key) .. ")")
check(piece(s.kit, BELT) == 10 and #s.kit.kit == 1, "pièces du kit réécrites : 10 tapis (" .. piece(s.kit, BELT) .. ")")
check(s.kit.item == BELT and s.kit.count == 10, "tête du kit réécrite : transport-belt x10")
check(use_of(s.kit, PLATE) == 15, "matière du kit ajusté : 15 plaques dans les 16 libres (" .. use_of(s.kit, PLATE) .. ")")
local p = s.reg.projects[s.agent.resa_id or -1]
check(p ~= nil and (p.resa[PLATE] or 0) == 15, "les 15 plaques sont réservées pour le PNJ")
local runs = 0
for _, c in ipairs(s.kit.steps or {}) do if c.recipe == BELT then runs = runs + c.runs end end
check(runs == 5, "fabrications replanifiées : 5 fois la recette des tapis (" .. runs .. ")")
check(s.kit.pids and s.kit.pids[1] == 10, "destinataires du kit gardés (pids)")
local inc = s.Board.incoming(s.f)
check((inc[BELT] or 0) == 10, "Board.incoming compte les 10 tapis du kit ajusté, pas 82 (" .. tostring(inc[BELT]) .. ")")

---------------------------------------------------------------------------------------------------
section("2. Même kit, fer pris par une autre prise entre la pensée et la prise (123 au coffre, 107 réservées) : pris, ajusté")
---------------------------------------------------------------------------------------------------
local s2 = scene({ chest = { { PLATE, 123 } }, want = { { BELT, 652 } }, stolen = 107 })
check(s2.kit and piece(s2.kit, BELT) == 82, "kit de 82 tapis à la pensée")
local got2 = s2.Board.claim(s2.f, s2.agent, s2.tick + 1)
check(got2 == s2.kit and piece(s2.kit, BELT) == 10 and use_of(s2.kit, PLATE) == 15, "pris, 10 tapis sur 15 plaques")

---------------------------------------------------------------------------------------------------
section("3. Journal 29,0 min : kit « inserter x7, transport-belt x16 » (52 plaques), 30 plaques libres : pièces ajustées ensemble")
---------------------------------------------------------------------------------------------------
local s3 = scene({ chest = { { PLATE, 52 }, { COPPER, 200 } }, want = { { ARM, 7 }, { BELT, 16 } }, stolen = 22 })
check(s3.kit and piece(s3.kit, ARM) == 7 and piece(s3.kit, BELT) == 16, "kit inserter x7, transport-belt x16 à la pensée")
check(s3.kit and use_of(s3.kit, PLATE) == 52, "52 plaques à la pensée (" .. tostring(s3.kit and use_of(s3.kit, PLATE)) .. ")")
local got3 = s3.Board.claim(s3.f, s3.agent, s3.tick + 1)
check(got3 == s3.kit, "kit à deux pièces pris (" .. tostring(got3 and got3.key) .. ")")
check(use_of(s3.kit, PLATE) <= 30 and use_of(s3.kit, PLATE) > 0, "fer du kit ajusté dans les 30 libres (" .. use_of(s3.kit, PLATE) .. ")")
check(piece(s3.kit, ARM) == 7 and piece(s3.kit, BELT) == 0, "ordre des pièces gardé : 7 bras (28 plaques), plus de tapis")
check(use_of(s3.kit, COPPER) > 0 and use_of(s3.kit, COPPER) <= 200, "cuivre des circuits replanifié")

---------------------------------------------------------------------------------------------------
section("4. Mutant (ancien P.want_kit, sans « fit ») et bornes")
---------------------------------------------------------------------------------------------------
local s4 = scene({ chest = { { PLATE, 16 } }, incoming = { { PLATE, 107 } }, want = { { BELT, 652 } }, fit = false })
local got4 = s4.Board.claim(s4.f, s4.agent, s4.tick + 1)
check(got4 == nil and piece(s4.kit, BELT) == 82, "kit sans « fit » : non pris, 82 inchangé (" .. tostring(got4 and got4.key) .. ")")
local s5 = scene({ chest = { { PLATE, 2 } }, incoming = { { PLATE, 121 } }, want = { { BELT, 652 } } })
local got5 = s5.Board.claim(s5.f, s5.agent, s5.tick + 1)
check(got5 == nil and piece(s5.kit, BELT) == 82, "2 plaques libres : aucun tapis faisable, kit non pris et inchangé")
local s6 = scene({ chest = { { PLATE, 200 } }, want = { { BELT, 40 } } })
local got6 = s6.Board.claim(s6.f, s6.agent, s6.tick + 1)
check(got6 == s6.kit and piece(s6.kit, BELT) == 40 and s6.kit.fit_at == nil, "kit couvert par le libre : pris tel quel, sans replanification")

print(string.format("kit_projet_ajuste_test : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
