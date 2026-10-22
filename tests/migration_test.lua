--[[
  Migration d'une sauvegarde 0.2 (économie à MU) vers 0.3 (économie réelle), moteur simulé.
  Usage, depuis la racine du mod :   lua5.2 tests/migration_test.lua
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

section("Guerre en cours, puis sauvegarde au format 0.2")
M.new_game({ p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
check(remote.call("factorio-overhaul", "war_start", 4, 40, 4, 320) == true, "guerre lancée")
M.run_ticks(2 * 3600)
local war = global.fo.war
local engineers = 0
for _, f in pairs(war.factions) do
  -- Ce que contenait une faction 0.2 : registre MU, pas d'équipe ni de tableau de tâches.
  f.team, f.board = nil, nil
  f.mu, f.income = 400, 1
  f.stats = nil
  for aid in pairs(f.engineers) do
    local a = global.fo.companion.agents[aid]
    if a then
      a.machine, a.state = "engineer", "build"
      a.task = { kind = "build", outpost = 1 }
      engineers = engineers + 1
    end
  end
end
global.fo.schema = 1
check(engineers > 0, "ingénieurs 0.2 présents (" .. engineers .. ")")

section("Chargement par la version 0.3")
M.load_mod()
local ok, err = pcall(M.dispatch, W().on_config, { mod_changes = { ["factorio-overhaul"] = { old_version = "0.2.0", new_version = "0.3.0" } } })
check(ok, "on_configuration_changed sans erreur (" .. tostring(err) .. ")")
check(global.fo.schema == 2, "schéma 2")
check(global.fo.war.active == false, "guerre 0.2 arrêtée")
local told = false
for _, p in ipairs(W().game_prints) do if tostring(p):find("war%-reset%-v03") then told = true end end
check(told, "joueurs prévenus")
local left = 0
for _ in pairs(global.fo.companion.agents) do left = left + 1 end
check(left == 0, "plus aucun ingénieur 0.2 (" .. left .. ")")
check(global.fo.td ~= nil and global.fo.pteam ~= nil, "nouveaux espaces de stockage créés")
ok, err = pcall(M.run_ticks, 3600)
check(ok, "une minute de jeu après migration (" .. tostring(err) .. ")")

section("Nouvelle guerre à économie réelle")
check(remote.call("factorio-overhaul", "war_start", 4, 40, 4, 320) == true, "guerre relancée")
ok, err = pcall(M.run_ticks, 3 * 3600)
check(ok, "trois minutes de jeu (" .. tostring(err) .. ")")
local stocked = 0
for _, f in pairs(global.fo.war.factions) do
  if f.team and f.hq and f.hq.valid and f.hq.get_item_count("iron-plate") >= 0 then stocked = stocked + 1 end
end
check(stocked == 4, "quatre équipes à stock réel (" .. stocked .. ")")

---------------------------------------------------------------------------------------------------
-- Niveaux : partie 0.3.0 (10 niveaux, chantier en cours) chargée par la version à 15 époques et à
-- amélioration instantanée (lots V2 et V2c : le chantier en cours est achevé au chargement). Le cas 0.4.0
-- (chantiers des 15 époques en cours, filet sans changement de version) est dans tests/levels_test.lua.
---------------------------------------------------------------------------------------------------
section("Niveaux : sauvegarde 0.3.0 avec un chantier en cours")
local L = require("shared.levels.config")
local Foot = require("shared.levels.footprint")
M.new_game({ p_busy = 0, p_nopath = 0, p_lost = 0 })
-- Correction V3-T2 (défaut 9) : le message de migration passe par LuaForce.print, absent du moteur simulé : posé ici
-- sur les trois forces (messages relevés dans fprints).
local fprints = {}
local function force_prints()
  for _, name in ipairs({ "player", "enemy", "neutral" }) do
    rawset(game.forces[name], "print", function(msg) fprints[#fprints + 1] = { force = name, msg = msg } end)
  end
end
force_prints()
-- Prototypes des niveaux (le moteur simulé ne lit pas l'étape data).
for _, f in ipairs(L.families) do
  for n = 1, f.max do
    local cb = Foot.proto_boxes(L.footprint(f, n))
    rawset(W().prototypes, L.name(f, n), {
      type = f.type, max_health = 1000,
      selection_box = { left_top = { x = -f.size / 2, y = -f.size / 2 }, right_bottom = { x = f.size / 2, y = f.size / 2 } },
      -- Lot V3-T : masque de collision (place d'un agrandissement ; le moteur simulé n'a pas d'étape data).
      collision_mask = { ["object-layer"] = true, ["player-layer"] = true, ["water-tile"] = true },
      -- Suite d'intégration de V3-T : boîte de collision du niveau (table L.footprints), comme l'étape data la
      -- pose ; le moteur simulé en tire bounding_box et la recherche par zone.
      collision_box = cb,
    })
  end
end
rawset(W().prototypes, "stone-wall", { type = "wall", max_health = 350, collision_mask = { ["object-layer"] = true } })
local s = game.surfaces[1]
-- Entités telles que 0.3.0 les a laissées : centre niveau 9, mitrailleuse au niveau maximal de 0.3.0 (10),
-- mur niveau 10, foreuse en chantier 9 → 10 (hors service), foreuse dont le chantier a perdu son bâtiment.
local cc = s.create_entity({ name = "fo-lvl-command-9", position = { x = 0.5, y = 0.5 }, force = "player" })
local gun = s.create_entity({ name = "fo-lvl-gun-10", position = { x = 10, y = 10 }, force = "player" })
gun.insert({ name = "firearm-magazine", count = 20 })
local wall = s.create_entity({ name = "fo-lvl-wall-10", position = { x = 20.5, y = 10.5 }, force = "player" })
-- 0.3.0 : un mur niveau 10 avait 3 712 PV ; V2 lui en donne 1 925 (ici : maximum simulé 1 000). La santé
-- enregistrée dans la sauvegarde peut dépasser le nouveau maximum.
rawset(wall, "_health", 3711.6)
-- Lot V3-T : mitrailleuses posées à l'ANCIENNE taille (2×2, position entière) que le lot V3-T agrandit : niveau 8
-- (3×3) bloqué par deux murs au nord et au sud (aucune des 4 positions candidates n'est libre), niveau 14 (4×4,
-- côté pair : déjà sur la grille, place libre), niveau 12 (3×3) dont un chantier 0.4.0 vise le niveau 13 (4×4).
local gun_blocked = s.create_entity({ name = "fo-lvl-gun-8", position = { x = 50, y = 50 }, force = "player" })
gun_blocked.insert({ name = "firearm-magazine", count = 5 })
s.create_entity({ name = "stone-wall", position = { x = 50.5, y = 48.5 }, force = "player" })
s.create_entity({ name = "stone-wall", position = { x = 50.5, y = 51.5 }, force = "player" })
local gun_even = s.create_entity({ name = "fo-lvl-gun-14", position = { x = 70, y = 70 }, force = "player" })
local gun_job = s.create_entity({ name = "fo-lvl-gun-12", position = { x = 90, y = 90 }, force = "player" })
gun_job.insert({ name = "piercing-rounds-magazine", count = 7 })
local drill = s.create_entity({ name = "fo-lvl-drill-9", position = { x = 30, y = 30 }, force = "player" })
drill.active = false
local ghost = s.create_entity({ name = "fo-lvl-drill-5", position = { x = 40, y = 30 }, force = "player" })
local function job_030(e, family, to, left)
  -- Forme exacte d'un chantier 0.3.0 (script/levels/levels.lua de la session 5).
  local j = { entity = e, unit = e.unit_number, force = "player", family = family, to = to, start = game.tick,
              finish = game.tick + left, cost = { { "iron-plate", 510 }, { "fo-resonance-crystal", 9 }, { "fo-retired-item", 4 } } }
  j.r_bg = rendering.draw_rectangle({ color = { r = 0, g = 0, b = 0 }, filled = true, surface = s, left_top = e, right_bottom = e })
  j.r_fg = rendering.draw_rectangle({ color = { r = 1, g = 1, b = 0 }, filled = true, surface = s, left_top = e, right_bottom = e })
  j.r_text = rendering.draw_text({ text = "x", surface = s, target = e, color = { r = 1, g = 1, b = 1 } })
  j.bar_w, j.bar_top = 3, -2
  return j
end
global.fo.levels = {
  cc = { player = cc },
  jobs = { [drill.unit_number] = job_030(drill, "drill", 10, 600), [ghost.unit_number] = job_030(ghost, "drill", 6, 600),
           [gun_job.unit_number] = job_030(gun_job, "gun", 13, 600) },
  busy = { player = 2 },
  replacing = false,
  time_factor = nil,
  stats = { upgrades = 12, instant = 40, cancelled = 1, lost = 0 },
}
ghost.destroy()
local saved = M.deepcopy_global(global)

section("Chargement par la version à amélioration instantanée (lot V2c)")
M.load_mod()
-- Un objet de coût d'un ancien chantier a disparu du jeu (table d'indirection changée depuis) : le chantier
-- est achevé quand même (son coût est déjà payé, il n'est plus relu).
local known_items = game.item_prototypes
game.item_prototypes = setmetatable({}, { __index = function(_, name)
  if name == "fo-retired-item" then return nil end
  return known_items[name]
end })
_G.global = saved
local renders = { global.fo.levels.jobs[drill.unit_number].r_bg, global.fo.levels.jobs[drill.unit_number].r_text }
ok, err = pcall(function() W().on_load() end)
check(ok, "on_load sans erreur (" .. tostring(err) .. ")")
ok, err = pcall(M.dispatch, W().on_config, { mod_changes = { ["factorio-overhaul"] = { old_version = "0.3.0", new_version = "0.4.1" } } })
check(ok, "on_configuration_changed sans erreur (" .. tostring(err) .. ")")
local Levels = require("script.levels.levels")
local force = game.forces.player
local lv = global.fo.levels
check(Levels.cc_level(force) == 9, "centre niveau 9 reconnu (époque 9)")
check(L.max_level(L.by_key.gun, Levels.cc_level(force)) == 18, "plafond porté à 18 (0.3.0 : 10)")
-- Suite d'intégration de V3-T : position attendue d'un bâtiment de la sauvegarde CALCULÉE depuis la table
-- L.footprints. `sides` : côtés successifs (celui de la sauvegarde d'avant V3-T, puis celui de chaque niveau) ; à
-- chaque changement de côté, la candidate préférée de la règle d'agrandissement (shared/levels/footprint.lua ; les
-- zones de ce test sont libres). Table livrée (seule la mitrailleuse grandit) : la foreuse et le centre restent.
-- Lot V3-T2 : l'emprise actuelle d'un bâtiment HORS grille est le carré de côté + 1 qui le contient exactement
-- (Levels.current_box) ; ce banc pose la foreuse 9 en (30 ; 30), position entière qu'un 3×3 n'a jamais en moteur réel.
local function current_box(at, side)
  if side >= 2 and not Foot.aligned(at, side) then return Foot.tile_box(at, side + 1) end
  return Foot.tile_box(at, side)
end
local function expected_at(pos, sides)
  local at = { x = pos.x, y = pos.y }
  for i = 2, #sides do
    if sides[i] ~= sides[i - 1] then
      local c = Foot.candidates(current_box(at, sides[i - 1]), sides[i])[1]
      at = { x = c.x, y = c.y }
    end
  end
  return at
end
local function moved_by_table(pos, f, n)
  local at = expected_at(pos, { f.size, L.footprint(f, n) })
  return at.x ~= pos.x or at.y ~= pos.y
end
-- Décision V2c : un chantier en cours (déjà payé) est ACHEVÉ au chargement (pas annulé ni remboursé).
local DR = L.by_key.drill
local d10_at = expected_at({ x = 30, y = 30 }, { DR.size, L.footprint(DR, 9), L.footprint(DR, 10) })
local d10 = s.find_entity("fo-lvl-drill-10", d10_at)
check(d10 ~= nil and d10.position.x == d10_at.x and d10.position.y == d10_at.y and d10.active ~= false and not drill.valid,
  "chantier 0.3.0 achevé au chargement : foreuse niveau 10 posée (" .. d10_at.x .. " ; " .. d10_at.y .. "), en service")
-- Correction de la suite : la boîte de ces prototypes est au format de l'ÉTAPE DATA ({ {x, y}, {x, y} },
-- Foot.proto_boxes) ; le moteur simulé doit la lire (bounding_box = ± (côté / 2 − MARGIN) autour de la position).
do
  local h = L.footprint(DR, 10) / 2 - Foot.MARGIN
  local bb = d10 and d10.bounding_box
  local function near(a, b) return math.abs(a - b) < 1e-9 end
  check(bb ~= nil and near(bb.left_top.x, d10_at.x - h) and near(bb.left_top.y, d10_at.y - h)
    and near(bb.right_bottom.x, d10_at.x + h) and near(bb.right_bottom.y, d10_at.y + h),
    "moteur simulé : boîte au format de l'étape data lue (foreuse 10 : ± " .. h .. " autour de sa position)")
end
check(next(lv.jobs) == nil and next(lv.busy) == nil and lv.time_factor == nil, "plus aucun chantier, ouvrier ni réglage de durée enregistré")
check(lv.stats.upgrades == 14 and lv.stats.lost == 1 and lv.stats.cancelled == 1 and lv.stats.instant == 40,
  "statistiques 0.3.0 conservées : +2 achevés (foreuse, mitrailleuse), +1 perdu (chantier sans bâtiment) (" .. lv.stats.upgrades .. ", " .. lv.stats.lost .. ")")
-- Lot V3-T : emprises. Sauvegarde d'avant V3-T (aucun relevé) : les mitrailleuses de niveau 7 et plus sont
-- reposées par la règle d'agrandissement (shared/levels/footprint.lua).
local old_gun = gun
gun = s.find_entity("fo-lvl-gun-10", { x = 9.5, y = 9.5 })
check(not old_gun.valid and gun ~= nil and gun.position.x == 9.5 and gun.position.y == 9.5,
  "V3-T : mitrailleuse 10 (2×2 → 3×3) reposée à la position préférée (9,5 ; 9,5 : nord-ouest, côté impair)")
check(gun and gun.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine") == 20,
  "V3-T : munitions transférées à la mitrailleuse reposée")
check(gun_blocked.valid and gun_blocked.position.x == 50 and gun_blocked.get_item_count("firearm-magazine") == 5,
  "V3-T : mitrailleuse 8 sans place libre (murs au nord et au sud) LAISSÉE en place, munitions comprises")
local kept_logged = false
for _, line in ipairs(W().logs) do if line:find("fo-lvl-gun-8", 1, true) and line:find("laissé en place", 1, true) then kept_logged = true end end
check(kept_logged, "V3-T : bâtiment laissé faute de place journalisé ([FO-LEVELS] emprise)")
-- Correction V3-T2 (défaut 9) : les joueurs de la force sont prévenus, une fois, avec le nombre et un lien de carte.
do
  local kept_msgs = {}
  for _, m in ipairs(fprints) do
    if type(m.msg) == "table" and m.msg[1] == "fo-levels-taille.migration-kept" then kept_msgs[#kept_msgs + 1] = m end
  end
  local m = kept_msgs[1]
  check(#kept_msgs == 1 and m.force == "player" and m.msg[2] == 1 and m.msg[3] == "[gps=50,50]",
    "V3-T2 : message unique à la force après la migration : 1 bâtiment laissé hors grille, lien [gps=50,50] ("
    .. tostring(#kept_msgs) .. " message(s))")
end
check(gun_even.valid and gun_even.position.x == 70, "V3-T : mitrailleuse 14 (2×2 → 4×4, déjà sur la grille, place libre) : même entité, rien à faire")
local g13 = s.find_entity("fo-lvl-gun-13", { x = 90, y = 90 })
check(g13 ~= nil and g13.position.x == 90 and g13.position.y == 90 and not gun_job.valid
  and g13.get_item_count("piercing-rounds-magazine") == 7,
  "V3-T : chantier 0.4.0 d'une mitrailleuse 12 → 13 : bâtiment reposé (3×3) puis chantier ACHEVÉ en 4×4, revenu au centre d'origine, munitions comprises")
-- Reposés : les 2 mitrailleuses, plus la foreuse 9 et le centre 9 si la table les fait grandir hors de leur place
-- (calculé ; 0 avec la table livrée).
local want_moved = 2 + (moved_by_table({ x = 30, y = 30 }, DR, 9) and 1 or 0)
  + (moved_by_table({ x = 0.5, y = 0.5 }, L.by_key.command, 9) and 1 or 0)
check(lv.stats.migrated == want_moved and lv.stats.overlap_kept == 1 and (lv.stats.forced or 0) == 0,
  "V3-T : statistiques de migration (" .. want_moved .. " reposées, 1 laissée, 0 forcée) (" .. tostring(lv.stats.migrated) .. ", "
  .. tostring(lv.stats.overlap_kept) .. ", " .. tostring(lv.stats.forced) .. ")")
-- Le centre a pu être reposé (ligne « command » de la table) : la suite vise le centre SUIVI par la force.
local cc_now = Levels.cc(force)
check(cc_now and cc_now.valid and cc_now.name == "fo-lvl-command-9" and (cc_now == cc) == not moved_by_table({ x = 0.5, y = 0.5 }, L.by_key.command, 9),
  "centre 9 suivi après la migration (même entité si la table ne le fait pas grandir hors de sa place)")
cc = cc_now
-- Suite d'intégration de V3-T : relevé comparé à la TABLE (L.footprint), famille par famille, niveau par niveau.
local relev_ok = lv.footprints ~= nil
for _, f in ipairs(L.families) do
  for n = 1, f.max do
    if not (relev_ok and lv.footprints[f.key] and lv.footprints[f.key][n] == L.footprint(f, n)) then relev_ok = false end
  end
end
check(relev_ok and lv.footprints.gun[6] == 2 and lv.footprints.gun[7] == 3 and lv.footprints.gun[30] == 6,
  "V3-T : relevé des emprises de la sauvegarde mis à jour (= L.footprint pour chaque famille et chaque niveau)")
local migrated0, kept0 = lv.stats.migrated, lv.stats.overlap_kept
local function emprise_lines()
  local n = 0
  for _, line in ipairs(W().logs) do if line:find("[FO-LEVELS] emprise", 1, true) then n = n + 1 end end
  return n
end
local lines0 = emprise_lines()
-- (Changement de configuration envoyé à la main : un autre mod mis à jour, par exemple.)
ok, err = pcall(M.dispatch, W().on_config, { mod_changes = { ["other-mod"] = { old_version = "1.0.0", new_version = "1.0.1" } } })
-- Correction V3-T (défaut 15) : le relevé est RELU, pas seulement le compteur de déplacements : aucun bâtiment
-- réexaminé, aucun « laissé en place » recompté ni rejournalisé.
check(ok and lv.stats.migrated == migrated0 and lv.stats.overlap_kept == kept0 and emprise_lines() == lines0
  and gun.valid and gun_blocked.valid,
  "V3-T : second changement de configuration : relevé à jour, aucune nouvelle migration, rien de recompté ni de rejournalisé ("
  .. tostring(err) .. ")")
local drawn = 0
for _, id in ipairs(renders) do if rendering.is_valid(id) then drawn = drawn + 1 end end
check(drawn == 0, "barre de progression du chantier 0.3.0 effacée")
check(wall.valid and math.abs(wall.health - 1000) < 1e-9, "mur 0.3.0 : PV ramenés au nouveau maximum (" .. tostring(wall.health) .. ")")
local info = Levels.preview(gun, nil)
check(info and info.next == 11 and info.reason == "no-resources", "mitrailleuse 10 → 11 désormais possible (il ne manque que les ressources)")
-- Q16 : centre 9 → 10 exige un bâtiment au niveau 18 dans chaque famille possédée (mitrailleuse, mur, foreuse).
info = Levels.preview(cc, nil)
check(info and info.next == 10 and info.reason == "cc-families" and info.condition_level == 18 and #info.blocking == 3
  and info.blocking[1] == "gun" and info.blocking[2] == "wall" and info.blocking[3] == "drill",
  "centre 9 → 10 : condition Q16 au niveau 18, mitrailleuse, mur et foreuse bloquent (" .. tostring(info and info.reason) .. ")")
ok, err = pcall(M.run_ticks, 630)
check(ok, "dix secondes de jeu après le chargement (" .. tostring(err) .. ")")
check(gun.valid and gun.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine") == 20
  and wall.valid, "bâtiments 0.3.0 intacts (munitions comprises)")
for _, c in ipairs(L.cost(L.by_key.gun, 11)) do cc.get_inventory(defines.inventory.chest).insert({ name = c[1], count = c[2] }) end
local r_ok, r_why, _, g11 = Levels.start(gun, nil)
check(r_ok and r_why == "done" and g11 and g11.name == "fo-lvl-gun-11", "mitrailleuse 0.3.0 au niveau 10 : niveau 11 aussitôt (" .. tostring(r_why) .. ")")
check(g11 and g11.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine") == 20, "munitions conservées au niveau 11")
-- Interface distante de 0.4.0 (mod de test, scénarios) : levels_time_factor est sans effet (ou retiré par le
-- diff proposé à l'intégrateur pour script/remote.lua) ; levels_status ne compte ni ouvrier ni chantier (ou ne
-- renvoie plus ces champs).
local iface = W().remote["factorio-overhaul"]
ok, err = true, nil
if iface.levels_time_factor then ok, err = pcall(remote.call, "factorio-overhaul", "levels_time_factor", 0.5) end
local st = remote.call("factorio-overhaul", "levels_status", "player")
check(ok and st and (st.busy or 0) == 0 and (st.jobs or 0) == 0 and st.cc_level == 9,
  "interface distante (levels_time_factor, levels_status) : sans erreur, 0 ouvrier, 0 chantier (" .. tostring(err) .. ")")
for _, c in ipairs(L.cost(L.by_key.gun, 12)) do cc.get_inventory(defines.inventory.chest).insert({ name = c[1], count = c[2] }) end
local rr = remote.call("factorio-overhaul", "levels_upgrade", g11)
check(rr and rr.ok and rr.reason == "done" and s.find_entity("fo-lvl-gun-12", { x = 9.5, y = 9.5 }) ~= nil,
  "levels_time_factor ignoré : levels_upgrade toujours instantané (" .. tostring(rr and rr.reason) .. ")")

---------------------------------------------------------------------------------------------------
-- Lot V3-T, corrections (défauts 1, 11, 12, 13) : sauvegarde 0.4.1 (d'avant V3-T, sans relevé des emprises)
-- rechargée SANS changement de version ni de prototypes. Le moteur n'appelle PAS on_configuration_changed (doc
-- 1.1.91) : ce test n'en envoie aucun, seul le filet on_nth_tick(30) peut migrer. Le moteur simulé applique ici
-- le NOUVEAU prototype aux bâtiments posés à l'ancienne taille (hypothèse H-T3) : leur boîte suit le
-- prototype, voisins non encore migrés compris.
---------------------------------------------------------------------------------------------------
section("V3-T : sauvegarde 0.4.1 rechargée sans changement de version (filet), voisins déjà grossis, chantier forcé")
M.new_game({ p_busy = 0, p_nopath = 0, p_lost = 0 })
force_prints()
local L3 = require("shared.levels.config")       -- instance chargée par le mod (M.load_mod vide le cache)
local Foot3 = require("shared.levels.footprint")
local Levels3 = require("script.levels.levels")
local s3 = game.surfaces[1]
local MASK3 = { ["object-layer"] = true, ["player-layer"] = true, ["water-tile"] = true, ["item-layer"] = true }
local function set_protos()
  for _, f in ipairs(L3.families) do
    for n = 1, f.max do
      local cb = Foot3.proto_boxes(L3.footprint(f, n))
      rawset(W().prototypes, L3.name(f, n), {
        type = f.type, max_health = 1000, collision_mask = MASK3,
        selection_box = { left_top = { x = -f.size / 2, y = -f.size / 2 }, right_bottom = { x = f.size / 2, y = f.size / 2 } },
        collision_box = { left_top = { x = cb[1][1], y = cb[1][2] }, right_bottom = { x = cb[2][1], y = cb[2][2] } },
      })
    end
  end
end
set_protos()
rawset(W().prototypes, "stone-wall", { type = "wall", max_health = 350, collision_mask = MASK3 })
-- Boîte de collision (bounding_box) et recherche par zone (« entities colliding with that area », doc 1.1.91) :
-- le moteur simulé les fait suivre la boîte du prototype (tests/mock_engine.lua, suite d'intégration de V3-T ;
-- l'enveloppe locale qui le faisait ici en attendant est retirée). Un voisin déjà grossi qui déborde dans la
-- zone est donc vu.
local hooked = {}
table.insert(Levels3.on_replaced, function(old_unit, new) hooked[#hooked + 1] = { old_unit, new } end)
-- Bâtiments posés par 0.4.1 à l'ANCIENNE taille (2×2, positions entières) :
--   - mitrailleuse 8 seule, à 50 % de PV, 9 chargeurs ;
--   - deux mitrailleuses 8 COLLÉES (2×2 bord à bord) : une fois grossies en 3×3 sur place, elles se chevauchent ;
--   - mitrailleuse 6 entourée de murs, avec un chantier 0.4.0 payé vers le niveau 7 (3×3) : aucune place.
local g8 = s3.create_entity({ name = "fo-lvl-gun-8", position = { x = 10, y = 10 }, force = "player" })
g8.insert({ name = "firearm-magazine", count = 9 })
g8.health = 500
local na = s3.create_entity({ name = "fo-lvl-gun-8", position = { x = 30, y = 10 }, force = "player" })
local nb = s3.create_entity({ name = "fo-lvl-gun-8", position = { x = 32, y = 10 }, force = "player" })
local g6 = s3.create_entity({ name = "fo-lvl-gun-6", position = { x = 50, y = 50 }, force = "player" })
g6.insert({ name = "piercing-rounds-magazine", count = 3 })
s3.create_entity({ name = "stone-wall", position = { x = 49.5, y = 48.5 }, force = "player" })
s3.create_entity({ name = "stone-wall", position = { x = 49.5, y = 51.5 }, force = "player" })
--   - mitrailleuse 6 avec un chantier vers 7 : eau au nord (rangée y = 48), mur au sud-ouest : aucune place ;
--     le chantier forcé prend la position la plus facile à libérer (sud-ouest), jamais l'eau.
local gw6 = s3.create_entity({ name = "fo-lvl-gun-6", position = { x = 70, y = 50 }, force = "player" })
s3.create_entity({ name = "stone-wall", position = { x = 69.5, y = 51.5 }, force = "player" })
local WATER3 = { ["69,48"] = "water", ["70,48"] = "water" }
local raw_tile_at = W().tile_at
W().tile_at = function(x, y) return WATER3[x .. "," .. y] or (raw_tile_at and raw_tile_at(x, y)) or "grass-1" end
local units = { g8 = g8.unit_number, na = na.unit_number, nb = nb.unit_number }
local lv3 = global.fo.levels
lv3.footprints = nil  -- sauvegarde d'avant V3-T : aucun relevé
lv3.jobs = { [g6.unit_number] = { entity = g6, unit = g6.unit_number, force = "player", family = "gun", to = 7,
  cost = { { "iron-plate", 10 } } },
  [gw6.unit_number] = { entity = gw6, unit = gw6.unit_number, force = "player", family = "gun", to = 7,
  cost = { { "iron-plate", 10 } } } }
local logs0 = #W().logs
check(Levels3.footprints_stale(), "filet : relevé absent → emprises à migrer")
ok, err = pcall(M.run_ticks, 30)
check(ok, "30 ticks sans changement de configuration (" .. tostring(err) .. ")")
local function find_log(pat, from)
  for i = (from or 0) + 1, #W().logs do if W().logs[i]:find(pat, 1, true) then return W().logs[i] end end
  return nil
end
local n8 = s3.find_entity("fo-lvl-gun-8", { x = 9.5, y = 9.5 })
check(lv3.footprints and lv3.footprints.gun[8] == 3 and not Levels3.footprints_stale() and find_log("emprises (filet", logs0),
  "filet on_nth_tick(30) : sauvegarde 0.4.1 SANS on_configuration_changed migrée au premier passage, relevé écrit, journalisé")
-- Défaut 12 : PV en proportion, crochets on_replaced appelés pendant la MIGRATION.
check(n8 and not g8.valid and math.abs(n8.get_health_ratio() - 0.5) < 1e-9 and n8.get_item_count("firearm-magazine") == 9,
  "migration : mitrailleuse 8 reposée en 3×3 (9,5 ; 9,5), PV en proportion (50 %), munitions transférées")
local seen = {}
for _, h in ipairs(hooked) do seen[h[1]] = h[2] end
check(seen[units.g8] == n8 and seen[units.na] ~= nil and seen[units.nb] ~= nil,
  "migration : crochets Levels.on_replaced appelés avec l'ancien numéro (le panneau ouvert suit le bâtiment reposé)")
-- Défaut 12 : voisins non encore migrés dont la boîte a DÉJÀ grossi (H-T3).
local ma, mb = seen[units.na], seen[units.nb]
local function overlap_bb(a, b)
  local x, y = a.bounding_box, b.bounding_box
  return x.left_top.x < y.right_bottom.x and y.left_top.x < x.right_bottom.x and x.left_top.y < y.right_bottom.y and y.left_top.y < x.right_bottom.y
end
check(ma and mb and ma.position.x == 29.5 and mb.position.x == 32.5 and ma.position.y == 9.5 and mb.position.y == 9.5
  and not overlap_bb(ma, mb),
  "migration : deux mitrailleuses collées, déjà grossies sur place (chevauchement), reposées sans chevauchement (29,5 et 32,5 : nord-ouest puis nord-est)")
-- Défaut 13 : chantier hérité payé, aucune place → position forcée (chevauchement toléré), compté, journalisé.
local g7 = s3.find_entity("fo-lvl-gun-7", { x = 49.5, y = 49.5 })
local gw7 = s3.find_entity("fo-lvl-gun-7", { x = 69.5, y = 50.5 })
check(g7 and not g6.valid and g7.get_item_count("piercing-rounds-magazine") == 3 and lv3.stats.forced == 2
  and find_log("agrandissement forcé", logs0) and next(lv3.jobs) == nil,
  "chantiers 0.4.0 payés (6 → 7) sans place : achevés quand même à la position montrée, comptés (forced = 2), journalisés, munitions comprises")
check(gw7 ~= nil and gw7.position.x == 69.5 and gw7.position.y == 50.5 and not gw6.valid,
  "chantier forcé : position la plus facile à libérer (sud-ouest, un mur), jamais la préférée dans l'eau")
check(lv3.stats.migrated == 3 and (lv3.stats.overlap_kept or 0) == 0, "statistiques : 3 reposées, 0 laissée (" .. tostring(lv3.stats.migrated) .. ")")
-- Suite d'intégration de V3-T : décors retirés par le moteur simulé (tests/mock_engine.lua), une zone par bâtiment
-- reposé, carrée, du côté du nouveau bâtiment (3×3 ici : toutes ces mitrailleuses passent en 3×3).
local cleared, square3 = W().decoratives_cleared or {}, true
for _, a in ipairs(cleared) do
  if a[2][1] - a[1][1] ~= 3 or a[2][2] - a[1][2] ~= 3 then square3 = false end
end
check(#cleared == lv3.stats.resized and #cleared == 5 and square3,
  "décors retirés sous chaque bâtiment reposé : " .. #cleared .. " zones 3×3 pour " .. tostring(lv3.stats.resized) .. " remplacements (3 migrées, 2 forcées)")
-- Le filet ne refait rien ensuite (relevé à jour).
local m3, k3, l3 = lv3.stats.migrated, lv3.stats.overlap_kept or 0, #W().logs
ok, err = pcall(M.run_ticks, 90)
check(ok and lv3.stats.migrated == m3 and (lv3.stats.overlap_kept or 0) == k3 and not find_log("[FO-LEVELS] emprise", l3),
  "filet : 3 passages de plus, rien à refaire, rien de journalisé (" .. tostring(err) .. ")")
-- Défaut 12 : CENTRE suivi pendant la migration. Ligne « command » temporaire (activation par la table) : le
-- centre 9 passe de 4×4 à 6×6 ; un mur bloque les positions centrée, sud et est : il est reposé à l'ouest.
local before_cmd = L3.footprints.command  -- remise ensuite telle quelle (suite d'intégration de V3-T)
-- Sauvegarde écrite AVANT l'activation de la ligne : relevé du centre au côté de base (sans effet avec la table
-- livrée ; nécessaire quand la ligne « command » y est déjà, sinon rien ne change entre relevé et table).
for n = 1, L3.by_key.command.max do lv3.footprints.command[n] = L3.by_key.command.size end
L3.footprints.command = { era = { 4, 5, 6, 7, 8 } }
set_protos()
local cc3 = s3.create_entity({ name = "fo-lvl-command-9", position = { x = 100, y = 100 }, force = "player" })
cc3.get_inventory(defines.inventory.chest).insert({ name = "iron-plate", count = 77 })
lv3.cc.player = cc3
s3.create_entity({ name = "stone-wall", position = { x = 102.5, y = 100.5 }, force = "player" })
local cc_unit = cc3.unit_number
ok, err = pcall(M.run_ticks, 30)
local cc_new
for _, h in ipairs(hooked) do if h[1] == cc_unit then cc_new = h[2] end end
check(ok and cc_new and not cc3.valid and cc_new.position.x == 99 and cc_new.position.y == 100 and lv3.cc.player == cc_new
  and Levels3.cc(game.forces.player) == cc_new and cc_new.get_item_count("iron-plate") == 77,
  "migration du centre (ligne « command » activée) : reposé à l'ouest (99 ; 100), SUIVI comme centre de la force, coffre transféré ("
  .. tostring(err) .. ")")
ok, err = pcall(M.dispatch, W().on_config, { mod_changes = { ["factorio-overhaul"] = { old_version = "0.4.1", new_version = "0.4.2" } } })
check(ok and lv3.cc.player == cc_new and Levels3.cc_level(game.forces.player) == 9,
  "réparation au changement de version : le centre reposé reste le centre (pas oublié) (" .. tostring(err) .. ")")
L3.footprints.command = before_cmd

-- Suite d'intégration de V3-T : Levels.transfer sur des entités du MOTEUR SIMULÉ (plus de doublure) : réglages du
-- circuit d'une foreuse (get_control_behavior, get_or_create_control_behavior) et recette d'un assembleur
-- (get_recipe, set_recipe), ce qu'un agrandissement de foreuse ou d'assembleur transfère.
local dra = s3.create_entity({ name = "fo-lvl-drill-12", position = { x = 200.5, y = 200.5 }, force = "player" })
local drb = s3.create_entity({ name = "fo-lvl-drill-13", position = { x = 210, y = 200 }, force = "player" })
check(dra.get_control_behavior() == nil, "moteur simulé : une foreuse sans fil ni réglage n'a pas de comportement de circuit (nil, comme le moteur)")
local cba = dra.get_or_create_control_behavior()
cba.circuit_enable_disable, cba.circuit_read_resources, cba.resource_read_mode = true, true, 1
cba.circuit_condition = { condition = { comparator = ">", first_signal = { type = "item", name = "iron-ore" }, constant = 50 } }
-- Correction de la suite : réseau logistique et condition logistique aussi réglés hors de leurs valeurs par défaut
-- (avant, seul « false » était vérifié : une régression de leur transfert passait inaperçue).
cba.connect_to_logistic_network = true
cba.logistic_condition = { condition = { comparator = "=", first_signal = { type = "item", name = "copper-ore" }, constant = 7 } }
local asa = s3.create_entity({ name = "fo-lvl-assembler-12", position = { x = 220.5, y = 200.5 }, force = "player" })
local asb = s3.create_entity({ name = "fo-lvl-assembler-13", position = { x = 230, y = 200 }, force = "player" })
asa.set_recipe("iron-gear-wheel")
asa.insert({ name = "iron-plate", count = 6 })
local ok_tr, err_tr = pcall(function() Levels3.transfer(dra, drb); Levels3.transfer(asa, asb) end)
local cbb = drb.get_control_behavior()
check(ok_tr and cbb and cbb.circuit_enable_disable == true and cbb.circuit_read_resources == true and cbb.resource_read_mode == 1
  and cbb.connect_to_logistic_network == true and cbb.circuit_condition.condition.comparator == ">"
  and cbb.circuit_condition.condition.constant == 50
  and cbb.logistic_condition.condition.comparator == "=" and cbb.logistic_condition.condition.constant == 7
  and cbb.logistic_condition.condition.first_signal.name == "copper-ore",
  "Levels.transfer en moteur simulé : réglages du circuit de la foreuse recopiés (activation, lecture, mode, condition, réseau et condition logistiques) ("
  .. tostring(err_tr) .. ")")
check(ok_tr and asb.get_recipe() and asb.get_recipe().name == "iron-gear-wheel" and asb.get_item_count("iron-plate") == 6
  and asa.get_item_count("iron-plate") == 0,
  "Levels.transfer en moteur simulé : recette de l'assembleur recopiée, contenu transféré")

-- Lot V3-T2 (F83, moteur réel : un four neuf ignore l'écriture de crafting_progress, et une fabrication en cours a
-- déjà pris ses ingrédients) : Levels.transfer d'une machine EN FABRICATION rend ses ingrédients à la nouvelle
-- machine et note la progression, que Levels.resume_progress repose dès que la nouvelle fabrique la même recette.
-- Le moteur simulé n'a ni is_crafting ni ingrédients de recette : posés sur ces deux entités seulement.
do
  local asc = s3.create_entity({ name = "fo-lvl-assembler-12", position = { x = 240.5, y = 200.5 }, force = "player" })
  local asd = s3.create_entity({ name = "fo-lvl-assembler-13", position = { x = 250, y = 200 }, force = "player" })
  asc.set_recipe("iron-gear-wheel")
  asc.insert({ name = "iron-plate", count = 4 })
  rawset(asc, "is_crafting", function() return true end)
  rawset(asc, "crafting_progress", 0.4)
  rawset(asc, "get_recipe", function()
    return { name = "iron-gear-wheel", valid = true, ingredients = { { type = "item", name = "iron-plate", amount = 2 } } }
  end)
  local crafting = false
  rawset(asd, "is_crafting", function() return crafting end)
  rawset(asd, "crafting_progress", 0) -- champ écrivable (le moteur simulé refuse toute écriture inconnue)
  local resumed0 = lv3.stats.resumed or 0
  local ok_r, err_r = pcall(Levels3.transfer, asc, asd)
  local pend = lv3.pending and lv3.pending[asd.unit_number]
  check(ok_r and asd.get_item_count("iron-plate") == 6 and pend and pend.progress == 0.4 and pend.recipe == "iron-gear-wheel"
    and (rawget(asd, "crafting_progress") or 0) == 0,
    "fabrication en cours : ingrédients rendus (4 + 2 plaques), progression 0,4 notée, pas écrite sur la machine neuve (" .. tostring(err_r) .. ")")
  local n1 = Levels3.resume_progress()
  check(n1 == 0 and lv3.pending[asd.unit_number] ~= nil, "progression notée gardée tant que la machine neuve ne fabrique pas")
  crafting = true
  local n2 = Levels3.resume_progress()
  check(n2 == 1 and asd.crafting_progress == 0.4 and lv3.pending[asd.unit_number] == nil and (lv3.stats.resumed or 0) == resumed0 + 1,
    "la machine neuve fabrique la même recette : progression reposée (0,4), entrée retirée, comptée")
  -- Autre recette au redémarrage : rien n'est écrit, l'entrée est retirée (les ingrédients sont déjà rendus).
  local ase = s3.create_entity({ name = "fo-lvl-assembler-13", position = { x = 260, y = 200 }, force = "player" })
  lv3.pending[ase.unit_number] = { entity = ase, recipe = "copper-cable", progress = 0.7, bonus = 0, tick = game.tick }
  ase.set_recipe("iron-gear-wheel")
  rawset(ase, "is_crafting", function() return true end)
  rawset(ase, "crafting_progress", 0)
  local n3 = Levels3.resume_progress()
  check(n3 == 0 and lv3.pending[ase.unit_number] == nil and (rawget(ase, "crafting_progress") or 0) == 0,
    "redémarrage sur une autre recette : progression NON reposée, entrée retirée")
  for _, e in ipairs({ asc, asd, ase }) do if e.valid then e.destroy() end end
end

-- Lot V3-T2 (F86, moteur réel : create_entity{fast_replace = true} d'un bâtiment HORS grille recale la position, ne
-- remplace rien et pose un second bâtiment par-dessus) : un bâtiment hors grille passe par le remplacement par
-- script, même à côté égal, et revient sur la grille à une demi-tuile (Levels.current_box).
do
  local cc9 = Levels3.cc(game.forces.player)
  local as8 = s3.create_entity({ name = "fo-lvl-assembler-8", position = { x = 300.5, y = 300.5 }, force = "player" })
  local side = L3.footprint(L3.by_key.assembler, 8)
  local info = Levels3.preview(as8, nil, true)
  local off = side % 2 == 0 -- (300,5 ; 300,5) : hors grille pour un côté pair
  check(off and info and info.resize and info.resize.regrid == true and info.resize.from == side and info.resize.to == side
    and info.room and info.room.chosen ~= nil,
    "bâtiment hors grille (assembleur 8, " .. side .. "×" .. side .. " centré sur une tuile) : l'aperçu demande une remise sur la grille, place libre")
  for _, c in ipairs(L3.cost(L3.by_key.assembler, 9)) do cc9.get_inventory(defines.inventory.chest).insert({ name = c[1], count = c[2] }) end
  local r0, fb0 = lv3.stats.resized or 0, lv3.stats.fallback or 0
  local ok_s, why, _, a9 = Levels3.start(as8, nil)
  local want = Foot3.candidates(Foot3.tile_box({ x = 300.5, y = 300.5 }, side + 1), side)[1]
  check(ok_s and a9 and a9.name == "fo-lvl-assembler-9" and not as8.valid and a9.position.x == want.x and a9.position.y == want.y
    and lv3.stats.resized == r0 + 1 and (lv3.stats.fallback or 0) == fb0,
    "amélioration à côté égal d'un bâtiment hors grille : par script (pas de remplacement rapide), reposé sur la grille en ("
    .. want.x .. " ; " .. want.y .. "), l'ancien retiré (" .. tostring(why) .. ")")
  if a9 and a9.valid then a9.destroy() end
end

-- Correction V3-T2 (défauts 2, 15 et 16) : progression notée (pending) qui suit la machine dans TOUS les chemins.
-- Mutations jouées par le correcteur et qui survivaient : m7 (le remplacement rapide ne fait plus suivre l'entrée) et
-- m9 (la branche « en attente » de Levels.transfer désactivée) ; et le défaut 2/15 : la machine a déjà REPRIS une
-- fabrication (ingrédients rendus consommés) quand une seconde amélioration arrive avant le on_tick.
do
  local AS3 = L3.by_key.assembler
  local cc9 = Levels3.cc(game.forces.player)
  local function recipe2()
    return { name = "iron-gear-wheel", valid = true, ingredients = { { type = "item", name = "iron-plate", amount = 2 } } }
  end
  local function machine(n, x, y, crafting, progress)
    local e = s3.create_entity({ name = L3.name(AS3, n), position = { x = x, y = y }, force = "player" })
    e.set_recipe("iron-gear-wheel")
    local state = { crafting = crafting }
    rawset(e, "is_crafting", function() return state.crafting end)
    rawset(e, "crafting_progress", progress or 0)
    rawset(e, "get_recipe", recipe2)
    return e, state
  end
  lv3.pending = lv3.pending or {}
  -- (a) Remplacement rapide (même taille : 8 → 9, 4×4), machine pas encore repartie : l'entrée suit la nouvelle.
  local side8 = L3.footprint(AS3, 8)
  local x8 = 400 + (side8 % 2 == 1 and 0.5 or 0)
  local a8 = machine(8, x8, x8, false, 0)
  lv3.pending[a8.unit_number] = { entity = a8, recipe = "iron-gear-wheel", progress = 0.3, bonus = 0, tick = game.tick }
  for _, c in ipairs(L3.cost(AS3, 9)) do cc9.get_inventory(defines.inventory.chest).insert({ name = c[1], count = c[2] }) end
  local u8 = a8.unit_number
  local ok_a, why_a, _, a9 = Levels3.start(a8, nil)
  local pa = a9 and lv3.pending[a9.unit_number]
  check(ok_a and a9 and L3.footprint(AS3, 9) == side8 and pa and pa.progress == 0.3 and pa.entity == a9 and lv3.pending[u8] == nil,
    "progression notée d'une machine pas encore repartie : SUIT la nouvelle après un remplacement rapide (8 → 9, même taille) ("
    .. tostring(why_a) .. ")")
  -- (b) Second remplacement PAR SCRIPT (Levels.transfer), machine pas encore repartie : l'entrée suit, rien n'est rendu.
  local b1 = machine(12, 420.5, 400.5, false, 0)
  local b2 = machine(13, 430, 400, false, 0)
  lv3.pending[b1.unit_number] = { entity = b1, recipe = "iron-gear-wheel", progress = 0.6, bonus = 0, tick = game.tick }
  local ub1 = b1.unit_number
  local ok_b, err_b = pcall(Levels3.transfer, b1, b2)
  local pb = lv3.pending[b2.unit_number]
  check(ok_b and pb and pb.progress == 0.6 and pb.entity == b2 and lv3.pending[ub1] == nil and b2.get_item_count("iron-plate") == 0,
    "progression notée d'une machine pas encore repartie : SUIT la nouvelle après un second remplacement par script, aucun ingrédient rendu deux fois ("
    .. tostring(err_b) .. ")")
  lv3.pending[b2.unit_number] = nil
  -- (c) Défauts 2 et 15 : la machine a déjà repris (fabrication neuve, progression 0,01, 2 plaques consommées) :
  -- progression notée (0,6) reposée d'abord, puis ingrédients de la fabrication en cours rendus à la nouvelle, et la
  -- progression 0,6 notée pour elle.
  local c1 = machine(12, 440.5, 400.5, true, 0.01)
  local c2 = machine(13, 450, 400, false, 0)
  lv3.pending[c1.unit_number] = { entity = c1, recipe = "iron-gear-wheel", progress = 0.6, bonus = 0, tick = game.tick }
  local uc1 = c1.unit_number
  local ok_c, err_c = pcall(Levels3.transfer, c1, c2)
  local pc = lv3.pending[c2.unit_number]
  check(ok_c and pc and pc.progress == 0.6 and lv3.pending[uc1] == nil and c2.get_item_count("iron-plate") == 2,
    "machine DÉJÀ repartie avant la seconde amélioration : ingrédients de sa fabrication rendus (2 plaques), progression notée 0,6 gardée ("
    .. tostring(err_c) .. ")")
  lv3.pending[c2.unit_number] = nil
  -- (d) Même cas par le remplacement rapide (Levels.start, même taille) : la progression notée est reposée AVANT.
  local d8 = machine(8, x8 + 20, x8, true, 0.01)
  lv3.pending[d8.unit_number] = { entity = d8, recipe = "iron-gear-wheel", progress = 0.5, bonus = 0, tick = game.tick }
  local ud8 = d8.unit_number
  local r0 = lv3.stats.resumed or 0
  for _, c in ipairs(L3.cost(AS3, 9)) do cc9.get_inventory(defines.inventory.chest).insert({ name = c[1], count = c[2] }) end
  local seen_progress
  table.insert(Levels3.on_replaced, function(old_unit) if old_unit == ud8 then seen_progress = rawget(d8, "crafting_progress") end end)
  local ok_d = Levels3.start(d8, nil)
  table.remove(Levels3.on_replaced)
  check(ok_d and lv3.pending[ud8] == nil and (lv3.stats.resumed or 0) == r0 + 1 and seen_progress == 0.5,
    "machine déjà repartie, remplacement rapide : progression notée reposée sur elle AVANT le remplacement (0,5), entrée retirée ("
    .. tostring(seen_progress) .. ")")
  for _, e in ipairs({ a9, b1, b2, c1, c2 }) do if e and e.valid then e.destroy() end end
end

-- Correction V3-T2 (défaut 16) : migration 0.4.2 → 0.4.3 hors jeu FAMILLE PAR FAMILLE (avant, seule la famille
-- « command » était tenue hors jeu : une migration qui sautait l'assembleur ou le four passait tous les bancs hors
-- jeu, mutations m4a et m4c du correcteur). Relevé 0.4.2 (seule la mitrailleuse grandissait) ; une machine de chaque
-- famille au niveau 7, posée à l'ANCIENNE taille (côté de base) en terrain libre : reposée à la position préférée
-- de la règle, contenu transféré, ancien retiré.
section("V3-T2 : sauvegarde 0.4.2 → 0.4.3, une machine par famille (assembleur, four, foreuse, laser)")
do
  local snap42 = L3.footprint_snapshot(true)
  for n = 1, L3.by_key.gun.max do snap42.gun[n] = L3.footprint(L3.by_key.gun, n) end
  lv3.footprints = snap42
  local want, ents = {}, {}
  local specs = {
    { key = "assembler", x = 600.5, y = 600.5, item = "iron-plate", count = 5 },
    { key = "furnace", x = 620, y = 600, item = "coal", count = 4 },
    { key = "drill", x = 640.5, y = 600.5 },
    { key = "laser", x = 660, y = 600 },
  }
  for _, sp in ipairs(specs) do
    local f = L3.by_key[sp.key]
    local e = s3.create_entity({ name = L3.name(f, 7), position = { x = sp.x, y = sp.y }, force = "player" })
    if sp.item then e.insert({ name = sp.item, count = sp.count }) end
    local c = Foot3.candidates(Foot3.tile_box({ x = sp.x, y = sp.y }, f.size), L3.footprint(f, 7))[1]
    want[sp.key] = { x = c.x, y = c.y }
    ents[sp.key] = e
  end
  -- Défaut 14 : assembleur 7 EN PLEINE FABRICATION dans la sauvegarde (2 plaques déjà prises, progression 0,3) : la
  -- migration le repose par script ; ses ingrédients sont rendus et la progression reposée au premier tick où il
  -- refabrique. (En moteur réel, une carte créée par --create est sauvegardée au tick 0 : aucune machine n'y fabrique ;
  -- ce cas n'est tenu qu'ici.)
  local AS3 = L3.by_key.assembler
  local busy = s3.create_entity({ name = L3.name(AS3, 7), position = { x = 680.5, y = 600.5 }, force = "player" })
  busy.set_recipe("iron-gear-wheel")
  busy.insert({ name = "iron-plate", count = 4 })
  rawset(busy, "is_crafting", function() return true end)
  rawset(busy, "crafting_progress", 0.3)
  rawset(busy, "get_recipe", function()
    return { name = "iron-gear-wheel", valid = true, ingredients = { { type = "item", name = "iron-plate", amount = 2 } } }
  end)
  local busy_at = Foot3.candidates(Foot3.tile_box({ x = 680.5, y = 600.5 }, AS3.size), L3.footprint(AS3, 7))[1]
  local ok_m, err_m = pcall(M.dispatch, W().on_config, { mod_changes = { ["factorio-overhaul"] = { old_version = "0.4.2", new_version = "0.4.3" } } })
  do
    local nb = s3.find_entity(L3.name(AS3, 7), { x = busy_at.x, y = busy_at.y })
    local pend = nb and lv3.pending and lv3.pending[nb.unit_number]
    check(nb and not busy.valid and nb.get_item_count("iron-plate") == 6 and pend and pend.progress == 0.3,
      "migration d'un assembleur EN PLEINE FABRICATION : reposé, ingrédients de la fabrication rendus (4 + 2 plaques), progression 0,3 notée")
    if nb then
      rawset(nb, "is_crafting", function() return true end)
      rawset(nb, "crafting_progress", 0)
      rawset(nb, "get_recipe", function() return { name = "iron-gear-wheel", valid = true, ingredients = {} } end)
      local done = Levels3.resume_progress()
      check(done == 1 and nb.crafting_progress == 0.3 and lv3.pending[nb.unit_number] == nil,
        "… puis, au premier tick où il refabrique : progression 0,3 reposée")
      nb.destroy()
    end
  end
  check(ok_m, "on_configuration_changed 0.4.2 → 0.4.3 sans erreur (" .. tostring(err_m) .. ")")
  for _, sp in ipairs(specs) do
    local f = L3.by_key[sp.key]
    local w = want[sp.key]
    local e = s3.find_entity(L3.name(f, 7), w)
    local content_ok = not sp.item or (e and e.get_item_count(sp.item) == sp.count)
    check(e ~= nil and not ents[sp.key].valid and e.position.x == w.x and e.position.y == w.y and content_ok,
      "migration 0.4.2 → 0.4.3 : " .. sp.key .. " 7 (" .. f.size .. "×" .. f.size .. " → " .. L3.footprint(f, 7) .. "×" .. L3.footprint(f, 7)
      .. ") reposé à la position préférée (" .. w.x .. " ; " .. w.y .. "), contenu transféré, ancien retiré")
  end
end

-- Correction V3-T2 (défaut 13) : doublons superposés hérités d'avant 0.4.3 (F86 : améliorer un bâtiment hors grille
-- posait le nouveau par-dessus l'ancien) relevés, journalisés et signalés, jamais retirés.
section("V3-T2 : doublons superposés hérités, relevés au chargement")
do
  local G = L3.by_key.gun
  local d1 = s3.create_entity({ name = L3.name(G, 8), position = { x = 700.5, y = 700.5 }, force = "player" })
  local d2 = s3.create_entity({ name = L3.name(G, 9), position = { x = 701, y = 701 }, force = "player" })
  local lone = s3.create_entity({ name = L3.name(G, 9), position = { x = 720, y = 720 }, force = "player" })
  local logs0, msgs0, st0 = #W().logs, #fprints, lv3.stats.stacked or 0
  local ok_s, err_s = pcall(M.dispatch, W().on_config, { mod_changes = { ["other-mod"] = { old_version = "1.0.0", new_version = "1.0.1" } } })
  local logged = 0
  for i = logs0 + 1, #W().logs do if W().logs[i]:find("doublon superposé", 1, true) then logged = logged + 1 end end
  local msg
  for i = msgs0 + 1, #fprints do
    local m = fprints[i].msg
    if type(m) == "table" and m[1] == "fo-levels-taille.migration-stacked" then msg = m end
  end
  check(ok_s and logged == 1 and (lv3.stats.stacked or 0) == st0 + 1 and msg and msg[2] == 1 and d1.valid and d2.valid and lone.valid,
    "doublon superposé (mitrailleuses 8 et 9 à une demi-tuile) : relevé une fois, journalisé, signalé à la force, aucun retiré ("
    .. tostring(err_s) .. ")")
  for _, e in ipairs({ d1, d2, lone }) do e.destroy() end
end

-- Correction de la suite : conventions du moteur simulé pour la recherche par zone, tenues par des contrôles (une
-- mutation de tests/mock_engine.lua doit casser ce banc). Le CONTACT BORD À BORD et par un coin COMPTE : observé en
-- moteur réel le 22/10 (RD_LOG E53, scénario greffé bord-a-bord ; avant, le moteur simulé l'excluait sans
-- observation). Le mod n'en dépend pas : après chaque recherche par zone des niveaux, il refiltre (Foot.overlap strict,
-- Points.inside, écart explicite des doublons) ; move_ground_items ne le faisait pas et poussait un objet au sol qui
-- touchait seulement le bord du bâtiment : corrigé le 22/10 (tests/levels_test.lua, cas « bord ou coin »).
-- Boîtes de ± 0,75 (exactes en binaire) posées loin du reste, en (−500 ; −500) et (−498,5 ; −500) : elles se
-- touchent en x = −499,25.
rawset(W().prototypes, "test-edge-box", { type = "container", max_health = 10,
  collision_box = { left_top = { x = -0.75, y = -0.75 }, right_bottom = { x = 0.75, y = 0.75 } } })
rawset(W().prototypes, "test-edge-item", { type = "item-entity", max_health = 10,
  collision_box = { left_top = { x = -0.14, y = -0.14 }, right_bottom = { x = 0.14, y = 0.14 } } })
local ea = s3.create_entity({ name = "test-edge-box", position = { x = -500, y = -500 }, force = "player" })
local eb = s3.create_entity({ name = "test-edge-box", position = { x = -498.5, y = -500 }, force = "player" })
local ei = s3.create_entity({ name = "test-edge-item", position = { x = -500, y = -500 }, force = "neutral" })
local function found(area, extra)
  local q = { area = area }
  for k, v in pairs(extra or {}) do q[k] = v end
  local has = {}
  for _, e in ipairs(s3.find_entities_filtered(q)) do has[e] = true end
  return has
end
local in_a = found({ { -500.75, -500.75 }, { -499.25, -499.25 } })
check(in_a[ea] and in_a[eb], "moteur simulé : zone égale à la boîte d'un bâtiment, le voisin qui la touche bord à bord EST rendu (moteur réel, E53)")
local in_gap = found({ { -500.75, -500.75 }, { -499.25 - 1 / 256, -499.25 } })
check(in_gap[ea] and not in_gap[eb], "moteur simulé : zone qui s'arrête à 1/256 du voisin, seul le bâtiment est rendu (moteur réel, E53)")
local in_corner = found({ { -499.25, -499.25 }, { -499, -499 } })
check(in_corner[ea] and in_corner[eb], "moteur simulé : zone qui touche le bâtiment par un coin (et le voisin par un bord), les deux sont rendus (moteur réel, E53)")
local in_ab = found({ { -500.75, -500.75 }, { -499.24, -499.25 } })
check(in_ab[ea] and in_ab[eb], "moteur simulé : zone qui mord de 0,01 dans la boîte du voisin, les deux sont rendus")
local only_player = found({ { -501, -501 }, { -499, -499 } }, { collision_mask = "player-layer" })
local only_item = found({ { -501, -501 }, { -499, -499 } }, { collision_mask = { "item-layer" } })
check(only_player[ea] and not only_player[ei] and only_item[ea] and only_item[ei],
  "moteur simulé : filtre collision_mask (objet au sol : couche item-layer seule ; conteneur : masque des bâtiments par défaut)")
-- Prototypes intégrés du moteur simulé : boîtes vanilla (gun-turret ± 0,7 ; QG = épave décentrée).
local gt = s3.create_entity({ name = "gun-turret", position = { x = -480, y = -480 }, force = "player" })
local hq = s3.create_entity({ name = "fo-faction-hq", position = { x = -460, y = -460 }, force = "player" })
local gb, hb = gt.bounding_box, hq.bounding_box
check(math.abs(gb.left_top.x + 480.7) < 1e-9 and math.abs(gb.right_bottom.y + 479.3) < 1e-9
  and math.abs(hb.left_top.x + 468.7) < 1e-9 and math.abs(hb.right_bottom.x + 453.1) < 1e-9
  and math.abs(hb.left_top.y + 463.3) < 1e-9 and math.abs(hb.right_bottom.y + 455.5) < 1e-9,
  "moteur simulé : boîtes des prototypes intégrés = vanilla (mitrailleuse ± 0,7 ; QG -8,7 / -3,3 / 6,9 / 4,5)")
for _, e in ipairs({ ea, eb, ei, gt, hq }) do e.destroy() end

print(string.format("\n%d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
