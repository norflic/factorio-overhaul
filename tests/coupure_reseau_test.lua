--[[
  Lot ENERGIE (2/11), santé du réseau : test hors jeu de la règle de coupure (shared/team/coupure_reseau.lua).
    §1 chemin le plus court (moins de poteaux perdus d'abord, puis fil), ordre du côté alimenté vers l'îlot, plusieurs îlots, doublons ;
    §2 ennemis : poteau tenu interdit, chemin sûr plus long préféré, second chemin quand tout est tenu ; §3 portée = la plus petite des deux ;
    §4 cas vides et replis ; §5 déterminisme (entrée mélangée) ; §6 zone à éviter ; §7 aucun nom d'objet ; §8 mutants.
  Usage : lua5.2 tests/coupure_reseau_test.lua   (depuis la racine du mod)
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
local SRC = read("shared/team/coupure_reseau.lua")
local function load_k(src)
  local fn, err = load(src, "=coupure", "t")
  assert(fn, err)
  return fn()
end
local K = load_k(SRC)

local function P(id, kind, x, y, extra)
  local p = { id = id, kind = kind, x = x, y = y, reach = 9 }
  for k, v in pairs(extra or {}) do p[k] = v end
  return p
end
local function ids(list) return table.concat(list, ",") end

-- §1 ligne droite : alimenté (0,0) -- perdus 1..4 (pas de 8) -- îlot (40, 0)
local line = { P(100, "live", 0, 0), P(1, "lost", 8, 0), P(2, "lost", 16, 0), P(3, "lost", 24, 0), P(4, "lost", 32, 0), P(200, "isl", 40, 0, { net = 7 }) }
local r = K.plan({ poles = line, enemies = {} })
check(r.action == "chemin", "ligne droite : chemin")
check(ids(r.order) == "1,2,3,4", "ordre du cote alimente vers l'ilot : " .. ids(r.order))
check(#r.second == 0, "aucun ilot sans chemin")
check(r.paths[1] and r.paths[1].lost == 4 and r.paths[1].net == 7, "4 poteaux sur le chemin de l'ilot 7")
-- ordre malgré une entrée à l'envers
local rev = {}
for i = #line, 1, -1 do rev[#rev + 1] = line[i] end
check(ids(K.plan({ poles = rev, enemies = {} }).order) == "1,2,3,4", "entree a l'envers : meme ordre")

-- chemin le plus court : deux routes, 3 perdus d'un côté (y = 0), 8 perdus de l'autre (contournement par le sud)
local two = { P(100, "live", 0, 0), P(200, "isl", 36, 0, { net = 1 }),
  P(1, "lost", 9, 0), P(2, "lost", 18, 0), P(3, "lost", 27, 0),
  P(11, "lost", 0, 8), P(12, "lost", 0, 16), P(13, "lost", 6, 22), P(14, "lost", 14, 26), P(15, "lost", 23, 26), P(16, "lost", 31, 22), P(17, "lost", 36, 15), P(18, "lost", 36, 8) }
r = K.plan({ poles = two, enemies = {} })
check(ids(r.order) == "1,2,3", "deux routes : la moins de poteaux perdus (" .. ids(r.order) .. ")")
-- à nombre égal, le fil le plus court : route A droite (3 perdus, 36), route B en arc (3 perdus, plus longue)
local tie = { P(100, "live", 0, 0), P(200, "isl", 36, 0, { net = 1 }),
  P(1, "lost", 9, 0), P(2, "lost", 18, 0), P(3, "lost", 27, 0),
  P(21, "lost", 9, 4), P(22, "lost", 18, 8), P(23, "lost", 27, 4) }
r = K.plan({ poles = tie, enemies = {} })
check(ids(r.order) == "1,2,3", "meme nombre de poteaux : le fil le plus court (" .. ids(r.order) .. ")")

-- moins de poteaux AVANT le fil : la ligne droite a 5 poteaux (fil 36), le contournement 4 (fil 38,8) : le contournement
local weigh = { P(100, "live", 0, 0), P(200, "isl", 36, 0, { net = 1 }),
  P(31, "lost", 6, 0), P(32, "lost", 12, 0), P(33, "lost", 18, 0), P(34, "lost", 24, 0), P(35, "lost", 30, 0),
  P(41, "lost", 8, 4), P(42, "lost", 16, 6), P(43, "lost", 25, 6), P(44, "lost", 31, 4) }
r = K.plan({ poles = weigh, enemies = {} })
check(ids(r.order) == "41,42,43,44", "moins de poteaux perdus avant le fil le plus court (" .. ids(r.order) .. ")")

-- plusieurs îlots : le plus proche d'abord, la partie commune une seule fois
local multi = { P(100, "live", 0, 0), P(1, "lost", 9, 0), P(2, "lost", 18, 0), P(3, "lost", 27, 0), P(4, "lost", 36, 0),
  P(200, "isl", 27, 9, { net = 5 }), P(201, "isl", 45, 0, { net = 6 }) }
r = K.plan({ poles = multi, enemies = {} })
check(ids(r.order) == "1,2,3,4", "deux ilots : partie commune sans doublon (" .. ids(r.order) .. ")")
check(#r.paths == 2 and r.paths[1].net == 5, "l'ilot le plus proche est le premier")
-- îlot déjà à portée d'un poteau vivant : rien à reposer -> repli (un fil, pas un poteau)
r = K.plan({ poles = { P(100, "live", 0, 0), P(200, "isl", 8, 0, { net = 1 }) }, enemies = {} })
check(r.action == "repli" and #r.order == 0, "ilot a portee de fil : repli")
-- un îlot ne sert pas de pont vers un autre
r = K.plan({ poles = { P(100, "live", 0, 0), P(200, "isl", 40, 0, { net = 1 }), P(201, "isl", 32, 9, { net = 2 }), P(1, "lost", 8, 0), P(2, "lost", 16, 0), P(3, "lost", 24, 0), P(4, "lost", 32, 0) }, enemies = {} })
check(#r.paths == 2, "les deux ilots sont joints par la ligne")
r = K.plan({ poles = { P(100, "live", 0, 0), P(200, "isl", 8, 0, { net = 1 }), P(201, "isl", 16, 0, { net = 2 }) }, enemies = {} })
check(#r.second == 1 and r.second[1].net == 2 and #r.paths == 1, "un ilot n'est pas un pont vers un autre : le second est sans chemin")

-- §2 ennemis
local en = { { x = 18, y = 0 } }
r = K.plan({ poles = two, enemies = en, enemy_r = 10 })
check(r.held >= 1, "poteaux tenus comptes (" .. r.held .. ")")
check(ids(r.order):find("2") == nil or ids(r.order) ~= "1,2,3", "route droite tenue par l'ennemi : abandonnee")
check(ids(r.order) == "11,12,13,14,15,16,17,18", "route sure plus longue preferee (" .. ids(r.order) .. ")")
for _, id in ipairs(r.order) do
  local ok = true
  for _, p in ipairs(two) do if p.id == id and K.held(p, en, 10) then ok = false end end
  check(ok, "poteau " .. id .. " non tenu")
end
-- tout est tenu : second chemin, récupérable (la ligne existe sans ennemi)
r = K.plan({ poles = line, enemies = { { x = 20, y = 5 } } })
check(r.action == "second" and #r.second == 1 and r.second[1].recoverable == true, "tout tenu : second chemin, recuperable")
check(#r.order == 0, "aucun poteau a reposer sous le feu")
-- ennemi loin : sans effet
r = K.plan({ poles = line, enemies = { { x = 20, y = 200 } } })
check(r.action == "chemin" and r.held == 0, "ennemi loin : sans effet")
-- ligne trop trouée : pas de chemin même sans ennemi
r = K.plan({ poles = { P(100, "live", 0, 0), P(1, "lost", 8, 0), P(200, "isl", 40, 0, { net = 3 }) }, enemies = {} })
check(r.action == "second" and r.second[1].recoverable == false, "trou dans la ligne : second chemin, non recuperable")
-- bord exact du rayon : tenu (<=) ; juste au-dessus : libre
check(K.held({ x = 28, y = 0 }, { { x = 0, y = 0 } }, 28) == true, "ennemi a exactement 28 : tenu")
check(K.held({ x = 28.01, y = 0 }, { { x = 0, y = 0 } }, 28) == false, "ennemi a 28,01 : libre")

-- §3 portée : un grand poteau (30) et un moyen (9) : arête permise à 9 seulement
r = K.plan({ poles = { P(100, "live", 0, 0, { reach = 30 }), P(1, "lost", 20, 0, { reach = 9 }), P(200, "isl", 28, 0, { net = 1, reach = 9 }) }, enemies = {} })
check(r.action == "second", "portee = la plus petite des deux : 20 tuiles entre un grand et un moyen ne se relie pas")
r = K.plan({ poles = { P(100, "live", 0, 0, { reach = 30 }), P(1, "lost", 25, 0, { reach = 30 }), P(200, "isl", 50, 0, { net = 1, reach = 30 }) }, enemies = {} })
check(r.action == "chemin" and ids(r.order) == "1", "deux grands poteaux : 25 tuiles se relient")
r = K.plan({ poles = { P(100, "live", 0, 0), P(1, "lost", 9, 0), P(200, "isl", 18, 0, { net = 1 }) }, enemies = {} })
check(r.action == "chemin", "9 tuiles pile : relie")
r = K.plan({ poles = { P(100, "live", 0, 0), P(1, "lost", 9.01, 0), P(200, "isl", 18, 0, { net = 1 }) }, enemies = {} })
check(r.action == "second", "9,01 tuiles : ne se relie pas")

-- §4 cas vides
r = K.plan({ poles = { P(100, "live", 0, 0), P(1, "lost", 8, 0) }, enemies = {} })
check(r.action == "rien" and #r.order == 0, "aucun ilot : rien")
r = K.plan({ poles = { P(1, "lost", 8, 0), P(200, "isl", 16, 0, { net = 1 }) }, enemies = {} })
check(r.action == "repli", "aucun poteau vivant du cote alimente : repli (l'appelant garde sa regle)")
r = K.plan({ poles = {}, enemies = {} })
check(r.action == "rien", "rien du tout : rien")
r = K.plan({})
check(r.action == "rien", "entree vide : rien")
r = K.plan({ poles = { P(1, "autre", 0, 0), P(2, "live", 0, 0) }, enemies = {} })
check(r.action == "rien", "genre inconnu ignore")

-- §5 déterminisme : même résultat quel que soit l'ordre
local function shuffle(list, seed)
  local out = {}
  for i, v in ipairs(list) do out[i] = v end
  local s = seed
  for i = #out, 2, -1 do
    s = (s * 1103515245 + 12345) % 2147483648
    local j = s % i + 1
    out[i], out[j] = out[j], out[i]
  end
  return out
end
local base = K.plan({ poles = two, enemies = en, enemy_r = 10 })
local same = true
for seed = 1, 20 do
  local q = K.plan({ poles = shuffle(two, seed), enemies = en, enemy_r = 10 })
  if ids(q.order) ~= ids(base.order) or q.action ~= base.action or q.held ~= base.held then same = false end
end
check(same, "20 melanges de l'entree : meme decision")

-- trim
local many = { P(100, "live", 0, 0), P(200, "isl", 400, 0, { net = 1 }) }
for i = 1, 10 do many[#many + 1] = P(i, "lost", 8 * i, 0) end
for i = 1, 700 do many[#many + 1] = P(1000 + i, "live", 5000 + i, 5000) end
local t = K.trim(many, 50)
local lost_kept = 0
for _, p in ipairs(t) do if p.kind == "lost" then lost_kept = lost_kept + 1 end end
check(#t == 50 and lost_kept == 10, "trim : 50 noeuds dont les 10 perdus")
check(K.plan({ poles = many, enemies = {} }).action == "repli", "plus de 600 noeuds : repli")

-- §6 zone à éviter
local z = K.avoid_zone({ { x = 50, y = 0 }, { x = 10, y = 0 }, { x = 30, y = 0 } }, { x = 0, y = 0 }, 2)
check(#z == 2 and z[1].x == 10 and z[2].x == 30 and z[1].r == 28, "zone : les 2 ennemis les plus proches, rayon 28")
check(K.in_zone(10, 20, z, nil, 0) == true, "point dans la zone")
check(K.in_zone(10, 40, z, nil, 0) == false, "point hors zone")
check(K.in_zone(10, 20, z, { { x = 10, y = 22 } }, 5) == false, "un bout de chaine reste permis dans la zone")
check(K.in_zone(10, 20, z, { { x = 10, y = 60 } }, 5) == true, "loin du bout : la zone vaut")

-- §7 aucun nom d'objet de jeu dans la règle pure
for _, name in ipairs({ "electric-pole", "medium-", "big-", "small-", "steam", "boiler", "transport-belt", "inserter", "game.", "global" }) do
  check(SRC:find(name, 1, true) == nil, "la regle pure ne nomme pas '" .. name .. "'")
end

-- §8 mutants : chaque règle retirée doit casser au moins un contrôle
local function suite(Kx)
  local f = 0
  local function c(cond) if not cond then f = f + 1 end end
  local a = Kx.plan({ poles = line, enemies = {} })
  c(ids(a.order) == "1,2,3,4")
  c(ids(Kx.plan({ poles = two, enemies = {} }).order) == "1,2,3")
  c(ids(Kx.plan({ poles = tie, enemies = {} }).order) == "1,2,3")
  c(ids(Kx.plan({ poles = multi, enemies = {} }).order) == "1,2,3,4")
  local b = Kx.plan({ poles = two, enemies = en, enemy_r = 10 })
  c(ids(b.order) == "11,12,13,14,15,16,17,18")
  local d = Kx.plan({ poles = line, enemies = { { x = 20, y = 5 } } })
  c(d.action == "second" and #d.order == 0 and d.second[1] and d.second[1].recoverable == true)
  local e = Kx.plan({ poles = { P(100, "live", 0, 0, { reach = 30 }), P(1, "lost", 20, 0, { reach = 9 }), P(200, "isl", 28, 0, { net = 1, reach = 9 }) }, enemies = {} })
  c(e.action == "second")
  local g = Kx.plan({ poles = { P(100, "live", 0, 0), P(1, "lost", 8, 0), P(200, "isl", 40, 0, { net = 3 }) }, enemies = {} })
  c(g.action == "second" and g.second[1].recoverable == false)
  local h = Kx.plan({ poles = { P(100, "live", 0, 0), P(200, "isl", 8, 0, { net = 1 }), P(201, "isl", 16, 0, { net = 2 }) }, enemies = {} })
  c(#h.second == 1 and h.second[1].net == 2)
  c(ids(Kx.plan({ poles = weigh, enemies = {} }).order) == "41,42,43,44")
  c(Kx.plan({ poles = multi, enemies = {} }).paths[1].net == 5)
  c(Kx.plan({ poles = { P(100, "live", 0, 0), P(200, "isl", 8, 0, { net = 1 }) }, enemies = {} }).action == "repli")
  c(Kx.held({ x = 28, y = 0 }, { { x = 0, y = 0 } }, 28) == true and Kx.held({ x = 28.01, y = 0 }, { { x = 0, y = 0 } }, 28) == false)
  c(Kx.plan({ poles = { P(100, "live", 0, 0), P(1, "lost", 9.01, 0), P(200, "isl", 18, 0, { net = 1 }) }, enemies = {} }).action == "second")
  c(Kx.plan({ poles = {}, enemies = {} }).action == "rien")
  c(Kx.plan({ poles = { P(1, "lost", 8, 0), P(200, "isl", 16, 0, { net = 1 }) }, enemies = {} }).action == "repli")
  local tt = Kx.trim(many, 50)
  local lk = 0
  for _, p in ipairs(tt) do if p.kind == "lost" then lk = lk + 1 end end
  c(#tt == 50 and lk == 10)
  c(Kx.plan({ poles = many, enemies = {} }).action == "repli")
  local zz = Kx.avoid_zone({ { x = 50, y = 0 }, { x = 10, y = 0 }, { x = 30, y = 0 } }, { x = 0, y = 0 }, 2)
  c(#zz == 2 and zz[1].x == 10)
  c(Kx.in_zone(10, 20, zz, { { x = 10, y = 22 } }, 5) == false and Kx.in_zone(10, 20, zz, nil, 0) == true)
  local ro = Kx.plan({ poles = rev, enemies = {} })
  c(ids(ro.order) == "1,2,3,4")
  local m5 = Kx.plan({ poles = { P(100, "live", 0, 0), P(200, "isl", 40, 0, { net = 1 }), P(201, "isl", 32, 9, { net = 2 }), P(1, "lost", 8, 0), P(2, "lost", 16, 0), P(3, "lost", 24, 0), P(4, "lost", 32, 0) }, enemies = {} })
  c(#m5.paths == 2)
  return f
end
check(suite(K) == 0, "la suite de mutants passe sur la regle intacte")

local function mutant(label, from, to)
  local s, n = SRC:gsub(from, function() return to end, 1)
  if n ~= 1 then check(false, "mutant mal forme (motif introuvable) : " .. label) return end
  local ok, Kx = pcall(load_k, s)
  local caught = not ok
  if ok then
    local ran, res = pcall(suite, Kx)
    caught = (not ran) or res > 0
  end
  check(caught, "mutant refuse : " .. label)
end
mutant("poteaux perdus gratuits (plus court en fil seulement)", "K%.W = 1e6", "K.W = 0")
mutant("poteau perdu = 1 tuile de fil seulement", "K%.W = 1e6", "K.W = 1")
mutant("ennemis ignores (jamais tenu)", "if p.kind == \"lost\" and K.held%(p, inp.enemies, r%) then", "if false then")
mutant("poteau tenu permis dans la recherche sure", "local safe = search%(nodes, held, false%)", "local safe = search(nodes, held, true)")
mutant("recherche libre = recherche sure", "local free = out.held > 0 and search%(nodes, held, true%) or safe", "local free = safe")
mutant("portee = la plus grande des deux", "math%.min%(nu%.reach or 9, nv%.reach or 9%)", "math.max(nu.reach or 9, nv.reach or 9)")
mutant("portee stricte (< au lieu de <=)", "if d <= reach %+ K%.EDGE_SLACK then", "if d < reach then")
mutant("portee trop large (+1)", "if d <= reach %+ K%.EDGE_SLACK then", "if d <= reach + 1 then")
mutant("ordre inverse (ilot vers alimente)", "for j = #chain, 1, %-1 do %-%- du côté alimenté vers l'îlot", "for j = 1, #chain do -- inverse")
mutant("doublons non filtres", "if not seen%[id%] then seen%[id%] = true; out%.order%[#out%.order %+ 1%] = id end", "out.order[#out.order + 1] = id")
mutant("ilots non tries par cout", "table%.sort%(rows, function%(a, b%) if a%.c ~= b%.c then return a%.c < b%.c end return a%.net < b%.net end%)", "table.sort(rows, function(a, b) return a.net > b.net end)")
mutant("un ilot sert de pont", "if nu%.kind ~= \"isl\" then", "if true then")
mutant("sources : aucun poteau vivant ne demarre", "if nodes%[i%]%.kind == \"live\" then cost%[i%] = 0", "if false then cost[i] = 0")
mutant("pas de repli sans poteau vivant", "if n_live == 0 then out%.action = \"repli\"", "if false then out.action = \"repli\"")
mutant("pas de repli au-dela de 600 noeuds", "if #nodes > K%.MAX_NODES then", "if false then")
mutant("second chemin jamais signale", "out%.second%[#out%.second %+ 1%] = { net = net, recoverable = b%.free ~= nil }", "local _ = 0")
mutant("recuperable toujours vrai", "recoverable = b%.free ~= nil", "recoverable = true")
mutant("ilot a portee de fil : chemin vide", "if #out%.order == 0 and #rows > 0 then", "if false then")
mutant("tenu seulement au-dela du rayon (< au lieu de <=)", "if dx %* dx %+ dy %* dy <= r %* r then return true end", "if dx * dx + dy * dy < r * r then return true end")
mutant("rayon de l'ennemi ignore (28 fixe a 5)", "K%.ENEMY_R = 28", "K.ENEMY_R = 5")
mutant("trim jette les perdus", "for _, p in ipairs%(lost%) do if #out < max then out%[#out %+ 1%] = p end end", "")
mutant("zone : tous les ennemis (pas de plafond)", "while #out > %(max or 6%) do table%.remove%(out%) end", "")
mutant("zone : bouts non exemptes", "if dx %* dx %+ dy %* dy <= %(exempt_r or 0%) %* %(exempt_r or 0%) then return false end", "")
mutant("zone : ennemis les plus loin d'abord", "if da ~= db then return da < db end\n    if a%.y ~= b%.y then return a%.y < b%.y end\n    return a%.x < b%.x\n  end%)\n  while", "if da ~= db then return da > db end\n    if a.y ~= b.y then return a.y < b.y end\n    return a.x < b.x\n  end)\n  while")

print(string.format("[COUPURE-RESEAU] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
