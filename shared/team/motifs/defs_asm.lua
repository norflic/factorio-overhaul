--[[
  Lot MOTIFS : assembleurs (famille « asm » : tuiles de mall, chaînes à insertion directe, circuits). Définitions lues par
  shared/team/motifs/catalogue.lua. Jetons : A, B, C = matières entrantes (ordre de la recette), P = produit, M, X, Y =
  intermédiaires de chaîne (insertion directe), Q = produit déposé en coffre. Aucun nom d'objet : machine_asm, bras,
  bras_long, tapis_*, poteau, coffre.
]]

local function need(dotted, slashed)
  local ok, res = pcall(require, dotted)
  if ok and type(res) == "table" then return res end
  return require("__factorio-overhaul__/" .. slashed)
end
local D = need("shared.team.motifs.dsl", "shared/team/motifs/dsl")
local h = D.h
local N, E, S, W = D.N, D.E, D.S, D.W

local SRC_MALL = { "https://wiki.factorio.com/Inserters", "https://wiki.factorio.com/Tutorial:Main_bus" }
local SRC_CIRC = { "https://wiki.factorio.com/Electronic_circuit", "https://wiki.factorio.com/Green_circuit",
  "https://forums.factorio.com/viewtopic.php?p=62228", "https://forums.factorio.com/viewtopic.php?p=204665" }

local function asm(groupe) return h.machine("machine_asm", 3, groupe) end

local L = {}

---------------------------------------------------------------------------------------------------
-- 1. Tuile élémentaire : un assembleur, un à trois tapis d'entrée, un tapis de sortie
---------------------------------------------------------------------------------------------------
L[#L + 1] = {
  id = "asm-1e-1s", famille = "asm", usages = { "mall", "assemblage" }, origine = "derive",
  source = SRC_MALL,
  nom_fr = "Tuile d'assemblage à 1 entrée, 1 sortie",
  nom_en = "Assembler tile, 1 input, 1 output",
  note_fr = "Un assembleur entre un tapis d'entrée au nord et un tapis de sortie au sud ; deux bras de chaque côté.",
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
    c = h.entree(1, E), a = h.sortie(1, E), m = asm(),
    i = h.bras(N, "tapis_entree:1", "machine_asm", "ent_a"), o = h.bras(N, "machine_asm", "tapis_sortie:1", "sort"),
    ["+"] = h.poteau,
  },
  entrees = { { k = 1, cote = "O", pos = 0, jetons = { A = { 1, 2 } } } },
  sorties = { { k = 1, cote = "E", pos = 6, jetons = { P = { 2 } } } },
  liens = { ent_a = { groupe = "principal", io = "in", jetons = { "A" } }, sort = { groupe = "principal", io = "out", jetons = { "P" } } },
}

L[#L + 1] = {
  id = "asm-2e-1s", famille = "asm", usages = { "mall", "assemblage" }, origine = "ref_dc",
  ref = "Patern1.png", source = SRC_MALL,
  nom_fr = "Tuile d'assemblage à 2 entrées, 1 sortie (référence du DC)",
  nom_en = "Assembler tile, 2 inputs, 1 output (DC reference)",
  note_fr = "Référence du DC : un assembleur entre deux tapis d'entrée en haut (bras court sur le premier, bras long vers le second) "
    .. "et un tapis de sortie en bas ; poteau dans la case libre.",
  art = {
    "dddd",
    "cccc",
    ".LI.",
    "mmm.",
    "mmm+",
    "mmm.",
    "..o.",
    "aaaa",
  },
  legende = {
    c = h.entree(1, E), d = h.entree(2, E), a = h.sortie(1, E), m = asm(),
    I = h.bras(N, "tapis_entree:1", "machine_asm", "ent_a"), L = h.bras_long(N, "tapis_entree:2", "machine_asm", "ent_b"),
    o = h.bras(N, "machine_asm", "tapis_sortie:1", "sort"),
    ["+"] = h.poteau,
  },
  entrees = { { k = 1, cote = "O", pos = 1, jetons = { A = { 1, 2 } } }, { k = 2, cote = "O", pos = 0, jetons = { B = { 1, 2 } } } },
  sorties = { { k = 1, cote = "E", pos = 7, jetons = { P = { 2 } } } },
  liens = {
    ent_a = { groupe = "principal", io = "in", jetons = { "A" } }, ent_b = { groupe = "principal", io = "in", jetons = { "B" } },
    sort = { groupe = "principal", io = "out", jetons = { "P" } },
  },
}

