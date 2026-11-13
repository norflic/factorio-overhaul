-- Scénario en boucle fermée n° 1 (s43, pilier A) : FAMINE DE FER SOUS ATTAQUE. Format : shared/scenarios/format.lua.
-- À la minute M, le fer en plaques des coffres de chaque équipe est retiré et une vague de biters attaque son QG.
-- THÉORIE (écrite avant le premier banc, le 13/11 à 23 h) : le cerveau doit (1) réparer le fer avant de s'étendre,
-- (2) réapprovisionner ses tourelles, (3) ne laisser aucun PNJ inactif, (4) retrouver le débit de fer d'avant en moins de T min.
local M = 20 -- minute de la famine et de l'attaque
local T = 10 -- délai de retour du débit de fer
local FER = "iron-plate"
local AVANT = { ref = "debit:" .. FER, de = M - 3, a = M - 1, fn = "moyenne", facteur = 0.9 }

local revenu = { type = "atteint", champ = "debit:" .. FER, de = M + 1, a = M + T, op = ">=", valeur = AVANT }

return {
  nom = "famine-fer-attaque",
  description = {
    fr = "Famine de fer sous attaque : coffres de fer vides et vague de biters sur le QG a la minute " .. M,
    en = "Iron famine under attack: iron chests emptied and a biter wave on the HQ at minute " .. M,
  },
  base = "partie",
  duree_min = M + T + 1,
  equipes = "toutes",
  rayon_qg = 80,
  suivre = { FER },
  mise_en_scene = {
    { minute = M, action = "vider_coffres", objets = { FER } },
    { minute = M, action = "attaque", unites = { { "small-biter", 12 }, { "medium-biter", 6 } }, distance = 45, rayon = 16 },
  },
  theorie = {
    { id = "famine-posee",
      texte = { fr = "Mise en scene : plus une plaque de fer au stock juste apres la famine",
                en = "Staging: no iron plate left in stock right after the famine" },
      predicat = { type = "seuil", champ = "stock:" .. FER, minute = M, op = "<=", valeur = 0 } },
    { id = "fer-revenu",
      texte = { fr = "Le debit de fer revient a 90 % de celui d'avant en moins de " .. T .. " min",
                en = "Iron output is back to 90% of its previous level within " .. T .. " min" },
      predicat = revenu },
    { id = "fer-avant-expansion",
      texte = { fr = "La reparation du fer passe devant l'expansion : debit revenu avant tout nouvel avant-poste",
                en = "Iron repair comes before expansion: output restored before any new outpost" },
      predicat = { type = "avant", premier = revenu,
        second = { type = "atteint", champ = "avant_postes", de = M + 1, a = M + T, op = ">",
                   valeur = { ref = "avant_postes", de = M, a = M, fn = "max" } } } },
    { id = "tourelles-reapprovisionnees",
      texte = { fr = "Cinq minutes apres l'attaque, aucune tourelle du QG n'est sans munitions",
                en = "Five minutes after the attack, no HQ turret is out of ammo" },
      predicat = { type = "seuil", champ = "tourelles_vides", minute = M + 5, op = "<=", valeur = 0 } },
    { id = "qg-tenu",
      texte = { fr = "Le QG tient la vague", en = "The HQ survives the wave" },
      predicat = { type = "agregat", champ = "qg_vie", de = M + 1, a = M + T, fn = "min", op = ">", valeur = 0 } },
    { id = "zero-inactif",
      texte = { fr = "Aucun PNJ ne reste inactif : au plus 1 PNJ inactif en moyenne pendant la crise",
                en = "No NPC stays idle: at most 1 idle NPC on average during the crisis" },
      predicat = { type = "agregat", champ = "pnj_inactifs", de = M + 1, a = M + T, fn = "moyenne", op = "<=", valeur = 1 } },
    { id = "zero-idle-journal",
      texte = { fr = "Journal [FO-ZERO-IDLE] : jamais plus de 2 PNJ libres sans tache pendant la crise",
                en = "[FO-ZERO-IDLE] log: never more than 2 free NPCs without a task during the crisis" },
      predicat = { type = "ligne", motif = [[\[FO-ZERO-IDLE\] {equipe} minute \d+ \| .*?PNJ libres (\d+) sans tache]],
                   de = M + 1, a = M + T, fn = "max", op = "<=", valeur = 2 } },
  },
}
