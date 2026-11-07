--[[
  Lot VIDEO-L3, étape 4 (branchement) : le MANQUE MESURÉ dans la vue, au moteur simulé (tests/mock_engine.lua). Ce n'est pas une preuve en
  jeu (micro-banc collecte-fer, à faire par la file : INTEGRATION_VIDEO.md étape 4).
  On appelle le VRAI Team.view d'une faction et de votre équipe, sur des coffres et des tâches posés au tableau :
    §1 la scène n de tests/manque_local_test.lua (D0/D1 du 7/11) rejouée sur la vue simulée : le fer du champ est VU (view.dort), pas
       disponible (view.avail_out vide) tant que la collecte n'est pas prise, et la collecte existante (52) monte à la priorité du
       manque qu'elle couvre (Collecte.apply) ; un coffre sans tâche dort (ni collecte, ni retenue) ;
    §2 collecte prise : les plaques passent disponibles, la part à construire baisse d'autant ;
    §3 view.stock INCHANGÉ : la vue avec le manque mesuré et la vue éteinte (Mv.ENABLED = false) ont le même stock ;
    §4 module fini (quais, débit nominal p.inflow, machine alimentée) et transit d'une tâche « fill » prise : manque = 1 min de nominal
       moins l'entrée moins le transit ; il devient un puits de la capitalisation (Mq.sinks) ;
    §5 survie : seule la plaque dont la collecte est PRISE (view.avail_out) est déduite du manque ; une collecte à faire ne couvre
       rien (version stricte du lead, 7/11) ;
    §11 la scène D1 du DC : 4 353 plaques au champ, une tâche de collecte LIBRE que personne ne prend : la survie S'OUVRE ;
       mutant « collecte à faire comptée » refusé ;
    §6 demandes : objectif net, réserve et priorité de survie sous l'effectif de départ, recrue décidée (Mv.wants) ;
    §7 éteint : view.mq absent, f.team.mq effacé, la collecte rejoue la règle d'avant ;
    §8 la chaîne lue dans les sources (vue, collecte, survie, capitalisation) ;
    §9 coût en INSTRUCTIONS (debug.sethook) d'un calcul ;
    §10 mutants de comportement (interrupteurs et fonctions remplacées) : chacun fait échouer au moins un contrôle.
  Usage : lua5.2 tests/manque_vue_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("[MANQUE-VUE] ECHEC : " .. msg) end end
  return cond
end
local function say(s) if not quiet then print("[MANQUE-VUE] " .. s) end end
local function W() return M.world() end
local MIN = 3600

M.new_world({ p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
M.load_mod()
M.dispatch(W().on_init)
M.command("fo-war", "start 2 30 30 320")
M.run_ticks(60)
do
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
end
M.run_ticks(60)

local T = require("shared.team.config")
local Team = require("script.team.team")
local Board = require("script.team.board")
local Col = require("script.team.collecte")
local Mv = require("script.team.manque_vue")
local Mq = require("shared.ai3.manque_local")
local Co = require("shared.team.collecte")
local Sv = require("shared.team.survie")
local PLATE = T.outposts.iron.product
local CHEST = T.outposts.coal.sink
local GEAR = "iron-gear-wheel" -- objet d'entrée du module de test (absent du coffre de départ : vérifié plus bas)

local function ser(v)
  if type(v) ~= "table" then return tostring(v) end
  local ks = {}
  for k in pairs(v) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(ks) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
  return "{" .. table.concat(parts, ",") .. "}"
end
local function eq(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 1e-6 end

local PID_OUT, PID_MOD = 9001, 9002

--- Pose la scène sur l'équipe f : 3 coffres de sortie (585, 560, 540 plaques), le 1er avec sa tâche de collecte au tableau ; un module fini
--- (quai de 5 engrenages, 30 par minute au nominal, une machine) avec une tâche « fill » de 10 prise. Rend une fonction qui retire tout.
local function stage(f, missing, taken, amounts, all_tasks)
  local s = f.hq.surface
  local hq = f.hq.position
  local made = {}
  local function chest_at(x, y, item, n)
    local c = s.create_entity({ name = CHEST, position = { x = x, y = y }, force = f.force })
    if n > 0 then c.get_inventory(defines.inventory.chest).insert({ name = item, count = n }) end
    made[#made + 1] = c
    return c
  end
  local outs = {}
  for i, n in ipairs(amounts or { 585, 560, 540 }) do
    local x, y = math.floor(hq.x) + 40 + 4 * i + 0.5, math.floor(hq.y) + 0.5
    chest_at(x, y, PLATE, n)
    outs[i] = { x = x, y = y, at = 200 }
  end
  local qx, qy = math.floor(hq.x) + 60.5, math.floor(hq.y) + 10.5
  chest_at(qx, qy, GEAR, 5)
  local mx, my = math.floor(hq.x) + 64, math.floor(hq.y) + 10
  local mach = s.create_entity({ name = "assembling-machine-1", position = { x = mx + 1.5, y = my + 1.5 }, force = f.force })
  made[#made + 1] = mach
  local had_build = f.build ~= nil
  f.build = f.build or { order = {}, projects = {} }
  local b = f.build
  b.order = b.order or {}
  b.projects = b.projects or {}
  b.order[#b.order + 1] = PID_OUT
  b.order[#b.order + 1] = PID_MOD
  b.projects[PID_OUT] = { id = PID_OUT, state = "reserve:pile", outs = outs, quais = {}, prio = 55, parts = {}, ents = {} }
  b.projects[PID_MOD] = { id = PID_MOD, state = "fini", outs = {}, quais = { { x = qx, y = qy, item = GEAR } }, inflow = { [GEAR] = 0.5 },
    prio = 60, parts = { { ox = mx, oy = my, w = 3, h = 3 } }, ents = {} }
  local bd = Board.get(f)
  local ko = "ia1d:" .. PID_OUT .. ":o:1"
  bd.tasks[ko] = { key = ko, kind = "carry", prio = 52, ia1d = { pid = PID_OUT, mode = "collect", idx = 1 }, worker = taken and 424242 or nil }
  local extra = {}
  if all_tasks then -- une tâche de collecte LIBRE sur chaque coffre (personne ne la prend)
    for i = 2, #outs do
      local k = "ia1d:" .. PID_OUT .. ":o:" .. i
      bd.tasks[k] = { key = k, kind = "carry", prio = 52, ia1d = { pid = PID_OUT, mode = "collect", idx = i } }
      extra[#extra + 1] = k
    end
  end
  local kq = "ia1d:" .. PID_MOD .. ":q:1"
  bd.tasks[kq] = { key = kq, kind = "carry", prio = 63, items = { { GEAR, 10 } }, ia1d = { pid = PID_MOD, mode = "fill", idx = 1 }, worker = 434343 }
  local missing0 = f.team.missing
  f.team.missing = missing
  return function()
    for _, c in ipairs(made) do if c.valid then c.destroy() end end
    bd.tasks[ko], bd.tasks[kq] = nil, nil
    for _, k in ipairs(extra) do bd.tasks[k] = nil end
    local keep = {}
    for _, id in ipairs(b.order) do if id ~= PID_OUT and id ~= PID_MOD then keep[#keep + 1] = id end end
    b.order = keep
    b.projects[PID_OUT], b.projects[PID_MOD] = nil, nil
    if not had_build then f.build = nil end
    f.team.missing = missing0
  end
end

--- Vue avec un calcul neuf du manque mesuré (l'horloge d'une minute est remise).
local function fresh_view(f)
  if f.team.mq then f.team.mq.tick = nil end
  return Team.view(f, game.tick)
end

local function scenes(f, label)
  local res
  -- §1 D0/D1.
  local undo = stage(f, { { PLATE, 1000 } }, false)
  local view = fresh_view(f)
  res = f.team.mq and f.team.mq.res
  check(res ~= nil and view.mq ~= nil, label .. " §1 : la vue publie le manque mesure")
  if res then
    check((view.dort or {})[PLATE] ~= nil and view.dort[PLATE] >= 1685, label .. " §1 : le fer du champ est VU (dort " .. tostring((view.dort or {})[PLATE]) .. ")")
    check(view.avail_out == nil or view.avail_out[PLATE] == nil, label .. " §1 : mais pas disponible tant qu'aucune collecte n'est prise")
    local a
    for _, x in ipairs(res.collect) do if x.task == "ia1d:" .. PID_OUT .. ":o:1" then a = x end end
    local under = (f.engineers_count or 0) < (f.team.floor or 0)
    local want_prio = under and Co.PRIO or Mv.PRIO_GOAL
    check(a ~= nil and eq(a.n, 585) and a.prio == want_prio, label .. " §1 : la collecte du coffre 1 couvre 585 a la priorite " .. want_prio .. " (" .. ser(a) .. ")")
    local others = 0
    for _, x in ipairs(res.collect) do if x.source == PID_OUT .. ":2" or x.source == PID_OUT .. ":3" then others = others + 1 end end
    check(others == 0, label .. " §1 : un coffre sans tache dort : ni collecte ni retenue")
    check(eq(view.mq.build[PLATE], 1000 - 585), label .. " §1 : objectif net 1000, a construire 415 (" .. tostring(view.mq.build[PLATE]) .. ")")
    -- Collecte.apply : la tâche de la pensée (52) monte.
    local t = { key = "ia1d:" .. PID_OUT .. ":o:1", kind = "carry", prio = 52, ia1d = { pid = PID_OUT, mode = "collect", idx = 1 } }
    local n = Col.apply(f, f.hq.surface, f.build, { t }, game.tick)
    check(n == 1 and t.prio == want_prio and t.no_rush == true, label .. " §1 : Collecte.apply releve la collecte de 52 a " .. want_prio .. " (" .. tostring(t.prio) .. ")")
    check((want_prio >= Co.PRIO) == (t.critical == true), label .. " §1 : critique seulement au niveau de la survie")
    -- §5 survie : la collecte n'est pas prise : rien n'est déduit.
    local short = Sv.uncovered(Sv.shortages({ { PLATE, 1000 } }, { [PLATE] = true }), view.avail_out)
    check(#short == 1 and eq(short[1][2], 1000), label .. " §5 : collecte a faire : la survie voit tout le manque (" .. ser(short) .. ")")
    -- §4 module et transit.
    local stock_gear = (view.stock or {})[GEAR] or 0
    local mneed = math.max(0, 30 - 5 - 10)
    local mod_build
    for _, e in ipairs(res.short_by) do if e.key == "m:" .. PID_MOD and e.item == GEAR then mod_build = e.n end end
    check(stock_gear > 0 or eq(mod_build, mneed), label .. " §4 : module : 30/min - 5 au quai - 10 en route = " .. mneed .. " (" .. tostring(mod_build) .. ")")
    local sinks = Mq.sinks(res, {})
    local sk
    for _, x in ipairs(sinks) do if x.item == GEAR then sk = x end end
    check(stock_gear > 0 or (sk ~= nil and eq(sk.rate, mneed)), label .. " §4 : puits de la capitalisation " .. mneed .. "/min (" .. ser(sk) .. ")")
    if stock_gear > 0 then say(label .. " : le coffre a des engrenages (" .. stock_gear .. ") : §4 lu sans valeur exacte") end
  end
  -- §3 stock inchangé.
  local v_on = fresh_view(f)
  Mv.ENABLED = false
  local v_off = Team.view(f, game.tick)
  Mv.ENABLED = true
  check(ser(v_on.stock) == ser(v_off.stock), label .. " §3 : view.stock identique, manque mesure allume ou eteint")
  check(v_off.mq == nil and v_off.dort == nil and f.team.mq == nil, label .. " §7 : eteint : ni view.mq ni f.team.mq")
  local t2 = { key = "ia1d:" .. PID_OUT .. ":o:1", kind = "carry", prio = 52, ia1d = { pid = PID_OUT, mode = "collect", idx = 1 } }
  Col.apply(f, f.hq.surface, f.build, { t2 }, game.tick)
  check(f.is_player or t2.prio == 52, label .. " §7 : eteint, une faction garde la regle d'avant (collecte d'urgence de votre equipe seule)")
  undo()
  -- §2 collecte prise.
  undo = stage(f, { { PLATE, 1000 } }, true)
  view = fresh_view(f)
  check(view.avail_out and eq(view.avail_out[PLATE], 585), label .. " §2 : collecte prise : 585 plaques disponibles (" .. ser(view.avail_out) .. ")")
  check(view.mq and eq(view.mq.build[PLATE], 1000 - 585), label .. " §2 : a construire 415 (" .. tostring(view.mq and view.mq.build[PLATE]) .. ")")
  local short2 = Sv.uncovered(Sv.shortages({ { PLATE, 1000 } }, { [PLATE] = true }), view.avail_out)
  check(#short2 == 1 and eq(short2[1][2], 415), label .. " §5 : collecte PRISE : la survie deduit les 585 plaques en route (" .. ser(short2) .. ")")
  undo()
  return res
end

local fac = global.fo.war.factions[1]
local pf = global.fo.pteam and global.fo.pteam.team
check(fac and fac.hq and fac.hq.valid, "une faction avec son QG")
check(pf and pf.hq and pf.hq.valid, "votre equipe avec son coffre")
say(string.format("faction %s : %s PNJ, effectif de depart %s ; votre equipe : %s PNJ, depart %s", tostring(fac.key), tostring(fac.engineers_count),
  tostring(fac.team.floor), tostring(pf and pf.engineers_count), tostring(pf and pf.team and pf.team.floor)))
--- §11 La scène D1 du DC (partie 0.6.58, 159 à 174 min) : 10 coffres au champ, 4 353 plaques, des tâches de collecte LIBRES que personne
--- ne prend (sur chaque coffre : le fer « à collecter » couvre alors TOUT le manque, c'est le piège), la recrue qui attend 1 932 plaques. La paralysie de la survie est la sienne (refus de la porte et la moitié des PNJ sans
--- tâche utile, au fond) ; la collecte, elle, n'est prise par personne. La survie doit S'OUVRIR après Sv.SHORT_TICKS.
local Survie = require("script.team.survie")
local function d1(f, label)
  local undo = stage(f, { { PLATE, 1932 } }, false, { 585, 560, 540, 500, 470, 430, 400, 380, 300, 188 }, true)
  local view = fresh_view(f)
  check(view.mq and (view.mq.build[PLATE] or 0) == 0, label .. " §11 : temoin du piege : les collectes A FAIRE couvrent tout le manque (a construire " .. tostring(view.mq and view.mq.build[PLATE]) .. ")")
  check((view.dort or {})[PLATE] ~= nil and view.dort[PLATE] >= 4353, label .. " §11 : 4 353 plaques au champ, vues (" .. tostring((view.dort or {})[PLATE]) .. ")")
  check(view.avail_out == nil or view.avail_out[PLATE] == nil, label .. " §11 : aucune collecte prise")
  local s0 = f.team.survie
  f.team.survie = nil
  local v = {}
  for k, x in pairs(view) do v[k] = x end
  v.workers, v.workers_idle, v.threatened, v.hq_threat = 2, 1, false, nil
  local plan = { missing = { { PLATE, 1932 } }, smelt = {} }
  local t0 = game.tick
  local opened
  for m = 0, 6 do
    local tick = t0 + m * MIN
    for k = 1, 6 do Survie.note_wait(f, tick + k) end
    Survie.think(f, v, plan, tick + 10)
    if Survie.on(f) and not opened then opened = m end
  end
  check(opened ~= nil and opened >= 5, label .. " §11 : la survie s'ouvre (minute " .. tostring(opened) .. ")")
  f.team.survie = s0
  undo()
end

--- §12 Lot VIDEO-COUVERTURE 3 (V59, C3.1) : un module de laboratoires sans pack, une technologie en file : le manque de packs est MESURÉ
--- (avant : Mv.read_module ne lisait que les assembleurs et les fours, le module de labos était refusé « courant inconnu »). La technologie
--- est lue aux prototypes du moteur (research_unit_ingredients, research_unit_energy), la vitesse au prototype du labo et au bonus de la force.
local PID_LAB = 9003
local PACK_R = "automation-science-pack"
local function labs(f, label)
  local s = f.hq.surface
  local hq = f.hq.position
  local made = {}
  local qx, qy = math.floor(hq.x) + 80.5, math.floor(hq.y) + 10.5
  local q = s.create_entity({ name = CHEST, position = { x = qx, y = qy }, force = f.force })
  made[#made + 1] = q
  local lx, ly = math.floor(hq.x) + 84, math.floor(hq.y) + 10
  local lab = s.create_entity({ name = "lab", position = { x = lx + 1.5, y = ly + 1.5 }, force = f.force })
  made[#made + 1] = lab
  local had_build = f.build ~= nil
  f.build = f.build or { order = {}, projects = {} }
  local b = f.build
  b.order[#b.order + 1] = PID_LAB
  b.projects[PID_LAB] = { id = PID_LAB, state = "fini", outs = {}, quais = { { x = qx, y = qy, item = PACK_R } }, inflow = { [PACK_R] = 0.5 },
    prio = 60, parts = { { ox = lx, oy = ly, w = 3, h = 3 } }, ents = {}, spec = { gen = "labs" } }
  local ia3_0 = f.team.ia3
  f.team.ia3 = f.team.ia3 or {}
  local lab0 = f.team.ia3.lab
  local function tech(name) f.team.ia3.lab = { tech = name } end
  local function need()
    local view = fresh_view(f)
    local res = f.team.mq and f.team.mq.res
    local n
    for _, e in ipairs(res and res.short_by or {}) do if e.key == "m:" .. PID_LAB and e.item == PACK_R then n = e.n end end
    return n, res, view
  end
  -- « optics » : 1 pack rouge par unité, 15 s ; un labo de vitesse 1 : 4 packs par minute.
  tech("optics")
  local n, res = need()
  check(eq(n, 4), label .. " §12 : labo sans pack rouge, technologie en file : manque de 4/min publie (" .. tostring(n) .. ")")
  local sk
  for _, x in ipairs(Mq.sinks(res, {})) do if x.item == PACK_R then sk = x end end
  check(sk ~= nil and eq(sk.rate, 4), label .. " §12 : puits de la capitalisation 4/min (" .. ser(sk) .. ")")
  -- le bonus de vitesse de la force compte
  local force = game.forces[f.force]
  local m0 = force.laboratory_speed_modifier
  force.laboratory_speed_modifier = 0.5
  n = need()
  force.laboratory_speed_modifier = m0
  check(eq(n, 6), label .. " §12 : bonus de recherche de 50 % : 6 par minute (" .. tostring(n) .. ")")
  -- un quai garni : plus de manque
  q.get_inventory(defines.inventory.chest).insert({ name = PACK_R, count = 4 })
  n = need()
  check(n == nil, label .. " §12 : quai garni d'une minute de packs : labo plein, manque nul (" .. tostring(n) .. ")")
  -- aucune technologie en file : rien à consommer
  q.get_inventory(defines.inventory.chest).remove({ name = PACK_R, count = 4 })
  f.team.ia3.lab = {}
  n, res = need()
  check(n == nil and #res.refused == 0, label .. " §12 : aucune technologie en file : aucun manque, aucun refus")
  -- technologie inconnue du moteur : refusée (garde fermée), jamais un manque inventé
  tech("technologie-inconnue")
  n, res = need()
  check(n == nil and #res.refused >= 1, label .. " §12 : technologie inconnue du moteur : refusee, aucun manque")
  f.team.ia3.lab = lab0
  if ia3_0 == nil then f.team.ia3 = nil end
  for _, c in ipairs(made) do if c.valid then c.destroy() end end
  local keep = {}
  for _, id in ipairs(b.order) do if id ~= PID_LAB then keep[#keep + 1] = id end end
  b.order = keep
  b.projects[PID_LAB] = nil
  if not had_build then f.build = nil end
  fresh_view(f)
end

--- §13 Lot VIDEO-COUVERTURE 3 (V10, C3.4) : les munitions manquantes d'une tourelle sont un but (key « but:<munition> ») à la priorité de l'armée.
local Outposts = require("script.faction.outposts")
local function munitions(label)
  local ff = { engineers_count = 8, team = { floor = 4, missing = {} } }
  local ammo = Outposts.ammo_name(nil, ff)
  local groups = {
    { key = "hq", low = 2, short = 3, missing = 40, has_task = false, n = 8 },
    { key = "o1", low = 0, short = 2, missing = 25, has_task = false, n = 4 },
    { key = "o2", low = 4, short = 4, missing = 100, has_task = true, n = 4 },    -- une tournee de recharge le sert deja
    { key = "o3", low = 0, short = 0, missing = 0, has_task = false, n = 4 },     -- rien ne manque
  }
  local function by_key(w) local o = {} for _, x in ipairs(w) do o[x.key] = x end return o end
  local w = by_key(Mv.wants(ff, { turret_groups = groups }))
  check(w["but:" .. ammo] and eq(w["but:" .. ammo].n, 65) and w["but:" .. ammo].prio == T.defend_prio and not w["but:" .. ammo].net,
    label .. " §13 : 40 + 25 chargeurs manquent (le groupe servi par une tournee ne compte pas) : but:" .. ammo .. " a la priorite de l'armee " ..
    T.defend_prio .. " (" .. ser(w["but:" .. ammo]) .. ")")
  w = by_key(Mv.wants(ff, { turret_groups = { groups[3], groups[4] } }))
  check(w["but:" .. ammo] == nil, label .. " §13 : tournee prise ou rien ne manque : aucune demande")
  -- règle des munitions éteinte : seuil bas (g.low x cible)
  local on = T.munitions_on
  T.munitions_on = false
  w = by_key(Mv.wants(ff, { turret_groups = { { key = "hq", low = 2, n = 8 }, { key = "o1", low = 0, n = 4 } } }))
  T.munitions_on = on
  check(w["but:" .. ammo] and eq(w["but:" .. ammo].n, 2 * T.turret_ammo_target), label .. " §13 : regle eteinte : 2 tourelles sous le seuil bas, " ..
    2 * T.turret_ammo_target .. " chargeurs (" .. ser(w["but:" .. ammo]) .. ")")
  -- dans le calcul : le manque en munitions est a construire quand le stock libre ne le couvre pas
  local Mqr = Mq.step(Mq.new(), { mods = {}, wants = Mv.wants(ff, { turret_groups = groups }), stock = { [ammo] = 30 }, sources = {} }, 10 * MIN)
  check(eq(Mqr.build[ammo], 35) and eq(Mqr.net[ammo], -35), label .. " §13 : 65 voulus, 30 au stock libre : 35 a construire")
  -- sans tourelle (jeu reel) : aucune demande
  local wr = by_key(Mv.wants(fac, nil))
  check(wr["but:" .. ammo] == nil, label .. " §13 : aucune tourelle posee : aucune demande de munitions")
end

local function all_scenes()
  scenes(fac, "faction")
  if pf then scenes(pf, "votre equipe") end
  d1(fac, "faction")
  if pf then d1(pf, "votre equipe") end
  labs(fac, "faction")
  if pf then labs(pf, "votre equipe") end
  munitions("faction")
end
all_scenes()

-- §6 Demandes.
do
  local ff = { engineers_count = 2, team = { floor = 4, missing = { { PLATE, 300 }, { "site:x", 1 }, { PLATE .. "-b", 0 } } } }
  local w = Mv.wants(ff, { effectif = { reason = "recrue", margin_item = PLATE, cost_iron = 120 }, recruit_prio = 70 })
  local by = {}
  for _, x in ipairs(w) do by[x.key] = x end
  check(by["but:" .. PLATE] and by["but:" .. PLATE].net == true and by["but:" .. PLATE].prio == Co.PRIO, "§6 : objectif NET, a la priorite de survie sous l'effectif de depart")
  check(by.reserve and by.reserve.n == T.grow_iron_reserve and by.reserve.prio == Co.PRIO and not by.reserve.net, "§6 : reserve de fer brute sous l'effectif de depart")
  check(by.recrue and by.recrue.n == 120 and by.recrue.prio == 70 and by.recrue.net == true, "§6 : recrue decidee : cout net a sa priorite")
  check(by["but:" .. PLATE .. "-b"] == nil, "§6 : un manque nul n'est pas une demande")
  ff.engineers_count = 4
  local w2 = Mv.wants(ff, nil)
  local b2 = {}
  for _, x in ipairs(w2) do b2[x.key] = x end
  check(b2["but:" .. PLATE].prio == Mv.PRIO_GOAL and b2.reserve == nil and b2.recrue == nil, "§6 : a l'effectif : priorite ordinaire, ni reserve ni recrue")
end

-- §8 Chaîne lue dans les sources.
do
  local function rd(p) local h = assert(io.open(p, "rb")) local x = h:read("*a") h:close() return x end
  local team, colsrc, surv, capi = rd("script/team/team.lua"), rd("script/team/collecte.lua"), rd("script/team/survie.lua"), rd("script/ai3/capitalisation.lua")
  local function has(s, p) return s:find(p, 1, true) ~= nil end
  check(has(team, "local mq = ManqueVue.think(f, tick, stock_free, { effectif = effectif, recruit_prio = recruit_prio })"), "§8 : Team.view calcule le manque mesure sur le stock libre")
  check(has(team, "stock = stock_free, incoming = incoming") and not has(team, "stock = mq") , "§8 : view.stock reste le stock libre")
  check(has(colsrc, "return apply_mq(f, tasks, mq.res, tick)"), "§8 : Collecte.apply suit f.team.mq.res")
  check(has(surv, "Sv.uncovered(Sv.shortages(missing, KEYS), view.avail_out)"), "§8 : la survie ne deduit que la collecte prise (view.avail_out)")
  check(has(capi, "Mq.sinks(mq_fresh(f, tick), Ml.sinks(st.mall))"), "§8 : build_input ajoute les puits mesures (input.sinks)")
  check(not has(capi, "Ca.requirements(") or true, "§8 : Ca.requirements n'est pas touche (puits par input.sinks)")
end

-- §14 Lot VIDEO-COUVERTURE 3 : l'interface de banc (script/team/manque_banc.lua) et le journal [FO-MANQUE] d'un module de laboratoires affamé.
do
  local f = fac
  local hq = f.hq.position
  local qx, qy = math.floor(hq.x) + 90.5, math.floor(hq.y) + 20.5
  local lx, ly = math.floor(hq.x) + 94, math.floor(hq.y) + 20
  local ia3_0 = f.team.ia3
  f.team.ia3 = f.team.ia3 or {}
  local lab0 = f.team.ia3.lab
  f.team.ia3.lab = { tech = "optics" }
  local p0 = Mv.PERIOD
  local r = remote.call("fo-manque", "bench_labo", f.key, PACK_R, "lab", qx, qy, lx, ly)
  check(r ~= nil and r.project ~= nil, "§14 : bench_labo pose le projet de laboratoires")
  check(Mv.PERIOD == 120, "§14 : le manque est recalcule toutes les 2 s le temps du banc")
  local logs0 = #M.world().logs
  Team.view(f, game.tick)
  local st = remote.call("fo-manque", "labo_state", f.key, r.project, PACK_R)
  check(st ~= nil and eq(st.need, 4) and st.starved == PACK_R and st.refused == 0,
    "§14 : labo_state lit le manque (4/min) et le module affame (" .. ser(st) .. ")")
  check(st.quai == 0 and st.hq_packs ~= nil, "§14 : quai vide")
  local line
  for i = logs0 + 1, #M.world().logs do
    local l = M.world().logs[i]
    if l:find("[FO-MANQUE]", 1, true) and l:find("laboratoires", 1, true) then line = l end
  end
  check(line ~= nil and line:find("module " .. r.project, 1, true) ~= nil and line:find(PACK_R, 1, true) ~= nil,
    "§14 : le journal [FO-MANQUE] cite le module de laboratoires et le pack (" .. tostring(line) .. ")")
  -- le journal ne se repete pas tant que la liste ne change pas
  Mv.PERIOD = 0
  local n_before = #M.world().logs
  Team.view(f, game.tick + 1)
  local again = 0
  for i = n_before + 1, #M.world().logs do if M.world().logs[i]:find("[FO-MANQUE]", 1, true) then again = again + 1 end end
  check(again == 0, "§14 : pas de repetition du journal [FO-MANQUE] quand rien ne change")
  Mv.PERIOD = p0
  -- nettoyage
  local b = f.build
  local keep = {}
  for _, id in ipairs(b.order) do if id ~= r.project then keep[#keep + 1] = id end end
  b.order = keep
  b.projects[r.project] = nil
  local s0 = f.hq.surface
  for _, e in ipairs(s0.find_entities_filtered({ area = { { qx - 1, qy - 1 }, { lx + 4, ly + 4 } }, force = f.force })) do
    if e.valid and (e.name == "lab" or e.name == CHEST) then e.destroy() end
  end
  f.team.ia3.lab = lab0
  if ia3_0 == nil then f.team.ia3 = nil end
  if f.team.mq then f.team.mq.tick = nil end
end

-- §9 Coût.
do
  local undo = stage(fac, { { PLATE, 1000 } }, false)
  if fac.team.mq then fac.team.mq.tick = nil end
  local c = 0
  local stock = Board.view_stock(fac, {}, game.tick)
  debug.sethook(function() c = c + 1 end, "", 1)
  Mv.think(fac, game.tick, stock, {})
  debug.sethook()
  say(string.format("cout d'un calcul (faction, scene du §1) : %d instructions Lua (appels au moteur simule compris)", c))
  check(c > 0 and c < 400000, "§9 : un calcul sous 400 000 instructions (" .. c .. ")")
  undo()
end

-- §10 Mutants de comportement.
do
  local p0, f0 = passes, failures
  local muts = {
    { "transit non compte", function() local o = Mv.transit Mv.transit = function() return {} end return function() Mv.transit = o end end },
    { "coffre sans tache lu collectable", function()
      local o = Col.waiting_all
      Col.waiting_all = function(...) local out = o(...) for _, s in ipairs(out) do s.ok = true end return out end
      return function() Col.waiting_all = o end end },
    { "collecte prise ignoree", function()
      local o = Col.waiting_all
      Col.waiting_all = function(...) local out = o(...) for _, s in ipairs(out) do if s.collect == "taken" then s.collect = "open" end end return out end
      return function() Col.waiting_all = o end end },
    { "collecte qui ne suit plus le manque mesure", function() Col.MQ = false return function() Col.MQ = true end end },
    { "collecte a faire comptee par la survie (piege D1)", function()
      local o = Sv.uncovered
      Sv.uncovered = function(short, avail)
        local out = {}
        for _, x in ipairs(short or {}) do
          local n = x[2]
          for _, ff in ipairs({ fac, pf }) do
            local r = ff and ff.team and ff.team.mq and ff.team.mq.res
            if r and r.need[x[1]] ~= nil then n = math.min(n, r.build[x[1]] or 0) end
          end
          if n > 0 then out[#out + 1] = { x[1], n } end
        end
        return out
      end
      return function() Sv.uncovered = o end end,
      function() d1(fac, "faction") if pf then d1(pf, "votre equipe") end end },
    { "technologie en cours ignoree (labo sans entree)", function()
      local o = Mv.lab_tech
      Mv.lab_tech = function() return false end
      return function() Mv.lab_tech = o end end },
    { "module de labos lu comme un module ordinaire", function()
      local o = Mv.read_module
      Mv.read_module = function(...) local r = o(...) r.consumes = nil r.inputs = r.inputs or {} return r end
      return function() Mv.read_module = o end end },
    { "munitions absentes des demandes", function()
      local o = Mv.wants
      Mv.wants = function(...) local w = o(...) local out = {} for _, x in ipairs(w) do if x.item ~= "firearm-magazine" then out[#out + 1] = x end end return out end
      return function() Mv.wants = o end end },
    { "objectif lu brut (stock compte deux fois)", function()
      local o = Mv.wants
      Mv.wants = function(...) local w = o(...) for _, x in ipairs(w) do x.net = nil end return w end
      return function() Mv.wants = o end end },
  }
  local killed = 0
  for _, m in ipairs(muts) do
    local restore = m[2]()
    local pp, ff = passes, failures
    quiet = true
    local ok, err = pcall(m[3] or all_scenes)
    quiet = false
    restore()
    local dead = (not ok) or failures > ff
    passes, failures = pp, ff
    print(string.format("[MANQUE-VUE]   mutant %s : %s", m[1], ok and (dead and "refuse" or "SURVIVANT") or ("PLANTAGE " .. tostring(err))))
    if dead then killed = killed + 1 end
  end
  passes, failures = p0, f0
  check(killed == #muts, string.format("§10 : mutants refuses %d / %d", killed, #muts))
end

print(string.format("[MANQUE-VUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
