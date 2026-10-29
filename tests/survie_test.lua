--[[
  Lot SURVIE-PENURIE (retours du DC du 29/10, RETOUR_DC_2 : « ils sont incapables d'avoir une option survivaliste où on se dépêche le
  plus possible, on prend des ressources à la main et on met des fours, on remet des foreuses à max » ; Ordre Écarlate encerclé de
  nids : « il manque 83 plaques de fer […] huit fours en réserve […] trop dangereux, ils font plus rien » ; « si on manque
  cruellement de ressources, l'objectif est ces ressources, pas la défense ») : banc HORS JEU. Lancement : lua5.2 tests/survie_test.lua
  (racine du mod).

    1. la règle pure (shared/team/survie.lua) : pénurie, paralysie, entrée, SORTIE PAR HYSTÉRÉSIS (un refus de la porte, une pensée
       sans manque, la fin de la paralysie ne font pas sortir), déterminisme ;
    2. les tâches : minage à la main (partage, minerai déjà au coffre), fours de réserve, agrandissement le plus proche et sûr ;
    3. la porte (shared/ai3/danger.lua, D.gate) : ce que le mode change, et surtout ce qu'il NE change PAS (but dangereux, chemin sans
       issue, 3 morts) ; équivalence exacte avec l'ancienne règle quand le mode est éteint (grille complète) ;
    4. la priorité (shared/team/priorite.lua et planner) : la production d'abord même quand le fer paie les deux ; la survie des
       effectifs garde la main ; sans le mode, plan d'avant ;
    5. la capitalisation : pas de part défense / armée, menace qui ne ferme plus les leviers, gisement dangereux toujours exclu ;
    6. la CHAÎNE lue dans les sources : chaque maillon (porte, tâche, vue, capitalisation) appelle bien la règle ;
    7. mutants : chaque règle retirée change au moins un fait observé.
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
  return s
end

local IRON, COPPER = T.outposts.iron.product, T.outposts.copper.product
local KEYS = {}
for _, kind in ipairs(T.OUTPOST_ORDER) do KEYS[T.outposts[kind].product] = true end

--- Charge les modules purs à partir de leurs sources (les mutants passent un texte modifié par module).
local function load_world(over)
  over = over or {}
  local names = { "shared.team.survie", "shared.ai3.danger", "shared.team.priorite", "shared.team.planner", "shared.ai3.capitalisation" }
  local saved = {}
  for _, n in ipairs(names) do saved[n] = package.loaded[n]; package.loaded[n] = nil end
  local W = {}
  local function mod(name, key)
    if over[key] then
      package.loaded[name] = assert(load(over[key], "@" .. name))()
    else
      package.loaded[name] = nil
      package.loaded[name] = require(name)
    end
    return package.loaded[name]
  end
  W.Sv = mod("shared.team.survie", "Sv")
  W.D = mod("shared.ai3.danger", "D")
  W.Pr = mod("shared.team.priorite", "Pr")
  W.Planner = mod("shared.team.planner", "Pl")
  W.Ca = mod("shared.ai3.capitalisation", "Ca")
  for _, n in ipairs(names) do package.loaded[n] = saved[n] end
  return W
end

local W0 = load_world()
local Sv, D, Pr, Planner, Ca = W0.Sv, W0.D, W0.Pr, W0.Planner, W0.Ca

--- Faits observés sur la règle pure (les mutants doivent en changer au moins un).
local function pure_facts(Sx)
  local f = {}
  local function d(st, tick, short, workers, idle, thr) return Sx.decide(st, { tick = tick, short = short, workers = workers, idle = idle, threatened = thr }) end
  local short = { { IRON, 83 } }
  -- F1 : manque 4 min seulement + paralysie : pas d'entrée ; 5 min : entrée.
  local st = Sx.new()
  for k = 1, 8 do Sx.note_wait(st, 100 + k) end
  d(st, 100, short, 8, 6)
  f.enter_4min = d(st, 100 + 4 * 3600, short, 8, 6).on
  f.enter_5min = d(st, 100 + 5 * 3600, short, 8, 6).on
  -- F2 : manque durable SANS paralysie (porte calme, PNJ occupés) : pas d'entrée.
  st = Sx.new()
  d(st, 0, short, 8, 1)
  f.enter_no_para = d(st, 6 * 3600, short, 8, 1).on
  -- F3 : paralysie SANS manque : pas d'entrée.
  st = Sx.new()
  for k = 1, 8 do Sx.note_wait(st, 6 * 3600 + k) end
  f.enter_no_short = d(st, 6 * 3600 + 20, {}, 8, 8).on
  -- F4 : menace seule (aucun refus), moitié des PNJ sans tâche : entrée.
  st = Sx.new()
  d(st, 0, short, 8, 4, true)
  f.enter_threat = d(st, 5 * 3600, short, 8, 4, true).on
  f.enter_threat_few = (function()
    local s2 = Sx.new()
    d(s2, 0, short, 8, 3, true)
    return d(s2, 5 * 3600, short, 8, 3, true).on
  end)()
  -- F5 : hystérésis : la pénurie s'interrompt 2 min, puis revient ; la paralysie finit ; un refus : le mode tient. Sortie à 5 min calmes.
  st = Sx.new()
  d(st, 10, short, 8, 6)
  for k = 1, 8 do Sx.note_wait(st, 5 * 3600 + k) end
  d(st, 5 * 3600 + 10, short, 8, 6)
  f.on_before = st.on
  f.stay_calm_2min = d(st, 5 * 3600 + 10 + 3600, {}, 8, 0).on             -- 1 min calme
  f.stay_blip = d(st, 5 * 3600 + 10 + 3 * 3600, {}, 8, 0).on             -- 3 min calmes
  d(st, 5 * 3600 + 10 + 3 * 3600 + 60, short, 8, 0)                      -- le manque revient : l'horloge du calme repart
  f.stay_after_blip = d(st, 5 * 3600 + 10 + 3 * 3600 + 120, {}, 8, 0).on
  local t0 = 5 * 3600 + 10 + 3 * 3600 + 120
  f.stay_4min = d(st, t0 + 4 * 3600, {}, 8, 0).on
  local ex = d(st, t0 + 5 * 3600, {}, 8, 0)
  f.exit_5min = ex.on == false and ex.event == "sortie"
  -- F6 : séjour minimal : pénurie finie tout de suite, sortie impossible avant Sv.MIN_ON même après 5 min de calme
  st = Sx.new()
  st.on, st.since, st.calm_since = true, 1000, -50000
  f.min_on = d(st, 1000 + Sx.MIN_ON - 1, {}, 8, 0).on
  f.min_on_out = d(st, 1000 + Sx.MIN_ON, {}, 8, 0).on
  -- F7 : un refus de la porte (ou 100) n'éteint rien
  st = Sx.new()
  st.on, st.since = true, 0
  for k = 1, 50 do Sx.note_wait(st, 40000 + k) end
  f.waits_keep_on = d(st, 40100, short, 8, 0).on
  -- F8 : les refus hors fenêtre ne comptent pas ; la fenêtre glisse
  st = Sx.new()
  for k = 1, 10 do Sx.note_wait(st, k) end
  f.waits_window_in = Sx.waits(st, 100)
  f.waits_window_out = Sx.waits(st, 100 + Sx.WINDOW)
  -- F9 : au plus WAITS_KEPT refus gardés
  st = Sx.new()
  for k = 1, 200 do Sx.note_wait(st, 1000 + k) end
  f.waits_cap = #st.waits
  -- F10 : le bilan périodique, une ligne toutes les Sv.BEAT
  st = Sx.new()
  st.on, st.since, st.beat = true, 0, 0
  f.beat_early = d(st, Sx.BEAT - 1, short, 8, 0).event
  f.beat_due = d(st, Sx.BEAT, short, 8, 0).event
  f.beat_again = d(st, Sx.BEAT + 1, short, 8, 0).event
  -- F11 : la cause écrite dit la matière et la raison
  st = Sx.new()
  d(st, 10, { { IRON, 83 } }, 8, 6)
  for k = 1, 8 do Sx.note_wait(st, 5 * 3600 + k) end
  local en = d(st, 5 * 3600 + 10, { { IRON, 83 } }, 8, 6)
  f.cause_item = en.cause ~= nil and en.cause:find(IRON .. " 83", 1, true) ~= nil
  f.cause_why = en.cause ~= nil and en.cause:find("porte", 1, true) ~= nil
  -- F12 : entrée enregistrée une fois
  f.entries = st.entries
  -- F13 : seules les matières clés comptent
  f.shortages_n = #Sx.shortages({ { "gun-turret", 2 }, { IRON, 5 } }, KEYS)
  return f
end

local function same_facts(a, b)
  for k, v in pairs(a) do if b[k] ~= v then return false, k end end
  for k, v in pairs(b) do if a[k] ~= v then return false, k end end
  return true
end

---------------------------------------------------------------------------------------------------
section("1. La règle pure : pénurie, paralysie, entrée, sortie par hystérésis")
---------------------------------------------------------------------------------------------------
local sh = Sv.shortages({ { IRON, 83 }, { "gun-turret", 2 }, { COPPER, 10 }, { IRON, 20 }, { "site:iron", 1 }, { T.outposts.coal.product, 0 } }, KEYS)
check(#sh == 2 and sh[1][1] == IRON and sh[1][2] == 83 and sh[2][1] == COPPER, "matières clés seules, le plus grand manque par matière, triées (n décroissant)")
check(#Sv.shortages({ { "gun-turret", 2 } }, KEYS) == 0 and #Sv.shortages(nil, KEYS) == 0, "rien de clé : aucun manque")
local tie = Sv.shortages({ { COPPER, 5 }, { IRON, 5 } }, KEYS)
check(tie[1][1] < tie[2][1], "égalité départagée par le nom (déterminisme)")

local st0 = Sv.new()
check(not Sv.paralysed(st0, { workers = 8, idle = 8 }, 0), "aucun refus, pas menacée : pas paralysée même avec 8 PNJ sans tâche")
for k = 1, Sv.PARA_WAITS - 1 do Sv.note_wait(st0, k) end
check(not Sv.paralysed(st0, { workers = 8, idle = 8 }, 10), "un refus de moins que le seuil : pas paralysée")
Sv.note_wait(st0, 10)
local p1, why1 = Sv.paralysed(st0, { workers = 8, idle = 3 }, 11)
check(p1 and why1 == "porte", "seuil de refus atteint + 3 PNJ sans tâche sur 8 (37 %) : paralysée par la porte")
check(not Sv.paralysed(st0, { workers = 8, idle = 2 }, 11), "25 % de PNJ sans tâche seulement : les PNJ travaillent, pas paralysée")
check(not Sv.paralysed(st0, { workers = 0, idle = 0 }, 11), "aucun PNJ : pas de paralysie")
local pt, wt = Sv.paralysed(Sv.new(), { workers = 8, idle = 4, threatened = true }, 0)
check(pt and wt == "menace", "menacée et la moitié des PNJ sans tâche : paralysée par la menace")
check(not Sv.paralysed(Sv.new(), { workers = 8, idle = 3, threatened = true }, 0), "menacée mais 3 PNJ sur 8 sans tâche : pas assez")

local facts = pure_facts(Sv)
check(facts.enter_4min == false and facts.enter_5min == true, "entrée : pas à 4 min de manque, oui à 5 min (manque DURABLE)")
check(facts.enter_no_para == false, "manque durable sans paralysie (PNJ occupés, porte calme) : jamais d'entrée")
check(facts.enter_no_short == false, "paralysie sans manque de matière clé : jamais d'entrée")
check(facts.enter_threat == true and facts.enter_threat_few == false, "entrée par la menace seule : 4 PNJ sur 8 sans tâche oui, 3 non")
check(facts.on_before == true, "mode allumé avant la série de pensées calmes")
check(facts.stay_calm_2min == true and facts.stay_blip == true, "HYSTÉRÉSIS : 1 min puis 3 min sans manque, le mode tient")
check(facts.stay_after_blip == true and facts.stay_4min == true, "le manque revient : l'horloge du calme repart de zéro (4 min calmes ne suffisent pas)")
check(facts.exit_5min == true, "sortie à 5 min calmes de suite, événement « sortie »")
check(facts.min_on == true and facts.min_on_out == false, "séjour minimal respecté (3 min), puis la sortie est possible")
check(facts.waits_keep_on == true, "50 refus de la porte n'éteignent pas le mode (seule la fin de la pénurie le fait)")
check(facts.waits_window_in == 10 and facts.waits_window_out == 0, "les refus hors fenêtre de 5 min ne comptent plus")
check(facts.waits_cap == Sv.WAITS_KEPT, "au plus " .. Sv.WAITS_KEPT .. " refus gardés (état borné)")
check(facts.beat_early == nil and facts.beat_due == "bilan" and facts.beat_again == nil, "bilan périodique : une ligne par tranche de 10 min")
check(facts.cause_item and facts.cause_why, "la cause écrite au journal nomme la matière, le manque et la raison")
check(facts.entries == 1, "une entrée comptée")
-- Déterminisme : deux passages identiques.
check(select(1, same_facts(pure_facts(Sv), facts)), "déterminisme : deux passages donnent les mêmes faits")
-- Grille : l'état ne contient que des nombres, booléens, chaînes et tables (sérialisable dans la sauvegarde).
do
  local function plain(v, depth)
    local t = type(v)
    if t == "number" or t == "string" or t == "boolean" or t == "nil" then return true end
    if t ~= "table" or depth > 4 then return false end
    for k, x in pairs(v) do if not plain(k, depth + 1) or not plain(x, depth + 1) then return false end end
    return true
  end
  local st = Sv.new()
  for k = 1, 8 do Sv.note_wait(st, k) end
  Sv.decide(st, { tick = 10, short = { { IRON, 5 } }, workers = 8, idle = 6 })
  Sv.decide(st, { tick = 5 * 3600 + 10, short = { { IRON, 5 } }, workers = 8, idle = 6 })
  check(plain(st, 0), "l'état (f.team.survie) n'a que des nombres, chaînes, booléens et tables")
end

---------------------------------------------------------------------------------------------------
section("2. Les tâches : minage à la main, fours de réserve, agrandissement")
---------------------------------------------------------------------------------------------------
local ORE_OF = {}
for _, kind in ipairs(T.OUTPOST_ORDER) do ORE_OF[T.outposts[kind].product] = T.outposts[kind].resource end
local IORE, CORE = T.outposts.iron.resource, T.outposts.copper.resource
local m = Sv.mines({ short = { { IRON, 83 } }, ore_of = ORE_OF, stock = {}, idle = 5, workers = 8, have = {} })
check(#m == 5 and m[1].ore == IORE and m[1].k == 1 and m[5].k == 5, "83 plaques de fer, 5 PNJ sans tâche : 5 minages à la main de minerai de fer")
check(m[1].count == Sv.MINE_MIN or (m[1].count >= Sv.MINE_MIN and m[1].count <= Sv.MINE_MAX), "quantité visée bornée (" .. m[1].count .. ")")
check(#Sv.mines({ short = { { IRON, 83 } }, ore_of = ORE_OF, stock = {}, idle = 50, workers = 50, have = {} }) == Sv.MINERS_MAX,
  "au plus " .. Sv.MINERS_MAX .. " minages à la fois")
check(#Sv.mines({ short = { { IRON, 83 } }, ore_of = ORE_OF, stock = {}, idle = 0, workers = 8, have = {} }) == 1,
  "aucun PNJ sans tâche à cet instant : un minage d'avance (le PNJ qui revient le prendra)")
check(#Sv.mines({ short = { { IRON, 83 } }, ore_of = ORE_OF, stock = { [IORE] = 90 }, idle = 5, workers = 8, have = {} }) == 0,
  "le minerai attend déjà au coffre (90 pour 83) : on ne mine pas, c'est la fonte")
check(#Sv.mines({ short = { { IRON, 83 } }, ore_of = ORE_OF, stock = { [IORE] = 20 }, idle = 5, workers = 8, have = {} }) == 5,
  "un peu de minerai au coffre ne couvre pas le manque : on mine")
check(#Sv.mines({ short = { { IRON, 83 } }, ore_of = ORE_OF, stock = {}, idle = 5, workers = 8, have = { [IORE] = 3 } }) == 2,
  "3 minages de fer déjà au tableau : 2 de plus seulement")
local m2 = Sv.mines({ short = { { IRON, 83 }, { COPPER, 40 } }, ore_of = ORE_OF, stock = {}, idle = 6, workers = 8, have = {} })
local by = {}
for _, x in ipairs(m2) do by[x.ore] = (by[x.ore] or 0) + 1 end
check(#m2 == 6 and by[IORE] == 3 and by[CORE] == 3, "deux matières en manque : les mineurs sont partagés")
check(#Sv.mines({ short = { { "gun-turret", 1 } }, ore_of = ORE_OF, stock = {}, idle = 5, workers = 8, have = {} }) == 0, "matière sans minerai : rien")
check(#Sv.mines({ short = {}, ore_of = ORE_OF, stock = {}, idle = 5, workers = 8, have = {} }) == 0, "aucun manque : aucun minage")

local function sm(over)
  local a = { short = { { IRON, 83 } }, smelts = { [IRON] = true, [COPPER] = true }, smelters = 2, pending = 0, stock_smelter = 8,
    stock_fuel = 100, fuel_per = 5 }
  for k, v in pairs(over or {}) do a[k] = v end
  return Sv.smelters(a)
end
check(sm() == 6, "2 fours posés, 8 en réserve au coffre, charbon pour 20 : 6 fours de plus (au plus " .. Sv.SMELTERS_MAX .. " en tout)")
check(sm({ smelters = 0, stock_smelter = 20 }) == Sv.SMELTERS_MAX, "au plus " .. Sv.SMELTERS_MAX .. " fours")
check(sm({ stock_fuel = 12 }) == 2, "le charbon limite (12 charbons : 2 fours à 5)")
check(sm({ stock_smelter = 0 }) == 0, "aucun four en réserve : rien (la fabrication est affaire du cerveau)")
check(sm({ pending = 3 }) == 3, "les fours déjà demandés comptent")
check(sm({ short = { { T.outposts.coal.product, 50 } } }) == 0, "le charbon ne passe pas au four : aucun four")

local function ex(over)
  local a = { short = { { IRON, 83 } }, kind_of = { [IRON] = "iron", [COPPER] = "copper" },
    outposts = { { id = 7, kind = "iron", drills = 8, full = false, d2 = 900, max = 20 }, { id = 3, kind = "iron", drills = 8, full = false, d2 = 90000, max = 20 },
      { id = 5, kind = "copper", drills = 3, full = false, d2 = 100, max = 12 } },
    lethal = {}, affordable = { iron = true, copper = true } }
  for k, v in pairs(over or {}) do a[k] = v end
  return Sv.extends(a)
end
local e1 = ex()
check(#e1 == 2 and e1[1].id == 7 and e1[2].id == 3, "fer en manque : les avant-postes de fer, le PLUS PROCHE d'abord (cuivre ignoré)")
check(#ex({ lethal = { [7] = true } }) == 1 and ex({ lethal = { [7] = true } })[1].id == 3, "un avant-poste meurtrier est écarté")
check(#ex({ affordable = { iron = false } }) == 0, "foreuses et fours absents du coffre : rien (le cerveau fabrique)")
local pl = ex({ outposts = { { id = 7, kind = "iron", drills = 20, full = false, d2 = 9, max = 20 }, { id = 3, kind = "iron", drills = 8, full = true, d2 = 9, max = 20 } } })
check(#pl == 0, "avant-poste plein ou au plafond de foreuses : rien")
check(#ex({ short = { { IRON, 5 }, { COPPER, 5 } } }) == 2 and ex({ short = { { IRON, 5 }, { COPPER, 5 } } })[1].kind == "iron", "au plus " .. Sv.EXTEND_MAX .. " agrandissements, la matière la plus en manque d'abord")

-- Sv.fresh : une tâche redemandée à chaque pensée (le tableau est refait) n'est comptée qu'une fois par série.
do
  local keys = {}
  check(Sv.fresh(keys, "a", 1000) == true, "première demande : nouvelle")
  check(Sv.fresh(keys, "a", 1300) == false and Sv.fresh(keys, "a", 1600) == false, "redemandée à chaque pensée (300 ticks) : pas recomptée")
  check(Sv.fresh(keys, "a", 1600 + Sv.REPEAT + 1) == true, "demandée de nouveau longtemps après : nouvelle série")
  Sv.fresh(keys, "b", 100)
  Sv.fresh(keys, "c", 100 + 3 * Sv.REPEAT)
  check(keys.b == nil and keys.c ~= nil, "les clés oubliées depuis plus de 2 × " .. Sv.REPEAT .. " ticks partent (état borné)")
end

---------------------------------------------------------------------------------------------------
section("3. La porte : ce que le mode change, et ce qu'il ne change pas")
---------------------------------------------------------------------------------------------------
local B = D.block(1086)
local function gate(info, ctx)
  local c = { B = B, prudence = 1086, escort_ok = false }
  for k, v in pairs(ctx or {}) do c[k] = v end
  return D.gate(info, c)
end
local marque = { blocked = false, max_d = B / 2 + 1, goal_d = 0, deaths = 0, far = false }
local d0, w0 = gate(marque)
check(d0 == "wait" and w0 == "marque", "témoin (prudence 1086, sans escorte, champ de danger moyen sur la route) : « Trop dangereux »")
local d1, w1 = gate(marque, { survie_deaths = Sv.DEATHS_WAIT })
check(d1 == "go" and w1 == "marque", "mode survie : la route qui croise un champ de danger moyen part")
check(gate(marque, { survie_deaths = Sv.DEATHS_WAIT, escort_ok = true }) == "escort", "mode survie, escorte libre : l'escorte reste préférée")
local two = { blocked = false, max_d = 0, goal_d = 0, deaths = 2, far = false }
check(select(1, gate(two)) == "wait" and select(2, gate(two)) == "morts", "témoin : 2 morts de l'heure sur la route : attente d'une heure")
check(select(1, gate(two, { survie_deaths = Sv.DEATHS_WAIT })) == "go", "mode survie : 2 morts sur la route ne bloquent plus")
local three = { blocked = false, max_d = 0, goal_d = 0, deaths = 3, far = false }
check(select(1, gate(three, { survie_deaths = Sv.DEATHS_WAIT })) == "wait" and select(2, gate(three, { survie_deaths = Sv.DEATHS_WAIT })) == "morts",
  "mode survie : 3 morts sur la route (danger immédiat) : on attend quand même")
local one = { blocked = false, max_d = 0, goal_d = 0, deaths = 1, far = false }
check(select(1, gate(one)) == "wait" and select(1, gate(one, { survie_deaths = Sv.DEATHS_WAIT })) == "go", "une mort sur la route : attente en temps normal, départ en survie")
local goal = { blocked = false, max_d = B, goal_d = B, deaths = 0, far = false }
check(select(1, gate(goal, { survie_deaths = Sv.DEATHS_WAIT })) == "wait" and select(2, gate(goal, { survie_deaths = Sv.DEATHS_WAIT })) == "but",
  "mode survie : un BUT à portée d'une menace reste refusé (« hors du danger immédiat »)")
local blocked = { blocked = true, max_d = B, goal_d = 0, deaths = 0, far = false }
check(select(1, gate(blocked, { survie_deaths = Sv.DEATHS_WAIT })) == "wait", "mode survie : un chemin sans issue reste refusé")
-- Équivalence exacte avec l'ancienne règle quand le mode est éteint (grille complète).
local function old_gate(info, ctx)
  local Bx = ctx.B or D.block(ctx.prudence)
  local esc = ctx.escort_ok and true or false
  if (info.deaths or 0) >= 2 then return "wait", "morts" end
  if info.blocked or (info.goal_d or 0) >= Bx or (info.deaths or 0) == 1 then
    if esc then return "escort", info.blocked and "bloque" or ((info.deaths or 0) == 1 and "mort" or "but") end
    return "wait", info.blocked and "bloque" or ((info.deaths or 0) == 1 and "mort" or "but")
  end
  if (info.max_d or 0) * 2 >= Bx then
    if esc then return "escort", "marque" end
    if (ctx.prudence or 1000) >= 1000 then return "wait", "marque" end
    return "go", "marque"
  end
  if info.far and esc then return "escort", "loin" end
  return "go", "sur"
end
local diff, n_grid = 0, 0
for _, blk in ipairs({ false, true }) do
  for _, md in ipairs({ 0, B / 2 - 1, B / 2, B }) do
    for _, gd in ipairs({ 0, B - 1, B }) do
      for _, dt in ipairs({ 0, 1, 2, 3, 5 }) do
        for _, far in ipairs({ false, true }) do
          for _, esc in ipairs({ false, true }) do
            for _, pr in ipairs({ 800, 1000, 1086 }) do
              n_grid = n_grid + 1
              local info = { blocked = blk, max_d = md, goal_d = gd, deaths = dt, far = far }
              local ctx = { B = B, prudence = pr, escort_ok = esc }
              local a1, a2 = D.gate(info, ctx)
              local b1, b2 = old_gate(info, ctx)
              if a1 ~= b1 or a2 ~= b2 then diff = diff + 1 end
            end
          end
        end
      end
    end
  end
end
check(diff == 0, string.format("mode éteint : D.gate identique à l'ancienne règle sur %d cas", n_grid))
-- Monotonie : le mode ne rend JAMAIS un départ plus dur qu'en temps normal.
local harder = 0
for _, blk in ipairs({ false, true }) do
  for _, md in ipairs({ 0, B / 2, B }) do
    for _, gd in ipairs({ 0, B }) do
      for _, dt in ipairs({ 0, 1, 2, 3, 5 }) do
        for _, esc in ipairs({ false, true }) do
          local info = { blocked = blk, max_d = md, goal_d = gd, deaths = dt, far = false }
          local a = D.gate(info, { B = B, prudence = 1086, escort_ok = esc })
          local b = D.gate(info, { B = B, prudence = 1086, escort_ok = esc, survie_deaths = Sv.DEATHS_WAIT })
          if a ~= "wait" and b == "wait" then harder = harder + 1 end
        end
      end
    end
  end
end
check(harder == 0, "le mode ne refuse jamais ce que la règle ordinaire accepte")
check(Sv.gate_deaths(true, "mine") == Sv.DEATHS_WAIT and Sv.gate_deaths(true, "extend") == Sv.DEATHS_WAIT
  and Sv.gate_deaths(true, "service") == Sv.DEATHS_WAIT and Sv.gate_deaths(true, "build") == Sv.DEATHS_WAIT, "tâches de ressources : porte assouplie")
check(Sv.gate_deaths(true, "fortify") == nil and Sv.gate_deaths(true, "garrison") == nil and Sv.gate_deaths(true, "refill") == nil
  and Sv.gate_deaths(true, "rebuild") == nil and Sv.gate_deaths(false, "mine") == nil, "défense, garde, reconstruction : porte ordinaire ; mode éteint : porte ordinaire")
check(Sv.escalade_w(4, true) == Sv.ESCALADE_W and Sv.escalade_w(4, false) == 4 and Sv.escalade_w(2, true) == 2, "escalade dès 2 refus en survie, jamais plus tard qu'avant")

---------------------------------------------------------------------------------------------------
section("4. La priorité : la production d'abord")
---------------------------------------------------------------------------------------------------
local both = Pr.decide({ funds = 500, defense_cost = 100, production_cost = 50 })
check(both.mode == Pr.MODE_DEFENSE_D_ABORD and not both.production_first, "témoin : le fer paie les deux, la défense d'abord")
local sv = Pr.decide({ funds = 500, defense_cost = 100, production_cost = 50, survie = true })
check(sv.mode == Pr.MODE_SURVIE_PENURIE and sv.production_first and sv.hold == 50 and sv.defense_budget == 450,
  "survie-pénurie, le fer paie les deux : la production d'abord, le pas (50) réservé, la défense a le reste")
local sv2 = Pr.decide({ funds = 30, defense_cost = 100, production_cost = 50, survie = true })
check(sv2.production_first and sv2.hold == 30 and sv2.defense_budget == 0, "manque cruel : tout le fer à la production, rien à la défense")
check(not Pr.decide({ funds = 500, defense_cost = 100, production_cost = nil, survie = true }).production_first,
  "aucun pas de production à faire : rien à prioriser (la défense comme avant)")
check(not Pr.decide({ funds = 5, defense_cost = 100, production_cost = 50, survie = true, survival = true }).production_first
  and Pr.decide({ funds = 5, defense_cost = 100, production_cost = 50, survie = true, survival = true }).mode == Pr.MODE_SURVIE,
  "équipe décimée (survie des effectifs) : les recrues gardent la main")
local bad = 0
for _, f in ipairs({ 0, 40, 150, 700 }) do
  for _, cd in ipairs({ 0, 90 }) do
    for _, cp in ipairs({ -1, 0, 50 }) do
      for _, sv_ in ipairs({ false, true }) do
        local a = Pr.decide({ funds = f, defense_cost = cd, production_cost = cp >= 0 and cp or nil })
        local b = Pr.decide({ funds = f, defense_cost = cd, production_cost = cp >= 0 and cp or nil, survie = sv_ })
        if not sv_ and (a.mode ~= b.mode or a.hold ~= b.hold or a.production_first ~= b.production_first) then bad = bad + 1 end
        if sv_ and cp >= 0 and not b.production_first then bad = bad + 1 end
        if b.hold + b.defense_budget ~= b.funds then bad = bad + 1 end
      end
    end
  end
end
check(bad == 0, "grille : `survie` faux = règle d'avant ; vrai avec un pas = production d'abord ; le fer se partage sans perte")

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
local function op(id, kind, drills, turrets)
  return { id = id, kind = kind, drills = drills, full = false, turrets = turrets or 0, coal_needed = 0, fuel_low = false, output = 0,
    idle_ticks = 0, has_task = true, has_fortify = false }
end
local outs = { op(1, "coal", 4, 1), op(2, "iron", 8, 1), op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
local kit = { ["burner-mining-drill"] = 20, ["stone-furnace"] = 20, ["iron-chest"] = 8 }
local rich = { [IRON] = 3000, [COPPER] = 1000, coal = 500, stone = 500, [T.turret_ammo] = 60, ["gun-turret"] = 4 }
for k, x in pairs(kit) do rich[k] = x end
local function plan(over) return Planner.plan(view(over), book) end
local function find(p, key) for _, t in ipairs(p.tasks) do if t.key == key then return t end end end
local pw = plan({ stock = rich, outposts = outs })
check(not pw.priorite.production_first and find(pw, "extend:2") == nil and find(pw, "fortify:2") ~= nil,
  "témoin riche, sans le mode : la défense d'abord (tourelle du fer, pas d'agrandissement avant elle)")
local ps = plan({ stock = rich, outposts = outs, survie = true })
check(ps.priorite.production_first and ps.priorite.mode == Pr.MODE_SURVIE_PENURIE, "riche MAIS en mode survie : la production d'abord")
check(find(ps, "extend:2") ~= nil, "mode survie : l'avant-poste de fer s'agrandit sans attendre sa tourelle")
local pd = plan({ stock = rich, outposts = outs, survie = true, workers = 3, recover_floor = 8 })
check(pd.priorite.mode == Pr.MODE_SURVIE and not pd.priorite.production_first, "mode survie ET équipe décimée : la survie des effectifs garde la main")
local pn = plan({ stock = rich, outposts = outs, survie = true, defend_first = false })
check(pn.priorite.mode == Pr.MODE_RIEN, "sans « défendre d'abord » : aucun effet (règle d'avant)")

---------------------------------------------------------------------------------------------------
section("5. La capitalisation : ni défense ni armée, menace qui ne ferme plus les leviers")
---------------------------------------------------------------------------------------------------
local th, pf = Sv.capi(false, true, false)
check(th == true and pf == false, "mode éteint, menacée : la menace est transmise telle quelle")
th, pf = Sv.capi(true, true, false)
check(th == false and pf == true, "mode survie : la menace ne ferme plus les leviers, production d'abord")
th, pf = Sv.capi(false, false, true)
check(th == false and pf == true, "mode éteint : le « production d'abord » du cerveau est transmis")
local ch_threat = Ca.character({}, {}, true, false)
local ch_survie = Ca.character({}, {}, false, true)
check(ch_threat.delta > 0 and ch_survie.delta == 0 and ch_survie.alpha == 0, "caractère : en survie, part défense et armée à zéro")
check(ch_survie.tmax > ch_threat.tmax, "caractère : en survie, le retour accepté n'est plus divisé par la menace")
local ctx_threat = { threat = true }
local ctx_survie = { threat = false }
check(Ca.usable(ctx_threat, {}, "couvrir") == "menace : leviers du QG seulement", "témoin : sous la menace, couvrir un gisement est refusé")
check(Ca.usable(ctx_survie, {}, "couvrir") == nil, "mode survie : couvrir un gisement SÛR est permis")
check(Ca.usable(ctx_survie, { danger = true }, "couvrir") == "danger", "mode survie : un gisement DANGEREUX reste exclu")
check(Ca.usable(ctx_survie, { blocked = "hors de portee" }, "ouvrir") == "hors de portee", "mode survie : un gisement interdit par l'exécutant reste exclu")

---------------------------------------------------------------------------------------------------
section("6. La chaîne lue dans les sources : chaque maillon appelle la règle")
---------------------------------------------------------------------------------------------------
local src = {
  team = read_src("script/team/team.lua"), comp = read_src("script/ai3/comportement.lua"), capi = read_src("script/ai3/capitalisation.lua"),
  worker = read_src("script/team/worker.lua"), glue = read_src("script/team/survie.lua"), planner = read_src("shared/team/planner.lua"),
  danger = read_src("shared/ai3/danger.lua"), pure = read_src("shared/team/survie.lua"), prio = read_src("shared/team/priorite.lua"),
}
local function has(s, pat) return s:find(pat, 1, true) ~= nil end
check(has(src.team, "Survie.think(f, view, plan, tick)"), "maillon 1 (pensée) : Team.think appelle Survie.think après la synchronisation du tableau")
check(has(src.team, "survie = Survie.on(f) or nil"), "maillon 2 (vue) : Team.view publie view.survie")
check(has(src.planner, "survie = view.survie"), "maillon 3 (priorité) : le planificateur passe view.survie à Pr.decide")
check(has(src.prio, "if a.survie and not a.survival and has_step then"), "maillon 3 bis : Pr.decide force la production d'abord")
check(has(src.comp, "Survie.gate_deaths(f, task.kind)") and has(src.comp, "survie_deaths = sv_deaths"), "maillon 4 (porte) : M.gate demande le seuil de morts du mode")
check(has(src.comp, "Survie.note_wait(f, tick)") and has(src.comp, "Survie.note_gate(f, tick, d0, w0, decision, why)"), "maillon 4 bis : la porte alimente la paralysie et le journal")
check(has(src.comp, "Sv.escalade_w("), "maillon 4 ter : l'escalade vient plus tôt")
check(has(src.danger, "local sv = ctx.survie_deaths"), "maillon 4 quater : D.gate lit survie_deaths")
check(has(src.capi, "Sv.capi(Survie.on(f)"), "maillon 5 (capitalisation) : build_input lit le mode")
check(has(src.glue, "Board.add(f, { t }, tick)") and has(src.glue, "\"survie:mine:\""), "maillon 6 (tâches) : Survie.think ajoute les tâches au tableau")
check(has(src.worker, "task.danger_radius or Worker.DANGER_RADIUS"), "maillon 7 (minage) : le minage de survie tolère un nid à 30 tuiles")
check(has(src.glue, "danger_radius = Sv.MINE_DANGER_RADIUS"), "maillon 7 bis : la tâche porte son rayon")
-- Journal : une ligne par cause.
for _, tag in ipairs({ "ENTREE en mode survie", "SORTIE du mode survie", "porte assouplie", "mode survie %s a %.1f min" }) do
  check(has(src.glue, tag), "journal [FO-SURVIE] : « " .. tag .. " »")
end
-- Aucun nom d'objet écrit dans la règle ni dans le module moteur (tout vient de T).
local names = { "iron%-plate", "copper%-plate", "iron%-ore", "stone%-furnace", "burner%-mining%-drill", "gun%-turret", "firearm" }
local named = {}
for _, n in ipairs(names) do
  for _, which in ipairs({ "pure", "glue" }) do
    -- les commentaires et les chaînes de journal sont ignorés
    local code = src[which]:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
    if code:find(n) then named[#named + 1] = which .. ":" .. n end
  end
end
check(#named == 0, "aucun nom d'objet du jeu dans la règle ni dans le module moteur" .. (#named > 0 and (" : " .. table.concat(named, ", ")) or ""))
-- Aucun `pairs` dont l'ordre décide : ceux de la règle et du module moteur construisent une liste puis la trient.
local function pairs_sorted(s)
  local bad_ = 0
  local pos = 1
  while true do
    local a = s:find("pairs%(", pos)
    if not a then break end
    local line_start = s:sub(1, a):match(".*()\n") or 1
    local line = s:sub(line_start, s:find("\n", a, true) or #s)
    if line:find("ipairs", 1, true) == nil and not line:find("^%s*%-%-") then
      -- doit être suivi d'un table.sort dans les 6 lignes suivantes, ou être un simple copiage dans une clé
      local tail = s:sub(a, a + 400)
      if not tail:find("table.sort", 1, true) then bad_ = bad_ + 1 end
    end
    pos = a + 6
  end
  return bad_
end
check(pairs_sorted(src.pure) == 0 and pairs_sorted(src.glue) == 0, "tout `pairs` de la règle et du module moteur est suivi d'un tri")
check(not src.pure:find("math.random", 1, true) and not src.glue:find("math.random", 1, true), "aucun hasard")
check(not src.glue:find("global%.") and not src.pure:find("global%."), "aucun accès à `global` hors de script/core/storage.lua")

---------------------------------------------------------------------------------------------------
section("7. Mutants : chaque règle retirée change au moins un fait")
---------------------------------------------------------------------------------------------------
local base_pure = read_src("shared/team/survie.lua")
local base_danger = read_src("shared/ai3/danger.lua")
local base_prio = read_src("shared/team/priorite.lua")
local mutants = {
  { "pas de durée minimale du manque", "Sv", "if #short > 0 and tick - st.short_since >= Sv.SHORT_TICKS and para then", "if #short > 0 and para then" },
  { "entrée sans paralysie", "Sv", "if #short > 0 and tick - st.short_since >= Sv.SHORT_TICKS and para then", "if #short > 0 and tick - st.short_since >= Sv.SHORT_TICKS then" },
  { "sortie sans hystérésis", "Sv", "if tick - st.since >= Sv.MIN_ON and st.calm_since and tick - st.calm_since >= Sv.EXIT_TICKS then", "if tick - st.since >= Sv.MIN_ON and st.calm_since then" },
  { "pas de séjour minimal", "Sv", "if tick - st.since >= Sv.MIN_ON and st.calm_since", "if st.calm_since" },
  { "le calme ne repart pas de zéro", "Sv", "    st.short_since = st.short_since or tick\n    st.calm_since = nil", "    st.short_since = st.short_since or tick" },
  { "un refus éteint le mode", "Sv", "    if tick - st.since >= Sv.MIN_ON", "    if Sv.waits(st, tick) > 0 or tick - st.since >= Sv.MIN_ON" },
  { "la paralysie qui finit éteint le mode", "Sv", "    if tick - st.since >= Sv.MIN_ON", "    if not para or tick - st.since >= Sv.MIN_ON" },
  { "la menace seule ne suffit plus", "Sv", "if a.threatened and idle * 100 >= workers * Sv.IDLE_PCT_THREAT then", "if false then" },
  { "les refus hors fenêtre comptent", "Sv", "if tick - t < Sv.WINDOW then n = n + 1 end", "n = n + 1" },
  { "refus gardés sans borne", "Sv", "while #w > Sv.WAITS_KEPT or (#w > 0 and tick - w[1] >= Sv.WINDOW) do", "while #w > 100000 do" },
  { "pas de bilan périodique", "Sv", "elseif tick - (st.beat or tick) >= Sv.BEAT then", "elseif false then" },
  { "matière hors clé comptée", "Sv", "if type(item) == \"string\" and keys[item] and n > 0 then", "if type(item) == \"string\" and n > 0 then" },
}
local obs_mut = {}
local function gate_facts(Dx, Svx)
  local f = {}
  f.marque = select(1, Dx.gate(marque, { B = B, prudence = 1086, escort_ok = false, survie_deaths = Svx.DEATHS_WAIT }))
  f.deux = select(1, Dx.gate(two, { B = B, prudence = 1086, escort_ok = false, survie_deaths = Svx.DEATHS_WAIT }))
  f.trois = select(1, Dx.gate(three, { B = B, prudence = 1086, escort_ok = false, survie_deaths = Svx.DEATHS_WAIT }))
  f.but = select(1, Dx.gate(goal, { B = B, prudence = 1086, escort_ok = false, survie_deaths = Svx.DEATHS_WAIT }))
  f.bloque = select(1, Dx.gate(blocked, { B = B, prudence = 1086, escort_ok = false, survie_deaths = Svx.DEATHS_WAIT }))
  f.une = select(1, Dx.gate(one, { B = B, prudence = 1086, escort_ok = false, survie_deaths = Svx.DEATHS_WAIT }))
  f.off = select(1, Dx.gate(marque, { B = B, prudence = 1086, escort_ok = false }))
  return f
end
local gf0 = gate_facts(D, Sv)
local killed = 0
local function mutate(src_, old, new)
  local a, b = src_:find(old, 1, true)
  if not a then return nil end
  return src_:sub(1, a - 1) .. new .. src_:sub(b + 1)
end
for _, mu in ipairs(mutants) do
  local txt = mutate(base_pure, mu[3], mu[4])
  if not txt then
    check(false, "mutant « " .. mu[1] .. " » : le texte à muter existe encore")
  else
    local W = load_world({ Sv = txt })
    local same = same_facts(facts, pure_facts(W.Sv))
    if not same then killed = killed + 1 end
    check(not same, "mutant « " .. mu[1] .. " » détecté")
  end
end
local gmut = {
  { "porte : les morts restent comptées en survie", "D", "if sv and deaths < sv then deaths = 0 end", "" },
  { "porte : la marque attend encore en survie", "D", "if (ctx.prudence or 1000) >= 1000 and not sv then", "if (ctx.prudence or 1000) >= 1000 then" },
  { "porte : un but dangereux n'est plus refusé en survie", "D", "if info.blocked or (info.goal_d or 0) >= B or deaths == 1 then", "if info.blocked or deaths == 1 then" },
  { "porte : toutes les morts sont ignorées en survie", "D", "if sv and deaths < sv then deaths = 0 end", "if sv then deaths = 0 end" },
}
for _, mu in ipairs(gmut) do
  local txt = mutate(base_danger, mu[3], mu[4])
  if not txt then
    check(false, "mutant « " .. mu[1] .. " » : le texte à muter existe encore")
  else
    local W = load_world({ D = txt })
    local g1 = gate_facts(W.D, Sv)
    local same = same_facts(gf0, g1)
    if not same then killed = killed + 1 end
    check(not same, "mutant « " .. mu[1] .. " » détecté")
  end
end
do
  local txt = mutate(base_prio, "if a.survie and not a.survival and has_step then", "if false then")
  local W = load_world({ Pr = txt })
  local r = W.Pr.decide({ funds = 500, defense_cost = 100, production_cost = 50, survie = true })
  local ok_ = not r.production_first
  if ok_ then killed = killed + 1 end
  check(ok_, "mutant « priorité : la survie-pénurie ne force plus la production » détecté")
  local txt2 = mutate(base_prio, "if a.survie and not a.survival and has_step then", "if a.survie and has_step then")
  local W2 = load_world({ Pr = txt2 })
  local r2 = W2.Pr.decide({ funds = 5, defense_cost = 100, production_cost = 50, survie = true, survival = true })
  local ok2 = r2.production_first
  if ok2 then killed = killed + 1 end
  check(ok2, "mutant « priorité : la survie des effectifs ne garde plus la main » détecté")
end
local total_mut = #mutants + #gmut + 2
print(string.format("[SURVIE] mutants refusés : %d sur %d", killed, total_mut))
check(killed == total_mut, "tous les mutants sont refusés")

print(string.format("[SURVIE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
