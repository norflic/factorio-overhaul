-- Étape data-final-fixes : tout ce qui dépend de la liste COMPLÈTE des recettes.

local M = require("shared.content.modules")

-- Recettes intermédiaires du mod éligibles à la productivité.
-- RÈGLE : jamais une recette réversible (compaction/décompaction...) : productivité + boucle = matière infinie.
local FO_PRODUCTIVITY_RECIPES = { "fo-tungsten-plate" }
-- Lot X1-TITANE : les recettes de la chaîne du titane que le scénario X0 marque « prod » (refusion de la plaque,
-- cokéfaction) ; aucune n'est réversible.
do
  local T = require("shared.content.titanium")
  for _, rr in ipairs(T.RECIPES) do
    if T.process_recipe(rr.name).prod then FO_PRODUCTIVITY_RECIPES[#FO_PRODUCTIVITY_RECIPES + 1] = rr.name end
  end
end
-- Lot X2 : celles de la chaîne de la bobine que X0 marque « prod » (ruban, aimant, cryostat, bobine) ; aucune réversible.
do
  local S = require("shared.content.superconductors")
  for _, rr in ipairs(S.RECIPES) do
    if S.process_recipe(rr.name).prod then FO_PRODUCTIVITY_RECIPES[#FO_PRODUCTIVITY_RECIPES + 1] = rr.name end
  end
end
-- Lot AMELIO-RESSOURCES : celles du plomb et du thorium que X0 marque « prod » (plomb, blindage plombé) ; aucune réversible.
do
  local P = require("shared.content.galena")
  for _, rr in ipairs(P.RECIPES) do
    if P.process_recipe(rr.name).prod then FO_PRODUCTIVITY_RECIPES[#FO_PRODUCTIVITY_RECIPES + 1] = rr.name end
  end
end
-- Piste BAUXITE : celles de l'aluminium que X3 marque « prod » (électrolyse ignée) ; aucune réversible.
do
  local B = require("shared.content.bauxite")
  for _, rr in ipairs(B.RECIPES) do
    if B.recipe(rr.name).prod then FO_PRODUCTIVITY_RECIPES[#FO_PRODUCTIVITY_RECIPES + 1] = rr.name end
  end
end

local base = data.raw.module["productivity-module-3"]
local limitation = table.deepcopy(base and base.limitation or {})
local present = {}
for _, r in ipairs(limitation) do present[r] = true end
for _, r in ipairs(FO_PRODUCTIVITY_RECIPES) do
  if data.raw.recipe[r] and not present[r] then
    limitation[#limitation + 1] = r
    present[r] = true
  end
end

for k = 1, M.TIERS do
  local module = data.raw.module[M.name("productivity", k)]
  if module then
    module.limitation = table.deepcopy(limitation)
    module.limitation_message_key = "production"
  end
end

-- Les tourelles du mod héritent des bonus de recherche de leur modèle vanilla (« turret-attack » est
-- attaché à un nom de tourelle). Moteur réel (session 3, banc de contenu) : sans cela, la tourelle lourde,
-- privée des +200 % des recherches de dégâts, tuait deux fois moins vite que la mitrailleuse de base.
local A = require("shared.content.arsenal")
local Lv = require("shared.levels.config")
local inherits = {}
for _, t in ipairs(A.turrets) do
  inherits[t.copy] = inherits[t.copy] or {}
  table.insert(inherits[t.copy], t.name)
end
-- Niveaux 2 à 30 des tourelles (session 5 ; 30 niveaux depuis le lot V2) : mêmes bonus que leur niveau 1.
for _, f in ipairs(Lv.families) do
  if f.type == "ammo-turret" or f.type == "electric-turret" then
    for n = 2, f.max do
      inherits[f.base] = inherits[f.base] or {}
      table.insert(inherits[f.base], Lv.name(f, n))
    end
  end
end
for _, tech in pairs(data.raw.technology) do
  local effects = tech.effects
  if effects then
    local extra = {}
    for _, eff in ipairs(effects) do
      if eff.type == "turret-attack" and inherits[eff.turret_id] then
        for _, name in ipairs(inherits[eff.turret_id]) do
          if data.raw["ammo-turret"][name] or data.raw["electric-turret"][name] or data.raw["fluid-turret"][name] then
            extra[#extra + 1] = { type = "turret-attack", turret_id = name, modifier = eff.modifier }
          end
        end
      end
    end
    for _, e in ipairs(extra) do effects[#effects + 1] = e end
  end
end

-- Lot V2c, QX9 (« alléger la recherche vanilla des premières époques ») : le nombre d'unités de chaque
-- technologie vanilla est multiplié par X.VANILLA_UNIT_SCALE de son époque (règle du lot X0 :
-- shared/levels/config.lua, L.vanilla_unit_count). Les technologies du mod (« fo- ») et les recherches
-- infinies ne changent pas. Noms triés : l'ordre de pairs ne compte pas.
local tech_names = {}
for name in pairs(data.raw.technology) do tech_names[#tech_names + 1] = name end
table.sort(tech_names)
local scaled = 0
for _, name in ipairs(tech_names) do
  local tech = data.raw.technology[name]
  local changed = false
  for _, holder in ipairs({ tech, tech.normal or false, tech.expensive or false }) do
    local unit = holder and holder.unit
    if unit and unit.count then
      local count = Lv.vanilla_unit_count({ name = name, effects = holder.effects or tech.effects, unit = unit,
        max_level = holder.max_level or tech.max_level }, unit.count)
      if count and count ~= unit.count then
        unit.count = count
        changed = true
      end
    end
  end
  if changed then scaled = scaled + 1 end
end
log("[FO-LEVELS] recherche vanilla allégée (QX9) : " .. scaled .. " technologie(s)")

-- Lot MOD-2 (D-15, Q-M2 a) : recettes par lots × 10 et × 100 au-delà de 60 fabrications par seconde. EN DERNIER :
-- la liste des recettes doit être complète, et les limitations de productivité posées plus haut sont étendues aux lots.
-- Aucune technologie n'est touchée (le calcul des époques ci-dessus lit leurs effets) : le script active les lots.
require("prototypes.lots")
