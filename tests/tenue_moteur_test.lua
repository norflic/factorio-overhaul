--[[
  Lot TENUE : banc HORS JEU du RUNTIME de la prévision (script/ai3/prevision.lua) sur le moteur simulé : la valeur de la défense d'un site
  compte le coup RÉEL des tourelles contre les résistances des unités ennemies (shared/ai3/armure.lua). Le moteur simulé donne à l'unité du
  nid des résistances (ou non) ; le même QG, les mêmes tourelles, la même évolution : la valeur de défense ne change que par le facteur.
    1. sans résistance : la valeur de défense est celle d'avant (aucune régression) ;
    2. avec -8 plats et 10 % contre un coup de 5 : valeur × 0,036 (5 → 1 / 5 × 0,9 = 0,18 ; 0,18 / 5) ;
    3. un coup de 20 (tourelle plus forte) : valeur × (20 - 8) × 0,9 / 20 = 0,54 ;
    4. une résistance d'un AUTRE type de dégâts ne touche pas la valeur ;
    5. deux passages identiques (déterminisme) ; global sérialisable.
  Lancement : lua5.2 tests/tenue_moteur_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

local function prepare_world(res, hit)
  local P = W().prototypes
  rawset(P, "fo-test-nest", { type = "unit-spawner", max_health = 350, spawn_cooldown = { min = 360, max = 150 },
    result_units = { { unit = "small-biter", spawn_points = { { evolution_factor = 0, weight = 1 } } } } })
  P["small-biter"].pollution_to_join_attack = 4
  P["small-biter"].speed = 0.2
  P["small-biter"].resistances = res
  P["gun-turret"].attack_parameters = { cooldown = 6, range = 18, damage_modifier = 1,
    ammo_type = { category = "bullet", action = { type = "direct", action_delivery = { type = "instant",
      target_effects = { { type = "damage", damage = { amount = hit, type = "physical" } } } } } } }
  game.map_settings = { unit_group = { min_group_gathering_time = 3600, max_group_gathering_time = 3 * 3600, max_unit_group_size = 200 },
    enemy_evolution = { enabled = true, time_factor = 0.000004, pollution_factor = 0.0000009 },
    pollution = { enabled = true, diffusion_ratio = 0.02 } }
  game.forces.enemy.evolution_factor = 0.1
  game.surfaces[1].find_enemy_units = function() return {} end
end

--- Valeur de défense du QG de la faction 1 avec 4 tourelles posées au QG, résistances `res`, coup `hit`.
local function defense(res, hit)
  M.new_game({ p_busy = 0, p_nopath = 0, p_lost = 0 })
  M.command("fo-war", "start 4 100 10 320")
  prepare_world(res, hit)
  M.run_ticks(600)
  local St = require("script.faction.state")
  local Prev = require("script.ai3.prevision")
  local f = St.war().factions[1]
  local s = game.surfaces[1]
  for i = 1, 4 do s.create_entity({ name = "gun-turret", position = { x = f.hq_pos.x - 6 + i * 3, y = f.hq_pos.y + 8 }, force = f.force }) end
  if f.prevision then f.prevision.t = nil end
  local st = Prev.think(f, game.tick)
  local out = { d = st and st.view.sites[1].d or -1, tv = st and st.turret_value or -1, ser = pcall(M.serialize, global) }
  return out
end

section("Valeur de défense contre les résistances (moteur simulé)")
local base = defense(nil, 5)
check(base.d > 0 and base.tv > 0, "sans résistance : la défense du QG vaut quelque chose (" .. tostring(base.d) .. ")")
local armoured = defense({ physical = { decrease = 8, percent = 0.1 } }, 5)
check(armoured.d > 0 and math.abs(armoured.d / base.d - 0.036) < 0.002,
  string.format("-8 plats et 10 %% contre un coup de 5 : valeur × 0,036 (obtenu %.4f)", armoured.d / base.d))
check(math.abs(armoured.tv / base.tv - 0.036) < 0.002, "la tourelle de plus compte aussi le coup réel (" .. string.format("%.4f", armoured.tv / base.tv) .. ")")
local strong_base = defense(nil, 20)
local strong = defense({ physical = { decrease = 8, percent = 0.1 } }, 20)
check(math.abs(strong.d / strong_base.d - 0.54) < 0.01, string.format("coup de 20 : valeur × 0,54 (obtenu %.4f)", strong.d / strong_base.d))
local other = defense({ explosion = { decrease = 8, percent = 0.5 } }, 5)
check(math.abs(other.d - base.d) < 1e-9, "résistance à un autre type de dégâts : valeur inchangée")
local zero = defense({}, 5)
check(math.abs(zero.d - base.d) < 1e-9, "table de résistances vide : valeur inchangée")
local again = defense({ physical = { decrease = 8, percent = 0.1 } }, 5)
check(again.d == armoured.d and again.tv == armoured.tv, "deux passages identiques")
check(armoured.ser and base.ser, "global sérialisable")

print(string.format("[TENUE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
