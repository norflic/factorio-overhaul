--[[
  Lot CC-GISEMENT (F490, 10/11/2026) : la partie du guide (etape1-guide) AVEC l'épave de freeplay, comme une partie neuve du DC.
  Le banc coupe l'épave (control.lua, skip_freeplay_intro) et ne crée aucun joueur : on_player_created de freeplay ne tourne
  jamais, et ses flammes (crash-site-fire-flame, créées sans force : « enemy » par défaut du moteur) n'existaient dans aucun banc.
  Dans la partie du DC (0.6.87, graine 3592985581), elles ont fait refuser « hostile » les quatre sites de fer voisins du coffre
  d'équipe au tick 180 ; l'équipe est partie à 177 tuiles.
  Ici : l'épave est posée à l'init en (-5, -6) par la bibliothèque du jeu (crash-site.lua, pièces par défaut, comme freeplay).
  Relevé [FO-EPAVE] aux ticks 1, 180, 600 et 1800 : entités de la force « enemy » à 48 tuiles du coffre d'équipe, par type
  (la cause, lue au moteur, indépendante des décisions du mod).
  Lancement : banc.py --out <archive> --graine 3592985581 --qui CC-GISEMENT -- 108000 etape1-guide-epave <source>.
]]
local crash_site = require("crash-site")
local base = require("scenarios/etape1-guide")
local init0, tick0 = base.init, base.tick
local TAG = "[FO-EPAVE] "
local SPOTS = { [1] = true, [180] = true, [600] = true, [1800] = true }

base.description = "CC-GISEMENT : " .. tostring(base.description or "etape1-guide") .. ", epave de freeplay posee"

base.init = function(ctx)
  if init0 then init0(ctx) end
  local s = ctx.surface()
  s.request_to_generate_chunks({ 0, 0 }, 3)
  s.force_generate_chunk_requests()
  crash_site.create_crash_site(s, { -5, -6 }, {}, {}, crash_site.default_ship_parts())
  local n = s.count_entities_filtered({ position = { -5, -6 }, radius = 60, name = "crash-site-fire-flame" })
  log(TAG .. string.format("epave posee en (-5, -6) : %d flamme(s) a 60 tuiles", n))
end

base.tick = function(ctx, e)
  if SPOTS[e.tick] then
    local s = ctx.surface()
    local by = {}
    for _, ent in ipairs(s.find_entities_filtered({ position = { 6, 6 }, radius = 48 + 40, force = "enemy" })) do
      local k = ent.type .. ":" .. ent.name
      by[k] = (by[k] or 0) + 1
    end
    local keys = {}
    for k in pairs(by) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. by[k] end
    log(TAG .. string.format("tick %d : force enemy a 88 tuiles du coffre (6, 6) : %s", e.tick,
      #parts > 0 and table.concat(parts, " ") or "aucune"))
  end
  if tick0 then return tick0(ctx, e) end
end

return base
