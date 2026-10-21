--[[
  Stratégie MILITAIRE d'une faction — PURE (aucune API Factorio).

  Session 4 : l'économie est réelle (shared/team/planner.lua décide de ce qui se construit, se fabrique et
  s'équipe, avec les objets du stock). Il reste ici la décision d'ATTAQUE, testable hors-jeu.

  Leçons de la simulation v1 (RD_LOG E4), toujours valables : logique de campagne (on accumule puis on
  frappe fort), attaque seulement avec un avantage estimé (loi de Lanchester).

  view = { personality, tech, upgrades, garrison, soldiers_max, enemy_defense, can_attack }
]]

local F = require("shared.faction.config")
local T = require("shared.team.config")

local S = {}

--- Nombre d'avant-postes visé (affichage, estimation) : croît avec la technologie et l'appétit économique.
function S.desired_outposts(tech, greed)
  return math.floor((3 + 2 * tech) * greed + 0.5)
end

--- Effectif visé par la personnalité.
function S.target_army(soldiers_max, P)
  local f = 0.25 + 0.35 * P.aggression - 0.15 * (P.research - 1)
  if f < 0.2 then f = 0.2 elseif f > 1 then f = 1 end
  return math.floor(soldiers_max * f)
end

--- Force relative d'un soldat par rapport au fusilier (dps × PV).
function S.soldier_strength(key, tech, upgrades)
  local s, r = F.soldiers[key], F.soldiers.rifleman
  return (s.damage / s.cooldown * s.hp) / (r.damage / r.cooldown * r.hp) * 1.1 ^ tech
    * (1 + F.economy.upgrade_damage * (upgrades or 0))
end

--- Décision d'attaque : renvoie l'effectif à envoyer, ou nil.
function S.attack(v)
  local P = F.personalities[v.personality] or F.personalities.balanced
  local unit = F.best_soldier(v.tech)
  local strength = S.soldier_strength(unit, v.tech, v.upgrades)
  local count = math.floor(v.garrison * (1 - P.keep))
  -- Session 4 (économie réelle) : l'armée se paie en objets et grossit moins vite qu'avec l'ancien
  -- registre. Moteur réel (E16 it. 8) : un seuil lié à l'armée maximale (35 % de 100) retardait la
  -- première attaque à 30 min. Seuil = taille d'attaque de la personnalité : conquérant 13, équilibré 20,
  -- technocrate 25, bâtisseur 28 soldats envoyés (garnison gardée en plus).
  local min_size = math.floor(F.military.attack_base / P.aggression)
  local needed = (v.enemy_defense or 0) * 1.3
  if v.can_attack ~= false and count >= min_size and count * strength >= needed then return count end
  return nil
end

return S
