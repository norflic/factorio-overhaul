--[[
  TRAVERSEE (lot TRAVERSEE, demande du DC du 8/11, en jouant la 0.6.65) : le tracé d'un tapis du plan directeur FRANCHIT un
  obstacle par une paire de tapis souterrains (ou le contourne), et ÉVITE les gisements (tapis comme poteaux). Lua PUR : aucune API
  du jeu, aucun nom d'objet, aucun nom de minerai (portée des souterrains, tuiles interdites, tuiles de gisement arrivent en DONNÉES) ;
  lu hors jeu (tests/traversee_test.lua) et en jeu par script/team/traversee.lua.

  Le DC : « il est possible que la construction d'une fonderie soit bloquée parce qu'elle peut pas être construite à cause des poteaux
  électriques ou des obstacles [...] il faut trouver le moyen de pouvoir entre guillemets enjamber cet obstacle-là, par exemple en
  posant des tunnels souterrains, en posant des splitters, en contournant avec des convoyeurs. Évitez également de passer par-dessus
  les gisements [...] Évidemment, si vous ne pouvez pas passer par autre part que par le gisement, passez par le gisement, mais
  essayez quand même d'organiser le passage un minimum. »

  Avant le lot (shared/team/plan.lua, P.belt_route) : un A* à 4 voisins, une tuile interdite l'est pour de bon (poteau, tapis croisé,
  bâtiment : détour ou « aucun chemin »), aucune idée de gisement. Mesuré dans la partie du DC (0.6.58, 175 min) : 8 liaisons sur 13
  refusées, 9 lignes « liaison: aucun chemin ».

  RÈGLE
  1. PAIRE SOUTERRAINE : mêmes conventions que la colonne de fours déjà jouée en moteur réel (shared/team/champ_colonne.lua, Co.route) :
     on arrive TOUT DROIT sur la tuile d'entrée ; la sortie est à k tuiles, 2 <= k <= maxd (maxd = portée lue aux données, nil : aucune
     paire) ; la tuile de sortie est libre (et n'est pas la cible) ; la tuile qui suit la sortie est atteinte tout droit. Les tuiles
     ENTRE l'entrée et la sortie peuvent être n'importe quoi (poteau, tapis, bâtiment, eau, falaise) sauf une pièce souterraine de MÊME
     axe (ctx.ug_axis). Surcoût d'une paire : Tv.UG_COST + k - 1 (jamais moins que de marcher sur terrain libre : l'heuristique reste
     admissible, une paire ne sert que pour passer un obstacle ou un gisement).
  2. GISEMENT : une tuile où se pose une pièce (tapis, entrée ou sortie) et qui porte du minerai coûte `pen` de plus. Trois étapes :
     (a) tracé de base, sans surcoût ; (b) s'il couvre du gisement, un tracé par surcoût de Tv.ORE_STEPS (8 puis 3 par tuile), cherché dans
     l'ELLIPSE des tuiles que la borne laisse atteignables ; (c) parmi les candidats dont la longueur PHYSIQUE (tuiles, trous des paires
     compris) reste sous la BORNE DE DÉTOUR (Tv.detour_limit : longueur de base + max(6, moitié), au plus + 24), celui qui couvre le MOINS
     de gisement (puis le plus court, puis le surcoût le plus faible). Si aucun détour raisonnable
     n'existe, le tracé traverse : les paires souterraines de portée maximale ne posent que l'entrée et la sortie, le gisement reste libre
     entre elles.
  3. POTEAUX (Tv.pole_chain) : la chaîne d'avant, puis une chaîne SANS tuile de gisement ; gardée si elle existe et pose au plus
     Tv.POLE_EXTRA poteaux de plus. Jamais plus de refus qu'avant.
  4. PREUVE (Tv.verify) : tuiles distinctes, chaque maillon mène au suivant, entrée droite, sortie droite, portée, tuiles libres, aucune
     pièce souterraine de même axe sous une paire, dernière tuile tournée vers la cible.
  5. JOURNAL (Tv.lines) : une ligne [FO-TRAVERSEE] par franchissement, une par détour ou gisement couvert.

  Déterminisme : tas à départage (f, h, clé), directions dans un ordre fixe, aucun `pairs`, aucune trigonométrie, aucun temps mesuré.
  Coordonnées : tuiles entières (x, y) ; direction de sortie : code du jeu (0 N, 2 E, 4 S, 6 O).
]]

local Tv = {}

