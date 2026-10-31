--[[
  Tests hors jeu du lot POTEAUX-COURT (retour du DC 31/10 : « chemins de poteaux 4 à 5 fois plus longs que nécessaire »).
  Règles pures : shared/team/poteaux.lua (Q.length, Q.ratio, Q.prefer_direct) et P.pole_chain de shared/team/plan.lua.
  Usage, depuis la racine du mod :   lua5.2 tests/poteaux_court_test.lua

    1. longueur et ratio de fil ; 2. table de vérité du choix direct / escalier ;
    3. terrain libre : la chaîne directe a un ratio de fil <= 1,3 sur toutes les distances et directions, et bat l'escalier de
       carrefours du treillis (même méthode que plan_power : P.route_nodes puis P.pole_chain entre carrefours) ;
    4. obstacles (lac, mur à brèche, rivière étroite) : ratio <= 1,3 quand le détour géométrique optimal le permet ;
    5. déterminisme ; 6. coût : appels à `free` bornés ; 7. mutants : variantes fautives refusées.
]]
package.path = "./?.lua;" .. package.path
local P = require("shared.team.plan")

local passes, failures = 0, 0
local verbose, quiet = false, false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
end

local function dist(p, q) return math.sqrt((p.x - q.x) ^ 2 + (p.y - q.y) ^ 2) end
local function rect(t, x0, y0, x1, y1) for y = y0, y1 do for x = x0, x1 do t[P.tkey(x, y)] = true end end end
local function freefn(block) return function(x, y) return not block[P.tkey(math.floor(x), math.floor(y))] end end
local function valid(chain, a, b, reach, free)
  if not chain then return false end
  local prev = a
  for _, c in ipairs(chain) do
    if dist(prev, c) > reach + 1e-9 or not free(c.x, c.y) then return false end
    prev = c
  end
  return dist(prev, b) <= reach + 1e-9
end
local function clen(a, chain, b)
  local l, p = 0, a
  for _, q in ipairs(chain) do l = l + dist(p, q); p = q end
  return l + dist(p, b)
end

--- Escalier comme plan_power : carrefours par P.route_nodes, chaîne entre carrefours voisins, puis liaison module-carrefour.
--- Rend { n = poteaux neufs, len = fil } et la position du poteau du carrefour cible.
local function staircase(mp, target, reach, free)
  local lat = { ox = 0, oy = 0 }
  local function spot(i, j) local n = P.node_pos(lat, i, j); return { x = n.x - 1.5, y = n.y - 1.5 } end
  local nodes = P.route_nodes({ i = 0, j = 0 }, target, function() return true end, 12)
  local n, len, prev = 0, 0, nil
  for k, nd in ipairs(nodes) do
    local pos = spot(nd.i, nd.j)
    if k > 1 then n = n + 1 end
    if prev then
      local c = P.pole_chain(prev, pos, reach, false, free, {})
      if not c then return nil end
      n = n + #c
      len = len + clen(prev, c, pos)
    end
    prev = pos
  end
  local first = spot(0, 0)
  local c = P.pole_chain(mp, first, reach, false, free, {})
  if not c then return nil end
  n = n + 1 + #c
  len = len + clen(mp, c, first)
  return { n = n, len = len }, spot(target.i, target.j)
end

