--[[
  Lot S42-DEFENSE (chantier 6.1 du DC, partie de 4 h 15 en 0.7.96 : « les factions sous-estiment les biters et se font raser »).
  BUDGET DE DÉFENSE DYNAMIQUE. PUR (aucune API Factorio, aucun nom d'objet), testé hors jeu par tests/s42_defense_test.lua.

  Constat (journal de la partie) : emerald perd sa centrale à 141 min, ses tourelles du QG de 144,8 à 222 min (12 puis 0), trois
  avant-postes ; sa part de défense (δ de Ca.character, shared/ai3/capitalisation.lua) reste celle de son CARACTÈRE (100 ‰ × prudence,
  doublée sous menace) : elle ne lit jamais ce qui vient d'être détruit.

  Règle :
    * chaque perte ajoute son poids à un NIVEAU de pertes récentes (Bd.W : pièce critique, pièce ordinaire ; un mur ne pèse rien : il est
      fait pour tomber) ; le niveau est plafonné à Bd.FULL ;
    * le niveau REDESCEND tout seul, linéairement (Bd.FULL en Bd.CALM ticks) : aucune horloge à armer, aucun état à lever ; sans perte
      nouvelle la part rend la main (au plus Bd.CALM ticks après la dernière perte, bien avant pour une perte isolée) ;
    * part de la défense (‰ de la production) = Bd.BASE au calme, jusqu'à Bd.MAX à niveau plein, linéaire entre les deux.
  État : { v = niveau à l'instant t, t = tick } : deux nombres (sérialisable). Déterminisme : arithmétique seule, aucun hasard, aucun pairs.
  Coupure de banc : Bd.ON = false (la part du caractère, comme avant).
]]

local Bd = {}

Bd.ON = true
Bd.BASE = 50            -- ‰ : part de base (tourelles, munitions, réapprovisionnement) : « environ 5 % »
Bd.MAX = 950            -- ‰ : part à niveau de pertes plein (« 90 à 100 % »)
Bd.FULL = 12            -- niveau plein : trois pièces critiques perdues coup sur coup
Bd.CALM = 10 * 3600     -- ticks : un niveau plein retombe à zéro en ce temps, sans perte nouvelle
Bd.W = { critique = 4, piece = 1, mur = 0 }
Bd.TIERS = { { 500, "crise" }, { 51, "alerte" }, { 0, "base" } } -- paliers du journal (part ≥ seuil), du plus haut au plus bas

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge and v or nil end

function Bd.new() return { v = 0, t = 0 } end

--- Niveau de pertes récentes à `tick` (0 à Bd.FULL) : le niveau noté, moins la décroissance depuis.
function Bd.level(st, tick)
  if type(st) ~= "table" then return 0 end
  local v, t, now = num(st.v) or 0, num(st.t) or 0, num(tick) or 0
  local dt = now - t
  if dt < 0 then dt = 0 end
  v = v - Bd.FULL * dt / Bd.CALM
  if v < 0 then v = 0 end
  if v > Bd.FULL then v = Bd.FULL end
  return v
end

--- Une perte de classe `class` (clé de Bd.W ; inconnue : pièce ordinaire) à `tick`. Rend le niveau après la perte.
function Bd.note(st, tick, class)
  local w = Bd.W[class]
  if w == nil then w = Bd.W.piece end
  local v = Bd.level(st, tick) + w
  if v > Bd.FULL then v = Bd.FULL end
  st.v, st.t = v, num(tick) or 0
  return v
end

--- Part de la défense (‰, entier) à `tick` : Bd.BASE au calme, Bd.MAX à niveau plein.
function Bd.share(st, tick)
  local lv = Bd.level(st, tick)
  return Bd.BASE + math.floor((Bd.MAX - Bd.BASE) * lv / Bd.FULL + 1e-9)
end

--- Palier d'une part (journal seulement) : « base », « alerte », « crise ».
function Bd.tier(share)
  for _, t in ipairs(Bd.TIERS) do
    if (num(share) or 0) >= t[1] then return t[2] end
  end
  return "base"
end

--- Ticks de calme encore nécessaires pour que la part revienne à Bd.BASE (0 : elle y est).
function Bd.calm_in(st, tick)
  return math.max(0, math.ceil(Bd.level(st, tick) * Bd.CALM / Bd.FULL - 1e-9))
end

return Bd
