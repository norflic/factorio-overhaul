--[[
  Lot S5 du ×10, partie FOSWAP (sur essai-0662, après FOREUSES-THERMIQUES) : preuves hors jeu de shared/team/foreuse_swap.lua.
    Q1 S.electric_centers et S.electric_center : même liste (ordre, valeurs) que la référence ;
    Q2 S.plan : même sortie (out, n_ready, n_chain) et mêmes refus (ctx.refused, dans l'ordre) que la référence, sur des modèles tirés
       d'une graine (thermiques et leurs récepteurs, poteaux alimentés ou non, chaînes, places qui tiennent ou non, échanges, réserve
       d'amorçage, bornes d'essais) ;
    Q3 mutants du nouveau code, qui DOIVENT être vus par Q1 ou Q2 ;
    Q4 coût sur le modèle du banc dense (328 thermiques) : instructions Lua (debug.sethook, compte 1), conversions nombre -> chaîne des
       clés de cases, mémoire allouée.
  Référence : tests/fixtures/x10_s5_foreuse_swap_ref.lua, copie EXACTE (même objet git 4d441c32) de shared/team/foreuse_swap.lua à 81305adf.
  Usage (racine du mod) : lua5.2 tests/x10_s5_foswap_test.lua [--court]
]]
package.path = "./?.lua;" .. package.path

