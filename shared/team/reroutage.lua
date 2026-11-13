--[[
  REROUTAGE (lot s42 reroutage, chantier 4.4 du DC, partie du 13/11 en 0.7.96) : « construire d'abord, couper ensuite ».
  Un tapis de l'équipe TRAVERSE un gisement à paver (tracé d'un projet de foreuses qui n'a trouvé aucun détour sous la borne :
  « [FO-TRAVERSEE] gisement traverse »). Avant le lot, le plan du champ (script/team/champ.lua, blocked_in) tient ces tuiles pour
  occupées : un TROU dans le pavage (« gisement occupe (hors paires) : transport-belt N »), jamais de démontage, jamais de détour.

  RÈGLE (Lua PUR : aucune API du jeu, aucun nom d'objet ; lu hors jeu par tests/s42_reroutage_test.lua, en jeu par
  script/team/reroutage.lua) :
  1. TRONÇON TRAVERSANT (Rr.runs) : chaîne de tapis simples Z1..Zn posés sur la zone, dont l'amont P (tapis simple qui pointe sur Z1)
     et l'aval Q (tapis simple que Zn alimente) sont HORS de la zone ; aucun Zi n'est alimenté par autre chose que son prédécesseur
     (ni foreuse, ni bras, ni tapis de côté). Tout autre tapis de la zone est classé et laissé en place (« collecteur »,
     « embranchement », « sans amont », « sans aval », « piece », « boucle »).
  2. CONTOURNEMENT (Rr.plan) : chemin le plus court D1..Dm de tuiles libres HORS du gisement, D1 voisine de P, Dm voisine de Q par un
     CÔTÉ de Q (chargement latéral : il marche pendant que Zn alimente encore Q). Aucune tuile du contournement n'est la tuile de
     sortie d'un tapis existant (rien d'étranger n'y entre). Parcours en largeur, voisins dans un ordre fixe, borne d'états.
  3. ÉTATS (Rr.step) : a_contourner -> contournement_pose -> coupe -> raccorde (ou abandonne).
       a_contourner       : rien ne se pose tant que le stock ne couvre pas TOUTES les tuiles manquantes ; puis pose.
       contournement_pose : chaque tuile porte son tapis ; la COUPE est une rotation de P vers D1 (aucune destruction : le flux
                            bascule d'un coup, l'ancienne ligne se vide dans Q).
       coupe              : l'ancienne ligne, une fois VIDE, est retirée (objets rendus au stock).
       raccorde           : plus aucune tuile de l'ancienne ligne ; le gisement est libre pour le pavage.
     INVARIANT : aucune action « couper » et aucun passage à « coupe » tant que posed < total (Rr.peut_couper).

  Coordonnées : tuiles entières ; directions du jeu (0 N, 2 E, 4 S, 6 O). Déterminisme : aucun `pairs`, ordres fixes.
]]

local Rr = {}

Rr.A_CONTOURNER = "a_contourner"
Rr.POSE = "contournement_pose"
Rr.COUPE = "coupe"
Rr.RACCORDE = "raccorde"
Rr.ABANDONNE = "abandonne"

Rr.CAP = 4000 -- tuiles développées au plus par recherche de contournement (borne technique, pas un équilibrage)

local DIRS = { 0, 2, 4, 6 }
local DX = { [0] = 0, [2] = 1, [4] = 0, [6] = -1 }
local DY = { [0] = -1, [2] = 0, [4] = 1, [6] = 0 }

function Rr.key(x, y) return (x + 1048576) * 2097152 + (y + 1048576) end -- même clé que P.tkey

local function front(b) return b.x + DX[b.dir], b.y + DY[b.dir] end

--- Direction (code du jeu) de la tuile (ax, ay) vers sa voisine (bx, by) ; nil si elles ne sont pas voisines.
function Rr.dir_to(ax, ay, bx, by)
  for _, d in ipairs(DIRS) do
    if ax + DX[d] == bx and ay + DY[d] == by then return d end
  end
  return nil
end

--- Table { [clé] = tapis } d'une liste de tapis { x, y, dir, plain (tapis simple), fed (alimenté par une machine), human }.
function Rr.index(belts)
  local map = {}
  for _, b in ipairs(belts) do map[Rr.key(b.x, b.y)] = b end
  return map
end

