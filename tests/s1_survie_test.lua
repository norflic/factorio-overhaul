--[[
  Lot S1 SURVIE (retour du DC du 31/10 : « deux factions détruites à 1 h 30 » ; mesures de la 0.6.32, Écarlate : fer 0 pendant 40 min, QG
  détruit à 79,9 min par de petits cracheurs, 7 tourelles comptées 4 018 PV sans un chargeur ; votre équipe sans recette de tourelle, coffre
  perdu = équipe finie) : banc HORS JEU. Lancement : lua5.2 tests/s1_survie_test.lua (racine du mod).

    1. la règle pure (shared/team/survie_qg.lua) : poids d'une tourelle selon ses chargeurs, menace mémorisée, péril avec hystérésis, cause
       (menace / munitions), tourelles voulues bornées, planchers, remplissage partiel, sort du coffre ;
    2. la prévision (shared/ai3/prevision.lua) : k borné plus haut, mémoire des vagues reçues (prévues ET ratées), fenêtre, plancher durable ;
    3. la priorité (shared/team/priorite.lua) : le péril passe devant la survie-pénurie, jamais devant la survie des effectifs ; sans péril,
       la règle d'avant à l'identique (grille) ;
    4. le planificateur : en péril (et en mode survie), la défense du QG est fabriquée sous le plancher ordinaire, les tourelles voulues sont
       posées, les tourelles vides remplies avec un stock incomplet ; sans péril, plan d'avant ;
    5. la CHAÎNE lue dans les sources : chaque maillon (prévision, vue, planificateur, capitalisation, coffre) appelle la règle ;
    6. mutants : chaque règle retirée change au moins un fait observé.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local S = require("shared.team.scale")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end
local function read_src(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  -- Lot TESTS-VERTS : script/team/team.lua mêle CRLF et LF (le bloc de la retenue des recrues est en CRLF depuis QGSURVIE tour 2, 98db0cc2) :
  -- les contrôles de texte lisent des fins de ligne LF
  s = s:gsub("\r\n", "\n")
  return s
end
local IRON, COPPER = T.outposts.iron.product, T.outposts.copper.product

--- Charge les modules purs à partir de leurs sources (les mutants passent un texte modifié par module).
local NAMES = { "shared.team.survie_qg", "shared.team.priorite", "shared.team.planner", "shared.ai3.prevision" }
local KEYMAP = { Sq = "shared.team.survie_qg", Pr = "shared.team.priorite", Pl = "shared.team.planner", Pv = "shared.ai3.prevision" }
local function load_world(over)
  over = over or {}
  local saved = {}
  for _, n in ipairs(NAMES) do saved[n] = package.loaded[n]; package.loaded[n] = nil end
  local W = {}
  for _, key in ipairs({ "Sq", "Pr", "Pv", "Pl" }) do
    local name = KEYMAP[key]
    if over[key] then
      package.loaded[name] = assert(load(over[key], "@" .. name))()
    else
      package.loaded[name] = nil
      package.loaded[name] = require(name)
    end
    W[key] = package.loaded[name]
  end
  for _, n in ipairs(NAMES) do package.loaded[n] = saved[n] end
  return W
end
local W0 = load_world()
local Sq, Pr, Pv, Planner = W0.Sq, W0.Pr, W0.Pv, W0.Pl

local function same_facts(a, b)
  for k, v in pairs(a) do if b[k] ~= v then return false, k end end
  for k, v in pairs(b) do if a[k] ~= v then return false, k end end
  return true
end

---------------------------------------------------------------------------------------------------
-- Faits observés sur la règle pure (les mutants doivent en changer au moins un).
---------------------------------------------------------------------------------------------------
local TV = 574 -- PV d'une tourelle (mesuré : « tourelle 574 PV pour 137 MU », 0.6.32)
local function sq_facts(Sx)
  local f = {}
  -- armed_share
  f.share_empty, f.share_half, f.share_full, f.share_over, f.share_nolow = Sx.armed_share(0, 8), Sx.armed_share(4, 8), Sx.armed_share(8, 8),
    Sx.armed_share(20, 8), Sx.armed_share(3, 0)
  -- menace : fenêtre, QG contre ailleurs
  local waves = { { t = 100, pv = 1200, hq = true }, { t = 200, pv = 3000, hq = false }, { t = -200000, pv = 9999, hq = true } }
  f.threat_in = Sx.threat(waves, 1000)
  f.threat_old_hq = Sx.threat({ { t = 0, pv = 9999, hq = true } }, Sx.WINDOW + 1)
  f.threat_edge = Sx.threat({ { t = 0, pv = 700, hq = true } }, Sx.WINDOW)
  f.threat_elsewhere = Sx.threat({ { t = 10, pv = 3590, hq = false } }, 20)
  f.threat_hq_wins = Sx.threat({ { t = 10, pv = 1800, hq = true }, { t = 11, pv = 3000, hq = false } }, 20)
  f.threat_future = Sx.threat({ { t = 50, pv = 5000, hq = true } }, 10)
  f.threat_empty = Sx.threat({}, 10)
  -- péril : le cas d'Écarlate (7 tourelles VIDES, vague de 1 740 PV)
  local a = Sx.peril({ threat = 1740, armed_value = 0, turret_value = TV, turrets = 7, armed = 0, cap = 8 })
  f.munitions_small = Sx.peril({ threat = 3000, armed_value = 0, turret_value = TV, turrets = 2, armed = 0, cap = 8 }).cause
  f.scar_peril, f.scar_cause, f.scar_want, f.scar_fresh, f.scar_refill, f.scar_need = a.peril, a.cause, a.want, a.fresh, a.refill, a.need
  -- 1 tourelle armée, vague de 1 740 PV : il en faut plus
  local b = Sx.peril({ threat = 1740, armed_value = TV, turret_value = TV, turrets = 1, armed = 1, cap = 8 })
  f.few_peril, f.few_cause, f.few_want, f.few_fresh, f.few_refill = b.peril, b.cause, b.want, b.fresh, b.refill
  -- 7 tourelles armées : rien à faire (la défense n'est pas un trou sans fond)
  local c = Sx.peril({ threat = 2055, armed_value = 7 * TV, turret_value = TV, turrets = 7, armed = 7, cap = 8 })
  f.armed_peril, f.armed_want = c.peril, c.want
  f.small_peril = Sx.peril({ threat = Sx.MIN_THREAT - 1, armed_value = 0, turret_value = TV, turrets = 0, armed = 0, cap = 8 }).peril
  f.min_peril = Sx.peril({ threat = Sx.MIN_THREAT, armed_value = 0, turret_value = TV, turrets = 0, armed = 0, cap = 8 }).peril
  f.novalue_peril = Sx.peril({ threat = 5000, armed_value = 0, turret_value = 0, turrets = 0, armed = 0, cap = 8 }).peril
  -- hystérésis : cible 2 175 PV (1 740 × 1,25), sortie à 2 392
  local need = math.floor(1740 * Sx.COVER_PCT / 100)
  f.hyst_enter = Sx.peril({ threat = 1740, armed_value = need - 1, turret_value = TV, turrets = 4, armed = 4, cap = 8 }).peril
  f.hyst_at_need = Sx.peril({ threat = 1740, armed_value = need, turret_value = TV, turrets = 4, armed = 4, cap = 8 }).peril
  f.hyst_stay = Sx.peril({ threat = 1740, armed_value = need + 10, turret_value = TV, turrets = 4, armed = 4, cap = 8, was = true }).peril
  f.hyst_exit = Sx.peril({ threat = 1740, armed_value = math.floor(need * Sx.EXIT_PCT / 100), turret_value = TV, turrets = 4, armed = 4, cap = 8, was = true }).peril
  -- plafond de tourelles
  local d = Sx.peril({ threat = 10000, armed_value = 0, turret_value = TV, turrets = 2, armed = 2, cap = 8 })
  f.cap_want, f.cap_full = d.want, d.full
  f.nocap_want = Sx.peril({ threat = 10000, armed_value = 0, turret_value = TV, turrets = 2, armed = 2, cap = 0 }).want
  -- jamais moins de tourelles que celles qui sont là (9 tourelles au QG, plafond 8)
  f.keep_want = Sx.peril({ threat = 400, armed_value = 0, turret_value = TV, turrets = 9, armed = 0, cap = 8 }).want
  -- armées > tourelles est corrigé
  f.clamp_refill = Sx.peril({ threat = 3000, armed_value = 0, turret_value = TV, turrets = 2, armed = 9, cap = 8 }).refill
  -- planchers
  local fi, fc, red = Sx.floors(true, 150, 30)
  f.floor_peril = fi .. "/" .. fc .. "/" .. tostring(red)
  fi, fc, red = Sx.floors(false, 150, 30)
  f.floor_calm = fi .. "/" .. fc .. "/" .. tostring(red)
  fi = Sx.floors(true, 40, 5)
  f.floor_low_base = fi
  -- remplissage partiel
  f.refill_partial_peril, f.refill_partial_calm, f.refill_tiny_peril = Sx.refill_take(2, 20, 15, true), Sx.refill_take(2, 20, 15, false), Sx.refill_take(2, 20, 9, true)
  f.refill_full, f.refill_none = Sx.refill_take(2, 20, 99, false), Sx.refill_take(0, 20, 99, true)
  -- sort du coffre
  f.fate_player_mined = Sx.chest_fate({ killed = false, workers = 5, soldiers = 0, recent = 0 })
  f.fate_alone = Sx.chest_fate({ killed = true, workers = 0, soldiers = 0, recent = 0 })
  f.fate_ok = Sx.chest_fate({ killed = true, workers = 1, soldiers = 0, recent = 0 })
  f.fate_soldiers = Sx.chest_fate({ killed = true, workers = 0, soldiers = 2, recent = 0 })
  f.fate_last = Sx.chest_fate({ killed = true, workers = 4, soldiers = 0, recent = Sx.CHEST_MAX - 1 })
  f.fate_too_many = Sx.chest_fate({ killed = true, workers = 4, soldiers = 0, recent = Sx.CHEST_MAX })
  -- lot QGSURVIE : réserve de fer du QG (vanilla : tourelle 40 fer, chargeur 4), module neuf retenu, recrue retenue
  f.rq_vanilla = Sx.qg_reserve({ floor = 150, turret_iron = 40, mag_iron = 4 })
  f.rq_noturret = Sx.qg_reserve({ floor = 150, turret_iron = nil, mag_iron = 4 })
  f.rq_frac = Sx.qg_reserve({ floor = 0, turret_iron = 0.25, mag_iron = 0 })
  f.rq_nil = Sx.qg_reserve(nil)
  f.mh_under = Sx.module_held({ iron = 309, reserve = 310 })
  f.mh_at = Sx.module_held({ iron = 310, reserve = 310 })
  f.mh_rebuild = Sx.module_held({ iron = 0, reserve = 310, rebuild = true })
  f.mh_noreserve = Sx.module_held({ iron = 0, reserve = nil })
  f.rh_fallen = Sx.recruit_hold({ armed = 0, threat = true, workers = 3 })
  f.rh_armed = Sx.recruit_hold({ armed = 1, threat = true, workers = 3 })
  f.rh_calm = Sx.recruit_hold({ armed = 0, threat = false, workers = 3 })
  f.rh_last = Sx.recruit_hold({ armed = 0, threat = true, workers = 1 })
  f.rh_alone = Sx.recruit_hold({ armed = 0, threat = true, workers = 0 })
  return f
end

section("1. La règle pure : menace, péril, hystérésis, cause, plafond, planchers, coffre")
local F0 = sq_facts(Sq)
check(F0.share_empty == 0 and F0.share_half == 500 and F0.share_full == 1000 and F0.share_over == 1000 and F0.share_nolow == 1000,
  "une tourelle vide ne défend rien, à moitié chargée la moitié, au seuil bas ou au-delà tout (0.6.32 : 7 vides comptaient 4 018 PV)")
check(F0.threat_in == 1500 and F0.threat_old_hq == 0 and F0.threat_edge == 700 and F0.threat_elsewhere == 1795 and F0.threat_hq_wins == 1800
  and F0.threat_future == 0 and F0.threat_empty == 0,
  "menace : la plus grosse vague de la fenêtre de 30 min (bord compris), ailleurs pour moitié (3 590 PV d'un avant-poste -> 1 795), le QG l'emporte s'il est plus gros")
check(F0.scar_peril and F0.scar_cause == "munitions" and F0.scar_need == 2175 and F0.scar_want == 7 and F0.scar_fresh == 0 and F0.scar_refill == 7,
  "Écarlate 75,8 min : 7 tourelles VIDES contre 1 740 PV -> péril, cause munitions, aucune tourelle de plus mais 7 à remplir")
check(F0.munitions_small == "menace", "2 tourelles vides qui ne couvriraient pas la menace même chargées : cause menace (il en faut plus), pas munitions")
check(F0.few_peril and F0.few_cause == "menace" and F0.few_want == 4 and F0.few_fresh == 3 and F0.few_refill == 0,
  "1 tourelle armée contre 1 740 PV -> péril, cause menace, 4 tourelles voulues dont 3 à poser")
check(not F0.armed_peril and F0.armed_want == 7, "7 tourelles ARMÉES contre 2 055 PV (cible 2 568 < 4 018) : pas de péril, rien de plus (pas de trou sans fond)")
check(not F0.small_peril and F0.min_peril and not F0.novalue_peril, "sous Sq.MIN_THREAT : pas de péril ; au seuil : péril ; valeur de tourelle inconnue : rien")
check(F0.hyst_enter and F0.hyst_at_need == false and F0.hyst_stay and F0.hyst_exit == false,
  "hystérésis : entrée sous la cible, pas d'entrée à la cible, le péril retenu tient jusqu'à cible × 1,10 puis cesse")
check(F0.cap_want == 8 and F0.cap_full and F0.nocap_want == 22 and F0.keep_want == 9, "tourelles voulues bornées au plafond (8), jamais moins que celles qui sont là")
check(F0.clamp_refill == 0, "des armées en trop (9 sur 2) ne donnent pas un remplissage négatif")
check(F0.floor_peril == "60/10/true" and F0.floor_calm == "150/30/false" and F0.floor_low_base == 40,
  "planchers : réduits en péril (jamais au-dessus du plancher ordinaire), ordinaires sinon")
check(F0.refill_partial_peril == 15 and F0.refill_partial_calm == 0 and F0.refill_tiny_peril == 0 and F0.refill_full == 40 and F0.refill_none == 0,
  "remplissage : un stock incomplet part en péril (>= 5 par tourelle vide), jamais hors péril (tout ou rien d'avant)")
check(F0.fate_player_mined == "fin" and F0.fate_alone == "fin" and F0.fate_ok == "poser" and F0.fate_soldiers == "poser" and F0.fate_last == "poser"
  and F0.fate_too_many == "fin",
  "coffre : reposé s'il est détruit et que des PNJ vivent ; fin si le joueur l'a retiré, si personne ne vit, ou après trop de pertes en 30 min")
check(F0.rq_vanilla == 310 and F0.rq_noturret == 230 and F0.rq_frac == 1 and F0.rq_nil == 0,
  "QGSURVIE : réserve du QG = plancher 150 + 2 × (tourelle 40 + 10 chargeurs × 4) = 310 ; sans recette de tourelle 230 ; arrondie au-dessus")
check(F0.mh_under and not F0.mh_at and not F0.mh_rebuild and not F0.mh_noreserve,
  "QGSURVIE : module neuf retenu sous la réserve (309 < 310), libre à la réserve, jamais une reconstruction, rien sans réserve")
check(F0.rh_fallen and not F0.rh_armed and not F0.rh_calm and F0.rh_last and F0.rh_alone,
  "QGSURVIE : recrue retenue dans un QG sans tourelle armée sous l'attaque, même pour l'équipe vide (tour 1 : une recrue sans arme " ..
  "tuée toutes les 6 s) ; libre avec une tourelle armée ou sans ennemi à portée")

-- déterminisme et invariants sur une grille
local bad, n = 0, 0
for _, threat in ipairs({ 0, 299, 300, 900, 1740, 5000, 20000 }) do
  for _, av in ipairs({ 0, 574, 2000, 4018, 9000 }) do
    for _, tur in ipairs({ 0, 1, 4, 8, 9 }) do
      for _, arm in ipairs({ 0, 1, 4, 8 }) do
        for _, was in ipairs({ false, true }) do
          local a = { threat = threat, armed_value = av, turret_value = TV, turrets = tur, armed = arm, cap = 8, was = was }
          local r1, r2 = Sq.peril(a), Sq.peril(a)
          n = n + 1
          if r1.peril ~= r2.peril or r1.want ~= r2.want then bad = bad + 1 end
          if r1.want < tur then bad = bad + 1 end
          if r1.fresh ~= r1.want - tur then bad = bad + 1 end
          if r1.want > math.max(8, tur) then bad = bad + 1 end
          if r1.peril and av >= math.floor(threat * Sq.COVER_PCT / 100 * (was and Sq.EXIT_PCT or 100) / 100) then bad = bad + 1 end
          if not r1.peril and threat >= Sq.MIN_THREAT and av < math.floor(threat * Sq.COVER_PCT / 100) and not was then bad = bad + 1 end
        end
      end
    end
  end
end
check(bad == 0, "grille de " .. n .. " cas : déterministe, tourelles voulues entre celles qui sont là et le plafond, péril = défense armée sous la cible")

---------------------------------------------------------------------------------------------------
section("2. La prévision : k borné plus haut, mémoire des vagues reçues")
---------------------------------------------------------------------------------------------------
local function pv_facts(Px)
  local f = {}
  -- k atteint plus de 4,00 : les rapports mesurés valaient 4,1, 3,6 puis 10,9
  local cal = {}
  local keys = { "qg" }
  local tick = 0
  for _, rec in ipairs({ { 112, 454 }, { 218, 795 }, { 108, 1182 }, { 100, 1200 } }) do
    Px.calibrate(cal, keys, { qg = { pred_raw = rec[1], contact = rec[2], source = true } }, tick)
    tick = tick + 3600
    Px.calibrate(cal, keys, { qg = { pred_raw = rec[1], source = true } }, tick)
    tick = tick + 3600
  end
  f.k_above_old_cap = Px.k_of(cal) > 4000
  f.k_bounded = Px.k_of(cal) <= Px.K_MAX
  -- mémoire : une vague prévue ET une vague ratée
  local cm = {}
  Px.calibrate(cm, { "qg", "ap1" }, { qg = { pred_raw = 0, contact = 1500, source = false }, ap1 = {} }, 100)
  Px.calibrate(cm, { "qg", "ap1" }, { qg = {}, ap1 = {} }, 100 + 60)           -- fin de l'attaque : RATÉ de 1 500 PV au QG
  Px.calibrate(cm, { "qg", "ap1" }, { qg = {}, ap1 = { pred_raw = 400, contact = 900, source = true } }, 200)
  Px.calibrate(cm, { "qg", "ap1" }, { qg = {}, ap1 = { pred_raw = 400, source = true } }, 260) -- VAGUE de 900 PV à ap1 (prévue 400)
  local w = Px.threat_waves(cm, "qg")
  f.mem_n = #w
  f.mem_hq_flag = (w[1] and w[1].hq) and "y" or "n"
  f.mem_other_flag = (w[2] and w[2].hq) and "y" or "n"
  f.mem_pv1, f.mem_pv2 = w[1] and w[1].pv, w[2] and w[2].pv
  f.floor_hq = Px.mem_floor(cm, "qg", 300)
  f.floor_ap = Px.mem_floor(cm, "ap1", 300)
  f.floor_unknown = Px.mem_floor(cm, "zz", 300)
  f.floor_old = Px.mem_floor(cm, "qg", 160 + Px.MEM_TICKS + 1)
  f.floor_edge = Px.mem_floor(cm, "qg", 160 + Px.MEM_TICKS)
  -- le plancher d'un raté (par site) tombe toujours quand plus rien ne nous vise (test historique) mais la mémoire dure
  f.site_floor_dropped = cm.qg.floor == nil
  -- bornes de la mémoire
  local cb = {}
  for i = 1, 40 do
    Px.calibrate(cb, { "qg" }, { qg = { pred_raw = 0, contact = 10 + i, source = false } }, i * 100)
    Px.calibrate(cb, { "qg" }, { qg = {} }, i * 100 + 50)
  end
  f.mem_cap = #(cb[Px.TEAM].waves or {})
  local cg = {}
  Px.calibrate(cg, { "qg" }, { qg = { pred_raw = 0, contact = 800, source = false } }, 0)
  Px.calibrate(cg, { "qg" }, { qg = {} }, 50)
  Px.calibrate(cg, { "qg" }, { qg = { pred_raw = 0, contact = 600, source = false } }, Px.MEM_TICKS + 1000)
  Px.calibrate(cg, { "qg" }, { qg = {} }, Px.MEM_TICKS + 1050)
  f.mem_pruned = #(cg[Px.TEAM].waves or {})
  -- sauvegarde d'avant le lot : pas de mémoire, aucune erreur
  f.old_save = #Px.threat_waves({ qg = { k = 650, hit = 3 } }, "qg") + Px.mem_floor({}, "qg", 10) + Px.mem_floor(nil, "qg", 10)
  return f
end
local P0 = pv_facts(Pv)
check(P0.k_above_old_cap and P0.k_bounded, "k dépasse l'ancien plafond de 4,00 après les rapports mesurés (4,1, 3,6, 10,9) et reste borné")
check(P0.mem_n == 2 and P0.mem_hq_flag == "y" and P0.mem_other_flag == "n" and P0.mem_pv1 == 1500 and P0.mem_pv2 == 900,
  "la mémoire garde le raté du QG (1 500 PV) ET la vague prévue d'un avant-poste (900 PV), avec le drapeau « reçue au QG »")
check(P0.floor_hq == 1500 and P0.floor_ap == 900 and P0.floor_unknown == 0, "plancher durable par site : la plus grosse vague reçue")
check(P0.floor_old == 0 and P0.floor_edge == 1500, "le plancher durable s'éteint après la fenêtre de 30 min (bord compris)")
check(P0.site_floor_dropped, "le plancher d'un raté par site garde sa règle (tombe quand plus rien ne nous vise) : test historique intact")
check(P0.mem_cap == 24 and P0.mem_pruned == 1, "mémoire bornée : 24 faits au plus, les faits de plus de 30 min partent")
check(P0.old_save == 0, "une calibration d'avant le lot (sans mémoire) ne plante pas")

---------------------------------------------------------------------------------------------------
section("3. La priorité : le péril passe devant la survie-pénurie, jamais devant la survie des effectifs")
---------------------------------------------------------------------------------------------------
local function pr_facts(Px)
  local f = {}
  local a = Px.decide({ funds = 30, defense_cost = 100, production_cost = 50, survie = true, peril = true })
  f.peril_mode, f.peril_pf, f.peril_hold, f.peril_budget = a.mode, a.production_first, a.hold, a.defense_budget
  local b = Px.decide({ funds = 500, defense_cost = 100, production_cost = 50, survie = true, peril = true })
  f.rich_mode, f.rich_pf = b.mode, b.production_first
  local c = Px.decide({ funds = 5, defense_cost = 100, production_cost = 50, survie = true, peril = true, survival = true })
  f.survival_mode, f.survival_pf = c.mode, c.production_first
  local d = Px.decide({ funds = 30, defense_cost = 100, production_cost = 50, survie = true })
  f.nope_mode, f.nope_pf = d.mode, d.production_first
  local e = Px.decide({ funds = 30, defense_cost = 100, production_cost = nil, peril = true })
  f.nostep_mode = e.mode
  return f
end
local R0 = pr_facts(Pr)
check(R0.peril_mode == Pr.MODE_QG_PERIL and not R0.peril_pf and R0.peril_hold == 0 and R0.peril_budget == 30,
  "péril + survie-pénurie + fer qui ne paie pas : la défense d'abord, rien mis de côté pour la production")
check(R0.rich_mode == Pr.MODE_QG_PERIL and not R0.rich_pf, "péril, fer riche : la défense d'abord aussi (le péril l'emporte sur la survie-pénurie)")
check(R0.survival_mode == Pr.MODE_SURVIE and not R0.survival_pf, "équipe décimée (survie des effectifs) : les recrues gardent la main sur le péril")
check(R0.nope_mode == Pr.MODE_SURVIE_PENURIE and R0.nope_pf, "sans péril : la survie-pénurie comme avant (production d'abord)")
check(R0.nostep_mode == Pr.MODE_QG_PERIL, "péril sans pas de production à faire : mode péril")
local badg = 0
for _, fd in ipairs({ 0, 40, 150, 700 }) do
  for _, cd in ipairs({ 0, 90 }) do
    for _, cp in ipairs({ -1, 0, 50 }) do
      for _, sv_ in ipairs({ false, true }) do
        for _, sl in ipairs({ false, true }) do
          local base = { funds = fd, defense_cost = cd, production_cost = cp >= 0 and cp or nil, survie = sv_, survival = sl }
          local x = Pr.decide(base)
          base.peril = false
          local y = Pr.decide(base)
          base.peril = true
          local z = Pr.decide(base)
          if x.mode ~= y.mode or x.hold ~= y.hold or x.production_first ~= y.production_first or x.defense_budget ~= y.defense_budget then badg = badg + 1 end
          if z.hold + z.defense_budget ~= z.funds then badg = badg + 1 end
          if not sl and (z.production_first or z.mode ~= Pr.MODE_QG_PERIL) then badg = badg + 1 end
          if sl and z.mode ~= x.mode then badg = badg + 1 end
        end
      end
    end
  end
end
check(badg == 0, "grille : `peril` absent ou faux = règle d'avant ; vrai = défense d'abord sauf équipe décimée ; le fer se partage sans perte")

---------------------------------------------------------------------------------------------------
section("4. Le planificateur : défense du QG sous le plancher, tourelles voulues, remplissage partiel")
---------------------------------------------------------------------------------------------------
local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)
local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true, defense = true },
    deferred = {}, stock = {}, incoming = {}, outposts = {}, pending = {}, sites = { iron = 1 }, smelters = 2,
    smelters_pending = 0, smelter_task = false, smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0,
    turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 8, workers_max = 30, workers_idle = 0,
    threatened = false, open = {}, workers_wanted = 30, no_research = true, ladder = T.player_ladder,
    hq_turrets = T.defend_hq, defend_first = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function keys_of(p)
  local set = {}
  for _, t in ipairs(p.tasks) do set[t.key] = true end
  return set
end
local recipes_nt = {}
for k, v in pairs(recipes) do if k ~= "gun-turret" then recipes_nt[k] = v end end
local book_norecipe = Book.new(recipes_nt)
local PERIL = { peril = true, want = 6, fresh = 2, refill = 0, cause = "menace" }
local function pl_facts(Pl, PrX)
  local f = {}
  -- A : fer 160 (sous le plancher ordinaire de 150 + une commande), survie-pénurie, aucune tourelle au stock
  local stock_a = { [IRON] = 160, [COPPER] = 200, coal = 100, stone = 100 }
  for _, sc in ipairs({ { "calm", nil }, { "peril", PERIL } }) do
    local p = Pl.plan(view({ stock = stock_a, hq_turrets = 4, hq_defend = 4, qg_peril = sc[2], survie = true }), book)
    local k = keys_of(p)
    f["A_" .. sc[1] .. "_mode"] = p.priorite.mode
    f["A_" .. sc[1] .. "_turret"] = k["craft:gun-turret:defense:1"] and 1 or 0
    f["A_" .. sc[1] .. "_ammo"] = k["craft:firearm-magazine:defense:1"] and 1 or 0
  end
  -- B : tourelles au stock, le QG en a 4 et en veut 4 : seul le péril en veut 6 -> tâche fortify:hq
  local stock_b = { [IRON] = 100, [COPPER] = 200, ["gun-turret"] = 2, [T.turret_ammo] = 60, coal = 100, stone = 100 }
  for _, sc in ipairs({ { "calm", nil }, { "peril", PERIL } }) do
    local p = Pl.plan(view({ stock = stock_b, hq_turrets = 4, hq_defend = 4, qg_peril = sc[2], survie = true }), book)
    f["B_" .. sc[1] .. "_fortify"] = keys_of(p)["fortify:hq"] and 1 or 0
  end
  -- C : deux tourelles du QG vides (low = 2), 15 chargeurs au coffre (il en faut 40)
  local g = { { key = "o1", low = 1, has_task = false }, { key = "hq", low = 2, has_task = false } }
  for _, sc in ipairs({ { "calm", nil }, { "peril", PERIL } }) do
    local p = Pl.plan(view({ stock = { [IRON] = 100, [COPPER] = 200, [T.turret_ammo] = 15 }, hq_turrets = 4, turret_groups = g, qg_peril = sc[2] }), book)
    local k = keys_of(p)
    f["C_" .. sc[1] .. "_refill_hq"] = k["refill:hq"] and 1 or 0
    f["C_" .. sc[1] .. "_refill_o1"] = k["refill:o1"] and 1 or 0
  end
  -- E : en péril, un avant-poste seul (stock incomplet) garde la règle de tout ou rien
  local pe = Pl.plan(view({ stock = { [IRON] = 100, [COPPER] = 200, [T.turret_ammo] = 15 }, hq_turrets = 4,
    turret_groups = { { key = "o1", low = 1, has_task = false } }, qg_peril = PERIL }), book)
  f.E_peril_o1_alone = keys_of(pe)["refill:o1"] and 1 or 0
  -- F : sans recette de tourelle ni tourelle au stock, le péril ne prend pas le pas sur la production (mais les tourelles posées se remplissent)
  local pn = Pl.plan(view({ stock = { [IRON] = 160, [COPPER] = 200, coal = 100, stone = 100 }, hq_turrets = 4, hq_defend = 4, qg_peril = PERIL,
    survie = true }), book_norecipe)
  f.F_norecipe_mode, f.F_norecipe_pf = pn.priorite.mode, pn.priorite.production_first
  local pr = Pl.plan(view({ stock = { [IRON] = 100, [COPPER] = 200, [T.turret_ammo] = 15 }, hq_turrets = 4,
    turret_groups = { { key = "o1", low = 1, has_task = false }, { key = "hq", low = 2, has_task = false } }, qg_peril = PERIL }), book_norecipe)
  f.F_norecipe_refill = keys_of(pr)["refill:hq"] and 1 or 0
  -- G (lot HQ-RECENSEMENT) : péril, 9 tourelles au recensement à 48 tuiles (avant-postes voisins compris) dont 4 du groupe « hq »,
  -- aucune à poser (fresh = 0), tourelles au stock : le groupe « hq » ne veut pas les 9 (avant : tâche fortify:hq, une pose en appelait une autre) ;
  -- avec fresh = 2 : 4 + 2 = 6, la tâche part
  local stock_g = { [IRON] = 100, [COPPER] = 200, ["gun-turret"] = 4, [T.turret_ammo] = 80, coal = 100, stone = 100 }
  local pg0 = Pl.plan(view({ stock = stock_g, hq_turrets = 4, hq_defend = 4, survie = true,
    qg_peril = { peril = true, want = 9, fresh = 0, refill = 0, cause = "menace" } }), book)
  f.G_census_fortify = keys_of(pg0)["fortify:hq"] and 1 or 0
  local pg2 = Pl.plan(view({ stock = stock_g, hq_turrets = 4, hq_defend = 4, survie = true,
    qg_peril = { peril = true, want = 11, fresh = 2, refill = 0, cause = "menace" } }), book)
  f.G_fresh_fortify = keys_of(pg2)["fortify:hq"] and 1 or 0
  -- D : un péril qui n'est pas un péril (peril = false) ne change rien
  local p0 = Pl.plan(view({ stock = stock_a, hq_turrets = 4, hq_defend = 4, survie = true }), book)
  local p1 = Pl.plan(view({ stock = stock_a, hq_turrets = 4, hq_defend = 4, qg_peril = { peril = false, want = 9 }, survie = true }), book)
  f.D_same = (p0.priorite.mode == p1.priorite.mode and #p0.tasks == #p1.tasks) and 1 or 0
  return f
end
local L0 = pl_facts(Planner, Pr)
check(L0.A_calm_mode == Pr.MODE_SURVIE_PENURIE and L0.A_calm_turret == 0 and L0.A_calm_ammo == 0,
  "témoin : fer 160, mode survie, QG sans péril : la production d'abord, aucune tourelle fabriquée (plancher de 150)")
check(L0.A_peril_mode == Pr.MODE_QG_PERIL and L0.A_peril_turret == 1 and L0.A_peril_ammo == 1,
  "QG en péril, mêmes données : la défense d'abord, une tourelle et ses chargeurs fabriqués sous l'ancien plancher")
check(L0.B_calm_fortify == 0 and L0.B_peril_fortify == 1, "tourelles au stock : le QG en péril en veut 6 (4 posées) et la tâche de pose part ; sans péril, rien")
check(L0.C_calm_refill_hq == 0 and L0.C_peril_refill_hq == 1 and L0.C_peril_refill_o1 == 0 and L0.C_calm_refill_o1 == 0,
  "15 chargeurs pour 2 tourelles vides (40 voulus) : le QG en péril est rempli quand même ; l'avant-poste garde la règle de tout ou rien")
check(L0.E_peril_o1_alone == 0, "en péril, un avant-poste seul avec 15 chargeurs pour 20 voulus : pas de remplissage partiel (réservé au QG)")
check(L0.F_norecipe_mode == Pr.MODE_SURVIE_PENURIE and L0.F_norecipe_pf and L0.F_norecipe_refill == 1,
  "sans recette de tourelle (ni au stock) : le péril ne prend pas le pas sur la production (survie-pénurie gardée), mais les tourelles posées se remplissent")
check(L0.D_same == 1, "peril = false : plan d'avant")
check(L0.G_census_fortify == 0 and L0.G_fresh_fortify == 1,
  "péril, 9 tourelles au recensement dont 4 au QG, fresh 0 : aucune pose au QG ; fresh 2 : la pose part (le groupe « hq » veut hq + fresh)")

---------------------------------------------------------------------------------------------------
section("5. La chaîne lue dans les sources : chaque maillon appelle la règle")
---------------------------------------------------------------------------------------------------
local src = {
  team = read_src("script/team/team.lua"), glue = read_src("script/team/survie_qg.lua"), planner = read_src("shared/team/planner.lua"),
  prio = read_src("shared/team/priorite.lua"), prev = read_src("script/ai3/prevision.lua"), pv = read_src("shared/ai3/prevision.lua"),
  capi = read_src("script/ai3/capitalisation.lua"), pteam = read_src("script/team/player_team.lua"),
}
local function has(s, pat) return s:find(pat, 1, true) ~= nil end
-- (X10-S0, 0.6.62 : l'appel passe par la portée fine du profileur, mesure seulement ; Profiler.fwrap rend la valeur de SurvieQg.update)
check(has(src.team, 'qg_peril = Profiler.fwrap("view:5-survieqg", SurvieQg.update, f, tick)'), "maillon 1 (vue) : Team.view publie view.qg_peril")
check(has(src.glue, "Sq.peril({") and has(src.glue, "Sq.threat(v.waves, tick)") and has(src.glue, "Prev.qg_view(f)") and has(src.glue, "[FO-SURVIE]"),
  "maillon 2 (glue) : la vue appelle Sq.peril avec la menace mémorisée et le recensement, et journalise [FO-SURVIE]")
check(has(src.prev, "Sq.armed_share(have, T.turret_ammo_low)") and has(src.prev, "e.get_inventory(defines.inventory.turret_ammo)"),
  "maillon 3 (prévision, script) : le dps d'une tourelle est pesé par ses chargeurs")
check(has(src.prev, "Pv.mem_floor(st.cal, \"qg\", tick)") and has(src.prev, "function Prev.qg_view(f)") and has(src.prev, "Pv.threat_waves(st.cal, \"qg\")"),
  "maillon 4 (prévision, script) : plancher durable du QG, vue de la mémoire des vagues")
check(has(src.planner, "local qg_peril = peril_seen and turret_ok") and has(src.planner, "peril = in_peril,") and has(src.planner, "Sq.floors(in_peril, T.defend_iron_floor, T.defend_copper_floor)"),
  "maillon 5 (planificateur) : le péril passe à Pr.decide et réduit les planchers")
check(has(src.planner, "if g.key == \"hq\" then groups[#groups + 1] = g end"), "maillon 5 ter (planificateur) : le groupe du QG est servi d'abord en péril")
check(has(src.planner, "qg_peril and math.max(dc.want, qwant) or dc.want") and has(src.planner, "local qwant = qp and (qp.hq_want or (view.hq_turrets or 0) + (qp.fresh or 0)) or 0") and has(src.planner, "Sq.refill_take(g.low, T.turret_ammo_target"),
  "maillon 5 bis (planificateur) : tourelles voulues au QG et remplissage partiel")
check(has(src.prio, "if a.peril and not a.survival then"), "maillon 6 (priorité) : Pr.decide force la défense d'abord")
check(has(src.capi, "Sv.capi(Survie.on(f) and not (view.qg_peril and view.qg_peril.peril)"), "maillon 7 (capitalisation) : le péril lève le mode survie de la capitalisation")
check(has(src.pteam, "Sq.chest_fate({") and has(src.pteam, "repose(f, e.tick)") and has(src.pteam, "[FO-SURVIE] player : coffre"),
  "maillon 8 (coffre) : la perte du coffre passe par Sq.chest_fate, repose, journalise")
check(has(src.pv, "remember(key, recv, \"vague\")") and has(src.pv, "remember(key, recv, \"rate\")"), "maillon 9 (calibration) : vagues prévues et ratées entrent dans la mémoire")
-- lot QGSURVIE
local build_src = read_src("script/team/build.lua")
check(has(src.team, "f.team.qg_reserve = Sq.qg_reserve({ floor = T.defend_iron_floor, turret_iron = rt[fe], mag_iron = rm[fe] })")
  and has(src.team, "if f.is_player and T.qg_reserve_on then"),
  "maillon 10 (vue, QGSURVIE) : la réserve du QG est calculée au livre de recettes, votre équipe seulement, sous interrupteur")
check(has(build_src, "local held = Sq.module_held({ iron = iron, reserve = f.team.qg_reserve, rebuild = false })")
  and has(build_src, "if qg_held(f, p, \"reserve\", tick) then") and has(build_src, "if qg_held(f, p, \"ligne\", tick) then")
  and has(build_src, "if not (T.qg_reserve_on and f.is_player and f.team and f.team.qg_reserve) then return false end"),
  "maillon 11 (chantiers, QGSURVIE) : la réserve d'un module neuf et l'agrandissement d'une ligne passent par Sq.module_held")
do -- la porte du QG vient AVANT celle de la pile (qui laisse passer un module qui produit une matière qui manque, le fer)
  local a = build_src:find("if qg_held(f, p, \"reserve\", tick) then", 1, true)
  local b = build_src:find("local ok, why = PileRt.porte(f, fam, p.spec.product)", 1, true)
  local c = build_src:find("local fam = pile_family(f, p)\n  if not fam then return false end\n  -- Lot QGSURVIE", 1, true)
  check(a and b and c and c < a and a < b, "maillon 11 bis (QGSURVIE) : la porte du QG suit pile_family (pas les reconstructions) et précède celle de la pile")
end
-- EFFONDREMENT (7/11) : la branche de la retenue écrit aussi le journal [FO-RECRUE] d'une recrue gratuite retenue (tests/spirale_test.lua).
check(has(src.team, "if f.is_player and T.qg_recruit_hold_on and SurvieQg.recruit_hold(f, tick, hq_threat) then\n    hold_recruits = true\n")
  and has(src.glue, "held = Sq.recruit_hold({ armed = v.qg.armed, threat = threat, workers = f.engineers_count })")
  and has(src.glue, "[FO-QGSURVIE]"),
  "maillon 12 (recrues, QGSURVIE) : la retenue passe par Sq.recruit_hold avec le recensement et la menace, view.hold_recruits, journal")
check(T.qg_reserve_on == false and T.qg_recruit_hold_on == true, "QGSURVIE : règle 1 éteinte par défaut (tour 1), règle 2 allumée")
check(has(src.team, "and not (f.is_player and T.qg_recruit_hold_on and f.team.s1 and f.team.s1.hold) then"),
  "maillon 12 bis (QGSURVIE) : la recrue SANS ARME de l'équipe vide est retenue aussi (chemin plan.recruit_unarmed)")

---------------------------------------------------------------------------------------------------
section("6. Mutants : chaque règle retirée change au moins un fait")
---------------------------------------------------------------------------------------------------
local base = {
  Sq = read_src("shared/team/survie_qg.lua"), Pr = read_src("shared/team/priorite.lua"), Pl = read_src("shared/team/planner.lua"),
  Pv = read_src("shared/ai3/prevision.lua"),
}
local function mutate(src_, old, new)
  local a, b = src_:find(old, 1, true)
  if not a then return nil end
  return src_:sub(1, a - 1) .. new .. src_:sub(b + 1)
end
local mutants = {
  -- règle pure
  { "armement proportionnel retiré", "Sq", "return math.floor(1000 * ammo / low)", "return 1000" },
  { "menace hors fenêtre comptée", "Sq", "if w.t and tick >= w.t and tick - w.t <= Sq.WINDOW then", "if w.t and tick >= w.t then" },
  { "vague hors fenêtre au bord exclue", "Sq", "tick - w.t <= Sq.WINDOW then", "tick - w.t < Sq.WINDOW then" },
  { "vague ailleurs comptée en entier", "Sq", "local other = math.floor(elsewhere * Sq.ELSEWHERE_PCT / 100)", "local other = elsewhere" },
  { "vague ailleurs ignorée", "Sq", "local other = math.floor(elsewhere * Sq.ELSEWHERE_PCT / 100)", "local other = 0" },
  { "vague future comptée", "Sq", "if w.t and tick >= w.t and", "if w.t and" },
  { "pas de seuil de menace", "Sq", "if threat < Sq.MIN_THREAT or value <= 0 then return out end", "if value <= 0 then return out end" },
  { "seuil de menace exclusif", "Sq", "if threat < Sq.MIN_THREAT or value <= 0 then return out end", "if threat <= Sq.MIN_THREAT or value <= 0 then return out end" },
  { "pas de marge sur la menace", "Sq", "local need = math.floor(threat * Sq.COVER_PCT / 100)", "local need = threat" },
  { "pas d'hystérésis", "Sq", "local limit = a.was and math.floor(need * Sq.EXIT_PCT / 100) or need", "local limit = need" },
  { "entrée à la cible incluse", "Sq", "if held >= limit then return out end", "if held > limit then return out end" },
  { "cause munitions jamais", "Sq", "out.cause = (turrets > armed and turrets * value >= need) and \"munitions\" or \"menace\"", "out.cause = \"menace\"" },
  { "cause munitions sans le nombre", "Sq", "(turrets > armed and turrets * value >= need)", "(turrets > armed)" },
  { "pas de plafond de tourelles", "Sq", "if cap > 0 and want > cap then", "if false then" },
  { "moins de tourelles que présentes", "Sq", "if want < turrets then want = turrets end", "" },
  { "armées au-delà des tourelles", "Sq", "if armed > turrets then armed = turrets end", "" },
  { "planchers non réduits en péril", "Sq", "  if peril then\n    return math.min(num(base_iron), Sq.FLOOR_IRON)", "  if false then\n    return math.min(num(base_iron), Sq.FLOOR_IRON)" },
  { "plancher réduit au-dessus de l'ordinaire", "Sq", "return math.min(num(base_iron), Sq.FLOOR_IRON), math.min(num(base_copper), Sq.FLOOR_COPPER), true", "return Sq.FLOOR_IRON, Sq.FLOOR_COPPER, true" },
  { "remplissage partiel jamais", "Sq", "if peril and stock >= low * Sq.REFILL_MIN then return stock end", "" },
  { "remplissage partiel sans minimum", "Sq", "if peril and stock >= low * Sq.REFILL_MIN then return stock end", "if peril and stock > 0 then return stock end" },
  { "remplissage partiel hors péril", "Sq", "if peril and stock >= low * Sq.REFILL_MIN then return stock end", "if stock >= low * Sq.REFILL_MIN then return stock end" },
  { "coffre retiré par le joueur reposé", "Sq", "if not a.killed then return \"fin\", \"retire par le joueur ou par script\" end", "" },
  { "coffre reposé sans PNJ", "Sq", "if num(a.workers) + num(a.soldiers) <= 0 then return \"fin\", \"aucun PNJ vivant\" end", "" },
  { "coffre reposé sans fin", "Sq", "if num(a.recent) >= Sq.CHEST_MAX then return \"fin\", \"trop de coffres perdus en peu de temps\" end", "" },
  { "soldats ignorés pour le coffre", "Sq", "if num(a.workers) + num(a.soldiers) <= 0 then", "if num(a.workers) <= 0 then" },
  -- lot QGSURVIE
  { "réserve sans le plancher", "Sq", "return ceil(num(a.floor) + Sq.RESERVE_TURRETS", "return ceil(0 + Sq.RESERVE_TURRETS" },
  { "réserve sans les chargeurs", "Sq", "(num(a.turret_iron) + Sq.RESERVE_MAGS * num(a.mag_iron))", "(num(a.turret_iron))" },
  { "réserve d'une seule tourelle", "Sq", "Sq.RESERVE_TURRETS = 2 ", "Sq.RESERVE_TURRETS = 1 " },
  { "réserve non arrondie", "Sq", "return ceil(num(a.floor) + Sq.RESERVE_TURRETS * (num(a.turret_iron) + Sq.RESERVE_MAGS * num(a.mag_iron)))",
    "return num(a.floor) + Sq.RESERVE_TURRETS * (num(a.turret_iron) + Sq.RESERVE_MAGS * num(a.mag_iron))" },
  { "module retenu à la réserve", "Sq", "return num(a.iron) < num(a.reserve)", "return num(a.iron) <= num(a.reserve)" },
  { "module jamais retenu", "Sq", "return num(a.iron) < num(a.reserve)", "return false" },
  { "reconstruction retenue", "Sq", "  if a.rebuild then return false end\n", "" },
  { "recrue retenue malgré une tourelle armée", "Sq", "if num(a.armed) > 0 or not a.threat then return false end", "if not a.threat then return false end" },
  { "recrue retenue sans attaque", "Sq", "if num(a.armed) > 0 or not a.threat then return false end", "if num(a.armed) > 0 then return false end" },
  { "recrue jamais retenue", "Sq", "then return false end\n  return true\nend", "then return false end\n  return false\nend" },
  { "équipe vide jamais retenue", "Sq", "then return false end\n  return true\nend", "then return false end\n  return (a.workers or 0) >= 1\nend" },
  -- priorité
  { "le péril ne force plus la défense", "Pr", "if a.peril and not a.survival then", "if false then" },
  { "le péril écrase la survie des effectifs", "Pr", "if a.peril and not a.survival then", "if a.peril then" },
  { "le péril met le pas de côté", "Pr", "    out.hold = 0\n    out.defense_budget = funds\n  end\n  return out", "    out.hold = math.min(funds, cp)\n    out.defense_budget = funds - out.hold\n  end\n  return out" },
  { "le péril garde production_first", "Pr", "    out.mode = Pr.MODE_QG_PERIL\n    out.production_first = false", "    out.mode = Pr.MODE_QG_PERIL\n    out.production_first = out.production_first" },
  -- planificateur
  { "le péril ne passe plus à la priorité", "Pl", "      peril = in_peril, -- lot S1", "      -- lot S1" },
  { "péril sans recette de tourelle", "Pl", "local qg_peril = peril_seen and turret_ok", "local qg_peril = peril_seen" },
  { "remplissage conditionné à la recette", "Pl", "  if peril_seen then" .. string.char(10) .. "    groups = {}", "  if in_peril then" .. string.char(10) .. "    groups = {}" },
  { "plancher du QG non réduit", "Pl", "if p.id == \"hq\" and (qg_peril or protect_any) then fi, fc, reduced = fl_i, fl_c, true end", "" },
  { "planchers ordinaires partout", "Pl", "local fl_i, fl_c = Sq.floors(in_peril, T.defend_iron_floor, T.defend_copper_floor)", "local fl_i, fl_c = T.defend_iron_floor, T.defend_copper_floor" },
  { "tourelles voulues du péril ignorées", "Pl", "want = qg_peril and math.max(dc.want, qwant) or dc.want", "want = dc.want" },
  { "groupe hq au recensement (défaut d'avant HQ-RECENSEMENT)", "Pl", "(qp.hq_want or (view.hq_turrets or 0) + (qp.fresh or 0))", "(qp.hq_want or qp.want)" },
  { "remplissage partiel retiré", "Pl", "local part = (g.key == \"hq\" and peril_seen) and Sq.refill_take", "local part = 0 and Sq.refill_take" },
  { "le QG en péril n'est pas servi d'abord", "Pl", "    for _, g in ipairs(view.turret_groups) do if g.key == \"hq\" then groups[#groups + 1] = g end end", "" },
  { "remplissage partiel pour tout groupe", "Pl", "local part = (g.key == \"hq\" and peril_seen) and Sq.refill_take", "local part = (peril_seen) and Sq.refill_take" },
  -- prévision
  { "k de nouveau plafonné à 4,00", "Pv", "Pv.K0, Pv.K_MIN, Pv.K_MAX = 1000, 50, 12000", "Pv.K0, Pv.K_MIN, Pv.K_MAX = 1000, 50, 4000" },
  { "le raté n'entre pas en mémoire", "Pv", "        remember(key, recv, \"rate\")\n", "" },
  { "la vague prévue n'entre pas en mémoire", "Pv", "        remember(key, recv, \"vague\")\n", "" },
  { "mémoire sans borne de nombre", "Pv", "while #w > Pv.MEM_MAX or (#w > 0 and tick - w[1].t > Pv.MEM_TICKS) do", "while (#w > 0 and tick - w[1].t > Pv.MEM_TICKS) do" },
  { "mémoire sans borne d'âge", "Pv", "while #w > Pv.MEM_MAX or (#w > 0 and tick - w[1].t > Pv.MEM_TICKS) do", "while #w > Pv.MEM_MAX do" },
  { "drapeau QG toujours vrai", "Pv", "out[#out + 1] = { t = w.t, pv = w.pv, hq = w.key == hq_key }", "out[#out + 1] = { t = w.t, pv = w.pv, hq = true }" },
  { "plancher durable hors fenêtre", "Pv", "if w.key == key and tick >= w.t and tick - w.t <= Pv.MEM_TICKS and (w.pv or 0) > best then best = w.pv end", "if w.key == key and (w.pv or 0) > best then best = w.pv end" },
  { "plancher durable de tout site", "Pv", "if w.key == key and tick >= w.t and", "if tick >= w.t and" },
}
local killed = 0
for _, mu in ipairs(mutants) do
  local txt = mutate(base[mu[2]], mu[3], mu[4])
  if not txt then
    check(false, "mutant « " .. mu[1] .. " » : le texte à muter existe encore")
  else
    local W = load_world({ [mu[2]] = txt })
    local fa, fb
    if mu[2] == "Sq" then fa, fb = F0, sq_facts(W.Sq)
    elseif mu[2] == "Pr" then fa, fb = R0, pr_facts(W.Pr)
    elseif mu[2] == "Pv" then fa, fb = P0, pv_facts(W.Pv)
    else fa, fb = L0, pl_facts(W.Pl, W.Pr) end
    local same = same_facts(fa, fb)
    if not same then killed = killed + 1 end
    check(not same, "mutant « " .. mu[1] .. " » détecté")
  end
end
print(string.format("[S1] mutants refusés : %d sur %d", killed, #mutants))
check(killed == #mutants, "tous les mutants sont refusés")

print(string.format("[S1] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
