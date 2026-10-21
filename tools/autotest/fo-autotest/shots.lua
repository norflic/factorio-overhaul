--[[
  Revue VISUELLE automatique (session avec images, fo-visual.bat / fo-captures.bat) : dès qu'un joueur est
  connecté, le mod de test prend une série de captures (game.take_screenshot) des points d'intérêt, puis
  écrit le marqueur de fin. Aucune saisie clavier ; la session est fermée par le pilote (visual_session.py).

  Scénario « content » : arène de contenu (tourelles en duel, ennemis, murs, ressources, biomes, niveaux).
  Scénario « vitrine » : entités demandées par fo-vitrine.lua, à côté des bâtiments vanilla de référence.
  Scénario greffé (scenarios/<nom>.lua) qui déclare `shots` : ses captures ; les contrôles greffés du banc
  « content » (checks/*.lua) ajoutent les leurs à la galerie « content ».
  Autres scénarios : la partie est accélérée (×8) jusqu'à 10 min de jeu, puis QG, avant-postes, ouvriers.

  Sorties (script-output/fo-shots/, dossier vidé par le pilote avant chaque session) :
    plan.txt   : nombre de captures prévues (écrit dès que la liste est connue) ;
    index.tsv  : une ligne par capture DEMANDÉE (numéro, fichier, scène, x, y, zoom, heure, tick, résolution) ;
    NNN-<scène>.png : les captures, numérotées dans l'ordre de la liste (nommage déterministe) ;
    done.txt   : écrit FLUSH ticks après set_wait_for_screenshots_to_finish (captures écrites sur disque).
  Le pilote vérifie ensuite chaque PNG (décodage complet) : le marqueur seul ne suffit pas.
]]

local Vitrine = require("vitrine")
local Greffons = require("greffons")

local Shots = {}

local RES = { 1600, 900 }
local WARMUP = 36000
local CADENCE = 10   -- ticks entre deux demandes de capture
local FLUSH = 60     -- ticks entre l'attente des captures et le marqueur de fin
local DIR = "fo-shots/"

local NIGHT = 0.5 -- surface.daytime : 0 = midi, 0.5 = minuit (les lueurs « draw_as_glow » se voient)

--- Une capture : nom de scène, centre, zoom, heure du jour ; options : résolution, alt-mode, anticrénelage.
local function shot(list, name, pos, zoom, daytime, opt)
  opt = opt or {}
  list[#list + 1] = {
    name = name, x = pos.x or pos[1], y = pos.y or pos[2], zoom = zoom or 1, daytime = daytime or 0,
    res = opt.res or RES, info = opt.info ~= false, aa = opt.aa ~= false,
  }
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

--- Fonction d'ajout passée aux greffons : add(nom, x, y, zoom, daytime, options).
local function adder(list)
  return function(name, x, y, zoom, daytime, opt)
    shot(list, name, { x = x, y = y }, zoom, daytime, opt)
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
  -- Niveaux (session 5 ; 15 époques depuis le lot V2) : la galerie de chaque famille par tranches de
  -- 10 niveaux (centre : 15 en une vue), de jour et de nuit, et les 4 derniers niveaux de près.
  for _, g in ipairs(S.gallery or {}) do
    local levels = g.levels or 10
    local per = levels <= 15 and levels or 10
    for first = 1, levels, per do
      local count = math.min(per, levels - first + 1)
      local center = { x = g.x1 + (first - 1 + (count - 1) / 2) * g.step, y = g.y }
      local zoom = math.min(1.4, RES[1] / (32 * (count * g.step + 4)))
      local tag = string.format("niveaux-%s-%02d-%02d", g.key, first, first + count - 1)
      shot(list, tag, center, zoom)
      shot(list, tag .. "-nuit", center, zoom, NIGHT)
    end
    local top = { x = g.x1 + (levels - 2.5) * g.step, y = g.y }
    local ztop = math.min(2.4, RES[1] / (32 * (4 * g.step + 2)))
    shot(list, "niveaux-" .. g.key .. "-haut", top, ztop)
    shot(list, "niveaux-" .. g.key .. "-haut-nuit", top, ztop, NIGHT)
  end
  shot(list, "murs-monde", { x = S.ox0 + 10, y = S.oy }, 0.9)
  shot(list, "biomes", { x = S.ox0 + 105, y = S.oy }, 0.7)
  shot(list, "modules", { x = S.mx0 + 25, y = S.my0 + 6 }, 0.7)
  shot(list, "recettes", { x = S.rx0 + 33, y = S.ry0 + 9 }, 0.6)
  Greffons.content_shots(adder(list)) -- captures des contrôles greffés (checks/*.lua)
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

local function vitrine_list()
  local list = {}
  for _, s in ipairs(Vitrine.shot_list(NIGHT)) do
    shot(list, s.name, { x = s.x, y = s.y }, s.zoom, s.daytime, { res = s.res, info = s.info, aa = s.aa })
  end
  -- Bilan de la pose (fait pendant --create) relu par le pilote : une entité refusée = code de sortie 6.
  local W = global.vitrine
  local lines = { "echecs\t" .. tostring(W and W.failures or "absent"), "source\t" .. tostring(W and W.source),
    "sol\t" .. tostring(W and W.sol) }
  for _, r in ipairs(W and W.rows or {}) do
    lines[#lines + 1] = "rangee\t" .. r.key .. "\t" .. r.name .. "\t"
      .. (#r.errors == 0 and "OK" or ("ECHEC : " .. table.concat(r.errors, " ; ")))
  end
  game.write_file(DIR .. "vitrine.txt", table.concat(lines, "\n") .. "\n", false)
  return list
end

local function fmt(v)
  return string.format("%.3f", v)
end

--- Une demande de capture, consignée dans index.tsv au même moment.
local function take(player, i, s, tick)
  local file = string.format("%03d-%s.png", i, s.name)
  game.take_screenshot({
    player = player, surface = game.surfaces[1], position = { s.x, s.y }, resolution = s.res, zoom = s.zoom,
    path = DIR .. file, show_entity_info = s.info, anti_alias = s.aa,
    daytime = s.daytime, allow_in_replay = true, force_render = true,
  })
  game.write_file(DIR .. "index.tsv", table.concat({
    string.format("%03d", i), file, s.name, fmt(s.x), fmt(s.y), fmt(s.zoom), fmt(s.daytime), tostring(tick),
    s.res[1] .. "x" .. s.res[2], s.info and "1" or "0", s.aa and "1" or "0",
  }, "\t") .. "\n", true)
end

function Shots.on_tick(e, scenario)
  local player = game.connected_players[1]
  if not player then return end
  local st = global.shots
  if not st then
    local delay = Greffons.scenario_shot_delay() -- scénario greffé qui déclare des captures
    st = { start = e.tick, i = 1, next = e.tick + (delay or 90),
      quick = (scenario == "content" or scenario == "vitrine" or delay ~= nil) }
    global.shots = st
    player.game_view_settings.show_side_menu = false
    if not st.quick then
      game.speed = 8
      st.next = e.tick + WARMUP
    end
    game.write_file(DIR .. "index.tsv",
      "num\tfichier\tscene\tx\ty\tzoom\tdaytime\ttick\tresolution\talt_mode\tanti_alias\n", false)
    log("[FO-SHOTS] debut, scenario " .. tostring(scenario) .. ", tick " .. e.tick
      .. ", joueurs " .. #game.players .. " (connectes " .. #game.connected_players .. ")")
    return
  end
  if st.finished or e.tick < st.next then return end
  if not st.list then
    game.speed = 1
    if scenario == "content" then
      st.list = content_list()
    elseif scenario == "vitrine" then
      st.list = vitrine_list()
    elseif Greffons.scenario_shot_delay() then
      st.list = {}
      Greffons.scenario_shots(adder(st.list))
    else
      st.list = war_list()
    end
    game.write_file(DIR .. "plan.txt", #st.list .. " captures prevues, scenario " .. tostring(scenario) .. "\n", false)
    log("[FO-SHOTS] " .. #st.list .. " captures prevues")
  end
  if st.flush_at then
    -- Les captures sont écrites de façon asynchrone : on attend qu'elles soient sur disque, puis on laisse
    -- FLUSH ticks avant le marqueur (le pilote revérifie chaque fichier).
    if not st.waited then
      game.set_wait_for_screenshots_to_finish()
      st.waited = true
      st.next = e.tick + FLUSH
      return
    end
    st.finished = true
    game.write_file(DIR .. "done.txt", "termine " .. #st.list .. " captures, tick " .. e.tick .. "\n", false)
    log("[FO-SHOTS] termine : " .. #st.list .. " captures, tick " .. e.tick)
    return
  end
  local s = st.list[st.i]
  if not s then
    st.flush_at = e.tick
    st.next = e.tick + 1
    return
  end
  take(player, st.i, s, e.tick)
  st.i = st.i + 1
  st.next = e.tick + CADENCE
end

return Shots
