-- Étape data-final-fixes : tout ce qui dépend de la liste COMPLÈTE des recettes.

local M = require("shared.content.modules")

-- Recettes intermédiaires du mod éligibles à la productivité.
-- RÈGLE : jamais une recette réversible (compaction/décompaction...) : productivité + boucle = matière infinie.
local FO_PRODUCTIVITY_RECIPES = { "fo-tungsten-plate" }

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
-- Niveaux 2-10 des tourelles (session 5) : mêmes bonus que leur niveau 1.
for _, f in ipairs(Lv.families) do
  if f.type == "ammo-turret" or f.type == "electric-turret" then
    for n = 2, Lv.MAX do
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
