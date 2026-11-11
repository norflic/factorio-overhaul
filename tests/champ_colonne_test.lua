--[[
  Tests hors jeu du lot FONDERIE (retour du DC du 2/11 au soir : « il faut tout le temps remplir n/2 coffres de charbons + n/2 coffres
  de cuivre pour n fours [...] la fonderie entière cesse de fonctionner » ; « Faites attention aux passages sous-terrain et aux
  splitters (si pas recherchés) »). Pur, aucune API Factorio. Usage, depuis la racine du mod :   lua5.2 tests/champ_colonne_test.lua

  1. tracé (Co.route) : tout droit, mur franchi par souterrain seulement s'il est débloqué et à portée, entrée et sortie droites,
     jamais par-dessus un souterrain déjà posé, déterminisme ;
  2. ligne de charbon (Co.coal_line) : foreuses sur des tuiles libres, charbon sous chacune, poteaux qui les couvrent ;
  3. champs entiers en colonne (Ch.plan, design « colonne ») : le contrôle de champ_verif, voies des tapis comprises (chaque four
     reçoit minerai ET charbon, chaque coffre de quai reçoit des plaques, aucune voie mêlée, aucun raccord faux) ; ce que le DC voit :
     0 coffre de combustible quand le charbon est joignable, un seul par colonne sinon ; quai assez rapide ; répartiteurs et
     souterrains seulement s'ils sont débloqués ; le tracé du charbon hors du champ ;
  4. stabilité (une bande seule, cadre figé, ⊂ plan entier ; toutes les pièces du plan entier posées par au moins une bande) ;
     cadre d'avant le lot (sans `design`) : fonderie à coffres inchangée ;
  5. déterminisme ;
  6. mutants : défauts injectés dans un plan ou dans la règle, chacun vu.
]]
package.path = "./?.lua;" .. package.path

