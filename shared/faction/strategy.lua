--[[
  Stratégie MILITAIRE d'une faction — PURE (aucune API Factorio).

  Session 4 : l'économie est réelle (shared/team/planner.lua décide de ce qui se construit, se fabrique et
  s'équipe, avec les objets du stock). Il reste ici la décision d'ATTAQUE, testable hors-jeu.

  Leçons de la simulation v1 (RD_LOG E4), toujours valables : logique de campagne (on accumule puis on
  frappe fort), attaque seulement avec un avantage estimé (loi de Lanchester).

  Lot IA0 (PvP, OBJECTIFS.md C4) : S.decide(view) -> actions. Le joueur devient une cible comme une
  faction rivale, selon le niveau de difficulté (shared/faction/config.lua, F.pvp) : délai de grâce,
  déclaration de guerre, intervalle entre deux attaques, part des forces, taille des attaques.

  view = {
    personality, tech, upgrades, garrison, soldiers_max, can_attack,
    enemy_defense,          -- défense estimée de la faction rivale visée (math.huge si aucune)
    rival = { id, outposts } | nil,          -- cible faction (coalition contre le leader, sinon voisin)
    own_outposts, leader_outposts,           -- territoire de la faction, plus grand territoire rival
    pvp = {
      difficulty, tick, anchor,              -- la grâce court depuis `anchor`
      grace_floor,                           -- fin de grâce au plus tôt (préavis garanti), ou nil
      declared, provoked, warned,            -- état diplomatique de la faction envers le joueur
      last_attack,                           -- tick de la dernière attaque lancée contre le joueur (ou nil)
      sent_player, sent_total,               -- soldats envoyés depuis la déclaration (joueur, toutes cibles)
      player_groups,                         -- groupes en route contre le joueur
    } | nil,
    player = { score, defense, reachable } | nil,  -- cible joueur repérée (secteurs, défense locale)
  }
  actions = {
    warn = minutes | nil, declare = "grace" | "provoked" | nil, truce = bool | nil, recall = bool | nil,
    attack = { target = "player" | id_faction, count = n } | nil,
  }
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

local function personality(v)
  return F.personalities[v.personality] or F.personalities.balanced
end

--- Décision d'attaque : renvoie l'effectif à envoyer, ou nil.
function S.attack(v)
  local P = personality(v)
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

---------------------------------------------------------------------------------------------------
-- PvP (lot IA0)
---------------------------------------------------------------------------------------------------
function S.pvp_params(level)
  return F.pvp_params(level)
end

--- Délai de grâce (ticks) d'une personnalité à un niveau : grace_min / agressivité. nil si « Paisible ».
function S.grace_ticks(level, pers)
  local d = F.pvp_params(level)
  if not d.aggressive then return nil end
  local P = F.personalities[pers] or F.personalities.balanced
  return math.floor(d.grace_min * 3600 / P.aggression)
end

--- Fin de la grâce (tick) : ancre + grâce, mais jamais avant `grace_floor` (préavis garanti après un
--- changement de niveau en cours de partie). nil si « Paisible ».
function S.grace_end(anchor, grace_floor, level, pers)
  local g = S.grace_ticks(level, pers)
  if not g then return nil end
  local t = (anchor or 0) + g
  if grace_floor and grace_floor > t then t = grace_floor end
  return t
end

function S.cooldown_ticks(level)
  return math.floor(F.pvp_params(level).cooldown_min * 3600)
end

--- Garnison gardée quand l'attaque vise le joueur.
function S.player_keep(level, pers)
  local P = F.personalities[pers] or F.personalities.balanced
  local k = P.keep * F.pvp_params(level).keep_mult
  if k > F.pvp_rules.max_keep then k = F.pvp_rules.max_keep end
  return k
end

local function base_size(pers)
  local P = F.personalities[pers] or F.personalities.balanced
  return math.floor(F.military.attack_base / P.aggression)
end

--- Taille minimale d'une attaque contre le joueur (en dessous, aucune attaque).
function S.player_min_size(level, pers)
  local m = math.floor(base_size(pers) * F.pvp_params(level).min_mult)
  if m < F.pvp_rules.min_attack then m = F.pvp_rules.min_attack end
  return m
end

--- Taille visée des attaques contre le joueur qui suivent la première.
function S.player_goal(level, pers)
  local g = math.floor(base_size(pers) * F.pvp_params(level).size_mult)
  local m = S.player_min_size(level, pers)
  return g > m and g or m
end

--- Effectif envoyé contre le joueur pour une garnison donnée (sans condition de force).
function S.player_count(level, pers, garrison)
  return math.floor(garrison * (1 - S.player_keep(level, pers)))
end

--- Effectif minimal pour attaquer le joueur : taille minimale du niveau, et force ≥ 1,3 × défense
--- estimée (même règle que contre une faction).
function S.player_need(v, level)
  local strength = S.soldier_strength(F.best_soldier(v.tech), v.tech, v.upgrades)
  local need = S.player_min_size(level, v.personality)
  local by_defense = math.ceil((v.player and v.player.defense or 0) * 1.3 / strength - 1e-9)
  if by_defense > need then need = by_defense end
  return need
end

--- Décision quand le joueur est « dû » : "attack" (effectif), "save" (la faction garde ses soldats pour
--- lui) ou "fallback" (elle se rabat sur sa rivale). Campagne : on accumule, puis on frappe.
---   - première attaque après la déclaration : dès que l'effectif atteint le minimum ;
---   - suivantes : dès qu'il atteint la taille visée, ou, après save_min minutes d'attente, le minimum ;
---   - minimum toujours hors d'atteinte après save_min minutes (joueur trop défendu, armée trop petite) :
---     repli sur la rivale, et l'attaque contre le joueur part dès que le minimum est atteint.
function S.player_plan(v, level, due_since)
  local pv = v.pvp
  if due_since == nil then due_since = pv.due_since end
  local count = S.player_count(level, v.personality, v.garrison)
  local need = S.player_need(v, level)
  local goal = need
  if (pv.sent_player or 0) > 0 then
    local g = S.player_goal(level, v.personality)
    if g > goal then goal = g end
  end
  local waited = due_since and (pv.tick - due_since) or 0
  local patience = math.floor(F.pvp_params(level).save_min * 3600)
  if count >= goal or (count >= need and waited >= patience) then return "attack", count end
  if waited < patience then return "save", count end
  return "fallback", count
end


--- Territoire du joueur en « équivalents avant-postes » (unité commune avec les factions) : secteurs
--- repérés / sectors_per_outpost.
function S.player_territory(v)
  local p = v.player
  if not p then return 0 end
  return (p.score or 0) / F.pvp_rules.sectors_per_outpost
end

--- Le joueur est-il le leader (territoire nettement supérieur, même règle que la coalition entre
--- factions : F.pick_target) ?
function S.player_is_leader(v)
  if not v.player then return false end
  local t = S.player_territory(v)
  return t > math.max(2, (v.own_outposts or 0) * 1.3) and t > (v.leader_outposts or 0)
end

--- Part visée des forces contre le joueur. Coalition : s + leader_bonus × (1 - s) quand il est le leader
--- (ordre strict des niveaux conservé, part laissée aux rivales).
function S.player_share(v, level)
  local s = F.pvp_params(level).share
  if S.player_is_leader(v) then s = s + F.pvp_rules.leader_bonus * (1 - s) end
  return s
end

--- Décision complète d'une pensée de commandant : diplomatie envers le joueur, puis cible et effectif.
function S.decide(v)
  local out = {}
  local pv = v.pvp
  local level = pv and pv.difficulty or "peaceful"
  local d = F.pvp_params(level)
  local declared = pv and pv.declared or false

  -- 1. Diplomatie
  if pv then
    if not d.aggressive then
      -- « Paisible » : une faction qui avait déclaré la guerre à cause de la difficulté rétablit le
      -- cessez-le-feu ; une faction provoquée par le joueur reste hostile (comportement d'avant IA0).
      -- Aucune attaque délibérée contre le joueur : les groupes en route sont rappelés.
      if declared and not pv.provoked then
        out.truce = true
        declared = false
      end
      if (pv.player_groups or 0) > 0 then out.recall = true end
    elseif not declared then
      local grace_end = S.grace_end(pv.anchor, pv.grace_floor, level, v.personality)
      if pv.provoked then
        out.declare, declared = "provoked", true
      elseif pv.tick >= grace_end then
        out.declare, declared = "grace", true
      elseif not pv.warned and pv.tick >= grace_end - F.pvp_rules.warn_ticks then
        out.warn = math.ceil((grace_end - pv.tick) / 3600)
      end
    end
  end

  -- 2. Cible : le joueur quand il est « dû » (règle du déficit : soldats envoyés contre lui ≤ part
  --    visée × soldats envoyés depuis la déclaration), sinon la faction rivale.
  local player_ok = pv and d.aggressive and declared and v.player and v.player.reachable
    and (v.player.score or 0) > 0
    and (pv.last_attack == nil or pv.tick - pv.last_attack >= S.cooldown_ticks(level))
  local due = player_ok
    and ((v.rival == nil) or (pv.sent_player or 0) <= S.player_share(v, level) * (pv.sent_total or 0))
  if pv then
    if due and pv.due_since == nil then out.due_since = pv.tick end
    if not due and pv.due_since ~= nil then out.due_since = false end
  end
  if due then
    local plan, n = S.player_plan(v, level, pv.due_since or out.due_since)
    out.plan = plan
    if plan == "attack" then
      if v.can_attack ~= false then out.attack = { target = "player", count = n } end
      return out
    elseif plan == "save" then
      return out -- la faction garde ses soldats pour le joueur
    end
    -- "fallback" : joueur hors d'atteinte pour l'instant, la faction se rabat sur sa rivale.
  end
  if v.rival then
    local n = S.attack(v)
    if n then out.attack = { target = v.rival.id, count = n } end
  end
  return out
end

return S
