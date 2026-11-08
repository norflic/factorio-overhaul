--[[
  Lot DEPENSES2, revue D1 (BLOQUANT : cliquet des laboratoires) : la règle du stock qui dort BRANCHÉE, au moteur simulé
  (tests/mock_engine.lua). Ce n'est pas une preuve en jeu.
    §1 une faction au coffre plein (30 000 fer, 30 000 cuivre, 60 laboratoires au coffre) : la règle s'endort ([FO-DEPENSES] « dort »),
       journal [FO-DEPENSES] à chaque cycle de capitalisation (la règle est jouée à la décision, une par cycle de Capi.CYCLE pensées).
       Lot X10-S10 (décision du DC du 7/11, 17 h 47, QCM-7/11-X10, OBJECTIFS §4 : « Oui, factions lointaines plus lentes
       (Recommandé) ») : dans ce §1, le joueur reste LOIN de la faction (moteur simulé : joueur au départ, faction à 320 tuiles), qui
       pense toutes les Cd.SLOW = 600 ticks quand elle est calme : une ligne par cycle, au moins 8 en 16 min (9 mesurées) ; §1 bis, même partie, joueur PRÈS de la faction : une ligne par minute, attendu d'avant S10 (au moins 10) ;
       la cible de laboratoires se fige, les laboratoires posés ne dépassent jamais le plafond (Br.labs_max + Dep.LABS_MAX) et ne
       bougent plus sur les 4 dernières minutes, même pensée après pensée (research_step tourne à chaque pensée) ;
    §2 TÉMOIN DU DÉFAUT : la cible relative d'avant (« présents + n », commit ddd82445) remise à la main : les laboratoires dépassent
       le plafond (le banc voit le cliquet) ;
    §3 armement (revues D3, E1, E2) : la cible d'armée de la faction est relevée de 6 au plus au-dessus de celle du cerveau, jamais au-delà
       du plafond de soldats, des recrues arrivent au-dessus de la cible du cerveau ; la capitalisation reçoit un stock hors besoin débité
       de l'engagé (laboratoires à faire, soldats AU-DESSUS de la cible du cerveau) ;
    §4 interrupteur f.team.depenses.on = false : aucune ligne ;
    §5 essai 3 : CENTRE EN ATTENTE DE CIRCUITS (but courant de l'amélioration, coût impayable) : 0 laboratoire de plus ; §5b (essai 4) :
       centre en attente de briques : 0 laboratoire, les soldats passent ;
       journal « CENTRE EN ATTENTE » ; son mutant (la garde ignorée) pose des laboratoires ;
    §7 siège du complément (essai 4 c, relecture point 4) : le fer dort, le cuivre non, deux modules en attente tiennent les emplacements :
       chemin de jeu Capi.slots → Dep.sleeping → Em.slots (1 siège réservé au cuivre, journal), décisions Em.drill_refused et
       Em.order_seat sur ce relevé ; mutant (relevé vide) : aucun siège ;
    §6 interface du périmètre (PERIMETRE2, 5/11) : table créée par le périmètre gardée, accord sur sa demande, etat actif / perime /
       eteint, Dep.debit au plus l'accord, débité aussi de la réserve, compte remis à zéro au nouvel accord.
  Usage : lua5.2 tests/depenses2_moteur_test.lua   (depuis la racine du mod ; quelques minutes)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[DEPENSES2-MOTEUR] ECHEC : " .. msg) end
end
local function say(s) print("[DEPENSES2-MOTEUR] " .. s) end
local function W() return M.world() end
local MIN = 3600

local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for _, c in ipairs({ { 1, 0 }, { -1, 0 } }) do
    for i = 0, 11 do
      out[#out + 1] = { x = c[1] * 320 + math.cos(i * math.pi / 6) * 60, y = math.sin(i * math.pi / 6) * 60, name = names[i % 4 + 1] }
    end
  end
  return out
end

local function labs_of(f)
  local n = 0
  for _, e in ipairs((f.team.ia3 and f.team.ia3.labs) or {}) do if e.valid then n = n + 1 end end
  return n
end

local function run(opts)
  M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
  M.load_mod()
  M.dispatch(W().on_init)
  M.command("fo-war", "start 2 30 30 320")
  -- Lot X10-S10 : joueur posé à 30 tuiles du QG de la faction (§1 bis : rythme normal) ; sinon il reste au départ, loin d'elle.
  local f1 = global.fo.war.factions[1]
  if opts.near and f1 and f1.hq_pos then W().player.character.teleport({ x = f1.hq_pos.x + 30, y = f1.hq_pos.y }) end
  M.run_ticks(MIN)
  local f = global.fo.war.factions[1]
  local Stock = require("script.team.stock")
  local Dep = require("script.ai3.depenses")
  if opts.off then
    f.team.depenses = { on = false }
  end
  if opts.want then -- §6 : le périmètre crée la table et écrit sa demande avant la première pensée de la règle
    f.team.depenses = { defense_want = opts.want }
  end
  if opts.centre then
    -- §5 : le centre est le but courant de l'amélioration et attend des circuits (coût impayable : il reste en attente).
    f.team.capital = f.team.capital or {}
    local c = f.team.capital
    local cost = { { opts.centre_item or "electronic-circuit", 1000000 } }
    c.current = { key = "command:2:banc", id = 0, family = "command", center = true, cost = cost, value = 50, work = 0, score = 1 }
    c.goal = { key = "capital:command:2:banc", family = "capital", kind = "upgrade", target = "command:2:banc", value = 50, center = true,
      fond = true, cost = cost }
    c.scan_n = 1e9
  end
  if opts.ignore_hold then Dep.centre_waiting = function() return false end end -- mutant de §5
  if opts.fake_mods then
    -- §7 : deux modules qui attendent leur matière tiennent les 2 emplacements (le moteur simulé n'a pas de foreuse électrique de
    -- l'exécutant : « foreuse electrique de l'executant nil », aucun module réel ne s'ouvre)
    local Em = require("shared.ai3.emplacements")
    local o_slots = Em.slots
    Em.slots = function(sl)
      if sl and sl.mods then
        local mods = {}
        for _, m in ipairs(sl.mods) do mods[#mods + 1] = m end
        for i = 1, 2 do mods[#mods + 1] = { key = "attente" .. i, states = { "attente" }, opened = 0 } end
        sl.mods = mods
      end
      local out = o_slots(sl)
      if out.comp and not opts.comp_slots then opts.comp_slots, opts.comp_sleeping = out, sl and sl.sleeping end -- (premier relevé avec le siège : il dépend du sommeil du moment)
      if not opts.any_slots then opts.any_slots = out end
      return out
    end
    -- Lot ROUGES-0659 : la prémisse « le cuivre ne dort pas » est POSÉE : le cuivre est retiré du relevé RÉEL de Dep.sleeping, le fer y
    -- reste tel que la règle le dit. Depuis 4c92c34d (lot COLLECTE, rappel d'un PNJ occupé pour une tâche urgente, voulu), l'économie
    -- du moteur simulé a changé : les plaques de cuivre « dorment » dès la minute 7, AVANT le fer au premier relevé avec un siège, et le
    -- siège allait au fer (4 ECHEC de 0.6.60 à 0.6.63). Avant 4c92c34d, le cuivre dormait aussi, mais après le fer (minute 8).
    local o_sleep = Dep.sleeping
    Dep.sleeping = function(ff, t)
      local s = o_sleep(ff, t)
      s["copper-plate"] = nil
      return s
    end
  end
  if opts.no_sleep then Dep.sleeping = function() return {} end end -- mutant de §7
  local spy = { calls = 0, raise = 0, over_max = 0, above_brain = 0, brain = nil }
  local o_st = Dep.soldiers_target
  Dep.soldiers_target = function(ff, army, max, now, tick, key, key_short, cost)
    local t = o_st(ff, army, max, now, tick, key, key_short, cost)
    if ff == f then
      spy.calls = spy.calls + 1
      if t - army > spy.raise then spy.raise = t - army end
      if t > (max or 0) and t > army then spy.over_max = spy.over_max + 1 end
      if t > army then spy.brain = army end
      if spy.brain and (f.soldiers_count or 0) - spy.brain > spy.above_brain then spy.above_brain = (f.soldiers_count or 0) - spy.brain end
    end
    return t
  end
  if opts.relative then
    -- TÉMOIN DU DÉFAUT D1 : la cible relative d'avant (présents + n, sans plafond ni base).
    Dep.labs_target = function(ff, now, cap, tick)
      local r = ff.team.depenses and ff.team.depenses.res
      if not (r and (r.labs or 0) > 0) then return nil end
      return now + r.labs
    end
  end
  for _, it in ipairs(opts.stock or { { "iron-plate", 30000 }, { "copper-plate", 30000 }, { "lab", 60 } }) do Stock.insert(f, it[1], it[2]) end
  local log0 = #W().logs -- (les lignes de la première minute, avant l'interrupteur, ne comptent pas)
  local dec0 = (f.team.capi and f.team.capi.decisions) or 0 -- lot X10-S10 : décisions de capitalisation de la fenêtre
  local series, reserve_seen = {}, nil
  for m = 1, opts.minutes do
    M.run_ticks(MIN)
    series[m] = labs_of(f)
    if not reserve_seen and f.team.depenses and f.team.depenses.lab_target then
      local held = Dep.reserved(f, game.tick)
      local tot = 0
      for _, v in pairs(held) do tot = tot + v end
      reserve_seen = tot
    end
  end
  local lines = {}
  for i = log0 + 1, #W().logs do
    local l = W().logs[i]
    if l:find("[FO-DEPENSES] " .. tostring(f.key), 1, true) then lines[#lines + 1] = l end
  end
  local Br = require("shared.ai3.bras")
  local Ia3 = require("script.ai3.cerveau")
  local cap = Br.labs_max(f.engineers_count or 0, Ia3.LABS_MAX, 6) + Dep.LABS_MAX -- (6 : plafond haut du bonus des bras libres, Dm.CAP_EXTRA_MAX)
  local lente = false
  for i = 1, #W().logs do
    if W().logs[i]:find("[FO-CADENCE] " .. tostring(f.key) .. " : cadence LENTE", 1, true) then lente = true end
  end
  return { f = f, series = series, lines = lines, cap = cap, reserve = reserve_seen, d = f.team.depenses, spy = spy,
    decisions = ((f.team.capi and f.team.capi.decisions) or 0) - dec0, lente = lente }
end

local MINUTES = 16
say("§1 regle allumee")
local a = run({ minutes = MINUTES })
local sleeping = 0
for _, l in ipairs(a.lines) do if l:find(" dort ", 1, true) then sleeping = sleeping + 1 end end
-- Lot X10-S10 : la faction du §1 est LOINTAINE et calme (décision du DC citée en tête) : une ligne par cycle de capitalisation, chaque
-- décision écrite (Dep.think est joué à la décision). Seuil 8 cycles en 16 min, juste sous le mesuré (décision du lead du 8/11, sur la
-- note de revue-s : 10 × 300 / 600 = 5 était trop lâche) : 9 lignes pour 9 décisions mesurées (16 pour la faction proche du §1 bis).
local Cd = require("shared.faction.cadence")
check(a.lente, "§1 la faction, loin du joueur, est passee en cadence lente")
say(string.format("§1 faction lointaine : %d ligne(s) [FO-DEPENSES], %d decision(s) en %d min", #a.lines, a.decisions, MINUTES))
local FAR_MIN = 8
check(#a.lines >= a.decisions and a.decisions >= FAR_MIN,
  string.format("§1 faction lointaine et calme (cadence %d ticks) : journal [FO-DEPENSES] a chaque cycle de capitalisation (%d lignes, %d decisions, au moins %d, 9 mesurees)",
    Cd.SLOW, #a.lines, a.decisions, FAR_MIN))
check(sleeping >= 3, "§1 le stock s'endort (" .. sleeping .. " ligne(s) « dort »)")
local maxl, last = 0, a.series[MINUTES]
for m = 1, MINUTES do if a.series[m] > maxl then maxl = a.series[m] end end
say("§1 laboratoires par minute : " .. table.concat(a.series, " ") .. " ; plafond " .. a.cap .. " ; base " .. tostring(a.d.lab_base)
  .. " cible " .. tostring(a.d.lab_target))
check(maxl <= a.cap, "§1 jamais au-delà du plafond (" .. maxl .. " <= " .. a.cap .. ")")
check(a.series[MINUTES - 4] == last, "§1 plus aucun laboratoire posé sur les 4 dernières minutes (" .. a.series[MINUTES - 4] .. " -> " .. last .. ")")
check(a.d.lab_target ~= nil and last <= a.d.lab_target, "§1 posés <= cible absolue (" .. last .. " <= " .. tostring(a.d.lab_target) .. ")")
check(last > a.series[1], "§1 la recherche a reçu des laboratoires de plus (" .. a.series[1] .. " -> " .. last .. ")")
say(string.format("§3 armement : appels %d, relevement max %d, au-dela du plafond %d, recrues au-dessus de la cible du cerveau %d",
  a.spy.calls, a.spy.raise, a.spy.over_max, a.spy.above_brain))
check(a.spy.raise >= 1 and a.spy.raise <= 6, "§3 cible d'armée relevée de 1 à 6 au-dessus de celle du cerveau (" .. a.spy.raise .. ")")
check(a.spy.over_max == 0, "§3 jamais au-delà du plafond de soldats")
check(a.spy.above_brain >= 1, "§3 des recrues arrivent au-dessus de la cible du cerveau (" .. a.spy.above_brain .. ")")
do -- §3 débit : 2 laboratoires encore à faire et 6 soldats au-dessus de la cible du cerveau (tous ceux du cerveau présents)
  -- Intégration 0.6.53 (essai-0653) : l'état « centre en attente » (d.res.hold) de la 16e minute dépend du moment où la faction choisit son
  -- centre (AGEBLOCAGE étage 3, d87b9768 : le centre passé devant y reste jusqu'à 15 min ; moteur simulé : centre en attente de la minute 4
  -- à la fin, laboratoires 1 -> 5 dès la minute 9 contre 12 avant). Le débit attendu en dépend (essai 4 (a) : centre en attente, aucun
  -- laboratoire débité). Le contrôle pose donc lui-même les DEUX états au lieu de lire celui du moment : hors attente, 2 laboratoires
  -- (120) + 6 soldats ; en attente, les 6 soldats seuls, exactement 120 de moins.
  local Rsv, Dep, Dp = require("script.ai3.reserve"), require("script.ai3.depenses"), require("shared.ai3.depenses")
  local d = a.d
  local save = { d.lab_now, d.soldier_target, d.soldier_brain, d.soldier_now, d.soldier_key, d.res.hold }
  d.lab_now = (d.lab_target or 2) - 2
  d.soldier_brain, d.soldier_target, d.soldier_now, d.soldier_key = 18, 24, 18, "iron-plate"
  local function sum(t) local n = 0 for _, v in pairs((t and t.free) or {}) do n = n + v end return n end
  local cfe = (d.soldier_cost or {})["iron-plate"] or 0
  local ccu = (d.soldier_cost or {})["copper-plate"] or 0
  say(string.format("§3 cout d'un soldat (equipement au livre de recettes) : %.0f fer, %.0f cuivre", cfe, ccu))
  check(cfe > 0 and ccu > 0, "§3 coût d'un soldat calculé depuis son équipement (fer et cuivre ; relecture, point 2)")
  local got = {}
  for _, hold in ipairs({ false, true }) do
    d.res.hold = hold
    local rin = Rsv.input(a.f, game.tick)
    local before = sum(rin)
    local out = Dep.capi_reserve(a.f, rin, game.tick)
    local held = Dp.reserved(d.res, d.lab_target, d.lab_now, 24, 18, 18, "iron-plate", d.spent, d.soldier_cost)
    local want = 0
    for _, v in pairs(held) do want = want + v end
    got[hold] = want
    local labs = hold and 0 or 120
    check(rin ~= nil and math.abs((before - sum(out)) - want) < 1e-6 and want >= labs + 6 * (cfe + ccu) - 1e-6,
      "§3 stock hors besoin de la capitalisation débité de l'engagé" .. (hold and ", centre en attente : les 6 soldats seuls" or
        " : 2 laboratoires (120) + 6 soldats") .. " au-dessus du cerveau au coût de leur équipement, défense comprise ("
      .. string.format("%.1f", before - sum(out)) .. " = " .. string.format("%.1f", want) .. ")")
    check(sum(rin) == before, "§3 l'entrée d'origine n'est pas modifiée (copie)")
  end
  check(math.abs(got[false] - got[true] - 120) < 1e-6,
    string.format("§3 centre en attente : les 2 laboratoires (120) ne sont plus débités, les soldats si (%.1f -> %.1f)", got[false], got[true]))
  d.lab_now, d.soldier_target, d.soldier_brain, d.soldier_now, d.soldier_key, d.res.hold = save[1], save[2], save[3], save[4], save[5], save[6]
end

say("§1 bis joueur pres de la faction (rythme normal)")
do
  local n = run({ minutes = MINUTES, near = true })
  check(not n.lente, "§1 bis joueur pres de la faction : jamais en cadence lente")
  say(string.format("§1 bis faction proche : %d ligne(s) [FO-DEPENSES], %d decision(s) en %d min", #n.lines, n.decisions, MINUTES))
  check(#n.lines >= 10, "§1 bis journal [FO-DEPENSES] chaque minute (" .. #n.lines .. ", attendu d'avant S10)")
end

say("§2 temoin du defaut (cible relative d'avant)")
local b = run({ minutes = MINUTES, relative = true })
local maxb = 0
for m = 1, MINUTES do if b.series[m] > maxb then maxb = b.series[m] end end
say("§2 laboratoires par minute : " .. table.concat(b.series, " "))
check(maxb > a.cap, "§2 le banc voit le cliquet : la cible relative dépasse le plafond (" .. maxb .. " > " .. a.cap .. ")")

say("§4 interrupteur eteint")
local c = run({ minutes = 8, off = true })
check(#c.lines == 0, "§4 éteint : aucune ligne [FO-DEPENSES] (" .. #c.lines .. ")")

say("§5 centre en attente de circuits")
local e = run({ minutes = 10, centre = true })
local held_lines = 0
for _, l in ipairs(e.lines) do if l:find("CENTRE EN ATTENTE", 1, true) then held_lines = held_lines + 1 end end
local maxe = 0
for m = 1, 10 do if e.series[m] > maxe then maxe = e.series[m] end end
say("§5 laboratoires par minute : " .. table.concat(e.series, " ") .. " ; lignes « centre en attente » " .. held_lines)
check(held_lines >= 5, "§5 journal : centre en attente (" .. held_lines .. ")")
check(maxe <= e.series[1], "§5 centre en attente : 0 laboratoire de plus (" .. e.series[1] .. " -> " .. maxe .. ")")
-- (un centre qui attend 1 000 000 de circuits rend le fer « court » au cerveau : garde E4, aucun soldat ; les soldats se contrôlent en §5b)
say("§5b centre en attente de briques (le fer ne manque pas)")
local eb = run({ minutes = 10, centre = true, centre_item = "stone-brick" })
local maxeb = 0
for m = 1, 10 do if eb.series[m] > maxeb then maxeb = eb.series[m] end end
say("§5b laboratoires par minute : " .. table.concat(eb.series, " ") .. " ; soldats relevés de " .. eb.spy.raise)
check(maxeb <= eb.series[1], "§5b centre en attente : 0 laboratoire de plus (" .. eb.series[1] .. " -> " .. maxeb .. ")")
check(eb.spy.raise >= 1 and eb.spy.raise <= 6 and eb.spy.over_max == 0,
  "§5b centre en attente : les soldats passent, 1 à 6 de plus, jamais au-delà du plafond (essai 4 ; " .. eb.spy.raise .. ")")
say("§5 mutant : la garde du centre ignoree")
local g = run({ minutes = 10, centre = true, ignore_hold = true })
local maxg = 0
for m = 1, 10 do if g.series[m] > maxg then maxg = g.series[m] end end
say("§5 mutant : laboratoires par minute : " .. table.concat(g.series, " "))
check(maxg > g.series[1], "§5 mutant détecté : sans la garde, des laboratoires sont posés malgré le centre (" .. g.series[1] .. " -> " .. maxg .. ")")

say("§6 interface du perimetre : accord, etat, debit")
do
  local Dep = require("script.ai3.depenses")
  local h = run({ minutes = 8, want = { ["iron-plate"] = 1200 } })
  local d, t = h.d, game.tick
  local acc, info = Dep.defense(h.f, t)
  check(info.etat == "actif" and info.tick == d.res_tick, "§6 accord actif, avec le tick de l'accord (" .. tostring(info.etat) .. ")")
  local g0 = acc["iron-plate"] or 0
  check(g0 == 1200, "§6 table créée par le périmètre gardée : fer accordé sur sa demande (" .. g0 .. ")")
  local function held() return Dep.reserved(h.f, t)["iron-plate"] or 0 end
  local r0 = held()
  check(Dep.debit(h.f, "defense", "iron-plate", 120) == 120, "§6 débit d'une tourelle : 120")
  check(Dep.defense(h.f, t)["iron-plate"] == g0 - 120, "§6 accord rendu débité (" .. tostring(Dep.defense(h.f, t)["iron-plate"]) .. ")")
  check(math.abs((r0 - held()) - 120) < 1e-6, "§6 la réserve de la capitalisation ne retient plus les 120 posés (" .. (r0 - held()) .. ")")
  check(Dep.debit(h.f, "defense", "iron-plate", 1e9) == g0 - 120 and (Dep.defense(h.f, t)["iron-plate"] or 0) == 0,
    "§6 jamais au-delà de l'accord")
  check(Dep.debit(h.f, "autre", "iron-plate", 10) == 0, "§6 autre dépense que la défense : 0")
  M.run_ticks(MIN)
  local acc2, info2 = Dep.defense(h.f, game.tick)
  check(info2.etat == "actif" and info2.tick > info.tick and (acc2["iron-plate"] or 0) > 0 and next(d.spent) == nil,
    "§6 nouvel accord à la minute suivante : compte remis à zéro (" .. tostring(acc2["iron-plate"]) .. ")")
  local _, info3 = Dep.defense(h.f, game.tick + Dep.FRESH + 1)
  check(info3.etat == "perime", "§6 accord périmé après 3 min sans relevé (" .. tostring(info3.etat) .. ")")
  local _, info5 = Dep.defense({ team = {} }, game.tick)
  check(info5.etat == "perime" and info5.tick == nil, "§6 équipe sans règle : perime, sans tick")
  d.on = false
  local acc4, info4 = Dep.defense(h.f, game.tick)
  check(info4.etat == "eteint" and next(acc4) == nil and Dep.debit(h.f, "defense", "iron-plate", 10) == 0,
    "§6 interrupteur : eteint, rien accordé ni débité")
  d.on = nil
end

say("§7 siege du complement : le fer dort, le cuivre non, emplacements pleins")
local function comp_case(opts)
  local r = run(opts)
  local Em = require("shared.ai3.emplacements")
  local sl = opts.comp_slots or (r.f.team.capi and r.f.team.capi.slots)
  local seen = 0
  for _, l in ipairs(W().logs) do
    if l:find("[FO-CAPI-EMPLACEMENTS] " .. tostring(r.f.key), 1, true) and l:find("complement du stock qui dort (copper-plate)", 1, true) then seen = seen + 1 end
  end
  return r, sl, seen, Em
end
local CU = { { "iron-plate", 30000 }, { "copper-plate", 100 } }
local o7 = { minutes = 10, fake_mods = true, stock = CU }
local h7, sl7, seen7, Em7 = comp_case(o7)
say("§7 emplacements : " .. tostring(sl7 and sl7.why))
check(o7.comp_sleeping ~= nil and o7.comp_sleeping["iron-plate"] == true and not o7.comp_sleeping["copper-plate"],
  "§7 précondition au relevé du siège : le fer dort (relevé réel de Dep.sleeping), le cuivre non (posé)")
check(sl7 ~= nil and sl7.busy and sl7.room == 0 and sl7.room_comp == 1 and sl7.comp and sl7.comp["copper-plate"] == true
  and not sl7.comp["iron-plate"], "§7 chemin de jeu (Capi.slots, Dep.sleeping) : plein, 1 siège réservé au cuivre")
check(seen7 >= 1, "§7 journal [FO-CAPI-EMPLACEMENTS] : +1 pour le complement (copper-plate)")
check(not Em7.drill_refused(sl7, "copper-plate") and Em7.drill_refused(sl7, "iron-plate"),
  "§7 foreuses sur ce relevé : cuivre servi, fer refusé « plan directeur occupe »")
check(Em7.order_seat(sl7.room, sl7.room_comp, sl7.comp, "copper-plate") == "complement" and Em7.order_seat(sl7.room, sl7.room_comp, sl7.comp, "iron-plate") == nil,
  "§7 ordres sur ce relevé : couvrir le cuivre prend le siège, le fer est refusé")
say("§7 mutant : la regle du stock qui dort ne dit rien (Dep.sleeping vide)")
local _, sl7m, seen7m = comp_case({ minutes = 10, fake_mods = true, no_sleep = true, stock = CU })
check(sl7m ~= nil and sl7m.comp == nil and sl7m.room_comp == 0 and seen7m == 0, "§7 mutant détecté : sans relevé, aucun siège (le cuivre reste refusé)")

print(string.format("[DEPENSES2-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
