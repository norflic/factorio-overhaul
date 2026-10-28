--[[
  Lot CAPITAL « améliorer, et monter les époques » : test hors jeu de la règle pure (shared/ai3/capital.lua) sur les
  DONNÉES RÉELLES des niveaux (shared/levels/config.lua) et sur une COPIE aux données changées.

    §1 la famille « centre » est déduite des règles (aucun nom) ; gains lus dans les prototypes des niveaux ;
    §2 sans centre : poser le centre (son objet, lu dans son prototype) est le seul but, rien d'autre n'est permis ;
    §3 centre 1 : améliorer les tourelles (coût = L.cost), le centre est BLOQUÉ par la condition Q16 et sa valeur passe
       au bâtiment qui le bloque (chaîne) ; choix valeur ÷ coût ;
    §4 condition remplie : le centre devient candidat, sa valeur compte ce qu'il débloque ;
    §5 règle H8 : un objet du coût sans moyen connu de l'obtenir rend le candidat impayable (cause, `wanted`) ;
    §6 débit et défense : une machine en marche vaut plus qu'à l'arrêt ; la menace double la défense ; stock qui dort ;
    §7 GÉNÉRALISATION (D-20 (3)) : COPIE des données des niveaux dont le coût contient une PIÈCE MONTÉE ; le même code
       lit le nouveau coût, le projet le fait FABRIQUER à la main (P.want, livre de recettes) et le dépliage du cerveau
       général (Gen.summary) dit comment l'obtenir quand la main ne suffit pas (machine à construire, ou impayable sans
       exécutant : H8) ; aucune ligne de plus (contrôle de l'anti-échelle, tests/iag_test.lua §8, sur ce module) ;
    §8 émission : coût au stock -> payé (E.pay) ; sinon fabrications et manques ;
    §9 déterminisme (ordre du relevé inversé) ;
    §10 mutants : chaque règle cassée est vue par au moins un contrôle.
  Usage : lua5.2 tests/capital_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local L = require("shared.levels.config")
local Cap = require("shared.ai3.capital")
local Book = require("shared.team.book")
local P = require("shared.ai3.projets")
local Gen = require("shared.ai3.general")
local K = require("shared.ai3.catalogue")
local F = require("tests.iag_fixture")

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[CAPITAL] ECHEC : " .. msg) end
  end
  return cond
end
local function say(s) if not quiet then print("[CAPITAL] " .. s) end end

--- Prototypes SIMULÉS des niveaux, calculés comme l'étape data (L.apply_stat sur les valeurs vanilla du niveau 1).
local BASE = {
  gun = { type = "ammo-turret", role = "militaire", health = 400, dmg = 1, cooldown = 10 },
  laser = { type = "electric-turret", role = "militaire", health = 1000, dmg = 1, cooldown = 40 },
  wall = { type = "wall", role = "militaire", health = 350 },
  drill = { type = "mining-drill", role = "foreuse", health = 300, speed = 0.5 },
  furnace = { type = "furnace", role = "fabrique", health = 300, speed = 2 },
  assembler = { type = "assembling-machine", role = "fabrique", health = 350, speed = 0.75 },
}
local function proto_of(Ld)
  local cache = {}
  for _, fam in ipairs(Ld.families) do
    for n = 1, fam.max do
      local name = Ld.name(fam, n)
      if fam.key == "command" then
        cache[name] = { type = "container", role = "logistique", health = 3000, item = name }
      else
        local b = BASE[fam.key]
        local p = { type = b.type, role = b.role, item = name }
        for _, st in ipairs(fam.stats) do
          local leaf = st.path[#st.path]
          if leaf == "max_health" then p.health = Ld.apply_stat(st, b.health, n) end
          if leaf == "damage_modifier" then p.dmg = Ld.apply_stat(st, b.dmg, n) end
          if leaf == "crafting_speed" or leaf == "mining_speed" then p.speed = Ld.apply_stat(st, b.speed, n) end
        end
        p.health = p.health or b.health
        p.speed = p.speed or b.speed
        if b.cooldown then p.dps = (p.dmg or 1) / b.cooldown end
        cache[name] = p
      end
    end
  end
  return function(name) return cache[name] end
end
local proto = proto_of(L)

-- Coût unitaire simple et déterministe (en jeu : point fixe du graphe du cerveau général).
local UNIT = { ["iron-plate"] = 2, ["copper-plate"] = 2, ["stone-brick"] = 5, ["iron-gear-wheel"] = 5,
  ["electronic-circuit"] = 8, ["steel-plate"] = 12, ["fo-command-center"] = 300, ["battery"] = 30 }
local function unit_cost(item) return UNIT[item] end

local GUN, CC = L.by_key.gun, L.by_key.command
local function census(list, center)
  return { list = list, center = center }
end
local function guns(levels, start_id)
  local out = {}
  for i, n in ipairs(levels) do out[#out + 1] = { id = (start_id or 100) + i, name = L.name(GUN, n), working = false } end
  return out
end
local function ctx(over)
  local c = { proto = proto, unit_cost = unit_cost, stock = {}, weights = {} }
  for k, v in pairs(over or {}) do c[k] = v end
  return c
end

local function run_all()
  -- §1 Famille centre et gains.
  local cf = Cap.center_family(L)
  check(cf == CC, "§1 famille centre déduite des règles (celle qui n'exige aucun centre) : " .. tostring(cf and cf.key))
  local g, kind = Cap.gain(L, proto, GUN, 1)
  local expect = (1 + 0.08) * (1 + 0.15) - 1
  check(kind == "combat" and math.abs(g - expect) < 1e-9, string.format("§1 gain de la tourelle 1 -> 2 lu dans les prototypes : %.4f (attendu %.4f)", g, expect))
  local ga, ka = Cap.gain(L, proto, L.by_key.assembler, 4)
  check(ka == "debit" and math.abs(ga - (0.08 / (1 + 0.08 * 3))) < 1e-9, "§1 gain de l'assembleur 4 -> 5 = vitesse(5)/vitesse(4) - 1")
  local g30 = Cap.gain(L, proto, GUN, 30)
  check(g30 == 0, "§1 niveau maximal : aucun gain")

  -- §2 Sans centre.
  local d0 = Cap.choose(L, census(guns({ 1, 1, 1, 1 })), ctx())
  check(d0.key == "command:1:pose" and d0.build == true, "§2 sans centre : poser le centre (" .. tostring(d0.key) .. ")")
  check(d0.cost and #d0.cost == 1 and d0.cost[1][1] == "fo-command-center" and d0.cost[1][2] == 1,
    "§2 coût de la pose = l'objet qui pose le centre (lu dans son prototype)")
  check(d0.n_cands == 1, "§2 aucune amélioration de tourelle permise sans centre (" .. tostring(d0.n_cands) .. " candidat(s))")
  local unlocked = 4 * Cap.building_value(L, proto, GUN, 1, false, {})
  check(d0.value == math.floor(Cap.V_EPOCH + unlocked / Cap.LOOK_DIV + 0.5), "§2 valeur de la pose : époque + ce qu'elle débloque ÷ 2 (" .. tostring(d0.value) .. ")")
  check(d0.value > Cap.V_EPOCH, "§2 la pose vaut plus que l'époque seule : ce qu'elle débloque compte (" .. tostring(d0.value) .. ")")
  say("§2 sans centre : " .. Cap.why_text(d0))

  -- §3 Centre 1, tourelles 1.
  local center1 = { id = 1, name = L.name(CC, 1) }
  local d1 = Cap.choose(L, census(guns({ 1, 1, 1, 1 }), center1), ctx())
  check(d1.family == "gun" and d1.from == 1 and d1.to == 2, "§3 centre 1 : une tourelle 1 -> 2 (" .. tostring(d1.key) .. ")")
  local c2 = L.cost(GUN, 2)
  local same = #d1.cost == #c2
  for i, it in ipairs(c2) do if not (d1.cost[i] and d1.cost[i][1] == it[1] and d1.cost[i][2] == it[2]) then same = false end end
  check(same, "§3 coût = L.cost(famille, n + 1), lu dans les données")
  local bl = nil
  for _, b in ipairs(d1.blocked) do if b.center then bl = b end end
  check(bl ~= nil and bl.causes and bl.causes[1] == "condition:gun", "§3 centre 1 -> 2 BLOQUÉ par la condition Q16 (famille possédée sous le niveau exigé)")
  check(d1.chain ~= nil and d1.chain.target == bl.key, "§3 chaîne : la tourelle qui bloque hérite d'une part de la valeur du centre")
  check(d1.id == 101, "§3 la tourelle choisie est celle de la chaîne (la plus haute, puis le plus petit numéro) : #" .. tostring(d1.id))
  local own_v = Cap.building_value(L, proto, GUN, 1, false, {})
  check(d1.value > own_v, "§3 valeur avec chaîne > valeur propre (" .. d1.value .. " > " .. own_v .. ")")
  say("§3 centre 1 : " .. Cap.why_text(d1))

  -- §4 Condition remplie (une tourelle au niveau 2).
  local d2 = Cap.choose(L, census(guns({ 2, 1, 1, 1 }), center1), ctx())
  local cc_c = nil
  for _, k in ipairs(d2.ranked) do if k[1]:sub(1, 8) == "command:" then cc_c = k end end
  local res2 = Cap.candidates(L, census(guns({ 2, 1, 1, 1 }), center1), ctx())
  local ccand = nil
  for _, c in ipairs(res2.cands) do if c.center then ccand = c end end
  check(ccand ~= nil and ccand.to == 2, "§4 condition remplie : le centre 1 -> 2 est candidat")
  local cc_cost = L.cost(CC, 2)
  check(ccand and #ccand.cost == #cc_cost and ccand.cost[1][1] == cc_cost[1][1] and ccand.cost[1][2] == cc_cost[1][2],
    "§4 coût du centre = L.cost(centre, 2)")
  local u2 = Cap.building_value(L, proto, GUN, 2, false, {})
  check(ccand and ccand.value == math.floor(Cap.V_EPOCH + u2 / Cap.LOOK_DIV + 0.5),
    "§4 valeur du centre : époque + améliorations que son plafond interdit (la tourelle au niveau 2) ÷ 2")
  check(d2.family == "gun", "§4 valeur ÷ coût : les tourelles (bon marché) avant le centre (cher) : " .. tostring(d2.key))
  -- Toutes les tourelles au plafond : le centre passe en tête.
  local d3 = Cap.choose(L, census(guns({ 2, 2, 2, 2 }), center1), ctx())
  check(d3.center == true and d3.to == 2, "§4 tourelles au plafond : monter le centre (" .. tostring(d3.key) .. ")")
  say("§4 tourelles au plafond : " .. Cap.why_text(d3))
  -- Centre 2 : la tourelle 2 -> 3 coûte de l'acier (époque 2).
  local center2 = { id = 1, name = L.name(CC, 2) }
  local d4 = Cap.choose(L, census(guns({ 2, 2 }), center2), ctx())
  local steel = false
  for _, it in ipairs(d4.cost or {}) do if it[1] == "steel-plate" then steel = true end end
  check(d4.family == "gun" and d4.to == 3 and steel, "§4 centre 2 : tourelle 2 -> 3 payée en acier (matériau de l'époque, données)")

  -- §5 Règle H8.
  local no_steel = function(item) if item == "steel-plate" then return nil end return UNIT[item] end
  local d5 = Cap.choose(L, census(guns({ 2, 2 }), center2), ctx({ unit_cost = no_steel }))
  local all_blocked = true
  for _, b in ipairs(d5.blocked) do
    if b.family == "gun" then
      local has = false
      for _, c in ipairs(b.causes or {}) do if c == "steel-plate" then has = true end end
      all_blocked = all_blocked and has
    end
  end
  check(d5.family ~= "gun" and all_blocked, "§5 sans acier obtenable : aucune tourelle 2 -> 3 choisie (impayable, cause l'acier)")
  check(d5.wanted["steel-plate"] == true, "§5 l'objet manquant est rendu dans `wanted` (la recherche qui le débloque prend de la valeur)")

  -- §6 Débit, défense, menace, stock.
  local A = L.by_key.assembler
  local mixed = { { id = 10, name = L.name(A, 1), working = false }, { id = 11, name = L.name(A, 1), working = true } }
  local d6 = Cap.choose(L, census(mixed, { id = 1, name = L.name(CC, 3) }), ctx())
  check(d6.id == 11, "§6 la machine EN MARCHE est améliorée d'abord (#" .. tostring(d6.id) .. ")")
  local vw1 = Cap.building_value(L, proto, A, 4, true, {})
  local vi1 = Cap.building_value(L, proto, A, 4, false, {})
  check(vw1 > vi1 and vi1 > 0, "§6 débit : une machine en marche vaut plus qu'à l'arrêt (" .. vi1 .. " < " .. vw1 .. ")")
  local vg = Cap.building_value(L, proto, GUN, 3, false, {})
  local vt = Cap.building_value(L, proto, GUN, 3, false, { threat = true })
  check(vt >= 2 * vg - 1 and vt <= 2 * vg + 1, "§6 sous menace, la défense vaut le double (" .. vg .. " -> " .. vt .. ")")
  local vw = Cap.building_value(L, proto, GUN, 3, false, { weights = { defense = 2000 } })
  check(vw >= 2 * vg - 1, "§6 le poids du chef (défense) pondère la valeur (" .. vg .. " -> " .. vw .. ")")
  local stock = {}
  for _, it in ipairs(L.cost(GUN, 2)) do stock[it[1]] = it[2] * 10 end
  local c_in, _, all_in = Cap.work_cost(L.cost(GUN, 2), ctx({ stock = stock }))
  local c_out = Cap.work_cost(L.cost(GUN, 2), ctx())
  check(all_in and c_in < c_out, "§6 un coût qui dort au stock coûte moins (" .. c_in .. " < " .. c_out .. ")")
  local goal_in = Cap.goal({ key = "x", cost = {}, all_in = true }, {})
  local goal_out = Cap.goal({ key = "x", cost = {} }, {})
  check(goal_in.value > goal_out.value, "§6 investir un stock qui dort : le but vaut plus (" .. goal_out.value .. " -> " .. goal_in.value .. ")")
  local gs = Cap.goal({ key = "s", cost = {}, work = Cap.SHORT_WORK, center = true }, {})
  local gl = Cap.goal({ key = "l", cost = {}, work = Cap.SHORT_WORK + 1, center = true }, {})
  local gb = Cap.goal({ key = "b", cost = {}, work = 1 }, {})
  check(gs.short == true and gl.short == nil, "§6 pas du centre court (coût ≤ SHORT_WORK) : servi avant l'armée ; long : après")
  check(gb.short == nil, "§6 un bâtiment n'est jamais court : servi après l'armée (K9)")
  check(gb.fond == true and gs.fond == true, "§6 but de FOND : aucune place parmi les K projets")
  -- Ordre de service (P.update) : un but de fond ne prend pas de place et passe après tous les projets ; le pas court du
  -- centre passe avec les travaux courts (avant l'armée).
  local st = {}
  local goals = {
    { key = "recherche", family = "recherche", kind = "research", value = 70 },
    { key = "extraction:a", family = "extraction", kind = "outpost", value = 60 },
    { key = "extraction:b", family = "extraction", kind = "outpost", value = 59 },
    { key = "extraction:c", family = "extraction", kind = "outpost", value = 58 },
    { key = "armee", family = "armee", kind = "army", value = 46, permanent = true },
    { key = "capital:x", family = "capital", kind = "upgrade", value = 99, fond = true },
    { key = "capital:y", family = "capital", kind = "upgrade", value = 99, fond = true, short = true },
  }
  local order, Kp = P.update(st, goals, 0, 8)
  local pos = {}
  for i, p in ipairs(order) do pos[p.key] = i end
  local n_ord = 0
  for _, p in ipairs(order) do if not p.goal.permanent and not p.goal.fond then n_ord = n_ord + 1 end end
  check(Kp == 4 and n_ord == 4, "§6 fond : les 4 places restent aux projets ordinaires (" .. n_ord .. " sur K = " .. Kp .. ")")
  check(pos["capital:x"] == #order and pos["capital:x"] > pos["extraction:c"], "§6 fond : servi après tous les projets")
  check(pos["capital:y"] < pos["armee"], "§6 pas court du centre : servi avant l'armée")
  check(d0.work <= Cap.SHORT_WORK and d3.work > Cap.SHORT_WORK, "§6 la pose du centre est courte, son passage au niveau 2 ne l'est pas (" .. d0.work .. ", " .. d3.work .. ")")
  local goal_cc = Cap.goal({ key = "y", cost = {}, center = true }, {})
  check(goal_cc.value > goal_out.value and goal_cc.value < 55, "§6 le but du centre (époque) vaut plus qu'un bâtiment, sous l'extraction qui grandit")

  -- §7 GÉNÉRALISATION : copie des données avec une pièce montée dans le coût.
  package.loaded["shared.levels.config"] = nil
  local L2 = require("shared.levels.config")
  package.loaded["shared.levels.config"] = L
  check(L2 ~= L, "§7 copie indépendante des données des niveaux")
  local G2 = L2.by_key.gun
  G2.base_cost[#G2.base_cost + 1] = { "inserter", 2 }          -- pièce montée fabricable à la main
  G2.base_cost[#G2.base_cost + 1] = { "engine-unit", 1 }       -- pièce montée qu'il faut une MACHINE pour faire
  L2.item_value["inserter"] = 6
  L2.item_value["engine-unit"] = 9
  L2.rebuild()
  local proto2 = proto_of(L2)
  UNIT["inserter"] = 20
  UNIT["engine-unit"] = 60
  local d7 = Cap.choose(L2, census(guns({ 1, 1 }), center1), ctx({ proto = proto2 }))
  local has_ins, has_eng = false, false
  for _, it in ipairs(d7.cost or {}) do
    if it[1] == "inserter" then has_ins = true end
    if it[1] == "engine-unit" then has_eng = true end
  end
  check(d7.family == "gun" and has_ins and has_eng, "§7 le même code lit le NOUVEAU coût (bras et moteur dans le coût de la tourelle)")
  -- Le projet fabrique la pièce montée à la main (livre de recettes des fixtures), sans rien savoir des niveaux.
  local recipes = dofile("tests/fixtures/recipes_ia1e.lua")
  local book = Book.new(recipes)
  local goal7 = Cap.goal(d7, {})
  local E0 = P.context({ ["iron-plate"] = 500, ["copper-plate"] = 500 }, book, { open = {}, workers_idle = 0 }, {})
  local s0 = Cap.emit(P)(E0, { id = 70, key = "capital:x", prio = 50 }, Cap.goal(d7, {}))
  check(s0 == "matiere" and #E0.tasks == 0, "§7 bâtiment sans bras libres : rien n'est fabriqué pour lui (" .. #E0.tasks .. " tâche(s))")
  local E = P.context({ ["iron-plate"] = 500, ["copper-plate"] = 500 }, book, { open = {}, workers_idle = 2 }, {})
  local proj = { id = 7, key = goal7.key, prio = 50 }
  local fn = Cap.emit(P)
  local status = fn(E, proj, goal7)
  local crafted = {}
  for _, t in ipairs(E.tasks) do if t.kind == "craft" then crafted[t.item] = (crafted[t.item] or 0) + t.count end end
  check(status == "matiere", "§7 coût incomplet au stock : le projet attend sa matière (" .. tostring(status) .. ")")
  check((crafted["inserter"] or 0) >= 2, "§7 la pièce montée fabricable (bras) est FABRIQUÉE à la main par le projet : " .. tostring(crafted["inserter"]))
  check((proj.missing or {})["engine-unit"] ~= nil and not crafted["engine-unit"],
    "§7 la pièce qu'il faut une machine pour faire n'est pas fabriquée à la main (manque déclaré)")
  -- Le dépliage du cerveau général sur le coût : sans machine qui sache la faire, impayable (H8) ; avec une machine
  -- d'assemblage parmi les exécutants (IA3-e), elle se PRODUIT en machine, la machine est à construire.
  local cat = K.build(F.dump(), F.opts())
  local st = F.start_state({ techs = { ["steel-processing"] = true, ["automation"] = true, ["engine"] = true,
    ["logistics"] = true, ["electronics"] = true, ["logistic-science-pack"] = true } })
  local goals = {}
  for _, it in ipairs(d7.cost) do goals[#goals + 1] = { item = it[1], n = it[2] } end
  local ev = Gen.prepare(cat, st)
  local sum = Gen.summary(cat, ev, st, goals)
  check(sum.payable == false and ev.feas["engine-unit"] ~= true, "§7 sans machine d'assemblage parmi les exécutants : le moteur est impayable (H8)")
  check((sum.hand["inserter"] or 0) >= 2, "§7 dépliage : le bras se fait à la main (" .. tostring(sum.hand["inserter"]) .. ")")
  -- Exécutants d'IA3-e (plan directeur) : assembleur et centrale à vapeur (pompe de rive, chaudière, machine à vapeur),
  -- l'eau connue.
  local o3 = F.opts()
  for _, m in ipairs({ "assembling-machine-1", "offshore-pump", "boiler", "steam-engine" }) do o3.exec[m] = true end
  local cat3 = K.build(F.dump(), o3)
  local st3 = F.start_state({ techs = st.techs })
  st3.known["water"] = true
  local ev3 = Gen.prepare(cat3, st3)
  local sum3 = Gen.summary(cat3, ev3, st3, goals)
  check(ev3.feas["engine-unit"] == true, "§7 avec une machine d'assemblage exécutante (IA3-e) : le moteur devient faisable")
  check((sum3.produce["engine-unit"] or 0) >= 1, "§7 dépliage : le moteur est PRODUIT en machine (" .. tostring(sum3.produce["engine-unit"]) .. ")")
  local built = 0
  for _ in pairs(sum3.build) do built = built + 1 end
  check(built >= 1, "§7 dépliage : la machine est à construire (" .. Gen.fmt_map(sum3.build) .. ")")
  say("§7 coût changé : " .. Cap.why_text(d7))
  say("§7 dépliage avec machine : main " .. Gen.fmt_map(sum3.hand, 6) .. " machine " .. Gen.fmt_map(sum3.produce, 6) ..
    " construire " .. Gen.fmt_map(sum3.build))
  UNIT["inserter"], UNIT["engine-unit"] = nil, nil

  -- §8 Émission : tout au stock -> payé.
  local cost = L.cost(GUN, 2)
  local av = {}
  for _, it in ipairs(cost) do av[it[1]] = it[2] end
  local E8 = P.context(av, book, { open = {} }, {})
  local g8 = Cap.goal({ key = "gun:2:5", cost = cost }, {})
  local s8 = fn(E8, { id = 8, key = g8.key, prio = 50 }, g8)
  check(s8 == "ok" and E8.pay and #E8.pay == 1 and E8.pay[1].target == "gun:2:5", "§8 coût au stock virtuel : payé à cette pensée (E.pay)")
  local left = 0
  for _, it in ipairs(cost) do left = left + (E8.avail[it[1]] or 0) end
  check(left == 0, "§8 le coût est RÉSERVÉ au stock virtuel (rien d'autre ne le prend)")

  -- §8 bis (lot AMELIORER) : sans bras libre, un bâtiment à niveaux ne réclame rien ; un remplacement réclame sa cible.
  local function snapshot(E)
    local n = 0
    for _, t in ipairs({ "raw", "tasks", "make", "hand", "want" }) do
      for _ in pairs(E[t] or {}) do n = n + 1 end
    end
    return n
  end
  local function emit_idle0(replace)
    local E = P.context({}, book, { open = {}, workers_idle = 0 }, {})
    E.view = { workers_idle = 0 }
    local g = { key = "capital:x", cost = { { "iron-gear-wheel", 2 } }, target = "x", replace = replace or nil }
    local before = snapshot(E)
    local r = fn(E, { id = 9, key = g.key, prio = 50 }, g)
    return r, snapshot(E) - before
  end
  local r0, d0n = emit_idle0(false)
  local r1, d1n = emit_idle0(true)
  check(r0 == "matiere" and d0n == 0, "§8 bis sans bras libre, un bâtiment à niveaux ne réclame rien (" .. tostring(d0n) .. ")")
  check(r1 == "matiere" and d1n > 0, "§8 bis sans bras libre, un remplacement réclame quand même sa cible (" .. tostring(d1n) .. ")")

  -- §9 Déterminisme.
  local l1 = guns({ 2, 1, 1, 1 })
  local l2 = {}
  for i = #l1, 1, -1 do l2[#l2 + 1] = l1[i] end
  local da = Cap.choose(L, census(l1, center1), ctx())
  local db = Cap.choose(L, census(l2, center1), ctx())
  check(da.key == db.key and da.score == db.score, "§9 déterminisme : relevé dans l'ordre inverse, même décision")
  local dx = Cap.choose(L, census(l1, center1), ctx({ exclude = { [da.key] = true } }))
  local refused = false
  for _, b in ipairs(dx.blocked) do if b.key == da.key and b.causes[1] == "refus" then refused = true end end
  check(dx.key ~= da.key and refused, "§9 une cible refusée par l'exécutant est écartée (" .. tostring(dx.key) .. ")")
  local di = Cap.choose(L, census(guns({ 1, 1, 1, 1 }), center1), ctx({ current = "gun:2:104" }))
  check(di.key == "gun:2:104" or di.chain, "§9 inertie : la cible en cours garde sa place à valeur proche")
end

run_all()

-- §10 Mutants.
do
  local n_mut, n_caught = 0, 0
  local function M(name, apply, undo)
    n_mut = n_mut + 1
    local p0, f0 = pass, fail
    quiet = true
    apply()
    local ok = pcall(run_all)
    undo()
    quiet = false
    local caught = (not ok) or fail > f0
    pass, fail = p0, f0
    if caught then n_caught = n_caught + 1 else print("[CAPITAL] mutant survivant : " .. name) end
  end
  local ch = Cap.CHAIN_PCT
  M("chaîne Q16 coupée", function() Cap.CHAIN_PCT = 0 end, function() Cap.CHAIN_PCT = ch end)
  local sp = Cap.STOCK_PCT
  M("stock compté plein", function() Cap.STOCK_PCT = 100 end, function() Cap.STOCK_PCT = sp end)
  local th = Cap.THREAT_PCT
  M("menace ignorée", function() Cap.THREAT_PCT = 100 end, function() Cap.THREAT_PCT = th end)
  local iu = Cap.IDLE_USE
  M("usage ignoré", function() Cap.IDLE_USE = 100 end, function() Cap.IDLE_USE = iu end)
  local wc = Cap.work_cost
  M("coût ignoré (valeur seule)", function() Cap.work_cost = function(l, c) local _, m, a = wc(l, c) return 0, m, a end end,
    function() Cap.work_cost = wc end)
  M("impayable compté payable", function() Cap.work_cost = function(l, c) local x, _, a = wc(l, c) return x, {}, a end end,
    function() Cap.work_cost = wc end)
  local gn = Cap.gain
  M("gain constant", function() Cap.gain = function(Ld, p, f, n) local _, k = gn(Ld, p, f, n) return 0.1, k end end,
    function() Cap.gain = gn end)
  local cfm = Cap.center_family
  M("centre pris pour une famille ordinaire", function() Cap.center_family = function() return nil end end,
    function() Cap.center_family = cfm end)
  local ld = Cap.LOOK_DIV
  M("déblocage ignoré", function() Cap.LOOK_DIV = 1e9 end, function() Cap.LOOK_DIV = ld end)
  local cg = Cap.goal
  M("but ordinaire (pas de fond)", function() Cap.goal = function(d, w) local g = cg(d, w) if g then g.fond = nil end return g end end,
    function() Cap.goal = cg end)
  check(n_caught == n_mut, string.format("§10 mutants : %d refusés sur %d", n_caught, n_mut))
end

-- §11 Coût de calcul (ordre de grandeur, PC non épinglé) : une décision sur 60 bâtiments (relevé d'une faction riche).
do
  local list = {}
  for i = 1, 40 do list[#list + 1] = { id = 1000 + i, name = L.name(GUN, 1 + (i % 4)), working = false } end
  for i = 1, 20 do list[#list + 1] = { id = 2000 + i, name = L.name(L.by_key.assembler, 1 + (i % 4)), working = i % 2 == 0 } end
  local cen = census(list, { id = 1, name = L.name(CC, 2) })
  local t0 = os.clock()
  local N = 200
  for _ = 1, N do Cap.choose(L, cen, ctx()) end
  local ms = (os.clock() - t0) * 1000 / N
  say(string.format("§11 une décision sur 60 bâtiments : %.3f ms (hors jeu ; une par faction et par minute en jeu)", ms))
  check(ms < 20, "§11 une décision coûte moins de 20 ms hors jeu")
end

-- §12 Réglage de carte (correction après revue, 27/10) : fo-war-capital existe, est relu en cours de partie
-- (runtime-global), porte le préfixe des réglages des bancs (« fo-war- », interface war_setting) et est ÉTEINT par défaut
-- (D1 ouvert : la recherche des factions est retardée quand il est allumé) ; ses deux traductions existent.
do
  local got = {}
  local saved = _G.data
  _G.data = { extend = function(_, list) for _, s in ipairs(list) do got[#got + 1] = s end end }
  local ok, err = pcall(dofile, "settings/capital.lua")
  _G.data = saved
  check(ok, "§12 settings/capital.lua se charge : " .. tostring(err))
  local s = got[1]
  check(#got == 1 and s and s.name == "fo-war-capital" and s.type == "bool-setting", "§12 un réglage bool fo-war-capital")
  check(s and s.setting_type == "runtime-global", "§12 réglage de carte relu en cours de partie (runtime-global)")
  check(s and s.default_value == false, "§12 ÉTEINT par défaut")
  for _, lang in ipairs({ "fr", "en" }) do
    local fh = io.open("locale/" .. lang .. "/capital.cfg", "r")
    local txt = fh and fh:read("*a") or ""
    if fh then fh:close() end
    check(txt:find("\n?fo%-war%-capital=") ~= nil and select(2, txt:gsub("fo%-war%-capital=", "")) == 2,
      "§12 nom et description traduits (" .. lang .. ")")
  end
  local src = io.open("script/ai3/capital.lua", "r")
  local code = src and src:read("*a") or ""
  if src then src:close() end
  check(code:find('Capital.SETTING = "fo-war-capital"', 1, true) ~= nil and code:find("settings.global[Capital.SETTING]", 1, true) ~= nil,
    "§12 Capital.on lit le réglage")
end


-- §13 Lot AMELIORER : machines HORS famille (four de pierre, premier assembleur) remplacées sur place par la machine
-- supérieure, DÉRIVÉE des prototypes (type, groupe de remplacement rapide, emprise, énergie, catégories, vitesse). Données
-- vanilla simulées PUIS un jeu de données aux noms changés (aucun nom du jeu dans le code : même décision).
local function machine_world(rn)
  rn = rn or function(n) return n end
  local cats_asm1 = { [rn("crafting")] = true, [rn("basic-crafting")] = true, [rn("advanced-crafting")] = true }
  local cats_asm2 = { [rn("crafting")] = true, [rn("basic-crafting")] = true, [rn("advanced-crafting")] = true,
    [rn("crafting-with-fluid")] = true }
  local defs = {
    { "stone-furnace", "furnace", "furnace", 2, "burner", { [rn("smelting")] = true }, 1 },
    { "steel-furnace", "furnace", "furnace", 2, "burner", { [rn("smelting")] = true }, 2 },
    { "electric-furnace", "furnace", "furnace", 3, "electric", { [rn("smelting")] = true }, 2 },
    { "assembling-machine-1", "assembling-machine", "assembling-machine", 3, "electric", cats_asm1, 0.5 },
    { "assembling-machine-2", "assembling-machine", "assembling-machine", 3, "electric", cats_asm2, 0.75 },
    { "assembling-machine-3", "assembling-machine", "assembling-machine", 3, "electric", cats_asm2, 1.25 },
    { "chemical-plant", "assembling-machine", "chemical-plant", 3, "electric", { [rn("chemistry")] = true }, 1 },
    -- Leurres : chacun ne diffère du four de pierre que par UNE propriété (emprise, énergie, groupe, catégories, vitesse).
    { "leurre-taille", "furnace", "furnace", 3, "burner", { [rn("smelting")] = true }, 3 },
    { "leurre-energie", "furnace", "furnace", 2, "electric", { [rn("smelting")] = true }, 3 },
    { "leurre-groupe", "furnace", "autre-groupe", 2, "burner", { [rn("smelting")] = true }, 3 },
    { "leurre-categories", "furnace", "furnace", 2, "burner", { ["autre-categorie"] = true }, 3 },
    { "leurre-lent", "furnace", "furnace", 2, "burner", { [rn("smelting")] = true }, 0.5 },
  }
  local protos, names = {}, {}
  for _, d in ipairs(defs) do
    local nm = rn(d[1])
    protos[nm] = { type = d[2], group = rn(d[3]), w = d[4], h = d[4], energy = d[5], cats = d[6], speed = d[7], item = nm }
    names[#names + 1] = nm
  end
  table.sort(names)
  return { mproto = function(n) return protos[n] end, machines = names }
end
local function mctx(world, over)
  local c = ctx(over)
  c.mproto, c.machines = world.mproto, world.machines
  return c
end
local MUNIT = { ["stone-furnace"] = 20, ["steel-furnace"] = 60, ["electric-furnace"] = 400, ["assembling-machine-1"] = 40,
  ["assembling-machine-2"] = 90, ["assembling-machine-3"] = 600 }

local function run_replace()
  local W = machine_world()
  local saved_unit = {}
  for k, v in pairs(MUNIT) do saved_unit[k] = UNIT[k]; UNIT[k] = v end
  local function restore() for k in pairs(MUNIT) do UNIT[k] = saved_unit[k] end end
  local function mach(list, base_id)
    local out = {}
    for i, e in ipairs(list) do out[#out + 1] = { id = (base_id or 500) + i, name = e[1], working = e[2] and true or false } end
    return out
  end
  local cen = { id = 1, name = L.name(CC, 2) }

  -- Successeurs : lus dans les prototypes (emprise, énergie, groupe, catégories, vitesse).
  local sc = Cap.successors(L, mctx(W), "stone-furnace")
  check(#sc == 1 and sc[1] == "steel-furnace", "§13 four de pierre -> four en acier seulement (le four électrique, 3x3, est écarté) : " .. table.concat(sc, ","))
  local sa = Cap.successors(L, mctx(W), "assembling-machine-1")
  check(#sa == 2 and sa[1] == "assembling-machine-2" and sa[2] == "assembling-machine-3", "§13 assembleur 1 : 2 puis 3, par vitesse croissante : " .. table.concat(sa, ","))
  check(#Cap.successors(L, mctx(W), "chemical-plant") == 0, "§13 une usine chimique n'a aucune cible (groupe, catégories)")
  check(#Cap.successors(L, mctx(W), "inconnu") == 0, "§13 un nom inconnu n'a aucune cible")

  -- Décision : le four de pierre en marche est remplacé ; la cible est l'objet qui la pose.
  local d = Cap.choose(L, census({}, cen), mctx(W))
  check(d.replace == nil, "§13 sans machine, aucun remplacement")
  local cs = census({}, cen)
  cs.machines = mach({ { "stone-furnace", true }, { "stone-furnace", true } })
  local d1 = Cap.choose(L, cs, mctx(W, { stock = { ["steel-furnace"] = 2 } }))
  check(d1.family == "remplacer" and d1.replace and d1.replace.from == "stone-furnace" and d1.replace.to == "steel-furnace",
    "§13 four de pierre en marche : remplacé par le four en acier (" .. tostring(d1.key) .. ")")
  check(d1.replace and d1.replace.n == 2 and #d1.ids == 2 and d1.cost[1][1] == "steel-furnace" and d1.cost[1][2] == 2,
    "§13 deux fours en stock : un lot de 2, coût = 2 objets de la cible")
  check(d1.value == 200, "§13 valeur = gain de vitesse (+100 %) × V_DEBIT par machine (" .. tostring(d1.value) .. ")")
  local d1b = Cap.choose(L, cs, mctx(W))
  check(d1b.replace and d1b.replace.n == 1 and #d1b.ids == 1, "§13 rien en stock : une machine à la fois (rien de fabriqué en gros)")
  local cs5 = census({}, cen)
  local seven = {}
  for i = 1, 7 do seven[i] = { "stone-furnace", true } end
  cs5.machines = mach(seven)
  local d5 = Cap.choose(L, cs5, mctx(W, { stock = { ["steel-furnace"] = 9 } }))
  check(d5.replace and d5.replace.n == Cap.REPLACE_BATCH, "§13 le lot est borné à Cap.REPLACE_BATCH (" .. tostring(d5.replace and d5.replace.n) .. ")")

  -- Valeur : à l'arrêt, un quart ; l'assembleur 1 choisit la cible de meilleur score ; la cible impayable ne compte pas.
  local cs2 = census({}, cen)
  cs2.machines = mach({ { "stone-furnace", false } })
  local d2 = Cap.choose(L, cs2, mctx(W))
  check(d2.value == 25, "§13 à l'arrêt : un quart de la valeur (" .. tostring(d2.value) .. ")")
  local cs3 = census({}, cen)
  cs3.machines = mach({ { "assembling-machine-1", true } })
  local d3 = Cap.choose(L, cs3, mctx(W))
  check(d3.replace and d3.replace.to == "assembling-machine-2", "§13 assembleur 1 -> 2 (meilleur valeur ÷ coût que 3) : " .. tostring(d3.replace and d3.replace.to))
  UNIT["assembling-machine-3"] = 100
  local d3b = Cap.choose(L, cs3, mctx(W))
  check(d3b.replace and d3b.replace.to == "assembling-machine-3", "§13 la cible de meilleur score change avec les coûts (3 devient bon marché)")
  UNIT["assembling-machine-3"] = 600
  UNIT["steel-furnace"] = nil
  local d4 = Cap.choose(L, cs2, mctx(W))
  check(d4.replace == nil, "§13 cible non faisable (coût inconnu) : aucun remplacement")
  local bl4 = false
  for _, b in ipairs(d4.blocked) do if b.family == "remplacer" and b.no_want then bl4 = true end end
  check(bl4, "§13 la machine attend, notée bloquée")
  check(next(d4.wanted) == nil, "§13 une cible non faisable ne réclame PAS la recherche (no_want)")
  UNIT["steel-furnace"] = 60

  -- Famille à niveaux : jamais en double (la machine d'une famille suit l'amélioration ordinaire).
  local cs6 = census({}, cen)
  cs6.machines = mach({ { "steel-furnace", true }, { L.name(L.by_key.assembler, 3), true } })
  local d6 = Cap.choose(L, cs6, mctx(W))
  check(d6.replace == nil, "§13 une machine déjà d'une famille à niveaux n'est pas un candidat « remplacer »")

  -- Refus par machine : écartée, sans bloquer les autres.
  local cs7 = census({}, cen)
  cs7.machines = mach({ { "stone-furnace", true }, { "stone-furnace", true } }, 700)
  local d7 = Cap.choose(L, cs7, mctx(W, { stock = { ["steel-furnace"] = 5 } }))
  check(d7.replace and d7.replace.n == 2 and d7.ids[1] == 701, "§13 deux machines au lot (sans refus)")
  local d7b = Cap.choose(L, cs7, mctx(W, { stock = { ["steel-furnace"] = 5 }, exclude = { ["m:701"] = true } }))
  check(d7b.replace and d7b.replace.n == 1 and d7b.ids[1] == 702, "§13 une machine refusée par l'exécutant est écartée, l'autre reste")

  -- Déterminisme : relevé inversé.
  local cs8 = census({}, cen)
  cs8.machines = mach({ { "stone-furnace", true }, { "assembling-machine-1", false }, { "stone-furnace", false } })
  local cs8r = census({}, cen)
  cs8r.machines = {}
  for i = #cs8.machines, 1, -1 do cs8r.machines[#cs8r.machines + 1] = cs8.machines[i] end
  local da, db = Cap.choose(L, cs8, mctx(W)), Cap.choose(L, cs8r, mctx(W))
  check(da.key == db.key, "§13 déterminisme : relevé inversé, même décision (" .. tostring(da.key) .. " / " .. tostring(db.key) .. ")")

  -- Débloquée seulement : une cible dont la recette est désactivée attend, sans réclamer sa recherche.
  local locked = mctx(W, { stock = { ["steel-furnace"] = 2 } })
  locked.available = function(item) return item ~= "steel-furnace" end
  local dl = Cap.choose(L, cs, locked)
  check(dl.replace == nil, "§13 cible non débloquée (recette désactivée) : aucun remplacement")
  local blk = false
  for _, b in ipairs(dl.blocked) do if b.family == "remplacer" and b.no_want and b.causes[1] == "steel-furnace" then blk = true end end
  check(blk and next(dl.wanted) == nil, "§13 cible non débloquée : notée bloquée, la recherche n'est pas réclamée")
  locked.available = function() return true end
  check(Cap.choose(L, cs, locked).replace ~= nil, "§13 cible débloquée : remplacement")

  -- But : fond (aucune place de projet), coût = les objets de la cible.
  local g = Cap.goal(d1, {})
  check(g and g.fond == true and g.kind == "upgrade" and g.cost[1][1] == "steel-furnace" and g.target == d1.key, "§13 but de fond, coût = la cible")
  check(g and g.replace == true, "§13 le but porte le drapeau « remplacer » (servi sans attendre un bras libre)")


  -- GÉNÉRALISATION : mêmes machines, TOUS les noms changés (types gardés : ce sont ceux du moteur).
  local map = { ["stone-furnace"] = "four-d-argile", ["steel-furnace"] = "four-de-fonte", ["electric-furnace"] = "four-a-arc",
    ["assembling-machine-1"] = "monteur-1", ["assembling-machine-2"] = "monteur-2", ["assembling-machine-3"] = "monteur-3",
    ["chemical-plant"] = "cornue", ["smelting"] = "fonte", ["crafting"] = "montage", ["basic-crafting"] = "montage-simple",
    ["advanced-crafting"] = "montage-fin", ["crafting-with-fluid"] = "montage-fluide", ["chemistry"] = "chimie",
    ["furnace"] = "groupe-four", ["assembling-machine"] = "groupe-montage" }
  local W2 = machine_world(function(n) return map[n] or n end)
  local U2 = {}
  for k, v in pairs(MUNIT) do U2[map[k]] = v end
  local function unit2(item) return U2[item] or UNIT[item] end
  local cs9 = census({}, cen)
  cs9.machines = { { id = 801, name = "four-d-argile", working = true }, { id = 802, name = "monteur-1", working = true } }
  local c9 = mctx(W2, { stock = { ["four-de-fonte"] = 3 } })
  c9.unit_cost = unit2
  local d9 = Cap.choose(L, cs9, c9)
  check(d9.replace and d9.replace.from == "four-d-argile" and d9.replace.to == "four-de-fonte",
    "§13 GÉNÉRALISATION : données aux noms changés, le même code remplace le four d'argile par celui de la fonte (" .. tostring(d9.key) .. ")")
  check(#Cap.successors(L, c9, "monteur-1") == 2, "§13 GÉNÉRALISATION : successeurs du monteur lus dans les prototypes")
  -- Même décision que sur les noms d'origine (au renommage près).
  local c9o = mctx(W, { stock = { ["steel-furnace"] = 3 } })
  local cs9o = census({}, cen)
  cs9o.machines = { { id = 801, name = "stone-furnace", working = true }, { id = 802, name = "assembling-machine-1", working = true } }
  local d9o = Cap.choose(L, cs9o, c9o)
  check(d9o.value == d9.value and d9o.score == d9.score and d9o.replace.n == d9.replace.n, "§13 GÉNÉRALISATION : même valeur, même score, même lot")
  restore()
end
run_replace()

-- Anti-échelle : aucun nom du jeu écrit dans le code pur de ce lot (commentaires exceptés).
do
  local fh = io.open("shared/ai3/capital.lua", "r")
  local code = fh and fh:read("*a") or ""
  if fh then fh:close() end
  local seg = code:match("function Cap%.successors.-\nend\n") or ""
  local seg2 = code:match("function Cap%.replace_candidates.-\nend\n") or ""
  local clean = (seg .. seg2):gsub("%-%-[^\n]*", "")
  for _, bad in ipairs({ "furnace", "assembling", "stone", "steel", "smelting" }) do
    check(not clean:find(bad, 1, true), "§13 aucun nom du jeu dans le code de remplacement : « " .. bad .. " »")
  end
  check(#seg > 100 and #seg2 > 100, "§13 les fonctions de remplacement sont trouvées par le contrôle anti-échelle")
end

-- Mutants du lot AMELIORER.
do
  local n_mut, n_caught = 0, 0
  local function M(name, apply, undo)
    n_mut = n_mut + 1
    local p0, f0 = pass, fail
    quiet = true
    apply()
    local ok = pcall(run_replace)
    undo()
    quiet = false
    local caught = (not ok) or fail > f0
    pass, fail = p0, f0
    if caught then n_caught = n_caught + 1 else print("[CAPITAL] mutant survivant (remplacer) : " .. name) end
  end
  local sc = Cap.successors
  local function wrap(edit)
    return function(Ld, c, n)
      local mp = c.mproto
      local c2 = setmetatable({ mproto = function(x)
        local p = mp(x)
        if not p then return nil end
        local q = {}
        for k, v in pairs(p) do q[k] = v end
        edit(q, x, n)
        return q
      end }, { __index = c })
      return sc(Ld, c2, n)
    end
  end
  M("successeurs : l'emprise n'est plus comparée", function() Cap.successors = wrap(function(q) q.w, q.h = 2, 2 end) end, function() Cap.successors = sc end)
  M("successeurs : le groupe n'est plus comparé", function() Cap.successors = wrap(function(q) q.group = "g" end) end, function() Cap.successors = sc end)
  M("successeurs : l'énergie n'est plus comparée", function() Cap.successors = wrap(function(q) q.energy = "e" end) end, function() Cap.successors = sc end)
  M("successeurs : les catégories ne sont plus comparées", function() Cap.successors = wrap(function(q) q.cats = {} end) end, function() Cap.successors = sc end)
  M("successeurs : la vitesse n'est plus comparée", function() Cap.successors = wrap(function(q, x, n) q.speed = (x == n) and 1 or 2 end) end, function() Cap.successors = sc end)
  local rb = Cap.REPLACE_BATCH
  M("lot non borné", function() Cap.REPLACE_BATCH = 100 end, function() Cap.REPLACE_BATCH = rb end)
  local iu = Cap.IDLE_USE
  M("usage ignoré (remplacer)", function() Cap.IDLE_USE = 100 end, function() Cap.IDLE_USE = iu end)
  local rc = Cap.replace_candidates
  M("remplacer éteint", function() Cap.replace_candidates = function() return {}, {} end end, function() Cap.replace_candidates = rc end)
  local wc = Cap.work_cost
  M("impayable compté payable (remplacer)", function() Cap.work_cost = function(l, c) local x, _, a = wc(l, c) return x, {}, a end end,
    function() Cap.work_cost = wc end)
  check(n_caught == n_mut, string.format("§13 mutants du lot : %d refusés sur %d", n_caught, n_mut))
end

print(string.format("[CAPITAL] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
