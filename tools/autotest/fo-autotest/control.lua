-- Mod de test automatisé : jamais activé en partie normale (dossier de mods séparé, voir fo-autotest.bat).
-- À la création de la carte : guerre à 4 factions + compagnons en errance + profiler, selon le SCÉNARIO
-- (fichier scenario.lua écrit par fo-autotest.bat à partir de fo-autotest-params.txt) :
--   default : 4 factions (100 soldats max, 10 ingénieurs), 50 compagnons
--   stress  : idem + 20 000 MU par faction (armées complètes en ~1 min) + 380 compagnons (≈ 430 agents riches)
--   content : banc de contenu ; vitrine : entités de fo-vitrine.lua à côté des références vanilla (vitrine.lua)
--   <autre nom> : scénario greffé scenarios/<nom>.lua (greffons.lua, tools/autotest/README.md)
-- Puis un rapport par minute de jeu dans factorio-current.log (balises [FO-AUTOTEST]).

local Spike = require("spike_worker")
local Content = require("content_test")
local Shots = require("shots")
local Vitrine = require("vitrine")
local Greffons = require("greffons")

local ok_s, SCENARIO = pcall(require, "scenario")
if not ok_s or type(SCENARIO) ~= "string" then SCENARIO = "default" end

-- Lot IA0 : les scénarios de guerre intégrés restent en « Paisible » (pvp = "peaceful"), comportement des
-- sessions 4-5, pour rester comparables à E17-E22 (sinon, au niveau Normal par défaut, les factions
-- deviennent hostiles aux compagnons et à la base du joueur après 20 à 43 min). Le PvP se mesure dans
-- les scénarios greffés scenarios/ia0-*.lua.
local SCENARIOS = {
  default = { war = true, companions = 50, radius = 32, fund = 0, pvp = "peaceful" },
  stress = { war = true, companions = 380, radius = 64, fund = 20000, pvp = "peaceful" },
  baseline = { war = false, companions = 0, radius = 32, fund = 0 }, -- témoin : même carte, sans guerre
  noexp = { war = true, companions = 50, radius = 32, fund = 0, no_expansion = true, pvp = "peaceful" }, -- expansion biters coupée
  peace = { war = true, companions = 50, radius = 32, fund = 0, biter_peace = true, pvp = "peaceful" },  -- biters en paix avec les factions
  parked = { war = true, companions = 50, radius = 32, fund = 0, garrison_mode = "stop", pvp = "peaceful" }, -- garnisons au repos
  worker = { war = false, companions = 0, radius = 32, fund = 0, spike = true }, -- un corps sans joueur travaille-t-il ?
  content = { content = true }, -- banc de contenu : chaque recette, module, arme, ennemi, ressource, biome
  vitrine = { vitrine = true }, -- vitrine : entités demandées (fo-vitrine.lua) à côté des références vanilla
  waves = { war = true, companions = 0, radius = 32, fund = 0, waves = true, pvp = "peaceful" }, -- défense de tours + guerre
  pteam = { war = true, companions = 0, radius = 32, fund = 0, pteam = true, pvp = "peaceful" }, -- équipe du joueur + guerre
}

-- Scénario GREFFÉ : un nom inconnu ci-dessus charge scenarios/<nom>.lua (au chargement du mod, jamais
-- pendant un événement : F24). Format et crochets : tools/autotest/README.md.
local PLUGIN = Greffons.load_scenario(SCENARIO, SCENARIOS)

