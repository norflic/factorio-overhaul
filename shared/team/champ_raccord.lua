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

--- Lot RACCORD-BANDE (partie neuve 0.6.72, INTEG-0672 : « champ: 1 composante(s) de poteaux (11 poteaux) sans chaine jusqu'au reseau alimente »,
--- projets 4 à 6, puis « migration abandonnee apres 3 echec(s) ») : une bande à une centaine de tuiles du réseau, au milieu du gisement et des
--- thermiques, ne trouvait aucune chaîne dans la boîte étroite (poteaux de la bande + poteau cible + 8 tuiles) où le minerai est interdit hors des
--- rangées de la bande. Comme un joueur : d'abord la chaîne d'avant (boîte étroite, minerai interdit), puis AUTOUR (boîte large, minerai toujours
--- interdit), puis À TRAVERS le minerai (un poteau 1x1 ne gêne rien) si c'est le seul chemin. Les tuiles occupées (thermiques, bâtiments, eau,
--- falaises, réserves du plan) ne sont jamais franchies. Coût borné : chaque essai est celui de P.pole_chain (plafonds de Poteaux.path), 3 essais au plus.
-- opts : plafonds de Poteaux.path pour ce palier. Les paliers larges ont un couloir de plus de 600 cellules de 2 tuiles (110 x 52 tuiles) : cellules de
-- 4 tuiles (div 2), donc moins de 400 cellules, plafond relevé à 1 200 ; nœuds développés au plus 700 (2 500 avant) : un palier coûte au plus ~0,5 M
-- d'instructions (~5 ms, mesuré par debug.sethook, tests/raccord_bande_test.lua §6).
Ra.TIERS = {
  { margin = 8, ore = false, name = "boite etroite" },
  { margin = 24, ore = false, name = "autour", opts = { div = 2, max_cells = 1200, max_expand = 450, widths = { 3.5 } } },
  { margin = 24, ore = true, name = "a travers le minerai", opts = { div = 2, max_cells = 1200, max_expand = 450, widths = { 3.5 } } },
}

