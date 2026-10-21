--[[
  Niveaux : STYLE COMMUN des 7 familles, par époque (Q10, 21/10, 18 h 49 : une forme commune aux familles
  d'une même époque). Palette, matériaux et pièces partagés, lus par les fichiers de famille via
  `ctx.kit.palette` (alias de Style.palette) ou `require("prototypes.levels.style")`.

  Propriétaire : UN SEUL lot (le lot V1 ou le lot V3 meneur, à désigner dans OBJECTIFS §7). Les autres
  fichiers de famille le LISENT et ne le modifient jamais (la garde de prototypes/levels/common.lua arrête
  l'étape data si dress modifie cette table).

  État : PROVISOIRE (lot V2) : la palette de la session 5, rejetée sur le design (E25), ramenée à
  15 époques. Lueur visible de jour à partir de l'époque 5, halo de nuit à partir de l'époque 6, socle à
  partir du niveau 2.
]]

local Style = {}

Style.palette = {
  glow = {
    [5] = { r = 1.00, g = 0.32, b = 0.06 }, [6] = { r = 0.30, g = 0.80, b = 1.00 },
    [7] = { r = 0.65, g = 0.30, b = 1.00 }, [8] = { r = 0.50, g = 1.00, b = 0.30 },
    [9] = { r = 0.40, g = 1.00, b = 0.40 }, [10] = { r = 0.40, g = 0.90, b = 1.00 },
    [11] = { r = 0.90, g = 0.95, b = 1.00 }, [12] = { r = 0.20, g = 0.70, b = 1.00 },
    [13] = { r = 1.00, g = 0.40, b = 0.90 }, [14] = { r = 1.00, g = 0.85, b = 0.40 },
    [15] = { r = 1.00, g = 0.88, b = 0.55 },
  },
  foundation = {
    [1] = { tile = "stone-path" }, [2] = { tile = "stone-path" }, [3] = { tile = "concrete" },
    [4] = { tile = "concrete" }, [5] = { tile = "refined-concrete" }, [6] = { tile = "refined-concrete" },
    [7] = { tile = "refined-concrete" }, [8] = { tile = "refined-hazard-concrete" },
    [9] = { tile = "refined-hazard-concrete" }, [10] = { tile = "refined-hazard-concrete" },
    [11] = { tile = "refined-concrete" }, [12] = { tile = "refined-concrete" },
    [13] = { tile = "refined-concrete", tint = { r = 0.90, g = 0.80, b = 1.00 } },
    [14] = { tile = "refined-concrete", tint = { r = 1.00, g = 0.84, b = 0.42 } },
    [15] = { tile = "refined-concrete", tint = { r = 1.00, g = 0.92, b = 0.70 } },
  },
}

return Style
