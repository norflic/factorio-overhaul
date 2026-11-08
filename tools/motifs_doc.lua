--[[
  Lot MOTIFS : génère docs/MOTIFS.md (lisible par le DC) depuis shared/team/motifs/catalogue.lua : classement par taille, nombre
  d'entrées et de sorties, modularité ; dessin de deux tuiles de chaque motif ; sources.
  Usage, depuis la racine du mod :   lua5.2 tools/motifs_doc.lua > docs/MOTIFS.md
]]

package.path = "./?.lua;" .. package.path
local Cat = require("shared.team.motifs.catalogue")
local D = Cat.D

local out = {}
local function p(s) out[#out + 1] = s end

p("# Base de motifs industriels (lot MOTIFS)")
p("")
p("Généré par `lua5.2 tools/motifs_doc.lua > docs/MOTIFS.md` : ne pas modifier à la main (la source est `shared/team/motifs/`).")
p("")
p("Demande du DC (8/11, vers 18 h 45) : des blocs compacts, équilibrés en entrées/sorties, strictement duplicables (coller les modules en série de gauche à droite ou de haut en bas) ; une base classée par taille, nombre d'entrées (n), de sorties (m) et modularité, que les scripts de placement INTERROGENT pour choisir et adapter le motif au terrain.")
p("")
p("## Comment c'est fait")
p("")
p("- Un **motif** est une **tuile** répétable le long d'un axe (période, emprise l × h). Ses pièces sont décrites par **rôle** (`machine_fonte`, `machine_asm`, `bras`, `bras_long`, `tapis_entree`, `tapis_sortie`, `repartiteur`, `souterrain_*`, `poteau`, `tuyau`, `tuyau_souterrain`, `coffre`, `foreuse`, `chevalet`…), **jamais par nom d'objet** : la correspondance rôle → prototype se fait en jeu, d'après les prototypes lus (vitesses, tailles, portée des bras).")
p("- **Orientations** : la répétition est écrite de gauche à droite ; `catalogue.instancier(id, n, { rot, miroir })` donne les 8 orientations (4 quarts de tour × miroir), donc aussi « de haut en bas ».")
p("- **Sélection** : `choix.lua` (`Choix.choisir`) reçoit le terrain (rectangle libre, obstacles, ou carte de tuiles libres), la demande (jeton et débit, ou nombre de voies, ou entrées et sorties d'un équilibreur), les entrées disponibles (côté, position, ce qu'elles portent), et ce que le client a lu aux prototypes. Elle rend le motif, le nombre de tuiles qui **tient et suffit**, l'orientation, le rectangle réservé, le débit, et la **cause** de chaque motif écarté.")
p("- **Vérification** : `lua5.2 tests/motifs_test.lua` (cohérence de chaque motif, orientations, équilibreurs par suivi de flux, 23 terrains de sélection, coût en instructions, mutants).")
p("- **Honnêteté sur l'origine** : `ref_dc` = transcrit des 4 images du DC ; `forum` / `wiki` = la logique du motif vient de la source citée (page lue par résumé de recherche, pas de blueprint copié) ; `derive` = géométrie déduite par nous. Dans tous les cas les coordonnées sont les nôtres, vérifiées hors jeu ; **rien n'est prouvé en moteur réel** (aucun banc lancé par ce lot).")
p("")
p("Lecture des dessins : `>` `<` `^` `v` tapis (sens de la marche) ; `n` `e` `s` `o` bras (côté de PRISE ; majuscule = bras long) ; `u` `U` entrée / sortie de tapis souterrain ; `=` répartiteur ; `+` poteau ; `~` tuyau ; `t` tuyau souterrain ; `#` coffre ; `A…Z` machines.")
p("")

-- classement
local liste = {}
for _, m in ipairs(Cat.MOTIFS) do liste[#liste + 1] = m end
table.sort(liste, function(a, b)
  if a.famille ~= b.famille then return a.famille < b.famille end
  local da, db = a.derive, b.derive
  if da.surface ~= db.surface then return da.surface < db.surface end
  return a.id < b.id
end)

p("## Classement")
p("")
p("| Motif | Famille | Tuile l × h | Période | Entrées n | Sorties m | Modularité | Machines / tuile | Origine |")
p("|---|---|---|---|---|---|---|---|---|")
for _, m in ipairs(liste) do
  local d = m.derive
  p(string.format("| `%s` | %s | %d × %d | %d | %d | %d | %s | %d | %s |", m.id, m.famille, m.periode, m.h, m.periode, d.n_entrees, d.m_sorties,
    d.modularite == "serie" and "série (x ou y)" or "tuile unique", d.machines, m.origine))
end
p("")
local compte = Cat.compte()
local fams = {}
for _, f in ipairs(Cat.FAMILLES) do fams[#fams + 1] = f .. " " .. (compte[f] or 0) end
p(string.format("%d motifs : %s.", #Cat.MOTIFS, table.concat(fams, ", ")))
p("")

p("## Ratios usuels (calculés, jamais écrits dans le catalogue)")
p("")
p("`Choix.rapport(amont, aval, jeton)` donne le nombre de machines amont par machine aval d'après les recettes et les vitesses lues en jeu ; `Choix.bras_necessaires` et `Choix.machines_par_voie` donnent les bras et les machines par voie de tapis. Valeurs pour les recettes de base à vitesses égales :")
p("")
p("| Liaison | Données de recette | Ratio amont : aval | Motif qui le réalise |")
p("|---|---|---|---|")
local Ch = require("shared.team.motifs.choix")
local function fmt(r) return string.format("%.2f", r) end
local engr = { temps = 0.5, vitesse = 1, sorties = { M = 1 } }
p("| engrenage → pack rouge | 0,5 s, 1 engrenage ; 5 s, 1 engrenage | " .. fmt(Ch.rapport(engr, { temps = 5, vitesse = 1, entrees = { M = 1 } }, "M")) .. " (1 : 10) | aucun en insertion directe : `asm-chaine-1-2` ne fait que 1 : 2 (l'amont tournerait à 20 %) ; passer par un tapis d'engrenages (`asm-2e-1s`, `asm-miroir-2e`) |")
p("| câble → circuit | 0,5 s, 2 câbles ; 0,5 s, 3 câbles | " .. fmt(Ch.rapport({ temps = 0.5, vitesse = 1, sorties = { M = 2 } }, { temps = 0.5, vitesse = 1, entrees = { M = 3 } }, "M")) .. " (3 : 2) | `asm-cable-circuit-3-2-simple`, `asm-cable-circuit-3-2-double` |")
p("| plaque → acier | 3,2 s, 1 plaque ; 16 s, 5 plaques | " .. fmt(Ch.rapport({ temps = 3.2, vitesse = 1, sorties = { M = 1 } }, { temps = 16, vitesse = 1, entrees = { M = 5 } }, "M")) .. " (1 : 1) | `fonte-chaine-directe-3x3` |")
p("| four de plaques → machine d'engrenages (vitesse 2 → 0,75) | 3,2 s, 1 plaque ; 0,5 s, 2 plaques | " .. fmt(Ch.rapport({ temps = 3.2, vitesse = 2, sorties = { M = 1 } }, { temps = 0.5, vitesse = 0.75, entrees = { M = 2 } }, "M")) .. " | tapis (aucun motif en insertion directe) |")
p("")
p("Un bras de base (0,83 objet/s) qui prend sur un tapis porte 0,83 × 0,85 × 0,9 = 0,635 objet/s : un four d'acier (0,625 objet/s de plaques) l'occupe presque entièrement. Une voie de tapis jaune (7,5 objets/s) nourrit " .. Ch.machines_par_voie(0.625, 7.5) .. " fours d'acier ou " .. Ch.machines_par_voie(0.3125, 7.5) .. " fours de pierre.")
p("")

p("## Les motifs")
for _, m in ipairs(liste) do
  local d = m.derive
  p("")
  p("### `" .. m.id .. "` : " .. m.nom_fr)
  p("")
  p(string.format("Famille **%s**, usages : %s. Origine : **%s**%s. Tuile %d × %d, période %d, %s, %d entrée(s), %d sortie(s), %d machine(s) par tuile.",
    m.famille, table.concat(m.usages, ", "), m.origine, m.ref and (" (" .. m.ref .. ")") or "", m.periode, m.h, m.periode,
    d.modularite == "serie" and "répétable en série" or "tuile unique", d.n_entrees, d.m_sorties, d.machines))
  if m.note_fr then p(""); p(m.note_fr) end
  p("")
  local roles = {}
  for _, r in ipairs(m.roles) do
    local n = 0
    for _, pc in ipairs(m.pieces) do if pc.role == r then n = n + 1 end end
    roles[#roles + 1] = r .. " ×" .. n
  end
  p("Pièces d'une tuile : " .. table.concat(roles, ", ") .. ".")
  local droit = {}
  for _, x in ipairs(d.droits) do droit[#droit + 1] = x.role .. ":" .. x.k .. " (rangée " .. x.y .. ")" end
  p(string.format("Place minimale : %d × %d (une tuile%s). Doit rester droit : %s.", d.place_min.l, d.place_min.h,
    (m.tete or m.queue) and ", tête et queue comprises" or "", #droit > 0 and table.concat(droit, ", ") or "rien sur toute la largeur"))
  if m.exige_poteau then p(string.format("Poteau exigé : aire %.1f, fil %.1f.", m.exige_poteau.supply, m.exige_poteau.fil)) end
  p("")
  p("```")
  local n = m.repetable and 2 or 1
  local inst = D.instancier(m, n, { rot = 0, miroir = false })
  for _, l in ipairs(D.dessiner(inst)) do p(l) end
  p("```")
  p("")
  local srcs = {}
  for _, u in ipairs(m.source) do srcs[#srcs + 1] = u end
  p("Sources : " .. table.concat(srcs, " ; "))
end

print(table.concat(out, "\n"))
