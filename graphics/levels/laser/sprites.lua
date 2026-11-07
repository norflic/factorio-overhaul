-- FICHIER GÉNÉRÉ par tools/render/pieces/levels/laser_e/feuilles.py (lot F1-C) : ne pas modifier à la main.
-- Tailles en pixels, shift en tuiles. hr = 64 px/tuile (scale 0,5), normale = 32 px/tuile.
-- Têtes (RotatedAnimation) : direction_count 64 ou 32 selon l'âge, feuille rangée par rangée (line_length 8),
-- image k = pose d(k × 64 / N), rotation uniforme depuis le nord, sens horaire, apply_projection vrai (F121).
-- tir : source_offset (tourné avec la tête) et hauteur du faisceau, mesurés sur la géométrie (bouches.py).
-- Images : MANIFEST.json (hors de git, D-6) ; régénérer : voir MANIFEST.json, « commande ».
return {
  ages = {
    [1] = {
      piece = {
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e01-piece-light.png",
            height = 190,
            shift = { -0.46875, 0.359375 },
            width = 176
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e01-piece-light.png",
            height = 95,
            shift = { -0.46875, 0.359375 },
            width = 88
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e01-piece-main.png",
            height = 190,
            shift = { 0.015625, -0.140625 },
            width = 178
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e01-piece-main.png",
            height = 95,
            shift = { 0.015625, -0.140625 },
            width = 89
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e01-piece-shadow.png",
            height = 142,
            shift = { 0.3125, 0.109375 },
            width = 188
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e01-piece-shadow.png",
            height = 71,
            shift = { 0.3125, 0.109375 },
            width = 94
          }
        }
      }
    },
    [2] = {
      boite = { { -1.1875, -1.84375 }, { 1.1875, 1.09375 } },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/laser/laser-e02-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e02-piece-glow.png",
            height = 16,
            shift = { 0, 0.5625 },
            width = 124
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e02-piece-glow.png",
            height = 8,
            shift = { 0, 0.5625 },
            width = 62
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e02-piece-light.png",
            height = 222,
            shift = { 0, 0.296875 },
            width = 260
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e02-piece-light.png",
            height = 111,
            shift = { 0, 0.296875 },
            width = 130
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e02-piece-main.png",
            height = 42,
            shift = { 0, 0.703125 },
            width = 152
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e02-piece-main.png",
            height = 21,
            shift = { 0, 0.703125 },
            width = 76
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e02-piece-shadow.png",
            height = 36,
            shift = { 0.078125, 0.6875 },
            width = 150
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e02-piece-shadow.png",
            height = 18,
            shift = { 0.078125, 0.6875 },
            width = 75
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e02-socle-glow.png",
            height = 136,
            shift = { 0, -0.15625 },
            width = 104
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e02-socle-glow.png",
            height = 68,
            shift = { 0, -0.15625 },
            width = 52
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e02-socle-light.png",
            height = 192,
            shift = { 0.359375, 0.0625 },
            width = 158
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e02-socle-light.png",
            height = 96,
            shift = { 0.359375, 0.0625 },
            width = 79
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e02-socle-main.png",
            height = 150,
            shift = { 0, -0.078125 },
            width = 152
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e02-socle-main.png",
            height = 75,
            shift = { 0, -0.078125 },
            width = 76
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e02-socle-shadow.png",
            height = 118,
            shift = { 0.25, 0.015625 },
            width = 148
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e02-socle-shadow.png",
            height = 59,
            shift = { 0.25, 0.015625 },
            width = 74
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e02-tete-glow.png",
            height = 88,
            line_length = 8,
            shift = { 0.015625, -0.78125 },
            width = 90
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e02-tete-glow.png",
            height = 44,
            line_length = 8,
            shift = { 0.015625, -0.78125 },
            width = 45
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e02-tete-main.png",
            height = 116,
            line_length = 8,
            shift = { 0, -0.9375 },
            width = 96
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e02-tete-main.png",
            height = 58,
            line_length = 8,
            shift = { 0, -0.9375 },
            width = 48
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e02-tete-shadow.png",
            height = 68,
            line_length = 8,
            shift = { 1.203125, 0 },
            width = 154
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e02-tete-shadow.png",
            height = 34,
            line_length = 8,
            shift = { 1.203125, 0 },
            width = 77
          }
        }
      },
      tir = {
        hauteur = 0.9475,
        source_offset = { 0, -0.354 }
      }
    },
    [3] = {
      boite = { { -1.21875, -1.53125 }, { 1.21875, 1.09375 } },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/laser/laser-e03-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e03-piece-glow.png",
            height = 10,
            shift = { 0, 0.640625 },
            width = 112
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e03-piece-glow.png",
            height = 5,
            shift = { 0, 0.640625 },
            width = 56
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e03-piece-main.png",
            height = 52,
            shift = { 0, 0.65625 },
            width = 156
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e03-piece-main.png",
            height = 26,
            shift = { 0, 0.65625 },
            width = 78
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e03-piece-shadow.png",
            height = 36,
            shift = { 0.140625, 0.6875 },
            width = 158
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e03-piece-shadow.png",
            height = 18,
            shift = { 0.140625, 0.6875 },
            width = 79
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e03-socle-glow.png",
            height = 120,
            shift = { 0, -0.0625 },
            width = 124
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e03-socle-glow.png",
            height = 60,
            shift = { 0, -0.0625 },
            width = 62
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e03-socle-light.png",
            height = 174,
            shift = { 0, 0.421875 },
            width = 244
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e03-socle-light.png",
            height = 87,
            shift = { 0, 0.421875 },
            width = 122
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e03-socle-main.png",
            height = 142,
            shift = { -0.015625, -0.015625 },
            width = 154
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e03-socle-main.png",
            height = 71,
            shift = { -0.015625, -0.015625 },
            width = 77
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e03-socle-shadow.png",
            height = 128,
            shift = { 0.046875, 0 },
            width = 150
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e03-socle-shadow.png",
            height = 64,
            shift = { 0.046875, 0 },
            width = 75
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e03-tete-glow.png",
            height = 78,
            line_length = 8,
            shift = { 0, -0.734375 },
            width = 84
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e03-tete-glow.png",
            height = 39,
            line_length = 8,
            shift = { 0, -0.734375 },
            width = 42
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e03-tete-main.png",
            height = 96,
            line_length = 8,
            shift = { 0, -0.78125 },
            width = 92
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e03-tete-main.png",
            height = 48,
            line_length = 8,
            shift = { 0, -0.78125 },
            width = 46
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e03-tete-shadow.png",
            height = 64,
            line_length = 8,
            shift = { 1, 0 },
            width = 128
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e03-tete-shadow.png",
            height = 32,
            line_length = 8,
            shift = { 1, 0 },
            width = 64
          }
        }
      },
      tir = {
        hauteur = 0.9475,
        source_offset = { 0, -0.3621 }
      }
    },
    [4] = {
      boite = { { -1.71875, -2.0625 }, { 1.71875, 1.5625 } },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/laser/laser-e04-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e04-piece-main.png",
            height = 58,
            shift = { 0, 1.109375 },
            width = 220
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e04-piece-main.png",
            height = 29,
            shift = { 0, 1.109375 },
            width = 110
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e04-piece-shadow.png",
            height = 52,
            shift = { 0.09375, 1.09375 },
            width = 220
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e04-piece-shadow.png",
            height = 26,
            shift = { 0.09375, 1.09375 },
            width = 110
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e04-socle-glow.png",
            height = 184,
            shift = { -0.0625, -0.09375 },
            width = 176
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e04-socle-glow.png",
            height = 92,
            shift = { -0.0625, -0.09375 },
            width = 88
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e04-socle-light.png",
            height = 218,
            shift = { 0, 0.421875 },
            width = 260
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e04-socle-light.png",
            height = 109,
            shift = { 0, 0.421875 },
            width = 130
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e04-socle-main.png",
            height = 218,
            shift = { 0.015625, -0.171875 },
            width = 218
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e04-socle-main.png",
            height = 109,
            shift = { 0.015625, -0.171875 },
            width = 109
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e04-socle-shadow.png",
            height = 186,
            shift = { 0.28125, 0.015625 },
            width = 224
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e04-socle-shadow.png",
            height = 93,
            shift = { 0.28125, 0.015625 },
            width = 112
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e04-tete-glow.png",
            height = 104,
            line_length = 8,
            shift = { 0, -0.875 },
            width = 120
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e04-tete-glow.png",
            height = 52,
            line_length = 8,
            shift = { 0, -0.875 },
            width = 60
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e04-tete-main.png",
            height = 134,
            line_length = 8,
            shift = { 0, -1.015625 },
            width = 124
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e04-tete-main.png",
            height = 67,
            line_length = 8,
            shift = { 0, -1.015625 },
            width = 62
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e04-tete-shadow.png",
            height = 88,
            line_length = 8,
            shift = { 1.296875, 0 },
            width = 182
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e04-tete-shadow.png",
            height = 44,
            line_length = 8,
            shift = { 1.296875, 0 },
            width = 91
          }
        }
      },
      tir = {
        hauteur = 1.2516,
        source_offset = { 0, -0.525 }
      }
    },
    [5] = {
      boite = { { -1.75, -1.96875 }, { 1.71875, 1.59375 } },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/laser/laser-e05-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e05-piece-glow.png",
            height = 20,
            shift = { 0, 0.90625 },
            width = 180
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e05-piece-glow.png",
            height = 10,
            shift = { 0, 0.90625 },
            width = 90
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e05-piece-light.png",
            height = 260,
            shift = { 0, 0.625 },
            width = 340
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e05-piece-light.png",
            height = 130,
            shift = { 0, 0.625 },
            width = 170
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e05-piece-main.png",
            height = 54,
            shift = { 0, 1.078125 },
            width = 212
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e05-piece-main.png",
            height = 27,
            shift = { 0, 1.078125 },
            width = 106
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e05-piece-shadow.png",
            height = 52,
            shift = { 0.09375, 1.09375 },
            width = 220
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e05-piece-shadow.png",
            height = 26,
            shift = { 0.09375, 1.09375 },
            width = 110
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e05-socle-glow.png",
            height = 204,
            shift = { -0.046875, -0.15625 },
            width = 186
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e05-socle-glow.png",
            height = 102,
            shift = { -0.046875, -0.15625 },
            width = 93
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e05-socle-light.png",
            height = 226,
            shift = { 0.03125, 0.421875 },
            width = 276
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e05-socle-light.png",
            height = 113,
            shift = { 0.03125, 0.421875 },
            width = 138
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e05-socle-main.png",
            height = 214,
            shift = { -0.015625, -0.078125 },
            width = 222
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e05-socle-main.png",
            height = 107,
            shift = { -0.015625, -0.078125 },
            width = 111
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e05-socle-shadow.png",
            height = 190,
            shift = { 0.171875, 0.015625 },
            width = 222
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e05-socle-shadow.png",
            height = 95,
            shift = { 0.171875, 0.015625 },
            width = 111
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e05-tete-glow.png",
            height = 118,
            line_length = 8,
            shift = { 0, -0.984375 },
            width = 120
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e05-tete-glow.png",
            height = 59,
            line_length = 8,
            shift = { 0, -0.984375 },
            width = 60
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e05-tete-main.png",
            height = 128,
            line_length = 8,
            shift = { 0, -0.96875 },
            width = 124
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e05-tete-main.png",
            height = 64,
            line_length = 8,
            shift = { 0, -0.96875 },
            width = 62
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e05-tete-shadow.png",
            height = 88,
            line_length = 8,
            shift = { 1.21875, 0 },
            width = 172
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e05-tete-shadow.png",
            height = 44,
            line_length = 8,
            shift = { 1.21875, 0 },
            width = 86
          }
        }
      },
      tir = {
        hauteur = 1.2516,
        source_offset = { 0, -0.602 }
      }
    },
    [6] = {
      boite = { { -1.8125, -2.125 }, { 1.8125, 1.5625 } },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/laser/laser-e06-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e06-piece-glow.png",
            height = 34,
            shift = { 0.015625, 1.078125 },
            width = 170
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e06-piece-glow.png",
            height = 17,
            shift = { 0.015625, 1.078125 },
            width = 85
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e06-piece-main.png",
            height = 54,
            shift = { 0, 1.078125 },
            width = 212
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e06-piece-main.png",
            height = 27,
            shift = { 0, 1.078125 },
            width = 106
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e06-piece-shadow.png",
            height = 52,
            shift = { 0.109375, 1.09375 },
            width = 222
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e06-piece-shadow.png",
            height = 26,
            shift = { 0.109375, 1.09375 },
            width = 111
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e06-socle-glow.png",
            height = 194,
            shift = { 0, -0.203125 },
            width = 200
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e06-socle-glow.png",
            height = 97,
            shift = { 0, -0.203125 },
            width = 100
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e06-socle-light.png",
            height = 210,
            shift = { 0, 0.515625 },
            width = 276
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e06-socle-light.png",
            height = 105,
            shift = { 0, 0.515625 },
            width = 138
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e06-socle-main.png",
            height = 210,
            shift = { 0, -0.078125 },
            width = 232
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e06-socle-main.png",
            height = 105,
            shift = { 0, -0.078125 },
            width = 116
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e06-socle-shadow.png",
            height = 186,
            shift = { 0.0625, -0.046875 },
            width = 236
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e06-socle-shadow.png",
            height = 93,
            shift = { 0.0625, -0.046875 },
            width = 118
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e06-tete-glow.png",
            height = 130,
            line_length = 8,
            shift = { 0, -1.078125 },
            width = 120
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e06-tete-glow.png",
            height = 65,
            line_length = 8,
            shift = { 0, -1.078125 },
            width = 60
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e06-tete-main.png",
            height = 138,
            line_length = 8,
            shift = { 0, -1.046875 },
            width = 124
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e06-tete-main.png",
            height = 69,
            line_length = 8,
            shift = { 0, -1.046875 },
            width = 62
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e06-tete-shadow.png",
            height = 88,
            line_length = 8,
            shift = { 1.328125, 0 },
            width = 186
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e06-tete-shadow.png",
            height = 44,
            line_length = 8,
            shift = { 1.328125, 0 },
            width = 93
          }
        }
      },
      tir = {
        hauteur = 1.2516,
        source_offset = { 0, -0.758 }
      }
    },
    [7] = {
      boite = { { -2.21875, -2.59375 }, { 2.21875, 2.0625 } },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/laser/laser-e07-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e07-piece-glow.png",
            height = 28,
            shift = { 0.046875, 1.53125 },
            width = 226
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e07-piece-glow.png",
            height = 14,
            shift = { 0.046875, 1.53125 },
            width = 113
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e07-piece-light.png",
            height = 130,
            shift = { 0, 1.703125 },
            width = 324
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e07-piece-light.png",
            height = 65,
            shift = { 0, 1.703125 },
            width = 162
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e07-piece-main.png",
            height = 70,
            shift = { 0, 1.484375 },
            width = 284
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e07-piece-main.png",
            height = 35,
            shift = { 0, 1.484375 },
            width = 142
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e07-piece-shadow.png",
            height = 64,
            shift = { 0.03125, 1.46875 },
            width = 280
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e07-piece-shadow.png",
            height = 32,
            shift = { 0.03125, 1.46875 },
            width = 140
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e07-socle-glow.png",
            height = 246,
            shift = { -0.015625, -0.140625 },
            width = 234
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e07-socle-glow.png",
            height = 123,
            shift = { -0.015625, -0.140625 },
            width = 117
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e07-socle-light.png",
            height = 314,
            shift = { 0, 0.234375 },
            width = 336
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e07-socle-light.png",
            height = 157,
            shift = { 0, 0.234375 },
            width = 168
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e07-socle-main.png",
            height = 264,
            shift = { 0, 0 },
            width = 272
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e07-socle-main.png",
            height = 132,
            shift = { 0, 0 },
            width = 136
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e07-socle-shadow.png",
            height = 244,
            shift = { 0.125, 0.03125 },
            width = 268
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e07-socle-shadow.png",
            height = 122,
            shift = { 0.125, 0.03125 },
            width = 134
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e07-tete-glow.png",
            height = 162,
            line_length = 8,
            shift = { 0, -1.265625 },
            width = 156
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e07-tete-glow.png",
            height = 81,
            line_length = 8,
            shift = { 0, -1.265625 },
            width = 78
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e07-tete-main.png",
            height = 172,
            line_length = 8,
            shift = { -0.015625, -1.25 },
            width = 162
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e07-tete-main.png",
            height = 86,
            line_length = 8,
            shift = { -0.015625, -1.25 },
            width = 81
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e07-tete-shadow.png",
            height = 116,
            line_length = 8,
            shift = { 1.59375, 0 },
            width = 232
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e07-tete-shadow.png",
            height = 58,
            line_length = 8,
            shift = { 1.59375, 0 },
            width = 116
          }
        }
      },
      tir = {
        hauteur = 1.5556,
        source_offset = { 0, -0.85 }
      }
    },
    [8] = {
      boite = { { -2.21875, -2.75 }, { 2.21875, 2.09375 } },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/laser/laser-e08-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e08-piece-light.png",
            height = 132,
            shift = { 0, 1.6875 },
            width = 324
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e08-piece-light.png",
            height = 66,
            shift = { 0, 1.6875 },
            width = 162
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e08-piece-main.png",
            height = 68,
            shift = { 0, 1.46875 },
            width = 284
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e08-piece-main.png",
            height = 34,
            shift = { 0, 1.46875 },
            width = 142
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e08-piece-shadow.png",
            height = 64,
            shift = { 0.0625, 1.46875 },
            width = 284
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e08-piece-shadow.png",
            height = 32,
            shift = { 0.0625, 1.46875 },
            width = 142
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e08-socle-glow.png",
            height = 226,
            shift = { -0.015625, -0.421875 },
            width = 238
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e08-socle-glow.png",
            height = 113,
            shift = { -0.015625, -0.421875 },
            width = 119
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e08-socle-light.png",
            height = 298,
            shift = { 0, 0.265625 },
            width = 344
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e08-socle-light.png",
            height = 149,
            shift = { 0, 0.265625 },
            width = 172
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e08-socle-main.png",
            height = 282,
            shift = { 0, -0.109375 },
            width = 280
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e08-socle-main.png",
            height = 141,
            shift = { 0, -0.109375 },
            width = 140
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e08-socle-shadow.png",
            height = 248,
            shift = { 0.25, 0 },
            width = 296
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e08-socle-shadow.png",
            height = 124,
            shift = { 0.25, 0 },
            width = 148
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e08-tete-glow.png",
            height = 170,
            line_length = 8,
            shift = { 0, -1.328125 },
            width = 152
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e08-tete-glow.png",
            height = 85,
            line_length = 8,
            shift = { 0, -1.328125 },
            width = 76
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e08-tete-main.png",
            height = 182,
            line_length = 8,
            shift = { 0, -1.328125 },
            width = 164
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e08-tete-main.png",
            height = 91,
            line_length = 8,
            shift = { 0, -1.328125 },
            width = 82
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e08-tete-shadow.png",
            height = 116,
            line_length = 8,
            shift = { 1.6875, 0 },
            width = 244
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e08-tete-shadow.png",
            height = 58,
            line_length = 8,
            shift = { 1.6875, 0 },
            width = 122
          }
        }
      },
      tir = {
        hauteur = 1.5556,
        source_offset = { 0, -0.965 }
      }
    },
    [9] = {
      boite = { { -2.375, -2.78125 }, { 2.375, 2.0625 } },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/laser/laser-e09-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e09-piece-glow.png",
            height = 34,
            shift = { -0.015625, 1.734375 },
            width = 222
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e09-piece-glow.png",
            height = 17,
            shift = { -0.015625, 1.734375 },
            width = 111
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e09-piece-light.png",
            height = 132,
            shift = { 0, 1.71875 },
            width = 328
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e09-piece-light.png",
            height = 66,
            shift = { 0, 1.71875 },
            width = 164
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e09-piece-main.png",
            height = 76,
            shift = { 0, 1.46875 },
            width = 296
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e09-piece-main.png",
            height = 38,
            shift = { 0, 1.46875 },
            width = 148
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e09-piece-shadow.png",
            height = 74,
            shift = { 0.125, 1.484375 },
            width = 308
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e09-piece-shadow.png",
            height = 37,
            shift = { 0.125, 1.484375 },
            width = 154
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e09-socle-glow.png",
            height = 238,
            shift = { 0.09375, -0.171875 },
            width = 260
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e09-socle-glow.png",
            height = 119,
            shift = { 0.09375, -0.171875 },
            width = 130
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e09-socle-light.png",
            height = 206,
            shift = { 0, 1.234375 },
            width = 368
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e09-socle-light.png",
            height = 103,
            shift = { 0, 1.234375 },
            width = 184
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e09-socle-main.png",
            height = 308,
            shift = { 0, -0.375 },
            width = 304
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e09-socle-main.png",
            height = 154,
            shift = { 0, -0.375 },
            width = 152
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e09-socle-shadow.png",
            height = 256,
            shift = { 0.4375, -0.09375 },
            width = 340
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e09-socle-shadow.png",
            height = 128,
            shift = { 0.4375, -0.09375 },
            width = 170
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e09-tete-glow.png",
            height = 172,
            line_length = 8,
            shift = { 0, -1.34375 },
            width = 160
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e09-tete-glow.png",
            height = 86,
            line_length = 8,
            shift = { 0, -1.34375 },
            width = 80
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e09-tete-main.png",
            height = 182,
            line_length = 8,
            shift = { 0, -1.328125 },
            width = 164
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e09-tete-main.png",
            height = 91,
            line_length = 8,
            shift = { 0, -1.328125 },
            width = 82
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e09-tete-shadow.png",
            height = 116,
            line_length = 8,
            shift = { 1.6875, 0 },
            width = 244
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e09-tete-shadow.png",
            height = 58,
            line_length = 8,
            shift = { 1.6875, 0 },
            width = 122
          }
        }
      },
      tir = {
        hauteur = 1.5556,
        source_offset = { 0, -0.89 }
      }
    },
    [10] = {
      boite = { { -2.71875, -3.125 }, { 2.71875, 2.46875 } },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/laser/laser-e10-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e10-piece-glow.png",
            height = 26,
            shift = { -0.03125, 2.015625 },
            width = 292
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e10-piece-glow.png",
            height = 13,
            shift = { -0.03125, 2.015625 },
            width = 146
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e10-piece-light.png",
            height = 160,
            shift = { 0, 2.03125 },
            width = 384
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e10-piece-light.png",
            height = 80,
            shift = { 0, 2.03125 },
            width = 192
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e10-piece-main.png",
            height = 80,
            shift = { 0, 1.84375 },
            width = 348
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e10-piece-main.png",
            height = 40,
            shift = { 0, 1.84375 },
            width = 174
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e10-piece-shadow.png",
            height = 76,
            shift = { 0.125, 1.84375 },
            width = 360
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e10-piece-shadow.png",
            height = 38,
            shift = { 0.125, 1.84375 },
            width = 180
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e10-socle-glow.png",
            height = 278,
            shift = { 0, -0.140625 },
            width = 284
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e10-socle-glow.png",
            height = 139,
            shift = { 0, -0.140625 },
            width = 142
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e10-socle-light.png",
            height = 326,
            shift = { 0, 0.546875 },
            width = 384
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e10-socle-light.png",
            height = 163,
            shift = { 0, 0.546875 },
            width = 192
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e10-socle-main.png",
            height = 328,
            shift = { -0.015625, -0.125 },
            width = 334
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e10-socle-main.png",
            height = 164,
            shift = { -0.015625, -0.125 },
            width = 167
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e10-socle-shadow.png",
            height = 290,
            shift = { 0.359375, 0.015625 },
            width = 342
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e10-socle-shadow.png",
            height = 145,
            shift = { 0.359375, 0.015625 },
            width = 171
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e10-tete-glow.png",
            height = 200,
            line_length = 8,
            shift = { 0, -1.5 },
            width = 196
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e10-tete-glow.png",
            height = 100,
            line_length = 8,
            shift = { 0, -1.5 },
            width = 98
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e10-tete-main.png",
            height = 210,
            line_length = 8,
            shift = { 0, -1.484375 },
            width = 200
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e10-tete-main.png",
            height = 105,
            line_length = 8,
            shift = { 0, -1.484375 },
            width = 100
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e10-tete-shadow.png",
            height = 140,
            line_length = 8,
            shift = { 1.890625, 0 },
            width = 286
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e10-tete-shadow.png",
            height = 70,
            line_length = 8,
            shift = { 1.890625, 0 },
            width = 143
          }
        }
      },
      tir = {
        hauteur = 1.8597,
        source_offset = { 0, -0.7335 }
      }
    },
    [11] = {
      boite = { { -2.71875, -3.0625 }, { 2.71875, 2.46875 } },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/laser/laser-e11-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e11-piece-glow.png",
            height = 52,
            shift = { -0.28125, 1.90625 },
            width = 284
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e11-piece-glow.png",
            height = 26,
            shift = { -0.28125, 1.90625 },
            width = 142
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e11-piece-light.png",
            height = 122,
            shift = { 0, 2.234375 },
            width = 372
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e11-piece-light.png",
            height = 61,
            shift = { 0, 2.234375 },
            width = 186
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e11-piece-main.png",
            height = 80,
            shift = { 0, 1.84375 },
            width = 348
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e11-piece-main.png",
            height = 40,
            shift = { 0, 1.84375 },
            width = 174
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e11-piece-shadow.png",
            height = 78,
            shift = { 0.015625, 1.859375 },
            width = 346
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e11-piece-shadow.png",
            height = 39,
            shift = { 0.015625, 1.859375 },
            width = 173
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e11-socle-glow.png",
            height = 290,
            shift = { 0, -0.046875 },
            width = 288
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e11-socle-glow.png",
            height = 145,
            shift = { 0, -0.046875 },
            width = 144
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e11-socle-light.png",
            height = 364,
            shift = { 0, 0.25 },
            width = 384
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e11-socle-light.png",
            height = 182,
            shift = { 0, 0.25 },
            width = 192
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e11-socle-main.png",
            height = 350,
            shift = { 0, -0.328125 },
            width = 344
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e11-socle-main.png",
            height = 175,
            shift = { 0, -0.328125 },
            width = 172
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e11-socle-shadow.png",
            height = 292,
            shift = { 0.234375, 0 },
            width = 358
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e11-socle-shadow.png",
            height = 146,
            shift = { 0.234375, 0 },
            width = 179
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e11-tete-glow.png",
            height = 186,
            line_length = 8,
            shift = { 0, -1.421875 },
            width = 188
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e11-tete-glow.png",
            height = 93,
            line_length = 8,
            shift = { 0, -1.421875 },
            width = 94
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e11-tete-main.png",
            height = 202,
            line_length = 8,
            shift = { 0, -1.421875 },
            width = 200
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e11-tete-main.png",
            height = 101,
            line_length = 8,
            shift = { 0, -1.421875 },
            width = 100
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e11-tete-shadow.png",
            height = 140,
            line_length = 8,
            shift = { 1.78125, 0 },
            width = 272
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e11-tete-shadow.png",
            height = 70,
            line_length = 8,
            shift = { 1.78125, 0 },
            width = 136
          }
        }
      },
      tir = {
        hauteur = 1.8597,
        source_offset = { 0, -1.206 }
      }
    },
    [12] = {
      boite = { { -2.71875, -3.15625 }, { 2.71875, 2.5 } },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/laser/laser-e12-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e12-piece-glow.png",
            height = 42,
            shift = { 0, 2.046875 },
            width = 288
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e12-piece-glow.png",
            height = 21,
            shift = { 0, 2.046875 },
            width = 144
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e12-piece-light.png",
            height = 134,
            shift = { 0, 2.109375 },
            width = 372
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e12-piece-light.png",
            height = 67,
            shift = { 0, 2.109375 },
            width = 186
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e12-piece-main.png",
            height = 80,
            shift = { 0, 1.84375 },
            width = 348
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e12-piece-main.png",
            height = 40,
            shift = { 0, 1.84375 },
            width = 174
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e12-piece-shadow.png",
            height = 76,
            shift = { 0.109375, 1.84375 },
            width = 358
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e12-piece-shadow.png",
            height = 38,
            shift = { 0.109375, 1.84375 },
            width = 179
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e12-socle-glow.png",
            height = 326,
            shift = { -0.015625, -0.171875 },
            width = 294
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e12-socle-glow.png",
            height = 163,
            shift = { -0.015625, -0.171875 },
            width = 147
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e12-socle-light.png",
            height = 328,
            shift = { 0, 0.65625 },
            width = 392
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e12-socle-light.png",
            height = 164,
            shift = { 0, 0.65625 },
            width = 196
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e12-socle-main.png",
            height = 356,
            shift = { 0, -0.28125 },
            width = 344
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e12-socle-main.png",
            height = 178,
            shift = { 0, -0.28125 },
            width = 172
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e12-socle-shadow.png",
            height = 304,
            shift = { 0.46875, 0 },
            width = 372
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e12-socle-shadow.png",
            height = 152,
            shift = { 0.46875, 0 },
            width = 186
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e12-tete-glow.png",
            height = 200,
            line_length = 8,
            shift = { 0.015625, -1.5 },
            width = 190
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e12-tete-glow.png",
            height = 100,
            line_length = 8,
            shift = { 0.015625, -1.5 },
            width = 95
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e12-tete-main.png",
            height = 212,
            line_length = 8,
            shift = { 0, -1.5 },
            width = 200
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e12-tete-main.png",
            height = 106,
            line_length = 8,
            shift = { 0, -1.5 },
            width = 100
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e12-tete-shadow.png",
            height = 140,
            line_length = 8,
            shift = { 1.90625, 0 },
            width = 284
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e12-tete-shadow.png",
            height = 70,
            line_length = 8,
            shift = { 1.90625, 0 },
            width = 142
          }
        }
      },
      tir = {
        hauteur = 1.8597,
        source_offset = { 0, -0.756 }
      }
    },
    [13] = {
      boite = { { -3.21875, -3.65625 }, { 3.21875, 2.9375 } },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/laser/laser-e13-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e13-piece-glow.png",
            height = 44,
            shift = { -0.03125, 2.5 },
            width = 344
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e13-piece-glow.png",
            height = 22,
            shift = { -0.03125, 2.5 },
            width = 172
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e13-piece-light.png",
            height = 156,
            shift = { 0, 2.4375 },
            width = 432
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e13-piece-light.png",
            height = 78,
            shift = { 0, 2.4375 },
            width = 216
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e13-piece-main.png",
            height = 90,
            shift = { 0, 2.234375 },
            width = 412
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e13-piece-main.png",
            height = 45,
            shift = { 0, 2.234375 },
            width = 206
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e13-piece-shadow.png",
            height = 88,
            shift = { 0.125, 2.25 },
            width = 424
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e13-piece-shadow.png",
            height = 44,
            shift = { 0.125, 2.25 },
            width = 212
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e13-socle-glow.png",
            height = 330,
            shift = { 0.078125, -0.296875 },
            width = 322
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e13-socle-glow.png",
            height = 165,
            shift = { 0.078125, -0.296875 },
            width = 161
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e13-socle-light.png",
            height = 370,
            shift = { 0.015625, 0.640625 },
            width = 398
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e13-socle-light.png",
            height = 185,
            shift = { 0.015625, 0.640625 },
            width = 199
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e13-socle-main.png",
            height = 370,
            shift = { 0, -0.234375 },
            width = 408
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e13-socle-main.png",
            height = 185,
            shift = { 0, -0.234375 },
            width = 204
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e13-socle-shadow.png",
            height = 332,
            shift = { 0.40625, -0.09375 },
            width = 404
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e13-socle-shadow.png",
            height = 166,
            shift = { 0.40625, -0.09375 },
            width = 202
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e13-tete-glow.png",
            height = 238,
            line_length = 8,
            shift = { 0, -1.734375 },
            width = 228
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e13-tete-glow.png",
            height = 119,
            line_length = 8,
            shift = { 0, -1.734375 },
            width = 114
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e13-tete-main.png",
            height = 248,
            line_length = 8,
            shift = { 0, -1.71875 },
            width = 236
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e13-tete-main.png",
            height = 124,
            line_length = 8,
            shift = { 0, -1.71875 },
            width = 118
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e13-tete-shadow.png",
            height = 168,
            line_length = 8,
            shift = { 2.1875, 0 },
            width = 336
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e13-tete-shadow.png",
            height = 84,
            line_length = 8,
            shift = { 2.1875, 0 },
            width = 168
          }
        }
      },
      tir = {
        hauteur = 2.1637,
        source_offset = { 0, -0.9653 }
      }
    },
    [14] = {
      boite = { { -3.21875, -3.75 }, { 3.21875, 3 } },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/laser/laser-e14-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e14-piece-glow.png",
            height = 70,
            shift = { 0, 2.234375 },
            width = 364
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e14-piece-glow.png",
            height = 35,
            shift = { 0, 2.234375 },
            width = 182
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e14-piece-light.png",
            height = 148,
            shift = { 0, 2.5 },
            width = 428
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e14-piece-light.png",
            height = 74,
            shift = { 0, 2.5 },
            width = 214
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e14-piece-main.png",
            height = 90,
            shift = { 0, 2.234375 },
            width = 412
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e14-piece-main.png",
            height = 45,
            shift = { 0, 2.234375 },
            width = 206
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e14-piece-shadow.png",
            height = 88,
            shift = { 0.21875, 2.25 },
            width = 436
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e14-piece-shadow.png",
            height = 44,
            shift = { 0.21875, 2.25 },
            width = 218
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e14-socle-glow.png",
            height = 374,
            shift = { 0, -0.234375 },
            width = 360
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e14-socle-glow.png",
            height = 187,
            shift = { 0, -0.234375 },
            width = 180
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e14-socle-light.png",
            height = 120,
            shift = { 0, -1.875 },
            width = 432
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e14-socle-light.png",
            height = 60,
            shift = { 0, -1.875 },
            width = 216
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e14-socle-main.png",
            height = 394,
            shift = { 0, -0.078125 },
            width = 396
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e14-socle-main.png",
            height = 197,
            shift = { 0, -0.078125 },
            width = 198
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e14-socle-shadow.png",
            height = 376,
            shift = { 0.234375, 0 },
            width = 410
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e14-socle-shadow.png",
            height = 188,
            shift = { 0.234375, 0 },
            width = 205
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e14-tete-glow.png",
            height = 244,
            line_length = 8,
            shift = { 0, -1.8125 },
            width = 232
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e14-tete-glow.png",
            height = 122,
            line_length = 8,
            shift = { 0, -1.8125 },
            width = 116
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e14-tete-main.png",
            height = 254,
            line_length = 8,
            shift = { 0, -1.765625 },
            width = 236
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e14-tete-main.png",
            height = 127,
            line_length = 8,
            shift = { 0, -1.765625 },
            width = 118
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e14-tete-shadow.png",
            height = 168,
            line_length = 8,
            shift = { 2.21875, 0 },
            width = 340
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e14-tete-shadow.png",
            height = 84,
            line_length = 8,
            shift = { 2.21875, 0 },
            width = 170
          }
        }
      },
      tir = {
        hauteur = 2.1354,
        source_offset = { 0, -0.0573 }
      }
    },
    [15] = {
      boite = { { -3.375, -3.5 }, { 3.40625, 3.0625 } },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/laser/laser-e15-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e15-piece-glow.png",
            height = 84,
            shift = { 0.046875, 2.3125 },
            width = 406
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e15-piece-glow.png",
            height = 42,
            shift = { 0.046875, 2.3125 },
            width = 203
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e15-piece-light.png",
            height = 194,
            shift = { -0.015625, 2.328125 },
            width = 446
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e15-piece-light.png",
            height = 97,
            shift = { -0.015625, 2.328125 },
            width = 223
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e15-piece-main.png",
            height = 102,
            shift = { 0.015625, 2.265625 },
            width = 434
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e15-piece-main.png",
            height = 51,
            shift = { 0.015625, 2.265625 },
            width = 217
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e15-piece-shadow.png",
            height = 100,
            shift = { 0.109375, 2.28125 },
            width = 442
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e15-piece-shadow.png",
            height = 50,
            shift = { 0.109375, 2.28125 },
            width = 221
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e15-socle-glow.png",
            height = 380,
            shift = { -0.015625, -0.34375 },
            width = 410
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e15-socle-glow.png",
            height = 190,
            shift = { -0.015625, -0.34375 },
            width = 205
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e15-socle-light.png",
            height = 258,
            shift = { 0, 1.859375 },
            width = 480
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e15-socle-light.png",
            height = 129,
            shift = { 0, 1.859375 },
            width = 240
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e15-socle-main.png",
            height = 402,
            shift = { 0, -0.171875 },
            width = 428
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e15-socle-main.png",
            height = 201,
            shift = { 0, -0.171875 },
            width = 214
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-lase-e15-socle-shadow.png",
            height = 372,
            shift = { 0.09375, -0.09375 },
            width = 436
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/laser/lase-e15-socle-shadow.png",
            height = 186,
            shift = { 0.09375, -0.09375 },
            width = 218
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e15-tete-glow.png",
            height = 228,
            line_length = 8,
            shift = { 0, -1.65625 },
            width = 232
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e15-tete-glow.png",
            height = 114,
            line_length = 8,
            shift = { 0, -1.65625 },
            width = 116
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e15-tete-main.png",
            height = 238,
            line_length = 8,
            shift = { 0, -1.640625 },
            width = 236
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e15-tete-main.png",
            height = 119,
            line_length = 8,
            shift = { 0, -1.640625 },
            width = 118
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/hr-laser-e15-tete-shadow.png",
            height = 168,
            line_length = 8,
            shift = { 2.078125, 0 },
            width = 322
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/laser/laser-e15-tete-shadow.png",
            height = 84,
            line_length = 8,
            shift = { 2.078125, 0 },
            width = 161
          }
        }
      },
      tir = {
        hauteur = 2.1637,
        source_offset = { 0, -0.8575 }
      }
    }
  },
  essai = false
}
