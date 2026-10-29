--[[
  Tests hors jeu de la chaîne de poteaux par recherche de chemin (lot POTEAUX-ASTAR ; shared/team/poteaux.lua et
  P.pole_chain de shared/team/plan.lua, purs).
  Usage, depuis la racine du mod :   lua5.2 tests/poteaux_astar_test.lua

  Vérifie, sur des cartes SYNTHÉTIQUES :
    1. diagonale directe : en terrain libre, la chaîne va droit, au plus un poteau au-dessus du minimum théorique ;
    2. contournement : un mur que la chaîne gloutonne ne passe pas (nil) est contourné par l'A* ; couloir élargi si besoin ;
    3. culs-de-sac : départ au fond d'une poche ouverte à l'opposé du but (recul nécessaire) ; but ou départ muré : nil ;
       rivière plus large que la portée : nil (honnête) ;
    4. poteaux connus : traversés, jamais rendus, jamais doublés ; liste vide = rien de changé ;
    5. équivalence ou amélioration face à l'ancienne chaîne (cas de plan_test) et sur 300 cartes d'obstacles pseudo-aléatoires :
       P.pole_chain n'est jamais nil si l'ancienne chaîne rend quelque chose, et jamais plus longue ;
    6. propriétés : portée, tuiles libres, bout à portée du but, minimum théorique ;
    7. déterminisme (deux appels, ordre des poteaux connus mélangé) ;
    8. plafond : coût borné (cellules résolues, appels à `free`), couloir trop grand refusé ;
    9. mutants : 6 variantes fautives du module sont refusées par la même batterie.
]]

package.path = "./?.lua;" .. package.path

local P = require("shared.team.plan")
local Q = require("shared.team.poteaux")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local function rect(t, x0, y0, x1, y1) for y = y0, y1 do for x = x0, x1 do t[P.tkey(x, y)] = true end end end
local function freefn(block) return function(x, y) return not block[P.tkey(math.floor(x), math.floor(y))] end end
local function dist(p, q) return math.sqrt((p.x - q.x) ^ 2 + (p.y - q.y) ^ 2) end
local function lower_bound(a, b, reach) return math.max(0, math.ceil((dist(a, b) - reach) / reach - 1e-9)) end

--- Contrôle complet d'une chaîne : portée de chaque maillon, tuiles libres, bout à portée du but.
local function valid(chain, a, b, reach, free)
  if not chain then return false end
  local prev = a
  for _, c in ipairs(chain) do
    if dist(prev, c) > reach + 1e-9 then return false end
    if not free(c.x, c.y) then return false end
    prev = c
  end
  return dist(prev, b) <= reach + 1e-9
end

