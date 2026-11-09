--[[
  Lot PETROLE-RANGEE : test hors jeu du COLLECTEUR d'un champ de puits (shared/ai3/collecteur.lua, règle pure).
    §1 champ de 26 puits sur un terrain libre : tous équipés, emprises disjointes, tuyaux hors emprises, réseau d'un seul tenant,
       raccord de sortie lu au prototype par direction, collecteur droit, embranchements droits ou en L ;
    §2 obstacles : lac et falaise dans le champ, puits dans l'eau écarté avec sa cause, puits trop proches, aucun tuyau sur un obstacle ;
    §3 réseau existant : les embranchements s'y accrochent, le collecteur prolonge la ligne du lot précédent (hint), composantes ;
    §4 lots (max_n) : les puits restants sont comptés « différés », les lots successifs couvrent tout ;
    §5 déterminisme, coût (tuiles lues) ;
    §6 MUTANTS : chaque mutation de la règle est détectée par le vérificateur indépendant (verify).
  Lancement : lua5.2 tests/collecteur_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local Col = require("shared.ai3.collecteur")

local pass, fail = 0, 0
local function check(c, msg)
  if c then pass = pass + 1 else fail = fail + 1; print("[COLLECTEUR] ECHEC : " .. msg) end
end

local tkey, untkey = Col.tkey, Col.untkey
local DV = Col.DV

-- Chevalet vanilla 1.1.91 : 3 x 3, une sortie, raccord explicite par direction (data/base/prototypes/entity/entities.lua)
local EXT = { w = 3, h = 3, boxes = { { type = "output", conns = { [0] = { { 1, -2 } }, [2] = { { 2, -1 } }, [4] = { { -1, 2 } }, [6] = { { -2, 1 } } } } } }

--- Terrain : cartes ASCII. '.' libre, '#' bloqué (falaise), '~' eau, 'W' puits (libre).
local function terrain(rows, ox, oy)
  local blocked, wells = {}, {}
  for j, r in ipairs(rows) do
    for i = 1, #r do
      local ch = r:sub(i, i)
      local tx, ty = ox + i - 1, oy + j - 1
      if ch == "#" or ch == "~" then blocked[tkey(tx, ty)] = ch end
      if ch == "W" then wells[#wells + 1] = { x = tx + 0.5, y = ty + 0.5 } end
    end
  end
  return blocked, wells
end

local function req_of(blocked, wells, extra)
  local r = { wells = wells, ext = EXT, free = function(tx, ty) return not blocked[tkey(tx, ty)] end }
  for k, v in pairs(extra or {}) do r[k] = v end
  return r
end

--- Vérificateur INDÉPENDANT de la règle : rend la liste des violations.
local function verify(res, req, label)
  local bad = {}
  local function ko(m) bad[#bad + 1] = (label or "") .. m end
  local S0 = req.net or {}
  local fp, ftiles = {}, {}
  for _, e in ipairs(res.extractors) do
    local w, h = EXT.w, EXT.h
    if e.dir == 2 or e.dir == 6 then w, h = h, w end
    local x0, y0 = math.floor(e.x - w / 2 + 0.01), math.floor(e.y - h / 2 + 0.01)
    for ty = y0, y0 + h - 1 do
      for tx = x0, x0 + w - 1 do
        local k = tkey(tx, ty)
        if fp[k] then ko(string.format("emprises qui se chevauchent en (%d,%d)", tx, ty)) end
        fp[k] = e
        if not req.free(tx, ty) then ko(string.format("emprise sur une tuile bloquee (%d,%d)", tx, ty)) end
        if S0[k] then ko("emprise sur un tuyau existant") end
        ftiles[#ftiles + 1] = k
      end
    end
    -- raccord lu au prototype pour cette direction
    local p = EXT.boxes[1].conns[e.dir][1]
    local cx, cy = math.floor(e.x + p[1] + 0.01), math.floor(e.y + p[2] + 0.01)
    if cx ~= e.cx or cy ~= e.cy then ko("raccord de sortie different du prototype") end
  end
  local tube = {}
  for _, k in ipairs(res.tubes) do
    if tube[k] then ko("tuyau en double") end
    tube[k] = true
    local tx, ty = untkey(k)
    if fp[k] then ko(string.format("tuyau sur une emprise (%d,%d)", tx, ty)) end
    if not req.free(tx, ty) then ko(string.format("tuyau sur une tuile bloquee (%d,%d)", tx, ty)) end
    if S0[k] then ko("tuyau sur le reseau existant") end
  end
  -- chaque raccord de sortie est sur un tuyau (neuf ou existant)
  for _, e in ipairs(res.extractors) do
    local k = tkey(e.cx, e.cy)
    if not (tube[k] or S0[k]) then ko(string.format("raccord (%d,%d) sans tuyau", e.cx, e.cy)) end
  end
  -- composantes des tuyaux neufs qui ne touchent pas le reseau existant = res.comps
  local all = {}
  for k in pairs(tube) do all[k] = true end
  for k in pairs(S0) do all[k] = true end
  local comp_of, ncomp, touching = {}, 0, {}
  local keys = {}
  for k in pairs(all) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    if not comp_of[k] then
      ncomp = ncomp + 1
      comp_of[k] = ncomp
      local stack = { k }
      while #stack > 0 do
        local c = table.remove(stack)
        local x, y = untkey(c)
        for _, d in ipairs({ 0, 2, 4, 6 }) do
          local nk = tkey(x + DV[d][1], y + DV[d][2])
          if all[nk] and not comp_of[nk] then comp_of[nk] = ncomp; stack[#stack + 1] = nk end
        end
      end
    end
  end
  local has_old = {}
  for k in pairs(S0) do has_old[comp_of[k]] = true end
  local orphan = 0
  local seen = {}
  for _, k in ipairs(keys) do
    local c = comp_of[k]
    if tube[k] and not has_old[c] and not seen[c] then seen[c] = true; orphan = orphan + 1 end
  end
  if orphan ~= #res.comps then ko(string.format("composantes orphelines %d contre %d annoncees", orphan, #res.comps)) end
  -- chaque composante annoncee part d'une tuile qui lui appartient
  for _, c in ipairs(res.comps) do
    if not tube[tkey(c.from[1], c.from[2])] then ko("tuile de depart d'une composante hors des tuyaux neufs") end
  end
  -- les raccords d'une meme composante sont tous reliés : sans reseau existant, au plus res.comps composantes en tout
  local accounted = #res.extractors + #res.skipped + res.deferred
  if accounted ~= #req.wells then ko(string.format("puits comptes %d contre %d", accounted, #req.wells)) end
  -- un puits écarté a une cause
  for _, s in ipairs(res.skipped) do if type(s.cause) ~= "string" or s.cause == "" then ko("puits ecarte sans cause") end end
  return bad
end

--- Tuiles de la composante (4 voisins) des tuyaux neufs qui contient `from`.
local function comp_tiles(res, from)
  local set = {}
  for _, k in ipairs(res.tubes) do set[k] = true end
  local seen, stack, list = {}, { tkey(from[1], from[2]) }, {}
  seen[stack[1]] = true
  while #stack > 0 do
    local k = table.remove(stack)
    list[#list + 1] = k
    local x, y = untkey(k)
    for _, d in ipairs({ 0, 2, 4, 6 }) do
      local nk = tkey(x + DV[d][1], y + DV[d][2])
      if set[nk] and not seen[nk] then seen[nk] = true; stack[#stack + 1] = nk end
    end
  end
  return list
end

--- Rend vrai si le depart de la composante est la tuile la plus proche de la cible (tx, ty) dans sa composante.
local function from_is_nearest(res, c, tx, ty)
  local best
  for _, k in ipairs(comp_tiles(res, c.from)) do
    local x, y = untkey(k)
    local dd = math.abs(x + 0.5 - tx) + math.abs(y + 0.5 - ty)
    if not best or dd < best then best = dd end
  end
  return math.abs(c.from[1] + 0.5 - tx) + math.abs(c.from[2] + 0.5 - ty) == best
end

local function report(bad, ctx)
  for i = 1, math.min(#bad, 3) do print("[COLLECTEUR]   " .. ctx .. " : " .. bad[i]) end
end

-- champ pseudo-aléatoire déterministe (suite congruentielle) : n puits espacés d'au moins 4 tuiles
local function field(n, w, h, seed)
  local s = seed
  local function rnd(m) s = (s * 1103515245 + 12345) % 2147483648; return s % m end
  local wells, tries = {}, 0
  while #wells < n and tries < 20000 do
    tries = tries + 1
    local x, y = 3 + rnd(w - 6), 3 + rnd(h - 6)
    local okw = true
    for _, q in ipairs(wells) do if math.abs(q.x - (x + 0.5)) < 4 and math.abs(q.y - (y + 0.5)) < 4 then okw = false end end
    if okw then wells[#wells + 1] = { x = x + 0.5, y = y + 0.5 } end
  end
  return wells
end

---------------------------------------------------------------------------------------------------
-- §1 champ libre de 26 puits
---------------------------------------------------------------------------------------------------
local free_all = {}
local W26 = field(26, 70, 50, 7)
check(#W26 == 26, "champ de test : 26 puits")
local R1 = req_of(free_all, W26)
local res1 = Col.plan(R1)
local bad1 = verify(res1, R1, "§1 ")
report(bad1, "§1")
check(#bad1 == 0, "§1 aucune violation du verificateur (" .. #bad1 .. ")")
check(#res1.extractors == 26, "§1 les 26 puits sont equipes (" .. #res1.extractors .. ")")
check(#res1.skipped == 0, "§1 aucun puits ecarte")
check(res1.trunk ~= nil, "§1 un collecteur est pose")
check(#res1.comps == 1, "§1 sans reseau existant : une seule composante (" .. #res1.comps .. ")")
do
  local nL, nD, nS = 0, 0, 0
  for _, e in ipairs(res1.extractors) do
    if e.kind == "L" then nL = nL + 1 elseif e.kind == "droit" then nD = nD + 1 else nS = nS + 1 end
    check(e.len <= Col.MAX_LINK, "§1 embranchement borne")
  end
  check(nD + nS >= nL, "§1 plus d'embranchements droits que de L (" .. nD .. "+" .. nS .. " contre " .. nL .. ")")
  -- le collecteur est une ligne droite continue
  local tr = res1.trunk
  local tubes = {}
  for _, k in ipairs(res1.tubes) do tubes[k] = true end
  for t = tr.a, tr.b do
    local k = tr.axis == "h" and tkey(t, tr.c) or tkey(tr.c, t)
    check(tubes[k], "§1 collecteur continu en " .. t)
  end
  check(tr.b - tr.a >= 20, "§1 le collecteur traverse le champ (" .. (tr.b - tr.a + 1) .. " tuiles)")
  -- peu de tuyau : bien moins qu'un chemin par puits de bout en bout
  check(#res1.tubes <= 26 * 10 + (tr.b - tr.a + 1), "§1 tuyaux bornes (" .. #res1.tubes .. ")")
end

---------------------------------------------------------------------------------------------------
-- §2 obstacles
---------------------------------------------------------------------------------------------------
do
  local map = {
    "......................................",
    "......................................",
    "..W.......W.....~~~~~......W..........",
    "..................~~~~~...............",
    "...........#########..................",
    "..W........#.W......#.........W.......",
    "...........#........#.................",
    "...........###..####..................",
    "..........W...........W...............",
    ".......................W..............",
    "......................................",
    "~~~~..................................",
    "~~W~..W..W............................",
    "~~~~..................................",
  }
  local blocked, wells = terrain(map, 0, 0)
  -- un puits en pleine eau : ajouté à la main
  wells[#wells + 1] = { x = 17.5, y = 3.5 }
  wells[#wells + 1] = { x = 2.5, y = 12.5 } -- 'W' dans l'eau '~' : la carte pose 'W' ; on le declare bloque
  blocked[tkey(2, 12)] = "~"
  local R2 = req_of(blocked, wells)
  local res2 = Col.plan(R2)
  local bad2 = verify(res2, R2, "§2 ")
  report(bad2, "§2")
  check(#bad2 == 0, "§2 aucune violation (tuyaux et emprises hors obstacles) (" .. #bad2 .. ")")
  check(#res2.skipped >= 2, "§2 les puits dans l'eau sont ecartes (" .. #res2.skipped .. ")")
  local causes = {}
  for _, s in ipairs(res2.skipped) do causes[s.code] = true end
  check(causes.emprise, "§2 cause « emprise » donnee")
  check(#res2.extractors + #res2.skipped == #wells, "§2 chaque puits est equipe ou ecarte")
  -- puits trop proches : deux chevalets de 3 x 3 ne tiennent pas sur 2 tuiles d'ecart
  local near = { { x = 10.5, y = 10.5 }, { x = 12.5, y = 10.5 }, { x = 20.5, y = 10.5 } }
  local R2b = req_of({}, near)
  local res2b = Col.plan(R2b)
  check(#res2b.extractors == 2 and #res2b.skipped == 1, "§2 deux puits trop proches : un seul equipe (" .. #res2b.extractors .. "/" .. #res2b.skipped .. ")")
  check(res2b.skipped[1] and res2b.skipped[1].code == "voisin", "§2 cause « voisin »")
  check(#verify(res2b, R2b) == 0, "§2 proches : verifie")
end

---------------------------------------------------------------------------------------------------
-- §3 réseau existant et ligne du lot précédent
---------------------------------------------------------------------------------------------------
do
  local W = field(14, 60, 40, 11)
  -- réseau existant : une ligne verticale de 12 tuyaux à l'ouest du champ
  local S0 = {}
  for ty = 5, 16 do S0[tkey(0, ty)] = true end
  local R3 = req_of({}, W, { net = S0, toward = { x = 0.5, y = 10.5 } })
  local res3 = Col.plan(R3)
  local bad3 = verify(res3, R3, "§3 ")
  report(bad3, "§3")
  check(#bad3 == 0, "§3 aucune violation avec reseau existant (" .. #bad3 .. ")")
  check(#res3.extractors == 14, "§3 les 14 puits sont equipes")
  -- sans reseau voisin, la ligne vers lui reste a tracer
  check(#res3.comps >= 1, "§3 la ligne principale reste a tracer (" .. #res3.comps .. " composante(s))")
  local c1 = res3.comps[1]
  check(c1 and c1.n > 0, "§3 composante non vide")
  -- le point de depart est le plus proche de la cible, dans sa composante
  if c1 then check(from_is_nearest(res3, c1, 0.5, 10.5), "§3 depart de la ligne principale au plus pres de la cible") end
  -- ligne du lot précédent : le collecteur la reprend quand elle sert
  local hint = res3.trunk and { axis = res3.trunk.axis, c = res3.trunk.c } or nil
  local W2 = {}
  for _, w in ipairs(W) do W2[#W2 + 1] = { x = w.x, y = w.y } end
  local R3b = req_of({}, W2, { hint = hint })
  local res3b = Col.plan(R3b)
  check(res3b.trunk and hint and res3b.trunk.axis == hint.axis and res3b.trunk.c == hint.c, "§3 le collecteur reprend la ligne du lot precedent")
  -- un puits dont le raccord tombe SUR le reseau existant : aucun tuyau neuf pour lui
  local S1 = {}
  S1[tkey(21, 18)] = true -- raccord nord du chevalet en (20.5, 20.5) : (cx+1, cy-2) = (21, 18)
  local R3c = req_of({}, { { x = 20.5, y = 20.5 } }, { net = S1 })
  local res3c = Col.plan(R3c)
  check(#res3c.extractors == 1 and res3c.extractors[1].len == 0 and #res3c.tubes == 0, "§3 raccord sur le reseau existant : zero tuyau neuf")
  check(#res3c.comps == 0 and res3c.joined, "§3 rien a relier")
  check(#verify(res3c, R3c) == 0, "§3 raccord pose sur le reseau : verifie")
end

---------------------------------------------------------------------------------------------------
-- §4 lots
---------------------------------------------------------------------------------------------------
do
  local W = field(26, 70, 50, 7)
  local R = req_of({}, W, { max_n = 10 })
  local res = Col.plan(R)
  check(#res.extractors == 10 and res.deferred == 16, "§4 lot de 10, 16 differes (" .. #res.extractors .. "/" .. res.deferred .. ")")
  check(#verify(res, R) == 0, "§4 lot verifie")
  -- lots successifs : chaque lot s'accroche au reseau du precedent, tout est equipe
  local net, left, rounds, hint = {}, {}, 0, nil
  for _, w in ipairs(W) do left[#left + 1] = { x = w.x, y = w.y } end
  local equipped, blocked = {}, {}
  local total_ext = 0
  while #left > 0 and rounds < 6 do
    rounds = rounds + 1
    local reqk = { wells = left, ext = EXT, net = net, hint = hint, max_n = 10, toward = { x = 35, y = 25 },
      free = function(tx, ty) return not blocked[tkey(tx, ty)] end }
    local rk = Col.plan(reqk)
    local badk = verify(rk, reqk, "§4 lot " .. rounds .. " ")
    check(#badk == 0, "§4 lot " .. rounds .. " verifie")
    -- le lot suivant voit les emprises et tuyaux du precedent comme occupes
    for _, k in ipairs(rk.tubes) do blocked[k] = true; net[k] = true end
    for _, e in ipairs(rk.extractors) do
      for ty = math.floor(e.y - 1.49), math.floor(e.y + 1.49) do
        for tx = math.floor(e.x - 1.49), math.floor(e.x + 1.49) do blocked[tkey(tx, ty)] = true end
      end
      total_ext = total_ext + 1
    end
    if rk.trunk then hint = { axis = rk.trunk.axis, c = rk.trunk.c } end
    local rest = {}
    local done = {}
    for _, e in ipairs(rk.extractors) do done[e.x .. ":" .. e.y] = true end
    for _, s in ipairs(rk.skipped) do done[s.x .. ":" .. s.y] = true end
    for _, w in ipairs(left) do if not done[w.x .. ":" .. w.y] then rest[#rest + 1] = w end end
    left = rest
  end
  check(#left == 0 and total_ext == 26, "§4 trois lots couvrent les 26 puits (" .. total_ext .. " en " .. rounds .. " lots)")
end

---------------------------------------------------------------------------------------------------
-- §5 déterminisme et coût
---------------------------------------------------------------------------------------------------
local function sig(res)
  local t = {}
  for _, e in ipairs(res.extractors) do t[#t + 1] = string.format("%.1f,%.1f,%d,%s", e.x, e.y, e.dir, e.kind) end
  t[#t + 1] = table.concat(res.tubes, ",")
  for _, s in ipairs(res.skipped) do t[#t + 1] = s.code end
  return table.concat(t, "|")
end
do
  local a = Col.plan(req_of({}, field(26, 70, 50, 7)))
  local b = Col.plan(req_of({}, field(26, 70, 50, 7)))
  check(sig(a) == sig(b), "§5 deux plans identiques")
  -- l'ordre des puits donnés ne change rien
  local W = field(26, 70, 50, 7)
  local rev = {}
  for i = #W, 1, -1 do rev[#rev + 1] = W[i] end
  check(sig(Col.plan(req_of({}, rev))) == sig(a), "§5 ordre des puits sans effet")
  check(a.spent < 8000, "§5 tuiles lues bornees (" .. a.spent .. ")")
end

---------------------------------------------------------------------------------------------------
-- §6 mutants : chaque mutation de la règle doit être vue par le vérificateur ou par un contrôle chiffré
---------------------------------------------------------------------------------------------------
local function load_src()
  local fh = assert(io.open("shared/ai3/collecteur.lua", "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end
local SRC = load_src()

--- Champ de 8 puits parmi trois murs de falaise (graine 231) : le collecteur choisi doit economiser le tuyau (49 tuiles ; 58 quand le
--- jugement des lignes ignore les obstacles).
local function walled(seed)
  local s = seed
  local function rnd(m) s = (s * 1103515245 + 12345) % 2147483648; return s % m end
  local wells, tries = {}, 0
  while #wells < 8 and tries < 5000 do
    tries = tries + 1
    local x, y = 3 + rnd(34), 3 + rnd(24)
    local okw = true
    for _, q in ipairs(wells) do if math.abs(q.x - (x + 0.5)) < 5 and math.abs(q.y - (y + 0.5)) < 5 then okw = false end end
    if okw then wells[#wells + 1] = { x = x + 0.5, y = y + 0.5 } end
  end
  local blocked = {}
  for _ = 1, 3 do
    local bx, by, bw, bh = 3 + rnd(30), 3 + rnd(20), 2 + rnd(8), 1 + rnd(2)
    for tx = bx, bx + bw do for ty = by, by + bh do blocked[tkey(tx, ty)] = true end end
  end
  return wells, blocked
end

local function scenario_failures(M)
  -- rejoue les scènes §1, §2 (obstacles) et §3 avec le module M ; rend le nombre de violations / d'attendus manqués
  local n = 0
  local R = req_of({}, field(26, 70, 50, 7))
  local ok, res = pcall(M.plan, R)
  if not ok then return 99 end
  n = n + #verify(res, R) + ((#res.extractors == 26) and 0 or 1) + (res.trunk and 0 or 1)
  -- obstacles
  local blocked, wells = terrain({
    "........~~~~~~........",
    "..W.....~~~~~~....W...",
    "........~~~~~~........",
    "..W...W........W......",
    "......................",
    "....#####.............",
    "....#.W.#......W......",
    "....#####.............",
  }, 0, 0)
  wells[#wells + 1] = { x = 10.5, y = 1.5 }
  local R2 = req_of(blocked, wells)
  local ok2, res2 = pcall(M.plan, R2)
  if not ok2 then return n + 99 end
  n = n + #verify(res2, R2)
  if #res2.skipped < 1 then n = n + 1 end
  -- voisins
  local R3 = req_of({}, { { x = 10.5, y = 10.5 }, { x = 12.5, y = 10.5 } })
  local res3 = M.plan(R3)
  if #res3.extractors ~= 1 then n = n + 1 end
  -- reseau existant
  local S0 = {}
  for ty = 5, 16 do S0[tkey(0, ty)] = true end
  local R4 = req_of({}, field(14, 60, 40, 11), { net = S0, toward = { x = 0.5, y = 10.5 } })
  local res4 = M.plan(R4)
  n = n + #verify(res4, R4)
  -- raccord sur le reseau
  local S1 = { [tkey(21, 18)] = true }
  local R5 = req_of({}, { { x = 20.5, y = 20.5 } }, { net = S1 })
  local res5 = M.plan(R5)
  if not (#res5.extractors == 1 and res5.extractors[1].len == 0 and #res5.tubes == 0) then n = n + 1 end
  -- depart de la ligne principale au plus pres de la cible
  if res4.comps[1] and not from_is_nearest(res4, res4.comps[1], 0.5, 10.5) then n = n + 1 end
  -- raccord nord bloque : le chevalet se tourne ailleurs et reste equipe
  local R7 = req_of({ [tkey(11, 8)] = "#" }, { { x = 10.5, y = 10.5 } })
  local res7 = M.plan(R7)
  if not (#res7.extractors == 1 and res7.extractors[1].dir ~= 0) then n = n + 1 end
  n = n + #verify(res7, R7)
  -- longueur exacte : reseau existant a 6 tuiles du raccord nord
  local S2 = {}
  for ty = 5, 12 do S2[tkey(21, ty)] = true end
  local R8 = req_of({}, { { x = 20.5, y = 20.5 } }, { net = S2 })
  local res8 = M.plan(R8)
  if not (#res8.extractors == 1 and res8.extractors[1].len == 6 and #res8.tubes == 6) then n = n + 1 end
  n = n + #verify(res8, R8)
  -- falaise sur la mediane du champ : le collecteur ne la traverse pas
  local blk9 = {}
  for tx = 24, 27 do for ty = 6, 14 do blk9[tkey(tx, ty)] = "#" end end
  local w9 = { { x = 10.5, y = 10.5 }, { x = 18.5, y = 10.5 }, { x = 33.5, y = 10.5 }, { x = 41.5, y = 10.5 } }
  local R9 = req_of(blk9, w9)
  local res9 = M.plan(R9)
  n = n + #verify(res9, R9)
  -- ordre des puits donnes sans effet quand deux puits sont a egale distance
  local wa = { { x = 20.5, y = 5.5 }, { x = 20.5, y = 7.5 } }
  local wb = { { x = 20.5, y = 7.5 }, { x = 20.5, y = 5.5 } }
  local ra = M.plan(req_of({}, wa, { toward = { x = 50.5, y = 6.5 } }))
  local rb = M.plan(req_of({}, wb, { toward = { x = 50.5, y = 6.5 } }))
  if sig(ra) ~= sig(rb) then n = n + 1 end
  -- ligne du lot precedent differente de la ligne naturelle : reprise
  local W10 = field(14, 60, 40, 11)
  local nat = M.plan(req_of({}, W10))
  if nat.trunk then
    local hc = nat.trunk.c + 2
    local rh = M.plan(req_of({}, W10, { hint = { axis = nat.trunk.axis, c = hc } }))
    if not (rh.trunk and rh.trunk.c == hc) then n = n + 1 end
  else
    n = n + 1
  end
  -- murs de falaise : collecteur economique
  local ww, wb = walled(231)
  local R11 = req_of(wb, ww)
  local res11 = M.plan(R11)
  n = n + #verify(res11, R11)
  if not (#res11.extractors == 8 and #res11.tubes <= 52) then n = n + 1 end
  -- lot
  local R6 = req_of({}, field(26, 70, 50, 7), { max_n = 10 })
  local res6 = M.plan(R6)
  if not (#res6.extractors == 10 and res6.deferred == 16) then n = n + 1 end
  return n
end

local function mutate(name, from, to)
  local i, j = SRC:find(from, 1, true)
  if not i then print("[COLLECTEUR] ECHEC : mutant '" .. name .. "' : motif introuvable"); fail = fail + 1; return end
  local src = SRC:sub(1, i - 1) .. to .. SRC:sub(j + 1)
  local chunk, err = load(src, "=mutant", "t")
  if not chunk then print("[COLLECTEUR] ECHEC : mutant '" .. name .. "' ne compile pas : " .. tostring(err)); fail = fail + 1; return end
  local M = chunk()
  local n = scenario_failures(M)
  check(n > 0, "mutant '" .. name .. "' survit (aucun controle ne le voit)")
end

-- le module non muté passe
check(scenario_failures(Col) == 0, "§6 le module non mute passe les scenes des mutants")

mutate("emprises sans controle de chevauchement", "if occ[tkey(tx, ty)] then clash = true end", "")
mutate("emprise sur tuile bloquee acceptee", "if S0[tkey(tx, ty)] or not free(tx, ty) then ok = false end", "")
mutate("raccord toujours vers le nord", "local cx, cy = out_conn(ext, w.x, w.y, d)", "local cx, cy = out_conn(ext, w.x, w.y, 0)")
mutate("tuyau traverse une emprise", "if occ[kk] or not free(x, y) then return false end", "if not free(x, y) then return false end")
mutate("tuyau sur obstacle (pass ignore free)", "    return free(tx, ty)\n  end\n  local xmin", "    return true\n  end\n  local xmin")
mutate("longueur du tracé fausse", "offer(neu, (dx == 0 or dy == 0)", "offer(neu + 1, (dx == 0 or dy == 0)")
mutate("collecteur : rayon droit sans controle de passage", "if not pass(tx, ty) then ok = false break end", "")
mutate("lot ignore max_n", "if #acc >= max_n then", "if false then")
mutate("puits differes non comptes", "out.deferred = out.deferred + 1", "")
mutate("puits ecarte sans cause", "cause = cause, code = code }", "cause = \"\", code = code }")
mutate("ordre des puits par x seulement", "if a.y ~= b.y then return a.y < b.y end\n    return a.x < b.x\n  end)\n  local occ", "return a.x < b.x\n  end)\n  local occ")
mutate("composantes non comptees", "out.comps[#out.comps + 1] = { from = { fx, fy }, n = n }", "")
mutate("hint ignore", "local hinted = (req.hint and cd.axis == req.hint.axis and cd.c == req.hint.c) and 1 or 0", "local hinted = 0")
mutate("collecteur jamais pose", "if trunk then\n    local lo, hi", "if false then\n    local lo, hi")
mutate("reseau existant ignore", "local S0 = req.net or {}", "local S0 = {}")
mutate("depart de la ligne principale au plus loin", "if not bd or dd < bd then bk, bd = ck, dd end", "if not bd or dd > bd then bk, bd = ck, dd end")

-- §7 champ : puits liés de proche en proche
local function cluster_failures(M)
  local n = 0
  local wells = { { x = 10.5, y = 10.5 }, { x = 20.5, y = 10.5 }, { x = 30.5, y = 12.5 }, { x = 90.5, y = 10.5 }, { x = 40.5, y = 12.5 }, { x = 10.5, y = 30.5 }, { x = 14.5, y = 8.5 } }
  local seeds = { { x = 10.5, y = 10.5 } }
  local c = M.cluster(wells, seeds, 12, nil)
  -- chaine 10 -> 20 -> 30 -> 40 en x (ecart 10) ; (90, 10) et (10, 30) trop loin
  if #c ~= 5 then n = n + 1 end
  for _, w in ipairs(c) do if w.x == 90.5 or w.y == 30.5 then n = n + 1 end end
  -- tri (y, x)
  for i = 2, #c do if c[i - 1].y > c[i].y or (c[i - 1].y == c[i].y and c[i - 1].x > c[i].x) then n = n + 1 end end
  -- coupe : les plus proches des graines restent
  local cut = M.cluster(wells, seeds, 12, 2)
  if #cut ~= 2 then n = n + 1 else
    for _, w in ipairs(cut) do if w.x > 25 then n = n + 1 end end
    if cut[1].y > cut[2].y then n = n + 1 end
  end
  -- sans graine : aucun puits
  if #M.cluster(wells, {}, 12, nil) ~= 0 then n = n + 1 end
  -- ordre d'entree sans effet
  local rev = {}
  for i = #wells, 1, -1 do rev[#rev + 1] = wells[i] end
  local a, b = M.cluster(wells, seeds, 12, nil), M.cluster(rev, seeds, 12, nil)
  if #a ~= #b then n = n + 1 else for i = 1, #a do if a[i].x ~= b[i].x or a[i].y ~= b[i].y then n = n + 1 end end end
  return n
end
check(cluster_failures(Col) == 0, "§7 champ : chaine de puits, ilots exclus, coupe, tri")
local function mutate_cluster(name, from, to)
  local i, j = SRC:find(from, 1, true)
  if not i then print("[COLLECTEUR] ECHEC : mutant '" .. name .. "' : motif introuvable"); fail = fail + 1; return end
  local chunk = assert(load(SRC:sub(1, i - 1) .. to .. SRC:sub(j + 1), "=mutant", "t"))
  check(cluster_failures(chunk()) > 0, "mutant '" .. name .. "' survit")
end
mutate_cluster("ecart ignore", "if abs(p.x - q.x) <= gap and abs(p.y - q.y) <= gap then", "if true then")
mutate_cluster("pas de proche en proche", "front[#front + 1] = p\n            changed = true", "changed = true")
mutate_cluster("coupe sans tri par distance", "local da, db = (a.x - sx) ^ 2 + (a.y - sy) ^ 2, (b.x - sx) ^ 2 + (b.y - sy) ^ 2", "local da, db = -a.x, -b.x")
mutate_cluster("liste non triee", "local cut = {}\n    for i = 1, max do cut[i] = out[i] end\n    table.sort(cut, function(a, b)\n      if a.y ~= b.y then return a.y < b.y end\n      return a.x < b.x\n    end)\n    out = cut", "local cut = {}\n    for i = 1, max do cut[i] = out[i] end\n    out = cut")

print(string.format("[COLLECTEUR] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
