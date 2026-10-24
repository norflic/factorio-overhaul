-- GÉNÉRÉ par tools/sound/sons.py (lot S0) : ne pas modifier à la main.
-- Tir de la mitrailleuse par ère (âges 1-3, 4-6, 7-9, 10-12, 13-15) : 4 variations par ère, dérivées
-- des 4 tirs vanilla (gun-turret-gunshot-01 à 04), volume du prototype vanilla (0,4).
return {
  volume = 0.4,
  -- Volume du prototype PAR ÈRE (lot S0-suite, tools/sound/rafales.py) : 0,4 × marge des rafales tirées au
  -- hasard (pire écart à la vanilla <= -0,5 dB) ; les fichiers OGG ne changent pas.
  volumes = { [1] = 0.388, [2] = 0.3904, [3] = 0.3832, [4] = 0.3816, [5] = 0.4 },
  eres = {
    [1] = { -- I Industrielle, âges 1, 2, 3
      "__factorio-overhaul__/sound/levels/gun/tir-ere1-1.ogg",
      "__factorio-overhaul__/sound/levels/gun/tir-ere1-2.ogg",
      "__factorio-overhaul__/sound/levels/gun/tir-ere1-3.ogg",
      "__factorio-overhaul__/sound/levels/gun/tir-ere1-4.ogg",
    },
    [2] = { -- II Lourde, âges 4, 5, 6
      "__factorio-overhaul__/sound/levels/gun/tir-ere2-1.ogg",
      "__factorio-overhaul__/sound/levels/gun/tir-ere2-2.ogg",
      "__factorio-overhaul__/sound/levels/gun/tir-ere2-3.ogg",
      "__factorio-overhaul__/sound/levels/gun/tir-ere2-4.ogg",
    },
    [3] = { -- III Exotique, âges 7, 8, 9
      "__factorio-overhaul__/sound/levels/gun/tir-ere3-1.ogg",
      "__factorio-overhaul__/sound/levels/gun/tir-ere3-2.ogg",
      "__factorio-overhaul__/sound/levels/gun/tir-ere3-3.ogg",
      "__factorio-overhaul__/sound/levels/gun/tir-ere3-4.ogg",
    },
    [4] = { -- IV Haute techno, âges 10, 11, 12
      "__factorio-overhaul__/sound/levels/gun/tir-ere4-1.ogg",
      "__factorio-overhaul__/sound/levels/gun/tir-ere4-2.ogg",
      "__factorio-overhaul__/sound/levels/gun/tir-ere4-3.ogg",
      "__factorio-overhaul__/sound/levels/gun/tir-ere4-4.ogg",
    },
    [5] = { -- V Stellaire, cosmique, âges 13, 14, 15
      "__factorio-overhaul__/sound/levels/gun/tir-ere5-1.ogg",
      "__factorio-overhaul__/sound/levels/gun/tir-ere5-2.ogg",
      "__factorio-overhaul__/sound/levels/gun/tir-ere5-3.ogg",
      "__factorio-overhaul__/sound/levels/gun/tir-ere5-4.ogg",
    },
  },
}