L[#L + 1] = {
  id = "asm-3e-1s", famille = "asm", usages = { "mall", "assemblage" }, origine = "derive",
  source = SRC_MALL,
  nom_fr = "Tuile d'assemblage à 3 entrées, 1 sortie",
  nom_en = "Assembler tile, 3 inputs, 1 output",
  note_fr = "Deux tapis d'entrée au nord (bras court, bras long) ; au sud, le troisième tapis d'entrée contre la machine et le tapis de sortie "
    .. "derrière lui (bras long de sortie qui passe par-dessus).",
  art = {
    "dddd",
    "cccc",
    ".LI.",
    "mmm.",
    "mmm+",
    "mmm.",
    ".OJ.",
    "eeee",
    "aaaa",
  },
  legende = {
    c = h.entree(1, E), d = h.entree(2, E), e = h.entree(3, E), a = h.sortie(1, E), m = asm(),
    I = h.bras(N, "tapis_entree:1", "machine_asm", "ent_a"), L = h.bras_long(N, "tapis_entree:2", "machine_asm", "ent_b"),
    J = h.bras(S, "tapis_entree:3", "machine_asm", "ent_c"), O = h.bras_long(N, "machine_asm", "tapis_sortie:1", "sort"),
    ["+"] = h.poteau,
  },
  entrees = { { k = 1, cote = "O", pos = 1, jetons = { A = { 1, 2 } } }, { k = 2, cote = "O", pos = 0, jetons = { B = { 1, 2 } } },
    { k = 3, cote = "O", pos = 7, jetons = { C = { 1, 2 } } } },
  sorties = { { k = 1, cote = "E", pos = 8, jetons = { P = { 2 } } } },
  liens = {
    ent_a = { groupe = "principal", io = "in", jetons = { "A" } }, ent_b = { groupe = "principal", io = "in", jetons = { "B" } },
    ent_c = { groupe = "principal", io = "in", jetons = { "C" } }, sort = { groupe = "principal", io = "out", jetons = { "P" } },
  },
}

---------------------------------------------------------------------------------------------------
-- 2. Rangées en miroir : deux assembleurs par tuile sur les deux mêmes tapis d'entrée centraux
---------------------------------------------------------------------------------------------------
L[#L + 1] = {
  id = "asm-miroir-2e", famille = "asm", usages = { "mall", "assemblage" }, origine = "derive",
  source = SRC_MALL,
  nom_fr = "Deux rangées d'assembleurs en miroir sur 2 tapis d'entrée centraux",
  nom_en = "Mirrored assembler rows on two central input belts",
  note_fr = "Deux tapis d'entrée au milieu, un assembleur au nord et un au sud par tuile, sorties sur les tapis extérieurs : "
    .. "densité maximale pour une recette à 2 entrées.",
  art = {
    "aaaa",
    "..s.",
    "mmm.",
    "mmm+",
    "mmm.",
    ".LI.",
    "cccc",
    "dddd",
    ".lj.",
    "nnn.",
    "nnn+",
    "nnn.",
    "..o.",
    "bbbb",
  },
  legende = {
    a = h.sortie(1, E), b = h.sortie(2, E), c = h.entree(1, E), d = h.entree(2, E), m = asm(), n = asm(),
    s = h.bras(S, "machine_asm", "tapis_sortie:1", "sort_h"),
    I = h.bras(S, "tapis_entree:1", "machine_asm", "a_h"), L = h.bras_long(S, "tapis_entree:2", "machine_asm", "b_h"),
    j = h.bras(N, "tapis_entree:2", "machine_asm", "b_b"), l = h.bras_long(N, "tapis_entree:1", "machine_asm", "a_b"),
    o = h.bras(N, "machine_asm", "tapis_sortie:2", "sort_b"),
    ["+"] = h.poteau,
  },
  entrees = { { k = 1, cote = "O", pos = 6, jetons = { A = { 1, 2 } } }, { k = 2, cote = "O", pos = 7, jetons = { B = { 1, 2 } } } },
  sorties = { { k = 1, cote = "E", pos = 0, jetons = { P = { 1 } } }, { k = 2, cote = "E", pos = 13, jetons = { P = { 2 } } } },
  liens = {
    a_h = { groupe = "principal", io = "in", jetons = { "A" } }, b_h = { groupe = "principal", io = "in", jetons = { "B" } },
    a_b = { groupe = "principal", io = "in", jetons = { "A" } }, b_b = { groupe = "principal", io = "in", jetons = { "B" } },
    sort_h = { groupe = "principal", io = "out", jetons = { "P" } }, sort_b = { groupe = "principal", io = "out", jetons = { "P" } },
  },
}

