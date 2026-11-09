--[[
  Lot CENTRALE-PRES : une centrale ne se demande qu'avec un poteau OBTENABLE. PUR (aucune API Factorio, aucun nom d'objet écrit :
  le poteau par défaut vient de shared/team/modules.lua), testé hors jeu par tests/centrale_pole_test.lua.

  Défaut mesuré (partie neuve 0.6.70, scénario etape1-guide, journal fo-logs/2026-11-08_INTEG-0670/neuve40-b-a627035e, votre équipe) :
  à 7,7 min [FO-ENERGIE] demande une centrale de 4 chaudières ; la première centrale (1 chaudière) avait le petit poteau (le moins cher
  débloqué, A.choose_pole), mais le gabarit de 4 chaudières avec le petit poteau laisse des machines à vapeur HORS de l'aire des
  poteaux (steam-engine n°8 : la rangée basse du milieu n'a aucune tuile libre à moins de 2,5 tuiles, M.check refuse dès 3 chaudières).
  template_of (script/team/build.lua) cédait alors au poteau par défaut, le MOYEN, dont la recette n'est pas ouverte : le projet 2
  réservait 34 poteaux moyens (ligne de liaison comprise) qu'aucun stock ni aucune fabrication ne pouvait couvrir, restait « reserve
  [materiaux] » 30 min (C.STALE), puis « annule (delai) » : la centrale n'a jamais été construite, 25 min de déficit de courant.

  Règles :
    CP.fit      : la plus grande taille (<= celle demandée) dont le gabarit tient avec un poteau obtenable, et ce poteau ; la taille
                  demandée d'abord, avec chaque poteau obtenable dans l'ordre (préféré, puis défaut : comportement d'avant quand le
                  moyen est ouvert) ; sinon une centrale plus petite (deux chaudières tiennent avec le petit poteau) ; sinon refus
                  immédiat avec sa cause.
    CP.dead     : parmi les objets qui manquent à une réserve, ceux qu'aucune fabrication ne peut plus couvrir (CP.dead), pour refuser
                  tout de suite au lieu de dormir.
]]
local M = require("shared.team.modules")

local CP = {}

--- Poteaux à essayer, dans l'ordre : `pref` (celui que la première centrale a reçu), puis `default`, sans doublon, en ne gardant que
--- ceux que `obtainable(nom)` accepte. `pref` nil : le défaut seul.
function CP.candidates(pref, default, obtainable)
  local out, seen = {}, {}
  for _, name in ipairs({ pref or default, default }) do
    if name and not seen[name] then
      seen[name] = true
      if obtainable(name) then out[#out + 1] = name end
    end
  end
  return out
end

--- Le gabarit `gen` à `n` éléments, joué avec le poteau `pole`, passe-t-il le contrôle du générateur (M.check) ? Vrai/faux.
function CP.valid(gen, pole, n)
  local fn = M.GEN[gen]
  if not fn then return false end
  local ok, g = pcall(M.with_pole, pole, fn, n)
  if not ok or not g then return false end
  return #M.check(g) == 0
end

--- Taille et poteau d'une centrale demandée à `nb` chaudières. poles = candidats obtenables (CP.candidates), valid(pole, n) -> bool.
--- Rend (n, pole, réduite) ou (nil, cause). Pure et déterministe : seules des listes ordonnées sont lues.
function CP.fit(nb, poles, valid)
  if not nb or nb < 1 then return nil, "taille demandee nulle" end
  if #poles == 0 then return nil, "aucun poteau obtenable (ni au stock, ni recette ouverte)" end
  for _, pole in ipairs(poles) do
    if valid(pole, nb) then return nb, pole, false end
  end
  for n = nb - 1, 1, -1 do
    for _, pole in ipairs(poles) do
      if valid(pole, n) then return n, pole, true end
    end
  end
  return nil, "aucun poteau obtenable ne couvre une centrale d'une chaudiere"
end

--- Objets d'une réserve (missing = { { objet, n }, ... }) qu'`obtainable(objet)` refuse : liste triée de noms, vide si tout peut venir.
function CP.dead(missing, obtainable)
  local out = {}
  for _, m in ipairs(missing or {}) do
    if (m[2] or 0) > 0 and not obtainable(m[1]) then out[#out + 1] = m[1] end
  end
  table.sort(out)
  return out
end

return CP
