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
-- Cadence vanilla (spawn_cooldown {360, 150}) : 10 unités/min à l'évolution 0, 24 à l'évolution 1 (mesuré : banc prev-mesure).
local KINDS = { { units = { SMALL, BIG }, rate_max = 10, rate_max1 = 24 } }
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
  check(m3 and m3.hbar > 15 and m3.hbar < 375, "entre les deux : moyenne pondérée")
  check(m0.cap == 10 and math.abs(Pv.mix(KINDS, 1000).cap - 24) < 1e-9 and m3.cap > 10 and m3.cap < 24
    and math.abs(Pv.rate_at(10, 24, 500) - 3600 / ((360 + 150) / 2)) < 1e-9,
    "cadence d'un nid : délai de ponte interpolé selon l'évolution (360 ticks à 0, 150 à 1)")
  check(Pv.mix({}, 0) == nil and Pv.mix({ { units = { { hp = 1, cost = 0, pts = { { 0, 1 } } } } } }, 0) == nil,
    "aucun nid lisible (ou coût nul) : aucune composition, aucune vague modélisée")
  check(Pv.evo_at(0, 0.01, 5) > 0 and Pv.evo_at(0, 0.01, 15) > Pv.evo_at(0, 0.01, 5) and Pv.evo_at(1000, 0.5, 15) == 1000,
    "évolution projetée : croissante avec l'horizon, jamais au-delà de 1000")

  section("2. Pollution qui ARRIVE au nid (C5, corrigé au lot PREVISION-CALIB sur mesure)")
  local NEED = 40 -- 10 unités/min × 4 de pollution : la demande d'un nid à l'évolution 0
  check(Pv.absorbed(100, 0, 20, NEED, 15) == NEED and Pv.absorbed(400, 0, 20, NEED, 15) == NEED,
    "case au-dessus du seuil de diffusion : le nid prend sa DEMANDE, pas plus (mesuré : 40 à 45/min, case à 5 ou à 40)")
  check(Pv.absorbed(10, 0, 20, NEED, 15) == 0,
    "case SOUS le seuil, voisines sous le seuil : le reste lu ne dit pas qu'il en arrive (ancienne règle : 20/min crédités)")
  check(Pv.absorbed(0, 0, 20, NEED, 15) == 0, "case propre, voisines propres : rien n'arrive, le nid ne nous vise pas")
  local edge = Pv.absorbed(0, 16, 20, NEED, 15)
  check(edge > 0 and edge < NEED, "nid en BORD de nuage (voisine au-dessus du seuil) : il absorbe ce qui arrive (" .. edge .. ")")
  check(Pv.absorbed(0, 1000, 20, NEED, 15) == NEED, "flux entrant au-delà de la demande : la demande")
  check(Pv.absorbed(0, 16, 40, NEED, 15) >= Pv.absorbed(0, 16, 20, NEED, 15), "plus de diffusion : au moins autant d'absorption")
  check(Pv.absorbed(5, 0, 20) == 0 and Pv.absorbed(15, 0, 20) == (Pv.ABS + Pv.PROP * 15 / 1000) * 60,
    "sans demande ni seuil donnés : seuil du moteur (15) et plafond du prototype pris par seconde")
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
  check(est({ nests = { nest(100, 0, 500) } }).by.qg.w5 == o1.w5,
    "case saturée : plus de pollution ne grossit pas la vague (le nid tourne à sa cadence, mesuré)")
  check(est({ nests = { nest(100, 0, 5, 16) } }).by.qg.w5 < o1.w5 and est({ nests = { nest(100, 0, 5, 16) } }).by.qg.w5 > 0,
    "nid en bord de nuage : vague plus petite qu'un nid saturé")
  -- Relecture PREVISION-CALIB : la diffusion arrive à la CASE de 32 × 32 ; deux nids d'une même case sous le seuil se partagent
  -- ce qui arrive (sans partage, chaque nid comptait tout le flux des voisines).
  local one_edge = est({ nests = { nest(100, 0, 5, 16) } }).by.qg
  local two_same = est({ nests = { nest(100, 0, 5, 16), nest(110, 5, 5, 16) } }).by.qg
  local two_apart = est({ nests = { nest(100, 0, 5, 16), nest(100, 40, 5, 16) } }).by.qg
  check(one_edge.rate > 0 and math.abs(two_same.rate - one_edge.rate) < 1e-9 and two_apart.rate > 1.9 * one_edge.rate,
    string.format("bord de nuage : deux nids d'une même case se partagent le flux (%.2f = %.2f unités/min), deux cases : le double (%.2f)",
      two_same.rate, one_edge.rate, two_apart.rate))
  check(est({ nests = { nest(100, 0, 50), nest(110, 5, 50) } }).by.qg.rate == 2 * est({ nests = { nest(100, 0, 50) } }).by.qg.rate,
    "case au-dessus du seuil : chaque nid de la case tourne à sa demande (rien à partager)")
  check(math.abs(o1.u5 - 10 * Pv.gather_mean(GATHER)) < 1e-9 and Pv.gather_mean(GATHER) == 5.5,
    "taille : cadence × rassemblement MOYEN (doc : temps tiré entre le minimum et le maximum)")
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

  section("6. Calibration symétrique (C8), k de l'équipe")
  local cal = {}
  local keys = { "qg" }
  Pv.calibrate(cal, keys, { qg = { pred_raw = 1000, window = 20, source = true } }, 0)
  check(Pv.k_of(cal) == Pv.K0 and cal.qg.ep and cal.qg.ep.pred == 1000, "vague prévue : épisode ouvert, k inchangé")
  for t = 1, 5 do Pv.calibrate(cal, keys, { qg = { pred_raw = 1000, window = 20, source = true } }, t * 3600) end
  check(Pv.k_of(cal) == Pv.K0, "aucun fait (ni contact, ni tuée, ni perte, fenêtre pas passée) : k ne bouge pas")
  Pv.calibrate(cal, keys, { qg = { pred_raw = 1000, contact = 2000, window = 20, source = true } }, 6 * 3600)
  local ev = Pv.calibrate(cal, keys, { qg = { pred_raw = 1000, window = 20, source = true } }, 7 * 3600)
  check(#ev == 1 and ev[1].kind == "vague" and ev[1].recv == 2000 and Pv.k_of(cal) > Pv.K0, "vague reçue deux fois plus grosse : k monte")
  local calq = {}
  Pv.calibrate(calq, keys, { qg = { pred_raw = 1000, contact = 250 } }, 0)
  Pv.calibrate(calq, keys, { qg = { pred_raw = 1000 } }, 60)
  check(Pv.k_of(calq) == 500, "k appris en moyenne GÉOMÉTRIQUE : reçu 1/4 du prévu depuis 1 -> 1/2 (" .. Pv.k_of(calq) .. ")")
  local calk = {}
  Pv.calibrate(calk, { "qg", "ap1" }, { qg = { pred_raw = 1000, killed = 800 }, ap1 = {} }, 0)
  local evk = Pv.calibrate(calk, { "qg", "ap1" }, { qg = { pred_raw = 1000 }, ap1 = {} }, 60)
  check(#evk == 1 and evk[1].recv == 800 and evk[1].killed == 800 and evk[1].seen == 0,
    "vague tuée par nos défenses sans être VUE au relevé : comptée par les unités tuées")
  local calm = {}
  Pv.calibrate(calm, keys, { qg = { pred_raw = 1000, contact = 300, killed = 500, losses = 1, hbar = 10 } }, 0)
  Pv.calibrate(calm, keys, { qg = { pred_raw = 1000, killed = 400 } }, 60)
  local evm = Pv.calibrate(calm, keys, { qg = { pred_raw = 1000 } }, 120)
  check(#evm == 1 and evm[1].recv == 900 + Pv.LOSS_UNITS * 10,
    "vague reçue = max(pic vu, tuées sur toute l'attaque) + pertes (sans compter deux fois une unité vue puis tuée)")
  check(Pv.k_of(calk) < Pv.K0 and calk.ap1.ep == nil, "un seul k pour l'équipe (l'écart du modèle est le même à tous ses sites)")
  -- Relecture : reçue CENSURÉE (ni vue ni tuée, pertes seules) = borne basse de la vague.
  local calc = {}
  Pv.calibrate(calc, keys, { qg = { pred_raw = 1000, losses = 1, hbar = 10 } }, 0)
  local evc = Pv.calibrate(calc, keys, { qg = { pred_raw = 1000 } }, 60)
  check(#evc == 1 and evc[1].kind == "vague" and evc[1].censored and Pv.k_of(calc) == Pv.K0,
    "reçue censurée (une perte, rien de vu ni de tué : la vague a survécu) plus petite que la prévue : k ne BAISSE pas")
  local calu = {}
  Pv.calibrate(calu, keys, { qg = { pred_raw = 100, losses = 10, hbar = 100 } }, 0)
  Pv.calibrate(calu, keys, { qg = { pred_raw = 100 } }, 60)
  check(Pv.k_of(calu) > Pv.K0, "reçue censurée déjà plus grosse que la prévue : k MONTE (la borne basse suffit à le dire)")
  local calv = {}
  Pv.calibrate(calv, keys, { qg = { pred_raw = 1000, killed = 100, losses = 1, hbar = 10 } }, 0)
  Pv.calibrate(calv, keys, { qg = { pred_raw = 1000 } }, 60)
  check(Pv.k_of(calv) < Pv.K0, "vague TUÉE par nos défenses (non censurée) plus petite que la prévue : k baisse")
  -- Relecture : unités tuées rattachées aux sites ; la garnison d'un nid connu n'est pas une vague.
  local KS = { { key = "qg", x = 0, y = 0 }, { key = "ch1", x = 190, y = 0 } }
  local KL = { { x = 10, y = 0, hp = 15 }, { x = 170, y = 0, hp = 75 }, { x = 205, y = 3, hp = 375 }, { x = 500, y = 0, hp = 9 } }
  local kb = Pv.kills_by_site(KL, KS, { { x = 210, y = 0 } }, 64, 24)
  local kn = Pv.kills_by_site(KL, KS, {}, 64, 24)
  check(kb.qg == 15 and kb.ch1 == 75 and kn.ch1 == 450,
    "unités tuées : au site le plus proche ; la GARNISON d'un nid connu (raid, nettoyage d'un champ) n'est pas une vague reçue")
  local cal2 = {}
  Pv.calibrate(cal2, keys, { qg = { pred_raw = 1000, window = 20, source = true } }, 0)
  local ev2 = Pv.calibrate(cal2, keys, { qg = { pred_raw = 1000, window = 20, source = true } }, 21 * 3600)
  check(#ev2 == 1 and ev2[1].kind == "fausse" and Pv.k_of(cal2) < Pv.K0 and cal2[Pv.TEAM].fa == 1,
    "fausse alerte (la vague prévue n'est pas venue dans la fenêtre du moteur) : k BAISSE (symétrie)")
  local cal3 = {}
  Pv.calibrate(cal3, keys, { qg = { pred_raw = 0, losses = 2, hbar = 100, source = true } }, 0)
  local ev3 = Pv.calibrate(cal3, keys, { qg = { pred_raw = 0, source = true } }, 3600)
  check(#ev3 == 1 and ev3[1].kind == "rate" and Pv.k_of(cal3) == Pv.K0 and cal3.qg.floor == 2 * Pv.LOSS_UNITS * 100,
    "raté (attaque sans vague prévue, mesurée par nos PERTES) : plancher de menace du site ; k de l'équipe inchangé (la vague est allée ailleurs)")
  Pv.calibrate(cal3, keys, { qg = { pred_raw = 0, source = false } }, 7200)
  check(cal3.qg.floor == nil, "plancher retiré quand plus rien ne nous vise (fait, pas horloge)")
  local cal3b = {}
  Pv.calibrate(cal3b, keys, { qg = { pred_raw = 500, contact = 600, source = true } }, 0)
  local ev3b = Pv.calibrate(cal3b, keys, { qg = { pred_raw = 500, source = true } }, 3600)
  check(#ev3b == 1 and ev3b[1].kind == "vague" and ev3b[1].pred == 500,
    "attaque dans le relevé même où la vague est prévue : comparée à la prévision (pas un raté)")
  local cal4 = { [Pv.TEAM] = { k = Pv.K_MAX, hit = 0, fa = 0 } }
  Pv.calibrate(cal4, keys, { qg = { pred_raw = 1, contact = 1e9 } }, 0)
  Pv.calibrate(cal4, keys, { qg = {} }, 60)
  local cal5 = { [Pv.TEAM] = { k = Pv.K_MIN, hit = 0, fa = 0 } }
  Pv.calibrate(cal5, keys, { qg = { pred_raw = 1e9, window = 1 } }, 0)
  Pv.calibrate(cal5, keys, { qg = {} }, 2 * 3600)
  check(Pv.k_of(cal4) == Pv.K_MAX and Pv.k_of(cal5) == Pv.K_MIN and cal5[Pv.TEAM].fa == 1, "k borné à [K_MIN, K_MAX]")
  local old = { qg = { k = 650, hit = 3, fa = 0, miss = 1 } } -- calibration d'une sauvegarde 0.6.24 (un k par site)
  Pv.calibrate(old, keys, { qg = {} }, 0)
  check(Pv.k_of(old) == Pv.K0 and old.qg.k == 650, "sauvegarde 0.6.24 : l'équipe repart de K0, l'ancien k du site est ignoré (rien d'effacé)")
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
  check(hpe > 0 and math.abs(hpe - e1.reach / 1000 / 4 * Pv.gather_mean(GATHER) * 15) < 1e-9,
    "PV de vague en plus par pollution/min émise en plus (rassemblement moyen)")
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

---------------------------------------------------------------------------------------------------
-- 12. Rejeu des vagues MESURÉES en moteur réel (lot PREVISION-CALIB)
---------------------------------------------------------------------------------------------------
-- Partie réelle verif-guide, 216 000 ticks, version 0.6.24, graines 271828182 (1) et 1618033988 (2) ; archives
-- fo-logs/2026-10-30_MATIN/verif-guide-0624/<graine>/benchmark.log.gz, lignes [FO-PREVISION] dans l'ordre du journal.
-- { graine, équipe, minute, genre (v : BILAN vague, r : RATE, f : FAUSSE ALERTE), site, prévue (PV, avant k), reçue (PV) }.
-- La prévue 0.6.24 est la vague au rassemblement MAXIMAL (10 min) : u = prévue ÷ PV moyens (2708 ÷ 200 = 13,54 PV à
-- l'évolution 0) ; u = 200 = plafond du groupe. Ces vagues plafonnées (azure, graine 1, QG) ont un débit lu à l'ÉTAT du
-- journal : 157 pollution/min reçue par 8 nids, tous rattachés au QG, ÷ 4 de pollution par unité = 39,25 unités/min.
section("12. Rejeu des vagues mesurées (verif-guide 0.6.24, 2 graines)")
do
  local Pv = require("shared.ai3.prevision")
  local H = 2708 / 200
  local RATE_AZURE1 = 157 / 4
  local G = { min = 1, max = 10, size = 200 } -- réglages de carte par défaut du moteur
  local E = {
    { 1, "azure", 24, "v", "qg", 2708, 255 }, { 1, "azure", 32, "r", "ap1", 0, 406 }, { 1, "azure", 32, "r", "ap2", 0, 550 },
    { 1, "azure", 32, "v", "qg", 2708, 605 }, { 1, "azure", 39, "v", "qg", 2708, 1046 }, { 1, "azure", 42, "r", "ap3", 0, 41 },
    { 1, "azure", 48, "r", "ap3", 0, 45 }, { 1, "azure", 49, "v", "qg", 2708, 41 }, { 1, "azure", 54, "v", "qg", 2708, 1545 },
    { 1, "azure", 55, "r", "ap1", 0, 41 }, { 1, "azure", 55, "r", "ap2", 0, 41 },
    { 1, "player", 47, "r", "ap2", 0, 41 }, { 1, "player", 47, "r", "ap3", 0, 284 }, { 1, "player", 51, "r", "ap2", 0, 81 },
    { 1, "player", 52, "r", "qg", 0, 81 }, { 1, "player", 53, "r", "ap2", 0, 163 }, { 1, "player", 53, "r", "ap3", 0, 81 },
    { 1, "player", 55, "v", "ap4", 1194, 156 },
    { 1, "scarlet", 49, "f", "qg", 2081, 0 },
    { 2, "player", 13, "r", "ap1", 0, 81 }, { 2, "player", 13, "v", "ap2", 605, 163 }, { 2, "player", 24, "v", "ap2", 614, 1909 },
    { 2, "player", 25, "v", "qg", 1569, 894 }, { 2, "player", 45, "r", "ap8", 0, 203 }, { 2, "player", 46, "f", "qg", 1562, 0 },
    { 2, "player", 52, "f", "ap7", 2170, 0 }, { 2, "player", 53, "r", "ap10", 0, 75 }, { 2, "player", 53, "v", "ap5", 519, 187 },
    { 2, "player", 56, "r", "ap10", 0, 60 },
    { 2, "azure", 19, "v", "ap1", 2350, 150 }, { 2, "azure", 27, "v", "qg", 2287, 41 }, { 2, "azure", 36, "v", "ap1", 2385, 203 },
    { 2, "azure", 36, "r", "ap2", 0, 15 }, { 2, "azure", 44, "r", "ap2", 0, 813 }, { 2, "azure", 44, "v", "qg", 1263, 41 },
    { 2, "azure", 50, "r", "ap2", 0, 802 }, { 2, "azure", 50, "v", "qg", 2428, 180 }, { 2, "azure", 57, "f", "ap1", 1157, 0 },
    { 2, "scarlet", 33, "r", "ap5", 0, 163 }, { 2, "scarlet", 38, "v", "ap2", 906, 122 }, { 2, "scarlet", 39, "r", "ap1", 0, 41 },
    { 2, "scarlet", 39, "r", "chiron", 0, 1097 }, { 2, "scarlet", 39, "r", "qg", 0, 122 }, { 2, "scarlet", 41, "r", "chiron", 0, 140 },
    { 2, "scarlet", 47, "v", "ap2", 906, 81 }, { 2, "scarlet", 56, "v", "ap2", 906, 41 },
  }
  --- Prévision corrigée d'une vague 0.6.24 : même débit, rassemblement moyen (seule part du modèle corrigé qui se recalcule
  --- avec le journal 0.6.24 ; la règle d'apport C5 demande la pollution de chaque case de nid, que ce journal n'écrit pas).
  local function corrected(seed, team, site, pred)
    local u = pred / H
    local rate
    if u >= 199.5 then
      assert(seed == 1 and team == "azure" and site == "qg", "vague plafonnée sans débit au journal")
      rate = RATE_AZURE1
    else
      rate = u / 10
    end
    return Pv.wave_units(rate, G) * H
  end
  --- Reçue faite de pertes seulement (aucune unité vue au contact) : n × 3 × PV moyens (déduit du journal : la règle 0.6.24).
  local function losses_only(r)
    local n = r / (Pv.LOSS_UNITS * H)
    return n >= 0.97 and math.abs(n - math.floor(n + 0.5)) < 0.03
  end
  local function replay(law)
    local cals, out, tick = {}, {}, 0
    for i, ev in ipairs(E) do
      local seed, team, minute, kind, site, pred, recv = ev[1], ev[2], ev[3], ev[4], ev[5], ev[6], ev[7]
      local id = seed .. ":" .. team
      cals[id] = cals[id] or {}
      local cal = cals[id]
      tick = minute * 3600 + i * 10
      local keys = { site }
      if kind == "v" then
        local p = law == "ancien" and pred or corrected(seed, team, site, pred)
        local k = law == "ancien" and 1000 or Pv.k_of(cal)
        out[#out + 1] = { ratio = k / 1000 * p / recv, raw = p / recv, seen = not losses_only(recv), id = id, k = k }
        -- Reçue faite de pertes seules : rejouée comme des PERTES (ce que le runtime voit : rien de vu, rien de tué), pas comme
        -- des unités vues (relecture : la loi ancienne ne distinguait pas, la nouvelle traite ces reçues en bornes basses).
        local fact = { pred_raw = p, contact = recv, source = true }
        if law ~= "ancien" and losses_only(recv) then
          fact = { pred_raw = p, losses = math.floor(recv / (Pv.LOSS_UNITS * H) + 0.5), hbar = H, source = true }
        end
        Pv.calibrate(cal, keys, { [site] = fact }, tick)
        Pv.calibrate(cal, keys, { [site] = { pred_raw = p, source = true } }, tick + 1)
      elseif kind == "r" then
        Pv.calibrate(cal, keys, { [site] = { pred_raw = 0, contact = recv, source = true } }, tick)
        Pv.calibrate(cal, keys, { [site] = { pred_raw = 0, source = true } }, tick + 1)
      else
        Pv.calibrate(cal, keys, { [site] = { pred_raw = pred, window = 0.001, source = true } }, tick)
        Pv.calibrate(cal, keys, { [site] = { source = true } }, tick + 5)
      end
    end
    return out
  end
  local function median(list)
    local t = {}
    for _, v in ipairs(list) do t[#t + 1] = v end
    table.sort(t)
    local n = #t
    if n == 0 then return 0 end
    if n % 2 == 1 then return t[(n + 1) / 2] end
    return (t[n / 2] + t[n / 2 + 1]) / 2
  end
  local before, after = replay("ancien"), replay("nouveau")
  local rb, ra, ras, rfirst, rcal = {}, {}, {}, {}, {}
  local seen_ids = {}
  for i, w in ipairs(after) do
    rb[#rb + 1] = before[i].raw
    ra[#ra + 1] = w.ratio
    if w.seen then ras[#ras + 1] = w.ratio end
    if not seen_ids[w.id] then seen_ids[w.id] = true; rfirst[#rfirst + 1] = w.ratio else rcal[#rcal + 1] = w.ratio end
  end
  local mb, ma, mas, mf, mc = median(rb), median(ra), median(ras), median(rfirst), median(rcal)
  local parts = {}
  for _, v in ipairs(ra) do parts[#parts + 1] = string.format("%.2f", v) end
  print(string.format("  rejeu : %d vagues ; ratio prévue/reçue médian 0.6.24 %.2f -> corrigé %.2f ; vagues VUES au contact (%d) %.2f ; "
    .. "premières vagues de chaque équipe (k = 1, modèle seul) %.2f, suivantes (k appris) %.2f", #ra, mb, ma, #ras, mas, mf, mc))
  print("  ratios corrigés dans l'ordre du journal : " .. table.concat(parts, " "))
  check(#ra == 18 and #rb == 18, "18 BILAN vague rejoués (6 sur la graine 1, 12 sur la graine 2)")
  check(mb > 8 and mb < 10, string.format("rejeu de la 0.6.24 fidèle au journal : ratio médian %.2f (journal : prévue 3 à 60 fois la reçue)", mb))
  check(ma < mb, string.format("modèle et calibration corrigés : ratio médian plus bas que la 0.6.24 (%.2f -> %.2f)", mb, ma))
  -- Relecture : sûreté de la calibration. Les reçues 0.6.24 sont TOUTES des bornes basses (aucune unité tuée comptée) ; une
  -- calibration qui les prend pour des mesures fait baisser k puis sous-estime la vague suivante (loi du commit 6045924a :
  -- vagues 5 et 8 sous-estimées 8 fois). Aucune vague prévue avec un k APPRIS (< K0) ne doit être sous-estimée de plus de 4 fois.
  local worst = nil
  for _, w in ipairs(after) do
    if w.k < Pv.K0 and (not worst or w.ratio < worst) then worst = w.ratio end
  end
  check(not worst or worst >= 0.25, string.format("calibration sur bornes basses : aucune vague sous-estimée de plus de 4 fois par un k appris (pire %.2f)", worst or 1))
  -- Écart écrit, PAS caché : les médianes ne se jugent PAS sur ce journal (reçues = bornes basses : le ratio prévue/reçue y est
  -- trop haut par construction). Le critère « médiane entre 0,5 et 2 » attend un banc long avec les unités tuées comptées.
  print(string.format("  (hors bilan, reçues 0.6.24 = bornes basses) médianes : 18 vagues %.2f, vues %.2f, k appris %.2f ; critère 0,5 à 2 : à juger sur le prochain banc long",
    ma, mas, mc))
end

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
    from = "if units > size then units = size end", to = "" },
  { name = "échéance optimiste (rassemblement maximal)", file = PV, mod = "shared.ai3.prevision",
    from = "o.eta = gmin + travel", to = "o.eta = (ga.max or 10) + travel" },
  { name = "évolution non projetée", file = PV, mod = "shared.ai3.prevision",
    from = "for _ = 1, H or 0 do x = x + (1000 - x) * (g or 0) end", to = "" },
  { name = "vu ignoré", file = PV, mod = "shared.ai3.prevision",
    from = "o.w5 = math.max(o.wmod5, wvu, fl)", to = "o.w5 = math.max(o.wmod5, fl)" },
  { name = "calibration asymétrique (fausse alerte sans effet)", file = PV, mod = "shared.ai3.prevision",
    from = "team.k = bound_k(floor(7 * team.k / 8))", to = "team.k = team.k" },
  { name = "raté sans plancher", file = PV, mod = "shared.ai3.prevision",
    from = "c.floor = recv", to = "c.floor = nil" },
  { name = "ancienne règle C5 (case touchée : plafond)", file = PV, mod = "shared.ai3.prevision",
    from = "if c >= (sat or Pv.SAT0) then return cap end", to = "if c > 0 then return cap end" },
  { name = "rassemblement maximal (au lieu du moyen)", file = PV, mod = "shared.ai3.prevision",
    from = "return ((g.min or 1) + (g.max or 10)) / 2", to = "return g.max or 10" },
  { name = "unités tuées ignorées", file = PV, mod = "shared.ai3.prevision",
    from = "c.kill = (c.kill or 0) + (f.killed or 0)", to = "c.kill = c.kill or 0" },
  { name = "moyenne linéaire de k (au lieu de géométrique)", file = PV, mod = "shared.ai3.prevision",
    from = "team.k = bound_k(floor(math.sqrt(team.k * r)))", to = "team.k = bound_k(floor((7 * team.k + r) / 8))" },
  { name = "cadence non interpolée selon l'évolution", file = PV, mod = "shared.ai3.prevision",
    from = "return 3600 / (cd0 + (cd1 - cd0) * x)", to = "return r0" },
  { name = "demande du nid ignorée (plafond du prototype seul)", file = PV, mod = "shared.ai3.prevision",
    from = "if need and need < cap then cap = need end", to = "" },
  { name = "attaque sans épisode comptée comme raté", file = PV, mod = "shared.ai3.prevision",
    from = "if not c.ep then c.ep = { pred = f.pred_raw or 0, t = tick } end", to = "if not c.ep then c.ep = { pred = 0, t = tick } end" },
  { name = "k non borné", file = PV, mod = "shared.ai3.prevision",
    from = "if k < Pv.K_MIN then return Pv.K_MIN end\n  if k > Pv.K_MAX then return Pv.K_MAX end", to = "" },
  { name = "pertes ignorées dans la vague reçue", file = PV, mod = "shared.ai3.prevision",
    from = "local hit_now = (f.contact or 0) > 0 or (f.losses or 0) > 0 or (f.killed or 0) > 0", to = "local hit_now = (f.contact or 0) > 0 or (f.killed or 0) > 0" },
  { name = "défense induite sans nid connu (triche)", file = PV, mod = "shared.ai3.prevision",
    from = "if not est or not est.mix or (est.nests_used or 0) == 0 then return 0 end", to = "if not est or not est.mix then return 0 end" },
  { name = "flux de la case compté une fois par nid (relecture)", file = PV, mod = "shared.ai3.prevision",
    from = "(n.nb or 0) / (per_chunk[Pv.chunk_key(n.x, n.y)] or 1)", to = "n.nb" },
  { name = "reçue censurée qui baisse k (relecture)", file = PV, mod = "shared.ai3.prevision",
    from = "local censored = seen <= 0 and killed <= 0", to = "local censored = false" },
  { name = "garnison tuée comptée comme vague (relecture)", file = PV, mod = "shared.ai3.prevision",
    from = "if d2(h.x, h.y, n.x, n.y) <= g2 then gar = true break end", to = "" },
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
