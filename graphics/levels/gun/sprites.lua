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
      eclat = {
        lr = {
          direction_count = 64,
          filename = "__factorio-overhaul__/graphics/levels/gun/gun-e02-eclat.png",
          frame_count = 1,
          height = 124,
          line_length = 8,
          shift = { 0, -0.625 },
          width = 148
        }
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
      boite = { { -1.40625, -1.625 }, { 1.40625, 1.21875 } },
      bouches = {
        d00 = { 0, -1.51562 },
        d01 = { 0.12776, -1.50816 },
        d02 = { 0.26061, -1.49851 },
        d03 = { 0.38077, -1.47365 },
        d04 = { 0.51147, -1.4429 },
        d05 = { 0.61778, -1.40393 },
        d06 = { 0.73365, -1.34951 },
        d07 = { 0.83475, -1.29254 },
        d08 = { 0.91474, -1.23429 },
        d09 = { 1.00521, -1.15933 },
        d10 = { 1.06802, -1.08609 },
        d11 = { 1.12865, -1.00852 },
        d12 = { 1.17395, -0.92749 },
        d13 = { 1.2128, -0.83688 },
        d14 = { 1.22977, -0.75769 },
        d15 = { 1.24058, -0.66779 },
        d16 = { 1.23438, -0.57812 },
        d17 = { 1.2415, -0.49509 },
        d18 = { 1.23168, -0.40534 },
        d19 = { 1.21051, -0.32185 },
        d20 = { 1.17854, -0.23661 },
        d21 = { 1.13017, -0.14974 },
        d22 = { 1.0721, -0.07448 },
        d23 = { 0.99729, 0.00317 },
        d24 = { 0.92903, 0.06565 },
        d25 = { 0.83504, 0.13613 },
        d26 = { 0.73305, 0.19354 },
        d27 = { 0.62361, 0.24253 },
        d28 = { 0.50144, 0.28501 },
        d29 = { 0.38635, 0.3162 },
        d30 = { 0.25474, 0.34198 },
        d31 = { 0.12704, 0.35196 },
        d32 = { 0, 0.35938 },
        d33 = { -0.12377, 0.35382 },
        d34 = { -0.25328, 0.33877 },
        d35 = { -0.38444, 0.31829 },
        d36 = { -0.5067, 0.28481 },
        d37 = { -0.62446, 0.24135 },
        d38 = { -0.7309, 0.19369 },
        d39 = { -0.82953, 0.1373 },
        d40 = { -0.92236, 0.06578 },
        d41 = { -1.00667, -0.00034 },
        d42 = { -1.07365, -0.07521 },
        d43 = { -1.12896, -0.15343 },
        d44 = { -1.17705, -0.23635 },
        d45 = { -1.20853, -0.31986 },
        d46 = { -1.23179, -0.40574 },
        d47 = { -1.23819, -0.49473 },
        d48 = { -1.23438, -0.57812 },
        d49 = { -1.23892, -0.66409 },
        d50 = { -1.23109, -0.753 },
        d51 = { -1.20775, -0.8382 },
        d52 = { -1.17498, -0.92344 },
        d53 = { -1.13117, -1.00519 },
        d54 = { -1.0717, -1.0831 },
        d55 = { -1.00163, -1.16025 },
        d56 = { -0.92613, -1.22719 },
        d57 = { -0.83238, -1.29643 },
        d58 = { -0.7315, -1.34966 },
        d59 = { -0.621, -1.40186 },
        d60 = { -0.50983, -1.44243 },
        d61 = { -0.38363, -1.47639 },
        d62 = { -0.25467, -1.50154 },
        d63 = { -0.12877, -1.51027 }
      },
      ecart_max = 0.1044,
      ecarts_bouche = {
        d00 = { -0.0887, 0 },
        d01 = { -0.0843, -0.0016 },
        d02 = { -0.0855, 0.002 },
        d03 = { -0.0755, -0.0026 },
        d04 = { -0.0722, 0.005 },
        d05 = { -0.0576, -0.0043 },
        d06 = { -0.0454, 0.0044 },
        d07 = { -0.0319, 0.0047 },
        d08 = { -0.0109, -0.0065 },
        d09 = { 0, 0.0031 },
        d10 = { 0.0218, -0.0017 },
        d11 = { 0.0354, -0.0022 },
        d12 = { 0.0517, -0.0039 },
        d13 = { 0.0632, 0.0028 },
        d14 = { 0.0801, -0.0051 },
        d15 = { 0.091, -0.0018 },
        d16 = { 0.1044, 0.0014 },
        d17 = { 0.0903, -0.002 },
        d18 = { 0.0787, 0.001 },
        d19 = { 0.0654, -0.0019 },
        d20 = { 0.0487, -0.0021 },
        d21 = { 0.0336, 0.0025 },
        d22 = { 0.0187, -0.0013 },
        d23 = { 0.0054, 0.0035 },
        d24 = { -0.0171, -0.0096 },
        d25 = { -0.0338, -0.0029 },
        d26 = { -0.0473, -0.0018 },
        d27 = { -0.0593, -0.0017 },
        d28 = { -0.0682, 0.0043 },
        d29 = { -0.0792, -0.0019 },
        d30 = { -0.0864, 0.0043 },
        d31 = { -0.0871, 0.0027 },
        d32 = { -0.0916, 0 },
        d33 = { -0.0885, -0.0062 },
        d34 = { -0.0829, -0.0049 },
        d35 = { -0.0804, -0.0007 },
        d36 = { -0.0707, 0.0003 },
        d37 = { -0.0589, 0.0031 },
        d38 = { -0.0459, 0.0002 },
        d39 = { -0.0304, -0.0016 },
        d40 = { -0.0117, 0.0056 },
        d41 = { -0.0009, 0.0043 },
        d42 = { 0.0176, 0.0026 },
        d43 = { 0.0361, 0.0005 },
        d44 = { 0.0501, 0.0015 },
        d45 = { 0.0669, -0.0005 },
        d46 = { 0.0787, -0.0006 },
        d47 = { 0.0936, 0.0014 },
        d48 = { 0.1044, -0.0014 },
        d49 = { 0.0929, -0.0017 },
        d50 = { 0.0794, 0.0003 },
        d51 = { 0.0679, -0.0004 },
        d52 = { 0.0519, -0.0003 },
        d53 = { 0.0342, -0.0018 },
        d54 = { 0.0197, -0.0025 },
        d55 = { 0.0027, -0.0005 },
        d56 = { -0.0161, -0.0059 },
        d57 = { -0.0326, -0.0002 },
        d58 = { -0.044, -0.0028 },
        d59 = { -0.0579, 0.0005 },
        d60 = { -0.071, -0.0038 },
        d61 = { -0.0791, 0.001 },
        d62 = { -0.0868, 0.0045 },
        d63 = { -0.0865, 0.0009 }
      },
      eclat = {
        lr = {
          direction_count = 64,
          filename = "__factorio-overhaul__/graphics/levels/gun/gun-e03-eclat.png",
          frame_count = 1,
          height = 130,
          line_length = 8,
          shift = { 0.015625, -0.5625 },
          width = 155
        }
      },
      eclat_visible = {
        d00 = { 0, -1.76583 },
        d01 = { 0.16444, -1.76011 },
        d02 = { 0.32729, -1.74303 },
        d03 = { 0.48699, -1.71475 },
        d04 = { 0.642, -1.67553 },
        d05 = { 0.79083, -1.62576 },
        d06 = { 0.93205, -1.56591 },
        d07 = { 1.06428, -1.49656 },
        d08 = { 1.18627, -1.41838 },
        d09 = { 1.29684, -1.33212 },
        d10 = { 1.39491, -1.23862 },
        d11 = { 1.47955, -1.13877 },
        d12 = { 1.54994, -1.03353 },
        d13 = { 1.60541, -0.92392 },
        d14 = { 1.64541, -0.81099 },
        d15 = { 1.66957, -0.69584 },
        d16 = { 1.67765, -0.57956 },
        d17 = { 1.66957, -0.46328 },
        d18 = { 1.64541, -0.34813 },
        d19 = { 1.60541, -0.2352 },
        d20 = { 1.54994, -0.12559 },
        d21 = { 1.47955, -0.02035 },
        d22 = { 1.39491, 0.0795 },
        d23 = { 1.29684, 0.173 },
        d24 = { 1.18627, 0.25926 },
        d25 = { 1.06428, 0.33744 },
        d26 = { 0.93205, 0.40679 },
        d27 = { 0.79083, 0.46664 },
        d28 = { 0.642, 0.51641 },
        d29 = { 0.48699, 0.55563 },
        d30 = { 0.32729, 0.58391 },
        d31 = { 0.16444, 0.60099 },
        d32 = { 0, 0.60671 },
        d33 = { -0.16444, 0.60099 },
        d34 = { -0.32729, 0.58391 },
        d35 = { -0.48699, 0.55563 },
        d36 = { -0.642, 0.51641 },
        d37 = { -0.79083, 0.46664 },
        d38 = { -0.93205, 0.40679 },
        d39 = { -1.06428, 0.33744 },
        d40 = { -1.18627, 0.25926 },
        d41 = { -1.29684, 0.173 },
        d42 = { -1.39491, 0.0795 },
        d43 = { -1.47955, -0.02035 },
        d44 = { -1.54994, -0.12559 },
        d45 = { -1.60541, -0.2352 },
        d46 = { -1.64541, -0.34813 },
        d47 = { -1.66957, -0.46328 },
        d48 = { -1.67765, -0.57956 },
        d49 = { -1.66957, -0.69584 },
        d50 = { -1.64541, -0.81099 },
        d51 = { -1.60541, -0.92392 },
        d52 = { -1.54994, -1.03353 },
        d53 = { -1.47955, -1.13877 },
        d54 = { -1.39491, -1.23862 },
        d55 = { -1.29684, -1.33212 },
        d56 = { -1.18627, -1.41838 },
        d57 = { -1.06428, -1.49656 },
        d58 = { -0.93205, -1.56591 },
        d59 = { -0.79083, -1.62576 },
        d60 = { -0.642, -1.67553 },
        d61 = { -0.48699, -1.71475 },
        d62 = { -0.32729, -1.74303 },
        d63 = { -0.16444, -1.76011 }
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
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e03-tete-glow.png",
            height = 134,
            line_length = 8,
            shift = { 0, -0.578125 },
            width = 180
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e03-tete-glow.png",
            height = 67,
            line_length = 8,
            shift = { 0, -0.578125 },
            width = 90
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e03-tete-main.png",
            height = 134,
            line_length = 8,
            shift = { 0, -0.578125 },
            width = 180
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e03-tete-main.png",
            height = 67,
            line_length = 8,
            shift = { 0, -0.578125 },
            width = 90
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e03-tete-shadow.png",
            height = 128,
            line_length = 8,
            shift = { 0.75, 0 },
            width = 188
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e03-tete-shadow.png",
            height = 64,
            line_length = 8,
            shift = { 0.75, 0 },
            width = 94
          }
        }
      },
      tir = {
        projectile_center = { 0, 0.42044 },
        projectile_creation_distance = 1.67765
      }
    },
    [4] = {
      boite = { { -2.1875, -2.4375 }, { 2.1875, 1.6875 } },
      bouches = {
        d00 = { 0, -2.25 },
        d01 = { 0.1984, -2.23688 },
        d02 = { 0.39657, -2.21791 },
        d03 = { 0.59412, -2.18183 },
        d04 = { 0.77418, -2.1322 },
        d05 = { 0.9483, -2.069 },
        d06 = { 1.11806, -1.99024 },
        d07 = { 1.26715, -1.90488 },
        d08 = { 1.40672, -1.8038 },
        d09 = { 1.52402, -1.69998 },
        d10 = { 1.62998, -1.58529 },
        d11 = { 1.7205, -1.46188 },
        d12 = { 1.7859, -1.33621 },
        d13 = { 1.834, -1.21033 },
        d14 = { 1.86511, -1.07947 },
        d15 = { 1.8782, -0.94296 },
        d16 = { 1.85938, -0.8125 },
        d17 = { 1.87876, -0.68608 },
        d18 = { 1.86658, -0.55424 },
        d19 = { 1.83516, -0.41736 },
        d20 = { 1.78498, -0.28723 },
        d21 = { 1.71642, -0.16278 },
        d22 = { 1.63189, -0.04173 },
        d23 = { 1.52347, 0.07437 },
        d24 = { 1.40411, 0.1797 },
        d25 = { 1.26079, 0.28106 },
        d26 = { 1.11191, 0.36814 },
        d27 = { 0.94399, 0.44268 },
        d28 = { 0.77017, 0.50609 },
        d29 = { 0.5896, 0.55501 },
        d30 = { 0.40137, 0.59224 },
        d31 = { 0.19529, 0.61155 },
        d32 = { 0, 0.60938 },
        d33 = { -0.19595, 0.61151 },
        d34 = { -0.39713, 0.59284 },
        d35 = { -0.58875, 0.55519 },
        d36 = { -0.77367, 0.50506 },
        d37 = { -0.95196, 0.43966 },
        d38 = { -1.1137, 0.36729 },
        d39 = { -1.27235, 0.27435 },
        d40 = { -1.40503, 0.17905 },
        d41 = { -1.52436, 0.0736 },
        d42 = { -1.63084, -0.04107 },
        d43 = { -1.71786, -0.16215 },
        d44 = { -1.78825, -0.29281 },
        d45 = { -1.83537, -0.41787 },
        d46 = { -1.86615, -0.55273 },
        d47 = { -1.87849, -0.68412 },
        d48 = { -1.85938, -0.8125 },
        d49 = { -1.8785, -0.94078 },
        d50 = { -1.86586, -1.08115 },
        d51 = { -1.83422, -1.20982 },
        d52 = { -1.78616, -1.33575 },
        d53 = { -1.72045, -1.46195 },
        d54 = { -1.62923, -1.58609 },
        d55 = { -1.52464, -1.69944 },
        d56 = { -1.39968, -1.80878 },
        d57 = { -1.27366, -1.9011 },
        d58 = { -1.11985, -1.98939 },
        d59 = { -0.94622, -2.07083 },
        d60 = { -0.76709, -2.13428 },
        d61 = { -0.59187, -2.18399 },
        d62 = { -0.39233, -2.21851 },
        d63 = { -0.19906, -2.23683 }
      },
      ecart_max = 0.1517,
      ecarts_bouche = {
        d00 = { -0.1137, 0 },
        d01 = { -0.1063, 0.0001 },
        d02 = { -0.1052, 0.0015 },
        d03 = { -0.1003, 0.0066 },
        d04 = { -0.0888, 0.0015 },
        d05 = { -0.0752, -0.0006 },
        d06 = { -0.0611, 0.0045 },
        d07 = { -0.0434, 0.0004 },
        d08 = { -0.0241, 0.0036 },
        d09 = { -0.0017, -0.0017 },
        d10 = { 0.0187, -0.0015 },
        d11 = { 0.0381, 0.0018 },
        d12 = { 0.0626, 0.0004 },
        d13 = { 0.0846, -0.0033 },
        d14 = { 0.1047, -0.0035 },
        d15 = { 0.1228, 0.0014 },
        d16 = { 0.1517, 0.0011 },
        d17 = { 0.1224, -0.0034 },
        d18 = { 0.1041, -0.0032 },
        d19 = { 0.0836, 0.0025 },
        d20 = { 0.0625, 0.0034 },
        d21 = { 0.041, 0.0019 },
        d22 = { 0.0169, 0.0007 },
        d23 = { -0.002, 0.0033 },
        d24 = { -0.0237, 0.0003 },
        d25 = { -0.0407, 0.0063 },
        d26 = { -0.0606, 0.0034 },
        d27 = { -0.0732, 0.0045 },
        d28 = { -0.0877, 0.0025 },
        d29 = { -0.0988, -0.0023 },
        d30 = { -0.1079, -0.0057 },
        d31 = { -0.1077, 0.0032 },
        d32 = { -0.1002, 0 },
        d33 = { -0.1077, -0.0025 },
        d34 = { -0.1073, 0.0014 },
        d35 = { -0.0986, 0.0014 },
        d36 = { -0.0885, 0.0011 },
        d37 = { -0.0756, 0.0037 },
        d38 = { -0.0612, -0.0016 },
        d39 = { -0.0451, 0.0063 },
        d40 = { -0.024, 0.0007 },
        d41 = { -0.0023, -0.0022 },
        d42 = { 0.0176, -0.0018 },
        d43 = { 0.0395, -0.002 },
        d44 = { 0.0609, 0.0029 },
        d45 = { 0.0835, -0.002 },
        d46 = { 0.1043, 0.0016 },
        d47 = { 0.1225, 0.0014 },
        d48 = { 0.1517, -0.0011 },
        d49 = { 0.1226, -0.0036 },
        d50 = { 0.1037, 0.0051 },
        d51 = { 0.0845, 0.0028 },
        d52 = { 0.0625, -0.0009 },
        d53 = { 0.0381, -0.0017 },
        d54 = { 0.0191, 0.0025 },
        d55 = { -0.0019, 0.001 },
        d56 = { -0.0212, 0.0045 },
        d57 = { -0.0458, -0.0075 },
        d58 = { -0.0618, -0.0064 },
        d59 = { -0.0754, 0.0033 },
        d60 = { -0.087, 0.0057 },
        d61 = { -0.1014, -0.0036 },
        d62 = { -0.1046, 0.0028 },
        d63 = { -0.1064, -0.0008 }
      },
      eclat = {
        lr = {
          direction_count = 64,
          filename = "__factorio-overhaul__/graphics/levels/gun/gun-e04-eclat.png",
          frame_count = 1,
          height = 218,
          line_length = 8,
          shift = { 0, -0.8125 },
          width = 258
        }
      },
      eclat_visible = {
        d00 = { 0, -2.47526 },
        d01 = { 0.23034, -2.46726 },
        d02 = { 0.45846, -2.44333 },
        d03 = { 0.68217, -2.40371 },
        d04 = { 0.89931, -2.34877 },
        d05 = { 1.10778, -2.27905 },
        d06 = { 1.30559, -2.19522 },
        d07 = { 1.49083, -2.09808 },
        d08 = { 1.66171, -1.98856 },
        d09 = { 1.81658, -1.86774 },
        d10 = { 1.95396, -1.73676 },
        d11 = { 2.07253, -1.59689 },
        d12 = { 2.17113, -1.44947 },
        d13 = { 2.24883, -1.29593 },
        d14 = { 2.30486, -1.13774 },
        d15 = { 2.3387, -0.97644 },
        d16 = { 2.35002, -0.81356 },
        d17 = { 2.3387, -0.65068 },
        d18 = { 2.30486, -0.48938 },
        d19 = { 2.24883, -0.33119 },
        d20 = { 2.17113, -0.17765 },
        d21 = { 2.07253, -0.03023 },
        d22 = { 1.95396, 0.10964 },
        d23 = { 1.81658, 0.24062 },
        d24 = { 1.66171, 0.36144 },
        d25 = { 1.49083, 0.47096 },
        d26 = { 1.30559, 0.5681 },
        d27 = { 1.10778, 0.65193 },
        d28 = { 0.89931, 0.72165 },
        d29 = { 0.68217, 0.77659 },
        d30 = { 0.45846, 0.81621 },
        d31 = { 0.23034, 0.84014 },
        d32 = { 0, 0.84814 },
        d33 = { -0.23034, 0.84014 },
        d34 = { -0.45846, 0.81621 },
        d35 = { -0.68217, 0.77659 },
        d36 = { -0.89931, 0.72165 },
        d37 = { -1.10778, 0.65193 },
        d38 = { -1.30559, 0.5681 },
        d39 = { -1.49083, 0.47096 },
        d40 = { -1.66171, 0.36144 },
        d41 = { -1.81658, 0.24062 },
        d42 = { -1.95396, 0.10964 },
        d43 = { -2.07253, -0.03023 },
        d44 = { -2.17113, -0.17765 },
        d45 = { -2.24883, -0.33119 },
        d46 = { -2.30486, -0.48938 },
        d47 = { -2.3387, -0.65068 },
        d48 = { -2.35002, -0.81356 },
        d49 = { -2.3387, -0.97644 },
        d50 = { -2.30486, -1.13774 },
        d51 = { -2.24883, -1.29593 },
        d52 = { -2.17113, -1.44947 },
        d53 = { -2.07253, -1.59689 },
        d54 = { -1.95396, -1.73676 },
        d55 = { -1.81658, -1.86774 },
        d56 = { -1.66171, -1.98856 },
        d57 = { -1.49083, -2.09808 },
        d58 = { -1.30559, -2.19522 },
        d59 = { -1.10778, -2.27905 },
        d60 = { -0.89931, -2.34877 },
        d61 = { -0.68217, -2.40371 },
        d62 = { -0.45846, -2.44333 },
        d63 = { -0.23034, -2.46726 }
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
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e04-tete-glow.png",
            height = 208,
            line_length = 8,
            shift = { 0, -0.8125 },
            width = 280
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e04-tete-glow.png",
            height = 104,
            line_length = 8,
            shift = { 0, -0.8125 },
            width = 140
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e04-tete-main.png",
            height = 208,
            line_length = 8,
            shift = { 0, -0.8125 },
            width = 280
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e04-tete-main.png",
            height = 104,
            line_length = 8,
            shift = { 0, -0.8125 },
            width = 140
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e04-tete-shadow.png",
            height = 200,
            line_length = 8,
            shift = { 1.03125, 0 },
            width = 292
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e04-tete-shadow.png",
            height = 100,
            line_length = 8,
            shift = { 1.03125, 0 },
            width = 146
          }
        }
      },
      tir = {
        projectile_center = { 0, 0.18644 },
        projectile_creation_distance = 2.35002
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
      eclat = {
        lr = {
          direction_count = 64,
          filename = "__factorio-overhaul__/graphics/levels/gun/gun-e05-eclat.png",
          frame_count = 1,
          height = 189,
          line_length = 8,
          shift = { 0.015625, -0.796875 },
          width = 229
        }
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
      boite = { { -2.1875, -2.4375 }, { 2.15625, 1.6875 } },
      bouches = {
        d00 = { 0, -2.23438 },
        d01 = { 0.19241, -2.22513 },
        d02 = { 0.39414, -2.20495 },
        d03 = { 0.5757, -2.17015 },
        d04 = { 0.76017, -2.11934 },
        d05 = { 0.9385, -2.05603 },
        d06 = { 1.10513, -1.97746 },
        d07 = { 1.25283, -1.89255 },
        d08 = { 1.38813, -1.79484 },
        d09 = { 1.50578, -1.69441 },
        d10 = { 1.60737, -1.57615 },
        d11 = { 1.70359, -1.45324 },
        d12 = { 1.76917, -1.33257 },
        d13 = { 1.81933, -1.20553 },
        d14 = { 1.8513, -1.07735 },
        d15 = { 1.86163, -0.94198 },
        d16 = { 1.85938, -0.8125 },
        d17 = { 1.86221, -0.68724 },
        d18 = { 1.85036, -0.55213 },
        d19 = { 1.82048, -0.42216 },
        d20 = { 1.76873, -0.29168 },
        d21 = { 1.70355, -0.17422 },
        d22 = { 1.61304, -0.05485 },
        d23 = { 1.50586, 0.06261 },
        d24 = { 1.38567, 0.16835 },
        d25 = { 1.25272, 0.26761 },
        d26 = { 1.10889, 0.35068 },
        d27 = { 0.94017, 0.42554 },
        d28 = { 0.76122, 0.49175 },
        d29 = { 0.5839, 0.54172 },
        d30 = { 0.39014, 0.5749 },
        d31 = { 0.19324, 0.59335 },
        d32 = { 0, 0.60156 },
        d33 = { -0.19394, 0.59711 },
        d34 = { -0.38569, 0.5743 },
        d35 = { -0.58217, 0.53987 },
        d36 = { -0.76491, 0.49106 },
        d37 = { -0.93994, 0.42477 },
        d38 = { -1.10458, 0.35143 },
        d39 = { -1.25225, 0.26509 },
        d40 = { -1.38617, 0.1699 },
        d41 = { -1.50762, 0.0635 },
        d42 = { -1.61235, -0.0523 },
        d43 = { -1.70352, -0.17191 },
        d44 = { -1.77263, -0.29738 },
        d45 = { -1.82088, -0.42572 },
        d46 = { -1.84896, -0.55063 },
        d47 = { -1.86399, -0.68295 },
        d48 = { -1.85938, -0.8125 },
        d49 = { -1.8637, -0.94411 },
        d50 = { -1.84901, -1.0742 },
        d51 = { -1.81972, -1.20196 },
        d52 = { -1.76849, -1.33468 },
        d53 = { -1.70208, -1.455 },
        d54 = { -1.61207, -1.573 },
        d55 = { -1.50716, -1.6889 },
        d56 = { -1.38796, -1.79591 },
        d57 = { -1.25196, -1.89479 },
        d58 = { -1.10082, -1.9782 },
        d59 = { -0.94362, -2.05428 },
        d60 = { -0.76386, -2.11865 },
        d61 = { -0.58625, -2.16567 },
        d62 = { -0.3873, -2.20018 },
        d63 = { -0.19659, -2.22193 }
      },
      ecart_max = 0.1324,
      ecarts_bouche = {
        d00 = { -0.1113, 0 },
        d01 = { -0.1073, -0.0041 },
        d02 = { -0.1056, 0.0027 },
        d03 = { -0.0962, -0.0056 },
        d04 = { -0.0849, -0.0039 },
        d05 = { -0.0737, -0.0003 },
        d06 = { -0.0583, 0.0041 },
        d07 = { -0.0404, 0.0006 },
        d08 = { -0.0202, 0.0005 },
        d09 = { -0.0002, -0.0058 },
        d10 = { 0.0255, -0.0025 },
        d11 = { 0.0389, 0.0043 },
        d12 = { 0.0612, -0.0005 },
        d13 = { 0.0812, -0.0013 },
        d14 = { 0.0995, -0.003 },
        d15 = { 0.1201, 0.0016 },
        d16 = { 0.1324, 0.0014 },
        d17 = { 0.1197, -0.003 },
        d18 = { 0.1007, 0.0015 },
        d19 = { 0.08, 0.0012 },
        d20 = { 0.0606, 0.004 },
        d21 = { 0.0388, -0.0039 },
        d22 = { 0.0217, -0.0028 },
        d23 = { 0.0017, 0.0023 },
        d24 = { -0.019, 0.002 },
        d25 = { -0.0422, 0.0016 },
        d26 = { -0.0617, -0.0061 },
        d27 = { -0.0726, -0.0026 },
        d28 = { -0.0857, 0.0031 },
        d29 = { -0.0989, -0.0021 },
        d30 = { -0.1024, 0.0005 },
        d31 = { -0.1035, 0.0027 },
        d32 = { -0.1064, 0 },
        d33 = { -0.1073, -0.0026 },
        d34 = { -0.1006, -0.0046 },
        d35 = { -0.0965, 0.0013 },
        d36 = { -0.087, 0.0004 },
        d37 = { -0.0719, 0.0029 },
        d38 = { -0.0593, 0.0025 },
        d39 = { -0.0402, 0 },
        d40 = { -0.0203, -0.003 },
        d41 = { -0.0002, -0.0022 },
        d42 = { 0.0212, 0.0002 },
        d43 = { 0.038, 0.0017 },
        d44 = { 0.0585, 0.0025 },
        d45 = { 0.0804, 0.0023 },
        d46 = { 0.1019, -0.0032 },
        d47 = { 0.1176, -0.0012 },
        d48 = { 0.1324, -0.0014 },
        d49 = { 0.1179, 0.0004 },
        d50 = { 0.1023, 0.0002 },
        d51 = { 0.0815, -0.0022 },
        d52 = { 0.0613, 0.0027 },
        d53 = { 0.0397, -0.0021 },
        d54 = { 0.0225, -0.0023 },
        d55 = { 0.0014, 0.0003 },
        d56 = { -0.0207, 0.0005 },
        d57 = { -0.0412, 0.0016 },
        d58 = { -0.0559, -0.0005 },
        d59 = { -0.0754, -0.0048 },
        d60 = { -0.0862, 0.0004 },
        d61 = { -0.0962, -0.0058 },
        d62 = { -0.0992, 0.0026 },
        d63 = { -0.1047, -0.0005 }
      },
      eclat = {
        lr = {
          direction_count = 64,
          filename = "__factorio-overhaul__/graphics/levels/gun/gun-e06-eclat.png",
          frame_count = 1,
          height = 191,
          line_length = 8,
          shift = { 0.015625, -0.796875 },
          width = 231
        }
      },
      eclat_visible = {
        d00 = { 0, -2.46196 },
        d01 = { 0.22845, -2.45402 },
        d02 = { 0.45469, -2.43029 },
        d03 = { 0.67656, -2.391 },
        d04 = { 0.89191, -2.33651 },
        d05 = { 1.09868, -2.26736 },
        d06 = { 1.29486, -2.18422 },
        d07 = { 1.47857, -2.08788 },
        d08 = { 1.64805, -1.97926 },
        d09 = { 1.80165, -1.85943 },
        d10 = { 1.9379, -1.72953 },
        d11 = { 2.05549, -1.59081 },
        d12 = { 2.15328, -1.4446 },
        d13 = { 2.23034, -1.29232 },
        d14 = { 2.28592, -1.13544 },
        d15 = { 2.31948, -0.97546 },
        d16 = { 2.3307, -0.81392 },
        d17 = { 2.31948, -0.65238 },
        d18 = { 2.28592, -0.4924 },
        d19 = { 2.23034, -0.33552 },
        d20 = { 2.15328, -0.18324 },
        d21 = { 2.05549, -0.03703 },
        d22 = { 1.9379, 0.10169 },
        d23 = { 1.80165, 0.23159 },
        d24 = { 1.64805, 0.35142 },
        d25 = { 1.47857, 0.46004 },
        d26 = { 1.29486, 0.55638 },
        d27 = { 1.09868, 0.63952 },
        d28 = { 0.89191, 0.70867 },
        d29 = { 0.67656, 0.76316 },
        d30 = { 0.45469, 0.80245 },
        d31 = { 0.22845, 0.82618 },
        d32 = { 0, 0.83412 },
        d33 = { -0.22845, 0.82618 },
        d34 = { -0.45469, 0.80245 },
        d35 = { -0.67656, 0.76316 },
        d36 = { -0.89191, 0.70867 },
        d37 = { -1.09868, 0.63952 },
        d38 = { -1.29486, 0.55638 },
        d39 = { -1.47857, 0.46004 },
        d40 = { -1.64805, 0.35142 },
        d41 = { -1.80165, 0.23159 },
        d42 = { -1.9379, 0.10169 },
        d43 = { -2.05549, -0.03703 },
        d44 = { -2.15328, -0.18324 },
        d45 = { -2.23034, -0.33552 },
        d46 = { -2.28592, -0.4924 },
        d47 = { -2.31948, -0.65238 },
        d48 = { -2.3307, -0.81392 },
        d49 = { -2.31948, -0.97546 },
        d50 = { -2.28592, -1.13544 },
        d51 = { -2.23034, -1.29232 },
        d52 = { -2.15328, -1.4446 },
        d53 = { -2.05549, -1.59081 },
        d54 = { -1.9379, -1.72953 },
        d55 = { -1.80165, -1.85943 },
        d56 = { -1.64805, -1.97926 },
        d57 = { -1.47857, -2.08788 },
        d58 = { -1.29486, -2.18422 },
        d59 = { -1.09868, -2.26736 },
        d60 = { -0.89191, -2.33651 },
        d61 = { -0.67656, -2.391 },
        d62 = { -0.45469, -2.43029 },
        d63 = { -0.22845, -2.45402 }
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
      socle_anime = {
        glow = {
          hr = {
            animation_speed = 0.166667,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e06-socle-anime-glow.png",
            frame_count = 16,
            height = 206,
            line_length = 4,
            shift = { -0.03125, -0.171875 },
            width = 204
          },
          lr = {
            animation_speed = 0.166667,
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e06-socle-anime-glow.png",
            frame_count = 16,
            height = 103,
            line_length = 4,
            shift = { -0.03125, -0.171875 },
            width = 102
          }
        },
        light = {
          hr = {
            animation_speed = 0.166667,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gune-e06-socle-anime-light.png",
            frame_count = 16,
            height = 280,
            line_length = 4,
            shift = { 0.453125, -0.125 },
            width = 246
          },
          lr = {
            animation_speed = 0.166667,
            filename = "__factorio-overhaul__/graphics/levels/gun/gune-e06-socle-anime-light.png",
            frame_count = 16,
            height = 140,
            line_length = 4,
            shift = { 0.453125, -0.125 },
            width = 123
          }
        }
      },
      tete = {
        glow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e06-tete-glow.png",
            height = 208,
            line_length = 8,
            shift = { -0.015625, -0.8125 },
            width = 278
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e06-tete-glow.png",
            height = 104,
            line_length = 8,
            shift = { -0.015625, -0.8125 },
            width = 139
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e06-tete-main.png",
            height = 208,
            line_length = 8,
            shift = { -0.015625, -0.8125 },
            width = 278
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e06-tete-main.png",
            height = 104,
            line_length = 8,
            shift = { -0.015625, -0.8125 },
            width = 139
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e06-tete-shadow.png",
            height = 196,
            line_length = 8,
            shift = { 1.03125, 0 },
            width = 288
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e06-tete-shadow.png",
            height = 98,
            line_length = 8,
            shift = { 1.03125, 0 },
            width = 144
          }
        }
      },
      tir = {
        projectile_center = { 0, 0.18608 },
        projectile_creation_distance = 2.3307
      }
    },
    [7] = {
      boite = { { -3.21875, -3.34375 }, { 3.21875, 2.1875 } },
      bouches = {
        d00 = { 0, -3.125 },
        d01 = { 0.27883, -3.11844 },
        d02 = { 0.55855, -3.08979 },
        d03 = { 0.8365, -3.04397 },
        d04 = { 1.10604, -2.9743 },
        d05 = { 1.36862, -2.89113 },
        d06 = { 1.6165, -2.78896 },
        d07 = { 1.85221, -2.66822 },
        d08 = { 2.07691, -2.5243 },
        d09 = { 2.29003, -2.35398 },
        d10 = { 2.4583, -2.18983 },
        d11 = { 2.60382, -2.01793 },
        d12 = { 2.72669, -1.8302 },
        d13 = { 2.81974, -1.63938 },
        d14 = { 2.88808, -1.44222 },
        d15 = { 2.92501, -1.24314 },
        d16 = { 2.9375, -1.03125 },
        d17 = { 2.92442, -0.83079 },
        d18 = { 2.88198, -0.62205 },
        d19 = { 2.81285, -0.42269 },
        d20 = { 2.71734, -0.23196 },
        d21 = { 2.59097, -0.04068 },
        d22 = { 2.4332, 0.13827 },
        d23 = { 2.25989, 0.30074 },
        d24 = { 2.06642, 0.45359 },
        d25 = { 1.83486, 0.60016 },
        d26 = { 1.60391, 0.71678 },
        d27 = { 1.35323, 0.81882 },
        d28 = { 1.09631, 0.8935 },
        d29 = { 0.82103, 0.96916 },
        d30 = { 0.56532, 1.004 },
        d31 = { 0.27132, 1.04084 },
        d32 = { 0, 1.04688 },
        d33 = { -0.27314, 1.04072 },
        d34 = { -0.55929, 1.00485 },
        d35 = { -0.81997, 0.96939 },
        d36 = { -1.09058, 0.89518 },
        d37 = { -1.35417, 0.81847 },
        d38 = { -1.60372, 0.71687 },
        d39 = { -1.83932, 0.59758 },
        d40 = { -2.05901, 0.45883 },
        d41 = { -2.25841, 0.30201 },
        d42 = { -2.43337, 0.1381 },
        d43 = { -2.58995, -0.04185 },
        d44 = { -2.71285, -0.22431 },
        d45 = { -2.81448, -0.42648 },
        d46 = { -2.88206, -0.62232 },
        d47 = { -2.92465, -0.83245 },
        d48 = { -2.9375, -1.03125 },
        d49 = { -2.92524, -1.24148 },
        d50 = { -2.88816, -1.44194 },
        d51 = { -2.82027, -1.63814 },
        d52 = { -2.72473, -1.83355 },
        d53 = { -2.60576, -2.01788 },
        d54 = { -2.45847, -2.18965 },
        d55 = { -2.28854, -2.35525 },
        d56 = { -2.07569, -2.52516 },
        d57 = { -1.84658, -2.67149 },
        d58 = { -1.61632, -2.78904 },
        d59 = { -1.36957, -2.89077 },
        d60 = { -1.10674, -2.97639 },
        d61 = { -0.83543, -3.0442 },
        d62 = { -0.56034, -3.08282 },
        d63 = { -0.28065, -3.11832 }
      },
      ecart_max = 0.0748,
      ecarts_bouche = {
        d00 = { -0.0732, 0 },
        d01 = { -0.0739, -0.0114 },
        d02 = { -0.068, -0.019 },
        d03 = { -0.0619, -0.0236 },
        d04 = { -0.0488, -0.0263 },
        d05 = { -0.0403, -0.0279 },
        d06 = { -0.0288, -0.0303 },
        d07 = { -0.018, -0.0289 },
        d08 = { -0.0088, -0.0175 },
        d09 = { -0.0035, 0.0079 },
        d10 = { 0.0094, 0.0053 },
        d11 = { 0.0197, 0.0004 },
        d12 = { 0.0289, 0.0025 },
        d13 = { 0.0388, -0.0003 },
        d14 = { 0.0451, -0.0018 },
        d15 = { 0.0533, -0.0052 },
        d16 = { 0.0563, 0.003 },
        d17 = { 0.0543, -0.0002 },
        d18 = { 0.0506, 0.0068 },
        d19 = { 0.0442, 0.008 },
        d20 = { 0.0361, 0.0061 },
        d21 = { 0.0283, 0.0133 },
        d22 = { 0.0249, 0.0207 },
        d23 = { 0.015, 0.0203 },
        d24 = { 0.001, 0.0217 },
        d25 = { -0.0051, 0.0405 },
        d26 = { -0.0174, 0.0368 },
        d27 = { -0.0279, 0.0379 },
        d28 = { -0.0332, 0.0284 },
        d29 = { -0.0499, 0.0353 },
        d30 = { -0.0531, 0.0077 },
        d31 = { -0.0637, 0.0175 },
        d32 = { -0.0635, 0 },
        d33 = { -0.0639, -0.0157 },
        d34 = { -0.0523, -0.0138 },
        d35 = { -0.0497, -0.0364 },
        d36 = { -0.0318, -0.0342 },
        d37 = { -0.0282, -0.0369 },
        d38 = { -0.0173, -0.037 },
        d39 = { -0.0067, -0.0356 },
        d40 = { 0.0041, -0.0303 },
        d41 = { 0.0156, -0.0222 },
        d42 = { 0.0249, -0.0204 },
        d43 = { 0.0296, -0.0126 },
        d44 = { 0.0383, -0.0147 },
        d45 = { 0.0434, -0.0039 },
        d46 = { 0.0506, -0.0065 },
        d47 = { 0.0541, 0.0019 },
        d48 = { 0.0563, -0.003 },
        d49 = { 0.0532, 0.0035 },
        d50 = { 0.0451, 0.0015 },
        d51 = { 0.0386, -0.001 },
        d52 = { 0.0299, 0.0012 },
        d53 = { 0.0179, -0.0011 },
        d54 = { 0.0094, -0.0055 },
        d55 = { -0.0028, -0.0061 },
        d56 = { -0.0083, 0.0189 },
        d57 = { -0.0158, 0.035 },
        d58 = { -0.0287, 0.0305 },
        d59 = { -0.0406, 0.027 },
        d60 = { -0.0509, 0.0267 },
        d61 = { -0.0617, 0.0247 },
        d62 = { -0.0618, 0.0153 },
        d63 = { -0.074, 0.0095 }
      },
      eclat = {
        lr = {
          direction_count = 64,
          filename = "__factorio-overhaul__/graphics/levels/gun/gun-e07-eclat.png",
          frame_count = 1,
          height = 232,
          line_length = 8,
          shift = { 0.015625, -1.03125 },
          width = 295
        }
      },
      eclat_visible = {
        d00 = { 0, -3.39076 },
        d01 = { 0.32666, -3.37941 },
        d02 = { 0.65017, -3.34548 },
        d03 = { 0.96742, -3.28929 },
        d04 = { 1.27535, -3.21138 },
        d05 = { 1.571, -3.11251 },
        d06 = { 1.85153, -2.99362 },
        d07 = { 2.11422, -2.85586 },
        d08 = { 2.35655, -2.70055 },
        d09 = { 2.57619, -2.5292 },
        d10 = { 2.77101, -2.34345 },
        d11 = { 2.93916, -2.14509 },
        d12 = { 3.07899, -1.93604 },
        d13 = { 3.18917, -1.71829 },
        d14 = { 3.26864, -1.49396 },
        d15 = { 3.31663, -1.2652 },
        d16 = { 3.33268, -1.03422 },
        d17 = { 3.31663, -0.80324 },
        d18 = { 3.26864, -0.57448 },
        d19 = { 3.18917, -0.35015 },
        d20 = { 3.07899, -0.1324 },
        d21 = { 2.93916, 0.07665 },
        d22 = { 2.77101, 0.27501 },
        d23 = { 2.57619, 0.46076 },
        d24 = { 2.35655, 0.63211 },
        d25 = { 2.11422, 0.78742 },
        d26 = { 1.85153, 0.92518 },
        d27 = { 1.571, 1.04407 },
        d28 = { 1.27535, 1.14294 },
        d29 = { 0.96742, 1.22085 },
        d30 = { 0.65017, 1.27704 },
        d31 = { 0.32666, 1.31097 },
        d32 = { 0, 1.32232 },
        d33 = { -0.32666, 1.31097 },
        d34 = { -0.65017, 1.27704 },
        d35 = { -0.96742, 1.22085 },
        d36 = { -1.27535, 1.14294 },
        d37 = { -1.571, 1.04407 },
        d38 = { -1.85153, 0.92518 },
        d39 = { -2.11422, 0.78742 },
        d40 = { -2.35655, 0.63211 },
        d41 = { -2.57619, 0.46076 },
        d42 = { -2.77101, 0.27501 },
        d43 = { -2.93916, 0.07665 },
        d44 = { -3.07899, -0.1324 },
        d45 = { -3.18917, -0.35015 },
        d46 = { -3.26864, -0.57448 },
        d47 = { -3.31663, -0.80324 },
        d48 = { -3.33268, -1.03422 },
        d49 = { -3.31663, -1.2652 },
        d50 = { -3.26864, -1.49396 },
        d51 = { -3.18917, -1.71829 },
        d52 = { -3.07899, -1.93604 },
        d53 = { -2.93916, -2.14509 },
        d54 = { -2.77101, -2.34345 },
        d55 = { -2.57619, -2.5292 },
        d56 = { -2.35655, -2.70055 },
        d57 = { -2.11422, -2.85586 },
        d58 = { -1.85153, -2.99362 },
        d59 = { -1.571, -3.11251 },
        d60 = { -1.27535, -3.21138 },
        d61 = { -0.96742, -3.28929 },
        d62 = { -0.65017, -3.34548 },
        d63 = { -0.32666, -3.37941 }
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
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e07-tete-glow.png",
            height = 294,
            line_length = 8,
            shift = { 0, -1.046875 },
            width = 412
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e07-tete-glow.png",
            height = 147,
            line_length = 8,
            shift = { 0, -1.046875 },
            width = 206
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e07-tete-main.png",
            height = 294,
            line_length = 8,
            shift = { 0, -1.046875 },
            width = 412
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e07-tete-main.png",
            height = 147,
            line_length = 8,
            shift = { 0, -1.046875 },
            width = 206
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e07-tete-shadow.png",
            height = 292,
            line_length = 8,
            shift = { 1.3125, 0 },
            width = 412
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e07-tete-shadow.png",
            height = 146,
            line_length = 8,
            shift = { 1.3125, 0 },
            width = 206
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.03422 },
        projectile_creation_distance = 3.33268
      }
    },
    [8] = {
      boite = { { -2.90625, -3.1875 }, { 2.90625, 2.15625 } },
      bouches = {
        d00 = { 0, -2.95312 },
        d01 = { 0.25905, -2.94795 },
        d02 = { 0.5348, -2.92028 },
        d03 = { 0.78573, -2.87347 },
        d04 = { 1.03124, -2.80619 },
        d05 = { 1.26903, -2.72109 },
        d06 = { 1.49433, -2.61506 },
        d07 = { 1.69964, -2.49903 },
        d08 = { 1.87646, -2.37341 },
        d09 = { 2.04483, -2.22327 },
        d10 = { 2.18637, -2.06787 },
        d11 = { 2.29898, -1.91453 },
        d12 = { 2.39398, -1.74696 },
        d13 = { 2.46323, -1.56766 },
        d14 = { 2.50669, -1.38858 },
        d15 = { 2.52221, -1.21692 },
        d16 = { 2.51562, -1.03906 },
        d17 = { 2.52248, -0.86313 },
        d18 = { 2.50751, -0.69248 },
        d19 = { 2.46457, -0.51359 },
        d20 = { 2.39883, -0.33946 },
        d21 = { 2.29854, -0.16302 },
        d22 = { 2.18431, -0.00808 },
        d23 = { 2.0406, 0.14879 },
        d24 = { 1.88618, 0.28613 },
        d25 = { 1.70151, 0.41982 },
        d26 = { 1.48937, 0.53928 },
        d27 = { 1.26847, 0.64318 },
        d28 = { 1.03508, 0.72505 },
        d29 = { 0.79067, 0.79429 },
        d30 = { 0.52722, 0.84212 },
        d31 = { 0.26955, 0.86909 },
        d32 = { 0, 0.875 },
        d33 = { -0.25883, 0.86984 },
        d34 = { -0.52472, 0.84247 },
        d35 = { -0.7896, 0.79452 },
        d36 = { -1.03392, 0.72539 },
        d37 = { -1.27118, 0.64215 },
        d38 = { -1.4979, 0.53525 },
        d39 = { -1.69834, 0.42166 },
        d40 = { -1.87933, 0.29097 },
        d41 = { -2.04098, 0.14846 },
        d42 = { -2.18622, -0.0101 },
        d43 = { -2.30235, -0.16805 },
        d44 = { -2.39656, -0.33558 },
        d45 = { -2.46332, -0.51068 },
        d46 = { -2.50658, -0.68917 },
        d47 = { -2.52227, -0.8616 },
        d48 = { -2.51562, -1.03906 },
        d49 = { -2.52228, -1.21646 },
        d50 = { -2.50694, -1.38766 },
        d51 = { -2.46199, -1.57056 },
        d52 = { -2.3979, -1.74255 },
        d53 = { -2.30279, -1.9095 },
        d54 = { -2.18076, -2.0738 },
        d55 = { -2.04522, -2.22293 },
        d56 = { -1.88847, -2.36492 },
        d57 = { -1.69142, -2.50379 },
        d58 = { -1.49236, -2.616 },
        d59 = { -1.27175, -2.72006 },
        d60 = { -1.03489, -2.80418 },
        d61 = { -0.78467, -2.8737 },
        d62 = { -0.52384, -2.92182 },
        d63 = { -0.26595, -2.94747 }
      },
      ecart_max = 0.1638,
      ecarts_bouche = {
        d00 = { -0.1182, 0 },
        d01 = { -0.1203, -0.0067 },
        d02 = { -0.1197, 0.0055 },
        d03 = { -0.1117, -0.0009 },
        d04 = { -0.0993, -0.0031 },
        d05 = { -0.0861, -0.0017 },
        d06 = { -0.0688, 0.004 },
        d07 = { -0.0517, 0.0037 },
        d08 = { -0.0272, -0.0057 },
        d09 = { -0.0041, 0.0025 },
        d10 = { 0.0206, 0.0042 },
        d11 = { 0.0469, -0.0057 },
        d12 = { 0.0705, -0.006 },
        d13 = { 0.0959, 0.0002 },
        d14 = { 0.1197, 0.0035 },
        d15 = { 0.1437, -0.0017 },
        d16 = { 0.1638, 0.0005 },
        d17 = { 0.1435, 0.0007 },
        d18 = { 0.1192, -0.0056 },
        d19 = { 0.0951, -0.0026 },
        d20 = { 0.0679, -0.0024 },
        d21 = { 0.0468, 0.0073 },
        d22 = { 0.0212, -0.0005 },
        d23 = { -0.0027, 0.0036 },
        d24 = { -0.0304, -0.0066 },
        d25 = { -0.053, -0.0051 },
        d26 = { -0.0678, 0.0018 },
        d27 = { -0.0867, 0.0028 },
        d28 = { -0.0995, -0.0012 },
        d29 = { -0.1136, -0.0036 },
        d30 = { -0.1185, 0.002 },
        d31 = { -0.122, -0.0037 },
        d32 = { -0.1192, 0 },
        d33 = { -0.1212, -0.0071 },
        d34 = { -0.1182, -0.0045 },
        d35 = { -0.1133, 0.0026 },
        d36 = { -0.0992, 0 },
        d37 = { -0.0875, 0 },
        d38 = { -0.0708, 0.0071 },
        d39 = { -0.0518, 0.0016 },
        d40 = { -0.0276, -0.0013 },
        d41 = { -0.0029, -0.0031 },
        d42 = { 0.0203, 0.0032 },
        d43 = { 0.045, -0.0012 },
        d44 = { 0.069, -0.0019 },
        d45 = { 0.0957, -0.0005 },
        d46 = { 0.1196, 0.0022 },
        d47 = { 0.1436, -0.0023 },
        d48 = { 0.1638, -0.0005 },
        d49 = { 0.1437, 0.0013 },
        d50 = { 0.1196, -0.0044 },
        d51 = { 0.0966, 0.0029 },
        d52 = { 0.068, 0.0006 },
        d53 = { 0.0452, -0.0004 },
        d54 = { 0.0232, 0.0035 },
        d55 = { -0.0042, -0.003 },
        d56 = { -0.0321, -0.0081 },
        d57 = { -0.0486, 0.0052 },
        d58 = { -0.0682, -0.002 },
        d59 = { -0.0869, -0.0011 },
        d60 = { -0.0994, -0.001 },
        d61 = { -0.1115, 0.002 },
        d62 = { -0.1182, 0.0054 },
        d63 = { -0.1208, -0.0002 }
      },
      eclat = {
        lr = {
          direction_count = 64,
          filename = "__factorio-overhaul__/graphics/levels/gun/gun-e08-eclat.png",
          frame_count = 1,
          height = 233,
          line_length = 8,
          shift = { 0, -1.046875 },
          width = 286
        }
      },
      eclat_visible = {
        d00 = { 0, -3.17382 },
        d01 = { 0.29585, -3.16354 },
        d02 = { 0.58885, -3.13281 },
        d03 = { 0.87617, -3.08192 },
        d04 = { 1.15506, -3.01136 },
        d05 = { 1.42283, -2.92181 },
        d06 = { 1.67689, -2.81413 },
        d07 = { 1.91481, -2.68936 },
        d08 = { 2.13429, -2.54871 },
        d09 = { 2.33321, -2.39352 },
        d10 = { 2.50966, -2.22529 },
        d11 = { 2.66194, -2.04564 },
        d12 = { 2.78859, -1.8563 },
        d13 = { 2.88838, -1.65909 },
        d14 = { 2.96035, -1.45592 },
        d15 = { 3.00382, -1.24874 },
        d16 = { 3.01835, -1.03954 },
        d17 = { 3.00382, -0.83034 },
        d18 = { 2.96035, -0.62316 },
        d19 = { 2.88838, -0.41999 },
        d20 = { 2.78859, -0.22278 },
        d21 = { 2.66194, -0.03344 },
        d22 = { 2.50966, 0.14621 },
        d23 = { 2.33321, 0.31444 },
        d24 = { 2.13429, 0.46963 },
        d25 = { 1.91481, 0.61028 },
        d26 = { 1.67689, 0.73505 },
        d27 = { 1.42283, 0.84273 },
        d28 = { 1.15506, 0.93228 },
        d29 = { 0.87617, 1.00284 },
        d30 = { 0.58885, 1.05373 },
        d31 = { 0.29585, 1.08446 },
        d32 = { 0, 1.09474 },
        d33 = { -0.29585, 1.08446 },
        d34 = { -0.58885, 1.05373 },
        d35 = { -0.87617, 1.00284 },
        d36 = { -1.15506, 0.93228 },
        d37 = { -1.42283, 0.84273 },
        d38 = { -1.67689, 0.73505 },
        d39 = { -1.91481, 0.61028 },
        d40 = { -2.13429, 0.46963 },
        d41 = { -2.33321, 0.31444 },
        d42 = { -2.50966, 0.14621 },
        d43 = { -2.66194, -0.03344 },
        d44 = { -2.78859, -0.22278 },
        d45 = { -2.88838, -0.41999 },
        d46 = { -2.96035, -0.62316 },
        d47 = { -3.00382, -0.83034 },
        d48 = { -3.01835, -1.03954 },
        d49 = { -3.00382, -1.24874 },
        d50 = { -2.96035, -1.45592 },
        d51 = { -2.88838, -1.65909 },
        d52 = { -2.78859, -1.8563 },
        d53 = { -2.66194, -2.04564 },
        d54 = { -2.50966, -2.22529 },
        d55 = { -2.33321, -2.39352 },
        d56 = { -2.13429, -2.54871 },
        d57 = { -1.91481, -2.68936 },
        d58 = { -1.67689, -2.81413 },
        d59 = { -1.42283, -2.92181 },
        d60 = { -1.15506, -3.01136 },
        d61 = { -0.87617, -3.08192 },
        d62 = { -0.58885, -3.13281 },
        d63 = { -0.29585, -3.16354 }
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
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e08-tete-glow.png",
            height = 276,
            line_length = 8,
            shift = { 0, -1.03125 },
            width = 372
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e08-tete-glow.png",
            height = 138,
            line_length = 8,
            shift = { 0, -1.03125 },
            width = 186
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e08-tete-main.png",
            height = 276,
            line_length = 8,
            shift = { 0, -1.03125 },
            width = 372
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e08-tete-main.png",
            height = 138,
            line_length = 8,
            shift = { 0, -1.03125 },
            width = 186
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e08-tete-shadow.png",
            height = 264,
            line_length = 8,
            shift = { 1.3125, 0 },
            width = 388
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e08-tete-shadow.png",
            height = 132,
            line_length = 8,
            shift = { 1.3125, 0 },
            width = 194
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.03954 },
        projectile_creation_distance = 3.01835
      }
    },
    [9] = {
      boite = { { -3.03125, -3.28125 }, { 3.03125, 2.1875 } },
      bouches = {
        d00 = { 0, -3.04688 },
        d01 = { 0.27683, -3.04155 },
        d02 = { 0.55435, -3.01238 },
        d03 = { 0.82794, -2.96152 },
        d04 = { 1.08221, -2.89227 },
        d05 = { 1.33304, -2.79969 },
        d06 = { 1.56388, -2.69398 },
        d07 = { 1.77675, -2.57195 },
        d08 = { 1.96834, -2.43629 },
        d09 = { 2.14366, -2.28139 },
        d10 = { 2.28876, -2.12123 },
        d11 = { 2.41243, -1.95098 },
        d12 = { 2.50844, -1.77638 },
        d13 = { 2.57868, -1.59521 },
        d14 = { 2.62458, -1.40516 },
        d15 = { 2.64049, -1.22333 },
        d16 = { 2.625, -1.03906 },
        d17 = { 2.64048, -0.85474 },
        d18 = { 2.62182, -0.66749 },
        d19 = { 2.58034, -0.48679 },
        d20 = { 2.50758, -0.30255 },
        d21 = { 2.41076, -0.12494 },
        d22 = { 2.28995, 0.04183 },
        d23 = { 2.14349, 0.20233 },
        d24 = { 1.97591, 0.34957 },
        d25 = { 1.77807, 0.49306 },
        d26 = { 1.56764, 0.61408 },
        d27 = { 1.33424, 0.72111 },
        d28 = { 1.0863, 0.81295 },
        d29 = { 0.81793, 0.88387 },
        d30 = { 0.55683, 0.9339 },
        d31 = { 0.27402, 0.96362 },
        d32 = { 0, 0.96875 },
        d33 = { -0.27583, 0.96349 },
        d34 = { -0.55198, 0.93458 },
        d35 = { -0.82504, 0.88234 },
        d36 = { -1.08585, 0.81308 },
        d37 = { -1.32985, 0.72277 },
        d38 = { -1.56686, 0.61445 },
        d39 = { -1.77545, 0.49458 },
        d40 = { -1.97349, 0.35128 },
        d41 = { -2.14308, 0.20268 },
        d42 = { -2.28882, 0.04258 },
        d43 = { -2.41069, -0.12485 },
        d44 = { -2.50641, -0.30056 },
        d45 = { -2.57922, -0.48417 },
        d46 = { -2.62205, -0.66829 },
        d47 = { -2.64032, -0.85356 },
        d48 = { -2.625, -1.03906 },
        d49 = { -2.64033, -1.22451 },
        d50 = { -2.62481, -1.40436 },
        d51 = { -2.58051, -1.59094 },
        d52 = { -2.50728, -1.77837 },
        d53 = { -2.41236, -1.95106 },
        d54 = { -2.28954, -2.12039 },
        d55 = { -2.14325, -2.28174 },
        d56 = { -1.97145, -2.43314 },
        d57 = { -1.77412, -2.57348 },
        d58 = { -1.5631, -2.69435 },
        d59 = { -1.33038, -2.80365 },
        d60 = { -1.08705, -2.89085 },
        d61 = { -0.83016, -2.96161 },
        d62 = { -0.55432, -3.01238 },
        d63 = { -0.27865, -3.04142 }
      },
      ecart_max = 0.1798,
      ecarts_bouche = {
        d00 = { -0.1236, 0 },
        d01 = { -0.1267, -0.002 },
        d02 = { -0.1236, -0.0007 },
        d03 = { -0.1172, 0.003 },
        d04 = { -0.1047, -0.0028 },
        d05 = { -0.0896, 0.0018 },
        d06 = { -0.0728, 0.0002 },
        d07 = { -0.0529, -0.0014 },
        d08 = { -0.0301, -0.0043 },
        d09 = { -0.0068, 0.0016 },
        d10 = { 0.0204, -0.0006 },
        d11 = { 0.046, 0.0001 },
        d12 = { 0.073, -0.0023 },
        d13 = { 0.0999, -0.0028 },
        d14 = { 0.1248, 0.0032 },
        d15 = { 0.1503, -0.0002 },
        d16 = { 0.1798, 0.0002 },
        d17 = { 0.1503, 0.0006 },
        d18 = { 0.1267, 0.003 },
        d19 = { 0.099, -0.001 },
        d20 = { 0.074, 0.0021 },
        d21 = { 0.0467, 0.0029 },
        d22 = { 0.0197, -0.0008 },
        d23 = { -0.0064, -0.002 },
        d24 = { -0.0315, -0.0068 },
        d25 = { -0.0536, 0.0002 },
        d26 = { -0.0743, -0.0039 },
        d27 = { -0.0902, -0.0028 },
        d28 = { -0.106, -0.0011 },
        d29 = { -0.114, 0.0065 },
        d30 = { -0.1243, -0.0017 },
        d31 = { -0.1268, 0.0049 },
        d32 = { -0.124, 0 },
        d33 = { -0.127, -0.0031 },
        d34 = { -0.1236, -0.0031 },
        d35 = { -0.1154, 0.0006 },
        d36 = { -0.1059, 0.0007 },
        d37 = { -0.0889, -0.0017 },
        d38 = { -0.0741, 0.0031 },
        d39 = { -0.0526, -0.0031 },
        d40 = { -0.0306, 0.004 },
        d41 = { -0.0062, 0.0015 },
        d42 = { 0.0204, -0.0004 },
        d43 = { 0.0467, -0.003 },
        d44 = { 0.0745, -0.0044 },
        d45 = { 0.0996, -0.0018 },
        d46 = { 0.1266, -0.0021 },
        d47 = { 0.1504, -0.0018 },
        d48 = { 0.1798, -0.0002 },
        d49 = { 0.1504, 0.0014 },
        d50 = { 0.1247, -0.004 },
        d51 = { 0.099, -0.0018 },
        d52 = { 0.0736, 0.0046 },
        d53 = { 0.0461, 0.0001 },
        d54 = { 0.0201, -0.0005 },
        d55 = { -0.0066, -0.0011 },
        d56 = { -0.0308, -0.0001 },
        d57 = { -0.0519, 0.0043 },
        d58 = { -0.0725, 0.0006 },
        d59 = { -0.0911, 0.0027 },
        d60 = { -0.1059, -0.0021 },
        d61 = { -0.1182, -0.005 },
        d62 = { -0.1236, 0.0007 },
        d63 = { -0.1268, 0.0002 }
      },
      eclat = {
        lr = {
          direction_count = 64,
          filename = "__factorio-overhaul__/graphics/levels/gun/gun-e09-eclat.png",
          frame_count = 1,
          height = 250,
          line_length = 8,
          shift = { 0, -1.03125 },
          width = 304
        }
      },
      eclat_visible = {
        d00 = { 0, -3.26217 },
        d01 = { 0.30814, -3.25147 },
        d02 = { 0.61331, -3.21946 },
        d03 = { 0.91257, -3.16645 },
        d04 = { 1.20304, -3.09296 },
        d05 = { 1.48193, -2.99969 },
        d06 = { 1.74655, -2.88755 },
        d07 = { 1.99435, -2.7576 },
        d08 = { 2.22294, -2.6111 },
        d09 = { 2.43013, -2.44946 },
        d10 = { 2.61391, -2.27424 },
        d11 = { 2.77252, -2.08713 },
        d12 = { 2.90442, -1.88993 },
        d13 = { 3.00836, -1.68453 },
        d14 = { 3.08332, -1.47292 },
        d15 = { 3.12859, -1.25713 },
        d16 = { 3.14373, -1.03924 },
        d17 = { 3.12859, -0.82135 },
        d18 = { 3.08332, -0.60556 },
        d19 = { 3.00836, -0.39395 },
        d20 = { 2.90442, -0.18855 },
        d21 = { 2.77252, 0.00865 },
        d22 = { 2.61391, 0.19576 },
        d23 = { 2.43013, 0.37098 },
        d24 = { 2.22294, 0.53262 },
        d25 = { 1.99435, 0.67912 },
        d26 = { 1.74655, 0.80907 },
        d27 = { 1.48193, 0.92121 },
        d28 = { 1.20304, 1.01448 },
        d29 = { 0.91257, 1.08797 },
        d30 = { 0.61331, 1.14098 },
        d31 = { 0.30814, 1.17299 },
        d32 = { 0, 1.18369 },
        d33 = { -0.30814, 1.17299 },
        d34 = { -0.61331, 1.14098 },
        d35 = { -0.91257, 1.08797 },
        d36 = { -1.20304, 1.01448 },
        d37 = { -1.48193, 0.92121 },
        d38 = { -1.74655, 0.80907 },
        d39 = { -1.99435, 0.67912 },
        d40 = { -2.22294, 0.53262 },
        d41 = { -2.43013, 0.37098 },
        d42 = { -2.61391, 0.19576 },
        d43 = { -2.77252, 0.00865 },
        d44 = { -2.90442, -0.18855 },
        d45 = { -3.00836, -0.39395 },
        d46 = { -3.08332, -0.60556 },
        d47 = { -3.12859, -0.82135 },
        d48 = { -3.14373, -1.03924 },
        d49 = { -3.12859, -1.25713 },
        d50 = { -3.08332, -1.47292 },
        d51 = { -3.00836, -1.68453 },
        d52 = { -2.90442, -1.88993 },
        d53 = { -2.77252, -2.08713 },
        d54 = { -2.61391, -2.27424 },
        d55 = { -2.43013, -2.44946 },
        d56 = { -2.22294, -2.6111 },
        d57 = { -1.99435, -2.7576 },
        d58 = { -1.74655, -2.88755 },
        d59 = { -1.48193, -2.99969 },
        d60 = { -1.20304, -3.09296 },
        d61 = { -0.91257, -3.16645 },
        d62 = { -0.61331, -3.21946 },
        d63 = { -0.30814, -3.25147 }
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
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e09-tete-glow.png",
            height = 288,
            line_length = 8,
            shift = { 0, -1.03125 },
            width = 388
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e09-tete-glow.png",
            height = 144,
            line_length = 8,
            shift = { 0, -1.03125 },
            width = 194
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e09-tete-main.png",
            height = 288,
            line_length = 8,
            shift = { 0, -1.03125 },
            width = 388
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e09-tete-main.png",
            height = 144,
            line_length = 8,
            shift = { 0, -1.03125 },
            width = 194
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e09-tete-shadow.png",
            height = 276,
            line_length = 8,
            shift = { 1.328125, 0 },
            width = 402
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e09-tete-shadow.png",
            height = 138,
            line_length = 8,
            shift = { 1.328125, 0 },
            width = 201
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.03924 },
        projectile_creation_distance = 3.14373
      }
    },
    [10] = {
      boite = { { -3.28125, -3.625 }, { 3.28125, 3.0625 } },
      bouches = {
        d00 = { 0, -3.3125 },
        d01 = { 0.29074, -3.30675 },
        d02 = { 0.57261, -3.27641 },
        d03 = { 0.84824, -3.22727 },
        d04 = { 1.12778, -3.15315 },
        d05 = { 1.38169, -3.06674 },
        d06 = { 1.62508, -2.95807 },
        d07 = { 1.85047, -2.82827 },
        d08 = { 2.05835, -2.69083 },
        d09 = { 2.24862, -2.53328 },
        d10 = { 2.39794, -2.36589 },
        d11 = { 2.53573, -2.1924 },
        d12 = { 2.64927, -2.00449 },
        d13 = { 2.72995, -1.80989 },
        d14 = { 2.78149, -1.61894 },
        d15 = { 2.81005, -1.42882 },
        d16 = { 2.8125, -1.22656 },
        d17 = { 2.81036, -1.03432 },
        d18 = { 2.78393, -0.84285 },
        d19 = { 2.72721, -0.64208 },
        d20 = { 2.6464, -0.45384 },
        d21 = { 2.53988, -0.26874 },
        d22 = { 2.40509, -0.09525 },
        d23 = { 2.24895, 0.06641 },
        d24 = { 2.05734, 0.22737 },
        d25 = { 1.85334, 0.3702 },
        d26 = { 1.62934, 0.49143 },
        d27 = { 1.38418, 0.60382 },
        d28 = { 1.12121, 0.69737 },
        d29 = { 0.85024, 0.76591 },
        d30 = { 0.57451, 0.81521 },
        d31 = { 0.29009, 0.84585 },
        d32 = { 0, 0.85938 },
        d33 = { -0.29575, 0.84946 },
        d34 = { -0.57524, 0.81632 },
        d35 = { -0.85246, 0.76654 },
        d36 = { -1.12144, 0.69691 },
        d37 = { -1.38048, 0.60226 },
        d38 = { -1.62883, 0.49253 },
        d39 = { -1.8556, 0.36966 },
        d40 = { -2.05932, 0.22826 },
        d41 = { -2.24496, 0.072 },
        d42 = { -2.40087, -0.09216 },
        d43 = { -2.53587, -0.26849 },
        d44 = { -2.64633, -0.45466 },
        d45 = { -2.72782, -0.64867 },
        d46 = { -2.78267, -0.84271 },
        d47 = { -2.80845, -1.03483 },
        d48 = { -2.8125, -1.23438 },
        d49 = { -2.80872, -1.42417 },
        d50 = { -2.78232, -1.61949 },
        d51 = { -2.72872, -1.81797 },
        d52 = { -2.64758, -2.00414 },
        d53 = { -2.54326, -2.18521 },
        d54 = { -2.40125, -2.36103 },
        d55 = { -2.24055, -2.53109 },
        d56 = { -2.06194, -2.6841 },
        d57 = { -1.8536, -2.82848 },
        d58 = { -1.62515, -2.95889 },
        d59 = { -1.38324, -3.06406 },
        d60 = { -1.12892, -3.15471 },
        d61 = { -0.85046, -3.22791 },
        d62 = { -0.56882, -3.27926 },
        d63 = { -0.29094, -3.30456 }
      },
      ecart_max = 0.1289,
      ecarts_bouche = {
        d00 = { -0.102, 0 },
        d01 = { -0.1054, 0.0015 },
        d02 = { -0.1008, -0.0029 },
        d03 = { -0.0937, -0.0079 },
        d04 = { -0.0849, 0.0011 },
        d05 = { -0.0731, -0.0054 },
        d06 = { -0.0577, -0.0057 },
        d07 = { -0.0373, -0.0029 },
        d08 = { -0.0222, -0.0044 },
        d09 = { -0.0063, 0.0014 },
        d10 = { 0.0242, -0.0026 },
        d11 = { 0.0415, -0.0037 },
        d12 = { 0.0587, 0.0014 },
        d13 = { 0.0806, 0.0056 },
        d14 = { 0.1014, 0.0023 },
        d15 = { 0.1163, -0.0031 },
        d16 = { 0.1288, 0.0035 },
        d17 = { 0.1162, 0 },
        d18 = { 0.0992, -0.0044 },
        d19 = { 0.0816, 0.0029 },
        d20 = { 0.061, 0.001 },
        d21 = { 0.038, 0.0012 },
        d22 = { 0.0182, -0.0014 },
        d23 = { -0.0031, -0.0075 },
        d24 = { -0.0194, 0.0021 },
        d25 = { -0.0407, 0.0025 },
        d26 = { -0.0558, -0.0019 },
        d27 = { -0.0723, 0.0016 },
        d28 = { -0.0852, 0.0068 },
        d29 = { -0.0932, 0.0055 },
        d30 = { -0.1002, 0.0008 },
        d31 = { -0.1044, -0.0009 },
        d32 = { -0.1089, 0 },
        d33 = { -0.1088, 0.006 },
        d34 = { -0.1014, -0.0004 },
        d35 = { -0.0947, -0.0037 },
        d36 = { -0.085, -0.0063 },
        d37 = { -0.0688, -0.0036 },
        d38 = { -0.0563, 0.0008 },
        d39 = { -0.0421, -0.0007 },
        d40 = { -0.0216, -0.0017 },
        d41 = { -0.0025, 0.0006 },
        d42 = { 0.0207, -0.0032 },
        d43 = { 0.0416, -0.0029 },
        d44 = { 0.0613, -0.0003 },
        d45 = { 0.0823, 0.0037 },
        d46 = { 0.1004, 0.004 },
        d47 = { 0.1182, 0.0004 },
        d48 = { 0.1288, 0.0044 },
        d49 = { 0.118, -0.0015 },
        d50 = { 0.1005, -0.0018 },
        d51 = { 0.0801, 0.0026 },
        d52 = { 0.0605, -0.0013 },
        d53 = { 0.037, -0.0057 },
        d54 = { 0.0233, -0.0032 },
        d55 = { 0.0018, 0.0007 },
        d56 = { -0.0213, -0.0032 },
        d57 = { -0.0398, 0.001 },
        d58 = { -0.0584, 0.0062 },
        d59 = { -0.0719, 0.0025 },
        d60 = { -0.0868, -0.0013 },
        d61 = { -0.0951, 0.0061 },
        d62 = { -0.1025, 0.0074 },
        d63 = { -0.1032, -0.002 }
      },
      eclat = {
        lr = {
          direction_count = 64,
          filename = "__factorio-overhaul__/graphics/levels/gun/gun-e10-eclat.png",
          frame_count = 1,
          height = 356,
          line_length = 8,
          shift = { 0, -1.21875 },
          width = 418
        }
      },
      eclat_visible = {
        d00 = { 0, -3.54944 },
        d01 = { 0.32151, -3.53827 },
        d02 = { 0.63993, -3.50488 },
        d03 = { 0.95218, -3.44957 },
        d04 = { 1.25526, -3.37289 },
        d05 = { 1.54626, -3.27557 },
        d06 = { 1.82236, -3.15855 },
        d07 = { 2.08092, -3.02296 },
        d08 = { 2.31943, -2.87011 },
        d09 = { 2.53561, -2.70145 },
        d10 = { 2.72737, -2.51863 },
        d11 = { 2.89286, -2.3234 },
        d12 = { 3.0305, -2.11763 },
        d13 = { 3.13894, -1.90332 },
        d14 = { 3.21716, -1.68252 },
        d15 = { 3.26439, -1.45737 },
        d16 = { 3.28019, -1.23002 },
        d17 = { 3.26439, -1.00267 },
        d18 = { 3.21716, -0.77752 },
        d19 = { 3.13894, -0.55672 },
        d20 = { 3.0305, -0.34241 },
        d21 = { 2.89286, -0.13664 },
        d22 = { 2.72737, 0.05859 },
        d23 = { 2.53561, 0.24141 },
        d24 = { 2.31943, 0.41007 },
        d25 = { 2.08092, 0.56292 },
        d26 = { 1.82236, 0.69851 },
        d27 = { 1.54626, 0.81553 },
        d28 = { 1.25526, 0.91285 },
        d29 = { 0.95218, 0.98953 },
        d30 = { 0.63993, 1.04484 },
        d31 = { 0.32151, 1.07823 },
        d32 = { 0, 1.0894 },
        d33 = { -0.32151, 1.07823 },
        d34 = { -0.63993, 1.04484 },
        d35 = { -0.95218, 0.98953 },
        d36 = { -1.25526, 0.91285 },
        d37 = { -1.54626, 0.81553 },
        d38 = { -1.82236, 0.69851 },
        d39 = { -2.08092, 0.56292 },
        d40 = { -2.31943, 0.41007 },
        d41 = { -2.53561, 0.24141 },
        d42 = { -2.72737, 0.05859 },
        d43 = { -2.89286, -0.13664 },
        d44 = { -3.0305, -0.34241 },
        d45 = { -3.13894, -0.55672 },
        d46 = { -3.21716, -0.77752 },
        d47 = { -3.26439, -1.00267 },
        d48 = { -3.28019, -1.23002 },
        d49 = { -3.26439, -1.45737 },
        d50 = { -3.21716, -1.68252 },
        d51 = { -3.13894, -1.90332 },
        d52 = { -3.0305, -2.11763 },
        d53 = { -2.89286, -2.3234 },
        d54 = { -2.72737, -2.51863 },
        d55 = { -2.53561, -2.70145 },
        d56 = { -2.31943, -2.87011 },
        d57 = { -2.08092, -3.02296 },
        d58 = { -1.82236, -3.15855 },
        d59 = { -1.54626, -3.27557 },
        d60 = { -1.25526, -3.37289 },
        d61 = { -0.95218, -3.44957 },
        d62 = { -0.63993, -3.50488 },
        d63 = { -0.32151, -3.53827 }
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
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e10-tete-glow.png",
            height = 306,
            line_length = 8,
            shift = { 0, -1.234375 },
            width = 420
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e10-tete-glow.png",
            height = 153,
            line_length = 8,
            shift = { 0, -1.234375 },
            width = 210
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e10-tete-main.png",
            height = 306,
            line_length = 8,
            shift = { 0, -1.234375 },
            width = 420
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e10-tete-main.png",
            height = 153,
            line_length = 8,
            shift = { 0, -1.234375 },
            width = 210
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e10-tete-shadow.png",
            height = 296,
            line_length = 8,
            shift = { 1.5625, 0 },
            width = 428
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e10-tete-shadow.png",
            height = 148,
            line_length = 8,
            shift = { 1.5625, 0 },
            width = 214
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.23002 },
        projectile_creation_distance = 3.28019
      }
    },
    [11] = {
      boite = { { -4.15625, -4.25 }, { 4.15625, 3.0625 } },
      bouches = {
        d00 = { 0, -4.01562 },
        d01 = { 0.37638, -4.00208 },
        d02 = { 0.76809, -3.96059 },
        d03 = { 1.14257, -3.89299 },
        d04 = { 1.50065, -3.80087 },
        d05 = { 1.84405, -3.68234 },
        d06 = { 2.17291, -3.5366 },
        d07 = { 2.47218, -3.37378 },
        d08 = { 2.75736, -3.18498 },
        d09 = { 3.0073, -2.97893 },
        d10 = { 3.22402, -2.75732 },
        d11 = { 3.40877, -2.52059 },
        d12 = { 3.56011, -2.27791 },
        d13 = { 3.67531, -2.02072 },
        d14 = { 3.75427, -1.76522 },
        d15 = { 3.79709, -1.49703 },
        d16 = { 3.79688, -1.23438 },
        d17 = { 3.79678, -0.96945 },
        d18 = { 3.75811, -0.70589 },
        d19 = { 3.67792, -0.44373 },
        d20 = { 3.5606, -0.18387 },
        d21 = { 3.41336, 0.0614 },
        d22 = { 3.22258, 0.291 },
        d23 = { 3.00279, 0.51622 },
        d24 = { 2.75841, 0.72101 },
        d25 = { 2.48517, 0.90733 },
        d26 = { 2.17701, 1.07373 },
        d27 = { 1.84715, 1.21832 },
        d28 = { 1.51135, 1.33546 },
        d29 = { 1.13871, 1.43288 },
        d30 = { 0.76411, 1.50131 },
        d31 = { 0.38117, 1.54081 },
        d32 = { 0, 1.54688 },
        d33 = { -0.38177, 1.54077 },
        d34 = { -0.76556, 1.50111 },
        d35 = { -1.13734, 1.43318 },
        d36 = { -1.50428, 1.33753 },
        d37 = { -1.85709, 1.21457 },
        d38 = { -2.17554, 1.07442 },
        d39 = { -2.48212, 0.90909 },
        d40 = { -2.7583, 0.72108 },
        d41 = { -3.00349, 0.51562 },
        d42 = { -3.22581, 0.28759 },
        d43 = { -3.41626, 0.05756 },
        d44 = { -3.56352, -0.18884 },
        d45 = { -3.67986, -0.44825 },
        d46 = { -3.75628, -0.69939 },
        d47 = { -3.79666, -0.96862 },
        d48 = { -3.79688, -1.23438 },
        d49 = { -3.7964, -1.502 },
        d50 = { -3.75606, -1.75886 },
        d51 = { -3.67352, -2.02488 },
        d52 = { -3.5605, -2.27724 },
        d53 = { -3.40913, -2.52012 },
        d54 = { -3.22724, -2.75391 },
        d55 = { -3.012, -2.97487 },
        d56 = { -2.76021, -3.18296 },
        d57 = { -2.47567, -3.37175 },
        d58 = { -2.17669, -3.53482 },
        d59 = { -1.85695, -3.67747 },
        d60 = { -1.4984, -3.80153 },
        d61 = { -1.14427, -3.89263 },
        d62 = { -0.76473, -3.96106 },
        d63 = { -0.37698, -4.00204 }
      },
      ecart_max = 0.1332,
      ecarts_bouche = {
        d00 = { -0.1041, 0 },
        d01 = { -0.1015, -0.0094 },
        d02 = { -0.0982, 0.0005 },
        d03 = { -0.0917, 0.0009 },
        d04 = { -0.082, -0.0036 },
        d05 = { -0.0685, -0.0066 },
        d06 = { -0.0533, -0.0036 },
        d07 = { -0.0351, -0.009 },
        d08 = { -0.0209, -0.0027 },
        d09 = { -0.0015, -0.0016 },
        d10 = { 0.0202, -0.0019 },
        d11 = { 0.0417, -0.0003 },
        d12 = { 0.0602, -0.0031 },
        d13 = { 0.0801, -0.0005 },
        d14 = { 0.0973, -0.0052 },
        d15 = { 0.1135, -0.0007 },
        d16 = { 0.1332, -0.0025 },
        d17 = { 0.114, -0.002 },
        d18 = { 0.0945, -0.0025 },
        d19 = { 0.0777, -0.0007 },
        d20 = { 0.0592, 0.005 },
        d21 = { 0.0358, 0.003 },
        d22 = { 0.0225, 0.0003 },
        d23 = { 0.0018, 0.0048 },
        d24 = { -0.0216, 0.002 },
        d25 = { -0.0432, -0.0015 },
        d26 = { -0.0568, 0.0012 },
        d27 = { -0.0702, 0.004 },
        d28 = { -0.086, -0.0064 },
        d29 = { -0.0936, 0.0041 },
        d30 = { -0.1014, 0.0046 },
        d31 = { -0.1046, 0.005 },
        d32 = { -0.0991, 0 },
        d33 = { -0.1047, -0.0044 },
        d34 = { -0.1016, -0.0031 },
        d35 = { -0.0933, -0.0055 },
        d36 = { -0.0842, -0.0007 },
        d37 = { -0.0732, 0.0062 },
        d38 = { -0.0562, -0.0028 },
        d39 = { -0.0421, -0.0018 },
        d40 = { -0.0216, -0.0021 },
        d41 = { 0.0016, -0.004 },
        d42 = { 0.0211, 0.0042 },
        d43 = { 0.0344, 0.0016 },
        d44 = { 0.0578, 0.0006 },
        d45 = { 0.0768, 0.0056 },
        d46 = { 0.0954, -0.0041 },
        d47 = { 0.114, 0.0011 },
        d48 = { 0.1332, 0.0025 },
        d49 = { 0.1138, 0.0057 },
        d50 = { 0.0964, -0.0013 },
        d51 = { 0.081, 0.0049 },
        d52 = { 0.06, 0.0024 },
        d53 = { 0.0415, -0.0003 },
        d54 = { 0.0187, -0.0025 },
        d55 = { -0.0035, -0.0043 },
        d56 = { -0.022, -0.0006 },
        d57 = { -0.0364, 0.0051 },
        d58 = { -0.0546, -0.0004 },
        d59 = { -0.0724, -0.0066 },
        d60 = { -0.0814, 0.0059 },
        d61 = { -0.0921, -0.0026 },
        d62 = { -0.0977, 0.0029 },
        d63 = { -0.1015, 0.0088 }
      },
      eclat = {
        lr = {
          direction_count = 64,
          filename = "__factorio-overhaul__/graphics/levels/gun/gun-e11-eclat.png",
          frame_count = 1,
          height = 421,
          line_length = 8,
          shift = { 0.015625, -1.234375 },
          width = 499
        }
      },
      eclat_visible = {
        d00 = { 0, -4.2505 },
        d01 = { 0.41843, -4.23596 },
        d02 = { 0.83283, -4.1925 },
        d03 = { 1.23921, -4.12052 },
        d04 = { 1.63365, -4.02072 },
        d05 = { 2.01237, -3.89407 },
        d06 = { 2.3717, -3.74178 },
        d07 = { 2.7082, -3.56532 },
        d08 = { 3.01861, -3.36638 },
        d09 = { 3.29995, -3.14689 },
        d10 = { 3.54952, -2.90895 },
        d11 = { 3.7649, -2.65487 },
        d12 = { 3.94402, -2.38708 },
        d13 = { 4.08516, -2.10816 },
        d14 = { 4.18695, -1.8208 },
        d15 = { 4.24842, -1.52778 },
        d16 = { 4.26898, -1.2319 },
        d17 = { 4.24842, -0.93602 },
        d18 = { 4.18695, -0.643 },
        d19 = { 4.08516, -0.35564 },
        d20 = { 3.94402, -0.07672 },
        d21 = { 3.7649, 0.19107 },
        d22 = { 3.54952, 0.44515 },
        d23 = { 3.29995, 0.68309 },
        d24 = { 3.01861, 0.90258 },
        d25 = { 2.7082, 1.10152 },
        d26 = { 2.3717, 1.27798 },
        d27 = { 2.01237, 1.43027 },
        d28 = { 1.63365, 1.55692 },
        d29 = { 1.23921, 1.65672 },
        d30 = { 0.83283, 1.7287 },
        d31 = { 0.41843, 1.77216 },
        d32 = { 0, 1.7867 },
        d33 = { -0.41843, 1.77216 },
        d34 = { -0.83283, 1.7287 },
        d35 = { -1.23921, 1.65672 },
        d36 = { -1.63365, 1.55692 },
        d37 = { -2.01237, 1.43027 },
        d38 = { -2.3717, 1.27798 },
        d39 = { -2.7082, 1.10152 },
        d40 = { -3.01861, 0.90258 },
        d41 = { -3.29995, 0.68309 },
        d42 = { -3.54952, 0.44515 },
        d43 = { -3.7649, 0.19107 },
        d44 = { -3.94402, -0.07672 },
        d45 = { -4.08516, -0.35564 },
        d46 = { -4.18695, -0.643 },
        d47 = { -4.24842, -0.93602 },
        d48 = { -4.26898, -1.2319 },
        d49 = { -4.24842, -1.52778 },
        d50 = { -4.18695, -1.8208 },
        d51 = { -4.08516, -2.10816 },
        d52 = { -3.94402, -2.38708 },
        d53 = { -3.7649, -2.65487 },
        d54 = { -3.54952, -2.90895 },
        d55 = { -3.29995, -3.14689 },
        d56 = { -3.01861, -3.36638 },
        d57 = { -2.7082, -3.56532 },
        d58 = { -2.3717, -3.74178 },
        d59 = { -2.01237, -3.89407 },
        d60 = { -1.63365, -4.02072 },
        d61 = { -1.23921, -4.12052 },
        d62 = { -0.83283, -4.1925 },
        d63 = { -0.41843, -4.23596 }
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
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e11-tete-glow.png",
            height = 386,
            line_length = 8,
            shift = { 0, -1.234375 },
            width = 532
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e11-tete-glow.png",
            height = 193,
            line_length = 8,
            shift = { 0, -1.234375 },
            width = 266
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e11-tete-main.png",
            height = 386,
            line_length = 8,
            shift = { 0, -1.234375 },
            width = 532
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e11-tete-main.png",
            height = 193,
            line_length = 8,
            shift = { 0, -1.234375 },
            width = 266
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e11-tete-shadow.png",
            height = 376,
            line_length = 8,
            shift = { 1.5625, 0 },
            width = 544
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e11-tete-shadow.png",
            height = 188,
            line_length = 8,
            shift = { 1.5625, 0 },
            width = 272
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.2319 },
        projectile_creation_distance = 4.26898
      }
    },
    [12] = {
      boite = { { -3.4375, -3.75 }, { 3.4375, 3.0625 } },
      bouches = {
        d00 = { 0, -3.09375 },
        d01 = { 0.24833, -3.09604 },
        d02 = { 0.50909, -3.06452 },
        d03 = { 0.73634, -3.02637 },
        d04 = { 0.96542, -2.96973 },
        d05 = { 1.48255, -3.18905 },
        d06 = { 1.73805, -3.07399 },
        d07 = { 1.98032, -2.93937 },
        d08 = { 2.19939, -2.78886 },
        d09 = { 2.39687, -2.62046 },
        d10 = { 2.57014, -2.44322 },
        d11 = { 2.71719, -2.25785 },
        d12 = { 2.83133, -2.06066 },
        d13 = { 2.92163, -1.8574 },
        d14 = { 2.9787, -1.65126 },
        d15 = { 3.0084, -1.43828 },
        d16 = { 3, -1.23047 },
        d17 = { 3.00751, -1.01624 },
        d18 = { 2.98025, -0.81084 },
        d19 = { 2.91951, -0.60641 },
        d20 = { 2.83312, -0.40104 },
        d21 = { 2.71205, -0.20158 },
        d22 = { 2.57222, -0.01302 },
        d23 = { 2.39828, 0.16503 },
        d24 = { 2.2019, 0.33167 },
        d25 = { 1.69701, 0.43401 },
        d26 = { 1.65831, 0.65072 },
        d27 = { 1.40851, 0.758 },
        d28 = { 1.15423, 0.83787 },
        d29 = { 0.87776, 0.91069 },
        d30 = { 0.59726, 0.95813 },
        d31 = { 0.2963, 0.98768 },
        d32 = { 0, 1 },
        d33 = { -0.29312, 0.99245 },
        d34 = { -0.58589, 0.96094 },
        d35 = { -0.87893, 0.91154 },
        d36 = { -1.14527, 0.84239 },
        d37 = { -1.41126, 0.75487 },
        d38 = { -1.66483, 0.6485 },
        d39 = { -1.90366, 0.52369 },
        d40 = { -2.20184, 0.32524 },
        d41 = { -2.40163, 0.15866 },
        d42 = { -2.5752, -0.01708 },
        d43 = { -2.71795, -0.20385 },
        d44 = { -2.82997, -0.40119 },
        d45 = { -2.92419, -0.60685 },
        d46 = { -2.97984, -0.81022 },
        d47 = { -3.0092, -1.0192 },
        d48 = { -3, -1.23438 },
        d49 = { -3.0101, -1.43532 },
        d50 = { -2.97855, -1.64746 },
        d51 = { -2.9194, -1.85743 },
        d52 = { -2.83575, -2.05768 },
        d53 = { -2.71774, -2.2546 },
        d54 = { -2.56318, -2.44922 },
        d55 = { -2.3968, -2.62484 },
        d56 = { -2.20566, -2.789 },
        d57 = { -1.98249, -2.94013 },
        d58 = { -1.74457, -3.07177 },
        d59 = { -1.4817, -3.19023 },
        d60 = { -0.95575, -2.97256 },
        d61 = { -0.74524, -3.02446 },
        d62 = { -0.50338, -3.06532 },
        d63 = { -0.24462, -3.0963 }
      },
      ecart_max = 0.2367,
      ecarts_bouche = {
        d00 = { 0.1669, 0 },
        d01 = { 0.1603, -0.0185 },
        d02 = { 0.1743, -0.0205 },
        d03 = { 0.1935, -0.0516 },
        d04 = { 0.2197, -0.072 },
        d05 = { -0.1604, -0.0293 },
        d06 = { -0.141, -0.0381 },
        d07 = { -0.1218, -0.0408 },
        d08 = { -0.0997, -0.0445 },
        d09 = { -0.0762, -0.0436 },
        d10 = { -0.055, -0.0449 },
        d11 = { -0.0348, -0.0483 },
        d12 = { -0.0086, -0.0501 },
        d13 = { 0.0123, -0.0504 },
        d14 = { 0.0359, -0.0526 },
        d15 = { 0.0567, -0.0495 },
        d16 = { 0.0841, -0.0513 },
        d17 = { 0.0643, -0.0464 },
        d18 = { 0.0488, -0.0503 },
        d19 = { 0.0365, -0.0523 },
        d20 = { 0.0187, -0.0496 },
        d21 = { 0.0058, -0.0444 },
        d22 = { -0.015, -0.0444 },
        d23 = { -0.0287, -0.0411 },
        d24 = { -0.0447, -0.0377 },
        d25 = { 0.1888, 0.1144 },
        d26 = { -0.0391, 0.0515 },
        d27 = { -0.0578, 0.0445 },
        d28 = { -0.0712, 0.0236 },
        d29 = { -0.0853, 0.0173 },
        d30 = { -0.0921, 0.0038 },
        d31 = { -0.094, 0.0055 },
        d32 = { -0.0977, 0 },
        d33 = { -0.0982, -0.0093 },
        d34 = { -0.0917, -0.0155 },
        d35 = { -0.0865, -0.0165 },
        d36 = { -0.0706, -0.0336 },
        d37 = { -0.0569, -0.0405 },
        d38 = { -0.0419, -0.0452 },
        d39 = { -0.0263, -0.0475 },
        d40 = { -0.0409, 0.0429 },
        d41 = { -0.0284, 0.0483 },
        d42 = { -0.016, 0.0494 },
        d43 = { 0.0011, 0.0486 },
        d44 = { 0.0218, 0.0488 },
        d45 = { 0.032, 0.0537 },
        d46 = { 0.0491, 0.0497 },
        d47 = { 0.0628, 0.0495 },
        d48 = { 0.0841, 0.0552 },
        d49 = { 0.0552, 0.0464 },
        d50 = { 0.0366, 0.0489 },
        d51 = { 0.0144, 0.0509 },
        d52 = { -0.012, 0.046 },
        d53 = { -0.0341, 0.0451 },
        d54 = { -0.0512, 0.0534 },
        d55 = { -0.0783, 0.0474 },
        d56 = { -0.1049, 0.041 },
        d57 = { -0.1239, 0.04 },
        d58 = { -0.1439, 0.0319 },
        d59 = { -0.1608, 0.0307 },
        d60 = { 0.2221, 0.0818 },
        d61 = { 0.1918, 0.0426 },
        d62 = { 0.1751, 0.0262 },
        d63 = { 0.1605, 0.0222 }
      },
      eclat = {
        lr = {
          direction_count = 64,
          filename = "__factorio-overhaul__/graphics/levels/gun/gun-e12-eclat.png",
          frame_count = 1,
          height = 347,
          line_length = 8,
          shift = { 0.015625, -1.203125 },
          width = 411
        }
      },
      eclat_visible = {
        d00 = { 0, -3.59957 },
        d01 = { 0.33551, -3.58791 },
        d02 = { 0.66778, -3.55306 },
        d03 = { 0.99363, -3.49535 },
        d04 = { 1.30991, -3.41533 },
        d05 = { 1.61357, -3.31378 },
        d06 = { 1.90169, -3.19167 },
        d07 = { 2.1715, -3.05017 },
        d08 = { 2.4204, -2.89066 },
        d09 = { 2.64599, -2.71467 },
        d10 = { 2.8461, -2.52389 },
        d11 = { 3.01879, -2.32015 },
        d12 = { 3.16242, -2.10543 },
        d13 = { 3.27558, -1.88179 },
        d14 = { 3.35721, -1.65138 },
        d15 = { 3.4065, -1.41642 },
        d16 = { 3.42298, -1.17918 },
        d17 = { 3.4065, -0.94194 },
        d18 = { 3.35721, -0.70698 },
        d19 = { 3.27558, -0.47657 },
        d20 = { 3.16242, -0.25293 },
        d21 = { 3.01879, -0.03821 },
        d22 = { 2.8461, 0.16553 },
        d23 = { 2.64599, 0.35631 },
        d24 = { 2.4204, 0.5323 },
        d25 = { 2.1715, 0.69181 },
        d26 = { 1.90169, 0.83331 },
        d27 = { 1.61357, 0.95542 },
        d28 = { 1.30991, 1.05697 },
        d29 = { 0.99363, 1.13699 },
        d30 = { 0.66778, 1.1947 },
        d31 = { 0.33551, 1.22955 },
        d32 = { 0, 1.24121 },
        d33 = { -0.33551, 1.22955 },
        d34 = { -0.66778, 1.1947 },
        d35 = { -0.99363, 1.13699 },
        d36 = { -1.30991, 1.05697 },
        d37 = { -1.61357, 0.95542 },
        d38 = { -1.90169, 0.83331 },
        d39 = { -2.1715, 0.69181 },
        d40 = { -2.4204, 0.5323 },
        d41 = { -2.64599, 0.35631 },
        d42 = { -2.8461, 0.16553 },
        d43 = { -3.01879, -0.03821 },
        d44 = { -3.16242, -0.25293 },
        d45 = { -3.27558, -0.47657 },
        d46 = { -3.35721, -0.70698 },
        d47 = { -3.4065, -0.94194 },
        d48 = { -3.42298, -1.17918 },
        d49 = { -3.4065, -1.41642 },
        d50 = { -3.35721, -1.65138 },
        d51 = { -3.27558, -1.88179 },
        d52 = { -3.16242, -2.10543 },
        d53 = { -3.01879, -2.32015 },
        d54 = { -2.8461, -2.52389 },
        d55 = { -2.64599, -2.71467 },
        d56 = { -2.4204, -2.89066 },
        d57 = { -2.1715, -3.05017 },
        d58 = { -1.90169, -3.19167 },
        d59 = { -1.61357, -3.31378 },
        d60 = { -1.30991, -3.41533 },
        d61 = { -0.99363, -3.49535 },
        d62 = { -0.66778, -3.55306 },
        d63 = { -0.33551, -3.58791 }
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
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e12-tete-glow.png",
            height = 322,
            line_length = 8,
            shift = { 0, -1.234375 },
            width = 440
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e12-tete-glow.png",
            height = 161,
            line_length = 8,
            shift = { 0, -1.234375 },
            width = 220
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e12-tete-main.png",
            height = 322,
            line_length = 8,
            shift = { 0, -1.234375 },
            width = 440
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e12-tete-main.png",
            height = 161,
            line_length = 8,
            shift = { 0, -1.234375 },
            width = 220
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e12-tete-shadow.png",
            height = 312,
            line_length = 8,
            shift = { 1.5625, 0 },
            width = 452
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e12-tete-shadow.png",
            height = 156,
            line_length = 8,
            shift = { 1.5625, 0 },
            width = 226
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.17918 },
        projectile_creation_distance = 3.42298
      }
    },
    [13] = {
      boite = { { -4.125, -4.40625 }, { 4.125, 3.40625 } },
      bouches = {
        d00 = { 0, -4.04688 },
        d01 = { 0.36181, -4.03435 },
        d02 = { 0.72488, -4.00134 },
        d03 = { 1.08249, -3.93489 },
        d04 = { 1.42544, -3.84689 },
        d05 = { 1.74939, -3.72956 },
        d06 = { 2.06041, -3.59277 },
        d07 = { 2.34789, -3.43336 },
        d08 = { 2.60529, -3.25462 },
        d09 = { 2.83264, -3.06161 },
        d10 = { 3.03356, -2.85465 },
        d11 = { 3.21209, -2.62926 },
        d12 = { 3.34791, -2.39726 },
        d13 = { 3.45295, -2.15413 },
        d14 = { 3.5229, -1.91079 },
        d15 = { 3.55814, -1.65988 },
        d16 = { 3.5625, -1.41406 },
        d17 = { 3.55726, -1.16188 },
        d18 = { 3.52446, -0.92288 },
        d19 = { 3.45353, -0.67535 },
        d20 = { 3.35026, -0.43488 },
        d21 = { 3.21168, -0.20085 },
        d22 = { 3.03984, 0.01988 },
        d23 = { 2.83265, 0.23348 },
        d24 = { 2.60692, 0.42534 },
        d25 = { 2.34964, 0.60422 },
        d26 = { 2.05992, 0.76444 },
        d27 = { 1.74931, 0.90147 },
        d28 = { 1.42581, 1.01866 },
        d29 = { 1.08576, 1.10606 },
        d30 = { 0.72858, 1.17269 },
        d31 = { 0.36825, 1.20577 },
        d32 = { 0, 1.21875 },
        d33 = { -0.36349, 1.21011 },
        d34 = { -0.72569, 1.17322 },
        d35 = { -1.08601, 1.10544 },
        d36 = { -1.4219, 1.01617 },
        d37 = { -1.75032, 0.90194 },
        d38 = { -2.05949, 0.76594 },
        d39 = { -2.34307, 0.60552 },
        d40 = { -2.6061, 0.42726 },
        d41 = { -2.83512, 0.23351 },
        d42 = { -3.03525, 0.02292 },
        d43 = { -3.21144, -0.20557 },
        d44 = { -3.35357, -0.43595 },
        d45 = { -3.45528, -0.67156 },
        d46 = { -3.52568, -0.92029 },
        d47 = { -3.55907, -1.1671 },
        d48 = { -3.5625, -1.41406 },
        d49 = { -3.55881, -1.66295 },
        d50 = { -3.52413, -1.91338 },
        d51 = { -3.45579, -2.15536 },
        d52 = { -3.35169, -2.39538 },
        d53 = { -3.21036, -2.62398 },
        d54 = { -3.03648, -2.84974 },
        d55 = { -2.83538, -3.06141 },
        d56 = { -2.60918, -3.25321 },
        d57 = { -2.34637, -3.43173 },
        d58 = { -2.05504, -3.59616 },
        d59 = { -1.7504, -3.73004 },
        d60 = { -1.42177, -3.84433 },
        d61 = { -1.08274, -3.93427 },
        d62 = { -0.7271, -4.00224 },
        d63 = { -0.36584, -4.03861 }
      },
      ecart_max = 0.1446,
      ecarts_bouche = {
        d00 = { -0.1104, 0 },
        d01 = { -0.109, -0.0031 },
        d02 = { -0.1105, -0.0027 },
        d03 = { -0.1029, 0.0011 },
        d04 = { -0.0949, 0.0005 },
        d05 = { -0.0777, -0.0005 },
        d06 = { -0.0645, 0.0015 },
        d07 = { -0.0473, 0.0031 },
        d08 = { -0.0246, 0.0017 },
        d09 = { 0.0004, -0.0029 },
        d10 = { 0.0238, -0.0062 },
        d11 = { 0.0416, -0.0007 },
        d12 = { 0.067, -0.0021 },
        d13 = { 0.0897, 0.001 },
        d14 = { 0.1107, -0.0008 },
        d15 = { 0.1308, 0.0024 },
        d16 = { 0.1446, 0.0004 },
        d17 = { 0.1312, 0.0048 },
        d18 = { 0.1098, -0.0041 },
        d19 = { 0.0892, -0.0016 },
        d20 = { 0.0656, -0.0016 },
        d21 = { 0.0424, -0.0002 },
        d22 = { 0.0206, -0.0017 },
        d23 = { 0, 0.0036 },
        d24 = { -0.0257, -0.0029 },
        d25 = { -0.0486, -0.0044 },
        d26 = { -0.0646, -0.0007 },
        d27 = { -0.0784, 0.0011 },
        d28 = { -0.0958, -0.0004 },
        d29 = { -0.1043, -0.0041 },
        d30 = { -0.1118, -0.0008 },
        d31 = { -0.1103, -0.0033 },
        d32 = { -0.1112, 0 },
        d33 = { -0.1139, -0.0021 },
        d34 = { -0.1116, -0.0022 },
        d35 = { -0.1038, 0.0046 },
        d36 = { -0.0916, -0.0017 },
        d37 = { -0.0794, -0.0006 },
        d38 = { -0.0654, -0.0006 },
        d39 = { -0.0444, -0.0009 },
        d40 = { -0.0262, 0.0009 },
        d41 = { -0.0021, -0.0024 },
        d42 = { 0.0234, -0.003 },
        d43 = { 0.0443, 0.0046 },
        d44 = { 0.0627, 0.0036 },
        d45 = { 0.0867, -0.0017 },
        d46 = { 0.1083, 0.0017 },
        d47 = { 0.1297, 0.0005 },
        d48 = { 0.1446, -0.0004 },
        d49 = { 0.1299, 0.0006 },
        d50 = { 0.1092, 0.0032 },
        d51 = { 0.0866, -0.0004 },
        d52 = { 0.0639, -0.0008 },
        d53 = { 0.0451, -0.0036 },
        d54 = { 0.0232, 0.0005 },
        d55 = { -0.0018, 0.0013 },
        d56 = { -0.027, -0.0051 },
        d57 = { -0.0451, -0.0033 },
        d58 = { -0.0632, 0.0047 },
        d59 = { -0.0787, 0 },
        d60 = { -0.0909, 0.0014 },
        d61 = { -0.1024, -0.0016 },
        d62 = { -0.112, 0.0008 },
        d63 = { -0.1138, -0.0003 }
      },
      eclat = {
        lr = {
          direction_count = 64,
          filename = "__factorio-overhaul__/graphics/levels/gun/gun-e13-eclat.png",
          frame_count = 1,
          height = 326,
          line_length = 8,
          shift = { 0.015625, -1.40625 },
          width = 403
        }
      },
      eclat_visible = {
        d00 = { 0, -4.27543 },
        d01 = { 0.39658, -4.26165 },
        d02 = { 0.78933, -4.22046 },
        d03 = { 1.17449, -4.15224 },
        d04 = { 1.54834, -4.05765 },
        d05 = { 1.90727, -3.93762 },
        d06 = { 2.24784, -3.79328 },
        d07 = { 2.56676, -3.62603 },
        d08 = { 2.86096, -3.43749 },
        d09 = { 3.12761, -3.22946 },
        d10 = { 3.36414, -3.00395 },
        d11 = { 3.56827, -2.76313 },
        d12 = { 3.73804, -2.50933 },
        d13 = { 3.87181, -2.24498 },
        d14 = { 3.96829, -1.97263 },
        d15 = { 4.02655, -1.6949 },
        d16 = { 4.04603, -1.41448 },
        d17 = { 4.02655, -1.13406 },
        d18 = { 3.96829, -0.85633 },
        d19 = { 3.87181, -0.58398 },
        d20 = { 3.73804, -0.31963 },
        d21 = { 3.56827, -0.06583 },
        d22 = { 3.36414, 0.17499 },
        d23 = { 3.12761, 0.4005 },
        d24 = { 2.86096, 0.60853 },
        d25 = { 2.56676, 0.79707 },
        d26 = { 2.24784, 0.96432 },
        d27 = { 1.90727, 1.10866 },
        d28 = { 1.54834, 1.22869 },
        d29 = { 1.17449, 1.32328 },
        d30 = { 0.78933, 1.3915 },
        d31 = { 0.39658, 1.43269 },
        d32 = { 0, 1.44647 },
        d33 = { -0.39658, 1.43269 },
        d34 = { -0.78933, 1.3915 },
        d35 = { -1.17449, 1.32328 },
        d36 = { -1.54834, 1.22869 },
        d37 = { -1.90727, 1.10866 },
        d38 = { -2.24784, 0.96432 },
        d39 = { -2.56676, 0.79707 },
        d40 = { -2.86096, 0.60853 },
        d41 = { -3.12761, 0.4005 },
        d42 = { -3.36414, 0.17499 },
        d43 = { -3.56827, -0.06583 },
        d44 = { -3.73804, -0.31963 },
        d45 = { -3.87181, -0.58398 },
        d46 = { -3.96829, -0.85633 },
        d47 = { -4.02655, -1.13406 },
        d48 = { -4.04603, -1.41448 },
        d49 = { -4.02655, -1.6949 },
        d50 = { -3.96829, -1.97263 },
        d51 = { -3.87181, -2.24498 },
        d52 = { -3.73804, -2.50933 },
        d53 = { -3.56827, -2.76313 },
        d54 = { -3.36414, -3.00395 },
        d55 = { -3.12761, -3.22946 },
        d56 = { -2.86096, -3.43749 },
        d57 = { -2.56676, -3.62603 },
        d58 = { -2.24784, -3.79328 },
        d59 = { -1.90727, -3.93762 },
        d60 = { -1.54834, -4.05765 },
        d61 = { -1.17449, -4.15224 },
        d62 = { -0.78933, -4.22046 },
        d63 = { -0.39658, -4.26165 }
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
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e13-tete-glow.png",
            height = 382,
            line_length = 8,
            shift = { 0, -1.421875 },
            width = 528
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e13-tete-glow.png",
            height = 191,
            line_length = 8,
            shift = { 0, -1.421875 },
            width = 264
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e13-tete-main.png",
            height = 382,
            line_length = 8,
            shift = { 0, -1.421875 },
            width = 528
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e13-tete-main.png",
            height = 191,
            line_length = 8,
            shift = { 0, -1.421875 },
            width = 264
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e13-tete-shadow.png",
            height = 372,
            line_length = 8,
            shift = { 1.796875, 0 },
            width = 538
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e13-tete-shadow.png",
            height = 186,
            line_length = 8,
            shift = { 1.796875, 0 },
            width = 269
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.41448 },
        projectile_creation_distance = 4.04603
      }
    },
    [14] = {
      boite = { { -4.28125, -4.53125 }, { 4.28125, 3.375 } },
      bouches = {
        d00 = { 0, -4.1875 },
        d01 = { 0.38174, -4.17467 },
        d02 = { 0.76612, -4.13494 },
        d03 = { 1.13888, -4.06901 },
        d04 = { 1.49595, -3.97641 },
        d05 = { 1.84379, -3.85241 },
        d06 = { 2.16698, -3.71085 },
        d07 = { 2.47232, -3.53978 },
        d08 = { 2.74553, -3.35417 },
        d09 = { 2.993, -3.14965 },
        d10 = { 3.20066, -2.92957 },
        d11 = { 3.38523, -2.69261 },
        d12 = { 3.53091, -2.4518 },
        d13 = { 3.6469, -2.19377 },
        d14 = { 3.71925, -1.93401 },
        d15 = { 3.75824, -1.67382 },
        d16 = { 3.75, -1.41406 },
        d17 = { 3.75763, -1.14993 },
        d18 = { 3.71724, -0.88697 },
        d19 = { 3.64594, -0.63212 },
        d20 = { 3.53169, -0.37764 },
        d21 = { 3.38446, -0.1345 },
        d22 = { 3.20217, 0.09984 },
        d23 = { 2.99408, 0.3206 },
        d24 = { 2.75053, 0.52022 },
        d25 = { 2.46848, 0.71389 },
        d26 = { 2.16964, 0.88147 },
        d27 = { 1.84251, 1.02477 },
        d28 = { 1.50089, 1.14684 },
        d29 = { 1.13909, 1.24084 },
        d30 = { 0.76501, 1.30697 },
        d31 = { 0.38378, 1.3464 },
        d32 = { 0, 1.35938 },
        d33 = { -0.38248, 1.34432 },
        d34 = { -0.76359, 1.30839 },
        d35 = { -1.13458, 1.23957 },
        d36 = { -1.49908, 1.14697 },
        d37 = { -1.84176, 1.02591 },
        d38 = { -2.16693, 0.88404 },
        d39 = { -2.47332, 0.71185 },
        d40 = { -2.74619, 0.52463 },
        d41 = { -2.98728, 0.32297 },
        d42 = { -3.20552, 0.10183 },
        d43 = { -3.3878, -0.13338 },
        d44 = { -3.53468, -0.37817 },
        d45 = { -3.64346, -0.6315 },
        d46 = { -3.71769, -0.88858 },
        d47 = { -3.75924, -1.15368 },
        d48 = { -3.75, -1.41406 },
        d49 = { -3.759, -1.67619 },
        d50 = { -3.7185, -1.93669 },
        d51 = { -3.64442, -2.19439 },
        d52 = { -3.5339, -2.45128 },
        d53 = { -3.38856, -2.69373 },
        d54 = { -3.20989, -2.92533 },
        d55 = { -2.99049, -3.14833 },
        d56 = { -2.74429, -3.3541 },
        d57 = { -2.47062, -3.54154 },
        d58 = { -2.16427, -3.71342 },
        d59 = { -1.83882, -3.85706 },
        d60 = { -1.4999, -3.97486 },
        d61 = { -1.13948, -4.06664 },
        d62 = { -0.76223, -4.13671 },
        d63 = { -0.38579, -4.17839 }
      },
      ecart_max = 0.1551,
      ecarts_bouche = {
        d00 = { -0.1115, 0 },
        d01 = { -0.1105, -0.0028 },
        d02 = { -0.1081, 0.0007 },
        d03 = { -0.103, -0.0001 },
        d04 = { -0.0928, -0.0044 },
        d05 = { -0.0783, 0.0005 },
        d06 = { -0.0636, -0.0025 },
        d07 = { -0.0456, 0.0033 },
        d08 = { -0.0254, 0.001 },
        d09 = { -0.0057, 0.0011 },
        d10 = { 0.0226, -0.003 },
        d11 = { 0.0438, 0.0008 },
        d12 = { 0.0665, -0.0035 },
        d13 = { 0.0854, 0.0024 },
        d14 = { 0.1091, 0.0031 },
        d15 = { 0.1277, 0.0019 },
        d16 = { 0.1551, -0.0001 },
        d17 = { 0.128, 0.0024 },
        d18 = { 0.1101, 0.0042 },
        d19 = { 0.0859, -0.0002 },
        d20 = { 0.0662, 0.0019 },
        d21 = { 0.0441, 0.0003 },
        d22 = { 0.0219, 0.0008 },
        d23 = { -0.0061, -0.0025 },
        d24 = { -0.026, -0.0087 },
        d25 = { -0.0441, 0.0008 },
        d26 = { -0.0645, -0.0004 },
        d27 = { -0.0778, 0.0008 },
        d28 = { -0.094, -0.0007 },
        d29 = { -0.103, -0.0002 },
        d30 = { -0.1079, 0.0004 },
        d31 = { -0.1105, 0.0007 },
        d32 = { -0.1113, 0 },
        d33 = { -0.1083, -0.0017 },
        d34 = { -0.1088, -0.0022 },
        d35 = { -0.1, -0.0035 },
        d36 = { -0.0932, -0.001 },
        d37 = { -0.0782, -0.0021 },
        d38 = { -0.0645, -0.0033 },
        d39 = { -0.0464, 0.0039 },
        d40 = { -0.025, 0.0026 },
        d41 = { -0.0014, -0.003 },
        d42 = { 0.018, -0.0012 },
        d43 = { 0.0406, -0.0002 },
        d44 = { 0.0634, -0.0005 },
        d45 = { 0.0882, -0.001 },
        d46 = { 0.1099, -0.0025 },
        d47 = { 0.1267, 0.0015 },
        d48 = { 0.1551, 0.0001 },
        d49 = { 0.1268, 0.0004 },
        d50 = { 0.1095, -0.0003 },
        d51 = { 0.0877, -0.0013 },
        d52 = { 0.0638, 0.0021 },
        d53 = { 0.0402, -0.0009 },
        d54 = { 0.016, -0.0048 },
        d55 = { -0.0029, -0.0009 },
        d56 = { -0.0243, -0.0003 },
        d57 = { -0.0454, -0.0009 },
        d58 = { -0.0637, 0.0062 },
        d59 = { -0.079, 0.0063 },
        d60 = { -0.0935, 0.0002 },
        d61 = { -0.1011, -0.0014 },
        d62 = { -0.1088, 0.0035 },
        d63 = { -0.1148, -0.0007 }
      },
      eclat = {
        lr = {
          direction_count = 64,
          filename = "__factorio-overhaul__/graphics/levels/gun/gun-e14-eclat.png",
          frame_count = 1,
          height = 338,
          line_length = 8,
          shift = { 0.015625, -1.40625 },
          width = 419
        }
      },
      eclat_visible = {
        d00 = { 0, -4.41497 },
        d01 = { 0.41598, -4.40052 },
        d02 = { 0.82796, -4.35731 },
        d03 = { 1.23197, -4.28575 },
        d04 = { 1.62411, -4.18654 },
        d05 = { 2.00061, -4.06063 },
        d06 = { 2.35785, -3.90923 },
        d07 = { 2.69238, -3.73379 },
        d08 = { 3.00098, -3.53602 },
        d09 = { 3.28067, -3.31781 },
        d10 = { 3.52878, -3.08127 },
        d11 = { 3.7429, -2.82866 },
        d12 = { 3.92098, -2.56244 },
        d13 = { 4.06129, -2.28515 },
        d14 = { 4.16249, -1.99947 },
        d15 = { 4.2236, -1.70816 },
        d16 = { 4.24404, -1.41401 },
        d17 = { 4.2236, -1.11986 },
        d18 = { 4.16249, -0.82855 },
        d19 = { 4.06129, -0.54287 },
        d20 = { 3.92098, -0.26558 },
        d21 = { 3.7429, 0.00064 },
        d22 = { 3.52878, 0.25325 },
        d23 = { 3.28067, 0.48979 },
        d24 = { 3.00098, 0.708 },
        d25 = { 2.69238, 0.90577 },
        d26 = { 2.35785, 1.08121 },
        d27 = { 2.00061, 1.23261 },
        d28 = { 1.62411, 1.35852 },
        d29 = { 1.23197, 1.45773 },
        d30 = { 0.82796, 1.52929 },
        d31 = { 0.41598, 1.5725 },
        d32 = { 0, 1.58695 },
        d33 = { -0.41598, 1.5725 },
        d34 = { -0.82796, 1.52929 },
        d35 = { -1.23197, 1.45773 },
        d36 = { -1.62411, 1.35852 },
        d37 = { -2.00061, 1.23261 },
        d38 = { -2.35785, 1.08121 },
        d39 = { -2.69238, 0.90577 },
        d40 = { -3.00098, 0.708 },
        d41 = { -3.28067, 0.48979 },
        d42 = { -3.52878, 0.25325 },
        d43 = { -3.7429, 0.00064 },
        d44 = { -3.92098, -0.26558 },
        d45 = { -4.06129, -0.54287 },
        d46 = { -4.16249, -0.82855 },
        d47 = { -4.2236, -1.11986 },
        d48 = { -4.24404, -1.41401 },
        d49 = { -4.2236, -1.70816 },
        d50 = { -4.16249, -1.99947 },
        d51 = { -4.06129, -2.28515 },
        d52 = { -3.92098, -2.56244 },
        d53 = { -3.7429, -2.82866 },
        d54 = { -3.52878, -3.08127 },
        d55 = { -3.28067, -3.31781 },
        d56 = { -3.00098, -3.53602 },
        d57 = { -2.69238, -3.73379 },
        d58 = { -2.35785, -3.90923 },
        d59 = { -2.00061, -4.06063 },
        d60 = { -1.62411, -4.18654 },
        d61 = { -1.23197, -4.28575 },
        d62 = { -0.82796, -4.35731 },
        d63 = { -0.41598, -4.40052 }
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
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e14-tete-glow.png",
            height = 398,
            line_length = 8,
            shift = { 0, -1.421875 },
            width = 548
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e14-tete-glow.png",
            height = 199,
            line_length = 8,
            shift = { 0, -1.421875 },
            width = 274
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e14-tete-main.png",
            height = 398,
            line_length = 8,
            shift = { 0, -1.421875 },
            width = 548
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e14-tete-main.png",
            height = 199,
            line_length = 8,
            shift = { 0, -1.421875 },
            width = 274
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e14-tete-shadow.png",
            height = 388,
            line_length = 8,
            shift = { 1.796875, 0 },
            width = 558
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e14-tete-shadow.png",
            height = 194,
            line_length = 8,
            shift = { 1.796875, 0 },
            width = 279
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.41401 },
        projectile_creation_distance = 4.24404
      }
    },
    [15] = {
      boite = { { -4.5625, -4.71875 }, { 4.5625, 3.40625 } },
      bouches = {
        d00 = { 0, -4.40625 },
        d01 = { 0.41748, -4.39365 },
        d02 = { 0.82715, -4.3528 },
        d03 = { 1.2279, -4.27929 },
        d04 = { 1.62186, -4.17698 },
        d05 = { 1.98745, -4.04848 },
        d06 = { 2.34126, -3.88983 },
        d07 = { 2.67035, -3.70883 },
        d08 = { 2.95473, -3.51165 },
        d09 = { 3.23353, -3.28498 },
        d10 = { 3.4524, -3.05272 },
        d11 = { 3.65543, -2.79593 },
        d12 = { 3.81619, -2.53315 },
        d13 = { 3.93482, -2.25635 },
        d14 = { 4.0151, -1.98453 },
        d15 = { 4.05657, -1.6946 },
        d16 = { 4.0625, -1.41406 },
        d17 = { 4.05654, -1.13329 },
        d18 = { 4.01547, -0.84491 },
        d19 = { 3.93496, -0.57208 },
        d20 = { 3.81791, -0.29791 },
        d21 = { 3.65537, -0.03211 },
        d22 = { 3.4588, 0.21783 },
        d23 = { 3.23139, 0.4587 },
        d24 = { 2.95867, 0.68073 },
        d25 = { 2.66037, 0.88649 },
        d26 = { 2.34095, 1.06185 },
        d27 = { 1.99505, 1.21748 },
        d28 = { 1.61318, 1.34911 },
        d29 = { 1.2292, 1.45088 },
        d30 = { 0.82875, 1.52445 },
        d31 = { 0.41855, 1.56545 },
        d32 = { 0, 1.57812 },
        d33 = { -0.41361, 1.56926 },
        d34 = { -0.82721, 1.52588 },
        d35 = { -1.23051, 1.45282 },
        d36 = { -1.61875, 1.34937 },
        d37 = { -1.99138, 1.21678 },
        d38 = { -2.34181, 1.06273 },
        d39 = { -2.65985, 0.88554 },
        d40 = { -2.95526, 0.68449 },
        d41 = { -3.22749, 0.45965 },
        d42 = { -3.45694, 0.22578 },
        d43 = { -3.65852, -0.03075 },
        d44 = { -3.81526, -0.29661 },
        d45 = { -3.93469, -0.56882 },
        d46 = { -4.01485, -0.85052 },
        d47 = { -4.05877, -1.13369 },
        d48 = { -4.0625, -1.41406 },
        d49 = { -4.05851, -1.69635 },
        d50 = { -4.0145, -1.97886 },
        d51 = { -3.93378, -2.26141 },
        d52 = { -3.8172, -2.53048 },
        d53 = { -3.66052, -2.79473 },
        d54 = { -3.45989, -3.05033 },
        d55 = { -3.2299, -3.2857 },
        d56 = { -2.96075, -3.50873 },
        d57 = { -2.66983, -3.70788 },
        d58 = { -2.34212, -3.89071 },
        d59 = { -1.98378, -4.04777 },
        d60 = { -1.61571, -4.17839 },
        d61 = { -1.23126, -4.28079 },
        d62 = { -0.82443, -4.3544 },
        d63 = { -0.41695, -4.39715 }
      },
      ecart_max = 0.1498,
      ecarts_bouche = {
        d00 = { -0.113, 0 },
        d01 = { -0.114, 0.0024 },
        d02 = { -0.113, 0.0004 },
        d03 = { -0.1052, -0.0012 },
        d04 = { -0.0969, 0.0029 },
        d05 = { -0.0811, -0.0032 },
        d06 = { -0.0649, 0.0013 },
        d07 = { -0.0487, 0.0046 },
        d08 = { -0.0211, -0.0068 },
        d09 = { -0.0071, 0.0048 },
        d10 = { 0.0248, -0.0068 },
        d11 = { 0.0441, -0.0003 },
        d12 = { 0.0656, -0.0013 },
        d13 = { 0.0914, 0.0017 },
        d14 = { 0.1134, -0.0057 },
        d15 = { 0.1351, 0.002 },
        d16 = { 0.1498, 0 },
        d17 = { 0.1351, -0.0017 },
        d18 = { 0.1132, 0.0043 },
        d19 = { 0.0913, -0.002 },
        d20 = { 0.0648, -0.002 },
        d21 = { 0.0441, 0.0003 },
        d22 = { 0.0219, -0.0021 },
        d23 = { -0.0062, -0.0021 },
        d24 = { -0.0226, 0.0022 },
        d25 = { -0.0449, 0.0063 },
        d26 = { -0.0648, -0.001 },
        d27 = { -0.0834, -0.0047 },
        d28 = { -0.0928, 0.0047 },
        d29 = { -0.1054, -0.0001 },
        d30 = { -0.1132, -0.0021 },
        d31 = { -0.1141, -0.0035 },
        d32 = { -0.1129, 0 },
        d33 = { -0.1172, -0.0019 },
        d34 = { -0.1142, 0.0002 },
        d35 = { -0.1077, 0.0006 },
        d36 = { -0.0958, 0 },
        d37 = { -0.0806, 0.0022 },
        d38 = { -0.066, 0.001 },
        d39 = { -0.0439, -0.0059 },
        d40 = { -0.022, -0.0072 },
        d41 = { -0.0033, -0.0007 },
        d42 = { 0.0202, -0.0059 },
        d43 = { 0.0407, -0.0005 },
        d44 = { 0.067, 0 },
        d45 = { 0.0909, -0.0012 },
        d46 = { 0.1146, 0.0012 },
        d47 = { 0.1329, 0.0023 },
        d48 = { 0.1498, 0 },
        d49 = { 0.133, -0.0003 },
        d50 = { 0.1147, 0.0002 },
        d51 = { 0.0914, 0.0035 },
        d52 = { 0.0654, -0.0015 },
        d53 = { 0.0398, -0.0027 },
        d54 = { 0.0191, 0.0014 },
        d55 = { -0.0043, -0.0023 },
        d56 = { -0.0243, 0.0009 },
        d57 = { -0.0477, -0.0049 },
        d58 = { -0.0662, -0.0013 },
        d59 = { -0.0784, 0.0056 },
        d60 = { -0.095, 0.0031 },
        d61 = { -0.1079, -0.0013 },
        d62 = { -0.1138, 0.0026 },
        d63 = { -0.1174, -0.0014 }
      },
      eclat = {
        lr = {
          direction_count = 64,
          filename = "__factorio-overhaul__/graphics/levels/gun/gun-e15-eclat.png",
          frame_count = 1,
          height = 404,
          line_length = 8,
          shift = { 0, -1.40625 },
          width = 490
        }
      },
      eclat_visible = {
        d00 = { 0, -4.63221 },
        d01 = { 0.44609, -4.61671 },
        d02 = { 0.88789, -4.57038 },
        d03 = { 1.32113, -4.49364 },
        d04 = { 1.74166, -4.38725 },
        d05 = { 2.14541, -4.25222 },
        d06 = { 2.5285, -4.08986 },
        d07 = { 2.88724, -3.90173 },
        d08 = { 3.21818, -3.68964 },
        d09 = { 3.51812, -3.45564 },
        d10 = { 3.78418, -3.20198 },
        d11 = { 4.0138, -2.93109 },
        d12 = { 4.20476, -2.6456 },
        d13 = { 4.35523, -2.34824 },
        d14 = { 4.46376, -2.04189 },
        d15 = { 4.52929, -1.72949 },
        d16 = { 4.55121, -1.41405 },
        d17 = { 4.52929, -1.09861 },
        d18 = { 4.46376, -0.78621 },
        d19 = { 4.35523, -0.47986 },
        d20 = { 4.20476, -0.1825 },
        d21 = { 4.0138, 0.10299 },
        d22 = { 3.78418, 0.37388 },
        d23 = { 3.51812, 0.62754 },
        d24 = { 3.21818, 0.86154 },
        d25 = { 2.88724, 1.07363 },
        d26 = { 2.5285, 1.26176 },
        d27 = { 2.14541, 1.42412 },
        d28 = { 1.74166, 1.55915 },
        d29 = { 1.32113, 1.66554 },
        d30 = { 0.88789, 1.74228 },
        d31 = { 0.44609, 1.78861 },
        d32 = { 0, 1.80411 },
        d33 = { -0.44609, 1.78861 },
        d34 = { -0.88789, 1.74228 },
        d35 = { -1.32113, 1.66554 },
        d36 = { -1.74166, 1.55915 },
        d37 = { -2.14541, 1.42412 },
        d38 = { -2.5285, 1.26176 },
        d39 = { -2.88724, 1.07363 },
        d40 = { -3.21818, 0.86154 },
        d41 = { -3.51812, 0.62754 },
        d42 = { -3.78418, 0.37388 },
        d43 = { -4.0138, 0.10299 },
        d44 = { -4.20476, -0.1825 },
        d45 = { -4.35523, -0.47986 },
        d46 = { -4.46376, -0.78621 },
        d47 = { -4.52929, -1.09861 },
        d48 = { -4.55121, -1.41405 },
        d49 = { -4.52929, -1.72949 },
        d50 = { -4.46376, -2.04189 },
        d51 = { -4.35523, -2.34824 },
        d52 = { -4.20476, -2.6456 },
        d53 = { -4.0138, -2.93109 },
        d54 = { -3.78418, -3.20198 },
        d55 = { -3.51812, -3.45564 },
        d56 = { -3.21818, -3.68964 },
        d57 = { -2.88724, -3.90173 },
        d58 = { -2.5285, -4.08986 },
        d59 = { -2.14541, -4.25222 },
        d60 = { -1.74166, -4.38725 },
        d61 = { -1.32113, -4.49364 },
        d62 = { -0.88789, -4.57038 },
        d63 = { -0.44609, -4.61671 }
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
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e15-tete-glow.png",
            height = 424,
            line_length = 8,
            shift = { 0, -1.40625 },
            width = 584
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e15-tete-glow.png",
            height = 212,
            line_length = 8,
            shift = { 0, -1.40625 },
            width = 292
          }
        },
        main = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e15-tete-main.png",
            height = 424,
            line_length = 8,
            shift = { 0, -1.40625 },
            width = 584
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e15-tete-main.png",
            height = 212,
            line_length = 8,
            shift = { 0, -1.40625 },
            width = 292
          }
        },
        shadow = {
          hr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/hr-gun-e15-tete-shadow.png",
            height = 412,
            line_length = 8,
            shift = { 1.796875, 0 },
            width = 594
          },
          lr = {
            direction_count = 64,
            filename = "__factorio-overhaul__/graphics/levels/gun/gun-e15-tete-shadow.png",
            height = 206,
            line_length = 8,
            shift = { 1.796875, 0 },
            width = 297
          }
        }
      },
      tir = {
        projectile_center = { 0, -0.41405 },
        projectile_creation_distance = 4.55121
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
