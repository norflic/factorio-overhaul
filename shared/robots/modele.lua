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

--- Géants admis pour une force à l'âge `age` (lot RB-5) : 0 avant l'âge 13, puis 1, 2, 3.
function M.giants_allowed(age) return Ro.giant_allowed(age) end

--- Le kit peut-il devenir une unité ? p = { used, cap, points, have, keep, giant, giants_have, giants_allowed } : `have` = effectif
--- vivant de CE robot pour la force, `keep` = « maintenir N » de l'usine (nil : pas de limite) ; pour un géant (`giant` vrai) :
--- `giants_have` géants vivants de la force, `giants_allowed` admis à son âge (lot RB-5).
function M.can_release(p)
  if p.used + p.points > p.cap then return false end
  if p.keep ~= nil and p.have >= p.keep then return false end
  if p.giant and (p.giants_have or 0) >= (p.giants_allowed or 0) then return false end
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

--- Ajoute une unité (idempotent : faux si elle est déjà inscrite). Les points entrent dans la force. `home` (lot RB-2) : numéro
--- d'unité de l'atelier d'origine (nil : inconnu ; inscription d'avant le lot) ; il donne le ralliement de l'unité.
function M.add(l, force, unit_number, id, points, home)
  if l.units[unit_number] then return false end
  l.units[unit_number] = { force = force, id = id, points = points, home = home }
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

--- Géants vivants d'une force (lot RB-5) : somme des effectifs des robots à chaîne de segments.
function M.giants_of(l, force)
  local n = 0
  for _, r in ipairs(Ro.ROBOTS) do
    if r.is_giant then n = n + M.have(l, force, r.id) end
  end
  return n
end

--- Numéros d'unité inscrits d'un robot (toutes forces), triés (lot RB-4 : soutien, géants).
function M.units_with(l, id)
  local out = {}
  for _, un in ipairs(l.order) do
    if l.units[un].id == id then out[#out + 1] = un end
  end
  return out
end
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

--- Numéros d'unité inscrits dont l'atelier d'origine est `home`, triés.
function M.units_at(l, home)
  local out = {}
  for _, un in ipairs(l.order) do
    if l.units[un].home == home then out[#out + 1] = un end
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

--- Lot RB-2 : édition de la file par le joueur. « Maintenir N » d'un robot EST une entrée de la file ; l'ordre des entrées est
--- l'ordre de préférence. Toutes ces fonctions rendent une file NEUVE (la file reçue n'est jamais modifiée).
local function copy_queue(queue)
  local out = {}
  for i, q in ipairs(queue or {}) do out[i] = { id = q.id, n = q.n } end
  return out
end

--- Cible (« maintenir N ») d'un robot dans la file, ou nil (pas de limite).
function M.queue_target(queue, id)
  for _, q in ipairs(queue or {}) do
    if q.id == id then return q.n end
  end
  return nil
end

--- Fixe la cible d'un robot : n entier ramené dans 0 à KEEP_MAX ; une entrée présente garde sa place, une entrée neuve passe en
--- queue de file (refusée au-delà de QUEUE_MAX ou pour un robot inconnu de `known`) ; n nil retire l'entrée.
--- Rend (file neuve, vrai si la file a changé).
function M.queue_set(queue, id, n, known)
  local out = copy_queue(queue)
  if n == nil then
    for i, q in ipairs(out) do
      if q.id == id then table.remove(out, i) return out, true end
    end
    return out, false
  end
  if known and not known[id] then return out, false end
  if type(n) ~= "number" or n ~= n then return out, false end
  n = max(0, min(Ro.KEEP_MAX, floor(n)))
  for _, q in ipairs(out) do
    if q.id == id then
      local changed = q.n ~= n
      q.n = n
      return out, changed
    end
  end
  if #out >= Ro.QUEUE_MAX then return out, false end
  out[#out + 1] = { id = id, n = n }
  return out, true
end

--- Monte (delta < 0) ou descend (delta > 0) une entrée d'un cran ; sans effet aux extrémités. Rend (file neuve, changée).
function M.queue_move(queue, id, delta)
  local out = copy_queue(queue)
  for i, q in ipairs(out) do
    if q.id == id then
      local j = i + (delta < 0 and -1 or 1)
      if j < 1 or j > #out then return out, false end
      out[i], out[j] = out[j], out[i]
      return out, true
    end
  end
  return out, false
end

--- Le robot que l'atelier doit fabriquer : la file n'impose une recette qu'à partir de DEUX entrées (une seule entrée est un simple
--- « maintenir N » : la recette reste celle du joueur), ou à un atelier SANS recette (`current_id` nil) dont la file est non vide.
--- `have[id]` = effectif vivant + kits en attente ; rend l'id voulu, ou nil (rien à changer : cibles atteintes, ou recette libre).
function M.recipe_wanted(queue, have, current_id)
  local n = #(queue or {})
  if n == 0 then return nil end
  if n < 2 and current_id ~= nil then return nil end
  local want = M.queue_next(queue, have)
  if want == nil or want == current_id then return nil end
  return want
end

--- Peut-on changer la recette maintenant ? p = { current (id ou nil), progress (0 à 1), output_blocked (kits d'une cible atteinte
--- seulement), output_empty, since (ticks depuis le dernier changement), min_gap (durée d'une fabrication, en ticks) }.
--- Pas de changement en cours de fabrication, ni avant qu'une fabrication entière ait pu s'achever (RB0 E7 : un changement plus
--- rapide n'en achève aucune) ; une sortie qui ne contient que des kits bloqués ne retient pas le changement.
function M.recipe_switch_ok(p)
  if p.current == nil then return true end
  if (p.progress or 0) > 0 then return false end
  if not (p.output_empty or p.output_blocked) then return false end
  return (p.since or 0) >= (p.min_gap or 0)
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
