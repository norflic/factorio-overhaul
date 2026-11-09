--[[
  Lot MOTIFS : motifs du DÉBUT de partie (demande du chef d'équipe, 8/11 : « aucun module de fabrication n'est fini avant 40 min »).
  Familles « energie » (centrale à vapeur extensible), « labo » (laboratoires en rangée), « science » (packs rouges et verts dédiés :
  producteur de tête + une assembleuse de packs par tuile), et « mine » (foreuses de charbon en boucle de combustible).
  Jetons : A, B, C… = matières ; S = vapeur, E = courant (kW), R = recherche, P = produit, combustible.
  Un PRODUCTEUR DE TÊTE est un groupe de machines placé dans la tête du motif : il existe une fois pour toute la rangée (groupe « fixe » du
  dérivé) et borne le NOMBRE de tuiles qu'il sert (engrenages : 1 machine pour 10 assembleuses de packs rouges, calculé d'après les recettes).
  Rien n'est prouvé en moteur réel : géométrie vérifiée hors jeu, débit estimé.
]]

local function need(dotted, slashed)
  local ok, res = pcall(require, dotted)
  if ok and type(res) == "table" then return res end
  return require("__factorio-overhaul__/" .. slashed)
end
local D = need("shared.team.motifs.dsl", "shared/team/motifs/dsl")
local h = D.h
local N, E, S, W = D.N, D.E, D.S, D.W

local SRC_VAPEUR = { "https://wiki.factorio.com/Steam_engine", "https://wiki.factorio.com/Boiler", "https://wiki.factorio.com/Offshore_pump",
  "https://wiki.factorio.com/Power_production" }
local SRC_LABO = { "https://wiki.factorio.com/Lab", "https://wiki.factorio.com/Inserters" }
local SRC_SCI = { "https://wiki.factorio.com/Science_pack", "https://wiki.factorio.com/Automation_science_pack", "https://wiki.factorio.com/Logistic_science_pack" }
local SRC_MINE = { "https://wiki.factorio.com/Burner_mining_drill", "https://forums.factorio.com/viewtopic.php?p=158464" }

local L = {}

local function brasc(role_fn, ...)
  local t = role_fn(...)
  t.combustion = true
  return t
end

---------------------------------------------------------------------------------------------------
-- 1. Centrale à vapeur : une chaudière et deux machines à vapeur par tuile (rapport 1 : 2), eau en chaîne, charbon par bras à combustion
---------------------------------------------------------------------------------------------------
L[#L + 1] = {
  id = "centrale-vapeur-rangee", famille = "energie", usages = { "energie", "vapeur" }, origine = "derive",
  source = SRC_VAPEUR,
  nom_fr = "Centrale à vapeur extensible : pompe, chaudières, machines à vapeur (1 : 2)",
  nom_en = "Extensible steam plant: pump, boilers, steam engines (1:2)",
  note_fr = "Même disposition que le gabarit « centrale » de modules.lua, en tuiles : une chaudière 3 × 2 et, au-dessus, deux machines à vapeur "
    .. "3 × 5 empilées (la vapeur passe par contact) ; l'eau traverse les chaudières par un tuyau dans le passage de la tuile ; la pompe de rive est "
    .. "dans la tête (à l'ouest, sur le raccord d'eau de la première chaudière) ; deux bras à combustion par chaudière prennent le charbon sur un tapis "
    .. "qui entre à l'est. Une tuile : 1,8 MW. Une pompe alimente 20 chaudières au plus (1 200 / 60 par seconde).",
  max_tuiles = 20,
  art = {
    "vvv.",
    "vvv.",
    "vvv+",
    "vvv.",
    "vvv.",
    "uuu.",
    "uuu.",
    "uuu+",
    "uuu.",
    "uuu.",
    "bbb.",
    "bbbp",
    "a.a.",
    "cccc",
  },
  legende = {
    v = { role = "machine_vapeur", w = 3, h = 5, groupe = "vapeur" }, u = { role = "machine_vapeur", w = 3, h = 5, groupe = "vapeur" },
    b = { role = "chaudiere", w = 3, h = 2, groupe = "chaudiere", dir = N, fluides_entree = { "F1", "F1" }, fluides_sortie = { false } },
    p = h.tuyau("F1"), c = h.entree(1, W),
    a = brasc(h.bras, S, "tapis_entree:1", "chaudiere", "ent"),
    ["+"] = h.poteau,
  },
  tete = {
    art = { ".", ".", ".", ".", ".", ".", ".", ".", ".", ".", ".", "P", ".", "c" },
    legende = { P = { role = "pompe", dir = W, fluide = "F1" }, c = h.entree(1, W) },
  },
  fluides = { { io = "in", jeton = "F1", x = 0, y = 11, cote = "O" } },
  entrees = { { k = 1, cote = "E", pos = 13, jetons = { combustible = { 1, 2 } } } },
  sorties = {},
  produits = { "E" },
  liens = { ent = { groupe = "chaudiere", io = "in", jetons = { "combustible" } } },
  chaines = { { amont = "chaudiere", aval = "vapeur", jeton = "S", contact = true } },
}