--- Tapis qui alimentent `b` (leur tuile de sortie est celle de b), dans l'ordre fixe des directions.
local function feeders(map, b)
  local out = {}
  for _, d in ipairs(DIRS) do
    local n = map[Rr.key(b.x - DX[d], b.y - DY[d])]
    if n and n.dir == d then out[#out + 1] = n end
  end
  return out
end

--- Tronçons de la zone. `belts` : liste (voir Rr.index) ; `zone` : { [clé] = true } (tuiles du gisement à paver).
--- Rend une liste triée par clé de la première tuile : { kind = "traversant" | motif, p, q, old = { tapis Z1..Zn } }.
function Rr.runs(belts, zone)
  local map = Rr.index(belts)
  local heads = {}
  for _, b in ipairs(belts) do
    if zone[Rr.key(b.x, b.y)] then
      -- tête : aucun prédécesseur dans la zone
      local inzone = false
      for _, fd in ipairs(feeders(map, b)) do
        if zone[Rr.key(fd.x, fd.y)] then inzone = true end
      end
      if not inzone then heads[#heads + 1] = b end
    end
  end
  table.sort(heads, function(a, b) return Rr.key(a.x, a.y) < Rr.key(b.x, b.y) end)
  local runs = {}
  for _, h in ipairs(heads) do
    local run = { old = {}, kind = "traversant" }
    local function mark(why) if run.kind == "traversant" then run.kind = why end end
    local fds = feeders(map, h)
    if #fds == 0 then mark("sans amont") elseif #fds > 1 then mark("embranchement") else run.p = fds[1] end
    if run.p and not run.p.plain then mark("piece") end
    if run.p and run.p.human then mark("joueur") end
    local seen, cur = {}, h
    while cur do
      local k = Rr.key(cur.x, cur.y)
      if seen[k] then mark("boucle"); break end
      seen[k] = true
      if not zone[k] then run.q = cur; break end
      run.old[#run.old + 1] = cur
      if not cur.plain then mark("piece") end
      if cur.fed then mark("collecteur") end
      if cur.human then mark("joueur") end
      if cur ~= h and #feeders(map, cur) > 1 then mark("embranchement") end
      local fx, fy = front(cur)
      local nx = map[Rr.key(fx, fy)]
      if nx and (nx.dir + 4) % 8 == cur.dir then nx = nil end -- face à face : rien ne passe
      cur = nx
    end
    if not run.q then mark("sans aval") end
    if run.q and not run.q.plain then mark("piece") end
    if run.q and run.q.human then mark("joueur") end
    if run.q and run.p and run.q == run.p then mark("boucle") end
    runs[#runs + 1] = run
  end
  return runs
end

--- Contournement d'un tronçon traversant. ctx = { free = fn(x, y) (tuile où un tapis se pose), avoid = { [clé] = true } (gisement),
--- map = Rr.index(tapis existants), bounds = { x0, y0, x1, y1 }, cap }. Rend { tiles = { { x, y, dir } }, cut = direction de P vers D1 }
--- ou nil, motif.
function Rr.plan(run, ctx)
  if run.kind ~= "traversant" then return nil, run.kind end
  local p, q, map = run.p, run.q, ctx.map or {}
  local b = ctx.bounds
  local old = {}
  for _, z in ipairs(run.old) do old[Rr.key(z.x, z.y)] = true end
  local okc = {}
  local function ok(x, y)
    local k = Rr.key(x, y)
    local v = okc[k]
    if v ~= nil then return v end
    v = true
    if b and (x < b[1] or y < b[2] or x > b[3] or y > b[4]) then v = false end
    if v and (ctx.avoid and ctx.avoid[k] or old[k] or map[k]) then v = false end
    if v then
      -- aucune entrée étrangère : aucun tapis existant (hors P) ne sort sur cette tuile
      for _, d in ipairs(DIRS) do
        local n = map[Rr.key(x - DX[d], y - DY[d])]
        if n and n.dir == d and n ~= p then v = false end
      end
    end
    if v and not ctx.free(x, y) then v = false end
    okc[k] = v
    return v
  end
  -- buts : les deux tuiles de côté de Q
  local goals, ngoal = {}, 0
  for _, d in ipairs(DIRS) do
    if d ~= q.dir and d ~= (q.dir + 4) % 8 then
      local gx, gy = q.x + DX[d], q.y + DY[d]
      if ok(gx, gy) then goals[Rr.key(gx, gy)] = true; ngoal = ngoal + 1 end
    end
  end
  if ngoal == 0 then return nil, "aucun cote libre a l'aval" end
  local queue, head, from, at = {}, 1, {}, {}
  for _, d in ipairs(DIRS) do
    local sx, sy = p.x + DX[d], p.y + DY[d]
    local k = Rr.key(sx, sy)
    if ok(sx, sy) and from[k] == nil then
      from[k] = false; at[k] = { x = sx, y = sy }
      queue[#queue + 1] = k
    end
  end
  if #queue == 0 then return nil, "aucune tuile libre a l'amont" end
  local cap, found = ctx.cap or Rr.CAP, nil
  while head <= #queue and head <= cap do
    local k = queue[head]; head = head + 1
    if goals[k] then found = k; break end
    local c = at[k]
    for _, d in ipairs(DIRS) do
      local nx, ny = c.x + DX[d], c.y + DY[d]
      local nk = Rr.key(nx, ny)
      if from[nk] == nil and ok(nx, ny) then
        from[nk] = k; at[nk] = { x = nx, y = ny }
        queue[#queue + 1] = nk
      end
    end
  end
  if not found then return nil, head > cap and "borne de recherche" or "aucun chemin hors du gisement" end
  local rev, k = {}, found
  while k do rev[#rev + 1] = at[k]; k = from[k] or nil end
  local tiles = {}
  for i = #rev, 1, -1 do tiles[#tiles + 1] = { x = rev[i].x, y = rev[i].y } end
  for i = 1, #tiles do
    local nx = tiles[i + 1] or q
    tiles[i].dir = Rr.dir_to(tiles[i].x, tiles[i].y, nx.x, nx.y)
  end
  return { tiles = tiles, cut = Rr.dir_to(p.x, p.y, tiles[1].x, tiles[1].y) }
end

--- Preuve d'un contournement : tuiles distinctes, voisines, hors gisement, chaque maillon mène au suivant, le dernier entre dans Q
--- par un côté, le premier est voisin de P. Rend true ou false, motif.
function Rr.verify(run, plan, avoid)
  local t = plan and plan.tiles
  if not t or #t == 0 then return false, "vide" end
  local seen = {}
  for i, c in ipairs(t) do
    local k = Rr.key(c.x, c.y)
    if seen[k] then return false, "tuile en double" end
    seen[k] = true
    if avoid and avoid[k] then return false, "tuile sur le gisement" end
    local nx = t[i + 1] or run.q
    if c.dir == nil or c.x + DX[c.dir] ~= nx.x or c.y + DY[c.dir] ~= nx.y then return false, "maillon rompu" end
  end
  local last = t[#t]
  if last.dir == run.q.dir or last.dir == (run.q.dir + 4) % 8 then return false, "entree non laterale" end
  if plan.cut == nil or run.p.x + DX[plan.cut] ~= t[1].x or run.p.y + DY[plan.cut] ~= t[1].y then return false, "amont non voisin" end
  return true
end

--- La coupe est permise : chaque tuile du contournement porte son tapis, amont et aval en place.
function Rr.peut_couper(facts)
  return (facts.total or 0) > 0 and (facts.posed or 0) >= facts.total and facts.p_ok == true and facts.q_ok == true
end

--- Un pas de l'automate. `state` : état courant ; facts = { total, posed (tuiles du contournement qui portent leur tapis dans la bonne
--- direction), stock (tapis au stock), p_ok, q_ok, p_cut (P pointe sur D1), old_left (tuiles de l'ancienne ligne encore en place),
--- old_items (objets encore dessus) }. Rend état suivant, action ({ kind = "poser" | "couper" | "retirer" | "attendre", why }) ou nil.
function Rr.step(state, facts)
  local total, posed = facts.total or 0, facts.posed or 0
  if state == Rr.RACCORDE or state == Rr.ABANDONNE then return state, nil end
  if state == Rr.A_CONTOURNER or state == Rr.POSE then
    if not (facts.p_ok and facts.q_ok) or total <= 0 then return Rr.ABANDONNE, { kind = "attendre", why = "amont ou aval disparu" } end
    if posed < total then
      -- (retour de contournement_pose à a_contourner si une tuile a disparu : jamais de coupe)
      if (facts.stock or 0) < total - posed then return Rr.A_CONTOURNER, { kind = "attendre", why = "stock" } end
      return Rr.A_CONTOURNER, { kind = "poser" }
    end
    if state == Rr.A_CONTOURNER then return Rr.POSE, nil end
    if not Rr.peut_couper(facts) then return Rr.POSE, { kind = "attendre", why = "contournement incomplet" } end
    if facts.p_cut then return Rr.COUPE, nil end
    return Rr.POSE, { kind = "couper" }
  end
  if state == Rr.COUPE then
    if posed < total then
      -- le flux passe déjà par le contournement : une tuile perdue se repose, l'ancienne ligne n'est pas touchée entre-temps
      if (facts.stock or 0) < total - posed then return Rr.COUPE, { kind = "attendre", why = "stock" } end
      return Rr.COUPE, { kind = "poser" }
    end
    if (facts.old_left or 0) == 0 then return Rr.RACCORDE, nil end
    if (facts.old_items or 0) > 0 then return Rr.COUPE, { kind = "attendre", why = "vidange" } end
    return Rr.COUPE, { kind = "retirer" }
  end
  return Rr.ABANDONNE, nil
end

return Rr
