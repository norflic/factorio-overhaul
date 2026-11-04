--[[
  Lot DEPENSES2, revue D1 (BLOQUANT : cliquet des laboratoires) : la règle du stock qui dort BRANCHÉE, au moteur simulé
  (tests/mock_engine.lua). Ce n'est pas une preuve en jeu.
    §1 une faction au coffre plein (30 000 fer, 30 000 cuivre, 60 laboratoires au coffre) : la règle s'endort ([FO-DEPENSES] « dort »),
       la cible de laboratoires se fige, les laboratoires posés ne dépassent jamais le plafond (Br.labs_max + Dep.LABS_MAX) et ne
       bougent plus sur les 4 dernières minutes, même pensée après pensée (research_step tourne à chaque pensée) ;
    §2 TÉMOIN DU DÉFAUT : la cible relative d'avant (« présents + n », commit ddd82445) remise à la main : les laboratoires dépassent
       le plafond (le banc voit le cliquet) ;
    §3 armement (revues D3, E1, E2) : la cible d'armée de la faction est relevée de 6 au plus au-dessus de celle du cerveau, jamais au-delà
       du plafond de soldats, des recrues arrivent au-dessus de la cible du cerveau ; la capitalisation reçoit un stock hors besoin débité
       de l'engagé (laboratoires à faire, soldats AU-DESSUS de la cible du cerveau) ;
    §4 interrupteur f.team.depenses.on = false : aucune ligne ;
    §5 essai 3 : CENTRE EN ATTENTE DE CIRCUITS (but courant de l'amélioration, coût impayable) : 0 laboratoire et 0 soldat de plus,
       journal « CENTRE EN ATTENTE » ; son mutant (la garde ignorée) pose des laboratoires.
  Usage : lua5.2 tests/depenses2_moteur_test.lua   (depuis la racine du mod ; quelques minutes)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[DEPENSES2-MOTEUR] ECHEC : " .. msg) end
end
local function say(s) print("[DEPENSES2-MOTEUR] " .. s) end
local function W() return M.world() end
local MIN = 3600

local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for _, c in ipairs({ { 1, 0 }, { -1, 0 } }) do
    for i = 0, 11 do
      out[#out + 1] = { x = c[1] * 320 + math.cos(i * math.pi / 6) * 60, y = math.sin(i * math.pi / 6) * 60, name = names[i % 4 + 1] }
    end
  end
  return out
end

local function labs_of(f)
  local n = 0
  for _, e in ipairs((f.team.ia3 and f.team.ia3.labs) or {}) do if e.valid then n = n + 1 end end
  return n
end

local function run(opts)
  M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
  M.load_mod()
  M.dispatch(W().on_init)
  M.command("fo-war", "start 2 30 30 320")
  M.run_ticks(MIN)
  local f = global.fo.war.factions[1]
  local Stock = require("script.team.stock")
  local Dep = require("script.ai3.depenses")
  if opts.off then
    f.team.depenses = { on = false }
  end
  if opts.centre then
    -- §5 : le centre est le but courant de l'amélioration et attend des circuits (coût impayable : il reste en attente).
    f.team.capital = f.team.capital or {}
    local c = f.team.capital
    local cost = { { "electronic-circuit", 1000000 } }
    c.current = { key = "command:2:banc", id = 0, family = "command", center = true, cost = cost, value = 50, work = 0, score = 1 }
    c.goal = { key = "capital:command:2:banc", family = "capital", kind = "upgrade", target = "command:2:banc", value = 50, center = true,
      fond = true, cost = cost }
    c.scan_n = 1e9
  end
  if opts.ignore_hold then Dep.centre_waiting = function() return false end end -- mutant de §5
  local spy = { calls = 0, raise = 0, over_max = 0, above_brain = 0, brain = nil }
  local o_st = Dep.soldiers_target
  Dep.soldiers_target = function(ff, army, max, now, tick, key, key_short)
    local t = o_st(ff, army, max, now, tick, key, key_short)
    if ff == f then
      spy.calls = spy.calls + 1
      if t - army > spy.raise then spy.raise = t - army end
      if t > (max or 0) and t > army then spy.over_max = spy.over_max + 1 end
      if t > army then spy.brain = army end
      if spy.brain and (f.soldiers_count or 0) - spy.brain > spy.above_brain then spy.above_brain = (f.soldiers_count or 0) - spy.brain end
    end
    return t
  end
  if opts.relative then
    -- TÉMOIN DU DÉFAUT D1 : la cible relative d'avant (présents + n, sans plafond ni base).
    Dep.labs_target = function(ff, now, cap, tick)
      local r = ff.team.depenses and ff.team.depenses.res
      if not (r and (r.labs or 0) > 0) then return nil end
      return now + r.labs
    end
  end
  for _, it in ipairs({ { "iron-plate", 30000 }, { "copper-plate", 30000 }, { "lab", 60 } }) do Stock.insert(f, it[1], it[2]) end
  local log0 = #W().logs -- (les lignes de la première minute, avant l'interrupteur, ne comptent pas)
  local series, reserve_seen = {}, nil
  for m = 1, opts.minutes do
    M.run_ticks(MIN)
    series[m] = labs_of(f)
    if not reserve_seen and f.team.depenses and f.team.depenses.lab_target then
      local held = Dep.reserved(f, game.tick)
      local tot = 0
      for _, v in pairs(held) do tot = tot + v end
      reserve_seen = tot
    end
  end
  local lines = {}
  for i = log0 + 1, #W().logs do
    local l = W().logs[i]
    if l:find("[FO-DEPENSES] " .. tostring(f.key), 1, true) then lines[#lines + 1] = l end
  end
  local Br = require("shared.ai3.bras")
  local Ia3 = require("script.ai3.cerveau")
  local cap = Br.labs_max(f.engineers_count or 0, Ia3.LABS_MAX, 6) + Dep.LABS_MAX -- (6 : plafond haut du bonus des bras libres, Dm.CAP_EXTRA_MAX)
  return { f = f, series = series, lines = lines, cap = cap, reserve = reserve_seen, d = f.team.depenses, spy = spy }
end

local MINUTES = 16
say("§1 regle allumee")
local a = run({ minutes = MINUTES })
local sleeping = 0
for _, l in ipairs(a.lines) do if l:find(" dort ", 1, true) then sleeping = sleeping + 1 end end
check(#a.lines >= 10, "§1 journal [FO-DEPENSES] chaque minute (" .. #a.lines .. ")")
check(sleeping >= 3, "§1 le stock s'endort (" .. sleeping .. " ligne(s) « dort »)")
local maxl, last = 0, a.series[MINUTES]
for m = 1, MINUTES do if a.series[m] > maxl then maxl = a.series[m] end end
say("§1 laboratoires par minute : " .. table.concat(a.series, " ") .. " ; plafond " .. a.cap .. " ; base " .. tostring(a.d.lab_base)
  .. " cible " .. tostring(a.d.lab_target))
check(maxl <= a.cap, "§1 jamais au-delà du plafond (" .. maxl .. " <= " .. a.cap .. ")")
check(a.series[MINUTES - 4] == last, "§1 plus aucun laboratoire posé sur les 4 dernières minutes (" .. a.series[MINUTES - 4] .. " -> " .. last .. ")")
check(a.d.lab_target ~= nil and last <= a.d.lab_target, "§1 posés <= cible absolue (" .. last .. " <= " .. tostring(a.d.lab_target) .. ")")
check(last > a.series[1], "§1 la recherche a reçu des laboratoires de plus (" .. a.series[1] .. " -> " .. last .. ")")
say(string.format("§3 armement : appels %d, relevement max %d, au-dela du plafond %d, recrues au-dessus de la cible du cerveau %d",
  a.spy.calls, a.spy.raise, a.spy.over_max, a.spy.above_brain))
check(a.spy.raise >= 1 and a.spy.raise <= 6, "§3 cible d'armée relevée de 1 à 6 au-dessus de celle du cerveau (" .. a.spy.raise .. ")")
check(a.spy.over_max == 0, "§3 jamais au-delà du plafond de soldats")
check(a.spy.above_brain >= 1, "§3 des recrues arrivent au-dessus de la cible du cerveau (" .. a.spy.above_brain .. ")")
do -- §3 débit : 2 laboratoires encore à faire et 6 soldats au-dessus de la cible du cerveau (tous ceux du cerveau présents)
  local Rsv, Dep, Dp = require("script.ai3.reserve"), require("script.ai3.depenses"), require("shared.ai3.depenses")
  local d = a.d
  local save = { d.lab_now, d.soldier_target, d.soldier_brain, d.soldier_now, d.soldier_key }
  d.lab_now = (d.lab_target or 2) - 2
  d.soldier_brain, d.soldier_target, d.soldier_now, d.soldier_key = 18, 24, 18, "iron-plate"
  local rin = Rsv.input(a.f, game.tick)
  local function sum(t) local n = 0 for _, v in pairs((t and t.free) or {}) do n = n + v end return n end
  local before = sum(rin)
  local out = Dep.capi_reserve(a.f, rin, game.tick)
  local held = Dp.reserved(d.res, d.lab_target, d.lab_now, 24, 18, 18, "iron-plate")
  local want = 0
  for _, v in pairs(held) do want = want + v end
  check(rin ~= nil and math.abs((before - sum(out)) - want) < 1e-6 and want >= 120 + 360 - 1e-6,
    "§3 stock hors besoin de la capitalisation débité de l'engagé : 2 laboratoires (120) + 6 soldats au-dessus du cerveau (360), défense comprise ("
    .. string.format("%.1f", before - sum(out)) .. " = " .. string.format("%.1f", want) .. ")")
  check(sum(rin) == before, "§3 l'entrée d'origine n'est pas modifiée (copie)")
  d.lab_now, d.soldier_target, d.soldier_brain, d.soldier_now, d.soldier_key = save[1], save[2], save[3], save[4], save[5]
end

say("§2 temoin du defaut (cible relative d'avant)")
local b = run({ minutes = MINUTES, relative = true })
local maxb = 0
for m = 1, MINUTES do if b.series[m] > maxb then maxb = b.series[m] end end
say("§2 laboratoires par minute : " .. table.concat(b.series, " "))
check(maxb > a.cap, "§2 le banc voit le cliquet : la cible relative dépasse le plafond (" .. maxb .. " > " .. a.cap .. ")")

say("§4 interrupteur eteint")
local c = run({ minutes = 8, off = true })
check(#c.lines == 0, "§4 éteint : aucune ligne [FO-DEPENSES] (" .. #c.lines .. ")")

say("§5 centre en attente de circuits")
local e = run({ minutes = 10, centre = true })
local held_lines = 0
for _, l in ipairs(e.lines) do if l:find("CENTRE EN ATTENTE", 1, true) then held_lines = held_lines + 1 end end
local maxe = 0
for m = 1, 10 do if e.series[m] > maxe then maxe = e.series[m] end end
say("§5 laboratoires par minute : " .. table.concat(e.series, " ") .. " ; lignes « centre en attente » " .. held_lines)
check(held_lines >= 5, "§5 journal : centre en attente (" .. held_lines .. ")")
check(maxe <= e.series[1], "§5 centre en attente : 0 laboratoire de plus (" .. e.series[1] .. " -> " .. maxe .. ")")
check(e.spy.raise == 0, "§5 centre en attente : 0 soldat de plus (" .. e.spy.raise .. ")")
say("§5 mutant : la garde du centre ignoree")
local g = run({ minutes = 10, centre = true, ignore_hold = true })
local maxg = 0
for m = 1, 10 do if g.series[m] > maxg then maxg = g.series[m] end end
say("§5 mutant : laboratoires par minute : " .. table.concat(g.series, " "))
check(maxg > g.series[1], "§5 mutant détecté : sans la garde, des laboratoires sont posés malgré le centre (" .. g.series[1] .. " -> " .. maxg .. ")")

print(string.format("[DEPENSES2-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
