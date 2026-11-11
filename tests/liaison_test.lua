--[[
  Lot INDUSTRIE I7 (LIAISONS) : test hors jeu de la liaison de quai (shared/team/liaison.lua) et de son branchement (script/team/liaison.lua,
  script/team/build.lua, lus comme texte).
    §1 constantes contre l'automatisation (marche, prise, pose) ; §2 prix (Li.worth) ; §3 sites et bouts ; §4 tracé accepté ;
    §5 entités et preuve géométrique sur des dispositions tirées (aucun nom d'objet) ; §6 appariement ; §7 décision ; §8 barre ;
    §9 déterminisme ; §10 aucun nom d'objet, aucun pairs dans la règle ; §11 branchement ; §12 mutants : chaque règle retirée est vue.
  Usage : lua5.2 tests/liaison_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/liaison.lua")
local function load_l(src)
  local fn, err = load(src, "=liaison", "t")
  assert(fn, err)
  return fn()
end
local Li = load_l(SRC)

-- §1 constantes de prix = celles de l'automatisation
local A = require("shared.ai3.automatiser")
check(Li.WALK == A.WALK and Li.HANDLE_S == A.HANDLE_S and Li.POSE_S == A.POSE_S and Li.BATCH == A.BATCH,
  "1.1 marche, prise, pose et lot de chantier comme shared/ai3/automatiser.lua")

-- §2 prix
local function winp(t)
  local base = { flow = 2.0, dist = 56, span = 28, fill = 400, low = 60 }
  for k, v in pairs(t or {}) do base[k] = v end
  return base
end
local ok, why, det = Li.worth(winp())
check(ok == true and det.payback_min > 0 and det.payback_min <= det.tmax, "2.1 gros debit, quai loin : la liaison se paie (" .. why .. ")")
check(Li.worth(winp({ flow = 0.1 })) == false, "2.2 petit debit : ne se paie pas")
check(Li.worth(winp({ flow = 0 })) == false and Li.worth(winp({ flow = Li.MIN_FLOW / 2 })) == false, "2.3 debit nul ou sous Li.MIN_FLOW : refuse")
local _, _, d_near = Li.worth(winp({ dist = 20 }))
local _, _, d_far = Li.worth(winp({ dist = 120 }))
check(d_far.payback_min < d_near.payback_min, "2.4 un quai plus loin du QG se paie plus vite (aller-retour plus long)")
local _, _, d_short = Li.worth(winp({ span = 10 }))
local _, _, d_long = Li.worth(winp({ span = 38 }))
check(d_short.payback_min < d_long.payback_min, "2.5 un tapis plus court se paie plus vite")
local _, _, d_flow1 = Li.worth(winp({ flow = 1 }))
local _, _, d_flow2 = Li.worth(winp({ flow = 2 }))
check(math.abs(d_flow1.payback_min / d_flow2.payback_min - 2) < 1e-9, "2.6 retour inversement proportionnel au debit")
check(Li.worth(winp({ threat = true })) == false or select(3, Li.worth(winp({ threat = true }))).tmax == Li.TMAX / Li.THREAT_DIV,
  "2.7 menace : retour accepte divise par Li.THREAT_DIV")
local _, _, d_thr = Li.worth(winp({ threat = true }))
check(d_thr.tmax == Li.TMAX / Li.THREAT_DIV, "2.8 tmax sous menace")
local o_cheap = Li.worth(winp({ flow = 1.2, price = { belt = 0.1, arm = 0.1, pole = 0.1 } }))
local o_dear = Li.worth(winp({ flow = 1.2, price = { belt = 50, arm = 50, pole = 50 } }))
check(o_cheap == true and o_dear == false, "2.9 le prix des pieces compte")
local _, _, d_t = Li.worth(winp({ tiles = 20 }))
local _, _, d_t2 = Li.worth(winp({ tiles = 60 }))
check(d_t2.cost > d_t.cost and d_t2.build_s > d_t.build_s, "2.10 le tapis reel remplace l'estimation (cout et pose)")
check(Li.worth(winp({ tmax = 1 })) == false and Li.worth(winp({ tmax = 100000, flow = 0.05 })) == true, "2.11 Tmax passe en argument")
-- le prix du travail est positif meme quand tous les bras sont libres : aucune entree n'est « 0 »
check(Li.LABOR_VALUE > 0, "2.12 prix du travail toujours positif")

-- §3 sites et bouts
local function open_grid(blocked)
  return function(x, y) return not (blocked and blocked[x .. ":" .. y]) end
end
local sites = Li.sites(10, 10, open_grid())
check(#sites == 4, "3.1 terrain libre : quatre sites")
check(sites[1].dir == 0 and sites[1].ax == 10 and sites[1].ay == 9 and sites[1].bx == 10 and sites[1].by == 8, "3.2 site nord : bras en (10, 9), tapis en (10, 8)")
check(sites[2].dir == 2 and sites[2].ax == 11 and sites[2].bx == 12, "3.3 site est")
local s_b = Li.sites(10, 10, open_grid({ ["10:8"] = true, ["11:10"] = true }))
check(#s_b == 2 and s_b[1].dir == 4 and s_b[2].dir == 6, "3.4 tuile de tapis ou de bras prise : site ecarte")
check(#Li.sites(10, 10, open_grid({ ["10:9"] = true, ["11:10"] = true, ["10:11"] = true, ["9:10"] = true })) == 0, "3.5 coffre muré : aucun site")
local S, D = { x = 0, y = 0 }, { x = 20, y = 0 }
local ends = Li.pick_ends(S, D, open_grid())
check(#ends > 0 and ends[1].src.dir == 2 and ends[1].dst.dir == 6, "3.6 deux coffres face a face : tapis entre eux (est -> ouest)")
check(ends[1].span == 16, "3.7 tuiles de tapis a 16 l'une de l'autre")
for i = 2, #ends do check(ends[i - 1].span <= ends[i].span, "3.8 paires triees par distance") end
check(#Li.pick_ends(S, D, open_grid(), 3) == 3, "3.9 au plus `max` paires")
-- coffres a 2 tuiles : le bras de l'un tombe sur celui de l'autre
local near = Li.pick_ends({ x = 0, y = 0 }, { x = 2, y = 0 }, open_grid())
local bad_pair = false
for _, e in ipairs(near) do
  if (e.src.ax == e.dst.ax and e.src.ay == e.dst.ay) or (e.src.ax == e.dst.bx and e.src.ay == e.dst.by) or (e.dst.ax == e.src.bx and e.dst.ay == e.src.by) then bad_pair = true end
end
check(not bad_pair, "3.10 jamais un bras sur l'autre bras ni sur le tapis de l'autre")
local px, py = Li.pole_tile(sites[1], open_grid())
check(px == 9 and py == 9, "3.11 poteau contre le bras, sur le cote (a l'ouest d'un bras au nord)")
check(px ~= sites[1].ax or py ~= sites[1].ay, "3.12 jamais sur le bras")
local px2, py2 = Li.pole_tile(sites[1], open_grid({ ["11:9"] = true, ["9:9"] = true }))
check(px2 ~= nil and math.abs(px2 - 10) == 1 and math.abs(py2 - 9) == 1, "3.13 cotes pris : une diagonale")
local six = { ["11:9"] = true, ["9:9"] = true, ["11:8"] = true, ["9:8"] = true, ["11:10"] = true, ["9:10"] = true }
local rx, ry = Li.pole_tile(sites[1], open_grid(six))
check(rx ~= nil and math.max(math.abs(rx - 10), math.abs(ry - 9)) == 2, "3.14 six tuiles collees prises : anneau de distance 2 (lot RESEAU-GRAPHE)")
local rx2, ry2 = Li.pole_tile(sites[1], open_grid(six))
check(rx == rx2 and ry == ry2, "3.14b choix deterministe")
local wall = {}
for k in pairs(six) do wall[k] = true end
for dx = -2, 2 do for dy = -2, 2 do wall[(10 + dx) .. ":" .. (9 + dy)] = true end end
check(Li.pole_tile(sites[1], open_grid(wall)) == nil, "3.14c rien de libre a distance 2 : nil")
local near2 = {}
for k in pairs(six) do near2[k] = true end
near2["8:9"] = nil
local nx, ny = Li.pole_tile(sites[1], open_grid((function() local w = {} for k in pairs(wall) do w[k] = true end w["8:9"] = nil return w end)()))
check(nx == 8 and ny == 9, "3.14d la tuile libre de l'anneau est trouvee")
local taken = { ["9:9"] = true }
local px3 = Li.pole_tile(sites[1], open_grid(), taken)
check(px3 == 11, "3.15 tuile deja prise (autre poteau) ecartee")
-- l'anneau de repli est borne par la zone d'alimentation LUE dans les donnees du jeu (pas une constante du test)
do
  local cands = { "../../data", "../../../../../data" }
  if os.getenv("FO_DATA_DIR") then table.insert(cands, 1, os.getenv("FO_DATA_DIR")) end
  local fh
  for _, d in ipairs(cands) do fh = d and io.open(d .. "/base/prototypes/entity/entities.lua", "rb") if fh then break end end
  if fh then
    local txt = fh:read("*a") fh:close()
    local blk = txt:match('name = "small%-electric%-pole".-supply_area_distance = ([%d%.]+)')
    local supply = tonumber(blk)
    check(supply ~= nil, "3.17 supply_area_distance du petit poteau lu dans les donnees du jeu (" .. tostring(supply) .. ")")
    if supply then
      local d = 0
      while (d + 1) - 0.5 < supply do d = d + 1 end
      check(Li.POLE_RING == d, "3.18 anneau de repli = plus grand d avec d - 0,5 < supply_area_distance (" .. d .. ")")
      check(Li.POLE_RING - 0.5 < supply, "3.19 un poteau a l'anneau couvre bien la tuile du bras")
      local ring_ok = true
      for dx = -Li.POLE_RING, Li.POLE_RING do for dy = -Li.POLE_RING, Li.POLE_RING do
        local rx3, ry3 = Li.pole_tile(sites[1], function(x, y) return x == sites[1].ax + dx and y == sites[1].ay + dy and math.max(math.abs(dx), math.abs(dy)) == Li.POLE_RING end)
        if rx3 ~= nil and (math.abs(rx3 - sites[1].ax) - 0.5 >= supply or math.abs(ry3 - sites[1].ay) - 0.5 >= supply) then ring_ok = false end
      end end
      check(ring_ok, "3.20 toute tuile rendue par le repli est dans la zone d'alimentation du petit poteau")
    end
  else
    print("  (info) donnees du jeu introuvables : 3.17 a 3.20 sautes")
  end
end
check(Li.end_dir(sites[1]) == 4, "3.16 la derniere tuile regarde le bras d'arrivee")

-- §4 tracé accepté
check(Li.route_ok(17, 16) == true, "4.1 tracé droit accepte")
check(Li.route_ok(Li.MAX_LEN + 1, Li.MAX_LEN) == false, "4.2 plus de Li.MAX_LEN tuiles : refuse")
check(Li.route_ok(Li.MAX_LEN, Li.MAX_LEN - 1) == true, "4.3 Li.MAX_LEN tuiles droites : accepte")
check(Li.route_ok(40, 10) == false, "4.4 detour de 4 fois : refuse (remarque du DC)")
check(Li.route_ok(20, 12) == true, "4.5 detour modere : accepte")
local _, why44 = Li.route_ok(40, 10)
check(why44:find("detour") ~= nil, "4.6 la raison nomme le detour")

-- §5 entités et preuve géométrique : un petit monde tiré, A* par largeur
local function bfs(sx, sy, tx, ty, blocked, last_dir)
  local key = function(x, y) return x .. ":" .. y end
  local prev, q, head = { [key(sx, sy)] = false }, { { sx, sy } }, 1
  local ORDER = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }
  while head <= #q do
    local cur = q[head]
    head = head + 1
    if cur[1] == tx and cur[2] == ty then
      local tiles, k = {}, cur
      while k do
        table.insert(tiles, 1, { x = k[1], y = k[2] })
        k = prev[key(k[1], k[2])]
      end
      for i = 1, #tiles - 1 do tiles[i].dir = Li.dir_of(tiles[i + 1].x - tiles[i].x, tiles[i + 1].y - tiles[i].y) end
      tiles[#tiles].dir = last_dir
      return tiles
    end
    for _, o in ipairs(ORDER) do
      local nx, ny = cur[1] + o[1], cur[2] + o[2]
      if nx >= -5 and nx <= 40 and ny >= -15 and ny <= 35 and prev[key(nx, ny)] == nil and not blocked[key(nx, ny)] then
        prev[key(nx, ny)] = cur
        q[#q + 1] = { nx, ny }
      end
    end
  end
  return nil
end
local names = { arm = "A", belt = "B", pole = "P" }
local function isbelt(e) return e.role == "liaison-tapis" end
local function isarm(e) return e.role == "liaison-bras" end
local function build_world(S, D, wall)
  local blocked = { [S.x .. ":" .. S.y] = true, [D.x .. ":" .. D.y] = true }
  for _, w in ipairs(wall or {}) do blocked[w[1] .. ":" .. w[2]] = true end
  local free = function(x, y) return not blocked[x .. ":" .. y] end
  local picks = Li.pick_ends(S, D, free, 8)
  for _, e in ipairs(picks) do
    local blk = {}
    for k in pairs(blocked) do blk[k] = true end
    blk[e.src.ax .. ":" .. e.src.ay] = true
    blk[e.dst.ax .. ":" .. e.dst.ay] = true
    local route = bfs(e.src.bx, e.src.by, e.dst.bx, e.dst.by, blk, Li.end_dir(e.dst))
    if route then
      local taken = {}
      for _, t in ipairs(route) do taken[t.x .. ":" .. t.y] = true end
      local p1 = { Li.pole_tile(e.src, free, taken) }
      if p1[1] then taken[p1[1] .. ":" .. p1[2]] = true end
      local p2 = { Li.pole_tile(e.dst, free, taken) }
      return Li.entities({ src = e.src, dst = e.dst, route = route, names = names, poles = { p1, p2 } }), e, route
    end
  end
  return nil
end
local worlds = {
  { { x = 0, y = 0 }, { x = 20, y = 0 }, {} },
  { { x = 0, y = 0 }, { x = 0, y = 20 }, {} },
  { { x = 20, y = 10 }, { x = 3, y = -4 }, {} },
  { { x = 5, y = 5 }, { x = 5, y = 12 }, { { 5, 8 }, { 6, 8 }, { 4, 8 }, { 7, 8 }, { 3, 8 } } },
  { { x = 0, y = 0 }, { x = 3, y = 3 }, {} },
  { { x = 0, y = 0 }, { x = 2, y = 0 }, {} },
}
for wi, w in ipairs(worlds) do
  local ents, e, route = build_world(w[1], w[2], w[3])
  check(ents ~= nil, "5." .. wi .. ".1 monde " .. wi .. " : un tracé existe")
  if ents then
    local bad = Li.verify(ents, w[1], w[2], isbelt, isarm)
    check(#bad == 0, "5." .. wi .. ".2 monde " .. wi .. " : chaque bras prend et depose ou le modele le dit (" .. table.concat(bad, "; ") .. ")")
    local nb, na, np = 0, 0, 0
    for _, x in ipairs(ents) do
      if isbelt(x) then nb = nb + 1 elseif isarm(x) then na = na + 1 else np = np + 1 end
    end
    check(nb == #route and na == 2 and np == 2, "5." .. wi .. ".3 monde " .. wi .. " : tapis, 2 bras, 2 poteaux")
    local seen, dup = {}, false
    for _, x in ipairs(ents) do
      local k = math.floor(x.x) .. ":" .. math.floor(x.y)
      if seen[k] then dup = true end
      seen[k] = true
      if k == w[1].x .. ":" .. w[1].y or k == w[2].x .. ":" .. w[2].y then dup = true end
    end
    check(not dup, "5." .. wi .. ".4 monde " .. wi .. " : aucune entite sur une autre ni sur un coffre")
  end
end
-- la preuve voit les fautes
local ents0, e0 = build_world({ x = 0, y = 0 }, { x = 20, y = 0 }, {})
local function copy_ents(list)
  local out = {}
  for _, x in ipairs(list) do out[#out + 1] = { name = x.name, x = x.x, y = x.y, dir = x.dir, role = x.role } end
  return out
end
local flip = copy_ents(ents0)
for _, x in ipairs(flip) do if isarm(x) then x.dir = (x.dir + 4) % 8 break end end
check(#Li.verify(flip, { x = 0, y = 0 }, { x = 20, y = 0 }, isbelt, isarm) > 0, "5.7.1 bras de depart retourne : vu")
local flip2 = copy_ents(ents0)
local arms_seen = 0
for _, x in ipairs(flip2) do if isarm(x) then arms_seen = arms_seen + 1; if arms_seen == 2 then x.dir = (x.dir + 4) % 8 end end end
check(#Li.verify(flip2, { x = 0, y = 0 }, { x = 20, y = 0 }, isbelt, isarm) > 0, "5.7.2 bras d'arrivee retourne : vu")
local cut = copy_ents(ents0)
for i, x in ipairs(cut) do if isbelt(x) and i == 6 then table.remove(cut, i) break end end
check(#Li.verify(cut, { x = 0, y = 0 }, { x = 20, y = 0 }, isbelt, isarm) > 0, "5.7.3 tuile de tapis absente : vu")
local turn = copy_ents(ents0)
for i, x in ipairs(turn) do if isbelt(x) and i == 6 then x.dir = (x.dir + 2) % 8 break end end
check(#Li.verify(turn, { x = 0, y = 0 }, { x = 20, y = 0 }, isbelt, isarm) > 0, "5.7.4 tuile tournee : vu")
local lastflip = copy_ents(ents0)
local lastbelt
for i, x in ipairs(lastflip) do if isbelt(x) then lastbelt = i end end
lastflip[lastbelt].dir = (lastflip[lastbelt].dir + 4) % 8
check(#Li.verify(lastflip, { x = 0, y = 0 }, { x = 20, y = 0 }, isbelt, isarm) > 0, "5.7.5 derniere tuile tournee a l'envers : vu")
check(#Li.verify(ents0, { x = 1, y = 0 }, { x = 20, y = 0 }, isbelt, isarm) > 0, "5.7.6 mauvais coffre de depart : vu")
check(#Li.verify(ents0, { x = 0, y = 0 }, { x = 21, y = 0 }, isbelt, isarm) > 0, "5.7.7 mauvais coffre d'arrivee : vu")
-- une route tiree au hasard (graine fixe) : la preuve tient sur 200 dispositions
local seed = 12345
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end
local good, tried = 0, 0
for _ = 1, 200 do
  local Sx, Sy, Dx, Dy = rnd(30), rnd(20) - 10, rnd(30), rnd(20) - 10
  if math.abs(Sx - Dx) + math.abs(Sy - Dy) >= 3 then
    local wall = {}
    for _ = 1, 25 do wall[#wall + 1] = { rnd(36) - 3, rnd(26) - 13 } end
    local ents, _, _ = build_world({ x = Sx, y = Sy }, { x = Dx, y = Dy }, wall)
    if ents then
      tried = tried + 1
      if #Li.verify(ents, { x = Sx, y = Sy }, { x = Dx, y = Dy }, isbelt, isarm) == 0 then good = good + 1 end
    end
  end
end
check(tried >= 100 and good == tried, string.format("5.8 200 dispositions tirees : %d tracees, %d prouvees", tried, good))

-- §6 appariement
local function dock(key, pid, x, y, item, flow, linked) return { key = key, pid = pid, x = x, y = y, item = item, flow = flow, linked = linked } end
local function src(key, pid, x, y, item, linked) return { key = key, pid = pid, x = x, y = y, item = item, linked = linked } end
local docks = { dock("d1", 2, 30, 0, "X", 1.0), dock("d2", 3, 30, 10, "X", 2.0), dock("d3", 4, 80, 0, "Y", 1.0) }
local srcs = { src("s1", 1, 10, 0, "X"), src("s2", 5, 40, 12, "X"), src("s3", 6, 60, 0, "Z") }
local pr = Li.pairs(docks, srcs)
check(#pr == 2, "6.1 deux paires (le quai Y n'a pas de source) : " .. #pr)
check(pr[1].dock.key == "d2" and pr[1].src.key == "s2", "6.2 le quai de plus gros debit choisit d'abord, la source la plus proche")
check(pr[2].dock.key == "d1" and pr[2].src.key == "s1", "6.3 le second quai prend la source restante")
check(#Li.pairs({ dock("d", 1, 0, 0, "X", 1) }, { src("s", 1, 5, 0, "X") }) == 0, "6.4 jamais un quai relie a la sortie de son propre projet")
check(#Li.pairs({ dock("d", 1, 0, 0, "X", 1) }, { src("s", 2, Li.MAX_SPAN + 1, 0, "X") }) == 0, "6.5 au-dela de Li.MAX_SPAN : rien")
check(#Li.pairs({ dock("d", 1, 0, 0, "X", 1) }, { src("s", 2, Li.MAX_SPAN, 0, "X") }) == 1, "6.6 a Li.MAX_SPAN : une paire")
check(#Li.pairs({ dock("d", 1, 0, 0, "X", 1, true) }, { src("s", 2, 5, 0, "X") }) == 0, "6.7 quai deja relie : rien")
check(#Li.pairs({ dock("d", 1, 0, 0, "X", 1) }, { src("s", 2, 5, 0, "X", true) }) == 0, "6.8 coffre de sortie deja pris : rien")
check(#Li.pairs({ dock("d", 1, 0, 0, "X", Li.MIN_FLOW / 2) }, { src("s", 2, 5, 0, "X") }) == 0, "6.9 debit sous le minimum : rien")
local two = Li.pairs({ dock("a", 1, 0, 0, "X", 1), dock("b", 2, 0, 10, "X", 1) }, { src("s", 3, 5, 5, "X") })
check(#two == 1 and two[1].dock.key == "a", "6.10 une source pour deux quais egaux : le premier par cle, un seul")
local tie = Li.pairs({ dock("d", 1, 0, 0, "X", 1) }, { src("s2", 2, 5, 0, "X"), src("s1", 3, 0, 5, "X") })
check(tie[1].src.key == "s1", "6.11 distances egales : cle la plus petite")
check(#Li.pairs({ dock("d", 1, 0, 0, nil, 1) }, { src("s", 2, 5, 0, nil) }) == 0, "6.12 objet inconnu : rien")

-- §7 décision
local function dinp(t)
  local base = { worth = true, worth_why = "ok", open = false, open_total = 0, seen = Li.CONFIRM, tries = 0, enemies = 0, threat = false }
  for k, v in pairs(t or {}) do base[k] = v end
  return base
end
check(Li.decide(dinp()) == "relier", "7.1 cas nominal : relier")
check(Li.decide(dinp({ worth = false, worth_why = "retour 99 min" })) == "laisser", "7.2 ne se paie pas : laisser (a la main)")
local _, why72 = Li.decide(dinp({ worth = false, worth_why = "retour 99 min" }))
check(why72:find("retour 99") ~= nil, "7.3 la raison du prix est ecrite")
check(Li.decide(dinp({ open = true })) == "attendre", "7.4 liaison deja en cours : attendre")
check(Li.decide(dinp({ seen = Li.CONFIRM - 1 })) == "attendre", "7.5 pas confirme : attendre")
check(Li.decide(dinp({ tries = Li.MAX_TRIES })) == "laisser", "7.6 essais epuises : laisser")
check(Li.decide(dinp({ tries = Li.MAX_TRIES, since_try = Li.RETRY_AFTER - 1 })) == "laisser", "7.7 dernier essai recent : laisser")
check(Li.decide(dinp({ tries = Li.MAX_TRIES, since_try = Li.RETRY_AFTER })) == "relier", "7.8 essais epuises depuis Li.RETRY_AFTER : un de plus")
check(Li.decide(dinp({ enemies = 1 })) == "attendre", "7.9 ennemi : attendre")
check(Li.decide(dinp({ open_total = 1, free = 0 })) == "attendre", "7.10 une liaison ouverte, aucun PNJ libre : attendre")
check(Li.decide(dinp({ open_total = 0, free = 0 })) == "relier", "7.10b aucun PNJ libre mais rien d'ouvert : une liaison reste permise")
check(Li.decide(dinp({ open_total = 3, free = 5 })) == "relier", "7.10c 5 PNJ libres : une 4e liaison, pas de borne écrite (AUDIT_PLAFONDS n° 22)")
check(Li.decide(dinp({ open_total = 5, free = 5 })) == "attendre", "7.10d autant de liaisons ouvertes que de PNJ libres : attendre")
check(Li.max_open(0) == 1 and Li.max_open(nil) == 1 and Li.max_open(1) == 1 and Li.max_open(12) == 12, "7.10e Li.max_open : au moins 1, sinon les PNJ libres")
check(Li.decide(dinp({ threat = true })) == "attendre", "7.11 QG menace : attendre")
check(Li.decide(dinp({ worth = false, open = true })) == "attendre", "7.12 en cours avant le prix")

-- §8 barre
check(Li.bar(400, 100) == 5, "8.1 400 objets de pile 100 : 4 cases, barre 5")
check(Li.bar(400, 50) == 9, "8.2 pile 50 : 8 cases, barre 9")
check(Li.bar(400, 1000) == 2, "8.3 pile enorme : une case, barre 2")
check(Li.bar(401, 100) == 6, "8.4 arrondi au-dessus")
check(Li.bar(400, 1) == 401, "8.5 pile de 1 : 400 cases")

-- §9 déterminisme : l'ordre des listes ne change rien
local function shuffle(list)
  local out = {}
  for i = #list, 1, -1 do out[#out + 1] = list[i] end
  return out
end
local big_d, big_s = {}, {}
for i = 1, 12 do
  big_d[#big_d + 1] = dock("d" .. string.format("%02d", i), i, (i * 7) % 40, (i * 3) % 25, i % 2 == 0 and "X" or "Y", (i % 3) + 1)
  big_s[#big_s + 1] = src("s" .. string.format("%02d", i), 100 + i, (i * 5) % 40, (i * 11) % 25, i % 2 == 0 and "X" or "Y")
end
local p1 = Li.pairs(big_d, big_s)
local p2 = Li.pairs(shuffle(big_d), shuffle(big_s))
local same = #p1 == #p2
for i = 1, math.min(#p1, #p2) do if p1[i].dock.key ~= p2[i].dock.key or p1[i].src.key ~= p2[i].src.key then same = false end end
check(same and #p1 > 0, "9.1 appariement identique quel que soit l'ordre des listes (" .. #p1 .. " paires)")
local e1 = Li.pick_ends({ x = 0, y = 0 }, { x = 12, y = 12 }, open_grid())
local e2 = Li.pick_ends({ x = 0, y = 0 }, { x = 12, y = 12 }, open_grid())
local same_e = #e1 == #e2
for i = 1, math.min(#e1, #e2) do if e1[i].src.dir ~= e2[i].src.dir or e1[i].dst.dir ~= e2[i].dst.dir then same_e = false end end
check(same_e, "9.2 bouts identiques d'un appel a l'autre")

-- §10 aucun nom d'objet, aucun pairs dans la règle
local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check(not code:find("iron%-") and not code:find("copper%-") and not code:find("transport%-belt") and not code:find("[a-z]%-inserter")
  and not code:find("electric%-pole") and not code:find("assembling") and not code:find("wooden"),
  "10.1 aucun nom d'objet dans shared/team/liaison.lua")
check(not code:find("[^i%.]pairs%("), "10.2 aucun pairs dans la regle (Li.pairs est la fonction d'appariement)")
check(not code:find("math%.random") and not code:find("os%.time") and not code:find("os%.clock") and not code:find("math%.sin") and not code:find("math%.cos"),
  "10.3 ni hasard, ni horloge, ni trigonometrie")
check(not code:find("game%.") and not code:find("global"), "10.4 aucune API du jeu")

-- §11 branchement (lu comme texte)
local BUILD = read("script/team/build.lua")
local SCRIPT = read("script/team/liaison.lua")
check(BUILD:find('if spec%.liaison then return Liaison%.plan%(') ~= nil, "11.1 plan_project renvoie au plan de la liaison")
check(BUILD:find("Liaison%.step%(") ~= nil, "11.2 pulse_team appelle Liaison.step")
check(BUILD:find('local Liaison = require%("script%.team%.liaison"%)') ~= nil, "11.3 require au chargement (jamais en evenement)")
check(not SCRIPT:find("global"), "11.4 global jamais nomme dans script/team/liaison.lua")
check(SCRIPT:find("%[FO%-LIAISON%]") ~= nil, "11.5 journal [FO-LIAISON]")
check(SCRIPT:find("p%.counted = true") ~= nil, "11.6 une liaison n'est pas comptee comme module")
check(SCRIPT:find("set_bar") ~= nil, "11.7 la barre du coffre d'entree est posee")
check(SCRIPT:find("aucune place pour un poteau contre un bras %(contre", 1) ~= nil, "11.7b refus de poteau : le bout fautif est nomme")
local i_plan = SCRIPT:find("function Liaison%.plan", 1)
local i_loop, i_pole = SCRIPT:find("for ie = first_end, #ends do", i_plan), SCRIPT:find("Tv%.pole_tile", i_plan)
local i_end = SCRIPT:find("if not chosen then return false", i_plan)
check(i_plan and i_loop and i_pole and i_end and i_loop < i_pole and i_pole < i_end, "11.7c les poteaux se cherchent DANS la boucle des bouts (un bout sans place : le suivant)")
local n_pairs = 0
local code_s = SCRIPT:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
for _ in code_s:gmatch("[^i%.]pairs%(") do n_pairs = n_pairs + 1 end
check(n_pairs == 1, "11.8 pairs seulement dans sorted_keys (liste triee ensuite) : " .. n_pairs)
local state_block = SCRIPT:match("local function new_state%(.-\nend")
check(state_block ~= nil and not state_block:find("function%s*%("), "11.9 l'etat b.liaison ne garde aucune fonction")
check(BUILD:find('Liaison%.plan%(') ~= nil and BUILD:find("read_masks = function%(x0, y0, x1, y1%) return read_masks%(f, surface, x0, y0, x1, y1%) end") ~= nil, "11.10 les aides du plan passent par la table donnee a Liaison.plan")
check(read("script/team/build.lua"):find("p%.inflow") ~= nil, "11.11 le debit des quais du module est garde au plan (p.inflow)")

-- §12 mutants
local function mutant(name, from, to, probe)
  local src = SRC:gsub(from, to, 1)
  if src == SRC then check(false, "mutant " .. name .. " : motif introuvable") return end
  local okl, Lm = pcall(load_l, src)
  if not okl then check(true, "mutant " .. name .. " (ne se charge pas)") return end
  local okp, seen = pcall(probe, Lm)
  check(not okp or seen, "mutant " .. name .. " vu")
end
-- (sonde qui rend vrai quand la regle est JUSTE : le mutant est vu quand elle ne l'est plus)
local function mutant_ok(name, from, to, probe)
  mutant(name, from, to, function(Lm) return not probe(Lm) end)
end
mutant_ok("debit minimum oublie", "if flow < Li%.MIN_FLOW then", "if false then",
  function(Lm) return Lm.worth(winp({ flow = Li.MIN_FLOW / 2, tmax = 1e9 })) == false end)
mutant_ok("retour sans plafond", "if payback > tmax then", "if false then",
  function(Lm) return Lm.worth(winp({ flow = 0.1 })) == false end)
mutant("menace sans effet", "if inp%.threat then tmax = tmax / Li%.THREAT_DIV end", "",
  function(Lm) local _, _, d = Lm.worth(winp({ threat = true })); return d.tmax ~= Li.TMAX / Li.THREAT_DIV end)
mutant_ok("allers-retours sans marche", "local trip_s = 2 %* %(inp%.dist or 56%) / Li%.WALK %+ Li%.HANDLE_S", "local trip_s = Li.HANDLE_S",
  function(Lm) local _, _, a = Lm.worth(winp({ dist = 20 })); local _, _, b = Lm.worth(winp({ dist = 120 })); return a.payback_min ~= b.payback_min end)
mutant("charge portee = pile entiere", "local per_trip = math%.max%(1, %(inp%.fill or 400%) %- %(inp%.low or 60%)%)", "local per_trip = 400",
  function(Lm) local _, _, a = Lm.worth(winp({ fill = 200, low = 100 })); local _, _, b = Li.worth(winp({ fill = 200, low = 100 })); return a.payback_min ~= b.payback_min end)
mutant("pose non comptee", "local pay_s = cost / labor %+ build_s", "local pay_s = cost / labor",
  function(Lm) local _, _, a = Lm.worth(winp()); local _, _, b = Li.worth(winp()); return a.payback_min ~= b.payback_min end)
mutant("cout des bras oublie", "2 %* price%.arm %+ 2 %* price%.pole", "0",
  function(Lm) local _, _, a = Lm.worth(winp()); local _, _, b = Li.worth(winp()); return a.cost ~= b.cost end)
mutant_ok("site sans tuile de tapis", "if free%(ax, ay%) and free%(bx, by%) then", "if free(ax, ay) then",
  function(Lm) return #Lm.sites(10, 10, open_grid({ ["10:8"] = true })) == 3 end)
mutant_ok("bras sur bras admis", "local clash = %(s%.ax == d%.ax and s%.ay == d%.ay%) or ", "local clash = false and ",
  function(Lm)
    for _, e in ipairs(Lm.pick_ends({ x = 0, y = 0 }, { x = 2, y = 0 }, open_grid())) do
      if e.src.ax == e.dst.ax and e.src.ay == e.dst.ay then return false end
    end
    return true
  end)
mutant("bouts non tries", "if a%.span ~= b%.span then return a%.span < b%.span end", "if false then return true end",
  function(Lm) local e = Lm.pick_ends(S, D, open_grid()); return e[1].span ~= 16 end)
mutant_ok("detour sans limite", "if len > lim then", "if false then",
  function(Lm) return Lm.route_ok(40, 10) == false end)
mutant_ok("longueur sans limite", "if len > Li%.MAX_LEN then", "if false then",
  function(Lm) return Lm.route_ok(Li.MAX_LEN + 1, Li.MAX_LEN) == false end)
mutant("bras de depart non retourne", "dir = opposite%(s%.dir%), role", "dir = s.dir, role",
  function(Lm)
    local ents = Lm.entities({ src = { dir = 2, ax = 1, ay = 0, bx = 2, by = 0 }, dst = { dir = 6, ax = 5, ay = 0, bx = 4, by = 0 },
      route = { { x = 2, y = 0, dir = 2 }, { x = 3, y = 0, dir = 2 }, { x = 4, y = 0, dir = 2 } }, names = names, poles = {} })
    return #Lm.verify(ents, { x = 0, y = 0 }, { x = 6, y = 0 }, isbelt, isarm) > 0
  end)
mutant("bras d'arrivee non oriente", "x = d%.ax %+ 0%.5, y = d%.ay %+ 0%.5, dir = d%.dir, role", "x = d.ax + 0.5, y = d.ay + 0.5, dir = opposite(d.dir), role",
  function(Lm)
    local ents = Lm.entities({ src = { dir = 2, ax = 1, ay = 0, bx = 2, by = 0 }, dst = { dir = 2, ax = 5, ay = 0, bx = 4, by = 0 },
      route = { { x = 2, y = 0, dir = 2 }, { x = 3, y = 0, dir = 2 }, { x = 4, y = 0, dir = 6 } }, names = names, poles = {} })
    return #Lm.verify(ents, { x = 0, y = 0 }, { x = 6, y = 0 }, isbelt, isarm) > 0
  end)
mutant_ok("fin de tapis non tournee", "return opposite%(site%.dir%)", "return site.dir",
  function(Lm) return Lm.end_dir(sites[1]) == 4 end)
mutant_ok("meme projet admis", "and s%.pid ~= d%.pid then", "then",
  function(Lm) return #Lm.pairs({ dock("d", 1, 0, 0, "X", 1) }, { src("s", 1, 5, 0, "X") }) == 0 end)
mutant_ok("objet non compare", "for _, s in ipairs%(by_item%[d%.item%] or {}%) do", "for _, s in ipairs(ss) do",
  function(Lm) return #Lm.pairs({ dock("d", 1, 0, 0, "X", 1) }, { src("s", 2, 5, 0, "Z") }) == 0 end)
mutant_ok("portee d'appariement oubliee", "if span <= Li%.MAX_SPAN and", "if",
  function(Lm) return #Lm.pairs({ dock("d", 1, 0, 0, "X", 1) }, { src("s", 2, 500, 0, "X") }) == 0 end)
mutant_ok("source prise deux fois", "used%[best%.key%] = true", "",
  function(Lm) return #Lm.pairs({ dock("a", 1, 0, 0, "X", 1), dock("b", 2, 0, 10, "X", 1) }, { src("s", 3, 5, 5, "X") }) == 1 end)
mutant_ok("quai relie reutilise", "if not d%.linked and d%.item", "if d.item",
  function(Lm) return #Lm.pairs({ dock("d", 1, 0, 0, "X", 1, true) }, { src("s", 2, 5, 0, "X") }) == 0 end)
mutant_ok("plus proche non retenue", "if span <= Li%.MAX_SPAN and %(not bspan or span < bspan%) then", "if span <= Li.MAX_SPAN and (not bspan) then",
  function(Lm) return Lm.pairs({ dock("d", 1, 0, 0, "X", 1) }, { src("s1", 2, 30, 0, "X"), src("s2", 3, 5, 0, "X") })[1].src.key == "s2" end)
mutant_ok("gros debit non prioritaire", "if %(a%.flow or 0%) ~= %(b%.flow or 0%) then return %(a%.flow or 0%) > %(b%.flow or 0%) end", "",
  function(Lm) return Lm.pairs({ dock("a", 1, 0, 0, "X", 1), dock("b", 2, 0, 10, "X", 5) }, { src("s", 3, 5, 5, "X") })[1].dock.key == "b" end)
mutant("sans confirmation", "if %(inp%.seen or 0%) < Li%.CONFIRM", "if false",
  function(Lm) return Lm.decide(dinp({ seen = 0 })) == "relier" end)
mutant("essais sans plafond", "if %(inp%.tries or 0%) >= Li%.MAX_TRIES", "if false",
  function(Lm) return Lm.decide(dinp({ tries = 99 })) == "relier" end)
mutant("ennemi ignore", "if %(inp%.enemies or 0%) > 0", "if false",
  function(Lm) return Lm.decide(dinp({ enemies = 1 })) == "relier" end)
mutant("menace du QG ignoree", "if inp%.threat then return", "if false then return",
  function(Lm) return Lm.decide(dinp({ threat = true })) == "relier" end)
mutant("plafond de liaisons ouvertes", "if %(inp%.open_total or 0%) >= Li%.max_open%(inp%.free%)", "if false",
  function(Lm) return Lm.decide(dinp({ open_total = 9 })) == "relier" end)
mutant("prix ignore", "if not inp%.worth then", "if false then",
  function(Lm) return Lm.decide(dinp({ worth = false })) == "relier" end)
mutant("liaison en cours ignoree", "if inp%.open then return", "if false then return",
  function(Lm) return Lm.decide(dinp({ open = true })) == "relier" end)
mutant_ok("barre sans le un", "return slots %+ 1", "return slots",
  function(Lm) return Lm.bar(400, 100) == 5 end)
mutant_ok("barre sans arrondi", "math%.ceil%(%(fill or 400%) / math%.max%(1, stack or 1%)%)", "math.floor((fill or 400) / math.max(1, stack or 1))",
  function(Lm) return Lm.bar(401, 100) == 6 end)
mutant("poteau sur le cote d'abord ignore", "{ site%.ax %+ px, site%.ay %+ py }, { site%.ax %- px, site%.ay %- py },", "",
  function(Lm) local x, y = Lm.pole_tile(sites[1], open_grid()); return x ~= 9 or y ~= 9 end)
mutant_ok("poteau sur tuile prise", "and not %(taken and taken%[c%[1%] %.%. \":\" %.%. c%[2%]%]%) then", "then",
  function(Lm) return Lm.pole_tile(sites[1], open_grid(), { ["9:9"] = true }) == 11 end)

-- §13 lot IA-RUPTURE (partie du DC en 0.6.96, amber, module 8 à 78,2 min) : le compte d'essais est celui de la PAIRE (quai > sortie), pas du
-- quai. Le script (script/team/liaison.lua) est joué hors jeu sur un relevé injecté. Deux essais vers la sortie A (refusés : « aucun chemin »)
-- ne verrouillent plus la sortie B, plus proche et apparue ensuite : le quai 8:q1 était porté à la main 17 min à 16 tuiles de sa sortie 64:o1,
-- reliée ensuite par 9 tapis.
local SSRC = read("script/team/liaison.lua")
local LOG13 = {}
log = function(s) LOG13[#LOG13 + 1] = s end
settings = { global = {} } -- bus éteint
game = { tick = 0, item_prototypes = {} }
defines = defines or { inventory = { chest = 1 } }
remote = { add_interface = function() end }
local function skeys(t) local ks = {} for k in pairs(t) do ks[#ks + 1] = k end table.sort(ks) return ks end
package.loaded["script.faction.state"] = { sorted_keys = skeys, faction = function() return nil end, alive = function() return {} end }
package.loaded["script.team.convoyeurs"] = { choose = function() return "transport-belt" end, is_belt = function(n) return n == "transport-belt" end,
  belts = function() return {} end }
package.loaded["script.ai3.reserve"] = { on = function() return true end }
package.loaded["script.companion.registry"] = { get = function() return nil end }
local function load_s(src)
  local fn, err = load(src, "=script_liaison", "t")
  assert(fn, err)
  return fn()
end
local SURF13 = { find_nearest_enemy = function() return nil end, count_entities_filtered = function() return 0 end }
--- Un monde : le quai 8:q1 (débit 1,49/s), la sortie A (57:o1) à 20 tuiles, puis la sortie B (64:o1) à 16 tuiles (coordonnées de la partie).
local function world13(Lx)
  local mod = { id = 8, state = "fini", spec = { gen = "x", names = { arm = "inserter", pole = "small-electric-pole" } }, parts = { { kind = "module" } },
    quais = {}, outs = {}, ents = {} }
  local b = { projects = { [8] = mod, [57] = { id = 57, state = "fini", spec = { gen = "y" }, parts = {}, quais = {}, outs = {}, ents = {} },
    [64] = { id = 64, state = "fini", spec = { gen = "y" }, parts = {}, quais = {}, outs = {}, ents = {} } }, order = { 8, 57, 64 }, next_id = 70 }
  local f = { key = "amber", force = "amber", build = b, hq_pos = { x = -317, y = -336 }, engineers = {} }
  local reqs = {}
  local api = { prio = 56, fill = 400, low = 60, request = function(_, spec)
    local id = b.next_id
    b.next_id = id + 1
    b.projects[id] = { id = id, spec = spec, state = "attente", parts = {}, ents = {}, quais = {}, outs = {} }
    b.order[#b.order + 1] = id
    reqs[#reqs + 1] = { id = id, spec = spec }
    return id
  end }
  local tick = 0
  Lx.step(api, f, SURF13, tick) -- crée b.liaison
  local function releve(srcs)
    tick = tick + Li.PERIOD
    game.tick = tick
    local n0 = #reqs
    b.liaison.cyc = { units = {}, i = 1, docks = { { key = "8:q1", pid = 8, idx = 1, x = -317, y = -405, item = "iron-plate", flow = 1.49, n = 10 } },
      srcs = srcs }
    Lx.step(api, f, SURF13, tick)
    local out = {}
    for i = n0 + 1, #reqs do out[#out + 1] = reqs[i] end
    return out
  end
  local A = { key = "57:o1", pid = 57, idx = 1, x = -325, y = -393, item = "iron-plate", n = 300 }
  local B = { key = "64:o1", pid = 64, idx = 1, x = -325, y = -397, item = "iron-plate", n = 300 }
  local function refuse(r) b.projects[r.id].state = "refuse"; b.projects[r.id].reason = "liaison: aucun chemin" end
  return { releve = releve, A = A, B = B, refuse = refuse, st = function() return b.liaison end }
end
--- Le scénario du DC : A essayée deux fois (refusée), puis B confirmée. Rend les demandes vues après la confirmation de B.
local function scenario13(Lx)
  local w = world13(Lx)
  w.releve({ w.A })                       -- vue 1 : à confirmer
  local r1 = w.releve({ w.A })            -- vue 2 : essai 1
  if r1[1] then w.refuse(r1[1]) end
  local r2 = w.releve({ w.A })            -- refus suivi, essai 2
  if r2[1] then w.refuse(r2[1]) end
  w.releve({ w.A })                       -- refus suivi : essais épuisés pour A
  w.releve({ w.A, w.B })                  -- B, plus proche : à confirmer
  local rb = w.releve({ w.A, w.B })       -- B confirmée
  return rb, w, r1, r2
end
local Lx = load_s(SSRC)
local rb, w13, r1, r2 = scenario13(Lx)
check(r1[1] and r2[1] and r1[1].spec.liaison.src.key == "57:o1" and r2[1].spec.liaison.src.key == "57:o1", "13.1 (témoin) deux essais vers la sortie A (57:o1)")
check(#rb == 1 and rb[1].spec.liaison.src.key == "64:o1", "13.2 la sortie B (64:o1), confirmée, est demandée malgré les deux refus de A (avant : laisser, 17 min à la main)")
local said133 = false
for _, l in ipairs(LOG13) do if l:find("quai 8:q1", 1, true) and l:find("64:o1", 1, true) and l:find("essai 1/" .. Li.MAX_TRIES, 1, true) then said133 = true end end
check(said133, "13.3 le journal [FO-LIAISON] compte l'essai 1 de la paire 8:q1 > 64:o1")
-- la paire A reste bornée : épuisée, elle ne repart qu'après Li.RETRY_AFTER
do
  local w = world13(Lx)
  w.releve({ w.A })
  local a1 = w.releve({ w.A }); if a1[1] then w.refuse(a1[1]) end
  local a2 = w.releve({ w.A }); if a2[1] then w.refuse(a2[1]) end
  local a3 = w.releve({ w.A })
  check(#a3 == 0, "13.4 la même paire refusée deux fois : laissée (plafond d'essais tenu)")
  local said = false
  for _, l in ipairs(LOG13) do if l:find("57:o1 a 20 tuiles : laisser : 2 liaison", 1, true) then said = true end end
  check(said, "13.5 le journal dit les essais épuisés de la paire 8:q1 > 57:o1")
  local later
  for _ = 1, math.ceil(Li.RETRY_AFTER / Li.PERIOD) + 1 do
    later = w.releve({ w.A })
    if #later > 0 then break end
  end
  check(later and #later == 1 and later[1].spec.liaison.src.key == "57:o1", "13.6 après Li.RETRY_AFTER : un essai de plus pour la même paire")
end
-- l'état ne garde que des nombres sous des clés de paire
do
  local st = w13.st()
  check(st.tries["8:q1>57:o1"] == 2 and st.tries["8:q1>64:o1"] == 1 and st.tries["8:q1"] == nil, "13.7 essais comptés par paire (8:q1>57:o1 = 2, 8:q1>64:o1 = 1)")
  check(type(st.last_try["8:q1>64:o1"]) == "number" and st.last_try["8:q1"] == nil, "13.8 dernier essai daté par paire")
end
-- déterminisme : deux parties identiques, mêmes demandes
do
  local rb2 = scenario13(load_s(SSRC))
  check(#rb2 == #rb and rb2[1] ~= nil and rb[1] ~= nil and rb2[1].spec.liaison.src.key == rb[1].spec.liaison.src.key, "13.9 deux parties identiques : mêmes demandes")
end
-- mutants du script : chaque retour au compte par quai est vu
local function smutant(name, from, to)
  local src, n = SSRC:gsub(from, to)
  if n == 0 then check(false, "mutant " .. name .. " : motif introuvable") return end
  local okl, Lm = pcall(load_s, src)
  if not okl then check(true, "mutant " .. name .. " (ne se charge pas)") return end
  local okp, rbm = pcall(scenario13, Lm)
  check(not okp or not (#rbm == 1 and rbm[1].spec.liaison.src.key == "64:o1"), "mutant " .. name .. " vu")
end
smutant("essais lus par quai", "tries = st%.tries%[pk%] or 0", "tries = st.tries[d.key] or 0")
smutant("dernier essai lu par quai", "local last = st%.last_try%[pk%]", "local last = st.last_try[d.key]")
smutant("essais écrits par quai", "st%.tries%[pk%] = %(st%.tries%[pk%] or 0%) %+ 1", "st.tries[d.key] = (st.tries[d.key] or 0) + 1")
smutant("dernier essai écrit par quai", "st%.last_try%[pk%] = tick", "st.last_try[d.key] = tick")
smutant("clé de paire = quai", "local pk = d%.key %.%. \">\" %.%. s%.key(%s+local ok, why, det)", "local pk = d.key%1")
smutant("clé de paire = sortie", "local pk = d%.key %.%. \">\" %.%. s%.key(%s+local ok, why, det)", "local pk = s.key%1")
-- le plafond d'essais retiré n'est pas une coupe valable : 13.4 le voit
do
  local src, n = SSRC:gsub("tries = st%.tries%[pk%] or 0", "tries = 0")
  local okl, Lm = pcall(load_s, src)
  local seen = false
  if n > 0 and okl then
    local w = world13(Lm)
    w.releve({ w.A })
    local a1 = w.releve({ w.A }); if a1[1] then w.refuse(a1[1]) end
    local a2 = w.releve({ w.A }); if a2[1] then w.refuse(a2[1]) end
    seen = #w.releve({ w.A }) > 0
  end
  check(n > 0 and seen, "mutant plafond d'essais retiré vu (la paire refusée repartirait sans fin)")
end

print(string.format("[LIAISON] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
