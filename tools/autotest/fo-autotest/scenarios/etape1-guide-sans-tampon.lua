-- Lot COMBUSTIBLE-CENTRALE : TEMOIN de etape1-guide, regle du tampon de charbon (levier a) COUPEE (reglage de banc no_tampon du plan
-- directeur, pose pour chaque equipe des que son plan existe). Meme partie, memes releves : comparer [FO-CHARBON-CENTRALE], [FO-SANTE-CENTRALE].
local base = require("scenarios/etape1-guide")
local tick0 = base.tick
base.description = base.description .. " -- TEMOIN : tampon de charbon de la centrale coupe"
base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick % 300 == 7 then
    local ok, rows = pcall(remote.call, "fo-ia1", "teams")
    for _, row in ipairs(ok and rows or {}) do
      pcall(remote.call, "fo-ia1d", "set_option", row.key, "no_tampon", true)
    end
  end
end
return base
