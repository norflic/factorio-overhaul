--[[
  Tests hors jeu du lot TRAVERSEE (shared/team/traversee.lua, Lua pur).
  Usage, depuis la racine du mod :   lua5.2 tests/traversee_test.lua

  Cartes SYNTHÉTIQUES en texte : '.' libre, 'o' gisement (libre), '#' obstacle (interdit à une pièce, franchissable par dessous),
  'P' poteau, 'B' tapis existant, 'V' / 'H' pièce souterraine existante (axe vertical / horizontal), 'S' départ, 'T' arrivée.
  La batterie est appliquée au module réel (0 échec attendu), puis à chaque MUTANT du module (au moins 1 échec attendu).
]]

package.path = "./?.lua;" .. package.path

local P = require("shared.team.plan")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

-- Carte -> { cost, ore, ug_axis, nature, s, t, bounds }
local function parse(rows)
  local m = { cells = {}, w = #rows[1], h = #rows }
  for y = 1, #rows do
    for x = 1, #rows[y] do
      local c = rows[y]:sub(x, x)
      m.cells[(x - 1) .. ":" .. (y - 1)] = c
      if c == "S" then m.s = { x = x - 1, y = y - 1 } end
      if c == "T" then m.t = { x = x - 1, y = y - 1 } end
    end
  end
  local function at(x, y) return m.cells[x .. ":" .. y] end
  m.bounds = { x0 = 0, y0 = 0, x1 = m.w - 1, y1 = m.h - 1 }
  m.cost = function(x, y)
    local c = at(x, y)
    if c == nil or c == "#" or c == "P" or c == "B" or c == "V" or c == "H" then return nil end
    return 1
  end
  m.ore = function(x, y) return at(x, y) == "o" end
  m.ug_axis = function(x, y)
    local c = at(x, y)
    if c == "V" then return 1 elseif c == "H" then return 2 end
    return nil
  end
  m.nature = function(x, y)
    local c = at(x, y)
    if c == "#" then return "obstacle" elseif c == "P" then return "poteau" elseif c == "B" then return "tapis"
    elseif c == "V" or c == "H" then return "souterrain" end
    return nil
  end
  return m
end

local function cols(n, ch) return string.rep(ch, n) end

-- Couloir de 3 lignes, mur de `th` colonnes `wall` à la colonne 6, départ à gauche, arrivée à droite.
local function corridor(th, wall)
  local mid = "S" .. cols(5, ".") .. cols(th, wall) .. cols(5, ".") .. "T"
  local top = cols(1, ".") .. cols(5, ".") .. cols(th, wall) .. cols(5, ".") .. "."
  return parse({ top, mid, top })
end

---------------------------------------------------------------------------------------------------
-- Batterie
---------------------------------------------------------------------------------------------------
local function battery(Tv)
  local fails, errs = 0, {}
  local function ck(c, why) if not c then fails = fails + 1; errs[#errs + 1] = why or "?" end end
  local function route(m, ctx)
    ctx = ctx or {}
    ctx.ore = ctx.ore or nil
    ctx.ug_axis = ctx.ug_axis or m.ug_axis
    ctx.nature = ctx.nature or m.nature
    return Tv.route(m.s, m.t, ctx.t_dir or 2, m.bounds, m.cost, ctx)
  end
  local function ok_verify(m, tiles, maxd, td) return #Tv.verify(tiles, m.s, m.t, td or 2, maxd, m.cost, { ug_axis = m.ug_axis }) == 0 end

  local ok, err = pcall(function()
    -- (a) terrain libre : tracé droit, aucune paire, même longueur que P.belt_route
    do
      local rows = {}
      for y = 1, 7 do rows[y] = (y == 4) and ("S" .. cols(18, ".") .. "T") or cols(20, ".") end
      local m = parse(rows)
      local tiles, info = route(m, { maxd = 5 })
      ck(tiles and #tiles == 20 and info.jumps == 0, "a1 : tracé droit sans paire")
      ck(tiles and ok_verify(m, tiles, 5), "a2 : preuve")
      local ref = P.belt_route(m.s, m.t, 2, m.bounds, m.cost)
      ck(ref and tiles and #ref == #tiles, "a3 : même longueur que P.belt_route")
    end
    -- (b) mur d'une colonne dans un couloir fermé : une paire (k = 2), nature du franchi
    do
      local m = corridor(1, "#")
      local tiles, info = route(m, { maxd = 5 })
      ck(tiles and info.jumps == 1 and info.jump_list[1].k == 2, "b1 : une paire de portée 2")
      ck(tiles and ok_verify(m, tiles, 5), "b2 : preuve")
      ck(info and info.jump_list[1].what[1] and info.jump_list[1].what[1][1] == "obstacle", "b3 : nature de l'obstacle franchi")
      local none, why = route(m, { maxd = nil })
      ck(none == nil and why == "aucun chemin", "b4 : sans souterrain débloqué, aucun chemin")
      local none2 = route(m, { maxd = 1 })
      ck(none2 == nil, "b5 : portée 1 : aucune paire")
    end
    -- (c) portée : mur de 4 passe avec maxd 5 (k = 5), mur de 5 ne passe pas, passe avec 6
    do
      local m4 = corridor(4, "#")
      local t4, i4 = route(m4, { maxd = 5 })
      ck(t4 and i4.jump_list[1].k == 5 and ok_verify(m4, t4, 5), "c1 : mur de 4 avec la portée 5")
      local m5 = corridor(5, "#")
      ck(route(m5, { maxd = 5 }) == nil, "c2 : mur de 5 avec la portée 5 : aucun chemin")
      local t5 = route(m5, { maxd = 6 })
      ck(t5 and ok_verify(m5, t5, 6), "c3 : mur de 5 avec la portée 6")
      local m10 = corridor(10, "#")
      local t10 = route(m10, { maxd = 5 })
      ck(t10 == nil, "c4 : mur de 10 : aucun chemin (pas de chaîne sur du vide)")
    end
    -- (d) poteau et tapis existant franchis
    do
      local mp = corridor(1, "P")
      local tp, ip = route(mp, { maxd = 5 })
      ck(tp and ip.jump_list[1].what[1][1] == "poteau", "d1 : poteau franchi")
      local mb = corridor(1, "B")
      local tb, ib = route(mb, { maxd = 5 })
      ck(tb and ib.jump_list[1].what[1][1] == "tapis" and ok_verify(mb, tb, 5), "d2 : tapis existant croisé par dessous")
    end
    -- (e) souterrain existant : même axe interdit, axe perpendiculaire permis
    do
      local mh = corridor(1, "H")
      ck(route(mh, { maxd = 5 }) == nil, "e1 : souterrain de même axe sous la paire : refusé")
      local mv = corridor(1, "V")
      local tv = route(mv, { maxd = 5 })
      ck(tv and ok_verify(mv, tv, 5), "e2 : souterrain d'axe perpendiculaire : permis")
    end
    -- (f) terrain libre : pas de paire pour un petit obstacle (le détour coûte moins), paire pour un mur sans fin
    do
      local rows = {}
      for y = 1, 9 do rows[y] = cols(20, ".") end
      rows[5] = "S" .. cols(8, ".") .. "#" .. cols(9, ".") .. "T"
      local m = parse(rows)
      local tiles, info = route(m, { maxd = 5 })
      ck(tiles and info.jumps == 0, "f1 : petit obstacle contourné, pas de paire")
      local long = {}
      for y = 1, 31 do long[y] = cols(10, ".") .. "#" .. cols(9, ".") end
      long[16] = "S" .. cols(8, ".") .. "." .. "#" .. cols(8, ".") .. "T"
      local ml = parse(long)
      local tl, il = route(ml, { maxd = 5 })
      ck(tl and il.jumps == 1, "f2 : mur de 31 lignes : une paire plutôt qu'un détour de 30")
    end
    -- (g) gisement : détour borné
    do
      local rows = {}
      for y = 1, 9 do rows[y] = cols(30, ".") end
      for y = 3, 7 do rows[y] = cols(10, ".") .. cols(5, "o") .. cols(15, ".") end
      rows[5] = "S" .. cols(9, ".") .. cols(5, "o") .. cols(14, ".") .. "T"
      local m = parse(rows)
      local tiles, info = route(m, { maxd = 5, ore = m.ore })
      ck(tiles and info.base_ore == 5, "g1 : le tracé de base couvre le gisement (5)")
      ck(tiles and info.ore == 0 and info.phys <= Tv.detour_limit(info.base_phys), "g2 : détour sous la borne : 0 tuile de gisement")
      ck(tiles and ok_verify(m, tiles, 5), "g3 : preuve")
    end
    -- (h) gisement qui ne se contourne pas : traversé par paires de portée maximale
    do
      local rows = {}
      for y = 1, 9 do rows[y] = cols(4, ".") .. cols(20, "o") .. cols(6, ".") end
      rows[5] = "S" .. cols(3, ".") .. cols(20, "o") .. cols(5, ".") .. "T"
      local m = parse(rows)
      local tiles, info = route(m, { maxd = 5, ore = m.ore })
      ck(tiles and info.base_ore == 20, "h1 : tracé de base : 20 tuiles de gisement")
      ck(tiles and info.ore <= 8 and info.jumps >= 3, "h2 : traversée par paires : au plus 8 tuiles couvertes (" .. tostring(info and info.ore) .. ")")
      ck(tiles and ok_verify(m, tiles, 5), "h3 : preuve")
      local t2, i2 = route(m, { maxd = nil, ore = m.ore })
      ck(t2 and i2.ore == 20 and i2.jumps == 0, "h4 : sans souterrain, il traverse quand même (20)")
      -- gisement sur toute la hauteur d'un grand champ : le détour dépasserait la borne, le tracé traverse
      local big = {}
      for y = 1, 61 do big[y] = cols(10, ".") .. ((y >= 7 and y <= 57) and cols(10, "o") or cols(10, ".")) .. cols(10, ".") end
      big[31] = "S" .. cols(9, ".") .. cols(10, "o") .. cols(9, ".") .. "T"
      local mb = parse(big)
      local tb, ib = route(mb, { maxd = 5, ore = mb.ore })
      ck(tb and ib.ore > 0 and ib.phys <= Tv.detour_limit(ib.base_phys), "h5 : détour trop long : traverse, longueur sous la borne")
      ck(tb and ib.ore < ib.base_ore, "h6 : mais couvre moins de gisement que le tracé de base")
      -- sans souterrain : le détour de 50 tuiles dépasse la borne, il traverse tout droit (10 tuiles) ; un détour borné est pris quand il existe
      local tn, inn = route(mb, { maxd = nil, ore = mb.ore })
      ck(tn and inn.ore == 10 and inn.phys <= Tv.detour_limit(inn.base_phys), "h7 : sans souterrain, détour trop long : traverse (10 tuiles), longueur sous la borne")
    end
    -- (i) déterminisme et forme du journal
    do
      local m = corridor(3, "#")
      local t1, i1 = route(m, { maxd = 5 })
      local t2 = route(m, { maxd = 5 })
      local same = t1 and t2 and #t1 == #t2
      for i = 1, (t1 and #t1 or 0) do
        if not (t2[i] and t1[i].x == t2[i].x and t1[i].y == t2[i].y and t1[i].dir == t2[i].dir and t1[i].ug == t2[i].ug) then same = false end
      end
      ck(same, "i1 : deux appels, même tracé")
      local lines = Tv.lines({ team = "azure", project = 81, kind = "liaison" }, i1)
      ck(#lines == 1 and lines[1]:find("[FO-TRAVERSEE] azure : projet 81 (liaison) : souterrain de (", 1, true) and lines[1]:find("3 obstacle", 1, true),
        "i2 : une ligne par paire, format")
      local ents = Tv.entities(t1, { belt = "B", ug = "U" }, "r")
      local nin, nout = 0, 0
      for _, e in ipairs(ents) do
        if e.type == "input" then nin = nin + 1 end
        if e.type == "output" then nout = nout + 1 end
      end
      ck(nin == 1 and nout == 1 and ents[1].name == "B", "i3 : entités : une entrée, une sortie, type écrit")
      local virt = Tv.virtual_belts(t1)
      ck(#virt == 1 + 5 + 3 + 5 + 1 + 0 and virt[1].x == m.s.x, "i4 : tracé virtuel continu (" .. #virt .. ")")
    end
    -- (j) preuve : tracés corrompus refusés
    do
      local m = corridor(3, "#")
      local tiles = route(m, { maxd = 5 })
      local function copy(l) local o = {} for i, e in ipairs(l) do o[i] = { x = e.x, y = e.y, dir = e.dir, ug = e.ug } end return o end
      local good = #Tv.verify(tiles, m.s, m.t, 2, 5, m.cost, { ug_axis = m.ug_axis }) == 0
      ck(good, "j0 : tracé juste accepté")
      local a = copy(tiles)
      for _, e in ipairs(a) do if e.ug == "output" then e.x = e.x + 3 end end
      ck(#Tv.verify(a, m.s, m.t, 2, 5, m.cost) > 0, "j1 : écart trop grand refusé")
      local a2 = copy(tiles)
      for _, e in ipairs(a2) do if e.ug == "output" then e.y = e.y + 1 end end
      ck(#Tv.verify(a2, m.s, m.t, 2, 5, m.cost) > 0, "j1b : sortie hors de l'axe de l'entrée refusée")
      local b = copy(tiles)
      for _, e in ipairs(b) do if e.ug == "output" then e.dir = 0 end end
      ck(#Tv.verify(b, m.s, m.t, 2, 5, m.cost) > 0, "j2 : sortie tournée refusée")
      local c = copy(tiles)
      c[#c].dir = 0
      ck(#Tv.verify(c, m.s, m.t, 2, 5, m.cost) > 0, "j3 : dernière tuile mal tournée refusée")
      local d = copy(tiles)
      for i, e in ipairs(d) do if e.ug == "input" then table.remove(d, i + 1) break end end
      ck(#Tv.verify(d, m.s, m.t, 2, 5, m.cost) > 0, "j4 : entrée sans sortie refusée")
      local e2 = copy(tiles)
      e2[#e2 + 1] = { x = m.t.x, y = m.t.y, dir = 2 }
      ck(#Tv.verify(e2, m.s, m.t, 2, 5, m.cost) > 0, "j5 : deux pièces sur la même tuile refusées")
      ck(#Tv.verify(tiles, m.s, m.t, 2, 3, m.cost) > 0, "j6 : portée plus petite que l'écart refusée")
    end
    -- (k) arrivée : jamais par l'avant de la cible
    do
      local rows = { "S.....T", ".......", "......." }
      local m = parse(rows)
      m.cells["7:0"] = nil -- tuile devant la cible hors carte (interdite)
      local tiles = route(m, { maxd = 5 })
      ck(tiles and tiles[#tiles].dir == 2, "k1 : dernière tuile tournée vers t_dir")
    end
    -- (k2) virage interdit juste après la sortie ; sortie jamais sur la cible ; jamais d'arrivée par l'avant
    do
      local m = parse({ cols(5, ".") .. "#" .. cols(5, "."), "S" .. cols(4, ".") .. "#" .. cols(2, ".") .. "." .. cols(2, "."), cols(5, ".") .. "#" .. cols(1, ".") .. "T" .. cols(3, ".") })
      local tiles = route(m, { maxd = 5, t_dir = 4 })
      ck(tiles and ok_verify(m, tiles, 5, 4), "k2 : pas de virage juste après la sortie")
      local m2 = parse({ cols(5, ".") .. "##" .. cols(2, "."), cols(2, ".") .. "S" .. cols(2, ".") .. "#T" .. cols(2, "."), cols(5, ".") .. "##" .. cols(2, ".") })
      m2.s = { x = 2, y = 1 }
      ck(route(m2, { maxd = 5, t_dir = 2 }) == nil, "k3 : jamais de sortie sur la cible")
      local m3 = parse({ cols(5, ".") .. "#" .. cols(2, "."), "S" .. cols(3, ".") .. "#T" .. cols(2, "."), cols(5, ".") .. "#" .. cols(2, ".") })
      -- cible dont l'arrière (4, 1) et les côtés sont interdits : seul l'avant (6, 1) est libre
      m3.cells["5:0"], m3.cells["5:2"] = "#", "#"
      ck(route(m3, { maxd = nil, t_dir = 2 }) == nil, "k4 : jamais d'arrivée par l'avant de la cible")
    end
    -- (c2) compression d'une traversée de gisement (Tv.compress) sur des listes fabriquées
    do
      local function line(x0, x1, y, turn_at)
        local l = {}
        for x = x0, x1 do l[#l + 1] = { x = x, y = y, d = 2 } end
        if turn_at then
          -- virage vers le sud à x = turn_at puis tout droit
          for i2, e in ipairs(l) do if e.x == turn_at then e.d = 3 end end
        end
        return l
      end
      local function as_tiles(el)
        local out = {}
        for _, e in ipairs(el) do out[#out + 1] = { x = e.x, y = e.y, dir = (e.d - 1) * 2, ug = e.ug } end
        return out
      end
      local function jumps_of(el) local n = 0 for _, e in ipairs(el) do if e.ug == "input" then n = n + 1 end end return n end
      local ore = function(x, y) return x >= 5 and x <= 16 end
      local el = line(0, 25, 3)
      local out = Tv.compress(el, { ore = ore, maxd = 5 })
      local t = as_tiles(out)
      ck(jumps_of(out) >= 2 and #Tv.verify(t, { x = 0, y = 3 }, { x = 25, y = 3 }, 2, 5, function() return 1 end) == 0, "c2a : traversée droite : paires dans la portée, preuve juste")
      local on = 0
      for _, e in ipairs(out) do if ore(e.x, e.y) then on = on + 1 end end
      ck(on <= 5, "c2b : au plus 5 pièces sur 12 tuiles de gisement (" .. on .. ")")
      -- virage juste après la sortie : l'écart ne peut pas finir sur la tuile qui précède le virage
      local el2 = line(0, 12, 3, 10)
      for i2 = #el2, 1, -1 do if el2[i2].x > 10 then table.remove(el2, i2) end end
      el2[#el2 + 1] = { x = 10, y = 4, d = 3 }
      local ore2 = function(x, y) return x >= 5 and x <= 9 and y == 3 end
      -- les pièces après le virage ne sont plus sur la droite : le tracé réel descend en x = 10
      local out2 = Tv.compress(el2, { ore = ore2, maxd = 5 })
      ck(#Tv.verify(as_tiles(out2), { x = 0, y = 3 }, { x = 10, y = 4 }, 4, 5, function() return 1 end) == 0, "c2c : pas de virage juste après la sortie")
      -- souterrain existant de même axe sous l'écart : aucune paire
      local out3 = Tv.compress(line(0, 25, 3), { ore = ore, maxd = 5, ug_axis = function(x, y) if x == 7 then return 2 end return nil end })
      ck(#Tv.verify(as_tiles(out3), { x = 0, y = 3 }, { x = 25, y = 3 }, 2, 5, function() return 1 end, { ug_axis = function(x) if x == 7 then return 2 end return nil end }) == 0,
        "c2d : jamais de paire au-dessus d'un souterrain de même axe")
    end
    -- (k5) cause d'un refus
    do
      local m = corridor(10, "#")
      local d = Tv.diagnose(m.s, m.t, m.bounds, m.cost, 5)
      ck(d.reached > 0 and d.near.x == 5 and d.dist == m.t.x - 5 and d.block and d.block.x == 6 and not d.outside, "k5 : cause du refus : le mur en x = 6")
      local line = Tv.refusal_line({ team = "azure", project = 7, kind = "liaison" }, "aucun chemin", d, "poteau")
      ck(line:find("REFUS (aucun chemin)", 1, true) and line:find("poteau en (6, 1)", 1, true), "k6 : ligne de refus")
      local d2 = Tv.diagnose(m.s, m.t, m.bounds, m.cost, nil)
      ck(d2.near.x == 5, "k7 : sans souterrain, même arrêt")
    end
    -- (p) PIRE CAS BORNÉ : un budget d'états partagé borne le coût d'un plan (mesuré : 23 M d'instructions sans budget sur une boîte de 120)
    do
      local W, H = 120, 120
      local seed = 99
      local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end
      local trees = {}
      for x = 0, W - 1 do for y = 0, H - 1 do if rnd(100) < 30 then trees[x * 1000 + y] = true end end end
      local function pcost(x, y)
        if x < 0 or y < 0 or x >= W or y >= H or x == 60 then return nil end
        return trees[x * 1000 + y] and 2 or 1
      end
      local bounds = { x0 = 0, y0 = 0, x1 = W - 1, y1 = H - 1 }
      local function instr(fn)
        local n = 0
        debug.sethook(function() n = n + 1 end, "", 1000)
        local a, b = fn()
        debug.sethook()
        return n * 1000, a, b
      end
      local bud = { left = 1500 }
      local n1, t1, w1 = instr(function() return Tv.route({ x = 1, y = 60 }, { x = W - 2, y = 60 }, 2, bounds, pcost, { maxd = nil, sd = 2, budget = bud }) end)
      ck(t1 == nil and w1 == "trop long", "p1 : mur sans issue, budget de 1500 : trop long (" .. tostring(w1) .. ")")
      ck(bud.left <= 0 and bud.left >= -1, "p2 : le budget est consommé jusqu'au bout (" .. bud.left .. ")")
      ck(n1 <= 3000000, "p3 : coût borné par le budget : au plus 3 M d'instructions (" .. n1 .. ")")
      -- budget partagé : un second appel, budget épuisé, sort au premier état
      local n2, t2, w2 = instr(function() return Tv.route({ x = 1, y = 10 }, { x = 10, y = 10 }, 2, bounds, pcost, { maxd = 5, sd = 2, budget = bud }) end)
      ck(t2 == nil and w2 == "trop long" and n2 <= 20000, "p4 : budget épuisé : le deuxième appel sort tout de suite (" .. n2 .. " instr)")
      -- avec les paires : le même mur se franchit s'il reste du budget
      local bud3 = { left = 20000 }
      local t3 = Tv.route({ x = 1, y = 60 }, { x = W - 2, y = 60 }, 2, bounds, function(x, y) if x == 60 and y >= 0 then return nil end return pcost(x, y) end, { maxd = 5, sd = 2, budget = bud3 })
      ck(t3 ~= nil, "p5 : avec souterrains et assez de budget, le mur de 1 tuile est franchi")
    end
    -- (p2) gisement PARTOUT (mesure d'un tiers : 5,4 M d'instructions sur une boîte de 52 avec 5 recherches) : au plus 2 recherches, coût borné
    do
      local W = 120
      local pb = { x0 = 0, y0 = 0, x1 = W - 1, y1 = W - 1 }
      local function ocost(x, y) if x < 0 or y < 0 or x >= W or y >= W then return nil end return 1 end
      local function instr2(fn)
        local n = 0
        debug.sethook(function() n = n + 1 end, "", 1000)
        local a, b = fn()
        debug.sethook()
        return n * 1000, a, b
      end
      local n, t, info = instr2(function() return Tv.route({ x = 1, y = 60 }, { x = W - 2, y = 60 }, 2, pb, ocost,
        { maxd = 5, ore = function() return true end, sd = 2, weight = Tv.GAME_WEIGHT, budget = { left = Tv.PLAN_BUDGET } }) end)
      ck(t ~= nil and info.searches <= 2, "p6 : gisement partout : au plus 2 recherches (" .. tostring(info and info.searches) .. ")")
      ck(n <= 3000000, "p7 : gisement partout, boîte de 120 : au plus 3 M d'instructions (" .. n .. ")")
      local n2, t2, i2 = instr2(function() return Tv.route({ x = 1, y = 60 }, { x = W - 2, y = 60 }, 2, pb, ocost,
        { maxd = 5, ore = function() return true end, sd = 2, weight = Tv.GAME_WEIGHT, budget = { left = 300 } }) end)
      ck(t2 ~= nil or i2 == "trop long", "p8 : budget de 300 : un tracé ou « trop long », jamais d'erreur")
    end
    -- (l) plafond : un plafond minuscule rend « trop long » sans planter
    do
      local m = corridor(1, "#")
      local none, why = route(m, { maxd = 5, max = 3 })
      ck(none == nil and why == "trop long", "l1 : plafond")
    end
    -- (m) équivalence avec P.belt_route sur 150 cartes pseudo-aléatoires sans gisement ni souterrain
    do
      local seed = 12345
      local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end
      local diff, both = 0, 0
      for _ = 1, 150 do
        local rows = {}
        for y = 1, 12 do
          local r = {}
          for x = 1, 20 do r[x] = (rnd(100) < 24) and "#" or "." end
          rows[y] = table.concat(r)
        end
        local sy, ty = 1 + rnd(12), 1 + rnd(12)
        local function put(y, x, c) rows[y] = rows[y]:sub(1, x - 1) .. c .. rows[y]:sub(x + 1) end
        put(sy, 2, "S"); put(ty, 19, "T"); put(sy, 1, "#"); put(ty, 20, "#")
        local m = parse(rows)
        local ref = P.belt_route(m.s, m.t, 2, m.bounds, m.cost)
        local got = Tv.route(m.s, m.t, 2, m.bounds, m.cost, { sd = 2 })
        if (ref ~= nil) ~= (got ~= nil) then diff = diff + 1
        elseif ref then
          both = both + 1
          if #ref ~= #got then diff = diff + 1 end
        end
      end
      ck(diff == 0 and both > 40, "m1 : équivalence avec P.belt_route sur terrain sans gisement ni paire (" .. diff .. " écart(s), " .. both .. " tracés)")
    end
    -- (n) poteaux : chaîne qui évite le gisement
    do
      local reach = 9
      local function mk(blocked_ore)
        local function free() return true end
        local function chain(a, b, f) return P.pole_chain(a, b, reach, false, f, nil) end
        return free, chain
      end
      local free, chain = mk()
      local a, b = { x = 0.5, y = 0.5 }, { x = 60.5, y = 0.5 }
      local function ore_blob(x0, x1, y0, y1) return function(x, y) local tx, ty = math.floor(x), math.floor(y) return tx >= x0 and tx <= x1 and ty >= y0 and ty <= y1 end end
      local ore1 = ore_blob(17, 19, -1, 1)
      local base = chain(a, b, free)
      local n0 = 0
      for _, c in ipairs(base) do if ore1(c.x, c.y) then n0 = n0 + 1 end end
      ck(n0 >= 1, "n0 : la chaîne d'avant pose un poteau sur le gisement")
      local c1, st1 = Tv.pole_chain(function(aa, bb, f) return chain(aa, bb, f) end, a, b, free, ore1)
      local n1 = 0
      for _, c in ipairs(c1 or {}) do if ore1(c.x, c.y) then n1 = n1 + 1 end end
      ck(c1 and st1 == "evitee" and n1 == 0 and #c1 <= #base + Tv.POLE_EXTRA, "n1 : chaîne sans gisement, au plus +2 poteaux")
      local _, st2 = Tv.pole_chain(function(aa, bb, f) return chain(aa, bb, f) end, a, b, free, function() return false end)
      ck(st2 == "libre", "n2 : sans gisement : libre")
      -- gisement partout : la chaîne d'avant est gardée
      local c3, st3 = Tv.pole_chain(function(aa, bb, f) return chain(aa, bb, f) end, a, b, free, function() return true end)
      ck(st3 == "traverse" and c3 and #c3 == #base, "n3 : gisement partout : chaîne d'avant")
      -- gisement immense : le contournement coûte plus de +2 poteaux, la chaîne d'avant est gardée
      local ore4 = ore_blob(10, 50, -16, 16)
      local free4 = function(x, y) return free(x, y) and not ore4(x, y) end
      local alt4 = chain(a, b, free4)
      ck(alt4 and #alt4 > #base + Tv.POLE_EXTRA, "n3b : le contournement existe et coûte plus de +2 poteaux (" .. tostring(alt4 and #alt4) .. " contre " .. #base .. ")")
      local c4, st4 = Tv.pole_chain(function(aa, bb, f) return chain(aa, bb, f) end, a, b, free, ore4)
      ck(st4 == "traverse" and c4 and #c4 == #base, "n4 : contournement trop long : chaîne d'avant (" .. tostring(st4) .. ")")
      -- tuile de poteau contre un bras
      local x, y = Tv.pole_tile(function(f) if f(1, 1) then return 1, 1 end if f(2, 2) then return 2, 2 end return nil end, function() return true end,
        function(px, py) return px == 1 end)
      ck(x == 2 and y == 2, "n5 : tuile de poteau sans gisement d'abord")
    end
    -- reprise par tranches : une tuile en file occupée entre deux passes (plantage de la partie neuve du 9/11 à 15 min, traversee.lua:217 :
    -- `false` entrait dans le prix) ; le tracé abandonne cet état et continue par les autres
    do
      local b = { x0 = 1, y0 = 1, x1 = 40, y1 = 9 }
      local s, t = { x = 1, y = 5 }, { x = 40, y = 5 }
      local function libre(cx, cy) return (cx >= b.x0 and cx <= b.x1 and cy >= b.y0 and cy <= b.y1) and 1 or nil end
      local function reprise(choisir)
        local none, why, st = Tv.route(s, t, 2, b, libre, { slice = 6, sd = 2 })
        ck(none == nil and why == "pending" and st and #st.open > 0, "reprise : la 1re tranche rend un état en attente (" .. tostring(why) .. ")")
        local occ = choisir(st)
        return Tv.route(s, t, 2, b, function(cx, cy) if occ[cx .. "," .. cy] then return nil end return libre(cx, cy) end, { resume = st, slice = 100000, sd = 2 }), occ
      end
      -- la tuile du prochain état à développer est prise : un chemin subsiste, qui l'évite
      local tiles, occ1 = reprise(function(st) local e = st.open[1]; return { [e.x .. "," .. e.y] = true } end)
      ck(tiles ~= nil, "reprise : un chemin subsiste quand une seule tuile en file est prise")
      for _, e in ipairs(tiles or {}) do ck(not occ1[e.x .. "," .. e.y], "reprise : le chemin passe sur la tuile prise (" .. e.x .. "," .. e.y .. ")") end
      -- toutes les tuiles en file sont prises : refus net, pas de plantage
      local none2 = reprise(function(st) local o = {}; for _, e in ipairs(st.open) do o[e.x .. "," .. e.y] = true end; return o end)
      ck(none2 == nil, "reprise : aucun chemin quand toute la file est prise")
    end
  end)
  if not ok then fails = fails + 1; errs[#errs + 1] = "plantage : " .. tostring(err) end
  return fails, errs
end

section("1. Batterie sur le module réel")
local Tv = require("shared.team.traversee")
do
  local n, errs = battery(Tv)
  for _, e in ipairs(errs) do print("  ECHEC : " .. e) end
  check(n == 0, "batterie : 0 échec (" .. n .. ")")
end

section("2. Mutants")
do
  local fh = io.open("shared/team/traversee.lua", "rb")
  local src = fh:read("*a")
  fh:close()
  local nmut = 0
  local function mutant(label, from, to)
    local s, n = src:gsub(from:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"), (to:gsub("%%", "%%%%")), 1)
    if n ~= 1 then check(false, "mutant « " .. label .. " » : motif introuvable dans traversee.lua") return end
    local fn, e = load(s, "=mutant", "t", _ENV)
    if not fn then check(false, "mutant « " .. label .. " » : ne se charge pas : " .. tostring(e)) return end
    local t0 = os.clock()
    local M = fn()
    local nf = battery(M)
    nmut = nmut + 1
    if os.clock() - t0 > 3 then print(string.format("  (info) mutant « %s » : %.1f s", label, os.clock() - t0)) end
    check(nf >= 1, "mutant « " .. label .. " » refusé par la batterie (" .. nf .. " échec(s))")
  end
  mutant("portée + 1", "for kk = 1, maxd do", "for kk = 1, maxd + 1 do")
  mutant("paire de portée au moins 3", "if kk >= 2 and ok_span", "if kk >= 3 and ok_span")
  mutant("sortie sur une tuile interdite", "ok_span and free(mx, my) and not", "ok_span and not")
  mutant("souterrain de même axe ignoré", "if a ~= nil and (a == true or a == axis) then ok_span = false end", "if false then ok_span = false end")
  mutant("paire sans surcout", "tc(mx, my) + (kk - 1) + Tv.UG_COST", "tc(mx, my)")
  mutant("virage permis juste après la sortie", "if turn == 0 or cur.m == 0 then", "if true then")
  mutant("arrivée par l'avant permise", "if cur.d ~= ((td + 1) % 4) + 1 and (cur.m == 0 or cur.d == td) then", "if true then")
  mutant("surcoût de gisement ignoré", "if pen > 0 and mo[tk(x, y)] then c = c + pen end", "")
  mutant("borne de détour retirée", "local limit = Tv.detour_limit(base_phys)", "local limit = math.huge")
  mutant("gisement sans choix du moins couvert", "if on < best_ore or (on == best_ore and phys(el) < phys(best)) then", "if false then")
  mutant("traversée : écart de la paire dépasse la portée", "for j = math.min(i + maxd, last - 1), i + 2, -1 do", "for j = math.min(i + maxd + 1, last - 1), i + 2, -1 do")
  mutant("traversée : virage permis juste après la sortie", "if after and after.d == d and j + 1 <= last then", "if after and j + 1 <= last then")
  mutant("traversée : souterrain de même axe ignoré", "if a ~= nil and (a == true or a == axis) then ok = false end", "if false then ok = false end")
  mutant("détour gisement : cinq recherches", "Tv.ORE_STEPS = { 8 } ", "Tv.ORE_STEPS = { 8, 5, 3, 2, 1 } ")
  mutant("budget : états non décomptés", "budget.left = budget.left - 1", "budget.left = budget.left")
  mutant("budget : épuisement ignoré", "if budget.left < 0 then return nil, \"trop long\", expanded end", "if false then return nil end")
  mutant("poteaux : borne +2 ignorée", "if alt and (not base or #alt <= #base + extra) then", "if alt then")
  mutant("poteaux : gisement jamais évité", "local alt = chain(a, b, free2)", "local alt = nil")
  mutant("preuve : portée non contrôlée", "if not (maxd and k >= 2 and k <= maxd) then", "if false then")
  mutant("reprise : état sur une tuile prise développé", "elseif free(cur.x, cur.y) then", "else")
  check(nmut >= 12, "au moins 12 mutants joués (" .. nmut .. ")")
end

-- lot TRAVERSEE-CAP : avec le budget du plan (Tv.PLAN_BUDGET, Trav.route en jeu) et des souterrains, la phase A ne prend que la moitié du budget ;
-- le plafond ctx.max de l'appelant (300 pour la branche de piquage) doit TENIR : il bornait la phase A, la moitié du budget le remplaçait (2 000 états)
section("plafond de l'appelant avec le budget du plan")
do
  local Tv = require("shared.team.traversee")
  -- un mur de 8 tuiles d'épaisseur (au-delà de la portée 5 des souterrains) coupe toute la boîte : aucun chemin, chaque phase va à son plafond
  local function cost(x, y) if x >= 30 and x <= 37 then return nil end return 1 end
  local bounds = { x0 = 0, y0 = 0, x1 = 59, y1 = 59 }
  local function run(max)
    local e0 = Tv.STATS.expanded
    local tiles, why = Tv.route({ x = 5, y = 30 }, { x = 55, y = 30 }, 2, bounds, cost,
      { maxd = 5, sd = 2, weight = 1.4, max = max, budget = { left = Tv.PLAN_BUDGET } })
    return tiles, why, Tv.STATS.expanded - e0
  end
  local t1, w1, n1 = run(300)
  check(t1 == nil and w1 == "trop long" and n1 <= 2 * 301,
    string.format("plafond 300 tenu, budget %d : %d états développés <= %d (deux phases), %s", Tv.PLAN_BUDGET, n1, 2 * 301, tostring(w1)))
  local _, _, n2 = run(nil)
  check(n2 > 2 * 301 and n2 <= Tv.PLAN_BUDGET + 2, string.format("sans plafond de l'appelant : la moitié du budget pour la phase A, comme avant (%d états)", n2))
  -- même borne par passes (ctx.phase_slice, lot TRANCHES-FOREUSES)
  local e0, st, why, tiles = Tv.STATS.expanded, nil, nil, nil
  local k = 0
  repeat
    k = k + 1
    tiles, why, st = Tv.route({ x = 5, y = 30 }, { x = 55, y = 30 }, 2, bounds, cost,
      { maxd = 5, sd = 2, weight = 1.4, max = 300, budget = { left = Tv.PLAN_BUDGET }, phase_slice = 200, phase_state = st })
  until why ~= "pending" or k > 50
  check(tiles == nil and why == "trop long" and Tv.STATS.expanded - e0 <= 2 * 301,
    string.format("par passes : plafond 300 tenu (%d états en %d passes)", Tv.STATS.expanded - e0, k))
end

print(string.format("[TRAVERSEE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