---------------------------------------------------------------------------------------------------
-- 3. Grille 3 × N à insertion directe (Mall1.png) : deux étages amont nourrissent l'étage central
---------------------------------------------------------------------------------------------------
L[#L + 1] = {
  id = "asm-grille-3-directe", famille = "asm", usages = { "mall", "chaine" }, origine = "ref_dc",
  ref = "Mall1.png", source = SRC_MALL,
  nom_fr = "Colonne de 3 assembleurs à insertion directe (grille 3 × N)",
  nom_en = "3-assembler column with direct insertion (3 x N grid)",
  note_fr = "Référence du DC : chaque colonne de la grille porte 3 machines ; la machine du haut et celle du bas prennent chacune sur un tapis "
    .. "d'entrée (haut, bas) et passent leur produit à celle du milieu par insertion directe ; la machine du milieu dépose son produit dans un "
    .. "coffre (quai). Les colonnes se collent de gauche à droite, chacune pouvant faire une recette différente.",
  art = {
    "ccccc",
    ".i.+.",
    "mmm..",
    "mmm..",
    "mmm..",
    ".d.+.",
    "nnn..",
    "nnnqk",
    "nnn..",
    ".e.+.",
    "ppp..",
    "ppp..",
    "ppp..",
    ".j.+.",
    "zzzzz",
  },
  legende = {
    c = h.entree(1, E), z = h.entree(2, E), m = asm("amont_a"), n = asm("aval"), p = asm("amont_b"),
    i = h.bras(N, "tapis_entree:1", "machine_asm", "ent_a"),
    d = h.bras(N, "machine_asm", "machine_asm", "mid_a"), e = h.bras(S, "machine_asm", "machine_asm", "mid_b"),
    j = h.bras(S, "tapis_entree:2", "machine_asm", "ent_b"),
    q = h.bras(W, "machine_asm", "coffre", "sort"), k = h.coffre(1),
    ["+"] = h.poteau,
  },
  entrees = { { k = 1, cote = "O", pos = 0, jetons = { A = { 1, 2 } } }, { k = 2, cote = "O", pos = 14, jetons = { B = { 1, 2 } } } },
  sorties = {},
  liens = {
    ent_a = { groupe = "amont_a", io = "in", jetons = { "A" } }, ent_b = { groupe = "amont_b", io = "in", jetons = { "B" } },
    mid_a = { groupe = "aval", io = "mid", interne = true, de = "amont_a", vers = "aval", jeton = "X" },
    mid_b = { groupe = "aval", io = "mid", interne = true, de = "amont_b", vers = "aval", jeton = "Y" },
    sort = { groupe = "aval", io = "out", interne = true, jetons = { "Q" } },
  },
  chaines = { { amont = "amont_a", aval = "aval", jeton = "X" }, { amont = "amont_b", aval = "aval", jeton = "Y" } },
}

---------------------------------------------------------------------------------------------------
-- 4. Circuits (Patern_Mall2.png) : 3 machines de câble pour 2 de circuits, insertion directe
---------------------------------------------------------------------------------------------------
local function circuits_legende()
  return {
    b = h.entree(1, E), f = h.entree(2, E), w = h.entree(3, E), o = h.sortie(1, E),
    c = asm("cable"), e = asm("cable"), g = asm("circ"), k = asm("circ"),
    i = h.bras(N, "tapis_entree:1", "machine_asm", "cu_h"),
    u = h.bras(S, "tapis_entree:3", "machine_asm", "cu_b"),
    d = h.bras(N, "machine_asm", "machine_asm", "mid_h"),
    t = h.bras(S, "machine_asm", "machine_asm", "mid_b"),
    s = h.bras(S, "tapis_entree:2", "machine_asm", "fer_h"),
    L = h.bras_long(N, "machine_asm", "tapis_sortie:1", "sort_h"),
    Q = h.bras_long(N, "tapis_entree:2", "machine_asm", "fer_b"),
    p = h.bras(S, "machine_asm", "tapis_sortie:1", "sort_b"),
    ["+"] = h.poteau,
  }
