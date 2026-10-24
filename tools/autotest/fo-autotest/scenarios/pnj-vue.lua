--[[
  Lot PNJ-VÉRIF (24/10) : CAPTURES des PNJ en action, pour le Directeur Créatif.
  Carte et guerre d'`ia0-normal` (difficulté Normale, base témoin du joueur en (-96, 10) depuis le départ) PLUS un
  coffre d'équipe garni près du départ (comme le scénario `pteam`) : 4 factions, l'équipe du joueur, des attaques.
  Session avec images : la partie tourne à ×8 jusqu'à SHOTS_DELAY - 600 ticks, puis à ×1 ; au tick SHOTS_DELAY
  (≈ 26,8 min de jeu, après la 1re attaque d'Écarlate contre le joueur au tick 93 901 dans `ia0-normal`) :
  - chaque QG de faction (soldats en garnison, ouvriers, fonderie) ;
  - pour chaque faction, l'ouvrier le plus éloigné de son QG (en tournée, sur un chantier, à la mine) ;
  - chaque groupe de soldats en marche ou au combat (5 membres au moins, 4 au plus) ;
  - la base témoin du joueur, le coffre d'équipe et 3 ouvriers de l'équipe du joueur.
  Ce qui est photographié est écrit au journal ([FO-PNJ-VUE]). Lancement :
    $env:FO_VISUAL_ARGS = '--ticks 99000'
    & "<racine>\fo-captures.bat" pnj-vue "<source>"
    $env:FO_VISUAL_ARGS = $null
  Sans images (`fo-autotest.bat nopause 400 pnj-vue <source>`) : 2 contrôles de mise en place.
]]
local C = require("scenarios/ia0_common")

local SHOTS_DELAY = 96600

local function place_team_chest(ctx)
  local s = ctx.surface()
  local c = game.forces.player.get_spawn_position(s)
  local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
  local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
  if chest then
    for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
      { "pistol", 3 }, { "firearm-magazine", 60 }, { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
      chest.insert({ name = it[1], count = it[2] })
    end
  end
  return chest
end

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

return {
  description = "PNJ-VERIF : captures des PNJ en action (Normal, equipe du joueur)",
  base = nil,
  check_tick = 300,
  shots_delay = SHOTS_DELAY,

  init = function(ctx)
    C.build_base(ctx)
    C.start_war(ctx, "normal")
    local chest = place_team_chest(ctx)
    ctx.check(chest ~= nil, "coffre d'equipe pose", chest and string.format("(%d, %d)", chest.position.x, chest.position.y))
  end,

  tick = function(ctx, e)
    if #game.connected_players == 0 then return end
    local want = e.tick < SHOTS_DELAY - 600 and 8 or 1
    if game.speed ~= want then game.speed = want end
  end,

  finish = function(ctx)
    ctx.check(ctx.call("team_status") ~= nil, "equipe du joueur active")
  end,

  shots = function(ctx, add)
    local s = ctx.surface()
    local poi = ctx.call("points_of_interest")
    for _, f in ipairs(poi.factions) do
      add("qg-" .. f.key, f.hq.x, f.hq.y + 6, 0.7, 0)
      local best, bd
      for _, w in ipairs(s.find_entities_filtered({ type = "character", force = "fo-" .. f.key })) do
        local d = dist(w.position, f.hq)
        if not bd or d > bd then best, bd = w, d end
      end
      if best then
        add("ouvrier-" .. f.key, best.position.x, best.position.y, 1.4, 0)
        ctx.log(string.format("ouvrier %s a %d tuiles du QG en (%d, %d)", f.key, math.floor(bd), best.position.x, best.position.y))
      end
    end
    local groups, order = {}, {}
    for _, f in ipairs(poi.factions) do
      for _, u in ipairs(s.find_entities_filtered({ type = "unit", force = "fo-" .. f.key })) do
        local g = u.unit_group
        if g and g.valid and not groups[g.group_number] then
          groups[g.group_number] = { g = g, key = f.key, hq = f.hq }
          order[#order + 1] = g.group_number
        end
      end
    end
    table.sort(order)
    local n = 0
    for _, gn in ipairs(order) do
      local r = groups[gn]
      if n < 4 and #r.g.members >= 5 then
        n = n + 1
        local p = r.g.position
        local base = poi.player and poi.player.hq
        add(string.format("groupe-%s-%d", r.key, gn), p.x, p.y, 0.9, 0)
        ctx.log(string.format("groupe %d de %s : %d soldats, etat %d, en (%d, %d), a %d tuiles de son QG%s", gn, r.key, #r.g.members,
          r.g.state, p.x, p.y, math.floor(dist(p, r.hq)),
          base and string.format(", a %d tuiles du coffre d'equipe", math.floor(dist(p, base))) or ""))
      end
    end
    local c = game.forces.player.get_spawn_position(s)
    add("base-temoin-joueur", c.x - 96, c.y + 16, 0.9, 0)
    if poi.player then
      add("equipe-joueur-coffre", poi.player.hq.x, poi.player.hq.y, 1.0, 0)
      local k = 0
      for _, w in ipairs(s.find_entities_filtered({ type = "character", force = "player" })) do
        if k < 3 and not w.player then
          k = k + 1
          add("equipe-joueur-ouvrier-" .. k, w.position.x, w.position.y, 1.4, 0)
          ctx.log(string.format("ouvrier du joueur %d en (%d, %d), a %d tuiles du coffre", k, w.position.x, w.position.y,
            math.floor(dist(w.position, poi.player.hq))))
        end
      end
      for i, o in ipairs(poi.player.outposts) do
        if i <= 2 then add("equipe-joueur-" .. o.kind .. "-" .. i, o.pos.x, o.pos.y, 1.0, 0) end
      end
    end
  end,
}
