--[[
  Lot PETROLE : banc COURT et ACCÉLÉRÉ de l'exécutant (pas une partie : la preuve A9 est petrole-partie). La partie
  d'iag-partie, réglage fo-war-petrole allumé ; au tick 300, chaque faction reçoit les technologies de la chaîne du
  pack chimique (force.technologies, et l'état de recherche du QG) et, dans le coffre de son QG, les bâtiments et
  pièces d'un site (chevalets, raffinerie, usines chimiques, pompe, tuyaux, bras, coffres, poteaux, centrale) et de quoi
  le nourrir. Mesure : le site est-il demandé, planifié, BÂTI par les PNJ, raccordé (tuyaux, courant), et produit-il
  plastique et soufre ? Variante photo (banc.py --captures) : capture du site de chaque faction.
]]
local common = require("scenarios/petrole_common")
local TECHS = { "automation", "electronics", "logistic-science-pack", "steel-processing", "automation-2", "engine",
  "fluid-handling", "oil-processing", "plastics", "advanced-electronics", "sulfur-processing", "chemical-science-pack",
  "electric-energy-distribution-1", "logistics" }
local KIT = { { "pumpjack", 4 }, { "oil-refinery", 2 }, { "chemical-plant", 4 }, { "offshore-pump", 3 }, { "pipe", 600 },
  { "inserter", 20 }, { "iron-chest", 20 }, { "medium-electric-pole", 120 }, { "small-electric-pole", 60 },
  { "boiler", 2 }, { "steam-engine", 4 }, { "assembling-machine-1", 4 }, { "coal", 400 }, { "steel-plate", 100 },
  { "iron-gear-wheel", 100 }, { "iron-plate", 400 } }
return function(variant)
  local base = common(variant or "site", 54000)
  local tick0 = base.tick
  base.tick = function(ctx, e)
    tick0(ctx, e)
    if e.tick ~= 300 then return end
    local ok, rows = pcall(remote.call, "fo-ia1", "teams")
    local s = ctx.surface()
    for _, row in ipairs(ok and rows or {}) do
      if row.key ~= "player" then
        local f = game.forces[row.force]
        local n = 0
        for _, t in ipairs(TECHS) do
          if f and f.technologies[t] and not f.technologies[t].researched then f.technologies[t].researched = true; n = n + 1 end
        end
        local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = row.force, limit = 1 })[1]
        local put = 0
        if hq and hq.valid then
          for _, it in ipairs(KIT) do put = put + hq.insert({ name = it[1], count = it[2] }) end
        end
        ctx.log(string.format("acceleration %s : %d technologies, %d objets au coffre du QG", row.key, n, put))
      end
    end
  end
  return base
end
