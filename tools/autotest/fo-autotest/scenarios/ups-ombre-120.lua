-- Lot UPS (13/11) : partie-reelle-120 avec l'OMBRE du registre des machines (script/team/registre_types.lua) : chaque lecture du
-- registre refait l'ancienne recherche sur toute la surface et compare ; un écart écrit [FO-REGISTRE-OMBRE]. Bilan à 60 et 120 min,
-- avec le recensement du stockage. Mêmes décisions que partie-reelle-120 (l'ombre ne fait que lire).
local S = require("scenarios/ups-recensement-120")
S.description = "UPS : partie-reelle-120, ombre du registre des machines, recensement"
-- L'ombre est une copie LOCALE du mod (jamais dans le stockage) : le banc crée la carte dans un processus et la rejoue dans un autre ;
-- elle est donc allumée au premier tick vu par CE processus (drapeau local du scénario, perdu au chargement comme elle).
local ombre_on = false
local tick0 = S.tick
S.tick = function(ctx, e)
  if not ombre_on then
    ombre_on = true
    ctx.remote("fo-ups-registre", "ombre", true)
  end
  tick0(ctx, e)
  if e.tick == 216001 or e.tick == 432001 then
    local b = ctx.remote("fo-ups-registre", "bilan")
    local sites = {}
    for k, v in pairs(b.sites) do sites[#sites + 1] = k .. "=" .. v end
    table.sort(sites)
    log(string.format("[FO-REGISTRE-OMBRE] bilan min=%d pret=%s lectures=%d ecarts=%d replis=%d tenues=%d releves=%d sites=%s", (e.tick - 1) / 3600,
      tostring(b.pret), b.lectures, b.ecarts, b.replis, b.tenues, b.releves, table.concat(sites, ",")))
  end
end
return S
