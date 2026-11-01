--[[
  Lot RB-1 CHAÎNE (31/10) : MODÈLE des robots, règles pures (aucune API du jeu ; tests/robots_test.lua).
    - plafond : points par force (12 + 6 × âge, ou le réglage) ; un kit n'est retiré (donc l'unité créée) que s'il reste de la
      place ET que « maintenir N » n'est pas atteint (PLAN §3 : la sortie se bloque, la machine s'arrête d'elle-même, RB0-3) ;
    - registre (« ledger ») des unités vivantes : points utilisés et effectif par force et par robot, tenus en nombres et
      chaînes (sauvegardables), parcourus en LISTE TRIÉE par numéro d'unité (jamais pairs dans une décision) ;
    - file d'une usine (liste ordonnée de { robot, n }) : le premier robot dont l'effectif est sous sa cible ;
    - point de sortie et de ralliement d'une usine.
  Les noms de prototypes viennent de shared/content/robots.lua ; ce fichier n'en nomme aucun.
]]

local Ro = require("shared.content.robots")

local M = {}

local floor, max, min = math.floor, math.max, math.min

---------------------------------------------------------------------------------------------------
-- 1. Plafond en points
---------------------------------------------------------------------------------------------------
--- Âge ramené dans 1 à 15 (nil, 0 ou négatif : 1).
function M.age_clamped(age)
  return max(1, min(Ro.AGES, floor(tonumber(age) or 1)))
end

--- Plafond en points : le réglage s'il est positif, sinon 12 + 6 × âge.
function M.cap(age, override)
  if override and override > 0 then return floor(override) end
  return Ro.CAP_BASE + Ro.CAP_PER_AGE * M.age_clamped(age)
end

--- Points libres.
function M.room(used, cap) return max(0, cap - used) end

--- Le kit peut-il devenir une unité ? p = { used, cap, points, have, keep } : `have` = effectif vivant de CE robot pour la
--- force, `keep` = « maintenir N » de l'usine (nil : pas de limite).
function M.can_release(p)
  if p.used + p.points > p.cap then return false end
  if p.keep ~= nil and p.have >= p.keep then return false end
  return true
end

---------------------------------------------------------------------------------------------------
-- 2. Registre des unités vivantes
---------------------------------------------------------------------------------------------------
function M.new_ledger()
  return { units = {}, order = {}, used = {}, by_id = {}, forces = {} }
end

local function insert_sorted(list, v)
  local i = #list
  while i >= 1 and list[i] > v do i = i - 1 end
  if list[i] == v then return false end
  table.insert(list, i + 1, v)
  return true
end

local function remove_value(list, v)
  for i = 1, #list do
    if list[i] == v then table.remove(list, i) return true end
  end
  return false
end

--- Ajoute une unité (idempotent : faux si elle est déjà inscrite). Les points entrent dans la force.
function M.add(l, force, unit_number, id, points)
  if l.units[unit_number] then return false end
  l.units[unit_number] = { force = force, id = id, points = points }
  insert_sorted(l.order, unit_number)
  if l.used[force] == nil then
    l.used[force], l.by_id[force] = 0, {}
    insert_sorted(l.forces, force)
  end
  l.used[force] = l.used[force] + points
  l.by_id[force][id] = (l.by_id[force][id] or 0) + 1
  return true
end