Tv.UG_COST = 6                   -- surcoût d'une paire de souterrains (tuiles de tapis) : ~12 tuiles de plaques-équivalent moins les 2 pièces ; Co.UG_COST vaut 3
Tv.ORE_STEPS = { 8 }             -- surcoût par tuile de gisement des recherches de détour (mesuré : 4 recherches coûtaient 3,5 à 127 millions d'instructions ; une seule, plafonnée)
Tv.ORE_WEIGHT = 1.5                -- heuristique des recherches « gisement » (tracé un peu moins court que le meilleur, bien moins d'états)
Tv.ORE_CAP = 3000                -- états développés au plus par recherche de détour (au-delà : abandon, on garde le tracé de base ; mesuré : 11 millions d'instructions sans plafond)
Tv.PROOF_AFTER = 0               -- états développés avant la preuve rapide d'impossibilité (remplissage de tuiles) ; 0 : éteinte (mesuré : le remplissage d'une boîte de 120 coûtait 10 M
                                    -- d'instructions, plus que les 6 000 états du budget ; Tv.unreachable reste disponible)
Tv.DETOUR_MIN = 6                -- détour toujours permis pour éviter un gisement (tuiles)
Tv.DETOUR_RATIO = 0.5            -- ... ou la moitié de la longueur de base
Tv.DETOUR_MAX = 24               -- ... mais jamais plus de 24 tuiles
Tv.POLE_EXTRA = 2                -- poteaux de plus acceptés pour éviter un gisement
Tv.NEAR_DETOUR = 8               -- détour (tuiles) au-delà duquel la recherche avec souterrains est lancée
Tv.GAME_WEIGHT = 1.25            -- heuristique des tracés EN JEU (script/team/traversee.lua) : un peu plus long que le meilleur, bien moins d'états
Tv.PLAN_BUDGET = 4000            -- états développés au plus par plan (tous les appels d'un même projet au même tick)
Tv.CAP = 24000                   -- états développés au plus par recherche (8 états possibles par tuile)

--- Compteurs de diagnostic (jamais lus par une décision).
Tv.STATS = { routes = 0, searches = 0, expanded = 0, jumps = 0, ore_detours = 0, ore_crossed = 0, refused = 0 }

local D4 = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } } -- N, E, S, O (index 1 à 4)
local CODE = { 0, 2, 4, 6 }                               -- code du jeu de chaque index
local function didx_of_code(c) return c / 2 + 1 end
Tv.D4, Tv.CODE = D4, CODE

--- Preuve RAPIDE et exacte d'impossibilité : remplissage de TUILES depuis `s` (4 voisins et, avec `maxd`, une arête de sortie de paire
--- vers chaque tuile libre à 2..maxd, puis la tuile suivante), sans les sens ni la règle des souterrains de même axe : il contient le graphe
--- de l'A*. Rend vrai quand `t` n'est pas atteint (l'A* rendrait « aucun chemin »). `inb(x, y)` : tuile permise (boîte, ellipse).
function Tv.unreachable(s, t, cost, maxd, inb)
  local seen = { [Tv.tkey(s.x, s.y)] = true }
  local q, h = { s.x, s.y }, 1
  local function push(x, y)
    local k = Tv.tkey(x, y)
    if not seen[k] and inb(x, y) and (cost(x, y) ~= nil or (x == t.x and y == t.y)) then
      seen[k] = true
      q[#q + 1] = x
      q[#q + 1] = y
    end
  end
  while h <= #q do
    local x, y = q[h], q[h + 1]
    h = h + 2
    if x == t.x and y == t.y then return false end
    for _, d in ipairs(D4) do
      push(x + d[1], y + d[2])
      if maxd then
        for kk = 2, maxd do
          local mx, my = x + kk * d[1], y + kk * d[2]
          if cost(mx, my) ~= nil and inb(mx, my) and not (mx == t.x and my == t.y) then push(mx + d[1], my + d[2]) end
        end
      end
    end
  end
  return true
end

local floor = math.floor
local function tk(x, y) return (x + 1048576) * 2097152 + (y + 1048576) end -- même clé que P.tkey
Tv.tkey = tk

-- Tas binaire (min) à départage (f, h, clé).
local function less(a, b) return a.f < b.f or (a.f == b.f and (a.h < b.h or (a.h == b.h and a.k < b.k))) end
local function hpush(h, n)
  h[#h + 1] = n
  local i = #h
  while i > 1 do
    local p = floor(i / 2)
    if less(h[p], h[i]) or not less(h[i], h[p]) then break end
    h[p], h[i] = h[i], h[p]
    i = p
  end
end
local function hpop(h)
  local top = h[1]
  local last = h[#h]
  h[#h] = nil
  if #h > 0 then
    h[1] = last
    local i = 1
    while true do
      local l, r, m = 2 * i, 2 * i + 1, i
      if l <= #h and less(h[l], h[m]) then m = l end
      if r <= #h and less(h[r], h[m]) then m = r end
      if m == i then break end
      h[m], h[i] = h[i], h[m]
      i = m
    end
  end
  return top
end

--- Borne du détour accepté pour éviter un gisement : longueur de base + max(DETOUR_MIN, moitié), au plus + DETOUR_MAX.
function Tv.detour_limit(base_len)
  local extra = math.max(Tv.DETOUR_MIN, floor(base_len * Tv.DETOUR_RATIO))
  if extra > Tv.DETOUR_MAX then extra = Tv.DETOUR_MAX end
  return base_len + extra
end

--- Direction (index 1 à 4) de l'axe dominant de a vers b (départage : l'axe des x).
local function dominant(a, b)
  local dx, dy = b.x - a.x, b.y - a.y
  if math.abs(dx) >= math.abs(dy) then return dx >= 0 and 2 or 4 end
  return dy >= 0 and 3 or 1
end

---------------------------------------------------------------------------------------------------
-- 1. Une recherche (surcoût de gisement fixé)
---------------------------------------------------------------------------------------------------
-- État : (tuile, sens d'arrivée d, m) ; m = 1 juste après une sortie de souterrain (la tuile suivante est droite ou une entrée).
-- Rend la liste d'éléments { x, y, d, ug } dans l'ordre du flux (d : index 1 à 4 ; ug : nil | "input" | "output"), le nombre d'états
-- développés, ou nil, raison.
local TURNS = { 0, -1, 1 }

-- use_ug : recherche AVEC paires souterraines (états (tuile, sens, tout droit imposé), jusqu'à 8 par tuile) ; sans : recherche de TUILES (un état
-- par tuile, comme P.belt_route ; seule la tuile d'arrivée garde son sens). Mesuré : la recherche avec sens coûtait 1,6 à 5 fois P.belt_route.
-- ctx.budget = { left } : états développés restants, PARTAGÉS entre les recherches d'un même plan (épuisé : « trop long »).
local function search(s, t, td, bounds, cost, ctx, pen, lim, wt, capn, use_ug)
  local ore = ctx.ore
  local maxd = use_ug and ctx.maxd or nil
  if maxd ~= nil and maxd < 2 then maxd = nil end
  local weight = wt or ctx.weight or 1
  local cap = capn or ctx.max or Tv.CAP
  local budget = ctx.budget
  local sd = ctx.sd or dominant(s, t)
  -- coût brut et gisement de chaque tuile : demandés UNE fois par tuile et par tracé (tables partagées par les recherches du tracé)
  local mc, mo = ctx.memo_c, ctx.memo_o
  local function raw(x, y)
    local k = tk(x, y)
    local c = mc[k]
    if c == nil then
      c = cost(x, y) or false
      mc[k] = c
      mo[k] = (c ~= false and ore and ore(x, y)) and true or false
    end
    return c
  end
  local function free(x, y) return raw(x, y) ~= false end
  local function tc(x, y)
    local c = raw(x, y)
    if pen > 0 and mo[tk(x, y)] then c = c + pen end
    return c
  end
  local x0, y0, x1, y1 = bounds.x0, bounds.y0, bounds.x1, bounds.y1
  local sx, sy, tx, ty = s.x, s.y, t.x, t.y
  local function inb(x, y)
    if x < x0 or x > x1 or y < y0 or y > y1 then return false end
    -- ellipse de la borne de détour : une tuile hors d'elle ne se trouve sur aucun tracé d'au plus `lim` tuiles
    if lim and math.abs(x - sx) + math.abs(y - sy) + math.abs(x - tx) + math.abs(y - ty) > lim - 1 then return false end
    return true
  end
  local function hh(x, y) return (math.abs(x - tx) + math.abs(y - ty)) * weight end
  local function key(x, y, d, m)
    if not maxd and not (x == tx and y == ty) then return tk(x, y) * 10 end
    return tk(x, y) * 10 + (d - 1) * 2 + m
  end
  local open, g, closed, pk, ppx, ppy, pnd, pjm, expanded
  local R = ctx.resume
  if R then
    -- lot RESEAU-GRAPHE : reprise d'une recherche par tranches (état rendu par la passe d'avant : nombres et tables seulement)
    open, g, closed, expanded = R.open, R.g, R.closed, R.expanded
    pk, ppx, ppy, pnd, pjm = R.pk, R.ppx, R.ppy, R.pnd, R.pjm
  else
    open, g, closed, expanded = {}, {}, {}, 0
    pk, ppx, ppy, pnd, pjm = {}, {}, {}, {}, {} -- parent : état, tuile, sens du tapis posé là, écart d'une paire (0 : tapis simple)
    local k0 = key(sx, sy, sd, 0)
    g[k0] = 0
    hpush(open, { x = sx, y = sy, d = sd, m = 0, f = hh(sx, sy), h = hh(sx, sy), k = k0 })
  end
  local slice_end = ctx.slice and (expanded + ctx.slice) or nil
  local pass = ctx.pass -- lot TRANCHES-FOREUSES : { left } = états à développer encore dans CETTE passe, partagés par toutes les recherches de la passe
  local function relax(cur, nx, ny, nd, nm, c, jm)
    if not inb(nx, ny) then return end
    if not (free(nx, ny) or (nx == tx and ny == ty)) then return end
    local nk = key(nx, ny, nd, nm)
    if closed[nk] then return end
    local ng = g[cur.k] + c
    local old = g[nk]
    if old == nil or ng < old then
      g[nk] = ng
      pk[nk], ppx[nk], ppy[nk], pnd[nk], pjm[nk] = cur.k, cur.x, cur.y, jm == 0 and nd or cur.d, jm
      local h = hh(nx, ny)
      hpush(open, { x = nx, y = ny, d = nd, m = nm, f = ng + h, h = h, k = nk })
    end
  end
  while #open > 0 do
    -- tranche épuisée : l'état part tel quel à la passe suivante (ctx.resume), `expanded` cumule les passes (plafond `cap` sur le total)
    if slice_end and expanded >= slice_end then
      return nil, "pending", expanded, { open = open, g = g, closed = closed, expanded = expanded, pk = pk, ppx = ppx, ppy = ppy, pnd = pnd, pjm = pjm }
    end
    if pass and pass.left <= 0 then -- lot TRANCHES-FOREUSES : la passe est épuisée (tranche partagée entre les recherches du tracé)
      return nil, "pending", expanded, { open = open, g = g, closed = closed, expanded = expanded, pk = pk, ppx = ppx, ppy = ppy, pnd = pnd, pjm = pjm }
    end
    local cur = hpop(open)
    if not closed[cur.k] then
      closed[cur.k] = true
      expanded = expanded + 1
      if pass then pass.left = pass.left - 1 end
      if expanded > cap then return nil, "trop long", expanded end
      if budget then
        budget.left = budget.left - 1
        if budget.left < 0 then return nil, "trop long", expanded end
      end
      if expanded == Tv.PROOF_AFTER and pen == 0 and not ctx.slice and Tv.unreachable(s, t, cost, maxd, inb) then return nil, "aucun chemin", expanded end
      if cur.x == tx and cur.y == ty then
        if cur.d ~= ((td + 1) % 4) + 1 and (cur.m == 0 or cur.d == td) then
          local rev = { { x = tx, y = ty, d = td } }
          local k = cur.k
          while pk[k] do
            local px, py, nd, kk = ppx[k], ppy[k], pnd[k], pjm[k]
            if kk == 0 then
              rev[#rev + 1] = { x = px, y = py, d = nd }
            else
              local dv = D4[nd]
              rev[#rev + 1] = { x = px + kk * dv[1], y = py + kk * dv[2], d = nd, ug = "output" }
              rev[#rev + 1] = { x = px, y = py, d = nd, ug = "input" }
            end
            k = pk[k]
          end
          local out = {}
          for a = #rev, 1, -1 do out[#out + 1] = rev[a] end
          return out, expanded
        end
      -- tracé par tranches (ctx.resume) : entre deux passes le moteur a pu occuper cette tuile, relue libre à l'empilement. L'état est abandonné : sinon
      -- `false` entre dans le prix (plantage de la partie neuve du 9/11 à 15 min, en `relax`)
      elseif free(cur.x, cur.y) then
        local cx, cy, cd = cur.x, cur.y, cur.d
        local ctc = tc(cx, cy)
        -- tapis posé ici, tout droit ou en virage (jamais demi-tour ; tout droit imposé après une sortie de souterrain)
        for ti = 1, 3 do
          local turn = TURNS[ti]
          if turn == 0 or cur.m == 0 then
            local nd = ((cd - 1 + turn) % 4) + 1
            local dv = D4[nd]
            relax(cur, cx + dv[1], cy + dv[2], nd, 0, ctc, 0)
          end
        end
        -- paire de souterrains : entrée ici (on y arrive tout droit), sortie k tuiles plus loin, puis tout droit
        -- (jamais depuis une tuile dont la suivante est libre et sans gisement : marcher jusqu'au bord de l'obstacle puis sauter coûte pareil,
        -- avec un trou plus court ; mesuré : sans cette règle, 8 arêtes de plus par état)
        if maxd then
          local dv = D4[cd]
          local nxt_x, nxt_y = cx + dv[1], cy + dv[2]
          if not free(nxt_x, nxt_y) or mo[tk(nxt_x, nxt_y)] then
            local axis = (cd == 1 or cd == 3) and 1 or 2
            local ok_span = true
            for kk = 1, maxd do
              local mx, my = cx + kk * dv[1], cy + kk * dv[2]
              if kk >= 2 and ok_span and free(mx, my) and not (mx == tx and my == ty) then
                relax(cur, mx + dv[1], my + dv[2], cd, 1, ctc + tc(mx, my) + (kk - 1) + Tv.UG_COST + kk * 0.001, kk)
              end
              -- les tuiles sous lesquelles la paire passe : tout sauf une pièce souterraine de même axe
              if ctx.ug_axis then
                local a = ctx.ug_axis(mx, my)
                if a ~= nil and (a == true or a == axis) then ok_span = false end
              end
              if not inb(mx, my) then ok_span = false end
            end
          end
        end
      end
    end
  end
  return nil, "aucun chemin", expanded
end

-- Statistiques d'un tracé : tuiles de gisement couvertes par une pièce, nombre de paires.
-- CAUSE d'un refus (journal) : remplissage de tuiles depuis `s` (mêmes arêtes que Tv.unreachable). Rend { reached (tuiles atteintes), near = {x, y}
--- (la tuile atteinte la plus proche de `t`, départage y puis x), dist (Manhattan de near à t), block = {x, y} ou nil (la tuile voisine de near, vers
--- t, qui arrête le tracé : interdite, ou hors de la boîte), outside (vrai : block est hors de la boîte) }.
function Tv.diagnose(s, t, bounds, cost, maxd)
  local function inb(x, y) return x >= bounds.x0 and x <= bounds.x1 and y >= bounds.y0 and y <= bounds.y1 end
  local seen = { [tk(s.x, s.y)] = true }
  local q, h = { s.x, s.y }, 1
  local best, bd = { x = s.x, y = s.y }, math.abs(s.x - t.x) + math.abs(s.y - t.y)
  local function push(x, y)
    local k = tk(x, y)
    if not seen[k] and inb(x, y) and cost(x, y) ~= nil then seen[k] = true; q[#q + 1] = x; q[#q + 1] = y end
  end
  while h <= #q do
    local x, y = q[h], q[h + 1]
    h = h + 2
    local d = math.abs(x - t.x) + math.abs(y - t.y)
    if d < bd or (d == bd and (y < best.y or (y == best.y and x < best.x))) then best, bd = { x = x, y = y }, d end
    for _, dv in ipairs(D4) do
      push(x + dv[1], y + dv[2])
      if maxd then
        for kk = 2, maxd do
          local mx, my = x + kk * dv[1], y + kk * dv[2]
          if inb(mx, my) and cost(mx, my) ~= nil then push(mx + dv[1], my + dv[2]) end
        end
      end
    end
  end
  -- voisin de `best` vers `t` qui n'est pas atteint : l'axe le plus éloigné d'abord
  local dx, dy = t.x - best.x, t.y - best.y
  local order = {}
  local function sgn(v) return v > 0 and 1 or (v < 0 and -1 or 0) end
  if math.abs(dx) >= math.abs(dy) then
    order = { { sgn(dx), 0 }, { 0, sgn(dy) } }
  else
    order = { { 0, sgn(dy) }, { sgn(dx), 0 } }
  end
  local block, outside
  for _, o in ipairs(order) do
    if o[1] ~= 0 or o[2] ~= 0 then
      local bx, by = best.x + o[1], best.y + o[2]
      if not seen[tk(bx, by)] then block, outside = { x = bx, y = by }, not inb(bx, by) break end
    end
  end
  return { reached = (#q) / 2, near = best, dist = bd, block = block, outside = outside }
end

-- Longueur PHYSIQUE d'un tracé en tuiles (trous des paires compris).
local function phys(tiles)
  local n = 1
  for i = 2, #tiles do n = n + math.abs(tiles[i].x - tiles[i - 1].x) + math.abs(tiles[i].y - tiles[i - 1].y) end
  return n
end

-- Traversée d'un gisement en ligne droite : sur chaque tronçon droit, la pièce qui précède le gisement devient l'ENTRÉE d'une paire dont la
-- SORTIE est la pièce la plus lointaine permise (écart <= maxd, tuile suivante droite), de préférence hors gisement ; les pièces d'entre
-- elles disparaissent (le gisement reste libre dessous). Rend la liste (la même s'il n'y a rien à gagner).
local function compress(el, ctx)
  local ore, maxd = ctx.ore, ctx.maxd
  local out, n, i = {}, #el, 1
  local function adj(a, b, d) local dv = D4[d]; return a.x + dv[1] == b.x and a.y + dv[2] == b.y end
  local changed = false
  while i <= n do
    local e, nx, prev = el[i], el[i + 1], out[#out]
    local took = false
    if not e.ug and nx and not nx.ug and prev and prev.d == e.d and adj(prev, e, prev.d) and adj(e, nx, e.d) and ore(nx.x, nx.y) then
      local d = e.d
      local dv = D4[d]
      local axis = (d == 1 or d == 3) and 1 or 2
      -- dernière pièce alignée sur la droite de e
      local last = i
      while last < n and not el[last + 1].ug and el[last + 1].x == e.x + (last + 1 - i) * dv[1] and el[last + 1].y == e.y + (last + 1 - i) * dv[2]
        and el[last].d == d do
        last = last + 1
      end
      local best_j, best_free
      for j = math.min(i + maxd, last - 1), i + 2, -1 do
        local after = el[j + 1]
        if after and after.d == d and j + 1 <= last then
          local ok, gain = true, 0
          for m = i + 1, j - 1 do
            if ore(el[m].x, el[m].y) then gain = gain + 1 end
            if ctx.ug_axis then
              local a = ctx.ug_axis(el[m].x, el[m].y)
              if a ~= nil and (a == true or a == axis) then ok = false end
            end
          end
          if ok and gain >= 1 then
            if not ore(el[j].x, el[j].y) then best_free = best_free or j end
            best_j = best_j or j
          end
        end
      end
      local j = best_free or best_j
      if j then
        out[#out + 1] = { x = e.x, y = e.y, d = d, ug = "input" }
        out[#out + 1] = { x = el[j].x, y = el[j].y, d = d, ug = "output" }
        i = j + 1
        took, changed = true, true
      end
    end
    if not took then
      out[#out + 1] = e
      i = i + 1
    end
  end
  if not changed then return el end
  return out
end
Tv.compress = compress

local function measure(tiles, ore)
  local on, jumps = 0, 0
  for _, e in ipairs(tiles) do
    if ore and ore(e.x, e.y) then on = on + 1 end
    if e.ug == "input" then jumps = jumps + 1 end
  end
  return on, jumps
end

---------------------------------------------------------------------------------------------------
-- 2. Le tracé
---------------------------------------------------------------------------------------------------
--- Tracé d'un tapis de la tuile `s` à la tuile `t` (incluses) dans `bounds` { x0, y0, x1, y1 } (inclus). cost(x, y) -> nil (interdit
--- pour une pièce) ou coût >= 1 (même contrat que P.belt_route). t_dir : code du jeu de la dernière tuile.
--- ctx.phase_slice (lot TRANCHES-FOREUSES) : le MÊME tracé (mêmes phases A, B et détour de gisement, même résultat qu'en un appel) cherché PAR PASSES
---   d'au plus phase_slice états développés ; ctx.phase_state : l'état rendu par la passe d'avant (nil à la première) ; une passe qui n'a pas
---   fini rend nil, "pending", état (tables de nombres seulement : sauvegardable). Le budget ctx.budget n'est lu qu'à la première passe
---   (son reste voyage dans l'état). Les phases finies sont REJOUÉES (résultat gardé), pas recalculées.
--- ctx (facultatif) : maxd (portée des souterrains, nil : aucun), ore(x, y) -> bool (tuile de gisement), ug_axis(x, y) -> nil | true | 1
---   (N/S) | 2 (E/O) (pièce souterraine à cet endroit), sd (sens d'arrivée en s, code du jeu ; défaut : axe dominant), weight (heuristique,
---   défaut 1), max (états développés au plus), nature(x, y) -> texte ou nil (journal).
--- Rend tiles = liste { x, y, dir (code du jeu), ug = nil | "input" | "output" } dans l'ordre du flux, info = { len, ore, jumps, base_len,
--- base_ore, pen, expanded, searches, jump_list = { { x1, y1, x2, y2, dir, k, what } } }, ou nil, raison.
function Tv.route(s, t, t_dir, bounds, cost, ctx)
  ctx = ctx or {}
  Tv.STATS.routes = Tv.STATS.routes + 1
  if not cost(s.x, s.y) then return nil, "depart" end
  if not cost(t.x, t.y) then return nil, "arrivee" end
  local td = didx_of_code(t_dir)
  local ctx2 = { ore = ctx.ore, maxd = ctx.maxd, ug_axis = ctx.ug_axis, weight = ctx.weight, max = ctx.max, nature = ctx.nature,
    sd = ctx.sd and didx_of_code(ctx.sd) or nil, memo_c = {}, memo_o = {}, slice = ctx.slice, resume = ctx.resume }
 ctx2.budget = ctx.budget
  -- lot TRANCHES-FOREUSES : tracé en passes (voir l'en-tête) ; PS = état gardé d'une passe à l'autre
  local PS
  if ctx.phase_slice then
    PS = ctx.phase_state or { done = {}, bl = ctx.budget and ctx.budget.left or nil, capn = {} }
    ctx2.pass = { left = ctx.phase_slice }
    ctx2.budget = PS.bl and { left = PS.bl } or nil
  end
  local expanded, searches = 0, 0
  -- (compteur de diagnostic ; par passes : seulement le travail de CETTE passe, pas les phases rejouées)
  -- et le reste du budget revient à l'appelant (comme en un seul appel : ses recherches le décomptent en place)
  local function stat_expanded()
    Tv.STATS.expanded = Tv.STATS.expanded + (PS and (ctx.phase_slice - ctx2.pass.left) or expanded)
    if PS and ctx.budget and PS.bl then ctx.budget.left = PS.bl end
  end
  local function run(pen, lim, use_ug, name)
    searches = searches + 1
    if PS then
      local d = PS.done[name]
      if d then expanded = expanded + d.used; return d.el, d.n end -- phase finie à une passe d'avant : rejouée
      ctx2.resume = (PS.cur == name) and PS.cs or nil
    end
    local el, n, used4, state
    if pen > 0 then
      local _u; el, n, _u, state = search(s, t, td, bounds, cost, ctx2, pen, lim, math.max(ctx.weight or 1, Tv.ORE_WEIGHT), math.min(ctx.max or Tv.CAP, Tv.ORE_CAP), false)
    else
      -- la phase A d'un plan qui dispose de souterrains n'use que la moitié du budget restant : un mur sans fin la ferait tout dépenser avant la phase B
      local capn
      if PS and PS.capn[name] then capn = PS.capn[name] -- (par passes : fixé au début de la phase, le budget a baissé depuis)
      elseif not use_ug and ctx2.maxd and ctx2.maxd >= 2 and ctx2.budget then
        capn = math.max(100, math.floor(ctx2.budget.left / 2))
        if ctx.max and ctx.max < capn then capn = ctx.max end -- lot TRAVERSEE-CAP : la moitié du budget BORNE le plafond de l'appelant, ne le remplace pas
        if PS then PS.capn[name] = capn end
      end
      el, n, used4, state = search(s, t, td, bounds, cost, ctx2, pen, lim, nil, capn, use_ug)
    end
    Tv.STATS.searches = Tv.STATS.searches + 1
    local used = type(n) == "number" and n or (type(used4) == "number" and used4 or 0)
    if PS then
      PS.bl = ctx2.budget and ctx2.budget.left or nil
      if n == "pending" then
        PS.cur, PS.cs = name, state
        return nil, "pending", "pending"
      end
      PS.cur, PS.cs = nil, nil
      PS.done[name] = { el = el, n = n, used = used }
    end
    expanded = expanded + used
    return el, n, state
  end
  -- Phase A : recherche de TUILES (le prix de P.belt_route). Phase B (avec paires souterraines) seulement si la phase A échoue ou impose un détour de
  -- plus de Tv.NEAR_DETOUR tuiles sur la distance à vol d'oiseau : un obstacle contournable de près ne mérite pas de souterrain.
  local base, why, pending_state
  local a_none = false -- la phase A a PROUVÉ qu'aucun tracé de surface n'existe (la base vient alors de la phase B)
  local manh = math.abs(s.x - t.x) + math.abs(s.y - t.y) + 1
  if ctx.slice or ctx.resume then
    -- lot RESEAU-GRAPHE : recherche PAR TRANCHES (tronc de bus) : une seule recherche reprenable, avec les souterrains s'il y en a ; pas de phase A
    base, why, pending_state = run(0, nil, true)
    if not base and why == "pending" then
      stat_expanded()
      return nil, "pending", pending_state
    end
  else
    base, why = run(0, nil, false, "A")
    if PS and why == "pending" then stat_expanded(); return nil, "pending", PS end
    a_none = not base and why == "aucun chemin"
    if ctx2.maxd and ctx2.maxd >= 2 and (not base or phys(base) > manh + Tv.NEAR_DETOUR) then
      local b2, why2 = run(0, nil, true, "B")
      if PS and why2 == "pending" then stat_expanded(); return nil, "pending", PS end
      if b2 then base, why = b2, nil elseif not base then why = why2 end
    end
  end
  if not base then
    Tv.STATS.refused = Tv.STATS.refused + 1
    stat_expanded()
    return nil, why
  end
  local base_ore = measure(base, ctx.ore)
  local best, best_pen, best_ore = base, 0, base_ore
  local base_phys = phys(base)
  if ctx.ore and base_ore > 0 and not ctx.no_detour then
    local limit = Tv.detour_limit(base_phys)
    -- (a_none : les recherches de détour, sans souterrain, parcourent le graphe de la phase A réduit à l'ellipse : elles échoueraient toutes)
    for _, pen in ipairs(a_none and {} or Tv.ORE_STEPS) do
      local el, why3 = run(pen, limit, false, "O" .. pen)
      if PS and why3 == "pending" then stat_expanded(); return nil, "pending", PS end
      if el and phys(el) <= limit then
        local on = measure(el, ctx.ore)
        if on < best_ore or (on == best_ore and phys(el) < phys(best)) then best, best_pen, best_ore = el, pen, on end
        if on == 0 then break end
      end
    end
    if best ~= base then
      if best_ore < base_ore then Tv.STATS.ore_detours = Tv.STATS.ore_detours + 1 end
    end
    if best_ore > 0 then Tv.STATS.ore_crossed = Tv.STATS.ore_crossed + 1 end
  end
  stat_expanded()
  -- traversée en ligne droite du gisement restant, par paires de portée maximale
  if ctx2.maxd and ctx2.maxd >= 2 and ctx.ore and best_ore > 0 then
    local c = compress(best, ctx2)
    if c ~= best then
      local on2 = measure(c, ctx.ore)
      if on2 < best_ore then best, best_ore = c, on2 end
    end
  end
  -- sortie au format du jeu
  local tiles, jump_list = {}, {}
  local open_in
  for _, e in ipairs(best) do
    tiles[#tiles + 1] = { x = e.x, y = e.y, dir = CODE[e.d], ug = e.ug }
    if e.ug == "input" then open_in = e end
    if e.ug == "output" and open_in then
      local k = math.abs(e.x - open_in.x) + math.abs(e.y - open_in.y)
      local dv = D4[e.d]
      local what, seen = {}, {}
      if ctx.nature then
        for i = 1, k - 1 do
          local n = ctx.nature(open_in.x + i * dv[1], open_in.y + i * dv[2])
          if n and not seen[n] then seen[n] = #what + 1; what[#what + 1] = { n, 0 } end
          if n then what[seen[n]][2] = what[seen[n]][2] + 1 end
        end
      end
      jump_list[#jump_list + 1] = { x1 = open_in.x, y1 = open_in.y, x2 = e.x, y2 = e.y, dir = CODE[e.d], k = k, what = what }
      open_in = nil
    end
  end
  Tv.STATS.jumps = Tv.STATS.jumps + #jump_list
  local on, jumps = measure(best, ctx.ore)
  return tiles, { len = #best, phys = phys(best), ore = on, jumps = jumps, base_len = #base, base_phys = base_phys, base_ore = base_ore, pen = best_pen, expanded = expanded,
    searches = searches, jump_list = jump_list }
end

---------------------------------------------------------------------------------------------------
-- 3. Entités et preuve
---------------------------------------------------------------------------------------------------
--- Entités d'un tracé. names = { belt, ug } ; role : rôle des pièces (« liaison-tapis », « tapis-foreuses »…). Centres de tuile (+ 0,5) ;
--- une pièce souterraine porte type = "input" | "output" (convention de build.lua : fantôme, retournement au ravivage).
function Tv.entities(tiles, names, role)
  local out = {}
  for _, t in ipairs(tiles) do
    if t.ug then
      out[#out + 1] = { name = names.ug, x = t.x + 0.5, y = t.y + 0.5, dir = t.dir, type = t.ug, role = role }
    else
      out[#out + 1] = { name = names.belt, x = t.x + 0.5, y = t.y + 0.5, dir = t.dir, role = role }
    end
  end
  return out
end

--- Le même tracé SANS souterrain : toutes les tuiles entre une entrée et sa sortie deviennent des tapis droits. Sert aux preuves qui
--- supposent un tapis continu (Li.verify de shared/team/liaison.lua).
function Tv.virtual_belts(tiles)
  local out = {}
  local i = 1
  while i <= #tiles do
    local e = tiles[i]
    if e.ug == "input" then
      local o = tiles[i + 1]
      local dx = o.x > e.x and 1 or (o.x < e.x and -1 or 0)
      local dy = o.y > e.y and 1 or (o.y < e.y and -1 or 0)
      local x, y = e.x, e.y
      while true do
        out[#out + 1] = { x = x, y = y, dir = e.dir }
        if x == o.x and y == o.y then break end
        x, y = x + dx, y + dy
      end
      i = i + 2
    else
      out[#out + 1] = { x = e.x, y = e.y, dir = e.dir }
      i = i + 1
    end
  end
  return out
end

--- Preuve d'un tracé. s, t = { x, y } ; maxd ; cost(x, y) (nil : interdit) ; ctx.ug_axis facultatif. Rend la liste des écarts (vide : juste).
function Tv.verify(tiles, s, t, t_dir, maxd, cost, ctx)
  ctx = ctx or {}
  local bad = {}
  local n = #tiles
  if n == 0 then return { "tracé vide" } end
  if tiles[1].x ~= s.x or tiles[1].y ~= s.y then bad[#bad + 1] = "ne part pas de la tuile de départ" end
  if tiles[n].x ~= t.x or tiles[n].y ~= t.y then bad[#bad + 1] = "n'arrive pas a la tuile d'arrivee" end
  if tiles[n].dir ~= t_dir then bad[#bad + 1] = "derniere tuile mal tournee" end
  if tiles[n].ug then bad[#bad + 1] = "la derniere tuile est un souterrain" end
  local seen = {}
  local ugs = {} -- pièces souterraines du tracé : clé -> axe
  for _, e in ipairs(tiles) do
    local k = tk(e.x, e.y)
    if seen[k] then bad[#bad + 1] = string.format("deux pieces sur (%d, %d)", e.x, e.y) end
    seen[k] = true
    if cost and not cost(e.x, e.y) then bad[#bad + 1] = string.format("piece sur une tuile interdite (%d, %d)", e.x, e.y) end
    if e.ug then ugs[k] = (e.dir == 0 or e.dir == 4) and 1 or 2 end
  end
  local i = 1
  while i <= n do
    local e = tiles[i]
    local dv = D4[didx_of_code(e.dir)]
    if not dv then bad[#bad + 1] = "direction inconnue" return bad end
    if e.ug == "input" then
      local o = tiles[i + 1]
      if not (o and o.ug == "output") then bad[#bad + 1] = string.format("entree (%d, %d) sans sortie juste apres", e.x, e.y) return bad end
      local k = math.abs(o.x - e.x) + math.abs(o.y - e.y)
      if o.dir ~= e.dir then bad[#bad + 1] = "entree et sortie de sens differents" end
      if not (maxd and k >= 2 and k <= maxd) then bad[#bad + 1] = string.format("ecart %d hors de 2..%s", k, tostring(maxd)) end
      if not ((o.x - e.x) * dv[2] == 0 and (o.y - e.y) * dv[1] == 0 and (o.x - e.x) * dv[1] + (o.y - e.y) * dv[2] == k) then
        bad[#bad + 1] = string.format("la sortie (%d, %d) n'est pas dans l'axe de l'entree (%d, %d)", o.x, o.y, e.x, e.y)
      end
      -- aucune pièce souterraine de même axe dessous
      local axis = (e.dir == 0 or e.dir == 4) and 1 or 2
      for j = 1, k - 1 do
        local gx, gy = e.x + j * dv[1], e.y + j * dv[2]
        local a = ugs[tk(gx, gy)]
        if a == axis then bad[#bad + 1] = string.format("souterrain de meme axe sous la paire en (%d, %d)", gx, gy) end
        if ctx.ug_axis then
          local b = ctx.ug_axis(gx, gy)
          if b ~= nil and (b == true or b == axis) then bad[#bad + 1] = string.format("souterrain existant de meme axe sous la paire en (%d, %d)", gx, gy) end
        end
      end
      -- entrée droite : la tuile d'avant mène à l'entrée dans son sens
      local p = tiles[i - 1]
      if p then
        if p.ug == "output" then
          -- sortie suivie d'une entrée : la tuile qui suit la sortie est l'entrée, tout droit
          if not (p.x + D4[didx_of_code(p.dir)][1] == e.x and p.y + D4[didx_of_code(p.dir)][2] == e.y and p.dir == e.dir) then
            bad[#bad + 1] = string.format("entree (%d, %d) non droite apres la sortie", e.x, e.y)
          end
        else
          local pv = D4[didx_of_code(p.dir)]
          if not (p.x + pv[1] == e.x and p.y + pv[2] == e.y and p.dir == e.dir) then
            bad[#bad + 1] = string.format("entree (%d, %d) non droite", e.x, e.y)
          end
        end
      end
      i = i + 2
      -- tuile après la sortie : droite
      local nx = tiles[i]
      if nx then
        if not (o.x + dv[1] == nx.x and o.y + dv[2] == nx.y) then bad[#bad + 1] = string.format("tuile apres la sortie (%d, %d) non droite", o.x, o.y) end
        if not nx.ug and nx.dir ~= e.dir then bad[#bad + 1] = string.format("virage juste apres la sortie (%d, %d)", o.x, o.y) end
      end
    else
      if e.ug == "output" then bad[#bad + 1] = string.format("sortie (%d, %d) sans entree", e.x, e.y) end
      local nx = tiles[i + 1]
      if nx then
        if not (e.x + dv[1] == nx.x and e.y + dv[2] == nx.y) then bad[#bad + 1] = string.format("la tuile (%d, %d) ne mene pas a la suivante", e.x, e.y) end
      end
      i = i + 1
    end
  end
  return bad
end

---------------------------------------------------------------------------------------------------
-- 4. Poteaux
---------------------------------------------------------------------------------------------------
--- Chaîne de poteaux qui évite les gisements. chain(a, b, free) -> liste de poteaux ou nil (la fonction de chaîne de l'appelant, ex.
--- P.pole_chain avec ses autres arguments) ; ore(x, y) -> bool pour un CENTRE de poteau (le mod passe floor des coordonnées).
--- Rend la chaîne, et ce qui a été fait : "libre" (rien sur le gisement), "evitee" (autre chaîne sans gisement), "traverse" (pas de
--- chaîne sans gisement dans la borne), "aucune".
function Tv.pole_chain(chain, a, b, free, ore, extra)
  local base = chain(a, b, free)
  if not ore then return base, base and "libre" or "aucune", 0 end
  local function on_ore(list)
    local n = 0
    for _, c in ipairs(list or {}) do if ore(c.x, c.y) then n = n + 1 end end
    return n
  end
  local n0 = on_ore(base)
  if base and n0 == 0 then return base, "libre", 0 end
  local function free2(x, y) return free(x, y) and not ore(x, y) end
  local alt = chain(a, b, free2)
  extra = extra or Tv.POLE_EXTRA
  if alt and (not base or #alt <= #base + extra) then return alt, "evitee", n0 end
  return base, base and "traverse" or "aucune", n0
end

--- Tuile d'un poteau contre un bras : préfère une tuile sans gisement. pick(free) -> tx, ty ou nil (ex. Li.pole_tile avec site et taken).
function Tv.pole_tile(pick, free, ore)
  if ore then
    local x, y = pick(function(px, py) return free(px, py) and not ore(px, py) end)
    if x then return x, y end
  end
  return pick(free)
end

---------------------------------------------------------------------------------------------------
-- 5. Journal
---------------------------------------------------------------------------------------------------
local DIRNAME = { [0] = "N", [2] = "E", [4] = "S", [6] = "O" }
Tv.DIRNAME = DIRNAME

--- Ligne [FO-TRAVERSEE] d'un REFUS : who comme Tv.lines, why (raison de la recherche), diag (Tv.diagnose), nature (texte de l'obstacle ou nil).
function Tv.refusal_line(who, why, diag, nature)
  local head = string.format("[FO-TRAVERSEE] %s : projet %s (%s) : ", tostring(who.team or "player"), tostring(who.project or "?"), tostring(who.kind or "tapis"))
  if not diag then return head .. "REFUS (" .. tostring(why) .. ")" end
  local what = "rien d'identifie"
  if diag.block then
    what = string.format("%s en (%d, %d)%s", nature or "obstacle", diag.block.x, diag.block.y, diag.outside and " (hors de la boite de recherche)" or "")
  end
  return string.format("%sREFUS (%s) : %d tuile(s) atteignable(s), la plus proche de l'arrivee en (%d, %d) a %d tuile(s) ; arrete par %s", head, tostring(why),
    diag.reached, diag.near.x, diag.near.y, diag.dist, what)
end

--- Lignes [FO-TRAVERSEE] d'un tracé : une par paire souterraine, une pour un détour ou un gisement couvert. who = { team, project, kind }.
function Tv.lines(who, info)
  local out = {}
  local head = string.format("[FO-TRAVERSEE] %s : projet %s (%s) : ", tostring(who.team or "player"), tostring(who.project or "?"), tostring(who.kind or "tapis"))
  for _, j in ipairs(info.jump_list or {}) do
    local w = {}
    for _, x in ipairs(j.what or {}) do w[#w + 1] = string.format("%d %s", x[2], x[1]) end
    out[#out + 1] = string.format("%ssouterrain de (%d, %d) a (%d, %d) sens %s, %d tuile(s), franchit : %s", head, j.x1, j.y1, j.x2, j.y2,
      DIRNAME[j.dir] or "?", j.k - 1, #w > 0 and table.concat(w, ", ") or "rien de particulier")
  end
  if (info.base_ore or 0) > 0 then
    if (info.ore or 0) < info.base_ore then
      out[#out + 1] = string.format("%sgisement evite : %d tuile(s) couverte(s) au lieu de %d, trace de %d tuile(s) au lieu de %d (detour +%d, surcout %d)",
        head, info.ore, info.base_ore, info.phys, info.base_phys, info.phys - info.base_phys, info.pen)
    else
      out[#out + 1] = string.format("%sgisement traverse : %d tuile(s) couverte(s) (aucun detour sous la borne de %d tuile(s))", head, info.ore,
        Tv.detour_limit(info.base_phys) - info.base_phys)
    end
  end
  return out
end

return Tv
