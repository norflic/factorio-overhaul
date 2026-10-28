--[[
  Lot RECON, mesure du gain de l'a priori d'anneau (RD_LOG E-RECON) : le MEME scenario recon-guide, avec la recherche d'une rivale
  SANS a priori d'anneau (Recon.ring_on = false, interface distante factorio-overhaul / recon_options). Seul ecart : la
  destination des eclaireurs « chercher » (frontiere de meilleure note sans anneau). Comparer, par graine, la premiere vue
  de chaque rivale (recon_mesures.py : « premieres vues ») avec recon-guide.
  Lancement : banc.py --out <archive> --graine <g> --qui RECON -- 216300 recon-guide-sansanneau <source>.
]]
local base = require("scenarios/recon-guide")
local init0 = base.init
base.description = base.description .. " -- SANS a priori d'anneau"
base.init = function(ctx)
  if init0 then init0(ctx) end
  local ok, r = pcall(remote.call, "factorio-overhaul", "recon_options", { ring = false })
  log("[FO-RECON-GUIDE] a priori d'anneau coupe : " .. tostring(ok and r and r.ring))
end
return base
