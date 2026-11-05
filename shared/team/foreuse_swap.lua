--[[
  Lot FOREUSES (retour du DC du 29/10, partie de 1 h 30 sur 0.6.13 : « des foreuses thermiques encore presentes malgre la tech 2,
  alors qu'ils peuvent mettre des foreuses electriques a la place »). PUR (aucune API Factorio, aucun nom d'objet : les noms et
  les dimensions viennent de shared/team/config.lua et du moteur, passes par l'appelant).

  Regle : le TYPE de foreuse suit l'objet (obtenable : au stock ou fabricable) ET le courant (un poteau de l'equipe dont la zone
  d'alimentation touche la foreuse, sur un reseau qui produit). Une foreuse a combustion deja posee, dont le recepteur (four ou
  coffre) recoit le minerai, est remplacee sur place par une electrique de 3 x 3 : meme direction, recepteur inchange, centre
  choisi pour que le point de depot de l'electrique tombe dans le recepteur sans que la nouvelle boite le recouvre.

  Lot FOREUSES-THERMIQUES (decision du DC, 5/11 : « Remplacer au fur et a mesure », avec leur poteau, meme hors des bandes du champ) :
  une foreuse SANS poteau alimente a portee est remplacee quand une chaine d'au plus S.CHAIN_MAX poteaux la relie au poteau alimente le
  plus proche (S.pole_plan : places du dernier poteau autour de la boite, recherche de chemin de shared/team/plan.lua P.pole_chain,
  connexite verifiee par S.chain_ok) ; S.power_ok garde la marge de la centrale ; S.pole_item choisit le poteau (stock, puis fabricable).

  Directions : 0 nord, 2 est, 4 sud, 6 ouest (defines.direction). Boites : { x, y, w, h } (centre et taille, en tuiles).
]]

local S = {}

local EPS = 1e-6

--- Vecteur (x, y) tourne selon la direction (sens horaire, depuis le nord) : meme regle que le depot d'une foreuse du moteur.
function S.rotate(dir, x, y)
  if dir == 2 then return -y, x end
  if dir == 4 then return -x, -y end
  if dir == 6 then return y, -x end
  return x, y
end

--- Deux boites se recouvrent-elles (les contacts par un bord ne comptent pas) ?
function S.overlap(a, b)
  return math.abs(a.x - b.x) < (a.w + b.w) / 2 - EPS and math.abs(a.y - b.y) < (a.h + b.h) / 2 - EPS
end

--- Le point est-il dans la boite (intervalle ouvert) ?
function S.inside(box, px, py)
  return math.abs(px - box.x) < box.w / 2 - EPS and math.abs(py - box.y) < box.h / 2 - EPS
end

