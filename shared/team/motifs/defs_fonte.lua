--[[
  Lot MOTIFS : colonnes de fonte (famille « fonte »). Définitions lues par shared/team/motifs/catalogue.lua.
  Orientation canonique : répétition de gauche à droite ; entrée à l'ouest. Jetons : A = matière entrante (minerai ou plaque),
  combustible = combustible, P = produit. Aucun nom d'objet du jeu : les rôles sont machine_fonte, bras, tapis_*, poteau.
  Une voie : voie 1 = gauche, voie 2 = droite dans le sens de la marche (comme shared/team/modules.lua). Un bras qui dépose
  sur un tapis le pose sur la voie la plus éloignée de lui.
]]

local function need(dotted, slashed)
  local ok, res = pcall(require, dotted)
  if ok and type(res) == "table" then return res end
  return require("__factorio-overhaul__/" .. slashed)
end
local D = need("shared.team.motifs.dsl", "shared/team/motifs/dsl")
local h = D.h
local N, E, S, W = D.N, D.E, D.S, D.W

local SRC_FONTE = { "https://forums.factorio.com/viewtopic.php?p=15569", "https://forums.factorio.com/viewtopic.php?p=46359",
  "https://forums.factorio.com/viewtopic.php?p=194325" }

local L = {}

local function fonte(taille, extra)
  return h.machine("machine_fonte", taille, extra and extra.groupe, extra and extra.p)
end

--- Entrée à l'ouest : minerai (voie 1) et combustible (voie 2) ; sans combustible : minerai sur les deux voies.
local function jetons_entree(comb)
  if comb then return { A = { 1 }, combustible = { 2 } } end
  return { A = { 1, 2 } }
end
local function liens_in(comb)
  if comb then return { "A", "combustible" } end
  return { "A" }
end

---------------------------------------------------------------------------------------------------
-- 1. Référence du DC (Fonderie.png) : colonne double, tapis central partagé, sorties en haut et en bas
---------------------------------------------------------------------------------------------------
L[#L + 1] = {
  id = "fonte-2x2-double-central", famille = "fonte", usages = { "fonte", "acier" }, origine = "ref_dc",
  ref = "Fonderie.png", source = SRC_FONTE,
  nom_fr = "Colonne de fonte 2×2, deux rangées, tapis central partagé",
  nom_en = "2x2 smelting column, two rows, shared central belt",
  note_fr = "Référence du DC : le minerai et le combustible arrivent par le tapis du milieu (voie 1 minerai, voie 2 combustible), "
    .. "deux rangées de fours de côté 2, plaques sortant par les tapis du haut et du bas ; se colle de gauche à droite.",
  art = {
    "aaaa",
    "s+s.",
    "ffff",
    "ffff",
    "i+i.",
    "cccc",
    "j.j.",
    "ffff",
    "ffff",
    "n+n.",
    "bbbb",
  },
  legende = {
    a = h.sortie(1, E), b = h.sortie(2, E), c = h.entree(1, E), f = fonte(2),
    s = h.bras(S, "machine_fonte", "tapis_sortie:1", "sort_h"), n = h.bras(N, "machine_fonte", "tapis_sortie:2", "sort_b"),
    i = h.bras(S, "tapis_entree:1", "machine_fonte", "ent_h"), j = h.bras(N, "tapis_entree:1", "machine_fonte", "ent_b"),
    ["+"] = h.poteau,
  },
  entrees = { { k = 1, cote = "O", pos = 5, jetons = jetons_entree(true) } },
  sorties = { { k = 1, cote = "E", pos = 0, jetons = { P = { 1 } } }, { k = 2, cote = "E", pos = 10, jetons = { P = { 2 } } } },
  liens = {
    ent_h = { groupe = "principal", io = "in", jetons = liens_in(true) }, ent_b = { groupe = "principal", io = "in", jetons = liens_in(true) },
    sort_h = { groupe = "principal", io = "out", jetons = { "P" } }, sort_b = { groupe = "principal", io = "out", jetons = { "P" } },
  },
  contraintes = { droit = { "tapis_entree:1", "tapis_sortie:1", "tapis_sortie:2" } },
}

