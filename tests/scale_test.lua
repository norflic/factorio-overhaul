--[[
  Lot SCALE « passage à l'échelle » : test hors jeu du travail des bras libres (shared/ai3/bras.lua) et de son
  branchement dans les générateurs de buts (shared/ai3/buts.lua).
    §1 bornes qui suivent l'effectif : à 8 PNJ, les bornes d'avant (5 capacités, 4 fours, 3 recherches, 3 laboratoires) ;
       à 30 PNJ, plus hautes ;
    §2 vagues d'extraction d'avance : une capacité par 3 bras libres, une par ressource, ressource saturée sautée ;
    §3 fonte : des fours de plus quand une plaque manque durablement ET que son minerai attend au coffre ; rien si le
       minerai manque aussi (le goulot est alors l'extraction), rien avant que les fours visés soient posés, rythme ;
    §4 armée selon le caractère ; §5 fenêtre des laboratoires ;
    §6 mutants : chaque règle retirée est vue ;
    §7 déterminisme (même entrée, même sortie) et aucun nom du jeu (règle anti-échelle d'IA-G, tests/iag_test.lua §8).
  Usage : lua5.2 tests/scale_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local R = require("shared.ai3.reglages")

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/ai3/bras.lua")

local function load_br(src)
  local fn, err = load(src, "=bras", "t")
  if not fn then return nil, err end
  local ok, mod = pcall(fn)
  if not ok then return nil, mod end
  package.loaded["shared.ai3.bras"] = mod
  package.loaded["shared.ai3.buts"] = nil
  local B = require("shared.ai3.buts")
  return mod, B
end

local IRON, ORE = T.outposts.iron.product, T.outposts.iron.resource
local COPPER = T.outposts.copper.product

local function suite(Br, B)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end
  -- §1 Bornes.
  check(Br.cap_max(8, 5) == 5 and Br.cap_max(30, 5) == 6, "§1 capacités au plus : 5 à 8 PNJ, 6 à 30 (" .. Br.cap_max(30, 5) .. ")")
  check(Br.smelt_max(8, 4) == 4 and Br.smelt_max(30, 4) == 15, "§1 fours au plus : 4 à 8 PNJ, 15 à 30 (" .. Br.smelt_max(30, 4) .. ")")
  check(Br.depth_max(8, 3) == 3 and Br.depth_max(30, 3) == 5, "§1 recherches d'avance au plus : 3 à 8, 5 à 30")
  check(Br.labs_max(8, 3) == 3 and Br.labs_max(30, 3) == 6, "§1 laboratoires au plus : 3 à 8, 6 à 30")
  check(Br.need_floor(8, 100) == 100 and Br.need_floor(30, 100) == 375 and Br.need_floor(nil, 100) == 100,
    "§1 plancher du besoin : 100 à 8 PNJ, 375 à 30 (" .. Br.need_floor(30, 100) .. ")")
  check(B.saturated({ workers = 8, stock = { [IRON] = 400 }, need = {} }, IRON)
    and not B.saturated({ workers = 30, stock = { [IRON] = 400 }, need = {} }, IRON),
    "§1 400 plaques : saturé à 8 PNJ, pas à 30")
  check(Br.smooth(nil, 9) == 90 and Br.smooth(90, 0) == 83 and Br.smooth(0, 9) == 7 and Br.smooth(85, 9) == 86,
    "§0 moyenne glissante des PNJ sans tâche (dixièmes) : " .. Br.smooth(90, 0) .. ", " .. Br.smooth(0, 9))
  -- §2 Vagues d'extraction.
  check(Br.wave(0) == 0 and Br.wave(1) == 1 and Br.wave(3) == 1 and Br.wave(4) == 2 and Br.wave(30) == 3,
    "§2 vague : 1 capacité par 3 bras libres, au plus 3 (" .. Br.wave(4) .. ", " .. Br.wave(30) .. ")")
  local function sit(spare, tick, sat_top, workers)
    return { key = R.FALLBACK_KEY, idle_grow = true, spare = spare, tick = tick, workers = workers or 30,
      cap = { iron = 2, coal = 2, copper = 1, stone = 1 },
      stock = { [IRON] = sat_top and 10000 or 0 }, need = {} }
  end
  local st = { targets = { iron = 2, coal = 2, copper = 1, stone = 1 }, iron2_set = true }
  B.targets(sit(9, 0, false), st)
  check(st.targets.iron == 3 and st.targets.copper == 2, "§2 9 bras libres : fer ET cuivre d'avance (" .. st.targets.iron
    .. ", " .. st.targets.copper .. ")")
  local st1 = { targets = { iron = 2, coal = 2, copper = 1, stone = 1 }, iron2_set = true }
  B.targets(sit(2, 0, false), st1)
  check(st1.targets.iron == 3 and st1.targets.copper == 1, "§2 2 bras libres : une seule capacité")
  local st2 = { targets = { iron = 2, coal = 2, copper = 1, stone = 1 }, iron2_set = true }
  B.targets(sit(9, 0, true), st2)
  check(st2.targets.iron == 2 and st2.targets.copper == 2, "§2 fer saturé : sauté, cuivre seul")
  local st3 = { targets = { iron = 6, coal = 2, copper = 1, stone = 1 }, iron2_set = true }
  local s3 = sit(9, 0, false)
  s3.cap.iron = 6
  B.targets(s3, st3)
  check(st3.targets.iron == 6, "§2 borne de l'effectif tenue (6 capacités à 30 PNJ)")
  local st4 = { targets = { iron = 5, coal = 2, copper = 1, stone = 1 }, iron2_set = true }
  local s4 = sit(9, 0, false, 8)
  s4.cap.iron = 5
  B.targets(s4, st4)
  check(st4.targets.iron == 5, "§2 à 8 PNJ, la borne d'avant (5)")
  -- §3 Fonte.
  local inputs = { { IRON, ORE, 1 } }
  local function fs(ore, smelters, tick)
    return { workers = 30, stock = { [ORE] = ore }, smelters = smelters, smelters_pending = 0, tick = tick or 0,
      smelter_inputs = inputs }
  end
  local sst = { short = { [IRON] = 60 }, short_n = { [IRON] = 6 } }
  local n = Br.smelters(fs(500, 4), sst, 4, 6)
  check(n == 6, "§3 plaque en manque, minerai au coffre : 2 fours de plus (" .. n .. ")")
  n = Br.smelters(fs(500, 4, 3600), sst, 4, 6)
  check(n == 6, "§3 fours visés pas encore posés (4 sur 6) : pas de nouvelle vague")
  n = Br.smelters(fs(500, 6, 600), sst, 4, 6)
  check(n == 6, "§3 au plus une vague par minute")
  n = Br.smelters(fs(500, 6, 3600), sst, 4, 6)
  check(n == 8, "§3 vague suivante après une minute (" .. n .. ")")
  local sst2 = { short = { [IRON] = 60 }, short_n = { [IRON] = 6 } }
  n = Br.smelters(fs(50, 4), sst2, 4, 6)
  check(n == 4, "§3 minerai qui manque aussi : pas de fours (le goulot est l'extraction)")
  local sst3 = { short = { [IRON] = 60 }, short_n = { [IRON] = 2 } }
  n = Br.smelters(fs(500, 4), sst3, 4, 6)
  check(n == 4, "§3 manque passager (2 pensées) : pas de fours")
  local sst4 = { short = {}, short_n = {} }
  n = Br.smelters(fs(5000, 4), sst4, 4, 6)
  check(n == 4, "§3 aucune plaque en manque : pas de fours")
  local sst6 = { short = { [IRON] = 60 }, short_n = { [IRON] = 6 } }
  n = Br.smelters(fs(500, 8), sst6, 4, 6)
  check(n == 10, "§3 8 fours déjà posés (amorçage) : la vague part de 8 (" .. n .. ")")
  local sst5 = { short = { [IRON] = 60 }, short_n = { [IRON] = 6 }, smelt_target = 15 }
  n = Br.smelters(fs(500, 15), sst5, 4, 6)
  check(n == 15, "§3 borne de l'effectif (15 fours à 30 PNJ)")
  -- Branchement : la famille capital demande les fours visés (faction), votre équipe garde 2.
  local gst = { targets = { iron = 1, coal = 1, copper = 1, stone = 0 }, short = { [IRON] = 60 }, short_n = { [IRON] = 6 } }
  local gs = { key = R.FALLBACK_KEY, tick = 0, workers = 30, cap = { iron = 1, coal = 1, copper = 1 }, pending = {},
    stock = { [ORE] = 500 }, smelters = 4, smelters_pending = 0, need = {}, weights = {} }
  local goals = B.generate(gs, gst)
  local fonderie
  for _, g in ipairs(goals) do if g.key == "capital:fonderie" then fonderie = g end end
  check(fonderie ~= nil and fonderie.n == 2, "§3 but « capital:fonderie » de 2 fours ouvert (" .. tostring(fonderie and fonderie.n) .. ")")
  gs.is_player = true
  local gst2 = { targets = { iron = 1, coal = 1, copper = 1, stone = 0 }, short = { [IRON] = 60 }, short_n = { [IRON] = 6 } }
  local goals2 = B.generate(gs, gst2)
  local f2
  for _, g in ipairs(goals2) do if g.key == "capital:fonderie" then f2 = g end end
  check(f2 == nil, "§3 votre équipe : fonderie inchangée (2 fours, déjà dépassés)")
  -- §4 Armée selon le caractère.
  check(Br.army(60, 100, 1400, 6, false) == 74, "§4 agressivité 1 400 : + 14 soldats sur 100 (" .. Br.army(60, 100, 1400, 6, false) .. ")")
  check(Br.army(60, 100, 600, 6, false) == 66, "§4 faction peu agressive (600) : + 6 seulement")
  check(Br.army(60, 100, 1400, 0, false) == 60, "§4 sans bras libres : cible du chef")
  check(Br.army(60, 100, 1400, 6, true) == 60, "§4 matière clé en manque : cible du chef")
  check(Br.army(98, 100, 2000, 6, false) == 100, "§4 jamais au-delà du plafond")
  -- §5 Laboratoires.
  check(Br.lab_window(600, 0) == 600 and Br.lab_window(600, 3) == 300 and Br.lab_window(600, 30) == 150,
    "§5 fenêtre : 600 s sans bras libres, 300 s à 3, 150 s au plus court (" .. Br.lab_window(600, 3) .. ")")
  -- §7 Déterminisme.
  local a = { targets = { iron = 2, coal = 2, copper = 1, stone = 1 }, iron2_set = true }
  local b = { targets = { iron = 2, coal = 2, copper = 1, stone = 1 }, iron2_set = true }
  B.targets(sit(9, 0, false), a)
  B.targets(sit(9, 0, false), b)
  check(a.targets.iron == b.targets.iron and a.targets.copper == b.targets.copper and a.targets.stone == b.targets.stone,
    "§7 même entrée, même vague")
  return pass, fail, msgs
end

local Br, B = load_br(SRC)
local pass, fail, msgs = suite(Br, B)
for _, m in ipairs(msgs) do print("[SCALE] ECHEC : " .. m) end

-- §7 Aucun nom du jeu, aucun pairs, aucun hasard dans le module.
local names = {}
for _, kind in ipairs(T.OUTPOST_ORDER) do
  names[#names + 1] = T.outposts[kind].product
  names[#names + 1] = T.outposts[kind].resource
end
for _, p in ipairs({ T.SMELTER, T.DRILL, T.turret_ammo }) do names[#names + 1] = p end
local hits = {}
for _, n in ipairs(names) do if SRC:find('"' .. n .. '"', 1, true) then hits[#hits + 1] = n end end
if #hits == 0 then pass = pass + 1 else fail = fail + 1 print("[SCALE] ECHEC : noms du jeu : " .. table.concat(hits, " ")) end
local code = SRC:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
if not code:find("[^i]pairs%(") and not code:find("math.random", 1, true) then pass = pass + 1 else
  fail = fail + 1
  print("[SCALE] ECHEC : pairs() ou math.random dans le module")
end

-- §6 Mutants.
local MUTANTS = {
  { "borne des capacités fixe", "function Br.cap_max(workers, floor) return math.max(floor or 0, pct(workers, Br.CAP_PCT)) end",
    "function Br.cap_max(workers, floor) return floor or 0 end" },
  { "borne des fours fixe", "function Br.smelt_max(workers, floor) return math.max(floor or 0, pct(workers, Br.SMELT_PCT)) end",
    "function Br.smelt_max(workers, floor) return floor or 0 end" },
  { "vague d'une capacité", "return clamp(math.floor((spare + Br.HANDS_PER_CAP - 1) / Br.HANDS_PER_CAP), 1, Br.WAVE_MAX)",
    "return 1" },
  { "fours sans minerai au coffre", "(s.stock[ore] or 0) >= Br.ORE_WAIT * short * per", "true" },
  { "fours sur manque passager", "n >= (grow_thinks or 0)", "true" },
  { "fours avant la pose des précédents", "if due and have >= target and target < max then", "if due and target < max then" },
  { "fours posés ignorés", "local target = math.max(base or 0, st.smelt_target or 0, have)",
    "local target = math.max(base or 0, st.smelt_target or 0)" },
  { "fours sans rythme", "local due = (s.tick or 0) - (st.smelt_tick or -Br.SMELT_EVERY) >= Br.SMELT_EVERY", "local due = true" },
  { "armée sans caractère", "local a = agressivite or 1000", "local a = 1000" },
  { "armée malgré le manque", "if (spare or 0) <= 0 or key_short then return target end", "if (spare or 0) <= 0 then return target end" },
  { "armée au-delà du plafond", "return math.min(soldiers_max or 0, target + add)", "return target + add" },
  { "plancher du besoin fixe", "return math.max(floor or 0, math.floor((floor or 0) * (workers or 0) / Br.REF_WORKERS))",
    "return floor or 0" },
  { "bras libres non lissés", "return prev + step", "return x" },
  { "fenêtre des laboratoires fixe", "local w = math.floor((window or 0) * Br.HANDS_PER_CAP / (Br.HANDS_PER_CAP + math.max(0, spare or 0)))",
    "local w = window or 0" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else
    local msrc = SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1)
    local mb, mB = load_br(msrc)
    local f2 = 1
    if mb then
      local ok, _, ff = pcall(suite, mb, mB)
      f2 = ok and ff or 1
    end
    if f2 > 0 then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
load_br(SRC)
if #kept == 0 then pass = pass + 1 else
  fail = fail + 1
  print("[SCALE] ECHEC : mutants NON refusés : " .. table.concat(kept, " ; "))
end
print(string.format("[SCALE] mutants refusés : %d sur %d", refused, #MUTANTS))
print(string.format("[SCALE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
