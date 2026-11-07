--[[
  Lot DESIGN-ATTAQUES (5/11) : banc hors jeu des règles pures de la 2e attaque des géants (shared/robots/attaques2.lua). Lua 5.2, depuis la
  racine du mod :   lua5.2 tests/attaques2_test.lua
    §1 angles sans trigonométrie (pseudo-angle et son inverse) ;  §2 Surtension (parcours en largeur, parents, déterminisme) ;
    §3 orage ;  §4 Balayage du Stylet (une salve par cible de la bande, au premier pas) ;  §5 bis réseau de proximité (sans poteaux) et débris ;  §6 Cyclone (huit qui part du centre, y repasse, y finit ; passage) ;  §7 Éruption (bords, anneaux de fonte
    qui partitionnent le lac, feux) ;  §8 Zénith (spirale du bord au centre, passage EXACT, tuiles de verre près du tracé) ;
    §9 plan d'une salve (tri, unicité, parts) ;  §10 forme des fichiers ;  §11 mutants (chaque règle a un mutant, tous refusés) ;
    §12 bandes de la recherche ;  §13 séquelles d'1 h (QCM-7/11 : registre, sol d'origine rendu, jamais sur un sol changé depuis).
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

  -- §4 Balayage (Stylet, idée du DC ; la Balafre et ses falaises sont abandonnées, QCM-7/11) : chaque cible de la bande prend la salve
  -- UNE fois, au tick du premier pas qui la touche ; rien hors de la bande ; plan trié
  local c = { x = 13.3, y = -7.8 }
  local R = 30
  local Ech = A.Ech
  local o4 = { x = c.x - 40, y = c.y + 4 }
  local bal = Ech.balayage(11, 45)
  local ray = Ech.rayons(o4, c, bal.longueur)
  local c4, e4 = {}, { v = 4242 }
  for i = 1, 300 do c4[i] = { x = o4.x + B.alea(e4) * 60, y = o4.y + (B.alea(e4) - 0.5) * 60, id = 2000 + i } end
  local pl4 = A.plan_balayage(o4, ray, c4, bal.demi, bal.ticks, bal.pas)
  local vu4, ok4, last4 = {}, true, nil
  for _, it in ipairs(pl4) do
    if vu4[it.i] then ok4 = false end
    vu4[it.i] = true
    local premier
    for k, e in ipairs(ray) do if Ech.dans_bande(c4[it.i], o4, e, bal.demi) then premier = k; break end end
    if not premier or it.t ~= math.floor((premier - 1) * bal.ticks / bal.pas) then ok4 = false end
    if last4 and (it.t < last4.t or (it.t == last4.t and it.id < last4.id)) then ok4 = false end
    last4 = it
  end
  local hors4 = 0
  for i, cc in ipairs(c4) do
    local dedans = false
    for _, e in ipairs(ray) do if Ech.dans_bande(cc, o4, e, bal.demi) then dedans = true end end
    if dedans ~= (vu4[i] == true) then hors4 = hors4 + 1 end
  end
  check(ok4 and hors4 == 0 and #pl4 > 10, "§4 balayage : une salve par cible de la bande, au premier pas qui la touche, aucune hors de la bande",
    string.format("%d touchées sur %d, %d écart(s)", #pl4, #c4, hors4))

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
    trombe = { c = c, w = w, o = o, R = 45 },
    ixion = { c = c, R = 60, bords = bords, rl = rl },
    tournesol = { c = c, R = RZ, U = U },
  }
  local pok = true
  local resume = {}
  for _, id in ipairs({ "trombe", "ixion", "tournesol" }) do
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

  -- §12 bandes de la recherche (budget par tick, 7/11) : elles couvrent la boîte, et chaque position de la boîte (bords compris, positions
  -- en 1/256 : F92) revient à UNE bande et une seule ; rien hors de la boîte
  local bx0, by0, bx1, by1 = -84.5, -61.25, 84.5, 70.75
  local bl = A.bandes(bx0, by0, bx1, by1, 32)
  local couvre = (#bl >= 1) and bl[1].y0 == by0 and bl[#bl].y1 == by1 and bl[#bl].der
  for k = 2, #bl do if bl[k].y0 ~= bl[k - 1].y1 or bl[k].y1 - bl[k].y0 > 32 then couvre = false end end
  check(couvre, "§12 bandes : la boîte entière, sans trou, 32 tuiles au plus", tostring(#bl))
  local une, hors = true, true
  local ys = {}
  for yy = by0 * 256 - 512, by1 * 256 + 512, 37 do ys[#ys + 1] = yy / 256 end
  for _, b in ipairs(bl) do ys[#ys + 1] = b.y0; ys[#ys + 1] = b.y1; ys[#ys + 1] = b.y1 - 1 / 256 end -- les bords des bandes
  for _, y in ipairs(ys) do
    for _, xx in ipairs({ bx0 - 1, bx0, 0, bx1, bx1 + 0.5 }) do
      local n = 0
      for _, b in ipairs(bl) do if A.dans_bande(b, xx, y) then n = n + 1 end end
      local dedans = xx >= bx0 and xx <= bx1 and y >= by0 and y <= by1
      if dedans and n ~= 1 then une = false end
      if not dedans and n ~= 0 then hors = false end
    end
  end
  check(une, "§12 chaque position de la boîte revient à une seule bande (bords compris)")
  check(hors, "§12 rien hors de la boîte")
  local b1 = A.bandes(0, 0, 10, 10, 32)
  check(#b1 == 1 and b1[1].der, "§12 une petite zone : une seule bande")

  -- §13 séquelles (QCM-7/11) : « Cratère et verre, pas de falaises » ; « durer 1 heure, se résorber »
  check(A.TRACE == 216000, "§13 une trace dure 1 h (216 000 ticks)", tostring(A.TRACE))
  check(A.ATTAQUES.stylet.ecart == nil and A.balafre == nil and A.falaises == nil, "§13 plus aucune falaise (Balafre abandonnée)")
  local Rg = A.Ech.trace_nouveau()
  local t0 = 1000
  A.Ech.trace_marquer(Rg, 5, 6, "grass-1", t0 + A.TRACE)         -- lave posée sur de l'herbe
  A.Ech.trace_marquer(Rg, 7, 6, "dry-dirt", t0 + A.TRACE)        -- verre chaud sur de la terre
  A.Ech.trace_marquer(Rg, 9, 6, "nuclear-ground", t0 + A.TRACE)  -- lave sur un cratère d'experimentaux
  A.Ech.trace_marquer(Rg, 11, 6, "sand-1", t0 + A.TRACE)         -- un joueur l'a pavée depuis
  A.Ech.trace_marquer(Rg, 5, 6, A.PREFIX .. "lave", t0 + 50 + A.TRACE) -- une 2e attaque sur la même tuile : l'origine reste l'herbe
  local avant = A.Ech.trace_echues(Rg, t0 + A.TRACE - 1, 100)
  local echues = A.Ech.trace_echues(Rg, t0 + A.TRACE + 60, 100)
  local actuel = { [5] = "nuclear-ground", [7] = A.PREFIX .. "verre", [9] = "nuclear-ground", [11] = "refined-concrete" }
  local rendu = {}
  for _, e in ipairs(echues) do rendu[e.x] = A.sol_a_rendre(e, actuel[e.x]) or false end
  check(#avant == 0, "§13 rien n'est rendu avant l'heure")
  check(rendu[5] == "grass-1" and rendu[7] == "dry-dirt", "§13 à l'heure, le cratère et le verre rendent leur sol d'ORIGINE (2e attaque comprise)",
    tostring(rendu[5]) .. ", " .. tostring(rendu[7]))
  check(rendu[9] == false, "§13 un cratère d'experimentaux dessous : rien (son propre registre le rendra)")
  check(rendu[11] == false, "§13 une tuile pavée depuis par un joueur n'est jamais écrasée")
  check(A.sol_a_rendre({ orig = "grass-1" }, A.PREFIX .. "lave") == nil and A.sol_a_rendre({ orig = "grass-1" }, A.PREFIX .. "verre-chaud") == nil,
    "§13 une tuile encore chaude (lave, verre chaud) n'est pas rendue")
  check(A.encore_chaud(A.PREFIX .. "lave") and A.encore_chaud(A.PREFIX .. "verre-chaud") and not A.encore_chaud("nuclear-ground")
    and not A.encore_chaud(A.PREFIX .. "verre") and A.REPRISE > 0, "§13 une tuile échue encore chaude reprend une attente (rien n'est perdu)")

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
  { "bande qui garde son bord sud", "return y < b.y1 or b.der", "return true" },
  { "trace d'une minute", "A.TRACE = Ech.TRACE_TICKS", "A.TRACE = 3600" },
  { "sol rendu même pavé", "if A.SOLS_TRACE[nom] and e.orig ~= nom then return e.orig end", "if e.orig ~= nom then return e.orig end" },
  { "lave chaude oubliée", 'A.CHAUDS = { [A.PREFIX .. "lave"] = true, [A.PREFIX .. "verre-chaud"] = true }', 'A.CHAUDS = { [A.PREFIX .. "verre-chaud"] = true }' },
  { "cratère jamais rendu", 'A.SOLS_TRACE = { ["nuclear-ground"] = true, [A.PREFIX .. "verre"] = true }', 'A.SOLS_TRACE = { [A.PREFIX .. "verre"] = true }' },
  { "dernière bande sans bord sud", "out[#out + 1] = { x0 = x0, y0 = y, x1 = x1, y1 = yb, der = (yb >= y1) }", "out[#out + 1] = { x0 = x0, y0 = y, x1 = x1, y1 = yb, der = false }" },
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