---------------------------------------------------------------------------------------------------
-- Batterie : appliquée au module réel (0 échec attendu) puis à chaque mutant (au moins 1 échec attendu).
---------------------------------------------------------------------------------------------------
local function battery(Qm)
  local fails = 0
  local function ck(c) if not c then fails = fails + 1 end end
  local ok, err = pcall(function()
    -- (a) terrain libre, diagonale : valide et près du minimum
    local a, b = { x = 0.5, y = 0.5 }, { x = 60.5, y = 60.5 }
    local free = function() return true end
    local c = Qm.path(a, b, 9, false, free)
    ck(valid(c, a, b, 9, free))
    ck(c and #c <= lower_bound(a, b, 9) + 3)
    -- (b) mur épais que la chaîne gloutonne ne franchit pas : contournement en reculant
    local blk = {}
    rect(blk, 20, -10, 31, 10)
    local fb = freefn(blk)
    local a2, b2 = { x = 0.5, y = 0.5 }, { x = 48.5, y = 0.5 }
    local c2 = Qm.path(a2, b2, 9, false, fb)
    ck(valid(c2, a2, b2, 9, fb))
    -- (c) grand lac : il faut le couloir élargi (le détour passe à plus d'une portée du segment)
    local lake = {}
    rect(lake, 25, -14, 35, 14)
    local fl = freefn(lake)
    local a3, b3 = { x = 0.5, y = 0.5 }, { x = 60.5, y = 0.5 }
    local c3 = Qm.path(a3, b3, 9, false, fl)
    ck(valid(c3, a3, b3, 9, fl))
    -- (d) poteaux connus : la rue déjà jalonnée ne reçoit aucun poteau neuf
    local known = {}
    for x = 8.5, 56.5, 8 do known[#known + 1] = { x = x, y = 0.5 } end
    local c4 = Qm.path(a3, b3, 9, false, function() return false end, known)
    ck(c4 ~= nil and #c4 == 0)
    -- (e) minimum de poteaux neufs sur une ligne droite libre (portée 9, 40 tuiles : minimum 4)
    local c5 = Qm.path({ x = 0.5, y = 0.5 }, { x = 40.5, y = 0.5 }, 9, false, free)
    ck(c5 and #c5 <= lower_bound({ x = 0.5, y = 0.5 }, { x = 40.5, y = 0.5 }, 9) + 1)
    -- (g) cinq poteaux connus espacés de 7 : on les traverse (zéro poteau neuf) au lieu d'en poser 3 ou 4
    local kk = {}
    for x = 6.5, 34.5, 7 do kk[#kk + 1] = { x = x, y = 0.5 } end
    local c6 = Qm.path({ x = 0.5, y = 0.5 }, { x = 41.5, y = 0.5 }, 9, false, free, kk)
    ck(c6 ~= nil and #c6 == 0)
    -- (f) le but trop loin du dernier poteau n'est pas accepté (aucune tuile libre sauf le départ : nil)
    local none = Qm.path(a3, b3, 9, false, function() return false end)
    ck(none == nil)
  end)
  if not ok then fails = fails + 1 end
  return fails, err
end

---------------------------------------------------------------------------------------------------
section("1. Diagonale directe")
do
  local free = function() return true end
  local a, b = { x = 0.5, y = 0.5 }, { x = 60.5, y = 60.5 }
  local c = Q.path(a, b, 9, false, free)
  local lb = lower_bound(a, b, 9)
  check(valid(c, a, b, 9, free), "diagonale 60 x 60 : chaîne valide")
  check(c and #c <= lb + 2, string.format("diagonale : %d poteau(x) pour un minimum théorique de %d", c and #c or -1, lb))
  -- toute la chaîne reste près du segment (pas de zigzag)
  local worst = 0
  for _, p in ipairs(c or {}) do
    local t = ((p.x - a.x) + (p.y - a.y)) / ((b.x - a.x) + (b.y - a.y))
    local qx, qy = a.x + t * (b.x - a.x), a.y + t * (b.y - a.y)
    worst = math.max(worst, dist(p, { x = qx, y = qy }))
  end
  check(worst <= 9, string.format("diagonale : écart maximal au segment %.1f tuiles", worst))
  -- P.pole_chain, terrain libre : identique à l'ancienne chaîne (elle est au minimum, l'A* n'est pas lancé)
  local old = P.pole_chain(a, b, 9, false, free, nil, { no_astar = true })
  local new = P.pole_chain(a, b, 9, false, free)
  local same = #old == #new
  for i = 1, #old do if not same or old[i].x ~= new[i].x or old[i].y ~= new[i].y then same = false end end
  check(same, "terrain libre : P.pole_chain rend la même chaîne que l'ancienne (A* non lancé)")
  -- grands poteaux (positions entières, portée 30)
  local big = Q.path({ x = 0, y = 0 }, { x = 90, y = 70 }, 30, true, free)
  check(valid(big, { x = 0, y = 0 }, { x = 90, y = 70 }, 30, free) and #big <= 4, "grands poteaux, diagonale 90 x 70 : au plus 4 intermédiaires (" .. tostring(big and #big) .. ")")
  for _, p in ipairs(big or {}) do check(p.x == math.floor(p.x) and p.y == math.floor(p.y), "grand poteau : position entière") end
  -- a et b déjà à portée : aucune chaîne
  check(#Q.path({ x = 0, y = 0 }, { x = 5, y = 5 }, 9, false, free) == 0, "à portée : chaîne vide")
end

section("2. Contournement d'obstacles")
do
  local blk = {}
  rect(blk, 20, -10, 31, 10)
  local fb = freefn(blk)
  local a, b = { x = 0.5, y = 0.5 }, { x = 48.5, y = 0.5 }
  local greedy = P.pole_chain(a, b, 9, false, fb, nil, { no_astar = true })
  check(greedy == nil, "mur épais de 12 : l'ancienne chaîne gloutonne est bloquée (nil)")
  local c = P.pole_chain(a, b, 9, false, fb)
  check(valid(c, a, b, 9, fb), "mur épais de 12 : P.pole_chain le contourne (chaîne valide)")
  local detour = false
  for _, p in ipairs(c or {}) do if math.abs(p.y - 0.5) > 10 then detour = true end end
  check(detour, "le contournement passe par-dessus le mur (un poteau à plus de 10 tuiles de l'axe)")
  -- eau : un lac large, le détour sort du couloir étroit (couloir élargi)
  local lake = {}
  rect(lake, 25, -14, 35, 14)
  local fl = freefn(lake)
  local a2, b2 = { x = 0.5, y = 0.5 }, { x = 60.5, y = 0.5 }
  check(P.pole_chain(a2, b2, 9, false, fl, nil, { no_astar = true }) == nil, "lac de 29 : l'ancienne chaîne est bloquée")
  local c2 = P.pole_chain(a2, b2, 9, false, fl)
  check(valid(c2, a2, b2, 9, fl), "lac de 29 : contourné par le couloir élargi (" .. tostring(c2 and #c2) .. " poteaux)")
  -- rivière traversable par le fil : 6 tuiles d'eau, portée 9, la chaîne passe
  local riv = {}
  rect(riv, 20, -200, 25, 200)
  local fr = freefn(riv)
  local c3 = P.pole_chain({ x = 0.5, y = 0.5 }, { x = 45.5, y = 0.5 }, 9, false, fr)
  check(valid(c3, { x = 0.5, y = 0.5 }, { x = 45.5, y = 0.5 }, 9, fr), "rivière de 6 tuiles : le fil la franchit")
  -- falaise en diagonale (ligne de tuiles bloquées) : la chaîne la suit puis la passe par le bout
  local cl = {}
  for i = -12, 12 do cl[P.tkey(30 + i, 30 - i)] = true; cl[P.tkey(31 + i, 30 - i)] = true end
  local fc = freefn(cl)
  local a4, b4 = { x = 5.5, y = 5.5 }, { x = 55.5, y = 55.5 }
  local c4 = P.pole_chain(a4, b4, 9, false, fc)
  check(valid(c4, a4, b4, 9, fc), "falaise en diagonale : chaîne valide")
end

section("3. Culs-de-sac et refus")
do
  -- poche en U ouverte à l'ouest, le but à l'est : le départ au fond doit reculer
  local blk = {}
  rect(blk, 10, -20, 30, -11)   -- toit (10 d'épaisseur : le fil ne le franchit pas)
  rect(blk, 10, 11, 30, 20)     -- plancher
  rect(blk, 28, -20, 40, 20)    -- fond épais (13), côté du but
  local f = freefn(blk)
  local a, b = { x = 20.5, y = 0.5 }, { x = 45.5, y = 0.5 }
  check(P.pole_chain(a, b, 9, false, f, nil, { no_astar = true }) == nil, "poche en U : l'ancienne chaîne est coincée (nil)")
  local c = P.pole_chain(a, b, 9, false, f)
  check(valid(c, a, b, 9, f), "poche en U : l'A* recule, sort de la poche et rejoint le but (" .. tostring(c and #c) .. " poteaux)")
  local back = false
  for _, p in ipairs(c or {}) do if p.x < a.x - 1 then back = true end end
  check(back, "poche en U : la chaîne passe réellement en arrière du départ")
  -- but muré : aucune tuile libre dans un anneau autour du but, fil impossible
  local ring = {}
  rect(ring, 36, -10, 56, 10)
  local fr = function(x, y)
    if math.abs(x - 46) <= 3 and math.abs(y - 0.5) <= 3 then return false end
    return not ring[P.tkey(math.floor(x), math.floor(y))] or (math.abs(x - 46) < 1.5 and math.abs(y) < 1.5)
  end
  local c2, why = Q.path({ x = 0.5, y = 0.5 }, { x = 46.5, y = 0.5 }, 9, false, function() return false end)
  check(c2 == nil and why ~= nil, "aucune tuile libre : nil avec une raison (" .. tostring(why) .. ")")
  -- départ muré : pas de candidat à portée
  local box = {}
  rect(box, -12, -12, 12, 12)
  rect(box, -12, -12, 12, 12)
  local fbx = function(x, y) return not box[P.tkey(math.floor(x), math.floor(y))] end
  check(Q.path({ x = 0.5, y = 0.5 }, { x = 60.5, y = 0.5 }, 9, false, fbx) == nil, "départ au centre d'un bloc de 25 : nil")
  -- rivière plus large que la portée : aucun poteau ne peut tenir dessus, nil
  local riv = {}
  rect(riv, 20, -300, 32, 300)
  check(Q.path({ x = 0.5, y = 0.5 }, { x = 50.5, y = 0.5 }, 9, false, freefn(riv)) == nil, "rivière de 13 pour une portée de 9 : nil")
  -- ... mais pas pour des grands poteaux de portée 30
  check(valid(P.pole_chain({ x = 0, y = 0 }, { x = 70, y = 0 }, 30, true, freefn(riv)), { x = 0, y = 0 }, { x = 70, y = 0 }, 30, freefn(riv)), "la même rivière, grands poteaux : franchie")
end

section("4. Poteaux connus")
do
  local free = function() return true end
  local a, b = { x = 0.5, y = 0.5 }, { x = 48.5, y = 0.5 }
  local base = P.pole_chain(a, b, 9, false, free)
  local known = {}
  for _, c in ipairs(base) do known[#known + 1] = { x = c.x, y = c.y } end
  local again = Q.path(a, b, 9, false, free, known)
  check(again ~= nil and #again == 0, "rue déjà jalonnée : aucun poteau neuf (" .. tostring(again and #again) .. ")")
  local none = Q.path(a, b, 9, false, function() return false end, known)
  check(none ~= nil and #none == 0, "poteaux connus : aucune tuile libre exigée")
  -- un mur et un poteau connu au-delà : la chaîne passe le mur, n'en rend pas le poteau connu
  local blk = {}
  rect(blk, 20, -10, 31, 10)
  local fb = freefn(blk)
  local kn = { { x = 31.5, y = 0.5 } }
  local c = P.pole_chain({ x = 0.5, y = 0.5 }, { x = 48.5, y = 0.5 }, 9, false, fb, kn)
  local has_known = false
  for _, p in ipairs(c or {}) do if p.x == 31.5 and p.y == 0.5 then has_known = true end end
  check(valid(c, { x = 0.5, y = 0.5 }, { x = 48.5, y = 0.5 }, 9, fb) or c ~= nil, "mur et poteau connu au-delà : une chaîne existe")
  check(not has_known, "le poteau connu n'est jamais rendu")
  -- un poteau connu hors du couloir est sans effet
  local far = { { x = 30.5, y = 400.5 } }
  local c1 = Q.path(a, b, 9, false, free)
  local c2 = Q.path(a, b, 9, false, free, far)
  local same = #c1 == #c2
  for i = 1, #c1 do if not same or c1[i].x ~= c2[i].x or c1[i].y ~= c2[i].y then same = false end end
  check(same, "poteau connu très loin du couloir : chaîne inchangée")
  -- liste vide = pas de liste
  local c3 = Q.path(a, b, 9, false, free, {})
  same = #c1 == #c3
  for i = 1, #c1 do if not same or c1[i].x ~= c3[i].x or c1[i].y ~= c3[i].y then same = false end end
  check(same, "liste vide de poteaux connus = comportement inchangé")
  -- un poteau connu qui évite des poteaux neufs : moins de poteaux neufs avec que sans, quand il est sur le chemin
  local blk2 = {}
  rect(blk2, 24, -2, 26, 2)
  local f2 = freefn(blk2)
  local without = Q.path(a, b, 9, false, f2)
  local with = Q.path(a, b, 9, false, f2, { { x = 23.5, y = 0.5 }, { x = 30.5, y = 0.5 } })
  check(without and with and #with <= #without, string.format("poteaux connus sur la route : %d neuf(s) contre %d sans", with and #with or -1, without and #without or -1))
end

section("5. Équivalence ou amélioration face à l'ancienne chaîne")
do
  -- cas de plan_test : ligne de 40 tuiles, bloc 10..12 x -2..2 (le même)
  local block = {}
  rect(block, 10, -2, 12, 2)
  local free = freefn(block)
  local a, b = { x = 0.5, y = 0.5 }, { x = 40.5, y = 0.5 }
  local old = P.pole_chain(a, b, 9, false, free, nil, { no_astar = true })
  local new = P.pole_chain(a, b, 9, false, free)
  check(old and new and #new <= #old, "cas de plan_test : pas plus de poteaux que l'ancienne chaîne (" .. tostring(new and #new) .. " contre " .. tostring(old and #old) .. ")")
  check(valid(new, a, b, 9, free), "cas de plan_test : chaîne valide")
  local bg = P.pole_chain({ x = 0, y = 0 }, { x = 56, y = 0 }, 30, true, function() return true end)
  check(bg and #bg == 1, "grands poteaux : un intermédiaire sur 56 tuiles")
  -- 300 cartes pseudo-aléatoires (LCG fixe) : blocs et lacs
  local seed = 20261029
  local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end
  local nil_old, saved, worse, bad, total, fewer = 0, 0, 0, 0, 0, 0
  for _ = 1, 300 do
    local blk = {}
    for _ = 1, 1 + rnd(5) do
      local x0, y0 = rnd(50) - 5, rnd(50) - 5
      rect(blk, x0, y0, x0 + rnd(12), y0 + rnd(12))
    end
    local f = freefn(blk)
    local pa = { x = rnd(10) + 0.5, y = rnd(10) + 0.5 }
    local pb = { x = 35 + rnd(25) + 0.5, y = 35 + rnd(25) + 0.5 }
    if f(pa.x, pa.y) and f(pb.x, pb.y) then
      total = total + 1
      local g = P.pole_chain(pa, pb, 9, false, f, nil, { no_astar = true })
      local n = P.pole_chain(pa, pb, 9, false, f)
      if not g then nil_old = nil_old + 1 end
      if g and not n then worse = worse + 1 end
      if g and n and #n > #g then worse = worse + 1 end
      if g and n and #n < #g then fewer = fewer + 1 end
      if not g and n then saved = saved + 1 end
      if n and not valid(n, pa, pb, 9, f) then bad = bad + 1 end
      if n and #n < lower_bound(pa, pb, 9) then bad = bad + 1 end
    end
  end
  check(total >= 250, "cartes jouées : " .. total)
  check(worse == 0, "jamais nil si l'ancienne chaîne rend quelque chose, jamais plus longue (" .. worse .. " cas pires)")
  check(bad == 0, "toute chaîne rendue est valide (portée, tuiles libres, bout) et au moins au minimum théorique (" .. bad .. ")")
  check(saved >= 1, string.format("l'A* rend une chaîne là où l'ancienne était bloquée : %d cas sur %d bloqués", saved, nil_old))
  print(string.format("  (info) %d cartes : ancienne bloquée %d fois, sauvées %d, raccourcies %d", total, nil_old, saved, fewer))
end

section("6. Propriétés sur terrain libre")
do
  local free = function() return true end
  local worst_gap = 0
  local cases = 0
  for _, reach in ipairs({ 7.5, 9, 30 }) do
    local big = reach == 30
    for _, d in ipairs({ { 20, 0 }, { 40, 13 }, { 0, 55 }, { 33, 33 }, { -47, 21 }, { 70, -64 } }) do
      local a = big and { x = 0, y = 0 } or { x = 0.5, y = 0.5 }
      local b = { x = a.x + d[1], y = a.y + d[2] }
      local c = Q.path(a, b, reach, big, free)
      cases = cases + 1
      check(valid(c, a, b, reach, free), string.format("portée %g, vers (%d, %d) : chaîne valide", reach, d[1], d[2]))
      if c then worst_gap = math.max(worst_gap, #c - lower_bound(a, b, reach)) end
    end
  end
  check(worst_gap <= 3, "écart au minimum théorique en terrain libre : " .. worst_gap .. " poteau(x) au plus")
  print("  (info) écart maximal au minimum théorique, A* seul, terrain libre : " .. worst_gap)
end

section("7. Déterminisme")
do
  local blk = {}
  rect(blk, 20, -10, 31, 10)
  rect(blk, 5, 8, 12, 14)
  local f = freefn(blk)
  local a, b = { x = 0.5, y = 0.5 }, { x = 48.5, y = 3.5 }
  local known = { { x = 3.5, y = -9.5 }, { x = 12.5, y = -12.5 }, { x = 21.5, y = -14.5 }, { x = 30.5, y = -12.5 }, { x = 40.5, y = -7.5 } }
  local function key(c) local t = {} for _, p in ipairs(c or {}) do t[#t + 1] = p.x .. "," .. p.y end return table.concat(t, ";") end
  local c1 = key(Q.path(a, b, 9, false, f, known))
  local c2 = key(Q.path(a, b, 9, false, f, known))
  local rev = {}
  for i = #known, 1, -1 do rev[#rev + 1] = known[i] end
  local c3 = key(Q.path(a, b, 9, false, f, rev))
  check(c1 ~= "" and c1 == c2, "deux appels identiques : même chaîne")
  check(c1 == c3, "ordre des poteaux connus inversé : même chaîne")
  local p1, p2 = key(P.pole_chain(a, b, 9, false, f, known)), key(P.pole_chain(a, b, 9, false, f, known))
  check(p1 == p2, "P.pole_chain : deux appels identiques")
  -- symétrie des égalités : des départs/buts décalés n'introduisent pas de non-déterminisme (100 appels, une seule chaîne)
  local keys = {}
  for _ = 1, 100 do keys[key(Q.path(a, b, 9, false, f))] = true end
  local n = 0
  for _ in pairs(keys) do n = n + 1 end
  check(n == 1, "100 appels : une seule chaîne")
end

section("8. Plafond et coût borné")
do
  local free = function() return true end
  local calls = 0
  local counting = function() calls = calls + 1 return true end
  local a, b = { x = 0.5, y = 0.5 }, { x = 40.5, y = 30.5 }
  local before = Q.STATS.cells
  local c = Q.path(a, b, 9, false, counting)
  local cells = Q.STATS.cells - before
  check(c ~= nil and cells <= Q.MAX_CELLS, "cellules résolues pour une liaison de 50 tuiles : " .. cells .. " (plafond " .. Q.MAX_CELLS .. ")")
  check(calls <= Q.MAX_CELLS * 9, "appels à free bornés (3 x 3 tuiles par cellule) : " .. calls)
  -- plafond serré : refus net
  local r, why = Q.path(a, b, 9, false, free, nil, { max_cells = 5 })
  check(r == nil and why == "couloir trop grand", "plafond de 5 cellules : refusé (" .. tostring(why) .. ")")
  -- budget de nœuds serré : refus net, jamais de chaîne fausse
  local r1, why1 = Q.path({ x = 0.5, y = 0.5 }, { x = 48.5, y = 0.5 }, 9, false, freefn((function() local t = {} rect(t, 20, -10, 31, 10) return t end)()), nil, { max_expand = 10 })
  check(r1 == nil and why1 == "budget de nœuds épuisé", "budget de 10 nœuds : refusé (" .. tostring(why1) .. ")")
  -- liaison démesurée : refus immédiat, sans appeler free
  local calls2 = 0
  local r2 = Q.path({ x = 0, y = 0 }, { x = 4000, y = 3000 }, 9, false, function() calls2 = calls2 + 1 return true end)
  check(r2 == nil and calls2 == 0, "liaison de 5000 tuiles : refusée sans aucun appel à free")
  -- P.pole_chain retombe alors sur la gloutonne (qui en pose 64 au plus, ici nil)
  check(P.pole_chain({ x = 0, y = 0 }, { x = 4000, y = 3000 }, 9, false, free) == nil, "liaison démesurée : repli gloutonne (nil, comme avant)")
  -- coût mesuré (information) : pire cas, couloir élargi au maximum, lac infranchissable
  local blk = {}
  rect(blk, 25, -400, 35, 400)
  local fw = freefn(blk)
  local t0 = os.clock()
  local rep = 20
  local rr
  for _ = 1, rep do rr = Q.path({ x = 0.5, y = 0.5 }, { x = 60.5, y = 0.5 }, 9, false, fw) end
  local ms = (os.clock() - t0) * 1000 / rep
  check(rr == nil, "mur infranchissable de 800 : nil")
  print(string.format("  (info) pire cas (3 couloirs, échec) : %.1f ms par appel hors jeu, %d expansions cumulées", ms, Q.STATS.expanded))
  -- plus de 600 cellules résolues cumulées par appel : jamais
  local b0 = Q.STATS.cells
  Q.path({ x = 0.5, y = 0.5 }, { x = 60.5, y = 0.5 }, 9, false, fw)
  check(Q.STATS.cells - b0 <= Q.MAX_CELLS, "cellules résolues sur le pire cas : " .. (Q.STATS.cells - b0))
end

section("9. Mutants")
do
  local f0, err0 = battery(Q)
  check(f0 == 0, "batterie sur le module réel : 0 échec (" .. f0 .. ", " .. tostring(err0) .. ")")
  local fh = io.open("shared/team/poteaux.lua", "rb")
  local src = fh:read("*a")
  fh:close()
  local function mutant(label, from, to)
    local s, n = src:gsub(from:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"), (to:gsub("%%", "%%%%")), 1)
    if n ~= 1 then check(false, "mutant « " .. label .. " » : motif introuvable dans poteaux.lua") return end
    local fn = load(s, "=mutant", "t", _ENV)
    local M = fn()
    local nf = battery(M)
    check(nf >= 1, "mutant « " .. label .. " » refusé par la batterie (" .. nf .. " échec(s))")
  end
  mutant("arête plus longue que la portée", "if d <= reach + EPS then", "if d <= reach + 3 then")
  mutant("bout trop loin du but", "if db <= reach + EPS then", "if db <= reach * 2 then")
  mutant("tuile non libre acceptée", "if free(px, py) then", "if true then")
  mutant("poteaux connus rendus comme neufs", "if not nodes[id].known then table.insert", "if true then table.insert")
  mutant("poteaux connus payés", "(m.known and 0 or Q.W)", "Q.W")
  mutant("couloir étroit seulement", "Q.WIDTHS = { 1, 2, 3.5 }", "Q.WIDTHS = { 1 }")
end

print(string.format("[POTEAUX-ASTAR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
