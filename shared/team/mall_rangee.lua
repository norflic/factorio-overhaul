--[[
  Lot MALL, tranche 2 (docs/MALL.md §2.2, §2.4, §2.5) : RANGÉE du mall. Règle PURE : aucune API du jeu, aucun nom d'objet (machines, bras,
  tapis, poteaux, coffres, recettes viennent de l'appelant, lus aux prototypes). Testée hors jeu : tests/mall_rangee_test.lua.

  Une rangée = une TÊTE (4 quais au plus : un par voie) puis des CELLULES mises bout à bout le long de l'axe. La cellule est LUE au
  catalogue de l'agent MOTIFS (shared/team/motifs, motif Mr.MOTIF = asm-miroir-2e-coffres, référence Mall1.png) : aucune géométrie de
  rangée n'est inventée ici, seule la tête (P.feeder, shared/team/plan.lua) l'est. Une cellule porte DEUX machines (haut et bas), chacune sa
  recette, chacune sa sortie en coffre ; deux tapis communs au centre portent chacun deux objets (quatre voies pures, déclarées `carries`).
  Allonger la rangée = poser les cellules suivantes : les tapis continuent, rien de posé n'est défait. Les cellules sont demandées
  par SECTIONS (un projet du plan directeur par section).

  Repère CANONIQUE : l'axe de la rangée va vers l'est (+x). Cellule i (1, 2, …) : x de 4 × (i − 1) à 4 × (i − 1) + 3, y de 0 à 13 ; tapis 1
  en y = 6, tapis 2 en y = 7 (ports « in » du motif) ; tête à l'ouest, x de −6 à −1, y de 4 à 9. Le repère du monde : Mr.frame(dir) quarts de
  tour vers `dir` (direction de croissance du secteur), Mr.to_world.

  DÉCISIONS (toutes déterministes, listes triées) :
    Mr.voies(cands, 4) : les entrées solides les plus demandées (un objet produit par un candidat n'est jamais une voie).
    Mr.accepte(voies, solides, nom).
    Mr.ajouts(row, demandes) : les machines à ajouter à une rangée (nouveaux objets, machines supplémentaires pour un objet qui manque de débit).
    Mr.sceller(row, ajouts) : cellules à demander (deux machines chacune ; une place libre reprend la recette de sa voisine : pas de machine sans recette).
]]

local Mr = {}

Mr.MOTIF = "asm-miroir-2e-coffres"
Mr.PERIODE = 4      -- tuiles par cellule le long de la rangée (période du motif)
Mr.LARGE = 14       -- tuiles en travers de la rangée (hauteur du motif)
Mr.PITCH = 15       -- pas entre deux rangées voisines (14 + 1 tuile de passage)
Mr.YA, Mr.YB = 6, 7 -- tapis d'entrée (ports « in » du motif : y = 6 et y = 7)
Mr.TETE = 6         -- tuiles de tête à l'ouest de la première cellule (x de −6 à −1)
Mr.MAX_CELLS = 64   -- cellules par rangée au plus (garde-fou)
Mr.MARGE = 1        -- tuiles laissées libres au bord du secteur
Mr.PORT_X = -4      -- abscisse canonique du coude de la tête (bout amont des deux tapis)
Mr.ARMS = 2         -- bras (et coffres) par voie à la tête : un seul bras plafonne la voie (micro-banc t2-rangee3 : 0,8 objet/s pour 12 machines, tapis clairsemés, mesuré)

local floor, ceil = math.floor, math.ceil

---------------------------------------------------------------------------------------------------
-- Voies et demande
---------------------------------------------------------------------------------------------------
--- Voies de la rangée : les `max_voies` (4) entrées solides les plus demandées parmi `cands` = { { name, solides = { noms } } } (dans l'ordre de
--- l'appelant), départage par nom ; un objet produit par la rangée n'est jamais une voie. Rend la liste (1 à 4 noms).
function Mr.voies(cands, max_voies)
  max_voies = max_voies or 4
  local use, made = {}, {}
  for _, c in ipairs(cands or {}) do made[c.name] = true end
  local names = {}
  for _, c in ipairs(cands or {}) do
    for _, s in ipairs(c.solides or {}) do
      if not made[s] then
        if not use[s] then use[s] = 0; names[#names + 1] = s end
        use[s] = use[s] + 1
      end
    end
  end
  table.sort(names, function(a, b)
    if use[a] ~= use[b] then return use[a] > use[b] end
    return a < b
  end)
  local out = {}
  for i = 1, math.min(max_voies, #names) do out[i] = names[i] end
  return out
end

--- Un objet entre-t-il dans la rangée : au moins une entrée solide, toutes sur les voies, et il n'est pas lui-même une voie ?
function Mr.accepte(voies, solides, name)
  local on = {}
  for _, v in ipairs(voies or {}) do on[v] = true end
  if on[name] then return false end
  if #(solides or {}) == 0 then return false end
  for _, s in ipairs(solides) do if not on[s] then return false end end
  return true
end

--- Nombre de machines qui portent `recipe` dans la rangée.
function Mr.compte(row, recipe)
  local n = 0
  for _, c in ipairs(row.cells or {}) do
    if c.h == recipe then n = n + 1 end
    if c.b == recipe then n = n + 1 end
  end
  return n
end

--- Dernière section VIVANTE d'une rangée (les sections refusées, `dead`, restent dans la liste : la dernière de la liste peut être morte). Rend l'entrée ou nil.
function Mr.derniere(projects)
  for i = #(projects or {}), 1, -1 do
    if not projects[i].dead then return projects[i] end
  end
  return nil
end

--- Machines à ajouter : demandes = { { item, recipe, machines, solides } } (machines ≥ 1, entier). Un objet refusé (entrée hors voies, objet-voie) est écarté ; un
--- objet déjà servi n'ajoute que la différence ; `max_new` borne le total (nil : aucune borne). Rend la liste { recipe, item, n } dans l'ordre reçu.
function Mr.ajouts(row, demandes, max_new)
  local out, total = {}, 0
  for _, d in ipairs(demandes or {}) do
    if Mr.accepte(row.voies, d.solides, d.item) then
      local n = math.max(0, (d.machines or 1) - Mr.compte(row, d.recipe))
      if max_new then n = math.min(n, max_new - total) end
      if n > 0 then
        out[#out + 1] = { recipe = d.recipe, item = d.item, n = n, machine = d.machine }
        total = total + n
      end
    end
  end
  return out
end

--- Découpe les ajouts en cellules { h, b, ih, ib, m } (deux machines) : une place libre reprend la recette de sa voisine (la machine ne reste jamais sans recette, elle
--- double le débit de sa voisine). Rend la liste de cellules neuves.
function Mr.sceller(ajouts)
  local flat = {}
  for _, a in ipairs(ajouts or {}) do
    for _ = 1, a.n do flat[#flat + 1] = a end
  end
  local cells = {}
  local i = 1
  while i <= #flat do
    local a, c = flat[i], flat[i + 1]
    cells[#cells + 1] = { h = a.recipe, b = (c or a).recipe, ih = a.item, ib = (c or a).item, m = a.machine, mb = (c or a).machine }
    i = i + 2
  end
  return cells
end

---------------------------------------------------------------------------------------------------
-- Géométrie canonique
---------------------------------------------------------------------------------------------------
local ROLE_NAME = { machine_asm = "machine", bras = "bras", bras_long = "bras_long", tapis_entree = "tapis", poteau = "poteau", coffre = "coffre" }

--- Modèle de la cellule : pièces de D.instancier(motif, 1, rot 0) (Mr.MOTIF lu au catalogue : `pieces` de l'instance, x, y, w, h, role, k, dir, groupe).
--- Rend le modèle (table simple) ou nil, raison (rôle inconnu : le motif a changé).
function Mr.modele(pieces)
  local out = {}
  for _, p in ipairs(pieces or {}) do
    if not ROLE_NAME[p.role] then return nil, "role inconnu du mall : " .. tostring(p.role) end
    out[#out + 1] = { role = p.role, x = p.x, y = p.y, w = p.w or 1, h = p.h or 1, dir = p.dir or 0, k = p.k, groupe = p.groupe }
  end
  return out
end

--- Tapis portés par les voies : { { A, B }, { C, D } } (carries de chaque tapis, 2 objets au plus par tapis, jamais nil pour un tapis utilisé).
function Mr.carries(voies)
  local a, b, c, d = voies[1], voies[2], voies[3], voies[4]
  return { { a, b or a }, { c or a, d or c or a } }
end

--- Entités canoniques (centres) de la cellule `i` (cell = { h, b, m }), kit `names` = { machine (repli), bras, bras_long, tapis, poteau, coffre }.
--- Rend { ents = { name, x, y, dir, recipe, role, carries }, outs = { x, y, item, bar } }.
function Mr.cellule(modele, i, cell, names, carries, serie)
  local dx = (i - 1) * Mr.PERIODE + ((serie and serie.shift and serie.shift[i]) or 0) -- (lot MALL-DIRECTIONS : cellule poussée après une rue)
  local swap = serie and serie.swap or nil
  local ents, outs = {}, {}
  for _, p in ipairs(modele) do
    local nm = names[ROLE_NAME[p.role]]
    if p.role == "machine_asm" then nm = ((p.groupe == "bas") and cell.mb or cell.m) or cell.m or names.machine end -- (machine propre à chaque recette)
    local c = { name = nm, x = p.x + p.w / 2 + dx, y = p.y + p.h / 2, dir = p.dir, role = "mall-" .. p.role }
    if p.role == "machine_asm" then
      c.recipe = (p.groupe == "haut") and cell.h or cell.b
    elseif p.role == "tapis_entree" then
      c.carries = carries[p.k]
      c.line, c.flow = p.k, dx + p.x
      local sw = swap and swap[dx + p.x]
      if sw then c.name, c.type, c.ug, c.role = names.souterrain, sw, sw, "mall-serie" end -- (entrée ou sortie du souterrain sous la rue)
    elseif p.role == "coffre" then
      -- coffre : le coffre du haut (k = 1) reçoit la machine « haut », celui du bas (k = 2) la machine « bas »
      c.role = "mall-sortie"
      outs[#outs + 1] = { x = c.x, y = c.y, item = (p.k == 1) and cell.ih or cell.ib }
    end
    ents[#ents + 1] = c
  end
  return { ents = ents, outs = outs }
end

--- Tête canonique : les quais des voies (Mr.ARMS par voie, P.feeder de shared/team/plan.lua) ; par tapis alimenté, un poteau entre ses bras et un relais vers le
--- premier poteau de cellule (fils de 4 et 4,1 tuiles, dans la portée d'un poteau de base).
--- P = shared/team/plan.lua ; rend { ents, quais = { x, y, item } } (centres) ; nb = tapis alimentés (1 ou 2).
function Mr.tete(P, voies, names, j)
  local ents, quais = {}, {}
  local nb = (#voies >= 3) and 2 or 1
  local rows = { Mr.YA, Mr.YB }
  local dirs = { 4, 0 } -- le tapis 1 arrive du nord (coude vers l'est), le tapis 2 du sud
  local carries = Mr.carries(voies)
  local lanes = { { voies[1], voies[2] or voies[1] }, { voies[3] or voies[1], voies[4] or voies[3] or voies[1] } }
  for k = 1, 2 do
    local y = rows[k]
    for x = Mr.PORT_X, -1 do ents[#ents + 1] = { name = names.tapis, x = x + 0.5, y = y + 0.5, dir = 2, role = "mall-tete", carries = carries[k], line = k, flow = -100 + (x - Mr.PORT_X) } end
    if k <= nb then
      local port = { x = Mr.PORT_X, y = y, dir = dirs[k], lanes = lanes[k] }
      local same = lanes[k][1] == lanes[k][2]
      local fd = P.feeder(port, { "quai", (not same) and "quai" or nil }, names.bras, names.tapis, Mr.ARMS)
      local upstream = 0
      for _, e in ipairs(fd.entities) do
        if e.role == "tete" then
          upstream = upstream + 1 -- (P.feeder donne ses tapis du coude vers l'amont)
          e.carries, e.line, e.flow = carries[k], k, -100 - upstream
          e.role = "mall-tete"
        end
        ents[#ents + 1] = e
      end
      for _, c in ipairs(fd.chests) do quais[#quais + 1] = { x = c.x, y = c.y, item = c.item } end
    end
  end
  if j and j > 1 then
    -- relais vers la rangée précédente, dans la tuile de passage : 8 tuiles séparent les poteaux de deux rangées voisines, au-delà du fil d'un petit poteau (7,5 ; partie neuve
    -- ab-a32fb69a, votre équipe : rangées 2 et 3 refusées au raccord, la réserve du secteur fermant tout autre chemin)
    ents[#ents + 1] = { name = names.poteau, x = 3.5, y = -0.5, dir = 0, role = "mall-poteau" }
  end
  ents[#ents + 1] = { name = names.poteau, x = -4.5, y = 4.5, dir = 0, role = "mall-poteau" }
  ents[#ents + 1] = { name = names.poteau, x = -0.5, y = 4.5, dir = 0, role = "mall-poteau" }
  if nb == 2 then
    ents[#ents + 1] = { name = names.poteau, x = -4.5, y = 9.5, dir = 0, role = "mall-poteau" }
    ents[#ents + 1] = { name = names.poteau, x = -0.5, y = 9.5, dir = 0, role = "mall-poteau" }
  end
  return { ents = ents, quais = quais, nb = nb }
end

---------------------------------------------------------------------------------------------------
-- Repère du monde
---------------------------------------------------------------------------------------------------
--- Quarts de tour qui envoient l'est canonique vers `dir` (0 N, 2 E, 4 S, 6 O), sens des aiguilles.
function Mr.frame(dir) return ((dir - 2) % 8) / 2 end

local function rot_pt(x, y, k)
  for _ = 1, k do x, y = -y, x end
  return x, y
end

--- (x, y) canonique (centre) de la rangée j tourné de k quarts de tour et translaté de (ox, oy) ; direction tournée. Rend wx, wy, wd.
function Mr.to_world(x, y, d, k, ox, oy, j)
  local wx, wy = rot_pt(x, y + ((j or 1) - 1) * Mr.PITCH, k)
  return wx + ox, wy + oy, d and ((d + 2 * k) % 8) or nil
end

--- Translation de la rangée dans le secteur s (x0, y0 inclus, x1, y1 exclus ; s.dir = sens de croissance) : la tête contre le bord amont, à Mr.MARGE tuile du bord,
--- la première rangée à Mr.MARGE tuile du bord latéral. Entiers : les centres tournés gardent leur demi-tuile. Rend ox, oy.
function Mr.origin(s, west, north)
  local k = Mr.frame(s.dir)
  local ax, ay = rot_pt(-(west or Mr.TETE), -(north or 0), k)
  local bx, by = rot_pt(Mr.PERIODE, Mr.LARGE, k)
  local x0, y0, x1, y1 = math.min(ax, bx), math.min(ay, by), math.max(ax, bx), math.max(ay, by)
  local m = Mr.MARGE
  if s.dir == 2 then return s.x0 + m - x0, s.y0 + m - y0 end
  if s.dir == 6 then return s.x1 - m - x1, s.y1 - m - y1 end
  if s.dir == 4 then return s.x1 - m - x1, s.y0 + m - y0 end
  return s.x0 + m - x0, s.y1 - m - y1
end

--- Inverse de Mr.to_world pour la rangée 1 : du monde au repère canonique (coordonnées absolues).
function Mr.from_world(wx, wy, k, ox, oy)
  local x, y = wx - ox, wy - oy
  for _ = 1, k do x, y = y, -x end
  return x, y
end

--- Vrai si cette tuile du repère canonique n'est utilisée par aucune rangée ni par le tronc, quelle que soit la croissance du mall : une chaîne de poteaux peut y passer (la réserve du secteur
--- la fermait : sections refusées au raccord, parties tronc-partie-30bfce34). west, north : place réservée à l'ouest et au nord (Mr.TETE, 0 sans tronc). Bande libre : hors de la place du tronc,
--- les tuiles de passage entre deux rangées (sauf x = 3, le poteau relais d'une rangée).
function Mr.reserve_libre(rx, ry, west, north)
  if rx < -west or ry < -north then return true end
  if ry < 0 then return rx >= 0 end
  if ry % Mr.PITCH == Mr.PITCH - 1 then return rx >= 0 and rx ~= 3 end
  return false
end

--- Rangées (j max) et cellules (n max) que le secteur porte, à l'intérieur : rend (rows, cells_in, along, across).
function Mr.capacite(s, west, north)
  local k = Mr.frame(s.dir)
  local w, h = s.x1 - s.x0, s.y1 - s.y0
  local along, across = (k % 2 == 0) and w or h, (k % 2 == 0) and h or w
  local rows = floor((across - 2 * Mr.MARGE - (north or 0) + 1) / Mr.PITCH)
  local cells = floor((along - 2 * Mr.MARGE - (west or Mr.TETE)) / Mr.PERIODE)
  return math.max(rows, 0), math.max(cells, 0), along, across
end

--- Boîte (tuiles entières, x0, y0, x1, y1 inclusifs) des entités (w, h lus par size(name, dir)).
function Mr.box(ents, size)
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, e in ipairs(ents) do
    local w, h = size(e.name, e.dir)
    local ax, ay = floor(e.x - w / 2 + 1e-6), floor(e.y - h / 2 + 1e-6)
    x0, y0 = math.min(x0, ax), math.min(y0, ay)
    x1, y1 = math.max(x1, ax + w - 1), math.max(y1, ay + h - 1)
  end
  return { x0, y0, x1, y1 }
end

--- Section (projet) : entités du monde (centres) des cellules from à to de la rangée, tête comprise quand `head` ; `P` = plan (feeder).
--- row = { j, voies, cells, ... } ; repere = { ox, oy, k } ; rend { ents, quais, outs }.
function Mr.section(P, modele, row, from, to, names, repere, head, extra, serie)
  local carries = Mr.carries(row.voies)
  local ents, quais, outs = {}, {}, {}
  local function push(list, dest)
    for _, e in ipairs(list) do
      local x, y, d = Mr.to_world(e.x, e.y, e.dir, repere.k, repere.ox, repere.oy, row.j)
      dest[#dest + 1] = { name = e.name, x = x, y = y, dir = d, recipe = e.recipe, role = e.role, carries = e.carries, item = e.item, line = e.line, flow = e.flow,
        type = e.type, ug = e.ug }
    end
  end
  -- lot MALL-DIRECTIONS : traversées des rues du treillis (Mr.serie_cells) servies par cette section : rallonge de tapis sur chaque ligne, souterrain
  -- (entrée sur la dernière tuile avant la rue, sortie sur la première après : tuiles libres, ou tuiles de tapis d'une cellule remplacées, Mr.cellule swap),
  -- deux poteaux relais dans la rangée de passage (y = −1), de part et d'autre de la rue
  if serie and serie.trav then
    local sw = {}
    for _, t in ipairs(serie.trav) do
      -- l'entrée est dans la dernière tuile de la cellule précédente (fin collée à la rue) ou sur une tuile libre après elle ; les remplacements (swap)
      -- valent pour toute la rangée : la cellule qui porte l'entrée la pose, dans sa propre section (Mr.serie_cells est calculé une cellule au-delà)
      local prev_end = t.avant > 1 and ((t.avant - 2) * Mr.PERIODE + (serie.shift[t.avant - 1] or 0) + Mr.PERIODE) or 0
      local inside = t.a_in < prev_end
      if inside then sw[t.a_in] = "input" end
      sw[t.a_out] = "output"
      if t.avant >= from and t.avant <= to then
        local list = {}
        for k, y in ipairs({ Mr.YA, Mr.YB }) do
          for _, a in ipairs(t.rallonge) do
            list[#list + 1] = { name = names.tapis, x = a + 0.5, y = y + 0.5, dir = 2, role = "mall-serie", carries = carries[k], line = k, flow = a }
          end
          if not inside then
            list[#list + 1] = { name = names.souterrain, x = t.a_in + 0.5, y = y + 0.5, dir = 2, role = "mall-serie", carries = carries[k], line = k, flow = t.a_in, type = "input", ug = "input" }
          end
        end
        list[#list + 1] = { name = names.poteau, x = t.a_in + 0.5, y = -0.5, dir = 0, role = "mall-poteau" }
        list[#list + 1] = { name = names.poteau, x = t.a_out + 0.5, y = -0.5, dir = 0, role = "mall-poteau" }
        push(list, ents)
      end
    end
    serie = { shift = serie.shift, swap = sw }
  end
  local routes = {}
  if extra then -- le tronc et les prises (shared/team/mall_tronc.lua) : coordonnées absolues, repère de la rangée 1
    for _, r in ipairs(extra.routes or {}) do
      local tiles = {}
      for _, t in ipairs(r.tiles) do
        local wx, wy, d = Mr.to_world(t.x + 0.5, t.y + 0.5, t.dir, repere.k, repere.ox, repere.oy, 1)
        tiles[#tiles + 1] = { x = floor(wx), y = floor(wy), dir = d, ug = t.ug }
      end
      routes[#routes + 1] = { item = r.item, tiles = tiles }
    end
    for _, e in ipairs(extra.ents) do
      local x, y, d = Mr.to_world(e.x, e.y, e.dir, repere.k, repere.ox, repere.oy, 1)
      ents[#ents + 1] = { name = e.name, x = x, y = y, dir = d, recipe = e.recipe, role = e.role, carries = e.carries, item = e.item, type = e.type }
    end
    for _, q in ipairs(extra.quais or {}) do
      local x, y = Mr.to_world(q.x, q.y, nil, repere.k, repere.ox, repere.oy, 1)
      quais[#quais + 1] = { x = x, y = y, item = q.item }
    end
  end
  if head then
    local t = Mr.tete(P, row.voies, names, row.j)
    push(t.ents, ents)
    for _, q in ipairs(t.quais) do
      local x, y = Mr.to_world(q.x, q.y, nil, repere.k, repere.ox, repere.oy, row.j)
      quais[#quais + 1] = { x = x, y = y, item = q.item }
    end
  end
  for i = from, to do
    local cc = Mr.cellule(modele, i, row.cells[i], names, carries, serie)
    push(cc.ents, ents)
    for _, o in ipairs(cc.outs) do
      local x, y = Mr.to_world(o.x, o.y, nil, repere.k, repere.ox, repere.oy, row.j)
      outs[#outs + 1] = { x = x, y = y, item = o.item }
    end
  end
  -- tracés des deux tapis, dans l'ordre du flux (preuve de pureté : Pur.check_route)
  local lines = { {}, {} }
  for _, e in ipairs(ents) do
    if e.line then lines[e.line][#lines[e.line] + 1] = { x = floor(e.x), y = floor(e.y), dir = e.dir, flow = e.flow, ug = e.ug } end
  end
  for k = 1, 2 do table.sort(lines[k], function(a, b) return a.flow < b.flow end) end
  return { ents = ents, quais = quais, outs = outs, lines = lines, carries = carries, routes = routes }
end

---------------------------------------------------------------------------------------------------
-- Lot MALL-DIRECTIONS (directive du DC du 10/11) : au-delà du secteur, la rangée FRANCHIT LES RUES du treillis par un souterrain par tapis
-- (la règle du ruban, F457, portée aux rangées) ; rien n'est posé sur la rue, qui reste libre pour les PNJ. Pur et déterministe.
---------------------------------------------------------------------------------------------------
--- Rues du treillis en coordonnées canoniques : bandes { a0, a1 } (a1 exclu, a = abscisse canonique le long de la rangée, en tuiles) dont a0 est
--- dans [a_min, a_max), triées. rep = { ox, oy, k } (Mr.frame, Mr.to_world) ; lots = { ox, oy, pitch, lot } (origine = coin nord-ouest du lot 0:0,
--- la rue = les pitch − lot tuiles après chaque lot, comme Mp.serie). L'axe canonique suit x croissant (k = 0), y croissant (k = 1), x décroissant
--- (k = 2), y décroissant (k = 3) : la tuile canonique a est la tuile du monde ox + a, oy + a, ox − a − 1, oy − a − 1.
function Mr.rues(rep, lots, a_min, a_max)
  local k = rep.k % 4
  local o = (k % 2 == 0) and rep.ox or rep.oy
  local lo = (k % 2 == 0) and lots.ox or lots.oy
  local sens = (k == 0 or k == 1) and 1 or -1
  local out = {}
  if lots.pitch - lots.lot <= 0 or a_max <= a_min then return out end
  local w0 = (sens > 0) and (o + a_min) or (o - a_max)
  local w1 = (sens > 0) and (o + a_max) or (o - a_min)
  local i0 = floor((w0 - lo - lots.lot) / lots.pitch) - 1
  local i1 = floor((w1 - lo) / lots.pitch) + 1
  for i = i0, i1 do
    local s0, s1 = lo + lots.pitch * i + lots.lot, lo + lots.pitch * (i + 1)
    local a0, a1
    if sens > 0 then a0, a1 = s0 - o, s1 - o else a0, a1 = o - s1, o - s0 end
    if a0 >= a_min and a0 < a_max then out[#out + 1] = { a0 = a0, a1 = a1 } end
  end
  table.sort(out, function(x, y) return x.a0 < y.a0 end)
  return out
end

--- Décalages des cellules 1..n et traversées. La cellule i commence en a = (i − 1) × PERIODE + shift ; si son emprise [a, a + PERIODE) touche une rue
--- { a0, a1 }, elle est poussée APRÈS la rue : elle commence en a1 (sa première tuile de tapis devient la SORTIE du souterrain), l'ENTRÉE est sur la
--- dernière tuile avant la rue (a0 − 1 : une tuile libre, ou la dernière tuile de tapis de la cellule précédente), une rallonge de tapis relie la fin de
--- la cellule précédente à l'entrée. reach = portée du souterrain (écart maximal entrée → sortie, lu au prototype) ; écart = a1 − a0 + 1.
--- Rend { shift = { [i] = s }, trav = { { a_in, a_out, rallonge = { a }, avant = i } } } ou nil, raison (portée insuffisante ou inconnue).
function Mr.serie_cells(n, rues, reach)
  local shift, trav = {}, {}
  local s, r = 0, 1
  for i = 1, n do
    local a = (i - 1) * Mr.PERIODE + s
    while rues[r] and rues[r].a1 <= a do r = r + 1 end
    local rue = rues[r]
    if rue and a + Mr.PERIODE > rue.a0 then
      local a_in, a_out = rue.a0 - 1, rue.a1
      local ecart = a_out - a_in
      if not reach or ecart > reach or ecart < 2 then
        return nil, string.format("rue de %d tuiles : souterrain d'ecart %d hors de la portee %s", rue.a1 - rue.a0, ecart, tostring(reach))
      end
      local t = { a_in = a_in, a_out = a_out, rallonge = {}, avant = i }
      for q = a, a_in - 1 do t.rallonge[#t.rallonge + 1] = q end
      trav[#trav + 1] = t
      s = s + (a_out - a)
      r = r + 1
    end
    shift[i] = s
  end
  return { shift = shift, trav = trav }
end

--- Liste de matériel { { nom, n } } triée par nom, comptée sur des entités.
function Mr.cout(ents)
  local n, names = {}, {}
  for _, e in ipairs(ents) do
    if not n[e.name] then n[e.name] = 0; names[#names + 1] = e.name end
    n[e.name] = n[e.name] + 1
  end
  table.sort(names)
  local out = {}
  for _, nm in ipairs(names) do out[#out + 1] = { nm, n[nm] } end
  return out
end

--- Contrôle de la géométrie d'une section (aucun chevauchement, tous les poteaux reliés, machines et bras couverts) pour un poteau de portée `wire` et d'aire `supply` (rayon).
--- Rend la liste des erreurs (vide : conforme).
function Mr.verifie(ents, size, wire, supply)
  local errs = {}
  local occ = {}
  local poles, consumers = {}, {}
  for i, e in ipairs(ents) do
    local w, h = size(e.name, e.dir)
    local x0, y0 = floor(e.x - w / 2 + 1e-6), floor(e.y - h / 2 + 1e-6)
    for ty = y0, y0 + h - 1 do
      for tx = x0, x0 + w - 1 do
        local k = tx .. ":" .. ty
        if occ[k] then errs[#errs + 1] = "chevauchement en " .. k .. " : " .. ents[occ[k]].name .. " et " .. e.name end
        occ[k] = i
      end
    end
    if e.role == "mall-poteau" then poles[#poles + 1] = e end
    if e.role == "mall-machine_asm" or e.role == "mall-bras" or e.role == "mall-bras_long" or e.role == "quai-bras" then consumers[#consumers + 1] = e end
  end
  -- composantes des poteaux (une seule attendue)
  local seen = {}
  local function visit(i)
    seen[i] = true
    for j = 1, #poles do
      if not seen[j] and (poles[i].x - poles[j].x) ^ 2 + (poles[i].y - poles[j].y) ^ 2 <= wire * wire + 1e-6 then visit(j) end
    end
  end
  if #poles > 0 then
    visit(1)
    for j = 1, #poles do if not seen[j] then errs[#errs + 1] = string.format("poteau isole en (%.1f, %.1f)", poles[j].x, poles[j].y) end end
  end
  for _, e in ipairs(consumers) do
    local w, h = size(e.name, e.dir)
    local covered = false
    for _, p in ipairs(poles) do
      if math.abs(p.x - e.x) < supply + w / 2 and math.abs(p.y - e.y) < supply + h / 2 then covered = true break end
    end
    if not covered then errs[#errs + 1] = string.format("%s sans courant en (%.1f, %.1f)", e.name, e.x, e.y) end
  end
  return errs
end

return Mr
