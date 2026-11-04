--[[
  Réglage du lot PANNEAU (4/11) : quand s'ouvre le panneau « Évolution » des bâtiments à niveaux. Étape settings uniquement ;
  requis par settings.lua.

  fo-levels-panneau (runtime-per-user : chaque joueur choisit, modifiable en cours de partie, effet au plus 30 ticks après)
    « clic » (défaut)  le panneau s'ouvre avec l'interface du bâtiment (clic) et se ferme avec elle ; la touche U améliore le
                       bâtiment survolé sans ouvrir le panneau ; Maj+U ouvre ou ferme le panneau du bâtiment survolé.
    « survol »         comportement d'avant : survoler un bâtiment (ou la touche U) ouvre son panneau, qui reste affiché.
  Règle : shared/levels/panneau.lua (valeurs et défaut : une seule source). Traductions : locale/*/levels_panneau.cfg.
]]

local P = require("shared.levels.panneau")

local values = {}
for i, v in ipairs(P.VALUES) do values[i] = v end

data:extend({
  {
    type = "string-setting",
    name = P.SETTING,
    setting_type = "runtime-per-user",
    default_value = P.DEFAULT,
    allowed_values = values,
    order = "l-panneau",
  },
})