L[#L + 1] = {
  id = "fonte-2x2-simple", famille = "fonte", usages = { "fonte", "acier" }, origine = "forum",
  source = SRC_FONTE,
  nom_fr = "Colonne de fonte 2×2, une rangée",
  nom_en = "2x2 smelting column, single row",
  note_fr = "Une rangée de fours : tapis d'entrée au nord, tapis de sortie au sud ; 6 tuiles de haut, la plus étroite.",
  art = {
    "cccc",
    "i+i.",
    "ffff",
    "ffff",
    "o+o.",
    "aaaa",
  },
  legende = {
    c = h.entree(1, E), a = h.sortie(1, E), f = fonte(2),
    i = h.bras(N, "tapis_entree:1", "machine_fonte", "ent"), o = h.bras(N, "machine_fonte", "tapis_sortie:1", "sort"),
    ["+"] = h.poteau,
  },
  entrees = { { k = 1, cote = "O", pos = 0, jetons = jetons_entree(true) } },
  sorties = { { k = 1, cote = "E", pos = 5, jetons = { P = { 2 } } } },
  liens = { ent = { groupe = "principal", io = "in", jetons = liens_in(true) }, sort = { groupe = "principal", io = "out", jetons = { "P" } } },
}

L[#L + 1] = {
  id = "fonte-2x2-double-sortie-centrale", famille = "fonte", usages = { "fonte", "acier" }, origine = "forum",
  source = SRC_FONTE,
  nom_fr = "Colonne de fonte 2×2, deux rangées, sortie centrale",
  nom_en = "2x2 smelting column, two rows, central output",
  note_fr = "Deux tapis d'entrée à l'extérieur, un seul tapis de sortie au centre qui reçoit les deux rangées (une voie chacune).",
  art = {
    "cccc",
    "i+i.",
    "ffff",
    "ffff",
    "n+n.",
    "aaaa",
    "s.s.",
    "ffff",
    "ffff",
    "j+j.",
    "dddd",
  },
  legende = {
    c = h.entree(1, E), d = h.entree(2, E), a = h.sortie(1, E), f = fonte(2),
    i = h.bras(N, "tapis_entree:1", "machine_fonte", "ent_h"), j = h.bras(S, "tapis_entree:2", "machine_fonte", "ent_b"),
    n = h.bras(N, "machine_fonte", "tapis_sortie:1", "sort_h"), s = h.bras(S, "machine_fonte", "tapis_sortie:1", "sort_b"),
    ["+"] = h.poteau,
  },
  entrees = { { k = 1, cote = "O", pos = 0, jetons = jetons_entree(true) }, { k = 2, cote = "O", pos = 10, jetons = jetons_entree(true) } },
  sorties = { { k = 1, cote = "E", pos = 5, jetons = { P = { 1, 2 } } } },
  liens = {
    ent_h = { groupe = "principal", io = "in", jetons = liens_in(true) }, ent_b = { groupe = "principal", io = "in", jetons = liens_in(true) },
    sort_h = { groupe = "principal", io = "out", jetons = { "P" } }, sort_b = { groupe = "principal", io = "out", jetons = { "P" } },
  },
}

---------------------------------------------------------------------------------------------------
-- 2. Fours de côté 3 (électriques : aucun combustible)
---------------------------------------------------------------------------------------------------
L[#L + 1] = {
  id = "fonte-3x3-double-central", famille = "fonte", usages = { "fonte", "acier" }, origine = "derive",
  source = SRC_FONTE,
  nom_fr = "Colonne de fonte 3×3 (électrique), deux rangées, tapis central",
  nom_en = "3x3 (electric) smelting column, two rows, central belt",
  note_fr = "Même disposition que la référence du DC avec des fours de côté 3 : pas de combustible, le minerai occupe les deux voies.",
  art = {
    "aaaaaa",
    ".s+.s.",
    "ffffff",
    "ffffff",
    "ffffff",
    ".i+.i.",
    "cccccc",
    ".j..j.",
    "ffffff",
    "ffffff",
    "ffffff",
    ".n+.n.",
    "bbbbbb",
  },
  legende = {
    a = h.sortie(1, E), b = h.sortie(2, E), c = h.entree(1, E), f = fonte(3),
    s = h.bras(S, "machine_fonte", "tapis_sortie:1", "sort_h"), n = h.bras(N, "machine_fonte", "tapis_sortie:2", "sort_b"),
    i = h.bras(S, "tapis_entree:1", "machine_fonte", "ent_h"), j = h.bras(N, "tapis_entree:1", "machine_fonte", "ent_b"),
    ["+"] = h.poteau,
  },
  entrees = { { k = 1, cote = "O", pos = 6, jetons = jetons_entree(false) } },
  sorties = { { k = 1, cote = "E", pos = 0, jetons = { P = { 1 } } }, { k = 2, cote = "E", pos = 12, jetons = { P = { 2 } } } },
  liens = {
    ent_h = { groupe = "principal", io = "in", jetons = liens_in(false) }, ent_b = { groupe = "principal", io = "in", jetons = liens_in(false) },
    sort_h = { groupe = "principal", io = "out", jetons = { "P" } }, sort_b = { groupe = "principal", io = "out", jetons = { "P" } },
  },
}

