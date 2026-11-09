-- Lot COMBUSTIBLE-MIGRATION : TEMOIN de etape1-carte, regle « le retrait des paires d'une bande de combustible exige un stock qui couvre le chantier »
-- COUPEE (reglage de banc no_combustible du plan directeur, pose pour chaque equipe des que son plan existe). Meme partie, memes releves.
local base = require("scenarios/etape1-carte")
local tick0 = base.tick
base.description = base.description .. " -- TEMOIN : retrait des paires de combustible sans garde du stock"
base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick % 300 == 7 then
    local ok, rows = pcall(remote.call, "fo-ia1", "teams")
    for _, row in ipairs(ok and rows or {}) do
      pcall(remote.call, "fo-ia1d", "set_option", row.key, "no_combustible", true)
    end
  end
end
return base
