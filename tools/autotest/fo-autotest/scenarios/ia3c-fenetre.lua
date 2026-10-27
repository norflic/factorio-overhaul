--[[
  Lot IA3-c : CAPTURES de la fenêtre « Équipe et factions » avec le cerveau par besoins (docs/IA3_CERVEAU.md §5.5) :
  bloc « Projets en cours » de votre équipe et des factions (projets, raison, ce qui manque, recherche, ce qu'on cherche,
  ce qu'on ne ramasse plus). Session AVEC images seulement :
    $env:FO_VISUAL_ARGS = '--ticks 29500' ; fo-captures.bat ia3c-fenetre <source> ; $env:FO_VISUAL_ARGS = $null
  Partie : réglage fo-war-ia3-cerveau allumé AVANT la guerre ; Facile ; 2 factions, 30 soldats, 10 ouvriers (8 au
  départ) ; votre coffre d'équipe SANS fer (le cas du DC : 600 pierres, 800 charbons). Captures à 7 min (onglet
  « Mon équipe », puis « Factions »). Journal : [FO-IA3C-FENETRE].
]]

local CHECK = 27500
local T_SHOT = 25200

local function player() return game.connected_players[1] end

local function shot(ctx, p, name)
  local st = ctx.state()
  local r = p.display_resolution
  local w, h = math.min(4096, math.max(640, r.width)), math.min(4096, math.max(360, r.height))
  game.take_screenshot({ path = "fo-shots/x-ia3c-" .. name .. ".png", player = p, show_gui = true,
    position = st.chest_pos, zoom = 1, resolution = { w, h }, daytime = 0, force_render = true, allow_in_replay = true })
  st.shots = (st.shots or 0) + 1
  ctx.log(string.format("capture x-ia3c-%s.png demandee au tick %d (%d x %d)", name, game.tick, w, h))
end

return {
  description = "IA3-c : captures de la fenetre (projets du cerveau par besoins)",
  base = nil,
  check_tick = CHECK,
  shots_delay = CHECK + 100,

  init = function(ctx)
    local v = ctx.remote("factorio-overhaul", "war_setting", "fo-war-ia3-cerveau", true)
    ctx.check(v == true, "reglage fo-war-ia3-cerveau allume", tostring(v))
    ctx.check(ctx.remote("fo-pvp", "set_difficulty", "easy") == true, "difficulte Facile")
    local w = ctx.remote("factorio-overhaul", "war_setting", "fo-war-workers", 10)
    ctx.check(w == 10, "fo-war-workers regle a 10", w)
    local started = ctx.call("war_start", 2, 30, 10)
    ctx.check(started == true, "guerre lancee : 2 factions, 30 soldats, 10 ouvriers", tostring(started))
    local s = ctx.surface()
    local c = game.forces.player.get_spawn_position(s)
    local pos = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
    local chest = pos and s.create_entity({ name = "fo-team-chest", position = pos, force = "player", raise_built = true })
    if chest then
      for _, it in ipairs({ { "stone", 600 }, { "coal", 800 }, { "firearm-magazine", 60 }, { "iron-plate", 6 } }) do
        chest.insert({ name = it[1], count = it[2] })
      end
    end
    ctx.check(chest ~= nil, "coffre d'equipe pose (sans fer : le cas du DC)")
    ctx.state().chest_pos = chest and { x = chest.position.x, y = chest.position.y } or c
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local p = player()
    if not p then
      if not st.no_player then
        st.no_player = true
        ctx.log("aucun joueur connecte (banc sans images) : captures en session avec images (fo-captures.bat)")
      end
      return
    end
    if e.tick == T_SHOT then
      ctx.remote("fo-ia1i", "open", p.index, "equipe")
    elseif e.tick == T_SHOT + 70 then
      shot(ctx, p, "01-equipe-projets")
    elseif e.tick == T_SHOT + 140 then
      ctx.remote("fo-ia1i", "select", p.index, "factions")
    elseif e.tick == T_SHOT + 210 then
      shot(ctx, p, "02-factions-projets")
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s3 = remote.call("fo-ia3c", "status", "player")
    ctx.check(s3 and s3.ia3c == true, "votre equipe au cerveau par besoins")
    ctx.check(s3 and #(s3.projects or {}) > 0, "projets ouverts dans votre equipe", s3 and #(s3.projects or {}) or 0)
    if player() then ctx.check((st.shots or 0) == 2, "2 captures demandees", st.shots) end
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local c = st.chest_pos or { x = 0, y = 0 }
    add("equipe-sol", c.x, c.y, 0.5, 0)
  end,
}