--- Retire une unité (idempotent : nil si elle n'est pas inscrite) ; rend (force, robot, points) et libère ses points.
function M.remove(l, unit_number)
  local u = l.units[unit_number]
  if not u then return nil end
  l.units[unit_number] = nil
  remove_value(l.order, unit_number)
  l.used[u.force] = l.used[u.force] - u.points
  l.by_id[u.force][u.id] = l.by_id[u.force][u.id] - 1
  return u.force, u.id, u.points
end

function M.used(l, force) return l.used[force] or 0 end
function M.have(l, force, id) return (l.by_id[force] and l.by_id[force][id]) or 0 end
function M.count(l) return #l.order end

--- Numéros d'unité inscrits d'une force, triés.
function M.units_of(l, force)
  local out = {}
  for _, un in ipairs(l.order) do
    if l.units[un].force == force then out[#out + 1] = un end
  end
  return out
end

--- Retire du registre les unités que `is_valid(numéro)` refuse (balayage de sécurité) ; rend la liste des retirées.
function M.prune(l, is_valid)
  local gone = {}
  local snapshot = {}
  for i, un in ipairs(l.order) do snapshot[i] = un end
  for _, un in ipairs(snapshot) do
    if not is_valid(un) then
      gone[#gone + 1] = un
      M.remove(l, un)
    end
  end
  return gone
end

--- Cohérence interne : points = somme des unités, effectifs = compte des unités, liste triée sans doublon.
--- Rend (vrai) ou (faux, raison).
function M.check(l)
  local used, by = {}, {}
  for i, un in ipairs(l.order) do
    if i > 1 and l.order[i - 1] >= un then return false, "liste non triée" end
    local u = l.units[un]
    if not u then return false, "numéro sans unité" end
    used[u.force] = (used[u.force] or 0) + u.points
    by[u.force] = by[u.force] or {}
    by[u.force][u.id] = (by[u.force][u.id] or 0) + 1
  end
  for _, force in ipairs(l.forces) do
    if (l.used[force] or 0) ~= (used[force] or 0) then return false, "points de " .. force end
    for _, r in ipairs(Ro.ROBOTS) do
      if (l.by_id[force][r.id] or 0) ~= ((by[force] or {})[r.id] or 0) then return false, "effectif de " .. force .. "/" .. r.id end
    end
  end
  return true
end

---------------------------------------------------------------------------------------------------
-- 3. File d'une usine : « maintenir N » dans l'ordre
---------------------------------------------------------------------------------------------------
--- Premier robot de la file dont l'effectif (`have[robot]`) est sous sa cible, ou nil. queue = { { id, n }, ... } ;
--- une cible nulle ou négative est sautée.
function M.queue_next(queue, have)
  for _, q in ipairs(queue or {}) do
    if (have[q.id] or 0) < q.n then return q.id end
  end
  return nil
end

--- Une file est valide si chaque entrée nomme un robot de `known` (table { [id] = true }) avec n entier ≥ 0.
function M.queue_valid(queue, known)
  for _, q in ipairs(queue or {}) do
    if not known[q.id] then return false end
    if type(q.n) ~= "number" or q.n < 0 or q.n ~= floor(q.n) then return false end
  end
  return true
end

---------------------------------------------------------------------------------------------------
-- 4. Géométrie d'une usine : sortie au sud, ralliement plus loin
---------------------------------------------------------------------------------------------------
--- Point de sortie (centre de recherche d'une place libre) : sous le bord sud de la machine, plus 2 tuiles.
function M.out_point(pos, size)
  return { x = pos.x, y = pos.y + size / 2 + 2 }
end

--- Ralliement par défaut : au sud du point de sortie.
function M.default_rally(pos, size)
  local o = M.out_point(pos, size)
  return { x = o.x, y = o.y + Ro.RALLY_DEPTH }
end

--- Distance entre deux points (tuiles).
function M.dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

---------------------------------------------------------------------------------------------------
-- 5. Ordres : le centre d'une sélection
---------------------------------------------------------------------------------------------------
--- Une position valide d'ordre : table { x, y } de nombres finis.
function M.valid_point(p)
  if type(p) ~= "table" then return false end
  local x, y = p.x or p[1], p.y or p[2]
  if type(x) ~= "number" or type(y) ~= "number" then return false end
  return x == x and y == y and math.abs(x) < 1e7 and math.abs(y) < 1e7
end

function M.is_order(kind)
  for _, k in ipairs(Ro.ORDERS) do
    if k == kind then return true end
  end
  return false
end

return M
