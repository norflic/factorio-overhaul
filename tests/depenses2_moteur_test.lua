--[[
  Lot DEPENSES2, revue D1 (BLOQUANT : cliquet des laboratoires) : la règle du stock qui dort BRANCHÉE, au moteur simulé
  (tests/mock_engine.lua). Ce n'est pas une preuve en jeu.
    §1 une faction au coffre plein (30 000 fer, 30 000 cuivre, 60 laboratoires au coffre) : la règle s'endort ([FO-DEPENSES] « dort »),
       la cible de laboratoires se fige, les laboratoires posés ne dépassent jamais le plafond (Br.labs_max + Dep.LABS_MAX) et ne
       bougent plus sur les 4 dernières minutes, même pensée après pensée (research_step tourne à chaque pensée) ;
    §2 TÉMOIN DU DÉFAUT : la cible relative d'avant (« présents + n », commit ddd82445) remise à la main : les laboratoires dépassent
       le plafond (le banc voit le cliquet) ;
    §3 la capitalisation reçoit un stock hors besoin débité de ce que la règle a engagé (revue D2) ;
    §4 interrupteur f.team.depenses.on = false : aucune ligne, aucun laboratoire de plus que le témoin éteint.
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
  return { f = f, series = series, lines = lines, cap = cap, reserve = reserve_seen, d = f.team.depenses }
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
do -- §3 : 2 laboratoires encore à faire (débit 2 x Dp.LAB_COST = 120 plaques) : la capitalisation reçoit un stock hors besoin débité d'autant
  local Rsv, Dep = require("script.ai3.reserve"), require("script.ai3.depenses")
  local save = a.d.lab_now
  a.d.lab_now = (a.d.lab_target or 2) - 2
  local rin = Rsv.input(a.f, game.tick)
  local function sum(t) local n = 0 for _, v in pairs((t and t.free) or {}) do n = n + v end return n end
  local before = sum(rin)
  local out = Dep.capi_reserve(a.f, rin, game.tick)
  local Dp = require("shared.ai3.depenses")
  local soldiers = (a.d.soldier_target and a.d.soldier_now) and Dp.engaged(a.d.soldier_target, a.d.soldier_now, Dp.SOLDIER_COST) or 0
  local def = 0
  for _, v in pairs(Dep.defense(a.f, game.tick)) do def = def + v end
  local want = 120 + soldiers + def
  check(rin ~= nil and math.abs((before - sum(out)) - want) < 1e-6, "§3 stock hors besoin de la capitalisation débité de l'engagé : 120 (2 laboratoires) + "
    .. soldiers .. " (soldats) + " .. def .. " (défense) = " .. want .. " (" .. string.format("%.1f", before - sum(out)) .. ")")
  check(soldiers > 0, "§3 des soldats de plus sont engagés (armement, " .. soldiers .. " plaques)")
  check(sum(rin) == before, "§3 l'entrée d'origine n'est pas modifiée (copie)")
  a.d.lab_now = save
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

print(string.format("[DEPENSES2-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
