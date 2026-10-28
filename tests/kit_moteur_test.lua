--[[
  Tests hors jeu (moteur simulé) du lot KIT : une faction au kit ÉGAL (coffre vide, aucun four) démarre, et ses mineurs
  ne se gênent plus sur la même tuile.
  Usage, depuis la racine du mod :   lua5.2 tests/kit_moteur_test.lua      (environ 1 min)

  Constat du moteur réel (graine 1618033988, banc kit-diag) : des ouvriers qui minent EN MÊME TEMPS la même tuile de
  minerai ne rendent presque rien (3 mineurs de charbon : 0 chacun en 91 s). Le moteur simulé suit désormais cette règle
  (seul le premier reçoit le minerai) ; le test compare la réservation de tuile (Worker.CLAIM_TILES) à son mutant.
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local function patches() -- même carte que tests/ia1_scale_test.lua (gisements autour des QG à 320 tuiles)
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end

local function run(minutes, opts)
  opts = opts or {}
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0, kit_egal = opts.egal })
  M.world().settings["fo-war-workers"] = 30
  local Worker = require("script.team.worker")
  check(Worker.CLAIM_TILES == true, "réservation de tuile allumée par défaut")
  Worker.CLAIM_TILES = opts.claims ~= false
  local ok = remote.call("factorio-overhaul", "war_start", 2, 100, nil, 320)
  check(ok == true, "guerre lancée")
  local w = global.fo.war
  local first = {}
  for _, f in ipairs(w.factions) do
    local inv = f.hq.get_inventory(defines.inventory.chest).get_contents()
    local n = 0
    for _, c in pairs(inv) do n = n + c end
    first[f.key] = n
  end
  local okr, err = pcall(M.run_ticks, minutes * 3600)
  check(okr, "simulation sans erreur (" .. tostring(err) .. ")")
  local s = game.surfaces[1]
  local drills, mined = 0, 0
  for _, f in ipairs(w.factions) do
    drills = drills + s.count_entities_filtered({ name = "burner-mining-drill", force = f.force })
    mined = mined + (f.stats.mined or 0)
  end
  return { first = first, drills = drills, mined = mined, conflicts = M.world().tile_conflicts or 0, w = w }
end

section("1. Kit égal : coffre vide à la fondation, la faction démarre quand même (10 min)")
local egal = run(10, { egal = true })
local empty = true
for _, n in pairs(egal.first) do if n ~= 0 then empty = false end end
check(empty, "coffres des QG vides à la fondation (kit égal)")
check(egal.drills >= 12, "au moins 12 foreuses posées par les 2 factions en 10 min (" .. egal.drills .. ")")
check(egal.mined > 0, "du minerai miné à la main (" .. egal.mined .. ")")
for _, f in ipairs(egal.w.factions) do check(f.engineers_count >= 8, f.key .. " : les 8 ouvriers de départ sont toujours là") end

section("2. Kit généreux (bancs) : coffre garni à la fondation")
local gen = run(2, { egal = false })
local full = true
for _, n in pairs(gen.first) do if n < 500 then full = false end end
check(full, "coffres des QG garnis (kit généreux, défaut du moteur simulé)")

section("3. Une tuile, un mineur : la réservation contre son mutant (10 min, kit égal)")
local sans = run(10, { egal = true, claims = false })
print(string.format("   avec réservation : %d conflits de tuile, %d minerais, %d foreuses ; sans : %d conflits, %d minerais, %d foreuses",
  egal.conflicts, egal.mined, egal.drills, sans.conflicts, sans.mined, sans.drills))
check(egal.conflicts * 3 < sans.conflicts, "la réservation divise les mineurs sur la même tuile par plus de 3")
check(egal.mined > sans.mined, "plus de minerai à la main avec la réservation")

section("4. Tourelles de QG offertes (exception), aucune technologie au départ en kit égal (décision du 28/10)")
local function hq_turrets(res)
  local s = game.surfaces[1]
  local n, techs = 0, 0
  for _, f in ipairs(res.w.factions) do
    n = n + s.count_entities_filtered({ name = "gun-turret", force = f.force })
    for _, name in ipairs({ "military", "gun-turret", "stone-wall" }) do
      local t = game.forces[f.force].technologies[name]
      if t and t.researched then techs = techs + 1 end
    end
  end
  return n, techs
end
M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0, kit_egal = true })
remote.call("factorio-overhaul", "war_start", 2, 100, nil, 320)
local tr0, te0 = hq_turrets({ w = global.fo.war })
check(tr0 == 8, "kit égal : 4 tourelles de QG par faction, exception documentée (" .. tr0 .. " pour 2 factions)")
check(te0 == 0, "kit égal : aucune technologie de niveau 0 offerte (" .. te0 .. ")")
M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0, kit_egal = false })
remote.call("factorio-overhaul", "war_start", 2, 100, nil, 320)
local tr1, te1 = hq_turrets({ w = global.fo.war })
check(tr1 == 8, "kit généreux : 4 tourelles de QG par faction (" .. tr1 .. " pour 2 factions)")
check(te1 == 6, "kit généreux : technologies de niveau 0 offertes (" .. te1 .. " sur 6)")

section("5. Votre équipe garde son minage (Harvest.PLAYER faux) ; les factions, la correction")
local Harvest = require("script.team.harvest")
check(Harvest.PLAYER == false, "Harvest.PLAYER est faux par défaut")
check(Harvest.applies({ is_player = false }) and not Harvest.applies({ is_player = true }), "la correction vise les factions seulement")
check(#Harvest.names_for({ is_player = true }, "wood") == 1 and Harvest.names_for({ is_player = true }, "wood")[1] == "wood",
  "votre équipe : l'ancien nom seul (l'objet)")
check(not Harvest.foreign_resource(game.surfaces[1], { x = 0, y = 0 }, "coal", { is_player = true }), "votre équipe : jamais de ressource étrangère")
check(next(Harvest.reachable({ is_player = true, team = { ia3 = { reach = { wood = 40 } } } })) == nil,
  "votre équipe : aucune matière récoltable à portée pour le cerveau")
check(#Harvest.free_types("wood", { is_player = true }) == 1, "votre équipe : seules les ressources comptent comme libres")
Harvest.PLAYER = true
check(Harvest.applies({ is_player = true }), "Harvest.PLAYER vrai : la correction vaut aussi pour votre équipe (mutant)")
Harvest.PLAYER = false

print(string.format("\n[KIT-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
