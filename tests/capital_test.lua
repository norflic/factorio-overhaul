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

print(string.format("[CAPITAL] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
