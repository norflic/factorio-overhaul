--[[
  Lot IA3-k : RÔLES des soldats de faction entre deux attaques (B5, C4, C7 ; docs/IA3K_COMPORTEMENTS.md §6). PUR
  (tests/ia3k_soldats_test.lua).

  Seuls les soldats SANS groupe du moteur (garnison) reçoivent un rôle ; une attaque, un éclaireur ou un rappel du chef
  les reprend (priorité au chef). Par ordre :
    1. DÉFENSE (C7) : points à défendre (QG menacé : tous les soldats ; alerte d'un PNJ en fuite : les n plus proches) ;
    2. ESCORTE : demandes de la porte des tâches (n soldats au plus près du PNJ escorté ; les escorteurs déjà attribués
       restent) ;
    3. repos : un soldat dont la mission vient de finir se repose REST ticks (il n'est ni compté « sans ordre », ni pris) ;
    4. NETTOYAGE : une menace fixe vue près d'un avant-poste ou d'un trajet (ou qui a tué) est attaquée quand la garnison
       libre suffit (2 par menace du groupe + 3) et que la faction est agressive (≥ 900) ou que la menace a tué ; une
       opération à la fois ;
    5. PATROUILLE : une part `patrol_share(agressivité)` des soldats libres tourne sur l'anneau de la frontière
       (8 secteurs à PATROL_R tuiles du QG) et autour des avant-postes proches, par paires, chaque point PATROL_TICKS ;
    6. GARDE : les autres tiennent des postes (8 postes à GUARD_R tuiles du QG ; avant-postes marqués : 2 gardes).
  Entrées triées, sorties par identifiant : aucun ordre de `pairs`. Racines carrées seulement.
]]

local Sd = {}

Sd.REST = 3600
Sd.PATROL_R = 80
Sd.PATROL_TICKS = 2400
Sd.GUARD_R = 28
Sd.GUARD_TICKS = 3 * 3600
Sd.ESCORT_MAX = 6
Sd.CLEAR_BASE = 3
Sd.CLEAR_PER = 2
Sd.CLEAR_AGR = 900
Sd.SAFE_R = 56 -- lot CENTRALE : un point de patrouille ou de garde n'est pas à moins de 56 tuiles d'un nid ou d'un ver CONNU
Sd.PATROL_RADII = { 80, 56, 32 } -- anneau de patrouille : le rayon le plus grand dont le point est sûr, dans chaque direction
Sd.GUARD_RADII = { 28, 16 }
Sd.NEAR_HQ = 160 -- au-delà : un soldat n'est pas pris pour une escorte, une patrouille ou une garde du QG
-- Lot CORR-SOLDATS (remarque 4 du DC : « 25 soldats inactifs [...] alors qu'ils pourraient détruire la base de biters »).
-- EXPÉDITION des soldats inactifs : un champ de nids CONNU à moins de OFFENSE_R tuiles du QG est attaqué dès que le besoin
-- (clear_need) tient dans le SURPLUS (inactifs moins la réserve gardée au QG) ; jamais toute la garnison, rien si le champ
-- est trop gros ; retraite si plus de la moitié de la force de départ est morte, site non retenté pendant RETREAT_COOL.
Sd.OFFENSE_R = 130
Sd.RESERVE_MIN = 8
Sd.RESERVE_SHARE = 350 -- pour mille des inactifs gardés au QG
Sd.RETREAT_COOL = 20 * 3600
Sd.BLOCK_R = 24
Sd.WIDE_R = 40 -- le champ ENTIER : toutes les menaces connues à moins de 40 tuiles du groupe (un champ étalé fait plusieurs groupes de 24)
-- Lot ACT-SOLDATS (fumée 0.6.13 : deux parties de 60 min, 24 soldats inactifs pendant 35 min chez Scarlet, aucune expédition) : les
-- candidats de l'expédition ne venaient QUE de la carte du danger (nids vus en marche par un PNJ armé : 0 à 1 nid en 60 min), jamais de
-- la carte de CONNAISSANCE (nids vus par les yeux du QG, des avant-postes et des éclaireurs), que le lot CORR-SOLDATS citait pourtant.
Sd.KNOWN_R = Sd.OFFENSE_R + Sd.WIDE_R -- nids connus lus autour du QG : la portée de l'expédition et le champ entier derrière
Sd.DUP_R = 4 -- un point connu à moins de 4 tuiles d'une menace vue du même genre est la même menace

-- 8 directions (vecteurs unitaires approchés en rationnels : aucune trigonométrie).
local DIRS = { { 1, 0 }, { 0.7071, 0.7071 }, { 0, 1 }, { -0.7071, 0.7071 }, { -1, 0 }, { -0.7071, -0.7071 }, { 0, -1 }, { 0.7071, -0.7071 } }
Sd.DIRS = DIRS

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

--- Part (pour mille) des soldats libres en patrouille selon l'agressivité : 250 (pacifique) à 750 (conquérant).
function Sd.patrol_share(agr)
  local v = math.floor((agr or 1000) / 2)
  if v < 250 then return 250 end
  if v > 750 then return 750 end
  return v
end

--- Soldats nécessaires pour nettoyer un groupe de k menaces.
function Sd.clear_need(k) return Sd.CLEAR_BASE + Sd.CLEAR_PER * k end

--- Réserve gardée au QG quand `idle` soldats sont inactifs (au moins RESERVE_MIN, ou RESERVE_SHARE pour mille).
function Sd.reserve(idle)
  local r = math.ceil(idle * Sd.RESERVE_SHARE / 1000)
  if r < Sd.RESERVE_MIN then r = Sd.RESERVE_MIN end
  return r
end

--- Soldats inactifs qu'une expédition peut prendre sans toucher à la réserve.
function Sd.surplus(idle)
  local s = idle - Sd.reserve(idle)
  if s < 0 then s = 0 end
  return s
end

--- Retraite : plus de la moitié de la force de départ n0 est morte (lost).
function Sd.retreat(n0, lost) return (n0 or 0) > 0 and lost * 2 > n0 end

--- Le groupe th est-il un site abandonné (liste { x, y, ["until"] }) encore interdit au tick donné ?
function Sd.is_blocked(blocked, th, tick)
  for _, b in ipairs(blocked or {}) do
    if tick < b["until"] and d2(b, th) <= Sd.BLOCK_R * Sd.BLOCK_R then return true end
  end
  return false
end

--- Complète `cand` (menaces fixes vues par les PNJ en marche : { x, y, kind, killed }) avec les nids et vers de la carte de
--- connaissance (`points` : K.enemy_points, { x, y, kind }), sans doublon. Les ajouts portent `known = true` : ils ne servent
--- qu'à l'EXPÉDITION (réserve gardée, champ entier mesuré), jamais au vieux seuil d'agressivité. Renvoie le nombre d'ajouts.
function Sd.add_known(cand, points)
  local added = 0
  local dup2 = Sd.DUP_R * Sd.DUP_R
  local seen = #cand
  for _, p in ipairs(points or {}) do
    local same = false
    for i = 1, seen do
      local c = cand[i]
      if c.kind == p.kind and d2(c, p) <= dup2 then same = true break end
    end
    if not same then
      cand[#cand + 1] = { x = p.x, y = p.y, kind = p.kind, known = true }
      added = added + 1
    end
  end
  return added
end

--- Un groupe de menaces peut-il être attaqué par EXPÉDITION avec `idle` soldats inactifs ? Au moins un nid, aucune tourelle
--- adverse (une faction n'est pas un nid), à portée du QG, et un besoin qui tient dans le surplus.
function Sd.offense_ok(th, hq, idle)
  if (th.nests or 0) < 1 or (th.rival or 0) > 0 then return false end
  if d2(th, hq) > Sd.OFFENSE_R * Sd.OFFENSE_R then return false end
  local k = th.k or 1
  if (th.wide or 0) > k then k = th.wide end
  return Sd.clear_need(k) <= Sd.surplus(idle)
end

--- Lot CENTRALE (moteur réel, etape1-guide 123456789 et 271828182, Azure : QG à 70-90 tuiles de groupes de nids ; les 5 soldats
--- partaient en patrouille sur l'anneau de 80 tuiles, au pied des nids et des vers, y mouraient (5, 3, 0 soldat de 5 à 7 min,
--- puis encore de 18 à 19 min) et le QG n'en avait pas à 12 min ; Écarlate, sans ennemi à 60 tuiles, patrouillait sans perte) :
--- points de l'anneau dans les 8 directions, chacun au plus grand rayon de `radii` (décroissant) dont le point est sûr.
--- safe(x, y) -> bool (nids et vers connus, danger de la carte de l'équipe). Une direction sans point sûr est sautée : la liste
--- peut être vide (les soldats restent alors en garde près du QG). Sortie triée par direction ; racines et sommes seulement.
function Sd.safe_ring(hq, radii, safe)
  local out = {}
  for _, d in ipairs(DIRS) do
    for _, r in ipairs(radii) do
      local x, y = hq.x + d[1] * r, hq.y + d[2] * r
      if safe(x, y) then
        out[#out + 1] = { x = x, y = y }
        break
      end
    end
  end
  return out
end

--- Les n soldats libres les plus proches de p (distance, puis identifiant). free = liste triée par id ; taken = { [id] }.
local function nearest(free, taken, p, n, hq, max_hq)
  local c = {}
  for _, s in ipairs(free) do
    if not taken[s.id] and (not max_hq or d2(s, hq) <= max_hq * max_hq) then c[#c + 1] = { s = s, d = d2(s, p) } end
  end
  table.sort(c, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.s.id < b.s.id end)
  local out = {}
  for i = 1, math.min(n, #c) do out[i] = c[i].s end
  return out
end

--- Attribution. input = {
---   tick, hq = {x,y}, agr, soldiers = { { id, x, y, role, rest_until, escort = aid } } (triés par id),
---   defend = { { key, x, y, n } } (n = nil : tous), escorts = { { aid, x, y, n } } (triés par aid),
---   threats = { { x, y, k, killed } } (menaces fixes candidates au nettoyage, déjà filtrées par l'appelant),
---   clearing = { x, y } | nil (opération en cours), blocked = { { x, y, until } } (sites abandonnés), offense = false (coupure), patrol_pts = { {x,y} } (nil : anneau du QG), guard_pts (nil : postes
---   du QG), marked_outposts = { {x,y} }, cursor = entier (rotation des patrouilles) }
--- Renvoie orders = { [id] = { role, x, y, aid, key } }, et le résumé { idle, rest, far, offense, roles = { [rôle] = n } } (far :
--- soldats égarés loin du QG sans rôle à poursuivre, laissés au rappel du chef).
function Sd.assign(input)
  local orders, taken = {}, {}
  local tick = input.tick or 0
  local hq = input.hq
  local free = {}
  local summary = { idle = 0, rest = 0, far = 0, roles = {} }
  for _, s in ipairs(input.soldiers) do free[#free + 1] = s end
  local function give(s, o)
    o.key = o.role .. ":" .. math.floor(o.x) .. ":" .. math.floor(o.y) .. ":" .. tostring(o.aid or "")
    orders[s.id] = o
    taken[s.id] = true
    summary.roles[o.role] = (summary.roles[o.role] or 0) + 1
  end
  -- 1. Défense (même au repos).
  for _, dp in ipairs(input.defend or {}) do
    local list = nearest(free, taken, dp, dp.n or #free, hq, nil)
    for _, s in ipairs(list) do give(s, { role = dp.role or "defense", x = dp.x, y = dp.y }) end
  end
  -- 2. Escortes.
  for _, er in ipairs(input.escorts or {}) do
    local n = math.min(er.n or 2, Sd.ESCORT_MAX)
    local have = 0
    for _, s in ipairs(free) do
      if have < n and not taken[s.id] and s.escort == er.aid then
        give(s, { role = "escort", x = er.x, y = er.y, aid = er.aid })
        have = have + 1
      end
    end
    if have < n then
      local avail = {}
      for _, s in ipairs(free) do if not (s.rest_until and tick < s.rest_until) then avail[#avail + 1] = s end end
      for _, s in ipairs(nearest(avail, taken, er, n - have, hq, Sd.NEAR_HQ)) do
        give(s, { role = "escort", x = er.x, y = er.y, aid = er.aid })
      end
    end
  end
  -- 3. Repos.
  local rest = {}
  for _, s in ipairs(free) do
    if not taken[s.id] and s.rest_until and tick < s.rest_until then
      rest[s.id] = true
      summary.rest = summary.rest + 1
    end
  end
  -- Loin du QG (au-delà de NEAR_HQ) : pas de rôle NOUVEAU (le rappel du chef ramène les égarés) ; on poursuit seulement un
  -- nettoyage en cours ou la garde d'un avant-poste marqué proche.
  local avail, far = {}, {}
  local n2 = Sd.NEAR_HQ * Sd.NEAR_HQ
  for _, s in ipairs(free) do
    if not taken[s.id] and not rest[s.id] then
      if d2(s, hq) <= n2 then avail[#avail + 1] = s else far[#far + 1] = s end
    end
  end
  -- 4. Nettoyage (une opération à la fois : la cible en cours d'abord).
  local target = input.clearing
  local by_offense = false
  if not target then
    local offense = input.offense ~= false -- coupure de banc : input.offense == false (ni expédition ni site interdit)
    for _, th in ipairs(input.threats or {}) do
      if not (offense and Sd.is_blocked(input.blocked, th, tick)) then
        -- Vieux seuil d'agressivité : seulement si au moins une menace du groupe a été VUE en marche (pas connue de la seule carte).
        if ((input.agr or 1000) >= Sd.CLEAR_AGR or th.killed) and (th.known or 0) < (th.k or 1) and #avail >= Sd.clear_need(th.k or 1) then
          target = th
          break
        elseif offense and Sd.offense_ok(th, hq, #avail) then
          target, by_offense = th, true
          break
        end
      end
    end
  end
  summary.offense = by_offense
  summary.target = target
  -- Opération en cours : `need` = force encore en vie (posée par l'appelant), sinon le besoin du groupe (sans cela, après le
  -- premier passage, seuls clear_need(1) = 5 soldats auraient gardé leur ordre et les autres seraient repartis en patrouille).
  -- Expédition : la force envoyée est celle que offense_ok a contrôlée (le champ entier, pas le seul groupe de 24 tuiles).
  local kk = target and (target.k or 1) or 1
  if by_offense and (target.wide or 0) > kk then kk = target.wide end
  local need = target and (target.need or Sd.clear_need(kk)) or 0
  for _, s in ipairs(far) do
    if target and s.role == "clear" and need > 0 then
      give(s, { role = "clear", x = target.x, y = target.y })
      need = need - 1
    elseif s.role == "guard" then
      local post = nil
      for _, o in ipairs(input.marked_outposts or {}) do if d2(s, o) <= 64 * 64 then post = o break end end
      if post then give(s, { role = "guard", x = post.x, y = post.y }) else summary.far = (summary.far or 0) + 1 end
    else
      summary.far = (summary.far or 0) + 1
    end
  end
  if target and need > 0 then
    for _, s in ipairs(nearest(avail, taken, target, need, hq, nil)) do give(s, { role = "clear", x = target.x, y = target.y }) end
  end
  -- 5. Patrouille, 6. garde.
  local rest_av = {}
  for _, s in ipairs(avail) do if not taken[s.id] then rest_av[#rest_av + 1] = s end end
  local n_patrol = math.floor(#rest_av * Sd.patrol_share(input.agr) / 1000 + 0.5)
  local ppts = input.patrol_pts
  if ppts and #ppts == 0 then n_patrol = 0 end -- aucun point sûr : tous en garde
  if not ppts then
    ppts = {}
    for i, d in ipairs(DIRS) do ppts[i] = { x = hq.x + d[1] * Sd.PATROL_R, y = hq.y + d[2] * Sd.PATROL_R } end
  end
  local gpts = {}
  for _, o in ipairs(input.marked_outposts or {}) do gpts[#gpts + 1] = o; gpts[#gpts + 1] = o end
  for _, g in ipairs(input.guard_pts or {}) do gpts[#gpts + 1] = g end
  if not input.guard_pts then
    for _, d in ipairs(DIRS) do gpts[#gpts + 1] = { x = hq.x + d[1] * Sd.GUARD_R, y = hq.y + d[2] * Sd.GUARD_R } end
  end
  local cur = input.cursor or 0
  local slot = math.floor(tick / Sd.PATROL_TICKS)
  for i, s in ipairs(rest_av) do
    if i <= n_patrol then
      -- par paires : soldats 2j-1 et 2j au même point ; le point tourne d'un cran toutes les PATROL_TICKS
      local j = math.floor((i - 1) / 2)
      local p = ppts[(j + slot + cur) % #ppts + 1]
      give(s, { role = "patrol", x = p.x, y = p.y })
    elseif #gpts > 0 then
      local p = gpts[(i - n_patrol - 1) % #gpts + 1]
      give(s, { role = "guard", x = p.x, y = p.y })
    else
      summary.idle = summary.idle + 1
    end
  end
  return orders, summary
end

--- Groupes de menaces fixes (à moins de 24 tuiles l'une de l'autre) : { x, y, k } triés par (x, y). threats triées.
function Sd.clusters(threats)
  local out = {}
  for _, t in ipairs(threats) do
    local hit = nil
    for _, c in ipairs(out) do
      if d2(c, t) <= 24 * 24 then hit = c break end
    end
    local nest = t.kind == "spawner" and 1 or 0
    local rival = t.kind == "turret" and 1 or 0
    if hit then
      hit.k = hit.k + 1
      hit.nests, hit.rival = hit.nests + nest, hit.rival + rival
      if t.known then hit.known = hit.known + 1 end
      if t.killed then hit.killed = true end
    else
      out[#out + 1] = { x = t.x, y = t.y, k = 1, killed = t.killed, nests = nest, rival = rival, known = t.known and 1 or 0 }
    end
  end
  -- Champ entier autour de chaque groupe (lot CORR-SOLDATS) : le besoin d'une expédition se compte sur TOUT ce qui l'attend.
  local w2 = Sd.WIDE_R * Sd.WIDE_R
  for _, c in ipairs(out) do
    local n = 0
    for _, t in ipairs(threats) do if d2(c, t) <= w2 then n = n + 1 end end
    c.wide = n
  end
  return out
end

return Sd
