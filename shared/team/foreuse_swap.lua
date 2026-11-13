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
local abs, floor = math.abs, math.floor
-- Lot S5 (×10) : décalages des centres candidats de S.electric_centers, sans table littérale à chaque appel, et leur ordre (même
-- comparateur qu'avant, une seule fermeture pour tous les appels)
local OFFS = { -1.5, -0.5, 0.5, 1.5 }
local function centers_before(a, b)
  if a[5] ~= b[5] then return a[5] < b[5] end
  if math.abs(a[3] - b[3]) > EPS then return a[3] < b[3] end
  if a[1] ~= b[1] then return a[1] < b[1] end
  if a[2] ~= b[2] then return a[2] < b[2] end
  return a[4] < b[4]
end

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
  for _, c in ipairs(S.electric_centers(bx, by, dir, sink, spec)) do
    -- (regle d'avant : direction de la thermique, boite qui CONTIENT l'ancienne emprise)
    if c[4] == dir and math.abs(c[1] - bx) <= 0.5 + EPS and math.abs(c[2] - by) <= 0.5 + EPS then return c[1], c[2] end
  end
  return nil
end

--- Lot FOREUSES-THERMIQUES (banc foreuses-chaine du 7/11 : 23 poses refusees sur 24, la 3 x 3 debordait sur la paire voisine ; le recepteur
--- fixe le centre a UNE place dans la direction de la thermique) : TOUS les placements admissibles { cx, cy, dir } : le depot tombe dans le
--- recepteur, la boite ne le recouvre pas et recouvre l'ancienne emprise 2 x 2 (remplacement SUR PLACE), dans les 4 directions. Ordre : la
--- direction de la thermique d'abord, puis le plus proche de l'ancien centre, puis x, puis y.
function S.electric_centers(bx, by, dir, sink, spec)
  -- Lot S5 (×10, mesure hors jeu sur le modèle du banc dense : 62 % des instructions de S.plan, une boîte par candidat) : même liste, sans
  -- table par candidat. Les boîtes { cx, cy, size, size } (nouvelle), { bx, by, 2, 2 } (ancienne emprise) de S.overlap sont écrites en
  -- ligne, mêmes opérations flottantes dans le même ordre. Directions : celle de la thermique, puis 0, 2, 4, 6 ; le passage d'une direction
  -- égale à celle de la thermique est sauté : il redonnait EXACTEMENT les candidats du premier passage, que le contrôle de doublon écartait
  -- tous (même (cx, cy, d)), et deux candidats d'un même passage n'ont jamais le même (cx, cy). Ordre d'avant le tri inchangé.
  -- S.inside(sink, cx + vx, cy + vy) est écrit en ligne et coupé en deux : sa partie x ne dépend que de ox, elle est lue une fois par
  -- colonne (même valeur) et saute les 4 lignes quand elle est fausse.
  local out = {}
  -- (revue-s, note sur 6c02464a : l'ancien ipairs({ dir, 0, 2, 4, 6 }) s'arrêtait au premier élément quand dir était nil : aucun candidat.
  -- Aucun appelant ne passe nil ; gardé tel quel pour rester égal dans tous les cas.)
  if dir == nil then return out end
  local size, sx, sy, sw, sh = spec.size, sink.x, sink.y, sink.w, sink.h
  local hw, hh = sw / 2 - EPS, sh / 2 - EPS
  local lim_sx, lim_sy = (size + sw) / 2 - EPS, (size + sh) / 2 - EPS
  local lim_old = (size + 2) / 2 - EPS
  for i = 0, 4 do
    local d = (i == 0) and dir or (i - 1) * 2
    if i == 0 or d ~= dir then
      local vx, vy = S.rotate(d, spec.drop[1], spec.drop[2])
      for a = 1, 4 do
        local ox = OFFS[a]
        local cx = bx + ox
        if abs(cx + vx - sx) < hw then
          local in_sx = abs(cx - sx) < lim_sx
          local in_old = abs(cx - bx) < lim_old
          for b = 1, 4 do
            local oy = OFFS[b]
            local cy = by + oy
            if abs(cy + vy - sy) < hh and not (in_sx and abs(cy - sy) < lim_sy) and (in_old and abs(cy - by) < lim_old) then
              out[#out + 1] = { cx, cy, ox * ox + oy * oy, d, d == dir and 0 or 1 }
            end
          end
        end
      end
    end
  end
  table.sort(out, centers_before)
  return out
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
--- Reserve d'amorcage (S.coal_reserve) : avec ctx.reserve = { [avant-poste] = { burners, keep } } et `o` (avant-poste) dans chaque entree, un
--- avant-poste de combustible garde ses `keep` dernieres thermiques (refus « reserve charbon », hors de n_ready et de n_chain).
function S.plan(entries, ctx)
  local ready, chained = {}, {}
  local list = {}
  for _, e in ipairs(entries) do list[#list + 1] = e end
  table.sort(list, function(a, b) return a.id < b.id end)
  -- Lot FOREUSES-THERMIQUES (coût) : poteaux ALIMENTÉS rangés par cases de S.CELL tuiles ; une foreuse ne lit que les cases voisines
  -- (couverture : la case et ses 8 voisines ; chaîne : les cases à portée de S.CHAIN_MAX fils). Réponses inchangées : seuls des poteaux
  -- trop loin pour compter sont sautés (rayon relevé élargi, des centaines de poteaux par équipe).
  -- Lot S5 (×10, mesure hors jeu sur le modèle du banc dense : 70 860 conversions nombre -> chaîne par passe pour les clés « gx:gy ») :
  -- clé NUMÉRIQUE de case, gx * 2^22 + gy (injective pour |gy| < 2^21 cases, soit 33 millions de tuiles ; au-delà, une collision
  -- n'ajouterait que des poteaux à plus de 2^21 cases, qui ne couvrent rien et dont la chaîne dépasse S.CHAIN_MAX fils : mêmes réponses).
  -- Mêmes cases, mêmes listes, même ordre ; une case vide n'alloue plus de table.
  local CELL = S.CELL
  local grid = {}
  for _, p in ipairs(ctx.poles) do
    if p.powered then
      local k = floor(p.x / CELL) * 4194304 + floor(p.y / CELL)
      local g = grid[k]
      if not g then
        g = {}
        grid[k] = g
      end
      g[#g + 1] = p
    end
  end
  local function near(box, r)
    local out = {}
    local gx, gy = floor(box.x / CELL), floor(box.y / CELL)
    for dy = -r, r do
      for dx = -r, r do
        local g = grid[(gx + dx) * 4194304 + (gy + dy)]
        if g then
          for i = 1, #g do out[#out + 1] = g[i] end
        end
      end
    end
    return out
  end
  local maxn = ctx.chain_max or S.CHAIN_MAX
  local far_r = ctx.pole and math.ceil((maxn * ctx.pole.wire + ctx.pole.supply + ctx.electric.size) / S.CELL) or 0
  local size = ctx.electric.size
  local function box_at(c) return { x = c[1], y = c[2], w = size, h = size } end
  -- Lot S5 : S.covered(p.x, p.y, p.dist, box_at(c)) sur les cases voisines, sans liste ni boîte (mêmes opérations flottantes) ; « au moins
  -- un poteau couvre » ne dépend pas de l'ordre de lecture.
  local function powered_at(c)
    local cx, cy = c[1], c[2]
    local gx, gy = floor(cx / CELL), floor(cy / CELL)
    for dy = -1, 1 do
      for dx = -1, 1 do
        local g = grid[(gx + dx) * 4194304 + (gy + dy)]
        if g then
          for i = 1, #g do
            local p = g[i]
            local l = (2 * p.dist + size) / 2 - EPS
            if abs(p.x - cx) < l and abs(p.y - cy) < l then return true end
          end
        end
      end
    end
    return false
  end
  -- Réserve d'amorçage (S.coal_reserve) : d'un avant-poste de combustible, au plus burners - keep candidats (ordre des numéros) ; les autres
  -- ne sont pas des candidats (ni n_ready, ni fabrication d'avance : lu par script/team/gisement.lua) et sont refusés « reserve charbon ».
  ctx.refused = ctx.refused or {}
  local quota = {}
  for _, e in ipairs(list) do
    local rv = ctx.reserve and e.o ~= nil and ctx.reserve[e.o]
    if rv and quota[e.o] == nil then quota[e.o] = math.max(0, (rv.burners or 0) - (rv.keep or 0)) end
    if rv and quota[e.o] <= 0 then
      ctx.refused[#ctx.refused + 1] = { id = e.id, why = "reserve charbon" }
    else
      local cs = S.electric_centers(e.x, e.y, e.dir, e.sink, ctx.electric)
      if #cs > 0 then
        -- classement sur les centres admissibles : alimentée si l'un d'eux l'est, sinon chaîne estimée depuis le premier
        local any_pw = false
        local classed = false
        for _, c in ipairs(cs) do if powered_at(c) then any_pw = true break end end
        if S.choose_type(ctx.obtainable, any_pw) == "electric" then
          ready[#ready + 1] = { id = e.id, e = e, cs = cs }
          classed = true
        elseif ctx.obtainable and ctx.pole then
          local b1 = box_at(cs[1]) -- (lot S5 : une boîte au lieu de deux, mêmes valeurs)
          local est = S.reach_estimate(b1, near(b1, far_r), ctx.pole, ctx.chain_max)
          if est then chained[#chained + 1] = { id = e.id, est = est, e = e, cs = cs } classed = true end
        end
        if rv and classed then quota[e.o] = quota[e.o] - 1 end
      end
    end
  end
  table.sort(chained, function(a, b) if a.est ~= b.est then return a.est < b.est end return a.id < b.id end)
  local out = {}
  local n = math.min(ctx.limit or (#ready + #chained), ctx.have or 0)
  ctx.refused = ctx.refused or {}
  -- Réserve d'amorçage (S.coal_reserve) : ctx.reserve = { [avant-poste] = { burners, keep } } pour les avant-postes de COMBUSTIBLE ; chaque
  -- entrée porte son avant-poste (`o`). Un remplacement qui ferait passer l'avant-poste sous `keep` thermiques est refusé « reserve charbon »,
  -- AVANT toute lecture de place (rien n'est dépensé), puis encore après, quand l'échange (iii) retire des thermiques voisines.
  local left = {}
  local function reserve_blocks(e, cost)
    local rv = ctx.reserve and e.o ~= nil and ctx.reserve[e.o]
    if not rv then return false end
    if left[e.o] == nil then left[e.o] = rv.burners or 0 end
    return not S.reserve_ok(left[e.o], rv.keep, cost)
  end
  local function reserve_take(e, cost)
    if left[e.o] ~= nil then left[e.o] = left[e.o] - cost end
  end
  local function cost_of(ex) return 1 + ((ex and ex.drills) and #ex.drills or 0) end
  -- (i) et (ii) : la 3 x 3 doit TENIR (ctx.fits : rien d'autre que l'ancienne foreuse et ce qui se defriche) AVANT tout poteau ; le premier
  -- centre qui tient est pris ; aucun : refus « 3x3 bloquee » (l'executant la laisse tranquille Swap.RETRY). Au plus S.FIT_TRIES foreuses
  -- essayees par passe (lecture du moteur).
  local fit_tries = 0
  local function first_fit(it, need_power)
    for _, c in ipairs(it.cs) do
      if not need_power or powered_at(c) then
        local fit = not ctx.fits or ctx.fits(it.e, c[1], c[2], c[4])
        if fit then return c, (type(fit) == "table") and fit or nil end
      end
    end
    return nil
  end
  local held_ready, held_chain = 0, 0 -- candidats retenus par la réserve : ni comptés pour la fabrication d'avance, ni pour n_ready
  for _, r in ipairs(ready) do
    if #out >= n or fit_tries >= (ctx.fit_tries or S.FIT_TRIES) then break end
    if reserve_blocks(r.e, 1) then
      held_ready = held_ready + 1
      ctx.refused[#ctx.refused + 1] = { id = r.id, why = "reserve charbon" }
    else
      fit_tries = fit_tries + 1
      local c, ex = first_fit(r, true)
      if c and reserve_blocks(r.e, cost_of(ex)) then
        held_ready = held_ready + 1
        ctx.refused[#ctx.refused + 1] = { id = r.id, why = "reserve charbon" }
      elseif c then
        reserve_take(r.e, cost_of(ex))
        out[#out + 1] = { id = r.id, cx = c[1], cy = c[2], dir = c[4], poles = {}, est = 0, exchange = ex }
      else
        ctx.refused[#ctx.refused + 1] = { id = r.id, why = "3x3 bloquee" }
      end
    end
  end
  local tries = 0
  for _, ch in ipairs(chained) do
    if #out >= n or tries >= (ctx.tries or S.TRIES) or fit_tries >= (ctx.fit_tries or S.FIT_TRIES) then break end
    if reserve_blocks(ch.e, 1) then
      held_chain = held_chain + 1
      ctx.refused[#ctx.refused + 1] = { id = ch.id, why = "reserve charbon" }
    else
      fit_tries = fit_tries + 1
      local c, ex = first_fit(ch, false)
      if not c then
        ctx.refused[#ctx.refused + 1] = { id = ch.id, why = "3x3 bloquee" }
      elseif reserve_blocks(ch.e, cost_of(ex)) then
        held_chain = held_chain + 1
        ctx.refused[#ctx.refused + 1] = { id = ch.id, why = "reserve charbon" }
      else
        tries = tries + 1
        local box = box_at(c)
        local plan, why = S.pole_plan(box, ctx.poles, ctx.pole, ctx.free_for(ch.e, box), { max = ctx.chain_max, chain = ctx.chain })
        if plan then
          reserve_take(ch.e, cost_of(ex))
          out[#out + 1] = { id = ch.id, cx = c[1], cy = c[2], dir = c[4], poles = plan.poles, source = plan.source, est = ch.est, exchange = ex }
        else
          ctx.refused[#ctx.refused + 1] = { id = ch.id, why = why }
        end
      end
    end
  end
  return out, #ready - held_ready, #chained - held_chain
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
S.FIT_TRIES = 8      -- foreuses dont la place de la 3 x 3 est lue au moteur au plus par passe (ctx.fits)
S.CELL = 16          -- cote (tuiles) des cases du rangement des poteaux alimentes (couverture : case et voisines ; supply + boite < 16)

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

---------------------------------------------------------------------------------------------------
-- Lot FOREUSES-THERMIQUES, RÉSERVE D'AMORÇAGE du combustible (décision du lead, 7/11 vers 19 h 10 : exception de SÛRETÉ à « Remplacer au fur
-- et à mesure », dite au DC, qui peut la refuser). Interblocage évité : réseau tombé → foreuses de charbon électriques arrêtées → centrale
-- sans charbon → réseau mort (la centrale ne repartirait qu'au minage à la main, une fois le coffre du QG vide). Un avant-poste de
-- COMBUSTIBLE garde toujours ses `keep` dernières thermiques : leur charbon NET (extrait moins brûlé), sans aucun courant, nourrit au moins
-- UNE chaudière de la centrale à pleine charge, de quoi la relancer depuis zéro. Les autres avant-postes et le reste de la règle : inchangés.
---------------------------------------------------------------------------------------------------
S.RESERVE_MARGIN = 1  -- charbon net des thermiques gardées / consommation d'une chaudière à pleine charge, au moins
S.RESERVE_DEFAULT = 3 -- données illisibles : la valeur des données vanilla. Chaudière 1 800 kW, charbon 4 MJ : 0,45/s ; thermique 0,25/s
                      -- extraits moins 150 kW / 4 MJ = 0,0375/s brûlés : 0,2125/s nets ; 0,45 / 0,2125 = 2,12, soit 3 (0,64/s : 1,42 chaudière)
S.RESERVE_ALL = 1e9   -- « toutes gardées » (une thermique ne nourrit pas plus qu'elle ne brûle)

local function finite(x) return type(x) == "number" and x == x and x > -math.huge and x < math.huge end

--- Thermiques à garder sur un avant-poste de combustible. d = { boiler_kw (UNE chaudière à pleine charge), fuel_kj (un combustible),
--- drill_rate (combustible extrait par seconde par une thermique, productivité comprise), drill_kw (sa combustion), margin (facultatif) }.
--- Rend un entier >= 1 ; S.RESERVE_DEFAULT si une donnée manque ou est fausse ; S.RESERVE_ALL si une thermique brûle autant qu'elle extrait
--- (aucune ne se remplace alors : rien ne relancerait la centrale ; un nombre fini, gardé dans global, jamais math.huge).
function S.coal_reserve(d)
  d = d or {}
  local bkw, kj, rate, dkw = d.boiler_kw, d.fuel_kj, d.drill_rate, d.drill_kw
  if not (finite(bkw) and bkw > 0 and finite(kj) and kj > 0 and finite(rate) and rate > 0 and finite(dkw) and dkw >= 0) then
    return S.RESERVE_DEFAULT
  end
  local net = rate - dkw / kj
  if net <= EPS then return S.RESERVE_ALL end
  local margin = finite(d.margin) and d.margin > 0 and d.margin or S.RESERVE_MARGIN
  return math.max(1, math.ceil(margin * (bkw / kj) / net - EPS))
end

--- Retrait de MASSE (balayage et retrait à sec du champ, script/team/migration_champ.lua) : thermiques GARDÉES d'un avant-poste de combustible,
--- les `keep` plus grands numéros de `ids` (déterministe). Rend la liste triée (toutes si keep >= #ids, aucune si keep <= 0).
function S.reserve_keepers(ids, keep)
  local l = {}
  for i, u in ipairs(ids or {}) do l[i] = u end
  table.sort(l)
  local n = math.min(#l, math.max(0, math.floor(keep or 0)))
  local out = {}
  for i = #l - n + 1, #l do out[#out + 1] = l[i] end
  return out
end

--- Un remplacement qui retire `cost` thermiques (l'ancienne et celles de l'échange) d'un avant-poste qui en a `burners` debout garde-t-il
--- la réserve `keep` ? (keep nil : avant-poste sans réserve, toujours vrai.)
function S.reserve_ok(burners, keep, cost)
  if keep == nil then return true end
  return (burners or 0) - (cost or 1) >= keep
end

--- Lot FOREUSES-THERMIQUES (iii), accord du lead (7/11, dans la ligne du QCM du DC « Remplacer au fur et a mesure ») : la 3 x 3 d'un
--- avant-poste dense deborde sur la paire voisine. Echange : retirer les paires thermiques du MEME avant-poste qui la bloquent, a trois
--- conditions (lead) : la place est verifiee AVANT tout retrait (cette regle, lue avant tout poteau) ; le courant est deja amene (l'executant
--- retire apres la chaine posee et reliee) ; le debit ne baisse pas : une electrique pour au plus S.EXCHANGE_MAX thermiques retirees,
--- l'ancienne comprise (electrique 0,5/s, thermique 0,25/s).
--- blockers : liste de { kind = "drill" | "sink" | "other", id } (ce qui recouvre la 3 x 3, l'ancienne foreuse et ce qui se defriche exclus) ;
--- info = { sink_of = { [foreuse] = recepteur }, feeders = { [recepteur] = { foreuses } }, fixed = { [foreuse] = true } } (paires de
--- l'avant-poste ; fixed : foreuses qui ne se retirent jamais, les ELECTRIQUES) ; own_sink : recepteur de la future electrique (jamais
--- retire) ; self_id : l'ancienne foreuse. Rend { drills = {...}, sinks = {...} } (ids tries ; listes vides : rien a retirer) ou nil, raison :
--- « 3x3 bloquee » (autre chose qu'une paire thermique), « recepteur » (il faudrait retirer le sien), « recepteur d'une electrique » (revue du
--- lead, 7/11, B1 : un four qui recoit d'une electrique deja posee n'est jamais retire, sinon elle depose au sol), « debit ».
S.EXCHANGE_MAX = 2
function S.exchange(blockers, info, own_sink, self_id, max)
  max = max or S.EXCHANGE_MAX
  info = info or {}
  local sink_of, feeders, fixed = info.sink_of or {}, info.feeders or {}, info.fixed or {}
  local drills, sinks = {}, {}
  local function add_sink(sid)
    if sid == nil or sinks[sid] then return true end
    if sid == own_sink then return false, "recepteur" end
    sinks[sid] = true
    for _, d in ipairs(feeders[sid] or {}) do
      if fixed[d] then return false, "recepteur d'une electrique" end
      if d ~= self_id and not drills[d] then
        drills[d] = true
        local ok, why = add_sink(sink_of[d])
        if not ok then return false, why end
      end
    end
    return true
  end
  -- four garde quand une foreuse voisine est retiree seule : celui de la future electrique, ou celui d'une electrique deja posee
  local function kept(sid)
    if sid == own_sink then return true end
    for _, d in ipairs(feeders[sid] or {}) do if fixed[d] then return true end end
    return false
  end
  for _, b in ipairs(blockers or {}) do
    if b.kind == "drill" and fixed[b.id] then
      return nil, "3x3 bloquee"
    elseif b.kind == "drill" then
      if b.id ~= self_id and not drills[b.id] then
        drills[b.id] = true
        local sid = sink_of[b.id]
        if sid ~= nil and not kept(sid) then
          local ok, why = add_sink(sid)
          if not ok then return nil, why end
        end
      end
    elseif b.kind == "sink" then
      local ok, why = add_sink(b.id)
      if not ok then return nil, why end
    else
      return nil, "3x3 bloquee"
    end
  end
  local dl, sl = {}, {}
  for d in pairs(drills) do dl[#dl + 1] = d end
  for k in pairs(sinks) do sl[#sl + 1] = k end
  table.sort(dl)
  table.sort(sl)
  if 1 + #dl > max then return nil, "debit" end
  return { drills = dl, sinks = sl }
end

--- Poteau a poser : le premier de `list` ({ name, have, craftable } dans l'ordre de preference) qui est au stock, sinon le premier fabricable.
function S.pole_item(list)
  for _, p in ipairs(list or {}) do if (p.have or 0) > 0 then return p.name end end
  for _, p in ipairs(list or {}) do if p.craftable then return p.name end end
  return nil
end

--- s40 champ p3 : clés échues de la table des nouveaux essais (`retry` : { [clé] = tick avant lequel la place n'est pas relevée }). Une entrée
--- dont le tick est <= `tick` ne retient plus rien (le relevé lit `t0 < retry[clé]`) : elle peut être retirée. Rend la liste TRIÉE des clés.
function S.retry_expired(retry, tick)
  local out = {}
  for k, v in pairs(retry or {}) do
    if type(v) ~= "number" or v <= tick then out[#out + 1] = k end
  end
  table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
  return out
end

return S
