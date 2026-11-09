--[[
  Lot MALL (demande du DC, 9/11 : voir des rangées alignées sur capture) : la partie du guide sur la carte aux gisements maximaux (scenarios/max_build.lua), avec aux minutes 60, 75 et 90, pour chaque
  équipe qui a un secteur de mall, une capture du secteur (mall-carte-<équipe>-m<minute>.png) et un relevé [FO-MALL-CARTE] : rangées, machines, objets fabriqués.
  La difficulté est celle de la partie du guide (Normal sur essai-0666 depuis 52b5db3a).
  Lancement (images, place 1) :
    py -3.9 -B tools/autotest/banc.py --carte-max --graine 271828182 --out <archive> --qui mall --captures --visuel="--ticks 324200 --timeout 14400 --pcores" -- 324200 mall-carte <source>
]]

local base0 = require("scenarios/max_build")({
  description = "MALL-CARTE : partie du guide sur carte maximale, captures des secteurs du mall a 60, 75 et 90 min",
  check_tick = 323500,
  releve_at = 1500,
  photo_ticks = { 216000, 323400 },
  fmin = 3,
  shots = true,       -- (sans captures de fin, la session avec images s'arrête aux captures par défaut, vers 36 000 ticks)
  shots_delay = 323700,
})

local TAG = "[FO-MALL-CARTE] "
local KEYS = { "player", "scarlet", "azure", "amber", "emerald" }
local TICKS = { [216000] = true, [270000] = true, [323400] = true }
local ZOOM = 0.6
local RES = { 1800, 1400 }

local base = {}
for k, v in pairs(base0) do base[k] = v end
local tick0 = base0.tick

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  -- Votre équipe : le coffre posé par l'init du guide tombe dans un chunk que la carte maximale efface au même tick (delete_chunk ; déduit : « ouvriers du joueur 0 » sur carte-1b700721) : on le repose une fois le terrain refait
  if e.tick == 120 then
    local s = ctx.surface()
    if s.count_entities_filtered({ name = "fo-team-chest", force = "player" }) == 0 then
      local c = game.forces.player.get_spawn_position(s)
      local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
      local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre de votre equipe repose apres la regeneration de la carte")
      if chest then
        for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 }, { "pistol", 3 }, { "firearm-magazine", 60 }, { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
          chest.insert({ name = it[1], count = it[2] })
        end
      end
    end
  end
  if not TICKS[e.tick] then return end
  local minute = math.floor(e.tick / 3600)
  local player = game.connected_players[1]
  for _, key in ipairs(KEYS) do
    local rep = ctx.remote("fo-mall", "report", key)
    if rep and rep.sect then
      local s = rep.sect
      local fab = rep.fab or {}
      local parts = {}
      for _, r in ipairs(rep.rows or {}) do parts[#parts + 1] = string.format("%d:%d", r.j, r.cells) end
      ctx.log(TAG .. string.format("%s minute %d | secteur (%d, %d)-(%d, %d) sens %d | rangees %d {%s} | machines %s, en marche %s, fabriques %s, coffres %s", key, minute, s.x0, s.y0, s.x1, s.y1, s.dir,
        #(rep.rows or {}), table.concat(parts, " "), tostring(fab.machines), tostring(fab.run), tostring(fab.made), tostring(fab.chests)))
      if player then
        game.take_screenshot({ player = player, surface = ctx.surface(), position = { (s.x0 + s.x1) / 2, (s.y0 + s.y1) / 2 }, resolution = RES, zoom = ZOOM,
          path = string.format("fo-shots/mall-carte-%s-m%03d.png", key, minute), show_entity_info = true, anti_alias = true, daytime = 0, allow_in_replay = true, force_render = true })
      end
    end
  end
end

return base
