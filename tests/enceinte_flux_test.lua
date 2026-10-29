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
}
local chunk = assert(load("local Enc, Build, ipairs, math, table, string, tostring, Stock, wall_recipe, craftable_walls, space_log, space_info = "
  .. "Enc, Build, ipairs, math, table, string, tostring, Stock, wall_recipe, craftable_walls, space_log, space_info\n"
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

print(string.format("[ENCEINTE-FLUX] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