local Ch = require("shared.team.champ")
local Co = require("shared.team.champ_colonne")
local Cv = require("shared.team.champ_verif")
-- (3/11, 0.6.43) sections 1 à 7 : le repli au coffre de tête, gardé pour les cadres 0.6.42 déjà posés (une colonne « coffre » du cadre) ;
-- la section 8 contrôle la règle des cadres neufs : colonne REFUSÉE au lieu du coffre (Ch.CFG.refuse_coffre, vrai en jeu)
Ch.CFG.refuse_coffre = false

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local BELTS3 = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }
local function disc(cx, cy, r, out)
  out = out or {}
  for x = cx - r, cx + r do for y = cy - r, cy + r do if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r then out[#out + 1] = x; out[#out + 1] = y end end end
  return out
end
local function ellipse(cx, cy, a, b)
  local o = {}
  for x = cx - a, cx + a do for y = cy - b, cy + b do if ((x - cx) / a) ^ 2 + ((y - cy) / b) ^ 2 <= 1 then o[#o + 1] = x; o[#o + 1] = y end end end
  return o
end

--- Spec d'un champ en colonne. o : coal (liste plate), split, ug, pole ("petit" | "moyen"), electric, belts, blocked, drill, fs, frame.
local function spec_of(ore, o)
  o = o or {}
  local pole = (o.pole == "moyen") and { reach = 3, wire = 9 } or { reach = 2, wire = 7.5 }
  local sp = { ore = ore, blocked = o.blocked or {}, drill = o.drill or { size = 3, reach = 1, rate = 0.5 }, pole = pole,
    belts = o.belts or BELTS3, furnace = { size = o.fs or 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 }, inserter = { rate = 0.83 },
    target = o.target or { x = 1000, y = 0 }, max_side = o.max_side or 8, frame = o.frame, design = "colonne",
    coal = o.coal and { tiles = o.coal, rate = 0.5 } or nil, logistics = { splitter = o.split, underground = o.ug } }
  if o.electric then sp.furnace = { size = o.fs or 2, rate = 0.625, fuel = false } end
  return sp
end

local function sig(e)
  return string.format("%s|%.1f|%.1f|%d|%s", e.kind, e.x, e.y, e.dir or 0, tostring(e.ug))
end
local function count(plan, pred) local n = 0; for _, e in ipairs(plan.ents) do if pred(e) then n = n + 1 end end; return n end

---------------------------------------------------------------------------------------------------
section("1. trace du charbon (Co.route)")
---------------------------------------------------------------------------------------------------
local function wall(x0, x1, y0, y1)
  local s = {}
  for x = x0, x1 do for y = y0, y1 do s[Co.tk(x, y)] = true end end
  return function(u, v) return not s[Co.tk(u, v)] end
end
local function free_all() return true end
local BOX = { u0 = -40, v0 = -40, u1 = 60, v1 = 40 }
local function route_ok(r, ug, name)
  -- chaque tuile une fois ; chaque pas va à la suivante ; une paire de souterrains : entrée droite, écart ≤ ug, sortie suivie tout droit
  local seen, okk = {}, true
  for i, t in ipairs(r) do
    local k = Co.tk(t.u, t.v)
    if seen[k] then okk = false end
    seen[k] = true
    if t.kind == "souterrain" and t.ug == "input" then
      local o = r[i + 1]
      local d = Co.D4[t.d]
      local gap = o and ((o.u - t.u) * d[1] + (o.v - t.v) * d[2]) or -1
      if not (o and o.ug == "output" and o.d == t.d and gap >= 2 and gap <= ug) then okk = false end
      if i > 1 then
        local p = r[i - 1]
        if not (p.u + Co.D4[p.d][1] == t.u and p.v + Co.D4[p.d][2] == t.v and p.d == t.d) then okk = false end
      end
      local nx = r[i + 2]
      if nx and nx.d ~= t.d then okk = false end
    elseif t.kind == "tapis" and i < #r then
      local d = Co.D4[t.d]
      if not (r[i + 1].u == t.u + d[1] and r[i + 1].v == t.v + d[2]) then okk = false end
    end
  end
  check(okk, name .. " : tracé cohérent (pas, souterrains droits, écart ≤ " .. tostring(ug) .. ")")
end
local function nug(r) local n = 0; for _, t in ipairs(r) do if t.kind == "souterrain" then n = n + 1 end end; return n end
do
  local r = Co.route({ u = 0, v = 0 }, 2, { u = 20, v = 0 }, 2, free_all, nil, nil, BOX)
  check(r and #r == 21 and nug(r) == 0, "tout droit : 21 tapis, 0 souterrain")
  r = Co.route({ u = 0, v = 0 }, 2, { u = 20, v = 0 }, 2, free_all, nil, 5, BOX)
  check(r and nug(r) == 0, "tout droit, souterrains débloqués : aucun (ils ne servent qu'à passer un obstacle)")
  -- mur de 3 tuiles d'épaisseur, de haut en bas de la boîte : sans souterrain, aucun chemin ; avec, une paire
  local w3 = wall(9, 11, -100, 100)
  r = Co.route({ u = 0, v = 0 }, 2, { u = 20, v = 0 }, 2, w3, nil, nil, BOX)
  check(r == nil, "mur infranchissable sans souterrain : aucun tracé (repli au coffre de tête)")
  r = Co.route({ u = 0, v = 0 }, 2, { u = 20, v = 0 }, 2, w3, nil, 5, BOX)
  check(r ~= nil and nug(r) == 2, "mur de 3 avec souterrains (portée 5) : une paire")
  if r then route_ok(r, 5, "mur de 3") end
  -- portée : 4 tuiles passent à 5 (entrée et sortie distantes de 5), 5 tuiles ne passent pas
  r = Co.route({ u = 0, v = 0 }, 2, { u = 20, v = 0 }, 2, wall(9, 12, -100, 100), nil, 5, BOX)
  check(r ~= nil and nug(r) == 2, "mur de 4, portée 5 : franchi")
  r = Co.route({ u = 0, v = 0 }, 2, { u = 20, v = 0 }, 2, wall(9, 13, -100, 100), nil, 5, BOX)
  check(r == nil, "mur de 5, portée 5 : non franchi")
  -- mur fini : sans souterrain, contournement ; avec, le contournement long est remplacé par une paire
  local wf = wall(9, 11, -12, 12)
  local r1 = Co.route({ u = 0, v = 0 }, 2, { u = 20, v = 0 }, 2, wf, nil, nil, BOX)
  local r2 = Co.route({ u = 0, v = 0 }, 2, { u = 20, v = 0 }, 2, wf, nil, 5, BOX)
  check(r1 ~= nil and nug(r1) == 0 and #r1 > 40, "mur fini sans souterrain : contournement (" .. tostring(r1 and #r1) .. " tuiles)")
  check(r2 ~= nil and nug(r2) == 2 and #r2 < 25, "mur fini avec souterrains : une paire au lieu du détour (" .. tostring(r2 and #r2) .. " tuiles)")
  if r1 then route_ok(r1, 5, "contournement") end
  -- un souterrain déjà posé sous le mur : on ne passe pas par-dessus (la paire se lierait à lui)
  local ugs = { [Co.tk(10, 0)] = true }
  r = Co.route({ u = 0, v = 0 }, 2, { u = 20, v = 0 }, 2, wall(9, 11, -1, 1), function(u, v) return not ugs[Co.tk(u, v)] end, 5, BOX)
  local over = false
  if r then
    for i, t in ipairs(r) do
      if t.ug == "input" then
        local o = r[i + 1]
        local d = Co.D4[t.d]
        for k = 1, (o.u - t.u) * d[1] + (o.v - t.v) * d[2] - 1 do if ugs[Co.tk(t.u + k * d[1], t.v + k * d[2])] then over = true end end
      end
    end
  end
  check(r ~= nil and not over, "aucune paire au-dessus d'un souterrain existant")
  -- forêt (arbres défrichables : posables mais chers, lot-20261020) : contournée quand le détour est court, passée DESSOUS par souterrain
  local forest = {}
  for x = 8, 12 do for y = -6, 6 do forest[Co.tk(x, y)] = true end end
  local tcost = function(u, v) return forest[Co.tk(u, v)] and (1 + Co.SOFT_COST) or 1 end
  local function on_trees(r) local n = 0; for _, t in ipairs(r) do if forest[Co.tk(t.u, t.v)] then n = n + 1 end end; return n end
  local rf = Co.route({ u = 0, v = 0 }, 2, { u = 20, v = 0 }, 2, free_all, nil, nil, BOX, nil, tcost)
  check(rf and on_trees(rf) == 0, "forêt sans souterrain : contournée (" .. tostring(rf and on_trees(rf)) .. " tapis sur un arbre, " .. tostring(rf and #rf) .. " tuiles)")
  local ru = Co.route({ u = 0, v = 0 }, 2, { u = 20, v = 0 }, 2, free_all, nil, 7, BOX, nil, tcost)
  check(ru and on_trees(ru) == 0 and nug(ru) == 2, "forêt avec souterrains : passée dessous (" .. tostring(ru and nug(ru)) .. " souterrains)")
  local wide = {}
  for x = 8, 12 do for y = -100, 100 do wide[Co.tk(x, y)] = true end end
  local rw = Co.route({ u = 0, v = 0 }, 2, { u = 20, v = 0 }, 2, free_all, nil, nil, BOX, nil, function(u, v) return wide[Co.tk(u, v)] and (1 + Co.SOFT_COST) or 1 end)
  check(rw ~= nil and #rw == 21, "forêt sans fin, sans souterrain : traversée tout droit (le défrichage reste possible)")
  -- virage à l'arrivée et sens imposé
  r = Co.route({ u = 0, v = 0 }, 2, { u = 10, v = 10 }, 3, free_all, nil, 5, BOX)
  check(r and r[#r].u == 10 and r[#r].v == 10 and r[#r].d == 3, "arrivée tournée vers le sens demandé")
  -- déterminisme
  local a = Co.route({ u = 0, v = 0 }, 2, { u = 20, v = 7 }, 2, wf, nil, 5, BOX)
  local b = Co.route({ u = 0, v = 0 }, 2, { u = 20, v = 7 }, 2, wf, nil, 5, BOX)
  local same = a and b and #a == #b
  if same then for i = 1, #a do if a[i].u ~= b[i].u or a[i].v ~= b[i].v or a[i].d ~= b[i].d or a[i].kind ~= b[i].kind then same = false end end end
  check(same, "tracé déterministe")
end

---------------------------------------------------------------------------------------------------
section("2. ligne de charbon (Co.coal_line)")
---------------------------------------------------------------------------------------------------
do
  local coal, set = {}, {}
  for x = 40, 55 do for y = -6, 6 do coal[#coal + 1] = { x, y }; set[Co.tk(x, y)] = true end end
  local isc = function(u, v) return set[Co.tk(u, v)] == true end
  local line = Co.coal_line(coal, isc, free_all, { size = 3, reach = 1 }, 3, { u = 0, v = 0 }, 2, 7.5)
  check(line ~= nil and line.drills == 3, "ligne de 3 foreuses sur un gisement de 16 x 13")
  if line then
    local okc = true
    for _, e in ipairs(line.ents) do
      if e.kind == "foreuse" then
        local n = 0
        for x = e.u - 1, e.u + 3 do for y = e.v - 1, e.v + 3 do if isc(x, y) then n = n + 1 end end end
        if n < 3 then okc = false end
      end
    end
    check(okc, "chaque foreuse a du charbon dans sa zone")
    check(math.abs(line.exit.u - 0) + math.abs(line.exit.v) <= 42, "sortie de la ligne du côté de la cible (" .. line.exit.u .. ", " .. line.exit.v .. ")")
  end
  local big = Co.coal_line(coal, isc, free_all, { size = 3, reach = 1 }, 40, { u = 0, v = 0 }, 2, 7.5)
  check(big ~= nil and big.drills >= 4 and big.drills <= 14, "ligne bornée par le gisement (" .. tostring(big and big.drills) .. " foreuses pour 40 voulues ; 7 par côté au plus sur 16 + 2 tuiles)")
  local one = Co.coal_line(coal, isc, free_all, { size = 3, reach = 1 }, 40, { u = 0, v = 0 }, 2, 7.5, 5)
  local per = { 0, 0 }
  if one then for _, e in ipairs(one.ents) do if e.kind == "foreuse" then per[e.dv ~= 0 and (e.dv > 0 and 1 or 2) or (e.du > 0 and 1 or 2)] = per[e.dv ~= 0 and (e.dv > 0 and 1 or 2) or (e.du > 0 and 1 or 2)] + 1 end end end
  check(one ~= nil and per[1] <= 5 and per[2] <= 5, "au plus 5 foreuses par côté quand une voie en porte 5 (" .. per[1] .. ", " .. per[2] .. ")")
  check(Co.coal_line({}, isc, free_all, { size = 3, reach = 1 }, 3, { u = 0, v = 0 }, 2, 7.5) == nil, "aucun charbon : aucune ligne")
end

---------------------------------------------------------------------------------------------------
section("3. champs en colonne")
---------------------------------------------------------------------------------------------------
--- Ce que le DC voit d'un plan : rapport du contrôle + compteurs propres au lot. Rend le rapport.
local function judge(name, sp, p, o)
  o = o or {}
  check(p ~= nil, name .. " : plan rendu")
  if not p then return nil end
  local rep = Cv.verify(p, sp)
  check(rep.ok, name .. " : contrôle " .. Cv.line(rep))
  local cols = 0
  for _, bd in ipairs(p.bands) do cols = cols + #bd.groups end
  local fuel_chests = count(p, function(e) return e.kind == "coffre" and e.role == "combustible" end)
  local n_ug = count(p, function(e) return e.kind == "souterrain" end)
  local n_sp = count(p, function(e) return e.kind == "repartiteur" end)
  if o.voie then
    check(fuel_chests == 0, string.format("%s : 0 coffre de combustible à garnir (%d colonnes, %d coffres)", name, cols, fuel_chests))
    if sp.furnace.fuel then
      -- la ligne de charbon suffit aux fours (foreuses de charbon × débit ≥ fours × charbon d'un four), relu sur les entités
      local cd = count(p, function(e) return e.kind == "foreuse" and e.role == "charbon" end)
      check(cd * sp.coal.rate + 1e-9 >= p.stats.furnaces * sp.furnace.fuel_rate,
        string.format("%s : charbon extrait %.2f/s >= brûlé %.2f/s", name, cd * sp.coal.rate, p.stats.furnaces * sp.furnace.fuel_rate))
      -- aucune colonne affamée pendant le remplissage : l'extrait couvre ce que les bras de dérivation peuvent prendre (relu ici)
      local nb = count(p, function(e) return e.kind == "bras" and e.role == "charbon" end)
      check(cd * sp.coal.rate + 1e-9 >= nb * sp.inserter.rate * 0.85,
        string.format("%s : charbon extrait %.2f/s >= prise des %d bras de dérivation %.2f/s", name, cd * sp.coal.rate, nb, nb * sp.inserter.rate * 0.85))
    end
  else
    check(fuel_chests <= cols, string.format("%s : au plus un coffre de combustible par colonne (%d colonnes, %d coffres)", name, cols, fuel_chests))
  end
  if not sp.logistics.underground then check(n_ug == 0, name .. " : aucun souterrain sans la recherche (" .. n_ug .. ")") end
  if not sp.logistics.splitter then check(n_sp == 0, name .. " : aucun répartiteur sans la recherche (" .. n_sp .. ")") end
  if o.want_ug then check(n_ug >= 2, name .. " : souterrains utilisés (" .. n_ug .. ")") end
  if o.no_split then check(n_sp == 0, name .. " : répartiteurs débloqués mais pas sur le tronc (" .. n_sp .. ")") end
  -- quai : bras de quai × débit d'un bras sur tapis ≥ plaques de la colonne (relu ici sur les entités, pas sur la règle)
  local short = 0
  local per = {}
  for _, e in ipairs(p.ents) do
    local k = (e.band or 0) .. ":" .. (e.group or 0)
    per[k] = per[k] or { f = 0, bay = 0 }
    if e.kind == "four" then per[k].f = per[k].f + 1 end
    if e.kind == "coffre" and e.role == "sortie" then per[k].bay = per[k].bay + 1 end
  end
  for bi, bd in ipairs(p.bands) do
    for gi in ipairs(bd.groups) do
      local q = per[bi .. ":" .. gi] or { f = 0, bay = 0 }
      if q.bay * 0.83 * 0.85 + 1e-9 < q.f * sp.furnace.rate then short = short + 1 end
    end
  end
  check(short == 0, name .. " : quais assez rapides pour les plaques (" .. short .. " trop lents)")
  -- le tracé du charbon ne traverse pas le gisement de minerai
  local ore = {}
  for i = 1, #sp.ore - 1, 2 do ore[Ch.key(sp.ore[i], sp.ore[i + 1])] = true end
  local on_ore = 0
  for _, e in ipairs(p.ents) do
    if (e.kind == "tapis" or e.kind == "souterrain") and e.role == "charbon" and (e.band or 0) == 0 then
      if ore[Ch.key(math.floor(e.x), math.floor(e.y))] then on_ore = on_ore + 1 end
    end
  end
  check(on_ore == 0, name .. " : tracé du charbon hors du gisement (" .. on_ore .. " tuiles dessus)")
  print(string.format("  %s : %d colonnes, %d fours, %d foreuses, %d coffres de combustible, %d coffres de quai, %d souterrains, %d répartiteurs ; %s",
    name, cols, p.stats.furnaces, p.stats.drills, fuel_chests,
    count(p, function(e) return e.kind == "coffre" and e.role == "sortie" end), n_ug, n_sp, Cv.line(rep)))
  for _, cs in ipairs(p.stats.coal or {}) do
    print(string.format("    charbon côté %+d : %s%s", cs.side, cs.voie and "voie" or "coffre de tête", cs.why and (" (" .. cs.why .. ")") or ""))
  end
  return rep
end

local ORE = disc(0, 0, 20)
local COAL_NEAR = disc(60, 40, 8)
local plans = {}
do
  local cases = {
    { "disque, charbon proche, sans logistique", { coal = COAL_NEAR }, { voie = true } },
    -- répartiteurs débloqués mais NON posés sur le tronc (banc-2, 3/11 : la cascade 50/50 laisse les dernières colonnes sans charbon
    -- pendant le remplissage des tampons d'amont ; le bras de dérivation borne la prise de chaque colonne)
    { "disque, répartiteurs", { coal = COAL_NEAR, split = true }, { voie = true, no_split = true } },
    { "disque, répartiteurs et souterrains", { coal = COAL_NEAR, split = true, ug = 5 }, { voie = true, no_split = true } },
    { "disque, poteaux moyens", { coal = COAL_NEAR, pole = "moyen" }, { voie = true } },
    { "disque, sans charbon (coffre de tête)", {}, {} },
  }
  for _, cs in ipairs(cases) do
    local sp = spec_of(ORE, cs[2])
    local p = Ch.plan(sp)
    plans[cs[1]] = { sp = sp, p = p }
    judge(cs[1], sp, p, cs[3])
  end
  -- four électrique : ni tête ni charbon, deux voies de minerai
  local sp = spec_of(ORE, { electric = true, coal = COAL_NEAR })
  local p = Ch.plan(sp)
  judge("disque, four électrique", sp, p, { voie = true })
  check(p and count(p, function(e) return e.role == "charbon" end) == 0, "four électrique : aucune pièce de charbon")
  -- deux bouts (ellipse longue au tapis jaune) : deux réseaux de charbon
  local sp2 = spec_of(ellipse(0, 0, 60, 14), { coal = disc(0, 60, 9), belts = { { lane = 7.5 } }, max_side = 30 })
  local p2 = Ch.plan(sp2)
  judge("ellipse longue, deux bouts", sp2, p2, { voie = true })
  local sides = 0
  for _, cs in ipairs(p2 and p2.stats.coal or {}) do if cs.voie then sides = sides + 1 end end
  check(sides == 2, "ellipse longue : charbon par tapis des deux côtés (" .. sides .. ")")
  -- rivière de 3 tuiles entre le champ et le charbon, sur toute la carte : sans souterrain, repli ; avec, franchie
  local river = {}
  for x = 36, 38 do for y = -400, 400 do river[Ch.key(x, y)] = true end end
  local coal_far = disc(60, 0, 8)
  local spn = spec_of(ORE, { coal = coal_far, blocked = river })
  local pn = Ch.plan(spn)
  judge("rivière sans souterrain", spn, pn, {})
  check(pn and count(pn, function(e) return e.kind == "coffre" and e.role == "combustible" end) > 0, "rivière sans souterrain : repli au coffre de tête")
  local spu = spec_of(ORE, { coal = coal_far, blocked = river, ug = 5 })
  local pu = Ch.plan(spu)
  plans["rivière avec souterrains"] = { sp = spu, p = pu }
  judge("rivière avec souterrains", spu, pu, { voie = true, want_ug = true })
  -- autre ligne de l'équipe (tapis posé) qui barre le chemin : contournée sans souterrain, passée dessous avec
  local line = {}
  for y = -120, 120 do line[Ch.key(45, y)] = true end
  local spl = spec_of(ORE, { coal = disc(70, 0, 8), blocked = line })
  judge("ligne voisine, sans souterrain", spl, Ch.plan(spl), {})
  local spl2 = spec_of(ORE, { coal = disc(70, 0, 8), blocked = line, ug = 5 })
  judge("ligne voisine, avec souterrains", spl2, Ch.plan(spl2), { voie = true, want_ug = true })
  -- foreuses de 5 et fours de 3 ou 4 (côtés impairs des foreuses : un côté pair n'a pas de tuile de dépôt centrale, la règle du
  -- champ ne le pose pas ; le jeu lit la foreuse de base, 3 x 3)
  for _, fs in ipairs({ 3, 4 }) do
    local sp5 = spec_of(disc(0, 0, 26), { coal = disc(70, 50, 16), drill = { size = 5, reach = 1, rate = 1 }, fs = fs })
    judge("foreuses de 5, fours de " .. fs, sp5, Ch.plan(sp5), { voie = true })
  end
  -- gisement le plus proche COUVERT (paires thermiques de l'équipe, lot2-20261020, emerald) et second gisement libre plus loin : la ligne va
  -- sur le second, aucun coffre de tête
  local near, far = disc(50, 30, 8), disc(-20, 75, 9)
  local coal2 = {}
  for _, l in ipairs({ near, far }) do for i = 1, #l do coal2[#coal2 + 1] = l[i] end end
  local covered = {}
  for i = 1, #near - 1, 2 do covered[Ch.key(near[i], near[i + 1])] = true end
  local spc = spec_of(ORE, { coal = coal2, blocked = covered })
  local pc = Ch.plan(spc)
  judge("charbon proche couvert, second gisement libre", spc, pc, { voie = true })
  -- gisement de charbon trop petit pour tout le côté : les premières colonnes du tronc par la voie, les autres au coffre de tête,
  -- jamais une colonne « en voie » que la ligne ne peut pas nourrir (le contrôle de capacité de judge le dit)
  local spp = spec_of(disc(0, 0, 26), { coal = disc(70, 50, 10), drill = { size = 5, reach = 1, rate = 1 }, fs = 3 })
  local pp = Ch.plan(spp)
  judge("charbon trop petit", spp, pp, {})
  local part, chests = false, 0
  for _, cs in ipairs(pp and pp.stats.coal or {}) do if cs.voie and cs.why and cs.why:find("charbon pour", 1, true) then part = true end end
  chests = pp and count(pp, function(e) return e.kind == "coffre" and e.role == "combustible" end) or 0
  check(part and chests >= 1, "charbon trop petit : voie pour une partie des colonnes, coffre de tête pour les autres (" .. chests .. ")")
  if pp then
    local cd = count(pp, function(e) return e.kind == "foreuse" and e.role == "charbon" end)
    local fed = 0
    for _, e in ipairs(pp.ents) do if e.kind == "four" then fed = fed + 1 end end
    -- fours des colonnes en voie seulement : fours de la bande dont la colonne n'a pas de coffre de tête
    local chest_cols = {}
    for _, e in ipairs(pp.ents) do if e.kind == "coffre" and e.role == "combustible" then chest_cols[e.band .. ":" .. e.group] = true end end
    local fv = 0
    for _, e in ipairs(pp.ents) do if e.kind == "four" and not chest_cols[e.band .. ":" .. e.group] then fv = fv + 1 end end
    check(cd * spp.coal.rate + 1e-9 >= fv * spp.furnace.fuel_rate, string.format("charbon trop petit : la ligne (%.2f/s) nourrit les colonnes en voie (%.2f/s)",
      cd * spp.coal.rate, fv * spp.furnace.fuel_rate))
  end
end

---------------------------------------------------------------------------------------------------
section("4. stabilite et cadres d'avant le lot")
---------------------------------------------------------------------------------------------------
local lone, lone_bad = 0, 0
local band_max, band_nocoal, band_full_max = 0, 0, 0
local function stability(ore, o)
  local sp = spec_of(ore, o)
  local full = Ch.plan(sp)
  local in_full, need = {}, {}
  for _, e in ipairs(full.ents) do
    in_full[sig(e)] = true
    if e.role ~= "relais" and e.kind ~= "poteau" then need[sig(e)] = true end
  end
  local bad, total, seen = 0, 0, {}
  for _, bd in ipairs(full.bands) do
    local fr = {}
    for _, k in ipairs({ "axis", "phase", "exit", "origin", "umin", "umax", "v0", "offsets", "design", "cols", "coal" }) do fr[k] = full.frame[k] end
    fr.only = { [bd.pr] = true }
    local oo = {}
    for k, v in pairs(o or {}) do oo[k] = v end
    oo.frame = fr
    local spp = spec_of(ore, oo)
    local part = Ch.plan(spp)
    -- (projet séparé) la bande sans les pièces communes du réseau du charbon : < 800 entités (critère D3), et ses pièces propres au charbon
    -- (dérivation, poteau de liaison) restent dans la bande
    if part then
      local own, shared, own_coal = 0, 0, 0
      for _, e in ipairs(part.ents) do
        if e.coalnet then shared = shared + 1 else own = own + 1; if e.role == "charbon" then own_coal = own_coal + 1 end end
      end
      band_max = math.max(band_max, own)
      band_full_max = math.max(band_full_max, own + shared)
      if shared > 0 and own_coal == 0 then band_nocoal = band_nocoal + 1 end
    end
    -- une bande bâtie seule (les autres pas encore) marche seule : un réseau, chaque four nourri (minerai et charbon), plaques au quai
    if part and #part.ents > 0 then
      local r = Cv.verify(part, spp)
      if not (r.components <= 1 and r.unpowered == 0 and r.no_ore == 0 and r.no_coal == 0 and r.no_plate == 0 and r.junction == 0
        and r.mixed == 0 and r.arms == 0 and r.drops == 0) then
        lone_bad = lone_bad + 1
        print("    bande " .. bd.pr .. " seule : " .. Cv.line(r))
      end
      lone = lone + 1
    end
    for _, e in ipairs(part and part.ents or {}) do
      total = total + 1
      seen[sig(e)] = true
      if not in_full[sig(e)] and e.kind ~= "poteau" then bad = bad + 1 end
    end
  end
  local missing = 0
  for _, e in ipairs(full.ents) do if need[sig(e)] and not seen[sig(e)] then missing = missing + 1 end end
  return bad, total, missing
end
do
  for _, c in ipairs({ { "voie", { coal = COAL_NEAR } }, { "répartiteurs", { coal = COAL_NEAR, split = true } },
      { "coffre de tête", {} } }) do
    local bad, total, missing = stability(ORE, c[2])
    check(total > 0 and bad == 0, string.format("%s, bandes seules : %d entités, %d absentes du plan entier", c[1], total, bad))
    check(missing == 0, string.format("%s : toutes les pièces du plan entier (hors poteaux) posées par une bande (%d manquent)", c[1], missing))
  end
  check(lone > 0 and lone_bad == 0, string.format("bandes bâties seules : %d sur %d marchent seules (réseau, minerai, charbon, plaques)", lone - lone_bad, lone))
  check(band_max > 0 and band_max < 800, string.format("une bande sans le réseau commun du charbon : %d entités au plus (< 800)", band_max))
  -- (3/11) le réseau du charbon est posé par la première bande de son côté : bande AVEC le réseau commun < 800 entités aussi (critère E3)
  -- ÉCART ÉCRIT (3/11) : sur ce grand champ (disque de rayon 20, 11 colonnes, deux côtés), une bande qui a des colonnes des DEUX côtés porte les
  -- deux réseaux du charbon et dépasse 800 entités ; dans les parties (rayon de recherche 192), les bandes avec leur réseau restent à 560 au plus
  -- (lot2-271828182). Le critère E3 se juge en jeu ([FO-CHAMP] ... entites), pas ici.
  print(string.format("  ECART ECRIT : une bande avec le réseau commun du charbon : %d entités au plus (seuil de jeu 800)", band_full_max))
  check(band_nocoal == 0, string.format("une bande en voie garde sa dérivation et son poteau de liaison (%d sans)", band_nocoal))
  -- toute pièce commune du réseau du charbon est marquée (posée par le projet du réseau, pas par une bande)
  local full = Ch.plan(spec_of(ORE, { coal = COAL_NEAR }))
  local unmarked = 0
  for _, e in ipairs(full.ents) do if e.role == "charbon" and (e.band or 0) == 0 and not e.coalnet then unmarked = unmarked + 1 end end
  check(unmarked == 0, "pièces communes du réseau du charbon toutes marquées coalnet (" .. unmarked .. " sans)")
  -- cadre d'avant le lot (0.6.38, sans design) : la bande garde la fonderie à coffres
  local sp = spec_of(ORE, { coal = COAL_NEAR })
  sp.design = nil
  local old = Ch.plan(sp)
  check(old and old.frame.design == nil and count(old, function(e) return e.role == "combustible" end) > 0,
    "plan sans design : fonderie à coffres (coffres de combustible)")
  local fr = {}
  for k, v in pairs(old.frame) do fr[k] = v end
  fr.only = { [old.bands[1].pr] = true }
  local sp2 = spec_of(ORE, { coal = COAL_NEAR, frame = fr }) -- le runtime demande la colonne : le cadre figé l'emporte
  local part = Ch.plan(sp2)
  check(part and part.design == nil and count(part, function(e) return e.role == "charbon" end) == 0,
    "cadre 0.6.38 rejoué avec design colonne demandé : motif du cadre gardé (rien à migrer)")
end

---------------------------------------------------------------------------------------------------
section("5. determinisme")
---------------------------------------------------------------------------------------------------
do
  local function ser(p) local t = {}; for _, e in ipairs(p.ents) do t[#t + 1] = sig(e) end; return table.concat(t, ";") end
  local a = Ch.plan(spec_of(ORE, { coal = COAL_NEAR, split = true, ug = 5 }))
  local b = Ch.plan(spec_of(ORE, { coal = COAL_NEAR, split = true, ug = 5 }))
  check(a and b and ser(a) == ser(b), "deux plans identiques")
end

---------------------------------------------------------------------------------------------------
section("6. mutants")
---------------------------------------------------------------------------------------------------
--- Plan muté : copie des entités, `f` modifie la liste ; rend le rapport du contrôle.
local function mutate(base, f)
  local p = {}
  for k, v in pairs(base.p) do p[k] = v end
  p.ents = {}
  for _, e in ipairs(base.p.ents) do local c = {}; for k, v in pairs(e) do c[k] = v end; p.ents[#p.ents + 1] = c end
  f(p.ents)
  return Cv.verify(p, base.sp)
end
local function drop_first(list, pred)
  for i, e in ipairs(list) do if pred(e) then table.remove(list, i) return true end end
  return false
end
do
  local voie = plans["disque, charbon proche, sans logistique"]
  local split = plans["disque, répartiteurs"]
  local chest = plans["disque, sans charbon (coffre de tête)"]
  local muts = {
    { "tuile du charbon à la tête retirée", voie, function(l)
      local bdir
      for _, e in ipairs(l) do if e.role == "bande" and e.band == 1 and e.group == 1 then bdir = e.dir end end
      -- la seule tuile de la voie de charbon de la colonne qui est en travers du sens de la bande : celle qui charge la tête
      drop_first(l, function(e) return e.kind == "tapis" and e.role == "charbon" and e.band == 1 and e.group == 1 and (e.dir - bdir) % 4 == 2 end)
    end, function(r) return r.no_coal > 0 end },
    { "bras de dérivation retiré", voie, function(l) drop_first(l, function(e) return e.kind == "bras" and e.role == "charbon" end) end,
      function(r) return r.no_coal > 0 or r.unpowered > 0 end },
    { "bras de dérivation retiré (répartiteurs débloqués)", split, function(l) drop_first(l, function(e) return e.kind == "bras" and e.role == "charbon" end) end,
      function(r) return r.no_coal > 0 or r.unpowered > 0 end },
    { "tête droite (minerai sur les deux voies, charbon mêlé)", voie, function(l)
      for _, e in ipairs(l) do if e.role == "tete" then e.kind = "foreuse_absente" end end
      for _, e in ipairs(l) do if e.kind == "foreuse_absente" then e.kind = "rien" end end
      local i = 1
      while i <= #l do if l[i].kind == "rien" then table.remove(l, i) else i = i + 1 end end
      -- la bande entre tout droit dans la tête : une tuile de bande de plus dans l'axe
      for _, e in ipairs(l) do if e.role == "bande" and e.band == 1 and e.group == 1 then e.last_bande = true end end
      local last
      for _, e in ipairs(l) do if e.last_bande then last = e end end
      if last then
        local v = ({ [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } })[last.dir]
        -- prolonger la bande jusqu'à la tête
        for k = 1, 3 do
          local x, y = last.x + k * v[1], last.y + k * v[2]
          local occupied = false
          for _, q in ipairs(l) do if math.abs(q.x - x) < 0.6 and math.abs(q.y - y) < 0.6 and (q.size or 1) == 1 then occupied = true end end
          if not occupied then l[#l + 1] = { kind = "tapis", x = x, y = y, size = 1, dir = last.dir, band = 1, group = 1, role = "bande" } end
        end
      end
    end, function(r) return r.mixed > 0 or r.no_ore > 0 or r.no_coal > 0 or r.junction > 0 end },
    { "quai sans bras", voie, function(l)
      local b, g
      for _, e in ipairs(l) do if e.kind == "coffre" and e.role == "sortie" then b, g = e.band, e.group break end end
      local i = 1
      while i <= #l do
        local e = l[i]
        local is_bay = false
        if e.kind == "bras" and e.band == b and e.group == g then
          for _, q in ipairs(l) do
            if q.kind == "coffre" and q.role == "sortie" and math.abs(q.x - e.x) + math.abs(q.y - e.y) < 1.1 then is_bay = true end
          end
        end
        if is_bay then table.remove(l, i) else i = i + 1 end
      end
    end, function(r) return r.no_plate > 0 end },
    { "coffre de tête retiré", chest, function(l) drop_first(l, function(e) return e.kind == "coffre" and e.role == "combustible" end) end,
      function(r) return r.no_coal > 0 or r.arms > 0 end },
    { "souterrain de sortie retiré", plans["rivière avec souterrains"], function(l)
      drop_first(l, function(e) return e.kind == "souterrain" and e.ug == "output" end)
    end, function(r) return r.junction > 0 or r.no_coal > 0 end },
    { "poteaux du charbon retirés", voie, function(l)
      while drop_first(l, function(e) return e.kind == "poteau" and e.role == "charbon" end) do end
    end, function(r) return r.unpowered > 0 or r.components > 1 end },
  }
  for _, m in ipairs(muts) do
    if m[2] and m[2].p then
      local r = mutate(m[2], m[3])
      check(m[4](r), "mutant « " .. m[1] .. " » vu (" .. Cv.line(r) .. ")")
    else
      check(false, "mutant « " .. m[1] .. " » : plan de base absent")
    end
  end
  -- mutants de la RÈGLE : la règle fautive doit être vue par le contrôle
  local function rule_mutant(name, apply, restore, o, pred)
    apply()
    local ok, sp, p = pcall(function() local s = spec_of(ORE, o); return s, Ch.plan(s) end)
    restore()
    if not ok then check(true, "mutant de règle « " .. name .. " » : la règle lève une erreur") return end
    local seen = (p == nil) or pred(Cv.verify(p, sp), p)
    check(seen, "mutant de règle « " .. name .. " » vu")
  end
  local pk = Co.PICKUP
  rule_mutant("quai compté à 10 objets par bras", function() Co.PICKUP = 10 end, function() Co.PICKUP = pk end, { coal = COAL_NEAR },
    function(_, p)
      local fours, bay = 0, 0
      for _, e in ipairs(p.ents) do if e.kind == "four" then fours = fours + 1 elseif e.kind == "coffre" and e.role == "sortie" then bay = bay + 1 end end
      return bay * 0.83 * 0.85 < fours * 0.3125
    end)
  local lay = Co.layout
  rule_mutant("tête sans chargement du charbon", function()
    Co.layout = function(...)
      local l, n, i = lay(...)
      if l then for k = #l, 1, -1 do if l[k].role == "charbon" and l[k].col == 1 then table.remove(l, k) end end end
      return l, n, i
    end
  end, function() Co.layout = lay end, { coal = COAL_NEAR }, function(r) return r.no_coal > 0 end)
  local rt = Co.route
  rule_mutant("souterrain au-delà de la portée", function()
    Co.route = function(s, sd, t, td, free, span, ug, box, cap) return rt(s, sd, t, td, free, span, ug and (ug + 3), box, cap) end
  end, function() Co.route = rt end, { coal = disc(60, 0, 8), blocked = (function()
    local rv = {}; for x = 36, 42 do for y = -400, 400 do rv[Ch.key(x, y)] = true end end; return rv end)(), ug = 5 },
    function(r) return r.junction > 0 or r.no_coal > 0 end)
  local br = Co.branch
  rule_mutant("dérivation qui s'arrête avant le tronc", function()
    Co.branch = function(col, net, side, wire) local l = br(col, net, side, wire); table.remove(l, 1); return l end
  end, function() Co.branch = br end, { coal = COAL_NEAR }, function(r) return r.no_coal > 0 end)
end

---------------------------------------------------------------------------------------------------
section("7. decoupe d'une bande trop grosse et foreuse sautee (dernier tour du 3/11)")
---------------------------------------------------------------------------------------------------
do
  local Sa = require("shared.team.champ_saut")
  check(#Sa.split(300, { { -1, 200 }, { 1, 250 } }, 800) == 0, "750 entités : aucun report")
  local d = Sa.split(500, { { -1, 200 }, { 1, 250 } }, 800)
  check(#d == 1 and d[1] == 1, "950 entités : le plus gros réseau (côté +, 250) reporté, la bande reste à 700")
  local d2 = Sa.split(700, { { -1, 200 }, { 1, 250 } }, 800)
  check(#d2 == 2 and d2[1] == -1 and d2[2] == 1, "1 150 entités : les deux réseaux reportés")
  local d3 = Sa.split(900, {}, 800)
  check(#d3 == 0, "bande propre de 900 sans réseau : rien à reporter")
  -- sur le grand champ du test : chaque bande seule, une fois ses réseaux reportés, sous 800 ; chaque réseau reporté sous 800
  local full = Ch.plan(spec_of(ORE, { coal = COAL_NEAR }))
  local worst, worst_net = 0, 0
  for _, bd in ipairs(full.bands) do
    local fr = {}
    for _, k in ipairs({ "axis", "phase", "exit", "origin", "umin", "umax", "v0", "offsets", "design", "cols", "coal" }) do fr[k] = full.frame[k] end
    fr.only = { [bd.pr] = true }
    local part = Ch.plan(spec_of(ORE, { coal = COAL_NEAR, frame = fr }))
    if part then
      local own, by = 0, {}
      for _, e in ipairs(part.ents) do if e.coalnet then by[e.coalnet] = (by[e.coalnet] or 0) + 1 else own = own + 1 end end
      local sh = {}
      for _, sd in ipairs({ -1, 1 }) do if by[sd] then sh[#sh + 1] = { sd, by[sd] } end end
      local def = Sa.split(own, sh, 800)
      local kept = own
      local gone = {}
      for _, sd in ipairs(def) do gone[sd] = true end
      for _, x in ipairs(sh) do if gone[x[1]] then worst_net = math.max(worst_net, x[2]) else kept = kept + x[2] end end
      worst = math.max(worst, kept)
    end
  end
  check(worst > 0 and worst <= 800, string.format("grand champ : bande après report %d entités au plus (<= 800)", worst))
  check(worst_net <= 800, string.format("grand champ : réseau reporté %d entités au plus (<= 800)", worst_net))
  -- foreuse sautée : toute foreuse de bande refusée pour la 3e fois, quoi qu'occupe son emprise (CHAMP-OBSTACLES, 11/11)
  local T1 = { { own_turret = true } }
  check(Sa.skip("champ-foreuse", "occupe", 2, T1, 3) == true, "3e refus sous une tourelle de l'équipe : foreuse sautée")
  check(Sa.skip("champ-foreuse", "occupe", 1, T1, 3) == false, "2e refus : pas encore")
  check(Sa.skip("champ-foreuse", "occupe", 2, { { own_turret = true }, { own_turret = false } }, 3) == true, "tourelle et autre bâtiment : sautée (CHAMP-OBSTACLES)")
  check(Sa.skip("champ-foreuse", "occupe", 2, { { own_turret = false } }, 3) == true, "tourelle d'une autre force ou bâtiment : sautée (CHAMP-OBSTACLES)")
  check(Sa.skip("champ-foreuse", "occupe", 2, {}, 3) == true, "rien de lu sous l'emprise : sautée (CHAMP-OBSTACLES)")
  check(Sa.skip("champ-charbon", "occupe", 2, T1, 3) == false, "foreuse de la ligne de charbon : jamais sautée")
  check(Sa.skip("champ-foreuse", "obstacle", 2, T1, 3) == true, "arbre résiduel (obstacle) au 3e refus : sautée (CHAMP-OBSTACLES)")
  -- mutants de la règle
  local sk = Sa.skip
  Sa.skip = function(role, reason, fails, bl, lim) return role == "champ-foreuse" and reason == "occupe" end
  check(Sa.skip("champ-foreuse", "occupe", 0, T1, 3) ~= false, "mutant « sans attendre 3 refus » vu (il saute au 1er refus)")
  Sa.skip = sk
  local spl = Sa.split
  Sa.split = function() return {} end
  check(#Sa.split(700, { { -1, 200 }, { 1, 250 } }, 800) == 0, "mutant « jamais de report » vu (1 150 entités gardées)")
  Sa.split = spl
end

---------------------------------------------------------------------------------------------------
section("8. colonne refusee au lieu du coffre de tete (cadre neuf, 0.6.43)")
---------------------------------------------------------------------------------------------------
Ch.CFG.refuse_coffre = true
do
  local function chests(p) return p and count(p, function(e) return e.kind == "coffre" and e.role == "combustible" end) or 0 end
  -- rivière sans souterrain : aucune colonne ne reçoit de voie ; toutes refusées, aucun coffre de tête
  local river = {}
  for x = 36, 38 do for y = -400, 400 do river[Ch.key(x, y)] = true end end
  local spn = spec_of(ORE, { coal = disc(60, 0, 8), blocked = river })
  local pn = Ch.plan(spn)
  -- (décision du lead, 3/11) refuser coûterait tout le champ : le cadre garde ses colonnes au coffre de tête (0.6.42), coût écrit
  check(pn ~= nil and chests(pn) > 0 and pn.coffre_cost == 100 and pn.refused == nil,
    string.format("rivière sans souterrain : refus à %s %% -> cadre à coffres (%d coffres de tête)", tostring(pn and pn.coffre_cost), chests(pn)))
  local refusee = 0
  for _, sides in pairs(pn and pn.frame.cols or {}) do for _, fc in pairs(sides) do if fc.mode == "refusee" then refusee = refusee + 1 end end end
  check(refusee == 0, "cadre à coffres : aucune colonne notée « refusee » au cadre (" .. refusee .. ")")
  local rb, rt, rm = stability(ORE, { coal = disc(60, 0, 8), blocked = river })
  check(rt > 0 and rb == 0 and rm == 0, string.format("cadre à coffres, bandes seules : %d entités, %d absentes du plan entier, %d manquent", rt, rb, rm))
  -- règle pure du seuil (Ch.CFG.refuse_min = 0,5) : cas azure (champ-longue 20261020 : 41 foreuses -> 4), 3 colonnes sur 4, 1 sur 10
  local k1, c1 = Ch.refuse_keeps(41, 4)
  local k2, c2 = Ch.refuse_keeps(4, 1)
  local k3, c3 = Ch.refuse_keeps(10, 9)
  local k4 = Ch.refuse_keeps(10, 5)
  check(not k1 and c1 == 90 and not k2 and c2 == 75 and k3 and c3 == 10 and k4,
    string.format("seuil 50 %% : azure 41->4 repli (%d %%), 3 sur 4 repli (%d %%), 1 sur 10 refus (%d %%), 5 sur 10 refus", c1, c2, c3))
  -- charbon trop petit pour tout le côté : les colonnes nourries gardent la voie, les autres sont refusées (moins de colonnes)
  local o = { coal = disc(70, 50, 10), drill = { size = 5, reach = 1, rate = 1 }, fs = 3 }
  local spp = spec_of(disc(0, 0, 26), o)
  local pp = Ch.plan(spp)
  local voie = 0
  for _, cs in ipairs(pp and pp.stats.coal or {}) do if cs.voie then voie = voie + 1 end end
  check(pp ~= nil and chests(pp) == 0 and voie >= 1, string.format("charbon trop petit : %d côté(s) en voie, 0 coffre de tête (%d)", voie, chests(pp)))
  check(pp and pp.refused and #pp.refused >= 1, "charbon trop petit : au moins une colonne refusée (" .. tostring(pp and pp.refused and #pp.refused) .. ")")
  local why_ok, noted = true, 0
  for _, x in ipairs(pp and pp.refused or {}) do
    if not (x.why and #x.why > 0) then why_ok = false end
    local fc = pp.frame.cols[tostring(x.pr)] and pp.frame.cols[tostring(x.pr)][tostring(x.side)]
    if fc and fc.mode == "refusee" then noted = noted + 1 end
  end
  check(why_ok and noted == #(pp and pp.refused or {}), "colonnes refusées : raison écrite et notées « refusee » au cadre (" .. noted .. ")")
  if pp then
    local r = Cv.verify(pp, spp)
    check(r.no_coal == 0 and r.no_ore == 0 and r.no_plate == 0, "charbon trop petit : chaque four restant a minerai et charbon, plaques au quai (" .. Cv.line(r) .. ")")
    local fv, cd = count(pp, function(e) return e.kind == "four" end), count(pp, function(e) return e.kind == "foreuse" and e.role == "charbon" end)
    check(cd * spp.coal.rate + 1e-9 >= fv * spp.furnace.fuel_rate, string.format("la ligne (%.2f/s) nourrit tous les fours restants (%.2f/s)",
      cd * spp.coal.rate, fv * spp.furnace.fuel_rate))
  end
  -- bandes seules rejouées du cadre : mêmes pièces que le plan entier, aucune colonne refusée posée, aucun coffre de tête
  local bad, total, missing = stability(disc(0, 0, 26), o)
  check(total > 0 and bad == 0 and missing == 0, string.format("refus, bandes seules : %d entités, %d absentes du plan entier, %d manquent", total, bad, missing))
  local band_chests = 0
  for _, bd in ipairs(pp and pp.bands or {}) do
    local fr = {}
    for k, v in pairs(pp.frame) do fr[k] = v end
    fr.only = { [bd.pr] = true }
    local oo = {}
    for k, v in pairs(o) do oo[k] = v end
    oo.frame = fr
    band_chests = band_chests + chests(Ch.plan(spec_of(disc(0, 0, 26), oo)))
  end
  check(band_chests == 0, "refus, bandes seules : aucun coffre de tête (" .. band_chests .. ")")
  -- déterminisme et mutant (règle coupée : le coffre de tête revient)
  local pp2 = Ch.plan(spec_of(disc(0, 0, 26), o))
  local same = pp and pp2 and #pp.ents == #pp2.ents
  for i = 1, (same and #pp.ents or 0) do if sig(pp.ents[i]) ~= sig(pp2.ents[i]) then same = false end end
  check(same, "refus : deux plans identiques")
  Ch.CFG.refuse_coffre = false
  local pm = Ch.plan(spec_of(disc(0, 0, 26), o))
  Ch.CFG.refuse_coffre = true
  check(chests(pm) > 0, "mutant « refus coupé » vu : le coffre de tête revient (" .. chests(pm) .. ")")
  check(pp and pp.refuse_cost == 30 and pp.coffre_cost == nil, "charbon trop petit : refus gardé, il coûte " .. tostring(pp and pp.refuse_cost) .. " % (< 50 %)")
  -- mutants du seuil : 0 (toujours refuser) -> la rivière perd ses coffres ; > 1 (jamais refuser) -> le charbon trop petit garde les siens
  Ch.CFG.refuse_min = 0
  local m1 = Ch.plan(spec_of(ORE, { coal = disc(60, 0, 8), blocked = river }))
  Ch.CFG.refuse_min = 1.01
  local m2 = Ch.plan(spec_of(disc(0, 0, 26), o))
  Ch.CFG.refuse_min = 0.5
  check(chests(m1) == 0 and chests(m2) > 0, string.format("mutants du seuil vus (toujours refuser : %d coffres ; jamais : %d)", chests(m1), chests(m2)))
end

---------------------------------------------------------------------------------------------------
section("9. ordre des cotes du reseau du charbon (revue-fonderie, 3/11)")
---------------------------------------------------------------------------------------------------
do
  -- règle pure du choix
  local function fake(chests, drills)
    local ents = {}
    for _ = 1, chests do ents[#ents + 1] = { kind = "coffre", role = "combustible" } end
    for _ = 1, drills do ents[#ents + 1] = { kind = "foreuse" } end
    return { ents = ents }
  end
  check(Ch.better_order(fake(4, 38), fake(0, 33)) and not Ch.better_order(fake(0, 33), fake(4, 38)), "moins de coffres de tete d'abord (0 contre 4, meme avec moins de foreuses)")
  check(Ch.better_order(fake(0, 30), fake(0, 31)) and not Ch.better_order(fake(0, 31), fake(0, 31)), "a coffres egaux, plus de foreuses ; egalite : l'ordre habituel")
  check(Ch.better_order(nil, fake(0, 1)) and not Ch.better_order(fake(0, 1), nil), "plan absent")
  -- cadre réel relevé en jeu (scarlet, avant-poste 3, fer, verif-guide 20261020 sur 0.6.43 : côté + « aucun chemin », 4 coffres de tête)
  local function split(str, sep)
    local out = {}
    if str == nil or str == "" then return out end
    for part in (str .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
    return out
  end
  local function nums(str) local out = {} for _, x in ipairs(split(str, ",")) do out[#out + 1] = tonumber(x) end return out end
  local function set(str) local out = {} for _, x in ipairs(split(str, ",")) do out[tonumber(x)] = true end return out end
  local function load_spec(path)
    local h = assert(io.open(path, "r"))
    local line = h:read("*l")
    h:close()
    local fl = {}
    for _, kv in ipairs(split(line, "|")) do local k, v = kv:match("^([%w_]+)=(.*)$"); if k then fl[k] = v end end
    return function()
    local d, pl, fu, tg = nums(fl.drill), nums(fl.pole), split(fl.furnace, ","), nums(fl.target)
    local belts = {}
    for _, x in ipairs(split(fl.belts, ";")) do belts[#belts + 1] = { lane = tonumber(x) } end
    return { ore = nums(fl.ore), blocked = set(fl.blocked), mine = set(fl.mine), soft = fl.soft ~= "" and set(fl.soft) or nil,
      drill = { size = d[1], reach = d[2], rate = d[3] }, pole = { reach = pl[1], wire = pl[2] }, belts = belts,
      furnace = { size = tonumber(fu[1]), rate = tonumber(fu[2]), fuel = fu[3] == "true", fuel_rate = tonumber(fu[4]) },
      inserter = { rate = tonumber(fl.ins) }, target = { x = tg[1], y = tg[2] }, max_side = tonumber(fl.max_side), design = "colonne",
      logistics = { underground = tonumber(fl.ug), splitter = fl.splitter == "true" }, coal = { tiles = nums(fl.coal), rate = tonumber(fl.coalrate) },
      ug_tiles = {} }
    end
  end
  local scarlet = load_spec("tests/fixtures/champ_spec_scarlet_20261020.txt")
  local player = load_spec("tests/fixtures/champ_spec_player_271828182.txt")
  local ps = Ch.plan(scarlet())
  check(ps ~= nil and Ch.head_chests(ps) == 0 and ps.order_swapped and ps.order_swapped.chests == 4,
    string.format("scarlet 20261020 : 0 coffre de tete (%s ; avant : %s)", tostring(ps and Ch.head_chests(ps)), tostring(ps and ps.order_swapped and ps.order_swapped.chests)))
  check(ps and Ch.field_drills(ps) >= 0.8 * ps.order_swapped.drills, string.format("scarlet : au moins 80 %% des foreuses gardees (%d sur %d)",
    ps and Ch.field_drills(ps) or 0, ps and ps.order_swapped and ps.order_swapped.drills or 0))
  local r = ps and Cv.verify(ps, scarlet())
  check(r and r.no_coal == 0 and r.no_ore == 0 and r.no_plate == 0, "scarlet : chaque four a minerai et charbon, plaques au quai (" .. (r and Cv.line(r) or "?") .. ")")
  -- bandes seules rejouées du cadre (le réseau du charbon est rejoué du cadre, sans dépendre de l'ordre)
  local in_full, bad, total, chests = {}, 0, 0, 0
  for _, e in ipairs(ps and ps.ents or {}) do in_full[sig(e)] = true end
  for _, bd in ipairs(ps and ps.bands or {}) do
    local fr = {}
    for k, v in pairs(ps.frame) do fr[k] = v end
    fr.only = { [bd.pr] = true }
    local sp = scarlet()
    sp.frame = fr
    local part = Ch.plan(sp)
    for _, e in ipairs(part and part.ents or {}) do
      total = total + 1
      if not in_full[sig(e)] and e.kind ~= "poteau" then bad = bad + 1 end
    end
    chests = chests + Ch.head_chests(part)
  end
  check(total > 0 and bad == 0 and chests == 0, string.format("scarlet, bandes seules : %d entites, %d absentes du plan entier, %d coffres de tete", total, bad, chests))
  -- un cadre sans repli ne change pas (pas d'autre ordre essayé)
  local pv = Ch.plan(spec_of(ORE, { coal = COAL_NEAR }))
  check(pv and pv.order_swapped == nil and Ch.head_chests(pv) == 0, "cadre en voie des deux cotes : ordre habituel garde")
  -- mutant : option coupée -> les 4 coffres de tête reviennent
  Ch.CFG.both_orders = false
  local pm = Ch.plan(scarlet())
  Ch.CFG.both_orders = true
  check(Ch.head_chests(pm) == 4, "mutant « un seul ordre » vu : 4 coffres de tete (" .. Ch.head_chests(pm) .. ")")
  -- cadre réel du joueur (avant-poste 1, fer, verif-guide 271828182 sur 0.6.43 : côté - « aucun chemin » dans les deux ordres, 5 coffres de
  -- tête, refus à 84 %) : la sortie de sa ligne de charbon était enfermée (ses foreuses de chaque côté, une case bloquée devant)
  local pp2 = Ch.plan(player())
  local voies = 0
  for _, cs in ipairs(pp2 and pp2.stats.coal or {}) do if cs.voie then voies = voies + 1 end end
  check(pp2 and Ch.head_chests(pp2) == 0 and voies == 2 and not (pp2.refused and #pp2.refused > 0) and Ch.field_drills(pp2) == 66,
    -- F555 : 66 (63 avant : le second bout prend tout le reste, le premier les foreuses que le second ne joint pas)
    string.format("joueur 271828182 : charbon par tapis des deux cotes, 0 coffre de tete, 66 foreuses (%s, %d voie(s), %d)", tostring(pp2 and Ch.head_chests(pp2)), voies,
      pp2 and Ch.field_drills(pp2) or -1))
  local r2 = pp2 and Cv.verify(pp2, player())
  check(r2 and r2.no_coal == 0 and r2.no_ore == 0 and r2.no_plate == 0, "joueur : chaque four a minerai et charbon (" .. (r2 and Cv.line(r2) or "?") .. ")")
  -- mutant : sans la préférence pour une sortie ouverte (Co.coal_line d'origine), les 5 coffres de tête reviennent
  local Co2src = io.open("shared/team/champ_colonne.lua"):read("*a")
  local ms, nm = Co2src:gsub("    if x%.open ~= y%.open then return x%.open end%c", "", 1)
  assert(nm == 1, "mutant introuvable")
  local Cm = assert(load(ms))()
  local keep = Co.coal_line
  Co.coal_line = Cm.coal_line
  local pmut = Ch.plan(player())
  Co.coal_line = keep
  check(Ch.head_chests(pmut) == 5, "mutant « sortie enfermee acceptee » vu : 5 coffres de tete (" .. Ch.head_chests(pmut) .. ")")
end

---------------------------------------------------------------------------------------------------
section("10. refus « sans place de fonderie » : la première tuile prise est donnée (9/11, partie 314159265, bande de fer de votre équipe)")
---------------------------------------------------------------------------------------------------
do
  local ore10 = {}
  for x = -12, 12 do for y = -8, 8 do if (x / 12) ^ 2 + (y / 8) ^ 2 <= 1 then ore10[#ore10 + 1] = x; ore10[#ore10 + 1] = y end end end
  local free10 = Ch.plan(spec_of(ore10, {}))
  check(free10 ~= nil and #free10.ents > 0 and free10.stats.no_smelter == 0 and free10.stats.no_smelter_at == nil, "champ libre : des entités, aucun groupe sans fonderie, aucune tuile signalée")
  local wall10 = {}
  for x = -80, 80 do for y = -80, 80 do
    if not (x >= -16 and x <= 16 and y >= -11 and y <= 11) then wall10[Ch.key(x, y)] = true end
  end end
  local p10 = Ch.plan(spec_of(ore10, { blocked = wall10 }))
  local at = p10 and p10.stats.no_smelter_at
  check(p10 ~= nil and #p10.ents == 0 and p10.stats.no_smelter >= 1 and (p10.stats.band_drills or 0) > 0, "champ muré : bande vide, des foreuses possibles, des groupes sans fonderie")
  check(at ~= nil and at.fixed == false and (math.abs(at.x) > 16 or math.abs(at.y) > 11) and at.band ~= nil and (at.side == 1 or at.side == -1),
    "la première tuile prise est donnée, dans le mur (" .. (at and string.format("%.1f, %.1f", at.x, at.y) or "aucune") .. ")")
  -- déterminisme du diagnostic
  local p10b = Ch.plan(spec_of(ore10, { blocked = wall10 }))
  check(p10b.stats.no_smelter_at.x == at.x and p10b.stats.no_smelter_at.y == at.y, "diagnostic déterministe")
end

---------------------------------------------------------------------------------------------------
section("11. F555 : la boite d'extraction couvre le minerai, la fonderie se dimensionne a part (DC, partie 0.7.3)")
---------------------------------------------------------------------------------------------------
do
  -- partie du DC en 0.7.3 : « 2 foreuses sur toute la largeur d'un gisement géant » ; maillon : take_group bornait chaque groupe au
  -- débit d'une colonne de fours (max_side par côté, une voie du tapis pour la colonne à combustible) et la bande n'a que deux bouts : le
  -- milieu d'un gisement large restait nu (156 foreuses posées sur 527 possibles ici)
  local Fd = require("shared.team.champ_fonderie")
  local wide = {}
  for x = 0, 149 do for y = 0, 39 do wide[#wide + 1] = x; wide[#wide + 1] = y end end
  local spw = spec_of(wide, { coal = disc(-60, 20, 10), belts = { { lane = 7.5 } } })
  local pw = Ch.plan(spw)
  local possible = pw and pw.stats.band_drills or 0
  check(pw ~= nil and possible > 0 and pw.stats.capped == 0 and Ch.field_drills(pw) == possible,
    string.format("F555 : gisement de 150 x 40, toutes les foreuses des rangees posees (%d sur %d)", pw and Ch.field_drills(pw) or -1, possible))
  -- les fours : dimensionnés sur ce que le tapis livre (une voie jaune, le charbon sur l'autre), jamais sur le nombre de foreuses
  local cap24, ok_f, groups = Fd.furnaces_for(7.5, spw.furnace.rate), true, 0
  for _, bd in ipairs(pw and pw.bands or {}) do for _, g in ipairs(bd.groups) do
    groups = groups + 1
    if g.count ~= Fd.count(spw, math.min(g.drills * spw.drill.rate, 7.5)) or g.count > cap24 then ok_f = false end
  end end
  check(groups > 0 and ok_f, "F555 : fours de chaque groupe = debit livre par le tapis (" .. cap24 .. " au plus a la voie jaune)")
  -- aucun four, coffre ou bras de la fonderie sur le minerai (F500)
  local ore_set, on_ore = {}, 0
  for i = 1, #wide - 1, 2 do ore_set[Ch.key(wide[i], wide[i + 1])] = true end
  for _, e in ipairs(pw and pw.ents or {}) do
    if e.kind == "four" and ore_set[Ch.key(math.floor(e.x - e.size / 2), math.floor(e.y - e.size / 2))] then on_ore = on_ore + 1 end
  end
  check(on_ore == 0, "F555 : aucun four sur le minerai (" .. on_ore .. ")")
  -- un mur en travers des tapis près du second bout (ligne posée, x = 6) : le second bout ne joint que les foreuses d'avant le mur ; le
  -- premier prend TOUTES celles d'après, au-delà de son partage habituel
  local wall6 = {}
  for y = -20, 60 do wall6[Ch.key(6, y)] = true end
  local spm = spec_of(wide, { coal = disc(-60, 20, 10), belts = { { lane = 7.5 } }, blocked = wall6 })
  local pm = Ch.plan(spm)
  check(pm ~= nil and pm.stats.band_drills > 0 and pm.stats.capped == 0,
    string.format("F555 : mur en travers des tapis, aucune foreuse ecartee (%d sur %d)", pm and Ch.field_drills(pm) or -1, pm and pm.stats.band_drills or 0))
end

print(string.format("[CHAMP-COLONNE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
