--[[
  Stratégie MILITAIRE d'une faction — PURE (aucune API Factorio).

  Session 4 : l'économie est réelle (shared/team/planner.lua décide de ce qui se construit, se fabrique et
  s'équipe, avec les objets du stock). Il reste ici la décision d'ATTAQUE, testable hors-jeu.

  Leçons de la simulation v1 (RD_LOG E4), toujours valables : logique de campagne (on accumule puis on
  frappe fort), attaque seulement avec un avantage estimé (loi de Lanchester).

  Lot IA0 (PvP, OBJECTIFS.md C4) : S.decide(view) -> actions. Le joueur devient une cible comme une
  faction rivale, selon le niveau de difficulté (shared/faction/config.lua, F.pvp) : délai de grâce,
  déclaration de guerre, intervalle entre deux attaques, part des forces, taille des attaques.

  Lot IA0b (base défendue) : rapport de force exigé par niveau et par personnalité (S.player_ratio), SIÈGE
  (la faction garde ses soldats pour le joueur au plus siege_min minutes, dans la limite d'un plafond, sinon
  elle est dissuadée), plancher des attaques suivantes (S.player_floor), ASSAUT COORDONNÉ en Difficile et
  Impitoyable (fenêtre ouverte par une attaque prête, jointe à join_frac × besoin), et tailles minimales
  plafonnées par ce que l'armée visée peut envoyer (S.player_min_size, S.attack).

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
      due_since,                             -- tick depuis lequel le joueur est « dû » (attente, siège), ou nil
      rally_until,                           -- fin de la fenêtre d'assaut coordonné en cours (IA0b), ou nil
    } | nil,
    player = { score, defense, reachable } | nil,  -- cible joueur repérée (secteurs, défense locale)
  }
  actions = {
    warn = minutes | nil, declare = "grace" | "provoked" | nil, truce = bool | nil, recall = bool | nil,
    attack = { target = "player" | id_faction, count = n, join = true | nil } | nil,
    due_since = tick | false | nil,          -- début (tick) ou fin (false) de l'attente pour le joueur
    plan = "attack" | "save" | "join" | "siege" | "deterred" | "fallback" | nil, need = n, count = n,
    rally = true | nil,                      -- l'attaque ouvre une fenêtre d'assaut coordonné (IA0b)
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
  -- Lot IA0b : jamais plus de rival_min_cap × ce que l'armée visée entière peut envoyer (au moins
  -- min_attack). Sans ce plafond, le bâtisseur (28 > 24 envoyables : armée visée 40, garnison gardée 40 %)
  -- n'attaquait JAMAIS (moteur réel E21 : Émeraude, 0 attaque en 60 min). Avec soldiers_max = 100 (défaut),
  -- seul le bâtisseur est concerné (28 ramené à 21) ; avec une armée maximale plus petite (/fo-war start
  -- ... 60), le technocrate et l'équilibré peuvent l'être aussi.
  if v.soldiers_max then
    local c = math.floor(F.military.rival_min_cap * math.floor(S.army_target(v.personality, v.soldiers_max) * (1 - P.keep)) + 1e-9)
    if c < F.pvp_rules.min_attack then c = F.pvp_rules.min_attack end
    if c < min_size then min_size = c end
  end
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

--- Effectif envoyé contre le joueur pour une garnison donnée (sans condition de force).
function S.player_count(level, pers, garrison)
  return math.floor(garrison * (1 - S.player_keep(level, pers)))
end

--- Armée visée d'une personnalité : même règle que le planificateur (shared/team/planner.lua,
--- P.army_target : T.army_share × soldiers_max).
function S.army_target(pers, soldiers_max)
  return math.floor((soldiers_max or F.defaults.soldiers_max) * (T.army_share[pers] or 0.6))
end

--- Taille minimale d'une attaque contre le joueur (en dessous, aucune attaque). Avec `soldiers_max` (lot
--- IA0b) : jamais plus de min_cap × ce que l'armée visée entière peut envoyer. Sans ce plafond, le
--- bâtisseur (taille 28, armée visée 40, garnison gardée 40 % : 24 envoyables au plus) n'attaquait JAMAIS
--- le joueur en Normal, même sans défense.
function S.player_min_size(level, pers, soldiers_max)
  local m = math.floor(base_size(pers) * F.pvp_params(level).min_mult)
  if soldiers_max then
    local c = math.floor(F.pvp_rules.min_cap * S.player_count(level, pers, S.army_target(pers, soldiers_max)) + 1e-9)
    if c < m then m = c end
  end
  if m < F.pvp_rules.min_attack then m = F.pvp_rules.min_attack end
  return m
