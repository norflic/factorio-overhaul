--[[
  Lot MOTIFS : bus et équilibreurs (familles « bus » et « equilibreur »). Définitions lues par
  shared/team/motifs/catalogue.lua. Jetons : B1…B8 = voie de bus k, un par tapis. Rôles : tapis_*, tapis, repartiteur,
  souterrain_entree, souterrain_sortie. Aucune machine : ces motifs se demandent par `demande = { voies, longueur }`
  (bus) ou `demande = { entrees, sorties }` (équilibreur), jamais par un débit de produit.
  Les équilibreurs sont à tuile unique (non répétables) ; le 4-4 est vérifié par un suivi de flux (tests/motifs_test.lua) :
  chaque entrée se répartit en quatre quarts égaux sur les quatre sorties.
]]

local function need(dotted, slashed)
  local ok, res = pcall(require, dotted)
  if ok and type(res) == "table" then return res end
  return require("__factorio-overhaul__/" .. slashed)
end
local D = need("shared.team.motifs.dsl", "shared/team/motifs/dsl")
local h = D.h
local N, E, S, W = D.N, D.E, D.S, D.W

local SRC_BUS = { "https://wiki.factorio.com/Tutorial:Main_bus", "https://wiki.factorio.com/Balancers",
  "https://wiki.factorio.com/Transport_belts/Physics" }
local SRC_EQ = { "https://wiki.factorio.com/Balancers", "https://forums.factorio.com/viewtopic.php?p=425342" }

local L = {}

local function bus(n, id, fr, en)
  local art, legende, entrees = {}, {}, {}
  local chars = "abcdefgh"
  for k = 1, n do
    local c = chars:sub(k, k)
    art[k] = c
    legende[c] = h.entree(k, E)
    entrees[k] = { k = k, cote = "O", pos = k - 1, jetons = { ["B" .. k] = { 1, 2 } } }
  end
  return {
    id = id, famille = "bus", usages = { "bus" }, origine = "wiki", source = SRC_BUS, nom_fr = fr, nom_en = en,
    note_fr = "Voies de bus parallèles, une case de large par tuile : se prolonge à volonté ; aucune machine, aucun poteau.",
    art = art, legende = legende, entrees = entrees, sorties = {}, capacite = { voies = n },
  }
