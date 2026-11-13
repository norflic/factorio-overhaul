--[[
  Tests hors jeu du lot s42 reroutage (shared/team/reroutage.lua, Lua pur) : « construire d'abord, couper ensuite ».
  Usage, depuis la racine du mod :   lua5.2 tests/s42_reroutage_test.lua

  Cartes en texte : '.' libre, 'o' gisement libre, '#' obstacle, '>' '<' '^' 'v' tapis simple (direction), majuscules
  'E' 'W' 'N' 'S' tapis simple ALIMENTÉ par une machine (collecteur), 'u' pièce non simple (souterrain) tournée vers l'est.
  Un tapis posé sur une tuile de gisement est déclaré par la liste `ore` (coordonnées { x, y }).
]]

package.path = "./?.lua;" .. package.path

local Rr = require("shared.team.reroutage")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local DIRC = { [">"] = 2, ["<"] = 6, ["^"] = 0, ["v"] = 4, E = 2, W = 6, N = 0, S = 4, u = 2 }

local function parse(rows, ore_belts)
  local m = { belts = {}, zone = {}, avoid = {}, wall = {}, w = #rows[1], h = #rows }
  for y = 1, #rows do
    for x = 1, #rows[y] do
      local c = rows[y]:sub(x, x)
      local k = Rr.key(x, y)
      if c == "o" then m.avoid[k] = true
      elseif c == "#" then m.wall[k] = true
      elseif DIRC[c] then
        m.belts[#m.belts + 1] = { x = x, y = y, dir = DIRC[c], plain = c ~= "u", fed = (c == "E" or c == "W" or c == "N" or c == "S") }
      end
    end
  end
  for _, o in ipairs(ore_belts or {}) do
    local k = Rr.key(o[1], o[2])
    m.avoid[k] = true; m.zone[k] = true
  end
  m.map = Rr.index(m.belts)
  m.ctx = { map = m.map, avoid = m.avoid, bounds = { 1, 1, m.w, m.h },
    free = function(x, y) return not m.wall[Rr.key(x, y)] end }
  return m
end

section("1. troncon traversant : detection")
local A = parse({
  "..........",
  "...oooo...",
  ">>>>>>>>>>",
  "...oooo...",
  "..........",
}, { { 4, 3 }, { 5, 3 }, { 6, 3 }, { 7, 3 } })
local runs = Rr.runs(A.belts, A.zone)
check(#runs == 1, "un seul troncon (" .. #runs .. ")")
local r = runs[1]
check(r.kind == "traversant", "traversant (" .. tostring(r.kind) .. ")")
check(r.p.x == 3 and r.q.x == 8 and #r.old == 4, "amont en 3, aval en 8, 4 tuiles sur le gisement")

section("2. contournement : hors du gisement, entree laterale, preuve")
local plan, why = Rr.plan(r, A.ctx)
check(plan ~= nil, "un contournement existe (" .. tostring(why) .. ")")
if plan then
  check(Rr.verify(r, plan, A.avoid), "preuve du contournement")
  local onore = 0
  for _, t in ipairs(plan.tiles) do if A.avoid[Rr.key(t.x, t.y)] then onore = onore + 1 end end
  check(onore == 0, "aucune tuile du contournement sur le gisement")
  local last = plan.tiles[#plan.tiles]
  check(last.x == 8 and (last.y == 2 or last.y == 4), "derniere tuile contre un cote de l'aval")
  check(plan.cut == 0 or plan.cut == 4, "la coupe tourne l'amont vers le cote")
  -- déterminisme : deux appels, même tracé
  local p2 = Rr.plan(r, A.ctx)
  local same = #p2.tiles == #plan.tiles
  for i, t in ipairs(plan.tiles) do same = same and p2.tiles[i].x == t.x and p2.tiles[i].y == t.y and p2.tiles[i].dir == t.dir end
  check(same, "trace deterministe")
end

section("3. classes laissees en place")
local B = parse({
  "...oooo...",
  ">>>>E>>>>>",
  "...oooo...",
}, { { 4, 2 }, { 5, 2 }, { 6, 2 }, { 7, 2 } })
check(Rr.runs(B.belts, B.zone)[1].kind == "collecteur", "tapis alimente par une machine : collecteur")
check(Rr.plan(Rr.runs(B.belts, B.zone)[1], B.ctx) == nil, "aucun plan pour un collecteur")
local C = parse({
  "...oooo...",
  "...>>>>>>>",
  "...oooo...",
}, { { 4, 2 }, { 5, 2 }, { 6, 2 }, { 7, 2 } })
check(Rr.runs(C.belts, C.zone)[1].kind == "sans amont", "ligne nee sur le gisement : sans amont")
local D = parse({
  "...oooo...",
  ">>>>>>>...",
  "...oooo...",
}, { { 4, 2 }, { 5, 2 }, { 6, 2 }, { 7, 2 } })
check(Rr.runs(D.belts, D.zone)[1].kind == "sans aval", "ligne morte sur le gisement : sans aval")
local E = parse({
  "....v.....",
  ">>>>>>>>>>",
  "...oooo...",
}, { { 4, 2 }, { 5, 2 }, { 6, 2 }, { 7, 2 } })
check(Rr.runs(E.belts, E.zone)[1].kind == "embranchement", "tapis de cote qui entre sur le troncon : embranchement")
local F = parse({
  "...oooo...",
  ">>u>>>>>>>",
  "...oooo...",
}, { { 4, 2 }, { 5, 2 }, { 6, 2 }, { 7, 2 } })
check(Rr.runs(F.belts, F.zone)[1].kind == "piece", "amont souterrain : piece")
local Hm = parse({ "...oooo...", ">>>>>>>>>>", "...oooo..." }, { { 4, 2 }, { 5, 2 }, { 6, 2 }, { 7, 2 } })
Hm.belts[5].human = true
check(Rr.runs(Hm.belts, Hm.zone)[1].kind == "joueur", "tapis pose par un joueur : jamais touche")

section("4. aucun chemin : refus, rien ne bouge")
local G = parse({
  "###oooo###",
  ">>>>>>>>>>",
  "###oooo###",
}, { { 4, 2 }, { 5, 2 }, { 6, 2 }, { 7, 2 } })
local pg, wg = Rr.plan(Rr.runs(G.belts, G.zone)[1], G.ctx)
check(pg == nil and wg ~= nil, "contournement refuse avec motif (" .. tostring(wg) .. ")")

section("5. aucune entree etrangere sur le contournement")
local I = parse({
  "..........",
  "..v.......",
  "...oooo...",
  ">>>>>>>>>>",
  "...oooo...",
  "..........",
}, { { 4, 4 }, { 5, 4 }, { 6, 4 }, { 7, 4 } })
local ri = Rr.runs(I.belts, I.zone)[1]
local pi = Rr.plan(ri, I.ctx)
check(pi ~= nil, "contournement trouve malgre un tapis voisin")
if pi then
  local bad = false
  for _, t in ipairs(pi.tiles) do if t.x == 3 and t.y == 3 then bad = true end end
  check(not bad, "la tuile ou sort un tapis etranger n'est pas prise")
  check(Rr.verify(ri, pi, I.avoid), "preuve")
end

section("6. automate : construire d'abord, couper ensuite")
local function facts(t) t.p_ok = t.p_ok ~= false; t.q_ok = t.q_ok ~= false; return t end
local s, a = Rr.step(Rr.A_CONTOURNER, facts({ total = 10, posed = 0, stock = 9 }))
check(s == Rr.A_CONTOURNER and a.kind == "attendre" and a.why == "stock", "stock insuffisant : rien ne se pose")
s, a = Rr.step(Rr.A_CONTOURNER, facts({ total = 10, posed = 0, stock = 10 }))
check(s == Rr.A_CONTOURNER and a.kind == "poser", "stock complet : pose")
s, a = Rr.step(Rr.A_CONTOURNER, facts({ total = 10, posed = 10, stock = 0 }))
check(s == Rr.POSE and a == nil, "tout pose : contournement_pose")
s, a = Rr.step(Rr.POSE, facts({ total = 10, posed = 10, stock = 0 }))
check(s == Rr.POSE and a.kind == "couper", "contournement pose : action couper")
s, a = Rr.step(Rr.POSE, facts({ total = 10, posed = 9, stock = 0 }))
check(s == Rr.A_CONTOURNER and a.kind ~= "couper", "une tuile disparue avant la coupe : retour, jamais de coupe")
s, a = Rr.step(Rr.POSE, facts({ total = 10, posed = 10, p_cut = true }))
check(s == Rr.COUPE, "amont tourne : coupe")
s, a = Rr.step(Rr.COUPE, facts({ total = 10, posed = 10, old_left = 4, old_items = 3 }))
check(s == Rr.COUPE and a.kind == "attendre" and a.why == "vidange", "ancienne ligne pas vide : on attend")
s, a = Rr.step(Rr.COUPE, facts({ total = 10, posed = 10, old_left = 4, old_items = 0 }))
check(s == Rr.COUPE and a.kind == "retirer", "ancienne ligne vide : retrait")
s, a = Rr.step(Rr.COUPE, facts({ total = 10, posed = 10, old_left = 0, old_items = 0 }))
check(s == Rr.RACCORDE, "plus d'ancienne ligne : raccorde")
s, a = Rr.step(Rr.A_CONTOURNER, facts({ total = 10, posed = 3, stock = 99, q_ok = false }))
check(s == Rr.ABANDONNE, "aval disparu avant la coupe : abandon")
s, a = Rr.step(Rr.RACCORDE, facts({ total = 10, posed = 0 }))
check(s == Rr.RACCORDE and a == nil, "raccorde est terminal")

section("7. invariant sur 20 000 suites de faits tirees (RNG maison)")
local seed = 20261113
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end
local viol, cuts = 0, 0
for _ = 1, 20000 do
  local st = Rr.A_CONTOURNER
  local total = 1 + rnd(12)
  for _ = 1, 12 do
    local f = { total = total, posed = rnd(total + 1), stock = rnd(14), p_ok = rnd(10) > 0, q_ok = rnd(10) > 0,
      p_cut = rnd(2) == 1, old_left = rnd(4), old_items = rnd(3) }
    local ns, act = Rr.step(st, f)
    if act and act.kind == "couper" then
      cuts = cuts + 1
      if f.posed < total then viol = viol + 1 end
    end
    if ns == Rr.COUPE and st ~= Rr.COUPE and f.posed < total then viol = viol + 1 end
    if act and act.kind == "retirer" and (st ~= Rr.COUPE or f.old_items > 0 or f.posed < total) then viol = viol + 1 end
    if act and act.kind == "poser" and f.stock < total - f.posed then viol = viol + 1 end
    st = ns
  end
end
check(viol == 0, "aucune coupe ni retrait avec un contournement incomplet (" .. viol .. " violation(s))")
check(cuts > 0, "la coupe est atteinte dans le tirage (" .. cuts .. ")")

section("8. mutant : un automate qui coupe trop tot est vu par l'invariant")
local real = Rr.peut_couper
Rr.peut_couper = function() return true end
local ms, ma = Rr.step(Rr.POSE, facts({ total = 10, posed = 10 }))
Rr.peut_couper = real
check(ma and ma.kind == "couper", "(temoin) le chemin de coupe passe par Rr.peut_couper")
check(not Rr.peut_couper({ total = 10, posed = 9, p_ok = true, q_ok = true }), "peut_couper refuse 9 sur 10")
check(not Rr.peut_couper({ total = 0, posed = 0, p_ok = true, q_ok = true }), "peut_couper refuse un contournement vide")
check(not Rr.peut_couper({ total = 3, posed = 3, p_ok = true, q_ok = false }), "peut_couper refuse sans aval")

section("9. cablage (script/team/reroutage.lua) sur un monde simule : ordre pose -> coupe -> retrait")
do
  local Ch = require("shared.team.champ")
  local world, events, stock, uid = {}, {}, 0, 0
  local function put(x, y, dir, user)
    uid = uid + 1
    local e = { valid = true, name = "tapis-a", type = "transport-belt", direction = dir, position = { x = x + 0.5, y = y + 0.5 },
      unit_number = uid, last_user = user, items = 0, prototype = { items_to_place_this = { { name = "objet-tapis" } } } }
    e.get_max_transport_line_index = function() return 2 end
    e.get_transport_line = function(i) local t = {}; if i == 1 then for n = 1, e.items do t[n] = true end end; return t end
    e.destroy = function() e.valid = false; world[Rr.key(x, y)] = nil; events[#events + 1] = "retrait" end
    world[Rr.key(x, y)] = e
    return e
  end
  local surface = {}
  function surface.find_entities_filtered(q)
    local out = {}
    if q.position then
      local e = world[Rr.key(math.floor(q.position[1]), math.floor(q.position[2]))]
      if e and q.type == "transport-belt" then out[1] = e end
    elseif q.type == "transport-belt" then
      for y = q.area[1][2], q.area[2][2] - 1 do for x = q.area[1][1], q.area[2][1] - 1 do
        local e = world[Rr.key(x, y)]; if e then out[#out + 1] = e end
      end end
    end
    return out
  end
  function surface.can_place_entity(q) return world[Rr.key(math.floor(q.position[1]), math.floor(q.position[2]))] == nil end
  function surface.create_entity(q)
    events[#events + 1] = "pose"
    return put(math.floor(q.position[1]), math.floor(q.position[2]), q.direction, nil)
  end
  local pulse
  package.loaded["script.core.events"] = { on_nth_tick = function(_, fn) pulse = fn end }
  local f = { key = "essai", id = 1, force = "essai", hq = { valid = true, surface = surface }, build = { occ = {}, projects = {} } }
  package.loaded["script.faction.state"] = { war = function() return { active = false } end, alive = function() return {} end,
    faction = function() return f end, disown = function() end }
  package.loaded["script.team.stock"] = { count = function() return stock end,
    remove = function(_, _, n) local g = math.min(n, stock); stock = stock - g; return g end,
    insert = function(_, _, n) stock = stock + n end }
  _G.game = { tick = 1000, entity_prototypes = { ["tapis-a"] = { type = "transport-belt", items_to_place_this = { { name = "objet-tapis" } } } } }
  _G.log = function() end
  local Rer = require("script.team.reroutage")
  -- ligne ouest -> est en y = 3, gisement en x = 4..7, y = 2..4
  for x = 1, 10 do put(x, 3, 2) end
  local ore, blocked = {}, {}
  for x = 4, 7 do for y = 2, 4 do ore[#ore + 1] = x; ore[#ore + 1] = y end; blocked[Ch.key(x, 3)] = "tapis-a" end
  Rer.note(f, surface, { id = 7 }, ore, blocked, {}, { 0, 0, 11, 6 })
  local run = f.reroutage and f.reroutage.run
  check(run ~= nil and run.state == Rr.A_CONTOURNER, "troncon inscrit, etat a_contourner")
  if run then
    local need = #run.tiles
    stock = need - 1
    pulse()
    check(#events == 0 and world[Rr.key(3, 3)].direction == 2, "stock insuffisant : rien pose, rien coupe")
    stock = need
    world[Rr.key(5, 3)].items = 2
    for _ = 1, 3 do pulse() end
    local poses, first_cut = 0, nil
    for _, ev in ipairs(events) do if ev == "pose" then poses = poses + 1 end end
    check(poses == need and stock == 0, "contournement pose en entier, paye au stock (" .. poses .. "/" .. need .. ")")
    check(world[Rr.key(3, 3)].direction == run.cut, "amont tourne vers le contournement apres la pose complete")
    pulse(); pulse()
    check(world[Rr.key(5, 3)] ~= nil and run.state == Rr.COUPE, "ancienne ligne non vide : pas de retrait")
    world[Rr.key(5, 3)].items = 0
    pulse(); pulse()
    local gone = true
    for x = 4, 7 do if world[Rr.key(x, 3)] then gone = false end end
    check(gone and stock == 4, "ancienne ligne retiree, 4 tapis rendus au stock")
    check(f.reroutage.run == nil and f.reroutage.done[run.key] == true, "troncon raccorde, jamais repris")
    local ordered, seen_retrait = true, false
    for _, ev in ipairs(events) do if ev == "retrait" then seen_retrait = true elseif seen_retrait then ordered = false end end
    check(ordered, "aucune pose apres le premier retrait : tout le contournement precede la coupe")
    -- relevé suivant : plus rien à faire
    _G.game.tick = 100000
    Rer.note(f, surface, { id = 7 }, ore, blocked, {}, { 0, 0, 11, 6 })
    check(f.reroutage.run == nil, "aucun nouveau troncon apres le raccord")
  end
  -- tapis posé par un joueur : rien
  world, events = {}, {}
  for x = 1, 10 do put(x, 3, 2, x == 5 and {} or nil) end
  f.reroutage = nil
  _G.game.tick = 200000
  Rer.note(f, surface, { id = 8 }, ore, blocked, {}, { 0, 0, 11, 6 })
  check(f.reroutage.run == nil, "ligne avec un tapis pose par un joueur : jamais inscrite")
end

print(string.format("s42_reroutage : %d OK, %d echec(s)", passes, failures))
if failures > 0 then os.exit(1) end