local function battery(Q)
  local before = failures
  local reach = 9
  -- 1. longueur et ratio
  local a, b = { x = 0.5, y = 0.5 }, { x = 20.5, y = 0.5 }
  local off = { x = 10.5, y = 10.5 }
  check(math.abs(Q.length(a, {}, b) - 20) < 1e-9, "longueur sans poteau = distance")
  check(math.abs(Q.length(a, { off }, b) - (dist(a, off) + dist(off, b))) < 1e-9, "longueur par un poteau")
  check(math.abs(Q.ratio(a, { { x = 10.5, y = 0.5 } }, b) - 1) < 1e-9, "ratio 1 en ligne droite")
  check(Q.ratio(a, { off }, b) > 1.4, "ratio d'un détour de 10 tuiles sur 20")
  check(Q.ratio(a, {}, a) == 1, "ratio de points confondus = 1")
  -- 2. table de vérité
  check(Q.prefer_direct({ n = 3, len = 40 }, { n = 5, len = 30 }) == true, "moins de poteaux : direct")
  check(Q.prefer_direct({ n = 6, len = 20 }, { n = 5, len = 90 }) == false, "plus de poteaux : escalier même si fil plus court")
  check(Q.prefer_direct({ n = 5, len = 30 }, { n = 5, len = 45 }) == true, "autant de poteaux, fil plus court : direct")
  check(Q.prefer_direct({ n = 5, len = 45 }, { n = 5, len = 30 }) == false, "autant de poteaux, fil plus long : escalier")
  check(Q.prefer_direct({ n = 5, len = 30 }, { n = 5, len = 30 }) == false, "égalité : escalier (rien ne change)")
  check(Q.prefer_direct(nil, { n = 5, len = 30 }) == false, "direct introuvable : escalier")
  -- 3. terrain libre : ratio direct <= 1,3 et gain sur l'escalier
  local free = function() return true end
  local worst, sum_dir, sum_via, cases, wins, np_dir, np_via = 0, 0, 0, 0, 0, 0, 0
  for _, tgt in ipairs({ { 3, 0 }, { 0, 4 }, { 3, 3 }, { 5, 2 }, { 2, 6 }, { 6, 6 } }) do
    for _, o in ipairs({ { 4, 4 }, { 9, 2 }, { 1, 11 } }) do
      local mp = { x = o[1] + 0.5, y = o[2] + 0.5 }
      local via, tpos = staircase(mp, { i = tgt[1], j = tgt[2] }, reach, free)
      local c = P.pole_chain(mp, tpos, reach, false, free, {})
      check(valid(c, mp, tpos, reach, free), "chaîne directe valide en terrain libre " .. tgt[1] .. "," .. tgt[2])
      if c and via then
        local r = Q.ratio(mp, c, tpos)
        if r > worst then worst = r end
        check(r <= 1.3 + 1e-9, string.format("ratio direct %.3f > 1,3 (module %d,%d, cible %d,%d)", r, o[1], o[2], tgt[1], tgt[2]))
        local dir = { n = #c, len = Q.length(mp, c, tpos) }
        cases = cases + 1
        np_dir = np_dir + dir.n; np_via = np_via + via.n
        sum_dir = sum_dir + dir.len / dist(mp, tpos); sum_via = sum_via + via.len / dist(mp, tpos)
        if Q.prefer_direct(dir, via) then wins = wins + 1 end
        check(dir.n <= via.n, string.format("le direct ne pose pas plus de poteaux que l'escalier (%d contre %d)", dir.n, via.n))
      end
    end
  end
  check(cases > 10 and wins >= cases - 2, "le direct est retenu presque toujours en terrain libre (" .. wins .. "/" .. cases .. ")")
  if verbose then print(string.format("   libre : ratio direct moyen %.2f (pire %.2f), escalier moyen %.2f ; direct retenu %d/%d ; poteaux neufs : direct %d, escalier %d",
    sum_dir / cases, worst, sum_via / cases, wins, cases, np_dir, np_via)) end
  check(cases > 0 and np_via > np_dir, "l'escalier pose plus de poteaux que le direct (il justifie le lot)")
  -- distances de 12 à 200 tuiles, 5 directions : ratio de fil <= 1,3
  local w2 = 0
  for d = 12, 200, 5 do
    for _, ang in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
      local mp = { x = 0.5, y = 0.5 }
      local t = { x = math.floor(0.5 + d * math.cos(ang * 0.7854)) + 0.5, y = math.floor(0.5 + d * math.sin(ang * 0.7854)) + 0.5 }
      local c = P.pole_chain(mp, t, reach, false, free, {})
      if c then
        local r = Q.ratio(mp, c, t)
        if r > w2 then w2 = r end
      else check(false, "chaîne nil en terrain libre à " .. d) end
    end
  end
  check(w2 <= 1.3, string.format("terrain libre 12 à 200 tuiles : ratio pire %.3f <= 1,3", w2))
  if verbose then print(string.format("   terrain libre 12 a 200 tuiles : ratio pire %.3f", w2)) end
  -- 4. obstacles
  do
    local blk = {}
    rect(blk, 24, -14, 40, 14) -- lac 17 x 29 sur la route (plus large que la portée : on le contourne)
    local f = freefn(blk)
    local m, t = { x = 0.5, y = 0.5 }, { x = 62.5, y = 0.5 }
    local c = P.pole_chain(m, t, reach, false, f, {})
    check(valid(c, m, t, reach, f), "lac : chaîne valide")
    local opt = 2 * math.sqrt(24.5 ^ 2 + 14.5 ^ 2) + 17 -- contournement géométrique optimal par les coins
    local r = c and Q.ratio(m, c, t) or 99
    check(r <= 1.3, string.format("lac : ratio %.3f <= 1,3 (optimum géométrique %.3f)", r, opt / dist(m, t)))
    if verbose then print(string.format("   lac : ratio %.3f (optimum %.3f)", r, opt / dist(m, t))) end
  end
  do
    local blk = {}
    rect(blk, 30, -40, 41, -3); rect(blk, 30, 3, 41, 40) -- mur de 12 tuiles avec une brèche de 5 tuiles
    local f = freefn(blk)
    local m, t = { x = 0.5, y = 8.5 }, { x = 60.5, y = -7.5 }
    local c = P.pole_chain(m, t, reach, false, f, {})
    check(valid(c, m, t, reach, f), "mur à brèche : chaîne valide")
    local r = c and Q.ratio(m, c, t) or 99
    check(r <= 1.3, string.format("mur à brèche : ratio %.3f <= 1,3", r))
    if verbose then print(string.format("   mur a breche : ratio %.3f", r)) end
  end
  do
    local blk = {}
    rect(blk, 30, -70, 41, 15); rect(blk, 30, 21, 41, 70) -- mur de 12 tuiles (plus que la portée), brèche de 5 à 18 tuiles de la droite : couloir large
    local f = freefn(blk)
    local m, t = { x = 0.5, y = 0.5 }, { x = 60.5, y = 0.5 }
    local c = P.pole_chain(m, t, reach, false, f, {})
    check(c ~= nil and valid(c, m, t, reach, f), "mur long à brèche écartée : chaîne valide")
    local r = c and Q.ratio(m, c, t) or 99
    check(r <= 1.3, string.format("mur long à brèche écartée : ratio %.3f <= 1,3", r))
    local cq = Q.path(m, t, reach, false, f, {}) -- la recherche seule (sans repli glouton) doit aussi y arriver
    check(cq ~= nil and valid(cq, m, t, reach, f), "mur long à brèche écartée : A* seul, couloir élargi")
    if verbose then print(string.format("   mur long, breche ecartee : ratio %.3f", r)) end
  end
  do
    local blk = {}
    rect(blk, 25, -50, 28, 50)
    local f = freefn(blk)
    local m, t = { x = 0.5, y = 0.5 }, { x = 60.5, y = 4.5 }
    local c = P.pole_chain(m, t, reach, false, f, {})
    check(c ~= nil and valid(c, m, t, reach, f), "rivière de 4 tuiles (moins que la portée) : franchie, chaîne valide")
    check(c ~= nil and Q.ratio(m, c, t) <= 1.3, "rivière de 4 tuiles : ratio <= 1,3")
  end
  -- 5. déterminisme
  do
    local blk = {}
    rect(blk, 24, -14, 40, 14)
    local m, t = { x = 0.5, y = 0.5 }, { x = 62.5, y = 0.5 }
    local c1 = P.pole_chain(m, t, reach, false, freefn(blk), {})
    local c2 = P.pole_chain(m, t, reach, false, freefn(blk), {})
    local same = c1 ~= nil and c2 ~= nil and #c1 == #c2
    if same then for i = 1, #c1 do if c1[i].x ~= c2[i].x or c1[i].y ~= c2[i].y then same = false end end end
    check(same, "deux appels, même chaîne")
  end
  -- 6. coût borné
  do
    local calls = 0
    local f = function() calls = calls + 1; return true end
    local m, t = { x = 0.5, y = 0.5 }, { x = 150.5, y = 100.5 }
    local c = P.pole_chain(m, t, reach, false, f, {})
    check(c ~= nil, "150 x 100 : chaîne trouvée")
    check(calls <= 6000, "appels à free bornés (" .. calls .. ")")
  end
  return failures - before
end

-- module réel
local Q = require("shared.team.poteaux")
verbose = true
local f0 = battery(Q)
verbose = false
check(f0 == 0, "batterie sur le module réel : 0 échec (" .. f0 .. ")")

-- 7. mutants
do
  local fh = io.open("shared/team/poteaux.lua", "rb")
  local src = fh:read("*a")
  fh:close()
  local function mutant(label, from, to)
    local s, n = src:gsub(from:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"), (to:gsub("%%", "%%%%")), 1)
    if n ~= 1 then check(false, "mutant « " .. label .. " » : motif introuvable dans poteaux.lua") return end
    local M = load(s, "=mutant", "t", _ENV)()
    local p0, f0 = passes, failures
    quiet = true
    local nf = battery(M)
    quiet = false
    passes, failures = p0, f0
    check(nf >= 1, "mutant « " .. label .. " » refusé par la batterie (" .. nf .. " échec(s))")
  end
  mutant("direct choisi à plus de poteaux", "return dir.n < via.n", "return dir.n > via.n")
  mutant("égalité de poteaux : fil plus long préféré", "return dir.len < via.len - 0.01", "return dir.len > via.len")
  mutant("direct absent accepté", "if not dir then return false end", "if not dir then return true end")
  mutant("ratio inversé", "return Q.length(a, chain, b) / d", "return d / Q.length(a, chain, b)")
  mutant("longueur sans le dernier maillon", "return l + dist(p, b)", "return l")
  mutant("couloir étroit seulement", "Q.WIDTHS = { 1, 2, 3.5 }", "Q.WIDTHS = { 1 }")
end

print(string.format("[POTEAUX-COURT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
