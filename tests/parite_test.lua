--[[
  Lot PARITE (retour du DC du 2/11, point 19) : le DÉPART de votre équipe est celui d'une faction. Hors jeu, moteur simulé.
  Usage, depuis la racine du mod :   lua5.2 tests/parite_test.lua     (environ 10 s)

    1. règle pure (shared/team/depart.lua) : coffre d'office, tourelles une seule fois, migration, anti-échelle ;
    2. le kit de fondation est le même pour les deux équipes, tourelles de QG comprises ;
    3. moteur simulé : coffre posé à la main (4 tourelles armées, une seule fois), coffre d'office au lancement de la guerre par le
       réglage de carte, rien pour une équipe déjà lancée à la montée de version, rien aux bancs (remote war_start) ;
    4. mutants : chacun doit être refusé par un contrôle.
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local D = require("shared.team.depart")
local Fondation = require("shared.team.fondation")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

---------------------------------------------------------------------------------------------------
section("1. Règle pure")
do
  local ok, why = D.chest_due({ human = true, team = false, offered = false })
  check(ok and why == "depart", "lancement humain, aucune équipe, départ pas offert : le coffre est posé d'office")
  check(not D.chest_due({ human = false, team = false, offered = false }), "lancement de banc : jamais d'office")
  local ok2, why2 = D.chest_due({ human = true, team = true, offered = false })
  check(not ok2 and why2 == "equipe-existe", "une équipe existe : rien")
  local ok3, why3 = D.chest_due({ human = true, team = false, offered = true })
  check(not ok3 and why3 == "deja-offert", "départ déjà offert (équipe perdue) : le coffre se refabrique, il n'est pas redonné")
  check(D.turrets_due({ grant = 4, offered = false }) == 4, "tourelles : 4 à la première fondation")
  check(D.turrets_due({ grant = 4, offered = true }) == 0, "tourelles : 0 une fois le départ offert")
  check(D.turrets_due({ grant = nil, offered = false }) == 0 and D.turrets_due({ grant = -3, offered = false }) == 0, "tourelles : jamais négatif")
  check(D.is_offered(false) == false and D.is_offered(true) == true and D.is_offered(nil) == true,
    "départ : faux = à offrir (partie neuve), vrai = offert, absent = sauvegarde d'avant le lot = déjà offert")
  check(D.migrate_offered({ team = true, offered = nil }) == true, "migration : équipe déjà lancée = départ offert")
  check(D.migrate_offered({ team = false, offered = nil }) == false, "migration : aucune équipe = départ à offrir")
  check(D.migrate_offered({ team = true, offered = false }) == false, "migration : une valeur déjà écrite est gardée")
  check(D.migrate_offered({ team = false, offered = true }) == true, "migration : départ déjà offert gardé")
  local o = D.offsets(4)
  check(#o == 4 and o[1][1] == 12 and o[2][1] == -12 and o[3][2] == 10 and o[4][2] == -10, "quatre emplacements, ceux d'avant le lot")
  check(#D.offsets(2) == 2 and #D.offsets(9) == 4 and #D.offsets(0) == 0, "emplacements bornés à la liste")
  -- Anti-échelle : aucun nom d'objet du jeu dans la règle
  local f = io.open("shared/team/depart.lua", "r")
  local src = f:read("*a")
  f:close()
  local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  local bad = {}
  for _, name in ipairs({ "gun%-turret", "iron%-chest", "fo%-team%-chest", "iron%-plate", "firearm", "burner", "stone%-furnace" }) do
    if code:find(name) then bad[#bad + 1] = name end
  end
  check(#bad == 0, "aucun nom d'objet dans shared/team/depart.lua (" .. table.concat(bad, ",") .. ")")
end

---------------------------------------------------------------------------------------------------
section("2. Kit de fondation commun")
do
  local p, fct = Fondation.grant(true, false), Fondation.grant(false, false)
  check(p.hq_turrets == 4 and fct.hq_turrets == 4, "4 tourelles de QG pour les deux équipes")
  check(#p.chest == 0 and #fct.chest == 0 and p.smelters == 0 and fct.smelters == 0, "coffre vide et aucun four pour les deux")
  check(Fondation.grant(true, true).hq_turrets == 4, "le kit généreux de banc ne change pas les tourelles de votre équipe")
end

---------------------------------------------------------------------------------------------------
local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

local function turrets_of(s, force)
  return s.find_entities_filtered({ name = "gun-turret", force = force })
end
local function ammo(t) return t.get_inventory(defines.inventory.turret_ammo).get_item_count() end

local function min_ammo(list)
  local m
  for _, t in ipairs(list) do m = math.min(m or ammo(t), ammo(t)) end
  return m or 0
end

---------------------------------------------------------------------------------------------------
section("3a. Coffre posé à la main : 4 tourelles armées, une seule fois")
M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
do
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  M.world().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  local f = global.fo.pteam.team
  check(f ~= nil and f.is_player, "équipe créée")
  local ts = turrets_of(s, "player")
  check(#ts == 4, "4 tourelles de QG autour du coffre (" .. #ts .. ")")
  check(min_ammo(ts) >= 20, "chacune avec au moins 20 chargeurs (" .. min_ammo(ts) .. ")")
  local Outposts = require("script.faction.outposts")
  local _, by_key = Outposts.turret_groups(f)
  check(by_key.hq and #by_key.hq.list == 4, "le groupe « hq » de l'équipe compte les 4 tourelles")
  check(global.fo.pteam.depart_offert == true, "départ marqué offert")
  check(chest.get_item_count("iron-plate") == 0 and chest.get_item_count("gun-turret") == 0, "le coffre ne contient aucun objet offert")
  -- un second coffre : ni équipe, ni tourelle
  local other = s.create_entity({ name = "fo-team-chest", position = { x = 20, y = 5 }, force = "player" })
  M.world().events[defines.events.on_built_entity]({ created_entity = other, player_index = 1, tick = game.tick })
  check(global.fo.pteam.team.hq == chest and #turrets_of(s, "player") == 4, "un second coffre ne fonde rien et n'offre rien")
  -- coffre perdu, refabriqué : l'équipe renaît sans nouvelle tourelle
  chest.destroy() -- retiré (mine, script) : l'équipe prend fin (une destruction par l'ennemi la ferait reposer, lot S1)
  M.run_ticks(2)
  check(global.fo.pteam.team == nil, "coffre retiré : équipe dissoute")
  local again = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  M.world().events[defines.events.on_built_entity]({ created_entity = again, player_index = 1, tick = game.tick })
  check(global.fo.pteam.team ~= nil, "coffre refabriqué : l'équipe renaît")
  check(#turrets_of(s, "player") == 4, "aucune tourelle de plus au second départ (" .. #turrets_of(s, "player") .. ")")
end

---------------------------------------------------------------------------------------------------
section("3b. Lancement de la guerre par le réglage de carte : coffre d'office")
M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0, war_autostart = true })
do
  local s = game.surfaces[1]
  check(global.fo.pteam.team == nil, "avant le lancement : aucune équipe")
  M.run_ticks(700)
  local f = global.fo.pteam.team
  check(f ~= nil and f.is_player and f.hq and f.hq.valid, "équipe fondée d'office après le lancement automatique")
  check(f and f.hq and f.hq.name == "fo-team-chest" and f.hq.force.name == "player", "coffre d'équipe, force player")
  local ts = turrets_of(s, "player")
  check(#ts == 4 and min_ammo(ts) >= 20, "4 tourelles armées au QG d'office (" .. #ts .. ")")
  local near = true
  for _, t in ipairs(ts) do
    local dx, dy = t.position.x - f.hq_pos.x, t.position.y - f.hq_pos.y
    if dx * dx + dy * dy > 16 * 16 then near = false end
  end
  check(near, "tourelles à moins de 16 tuiles du coffre")
  check(f.engineers_count >= 2, "PNJ offerts à la fondation (" .. tostring(f.engineers_count) .. ")")
  -- les factions ont le même nombre de tourelles de QG
  local w = global.fo.war
  local same = true
  for _, fac in ipairs(w.factions) do
    local n = 0
    for _ in pairs(fac.turrets) do n = n + 1 end
    if n ~= 4 then same = false end
  end
  check(same and #w.factions >= 2, "chaque faction a aussi 4 tourelles de QG : parité")
  local PlayerTeam = require("script.team.player_team")
  local ok, why = PlayerTeam.found_default(s, { x = 0, y = 0 })
  check(ok == false and why == "equipe-existe", "second appel : l'équipe existe, rien")
  local pwr = 0
  for _, e in ipairs(s.find_entities_filtered({ name = "fo-team-chest" })) do pwr = pwr + 1 end
  check(pwr == 1, "un seul coffre d'équipe sur la carte")
end

---------------------------------------------------------------------------------------------------
section("3c. Bancs (remote war_start) : rien d'office")
M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
do
  check(remote.call("factorio-overhaul", "war_start", 2, 100, 4, 320) == true, "guerre lancée par le remote")
  M.run_ticks(700)
  check(global.fo.pteam.team == nil, "aucun coffre d'équipe posé par le lancement de banc")
end

---------------------------------------------------------------------------------------------------
section("3d. Montée de version : une équipe déjà lancée ne reçoit rien d'office")
M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
do
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  M.world().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  -- état d'une sauvegarde ANTÉRIEURE : équipe là, jamais de départ écrit, tourelles retirées
  for _, t in ipairs(turrets_of(s, "player")) do t.destroy() end
  global.fo.pteam.depart_offert = nil
  M.world().settings["fo-war-adopte"] = { value = true } -- lu par la migration d'ADOPTE (non déclaré par le moteur simulé)
  M.world().on_config({})
  check(global.fo.pteam.depart_offert == true, "migration : le départ est marqué offert pour l'équipe existante")
  chest.destroy()
  M.run_ticks(2)
  local again = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  M.world().events[defines.events.on_built_entity]({ created_entity = again, player_index = 1, tick = game.tick })
  check(#turrets_of(s, "player") == 0, "équipe lancée avant la montée de version : aucune tourelle offerte au coffre refabriqué")
  -- la migration n'a PAS tourné (même version, bancs) : une valeur absente vaut « déjà offert », la sauvegarde d'avant le lot ne reçoit rien
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
  global.fo.pteam.depart_offert = nil
  local s2 = game.surfaces[1]
  local c2 = s2.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  M.world().events[defines.events.on_built_entity]({ created_entity = c2, player_index = 1, tick = game.tick })
  check(global.fo.pteam.team ~= nil and #turrets_of(s2, "player") == 0, "sauvegarde d'avant le lot, migration non jouée : coffre posé, aucune tourelle offerte")
  -- une partie sans équipe garde le départ à offrir
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
  M.world().settings["fo-war-adopte"] = { value = true }
  M.world().on_config({})
  check(global.fo.pteam.depart_offert == false, "migration : aucune équipe, le départ reste à offrir")
end

---------------------------------------------------------------------------------------------------
section("4. Mutants")
local function mutant(name, fn)
  local ok, killed = pcall(fn)
  check(ok and killed == true, "mutant refusé : " .. name .. (ok and "" or " (" .. tostring(killed) .. ")"))
end
do
  local chest_due, turrets_due, migrate = D.chest_due, D.turrets_due, D.migrate_offered
  mutant("le coffre d'office aussi aux bancs", function()
    D.chest_due = function(c) return chest_due({ human = true, team = c.team, offered = c.offered }) end
    local ok = D.chest_due({ human = false, team = false, offered = false })
    D.chest_due = chest_due
    return ok == true
  end)
  mutant("le coffre d'office malgré une équipe existante", function()
    D.chest_due = function(c) return chest_due({ human = c.human, team = false, offered = c.offered }) end
    local ok = D.chest_due({ human = true, team = true, offered = false })
    D.chest_due = chest_due
    return ok == true
  end)
  mutant("le coffre redonné après la perte de l'équipe", function()
    D.chest_due = function(c) return chest_due({ human = c.human, team = c.team, offered = false }) end
    local ok = D.chest_due({ human = true, team = false, offered = true })
    D.chest_due = chest_due
    return ok == true
  end)
  mutant("les tourelles redonnées à chaque coffre", function()
    D.turrets_due = function(c) return turrets_due({ grant = c.grant, offered = false }) end
    local n = D.turrets_due({ grant = 4, offered = true })
    D.turrets_due = turrets_due
    return n == 4
  end)
  mutant("la migration offre le départ à une équipe lancée", function()
    D.migrate_offered = function(c) return migrate({ team = false, offered = c.offered }) end
    local v = D.migrate_offered({ team = true, offered = nil })
    D.migrate_offered = migrate
    return v == false
  end)
  mutant("la fondation de votre équipe sans tourelles", function()
    local grant0 = Fondation.grant
    Fondation.grant = function(is_player, g, b)
      local r = grant0(is_player, g, b)
      if is_player then r.hq_turrets = 0 end
      return r
    end
    local ok = Fondation.grant(true, false).hq_turrets == Fondation.grant(false, false).hq_turrets
    Fondation.grant = grant0
    return not ok
  end)
end

print(string.format("\n[PARITE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