---------------------------------------------------------------------------------------------------
-- 2. Laboratoires en rangée : par tapis (une face, deux faces) ou par bras en chaîne
---------------------------------------------------------------------------------------------------
local function labo() return h.machine("machine_labo", 3, "principal") end

L[#L + 1] = {
  id = "labo-rangee-tapis", famille = "labo", usages = { "labo", "recherche" }, origine = "derive",
  source = SRC_LABO,
  nom_fr = "Laboratoires en rangée sur un tapis de packs",
  nom_en = "Lab row on a science pack belt",
  note_fr = "Un tapis porte les packs (un type par voie) ; chaque laboratoire en prend avec deux bras. Période 4.",
  produits = { "R" },
  art = {
    "cccc",
    ".ii.",
    "mmm.",
    "mmm+",
    "mmm.",
  },
  legende = { c = h.entree(1, E), m = labo(), i = h.bras(N, "tapis_entree:1", "machine_labo", "ent"), ["+"] = h.poteau },
  entrees = { { k = 1, cote = "O", pos = 0, jetons = { A = { 1 }, B = { 2 } } } },
  sorties = {},
  liens = { ent = { groupe = "principal", io = "in", jetons = { "A", "B" } } },
}

L[#L + 1] = {
  id = "labo-rangee-miroir", famille = "labo", usages = { "labo", "recherche" }, origine = "derive",
  source = SRC_LABO,
  nom_fr = "Laboratoires en rangée, deux faces sur un même tapis de packs",
  nom_en = "Lab row, two faces on one science pack belt",
  note_fr = "Le tapis de packs au milieu nourrit un laboratoire au nord et un au sud par tuile : le double de laboratoires pour la même longueur de tapis.",
  produits = { "R" },
  art = {
    "mmm.",
    "mmm.",
    "mmm+",
    ".ii.",
    "cccc",
    ".jj.",
    "nnn+",
    "nnn.",
    "nnn.",
  },
  legende = {
    c = h.entree(1, E), m = labo(), n = labo(),
    i = h.bras(S, "tapis_entree:1", "machine_labo", "ent_h"), j = h.bras(N, "tapis_entree:1", "machine_labo", "ent_b"),
    ["+"] = h.poteau,
  },
  entrees = { { k = 1, cote = "O", pos = 4, jetons = { A = { 1 }, B = { 2 } } } },
  sorties = {},
  liens = { ent_h = { groupe = "principal", io = "in", jetons = { "A", "B" } }, ent_b = { groupe = "principal", io = "in", jetons = { "A", "B" } } },
}

L[#L + 1] = {
  id = "labo-chaine-bras", famille = "labo", usages = { "labo", "recherche", "chaine" }, origine = "derive",
  source = SRC_LABO,
  nom_fr = "Laboratoires en chaîne : un bras passe les packs d'un laboratoire au suivant",
  nom_en = "Lab chain: an inserter passes packs from one lab to the next",
  note_fr = "Aucun tapis le long de la rangée : un seul bras en tête prend les packs sur le tapis d'entrée et chaque laboratoire les passe au suivant. "
    .. "Le nombre de laboratoires est borné par ce que les bras portent (le premier bras porte les packs de tous les suivants) ; la queue pose le dernier laboratoire.",
  produits = { "R" },
  serie_directe = { ent = 0, mid = 1 },
  art = {
    "....",
    "mmm.",
    "mmmw",
    "mmm+",
    "....",
  },
  legende = {
    m = labo(), w = h.bras(W, "machine_labo", "machine_labo", "mid"), ["+"] = h.poteau,
  },
  tete = {
    art = {
      "..",
      "..",
      "ct",
      ".+",
      "..",
    },
    legende = { c = h.entree(1, E), t = h.bras(W, "tapis_entree:1", "machine_labo", "ent"), ["+"] = h.poteau },
  },
  queue = {
    art = {
      "...",
      "mmm",
      "mmm",
      "mmm",
      "...",
    },
    legende = { m = labo() },
  },
  entrees = { { k = 1, cote = "O", pos = 2, jetons = { A = { 1 }, B = { 2 } } } },
  sorties = {},
  liens = {
    ent = { groupe = "principal", io = "in", jetons = { "A", "B" } },
    mid = { groupe = "principal", io = "in", interne = true, jetons = { "A", "B" } },
  },
}