local COURT = arg and arg[1] == "--court"
local T = require("shared.team.config")
local P = require("shared.team.plan")
local ok_n, ko_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 else ko_n = ko_n + 1 print("  ECHEC : " .. msg) end
end
local function read(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end
local function load_mod(src, name)
  local fn = assert(load(src, "=" .. name, "t"))
  return fn()
end

local function Rng(seed)
  local s = seed % 2147483647
  if s <= 0 then s = s + 2147483646 end
  local r = {}
  function r.next() s = (s * 16807) % 2147483647 return s end
  function r.int(a, b) return a + (r.next() % (b - a + 1)) end
  function r.pick(t) return t[r.int(1, #t)] end
  return r
end

local function deep_eq(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in next, a do if not deep_eq(v, b[k]) then return false end end
  for k in next, b do if a[k] == nil then return false end end
  return true
end

local function count_instr(fn)
  local c = 0
  debug.sethook(function() c = c + 1 end, "", 1)
  local a, b, d = fn()
  debug.sethook()
  return c, a, b, d
end

local REF_SRC = read("tests/fixtures/x10_s5_foreuse_swap_ref.lua")
local NEW_SRC = read("shared/team/foreuse_swap.lua")
local R = load_mod(REF_SRC, "foreuse_swap_ref")
local S = require("shared.team.foreuse_swap")

-- Q1 : S.electric_centers ---------------------------------------------------------------------------------------------------------
local function q1_run(SS, n, seed)
  local r = Rng(seed)
  local bad = 0
  for _ = 1, n do
    local bx, by = r.int(-60, 60), r.int(-60, 60)
    if r.int(1, 8) == 1 then bx = bx + r.int(1, 255) / 256 end
    if r.int(1, 8) == 1 then by = by + r.int(1, 255) / 256 end
    local dir = r.pick({ 0, 2, 4, 6 })
    if r.int(1, 40) == 1 then dir = nil end -- (revue-s : direction nil, aucun candidat avant comme après)
    local rx, ry = R.rotate(dir, T.drill_drop[1], T.drill_drop[2])
    local px, py = bx + rx, by + ry
    local sink
    local u = r.int(1, 4)
    if u == 1 then sink = { x = math.floor(px) + r.int(0, 1), y = math.floor(py) + r.int(0, 1), w = 2, h = 2 }
    elseif u == 2 then sink = { x = math.floor(px) + 0.5, y = math.floor(py) + 0.5, w = 1, h = 1 }
    elseif u == 3 then sink = { x = bx + r.int(-4, 4) + 0.5 * r.int(0, 1), y = by + r.int(-4, 4), w = r.pick({ 1, 2, 3 }), h = r.pick({ 1, 2, 3 }) }
    else sink = { x = px + r.int(-8, 8) / 4, y = py + r.int(-8, 8) / 4, w = 2, h = 2 } end
    local a = R.electric_centers(bx, by, dir, sink, T.drill_electric)
    local b = SS.electric_centers(bx, by, dir, sink, T.drill_electric)
    local ax, ay = R.electric_center(bx, by, dir, sink, T.drill_electric)
    local cx, cy = SS.electric_center(bx, by, dir, sink, T.drill_electric)
    if not (deep_eq(a, b) and ax == cx and ay == cy) then bad = bad + 1 end
  end
  return bad
end

do
  local n = COURT and 4000 or 20000
  local bad = q1_run(S, n, 101)
  print(string.format("[X10-S5-FOSWAP] Q1 S.electric_centers / S.electric_center : %d cas, %d écarts", n, bad))
  check(bad == 0, "Q1 : mêmes centres que la référence (" .. bad .. " écarts)")
end

-- Q2 : S.plan ----------------------------------------------------------------------------------------------------------------------
--- Un modèle tiré : `spec` décrit tout, et ctx_of(SS, spec) refait le même contexte neuf (S.plan écrit ctx.refused).
local function model(r)
  local m = { entries = {}, poles = {}, blocked = {}, fit = {} }
  local ne = r.int(0, 50)
  local ids = {}
  for k = 1, ne do
    local bx, by = r.int(-70, 70), r.int(-70, 70)
    local dir = r.pick({ 0, 2, 4, 6 })
    local rx, ry = R.rotate(dir, T.drill_drop[1], T.drill_drop[2])
    local px, py = bx + rx, by + ry
    local sink = (r.int(1, 3) > 1) and { x = math.floor(px) + r.int(0, 1), y = math.floor(py) + r.int(0, 1), w = 2, h = 2 }
      or { x = math.floor(px) + 0.5, y = math.floor(py) + 0.5, w = 1, h = 1 }
    local id
    repeat id = r.int(1, 100000) until not ids[id]
    ids[id] = true
    m.entries[k] = { id = id, x = bx, y = by, dir = dir, sink = sink, o = r.int(1, 4) }
  end
  local np = r.int(0, 60)
  for k = 1, np do
    local d = r.pick({ { 2.5, 7.5 }, { 3.5, 9 }, { 2, 30 }, { 9, 18 } })
    m.poles[k] = { id = k, x = r.int(-90, 90) + 0.5, y = r.int(-90, 90) + 0.5, dist = d[1], wire = d[2], powered = r.int(1, 3) == 1 }
  end
  -- des poteaux alimentés juste à côté de quelques thermiques (« déjà alimentées »)
  for k = 1, math.min(ne, r.int(0, 8)) do
    local e = m.entries[r.int(1, ne)]
    m.poles[#m.poles + 1] = { id = 1000 + k, x = e.x + r.int(-3, 3) + 0.5, y = e.y + r.int(-3, 3) + 0.5, dist = 2.5, wire = 7.5, powered = true }
  end
  for _ = 1, r.int(0, 200) do m.blocked[r.int(-95, 95) .. "," .. r.int(-95, 95)] = true end
  m.fit_mode = r.int(1, 4) -- 1 : tout tient ; 2 : hachage ; 3 : échanges ; 4 : sans ctx.fits
  m.fit_seed = r.int(1, 1000000)
  m.have = r.int(0, 6)
  m.obtainable = r.int(1, 8) > 1
  m.limit = r.int(1, 6)
  m.pole = r.pick({ false, { supply = 2.5, wire = 7.5 }, { supply = 3.5, wire = 9 } })
  m.chain_max = r.pick({ nil, 2, 4, 6 })
  m.tries = r.pick({ nil, 1, 3 })
  m.fit_tries = r.pick({ nil, 2, 8, 20 })
  m.reserve = {}
  for o = 1, 4 do
    if r.int(1, 3) == 1 then m.reserve[o] = { burners = r.int(0, 12), keep = r.int(0, 4) } end
  end
  return m
end

local function ctx_of(SS, m)
  local function hash(a, b, c, d) return ((a * 73856093 + math.floor(b * 2) * 19349663 + math.floor(c * 2) * 83492791 + (d or 0) * 2654435) + m.fit_seed) % 7 end
  local fits
  if m.fit_mode == 1 then fits = function() return true end
  elseif m.fit_mode == 2 then fits = function(e, cx, cy, d) return hash(e.id, cx, cy, d) ~= 0 end
  elseif m.fit_mode == 3 then
    fits = function(e, cx, cy, d)
      local h = hash(e.id, cx, cy, d)
      if h == 0 then return false end
      if h <= 2 then return { drills = { e.id + 1 }, ents = {} } end
      return true
    end
  end
  return { poles = m.poles, electric = T.drill_electric, have = m.have, obtainable = m.obtainable, limit = m.limit,
    pole = m.pole or nil,
    free_for = m.pole and function(e, box) return function(x, y)
      if m.blocked[math.floor(x) .. "," .. math.floor(y)] then return false end
      local pb = { x = x, y = y, w = 1, h = 1 }
      return not (SS.overlap(pb, box) or SS.overlap(pb, e.sink))
    end end or nil,
    chain = P.pole_chain, chain_max = m.chain_max, tries = m.tries, fit_tries = m.fit_tries, fits = fits, reserve = m.reserve }
end

local function q2_run(SS, n, seed)
  local r = Rng(seed)
  local bad, first, outs, refs = 0, nil, 0, 0
  for c = 1, n do
    local m = model(r)
    local c0, c1 = ctx_of(R, m), ctx_of(SS, m)
    local o0, r0, h0 = R.plan(m.entries, c0)
    local o1, r1, h1 = SS.plan(m.entries, c1)
    outs, refs = outs + #o0, refs + #(c0.refused or {})
    if not (deep_eq(o0, o1) and r0 == r1 and h0 == h1 and deep_eq(c0.refused, c1.refused)) then
      bad = bad + 1
      first = first or c
    end
  end
  return bad, first, outs, refs
end

do
  local n = COURT and 600 or 3000
  local bad, first, outs, refs = q2_run(S, n, 202)
  print(string.format("[X10-S5-FOSWAP] Q2 S.plan : %d modèles, %d remplacements et %d refus de référence, %d écarts%s", n, outs, refs, bad,
    first and (" ; premier : modèle " .. first) or ""))
  check(bad == 0, "Q2 : S.plan = référence (out, n_ready, n_chain, refus) (" .. bad .. " écarts)")
  check(outs > n / 2 and refs > n / 2, "Q2 : les modèles produisent des remplacements et des refus (" .. outs .. ", " .. refs .. ")")
end

-- Q3 : mutants du nouveau code ------------------------------------------------------------------------------------------------------
do
  local MUT = {
    { "centres : passage en double non sauté", "if i == 0 or d ~= dir then", "if true then", "q1" },
    { "centres : direction nil acceptée", "if dir == nil then return out end", "", "q1" },
    -- (mutant de l'ancienne emprise écarté : les décalages de ±1,5 recouvrent toujours la 2 × 2, test toujours vrai ; même remarque que
    -- tests/foreuse_chaine_test.lua, 7/11)
    { "centres : recouvrement du récepteur en x seulement", "not (in_sx and abs(cy - sy) < lim_sy)", "not (in_sx)", "q1" },
    { "centres : dépôt, partie x avec la demi-hauteur", "if abs(cx + vx - sx) < hw then", "if abs(cx + vx - sx) < hh then", "q1" },
    { "centres : dépôt, partie y oubliée", "if abs(cy + vy - sy) < hh and not (in_sx", "if not (in_sx", "q1" },
    { "centres : direction de la thermique perdue", "local d = (i == 0) and dir or (i - 1) * 2", "local d = (i == 0) and 0 or (i - 1) * 2", "q1" },
    { "couverture : cases voisines oubliées", "    for dy = -1, 1 do\n      for dx = -1, 1 do\n        local g = grid[(gx + dx) * 4194304 + (gy + dy)]\n        if g then\n          for i = 1, #g do\n            local p = g[i]",
      "    for dy = 0, 0 do\n      for dx = 0, 0 do\n        local g = grid[(gx + dx) * 4194304 + (gy + dy)]\n        if g then\n          for i = 1, #g do\n            local p = g[i]", "q2" },
    { "couverture : zone sans le facteur 2", "local l = (2 * p.dist + size) / 2 - EPS", "local l = (p.dist + size) / 2 - EPS", "q2" },
    { "couverture : y non testé", "if abs(p.x - cx) < l and abs(p.y - cy) < l then return true end", "if abs(p.x - cx) < l then return true end", "q2" },
    { "grille : poteau éteint rangé", "    if p.powered then\n      local k = floor(p.x / CELL) * 4194304 + floor(p.y / CELL)",
      "    if true then\n      local k = floor(p.x / CELL) * 4194304 + floor(p.y / CELL)", "q2" },
    -- (lire les lignes de near dans l'autre sens ne change rien : reach_estimate rend un minimum ; on retire la ligne à la place)
    { "grille : ligne de case oubliée à la lecture (chaîne)", "local g = grid[(gx + dx) * 4194304 + (gy + dy)]\n        if g then\n          for i = 1, #g do out",
      "local g = grid[(gx + dx) * 4194304 + gy]\n        if g then\n          for i = 1, #g do out", "q2" },
  }
  local seen = 0
  for _, mu in ipairs(MUT) do
    local a, z = NEW_SRC:find(mu[2], 1, true)
    assert(a, "mutant introuvable : " .. mu[1])
    local ok, M = pcall(load_mod, NEW_SRC:sub(1, a - 1) .. mu[3] .. NEW_SRC:sub(z + 1), "mutant")
    local caught = not ok
    if ok then
      local ok2, bad
      if mu[4] == "q1" then ok2, bad = pcall(q1_run, M, COURT and 4000 or 10000, 101)
      else ok2, bad = pcall(q2_run, M, COURT and 600 or 1500, 202) end
      caught = (not ok2) or bad > 0
    end
    if caught then seen = seen + 1 end
    print(string.format("[X10-S5-FOSWAP] Q3 mutant « %s » : %s", mu[1], caught and "vu" or "NON VU"))
  end
  print(string.format("[X10-S5-FOSWAP] Q3 : mutants vus %d sur %d", seen, #MUT))
  check(seen == #MUT, "Q3 : tous les mutants vus (" .. seen .. " sur " .. #MUT .. ")")
end

-- Q4 : coût sur le modèle du banc dense ---------------------------------------------------------------------------------------------
do
  -- clés de cases de la référence, comptées (même chaîne rendue)
  local KEYS = 0
  local src, n1, n2 = REF_SRC, 0, 0
  src, n1 = src:gsub('math%.floor%(p%.x / S%.CELL%) %.%. ":" %.%. math%.floor%(p%.y / S%.CELL%)', 'S._k(math.floor(p.x / S.CELL), math.floor(p.y / S.CELL))')
  src, n2 = src:gsub('%(gx %+ dx%) %.%. ":" %.%. %(gy %+ dy%)', 'S._k(gx + dx, gy + dy)')
  check(n1 == 1 and n2 == 1, "Q4 : clés de cases de la référence repérées")
  local RK = load_mod(src, "foreuse_swap_ref_compte")
  RK._k = function(a, b) KEYS = KEYS + 1 return a .. ":" .. b end
  local new_conv = select(2, NEW_SRC:gsub('%.%. ":" %.%.', ""))
  for _, sz in ipairs({ 328, 171 }) do
    local entries, poles = {}, {}
    for i = 1, sz do
      local x, y = ((i - 1) % 17) * 4, math.floor((i - 1) / 17) * 6
      entries[i] = { id = 1000 + i, x = x, y = y, dir = 0, sink = { x = x - 1, y = y - 2, w = 2, h = 2 }, o = 1 + math.floor((i - 1) / 60) }
    end
    local pid = 0
    for gx = 0, 68, 8 do
      for gy = 0, math.floor(sz / 17) * 6 + 6, 8 do
        pid = pid + 1
        poles[#poles + 1] = { id = pid, x = gx + 0.5, y = gy + 0.5, dist = 2.5, wire = 7.5, powered = false }
      end
    end
    for k = 1, 6 do
      pid = pid + 1
      poles[#poles + 1] = { id = pid, x = -40 + k * 7, y = -40, dist = 2.5, wire = 7.5, powered = true }
    end
    local function ctx(SS)
      return { poles = poles, electric = T.drill_electric, have = 4, obtainable = true, limit = T.swap.per_pass, pole = { supply = 2.5, wire = 7.5 },
        free_for = function(e, box) return function(x, y)
          local pb = { x = x, y = y, w = 1, h = 1 }
          return not (SS.overlap(pb, box) or SS.overlap(pb, e.sink))
        end end,
        chain = P.pole_chain, chain_max = S.CHAIN_MAX, fits = function() return true end, reserve = {} }
    end
    KEYS = 0
    RK.plan(entries, ctx(RK))
    local keys = KEYS
    local c0 = ctx(R)
    local c1 = ctx(S)
    local i0, o0, r0, h0 = count_instr(function() return R.plan(entries, c0) end)
    local i1, o1, r1, h1 = count_instr(function() return S.plan(entries, c1) end)
    local function alloc(SS)
      collectgarbage("collect") collectgarbage("stop")
      local a = collectgarbage("count")
      SS.plan(entries, ctx(SS))
      local b = collectgarbage("count")
      collectgarbage("restart")
      return b - a
    end
    local k0, k1 = alloc(R), alloc(S)
    print(string.format("[X10-S5-FOSWAP] Q4 modèle dense %d thermiques, %d poteaux : instructions %d -> %d (/%.1f) ; conversions nombre -> chaîne %d -> 0 ; mémoire %.0f -> %.0f Ko",
      sz, #poles, i0, i1, i0 / math.max(1, i1), 2 * keys, k0, k1))
    check(deep_eq(o0, o1) and r0 == r1 and h0 == h1 and deep_eq(c0.refused, c1.refused), "Q4 " .. sz .. " : même plan")
    -- Condition de versement du lead (7/11) : sorties identiques sur un cas où un POTEAU MANQUE. Ici aucune thermique n'est couverte : chaque
    -- remplacement retenu porte sa chaîne de poteaux neufs (out[i].poles non vide).
    local chains = 0
    for _, o in ipairs(o0) do if #o.poles > 0 then chains = chains + 1 end end
    print(string.format("[X10-S5-FOSWAP] Q4 %d : %d remplacement(s), dont %d avec chaîne de poteaux neufs (poteau manquant) ; n_chain %d ; %d refus",
      sz, #o0, chains, h0, #(c0.refused or {})))
    check(chains > 0 and chains == #o0, "Q4 " .. sz .. " : les remplacements retenus posent leur chaîne (poteau manquant)")
    -- Variante : AUCUN poteau à poser (objet poteau ni au stock ni fabricable : ctx.pole = nil) ; mêmes sorties et mêmes refus.
    local function no_pole(SS)
      local c = ctx(SS)
      c.pole, c.free_for = nil, nil
      return c
    end
    local d0, d1 = no_pole(R), no_pole(S)
    local p0, q0, s0 = R.plan(entries, d0)
    local p1, q1, s1 = S.plan(entries, d1)
    check(deep_eq(p0, p1) and q0 == q1 and s0 == s1 and deep_eq(d0.refused, d1.refused), "Q4 " .. sz .. " sans poteau à poser : même plan")
    if sz == 328 then
      check(i0 >= 2 * i1, "Q4 328 : instructions de S.plan divisées par au moins 2")
      check(k1 * 2 <= k0, "Q4 328 : mémoire allouée divisée par au moins 2")
    end
  end
  check(new_conv == 0, "Q4 : plus aucune clé « a:b » construite dans shared/team/foreuse_swap.lua (" .. new_conv .. ")")
end

-- Q5 : cas construit, une thermique à 31 tuiles du réseau alimenté (le cas du DC de tests/foreuse_chaine_test.lua) ---------------------
do
  local e1 = { id = 7, x = 10, y = 10, dir = 0, sink = { x = 9, y = 8, w = 2, h = 2 }, o = 1 }
  local net = { { id = 1, x = 41.5, y = 10.5, dist = 2.5, wire = 7.5, powered = true }, { id = 2, x = 12.5, y = 40.5, dist = 2.5, wire = 7.5, powered = false } }
  local function ctx(SS)
    return { poles = net, electric = T.drill_electric, have = 1, obtainable = true, limit = 2, pole = { supply = 2.5, wire = 7.5 },
      free_for = function(e, box) return function(x, y)
        local pb = { x = x, y = y, w = 1, h = 1 }
        return not (SS.overlap(pb, box) or SS.overlap(pb, e.sink))
      end end, chain = P.pole_chain, chain_max = S.CHAIN_MAX, fits = function() return true end, reserve = {} }
  end
  local c0, c1 = ctx(R), ctx(S)
  local o0, r0, h0 = R.plan({ e1 }, c0)
  local o1, r1, h1 = S.plan({ e1 }, c1)
  print(string.format("[X10-S5-FOSWAP] Q5 thermique à 31 tuiles du réseau : %d remplacement, %d poteau(x) neuf(s) posé(s) par la chaîne", #o0,
    o0[1] and #o0[1].poles or 0))
  check(#o0 == 1 and #o0[1].poles > 0, "Q5 : la référence pose une chaîne (poteau manquant)")
  check(deep_eq(o0, o1) and r0 == r1 and h0 == h1 and deep_eq(c0.refused, c1.refused), "Q5 : même plan, même chaîne de poteaux")
end

print(string.format("[X10-S5-FOSWAP] BILAN : %d OK, %d ECHEC(S)", ok_n, ko_n))
os.exit(ko_n == 0 and 0 or 1)
