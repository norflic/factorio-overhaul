--[[
  Lot TV-VAPEUR, point V89 (docs/TODO_VIDEO.md l.155 : « keep UPS above 60 for a couple hundred mega tiles ») : DÉGRADATION GRADUÉE quand
  le jeu est chargé, sur un signal DÉTERMINISTE. RÈGLE PURE (aucune API Factorio ; tests/charge_test.lua, avec mutants).

  Signal : q = nombre de demandeurs de travaux lourds REFUSÉS et en attente dans la file du jeton (script/core/lourd.lua, J.waiting).
  C'est de l'état de jeu (identique sur tous les clients et après un chargement), JAMAIS un temps mesuré : plus l'usine est grande, plus les
  relevés déclarent de chunks (coûts du jeton), plus la file s'allonge. Échantillon toutes les Ch.SAMPLE ticks, lissé en entier :
  ema (en seizièmes de file) += (16 q − ema) / 4, arrondi vers la cible (il l'atteint exactement).
  Niveau 0 à 3 : on monte au niveau k dès que ema >= Ch.UP[k] files ; on redescend d'UN niveau quand ema < (Ch.UP[niveau] − Ch.HYST) files
  (hystérésis : aucun battement autour d'un seuil).
  Levier : Ch.stretch(ticks, niveau) espace un travail NON URGENT (Ch.PERCENT : 100, 150, 200, 300 %). Les urgences (défense, courant,
  votre équipe) ne l'appellent jamais.
]]

local Ch = {}

Ch.SAMPLE = 60               -- ticks entre deux échantillons de la file
Ch.UP = { 2, 4, 8 }          -- files (lissées) à partir desquelles on passe aux niveaux 1, 2, 3
Ch.HYST = 1                  -- file de marge à la descente
Ch.MAX = #Ch.UP              -- niveau le plus haut
Ch.PERCENT = { 100, 150, 200, 300 } -- durée d'un travail non urgent, en % de sa période normale, par niveau (index niveau + 1)
Ch.LOGS = 40                 -- lignes [FO-CHARGE] au plus par partie

--- Un échantillon. st = { ema, level } (modifié) ; q = file au tick. Rend (niveau avant, niveau après).
function Ch.sample(st, q)
  q = (type(q) == "number" and q >= 0) and math.floor(q) or 0
  local ema = st.ema or 0
  local d = 16 * q - ema
  if d > 0 then ema = ema + math.ceil(d / 4) elseif d < 0 then ema = ema + math.floor(d / 4) end
  st.ema = ema
  local before = st.level or 0
  local level = before
  local up = 0
  for k = 1, #Ch.UP do
    if ema >= Ch.UP[k] * 16 then up = k end
  end
  if up > level then
    level = up
  elseif level > 0 and ema < (Ch.UP[level] - Ch.HYST) * 16 then
    level = level - 1
  end
  st.level = level
  return before, level
end

--- Durée (ticks, entière) d'un travail non urgent de période `ticks` au niveau `level` (inconnu ou hors bornes : la période normale).
function Ch.stretch(ticks, level)
  local pct = Ch.PERCENT[(tonumber(level) or 0) + 1] or 100
  return math.floor(ticks * pct / 100)
end

return Ch
