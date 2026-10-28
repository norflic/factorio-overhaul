-- Lot LEVIERS : même usine et même demande que leviers-modules, mais les sites restent OUVERTS : l'extraction et les modules se
-- font concurrence (choix par le retour T, règle de la capitalisation). Lancement : banc.py ... -- 36200 leviers-libre <source>.
local base = require("scenarios/leviers-modules")
local S = {}
for k, v in pairs(base) do S[k] = v end
S.description = "LEVIERS : sites libres, extraction contre modules"
S.init = function(ctx)
  base.init(ctx)
  ctx.state().libre = true
end
return S
