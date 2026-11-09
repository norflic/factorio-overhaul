--[[
  Lot PURETE-TAPIS : côté runtime du garde-fou (script/team/purete.lua) contre un moteur simulé, hors jeu : lua5.2 tests/purete_script_test.lua
    §1 lecture du monde : tapis, répartiteur (deux tuiles), souterrains (entrée muette, sortie verse), fantômes ; tuiles interdites à l'A* ;
    §2 lecture du plan : b.occ donne le projet, tapis du plan qui versent, projets exclus (le projet lui-même, abandonné, refusé) ;
    §3 preuve d'un tracé : monde + plan, objet déclaré de la ligne d'un projet, cibles, tuiles propres ;
    §4 queues de gabarit (front_ok) ; §5 compteurs, journal, plafond de lignes ; §6 réglage éteint ;
    §7 COÛT en instructions (debug.sethook) : pire appel de la preuve d'un tracé de 130 tuiles, de fronts() par tuile, de pidx() d'un projet de 120 pièces ;
    §8 interface de banc ; §9 branchements : chaque poseur appelle le garde (lecture du source).
]]

package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end
end

-- Bouchons --------------------------------------------------------------------------------------
local LOG = {}
log = function(s) LOG[#LOG + 1] = s end
game = { tick = 1000, surfaces = {} }
local REMOTE = {}
remote = { add_interface = function(name, t) REMOTE[name] = t end }
package.loaded["script.team.convoyeurs"] = { belts = function() return { { name = "transport-belt" }, { name = "fast-transport-belt" } } end }
local FACTION = { key = "player", force = "player" }
package.loaded["script.faction.state"] = {
  faction = function(k) if k == "player" then return FACTION end end,
  alive = function() return {} end,
}

local Pu = require("shared.team.purete")
local P = require("shared.team.plan")
local Pur = require("script.team.purete")

local ENTS, GHOSTS = {}, {}
local function belt(x, y, dir, ty, extra)
  local e = { valid = true, type = ty or "transport-belt", position = { x = x + 0.5, y = y + 0.5 }, direction = dir,
    bounding_box = { left_top = { x = x + 0.1, y = y + 0.1 }, right_bottom = { x = x + 0.9, y = y + 0.9 } } }
  for k, v in pairs(extra or {}) do e[k] = v end
  return e
end
local function splitter(x, y, dir) -- vers le nord : deux tuiles côte à côte (x, y) et (x + 1, y)
  return { valid = true, type = "splitter", position = { x = x + 1, y = y + 0.5 }, direction = dir,
    bounding_box = { left_top = { x = x + 0.1, y = y + 0.1 }, right_bottom = { x = x + 1.9, y = y + 0.9 } } }
end

local SURF = { index = 1 }
game.surfaces[1] = SURF
local CALLS = 0
SURF.find_entities_filtered = function(t)
  CALLS = CALLS + 1
  local list = (t.type == "entity-ghost") and GHOSTS or ENTS
  local out = {}
  local a = t.area
  for _, e in ipairs(list) do
    local bb = e.bounding_box
    if not a or not (bb.right_bottom.x <= a[1][1] or bb.left_top.x >= a[2][1] or bb.right_bottom.y <= a[1][2] or bb.left_top.y >= a[2][2]) then
      out[#out + 1] = e
    end
  end
  return out
end

local function reset()
  ENTS, GHOSTS, LOG = {}, {}, {}
  game.tick = game.tick + 1000 -- les chunks lus au test d'avant ont expiré (Pur.TTL)
  FACTION.build = { order = {}, projects = {}, occ = {}, stats = {}, next_id = 10 }
  Pur.set_enabled(true)
end

--- Projet de plan : ents = liste { name, x, y, dir, type, role, piq } ; réserve ses tuiles dans b.occ.
local function project(id, ents, state, spec)
  local b = FACTION.build
  local p = { id = id, state = state or "fini", ents = ents, spec = spec or {}, parts = {} }
  b.projects[id] = p
  b.order[#b.order + 1] = id
  for _, e in ipairs(ents) do
    if e.piq then
      b.occ[P.tkey(math.floor(e.x - 0.5), math.floor(e.y))] = id
      b.occ[P.tkey(math.floor(e.x + 0.5), math.floor(e.y))] = id
    else
      b.occ[P.tkey(math.floor(e.x), math.floor(e.y))] = id
    end
  end
  return p
end

local function east(x0, x1, y)
  local t = {}
  for x = x0, x1 do t[#t + 1] = { x = x, y = y, dir = 2 } end
  return t
end

local function forbidden(item, p, opts) return Pur.fronts(FACTION, SURF, item, p, opts) end

-- §1 lecture du monde ----------------------------------------------------------------------------
do
  reset()
  ENTS[#ENTS + 1] = belt(10, 5, 2)                                      -- tapis vers l'est : verse sur (11, 5)
  ENTS[#ENTS + 1] = splitter(20, 5, 0)                                  -- vers le nord : verse sur (20, 4) et (21, 4)
  ENTS[#ENTS + 1] = belt(30, 5, 2, "underground-belt", { belt_to_ground_type = "input" })   -- entrée : ne verse rien
  ENTS[#ENTS + 1] = belt(33, 5, 2, "underground-belt", { belt_to_ground_type = "output" })  -- sortie : verse sur (34, 5)
  GHOSTS[#GHOSTS + 1] = belt(40, 5, 4, "entity-ghost", { ghost_type = "transport-belt" })   -- fantôme vers le sud : verse sur (40, 6)
  local f = forbidden("iron-plate", nil)
  check(f(11, 5) == true, "1.1 la tuile devant un tapis du monde est interdite")
  check(f(10, 6) == false and f(10, 4) == false and f(9, 5) == false, "1.2 les tuiles voisines ne le sont pas")
  check(f(20, 4) == true and f(21, 4) == true and f(22, 4) == false, "1.3 un répartiteur verse devant chacune de ses deux tuiles")
  check(f(31, 5) == false, "1.4 une entrée de souterrain ne verse rien devant elle")
  check(f(34, 5) == true, "1.5 une sortie de souterrain verse devant elle")
  check(f(40, 6) == true, "1.6 un fantôme de tapis compte (il sera posé)")
  check(forbidden("iron-plate", nil, { world_only = true })(11, 5) == true, "1.7 world_only lit le monde")
  local c0 = CALLS
  f(11, 5); f(12, 5); f(13, 6)
  check(CALLS == c0, "1.8 le chunk lu est gardé : aucune lecture de plus pour les tuiles voisines (" .. (CALLS - c0) .. ")")
  local rs = Pur.feeding(SURF, 11, 5)
  check(#rs == 1 and rs[1].x == 10 and rs[1].y == 5, "1.9 Pur.feeding rend le tapis qui verse sur la tuile")
  -- un tapis du MÊME objet n'est pas connu du monde (aucun objet lu) : il reste étranger (inconnu)
  check(f(11, 5) == true, "1.10 un tapis du monde non déclaré est étranger même pour un objet qui lui ressemble")
end

-- §2 lecture du plan -----------------------------------------------------------------------------
do
  reset()
  local belts = { { name = "transport-belt", x = 50.5, y = 5.5, dir = 2 }, { name = "transport-belt", x = 51.5, y = 5.5, dir = 2 } }
  local q = project(1, belts, "fini")
  local f = forbidden("iron-plate", nil)
  check(f(52, 5) == true, "2.1 la tuile devant un tapis d'un projet du plan est interdite")
  check(f(51, 5) == true, "2.2 ... et la tuile suivante de la même ligne aussi (le tapis suivant est un tapis du plan : un autre projet ne s'y pose pas)")
  local own = forbidden("iron-plate", q)
  check(own(52, 5) == false, "2.3 les tapis du projet lui-même ne comptent pas")
  q.abandoned = true
  check(forbidden("iron-plate", nil)(52, 5) == false, "2.4 un projet abandonné ne compte pas")
  q.abandoned = nil
  q.state = "refuse"
  check(forbidden("iron-plate", nil)(52, 5) == false, "2.5 un projet refusé ne compte pas")
  q.state = "fini"
  check(forbidden("iron-plate", nil, { world_only = true })(52, 5) == false, "2.6 world_only ne lit pas le plan")
  -- pièce d'un autre type : un coffre dans le plan n'interdit rien
  project(2, { { name = "iron-chest", x = 60.5, y = 5.5, dir = 0 } }, "fini")
  check(forbidden("iron-plate", nil)(61, 5) == false, "2.7 une pièce qui n'est pas un tapis n'interdit rien")
  -- souterrain du plan : l'entrée ne verse pas, la sortie verse
  project(3, { { name = "underground-belt", x = 70.5, y = 5.5, dir = 2, type = "input" }, { name = "underground-belt", x = 74.5, y = 5.5, dir = 2, type = "output" } }, "fini")
  local g = forbidden("iron-plate", nil)
  check(g(71, 5) == false and g(75, 5) == true, "2.8 souterrain du plan : seule la sortie verse")
  -- répartiteur du plan (deux tuiles)
  project(4, { { name = "splitter", x = 80, y = 5.5, dir = 0, piq = true } }, "fini")
  local g2 = forbidden("iron-plate", nil)
  check(g2(79, 4) == true and g2(80, 4) == true, "2.9 répartiteur du plan : devant chacune de ses deux tuiles")
end

-- §3 preuve d'un tracé ---------------------------------------------------------------------------
do
  reset()
  ENTS[#ENTS + 1] = belt(10, 0, 2)
  local ok, why = Pur.check_route(FACTION, SURF, nil, "liaison", east(0, 9, 0), "iron-plate", nil, nil)
  check(ok == false and why:find("pointe_vers_etranger", 1, true), "3.1 la dernière tuile vers un tapis du monde : refusée (" .. tostring(why) .. ")")
  check(select(1, Pur.check_route(FACTION, SURF, nil, "liaison", east(0, 9, 0), "iron-plate", { [P.tkey(10, 0)] = true }, nil)) == true, "3.2 la cible déclarée est admise")
  -- tapis du plan déclaré du même objet à la même tuile : admis ; d'un autre objet : refusé
  reset()
  ENTS[#ENTS + 1] = belt(10, 0, 2)
  local same = project(1, { { name = "transport-belt", x = 10.5, y = 0.5, dir = 2, role = "liaison-tapis" } }, "fini", { liaison = { item = "iron-plate" } })
  check(select(1, Pur.check_route(FACTION, SURF, nil, "liaison", east(0, 9, 0), "iron-plate", nil, nil)) == true, "3.3 tapis du plan déclaré du même objet devant : admis")
  reset()
  ENTS[#ENTS + 1] = belt(10, 0, 2)
  project(1, { { name = "transport-belt", x = 10.5, y = 0.5, dir = 2, role = "liaison-tapis" } }, "fini", { liaison = { item = "copper-plate" } })
  check(select(1, Pur.check_route(FACTION, SURF, nil, "liaison", east(0, 9, 0), "iron-plate", nil, nil)) == false, "3.4 déclaré d'un autre objet : refusé")
  reset()
  ENTS[#ENTS + 1] = belt(10, 0, 2)
  project(1, { { name = "transport-belt", x = 10.5, y = 0.5, dir = 2, role = "liaison-tapis" } }, "fini", { rapatriement = { item = "iron-plate" } })
  check(select(1, Pur.check_route(FACTION, SURF, nil, "liaison", east(0, 9, 0), "iron-plate", nil, nil)) == true, "3.5 la ligne d'un rapatriement déclare aussi son objet")
  -- un tapis étranger qui verse sur le tracé
  reset()
  ENTS[#ENTS + 1] = belt(4, 1, 0)
  local ok2, why2 = Pur.check_route(FACTION, SURF, nil, "bus", east(0, 9, 0), "iron-plate", nil, nil)
  check(ok2 == false and why2:find("etranger_pointe_vers", 1, true) ~= nil and why2:find("4, 1", 1, true) ~= nil, "3.6 un tapis étranger au sud qui verse sur le tracé : refusé et cité (" .. tostring(why2) .. ")")
  -- les tuiles de notre propre projet (encore au plan) ne sont pas lues comme tapis du monde
  local mine = project(7, { { name = "transport-belt", x = 4.5, y = 1.5, dir = 0 } }, "reserve")
  check(select(1, Pur.check_route(FACTION, SURF, mine, "bus", east(0, 9, 0), "iron-plate", nil, nil)) == false, "3.7 le tapis du monde reste vu même si un projet le réserve")
  -- ... mais l'ensemble `own` retire la tuile
  check(select(1, Pur.check_route(FACTION, SURF, mine, "bus", east(0, 9, 0), "iron-plate", nil, { own = { [P.tkey(4, 1)] = true } })) == true, "3.8 opts.own retire la tuile")
  -- zone trop grande : pas de preuve (relais de centrale), le garde de l'A* reste
  local big = {}
  for x = 0, Pur.AREA_MAX + 5 do big[#big + 1] = { x = x, y = 0, dir = 2 } end
  check(select(1, Pur.check_route(FACTION, SURF, nil, "foreuses", big, "iron-plate", nil, nil)) == true, "3.9 plus de " .. Pur.AREA_MAX .. " tuiles : pas de preuve, tracé admis")
  check(select(1, Pur.check_route(FACTION, SURF, nil, "foreuses", {}, "iron-plate", nil, nil)) == true, "3.10 tracé vide : admis")
end

-- §4 queues de gabarit ---------------------------------------------------------------------------
do
  reset()
  ENTS[#ENTS + 1] = belt(11, 0, 2)
  project(1, { { name = "transport-belt", x = 21.5, y = 0.5, dir = 2 } }, "fini")
  local ok_ = Pur.front_ok(FACTION, SURF)
  check(ok_(11, 0) == false and ok_(21, 0) == false and ok_(12, 0) == true, "4.1 une tuile occupée par un tapis (monde ou plan) refuse la queue")
  check(#LOG == 2 and LOG[1]:find("gabarit", 1, true) ~= nil, "4.2 chaque tuile refusée est journalisée une fois (" .. #LOG .. ")")
  ok_(11, 0); ok_(11, 0)
  check(#LOG == 2, "4.3 ... et une seule fois par lecture")
  check(Pur.set_enabled(false) == nil and Pur.front_ok(FACTION, SURF) == nil, "4.4 réglage éteint : pas de contrôle (nil)")
  Pur.set_enabled(true)
end

-- §5 compteurs et journal ------------------------------------------------------------------------
do
  reset()
  game.tick = 40000 -- une tranche de bilan commence (Pur.BILAN_TICKS)
  ENTS[#ENTS + 1] = belt(4, 1, 0)
  local p = { id = 99, ents = {}, spec = {} }
  Pur.check_route(FACTION, SURF, p, "liaison", east(0, 9, 0), "iron-plate", nil, nil)
  Pur.check_route(FACTION, SURF, p, "liaison", east(0, 9, 3), "iron-plate", nil, nil)
  local st = FACTION.build.stats.purete
  check(st and st.checks == 2 and st.refused == 1 and st.why.etranger_pointe_vers == 1, "5.1 compteurs : 2 contrôles, 1 refus, cause comptée")
  local line
  for _, l in ipairs(LOG) do if l:find("tracé refusé", 1, true) then line = l end end
  check(line and line:find("^%[FO%-PURETE%] player liaison projet 99 : tracé refusé %(etranger_pointe_vers%) objet iron%-plate contre %? en %(4, 1%)"), "5.2 ligne du journal : " .. tostring(line))
  check(#LOG >= 2, "5.3 un bilan de tranche est écrit")
  -- plafond de lignes
  for i = 1, Pur.LOGS + 20 do Pur.check_route(FACTION, SURF, p, "liaison", east(0, 9, 0), "iron-plate", nil, nil) end
  local n = 0
  for _, l in ipairs(LOG) do if l:find("tracé refusé", 1, true) then n = n + 1 end end
  check(n <= Pur.LOGS, "5.4 au plus " .. Pur.LOGS .. " lignes par équipe (" .. n .. ")")
end

-- §6 réglage éteint ------------------------------------------------------------------------------
do
  reset()
  ENTS[#ENTS + 1] = belt(10, 0, 2)
  Pur.set_enabled(false)
  check(select(1, Pur.check_route(FACTION, SURF, nil, "liaison", east(0, 9, 0), "iron-plate", nil, nil)) == true, "6.1 éteint : la preuve admet")
  check(forbidden("iron-plate", nil)(11, 0) == false, "6.2 éteint : aucune tuile interdite")
  Pur.set_enabled(true)
end

-- §7 COÛT en instructions ------------------------------------------------------------------------
local function instructions(fn)
  local n = 0
  debug.sethook(function() n = n + 1 end, "", 1000)
  fn()
  debug.sethook()
  return n * 1000
end
do
  reset()
  -- monde dense : 2 000 tapis dans la zone, la plupart sans rapport avec le tracé
  for i = 0, 1999 do ENTS[#ENTS + 1] = belt(i % 100, 20 + math.floor(i / 100), 2) end
  -- plan : 200 projets de 120 pièces, loin du tracé, et un projet qui touche le tracé
  for k = 1, 200 do
    local ents = {}
    for e = 1, 120 do ents[e] = { name = (e % 3 == 0) and "transport-belt" or "inserter", x = 800 + k * 3 + 0.5, y = 800 + e + 0.5, dir = 2 } end
    project(100 + k, ents, "fini")
  end
  project(5, { { name = "transport-belt", x = 60.5, y = 0.5, dir = 2 } }, "fini")
  local route = {}
  for i = 0, 129 do route[#route + 1] = { x = i, y = 0, dir = 2 } end
  local ok1
  local m = instructions(function() ok1 = Pur.check_route(FACTION, SURF, nil, "liaison", route, "iron-plate", nil, nil) end)
  check(ok1 == false, "7.1 le tracé de 130 tuiles croise un tapis du plan en (60, 0) : refusé")
  check(m <= 150000, "7.2 première preuve (monde de 2 000 tapis, plan de 24 000 pièces) : " .. m .. " instructions <= 150 000")
  local m2 = instructions(function() Pur.check_route(FACTION, SURF, nil, "liaison", route, "iron-plate", nil, nil) end)
  check(m2 <= 100000, "7.3 preuve suivante : " .. m2 .. " instructions <= 100 000")
  local f = forbidden("iron-plate", nil)
  local m0 = instructions(function() for x = 0, 99 do f(x, 0) end end)  -- lit les chunks (4 chunks, 2 000 tapis du monde à ranger)
  check(m0 <= 600000, "7.4a première lecture des chunks (2 000 tapis du monde dans la zone) : " .. m0 .. " instructions <= 600 000, une fois par chunk et par " .. Pur.TTL .. " ticks")
  local m3 = instructions(function() for x = 0, 99 do for y = 0, 9 do f(x, y) end end end)
  check(m3 / 1000 <= 120, "7.4 fronts() sur 1 000 tuiles, chunks lus : " .. m3 .. " instructions, " .. string.format("%.0f", m3 / 1000) .. " par tuile (<= 120)")
  local f2 = forbidden("iron-plate", nil, { world_only = true })
  local m4 = instructions(function() for x = 0, 99 do for y = 0, 9 do f2(x, y) end end end)
  check(m4 / 1000 <= 60, "7.5 world_only sur 1 000 tuiles : " .. string.format("%.0f", m4 / 1000) .. " instructions par tuile (<= 60)")
  local ok_ = Pur.front_ok(FACTION, SURF)
  for i = 1, 200 do ok_(i, 3) end -- (les chunks sont lus ici : la doublure du moteur parcourt ses 2 000 tapis à chaque lecture, ce coût n'est pas celui du jeu)
  local m5 = instructions(function() for i = 1, 200 do ok_(i, 3) end end)
  if os.getenv("FO_VERBOSE") then
    print(string.format("  [coût] preuve 1re %d, suivante %d ; chunks 1re lecture %d ; fronts %d/tuile ; world_only %d/tuile ; front_ok %d/tuile", m, m2, m0, m3 / 1000, m4 / 1000, m5 / 200))
  end
  check(m5 / 200 <= 400, "7.6 front_ok sur 200 tuiles : " .. string.format("%.0f", m5 / 200) .. " instructions par tuile (<= 400)")
end

-- §8 interface de banc ---------------------------------------------------------------------------
do
  reset()
  ENTS[#ENTS + 1] = belt(10, 0, 2)
  local R = REMOTE["fo-purete"]
  check(R ~= nil and type(R.check) == "function", "8.1 l'interface fo-purete existe")
  local r = R.check("player", east(0, 9, 0), "iron-plate", {})
  check(r and r.ok == false and r.refused == true and tostring(r.why):find("pointe_vers_etranger", 1, true) ~= nil, "8.2 check rend le verdict")
  check(R.forbidden("player", "iron-plate", 11, 0) == true and R.forbidden("player", "iron-plate", 0, 0) == false, "8.3 forbidden")
  local rep = R.report("player")
  check(rep and rep.refused == 1, "8.4 report")
  check(R.set_enabled(false) == false and R.set_enabled(true) == true, "8.5 set_enabled")
  check(R.check("inconnue", east(0, 9, 0), "iron-plate", {}) == nil, "8.6 équipe inconnue : nil")
end

-- §9 branchements (lecture du source) ------------------------------------------------------------
do
  local function read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
  end
  local L, R, Q, B, PL = read("script/team/liaison.lua"), read("script/team/rapatriement.lua"), read("script/team/piquage.lua"), read("script/team/build.lua"), read("shared/team/plan.lua")
  check(L:find('require("script.team.purete")', 1, true) and L:find("Pur.fronts(f, surface, lc.item, p, { world_only = true })", 1, true), "9.1 liaison : tuiles du monde interdites à l'A*")
  check(L:find("Pur.check_route(f, surface, p, lc.bus and", 1, true), "9.2 liaison (et bus) : preuve du tracé avant les poteaux")
  check(R:find("J.wf = Pur.fronts(f, surface, lc.item, p, { world_only = true })", 1, true) and R:find("and not J.wf(x, y)", 1, true), "9.3 rapatriement : tuiles du monde interdites")
  local _, n_found = R:gsub("ok, w2 = purity%(J, e,", "")
  check(n_found == 2, "9.4 rapatriement : preuve aux deux endroits où un tracé est trouvé (" .. n_found .. ")")
  check(Q:find('Pur.check_route(f, surface, p, "piquage"', 1, true) and Q:find("Pur.feeding(surface, g.side_tile.x, g.side_tile.y)", 1, true), "9.5 piquage : preuve de la branche et seconde entrée relue à la pose")
  check(B:find("local pure_front = Build.Pur.fronts(f, surface, item, p)", 1, true) and B:find("if pure_front(x, y) then return nil end", 1, true), "9.6 lignes de foreuses : tuile devant un tapis interdite (garde qui manquait)")
  check(B:find('Build.Pur.check_route(f, surface, p, "foreuses"', 1, true), "9.7 lignes de foreuses : preuve du tracé")
  check(B:find("fopts.front_ok = Build.Pur.front_ok(f, surface)", 1, true) and PL:find("opts.front_ok(ox + t0.x, oy + t0.y)", 1, true), "9.8 gabarits : queues de tapis contre le monde")
end

print(string.format("[PURETE-SCRIPT] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