end

L[#L + 1] = {
  id = "asm-cable-circuit-3-2-double", famille = "asm", usages = { "circuits", "chaine" }, origine = "ref_dc",
  ref = "Patern_Mall2.png", source = SRC_CIRC,
  nom_fr = "Circuits : 3 machines de câble pour 2 de circuits, double face",
  nom_en = "Circuits: 3 cable machines for 2 circuit machines, both faces",
  note_fr = "Référence du DC : un tapis de cuivre en haut, un en bas, deux tapis au centre (fer, sortie). Par tuile et par face : 3 machines "
    .. "amont qui alimentent par insertion directe 2 machines aval (la machine amont du milieu sert les deux). Rapport 3:2 de la recette amont "
    .. "à une machine par unité de temps égale ; 6 amont et 4 aval par tuile.",
  art = {
    "bbbbbbbbb",
    "ii+ii.ii+",
    "ccccccccc",
    "ccccccccc",
    "ccccccccc",
    "+ddd+ddd+",
    ".ggg.ggg.",
    ".ggg.ggg.",
    ".ggg.ggg.",
    "+ssL+ssL+",
    "fffffffff",
    "ooooooooo",
    "+QQp+QQp+",
    ".kkk.kkk.",
    ".kkk.kkk.",
    ".kkk.kkk.",
    "+ttt+ttt+",
    "eeeeeeeee",
    "eeeeeeeee",
    "eeeeeeeee",
    "uu+uu.uu+",
    "wwwwwwwww",
  },
  legende = circuits_legende(),
  entrees = { { k = 1, cote = "O", pos = 0, jetons = { A = { 1, 2 } } }, { k = 2, cote = "O", pos = 10, jetons = { B = { 1, 2 } } },
    { k = 3, cote = "O", pos = 21, jetons = { A = { 1, 2 } } } },
  sorties = { { k = 1, cote = "E", pos = 11, jetons = { P = { 1, 2 } } } },
  liens = {
    cu_h = { groupe = "cable", io = "in", jetons = { "A" } }, cu_b = { groupe = "cable", io = "in", jetons = { "A" } },
    fer_h = { groupe = "circ", io = "in", jetons = { "B" } }, fer_b = { groupe = "circ", io = "in", jetons = { "B" } },
    mid_h = { groupe = "circ", io = "mid", interne = true, de = "cable", vers = "circ", jeton = "M" },
    mid_b = { groupe = "circ", io = "mid", interne = true, de = "cable", vers = "circ", jeton = "M" },
    sort_h = { groupe = "circ", io = "out", jetons = { "P" } }, sort_b = { groupe = "circ", io = "out", jetons = { "P" } },
  },
  chaines = { { amont = "cable", aval = "circ", jeton = "M" } },
}

L[#L + 1] = {
  id = "asm-cable-circuit-3-2-simple", famille = "asm", usages = { "circuits", "chaine" }, origine = "ref_dc",
  ref = "Patern_Mall2.png", source = SRC_CIRC,
  nom_fr = "Circuits : 3 machines de câble pour 2 de circuits, une face",
  nom_en = "Circuits: 3 cable machines for 2 circuit machines, one face",
  note_fr = "Moitié haute de la référence du DC : un tapis de cuivre, 3 machines amont, 2 machines aval, un tapis de fer et un tapis de sortie.",
  art = {
    "bbbbbbbbb",
    "ii+ii.ii+",
    "ccccccccc",
    "ccccccccc",
    "ccccccccc",
    "+ddd+ddd+",
    ".ggg.ggg.",
    ".ggg.ggg.",
    ".ggg.ggg.",
    "+ssL+ssL+",
    "fffffffff",
    "ooooooooo",
  },
  legende = circuits_legende(),
  entrees = { { k = 1, cote = "O", pos = 0, jetons = { A = { 1, 2 } } }, { k = 2, cote = "O", pos = 10, jetons = { B = { 1, 2 } } } },
  sorties = { { k = 1, cote = "E", pos = 11, jetons = { P = { 2 } } } },
  liens = {
    cu_h = { groupe = "cable", io = "in", jetons = { "A" } }, fer_h = { groupe = "circ", io = "in", jetons = { "B" } },
    mid_h = { groupe = "circ", io = "mid", interne = true, de = "cable", vers = "circ", jeton = "M" },
    sort_h = { groupe = "circ", io = "out", jetons = { "P" } },
  },
  chaines = { { amont = "cable", aval = "circ", jeton = "M" } },
}

