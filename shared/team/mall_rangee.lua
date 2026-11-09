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
    cells[#cells + 1] = { h = a.recipe, b = (c or a).recipe, ih = a.item, ib = (c or a).item, m = a.machine }
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
function Mr.cellule(modele, i, cell, names, carries)
  local dx = (i - 1) * Mr.PERIODE
  local ents, outs = {}, {}
  for _, p in ipairs(modele) do
    local nm = (p.role == "machine_asm") and (cell.m or names.machine) or names[ROLE_NAME[p.role]]
    local c = { name = nm, x = p.x + p.w / 2 + dx, y = p.y + p.h / 2, dir = p.dir, role = "mall-" .. p.role }
    if p.role == "machine_asm" then
      c.recipe = (p.groupe == "haut") and cell.h or cell.b
    elseif p.role == "tapis_entree" then
      c.carries = carries[p.k]
    elseif p.role == "coffre" then
      -- coffre : le coffre du haut (k = 1) reçoit la machine « haut », celui du bas (k = 2) la machine « bas »
      c.role = "mall-sortie"
      outs[#outs + 1] = { x = c.x, y = c.y, item = (p.k == 1) and cell.ih or cell.ib }
    end
    ents[#ents + 1] = c
  end
  return { ents = ents, outs = outs }
end

--- Tête canonique : les quais des voies (un par voie, P.feeder de shared/team/plan.lua) ; deux poteaux à 7,07 tuiles des premiers poteaux des cellules
--- (dans la portée d'un fil de poteau de base : 7,5).
--- P = shared/team/plan.lua ; rend { ents, quais = { x, y, item } } (centres) ; nb = tapis alimentés (1 ou 2).
function Mr.tete(P, voies, names)
  local ents, quais = {}, {}
  local nb = (#voies >= 3) and 2 or 1
  local rows = { Mr.YA, Mr.YB }
  local dirs = { 4, 0 } -- le tapis 1 arrive du nord (coude vers l'est), le tapis 2 du sud
  local carries = Mr.carries(voies)
  local lanes = { { voies[1], voies[2] or voies[1] }, { voies[3] or voies[1], voies[4] or voies[3] or voies[1] } }
  for k = 1, 2 do
    local y = rows[k]
    for x = Mr.PORT_X, -1 do ents[#ents + 1] = { name = names.tapis, x = x + 0.5, y = y + 0.5, dir = 2, role = "mall-tete", carries = carries[k] } end
    if k <= nb then
      local port = { x = Mr.PORT_X, y = y, dir = dirs[k], lanes = lanes[k] }
      local same = lanes[k][1] == lanes[k][2]
      local fd = P.feeder(port, { "quai", (not same) and "quai" or nil }, names.bras, names.tapis, 1)
      for _, e in ipairs(fd.entities) do
        e.carries = (e.role == "tete") and carries[k] or nil
        e.role = (e.role == "tete") and "mall-tete" or e.role
        ents[#ents + 1] = e
      end
      for _, c in ipairs(fd.chests) do quais[#quais + 1] = { x = c.x, y = c.y, item = c.item } end
    end
  end
  ents[#ents + 1] = { name = names.poteau, x = -3.5, y = 4.5, dir = 0, role = "mall-poteau" }
  ents[#ents + 1] = { name = names.poteau, x = -3.5, y = 9.5, dir = 0, role = "mall-poteau" }
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
function Mr.origin(s)
  local k = Mr.frame(s.dir)
  local ax, ay = rot_pt(-Mr.TETE, 0, k)
  local bx, by = rot_pt(Mr.PERIODE, Mr.LARGE, k)
  local x0, y0, x1, y1 = math.min(ax, bx), math.min(ay, by), math.max(ax, bx), math.max(ay, by)
  local m = Mr.MARGE
  if s.dir == 2 then return s.x0 + m - x0, s.y0 + m - y0 end
  if s.dir == 6 then return s.x1 - m - x1, s.y1 - m - y1 end
  if s.dir == 4 then return s.x1 - m - x1, s.y0 + m - y0 end
  return s.x0 + m - x0, s.y1 - m - y1
end

--- Rangées (j max) et cellules (n max) que le secteur porte, à l'intérieur : rend (rows, cells_in, along, across).
function Mr.capacite(s)
  local k = Mr.frame(s.dir)
  local w, h = s.x1 - s.x0, s.y1 - s.y0
  local along, across = (k % 2 == 0) and w or h, (k % 2 == 0) and h or w
  local rows = floor((across - 2 * Mr.MARGE + 1) / Mr.PITCH)
  local cells = floor((along - 2 * Mr.MARGE - Mr.TETE) / Mr.PERIODE)
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
function Mr.section(P, modele, row, from, to, names, repere, head)
  local carries = Mr.carries(row.voies)
  local ents, quais, outs = {}, {}, {}
  local function push(list, dest)
    for _, e in ipairs(list) do
      local x, y, d = Mr.to_world(e.x, e.y, e.dir, repere.k, repere.ox, repere.oy, row.j)
      dest[#dest + 1] = { name = e.name, x = x, y = y, dir = d, recipe = e.recipe, role = e.role, carries = e.carries, item = e.item }
    end
  end
  if head then
    local t = Mr.tete(P, row.voies, names)
    push(t.ents, ents)
    for _, q in ipairs(t.quais) do
      local x, y = Mr.to_world(q.x, q.y, nil, repere.k, repere.ox, repere.oy, row.j)
      quais[#quais + 1] = { x = x, y = y, item = q.item }
    end
  end
  for i = from, to do
    local cc = Mr.cellule(modele, i, row.cells[i], names, carries)
    push(cc.ents, ents)
    for _, o in ipairs(cc.outs) do
      local x, y = Mr.to_world(o.x, o.y, nil, repere.k, repere.ox, repere.oy, row.j)
      outs[#outs + 1] = { x = x, y = y, item = o.item }
    end
  end
  return { ents = ents, quais = quais, outs = outs }
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
