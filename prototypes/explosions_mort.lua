-- Lot X10, Q5 et Q5b (7/11) : explosions de mort des unités, des vers (Q5) et des bâtiments (Q5b) recréées par script
-- près d'un joueur seulement (règle pure : shared/explosions_mort/regles.lua). Au data-final-fixes, chaque prototype de
-- n'importe quel type retenu par M.lot (unités et vers ; bâtiments « player-creation » hors des types exclus ; jamais nos
-- tourelles), tous créés avant cette étape, dont l'explosion de mort a une forme sûre perd son `dying_explosion` au profit
-- d'un effet `script` de `dying_trigger_effect` ; le jeu (script/world/explosions_mort.lua) ne recrée l'explosion que près
-- d'un joueur connecté. Types et noms triés : l'ordre de pairs ne compte pas.
local M = require("shared.explosions_mort.regles")

local habilles, laisses = 0, {}
local explosions = {} -- [nom] = true : explosions recréées par script
local par_lot, par_type = { q5 = 0, q5b = 0 }, {} -- comptes pour le journal
local types = {}
for t in pairs(data.raw) do types[#types + 1] = t end
table.sort(types)
for _, t in ipairs(types) do
  local names = {}
  for name in pairs(data.raw[t] or {}) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local p = data.raw[t][name]
    local lot = p.dying_explosion ~= nil and M.lot(t, p)
    if lot then
      local noms = M.habiller(p)
      if noms then
        habilles = habilles + 1
        par_lot[lot] = par_lot[lot] + 1
        if lot == "q5b" then par_type[t] = (par_type[t] or 0) + 1 end
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
local pt = {}
for _, t in ipairs(types) do if par_type[t] then pt[#pt + 1] = t .. " " .. par_type[t] end end
log(string.format("[FO-EXPLOSIONS-MORT] Q5 (unites, vers) : %d ; Q5b (batiments) : %d, par type : %s", par_lot.q5, par_lot.q5b,
  table.concat(pt, ", ")))
log(string.format("[FO-EXPLOSIONS-MORT] explosions de mort habillees par script : %d prototype(s) ; laisse(s) au moteur : %d%s ; "
  .. "%d explosion(s) (%s), dont %d mise(s) hors grille ; hors data.raw.explosion : %d%s",
  habilles, #laisses, #laisses > 0 and (" (" .. table.concat(laisses, ", ") .. ")") or "", #xn, table.concat(xn, ", "), ajoutes, #absentes,
  #absentes > 0 and (" (" .. table.concat(absentes, ", ") .. ")") or ""))
