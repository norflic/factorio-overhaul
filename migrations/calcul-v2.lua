-- Migration du moteur (dossier migrations/ : jouée UNE fois par sauvegarde, jamais pour une partie neuve).
-- Lot CALCUL-V2 (30/10) : les cinq technologies du calcul v1 gardent leur nom et ouvrent en plus les recettes v2 ; deux
-- technologies neuves s'intercalent (fo-wafer-fab avant fo-data-centers, fo-data-centers-2 avant fo-quantum-computing).
-- Une sauvegarde 0.6.27 où une technologie v1 est recherchée : ses prérequis neufs sont accordés (comme la migration
-- amelio-crafts-titane) et ses recettes v2 ouvertes. Aucun `global` touché (les centres sont migrés par
-- script/compute/compute.lua à on_configuration_changed). Forces parcourues par numéro (déterminisme).
local GRANT = {
  -- technologie recherchée -> prérequis neufs à accorder (ordre)
  { "fo-data-centers", { "fo-wafer-fab" } },
  { "fo-quantum-computing", { "fo-data-centers-2" } },
}
local TECHS = { "fo-wafer-fab", "fo-chip-foundry", "fo-data-centers", "fo-gpu-computing", "fo-data-centers-2", "fo-quantum-computing" }

local forces = {}
for _, f in pairs(game.forces) do forces[#forces + 1] = f end
table.sort(forces, function(a, b) return a.index < b.index end)

for _, f in ipairs(forces) do
  local granted, opened = 0, 0
  for _, g in ipairs(GRANT) do
    local t = f.technologies[g[1]]
    if t and t.researched then
      for _, name in ipairs(g[2]) do
        local p = f.technologies[name]
        if p and not p.researched then p.researched = true; granted = granted + 1 end
      end
    end
  end
  for _, name in ipairs(TECHS) do
    local t = f.technologies[name]
    if t and t.researched then
      for _, eff in ipairs(t.effects) do
        if eff.type == "unlock-recipe" then
          local r = f.recipes[eff.recipe]
          if r and not r.enabled then r.enabled = true; opened = opened + 1 end
        end
      end
    end
  end
  if granted + opened > 0 then
    log("[FO-CALCUL-V2-MIGRATION] force " .. f.name .. " : " .. granted .. " technologie(s) accordee(s), " .. opened .. " recette(s) ouverte(s)")
  end
end
