--[[
  Lot ZERO-IDLE-3 : banc HORS JEU de la fonderie du QG agrandie par les PNJ SANS TÂCHE (shared/ai3/bras.lua, Br.smelters, entrée
  workers_idle ; shared/ai3/buts.lua, B.smelt_situation). Lancement : lua5.2 tests/fonte_libres_test.lua (depuis la racine du mod).

  Défaut mesuré (fo-logs/2026-11-09_ZERO-IDLE-3, scarlet, 8 PNJ) : 4 fours du QG de 8 à 40 min avec 105 à 131 minerais de fer au coffre, 74 à
  158 plaques manquantes et 1 à 4 PNJ libres. Trois seuils qui ne se composent pas : le minage à la main s'arrête à 100 minerais, la vague
  exige 2 fois le manque, la borne vaut 50 % de l'effectif (8 PNJ : 4). Règle : avec des PNJ sans tâche et un minerai qui couvre le manque
  (stock >= manque), la borne monte d'une vague (au plus le nombre de PNJ libres, Br.SMELT_STEP) jusqu'à Br.SMELT_HARD.
]]
package.path = "./?.lua;" .. package.path
local Br = require("shared.ai3.bras")
local B = require("shared.ai3.buts")
local T = require("shared.team.config")

Br.IDLE_SMELT_ON = true -- la regle est eteinte par defaut (shared/ai3/bras.lua) : ce banc l'allume
local passes, failures = 0, 0
local QUIET = false
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not QUIET then print("  ECHEC : " .. msg) end
  end
  return cond
end
local function section(name) if not QUIET then print("== " .. name) end end