---------------------------------------------------------------------------------------------------
-- 3. Packs rouges et verts : producteur(s) de tête + une assembleuse de packs par tuile
---------------------------------------------------------------------------------------------------
L[#L + 1] = {
  id = "packs-rouges-rangee", famille = "science", usages = { "science", "packs-rouges" }, origine = "derive",
  source = SRC_SCI,
  nom_fr = "Packs rouges : une assembleuse d'engrenages en tête, une assembleuse de packs par tuile",
  nom_en = "Red science: one gear assembler at the head, one pack assembler per tile",
  note_fr = "Le tapis du haut porte le cuivre (voie 2) et reçoit les engrenages de la machine de tête (voie 1) ; chaque tuile fabrique des packs "
    .. "avec les deux. Le nombre de tuiles servies par la machine d'engrenages (1 pour 10 à vitesses égales) est calculé d'après les recettes.",
  art = {
    "cccc",
    ".ii.",
    "mmm.",
    "mmm+",
    "mmm.",
    ".oo.",
    "aaaa",
  },
  legende = {
    c = h.entree(1, E), a = h.sortie(1, E), m = h.machine("machine_asm", 3, "pack"),
    i = h.bras(N, "tapis_entree:1", "machine_asm", "ent"), o = h.bras(N, "machine_asm", "tapis_sortie:1", "sort"),
    ["+"] = h.poteau,
  },
  tete = {
    art = {
      "ccccc",
      "..ss.",
      ".mmm.",
      ".mmm+",
      ".mmm.",
      "..tt.",
      "ffff.",
    },
    legende = {
      c = h.entree(1, E), f = h.entree(2, E), m = h.machine("machine_asm", 3, "engrenage"),
      s = h.bras(S, "machine_asm", "tapis_entree:1", "sort_g"), t = h.bras(S, "tapis_entree:2", "machine_asm", "ent_g"),
      ["+"] = h.poteau,
    },
  },
  entrees = {
    { k = 1, cote = "O", pos = 0, jetons = { A = { 2 }, B = { 1 } } },
    { k = 2, cote = "O", pos = 6, jetons = { C = { 1, 2 } } },
  },
  sorties = { { k = 1, cote = "E", pos = 6, jetons = { P = { 2 } } } },
  liens = {
    ent = { groupe = "pack", io = "in", jetons = { "A", "B" } }, sort = { groupe = "pack", io = "out", jetons = { "P" } },
    ent_g = { groupe = "engrenage", io = "in", jetons = { "C" } }, sort_g = { groupe = "engrenage", io = "out", interne = true, jetons = { "B" } },
  },
  chaines = { { amont = "engrenage", aval = "pack", jeton = "B" } },
}

