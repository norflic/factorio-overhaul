--[[
  Lot PIQUAGE (8/11) : test hors jeu de la règle pure shared/team/piquage.lua (alimenter l'entrée d'un bloc par le surplus d'un tapis
  existant) et, une fois écrit, de son branchement (script/team/piquage.lua, lu comme texte).
    §1 observation et verdict d'une tuile ; §2 géométrie du répartiteur (4 directions, 2 côtés) ; §3 prix ; §4 classement des sources ;
    §5 entités et preuve ; §6 décision, livraison, journal ; §7 déterminisme et hygiène (aucun nom d'objet, aucun pairs) ;
    §8 mutants : chaque règle retirée est vue.
  Usage : lua5.2 tests/piquage_test.lua   (depuis la racine du mod)
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
local SRC = read("shared/team/piquage.lua")
local function load_p(src)
  local fn, err = load(src, "=piquage", "t")
  assert(fn, err)
  return fn()
end
local Pq = load_p(SRC)
local Li = require("shared.team.liaison")
local P = require("shared.team.plan")

---------------------------------------------------------------------------------------------------
-- §1 observation et verdict d'une tuile
---------------------------------------------------------------------------------------------------
local function obs_of(list)
  local o
  for _, s in ipairs(list) do o = Pq.observe(o, s) end
  return o
end
local function dense(n) return { count = n, other = 0 } end
local o3 = obs_of({ dense(8), dense(7), dense(8) })
check(o3.n == 3 and o3.dense == 3 and o3.mixed == 0 and o3.sum == 23, "1.1 trois relevés denses accumulés")
local function tile(obs, over)
  local t = { obs = obs, shape = "straight", back = true, front = true }
  for _, k in ipairs({ "shape", "back", "front" }) do if over and over[k] ~= nil then t[k] = over[k] end end
  return t
end
check(Pq.tile_verdict(tile(o3)) == true, "1.2 tuile dense, droite, alimentée et prolongée : candidate")
local ok12, w12 = Pq.tile_verdict(tile(obs_of({ dense(8), dense(8) })))
check(ok12 == false and w12:find("insuffisants", 1, true) ~= nil, "1.3 deux relevés seulement : refusé, cause écrite")
check(Pq.tile_verdict(tile(nil)) == false, "1.4 aucun relevé : refusé")
local okm, wm = Pq.tile_verdict(tile(obs_of({ dense(8), { count = 8, other = 1 }, dense(8) })))
check(okm == false and wm:find("mixte", 1, true) ~= nil, "1.5 un autre objet vu une fois : tapis mixte refusé")
local oks, ws = Pq.tile_verdict(tile(obs_of({ dense(8), dense(2), dense(1) })))
check(oks == false and ws:find("surplus non observe", 1, true) ~= nil, "1.6 une tuile dense sur trois : surplus non observé")
check(Pq.tile_verdict(tile(obs_of({ dense(8), dense(8), dense(1) }))) == true, "1.7 deux relevés denses sur trois suffisent (2/3)")
check(Pq.tile_verdict(tile(obs_of({ dense(5), dense(5), dense(5) }))) == false, "1.8 5 objets par tuile n'est pas dense (seuil Pq.DENSE_AT)")
check(Pq.tile_verdict(tile(o3, { shape = "left" })) == false, "1.9 courbe refusée")
check(Pq.tile_verdict(tile(o3, { back = false })) == false, "1.10 rien n'alimente la tuile : refusé")
check(Pq.tile_verdict(tile(o3, { front = false })) == false, "1.11 le tapis finit sur la tuile : refusé")
do -- fenêtre glissante : un tapis vide 40 relevés puis plein 9 relevés de suite qualifie ; un tapis plein puis vide 9 relevés ne qualifie plus
  local lst = {}
  for _ = 1, 40 do lst[#lst + 1] = dense(0) end
  for _ = 1, Pq.WINDOW do lst[#lst + 1] = dense(8) end
  check(Pq.tile_verdict(tile(obs_of(lst))) == true, "1.13 un tapis vide puis plein depuis 9 relevés qualifie (fenêtre glissante)")
  local lst2 = {}
  for _ = 1, 40 do lst2[#lst2 + 1] = dense(8) end
  for _ = 1, Pq.WINDOW do lst2[#lst2 + 1] = dense(0) end
  check(Pq.tile_verdict(tile(obs_of(lst2))) == false, "1.14 un tapis plein puis vide depuis 9 relevés ne qualifie plus")
  local o = obs_of(lst2)
  check(#o.hist == Pq.WINDOW and o.n == 49, "1.15 l'historique est borné par la fenêtre (" .. #o.hist .. "), le total des relevés est gardé (" .. o.n .. ")")
end
check(Pq.DENSE_AT <= Pq.TILE_CAP and Pq.JAM_FRAC > 0.5 and Pq.JAM_FRAC <= 1, "1.12 seuils cohérents")

---------------------------------------------------------------------------------------------------
-- §2 géométrie : 4 directions x 2 côtés, valeurs écrites à la main
---------------------------------------------------------------------------------------------------
local function geo_is(d, side, want, msg)
  local g = Pq.geometry(10, 10, d, side)
  check(g.x == want.x and g.y == want.y and g.side_tile.x == want.sx and g.side_tile.y == want.sy
    and g.branch.x == want.bx and g.branch.y == want.by and g.main.x == want.mx and g.main.y == want.my and g.priority == want.pr and g.dir == d,
    "2 " .. msg .. string.format(" (obtenu centre %.1f,%.1f lateral %d,%d branche %d,%d priorite %s)", g.x, g.y, g.side_tile.x, g.side_tile.y,
      g.branch.x, g.branch.y, g.priority))
end
-- nord (0) : la gauche est l'ouest ; le tapis principal reste à l'est de la branche quand elle part à gauche -> priorité "right"
geo_is(0, "left", { x = 10.0, y = 10.5, sx = 9, sy = 10, bx = 9, by = 9, mx = 10, my = 9, pr = "right" }, "nord, branche à gauche")
geo_is(0, "right", { x = 11.0, y = 10.5, sx = 11, sy = 10, bx = 11, by = 9, mx = 10, my = 9, pr = "left" }, "nord, branche à droite")
-- est (2) : la gauche est le nord
geo_is(2, "left", { x = 10.5, y = 10.0, sx = 10, sy = 9, bx = 11, by = 9, mx = 11, my = 10, pr = "right" }, "est, branche à gauche")
geo_is(2, "right", { x = 10.5, y = 11.0, sx = 10, sy = 11, bx = 11, by = 11, mx = 11, my = 10, pr = "left" }, "est, branche à droite")
-- sud (4) : la gauche est l'est
geo_is(4, "left", { x = 11.0, y = 10.5, sx = 11, sy = 10, bx = 11, by = 11, mx = 10, my = 11, pr = "right" }, "sud, branche à gauche")
geo_is(4, "right", { x = 10.0, y = 10.5, sx = 9, sy = 10, bx = 9, by = 11, mx = 10, my = 11, pr = "left" }, "sud, branche à droite")
-- ouest (6) : la gauche est le sud
geo_is(6, "left", { x = 10.5, y = 11.0, sx = 10, sy = 11, bx = 9, by = 11, mx = 9, my = 10, pr = "right" }, "ouest, branche à gauche")
geo_is(6, "right", { x = 10.5, y = 10.0, sx = 10, sy = 9, bx = 9, by = 9, mx = 9, my = 10, pr = "left" }, "ouest, branche à droite")
do
  -- invariant : la priorité est toujours le côté opposé à la branche, et la tuile principale n'est jamais la tuile de départ de la branche
  local all_ok = true
  for _, d in ipairs({ 0, 2, 4, 6 }) do
    for _, side in ipairs({ "left", "right" }) do
      local g = Pq.geometry(3, -7, d, side)
      if g.priority == side or (g.main.x == g.branch.x and g.main.y == g.branch.y) then all_ok = false end
    end
  end
  check(all_ok, "2.9 priorité opposée à la branche, tuiles principale et branche distinctes (4 x 2)")
end

---------------------------------------------------------------------------------------------------
-- §3 prix
---------------------------------------------------------------------------------------------------
local function winp(t)
  local base = { flow = 1.0, dist = 56, span = 12, fill = 400, low = 60 }
  for _, k in ipairs({ "flow", "dist", "span", "fill", "low", "tiles", "ug", "threat", "price", "tmax" }) do
    if t and t[k] ~= nil then base[k] = t[k] end
  end
  return base
end
local okw, whyw, dw = Pq.worth(winp())
check(okw == true and dw.payback_min > 0 and dw.payback_min <= dw.tmax and whyw:find("retour", 1, true), "3.1 quai loin, bon débit : le piquage se paie (" .. whyw .. ")")
check(Pq.worth(winp({ flow = 0 })) == false and Pq.worth(winp({ flow = Li.MIN_FLOW / 2 })) == false, "3.2 débit nul ou sous Li.MIN_FLOW : refusé")
check(select(3, Pq.worth(winp({ tiles = 10 }))).payback_min < select(3, Pq.worth(winp({ tiles = 40 }))).payback_min, "3.3 un tapis plus court se paie plus vite")
check(select(3, Pq.worth(winp({ ug = 0 }))).cost < select(3, Pq.worth(winp({ ug = 2 }))).cost, "3.4 chaque paire de souterrains coûte")
check(select(3, Pq.worth(winp({ dist = 120 }))).payback_min < select(3, Pq.worth(winp({ dist = 20 }))).payback_min, "3.5 un quai plus loin du QG se paie plus vite")
local d1, d2 = select(3, Pq.worth(winp({ flow = 1 }))), select(3, Pq.worth(winp({ flow = 2 })))
check(math.abs(d1.payback_min / d2.payback_min - 2) < 0.5 and d2.payback_min < d1.payback_min, "3.6 un double débit se paie plus vite")
check(select(3, Pq.worth(winp({ threat = true }))).tmax == Li.TMAX / Li.THREAT_DIV, "3.7 menace : retour accepté divisé par Li.THREAT_DIV")
check(Pq.cost(10, 0) == 10 * Pq.PRICE.belt + Pq.PRICE.split + Pq.PRICE.arm + Pq.PRICE.pole, "3.8 coût = tapis + répartiteur + 1 bras + 1 poteau")
check(Pq.cost(10, 2) - Pq.cost(10, 0) == 2 * Pq.PRICE.ug, "3.9 coût des souterrains")
check(Pq.worth(winp({ flow = 1.2, price = { belt = 0.1, arm = 0.1, pole = 0.1, split = 0.1, ug = 0.1 } })) == true
  and Pq.worth(winp({ flow = 0.1, price = { belt = 50, arm = 50, pole = 50, split = 50, ug = 50 } })) == false, "3.10 le prix des pièces compte")
-- moins cher que la liaison à la sortie d'un module sur le même trajet : un bras et un poteau de moins
local _, _, dl = Li.worth(winp())
check(select(3, Pq.worth(winp({ tiles = dl.tiles }))).cost < dl.cost + Pq.PRICE.split, "3.11 coût comparable à la liaison (un bras et un poteau de moins, un répartiteur de plus)")

---------------------------------------------------------------------------------------------------
-- §4 classement des sources
---------------------------------------------------------------------------------------------------
local DOCK = { key = "7:q1", item = "X", flow = 1.0, dist = 56, fill = 400, low = 60 }
local function cand(key, o)
  local c = { key = key, x = 10, y = 10, dir = 2, obs = o3, shape = "straight", back = true, front = true,
    sides = { left = { span = 8 }, right = { span = 12 } } }
  for _, k in ipairs({ "obs", "shape", "back", "front", "sides", "x", "y" }) do if o and o[k] ~= nil then c[k] = o[k] end end
  return c
end
local r1 = Pq.rank(DOCK, { cand("t1") }, {}, {})
check(#r1 == 1 and r1[1].ok == true and r1[1].kind == "tapis" and r1[1].side == "left" and r1[1].span == 8, "4.1 un tapis candidat : retenu, côté le plus court (gauche, 8)")
local r2 = Pq.rank(DOCK, { cand("t1", { sides = { left = { span = 14 }, right = { span = 6 } } }) }, {}, {})
check(r2[1].side == "right" and r2[1].span == 6, "4.2 le côté qui rapproche de l'arrivée gagne")
local r3 = Pq.rank(DOCK, { cand("t1", { sides = {} }) }, {}, {})
check(r3[1].ok == false and r3[1].why:find("aucune place", 1, true), "4.3 aucun côté libre : refusé, cause")
local r4 = Pq.rank(DOCK, { cand("t1", { sides = { left = { span = Pq.SEARCH_SPAN + 1 } } }) }, {}, {})
check(r4[1].ok == false and r4[1].why:find("trop loin", 1, true), "4.4 trop loin : refusé, cause")
local r5 = Pq.rank(DOCK, { cand("t1") }, {}, { arm_rate = 0.5 })
check(r5[1].ok == false and r5[1].why:find("trop lent", 1, true), "4.5 bras du quai trop lent pour le débit : refusé")
check(Pq.rank(DOCK, { cand("t1") }, {}, { arm_rate = 5 })[1].ok == true, "4.6 bras assez rapide : accepté")
local r7 = Pq.rank(DOCK, { cand("t1", { obs = obs_of({ dense(8), { count = 8, other = 2 }, dense(8) }) }) }, {}, {})
check(r7[1].ok == false and r7[1].why:find("mixte", 1, true), "4.7 tapis mixte : refusé")
-- sortie de module proche : classée avec les tapis
local r8 = Pq.rank(DOCK, { cand("t1", { sides = { left = { span = 25 } } }) }, { { key = "9:o1", span = 6 } }, {})
check(#r8 == 2 and r8[1].kind == "sortie" and r8[1].ok == true and r8[2].kind == "tapis", "4.8 sortie de module à 6 tuiles contre tapis à 25 : la sortie d'abord")
local r9 = Pq.rank(DOCK, { cand("t1", { sides = { left = { span = 3 } } }) }, { { key = "9:o1", span = 30 } }, {})
check(r9[1].kind == "tapis" and r9[2].kind == "sortie", "4.9 tapis à 3 tuiles contre sortie à 30 : le tapis d'abord")
local r10 = Pq.rank(DOCK, { cand("t0", { shape = "left" }), cand("t1") }, {}, {})
check(r10[1].key == "t1" and r10[1].ok and not r10[2].ok, "4.10 une option qui se paie passe avant une option refusée")
local r11 = Pq.rank(DOCK, { cand("t2"), cand("t1") }, {}, {})
check(r11[1].key == "t1" and r11[2].key == "t2", "4.11 égalité : la clé la plus petite d'abord")
local z = { key = "7:q1", item = "X", flow = 0, dist = 56, fill = 400, low = 60 }
local r12 = Pq.rank(z, { cand("t1") }, { { key = "9:o1", span = 6 } }, {})
check(r12[1].kind == "sortie" and r12[1].ok == false and r12[2].ok == false, "4.12 deux options refusées à égalité : la sortie de module d'abord")
check(Pq.why_none({}):find("aucune source", 1, true) and Pq.why_none(r4) == r4[1].why, "4.13 cause d'un quai sans source")
-- le tapis existant est le choix par défaut (PREFER_TAPIS) : devant une sortie de module qui ne rapporte pas plus de 2 fois mieux
local r16 = Pq.rank(DOCK, { cand("t1", { sides = { left = { span = 20 } } }) }, { { key = "9:o1", span = 6 } }, {})
check(r16[1].kind == "tapis" and r16[2].kind == "sortie", "4.16 tapis à 20 tuiles contre sortie à 6 : le tapis par défaut (retour < 2 fois celui de la sortie)")
local r17 = Pq.rank(DOCK, { cand("t1", { sides = { left = { span = 30 } } }) }, { { key = "9:o1", span = 6 } }, {})
check(r17[1].kind == "sortie", "4.17 tapis à 30 tuiles (retour plus de 2 fois la sortie) : la sortie reste devant")
check(Pq.SEARCH_SPAN == Li.MAX_SPAN, "4.18 portée de recherche = celle de la liaison (40 tuiles)")
-- le classement ne modifie pas ses entrées
local c_in = cand("t1")
local before = c_in.sides.left.span
Pq.rank(DOCK, { c_in }, {}, {})
check(c_in.sides.left.span == before and c_in.obs.n == 3, "4.14 entrées intactes")
-- une branche plus courte gagne : retour croissant
local ra = Pq.rank(DOCK, { cand("a", { sides = { left = { span = 20 } } }), cand("b", { sides = { left = { span = 5 } } }) }, {}, {})
check(ra[1].key == "b" and ra[1].payback < ra[2].payback, "4.15 retour croissant : la branche courte d'abord")

---------------------------------------------------------------------------------------------------
-- §5 entités et preuve
---------------------------------------------------------------------------------------------------
local NAMES = { arm = "A", belt = "B", pole = "L" }
local isbelt = function(e) return e.role == "liaison-tapis" end
local isarm = function(e) return e.role == "liaison-bras" end
local geo = Pq.geometry(10, 10, 2, "left") -- est, branche à gauche : tuile latérale (10, 9), départ de branche (11, 9)
local D = { x = 14, y = 9 }               -- coffre du quai
local function open_grid(blocked)
  return function(x, y) return not (blocked and blocked[x .. ":" .. y]) end
end
local sites = Li.sites(D.x, D.y, open_grid())
local dst
for _, s in ipairs(sites) do if s.dir == 6 then dst = s end end -- bras à l'ouest du coffre : (13, 9), tuile de tapis (12, 9)
check(dst and dst.ax == 13 and dst.bx == 12, "5.1 site d'arrivée à l'ouest du coffre")
local route = P.belt_route({ x = geo.branch.x, y = geo.branch.y }, { x = dst.bx, y = dst.by }, Li.end_dir(dst), { x0 = 0, y0 = 0, x1 = 30, y1 = 30 },
  function(x, y) if x == D.x and y == D.y then return nil end return 1 end)
check(route and #route == 2 and route[1].x == 11 and route[2].x == 12, "5.2 tracé de la sortie du répartiteur au tapis d'arrivée")
local ents = Pq.entities({ geo = geo, dst = dst, route = route, names = NAMES, pole = { 13, 8 } })
check(#ents == 4 and ents[1].role == "liaison-tapis" and ents[3].role == "liaison-bras" and ents[4].role == "liaison" and ents[4].name == "L", "5.3 entités : 2 tapis, 1 bras, 1 poteau")
check(#Pq.verify(geo, ents, D, isbelt, isarm) == 0, "5.4 preuve géométrique juste")
-- un tracé plus long avec un détour, plusieurs tuiles
local route2 = P.belt_route({ x = 11, y = 9 }, { x = 12, y = 9 }, Li.end_dir(dst), { x0 = 0, y0 = 0, x1 = 30, y1 = 30 },
  function(x, y) if (x == 12 and y == 9 and false) then return nil end return 1 end)
check(route2 ~= nil, "5.5 tracé court sans obstacle")
-- cas faux détectés
local function with(mod)
  local e2 = {}
  for i, e in ipairs(ents) do e2[i] = { name = e.name, x = e.x, y = e.y, dir = e.dir, role = e.role } end
  mod(e2)
  return e2
end
check(#Pq.verify(geo, with(function(e) e[1].dir = 6 end), D, isbelt, isarm) > 0, "5.6 premier tapis tourné vers le répartiteur : refusé")
check(#Pq.verify(geo, with(function(e) e[3].dir = 2 end), D, isbelt, isarm) > 0, "5.7 bras tourné à l'envers : refusé")
check(#Pq.verify(geo, with(function(e) table.remove(e, 2) end), D, isbelt, isarm) > 0, "5.8 tapis interrompu : refusé")
check(#Pq.verify(geo, with(function(e) e[2].x = e[2].x + 3 end), D, isbelt, isarm) > 0, "5.9 tuile hors chaîne : refusé")
check(#Pq.verify(geo, with(function(e) e[#e + 1] = { name = "A", x = 20.5, y = 20.5, dir = 0, role = "liaison-bras" } end), D, isbelt, isarm) > 0, "5.10 deux bras : refusé")
check(#Pq.verify(geo, ents, { x = 15, y = 9 }, isbelt, isarm) > 0, "5.11 coffre déplacé : refusé")
check(#Pq.verify(Pq.geometry(10, 12, 2, "left"), ents, D, isbelt, isarm) > 0, "5.12 départ de branche ailleurs que sur la sortie du répartiteur : refusé")

---------------------------------------------------------------------------------------------------
-- §6 décision, livraison, journal
---------------------------------------------------------------------------------------------------
local function dinp(t)
  local base = { worth = true, worth_why = "ok", open = false, open_total = 0, free = 3, seen = Li.CONFIRM, tries = 0, since_try = 99999, enemies = 0, threat = false }
  for _, k in ipairs({ "worth", "open", "open_total", "free", "seen", "tries", "since_try", "enemies", "threat" }) do if t and t[k] ~= nil then base[k] = t[k] end end
  return base
end
check(Pq.decide(dinp()) == "relier", "6.1 tout est réuni : relier")
check(Pq.decide(dinp({ seen = 0 })) == "attendre", "6.2 à confirmer")
check(Pq.decide(dinp({ worth = false })) == "laisser", "6.3 ne se paie pas : laisser")
check(Pq.decide(dinp({ threat = true })) == "attendre" and Pq.decide(dinp({ enemies = 1 })) == "attendre", "6.4 menace ou ennemi : attendre")
check(Pq.decide(dinp({ tries = Li.MAX_TRIES, since_try = 10 })) == "laisser", "6.5 essais épuisés : laisser")
check(Pq.delivers(80, 60, 0) and Pq.delivers(10, 60, 3) and not Pq.delivers(10, 60, 0), "6.6 livraison : coffre au-dessus du seuil ou tapis qui porte")
check(Pq.CHEST == "tampon" and Pq.CHEST_WHY:find("repli PNJ", 1, true), "6.7 le coffre reste en tampon, raison écrite")
local ln = Pq.line("azure", { key = "15:q2", item = "X", flow = 0.5, dist = 54.2 }, "piquage demande", "tuile (3, 4)", 260.4)
check(ln == "[FO-PIQUAGE] azure : quai 15:q2 (X, 0.50/s, a 54 tuiles du QG) : piquage demande : tuile (3, 4) a 260.4 min", "6.8 format de la ligne de journal : " .. ln)
check(Pq.bilan_line("player", { docks = 33, linked = 1, piques = 2, tours = 41, items = 8200, minutes = 261.9 })
  == "[FO-PIQUAGE] player : bilan : quais d'entree 33, servis par tapis 1, par piquage 2, tournees fill 41 (objets 8200) a 261.9 min", "6.9 ligne de bilan")
do
  local seen = {}
  for _, v in ipairs(Pq.VERDICTS) do seen[v] = true end
  check(seen["piquage demande"] and seen["piquage refuse"] and seen["repartiteur pose"] and seen["coupe"], "6.10 verdicts écrits")
end

---------------------------------------------------------------------------------------------------
-- §7 déterminisme et hygiène
---------------------------------------------------------------------------------------------------
do
  local function flat(list)
    local out = {}
    for _, o in ipairs(list) do out[#out + 1] = table.concat({ o.kind, o.key, tostring(o.ok), tostring(o.payback), tostring(o.side), tostring(o.span) }, "|") end
    return table.concat(out, ";")
  end
  local cs = { cand("t3"), cand("t1", { sides = { right = { span = 9 } } }), cand("t2", { shape = "right" }) }
  local outs = { { key = "9:o1", span = 11 }, { key = "8:o1", span = 11 } }
  check(flat(Pq.rank(DOCK, cs, outs, {})) == flat(Pq.rank(DOCK, cs, outs, {})), "7.1 déterministe")
  local rev = { cs[3], cs[2], cs[1] }
  check(flat(Pq.rank(DOCK, cs, outs, {})) == flat(Pq.rank(DOCK, rev, { outs[2], outs[1] }, {})), "7.2 indépendant de l'ordre d'entrée")
end
do
  local CODE = SRC:gsub("%-%-%[%[.-%]%]", "")
  local names = { "iron", "copper", "coal", "stone", "chest", "inserter", "transport", "splitter", "underground", "plate", "ore" }
  local hits = {}
  for _, n in ipairs(names) do
    -- hors commentaires (une ligne commençant par --) et hors chaînes de journal : on cherche dans le code
    for line in CODE:gmatch("[^\n]+") do
      local code = line:gsub("%-%-.*$", "")
      code = code:gsub('"[^"]*"', '""')
      if code:find(n, 1, true) then hits[#hits + 1] = n break end
    end
  end
  check(#hits == 0, "7.3 aucun nom d'objet dans le code de la règle" .. (#hits > 0 and (" : " .. table.concat(hits, " ")) or ""))
  local bad_pairs = false
  for line in CODE:gmatch("[^\n]+") do
    local code = line:gsub("%-%-.*$", "")
    if code:find("[^i]pairs%(") then bad_pairs = true end
  end
  check(not bad_pairs, "7.4 aucun pairs dans la règle")
  check(not SRC:find("os%.clock") and not SRC:find("os%.time") and not SRC:find("math%.random") and not SRC:find("math%.sin") and not SRC:find("math%.cos"),
    "7.5 ni horloge, ni hasard, ni trigonométrie")
  check(select(2, SRC:gsub("\n", "")) < 500, "7.6 fichier de moins de 500 lignes")
end

---------------------------------------------------------------------------------------------------
-- §8 mutants
---------------------------------------------------------------------------------------------------
local function mutant(name, from, to, probe)
  local src = SRC:gsub(from, to, 1)
  if src == SRC then check(false, "mutant " .. name .. " : motif introuvable") return end
  local okl, Pm = pcall(load_p, src)
  if not okl then check(true, "mutant " .. name .. " (ne se charge pas)") return end
  local okp, seen = pcall(probe, Pm)
  check(not okp or seen, "mutant " .. name .. " vu")
end
-- (sonde qui rend vrai quand la règle est JUSTE : le mutant est vu quand elle ne l'est plus)
local function mutant_ok(name, from, to, probe)
  mutant(name, from, to, function(Pm) return not probe(Pm) end)
end
mutant_ok("tapis mixte accepté", "if o%.mixed > 0 then return false", "if false then return false",
  function(Pm) return Pm.tile_verdict(tile(obs_of({ dense(8), { count = 8, other = 1 }, dense(8) }))) == false end)
mutant_ok("un seul relevé suffit", "if not o or o%.n < Pq%.MIN_SAMPLES then", "if not o then",
  function(Pm) return Pm.tile_verdict(tile(obs_of({ dense(8) }))) == false end)
mutant_ok("surplus non exigé", "if wd < need then", "if false then",
  function(Pm) return Pm.tile_verdict(tile(obs_of({ dense(1), dense(1), dense(1) }))) == false end)
mutant_ok("part dense arrondie vers le bas", "math%.ceil%(Pq%.JAM_FRAC %* wn %- 1e%-9%)", "math.floor(Pq.JAM_FRAC * wn)",
  function(Pm) return Pm.tile_verdict(tile(obs_of({ dense(8), dense(1), dense(1) }))) == false end)
mutant_ok("fenêtre glissante retirée", ":sub%(%-Pq%.WINDOW%)", "",
  function(Pm)
    local lst = {}
    for _ = 1, 40 do lst[#lst + 1] = dense(0) end
    for _ = 1, Pq.WINDOW do lst[#lst + 1] = dense(8) end
    local o
    for _, s in ipairs(lst) do o = Pm.observe(o, s) end
    return Pm.tile_verdict(tile(o)) == true
  end)
mutant_ok("courbe acceptée", 'if c%.shape ~= "straight" then', "if false then",
  function(Pm) return Pm.tile_verdict(tile(o3, { shape = "left" })) == false end)
mutant_ok("tuile sans alimentation acceptée", "if not c%.back then", "if false then",
  function(Pm) return Pm.tile_verdict(tile(o3, { back = false })) == false end)
mutant_ok("bout de tapis accepté", "if not c%.front then", "if false then",
  function(Pm) return Pm.tile_verdict(tile(o3, { front = false })) == false end)
mutant_ok("priorité inversée", 'priority = %(side == "left"%) and "right" or "left"', 'priority = (side == "left") and "left" or "right"',
  function(Pm) return Pm.geometry(10, 10, 0, "left").priority == "right" end)
mutant_ok("côté inversé", 'local sgn = %(side == "left"%) and 1 or %-1', 'local sgn = (side == "left") and -1 or 1',
  function(Pm) return Pm.geometry(10, 10, 0, "left").side_tile.x == 9 end)
mutant_ok("centre pas au milieu", "x = %(tx %+ sx%) / 2 %+ 0%.5", "x = tx + 0.5",
  function(Pm) return Pm.geometry(10, 10, 0, "left").x == 10.0 end)
mutant_ok("départ de branche sur la tuile latérale", "branch = { x = sx %+ v%[1%], y = sy %+ v%[2%] }", "branch = { x = sx, y = sy }",
  function(Pm) local g = Pm.geometry(10, 10, 0, "left"); return g.branch.y == 9 end)
mutant_ok("coût sans répartiteur", "%+ price%.split %+", "+",
  function(Pm) return Pm.cost(10, 0) == Pq.cost(10, 0) end)
mutant_ok("souterrains gratuits", "%(ug_pairs or 0%) %* price%.ug", "0",
  function(Pm) return Pm.cost(10, 2) > Pm.cost(10, 0) end)
mutant_ok("pose non comptée", "local pay_s = cost / labor %+ build_s", "local pay_s = cost / labor",
  function(Pm) return select(3, Pm.worth(winp())).payback_min == select(3, Pq.worth(winp())).payback_min end)
mutant_ok("menace sans effet", "if inp%.threat then tmax = tmax / Li%.THREAT_DIV end", "",
  function(Pm) return select(3, Pm.worth(winp({ threat = true }))).tmax == Li.TMAX / Li.THREAT_DIV end)
mutant_ok("retour sans plafond", "if payback > tmax then", "if false then",
  function(Pm) return Pm.worth(winp({ flow = 0.05 })) == false end)
mutant_ok("côté le plus long préféré", "s%.span < best_span", "s.span > best_span",
  function(Pm) return Pm.rank(DOCK, { cand("t1") }, {}, {})[1].side == "left" end)
mutant_ok("portée de recherche ignorée", "elseif best_span > Pq%.SEARCH_SPAN then", "elseif false then",
  function(Pm) return (Pm.rank(DOCK, { cand("t1", { sides = { left = { span = 99 } } }) }, {}, {})[1].why):find("trop loin", 1, true) ~= nil end)
mutant_ok("débit du bras ignoré", "elseif opts%.arm_rate and dock%.flow > opts%.arm_rate then", "elseif false then",
  function(Pm) return Pm.rank(DOCK, { cand("t1") }, {}, { arm_rate = 0.5 })[1].ok == false end)
mutant_ok("tapis par défaut oublié", "if t%.payback <= list%[1%]%.payback %* Pq%.PREFER_TAPIS then", "if false then",
  function(Pm) return Pm.rank(DOCK, { cand("t1", { sides = { left = { span = 20 } } }) }, { { key = "9:o1", span = 6 } }, {})[1].kind == "tapis" end)
mutant_ok("tapis préféré à tout prix", "if t%.payback <= list%[1%]%.payback %* Pq%.PREFER_TAPIS then", "if true then",
  function(Pm) return Pm.rank(DOCK, { cand("t1", { sides = { left = { span = 30 } } }) }, { { key = "9:o1", span = 6 } }, {})[1].kind == "sortie" end)
mutant_ok("retour décroissant", "if pa ~= pb then return pa < pb end", "if pa ~= pb then return pa > pb end",
  function(Pm) return Pm.rank(DOCK, { cand("a", { sides = { left = { span = 20 } } }), cand("b", { sides = { left = { span = 5 } } }) }, {}, {})[1].key == "b" end)
mutant_ok("tapis avant sortie à égalité", 'return a%.kind == "sortie"', 'return a.kind == "tapis"',
  function(Pm) return Pm.rank(z, { cand("t1") }, { { key = "9:o1", span = 6 } }, {})[1].kind == "sortie" end)
mutant_ok("preuve : deux bras admis", "if #arms ~= 1 then", "if false then",
  function(Pm) return #Pm.verify(geo, with(function(e) e[#e + 1] = { name = "A", x = 20.5, y = 20.5, dir = 0, role = "liaison-bras" } end), D, isbelt, isarm) > 0 end)
mutant_ok("preuve : coffre non contrôlé", 'if arm%.tx %- av%[1%] ~= D%.x or arm%.ty %- av%[2%] ~= D%.y then', "if false then",
  function(Pm) return #Pm.verify(geo, ents, { x = 15, y = 9 }, isbelt, isarm) > 0 end)
mutant_ok("livraison : tapis ignoré", "or %(branch or 0%) > 0", "",
  function(Pm) return Pm.delivers(10, 60, 3) end)
mutant_ok("menace du QG ignorée par le piquage", "if inp%.threat then return", "if false then return",
  function(Pm) return Pm.decide(dinp({ threat = true })) == "attendre" end)

print(string.format("[PIQUAGE] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
