--[[
  Lot MOTIFS : extraction (famille « mine » : champs de foreuses sur tapis central). Définitions lues par
  shared/team/motifs/catalogue.lua. Jeton : P = minerai extrait. Rôle : foreuse (la direction d'une foreuse est le côté de sa sortie ;
  elle dépose sur la voie la PLUS PROCHE de lui : RD_LOG F116). Les tuiles se posent sur le gisement : le client garde les positions
  de foreuse dont l'aire de minage touche du minerai (shared/team/modules.lua, M.resource_tiles).
]]

local function need(dotted, slashed)
  local ok, res = pcall(require, dotted)
  if ok and type(res) == "table" then return res end
  return require("__factorio-overhaul__/" .. slashed)
end
local D = need("shared.team.motifs.dsl", "shared/team/motifs/dsl")
local h = D.h
local N, E, S, W = D.N, D.E, D.S, D.W

local SRC_MINE = { "https://forums.factorio.com/viewtopic.php?p=158464", "https://forums.factorio.com/viewtopic.php?p=19252" }

local L = {}

L[#L + 1] = {
  id = "foreuses-2xN-tapis-central", famille = "mine", usages = { "extraction" }, origine = "forum",
  source = SRC_MINE,
  nom_fr = "Champ de foreuses 3×3, 2 × N, sur un tapis central",
  nom_en = "3x3 drill field, 2 x N, on a central belt",
  note_fr = "Une rangée de foreuses de chaque côté d'un tapis ; deux foreuses par rangée et par tuile avec un poteau dans le passage du milieu "
    .. "(période 7). La rangée du nord remplit la voie 1, celle du sud la voie 2.",
  art = {
    "fff.fff",
    "fff.fff",
    "fff+fff",
    "aaaaaaa",
    "ggg.ggg",
    "ggg.ggg",
    "ggg.ggg",
  },
  legende = {
    f = h.machine("foreuse", 3, "principal", { dir = S }), g = h.machine("foreuse", 3, "principal", { dir = N }),
    a = h.sortie(1, E), ["+"] = h.poteau,
  },
  entrees = {},
  sorties = { { k = 1, cote = "E", pos = 3, jetons = { P = { 1, 2 } } } },
  liens = {},
}

L[#L + 1] = {
  id = "foreuses-3x3-simple-face", famille = "mine", usages = { "extraction" }, origine = "forum",
  source = SRC_MINE,
  nom_fr = "Rangée de foreuses 3×3 d'un seul côté du tapis",
  nom_en = "Single-sided 3x3 drill row",
  note_fr = "Une rangée de foreuses au nord d'un tapis (voie 1) ; période 4 : une foreuse et un passage pour le poteau.",
  art = {
    "fff.",
    "fff.",
    "fff+",
    "aaaa",
  },
  legende = {
    f = h.machine("foreuse", 3, "principal", { dir = S }),
    a = h.sortie(1, E), ["+"] = h.poteau,
  },
  entrees = {},
  sorties = { { k = 1, cote = "E", pos = 3, jetons = { P = { 1 } } } },
  liens = {},
}

L[#L + 1] = {
  id = "foreuses-2x2-combustion-2xN", famille = "mine", usages = { "extraction" }, origine = "forum",
  source = SRC_MINE,
  nom_fr = "Champ de foreuses 2×2 à combustion, 2 × N, sur un tapis central",
  nom_en = "2x2 burner drill field, 2 x N, on a central belt",
  note_fr = "Foreuses jointives de côté 2 de part et d'autre d'un tapis, sans poteau (combustion) ; période 2.",
  art = {
    "ff",
    "ff",
    "aa",
    "gg",
    "gg",
  },
  legende = {
    f = h.machine("foreuse", 2, "principal", { dir = S, combustion = true }), g = h.machine("foreuse", 2, "principal", { dir = N, combustion = true }),
    a = h.sortie(1, E),
  },
  entrees = {},
  sorties = { { k = 1, cote = "E", pos = 2, jetons = { P = { 1, 2 } } } },
  liens = {},
}

return L
