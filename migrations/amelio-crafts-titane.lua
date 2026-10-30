-- Migration du moteur (dossier migrations/ : jouée UNE fois par sauvegarde, jamais pour une partie neuve).
-- Lot AMELIO-CRAFTS : fo-titanium-processing gagne le prérequis fo-electrical-steel, car les machines du titane demandent
-- désormais des bobines (fo-coil). Une sauvegarde où le titane est déjà recherché reçoit la chaîne neuve qui y mène
-- (âges 2 à 6, toute en dessous de l'âge 11) : sans cela, elle ne pourrait plus construire de machine du titane avant
-- cinq recherches. Aucun `global` touché ; forces parcourues par numéro (déterminisme).
local CHAIN = { "fo-coking", "fo-blast-furnace", "fo-crushing", "fo-arc-smelting", "fo-electrical-steel" }

local forces = {}
for _, f in pairs(game.forces) do forces[#forces + 1] = f end
table.sort(forces, function(a, b) return a.index < b.index end)

for _, f in ipairs(forces) do
  local ti = f.technologies["fo-titanium-processing"]
  if ti and ti.researched then
    local n = 0
    for _, name in ipairs(CHAIN) do
      local t = f.technologies[name]
      if t and not t.researched then
        t.researched = true
        n = n + 1
      end
    end
    if n > 0 then log("[FO-CRAFTS-MIGRATION] force " .. f.name .. " : " .. n .. " technologie(s) de la chaine des bobines accordee(s)") end
  end
end