end
L[#L + 1] = bus(4, "bus-4-voies", "Bus de 4 voies", "4-lane bus")
L[#L + 1] = bus(8, "bus-8-voies", "Bus de 8 voies", "8-lane bus")

--- Piquage d'une voie extérieure : un répartiteur sur la voie du bas, la moitié part vers le sud.
L[#L + 1] = {
  id = "bus-piquage-voie-exterieure", famille = "bus", usages = { "bus", "piquage" }, origine = "wiki",
  source = { "https://wiki.factorio.com/Tutorial:Main_bus" },
  nom_fr = "Bus de 4 voies avec piquage de la voie extérieure",
  nom_en = "4-lane bus with a tap on the outer lane",
  note_fr = "Un répartiteur sur la 4e voie : la moitié continue dans le bus, l'autre moitié part vers le sud par un tapis qui tourne. "
    .. "Les trois autres voies passent droit. Tuile unique.",
  repetable = false,
  art = {
    "attttA",
    "bttttB",
    "cttttC",
    "dSstD ",
    ".Stv..",
    "...v..",
    "...v..",
    "...Z..",
  },
  legende = {},
  capacite = { voies = 4, piquage = true },
}
do
  local d = L[#L]
  d.art[4] = "dSsttD"
  d.legende = {
    a = h.entree(1, E), b = h.entree(2, E), c = h.entree(3, E), d = h.entree(4, E),
    A = h.sortie(1, E), B = h.sortie(2, E), C = h.sortie(3, E), D = h.sortie(4, E), Z = h.sortie(5, S),
    t = h.tapis(E), v = h.tapis(S), S = h.repartiteur(E), s = h.tapis(E),
  }
  d.entrees, d.sorties = {}, {}
  for k = 1, 4 do
    d.entrees[k] = { k = k, cote = "O", pos = k - 1, jetons = { ["B" .. k] = { 1, 2 } } }
    d.sorties[k] = { k = k, cote = "E", pos = k - 1, jetons = { ["B" .. k] = { 1, 2 } } }
  end
  d.sorties[5] = { k = 5, cote = "S", pos = 3, jetons = { B4 = { 1, 2 } } }
end

---------------------------------------------------------------------------------------------------
-- Équilibreurs (répartiteurs) : arbres planaires 1-2, 2-2, 1-4, 2-4 et papillon 4-4 avec croisements par souterrain
---------------------------------------------------------------------------------------------------
local function entrees_sorties(d, ne, ns, pos_e, pos_s)
  d.entrees, d.sorties = {}, {}
  for k = 1, ne do d.entrees[k] = { k = k, cote = "O", pos = pos_e[k], jetons = { ["B" .. k] = { 1, 2 } } } end
  for k = 1, ns do d.sorties[k] = { k = k, cote = "E", pos = pos_s[k], jetons = { P = { 1, 2 } } } end
end
local function leg_eq()
  return {
    a = h.entree(1, E), b = h.entree(2, E), c = h.entree(3, E), d = h.entree(4, E),
    o = h.sortie(1, E), p = h.sortie(2, E), q = h.sortie(3, E), s = h.sortie(4, E),
    t = h.tapis(E), v = h.tapis(S), n = h.tapis(N), g = h.ug_entree(E), G = h.ug_sortie(E),
    S = h.repartiteur(E), T = h.repartiteur(E), U = h.repartiteur(E), V = h.repartiteur(E),
  }
end
local function eq(id, fr, en, note, art, ne, ns, pos_e, pos_s, repartiteurs)
  local d = {
    id = id, famille = "equilibreur", usages = { "equilibreur", "repartition" }, origine = "wiki", source = SRC_EQ,
    nom_fr = fr, nom_en = en, note_fr = note, repetable = false, art = art, legende = leg_eq(),
    capacite = { entrees = ne, sorties = ns, repartiteurs = repartiteurs },
  }
  entrees_sorties(d, ne, ns, pos_e, pos_s)
  return d
end

L[#L + 1] = eq("equilibreur-1-2", "Répartiteur 1 vers 2", "1-to-2 splitter",
  "Un répartiteur : une voie d'entrée, deux voies de sortie à parts égales.",
  { "aSo", ".Sp" }, 1, 2, { 0 }, { 0, 1 }, 1)
L[#L + 1] = eq("equilibreur-2-2", "Équilibreur 2 vers 2", "2-to-2 balancer",
  "Un répartiteur à deux entrées et deux sorties : égalise les deux tapis (une sortie bloquée reporte tout sur l'autre).",
  { "aSo", "bSp" }, 2, 2, { 0, 1 }, { 0, 1 }, 1)
L[#L + 1] = eq("equilibreur-1-4", "Arbre 1 vers 4", "1-to-4 splitter tree",
  "Trois répartiteurs en arbre plan (1 puis 2) : une entrée, quatre sorties égales.",
  {
    "...So",
    "aStSp",
    ".StTq",
    "...Ts",
  }, 1, 4, { 1 }, { 0, 1, 2, 3 }, 3)
L[#L + 1] = eq("equilibreur-2-4", "Arbre 2 vers 4", "2-to-4 splitter tree",
  "Un répartiteur de mélange puis deux d'arbre : deux entrées, quatre sorties égales.",
  {
    "...So",
    "aStSp",
    "bStTq",
    "...Ts",
  }, 2, 4, { 1, 2 }, { 0, 1, 2, 3 }, 3)
-- 4-4 en papillon : étage 1 (0,1) (2,3) ; la voie 2 passe sous les voies 3 et 4 par la colonne 3 (souterrains), puis étage 2 (0,1) (2,3)
L[#L + 1] = eq("equilibreur-4-4", "Équilibreur 4 vers 4 (papillon)", "4-to-4 butterfly balancer",
  "Deux étages de deux répartiteurs ; entre les étages, la deuxième voie descend en colonne 3 sous les voies 3 et 4 (tapis souterrains) "
    .. "pour que les paires de l'étage 2 mêlent chacune une voie de chaque paire de l'étage 1 : chaque entrée se répartit en quatre quarts "
    .. "égaux, pour toute combinaison d'entrées pleines ou vides.",
  {
    "aSttttttUo",
    "bStv.tttUp",
    "cTgvGnttVq",
    "dTgvGtntVs",
    "...ttttn..",
  }, 4, 4, { 0, 1, 2, 3 }, { 0, 1, 2, 3 }, 4)

return L
