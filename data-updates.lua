-- Étape data-updates : ajustements de prototypes vanilla, une fois tous les data.lua chargés.

local W = require("shared.content.world")

-- Le tungstène est un minerai dur : seules les foreuses électriques (et futures foreuses du mod) le minent.
for _, drill in pairs(data.raw["mining-drill"]) do
  local cats = drill.resource_categories or {}
  local solid, has_hard = false, false
  for _, c in ipairs(cats) do
    if c == "basic-solid" then solid = true end
    if c == "fo-hard-solid" then has_hard = true end
  end
  local burner = drill.energy_source and drill.energy_source.type == "burner"
  if solid and not has_hard and not burner then
    cats[#cats + 1] = "fo-hard-solid"
    drill.resource_categories = cats
  end
end

-- Le méthane est un carburant de lance-flammes plus violent que les huiles vanilla.
for _, turret in pairs(data.raw["fluid-turret"]) do
  local ap = turret.attack_parameters
  local fluids = ap and ap.fluids
  -- Seulement les lance-flammes (le pulvérisateur d'acide du mod ne brûle rien).
  if fluids and ap.ammo_type and ap.ammo_type.category == "flamethrower" then
    fluids[#fluids + 1] = { type = W.resources.methane.fluid, damage_modifier = W.resources.methane.flamethrower_damage_modifier }
  end
end
