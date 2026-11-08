--[[
  Lot MOTIFS : chimie et pétrole (familles « chimie » et « petrole »). Définitions lues par shared/team/motifs/catalogue.lua.
  Jetons de fluide : F1, F2 (ordre des entrées de la recette) ; solides : A, B (entrées), P (produit). Rôles : machine_chimie,
  machine_raffinerie, chevalet, tuyau, tuyau_souterrain, bras, bras_long, tapis_*, poteau. Les cellules de raccord des machines
  sont celles de shared/team/modules.lua (usine chimique : entrées à (0, −1) et (2, −1), sorties à (0, 3) et (2, 3) ;
  raffinerie : entrées (1, 5) et (3, 5), sorties (0, −1), (2, −1), (4, −1) ; chevalet : sortie selon sa direction).
  Un tuyau souterrain porte la direction de son raccord de SURFACE (le souterrain part du côté opposé).
]]

local function need(dotted, slashed)
  local ok, res = pcall(require, dotted)
  if ok and type(res) == "table" then return res end
  return require("__factorio-overhaul__/" .. slashed)
end
local D = need("shared.team.motifs.dsl", "shared/team/motifs/dsl")
local h = D.h
local N, E, S, W = D.N, D.E, D.S, D.W

local SRC_CHIM = { "https://wiki.factorio.com/Chemical_plant", "https://wiki.factorio.com/Oil_processing" }
local SRC_RAFF = { "https://wiki.factorio.com/Oil_refinery", "https://wiki.factorio.com/Oil_processing",
  "https://forums.factorio.com/viewtopic.php?p=227781" }

local L = {}

local function chimie(entrees)
  return h.machine("machine_chimie", 3, "principal", { fluides_entree = entrees, fluides_sortie = {} })
end

---------------------------------------------------------------------------------------------------
-- 1. Rangées d'usines chimiques
---------------------------------------------------------------------------------------------------
-- Deux fluides par le nord sans mélange : l'un par une conduite directe (rangée 0, raccord de gauche), l'autre par la rangée 1
-- (raccord de droite) dont les paires de tuyaux souterrains passent sous le piquage de l'autre (méthode du gabarit « soufre »).
local function legende_2f()
  return {
    w = h.tuyau("F1"), x = h.ptg(W, "F1"), y = h.ptg(E, "F1"),
    g = h.tuyau("F2"), G = h.ptg(W, "F2"), H = h.ptg(E, "F2"),
    m = chimie({ "F1", "F2" }),
    a = h.sortie(1, E), e = h.entree(1, E),
    o = h.bras(N, "machine_chimie", "tapis_sortie:1", "sort"),
    J = h.bras(S, "tapis_entree:1", "machine_chimie", "ent"), O = h.bras_long(N, "machine_chimie", "tapis_sortie:1", "sort"),
    ["+"] = h.poteau,
  }