L[#L + 1] = {
  id = "fonte-3x3-simple", famille = "fonte", usages = { "fonte", "acier" }, origine = "derive",
  source = SRC_FONTE,
  nom_fr = "Colonne de fonte 3×3 (électrique), une rangée",
  nom_en = "3x3 (electric) smelting column, single row",
  art = {
    "cccccc",
    ".i+.i.",
    "ffffff",
    "ffffff",
    "ffffff",
    ".o+.o.",
    "aaaaaa",
  },
  legende = {
    c = h.entree(1, E), a = h.sortie(1, E), f = fonte(3),
    i = h.bras(N, "tapis_entree:1", "machine_fonte", "ent"), o = h.bras(N, "machine_fonte", "tapis_sortie:1", "sort"),
    ["+"] = h.poteau,
  },
  entrees = { { k = 1, cote = "O", pos = 0, jetons = jetons_entree(false) } },
  sorties = { { k = 1, cote = "E", pos = 6, jetons = { P = { 2 } } } },
  liens = { ent = { groupe = "principal", io = "in", jetons = liens_in(false) }, sort = { groupe = "principal", io = "out", jetons = { "P" } } },
}

L[#L + 1] = {
  id = "fonte-3x3-double-sortie-centrale", famille = "fonte", usages = { "fonte", "acier" }, origine = "derive",
  source = SRC_FONTE,
  nom_fr = "Colonne de fonte 3×3 (électrique), deux rangées, sortie centrale",
  nom_en = "3x3 (electric) smelting column, two rows, central output",
  art = {
    "cccccc",
    ".i+.i.",
    "ffffff",
    "ffffff",
    "ffffff",
    ".n+.n.",
    "aaaaaa",
    ".s..s.",
    "ffffff",
    "ffffff",
    "ffffff",
    ".j+.j.",
    "dddddd",
  },
  legende = {
    c = h.entree(1, E), d = h.entree(2, E), a = h.sortie(1, E), f = fonte(3),
    i = h.bras(N, "tapis_entree:1", "machine_fonte", "ent_h"), j = h.bras(S, "tapis_entree:2", "machine_fonte", "ent_b"),
    n = h.bras(N, "machine_fonte", "tapis_sortie:1", "sort_h"), s = h.bras(S, "machine_fonte", "tapis_sortie:1", "sort_b"),
    ["+"] = h.poteau,
  },
  entrees = { { k = 1, cote = "O", pos = 0, jetons = jetons_entree(false) }, { k = 2, cote = "O", pos = 12, jetons = jetons_entree(false) } },
  sorties = { { k = 1, cote = "E", pos = 6, jetons = { P = { 1, 2 } } } },
  liens = {
    ent_h = { groupe = "principal", io = "in", jetons = liens_in(false) }, ent_b = { groupe = "principal", io = "in", jetons = liens_in(false) },
    sort_h = { groupe = "principal", io = "out", jetons = { "P" } }, sort_b = { groupe = "principal", io = "out", jetons = { "P" } },
  },
}

