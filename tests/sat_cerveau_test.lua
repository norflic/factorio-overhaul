--[[
  Lot VIDEO-SAT, étape 4 bis (branchement) : la scène V79 dans la VRAIE situation du cerveau, au moteur simulé (tests/mock_engine.lua).
  Ce n'est pas une preuve en jeu : la levée y demande au moins Sa.WINDOW relevés d'une minute, donc un banc LONG (accord du DC).
  On appelle le vrai Ia3.plan (script/ai3/cerveau.lua : C.situation, C.think, B.saturated) d'une faction, une pensée par minute de
  jeu, sur sa vraie vue (Team.view) dont seul le stock libre de la plaque clé est remplacé par une suite connue :
    §1 FONTE : seuil + 2 000 + 200 × (10 − m) : saturée par la règle d'avant à la minute 10 (stock au-dessus du seuil), mais le stock
       fond de 200/min : la saturation est LEVÉE (st.saturated faux, st.sat_lifted = 200) dès que la fonte est mesurée ;
       journal [FO-SAT] « LEVEE », puis « RENDUE » quand le stock cesse de fondre ;
    §2 TÉMOIN sans mesure (Sa.drains rend {}) : la même suite reste saturée (la règle d'avant) ;
    §3 stock qui MONTE : saturé de bout en bout, rien de levé ;
    §4 état st.sat : nombres seulement, une entrée par matière suivie (C.raw_items) ;
    §5 mutants de comportement : chacun fait échouer au moins un contrôle.
  Usage : lua5.2 tests/sat_cerveau_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("[SAT-CERVEAU] ECHEC : " .. msg) end end
  return cond
end
local function say(s) if not quiet then print("[SAT-CERVEAU] " .. s) end end
local function W() return M.world() end
local MIN = 3600

M.new_world({ p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
M.load_mod()
M.dispatch(W().on_init)
M.command("fo-war", "start 2 30 30 320")
M.run_ticks(2 * MIN)

local T = require("shared.team.config")
local Team = require("script.team.team")
local Ia3 = require("script.ai3.cerveau")
local Sa = require("shared.ai3.saturation")
local B = require("shared.ai3.buts")
local Dm = require("shared.ai3.demande")
local Br = require("shared.ai3.bras")
local Book = require("shared.team.book")

local f = global.fo.war.factions[1]
check(f and f.team and f.hq and f.hq.valid, "une faction avec son QG")
local force = game.forces[f.force]
local book = Book.from_game(game.recipe_prototypes, { allowed = function(name)
  local r = force and force.recipes and force.recipes[name]
  return r ~= nil and r.enabled
end })
local P = T.outposts[B.key({}).top].product
local surface = f.hq.surface

--- Seuil de saturation de P d'après l'état du cerveau APRÈS la pensée (st.need est mis à jour avant le jugement, même table que s.need).
local function threshold(st, workers)
  local need = Dm.sat_need(Br.need_floor(workers, B.NEED_FLOOR), st.need and st.need[P], st.puits and st.puits.flow and st.puits.flow[P] or nil)
  return B.SAT_FACTOR * need
end

--- Une pensée du vrai cerveau au tick donné, sur la vraie vue dont le stock libre de P vaut `stock`.
local function think(tick, stock)
  local view = Team.view(f, tick)
  view.stock[P] = stock
  Ia3.active(f, tick)
  Ia3.plan(f, view, book, surface, tick)
  return f.team.ia3, view
end

local function logs_from(i0, pat)
  local out = {}
  for i = i0 + 1, #W().logs do
    local l = W().logs[i]
    if type(l) == "string" and l:find(pat, 1, true) then out[#out + 1] = l end
  end
  return out
end

--- Suite de pensées : stock(m) pour m = 0 .. n ; rend le relevé minute par minute.
local function run(stock_of, n, journal)
  local st0 = think(game.tick, stock_of(0)) -- échauffement : besoin et seuil
  st0.sat, st0.sat_said, st0.sat_lifted = nil, nil, nil
  local rows = {}
  local t0 = game.tick + MIN
  for m = 0, n do
    local tick = t0 + m * MIN
    local st, view = think(tick, stock_of(m))
    rows[m] = { thr = threshold(st, view.workers or 0), sat = st.saturated[P] == true, lifted = (st.sat_lifted or {})[P],
      drain = Sa.drain(st.sat, P), s = stock_of(m) }
    if journal then Ia3.sat_journal(f, st, tick) end
  end
  return rows
end

local THR
do
  local st, view = think(game.tick, 5000)
  THR = threshold(st, view.workers or 0)
end
say(string.format("plaque cle %s : seuil de saturation %d (besoin du cerveau, plancher, puits)", P, math.floor(THR + 0.5)))

local function scenes()
  -- §1 Fonte, puis arrêt de la fonte à la minute 12.
  local base = THR + 2000
  local function fonte(m) return base + 200 * (10 - math.min(m, 12)) end
  local i0 = #W().logs
  local rows = run(fonte, 24, true)
  local r10 = rows[Sa.WINDOW]
  check(r10.s >= r10.thr, string.format("§1 : minute %d, stock %d au-dessus du seuil %d (la regle d'avant le dit sature)", Sa.WINDOW, r10.s, math.floor(r10.thr)))
  check(not r10.sat and r10.lifted ~= nil and math.abs(r10.lifted - 200) <= 1,
    string.format("§1 : minute %d, fonte de 200/min mesuree : saturation LEVEE (sature %s, levee %s)", Sa.WINDOW, tostring(r10.sat), tostring(r10.lifted)))
  local early = true
  for m = 0, Sa.WINDOW - 1 do if not rows[m].sat or rows[m].lifted then early = false end end
  check(early, "§1 : avant " .. Sa.WINDOW .. " releves, aucune fonte n'est crue : sature comme avant")
  local back
  for m = 13, 24 do if rows[m].sat and not back then back = m end end
  check(back ~= nil, "§1 : le stock ne fond plus : la saturation revient (minute " .. tostring(back) .. ")")
  local lev = logs_from(i0, "[FO-SAT] " .. tostring(f.key) .. " : saturation de " .. P .. " LEVEE")
  local ren = logs_from(i0, "[FO-SAT] " .. tostring(f.key) .. " : saturation de " .. P .. " RENDUE")
  check(#lev == 1 and #ren == 1, string.format("§1 : journal [FO-SAT] : une ligne LEVEE, une ligne RENDUE (%d, %d)", #lev, #ren))
  if lev[1] then say(lev[1]) end
  if ren[1] then say(ren[1]) end
  -- §3 Stock qui monte.
  local rows3 = run(function(m) return base + 50 * m end, 14, false)
  local all = true
  for m = 0, 14 do if not rows3[m].sat or rows3[m].lifted then all = false end end
  check(all, "§3 : stock qui monte : sature de bout en bout, rien de leve")
  -- §4 État.
  local st = f.team.ia3
  local ok, n = true, 0
  for k, e in pairs(st.sat.items) do
    n = n + 1
    for _, v in pairs(e) do if type(v) ~= "number" then ok = false end end
  end
  check(ok and n >= 1, "§4 : st.sat : nombres seulement (" .. n .. " matieres suivies)")
end

scenes()

-- §2 Témoin sans mesure.
do
  local o = Sa.drains
  Sa.drains = function() return {} end
  local base = THR + 2000
  local rows = run(function(m) return base + 200 * (10 - m) end, Sa.WINDOW, false)
  Sa.drains = o
  check(rows[Sa.WINDOW].sat, "§2 : temoin sans mesure : la meme fonte reste saturee (regle d'avant)")
end

-- §5 Mutants de comportement.
do
  local p0, f0 = passes, failures
  local muts = {
    { "saturation qui ignore la pente", function() local o = B.saturated
      B.saturated = function(s, item, fo) local d = s.drain s.drain = nil local a, b = o(s, item, fo) s.drain = d return a, b end
      return function() B.saturated = o end end },
    { "releve sans pente (stock ignore)", function() local o = Sa.observe
      Sa.observe = function(state, tick, stock, items) return o(state, tick, {}, items) end
      return function() Sa.observe = o end end },
    { "journal muet", function() local o = Ia3.sat_journal Ia3.sat_journal = function() end return function() Ia3.sat_journal = o end end },
  }
  local killed = 0
  for _, m in ipairs(muts) do
    local restore = m[2]()
    local pp, ff = passes, failures
    quiet = true
    local ok, err = pcall(scenes)
    quiet = false
    restore()
    local dead = (not ok) or failures > ff
    passes, failures = pp, ff
    print(string.format("[SAT-CERVEAU]   mutant %s : %s", m[1], ok and (dead and "refuse" or "SURVIVANT") or ("PLANTAGE " .. tostring(err))))
    if dead then killed = killed + 1 end
  end
  passes, failures = p0, f0
  check(killed == #muts, string.format("§5 : mutants refuses %d / %d", killed, #muts))
end

print(string.format("[SAT-CERVEAU] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
