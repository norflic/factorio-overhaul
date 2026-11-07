--[[
  Lot DESIGN-ATTAQUES (5/11) : COÛT des grandes attaques, mesuré au MOTEUR SIMULÉ (petit moteur de ce fichier : il compte les appels du script
  au jeu, il ne prouve rien du moteur réel). Lua 5.2, depuis la racine du mod :   lua5.2 tests/attaques2_cout_test.lua
  Le VRAI script (script/robots/attaques2.lua et attaques2_effets.lua) joue une salve de chaque géant sur une base ennemie dense : un îlot
  de 3 × 3 tous les 4 tuiles, des poteaux reliés en cuivre tous les 8 tuiles, des biters, des arbres, et une base AMIE à protéger.
  Mesuré par salve : recherches d'entités, candidats, coups (dégâts et morts), créations (explosions, rayons, falaises, brasiers), tuiles
  posées, appels de rendu, opérations au pire tick (compte du script), temps Lua au pire tick ; et les règles : aucune entité amie touchée,
  aucune falaise ni lave sous un bâtiment ami.
]]

package.path = "./?.lua;" .. package.path

-- ------------------------------------------------------------------ moteur simulé
local C = { find = 0, found = 0, damage = 0, die = 0, create = 0, smoke = 0, particle = 0, tiles = 0, set_tiles = 0, draw = 0, set = 0,
  destroy = 0, get_tile = 0, cliff = 0 }
local W = { ents = {}, tick = 0, tiles = {}, cliffs = {}, crees = {} }
local next_un, next_rid = 1, 1

local forces = {}
local PAIX = false -- paix déclarée (contrôle « paix en pleine attaque »)
local function new_force(name, index)
  local f = { name = name, valid = true, index = index }
  forces[index] = f -- le jeu indexe aussi les forces par numéro (player 1, enemy 2, neutral 3)
  f.is_enemy = function(o) return not PAIX and ((o.name == "enemy" and name == "player") or (o.name == "player" and name == "enemy")) end
  forces[name] = f
  return f
end
new_force("player", 1); new_force("enemy", 2); new_force("neutral", 3)

local DEAD = setmetatable({}, { __index = function(_, k) if k == "valid" then return false end return nil end })

