--[[
  Lot ILOTS-MURS (vague 8, 29/10) : les ÎLOTS isolés d'une équipe de PNJ (lots bâtis restés HORS du contour serré de l'enceinte,
  lot ENCEINTE3) reçoivent un petit enclos de murs et une ou deux tourelles. Règle PURE : aucune API du jeu, aucun nom d'objet ;
  lue hors jeu (tests/ilots_test.lua) et en jeu (script/team/ilots.lua, appelé par Build.space_step et le planificateur).

  Arbitrage du DC (QCU du 29/10, 20 h 50), mot pour mot : « oui hors du mur mais potentiellement l'entourer d'un mur et d'une ou 2
  tourelle » ; et, pour la dépense : « Oui, ressources d'abord ».

  1. ÎLOTS : les lots pris par un projet FINI dont le rectangle n'est pas dans le contour figé de l'enceinte sont regroupés de proche
     en proche (I.JOIN : deux lots voisins, une rue entre eux, font un seul îlot). Un îlot est IMPORTANT si sa valeur (pièces bâties de
     ses projets, une centrale comptant I.PLANT_BONUS de plus) atteint I.MIN_VALUE. Au plus I.MAX îlots par équipe ; un îlot retenu a
     son emprise FIGÉE (comme les bornes de l'enceinte) : son mur ne bouge plus.
  2. MUR : un anneau d'une tuile sur le BORD de l'emprise (la première tuile du lot), JAMAIS sur une rue : une rue qui porte un de nos
     bâtiments serait « fermée » au relevé suivant du plan directeur (script/team/build.lua, survey : seuls tapis et poteaux y sont
     tolérés), et les PNJ la contourneraient. Ouvertures : (a) là où l'anneau d'un îlot de plusieurs lots passe sur une rue intérieure
     (toute la largeur de la rue) ; (b) I.GATE tuiles au milieu de chaque côté, pour les PNJ ; (c) les tuiles déjà prises par un tapis,
     un poteau ou une autre pièce du plan (ou par du minerai, de l'eau, un bâtiment) restent ouvertes au moment du plan
     (script/team/build.lua, plan_enceinte : « reserve », « ressource », « eau », « bloque ») : les entrées de l'îlot ne sont jamais coupées.
  3. SEGMENTS : la machinerie de l'enceinte (shared/team/enceinte.lua : E.split_runs, E.next_segment, E.segment_cap) ; le premier
     tronçon posé est celui tourné vers la dernière attaque connue de l'îlot (mémoire du front), à défaut vers l'extérieur (à l'opposé
     du QG).
  4. TOURELLES : I.TURRETS tourelle, I.TURRETS_ATTACKED si l'îlot a été attaqué (score de la mémoire du front autour de lui au moins
     I.ATTACK_MIN) ; une tourelle de l'équipe déjà à moins de I.COVER tuiles de l'emprise compte ; plafond d'équipe I.TEAM_MAX.
  5. ORDRE : un îlot attaqué passe avant un îlot calme, puis la valeur, puis la distance au QG, puis la clé.
  « Les ressources d'abord » est appliqué par les appelants : murs seulement quand l'enceinte principale est complète et sans chantier,
  segments payés au plus un quart du stock (E.segment_cap) ; tourelles hors du coût de la défense (elles ne font jamais passer la
  défense avant la production), servies seulement hors « production d'abord » et au-dessus de planchers I.FLOOR_MULT fois plus hauts.

  Déterminisme : listes triées, aucun `pairs`, aucune trigonométrie.
]]

local I = {}

