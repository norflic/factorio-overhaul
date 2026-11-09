--[[
  Lot COMBUSTIBLE-MIGRATION (suite, 9/11) : déduplication des pièces d'un projet de champ dont la tuile est DÉJÀ au plan d'un autre projet.
  PUR : aucune API Factorio, aucun nom d'objet ; testé hors jeu par tests/champ_dedupe_test.lua (mutants). Exécutant : Build.SITES.champ
  (script/team/champ.lua).

  Défaut cherché (fo-logs/2026-11-09_CANDIDAT/carte-g123456789-1d7c6218, votre équipe) : « projet 9 (bande -37) : 28 pièce(s) écartée(s), leurs tuiles déjà
  au plan du projet 11 : small-electric-pole 4, transport-belt 24 » (rôle champ-charbon, commun), alors que la voie de charbon du champ de fer livre
  si peu que 72 fours sur 112 sont sans combustible. Avant ce lot, une pièce était écartée dès que sa tuile était au plan d'un AUTRE projet, quel que soit
  ce que le détenteur y pose : un tapis d'un autre flux, ou dans l'autre sens, coupait le tronc en silence.

  Règle : une pièce n'est écartée que si, sur CHACUNE de ses tuiles prises, le détenteur porte la même pièce (même nom, même rôle, même direction : un
  doublon légitime, le tronc commun posé par la première bande d'un côté). Sinon la tuile est un CONFLIT : une pièce du réseau du charbon en conflit
  coupe le tronc (`cut`), l'exécutant refuse le réseau avec la cause au journal (une autre tentative le retrace, les tuiles du détenteur étant alors
  connues du plan) ; toute autre pièce reste écartée comme avant (la ligne du journal la compte à part).
  Aucun `pairs` décisionnel, aucun hasard, aucun temps mesuré.
]]

local M = {}

--- Le détenteur `h` porte-t-il la même pièce que `e` ? Mêmes nom, rôle et direction (direction absente = 0). `h` nil : non.
function M.same(e, h)
  if not (e and h) then return false end
  return e.name == h.name and e.role == h.role and (e.dir or 0) == (h.dir or 0)
end

--- Verdict pour une pièce `e` dont les tuiles prises ont pour détenteurs `held` = { { pid, ent }, ... } (une entrée par tuile prise ; ent nil si le projet
--- détenteur ne porte plus de pièce sur cette tuile). Rend ("garder" si rien n'est pris, "ecarter" si tout est un doublon légitime, "conflit" sinon).
function M.verdict(e, held)
  if #held == 0 then return "garder" end
  for _, x in ipairs(held) do
    if not M.same(e, x.ent) then return "conflit" end
  end
  return "ecarter"
end

--- Une pièce en conflit coupe-t-elle le tronc du charbon ? `role_coal` : le rôle de la pièce est celui du réseau du charbon.
function M.cuts_trunk(verdict, role_coal)
  return verdict == "conflit" and role_coal == true
end

return M
