-- Corps physique du compagnon : clone du personnage vanilla.
-- Hypothèse H0 (RD_LOG.md) : un `character` sans joueur conserve inventaire, PV, minage et tir.
-- Aucun sprite nouveau : la teinte est appliquée au runtime via LuaEntity.color.

local body = table.deepcopy(data.raw["character"]["character"])
body.name = "fo-companion"
body.localised_name = { "entity-name.fo-companion" }
body.localised_description = { "entity-description.fo-companion" }

data:extend({ body })
