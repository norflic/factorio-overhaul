--[[
  Lot DESIGN-ATTAQUES (5/11) : banc hors jeu des règles pures de la 2e attaque des géants (shared/robots/attaques2.lua). Lua 5.2, depuis la
  racine du mod :   lua5.2 tests/attaques2_test.lua
    §1 angles sans trigonométrie (pseudo-angle et son inverse) ;  §2 Surtension (parcours en largeur, parents, déterminisme) ;
    §3 orage ;  §4 Balafre (canyon de 2 lignes de falaises sur la grille, bouts, sans trouée ni chevauchement ; vol du Stylet) ;
    §5 passage du nez ; §5 bis réseau de proximité (sans poteaux) et débris ;  §6 Cyclone (huit qui part du centre, y repasse, y finit ; passage) ;  §7 Éruption (bords, anneaux de fonte
    qui partitionnent le lac, feux) ;  §8 Zénith (spirale du bord au centre, passage EXACT, tuiles de verre près du tracé) ;
    §9 plan d'une salve (tri, unicité, parts) ;  §10 forme des fichiers ;  §11 mutants (chaque règle a un mutant, tous refusés).
]]

package.path = "./?.lua;" .. package.path

local B = require("shared.robots.bourdon")

local function read(p)
  local f = assert(io.open(p, "rb"), "lecture impossible : " .. p)
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/robots/attaques2.lua")

local function charge_module(src)
  local fn = assert(load(src, "=attaques2", "t", setmetatable({ require = require }, { __index = _G })))
  return fn()
end

