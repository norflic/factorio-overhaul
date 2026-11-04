-- FICHIER GÉNÉRÉ par tools/render/pieces/chimie/feuilles.py (lot DA-CHIMIE) : ne pas modifier à la main.
-- machines[nom][n|e|s|w][main|shadow|glow|light] = { hr, lr } ; tailles en pixels, shift et boîtes en tuiles ;
-- hr = 64 px par tuile (scale 0,5), normale (lr) = 32. Images hors de git (D-6) : MANIFEST.json, « commande ».
return {
  machines = {
    colonne = {
      boite = { { -1.625, -4.6562 }, { 5.8125, 1.5625 } },
      e = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-colonne_e-glow.png",
            height = 298,
            shift = { -0.046875, -1.109375 },
            width = 162
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/colonne_e-glow.png",
            height = 149,
            shift = { -0.046875, -1.109375 },
            width = 81
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-colonne_e-main.png",
            height = 374,
            shift = { 0.0625, -1.546875 },
            width = 200
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/colonne_e-main.png",
            height = 187,
            shift = { 0.0625, -1.546875 },
            width = 100
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-colonne_e-shadow.png",
            height = 186,
            shift = { 2.171875, -0.015625 },
            width = 458
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/colonne_e-shadow.png",
            height = 93,
            shift = { 2.171875, -0.015625 },
            width = 229
          }
        }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/machines/chimie/colonne-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      map_color = { 0.313, 0.266, 0.238 },
      n = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-colonne_n-glow.png",
            height = 322,
            shift = { -0.015625, -1.171875 },
            width = 114
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/colonne_n-glow.png",
            height = 161,
            shift = { -0.015625, -1.171875 },
            width = 57
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-colonne_n-main.png",
            height = 392,
            shift = { -0.03125, -1.59375 },
            width = 196
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/colonne_n-main.png",
            height = 196,
            shift = { -0.03125, -1.59375 },
            width = 98
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-colonne_n-shadow.png",
            height = 190,
            shift = { 2.171875, -0.046875 },
            width = 466
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/colonne_n-shadow.png",
            height = 95,
            shift = { 2.171875, -0.046875 },
            width = 233
          }
        }
      },
      s = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-colonne_s-glow.png",
            height = 278,
            shift = { -0.015625, -1.015625 },
            width = 158
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/colonne_s-glow.png",
            height = 139,
            shift = { -0.015625, -1.015625 },
            width = 79
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-colonne_s-main.png",
            height = 360,
            shift = { 0.03125, -1.25 },
            width = 196
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/colonne_s-main.png",
            height = 180,
            shift = { 0.03125, -1.25 },
            width = 98
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-colonne_s-shadow.png",
            height = 190,
            shift = { 2.109375, 0.046875 },
            width = 434
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/colonne_s-shadow.png",
            height = 95,
            shift = { 2.109375, 0.046875 },
            width = 217
          }
        }
      },
      w = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-colonne_w-glow.png",
            height = 292,
            shift = { 0.203125, -1.15625 },
            width = 142
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/colonne_w-glow.png",
            height = 146,
            shift = { 0.203125, -1.15625 },
            width = 71
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-colonne_w-main.png",
            height = 394,
            shift = { -0.0625, -1.546875 },
            width = 200
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/colonne_w-main.png",
            height = 197,
            shift = { -0.0625, -1.546875 },
            width = 100
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-colonne_w-shadow.png",
            height = 186,
            shift = { 1.875, 0.015625 },
            width = 432
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/colonne_w-shadow.png",
            height = 93,
            shift = { 1.875, 0.015625 },
            width = 216
          }
        }
      }
    },
    craqueur = {
      boite = { { -1.625, -4.4375 }, { 5.5312, 1.5625 } },
      e = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_e-glow.png",
            height = 154,
            shift = { -0.0625, -0.390625 },
            width = 140
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_e-glow.png",
            height = 77,
            shift = { -0.0625, -0.390625 },
            width = 70
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_e-light.png",
            height = 82,
            shift = { 0.4375, 1.359375 },
            width = 268
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_e-light.png",
            height = 41,
            shift = { 0.4375, 1.359375 },
            width = 134
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_e-main.png",
            height = 374,
            shift = { 0.0, -1.484375 },
            width = 208
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_e-main.png",
            height = 187,
            shift = { 0.0, -1.484375 },
            width = 104
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_e-shadow.png",
            height = 182,
            shift = { 2.015625, -0.015625 },
            width = 450
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_e-shadow.png",
            height = 91,
            shift = { 2.015625, -0.015625 },
            width = 225
          }
        }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      map_color = { 0.324, 0.263, 0.215 },
      n = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_n-glow.png",
            height = 204,
            shift = { -0.125, -0.75 },
            width = 148
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_n-glow.png",
            height = 102,
            shift = { -0.125, -0.75 },
            width = 74
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_n-light.png",
            height = 110,
            shift = { 0.03125, 0.890625 },
            width = 264
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_n-light.png",
            height = 55,
            shift = { 0.03125, 0.890625 },
            width = 132
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_n-main.png",
            height = 384,
            shift = { 0.046875, -1.4375 },
            width = 198
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_n-main.png",
            height = 192,
            shift = { 0.046875, -1.4375 },
            width = 99
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_n-shadow.png",
            height = 196,
            shift = { 1.53125, 0.0 },
            width = 376
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_n-shadow.png",
            height = 98,
            shift = { 1.53125, 0.0 },
            width = 188
          }
        }
      },
      s = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_s-glow.png",
            height = 180,
            shift = { 0.0, -0.375 },
            width = 164
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_s-glow.png",
            height = 90,
            shift = { 0.0, -0.375 },
            width = 82
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_s-light.png",
            height = 78,
            shift = { 0.203125, 1.546875 },
            width = 274
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_s-light.png",
            height = 39,
            shift = { 0.203125, 1.546875 },
            width = 137
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_s-main.png",
            height = 314,
            shift = { -0.046875, -0.890625 },
            width = 198
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_s-main.png",
            height = 157,
            shift = { -0.046875, -0.890625 },
            width = 99
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_s-shadow.png",
            height = 196,
            shift = { 1.984375, 0.0 },
            width = 446
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_s-shadow.png",
            height = 98,
            shift = { 1.984375, 0.0 },
            width = 223
          }
        }
      },
      w = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_w-glow.png",
            height = 240,
            shift = { 0.0, -0.65625 },
            width = 132
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_w-glow.png",
            height = 120,
            shift = { 0.0, -0.65625 },
            width = 66
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_w-light.png",
            height = 68,
            shift = { -0.21875, 1.59375 },
            width = 244
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_w-light.png",
            height = 34,
            shift = { -0.21875, 1.59375 },
            width = 122
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_w-main.png",
            height = 318,
            shift = { 0.0, -0.921875 },
            width = 208
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_w-main.png",
            height = 159,
            shift = { 0.0, -0.921875 },
            width = 104
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-craqueur_w-shadow.png",
            height = 188,
            shift = { 1.46875, 0.0625 },
            width = 380
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/craqueur_w-shadow.png",
            height = 94,
            shift = { 1.46875, 0.0625 },
            width = 190
          }
        }
      }
    },
    electrolyseur = {
      boite = { { -1.625, -2.7188 }, { 3.1875, 1.5625 } },
      e = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-electrolyseur_e-glow.png",
            height = 190,
            shift = { -0.03125, -0.734375 },
            width = 164
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/electrolyseur_e-glow.png",
            height = 95,
            shift = { -0.03125, -0.734375 },
            width = 82
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-electrolyseur_e-main.png",
            height = 268,
            shift = { 0.0, -0.625 },
            width = 208
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/electrolyseur_e-main.png",
            height = 134,
            shift = { 0.0, -0.625 },
            width = 104
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-electrolyseur_e-shadow.png",
            height = 184,
            shift = { 0.75, 0.0625 },
            width = 288
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/electrolyseur_e-shadow.png",
            height = 92,
            shift = { 0.75, 0.0625 },
            width = 144
          }
        }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/machines/chimie/electrolyseur-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      map_color = { 0.299, 0.275, 0.254 },
      n = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-electrolyseur_n-glow.png",
            height = 150,
            shift = { 0.0, -0.484375 },
            width = 180
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/electrolyseur_n-glow.png",
            height = 75,
            shift = { 0.0, -0.484375 },
            width = 90
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-electrolyseur_n-main.png",
            height = 266,
            shift = { 0.015625, -0.515625 },
            width = 190
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/electrolyseur_n-main.png",
            height = 133,
            shift = { 0.015625, -0.515625 },
            width = 95
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-electrolyseur_n-shadow.png",
            height = 196,
            shift = { 0.90625, 0.0 },
            width = 292
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/electrolyseur_n-shadow.png",
            height = 98,
            shift = { 0.90625, 0.0 },
            width = 146
          }
        }
      },
      s = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-electrolyseur_s-glow.png",
            height = 162,
            shift = { -0.015625, -0.859375 },
            width = 166
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/electrolyseur_s-glow.png",
            height = 81,
            shift = { -0.015625, -0.859375 },
            width = 83
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-electrolyseur_s-main.png",
            height = 274,
            shift = { -0.015625, -0.578125 },
            width = 190
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/electrolyseur_s-main.png",
            height = 137,
            shift = { -0.015625, -0.578125 },
            width = 95
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-electrolyseur_s-shadow.png",
            height = 196,
            shift = { 0.890625, 0.0 },
            width = 294
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/electrolyseur_s-shadow.png",
            height = 98,
            shift = { 0.890625, 0.0 },
            width = 147
          }
        }
      },
      w = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-electrolyseur_w-glow.png",
            height = 190,
            shift = { 0.03125, -0.703125 },
            width = 164
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/electrolyseur_w-glow.png",
            height = 95,
            shift = { 0.03125, -0.703125 },
            width = 82
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-electrolyseur_w-main.png",
            height = 266,
            shift = { 0.0, -0.640625 },
            width = 208
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/electrolyseur_w-main.png",
            height = 133,
            shift = { 0.0, -0.640625 },
            width = 104
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-electrolyseur_w-shadow.png",
            height = 182,
            shift = { 0.8125, -0.015625 },
            width = 296
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/electrolyseur_w-shadow.png",
            height = 91,
            shift = { 0.8125, -0.015625 },
            width = 148
          }
        }
      }
    },
    reformeur = {
      boite = { { -1.625, -3.5312 }, { 4.1562, 1.5625 } },
      e = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-reformeur_e-glow.png",
            height = 194,
            shift = { 0.015625, -0.828125 },
            width = 158
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/reformeur_e-glow.png",
            height = 97,
            shift = { 0.015625, -0.828125 },
            width = 79
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-reformeur_e-main.png",
            height = 306,
            shift = { 0.0, -0.890625 },
            width = 208
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/reformeur_e-main.png",
            height = 153,
            shift = { 0.0, -0.890625 },
            width = 104
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-reformeur_e-shadow.png",
            height = 188,
            shift = { 1.25, -0.03125 },
            width = 352
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/reformeur_e-shadow.png",
            height = 94,
            shift = { 1.25, -0.03125 },
            width = 176
          }
        }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/machines/chimie/reformeur-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      map_color = { 0.297, 0.261, 0.223 },
      n = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-reformeur_n-glow.png",
            height = 210,
            shift = { -0.109375, -0.703125 },
            width = 162
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/reformeur_n-glow.png",
            height = 105,
            shift = { -0.109375, -0.703125 },
            width = 81
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-reformeur_n-main.png",
            height = 316,
            shift = { -0.015625, -0.90625 },
            width = 202
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/reformeur_n-main.png",
            height = 158,
            shift = { -0.015625, -0.90625 },
            width = 101
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-reformeur_n-shadow.png",
            height = 196,
            shift = { 1.34375, 0.0 },
            width = 360
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/reformeur_n-shadow.png",
            height = 98,
            shift = { 1.34375, 0.0 },
            width = 180
          }
        }
      },
      s = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-reformeur_s-glow.png",
            height = 140,
            shift = { 0.1875, -0.25 },
            width = 140
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/reformeur_s-glow.png",
            height = 70,
            shift = { 0.1875, -0.25 },
            width = 70
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-reformeur_s-main.png",
            height = 244,
            shift = { 0.015625, -0.34375 },
            width = 202
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/reformeur_s-main.png",
            height = 122,
            shift = { 0.015625, -0.34375 },
            width = 101
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-reformeur_s-shadow.png",
            height = 196,
            shift = { 1.171875, 0.0 },
            width = 338
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/reformeur_s-shadow.png",
            height = 98,
            shift = { 1.171875, 0.0 },
            width = 169
          }
        }
      },
      w = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-reformeur_w-glow.png",
            height = 196,
            shift = { 0.0, -0.46875 },
            width = 160
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/reformeur_w-glow.png",
            height = 98,
            shift = { 0.0, -0.46875 },
            width = 80
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-reformeur_w-main.png",
            height = 324,
            shift = { 0.0, -1.0 },
            width = 208
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/reformeur_w-main.png",
            height = 162,
            shift = { 0.0, -1.0 },
            width = 104
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/hr-reformeur_w-shadow.png",
            height = 188,
            shift = { 0.578125, 0.03125 },
            width = 266
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/machines/chimie/reformeur_w-shadow.png",
            height = 94,
            shift = { 0.578125, 0.03125 },
            width = 133
          }
        }
      }
    }
  }
}
