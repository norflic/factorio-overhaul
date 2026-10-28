--[[
  Lot RECON, mesure du gain de l'a priori d'anneau (RD_LOG E-RECON) : le MEME scenario recon-guide, avec la recherche d'une rivale
  SANS a priori d'anneau (Recon.ring_on = false, interface distante factorio-overhaul / recon_options). Seul ecart : la
  destination des eclaireurs « chercher » (frontiere de meilleure note sans anneau). Comparer, par graine, la premiere vue
  de chaque rivale (recon_mesures.py : « premieres vues ») avec recon-guide.
  Lancement : banc.py --out <archive> --graine <g> --qui RECON -- 216300 recon-guide-sansanneau <source>.
]]
local base = require("scenarios/recon-guide")
local tick0 = base.tick
base.description = base.description .. " -- SANS a priori d'anneau"
-- L'option est posée au tick 30 (la guerre et le mod sont lancés), pas dans init : le premier essai (init) n'a rien posé.
base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick == 30 then
    local ok, r = pcall(remote.call, "factorio-overhaul", "recon_options", { ring = false })
    log("[FO-RECON-GUIDE] option ring coupee : " .. tostring(ok) .. " " .. tostring(ok and r and r.ring))
  end
end
return base