---------------------------------------------------------------------------------------------------
-- 5. Chaînes à insertion directe : 1 amont → 1 aval, 1 amont → 2 aval
---------------------------------------------------------------------------------------------------
L[#L + 1] = {
  id = "asm-chaine-1-1", famille = "asm", usages = { "chaine", "mall" }, origine = "derive",
  source = SRC_MALL,
  nom_fr = "Chaîne d'assembleurs 1 → 1, insertion directe",
  nom_en = "1 -> 1 assembler chain, direct insertion",
  note_fr = "L'assembleur amont prend la matière A et passe son produit à l'assembleur aval par un bras ; l'aval prend B (bras long) et sort le produit.",
  art = {
    "dddddddd",
    "cccccccc",
    ".I...L..",
    "ppp+qqq.",
    "pppwqqq.",
    "ppp.qqq+",
    ".....o..",
    "aaaaaaaa",
  },
  legende = {
    c = h.entree(1, E), d = h.entree(2, E), a = h.sortie(1, E), p = asm("amont"), q = asm("aval"),
    I = h.bras(N, "tapis_entree:1", "machine_asm", "ent_a"), L = h.bras_long(N, "tapis_entree:2", "machine_asm", "ent_b"),
    w = h.bras(W, "machine_asm", "machine_asm", "mid"), o = h.bras(N, "machine_asm", "tapis_sortie:1", "sort"),
    ["+"] = h.poteau,
  },
  entrees = { { k = 1, cote = "O", pos = 1, jetons = { A = { 1, 2 } } }, { k = 2, cote = "O", pos = 0, jetons = { B = { 1, 2 } } } },
  sorties = { { k = 1, cote = "E", pos = 7, jetons = { P = { 2 } } } },
  liens = {
    ent_a = { groupe = "amont", io = "in", jetons = { "A" } }, ent_b = { groupe = "aval", io = "in", jetons = { "B" } },
    mid = { groupe = "aval", io = "mid", interne = true, de = "amont", vers = "aval", jeton = "M" },
    sort = { groupe = "aval", io = "out", jetons = { "P" } },
  },
  chaines = { { amont = "amont", aval = "aval", jeton = "M" } },
}

L[#L + 1] = {
  id = "asm-chaine-1-2", famille = "asm", usages = { "chaine", "mall" }, origine = "derive",
  source = SRC_MALL,
  nom_fr = "Chaîne d'assembleurs 1 → 2, insertion directe",
  nom_en = "1 -> 2 assembler chain, direct insertion",
  note_fr = "Un assembleur amont au milieu nourrit directement ses deux voisins aval, à gauche et à droite.",
  art = {
    "dddddddddddd",
    "cccccccccccc",
    ".L...I...L..",
    "qqq+ppp+qqq+",
    "qqqepppwqqq.",
    "qqq+ppp+qqq.",
    ".o.......o..",
    "aaaaaaaaaaaa",
  },
  legende = {
    c = h.entree(1, E), d = h.entree(2, E), a = h.sortie(1, E), p = asm("amont"), q = asm("aval"),
    I = h.bras(N, "tapis_entree:1", "machine_asm", "ent_a"), L = h.bras_long(N, "tapis_entree:2", "machine_asm", "ent_b"),
    e = h.bras(E, "machine_asm", "machine_asm", "mid"), w = h.bras(W, "machine_asm", "machine_asm", "mid"),
    o = h.bras(N, "machine_asm", "tapis_sortie:1", "sort"),
    ["+"] = h.poteau,
  },
  entrees = { { k = 1, cote = "O", pos = 1, jetons = { A = { 1, 2 } } }, { k = 2, cote = "O", pos = 0, jetons = { B = { 1, 2 } } } },
  sorties = { { k = 1, cote = "E", pos = 7, jetons = { P = { 2 } } } },
  liens = {
    ent_a = { groupe = "amont", io = "in", jetons = { "A" } }, ent_b = { groupe = "aval", io = "in", jetons = { "B" } },
    mid = { groupe = "aval", io = "mid", interne = true, de = "amont", vers = "aval", jeton = "M" },
    sort = { groupe = "aval", io = "out", jetons = { "P" } },
  },
  chaines = { { amont = "amont", aval = "aval", jeton = "M" } },
}

return L
