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
  Impitoyable (fenêtre ouverte par une attaque prête ; une autre faction s'y joint contre la MÊME cible, avec
  au moins join_frac × son besoin et jamais sous la taille minimale du niveau, ou avec son plancher sans
  attendre la fin de save_min), taille minimale contre le joueur plafonnée par ce que l'armée visée peut
  envoyer (S.player_min_size), et fin de l'impasse de la règle du déficit (le joueur redevient « dû » quand
  la faction n'a rien pu lancer, ni contre lui ni contre une faction, depuis rival_wait × l'intervalle entre
  deux attaques). La guerre ENTRE factions (S.attack) est inchangée depuis IA0.

  view = {
    personality, tech, upgrades, garrison, soldiers_max, can_attack,
    character,              -- lot IA2-0 : caractère effectif tiré de la graine (shared/faction/traits.lua), ou nil
    attack_jitter,          -- lot IA2-0 : multiplicateur (pour mille) du seuil de la prochaine attaque ENTRE factions, ou nil
    chef = { war_mult, raid, raid_defense, hold, vain, hold_rival } | nil, -- lot IA2-a (shared/faction/chef.lua) : multiplicateur du seuil (tirage
                            -- refait à chaque pensée × posture), raid demandé (5 à 10) et défense de sa cible ; avec un chef,
                            -- la guerre entre factions varie à tous les niveaux, la réserve du joueur passant avant ; lot ARMEE :
                            -- vain = « echec » | « portee » (attaque sans effet contre la rivale, shared/faction/chef.lua),
                            -- hold_rival = trêve, vague en route ou vain : rivale épargnée À TOUS LES NIVEAUX (hold seul : Paisible)
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
      last_rival,                            -- tick de la dernière attaque lancée contre une faction (IA0b), ou nil
      rally_until,                           -- fin de la fenêtre d'assaut coordonné en cours (IA0b), ou nil
      rally_defense,                         -- défense estimée de la cible de cette fenêtre (cible commune), ou nil
      first_after,                           -- lot IA2-c : moment de la 1re attaque de la partie (tick) : pas avant
      cooldown_mult,                         -- lot IA2-c : tempo de l'intervalle entre deux attaques (pour mille)
    } | nil,
    player = { score, defense, reachable } | nil,  -- cible joueur repérée (lot IA2-c : secteurs VUS, défense vue)
  }
  actions = {
    warn = minutes | nil, declare = "grace" | "provoked" | nil, truce = bool | nil, recall = bool | nil,
    attack = { target = "player" | id_faction, count = n, join = true | nil, rule = "variee" | "ia0" | nil,
               raid = true | nil } | nil,  -- lot IA2-a : règle appliquée (journal), raid du chef
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

--- Caractère d'une vue (lot IA2-0) : le caractère effectif tiré de la graine (v.character), sinon la clé de la
--- personnalité (archétype, comportement d'avant IA2-0 : tests purs, sauvegardes sans traits).
local function pers_of(v)
  return v.character or v.personality
end

--- Seuil d'attaque entre factions multiplié par un tirage pour mille (lot IA2-0), arrondi, jamais sous 1.
function S.jittered_size(min_size, jitter)
  local n = math.floor(min_size * jitter / 1000 + 0.5)
  if n < 1 then n = 1 end
  return n
end

local function personality(v)
  return F.persona(pers_of(v))
end

--- La guerre ENTRE factions suit-elle le caractère tiré (lot IA2-0) ? Oui sans état PvP (tests purs d'avant IA0b
--- qui donnent un caractère) et en « Paisible » ; à un niveau agressif, seulement sous le CHEF (lot IA2-a,
--- v.chef) : il réserve d'abord les soldats de la prochaine attaque contre le joueur (S.player_reserve). Sans chef,
--- règle d'IA0 (bornes de pvp_test).
function S.faction_war_varied(v)
  if v.pvp == nil or v.chef ~= nil then return true end
  return not F.pvp_params(v.pvp.difficulty).aggressive
end

--- Lot IA2-a : multiplicateur (pour mille) du seuil d'attaque entre factions : celui du chef (tirage ±20 % refait à
--- chaque pensée, × posture, borné), sinon le tirage d'IA2-0 (v.attack_jitter), sinon aucun.
local function war_mult(v)
  if v.chef and v.chef.war_mult then return v.chef.war_mult end
  return v.attack_jitter
end

--- Lot IA2-a : RÉSERVE gardée pour le joueur à un niveau agressif : garnison qui permet d'envoyer la prochaine
--- attaque contre lui (besoin, ou taille visée après une première attaque ; S.player_garrison_for). Une attaque
--- ou un raid contre une RIVALE ne prend que les soldats au-delà. 0 en « Paisible » ou sans état PvP.
function S.player_reserve(v)
  local pv = v.pvp
  if not pv or not F.pvp_params(pv.difficulty).aggressive then return 0 end
  local level = pv.difficulty
  local goal = S.player_need(v, level)
  if (pv.sent_player or 0) > 0 then
    local g = S.player_target_size(v, level)
    if g > goal then goal = g end
  end
  return S.player_garrison_for(level, pers_of(v), goal)
end

--- Règle d'attaque entre factions : `varied` = caractère tiré et seuil multiplié ; `spare` = effectif au plus
--- (soldats au-delà de la réserve du joueur), ou nil.
local function attack_rule(v, varied, spare)
  local P = personality(v)
  local unit = F.best_soldier(v.tech)
  local strength = S.soldier_strength(unit, v.tech, v.upgrades)
  local count = math.floor(v.garrison * (1 - (varied and P.war_keep or P.keep)))
  if spare and count > spare then count = spare end
  -- Session 4 (économie réelle) : l'armée se paie en objets et grossit moins vite qu'avec l'ancien
  -- registre. Moteur réel (E16 it. 8) : un seuil lié à l'armée maximale (35 % de 100) retardait la
  -- première attaque à 30 min. Seuil = taille d'attaque de la personnalité : conquérant 13, équilibré 20,
  -- technocrate 25, bâtisseur 28 soldats envoyés (garnison gardée en plus).
  -- Lot IA0b : règle INCHANGÉE depuis IA0 (guerre entre factions, « Paisible » compris). Le bâtisseur
  -- (28 > 24 envoyables avec son armée visée) n'attaque jamais sa rivale : défaut antérieur (E21), hors du
  -- contrat IA0b ; son impasse contre le joueur est traitée dans S.decide (S.rival_stalled).
  local min_size = math.floor(F.military.attack_base / (varied and P.war_aggression or P.aggression))
  -- Lot IA2-0 : seuil tiré à ±20 % à chaque attaque (v.attack_jitter, pour mille, flux de la faction) : le
  -- moment et la taille des attaques entre factions ne sont plus un métronome. Sans tirage : règle d'IA0.
  -- Lot IA2-a : sous le chef, son multiplicateur (tirage refait à chaque pensée × posture, borné).
  local m = war_mult(v)
  if varied and m then min_size = S.jittered_size(min_size, m) end
  local needed = (v.enemy_defense or 0) * 1.3
  if v.can_attack ~= false and count >= min_size and count * strength >= needed then return count end
  return nil
end

--- Décision d'attaque : renvoie l'effectif à envoyer, ou nil.
--- Lot IA2-0 : en « Paisible » (aucune attaque contre le joueur), caractère tiré (war_keep, war_aggression) et seuil
--- tiré à ±20 % ; à un niveau AGRESSIF, règle d'IA0 (archétype, sans tirage). Mesuré : la campagne pure de
--- tests/pvp_test.lua perd l'ordre strict des niveaux pour 1 à 3 caractères sur 16 quand la guerre entre factions
--- varie à un niveau agressif (elle prend des soldats à la part visée contre le joueur).
--- Lot IA2-a : sous le chef (v.chef), à un niveau agressif : d'abord la règle VARIÉE (caractère tiré, seuil du chef)
--- avec les seuls soldats au-delà de la réserve du joueur (S.player_reserve) ; si elle ne part pas, la règle d'IA0.
--- Mesuré (campagne pure, 24 caractères × 11 configurations × 4 niveaux agressifs) : la réserve SEULE (sans repli
--- sur la règle d'IA0) casse l'ordre strict dans 143 cas sur 264 (guerres entre factions affamées : technocrate
--- 0 attaque contre sa rivale en Normal) ; avec le repli, 0 cas, mais la branche variée ne part que 9 à 17 fois sur
--- environ 8 500 attaques entre factions (la règle d'IA0 part avant que la garnison dépasse la réserve).
--- Second résultat : la règle appliquée, "variee" ou "ia0" (journal).
function S.attack(v)
  local aggressive = v.pvp ~= nil and F.pvp_params(v.pvp.difficulty).aggressive
  -- Lot IA2-a2 : TRÊVE du chef (toutes les rivales atteignables épargnées par satiété, shared/faction/chef.lua) : aucune
  -- attaque entre factions en « Paisible » ; à un niveau agressif, la règle ne change pas (seuil du chef au plus haut,
  -- règle d'IA0 ensuite) : une trêve qui bloquait la rivale y cassait l'ordre strict des tailles contre le joueur
  -- (campagne pure, 6 conquérants sur 24 en configuration 7, 1er essai du lot).
  if v.chef and (v.chef.hold or v.chef.vain) and not aggressive then return nil end
  if v.chef and aggressive then
    -- Lot ARMEE : à un niveau agressif aussi, la rivale est épargnée (`hold_rival` : trêve, vague déjà en route contre
    -- elle, attaque sans effet ou hors de la portée déjà atteinte ; script/faction/chef.lua, Chef.decision_fields).
    -- Champ distinct de `hold` : la campagne de pvp_test (qui ne le fournit pas) et le chemin contre le joueur
    -- (S.decide, plan « attack » avant tout appel à S.attack) restent ce qu'ils étaient.
    if v.chef.hold_rival then return nil end
    local n = attack_rule(v, true, v.garrison - S.player_reserve(v))
    if n then return n, "variee" end
    n = attack_rule(v, false)
    if n then return n, "ia0" end
    return nil
  end
  local varied = S.faction_war_varied(v)
  local n = attack_rule(v, varied)
  if n then return n, varied and "variee" or "ia0" end
  return nil
end

--- Lot IA2-a : RAID demandé par le chef (v.chef.raid = effectif visé, 5 à 10) contre la rivale : seulement avec les
--- soldats au-delà de la réserve du joueur ET de la garnison gardée de la faction ; force du groupe ≥ 1,3 × la
--- défense estimée de la cible du raid (v.chef.raid_defense). Renvoie l'effectif, ou nil.
function S.raid(v)
  local c = v.chef
  if not (c and c.raid and c.raid > 0) or c.hold or c.vain or v.can_attack == false then return nil end
  local P = personality(v)
  local n = c.raid
  local keep = math.ceil(v.garrison * (P.war_keep or P.keep) - 1e-9)
  local reserve = S.player_reserve(v)
  if reserve > keep then keep = reserve end
  if v.garrison - keep < n then return nil end
  local strength = S.soldier_strength(F.best_soldier(v.tech), v.tech, v.upgrades)
  if n * strength < (c.raid_defense or 0) * 1.3 then return nil end
  return n
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
  local P = F.persona(pers)
  -- Lot IA2-0 : agressivité tirée du caractère (grace_aggression, bornée à l'enveloppe des archétypes).
  return math.floor(d.grace_min * 3600 / (P.grace_aggression or P.aggression))
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

--- Lot IA2-c : intervalle entre deux attaques contre le joueur × tempo (pv.cooldown_mult, pour mille ; nil = 1 000).
--- Bornes : même au pire tirage ±20 %, l'intervalle d'un niveau reste plus court que celui du niveau d'en dessous
--- (Facile 12 > Normal 9,6 ; Normal 6,4 > Difficile 6 ; Difficile 4 > 3,6). MESURÉ ET NON RETENU en jeu : tiré après
--- chaque attaque, il casse l'ordre strict du nombre d'attaques dans la campagne de tests/pvp_test.lua (config 8,
--- conquérants : Normal 16 = Difficile 16) ; le runtime ne le fournit pas (seul le moment de la 1re attaque varie).
--- Jamais sous la fenêtre d'assaut coordonné (rally_min ≤ cooldown_min, IA0b : une faction ne se joint jamais à sa
--- propre fenêtre ; Impitoyable, 3 min × 0,8 = 2,4 min la cassait dans pvp_test).
function S.player_cooldown(pv, level)
  local c = S.cooldown_ticks(level)
  local m = pv and pv.cooldown_mult
  if m then
    c = math.floor(c * m / 1000)
    local r = S.rally_ticks(level)
    if c < r then c = r end
  end
  return c
end

--- Garnison gardée quand l'attaque vise le joueur.
function S.player_keep(level, pers)
  local P = F.persona(pers)
  local k = P.keep * F.pvp_params(level).keep_mult
  if k > F.pvp_rules.max_keep then k = F.pvp_rules.max_keep end
  return k
end

local function base_size(pers)
  local P = F.persona(pers)
  return math.floor(F.military.attack_base / P.aggression)
end

--- Effectif envoyé contre le joueur pour une garnison donnée (sans condition de force).
function S.player_count(level, pers, garrison)
  return math.floor(garrison * (1 - S.player_keep(level, pers)))
end

--- Armée visée d'une personnalité : même règle que le planificateur (shared/team/planner.lua,
--- P.army_target : T.army_share × soldiers_max).
function S.army_target(pers, soldiers_max)
  return math.floor((soldiers_max or F.defaults.soldiers_max) * (T.army_share[F.archetype_of(pers)] or 0.6))
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
  local P = F.persona(pers)
  return F.pvp_params(level).force_ratio * (P.caution or 1)
end

--- Soldats (du meilleur type débloqué) dont la force vaut `ratio` × la défense estimée du joueur (ou
--- `defense`, quand elle est donnée).
local function defense_units(v, ratio, defense)
  local strength = S.soldier_strength(F.best_soldier(v.tech), v.tech, v.upgrades)
  if defense == nil then defense = v.player and v.player.defense or 0 end
  return math.ceil(defense * ratio / strength - 1e-9)
end

--- Effectif minimal pour attaquer le joueur : taille minimale du niveau, et force ≥ rapport exigé
--- (S.player_ratio) × défense estimée (celle de la cible de la faction, ou `defense`). Avant IA0b : 1,3 à
--- tous les niveaux (règle entre factions).
function S.player_need(v, level, defense)
  local need = S.player_min_size(level, pers_of(v), v.soldiers_max)
  local by_defense = defense_units(v, S.player_ratio(level, pers_of(v)), defense)
  if by_defense > need then need = by_defense end
  return need
end

--- Taille visée des attaques qui suivent la première : la taille de base du niveau (S.player_goal), et,
--- face à une défense, size_mult × prudence × défense (lot IA0b : des attaques plus grandes aux niveaux
--- élevés, même quand la défense fixe la taille).
function S.player_target_size(v, level)
  local P = F.persona(pers_of(v))
  local g = S.player_goal(level, pers_of(v), v.soldiers_max)
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
  local cap = math.floor(F.pvp_rules.floor_cap * S.player_count(level, pers_of(v), S.army_target(pers_of(v), v.soldiers_max)) + 1e-9)
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

--- Effectif suffisant pour se joindre à un assaut coordonné : join_frac × besoin, jamais sous la taille
--- minimale du niveau (S.player_min_size). Le défenseur est occupé par l'attaque qui a ouvert la fenêtre, contre
--- la même cible : un groupe plus petit que le besoin est accepté, seulement quand la défense fixe le besoin.
function S.join_need(v, level, need)
  local j = math.ceil(need * F.pvp_params(level).join_frac - 1e-9)
  local m = S.player_min_size(level, pers_of(v), v.soldiers_max)
  if j < m then j = m end
  return j
end

function S.rally_ticks(level)
  return math.floor((F.pvp_params(level).rally_min or 0) * 3600)
end

--- Décision quand le joueur est « dû ». Campagne : on accumule, puis on frappe.
---   "attack"   : effectif ≥ taille visée ; ou ≥ plancher (S.player_floor) après save_min minutes
---                d'attente ; ou ≥ besoin une fois siege_min écoulé (la première attaque après la
---                déclaration part dès le besoin : taille visée = besoin) ;
---   "save"     : besoin atteint, la faction attend encore la taille visée : le plancher après save_min, le
---                besoin seul après siege_min (lot IA0b : avant, au plus save_min) ;
---   "join"     : un assaut coordonné est ouvert (Difficile, Impitoyable ; cible commune, de défense
---                pv.rally_defense) et soit le besoin n'est pas atteint mais l'effectif atteint S.join_need
---                (join_frac × besoin, jamais sous la taille minimale), soit le plancher est atteint (la
---                faction part avec les autres au lieu d'attendre la fin de save_min) ;
---   "deterred" : la garnison nécessaire dépasse le plafond du siège : repli sur la rivale (dissuasion) ;
---   "siege"    : la faction garde ses soldats pour le joueur, au plus siege_min minutes (lot IA0b) ;
---   "fallback" : siège expiré : répit, repli sur la rivale ; la prochaine attaque contre elle clôt le répit
---                et un nouveau siège commence (S.decide efface due_since).
--- Renvoie plan, effectif, besoin (pour "join" : le besoin contre la cible de la fenêtre).
function S.player_plan(v, level, due_since)
  local pv = v.pvp
  local d = F.pvp_params(level)
  if due_since == nil then due_since = pv.due_since end
  local count = S.player_count(level, pers_of(v), v.garrison)
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
  -- Compromis voulu (BALANCE_SHEET §10 bis) : l'attente « save » peut durer jusqu'à siege_min (et non plus
  -- save_min) ; borner cette attente à 1,5, 2 ou 3 × save_min dégrade l'ordre strict des niveaux (mesuré).
  if count >= need and waited >= math.floor(d.siege_min * 3600) and waited >= patience then return "attack", count, need end
  -- Assaut coordonné (Difficile, Impitoyable) : sous le besoin (la défense le fixe : jointe à join_frac ×
  -- besoin, jamais sous la taille minimale), ou plancher atteint sans attendre la fin de save_min.
  if S.rally_open(v, level) and (count < need or count >= floor_n) then
    local jneed = pv.rally_defense and S.player_need(v, level, pv.rally_defense) or need
    if count >= S.join_need(v, level, jneed) then return "join", count, jneed end
  end
  if count >= need then return "save", count, need end
  if (d.siege_min or 0) <= 0 then return "fallback", count, need end -- Facile : jamais de siège
  if S.player_garrison_for(level, pers_of(v), need) > S.siege_cap(level, pers_of(v), v.soldiers_max) then
    return "deterred", count, need
  end
  if waited < math.floor(d.siege_min * 3600) then return "siege", count, need end
  return "fallback", count, need
end


--- Délai au-delà duquel une faction qui n'a rien lancé (ni contre le joueur, ni contre une rivale) se
--- retourne contre le joueur malgré la règle du déficit (lot IA0b) : rival_wait × l'intervalle du niveau.
function S.rival_wait_ticks(level)
  return math.floor(F.pvp_rules.rival_wait * F.pvp_params(level).cooldown_min * 3600)
end

--- Impasse de la règle du déficit (lot IA0b) : aucune attaque lancée (joueur ou rivale) depuis
--- S.rival_wait_ticks. Sans attaque contre le joueur depuis la déclaration, le déficit le rend déjà dû.
function S.rival_stalled(v, level)
  local pv = v.pvp
  local last = pv.last_attack
  if pv.last_rival and (last == nil or pv.last_rival > last) then last = pv.last_rival end
  return last ~= nil and pv.tick - last >= S.rival_wait_ticks(level)
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
      local grace_end = S.grace_end(pv.anchor, pv.grace_floor, level, pers_of(v))
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
  --    visée × soldats envoyés depuis la déclaration), sinon la faction rivale. Lot IA0b, fin de l'impasse :
  --    une faction qui ne peut pas attaquer sa rivale n'enverrait plus jamais rien au joueur (le déficit ne
  --    se comble qu'en attaquant la rivale) ; le joueur redevient dû si la faction n'a rien lancé (ni contre
  --    lui, ni contre une faction) depuis rival_wait × l'intervalle du niveau (S.rival_stalled).
  local player_ok = pv and d.aggressive and declared and v.player and v.player.reachable
    and (v.player.score or 0) > 0
    and (pv.last_attack == nil or pv.tick - pv.last_attack >= S.player_cooldown(pv, level))
  -- Lot IA2-c : MOMENT de la 1re attaque de la partie contre le joueur (pv.first_after : valeur du niveau × tempo
  -- tiré à ±20 %, shared/faction/adversaire.lua). Le joueur reste « dû » dès la déclaration (règle d'IA0 : la faction
  -- garde ses soldats pour lui), mais aucune attaque ne part avant le moment. Moteur réel (essai 2 du lot) : avec une
  -- préparation de 4 min seulement, Émeraude (graine 3141592653) avait vidé sa garnison sur sa rivale et n'attaquait
  -- qu'à 34,0 min (26,2 avant le lot).
  local hold_first = player_ok and pv.first_after ~= nil and pv.tick < pv.first_after
  -- Lot ARMEE : une rivale épargnée (`hold_rival` : vague en route, attaque sans effet, trêve) ne fait pas attendre le
  -- joueur derrière la règle du déficit, comme une faction sans rivale : sans cela, la part du joueur ne se comblerait
  -- plus (sent_total n'augmente plus) avant la fin de l'impasse, rival_wait × l'intervalle du niveau.
  local rival_held = v.chef ~= nil and v.chef.hold_rival == true
  local due = player_ok
    and ((v.rival == nil) or rival_held or (pv.sent_player or 0) <= S.player_share(v, level) * (pv.sent_total or 0)
      or S.rival_stalled(v, level))
  if pv then
    if due and pv.due_since == nil then out.due_since = pv.tick end
    if not due and pv.due_since ~= nil then out.due_since = false end
  end
  if due then
    local plan, n, need = S.player_plan(v, level, pv.due_since or out.due_since)
    if hold_first and (plan == "attack" or plan == "join") then plan = "save" end -- lot IA2-c : pas avant le moment
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
    local n, rule = S.attack(v)
    if n then
      out.attack = { target = v.rival.id, count = n, rule = rule }
      -- Fin du répit : l'attaque contre la rivale part, un nouveau siège commencera à la pensée suivante.
      if out.plan == "fallback" then out.due_since = false end
    elseif out.plan == nil then
      -- Lot IA2-a : raid du chef, seulement quand le joueur n'est pas « dû » (ni attente, ni siège, ni répit). Un
      -- raid ne compte ni dans la part visée (sent_total) ni comme attaque contre une rivale (last_rival : fin de
      -- l'impasse inchangée) : script/faction/pvp.lua, Military.on_launched.
      local r = S.raid(v)
      if r then out.attack = { target = v.rival.id, count = r, raid = true } end
    end
  end
  return out
end

return S
