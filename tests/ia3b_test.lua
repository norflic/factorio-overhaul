--[[
  Lot IA3-b « personne n'attend, personne n'arrache » : tests hors jeu (règles pures et moteur simulé).
  docs/IA3_CERVEAU.md §2.2, §2.3 ; réglage fo-war-ia3-marche (settings/ia3b.lua).

  Ce qu'il prouve :
    1. place de marché (M.order) : cerveau avant fond, note, besoin des tâches d'extraction (constat du DC, 18 h 45 :
       surplus « vaut peu », ce qui manque vaut plus), anti-ruée et garde du QG menacé exemptée, rôle qui oriente ;
    2. registre : R.set_count rogne les réservations les moins prioritaires et le dit ; R.preemptable = R.preempt ;
    3. manque de plaques (X.tasks) sur le cas du DC (18 h 40 : « il manque 62 plaques de fer », aucun four) : fours
       fabriqués puis posés, plusieurs mineurs de fer, rien sans manque, rien de plus quand assez de mineurs ;
    4. moteur simulé, votre équipe dans le cas du DC, réglage ÉTEINT puis ALLUMÉ : fours posés, plusieurs PNJ minent le
       fer, 0 échec « stock », registre jamais au-delà du coffre (R.check à chaque minute), global sérialisable ;
    5. réglage éteint : aucune réservation, aucun indice, comportement d'avant (pas de champ du lot dans le tableau).
  Usage : lua5.2 tests/ia3b_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[IA3-B] ECHEC : " .. msg) end
end

local Mk = require("shared.ai3.marche")
local R = require("shared.ai3.registre")
local X = require("shared.ai3.manque")
local T = require("shared.team.config")

-- 1. Place de marché.
do
  local npc = { id = 1, role = "executant", pole = "base", pos = { x = 0, y = 0 } }
  local tasks = {
    { key = "a", kind = "craft", prio = 50, pole = "base" },
    { key = "b", kind = "mine", prio = 45, pole = "extraction", resource = "iron-ore" },
    { key = "c", kind = "mine", prio = 60, pole = "extraction", resource = "stone", fond = true },
    { key = "d", kind = "service", prio = 70, pole = "extraction", worker = 9 },
  }
  local idx = Mk.order(npc, tasks, {})
  check(#idx == 3 and tasks[idx[1]].key == "a" and tasks[idx[3]].key == "c",
    "cerveau avant fond, tâche prise ignorée, pôle +20 % (craft 60 contre mine 45)")
  local mult = { ["iron-ore"] = Mk.NEED_SHORT, stone = Mk.NEED_SURPLUS }
  idx = Mk.order(npc, tasks, { mult_of = function(t) return t.kind == "mine" and mult[t.resource] or 1 end })
  check(tasks[idx[1]].key == "b", "le fer qui manque (45 x 1,5 = 67,5) passe devant la fabrication (60)")
  check(Mk.need_factor(500, 400, false) == Mk.NEED_SURPLUS and Mk.need_factor(10, 400, false) == 1
    and Mk.need_factor(500, 400, true) == Mk.NEED_SHORT, "besoin : surplus 0,25, normal 1, manque 1,5")
  -- Anti-ruée : 2 ravitaillements urgents déjà pris, le 3e vaut 95 x 0,49 = 46,6 < fabrication 50 (hors pôle).
  local exec = { id = 2, role = "executant", pole = "territoire", pos = { x = 0, y = 0 } }
  local t2 = { { key = "s", kind = "service", prio = 95 }, { key = "k", kind = "craft", prio = 50 } }
  idx = Mk.order(exec, t2, { rush = { service = 2 } })
  check(t2[idx[1]].key == "k", "anti-ruée : la 3e urgence d'un genre passe après une tâche ordinaire")
  local g = { { key = "garde:qg:1", kind = "garrison", prio = 96, post = "hq", no_rush = true }, { key = "k", kind = "craft", prio = 50 } }
  idx = Mk.order(exec, g, { rush = { garrison = 5 } })
  check(g[idx[1]].key == "garde:qg:1", "garde du QG menacé : pas d'anti-ruée (toute l'équipe y va)")
  local design = { { key = "x", kind = "plan_module", prio = 80, design = true } }
  idx = Mk.order({ id = 3, role = "executant", cannot = { plan_module = true } }, design, {})
  check(#idx == 0, "un exécutant ne prend pas une tâche de conception")
  -- Ordre total : mêmes notes, ordre des clés ; entrée inversée, même ordre.
  local same = {}
  for i = 1, 20 do same[i] = { key = string.format("k%02d", 21 - i), kind = "craft", prio = 50 } end
  local o1 = Mk.order(npc, same, {})
  local ok = true
  for i = 2, #o1 do if same[o1[i - 1]].key > same[o1[i]].key then ok = false end end
  check(ok, "à note égale, ordre des clés (tri total)")
end

-- 2. Registre.
do
  local reg = R.new()
  R.set_stock(reg, { ["iron-plate"] = 100 }, 0)
  R.open(reg, 1, 80, 0); R.request(reg, 1, { { "iron-plate", 60 } }, 0)
  R.open(reg, 2, 40, 0); R.request(reg, 2, { { "iron-plate", 40 } }, 0)
  local cuts = R.set_count(reg, "iron-plate", 70, 0)
  check(#cuts == 1 and cuts[1][1] == 2 and cuts[1][3] == 30 and reg.projects[2].resa["iron-plate"] == 10,
    "set_count : 30 plaques disparues rognées sur le projet le moins prioritaire, et dites")
  check(R.check(reg), "set_count : invariants")
  R.open(reg, 3, 95, 0)
  local can = R.preemptable(reg, 3, "iron-plate", 0)
  local got = R.preempt(reg, 3, "iron-plate", 100, 0)
  check(can == got and got == 70, "preemptable = preempt (écarts 15 et 55, rien d'engagé : tout)")
  reg.projects[1].engaged = true
  check(R.preemptable(reg, 2, "iron-plate", 0) == 0, "jamais un projet plus prioritaire")
end

-- 3. Manque de plaques, cas du DC (règle pure).
do
  local Book = require("shared.team.book")
  local book = Book.new({
    ["stone-furnace"] = { name = "stone-furnace", category = "crafting", energy = 0.5,
      ingredients = { { type = "item", name = "stone", amount = 5 } },
      products = { { type = "item", name = "stone-furnace", amount = 1 } } },
  })
  local view = { smelters = 0, smelters_pending = 0, stock = { ["iron-plate"] = 6, coal = 30, stone = 60 }, outposts = {}, workers = 8 }
  local missing = { ["iron-plate"] = 62 }
  local function miners_of(list)
    local n = 0
    for _, t in ipairs(list) do if t.kind == "mine" and t.resource == "iron-ore" then n = n + 1 end end
    return n
  end
  local out = X.tasks(view, missing, { keys = {}, mines = {}, book = book })
  check(#out == 5 and out[1].kind == "craft" and out[1].item == "stone-furnace" and out[1].count == X.SMELTERS_MAX,
    "cas du DC : 4 fours fabriqués (pierre ; manque >= 50) et 4 mineurs de fer", #out .. " tâches")
  check(miners_of(out) == 4 and out[2].count == X.MINE_MIN, "4 mineurs de fer (62 / 20), 25 minerais au moins chacun")
  view.workers_idle = 6
  check(miners_of(X.tasks(view, missing, { keys = {}, mines = {}, book = book })) == 6,
    "6 PNJ inactifs : 6 mineurs (au plus X.MINERS_MAX), aucun n'attend")
  view.workers_idle = 0
  check(miners_of(X.tasks(view, missing, { keys = {}, mines = { ["iron-ore"] = 4 }, mines_taken = { ["iron-ore"] = 4 },
    book = book })) == 1, "4 mineurs au travail : une tâche d'avance (le mineur qui revient repart tout de suite)")
  view.stock["stone-furnace"] = 2
  out = X.tasks(view, missing, { keys = {}, mines = {}, book = book })
  check(out[1].kind == "smelters" and out[1].items[1][2] == 2 and out[1].items[2][2] == T.fuel_per_burner * 2
    and out[2].kind == "craft" and out[2].count == 2,
    "2 fours au coffre : posés au QG avec leur charbon, 2 autres fabriqués en parallèle")
  out = X.tasks(view, missing, { keys = {}, mines = { ["iron-ore"] = 4 }, book = book })
  check(miners_of(out) == 0, "assez de mineurs au tableau : aucun de plus")
  view.outposts = { { kind = "iron" } }
  view.smelters = 2
  out = X.tasks(view, missing, { keys = {}, mines = {}, book = book })
  check(#out == 0, "un avant-poste de fer existe : on attend sa tournée (règle du planificateur)")
  out = X.tasks({ smelters = 2, stock = {}, outposts = {}, workers = 8 }, {}, {})
  check(#out == 0, "aucun manque : rien")
  local need = X.need({ stock = { coal = 900, stone = 500, ["iron-ore"] = 0 } }, missing)
  check(need.coal == Mk.NEED_SURPLUS and need.stone == Mk.NEED_SURPLUS and need["iron-ore"] == Mk.NEED_SHORT
    and need["iron-plate"] == Mk.NEED_SHORT, "besoin : charbon et pierre en surplus (0,25), minerai et plaque de fer en manque (1,5)")
  need = X.need({ stock = { ["iron-ore"] = 100 } }, missing)
  check(need["iron-ore"] == 1 and need["iron-plate"] == Mk.NEED_SHORT,
    "minerai au coffre qui couvre le manque : la fonte passe devant le minage")
  check(miners_of(X.tasks({ smelters = 2, stock = { ["iron-ore"] = 100 }, outposts = {}, workers = 8, workers_idle = 4 },
    missing, { keys = {}, mines = {}, book = book })) == 0, "minerai au coffre qui couvre le manque : aucun mineur de plus")
end

-- 4 et 5. Moteur simulé : votre équipe dans le cas du DC.
local Mo = require("tests.mock_engine")
local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

local function run_case(on)
  Mo.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
  Mo.world().settings[Mk.SETTING] = on
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 6 }, { "coal", 30 }, { "stone", 60 } }) do chest.insert({ name = it[1], count = it[2] }) end
  Mo.world().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  local f = global.fo.pteam.team
  local res = { max_iron_miners = 0, reg_ok = true, idle_short = 0, samples_short = 0, ok = true }
  local Registry = require("script.companion.registry")
  for minute = 1, 12 do
    local ok, err = pcall(Mo.run_ticks, 3600)
    if not ok then res.ok = false; res.err = tostring(err); break end
    f = global.fo.pteam.team
    local miners, idle = 0, 0
    for id in pairs(f.engineers) do
      local a = Registry.get(id)
      if a and a.task and a.task.kind == "mine" and a.task.resource == "iron-ore" then miners = miners + 1 end
      if a and not a.task then idle = idle + 1 end
    end
    if miners > res.max_iron_miners then res.max_iron_miners = miners end
    if f.team.reg then
      local okr, msg = R.check(f.team.reg)
      if not okr then res.reg_ok = false; res.reg_msg = msg end
    end
  end
  res.f = f
  res.stock_fail = (f.team.fail_reasons or {}).stock or 0
  res.smelters = #(f.smelters or {})
  res.ser = pcall(Mo.serialize, global)
  res.reg = f.team.reg
  res.marche = f.team.marche
  res.hint = f.team.board and f.team.board.hint
  return res
end

local off = run_case(false)
check(off.ok, "réglage éteint : simulation sans erreur (" .. tostring(off.err) .. ")")
check(off.marche == false and off.reg == nil and off.hint == nil, "réglage éteint : ni registre ni indice")
local on = run_case(true)
check(on.ok, "réglage allumé : simulation sans erreur (" .. tostring(on.err) .. ")")
check(on.marche == true, "réglage allumé : figé dans l'équipe")
check(on.smelters >= 1, "cas du DC : fours posés au QG (" .. on.smelters .. ") ; éteint : " .. off.smelters)
check(on.max_iron_miners >= 2, "cas du DC : plusieurs PNJ minent le fer (au plus " .. on.max_iron_miners
  .. " à la fois ; éteint : " .. off.max_iron_miners .. ")")
check(on.stock_fail == 0, "0 échec « stock » (éteint : " .. off.stock_fail .. ")")
check(on.reg_ok, "registre jamais au-delà du coffre (R.check chaque minute) " .. tostring(on.reg_msg))
check(on.ser, "global sérialisable (registre, indices)")
print(string.format("[IA3-B] moteur simulé, cas du DC, 12 min : fours %d / %d, mineurs de fer au plus %d / %d, échecs stock %d / %d (éteint / allumé)",
  off.smelters, on.smelters, off.max_iron_miners, on.max_iron_miners, off.stock_fail, on.stock_fail))

print(string.format("[IA3-B] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
