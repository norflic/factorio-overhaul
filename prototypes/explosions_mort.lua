-- Lot X10, Q5 (7/11) : explosions de mort des unités recréées par script près d'un joueur seulement (règle pure :
-- shared/explosions_mort/regles.lua). Au data-final-fixes, chaque prototype des types M.TYPES (les unités, vanilla et du
-- mod, toutes créées avant cette étape) dont l'explosion de mort a une forme sûre perd son `dying_explosion` au profit d'un
-- effet `script` de `dying_trigger_effect` ; le jeu (script/world/explosions_mort.lua) ne recrée l'explosion que près d'un
-- joueur connecté. Noms triés : l'ordre de pairs ne compte pas.
local M = require("shared.explosions_mort.regles")

local habilles, laisses = 0, {}
for _, t in ipairs(M.TYPES) do
  local names = {}
  for name in pairs(data.raw[t] or {}) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local p = data.raw[t][name]
    if p.dying_explosion ~= nil then
      if M.habiller(p) then habilles = habilles + 1 else laisses[#laisses + 1] = t .. "/" .. name end
    end
  end
end
log(string.format("[FO-EXPLOSIONS-MORT] explosions de mort habillees par script : %d prototype(s) ; laisse(s) au moteur : %d%s",
  habilles, #laisses, #laisses > 0 and (" (" .. table.concat(laisses, ", ") .. ")") or ""))
