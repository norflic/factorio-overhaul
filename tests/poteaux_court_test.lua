--[[
  Tests hors jeu du lot POTEAUX-COURT (retour du DC 31/10 : « chemins de poteaux 4 à 5 fois plus longs que nécessaire »).
  Règles pures : shared/team/poteaux.lua (Q.length, Q.ratio, Q.prefer_direct) et P.pole_chain de shared/team/plan.lua.
  Usage, depuis la racine du mod :   lua5.2 tests/poteaux_court_test.lua

    1. longueur et ratio de fil ; 2. table de vérité du choix direct / escalier ;
    3. terrain libre : la chaîne directe a un ratio de fil <= 1,3 sur toutes les distances et directions, et bat l'escalier de
       carrefours du treillis (même méthode que plan_power : P.route_nodes puis P.pole_chain entre carrefours) ;
    4. obstacles (lac, mur à brèche, rivière étroite) : ratio <= 1,3 quand le détour géométrique optimal le permet ;
    5. déterminisme ; 6. coût : appels à `free` bornés ; 7. mutants : variantes fautives refusées ;
    8. P.lot_at ; 9. chaîne par les rues seules ; 10. plan_power exécuté (corps de build.lua, monde simulé réduit) et ses mutants.
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

  -- relecture : but vivant le plus proche, lots à garder, détour des rues
  do
    local near = Q.nearest({ x = 0, y = 0 }, { { x = 9, y = 0 }, { x = 0, y = 3 }, { x = 3, y = 0 }, { x = -3, y = 0 } })
    check(near and near.x == -3 and near.y == 0, "nearest : le plus proche, égalité par y puis x")
    check(Q.nearest({ x = 0, y = 0 }, {}) == nil, "nearest : liste vide")
    check(Q.lot_protected({ state = "libre" }) == true, "lot libre protégé")
    check(Q.lot_protected({ state = "inconnu" }) == true, "lot pas encore relevé protégé")
    check(Q.lot_protected({ state = "libre", used = 3 }) == false, "lot pris : ses tuiles libres servent")
    check(Q.lot_protected({ state = "refuse" }) == false, "lot refusé : rien n'y viendra")
    check(Q.lot_protected({ state = "gisement", used = 3 }) == true, "gisement pris : d'autres lignes s'y posent")
    check(Q.lot_protected(nil) == false, "hors du treillis : libre")
    local a, b = { x = 0, y = 0 }, { x = 100, y = 0 }
    check(Q.keep_street(a, {}, b) == true, "rue droite gardée")
    check(Q.keep_street(a, nil, b) == false, "pas de chaîne : non gardée")
    check(Q.keep_street(a, { { x = 50, y = 80 } }, b) == false, "détour de 1,89 refusé")
    check(Q.keep_street(a, { { x = 50, y = 50 } }, b) == true, "détour de 1,41 gardé")
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
  mutant("nearest : le plus loin", "d < bd - EPS", "d > bd + EPS")
  mutant("lot pris encore protégé", "return not l.used and l.state ~= \"refuse\"", "return l.state ~= \"refuse\"")
  mutant("lot refusé protégé", "return not l.used and l.state ~= \"refuse\"", "return not l.used")
  mutant("gisement non protégé", "if l.state == \"gisement\" then return true end", "")
  mutant("détour sans plafond", "Q.ratio(a, chain, b) <= Q.STREET_RATIO + EPS", "true")
end


-- 8. P.lot_at contre P.lot_rect
do
  local lat = { ox = 3, oy = -5 }
  local ok = true
  for ty = -80, 80, 3 do
    for tx = -80, 80 do
      local i, j = P.lot_at(lat, tx, ty)
      if i then
        local x0, y0, x1, y1 = P.lot_rect(lat, i, j)
        if not (tx >= x0 and tx < x1 and ty >= y0 and ty < y1) then ok = false end
      else
        for ci = -4, 4 do for cj = -4, 4 do
          local x0, y0, x1, y1 = P.lot_rect(lat, ci, cj)
          if tx >= x0 and tx < x1 and ty >= y0 and ty < y1 then ok = false end
        end end
      end
    end
  end
  check(ok, "P.lot_at : les tuiles d'un lot le rendent, celles d'une rue rendent nil")
end

-- 9. Les rues seules suffisent (grille de lots libres, portée 9, budget de Cl.path_opts) : ratio <= STREET_RATIO
do
  local Cl = require("shared.team.centrale_loin")
  local Pt = require("shared.team.poteaux")
  local lat = { ox = 0, oy = 0 }
  local function streets(oi, oj)
    return function(x, y)
      local i, j = P.lot_at(lat, math.floor(x), math.floor(y))
      return not i or (i == oi and j == oj)
    end
  end
  local worst, missing = 0, 0
  for _, l in ipairs({ { 2, 0 }, { 0, 3 }, { 2, 2 }, { -3, 1 }, { 4, -4 }, { -5, -2 }, { 6, 1 }, { 5, 5 } }) do
    local a = { x = l[1] * 28 + 0.5, y = l[2] * 28 + 0.5 }
    local n = P.node_pos(lat, 0, 0)
    local b = { x = n.x - 1.5, y = n.y - 1.5 }
    local c = P.pole_chain(a, b, 9, false, streets(l[1], l[2]), {}, Cl.path_opts(dist(a, b), 9))
    if not c then missing = missing + 1 else worst = math.max(worst, Pt.ratio(a, c, b)) end
  end
  check(missing == 0, "chaîne par les rues trouvée pour les 8 modules (" .. missing .. " manquante(s))")
  check(worst <= Pt.STREET_RATIO, string.format("par les rues, ratio au pire %.3f <= %.1f", worst, Pt.STREET_RATIO))
end

-- 10. plan_power EXÉCUTÉ (corps de script/team/build.lua, monde simulé réduit), avec des mutants de son corps
do
  local fh = io.open("script/team/build.lua", "rb")
  local src = fh:read("*a")
  fh:close()
  local s0 = src:find("local function plan_power(f, p, mp, masks)", 1, true)
  local _, s1 = src:find("\nend\n", s0, true)
  local body = src:sub(s0, s1)
  local Mq = require("shared.team.masques")
  local Cl = require("shared.team.centrale_loin")
  local Pt = require("shared.team.poteaux")
  local POLE = "medium-electric-pole"

  local function make(text)
    local world = {}
    local env = setmetatable({
      P = P, Pt = Pt, Mq = Mq, Cl = Cl, Far = {}, REUSE_STATES = { fini = true },
      -- lot TRAVERSEE : plan_power appelle Build.Trav.pole_chain ; doublure sans lecture du moteur (aucun gisement), même chaîne que P.pole_chain
      Build = { Trav = { pole_chain = function(_, _, a, b, reach, big, free, known, opts) return P.pole_chain(a, b, reach, big, free, known, opts) end } },
      pole_kind = function() return world.big and "big-electric-pole" or POLE, world.big and 30 or 9 end,
      nearest_node = function(_, x, y) return math.floor(x / 28 + 0.5), math.floor(y / 28 + 0.5) end,
      surface_of = function() return world.surface end,
      seg_passable = function() return function(key) return not world.closed[key] end end,
      seg_wire = function() return function(key) return not world.closed[key] end end,
      sorted_keys = function(t) local o = {} for k in pairs(t) do o[#o + 1] = k end table.sort(o) return o end,
      masques_view = function() return world.view end,
      log = function(l) world.logs[#world.logs + 1] = l end,
    }, { __index = _G })
    return assert(load(text .. "\nreturn plan_power", "=plan_power", "t", env))(), world
  end

  local function setup(world, o)
    local b = { lat = { ox = 0, oy = 0 }, radius = 12, net = {}, occ = {}, lots = {}, order = {}, projects = {} }
    for j = -12, 12 do for i = -12, 12 do b.lots[P.lot_key(i, j)] = { i = i, j = j, state = "libre" } end end
    world.logs, world.closed, world.big = {}, o.closed or {}, o.big
    local blocked = o.blocked or function() return false end
    world.view = { free = function(tx, ty) return not b.occ[P.tkey(tx, ty)] and not blocked(tx, ty) end, clear = function() return false end }
    local poles = {}
    for _, q in ipairs(o.poles or {}) do
      poles[#poles + 1] = { name = POLE, position = { x = q.x, y = q.y }, electric_network_id = q.net or 1 }
    end
    world.surface = {
      count_tiles_filtered = function() return 0 end,
      find_entities_filtered = function(q)
        if q.type == "generator" then return o.gen == false and {} or { { electric_network_id = 1 } } end
        if q.type ~= "electric-pole" then return {} end
        local out = {}
        for _, e in ipairs(poles) do
          local x, y = e.position.x, e.position.y
          if q.position then
            if (x - q.position[1]) ^ 2 + (y - q.position[2]) ^ 2 <= q.radius ^ 2 then out[#out + 1] = e end
          elseif x >= q.area[1][1] and x <= q.area[2][1] and y >= q.area[1][2] and y <= q.area[2][2] then
            out[#out + 1] = e
          end
        end
        return out
      end }
    for _, n in ipairs(o.net or {}) do
      b.net[P.lot_key(n.i, n.j)] = { i = n.i, j = n.j, pid = n.pid or 1, built = n.built ~= false, x = n.x, y = n.y }
    end
    return b
  end

  -- Module de la tuile au centre du lot (li, lj), carrefour vivant (0, 0).
  local n00 = P.node_pole({ ox = 0, oy = 0 }, 0, 0, false)
  local function run(pp, world, li, lj, o)
    o.net = o.net or { { i = 0, j = 0, x = n00.x, y = n00.y } }
    o.poles = o.poles or { n00 }
    local b = setup(world, o)
    b.lots[P.lot_key(li, lj)].used = 7
    local mp = { name = POLE, x = li * 28 + 0.5, y = lj * 28 + 0.5, part = 1 }
    local p = { id = 7, ents = { mp } }
    local f = { build = b, force = "f" }
    local out, why, nodes = pp(f, p, mp, { free = world.view.free, clear = {} })
    return out, why, nodes, b, mp
  end
  local function in_free_lot(b, e)
    local i, j = P.lot_at(b.lat, math.floor(e.x), math.floor(e.y))
    return i and Pt.lot_protected(b.lots[P.lot_key(i, j)]) or false
  end
  local function count_in_free(b, out)
    local n = 0
    for _, e in ipairs(out or {}) do if in_free_lot(b, e) then n = n + 1 end end
    return n
  end
  local function closed_block(i0, i1, j0, j1)
    local t = {}
    for j = j0, j1 do for i = i0, i1 do
      t["h:" .. P.lot_key(i, j)] = true
      t["v:" .. P.lot_key(i, j)] = true
    end end
    return t
  end

  local function scenarios(pp, world, chk)
    -- A. poteau vivant d'un module voisin : une courte branche, pas une ligne vers le carrefour lointain
    local near = { x = 6 * 28 + 0.5, y = 16.5 }
    local out, _, nodes = run(pp, world, 6, 0, { poles = { n00, near } })
    chk(out and #out <= 1, "A. voisin vivant à 16 tuiles : 1 poteau au plus (" .. tostring(out and #out) .. ")")
    chk(nodes and #nodes == 0, "A. aucun carrefour enregistré")
    -- A bis. le voisin est sur une île (autre réseau) : il ne compte pas
    out = run(pp, world, 6, 0, { poles = { n00, { x = near.x, y = near.y, net = 2 } } })
    chk(out and #out >= 15, "A bis. voisin sur une île ignoré (" .. tostring(out and #out) .. " poteaux)")
    -- B. loin en diagonale, rien entre les deux : les lots libres restent entiers
    local b
    out, _, nodes, b = run(pp, world, 4, 4, {})
    chk(out and #out > 0, "B. diagonale : reliée")
    chk(out and count_in_free(b, out) == 0, "B. aucun poteau dans un lot libre (" .. count_in_free(b, out or {}) .. ")")
    chk(nodes and #nodes == 0 and #world.logs == 1 and world.logs[1]:find("DIRECT retenu", 1, true) ~= nil, "B. direct retenu et journalisé")
    -- C. rues fermées (eau, falaises) : le détour de l'escalier, cause du retour du DC, ne se paie plus
    local mp
    out, _, nodes, b, mp = run(pp, world, 3, 0, { closed = closed_block(1, 2, -8, 8) })
    chk(out ~= nil, "C. rues fermées : relié")
    local reach_ok, len = true, 0
    if out then
      local cur = { x = mp.x, y = mp.y }
      for _, e in ipairs(out) do
        local d = dist(cur, e)
        if d > 9 + 1e-6 then reach_ok = false end
        len = len + d
        cur = e
      end
      if dist(cur, n00) > 9 + 1e-6 then reach_ok = false end
      len = len + dist(cur, n00)
    end
    chk(reach_ok, "C. chaque maillon tient dans la portée")
    chk(len <= 1.6 * dist(mp, n00), string.format("C. fil %.0f pour %.0f à vol d'oiseau", len, dist(mp, n00)))
    -- D. aucune route (carrefours étrangers tout autour) : le direct évite le refus
    local foreign = { { i = 0, j = 0, x = n00.x, y = n00.y } }
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      foreign[#foreign + 1] = { i = d[1], j = d[2], pid = 9, built = false }
    end
    local why
    out, why, nodes = run(pp, world, 3, 0, { net = foreign })
    chk(out ~= nil and why == nil and nodes and #nodes == 0, "D. pas de route, direct posé (" .. tostring(why) .. ")")
    -- E. aucune route ET aucun direct : le refus d'avant, attente comprise
    out, why, nodes = run(pp, world, 3, 0, { net = foreign, blocked = function() return true end })
    chk(out == nil and why == "pas de rue vers le reseau" and nodes == "net", "E. refus inchangé (attente " .. tostring(nodes) .. ")")
    -- F. pas de centrale qui tourne : le carrefour cible reste le but
    out, _, nodes, b = run(pp, world, 4, 0, { gen = false, poles = {} })
    chk(out and #out > 0 and count_in_free(b, out) == 0, "F. sans centrale : relié au carrefour cible")
    -- G. grands poteaux : l'escalier, inchangé
    out, _, nodes = run(pp, world, 4, 0, { big = true })
    chk(out and nodes and #nodes == 5 and #world.logs == 0, "G. grands poteaux : escalier de 5 carrefours, sans comparaison (" .. tostring(nodes and #nodes) .. ")")
    -- H. carrefour du module déjà au réseau : la liaison seule
    out, _, nodes = run(pp, world, 0, 0, {})
    chk(out and nodes and #nodes == 1 and #world.logs == 0, "H. module au carrefour : pas de comparaison")
    -- I. rues toutes bloquées : le direct coupe les lots (il ne reste que ça)
    out, _, nodes, b = run(pp, world, 3, 0, { blocked = function(tx, ty) return P.lot_at({ ox = 0, oy = 0 }, tx, ty) == nil and math.abs(tx) > 6 end })
    chk(out and count_in_free(b, out) > 0 and nodes and #nodes == 0, "I. rues bloquées : la chaîne directe traverse un lot libre")
  end


  -- réel
  do
    local pp, world = make(body)
    scenarios(pp, world, check)
    -- déterminisme
    local a1 = run(pp, world, 4, 4, {})
    local a2 = run(pp, world, 4, 4, {})
    local same = #a1 == #a2
    for i = 1, #a1 do if a1[i].x ~= a2[i].x or a1[i].y ~= a2[i].y then same = false end end
    check(same, "deux plans identiques")
  end
  -- mutants du corps de plan_power
  local function mutant(label, from, to)
    local n
    local text = body
    local a, z = text:find(from, 1, true)
    if not a then check(false, "mutant « " .. label .. " » : motif introuvable") return end
    text = text:sub(1, a - 1) .. to .. text:sub(z + 1)
    local pp, world = make(text)
    local bad = 0
    pcall(scenarios, pp, world, function(c) if not c then bad = bad + 1 end end)
    check(bad >= 1, "mutant « " .. label .. " » refusé (" .. bad .. " échec(s))")
  end
  mutant("le but reste le carrefour", "if near then dgoal, dlive = near, live end", "")
  mutant("île comptée vivante", "e.electric_network_id == gen_net and ", "")
  mutant("lots libres coupés d'abord", "direct = Build.Trav.pole_chain(f, surface, a, dgoal, dlink, false, free_street, k, opts)", "direct = Build.Trav.pole_chain(f, surface, a, dgoal, dlink, false, free, k, opts)")
  mutant("pas de repli à travers les lots", "local c2 = Build.Trav.pole_chain(f, surface, a, dgoal, dlink, false, free, k, opts)", "local c2 = nil")
  mutant("pas de route : refus sans essai", "if far or big or not surface or #keys == 0 then return nil, \"pas de rue vers le reseau\", wait end", "if true then return nil, \"pas de rue vers le reseau\", wait end")
  mutant("sans direct, l'attente est perdue", "return nil, \"pas de rue vers le reseau\", no_route.wait", "return nil, \"pas de rue vers le reseau\"")
  mutant("direct avec les grands poteaux", "if not far and not big and surface and (no_route or #nodes >= 2) then", "if not far and surface and (no_route or #nodes >= 2) then")
  mutant("direct jamais retenu", "if use then return direct_out() end", "")
end

print(string.format("[POTEAUX-COURT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
