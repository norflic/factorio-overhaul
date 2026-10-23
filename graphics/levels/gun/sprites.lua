-- FICHIER GÉNÉRÉ par tools/render/pieces/levels/gun_e/feuilles.py (lots A2 et A3-jeu) : ne pas modifier à
-- la main. Tailles en pixels, shift en tuiles. hr = 64 px/tuile (scale 0,5), normale = 32 px/tuile.
-- Têtes (RotatedAnimation), selon l'âge : direction_count 64, feuille de 8 × 8 images d00 à d63 rangée par
-- rangée (line_length 8, rotation uniforme, apply_projection vrai : F121) ; ou, en repli, direction_count 4,
-- feuille en COLONNE N, E, S, O (line_length 1, F123). Images : MANIFEST.json (hors de git, D-6) ;
-- régénérer : voir MANIFEST.json, « commande ».
return {
  ages = {
    [1] = {
      piece = {
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e01-piece-light.png",
            height = 168,
            shift = { 0.421875, 0.59375 },
            width = 190
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e01-piece-light.png",
            height = 84,
            shift = { 0.421875, 0.59375 },
            width = 95
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e01-piece-main.png",
            height = 130,
            shift = { 0.015625, 0.328125 },
            width = 178
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e01-piece-main.png",
            height = 65,
            shift = { 0.015625, 0.328125 },
            width = 89
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e01-piece-shadow.png",
            height = 122,
            shift = { 0.0625, 0.296875 },
            width = 156
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e01-piece-shadow.png",
            height = 61,
            shift = { 0.0625, 0.296875 },
            width = 78
          }
        }
      }
    },
    [2] = {
      boite = { { -1.40625, -1.65625 }, { 1.40625, 1.21875 } },
      bouches = {
        d00 = { 0, -1.59375 },
        d01 = { 0.10458, -1.59735 },
        d02 = { 0.21501, -1.58549 },
        d03 = { 0.33661, -1.56068 },
        d04 = { 0.44925, -1.52702 },
        d05 = { 0.56147, -1.48267 },
        d06 = { 0.65909, -1.4305 },
        d07 = { 0.25951, -1.4557 },
        d08 = { 0.35503, -1.42115 },
        d09 = { 0.4241, -1.39736 },
        d10 = { 0.4966, -1.35524 },
        d11 = { 1.02418, -1.05965 },
        d12 = { 1.07104, -0.98574 },
        d13 = { 1.1097, -0.91099 },
        d14 = { 1.13722, -0.82108 },
        d15 = { 1.15741, -0.72162 },
        d16 = { 0.96875, -0.94141 },
        d17 = { 1.16677, -0.50578 },
        d18 = { 1.16116, -0.42026 },
        d19 = { 1.14772, -0.33388 },
        d20 = { 1.11991, -0.25537 },
        d21 = { 1.0691, -0.16759 },
        d22 = { 1.02219, -0.09402 },
        d23 = { 0.9588, -0.01954 },
        d24 = { 0.87667, 0.0553 },
        d25 = { 0.79547, 0.11658 },
        d26 = { 0.69847, 0.17393 },
        d27 = { 0.60187, 0.22183 },
        d28 = { 0.49471, 0.26246 },
        d29 = { 0.37366, 0.29707 },
        d30 = { 0.25235, 0.32045 },
        d31 = { 0.12487, 0.33497 },
        d32 = { 0, 0.32813 },
        d33 = { -0.11735, 0.33549 },
        d34 = { -0.24687, 0.32122 },
        d35 = { -0.3748, 0.29592 },
        d36 = { -0.4892, 0.26408 },
        d37 = { -0.61153, 0.21818 },
        d38 = { -0.70974, 0.16947 },
        d39 = { -0.79845, 0.11485 },
        d40 = { -0.88499, 0.04851 },
        d41 = { -0.96475, -0.02467 },
        d42 = { -1.01989, -0.09159 },
        d43 = { -1.0754, -0.17592 },
        d44 = { -1.11704, -0.25046 },
        d45 = { -1.14786, -0.33422 },
        d46 = { -1.15889, -0.4122 },
        d47 = { -1.16608, -0.50088 },
        d48 = { -0.96875, -0.94141 },
        d49 = { -1.15788, -0.71825 },
        d50 = { -1.13618, -0.82479 },
        d51 = { -1.10985, -0.91065 },
        d52 = { -1.0737, -0.98121 },
        d53 = { -1.02353, -1.0605 },
        d54 = { -0.48841, -1.3639 },
        d55 = { -0.43031, -1.392 },
        d56 = { -0.3578, -1.4192 },
        d57 = { -0.26903, -1.45018 },
        d58 = { -0.6587, -1.43068 },
        d59 = { -0.55749, -1.48418 },
        d60 = { -0.00309, -1.49547 },
        d61 = { -0.33811, -1.56036 },
        d62 = { -0.21915, -1.5849 },
        d63 = { -0.09706, -1.59787 }
      },
      ecart_max = 0.1606,
      ecarts_bouche = {
        d00 = { -0.1531, 0 },
        d01 = { -0.1562, -0.0318 },
        d02 = { -0.1449, -0.0555 },
        d03 = { -0.1283, -0.0629 },
        d04 = { -0.1063, -0.0726 },
        d05 = { -0.0826, -0.0745 },
        d06 = { -0.0527, -0.0801 },
        d07 = { 0.2941, -0.4665 },
        d08 = { 0.3311, -0.4521 },
        d09 = { 0.3725, -0.4626 },
        d10 = { 0.4092, -0.4559 },
        d11 = { 0.0972, -0.0525 },
        d12 = { 0.113, -0.0534 },
        d13 = { 0.1242, -0.0553 },
        d14 = { 0.1357, -0.0443 },
        d15 = { 0.1402, -0.0246 },
        d16 = { 0.3373, -0.325 },
        d17 = { 0.1305, 0.0293 },
        d18 = { 0.1132, 0.0325 },
        d19 = { 0.0896, 0.0355 },
        d20 = { 0.0684, 0.0317 },
        d21 = { 0.0533, 0.0418 },
        d22 = { 0.0264, 0.0356 },
        d23 = { 0.0024, 0.035 },
        d24 = { -0.0179, 0.0423 },
        d25 = { -0.0425, 0.036 },
        d26 = { -0.0624, 0.0351 },
        d27 = { -0.0846, 0.0253 },
        d28 = { -0.1019, 0.0174 },
        d29 = { -0.1145, 0.0167 },
        d30 = { -0.124, 0.0108 },
        d31 = { -0.1297, 0.0076 },
        d32 = { -0.1203, 0 },
        d33 = { -0.1291, -0.0151 },
        d34 = { -0.1232, -0.0163 },
        d35 = { -0.1139, -0.0152 },
        d36 = { -0.1005, -0.0229 },
        d37 = { -0.0875, -0.0154 },
        d38 = { -0.0669, -0.0239 },
        d39 = { -0.0436, -0.0328 },
        d40 = { -0.0208, -0.0319 },
        d41 = { -0.0002, -0.0276 },
        d42 = { 0.0275, -0.0388 },
        d43 = { 0.0503, -0.0318 },
        d44 = { 0.0698, -0.0372 },
        d45 = { 0.0895, -0.0351 },
        d46 = { 0.1143, -0.0408 },
        d47 = { 0.1308, -0.0342 },
        d48 = { 0.3373, 0.325 },
        d49 = { 0.1399, 0.0212 },
        d50 = { 0.1362, 0.0481 },
        d51 = { 0.1241, 0.055 },
        d52 = { 0.1117, 0.0483 },
        d53 = { 0.0975, 0.0536 },
        d54 = { 0.4129, 0.4672 },
        d55 = { 0.3698, 0.4549 },
        d56 = { 0.33, 0.4489 },
        d57 = { 0.2905, 0.4561 },
        d58 = { -0.0526, 0.0805 },
        d59 = { -0.0814, 0.0786 },
        d60 = { 0.1464, 0.4417 },
        d61 = { -0.1286, 0.0614 },
        d62 = { -0.1455, 0.0513 },
        d63 = { -0.1557, 0.0393 }
      },
      eclat_visible = {
        d00 = { 0, -1.77955 },
        d01 = { 0.16123, -1.77394 },
        d02 = { 0.32092, -1.7572 },
        d03 = { 0.47751, -1.72946 },
        d04 = { 0.6295, -1.69101 },
        d05 = { 0.77543, -1.6422 },
        d06 = { 0.9139, -1.58352 },
        d07 = { 1.04356, -1.51552 },
        d08 = { 1.16317, -1.43887 },
        d09 = { 1.27158, -1.35429 },
        d10 = { 1.36775, -1.2626 },
        d11 = { 1.45074, -1.1647 },
        d12 = { 1.51976, -1.06151 },
        d13 = { 1.57415, -0.95403 },
        d14 = { 1.61337, -0.8433 },
        d15 = { 1.63706, -0.73039 },
        d16 = { 1.64498, -0.61638 },
        d17 = { 1.63706, -0.50237 },
        d18 = { 1.61337, -0.38946 },
        d19 = { 1.57415, -0.27873 },
        d20 = { 1.51976, -0.17125 },
        d21 = { 1.45074, -0.06806 },
        d22 = { 1.36775, 0.02984 },
        d23 = { 1.27158, 0.12153 },
        d24 = { 1.16317, 0.20611 },
        d25 = { 1.04356, 0.28276 },
        d26 = { 0.9139, 0.35076 },
        d27 = { 0.77543, 0.40944 },
        d28 = { 0.6295, 0.45825 },
        d29 = { 0.47751, 0.4967 },
        d30 = { 0.32092, 0.52444 },
        d31 = { 0.16123, 0.54118 },
        d32 = { 0, 0.54679 },
        d33 = { -0.16123, 0.54118 },
        d34 = { -0.32092, 0.52444 },
        d35 = { -0.47751, 0.4967 },
        d36 = { -0.6295, 0.45825 },
        d37 = { -0.77543, 0.40944 },
        d38 = { -0.9139, 0.35076 },
        d39 = { -1.04356, 0.28276 },
        d40 = { -1.16317, 0.20611 },
        d41 = { -1.27158, 0.12153 },
        d42 = { -1.36775, 0.02984 },
        d43 = { -1.45074, -0.06806 },
        d44 = { -1.51976, -0.17125 },
        d45 = { -1.57415, -0.27873 },
        d46 = { -1.61337, -0.38946 },
        d47 = { -1.63706, -0.50237 },
        d48 = { -1.64498, -0.61638 },
        d49 = { -1.63706, -0.73039 },
        d50 = { -1.61337, -0.8433 },
        d51 = { -1.57415, -0.95403 },
        d52 = { -1.51976, -1.06151 },
        d53 = { -1.45074, -1.1647 },
        d54 = { -1.36775, -1.2626 },
        d55 = { -1.27158, -1.35429 },
        d56 = { -1.16317, -1.43887 },
        d57 = { -1.04356, -1.51552 },
        d58 = { -0.9139, -1.58352 },
        d59 = { -0.77543, -1.6422 },
        d60 = { -0.6295, -1.69101 },
        d61 = { -0.47751, -1.72946 },
        d62 = { -0.32092, -1.7572 },
        d63 = { -0.16123, -1.77394 }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/gun/gun-e02-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e02-piece-main.png",
            height = 70,
            shift = { 0, 0.640625 },
            width = 172
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e02-piece-main.png",
            height = 35,
            shift = { 0, 0.640625 },
            width = 86
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e02-piece-shadow.png",
            height = 52,
            shift = { 0.265625, 0.65625 },
            width = 162
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e02-piece-shadow.png",
            height = 26,
            shift = { 0.265625, 0.65625 },
            width = 81
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e02-socle-glow.png",
            height = 120,
            shift = { -0.109375, 0 },
            width = 118
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e02-socle-glow.png",
            height = 60,
            shift = { -0.109375, 0 },
            width = 59
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e02-socle-light.png",
            height = 248,
            shift = { -0.09375, 0.03125 },
            width = 260
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e02-socle-light.png",
            height = 124,
            shift = { -0.09375, 0.03125 },
            width = 130
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e02-socle-main.png",
            height = 162,
            shift = { -0.03125, -0.046875 },
            width = 168
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e02-socle-main.png",
            height = 81,
            shift = { -0.03125, -0.046875 },
            width = 84
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e02-socle-shadow.png",
            height = 134,
            shift = { 0.296875, 0.015625 },
            width = 174
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e02-socle-shadow.png",
            height = 67,
            shift = { 0.296875, 0.015625 },
            width = 87
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e02-tete-glow.png",
            height = 128,
            line_length = 8,
            shift = { 0, -0.53125 },
            width = 172
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e02-tete-glow.png",
            height = 64,
            line_length = 8,
            shift = { 0, -0.53125 },
            width = 86
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e02-tete-main.png",
            height = 138,
            line_length = 8,
            shift = { 0, -0.578125 },
            width = 180
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e02-tete-main.png",
            height = 69,
            line_length = 8,
            shift = { 0, -0.578125 },
            width = 90
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e02-tete-shadow.png",
            height = 128,
            line_length = 8,
            shift = { 0.75, 0 },
            width = 192
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e02-tete-shadow.png",
            height = 64,
            line_length = 8,
            shift = { 0.75, 0 },
            width = 96
          }
        }
      },
      tir = {
        projectile_center = { 0, 0.38362 },
        projectile_creation_distance = 1.64498
      }
    },
    [3] = {
      boite = { { -1.3125, -1.53125 }, { 1.3125, 1.21875 } },
      bouches = {
        E = { 1.23438, -0.57812 },
        N = { 0, -1.51562 },
        O = { -1.23438, -0.57812 },
        S = { 0, 0.35938 }
      },
      ecart_max = 0.1093,
      ecarts_bouche = {
        E = { 0.0773, 0 },
        N = { -0.1093, 0 },
        O = { 0.0773, 0 },
        S = { -0.1093, 0 }
      },
      eclat_visible = {
        E = { 1.65058, -0.57813 },
        N = { 0, -1.74526 },
        O = { -1.65058, -0.57813 },
        S = { 0, 0.589 }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/gun/gun-e03-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e03-piece-glow.png",
            height = 48,
            shift = { -0.15625, 0.625 },
            width = 108
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e03-piece-glow.png",
            height = 24,
            shift = { -0.15625, 0.625 },
            width = 54
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e03-piece-main.png",
            height = 66,
            shift = { 0, 0.578125 },
            width = 160
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e03-piece-main.png",
            height = 33,
            shift = { 0, 0.578125 },
            width = 80
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e03-piece-shadow.png",
            height = 50,
            shift = { 0.265625, 0.640625 },
            width = 166
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e03-piece-shadow.png",
            height = 25,
            shift = { 0.265625, 0.640625 },
            width = 83
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e03-socle-glow.png",
            height = 74,
            shift = { 0.375, 0.390625 },
            width = 88
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e03-socle-glow.png",
            height = 37,
            shift = { 0.375, 0.390625 },
            width = 44
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e03-socle-light.png",
            height = 104,
            shift = { 1, 0.6875 },
            width = 100
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e03-socle-light.png",
            height = 52,
            shift = { 1, 0.6875 },
            width = 50
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e03-socle-main.png",
            height = 152,
            shift = { 0, 0.03125 },
            width = 168
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e03-socle-main.png",
            height = 76,
            shift = { 0, 0.03125 },
            width = 84
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e03-socle-shadow.png",
            height = 130,
            shift = { 0.5, 0.046875 },
            width = 196
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e03-socle-shadow.png",
            height = 65,
            shift = { 0.5, 0.046875 },
            width = 98
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e03-tete-glow.png",
            height = 122,
            line_length = 1,
            shift = { 0, -0.578125 },
            width = 160
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e03-tete-glow.png",
            height = 61,
            line_length = 1,
            shift = { 0, -0.578125 },
            width = 80
          }
        },
        main = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e03-tete-main.png",
            height = 122,
            line_length = 1,
            shift = { 0, -0.578125 },
            width = 164
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e03-tete-main.png",
            height = 61,
            line_length = 1,
            shift = { 0, -0.578125 },
            width = 82
          }
        },
        shadow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e03-tete-shadow.png",
            height = 116,
            line_length = 1,
            shift = { 0.734375, 0 },
            width = 170
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e03-tete-shadow.png",
            height = 58,
            line_length = 1,
            shift = { 0.734375, 0 },
            width = 85
          }
        }
      },
      tir = {
        projectile_center = { 0, 0.42187 },
        projectile_creation_distance = 1.65058
      }
    },
    [4] = {
      boite = { { -1.90625, -2.28125 }, { 1.90625, 1.6875 } },
      bouches = {
        E = { 1.85938, -0.8125 },
        N = { 0, -2.25 },
        O = { -1.85938, -0.8125 },
        S = { 0, 0.60938 }
      },
      ecart_max = 0.1467,
      ecarts_bouche = {
        E = { 0.101, 0.0039 },
        N = { -0.1467, 0 },
        O = { 0.101, -0.0039 },
        S = { -0.1389, 0 }
      },
      eclat_visible = {
        E = { 2.29927, -0.81641 },
        N = { 0, -2.44222 },
        O = { -2.29927, -0.81641 },
        S = { 0, 0.8094 }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/gun/gun-e04-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e04-piece-glow.png",
            height = 8,
            shift = { -0.0625, 0.8125 },
            width = 160
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e04-piece-glow.png",
            height = 4,
            shift = { -0.0625, 0.8125 },
            width = 80
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e04-piece-main.png",
            height = 66,
            shift = { 0, 1.078125 },
            width = 224
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e04-piece-main.png",
            height = 33,
            shift = { 0, 1.078125 },
            width = 112
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e04-piece-shadow.png",
            height = 56,
            shift = { 0.1875, 1.0625 },
            width = 216
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e04-piece-shadow.png",
            height = 28,
            shift = { 0.1875, 1.0625 },
            width = 108
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e04-socle-glow.png",
            height = 220,
            shift = { -0.1875, -0.34375 },
            width = 160
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e04-socle-glow.png",
            height = 110,
            shift = { -0.1875, -0.34375 },
            width = 80
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e04-socle-light.png",
            height = 232,
            shift = { -0.21875, -0.65625 },
            width = 296
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e04-socle-light.png",
            height = 116,
            shift = { -0.21875, -0.65625 },
            width = 148
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e04-socle-main.png",
            height = 240,
            shift = { -0.015625, -0.1875 },
            width = 222
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e04-socle-main.png",
            height = 120,
            shift = { -0.015625, -0.1875 },
            width = 111
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e04-socle-shadow.png",
            height = 190,
            shift = { 0.265625, 0.015625 },
            width = 218
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e04-socle-shadow.png",
            height = 95,
            shift = { 0.265625, 0.015625 },
            width = 109
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e04-tete-glow.png",
            height = 188,
            line_length = 1,
            shift = { 0, -0.8125 },
            width = 244
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e04-tete-glow.png",
            height = 94,
            line_length = 1,
            shift = { 0, -0.8125 },
            width = 122
          }
        },
        main = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e04-tete-main.png",
            height = 188,
            line_length = 1,
            shift = { 0, -0.8125 },
            width = 244
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e04-tete-main.png",
            height = 94,
            line_length = 1,
            shift = { 0, -0.8125 },
            width = 122
          }
        },
        shadow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e04-tete-shadow.png",
            height = 172,
            line_length = 1,
            shift = { 1.03125, 0 },
            width = 260
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e04-tete-shadow.png",
            height = 86,
            line_length = 1,
            shift = { 1.03125, 0 },
            width = 130
          }
        }
      },
      tir = {
        projectile_center = { 0, 0.18359 },
        projectile_creation_distance = 2.29927
      }
    },
    [5] = {
      boite = { { -2.21875, -2.5 }, { 2.21875, 1.6875 } },
      bouches = {
        d00 = { 0, -2.23438 },
        d01 = { 0.19443, -2.23681 },
        d02 = { 0.39171, -2.21456 },
        d03 = { 0.58167, -2.17895 },
        d04 = { 0.76159, -2.12997 },
        d05 = { 0.9492, -2.06312 },
        d06 = { 1.10643, -1.98946 },
        d07 = { 1.25389, -1.90427 },
        d08 = { 1.39796, -1.80258 },
        d09 = { 1.52252, -1.6937 },
        d10 = { 1.62435, -1.58435 },
        d11 = { 1.7152, -1.46108 },
        d12 = { 1.78333, -1.3383 },
        d13 = { 1.83244, -1.20886 },
        d14 = { 1.86437, -1.07948 },
        d15 = { 1.88014, -0.94744 },
        d16 = { 1.875, -0.8125 },
        d17 = { 1.88048, -0.67996 },
        d18 = { 1.86554, -0.54969 },
        d19 = { 1.83436, -0.42062 },
        d20 = { 1.78747, -0.29376 },
        d21 = { 1.71603, -0.16502 },
        d22 = { 1.62729, -0.04794 },
        d23 = { 1.52298, 0.0683 },
        d24 = { 1.40102, 0.17541 },
        d25 = { 1.25762, 0.27537 },
        d26 = { 1.10859, 0.3619 },
        d27 = { 0.95014, 0.43568 },
        d28 = { 0.76331, 0.50352 },
        d29 = { 0.58803, 0.55145 },
        d30 = { 0.39388, 0.58866 },
        d31 = { 0.20022, 0.61012 },
        d32 = { 0, 0.60938 },
        d33 = { -0.1956, 0.61044 },
        d34 = { -0.39458, 0.58856 },
        d35 = { -0.579, 0.55339 },
        d36 = { -0.76665, 0.50271 },
        d37 = { -0.94981, 0.4358 },
        d38 = { -1.10919, 0.36161 },
        d39 = { -1.25404, 0.27745 },
        d40 = { -1.3987, 0.17705 },
        d41 = { -1.51906, 0.07168 },
        d42 = { -1.62491, -0.04541 },
        d43 = { -1.71404, -0.16239 },
        d44 = { -1.78359, -0.29038 },
        d45 = { -1.83535, -0.42292 },
        d46 = { -1.8651, -0.54812 },
        d47 = { -1.8802, -0.67799 },
        d48 = { -1.875, -0.8125 },
        d49 = { -1.8816, -0.937 },
        d50 = { -1.86392, -1.08106 },
        d51 = { -1.83546, -1.20699 },
        d52 = { -1.7836, -1.33785 },
        d53 = { -1.7126, -1.46452 },
        d54 = { -1.62359, -1.58189 },
        d55 = { -1.52292, -1.69419 },
        d56 = { -1.40035, -1.80088 },
        d57 = { -1.26041, -1.90049 },
        d58 = { -1.10819, -1.98949 },
        d59 = { -0.94355, -2.06526 },
        d60 = { -0.75976, -2.1309 },
        d61 = { -0.58287, -2.17869 },
        d62 = { -0.39241, -2.21446 },
        d63 = { -0.19412, -2.23683 }
      },
      ecart_max = 0.1323,
      ecarts_bouche = {
        d00 = { -0.1009, 0 },
        d01 = { -0.1086, -0.0038 },
        d02 = { -0.1035, -0.0023 },
        d03 = { -0.0957, -0.0038 },
        d04 = { -0.0836, -0.0083 },
        d05 = { -0.0742, 0.0036 },
        d06 = { -0.0558, -0.0035 },
        d07 = { -0.0362, -0.0079 },
        d08 = { -0.0196, -0.0005 },
        d09 = { -0.0007, 0.0028 },
        d10 = { 0.0206, -0.0031 },
        d11 = { 0.0397, 0.0006 },
        d12 = { 0.0608, -0.0025 },
        d13 = { 0.0827, -0.0023 },
        d14 = { 0.1016, -0.0038 },
        d15 = { 0.1167, -0.0031 },
        d16 = { 0.1323, 0.0009 },
        d17 = { 0.1164, 0.0025 },
        d18 = { 0.1007, 0.0013 },
        d19 = { 0.0814, -0.0007 },
        d20 = { 0.0583, -0.0037 },
        d21 = { 0.0386, -0.0002 },
        d22 = { 0.0203, -0.0031 },
        d23 = { -0.0019, -0.0018 },
        d24 = { -0.0219, -0.0015 },
        d25 = { -0.0377, 0.0039 },
        d26 = { -0.0567, 0.0015 },
        d27 = { -0.0742, -0.0047 },
        d28 = { -0.0847, 0.007 },
        d29 = { -0.0976, -0.0023 },
        d30 = { -0.105, 0.0005 },
        d31 = { -0.1095, -0.0019 },
        d32 = { -0.1027, 0 },
        d33 = { -0.1092, -0.0027 },
        d34 = { -0.1051, 0.0002 },
        d35 = { -0.0958, -0.0068 },
        d36 = { -0.0857, -0.0037 },
        d37 = { -0.0741, 0.0044 },
        d38 = { -0.057, -0.0008 },
        d39 = { -0.0363, -0.0078 },
        d40 = { -0.021, -0.0012 },
        d41 = { -0.0002, -0.0031 },
        d42 = { 0.0214, -0.0002 },
        d43 = { 0.0396, -0.003 },
        d44 = { 0.061, -0.0006 },
        d45 = { 0.0809, 0.0031 },
        d46 = { 0.101, -0.0029 },
        d47 = { 0.1165, -0.0045 },
        d48 = { 0.1323, -0.0009 },
        d49 = { 0.116, -0.0074 },
        d50 = { 0.1018, 0.0054 },
        d51 = { 0.0801, -0.0001 },
        d52 = { 0.0606, 0.0019 },
        d53 = { 0.0409, 0.0036 },
        d54 = { 0.0223, 0.0012 },
        d55 = { -0.0013, -0.0026 },
        d56 = { -0.0206, -0.0022 },
        d57 = { -0.0387, 0.0008 },
        d58 = { -0.057, 0.0023 },
        d59 = { -0.0725, 0.0022 },
        d60 = { -0.0834, 0.0104 },
        d61 = { -0.096, 0.0026 },
        d62 = { -0.1036, 0.0016 },
        d63 = { -0.1086, 0.0041 }
      },
      eclat_visible = {
        d00 = { 0, -2.47239 },
        d01 = { 0.22996, -2.46441 },
        d02 = { 0.45771, -2.44052 },
        d03 = { 0.68105, -2.40096 },
        d04 = { 0.89784, -2.34611 },
        d05 = { 1.10597, -2.27651 },
        d06 = { 1.30346, -2.19281 },
        d07 = { 1.48839, -2.09583 },
        d08 = { 1.65899, -1.98649 },
        d09 = { 1.81361, -1.86586 },
        d10 = { 1.95077, -1.7351 },
        d11 = { 2.06914, -1.59546 },
        d12 = { 2.16758, -1.44828 },
        d13 = { 2.24515, -1.29499 },
        d14 = { 2.3011, -1.13706 },
        d15 = { 2.33488, -0.97602 },
        d16 = { 2.34618, -0.81341 },
        d17 = { 2.33488, -0.6508 },
        d18 = { 2.3011, -0.48976 },
        d19 = { 2.24515, -0.33183 },
        d20 = { 2.16758, -0.17854 },
        d21 = { 2.06914, -0.03136 },
        d22 = { 1.95077, 0.10828 },
        d23 = { 1.81361, 0.23904 },
        d24 = { 1.65899, 0.35967 },
        d25 = { 1.48839, 0.46901 },
        d26 = { 1.30346, 0.56599 },
        d27 = { 1.10597, 0.64969 },
        d28 = { 0.89784, 0.71929 },
        d29 = { 0.68105, 0.77414 },
        d30 = { 0.45771, 0.8137 },
        d31 = { 0.22996, 0.83759 },
        d32 = { 0, 0.84557 },
        d33 = { -0.22996, 0.83759 },
        d34 = { -0.45771, 0.8137 },
        d35 = { -0.68105, 0.77414 },
        d36 = { -0.89784, 0.71929 },
        d37 = { -1.10597, 0.64969 },
        d38 = { -1.30346, 0.56599 },
        d39 = { -1.48839, 0.46901 },
        d40 = { -1.65899, 0.35967 },
        d41 = { -1.81361, 0.23904 },
        d42 = { -1.95077, 0.10828 },
        d43 = { -2.06914, -0.03136 },
        d44 = { -2.16758, -0.17854 },
        d45 = { -2.24515, -0.33183 },
        d46 = { -2.3011, -0.48976 },
        d47 = { -2.33488, -0.6508 },
        d48 = { -2.34618, -0.81341 },
        d49 = { -2.33488, -0.97602 },
        d50 = { -2.3011, -1.13706 },
        d51 = { -2.24515, -1.29499 },
        d52 = { -2.16758, -1.44828 },
        d53 = { -2.06914, -1.59546 },
        d54 = { -1.95077, -1.7351 },
        d55 = { -1.81361, -1.86586 },
        d56 = { -1.65899, -1.98649 },
        d57 = { -1.48839, -2.09583 },
        d58 = { -1.30346, -2.19281 },
        d59 = { -1.10597, -2.27651 },
        d60 = { -0.89784, -2.34611 },
        d61 = { -0.68105, -2.40096 },
        d62 = { -0.45771, -2.44052 },
        d63 = { -0.22996, -2.46441 }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/gun/gun-e05-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e05-piece-glow.png",
            height = 34,
            shift = { 0, 0.828125 },
            width = 164
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e05-piece-glow.png",
            height = 17,
            shift = { 0, 0.828125 },
            width = 82
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e05-piece-light.png",
            height = 222,
            shift = { 0, 0.390625 },
            width = 328
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e05-piece-light.png",
            height = 111,
            shift = { 0, 0.390625 },
            width = 164
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e05-piece-main.png",
            height = 72,
            shift = { 0, 1.0625 },
            width = 232
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e05-piece-main.png",
            height = 36,
            shift = { 0, 1.0625 },
            width = 116
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e05-piece-shadow.png",
            height = 60,
            shift = { 0.21875, 1.0625 },
            width = 232
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e05-piece-shadow.png",
            height = 30,
            shift = { 0.21875, 1.0625 },
            width = 116
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e05-socle-glow.png",
            height = 190,
            shift = { 0.015625, -0.046875 },
            width = 194
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e05-socle-glow.png",
            height = 95,
            shift = { 0.015625, -0.046875 },
            width = 97
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e05-socle-light.png",
            height = 284,
            shift = { 0.03125, -0.15625 },
            width = 300
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e05-socle-light.png",
            height = 142,
            shift = { 0.03125, -0.15625 },
            width = 150
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e05-socle-main.png",
            height = 212,
            shift = { 0, 0.03125 },
            width = 232
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e05-socle-main.png",
            height = 106,
            shift = { 0, 0.03125 },
            width = 116
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e05-socle-shadow.png",
            height = 188,
            shift = { 0.390625, 0.03125 },
            width = 242
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e05-socle-shadow.png",
            height = 94,
            shift = { 0.390625, 0.03125 },
            width = 121
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e05-tete-glow.png",
            height = 210,
            line_length = 8,
            shift = { 0, -0.796875 },
            width = 284
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e05-tete-glow.png",
            height = 105,
            line_length = 8,
            shift = { 0, -0.796875 },
            width = 142
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e05-tete-main.png",
            height = 216,
            line_length = 8,
            shift = { 0, -0.8125 },
            width = 284
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e05-tete-main.png",
            height = 108,
            line_length = 8,
            shift = { 0, -0.8125 },
            width = 142
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e05-tete-shadow.png",
            height = 202,
            line_length = 8,
            shift = { 1.046875, -0.015625 },
            width = 302
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e05-tete-shadow.png",
            height = 101,
            line_length = 8,
            shift = { 1.046875, -0.015625 },
            width = 151
          }
        }
      },
      tir = {
        projectile_center = { 0, 0.18659 },
        projectile_creation_distance = 2.34618
      }
    },
    [6] = {
      boite = { { -1.875, -2.25 }, { 1.875, 1.6875 } },
      bouches = {
        E = { 1.85938, -0.8125 },
        N = { 0, -2.23438 },
        O = { -1.85938, -0.8125 },
        S = { 0, 0.60156 }
      },
      ecart_max = 0.1369,
      ecarts_bouche = {
        E = { 0.0955, 0.002 },
        N = { -0.1369, 0 },
        O = { 0.0955, -0.002 },
        S = { -0.133, 0 }
      },
      eclat_visible = {
        E = { 2.29375, -0.81445 },
        N = { 0, -2.43636 },
        O = { -2.29375, -0.81445 },
        S = { 0, 0.80746 }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/gun/gun-e06-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e06-piece-glow.png",
            height = 44,
            shift = { 0, 1.03125 },
            width = 156
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e06-piece-glow.png",
            height = 22,
            shift = { 0, 1.03125 },
            width = 78
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e06-piece-light.png",
            height = 242,
            shift = { -0.015625, 0.671875 },
            width = 326
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e06-piece-light.png",
            height = 121,
            shift = { -0.015625, 0.671875 },
            width = 163
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e06-piece-main.png",
            height = 62,
            shift = { 0, 1.046875 },
            width = 204
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e06-piece-main.png",
            height = 31,
            shift = { 0, 1.046875 },
            width = 102
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e06-piece-shadow.png",
            height = 58,
            shift = { 0.15625, 1.046875 },
            width = 208
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e06-piece-shadow.png",
            height = 29,
            shift = { 0.15625, 1.046875 },
            width = 104
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e06-socle-glow.png",
            height = 206,
            shift = { -0.078125, -0.171875 },
            width = 198
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e06-socle-glow.png",
            height = 103,
            shift = { -0.078125, -0.171875 },
            width = 99
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e06-socle-light.png",
            height = 270,
            shift = { 0.46875, -0.140625 },
            width = 236
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e06-socle-light.png",
            height = 135,
            shift = { 0.46875, -0.140625 },
            width = 118
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e06-socle-main.png",
            height = 222,
            shift = { -0.03125, -0.046875 },
            width = 232
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e06-socle-main.png",
            height = 111,
            shift = { -0.03125, -0.046875 },
            width = 116
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e06-socle-shadow.png",
            height = 186,
            shift = { 0.375, 0.046875 },
            width = 244
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e06-socle-shadow.png",
            height = 93,
            shift = { 0.375, 0.046875 },
            width = 122
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e06-tete-glow.png",
            height = 184,
            line_length = 1,
            shift = { 0, -0.8125 },
            width = 240
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e06-tete-glow.png",
            height = 92,
            line_length = 1,
            shift = { 0, -0.8125 },
            width = 120
          }
        },
        main = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e06-tete-main.png",
            height = 184,
            line_length = 1,
            shift = { 0, -0.8125 },
            width = 240
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e06-tete-main.png",
            height = 92,
            line_length = 1,
            shift = { 0, -0.8125 },
            width = 120
          }
        },
        shadow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e06-tete-shadow.png",
            height = 172,
            line_length = 1,
            shift = { 1.046875, 0 },
            width = 258
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e06-tete-shadow.png",
            height = 86,
            line_length = 1,
            shift = { 1.046875, 0 },
            width = 129
          }
        }
      },
      tir = {
        projectile_center = { 0, 0.18555 },
        projectile_creation_distance = 2.29375
      }
    },
    [7] = {
      boite = { { -2.96875, -3.15625 }, { 2.96875, 2.1875 } },
      bouches = {
        E = { 2.9375, -1.03125 },
        N = { 0, -3.125 },
        O = { -2.9375, -1.03125 },
        S = { 0, 1.04688 }
      },
      ecart_max = 0.076,
      ecarts_bouche = {
        E = { 0.051, 0.0039 },
        N = { -0.076, 0 },
        O = { 0.051, -0.0039 },
        S = { -0.0682, 0 }
      },
      eclat_visible = {
        E = { 3.32738, -1.03516 },
        N = { 0, -3.38795 },
        O = { -3.32738, -1.03516 },
        S = { 0, 1.31763 }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/gun/gun-e07-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e07-piece-glow.png",
            height = 64,
            shift = { 0, 1.4375 },
            width = 264
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e07-piece-glow.png",
            height = 32,
            shift = { 0, 1.4375 },
            width = 132
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e07-piece-light.png",
            height = 168,
            shift = { 0, 0.4375 },
            width = 376
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e07-piece-light.png",
            height = 84,
            shift = { 0, 0.4375 },
            width = 188
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e07-piece-main.png",
            height = 72,
            shift = { 0, 1.46875 },
            width = 288
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e07-piece-main.png",
            height = 36,
            shift = { 0, 1.46875 },
            width = 144
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e07-piece-shadow.png",
            height = 64,
            shift = { 0.125, 1.4375 },
            width = 284
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e07-piece-shadow.png",
            height = 32,
            shift = { 0.125, 1.4375 },
            width = 142
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e07-socle-glow.png",
            height = 260,
            shift = { -0.015625, -0.09375 },
            width = 246
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e07-socle-glow.png",
            height = 130,
            shift = { -0.015625, -0.09375 },
            width = 123
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e07-socle-light.png",
            height = 292,
            shift = { 0.578125, -0.53125 },
            width = 314
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e07-socle-light.png",
            height = 146,
            shift = { 0.578125, -0.53125 },
            width = 157
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e07-socle-main.png",
            height = 276,
            shift = { -0.046875, 0.03125 },
            width = 282
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e07-socle-main.png",
            height = 138,
            shift = { -0.046875, 0.03125 },
            width = 141
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e07-socle-shadow.png",
            height = 250,
            shift = { 0.203125, 0.046875 },
            width = 278
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e07-socle-shadow.png",
            height = 125,
            shift = { 0.203125, 0.046875 },
            width = 139
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e07-tete-glow.png",
            height = 270,
            line_length = 1,
            shift = { 0, -1.046875 },
            width = 380
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e07-tete-glow.png",
            height = 135,
            line_length = 1,
            shift = { 0, -1.046875 },
            width = 190
          }
        },
        main = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e07-tete-main.png",
            height = 270,
            line_length = 1,
            shift = { 0, -1.046875 },
            width = 380
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e07-tete-main.png",
            height = 135,
            line_length = 1,
            shift = { 0, -1.046875 },
            width = 190
          }
        },
        shadow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e07-tete-shadow.png",
            height = 268,
            line_length = 1,
            shift = { 1.3125, 0 },
            width = 380
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e07-tete-shadow.png",
            height = 134,
            line_length = 1,
            shift = { 1.3125, 0 },
            width = 190
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.03516 },
        projectile_creation_distance = 3.32738
      }
    },
    [8] = {
      boite = { { -2.53125, -2.96875 }, { 2.53125, 2.15625 } },
      bouches = {
        E = { 2.51562, -1.03906 },
        N = { 0, -2.95312 },
        O = { -2.51562, -1.03906 },
        S = { 0, 0.875 }
      },
      ecart_max = 0.1564,
      ecarts_bouche = {
        E = { 0.1106, 0 },
        N = { -0.1564, 0 },
        O = { 0.1106, 0 },
        S = { -0.1564, 0 }
      },
      eclat_visible = {
        E = { 2.96511, -1.03906 },
        N = { 0, -3.13569 },
        O = { -2.96511, -1.03906 },
        S = { 0, 1.05757 }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/gun/gun-e08-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e08-piece-glow.png",
            height = 70,
            shift = { 0, 1.140625 },
            width = 268
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e08-piece-glow.png",
            height = 35,
            shift = { 0, 1.140625 },
            width = 134
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e08-piece-light.png",
            height = 68,
            shift = { -0.09375, 1.65625 },
            width = 292
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e08-piece-light.png",
            height = 34,
            shift = { -0.09375, 1.65625 },
            width = 146
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e08-piece-main.png",
            height = 92,
            shift = { 0, 1.28125 },
            width = 276
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e08-piece-main.png",
            height = 46,
            shift = { 0, 1.28125 },
            width = 138
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e08-piece-shadow.png",
            height = 66,
            shift = { 0.515625, 1.453125 },
            width = 298
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e08-piece-shadow.png",
            height = 33,
            shift = { 0.515625, 1.453125 },
            width = 149
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e08-socle-glow.png",
            height = 268,
            shift = { 0.0625, -0.125 },
            width = 256
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e08-socle-glow.png",
            height = 134,
            shift = { 0.0625, -0.125 },
            width = 128
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e08-socle-light.png",
            height = 142,
            shift = { 2.59375, -0.015625 },
            width = 64
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e08-socle-light.png",
            height = 71,
            shift = { 2.59375, -0.015625 },
            width = 32
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e08-socle-main.png",
            height = 282,
            shift = { 0.015625, -0.046875 },
            width = 290
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e08-socle-main.png",
            height = 141,
            shift = { 0.015625, -0.046875 },
            width = 145
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e08-socle-shadow.png",
            height = 254,
            shift = { 0.484375, 0.015625 },
            width = 314
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e08-socle-shadow.png",
            height = 127,
            shift = { 0.484375, 0.015625 },
            width = 157
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e08-tete-glow.png",
            height = 248,
            line_length = 1,
            shift = { 0, -1.03125 },
            width = 324
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e08-tete-glow.png",
            height = 124,
            line_length = 1,
            shift = { 0, -1.03125 },
            width = 162
          }
        },
        main = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e08-tete-main.png",
            height = 248,
            line_length = 1,
            shift = { 0, -1.03125 },
            width = 324
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e08-tete-main.png",
            height = 124,
            line_length = 1,
            shift = { 0, -1.03125 },
            width = 162
          }
        },
        shadow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e08-tete-shadow.png",
            height = 232,
            line_length = 1,
            shift = { 1.328125, 0 },
            width = 346
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e08-tete-shadow.png",
            height = 116,
            line_length = 1,
            shift = { 1.328125, 0 },
            width = 173
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.03906 },
        projectile_creation_distance = 2.96511
      }
    },
    [9] = {
      boite = { { -2.65625, -3.0625 }, { 2.65625, 2.1875 } },
      bouches = {
        E = { 2.625, -1.03906 },
        N = { 0, -3.04688 },
        O = { -2.625, -1.03906 },
        S = { 0, 0.96875 }
      },
      ecart_max = 0.1673,
      ecarts_bouche = {
        E = { 0.1183, 0 },
        N = { -0.1673, 0 },
        O = { 0.1183, 0 },
        S = { -0.1673, 0 }
      },
      eclat_visible = {
        E = { 3.08222, -1.03906 },
        N = { 0, -3.2185 },
        O = { -3.08222, -1.03906 },
        S = { 0, 1.14038 }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/gun/gun-e09-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e09-piece-glow.png",
            height = 32,
            shift = { 0.21875, 1.59375 },
            width = 196
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e09-piece-glow.png",
            height = 16,
            shift = { 0.21875, 1.59375 },
            width = 98
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e09-piece-main.png",
            height = 74,
            shift = { 0, 1.453125 },
            width = 292
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e09-piece-main.png",
            height = 37,
            shift = { 0, 1.453125 },
            width = 146
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e09-piece-shadow.png",
            height = 62,
            shift = { 0.234375, 1.421875 },
            width = 286
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e09-piece-shadow.png",
            height = 31,
            shift = { 0.234375, 1.421875 },
            width = 143
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e09-socle-glow.png",
            height = 284,
            shift = { -0.109375, -0.28125 },
            width = 270
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e09-socle-glow.png",
            height = 142,
            shift = { -0.109375, -0.28125 },
            width = 135
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e09-socle-light.png",
            height = 206,
            shift = { -1.640625, 0.703125 },
            width = 178
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e09-socle-light.png",
            height = 103,
            shift = { -1.640625, 0.703125 },
            width = 89
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e09-socle-main.png",
            height = 300,
            shift = { 0, -0.15625 },
            width = 292
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e09-socle-main.png",
            height = 150,
            shift = { 0, -0.15625 },
            width = 146
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e09-socle-shadow.png",
            height = 264,
            shift = { 0.421875, -0.0625 },
            width = 322
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e09-socle-shadow.png",
            height = 132,
            shift = { 0.421875, -0.0625 },
            width = 161
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e09-tete-glow.png",
            height = 260,
            line_length = 1,
            shift = { 0, -1.03125 },
            width = 340
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e09-tete-glow.png",
            height = 130,
            line_length = 1,
            shift = { 0, -1.03125 },
            width = 170
          }
        },
        main = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e09-tete-main.png",
            height = 260,
            line_length = 1,
            shift = { 0, -1.03125 },
            width = 340
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e09-tete-main.png",
            height = 130,
            line_length = 1,
            shift = { 0, -1.03125 },
            width = 170
          }
        },
        shadow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e09-tete-shadow.png",
            height = 240,
            line_length = 1,
            shift = { 1.3125, 0 },
            width = 364
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e09-tete-shadow.png",
            height = 120,
            line_length = 1,
            shift = { 1.3125, 0 },
            width = 182
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.03906 },
        projectile_creation_distance = 3.08222
      }
    },
    [10] = {
      boite = { { -2.84375, -3.34375 }, { 2.84375, 3.0625 } },
      bouches = {
        E = { 2.8125, -1.22656 },
        N = { 0, -3.3125 },
        O = { -2.8125, -1.23438 },
        S = { 0, 0.85938 }
      },
      ecart_max = 0.133,
      ecarts_bouche = {
        E = { 0.0926, 0.002 },
        N = { -0.129, 0 },
        O = { 0.0926, 0.0059 },
        S = { -0.133, 0 }
      },
      eclat_visible = {
        E = { 3.24405, -1.22852 },
        N = { 0, -3.52239 },
        O = { -3.24405, -1.22852 },
        S = { 0, 1.06535 }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/gun/gun-e10-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e10-piece-glow.png",
            height = 42,
            shift = { -0.09375, 2.546875 },
            width = 220
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e10-piece-glow.png",
            height = 21,
            shift = { -0.09375, 2.546875 },
            width = 110
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e10-piece-light.png",
            height = 102,
            shift = { 0, 2.703125 },
            width = 312
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e10-piece-light.png",
            height = 51,
            shift = { 0, 2.703125 },
            width = 156
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e10-piece-main.png",
            height = 70,
            shift = { 0, 2.515625 },
            width = 268
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e10-piece-main.png",
            height = 35,
            shift = { 0, 2.515625 },
            width = 134
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e10-piece-shadow.png",
            height = 34,
            shift = { 0.265625, 2.640625 },
            width = 270
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e10-piece-shadow.png",
            height = 17,
            shift = { 0.265625, 2.640625 },
            width = 135
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e10-socle-glow.png",
            height = 338,
            shift = { -0.046875, -0.078125 },
            width = 306
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e10-socle-glow.png",
            height = 169,
            shift = { -0.046875, -0.078125 },
            width = 153
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e10-socle-light.png",
            height = 352,
            shift = { -0.125, 0.6875 },
            width = 408
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e10-socle-light.png",
            height = 176,
            shift = { -0.125, 0.6875 },
            width = 204
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e10-socle-main.png",
            height = 360,
            shift = { -0.0625, -0.0625 },
            width = 352
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e10-socle-main.png",
            height = 180,
            shift = { -0.0625, -0.0625 },
            width = 176
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e10-socle-shadow.png",
            height = 324,
            shift = { 0.296875, 0.0625 },
            width = 358
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e10-socle-shadow.png",
            height = 162,
            shift = { 0.296875, 0.0625 },
            width = 179
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e10-tete-glow.png",
            height = 270,
            line_length = 1,
            shift = { 0, -1.234375 },
            width = 364
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e10-tete-glow.png",
            height = 135,
            line_length = 1,
            shift = { 0, -1.234375 },
            width = 182
          }
        },
        main = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e10-tete-main.png",
            height = 270,
            line_length = 1,
            shift = { 0, -1.234375 },
            width = 364
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e10-tete-main.png",
            height = 135,
            line_length = 1,
            shift = { 0, -1.234375 },
            width = 182
          }
        },
        shadow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e10-tete-shadow.png",
            height = 256,
            line_length = 1,
            shift = { 1.578125, 0 },
            width = 378
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e10-tete-shadow.png",
            height = 128,
            line_length = 1,
            shift = { 1.578125, 0 },
            width = 189
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.22852 },
        projectile_creation_distance = 3.24405
      }
    },
    [11] = {
      boite = { { -3.8125, -4.03125 }, { 3.8125, 3.0625 } },
      bouches = {
        E = { 3.79688, -1.23438 },
        N = { 0, -4.01562 },
        O = { -3.79688, -1.23438 },
        S = { 0, 1.54688 }
      },
      ecart_max = 0.1305,
      ecarts_bouche = {
        E = { 0.0923, 0 },
        N = { -0.1305, 0 },
        O = { 0.0923, 0 },
        S = { -0.1305, 0 }
      },
      eclat_visible = {
        E = { 4.22808, -1.23438 },
        N = { 0, -4.22406 },
        O = { -4.22808, -1.23438 },
        S = { 0, 1.7553 }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/gun/gun-e11-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e11-piece-glow.png",
            height = 24,
            shift = { -0.09375, 2.6875 },
            width = 224
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e11-piece-glow.png",
            height = 12,
            shift = { -0.09375, 2.6875 },
            width = 112
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e11-piece-light.png",
            height = 80,
            shift = { 0.015625, 2.875 },
            width = 298
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e11-piece-light.png",
            height = 40,
            shift = { 0.015625, 2.875 },
            width = 149
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e11-piece-main.png",
            height = 66,
            shift = { 0, 2.546875 },
            width = 268
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e11-piece-main.png",
            height = 33,
            shift = { 0, 2.546875 },
            width = 134
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e11-piece-shadow.png",
            height = 34,
            shift = { 0.25, 2.640625 },
            width = 268
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e11-piece-shadow.png",
            height = 17,
            shift = { 0.25, 2.640625 },
            width = 134
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e11-socle-glow.png",
            height = 336,
            shift = { 0, -0.09375 },
            width = 312
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e11-socle-glow.png",
            height = 168,
            shift = { 0, -0.09375 },
            width = 156
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e11-socle-light.png",
            height = 352,
            shift = { 0.03125, 0.6875 },
            width = 428
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e11-socle-light.png",
            height = 176,
            shift = { 0.03125, 0.6875 },
            width = 214
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e11-socle-main.png",
            height = 362,
            shift = { -0.046875, -0.046875 },
            width = 350
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e11-socle-main.png",
            height = 181,
            shift = { -0.046875, -0.046875 },
            width = 175
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e11-socle-shadow.png",
            height = 326,
            shift = { 0.421875, 0.046875 },
            width = 374
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e11-socle-shadow.png",
            height = 163,
            shift = { 0.421875, 0.046875 },
            width = 187
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e11-tete-glow.png",
            height = 360,
            line_length = 1,
            shift = { 0, -1.21875 },
            width = 488
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e11-tete-glow.png",
            height = 180,
            line_length = 1,
            shift = { 0, -1.21875 },
            width = 244
          }
        },
        main = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e11-tete-main.png",
            height = 360,
            line_length = 1,
            shift = { 0, -1.21875 },
            width = 488
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e11-tete-main.png",
            height = 180,
            line_length = 1,
            shift = { 0, -1.21875 },
            width = 244
          }
        },
        shadow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e11-tete-shadow.png",
            height = 348,
            line_length = 1,
            shift = { 1.5625, 0 },
            width = 504
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e11-tete-shadow.png",
            height = 174,
            line_length = 1,
            shift = { 1.5625, 0 },
            width = 252
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.23438 },
        projectile_creation_distance = 4.22808
      }
    },
    [12] = {
      boite = { { -3.03125, -3.5 }, { 3.03125, 3.0625 } },
      bouches = {
        E = { 3, -1.23047 },
        N = { 0, -3.09375 },
        O = { -3, -1.23438 },
        S = { 0, 1 }
      },
      ecart_max = 0.1093,
      ecarts_bouche = {
        E = { 0.0117, -0.0908 },
        N = { 0.0762, 0 },
        O = { 0.0117, 0.0947 },
        S = { -0.1093, 0 }
      },
      eclat_visible = {
        E = { 3.35064, -1.13965 },
        N = { 0, -3.50889 },
        O = { -3.35064, -1.13965 },
        S = { 0, 1.22959 }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/gun/gun-e12-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e12-piece-glow.png",
            height = 54,
            shift = { 0, 2.453125 },
            width = 232
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e12-piece-glow.png",
            height = 27,
            shift = { 0, 2.453125 },
            width = 116
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e12-piece-light.png",
            height = 132,
            shift = { 0, 2.46875 },
            width = 340
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e12-piece-light.png",
            height = 66,
            shift = { 0, 2.46875 },
            width = 170
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e12-piece-main.png",
            height = 74,
            shift = { 0, 2.484375 },
            width = 268
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e12-piece-main.png",
            height = 37,
            shift = { 0, 2.484375 },
            width = 134
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e12-piece-shadow.png",
            height = 34,
            shift = { 0.25, 2.640625 },
            width = 268
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e12-piece-shadow.png",
            height = 17,
            shift = { 0.25, 2.640625 },
            width = 134
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e12-socle-glow.png",
            height = 336,
            shift = { -0.078125, -0.125 },
            width = 318
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e12-socle-glow.png",
            height = 168,
            shift = { -0.078125, -0.125 },
            width = 159
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e12-socle-light.png",
            height = 352,
            shift = { -0.109375, 0.6875 },
            width = 410
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e12-socle-light.png",
            height = 176,
            shift = { -0.109375, 0.6875 },
            width = 205
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e12-socle-main.png",
            height = 366,
            shift = { -0.0625, -0.046875 },
            width = 352
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e12-socle-main.png",
            height = 183,
            shift = { -0.0625, -0.046875 },
            width = 176
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e12-socle-shadow.png",
            height = 332,
            shift = { 0.265625, 0.125 },
            width = 366
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e12-socle-shadow.png",
            height = 166,
            shift = { 0.265625, 0.125 },
            width = 183
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e12-tete-glow.png",
            height = 290,
            line_length = 1,
            shift = { 0, -1.234375 },
            width = 388
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e12-tete-glow.png",
            height = 145,
            line_length = 1,
            shift = { 0, -1.234375 },
            width = 194
          }
        },
        main = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e12-tete-main.png",
            height = 290,
            line_length = 1,
            shift = { 0, -1.234375 },
            width = 388
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e12-tete-main.png",
            height = 145,
            line_length = 1,
            shift = { 0, -1.234375 },
            width = 194
          }
        },
        shadow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e12-tete-shadow.png",
            height = 276,
            line_length = 1,
            shift = { 1.5625, 0 },
            width = 404
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e12-tete-shadow.png",
            height = 138,
            line_length = 1,
            shift = { 1.5625, 0 },
            width = 202
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.13965 },
        projectile_creation_distance = 3.35064
      }
    },
    [13] = {
      boite = { { -3.59375, -4.0625 }, { 3.59375, 3.40625 } },
      bouches = {
        E = { 3.5625, -1.41406 },
        N = { 0, -4.04688 },
        O = { -3.5625, -1.41406 },
        S = { 0, 1.21875 }
      },
      ecart_max = 0.142,
      ecarts_bouche = {
        E = { 0.1004, 0 },
        N = { -0.142, 0 },
        O = { 0.1004, 0 },
        S = { -0.142, 0 }
      },
      eclat_visible = {
        E = { 4.00185, -1.41406 },
        N = { 0, -4.24377 },
        O = { -4.00185, -1.41406 },
        S = { 0, 1.41565 }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/gun/gun-e13-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e13-piece-glow.png",
            height = 40,
            shift = { -0.03125, 2.875 },
            width = 188
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e13-piece-glow.png",
            height = 20,
            shift = { -0.03125, 2.875 },
            width = 94
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e13-piece-light.png",
            height = 112,
            shift = { 0, 3.0625 },
            width = 328
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e13-piece-light.png",
            height = 56,
            shift = { 0, 3.0625 },
            width = 164
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e13-piece-main.png",
            height = 60,
            shift = { 0, 2.9375 },
            width = 236
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e13-piece-main.png",
            height = 30,
            shift = { 0, 2.9375 },
            width = 118
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e13-piece-shadow.png",
            height = 46,
            shift = { 0.234375, 2.890625 },
            width = 230
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e13-piece-shadow.png",
            height = 23,
            shift = { 0.234375, 2.890625 },
            width = 115
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e13-socle-glow.png",
            height = 372,
            shift = { -0.0625, -0.15625 },
            width = 380
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e13-socle-glow.png",
            height = 186,
            shift = { -0.0625, -0.15625 },
            width = 190
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e13-socle-light.png",
            height = 478,
            shift = { 0, 0.171875 },
            width = 452
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e13-socle-light.png",
            height = 239,
            shift = { 0, 0.171875 },
            width = 226
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e13-socle-main.png",
            height = 398,
            shift = { 0, -0.046875 },
            width = 412
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e13-socle-main.png",
            height = 199,
            shift = { 0, -0.046875 },
            width = 206
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e13-socle-shadow.png",
            height = 374,
            shift = { 0.359375, 0.046875 },
            width = 434
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e13-socle-shadow.png",
            height = 187,
            shift = { 0.359375, 0.046875 },
            width = 217
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e13-tete-glow.png",
            height = 340,
            line_length = 1,
            shift = { 0, -1.40625 },
            width = 460
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e13-tete-glow.png",
            height = 170,
            line_length = 1,
            shift = { 0, -1.40625 },
            width = 230
          }
        },
        main = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e13-tete-main.png",
            height = 340,
            line_length = 1,
            shift = { 0, -1.40625 },
            width = 460
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e13-tete-main.png",
            height = 170,
            line_length = 1,
            shift = { 0, -1.40625 },
            width = 230
          }
        },
        shadow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e13-tete-shadow.png",
            height = 324,
            line_length = 1,
            shift = { 1.796875, 0 },
            width = 478
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e13-tete-shadow.png",
            height = 162,
            line_length = 1,
            shift = { 1.796875, 0 },
            width = 239
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.41406 },
        projectile_creation_distance = 4.00185
      }
    },
    [14] = {
      boite = { { -3.78125, -4.21875 }, { 3.78125, 3.375 } },
      bouches = {
        E = { 3.75, -1.41406 },
        N = { 0, -4.1875 },
        O = { -3.75, -1.41406 },
        S = { 0, 1.35938 }
      },
      ecart_max = 0.1474,
      ecarts_bouche = {
        E = { 0.1042, 0 },
        N = { -0.1474, 0 },
        O = { 0.1042, 0 },
        S = { -0.1474, 0 }
      },
      eclat_visible = {
        E = { 4.19314, -1.41406 },
        N = { 0, -4.37903 },
        O = { -4.19314, -1.41406 },
        S = { 0, 1.55091 }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/gun/gun-e14-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e14-piece-glow.png",
            height = 44,
            shift = { 0, 2.875 },
            width = 192
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e14-piece-glow.png",
            height = 22,
            shift = { 0, 2.875 },
            width = 96
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e14-piece-light.png",
            height = 126,
            shift = { 0, 2.953125 },
            width = 332
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e14-piece-light.png",
            height = 63,
            shift = { 0, 2.953125 },
            width = 166
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e14-piece-main.png",
            height = 64,
            shift = { 0, 2.875 },
            width = 232
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e14-piece-main.png",
            height = 32,
            shift = { 0, 2.875 },
            width = 116
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e14-piece-shadow.png",
            height = 48,
            shift = { 0.15625, 2.875 },
            width = 220
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e14-piece-shadow.png",
            height = 24,
            shift = { 0.15625, 2.875 },
            width = 110
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e14-socle-glow.png",
            height = 402,
            shift = { 0.109375, -0.390625 },
            width = 402
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e14-socle-glow.png",
            height = 201,
            shift = { 0.109375, -0.390625 },
            width = 201
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e14-socle-light.png",
            height = 474,
            shift = { 0.1875, 0.203125 },
            width = 468
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e14-socle-light.png",
            height = 237,
            shift = { 0.1875, 0.203125 },
            width = 234
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e14-socle-main.png",
            height = 422,
            shift = { 0.015625, -0.234375 },
            width = 414
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e14-socle-main.png",
            height = 211,
            shift = { 0.015625, -0.234375 },
            width = 207
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e14-socle-shadow.png",
            height = 390,
            shift = { 0.390625, -0.078125 },
            width = 438
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e14-socle-shadow.png",
            height = 195,
            shift = { 0.390625, -0.078125 },
            width = 219
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e14-tete-glow.png",
            height = 358,
            line_length = 1,
            shift = { 0, -1.421875 },
            width = 484
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e14-tete-glow.png",
            height = 179,
            line_length = 1,
            shift = { 0, -1.421875 },
            width = 242
          }
        },
        main = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e14-tete-main.png",
            height = 358,
            line_length = 1,
            shift = { 0, -1.421875 },
            width = 484
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e14-tete-main.png",
            height = 179,
            line_length = 1,
            shift = { 0, -1.421875 },
            width = 242
          }
        },
        shadow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e14-tete-shadow.png",
            height = 344,
            line_length = 1,
            shift = { 1.8125, 0 },
            width = 504
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e14-tete-shadow.png",
            height = 172,
            line_length = 1,
            shift = { 1.8125, 0 },
            width = 252
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.41406 },
        projectile_creation_distance = 4.19314
      }
    },
    [15] = {
      boite = { { -4.09375, -4.4375 }, { 4.09375, 3.40625 } },
      bouches = {
        E = { 4.0625, -1.41406 },
        N = { 0, -4.40625 },
        O = { -4.0625, -1.41406 },
        S = { 0, 1.57812 }
      },
      ecart_max = 0.1459,
      ecarts_bouche = {
        E = { 0.1032, 0 },
        N = { -0.1459, 0 },
        O = { 0.1032, 0 },
        S = { -0.1459, 0 }
      },
      eclat_visible = {
        E = { 4.5046, -1.41406 },
        N = { 0, -4.59926 },
        O = { -4.5046, -1.41406 },
        S = { 0, 1.77114 }
      },
      icone = {
        filename = "__factorio-overhaul__/graphics/levels/gun/gun-e15-icone.png",
        icon_mipmaps = 4,
        icon_size = 64
      },
      piece = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e15-piece-glow.png",
            height = 54,
            shift = { 0.015625, 2.796875 },
            width = 198
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e15-piece-glow.png",
            height = 27,
            shift = { 0.015625, 2.796875 },
            width = 99
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e15-piece-light.png",
            height = 138,
            shift = { 0, 2.890625 },
            width = 344
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e15-piece-light.png",
            height = 69,
            shift = { 0, 2.890625 },
            width = 172
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e15-piece-main.png",
            height = 66,
            shift = { 0, 2.890625 },
            width = 232
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e15-piece-main.png",
            height = 33,
            shift = { 0, 2.890625 },
            width = 116
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e15-piece-shadow.png",
            height = 36,
            shift = { 0.25, 2.96875 },
            width = 232
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e15-piece-shadow.png",
            height = 18,
            shift = { 0.25, 2.96875 },
            width = 116
          }
        }
      },
      socle = {
        glow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e15-socle-glow.png",
            height = 382,
            shift = { 0, -0.234375 },
            width = 384
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e15-socle-glow.png",
            height = 191,
            shift = { 0, -0.234375 },
            width = 192
          }
        },
        light = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e15-socle-light.png",
            height = 342,
            shift = { 0.84375, 1.203125 },
            width = 392
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e15-socle-light.png",
            height = 171,
            shift = { 0.84375, 1.203125 },
            width = 196
          }
        },
        main = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e15-socle-main.png",
            height = 408,
            shift = { 0, -0.0625 },
            width = 420
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e15-socle-main.png",
            height = 204,
            shift = { 0, -0.0625 },
            width = 210
          }
        },
        shadow = {
          hr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e15-socle-shadow.png",
            height = 374,
            shift = { 0.5625, 0.046875 },
            width = 448
          },
          lr = {
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e15-socle-shadow.png",
            height = 187,
            shift = { 0.5625, 0.046875 },
            width = 224
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e15-tete-glow.png",
            height = 386,
            line_length = 1,
            shift = { 0, -1.421875 },
            width = 524
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e15-tete-glow.png",
            height = 193,
            line_length = 1,
            shift = { 0, -1.421875 },
            width = 262
          }
        },
        main = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e15-tete-main.png",
            height = 386,
            line_length = 1,
            shift = { 0, -1.421875 },
            width = 524
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e15-tete-main.png",
            height = 193,
            line_length = 1,
            shift = { 0, -1.421875 },
            width = 262
          }
        },
        shadow = {
          hr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e15-tete-shadow.png",
            height = 372,
            line_length = 1,
            shift = { 1.796875, 0 },
            width = 542
          },
          lr = {
            direction_count = 4,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e15-tete-shadow.png",
            height = 186,
            line_length = 1,
            shift = { 1.796875, 0 },
            width = 271
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.41406 },
        projectile_creation_distance = 4.5046
      }
    }
  },
  directions = { "N", "E", "S", "O" },
  eclat = {
    hauteur = 1,
    k_proj = 0.7071,
    marge = 0.33892,
    seuil = 0.5,
    tol_canon_px = 24
  },
  vanille = {
    bouches = {
      E = { 1, -1.03906 },
      N = { 0, -1.84375 },
      O = { -1, -1.03906 },
      S = { 0, 0.10938 }
    },
    ecarts_bouche = {
      E = { 0.0548, 0.0484 },
      N = { -0.1097, 0 },
      O = { 0.0548, -0.0484 },
      S = { -0.5503, 0 }
    },
    projectile_center = { 0, -0.0875 },
    projectile_creation_distance = 1.39375
  }
}
