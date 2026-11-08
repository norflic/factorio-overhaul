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
    §3 quinquies CRÉNEAU APRÈS UN RÉVEIL (point 3, seuil décidé par le lead) : réveillée 298 ticks après son créneau sauté S, la
       faction ne repense PAS au créneau S + 300, qui tombe dans les étapes de la pensée du réveil (Et.SPAN = 7 en 0.6.62) : sa pensée suivante est à
       S + 600 au plus tard (le seul cas borné) ; réveillée à S + 1, elle repense au créneau S + 300 (rythme gardé) ; la dernière étape
       de la pensée du réveil tombe bien Et.SPAN ticks après elle (shared/team/etapes.lua) ;
    §4 votre équipe garde son rythme (aucune cadence posée sur elle) ; Commander.CADENCE faux : une pensée par créneau ;
    §5 mutant « jamais réveillée » (Cd.wake rend toujours faux) : le §2 échoue (la faction attend son créneau) ;
    §6 COÛT DU GUET (réserve de la revue) : deux factions endormies, un joueur : la liste des joueurs est lue UNE fois par tick ; appels
       au moteur comptés (liste des joueurs, champs du joueur) et instructions Lua (debug.sethook, champs du moteur simulé compris) ;
    §7 mutants de SOURCE (fichiers chargés modifiés, un monde neuf chacun) : l'IA3 non lue, le coup noté après le filtre des classes,
       la garde du créneau récent retirée, son seuil porté à la période, les joueurs relus par faction : chacun fait échouer sa scène.
       Lot LOURD (point 2 c, 8/11) : la garde « pensée en cours » (f.team.etape posé ; commander.lua, juste avant Cd.recent) couvre
       aussi la scène du §3 quinquies ; le mutant « garde du créneau récent retirée » retire donc LES DEUX gardes (sinon il serait
       équivalent), dit en connaissance de cause ;
    §8 (lot LOURD, point 2 c) PENSÉE EN COURS : réveillée à S + 290, la faction a ses étapes retardées par le jeton des travaux lourds
       (neuf demandeurs « banc » en file au tick S + 291, qui retiennent tout le budget jusqu'à leur purge, J.STALE) : au créneau S + 300,
       hors de Cd.recent (S + 297) mais pendant la pensée, AUCUNE pensée n'est commencée et aucun rattrapage n'a lieu ; mutant « créneau
       joué pendant une pensée » (la seule garde « pensée en cours » retirée) : la scène échoue.
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
  local th2 = thinks_over(f, 1300)
  local normal = #th2 >= 4
  for i = 2, #th2 do if th2[i] - th2[i - 1] > 300 then normal = false end end
  check(normal, "§2 : le joueur reste : rythme normal, aucun ecart au-dela de 300 (" .. table.concat(th2, " ") .. ")")
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
  local every = #th3 >= 4
  for i = 2, #th3 do if th3[i] - th3[i - 1] > 300 then every = false end end
  check(every, "§3 bis : armee dehors : rythme normal, aucun ecart au-dela de 300 (" .. table.concat(th3, " ") .. ")")
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

--- §3 quinquies : réveil k ticks après le créneau sauté S (perte notée à S + k − 1, vue par le guet au tick suivant). Rend la pensée du
--- réveil, la liste des pensées des 700 ticks suivants et le tick de la dernière étape de la pensée du réveil.
local function wake_at(ctx, k)
  local f = ctx.f
  local ok = sleep(ctx)
  local S = game.tick
  if k > 1 then M.run_ticks(k - 1) end
  calm_down(f)
  ok = ok and f.cadence.asleep and game.tick == S + k - 1
  f.lost_t = game.tick
  M.run_ticks(1)
  local woke = f.last_think
  local last_step
  local th, last = {}, f.last_think
  for _ = 1, 700 do
    local busy = f.team and f.team.etape ~= nil
    M.run_ticks(1)
    if busy and not last_step and not (f.team and f.team.etape) then last_step = game.tick end
    if f.last_think ~= last then th[#th + 1] = f.last_think last = f.last_think end
  end
  return ok, S, woke, th, last_step
end

local function scene_double(ctx)
  local Et = require("shared.team.etapes")
  -- Le seul cas borné : le créneau S + 300 tombe dans les étapes de la pensée du réveil (S + 298 à S + 301).
  local ok, S, woke, th, last_step = wake_at(ctx, 298)
  check(ok and woke == S + 298, string.format("§3 quinquies : reveillee a S + 298 (S = %d, pensee a %s)", S, tostring(woke)))
  check(ok and last_step == woke + Et.SPAN, string.format("§3 quinquies : derniere etape de la pensee du reveil a + %s ticks (Et.SPAN = %d)",
    tostring(last_step and woke and last_step - woke), Et.SPAN))
  local nxt = th[1]
  check(ok and nxt ~= S + 300 and nxt ~= nil and nxt <= S + 600 and th[2] and th[2] - nxt == 300,
    string.format("§3 quinquies : creneau S + 300 laisse (dans les etapes), pensee suivante a S + 600 au plus tard (%s), puis 300", table.concat(th, " ")))
  -- Réveil juste après le créneau sauté : le créneau suivant n'est pas dans les étapes, la faction y pense (rythme gardé).
  ok, S, woke, th = wake_at(ctx, 1)
  check(ok and woke == S + 1 and th[1] == S + 300, string.format("§3 quinquies : reveillee a S + 1 (%s), pensee suivante au creneau S + 300 (%s ; S = %d)",
    tostring(woke), table.concat(th, " "), S))
  local every = #th >= 2
  for i = 2, #th do if th[i] - th[i - 1] ~= 300 then every = false end end
  check(every, "§3 quinquies : puis 300 (" .. table.concat(th, " ") .. ")")
end

--- §8 (lot LOURD, point 2 c) : réveil à S + 290, étapes retardées par le jeton ; le créneau S + 300 tombe pendant la pensée.
local function scene_busy(ctx)
  local f = ctx.f
  local Lourd = require("script.core.lourd")
  local ok = sleep(ctx)
  local S = game.tick
  M.run_ticks(289)
  calm_down(f)
  ok = ok and f.cadence.asleep and game.tick == S + 289
  f.lost_t = game.tick
  M.run_ticks(1)
  local woke = f.last_think
  local rt0 = (f.team and f.team.etapes and f.team.etapes.rattrapages) or 0
  for i = 1, 10 do Lourd.take(S + 291, "banc:" .. i) end -- (le 1er servi ; les 9 autres en file retiennent le budget jusqu'à leur purge)
  M.run_ticks(9) -- jusqu'à S + 299
  local busy = f.team and f.team.etape ~= nil
  M.run_ticks(1) -- S + 300 : le créneau
  local at300 = f.last_think
  local still = f.team and f.team.etape ~= nil
  local rt1 = (f.team and f.team.etapes and f.team.etapes.rattrapages) or 0
  check(ok and woke == S + 290, string.format("§8 : reveillee a S + 290 (S = %d, pensee a %s)", S, tostring(woke)))
  check(ok and busy and still and at300 == S + 290 and rt1 == rt0,
    string.format("§8 : creneau S + 300 pendant la pensee (etapes retardees, en cours avant et apres : %s, %s) : aucune pensee commencee (derniere : %s) ni rattrapage (%d)",
      tostring(busy), tostring(still), tostring(at300), rt1 - rt0))
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
  scene_busy(ctx)
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
  { "garde du creneau recent retiree (point 3, garde du meme tick seule ; lot LOURD : avec la garde pensee en cours)",
    { module = "script.faction.commander", path = CMD,
      old = "    if f.team and f.team.etape then return end\n    if not woken and Cd.recent(cs, tick) then return end", new = "" }, scene_double },
  { "creneau joue pendant une pensee (lot LOURD, point 2 c : la garde pensee en cours retiree)", { module = "script.faction.commander",
      path = CMD, old = "    if f.team and f.team.etape then return end\n    if not woken", new = "    if not woken" }, function(c) scene_busy(c) end },
  { "seuil du creneau porte a la periode (point 3, correction refusee par le lead)", { module = "script.faction.commander", path = CMD,
      old = "Cd.recent(cs, tick)", new = "Cd.recent(cs, tick, Scheduler.period(Commander.LANE))" }, scene_double },
  { "ecart des etapes fige a 3 (E1 a E4 d'avant la 0.6.62) au lieu d'etre tire de E.STAGES", { module = "shared.team.etapes",
      path = "shared/team/etapes.lua", old = "E.SPAN = E.STEPS - 1", new = "E.SPAN = 3" }, scene_double },
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
