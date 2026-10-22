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
M.new_game({ p_busy = 0, p_nopath = 0, p_lost = 0 })
-- Prototypes des niveaux (le moteur simulé ne lit pas l'étape data).
for _, f in ipairs(L.families) do
  for n = 1, f.max do
    rawset(W().prototypes, L.name(f, n), {
      type = f.type, max_health = 1000,
      selection_box = { left_top = { x = -f.size / 2, y = -f.size / 2 }, right_bottom = { x = f.size / 2, y = f.size / 2 } },
    })
  end
end
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
  jobs = { [drill.unit_number] = job_030(drill, "drill", 10, 600), [ghost.unit_number] = job_030(ghost, "drill", 6, 600) },
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
-- Décision V2c : un chantier en cours (déjà payé) est ACHEVÉ au chargement (pas annulé ni remboursé).
local d10 = s.find_entity("fo-lvl-drill-10", { x = 30, y = 30 })
check(d10 ~= nil and d10.active ~= false and not drill.valid, "chantier 0.3.0 achevé au chargement : foreuse niveau 10 posée, en service")
check(next(lv.jobs) == nil and next(lv.busy) == nil and lv.time_factor == nil, "plus aucun chantier, ouvrier ni réglage de durée enregistré")
check(lv.stats.upgrades == 13 and lv.stats.lost == 1 and lv.stats.cancelled == 1 and lv.stats.instant == 40,
  "statistiques 0.3.0 conservées : +1 achevé, +1 perdu (chantier sans bâtiment) (" .. lv.stats.upgrades .. ", " .. lv.stats.lost .. ")")
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
check(rr and rr.ok and rr.reason == "done" and s.find_entity("fo-lvl-gun-12", { x = 10, y = 10 }) ~= nil,
  "levels_time_factor ignoré : levels_upgrade toujours instantané (" .. tostring(rr and rr.reason) .. ")")

print(string.format("\n%d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
