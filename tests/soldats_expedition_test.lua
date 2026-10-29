--[[
  Lot CORR-SOLDATS (remarque 4 du DC : « une base de 25 soldats inactifs [...] alors qu'ils pourraient détruire la base de
  biters ») : banc HORS JEU de l'EXPÉDITION des soldats inactifs (shared/ai3/soldats.lua : reserve, surplus, offense_ok,
  retreat, is_blocked, choix de la cible dans Sd.assign) ; mutants qui doivent échouer.
  Lancement : lua5.2 tests/soldats_expedition_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Sd = require("shared.ai3.soldats")
local K = require("shared.ai3.carte")

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
end
local function section(name) if not quiet then print("== " .. name) end end

local HQ = { x = 0, y = 0 }
local function soldiers(n)
  local out = {}
  for i = 1, n do out[i] = { id = i, x = (i % 5) * 3, y = 14 + math.floor(i / 5) * 2 } end
  return out
end
local function count(orders, role)
  local n = 0
  for _, o in pairs(orders) do if o.role == role then n = n + 1 end end
  return n
end
-- Champ de nids connu : nests nids + worms vers (k = nests + worms), au point (x, y).
local function field(x, y, nests, worms, over)
  local th = {}
  for i = 1, nests do th[#th + 1] = { x = x + i, y = y, kind = "spawner" } end
  for i = 1, worms do th[#th + 1] = { x = x, y = y + i, kind = "worm" } end
  local c = Sd.clusters(th)[1]
  for k, v in pairs(over or {}) do c[k] = v end
  return c
end

-- Carte de connaissance minimale : points { x, y, "spawner" | "worm" } rangés par secteur (K.record remplace tout un secteur).
local function known_map(points)
  local m = K.new()
  local by = {}
  for _, p in ipairs(points) do
    local key = K.key_of(p[1], p[2])
    by[key] = by[key] or { nests = {}, worms = {} }
    local l = p[3] == "spawner" and by[key].nests or by[key].worms
    l[#l + 1] = { x = p[1], y = p[2] }
  end
  for _, key in ipairs(K.sorted_keys(by)) do K.record(m, key, 0, by[key]) end
  return m
end
-- Chaîne du script : menaces vues en marche (`seen`), puis nids connus (Sd.add_known), triées, groupées.
local function known_clusters(km, seen)
  local cand = {}
  for _, t in ipairs(seen) do cand[#cand + 1] = t end
  Sd.add_known(cand, K.enemy_points(km, HQ.x, HQ.y, Sd.KNOWN_R))
  table.sort(cand, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  return Sd.clusters(cand)
end

local function suite()
  section("réserve et surplus")
  check(Sd.reserve(25) == 9, "25 inactifs : réserve 9 (35 %), pas 8 (" .. Sd.reserve(25) .. ")")
  check(Sd.reserve(12) == 8, "12 inactifs : réserve minimale 8 (" .. Sd.reserve(12) .. ")")
  check(Sd.surplus(25) == 16 and Sd.surplus(8) == 0 and Sd.surplus(3) == 0, "surplus : 25 -> 16, 8 -> 0, 3 -> 0")
  check(Sd.surplus(60) == 60 - 21, "60 inactifs : surplus 39 (" .. Sd.surplus(60) .. ")")

  section("groupes : nids comptés, tourelles adverses comptées")
  local c = field(60, 0, 2, 2)
  check(c.k == 4 and c.nests == 2 and c.rival == 0, "2 nids + 2 vers : k 4, 2 nids")
  local c2 = Sd.clusters({ { x = 60, y = 0, kind = "spawner" }, { x = 62, y = 0, kind = "turret" } })[1]
  check(c2.nests == 1 and c2.rival == 1, "une tourelle adverse est comptée à part")
  local c3 = Sd.clusters({ { x = 60, y = 0 }, { x = 62, y = 0 } })[1]
  check(c3.k == 2 and c3.nests == 0, "menaces sans genre : aucun nid")

  section("expédition : décision")
  local o, sm = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(25), threats = { field(60, 0, 2, 2) } })
  check(count(o, "clear") == 11, "25 inactifs, 2 nids + 2 vers, faction pacifique : 11 soldats partent (3 + 2 x 4) (" .. count(o, "clear") .. ")")
  check(sm.offense == true, "le résumé dit que c'est l'expédition (et non l'ancien seuil d'agressivité)")
  local garde = 25 - count(o, "clear")
  check(garde >= Sd.reserve(25), "la réserve reste au QG : " .. garde .. " >= " .. Sd.reserve(25))
  local o2 = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(10), threats = { field(60, 0, 2, 2) } })
  check(count(o2, "clear") == 0, "10 inactifs (surplus 2 < 11) : rien ne part")
  local o3 = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(25), threats = { field(60, 0, 8, 4) } })
  check(count(o3, "clear") == 0, "champ trop gros (8 nids + 4 vers : 27 > surplus 16) : rien ne part")
  local o4 = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(25), threats = { field(200, 0, 1, 0) } })
  check(count(o4, "clear") == 0, "nid à 200 tuiles du QG (> OFFENSE_R) : rien ne part")
  local o5 = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(25),
    threats = { Sd.clusters({ { x = 60, y = 0, kind = "worm" } })[1] } })
  check(count(o5, "clear") == 0, "un ver seul (aucun nid) : pas d'expédition")
  local o6 = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(25),
    threats = { Sd.clusters({ { x = 60, y = 0, kind = "spawner" }, { x = 63, y = 0, kind = "turret" } })[1] } })
  check(count(o6, "clear") == 0, "nid gardé par une tourelle adverse : pas d'expédition (une faction n'est pas un nid)")
  local o7 = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(25), offense = false, threats = { field(60, 0, 2, 2) } })
  check(count(o7, "clear") == 0, "coupure de banc (offense = false) : rien ne part")
  local o8 = Sd.assign({ tick = 100, hq = HQ, agr = 1500, soldiers = soldiers(25), offense = false, threats = { field(60, 0, 2, 2) } })
  check(count(o8, "clear") == 11, "coupure de banc, faction agressive : l'ancien nettoyage joue encore")

  section("champ étalé : le besoin se compte sur le champ entier")
  -- 8 nids sur 2 rangées de 4 à 8 tuiles : des groupes de 24 tuiles séparés, mais un seul champ
  local th = {}
  for i = 1, 8 do th[#th + 1] = { x = 60 + ((i - 1) % 4) * 10, y = math.floor((i - 1) / 4) * 10, kind = "spawner" } end
  local cl = Sd.clusters(th)
  check(#cl >= 2, "le champ étalé fait plusieurs groupes (" .. #cl .. ")")
  local launched = 0
  for _, g in ipairs(cl) do
    local oo = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(25), threats = { g } })
    launched = launched + count(oo, "clear")
  end
  check(launched == 0, "aucun sous-groupe d'un champ de 8 nids n'est attaqué (besoin 19 > surplus 16) (" .. launched .. ")")
  check(cl[1].wide == 8, "le groupe voit les 8 nids du champ (" .. tostring(cl[1].wide) .. ")")

  -- 5 nids en 2 groupes (3 + 2) : le champ (wide = 5, besoin 13) tient dans le surplus 16 ; la force envoyée = 13, pas 9.
  local th5 = {}
  for i = 1, 3 do th5[#th5 + 1] = { x = 60 + (i - 1) * 5, y = 0, kind = "spawner" } end
  for i = 1, 2 do th5[#th5 + 1] = { x = 60 + (i - 1) * 5, y = 30, kind = "spawner" } end
  local cl5 = Sd.clusters(th5)
  check(#cl5 == 2 and cl5[1].k == 3 and cl5[1].wide == 5, "champ de 5 nids en 2 groupes (3 + 2), wide = 5")
  local o5b = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(25), threats = { cl5[1] } })
  check(count(o5b, "clear") == Sd.clear_need(5), "expédition dimensionnée sur le champ entier (" .. count(o5b, "clear") .. " = " .. Sd.clear_need(5) .. ")")

  section("expédition : site abandonné")
  local blocked = { { x = 61, y = 1, ["until"] = 5000 } }
  local o9 = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(25), blocked = blocked, threats = { field(60, 0, 2, 2) } })
  check(count(o9, "clear") == 0, "site abandonné : pas retenté pendant le délai")
  local o10 = Sd.assign({ tick = 5000, hq = HQ, agr = 700, soldiers = soldiers(25), blocked = blocked, threats = { field(60, 0, 2, 2) } })
  check(count(o10, "clear") == 11, "délai écoulé : l'expédition repart")
  local o11 = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(25), blocked = blocked, threats = { field(-60, 0, 2, 2) } })
  check(count(o11, "clear") == 11, "un autre site n'est pas interdit")
  local o12 = Sd.assign({ tick = 100, hq = HQ, agr = 1500, soldiers = soldiers(25), blocked = blocked, threats = { field(60, 0, 2, 2) } })
  check(count(o12, "clear") == 0, "site abandonné : même une faction agressive ne le retente pas tout de suite")
  local o13 = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(25), clearing = { x = 60, y = 0, k = 4 },
    threats = { field(60, 0, 2, 2) } })
  check(count(o13, "clear") == 11, "opération en cours : poursuivie")
  -- Sans `need`, une opération en cours ne garderait que clear_need(1) = 5 soldats : les autres repartiraient en patrouille.
  local o14 = Sd.assign({ tick = 200, hq = HQ, agr = 700, soldiers = soldiers(25), clearing = { x = 60, y = 0, need = 11 },
    threats = { field(60, 0, 2, 2) } })
  check(count(o14, "clear") == 11, "opération en cours, 11 vivants : les 11 gardent leur ordre (" .. count(o14, "clear") .. ")")
  local o15 = Sd.assign({ tick = 200, hq = HQ, agr = 700, soldiers = soldiers(25), clearing = { x = 60, y = 0, need = 7 },
    threats = { field(60, 0, 2, 2) } })
  check(count(o15, "clear") == 7, "opération en cours, 7 vivants : pas de renfort (" .. count(o15, "clear") .. ")")

  section("retraite")
  check(Sd.retreat(11, 6) == true, "6 morts sur 11 : retraite")
  check(Sd.retreat(11, 5) == false, "5 morts sur 11 : on continue")
  check(Sd.retreat(10, 5) == false, "la moitié exactement : on continue")
  check(Sd.retreat(0, 0) == false, "aucune force : pas de retraite")

  section("ancien comportement inchangé")
  local old = Sd.assign({ tick = 100, hq = HQ, agr = 1500, soldiers = soldiers(10), threats = { { x = 120, y = 0, k = 2 } } })
  check(count(old, "clear") == 7, "faction agressive, menace sans genre : 7 soldats comme avant")
  local old2 = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(10), threats = { { x = 120, y = 0, k = 2 } } })
  check(count(old2, "clear") == 0, "faction pacifique, menace sans genre et sans mort : rien")

  section("carte de connaissance : les nids vus par les yeux du QG sont candidats (lot ACT-SOLDATS)")
  -- Défaut de la fumée 0.6.13 : les candidats ne venaient que de la carte du danger (nids vus en marche) ; la carte de
  -- connaissance (nids vus par les yeux du QG, des avant-postes, des éclaireurs) n'arrivait jamais à Sd.assign.
  local km = known_map({ { 60, 0, "spawner" }, { 61, 0, "spawner" }, { 60, 1, "worm" }, { 60, 2, "worm" } })
  local pts = K.enemy_points(km, 0, 0, Sd.KNOWN_R)
  check(#pts == 4, "K.enemy_points : 4 points lus à 170 tuiles (" .. #pts .. ")")
  -- Chemin d'AVANT (carte du danger seule, vide ici) : rien ne part, c'est le défaut observé.
  local avant = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(25), threats = Sd.clusters({}) })
  check(count(avant, "clear") == 0, "avant : carte du danger vide, 25 inactifs, nids connus de la carte de connaissance : rien ne part")
  local cl_k = known_clusters(km, {})
  check(#cl_k == 1 and cl_k[1].nests == 2 and cl_k[1].k == 4 and cl_k[1].known == 4, "les nids connus forment un groupe (2 nids, k 4, known 4)")
  local ok1, sm1 = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(25), threats = cl_k })
  check(count(ok1, "clear") == 11 and sm1.offense == true, "après : 25 inactifs, 2 nids + 2 vers connus : 11 soldats partent en expédition (" .. count(ok1, "clear") .. ")")
  -- Doublon : le même nid vu en marche (60,5 ; 0,5) et connu (60 ; 0) ne compte qu'une fois.
  local cand_d = { { x = 60.5, y = 0.5, kind = "spawner" } }
  local add = Sd.add_known(cand_d, { { x = 60, y = 0, kind = "spawner" }, { x = 61, y = 0, kind = "worm" } })
  check(add == 1 and #cand_d == 2, "doublon (même genre à moins de 4 tuiles) ignoré, un ver voisin gardé (" .. add .. ")")
  -- Le vieux seuil d'agressivité ne s'applique pas à une menace connue de la seule carte : la réserve est gardée.
  local km3 = known_map({ { 60, 0, "spawner" }, { 62, 0, "spawner" }, { 64, 0, "spawner" } })
  local o_ag = Sd.assign({ tick = 100, hq = HQ, agr = 1500, soldiers = soldiers(11), threats = known_clusters(km3, {}) })
  check(count(o_ag, "clear") == 0, "faction agressive, 3 nids connus de la seule carte, 11 inactifs : la réserve reste (surplus 3 < 9) (" .. count(o_ag, "clear") .. ")")
  local o_ag2 = Sd.assign({ tick = 100, hq = HQ, agr = 1500, soldiers = soldiers(11), threats = Sd.clusters({ { x = 60, y = 0, kind = "spawner" }, { x = 62, y = 0, kind = "spawner" }, { x = 64, y = 0, kind = "spawner" } }) })
  check(count(o_ag2, "clear") == 9, "les mêmes nids VUS en marche : ancien seuil inchangé, 9 soldats (" .. count(o_ag2, "clear") .. ")")
  -- Portée.
  local km_far = known_map({ { 150, 0, "spawner" } })
  check(#K.enemy_points(km_far, 0, 0, Sd.KNOWN_R) == 1, "nid à 150 tuiles : lu")
  local o_far = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(25), threats = known_clusters(km_far, {}) })
  check(count(o_far, "clear") == 0, "nid connu à 150 tuiles (> 130) : pas d'expédition")
  check(#K.enemy_points(known_map({ { 175, 0, "spawner" } }), 0, 0, Sd.KNOWN_R) == 0, "nid à 175 tuiles (> 170) : non lu")
  -- Champ trop gros connu de la carte seule : pas d'attaque suicide.
  local big = {}
  for i = 1, 8 do big[#big + 1] = { 60 + i, 0, "spawner" } end
  for i = 1, 4 do big[#big + 1] = { 60, i, "worm" } end
  local o_big = Sd.assign({ tick = 100, hq = HQ, agr = 700, soldiers = soldiers(25), threats = known_clusters(known_map(big), {}) })
  check(count(o_big, "clear") == 0, "champ connu de 8 nids + 4 vers : hors de portée (27 > 16)")
  -- Secteurs voisins : les points de part et d'autre de la frontière x = 64 sont lus, dans un ordre fixe.
  local km_b = known_map({ { 63, 0, "spawner" }, { 65, 0, "spawner" }, { 63, 70, "worm" } })
  local pb = K.enemy_points(km_b, 64, 30, 60)
  check(#pb == 3 and pb[1].x == 63 and pb[2].x == 65 and pb[3].kind == "worm", "points de secteurs voisins lus, ordre fixe")
  -- Oubli (soldats sur place : nids détruits) : le groupe disparaît, plus d'expédition.
  local gone = K.forget_enemies(km, 60, 0, 32)
  check(gone == 4 and #K.enemy_points(km, 0, 0, Sd.KNOWN_R) == 0, "K.forget_enemies : 4 points oubliés (" .. gone .. ")")
  check(#known_clusters(km, {}) == 0, "plus aucun groupe après l'oubli")
  local km_p = known_map({ { 60, 0, "spawner" }, { 120, 0, "spawner" } })
  check(K.forget_enemies(km_p, 60, 0, 10) == 1 and #K.enemy_points(km_p, 0, 0, Sd.KNOWN_R) == 1, "l'oubli ne touche que le rayon demandé")
end

local function run_quiet()
  local p0, f0 = passes, failures
  quiet = true
  suite()
  quiet = false
  local n = failures - f0
  passes, failures = p0, f0
  return n
end

suite()
print("== mutants")
local keep = {}
local function patch(t, k, v) keep[#keep + 1] = { t, k, t[k] }; t[k] = v end
local function unpatch() for i = #keep, 1, -1 do local e = keep[i]; e[1][e[2]] = e[3] end keep = {} end
local function mutant(name, apply)
  apply()
  local n = run_quiet()
  unpatch()
  check(n > 0, "mutant « " .. name .. " » détecté (" .. n .. ")")
end
mutant("pas de réserve (toute la garnison part)", function() patch(Sd, "RESERVE_MIN", 0); patch(Sd, "RESERVE_SHARE", 0) end)
mutant("réserve trop faible (4)", function() patch(Sd, "RESERVE_MIN", 4); patch(Sd, "RESERVE_SHARE", 0) end)
mutant("surplus ignoré (besoin seul)", function() patch(Sd, "surplus", function(idle) return idle end) end)
mutant("champ de n'importe quelle taille", function() patch(Sd, "clear_need", function() return 1 end) end)
mutant("portée de l'expédition infinie", function() patch(Sd, "OFFENSE_R", 1e9) end)
mutant("portée de l'expédition nulle", function() patch(Sd, "OFFENSE_R", 0) end)
mutant("tourelles adverses attaquées", function()
  local f = Sd.offense_ok
  patch(Sd, "offense_ok", function(th, hq, idle) local c = {} for k, v in pairs(th) do c[k] = v end c.rival = 0 return f(c, hq, idle) end)
end)
mutant("sans nid exigé", function()
  local f = Sd.offense_ok
  patch(Sd, "offense_ok", function(th, hq, idle) local c = {} for k, v in pairs(th) do c[k] = v end c.nests = 1 return f(c, hq, idle) end)
end)
mutant("retraite jamais", function() patch(Sd, "retreat", function() return false end) end)
mutant("retraite au premier mort", function() patch(Sd, "retreat", function(n0, lost) return lost > 0 end) end)
mutant("site abandonné retenté tout de suite", function() patch(Sd, "is_blocked", function() return false end) end)
mutant("site abandonné interdit pour toujours", function() patch(Sd, "is_blocked", function(b) return #(b or {}) > 0 end) end)
mutant("coupure de banc ignorée", function()
  local a = Sd.assign
  patch(Sd, "assign", function(i) local j = {} for k, v in pairs(i) do j[k] = v end j.offense = nil return a(j) end)
end)
mutant("force vivante ignorée (besoin du groupe seul)", function()
  local a = Sd.assign
  patch(Sd, "assign", function(i)
    local j = {} for k, v in pairs(i) do j[k] = v end
    if j.clearing then local c = {} for k, v in pairs(j.clearing) do c[k] = v end c.need = nil j.clearing = c end
    return a(j)
  end)
end)
mutant("champ entier ignoré (sous-groupe attaqué seul)", function()
  local f = Sd.clusters
  patch(Sd, "clusters", function(th) local out = f(th) for _, c in ipairs(out) do c.wide = nil end return out end)
end)
mutant("carte de connaissance ignorée (add_known inactif)", function() patch(Sd, "add_known", function() return 0 end) end)
mutant("doublons de la carte du danger comptés deux fois", function() patch(Sd, "DUP_R", 0) end)
mutant("portée de lecture des nids connus nulle", function() patch(Sd, "KNOWN_R", 0) end)
mutant("nids connus pris pour des nids vus (ancien seuil d'agressivité)", function()
  local f = Sd.clusters
  patch(Sd, "clusters", function(th) local out = f(th) for _, c in ipairs(out) do c.known = 0 end return out end)
end)
mutant("oubli de la carte de connaissance inactif", function() patch(K, "forget_enemies", function() return 0 end) end)
mutant("nids non comptés par les groupes", function()
  local f = Sd.clusters
  patch(Sd, "clusters", function(th)
    local t2 = {} for i, t in ipairs(th) do t2[i] = { x = t.x, y = t.y, killed = t.killed } end
    return f(t2)
  end)
end)
print(string.format("[SOLDATS-EXPEDITION] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