end

--- Taille visée des attaques contre le joueur qui suivent la première.
function S.player_goal(level, pers, soldiers_max)
  local g = math.floor(base_size(pers) * F.pvp_params(level).size_mult)
  local m = S.player_min_size(level, pers, soldiers_max)
  return g > m and g or m
end

--- Rapport de force exigé contre le joueur (lot IA0b) : celui du niveau × la prudence de la personnalité.
function S.player_ratio(level, pers)
  local P = F.personalities[pers] or F.personalities.balanced
  return F.pvp_params(level).force_ratio * (P.caution or 1)
end

--- Soldats (du meilleur type débloqué) dont la force vaut `ratio` × la défense estimée du joueur.
local function defense_units(v, ratio)
  local strength = S.soldier_strength(F.best_soldier(v.tech), v.tech, v.upgrades)
  return math.ceil((v.player and v.player.defense or 0) * ratio / strength - 1e-9)
end

--- Effectif minimal pour attaquer le joueur : taille minimale du niveau, et force ≥ rapport exigé
--- (S.player_ratio) × défense estimée. Avant IA0b : 1,3 à tous les niveaux (règle entre factions).
function S.player_need(v, level)
  local need = S.player_min_size(level, v.personality, v.soldiers_max)
  local by_defense = defense_units(v, S.player_ratio(level, v.personality))
  if by_defense > need then need = by_defense end
  return need
end

--- Taille visée des attaques qui suivent la première : la taille de base du niveau (S.player_goal), et,
--- face à une défense, size_mult × prudence × défense (lot IA0b : des attaques plus grandes aux niveaux
--- élevés, même quand la défense fixe la taille).
function S.player_target_size(v, level)
  local P = F.personalities[v.personality] or F.personalities.balanced
  local g = S.player_goal(level, v.personality, v.soldiers_max)
  local by_defense = defense_units(v, F.pvp_params(level).size_mult * (P.caution or 1))
  if by_defense > g then g = by_defense end
  return g
end

--- Plancher des attaques qui suivent la première (lot IA0b) : après save_min minutes d'attente, la faction
--- attaque dès goal_floor × taille visée (au moins le besoin), plafonné à floor_cap × ce que l'armée visée
--- entière peut envoyer. Avant IA0b, le plancher était le besoin : face à une défense, les niveaux élevés
--- (plus téméraires, besoin plus petit) frappaient alors avec MOINS de soldats que Normal.
function S.player_floor(v, level, need, goal)
  local fl = math.ceil(goal * F.pvp_rules.goal_floor - 1e-9)
  local cap = math.floor(F.pvp_rules.floor_cap * S.player_count(level, v.personality, S.army_target(v.personality, v.soldiers_max)) + 1e-9)
  if fl > cap then fl = cap end
  if fl < need then fl = need end
  return fl
end

--- Garnison minimale pour envoyer n soldats contre le joueur (garnison gardée déduite).
function S.player_garrison_for(level, pers, n)
  local k = 1 - S.player_keep(level, pers)
  if k <= 0 then return math.huge end
  local g = math.max(0, math.ceil(n / k - 1e-9) - 1)
  while math.floor(g * k + 1e-9) < n do g = g + 1 end
  return g
end

--- Plafond du siège (lot IA0b) : garnison que la faction accepte de réunir contre le joueur, part siege_cap
--- de l'armée visée de sa personnalité (même règle que le planificateur : T.army_share × soldiers_max).
function S.siege_cap(level, pers, soldiers_max)
  return math.floor(S.army_target(pers, soldiers_max) * F.pvp_params(level).siege_cap + 1e-9)
end

--- Fenêtre d'assaut coordonné ouverte (Difficile, Impitoyable) ?
function S.rally_open(v, level)
  local pv = v.pvp
  return (F.pvp_params(level).rally_min or 0) > 0 and pv ~= nil and pv.rally_until ~= nil and pv.tick < pv.rally_until
