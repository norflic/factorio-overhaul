--[[
  Lot FONDERIE (3/11, diagnostic d'ENERGIE4 sur lot7bis-20261020) : TOUS les poteaux d'une bande de champ rejoignent le réseau alimenté.

  Défaut mesuré : le raccord d'une bande partait du SEUL poteau le plus proche du réseau alimenté ; une autre composante des poteaux du plan
  (colonne loin du centre, ligne de foreuses du charbon) restait hors réseau toute la partie (réseau 275 : 15 à 22 bras sur 16 à 20 poteaux,
  à 101 tuiles du réseau alimenté, de 50 à 130 min ; réseau 187 : 4 foreuses de charbon à 65 tuiles).

  Règle (pure, déterministe) :
    1. composantes des poteaux du plan : deux poteaux à portée de fil (`reach`) sont reliés (le moteur relie seul les poteaux à portée) ;
    2. une composante est raccordée si l'un de ses poteaux est à portée d'une CIBLE (poteau du réseau alimenté, ou poteau d'un autre projet
       du même champ, raccordé par cette même règle) ;
    3. tant qu'il reste une composante non raccordée : celle dont la paire (poteau, cible ou poteau raccordé) est la plus courte reçoit une
       chaîne de poteaux (`chain(a, b)`, P.pole_chain dans le jeu) ; ses poteaux deviennent des cibles ;
    4. une composante qu'aucune chaîne ne joint est rendue dans `fails` (la bande ne se pose pas : jamais de machines sans courant).
]]

local Ra = {}
Ra.EPS = 1e-6

local function key(x, y) return (math.floor(x) + 50000) * 100000 + (math.floor(y) + 50000) end

--- Composantes des points `pts` ({x, y}) à portée `r` : comp[i] = numéro de composante (1..n, dans l'ordre du premier point), n.
function Ra.components(pts, r)
  local parent = {}
  for i = 1, #pts do parent[i] = i end
  local function root(i) while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end return i end
  local cell = math.max(1, math.ceil(r))
  local grid = {}
  for i, p in ipairs(pts) do
    local k = key(p.x / cell, p.y / cell)
    grid[k] = grid[k] or {}
    grid[k][#grid[k] + 1] = i
  end
  local r2 = r * r + Ra.EPS
  for i, p in ipairs(pts) do
    local gx, gy = math.floor(p.x / cell), math.floor(p.y / cell)
    for dx = -1, 1 do
      for dy = -1, 1 do
        for _, j in ipairs(grid[key(gx + dx, gy + dy)] or {}) do
          local q = pts[j]
          if j > i and (p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 <= r2 then
            local a, b = root(i), root(j)
            if a ~= b then if a < b then parent[b] = a else parent[a] = b end end
          end
        end
      end
    end
  end
  local comp, num, n = {}, {}, 0
  for i = 1, #pts do
    local rt = root(i)
    if not num[rt] then n = n + 1; num[rt] = n end
    comp[i] = num[rt]
  end
  return comp, n
end

--- Raccorde toutes les composantes de `own` (poteaux du plan) aux `targets` (poteaux alimentés ou raccordés).
--- chain(a, b) -> liste de {x, y} (poteaux intermédiaires de a vers b) ou nil. Rend added (poteaux posés, dans l'ordre), fails
--- ({ n = poteaux, d = distance de sa paire la plus courte, at = {x, y} }), linked (composantes jointes par une chaîne).
function Ra.connect(own, targets, r, chain)
  local added, fails, linked = {}, {}, 0
  local r2 = r * r + Ra.EPS
  local tgt = {}
  for _, t in ipairs(targets or {}) do tgt[#tgt + 1] = { x = t.x, y = t.y } end
  local failed = {} -- clé du premier poteau d'une composante sans chaîne
  for _ = 1, #own + 1 do
    local pts = {}
    for _, p in ipairs(own) do pts[#pts + 1] = p end
    for _, p in ipairs(added) do pts[#pts + 1] = p end
    local comp, n = Ra.components(pts, r)
    -- composantes raccordées : un poteau à portée d'une cible
    local ok = {}
    for i, p in ipairs(pts) do
      if not ok[comp[i]] then
        for _, t in ipairs(tgt) do
          if (p.x - t.x) ^ 2 + (p.y - t.y) ^ 2 <= r2 then ok[comp[i]] = true break end
        end
      end
    end
    -- cibles du tour : cibles données et poteaux des composantes raccordées
    local reach_to = {}
    for _, t in ipairs(tgt) do reach_to[#reach_to + 1] = t end
    for i, p in ipairs(pts) do if ok[comp[i]] then reach_to[#reach_to + 1] = p end end
    -- composante non raccordée la plus proche d'une cible (paire la plus courte ; égalité : composante de plus petit numéro)
    local best
    for c = 1, n do
      local first
      for i = 1, #pts do if comp[i] == c then first = pts[i] break end end
      if not ok[c] and not failed[key(first.x, first.y)] then
        for i, p in ipairs(pts) do
          if comp[i] == c then
            for _, t in ipairs(reach_to) do
              local d2 = (p.x - t.x) ^ 2 + (p.y - t.y) ^ 2
              if not best or d2 < best.d2 - Ra.EPS then best = { c = c, a = p, b = t, d2 = d2, first = first } end
            end
          end
        end
      end
    end
    if not best then
      -- plus rien à joindre (ou plus aucune cible) : les composantes restantes sont des échecs
      for c = 1, n do
        if not ok[c] then
          local cnt, first = 0, nil
          for i = 1, #pts do if comp[i] == c then cnt = cnt + 1; first = first or pts[i] end end
          if not failed[key(first.x, first.y)] then fails[#fails + 1] = { n = cnt, d = nil, at = { x = first.x, y = first.y } } end
        end
      end
      return added, fails, linked
    end
    local ch = chain({ x = best.a.x, y = best.a.y }, { x = best.b.x, y = best.b.y })
    if ch then
      for _, q in ipairs(ch) do added[#added + 1] = { x = q.x, y = q.y } end
      linked = linked + 1
      -- une chaîne vide (paire déjà à portée) ne peut arriver qu'à une composante déjà raccordée : garde contre la boucle
      if #ch == 0 and best.d2 > r2 then
        failed[key(best.first.x, best.first.y)] = true
        local cnt = 0
        for i = 1, #pts do if comp[i] == best.c then cnt = cnt + 1 end end
        fails[#fails + 1] = { n = cnt, d = math.sqrt(best.d2), at = { x = best.first.x, y = best.first.y } }
      end
    else
      failed[key(best.first.x, best.first.y)] = true
      local cnt = 0
      for i = 1, #pts do if comp[i] == best.c then cnt = cnt + 1 end end
      fails[#fails + 1] = { n = cnt, d = math.sqrt(best.d2), at = { x = best.first.x, y = best.first.y } }
    end
  end
  return added, fails, linked
end

return Ra
