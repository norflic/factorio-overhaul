--[[
  Lot COUVERTURE : test hors jeu de la règle pure shared/team/couverture.lua (choix des positions de tourelles par
  couverture maximale) et de la règle pure shared/team/reconstruction.lua (registre des bâtiments détruits, ordre et
  patience de la reconstruction).
    §1 objectif : H croissante et concave, regroupement des bâtiments, exposition relative ;
    §2 GLOUTON CONTRE FORCE BRUTE : 400 petites instances tirées d'une graine fixe ; sans espacement le rapport doit
       dépasser 1 − 1/e (63,2 %, garantie de la sous-modularité) ; avec l'espacement (un filtre) le rapport est mesuré et
       doit rester au-dessus du même seuil sur ces instances ;
    §3 espacement : jamais deux tourelles plus proches que Cov.SEP_PCT % de la portée, sauf relâchement déclaré ;
    §4 couverture : sur des bases allongées, le glouton couvre au moins autant que les 4 diagonales fixes d'avant ;
    §5 exposition, tourelles déjà posées, épreuve du moteur, relâchement, déterminisme (ordre d'entrée mélangé) ;
    §6 menaces (carte du danger + bâtiments détruits) ;
    §7 reconstruction : registre, patience, abandon, lots, priorité ;
    §8 aucun nom du jeu, aucun pairs/hasard/trigonométrie ;
    §9 mutants : chaque règle retirée est vue.
  Usage : lua5.2 tests/couverture_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC_COV = read("shared/team/couverture.lua")
local SRC_REC = read("shared/team/reconstruction.lua")

local function load_mod(name, src)
  local fn, err = load(src, "=" .. name, "t")
  if not fn then return nil, err end
  local ok, mod = pcall(fn)
  if not ok then return nil, mod end
  return mod
end

-- Générateur congruentiel linéaire (graine fixe : mêmes instances à chaque passage).
local function lcg(seed)
  local s = seed
  return function(n)
    s = (s * 1103515245 + 12345) % 2147483648
    return (math.floor(s / 65536) % n) + 1
  end
end

local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

local function suite(Cov, Rc, n_instances)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end
  local info = {}
  local light = (n_instances or 400) < 400 -- passage des mutants : moins d'instances
  local N3, N4 = light and 12 or 60, light and 24 or 60

  -- §1 -------------------------------------------------------------------------------------------------------
  do
    local concave, increasing = true, true
    for k = 1, Cov.H_MAX - 1 do
      if Cov.h(k + 1) <= Cov.h(k) then increasing = false end
      if k >= 2 and (Cov.h(k + 1) - Cov.h(k)) >= (Cov.h(k) - Cov.h(k - 1)) then concave = false end
    end
    check(Cov.h(0) == 0 and Cov.h(1) == 100, "§1 H(0) = 0 et H(1) = 100")
    check(increasing and Cov.h(Cov.H_MAX + 5) == Cov.h(Cov.H_MAX), "§1 H croissante jusqu'au plafond")
    check(concave and (Cov.h(2) - Cov.h(1)) < Cov.h(1) - Cov.h(0), "§1 H concave (gains décroissants : sous-modularité)")
    local cl = Cov.cluster({ { x = 0.5, y = 0.5, v = 2 }, { x = 2.5, y = 2.5, v = 6 }, { x = 9.5, y = 0.5, v = 1 }, { x = 1, y = 1, v = 0 } })
    check(#cl == 2 and cl[1].v == 8 and cl[2].v == 1, "§1 regroupement par cases de 4 tuiles, valeur nulle ignorée")
    check(math.abs(cl[1].x - (0.5 * 2 + 2.5 * 6) / 8) < 1e-9, "§1 centre du regroupement pondéré par la valeur")
    local many = {}
    for i = 1, 200 do many[i] = { x = (i % 40) * 4 + 1, y = math.floor(i / 40) * 4 + 1, v = 1 + (i % 7) } end
    check(#Cov.cluster(many) <= Cov.MAX_CLUSTERS, "§1 regroupements bornés (" .. #Cov.cluster(many) .. ")")
    check(Cov.role_value("labo") > Cov.role_value("foreuse") and Cov.role_value("foreuse") > Cov.role_value("logistique")
      and Cov.role_value("logistique") > 0 and Cov.role_value("inconnu") == 0, "§1 valeurs par rôle ordonnées, rôle inconnu = 0")
  end

  -- §2 Glouton contre force brute ---------------------------------------------------------------------------
  do
    local rnd = lcg(20261028)
    local worst_free, worst_sep, sum_free, n_inst = 9, 9, 0, 0
    local function subsets(list, k, from, cur, out)
      if #cur == k then
        local copy = {}
        for i, v in ipairs(cur) do copy[i] = v end
        out[#out + 1] = copy
        return
      end
      for i = from, #list do
        cur[#cur + 1] = list[i]
        subsets(list, k, i + 1, cur, out)
        cur[#cur] = nil
      end
    end
    local sep_save = Cov.SEP_PCT
    for inst = 1, (n_instances or 400) do
      local assets = {}
      for i = 1, 4 + rnd(5) do assets[i] = { x = rnd(41) - 21, y = rnd(41) - 21, v = rnd(8) } end
      local cands = {}
      for i = 1, 12 do cands[i] = { x = 2 * (rnd(21) - 11), y = 2 * (rnd(21) - 11) } end
      local k = 1 + rnd(3)
      local spec = { assets = assets, range = 18, candidates = cands }
      for pass_sep = 1, 2 do
        Cov.SEP_PCT = (pass_sep == 1) and 0 or sep_save
        local picks, st = Cov.plan(spec, k)
        local got = Cov.objective(st)
        -- optimum : tous les sous-ensembles de taille |picks| des candidats qui couvrent quelque chose et respectent
        -- l'espacement de ce passage
        local base = Cov.new(spec)
        local usable = {}
        for _, c in ipairs(base.cands) do usable[#usable + 1] = { x = c.x, y = c.y, cov = c.cov } end
        local all = {}
        subsets(usable, #picks, 1, {}, all)
        local best = 0
        local sep = 18 * Cov.SEP_PCT / 100
        for _, sset in ipairs(all) do
          local okset = true
          for a = 1, #sset do
            for b = a + 1, #sset do if dist(sset[a], sset[b]) < sep - 1e-9 then okset = false end end
          end
          if okset then
            local kk = {}
            for i = 1, #base.clusters do kk[i] = 0 end
            for _, c in ipairs(sset) do for _, i in ipairs(c.cov) do kk[i] = kk[i] + 1 end end
            local v = 0
            for i = 1, #base.clusters do v = v + base.V[i] * Cov.h(kk[i]) end
            if v > best then best = v end
          end
        end
        if best > 0 and #picks == k then
          local r = got / best
          if pass_sep == 1 then
            if r < worst_free then worst_free = r end
            sum_free = sum_free + r
            n_inst = n_inst + 1
          elseif r < worst_sep then worst_sep = r end
          check(r <= 1 + 1e-9, "§2 le glouton ne dépasse pas l'optimum (instance " .. inst .. ")")
        end
      end
    end
    Cov.SEP_PCT = sep_save
    local bound = 1 - 1 / math.exp(1)
    check(n_inst >= math.floor((n_instances or 400) * 0.75), "§2 assez d'instances comparées (" .. n_inst .. ")")
    check(worst_free >= bound, string.format("§2 sans espacement, glouton/optimum >= 1 - 1/e (pire %.3f)", worst_free))
    check(worst_sep >= bound, string.format("§2 avec espacement, glouton/optimum >= 1 - 1/e sur ces instances (pire %.3f)", worst_sep))
    info.worst_free, info.worst_sep, info.mean_free, info.n_inst = worst_free, worst_sep, sum_free / math.max(1, n_inst), n_inst
  end

  -- §3 Espacement -----------------------------------------------------------------------------------------------
  do
    local rnd = lcg(7)
    local bad, tried = 0, 0
    for _ = 1, N3 do
      local assets = {}
      for i = 1, 5 + rnd(10) do assets[i] = { x = rnd(31) - 16, y = rnd(31) - 16, v = rnd(8) } end
      local picks = Cov.plan({ assets = assets, range = 18 }, 5)
      tried = tried + 1
      for i = 1, #picks do
        check(picks[i].relaxed == 0, "§3 espacement plein tant que des candidats passent")
        for j = i + 1, #picks do if dist(picks[i], picks[j]) < 18 * Cov.SEP_PCT / 100 - 1e-9 then bad = bad + 1 end end
      end
    end
    check(bad == 0 and tried == N3, "§3 jamais deux tourelles plus proches que l'espacement (" .. bad .. " paire(s))")
    -- Le cas du DC : une base compacte, 4 tourelles, aucune « à deux cases d'une autre ».
    local base = {}
    for i = 0, 5 do base[#base + 1] = { x = (i % 3) * 3 - 3, y = math.floor(i / 3) * 3 - 2, v = 5 } end
    local picks = Cov.plan({ assets = base, range = 18 }, 4)
    local pos = {}
    for i, p in ipairs(picks) do pos[i] = p end
    check(#picks == 4 and Cov.min_gap(pos) >= 18 * Cov.SEP_PCT / 100 - 1e-9, string.format("§3 base compacte, 4 tourelles : écart minimal %.1f tuiles", Cov.min_gap(pos) or -1))
    info.compact_gap = Cov.min_gap(pos)
  end

  -- §4 Couverture contre les 4 diagonales fixes d'avant -------------------------------------------------------
  do
    local diag = { { 7, 7 }, { -7, -7 }, { 7, -7 }, { -7, 7 } }
    local rnd = lcg(99)
    local win, tie, loss = 0, 0, 0
    local sum_g, sum_o = 0, 0
    for _ = 1, N4 do
      -- base allongée : une ligne de 30 à 70 tuiles, orientée au hasard, avec quelques bâtiments de chaque côté
      local len, horiz = 30 + rnd(41), rnd(2) == 1
      local assets = {}
      for i = 0, 7 do
        local u = (i / 7 - 0.5) * len
        assets[#assets + 1] = { x = horiz and u or rnd(7) - 4, y = horiz and rnd(7) - 4 or u, v = 1 + rnd(8) }
      end
      local old = {}
      for _, o in ipairs(diag) do old[#old + 1] = { x = o[1], y = o[2] } end
      local new = Cov.plan({ assets = assets, range = 18 }, 4)
      local cn, co = Cov.covered_fraction(assets, new, 18), Cov.covered_fraction(assets, old, 18)
      sum_g, sum_o = sum_g + cn, sum_o + co
      if cn > co + 1e-9 then win = win + 1 elseif cn < co - 1e-9 then loss = loss + 1 else tie = tie + 1 end
    end
    check(loss == 0, string.format("§4 jamais moins de valeur couverte que les 4 diagonales (%d gagnée(s), %d égale(s), %d perdue(s))", win, tie, loss))
    check(win >= math.floor(N4 * 2 / 3), "§4 couvre plus que les diagonales sur les bases allongées (" .. win .. " sur " .. N4 .. ")")
    check(sum_g > sum_o, "§4 couverture moyenne supérieure")
    info.cov_new, info.cov_old = sum_g / N4, sum_o / N4
  end

  -- §5 Exposition, tourelles posées, épreuve du moteur, relâchement, déterminisme -------------------------------
  do
    -- Deux groupes de valeur égale à 50 tuiles l'un de l'autre, menace à l'est : la 1re tourelle va à l'est.
    local assets = { { x = -25, y = 0, v = 5 }, { x = 25, y = 0, v = 5 } }
    local east = Cov.plan({ assets = assets, range = 18, threats = { { x = 90, y = 0 } } }, 1)
    local west = Cov.plan({ assets = assets, range = 18, threats = { { x = -90, y = 0 } } }, 1)
    check(east[1] and east[1].x > 0 and west[1] and west[1].x < 0, "§5 la 1re tourelle va du côté de la menace")
    -- À gain égal (un seul bâtiment), la tourelle se place du côté de la menace
    local lone_e = Cov.plan({ assets = { { x = 0, y = 0, v = 5 } }, range = 18, threats = { { x = 90, y = 0 } } }, 1)
    local lone_w = Cov.plan({ assets = { { x = 0, y = 0, v = 5 } }, range = 18, threats = { { x = -90, y = 0 } } }, 1)
    check(lone_e[1] and lone_e[1].x >= 8 and lone_w[1] and lone_w[1].x <= -8, "§5 à gain égal, la tourelle se place du côté de la menace")
    -- Gain d'exposition : à menace à l'est, le bâtiment de l'est vaut plus
    local st = Cov.new({ assets = assets, range = 18, threats = { { x = 90, y = 0 } } })
    local ve, vw
    for i, c in ipairs(st.clusters) do if c.x > 0 then ve = st.V[i] else vw = st.V[i] end end
    check(ve > vw and ve <= 2 * vw + 1, "§5 valeur majorée du bâtiment exposé, au plus du double")
    -- menace hors de portée : sans effet
    local far = Cov.new({ assets = assets, range = 18, threats = { { x = 5000, y = 0 } } })
    check(far.V[1] == far.V[2], "§5 menace hors de portée : aucune majoration")
    -- Tourelles déjà posées : comptées (la 1re nouvelle va couvrir l'autre groupe)
    local one = Cov.plan({ assets = { { x = -25, y = 0, v = 5 }, { x = 25, y = 0, v = 9 } }, range = 18, turrets = { { x = 25, y = 0 } } }, 1)
    check(one[1] and one[1].x < 0, "§5 une tourelle déjà posée couvre : la nouvelle va ailleurs")
    -- Épreuve du moteur : la meilleure place est refusée, la suivante est prise
    local s2 = Cov.new({ assets = { { x = 0, y = 0, v = 5 } }, range = 18 })
    local first = Cov.next(Cov.new({ assets = { { x = 0, y = 0, v = 5 } }, range = 18 }))
    local refused = {}
    local second = Cov.next(s2, function(x, y)
      if x == first.x and y == first.y then refused[#refused + 1] = true return false end
      return true
    end)
    check(#refused == 1 and second and (second.x ~= first.x or second.y ~= first.y), "§5 place refusée par le moteur : la suivante est prise")
    -- Relâchement : trois candidats serrés, trois tourelles voulues
    local tight = { { x = 0, y = 0 }, { x = 2, y = 0 }, { x = 4, y = 0 } }
    local rel = Cov.plan({ assets = { { x = 1, y = 0, v = 5 } }, range = 18, candidates = tight }, 3)
    local distinct = {}
    for _, p in ipairs(rel) do distinct[p.x .. "," .. p.y] = true end
    local nd = 0
    for _ in pairs(distinct) do nd = nd + 1 end
    check(#rel == 3 and nd == 3 and rel[2].relaxed > 0, "§5 espacement relâché (déclaré) quand plus rien ne passe, positions distinctes")
    -- Plus de candidat : rend moins de positions
    local none = Cov.plan({ assets = { { x = 1, y = 0, v = 5 } }, range = 18, candidates = tight }, 5)
    check(#none == 3, "§5 jamais plus de positions que de candidats")
    check(#Cov.plan({ assets = {}, range = 18 }, 3) == 0, "§5 aucun bâtiment : aucune position")
    -- Déterminisme et ordre d'entrée
    local rnd = lcg(5)
    local list = {}
    for i = 1, 14 do list[i] = { x = rnd(41) - 21, y = rnd(41) - 21, v = rnd(8) } end
    local a = Cov.plan({ assets = list, range = 18, threats = { { x = 70, y = 10 } } }, 4)
    local rev = {}
    for i = #list, 1, -1 do rev[#rev + 1] = list[i] end
    local b = Cov.plan({ assets = rev, range = 18, threats = { { x = 70, y = 10 } } }, 4)
    local c = Cov.plan({ assets = list, range = 18, threats = { { x = 70, y = 10 } } }, 4)
    local same_ab, same_ac = #a == #b, #a == #c
    for i = 1, #a do
      same_ab = same_ab and b[i] and a[i].x == b[i].x and a[i].y == b[i].y
      same_ac = same_ac and c[i] and a[i].x == c[i].x and a[i].y == c[i].y
    end
    check(same_ab, "§5 même résultat quel que soit l'ordre des bâtiments")
    check(same_ac, "§5 même entrée, même sortie")
    -- Large base : le coût reste borné
    local big = {}
    for i = 1, 400 do big[i] = { x = (i % 40) * 3, y = math.floor(i / 40) * 3, v = 1 + i % 5 } end
    local t0 = os.clock()
    local bigp, bst = Cov.plan({ assets = big, range = 18 }, 6)
    check(#bigp == 6 and #bst.cands <= Cov.MAX_CANDS, "§5 400 bâtiments : 6 positions, candidats bornés (" .. #bst.cands .. ")")
    info.big_ms = (os.clock() - t0) * 1000
    -- Réglage de la portée : lue du prototype, jamais fixe
    local short = Cov.plan({ assets = { { x = 0, y = 0, v = 5 }, { x = 30, y = 0, v = 5 } }, range = 10 }, 2)
    local long = Cov.plan({ assets = { { x = 0, y = 0, v = 5 }, { x = 30, y = 0, v = 5 } }, range = 40 }, 2)
    check(short[1] and long[1] and Cov.covered_fraction({ { x = 0, y = 0, v = 5 }, { x = 30, y = 0, v = 5 } }, short, 10) == 1
      and Cov.covered_fraction({ { x = 0, y = 0, v = 5 }, { x = 30, y = 0, v = 5 } }, { long[1] }, 40) == 1,
      "§5 la portée du prototype décide : courte, 2 tourelles ; longue, une seule suffit")
    -- Rayon utile : un bâtiment à 16 tuiles n'est pas couvert par une portée de 18 (COVER_PCT)
    check(Cov.covered_fraction({ { x = 16, y = 0, v = 5 } }, { { x = 0, y = 0 } }, 18) == 0
      and Cov.covered_fraction({ { x = 12, y = 0, v = 5 } }, { { x = 0, y = 0 } }, 18) == 1, "§5 rayon utile : 75 % de la portée")
  end

  -- §6 Menaces ---------------------------------------------------------------------------------------------------
  do
    local now = 300000
    local map = { threats = { { x = 100, y = 5, k = "spawner", r = 30, t = 0 } },
      deaths = { { x = -50, y = 7, t = 250000 }, { x = 3, y = 3, t = 250000, home = true }, { x = 200, y = 0, t = 0 } } }
    local pts = Cov.threat_points(map, { { x = 10, y = 10, t = 290000 }, { x = 11, y = 10, t = 290000 }, { x = 80, y = 80, t = 0 } }, now)
    -- nid, mort lointaine hors fenêtre (une heure), mort au QG ignorée, bâtiment détruit récent (les deux voisins fusionnent)
    local found = {}
    for _, p in ipairs(pts) do found[#found + 1] = p.x .. "," .. p.y end
    check(#pts == 3 and found[1] == "100,5" and found[2] == "-50,7" and found[3] == "10,10",
      "§6 menaces : nid, mort récente, bâtiment détruit ; mort au QG et vieilles pertes écartées (" .. table.concat(found, " ") .. ")")
    check(#Cov.threat_points(nil, nil, 0) == 0, "§6 sans carte ni pertes : aucune menace")
    check(#Cov.threat_points(nil, { { x = 80, y = 80, t = 0 } }, Cov.HITS_TTL + 10) == 0 and #Cov.threat_points(nil, { { x = 80, y = 80, t = 0 } }, Cov.HITS_TTL - 10) == 1, "§6 un bâtiment détruit il y a plus de 30 min ne compte plus")
  end

  -- §7 Reconstruction --------------------------------------------------------------------------------------------
  do
    local st = Rc.new()
    check(Rc.pending(st) == 0 and not Rc.hold_upgrades(st), "§7 registre vide : rien en attente, améliorations libres")
    local k1 = Rc.record(st, { name = "A", x = 10, y = 10, dir = 0, item = "ia", value = 8 }, 1000)
    local k2 = Rc.record(st, { name = "B", x = 12, y = 10, dir = 2, item = "ib", value = 1 }, 1010)
    local k3 = Rc.record(st, { name = "C", x = 100, y = 100, dir = 0, item = "ic", value = 5 }, 1020)
    check(Rc.pending(st) == 3 and Rc.hold_upgrades(st), "§7 trois pertes en attente : les améliorations attendent")
    check(#Rc.due(st, 1000 + Rc.CALM - 1) == 0, "§7 patience : rien avant le calme")
    local due = Rc.due(st, 1000 + Rc.CALM + 100)
    check(#due == 3 and due[1].key == k1 and due[2].key == k3 and due[3].key == k2, "§7 ordre par valeur décroissante, puis date")
    -- lot : le plus précieux et ses voisins de 12 tuiles
    local batch = Rc.batch(st, due, due[1], 12, 12)
    check(#batch == 2 and batch[1].key == k1 and batch[2].key == k2, "§7 lot de voisins (rayon 12) : le précieux et sa voisine")
    check(#Rc.batch(st, due, due[1], 1, 12) == 1, "§7 lot borné à 1 : une seule pièce")
    local items = Rc.items(batch)
    check(#items == 2 and items[1][1] == "ia" and items[1][2] == 1 and items[2][1] == "ib", "§7 objets du lot, triés, dénombrés")
    local same = Rc.items({ { item = "ia" }, { item = "ia" }, { item = "zz" } })
    check(same[1][1] == "ia" and same[1][2] == 2 and same[2][1] == "zz", "§7 objets identiques additionnés")
    -- tâche prise : plus proposée
    Rc.claim(st, { k1, k2 }, "tache-1")
    check(#Rc.due(st, 5000) == 1 and Rc.due(st, 5000)[1].key == k3, "§7 les pièces d'une tâche prise ne sont plus proposées")
    Rc.release(st, "tache-1")
    check(#Rc.due(st, 5000) == 3, "§7 tâche abandonnée : ses pièces reviennent")
    Rc.done(st, k1)
    check(Rc.pending(st) == 2, "§7 pièce refaite : retirée")
    -- défèrement
    Rc.defer(st, k3, 6000, 5000)
    check(#Rc.due(st, 5500) == 1 and #Rc.due(st, 6000) == 2, "§7 pièce différée (ennemis près d'elle) jusqu'à la date")
    -- même place détruite de nouveau : patience doublée, puis abandon
    local st2 = Rc.new()
    local ka = Rc.record(st2, { name = "A", x = 1, y = 1, dir = 0, item = "ia", value = 3 }, 0)
    local c1 = Rc.calm_for(st2.lost[ka])
    Rc.done(st2, ka)
    local kb = Rc.record(st2, { name = "A", x = 1, y = 1, dir = 0, item = "ia", value = 3 }, 100)
    check(kb == ka, "§7 la même place garde la même clé")
    check(st2.lost[kb].losses == 2 and Rc.calm_for(st2.lost[kb]) == 2 * c1, "§7 deuxième destruction au même endroit : patience doublée")
    for i = 1, 10 do
      Rc.done(st2, ka)
      Rc.record(st2, { name = "A", x = 1, y = 1, dir = 0, item = "ia", value = 3 }, 100 + i)
    end
    check(st2.lost[ka].abandoned and #Rc.due(st2, 1e9) == 0 and not Rc.hold_upgrades(st2),
      "§7 détruit trop souvent au même endroit : abandonné, n'empêche plus d'améliorer")
    check(Rc.calm_for({ losses = 99 }) <= Rc.CALM_MAX, "§7 patience bornée")
    -- priorité de tâche
    check(Rc.task_prio(8) > Rc.task_prio(1) and Rc.task_prio(8) < 90 and Rc.task_prio(1) >= 70, "§7 priorité de tâche selon la valeur, sous l'urgence (90)")
    -- purge des anciennes pertes
    local st3 = Rc.new()
    Rc.record(st3, { name = "A", x = 1, y = 1, dir = 0, item = "ia", value = 3 }, 0)
    Rc.prune(st3, Rc.TTL + 1)
    check(Rc.pending(st3) == 0, "§7 une perte jamais refaite finit par être oubliée")
    -- contrôle de cohérence (lot POTEAUX) : seules les places INCONNUES du registre sont à inscrire
    local sa = Rc.new()
    local known = Rc.record(sa, { name = "P", x = 1.5, y = 1.5, dir = 0, item = "ip", value = 1 }, 0)
    local gone = Rc.record(sa, { name = "P", x = 2.5, y = 1.5, dir = 0, item = "ip", value = 1 }, 0)
    sa.lost[gone].abandoned = true
    local unk = Rc.unknown(sa, { { name = "P", x = 1.5, y = 1.5 }, { name = "P", x = 2.5, y = 1.5 }, { name = "P", x = 3.5, y = 1.5 },
      { name = "Q", x = 1.5, y = 1.5 } })
    check(#unk == 2 and unk[1].x == 3.5 and unk[2].name == "Q", "§7 contrôle : ni la pièce en attente ni l'abandonnée ne sont réinscrites, les inconnues oui")
    check(known ~= nil and #Rc.unknown(sa, {}) == 0, "§7 contrôle : liste vide, rien")
    -- pièce sans objet pour la poser : non proposée
    local st4 = Rc.new()
    Rc.record(st4, { name = "A", x = 1, y = 1, dir = 0, value = 3 }, 0)
    check(#Rc.due(st4, 1e6) == 0, "§7 sans objet pour la poser, une pièce n'est pas proposée")
  end

  return pass, fail, msgs, info
end

local Cov0 = assert(load_mod("couverture", SRC_COV))
package.loaded["shared.team.couverture"] = Cov0
local Rc0 = assert(load_mod("reconstruction", SRC_REC))
package.loaded["shared.team.reconstruction"] = Rc0

local pass, fail, msgs, info = suite(Cov0, Rc0, 400)
for _, m in ipairs(msgs) do print("[COUVERTURE] ECHEC : " .. m) end
print(string.format("[COUVERTURE] glouton/optimum sur %d instances : pire %.3f sans espacement (moyenne %.3f), pire %.3f avec ; 1 - 1/e = %.3f",
  info.n_inst, info.worst_free, info.mean_free, info.worst_sep, 1 - 1 / math.exp(1)))
print(string.format("[COUVERTURE] bases allongées, 4 tourelles : valeur couverte %.1f %% (glouton) contre %.1f %% (4 diagonales d'avant) ; base compacte : écart minimal %.1f tuiles ; 400 bâtiments : %.1f ms",
  100 * info.cov_new, 100 * info.cov_old, info.compact_gap or 0, info.big_ms))

-- §8 Source : aucun nom du jeu, aucun hasard, aucun pairs, aucune trigonométrie ------------------------------------
for _, file in ipairs({ "shared/team/couverture.lua", "shared/team/reconstruction.lua" }) do
  local src = read(file)
  local code = src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  local clean = not code:find("[^i]pairs%(") and not code:find("math.random", 1, true) and not code:find("math.sin", 1, true)
    and not code:find("math.cos", 1, true) and not code:find("math.atan", 1, true) and not code:find("os.time", 1, true)
    and not code:find("%f[%w_]game%f[^%w_]") and not code:find("%f[%w_]global%f[^%w_]")
  if clean then pass = pass + 1 else
    fail = fail + 1
    print("[COUVERTURE] ECHEC : " .. file .. " contient pairs, hasard, trigonométrie, game ou global")
  end
  local T = require("shared.team.config")
  local named = false
  for _, it in ipairs({ T.turret_ammo, "gun-turret", "iron-plate", "lab", "stone-furnace", "iron-chest", "transport-belt" }) do
    if code:find('"' .. it .. '"', 1, true) then named = true end
  end
  if not named then pass = pass + 1 else
    fail = fail + 1
    print("[COUVERTURE] ECHEC : " .. file .. " nomme un objet du jeu")
  end
end

-- §9 Mutants -----------------------------------------------------------------------------------------------------------
local MUTANTS = {
  -- couverture.lua
  { "cov", "sans espacement", "if not m or m >= sep2 then", "if true then" },
  { "cov", "exposition ignorée", "st.V[i] = c.v * (10000 + Cov.EXPO_PCT * ex[i])", "st.V[i] = c.v * 10000" },
  { "cov", "tourelles posées non comptées", "if d2(c.x, c.y, t.x, t.y) <= st.rc2 then st.k[i] = st.k[i] + 1 end",
    "if false then st.k[i] = st.k[i] + 1 end" },
  { "cov", "rayon utile = portée entière", "local rc = range * Cov.COVER_PCT / 100\n  local st = {", "local rc = range\n  local st = {" },
  { "cov", "départage vers la menace inversé", "if has_threat then e.t1 = near_threat_d2(st, c.x, c.y) or math.huge",
    "if has_threat then e.t1 = -(near_threat_d2(st, c.x, c.y) or 0)" },
  { "cov", "jamais de relâchement", "local seps = { st.sep, st.sep / 2, 0 }", "local seps = { st.sep }" },
  { "cov", "épreuve du moteur ignorée", "if not ok or ok(c.x, c.y) then", "if true then" },
  { "cov", "pire gain d'abord", "if a.g ~= b.g then return a.g > b.g end", "if a.g ~= b.g then return a.g < b.g end" },
  { "cov", "H linéaire", "Cov.H = { [0] = 0, 100, 115, 125, 132, 137, 140, 142, 143 }",
    "Cov.H = { [0] = 0, 100, 200, 300, 400, 500, 600, 700, 800 }" },
  { "cov", "menace sans portée", "if q <= reach2 and (not best or q < best) then best = q end", "if (not best or q < best) then best = q end" },
  { "cov", "candidat réutilisé", "        c.used = true\n        st.turrets[#st.turrets + 1]", "        st.turrets[#st.turrets + 1]" },
  { "cov", "valeur ignorée au regroupement", "c.sx, c.sy, c.v, c.n = c.sx + a.x * a.v, c.sy + a.y * a.v, c.v + a.v, c.n + 1",
    "c.sx, c.sy, c.v, c.n = c.sx + a.x * a.v, c.sy + a.y * a.v, 1, c.n + 1" },
  { "cov", "morts au QG comptées", "if not d.home and tick - d.t < D.HOUR then add(d.x, d.y) end", "if tick - d.t < D.HOUR then add(d.x, d.y) end" },
  { "cov", "bâtiments détruits éternels", "if tick - h.t < Cov.HITS_TTL then add(h.x, h.y) end", "add(h.x, h.y)" },
  -- reconstruction.lua
  { "rec", "sans patience", "if tick - r.tick >= Rc.calm_for(r) then", "if true then" },
  { "rec", "patience fixe", "return math.min(Rc.CALM_MAX, Rc.CALM * (2 ^ (r.losses - 1)))", "return Rc.CALM" },
  { "rec", "jamais d'abandon", "if r.losses > Rc.MAX_LOSSES then r.abandoned = true end", "" },
  { "rec", "ordre sans valeur", "if a.value ~= b.value then return a.value > b.value end", "" },
  { "rec", "tâche prise toujours proposée", "if not r.claimed and not r.abandoned", "if not r.abandoned" },
  { "rec", "pièce différée proposée", "and (not r.retry or tick >= r.retry)", "" },
  { "rec", "lot sans rayon", "if #out < max and (r == seed or d2(r, seed) <= radius * radius) then", "if #out < max then" },
  { "rec", "oubli jamais", "if tick - r.tick > Rc.TTL then st.lost[k] = nil end", "" },
  { "rec", "objets non additionnés", "n[r.item] = (n[r.item] or 0) + 1", "n[r.item] = 1" },
  { "rec", "priorité sans valeur", "return math.min(Rc.PRIO_MAX, Rc.PRIO_BASE + value)", "return Rc.PRIO_BASE" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local src = (m[1] == "cov") and SRC_COV or SRC_REC
  local a, b = src:find(m[3], 1, true)
  if not a then kept[#kept + 1] = m[2] .. " (motif absent)" else
    local msrc = src:sub(1, a - 1) .. m[4] .. src:sub(b + 1)
    local mod = load_mod(m[1], msrc)
    local f2 = 1
    if mod then
      package.loaded["shared.team.couverture"] = (m[1] == "cov") and mod or Cov0
      local cov, rec = (m[1] == "cov") and mod or Cov0, (m[1] == "rec") and mod or Rc0
      local ok, _, ff = pcall(suite, cov, rec, 50)
      f2 = ok and ff or 1
    end
    if f2 > 0 then refused = refused + 1 else kept[#kept + 1] = m[2] end
  end
end
package.loaded["shared.team.couverture"] = Cov0
if #kept == 0 then pass = pass + 1 else
  fail = fail + 1
  print("[COUVERTURE] ECHEC : mutants NON refusés : " .. table.concat(kept, " ; "))
end
print(string.format("[COUVERTURE] mutants refusés : %d sur %d", refused, #MUTANTS))

print(string.format("[COUVERTURE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
