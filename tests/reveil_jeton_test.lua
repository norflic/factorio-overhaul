--[[
  Lot LOURD (point 2 b, 8/11 ; fo-logs\2026-11-07_LOURD\CRITERES.md §2) : le RÉVEIL d'une faction endormie (lot X10-S10, Commander.wake,
  script/faction/commander.lua) passe par le jeton des travaux lourds (script/core/lourd.lua). Cd.wake décide SI la faction pense, le
  jeton décide QUAND. Au moteur simulé (tests/mock_engine.lua), avec le VRAI Commander.think et le vrai guet par tick. Une scène
  « banc:lourd » prend tout le budget d'un tick AVANT que le tick ne soit joué (même module script.core.lourd que le mod).
    §1 jeton libre : la faction endormie repense au tick suivant la cause (comme le lot S10), et le jeton a servi « <faction>:reveil » ;
    §2 jeton pris au tick suivant la cause : la pensée n'y est PAS jouée ; elle l'est au tick d'après (cause tenue : Cd.wake est un
       niveau), et jamais sur un tick dont le budget est déjà pris ;
    §3 file : le réveil refusé passe EN TÊTE ; au tick suivant, un autre travail lourd qui demande avant le guet est refusé et le réveil
       est servi (personne n'est affamé) ;
    §4 créneau pendant l'attente : le réveil est refusé au tick du créneau de la faction ; le créneau la fait penser, le guet ne la
       réveille plus : UNE seule pensée dans les Et.SPAN ticks qui suivent ;
    §5 relevés à la période du pouls : un relevé « banc:rv » (période Build.PULSE, coût 32) en file depuis une passe ne retient PAS le
       budget au tick suivant (hors passe) : le réveil y passe ; build.lua passe `pulse = Build.PULSE` aux deux relevés, et chaque prise de
       reseau_vivant.lua et raccord.lua la transmet ;
    §6 mutants de source : réveil sans jeton (§2 échoue) ; période ignorée par le jeton (§5 échoue).
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
--- Avance (la faction dort toujours) jusqu'à un tick T dont les deux suivants ne sont ni des passes du pouls (Build.PULSE = 5) ni des
--- passages des soldats de l'IA3 (30) : aucun relevé du mod ne demande le jeton à T + 1 ni à T + 2.
local function quiet_ticks()
  while (game.tick + 1) % 5 == 0 or (game.tick + 2) % 5 == 0 or (game.tick + 1) % 30 == 0 or (game.tick + 2) % 30 == 0 do
    M.run_ticks(1)
  end
end
--- Ticks où la faction pense pendant n ticks.
local function thinks_over(f, n)
  local out, last = {}, f.last_think
  for _ = 1, n do
    M.run_ticks(1)
    if f.last_think ~= last then out[#out + 1] = f.last_think; last = f.last_think end
  end
  return out
end

--- §2 : rend (tick de la cause T, tick de la pensée, pris au tick T + 1 par le banc).
local function scene_taken(ctx)
  local f = ctx.f
  if not sleep(ctx) then return nil end
  quiet_ticks()
  local T = game.tick
  f.lost_t = T
  local held = ctx.Lourd.take(T + 1, "banc:lourd")
  M.run_ticks(1)
  local at1 = f.last_think
  M.run_ticks(1)
  return T, f.last_think, held, at1
end

local function scenes(ctx)
  local f, Lourd, Et = ctx.f, ctx.Lourd, ctx.Et
  -- §1
  check(sleep(ctx), "§1 : la faction dort (créneau sauté)")
  quiet_ticks()
  local T = game.tick
  f.lost_t = T
  M.run_ticks(1)
  check(f.last_think == T + 1, string.format("§1 : jeton libre : la faction repense au tick suivant la cause (%s, attendu %d)", tostring(f.last_think), T + 1))
  check(not Lourd.take(T + 1, "banc:apres"), "§1 : le réveil a pris tout le budget de son tick (un autre travail y est refusé)")
  -- §2
  local T2, th2, held2, at1 = scene_taken(ctx)
  check(T2 and held2 and at1 ~= T2 + 1 and th2 == T2 + 2,
    string.format("§2 : jeton pris au tick %s : pas de pensée ce tick-là (%s), pensée au tick d'après (%s, attendu %s)", tostring(T2 and T2 + 1),
      tostring(at1), tostring(th2), tostring(T2 and T2 + 2)))
  -- §3
  check(sleep(ctx), "§3 : rendormie")
  quiet_ticks()
  local T3 = game.tick
  f.lost_t = T3
  Lourd.take(T3 + 1, "banc:lourd")
  M.run_ticks(1)
  local other = Lourd.take(T3 + 2, "banc:autre")
  M.run_ticks(1)
  check(other == false and f.last_think == T3 + 2,
    string.format("§3 : réveil en tête de file : un autre travail demandé avant le guet au tick %d est refusé (%s), le réveil est servi (%s)", T3 + 2,
      tostring(other), tostring(f.last_think)))
  -- §4 : réveil refusé au tick du créneau de la faction
  check(sleep(ctx), "§4 : rendormie")
  local S = game.tick -- créneau sauté
  M.run_ticks(299)
  f.lost_t = game.tick
  Lourd.take(S + 300, "banc:lourd")
  local th4 = thinks_over(f, 1 + Et.SPAN + 2)
  check(#th4 == 1 and th4[1] == S + 300,
    string.format("§4 : réveil refusé au créneau S + 300 : le créneau fait penser la faction, une seule pensée en %d ticks (%s)", 1 + Et.SPAN + 2,
      table.concat(th4, " ")))
  -- §5 : un relevé à la période du pouls en file ne retient pas le budget hors passe
  check(sleep(ctx), "§5 : rendormie")
  while (game.tick + 1) % 5 ~= 0 or (game.tick + 1) % 30 == 0 or (game.tick + 2) % 30 == 0 do M.run_ticks(1) end
  local P = game.tick + 1 -- une passe du pouls
  Lourd.take(P, "banc:lourd")
  local rv = Lourd.take(P, "banc:rv", 5, 32) -- refusé : en file, période 5
  M.run_ticks(1)
  f.lost_t = game.tick
  M.run_ticks(1)
  check(rv == false and f.last_think == P + 1,
    string.format("§5 : « banc:rv » (période 5) en file depuis la passe %d : le réveil passe au tick %d hors passe (%s)", P, P + 1, tostring(f.last_think)))
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
    local c = setup({ { module = "script.faction.commander", path = "script/faction/commander.lua",
      old = '  if not Lourd.take(tick, tostring(f.key) .. ":reveil") then return end\n', new = "" } })
    local T, th, held = scene_taken(c)
    return not (T and held and th == T + 2)
  end)
  check(dead, "§6 : mutant « réveil sans jeton » refusé (§2 échoue)")
end
do
  local dead = refused(function()
    local c = setup({ { module = "script.core.lourd", path = "script/core/lourd.lua",
      old = "return (tick - (s.last[k] or tick)) % p == 0", new = "return true" } })
    local f, Lourd = c.f, c.Lourd
    if not sleep(c) then return true end
    while (game.tick + 1) % 5 ~= 0 or (game.tick + 1) % 30 == 0 or (game.tick + 2) % 30 == 0 do M.run_ticks(1) end
    local P = game.tick + 1
    Lourd.take(P, "banc:lourd")
    Lourd.take(P, "banc:rv", 5, 32)
    M.run_ticks(1)
    f.lost_t = game.tick
    M.run_ticks(1)
    return f.last_think ~= P + 1
  end)
  check(dead, "§6 : mutant « période ignorée » refusé (§5 échoue)")
end

print(string.format("[REVEIL-JETON] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
