-- Lot THERMIQUE : règle pure shared/team/thermique.lua (gisement couvert, balayage des paires thermiques, protection, ordre, créneaux).
-- Usage (depuis la racine du mod) : lua5.2 tests/thermique_test.lua
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local SRC_PATH = "shared/team/thermique.lua"

local function load_module(src)
  local chunk, err = load(src, "=thermique", "t")
  assert(chunk, err)
  return chunk()
end

local function read(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end

local SRC = read(SRC_PATH)

-- Gisement : th = cadence thermique 0,25 ore/s, el = cadence électrique 0,5 ore/s (données du jeu vanilla, passées ici en nombres)
local function fl(id, res, pairs_n, working, extra)
  local t = { id = id, res = res, pairs = pairs_n, th_rate = 0.25, working = working, el_rate = 0.5, have = 0 }
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end

-- La batterie : rend le nombre d'échecs sur le module `Th`
local function suite(Th, verbose)
  local before = failures
  local say = verbose and print or function() end
  local C = Th.CFG

  -- 1. supply / covered
  do
    local th, el = Th.supply(fl(1, "fer", 10, 4))
    check(math.abs(th - 2.5) < 1e-9 and math.abs(el - 2.0) < 1e-9, "1 : supply = paires × cadence thermique, en marche × cadence électrique")
    local ok, why = Th.covered(fl(1, "fer", 10, 4))
    check(ok == false and why == "extraction-electrique-insuffisante", "1 : 10 thermiques (2,5/s) contre 4 électriques (2,0/s) : pas couvert (" .. tostring(why) .. ")")
    ok = Th.covered(fl(1, "fer", 10, 5))
    check(ok == true, "1 : 5 électriques (2,5/s) égalent 10 thermiques (2,5/s) : couvert (cover_ratio 1)")
    ok, why = Th.covered(fl(1, "fer", 0, 1))
    check(ok == false and why == "bande-qui-ne-produit-pas", "1 : une seule foreuse en marche ne fait pas une bande productive")
    ok = Th.covered(fl(1, "fer", 3, 2))
    check(ok == true, "1 : 2 électriques (1,0/s) couvrent 3 thermiques (0,75/s)")
    ok = Th.covered(fl(1, "fer", 3, 0))
    check(ok == false, "1 : aucune foreuse en marche : pas couvert, même sans paire")
    local cfg2 = { cover_ratio = 2.0, min_working = 2 }
    for k, v in pairs(C) do if cfg2[k] == nil then cfg2[k] = v end end
    ok = Th.covered(fl(1, "fer", 4, 3), cfg2)
    check(ok == false, "1 : le seuil se lit du réglage (cover_ratio 2 : 3 électriques ne couvrent pas 4 thermiques)")
    ok = Th.covered(fl(1, "fer", 4, 8), cfg2)
    check(ok == true, "1 : cover_ratio 2 : 8 électriques couvrent 4 thermiques")
  end

  -- 2. protection
  do
    local fields = { fl(1, "charbon", 8, 6), fl(2, "charbon", 6, 0) }
    -- plancher 1,0 ore/s ; la coupe des 8 paires du gisement 1 (2,0/s) laisse 3,0 (électrique) + 1,5 (gisement 2) = 4,5
    local ctx = { floor = { charbon = 1.0 }, stock = { charbon = 0 }, critical = { charbon = true } }
    local ok, why = Th.cut_ok(fields[1], fields, 2.0, ctx)
    check(ok and why == "plancher-tenu", "2 : reste 4,5/s >= plancher 1,0 : la coupe passe (" .. tostring(why) .. ")")
    ctx.floor.charbon = 5.0
    ok, why = Th.cut_ok(fields[1], fields, 2.0, ctx)
    check(not ok and why == "source-critique", "2 : charbon critique sous le plancher : refus, le stock ne ponte pas (" .. tostring(why) .. ")")
    ctx.stock.charbon = 1e9
    ok, why = Th.cut_ok(fields[1], fields, 2.0, ctx)
    check(not ok and why == "source-critique", "2 : même avec un stock énorme, un minerai critique ne se coupe pas sous son plancher")
    ctx.critical.charbon = nil
    ok, why = Th.cut_ok(fields[1], fields, 2.0, ctx)
    check(ok and why == "stock-ponte", "2 : minerai ordinaire sous le plancher et stock énorme : pont par le stock (" .. tostring(why) .. ")")
    ctx.stock.charbon = 10
    ok, why = Th.cut_ok(fields[1], fields, 2.0, ctx)
    check(not ok and why == "plancher", "2 : stock trop petit pour ponter le manque : refus (" .. tostring(why) .. ")")
    -- dernière source : un seul gisement, tout thermique, la coupe supprime tout
    local solo = { fl(1, "fer", 4, 0) }
    ok, why = Th.cut_ok(solo[1], solo, 1.0, { floor = {}, stock = { fer = 0 } })
    check(not ok and why == "derniere-source", "2 : la coupe de la dernière source est refusée même sans plancher (" .. tostring(why) .. ")")
    ok, why = Th.cut_ok(solo[1], solo, 1.0, { floor = {}, stock = { fer = 1.0 * C.horizon } })
    check(ok and why == "stock-ponte", "2 : la dernière source ne se coupe que si le stock couvre l'horizon")
    ok, why = Th.cut_ok(solo[1], solo, 1.0, { floor = {}, stock = { fer = 1.0 * C.horizon - 1 } })
    check(not ok, "2 : un objet de moins que l'horizon : refus")
    local solo_crit = Th.cut_ok(solo[1], solo, 1.0, { floor = {}, stock = { fer = 1e9 }, critical = { fer = true } })
    check(solo_crit == false, "2 : la dernière source d'un minerai critique ne se coupe jamais")
    -- un autre minerai n'entre pas dans l'approvisionnement
    local mix = { fl(1, "fer", 4, 0), fl(2, "cuivre", 20, 10) }
    ok = Th.cut_ok(mix[1], mix, 1.0, { floor = {}, stock = {} })
    check(ok == false, "2 : l'approvisionnement du cuivre ne protège pas le fer")
    -- plancher dans les données
    -- gisement 1 : 1,0 thermique + 3,0 électrique ; gisement 2 : 1,0 thermique ; couper ce dernier laisse 4,0
    local f2 = { fl(1, "fer", 4, 6), fl(2, "fer", 4, 0) }
    ok = Th.cut_ok(f2[2], f2, 1.0, { floor = { fer = 4.0 }, stock = {} })
    check(ok == true, "2 : reste 4,0 contre un plancher de 4,0 : la coupe passe")
    ok = Th.cut_ok(f2[2], f2, 1.0, { floor = { fer = 4.5 }, stock = {} })
    check(ok == false, "2 : reste 4,0 contre un plancher de 4,5 : refus (le plancher se lit du contexte)")
  end

  -- 3. balayage
  do
    local ctx = { floor = {}, stock = {}, critical = {} }
    local fields = {
      fl(1, "fer", 3, 6),                                 -- couvert, 3 paires : balayé
      fl(2, "fer", 10, 4),                                -- pas couvert
      fl(3, "cuivre", 5, 12),                             -- couvert, 5 paires
      fl(4, "cuivre", 2, 8, { busy = true }),             -- couvert mais une bande en chantier
      fl(5, "pierre", 0, 6),                              -- couvert, aucune paire : rien à retirer
      fl(6, "fer", 4, 1),                                 -- une seule foreuse en marche
    }
    local act, refused = Th.sweep(fields, ctx)
    check(#act == 1 and act[1].id == 3 and act[1].pairs == 5, "3 : le gisement couvert le plus productif est balayé d'abord (id " .. tostring(act[1] and act[1].id) .. ")")
    local why = {}
    for _, r in ipairs(refused) do why[r.id] = r.why end
    check(why[2] == "extraction-electrique-insuffisante", "3 : gisement non couvert : refus motivé (" .. tostring(why[2]) .. ")")
    check(why[4] == "chantier-en-cours", "3 : une bande en chantier sur le gisement retient le balayage (" .. tostring(why[4]) .. ")")
    check(why[1] == "file", "3 : au plus sweep_max gisements par pensée, le suivant attend (" .. tostring(why[1]) .. ")")
    check(why[5] == nil, "3 : un gisement sans paire n'est ni balayé ni refusé")
    check(why[6] == "bande-qui-ne-produit-pas", "3 : une bande qui ne produit pas ne couvre rien (" .. tostring(why[6]) .. ")")
    -- deux pensées de suite : le second part
    local fields2 = { fields[1], fields[2] }
    local act2 = Th.sweep(fields2, ctx)
    check(#act2 == 1 and act2[1].id == 1, "3 : le gisement couvert unique est balayé")
    local cfg3 = { sweep_max = 5, cover_ratio = 1.0, min_working = 2, horizon = C.horizon }
    local act3 = Th.sweep(fields, ctx, cfg3)
    check(#act3 == 2 and act3[1].id == 3 and act3[2].id == 1, "3 : sweep_max 5 : deux gisements, du plus productif au moins productif")
    -- déterminisme : l'ordre d'entrée ne change rien
    local rev = {}
    for i = #fields, 1, -1 do rev[#rev + 1] = fields[i] end
    local act4 = Th.sweep(rev, ctx, cfg3)
    check(#act4 == 2 and act4[1].id == act3[1].id and act4[2].id == act3[2].id, "3 : l'ordre des gisements en entrée ne change pas la décision")
    -- protection : le charbon critique garde ses paires tant que le plancher n'est pas tenu
    local coal = { fl(1, "charbon", 4, 2) } -- 2 électriques (1,0) pour 4 thermiques (1,0) : couvert, la coupe laisse 1,0
    local a1, r1 = Th.sweep(coal, { floor = { charbon = 1.5 }, stock = { charbon = 1e9 }, critical = { charbon = true } })
    check(#a1 == 0 and r1[1] and r1[1].why == "source-critique", "3 : charbon couvert mais sous le plancher de la centrale : paires gardées (" .. tostring(r1[1] and r1[1].why) .. ")")
    local a2 = Th.sweep(coal, { floor = { charbon = 0.8 }, stock = {}, critical = { charbon = true } })
    check(#a2 == 1, "3 : plancher tenu par l'électrique : les paires partent")
  end

  -- 4. financement, ordre, créneaux
  do
    local g = fl(1, "fer", 10, 0) -- 2,5 ore/s : 5 électriques
    local ok, why = Th.financed(g, { power = false, iron = 1e6, drill_cost = 30 })
    check(not ok and why == "courant", "4 : pas de courant : pas de bande (" .. tostring(why) .. ")")
    ok, why = Th.financed(g, { power = true, iron = 149, drill_cost = 30 })
    check(not ok and why == "fer", "4 : 149 fer pour 5 foreuses à 30 : pas financé (" .. tostring(why) .. ")")
    ok = Th.financed(g, { power = true, iron = 150, drill_cost = 30 })
    check(ok == true, "4 : 150 fer pour 5 foreuses à 30 : financé")
    ok = Th.financed(fl(1, "fer", 11, 0), { power = true, iron = 150, drill_cost = 30 })
    check(ok == false, "4 : 11 paires (2,75/s) demandent 6 foreuses : 180 fer")
    ok = Th.financed(fl(1, "fer", 0, 0), { power = true, iron = 0, drill_cost = 30 })
    check(ok == true, "4 : aucune paire à remplacer : rien à financer")

    local cands = {
      fl(1, "fer", 4, 0, { have = 500 }),
      fl(2, "fer", 40, 0, { have = 500 }),
      fl(3, "cuivre", 12, 0, { have = 40 }),
      fl(4, "cuivre", 12, 0, { have = 900 }),
      fl(5, "pierre", 2, 0, { wanted = true }),
    }
    local ord = Th.order(cands)
    local ids = {}
    for _, g2 in ipairs(ord) do ids[#ids + 1] = g2.id end
    check(table.concat(ids, ",") == "5,2,3,4,1", "4 : voulu d'abord, puis le plus productif, puis le stock le plus bas, puis le numéro (" .. table.concat(ids, ",") .. ")")
    local tiers = Th.order({ fl(1, "charbon", 40, 0, { tier = 1 }), fl(2, "fer", 4, 0), fl(3, "cuivre", 2, 0), fl(4, "pierre", 1, 0, { tier = 1, wanted = true }) })
    ids = {}
    for _, g2 in ipairs(tiers) do ids[#ids + 1] = g2.id end
    check(table.concat(ids, ",") == "4,2,3,1", "4 : les plaques avant le charbon et la pierre, même moins productives ; un voulu passe devant (" .. table.concat(ids, ",") .. ")")
    check(cands[1].id == 1 and cands[5].id == 5, "4 : order rend une nouvelle liste, l'entrée n'est pas triée en place")
    local ord2 = Th.order({ fl(9, "fer", 4, 0), fl(3, "fer", 4, 0) })
    check(ord2[1].id == 3, "4 : à égalité complète, le numéro le plus petit")

    local busy = { total = 0 }
    local s, w = Th.free_slot("fer", busy)
    check(s and w == "libre", "4 : aucun chantier : créneau libre")
    busy = { total = 1, fer = 1 }
    s, w = Th.free_slot("fer", busy)
    check(not s and w == "minerai-occupe", "4 : un chantier de fer : pas un deuxième (" .. tostring(w) .. ")")
    s = Th.free_slot("cuivre", busy)
    check(s == true, "4 : un autre minerai prend un autre créneau")
    -- 9/11 : la plaque clé (busy.key) a un 2e chantier quand TOUS les siens sont bloqués par leurs matières ; jamais les autres minerais
    busy = { total = 1, fer = 1, key = "fer", stuck = { fer = 1 } }
    s, w = Th.free_slot("fer", busy)
    check(s and w == "libre-cle", "4 : fer clé, chantier bloqué par ses matières : un 2e chantier (" .. tostring(w) .. ")")
    busy = { total = 1, fer = 1, key = "fer", stuck = {} }
    s, w = Th.free_slot("fer", busy)
    check(not s and w == "minerai-occupe", "4 : fer clé, chantier qui avance : pas de 2e")
    busy = { total = 2, fer = 2, key = "fer", stuck = { fer = 2 } }
    s, w = Th.free_slot("fer", busy)
    check(not s and w == "creneaux", "4 : tous les créneaux pris : pas de 3e")
    busy = { total = 1, cuivre = 1, key = "fer", stuck = { cuivre = 1 } }
    s, w = Th.free_slot("cuivre", busy)
    check(not s and w == "minerai-occupe", "4 : un minerai qui n'est pas la plaque clé n'a jamais de 2e chantier")
    busy = { total = 1, fer = 1, stuck = { fer = 1 } }
    s, w = Th.free_slot("fer", busy)
    check(not s and w == "minerai-occupe", "4 : sans plaque clé déclarée : comme avant")
    busy = { total = 1, fer = 1, key = "fer", stuck = { fer = 0 } }
    check(not (Th.free_slot("fer", busy)), "4 : bloqués 0 sur 1 : pas de 2e")
    busy = { total = 2, fer = 2, key = "fer", stuck = { fer = 2 } }
    local C2 = {}
    for k, v in pairs(C) do C2[k] = v end
    C2.slots = 3
    s, w = Th.free_slot("fer", busy, C2)
    check(not s and w == "minerai-occupe", "4 : plafond de 2 chantiers de la plaque clé (key_per_mineral)")
    check(Th.band_stuck("reserve", "materiaux", C.stuck_wait + 1) == true and Th.band_stuck("reserve", "materiaux", C.stuck_wait) == false
      and Th.band_stuck("reserve", "degel", C.stuck_wait * 3) == false and Th.band_stuck("chantier", nil, C.stuck_wait * 3) == false
      and Th.band_stuck("reserve", "pile", C.stuck_wait + 1) == true and Th.band_stuck("reserve", "materiaux", nil) == false,
      "4 : bande bloquée = en réserve (hors porte « degel ») depuis plus de stuck_wait")
    busy = { total = C.slots, fer = 1, cuivre = 1, charbon = 1 }
    s, w = Th.free_slot("pierre", busy)
    check(not s and w == "creneaux", "4 : tous les créneaux pris : attendre (" .. tostring(w) .. ")")
    -- IA-SPAWN (B2, partie du DC 0.6.96, 11/11, graine 2507543475) : de 30 à 114 min, les 2 créneaux tenus par le charbon (p21 puis p46) et le
    -- cuivre (p22, 76 min en « reserve:materiaux ») ; le champ du fer du spawn (plaque clé en manque, couvert à 177 pour mille) restait « en
    -- veille », jamais servi : la plaque clé sans chantier à elle a sa voie même quand les autres minerais tiennent tous les créneaux
    busy = { total = C.slots, charbon = 1, cuivre = 1, key = "fer", stuck = {} }
    s, w = Th.free_slot("fer", busy)
    check(s and w == "voie-cle", "4 : plaque clé sans chantier, créneaux tenus par le charbon et le cuivre : sa voie (" .. tostring(w) .. ")")
    s, w = Th.free_slot("charbon", busy)
    check(not s and w == "creneaux", "4 : voie de la plaque clé : un autre minerai attend toujours un créneau (" .. tostring(w) .. ")")
    busy = { total = C.slots, fer = 1, charbon = 1, key = "fer", stuck = { fer = 1 } }
    s, w = Th.free_slot("fer", busy)
    check(not s and w == "creneaux", "4 : plaque clé qui a déjà un chantier : pas de voie de plus au-delà des créneaux (" .. tostring(w) .. ")")
    busy = { total = C.slots, charbon = 1, cuivre = 1, stuck = {} }
    s, w = Th.free_slot("fer", busy)
    check(not s and w == "creneaux", "4 : sans plaque clé déclarée : pas de voie (" .. tostring(w) .. ")")
  end

  -- 4 bis. verdict au retrait
  do
    check(Th.verdict(true, true, 0) == "retirer", "4b : coupe permise : retirer")
    check(Th.verdict(false, false, 0) == "attendre", "4b : coupe refusée, minerai ordinaire : attendre")
    check(Th.verdict(false, false, C.protect_wait) == "attendre", "4b : à la limite exacte, on attend encore")
    check(Th.verdict(false, false, C.protect_wait + 1) == "retirer", "4b : le pont de stock n'attend pas plus que protect_wait (jamais un blocage définitif)")
    check(Th.verdict(false, true, 0) == "attendre", "4b : minerai critique : attendre")
    check(Th.verdict(false, true, C.protect_wait + 1) == "attendre", "4b : un minerai critique ne passe jamais au bout de protect_wait")
    check(Th.verdict(false, true, C.critical_wait + 1) == "annuler", "4b : minerai critique : la demande est annulée après critical_wait")
  end

  -- 5. parts par minerai (critères T1 et T2)
  do
    local fields = {
      fl(1, "fer", 10, 4), fl(2, "fer", 2, 6),
      fl(3, "cuivre", 0, 8),
      fl(4, "charbon", 20, 0),
    }
    local rows = Th.shares(fields, { "fer", "cuivre", "charbon", "pierre" })
    check(#rows == 4 and rows[1].res == "fer" and rows[4].res == "pierre", "5 : un rang par minerai demandé, dans l'ordre demandé")
    local fer = rows[1]
    check(math.abs(fer.th - 3.0) < 1e-9 and math.abs(fer.el - 5.0) < 1e-9 and math.abs(fer.share - 5.0 / 8.0) < 1e-9, "5 : fer : thermique 3,0, électrique 5,0, part 62,5 %")
    check(fer.pairs == 12 and fer.working == 10, "5 : fer : paires et foreuses en marche cumulées")
    check(fer.covered_with_pairs == 1, "5 : fer : un gisement couvert garde des paires (le 2)")
    check(rows[2].share == 1 and rows[2].covered_with_pairs == 0, "5 : cuivre tout électrique : part 100 %")
    check(rows[3].share == 0, "5 : charbon tout thermique : part 0")
    check(rows[4].share == nil, "5 : un minerai sans foreuse n'a pas de part")
  end

  do -- 7. Lot THERMIQUE2 (essai 3) : minerai brut plein (stock libre >= 3 000) : plus de brûleur
    local raw = { resource = "r", product = "r" }
    local plate = { resource = "r", product = "p" }
    check(Th.raw_full(raw, { r = 3000 }) == true, "7 : minerai brut à 3 000 au stock : plein")
    check(Th.raw_full(raw, { r = 2999 }) == false, "7 : minerai brut à 2 999 : pas plein")
    check(Th.raw_full(raw, {}) == false and Th.raw_full(raw, nil) == false, "7 : stock vide ou absent : pas plein")
    check(Th.raw_full(plate, { p = 1e6, r = 1e6 }) == false, "7 : paire avec four (produit = plaque) : jamais plein, même stock énorme")
    check(Th.raw_full(nil, { r = 1e6 }) == false, "7 : type inconnu : pas plein")
    check(Th.raw_full(raw, { r = 1500 }, { raw_stock_max = 1000 }) == true, "7 : le seuil se lit du réglage")
  end

  do -- 8. Lot THERMIQUE5 (revue du 3/11) : pile, fin d'ordre, lignes sans effet, arrêt, garde de plaques, électrique pleine, brûleurs à sec
    -- 8a. pile : suivre et balayer jamais retenus ; partir retenu, sauf porte ouverte ; sans retenue tout passe
    check(Th.pile_permits("suivre", true) and Th.pile_permits("balayer", true), "8a : retenue : une bande demandée avance, le balayage passe")
    check(not Th.pile_permits("partir", true, false) and not Th.pile_permits("partir", true, nil), "8a : retenue : pas de bande neuve, porte fermée")
    check(Th.pile_permits("partir", true, true), "8a : retenue : bande neuve si la porte laisse passer sa plaque")
    check(Th.pile_permits("partir", false, false) and Th.pile_permits("suivre", false) and Th.pile_permits("balayer", nil),
      "8a : sans retenue : tout passe, porte non lue")
    -- 8b. fin de l'ordre des bandes
    check(Th.order_end(31, 1, 1) == "partiel", "8b : bandes posées, 31 paires hors des bandes : partiel, pas fini")
    check(Th.order_end(5, 0, 0) == "replanifier", "8b : rien de migré, 5 paires : cadre refait (pas d'abandon)")
    check(Th.order_end(0, 2, 2) == "fini", "8b : plus de paire, bandes posées : fini")
    check(Th.order_end(0, 0, 1) == "fini", "8b : bande sans paire qui produit, plus de paire : fini")
    check(Th.order_end(0, 0, 0) == "abandon", "8b : rien de migré, plus de paire : abandon")
    check(Th.order_end(3, 0, 1) == "partiel", "8b : une bande a produit, 3 paires : partiel")
    -- 8c. ligne sans effet : seulement une bande qui portait des paires
    check(Th.noop_counts({ 4, 7 }) == true, "8c : bande avec paires, rien libéré : compte comme sans effet")
    check(Th.noop_counts({}) == false and Th.noop_counts(nil) == false, "8c : bande sans paire (agrandissement) : ne compte pas")
    -- 8d. arrêt d'une ligne qui n'aboutit pas
    check(Th.stop_state(0, 0, 6) == "partiel", "8d : 6 paires déjà retirées : partiel (l'avant-poste reste fermé aux brûleurs)")
    check(Th.stop_state(0, 0, 0) == "abandon" and Th.stop_state(nil, nil, nil) == "abandon", "8d : rien retiré ni migré : abandon")
    check(Th.stop_state(1, 0, 0) == "partiel" and Th.stop_state(0, 1, 0) == "partiel", "8d : une partie migrée ou une ligne produite : partiel")
    -- 8e. garde de plaques
    -- 8f. états qui couvrent
    check(Th.covering("working") and Th.covering("waiting_for_space_in_destination"), "8f : en marche et sortie pleine couvrent")
    check(not Th.covering("no_power") and not Th.covering("no_minable_resources") and not Th.covering("waiting_for_source_items")
      and not Th.covering(nil), "8f : sans courant, sans minerai, sans entrée : ne couvre pas")
    -- 8h. priorité 0 : seule une bande FINIE au plan couvre (l'amorce d'une bande en chantier fait déjà tourner des foreuses)
    -- (lot THERMIQUE7, essai 4 : jugée à sa production, quel que soit son état ; jamais produit : ne couvre rien)
    for _, st in ipairs({ "attente", "plan", "reserve", "defrichage", "fantomes", "chantier", "bloque", "refuse", "fini" }) do
      check(Th.band_covers(st, false, true) == false, "8h : bande « " .. st .. " » qui n'a jamais produit : ne couvre pas")
      check(Th.band_covers(st, true, false) == false, "8h : bande « " .. st .. " » qui a produit mais à l'arrêt (aucun four en marche) : ne couvre pas")
      check(Th.band_covers(st, true, true) == true, "8h : bande « " .. st .. " » qui a produit et produit : couvre")
    end
    check(Th.band_covers(nil, nil, nil) == false, "8h : rien de connu : ne couvre pas")
    -- 8i. lot THERMIQUE6 (essai 3) : bande bloquée qui a produit ; sortie pleine seulement si la bande produit ; éteint : règle de THERMIQUE5
    local OFF = { cover_by_output = false }
    check(Th.band_covers("bloque", true, true, OFF) == false and Th.band_covers("fini", false, false, OFF) == true,
      "8i : éteint : seule la bande finie au plan couvre (règle de P0)")
    check(Th.drill_counts("working", false) == true, "8i : foreuse en marche : compte, même bande sans fonte")
    check(Th.drill_counts("waiting_for_space_in_destination", true) == true, "8i : sortie pleine, bande qui produit : compte")
    check(Th.drill_counts("waiting_for_space_in_destination", false) == false, "8i : sortie pleine, fonderie à l'arrêt : ne compte pas")
    check(Th.drill_counts("no_power", true) == false and Th.drill_counts(nil, true) == false, "8i : sans courant, état inconnu : ne compte pas")
    check(Th.drill_counts("waiting_for_space_in_destination", false, OFF) == true, "8i : éteint : sortie pleine compte (règle de THERMIQUE5)")
    -- 8j. lot THERMIQUE6, règle B : brûleur à sec retiré seul après dry_wait, bande finie, protection tenue
    local W = C.dry_wait
    check(Th.dry_retire(100, 100 + W, true, true) == true, "8j : à sec depuis dry_wait, bande finie : retiré")
    check(Th.dry_retire(100, 100 + W - 1, true, true) == false, "8j : à sec depuis moins de dry_wait : gardé")
    check(Th.dry_retire(100, 100 + W, false, true) == false, "8j : aucune bande finie : gardé")
    check(Th.dry_retire(100, 100 + W, true, false) == false, "8j : charbon de la centrale sous son plancher : gardé")
    check(Th.dry_retire(nil, 1e9, true, true) == false, "8j : avec du combustible (pas de date) : gardé")
    check(Th.dry_retire(0, 30, true, nil, { dry_wait = 30 }) == true, "8j : la durée se lit du réglage, protection absente : retiré")
    -- 8g. brûleurs à sec : n'extraient rien
    local th0 = Th.supply(fl(1, "a", 24, 12, { fueled = 0 }))
    check(th0 == 0, "8g : 24 paires à sec : extraction thermique nulle")
    check(Th.covered(fl(1, "a", 24, 12, { fueled = 0 })), "8g : 12 électriques contre 24 paires à sec : couvert")
    check(not Th.covered(fl(1, "a", 30, 12, { fueled = 30 })), "8g : 12 électriques (6,0) contre 30 paires qui brûlent (7,5) : pas couvert")
    check(Th.supply(fl(1, "a", 8, 0)) == 2.0, "8g : sans compte de combustible : toutes les paires comptent (8 × 0,25)")
    check(Th.supply(fl(1, "a", 8, 0, { fueled = 3 })) == 0.75, "8g : 3 paires avec combustible sur 8 : 0,75 ore/s")
  end

  return failures - before
end

section("1 à 5. Règle pure")
local Th = load_module(SRC)
local bad = suite(Th, false)
check(bad == 0, "la batterie passe sur la règle réelle")

section("6. Mutants")
local function mutate(from, to)
  local i, j = SRC:find(from, 1, true)
  assert(i, "motif de mutant introuvable : " .. from)
  assert(not SRC:find(from, j + 1, true), "motif de mutant ambigu : " .. from)
  return SRC:sub(1, i - 1) .. to .. SRC:sub(j + 1)
end

local mutants = {
  { "covered : min_working ignoré", "if (fl.working or 0) < cfg.min_working then", "if false then" },
  { "covered : cover_ratio ignoré", "if el + EPS < cfg.cover_ratio * th then", "if el + EPS < 0 then" },
  { "covered : rapport inversé", "if el + EPS < cfg.cover_ratio * th then", "if th + EPS < cfg.cover_ratio * el then" },
  { "supply : cadence électrique prise pour la thermique", "(fl.working or 0) * (fl.el_rate or 0)", "(fl.working or 0) * (fl.th_rate or 0)" },
  { "cut_ok : plancher ignoré", "if rest + EPS >= floor and not sole then", "if not sole then" },
  { "cut_ok : dernière source permise", "local sole = rest <= EPS", "local sole = false" },
  { "cut_ok : minerai critique pontable par le stock", "if (ctx.critical or {})[res] then return false, \"source-critique\" end", "" },
  { "cut_ok : stock sans horizon", "if stock + EPS >= need * cfg.horizon then", "if stock + EPS >= need then" },
  { "cut_ok : manque sans plancher", "local need = math.max(floor, sole and lost or 0) - rest", "local need = 0" },
  { "cut_ok : autres minerais comptés", "if g.res == res then\n      local th, el = M.supply(g)\n      total = total + th + el", "do\n      local th, el = M.supply(g)\n      total = total + th + el" },
  { "sweep : chantier en cours ignoré", "if g.busy then", "if false then" },
  { "sweep : protection ignorée", "ok, why = M.cut_ok(g, fields, th, ctx, cfg)", "ok, why = true, \"x\"" },
  { "sweep : non couvert balayé", "if ok then\n        local th = M.supply(g)", "if true then\n        local th = M.supply(g)" },
  { "sweep : sweep_max ignoré", "for i = 1, math.min(#cands, cfg.sweep_max) do", "for i = 1, #cands do" },
  { "sweep : le moins productif d'abord", "if ta ~= tb then return ta > tb end\n    return a.id < b.id\n  end)\n  local out = {}", "if ta ~= tb then return ta < tb end\n    return a.id < b.id\n  end)\n  local out = {}" },
  { "financed : courant ignoré", "if not ctx.power then return false, \"courant\" end", "" },
  { "financed : coût ignoré", "if (ctx.iron or 0) + EPS < cfg.fund_ratio * cost then return false, \"fer\" end", "" },
  { "financed : une foreuse de moins", "need = math.ceil(th / fl.el_rate - EPS)", "need = math.floor(th / fl.el_rate - EPS)" },
  { "order : voulus ignorés", "if wa ~= wb then return wa > wb end", "" },
  { "order : rang des plaques ignoré", "if ra ~= rb then return ra < rb end", "" },
  { "order : le moins productif d'abord", "if ta ~= tb then return ta > tb end\n    local ha", "if ta ~= tb then return ta < tb end\n    local ha" },
  { "order : stock le plus haut d'abord", "if ha ~= hb then return ha < hb end", "if ha ~= hb then return ha > hb end" },
  { "order : tri en place", "local out = {}\n  for _, g in ipairs(cands) do out[#out + 1] = g end\n  table.sort(out,", "local out = cands\n  table.sort(out," },
  { "verdict : le critique passe après l'attente", "if age > cfg.critical_wait then return \"annuler\" end\n    return \"attendre\"", "return \"retirer\"" },
  { "verdict : l'ordinaire n'attend jamais", "if age > cfg.protect_wait then return \"retirer\" end", "return \"retirer\"" },
  { "verdict : l'ordinaire attend toujours", "if age > cfg.protect_wait then return \"retirer\" end", "if false then return \"retirer\" end" },
  { "free_slot : un minerai plusieurs chantiers", "if (busy[res] or 0) >= cfg.per_mineral then", "if false then" },
  { "free_slot : 2e chantier sans bloquage", "((busy.stuck and busy.stuck[res]) or 0) >= (busy[res] or 0) then", "true then" },
  { "free_slot : 2e chantier pour tout minerai", "if busy.key ~= nil and busy.key == res and", "if busy.key ~= nil and" },
  { "free_slot : plafond de la plaque clé", "(busy[res] or 0) < cfg.key_per_mineral and", "" },
  { "band_stuck : degel compte", "reason ~= \"degel\" and", "" },
  { "band_stuck : seuil inclusif", "(age or 0) > cfg.stuck_wait", "(age or 0) >= cfg.stuck_wait" },
  { "band_stuck : chantier compte", "state == \"reserve\" and reason", "reason" },
  { "free_slot : total ignoré", "if (busy.total or 0) >= cfg.slots then", "if false then" },
  -- IA-SPAWN : voie de la plaque clé
  { "free_slot : voie de la plaque clé ignorée", 'if busy.key ~= nil and busy.key == res and (busy[res] or 0) == 0 then return true, "voie-cle" end', '' },
  { "free_slot : voie pour tout minerai", 'if busy.key ~= nil and busy.key == res and (busy[res] or 0) == 0 then return true, "voie-cle" end', 'if (busy[res] or 0) == 0 then return true, "voie-cle" end' },
  { "free_slot : voie même avec un chantier", 'if busy.key ~= nil and busy.key == res and (busy[res] or 0) == 0 then return true, "voie-cle" end', 'if busy.key ~= nil and busy.key == res then return true, "voie-cle" end' },
  { "free_slot : voie sans plaque clé déclarée", 'if busy.key ~= nil and busy.key == res and (busy[res] or 0) == 0 then return true, "voie-cle" end', 'if (busy.key == nil or busy.key == res) and (busy[res] or 0) == 0 then return true, "voie-cle" end' },
  { "raw_full : seuil ignoré", "return ((stock or {})[spec.product] or 0) >= cfg.raw_stock_max", "return true" },
  { "raw_full : seuil strict", "return ((stock or {})[spec.product] or 0) >= cfg.raw_stock_max", "return ((stock or {})[spec.product] or 0) > cfg.raw_stock_max" },
  { "raw_full : paire avec four comptée", "if spec == nil or spec.product ~= spec.resource then return false end", "if spec == nil then return false end" },
  { "shares : paires des gisements couverts non comptées", "if (g.pairs or 0) > 0 and M.covered(g, cfg) then", "if false then" },
  -- lot THERMIQUE5
  { "pile : départ toujours permis", "  return porte == true\nend", "  return true\nend" },
  { "pile : départ jamais permis sous retenue", "  return porte == true\nend", "  return false\nend" },
  { "pile : suivi retenu", "if action == \"suivre\" or action == \"balayer\" then return true end", "if action == \"balayer\" then return true end" },
  { "pile : balayage retenu", "if action == \"suivre\" or action == \"balayer\" then return true end", "if action == \"suivre\" then return true end" },
  { "pile : retenue ignorée", "  if not hold then return true end\n  if action", "  if true then return true end\n  if action" },
  { "order_end : fini avec des paires", "if (left or 0) > 0 then return migrated and \"partiel\" or \"replanifier\" end", "" },
  { "order_end : abandon au lieu de refaire", "return migrated and \"partiel\" or \"replanifier\"", "return migrated and \"partiel\" or \"abandon\"" },
  { "noop_counts : toute bande compte", "  return #(ids or {}) > 0\nend", "  return true\nend" },
  { "stop_state : retrait ignoré", "or (retired or 0) > 0 then return \"partiel\" end", "then return \"partiel\" end" },
  { "covering : sortie pleine ignorée", "M.COVERING_STATUS = { \"working\", \"waiting_for_space_in_destination\" }", "M.COVERING_STATUS = { \"working\" }" },
  { "covering : tout couvre", "  for _, s in ipairs(M.COVERING_STATUS) do if s == status_name then return true end end\n  return false", "  return true" },
  { "band_covers : toute bande couvre", "  return made_ok == true and live == true\nend", "  return true\nend" },
  { "band_covers : éteint, toute bande couvre", "  if cfg.cover_by_output ~= true then return state == \"fini\" end", "  if cfg.cover_by_output ~= true then return true end" },
  { "band_covers : jamais produit couvre", "  return made_ok == true and live == true\nend", "  return live == true\nend" },
  { "band_covers : à l'arrêt couvre", "  return made_ok == true and live == true\nend", "  return made_ok == true\nend" },
  { "band_covers : interrupteur ignoré", "  if cfg.cover_by_output ~= true then return state == \"fini\" end\n", "" },
  { "drill_counts : sortie pleine toujours", "  return live == true\nend", "  return true\nend" },
  { "drill_counts : sortie pleine jamais", "  return live == true\nend", "  return false\nend" },
  { "drill_counts : interrupteur ignoré", "if cfg.cover_by_output ~= true or status_name == \"working\" then return true end", "if status_name == \"working\" then return true end" },
  { "dry_retire : durée ignorée", "  return now - since >= cfg.dry_wait\nend", "  return true\nend" },
  { "dry_retire : bande finie ignorée", "if since == nil or band_done ~= true or protect_ok == false then return false end", "if since == nil or protect_ok == false then return false end" },
  { "dry_retire : protection ignorée", "if since == nil or band_done ~= true or protect_ok == false then return false end", "if since == nil or band_done ~= true then return false end" },
  { "supply : brûleurs à sec comptés", "  local th = fl.fueled\n", "  local th = nil\n" },
}

local survivors = 0
for _, mu in ipairs(mutants) do
  local ok, M2 = pcall(function() return load_module(mutate(mu[2], mu[3])) end)
  local killed
  if not ok then
    killed = true
  else
    local saved_pass, saved_fail = passes, failures
    local silent = print
    _G.print = function() end
    local okr, res = pcall(suite, M2, false)
    _G.print = silent
    killed = (not okr) or res > 0
    passes, failures = saved_pass, saved_fail -- les échecs d'un mutant ne comptent pas
  end
  check(killed, "mutant refusé : " .. mu[1])
  if not killed then survivors = survivors + 1 end
end
print(string.format("[THERMIQUE] mutants %d refusés sur %d", #mutants - survivors, #mutants))

print(string.format("[THERMIQUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
