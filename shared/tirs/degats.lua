--[[
  Dégâts des tourelles par niveau (lot TIRS, D-21 ; RÉVISÉE par le lot EQUILIBRE le 31/10 sur le retour du DC :
  « passer à x1.15 de stats par niveau et non par âge pour les défenses »). Lua pur, NOMBRES ÉCRITS (aucun calcul de
  puissance au chargement du jeu : même résultat sur tous les clients). Lu par shared/levels/config.lua (statistique
  `damage_modifier` de la mitrailleuse ET du laser, op « table ») : prototype, panneau du centre et règles des
  factions lisent le prototype.

  Multiplicateur de dégâts du niveau n RELATIF au niveau 1 vanilla (le laser vanilla a déjà `damage_modifier` 2 : le
  niveau n du laser vaut 2 × par_niveau[n]) : 1,15^(n-1) arrondi au centième, soit × 1,15 PAR NIVEAU (× 1,32 par âge)
  et × 57,58 au niveau 30. Avant (0.6.27, D-21 du 28/10) : × 1,15 par ÂGE à partir de l'âge 4, 7,49 au niveau 30 ;
  avant 0.6.5 : + 8 % par niveau. Niveau 2e : âge 4 : 1,52 (avant 1,61), âge 8 : 2,66 / 2,82, âge 10 : 3,52 / 3,72,
  âge 12 : 4,65 / 4,93, âge 15 : 57,58 / 7,49 (niveau 30 : × 7,7 contre l'ancienne courbe).
]]

local D = {}

D.par_niveau = {
  1.00, 1.15, 1.32, 1.52, 1.75, 2.01, 2.31, 2.66, 3.06, 3.52,
  4.05, 4.65, 5.35, 6.15, 7.08, 8.14, 9.36, 10.76, 12.38, 14.23,
  16.37, 18.82, 21.64, 24.89, 28.63, 32.92, 37.86, 43.54, 50.07, 57.58 }

--- Multiplicateur de dégâts du niveau n (1 à 30).
function D.mult(n) return D.par_niveau[n] end

--- Rapport d'un âge au précédent (âge e = niveau 2e), pour les contrôles : D.rapport_age(e) = mult(2e) / mult(2e - 2).
function D.rapport_age(e) return D.par_niveau[2 * e] / D.par_niveau[2 * e - 2] end

--- Règle K9 hors jeu : rend la liste des motifs de refus d'une table de dégâts t (vide si elle est bonne) :
--- 30 nombres, t[1] = 1, strictement croissants, chaque niveau = 1,15^(n-1) à 0,6 % + 0,006 près (× 1,15 PAR NIVEAU).
function D.verifier(t)
  local out = {}
  if type(t) ~= "table" or #t ~= 30 then return { "30 nombres attendus" } end
  for n = 1, 30 do if type(t[n]) ~= "number" then return { "niveau " .. n .. " : nombre attendu" } end end
  if t[1] ~= 1 then out[#out + 1] = "niveau 1 : 1 attendu (tourelle vanilla)" end
  local want = 1
  for n = 2, 30 do
    want = want * 1.15
    if not (t[n] > t[n - 1]) then out[#out + 1] = "niveau " .. n .. " : pas plus fort que le niveau " .. (n - 1) end
    if math.abs(t[n] - want) > 0.006 * want + 0.006 then
      out[#out + 1] = string.format("niveau %d : %.2f au lieu de %.2f (1,15 par niveau)", n, t[n], want)
    end
  end
  return out
end

return D