--- Les contrôles des règles ; rend (ok, échecs, journal) sans rien écrire (les mutants les rejouent).
local function controles(A, bavard)
  local ok, ko = 0, 0
  local function check(cond, nom, det)
    if cond then ok = ok + 1 else ko = ko + 1 end
    if bavard and not cond then print("ECHEC " .. nom .. (det and (" : " .. det) or "")) end
  end

  -- §1 angles
  local prev, mono, inv = -1, true, 0
  for k = 0, 255 do
    local c, s = B.dir(k / 256)
    local pa = A.pseudo_angle(c, s)
    if pa < prev - 1e-12 then mono = false end
    prev = pa
    local x, y = A.direction(pa)
    local e = math.abs(x - c) + math.abs(y - s)
    if e > inv then inv = e end
  end
  check(mono, "§1 pseudo-angle croissant sur 256 directions")
  check(inv < 1e-6, "§1 direction(pseudo_angle(v)) = v", string.format("ecart %.2e", inv))
  check(A.pseudo_angle(0, 0) == 0, "§1 (0, 0) rend 0")

  -- §2 Surtension : grille 9 × 9 de poteaux (voisins à 4), départ au centre
  local N = 9
  local function idg(i, j) return i * 100 + j end
  local function voisins_g(id)
    local i, j = math.floor(id / 100), id % 100
    local l = {}
    if j < N - 1 then l[#l + 1] = idg(i, j + 1) end
    if i > 0 then l[#l + 1] = idg(i - 1, j) end
    if j > 0 then l[#l + 1] = idg(i, j - 1) end
    if i < N - 1 then l[#l + 1] = idg(i + 1, j) end
    return l
  end
  local niv, par = A.surtension(idg(4, 4), voisins_g, 1000)
  local vus, total, couches = {}, 0, true
  for k, l in ipairs(niv) do
    for _, id in ipairs(l) do
      total = total + 1
      if vus[id] then couches = false end
      vus[id] = k
      local d = math.abs(math.floor(id / 100) - 4) + math.abs(id % 100 - 4)
      if d ~= k - 1 then couches = false end
      if k > 1 then
        local p = par[id]
        local adj = false
        for _, v in ipairs(voisins_g(p or -1)) do if v == id then adj = true end end
        if not (p and vus[p] == k - 1 and adj) then couches = false end
      end
    end
  end
  check(total == N * N and couches, "§2 parcours en largeur : chaque poteau une fois, au niveau de sa distance, parent adjacent au niveau d'avant",
    total .. " poteaux")
  local niv2 = A.surtension(idg(4, 4), voisins_g, 13)
  local n2 = 0
  for _, l in ipairs(niv2) do n2 = n2 + #l end
  check(n2 == 13, "§2 au plus `max` poteaux", tostring(n2))
  local function voisins_m(id) local l = voisins_g(id); local r = {}; for i = #l, 1, -1 do r[#r + 1] = l[i] end; return r end
  local niv3 = A.surtension(idg(4, 4), voisins_m, 30)
  local same = #niv3 == #niv2 or true
  local a1, a3 = {}, {}
  for _, l in ipairs(A.surtension(idg(4, 4), voisins_g, 30)) do for _, id in ipairs(l) do a1[#a1 + 1] = id end end
  for _, l in ipairs(niv3) do for _, id in ipairs(l) do a3[#a3 + 1] = id end end
  for i = 1, math.max(#a1, #a3) do if a1[i] ~= a3[i] then same = false end end
  check(same, "§2 déterministe : l'ordre des voisins rendu par le moteur ne change rien")
  local seul = A.surtension(7, function() return {} end, 10)
  check(#seul == 1 and seul[1][1] == 7, "§2 poteau isolé : lui seul")

  -- §3 orage
  local f1, f2 = A.foudres(17, 24, 4242), A.foudres(17, 24, 4242)
  local dans, egal = true, true
  for i = 1, 24 do
    if not (f1[i] and f1[i] >= 1 and f1[i] <= 17) then dans = false end
    if f1[i] ~= f2[i] then egal = false end
  end
  check(#f1 == 24 and dans and egal, "§3 orage : 24 éclairs dans 1..17, déterministes")
  check(#A.foudres(0, 24, 1) == 0, "§3 orage sans cible : rien")

  -- §4 Balafre (Stylet) : deux lignes nord-sud de falaises, faces opposées, continues, sans chevauchement
  local cst = A.ATTAQUES.stylet
  local c = { x = 13.3, y = -7.8 }
  local R = 30
  local traits = A.balafre(c, R, cst.ecart)
  local departs = { 0, 0 }
  local grille = #traits == 2
  for _, tr in ipairs(traits) do
    if tr.axe ~= "v" or tr.x % 4 ~= 0 or (tr.de - 0.5) % 4 ~= 0 or (tr.a - 0.5) % 4 ~= 0 or tr.de > tr.a then grille = false end
  end
  check(grille and traits[2].x - traits[1].x == cst.ecart and traits[1].sens == 1 and traits[2].sens == -1,
    "§4 balafre : 2 lignes nord-sud sur la grille des falaises (4, décalage 0,5), écart " .. cst.ecart .. ", faces opposées")
  check(math.abs((traits[1].x + traits[2].x) / 2 - c.x) <= 2 and traits[1].de <= c.y - R + 2 and traits[1].a >= c.y + R - 2,
    "§4 elle passe par la cible et couvre la zone du nord au sud")
  local toutes, bouts, pas4, monot, nb = {}, true, true, true, {}
  for i2, tr in ipairs(traits) do
    local fl = A.falaises(tr, {}, 0, cst.vitesse)
    nb[i2] = #fl
    local lastt = -1
    for k, f in ipairs(fl) do
      toutes[#toutes + 1] = { f = f, axe = tr.axe }
      if f.t < lastt then monot = false end
      lastt = f.t
      if k > 1 and math.abs(f.y - fl[k - 1].y) ~= 4 then pas4 = false end
      local attendu
      if tr.sens == 1 then
        attendu = (k == 1 and "none-to-south") or (k == #fl and "north-to-none") or "north-to-south"
      else
        attendu = (k == 1 and "south-to-none") or (k == #fl and "none-to-north") or "south-to-north"
      end
      if f.o ~= attendu then bouts = false end
    end
  end
  check(nb[1] >= 15 and nb[1] == nb[2], "§4 deux lignes continues, autant de falaises chacune", nb[1] .. " et " .. nb[2])
  check(bouts, "§4 bouts et milieux : north-to-south à gauche (none-to-south, north-to-none), south-to-north à droite")
  check(pas4, "§4 aucune trouée : une falaise tous les 4 tuiles")
  check(monot, "§4 falaises dans l'ordre de passage du nez (du nord au sud)")
  local chev = 0
  local function bb(t)
    local hx, hy = (t.axe == "h") and 2 or 1, (t.axe == "h") and 1.5 or 2
    return t.f.x - hx, t.f.y - hy, t.f.x + hx, t.f.y + hy
  end
  for i2 = 1, #toutes do
    for k = i2 + 1, #toutes do
      local a0, b0, a1, b1 = bb(toutes[i2])
      local c0, d0, c1, d1 = bb(toutes[k])
      if a0 < c1 - 1e-9 and a1 > c0 + 1e-9 and b0 < d1 - 1e-9 and b1 > d0 + 1e-9 then chev = chev + 1 end
    end
  end
  check(chev == 0, "§4 aucune falaise n'en chevauche une autre", tostring(chev))
  -- le vol du Stylet : départ à sa place, au bord nord à la frappe, puis vers le sud à la vitesse du labour
  local dep = { x = c.x - 40, y = c.y + 5 }
  local vx0, vy0 = A.vol_stylet(dep, traits, -cst.charge, cst.charge, cst.vitesse)
  local vx1, vy1 = A.vol_stylet(dep, traits, 0, cst.charge, cst.vitesse)
  local vx2, vy2 = A.vol_stylet(dep, traits, 40, cst.charge, cst.vitesse)
  local vx3, vy3 = A.vol_stylet(dep, traits, 100000, cst.charge, cst.vitesse)
  check(math.abs(vx0 - dep.x) < 1e-9 and math.abs(vy0 - dep.y) < 1e-9 and math.abs(vy1 - traits[1].de) < 1e-9
    and math.abs(vy2 - (traits[1].de + 40 * cst.vitesse)) < 1e-9 and math.abs(vy3 - traits[1].a) < 1e-9 and math.abs(vx2 - vx1) < 1e-9,
    "§4 vol du Stylet : de sa place au bord nord pendant la charge, puis labour vers le sud, arrêt au bord sud")

  -- §5 passage du nez
  local tr1 = traits[1]
  local p_on = { x = tr1.x, y = tr1.de + 9 }
  local t5, d5 = A.passage_gravure(p_on, traits, departs, cst.vitesse, cst.brule)
  check(d5 == 0 and t5 == math.floor(9 / cst.vitesse), "§5 point sur la ligne : distance 0, tick d'arrivée du nez", tostring(t5) .. " " .. tostring(d5))
  check(A.passage_gravure({ x = c.x + 500, y = c.y }, traits, departs, cst.vitesse, cst.brule) == nil, "§5 point loin : aucun passage")

  -- §5 bis Surtension sans réseau : de proche en proche (nids)
  local nids = {}
  for k = 0, 9 do nids[#nids + 1] = { x = k * 10, y = 0, id = 500 + k } end
  nids[#nids + 1] = { x = 300, y = 300, id = 999 }
  local nv = A.reseau_proche(nids, 1, 12, 60)
  local nn, isole = 0, false
  for _, l in ipairs(nv) do for _, i2 in ipairs(l) do nn = nn + 1; if i2 == #nids then isole = true end end end
  check(#nv == 10 and nn == 10 and not isole, "§5 bis sans réseau : l'arc saute de nid en nid à moins de 12 tuiles, pas au-delà", #nv .. " niveaux, " .. nn)
  -- débris de la Trombe : environ la part demandée, déterministes
  local nd, same = 0, true
  for id = 1, 2000 do
    local k = A.debris(id, 4242, 0.35)
    if k then nd = nd + 1; if k < 1 or k > #A.ROCHERS then same = false end end
    if k ~= A.debris(id, 4242, 0.35) then same = false end
  end
  check(same and nd > 600 and nd < 800, "§5 bis débris : 35 % des cibles arrachées laissent un rocher (déterministe)", tostring(nd))

  -- §6 Cyclone
  local ctr = A.ATTAQUES.trombe
  local w, o = 27, 0.3125
  local x0, y0 = A.cyclone(c, w, o, 0, ctr.duree)
  local xm, ym = A.cyclone(c, w, o, ctr.duree / 2, ctr.duree)
  local x1, y1 = A.cyclone(c, w, o, ctr.duree, ctr.duree)
  local dmax = 0
  for t = 0, ctr.duree, 5 do
    local x, y = A.cyclone(c, w, o, t, ctr.duree)
    local d = math.sqrt((x - c.x) ^ 2 + (y - c.y) ^ 2)
    if d > dmax then dmax = d end
  end
  local function pres(x, y) return math.abs(x - c.x) + math.abs(y - c.y) < 1e-6 end
  check(pres(x0, y0) and pres(xm, ym) and pres(x1, y1), "§6 le huit part du centre, y repasse à mi-course et y finit")
  check(dmax <= w * 1.01 and dmax >= w * 0.95, "§6 il va jusqu'à sa demi-largeur", string.format("%.2f pour %d", dmax, w))
  local xq, yq = A.cyclone(c, w, o, 140, ctr.duree)
  local tq, dq = A.passage_cyclone({ x = xq, y = yq }, c, w, o, ctr.duree, ctr.pas, ctr.souffle)
  check(tq == 140 and dq < 1e-9, "§6 passage : un point du tracé est touché au tick où le tourbillon y passe", tostring(tq))
  local bx = A.boite_cyclone(c, w, o, ctr.duree, 4, 2)
  check(bx[1][1] <= c.x - w * 0.6 and bx[2][1] >= c.x + w * 0.6, "§6 boîte de la recherche autour de la course")

  -- §7 Éruption
  local cix = A.ATTAQUES.ixion
  local rl = 20
  local bords = A.bords_lave(rl, cix.secteurs, 777)
  local bok = true
  for _, b in ipairs(bords) do if b < 0.8 * rl - 1e-9 or b > rl + 1e-9 then bok = false end end
  check(#bords == cix.secteurs and bok, "§7 bord du lac entre 0,8 et 1 fois le rayon, un rayon par secteur")
  local tout = A.tuiles_lave(c, bords, -1, 1)
  local vu, dbl, n = {}, 0, 0
  for k = 1, cix.anneaux do
    local f0 = (k == 1) and -1 or (k - 1) / cix.anneaux
    for _, q in ipairs(A.tuiles_lave(c, bords, f0, k / cix.anneaux)) do
      local key = q.x .. ":" .. q.y
      if vu[key] then dbl = dbl + 1 end
      vu[key] = true
      n = n + 1
    end
  end
  check(n == #tout and dbl == 0, "§7 les anneaux de fonte partitionnent le lac (aucune tuile deux fois, aucune oubliée)",
    string.format("%d anneaux, %d tuiles, lac %d, doublons %d", cix.anneaux, n, #tout, dbl))
  check(#tout > math.floor(3.14159 * (0.8 * rl) ^ 2) and #tout < math.ceil(3.1416 * (rl + 1) ^ 2), "§7 aire du lac entre π(0,8 r)² et π(r + 1)²",
    tostring(#tout))
  local fx = A.feux(c, rl, 60, 80, 777)
  local fok = #fx == 80
  for _, p in ipairs(fx) do
    local d = math.sqrt((p.x - c.x) ^ 2 + (p.y - c.y) ^ 2)
    if d < rl - 1e-6 or d > 60 + 1e-6 then fok = false end
  end
  check(fok, "§7 80 brasiers entre le lac et le bord de la zone")
  check(A.t_fonte(1, rl, cix.fonte) == math.floor(rl / cix.fonte), "§7 le front de fonte atteint le bord à rl / fonte ticks")

  -- §8 Zénith
  local czn = A.ATTAQUES.tournesol
  local RZ = 75
  local U = RZ / czn.pas
  local um, dec = U + 1, true
  for t = 0, czn.duree do
    local u = A.u_zenith(t, czn.duree, U)
    if u > um + 1e-12 then dec = false end
    um = u
  end
  check(math.abs(A.u_zenith(0, czn.duree, U) - U) < 1e-12 and A.u_zenith(czn.duree, czn.duree, U) == 0 and dec,
    "§8 la spirale va du bord (u = R / pas) au centre (u = 0), sans revenir")
  local xr, yr = A.point_zenith(c, czn.pas, U)
  check(math.abs(math.sqrt((xr - c.x) ^ 2 + (yr - c.y) ^ 2) - RZ) < 1e-6, "§8 elle part au rayon R")
  local exact, tmax_err = true, 0
  for t = 3, czn.duree - 3, 37 do
    local u = A.u_zenith(t, czn.duree, U)
    local x, y = A.point_zenith(c, czn.pas, u)
    local tt, d = A.passage_zenith({ x = x, y = y }, c, czn.pas, U, czn.duree)
    if d > 1e-6 then exact = false end
    if math.abs(tt - t) > tmax_err then tmax_err = math.abs(tt - t) end
  end
  check(exact and tmax_err <= 1, "§8 passage EXACT : un point du tracé est touché au tick où le foyer y passe (± 1 tick)",
    string.format("ecart max %d tick(s)", tmax_err))
  local etat, brute = { v = 99 }, true
  for _ = 1, 200 do
    local ux, uy = B.dir(B.alea(etat))
    local rr = czn.pas + (RZ - czn.pas * 1.5) * B.alea(etat)
    local px, py = c.x + ux * rr, c.y + uy * rr
    local _, d = A.passage_zenith({ x = px, y = py }, c, czn.pas, U, czn.duree)
    if d > czn.pas / 2 + 1e-6 then brute = false end
  end
  check(brute, "§8 tout point entre un tour et le bord est à au plus pas / 2 d'un bras (la spirale couvre la zone ; le cœur prend l'éclat final)")
  local tz = A.tuiles_zenith(c, czn.pas, U, U - 0.05, czn.pinceau)
  local loin = 0
  for _, q in ipairs(tz) do
    local best = 1e9
    for i = 0, 40 do
      local x, y = A.point_zenith(c, czn.pas, U - 0.05 * i / 40)
      local d = math.sqrt((q.x + 0.5 - x) ^ 2 + (q.y + 0.5 - y) ^ 2)
      if d < best then best = d end
    end
    if best > czn.pinceau + 0.6 then loin = loin + 1 end
  end
  check(#tz > 5 and loin == 0, "§8 tuiles de verre le long du tracé, aucune loin du pinceau", string.format("%d tuiles, %d loin", #tz, loin))

  -- §9 plan d'une salve
  local cands = {}
  local e2 = { v = 31337 }
  for i = 1, 400 do
    cands[i] = { x = c.x + (B.alea(e2) - 0.5) * 140, y = c.y + (B.alea(e2) - 0.5) * 140, id = 1000 + i * 3 }
  end
  local plans = {
    stylet = { traits = traits, departs = departs, c = c, R = R },
    trombe = { c = c, w = w, o = o, R = 45 },
    ixion = { c = c, R = 60, bords = bords, rl = rl },
    tournesol = { c = c, R = RZ, U = U },
  }
  local pok = true
  local resume = {}
  for _, id in ipairs({ "stylet", "trombe", "ixion", "tournesol" }) do
    local pl = A.plan(id, plans[id], cands)
    local vu2, last = {}, nil
    local tues = 0
    for _, it in ipairs(pl) do
      if vu2[it.i] then pok = false end
      vu2[it.i] = true
      if last and (it.t < last.t or (it.t == last.t and it.id < last.id)) then pok = false end
      if it.f < 0 or it.f > 1 then pok = false end
      if it.tue then tues = tues + 1 end
      last = it
    end
    resume[#resume + 1] = string.format("%s %d/%d (tues %d)", id, #pl, #cands, tues)
    if id ~= "ixion" and tues > 0 then pok = false end
    if #pl == 0 then pok = false end
  end
  check(pok, "§9 plans triés par (tick, numéro), une entrée par cible au plus, part dans [0, 1], mort d'office seulement dans la lave", table.concat(resume, ", "))
  check(math.abs(A.chute(100, 0, 0.3) - 100) < 1e-9 and math.abs(A.chute(100, 1, 0.3) - 30) < 1e-9 and A.chute(100, 1.01, 0.3) == 0,
    "§9 chute : plein au centre, bord au bord, 0 au-delà")
  check(A.zone(10) == 15 and A.zone(14) == 75, "§9 zone 15 × (âge − 9)")

  -- grille de proximité
  local g = A.grille(cands, 8)
  local gok = true
  for t = 1, 20 do
    local px, py = cands[t].x + 3, cands[t].y - 2
    local l = A.voisinage(g, px, py, 10, 8)
    local set = {}
    for _, i in ipairs(l) do set[i] = true end
    for i, cc in ipairs(cands) do
      if (cc.x - px) ^ 2 + (cc.y - py) ^ 2 <= 100 and not set[i] then gok = false end
    end
  end
  check(gok, "§9 grille : tout candidat dans le disque est rendu par le voisinage")

  return ok, ko
end

local total_ok, total_ko = 0, 0
local function bilan(ok, ko) total_ok, total_ko = total_ok + ok, total_ko + ko end

local A = charge_module(SRC)
local ok, ko = controles(A, true)
bilan(ok, ko)
print(string.format("[ATT2] regles : %d OK, %d ECHEC(S)", ok, ko))

-- §10 forme des fichiers
local function forme(chemin, pur)
  local s = read(chemin)
  local f_ok = true
  local det = {}
  local code = s:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  if code:find("[^%w_]pairs%(") then f_ok = false; det[#det + 1] = "pairs" end
  for _, m in ipairs({ "math%.sin", "math%.cos", "math%.tan", "math%.atan", "math%.random" }) do
    if code:find(m) then f_ok = false; det[#det + 1] = m end
  end
  if code:find("[^%w_%.]global[^%w_]") then f_ok = false; det[#det + 1] = "global" end
  for line in code:gmatch("[^\n]+") do
    if line:find("require%(") and line:find("^%s") then f_ok = false; det[#det + 1] = "require dans une fonction" end
  end
  if pur and (code:find("game%.") or code:find("rendering%.") or code:find("defines%.")) then f_ok = false; det[#det + 1] = "API du jeu" end
  return f_ok, table.concat(det, ", ")
end
local fichiers = { { "shared/robots/attaques2.lua", true }, { "script/robots/attaques2.lua", false }, { "script/robots/attaques2_effets.lua", false } }
for _, f in ipairs(fichiers) do
  local fo, det = forme(f[1], f[2])
  bilan(fo and 1 or 0, fo and 0 or 1)
  print(string.format("[ATT2] forme %s : %s%s", f[1], fo and "OK" or "ECHEC", det ~= "" and (" (" .. det .. ")") or ""))
end

-- §11 mutants
local MUTANTS = {
  { "pseudo-angle", "return 1 - dx / (-dx + dy)", "return 1 + dx / (-dx + dy)" },
  { "parcours sans marque", "          vu[v] = true\n", "\n" },
  { "bout de la ligne remontante", '(k == j and "none-to-north")', '(k == j and "north-to-none")' },
  { "canyon sans écart", "return { { axe = \"v\", x = x0, de = y0, a = y1, sens = 1 }, { axe = \"v\", x = x0 + ecart,", "return { { axe = \"v\", x = x0, de = y0, a = y1, sens = 1 }, { axe = \"v\", x = x0," },
  { "vol sans labour", "return xm, math.min(y1, y0 + t * vitesse)", "return xm, y0" },
  { "huit qui ne part pas du centre", "local s = 0.25 + t / duree", "local s = t / duree" },
  { "spirale à vitesse non constante", "return U * math.sqrt(1 - t / T)", "return U * (1 - t / T)" },
  { "bras mal arrondi", "local k = math.floor(rr / pas - a + 0.5)", "local k = math.floor(rr / pas - a)" },
  { "anneaux qui se recouvrent", "if f > f0 and f <= f1 then", "if f >= f0 - 0.01 and f <= f1 then" },
  { "chute inversée", "return coup * (1 - (1 - bord) * f)", "return coup * (1 - (1 + bord) * f)" },
  { "voisinage trop court", "local x0, x1 = math.floor((x - r) / cell), math.floor((x + r) / cell)", "local x0, x1 = math.floor(x / cell), math.floor(x / cell)" },
  { "pinceau oublié", "if ex * ex + ey * ey <= pinceau * pinceau then", "if ex * ex + ey * ey <= 4 * pinceau * pinceau then" },
  { "zone fausse", "return 15 * (math.floor(age) - 9)", "return 15 * (math.floor(age) - 10)" },
  { "proximité sans borne", "if k ~= i and (o.x - c.x) * (o.x - c.x) + (o.y - c.y) * (o.y - c.y) <= r * r then", "if k ~= i then" },
  { "débris toujours", "if u >= part then return nil end", "if u >= 1 then return nil end" },
  { "Trombe qui tue d'office", "if tt then t, f, tue = tt, math.max(0, d - a.rayon) / (a.souffle - a.rayon), false end", "if tt then t, f, tue = tt, 0, d <= a.rayon end" },
}
local refuses = 0
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  local tue
  if not a then
    print("[ATT2] mutant " .. m[1] .. " : texte introuvable (banc à corriger)")
    tue = false
  else
    local src = SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1)
    local okm, Am = pcall(charge_module, src)
    if not okm then tue = true
    else
      local ok2, okv, kov = pcall(controles, Am, false)
      tue = (not ok2) or (kov or 0) > 0
    end
  end
  if tue then refuses = refuses + 1 end
  print(string.format("[ATT2] mutant %-32s %s", m[1], tue and "refuse" or "SURVIT"))
end
bilan(refuses == #MUTANTS and 1 or 0, refuses == #MUTANTS and 0 or 1)
print(string.format("[ATT2] mutants : %d / %d refuses", refuses, #MUTANTS))
print(string.format("[ATT2] BILAN : %d OK, %d ECHEC(S)", total_ok, total_ko))
os.exit(total_ko == 0 and 0 or 1)
