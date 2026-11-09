--[[
  Lot REINVESTIR-FER : banc HORS JEU. Lancement, depuis la racine du mod : lua5.2 tests/reinvestir_test.lua
    1. règle pure Rv.decide : le fer manque, tout tourne, remboursement court, garde-fous (menace, avant-poste tombé, borne, rythme) ;
    2. B.targets : la cible du fer monte sans attendre 6 pensées ; ne monte pas quand le fer ne manque pas, quand une foreuse est à sec, quand
       un avant-poste est tombé, quand l'équipe est menacée ;
    3. mutants.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local passes, failures = 0, 0
local function check(cond, msg) if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end return cond end
local function read_src(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end
local PRODUCT = T.outposts.iron.product

local function load_world(over)
  over = over or {}
  local names = { "shared.ai3.reinvestir", "shared.ai3.buts" }
  local keys = { "Rv", "B" }
  local saved = {}
  for _, n in ipairs(names) do saved[n] = package.loaded[n]; package.loaded[n] = nil end
  local W = {}
  for i, n in ipairs(names) do
    local k = keys[i]
    if over[k] then package.loaded[n] = assert(load(over[k], "@" .. n))() else package.loaded[n] = require(n) end
    W[k] = package.loaded[n]
  end
  for _, n in ipairs(names) do package.loaded[n] = saved[n] end
  return W
end

local OK = { have = 20, floor = 100, tg = 2, cap = 2, pending = 0, max = 5, outs = { { drills = 8 }, { drills = 8 } }, maxcap = 2, cost = 152,
  drills = 8, threatened = false, undefended = 0, tick = 10000, last = nil }
local function with(over) local a = {} for k, v in pairs(OK) do a[k] = v end for k, v in pairs(over or {}) do a[k] = v end return a end

local function facts(W)
  local Rv, B = W.Rv, W.B
  local f = {}
  local function dec(over) local ok = Rv.decide(with(over)) return ok and 1 or 0 end
  f.ok = dec()
  f.no_short = dec({ have = 100 })
  f.pending = dec({ pending = 1 })
  f.unbuilt = dec({ cap = 1.5, maxcap = 1.5 })
  f.fallen = dec({ cap = 1, tg = 1, maxcap = 2 })
  f.threat = dec({ threatened = true })
  f.undef = dec({ undefended = 1 })
  f.dry = dec({ outs = { { drills = 8, dry = 1 } } })
  f.stuck = dec({ outs = { { drills = 8, stuck = 2 } } })
  f.fuel = dec({ outs = { { drills = 8, fuel_low = true } } })
  f.unsafe = dec({ outs = { { drills = 8, unsafe = true } } })
  f.lethal = dec({ outs = { { drills = 8, lethal = true } } })
  f.protect = dec({ outs = { { drills = 8, protect = true } } })
  f.pay_long = dec({ cost = 2000 })
  f.bound = dec({ tg = 4, cap = 4, maxcap = 4 })
  f.limit = dec({ tg = 2, max = 2 })
  f.soon = dec({ last = 9000 })
  f.late = dec({ last = 5000 })
  f.none = dec({ outs = {} })
  -- B.targets
  local function s_of(over)
    local s = { is_player = true, workers = 8, stock = { [PRODUCT] = 20 }, cap = { iron = 2, coal = 2, copper = 1, stone = 1 }, pending = {},
      threatened = false, undef_n = 0, tick = 10000, out_state = { iron = { { drills = 8 }, { drills = 8 } } },
      reinvest_cost = { iron = 152, coal = 70, copper = 60, stone = 40 }, weights = B.weights({}, nil), need = {} }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
  end
  local function tgt(over, st0)
    local st = st0 or { targets = { iron = 2, coal = 2, copper = 1, stone = 1 }, iron2_set = true }
    B.targets(s_of(over), st)
    return st.targets.iron, st
  end
  f.t_up = tgt()
  f.t_nofer = tgt({ stock = { [PRODUCT] = 500 } })
  f.t_dry = tgt({ out_state = { iron = { { drills = 8, dry = 3 }, { drills = 8 } } } })
  f.t_threat = tgt({ threatened = true })
  f.t_fallen = tgt({ cap = { iron = 1, coal = 2, copper = 1, stone = 1 } }, { targets = { iron = 1, coal = 2, copper = 1, stone = 1 }, iron2_set = true,
    reinv = { maxcap = 2 } })
  local t1, st1 = tgt()
  local t2 = tgt({ tick = 10100 }, st1)
  f.t_spacing = t2
  f.t_log = st1.reinv and st1.reinv.n or 0
  return f
end

local W0 = load_world()
local F0 = facts(W0)
print("== 1. Rv.decide")
check(F0.ok == 1, "le fer manque, tout tourne, remboursement court : la cible monte")
check(F0.no_short == 0 and F0.pending == 0 and F0.unbuilt == 0, "fer en stock, avant-poste en cours, capacité visée pas posée : non")
check(F0.fallen == 0, "un avant-poste est tombé (capacité sous la plus grande vue) : non")
check(F0.threat == 0 and F0.undef == 0, "équipe menacée ou avant-poste sans tourelles : non")
check(F0.dry == 0 and F0.stuck == 0 and F0.fuel == 0, "brûleur à sec, réceptacle plein ou combustible bas : non")
check(F0.unsafe == 0 and F0.lethal == 0 and F0.protect == 0 and F0.none == 0, "site dangereux, PNJ mort, à protéger, aucun avant-poste : non")
check(F0.pay_long == 0, "remboursement plus long que l'horizon : non")
check(F0.bound == 0 and F0.limit == 0, "borne Rv.MAX et borne de l'appelant : non")
check(F0.soon == 0 and F0.late == 1, "au plus une hausse par Rv.EVERY ticks")
print("== 2. B.targets")
check(F0.t_up == 3, "cible du fer 2 -> 3 sans attendre le manque durable (" .. tostring(F0.t_up) .. ")")
check(F0.t_nofer == 2 and F0.t_dry == 2 and F0.t_threat == 2 and F0.t_fallen == 1, "fer en stock, foreuse à sec, menace, avant-poste tombé : la cible ne monte pas")
check(F0.t_spacing == 3 and F0.t_log == 1, "pas de seconde hausse à 100 ticks d'écart ; une hausse comptée au journal")

print("== 3. Mutants")
local killed, total = 0, 0
local function mutant(name, which, from, to)
  total = total + 1
  local path = which == "Rv" and "shared/ai3/reinvestir.lua" or "shared/ai3/buts.lua"
  local src = read_src(path)
  local i, j = src:find(from, 1, true)
  if not i then check(false, "mutant '" .. name .. "' : texte introuvable") return end
  local ok, F = pcall(facts, load_world({ [which] = src:sub(1, i - 1) .. to .. src:sub(j + 1) }))
  local changed = not ok
  if ok then for k, v in pairs(F0) do if F[k] ~= v then changed = true end end end
  if check(changed, "mutant refusé : " .. name) then killed = killed + 1 end
end
mutant("le fer n'a pas besoin de manquer", "Rv", "if (a.have or 0) >= (a.floor or 0) then", "if false then")
mutant("avant-poste en cours ignoré", "Rv", "if (a.pending or 0) > 0 then", "if false then")
mutant("capacité visée non posée ignorée", "Rv", "if cap + 1e-9 < tg then", "if false then")
mutant("avant-poste tombé ignoré", "Rv", "if cap + 1e-9 < (a.maxcap or 0) then", "if false then")
mutant("menace ignorée", "Rv", "if a.threatened or (a.undefended or 0) > 0 then", "if false then")
mutant("brûleur à sec ignoré", "Rv", "if (o.dry or 0) > 0 or (o.stuck or 0) > 0 or o.fuel_low then", "if false then")
mutant("site dangereux ignoré", "Rv", "if o.unsafe or o.lethal or o.protect then", "if false then")
mutant("remboursement ignoré", "Rv", "if rate <= 0 or (a.cost or math.huge) / rate > Rv.HORIZON_MIN then", "if false then")
mutant("borne ignorée", "Rv", "if tg >= limit then", "if false then")
mutant("rythme ignoré", "Rv", "if a.last ~= nil and (a.tick or 0) - a.last < Rv.EVERY then", "if false then")
mutant("B.targets n'appelle plus la règle", "B", "local up, why = Rv.decide(", "local up, why = (function() return false end)(")
mutant("B.targets ne lit pas l'état des avant-postes", "B", "outs = (s.out_state or {})[top]", "outs = { { drills = 8 } }")
print(string.format("   mutants refusés : %d / %d", killed, total))
check(killed == total, "tous les mutants refusés")
print(string.format("[REINVESTIR-FER] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, total))
os.exit(failures == 0 and 0 or 1)
