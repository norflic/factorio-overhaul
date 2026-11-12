--[[
  Lot RAPATRIEMENT (8/11) : test hors jeu de la règle des lignes de rapatriement (shared/team/rapatriement.lua), de son branchement (script/team/rapatriement.lua,
  script/team/build.lua, lus comme texte) et de ses mutants.
    §1 constantes contre la liaison ; §2 débit d'une sortie ; §3 point du tampon contre la force brute ; §4 ramené au QG ; §5 prix ; §6 candidats ;
    §7 décision ; §8 anneaux et points libres ; §9 tracé accepté ; §10 entités et preuve géométrique ; §11 barre ; §12 journal ; §13 déterminisme ;
    §14 hygiène (aucun nom d'objet, aucun pairs dans une décision) ; §15 branchement ; §16 mutants : chaque règle faussée est vue.
  Usage : lua5.2 tests/rapatriement_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/rapatriement.lua")
local Li = require("shared.team.liaison")

local function load_rp(src)
  local fn, err = load(src, "=rapatriement", "t")
  assert(fn, err)
  return fn()
end

-- Générateur congruentiel (Lua 5.2 : pas de entiers 64 bits, rester sous 2^31)
local function lcg(seed)
  local s = seed
  return function(n)
    s = (s * 1103515245 + 12345) % 2147483648
    return (s % n) + 1
  end
end

local function shuffled(list, rnd)
  local out = {}
  for i, v in ipairs(list) do out[i] = v end
  for i = #out, 2, -1 do
    local j = rnd(i)
    out[i], out[j] = out[j], out[i]
  end
  return out
end

--- Toute la suite, contre la règle `Rp`. Rend le nombre d'échecs, le nombre de contrôles ; `quiet` : n'imprime pas les échecs.
local function suite(Rp, quiet)
  local ok_n, fail_n = 0, 0
  local function check(c, msg)
    if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 if not quiet then print("  ECHEC : " .. msg) end end
  end
  local function near(a, b, e) return math.abs(a - b) <= (e or 1e-9) end

  -- §1 constantes
  check(Rp.MIN_DIST > Li.MAX_SPAN, "1.1 une sortie lointaine est au-dela de la portee de la liaison ordinaire")
  check(Rp.MAX_LEN > Li.MAX_LEN, "1.2 la ligne de rapatriement est plus longue que la liaison ordinaire")
  check(Rp.NEAR_HUB >= Li.MAX_SPAN, "1.3 le tampon peut servir des quais jusqu'a la portee d'une liaison")
  check(Rp.REUSE_MAX >= 2 and Rp.MAX_LINES >= 2, "1.4 plusieurs lignes par tampon et par equipe")
  check(Rp.TAMPON_AT < Rp.COLLECT_BATCH * 2 and Rp.KEEP_STOCK > 0, "1.5 seuils du tampon sains")
  check(Rp.leg(100, 200) > Rp.leg(50, 200) and Rp.leg(100, 200) < Rp.leg(100, 100), "1.6 un trajet long coute plus, un lot plus gros coute moins par objet")
  check(near(Rp.leg(0, 200), Li.HANDLE_S / 200), "1.7 aucun trajet : la seule prise")

  -- §2 débit d'une sortie
  local r, nat = Rp.rate_of({ { 0, 0 }, { 1800, 90 } }, 200, 0.83)
  check(near(r, 3.0 > 0.83 and 0.83 or 3.0) and nat == "mesure", "2.1 hausse de 90 en 30 s = 3/s, borne par le bras (0,83)")
  r, nat = Rp.rate_of({ { 0, 0 }, { 1800, 9 } }, 200, 0.83)
  check(near(r, 0.3) and nat == "mesure", "2.2 hausse de 9 en 30 s = 0,3/s")
  r, nat = Rp.rate_of({ { 0, 50 }, { 1800, 0 }, { 3600, 9 } }, 200, 2)
  check(near(r, 0.3) and nat == "mesure", "2.3 une baisse (collecte) est ecartee, la hausse suivante compte")
  r, nat = Rp.rate_of({ { 0, 400 }, { 1800, 400 } }, 200, 0.83)
  check(nat == "stock" and near(r, 400 / (Rp.DRAIN_MIN * 60)) , "2.4 coffre plein qui ne monte plus : debit de stock")
  r, nat = Rp.rate_of({ { 0, 3200 }, { 1800, 3200 } }, 200, 0.83)
  check(nat == "stock" and near(r, 0.83), "2.5 stock gros : borne par le bras")
  r, nat = Rp.rate_of({ { 0, 10 }, { 1800, 10 } }, 200, 0.83)
  check(r == 0 and nat == nil, "2.6 coffre quasi vide et immobile : rien")
  r, nat = Rp.rate_of({}, 200, 0.83)
  check(r == 0 and nat == nil, "2.7 aucun releve : rien")
  r = Rp.rate_of({ { 100, 5 }, { 100, 90 } }, 200, 5)
  check(r == 0, "2.8 deux releves au meme tick : aucun debit")
  r = Rp.rate_of({ { 0, 0 }, { 1800, 3 }, { 3600, 6 }, { 5400, 90 } }, 200, 5)
  check(near(r, 0.1), "2.9 un pic isole ne fait pas le debit : mediane des hausses (" .. tostring(r) .. ")")

  -- §3 point du tampon : médiane pondérée, prouvée contre la force brute
  local rnd = lcg(20261108)
  local brute_ok, n_cases = 0, 0
  for case = 1, 120 do
    local n = rnd(6)
    local cons = {}
    for i = 1, n do cons[i] = { x = rnd(30) - 15, y = rnd(30) - 15, flow = rnd(9) / 4 } end
    local x, y, cost = Rp.tampon_point(cons)
    local best = math.huge
    for gx = -16, 16 do
      for gy = -16, 16 do
        local c = Rp.cost_at(cons, gx, gy)
        if c < best then best = c end
      end
    end
    n_cases = n_cases + 1
    if x and near(cost, best, 1e-7) and near(Rp.cost_at(cons, x, y), cost, 1e-7) then brute_ok = brute_ok + 1 end
  end
  check(brute_ok == n_cases, string.format("3.1 le point minimise la somme debit x distance sur %d cas tires (%d justes)", n_cases, brute_ok))
  check(Rp.tampon_point({}) == nil and Rp.tampon_point({ { x = 1, y = 1, flow = 0 } }) == nil, "3.2 aucun consommateur : aucun point")
  local x, y = Rp.tampon_point({ { x = 5, y = -3, flow = 1 } })
  check(x == 5 and y == -3, "3.3 un seul consommateur : son point")
  x, y = Rp.tampon_point({ { x = 0, y = 0, flow = 1 }, { x = 10, y = 0, flow = 5 }, { x = 20, y = 0, flow = 1 } })
  check(x == 10 and y == 0, "3.4 le gros debit attire le tampon")
  x, y = Rp.tampon_point({ { x = 0, y = 0, flow = 1 }, { x = 10, y = 10, flow = 1 } })
  check(x == 0 and y == 0, "3.5 egalite parfaite : la plus petite valeur (deterministe)")
  local a1, b1 = Rp.tampon_point({ { x = 3, y = 4, flow = 2 }, { x = -9, y = 4, flow = 1 }, { x = 7, y = 20, flow = 1.5 } })
  local a2, b2 = Rp.tampon_point({ { x = 7, y = 20, flow = 1.5 }, { x = 3, y = 4, flow = 2 }, { x = -9, y = 4, flow = 1 } })
  check(a1 == a2 and b1 == b2, "3.6 l'ordre des consommateurs ne change rien")
  check(Rp.wmedian({ { 1, 1 }, { 2, 1 }, { 3, 1 }, { 4, 1 } }) == 2, "3.7 mediane de quatre valeurs egales : la basse")
  check(Rp.wmedian({ { 1, 1 }, { 9, 10 } }) == 9, "3.8 un poids majoritaire l'emporte")
  check(Rp.wmedian({ { 5, 0 } }) == nil, "3.9 poids nul : aucune mediane")

  -- §4 ramené au QG
  local hub = { x = 0, y = 0 }
  local cx, cy = Rp.clamp_near(10, -20, hub, 72)
  check(cx == 10 and cy == -20, "4.1 deja assez pres : inchange")
  cx, cy = Rp.clamp_near(100, 0, hub, 72)
  check(cx == 72 and cy == 0, "4.2 trop loin sur un axe : ramene a la limite")
  cx, cy = Rp.clamp_near(-90, 90, hub, 72)
  check(math.abs(cx) + math.abs(cy) <= 72 and cx < 0 and cy > 0 and math.abs(cx) == math.abs(cy), "4.3 trop loin en diagonale : meme direction, dans la limite")
  cx, cy = Rp.clamp_near(-3, -500, { x = 10, y = 10 }, 20)
  check(math.abs(cx - 10) + math.abs(cy - 10) <= 20 and cy < 10, "4.4 autour d'un QG qui n'est pas l'origine")

  -- §5 prix
  local function winp(t)
    local base = { flow = 0.8, d_src = 150, d_tam = 40, d_fill = 50, covered = 0.4, span = 140 }
    for k, v in pairs(t or {}) do base[k] = v end
    return base
  end
  local ok, why, det = Rp.worth(winp())
  check(ok == true and det.payback_min > 0 and det.payback_min <= det.tmax, "5.1 gros debit, sortie lointaine : la ligne se paie (" .. tostring(why) .. ")")
  check(Rp.worth(winp({ flow = 0.01 })) == false and Rp.worth(winp({ flow = 0 })) == false, "5.2 debit sous Rp.MIN_RATE : refuse")
  local _, _, d_near = Rp.worth(winp({ d_src = 70, span = 60 }))
  local _, _, d_far = Rp.worth(winp({ d_src = 200, span = 190 }))
  check(d_far.save_s_min > d_near.save_s_min, "5.3 une sortie plus loin economise plus de travail de PNJ")
  local _, _, d_f1 = Rp.worth(winp({ flow = 0.4, covered = 0 }))
  local _, _, d_f2 = Rp.worth(winp({ flow = 0.8, covered = 0 }))
  check(near(d_f2.save_s_min / d_f1.save_s_min, 2, 1e-6), "5.4 l'economie est proportionnelle au debit")
  local _, _, d_c0 = Rp.worth(winp({ covered = 0 }))
  local _, _, d_c1 = Rp.worth(winp({ covered = 0.8 }))
  check(d_c1.save_s_min > d_c0.save_s_min, "5.5 des quais servis par le tampon economisent plus (reste a porter plus court + remplissage)")
  check(near(d_c1.phi, 1) and near(d_c0.phi, 0), "5.6 part servie par tapis bornee entre 0 et 1")
  local _, _, d_ct = Rp.worth(winp({ covered = 5 }))
  check(near(d_ct.phi, 1), "5.7 des quais plus gourmands que la sortie : phi = 1")
  local _, _, d_t1 = Rp.worth(winp({ d_tam = 5 }))
  local _, _, d_t2 = Rp.worth(winp({ d_tam = 70 }))
  check(d_t1.save_s_min > d_t2.save_s_min, "5.8 un tampon plus loin du QG laisse un trajet plus long")
  local _, _, d_s1 = Rp.worth(winp({ tiles = 60 }))
  local _, _, d_s2 = Rp.worth(winp({ tiles = 240 }))
  check(d_s1.payback_min < d_s2.payback_min and d_s1.cost < d_s2.cost, "5.9 un tapis plus court se paie plus vite")
  local _, _, d_th = Rp.worth(winp({ threat = true }))
  check(d_th.tmax == Rp.TMAX / Rp.THREAT_DIV, "5.10 menace : retour accepte divise par Rp.THREAT_DIV")
  local o_cheap = Rp.worth(winp({ flow = 0.5, price = { belt = 0.1, arm = 0.1, pole = 0.1, chest = 0 } }))
  local o_dear = Rp.worth(winp({ flow = 0.5, price = { belt = 60, arm = 60, pole = 60, chest = 60 } }))
  check(o_cheap == true and o_dear == false, "5.11 le prix des pieces compte")
  -- un tampon aussi loin que la sortie n'economise rien de la jambe de collecte
  local o_none = Rp.worth(winp({ d_tam = 150, covered = 0 }))
  check(o_none == false, "5.12 tampon aussi loin que la source, rien de servi : aucun travail economise")
  local t = Rp.trips(0.8, 0.5)
  check(near(t.far_avoided_h, 3600 * 0.8 / Rp.COLLECT_BATCH) and near(t.short_left_h, 0.5 * 3600 * 0.8 / Rp.COLLECT_BATCH)
    and near(t.fill_avoided_h, 0.5 * Rp.STAGE2 * 3600 * 0.8 / Rp.FILL_BATCH), "5.13 trajets par heure evites et restants")
  local ts = Rp.trips(0.8, 1)
  check(ts.short_left_h == 0 and ts.far_avoided_h > 0, "5.14 tout servi par tapis : plus de court trajet")

  -- §6 candidats
  local H = { x = 0, y = 0 }
  local function src(key, x, y, item, rate, linked) return { key = key, pid = 1, idx = 1, x = x, y = y, item = item, rate = rate, linked = linked } end
  local function dock(key, x, y, item, flow, served) return { key = key, x = x, y = y, item = item, flow = flow, served = served } end
  local docks = { dock("d1", 20, 10, "A", 1.0), dock("d2", 30, 14, "A", 1.0), dock("d3", -25, 5, "B", 1.0), dock("d4", 22, 12, "A", 1.0, true) }
  local srcs = { src("s-far", 120, 20, "A", 0.8), src("s-near", 30, 20, "A", 0.8), src("s-slow", 130, 20, "A", 0.01), src("s-linked", 140, 20, "A", 0.8, true),
    src("s-noitem", 150, 20, nil, 0.8), src("s-b", -130, 10, "B", 0.6) }
  local cands = Rp.candidates(srcs, docks, H)
  local keys = {}
  for _, c in ipairs(cands) do keys[#keys + 1] = c.src.key end
  check(#cands == 2 and ((keys[1] == "s-far" and keys[2] == "s-b") or (keys[1] == "s-b" and keys[2] == "s-far")),
    "6.1 seules les sorties lointaines, rapides, libres et d'un objet connu sont candidates (" .. table.concat(keys, ",") .. ")")
  local far
  for _, c in ipairs(cands) do if c.src.key == "s-far" then far = c end end
  check(far and far.point.x == 20 and far.point.y == 10, "6.2 le tampon est a la mediane des quais non servis du meme objet (le quai servi est ecarte)")
  check(far and near(far.covered, 1.0) and far.consumers == 2, "6.3 deux quais a portee : le tampon n'en sert qu'un (liaison ordinaire), covered = le plus gros (1,0), pas la somme (2,0)")
  check(far and far.d_src == 140 and far.d_tam == 30 and far.span == 110, "6.4 distances source -> QG, tampon -> QG et source -> tampon")
  check(cands[1].net >= cands[2].net, "6.5 tri par economie decroissante")
  local with_reuse = Rp.candidates({ src("s-far", 120, 20, "A", 0.8) }, {}, H, { tampons = { { x = 6, y = 2, item = "A", lines = 1 } } })
  check(with_reuse[1].reuse ~= nil and with_reuse[1].point.x == 6 and with_reuse[1].point.y == 2, "6.6 un tampon voisin du meme objet est reutilise")
  local no_reuse_item = Rp.candidates({ src("s-far", 120, 20, "A", 0.8) }, {}, H, { tampons = { { x = 6, y = 2, item = "B", lines = 1 } } })
  check(no_reuse_item[1].reuse == nil, "6.7 un tampon d'un autre objet n'est pas reutilise")
  local no_reuse_full = Rp.candidates({ src("s-far", 120, 20, "A", 0.8) }, {}, H, { tampons = { { x = 6, y = 2, item = "A", lines = Rp.REUSE_MAX } } })
  check(no_reuse_full[1].reuse == nil, "6.8 un tampon deja alimente par Rp.REUSE_MAX lignes n'est pas reutilise")
  local no_reuse_far = Rp.candidates({ src("s-far", 120, 20, "A", 0.8) }, {}, H, { tampons = { { x = 60, y = 50, item = "A", lines = 1 } } })
  check(no_reuse_far[1].reuse == nil, "6.9 un tampon trop loin du point voulu n'est pas reutilise")
  local no_docks = Rp.candidates({ src("s-far", 120, 20, "A", 0.8) }, {}, H)
  check(#no_docks == 1 and no_docks[1].point.x == 0 and no_docks[1].point.y == 0 and no_docks[1].covered == 0, "6.10 aucun quai : le tampon est au QG")
  local far_docks = Rp.candidates({ src("s-far", 200, 20, "A", 0.8) }, { dock("dz", 400, 400, "A", 1.0) }, H)
  check(math.abs(far_docks[1].point.x) + math.abs(far_docks[1].point.y) <= Rp.NEAR_HUB, "6.11 le tampon reste a Rp.NEAR_HUB tuiles du QG")
  local sorted = Rp.candidates({ src("b", 120, 20, "A", 0.5), src("a", 120, 20, "A", 0.5) }, docks, H)
  check(sorted[1].src.key == "a", "6.12 a economie egale, la plus petite cle d'abord")
  -- un quai sous Li.MIN_FLOW n'est pas un consommateur
  local tiny = Rp.candidates({ src("s-far", 120, 20, "A", 0.8) }, { dock("t1", 5, 5, "A", Li.MIN_FLOW / 2) }, H)
  check(tiny[1].consumers == 0, "6.13 un quai sous Li.MIN_FLOW ne compte pas")

  -- le stock dormant ne compte que pour une part dans le prix
  local prod = Rp.candidates({ { key = "p", pid = 1, idx = 1, x = 120, y = 20, item = "A", rate = 0.8, nature = "mesure" } }, docks, H)
  local stock = Rp.candidates({ { key = "p", pid = 1, idx = 1, x = 120, y = 20, item = "A", rate = 0.8, nature = "stock" } }, docks, H)
  check(near(stock[1].worth_flow, 0.8 * Rp.STOCK_FACTOR) and near(prod[1].worth_flow, 0.8) and stock[1].net < prod[1].net and stock[1].flow == 0.8,
    "6.14 un debit de stock ne compte que pour Rp.STOCK_FACTOR dans le prix, le debit reste le vrai")

  -- objet saturé au QG sans quai preneur : pas de ligne ; avec un quai preneur : la ligne reste possible
  local sat_src = { key = "sat", pid = 1, idx = 1, x = 120, y = 20, item = "A", rate = 0.8, nature = "mesure", saturated = true }
  local sat_none = Rp.candidates({ sat_src }, {}, H)
  check(sat_none[1].ok == false and sat_none[1].why == Rp.WHY_SATURATED, "6.15 objet sature au QG et aucun quai : refuse avec la cause ecrite")
  local sat_dock = Rp.candidates({ sat_src }, docks, H)
  check(sat_dock[1].ok == true, "6.16 objet sature au QG mais des quais le consomment : la ligne reste possible")
  local unsat = Rp.candidates({ { key = "u", pid = 1, idx = 1, x = 120, y = 20, item = "A", rate = 0.8, nature = "mesure", saturated = false } }, {}, H)
  check(unsat[1].why ~= Rp.WHY_SATURATED, "6.17 objet non sature : la cause n'est pas la saturation")
  -- lot BUS-SORTIE (partie du DC 0.7.3) : le quai consommateur au point voulu EST l'arrivee de la ligne (le dernier bras y depose) ; un tampon pose a cote
  -- (3:o6 -> tampon (-63, 13) -> liaison de 12 tuiles -> quai 8:q1 (-58, 13)) empilait un second relais coffre -> bras -> tapis -> bras -> coffre
  local q1 = dock("q1", 20, 10, "A", 1.0)
  local direct = Rp.candidates({ src("s-far", 120, 20, "A", 0.8) }, { q1 }, H)
  check(direct[1].reuse == q1 and direct[1].point.x == 20 and direct[1].point.y == 10, "6.18 un seul quai : la ligne arrive dans le quai, aucun tampon pose")
  local qa, qb = dock("qa", 20, 14, "A", 1.0), dock("qb", 24, 10, "A", 1.0) -- point voulu (20, 10), a 4 tuiles de chaque quai
  local over_tam = Rp.candidates({ src("s-far", 120, 20, "A", 0.8) }, { qa, qb }, H, { tampons = { { x = 21, y = 10, item = "A", lines = 1 } } })
  check(over_tam[1].reuse == qa or over_tam[1].reuse == qb, "6.19 un tampon voisin ne s'intercale pas entre la ligne et le quai")
  local q2 = dock("q2", 24, 12, "A", 1.0)
  local nearest = Rp.candidates({ src("s-far", 120, 20, "A", 0.8) }, { q1, q2 }, H)
  check(nearest[1].reuse == q1, "6.20 deux quais : la ligne arrive dans le plus proche du point voulu")
  local far_q = Rp.candidates({ src("s-far", 200, 20, "A", 0.8) }, { dock("dz", 400, 400, "A", 1.0) }, H)
  check(far_q[1].reuse == nil, "6.21 quai loin du point ramene pres du QG : tampon ordinaire")
  local served_q = Rp.candidates({ src("s-far", 120, 20, "A", 0.8) }, { dock("qs", 20, 10, "A", 1.0, true) }, H)
  check(served_q[1].reuse == nil, "6.22 un quai deja servi n'est pas l'arrivee")

  -- lot CC-ROUTE (F518, A6) : le QG est donné par sa POSITION (centre d'entité, x,5 pour un coffre 1 x 1) ; le tampon et les bouts du tapis sont des TUILES.
  -- Partie du DC (graine 1618033988, banc CC-ROUTE-SONDE) : les 5 lignes du joueur visaient le bout (-3,5 ; 4,5) et cherchaient 2 000 appels et plus sans fin.
  local HC = { x = -0.5, y = 0.5 }
  local function is_tile(v) return v == math.floor(v) end
  local c_hub = Rp.candidates({ src("s-far", 120, 20, "A", 0.8) }, {}, HC)[1]
  check(c_hub and c_hub.point.x == -1 and c_hub.point.y == 0, "6.18 aucun quai, QG au centre (-0,5 ; 0,5) : le tampon est la tuile du QG (-1, 0) ("
    .. tostring(c_hub and c_hub.point.x) .. ", " .. tostring(c_hub and c_hub.point.y) .. ")")
  local c_clamp = Rp.candidates({ src("s-far", 200, 20, "A", 0.8) }, { dock("dz", 400, 401, "A", 1.0) }, HC)[1]
  check(c_clamp and is_tile(c_clamp.point.x) and is_tile(c_clamp.point.y) and math.abs(c_clamp.point.x + 1) + math.abs(c_clamp.point.y) <= Rp.NEAR_HUB,
    "6.19 tampon ramene pres du QG : une tuile entiere (" .. tostring(c_clamp and c_clamp.point.x) .. ", " .. tostring(c_clamp and c_clamp.point.y) .. ")")
  check(c_hub and c_hub.d_src == 141 and c_hub.d_tam == 0, "6.20 distances comptees depuis la tuile du QG (-1, 0)")
  -- la chaîne jusqu'au tracé : point -> place du tampon -> paire de bouts -> tracé par tronçons, monde ouvert : la ligne est trouvée en quelques appels
  do
    local Tc = require("shared.team.troncons")
    local open = function() return true end
    local sp = c_hub and Rp.pick_spots(c_hub.point.x, c_hub.point.y, open, 1)[1]
    local e = sp and Li.pick_ends({ x = 120, y = 20 }, { x = sp.x, y = sp.y }, open, Rp.ROUTE_TRIES)[1]
    local status, calls = "aucun bout", 0
    if e then
      local m = Li.manhattan(e.src.bx, e.src.by, e.dst.bx, e.dst.by)
      local st = Tc.new({ s = { x = e.src.bx, y = e.src.by }, t = { x = e.dst.bx, y = e.dst.by }, t_dir = Li.end_dir(e.dst), sd = e.src.dir,
        box = { x0 = -60, y0 = -60, x1 = 180, y1 = 80 }, lim = Rp.DETOUR * (m + 1) + Rp.DETOUR_SLACK })
      local w = { maxd = 4, solid = function() return false end, cost = function() return 1 end }
      repeat calls = calls + 1; status = Tc.step(st, w) until status ~= "more" or calls >= 400
    end
    check(e and is_tile(e.dst.bx) and is_tile(e.dst.by) and status == "done", "6.21 QG au centre d'entite : le bout d'arrivee est une tuile et le trace est trouve ("
      .. tostring(status) .. " en " .. calls .. " appel(s), bout " .. tostring(e and e.dst.bx) .. ", " .. tostring(e and e.dst.by) .. ")")
  end

  -- §7 décision
  local good = { worth = true, worth_why = "ok", open_total = 0, free = 1, seen = 2, tries = 0, since_try = Rp.RETRY_AFTER, enemies = 0, threat = false, lines = 0 }
  local function with(t) local c = {} for k, v in pairs(good) do c[k] = v end for k, v in pairs(t) do c[k] = v end return c end
  check(Rp.decide(good) == "relier", "7.1 tout est reuni : relier")
  check(Rp.decide(with({ worth = false })) == "laisser", "7.2 ne se paie pas : laisser")
  check(Rp.decide(with({ seen = 1 })) == "attendre", "7.3 pas confirme : attendre")
  check(Rp.decide(with({ tries = Rp.MAX_TRIES, since_try = 10 })) == "laisser", "7.4 essais epuises : laisser")
  check(Rp.decide(with({ tries = Rp.MAX_TRIES, since_try = Rp.RETRY_AFTER })) == "relier", "7.5 essai de plus apres Rp.RETRY_AFTER")
  check(Rp.decide(with({ threat = true })) == "attendre", "7.6 QG menace : attendre")
  check(Rp.decide(with({ enemies = 1 })) == "attendre", "7.7 ennemi a portee : attendre")
  check(Rp.decide(with({ open_total = 1, free = 1 })) == "attendre", "7.8 autant de lignes ouvertes que de PNJ libres : attendre")
  check(Rp.decide(with({ open_total = 1, free = 3 })) == "relier", "7.9 des PNJ libres de reste : relier")
  check(Rp.decide(with({ lines = Rp.MAX_LINES })) == "laisser", "7.10 trop de lignes deja posees : laisser")
  check(Rp.max_open(0) == 1 and Rp.max_open(4) == 4, "7.11 au moins une ligne ouverte, autant que de PNJ libres")

  -- §8 anneaux et points libres
  local ring_ok = true
  for rr = 0, 6 do
    local ring = Rp.ring(3, -2, rr)
    local seen = {}
    if #ring ~= (rr == 0 and 1 or 4 * rr) then ring_ok = false end
    for _, tl in ipairs(ring) do
      if math.abs(tl[1] - 3) + math.abs(tl[2] + 2) ~= rr then ring_ok = false end
      local k = tl[1] .. ":" .. tl[2]
      if seen[k] then ring_ok = false end
      seen[k] = true
    end
  end
  check(ring_ok, "8.1 anneaux de Manhattan : 4r tuiles distinctes a la distance r")
  local free_all = function() return true end
  local spots = Rp.pick_spots(10, 10, free_all, 3)
  check(#spots == 3 and spots[1].x == 10 and spots[1].y == 10 and #spots[1].sites == 4, "8.2 libre partout : le point voulu d'abord, quatre sites")
  local free_block = function(x, y) return not (x == 10 and y == 10) end
  spots = Rp.pick_spots(10, 10, free_block, 2)
  check(spots[1].x == 10 and spots[1].y == 9, "8.3 le point voulu est pris : la tuile voisine la plus au nord (y croissant, x croissant)")
  local free_none = function() return false end
  check(#Rp.pick_spots(10, 10, free_none, 3) == 0, "8.4 rien de libre : aucun point")
  -- une tuile isolée (voisins pris) n'a pas de site : écartée
  local free_isolated = function(x, y) return x == 10 and y == 10 end
  check(#Rp.pick_spots(10, 10, free_isolated, 3) == 0, "8.5 une tuile libre sans place pour un bras et un tapis est ecartee")
  check(#Rp.pick_spots(10, 10, free_all, 100, 0) == 1, "8.6 le rayon de recherche borne la liste")

  -- §8 ter repli forcé du tampon (lot PLAQUES, A4 : le repli « vers le QG » n'avait aucun pas quand le point voulu EST le QG)
  do
    local fp = Rp.fallback_points
    check(type(fp) == "function", "8r.1 la regle du repli force existe (Rp.fallback_points)")
    if type(fp) == "function" then
      -- cas du banc : aucune consommation, point voulu = tuile du QG (339, -340), sortie a 90 tuiles
      local hub, src = { x = 339, y = -340 }, { x = 429, y = -340 }
      local pts = fp(339, -340, hub, src, 12, 72)
      local far = 0
      for _, q in ipairs(pts) do far = math.max(far, math.abs(q.x - hub.x) + math.abs(q.y - hub.y)) end
      check(#pts == 6 and pts[1].x == 351 and pts[1].y == -340, "8r.2 point voulu au QG : le repli part du QG vers la sortie, par pas de 12 (" .. #pts .. " points)")
      check(far == 72, "8r.3 le repli ne s'eloigne jamais du QG au-dela de la portee (" .. far .. ")")
      -- cas de BUS-FER : point voulu a 48 tuiles du QG, hors reseau : d'abord vers le QG
      local pts2 = fp(48, 0, { x = 0, y = 0 }, { x = 200, y = 0 }, 12, 72)
      check(pts2[1].x == 36 and pts2[4].x == 0 and pts2[5].x == 60 and #pts2 == 6, "8r.4 point voulu loin du QG : vers le QG d'abord, puis vers la sortie (sans repasser)")
      local seen, dup = {}, false
      for _, q in ipairs(pts2) do local k = q.x .. ":" .. q.y; if seen[k] or (q.x == 48 and q.y == 0) then dup = true end; seen[k] = true end
      check(not dup, "8r.5 aucun point essaye deux fois, ni le point voulu")
    end
  end

  -- §8 quater lot TAMPON-MINERAI (scarlet, graine 123456789, 50 min : coffre et bras du tampon du projet 22 en (379.5, -317.5) et (380.5, -317.5),
  -- au milieu de son cuivre ; repli Rp.fallback_points du QG vers la sortie) : la règle unique du sol (Sm.forbidden) refuse le coffre ET le bras
  do
    local ore3 = function(x, y) return x >= 9 and x <= 11 and y >= 9 and y <= 11 end
    local off = Rp.off_ore
    check(type(off) == "function" and type(Rp.sites_ok) == "function" and type(Rp.ends_ok) == "function", "8m.1 la regle du minerai existe (Rp.off_ore, Rp.sites_ok, Rp.ends_ok)")
    if type(off) == "function" and type(Rp.sites_ok) == "function" and type(Rp.ends_ok) == "function" then
      local chest_ok, arm_ok, belt_ok = off("container", ore3), off("inserter", ore3), off("transport-belt", ore3)
      check(not chest_ok(10, 10) and chest_ok(13, 10) and not arm_ok(9, 11) and arm_ok(8, 11), "8m.2 coffre et bras : refuses sur une tuile de ressource, admis a cote")
      check(belt_ok(10, 10) and off("electric-pole", ore3)(10, 10), "8m.3 tapis et poteau (BOX_MINAGE) : admis sur la ressource")
      local ok = { chest = chest_ok, arm = arm_ok }
      local free_all = function() return true end
      local sp = Rp.pick_spots(10, 10, free_all, 3, nil, ok)
      local bad = 0
      for _, q in ipairs(sp) do
        if ore3(q.x, q.y) then bad = bad + 1 end
        for _, si in ipairs(q.sites) do if ore3(si.ax, si.ay) then bad = bad + 1 end end
      end
      check(#sp == 3 and bad == 0, "8m.4 point voulu au milieu du minerai : aucun coffre ni bras sur une ressource (" .. bad .. ")")
      check(sp[1] and sp[1].x == 10 and sp[1].y == 8 and #sp[1].sites == 3, "8m.5 premier point hors minerai (10, 8), le site sud (bras sur la ressource) ecarte")
      check(Rp.pick_spots(10, 10, free_all, 3)[1].x == 10 and Rp.pick_spots(10, 10, free_all, 3)[1].y == 10, "8m.6 sans la regle (ok absent) : comportement d'avant")
      local ends = { { src = { ax = 1, ay = 1 }, dst = { ax = 10, ay = 10 } }, { src = { ax = 10, ay = 10 }, dst = { ax = 1, ay = 1 } },
        { src = { ax = 1, ay = 1 }, dst = { ax = 2, ay = 2 } }, { src = { ax = 3, ay = 1 }, dst = { ax = 2, ay = 3 } } }
      local kept = Rp.ends_ok(ends, arm_ok)
      check(#kept == 2 and kept[1] == ends[3] and kept[2] == ends[4], "8m.7 paires de bouts : un bras de depart ou d'arrivee sur la ressource ecarte la paire")
      check(#Rp.ends_ok(ends, arm_ok, 1) == 1, "8m.8 paires de bouts : au plus max")
      -- cas du banc : QG (339, -340), sortie (388, -306), cuivre de scarlet autour de (379, -318), seul poteau du réseau au cuivre
      local copper = function(x, y) return x >= 372 and x <= 386 and y >= -324 and y <= -312 end
      local near_pole = function(x, y) return (x - 381) ^ 2 + (y - -317) ^ 2 <= 7 * 7 end
      local okb = { chest = off("container", copper), arm = off("inserter", copper) }
      local function first(o)
        for _, q in ipairs(Rp.fallback_points(339, -340, { x = 339, y = -340 }, { x = 388, y = -306 }, Rp.FALLBACK_STEP, Rp.NEAR_HUB)) do
          local s2 = Rp.pick_spots(q.x, q.y, near_pole, Rp.SPOT_TRIES, nil, o)
          if #s2 > 0 then return s2 end
        end
        return {}
      end
      local before, after = first(nil), first(okb)
      check(#before > 0 and copper(before[1].x, before[1].y), "8m.9 cas du banc, sans la regle : le repli pose le tampon sur le cuivre (" .. (before[1] and before[1].x .. ", " .. before[1].y or "-") .. ")")
      local bad2 = 0
      for _, q in ipairs(after) do
        if copper(q.x, q.y) then bad2 = bad2 + 1 end
        for _, si in ipairs(q.sites) do if copper(si.ax, si.ay) then bad2 = bad2 + 1 end end
      end
      check(#after > 0 and bad2 == 0, "8m.10 cas du banc, avec la regle : tampon et bras hors du cuivre, a portee du poteau (" .. #after .. " point(s), " .. bad2 .. " sur la ressource)")
    end
  end

  -- §8 bis bord de rue (constantes du treillis de shared/team/plan.lua)
  local PL = require("shared.team.plan")
  local geom = { pitch = PL.PITCH, lot = PL.LOT, half = PL.HALF }
  local lat = { ox = 5, oy = -7 }
  local edge_n, edge_bad = 0, 0
  for tx = lat.ox - geom.half, lat.ox - geom.half + geom.pitch - 1 do
    for ty = lat.oy - geom.half, lat.oy - geom.half + geom.pitch - 1 do
      if Rp.street_edge(lat, geom, tx, ty) then
        edge_n = edge_n + 1
        if not PL.in_street(lat, tx, ty) then edge_bad = edge_bad + 1 end
        local lot_neighbour = false
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
          if not PL.in_street(lat, tx + d[1], ty + d[2]) then lot_neighbour = true end
        end
        if not lot_neighbour then edge_bad = edge_bad + 1 end
      end
    end
  end
  check(edge_n == 4 * geom.lot and edge_bad == 0, string.format("8.7 bord de rue : %d tuiles par case (attendu %d), toutes en rue et contre un lot (%d fautes)", edge_n, 4 * geom.lot, edge_bad))
  check(not Rp.street_edge(lat, geom, lat.ox - geom.half + geom.lot, lat.oy - geom.half + geom.lot), "8.8 un croisement n'est pas un bord")
  check(not Rp.street_edge(lat, geom, lat.ox - geom.half + 5, lat.oy - geom.half + 5), "8.9 le milieu d'un lot n'est pas un bord")
  check(not Rp.street_edge(lat, geom, lat.ox - geom.half + geom.lot + 1, lat.oy - geom.half + 5), "8.10 le milieu de la rue n'est pas un bord")

  -- §9 tracé accepté
  check(Rp.route_ok(100, 90) == true, "9.1 un tapis direct est accepte")
  check(Rp.route_ok(Rp.MAX_LEN + 1, Rp.MAX_LEN - 50) == false, "9.2 un tapis plus long que Rp.MAX_LEN est refuse")
  check(Rp.route_ok(250, 100) == false, "9.3 un detour de plus de Rp.DETOUR est refuse")
  check(Rp.route_ok(Rp.MAX_LEN, Rp.MAX_LEN - 20) == true, "9.4 au plafond mais direct : accepte")
  local _, w = Rp.route_ok(Rp.MAX_LEN + 80, Rp.MAX_LEN - 20)
  check(type(w) == "string" and w:find("tuiles", 1, true) ~= nil, "9.5 la raison du refus est ecrite")

  -- §10 entités et preuve géométrique : tracé en L entre un coffre S (au nord-ouest) et un tampon D
  local function build_line(S, D, free)
    local ends = Li.pick_ends(S, D, free, 4)
    local e = ends[1]
    local tiles = {}
    local x, y = e.src.bx, e.src.by
    local function dirn(dx, dy) return Li.dir_of(dx, dy) end
    -- horizontal puis vertical
    while x ~= e.dst.bx do
      local step = (e.dst.bx > x) and 1 or -1
      tiles[#tiles + 1] = { x = x, y = y, dir = dirn(step, 0) }
      x = x + step
    end
    while y ~= e.dst.by do
      local step = (e.dst.by > y) and 1 or -1
      tiles[#tiles + 1] = { x = x, y = y, dir = dirn(0, step) }
      y = y + step
    end
    tiles[#tiles + 1] = { x = x, y = y, dir = Li.end_dir(e.dst) }
    return e, tiles
  end
  local geo_ok, geo_n = 0, 0
  local rnd2 = lcg(777)
  for case = 1, 40 do
    local S = { x = rnd2(20), y = rnd2(20) }
    local D = { x = 60 + rnd2(40), y = 50 + rnd2(40) }
    local e, tiles = build_line(S, D, function(x, y) return not ((x == S.x and y == S.y) or (x == D.x and y == D.y)) end)
    if e then
      -- les tuiles en L peuvent se recouvrir sur une arete : on ne garde que les lignes a tuiles distinctes
      local seen, distinct = {}, true
      for _, tl in ipairs(tiles) do
        local k = tl.x .. ":" .. tl.y
        if seen[k] then distinct = false end
        seen[k] = true
      end
      if distinct then
        geo_n = geo_n + 1
        local ents = Rp.entities({ src = e.src, dst = e.dst, route = tiles, names = { arm = "ARM", belt = "BELT", pole = "POLE", chest = "CHEST" }, poles = {} })
        local bad = Rp.verify(ents, S, D, function(x) return x.role == "liaison-tapis" end, function(x) return x.role == "liaison-bras" end,
          function(x) return x.role == "tampon" end, false)
        if #bad == 0 then geo_ok = geo_ok + 1 end
      end
    end
  end
  check(geo_n >= 20 and geo_ok == geo_n, string.format("10.1 la preuve geometrique est juste sur %d lignes tirees (%d justes)", geo_n, geo_ok))
  do
    local S, D = { x = 5, y = 5 }, { x = 40, y = 30 }
    local free = function(x, y) return not ((x == S.x and y == S.y) or (x == D.x and y == D.y)) end
    local e, tiles = build_line(S, D, free)
    local names = { arm = "ARM", belt = "BELT", pole = "POLE", chest = "CHEST" }
    local function isbelt(x) return x.role == "liaison-tapis" end
    local function isarm(x) return x.role == "liaison-bras" end
    local function ischest(x) return x.role == "tampon" end
    local ents = Rp.entities({ src = e.src, dst = e.dst, route = tiles, names = names, poles = { { 7, 7 } } })
    check(#Rp.verify(ents, S, D, isbelt, isarm, ischest, false) == 0, "10.2 la ligne tiree est juste")
    local n_chest, chest_e = 0, nil
    for _, x in ipairs(ents) do if ischest(x) then n_chest = n_chest + 1 chest_e = x end end
    check(n_chest == 1 and chest_e.name == "CHEST" and math.floor(chest_e.x) == D.x and math.floor(chest_e.y) == D.y, "10.3 un coffre tampon sur la tuile d'arrivee")
    local reuse_ents = Rp.entities({ src = e.src, dst = e.dst, route = tiles, names = names, poles = {}, reuse = true })
    local has_chest = false
    for _, x in ipairs(reuse_ents) do if ischest(x) then has_chest = true end end
    check(not has_chest and #Rp.verify(reuse_ents, S, D, isbelt, isarm, ischest, true) == 0, "10.4 tampon reutilise : aucun coffre pose, preuve juste")
    check(#Rp.verify(ents, S, D, isbelt, isarm, ischest, true) > 0, "10.5 un coffre pose alors que le tampon existe : refuse")
    -- fautes : chaque modification doit être vue
    local function copy_ents() local c = {} for i, x in ipairs(ents) do local y = {} for k, v in pairs(x) do y[k] = v end c[i] = y end return c end
    local bad1 = copy_ents()
    for _, x in ipairs(bad1) do if isarm(x) then x.dir = (x.dir + 2) % 8 break end end
    check(#Rp.verify(bad1, S, D, isbelt, isarm, ischest, false) > 0, "10.6 bras de depart tourne : refuse")
    local bad2 = copy_ents()
    for i = #bad2, 1, -1 do if isbelt(bad2[i]) then table.remove(bad2, i) break end end
    check(#Rp.verify(bad2, S, D, isbelt, isarm, ischest, false) > 0, "10.7 une tuile de tapis manquante : refuse")
    local bad3 = copy_ents()
    for _, x in ipairs(bad3) do if ischest(x) then x.x = x.x + 1 end end
    check(#Rp.verify(bad3, S, D, isbelt, isarm, ischest, false) > 0, "10.8 coffre tampon decale d'une tuile : refuse")
    local bad4 = copy_ents()
    for i = #bad4, 1, -1 do if ischest(bad4[i]) then table.remove(bad4, i) end end
    check(#Rp.verify(bad4, S, D, isbelt, isarm, ischest, false) > 0, "10.9 pas de coffre tampon : refuse")
    local bad5 = copy_ents()
    bad5[#bad5 + 1] = { name = "CHEST", x = D.x + 0.5, y = D.y + 0.5, dir = 0, role = "tampon" }
    check(#Rp.verify(bad5, S, D, isbelt, isarm, ischest, false) > 0, "10.10 deux coffres tampon : refuse")
    local bad6 = copy_ents()
    for _, x in ipairs(bad6) do if isbelt(x) then x.dir = (x.dir + 4) % 8 break end end
    check(#Rp.verify(bad6, S, D, isbelt, isarm, ischest, false) > 0, "10.11 un tapis a contresens : refuse")
  end

  -- §11 barre
  check(Rp.bar(0, 100) == math.ceil(Rp.BUFFER_MIN_OBJ / 100) + 1, "11.1 debit nul : le plancher d'objets")
  check(Rp.bar(10, 100) == math.ceil(Rp.BUFFER_MAX_OBJ / 100) + 1, "11.2 gros debit : le plafond d'objets")
  check(Rp.bar(0.5, 100) == math.ceil(0.5 * 60 * Rp.BUFFER_MIN / 100) + 1, "11.3 debit moyen : Rp.BUFFER_MIN minutes de debit")
  check(Rp.bar(0.5, 50) > Rp.bar(0.5, 100), "11.4 une pile plus petite demande plus de cases")
  check(Rp.bar(0.5, 100) >= 2, "11.5 au moins une case libre (F95 : barre n + 1 = n cases)")
  check(Rp.bar(0.4, 100) < Rp.bar_total({ 0.4, 0.4 }, 100), "11.6 deux lignes dans un tampon : debit cumule")
  check(Rp.bar(0.5, nil) >= 2, "11.7 pile inconnue : une case par objet")

  -- §12 journal
  local d = { team = "player", tick = 3600 * 100, pid = 140, key = "12:o3", item = "A", flow = 0.83, nature = "mesure", d_src = 150, x = 22, y = 14, d_tam = 36,
    tiles = 160, why = "retour 60 min", phi = 0.5 }
  local tx = Rp.text("demandee", d)
  check(tx:find("[FO-RAPATRIEMENT]", 1, true) and tx:find("player", 1, true) and tx:find("12:o3", 1, true) and tx:find("(22, 14)", 1, true), "12.1 ligne demandee : equipe, sortie, tampon")
  check(tx:find("trajets de PNJ economises par heure", 1, true) and tx:find("lointain", 1, true), "12.2 ligne demandee : compte des trajets economises")
  local tr = Rp.trips(0.83, 0.5)
  check(tx:find(string.format("%.1f lointain", tr.far_avoided_h), 1, true), "12.3 le nombre de trajets lointains ecrit est celui de Rp.trips")
  check(Rp.text("finie", d):find("ligne finie", 1, true) and Rp.text("coupee", d):find("ligne coupee", 1, true), "12.4 lignes finie et coupee")
  d.cause = "liaison: aucun chemin"
  check(Rp.text("refusee", d):find("aucun chemin", 1, true), "12.5 ligne refusee : la cause")
  d.action, d.cause = "laisser", "ne se paie pas"
  check(Rp.text("laissee", d):find("ne se paie pas", 1, true), "12.6 ligne laissee : la cause")
  check(Rp.text("releve", { team = "p", tick = 0, far = 3, worth = 1 }):find("3 sortie(s) lointaine(s)", 1, true), "12.7 releve")

  -- §13 déterminisme : l'ordre des entrées ne change rien
  local rnd3 = lcg(31337)
  local all_same = true
  for case = 1, 25 do
    local ss, dd = {}, {}
    for i = 1, 4 do ss[i] = src("s" .. i, 60 + rnd3(150), rnd3(80) - 40, ({ "A", "B" })[rnd3(2)], rnd3(9) / 8) end
    for i = 1, 6 do dd[i] = dock("d" .. i, rnd3(60) - 30, rnd3(60) - 30, ({ "A", "B" })[rnd3(2)], rnd3(9) / 8) end
    local c1 = Rp.candidates(ss, dd, H)
    local c2 = Rp.candidates(shuffled(ss, rnd3), shuffled(dd, rnd3), H)
    if #c1 ~= #c2 then all_same = false
    else
      for i = 1, #c1 do
        if c1[i].src.key ~= c2[i].src.key or c1[i].point.x ~= c2[i].point.x or c1[i].point.y ~= c2[i].point.y or not near(c1[i].net, c2[i].net, 1e-9) then all_same = false end
      end
    end
  end
  check(all_same, "13.1 les candidats ne dependent pas de l'ordre des entrees (25 cas tires)")
  local c1, c2 = Rp.candidates(srcs, docks, H), Rp.candidates(srcs, docks, H)
  check(#c1 == #c2 and c1[1].src.key == c2[1].src.key and near(c1[1].net, c2[1].net), "13.2 deux appels, meme resultat")

  -- §17 recherche de chemin reprenable : même résultat que P.belt_route (shared/team/plan.lua), quel que soit le découpage
  local PP = require("shared.team.plan")
  local rnd4 = lcg(424242)
  local same, total, sliced_same, cap_same = 0, 0, 0, 0
  for case = 1, 160 do
    local W, H = 14 + rnd4(12), 14 + rnd4(12)
    local wall = {}
    local density = rnd4(35)
    for x = 0, W do for y = 0, H do if rnd4(100) <= density then wall[x .. ":" .. y] = true end end end
    local s = { x = 1 + (rnd4(3) - 1), y = 1 + (rnd4(3) - 1) }
    local t = { x = W - (rnd4(3) - 1), y = H - (rnd4(3) - 1) }
    wall[s.x .. ":" .. s.y], wall[t.x .. ":" .. t.y] = nil, nil
    local function cost(x, y) if wall[x .. ":" .. y] then return nil end if case % 4 < 2 then return 1 + (((x * 7 + y * 3) % 5 == 0) and 1 or 0) end return 1 + ((x * 7 + y * 3) % 5) end
    local bounds = { x0 = 0, y0 = 0, x1 = W, y1 = H }
    local weight = (case % 2 == 0) and 1.4 or 1
    local cap = (case % 5 == 0) and 25 or 100000
    local ref, why = PP.belt_route(s, t, 2, bounds, cost, { weight = weight, max = cap })
    local job = Rp.route_begin(s, t, 2, bounds, weight)
    local st = Rp.route_step(job, cost, nil, cap)
    total = total + 1
    local ok_one = (ref ~= nil and st == "found" and #ref == #job.tiles) or (ref == nil and st ~= "found" and job.why == why)
    if ok_one and ref then for i = 1, #ref do if ref[i].x ~= job.tiles[i].x or ref[i].y ~= job.tiles[i].y or ref[i].dir ~= job.tiles[i].dir then ok_one = false end end end
    if ok_one then same = same + 1 end
    local job2 = Rp.route_begin(s, t, 2, bounds, weight)
    local guard = 0
    local st2 = "more"
    while st2 == "more" and guard < 100000 do st2 = Rp.route_step(job2, cost, 1 + rnd4(9), cap); guard = guard + 1 end
    local ok_sl = (ref ~= nil and st2 == "found" and #ref == #job2.tiles) or (ref == nil and st2 ~= "found" and job2.why == why)
    if ok_sl and ref then for i = 1, #ref do if ref[i].x ~= job2.tiles[i].x or ref[i].y ~= job2.tiles[i].y then ok_sl = false end end end
    if ok_sl then sliced_same = sliced_same + 1 end
    if cap == 25 and ok_one then cap_same = cap_same + 1 end
  end
  check(same == total, string.format("17.1 d'un seul tenant : meme trace que P.belt_route sur %d grilles tirees (%d)", total, same))
  check(sliced_same == total, string.format("17.2 en tranches de 1 a 9 noeuds : meme trace (%d sur %d)", sliced_same, total))
  local jb = Rp.route_begin({ x = 0, y = 0 }, { x = 5, y = 5 }, 2, { x = 0, y = 0, x1 = 9, y1 = 9 }, 1)
  check(Rp.route_step(jb, function() return nil end, 10, 100) == "none" and jb.why == "depart", "17.3 depart interdit : refuse avec la cause")
  local jc = Rp.route_begin({ x = 0, y = 0 }, { x = 5, y = 5 }, 2, { x0 = 0, y0 = 0, x1 = 9, y1 = 9 }, 1)
  check(Rp.route_step(jc, function(x, y) if x == 5 and y == 5 then return nil end return 1 end, 10, 100) == "none" and jc.why == "arrivee", "17.4 arrivee interdite : refuse avec la cause")
  local jd = Rp.route_begin({ x = 0, y = 0 }, { x = 9, y = 9 }, 2, { x0 = 0, y0 = 0, x1 = 9, y1 = 9 }, 1)
  local sd = Rp.route_step(jd, function() return 1 end, 3, 100)
  check(sd == "more" and jd.expanded == 3, "17.5 une tranche de 3 noeuds developpe 3 noeuds et rend la main (" .. tostring(sd) .. " " .. jd.expanded .. ")")
  local je = Rp.route_begin({ x = 0, y = 0 }, { x = 9, y = 9 }, 2, { x0 = 0, y0 = 0, x1 = 9, y1 = 9 }, 1)
  check(Rp.route_step(je, function() return 1 end, nil, 5) == "cap" and je.why == "trop long", "17.6 plafond de noeuds : trop long")
  local jf = Rp.route_begin({ x = 0, y = 0 }, { x = 4, y = 0 }, 2, { x0 = 0, y0 = 0, x1 = 9, y1 = 9 }, 1)
  local function no_open_state() for k, v in pairs(jf) do if type(v) == "function" then return false end end return true end
  Rp.route_step(jf, function() return 1 end, 2, 100)
  check(no_open_state(), "17.7 l'etat d'une recherche ne contient aucune fonction")

  -- §18 lot SORTIE-COFFRE : l'état mesuré en moteur (graine 2507543475, azure 5:o2 a t=135770) : quai de coffres (458..466, 456), bras du quai au nord
  -- (y = 455) sur la ligne de plaques (y = 454), la ligne 5:o4 longe la face sud du quai (tapis en y = 458, vers l'ouest)
  if Rp.quai_guard and Rp.branch_sites then
    local outs = {}
    for x = 458, 466 do outs[#outs + 1] = { x = x + 0.5, y = 456.5 } end
    local S = { x = 459, y = 456 }
    local g = Rp.quai_guard(outs, S)
    local gk = {}
    for _, t in ipairs(g) do gk[t.x .. ":" .. t.y] = true end
    check(gk["458:457"] and gk["460:457"] and gk["461:457"] and gk["466:457"], "18.1 la ligne de S ne prend pas la face libre des autres coffres du quai")
    check(not gk["459:457"] and not gk["459:455"] and not gk["459:456"], "18.2 la face de S elle-meme reste a S")
    check(gk["457:456"] and gk["467:456"] and not gk["459:458"], "18.3 les bouts du quai sont gardes, la tuile a deux pas de S ne l'est pas")
    local dup = false
    for i = 2, #g do if g[i].x == g[i - 1].x and g[i].y == g[i - 1].y then dup = true end end
    local sorted = true
    for i = 2, #g do if g[i - 1].y > g[i].y or (g[i - 1].y == g[i].y and g[i - 1].x > g[i].x) then sorted = false end end
    check(not dup and sorted and #g == 3 * 8 + 2 - 2, "18.4 liste triee sans doublon (" .. #g .. ")")
    local _, bk = Rp.quai_guard(outs, S)
    local bkk = {}
    for _, t in ipairs(bk) do bkk[t.x .. ":" .. t.y] = true end
    check(bkk["458:458"] and bkk["460:458"] and bkk["466:458"] and bkk["458:454"], "18.4b la tuile du tapis derriere chaque autre coffre est rendue (sans poteau)")
    check(not bkk["459:458"] and not bkk["459:454"] and not bkk["459:457"] and not bkk["467:456"] and not bkk["460:456"], "18.4c ni les tuiles de S ni les voisines deja gardees")
    local okb = true
    for i = 2, #bk do if bk[i - 1].y > bk[i].y or (bk[i - 1].y == bk[i].y and bk[i - 1].x >= bk[i].x) then okb = false end end
    check(okb, "18.4d second rendu trie, sans doublon")
    local tiles_of_quai = {}
    for x = 458, 466 do tiles_of_quai[x .. ":456"] = true end
    local busy = { ["459:455"] = true, ["459:454"] = true, ["459:458"] = true }
    local function free(x, y) return not busy[x .. ":" .. y] and not tiles_of_quai[x .. ":" .. y] end
    check(#Li.sites(S.x, S.y, free) == 0, "18.5 etat du symptome : aucun site (bras et tapis) contre le coffre")
    local line = { ["459:458"] = 6, ["460:458"] = 6, ["458:458"] = 6 }
    local bs = Rp.branch_sites(S, free, function(x, y) return line[x .. ":" .. y] end)
    check(#bs == 1 and bs[1].dir == 4 and bs[1].ax == 459 and bs[1].ay == 457 and bs[1].bx == 459 and bs[1].by == 458, "18.6 le coffre verse par un bras sur la ligne voisine (face sud)")
    check(#Rp.branch_sites(S, free, function() return nil end) == 0, "18.7 aucune ligne : aucun branchement")
    check(#Rp.branch_sites(S, free, function(x, y) if x == 459 and y == 458 then return 0 end end) == 0, "18.8 un tapis qui verse sur la tuile du bras n'est pas un branchement")
    check(#Rp.branch_sites(S, free, function(x, y) return line[x .. ":" .. y] end, function(x, y) return not (x == 459 and y == 457) end) == 0, "18.9 bras refuse sur la ressource")
    check(#Rp.branch_sites(S, function(x, y) return free(x, y) and not (x == 459 and y == 457) end, function(x, y) return line[x .. ":" .. y] end) == 0, "18.10 tuile du bras prise : aucun branchement")
    local ents = Rp.branch_entities(bs[1] or { dir = 4, ax = 459, ay = 457, bx = 459, by = 458 }, { arm = "A", pole = "P" }, { 458, 457 })
    local isarm = function(e) return e.role == "liaison-bras" end
    check(#ents == 2 and #Rp.branch_verify(ents, S, { x = 459, y = 458 }, isarm) == 0, "18.11 bras et poteau, preuve juste (prend en S, depose sur la ligne)")
    check(#Rp.branch_verify(ents, S, { x = 460, y = 458 }, isarm) > 0, "18.12 la preuve voit un bras qui ne depose pas sur la ligne")
    check(#Rp.branch_verify(ents, { x = 460, y = 456 }, { x = 459, y = 458 }, isarm) > 0, "18.13 la preuve voit un bras qui ne prend pas au coffre")
    check(#Rp.branch_verify({ ents[1], ents[1] }, S, { x = 459, y = 458 }, isarm) > 0, "18.14 la preuve compte les bras")
    local E = Rp.branch_sites({ x = 0, y = 0 }, function() return true end, function(x, y) if x == 2 and y == 0 then return 4 end end)
    check(#E == 1 and E[1].dir == 2, "18.15 branchement a l'est (direction lue, pas supposee)")
  else
    check(false, "18.0 regles du quai et du branchement absentes (Rp.quai_guard, Rp.branch_sites)")
  end

  return fail_n, ok_n
end

-- §14 hygiène : aucun nom d'objet, aucun pairs dans la règle
local fails_hyg, n_hyg = 0, 0
local function hyg(c, msg) n_hyg = n_hyg + 1 if not c then fails_hyg = fails_hyg + 1 print("  ECHEC : " .. msg) end end
hyg(not SRC:find("pairs%(", 1) or not SRC:gsub("ipairs%(", ""):find("pairs%("), "14.1 aucun pairs dans la regle (seulement ipairs)")
for _, name in ipairs({ "iron", "copper", "plate", "stone", "coal", "gear", "inserter", "transport", "chest\"", "pole\"", "-belt" }) do
  hyg(not SRC:gsub("%-%-[^\n]*", ""):find(name, 1, true), "14.2 aucun nom d'objet dans la regle : " .. name)
end
hyg(not SRC:gsub("%-%-[^\n]*", ""):find("math.sin", 1, true) and not SRC:find("os.clock", 1, true) and not SRC:find("os.time", 1, true), "14.3 ni trigonometrie ni horloge")

-- §15 branchement (textes)
local function exists(path) local f = io.open(path, "rb") if f then f:close() return true end return false end
local fails_br, n_br = 0, 0
local function br(c, msg) n_br = n_br + 1 if not c then fails_br = fails_br + 1 print("  ECHEC : " .. msg) end end
if exists("script/team/rapatriement.lua") then
  local RT = read("script/team/rapatriement.lua")
  local BD = read("script/team/build.lua")
  br(RT:find('require("shared.team.rapatriement")', 1, true) ~= nil, "15.1 le runtime lit la regle pure")
  br(RT:find("[FO-RAPATRIEMENT]", 1, true) ~= nil or RT:find("Rp.text", 1, true) ~= nil, "15.2 le runtime ecrit le journal [FO-RAPATRIEMENT]")
  br(BD:find("Build.Rapatriement", 1, true) ~= nil and BD:find("spec.rapatriement", 1, true) ~= nil, "15.3 build.lua branche le plan de la ligne")
  br(BD:find("Build.Rapatriement.step", 1, true) ~= nil, "15.4 build.lua appelle le releve a chaque passe du plan directeur")
  br(BD:find("trips_collect", 1, true) ~= nil and BD:find("trips_fill", 1, true) ~= nil, "15.5 build.lua compte les trajets de collecte et de remplissage")
  br(RT:find("pairs%(") == nil or not RT:gsub("ipairs%(", ""):find("pairs%("), "15.6 aucun pairs dans le runtime (seulement ipairs et sorted_keys)")
  br(RT:find("fo%-war%-rapatriement") ~= nil, "15.7 le reglage fo-war-rapatriement commande la ligne")
  br(not RT:find("\nglobal%.") and not RT:find("[^%w_]global%.", 1), "15.8 global n'est pas nomme hors storage.lua")
  -- lot TAMPON-MINERAI : le runtime applique la règle du minerai à chaque choix du tampon (4 appels) et aux bras des paires de bouts
  local _, n_ok = RT:gsub("Rp%.SPOT_TRIES, nil, J%.ok%)", "")
  br(n_ok == 4, "15.9 les quatre recherches du tampon (point voulu et repli) passent la regle du minerai (" .. n_ok .. ")")
  br(RT:find("J.ends = Rp.ends_ok(Li.pick_ends(J.S, J.D, J.free), J.ok.arm, Rp.ROUTE_TRIES)", 1, true) ~= nil, "15.10 les bras de depart et d'arrivee passent la regle du minerai")
  br(RT:find("res = m.res", 1, true) ~= nil and RT:find('"L", "ok" }', 1, true) ~= nil and RT:find("Rp.off_ore(ptype(lc.chest), ore)", 1, true) ~= nil
    and RT:find("Rp.off_ore(ptype(lc.arm), ore)", 1, true) ~= nil, "15.11 tuiles de ressource lues aux masques, types lus aux prototypes, regle retiree de l'etat")
end

-- §16 mutants : chaque règle faussée doit faire échouer au moins un contrôle
local base_fail, base_ok = suite(load_rp(SRC), false)
print(string.format("  suite sur la regle : %d OK, %d ECHEC", base_ok, base_fail))
local function mutant(label, from, to, count)
  local src, n = SRC:gsub(from:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"), (to:gsub("%%", "%%%%")), count or 1)
  if n == 0 then return false, label .. " (motif introuvable : " .. from .. ")" end
  local ok, Rp = pcall(load_rp, src)
  if not ok then return true, label end -- une règle qui ne se charge plus est vue
  local ran, fails = pcall(suite, Rp, true)
  if not ran then return true, label end -- une exception est vue
  return fails > base_fail, label
end
local mutants = {
  { "mediane : le seuil de la moitie devient un tiers", "if cum * 2 >= total then", "if cum * 3 >= total then" },
  { "mediane : le poids est oublie", "cum = cum + e[2]", "cum = cum + 1" },
  { "tampon : y oublie (x pour les deux axes)", "local x, y = Rp.wmedian(xs), Rp.wmedian(ys)", "local x, y = Rp.wmedian(xs), Rp.wmedian(xs)" },
  { "cout : distance de Chebyshev au lieu de Manhattan", "c = c + (k.flow or 0) * manhattan(k.x, k.y, x, y)", "c = c + (k.flow or 0) * math.max(math.abs(k.x - x), math.abs(k.y - y))" },
  { "cout : le debit est oublie", "c = c + (k.flow or 0) * manhattan(k.x, k.y, x, y)", "c = c + manhattan(k.x, k.y, x, y)" },
  { "prix : la jambe lointaine devient la jambe du tampon", "local far = Rp.leg(inp.d_src or 0, Rp.COLLECT_BATCH)", "local far = Rp.leg(inp.d_tam or 0, Rp.COLLECT_BATCH)" },
  { "prix : le reste a porter est oublie", "local rest = (1 - phi) * Rp.leg(inp.d_tam or 0, Rp.COLLECT_BATCH)", "local rest = 0" },
  { "prix : le gain a le mauvais signe", "local save_s = flow * (far - rest + fill)", "local save_s = flow * (rest - far + fill)" },
  { "prix : le debit n'entre pas dans l'economie", "local save_s = flow * (far - rest + fill)", "local save_s = (far - rest + fill)" },
  { "prix : le cout des tuiles est oublie", "local cost = tiles * price.belt +", "local cost = 0 * tiles * price.belt +" },
  { "prix : la menace ne divise plus le retour", "if inp.threat then tmax = tmax / Rp.THREAT_DIV end", "" },
  { "prix : phi n'est plus borne", "phi = min(1, max(0, (inp.covered or 0) / flow))", "phi = max(0, (inp.covered or 0) / flow)" },
  { "candidats : la distance minimale est oubliee", "and d_src >= Rp.MIN_DIST then", "then" },
  { "candidats : une sortie liee est reprise", "if s.item and not s.linked and", "if s.item and" },
  { "candidats : un quai deja servi est consommateur", "if d.item and not d.served and", "if d.item and" },
  { "candidats : le debit minimal est oublie", "(s.rate or 0) >= Rp.MIN_RATE and d_src", "true and d_src" },
  { "bus-sortie : le quai n'est plus l'arrivee", "then reuse = d end", "then end" },
  { "bus-sortie : le tampon passe avant le quai", "if not reuse then for _, t in ipairs(o.tampons or {}) do", "if true then for _, t in ipairs(o.tampons or {}) do" },
  { "bus-sortie : le quai le plus loin", "manhattan(d.x, d.y, px, py) < manhattan(reuse.x, reuse.y, px, py)", "manhattan(d.x, d.y, px, py) > manhattan(reuse.x, reuse.y, px, py)" },
  { "bus-sortie : quai a toute distance", "if manhattan(d.x, d.y, px, py) <= Rp.REUSE_R and", "if true and" },
  { "candidats : le QG reste au centre d'entite (demi-tuile)", "hub = { x = floor(hub.x), y = floor(hub.y) }", "hub = { x = hub.x, y = hub.y }" },
  { "candidats : seul x est ramene a la tuile", "hub = { x = floor(hub.x), y = floor(hub.y) }", "hub = { x = floor(hub.x), y = hub.y }" },
  { "candidats : seul y est ramene a la tuile", "hub = { x = floor(hub.x), y = floor(hub.y) }", "hub = { x = hub.x, y = floor(hub.y) }" },
  { "candidats : arrondi vers le haut (tuile voisine)", "hub = { x = floor(hub.x), y = floor(hub.y) }", "hub = { x = math.ceil(hub.x), y = math.ceil(hub.y) }" },
  { "candidats : arrondi au plus proche (tuile voisine)", "hub = { x = floor(hub.x), y = floor(hub.y) }", "hub = { x = floor(hub.x + 0.5), y = floor(hub.y + 0.5) }" },
  { "candidats : la tuile du QG n'est plus lue (centre gardé pour le tampon)", "if not px then px, py = hub.x, hub.y end", "if not px then px, py = hub.x + 0.5, hub.y + 0.5 end" },
  { "candidats : le tampon n'est plus ramene au QG", "px, py = Rp.clamp_near(px, py, hub, Rp.NEAR_HUB)", "" },
  { "candidats : le tampon du meme objet n'est pas controle", "if t.item == s.item and (t.lines or 1) < Rp.REUSE_MAX", "if (t.lines or 1) < Rp.REUSE_MAX" },
  { "candidats : la limite de lignes par tampon est oubliee", "(t.lines or 1) < Rp.REUSE_MAX and", "true and" },
  { "chemin : le poids de l'heuristique est ignore", "local h = (math.abs(nx - t.x) + math.abs(ny - t.y)) * hw", "local h = (math.abs(nx - t.x) + math.abs(ny - t.y))" },
  { "chemin : le plafond de noeuds est ignore", "if job.expanded > (cap or math.huge) then", "if false then" },
  { "chemin : un noeud ferme est rouvert", "if not closed[nk] then\n            local c = cost(nx, ny)", "if true then\n            local c = cost(nx, ny)" },
  { "chemin : la tranche ne rend jamais la main", "if left <= 0 then return \"more\" end", "" },
  { "chemin : tas sans depart a egalite de cle", "if a.f < b.f or (a.f == b.f and (a.h < b.h or (a.h == b.h and a.k < b.k))) then m = r end", "if a.f <= b.f then m = r end" },
  { "bord de rue : le croisement compte", "if xs and ys then return false end -- croisement", "" },
  { "bord de rue : le milieu de la rue compte", "if xs then return rx == geom.lot or rx == geom.pitch - 1 end", "if xs then return true end" },
  { "bord de rue : un seul bord", "if ys then return ry == geom.lot or ry == geom.pitch - 1 end", "if ys then return ry == geom.lot end" },
  { "candidats : le stock dormant compte comme une production", "if s.nature == \"stock\" then flow = flow * Rp.STOCK_FACTOR end", "" },
  { "debit : le pic remplace la mediane", "best = rises[floor((#rises + 1) / 2)]", "best = rises[#rises]" },
  { "candidats : les quais a portee s'additionnent", "and d.flow > covered then covered = d.flow end", "then covered = covered + d.flow end" },
  { "candidats : la saturation est ignoree", "if s.saturated and #cons == 0 then ok, why = false, Rp.WHY_SATURATED end", "" },
  { "candidats : le tri est inverse", "if a.net ~= b.net then return a.net > b.net end", "if a.net ~= b.net then return a.net < b.net end" },
  { "decision : la confirmation est oubliee", "if (inp.seen or 0) < Rp.CONFIRM then", "if false then" },
  { "decision : la menace est ignoree", "if inp.threat then return", "if false then return" },
  { "decision : l'ennemi est ignore", "if (inp.enemies or 0) > 0 then", "if false then" },
  { "decision : la limite de lignes est oubliee", "if (inp.lines or 0) >= Rp.MAX_LINES then", "if false then" },
  { "decision : les lignes ouvertes ne bornent plus", "if (inp.open_total or 0) >= Rp.max_open(inp.free) then", "if false then" },
  { "decision : les essais epuises sont repris", "if (inp.tries or 0) >= Rp.MAX_TRIES and", "if false and" },
  { "anneau : les tuiles du bord sont doublees", "if rem == 0 then out[#out + 1] = { px, py + dy }", "if rem == 0 then out[#out + 1] = { px, py + dy } out[#out + 1] = { px, py + dy }" },
  { "points : les sites du bras ne sont pas exiges", "if #sites > 0 then", "if true then" },
  { "trace : le detour n'est plus borne", "if len > lim then", "if false then" },
  { "trace : la longueur n'est plus bornee", "if len > Rp.MAX_LEN then", "if false then" },
  { "entites : le coffre tampon est pose a l'opposee", "x = inp.dst.ax - v[1] + 0.5, y = inp.dst.ay - v[2] + 0.5", "x = inp.dst.ax + v[1] + 0.5, y = inp.dst.ay + v[2] + 0.5" },
  { "entites : le coffre est pose meme reutilise", "if not inp.reuse then", "if true then" },
  { "preuve : le compte des coffres est oublie", "elseif chests ~= 1 then", "elseif false then" },
  { "preuve : la tuile du coffre n'est plus controlee", "if floor(e.x) ~= D.x or floor(e.y) ~= D.y then", "if false then" },
  { "barre : la case libre (F95) est oubliee", "return slots + 1", "return slots" },
  { "barre : le plafond d'objets est oublie", "local objs = min(Rp.BUFFER_MAX_OBJ, max(Rp.BUFFER_MIN_OBJ, ceil((flow or 0) * 60 * Rp.BUFFER_MIN)))", "local objs = max(Rp.BUFFER_MIN_OBJ, ceil((flow or 0) * 60 * Rp.BUFFER_MIN))" },
  { "barre : le plancher d'objets est oublie", "local objs = min(Rp.BUFFER_MAX_OBJ, max(Rp.BUFFER_MIN_OBJ, ceil((flow or 0) * 60 * Rp.BUFFER_MIN)))", "local objs = min(Rp.BUFFER_MAX_OBJ, ceil((flow or 0) * 60 * Rp.BUFFER_MIN))" },
  { "debit : le bras ne borne plus", "if arm and best > arm then best = arm end", "" },
  { "debit : le stock dormant est ignore", "if n >= (at or Rp.COLLECT_BATCH) then", "if false then" },
  { "journal : le compte des trajets lointains disparait", "%.1f lointain(s)", "%.1f proche(s)" },
  { "repli (PLAQUES) : plus de pas du QG vers la sortie", "  walk(hub.x, hub.y, tx, ty)", "  local _ = tx" },
  { "repli (PLAQUES) : la sortie n'est plus bornee a la portee", "local tx, ty = Rp.clamp_near(src.x, src.y, hub, reach)", "local tx, ty = src.x, src.y" },
  { "repli (PLAQUES) : plus de pas vers le QG", "  walk(px, py, hub.x, hub.y)", "  local _ = px" },
  { "repli (PLAQUES) : les doublons sont repris", "      if not seen[k] then", "      if true then" },
  { "minerai (TAMPON-MINERAI) : le coffre n'est plus controle", " and (not ok or ok.chest(t[1], t[2]))", "" },
  { "minerai (TAMPON-MINERAI) : les bras des sites ne sont plus controles", "if ok then sites = Rp.sites_ok(sites, ok.arm) end", "" },
  { "minerai (TAMPON-MINERAI) : le bras de depart n'est plus controle", "if arm_ok(e.src.ax, e.src.ay) and arm_ok(e.dst.ax, e.dst.ay) then", "if arm_ok(e.dst.ax, e.dst.ay) then" },
  { "minerai (TAMPON-MINERAI) : le bras d'arrivee n'est plus controle", "if arm_ok(e.src.ax, e.src.ay) and arm_ok(e.dst.ax, e.dst.ay) then", "if arm_ok(e.src.ax, e.src.ay) then" },
  { "minerai (TAMPON-MINERAI) : la regle du sol est muette", "return not Sm.forbidden(ptype, function() return ore(x, y) == true end)", "return true" },
  { "minerai (TAMPON-MINERAI) : tapis refuses sur la ressource", "return not Sm.forbidden(ptype, function() return ore(x, y) == true end)", "return not ore(x, y)" },
  { "minerai (TAMPON-MINERAI) : le max des paires est oublie", "if max_n and #out >= max_n then break end", "" },
}
for _, m in ipairs({
  { "quai (SORTIE-COFFRE) : les voisines des autres coffres ne sont plus gardees", "if not seen[k] and not mine[k] then", "if false then" },
  { "quai (SORTIE-COFFRE) : la face de S est gardee", "local faces = ring(1, seen, {}, own)", "local faces = ring(1, seen, {}, {})" },
  { "quai (SORTIE-COFFRE) : la tuile du tapis de S est rendue", [==[own2[(S.x + 2 * v[1]) .. ":" .. (S.y + 2 * v[2])] = true]==], "local _ = 0" },
  { "quai (SORTIE-COFFRE) : les tuiles a deux pas sont oubliees", "return faces, ring(2, seen, {}, own2)", "return faces, {}" },
  { "quai (SORTIE-COFFRE) : les tuiles a deux pas reprennent les voisines", "return faces, ring(2, seen, {}, own2)", "return faces, ring(2, {}, {}, own2)" },
  { "branchement (SORTIE-COFFRE) : la ligne n'est plus exigee", "local w = Li.DV[belt_dir(bx, by) or -1]", "local w = Li.DV[belt_dir(bx, by) or 0]" },
  { "branchement (SORTIE-COFFRE) : tapis qui verse sur le bras accepte", "if w and not (bx + w[1] == ax and by + w[2] == ay) and", "if w and" },
  { "branchement (SORTIE-COFFRE) : tuile du bras non controlee", "and free(ax, ay) and (not arm_ok", "and (not arm_ok" },
  { "branchement (SORTIE-COFFRE) : minerai ignore", "and (not arm_ok or arm_ok(ax, ay)) then", "then" },
  { "branchement (SORTIE-COFFRE) : bras a l'envers", "dir = (site.dir + 4) % 8, role", "dir = site.dir, role" },
  { "branchement (SORTIE-COFFRE) : la preuve ne compte plus les bras", "if #arms ~= 1 then bad[1]", "if #arms == 0 then bad[1]" },
  { "branchement (SORTIE-COFFRE) : la depose n'est plus controlee", "if not v or tx - v[1] ~= B.x or ty - v[2] ~= B.y then", "if false then" },
}) do mutants[#mutants + 1] = m end
local refused, total_m = 0, 0
local survivors = {}
for _, m in ipairs(mutants) do
  do
    total_m = total_m + 1
    local seen, label = mutant(m[1], m[2], m[3])
    if seen then refused = refused + 1 else survivors[#survivors + 1] = label end
  end
end
print(string.format("  mutants refuses : %d / %d", refused, total_m))
for _, s in ipairs(survivors) do print("  SURVIVANT : " .. s) end

local total_ok = base_ok + n_hyg - fails_hyg + n_br - fails_br
local total_fail = base_fail + fails_hyg + fails_br + (total_m - refused)
print(string.format("[RAPATRIEMENT] BILAN : %d OK, %d ECHEC(S) ; mutants refuses %d / %d", total_ok, total_fail, refused, total_m))
os.exit(total_fail == 0 and 0 or 1)