local INPUTS = {}
do
  local ps = {}
  for p in pairs(T.smelter_inputs) do ps[#ps + 1] = p end
  table.sort(ps)
  for _, p in ipairs(ps) do INPUTS[#INPUTS + 1] = { p, T.smelter_inputs[p][1], T.smelter_inputs[p][2] } end
end
local IRON, IRON_ORE = "iron-plate", T.smelter_inputs["iron-plate"][1]
local COPPER, COPPER_ORE = "copper-plate", T.smelter_inputs["copper-plate"][1]

local function sit(ore, smelters, tick, idle, covered, workers)
  return { workers = workers or 8, stock = ore, smelters = smelters, smelters_pending = 0, tick = tick or 0,
    smelter_inputs = INPUTS, covered = covered, workers_idle = idle }
end
local function st_short(n, k) return { short = { [IRON] = n }, short_n = { [IRON] = k or 9 } } end

section("1. le cas mesure : 8 PNJ, 131 minerais, 75 plaques manquantes")
do
  local ore = { [IRON_ORE] = 131 }
  local n = Br.smelters(sit(ore, 4, 0, 0), st_short(75), 4, 6)
  check(n == 4, "aucun PNJ libre : la fonderie reste a 4 (la regle d'avant), " .. n)
  n = Br.smelters(sit(ore, 4, 0, nil), st_short(75), 4, 6)
  check(n == 4, "workers_idle absent : 4, " .. n)
  n = Br.smelters(sit(ore, 4, 0, 3), st_short(75), 4, 6)
  check(n == 6, "3 PNJ libres : une vague (4 -> 6), " .. n)
  n = Br.smelters(sit(ore, 4, 0, 1), st_short(75), 4, 6)
  check(n == 5, "1 PNJ libre : un four de plus (4 -> 5), " .. n)
  -- le manque de 158 : le minerai 131 ne le couvre pas, la regle ne dit rien
  n = Br.smelters(sit(ore, 4, 0, 3), st_short(158), 4, 6)
  check(n == 4, "minerai 131 < manque 158 : rien de plus (le minerai manque, c'est au minage), " .. n)
  -- manque trop recent
  n = Br.smelters(sit(ore, 4, 0, 3), st_short(75, 2), 4, 6)
  check(n == 4, "manque de moins de grow_thinks pensees : rien, " .. n)
end

section("2. une vague par minute, bornee par Br.SMELT_HARD")
do
  local ore = { [IRON_ORE] = 500 }
  local st = st_short(300)
  local cur = 4
  local trace = {}
  for i = 0, 12 do
    cur = Br.smelters(sit(ore, cur, 3600 * i, 5), st, 4, 6)
    trace[#trace + 1] = cur
  end
  check(cur == Br.SMELT_HARD, "la fonderie monte jusqu'a Br.SMELT_HARD = " .. Br.SMELT_HARD .. " (" .. table.concat(trace, " ") .. ")")
  local steps_ok = true
  local prev = 4
  for _, v in ipairs(trace) do
    if v - prev > Br.SMELT_STEP then steps_ok = false end
    prev = v
  end
  check(steps_ok and trace[1] == 6, "une vague (Br.SMELT_STEP fours) par minute au plus (" .. table.concat(trace, " ") .. ")")
  -- deux pensees dans la meme minute : une seule vague
  local st_b = st_short(300)
  local a = Br.smelters(sit(ore, 4, 0, 5), st_b, 4, 6)
  local b = Br.smelters(sit(ore, a, 600, 5), st_b, 4, 6)
  check(a == 6 and b == 6, "deux pensees dans la meme minute : une seule vague (" .. a .. ", " .. b .. ")")
end

section("3. plaque couverte par une ligne : la borne de l'automatisation reste")
do
  local ore = { [IRON_ORE] = 500 }
  local st = st_short(75)
  local n = Br.smelters(sit(ore, 4, 0, 4, { [IRON] = true }), st, 4, 6)
  check(n == 4 and st.fq ~= nil and st.fq.cap == 4, "fer fondu par une ligne : 4, borne 4, " .. n)
  local st2 = { short = { [IRON] = 75, [COPPER] = 75 }, short_n = { [IRON] = 9, [COPPER] = 9 } }
  local both = { [IRON_ORE] = 500, [COPPER_ORE] = 500 }
  n = Br.smelters(sit(both, 4, 0, 4, { [IRON] = true }), st2, 4, 6)
  check(n == 6, "cuivre non couvert : une vague (4 -> 6), " .. n)
end

section("4. la situation du cerveau transmet les PNJ libres")
do
  local s = B.smelt_situation({ workers = 8, stock = {}, smelters = 4, smelters_pending = 0, tick = 0, workers_idle = 3 }, {})
  check(s.workers_idle == 3, "B.smelt_situation transmet workers_idle")
  -- 30 PNJ, minerai en abondance, sans PNJ libre : le comportement d'avant (tests/fonderie_qg_test.lua)
  local st = { short = { [IRON] = 200 }, short_n = { [IRON] = 9 } }
  local n = Br.smelters({ workers = 30, stock = { [IRON_ORE] = 1000 }, smelters = 4, smelters_pending = 0, tick = 0, smelter_inputs = INPUTS }, st, 4, 6)
  check(n == 6, "30 PNJ sans PNJ libre : une vague comme avant, " .. n)
end

section("5. determinisme et cout")
do
  local function run()
    local out = {}
    local st = st_short(300)
    local cur = 4
    for i = 0, 8 do
      cur = Br.smelters(sit({ [IRON_ORE] = 400 }, cur, 3600 * i, i % 4), st, 4, 6)
      out[#out + 1] = cur
    end
    return table.concat(out, ",")
  end
  check(run() == run(), "deux passages identiques")
  local count = 0
  local st = st_short(300)
  debug.sethook(function() count = count + 1 end, "", 1000)
  for i = 1, 100 do Br.smelters(sit({ [IRON_ORE] = 400, [COPPER_ORE] = 400 }, 6, 3600 * i, 5), st, 4, 6) end
  debug.sethook()
  local per = count * 1000 / 100
  check(per < 100000, string.format("moins de 100 000 instructions par appel (mesure : %d)", per))
  if not QUIET then print(string.format("  cout : %d instructions Lua par appel", per)) end
end

local function body()
  QUIET = true
  local f0 = failures
  local ore = { [IRON_ORE] = 131 }
  check(Br.smelters(sit(ore, 4, 0, 0), st_short(75), 4, 6) == 4, "m1 sans PNJ libre")
  check(Br.smelters(sit(ore, 4, 0, 3), st_short(75), 4, 6) == 6, "m2 avec PNJ libres")
  check(Br.smelters(sit(ore, 4, 0, 1), st_short(75), 4, 6) == 5, "m3 un PNJ, un four")
  check(Br.smelters(sit(ore, 4, 0, 3), st_short(158), 4, 6) == 4, "m4 minerai < manque")
  check(Br.smelters(sit(ore, 4, 0, 3), st_short(75, 2), 4, 6) == 4, "m5 manque recent")
  local st = { short = { [IRON] = 75 }, short_n = { [IRON] = 9 } }
  check(Br.smelters(sit({ [IRON_ORE] = 500 }, 4, 0, 4, { [IRON] = true }), st, 4, 6) == 4, "m6 couverte")
  local cur = 4
  local s2 = st_short(300)
  for i = 0, 12 do cur = Br.smelters(sit({ [IRON_ORE] = 500 }, cur, 3600 * i, 5), s2, 4, 6) end
  check(cur == Br.SMELT_HARD, "m7 plafond")
  QUIET = false
  return failures - f0
end

section("6. mutants")
do
  local f = io.open("shared/ai3/bras.lua", "rb")
  local src = f:read("*a")
  f:close()
  local mutants = {
    { "regle toujours eteinte", "local idle = Br.IDLE_SMELT_ON and math.max(0, s.workers_idle or 0) or 0", "local idle = 0" },
    { "pas de plafond", "max = math.max(max, math.min(Br.SMELT_HARD, have + math.min(idle, Br.SMELT_STEP)))", "max = max + idle * 100" },
    { "seuil de vague toujours double", "(idle > 0 and 1 or Br.ORE_WAIT) * short * per", "Br.ORE_WAIT * short * per" },
  }
  for _, m in ipairs(mutants) do
    local a, b = src:find(m[2], 1, true)
    if not a then
      check(false, "mutant '" .. m[1] .. "' : motif introuvable")
    else
      local chunk, err = load(src:sub(1, a - 1) .. m[3] .. src:sub(b + 1), "=mut", "t")
      if not chunk then
        check(false, "mutant '" .. m[1] .. "' : " .. tostring(err))
      else
        local saved = Br
        local ok, Bm = pcall(chunk)
        if ok then Bm.IDLE_SMELT_ON = true end -- (la copie mutee reprend le defaut eteint du module)
        if not ok then
          check(false, "mutant '" .. m[1] .. "' ne charge pas : " .. tostring(Bm))
        else
          Br = Bm
          local p0, f0 = passes, failures
          local okb, nfail = pcall(body)
          passes, failures = p0, f0
          Br = saved
          QUIET = false
          check((not okb) or nfail > 0, "mutant detecte : " .. m[1])
        end
      end
    end
  end
end

print(string.format("[FONTE-LIBRES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
