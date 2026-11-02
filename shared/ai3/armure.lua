--[[
  Lot TENUE (2/11) : la défense compte les dégâts RÉELLEMENT infligés, pas les dégâts nominaux. PUR (aucune API Factorio, aucun nom
  d'objet : l'appelant, script/ai3/prevision.lua, passe des nombres lus aux prototypes), testé hors jeu par tests/tenue_test.lua.

  Constat (fo-logs/2026-11-01_C4/longue2, Émeraude, 0.6.34, graine 20261020) : la valeur d'une tourelle ou d'un soldat de la prévision
  (shared/ai3/prevision.lua, Pv.turrets_value, Pv.soldier_value) était un débit de dégâts NOMINAL × un temps, sans la résistance des
  unités ennemies (Pv.ARENA = 1000, « à mesurer », jamais mesuré). Or le biter moyen (-4 plats, 10 %), le gros (-8, 10 %) et le béhémoth
  (-12, 10 %) encaissent mal un petit coup : un tir de 5 contre un gros biter ne fait pas 5. À mesure que l'évolution monte, le mélange des
  vagues passe des petits biters (aucune résistance) aux moyens puis aux gros : la défense « 10 700 PV » du QG (16 tourelles, 313 chargeurs)
  a tué 1 250 PV d'une vague de 9 270 PV à 195 min ; le péril, « préparer » et la levée de soldats se décidaient sur ce nominal.

  Règle : un coup de `d` contre une unité de résistance (plat, pct) inflige Ar.hit(d, plat, pct) (formule du MOTEUR, mesurée en moteur réel
  par le scénario tenue-armure : tests/fixtures/tenue_armure.lua). Contre un mélange d'unités (poids w, PV hp), les PV neutralisés par
  seconde valent ceux d'un adversaire sans résistance × Ar.factor = Σ w·hp / Σ (w·hp / r), r = dégâts réels ÷ dégâts nominaux de chaque
  unité (le temps pour tuer une unité est hp / (cadence × coup réel), le rapport se fait donc en harmonique pondérée par les PV).
  Les résistances et le mélange viennent des prototypes (aucune table par âge, aucun nom) ; le coup tient compte des bonus de la force.

  Déterminisme : entiers en pour-mille, aucun hasard, aucun temps mesuré.
]]

local Ar = {}

Ar.ONE = 1000   -- ‰ : aucune résistance
Ar.FLOOR = 10   -- ‰ : une unité n'est jamais comptée invulnérable (plancher du facteur par unité)

local function num(x)
  if type(x) ~= "number" or x ~= x then return 0 end
  return x
end

--- Dégâts appliqués d'un coup de `d` à une unité de résistance (`flat` : réduction plate, `pct` : fraction 0..1). Formule du moteur :
--- si le coup dépasse la réduction plate, il perd `flat`, sinon il tombe à 1 / (flat - d + 2) ; puis il perd `pct`.
function Ar.hit(d, flat, pct)
  d, flat, pct = num(d), num(flat), num(pct)
  if d <= 0 then return 0 end
  if flat < 0 then flat = 0 end
  if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
  local after
  if d > flat then after = d - flat else after = 1 / (flat - d + 2) end
  return after * (1 - pct)
end

--- Facteur (‰, 0..1000) de l'efficacité d'un coup de `hit` dégâts de type `dtype` contre le mélange `units` = { { w (poids), hp, res =
--- { [type] = { plat, pct } } | nil } } (Pv.mix, champ `units`). 1000 sans mélange, sans coup ou sans résistance.
function Ar.factor(units, hit, dtype)
  hit = num(hit)
  if hit <= 0 or not units then return Ar.ONE end
  local nominal, real = 0, 0
  for _, u in ipairs(units) do
    local w = num(u.w) * math.max(0, num(u.hp))
    if w > 0 then
      local r = u.res and dtype and u.res[dtype]
      local ratio = 1
      if r then ratio = Ar.hit(hit, r[1], r[2]) / hit end
      if ratio < Ar.FLOOR / 1000 then ratio = Ar.FLOOR / 1000 end
      nominal = nominal + w
      real = real + w / ratio
    end
  end
  if nominal <= 0 or real <= 0 then return Ar.ONE end
  local f = math.floor(Ar.ONE * nominal / real)
  if f > Ar.ONE then f = Ar.ONE end
  return f
end

--- Applique le facteur (‰) à un débit de dégâts.
function Ar.scale(dps, factor)
  return num(dps) * math.max(0, math.min(Ar.ONE, num(factor))) / Ar.ONE
end

return Ar
