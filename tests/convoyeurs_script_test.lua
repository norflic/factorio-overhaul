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

---------------------------------------------------------------------------------------------------
-- Lot CONVEYOR-SCALING : l'ordre de la passe (troncs du bus d'abord), les lignes du plan (spec), la méga-fonderie, le réveil « recherche »
---------------------------------------------------------------------------------------------------
local function line_ents(n, y, name)
  local out = {}
  for i = 1, n do
    out[i] = { name = name or "transport-belt", item = name or "transport-belt", x = i + 0.5, y = y, part = 1, built = true, role = "champ-tapis" }
    old_alive[(i + 0.5) .. "," .. y] = true
  end
  return out
end
local team4 = team("azure")
team4.team = { scan = {} }
team4.build.order = { 1, 2, 3, 4 }
-- projet 1 : tracé de foreuses très saturé (7/s sur une voie) ; projet 2 : liaison de quai ; projet 3 : tronc du bus (moins saturé) ;
-- projet 4 : bande d'un champ dont le gisement 9 a une méga-fonderie décidée (18 minerai/s sur 2 lignes)
team4.build.projects[1] = { id = 1, state = "fini", ents = line_ents(10, 10.5), parts = { { belt = "transport-belt", flow = 7 } } }
team4.build.projects[2] = { id = 2, state = "fini", ents = line_ents(10, 20.5), parts = { { kind = "liaison" } }, spec = { liaison = { belt = "transport-belt", flow = 6 } } }
team4.build.projects[3] = { id = 3, state = "fini", ents = line_ents(12, 30.5), parts = { { kind = "liaison" } }, spec = { liaison = { belt = "transport-belt", flow = 5, bus = true } } }
team4.build.projects[4] = { id = 4, state = "fini", ents = line_ents(6, 40.5), parts = { { kind = "module" } }, spec = { champ = { oid = 9 } } }
team4.mega = { deps = { [9] = { state = "decide", lines = 2, cols = 2, ore = 18, plates = 18 } } }
STOCK["fast-transport-belt"] = 100
placed = {}
Conv.step(team4, surface, 20 * 1800)
check(#placed == Conv.BATCH and placed[1].position.y == 30.5, "le tronc du bus (projet 3) passe AVANT la liaison et le tracé plus saturés", placed[1] and placed[1].position.y)
check(count_logs("[FO-CONVOYEURS]", "montée de palier : tronc 3 (12 tuiles) puis sortie-fonderie 4 (6 tuiles) puis liaison 2 (10 tuiles) puis autre 1 (10 tuiles)") == 1,
  "ligne du plan : tronc, sortie-fonderie, liaison, autre")
check(count_logs("[FO-CONVOYEURS]", "tracé 1 (tronc)") == 1, "ligne du lot nomme la sorte")
-- cadence : rien avant Conv.EVERY
placed = {}
Conv.step(team4, surface, 20 * 1800 + 100)
check(#placed == 0, "passe bornée par Conv.EVERY")
-- réveil « recherche » servi : la passe part sans attendre la cadence ; une seule fois par passe servie
team4.team.scan = { why = "recherche", served = 20 * 1800 + 50 }
Conv.step(team4, surface, 20 * 1800 + 200)
check(#placed == 12 - Conv.BATCH, "réveil « recherche » servi : passe anticipée (le tronc finit ses 4 tuiles)", #placed)
check(team4.build.projects[3].spec.liaison.belt == "fast-transport-belt", "tronc fini : sa spec porte le tapis rapide (une reconstruction le garde)")
placed = {}
Conv.step(team4, surface, 20 * 1800 + 300)
check(#placed == 0, "le même réveil ne relance pas la passe")
team4.team.scan = { why = "stock", served = 20 * 1800 + 350 }
Conv.step(team4, surface, 20 * 1800 + 400)
check(#placed == 0, "un réveil « stock » n'anticipe pas")
-- kit vide : rien n'est retiré, la ligne « en attente » sort une fois
STOCK["fast-transport-belt"] = 0
Conv.step(team4, surface, 22 * 1800)
check(#placed == 0 and count_logs("[FO-CONVOYEURS]", "en attente : fast-transport-belt x") == 1, "sans kit : rien n'est retiré, manque journalisé")
check(team4.build.conv_wait and team4.build.conv_wait.item == "fast-transport-belt", "Conv.wanted dit le tapis à fabriquer")
-- la bande d'un champ SANS méga-fonderie décidée n'a pas de débit : laissée
local team5 = team("azure")
team5.build.order = { 1 }
team5.build.projects[1] = { id = 1, state = "fini", ents = line_ents(6, 50.5), parts = { { kind = "module" } }, spec = { champ = { oid = 3 } } }
STOCK["fast-transport-belt"] = 100
placed = {}
Conv.step(team5, surface, 30 * 1800)
check(#placed == 0, "bande ordinaire : débit inconnu, laissée")
-- rien dans global qui ne soit une donnée
for _, k in ipairs({ "conv_next", "conv_served", "conv_plan_key" }) do
  check(type(team4.build[k]) == "number" or type(team4.build[k]) == "string", "f.build." .. k .. " est une donnée")
end

print(string.format("[CONVOYEURS-SCRIPT] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