L[#L + 1] = {
  id = "packs-verts-rangee", famille = "science", usages = { "science", "packs-verts" }, origine = "derive",
  source = SRC_SCI,
  nom_fr = "Packs verts : machines de bras et de tapis en tête, une assembleuse de packs par tuile",
  nom_en = "Green science: inserter and belt makers at the head, one pack assembler per tile",
  note_fr = "Deux tapis naissent dans la tête : les bras (tapis proche) et les convoyeurs (tapis lointain, bras long) ; chaque tuile prend un de chaque. "
    .. "Le rapport réel est calculé d'après les recettes : une machine de bras sert 12 assembleuses de packs, une machine de convoyeurs 24. Deux tapis "
    .. "d'entrée (fer et engrenages ; circuits) alimentent la tête.",
  art = {
    "dddd",
    "cccc",
    ".LI.",
    "mmm.",
    "mmm+",
    "mmm.",
    "..o.",
    "aaaa",
    "....",
  },
  legende = {
    c = { role = "tapis", k = 1, dir = E, bout = true }, d = { role = "tapis", k = 2, dir = E, bout = true }, a = h.sortie(1, E),
    m = h.machine("machine_asm", 3, "pack"),
    I = h.bras(N, "tapis:1", "machine_asm", "ent"), L = h.bras_long(N, "tapis:2", "machine_asm", "ent"),
    o = h.bras(N, "machine_asm", "tapis_sortie:1", "sort"), ["+"] = h.poteau,
  },
  tete = {
    art = {
      "ddddddddd",
      "ccccccccc",
      "..s...LL.",
      "+mmm+nnn+",
      ".mmm.nnn.",
      ".mmm.nnn.",
      "+ttT+uu..",
      "xxxxxxx..",
      "yyyy.....",
    },
    legende = {
      d = { role = "tapis", k = 2, dir = E, origine = true }, c = { role = "tapis", k = 1, dir = E, origine = true },
      x = h.entree(3, E), y = h.entree(4, E),
      m = h.machine("machine_asm", 3, "bras"), n = h.machine("machine_asm", 3, "tapis"),
      s = h.bras(S, "machine_asm", "tapis:1", "sort_b"), L = h.bras_long(S, "machine_asm", "tapis:2", "sort_t"),
      t = h.bras(S, "tapis_entree:3", "machine_asm", "ent_b1"), T = h.bras_long(S, "tapis_entree:4", "machine_asm", "ent_b2"),
      u = h.bras(S, "tapis_entree:3", "machine_asm", "ent_t"),
      ["+"] = h.poteau,
    },
  },
  entrees = {
    { k = 3, cote = "O", pos = 7, jetons = { D = { 1 }, E = { 2 } } },
    { k = 4, cote = "O", pos = 8, jetons = { F = { 1, 2 } } },
  },
  sorties = { { k = 1, cote = "E", pos = 7, jetons = { P = { 2 } } } },
  liens = {
    ent = { groupe = "pack", io = "in", interne = true, jetons = { "B", "C" } }, sort = { groupe = "pack", io = "out", jetons = { "P" } },
    ent_b1 = { groupe = "bras", io = "in", jetons = { "D", "E" } }, ent_b2 = { groupe = "bras", io = "in", jetons = { "F" } },
    ent_t = { groupe = "tapis", io = "in", jetons = { "D", "E" } },
    sort_b = { groupe = "bras", io = "out", interne = true, jetons = { "B" } }, sort_t = { groupe = "tapis", io = "out", interne = true, jetons = { "C" } },
  },
  chaines = { { amont = "bras", aval = "pack", jeton = "B" }, { amont = "tapis", aval = "pack", jeton = "C" } },
}
---------------------------------------------------------------------------------------------------
-- 4. Foreuses de charbon en boucle de combustible (démarrage thermique)
---------------------------------------------------------------------------------------------------
L[#L + 1] = {
  id = "foreuses-boucle-charbon", famille = "mine", usages = { "extraction", "bootstrap" }, origine = "derive",
  source = SRC_MINE,
  nom_fr = "Paire de foreuses à combustion en boucle de combustible",
  nom_en = "Burner drill pair in a fuel loop",
  note_fr = "Deux foreuses face à face : chacune dépose son charbon dans un coffre, et un bras à combustion reprend le charbon du coffre de l'autre "
    .. "pour la recharger. Elles se tiennent seules ; le surplus s'accumule dans les coffres (quai de collecte). Période 6 : se colle en série. "
    .. "Le débit annoncé est brut (le combustible brûlé par les foreuses n'est pas déduit).",
  produits = { "P" },
  art = {
    "AAckBB",
    "AAeCBB",
  },
  legende = {
    A = h.machine("foreuse", 2, "principal", { dir = E, combustion = true }), B = h.machine("foreuse", 2, "principal", { dir = W, combustion = true }),
    c = h.coffre(1), C = h.coffre(2),
    k = brasc(h.bras, W, "coffre", "foreuse", "rech"), e = brasc(h.bras, E, "coffre", "foreuse", "rech"),
  },
  entrees = {},
  sorties = {},
  liens = { rech = { groupe = "principal", io = "in", interne = true, jetons = { "combustible" } } },
}

return L