--- Centre de la foreuse electrique qui remplace une foreuse a combustion posee en (bx, by) dans la direction `dir`, ou nil.
--- `sink` : boite du recepteur ; `spec` = { size = 3, drop = { dx, dy } } (point de depot de l'electrique vers le nord).
--- La boite de l'electrique (size x size, centree sur un demi-entier) doit contenir l'ancienne emprise (2 x 2 centree sur un entier :
--- centres a demi-tuile), ne pas recouvrir le recepteur, et deposer dans le recepteur. Choix : le plus proche de l'ancien centre,
--- puis x, puis y croissants (deterministe).
function S.electric_center(bx, by, dir, sink, spec)
  local best, best_d
  local vx, vy = S.rotate(dir, spec.drop[1], spec.drop[2])
  for _, ox in ipairs({ -0.5, 0.5 }) do
    for _, oy in ipairs({ -0.5, 0.5 }) do
      local cx, cy = bx + ox, by + oy
      local box = { x = cx, y = cy, w = spec.size, h = spec.size }
      if S.inside(sink, cx + vx, cy + vy) and not S.overlap(box, sink) then
        local d = ox * ox + oy * oy
        if not best_d or d < best_d - EPS or (math.abs(d - best_d) <= EPS and (cx < best[1] or (cx == best[1] and cy < best[2]))) then
          best, best_d = { cx, cy }, d
        end
      end
    end
  end
  if not best then return nil end
  return best[1], best[2]
end

--- La zone d'alimentation (carre de demi-cote `dist` autour du poteau) touche-t-elle la boite de la foreuse ?
function S.covered(px, py, dist, box)
  return S.overlap({ x = px, y = py, w = 2 * dist, h = 2 * dist }, box)
end

--- Type de foreuse choisi : "electric" quand l'objet est obtenable ET le courant arrive ; "burner" sinon.
function S.choose_type(obtainable, powered)
  if obtainable and powered then return "electric" end
  return "burner"
end

--- Remplacements a faire cette fois. entries : liste de { id, x, y, dir, sink = boite } (foreuses a combustion posees) ;
--- ctx = { poles = { { x, y, dist, powered } }, electric = spec, have = nombre d'objets electriques au stock, obtainable = bool,
--- limit = remplacements au plus }. Rend une liste triee par id de { id, cx, cy } (au plus min(limit, have)), et le nombre de
--- candidats alimentes (`n_ready`, pour fabriquer ce qui manque).
--- Lot FOREUSES-THERMIQUES : avec ctx.pole = { supply, wire } (poteau a poser), ctx.free_for(entree, boite) -> free(x, y) et ctx.chain
--- (P.pole_chain), une foreuse SANS poteau alimente a portee devient candidate quand une chaine d'au plus ctx.chain_max poteaux l'atteint :
--- les deja alimentees d'abord, puis les moins de poteaux estimes, puis l'id. Chaque sortie porte `poles` (liste a poser, vide si deja
--- alimentee). Rend aussi le nombre de candidats a chaine (`n_chain`, estime). `n_ready` garde son sens : candidats DEJA alimentes (lu par
--- script/team/gisement.lua : la politique des paires thermiques ne change pas).
function S.plan(entries, ctx)
  local ready, chained = {}, {}
  local list = {}
  for _, e in ipairs(entries) do list[#list + 1] = e end
  table.sort(list, function(a, b) return a.id < b.id end)
  for _, e in ipairs(list) do
    local cx, cy = S.electric_center(e.x, e.y, e.dir, e.sink, ctx.electric)
    if cx then
      local box = { x = cx, y = cy, w = ctx.electric.size, h = ctx.electric.size }
      local powered = false
      for _, p in ipairs(ctx.poles) do
        if p.powered and S.covered(p.x, p.y, p.dist, box) then powered = true break end
      end
      if S.choose_type(ctx.obtainable, powered) == "electric" then
        ready[#ready + 1] = { id = e.id, cx = cx, cy = cy, poles = {}, est = 0 }
      elseif ctx.obtainable and ctx.pole then
        local est = S.reach_estimate(box, ctx.poles, ctx.pole, ctx.chain_max)
        if est then chained[#chained + 1] = { id = e.id, cx = cx, cy = cy, est = est, e = e, box = box } end
      end
    end
  end
  table.sort(chained, function(a, b) if a.est ~= b.est then return a.est < b.est end return a.id < b.id end)
  local out = {}
  local n = math.min(ctx.limit or (#ready + #chained), ctx.have or 0)
  for i = 1, math.min(n, #ready) do out[#out + 1] = ready[i] end
  ctx.refused = ctx.refused or {}
  local tries = 0
  for _, c in ipairs(chained) do
    if #out >= n or tries >= (ctx.tries or S.TRIES) then break end
    tries = tries + 1
    local plan, why = S.pole_plan(c.box, ctx.poles, ctx.pole, ctx.free_for(c.e, c.box), { max = ctx.chain_max, chain = ctx.chain })
    if plan then
      out[#out + 1] = { id = c.id, cx = c.cx, cy = c.cy, poles = plan.poles, source = plan.source, est = c.est }
    else
      ctx.refused[#ctx.refused + 1] = { id = c.id, why = why }
    end
  end
  return out, #ready, #chained
end

--- Objets electriques a fabriquer : les candidats alimentes (au plus `cap`) moins ceux deja au stock.
function S.demand(n_ready, have, cap)
  return math.max(0, math.min(n_ready, cap) - have)
end

---------------------------------------------------------------------------------------------------
-- Lot FOREUSES-THERMIQUES (decision du DC par QCM, 5/11 20 h 47 : « Remplacer au fur et a mesure » : les thermiques existantes sont
-- remplacees une a une par des electriques AVEC LEUR POTEAU, meme hors des bandes du champ). Avant ce lot, une foreuse sans poteau
-- alimente a portee n'etait jamais remplacee : 5 remplacements en 150 min dans la partie du DC (0.6.53), 201 thermiques de fer.
-- Le remplacement pose LUI-MEME une chaine bornee de poteaux depuis le poteau alimente le plus proche.
---------------------------------------------------------------------------------------------------
S.CHAIN_MAX = 6      -- poteaux neufs au plus par remplacement (6 petits poteaux : 45 tuiles de fil)
S.SOURCES = 4        -- poteaux alimentes essayes au plus (les plus proches)
S.TARGETS = 3        -- places du dernier poteau essayees par source (les plus proches de la source)
S.TRIES = 4          -- plans de chaine calcules au plus par passe (un refus est remis a plus tard par l'executant : Swap.RETRY)

local function d2(a, b) local dx, dy = a.x - b.x, a.y - b.y; return dx * dx + dy * dy end

--- Places possibles du DERNIER poteau : centres de tuile dont la zone d'alimentation (demi-cote `supply`) touche la boite, hors de la boite,
--- libres (free(x, y)). Triees par distance au centre de la boite, puis y, puis x.
function S.pole_targets(box, supply, free)
  local out = {}
  local r = math.floor(box.w / 2 + supply) + 1
  local bx, by = math.floor(box.x), math.floor(box.y)
  for ty = by - r, by + r do
    for tx = bx - r, bx + r do
      local p = { x = tx + 0.5, y = ty + 0.5 }
      if S.covered(p.x, p.y, supply, box) and not S.overlap({ x = p.x, y = p.y, w = 1, h = 1 }, box) and free(p.x, p.y) then
        out[#out + 1] = p
      end
    end
  end
  table.sort(out, function(a, b)
    local da, db = d2(a, box), d2(b, box)
    if math.abs(da - db) > EPS then return da < db end
    if a.y ~= b.y then return a.y < b.y end
    return a.x < b.x
  end)
  return out
end

--- La chaine est-elle connexe ? source { x, y }, poles (dans l'ordre de pose), reach : chaque maillon a `reach` au plus du precedent.
function S.chain_ok(source, poles, reach)
  local prev = source
  for _, p in ipairs(poles) do
    if d2(prev, p) > reach * reach + EPS then return false end
    prev = p
  end
  return true
end

--- Plan des poteaux qui alimentent une foreuse electrique de boite `box`. sources : poteaux de l'equipe { x, y, dist (demi-cote de la zone),
--- wire (portee de fil), powered } ; pole : { supply, wire } du poteau a poser ; free(x, y) : centre de tuile ou un poteau peut aller ;
--- opts = { max, sources, targets, chain (a, b, reach, big, free) }. Rend { poles = { { x, y }, ... } dans l'ordre de pose, source }
--- (poles vide : deja alimentee) ou nil, raison. Choix : le moins de poteaux neufs, puis le moins de fil, puis l'ordre des sources
--- (distance, y, x) et des places : deterministe.
function S.pole_plan(box, sources, pole, free, opts)
  opts = opts or {}
  local maxn = opts.max or S.CHAIN_MAX
  local chain = opts.chain
  local live = {}
  for _, s in ipairs(sources or {}) do
    if s.powered then
      if S.covered(s.x, s.y, s.dist, box) then return { poles = {}, source = s } end
      live[#live + 1] = s
    end
  end
  if #live == 0 then return nil, "aucun poteau alimente" end
  local cand = {}
  for _, s in ipairs(live) do
    local reach = math.min(pole.wire, s.wire or pole.wire)
    local lim = maxn * reach + pole.supply + box.w
    if d2(s, box) <= lim * lim then cand[#cand + 1] = { s = s, reach = reach, d = d2(s, box) } end
  end
  if #cand == 0 then return nil, "reseau trop loin" end
  table.sort(cand, function(a, b)
    if math.abs(a.d - b.d) > EPS then return a.d < b.d end
    if a.s.y ~= b.s.y then return a.s.y < b.s.y end
    return a.s.x < b.s.x
  end)
  local targets = S.pole_targets(box, pole.supply, free)
  if #targets == 0 then return nil, "aucune place de poteau" end
  local best
  for i = 1, math.min(#cand, opts.sources or S.SOURCES) do
    local c = cand[i]
    local ts = {}
    for k, t in ipairs(targets) do ts[k] = t end
    table.sort(ts, function(a, b)
      local da, db = d2(a, c.s), d2(b, c.s)
      if math.abs(da - db) > EPS then return da < db end
      if a.y ~= b.y then return a.y < b.y end
      return a.x < b.x
    end)
    for j = 1, math.min(#ts, opts.targets or S.TARGETS) do
      local t = ts[j]
      local mid
      if d2(c.s, t) <= c.reach * c.reach + EPS then mid = {} else mid = chain and chain(c.s, t, c.reach, false, free) end
      if mid and #mid + 1 <= maxn then
        local list = {}
        for _, m in ipairs(mid) do list[#list + 1] = { x = m.x, y = m.y } end
        list[#list + 1] = { x = t.x, y = t.y }
        if S.chain_ok(c.s, list, c.reach) then
          local len, prev = 0, c.s
          for _, p in ipairs(list) do len = len + math.sqrt(d2(prev, p)); prev = p end
          if not best or #list < #best.poles or (#list == #best.poles and len < best.len - EPS) then
            best = { poles = list, source = c.s, len = len }
          end
        end
      end
    end
  end
  if not best then return nil, "chaine de poteaux impossible" end
  return { poles = best.poles, source = best.source }
end

--- Estimation (sans recherche de chemin) : la boite est-elle a portee d'une chaine de `maxn` poteaux depuis un poteau alimente ? Rend le nombre
--- de poteaux neufs estime (0 : deja alimentee) ou nil. Sert au compte des candidats (fabrication d'avance), jamais a la pose.
function S.reach_estimate(box, sources, pole, maxn)
  maxn = maxn or S.CHAIN_MAX
  local best
  for _, s in ipairs(sources or {}) do
    if s.powered then
      if S.covered(s.x, s.y, s.dist, box) then return 0 end
      local reach = math.min(pole.wire, s.wire or pole.wire)
      local gap = math.max(0, math.sqrt(d2(s, box)) - pole.supply - box.w / 2)
      local n = math.max(1, math.ceil(gap / reach - EPS))
      if n <= maxn and (not best or n < best) then best = n end
    end
  end
  return best
end

--- Puissance : un remplacement de `kw` kW passe-t-il ? c = { capacity, used, committed } (kW) ; sans centrale connue (capacite nulle) : vrai
--- (le poteau source est sur un reseau qui produit). draw : part tiree des chantiers (comme shared/team/sante_centrale.lua S.DRAW).
function S.power_ok(c, kw, draw)
  if not (c and c.capacity and c.capacity > 0) then return true end
  return (c.used or 0) + (draw or 0.6) * (c.committed or 0) + (kw or 0) <= c.capacity + EPS
end

--- Poteau a poser : le premier de `list` ({ name, have, craftable } dans l'ordre de preference) qui est au stock, sinon le premier fabricable.
function S.pole_item(list)
  for _, p in ipairs(list or {}) do if (p.have or 0) > 0 then return p.name end end
  for _, p in ipairs(list or {}) do if p.craftable then return p.name end end
  return nil
end

return S
