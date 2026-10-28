--[[
  Dégâts des tourelles par niveau (lot TIRS, décision D-21 du DC, 27/10 : « Aussi les dégâts » ; courbe C2 de
  fo-logs\2026-10-27_TIRS\EQUILIBRE.md). Lua pur, NOMBRES ÉCRITS (aucun calcul de puissance au chargement du jeu :
  même résultat sur tous les clients). Lu par shared/levels/config.lua (statistique `damage_modifier` de la
  mitrailleuse ET du laser, op « table ») : prototype, panneau du centre et règles des factions lisent le prototype.

  Multiplicateur de dégâts du niveau n RELATIF au niveau 1 vanilla (le laser vanilla a déjà `damage_modifier` 2 :
  le niveau n du laser vaut 2 × par_niveau[n]). Âge e = niveaux 2e - 1 et 2e. Niveaux 1 à 6 (âges 1 à 3) = le jeu
  d'avant (1 + 0,08 (n - 1)) ; ensuite × 1,2 par âge (× 1,0954 par niveau), 12,48 au niveau 30. Aujourd'hui (0.6.5) :
  + 2 % par âge de 6 à 15, 2,12 au niveau 30.
]]

local D = {}

D.par_niveau = { 1.00, 1.08,  1.16, 1.24,  1.32, 1.40,  1.53, 1.68,  1.84, 2.02,  2.21, 2.42,  2.65, 2.90,
  3.18, 3.48,  3.82, 4.18,  4.58, 5.02,  5.50, 6.02,  6.59, 7.22,  7.91, 8.67,  9.50, 10.40,  11.39, 12.48 }

--- Multiplicateur de dégâts du niveau n (1 à 30).
function D.mult(n) return D.par_niveau[n] end

--- Rapport d'un âge au précédent (âge e = niveau 2e), pour les contrôles : D.rapport_age(e) = mult(2e) / mult(2e - 2).
function D.rapport_age(e) return D.par_niveau[2 * e] / D.par_niveau[2 * e - 2] end

return D
