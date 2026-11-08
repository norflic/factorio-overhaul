--[[
  Lot ÉTALEMENT (5/11) : pensées des factions ESPACÉES sur la période (script/faction/commander.lua, Commander.spread ;
  script/core/scheduler.lua, Scheduler.add_at). Avant : 4 ticks consécutifs (phases 0 à 3 modulo 300), un bloc de 0,22 à 0,5 s
  toutes les 300 ticks chez le DC (mesure de perf3) ; après : phases 7, 82, 157 et 232.
    1. Scheduler.add_at : place, déplacement, jamais deux passages dans un tick, période exacte après le déplacement, retrait ;
       mutants.
    2. Commander.slot_for : phases distinctes, espacées de P / n, hors des multiples de 5, des restes 0 à 3 de 30, loin de 174
       (votre équipe), pour n = 2 à F.MAX_FACTIONS.
    3. Partie au moteur simulé (4 factions) : chaque faction pense une fois par période, à sa phase, jamais deux le même tick.
    4. Migration d'une partie d'avant (factions à la suite) : replacées au changement de configuration, journal [FO-ETALEMENT] ;
       pendant le passage, jamais deux pensées d'une faction dans un tick, aucun écart au-delà de 2 périodes ; puis période exacte.
       Les §3 et §4 se jouent avec la cadence des factions ÉTEINTE (Commander.CADENCE = false, lot X10-S10) : ils testent
       l'étalement des créneaux, et leurs factions, loin du joueur et calmes, penseraient sinon une fois sur deux (décision du lead,
       8/11 : attendus inchangés, 300 et phases 7, 82, 157, 232).
    5. Cadence ALLUMÉE (lot X10-S10), même monde : les factions lointaines et calmes pensent toutes les 600 ticks exactement, chacune
       dans sa voie (même phase modulo 300, jamais deux au même tick) ; une faction réveillée (joueur proche, coup reçu sur une
       tourelle) repasse à 300 dès la pensée de réveil, dans sa voie. Mutants : une faction endormie dont la voie glisse (créneau
       reposé un tick plus tôt à chaque sommeil), une voie déplacée au réveil.
  Lancement : lua5.2 tests/etalement_phases_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local M = require("tests.mock_engine")
M.new_game({ patches = {}, p_busy = 0, p_nopath = 0, p_lost = 0 })
local W = M.world()
local Scheduler = require("script.core.scheduler")
local Commander = require("script.faction.commander")
local State = require("script.faction.state")
local F = require("shared.faction.config")

---------------------------------------------------------------------------------------------------
section("1. Scheduler.add_at : place, déplacement, période exacte")
---------------------------------------------------------------------------------------------------
do
  local P = 10
  local passes_of = {}
  local lane = "t-etalement"
  Scheduler.define_lane(lane, P, function(id, tick)
    passes_of[id] = passes_of[id] or {}
    local l = passes_of[id]
    l[#l + 1] = tick
  end)
  for id = 1, 4 do Scheduler.add(lane, id) end
  check(Scheduler.slot(lane, 1) == 1 and Scheduler.slot(lane, 4) == 4, "ajout tournant : créneaux 1 à 4")
  check(Scheduler.period(lane) == P, "Scheduler.period")
  M.run_ticks(23) -- au milieu d'un cycle
  local t_move = game.tick
  Scheduler.add_at(lane, 2, 8)
  Scheduler.add_at(lane, 3, 3) -- déjà à sa place : sans effet
  Scheduler.add_at(lane, 4, 14) -- ramené dans la période : 4
  Scheduler.add_at(lane, 9, 6) -- absent : ajouté
  check(Scheduler.count(lane) == 5, "compte : 4 + 1 ajouté par add_at (" .. Scheduler.count(lane) .. ")")
  check(Scheduler.slot(lane, 2) == 8 and Scheduler.slot(lane, 4) == 4 and Scheduler.slot(lane, 9) == 6, "créneaux après add_at")
  M.run_ticks(60)
  local ok_tick, ok_period, ok_phase = true, true, true
  for _, id in ipairs({ 1, 2, 3, 4, 9 }) do
    local l = passes_of[id] or {}
    local after = {}
    for _, t in ipairs(l) do if t > t_move then after[#after + 1] = t end end
    for k = 2, #after do
      if after[k] == after[k - 1] then ok_tick = false end
      if k >= 3 and after[k] - after[k - 1] ~= P then ok_period = false end
    end
    local s = Scheduler.slot(lane, id)
    for _, t in ipairs(after) do if (t % P) + 1 ~= s then ok_phase = false end end
    check(#after >= 5, "id " .. id .. " passe après le déplacement (" .. #after .. " fois)")
  end
  check(ok_tick, "jamais deux passages d'un id dans un tick")
  check(ok_period, "période exacte après le premier passage qui suit le déplacement")
  check(ok_phase, "chaque passage au créneau de l'id")
  Scheduler.remove(lane, 2)
  local n2 = #(passes_of[2] or {})
  M.run_ticks(20)
  check(#passes_of[2] == n2, "retrait après add_at : plus de passage")
  -- déplacé puis ramené (entrée périmée et entrée neuve dans le même seau) : un seul passage par tick
  Scheduler.add_at(lane, 1, 5)
  Scheduler.add_at(lane, 1, 1)
  local before = #passes_of[1]
  M.run_ticks(30)
  local l = passes_of[1]
  local dup = false
  for k = before + 2, #l do if l[k] == l[k - 1] then dup = true end end
  check(not dup and #l - before == 3, "aller-retour dans un seau : un passage par période (" .. (#l - before) .. " en 30 ticks)")
end

---------------------------------------------------------------------------------------------------
section("2. Commander.slot_for : phases espacées, hors des rythmes des autres passes")
---------------------------------------------------------------------------------------------------
do
  local P = F.defaults.think_period
  check(P == 300, "période des pensées de faction : 300")
  local ok = true
  for n = 2, F.MAX_FACTIONS do
    local seen, phases = {}, {}
    for i = 1, n do
      local ph = Commander.slot_for(i, n, P) - 1
      phases[#phases + 1] = ph
      if seen[ph] then ok = false print("  phase en double, n = " .. n) end
      seen[ph] = true
      if ph % 5 == 0 then ok = false print("  multiple de 5 : " .. ph) end
      if ph % 30 <= 3 then ok = false print("  reste 0 à 3 de 30 : " .. ph) end
      if math.abs(ph - 174) < 10 then ok = false print("  trop près de 174 : " .. ph) end
    end
    table.sort(phases)
    for k = 2, #phases do
      local gap = phases[k] - phases[k - 1]
      if math.abs(gap - P / n) > 1 then ok = false print(string.format("  écart %d (n = %d)", gap, n)) end
    end
    if n == 4 then check(table.concat(phases, ",") == "7,82,157,232", "4 factions : phases 7, 82, 157, 232 (" .. table.concat(phases, ",") .. ")") end
  end
  check(ok, "phases distinctes, espacées de P / n, hors des multiples de 5 et des restes 0 à 3 de 30, à 10 ticks au moins de 174")
  -- mutant : sans PHASE0, les phases tombent sur des multiples de 5 (passes du plan directeur)
  local save = Commander.PHASE0
  Commander.PHASE0 = 0
  check(Commander.slot_for(1, 4, 300) - 1 == 0, "mutant PHASE0 = 0 : phase 0, refusé par la règle des multiples de 5")
  Commander.PHASE0 = save
end

---------------------------------------------------------------------------------------------------
section("3. Partie à 4 factions : une pensée par faction et par période, à sa phase, jamais deux au même tick")
---------------------------------------------------------------------------------------------------
-- Lot X10-S10 (décision du lead, 8/11) : les §3 et §4 testent l'ÉTALEMENT des créneaux (une pensée par période, à sa phase). La cadence
-- des factions lointaines et calmes (shared/faction/cadence.lua) y ferait penser chaque faction une fois sur deux : elle est éteinte ici,
-- et rallumée au §5, qui la teste sur le même monde.
Commander.CADENCE = false
local function watch(ticks)
  local war = State.war()
  local by = {}
  local same_tick = 0
  for _ = 1, ticks do
    M.run_ticks(1)
    local t = game.tick
    local n = 0
    for i, f in ipairs(war.factions) do
      if f.last_think == t then
        n = n + 1
        by[i] = by[i] or {}
        by[i][#by[i] + 1] = t
      end
    end
    if n > 1 then same_tick = same_tick + 1 end
  end
  return by, same_tick
end
assert(remote.call("factorio-overhaul", "war_start", 4, 100, nil, 320) == true)
remote.call("factorio-overhaul", "war_fund", 1000)
do
  local war = State.war()
  check(#war.factions == 4, "4 factions")
  for i = 1, 4 do
    check(Scheduler.slot(Commander.LANE, i) == Commander.slot_for(i, 4, 300), "faction " .. i .. " à son créneau dès le lancement")
  end
  local by, same = watch(3000)
  check(same == 0, "jamais deux pensées de faction au même tick (" .. same .. ")")
  for i = 1, 4 do
    local l = by[i] or {}
    local ok = #l >= 9
    for k = 2, #l do if l[k] - l[k - 1] ~= 300 then ok = false end end
    for _, t in ipairs(l) do if t % 300 ~= Commander.slot_for(i, 4, 300) - 1 then ok = false end end
    check(ok, string.format("faction %d : %d pensées, toutes les 300 ticks, à la phase %d", i, #l, Commander.slot_for(i, 4, 300) - 1))
  end
end

---------------------------------------------------------------------------------------------------
section("4. Migration d'une partie d'avant : factions à la suite, replacées au changement de configuration")
---------------------------------------------------------------------------------------------------
do
  local war = State.war()
  -- état d'une sauvegarde 0.6.53 : créneaux consécutifs (ajout tournant)
  for i = 1, 4 do Scheduler.add_at(Commander.LANE, i, ((game.tick + 40 + i) % 300) + 1) end
  local by0, same0 = watch(600)
  check(same0 == 0, "avant migration, une pensée par tick")
  local old_ph = {}
  for i = 1, 4 do old_ph[i] = (Scheduler.slot(Commander.LANE, i) - 1) end
  check(old_ph[2] == old_ph[1] + 1 and old_ph[4] == old_ph[3] + 1, "avant : phases consécutives (" .. table.concat(old_ph, ",") .. ")")
  local nlog = #W.logs
  local last = {}
  for i = 1, 4 do last[i] = war.factions[i].last_think end
  W.on_config({ mod_changes = {}, mod_startup_settings_changed = false, migration_applied = false })
  local logged = false
  for k = nlog + 1, #W.logs do if tostring(W.logs[k]):find("[FO-ETALEMENT]", 1, true) then logged = true end end
  check(logged, "journal [FO-ETALEMENT] de la migration")
  for i = 1, 4 do
    check(Scheduler.slot(Commander.LANE, i) == Commander.slot_for(i, 4, 300), "faction " .. i .. " replacée")
  end
  local by, same = watch(1500)
  check(same == 0, "après migration, jamais deux pensées de faction au même tick")
  for i = 1, 4 do
    local l = by[i] or {}
    local gaps_ok = #l >= 4 and l[1] - last[i] >= 1 and l[1] - last[i] <= 600
    for k = 2, #l do if l[k] - l[k - 1] ~= 300 then gaps_ok = false end end
    check(gaps_ok, string.format("faction %d : premier écart %d ticks (1 à 600), puis 300 exactement", i, (l[1] or 0) - last[i]))
  end
  -- deuxième changement de configuration : rien ne bouge, pas de journal
  local nlog2 = #W.logs
  W.on_config({ mod_changes = {} })
  local relog = false
  for k = nlog2 + 1, #W.logs do if tostring(W.logs[k]):find("[FO-ETALEMENT]", 1, true) then relog = true end end
  check(not relog, "migration jouée une seule fois (déjà en place : sans journal)")
  check(pcall(M.serialize, global), "global sérialisable")
end

---------------------------------------------------------------------------------------------------
section("5. Cadence allumée (X10-S10) : lointaines et calmes à 600 dans leur voie, réveillées à 300 dès la pensée de réveil")
---------------------------------------------------------------------------------------------------
local Cd = require("shared.faction.cadence")
local turret5 -- tourelle de la faction 3, posée une fois (coup reçu)

local function calm_all(war)
  for _, f in ipairs(war.factions) do f.threatened_until, f.attack_alert_t, f.lost_t, f.hit_t = 0, nil, nil, nil end
end

--- Attend que la faction S'ENDORME (créneau sauté) : si elle dort déjà, d'abord sa pensée suivante. Au retour, game.tick est le tick du
--- créneau sauté (sa phase) ; rend vrai si elle dort.
local function wait_asleep(f, maxw)
  local g = 0
  while f.cadence and f.cadence.asleep and g < maxw do M.run_ticks(1) g = g + 1 end
  while not (f.cadence and f.cadence.asleep) and g < maxw do M.run_ticks(1) g = g + 1 end
  return f.cadence and f.cadence.asleep
end

--- Avance jusqu'au tick `phase + off` (modulo 300) suivant.
local function to_phase(phase, off)
  while game.tick % 300 ~= (phase + off) % 300 do M.run_ticks(1) end
end

--- Pensées d'une faction après un réveil au tick `w` : la première est le réveil, les suivantes dans sa voie, écarts au plus 300, puis
--- 300 exactement (rend ok, détail).
local function woke_rhythm(l, w, phase)
  local ok = l[1] == w and #l >= 3
  for k = 2, #l do
    local g = l[k] - l[k - 1]
    if l[k] % 300 ~= phase or g > 300 or g < 1 or (k >= 3 and g ~= 300) then ok = false end
  end
  return ok, table.concat(l, " ")
end

--- La scène du §5 ; rend la liste des contrôles { ok, message } (le jeu normal les compte ; un mutant doit en faire échouer un).
local function scene5()
  local res = {}
  local function chk(c, m) res[#res + 1] = { c and true or false, m } end
  local war = State.war()
  local char = W.player.character
  Commander.CADENCE = true
  char.teleport({ x = 20000, y = 20000 })
  calm_all(war)
  M.run_ticks(600) -- chaque faction a pensé sous la cadence (zone relevée)
  calm_all(war)
  -- (a, b) Loin et calmes : 600 exactement, dans leur voie, jamais deux au même tick.
  local by, same = watch(1800)
  chk(same == 0, "cadence : jamais deux pensees de faction au meme tick (" .. same .. ")")
  for i = 1, 4 do
    local ph = Commander.slot_for(i, 4, 300) - 1
    local l = by[i] or {}
    local six = #l >= 3
    for k = 2, #l do if l[k] - l[k - 1] ~= Cd.SLOW then six = false end end
    local lane = #l >= 1
    for _, t in ipairs(l) do if t % 300 ~= ph then lane = false end end
    chk(six, string.format("cadence : faction %d loin et calme, pensees toutes les %d ticks exactement (%s)", i, Cd.SLOW, table.concat(l, " ")))
    chk(lane, string.format("cadence : faction %d garde sa voie, phase %d modulo 300 (%s)", i, ph, table.concat(l, " ")))
  end
  -- (c) Réveil par le joueur : la faction 1 endormie, le joueur à 20 tuiles de son QG 40 ticks après sa phase (hors des 4 phases).
  local f1, f3 = war.factions[1], war.factions[3]
  local ph1, ph3 = Commander.slot_for(1, 4, 300) - 1, Commander.slot_for(3, 4, 300) - 1
  local a1 = wait_asleep(f1, 700)
  to_phase(ph1, 40)
  local w1 = game.tick + 1
  char.teleport({ x = f1.hq_pos.x + 20, y = f1.hq_pos.y })
  -- (c bis) Coup reçu : une tourelle de la faction 3, touchée par une force adverse, 60 ticks après la phase de la faction 3.
  W.raise_damaged = true
  if not (turret5 and turret5.valid) then
    turret5 = game.surfaces[1].create_entity({ name = "gun-turret", position = { x = f3.hq_pos.x + 40, y = f3.hq_pos.y + 40 }, force = f3.force })
  end
  local by2 = {}
  local w3
  local same2 = 0
  for _ = 1, 1500 do
    if not w3 and f3.cadence and f3.cadence.asleep and game.tick % 300 == (ph3 + 60) % 300 and turret5 and turret5.valid then
      turret5.damage(5, "enemy", "physical")
      w3 = game.tick + 1
    end
    M.run_ticks(1)
    local n = 0
    for i, f in ipairs(war.factions) do
      if f.last_think == game.tick then n = n + 1 by2[i] = by2[i] or {} by2[i][#by2[i] + 1] = game.tick end
    end
    if n > 1 then same2 = same2 + 1 end
  end
  W.raise_damaged = false
  if turret5 and turret5.valid then turret5.health = 400 end
  local ok1, d1 = woke_rhythm(by2[1] or {}, w1, ph1)
  chk(a1 and ok1, string.format("reveil par le joueur : faction 1 repense a %d puis a 300 dans sa voie, phase %d (%s)", w1, ph1, d1))
  local l3 = {}
  for _, t in ipairs(by2[3] or {}) do if w3 and t >= w3 and t < w3 + Cd.ALERT then l3[#l3 + 1] = t end end
  local ok3, d3 = woke_rhythm(l3, w3, ph3)
  chk(w3 ~= nil and ok3, string.format("reveil par un coup sur une tourelle : faction 3 repense a %s puis a 300 dans sa voie, phase %d, tant que dure l'alerte (%s)",
    tostring(w3), ph3, d3))
  chk(same2 == 0, "reveils : jamais deux pensees de faction au meme tick (" .. same2 .. ")")
  local lanes = true
  for _, i in ipairs({ 2, 4 }) do
    for _, t in ipairs(by2[i] or {}) do if t % 300 ~= Commander.slot_for(i, 4, 300) - 1 then lanes = false end end
  end
  chk(lanes, "reveils : les factions 2 et 4, restees endormies, gardent leur voie")
  char.teleport({ x = 20000, y = 20000 })
  calm_all(war)
  return res
end

do
  for _, r in ipairs(scene5()) do check(r[1], r[2]) end
  -- Mutants (même monde, joués à la suite) : chacun doit faire échouer au moins un contrôle de la scène.
  local function refused(name, install, remove)
    install()
    local ok, res = pcall(scene5)
    remove()
    local bad = not ok
    if ok then for _, r in ipairs(res) do if not r[1] then bad = true end end end
    print(string.format("   mutant %s : %s", name, ok and (bad and "refuse" or "SURVIVANT") or ("PLANTAGE " .. tostring(res))))
    check(bad, "mutant « " .. name .. " » refuse")
  end
  -- Une faction endormie dont la VOIE GLISSE : à chaque créneau sauté, son créneau est reposé un tick plus tôt (une mise en sommeil
  -- qui replanifierait la faction au lieu de laisser son créneau). (Un réveil au minuteur sans cause ne suffit pas à faire glisser la
  -- voie : Commander.think rejuge le réveil par Cd.skip, et une faction calme y est de nouveau endormie, dans sa voie.)
  local skip0 = Cd.skip
  refused("voie d'une faction endormie qui glisse (creneau repose un tick plus tot a chaque sommeil)", function()
    Cd.skip = function(st, s, tick)
      local sk, why = skip0(st, s, tick)
      if sk then
        for id, f in ipairs(State.war().factions) do
          if f.cadence == st then Scheduler.add_at(Commander.LANE, id, (tick - 1) % Scheduler.period(Commander.LANE) + 1) end
        end
      end
      return sk, why
    end
  end, function() Cd.skip = skip0 Commander.spread() end)
  -- La voie déplacée au réveil (créneau posé au tick du réveil) : les pensées suivantes quittent la phase de la faction.
  local cwake0 = Commander.wake
  refused("voie deplacee au reveil", function()
    Commander.wake = function(f, id, cause, tick)
      Scheduler.add_at(Commander.LANE, id, tick % Scheduler.period(Commander.LANE) + 1)
      return cwake0(f, id, cause, tick)
    end
  end, function() Commander.wake = cwake0 Commander.spread() end)
end

print(string.format("[ETALEMENT-PHASES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
