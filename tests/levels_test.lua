--[[
  Tests hors-jeu des NIVEAUX de bâtiments (session 5) : règles pures + chantiers en moteur simulé.
  Usage, depuis la racine du mod :   lua5.2 tests/levels_test.lua
]]

package.path = "./?.lua;" .. package.path
local L = require("shared.levels.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

---------------------------------------------------------------------------------------------------
section("Règles pures")
---------------------------------------------------------------------------------------------------
check(#L.families == 7, "7 familles")
for _, f in ipairs(L.families) do
  for n = 1, L.MAX do
    local fam, lv = L.parse(L.name(f, n))
    check(fam == f and lv == n, f.key .. " : nom du niveau " .. n .. " réversible")
  end
  local prev_total, prev_time = 0, -1
  for n = 2, L.MAX do
    local cost = L.cost(f, n)
    local total = 0
    for _, c in ipairs(cost) do
      check(c[2] >= 1, f.key .. " N" .. n .. " : quantité positive " .. c[1])
      total = total + c[2]
    end
    check(total > prev_total, f.key .. " N" .. n .. " : coût total croissant")
    prev_total = total
    local t = L.time_ticks(f, n, 1)
    if f.instant then check(t == 0, f.key .. " : instantané") else check(t > prev_time, f.key .. " N" .. n .. " : durée croissante") end
    prev_time = t
  end
  -- Le tungstène et le cristal (ressources des biomes) deviennent des monnaies d'amélioration.
  local top = {}
  for _, c in ipairs(L.cost(f, 10)) do top[c[1]] = true end
  check(top["fo-tungsten-plate"] and top["fo-resonance-crystal"], f.key .. " N10 : tungstène et cristal requis")
end
check(L.max_level(L.by_key.gun, 0) == 1, "sans centre : aucun bâtiment au-delà du niveau 1")
check(L.max_level(L.by_key.gun, 3) == 4, "centre 3 : bâtiments jusqu'au niveau 4")
check(L.max_level(L.by_key.gun, 10) == 10, "centre 10 : niveau 10")
check(L.max_level(L.by_key.command, 1) == 10, "le centre lui-même n'est pas plafonné")
check(L.builders(1) == 1 and L.builders(4) == 2 and L.builders(7) == 3 and L.builders(10) == 4, "ouvriers 1/2/3/4")
local ok, why = L.check(L.by_key.gun, 2, 0, 0)
check(not ok and why == "no-cc", "refus sans centre")
ok, why = L.check(L.by_key.gun, 3, 1, 0)
check(not ok and why == "cc-too-low", "refus : centre trop bas")
ok, why = L.check(L.by_key.gun, 2, 1, 1)
check(not ok and why == "no-builder", "refus : ouvrier occupé")
ok = L.check(L.by_key.wall, 2, 1, 5)
check(ok, "les murs n'ont pas besoin d'ouvrier")
check(math.abs(L.apply_stat({ op = "pow", k = 1.3 }, 350, 10) - 350 * 1.3 ^ 9) < 1e-9, "mur N10 : PV × 1,3^9")

---------------------------------------------------------------------------------------------------
section("Chantiers en moteur simulé")
---------------------------------------------------------------------------------------------------
local M = require("tests.mock_engine")
M.new_game({})
local W = M.world()
-- Prototypes des niveaux (le moteur simulé ne lit pas l'étape data).
local HP = { command = 3000, gun = 400, wall = 350, laser = 1000, drill = 300, furnace = 300, assembler = 350 }
for _, f in ipairs(L.families) do
  for n = 1, L.MAX do
    local hp = L.apply_stat(f.stats[1], HP[f.key], n)
    rawset(W.prototypes, L.name(f, n), {
      type = f.type, max_health = hp,
      selection_box = { left_top = { x = -f.size / 2, y = -f.size / 2 }, right_bottom = { x = f.size / 2, y = f.size / 2 } },
    })
  end
end
local s = game.surfaces[1]
local ev = W.events
local function built(e) ev[defines.events.on_built_entity]({ created_entity = e, player_index = 1, tick = game.tick }) end
local Levels = require("script.levels.levels")
local force = game.forces.player

local cc = s.create_entity({ name = "fo-command-center", position = { x = 0.5, y = 0.5 }, force = "player" })
built(cc)
check(Levels.cc_level(force) == 1, "centre de commandement niveau 1 enregistré")
local cc2 = s.create_entity({ name = "fo-command-center", position = { x = 20.5, y = 0.5 }, force = "player" })
built(cc2)
check(not cc2.valid and Levels.cc(force) == cc, "un seul centre par force (le second est rendu)")

local gun = s.create_entity({ name = "gun-turret", position = { x = 10, y = 10 }, force = "player" })
gun.insert({ name = "firearm-magazine", count = 25 })
gun.health = 200
local r_ok, r_why = Levels.start(gun, nil)
check(not r_ok and r_why == "no-resources", "refus faute de ressources")
local chest = cc.get_inventory(defines.inventory.chest)
for _, c in ipairs(L.cost(L.by_key.gun, 2)) do chest.insert({ name = c[1], count = c[2] * 2 }) end
r_ok, r_why = Levels.start(gun, nil)
check(r_ok and r_why == "started", "chantier lancé (payé par le centre)")
check(gun.active == false, "bâtiment hors service pendant le chantier")
check(Levels.busy(force) == 1, "un ouvrier occupé")
check(chest.get_item_count("iron-plate") == L.cost(L.by_key.gun, 2)[1][2], "coût prélevé dans le centre")
local gun_b = s.create_entity({ name = "gun-turret", position = { x = 14, y = 10 }, force = "player" })
r_ok, r_why = Levels.start(gun_b, nil)
check(not r_ok and r_why == "no-builder", "second chantier refusé (1 ouvrier au centre niveau 1)")
M.run_ticks(L.time_ticks(L.by_key.gun, 2, 1) + 31)
check(not gun.valid, "ancienne tourelle remplacée")
local g2 = s.find_entity("fo-lvl-gun-2", { x = 10, y = 10 })
check(g2 ~= nil, "tourelle niveau 2 posée au même endroit")
check(g2 and g2.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine") == 25, "munitions conservées")
check(g2 and math.abs(g2.get_health_ratio() - 0.5) < 1e-6, "santé conservée en proportion (50 %)")
check(g2 and g2.active ~= false, "tourelle niveau 2 en service")
check(Levels.busy(force) == 0, "ouvrier libéré")
check((W.lights or 0) >= 1 and (W.flying or 0) >= 1, "célébration (lumière, texte)")

-- Plafond : niveau 3 interdit avec un centre niveau 1, autorisé après amélioration du centre.
for _, c in ipairs(L.cost(L.by_key.gun, 3)) do chest.insert({ name = c[1], count = c[2] }) end
r_ok, r_why = Levels.start(g2, nil)
check(not r_ok and r_why == "cc-too-low", "tourelle niveau 3 refusée : centre niveau 1")
for _, c in ipairs(L.cost(L.by_key.command, 2)) do chest.insert({ name = c[1], count = c[2] }) end
r_ok, r_why = Levels.start(cc, nil)
check(r_ok and r_why == "started", "chantier du centre lancé")
M.run_ticks(L.time_ticks(L.by_key.command, 2, 1) + 31)
check(Levels.cc_level(force) == 2 and Levels.cc(force).name == "fo-lvl-command-2", "centre niveau 2 (toujours enregistré après remplacement)")
check(Levels.cc(force).get_inventory(defines.inventory.chest).get_item_count("iron-plate") > 0, "le stock du centre a suivi le remplacement")
r_ok, r_why = Levels.start(g2, nil)
check(r_ok and r_why == "started", "tourelle niveau 3 autorisée avec un centre niveau 2")

-- Démontage pendant le chantier : moitié du coût rendue.
local buffer = M.new_inventory()
ev[defines.events.on_player_mined_entity]({ entity = g2, buffer = buffer, player_index = 1, tick = game.tick })
check(Levels.busy(force) == 0, "chantier annulé au démontage")
check(buffer.get_item_count("iron-plate") == math.floor(L.cost(L.by_key.gun, 3)[1][2] / 2), "moitié du coût rendue")

-- Murs : instantanés, rangée entière.
local walls = {}
for i = 0, 5 do
  walls[#walls + 1] = s.create_entity({ name = "stone-wall", position = { x = 30 + i, y = 5 }, force = "player" })
end
local cinv = Levels.cc(force).get_inventory(defines.inventory.chest)
for _, c in ipairs(L.cost(L.by_key.wall, 2)) do cinv.insert({ name = c[1], count = c[2] * 6 }) end
local done = Levels.start_row(walls[3], nil)
check(done == 6, "rangée de 6 murs améliorée d'un coup (" .. tostring(done) .. ")")
check(s.find_entity("fo-lvl-wall-2", { x = 30, y = 5 }) ~= nil and s.find_entity("stone-wall", { x = 35, y = 5 }) == nil, "murs niveau 2 posés")
check(Levels.busy(force) == 0, "les murs n'occupent pas d'ouvrier")

-- Destruction pendant le chantier : chantier perdu, ouvrier libéré.
local drill = s.create_entity({ name = "electric-mining-drill", position = { x = 50, y = 50 }, force = "player" })
for _, c in ipairs(L.cost(L.by_key.drill, 2)) do cinv.insert({ name = c[1], count = c[2] }) end
r_ok = Levels.start(drill, nil)
check(r_ok and Levels.busy(force) == 1, "chantier de foreuse lancé")
drill.die("enemy")
M.run_ticks(31)
check(Levels.busy(force) == 0, "foreuse détruite : chantier perdu, ouvrier libéré")

print(string.format("Résultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
