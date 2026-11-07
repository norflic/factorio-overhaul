-- Lot X10, Q5 (7/11) : explosions de mort des unités et des vers recréées par script près d'un joueur seulement (règle
-- pure : shared/explosions_mort/regles.lua). Au data-final-fixes, chaque prototype retenu par M.cible (les unités et les
-- vers, vanilla et du mod, tous créés avant cette étape ; pas nos tourelles) dont l'explosion de mort a une forme sûre
-- perd son `dying_explosion` au profit d'un
-- effet `script` de `dying_trigger_effect` ; le jeu (script/world/explosions_mort.lua) ne recrée l'explosion que près d'un
-- joueur connecté. Noms triés : l'ordre de pairs ne compte pas.
local M = require("shared.explosions_mort.regles")

local habilles, laisses = 0, {}
local explosions = {} -- [nom] = true : explosions recréées par script
for _, t in ipairs(M.TYPES) do
  local names = {}
  for name in pairs(data.raw[t] or {}) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local p = data.raw[t][name]
    if p.dying_explosion ~= nil and M.cible(t, p) then
      local noms = M.habiller(p)
      if noms then
        habilles = habilles + 1
        for _, n in ipairs(noms) do explosions[n] = true end
      else
        laisses[#laisses + 1] = t .. "/" .. name
      end
    end
  end
end
-- Les explosions recréées par script sont posées hors de la grille, comme le moteur les pose (identité C8 : même point).
local xn, ajoutes, absentes = {}, 0, {}
for n in pairs(explosions) do xn[#xn + 1] = n end
table.sort(xn)
for _, n in ipairs(xn) do
  local x = data.raw.explosion[n]
  if x then
    if M.hors_grille(x) then ajoutes = ajoutes + 1 end
  else
    absentes[#absentes + 1] = n
  end
end
log(string.format("[FO-EXPLOSIONS-MORT] explosions de mort habillees par script : %d prototype(s) ; laisse(s) au moteur : %d%s ; "
  .. "%d explosion(s) (%s), dont %d mise(s) hors grille ; hors data.raw.explosion : %d%s",
  habilles, #laisses, #laisses > 0 and (" (" .. table.concat(laisses, ", ") .. ")") or "", #xn, table.concat(xn, ", "), ajoutes, #absentes,
  #absentes > 0 and (" (" .. table.concat(absentes, ", ") .. ")") or ""))
