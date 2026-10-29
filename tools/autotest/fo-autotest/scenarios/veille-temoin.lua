-- Lot VEILLE : TEMOIN sur la MEME source que le lot, reconnaissance reguliere eteinte (remote veille_options { on = false } au tick 30) :
-- memes bilans de 10 min (secteurs reconnus), aucun vivier. Lancement : banc.py --out <archive> --graine <g> --qui RECON -- 216300 veille-temoin <source>.
local base = require("scenarios/etape1-guide")
local tick0 = base.tick
base.description = base.description .. " -- veille eteinte (temoin du lot VEILLE)"
base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick == 30 then
    local ok, r = pcall(remote.call, "factorio-overhaul", "veille_options", { on = false })
    log("[FO-VEILLE] option veille eteinte : " .. tostring(ok) .. " " .. tostring(ok and r and r.on))
  end
end
return base