-- Équipe du joueur : un coffre d'équipe garni posé près du départ (comme le ferait le joueur).
local function place_team_chest()
  local s = game.surfaces[1]
  local c = game.forces.player.get_spawn_position(s)
  local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
  local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
    { "pistol", 3 }, { "firearm-magazine", 60 }, { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  log("[FO-AUTOTEST] coffre d'equipe pose en (" .. math.floor(p.x) .. "," .. math.floor(p.y) .. ")")
end

-- Base de test pour le mode défense de tours : anneau de tourelles approvisionnées autour du départ.
local function build_test_base()
  local s = game.surfaces[1]
  local c = game.forces.player.get_spawn_position(s)
  local n = 0
  for i = 0, 11 do
    local a = i * math.pi / 6
    local p = s.find_non_colliding_position("gun-turret", { x = c.x + math.cos(a) * 14, y = c.y + math.sin(a) * 14 }, 8, 1)
    if p then
      local t = s.create_entity({ name = "gun-turret", position = p, force = "player" })
      if t then
        t.insert({ name = "piercing-rounds-magazine", count = 200 })
        n = n + 1
      end
    end
  end
  log("[FO-AUTOTEST] base de defense : " .. n .. " tourelles")
end

--- Session visuelle : le scénario « freeplay » joue la cinématique de l'épave à l'arrivée du joueur puis
--- affiche son message d'accueil, qui MET LE JEU EN PAUSE en solo jusqu'à <Tab> (moteur réel : captures
--- bloquées à 34/55). Sans effet sur les bancs (aucun joueur n'y est créé).
local function skip_freeplay_intro()
  local fp = remote.interfaces["freeplay"]
  if not fp then return end
  if fp.set_skip_intro then remote.call("freeplay", "set_skip_intro", true) end
  if fp.set_disable_crashsite then remote.call("freeplay", "set_disable_crashsite", true) end
end

--- Préparation d'un scénario intégré (aussi la « base » d'un scénario greffé).
local function builtin_init(sc)
  if sc.content then
    Content.start()
    return
  end
  if sc.vitrine then
    Vitrine.start()
    return
  end
  if sc.no_expansion then game.map_settings.enemy_expansion.enabled = false end
  if sc.spike then Spike.start() end
  if sc.pvp and remote.interfaces["fo-pvp"] then
    -- Lot IA0 : niveau imposé AVANT le lancement (message d'introduction et état PvP à ce niveau).
    log("[FO-AUTOTEST] difficulte PvP " .. sc.pvp .. " = " .. tostring(remote.call("fo-pvp", "set_difficulty", sc.pvp)))
  end
  if sc.war then
    local ok = remote.call("factorio-overhaul", "war_start", 4, 100, 10)
    log("[FO-AUTOTEST] war_start = " .. tostring(ok))
    if sc.biter_peace then
      for name, force in pairs(game.forces) do
        if name:find("^fo%-") then
          force.set_cease_fire("enemy", true)
          game.forces.enemy.set_cease_fire(force, true)
        end
      end
    end
    if sc.fund > 0 then remote.call("factorio-overhaul", "war_fund", sc.fund) end
    if sc.garrison_mode then remote.call("factorio-overhaul", "war_option", "garrison_mode", sc.garrison_mode) end
  else
    -- Témoin : on génère le même voisinage que la guerre (sans QG) pour comparer le coût moteur.
    local s = game.surfaces[1]
    local c = game.forces.player.get_spawn_position(s)
    for _, d in ipairs({ { 1, -1 }, { 1, 1 }, { -1, 1 }, { -1, -1 } }) do
      s.request_to_generate_chunks({ x = c.x + d[1] * 339, y = c.y + d[2] * 339 }, 4)
    end
    s.force_generate_chunk_requests()
    for _, d in ipairs({ { 1, -1 }, { 1, 1 }, { -1, 1 }, { -1, -1 } }) do
      s.request_to_generate_chunks({ x = c.x + d[1] * 339, y = c.y + d[2] * 339 }, 13)
    end
  end
  if sc.companions > 0 then
    local n = remote.call("factorio-overhaul", "companions_spawn", sc.companions, sc.radius)
    log("[FO-AUTOTEST] compagnons crees = " .. tostring(n))
  end
  if sc.pteam then place_team_chest() end
  if sc.waves then
    build_test_base()
    remote.call("factorio-overhaul", "waves", "on", 30)
  end
  remote.call("factorio-overhaul", "profiler", true)
  remote.call("factorio-overhaul", "reset_stats")
  -- H-W1 : les biomes et ressources du mod apparaissent-ils dans les chunks générés ?
  local s = game.surfaces[1]
  local chunks = 0
  for _ in s.get_chunks() do chunks = chunks + 1 end
  log("[FO-AUTOTEST] carte : " .. chunks .. " chunks generes")
  for _, tile in ipairs({ "fo-volcanic-ash", "fo-crystal-flats", "fo-toxic-marsh" }) do
    log("[FO-AUTOTEST] tuiles " .. tile .. " = " .. s.count_tiles_filtered({ name = tile }))
  end
  for _, res in ipairs({ "fo-tungsten-ore", "fo-resonance-crystal", "fo-methane", "iron-ore", "crude-oil" }) do
    log("[FO-AUTOTEST] ressource " .. res .. " = " .. s.count_entities_filtered({ name = res }))
  end
  -- Décor des biomes (session 4) : roches en fusion, cristaux, arbres calcinés et des marais.
  local decor = {}
  for _, n in ipairs({ "fo-magma-rock", "fo-basalt-spire", "fo-charred-tree", "fo-crystal-cluster", "fo-crystal-shard", "fo-marsh-tree", "fo-marsh-snag" }) do
    decor[#decor + 1] = n .. "=" .. s.count_entities_filtered({ name = n })
  end
  log("[FO-AUTOTEST] decor des biomes : " .. table.concat(decor, ", "))
  local nests = s.count_entities_filtered({ type = "unit-spawner" })
  local fam = s.count_entities_filtered({ name = { "fo-armored-nest", "fo-pyro-nest", "fo-brood-nest", "fo-storm-nest" } })
  log("[FO-AUTOTEST] nids = " .. nests .. " (dont familles : " .. fam .. ")")

  -- Exploration lointaine : 4 zones de 9×9 chunks à 1 800 tuiles (nids de famille, gisements de biome).
  local far = { { 1800, 0 }, { 0, 1800 }, { -1800, 0 }, { 0, -1800 } }
  for _, p in ipairs(far) do s.request_to_generate_chunks({ x = p[1], y = p[2] }, 4) end
  s.force_generate_chunk_requests()
  local names = { "fo-tungsten-ore", "fo-resonance-crystal", "fo-methane", "iron-ore" }
  local totals, tiles, nest_total, fam_total = {}, {}, 0, 0
  for _, p in ipairs(far) do
    local area = { { p[1] - 144, p[2] - 144 }, { p[1] + 144, p[2] + 144 } }
    for _, n in ipairs(names) do totals[n] = (totals[n] or 0) + s.count_entities_filtered({ area = area, name = n }) end
    for _, t in ipairs({ "fo-volcanic-ash", "fo-crystal-flats", "fo-toxic-marsh" }) do
      tiles[t] = (tiles[t] or 0) + s.count_tiles_filtered({ area = area, name = t })
    end
    nest_total = nest_total + s.count_entities_filtered({ area = area, type = "unit-spawner" })
    fam_total = fam_total + s.count_entities_filtered({ area = area, name = { "fo-armored-nest", "fo-pyro-nest", "fo-brood-nest", "fo-storm-nest" } })
  end
  local parts = {}
  for _, n in ipairs(names) do parts[#parts + 1] = n .. "=" .. totals[n] end
  for _, t in ipairs({ "fo-volcanic-ash", "fo-crystal-flats", "fo-toxic-marsh" }) do parts[#parts + 1] = t .. "=" .. tiles[t] end
  log("[FO-AUTOTEST] lointain (4 x 81 chunks, 331 776 tuiles) : " .. table.concat(parts, ", ")
    .. " | nids " .. nest_total .. " (familles " .. fam_total .. ")")

  -- Répartition des nids lointains par nom
  local by_name = {}
  for _, p in ipairs(far) do
    local area = { { p[1] - 144, p[2] - 144 }, { p[1] + 144, p[2] + 144 } }
    for _, e in ipairs(s.find_entities_filtered({ area = area, type = "unit-spawner" })) do
      by_name[e.name] = (by_name[e.name] or 0) + 1
    end
  end
  local names_sorted = {}
  for n in pairs(by_name) do names_sorted[#names_sorted + 1] = n end
  table.sort(names_sorted)
  local np = {}
  for _, n in ipairs(names_sorted) do np[#np + 1] = n .. "=" .. by_name[n] end
  log("[FO-AUTOTEST] nids lointains par type : " .. table.concat(np, ", "))
end

script.on_init(function()
  log("[FO-AUTOTEST] on_init : lancement, scenario " .. SCENARIO
    .. (PLUGIN and (" (greffon scenarios/" .. SCENARIO .. ".lua)") or ""))
  skip_freeplay_intro()
  -- Lot KIT (28/10) : les bancs gardent le kit de départ généreux des factions (leurs attendus datent de ce kit) ; la partie
  -- réelle (par défaut) donne aux factions le kit de votre équipe. Le scénario etape1-guide l'éteint pour mesurer le guide.
  -- Allumé AVANT toute fondation (builtin_init, greffons). Sans le réglage (mod à créer d'une vieille source), rien.
  pcall(remote.call, "factorio-overhaul", "war_setting", "fo-war-kit-genereux", true)
  if PLUGIN then
    if PLUGIN.base then
      if SCENARIOS[PLUGIN.base] then
        builtin_init(SCENARIOS[PLUGIN.base])
      else
        log("[FO-AUTOTEST] ECHEC base inconnue pour le greffon : " .. tostring(PLUGIN.base))
      end
    end
    Greffons.scenario_init()
    return
  end
  if not SCENARIOS[SCENARIO] then
    log("[FO-AUTOTEST] scenario inconnu " .. SCENARIO .. ", ni integre ni greffe (" .. tostring(Greffons.missing)
      .. ") : default")
  end
  builtin_init(SCENARIOS[SCENARIO] or SCENARIOS.default)
end)

-- Un seul gestionnaire on_tick (un second script.on_event remplacerait le premier).
script.on_event(defines.events.on_tick, function(e)
  Spike.on_tick(e)
  Content.on_tick(e)
  Greffons.scenario_tick(e)
  Shots.on_tick(e, SCENARIO) -- seulement en session avec images (un joueur est connecté)
end)

script.on_nth_tick(3600, function(e)
  remote.call("factorio-overhaul", "log_report", string.format("minute %d", e.tick / 3600))
  local line = remote.call("factorio-overhaul", "team_status")
  if line then log("[FO-AUTOTEST] equipe du joueur :" .. line) end
  local w = remote.call("factorio-overhaul", "waves", "status")
  if w.active or w.wave > 0 then
    log(string.format("[FO-AUTOTEST] vagues : vague %d, phase %s, vivants %d, tenues %d, tues %d, passes %d", w.wave, w.phase, w.alive, w.cleared, w.kills, w.leaked))
  end
end)

-- Étalon machine : une charge Lua FIXE chronométrée toutes les 10 s. Si sa durée varie, c'est la machine
-- (autre programme, mise en veille, fréquence du processeur), pas le mod : les pics du benchmark sont
-- alors à relativiser. Lignes [FO-CALIB] lues par analyze.py.
local CALIB_N = 200000
local function calibrate(tick)
  local p = game.create_profiler()
  local s = 0
  for i = 1, CALIB_N do s = s + (i % 7) * 0.5 end
  p.stop()
  log({ "", "[FO-CALIB] ", tostring(tick), " ", p, s > 0 and "" or " !" })
end

-- Premier rapport après 10 s : un plantage précoce reste lisible même si le benchmark s'arrête tôt.
script.on_nth_tick(600, function(e)
  calibrate(e.tick)
  if e.tick == 600 then remote.call("factorio-overhaul", "log_report", "10 s") end
end)
