--[[
  Lot IA3-f : test hors jeu de la CARTE DE CONNAISSANCE (shared/ai3/carte.lua). docs/IA3_CERVEAU.md §4.1, §4.2.

  Ce qu'il prouve : un secteur n'est connu que par un regard (date, gisements, nids, vers, eau) ; ressources nouvelles
  rendues une fois ; gisements triés du plus proche ; nids et vers comptés à 64 tuiles, nids près du chemin, part vue du
  voisinage, risque d'expédition (E.risk) qui monte avec ce qui est vu ; danger d'un secteur (nids, incidents décroissants,
  QG rival) ; frontière ; cible d'exploration (proche, sûre, jamais au-delà de la distance maximale, jamais exclue, a
  priori qui pousse loin du départ pour une ressource jamais vue) ; anneau sans trigonométrie ; ordre d'insertion sans
  effet (déterminisme) ; et une EXPLORATION SIMULÉE sur un monde caché : un éclaireur qui ne voit qu'à 128 tuiles trouve
  le pétrole caché, sans entrer dans la zone des nids.

  Usage : lua5.2 tests/ai3_carte_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local K = require("shared.ai3.carte")
local E = require("shared.ai3.expedition")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[AI3-CARTE] ECHEC : " .. msg) end
end

local key = K.key

-- 1. Regards et secteurs vus.
do
  local m = K.new()
  check(K.seen(m, key(0, 0)) == nil and m.n == 0, "carte neuve : rien de vu")
  local fresh = K.record(m, key(1, 2), 100, { res = { { name = "iron-ore", n = 300, a = 600000, x = 90, y = 150 } },
    nests = { { x = 100, y = 170 } }, worms = {}, water = true })
  check(#fresh == 1 and fresh[1] == "iron-ore", "1er regard : ressource nouvelle rendue")
  check(K.seen(m, key(1, 2)) == 100 and K.first_seen(m, key(1, 2)) == 100 and m.n == 1, "secteur vu, daté")
  check(K.seen_xy(m, 70, 140) == 100 and K.seen_xy(m, 140, 140) == nil, "secteur d'un point (64 × 64)")
  local again = K.record(m, key(1, 2), 500, { res = { { name = "iron-ore", n = 290, a = 580000, x = 90, y = 150 },
    { name = "coal", n = 40, a = 20000, x = 120, y = 180 } } })
  check(#again == 1 and again[1] == "coal", "2e regard : seule la ressource nouvelle est rendue")
  check(K.seen(m, key(1, 2)) == 500 and K.first_seen(m, key(1, 2)) == 100 and m.n == 1, "2e regard : date mise à jour, 1er gardé")
  check(m.found["iron-ore"] == 100 and m.found["coal"] == 500, "premier gisement vu, par ressource")
  check(K.due(m, key(1, 2), 600, 3600) == false and K.due(m, key(1, 2), 4100, 3600) and K.due(m, key(5, 5), 0, 3600),
    "regard dû : jamais vu, ou trop ancien")
  check(m.s[key(1, 2)].sp == nil, "nids : le dernier regard fait foi (le nid détruit disparaît)")
  local list = K.known_resources(m)
  check(#list == 2 and list[1] == "coal" and list[2] == "iron-ore", "ressources connues triées")
end

-- 2. Gisements triés, nids, chemin, voisinage, risque.
do
  local m = K.new()
  K.record(m, key(3, 0), 10, { res = { { name = "iron-ore", n = 100, a = 1, x = 220, y = 30 } } })
  K.record(m, key(-2, 0), 10, { res = { { name = "iron-ore", n = 100, a = 1, x = -100, y = 30 } } })
  K.record(m, key(0, 4), 10, { res = { { name = "iron-ore", n = 100, a = 1, x = 30, y = 280 } } })
  local d = K.deposits(m, "iron-ore", { x = 0, y = 0 })
  check(#d == 3 and d[1].x == -100 and d[2].x == 220 and d[3].y == 280, "gisements du plus proche au plus lointain")
  check(#K.deposits(m, "crude-oil", { x = 0, y = 0 }) == 0, "ressource jamais vue : aucun gisement")
  -- Nids et vers.
  K.record(m, key(5, 5), 10, { nests = { { x = 330, y = 330 }, { x = 350, y = 340 } }, worms = { { x = 360, y = 300 } } })
  local n, w = K.enemies_near(m, 340, 330, 64)
  check(n == 2 and w == 1, "nids et vers vus à 64 tuiles : " .. n .. ", " .. w)
  n, w = K.enemies_near(m, 500, 500, 64)
  check(n == 0 and w == 0, "loin : aucun")
  check(K.path_nests(m, { x = 0, y = 0 }, { x = 700, y = 700 }) == 2, "nids près du chemin (segment QG → site)")
  check(K.path_nests(m, { x = 0, y = 0 }, { x = 700, y = 0 }) == 0, "chemin qui passe loin des nids : 0")
  check(K.seen_pct(m, 340, 330) == 11, "part vue du voisinage : 1 secteur sur 9 = 11 % (" .. K.seen_pct(m, 340, 330) .. ")")
  -- Risque d'un site : plus on voit de nids, plus c'est risqué ; l'inconnu compte (prudence face à l'inconnu).
  local r_near = K.site_risk(m, { x = 340, y = 320 }, { x = 0, y = 0 }, 10)
  local r_far = K.site_risk(m, { x = 30, y = 280 }, { x = 0, y = 0 }, 10)
  local inputs = K.site_inputs(m, { x = 340, y = 320 }, { x = 0, y = 0 }, 10)
  check(inputs.spawners == 2 and inputs.worms == 1 and inputs.distance == 466, "entrées du risque (nids, vers, distance)")
  check(r_near == E.risk(inputs) and r_near > r_far, "risque d'expédition : site entre les nids plus risqué (" .. r_near .. " > " .. r_far .. ")")
  -- Incident : marque comptée comme perte récente.
  K.mark(m, 30, 280, 100, 600)
  local i2 = K.site_inputs(m, { x = 30, y = 280 }, { x = 0, y = 0 }, 200)
  check(i2.losses == 1 and K.site_risk(m, { x = 30, y = 280 }, { x = 0, y = 0 }, 200) > r_far, "incident récent : risque plus haut")
  local i3 = K.site_inputs(m, { x = 30, y = 280 }, { x = 0, y = 0 }, 100 + K.DANGER.mark_ttl)
  check(i3.losses == 0, "incident oublié après " .. K.DANGER.mark_ttl / 3600 .. " min")
end

-- 3. Danger d'un secteur pour l'éclaireur.
do
  local m = K.new()
  K.record(m, key(0, 0), 0, { nests = { { x = 10, y = 10 } } })
  check(K.sector_risk(m, key(1, 1), 0) == K.DANGER.nest, "nid du secteur voisin : " .. K.DANGER.nest)
  check(K.sector_risk(m, key(3, 3), 0) == 0, "loin des nids : 0")
  K.mark(m, 200, 200, 1000, 800)
  local r0 = K.sector_risk(m, key(3, 3), 1000)
  local r1 = K.sector_risk(m, key(3, 3), 1000 + K.DANGER.mark_ttl / 2)
  check(r0 == 800 and r1 == 400 and K.sector_risk(m, key(3, 3), 1000 + K.DANGER.mark_ttl) == 0,
    "incident : décroissance linéaire (" .. r0 .. ", " .. r1 .. ")")
  check(K.sector_risk(m, key(6, 6), 0, { { x = 400, y = 400 } }) == K.DANGER.rival, "QG rival à moins de 256 tuiles")
  local many = { nests = {} }
  for i = 1, 8 do many.nests[i] = { x = 70 + i, y = 70 } end
  K.record(m, key(1, 1), 0, many)
  check(K.sector_risk(m, key(1, 1), 0) == K.DANGER.cap, "plafond à " .. K.DANGER.cap)
end

-- 4. Frontière et cible.
do
  local m = K.new()
  K.record(m, key(0, 0), 0, {})
  local fr = K.frontier(m)
  check(#fr == 8, "frontière d'un secteur seul : ses 8 voisins (" .. #fr .. ")")
  for i = 2, #fr do check(fr[i - 1] < fr[i], "frontière triée") end
  -- Base vue 5 × 5 autour du QG ; nids au nord-est.
  m = K.new()
  for sy = -2, 2 do for sx = -2, 2 do K.record(m, key(sx, sy), 0, {}) end end
  K.record(m, key(2, -2), 0, { nests = { { x = 150, y = -110 }, { x = 160, y = -100 } } })
  local hq = { x = 32, y = 32 }
  local k1 = K.best_target(m, { hq = hq, me = hq, tick = 0, spawn = { x = 0, y = 0 } })
  local sx, sy = K.xy(k1)
  check(k1 ~= nil and not m.s[k1], "cible : un secteur non vu")
  check(math.max(math.abs(sx), math.abs(sy)) == 3, "cible : sur la frontière (anneau suivant), " .. sx .. ", " .. sy)
  check(not (sx >= 2 and sy <= -2), "cible : jamais à côté des nids du nord-est")
  -- L'éclaireur à l'ouest préfère la frontière de l'ouest (balayage de proche en proche).
  local kw = K.best_target(m, { hq = hq, me = { x = -150, y = 32 }, tick = 0, spawn = { x = 0, y = 0 } })
  check(K.xy(kw) < 0, "éclaireur à l'ouest : cible à l'ouest (" .. K.xy(kw) .. ")")
  -- Exclusion et distance maximale.
  local ex = { [k1] = true }
  local k2 = K.best_target(m, { hq = hq, me = hq, tick = 0, spawn = { x = 0, y = 0 }, exclude = ex })
  check(k2 ~= nil and k2 ~= k1, "secteur exclu (chemin raté) : autre cible")
  check(K.best_target(m, { hq = hq, me = hq, tick = 0, max_dist = 100 }) == nil, "rien au-delà de la distance maximale")
  -- A priori : une ressource jamais vue se cherche plutôt loin du départ de la carte.
  local mm = K.new()
  for sy = -1, 1 do for sx = -1, 1 do K.record(mm, key(sx + 8, sy), 0, {}) end end
  local hq2 = { x = 8 * 64 + 32, y = 32 }
  local ko = K.best_target(mm, { hq = hq2, me = hq2, tick = 0, res = "crude-oil", spawn = { x = 0, y = 0 } })
  check(K.xy(ko) == 10, "ressource jamais vue : vers l'extérieur (loin du départ), secteur x = " .. K.xy(ko))
  check(K.prior(mm, "crude-oil", key(20, 0), { x = 0, y = 0 }, hq2) > K.prior(mm, "crude-oil", key(4, 0), { x = 0, y = 0 }, hq2),
    "a priori croissant avec la distance au départ")
  K.record(mm, key(9, 1), 5, { res = { { name = "crude-oil", n = 3, a = 900000, x = 600, y = 100 } } })
  check(K.prior(mm, "crude-oil", key(20, 0), { x = 0, y = 0 }, hq2) == 1000, "ressource déjà vue : a priori uniforme")
end

-- 5. Anneau, pas de déplacement.
do
  local ring = K.ring(100, 100, 150, 0)
  check(#ring == 8, "anneau : 8 points")
  local ok = true
  for _, p in ipairs(ring) do
    local d = math.sqrt((p.x - 100) ^ 2 + (p.y - 100) ^ 2)
    if math.abs(d - 150) > 1.5 then ok = false end
  end
  check(ok and ring[1].x > 240 and math.abs(ring[3].x - 100.5) < 1, "anneau à 150 tuiles, de l'est vers le sud")
  local r2 = K.ring(100, 100, 150, 4)
  check(r2[1].x < -40, "anneau : octant de départ")
  local t = K.toward({ x = 0, y = 0 }, { x = 300, y = 400 }, 100)
  check(math.abs(t.x - 60) < 1e-9 and math.abs(t.y - 80) < 1e-9, "point de passage à 100 tuiles vers la cible")
  local t2 = K.toward({ x = 0, y = 0 }, { x = 30, y = 40 }, 100)
  check(t2.x == 30 and t2.y == 40, "cible proche : la cible elle-même")
end

-- 6. Déterminisme : même carte quel que soit l'ordre des regards.
do
  local obs = {}
  for i = 1, 40 do
    local sx, sy = i % 8 - 4, math.floor(i / 8) - 2 -- secteurs distincts (un regard par secteur)
    obs[#obs + 1] = { key(sx, sy), { res = (i % 3 == 0) and { { name = (i % 2 == 0) and "coal" or "stone", n = i, a = i * 10,
      x = sx * 64 + 10, y = sy * 64 + 20 } } or {}, nests = (i % 7 == 0) and { { x = sx * 64 + 5, y = sy * 64 + 5 } } or {} } }
  end
  local a, b = K.new(), K.new()
  for i = 1, #obs do K.record(a, obs[i][1], 7, obs[i][2]) end
  for i = #obs, 1, -1 do K.record(b, obs[i][1], 7, obs[i][2]) end
  local ctx = { hq = { x = 0, y = 0 }, me = { x = 0, y = 0 }, tick = 7, spawn = { x = 0, y = 0 } }
  local ka, sa = K.best_target(a, ctx)
  local kb, sb = K.best_target(b, ctx)
  check(ka == kb and sa == sb, "même cible quel que soit l'ordre des regards")
  local da, db = K.deposits(a, "coal", { x = 0, y = 0 }), K.deposits(b, "coal", { x = 0, y = 0 })
  local same = #da == #db
  for i = 1, #da do same = same and da[i].key == db[i].key end
  check(same and #da > 0, "mêmes gisements, même ordre")
end

-- 7. EXPLORATION SIMULÉE : monde caché (pétrole à 600 tuiles au nord-est derrière rien, nids au sud-est), éclaireur
--    à 9 tuiles par seconde, regard tous les 64 tuiles parcourues (œil de 128), fuite si un nid VU est à 40 tuiles.
do
  local world = { oil = { x = 420, y = -430 }, nests = { { x = 250, y = 260 }, { x = 280, y = 230 }, { x = 300, y = 300 } } }
  local function observe(m, k, tick)
    local sx, sy = K.xy(k)
    local x0, y0 = sx * 64, sy * 64
    local o = { res = {}, nests = {} }
    if world.oil.x >= x0 and world.oil.x < x0 + 64 and world.oil.y >= y0 and world.oil.y < y0 + 64 then
      o.res[1] = { name = "crude-oil", n = 4, a = 1200000, x = world.oil.x, y = world.oil.y }
    end
    for _, p in ipairs(world.nests) do
      if p.x >= x0 and p.x < x0 + 64 and p.y >= y0 and p.y < y0 + 64 then o.nests[#o.nests + 1] = p end
    end
    K.record(m, k, tick, o)
  end
  local A = require("shared.faction.adversaire")
  local m = K.new()
  local hq = { x = 0, y = 0 }
  local function look_eye(x, y, r, tick)
    for _, k in ipairs(A.visible({ { x = x, y = y, r = r } })) do
      if not m.s[k] then observe(m, k, tick) end
    end
  end
  look_eye(0, 0, K.EYE.hq, 0)
  local me = { x = 0, y = 0 }
  local walked, tick, found, closest = 0, 0, nil, 1e9
  for _ = 1, 400 do
    if #K.deposits(m, "crude-oil") > 0 then found = tick break end
    local k = K.best_target(m, { hq = hq, me = me, tick = tick, res = "crude-oil", spawn = { x = -480, y = 480 } })
    if not k then break end
    local cx, cy = K.center(K.xy(k))
    local wp = K.toward(me, { x = cx, y = cy }, 64)
    local d = math.sqrt((wp.x - me.x) ^ 2 + (wp.y - me.y) ^ 2)
    me = wp
    walked = walked + d
    tick = tick + math.floor(d / 9 * 60)
    look_eye(me.x, me.y, K.EYE.explorer, tick)
    for _, p in ipairs(world.nests) do
      local dd = math.sqrt((p.x - me.x) ^ 2 + (p.y - me.y) ^ 2)
      if dd < closest then closest = dd end
    end
  end
  check(found ~= nil, "pétrole caché trouvé par l'exploration simulée")
  check(found and found <= 10 * 3600, string.format("en moins de 10 min de marche (%.1f min, %d tuiles)", (found or 0) / 3600, walked))
  check(closest > 100, string.format("jamais à moins de 100 tuiles des nids (au plus près : %d)", math.floor(closest)))
end

print(string.format("[AI3-CARTE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
