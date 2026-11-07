--[[
  Lot X10-S10 « factions lointaines plus lentes », au moteur simulé (tests/mock_engine.lua) : le VRAI Commander.think (créneaux de la voie
  fo-commander, période 300) et le guet par tick (script/faction/commander.lua). Ce n'est pas une preuve en jeu ; la mesure du gain se
  fera dans la série --seul du x10.
    §1 joueur LOIN, rien ne menace : les pensées d'une faction sont espacées de Cd.SLOW (600) ticks ; journal [FO-CADENCE] « LENTE » ;
    §2 RÉVEIL : le joueur entre dans la zone de la faction endormie : elle repense AU TICK SUIVANT (le premier tick joué après son
       arrivée), puis reprend la période de 300 tant qu'il reste ; journal « NORMALE (joueur proche) » ;
    §3 PERTE : une entité de la faction meurt loin de tout : la faction endormie repense au tick suivant (cause « perte ») ;
    §3 bis ARMÉE DEHORS (condition du lead) : une attaque en préparation (f.route_pending) tient la faction au rythme de 300 ;
    §3 ter ARMÉE DE L'IA3 (revue de 87ac84fe, point 1) : opération de nettoyage d'un site, expédition, alerte et regroupement de la
       prévision réveillent la faction endormie au tick suivant (cause « armee dehors : ... ») ;
    §3 quater COUP SUR UNE TOURELLE (point 2) : une tourelle de la faction endormie touchée par une force adverse (sans cause mobile :
       f.attack_alert_t n'est pas écrit) la réveille au tick suivant (f.hit_t, cause « attaque ») ;
    §3 quinquies CRÉNEAU APRÈS UN RÉVEIL (point 3) : réveillée 298 ticks après son créneau sauté, la faction ne repense PAS au créneau
       suivant (2 ticks plus tard) : sa pensée d'après tombe une période plus loin ;
    §4 votre équipe garde son rythme (aucune cadence posée sur elle) ; Commander.CADENCE faux : une pensée par créneau ;
    §5 mutant « jamais réveillée » (Cd.wake rend toujours faux) : le §2 échoue (la faction attend son créneau) ;
    §6 COÛT DU GUET (réserve de la revue) : deux factions endormies, un joueur : la liste des joueurs est lue UNE fois par tick ; appels
       au moteur comptés (liste des joueurs, champs du joueur) et instructions Lua (debug.sethook, champs du moteur simulé compris) ;
    §7 mutants de SOURCE (fichiers chargés modifiés, un monde neuf chacun) : l'IA3 non lue, le coup noté après le filtre des classes,
       la garde du créneau récent retirée, les joueurs relus par faction : chacun fait échouer sa scène.
  Usage : lua5.2 tests/cadence_moteur_test.lua   (depuis la racine du mod ; FO_VERBOSE=1 : contrôles réussis affichés)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1; if not quiet and os.getenv("FO_VERBOSE") then print("[CADENCE-MOTEUR] OK : " .. msg) end else failures = failures + 1; if not quiet then print("[CADENCE-MOTEUR] ECHEC : " .. msg) end end
  return cond
end
local function say(s) if not quiet then print("[CADENCE-MOTEUR] " .. s) end end
local function W() return M.world() end
local function slurp(p) local h = assert(io.open(p, "rb")) local x = h:read("*a") h:close() return x end

--- Monde neuf : guerre de 2 factions à 320 tuiles, joueur loin de tout, coffre d'équipe ; `mutants` = { { module, path, old, new } }
--- (sources chargées modifiées, par package.preload). Rend le contexte de la partie après 2 000 ticks d'échauffement.
local function setup(mutants)
  M.new_world({ p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true, raise_damaged = true })
  local pre = {}
  for _, m in ipairs(mutants or {}) do
    local src = slurp(m.path)
    local i, j = src:find(m.old, 1, true)
    assert(i, "texte du mutant introuvable dans " .. m.path .. " : " .. m.old)
    src = src:sub(1, i - 1) .. m.new .. src:sub(j + 1)
    package.preload[m.module] = function() return assert(load(src, "=" .. m.module .. "(mutant)"))() end
    pre[#pre + 1] = m.module
  end
  M.load_mod()
  for _, name in ipairs(pre) do package.preload[name] = nil end
  M.dispatch(W().on_init)
  local char = W().player.character
  char.teleport({ x = 20000, y = 20000 })
  M.command("fo-war", "start 2 30 30 320")
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 20005, y = 20005 }, force = "player" })
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  local ctx = { char = char, Commander = require("script.faction.commander"), Cd = require("shared.faction.cadence"),
    Ia3k = require("script.ai3.comportement"), f = global.fo.war.factions[1], f2 = global.fo.war.factions[2] }
  M.run_ticks(2000)
  return ctx
end

--- Joue n ticks et rend la liste des ticks où la faction a pensé (f.last_think change).
local function thinks_over(f, n)
  local out = {}
  local last = f.last_think
  for _ = 1, n do
    M.run_ticks(1)
    if f.last_think ~= last then out[#out + 1] = f.last_think last = f.last_think end
  end
  return out
end
local function logs_since(i0, pat)
  local out = {}
  for i = i0 + 1, #W().logs do local l = W().logs[i] if type(l) == "string" and l:find(pat, 1, true) then out[#out + 1] = l end end
  return out
end
--- Rythme normal d'une faction éveillée (pensées `list`, la dernière à son créneau) : jamais deux pensées à moins de 300 ticks ; 300 tout
--- juste entre deux créneaux ; après un RÉVEIL hors créneau, le créneau suivant est laissé (Cd.recent, revue de 87ac84fe) : écart de
--- 301 à 599 ticks jusqu'au créneau d'après.
local function rhythm_ok(list)
  local ref = list[#list]
  for i = 2, #list do
    local g = list[i] - list[i - 1]
    local woke = (list[i - 1] - ref) % 300 ~= 0
    if g < 300 then return false end
    if g > 300 and not (woke and g < 600 and (list[i] - ref) % 300 == 0) then return false end
  end
  return true
end
local function calm_down(f)
  f.threatened_until, f.attack_alert_t, f.lost_t, f.hit_t = 0, nil, nil, nil
end
--- Rendort la faction (alertes effacées, joueur loin) ; rend vrai quand elle dort, game.tick étant alors le tick de son créneau sauté.
local function sleep(ctx, maxw)
  local f = ctx.f
  calm_down(f)
  ctx.char.teleport({ x = 20000, y = 20000 })
  local guard = 0
  while not (f.cadence and f.cadence.asleep) and guard < (maxw or 1500) do
    M.run_ticks(1)
    guard = guard + 1
    if guard % 100 == 0 then calm_down(f) end
  end
  return f.cadence and f.cadence.asleep
end
--- Avance jusqu'à un tick dont le SUIVANT n'est pas un passage des soldats de l'IA3 (toutes les 30 ticks, script/ai3/soldats.lua) : le
--- faux état d'armée posé par une scène n'y est ni relu ni effacé avant le guet.
local function off_pass()
  while (game.tick + 1) % 30 == 0 do M.run_ticks(1) end
end

local function scene_slow(ctx)
  local f, Cd = ctx.f, ctx.Cd
  calm_down(f)
  ctx.char.teleport({ x = 20000, y = 20000 })
  local th = thinks_over(f, 2400)
  local gaps_ok = true
  for i = 2, #th do if th[i] - th[i - 1] ~= Cd.SLOW then gaps_ok = false end end
  check(#th >= 3 and gaps_ok, "§1 : loin et calme : pensees espacees de " .. Cd.SLOW .. " ticks (" .. table.concat(th, " ") .. ")")
  local lente = logs_since(0, "[FO-CADENCE] " .. tostring(f.key) .. " : cadence LENTE")
  check(#lente >= 1, "§1 : journal [FO-CADENCE] « LENTE »")
end

local function scene_player(ctx)
  local f = ctx.f
  check(sleep(ctx, 700), "§2 : la faction dort (creneau saute)")
  local T = game.tick
  local before = f.last_think
  local i1 = #W().logs
  ctx.char.teleport({ x = f.hq_pos.x + 20, y = f.hq_pos.y })
  M.run_ticks(1)
  check(f.last_think == T + 1 and f.last_think ~= before, string.format("§2 : joueur arrive apres le tick %d : la faction repense au tick suivant (%s)", T, tostring(f.last_think)))
  local list = { f.last_think == T + 1 and T + 1 or nil } -- (le réveil, s'il a eu lieu, ouvre la liste)
  local th2 = thinks_over(f, 1300)
  for _, x in ipairs(th2) do list[#list + 1] = x end
  check(#th2 >= 3 and rhythm_ok(list), "§2 : le joueur reste : rythme normal (300 entre deux creneaux, creneau qui suit le reveil laisse) ("
    .. table.concat(list, " ") .. ")")
  local nor = logs_since(i1, "[FO-CADENCE] " .. tostring(f.key) .. " : cadence NORMALE (joueur proche)")
  check(#nor == 1, "§2 : journal « NORMALE (joueur proche) » (" .. #nor .. ")")
end

local function scene_loss(ctx)
  local f = ctx.f
  check(sleep(ctx), "§3 : rendormie apres le depart du joueur")
  local T3 = game.tick
  f.lost_t = T3 -- (ce qu'écrit on_died pour toute entité de la faction : la mort elle-même est jouée par le moteur réel)
  M.run_ticks(1)
  check(f.last_think == T3 + 1, string.format("§3 : perte : la faction repense au tick suivant (%s, attendu %d)", tostring(f.last_think), T3 + 1))
end

local function scene_route(ctx)
  local f, Cd = ctx.f, ctx.Cd
  M.run_ticks(Cd.ALERT + 10)
  calm_down(f)
  local saved = f.route_pending
  f.route_pending = { ticket = -1, target_faction = -1, test = true }
  local th3 = thinks_over(f, 1300)
  f.route_pending = saved
  check(#th3 >= 3 and rhythm_ok(th3), "§3 bis : armee dehors : rythme normal (300 entre deux creneaux, creneau qui suit le reveil laisse) ("
    .. table.concat(th3, " ") .. ")")
end

--- §3 ter : chaque état d'armée de l'IA3 posé sur la faction endormie la réveille au tick suivant.
local function scene_ia3(ctx)
  local f = ctx.f
  local t = ctx.Ia3k.team(f)
  t.sd = t.sd or { per = {}, cursor = 0 }
  local sd = t.sd
  local cases = {
    { "nettoyage", function() sd.nt = { res = "site-test", x = f.hq_pos.x + 60, y = f.hq_pos.y, d = 60, phase = "rassemble", ids = {}, n0 = 0,
      need = 1, t0 = game.tick, t_phase = game.tick, rally = { x = f.hq_pos.x + 30, y = f.hq_pos.y } } end, function() sd.nt = nil end },
    { "expedition", function() sd.clearing = { x = f.hq_pos.x + 60, y = f.hq_pos.y, ["until"] = game.tick + 3600, ids = {} } end,
      function() sd.clearing = nil end },
    { "alerte", function() ctx.saved_armee = f.armee f.armee = { alert = true, fails = {}, t = game.tick } end,
      function() f.armee = ctx.saved_armee end },
    { "regroupement", function() ctx.saved_armee = f.armee f.armee = { alert = false, muster = { x = f.hq_pos.x + 10, y = f.hq_pos.y }, fails = {}, t = game.tick } end,
      function() f.armee = ctx.saved_armee end },
  }
  for _, c in ipairs(cases) do
    local ok = sleep(ctx)
    off_pass()
    ok = ok and f.cadence.asleep
    local T = game.tick
    local i0 = #W().logs
    c[2]()
    M.run_ticks(1)
    c[3]()
    local said = logs_since(i0, "[FO-CADENCE] " .. tostring(f.key) .. " : cadence NORMALE (armee dehors : " .. c[1] .. ")")
    check(ok and f.last_think == T + 1 and #said == 1, string.format("§3 ter : %s (IA3) posee sur la faction endormie : repense au tick suivant (%s, attendu %d ; journal %d)",
      c[1], tostring(f.last_think), T + 1, #said))
  end
end

--- §3 quater : coup d'une force adverse sur une tourelle de la faction endormie, sans cause mobile.
local function scene_hit(ctx)
  local f = ctx.f
  local s = game.surfaces[1]
  local tur = ctx.turret
  if not (tur and tur.valid) then
    tur = s.create_entity({ name = "gun-turret", position = { x = f.hq_pos.x + 40, y = f.hq_pos.y + 40 }, force = f.force })
    ctx.turret = tur
  end
  local ok = check(tur and tur.valid, "§3 quater : tourelle de la faction posee")
  ok = sleep(ctx) and ok
  local T = game.tick
  local i0 = #W().logs
  if tur and tur.valid then tur.damage(5, "enemy", "physical") end
  local alert = f.attack_alert_t
  M.run_ticks(1)
  local said = logs_since(i0, "[FO-CADENCE] " .. tostring(f.key) .. " : cadence NORMALE (attaque)")
  check(ok and f.hit_t == T and alert == nil, string.format("§3 quater : coup note sur la tourelle (f.hit_t %s, tick %d), sans alerte de cause mobile (%s)",
    tostring(f.hit_t), T, tostring(alert)))
  check(ok and f.last_think == T + 1 and #said == 1, string.format("§3 quater : la faction endormie repense au tick suivant (%s, attendu %d ; journal %d)",
    tostring(f.last_think), T + 1, #said))
  if tur and tur.valid then tur.health = 400 end
end

--- §3 quinquies : réveil 298 ticks après le créneau sauté S ; le créneau S + 300 est laissé, la pensée suivante tombe à S + 600.
local function scene_double(ctx)
  local f = ctx.f
  local ok = sleep(ctx)
  local S = game.tick
  M.run_ticks(297 - 0)
  calm_down(f)
  ok = ok and f.cadence.asleep and game.tick == S + 297
  f.lost_t = game.tick
  M.run_ticks(1)
  local woke = f.last_think
  local th = thinks_over(f, 700)
  local min_gap = math.huge
  local prev = woke
  for _, x in ipairs(th) do if x - prev < min_gap then min_gap = x - prev end prev = x end
  check(ok and woke == S + 298, string.format("§3 quinquies : reveillee a S + 298 (S = %d, pensee a %s)", S, tostring(woke)))
  check(ok and th[1] == S + 600 and min_gap >= 300, string.format("§3 quinquies : creneau S + 300 laisse, pensee suivante a S + 600 (%s), aucun ecart sous 300 (min %s)",
    table.concat(th, " "), tostring(min_gap)))
end

--- §6 : coût d'un tick de guet, deux factions endormies et calmes, un joueur connecté. Rend { lists, fields, instr }.
local function guard_cost(ctx)
  local f, f2, Commander = ctx.f, ctx.f2, ctx.Commander
  calm_down(f)
  calm_down(f2)
  ctx.char.teleport({ x = 20000, y = 20000 })
  local a1, a2 = f.cadence and f.cadence.asleep, f2.cadence and f2.cadence.asleep
  f.cadence, f2.cadence = f.cadence or { logs = 0 }, f2.cadence or { logs = 0 }
  f.cadence.asleep, f2.cadence.asleep = true, true
  local real_wake = Commander.wake
  local woken = 0
  Commander.wake = function() woken = woken + 1 end
  local real_on = Commander.players_on
  local calls = 0
  Commander.players_on = function(...) calls = calls + 1 return real_on(...) end
  -- Appels au moteur : lectures de game.connected_players et des champs du joueur, comptées par des mandataires.
  local cp = rawget(game, "connected_players")
  local lists, fields = 0, 0
  local proxy = setmetatable({}, { __index = function(_, k) fields = fields + 1 return cp[1][k] end })
  game.connected_players = nil
  local old_mt = getmetatable(game)
  setmetatable(game, { __index = function(_, k) if k == "connected_players" then lists = lists + 1 return { proxy } end end })
  local c = 0
  debug.sethook(function() c = c + 1 end, "", 1)
  Commander.guard(game.tick)
  debug.sethook()
  setmetatable(game, old_mt)
  game.connected_players = cp
  Commander.players_on, Commander.wake = real_on, real_wake
  f.cadence.asleep, f2.cadence.asleep = a1, a2
  return { calls = calls, lists = lists, fields = fields, instr = c, woken = woken }
end

local function scene_guard(ctx)
  local r = guard_cost(ctx)
  say(string.format("§6 cout du guet, 2 factions endormies et 1 joueur : Commander.players_on %d fois, liste des joueurs lue %d fois, %d champ(s) du joueur lu(s), %d instructions Lua (champs du moteur simule compris), %d reveil(s)",
    r.calls, r.lists, r.fields, r.instr, r.woken))
  check(r.calls == 1 and r.lists == 1, string.format("§6 : joueurs lus UNE fois par tick pour les 2 factions endormies (players_on %d, liste %d)", r.calls, r.lists))
  check(r.fields == 2, string.format("§6 : 2 champs lus par joueur connecte (surface_index, position) : %d", r.fields))
  check(r.instr < 1500, string.format("§6 : un tick de guet sous 1 500 instructions Lua (%d)", r.instr))
  return r
end

local function scenes(ctx)
  scene_slow(ctx)
  scene_player(ctx)
  scene_loss(ctx)
  scene_route(ctx)
  scene_ia3(ctx)
  scene_hit(ctx)
  scene_double(ctx)
end

local ctx = setup()
check(ctx.f and ctx.f.hq and ctx.f.hq.valid, "une faction avec son QG")
scenes(ctx)

-- §4 Votre équipe ; témoin éteint.
do
  local f = ctx.f
  local pf = global.fo.pteam and global.fo.pteam.team
  check(pf == nil or pf.cadence == nil, "§4 : votre equipe : aucune cadence posee")
  ctx.Commander.CADENCE = false
  ctx.char.teleport({ x = 20000, y = 20000 })
  calm_down(f)
  local th = thinks_over(f, 1300)
  ctx.Commander.CADENCE = true
  local every = #th >= 4
  for i = 2, #th do if th[i] - th[i - 1] ~= 300 then every = false end end
  check(every, "§4 : CADENCE eteinte : une pensee par creneau de 300 (" .. table.concat(th, " ") .. ")")
end

-- §6 Coût du guet.
scene_guard(ctx)

--- Un mutant est refusé quand sa scène échoue (ou plante).
local function refused(name, fn)
  local p0, f0 = passes, failures
  quiet = true
  local ok, err = pcall(fn)
  quiet = false
  local dead = (not ok) or failures > f0
  passes, failures = p0, f0
  print(string.format("[CADENCE-MOTEUR]   mutant %s : %s", name, ok and (dead and "refuse" or "SURVIVANT") or ("PLANTAGE " .. tostring(err))))
  return dead
end

-- §5 Mutant « jamais réveillée ».
do
  local Cd = ctx.Cd
  local o = Cd.wake
  Cd.wake = function() return false, nil end
  local dead = refused("jamais reveillee", function() scene_player(ctx) scene_loss(ctx) end)
  Cd.wake = o
  check(dead, "§5 : mutant « jamais reveillee » refuse")
end

-- §7 Mutants de source (un monde neuf chacun).
local CMD, REP = "script/faction/commander.lua", "script/team/reparation.lua"
local SRC_MUTANTS = {
  { "commander ne lit pas l'armee de l'IA3 (point 1)", { module = "script.faction.commander", path = CMD,
      old = "nt = sd and sd.nt, clearing = sd and sd.clearing,\n    armee = f.armee", new = "nt = nil, clearing = nil,\n    armee = nil" }, scene_ia3 },
  { "coup note apres le filtre des classes (point 2, l'ancien ordre)", { module = "script.team.reparation", path = REP,
      old = "  if fname ~= \"player\" then\n    local fh = State.by_force(fname)\n    if fh and e.force ~= eforce then fh.hit_t = e.tick end\n  end\n  if not Rp.ENABLED then return end\n  if not CLASS[false][etype] then return end",
      new = "  if not Rp.ENABLED then return end\n  if not CLASS[false][etype] then return end\n  if fname ~= \"player\" then\n    local fh = State.by_force(fname)\n    if fh and e.force ~= eforce then fh.hit_t = e.tick end\n  end" }, scene_hit },
  { "garde du creneau recent retiree (point 3, garde du meme tick seule)", { module = "script.faction.commander", path = CMD,
      old = "if not woken and Cd.recent(cs, tick, Scheduler.period(Commander.LANE)) then return end", new = "" }, scene_double },
  { "joueurs relus pour chaque faction endormie (reserve)", { module = "script.faction.commander", path = CMD,
      old = "players = players or Commander.players_on(war.surface)", new = "players = Commander.players_on(war.surface)" },
    function(c) scene_guard(c) end },
}
local killed = 0
for _, m in ipairs(SRC_MUTANTS) do
  local dead = refused(m[1], function()
    local c = setup({ m[2] })
    m[3](c)
  end)
  if dead then killed = killed + 1 end
  check(dead, "§7 : mutant « " .. m[1] .. " » refuse")
end
say(string.format("mutants de source refuses : %d / %d", killed, #SRC_MUTANTS))

print(string.format("[CADENCE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
