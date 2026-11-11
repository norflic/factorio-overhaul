--[[
  Lot OUVRIERS-30 (0.6.95) : migration UNIQUE du réglage « Factions : ouvriers au plus » (shared/ai3/ouvriers_reglage.lua,
  script/ai3/ouvriers_reglage.lua). Lancer depuis la racine du mod :
    lua5.2 tests/ouvriers_reglage_test.lua   -> [OUVRIERS-REGLAGE] BILAN : N OK, 0 ECHEC(S)
  §1 règle pure ; §2 partie d'avant la 0.6.95 à 8 ouvriers, par le VRAI on_configuration_changed du mod : 30, une ligne de
  journal ; §3 jamais rejouée ; §4 valeur au défaut ou plus gardée, pas de migration sans montée ; §5 mutants.
]]
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[OUVRIERS-REGLAGE] ECHEC : " .. msg) end
end
local function section(s) print("== " .. s) end

local Ow = require("shared.ai3.ouvriers_reglage")
local Scale = require("shared.team.scale")
local M = require("tests.mock_engine")
local DEF = Scale.DEFAULTS["fo-war-workers"]

section("1. Règle pure")
local function d(old, new) return { mod_changes = { ["factorio-overhaul"] = { old_version = old, new_version = new or "0.6.95" } } } end
check(DEF == 30, "le défaut lu dans Scale vaut 30 (" .. tostring(DEF) .. ")")
check(Ow.due(d("0.6.94"), "factorio-overhaul", false) and Ow.due(d("0.6.87"), "factorio-overhaul", false), "due depuis 0.6.94 et 0.6.87")
check(not Ow.due(d("0.6.95", "0.6.96"), "factorio-overhaul", false) and not Ow.due(d("0.6.94"), "factorio-overhaul", true),
  "pas due depuis 0.6.95, jamais une seconde fois")
check(not Ow.due({ mod_changes = {} }, "factorio-overhaul", false) and not Ow.due(d(nil), "factorio-overhaul", false),
  "pas due sans montée de version ni pour un mod ajouté")
check(Ow.to_set(8) == DEF and Ow.to_set(1) == DEF, "8 et 1 remontent au défaut")
check(Ow.to_set(DEF) == nil and Ow.to_set(45) == nil and Ow.to_set(nil) == nil and Ow.to_set("8") == nil,
  "défaut, plus haut, absent ou non nombre : rien")

local function value(n)
  local ok, v = pcall(function() return settings.global[n].value end)
  if ok then return v end
  return nil
end
local function logs_of(W, from)
  local out = {}
  for i = from + 1, #W.logs do if W.logs[i]:find("[FO-OUVRIERS-REGLAGE]", 1, true) then out[#out + 1] = W.logs[i] end end
  return out
end
local function game_with(v)
  M.new_game({})
  local W = M.world()
  W.settings["fo-war-workers"] = v
  return W
end

section("2. Partie d'avant la 0.6.95 à 8 ouvriers")
local W = game_with(8)
local n0 = #W.logs
W.on_config(d("0.6.94", "0.6.95"))
local L = logs_of(W, n0)
check(value("fo-war-workers") == DEF, "fo-war-workers vaut le défaut après la migration (" .. tostring(value("fo-war-workers")) .. ")")
check(#L == 1 and L[1]:find("8 -> 30", 1, true) ~= nil and L[1]:find("0.6.94 -> 0.6.95", 1, true) ~= nil,
  "une ligne [FO-OUVRIERS-REGLAGE] (" .. tostring(L[1]) .. ")")
check(global.fo.ouvriers_reglage.done == true and global.fo.ouvriers_reglage.avant == 8, "drapeau done, valeur d'avant gardée")

section("3. Jamais rejouée")
settings.global["fo-war-workers"] = { value = 8 } -- le DC la baisse ensuite
n0 = #W.logs
W.on_config(d("0.6.95", "0.6.96"))
W.on_config(d("0.6.40", "0.6.96"))
check(value("fo-war-workers") == 8 and #logs_of(W, n0) == 0, "un réglage baissé ensuite par le DC est respecté, aucune ligne")

section("4. Valeur gardée, pas de migration sans montée")
W = game_with(45)
n0 = #W.logs
W.on_config(d("0.6.94", "0.6.95"))
L = logs_of(W, n0)
check(value("fo-war-workers") == 45 and #L == 1 and L[1]:find("garde", 1, true) ~= nil, "45 gardé, ligne « garde » (" .. tostring(L[1]) .. ")")
W = game_with(8)
n0 = #W.logs
W.on_config({ mod_changes = {} })
check(value("fo-war-workers") == 8 and #logs_of(W, n0) == 0 and global.fo.ouvriers_reglage.done == false,
  "contenu seul : rien d'écrit, drapeau faux")

section("5. Mutants")
local function mutant(name, src_path, old, new, run)
  local f = assert(io.open(src_path, "rb")) local src = f:read("*a") f:close()
  local i = src:find(old, 1, true)
  if not i then check(false, "mutant " .. name .. " : texte introuvable") return end
  local m = src:sub(1, i - 1) .. new .. src:sub(i + #old)
  local chunk = assert(load(m, "=" .. src_path))
  check(run(chunk()) == false, "mutant refusé : " .. name)
end
mutant("seuil 0.6.94 (une partie de la 0.6.94 garderait 8)", "shared/ai3/ouvriers_reglage.lua",
  "Ow.BEFORE = { 0, 6, 95 }", "Ow.BEFORE = { 0, 6, 94 }", function(O) return O.due(d("0.6.94"), "factorio-overhaul", false) end)
mutant("drapeau ignoré", "shared/ai3/ouvriers_reglage.lua", "if done then return false end", "",
  function(O) return not O.due(d("0.6.94"), "factorio-overhaul", true) end)
mutant("plus haut écrasé", "shared/ai3/ouvriers_reglage.lua", "v < def", "v ~= def", function(O) return O.to_set(45) == nil end)
mutant("défaut en dur", "shared/ai3/ouvriers_reglage.lua", "Scale.DEFAULTS[Ow.NAME]", "20", function(O) return O.to_set(8) == DEF end)
mutant("égal réécrit", "shared/ai3/ouvriers_reglage.lua", "v < def", "v <= def", function(O) return O.to_set(DEF) == nil end)

print(string.format("[OUVRIERS-REGLAGE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
