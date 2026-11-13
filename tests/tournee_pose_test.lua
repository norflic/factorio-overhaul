-- Lot CHANTIERS-FANTOMES : tournées de pose (shared/team/tournee_pose.lua). Usage : lua5.2 tests/tournee_pose_test.lua
package.path = "./?.lua;" .. package.path
local Tp = require("shared.team.tournee_pose")
local ok, ko = 0, 0
local function check(c, what)
  if c then ok = ok + 1 else ko = ko + 1 print("ECHEC : " .. what) end
end
local function a(k, x, y, n, items) return { k = k, x = x, y = y, n = n, items = items or { { "piece", n } } } end
local function stack() return 100 end

-- 1. Ligne de poteaux : 20 points d'appui à 7 tuiles l'un de l'autre, 1 pièce chacun : une seule tournée, de proche en proche depuis l'origine.
do
  local list = {}
  for i = 1, 20 do list[#list + 1] = a(string.format("p%02d", i), 7 * i, 0, 1) end
  local t = Tp.group(list, { x = 0, y = 0 }, stack)
  check(#t == 1, "ligne : une tournee (" .. #t .. ")")
  check(t[1][1] == 1 and t[1][20] == 20, "ligne : ordre de passage depuis l'origine")
end

-- 2. Borne de pièces : 10 points d'appui de 10 pièces voisins : tournées de 40 au plus (Tp.MAX_PIECES 48).
do
  local list = {}
  for i = 1, 10 do list[#list + 1] = a("c" .. i, 8 * i, 0, 10) end
  local t = Tp.group(list, { x = 0, y = 0 }, stack)
  local seen = 0
  for _, tour in ipairs(t) do
    local n = 0
    for _, i in ipairs(tour) do n = n + list[i].n; seen = seen + 1 end
    check(n <= Tp.MAX_PIECES, "bornes : " .. n .. " pieces")
  end
  check(seen == 10, "bornes : chaque point d'appui une fois")
  check(#t == 3, "bornes : 3 tournees (" .. #t .. ")")
end

-- 3. Saut trop long : deux groupes à 200 tuiles : deux tournées.
do
  local list = { a("a", 0, 0, 2), a("b", 8, 0, 2), a("c", 208, 0, 2), a("d", 216, 0, 2) }
  local t = Tp.group(list, { x = 0, y = 0 }, stack)
  check(#t == 2, "saut : 2 tournees")
end

-- 4. Piles : un objet de pile 1 (foreuse fictive), 40 pièces : bornées par Tp.MAX_SLOTS.
do
  local list = {}
  for i = 1, 8 do list[#list + 1] = a("f" .. i, 3 * i, 0, 5, { { "lourd", 5 } }) end
  local t = Tp.group(list, { x = 0, y = 0 }, function() return 1 end)
  for _, tour in ipairs(t) do
    local n = 0
    for _, i in ipairs(tour) do n = n + 5 end
    check(n <= Tp.MAX_SLOTS, "piles : " .. n .. " piles")
  end
end

-- 5. Un point d'appui trop gros fait sa tournée seul ; déterminisme (même entrée, même sortie).
do
  local list = { a("g", 0, 0, 100), a("h", 5, 0, 1) }
  local t1 = Tp.group(list, { x = 0, y = 0 }, stack)
  local t2 = Tp.group(list, { x = 0, y = 0 }, stack)
  check(#t1 == 2 and #t1[1] == 1, "gros : seul")
  check(table.concat(t1[1], ",") == table.concat(t2[1], ",") and table.concat(t1[2], ",") == table.concat(t2[2], ","), "determinisme")
end

-- 6. Égalité de distance : la plus petite clé d'abord.
do
  local list = { a("b", 10, 0, 1), a("a", -10, 0, 1) }
  local t = Tp.group(list, { x = 0, y = 0 }, stack)
  check(t[1][1] == 2, "egalite : cle la plus petite")
end

-- Lot FANTOMES : matière comptée d'un point d'appui au suivant (Tp.allot).
local function pcs(item, n, extra)
  local t = {}
  for _ = 1, n do t[#t + 1] = { item = item, extra = extra } end
  return t
end
local function left_in(stock) return function(nm) return stock[nm] or 0 end end
local function line(c)
  local t = {}
  for _, it in ipairs(c.items) do t[#t + 1] = it[1] .. "=" .. it[2] end
  return tostring(c.k) .. ":" .. c.n .. ":" .. table.concat(t, ",") .. (c.short and ":manque" or "")
end
local function dump(list)
  local t = {}
  for _, c in ipairs(list) do t[#t + 1] = line(c) end
  return table.concat(t, " ")
end

-- 7. La même matière n'est promise qu'une fois : 10 points d'appui de 5 tapis, 12 tapis au coffre : 2 pleins, 1 de 2 tapis, 7 sans tâche.
do
  local list = {}
  for i = 1, 10 do list[#list + 1] = { k = string.format("t%02d", i), pieces = pcs("tapis", 5) } end
  local out, taken = Tp.allot(list, left_in({ tapis = 12 }))
  check(#out == 3, "matiere : 3 points d'appui servis sur 10 (" .. #out .. ")")
  check(dump(out) == "t01:5:tapis=5 t02:5:tapis=5 t03:2:tapis=2:manque", "matiere : " .. dump(out))
  check(taken.tapis == 12, "matiere : 12 tapis donnes, pas un de plus")
  local total = 0
  for _, c in ipairs(out) do total = total + c.n end
  check(total == 12, "matiere : pieces donnees = matiere disponible")
end

-- 8. Rien au coffre : aucune tâche ; matière négative (promise ailleurs) : aucune tâche.
do
  local list = { { k = "a", pieces = pcs("four", 2) } }
  check(#Tp.allot(list, left_in({})) == 0, "vide : aucune tache")
  check(#Tp.allot(list, left_in({ four = -3 })) == 0, "promis ailleurs : aucune tache")
end

-- 9. Chantier ouvert fini d'abord : le point d'appui entamé passe devant une clé plus petite.
do
  local list = { { k = "a", pieces = pcs("bras", 3) }, { k = "z", started = true, pieces = pcs("bras", 3) } }
  local out = Tp.allot(list, left_in({ bras = 4 }))
  check(dump(out) == "a:1:bras=1:manque z:3:bras=3", "entame d'abord : " .. dump(out))
end

-- 10. Une pièce sans son objet n'est pas donnée, les autres le sont ; l'accompagnement suit la pièce, dans la limite du disponible.
do
  local list = { { k = "m", pieces = { { item = "foreuse" }, { item = "bras", extra = { { "combustible", 2 } } }, { item = "bras", extra = { { "combustible", 2 } } },
    { item = "tapis" } } } }
  local out = Tp.allot(list, left_in({ bras = 2, tapis = 9, combustible = 3 }))
  check(dump(out) == "m:3:bras=2,combustible=3,tapis=1:manque", "mixte : " .. dump(out))
  -- l'accompagnement seul ne fait pas une tâche
  check(#Tp.allot({ { k = "n", pieces = { { item = "bras", extra = { { "combustible", 2 } } } } } }, left_in({ combustible = 5 })) == 0, "accompagnement seul : aucune tache")
end

-- 11. Déterminisme et sortie triée par clé ; l'entrée n'est pas modifiée.
do
  local list = { { k = "c", pieces = pcs("x", 2) }, { k = "a", pieces = pcs("x", 2) }, { k = "b", started = true, pieces = pcs("x", 2) } }
  local o1, o2 = Tp.allot(list, left_in({ x = 5 })), Tp.allot(list, left_in({ x = 5 }))
  check(dump(o1) == dump(o2) and dump(o1) == "a:2:x=2 b:2:x=2 c:1:x=1:manque", "determinisme : " .. dump(o1))
  check(list[1].k == "c" and #list[1].pieces == 2, "entree intacte")
  check(o1[1].i == 2 and o1[2].i == 3 and o1[3].i == 1, "indices d'origine rendus")
end

-- 12. Câblage (lecture du code) : batch_tasks passe par Tp.allot avec la matière promise, la tâche ne demande que le donné, le PNJ passe
-- un point d'appui dont il ne porte rien.
do
  local function read(p) local fh = assert(io.open(p, "rb")); local s = fh:read("*a"); fh:close(); return s end
  local B, W = read("script/team/build.lua"), read("script/team/worker.lua")
  check(B:find("local allot, taken = Build.Tournee.allot(list, left_of)", 1, true) ~= nil, "build.lua : batch_tasks passe par Tp.allot")
  check(B:find("local function left_of(it) return (p.stock[it] or 0) + (free[it] or 0) - (promised[it] or 0) end", 1, true) ~= nil,
    "build.lua : disponible = reserve + libre - promis")
  check(B:find("if not t.took then", 1, true) ~= nil and B:find("promised[it[1]] = (promised[it[1]] or 0) + it[2]", 1, true) ~= nil,
    "build.lua : objets promis aux taches qui n'ont pas pris")
  check(B:find("cand[#cand + 1] = { k = c.k, x = a.ax, y = a.ay, n = c.n, items = c.items, its = its }", 1, true) ~= nil,
    "build.lua : la tache ne demande que la matiere donnee")
  check(B:find("Rr.batch_ready(bt.main, have)", 1, true) == nil, "build.lua : plus de lot qui voit toute la reserve")
  check(W:find('steps[#steps + 1] = { "goto", { x = a.ax, y = a.ay }, 1, i }', 1, true) ~= nil and W:find("agent.pc = agent.pc + 2", 1, true) ~= nil,
    "worker.lua : point d'appui sans objet porte passe sans marche")
end

print(string.format("tournee_pose : %d OK, %d ECHEC(S)", ok, ko))
if ko > 0 then os.exit(1) end
