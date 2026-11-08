--- Lot RANGEES-ASM (suite, plan accepté le 8/11) : rangée d'assembleurs DYNAMIQUE, règles pures.
--- Comme la ligne de fours (FONDERIE-DYNAMIQUE), la rangée est planifiée ENTIÈRE à la borne de son gabarit (place réservée dans
--- le lot) ; seules n machines et leurs bras sont posés, les autres attendent (p.rangee.held) et sont rendus au chantier quand la
--- demande monte (script/team/rangee_dyn.lua). Tapis et poteaux sont TOUJOURS posés en entier : agrandir n'ajoute que des machines
--- et leurs bras, l'entrée et la sortie restent les mêmes, le réseau électrique ne se coupe jamais.
--- Aucun nom d'objet ; l'appelant donne le genre de chaque entité (kind(name) -> "machine" | "inserter" | autre) et sa largeur.
local Rd = {}

--- Colonne (machine 1..m, d'ouest en est dans le gabarit NON tourné) de chaque machine et de chaque bras posé dans l'emprise en x
--- d'une machine (bras du haut et de sortie). entities = { { name, x, y } } (centres) ; kind(name), width(name).
--- Rend cols { [indice] = colonne } et le nombre de machines.
function Rd.columns(entities, kind, width)
  local ms = {}
  for i, e in ipairs(entities or {}) do
    if kind(e.name) == "machine" then
      local w = width(e.name) or 1
      ms[#ms + 1] = { i = i, x0 = e.x - w / 2, x1 = e.x + w / 2 }
    end
  end
  table.sort(ms, function(a, b)
    if a.x0 ~= b.x0 then return a.x0 < b.x0 end
    return a.i < b.i
  end)
  local cols = {}
  for k, m in ipairs(ms) do cols[m.i] = k end
  for i, e in ipairs(entities or {}) do
    if kind(e.name) == "inserter" then
      for k, m in ipairs(ms) do
        if e.x > m.x0 and e.x < m.x1 then cols[i] = k break end
      end
    end
  end
  return cols, #ms
end

--- Ordre d'activation des colonnes 1..n : d'ouest en est ; avec une jonction après la machine `jn` (sortie sur deux voies), de la
--- jonction vers les bords en alternant (jn, jn+1, jn−1, jn+2, …) : les deux tronçons de sortie restent équilibrés.
function Rd.order(n, jn)
  local out = {}
  if not (jn and jn >= 1 and jn < n) then
    for i = 1, n do out[i] = i end
    return out
  end
  local w, e = jn, jn + 1
  while #out < n do
    if w >= 1 then out[#out + 1] = w w = w - 1 end
    if e <= n then out[#out + 1] = e e = e + 1 end
  end
  return out
end

--- Colonnes actives pour n machines posées : { [colonne] = vrai }.
function Rd.active(order, n)
  local a = {}
  for i = 1, math.min(n or 0, #(order or {})) do a[order[i]] = true end
  return a
end

--- Découpe des entités 1..count : gardées (sans colonne, ou colonne active) et en attente. Rend deux listes d'indices.
function Rd.split(cols, count, order, n)
  local a = Rd.active(order, n)
  local keep, held = {}, {}
  for i = 1, count do
    local c = cols[i]
    if c and not a[c] then held[#held + 1] = i else keep[#keep + 1] = i end
  end
  return keep, held
end

--- Croissance : machines posées après la demande d'aller à n2 (bornée par n_max ; jamais moins que n). Rend n', ajoutées.
function Rd.grow(n, n_max, n2)
  local t = math.max(n or 0, math.min(n_max or 0, math.floor(n2 or 0)))
  return t, t - (n or 0)
end

return Rd
