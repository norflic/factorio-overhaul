--[[
  Revue VISUELLE automatique (session avec images, fo-visual.bat) : dès qu'un joueur est connecté, le mod
  de test prend une série de captures (game.take_screenshot) des points d'intérêt, puis écrit
  script-output/fo-shots/done.txt. Aucune saisie clavier nécessaire.

  Scénario « content » : arène de contenu (tourelles en duel, ennemis, murs, ressources, biomes).
  Autres scénarios : la partie est accélérée (×8) jusqu'à 10 min de jeu, puis QG, avant-postes, ouvriers.
]]

local Shots = {}

local RES = { 1600, 900 }
local WARMUP = 36000

local NIGHT = 0.5 -- surface.daytime : 0 = midi, 0.5 = minuit (les lueurs « draw_as_glow » se voient)

local function shot(list, name, pos, zoom, daytime)
  list[#list + 1] = { name = name, x = pos.x or pos[1], y = pos.y or pos[2], zoom = zoom or 1, daytime = daytime or 0 }
end

--- Décor de chaque biome (compté autour des points candidats).
local DECOR = {
  ["fo-volcanic-ash"] = { "fo-magma-rock", "fo-basalt-spire", "fo-charred-tree", "fo-tungsten-ore" },
  ["fo-crystal-flats"] = { "fo-crystal-cluster", "fo-crystal-shard", "fo-resonance-crystal" },
  ["fo-toxic-marsh"] = { "fo-marsh-tree", "fo-marsh-snag", "fo-methane" },
}

--- Le chunk et ses 8 voisins sont-ils ENTIÈREMENT générés ? (moteur réel : en bord de zone générée, les
--- chunks n'ont que leurs tuiles — ni décor, ni entités — et les captures montraient un sol nu.)
local function fully_generated(surface, p)
  local cx, cy = math.floor(p.x / 32), math.floor(p.y / 32)
  for dx = -1, 1 do
    for dy = -1, 1 do
      if not surface.is_chunk_generated({ cx + dx, cy + dy }) then return false end
    end
  end
  return true
end

--- Meilleur point d'un biome près du départ (rayon 640) : tuiles du biome dans des chunks entièrement
--- générés, notées par la pureté du biome (rayon 12) et la quantité de décor visible (rayon 16).
local function biome_spot(surface, tile)
  local tiles = surface.find_tiles_filtered({ area = { { -640, -640 }, { 640, 640 } }, name = tile, limit = 20000 })
  if #tiles == 0 then return nil end
  local best, best_score
  local step = math.max(1, math.floor(#tiles / 120))
  for i = 1, #tiles, step do
    local p = tiles[i].position
    if fully_generated(surface, p) then
      local pure = surface.count_tiles_filtered({ position = p, radius = 12, name = tile })
      local decor = surface.count_entities_filtered({ position = p, radius = 16, name = DECOR[tile] })
      local score = pure + 25 * math.min(decor, 30)
      if not best_score or score > best_score then best, best_score = p, score end
    end
  end
  return best
end

local function biome_shots(list, surface)
  for _, b in ipairs({ { "fo-volcanic-ash", "cendres" }, { "fo-crystal-flats", "cristal" }, { "fo-toxic-marsh", "marais" } }) do
    local p = biome_spot(surface, b[1])
    if p then
      shot(list, "biome-" .. b[2] .. "-jour", p, 0.6)
      shot(list, "biome-" .. b[2] .. "-proche", p, 1.4)
      shot(list, "biome-" .. b[2] .. "-nuit", p, 0.9, NIGHT)
    end
  end
end

local function content_list()
  local list = {}
  local S = global.content
  if not S then return list end
  for i, d in ipairs(S.duels or {}) do
    local t = d.turret or d.body
    if t and t.valid then
      local p = t.position
      shot(list, string.format("duel-%02d", i), { x = p.x + 8, y = p.y }, 1.6)
    end
  end
  shot(list, "ennemis", { x = S.ex0 + 70, y = S.ey0 + 20 }, 0.45)
  shot(list, "ennemis-zoom", { x = S.ex0 + 20, y = S.ey0 + 4 }, 1.2)
  shot(list, "ennemis-nuit", { x = S.ex0 + 70, y = S.ey0 + 20 }, 0.45, NIGHT)
  shot(list, "ennemis-zoom-nuit", { x = S.ex0 + 20, y = S.ey0 + 4 }, 1.2, NIGHT)
  -- Tourelles de l'arsenal spécial et lourdes, de près et de nuit (couches lumineuses).
  for i, d in ipairs(S.duels or {}) do
    local t = d.turret
    if t and t.valid and (t.name:find("^fo%-")) then
      local p = t.position
      shot(list, string.format("tourelle-%02d-%s", i, t.name), { x = p.x, y = p.y - 0.5 }, 2.2)
      shot(list, string.format("tourelle-%02d-%s-nuit", i, t.name), { x = p.x, y = p.y - 0.5 }, 2.2, NIGHT)
    end
  end
  -- Niveaux (session 5) : la galerie des 10 niveaux de chaque famille, de jour et de nuit, et les
  -- niveaux 7 à 10 de près.
  for _, g in ipairs(S.gallery or {}) do
    local center = { x = g.x1 + 4.5 * g.step, y = g.y }
    local zoom = math.min(1.4, RES[1] / (32 * (10 * g.step + 4)))
    shot(list, "niveaux-" .. g.key, center, zoom)
    shot(list, "niveaux-" .. g.key .. "-nuit", center, zoom, NIGHT)
    local top = { x = g.x1 + 7.5 * g.step, y = g.y }
    local ztop = math.min(2.4, RES[1] / (32 * (4 * g.step + 2)))
    shot(list, "niveaux-" .. g.key .. "-haut", top, ztop)
    shot(list, "niveaux-" .. g.key .. "-haut-nuit", top, ztop, NIGHT)
  end
  shot(list, "murs-monde", { x = S.ox0 + 10, y = S.oy }, 0.9)
  shot(list, "biomes", { x = S.ox0 + 105, y = S.oy }, 0.7)
  shot(list, "modules", { x = S.mx0 + 25, y = S.my0 + 6 }, 0.7)
  shot(list, "recettes", { x = S.rx0 + 33, y = S.ry0 + 9 }, 0.6)
  return list
end

local function war_list()
  local list = {}
  -- `global` est propre à chaque mod : les QG et avant-postes viennent de l'interface du mod.
  local poi = remote.call("factorio-overhaul", "points_of_interest")
  for _, f in ipairs(poi.factions) do
    shot(list, "qg-" .. f.key, f.hq, 0.8)
    for n, o in ipairs(f.outposts) do
      if n <= 2 then shot(list, "avant-poste-" .. f.key .. "-" .. o.kind, o.pos, 1.0) end
    end
  end
  biome_shots(list, game.surfaces[1])
  if poi.player then
    shot(list, "equipe-joueur", poi.player.hq, 0.9)
    for n, o in ipairs(poi.player.outposts) do
      if n <= 2 then shot(list, "equipe-joueur-" .. o.kind, o.pos, 1.0) end
    end
  end
  log("[FO-SHOTS] points d'interet : " .. #poi.factions .. " factions, equipe du joueur " .. tostring(poi.player ~= nil))
  return list
end

function Shots.on_tick(e, scenario)
  local player = game.connected_players[1]
  if not player then return end
  local st = global.shots
  if not st then
    st = { start = e.tick, i = 1, next = e.tick + 90, content = scenario == "content" }
    global.shots = st
    player.game_view_settings.show_side_menu = false
    if not st.content then
      game.speed = 8
      st.next = e.tick + WARMUP
    end
    log("[FO-SHOTS] debut, scenario " .. tostring(scenario))
    return
  end
  if st.done or e.tick < st.next then return end
  if not st.list then
    game.speed = 1
    st.list = st.content and content_list() or war_list()
    log("[FO-SHOTS] " .. #st.list .. " captures prevues")
  end
  local s = st.list[st.i]
  if not s then
    st.done = true
    game.write_file("fo-shots/done.txt", "termine " .. #st.list .. " captures\n")
    log("[FO-SHOTS] termine")
    return
  end
  game.take_screenshot({
    player = player, surface = player.surface, position = { s.x, s.y }, resolution = RES, zoom = s.zoom,
    path = string.format("fo-shots/%02d-%s.png", st.i, s.name), show_entity_info = true, anti_alias = true,
    quality = 85, daytime = s.daytime, allow_in_replay = true,
  })
  st.i = st.i + 1
  st.next = e.tick + 20
end

return Shots
