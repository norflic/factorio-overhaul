--[[
  Dézoom étendu (shared/gui/dezoom.lua : la règle et la raison). Touches « fo-dezoom-down » et « fo-dezoom-up »
  (Ctrl + molette par défaut, réassignables dans les contrôles). Chaque appui écrit `player.zoom` UNE fois : aucune
  boucle par tick. Le cran est mémorisé par joueur (espace « dezoom » de `global`, indexé par numéro de joueur).

  DÉTERMINISME : un événement de touche est synchronisé par le moteur chez tous les joueurs ; le gestionnaire ne lit rien
  de local (ni résolution ni échelle) et n'écrit que le cran du joueur concerné.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local M = require("shared.gui.dezoom")

Storage.declare("dezoom", function() return { idx = {} } end)

local function state()
  return Storage.ns("dezoom")
end

--- Un appui pour le joueur `player` (LuaPlayer). Rend le cran, le zoom écrit (ou nil).
local function press(player, down)
  if not (player and player.valid and player.connected) then return nil end
  if player.render_mode ~= defines.render_mode.game then return nil end -- la carte a son propre zoom
  local st = state()
  if not st then return nil end
  local idx, zoom = M.step(st.idx[player.index] or 0, down)
  st.idx[player.index] = idx
  if not zoom then return idx, nil end
  player.zoom = zoom
  if idx == 0 then
    player.print({ "fo-dezoom.normal" })
  else
    player.print({ "fo-dezoom.cran", idx, M.count(), M.view_percent(zoom) })
  end
  return idx, zoom
end

Events.on("fo-dezoom-down", function(e) press(game.get_player(e.player_index), true) end)
Events.on("fo-dezoom-up", function(e) press(game.get_player(e.player_index), false) end)

-- Pilotage des bancs (un script ne lève pas un événement de touche) : mêmes fonctions que la touche.
remote.add_interface("fo-dezoom", {
  press = function(player_index, down)
    return press(game.get_player(player_index), down and true or false)
  end,
  cran = function(player_index)
    local st = state()
    return st and st.idx[player_index] or 0
  end,
})
