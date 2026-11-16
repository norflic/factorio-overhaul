-- Lot UI-FLUX : la partie de jalons (jalons_common, 20 min) + le panneau « Flux de l'IA » : à 10 et à 20 min, la ligne [FO-FLUX-IA] de l'équipe du joueur
-- (pourcentages et temps écoulé par catégorie, remote fo-flux), le coût d'une passe de rafraîchissement ([FO-FLUX-COUT], profileur du moteur) et,
-- si une session avec images est ouverte (--captures --visuel), une capture AVEC l'interface du joueur : fo-shots/flux-m010.png, flux-m020.png.
-- Lecture : grep "FO-FLUX-IA\|FO-FLUX-COUT\|FO-FLUX-SCEN" dans le journal de l'archive.
local base = require("scenarios/jalons_common")(20)
local MIN = 3600
local TAG = "[FO-FLUX-SCEN] "

local function panneau(minute)
  local ligne = remote.call("fo-flux", "ligne", minute)
  log(TAG .. "minute " .. minute .. " ligne=" .. tostring(ligne))
  local p = game.connected_players[1]
  if not p then
    log(TAG .. "aucun joueur connecte : panneau non ouvert (ligne seule)")
    return
  end
  local ok = remote.call("fo-flux", "ouvrir", p.index)
  log(TAG .. "minute " .. minute .. " panneau ouvert=" .. tostring(ok) .. " joueur=" .. p.name .. " force=" .. p.force.name)
  remote.call("fo-flux", "cout", p.index, 20)
end

-- La capture suit l'ouverture de 3 ticks : l'interface ajoutee pendant le tick n'est pas encore dessinee a l'instant de l'appel.
local function capture(minute)
  local p = game.connected_players[1]
  if not (p and p.gui.left["fo_flux_frame"]) then return end -- (le panneau ouvert 3 ticks plus tot, rafraichi par son passage de 60 ticks)
  local s = p.surface
  local r = p.display_resolution
  local w, h = math.min(4096, math.max(1280, r.width)), math.min(4096, math.max(720, r.height))
  local hq = s.find_entities_filtered({ force = p.force, name = "fo-team-chest", limit = 1 })[1]
  game.take_screenshot({ player = p, surface = s, position = hq and hq.position or p.position, resolution = { w, h }, zoom = 0.35,
    path = string.format("fo-shots/flux-m%03d.png", minute), show_gui = true, show_entity_info = true, daytime = 0, allow_in_replay = true,
    force_render = true })
  game.set_wait_for_screenshots_to_finish()
  log(TAG .. "capture fichier=fo-shots/flux-m" .. string.format("%03d", minute) .. ".png (" .. w .. " x " .. h .. ")")
end

local tick0 = base.tick
base.description = "FLUX : jalons 20 min + panneau Flux de l'IA ouvert a 10 et 20 min ([FO-FLUX-IA], [FO-FLUX-COUT], captures avec interface)"
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick == 10 * MIN or e.tick == 20 * MIN then
    local ok, err = pcall(panneau, math.floor(e.tick / MIN))
    if not ok then log(TAG .. "ERREUR " .. tostring(err)) end
  end
  if e.tick == 10 * MIN + 3 or e.tick == 20 * MIN + 3 then
    local ok, err = pcall(capture, math.floor((e.tick - 3) / MIN))
    if not ok then log(TAG .. "ERREUR capture " .. tostring(err)) end
  end
end
return base
