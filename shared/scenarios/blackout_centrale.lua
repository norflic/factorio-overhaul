-- Scénario en boucle fermée (s43 scen-energie, pilier A) : RUPTURE DE CHARBON / BLACKOUT EN PLEINE MONTÉE EN CHARGE.
-- Format : shared/scenarios/format.lua. Version fine (relevé toutes les 5 s) : tools/autotest/fo-autotest/scenarios/scen-blackout.lua.
-- À la minute M, le combustible des chaudières, de leurs coffres d'alimentation, des mains des bras et des tapis voisins est retiré
-- et le tapis de charbon coupé (2 tapis détruits) ; le stock du QG reste.
-- THÉORIE (écrite avant le premier banc, le 13/11 à 23 h 15) : le cerveau (1) détecte la panne (Sante.observe, script/team/
-- sante_centrale.lua:72, toutes les 5 s : chaudières à sec, production contre capacité), (2) remonte à la cause (S.classify :
-- chaudiere_a_sec, tapis_manquant), (3) ravitaille (amorce à la main S.prime depuis le stock du QG, tâche prio 92 ; tournée de quai ;
-- bras thermiques de secours), (4) répare la ligne (reconstruction des tapis), (5) la satisfaction électrique revient à 95 % de
-- celle d'avant en moins de T minutes.
local M = 25 -- minute de la coupe
local T = 5  -- délai de retour

local AVANT = { ref = "elec_sat", de = M - 3, a = M - 1, fn = "moyenne", facteur = 0.95 }

return {
  nom = "blackout-centrale",
  description = {
    fr = "Blackout : combustible des chaudieres, coffres et tapis retire, tapis de charbon coupe a la minute " .. M,
    en = "Blackout: boiler, chest and belt fuel removed, coal belt cut at minute " .. M,
  },
  base = "partie",
  duree_min = M + T + 2,
  equipes = "toutes",
  rayon_qg = 80,
  suivre = {},
  mise_en_scene = {
    { minute = M, action = "assecher_centrale", rayon = 6, tapis_coupes = 2 },
  },
  theorie = {
    { id = "centrale-en-marche",
      texte = { fr = "Avant la coupe, la centrale produit (au moins 1 kW en moyenne sur 3 min)",
                en = "Before the cut, the plant produces (at least 1 kW on average over 3 min)" },
      predicat = { type = "agregat", champ = "elec_kw", de = M - 3, a = M - 1, fn = "moyenne", op = ">=", valeur = 1 } },
    { id = "coupe-posee",
      texte = { fr = "Mise en scene : au moins une chaudiere a sec juste apres la coupe",
                en = "Staging: at least one boiler dry right after the cut" },
      predicat = { type = "seuil", champ = "chaudieres_a_sec", minute = M, op = ">=", valeur = 1 } },
    { id = "chaudieres-rallumees",
      texte = { fr = "Toutes les chaudieres rallumees en moins de " .. T .. " min",
                en = "All boilers relit within " .. T .. " min" },
      predicat = { type = "atteint", champ = "chaudieres_a_sec", de = M + 1, a = M + T, op = "<=", valeur = 0 } },
    { id = "satisfaction-revenue",
      texte = { fr = "La satisfaction electrique revient a 95 % de celle d'avant en moins de " .. T .. " min",
                en = "Electric satisfaction is back to 95% of its previous level within " .. T .. " min" },
      predicat = { type = "atteint", champ = "elec_sat", de = M + 1, a = M + T, op = ">=", valeur = AVANT } },
    { id = "satisfaction-tenue",
      texte = { fr = "Et elle tient : a 95 % de celle d'avant les deux minutes suivantes",
                en = "And it holds: at 95% of its previous level for the next two minutes" },
      predicat = { type = "agregat", champ = "elec_sat", de = M + T + 1, a = M + T + 2, fn = "min", op = ">=", valeur = AVANT } },
  },
}
