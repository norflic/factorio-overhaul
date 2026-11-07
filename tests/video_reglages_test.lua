--[[
  Lot VIDEO (0.6.61) : migration UNIQUE des quatre réglages de carte de la vidéo (shared/ai3/video_reglages.lua,
  script/ai3/video_reglages.lua). Lancer depuis la racine du mod :
    lua5.2 tests/video_reglages_test.lua   -> [VIDEO-REGLAGES] BILAN : N OK, 0 ECHEC(S)
  §1 règle pure (versions, due, réglages à écrire) ; §2 partie d'avant la 0.6.61 au moteur simulé, par le VRAI on_configuration_changed
  du mod (Events) : les 4 réglages éteints passent à vrai, une ligne de journal ; §3 jamais rejouée (réglage éteint ensuite par le DC
  respecté ; drapeau même si la version recule) ; §4 pas de migration sans montée de version, pour une partie neuve, ou pour un
  réglage absent ; §5 mutants.
]]
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[VIDEO-REGLAGES] ECHEC : " .. msg) end
end
local function section(s) print("== " .. s) end

local Vr = require("shared.ai3.video_reglages")
local M = require("tests.mock_engine")

section("1. Règle pure")
check(Vr.older("0.6.59", Vr.BEFORE) == true and Vr.older("0.6.60", Vr.BEFORE) == true, "0.6.59 et 0.6.60 sont antérieures à 0.6.61")
check(Vr.older("0.6.61", Vr.BEFORE) == false and Vr.older("0.7.0", Vr.BEFORE) == false and Vr.older("1.0.0", Vr.BEFORE) == false,
  "0.6.61, 0.7.0 et 1.0.0 ne le sont pas")
check(Vr.older("0.5.99", Vr.BEFORE) == true and Vr.older("0.6.100", Vr.BEFORE) == false, "comparaison nombre par nombre (0.6.100 > 0.6.61)")
check(Vr.older(nil, Vr.BEFORE) == nil and Vr.older("0.6", Vr.BEFORE) == nil and Vr.older("x.y.z", Vr.BEFORE) == nil, "version illisible : nil")
local function d(old, new) return { mod_changes = { ["factorio-overhaul"] = { old_version = old, new_version = new or "0.6.61" } } } end
check(Vr.due(d("0.6.59"), "factorio-overhaul", false) and Vr.due(d("0.6.60"), "factorio-overhaul", false), "due depuis 0.6.59 et 0.6.60")
check(not Vr.due(d("0.6.59"), "factorio-overhaul", true), "jamais due une seconde fois (done)")
check(not Vr.due({ mod_changes = {} }, "factorio-overhaul", false) and not Vr.due(nil, "factorio-overhaul", false)
  and not Vr.due(d(nil), "factorio-overhaul", false), "pas due sans montée de version (contenu seul, F130), ni pour un mod ajouté")
check(not Vr.due(d("0.6.61", "0.6.62"), "factorio-overhaul", false), "pas due depuis 0.6.61")
local vals = { ["fo-war-portes"] = false, ["fo-war-paliers"] = true, ["fo-debug-trace-carte"] = false }
local ts = Vr.to_set(function(n) return vals[n] end)
check(table.concat(ts, ",") == "fo-debug-trace-carte,fo-war-portes", "à écrire : les faux seulement, absents ignorés, ordre trié (" .. table.concat(ts, ",") .. ")")