local function new_entity(t)
  local e = { name = t.name, type = t.type or t.name, position = { x = t.x, y = t.y }, force = forces[t.force or "neutral"],
    force_index = forces[t.force or "neutral"].index, valid = true,
    health = t.health or 1000, destructible = true, active = true, unit_number = next_un, half = t.half or 0.5 }
  next_un = next_un + 1
  e.bounding_box = { left_top = { x = t.x - e.half, y = t.y - e.half }, right_bottom = { x = t.x + e.half, y = t.y + e.half } }
  e.neighbours = { copper = {}, red = {}, green = {} }
  e.die = function()
    C.die = C.die + 1
    e.valid = false
    return true
  end
  e.damage = function(amount)
    C.damage = C.damage + 1
    local d = math.min(e.health, amount)
    e.health = e.health - amount
    if e.health <= 0 then e.valid = false end
    return d
  end
  W.ents[#W.ents + 1] = e
  return e
end

local function in_query(e, q)
  local p = e.position
  if q.area then
    local a = q.area
    local x0, y0 = a[1][1] or a.left_top.x, a[1][2] or a.left_top.y
    local x1, y1 = a[2][1] or a.right_bottom.x, a[2][2] or a.right_bottom.y
    if p.x < x0 or p.x > x1 or p.y < y0 or p.y > y1 then return false end
  elseif q.position then
    local c = q.position
    local cx, cy = c.x or c[1], c.y or c[2]
    if (p.x - cx) ^ 2 + (p.y - cy) ^ 2 > q.radius ^ 2 then return false end
  end
  if q.type then
    local hit = false
    for _, ty in ipairs(type(q.type) == "table" and q.type or { q.type }) do if e.type == ty then hit = true end end
    if q.invert then hit = not hit end
    if not hit then return false end
  end
  if q.force then
    local hit = false
    for _, fn in ipairs(type(q.force) == "table" and q.force or { q.force }) do if e.force.name == fn then hit = true end end
    if not hit then return false end
  end
  return true
end

local surface = { index = 1, valid = true, name = "nauvis" }
surface.find_entities_filtered = function(q)
  C.find = C.find + 1
  local out = {}
  for _, e in ipairs(W.ents) do if e.valid and in_query(e, q) then out[#out + 1] = e end end
  C.found = C.found + #out
  return out
end
surface.create_entity = function(t)
  C.create = C.create + 1
  if t.name == "cliff" then
    C.cliff = C.cliff + 1
    W.cliffs[#W.cliffs + 1] = { x = t.position[1], y = t.position[2], h = t.cliff_orientation:find("east") or t.cliff_orientation:find("west") }
  end
  local e = { valid = true, name = t.name, position = { x = t.position[1] or t.position.x, y = t.position[2] or t.position.y } }
  e.destroy = function() e.valid = false; C.detruits = (C.detruits or 0) + 1 end
  W.crees[#W.crees + 1] = e
  return e
end
surface.create_trivial_smoke = function() C.smoke = C.smoke + 1 end
surface.create_particle = function() C.particle = C.particle + 1 end
surface.set_tiles = function(t) C.set_tiles = C.set_tiles + 1; C.tiles = C.tiles + #t
  for _, q in ipairs(t) do W.tiles[(q.position[1] or q.position.x) .. ":" .. (q.position[2] or q.position.y)] = q.name end -- {x, y} ou {x =, y =}
end
local TUILE = {} -- une table par nom de tuile, partagée : le moteur simulé n'alloue rien par lecture (mesure de la mémoire, plus bas)
local function non() return false end
surface.get_tile = function(x, y)
  C.get_tile = C.get_tile + 1
  local n = W.tiles[x .. ":" .. y] or "grass-1"
  local t = TUILE[n]
  if not t then t = { valid = true, name = n, hidden_tile = nil, collides_with = non }; TUILE[n] = t end
  return t
end
surface.play_sound = function() end
surface.find_nearest_enemy_entity_with_owner = function() return nil end
surface.darkness = 0

local function rid() local r = next_rid; next_rid = next_rid + 1; C.draw = C.draw + 1; return r end
_G.rendering = setmetatable({ is_valid = function() return true end, destroy = function() C.destroy = C.destroy + 1 end }, {
  __index = function(_, k)
    if k:sub(1, 5) == "draw_" then return rid end
    if k:sub(1, 4) == "set_" then return function() C.set = C.set + 1 end end
    return function() end
  end })
_G.game = { forces = forces, surfaces = { [1] = surface }, is_valid_sprite_path = function(n) return n:sub(-2) == "-1" or n:sub(-2) == "-2" end }
setmetatable(game, { __index = function(_, k) if k == "tick" then return W.tick end end })
_G.defines = { events = { on_tick = "on_tick", on_built_entity = 1, on_robot_built_entity = 2, script_raised_built = 3, script_raised_revive = 4 } }
_G.log = function() end
_G.remote = { add_interface = function() end }
_G.commands = { add_command = function() end }

local H = { tick = {}, nth = {} }
package.loaded["script.core.events"] = {
  on = function(id, fn) if id == "on_tick" then H.tick[#H.tick + 1] = fn end end,
  on_nth_tick = function(n, fn) H.nth[#H.nth + 1] = { n = n, fn = fn } end,
}
local NS = {}
package.loaded["script.core.storage"] = {
  declare = function(name, fn) NS[name] = fn() end,
  ns = function(name) return NS[name] end,
}
package.loaded["script.robots.armee"] = { age = function() return 15 end, giants = function() return 0 end }

local Xp = require("shared.robots.experimentaux")
local A = require("shared.robots.attaques2")
local M = require("script.robots.attaques2")

-- ------------------------------------------------------------------ la base ennemie, la base amie
local CX, CY = 0, 0
local function base(ox)
  W.ents = {}
  W.cliffs = {}
  -- îlots de 3 × 3 tous les 4 tuiles dans un carré de 170 tuiles (moins un couloir de poteaux)
  for x = -84, 84, 4 do
    for y = -84, 84, 4 do
      if (x % 8 ~= 0) or (y % 8 ~= 0) then
        new_entity({ name = "assembling-machine-2", type = "assembling-machine", x = x + 0.5, y = y + 0.5, force = "enemy", half = 1.4 })
      end
    end
  end
  -- poteaux tous les 8 tuiles, reliés à 4 voisins (cuivre)
  local P = {}
  for i = -10, 10 do
    P[i] = {}
    for k = -10, 10 do
      P[i][k] = new_entity({ name = "medium-electric-pole", type = "electric-pole", x = i * 8 + 0.5, y = k * 8 + 0.5, force = "enemy", half = 0.15 })
    end
  end
  for i = -10, 10 do
    for k = -10, 10 do
      local e = P[i][k]
      for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local q = P[i + d[1]] and P[i + d[1]][k + d[2]]
        if q then e.neighbours.copper[#e.neighbours.copper + 1] = q end
      end
    end
  end
  for k = 1, 30 do new_entity({ name = "behemoth-biter", type = "unit", x = -40 + k * 2.7, y = 12.3, force = "enemy" }) end
  for k = 1, 60 do new_entity({ name = "tree-01", type = "tree", x = -90 + k * 3, y = -91.2, force = "neutral" }) end
  -- base AMIE dans la zone : une rangée de labos au sud du centre (un géant ne la touche jamais)
  local amis = {}
  for x = -20, 20, 4 do amis[#amis + 1] = new_entity({ name = "lab", type = "lab", x = x + 0.5, y = 30.5, force = "player", half = 1.4 }) end
  for _, e in ipairs(W.ents) do
    e.position.x = e.position.x + ox
    e.bounding_box.left_top.x = e.bounding_box.left_top.x + ox
    e.bounding_box.right_bottom.x = e.bounding_box.right_bottom.x + ox
  end
  return amis
end

local function geant(id)
  local r = Xp.robot(id)
  local g = { name = r.name, valid = true, unit_number = 999000 + #id, force = forces.player, surface = surface, position = { x = -60, y = -60 },
    teleports = 0 }
  g.position.x = g.position.x + CX
  g.teleport = function(p) g.position = { x = p[1] or p.x, y = p[2] or p.y }; g.teleports = g.teleports + 1; return true end
  return g
end

local function run(n)
  for _ = 1, n do
    W.tick = W.tick + 1
    for _, fn in ipairs(H.tick) do fn({ tick = W.tick }) end
  end
end

local ok, ko = 0, 0
local function check(cond, nom, det)
  if cond then ok = ok + 1 else ko = ko + 1 end
  print(string.format("%s %s%s", cond and "OK   " or "ECHEC", nom, det and (" : " .. det) or ""))
end

-- ------------------------------------------------------------------ MESURE d'une grande attaque, tick par tick (demande du lead, 7/11, 20 h 20 :
-- le tick de script à 10,9 ms du Tournesol au tick +493 du banc att2-perf v7, « en instructions ET en mémoire allouée », F398) :
--   FO_ATT2_MESURE=tournesol [FO_ATT2_RT=493] lua5.2 tests/attaques2_cout_test.lua
-- Instructions du script du MOD comptées par paquets de 100 (debug.sethook), à part celles du moteur simulé (ce fichier) ; par section :
-- plan (A.u_zenith, A.tuiles_zenith, A.point_zenith, A.tuiles_lave), registre (Ech.trace_marquer), voisinage (A.voisinage), effets (rendus
-- de attaques2_effets), autre (le reste du script). Mémoire allouée par tick : collectgarbage("count"), ramasse-miettes ARRÊTÉ (rien n'est
-- libéré pendant la mesure ; le moteur simulé alloue aussi : clés de tuiles, entités créées). Déterministe ; aucun temps mesuré.
local MES = os.getenv("FO_ATT2_MESURE")
if MES then
  local ICI = debug.getinfo(1, "S").source
  local PAQ = 100
  local SEC = "autre"
  local INS = { banc = 0, plan = 0, registre = 0, voisinage = 0, effets = 0, autre = 0 }
  local SECTIONS = { "plan", "registre", "voisinage", "effets", "autre" }
  local function crochet()
    if debug.getinfo(2, "S").source == ICI then INS.banc = INS.banc + PAQ else INS[SEC] = INS[SEC] + PAQ end
  end
  local KO = { plan = 0, registre = 0, voisinage = 0, effets = 0 } -- mémoire allouée par section (Ko), sections jamais imbriquées entre elles
  local function sortir(s0, k0, nom, ...) SEC = s0; KO[nom] = KO[nom] + collectgarbage("count") - k0; return ... end
  local function envelopper(t, k, nom)
    local f = t[k]
    if not f then return end
    t[k] = function(...) local s0 = SEC; SEC = nom; return sortir(s0, collectgarbage("count"), nom, f(...)) end
  end
  local V = require("script.robots.attaques2_effets")
  for _, k in ipairs({ "u_zenith", "tuiles_zenith", "point_zenith", "tuiles_lave" }) do envelopper(A, k, "plan") end
  envelopper(A.Ech, "trace_marquer", "registre")
  envelopper(A, "voisinage", "voisinage")
  local noms = {}
  for k, f in pairs(V) do if type(f) == "function" then noms[#noms + 1] = k end end
  table.sort(noms)
  for _, k in ipairs(noms) do envelopper(V, k, "effets") end
  local RT = tonumber(os.getenv("FO_ATT2_RT") or "493")
  base(0)
  local e = geant(MES)
  collectgarbage("collect")
  collectgarbage("stop")
  assert(M.lancer(e, 0.3, 0.2, true), "lancement")
  local job = NS.attaques2.jobs[1]
  local L = {}
  debug.sethook(crochet, "", PAQ)
  for _ = 1, 6000 do
    if #NS.attaques2.jobs == 0 then break end
    local i0 = {}
    for k, v in pairs(INS) do i0[k] = v end
    local a0 = {}
    for k, v in pairs(KO) do a0[k] = v end
    local k0, c0, t0 = collectgarbage("count"), C.damage + C.die, C.tiles
    run(1)
    local ko = collectgarbage("count") - k0
    local r = { rt = W.tick - job.t0, ko = ko, coups = C.damage + C.die - c0, tuiles = C.tiles - t0, banc = INS.banc - i0.banc, mod = 0, ka = {} }
    for _, s in ipairs(SECTIONS) do r[s] = INS[s] - i0[s]; r.mod = r.mod + r[s] end
    for k, v in pairs(KO) do r.ka[k] = v - a0[k] end
    L[#L + 1] = r
  end
  debug.sethook()
  collectgarbage("restart")
  local function ligne(r)
    return string.format("%+6d %8d %7d %7d %6d %6d %7d | %7d %8.1f %5d %5d", r.rt, r.mod, r.plan, r.registre, r.voisinage, r.effets, r.autre,
      r.banc, r.ko, r.coups, r.tuiles)
  end
  local tete = string.format("%6s %8s %7s %7s %6s %6s %7s | %7s %8s %5s %5s", "rt", "mod", "plan", "registre", "vois", "effets", "autre",
    "banc", "Ko", "coups", "tuiles")
  local function mediane(t) table.sort(t); return t[math.max(1, math.floor((#t + 1) / 2))] or 0 end
  local mi, mk, tot_i, tot_k, n = {}, {}, 0, 0, 0
  for _, r in ipairs(L) do
    if r.rt >= 0 then mi[#mi + 1] = r.mod; mk[#mk + 1] = r.ko; tot_i = tot_i + r.mod; tot_k = tot_k + r.ko; n = n + 1 end
  end
  print(string.format("[ATT2-MESURE] %s : %d ticks d'attaque (rt >= 0) ; instructions du mod %d (médiane %d par tick) ; mémoire allouée %.0f Ko "
    .. "(médiane %.1f Ko par tick)", MES, n, tot_i, mediane(mi), tot_k, mediane(mk)))
  print("[ATT2-MESURE] autour de rt " .. RT .. " :")
  print(tete)
  for _, r in ipairs(L) do if math.abs(r.rt - RT) <= 6 then print(ligne(r)) end end
  -- où va la mémoire pendant l'attaque (rt >= 0), par section ; « reste » : le reste du script ET le moteur simulé
  local S = { plan = 0, registre = 0, voisinage = 0, effets = 0 }
  for _, r in ipairs(L) do if r.rt >= 0 then for k, v in pairs(r.ka) do S[k] = S[k] + v end end end
  local somme = S.plan + S.registre + S.voisinage + S.effets
  print(string.format("[ATT2-MESURE] mémoire allouée pendant l'attaque, par section (Ko) : plan %.0f, registre %.0f, voisinage %.0f, effets %.0f, "
    .. "reste %.0f (script hors sections et moteur simulé)", S.plan, S.registre, S.voisinage, S.effets, tot_k - somme))
  for _, cle in ipairs({ "mod", "ko" }) do
    local T = {}
    for _, r in ipairs(L) do T[#T + 1] = r end
    table.sort(T, function(a, b) if a[cle] ~= b[cle] then return a[cle] > b[cle] end return a.rt < b.rt end)
    print("[ATT2-MESURE] 8 pires ticks en " .. (cle == "mod" and "instructions du mod" or "mémoire allouée") .. " :")
    print(tete)
    for i = 1, math.min(8, #T) do print(ligne(T[i])) end
  end
  os.exit(0)
end

print(string.format("%-10s %4s %6s %6s %6s %6s %6s %6s %7s %7s %6s %8s %6s %6s %6s %6s", "geant", "rech", "cand", "coups", "morts", "creat", "fal",
  "tuiles", "rendus", "sets", "ops", "pire ms", "c/tick", "t/tick", "jetons", "duree"))
local LIGNES = {}
for n, id in ipairs(A.ORDRE) do
  CX = (n - 1) * 1000
  local amis = base(CX)
  local nb_amis = #amis
  for k in pairs(C) do C[k] = 0 end -- remise à zéro des compteurs (ordre sans effet)
  local e = geant(id)
  local okl = M.lancer(e, CX + 0.3, CY + 0.2, true)
  local pire, pire_t = 0, 0
  local avant = C.find
  local fin = A.duree(id, { rl = A.zone(Xp.robot(id).age) / 3, R = A.zone(Xp.robot(id).age) }) + 5
  -- jusqu'à la fin de l'attaque (les files du budget peuvent la prolonger), 3 000 ticks de plus au plus
  local cmax, tmax, duree = 0, 0, 0
  for k = 1, fin + 3000 do
    if k > fin and #NS.attaques2.jobs == 0 then break end
    local c0, t0c = C.damage + C.die, C.tiles
    local t0 = os.clock()
    run(1)
    local dt = os.clock() - t0
    if dt > pire then pire, pire_t = dt, W.tick end
    cmax = math.max(cmax, C.damage + C.die - c0)
    tmax = math.max(tmax, C.tiles - t0c)
    if #NS.attaques2.jobs > 0 then duree = k end
  end
  local st = NS.attaques2.stats[id]
  local intacts = 0
  for _, a in ipairs(amis) do if a.valid and a.health == 1000 then intacts = intacts + 1 end end
  local lave_sous_ami = 0
  for _, a in ipairs(amis) do
    local x, y = math.floor(a.position.x), math.floor(a.position.y)
    local tn = W.tiles[x .. ":" .. y]
    if tn and tn ~= "grass-1" and tn ~= A.PREFIX .. "verre" then lave_sous_ami = lave_sous_ami + 1 end
  end
  for _, f in ipairs(W.cliffs) do
    local hx, hy = f.h and 2 or 1, f.h and 1.5 or 2
    for _, a in ipairs(amis) do
      local bb = a.bounding_box
      if bb.left_top.x < f.x + hx and bb.right_bottom.x > f.x - hx and bb.left_top.y < f.y + hy and bb.right_bottom.y > f.y - hy then
        lave_sous_ami = lave_sous_ami + 1
      end
    end
  end
  LIGNES[#LIGNES + 1] = string.format("%-10s %4d %6d %6d %6d %6d %6d %6d %7d %7d %6d %8.2f %6d %6d %6d %6d", id, C.find - avant, st.candidats,
    C.damage, C.die, C.create, C.cliff, C.tiles, C.draw, C.set, st.max_ops, pire * 1000, cmax, tmax, st.max_cout or 0, duree)
  print(LIGNES[#LIGNES])
  check(okl, id .. " : lancée")
  check(st.recherches == 1 and C.find - avant >= st.bandes and C.find - avant <= 3 * st.bandes,
    id .. " : UNE recherche par salve, en bandes de " .. A.BANDE_AIRE .. " tuiles² (3 recherches par bande au plus)",
    string.format("%d bande(s), %d appel(s)", st.bandes or 0, C.find - avant))
  -- le budget du tick : au plus BUDGET / coup coups par tick (le Cairn paie le poteau, plus cher), au plus A.TUILES tuiles par tick,
  -- et les jetons comptés par le script ne dépassent pas le budget (marge : les arbres de la Trombe, payés après coup)
  check(cmax <= math.floor(A.BUDGET / A.POIDS.coup), id .. " : coups par tick dans le budget", string.format("%d au plus (%d permis)", cmax,
    math.floor(A.BUDGET / A.POIDS.coup)))
  check(tmax <= A.TUILES, id .. " : tuiles par tick bornées", string.format("%d au plus", tmax))
  check((st.max_cout or 0) <= A.BUDGET + 4 * A.POIDS.abattre, id .. " : jetons par tick dans le budget", tostring(st.max_cout))
  check(duree <= fin + 600, id .. " : la file du budget ne prolonge pas l'attaque de plus de 10 s", string.format("%d ticks (prévu %d)", duree, fin))
  check(st.tues > 0, id .. " : des cibles tuées", string.format("tues %d, cibles %d", st.tues, st.cibles))
  check(intacts == nb_amis, id .. " : la base amie dans la zone est intacte", string.format("%d / %d", intacts, nb_amis))
  check(lave_sous_ami == 0, id .. " : ni lave ni falaise sous un bâtiment ami")
  check(#NS.attaques2.jobs == 0, id .. " : l'attaque finit (aucun travail en attente)")
  if id == "cairn" then check(st.poteaux >= 40, "cairn : la surtension court sur le réseau", tostring(st.poteaux) .. " poteaux") end
  if id == "stylet" then
    check(st.feux >= 40 and st.feux <= 11 * 12, "stylet : le balayage laisse du feu et du sol brûlé (12 au plus par pas)", tostring(st.feux))
  end
  if id == "trombe" then
    check(st.rochers > 0, "trombe : des rochers sur le couloir", tostring(st.rochers))
    check(e.teleports > 600 and math.abs(e.position.x - CX - 0.3) < 1e-6 and math.abs(e.position.y - CY - 0.2) < 1e-6,
      "trombe : elle parcourt le huit elle-même et finit au centre", string.format("%d deplacements", e.teleports))
  end
  if id == "ixion" then check(st.tuiles > 900 and #NS.attaques2.laves == 1, "ixion : le lac de lave est posé et enregistré pour refroidir", tostring(st.tuiles)) end
  if id == "tournesol" then check(st.tuiles > 1500 and #NS.attaques2.verres == 1, "tournesol : la spirale de verre chaud est posée et enregistrée", tostring(st.tuiles)) end
  NS.attaques2.pret = {}
end
-- séquelles : le lac et le verre refroidissent
run(math.max(A.ATTAQUES.ixion.tenue + A.ATTAQUES.ixion.refroidit, A.ATTAQUES.tournesol.tenue + A.ATTAQUES.tournesol.refroidit) + 60)
local lave = 0
for _, v in pairs(W.tiles) do if v == A.PREFIX .. "lave" then lave = lave + 1 end end -- compte seul (l'ordre ne sert pas)
check(#NS.attaques2.laves == 0 and lave == 0, "ixion : le lac a refroidi en cratère (plus aucune tuile de lave)", tostring(lave))
local chaud, froid = 0, 0
for _, v in pairs(W.tiles) do -- compte seul (l'ordre ne sert pas)
  if v == A.PREFIX .. "verre-chaud" then chaud = chaud + 1 elseif v == A.PREFIX .. "verre" then froid = froid + 1 end
end
check(#NS.attaques2.verres == 0 and chaud == 0 and froid > 1500, "tournesol : le verre chaud a refroidi en verre doré", chaud .. " chaudes, " .. froid .. " froides")
local cratere = 0
for _, v in pairs(W.tiles) do if v == "nuclear-ground" then cratere = cratere + 1 end end -- compte seul
check(cratere > 900, "ixion : le cratère est là après le refroidissement", tostring(cratere))
-- séquelles d'1 h (QCM-7/11) : une heure après, le sol d'origine est revenu partout, les rochers de la Trombe se sont effacés
local function rochers_vivants()
  local n = 0
  for _, e in ipairs(W.crees) do if e.valid and (e.name == "rock-big" or e.name == "sand-rock-big" or e.name == "rock-huge") then n = n + 1 end end
  return n
end
local rv0 = rochers_vivants()
run(A.TRACE + 600)
local reste, autres = 0, 0
for _, v in pairs(W.tiles) do -- compte seul (l'ordre ne sert pas)
  if v ~= "grass-1" then reste = reste + 1 end
end
check(rv0 > 0 and rochers_vivants() == 0, "trombe : les rochers s'effacent au bout d'1 h", rv0 .. " avant, " .. rochers_vivants() .. " après")
check(reste == 0, "séquelles : au bout d'1 h, cratère et verre ont rendu le sol d'origine (herbe)", tostring(reste) .. " tuile(s) encore marquées")
local Rr = NS.attaques2.traces[1] and NS.attaques2.traces[1].R
check(Rr and A.Ech.trace_compte(Rr) == 0, "séquelles : le registre est vide", Rr and tostring(A.Ech.trace_compte(Rr)) or "aucun registre")
-- paix en pleine attaque (décision du lead, 7/11) : les ennemis sont relus à chaque tick, plus aucun coup dès le tick suivant
CX = 9000
base(CX)
for k in pairs(C) do C[k] = 0 end -- remise à zéro des compteurs (ordre sans effet)
NS.attaques2.pret = {}
local e9 = geant("ixion")
check(M.lancer(e9, CX + 0.3, CY + 0.2, true) == true, "paix : Ixion lancée")
run(A.ATTAQUES.ixion.charge + 70)
local avant_paix = C.damage + C.die
PAIX = true
run(900)
check(avant_paix > 0 and C.damage + C.die == avant_paix, "paix déclarée en pleine attaque : plus aucun coup dès le tick suivant",
  string.format("%d coups avant, %d après", avant_paix, C.damage + C.die - avant_paix))
PAIX = false
print(string.format("[ATT2-COUT] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
