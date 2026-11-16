--[[
  N100-IMPASSES (cycle 0.9.10) : classe d'un tapis chargé sans sortie relevé par la sonde [FO-CUL-DE-SAC] (scenarios/jalons_common.lua).
  Règle PURE : aucune API du jeu, aucun nom d'objet ; testée hors jeu par tests/n100_impasses_test.lua (mutant).

  Constat (banc fo-logs/2026-11-16_n100-impasses-1, graine 4251870853, 90 min, sonde [FO-CUL-DETAIL]) : les 26 « culs-de-sac » de 90 min
  sont tous des BOUTS DE LIGNES D'ALIMENTATION (une ligne qui finit après son dernier preneur est pleine jusqu'au bout : état normal) :
  lignes de modules et de rangées (bras de quai, de machines, de fours d'acier ou de briques), entrées du mall, tronc du charbon (bras de
  dérivation), trop-plein des lignes de plaques (bras du quai de sortie), bande d'un champ de charbon vers ses coffres. La sonde d'avant
  ne regardait que la DERNIÈRE tuile (un bras qui y prend) : elle comptait ces bouts comme des impasses. Une vraie impasse est une ligne
  dont RIEN n'est pris, sans suite au plan : la matière n'y va nulle part.

  c = { suite_a_poser, souterrain_seul, preneurs, occ_suiv, propre }
    suite_a_poser   vrai si une pièce de TRANSPORT est planifiée à la case suivante et pas encore posée (un projet en chantier) ;
    souterrain_seul vrai si le tapis est l'entrée d'un souterrain sans sortie appariée (paire amputée) ;
    preneurs        nombre de bras dont la prise est sur une tuile de la ligne (la dernière et l'amont) ;
    occ_suiv        détenteur de la case suivante au plan (nil, numéro de projet, marqueur de cadre) ;
    propre          numéro du projet qui porte le tapis (nil si aucun).
  Rend "chantier" | "souterrain_ampute" | "alimentation" | "retenue" | "impasse".
]]
local M = {}

M.CLASSES = { "impasse", "souterrain_ampute", "chantier", "retenue", "alimentation" }

function M.classe(c)
  if c.suite_a_poser then return "chantier" end
  if c.souterrain_seul then return "souterrain_ampute" end
  if (c.preneurs or 0) > 0 then return "alimentation" end
  if c.occ_suiv ~= nil and c.occ_suiv ~= c.propre then return "retenue" end
  return "impasse"
end

return M
