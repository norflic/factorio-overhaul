--[[
  Lot PREVISION : banc HORS JEU de l'estimateur UNIQUE de la menace (shared/ai3/prevision.lua) et de ses décisions
  (shared/ai3/prevision_choix.lua). Lancement, depuis la racine du mod : lua5.2 tests/prevision_test.lua

  Sections :
    1. composition des vagues (result_units : interpolation du moteur, moyennes, plafond de cadence) ;
    2. pollution qui ARRIVE au nid (C5 : case polluée = plafond, case propre = flux des voisines), constantes contrôlées contre
       les données vanilla (data/base) et le mod (prototypes/enemies.lua ne les change pas) ;
    3. attribution (C6) : au site POLLUEUR le plus attirant (avant-poste, pas l'octant du QG), part de l'équipe contre un rival ;
    4. vagues (C7) : monotonie (pollution, nids, évolution), plafond de groupe, taille ≠ débit, échéance pessimiste, horizons
       distincts par l'évolution projetée, ce qui est VU l'emporte ;
    5. défense calculée depuis les prototypes (C9) et généralisation sur des données changées ;
    6. calibration SYMÉTRIQUE (C8) : vague reçue, fausse alerte, raté, bornes, aucun mouvement sans fait ;
    7. décisions : hystérésis (60 relevés bruités : une ouverture au plus), fermeture à la cible, aucune horloge, insurmontable
       avec hystérésis, réserve mobile sans ping-pong (C4), PREP_MAX, « production d'abord », trou d'exécutant (C10), budget en
       rampe au-dessus de la réserve de production (C1, C2), rang par échéance (moyen terme : armée visée sans retenue), menace
       couverte constante ;
    8. raid préventif (porte : valeur, autres vagues) ;
    9. défense induite (C12) ;
   10. déterminisme et état sérialisable ;
   11. mutants (règle retirée par substitution du texte) : chacun fait échouer au moins un contrôle.
  Limite écrite (critique §4) : ce banc prouve la PLOMBERIE et les propriétés ; la PRÉCISION du modèle contre le moteur ne se
  prouve qu'en moteur réel (bancs prev-vague, prev-ombre : non joués par ce lot).
]]
package.path = "./?.lua;" .. package.path

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end

local function deep_ok(t, seen)
  seen = seen or {}
  if type(t) ~= "table" then return type(t) ~= "function" and type(t) ~= "userdata" end
  if seen[t] then return false end -- référence partagée : refusée (copie attendue)
  seen[t] = true
  for k, v in pairs(t) do
    if type(k) == "table" or not deep_ok(v, seen) then return false end
  end
  return true
end

-- Données synthétiques : un type de nid, deux unités (petite dès 0, grosse à partir de 300 ‰).
local SMALL = { hp = 15, cost = 4, speed = 0.2, pts = { { 0, 300 }, { 600, 0 } } }
local BIG = { hp = 375, cost = 80, speed = 0.15, pts = { { 300, 0 }, { 900, 400 } } }
local KINDS = { { units = { SMALL, BIG }, rate_max = 60 } }
local GATHER = { min = 1, max = 10, size = 200 }

local function site(key, x, y, over)
  local s = { key = key, x = x, y = y, emit = 100, dps = 0, dpsr = 0, turrets = 0, seen = 0, contact = 0 }
  for k, v in pairs(over or {}) do s[k] = v end
  return s
end
local function nest(x, y, c, nb) return { x = x, y = y, c = c or 0, nb = nb or 0 } end

local function battery(Pv, Pc)
  local function est(over)
    local inp = { evo = 0, g = 0, kinds = KINDS, gather = GATHER, diff = 20, sites = { site("qg", 0, 0) },
      nests = { nest(100, 0, 50) }, rivals = {} }
    for k, v in pairs(over or {}) do inp[k] = v end
    return Pv.estimate(inp)
  end

  section("1. Composition des vagues")
  check(Pv.weight_at(SMALL.pts, 0) == 300 and Pv.weight_at(SMALL.pts, 300) == 150 and Pv.weight_at(SMALL.pts, 900) == 0,
    "interpolation linéaire entre les points, bornée au dernier (300, 150, 0)")
  check(Pv.weight_at(BIG.pts, 0) == 0 and Pv.weight_at(BIG.pts, 600) == 200 and Pv.weight_at(BIG.pts, 1000) == 400,
    "avant le premier point : son poids ; au-delà du dernier : le sien")
  local m0, m6 = Pv.mix(KINDS, 0), Pv.mix(KINDS, 600)
  check(m0 and m0.hbar == 15 and m0.pbar == 4, "évolution 0 : seulement la petite unité (15 PV, 4 de pollution)")
  check(m6 and m6.hbar == 375 and m6.pbar == 80, "évolution 600 : seulement la grosse")
  local m3 = Pv.mix(KINDS, 450)
  check(m3 and m3.hbar > 15 and m3.hbar < 375 and m3.cap == 60, "entre les deux : moyenne pondérée, plafond de cadence du prototype")
  check(Pv.mix({}, 0) == nil and Pv.mix({ { units = { { hp = 1, cost = 0, pts = { { 0, 1 } } } } } }, 0) == nil,
    "aucun nid lisible (ou coût nul) : aucune composition, aucune vague modélisée")
  check(Pv.evo_at(0, 0.01, 5) > 0 and Pv.evo_at(0, 0.01, 15) > Pv.evo_at(0, 0.01, 5) and Pv.evo_at(1000, 0.5, 15) == 1000,
    "évolution projetée : croissante avec l'horizon, jamais au-delà de 1000")

  section("2. Pollution qui ARRIVE au nid (C5)")
  check(Pv.absorbed(100, 0, 20) == Pv.ABS + Pv.PROP * 100 / 1000, "case polluée : le nid absorbe à son plafond (il en reste)")
  check(Pv.absorbed(200, 0, 20) > Pv.absorbed(100, 0, 20), "plus de pollution à la case : plus d'absorption")
  check(Pv.absorbed(0, 0, 20) == 0, "case propre, voisines propres : rien n'arrive, le nid ne nous vise pas")
  local edge = Pv.absorbed(0, 4, 20)
  check(edge > 0 and edge <= Pv.ABS, "nid en BORD de nuage (case propre, voisine polluée) : il absorbe ce qui arrive (" .. edge .. ")")
  check(Pv.absorbed(0, 1000, 20) == Pv.ABS, "flux entrant au-delà du plafond : le plafond")
  check(Pv.absorbed(0, 4, 40) >= Pv.absorbed(0, 4, 20), "plus de diffusion : au moins autant d'absorption")
  -- Constantes contre les données vanilla et le mod (le moteur ne les donne pas en runtime).
  local data = (os.getenv("FO_DATA_DIR") or "../../data") .. "/base/prototypes/entity/enemies.lua"
  local fh = io.open(data, "rb")
  if fh then
    local src = fh:read("*a")
    fh:close()
    check(src:find("pollution_absorption_absolute = " .. Pv.ABS, 1, true) ~= nil
      and src:find("pollution_absorption_proportional = " .. (Pv.PROP / 1000), 1, true) ~= nil,
      "Pv.ABS et Pv.PROP valent les données vanilla des nids (" .. data .. ")")
  else
    print("  (données vanilla introuvables : " .. data .. " ; FO_DATA_DIR=<racine>/data ; contrôle sauté)")
  end
  local mh = io.open("prototypes/enemies.lua", "rb")
  if mh then
    local msrc = mh:read("*a")
    mh:close()
    check(not msrc:find("pollution_absorption", 1, true), "le mod ne change pas l'absorption des nids (prototypes/enemies.lua)")
  end

  section("3. Attribution (C6) : au site pollueur, part de l'équipe")
  local two = est({ sites = { site("qg", 0, 0, { emit = 100 }), site("ap1", 150, 0, { emit = 100 }) }, nests = { nest(180, 0, 50) } })
  check(two.by.ap1.rate > 0 and two.by.qg.rate == 0, "le nid près de l'avant-poste nourrit la vague de l'AVANT-POSTE (pas un octant du QG)")
  local mute = est({ sites = { site("qg", 0, 0, { emit = 100 }), site("ap1", 150, 0, { emit = 0 }) }, nests = { nest(180, 0, 50) } })
  check(mute.by.ap1.rate == 0 and mute.by.qg.rate > 0, "un site qui ne pollue pas n'attire pas la vague")
  local alone = est({})
  local shared = est({ rivals = { { x = 200, y = 0 } } })
  local rival_near = est({ rivals = { { x = 110, y = 0 } } })
  check(shared.by.qg.rate < alone.by.qg.rate and rival_near.by.qg.rate < shared.by.qg.rate and rival_near.by.qg.rate > 0,
    "un QG rival plus proche du nid prend une plus grande part de la vague")
  check(math.abs(Pv.share(3, 1) + Pv.share(1, 3) - 1000) <= 1, "parts complémentaires : deux équipes ne prévoient pas chacune la vague entière")
  check(est({ nests = { nest(Pv.R_ATTR + 20, 0, 50) } }).by.qg.rate == 0, "nid au-delà de Pv.R_ATTR de tous nos sites : ne nous vise pas")

  section("4. Vagues (C7)")
  local e1 = est({})
  local o1 = e1.by.qg
  check(o1.rate > 0 and o1.w5 > 0 and o1.wmod5 == o1.w5, "nid pollué à 100 tuiles : vague prévue")
  check(math.abs(o1.eta - (GATHER.min + 100 / (0.2 * 3600))) < 1e-6, "échéance PESSIMISTE : rassemblement minimal + marche la plus courte")
  check(est({ nests = { nest(100, 0, 50), nest(100, 10, 50) } }).by.qg.w5 > o1.w5, "plus de nids : vague plus grosse")
  check(est({ nests = { nest(100, 0, 500) } }).by.qg.w5 > o1.w5, "plus de pollution : vague plus grosse")
  check(est({ evo = 400 }).by.qg.w5 > o1.w5, "plus d'évolution : vague plus grosse (unités plus fortes)")
  check(est({ evo = 250, g = 0.05 }).by.qg.w15 > est({ evo = 250, g = 0.05 }).by.qg.w5,
    "horizons distincts : à 15 min l'évolution projetée grossit la vague")
  local many = {}
  for i = 1, 30 do many[#many + 1] = nest(100, i, 1e6) end
  local big = est({ nests = many }).by.qg
  check(big.u5 <= GATHER.size, "taille d'une vague au plus la taille de groupe du moteur (" .. big.u5 .. ")")
  check(big.debit15 > big.w15, "débit sur 15 min (munitions) distinct de la taille d'une vague (défense)")
  local slow = Pv.estimate({ evo = 0, kinds = { { units = { { hp = 15, cost = 4, speed = 0.005, pts = { { 0, 1 } } } } } },
    gather = GATHER, sites = { site("qg", 0, 0) }, nests = { nest(200, 0, 50) }, rivals = {} }).by.qg
  check(slow.eta > Pv.H_COURT and slow.w5 == 0 and slow.w15 > 0, "vague lointaine (échéance > 5 min) : rien à court terme, prévue à 15 min")
  local seen = est({ sites = { site("qg", 0, 0, { seen = 9000, vx = 9000 * 50, vy = 0 }) } }).by.qg
  check(seen.w5 == 9000 and seen.wvu == 9000, "ce qui est VU à portée d'œil l'emporte s'il est plus gros")
  local seen2 = est({ sites = { site("qg", 0, 0, { seen = 9000, vx = 0, vy = 9000 * -60 }) } , nests = {} }).by.qg
  check(seen2.tx == 0 and seen2.ty == -60, "sans nid rattaché : la menace vient du barycentre des unités vues")
  check(est({ nests = { nest(100, 0, 0, 0) } }).by.qg.w5 == 0, "nid connu sans pollution reçue : aucune vague")

  section("5. Défense calculée depuis les prototypes (C9)")
  local v1 = Pv.turrets_value(50, 50 * 18, 0.2)
  check(math.abs(v1 - (50 * Pv.T_HOLD + 50 * 18 / (0.2 * 60))) < 1e-9, "tourelle : dps × (traversée de la portée + tenue)")
  check(math.abs(Pv.turrets_value(100, 100 * 18, 0.2) - 2 * v1) < 1e-9, "données changées (dégâts doublés) : valeur doublée, aucune table par âge")
  check(Pv.turrets_value(50, 50 * 18, 0.1) > v1, "ennemis plus lents : plus longtemps sous le feu")
  check(Pv.soldier_value(24) == 24 * Pv.T_SOLDIER * Pv.ARENA / 1000, "soldat : dps × temps de combat × arène (un seul facteur)")
  local ed = est({ sites = { site("qg", 0, 0, { dps = 100, dpsr = 1800, turrets = 2 }) } }).by.qg
  check(ed.d > 0 and ed.turrets == 2, "défense du site lue de ses tourelles")

  section("6. Calibration symétrique (C8)")
  local cal = {}
  local keys = { "qg" }
  Pv.calibrate(cal, keys, { qg = { pred_raw = 1000, window = 20, source = true } }, 0)
  check(cal.qg.k == Pv.K0 and cal.qg.ep and cal.qg.ep.pred == 1000, "vague prévue : épisode ouvert, k inchangé")
  for t = 1, 5 do Pv.calibrate(cal, keys, { qg = { pred_raw = 1000, window = 20, source = true } }, t * 3600) end
  check(cal.qg.k == Pv.K0, "aucun fait (ni contact, ni perte, fenêtre pas passée) : k ne bouge pas")
  Pv.calibrate(cal, keys, { qg = { pred_raw = 1000, contact = 2000, window = 20, source = true } }, 6 * 3600)
  local ev = Pv.calibrate(cal, keys, { qg = { pred_raw = 1000, window = 20, source = true } }, 7 * 3600)
  check(#ev == 1 and ev[1].kind == "vague" and ev[1].recv == 2000 and cal.qg.k > Pv.K0, "vague reçue deux fois plus grosse : k monte")
  local cal2 = {}
  Pv.calibrate(cal2, keys, { qg = { pred_raw = 1000, window = 20, source = true } }, 0)
  local ev2 = Pv.calibrate(cal2, keys, { qg = { pred_raw = 1000, window = 20, source = true } }, 21 * 3600)
  check(#ev2 == 1 and ev2[1].kind == "fausse" and cal2.qg.k < Pv.K0 and cal2.qg.fa == 1,
    "fausse alerte (la vague prévue n'est pas venue dans la fenêtre du moteur) : k BAISSE (symétrie)")
  local cal3 = {}
  Pv.calibrate(cal3, keys, { qg = { pred_raw = 0, losses = 2, hbar = 100, source = true } }, 0)
  local ev3 = Pv.calibrate(cal3, keys, { qg = { pred_raw = 0, source = true } }, 3600)
  check(#ev3 == 1 and ev3[1].kind == "rate" and cal3.qg.k > Pv.K0 and cal3.qg.floor == 2 * Pv.LOSS_UNITS * 100,
    "raté (attaque sans vague prévue, mesurée par nos PERTES) : k monte, plancher de menace")
  Pv.calibrate(cal3, keys, { qg = { pred_raw = 0, source = false } }, 7200)
  check(cal3.qg.floor == nil, "plancher retiré quand plus rien ne nous vise (fait, pas horloge)")
  local cal3b = {}
  Pv.calibrate(cal3b, keys, { qg = { pred_raw = 500, contact = 600, source = true } }, 0)
  local ev3b = Pv.calibrate(cal3b, keys, { qg = { pred_raw = 500, source = true } }, 3600)
  check(#ev3b == 1 and ev3b[1].kind == "vague" and ev3b[1].pred == 500,
    "attaque dans le relevé même où la vague est prévue : comparée à la prévision (pas un raté)")
  local cal4 = { qg = { k = Pv.K_MAX, hit = 0, fa = 0, miss = 0 } }
  Pv.calibrate(cal4, keys, { qg = { pred_raw = 0, contact = 1e9 } }, 0)
  Pv.calibrate(cal4, keys, { qg = {} }, 60)
  local cal5 = { qg = { k = Pv.K_MIN, hit = 0, fa = 0, miss = 0 } }
  Pv.calibrate(cal5, keys, { qg = { pred_raw = 1e9, window = 1 } }, 0)
  Pv.calibrate(cal5, keys, { qg = {} }, 2 * 3600)
  check(cal4.qg.k == Pv.K_MAX and cal5.qg.k == Pv.K_MIN, "k borné à [K_MIN, K_MAX]")
  local w_hi = est({ k = { qg = 2000 } }).by.qg.w5
  check(math.abs(w_hi - 2 * o1.w5) < 1e-6, "k appliqué à la vague modélisée")

  section("7. Décisions")
  local function ctx(over)
    local c = { soldiers = 10, soldiers_max = 30, soldier_value = 480, mobile = 0, turret_value = 600, turret_stock = 0,
      iron = 2000, reserve = 150, kit_iron = 20, turret_iron = 60, recruit_ok = true }
    for k, v in pairs(over or {}) do c[k] = v end
    return c
  end
  -- Vague imposée par ce qui est vu : w5 = W, défense des tourelles d.
  local function e_w(w, dps, extra)
    local s = site("qg", 0, 0, { seen = w, vx = w * 60, vy = 0, dps = dps or 0, dpsr = (dps or 0) * 18, turrets = 2 })
    local sites = { s }
    for _, x in ipairs(extra or {}) do sites[#sites + 1] = x end
    return Pv.estimate({ evo = 0, kinds = KINDS, gather = GATHER, sites = sites, nests = {}, rivals = {} })
  end
  local d1 = e_w(1, 10).by.qg.d
  -- a. Hystérésis : 60 relevés qui oscillent de ±15 % autour du seuil d'ouverture.
  local st = Pc.new()
  local opens = 0
  for i = 1, 60 do
    local f = (i % 2 == 0) and 1.15 or 0.85
    Pc.update(st, e_w(d1 * Pc.RHO_IN / 1000 * f, 10), ctx({ soldiers_max = 0 }), i * 3600)
    for _, e in ipairs(st.events) do if e.kind == "ouvert" then opens = opens + 1 end end
  end
  check(opens <= 1, "60 relevés bruités (±15 %) autour du seuil : une ouverture au plus (" .. opens .. ")")
  -- b. Ouverture, fermeture à la cible, aucune horloge.
  local s2 = Pc.new()
  Pc.update(s2, e_w(3 * d1, 10), ctx({ soldiers_max = 0 }), 0)
  check(s2.sites.qg.prep and s2.sites.qg.want > s2.sites.qg.have, "vague 3 × la défense : PRÉPARER ouvert, tourelles voulues")
  Pc.update(s2, e_w(3 * d1, 10), ctx({ soldiers_max = 0 }), 10 * 60 * 3600)
  check(s2.sites.qg.prep, "AUCUNE horloge : 10 h plus tard, tant que l'écart tient, le cadre tient")
  Pc.update(s2, e_w(3 * d1, 10 * 3 * Pc.MARGE / 1000 + 1), ctx({ soldiers_max = 0 }), 10 * 60 * 3600 + 3600)
  check(not s2.sites.qg.prep, "défense posée jusqu'à la cible W × MARGE : fermé (une seule règle, C10)")
  Pc.update(s2, e_w(3 * d1, 10), ctx({ soldiers_max = 0 }), 2e7)
  Pc.update(s2, e_w(0, 10), ctx({ soldiers_max = 0 }), 2e7 + 3600)
  check(not s2.sites.qg.prep, "vague retombée : fermé")
  -- c. Menace COUVERTE constante : jamais ouverte, jamais retenue.
  local s3 = Pc.new()
  local ever = false
  for i = 1, 60 do
    Pc.update(s3, e_w(d1 * 0.8, 10), ctx({ soldiers_max = 0 }), i * 3600)
    if s3.sites.qg.prep then ever = true end
  end
  check(not ever, "menace moyenne constante et couverte : aucun cadre en 60 relevés")
  -- d. Rows : pile et front, en pièces.
  local s4 = Pc.new()
  Pc.update(s4, e_w(3 * d1, 10), ctx({ soldiers_max = 0 }), 0)
  local pr = Pc.pile_rows(s4, { "qg" })
  local fr = Pc.front_rows(s4, { "qg" })
  check(#pr == 1 and pr[1].exec and not pr[1].nohold and pr[1].want > pr[1].have, "pile : un cadre qui retient, tourelles en pièces")
  check(#fr == 1 and fr[1].key == "prev:qg" and fr[1].x > 0 and fr[1].x <= Pc.PREP_OFFSET + 1e-9,
    "front : tourelles d'avance du côté de la menace, à PREP_OFFSET du centre")
  Pc.update(s4, e_w(3 * d1, 10), ctx({ soldiers_max = 0, front = { qg = "refus" } }), 3600)
  check(not s4.sites.qg.exec and s4.sites.qg.nohold, "front refusé et aucune recrue : sans exécutant, ne retient pas (C10)")
  Pc.update(s4, e_w(3 * d1, 10), ctx({ soldiers_max = 0, production_first = true }), 7200)
  check(s4.sites.qg.nohold and s4.sites.qg.why == "production d'abord", "« production d'abord » : les ressources d'abord, aucun cadre ne retient")
  -- e. PREP_MAX.
  local three = e_w(3 * d1, 10, { site("ap1", 300, 0, { seen = 4 * d1, vx = 4 * d1 * 300, vy = 0, dps = 10, dpsr = 180, turrets = 2 }),
    site("ap2", -300, 0, { seen = 5 * d1, vx = 5 * d1 * -300, vy = 0, dps = 10, dpsr = 180, turrets = 2 }) })
  local s5 = Pc.new()
  Pc.update(s5, three, ctx({ soldiers_max = 0 }), 0)
  local hold = 0
  for _, k in ipairs({ "qg", "ap1", "ap2" }) do if s5.sites[k].prep and not s5.sites[k].nohold then hold = hold + 1 end end
  check(hold == Pc.PREP_MAX and s5.sites.qg.nohold, "trois sites menacés : seuls les PREP_MAX plus grands écarts retiennent")
  -- f. Réserve mobile : une seule vague à la fois, sans ping-pong (C4).
  local sw = site("ap1", 0, 200, { seen = 2 * d1, vx = 0, vy = 2 * d1 * 260, dps = 10, dpsr = 180, turrets = 2 })
  local se = site("ap2", 0, -200, { seen = 2 * d1, vx = 0, vy = 2 * d1 * -260, dps = 10, dpsr = 180, turrets = 2 })
  local s6 = Pc.new()
  local firsts = {}
  for i = 1, 60 do
    local e = Pv.estimate({ evo = 0, kinds = KINDS, gather = GATHER, sites = { site("qg", 0, 0), sw, se }, nests = {}, rivals = {} })
    Pc.update(s6, e, ctx({ mobile = 4 * d1 }), i * 3600)
    firsts[s6.first or "?"] = true
  end
  local nf = 0
  for _ in pairs(firsts) do nf = nf + 1 end
  check(nf == 1, "deux menaces égales opposées, réserve mobile : la même première vague sur 60 relevés (aucun ping-pong)")
  -- Échéances qui se croisent d'un relevé à l'autre (bruit de quelques tuiles) : la première vague ne bascule pas.
  local s6b = Pc.new()
  local fb = {}
  for i = 1, 60 do
    local a1, a2 = (i % 2 == 0) and 30 or 33, (i % 2 == 0) and 33 or 30
    local e = Pv.estimate({ evo = 0, kinds = KINDS, gather = GATHER, rivals = {},
      sites = { site("ap1", 0, 200, { dps = 10, dpsr = 180 }), site("ap2", 0, -200, { dps = 10, dpsr = 180 }) },
      nests = { nest(0, 200 + a1, 50), nest(0, -200 - a2, 50) } })
    Pc.update(s6b, e, ctx({ mobile = 4 * d1 }), i * 3600)
    fb[s6b.first or "?"] = true
  end
  local nfb = 0
  for _ in pairs(fb) do nfb = nfb + 1 end
  check(nfb == 1, "échéances qui se croisent (bruit) : la première vague reste la même (" .. nfb .. ")")
  -- g. Insurmontable avec hystérésis : estimation qui tremble de ±10 % autour de la meilleure défense réunissable.
  local s7 = Pc.new()
  local dmax = d1 -- aucune réserve, aucun fer libre, aucune tourelle au coffre
  local flips = 0
  for i = 1, 60 do
    local f = (i % 2 == 0) and 1.1 or 0.95
    Pc.update(s7, e_w(dmax * f * 1.1, 10), ctx({ soldiers_max = 0, iron = 0 }), i * 3600)
    for _, e in ipairs(s7.events) do if e.kind == "insurmontable" or e.kind == "tenable" then flips = flips + 1 end end
  end
  check(flips <= 1, "insurmontable : ±10 % autour du seuil, une bascule au plus (" .. flips .. ")")
  local s8 = Pc.new()
  Pc.update(s8, e_w(50 * d1, 10), ctx({ soldiers_max = 0, iron = 0 }), 0)
  check(s8.sites.qg.insurm and s8.sites.qg.nohold and #Pc.front_rows(s8, { "qg" }) == 0,
    "vague insurmontable : aucun gel, aucune tourelle envoyée à la mort, repli")
  -- h. Armée : besoin borné, budget en rampe au-dessus de la réserve de production (C1, C2), jamais réduit pendant l'alerte.
  local s9 = Pc.new()
  Pc.update(s9, e_w(100 * d1, 10), ctx({ iron = 2000 }), 0)
  check(s9.alert and s9.army_need > 10 and s9.army_need <= 30, "vague imminente au-dessus des tourelles : alerte, besoin au-delà de l'effectif, sous le plafond (" .. s9.army_need .. ")")
  local s10 = Pc.new()
  Pc.update(s10, e_w(100 * d1, 10), ctx({ iron = 150 }), 0)
  check(s10.alert and s10.army_need == 10, "fer à la réserve de production : AUCUNE recrue payée de plus (besoin = effectif, C1)")
  local s10b = Pc.new()
  Pc.update(s10b, e_w(100 * d1, 10), ctx({ iron = 150, kits_stock = 4 }), 0)
  check(s10b.army_need == 14, "équipements déjà au coffre : payés, hors du budget de fer")
  check(Pc.part(0) == Pc.PART_MAX and Pc.part(Pv.H_COURT) == Pc.PART_MIN and Pc.part(2) > Pc.part(4),
    "budget en rampe selon l'échéance (300 au loin, 700 au contact)")
  check(Pc.affordable(1150, 150, 20, 0) == math.floor(1000 * Pc.PART_MAX / 1000 / 20) and Pc.affordable(100, 150, 20, 0) == 0,
    "recrues payables : fer AU-DESSUS de la réserve seulement")
  local n0 = s9.army_need
  Pc.update(s9, e_w(100 * d1, 10), ctx({ iron = 160 }), 3600)
  check(s9.alert and s9.army_need == n0, "pendant l'alerte, le besoin ne descend pas (on ne licencie pas)")
  -- Relecture de la revue : des soldats MORTS (10 -> 4) ne sont pas remplacés hors budget (fer à la réserve : aucune recrue de plus).
  local s9b = Pc.new()
  Pc.update(s9b, e_w(100 * d1, 10), ctx({ iron = 2000 }), 0)
  local nb0 = s9b.army_need
  Pc.update(s9b, e_w(100 * d1, 10), ctx({ iron = 150, soldiers = 4 }), 3600)
  check(s9b.alert and s9b.army_need == nb0 - 6, "pendant l'alerte, 6 morts et fer à la réserve : le besoin perd les morts (" .. nb0 .. " -> " .. s9b.army_need .. ")")
  Pc.update(s9b, e_w(100 * d1, 10), ctx({ iron = 2000, soldiers = 4 }), 7200)
  check(s9b.alert and s9b.army_need > nb0 - 6, "fer revenu : le remplacement repasse par le budget du moment (" .. s9b.army_need .. ")")
  -- Insurmontable : le même fer libre paie des tourelles OU des recrues, pas les deux.
  local s9c = Pc.new()
  local cx9 = ctx({ iron = 1150, soldiers = 0, kit_iron = 50, turret_iron = 50 })
  Pc.update(s9c, e_w(1, 10), cx9, 0)
  local tv9, sv9 = cx9.turret_value, cx9.soldier_value
  local pay = math.floor((1150 - (cx9.reserve or 0)) / 50)
  local buy = math.min(cx9.soldiers_max, Pc.affordable(1150, cx9.reserve, 50, s9c.sites.qg.eta))
  local dsum = s9c.sites.qg.d + pay * tv9 + buy * sv9
  local dmx = s9c.sites.qg.d + math.max(pay * tv9, buy * sv9)
  local s9d = Pc.new()
  Pc.update(s9d, e_w((dmx + dsum) / 2 / 1.1 * 1.2, 10), cx9, 0)
  check(dsum > dmx and s9d.sites.qg.insurm, "vague entre la défense « fer compté deux fois » et la vraie : insurmontable")
  Pc.update(s9, e_w(0, 10), ctx({ iron = 160 }), 7200)
  check(not s9.alert and s9.army_need == 0, "vague retombée : alerte close (état, pas horloge)")
  local s11 = Pc.new()
  Pc.update(s11, e_w(20 * d1, 10), ctx({ soldiers_max = 0 }), 0)
  check(not s11.alert and s11.army_need == 0 and s11.sites.qg.prep, "votre équipe (pas d'armée) : tourelles d'avance seulement")
  -- i. Rang par échéance : une vague à plus de 5 min ne retient rien ; l'armée visée monte à moyen terme.
  local far = Pv.estimate({ evo = 0, kinds = { { units = { { hp = 375, cost = 4, speed = 0.005, pts = { { 0, 1 } } } } } },
    gather = GATHER, sites = { site("qg", 0, 0, { dps = 10, dpsr = 180 }) }, nests = { nest(200, 0, 50) }, rivals = {} })
  local s12 = Pc.new()
  Pc.update(s12, far, ctx(), 0)
  check(not s12.sites.qg.prep and #Pc.pile_rows(s12, { "qg" }) == 0 and s12.army_soon > 0,
    "vague prévue à plus de 5 min : aucun cadre (R3 libre), armée visée à moyen terme relevée")

  section("8. Raid préventif")
  local re = est({ nests = { nest(100, 0, 50), nest(102, 0, 50) } })
  local ps = Pc.update(Pc.new(), re, ctx(), 0)
  local ok, why = Pc.raid_gate(ps, re, { x = 101, y = 0, r = 24 }, 4, { soldier_value = 480 })
  check(ok, "champ qui nourrit la vague, raid peu coûteux : accepté (" .. tostring(why) .. ")")
  local ok2, why2 = Pc.raid_gate(ps, re, { x = 101, y = 0, r = 24 }, 400, { soldier_value = 480 })
  check(not ok2 and why2:find("engage", 1, true), "raid qui engage plus qu'il n'évite : refusé")
  local ok3 = Pc.raid_gate(ps, re, { x = -500, y = 0, r = 24 }, 4, { soldier_value = 480 })
  check(not ok3, "champ qu'aucune pollution n'atteint : pas de raid")
  local two_f = est({ nests = { nest(100, 0, 50), nest(-100, 0, 5000) } })
  local ok4, why4 = Pc.raid_gate(Pc.update(Pc.new(), two_f, ctx(), 0), two_f, { x = 100, y = 0, r = 24 }, 4,
    { soldier_value = 480, mobile_left = 0 })
  check(not ok4 and why4:find("autre vague", 1, true), "une AUTRE vague imminente tomberait pendant le raid : refusé")

  section("9. Défense induite (C12)")
  check(Pv.hp_per_emit({ mix = { pbar = 4, hbar = 15 }, nests_used = 0, reach = 0 }, GATHER) == 0,
    "aucun nid connu ne nous vise : aucune défense induite (comme le joueur)")
  local hpe = Pv.hp_per_emit(e1, GATHER)
  check(hpe > 0 and math.abs(hpe - e1.reach / 1000 / 4 * GATHER.max * 15) < 1e-9, "PV de vague en plus par pollution/min émise en plus")
  check(Pv.hp_per_emit({ mix = { pbar = 4, hbar = 15 }, nests_used = 2, reach = 0 }, GATHER) > 0,
    "nids connus qui n'absorbent rien encore : part par défaut (l'agrandissement les atteindra)")
  local p1 = Pv.defense_price(hpe, 600, 50, 1100)
  check(p1 > 0 and math.abs(Pv.defense_price(2 * hpe, 600, 50, 1100) - 2 * p1) < 1e-9 and Pv.defense_price(hpe, 0, 50) == 0,
    "prix linéaire en pollution, nul sans valeur de tourelle")

  section("10. Déterminisme et état")
  local a, b = Pc.new(), Pc.new()
  Pc.update(a, three, ctx(), 0)
  Pc.update(b, three, ctx(), 0)
  local same = true
  for _, k in ipairs({ "qg", "ap1", "ap2" }) do
    if a.sites[k].prep ~= b.sites[k].prep or a.sites[k].want ~= b.sites[k].want or a.sites[k].nohold ~= b.sites[k].nohold then same = false end
  end
  check(same and a.first == b.first and a.army_need == b.army_need, "deux passages identiques")
  check(deep_ok(a.sites) and deep_ok(cal), "état des décisions et calibration : nombres, chaînes, tables sans référence partagée")
end

---------------------------------------------------------------------------------------------------
-- Chargement (normal ou muté).
---------------------------------------------------------------------------------------------------
local MODS = { "shared.ai3.prevision", "shared.ai3.prevision_choix" }
local function fresh(mut)
  for _, m in ipairs(MODS) do package.loaded[m] = nil end
  if mut then
    local fh = assert(io.open(mut.file, "rb"))
    local src = fh:read("*a")
    fh:close()
    local i, j = src:find(mut.from, 1, true)
    assert(i, "mutant introuvable : " .. mut.name)
    assert(not src:find(mut.from, j + 1, true), "mutant ambigu : " .. mut.name)
    src = src:sub(1, i - 1) .. mut.to .. src:sub(j + 1)
    package.loaded[mut.mod] = assert(load(src, "@" .. mut.file))()
  end
  return require("shared.ai3.prevision"), require("shared.ai3.prevision_choix")
end

battery(fresh(nil))

section("Anti-échelle : aucun nom d'objet du jeu dans les règles")
do
  local recipes = dofile("tests/fixtures/recipes.lua")
  local names = {}
  for name, r in pairs(recipes) do
    names[name] = true
    for _, p in ipairs(r.products) do names[p.name] = true end
    for _, ing in ipairs(r.ingredients) do names[ing.name] = true end
  end
  for _, file in ipairs({ "shared/ai3/prevision.lua", "shared/ai3/prevision_choix.lua", "shared/ai3/armee.lua", "script/ai3/prevision.lua" }) do
    local fh = assert(io.open(file, "rb"))
    local code = fh:read("*a"):gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
    fh:close()
    local hits = {}
    for s in code:gmatch('"([^"\n]*)"') do if names[s] then hits[#hits + 1] = s end end
    check(#hits == 0, "aucun nom d'objet dans " .. file .. " (" .. table.concat(hits, ", ") .. ")")
  end
end

local base_pass, base_fail = passes, failures
section("11. Mutants")
local PV, PC = "shared/ai3/prevision.lua", "shared/ai3/prevision_choix.lua"
local MUTANTS = {
  { name = "hystérésis retirée (fermeture au seuil d'ouverture)", file = PC, mod = "shared.ai3.prevision_choix",
    from = "elseif was and (o.w5 <= 0 or dtot * 1000 >= o.w5 * Pc.MARGE) then", to = "elseif was and (o.w5 <= 0 or o.w5 * 1000 < Pc.RHO_IN * dtot) then" },
  { name = "une horloge ferme le cadre", file = PC, mod = "shared.ai3.prevision_choix",
    from = "    local was = s.prep\n", to = "    local was = s.prep\n    if tick > 20 * 3600 then s.prep = false was = false end\n" },
  { name = "PREP_MAX retiré", file = PC, mod = "shared.ai3.prevision_choix",
    from = "for i = 1, math.min(#open, Pc.PREP_MAX) do", to = "for i = 1, #open do" },
  { name = "insurmontable sans hystérésis", file = PC, mod = "shared.ai3.prevision_choix",
    from = "elseif wi and o.w5 <= dmax then s.insurm = false end", to = "elseif wi and o.w5 * 1000 < Pc.INSURM_IN * dmax then s.insurm = false end" },
  { name = "insurmontable retiré", file = PC, mod = "shared.ai3.prevision_choix",
    from = "if not wi and o.w5 > 0 and o.w5 * 1000 >= Pc.INSURM_IN * dmax then s.insurm = true", to = "if false then s.insurm = true" },
  { name = "réserve de production ignorée", file = PC, mod = "shared.ai3.prevision_choix",
    from = "local free = (iron or 0) - (reserve or 0)", to = "local free = (iron or 0)" },
  { name = "plafond de soldats retiré", file = PC, mod = "shared.ai3.prevision_choix",
    from = "if need > cap then need = cap end", to = "" },
  { name = "besoin réduit pendant l'alerte (licenciement)", file = PC, mod = "shared.ai3.prevision_choix",
    from = "if keep > need then need = keep end", to = "" },
  { name = "morts remplacés hors budget (besoin gardé malgré les pertes)", file = PC, mod = "shared.ai3.prevision_choix",
    from = "local keep = st.army_need - lost", to = "local keep = st.army_need" },
  { name = "fer libre compté deux fois (tourelles ET recrues)", file = PC, mod = "shared.ai3.prevision_choix",
    from = "math.max(turrets_pay * tv, buy_n * sv)", to = "turrets_pay * tv + buy_n * sv" },
  { name = "première vague sans mémoire (ping-pong au moindre bruit)", file = PC, mod = "shared.ai3.prevision_choix",
    from = "if prev and prev.w5 > 0 and prev.w5 * 1000 > Pc.MARGE * prev.d then first = prev end", to = "" },
  { name = "trou d'exécutant (exec toujours vrai)", file = PC, mod = "shared.ai3.prevision_choix",
    from = "s.exec = (turret_path or recruit_path) and true or false", to = "s.exec = true" },
  { name = "production d'abord ignorée", file = PC, mod = "shared.ai3.prevision_choix",
    from = "and not ctx.production_first and s.exec)", to = "and s.exec)" },
  { name = "porte du raid sans valeur", file = PC, mod = "shared.ai3.prevision_choix",
    from = "if cost > 0 and gain * 1000 < Pc.RAID_RATIO * cost then", to = "if false then" },
  { name = "raid sans regarder les autres vagues", file = PC, mod = "shared.ai3.prevision_choix",
    from = "if w_other * 1000 >= Pc.RHO_IN * (o.d + (ctx.mobile_left or 0)) then", to = "if false then" },
  { name = "pollution lue = reste (nid en bord de nuage ignoré, C5)", file = PV, mod = "shared.ai3.prevision",
    from = "local inflow = nb * (diff or Pv.DIFF0) / 1000 * Pv.CYCLES", to = "local inflow = 0" },
  { name = "pollution sans propriétaire (part ignorée, C6)", file = PV, mod = "shared.ai3.prevision",
    from = "local share = Pv.share(ba, ar)", to = "local share = 1000" },
  { name = "site non pollueur qui attire (C6)", file = PV, mod = "shared.ai3.prevision",
    from = "if not emit or emit <= 0 then return 0 end\n  return emit / math.max(1, dd)", to = "return 1 / math.max(1, dd)" },
  { name = "plafond de groupe retiré", file = PV, mod = "shared.ai3.prevision",
    from = "if units > gsize then units = gsize end", to = "" },
  { name = "échéance optimiste (rassemblement maximal)", file = PV, mod = "shared.ai3.prevision",
    from = "o.eta = gmin + travel", to = "o.eta = gmax + travel" },
  { name = "évolution non projetée", file = PV, mod = "shared.ai3.prevision",
    from = "for _ = 1, H or 0 do x = x + (1000 - x) * (g or 0) end", to = "" },
  { name = "vu ignoré", file = PV, mod = "shared.ai3.prevision",
    from = "o.w5 = math.max(o.wmod5, wvu, fl)", to = "o.w5 = math.max(o.wmod5, fl)" },
  { name = "calibration asymétrique (fausse alerte sans effet)", file = PV, mod = "shared.ai3.prevision",
    from = "c.k = floor(7 * c.k / 8)", to = "c.k = c.k" },
  { name = "raté sans effet", file = PV, mod = "shared.ai3.prevision",
    from = "c.k = c.k + Pv.K_MISS", to = "c.k = c.k" },
  { name = "attaque sans épisode comptée comme raté", file = PV, mod = "shared.ai3.prevision",
    from = "if not c.ep then c.ep = { pred = f.pred_raw or 0, t = tick } end", to = "if not c.ep then c.ep = { pred = 0, t = tick } end" },
  { name = "k non borné", file = PV, mod = "shared.ai3.prevision",
    from = "if c.k < Pv.K_MIN then c.k = Pv.K_MIN elseif c.k > Pv.K_MAX then c.k = Pv.K_MAX end", to = "" },
  { name = "pertes ignorées dans la vague reçue", file = PV, mod = "shared.ai3.prevision",
    from = "local hit_now = (f.contact or 0) > 0 or (f.losses or 0) > 0", to = "local hit_now = (f.contact or 0) > 0" },
  { name = "défense induite sans nid connu (triche)", file = PV, mod = "shared.ai3.prevision",
    from = "if not est or not est.mix or (est.nests_used or 0) == 0 then return 0 end", to = "if not est or not est.mix then return 0 end" },
  { name = "interpolation du moteur fausse (poids du premier point partout)", file = PV, mod = "shared.ai3.prevision",
    from = "return a[2] + (b[2] - a[2]) * (e - a[1]) / (b[1] - a[1])", to = "return a[2]" },
}
local killed = 0
quiet = true
for _, m in ipairs(MUTANTS) do
  local f0 = failures
  local ok, err = pcall(function() battery(fresh(m)) end)
  local dead = (not ok) or failures > f0
  if dead then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. m.name) end
  if not ok and not tostring(err):find("ECHEC") then print("  (mutant « " .. m.name .. " » : erreur " .. tostring(err) .. ")") end
end
quiet = false
fresh(nil)
passes, failures = base_pass, base_fail
check(killed == #MUTANTS, "mutants refusés : " .. killed .. " sur " .. #MUTANTS)
print(string.format("[PREVISION] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
