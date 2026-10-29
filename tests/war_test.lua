--[[
  Test de fumée de la guerre des factions + mécaniques du monde, sur le moteur simulé.
  Usage, depuis la racine du mod :   lua5.2 tests/war_test.lua [minutes=20]

  Vérifie : lancement (forces, QG, diplomatie), boucle économique et militaire sur N minutes (avant-postes
  construits par les ouvriers avec les objets du stock, soldats équipés, attaques, pertes), statut, déterminisme, sauvegarde en pleine
  guerre, élimination d'une faction, déclaration de guerre au joueur, arrêt ; dangers des biomes ;
  libération de couvée.
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local MINUTES = tonumber(arg and arg[1]) or 30
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

-- Gisements sur les anneaux d'échantillonnage de chaque QG (distance 320, diagonales).
local function patches()
  local out = {}
  local D, d = 320 * 0.7071, 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  -- une poche de méthane (fluide) pour vérifier qu'elle est ignorée
  out[#out + 1] = { x = 226 + 40, y = -226, category = "basic-fluid", name = "fo-methane" }
  return out
end

local function war(text) M.command("fo-war", text) end
local function W() return M.world() end

local function count_entities(name, force)
  local n = 0
  for _, e in ipairs(W().entities) do
    if e.valid and e.name == name and (not force or e.force.name == force) then n = n + 1 end
  end
  return n
end

---------------------------------------------------------------------------------------------------
section("Lancement de la guerre")
M.new_game({ patches = patches(), p_busy = 0.02, p_nopath = 0.02, p_lost = 0.005 })
war("start 4 100 10 320")
local war_state = global.fo.war
check(war_state.active, "guerre active")
check(#war_state.factions == 4, "4 factions")
for _, key in ipairs({ "scarlet", "azure", "emerald", "amber" }) do
  local f = game.forces["fo-" .. key]
  check(f ~= nil, "force fo-" .. key .. " créée")
  check(f and f.get_cease_fire(game.forces.player) == true, "cessez-le-feu " .. key .. " -> joueur")
  check(game.forces.player.get_cease_fire(f) == true, "cessez-le-feu joueur -> " .. key)
end
check(count_entities("fo-faction-hq") == 4, "4 QG posés")
-- Lot KIT : le kit généreux (défaut du moteur simulé) offre 4 tourelles de QG par faction ; le kit égal (FO_KIT_EGAL=1, le
-- jeu réel) n'en offre aucune, ni stock de départ au coffre.
local kit_egal = os.getenv("FO_KIT_EGAL") == "1"
check(count_entities("gun-turret") == 16, "16 tourelles de QG (offertes aux factions, même en kit égal)")
-- Lot IA1-a : effectif de départ fo-npc-start (8, défaut de shared/team/scale.lua ; 2 avant IA1-a).
check(count_entities("fo-companion") == 32, "8 ouvriers par faction (fo-npc-start)")
for _, f in ipairs(global.fo.war.factions) do
  if kit_egal then
    check(f.hq.get_item_count("burner-mining-drill") == 0 and f.hq.get_item_count("coal") == 0, f.key .. " : coffre du QG vide (kit égal)")
  else
    check(f.hq.get_item_count("burner-mining-drill") > 0 and f.hq.get_item_count("coal") > 0, f.key .. " : stock de depart dans le QG")
  end
end

---------------------------------------------------------------------------------------------------
section(string.format("Simulation de %d minutes de guerre", MINUTES))
local t0 = os.clock()
local ok, err = pcall(M.run_ticks, MINUTES * 3600)
check(ok, "simulation sans erreur Lua (" .. tostring(err) .. ")")
print(string.format("  (%.1f s CPU pour %d ticks)", os.clock() - t0, MINUTES * 3600))
war("status")
local status = table.concat({ table.unpack(W().prints, #W().prints - 4, #W().prints) }, "\n")
print(status)
local total_outposts, total_soldiers, total_attacks, total_lost, techs = 0, 0, 0, 0, 0
for _, f in ipairs(global.fo.war.factions) do
  total_outposts = total_outposts + f.outposts_count
  total_soldiers = total_soldiers + f.soldiers_count
  total_attacks = total_attacks + f.stats.attacks
  total_lost = total_lost + f.stats.soldiers_lost
  techs = techs + f.tech
  check(f.outposts_count + f.stats.outposts_lost >= 1, f.key .. " a construit au moins un avant-poste")
  check(f.soldiers_count <= 100, f.key .. " respecte le plafond de soldats")
  check(f.garrison_count >= 0 and f.garrison_count <= f.soldiers_count, f.key .. " garnison cohérente")
  local real = 0
  for _ in pairs(f.soldiers) do real = real + 1 end
  check(real == f.soldiers_count, f.key .. " compteur de soldats = table des soldats")
end
check(total_soldiers > 0, "des soldats existent (" .. total_soldiers .. ")")
check(total_attacks > 0, "des attaques ont été lancées (" .. total_attacks .. ")")
check(total_lost > 0, "des soldats sont morts au combat (" .. total_lost .. ")")
check(techs > 0, "au moins une faction a progressé en technologie (" .. techs .. ")")
check(count_entities("burner-mining-drill") > 0, "des foreuses d'avant-poste existent")
check(count_entities("stone-furnace") > 0, "des fours d'avant-poste existent")
for _, f in ipairs(global.fo.war.factions) do
  local st = f.team.task_stats
  check((st.craft and st.craft.ok or 0) > 0, f.key .. " : les ouvriers ont fabrique (" .. (st.craft and st.craft.ok or 0) .. ")")
  check((st.service and st.service.ok or 0) > 0, f.key .. " : les ouvriers ont entretenu les avant-postes")
  check(f.team.done.coal and f.team.done.iron, f.key .. " : objectifs Charbon et Fer atteints")
end
check(W().files["fo-war/status.txt"] ~= nil, "statut écrit dans script-output")
-- Lot IA0 (difficulté par défaut : Normal) : déclarations à la fin de la grâce, mais aucune attaque
-- contre un joueur qui n'a aucune installation.
do
  local declared, against_player, status_pvp = 0, 0, false
  for _, f in ipairs(global.fo.war.factions) do
    if f.pvp and f.pvp.declared then declared = declared + 1 end
    against_player = against_player + (f.pvp and f.pvp.attacks or 0)
  end
  for _, l in ipairs(W().prints) do if l:find("PvP : difficulte normal", 1, true) then status_pvp = true end end
  check(global.fo.war.factions[1].pvp.declared and declared >= 1, "PvP Normal : l'Ordre Écarlate (grâce 20 min) a déclaré la guerre au joueur")
  check(against_player == 0, "PvP : aucune attaque contre un joueur sans installation (" .. against_player .. ")")
  check(status_pvp, "statut : ligne PvP")
end
local ok_ser, err_ser = pcall(M.serialize, global)
check(ok_ser, "global sérialisable en pleine guerre (" .. tostring(err_ser) .. ")")

---------------------------------------------------------------------------------------------------
section("Sauvegarde / rechargement en pleine guerre")
local saved = M.deepcopy_global(global)
M.load_mod()
_G.global = saved
local ok_load = pcall(function() W().on_load() end)
check(ok_load, "on_load sans erreur")
local ok_run, err_run = pcall(M.run_ticks, 5 * 3600)
check(ok_run, "la guerre continue après rechargement (" .. tostring(err_run) .. ")")

---------------------------------------------------------------------------------------------------
-- Lot PNJ-VÉRIF (défauts M3, M4). Le moteur simulé ne déplace pas les unités et ne retire jamais un membre d'un
-- groupe : on le fait à la main (téléport, membre retiré), puis on vérifie la logique du mod. Le trajet réel du
-- groupe de rappel n'est prouvé qu'en moteur réel.
section("Soldats égarés : garnison utile, soldat retiré de son groupe, rappel")
do
  local Military = require("script.faction.military")
  local Commander = require("script.faction.commander")
  local St = require("script.faction.state")
  local w = W()
  w.p_busy, w.p_nopath, w.p_lost = 0, 0, 0 -- itinéraires sûrs pour ce cas
  local f
  for _, ff in ipairs(global.fo.war.factions) do
    local idle = 0
    for _, id in ipairs(St.sorted_keys(ff.soldiers)) do
      if not ff.soldiers[id].group and ff.soldiers[id].entity.valid then idle = idle + 1 end
    end
    if not ff.eliminated and idle >= 6 and not ff.recall_pending then f = ff break end
  end
  check(f ~= nil, "une faction avec au moins 6 soldats en garnison")
  if f then
    local idle = {}
    for _, id in ipairs(St.sorted_keys(f.soldiers)) do
      if not f.soldiers[id].group and f.soldiers[id].entity.valid then idle[#idle + 1] = id end
    end
    local near0, far0 = Military.garrison_split(f)
    check(far0 == 0, "au départ, aucun soldat loin du QG (" .. far0 .. ")")
    -- 3 soldats téléportés à 600 tuiles, à moins de 32 tuiles l'un de l'autre.
    for k = 1, 3 do
      f.soldiers[idle[k]].entity.teleport({ x = f.hq_pos.x + 600 + 4 * k, y = f.hq_pos.y + 14 })
    end
    local near1, far1 = Military.garrison_split(f)
    check(far1 == 3 and near1 == near0 - 3, string.format("garnison : %d proches, %d loin (attendu %d, 3)", near1, far1, near0 - 3))
    local view = Commander.view(f, game.tick)
    check(view.garrison == near1, string.format("la décision d'attaque ne compte que la garnison proche (%d, garnison totale %d)",
      view.garrison, f.garrison_count))
    -- Un groupe de 2 soldats dont le moteur a retiré un membre en route.
    local surface = game.surfaces[global.fo.war.surface]
    local g = surface.create_unit_group({ position = f.hq_pos, force = f.force })
    for k = 4, 5 do
      g.add_member(f.soldiers[idle[k]].entity)
      f.soldiers[idle[k]].group = g.group_number
    end
    f.garrison_count = f.garrison_count - 2
    g.set_command({ type = defines.command.go_to_location, destination = f.hq_pos, radius = 16 })
    f.groups[g.group_number] = { group = g, state = "attack", target = f.hq_pos, started = game.tick, size = 2, route = {} }
    f.soldiers[idle[5]].entity._group = false -- retiré par le moteur (false : le mock refuse une clé effacée)
    local gc = f.garrison_count
    f.recall_block_until, f.recall_pending = nil, nil
    Military.maintain(f, game.tick)
    check(f.soldiers[idle[5]].group == nil and f.soldiers[idle[4]].group == g.group_number,
      "le soldat retiré de son groupe revient à la garnison, l'autre reste membre")
    check(f.garrison_count == gc + 1, "garnison + 1 pour le soldat retiré")
    local rc = f.recall_pending
    check(rc ~= nil and #rc.ids == 3, "rappel demandé pour le paquet des 3 soldats lointains (" .. (rc and #rc.ids or 0) .. ")")
    M.run_ticks(30) -- l'itinéraire arrive (latence simulée : 3 ticks)
    local rg
    for _, gid in ipairs(St.sorted_keys(f.groups)) do
      if f.groups[gid].recall then rg = f.groups[gid] end
    end
    check(rg ~= nil and rg.state == "return" and #rg.group.members == 3 and #rg.route > 0,
      "un groupe de rappel de 3 soldats rentre par un itinéraire (" .. (rg and (#rg.group.members .. " membres, " .. #rg.route .. " étapes") or "aucun") .. ")")
    local ok_ids = rg ~= nil
    for k = 1, 3 do ok_ids = ok_ids and f.soldiers[idle[k]].group == rg.group.group_number and (f.soldiers[idle[k]].recalls or 0) == 1 end
    check(ok_ids, "les 3 soldats sont membres du groupe de rappel, rappel compté une fois chacun")
    local near2, far2 = Military.garrison_split(f)
    check(far2 == 0, "plus aucun soldat de garnison loin du QG pendant le rappel (" .. far2 .. ")")
    check((f.stats.recalls or 0) >= 1, "rappel compté dans les statistiques")
    for k = 1, 3 do
      local s = f.soldiers[idle[k]]
      if s and s.entity.valid then s.entity.teleport({ x = f.hq_pos.x, y = f.hq_pos.y + 14 }) end
    end
    local ok_r, err_r = pcall(M.run_ticks, 2 * 3600)
    check(ok_r, "deux minutes après le rappel sans erreur (" .. tostring(err_r) .. ")")
    check(f.garrison_count >= 0 and f.garrison_count <= f.soldiers_count, "garnison cohérente après le rappel")
  end
  w.p_busy, w.p_nopath, w.p_lost = 0.02, 0.02, 0.005
end

---------------------------------------------------------------------------------------------------
section("Équipe sans ouvrier ni pistolet : embauche de secours")
do
  local f = global.fo.war.factions[2]
  for _, aid in ipairs(require("script.faction.state").sorted_keys(f.engineers)) do
    local a = global.fo.companion.agents[aid]
    if a and a.entity.valid then a.entity.die() end
  end
  M.run_ticks(2)
  for _, name in ipairs({ "pistol", "firearm-magazine", "copper-plate" }) do
    local n = f.hq.get_item_count(name)
    if n > 0 then f.hq.remove_item({ name = name, count = n }) end
  end
  check(f.engineers_count == 0, "plus aucun ouvrier (" .. f.engineers_count .. ")")
  local ok_r, err_r = pcall(M.run_ticks, 3 * 3600)
  check(ok_r, "trois minutes sans erreur (" .. tostring(err_r) .. ")")
  check(f.engineers_count >= 1, "un ouvrier embauché sans arme (" .. f.engineers_count .. ")")
  check((f.stats.unarmed_hires or 0) >= 1, "embauche de secours comptée")
end

---------------------------------------------------------------------------------------------------
section("Avant-poste détruit : reconstruction")
do
  local f, lost
  for _, ff in ipairs(global.fo.war.factions) do
    for oid, o in pairs(ff.outposts) do
      if o.kind == "stone" and not lost then f, lost = ff, oid end
    end
  end
  if f then
    local killed = 0
    for _, e in ipairs(W().entities) do
      local fname = type(f.force) == "string" and f.force or f.force.name
      if e.valid and e.name == "burner-mining-drill" and e.force.name == fname then
        local o = f.outposts[lost]
        if o then
          local dx, dy = e.position.x - o.pos.x, e.position.y - o.pos.y
          if dx * dx + dy * dy < 20 * 20 then e.die(); killed = killed + 1 end
        end
      end
    end
    M.run_ticks(2)
    local stone_now = 0
    for _, o in pairs(f.outposts) do if o.kind == "stone" then stone_now = stone_now + 1 end end
    check(killed > 0 and stone_now == 0, f.key .. " : avant-poste de pierre détruit (" .. killed .. " foreuses)")
    check(#(f.prospects or {}) > 0, "le gisement perdu revient à la réserve")
    -- Équipe en fin d'échelle souvent à court de fer dans le moteur simulé : on lui donne de quoi
    -- reconstruire, le test porte sur la règle, pas sur l'économie.
    -- Lot IA3-d : avec « défendre d'abord » pour toutes les factions (IA1-b2, R-QCM-25c), un avant-poste se reconstruit
    -- AVEC ses tourelles : elles sont données aussi (sur ia-v2, la reconstruction ne passait qu'avec une 9e recrue faite
    -- par l'ancien frein à un instant où personne n'était sans tâche ; 8 PNJ, fer au chemin critique : tourelles jamais
    -- fabriquées en 6 min, manque « gun-turret 2 »).
    for _, it in ipairs({ { "burner-mining-drill", 4 }, { "iron-chest", 4 }, { "coal", 50 }, { "gun-turret", 2 },
      { "firearm-magazine", 40 } }) do
      f.hq.insert({ name = it[1], count = it[2] })
    end
    -- Lot IA3-d : 10 min au lieu de 6. Sous le cerveau par besoins, la reconstruction est planifiée dès la pensée qui
    -- suit la perte (tâche « build:stone » prise) ; selon le site choisi et le trajet, l'avant-poste tient à 5 ou à 8 min
    -- (moteur simulé, effectifs des autres factions changés par la règle d'effectif : 8 min). La règle testée (un
    -- avant-poste perdu est reconstruit avec le stock) n'est pas affaiblie ; seule l'attente du trajet est allongée.
    local ok_r, err_r = pcall(M.run_ticks, 10 * 3600)
    check(ok_r, "dix minutes sans erreur (" .. tostring(err_r) .. ")")
    stone_now = 0
    for _, o in pairs(f.outposts) do if o.kind == "stone" then stone_now = stone_now + 1 end end
    check(stone_now >= 1, f.key .. " : avant-poste de pierre reconstruit (" .. stone_now .. ")")
  else
    check(false, "aucun avant-poste de pierre pour le test de reconstruction")
  end
end

---------------------------------------------------------------------------------------------------
section("Diplomatie : le joueur détruit une foreuse")
-- Lot IA0 : en Normal, toutes les grâces sont écoulées ici. On repasse en « Paisible » (trêve des factions
-- déclarées par la difficulté), puis on vérifie la rupture du cessez-le-feu par provocation.
check(remote.call("fo-pvp", "set_difficulty", "peaceful") == true, "passage en Paisible (interface distante)")
local truce_all = true
for _, id in ipairs(require("script.faction.state").alive()) do
  local ff = game.forces[global.fo.war.factions[id].force]
  if not (ff.get_cease_fire(game.forces.player) and game.forces.player.get_cease_fire(ff)) then truce_all = false end
end
check(truce_all, "Paisible : cessez-le-feu rétabli avec toutes les factions")
local victim
for _, e in ipairs(W().entities) do
  if e.valid and e.name == "burner-mining-drill" then victim = e break end
end
if victim then
  local vf = victim.force
  victim.die(game.forces.player)
  M.run_ticks(2)
  check(vf.get_cease_fire(game.forces.player) == false, "la faction lésée déclare la guerre au joueur")
  check(game.forces.player.get_cease_fire(vf) == false, "et réciproquement")
  local told = 0
  for _, line in ipairs(W().game_prints) do if line:find("fo-pvp.declare-provoked:", 1, true) then told = told + 1 end end
  check(told == 1, "représailles annoncées au joueur (" .. told .. ")")
else
  check(false, "aucune foreuse disponible pour le test de diplomatie")
end

---------------------------------------------------------------------------------------------------
section("Élimination d'une faction")
local f1 = global.fo.war.factions[1]
f1.hq.die(game.forces["fo-azure"])
M.run_ticks(2)
check(global.fo.war.factions[1].eliminated == true, "faction 1 anéantie à la perte de son QG")
local found = false
for _, line in ipairs(W().game_prints) do if line:find("fo-faction.eliminated", 1, true) then found = true end end
check(found, "annonce d'élimination diffusée")
local ok_after = pcall(M.run_ticks, 2 * 3600)
check(ok_after, "les autres factions continuent sans erreur")
check(#require("script.faction.state").alive() == 3, "3 factions vivantes")

---------------------------------------------------------------------------------------------------
section("Déterminisme de la guerre")
local function scenario()
  M.new_game({ patches = patches(), seed = 5 })
  war("start 4 60 6 320")
  M.run_ticks(4 * 3600)
  return M.serialize(global)
end
check(scenario() == scenario(), "deux guerres identiques produisent le même état global")

---------------------------------------------------------------------------------------------------
section("Arrêt")
M.new_game({ patches = patches() })
war("start 4 50 5 320")
M.run_ticks(3 * 3600)
war("stop")
M.run_ticks(2)
check(global.fo.war.active == false, "guerre inactive")
local left = 0
for _, e in ipairs(W().entities) do
  if e.valid and e.force.name:match("^fo%-") then left = left + 1 end
end
check(left == 0, "plus aucune entité de faction (" .. left .. " restantes)")
local ok_idle = pcall(M.run_ticks, 600)
check(ok_idle, "le jeu continue après l'arrêt")

---------------------------------------------------------------------------------------------------
section("Biomes : marais toxique et plaine de cristal")
M.new_game({ tile_at = function(x, y)
  if x > 500 then return "fo-toxic-marsh" end
  if x < -500 then return "fo-crystal-flats" end
  return "grass-1"
end })
local pc = W().player.character
pc._x = 600
local h0 = pc._health
M.run_ticks(600)
check(pc._health < h0, string.format("le marais empoisonne le joueur (%d -> %.1f PV)", h0, pc._health))
pc._x = -600
pc._health = 100
M.run_ticks(600)
check(pc._health > 100, string.format("la plaine de cristal soigne le joueur (100 -> %.1f PV)", pc._health))

---------------------------------------------------------------------------------------------------
section("Déchiqueteurs de couvée")
M.new_game({})
local brood = W().surface.create_entity({ name = "fo-brood-big-biter", position = { x = 50, y = 50 }, force = "enemy" })
brood.die(game.forces.player)
check(count_entities("fo-brood-medium-biter") == 2, "un gros déchiqueteur de couvée libère 2 déchiqueteurs moyens de couvée")
local small = W().surface.create_entity({ name = "fo-brood-small-biter", position = { x = 60, y = 50 }, force = "enemy" })
small.die(game.forces.player)
check(count_entities("fo-brood-small-biter") == 0, "le petit de couvée ne libère rien")

---------------------------------------------------------------------------------------------------
section("Interface distante (pilotage sans joueur, mod fo-autotest)")
M.new_game({ patches = patches() })
check(remote.call("factorio-overhaul", "war_start", 4, 40, 4, 320) == true, "war_start via remote")
check(remote.call("factorio-overhaul", "companions_spawn", 10, 20) == 10, "10 compagnons via remote")
remote.call("factorio-overhaul", "profiler", true)
remote.call("factorio-overhaul", "reset_stats")
M.run_ticks(3 * 3600)
remote.call("factorio-overhaul", "log_report", "minute 3")
local logged = table.concat(W().logs, "\n")
check(logged:find("[FO-AUTOTEST] ===== minute 3", 1, true) ~= nil, "rapport écrit dans le journal")
check(logged:find("[FO-BENCH]", 1, true) ~= nil and logged:find("[FO-WAR]", 1, true) ~= nil, "rapport complet (bench + guerre)")

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
