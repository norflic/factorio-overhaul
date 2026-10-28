--[[
  Lot RECON, témoin SANS éclaireur : le MEME scenario recon-guide, avec les connaissances par la vue (aucune cible jamais vue) mais
  AUCUN soldat éclaireur (Recon.scouts_on = false, interface distante factorio-overhaul / recon_options). Sépare, dans l'écart
  d'armée entre main et le lot, ce qui vient des éclaireurs de ce qui vient du changement de connaissance.
  Lancement : banc.py --out <archive> --graine <g> --qui RECON -- 216300 recon-guide-sanseclaireur <source>.
]]
local base = require("scenarios/recon-guide")
local tick0 = base.tick
base.description = base.description .. " -- SANS soldat eclaireur"
-- L'option est posée au tick 30 (la guerre et le mod sont lancés), pas dans init : le premier essai (init) n'a rien posé.
base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick == 30 then
    local ok, r = pcall(remote.call, "factorio-overhaul", "recon_options", { scouts = false })
    log("[FO-RECON-GUIDE] option scouts coupee : " .. tostring(ok) .. " " .. tostring(ok and r and r.scouts))
  end
end
return base
