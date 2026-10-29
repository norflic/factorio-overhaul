-- Banc hors jeu : script/team/convoyeurs.lua contre un moteur simulé minimal (lot CONVOYEURS, passe d'activation).
--   lua5.2 tests/convoyeurs_script_test.lua   -> [CONVOYEURS-SCRIPT] BILAN : N OK, 0 ECHEC(S)
-- Question posée par les deux parties 0.6.13 du 29/10 (aucune ligne [FO-CONVOYEURS] alors qu'azure avait terminé logistics-2) :
-- (1) la règle est-elle appelée et se trace-t-elle, (2) le tapis rapide est-il choisi / amélioré quand son débit l'exige,
-- (3) la ligne de journal ne sort-elle qu'une fois par équipe.
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(cond, what, detail)
  if cond then ok_n = ok_n + 1 else
    fail_n = fail_n + 1
    print("ECHEC " .. what .. (detail and (" : " .. tostring(detail)) or ""))
  end
end

-- stock simulé (le vrai module charge le coffre du QG, les annexes, les places...)
local STOCK = {}
package.preload["script.team.stock"] = function()
  return {
    count = function(_, item) return STOCK[item] or 0 end,
    remove = function(_, item, n) STOCK[item] = (STOCK[item] or 0) - n end,
    insert = function(_, item, n) STOCK[item] = (STOCK[item] or 0) + n end,
  }
end

-- moteur simulé : 3 tapis, recettes activées par force
local SPEEDS = { ["transport-belt"] = 0.03125, ["fast-transport-belt"] = 0.0625, ["express-transport-belt"] = 0.09375 }
local ITEM = { ["transport-belt"] = "transport-belt", ["fast-transport-belt"] = "fast-transport-belt", ["express-transport-belt"] = "express-transport-belt" }
local ENABLED = { azure = { ["transport-belt"] = true }, scarlet = { ["transport-belt"] = true } }
local LOGS = {}
function log(s) LOGS[#LOGS + 1] = s end
game = { tick = 0, forces = {} }
for _, fname in ipairs({ "azure", "scarlet" }) do
  game.forces[fname] = { recipes = setmetatable({}, { __index = function(_, item)
    return { enabled = ENABLED[fname][item] == true }
  end }) }
end
function game.get_filtered_entity_prototypes()
  local out = {}
  for name, sp in pairs(SPEEDS) do
    out[name] = { belt_speed = sp, items_to_place_this = { { name = ITEM[name] } }, has_flag = function() return false end }
  end
  return out
end

local Conv = dofile("script/team/convoyeurs.lua")

local function count_logs(prefix, key)
  local n = 0
  for _, l in ipairs(LOGS) do
    if l:find(prefix, 1, true) and (not key or l:find(key, 1, true)) then n = n + 1 end
  end
  return n
end

local function team(key) return { key = key, force = key, build = { order = {}, projects = {} } } end

-- (1) avant la technologie : jaune, une ligne de choix, aucune ligne de déblocage
local az = team("azure")
check(Conv.choose(az, 1.25) == "transport-belt", "sans technologie : tapis jaune")
check(count_logs("[FO-CONVOYEURS]", "azure : premier choix") == 1, "première activation : une ligne de choix")
check(Conv.choose(az, 1.25) == "transport-belt", "deuxième appel : encore le jaune")
check(count_logs("[FO-CONVOYEURS]", "azure : premier choix") == 1, "la ligne de choix ne sort qu'une fois par équipe")
Conv.step(az, nil, 1800)
check(count_logs("[FO-CONVOYEURS]", "plus rapide débloqué") == 0, "tapis rapide pas débloqué : pas de ligne de déblocage")

-- (2) logistics-2 terminée par azure seulement (cas des parties du 29/10) : débit réel 1,25/s -> jaune gardé, mais DIT
game.tick = 44.5 * 3600
ENABLED.azure["fast-transport-belt"] = true
check(Conv.choose(az, 1.25) == "transport-belt", "technologie là, débit 1,25/s : le jaune suffit (mode besoin)")
Conv.step(az, nil, 44.5 * 3600)
check(count_logs("[FO-CONVOYEURS]", "azure : tapis plus rapide débloqué") == 1, "déblocage dit une fois")
check(count_logs("[FO-CONVOYEURS]", "fast-transport-belt") >= 1, "la ligne nomme le tapis rapide")
Conv.step(az, nil, 44.5 * 3600 + 1800)
Conv.step(az, nil, 44.5 * 3600 + 3600)
check(count_logs("[FO-CONVOYEURS]", "azure : tapis plus rapide débloqué") == 1, "pas de répétition à chaque passage")
check(az.build.conv_noted.debloque == true and az.build.conv_noted.choix == true, "drapeaux booléens seuls dans la partie")

-- l'autre équipe n'a pas la technologie : sa propre ligne de choix, jamais de déblocage
local sc = team("scarlet")
check(Conv.choose(sc, 2) == "transport-belt", "scarlet : jaune")
Conv.step(sc, nil, 44.5 * 3600)
check(count_logs("[FO-CONVOYEURS]", "scarlet : premier choix") == 1, "scarlet : sa ligne de choix")
check(count_logs("[FO-CONVOYEURS]", "scarlet : tapis plus rapide") == 0, "scarlet : pas de déblocage (technologie absente)")

-- (3) le tapis rapide se déclenche quand le débit l'exige : choix d'un tracé neuf
check(Conv.choose(az, 6) == "fast-transport-belt", "débit 6/s sur une voie, technologie là : tapis rapide")
check(Conv.choose(sc, 6) == "transport-belt", "même débit sans la technologie : jaune")

-- amélioration sur place d'un tracé fini saturé, avec des tapis neufs en stock
local placed, old_alive = {}, {}
local surface = {
  find_entity = function(name, pos)
    if old_alive[pos[1] .. "," .. pos[2]] and name == "transport-belt" then
      return { valid = true, force = { name = "azure" }, position = { x = pos[1], y = pos[2] }, direction = 2 }
    end
  end,
  create_entity = function(t) placed[#placed + 1] = t; return { valid = true } end,
}
local ents = {}
for i = 1, 20 do
  ents[i] = { name = "transport-belt", item = "transport-belt", x = i + 0.5, y = 0.5, part = 1, built = true }
  old_alive[(i + 0.5) .. ",0.5"] = true
end
local team2 = team("azure")
team2.build.order = { 1 }
team2.build.projects[1] = { id = 1, state = "fini", ents = ents, parts = { { belt = "transport-belt", flow = 6.5 } } }
STOCK["fast-transport-belt"] = 100
Conv.step(team2, surface, 10 * 1800)
check(#placed == Conv.BATCH, "tracé saturé : un lot de tuiles remplacé", #placed)
check(placed[1] and placed[1].name == "fast-transport-belt" and placed[1].fast_replace == true, "remplacement par fast_replace en tapis rapide")
check(count_logs("[FO-CONVOYEURS]", "tuile(s) transport-belt -> fast-transport-belt") == 1, "ligne d'amélioration (déjà là avant ce lot)")
check((STOCK["transport-belt"] or 0) == Conv.BATCH, "les anciens tapis retournent au stock")

-- tracé non saturé : rien
local team3 = team("azure")
team3.build.order = { 1 }
team3.build.projects[1] = { id = 1, state = "fini", ents = ents, parts = { { belt = "transport-belt", flow = 2 } } }
local before = #placed
Conv.step(team3, surface, 10 * 1800)
check(#placed == before, "tracé à 2/s : aucune amélioration")

print(string.format("[CONVOYEURS-SCRIPT] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
