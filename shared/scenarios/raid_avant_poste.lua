-- Scénario en boucle fermée (s43, pilier A, agent 3 scen-raid) : ASSAUT COORDONNÉ D'UNE FACTION RIVALE SUR UN AVANT-POSTE
-- ISOLÉ. Format : shared/scenarios/format.lua (action « raid »). Version greffée d'origine, plus détaillée (lieu de mort des
-- assaillants, premier défenseur) : tools/autotest/fo-autotest/scenarios/scen_raid_common.lua.
-- THÉORIE (écrite avant le banc, 13/11 23 h) : le défenseur (1) voit l'attaque d'un site lointain tout de suite, (2) le défend
-- (soldats au-dessus de la réserve du QG, tourelles, ouvriers armés) et repousse l'escouade, (3) remet ses tourelles, (4)
-- reconstruit ce qui est détruit, (5) sans abandonner l'économie du QG. L'attaquant est une escouade posée (elle ne recule pas) :
-- le choix de cible et la retraite du chef (script/faction/chef.lua) ne sont pas jugés ici.
local M = 25 -- minute de l'assaut
local FER = "iron-plate"
local AVANT = function(champ, k) return { ref = champ, de = M, a = M, fn = "max", facteur = k or 1 } end

return {
  nom = "raid-avant-poste",
  description = {
    fr = "Assaut d'une escouade d'Ecarlate sur l'avant-poste le plus eloigne d'Azur a la minute " .. M,
    en = "Scarlet squad assault on Azure's farthest outpost at minute " .. M,
  },
  base = "partie",
  duree_min = M + 10,
  equipes = { "azure" },
  rayon_qg = 80,
  suivre = { FER },
  mise_en_scene = {
    { minute = M, action = "raid", attaquant = "scarlet", soldat = "rifleman", n = 8, distance = 28, loin_min = 40 },
  },
  theorie = {
    { id = "raid-pose",
      texte = { fr = "Mise en scene : l'escouade est posee pres de l'avant-poste", en = "Staging: the squad is placed near the outpost" },
      predicat = { type = "seuil", champ = "raid_vivants", minute = M, op = ">=", valeur = 6 } },
    { id = "d1-alerte",
      texte = { fr = "D1 : l'attaque du site lointain leve une alerte de site dans la minute",
                en = "D1: the attack on the remote site raises a site alert within the minute" },
      predicat = { type = "seuil", champ = "alertes_site", minute = M + 1, op = ">=", valeur = 1 } },
    { id = "d2-defenseurs",
      texte = { fr = "D2 : des unites de l'equipe sont sur le site dans les 3 minutes",
                en = "D2: team units are on the site within 3 minutes" },
      predicat = { type = "atteint", champ = "site_unites", de = M + 1, a = M + 3, op = ">=", valeur = 1 } },
    { id = "d2-repousse",
      texte = { fr = "D2 : l'escouade est detruite en 5 minutes", en = "D2: the squad is destroyed within 5 minutes" },
      predicat = { type = "seuil", champ = "raid_vivants", minute = M + 5, op = "<=", valeur = 0 } },
    { id = "d3-tourelles",
      texte = { fr = "D3 : 10 minutes apres, le site a au moins autant de tourelles qu'avant",
                en = "D3: 10 minutes later, the site has at least as many turrets as before" },
      predicat = { type = "seuil", champ = "site_tourelles", minute = M + 10, op = ">=", valeur = AVANT("site_tourelles") } },
    { id = "d4-reconstruit",
      texte = { fr = "D4 : les foreuses du site reviennent a leur nombre d'avant en 10 minutes",
                en = "D4: the site's drills are back to their previous count within 10 minutes" },
      predicat = { type = "atteint", champ = "site_foreuses", de = M + 1, a = M + 10, op = ">=", valeur = AVANT("site_foreuses") } },
    { id = "d5-economie",
      texte = { fr = "D5 : le debit de fer de l'equipe garde 80 % de celui d'avant pendant le raid",
                en = "D5: the team's iron output keeps 80% of its previous level during the raid" },
      predicat = { type = "agregat", champ = "debit:" .. FER, de = M + 1, a = M + 10, fn = "moyenne", op = ">=",
                   valeur = { ref = "debit:" .. FER, de = M - 5, a = M - 1, fn = "moyenne", facteur = 0.8 } } },
  },
}
