--[[
  Dégâts des tourelles par niveau (lot TIRS, décision D-21 du DC, 27/10 : « Aussi les dégâts » ; courbe C2 de
  fo-logs\2026-10-27_TIRS\EQUILIBRE.md). Lua pur, NOMBRES ÉCRITS (aucun calcul de puissance au chargement du jeu :
  même résultat sur tous les clients). Lu par shared/levels/config.lua (statistique `damage_modifier` de la
  mitrailleuse ET du laser, op « table ») : prototype, panneau du centre et règles des factions lisent le prototype.

  Multiplicateur de dégâts du niveau n RELATIF au niveau 1 vanilla (le laser vanilla a déjà `damage_modifier` 2 :
  le niveau n du laser vaut 2 × par_niveau[n]). Âge e = niveaux 2e - 1 et 2e. Niveaux 1 à 6 (âges 1 à 3) = le jeu
  d'avant (1 + 0,08 (n - 1)) ; ensuite × 1,15 PAR ÂGE (× 1,0724 par niveau), 1,4 × 1,15^(âge - 3) au niveau pair 2e :
  1,61 à l'âge 4, 1,85 à l'âge 5, 3,72 à l'âge 10, 7,49 à l'âge 15 (niveau 30) ; niveau impair 2e - 1 = 1,4 × 1,15^(e - 3,5),
  arrondi au centième. Décision du DC du 28/10 (soir) : « en fait x1.2 c'est un peu trop, x1.1 c'est mieux », puis
  « ah ok donc on par sur 1.15 ? » (réponse : oui) : D-21 révisée, × 1,15 par âge ; les courbes × 1,2 (12,48 au niveau 30)
  et × 1,1 (4,39) sont abandonnées. Aujourd'hui (0.6.5) : + 8 % par niveau jusqu'au 10 puis + 2 % : 2,12 au niveau 30.
  Niveau 2e, nouvelle contre 0.6.5 : âge 4 1,61 / 1,56 ; 5 1,85 / 1,72 ; 6 2,13 / 1,76 ; 7 2,45 / 1,80 ; 8 2,82 / 1,84 ;
  9 3,24 / 1,88 ; 10 3,72 / 1,92 ; 11 4,28 / 1,96 ; 12 4,93 / 2,00 ; 13 5,66 / 2,04 ; 14 6,51 / 2,08 ; 15 7,49 / 2,12
  (3,5 fois les dégâts d'aujourd'hui au niveau 30 ; dégâts par joule du laser × 3,47 au niveau 30 : 7,49 / 2,16).
]]

local D = {}

D.par_niveau = { 1.00, 1.08,  1.16, 1.24,  1.32, 1.40,  1.50, 1.61,  1.73, 1.85,  1.99, 2.13,  2.28, 2.45,
  2.63, 2.82,  3.02, 3.24,  3.47, 3.72,  3.99, 4.28,  4.59, 4.93,  5.28, 5.66,  6.07, 6.51,  6.98, 7.49 }

--- Multiplicateur de dégâts du niveau n (1 à 30).
function D.mult(n) return D.par_niveau[n] end

--- Rapport d'un âge au précédent (âge e = niveau 2e), pour les contrôles : D.rapport_age(e) = mult(2e) / mult(2e - 2).
function D.rapport_age(e) return D.par_niveau[2 * e] / D.par_niveau[2 * e - 2] end

--- Règle K9 hors jeu : rend la liste des motifs de refus d'une table de dégâts t (vide si elle est bonne) :
--- 30 nombres, t[1] = 1, strictement croissants, niveaux 1 à 6 = 1 + 0,08 (n - 1) (jeu d'avant, âges 1 à 3),
--- rapport d'un âge au précédent = 1,15 à 0,012 près de l'âge 4 à l'âge 15.
function D.verifier(t)
  local out = {}
  if type(t) ~= "table" or #t ~= 30 then return { "30 nombres attendus" } end
  for n = 1, 30 do if type(t[n]) ~= "number" then return { "niveau " .. n .. " : nombre attendu" } end end
  if t[1] ~= 1 then out[#out + 1] = "niveau 1 : 1 attendu (tourelle vanilla)" end
  for n = 2, 30 do
    if not (t[n] > t[n - 1]) then out[#out + 1] = "niveau " .. n .. " : pas plus fort que le niveau " .. (n - 1) end
  end
  for n = 1, 6 do
    if math.abs(t[n] - (1 + 0.08 * (n - 1))) > 1e-9 then out[#out + 1] = "niveau " .. n .. " : le jeu d'avant (1 + 0,08 (n - 1)) est change" end
  end
  for e = 4, 15 do
    local r = t[2 * e] / t[2 * e - 2]
    if math.abs(r - 1.15) > 0.012 then out[#out + 1] = string.format("age %d : rapport %.3f a l'age precedent (1,15 attendu)", e, r) end
  end
  return out
end

return D