---------------------------------------------------------------------------------------------------
-- 3. Chaîne directe fonte → fonte (plaque puis acier) : aucune plaque ne passe par un tapis
---------------------------------------------------------------------------------------------------
L[#L + 1] = {
  id = "fonte-chaine-directe-3x3", famille = "fonte", usages = { "acier", "chaine" }, origine = "forum",
  source = { "https://forums.factorio.com/viewtopic.php?p=273173", "https://forums.factorio.com/viewtopic.php?p=249120" },
  nom_fr = "Chaîne directe de fours 3×3 (matière → plaque → acier)",
  nom_en = "3x3 direct furnace chain (ore -> plate -> steel)",
  note_fr = "Deux fours en série par insertion directe : le premier fond la matière, le second la transforme (même vitesse : un pour un).",
  art = {
    "cccccc",
    ".i+.i.",
    "ffffff",
    "ffffff",
    "ffffff",
    ".m+.m.",
    "gggggg",
    "gggggg",
    "gggggg",
    ".o+.o.",
    "aaaaaa",
  },
  legende = {
    c = h.entree(1, E), a = h.sortie(1, E), f = h.machine("machine_fonte", 3, "amont"), g = h.machine("machine_fonte", 3, "aval"),
    i = h.bras(N, "tapis_entree:1", "machine_fonte", "ent"), m = h.bras(N, "machine_fonte", "machine_fonte", "mid"),
    o = h.bras(N, "machine_fonte", "tapis_sortie:1", "sort"),
    ["+"] = h.poteau,
  },
  entrees = { { k = 1, cote = "O", pos = 0, jetons = jetons_entree(false) } },
  sorties = { { k = 1, cote = "E", pos = 10, jetons = { P = { 2 } } } },
  liens = {
    ent = { groupe = "amont", io = "in", jetons = { "A" } },
    mid = { groupe = "aval", io = "mid", interne = true, de = "amont", vers = "aval", jeton = "M" },
    sort = { groupe = "aval", io = "out", jetons = { "P" } },
  },
  chaines = { { amont = "amont", aval = "aval", jeton = "M" } },
}

---------------------------------------------------------------------------------------------------
-- 4. Fusion des deux sorties en queue (Fonderie.png : les deux tapis de plaques se rejoignent au bout de la colonne)
---------------------------------------------------------------------------------------------------
-- Le tapis du haut descend, celui du bas monte, tous deux entrent par les côtés d'un même tapis : l'un remplit sa voie 1, l'autre sa voie 2.
-- Le tapis d'entrée du milieu s'arrête devant la queue (bout de ligne). Une seule sortie à l'est.
local function fusion(src_id, mid, note)
  local src
  for _, d in ipairs(L) do if d.id == src_id then src = d end end
  local H = #src.art
  local d = {}
  for k, v in pairs(src) do d[k] = v end
  d.legende = {}
  for k, v in pairs(src.legende) do d.legende[k] = v end
  d.legende.T, d.legende.V, d.legende.U, d.legende.A = h.tapis(E), h.tapis(S), h.tapis(N), h.sortie(3, E)
  d.id = src_id .. "-fusion"
  d.usages = { "fonte", "acier", "sortie-unique" }
  d.origine = "ref_dc"
  d.nom_fr = src.nom_fr .. ", sorties fusionnées en queue"
  d.nom_en = src.nom_en .. ", outputs merged at the tail"
  d.note_fr = note
  local rows = {}
  for y = 0, H - 1 do
    if y == 0 then rows[#rows + 1] = "TV."
    elseif y < mid then rows[#rows + 1] = ".V."
    elseif y == mid then rows[#rows + 1] = ".TA"
    elseif y < H - 1 then rows[#rows + 1] = ".U."
    else rows[#rows + 1] = "TU." end
  end
  d.queue = { art = rows }
  d.sorties = { { k = 3, cote = "E", pos = mid, jetons = { P = { 1, 2 } } } }
  d.sorties_internes = { { k = 1, jetons = { P = { 1 } } }, { k = 2, jetons = { P = { 2 } } } }
  L[#L + 1] = d
end
fusion("fonte-2x2-double-central", 5, "Comme la colonne de référence du DC, avec la queue de Fonderie.png : les deux tapis de plaques rejoignent par les côtés un seul tapis "
  .. "de sortie (plaques du haut sur la voie 1, du bas sur la voie 2), au bout de la colonne ; le tapis du milieu s'arrête devant la queue.")
fusion("fonte-3x3-double-central", 6, "Colonne électrique à fours de côté 3 avec la même queue : les deux tapis de plaques se fusionnent en un seul tapis de sortie à l'est.")

return L
