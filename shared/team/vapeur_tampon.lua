--[[
  Lot TV-VAPEUR, point V36 (docs/TODO_VIDEO.md l.102 : « check if the steam in the storage tanks has gone below a certain threshold …
  feed fuel cells ») : le remplissage de charbon du coffre de la centrale se déclenche AUSSI sur le TAMPON de vapeur, en plus de la
  consommation (shared/team/charbon_centrale.lua). RÈGLE PURE (aucune API Factorio ; tests/vapeur_tampon_test.lua, avec mutants).

  Tampon = vapeur contenue dans les machines à vapeur de la centrale (lecture de leurs boîtes à fluide, toutes les Vt.EVERY ticks, par
  script/team/vapeur_glue.lua). Taux = vapeur / capacité. État « bas » avec HYSTÉRÉSIS (V37) : on entre sous Vt.LOW_IN, on ne sort qu'à
  Vt.LOW_OUT. Tampon bas et coffre sous Vt.COMFORT de la cible : Cc.refill rend la tâche urgente (le coffre est peut-être plein
  d'avance pour la consommation mais la vapeur manque déjà : le courant de toute la base passe avant). Coffre au-dessus du confort :
  rien (le manque vient alors d'ailleurs : tapis coupé, chaudière détruite, demande au-delà de la centrale ; ce n'est pas du charbon).
]]

local Vt = {}

Vt.EVERY = 300     -- ticks entre deux lectures du tampon d'une centrale
Vt.LOW_IN = 0.30   -- on entre dans l'état « bas » sous ce taux
Vt.LOW_OUT = 0.60  -- on en sort à ce taux
Vt.COMFORT = 0.75  -- part de la cible du coffre au-dessus de laquelle un tampon bas ne déclenche rien
Vt.MAX_READ = 12   -- machines à vapeur lues au plus par relevé (les premières du plan)
Vt.LOGS = 40       -- lignes [FO-VAPEUR-TAMPON] au plus par équipe

--- Taux de remplissage : parts = { { amount, cap }, ... } (machines lues). nil sans capacité connue.
function Vt.ratio(parts)
  local a, c = 0, 0
  for i, p in ipairs(parts or {}) do
    if i > Vt.MAX_READ then break end
    if type(p.cap) == "number" and p.cap > 0 then
      a = a + math.max(0, math.min(p.amount or 0, p.cap))
      c = c + p.cap
    end
  end
  if c <= 0 then return nil end
  return a / c
end

--- État « bas » après une lecture (hystérésis). prev : état précédent ; ratio nil (rien lu) : faux, garde fermée.
function Vt.low(prev, ratio)
  if type(ratio) ~= "number" then return false end
  if prev then return ratio < Vt.LOW_OUT end
  return ratio < Vt.LOW_IN
end

--- Seuil de confort du coffre : en dessous, un tampon bas déclenche le remplissage.
function Vt.comfort(target)
  return math.floor((target or 0) * Vt.COMFORT)
end

return Vt
