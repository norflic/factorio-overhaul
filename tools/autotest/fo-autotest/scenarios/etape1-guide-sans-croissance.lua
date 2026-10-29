-- Lot CORR-ENERGIE : TEMOIN A' de etape1-guide, croissance de la centrale COUPEE (reglage de banc no_grow du plan directeur,
-- pose pour chaque equipe des que son plan existe). Meme partie, memes releves ; comparer [FO-ENERGIE] et [FO-FONCTION].
local base = require("scenarios/etape1-guide")
local tick0 = base.tick
base.description = base.description .. " -- TEMOIN : croissance de la centrale coupee"
base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick % 300 == 7 then
    local ok, rows = pcall(remote.call, "fo-ia1", "teams")
    for _, row in ipairs(ok and rows or {}) do
      pcall(remote.call, "fo-ia1d", "set_option", row.key, "no_grow", true)
    end
  end
end
return base