-- Partie au moteur simulé : les 4 réglages DÉCLARÉS éteints (une sauvegarde d'avant).
local function game_with(values)
  M.new_game({})
  local W = M.world()
  for _, n in ipairs(Vr.NAMES) do W.settings[n] = values[n] end
  return W
end
local function value(n)
  local ok, v = pcall(function() return settings.global[n].value end)
  if ok then return v end
  return nil
end
local function logs_of(W, from)
  local out = {}
  for i = from + 1, #W.logs do if W.logs[i]:find("[FO-VIDEO-REGLAGES]", 1, true) then out[#out + 1] = W.logs[i] end end
  return out
end
local function all_true()
  for _, n in ipairs(Vr.NAMES) do if value(n) ~= true then return false end end
  return true
end

section("2. Partie d'avant la 0.6.61 : les 4 réglages allumés, une ligne de journal")
local W = game_with({ ["fo-war-portes"] = false, ["fo-war-paliers"] = false, ["fo-war-lots-minerai"] = false, ["fo-debug-trace-carte"] = false })
local n0 = #W.logs
W.on_config(d("0.6.59", "0.6.61"))
local L = logs_of(W, n0)
check(all_true(), "les 4 réglages valent vrai après la migration")
check(#L == 1 and L[1]:find("4 reglage(s) de la video allume(s)", 1, true) ~= nil and L[1]:find("0.6.59 -> 0.6.61", 1, true) ~= nil,
  "une ligne [FO-VIDEO-REGLAGES] : 4 allumés, versions (" .. tostring(L[1]) .. ")")
local st = global.fo.video_reglages
check(st and st.done == true and #st.set == 4, "drapeau done posé, 4 noms gardés")

section("3. Jamais rejouée")
settings.global["fo-war-portes"] = { value = false } -- le DC l'éteint ensuite
n0 = #W.logs
W.on_config(d("0.6.61", "0.6.62"))
W.on_config(d("0.6.40", "0.6.62")) -- même si la version recule puis remonte : le drapeau suffit
check(value("fo-war-portes") == false and #logs_of(W, n0) == 0, "un réglage éteint ensuite par le DC reste éteint, aucune ligne")

section("4. Pas de migration hors d'une montée d'avant la 0.6.61")
W = game_with({ ["fo-war-portes"] = false, ["fo-war-paliers"] = false, ["fo-war-lots-minerai"] = false, ["fo-debug-trace-carte"] = false })
n0 = #W.logs
W.on_config({ mod_changes = {} })
W.on_config(d("0.6.61", "0.6.62"))
check(value("fo-war-portes") == false and #logs_of(W, n0) == 0 and global.fo.video_reglages.done == false,
  "contenu seul ou depuis 0.6.61 : rien d'écrit, aucune ligne, drapeau faux")
W = game_with({ ["fo-war-portes"] = true, ["fo-war-paliers"] = false, ["fo-war-lots-minerai"] = nil, ["fo-debug-trace-carte"] = true })
n0 = #W.logs
local ok_cfg = pcall(W.on_config, d("0.6.60", "0.6.61"))
L = logs_of(W, n0)
check(ok_cfg and value("fo-war-paliers") == true and value("fo-war-lots-minerai") == nil
  and #L == 1 and L[1]:find("1 reglage(s)", 1, true) ~= nil and L[1]:find("deja vrai(s) : 2", 1, true) ~= nil,
  "réglage absent ignoré sans erreur ; seuls les faux écrits ; déjà vrais comptés (" .. tostring(L[1]) .. ")")

section("5. Mutants")
local function mutant(name, src_path, old, new, run)
  local f = assert(io.open(src_path, "rb")) local src = f:read("*a") f:close()
  local i = src:find(old, 1, true)
  if not i then check(false, "mutant " .. name .. " : texte introuvable") return end
  local m = src:sub(1, i - 1) .. new .. src:sub(i + #old)
  local chunk = assert(load(m, "=" .. src_path))
  check(run(chunk()) == false, "mutant refusé : " .. name)
end
mutant("seuil 0.6.60 (une partie passée par la 0.6.60 garderait ses réglages éteints)", "shared/ai3/video_reglages.lua",
  "Vr.BEFORE = { 0, 6, 61 }", "Vr.BEFORE = { 0, 6, 60 }",
  function(V) return V.due(d("0.6.60"), "factorio-overhaul", false) end)
mutant("drapeau ignoré (rejouée à chaque montée)", "shared/ai3/video_reglages.lua",
  "if done then return false end", "",
  function(V) return not V.due(d("0.6.59"), "factorio-overhaul", true) end)
mutant("vrai réécrit aussi (compte faux des réglages déjà vrais)", "shared/ai3/video_reglages.lua",
  "v ~= nil and v ~= true", "v ~= nil",
  function(V) return #V.to_set(function() return true end) == 0 end)

print(string.format("[VIDEO-REGLAGES] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