I.MIN_VALUE = 8         -- valeur au moins (pièces bâties) pour qu'un îlot soit « important » (une petite mine isolée de 2 pièces non)
I.PLANT_BONUS = 20      -- une centrale compte 20 pièces de plus : elle est toujours importante
I.JOIN = 4              -- tuiles : deux lots à 4 tuiles au plus (lots voisins, une rue entre eux) forment un même îlot
I.NEAR_ISLAND = 8       -- tuiles : un lot à moins de 8 tuiles d'un îlot déjà retenu n'en démarre pas un autre (deux murs dans une rue)
I.MAX = 4               -- îlots retenus au plus par équipe
I.GATE = 2              -- tuiles : ouverture des PNJ au milieu de chaque côté
I.TURRETS = 1           -- tourelles voulues pour un îlot calme
I.TURRETS_ATTACKED = 2  -- ... pour un îlot attaqué
I.TEAM_MAX = 8          -- tourelles des îlots, au plus, par équipe
I.ATTACK_MARGIN = 16    -- tuiles : une cellule de la mémoire du front compte pour l'îlot si son centre est à moins de cela de l'emprise
I.ATTACK_MIN = 200      -- centièmes (deux coups, comme shared/team/front.lua F.MIN_SCORE) : îlot « attaqué »
I.COVER = 4             -- tuiles : une tourelle de l'équipe à moins de cela de l'emprise garde déjà l'îlot
I.ACCEPT = -2           -- tuiles : centre de la tourelle (2 x 2) à 2 tuiles DANS l'emprise : la tourelle entière en dedans du mur
I.INSET = 3             -- tuiles : emplacements candidats des tourelles, en retrait des coins et des milieux de l'emprise
I.FLOOR_MULT = 2        -- planchers de fer et de cuivre des tourelles des îlots : 2 fois ceux de la défense (« ressources d'abord »)
I.PITCH, I.HALF, I.STREET = 28, 12, 4 -- treillis (shared/team/plan.lua : P.PITCH, P.HALF, P.STREET)

local function sorted_strings(list)
  local out = {}
  for i = 1, #list do out[i] = list[i] end
  table.sort(out)
  return out
end

--- Écart de Chebyshev entre deux rectangles { x0, y0, x1, y1 } (fin exclue) : 0 s'ils se touchent ou se recouvrent.
function I.gap(a, b)
  local dx = math.max(a.x0 - b.x1, b.x0 - a.x1, 0)
  local dy = math.max(a.y0 - b.y1, b.y0 - a.y1, 0)
  return math.max(dx, dy)
end

--- Centre d'un rectangle.
function I.center(box) return (box.x0 + box.x1) / 2, (box.y0 + box.y1) / 2 end

---------------------------------------------------------------------------------------------------
-- 1. Îlots
---------------------------------------------------------------------------------------------------
--- Regroupe les lots candidats de proche en proche. cands = { { k, x0, y0, x1, y1, pid, value, plant } ... } (lots HORS de l'enceinte
--- pris par un projet fini ; `value` est la valeur du projet, comptée une fois par projet et par îlot). Rend une liste d'îlots
--- { key, box = { x0, y0, x1, y1 }, value, plant, lots = { k ... } }, dans l'ordre de leur premier lot. Déterministe : l'ordre des
--- candidats ne change que l'ordre de la liste rendue, jamais les groupes (fermeture transitive).
function I.clusters(cands, join)
  join = join or I.JOIN
  local n = #(cands or {})
  local group = {}
  local out = {}
  for i = 1, n do
    if not group[i] then
      local g = { members = { i } }
      group[i] = g
      local q = 1
      while q <= #g.members do
        local a = cands[g.members[q]]
        for j = 1, n do
          if not group[j] and I.gap(a, cands[j]) <= join then
            group[j] = g
            g.members[#g.members + 1] = j
          end
        end
        q = q + 1
      end
      out[#out + 1] = g
    end
  end
  local list = {}
  for _, g in ipairs(out) do
    table.sort(g.members)
    local box, keys, value, plant, seen = nil, {}, 0, false, {}
    local pids = {}
    for _, i in ipairs(g.members) do
      local c = cands[i]
      if box then
        box.x0, box.y0 = math.min(box.x0, c.x0), math.min(box.y0, c.y0)
        box.x1, box.y1 = math.max(box.x1, c.x1), math.max(box.y1, c.y1)
      else
        box = { x0 = c.x0, y0 = c.y0, x1 = c.x1, y1 = c.y1 }
      end
      keys[#keys + 1] = tostring(c.k)
      local pk = c.pid ~= nil and tostring(c.pid) or ("lot " .. tostring(c.k))
      if not seen[pk] then
        seen[pk] = true
        pids[#pids + 1] = pk
        value = value + (c.value or 0)
      end
      if c.plant then plant = true end
    end
    keys = sorted_strings(keys)
    list[#list + 1] = { key = table.concat(keys, "+"), box = box, value = value, plant = plant, lots = keys, projects = #pids }
  end
  return list
end

--- Le rectangle `r` (fin exclue) est-il entièrement DEHORS du contour de l'enceinte `bounds` = { x0, y0, x1, y1 } (tuiles du mur, incluses),
--- avec au moins deux tuiles libres entre le mur de l'îlot (collé à `r`) et celui de l'enceinte ? Un lot que le mur principal coupe n'est pas
--- un îlot (son anneau croiserait l'enceinte).
function I.outside(bounds, r)
  if not bounds then return false end
  return I.gap(r, { x0 = bounds[1], y0 = bounds[2], x1 = bounds[3] + 1, y1 = bounds[4] + 1 }) >= 3
end

--- Valeur d'un projet : `built` pièces bâties (murs exclus par l'appelant), plus I.PLANT_BONUS pour une centrale.
function I.value(built, plant)
  return (built or 0) + (plant and I.PLANT_BONUS or 0)
end

--- Attaques connues autour d'une emprise : cells = { { x, y, score } ... } (mémoire du front, shared/team/front.lua F.top). Rend
--- (score total des cellules à moins de `margin` tuiles de l'emprise, centre pondéré { x, y } de ces cellules ou nil).
function I.attack(box, cells, margin)
  margin = margin or I.ATTACK_MARGIN
  local total, sx, sy = 0, 0, 0
  for _, c in ipairs(cells or {}) do
    if c.x >= box.x0 - margin and c.x <= box.x1 + margin and c.y >= box.y0 - margin and c.y <= box.y1 + margin then
      local s = c.score or 0
      total, sx, sy = total + s, sx + c.x * s, sy + c.y * s
    end
  end
  if total <= 0 then return 0, nil end
  return total, { x = sx / total, y = sy / total }
end

--- Tri des îlots : attaqué d'abord (score décroissant), puis valeur décroissante, puis distance (carrée) du centre au QG croissante, puis clé.
--- `rows` : { { key, attack, value, box } ... } ; `hq` : { x, y }. Trie la liste en place et la rend.
function I.sort(rows, hq)
  local function d2(r)
    local cx, cy = I.center(r.box)
    local dx, dy = cx - (hq and hq.x or 0), cy - (hq and hq.y or 0)
    return dx * dx + dy * dy
  end
  for _, r in ipairs(rows) do r._d2 = d2(r) end
  table.sort(rows, function(a, b)
    local aa, ab = (a.attack or 0) >= I.ATTACK_MIN, (b.attack or 0) >= I.ATTACK_MIN
    if aa ~= ab then return aa end
    if (a.attack or 0) ~= (b.attack or 0) then return (a.attack or 0) > (b.attack or 0) end
    if (a.value or 0) ~= (b.value or 0) then return (a.value or 0) > (b.value or 0) end
    if a._d2 ~= b._d2 then return a._d2 < b._d2 end
    return tostring(a.key) < tostring(b.key)
  end)
  for _, r in ipairs(rows) do r._d2 = nil end
  return rows
end

--- Nouvel îlot à retenir : parmi `clusters` (I.clusters), ceux qui sont importants (valeur >= I.MIN_VALUE), pas déjà retenus (clé) et
--- pas collés à un îlot retenu (`islands` : { { key, box } }, écart <= I.NEAR_ISLAND), triés par I.sort. `cells` : mémoire du front.
--- Rend (îlot choisi ou nil, raison ou nil, liste triée des admissibles). Plus de place (I.MAX atteint) : (nil, "plafond").
function I.pick_new(clusters, islands, cells, hq, max)
  max = max or I.MAX
  islands = islands or {}
  if #islands >= max then return nil, "plafond", {} end
  local known = {}
  for _, il in ipairs(islands) do known[il.key] = true end
  local rows = {}
  local small, near = 0, 0
  for _, c in ipairs(clusters or {}) do
    if not known[c.key] then
      local close = false
      for _, il in ipairs(islands) do
        if I.gap(c.box, il.box) <= I.NEAR_ISLAND then close = true break end
      end
      if close then
        near = near + 1
      elseif (c.value or 0) < I.MIN_VALUE then
        small = small + 1
      else
        local a, at = I.attack(c.box, cells)
        rows[#rows + 1] = { key = c.key, box = c.box, value = c.value, plant = c.plant, lots = c.lots, attack = a, at = at }
      end
    end
  end
  I.sort(rows, hq)
  if #rows == 0 then
    if small > 0 then return nil, "petits", rows end
    if near > 0 then return nil, "voisins", rows end
    return nil, "aucun", rows
  end
  return rows[1], nil, rows
end

---------------------------------------------------------------------------------------------------
-- 2. Mur
---------------------------------------------------------------------------------------------------
--- La coordonnée `v` (axe x ou y) est-elle sur une rue du treillis d'origine `o` ?
function I.on_street(v, o)
  return ((v - o - I.HALF) % I.PITCH) < I.STREET
end

--- Anneau d'un îlot : { walls = { { tx, ty, x, y, side } ... }, gates = tuiles ouvertes, skipped = { [raison] = n }, bounds }. Le mur est sur
--- le BORD de l'emprise `box` (fin exclue) : rangées y0 et y1 - 1, colonnes x0 et x1 - 1 (jamais sur une rue : celles qui traversent
--- l'emprise sont ouvertes). `lat` = { ox, oy } (treillis ; nil : pas d'ouverture de rue). opts.skip(tx, ty) -> raison ou nil, opts.gate
--- (défaut I.GATE). Ordre : nord, sud, ouest, est (comme E.ring).
function I.ring(box, lat, opts)
  opts = opts or {}
  local g = opts.gate or I.GATE
  local x0, y0, x1, y1 = box.x0, box.y0, box.x1, box.y1
  local out = { walls = {}, gates = 0, skipped = {}, bounds = { x0, y0, x1 - 1, y1 - 1 } }
  local gx = math.floor((x0 + x1) / 2) - math.floor(g / 2)
  local gy = math.floor((y0 + y1) / 2) - math.floor(g / 2)
  local function gate_x(tx)
    if g > 0 and tx >= gx and tx < gx + g then return true end
    return lat ~= nil and I.on_street(tx, lat.ox)
  end
  local function gate_y(ty)
    if g > 0 and ty >= gy and ty < gy + g then return true end
    return lat ~= nil and I.on_street(ty, lat.oy)
  end
  local function add(tx, ty, side, gate)
    if gate then out.gates = out.gates + 1 return end
    local why = opts.skip and opts.skip(tx, ty) or nil
    if why then out.skipped[why] = (out.skipped[why] or 0) + 1 return end
    out.walls[#out.walls + 1] = { tx = tx, ty = ty, x = tx + 0.5, y = ty + 0.5, side = side }
  end
  -- (une rangée posée SUR une rue (emprise hors treillis) serait entièrement ouverte : la rangée elle-même est testée)
  local function row_gate(tx, ty) return gate_x(tx) or (lat ~= nil and I.on_street(ty, lat.oy)) end
  local function col_gate(tx, ty) return gate_y(ty) or (lat ~= nil and I.on_street(tx, lat.ox)) end
  for tx = x0, x1 - 1 do add(tx, y0, "n", row_gate(tx, y0)) end
  for tx = x0, x1 - 1 do add(tx, y1 - 1, "s", row_gate(tx, y1 - 1)) end
  for ty = y0 + 1, y1 - 2 do add(x0, ty, "o", col_gate(x0, ty)) end
  for ty = y0 + 1, y1 - 2 do add(x1 - 1, ty, "e", col_gate(x1 - 1, ty)) end
  return out
end

--- Point vers lequel l'îlot se mure d'abord : la dernière attaque connue (centre pondéré, I.attack), sinon le point à l'opposé du QG
--- (centre + (centre - QG)) : le côté tourné vers la nature ; sans QG, le centre.
function I.ref_point(box, hq, attack_at)
  if attack_at then return { x = attack_at.x, y = attack_at.y } end
  local cx, cy = I.center(box)
  if not hq then return { x = cx, y = cy } end
  return { x = cx + (cx - hq.x), y = cy + (cy - hq.y) }
end

--- Ordre de pose des tronçons d'un îlot (E.split_runs) : le milieu le plus proche de `ref` d'abord, puis l'identifiant. Rend (ordre, refs)
--- au format de E.next_segment (refs[id] = ref : un segment plus court que son bloc démarre par le bout le plus proche de ref).
function I.run_order(runs, ref)
  local ids, d = {}, {}
  for _, run in ipairs(runs) do
    ids[#ids + 1] = run.id
    d[run.id] = (run.mx - ref.x) ^ 2 + (run.my - ref.y) ^ 2
  end
  table.sort(ids, function(a, b) if d[a] ~= d[b] then return d[a] < d[b] end return a < b end)
  local refs = {}
  for _, id in ipairs(ids) do refs[id] = ref end
  return ids, refs
end

---------------------------------------------------------------------------------------------------
-- 3. Tourelles
---------------------------------------------------------------------------------------------------
--- Tourelles voulues pour un îlot de ce score d'attaque.
function I.want(attack)
  if (attack or 0) >= I.ATTACK_MIN then return I.TURRETS_ATTACKED end
  return I.TURRETS
end

--- (x, y) est-il à moins de `d` tuiles (Chebyshev) de l'emprise ?
function I.near_box(box, x, y, d)
  return x >= box.x0 - d and x <= box.x1 + d and y >= box.y0 - d and y <= box.y1 + d
end

--- Tourelles de l'équipe (armées ou non : une vide est ravitaillée, pas remplacée) qui gardent déjà l'îlot.
function I.guards(box, turrets, cover)
  cover = cover or I.COVER
  local n = 0
  for _, t in ipairs(turrets or {}) do
    if I.near_box(box, t.x, t.y, cover) then n = n + 1 end
  end
  return n
end

--- Une pose en (x, y) est-elle acceptée pour l'îlot ? La tourelle entière DANS l'emprise (centre à I.ACCEPT = -1 : une tuile en retrait) :
--- jamais sur la rue (les PNJ y marchent) ni sur la tuile du mur.
function I.accepts(box, x, y) return I.near_box(box, x, y, I.ACCEPT) end

--- Emplacements candidats : les 4 coins de l'emprise en retrait de I.INSET tuiles, puis les 4 milieux des côtés en retrait, du plus
--- proche de `ref` au plus loin (à égalité, cet ordre). La pose cherche une place libre autour de chacun (script/faction/outposts.lua).
function I.sites(box, ref)
  local k = I.INSET
  local cx, cy = math.floor((box.x0 + box.x1) / 2), math.floor((box.y0 + box.y1) / 2)
  local raw = {
    { box.x0 + k, box.y0 + k }, { box.x1 - k, box.y0 + k }, { box.x1 - k, box.y1 - k }, { box.x0 + k, box.y1 - k },
    { cx, box.y0 + k }, { box.x1 - k, cy }, { cx, box.y1 - k }, { box.x0 + k, cy },
  }
  local cand = {}
  for i, p in ipairs(raw) do
    local d = ref and ((p[1] - ref.x) ^ 2 + (p[2] - ref.y) ^ 2) or 0
    cand[#cand + 1] = { x = p[1], y = p[2], d = d, i = i }
  end
  table.sort(cand, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.i < b.i end)
  local out = {}
  for _, c in ipairs(cand) do out[#out + 1] = { x = c.x, y = c.y } end
  return out
end

--- Plan des tourelles des îlots. islands = { { key, box, attack, at (centre d'attaque ou nil), rest (au repos) } } (îlots retenus, dans
--- l'ordre de la liste) ; turrets = { { x, y } } toutes les tourelles de l'équipe ; placed = tourelles des îlots déjà posées ; hq = { x, y }.
--- Rend { rows = { { key, want, have, missing, skip } }, pick = { key, want, have, missing, sites, pos } ou nil, left }. Une seule tâche
--- à la fois : l'îlot le plus en manque selon I.sort (attaqué d'abord), sous le plafond d'équipe I.TEAM_MAX.
function I.plan_turrets(islands, turrets, placed, hq, cap)
  cap = cap or I.TEAM_MAX
  local left = math.max(0, cap - (placed or 0))
  local rows = {}
  for _, il in ipairs(islands or {}) do
    local want = I.want(il.attack)
    local have = I.guards(il.box, turrets)
    rows[#rows + 1] = { key = il.key, box = il.box, attack = il.attack or 0, value = il.value or 0, at = il.at, rest = il.rest,
      want = want, have = have, missing = math.max(0, want - have) }
  end
  local order = {}
  for _, r in ipairs(rows) do order[#order + 1] = r end
  I.sort(order, hq)
  local pick = nil
  for _, r in ipairs(order) do
    if r.missing <= 0 then
      r.skip = "gardee"
    elseif r.rest then
      r.skip = "repos"
    elseif left <= 0 then
      r.skip = "plafond"
    elseif pick then
      r.skip = "suivante"
    else
      local n = math.min(r.missing, left)
      local cx, cy = I.center(r.box)
      pick = { key = r.key, want = r.have + n, have = r.have, missing = n, sites = I.sites(r.box, I.ref_point(r.box, hq, r.at)),
        pos = { x = cx, y = cy }, box = r.box }
      r.skip = "servie"
    end
  end
  return { rows = order, pick = pick, left = left }
end

--- Planchers de fer et de cuivre des tourelles des îlots (« ressources d'abord ») : I.FLOOR_MULT fois ceux de la défense.
function I.floors(base_iron, base_copper)
  return (base_iron or 0) * I.FLOOR_MULT, (base_copper or 0) * I.FLOOR_MULT
end

return I