--- Chaîne de a vers b par paliers. p = {
---   hull       = { x0, y0, x1, y1 } boîte des poteaux de la bande et de leurs cibles les plus proches (sans marge),
---   reach      = portée de fil du poteau obtenable ; pole_chain = fonction (a, b, reach, big, free, known) -> liste | nil (P.pole_chain),
---   blocked    = function(margin) -> function(tx, ty) -> vrai si la tuile est occupée (lecture du moteur, faite au premier besoin de chaque marge),
---   used       = { [clé] = vrai } tuiles déjà prises par les poteaux du plan et les chaînes posées (modifié par l'appelant), key = function(tx, ty),
---   ore        = function(tx, ty) -> vrai si minerai ; rows = function(tx, ty) -> vrai si la tuile est dans une rangée de la bande,
---   tier       = (facultatif) numéro du SEUL palier essayé : l'appelant découpe le travail sur plusieurs ticks (un palier par essai, le coût d'un
---                appel reste celui d'une recherche) ; absent : les trois paliers à la suite }.
--- Rend chaîne (liste de {x, y}), nom du palier retenu ; ou nil, nom du dernier palier essayé.
function Ra.tier_free(p, t)
  local x0, y0 = math.floor(p.hull.x0) - t.margin, math.floor(p.hull.y0) - t.margin
  local x1, y1 = math.ceil(p.hull.x1) + t.margin, math.ceil(p.hull.y1) + t.margin
  local blocked = p.blocked(t.margin)
  local function free(x, y)
    local tx, ty = math.floor(x), math.floor(y)
    if tx < x0 or tx > x1 or ty < y0 or ty > y1 then return false end
    local k = p.key(tx, ty)
    if blocked(tx, ty) or p.used[k] then return false end
    return t.ore or not p.ore(tx, ty) or p.rows(tx, ty)
  end
  return free, { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }, blocked
end

function Ra.tiered_chain(a, b, p)
  local last
  for ti, t in ipairs(Ra.TIERS) do
    if p.tier ~= nil and ti ~= p.tier then goto continue end
    last = t.name
    local free = Ra.tier_free(p, t)
    local ch = p.pole_chain(a, b, p.reach, false, free, nil, t.opts)
    if ch then return ch, t.name end
    ::continue::
  end
  return nil, last
end

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
        fails[#fails + 1] = { n = cnt, d = math.sqrt(best.d2), at = { x = best.first.x, y = best.first.y }, to = { x = best.b.x, y = best.b.y } }
      end
    else
      failed[key(best.first.x, best.first.y)] = true
      local cnt = 0
      for i = 1, #pts do if comp[i] == best.c then cnt = cnt + 1 end end
      fails[#fails + 1] = { n = cnt, d = math.sqrt(best.d2), at = { x = best.first.x, y = best.first.y }, to = { x = best.b.x, y = best.b.y } }
    end
  end
  return added, fails, linked
end

--- Lot RACCORD-BANDE, diagnostic d'un refus (journal seulement, aucune décision ne le lit) : le long du segment de a à b (une tuile sur deux) et dans la
--- boîte du palier (une tuile sur deux), combien de tuiles sont occupées, de minerai, déjà prises, ou libres pour un poteau. free(tx, ty) est la règle du palier.
--- Rend { seg, seg_blocked, seg_ore, seg_used, seg_free, box, box_free }.
function Ra.segment_stats(a, b, box, p, free)
  local dx, dy = b.x - a.x, b.y - a.y
  local n = math.max(1, math.floor(math.sqrt(dx * dx + dy * dy) / 2))
  local out = { seg = 0, seg_blocked = 0, seg_ore = 0, seg_used = 0, seg_free = 0, box = 0, box_free = 0 }
  for i = 0, n do
    local tx, ty = math.floor(a.x + dx * i / n), math.floor(a.y + dy * i / n)
    out.seg = out.seg + 1
    if p.blocked_now(tx, ty) then out.seg_blocked = out.seg_blocked + 1 end
    if p.ore(tx, ty) then out.seg_ore = out.seg_ore + 1 end
    if p.used[p.key(tx, ty)] then out.seg_used = out.seg_used + 1 end
    if free(tx, ty) then out.seg_free = out.seg_free + 1 end
  end
  for tx = box.x0, box.x1, 2 do
    for ty = box.y0, box.y1, 2 do
      out.box = out.box + 1
      if free(tx, ty) then out.box_free = out.box_free + 1 end
    end
  end
  return out
end

--- Lot RACCORD-BANDE 2 : la paire (poteau de la bande, poteau alimenté) la plus proche. Rend { at, to, d } ou nil. Égalité : plus petit x puis y du poteau de la
--- bande, puis de la cible (déterministe).
function Ra.nearest(own, targets)
  local best
  for _, q in ipairs(own) do
    for _, t in ipairs(targets) do
      local d2 = (q.x - t.x) ^ 2 + (q.y - t.y) ^ 2
      if not best or d2 < best.d2 - Ra.EPS then best = { d2 = d2, at = q, to = t } end
    end
  end
  if not best then return nil end
  return { at = { x = best.at.x, y = best.at.y }, to = { x = best.to.x, y = best.to.y }, d = math.sqrt(best.d2) }
end

--- Lot COURANT-BANDE (V0675-A, graine 1618033988) : cause, en clair, d'une bande « sans courant » ([FO-FONDERIE], script/team/champ.lua).
--- `net` = numéro de réseau du premier consommateur sans courant (nil : sous aucun poteau) ; `live` = { [numéro] = true } des réseaux qui portent une
--- génératrice (Gens.networks) ; `kw` = production de CE réseau (kW) ; `dist` = distance au poteau alimenté le plus proche (nil : aucun à `far` tuiles).
--- Défaut mesuré : à 47 et 57 min, « 37 consommateur(s) sans courant, poteau alimente le plus proche a 1 tuiles » : le réseau de la bande ÉTAIT joint
--- (FONCTION : foreuse_elec_reseau 8/8, poteaux_reseau_gen 84/85), la centrale ne produisait rien (machines à vapeur détruites 42,2 → 50,5 min,
--- chaudière à sec 56,3 min) ; la ligne, qui ne lisait jamais le réseau du consommateur, faisait chercher un défaut de câblage inexistant.
function Ra.cause_sans_courant(net, live, kw, dist, far)
  if net == nil then return "sous aucun poteau" end
  if live[net] then
    return string.format("reseau JOINT au reseau alimente (n. %s), production %.0f kW : centrale a sec, detruite ou en chantier, pas un defaut de cablage",
      tostring(net), kw or 0)
  end
  if dist then return string.format("reseau NON joint, poteau alimente le plus proche a %.0f tuiles", dist) end
  return string.format("reseau NON joint, aucun poteau alimente a moins de %d tuiles", far)
end

return Ra
