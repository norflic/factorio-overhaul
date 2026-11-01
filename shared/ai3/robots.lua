--[[
  Lot RB-3 CERVEAU (1/11) : la DÉCISION pure des unités que l'équipe fait fabriquer (PLAN fo-logs/2026-10-31_ROBOTS §4). PUR :
  aucune API Factorio, AUCUN nom d'objet, de machine, de recette ou d'unité (anti-échelle de tests/iag_test.lua §8 ; preuve par
  permutation et par une unité inventée dans tests/ai3_robots_test.lua). Le catalogue (shared/ai3/catalogue.lua) donne les unités
  lues dans les prototypes : un candidat = { item (le kit qui la pose), hp, dps (nil : non lisible), range, min_range, zone, points,
  cost, usable } ; un mod qui ajoute une unité y entre sans une ligne.

  Ce que le module décide, rien d'autre :
    - la VALEUR d'une unité = √(PV × DPS) × (portée ÷ portée de référence)^½, et son score = valeur ÷ coût (moins cher pour
      la même force = meilleur) ; une unité sans dégâts (soutien) vaut √(PV × DPS de référence) ;
    - le CHOIX parmi les candidats utilisables, sous trois règles lues aux nombres, jamais aux noms :
        artillerie (portée minimale > 0)  : au plus INDIRECT_MAX des points d'armée ;
        soutien (DPS déclaré 0)           : au plus SOUTIEN_MAX des points d'armée ;
        zone préférée si un essaim est vu : un grand nombre d'ennemis dont les PV moyens sont une fraction de ceux de nos unités ;
      l'hystérésie garde le choix précédent tant que le nouveau ne le dépasse pas de HYSTERESIS ;
    - le BESOIN en points (la part de robots visée moins ce qu'on a, bornée par la place sous le plafond) et la DEMANDE en objets par
      minute pour le combler en HORIZON_MIN minutes (ce que le mall d'INDUSTRIE lit : une demande, jamais un ordre de pose).
  Un DPS non lisible (les dégâts d'une arme ne sont pas toujours dans le relevé) est estimé à PV ÷ HP_PER_DPS : estimation DÉCLARÉE,
  jamais présentée comme une mesure.
  Déterminisme : listes triées, ex æquo au nom de l'objet, aucun pairs décisionnel, aucune horloge, entiers et flottants calculés
  dans un ordre fixe ; l'état de l'appelant (nombres et chaînes) est sérialisable.
]]

local Rb = {}

local floor, max, min, sqrt, ceil = math.floor, math.max, math.min, math.sqrt, math.ceil

Rb.REF_RANGE = 16        -- portée de référence (tuiles) : la valeur est multipliée par (portée ÷ cette portée)^½
Rb.SOUTIEN_MAX = 0.10    -- part maximale des points d'armée en unités sans dégâts
Rb.INDIRECT_MAX = 0.25  -- part maximale des points d'armée en unités à portée minimale
Rb.ZONE_FACTOR = 1.5     -- score multiplié d'une unité de zone quand un essaim est vu
Rb.SWARM_COUNT = 8       -- ennemis vus au moins pour parler d'essaim
Rb.SWARM_RATIO = 4       -- et leurs PV moyens au plus le médian des PV de nos candidats ÷ ce nombre
Rb.HP_PER_DPS = 9        -- DPS estimé = PV ÷ ce nombre quand le relevé n'en donne pas (estimation déclarée)
Rb.SUPPORT_DPS = 20      -- DPS de référence de la valeur d'une unité de soutien
Rb.HYSTERESIS = 1.15     -- le choix précédent reste tant que le meilleur ne le dépasse pas de 15 %
Rb.SHARE = 0.5           -- part des points d'armée visée en robots
Rb.HORIZON_MIN = 10      -- minutes pour combler le manque
Rb.MIN_RATE = 0.2        -- demande minimale (objets par minute) quand il manque quelque chose
Rb.EPS = 1e-9

--- DPS d'un candidat : celui du relevé (0 : soutien), sinon l'estimation PV ÷ HP_PER_DPS.
function Rb.dps(u)
  if type(u.dps) == "number" and u.dps >= 0 then return u.dps end
  return (u.hp or 0) / Rb.HP_PER_DPS
end

--- Classe d'un candidat lue aux nombres : "soutien" (DPS déclaré 0), "indirect" (portée minimale > 0), sinon "ligne".
function Rb.kind(u)
  if type(u.dps) == "number" and u.dps == 0 then return "soutien" end
  if (u.min_range or 0) > 0 then return "indirect" end
  return "ligne"
end

--- Valeur d'une unité (sans unité de mesure : seule la comparaison compte).
function Rb.value(u)
  local d = Rb.dps(u)
  if d <= 0 then d = Rb.SUPPORT_DPS end
  return sqrt(max(0, u.hp or 0) * d) * sqrt(max(u.range or 0, 1) / Rb.REF_RANGE)
end

--- Score : valeur ÷ coût (un coût nul ou négatif n'est pas un candidat : score 0).
function Rb.score(u)
  if type(u.cost) ~= "number" or u.cost <= Rb.EPS then return 0 end
  return Rb.value(u) / u.cost
end

--- Y a-t-il un essaim ? enemy = { count (ennemis vus), hp (PV moyens) } ; la comparaison est relative à NOS unités (médian des PV des
--- candidats), jamais à un nombre du jeu.
function Rb.swarm(enemy, cands)
  if type(enemy) ~= "table" or (enemy.count or 0) < Rb.SWARM_COUNT or (enemy.hp or 0) <= 0 then return false end
  local hps = {}
  for _, c in ipairs(cands or {}) do hps[#hps + 1] = c.hp or 0 end
  if #hps == 0 then return false end
  table.sort(hps)
  local median = hps[floor((#hps + 1) / 2)]
  return enemy.hp * Rb.SWARM_RATIO <= median
end

--- Points d'armée par classe et total, depuis `have` = { [objet] = points vivants } et la table des candidats.
local function shares(cands, have)
  local by_item = {}
  for _, c in ipairs(cands) do by_item[c.item] = c end
  local out = { soutien = 0, indirect = 0, ligne = 0, total = 0 }
  local names = {}
  for k in next, have or {} do names[#names + 1] = k end
  table.sort(names)
  for _, k in ipairs(names) do
    local p = have[k] or 0
    local c = by_item[k]
    out[c and Rb.kind(c) or "ligne"] = out[c and Rb.kind(c) or "ligne"] + p
    out.total = out.total + p
  end
  return out
end

--- Choisit l'unité à faire fabriquer. cands = liste de candidats (voir l'en-tête ; `usable` faux : écarté) ;
--- st = { have = { [objet] = points vivants }, enemy = { count, hp } ou nil, prev = objet choisi la dernière fois ou nil }.
--- Rend { item, score, kind, swarm, why } ou (nil, raison).
function Rb.choose(cands, st)
  st = st or {}
  local list = {}
  for _, c in ipairs(cands or {}) do
    if c.usable and (c.points or 0) > 0 and Rb.score(c) > 0 then list[#list + 1] = c end
  end
  if #list == 0 then return nil, "aucune unite utilisable" end
  table.sort(list, function(a, b) return a.item < b.item end)
  local sh = shares(list, st.have)
  local swarm = Rb.swarm(st.enemy, list)
  local best, best_score, refused
  local scores = {}
  for _, c in ipairs(list) do
    local kind = Rb.kind(c)
    local cap = (kind == "soutien" and Rb.SOUTIEN_MAX) or (kind == "indirect" and Rb.INDIRECT_MAX) or 1
    local after = (sh[kind] + c.points) / (sh.total + c.points)
    if kind ~= "ligne" and after > cap + Rb.EPS then
      refused = (refused and refused .. " ; " or "") .. string.format("%s (%s %.0f%% > %.0f%%)", c.item, kind, after * 100, cap * 100)
    else
      local s = Rb.score(c)
      if swarm and c.zone then s = s * Rb.ZONE_FACTOR end
      scores[c.item] = s
      if best == nil or s > best_score + Rb.EPS then best, best_score = c, s end
    end
  end
  if not best then return nil, "aucune unite sous les regles de part" .. (refused and (" : " .. refused) or "") end
  -- hystérésis : le choix précédent reste s'il est encore possible et que le meilleur ne le dépasse pas assez
  if st.prev and st.prev ~= best.item and scores[st.prev] and best_score < scores[st.prev] * Rb.HYSTERESIS then
    for _, c in ipairs(list) do
      if c.item == st.prev then best, best_score = c, scores[st.prev] end
    end
  end
  return { item = best.item, score = best_score, kind = Rb.kind(best), swarm = swarm, points = best.points,
    why = refused and ("ecartees : " .. refused) or nil }
end

--- Points à ajouter : la part visée de robots (SHARE × plafond) moins ce qu'on a, bornée par la place sous le plafond.
function Rb.want(cap, used, robots)
  local room = max(0, (cap or 0) - (used or 0))
  local target = floor((cap or 0) * Rb.SHARE + Rb.EPS)
  return max(0, min(room, target - (robots or 0)))
end

--- Demande en objets par minute pour apporter `want` points avec l'unité choisie ; nil si rien à demander.
--- Rend { item, rate, units }.
function Rb.demand(choice, want)
  if not choice or (want or 0) <= 0 or (choice.points or 0) <= 0 then return nil end
  local units = ceil(want / choice.points - Rb.EPS)
  return { item = choice.item, units = units, rate = max(Rb.MIN_RATE, units / Rb.HORIZON_MIN) }
end

return Rb
