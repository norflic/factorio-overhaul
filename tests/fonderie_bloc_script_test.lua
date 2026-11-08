--[[
  Lot FONDERIE-BLOC (8/11) : le SCRIPT (script/team/fonderie_bloc.lua) joué hors jeu contre un monde fictif minimal. Ce n'est PAS le moteur : il
  prouve l'enchaînement relevé -> décision -> demande -> plan -> suivi, les causes de refus et le journal, avant tout banc.
    §1 relevé, confirmation, demande ; §2 quai déjà servi, piquage pas conclu, plafond, menace ; §3 suivi (fini, coupé, refusé) ;
    §4 plan (bras, poteau, arrivée, réservation, repli sur un autre côté, échec rendu proprement) ; §5 pire cas en instructions.
  Usage : lua5.2 tests/fonderie_bloc_script_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end

local LOGS = {}
log = function(s) LOGS[#LOGS + 1] = s end
local function logs_with(txt)
  local n = 0
  for _, l in ipairs(LOGS) do if l:find(txt, 1, true) then n = n + 1 end end
  return n
end
defines = { inventory = { chest = 1 } }
remote = { add_interface = function() end }
game = { tick = 0 }
local THREAT, ENEMY = false, false
package.loaded["script.faction.state"] = {
  sorted_keys = function(t) local ks = {} for k in pairs(t) do ks[#ks + 1] = k end table.sort(ks) return ks end,
}
package.loaded["script.ai3.reserve"] = { on = function() return true end }
package.loaded["script.companion.registry"] = { get = function() return { entity = { valid = true } } end }

local FB = require("script.team.fonderie_bloc")
local Fb = require("shared.team.fonderie_bloc")
local P = require("shared.team.plan")

local CHESTS = { ["10:10"] = true }
local surface = {
  find_entities_filtered = function(q)
    local x, y = q.position[1], q.position[2]
    if CHESTS[math.floor(x) .. ":" .. math.floor(y)] then return { { valid = true } } end
    return {}
  end,
  count_entities_filtered = function() return THREAT and 1 or 0 end,
  find_nearest_enemy = function() return ENEMY and {} or nil end,
}

local function new_world()
  local b = {
    order = { 1, 2 }, occ = {}, next_id = 10, plant = 1,
    projects = {
      [1] = { id = 1, state = "fini", ents = {}, quais = {} },
      [2] = { id = 2, state = "fini", spec = { champ = { oid = 1 } }, ents = {
        { name = "inserter", role = "champ-bras", x = 9.5, y = 10.5 }, { name = "small-electric-pole", role = "champ-poteau", x = 5.5, y = 5.5 } },
        quais = { { x = 10.5, y = 10.5, item = "coal", flow = 0.27 } } },
    },
    piquage = { links = {}, quais = { ["2:q1"] = { verdict = "laisser", cause = "aucune_source", tick = 0 } } },
    liaison = { links = {} },
  }
  local f = { key = "player", force = "player", build = b, hq_pos = { x = 0, y = 0 }, engineers = { 1, 2 } }
  return f, b
end

local REQ = {}
local api = { prio = 56, request = function(f, spec)
  local id = f.build.next_id
  f.build.next_id = id + 1
  REQ[#REQ + 1] = spec
  f.build.projects[id] = { id = id, state = "attente", spec = spec, ents = {}, quais = {}, parts = {} }
  f.build.order[#f.build.order + 1] = id
  return id
end }

local function run(f, from, to)
  for t = from, to, 5 do FB.step(api, f, surface, t) end
end

---------------------------------------------------------------------------------------------------
-- §1 relevé, confirmation, demande
---------------------------------------------------------------------------------------------------
local f, b = new_world()
run(f, 0, Fb.PERIOD * 4)
check(#REQ == 1, "une alimentation demandee apres la confirmation (" .. #REQ .. ")")
local spec = REQ[1] and REQ[1].alimquai
check(spec ~= nil, "la demande porte spec.alimquai")
if spec then
  check(spec.item == "coal" and math.abs(spec.flow - 0.27) < 1e-9, "objet et debit du quai")
  check(spec.arm == "inserter", "bras electrique du champ (" .. tostring(spec.arm) .. ")")
  check(spec.pole == "small-electric-pole", "poteau du champ (" .. tostring(spec.pole) .. ")")
  check(spec.dock.pid == 2 and spec.dock.idx == 1 and spec.dock.x == 10 and spec.dock.y == 10, "coordonnees du quai")
  check(REQ[1].prio == 56 and REQ[1].domain == "infrastructures" and REQ[1].pile == "capital", "priorite, domaine et pile d'un investissement")
end
check(b.fonderie_bloc ~= nil and b.fonderie_bloc.n.demandes == 1, "compteur de demandes")
check(logs_with("alimentation demandee") == 1, "une ligne de demande au journal")
check(logs_with("[FO-FONDERIE-BLOC] player : quai 2:q1 (coal, 0.27/s)") >= 1, "format du journal")
check(logs_with("a confirmer") >= 1, "l'attente de confirmation est ecrite")
-- pas de seconde demande tant que la premiere est ouverte
run(f, Fb.PERIOD * 4, Fb.PERIOD * 9)
check(#REQ == 1, "pas de seconde demande pendant que la premiere est ouverte")

---------------------------------------------------------------------------------------------------
-- §2 cas où l'on n'agit pas
---------------------------------------------------------------------------------------------------
do
  local f2, b2 = new_world()
  b2.liaison.links["2:q1"] = { pid = 99 }
  REQ = {}
  run(f2, 0, Fb.PERIOD * 6)
  check(#REQ == 0, "quai deja servi par une liaison : aucune demande")
  local f3, b3 = new_world()
  b3.piquage.links["2:q1"] = { pid = 99 }
  REQ = {}
  run(f3, 0, Fb.PERIOD * 6)
  check(#REQ == 0, "quai deja servi par un piquage : aucune demande")
  local f4, b4 = new_world()
  b4.piquage.quais["2:q1"] = { verdict = "attente", cause = "releves_insuffisants" }
  REQ = {}
  run(f4, 0, Fb.PERIOD * 6)
  check(#REQ == 0, "piquage pas conclu : aucune demande")
  local f4b, b4b = new_world()
  b4b.piquage.quais = {}
  REQ = {}
  run(f4b, 0, Fb.PERIOD * 6)
  check(#REQ == 0, "piquage sans verdict : aucune demande")
  local f5, b5 = new_world()
  b5.projects[2].quais[1].flow = nil
  REQ = {}
  run(f5, 0, Fb.PERIOD * 6)
  check(#REQ == 0, "quai sans debit (champ d'avant le lot) : aucune demande")
  local f6 = new_world()
  f6.hq = { valid = true }
  THREAT = true
  REQ = {}
  run(f6, 0, Fb.PERIOD * 6)
  THREAT = false
  check(#REQ == 0, "QG menace : aucune demande")
  local f7 = new_world()
  ENEMY = true
  REQ = {}
  run(f7, 0, Fb.PERIOD * 6)
  ENEMY = false
  check(#REQ == 0, "ennemi a portee du coffre : aucune demande")
  local f8, b8 = new_world()
  b8.projects[1].state = "plan"
  REQ = {}
  run(f8, 0, Fb.PERIOD * 6)
  check(#REQ == 0, "centrale pas finie : aucune demande")
  local f9, b9 = new_world()
  b9.projects[2].state = "construction"
  REQ = {}
  run(f9, 0, Fb.PERIOD * 6)
  check(#REQ == 0, "projet de champ pas fini : aucune demande")
  local f10 = new_world()
  CHESTS["10:10"] = nil
  REQ = {}
  run(f10, 0, Fb.PERIOD * 6)
  CHESTS["10:10"] = true
  check(#REQ == 0, "coffre detruit : aucune demande")
  local f11 = new_world()
  f11.engineers = {}
  REQ = {}
  run(f11, 0, Fb.PERIOD * 6)
  check(#REQ == 0, "aucun PNJ libre : aucune demande")
  -- un seul projet ouvert a la fois, meme avec deux quais
  local f12, b12 = new_world()
  b12.projects[2].quais[2] = { x = 20.5, y = 20.5, item = "coal", flow = 0.2 }
  b12.piquage.quais["2:q2"] = { verdict = "laisser", cause = "aucune_source" }
  CHESTS["20:20"] = true
  REQ = {}
  run(f12, 0, Fb.PERIOD * 8)
  CHESTS["20:20"] = nil
  check(#REQ == 1, "deux quais sans source : une seule alimentation ouverte (" .. #REQ .. ")")
  check(REQ[1] and REQ[1].alimquai.dock.idx == 1, "le premier quai (cle la plus petite) passe d'abord")
end

---------------------------------------------------------------------------------------------------
-- §3 suivi
---------------------------------------------------------------------------------------------------
do
  local f2, b2 = new_world()
  REQ = {}
  LOGS = {}
  run(f2, 0, Fb.PERIOD * 4)
  local pid = REQ[1] and b2.fonderie_bloc.links["2:q1"].pid
  check(pid ~= nil, "lien garde")
  b2.projects[pid].state = "fini"
  b2.projects[pid].ents = { {}, {} }
  run(f2, Fb.PERIOD * 4, Fb.PERIOD * 7)
  check(b2.fonderie_bloc.links["2:q1"].done == true and b2.fonderie_bloc.n.finis == 1, "projet fini : lien fait")
  check(logs_with("alimentation finie") == 1, "ligne de fin")
  check(#REQ == 1, "quai servi : plus de demande")
  b2.projects[pid].state = "pose"
  run(f2, Fb.PERIOD * 7, Fb.PERIOD * 9)
  check(b2.fonderie_bloc.links["2:q1"].done == false and b2.fonderie_bloc.n.coupees == 1, "projet rouvert : alimentation coupee")
  check(logs_with("alimentation coupee") == 1, "ligne de coupure")
  b2.projects[pid].state = "refuse"
  b2.projects[pid].reason = "foreuses : aucun gisement"
  run(f2, Fb.PERIOD * 9, Fb.PERIOD * 11)
  check(b2.fonderie_bloc.links["2:q1"] == nil and b2.fonderie_bloc.n.refuses == 1, "projet refuse : lien retire")
  check(logs_with("foreuses : aucun gisement") == 1, "la cause du refus est ecrite")
  check(logs_with("le PNJ continue a la main") == 1, "le repli PNJ est dit")
  -- essais : un ecart entre deux essais (compte depuis la demande), deux au plus, puis attente
  local st2 = b2.fonderie_bloc
  local t_first = st2.last_try["2:q1"]
  run(f2, Fb.PERIOD * 11, t_first + Fb.RETRY_GAP - Fb.PERIOD * 2)
  check(#REQ == 1, "pas de nouvel essai avant l'ecart entre deux essais (" .. #REQ .. ")")
  run(f2, t_first + Fb.RETRY_GAP - Fb.PERIOD * 2, t_first + Fb.RETRY_GAP + Fb.PERIOD * 4)
  check(#REQ == 2, "un nouvel essai apres l'ecart (" .. #REQ .. ")")
  local last = st2.links["2:q1"] and st2.links["2:q1"].pid
  check(last ~= nil, "le deuxieme essai est ouvert")
  if last then b2.projects[last].state = "refuse"; b2.projects[last].reason = "x" end
  local t2 = st2.last_try["2:q1"]
  run(f2, t_first + Fb.RETRY_GAP + Fb.PERIOD * 4, t2 + Fb.RETRY_AFTER - Fb.PERIOD * 4)
  check(#REQ == 2, "essais epuises : pas de troisieme demande avant le delai (" .. #REQ .. ")")
  run(f2, t2 + Fb.RETRY_AFTER - Fb.PERIOD * 4, t2 + Fb.RETRY_AFTER + Fb.PERIOD * 8)
  check(#REQ == 3, "delai passe : un essai de plus (" .. #REQ .. ")")
end

---------------------------------------------------------------------------------------------------
-- §4 plan
---------------------------------------------------------------------------------------------------
local function plan_api(b, drills_ok, fail_counter)
  return {
    read_masks = function() return { water = {}, blocked = {}, clear = {} } end,
    reserve_tiles = function(bb, p, list)
      for _, e in ipairs(list) do
        for _, t in ipairs(P.tiles_of(e)) do
          local k = P.tkey(t[1], t[2])
          if bb.occ[k] and bb.occ[k] ~= p.id then return false end
        end
      end
      for _, e in ipairs(list) do
        for _, t in ipairs(P.tiles_of(e)) do bb.occ[P.tkey(t[1], t[2])] = p.id end
        p.ents[#p.ents + 1] = e
      end
      return true
    end,
    plan_drills = function(f, surface_, p, item, flow, a, belt)
      fail_counter.n = fail_counter.n + 1
      fail_counter.arrivals[#fail_counter.arrivals + 1] = a
      if drills_ok and drills_ok(fail_counter.n) then
        p.parts[#p.parts + 1] = { kind = "foreuses", drills = 4 }
        p.ents[#p.ents + 1] = { name = "transport-belt", x = a.x + 0.5, y = a.y + 0.5, dir = a.dir, role = "liaison-tapis", part = 1 }
        b.occ[P.tkey(a.x, a.y)] = p.id
        return true
      end
      return false, "aucun gisement"
    end,
    finish = function() return true end,
  }
end
do
  local f2, b2 = new_world()
  local p = { id = 7, state = "plan", spec = { alimquai = { key = "2:q1", item = "coal", flow = 0.27, arm = "inserter", pole = "small-electric-pole",
    dock = { pid = 2, idx = 1, x = 10, y = 10 } } }, parts = {}, ents = {}, quais = {} }
  b2.projects[7] = p
  local cnt = { n = 0, arrivals = {} }
  LOGS = {}
  local ok, why = FB.plan(plan_api(b2, function() return true end, cnt), f2, surface, p)
  check(ok == true, "plan rendu : " .. tostring(why))
  check(cnt.n == 1, "la ligne de foreuses est planifiee une fois quand le premier cote passe")
  local arm, pole, belt
  for _, e in ipairs(p.ents) do
    if e.role == "liaison-bras" then arm = e elseif e.role == "liaison" then pole = e elseif e.role == "liaison-tapis" then belt = e end
  end
  check(arm ~= nil and pole ~= nil and belt ~= nil, "bras, poteau et tapis d'arrivee dans le projet")
  if arm and belt then
    local DV = P.DV[arm.dir]
    check(math.floor(arm.x) + DV[1] == math.floor(belt.x) and math.floor(arm.y) + DV[2] == math.floor(belt.y), "le bras prend sur la tuile d'arrivee")
    check(math.floor(arm.x) - DV[1] == 10 and math.floor(arm.y) - DV[2] == 10, "le bras depose dans le coffre")
    local W = P.DV[belt.dir]
    check(math.floor(belt.x) + W[1] == math.floor(arm.x) and math.floor(belt.y) + W[2] == math.floor(arm.y), "la derniere tuile mene au bras")
  end
  check(p.parts[1] and p.parts[1].kind == "foreuses" and p.parts[2] and p.parts[2].kind == "liaison" and p.parts[2].power == false, "parts : foreuses puis bras sans courant propre")
  check(arm and arm.part == 2 and pole and pole.part == 2, "bras et poteau dans la part 2")
  check(p.counted == true, "projet non compte aux modules")
  check(b2.occ[P.tkey(math.floor(arm.x), math.floor(arm.y))] == 7, "tuile du bras reservee")
  check(logs_with("alimentation planifiee") == 1, "ligne de plan au journal")
  check(logs_with("4 foreuse(s)") == 1, "nombre de foreuses au journal")
end
do
  -- le premier cote echoue, le suivant passe ; les tuiles du premier sont rendues
  local f2, b2 = new_world()
  local p = { id = 7, state = "plan", spec = { alimquai = { key = "2:q1", item = "coal", flow = 0.27, arm = "inserter", pole = "small-electric-pole",
    dock = { pid = 2, idx = 1, x = 10, y = 10 } } }, parts = {}, ents = {}, quais = {} }
  b2.projects[7] = p
  local cnt = { n = 0, arrivals = {} }
  local ok = FB.plan(plan_api(b2, function(n) return n >= 2 end, cnt), f2, surface, p)
  check(ok == true and cnt.n == 2, "le deuxieme cote passe (" .. cnt.n .. " essais)")
  local a1, a2 = cnt.arrivals[1], cnt.arrivals[2]
  check(a1 and a2 and (a1.x ~= a2.x or a1.y ~= a2.y), "deux arrivees differentes")
  local nocc, mine = 0, 0
  for _, k in ipairs((function() local ks = {} for k in pairs(b2.occ) do ks[#ks + 1] = k end table.sort(ks) return ks end)()) do
    nocc = nocc + 1
    if b2.occ[k] == 7 then mine = mine + 1 end
  end
  check(mine == 3, "seules les tuiles du dernier plan sont reservees : bras, poteau, tapis (" .. mine .. ")")
end
do
  -- tout echoue : la raison est rendue, rien n'est reserve
  local f2, b2 = new_world()
  local p = { id = 7, state = "plan", spec = { alimquai = { key = "2:q1", item = "coal", flow = 0.27, arm = "inserter", pole = "small-electric-pole",
    dock = { pid = 2, idx = 1, x = 10, y = 10 } } }, parts = {}, ents = {}, quais = {} }
  b2.projects[7] = p
  local cnt = { n = 0, arrivals = {} }
  local ok, why = FB.plan(plan_api(b2, function() return false end, cnt), f2, surface, p)
  check(ok == false and tostring(why):find("aucun gisement", 1, true) ~= nil, "echec : la cause du gisement est rendue (" .. tostring(why) .. ")")
  check(cnt.n == Fb.MAX_SITES, "tous les cotes sont essayes (" .. cnt.n .. ")")
  local any = false
  for _, v in pairs(b2.occ) do if v == 7 then any = true end end
  check(not any, "aucune tuile reservee apres l'echec")
  check(#p.ents == 0 and #p.parts == 0, "projet vide apres l'echec")
  -- coffre disparu, projet du quai absent, pieces inconnues
  CHESTS["10:10"] = nil
  local ok2, why2 = FB.plan(plan_api(b2, function() return true end, { n = 0, arrivals = {} }), f2, surface, p)
  CHESTS["10:10"] = true
  check(ok2 == false and why2:find("coffre du quai disparu", 1, true) ~= nil, "coffre disparu : refus")
  b2.projects[2].state = "construction"
  local ok3, why3 = FB.plan(plan_api(b2, function() return true end, { n = 0, arrivals = {} }), f2, surface, p)
  check(ok3 == false and why3:find("projet du quai", 1, true) ~= nil, "projet du quai pas fini : refus")
  b2.projects[2].state = "fini"
  p.spec.alimquai.arm = nil
  local ok4, why4 = FB.plan(plan_api(b2, function() return true end, { n = 0, arrivals = {} }), f2, surface, p)
  check(ok4 == false and why4:find("pieces inconnues", 1, true) ~= nil, "pieces inconnues : refus")
  p.spec.alimquai.arm = "inserter"
  -- aucune place contre le coffre
  for x = 8, 12 do for y = 6, 14 do b2.occ[P.tkey(x, y)] = 99 end end
  local ok5, why5 = FB.plan(plan_api(b2, function() return true end, { n = 0, arrivals = {} }), f2, surface, p)
  check(ok5 == false and why5:find("aucune place", 1, true) ~= nil, "coffre cerne : aucune place")
end

---------------------------------------------------------------------------------------------------
-- §5 pire cas en instructions (debug.sethook, deterministe)
---------------------------------------------------------------------------------------------------
do
  local f2, b2 = new_world()
  for pid = 3, 202 do
    local qs = {}
    for i = 1, 6 do qs[i] = { x = pid + 0.5, y = i * 3 + 0.5, item = "coal", flow = 0.2 } end
    b2.projects[pid] = { id = pid, state = "fini", spec = { champ = { oid = 1 } }, ents = {}, quais = qs }
    b2.order[#b2.order + 1] = pid
    for i = 1, 6 do b2.piquage.quais[pid .. ":q" .. i] = { verdict = "attente", cause = "releves_insuffisants" } end
  end
  b2.next_id = 1000
  local worst = 0
  local count = 0
  local function hook() count = count + 1000 end
  local t = 0
  for _ = 1, 400 do
    t = t + 5
    count = 0
    debug.sethook(hook, "", 1000)
    FB.step(api, f2, surface, t * 70)
    debug.sethook()
    if count > worst then worst = count end
  end
  check(worst < 200000, string.format("pire passe de Build : %d instructions (1 200 quais, 200 projets) sous 200 000", worst))
  print(string.format("  mesure : pire passe %d instructions", worst))
end

do
  -- plan : la seule boucle propre est la garde des tuiles devant les tapis des autres projets (300 projets x 100 entites)
  local f2, b2 = new_world()
  for pid = 3, 302 do
    local ents = {}
    for i = 1, 100 do ents[i] = { name = (i % 2 == 0) and "transport-belt" or "inserter", x = pid * 3 + 0.5, y = i + 0.5, dir = 2 } end
    b2.projects[pid] = { id = pid, state = "fini", ents = ents, quais = {} }
    b2.order[#b2.order + 1] = pid
  end
  local p = { id = 7, state = "plan", spec = { alimquai = { key = "2:q1", item = "coal", flow = 0.27, arm = "inserter", pole = "small-electric-pole",
    dock = { pid = 2, idx = 1, x = 10, y = 10 } } }, parts = {}, ents = {}, quais = {} }
  b2.projects[7] = p
  local count = 0
  debug.sethook(function() count = count + 1000 end, "", 1000)
  FB.plan(plan_api(b2, function() return true end, { n = 0, arrivals = {} }), f2, surface, p)
  debug.sethook()
  check(count < 250000, string.format("plan (hors Build.plan_drills) : %d instructions pour 30 000 entites de projets sous 250 000", count))
  print(string.format("  mesure : plan %d instructions (30 000 entites de projets)", count))
end

print(string.format("[FONDERIE-BLOC-SCRIPT] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
