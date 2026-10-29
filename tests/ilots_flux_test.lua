--[[
  Lot ILOTS-MURS : machine d'états des murs et des tourelles des îlots (script/team/ilots.lua, le VRAI module) branchée sur le VRAI
  Build.space_step de script/team/build.lua (texte extrait entre deux repères, comme tests/enceinte_flux_test.lua), avec un moteur de
  bouchons (Stock, Build.request/cancel, surface, State, Outposts). Aucun banc moteur.
  Usage, depuis la racine du mod :   lua5.2 tests/ilots_flux_test.lua
  Vérifie : îlot retenu seulement APRÈS l'enceinte complète et sans chantier, segments un à la fois et payés au quart du stock,
  tuiles jamais en double, refus (matière) puis nouvel essai, réparation d'un mur détruit, mur complet, îlot attaqué d'abord (et son
  côté attaqué d'abord), sauvegarde d'avant ENCEINTE3, tourelles (vue, pose dans l'emprise, repos, pause après un porteur tué),
  rapport, déterminisme, journal [FO-ILOT] par cause.
]]
package.path = "./?.lua;" .. package.path
local Enc = require("shared.team.enceinte")
local P = require("shared.team.plan")
local Fr = require("shared.team.front")
local I = require("shared.team.ilots")
local D = require("shared.team.automatisation_donnees")
local T = require("shared.team.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

-- bouchons du moteur pour script/team/ilots.lua
local LOGS = {}
_G.log = function(s) LOGS[#LOGS + 1] = s end
_G.game = { tick = 0 }
local OWNERS = {}
local FORT = {}
package.loaded["script.faction.state"] = {
  sorted_keys = function(t) local k = {}; for x in pairs(t) do k[#k + 1] = x end; table.sort(k); return k end,
  owner = function(id) return OWNERS[id] end,
}
package.loaded["script.faction.outposts"] = {
  fortify_at = function(f, surface, oid, sites, count, carrier, accept)
    FORT[#FORT + 1] = { oid = oid, sites = sites, count = count, accept = accept }
    return FORT.ret or count
  end,
}
local Ilots = require("script.team.ilots")

-- extraction du code testé (même repères que tests/enceinte_flux_test.lua)
local fh = assert(io.open("script/team/build.lua", "rb"))
local src = fh:read("*a")
fh:close()
local a = assert(src:find("--- Segment d'enceinte en cours", 1, true), "repere de debut absent")
local b_ = assert(src:find("--- Pensée d'équipe (script/team/team.lua", 1, true), "repere de fin absent")
local chunk_src = src:sub(a, b_ - 1)

local W = { stock_wall = 0 }
local built = {}
local Build = { PRIO = 55 }
local env = {
  Enc = Enc, Build = Build, Ilots = Ilots, ipairs = ipairs, pairs = pairs, math = math, table = table, string = string, tostring = tostring,
  next = next, type = type,
  Stock = { count = function(_, name) if name == T.wall then return W.stock_wall end return 0 end },
  wall_recipe = function() return { item = T.wall, ings = { { name = "brique", amount = 5 } }, per = 1 } end,
  craftable_walls = function() return 0 end,
  space_log = function(_, text) LOGS[#LOGS + 1] = text end,
  space_info = function() return { radius = 5, rmax = 5, pending = 0, free = 5, busy = 0, done = 10, enc = true } end,
  enc_tight_bounds = function() return nil end,
  enc_mark_out = function() return 0 end,
  enc_release = function() end,
}
local chunk = assert(load("local Enc, Build, Ilots, ipairs, math, table, string, tostring, Stock, wall_recipe, craftable_walls, space_log, space_info, "
  .. "enc_tight_bounds, enc_mark_out, enc_release = "
  .. "Enc, Build, Ilots, ipairs, math, table, string, tostring, Stock, wall_recipe, craftable_walls, space_log, space_info, "
  .. "enc_tight_bounds, enc_mark_out, enc_release\n"
  .. chunk_src .. "\nreturn Build", "ilots_flux", "t", setmetatable(env, { __index = _G })))
chunk()

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

local lat = P.lattice({ x = 0.5, y = 0.5 })
local function ents(n, plant)
  local out = {}
  for i = 1, n do out[i] = { name = "piece" .. i, x = i, y = 0, built = true } end
  out[#out + 1] = { name = T.wall, x = 0, y = 0, built = true, wall = true } -- un mur ne compte pas dans la valeur
  return out
end
--- Équipe murée : enceinte complète (un segment fini), lots bâtis dedans et dehors.
local function new_team(opts)
  opts = opts or {}
  local projects = {
    [1] = { id = 1, state = "fini", spec = {}, ents = ents(6) },                                -- lot du QG
    [2] = { id = 2, state = "fini", spec = {}, ents = ents(10) },                               -- (4, 0) : fonderie isolée
    [3] = { id = 3, state = "fini", spec = { gen = D.PLANT.gen }, ents = ents(4) },              -- (5, 0) : centrale isolée, voisine
    [4] = { id = 4, state = "fini", spec = {}, ents = ents(2) },                                -- (0, -5) : petite mine isolée
    [5] = { id = 5, state = "fini", spec = {}, ents = ents(12) },                               -- (-5, 0) : îlot de l'ouest
    [10] = { id = 10, state = "fini", spec = { enceinte = true, walls = {} }, ents = {}, finished = 1 }, -- segment de l'enceinte principale
  }
  local lots = {
    ["0:0"] = { i = 0, j = 0, state = "occupe", used = 1 },
    ["4:0"] = { i = 4, j = 0, state = "occupe", used = 2 },
    ["5:0"] = { i = 5, j = 0, state = "occupe", used = 3 },
    ["0:-5"] = { i = 0, j = -5, state = "occupe", used = 4 },
    ["-5:0"] = { i = -5, j = 0, state = "occupe", used = opts.west and 5 or nil },
  }
  local bounds = { -50, -50, 50, 50 }
  if opts.legacy then bounds = nil end
  local f = { key = "f1", is_player = false, build = {
    opts = {}, lat = lat, radius = 5, projects = projects, order = { 1, 2, 3, 4, 5, 10 }, stats = {}, lots = lots, queue = {}, qhead = 1,
    next_id = 20, occ = {},
    enc = { r = 5, claimed = {}, segs = { { pid = 10, n = 0, side = "n" } }, complete = opts.complete ~= false,
      bounds = bounds, gates = 32 },
  } }
  if opts.front then f.front_mem = { mem = opts.front } end
  return f
end

--- Termine un segment : ses murs existent.
local function finish(p, tick)
  p.ents = {}
  for _, w in ipairs(p.spec.walls) do
    local x, y = w[1] + 0.5, w[2] + 0.5
    p.ents[#p.ents + 1] = { x = x, y = y, built = true }
    built[x .. ":" .. y] = true
  end
  p.state, p.finished, p.started = "fini", tick, tick - 100
end

local tick = 200000
local function step(f)
  tick = tick + Enc.CHECK_TICKS
  game.tick = tick
  Build.space_step(f, surface, tick)
end
local function has_log(pat, from)
  for i = from or 1, #LOGS do if LOGS[i]:find(pat, 1, true) then return true end end
  return false
end
local function walls_set(list)
  local s = {}
  for _, p in ipairs(list) do for _, w in ipairs(p.spec.walls) do s[w[1] .. ":" .. w[2]] = (s[w[1] .. ":" .. w[2]] or 0) + 1 end end
  return s
end

-- 1. Enceinte principale pas complète : rien (ni état, ni demande)
do
  requests, LOGS = {}, {}
  local f = new_team({ complete = false })
  W.stock_wall = 400
  step(f)
  local isl = 0
  for _, p in ipairs(requests) do if p.spec.ilot then isl = isl + 1 end end
  check(f.build.ilots == nil and isl == 0, "enceinte principale pas complete : aucun ilot, aucun segment d'ilot (" .. isl .. ")")
end

-- 2. Îlot retenu, premier segment, un à la fois, payé au quart du stock
local x0_4, y0_4 = P.lot_rect(lat, 4, 0)
local _, _, x1_5, y1_5 = P.lot_rect(lat, 5, 0)
local box45 = { x0 = x0_4, y0 = y0_4, x1 = x1_5, y1 = y1_5 }
local f2
do
  requests, LOGS = {}, {}
  local f = new_team()
  f2 = f
  W.stock_wall = 120 -- un quart = 30
  step(f)
  local h = f.build.ilots
  check(h ~= nil and #h.list == 1 and h.list[1].key == "4:0+5:0", "ilot retenu : les deux lots voisins de l'est (fonderie + centrale) (" .. tostring(h and h.list[1] and h.list[1].key) .. ")")
  check(h and h.list[1].value == 10 + 4 + I.PLANT_BONUS, "valeur : 10 + 4 pieces + bonus de centrale, murs exclus (" .. tostring(h and h.list[1].value) .. ")")
  check(h and h.list[1].box.x0 == box45.x0 and h.list[1].box.x1 == box45.x1, "emprise figee = union des deux lots")
  check(has_log("[FO-ILOT] f1 : ilot 4:0+5:0 retenu"), "journal : ilot retenu")
  check(#requests == 1 and requests[1].spec.ilot == "4:0+5:0" and requests[1].spec.enceinte == true and #requests[1].spec.walls <= 30,
    "un premier segment demande (projet d'enceinte marque ilot, 30 murs au plus)")
  check(requests[1].spec.side == "e", "premier segment : le cote tourne vers l'exterieur (est) (" .. tostring(requests[1].spec.side) .. ")")
  check(requests[1].spec.prio == Build.PRIO - 15 and requests[1].spec.domain == "infrastructures", "priorite et domaine des murs de l'enceinte")
  check(has_log("[FO-ILOT] f1 : segment de l'ilot 4:0+5:0 demande"), "journal : segment demande")
  -- les tuiles sont toutes sur l'anneau de l'îlot
  local ring = I.ring(box45, lat)
  local on = {}
  for _, w in ipairs(ring.walls) do on[w.tx .. ":" .. w.ty] = true end
  local off = 0
  for _, w in ipairs(requests[1].spec.walls) do if not on[w[1] .. ":" .. w[2]] then off = off + 1 end end
  check(off == 0, "toutes les tuiles du segment sont sur l'anneau de l'ilot")
  step(f)
  check(#requests == 1, "un seul segment d'ilot en cours")
  finish(requests[1], tick)
  W.stock_wall = 90 -- un quart = 22
  step(f)
  check(#requests == 2 and #requests[2].spec.walls <= 22, "premier fini : le second segment, 22 murs au plus")
  local s = walls_set(requests)
  local dup = 0
  for _, n in pairs(s) do if n > 1 then dup = dup + 1 end end
  check(dup == 0, "deux segments sans tuile commune")
  -- la petite mine (2 pièces) n'est jamais retenue
  for _, il in ipairs(h.list) do check(il.key ~= "0:-5", "la petite mine n'est pas un ilot important") end
end

-- 3. Stock pauvre : « les ressources d'abord »
do
  local f = f2
  finish(requests[2], tick)
  W.stock_wall = 20 -- un quart = 5 < SEG_MIN
  local n0, l0 = #requests, #LOGS
  step(f)
  check(#requests == n0, "stock pauvre : aucun segment")
  check(has_log("les ressources d'abord", l0 + 1), "journal : segment attendu, ressources d'abord")
  local l1 = #LOGS
  step(f)
  check(not has_log("les ressources d'abord", l1 + 1), "journal : une seule ligne par attente")
end

-- 4. Enceinte principale en chantier (réparation) : l'îlot attend
do
  local f = f2
  W.stock_wall = 400
  local main = f.build.projects[10]
  main.state, main.reopened = "reserve", 1
  local n0 = #requests
  step(f)
  check(#requests == n0, "enceinte principale en reparation : aucun segment d'ilot")
  main.state = "fini"
  step(f)
  check(#requests == n0 + 1, "enceinte principale finie : le segment d'ilot suivant")
end

-- 5. Segment refusé faute de matière : tuiles rendues, nouvel essai 5 min plus tard
do
  local f = f2
  local h = f.build.ilots
  local p = requests[#requests]
  local claimed_before = 0
  for _ in pairs(h.list[1].claimed) do claimed_before = claimed_before + 1 end
  p.state, p.reason = "refuse", "materiaux"
  local n0, l0 = #requests, #LOGS
  step(f)
  local claimed_after = 0
  for _ in pairs(h.list[1].claimed) do claimed_after = claimed_after + 1 end
  check(claimed_after == claimed_before - #p.spec.walls, "segment refuse (matiere) : ses tuiles sont rendues")
  check(#requests == n0 and h.list[1].retry ~= nil, "pas de nouvel essai avant le delai")
  check(has_log("refuse (materiaux)", l0 + 1), "journal : segment refuse")
  tick = tick + Enc.SEG_RETRY_TICKS
  step(f)
  check(#requests == n0 + 1, "apres le delai : nouvel essai")
  -- refus durable (aucun mur posable) : tuiles gardées, pas de boucle
  local p2 = requests[#requests]
  p2.state, p2.reason = "refuse", "aucun mur posable"
  step(f)
  local kept, again = true, false
  for _, w in ipairs(p2.spec.walls) do if not h.list[1].claimed[Enc.key(w[1], w[2])] then kept = false end end
  for i = n0 + 2, #requests do
    for _, w in ipairs(requests[i].spec.walls) do
      for _, w2 in ipairs(p2.spec.walls) do if w[1] == w2[1] and w[2] == w2[2] then again = true end end
    end
  end
  check(kept and not again, "refus durable : tuiles gardees, jamais redemandees (pas de boucle)")
end

-- 6. Réparation : un mur détruit rouvre son segment
do
  local f = f2
  local h = f.build.ilots
  local p1 = requests[1]
  check(p1.state == "fini", "le premier segment est fini")
  local w = p1.ents[3]
  built[w.x .. ":" .. w.y] = nil
  local l0 = #LOGS
  for _ = 1, math.ceil(Enc.REPAIR_TICKS / Enc.CHECK_TICKS) + 2 do step(f) end
  check(p1.state == "reserve" and p1.reopened == 1 and p1.ents[3].built == false, "mur detruit : le segment de l'ilot reprend son chantier")
  check(has_log("[FO-ILOT] f1 : 1 mur(s) detruit(s)", l0 + 1), "journal : mur detruit (etiquette [FO-ILOT])")
  check(Build.cancel(f, p1.id, "materiaux") == false, "segment rouvert : jamais annule")
  finish(p1, tick)
end

-- 7. Mur complet
do
  local f = f2
  local h = f.build.ilots
  W.stock_wall = 400
  local guard = 0
  while not h.list[1].complete and guard < 60 do
    guard = guard + 1
    tick = tick + Enc.SEG_RETRY_TICKS
    step(f)
    local last = requests[#requests]
    if last.state ~= "fini" and last.state ~= "refuse" then finish(last, tick) end
  end
  check(h.list[1].complete == true, "le mur de l'ilot finit complet")
  check(has_log("[FO-ILOT] f1 : mur de l'ilot 4:0+5:0 complet"), "journal : mur complet")
  -- toutes les tuiles de l'anneau réservées (sauf le refus durable), aucune en double parmi les segments finis
  local ring = I.ring(box45, lat)
  local claimed = 0
  for _ in pairs(h.list[1].claimed) do claimed = claimed + 1 end
  check(claimed == #ring.walls, "tout l'anneau reserve (" .. claimed .. " / " .. #ring.walls .. ")")
  local rep = Ilots.report(f.build)
  check(rep and rep.islands >= 1 and rep.complete >= 1 and rep.segments >= 3, "rapport : ilots, murs complets, segments")
end

-- 8. Îlot attaqué d'abord, et son côté attaqué d'abord
do
  requests, LOGS = {}, {}
  local mem = Fr.new(tick)
  local xw0, yw0, xw1 = P.lot_rect(lat, -5, 0)
  Fr.record(mem, xw0 + 12, yw0 - 8, 300) -- au nord de l'îlot de l'ouest
  local f = new_team({ west = true, front = mem })
  W.stock_wall = 120
  step(f)
  local h = f.build.ilots
  check(h and h.list[1].key == "-5:0", "l'ilot attaque (ouest) est retenu avant le plus precieux (" .. tostring(h and h.list[1].key) .. ")")
  check(#requests == 1 and requests[1].spec.ilot == "-5:0" and requests[1].spec.side == "n", "son premier segment est du cote de l'attaque (nord) (" .. tostring(requests[1] and requests[1].spec.side) .. ")")
  -- relevé suivant (5 min) : le second îlot est retenu ; l'attaqué garde la priorité des murs
  finish(requests[1], tick)
  tick = tick + Ilots.SCAN_TICKS
  step(f)
  check(#h.list == 2 and h.list[2].key == "4:0+5:0", "releve suivant : le second ilot retenu")
  check(requests[#requests].spec.ilot == "-5:0", "l'ilot attaque garde la priorite des murs")
  -- tourelles : l'attaqué en veut 2
  local fo = {}
  local v = Ilots.view(f, fo, 500)
  check(v and v.pick and v.pick.key == "-5:0" and v.pick.want == 2 and v.pick.missing == 2, "tourelles : l'ilot attaque d'abord, 2 voulues")
  check(v and v.floor_i == 2 * T.defend_iron_floor and v.busy == false, "planchers doubles, tache libre")
  check(has_log("[FO-ILOT] f1 : tourelles des ilots"), "journal : etat des tourelles")
  -- une tourelle de l'équipe dans l'emprise compte
  f.turrets = { [101] = { valid = true, position = { x = xw0 + 5, y = yw0 + 5 } } }
  OWNERS[101] = { f = 1, kind = "turret", oid = "ilot-5:0" }
  local v2 = Ilots.view(f, fo, 500)
  check(v2.pick and v2.pick.key == "-5:0" and v2.pick.have == 1 and v2.pick.missing == 1, "une tourelle deja la : il en manque une")
  -- pose : poste « ilot<cle> », acceptée dans l'emprise seulement
  FORT = {}
  local n = Ilots.place(f, {}, { ilot = "-5:0", box = v2.pick.box, sites = v2.pick.sites, items = { { T.turret, 1 }, { T.turret_ammo, 10 } } }, {})
  check(n == 1 and FORT[1].oid == "ilot-5:0" and FORT[1].count == 1, "pose : poste ilot-5:0, une tourelle")
  check(FORT[1].accept({ x = xw0 + 2, y = yw0 + 2 }) and not FORT[1].accept({ x = xw0 - 20, y = yw0 }), "pose acceptee dans l'emprise, refusee loin")
  check(has_log("[FO-ILOT] f1 : pose de 1 tourelle(s)"), "journal : pose")
  -- pose à zéro : îlot au repos, le suivant est servi
  FORT = {}
  FORT.ret = 0
  Ilots.place(f, {}, { ilot = "-5:0", box = v2.pick.box, sites = {}, items = { { T.turret, 1 } } }, {})
  FORT.ret = nil
  local v3 = Ilots.view(f, fo, 500)
  check(v3.pick and v3.pick.key == "4:0+5:0" and v3.pick.want == 1, "ilot au repos : l'autre ilot (calme) recoit 1 tourelle")
  -- porteur tué : pause
  Ilots.on_lost(f, 7, "biter")
  local v4 = Ilots.view(f, fo, 500)
  check(v4.pick == nil, "porteur tue en route : pause du poste")
  check(has_log("[FO-ILOT] f1 : PNJ 7 tue"), "journal : porteur tue")
  f.turrets, OWNERS = nil, {}
end

-- 9. Sauvegarde d'avant ENCEINTE3 (anneau du rayon, sans contour) : aucun îlot
do
  requests, LOGS = {}, {}
  local f = new_team({ legacy = true })
  W.stock_wall = 400
  step(f)
  check(f.build.ilots ~= nil and #f.build.ilots.list == 0 and #requests == 0, "sans contour serre : aucun ilot, aucune demande")
  check(has_log("enceinte sans contour serre"), "journal : la raison")
  check(Ilots.view(f, {}, 0) == nil, "aucun ilot : aucune vue de tourelles")
end

-- 10. Déterminisme : deux parties identiques, mêmes demandes
do
  local function play()
    requests, LOGS = {}, {}
    built = {}
    tick = 500000
    local f = new_team({ west = true })
    W.stock_wall = 160
    for _ = 1, 12 do
      step(f)
      local last = requests[#requests]
      if last and last.state == "attente" then finish(last, tick) end
    end
    local out = {}
    for _, p in ipairs(requests) do
      local t = {}
      for _, w in ipairs(p.spec.walls) do t[#t + 1] = w[1] .. "," .. w[2] end
      out[#out + 1] = p.spec.ilot .. "|" .. table.concat(t, ";")
    end
    return table.concat(out, "\n"), #requests
  end
  local a1, n1 = play()
  local a2, n2 = play()
  check(n1 >= 4 and a1 == a2, "deux parties identiques : memes segments (" .. n1 .. ")")
end

print(string.format("[ILOTS-FLUX] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