end

--- Effectif suffisant pour se joindre à un assaut coordonné : join_frac × besoin (au moins min_attack). Le
--- défenseur est occupé par l'attaque qui a ouvert la fenêtre : un groupe plus petit est accepté.
function S.join_need(v, level, need)
  local j = math.ceil(need * F.pvp_params(level).join_frac - 1e-9)
  if j < F.pvp_rules.min_attack then j = F.pvp_rules.min_attack end
  return j
end

function S.rally_ticks(level)
  return math.floor((F.pvp_params(level).rally_min or 0) * 3600)
end

--- Décision quand le joueur est « dû ». Campagne : on accumule, puis on frappe.
---   "attack"   : effectif ≥ taille visée ; ou ≥ plancher (S.player_floor) après save_min minutes
---                d'attente ; ou ≥ besoin une fois siege_min écoulé (la première attaque après la
---                déclaration part dès le besoin : taille visée = besoin) ;
---   "save"     : besoin atteint, la faction attend encore la taille visée (au plus save_min) ;
---   "join"     : besoin non atteint, mais un assaut coordonné est ouvert et l'effectif atteint
---                join_frac × besoin (Difficile, Impitoyable) ;
---   "deterred" : la garnison nécessaire dépasse le plafond du siège : repli sur la rivale (dissuasion) ;
---   "siege"    : la faction garde ses soldats pour le joueur, au plus siege_min minutes (lot IA0b) ;
---   "fallback" : siège expiré : répit, repli sur la rivale ; la prochaine attaque contre elle clôt le répit
---                et un nouveau siège commence (S.decide efface due_since).
--- Renvoie plan, effectif, besoin.
function S.player_plan(v, level, due_since)
  local pv = v.pvp
  local d = F.pvp_params(level)
  if due_since == nil then due_since = pv.due_since end
  local count = S.player_count(level, v.personality, v.garrison)
  local need = S.player_need(v, level)
  local goal = need
  if (pv.sent_player or 0) > 0 then
    local g = S.player_target_size(v, level)
    if g > goal then goal = g end
  end
  local waited = due_since and (pv.tick - due_since) or 0
  local patience = math.floor(d.save_min * 3600)
  local floor_n = S.player_floor(v, level, need, goal)
  if count >= goal or (count >= floor_n and waited >= patience) then return "attack", count, need end
  -- Siège écoulé, besoin atteint mais pas le plancher : on frappe avec ce qu'on a (jamais sous le besoin).
  if count >= need and waited >= math.floor(d.siege_min * 3600) and waited >= patience then return "attack", count, need end
  if count >= need then return "save", count, need end
  if S.rally_open(v, level) and count >= S.join_need(v, level, need) then return "join", count, need end
  if (d.siege_min or 0) <= 0 then return "fallback", count, need end -- Facile : jamais de siège
  if S.player_garrison_for(level, v.personality, need) > S.siege_cap(level, v.personality, v.soldiers_max) then
    return "deterred", count, need
  end
  if waited < math.floor(d.siege_min * 3600) then return "siege", count, need end
  return "fallback", count, need
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
    local plan, n, need = S.player_plan(v, level, pv.due_since or out.due_since)
    out.plan, out.need, out.count = plan, need, n
    if plan == "attack" or plan == "join" then
      if v.can_attack ~= false then
        out.attack = { target = "player", count = n }
        if plan == "join" then
          out.attack.join = true
        elseif S.rally_ticks(level) > 0 then
          out.rally = true -- Difficile, Impitoyable : fenêtre d'assaut coordonné ouverte pour les autres
        end
      end
      return out
    elseif plan == "save" or plan == "siege" then
      return out -- la faction garde ses soldats pour le joueur
    end
    -- "deterred" (dissuasion) ou "fallback" (répit) : la faction se rabat sur sa rivale.
  end
  if v.rival then
    local n = S.attack(v)
    if n then
      out.attack = { target = v.rival.id, count = n }
      -- Fin du répit : l'attaque contre la rivale part, un nouveau siège commencera à la pensée suivante.
      if out.plan == "fallback" then out.due_since = false end
    end
  end
  return out
end

return S