end
-- tête et queue : l'amorce des deux fluides (la tête porte la moitié de paire de souterrains de gaz que la première tuile attend)
-- et le prolongement des tapis ; `extra` = { [rangée] = "chaîne de 2 caractères" } (tapis d'entrée et de sortie).
local function tete_2f(hauteur, extra)
  local t = { ".w", "gG" }
  for y = 3, hauteur do t[#t + 1] = (extra and extra[y - 1]) or ".." end
  return { art = t }
end
local function queue_2f(hauteur, extra)
  local t = { "..", ".H" }
  for y = 3, hauteur do t[#t + 1] = (extra and extra[y - 1]) or ".." end
  return { art = t }
end

L[#L + 1] = {
  id = "chimie-rangee-2f-sortie", famille = "chimie", usages = { "chimie", "soufre" }, origine = "derive",
  source = SRC_CHIM,
  nom_fr = "Rangée d'usines chimiques, 2 fluides, sortie solide",
  nom_en = "Chemical plant row, 2 fluids, solid output",
  note_fr = "Deux fluides arrivent par le nord (F1 rangée 0, F2 rangée 1) sans se toucher grâce aux tuyaux souterrains ; produit solide "
    .. "sorti par bras sur un tapis au sud. Période 4 (3 de machine, 1 de passage).",
  art = {
    "wx.y",
    "wHgG",
    "mmm.",
    "mmm.",
    "mmm.",
    "oo+.",
    "aaaa",
  },
  legende = legende_2f(),
  tete = tete_2f(7, { [6] = "aa" }), queue = queue_2f(7, { [6] = "aa" }),
  fluides = { { io = "in", jeton = "F1", x = 1, y = 0, cote = "O" }, { io = "in", jeton = "F2", x = 0, y = 1, cote = "O" } },
  entrees = {},
  sorties = { { k = 1, cote = "E", pos = 6, jetons = { P = { 2 } } } },
  liens = { sort = { groupe = "principal", io = "out", jetons = { "P" } } },
}

L[#L + 1] = {
  id = "chimie-rangee-2f-1e-1s", famille = "chimie", usages = { "chimie" }, origine = "derive",
  source = SRC_CHIM,
  nom_fr = "Rangée d'usines chimiques, 2 fluides, 1 entrée solide, 1 sortie solide",
  nom_en = "Chemical plant row, 2 fluids, 1 solid input, 1 solid output",
  note_fr = "Comme la rangée à 2 fluides, avec un tapis d'entrée solide contre les machines (bras court) et le tapis de sortie derrière (bras long).",
  art = {
    "wx.y",
    "wHgG",
    "mmm.",
    "mmm.",
    "mmm.",
    "JO+.",
    "eeee",
    "aaaa",
  },
  legende = legende_2f(),
  tete = tete_2f(8, { [6] = "ee", [7] = "aa" }), queue = queue_2f(8, { [6] = "ee", [7] = "aa" }),
  fluides = { { io = "in", jeton = "F1", x = 1, y = 0, cote = "O" }, { io = "in", jeton = "F2", x = 0, y = 1, cote = "O" } },
  entrees = { { k = 1, cote = "O", pos = 6, jetons = { A = { 1, 2 } } } },
  sorties = { { k = 1, cote = "E", pos = 7, jetons = { P = { 2 } } } },
  liens = { ent = { groupe = "principal", io = "in", jetons = { "A" } }, sort = { groupe = "principal", io = "out", jetons = { "P" } } },
}

L[#L + 1] = {
  id = "chimie-rangee-1f-1e-1s", famille = "chimie", usages = { "chimie", "plastique" }, origine = "derive",
  source = SRC_CHIM,
  nom_fr = "Rangée d'usines chimiques, 1 fluide, 1 entrée solide, 1 sortie solide",
  nom_en = "Chemical plant row, 1 fluid, 1 solid input, 1 solid output",
  note_fr = "Une conduite au nord (un seul fluide : aucun risque de mélange), usines jointives (période 3), tapis d'entrée solide puis tapis de sortie au sud.",
  art = {
    "www",
    "w..",
    "mmm",
    "mmm",
    "mmm",
    "JO+",
    "eee",
    "aaa",
  },
  legende = {
    w = h.tuyau("F1"), m = chimie({ "F1" }), a = h.sortie(1, E), e = h.entree(1, E),
    J = h.bras(S, "tapis_entree:1", "machine_chimie", "ent"), O = h.bras_long(N, "machine_chimie", "tapis_sortie:1", "sort"),
    ["+"] = h.poteau,
  },
  fluides = { { io = "in", jeton = "F1", x = 0, y = 0, cote = "O" } },
  entrees = { { k = 1, cote = "O", pos = 6, jetons = { A = { 1, 2 } } } },
  sorties = { { k = 1, cote = "E", pos = 7, jetons = { P = { 2 } } } },
  liens = { ent = { groupe = "principal", io = "in", jetons = { "A" } }, sort = { groupe = "principal", io = "out", jetons = { "P" } } },
}

---------------------------------------------------------------------------------------------------
-- 2. Rangée de raffineries (traitement de base : un brut entre, un gaz sort) et champs de chevalets
---------------------------------------------------------------------------------------------------
L[#L + 1] = {
  id = "raffinerie-rangee-base", famille = "petrole", usages = { "petrole", "raffinage" }, origine = "derive",
  source = SRC_RAFF,
  nom_fr = "Rangée de raffineries (traitement de base) sur deux conduites",
  nom_en = "Refinery row (basic processing) on two pipelines",
  note_fr = "Brut par la conduite du sud (un piquage par raffinerie), gaz sorti par la conduite du nord ; période 5 (côté de la raffinerie), "
    .. "un poteau par tuile ; même géométrie que le gabarit « raffinerie » de modules.lua.",
  art = {
    "ggggg",
    "....g",
    "rrrrr",
    "rrrrr",
    "rrrrr",
    "rrrrr",
    "rrrrr",
    "+..w.",
    "wwwww",
  },
  legende = {
    g = h.tuyau("F2"), w = h.tuyau("F1"),
    r = h.machine("machine_raffinerie", 5, "principal", { fluides_entree = { false, "F1" }, fluides_sortie = { false, false, "F2" } }),
    ["+"] = h.poteau,
  },
  fluides = { { io = "in", jeton = "F1", x = 0, y = 8, cote = "O" }, { io = "out", jeton = "F2", x = 0, y = 0, cote = "O" } },
  entrees = {}, sorties = {},
}

L[#L + 1] = {
  id = "chevalets-ligne", famille = "petrole", usages = { "petrole", "chevalets" }, origine = "forum",
  source = { "https://wiki.factorio.com/Oil_processing", "https://forums.factorio.com/viewtopic.php?p=158464" },
  nom_fr = "Ligne de chevalets sur une conduite collectrice",
  nom_en = "Pumpjack row along a collector pipe",
  note_fr = "Chevalets jointifs (période 3) orientés vers le nord, un piquage chacun sur la conduite collectrice du nord.",
  art = {
    "www",
    "+.w",
    "ccc",
    "ccc",
    "ccc",
  },
  legende = {
    w = h.tuyau("F1"), c = h.machine("chevalet", 3, "principal", { dir = N, fluides_sortie = { "F1" } }),
    ["+"] = h.poteau,
  },
  fluides = { { io = "out", jeton = "F1", x = 0, y = 0, cote = "O" } },
  entrees = {}, sorties = {},
}

L[#L + 1] = {
  id = "chevalets-double", famille = "petrole", usages = { "petrole", "chevalets" }, origine = "forum",
  source = { "https://wiki.factorio.com/Oil_processing", "https://forums.factorio.com/viewtopic.php?p=158464" },
  nom_fr = "Deux lignes de chevalets de part et d'autre d'une conduite collectrice",
  nom_en = "Two pumpjack rows on both sides of a collector pipe",
  note_fr = "La conduite du milieu reçoit directement la sortie des chevalets du nord (orientés vers le sud) et du sud (orientés vers le nord) ; "
    .. "poteau moyen requis (les deux rangées de poteaux sont à 8 tuiles).",
  art = {
    "+..",
    "ccc",
    "ccc",
    "ccc",
    "www",
    "ddd",
    "ddd",
    "ddd",
    "+..",
  },
  legende = {
    w = h.tuyau("F1"),
    c = h.machine("chevalet", 3, "principal", { dir = S, fluides_sortie = { "F1" } }),
    d = h.machine("chevalet", 3, "principal", { dir = N, fluides_sortie = { "F1" } }),
    ["+"] = h.poteau,
  },
  exige_poteau = { supply = 3.5, fil = 9 },
  fluides = { { io = "out", jeton = "F1", x = 0, y = 4, cote = "O" } },
  entrees = {}, sorties = {},
}

return L
