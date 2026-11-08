--[[
  Lot MOTIFS : CATALOGUE des motifs industriels (demande du DC, 8/11 vers 18 h 45 : « une base de données de motifs […]
  strictement duplicables (possibilité de coller les modules en série de gauche à droite ou de haut en bas) »).
  Lua PUR : aucune API du jeu ; lu hors jeu (tests/motifs_test.lua) et par les règles « rangée extensible » des clients
  (mega-fonderie, mall, petrole-rangee, acier, plan directeur : shared/team/plan.lua).

  UN MOTIF = une TUILE répétable le long de l'axe x (orientation canonique) :
    id, famille ("fonte", "asm", "chimie", "petrole", "mine", "bus", "equilibreur"), usages (ce qu'il sait faire),
    origine ("ref_dc" : référence du DC, "forum", "wiki", "derive" : géométrie dérivée par nous), ref (fichier de référence du DC),
    source = { URL, ... } (où la LOGIQUE du motif a été relevée ; les coordonnées sont les nôtres, vérifiées par les tests),
    nom_fr, nom_en, note_fr,
    l, h, periode, emprise = { l, h }   -- tuile l × h, pas de répétition = période (≥ emprise utile) ; `repetable = false` : tuile unique,
    pieces = { { role, x, y, w, h, dir, k, groupe, prend, depose, lien, fluide, ... } }   -- par RÔLE, jamais par nom d'objet,
    tete / queue = { len, pieces }     -- facultatifs : posés une fois avant le premier et après le dernier,
    entrees / sorties = { { k, cote, pos, jetons = { jeton = { voies } } } },   -- n entrées, m sorties (côté, rangée, voies du tapis),
    fluides = { { io, jeton, x, y, cote } },   -- raccords de tuyau, liens, groupes, chaines (rapports de machines),
    exige_poteau = { supply, fil },   -- plus petit poteau qui suffit (défaut : le petit),
    capacite = { voies, ... }   -- motifs de transport (bus, équilibreurs),
    roles = { ... } (dérivé),  derive = { groupes, liens, pieces } (dérivé de la géométrie : jamais écrit à la main).

  VOCABULAIRE (shared/team/motifs/dsl.lua, D.ROLES) : machine_fonte, machine_asm, machine_chimie, machine_raffinerie, foreuse,
  chevalet, bras, bras_long, tapis_entree, tapis_sortie, tapis, repartiteur, souterrain_entree, souterrain_sortie, poteau, tuyau,
  tuyau_souterrain, coffre. La correspondance rôle → prototype se fait EN JEU, d'après les prototypes (catégories, vitesses, emprises),
  jamais ici : la sélection (choix.lua) reçoit ce que le client a lu.

  JETONS (abstraits) : A, B, C = matières entrantes (ordre de la recette), P = produit, M, X, Y = intermédiaires d'une chaîne à
  insertion directe, Q = produit déposé en coffre, combustible, F1, F2 = fluides, B1…B8 = voies de bus.

  Convention d'orientation : la répétition va de gauche à droite ; les 8 orientations (D.ORIENTATIONS : 4 quarts de tour × miroir)
  placent la tuile « de haut en bas » (rot 2 ou 6) ou à l'envers ; D.instancier(motif, n, T) rend les pièces de n tuiles.

  Déterminisme : le catalogue est trié par id ; aucune fonction dans un motif (sérialisable).
]]

local function need(dotted, slashed)
  local ok, res = pcall(require, dotted)
  if ok and type(res) == "table" then return res end
  return require("__factorio-overhaul__/" .. slashed)
end
local D = need("shared.team.motifs.dsl", "shared/team/motifs/dsl")
local C = need("shared.team.motifs.compile", "shared/team/motifs/compile")

local M = {}

M.FAMILLES = { "asm", "bus", "chimie", "energie", "equilibreur", "fonte", "labo", "mine", "petrole", "science" }
M.D = D

local SOURCES = {
  "shared.team.motifs.defs_fonte", "shared.team.motifs.defs_asm", "shared.team.motifs.defs_chimie",
  "shared.team.motifs.defs_mine", "shared.team.motifs.defs_bus", "shared.team.motifs.defs_debut",
}
local SOURCES_SLASH = {
  "shared/team/motifs/defs_fonte", "shared/team/motifs/defs_asm", "shared/team/motifs/defs_chimie",
  "shared/team/motifs/defs_mine", "shared/team/motifs/defs_bus", "shared/team/motifs/defs_debut",
}

M.MOTIFS = {}
M.par_id = {}
M.erreurs = {}   -- erreurs de compilation (jamais levées : le catalogue charge ce qu'il peut, le test les compte)

local function charger()
  local defs = {}
  for i, nom in ipairs(SOURCES) do
    local liste = need(nom, SOURCES_SLASH[i])
    for _, d in ipairs(liste) do defs[#defs + 1] = d end
  end
  table.sort(defs, function(a, b) return a.id < b.id end)
  for _, def in ipairs(defs) do
    if M.par_id[def.id] then
      M.erreurs[#M.erreurs + 1] = "identifiant en double : " .. def.id
    else
      local m, err = C.compiler(def)
      if m then
        M.MOTIFS[#M.MOTIFS + 1] = m
        M.par_id[m.id] = m
      else
        M.erreurs[#M.erreurs + 1] = err
      end
    end
  end
end
charger()

function M.get(id) return M.par_id[id] end

--- Motifs d'une famille (triés par id).
function M.famille(f)
  local out = {}
  for _, m in ipairs(M.MOTIFS) do if m.famille == f then out[#out + 1] = m end end
  return out
end

--- Nombre de motifs par famille.
function M.compte()
  local c = {}
  for _, m in ipairs(M.MOTIFS) do c[m.famille] = (c[m.famille] or 0) + 1 end
  return c
end

--- Instance de n tuiles d'un motif (D.instancier) : pièces transformées, emprise, ports.
function M.instancier(id, n, T, opt)
  local m = M.par_id[id]
  if not m then return nil, "motif inconnu : " .. tostring(id) end
  if not m.repetable and n ~= 1 then return nil, "motif à tuile unique : n = 1 seulement" end
  return D.instancier(m, n, T, opt)
end

return M
