--[[
  Lot TOURELLES-HORS-AXE (retour du DC du 29/10 sur 0.6.18, défaut 4 : « le canon est en plein milieu [...] si on voulait étendre
  sur la gauche [...] on pourrait pas »). Usage : lua5.2 tests/axe_test.lua

  1. règles pures de shared/team/axe.lua (axe, couloir, emprise, contact, positions de côté, déterminisme) ;
  2. Build.corridors et Build.axis_entity (code EXTRAIT de script/team/build.lua, vrais P et M) : quels projets ont un couloir ;
  3. Outposts.fortify_at (vrai script/faction/outposts.lua, moteur factice) : la tourelle voulue dans le couloir est posée SUR LE
     CÔTÉ de la ligne, journal [FO-AXE] ; hors couloir et sans crochet : comme avant ; réservation (b.occ) toujours respectée ;
  4. move_turrets_off (code EXTRAIT de build.lua) : la tourelle de l'équipe sur l'emprise d'une pièce à poser est DÉPLACÉE (teleport)
     hors des couloirs et des tuiles réservées ; tourelle d'un joueur, arbre, aucune place : rien ne bouge ;
  5. câblage (texte) : crochets posés, appels aux deux refus « occupe », repli « récupérée au coffre » gardé ;
  6. mutants : chaque règle cassée est vue par au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path
defines = { direction = { north = 0, east = 2, south = 4, west = 6 }, inventory = { chest = 1 } }
local logs = {}
function log(s) logs[#logs + 1] = s end

local passes, failures = 0, 0
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. m) end end

local function read(path) local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s end
local AXE_SRC = read("shared/team/axe.lua")
local function load_axe(src) return assert(load(src, "axe", "t", _G))() end
local Axe = load_axe(AXE_SRC)
package.loaded["shared.team.axe"] = Axe

local P = require("shared.team.plan")
local M = require("shared.team.modules")
local Blocage = require("shared.team.blocage")
local T = require("shared.team.config")

_G.game = { entity_prototypes = {
  ["gun-turret"] = { tile_width = 2, tile_height = 2, turret_range = 18 },
  ["transport-belt"] = { tile_width = 1, tile_height = 1, type = "transport-belt" },
  ["fast-transport-belt"] = { tile_width = 1, tile_height = 1, type = "transport-belt" }, -- relecture : tapis amélioré (Conv)
  ["stone-furnace"] = { tile_width = 2, tile_height = 2 },
} }

-- Le cas du DC : treillis en (0, 0), lot (0, 0) = tuiles [-12, 12) ; ligne de fours verticale de 6 × 14 en (-3, -8), tapis au
-- milieu (nord-sud) ; la tourelle voulue en (0, 9), au bout de la ligne, « en plein milieu de l'axe ».
local LOT = { x0 = -12, y0 = -12, x1 = 12, y1 = 12 }
local PART = { x0 = -3, y0 = -8, x1 = 3, y1 = 6 }

---------------------------------------------------------------------------------------------------
-- 1. Règles pures
---------------------------------------------------------------------------------------------------
local function pure(A)
  local ok = true
  local function c(v, m) if not v then ok = false end check(v, m) end
  c(A.axis_of({ 0, 0, 4 }) == "y", "axe : tapis nord-sud -> y")
  c(A.axis_of({ 2, 6, 2 }) == "x", "axe : tapis est-ouest -> x")
  c(A.axis_of({ 0, 0, 2 }) == "y", "axe : majorité")
  c(A.axis_of({}) == nil and A.axis_of(nil) == nil, "axe : sans tapis -> nil")
  c(A.axis_of({ 0, 2 }) == nil, "axe : égalité -> nil")
  c(A.axis_of({ 1, 3, 5 }) == nil, "axe : diagonales ignorées")
  local cy = A.corridor(PART, LOT, "y")
  c(cy and cy.x0 == -4 and cy.x1 == 4 and cy.y0 == -12 and cy.y1 == 12 and cy.axis == "y",
    "couloir y : largeur du module + 1 de chaque côté, toute la longueur du lot")
  local cx = A.corridor({ x0 = -8, y0 = 2, x1 = 6, y1 = 6 }, LOT, "x")
  c(cx and cx.x0 == -12 and cx.x1 == 12 and cx.y0 == 1 and cx.y1 == 7 and cx.axis == "x", "couloir x")
  local edge = A.corridor({ x0 = -12, y0 = -8, x1 = -6, y1 = 6 }, LOT, "y")
  c(edge and edge.x0 == -12, "couloir rogné au lot")
  c(A.corridor(PART, LOT, nil) == nil and A.corridor(PART, nil, "y") == nil, "couloir sans axe ou sans lot -> nil")
  local wide = A.corridor(PART, LOT, "y", 3)
  c(wide and wide.x0 == -6 and wide.x1 == 6, "couloir : largeur de côté en paramètre")
  local x0, y0, x1, y1 = A.tile_rect(-6, 9, 2, 2)
  c(x0 == -7 and y0 == 8 and x1 == -5 and y1 == 10, "emprise 2 × 2")
  x0, y0, x1, y1 = A.tile_rect(0.5, 0.5, 1, 1)
  c(x0 == 0 and y0 == 0 and x1 == 1 and y1 == 1, "emprise 1 × 1")
  x0, y0, x1, y1 = A.tile_rect(1.5, 1.5, 3, 3)
  c(x0 == 0 and y0 == 0 and x1 == 3 and y1 == 3, "emprise 3 × 3")
  c(A.hit({ cy }, -1, 8, 1, 10) == cy, "tourelle dans le couloir : touchée")
  c(A.hit({ cy }, 4, 8, 6, 10) == nil and A.hit({ cy }, -6, 8, -4, 10) == nil, "contact par un bord : pas de recouvrement (F96)")
  c(A.hit({ cy }, -6, 12, -4, 14) == nil and A.hit({ cy }, -1, 12, 1, 14) == nil, "hors du lot : pas de recouvrement")
  local _, idx = A.hit({ cx, cy }, -1, 8, 1, 10)
  c(idx == 2, "hit : indice du couloir")
  local s = A.side_spots(0, 9, { cy }, 2, 2)
  c(#s == 2 * #A.STEPS, "positions de côté : deux côtés × décalages")
  c(s[1].x == -6 and s[1].y == 9, "égalité : le côté des petites coordonnées d'abord, même hauteur")
  c(s[#A.STEPS + 1].x == 6, "puis l'autre côté")
  local all_out = true
  for _, q in ipairs(s) do
    local a0, b0, a1, b1 = A.tile_rect(q.x, q.y, 2, 2)
    if A.hit({ cy }, a0, b0, a1, b1) or A.hit({ cy }, a0 - A.GAP, b0, a1 + A.GAP, b1) then all_out = false end
  end
  c(all_out, "positions de côté : hors du couloir, à " .. A.GAP .. " tuile d'écart")
  local s2 = A.side_spots(2, 9, { cy }, 2, 2)
  c(s2[1].x == 6, "côté le plus proche d'abord (est)")
  local s3 = A.side_spots(-9, 9, { cy }, 2, 2)
  c(#s3 == 0, "hors couloir : aucune position de côté")
  local sx = A.side_spots(0, 4, { cx }, 2, 2)
  c(#sx > 0 and sx[1].y == -1 and sx[1].x == 0 and sx[#A.STEPS + 1].y == 9, "axe x : positions au-dessus puis au-dessous")
  local again = A.side_spots(0, 9, { cy }, 2, 2)
  local same = #again == #s
  for i = 1, #s do if not (again[i] and again[i].x == s[i].x and again[i].y == s[i].y) then same = false end end
  c(same, "déterministe")
  return ok
end
pure(Axe)

---------------------------------------------------------------------------------------------------
-- 2. Build.corridors / Build.axis_entity / Build.reserved_entity (extraits de script/team/build.lua)
---------------------------------------------------------------------------------------------------
local BUILD_SRC = read("script/team/build.lua")
local function extract(src, from, to)
  local a = assert(src:find(from, 1, true), "repère absent : " .. from)
  local b = assert(src:find(to, a, true), "repère absent : " .. to)
  return src:sub(a, b - 1)
end
local Build = {}
local Outposts, Stock = {}, {}
local function load_build(src, A)
  local chunk_src = extract(src, "--- Lot AUTO : l'emprise d'une entité `name`", "Build.ROUTE_WEIGHT")
  -- Conv.belts : tapis des données (relecture : un tapis amélioré en place garde le couloir)
  local Conv = { belts = function() return { { name = "transport-belt" }, { name = "fast-transport-belt" } } end }
  local env = setmetatable({ Build = Build, Outposts = Outposts, Stock = Stock, P = P, M = M, Axe = A, Conv = Conv }, { __index = _G })
  assert(load("local Build, Outposts, Stock, P, M, Axe = Build, Outposts, Stock, P, M, Axe\n" .. chunk_src, "build_axe", "t", env))()
end
load_build(BUILD_SRC, Axe)

local lat = P.lattice({ x = 0, y = 0 })
local function belt(x, y, dir, part) return { name = "transport-belt", x = x, y = y, dir = dir, part = part } end
local function team()
  local b = { lat = lat, order = {}, projects = {}, occ = {}, stats = {} }
  return { key = "ambre", force = "f1", id = 1, turrets = {}, outposts = {}, stats = {}, build = b }
end
local function add_project(f, id, spec, parts, ents, extra)
  local p = { id = id, spec = spec, parts = parts, ents = ents, state = "fini" }
  for k, v in pairs(extra or {}) do p[k] = v end
  f.build.projects[id] = p
  f.build.order[#f.build.order + 1] = id
  return p
end
local function line_team()
  local f = team()
  local ents = {}
  for y = -7.5, 5.5 do ents[#ents + 1] = belt(-0.5, y, 0, 1) end
  ents[#ents + 1] = { name = "stone-furnace", x = -2, y = -6, dir = 0, part = 1 }
  add_project(f, 1, { gen = "smelter", feed = "tapis" }, { { kind = "module", ox = -3, oy = -8, w = 6, h = 14 } }, ents)
  return f
end
do
  local f = line_team()
  local cors = Build.corridors(f)
  check(#cors == 1 and cors[1].axis == "y" and cors[1].x0 == -4 and cors[1].x1 == 4 and cors[1].y0 == -12 and cors[1].y1 == 12
    and cors[1].pid == 1 and cors[1].part == 1, "fonderie à tapis : couloir le long de la ligne, toute la longueur du lot")
  check(Build.axis_entity(cors, "gun-turret", { x = 0, y = 9 }) == cors[1], "tourelle au bout de la ligne : dans le couloir")
  check(Build.axis_entity(cors, "gun-turret", { x = -6, y = 9 }) == nil, "tourelle à côté : hors du couloir")
  check(Build.axis_entity({}, "gun-turret", { x = 0, y = 9 }) == nil, "sans couloir : rien")
  -- rangée de foreuses (partie 2, horizontale), même projet
  local p = f.build.projects[1]
  p.parts[2] = { kind = "foreuses", ox = 30, oy = -4, w = 16, h = 6 }
  for x = 30.5, 45.5 do p.ents[#p.ents + 1] = belt(x, -0.5, 6, 2) end
  p.ents[#p.ents + 1] = belt(29.5, -0.5, 0, 2) -- tapis de liaison hors de la partie : ne compte pas
  cors = Build.corridors(f)
  check(#cors == 2 and cors[2].axis == "x" and cors[2].part == 2 and cors[2].x0 == 16 and cors[2].x1 == 40,
    "rangée de foreuses : couloir horizontal rogné à son lot")
  -- relecture : tapis de la rangée amélioré en place (script/team/convoyeurs.lua réécrit e.name) : le couloir reste
  for _, e in ipairs(p.ents) do if e.part == 2 then e.name = "fast-transport-belt" end end
  cors = Build.corridors(f)
  check(#cors == 2 and cors[2].axis == "x" and cors[2].part == 2, "rangée à tapis amélioré : couloir gardé (type du prototype)")
end
do
  local f = team()
  add_project(f, 1, { gen = "assembler", feed = "quai" }, { { kind = "module", ox = -3, oy = -8, w = 6, h = 14 } }, { belt(-0.5, 0.5, 0, 1) })
  add_project(f, 2, { gen = "smelter", feed = "tapis", fixe = true }, { { kind = "module", ox = 25, oy = -8, w = 6, h = 14 } }, { belt(27.5, 0.5, 0, 1) })
  add_project(f, 3, { gen = "smelter", feed = "tapis" }, { { kind = "module", ox = -3, oy = 20, w = 6, h = 14 } }, { belt(-0.5, 25.5, 0, 1) }, { abandoned = true })
  add_project(f, 4, { gen = "smelter", feed = "tapis" }, { { kind = "module", ox = 25, oy = 20, w = 6, h = 14 } }, { belt(27.5, 25.5, 0, 1) }, { state = "refuse" })
  add_project(f, 5, { gen = "smelter", feed = "tapis" }, { { kind = "module", ox = 53, oy = -8, w = 6, h = 14 } }, {})
  check(#Build.corridors(f) == 0, "module non extensible, ligne fixe, abandonnée, refusée, sans tapis : aucun couloir")
  check(#Build.corridors({}) == 0 and #Build.corridors(nil) == 0, "équipe sans plan directeur : aucun couloir")
end

---------------------------------------------------------------------------------------------------
-- 3. Outposts.fortify_at (vrai script/faction/outposts.lua, moteur factice)
---------------------------------------------------------------------------------------------------
package.loaded["script.faction.state"] = { own = function() end, sorted_keys = function(t) local k = {} for a in pairs(t) do k[#k + 1] = a end table.sort(k) return k end }
package.loaded["script.faction.sites"] = {}
package.loaded["script.ai3.places_qg"] = {}
local OUT_SRC = read("script/faction/outposts.lua")
local function load_outposts(src)
  package.loaded["script.faction.outposts"] = nil
  local O = assert(load(src, "outposts", "t", _G))()
  return O
end
local function world(blocked)
  local placed = {}
  local surface = {}
  surface.find_non_colliding_position = function(_, c)
    if blocked and blocked(c) then return nil end
    return { x = c.x, y = c.y }
  end
  surface.find_entities_filtered = function() return {} end
  surface.create_entity = function(q)
    local e = { name = q.name, position = q.position, unit_number = 1000 + #placed, valid = true,
      get_item_count = function() return 0 end, insert = function() end }
    placed[#placed + 1] = e
    return e
  end
  return surface, placed
end
local function carrier(n) local c = { n = n }
  c.get_item_count = function(name) return name == "gun-turret" and c.n or 0 end
  c.remove = function(q) if q.name == "gun-turret" then c.n = c.n - q.count end return q.count end
  return c
end
local function fortify_cases(O, label)
  local ok = true
  local function c(v, m) if not v then ok = false end check(v, (label or "") .. m) end
  local f = line_team()
  O.corridors = function(ff) return Build.corridors(ff) end
  O.axe_log = function(ff, text) log("[FO-AXE] " .. tostring(ff.key) .. " : " .. text) end
  O.reserved = nil
  logs = {}
  local s, placed = world()
  local n = O.fortify_at(f, s, 7, { { x = 0, y = 9 } }, 1, carrier(3))
  c(n == 1 and placed[1].position.x == -6 and placed[1].position.y == 9, "pose : tourelle voulue au bout de la ligne -> sur le côté (-6, 9)")
  local found = false
  for _, l in ipairs(logs) do if l:find("[FO-AXE]", 1, true) and l:find("couloir d'extension du projet 1", 1, true) then found = true end end
  c(found, "pose : une ligne [FO-AXE]")
  -- hors couloir : comme avant, aucun journal
  logs = {}
  s, placed = world()
  n = O.fortify_at(f, s, 7, { { x = -9, y = 0 } }, 1, carrier(3))
  -- (intégration 0.6.21 avec PD-ESPACEMENT : la pose écrit désormais son bilan [FO-TOUR-ECART] ; « sans journal » = aucune ligne [FO-AXE])
  local axe_lines = 0
  for _, l in ipairs(logs) do if l:find("[FO-AXE]", 1, true) then axe_lines = axe_lines + 1 end end
  c(n == 1 and placed[1].position.x == -9 and placed[1].position.y == 0 and axe_lines == 0, "pose hors couloir : inchangée, sans journal [FO-AXE]")
  -- côté ouest réservé (b.occ) : l'autre côté
  O.reserved = function(_, _, q) return q.x < -4 end
  s, placed = world()
  n = O.fortify_at(f, s, 7, { { x = 0, y = 9 } }, 1, carrier(3))
  c(n == 1 and placed[1].position.x == 6, "pose : côté ouest réservé -> côté est")
  O.reserved = nil
  -- le moteur refuse tout hors du couloir (relief) : jamais dans le couloir, emplacement sauté
  logs = {}
  s, placed = world(function(q) return q.x < -4 or q.x >= 4 or q.y >= 12 or q.y < -12 end)
  n = O.fortify_at(f, s, 7, { { x = 0, y = 9 } }, 1, carrier(3))
  local skipped = false
  for _, l in ipairs(logs) do if l:find("emplacement saute", 1, true) then skipped = true end end
  c(n == 0 and #placed == 0 and skipped, "pose : aucune place hors des couloirs -> rien posé dans le couloir, journal")
  -- sans crochet (projet sans plan directeur) : l'ancien comportement
  O.corridors = nil
  s, placed = world()
  n = O.fortify_at(f, s, 7, { { x = 0, y = 9 } }, 1, carrier(3))
  c(n == 1 and placed[1].position.x == 0 and placed[1].position.y == 9, "sans crochet : comme avant")
  return ok
end
local Outposts_real = load_outposts(OUT_SRC)
fortify_cases(Outposts_real)

---------------------------------------------------------------------------------------------------
-- 4. move_turrets_off (extrait de script/team/build.lua)
---------------------------------------------------------------------------------------------------
local function footprint(e)
  local w = (game.entity_prototypes[e.name] or {}).tile_width or 1
  return { { e.x - w / 2 + 0.05, e.y - w / 2 + 0.05 }, { e.x + w / 2 - 0.05, e.y + w / 2 - 0.05 } }
end
local function load_move(src, A)
  local chunk_src = extract(src, "--- Lot TOURELLES-HORS-AXE : une tourelle ENREGISTRÉE", "--- Refus passager")
  local env = setmetatable({ Build = Build, Blocage = Blocage, Axe = A, T = T, footprint = footprint }, { __index = _G })
  return assert(load("local Build, Blocage, Axe, T, footprint = Build, Blocage, Axe, T, footprint\n" .. chunk_src
    .. "\nreturn move_turrets_off", "move", "t", env))()
end
local function move_world(ents, blocked)
  local s = {}
  s.find_entities_filtered = function(q)
    local a, out = q.area, {}
    for _, x in ipairs(ents) do
      if x.valid then
        local h = (game.entity_prototypes[x.name] or {}).tile_width or 1
        h = h / 2
        if x.position.x - h < a[2][1] and a[1][1] < x.position.x + h and x.position.y - h < a[2][2] and a[1][2] < x.position.y + h then out[#out + 1] = x end
      end
    end
    return out
  end
  s.find_non_colliding_position = function(_, c)
    if blocked and blocked(c) then return nil end
    return { x = c.x, y = c.y }
  end
  return s
end
local function turret(x, y, un, force)
  local t = { name = "gun-turret", position = { x = x, y = y }, unit_number = un, valid = true, force = { name = force or "f1" } }
  t.teleport = function(pos) t.position = { x = pos.x, y = pos.y } return true end
  return t
end
local function move_cases(mv, label)
  local ok = true
  local function c(v, m) if not v then ok = false end check(v, (label or "") .. m) end
  -- la ligne s'étend : tapis à poser en (-0.5, 8.5), une tourelle de l'équipe posée en (0, 9) avant ce lot
  local f = line_team()
  local t = turret(0, 9, 501)
  f.turrets[501] = t
  local piece = belt(-0.5, 8.5, 0, 1)
  local p = f.build.projects[1]
  p.ents[#p.ents + 1] = piece
  for _, q in ipairs(p.ents) do
    for _, tt in ipairs({ { math.floor(q.x), math.floor(q.y) } }) do f.build.occ[P.tkey(tt[1], tt[2])] = 1 end
  end
  logs = {}
  local s = move_world({ t })
  local r = mv(f, s, p, piece)
  c(r == true and t.valid and t.position.x == -6 and t.position.y == 9, "déplacée : sur le côté de la ligne (-6, 9), pas détruite")
  local x0, y0, x1, y1 = Axe.tile_rect(t.position.x, t.position.y, 2, 2)
  c(Axe.hit(Build.corridors(f), x0, y0, x1, y1) == nil and not Build.reserved_entity(f, "gun-turret", t.position), "nouvelle place : hors couloir et non réservée")
  c(f.build.stats.turrets_moved == 1, "compteur turrets_moved")
  local found = false
  for _, l in ipairs(logs) do if l:find("[FO-AXE]", 1, true) and l:find("tourelle deplacee", 1, true) then found = true end end
  c(found, "journal [FO-AXE] du déplacement")
  -- côté ouest réservé : côté est
  f = line_team()
  t = turret(0, 9, 502)
  f.turrets[502] = t
  p = f.build.projects[1]
  for x = -9, -5 do for y = -20, 20 do f.build.occ[P.tkey(x, y)] = 9 end end
  s = move_world({ t })
  r = mv(f, s, p, piece)
  c(r == true and t.position.x == 6, "côté ouest réservé : déplacée à l'est")
  -- les deux côtés refusés par le moteur : l'anneau voisin, jamais dans le couloir (ici au-delà du bout du lot)
  f = line_team()
  t = turret(0, 9, 507)
  f.turrets[507] = t
  p = f.build.projects[1]
  p.ents[#p.ents + 1] = piece
  for _, q in ipairs(p.ents) do f.build.occ[P.tkey(math.floor(q.x), math.floor(q.y))] = 1 end
  s = move_world({ t }, function(q) return q.x <= -5 or q.x >= 5 end)
  r = mv(f, s, p, piece)
  x0, y0, x1, y1 = Axe.tile_rect(t.position.x, t.position.y, 2, 2)
  c(r == true and Axe.hit(Build.corridors(f), x0, y0, x1, y1) == nil, "côtés refusés : déplacée sur l'anneau, hors couloir")
  -- tourelle d'un joueur (non enregistrée) : jamais touchée
  f = line_team()
  t = turret(0, 9, 503)
  s = move_world({ t })
  r = mv(f, s, f.build.projects[1], piece)
  c(r == false and t.position.x == 0, "tourelle non enregistrée : pas déplacée")
  -- tourelle + arbre : rien
  f = line_team()
  t = turret(0, 9, 504)
  f.turrets[504] = t
  local tree = { name = "tree-01", position = { x = -0.5, y = 8.5 }, valid = true, force = { name = "neutral" } }
  s = move_world({ t, tree })
  r = mv(f, s, f.build.projects[1], piece)
  c(r == false and t.position.x == 0, "tourelle et arbre : pas déplacée (ancien traitement)")
  -- aucune place libre : rien, journal
  f = line_team()
  t = turret(0, 9, 505)
  f.turrets[505] = t
  logs = {}
  s = move_world({ t }, function() return true end)
  r = mv(f, s, f.build.projects[1], piece)
  local said = false
  for _, l in ipairs(logs) do if l:find("non deplacee", 1, true) then said = true end end
  c(r == false and t.position.x == 0 and said, "aucune place : pas déplacée, journal")
  -- teleport refusé par le moteur : faux (le repli « récupérée au coffre » de free_own_turrets prend la suite)
  f = line_team()
  t = turret(0, 9, 506)
  t.teleport = function() return false end
  f.turrets[506] = t
  s = move_world({ t })
  c(mv(f, s, f.build.projects[1], piece) == false, "teleport refusé : faux")
  -- rien sur l'emprise : faux, sans appel du moteur de place
  f = line_team()
  s = move_world({})
  c(mv(f, s, f.build.projects[1], piece) == false, "emprise libre : faux")
  return ok
end
move_cases(load_move(BUILD_SRC, Axe))

---------------------------------------------------------------------------------------------------
-- 5. Câblage (texte)
---------------------------------------------------------------------------------------------------
local function count(src, pat) local n = 0 for _ in src:gmatch(pat) do n = n + 1 end return n end
check(BUILD_SRC:find('Outposts.corridors = function(f) return Build.corridors(f) end', 1, true) ~= nil, "crochet Outposts.corridors posé par build.lua")
check(BUILD_SRC:find('Outposts.axe_log = function(f, text) return Build.axe_log(f, text) end', 1, true) ~= nil, "crochet Outposts.axe_log posé")
check(count(BUILD_SRC, 'if r == "occupe" and move_turrets_off%(f, surface, p, e%) then r = place_ghost%(surface, f, e%) end') == 2,
  "déplacement appelé aux deux refus « occupe » (revive_one, phase fantomes)")
check(BUILD_SRC:find('and move_turrets_off(f, surface, p, e) then', 1, true) ~= nil and BUILD_SRC:find('x.mine({ inventory = inv', 1, true) ~= nil,
  "free_own_turrets : déplacée d'abord, repli « récupérée au coffre » gardé")
check(OUT_SRC:find('require("shared.team.axe")', 1, true) ~= nil and OUT_SRC:find('in_axe(q) ~= nil', 1, true) ~= nil, "fortify_at lit les couloirs")
check(not AXE_SRC:find("[^i]pairs%("), "axe.lua : aucun pairs non trié")
check(not AXE_SRC:find("math.random") and not AXE_SRC:find("math.sin") and not AXE_SRC:find("math.cos") and not AXE_SRC:find("game%."),
  "axe.lua : pur (ni hasard, ni trigonométrie, ni API)")
check(not AXE_SRC:find('"gun%-turret"') and not AXE_SRC:find('"transport%-belt"'), "axe.lua : aucun nom d'objet")

---------------------------------------------------------------------------------------------------
-- 6. Mutants
---------------------------------------------------------------------------------------------------
local saved = { passes = passes, failures = failures }
local function quiet(fn)
  local p0, f0 = passes, failures
  local real_print = print
  print = function() end
  local okc, res = pcall(fn)
  print = real_print
  local caught = (not okc) or res == false or failures > f0
  passes, failures = p0, f0
  return caught
end
local function mutant(name, file_src, from, to, run)
  local m = file_src:gsub(from, to, 1)
  if m == file_src then check(false, "mutant " .. name .. " : motif introuvable") return end
  check(quiet(function() return run(m) end), "mutant " .. name .. " détecté")
end
local function with_axe(m, fn) local A = load_axe(m) local r = fn(A) return r end
mutant("contact compte", AXE_SRC, "if x0 < c%.x1 and c%.x0 < x1", "if x0 <= c.x1 and c.x0 <= x1", function(m) return with_axe(m, pure) end)
mutant("sans écart", AXE_SRC, "A%.GAP = 1", "A.GAP = 0", function(m) return with_axe(m, pure) end)
mutant("couloir court", AXE_SRC, "y0 = lot%.y0, y1 = lot%.y1, axis = \"y\"", "y0 = part.y0, y1 = part.y1, axis = \"y\"", function(m) return with_axe(m, pure) end)
mutant("côté lointain", AXE_SRC, "if %(x %- c%.x0%) > %(c%.x1 %- x%)", "if (x - c.x0) < (c.x1 - x)", function(m) return with_axe(m, pure) end)
mutant("axe inversé", AXE_SRC, "if d %% 4 == 0 then v = v %+ 1", "if d %% 4 == 0 then h = h + 1", function(m) return with_axe(m, pure) end)
mutant("pose ignore le couloir", OUT_SRC, "or in_axe%(q%) ~= nil or", "or", function(m) return fortify_cases(load_outposts(m)) end)
mutant("repli dans le couloir", OUT_SRC, "if q and not in_axe%(q%) then pos = q end", "if q then pos = q end", function(m) return fortify_cases(load_outposts(m)) end)
mutant("côté d'abord oublié", OUT_SRC, "local spots = Axe%.side_spots%(s%.x, s%.y, cors, tw, th%)", "local spots = {}",
  function(m) return fortify_cases(load_outposts(m)) end)
mutant("déplacement dans un couloir", BUILD_SRC, "or Build%.axis_entity%(cors, x%.name, q%) ~= nil end%)", "end)", function(m) return move_cases(load_move(m, Axe)) end)
mutant("joueur déplacé", BUILD_SRC, "local mine = x%.unit_number ~= nil and f%.turrets%[x%.unit_number%] ~= nil\n    list",
  "local mine = true\n    list", function(m) return move_cases(load_move(m, Axe)) end)
mutant("ligne sans couloir", BUILD_SRC, "%(i == 1 and spec%.gen == \"smelter\" and spec%.feed == \"tapis\"%) or ", "",
  function(m)
    load_build(m, Axe)
    local r = #Build.corridors(line_team()) == 1
    load_build(BUILD_SRC, Axe)
    return r
  end)
mutant("tapis amélioré ignoré", BUILD_SRC, "for _, bt in ipairs%(Conv%.belts%(%)%) do belt_of%[bt%.name%] = true end", "",
  function(m)
    load_build(m, Axe)
    local f = line_team()
    local p = f.build.projects[1]
    p.parts[2] = { kind = "foreuses", ox = 30, oy = -4, w = 16, h = 6 }
    for x = 30.5, 45.5 do p.ents[#p.ents + 1] = { name = "fast-transport-belt", x = x, y = -0.5, dir = 6, part = 2 } end
    local r = #Build.corridors(f) == 2
    load_build(BUILD_SRC, Axe)
    return r
  end)
package.loaded["script.faction.outposts"] = Outposts_real

print(string.format("[AXE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
