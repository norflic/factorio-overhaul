--[[
  Lot VIDEO L9, branchement : banc HORS JEU de la colle script/team/lots_minerai_glue.lua (règle shared/team/lot_minerai.lua) et du
  câblage de script/team/build.lua. Lancement, depuis la racine du mod : lua5.2 tests/lots_minerai_glue_test.lua
    1. diagnostic [FO-LOTS-MINERAI] : modules posés sur un lot de gisement par sorte, dont sans ressource (fabrique, énergie), projets
       refusés écartés, une ligne par équipe et par minute de jeu, compteurs de replis remis à zéro ;
    2. interrupteur ÉTEINT par défaut (réglage absent : le repli d'avant) ; allumé : une fabrique ne se replie plus sur un gisement,
       la fonte et l'extraction gardent leur repli ; un refus est compté ;
    3. câblage de build.lua (source) : champ Build.LotsMinerai, repli de try_place gardé par la règle, ligne par Build.think, aucune
       locale de plus au bloc principal ;
    4. mutants refusés.
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end
local SET = {}
_G.settings = { global = setmetatable({}, { __index = function(_, k)
  if SET[k] == nil then error("parametre inconnu : " .. k, 2) end
  return { value = SET[k] }
end }) }
local LOGS = {}
_G.log = function(s) LOGS[#LOGS + 1] = s end
local Lg0 = require("script.team.lots_minerai_glue")

local function team()
  local lots = { a = { state = "gisement" }, b = { state = "libre" }, c = { state = "gisement" } }
  local function pr(id, gen, lot, st, kind) return { id = id, state = st or "fini", spec = { gen = gen }, parts = { { kind = kind or "module", lot = lot } } } end
  return { key = "rouge", build = { order = { 1, 2, 3, 4, 5, 6, 7 }, lots = lots, projects = {
    [1] = pr(1, "patron", "a"), [2] = pr(2, "smelter", "c"), [3] = pr(3, "drills", "a"), [4] = pr(4, "labs", "b"),
    [5] = pr(5, "patron", "a", "refuse"), [6] = pr(6, "steam", "a", "chantier", "centrale"), [7] = { id = 7, state = "attente", spec = { gen = "patron" }, parts = {} },
  } } }
end

local function battery(Lg, verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 if verbose then print("  ECHEC : " .. msg) end end
    if verbose then check(c, msg) end
  end
  for k in pairs(SET) do SET[k] = nil end
  -- 1. diagnostic
  local f = team()
  local c = Lg.census(f)
  ck(c.by.fabrique == 1 and c.by.energie == 1 and c.by.fonte == 1 and c.by.extraction == 1, "par sorte : fabrique 1, energie 1, fonte 1, extraction 1")
  ck(c.sans == 2 and c.total == 5, "sans ressource 2 (chaine et centrale) sur 5 poses (refuse et sans lieu ecartes)")
  ck(table.concat(c.list, " ") == "1:patron 6:steam", "projets cites : " .. table.concat(c.list, " "))
  local n0 = #LOGS
  local line = Lg.minute(f, 3600)
  ck(line and line:find("[FO-LOTS-MINERAI] rouge", 1, true) and line:find("sans ressource 2", 1, true) and line:find("regle eteinte", 1, true),
    "ligne [FO-LOTS-MINERAI] : " .. tostring(line))
  ck(Lg.minute(f, 3600 + 3599) == nil and #LOGS == n0 + 1, "une ligne par minute de jeu au plus")
  -- 2. interrupteur
  local function has_ore(list) for _, st in ipairs(list) do if st.gisement then return true end end return false end
  local function first(list) return list[1] end
  ck(Lg.states(f, "patron") == Lg.LEGACY and Lg.states(f, "labs") == Lg.LEGACY, "reglage absent : eteint, le repli d'avant (libres, puis gisement)")
  SET[Lg.SETTING] = false
  ck(Lg.states(f, "patron") == Lg.LEGACY, "reglage eteint : le repli d'avant")
  SET[Lg.SETTING] = true
  ck(not has_ore(Lg.states(f, "patron")), "allume : une fabrique n'a plus de gisement (Lm.states_for)")
  local sm = Lg.states(f, "smelter")
  ck(first(sm).libre and has_ore(sm), "allume : la fonte essaie les libres, puis garde son repli sur le gisement")
  local dr = Lg.states(f, "drills")
  ck(#dr == 1 and dr[1].gisement, "allume : l'extraction ne va que sur un gisement")
  Lg.after(f, "smelter", { ok = true }, 2, sm[2])   -- fonderie posée sur un gisement au 2e essai : un repli
  Lg.after(f, "drills", { ok = true }, 1, dr[1])    -- foreuses sur un gisement au 1er essai : pas un repli
  Lg.after(f, "patron", nil, 1, nil)                -- fabrique sans lot libre : repli refusé par la règle
  Lg.after(f, "smelter", nil, 2, nil)               -- fonderie sans lot : pas un refus de la règle
  line = Lg.minute(f, 7200)
  ck(line and line:find("replis sur un gisement 1, replis refuses 1 (regle allumee)", 1, true), "replis et refus comptes : " .. tostring(line))
  line = Lg.minute(f, 10800)
  ck(line and line:find("replis sur un gisement 0, replis refuses 0", 1, true), "compteurs remis a zero a chaque ligne")
  for k in pairs(SET) do SET[k] = nil end
  return fails
end

print("[LOTS-MINERAI-GLUE] 1-2. diagnostic et interrupteur")
check(battery(Lg0, true) == 0, "batterie sans echec")

-- 3. câblage
print("[LOTS-MINERAI-GLUE] 3. cablage de build.lua")
local SRC = assert(io.open("script/team/build.lua", "rb")):read("*a")
check(SRC:find('Build.LotsMinerai = require("script.team.lots_minerai_glue")', 1, true) ~= nil, "Build.LotsMinerai requis au chargement (champ, pas une locale)")
local a = SRC:find("for i, states in ipairs(Build.LotsMinerai.states(f, gx.gen)) do", 1, true)
local g = SRC:find("m, w = place_module(f, surface, gx, states, toward, nil, fopts)", 1, true)
local h = SRC:find("Build.LotsMinerai.after(f, gx.gen, m, mi, ms)", 1, true)
check(a and g and h and a < g and g < h and h - a < 600, "try_place : les etats essayes viennent de la regle (Lm.states_for allumee, repli d'avant eteinte)")
check(not SRC:find("if not m then m, w = place_module(f, surface, gx, { gisement = true }", 1, true), "try_place : plus de repli sans condition")
local t1 = SRC:find("function Build.think(f, surface, tick)", 1, true)
local t2 = SRC:find("Build.LotsMinerai.minute(f, tick)", 1, true)
check(t1 and t2 and t2 > t1 and t2 - t1 < 400, "Build.think : une ligne [FO-LOTS-MINERAI] par minute")
do
  local cut
  for pos in SRC:gmatch("()\nreturn Build%s*$") do cut = pos end
  local head, tail = SRC:sub(1, cut), SRC:sub(cut + 1)
  local function ok_with(n)
    local t = {}
    for i = 1, n do t[i] = "local zz_" .. i .. " = nil" end
    return load(head .. table.concat(t, "\n") .. "\n" .. tail, "=x") ~= nil
  end
  local free = 0
  while free < 201 and ok_with(free + 1) do free = free + 1 end
  print(string.format("[LOTS-MINERAI-GLUE] build.lua : %d locales au bloc principal (encore %d)", 200 - free, free))
  check(200 - free <= 199, "aucune locale de plus au bloc principal de build.lua (199 au plus)")
end

-- 4. mutants
print("[LOTS-MINERAI-GLUE] 4. mutants")
local function mutant(name, patch)
  local saved = {}
  for k, v in pairs(Lg0) do saved[k] = v end
  patch(Lg0)
  local ok, fl = pcall(battery, Lg0, false)
  for k in pairs(Lg0) do Lg0[k] = saved[k] end
  check((not ok) or fl > 0, "mutant refuse : " .. name)
end
mutant("interrupteur allume par defaut", function(Lg) Lg.on = function() local ok, v = pcall(function() return settings.global[Lg.SETTING].value end) return (not ok) or v == true end end)
mutant("fabrique encore repliee regle allumee", function(Lg) Lg.states = function() return Lg.LEGACY end end)
mutant("refus jamais compte", function(Lg)
  local base = Lg.after
  Lg.after = function(f, gen, m, i, st) if m then return base(f, gen, m, i, st) end end
end)
mutant("fonderie comptee sans ressource", function(Lg)
  local base = Lg.kind
  Lg.kind = function(gen, plant) local k = base(gen, plant) if k == "fonte" then return "fabrique" end return k end
end)
mutant("une ligne a chaque appel", function(Lg)
  local base = Lg.minute
  Lg.minute = function(f, tick) if f.build and f.build.lm then f.build.lm.t = nil end return base(f, tick) end
end)
mutant("compteurs jamais remis a zero", function(Lg)
  local base = Lg.minute
  Lg.minute = function(f, tick)
    local st = f.build.lm or { repli = 0, refus = 0 }
    local r, s = st.repli, st.refus
    local line = base(f, tick)
    if line and f.build.lm then f.build.lm.repli, f.build.lm.refus = r, s end
    return line
  end
end)

print(string.format("[LOTS-MINERAI-GLUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
