--[[
  Lot LOURD (fo-logs\2026-11-07_LOURD\CRITERES.md §2) : la pensée d'une faction et le jeton des travaux lourds (script/core/lourd.lua),
  au moteur simulé (tests/mock_engine.lua), avec le VRAI Commander.think, le vrai guet par tick (lot X10-S10) et les vraies étapes
  (script/team/team.lua). Une scène « banc:lourd » prend tout le budget d'un tick AVANT que le tick ne soit joué (même module
  script.core.lourd que le mod).
  RÉÉCRIT au point 2 c (8/11, décision Q1 du lead) : au point 2 b, le réveil prenait le jeton dans Commander.wake et le créneau n'y passait
  jamais. Désormais le jeton est pris par la PREMIÈRE ÉTAPE de la pensée (E1a, Team.think), pour le réveil comme pour le créneau : une seule
  prise par pensée ; Commander.think (créneau ou réveil) se joue à son tick, et son E1a attend le jeton s'il est pris. L'ancien §7 (« le
  créneau ne passe jamais par le jeton ») et son mutant sont donc RETIRÉS en connaissance de cause (remarque d'effondrement) ; le §7
  nouveau dit le contraire, avec ses mutants.
    §1 jeton libre : la faction endormie est réveillée au tick suivant la cause, et son E1a se joue à CE tick (aucun décalage) ;
    §2 jeton pris au tick du réveil : Commander.think se joue (la faction est réveillée), E1a ATTEND (état n = 1) et se joue au tick
       d'après, t0 = ce tick-là ;
    §3 file : l'E1a refusée est EN TÊTE ; au tick suivant, un autre travail lourd qui demande avant elle est refusé, et elle est servie ;
    §4 créneau pendant l'attente : tout le budget pris au tick du créneau d'une faction endormie à cause posée : UNE seule pensée
       (Commander.think) dans les Et.SPAN + 3 ticks ;
    §5 relevés à la période du pouls : un relevé « banc:rv » (période Build.PULSE, coût 32) en file depuis une passe ne retient PAS le
       budget au tick suivant (hors passe) : l'E1a du réveil y passe ; câblage de build.lua et des prises des relevés ;
    §6 mutants de source : E1a jouée dans la voie sans jeton (§2 échoue) ; double prise au réveil (Commander.wake reprend le jeton :
       §1 échoue) ; période ignorée par le jeton (§5 échoue) ;
    §7 le CRÉNEAU d'une faction éveillée se joue à son tick ; tout le budget pris : son E1a attend le tick suivant ; et l'E1a refusée
       est en file (« <faction>:etape ») au tick du refus.
  Usage : lua5.2 tests/reveil_jeton_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1; if not quiet then print("[REVEIL-JETON] OK : " .. msg) end
  else failures = failures + 1; if not quiet then print("[REVEIL-JETON] ECHEC : " .. msg) end end
  return cond
end
local function W() return M.world() end
local function slurp(p) local h = assert(io.open(p, "rb")) local x = h:read("*a") h:close() return x end

--- Monde neuf (celui de tests/cadence_moteur_test.lua) : guerre de 2 factions à 320 tuiles, joueur loin de tout ; `mutants` =
--- { { module, path, old, new } } (sources chargées modifiées).
local function setup(mutants)
  M.new_world({ p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true, raise_damaged = true })
  local pre = {}
  for _, m in ipairs(mutants or {}) do
    local src = slurp(m.path)
    local i, j = src:find(m.old, 1, true)
    assert(i, "texte du mutant introuvable dans " .. m.path .. " : " .. m.old)
    assert(not src:find(m.old, j + 1, true), "texte du mutant present plusieurs fois : " .. m.old)
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
  local ctx = { char = char, Lourd = require("script.core.lourd"), Et = require("shared.team.etapes"), f = global.fo.war.factions[1] }
  M.run_ticks(2000)
  return ctx
end

local function calm_down(f) f.threatened_until, f.attack_alert_t, f.lost_t, f.hit_t = 0, nil, nil, nil end
--- Rendort la faction ; vrai quand elle dort (game.tick : le tick de son créneau sauté).
local function sleep(ctx)
  local f = ctx.f
  calm_down(f)
  ctx.char.teleport({ x = 20000, y = 20000 })
  local guard = 0
  while not (f.cadence and f.cadence.asleep) and guard < 1500 do
    M.run_ticks(1)
    guard = guard + 1
    if guard % 100 == 0 then calm_down(f) end
  end
  return f.cadence and f.cadence.asleep
end
--- Avance (la faction dort toujours, aucune pensée en cours) jusqu'à un tick T dont les deux suivants ne sont ni des passes du pouls
--- (Build.PULSE = 5) ni des passages des soldats de l'IA3 (30).
local function quiet_ticks(f)
  while (game.tick + 1) % 5 == 0 or (game.tick + 2) % 5 == 0 or (game.tick + 1) % 30 == 0 or (game.tick + 2) % 30 == 0
    or (f and f.team and f.team.etape) do
    M.run_ticks(1)
  end
end
--- Tick où l'E1a de la pensée en cours s'est jouée (nil : pas de pensée en cours, ou E1a encore en attente).
local function e1a_at(f)
  local et = f.team and f.team.etape
  return et and et.n >= 2 and et.t0 or nil
end
local function waiting(f)
  local et = f.team and f.team.etape
  return et and et.n == 1 and et.t0 or nil
end
local function thinks_over(f, n)
  local out, last = {}, f.last_think
  for _ = 1, n do
    M.run_ticks(1)
    if f.last_think ~= last then out[#out + 1] = f.last_think; last = f.last_think end
  end
  return out
end

--- §1 : rend (T, tick de Commander.think, tick de l'E1a).
local function scene_free(ctx)
  local f = ctx.f
  if not sleep(ctx) then return nil end
  quiet_ticks(f)
  local T = game.tick
  f.lost_t = T
  M.run_ticks(1)
  return T, f.last_think, e1a_at(f)
end

--- §2 : rend (T, Commander.think, E1a en attente après T + 1 (son t0), E1a jouée après T + 2 (son t0), jeton du banc pris, en file).
local function scene_taken(ctx)
  local f = ctx.f
  if not sleep(ctx) then return nil end
  quiet_ticks(f)
  local T = game.tick
  f.lost_t = T
  local held = ctx.Lourd.take(T + 1, "banc:lourd")
  M.run_ticks(1)
  local think, wait = f.last_think, waiting(f)
  local q = (require("script.core.storage").ns("pouls_jeton") or {}).q or {}
  local queued = false
  for _, k in ipairs(q) do if k == tostring(f.key) .. ":etape" then queued = true end end
  M.run_ticks(1)
  return T, think, wait, e1a_at(f), held, queued
end

--- §7 : faction éveillée (joueur proche) ; tout le budget pris au tick de son prochain créneau. Rend (créneau, Commander.think, E1a en
--- attente au créneau, E1a jouée au tick suivant).
local function scene_slot(ctx)
  local f = ctx.f
  ctx.char.teleport({ x = f.hq_pos.x + 20, y = f.hq_pos.y })
  M.run_ticks(700)
  local L = f.last_think
  if not L or game.tick >= L + 300 then return nil end
  while game.tick < L + 299 do M.run_ticks(1) end
  local held = ctx.Lourd.take(L + 300, "banc:lourd")
  M.run_ticks(1)
  local think, wait = f.last_think, waiting(f)
  M.run_ticks(1)
  local played = e1a_at(f)
  ctx.char.teleport({ x = 20000, y = 20000 })
  return held and L + 300, think, wait, played
end

--- §5 : rend (passe P, refus de « banc:rv », tick de l'E1a du réveil).
local function scene_pulse(ctx)
  local f, Lourd = ctx.f, ctx.Lourd
  if not sleep(ctx) then return nil end
  while (game.tick + 1) % 5 ~= 0 or (game.tick + 1) % 30 == 0 or (game.tick + 2) % 30 == 0 or (f.team and f.team.etape) do M.run_ticks(1) end
  local P = game.tick + 1 -- une passe du pouls
  Lourd.take(P, "banc:lourd")
  local rv = Lourd.take(P, "banc:rv", 5, 32) -- refusé : en file, période 5
  M.run_ticks(1)
  f.lost_t = game.tick
  M.run_ticks(1)
  return P, rv, e1a_at(f)
end

local function scenes(ctx)
  local f, Lourd, Et = ctx.f, ctx.Lourd, ctx.Et
  -- §1
  local T, th, e1 = scene_free(ctx)
  check(T and th == T + 1 and e1 == T + 1,
    string.format("§1 : jeton libre : réveil au tick %s, E1a jouée à ce tick (%s, %s)", tostring(T and T + 1), tostring(th), tostring(e1)))
  check(T and not Lourd.take(T + 1, "banc:apres"), "§1 : l'E1a a pris tout le budget de son tick (un autre travail y est refusé)")
  -- §2
  local T2, th2, w2, e2, held2, queued2 = scene_taken(ctx)
  check(T2 and held2 and th2 == T2 + 1 and w2 == T2 + 1 and e2 == T2 + 2,
    string.format("§2 : jeton pris au tick %s : la faction est réveillée (%s), son E1a attend (état n = 1, t0 %s) puis se joue au tick d'après (t0 %s, attendu %s)",
      tostring(T2 and T2 + 1), tostring(th2), tostring(w2), tostring(e2), tostring(T2 and T2 + 2)))
  check(queued2 == true, "§7 : l'E1a refusée au tick " .. tostring(T2 and T2 + 1) .. " est en file (« " .. tostring(f.key) .. ":etape »)")
  -- §3
  check(sleep(ctx), "§3 : rendormie")
  quiet_ticks(f)
  local T3 = game.tick
  f.lost_t = T3
  Lourd.take(T3 + 1, "banc:lourd")
  M.run_ticks(1)
  local other = Lourd.take(T3 + 2, "banc:autre")
  M.run_ticks(1)
  check(other == false and e1a_at(f) == T3 + 2,
    string.format("§3 : E1a en tête de file : un autre travail demandé avant elle au tick %d est refusé (%s), elle est servie (%s)", T3 + 2,
      tostring(other), tostring(e1a_at(f))))
  -- §4 : tout le budget pris au tick du créneau d'une faction endormie, cause posée
  check(sleep(ctx), "§4 : rendormie")
  local S = game.tick -- créneau sauté
  M.run_ticks(299)
  f.lost_t = game.tick
  Lourd.take(S + 300, "banc:lourd")
  local th4 = thinks_over(f, 1 + Et.SPAN + 2)
  check(#th4 == 1 and th4[1] == S + 300,
    string.format("§4 : budget pris au créneau S + 300 : une seule pensée en %d ticks (%s)", 1 + Et.SPAN + 2, table.concat(th4, " ")))
  -- §5
  local P, rv, e5 = scene_pulse(ctx)
  check(P and rv == false and e5 == P + 1,
    string.format("§5 : « banc:rv » (période 5) en file depuis la passe %s : l'E1a du réveil passe au tick %s hors passe (%s)", tostring(P),
      tostring(P and P + 1), tostring(e5)))
  -- §7
  local slot, th7, w7, e7 = scene_slot(ctx)
  check(slot and th7 == slot and w7 == slot and e7 == slot + 1,
    string.format("§7 : budget pris au créneau %s : la faction éveillée pense à son créneau (%s), son E1a attend (t0 %s) et se joue au tick suivant (%s)",
      tostring(slot), tostring(th7), tostring(w7), tostring(e7)))
end

-- Câblage : build.lua passe la période aux deux relevés ; chaque prise des relevés la transmet.
do
  local b = slurp("script/team/build.lua")
  local n = select(2, b:gsub("pulse = Build%.PULSE", ""))
  check(n == 2, string.format("§5 : build.lua passe pulse = Build.PULSE aux deux relevés (Rv.step et Raccord.step) : %d", n))
  local rv = slurp("script/team/reseau_vivant.lua")
  local ra = slurp("script/team/raccord.lua")
  local takes_rv = select(2, rv:gsub("api%.jeton%.take%(", ""))
  local with_rv = select(2, rv:gsub("api%.jeton%.take%([^\n]-api%.pulse", ""))
  local takes_ra = select(2, ra:gsub("api%.jeton%.take%(", ""))
  local with_ra = select(2, ra:gsub("api%.jeton%.take%([^\n]-api%.pulse", ""))
  check(takes_rv > 0 and takes_rv == with_rv and takes_ra > 0 and takes_ra == with_ra,
    string.format("§5 : chaque prise du jeton des relevés transmet api.pulse (réseau %d/%d, raccord %d/%d)", with_rv, takes_rv, with_ra, takes_ra))
end

local ctx = setup()
check(ctx.f and ctx.f.hq and ctx.f.hq.valid, "une faction avec son QG")
scenes(ctx)

-- §6 Mutants de source (un monde neuf chacun) : la scène visée DOIT échouer.
local function refused(fn)
  local p0, f0 = passes, failures
  quiet = true
  local ok, dead = pcall(fn)
  quiet = false
  passes, failures = p0, f0
  return ok and dead -- (un mutant qui plante, ou dont le texte manque, n'est PAS vu)
end
do
  local dead = refused(function()
    local c = setup({ { module = "script.team.team", path = "script/team/team.lua",
      old = "    if Lourd.take(tick, TT.who(f)) then", new = "    if true then" } })
    local T, th, w, e, held = scene_taken(c)
    return T ~= nil and held and not (w == T + 1 and e == T + 2)
  end)
  check(dead, "§6 : mutant « E1a jouée dans la voie sans jeton » refusé (§2 échoue)")
end
do
  local dead = refused(function()
    local c = setup({ { module = "script.faction.commander", path = "script/faction/commander.lua",
      old = "  if f.team and f.team.etape then return end -- (pensée en cours : aucun journal",
      new = "  if not package.loaded['script.core.lourd'].take(tick, tostring(f.key) .. ':reveil') then return end" .. string.char(10) ..
        "  if f.team and f.team.etape then return end -- (pensée en cours : aucun journal" } })
    local T, th, e1 = scene_free(c)
    return T ~= nil and not (th == T + 1 and e1 == T + 1)
  end)
  check(dead, "§6 : mutant « double prise au réveil » refusé (§1 échoue)")
end
do
  local dead = refused(function()
    local c = setup({ { module = "script.core.lourd", path = "script/core/lourd.lua",
      old = "return (tick - (s.last[k] or tick)) % p == 0", new = "return true" } })
    local P, rv, e5 = scene_pulse(c)
    return P ~= nil and e5 ~= P + 1
  end)
  check(dead, "§6 : mutant « période ignorée » refusé (§5 échoue)")
end

print(string.format("[REVEIL-JETON] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
