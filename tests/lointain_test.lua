--[[
  Lot CENTRALE : test hors jeu de la centrale à distance (shared/team/lointain.lua, shared/ai3/carte.lua pour l'eau et les
  couloirs, P.pole_chain à longueur réglable). Lua pur, moins de 10 s.
    §1 rives d'un secteur : rive droite, rive concave, mare d'une tuile et filet d'eau refusés, eau profonde de 1 tuile
       refusée, espacement, tri (distance, puis y, puis x), ordre de construction de l'eau sans effet ;
    §2 carrefour d'accroche (clamp), nombre de poteaux, découpage en tronçons ;
    §3 carte : l'eau est une trouvaille (second retour de K.record, compteur, perte), K.waters trié et filtré, couloir
       (nid à 31 et 33 tuiles, secteur non vu, QG rival, sens indifférent), a priori de l'eau ;
    §4 règles d'acceptation d'un couloir et d'un site, porte de la centrale ;
    §5 ligne de 320 tuiles par P.pole_chain à longueur réglable : portée respectée, contourne un mur et un lac, rien si muré,
       plafond respecté, 64 par défaut inchangé ;
    §6 mutants : chaque règle retirée est vue ; §7 déterminisme et aucun nom du jeu.
  Usage : lua5.2 tests/lointain_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC_L, SRC_K, SRC_P = read("shared/team/lointain.lua"), read("shared/ai3/carte.lua"), read("shared/team/plan.lua")

local function load_all(sl, sk, sp)
  for _, n in ipairs({ "shared.team.lointain", "shared.ai3.carte", "shared.team.plan" }) do package.loaded[n] = nil end
  local function ld(src, name)
    local fn, err = load(src, "=" .. name, "t")
    if not fn then return nil, err end
    local ok, mod = pcall(fn)
    if not ok then return nil, mod end
    package.loaded[({ lointain = "shared.team.lointain", carte = "shared.ai3.carte", plan = "shared.team.plan" })[name]] = mod
    return mod
  end
  -- plan d'abord (carte et lointain peuvent le lire), puis la carte, puis les règles
  local P, e1 = ld(sp, "plan")
  if not P then return nil, e1 end
  local K, e2 = ld(sk, "carte")
  if not K then return nil, e2 end
  local L, e3 = ld(sl, "lointain")
  if not L then return nil, e3 end
  return L, K, P
end

local function suite(L, K, P)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = m end end

  -- Eau synthétique : ensemble de tuiles.
  local function lake(x0, y0, x1, y1, set)
    set = set or {}
    for y = y0, y1 do for x = x0, x1 do set[P.tkey(x, y)] = true end end
    return set
  end
  local function is_w(set) return function(x, y) return set[P.tkey(x, y)] == true end end
  local area = { x0 = 0, y0 = 0, x1 = 64, y1 = 64 }

  ---------------------------------------------------------------------------------------------------
  -- §1 Rives
  ---------------------------------------------------------------------------------------------------
  do
    -- lac à l'est : eau de x = 40 à 63, y = 10 à 50 : rive droite, toutes les tuiles de x = 38 (2 tuiles d'eau devant : 39 n'est
    -- pas eau, donc x = 38 voit 39 ? non : eau à partir de 40 => la rive est x = 39 : voisine 40 et suivante 41 sont de l'eau)
    local w = lake(40, 10, 63, 50)
    local s = L.shores(is_w(w), area, { x = 0, y = 0 })
    check(#s > 0, "§1 rive droite : au moins une rive")
    -- chaque rive respecte la règle, relue indépendamment : terre, puis deux tuiles d'eau dans la direction, la voisine a une
    -- voisine latérale en eau
    local valid = true
    local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
    for _, r in ipairs(s) do
      local d = DV[r.dir]
      local lat1 = w[P.tkey(r.x + d[1] - d[2], r.y + d[2] + d[1])]
      local lat2 = w[P.tkey(r.x + d[1] + d[2], r.y + d[2] - d[1])]
      if w[P.tkey(r.x, r.y)] or not w[P.tkey(r.x + d[1], r.y + d[2])] or not w[P.tkey(r.x + 2 * d[1], r.y + 2 * d[2])]
        or not (lat1 or lat2) then valid = false end
    end
    check(valid, "§1 rive droite : chaque rive est une terre devant deux tuiles d'eau (voisine latérale en eau)")
    local east = false
    for _, r in ipairs(s) do if r.x == 39 and r.dir == 2 then east = true end end
    check(east, "§1 rive droite : des rives en x = 39 tournées vers l'est")
    -- tri : la plus proche de (0, 0) d'abord (coin nord-ouest du lac)
    check(s[1].d == 50, "§1 tri par distance : la rive la plus proche de (0, 0) d'abord (d = " .. tostring(s[1].d) .. ")")
    -- égalité de distance (39, 10) et (40, 9), toutes deux à 50 : départage par y croissant
    check(s[1].y == 9 and s[1].x == 40, "§1 égalité de distance : la plus au nord d'abord (" .. s[1].x .. ", " .. s[1].y .. ")")
    -- espacement
    local gap_ok = true
    for i = 1, #s do for j = i + 1, #s do
      if math.max(math.abs(s[i].x - s[j].x), math.abs(s[i].y - s[j].y)) < L.SHORE_GAP then gap_ok = false end
    end end
    check(gap_ok, "§1 espacement : deux rives à moins de L.SHORE_GAP ne coexistent pas")
    check(#s <= L.SHORES_MAX, "§1 au plus L.SHORES_MAX rives")
    -- tri croissant en distance
    local sorted = true
    for i = 2, #s do if s[i].d < s[i - 1].d then sorted = false end end
    check(sorted, "§1 les rives sont triées par distance croissante")
    -- ordre de construction de l'eau sans effet (même ensemble, insertion inverse)
    local w2 = {}
    for y = 50, 10, -1 do for x = 63, 40, -1 do w2[P.tkey(x, y)] = true end end
    local s2 = L.shores(is_w(w2), area, { x = 0, y = 0 })
    local same = #s == #s2
    for i = 1, math.min(#s, #s2) do if s[i].x ~= s2[i].x or s[i].y ~= s2[i].y or s[i].dir ~= s2[i].dir then same = false end end
    check(same, "§1 même eau construite à l'envers : mêmes rives dans le même ordre")
    -- mare d'une tuile : aucune rive
    check(#L.shores(is_w(lake(30, 30, 30, 30)), area, { x = 0, y = 0 }) == 0, "§1 mare d'une tuile : aucune rive")
    -- filet d'eau d'une tuile de large (ligne) : la voisine latérale manque
    check(#L.shores(is_w(lake(30, 10, 30, 50)), area, { x = 0, y = 0 }) == 0, "§1 filet d'eau d'une tuile de large : aucune rive")
    -- eau profonde de 1 tuile seulement (bande de 1 tuile de large devant la terre, puis terre) : refusée
    local thin = lake(40, 10, 40, 50)
    check(#L.shores(is_w(thin), area, { x = 0, y = 0 }) == 0, "§1 eau profonde de 1 tuile : aucune rive")
    -- bande de 2 tuiles de large, 2 de long : acceptée
    check(#L.shores(is_w(lake(40, 10, 41, 11)), area, { x = 0, y = 0 }) > 0, "§1 étang de 2 × 2 : au moins une rive")
    -- rive concave : un lac en L ; les tuiles de terre du creux sont des rives
    local conc = lake(30, 10, 60, 20, lake(50, 10, 60, 50))
    local sc = L.shores(is_w(conc), area, { x = 0, y = 0 }, { gap = 1, max = 500 })
    local has_s, has_e = false, false
    for _, r in ipairs(sc) do
      if r.dir == 2 then has_e = true end
      if r.dir == 4 then has_s = true end
    end
    check(has_e and has_s, "§1 rive concave : rives tournées vers l'est ET vers le sud")
    check(#L.shores(is_w({}), area, { x = 0, y = 0 }) == 0, "§1 sans eau : aucune rive")
    -- fenêtre d'essai
    local win = L.window(100, -50)
    check(win.x1 - win.x0 == L.WINDOW and win.y1 - win.y0 == L.WINDOW and win.x0 == 100 - L.WINDOW / 2, "§1 fenêtre d'essai centrée")
    check(L.WINDOW == P.LOT, "§1 la fenêtre d'essai est un lot du treillis (24)")
  end

  ---------------------------------------------------------------------------------------------------
  -- §2 Carrefour, poteaux, tronçons
  ---------------------------------------------------------------------------------------------------
  do
    local i, j = L.clamp_node(5, 3, -2)
    check(i == 3 and j == -2, "§2 clamp : dedans, inchangé")
    i, j = L.clamp_node(5, 17, -2)
    check(i == 5 and j == -2, "§2 clamp : trop à l'est")
    i, j = L.clamp_node(5, -17, 40)
    check(i == -5 and j == 5, "§2 clamp : coin (négatif et positif)")
    i, j = L.clamp_node(5, -5, 5)
    check(i == -5 and j == 5, "§2 clamp : sur le bord")
    check(L.poles_needed(0, 7.5) == 0, "§2 poteaux : distance nulle")
    check(L.poles_needed(7, 7.5) == 1, "§2 poteaux : un pas de 7 tuiles = 1 poteau")
    check(L.poles_needed(320, 7.5) == 46, "§2 poteaux : 320 tuiles au petit poteau = 46 (" .. L.poles_needed(320, 7.5) .. ")")
    check(L.poles_needed(320, 9) == 38, "§2 poteaux : portée 9 = 38")
    check(L.poles_needed(10, 0.5) == math.huge, "§2 poteaux : portée nulle = infini")
    check(L.chain_max(320, 7.5) == 100, "§2 plafond du tracé : le double du plancher + 8")
    local g = L.groups(10)
    check(#g == 3 and g[1].first == 1 and g[1].last == 4 and g[3].first == 9 and g[3].last == 10, "§2 tronçons : 10 poteaux = 4 + 4 + 2")
    local cover = {}
    for _, t in ipairs(g) do for n = t.first, t.last do cover[n] = (cover[n] or 0) + 1 end end
    local once = true
    for n = 1, 10 do if cover[n] ~= 1 then once = false end end
    check(once, "§2 tronçons : chaque poteau dans un seul tronçon")
    check(g[1].mid == 2 and g[3].mid == 9, "§2 tronçons : le poteau médian est dans le tronçon")
    check(#L.groups(0) == 0, "§2 tronçons : aucun poteau, aucun tronçon")
    -- un tronçon tient dans la portée de construction (16) du point d'appui posé près du centre, au petit poteau
    check((L.GROUP - 1) * (7.5 - 0.5) / 2 + 3 < P.BUILD_DISTANCE, "§2 un tronçon tient à la portée de construction du point d'appui")
  end

  ---------------------------------------------------------------------------------------------------
  -- §3 Carte : eau, couloirs
  ---------------------------------------------------------------------------------------------------
  do
    local key = K.key
    local m = K.new()
    check(K.count(m, K.WATER) == 0, "§3 carte neuve : 0 secteur d'eau")
    local fresh, wet = K.record(m, key(1, 1), 100, { res = {}, water = true })
    check(#fresh == 0 and wet == true, "§3 1er regard d'un secteur d'eau : second retour vrai, liste des ressources inchangée")
    check(K.count(m, K.WATER) == 1, "§3 compteur d'eau = 1")
    fresh, wet = K.record(m, key(1, 1), 200, { res = {}, water = true })
    check(wet == false and K.count(m, K.WATER) == 1, "§3 2e regard du même secteur : pas une trouvaille, compteur inchangé")
    _, wet = K.record(m, key(2, 1), 210, { res = {}, water = false })
    check(wet == false and K.count(m, K.WATER) == 1, "§3 secteur sans eau : compteur inchangé")
    _, wet = K.record(m, key(3, 1), 220, { res = {}, water = true })
    check(wet and K.count(m, K.WATER) == 2, "§3 second secteur d'eau : compteur = 2")
    K.record(m, key(1, 1), 300, { res = {}, water = false })
    check(K.count(m, K.WATER) == 1, "§3 un secteur qui perd son eau : compteur = 1")
    K.record(m, key(1, 1), 400, { res = {}, water = false })
    check(K.count(m, K.WATER) == 1, "§3 pas de perte comptée deux fois")
    -- eau et ressource ensemble
    local f2, w2 = K.record(m, key(5, 5), 500, { res = { { name = "iron-ore", n = 100, a = 1000, x = 330, y = 330 } }, water = true })
    check(#f2 == 1 and f2[1] == "iron-ore" and w2, "§3 ressource ET eau au même regard : les deux rendus")
    -- carte d'avant le lot : s.w sans compteur
    local old = K.new()
    old.s[key(0, 0)] = { t0 = 1, t = 1, w = true }
    old.s[key(1, 0)] = { t0 = 1, t = 1, w = true }
    old.n = 2
    check(K.count(old, K.WATER) == 2, "§3 carte ancienne : le compteur est relu par balayage")
    K.record(old, key(2, 0), 10, { res = {}, water = true })
    check(K.count(old, K.WATER) == 3, "§3 carte ancienne : le compteur reste juste après un regard")
    K.record(old, key(0, 0), 20, { res = {}, water = true })
    check(K.count(old, K.WATER) == 3, "§3 carte ancienne : un secteur d'eau revu n'est pas recompté")

    -- K.waters
    local m2 = K.new()
    for _, sec in ipairs({ { 4, 0 }, { 2, 0 }, { 0, 3 }, { -2, 0 }, { 6, 6 } }) do
      K.record(m2, key(sec[1], sec[2]), 10, { res = {}, water = true })
    end
    K.record(m2, key(1, 1), 10, { res = {}, water = false })
    local ws = K.waters(m2, { x = 0, y = 0 })
    check(#ws == 5, "§3 K.waters : 5 secteurs d'eau (le sec n'y est pas)")
    local srt = true
    for i = 2, #ws do if ws[i].d2 < ws[i - 1].d2 or (ws[i].d2 == ws[i - 1].d2 and ws[i].key < ws[i - 1].key) then srt = false end end
    check(srt, "§3 K.waters trié par distance puis clé")
    check(ws[1].key == key(-2, 0) or ws[1].key == key(2, 0), "§3 K.waters : le plus proche d'abord")
    local ex = K.waters(m2, { x = 0, y = 0 }, { [key(2, 0)] = "danger", [key(-2, 0)] = "place" })
    check(#ex == 3, "§3 K.waters : les secteurs écartés sont exclus")
    check(#K.waters(K.new(), { x = 0, y = 0 }) == 0, "§3 K.waters : carte neuve = rien")
    check(ws[1].x == 2 * K.SECTOR + K.SECTOR / 2 or ws[1].x == -2 * K.SECTOR + K.SECTOR / 2, "§3 K.waters : centre du secteur")

    -- couloirs
    local function seen_all(mm, x0, y0, x1, y1)
      for sy = math.floor(y0 / 64), math.floor(y1 / 64) do
        for sx = math.floor(x0 / 64), math.floor(x1 / 64) do
          if not mm.s[key(sx, sy)] then K.record(mm, key(sx, sy), 10, { res = {} }) end
        end
      end
    end
    local mc = K.new()
    seen_all(mc, -64, -64, 700, 64)
    local a, b = { x = 0, y = 0 }, { x = 640, y = 0 }
    local info = K.line_risk(mc, a, b, 100, {})
    check(info.unseen == 0 and info.nests == 0 and info.risk == 0 and info.samples >= 10, "§3 couloir sûr et vu : 0 inconnu, 0 nid, risque 0")
    check(math.abs(info.length - 640) < 1e-6, "§3 couloir : longueur")
    local infob = K.line_risk(mc, b, a, 100, {})
    check(infob.unseen == info.unseen and infob.risk == info.risk and infob.nests == info.nests and infob.samples == info.samples,
      "§3 couloir : le sens du segment ne change rien")
    -- nid à 31 tuiles du segment : compté ; à 33 : non
    K.record(mc, key(5, 0), 20, { res = {}, nests = { { x = 330, y = 31 } } })
    check(K.line_risk(mc, a, b, 100, {}).nests == 1, "§3 couloir : nid à 31 tuiles du segment compté")
    K.record(mc, key(5, 0), 30, { res = {}, nests = { { x = 330, y = 33 } } })
    check(K.line_risk(mc, a, b, 100, {}).nests == 0, "§3 couloir : nid à 33 tuiles du segment non compté")
    check(K.line_risk(mc, a, b, 100, {}).risk > 0, "§3 couloir : un nid voisin donne du risque")
    -- secteur non vu
    local mu = K.new()
    seen_all(mu, -64, -64, 200, 64)
    local iu = K.line_risk(mu, a, b, 100, {})
    check(iu.unseen > 0 and iu.unseen < iu.samples, "§3 couloir : les secteurs jamais vus sont comptés")
    -- QG rival
    local ir = K.line_risk(mc, a, b, 100, { { x = 320, y = 60 } })
    check(ir.risk >= K.DANGER.rival, "§3 couloir : un QG rival à portée donne le risque d'un rival")
    -- incident récent
    local mi = K.new()
    seen_all(mi, -64, -64, 700, 64)
    K.mark(mi, 320, 0, 50, 500)
    check(K.line_risk(mi, a, b, 60, {}).risk > 0, "§3 couloir : un incident récent sur le couloir compte")
    check(K.line_risk(mi, a, b, 50 + K.DANGER.mark_ttl + 1, {}).risk == 0, "§3 couloir : l'incident périmé ne compte plus")
    -- territoire de la base : les `skip_dist` premières tuiles ne comptent pas (nids au QG), le reste oui
    local mb = K.new()
    seen_all(mb, -64, -64, 700, 64)
    for _, x in ipairs({ 20, 40, 60, 80 }) do K.record(mb, key(0, 0), 10, { res = {}, nests = { { x = x, y = 5 }, { x = x, y = 25 }, { x = x, y = 40 }, { x = x, y = 50 } } }) end
    local full = K.line_risk(mb, a, b, 100, {})
    local based = K.line_risk(mb, a, b, 100, {}, 200)
    check(full.risk > 0, "§3 couloir : des nids au QG donnent du risque sans territoire de base")
    check(based.risk == 0 and based.nests == 0, "§3 couloir : avec 200 tuiles de territoire, les nids du QG ne comptent plus (risque " .. based.risk .. ")")
    K.record(mb, key(5, 0), 20, { res = {}, nests = { { x = 330, y = 10 } } })
    check(K.line_risk(mb, a, b, 100, {}, 200).nests == 1, "§3 couloir : un nid sur le couloir HORS du territoire compte")
    check(K.line_risk(mb, a, b, 100, {}, 700).nests == 0 and K.line_risk(mb, a, b, 100, {}, 700).samples == 0, "§3 couloir : territoire plus long que le segment : rien à juger")
    check(K.prior(K.new(), K.WATER, key(9, 9), { x = 0, y = 0 }, { x = 5000, y = 0 }) == 1000, "§3 a priori de l'eau : uniforme, sans biais d'éloignement")
  end

  ---------------------------------------------------------------------------------------------------
  -- §4 Acceptation
  ---------------------------------------------------------------------------------------------------
  do
    local lim = { skip = 900 }
    check(L.corridor_ok({ nests = 0, risk = 0, unseen = 0, samples = 10 }, lim), "§4 couloir sûr accepté")
    local ok, why = L.corridor_ok({ nests = 1, risk = 0, unseen = 0, samples = 10 }, lim)
    check(not ok and why == "nid sur le couloir", "§4 un nid sur le couloir refuse")
    ok, why = L.corridor_ok({ nests = 0, risk = 900, unseen = 0, samples = 10 }, lim)
    check(not ok and why == "danger", "§4 risque au seuil de saut refuse")
    check(L.corridor_ok({ nests = 0, risk = 899, unseen = 0, samples = 10 }, lim), "§4 risque juste sous le seuil accepté")
    ok, why = L.corridor_ok({ nests = 0, risk = 0, unseen = 3, samples = 10 }, lim)
    check(not ok and why == "couloir inconnu", "§4 30 % de secteurs inconnus refuse")
    check(L.corridor_ok({ nests = 0, risk = 0, unseen = 2, samples = 10 }, lim), "§4 20 % de secteurs inconnus accepté")
    check(L.corridor_ok({ nests = 0, risk = 0, unseen = 25, samples = 100 }, lim), "§4 25 % pile accepté")
    check(not L.corridor_ok({ nests = 0, risk = 0, unseen = 26, samples = 100 }, lim), "§4 26 % refusé")
    check(L.site_ok({ spawners = 0, worms = 0, losses = 0, enemy_zone = false }), "§4 site sûr accepté")
    check(not L.site_ok({ spawners = 1, worms = 0 }), "§4 un nid au site refuse")
    check(not L.site_ok({ spawners = 0, worms = 1 }), "§4 un ver au site refuse")
    check(not L.site_ok({ losses = 1 }), "§4 une perte récente au site refuse")
    check(not L.site_ok({ enemy_zone = true }), "§4 territoire rival refuse")
    -- porte de la centrale : seul un projet NON électrique passe devant une centrale qui attend l'eau
    check(L.passes_plant_gate(true, false) == true, "§4 porte : projet non électrique passe pendant l'attente d'eau")
    check(L.passes_plant_gate(true, true) == false, "§4 porte : projet électrique attend")
    check(L.passes_plant_gate(false, false) == false, "§4 porte : sans attente d'eau, comportement d'avant (rien ne passe)")
    check(L.passes_plant_gate(nil, false) == false, "§4 porte : attente d'eau inconnue = comportement d'avant")
  end

  ---------------------------------------------------------------------------------------------------
  -- §5 Ligne de poteaux (P.pole_chain à longueur réglable)
  ---------------------------------------------------------------------------------------------------
  do
    local function chain_ok(chain, a, b, reach)
      local prev = a
      for _, c in ipairs(chain) do
        if math.sqrt((c.x - prev.x) ^ 2 + (c.y - prev.y) ^ 2) > reach + 1e-9 then return false end
        prev = c
      end
      return math.sqrt((b.x - prev.x) ^ 2 + (b.y - prev.y) ^ 2) <= reach + 1e-9
    end
    local a, b = { x = 0.5, y = 0.5 }, { x = 320.5, y = 0.5 }
    local free_all = function() return true end
    local c = P.pole_line(a, b, 7.5, free_all, L.chain_max(320, 7.5))
    check(c ~= nil and chain_ok(c, a, b, 7.5), "§5 ligne de 320 tuiles : chaque maillon à la portée")
    check(c ~= nil and #c <= L.poles_needed(320, 7.5) + 2, "§5 ligne de 320 tuiles : nombre de poteaux proche du plancher (" .. tostring(c and #c) .. ")")
    check(P.pole_line(a, b, 7.5, free_all, 10) == nil, "§5 plafond respecté : 10 poteaux ne suffisent pas")
    local far = P.pole_line(a, { x = 640.5, y = 0.5 }, 7.5, free_all, 300)
    check(far ~= nil and #far > 64, "§5 ligne de 640 tuiles : plus de 64 poteaux (" .. tostring(far and #far) .. ")")
    -- mur de 3 tuiles de large : enjambé
    local wall = function(x, y) return not (x >= 150 and x < 153 and y >= -40 and y <= 40) end
    local cw = P.pole_line(a, b, 7.5, wall, 100)
    check(cw ~= nil and chain_ok(cw, a, b, 7.5), "§5 un mur de 3 tuiles est enjambé")
    local crosses = true
    if cw then for _, p in ipairs(cw) do if not wall(p.x, p.y) then crosses = false end end end
    check(crosses, "§5 aucun poteau posé dans le mur")
    -- un lac de 5 tuiles de large (franchi d'une portée de 7,5) : la ligne l'enjambe
    local lake5 = function(x, y) return not (x >= 150 and x < 155 and y >= -40 and y <= 40) end
    local cl = P.pole_line(a, b, 7.5, lake5, 100)
    check(cl ~= nil and chain_ok(cl, a, b, 7.5), "§5 un lac de 5 tuiles est enjambé par la ligne")
    local on_lake = false
    if cl then for _, p in ipairs(cl) do if not lake5(p.x, p.y) then on_lake = true end end end
    check(not on_lake, "§5 aucun poteau sur le lac")
    -- un lac de 12 tuiles : impossible
    local lake12 = function(x, y) return not (x >= 150 and x < 162 and y >= -40 and y <= 40) end
    check(P.pole_line(a, b, 7.5, lake12, 100) == nil, "§5 un lac de 12 tuiles : pas de ligne (rien n'est inventé)")
    -- tout muré
    check(P.pole_line(a, b, 7.5, function() return false end, 100) == nil, "§5 tout muré : pas de ligne")
    -- déjà à portée
    local near = P.pole_line(a, { x = 5.5, y = 0.5 }, 7.5, free_all, 100)
    check(near ~= nil and #near == 0, "§5 déjà à portée : ligne vide")
    -- un arbre sur la route est évité
    local tree = function(x, y) return not (math.floor(x) == 7 and math.floor(y) == 0) end
    local ct = P.pole_line(a, b, 7.5, tree, 100)
    check(ct ~= nil and chain_ok(ct, a, b, 7.5), "§5 un arbre sur la route est évité")
    -- aucune tuile utilisée deux fois
    local seen_t, dup = {}, false
    for _, p in ipairs(c or {}) do local k = P.tkey(math.floor(p.x), math.floor(p.y)); if seen_t[k] then dup = true end seen_t[k] = true end
    check(not dup, "§5 aucune tuile utilisée deux fois")
    -- déterminisme
    local c2 = P.pole_line(a, b, 7.5, free_all, L.chain_max(320, 7.5))
    local same = c ~= nil and c2 ~= nil and #c == #c2
    if same then for i = 1, #c do if c[i].x ~= c2[i].x or c[i].y ~= c2[i].y then same = false end end end
    check(same, "§5 deux tracés identiques")
  end

  return pass, fail, msgs
end

local L0, K0, P0 = load_all(SRC_L, SRC_K, SRC_P)
local pass, fail, msgs = suite(L0, K0, P0)
for _, m in ipairs(msgs) do print("  ECHEC : " .. m) end
print(string.format("[LOINTAIN] %d OK, %d ECHEC(S)", pass, fail))

---------------------------------------------------------------------------------------------------
-- §6 Mutants : chaque règle retirée est vue
---------------------------------------------------------------------------------------------------
local MUT = {
  { "shores sans la règle des 2 tuiles d'eau", "shared/team/lointain.lua", "and is_water(tx + 2 * d[1], ty + 2 * d[2])", "" },
  { "shores sans la voisine latérale", "shared/team/lointain.lua", "and (is_water(x1 - d[2], y1 + d[1]) or is_water(x1 + d[2], y1 - d[1]))", "" },
  { "shores tri inversé", "shared/team/lointain.lua", "if a.d ~= b.d then return a.d < b.d end", "if a.d ~= b.d then return a.d > b.d end" },
  { "shores sans espacement", "shared/team/lointain.lua", "if math.max(math.abs(o.x - c.x), math.abs(o.y - c.y)) < gap then near = true break end", "" },
  { "shores sans départage par y", "shared/team/lointain.lua", "if a.y ~= b.y then return a.y < b.y end\n    return a.x < b.x", "return a.x < b.x" },
  { "clamp ignoré", "shared/team/lointain.lua", "return c(i), c(j)", "return i, j" },
  { "poteaux : portée +1", "shared/team/lointain.lua", "local step = reach - 0.5", "local step = reach + 0.5" },
  { "tronçons : pas de médian", "shared/team/lointain.lua", "mid = i + math.floor((last - i) / 2)", "mid = last" },
  { "couloir : les nids ne comptent pas", "shared/team/lointain.lua", "if (info.nests or 0) > 0 then return false", "if false then return false" },
  { "couloir : secteurs non vus sûrs", "shared/team/lointain.lua", "if (info.unseen or 0) * 100 > L.UNSEEN_PCT * math.max(1, info.samples or 1) then", "if false then" },
  { "couloir : danger ignoré", "shared/team/lointain.lua", "if (info.risk or 0) >= ((limits and limits.skip) or 900) then", "if false then" },
  { "site : territoire rival permis", "shared/team/lointain.lua", "if inputs.enemy_zone then", "if false then" },
  { "porte : tout passe", "shared/team/lointain.lua", "return wait_water == true and electric == false", "return true" },
  { "carte : l'eau n'est pas une trouvaille", "shared/ai3/carte.lua", "if s.w and not water_before then", "if false then" },
  { "carte : l'eau perdue non retirée", "shared/ai3/carte.lua", "elseif water_before and not s.w then", "elseif false then" },
  { "carte : K.waters non trié", "shared/ai3/carte.lua", "    if p.d2 ~= q.d2 then return p.d2 < q.d2 end\n    return p.key < q.key\n  end)\n  return out", "    return false\n  end)\n  return out" },
  { "carte : couloir sans les secteurs inconnus", "shared/ai3/carte.lua", "if not m.s[key] then unseen = unseen + 1 end", "" },
  { "carte : couloir sans les nids", "shared/ai3/carte.lua", "K.path_nests(m, from, b)", "0" },
  { "carte : territoire de la base ignoré", "shared/ai3/carte.lua", "if len * i / n >= skip_dist then", "if true then" },
  { "carte : le territoire ne retire pas les nids", "shared/ai3/carte.lua", "local t = math.min(1, skip_dist / len)", "local t = 0" },
  { "carte : couloir au risque minimal", "shared/ai3/carte.lua", "if r > risk then risk, worst = r, key end", "if r < risk then risk, worst = r, key end" },
  { "plan : plafond de la ligne ignoré", "shared/team/plan.lua", "for _ = 1, max_n or 200 do", "for _ = 1, 400 do" },
  { "plan : la ligne ignore le terrain", "shared/team/plan.lua", "      if free(c.x, c.y) then found = c break end", "      found = c break" },
  { "plan : la ligne au pire progrès", "shared/team/plan.lua", "      if p.d ~= q.d then return p.d < q.d end\n      if p.y ~= q.y then return p.y < q.y end\n      return p.x < q.x\n    end)\n    local found", "      if p.d ~= q.d then return p.d > q.d end\n      if p.y ~= q.y then return p.y < q.y end\n      return p.x < q.x\n    end)\n    local found" },
}
local kept = {}
local refused = 0
for _, mu in ipairs(MUT) do
  local sl, sk, sp = SRC_L, SRC_K, SRC_P
  local function sub(src)
    local i, j = src:find(mu[3], 1, true)
    assert(i, "mutant introuvable : " .. mu[1])
    return src:sub(1, i - 1) .. mu[4] .. src:sub(j + 1)
  end
  if mu[2] == "shared/team/lointain.lua" then sl = sub(sl) elseif mu[2] == "shared/ai3/carte.lua" then sk = sub(sk) else sp = sub(sp) end
  local L1, K1, P1 = load_all(sl, sk, sp)
  local seen = false
  if not L1 then
    seen = true
  else
    local ok, p, f2 = pcall(suite, L1, K1, P1)
    seen = (not ok) or f2 > 0
  end
  if seen then refused = refused + 1 else kept[#kept + 1] = mu[1] end
end
-- restaure les modules d'origine pour la suite
load_all(SRC_L, SRC_K, SRC_P)
if #kept > 0 then
  print("[LOINTAIN] ECHEC : mutants NON refuses : " .. table.concat(kept, " ; "))
  fail = fail + #kept
end
print(string.format("[LOINTAIN] mutants refuses : %d sur %d", refused, #MUT))

---------------------------------------------------------------------------------------------------
-- §7 Aucun nom du jeu dans les règles pures ; déterminisme
---------------------------------------------------------------------------------------------------
do
  local bad = {}
  for _, name in ipairs({ "offshore-pump", "boiler", "steam-engine", "small-electric-pole", "medium-electric-pole", "big-electric-pole",
    "water", "iron-ore", "coal", "copper-ore", "stone" }) do
    local q = '"' .. name .. '"'
    if SRC_L:find(q, 1, true) then bad[#bad + 1] = name .. " (shared/team/lointain.lua)" end
  end
  for _, path in ipairs({ "script/team/lointain.lua" }) do
    local src = read(path)
    for _, name in ipairs({ "offshore-pump", "boiler", "steam-engine", "small-electric-pole", "medium-electric-pole", "big-electric-pole",
      "iron-ore", "copper-ore" }) do
      if src:find('"' .. name .. '"', 1, true) then bad[#bad + 1] = name .. " (" .. path .. ")" end
    end
  end
  if #bad == 0 then
    print("[LOINTAIN] §7 aucun nom d'objet du jeu dans les regles du lot")
  else
    print("[LOINTAIN] ECHEC : §7 noms du jeu : " .. table.concat(bad, ", "))
    fail = fail + #bad
  end
end

print(string.format("[LOINTAIN] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
