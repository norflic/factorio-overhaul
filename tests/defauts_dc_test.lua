--[[
  Lot DEFAUTS-DC (9/11, QCM du DC de 12 h 10) : la partie du DC aux réglages PAR DÉFAUT du mod. Hors jeu, Lua pur.
    D1. réglages livrés : guerre cochée (fo-war-autostart), difficulté Normal, kit généreux des bancs éteint, 30 ouvriers, 2 factions ;
    D2. stock de départ du coffre d'office (shared/team/depart_coffre.lua) : exactement celui de verif_guide_common.lua (8d1d4ba3, 76-83) ;
    D3. règle D.stock_due : garni seulement s'il est posé d'office et pas déjà garni ; copie défensive ;
    D4. le banc de la partie du guide LIT ces défauts au lieu de les écrire (verif_guide_common.lua), et n'écrit plus le réglage inexistant
        fo-war-ia3-recherche (ia3d_common.lua) ;
    D5. mutants : chaque règle faussée est vue par au moins un contrôle.
  Usage : lua5.2 tests/defauts_dc_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

-- D1. Réglages livrés (settings.lua chargé avec un data:extend de bouchon)
local DEF = {}
data = { extend = function(_, t) for _, s in ipairs(t) do DEF[s.name] = s end end }
dofile("settings.lua")
check(DEF["fo-war-autostart"] and DEF["fo-war-autostart"].default_value == true, "D1 fo-war-autostart coché par défaut")
check(DEF["fo-pvp-difficulty"] and DEF["fo-pvp-difficulty"].default_value == "normal", "D1 difficulté Normal par défaut")
check(DEF["fo-war-kit-genereux"] and DEF["fo-war-kit-genereux"].default_value == false, "D1 kit généreux (bancs) éteint par défaut")
check(DEF["fo-war-workers"] and DEF["fo-war-workers"].default_value == 30, "D1 30 ouvriers par défaut")
check(DEF["fo-war-factions"] and DEF["fo-war-factions"].default_value == 2, "D1 2 factions par défaut")
check(DEF["fo-war-soldiers"] and DEF["fo-war-soldiers"].default_value == 30, "D1 30 soldats par défaut")

-- D2. Stock de départ
local function load_dc(src)
  local fn = assert(load(src, "depart_coffre", "t", setmetatable({}, { __index = _G })))
  return fn()
end
local SRC = read("shared/team/depart_coffre.lua")
local DC = load_dc(SRC)
local want = { ["iron-plate"] = 400, ["copper-plate"] = 100, ["coal"] = 200, ["stone"] = 100, ["pistol"] = 3,
  ["firearm-magazine"] = 60, ["burner-mining-drill"] = 8, ["stone-furnace"] = 8, ["iron-chest"] = 4 }
local got, n = {}, 0
for _, it in ipairs(DC.CONTENTS) do got[it[1]] = (got[it[1]] or 0) + it[2]; n = n + 1 end
local same = n == 9
for k, v in pairs(want) do if got[k] ~= v then same = false end end
check(same, "D2 stock de départ : 9 objets, quantités du guide (400 fer, 100 cuivre, 200 charbon, 100 pierre, 3 pistolets, 60 chargeurs, 8 foreuses, 8 fours, 4 coffres)")

-- D3. Règle
check(select(1, DC.stock_due({ founded_by_default = true, garni = false })) == true, "D3 coffre d'office pas encore garni : garni")
check(select(1, DC.stock_due({ founded_by_default = true, garni = true })) == false, "D3 déjà garni : jamais deux fois")
check(select(1, DC.stock_due({ founded_by_default = false, garni = false })) == false, "D3 coffre fondé par le joueur : jamais garni")
local cp = DC.items()
cp[1][2] = 1
check(DC.CONTENTS[1][2] == 400, "D3 items() rend une copie (la référence n'est jamais modifiée)")

-- D4. Le banc lit les défauts
local VG = read("tools/autotest/fo-autotest/scenarios/verif_guide_common.lua")
check(not VG:find('"fo-war-autostart", true', 1, true), "D4 verif_guide_common n'écrit plus fo-war-autostart (il le lit)")
check(VG:find('DIFF = DIFF or "normal"', 1, true) ~= nil, "D4 difficulté Normale par défaut dans le banc du guide")
check(VG:find("if AUTO == nil then AUTO = true end", 1, true) ~= nil, "D4 le mod garnit le coffre par défaut (AUTO nil = true)")
local I3 = read("tools/autotest/fo-autotest/scenarios/ia3d_common.lua")
check(not I3:find('"war_setting", "fo-war-ia3-recherche"', 1, true), "D4 ia3d_common n'écrit plus le réglage inexistant fo-war-ia3-recherche")
check(DEF["fo-war-ia3-recherche"] == nil, "D4 ce réglage n'existe toujours pas dans le mod")

-- D5. Mutants
local function killed(name, fn)
  local ok, res = pcall(fn)
  check(ok and res == true, "D5 mutant refusé : " .. name .. (ok and "" or (" (" .. tostring(res) .. ")")))
end
killed("garniture sans contrôle du déjà-garni", function()
  local m, c = SRC:gsub('if c%.garni then return false, "deja%-garni" end', "")
  local M = load_dc(m)
  return c == 1 and select(1, M.stock_due({ founded_by_default = true, garni = true })) == true
end)
killed("garniture d'un coffre fondé par le joueur", function()
  local m, c = SRC:gsub('if not c%.founded_by_default then return false, "pas%-d%-office" end', "")
  local M = load_dc(m)
  return c == 1 and select(1, M.stock_due({ founded_by_default = false, garni = false })) == true
end)
killed("quantité de fer changée", function()
  local m, c = SRC:gsub('{ "iron%-plate", 400 }', '{ "iron-plate", 399 }')
  local M = load_dc(m)
  return c == 1 and M.CONTENTS[1][2] ~= want["iron-plate"]
end)

print(string.format("[DEFAUTS-DC] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
