--[[
  Lot ENCEINTE2 : machine d'états des SEGMENTS d'enceinte de script/team/build.lua (Build.space_step, request_segment,
  repair_enclosure, segment_failed), jouée hors jeu avec un moteur de bouchons. Le texte du code est celui de build.lua :
  il est extrait entre deux repères et exécuté dans un environnement où seules les dépendances du moteur sont factices
  (Stock, Build.request/cancel, wall_recipe, surface). Aucun banc moteur.
  Usage, depuis la racine du mod :   lua5.2 tests/enceinte_flux_test.lua
]]
package.path = "./?.lua;" .. package.path
local Enc = require("shared.team.enceinte")
local P = require("shared.team.plan")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

-- extraction du code testé
local fh = assert(io.open("script/team/build.lua", "rb"))
local src = fh:read("*a")
fh:close()
local a = assert(src:find("--- Segment d'enceinte en cours", 1, true), "repere de debut absent")
local b = assert(src:find("--- Pensée d'équipe (script/team/team.lua", 1, true), "repere de fin absent")
local chunk_src = src:sub(a, b - 1)

local W = { stock_wall = 0, logs = {} }
local built = {}                      -- positions des murs "vivants" : "x:y"
local Build = { PRIO = 55 }
local env = {
  Enc = Enc, Build = Build, ipairs = ipairs, pairs = pairs, math = math, table = table, string = string, tostring = tostring,
  next = next, type = type,
  Stock = { count = function(_, name) if name == "stone-wall" then return W.stock_wall end return 0 end },
  wall_recipe = function() return { item = "stone-wall", ings = { { name = "stone-brick", amount = 5 } }, per = 1 } end,
  craftable_walls = function() return 0 end,
  space_log = function(_, text) W.logs[#W.logs + 1] = text end,
  space_info = function() return { radius = 3, rmax = 5, pending = 0, free = 5, busy = 0, done = 10, enc = false } end,
  -- lot ENCEINTE3 : par defaut, pas de contour serre (le rayon, comme avant) ; les essais du contour serre posent W.tight
  enc_tight_bounds = function() if W.tight then return W.tight, W.tight_info end return nil end,
  enc_mark_out = function() W.marked = (W.marked or 0) + 1 return 7 end,
  enc_release = function() W.released = (W.released or 0) + 1 end,
  -- lot ILOTS-MURS : le pas des îlots est appelé à chaque décision d'une équipe murée (joué en vrai par tests/ilots_flux_test.lua)
  Ilots = { step = function(_, _, _, ctx) W.ilots_calls = (W.ilots_calls or 0) + 1; W.ilots_ctx = ctx end },
}
local chunk = assert(load("local Enc, Build, ipairs, math, table, string, tostring, Stock, wall_recipe, craftable_walls, space_log, space_info, "
  .. "enc_tight_bounds, enc_mark_out, enc_release, Ilots = "
  .. "Enc, Build, ipairs, math, table, string, tostring, Stock, wall_recipe, craftable_walls, space_log, space_info, "
  .. "enc_tight_bounds, enc_mark_out, enc_release, Ilots\n"
  .. chunk_src .. "\nreturn Build", "enceinte_flux", "t", setmetatable(env, { __index = _G })))
chunk()

local lat = P.lattice({ x = 0.5, y = 0.5 })
local function new_team()
  local f = { key = "f1", is_player = false, ai3f = nil, build = {
    opts = {}, lat = lat, radius = 3, projects = {}, order = {}, stats = {}, lots = {}, queue = {}, qhead = 1,
    next_id = 1,
  } }
  return f
end
local requests = {}
Build.request = function(f, spec)
  local b = f.build
  local id = b.next_id
  b.next_id = id + 1
  local p = { id = id, spec = spec, state = "attente", ents = {}, parts = {} }
  b.projects[id] = p
  b.order[#b.order + 1] = id
  requests[#requests + 1] = p
  return id
end
Build.cancel = function(f, id, why)
  local p = f.build.projects[id]
  if p and (p.state == "attente" or p.state == "plan" or p.state == "reserve") and not p.reopened then
    p.state, p.reason = "refuse", why
    return true
  end
  return false
end
Build.grow = function() end
local surface = {
  count_entities_filtered = function(q) return built[q.position[1] .. ":" .. q.position[2]] and 1 or 0 end,
}

--- Termine un segment comme le ferait le chantier : ses murs planifiés existent.
local function finish(f, p, tick)
  p.ents = {}
  for _, w in ipairs(p.spec.walls) do
    local x, y = w[1] + 0.5, w[2] + 0.5
    p.ents[#p.ents + 1] = { x = x, y = y, built = true }
    built[x .. ":" .. y] = true
  end
  p.state, p.finished, p.started = "fini", tick, tick - 100
end

local tick = 100000
local function step(f)
  tick = tick + Enc.CHECK_TICKS
  Build.space_step(f, surface, tick)
end

-- 1. Stock trop pauvre : rien n'est demandé, le rayon n'est pas figé
do
  local f = new_team()
  W.stock_wall = 20 -- un quart = 5 < SEG_MIN
  step(f)
  check(f.build.enc == nil and #requests == 0, "stock pauvre : aucune enceinte, rayon libre")
  step(f)
  check(f.build.enc == nil and #requests == 0, "stock pauvre : toujours rien au pas suivant")
end

-- 2. Premier segment, un seul en cours, payé au quart du stock
do
  requests = {}
  local f = new_team()
  W.stock_wall = 120 -- cap 30
  step(f)
  local b = f.build
  check(b.enc ~= nil and #b.enc.segs == 1 and #requests == 1, "stock suffisant : un premier segment demande")
  local p1 = requests[1]
  check(p1.spec.enceinte == true and #p1.spec.walls == 30, "le segment a 30 murs, un quart de 120 (" .. #p1.spec.walls .. ")")
  check(b.enc.r == 3, "rayon fige au premier segment")
  step(f)
  check(#requests == 1, "un seul segment en cours : pas de second pendant le premier")
  finish(f, p1, tick)
  W.stock_wall = 90 -- cap 22
  step(f)
  check(#requests == 2 and #requests[2].spec.walls == 22, "premier fini : le second a 22 murs, un quart de 90 (" .. #requests[2].spec.walls .. ")")
  -- aucun mur en commun
  local seen, dup = {}, 0
  for _, rq in ipairs(requests) do for _, w in ipairs(rq.spec.walls) do local k = w[1] .. ":" .. w[2]; if seen[k] then dup = dup + 1 end seen[k] = true end end
  check(dup == 0, "deux segments sans tuile commune")
  local rep = Build.enclosure_report(b)
  check(rep.segments == 2 and rep.finished == 1 and rep.complete == false and rep.gates == Enc.gate_count(), "rapport : 2 segments, 1 fini")

  -- 3. Segment annulé faute de matière : ses tuiles reviennent, nouvel essai plus tard
  local p2 = requests[2]
  p2.state, p2.reason = "refuse", "materiaux"
  step(f)
  check(#b.enc.segs == 1, "segment refuse (matiere) retire de la liste")
  local count_claimed = 0
  for _ in pairs(b.enc.claimed) do count_claimed = count_claimed + 1 end
  check(count_claimed == 30, "ses tuiles sont rendues (30 restent reservees)")
  check(#requests == 2, "pas de nouvel essai avant le delai")
  tick = tick + Enc.SEG_RETRY_TICKS
  step(f)
  check(#requests == 3 and requests[3].spec.walls[1][1] == requests[2].spec.walls[1][1], "apres le delai : le meme endroit est redemande")

  -- 4. Segment refuse pour une raison durable : tuiles gardees, pas de boucle
  requests[3].state, requests[3].reason = "refuse", "aucun mur posable"
  local n_before = #requests
  step(f)
  check(#b.enc.segs == 2 and b.projects[requests[3].id].state == "refuse", "segment non murable retire de la liste, le suivant est deja demande")
  check(#requests == n_before + 1 and requests[#requests].spec.walls[1][1] ~= requests[3].spec.walls[1][1]
    or requests[#requests].spec.walls[1][2] ~= requests[3].spec.walls[1][2], "tuiles non murables gardees : le segment suivant est ailleurs")

  -- 5. Reprise d'un segment detruit : le seul segment touche est rouvert
  finish(f, requests[#requests], tick)
  local first = requests[1]
  local lost_key = first.ents[5].x .. ":" .. first.ents[5].y
  built[lost_key] = nil
  tick = tick + Enc.REPAIR_TICKS
  step(f)
  check(first.state == "reserve" and (first.reopened or 0) >= 1, "segment 1 (un mur detruit) rouvert en reserve")
  check(first.ents[5].built == false and first.ents[4].built == true, "seul le mur detruit est a refaire")
  check(requests[#requests].state == "fini", "l'autre segment reste fini")
  check(not Build.cancel(f, first.id, "x"), "un segment rouvert n'est pas annulable")
end

-- 6. Premier segment refuse pour la place : le rayon est libere
do
  requests = {}
  local f = new_team()
  W.stock_wall = 400
  step(f)
  check(f.build.enc ~= nil and #requests == 1, "premier segment demande")
  requests[1].state, requests[1].reason = "refuse", "place"
  step(f)
  check(f.build.enc == nil and f.build.enc_retry and f.build.enc_retry > tick, "rien de pose : rayon libere, nouvel essai plus tard")
end

-- 7. Pose complète par un stock généreux : couverture exacte de l'anneau
do
  requests = {}
  local f = new_team()
  W.stock_wall = 100000
  local guard = 0
  while guard < 200 do
    guard = guard + 1
    step(f)
    local b = f.build
    local last = requests[#requests]
    if last and last.state ~= "fini" then finish(f, last, tick) end
    if b.enc and b.enc.complete then break end
  end
  local total, seen, dup = 0, {}, 0
  for _, rq in ipairs(requests) do
    for _, w in ipairs(rq.spec.walls) do
      total = total + 1
      local k = w[1] .. ":" .. w[2]
      if seen[k] then dup = dup + 1 end
      seen[k] = true
    end
  end
  check(f.build.enc.complete and total == Enc.max_walls(3) and dup == 0,
    "l'anneau complet est pose en " .. #requests .. " segments (" .. total .. " / " .. Enc.max_walls(3) .. ")")
  local n = #requests
  step(f); step(f)
  check(#requests == n, "enceinte complete : plus aucun segment demande")
end

-- 8. Menace connue : le premier segment est du côté du nid
do
  requests = {}
  local f = new_team()
  W.stock_wall = 400
  f.ai3f = { m = { s = { [1] = { sp = { { x = lat.ox - 180, y = lat.oy + 10 } } } } } }
  step(f)
  check(requests[1] and requests[1].spec.side == "o", "nid connu a l'ouest : premier segment a l'ouest (" .. tostring(requests[1] and requests[1].spec.side) .. ")")
end

-- 9. Sauvegarde d'avant ENCEINTE2 : un projet unique devient l'unique segment, enceinte complete
do
  requests = {}
  local f = new_team()
  local id = Build.request(f, { enceinte = true })
  f.build.enc = { r = 3, pid = id, tick = 5 }
  W.stock_wall = 400
  step(f)
  check(f.build.enc.segs and #f.build.enc.segs == 1 and f.build.enc.complete == true, "ancienne enceinte : un segment, complete")
  check(#requests == 1, "ancienne enceinte : aucun nouveau segment")
  local rep = Build.enclosure_report(f.build)
  check(rep.segments == 1 and rep.complete == true, "rapport d'une ancienne enceinte")
end

-- 10. Ancienne enceinte refusee pour une raison durable (aucun mur posable) : le rayon est libere, pas fige pour toujours
do
  requests = {}
  local f = new_team()
  local id = Build.request(f, { enceinte = true })
  f.build.enc = { r = 3, pid = id, tick = 5 }
  f.build.projects[id].state, f.build.projects[id].reason = "refuse", "aucun mur posable"
  W.stock_wall = 400
  step(f)
  check(f.build.enc == nil and f.build.enc_retry ~= nil, "ancienne enceinte refusee pour de bon : rayon libere, nouvel essai plus tard")
end

-- 11. Segment neuf refuse pour de bon (aucun mur posable), seul de l'enceinte : tuiles gardees, le suivant est tente
do
  requests = {}
  local f = new_team()
  W.stock_wall = 400
  step(f)
  local p1 = requests[1]
  p1.state, p1.reason = "refuse", "aucun mur posable"
  step(f)
  check(f.build.enc ~= nil and #requests == 2, "refus durable : rayon garde, un autre segment est demande")
  check(requests[2].spec.walls[1][1] ~= p1.spec.walls[1][1] or requests[2].spec.walls[1][2] ~= p1.spec.walls[1][2],
    "refus durable : le segment refuse n'est pas redemande")
end

-- 12. Lot ENCEINTE3 : contour serré — les bornes sont figées avec le rayon, lues par request_segment, la pose couvre exactement ce contour
do
  requests = {}
  W.marked, W.released = nil, nil
  local tb = Enc.tight_bounds(lat, { Enc.lot_box(lat, 1, 0), Enc.lot_box(lat, 0, 1) }, {})
  W.tight, W.tight_info = tb, { core = 2, excluded = {}, room = 0 }
  local f = new_team()
  W.stock_wall = 100000
  step(f)
  local b = f.build
  check(b.enc ~= nil and b.enc.bounds == tb and b.enc.r == 3, "contour serre : bornes et rayon figes ensemble au premier segment")
  check(W.marked == 1, "les lots hors du contour sont ecartes une fois, a la creation (" .. tostring(W.marked) .. ")")
  local p1 = requests[1]
  local on_ring = true
  for _, w in ipairs(p1.spec.walls) do
    local x, y = w[1], w[2]
    if not (x == tb[1] or x == tb[3] or y == tb[2] or y == tb[4]) then on_ring = false end
  end
  check(on_ring and #p1.spec.walls >= 1 and #p1.spec.walls <= Enc.SEG_MAX, "le premier segment est sur le contour serre, pas sur l'anneau du rayon")
  -- lot A : il demarre a l'ouverture (bout du troncon le plus proche du QG), pas au coin
  local w1 = p1.spec.walls[1]
  check(not ((w1[1] == tb[1] or w1[1] == tb[3]) and (w1[2] == tb[2] or w1[2] == tb[4])), "le premier segment ne commence pas dans un coin")
  local guard = 0
  while guard < 200 do
    guard = guard + 1
    local last = requests[#requests]
    if last and last.state ~= "fini" then finish(f, last, tick) end
    step(f)
    if b.enc and b.enc.complete then break end
  end
  local total, seen, dup, outside = 0, {}, 0, 0
  for _, rq in ipairs(requests) do
    for _, w in ipairs(rq.spec.walls) do
      total = total + 1
      local k = w[1] .. ":" .. w[2]
      if seen[k] then dup = dup + 1 end
      seen[k] = true
      if not (w[1] >= tb[1] and w[1] <= tb[3] and w[2] >= tb[2] and w[2] <= tb[4]) then outside = outside + 1 end
    end
  end
  check(b.enc.complete and total == Enc.max_walls(3, { bounds = tb }) and dup == 0 and outside == 0,
    "contour serre : pose complete en " .. #requests .. " segments (" .. total .. " / " .. Enc.max_walls(3, { bounds = tb }) .. ")")
  check(total < Enc.max_walls(3) / 2, "et bien moins de murs que l'anneau du rayon (" .. total .. " contre " .. Enc.max_walls(3) .. ")")
  local rep = Build.enclosure_report(b)
  check(rep.tight == true and rep.bounds == tb and rep.complete == true, "rapport : contour serre, bornes, complet")
  W.tight, W.tight_info = nil, nil
end

-- 13. Contour serré : premier segment refusé pour la place -> rayon et lots écartés libérés
do
  requests = {}
  W.marked, W.released = nil, nil
  W.tight = Enc.tight_bounds(lat, { Enc.lot_box(lat, 1, 0) }, {})
  W.tight_info = { core = 1, excluded = {}, room = 0 }
  local f = new_team()
  W.stock_wall = 400
  step(f)
  check(f.build.enc ~= nil and W.marked == 1, "contour serre pose")
  requests[1].state, requests[1].reason = "refuse", "place"
  step(f)
  check(f.build.enc == nil and W.released == 1, "rien de pose : le rayon et les lots ecartes sont liberes")
  W.tight, W.tight_info = nil, nil
end

-- 14. Contour serré et menace connue : le segment démarre au bout du tronçon le plus proche du nid
do
  requests = {}
  local tb = Enc.tight_bounds(lat, { Enc.lot_box(lat, 1, 0), Enc.lot_box(lat, -1, 0), Enc.lot_box(lat, 0, 1), Enc.lot_box(lat, 0, -1) }, {})
  W.tight, W.tight_info = tb, { core = 4, excluded = {}, room = 0 }
  local f = new_team()
  W.stock_wall = 400
  local nest = { x = lat.ox + 170, y = lat.oy - 30 }
  f.ai3f = { m = { s = { [1] = { sp = { nest } } } } }
  step(f)
  local p1 = requests[1]
  check(p1 and p1.spec.side == "e", "nid a l'est : segment du cote est")
  local runs = Enc.runs(lat, 3, { bounds = tb })
  local best, bd = nil, math.huge
  for _, run in ipairs(runs) do
    if run.side == "e" then
      for _, w in ipairs({ run.walls[1], run.walls[#run.walls] }) do
        local d = (w.x - nest.x) ^ 2 + (w.y - nest.y) ^ 2
        if d < bd then best, bd = w, d end
      end
    end
  end
  check(p1.spec.walls[1][1] == best.tx and p1.spec.walls[1][2] == best.ty,
    "le segment demarre au bout de troncon le plus proche du nid (" .. p1.spec.walls[1][1] .. "," .. p1.spec.walls[1][2] .. ")")
  W.tight, W.tight_info = nil, nil
end

-- 15. Lot ENCEINTE3 : le relevé de l'empreinte de build.lua (enc_tight_bounds, enc_mark_out, enc_release), extrait du code lui-même
do
  local a2 = assert(src:find("--- Lot ENCEINTE3 (retour du DC, Azur", 1, true), "repere du releve de l'empreinte absent")
  local b2 = assert(src:find("--- Plan du projet « enceinte » : (true) ou (false, raison)", 1, true), "repere de fin du releve absent")
  local env2 = setmetatable({ Enc = Enc, P = P, ipairs = ipairs, table = table, math = math, type = type, pairs = pairs,
    sorted_keys = function(t)
      local ks = {}
      for k in pairs(t) do ks[#ks + 1] = k end
      table.sort(ks, function(x, y) if type(x) == type(y) then return x < y end return type(x) == "number" end)
      return ks
    end }, { __index = _G })
  local code = assert(load("local Enc, P, ipairs, table, math, type, pairs, sorted_keys = Enc, P, ipairs, table, math, type, pairs, sorted_keys\n"
    .. src:sub(a2, b2 - 1) .. "\nreturn enc_tight_bounds, enc_mark_out, enc_release", "releve", "t", env2))
  local tight_bounds_of, mark_out, release = code()
  local az = P.lattice({ x = 339.5, y = 339.5 })
  local function mk(lots, projects, turrets)
    local b = { lat = az, radius = 3, lots = {}, projects = projects or {} }
    for _, l in ipairs(lots) do b.lots[P.lot_key(l.i, l.j)] = l end
    return { build = b, turrets = turrets }
  end
  local function turret(x, y, valid) return { valid = valid ~= false, position = { x = x, y = y } } end
  local lots = {
    { i = 0, j = 0, state = "occupe", used = 1 },       -- le lot du QG
    { i = 1, j = 0, state = "libre", used = 2 },        -- pris par un projet fini
    { i = 0, j = 1, state = "libre", used = 3 },        -- pris par un projet refuse : ne compte pas
    { i = 0, j = -1, state = "libre", used = 4 },       -- pris par un projet d'enceinte : ne compte pas
    { i = 5, j = 0, state = "gisement", used = 5 },     -- mine lointaine : isolee
    { i = -1, j = 0, state = "libre" },                 -- libre, voisin : garde dedans
    { i = 0, j = 2, state = "libre" },                  -- libre
    { i = -2, j = 0, state = "defricher" },             -- libre
    { i = 2, j = 1, state = "libre", bad = 2 },         -- ecarte par des echecs : jamais "libre garde"
    { i = 8, j = 8, state = "libre" },                  -- libre, hors de portee
  }
  local projects = { [1] = { state = "fini" }, [2] = { state = "fini", spec = {} }, [3] = { state = "refuse" },
    [4] = { state = "fini", spec = { enceinte = true } }, [5] = { state = "fini" } }
  local f = mk(lots, projects, { [11] = turret(339 + 20, 339), [12] = turret(339 + 200, 339), [13] = turret(339 + 22, 339, false) })
  local tb, info = tight_bounds_of(f)
  check(tb ~= nil and info.core >= 2 and info.room >= 1, "releve : empreinte, lots libres gardes (" .. tostring(info and info.core) .. ", " .. tostring(info and info.room) .. ")")
  -- exclus : la mine lointaine (5, 0) et la tourelle a 200 tuiles
  check(#info.excluded == 2, "releve : la mine lointaine et la tourelle d'avant-poste sont dehors (" .. #info.excluded .. ")")
  check(tb[3] < az.ox + 100, "le contour ne va pas jusqu'a la mine lointaine (x1 " .. tb[3] .. ")")
  -- le lot refuse (0, 1) et celui de l'enceinte (0, -1) ne tirent pas le contour : a l'est, le lot (1, 0) donne 339+12+28 = 379
  local f2 = mk({ { i = 0, j = 0, state = "occupe", used = 1 }, { i = 0, j = 1, state = "libre", used = 3 }, { i = 0, j = -1, state = "libre", used = 4 } },
    projects, {})
  local t2 = tight_bounds_of(f2)
  check(t2[2] == 339 - 12 - Enc.MARGIN - 1 and t2[4] == 339 + 12 + Enc.MARGIN, "projet refuse ou d'enceinte : ne compte pas dans l'empreinte")
  -- une tourelle invalide ne compte pas
  local f3 = mk({ { i = 0, j = 0, state = "occupe", used = 1 } }, projects, { [1] = turret(339 + 22, 339, false) })
  local t3 = tight_bounds_of(f3)
  check(t3[3] == 339 + 12 + Enc.MARGIN, "tourelle invalide ignoree")
  -- determinisme : deux releves identiques
  local tb2 = tight_bounds_of(mk(lots, projects, { [11] = turret(339 + 20, 339), [12] = turret(339 + 200, 339) }))
  check(tb2[1] == tb[1] and tb2[2] == tb[2] and tb2[3] == tb[3] and tb2[4] == tb[4], "releve deterministe")
  -- marquage : les lots libres dehors ou coupes sont ecartes, ceux de dedans non ; le lot du QG jamais
  local n = mark_out(f.build, tb)
  local inside_free, outside_free = f.build.lots["-1:0"], f.build.lots["8:8"]
  check(not inside_free.out and outside_free.out == true and not f.build.lots["0:0"].out, "marquage : (8,8) ecarte, (-1,0) dedans, le lot du QG jamais")
  check(f.build.lots["5:0"].out == true and n >= 2, "marquage : la mine lointaine est dehors (mais un gisement reste utilisable : le drapeau n'agit pas sur lui)")
  -- Enc.free_count ignore les lots ecartes
  local fc = Enc.free_count(f.build.lots)
  local expect = 0
  for _, l in pairs(f.build.lots) do
    if not (l.i == 0 and l.j == 0) and not l.used and (l.state == "libre" or l.state == "defricher") and not (l.bad and l.bad >= 2) and not l.out then expect = expect + 1 end
  end
  check(fc == expect and fc >= 1, "free_count ne compte pas les lots ecartes (" .. fc .. ")")
  release(f.build)
  check(not f.build.lots["8:8"].out and not f.build.lots["5:0"].out, "liberation : plus aucun lot ecarte")
  -- le code lit bien le drapeau aux deux endroits qui choisissent un lot libre
  check(src:find('if l.out and (l.state == "libre" or l.state == "defricher") then ok_state = false end', 1, true) ~= nil, "candidates() ecarte les lots libres dehors")
  check(src:find('and not (l.i == 0 and l.j == 0) and not l.used and (l.state == "libre" or l.state == "defricher") and not l.out then', 1, true) ~= nil
    or src:find('(l.state == "libre" or l.state == "defricher") and not l.out then', 1, true) ~= nil, "make_pond() ecarte les lots libres dehors")
end

-- Lot ILOTS-MURS : le pas des îlots est appelé à chaque décision d'une équipe murée, avec son contexte (enceinte principale occupée ou non)
do
  requests = {}
  W.ilots_calls, W.ilots_ctx, W.tight = 0, nil, nil
  local f = new_team()
  W.stock_wall = 120
  step(f) -- premier segment : pas encore d'enceinte au début du pas, aucun appel
  check(W.ilots_calls == 0, "ilots : aucun appel avant l'enceinte (" .. W.ilots_calls .. ")")
  step(f)
  check(W.ilots_calls == 1 and W.ilots_ctx ~= nil and W.ilots_ctx.main_busy == true, "ilots : appele une fois, enceinte principale occupee (segment en cours)")
  check(type(W.ilots_ctx.equiv) == "function" and W.ilots_ctx.equiv() == 120 and type(W.ilots_ctx.request) == "function"
    and type(W.ilots_ctx.cancel) == "function" and type(W.ilots_ctx.repair) == "function" and W.ilots_ctx.prio == Build.PRIO - 15,
    "ilots : contexte complet (stock equivalent 120, demande, annulation, reparation, priorite des murs)")
  finish(f, requests[1], tick)
  step(f)
  check(W.ilots_calls == 2 and W.ilots_ctx.main_busy == false, "ilots : segment fini, enceinte principale libre au moment de l'appel")
end

print(string.format("[ENCEINTE-FLUX] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
