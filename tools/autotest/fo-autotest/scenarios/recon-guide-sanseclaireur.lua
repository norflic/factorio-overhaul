--[[
  Lot RECON, témoin SANS éclaireur : le MEME scenario recon-guide, avec les connaissances par la vue (aucune cible jamais vue) mais
  AUCUN soldat éclaireur (Recon.scouts_on = false, interface distante factorio-overhaul / recon_options). Sépare, dans l'écart
  d'armée entre main et le lot, ce qui vient des éclaireurs de ce qui vient du changement de connaissance.
  Lancement : banc.py --out <archive> --graine <g> --qui RECON -- 216300 recon-guide-sanseclaireur <source>.
]]
local base = require("scenarios/recon-guide")
local init0 = base.init
base.description = base.description .. " -- SANS soldat eclaireur"
base.init = function(ctx)
  if init0 then init0(ctx) end
  local ok, r = pcall(remote.call, "factorio-overhaul", "recon_options", { scouts = false })
  log("[FO-RECON-GUIDE] soldats eclaireurs coupes : " .. tostring(ok and r and r.scouts == false))
end
return base
