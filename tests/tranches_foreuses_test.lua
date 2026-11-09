--[[
  Lot TRANCHES-FOREUSES : le tracé du tapis des foreuses (Build.plan_drills) PAR TRANCHES. Cause : l'essai pondéré (budget = la boîte entière, 0.6.72) et les
  deux essais exacts qui le précèdent coûtaient jusqu'à 14 millions d'instructions (90 ms et plus) dans UN appel (mesure de l'agent COURANT-LIBRE).
    §1 shared/team/traversee.lua, ctx.phase_slice / ctx.phase_state : le tracé par passes rend EXACTEMENT celui d'un seul appel (tuiles, info, reste du budget),
       sur forêt, gisement, souterrains, arrivée murée ; chaque passe ne dépasse jamais PASS_MAX instructions (debug.sethook, déterministe) ; l'état entre
       deux passes ne contient que des nombres, des chaînes et des tables (copié, comme une sauvegarde) ;
    §2 script/team/foreuses_tranches.lua (Td.trace), sur le vrai script/team/traversee.lua et un moteur minimal : les trois essais (exact, marge, pondéré)
       rendent le résultat de l'ancien enchaînement d'un seul appel ; chaque pensée ≤ PASS_MAX ; masques lus UNE fois par essai ; un chargement de sauvegarde
       (mémoire locale perdue) ne change pas le résultat ; une signature changée repart de zéro ; un essai fini est rejoué sans recherche ;
    §3 branchement lu comme texte (build.lua, fonderie_bloc.lua) : l'attente « foreuses », la propagation, 198 locales au plus 199 ;
    §4 mutants : sans tranche, sans rejeu des phases finies, budget non rendu, plafond de phase non gardé, signature ignorée : tous refusés.
  Usage : lua5.2 tests/tranches_foreuses_test.lua   (depuis la racine du mod ; environ 40 s)
]]
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
io.stdout:setvbuf("line")
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end

local PASS_MAX = 800000 -- instructions par pensée (~5 à 8 ms : Td.SLICE états de ~900 à 1 200 instructions, plus la reprise, le tas et la fin du tracé)

local TV_SRC = read("shared/team/traversee.lua")
local TD_SRC = read("script/team/foreuses_tranches.lua")
local TRAV_SRC = read("script/team/traversee.lua")

-- Moteur minimal (celui de traversee_script_test, réduit) ---------------------------------------------
local logs = {}
function log(text) logs[#logs + 1] = text end -- luacheck: ignore
local ORE_ON = false -- la bande de gisement (x 31 à 89, y 21 à 99) existe au moteur pour la scène en cours
local function in_band(x0, y0, x1, y1) return x0 < 90 and x1 > 30 and y0 < 100 and y1 > 20 end
local surface = {
  index = 1,
  find_entities_filtered = function(q)
    local out = {}
    if ORE_ON and q.type == "resource" then
      local x0, y0, x1, y1 = q.area[1][1], q.area[1][2], q.area[2][1], q.area[2][2]
      for x = math.max(31, math.floor(x0)), math.min(89, math.ceil(x1) - 1) do
        for y = math.max(21, math.floor(y0)), math.min(99, math.ceil(y1) - 1) do out[#out + 1] = { position = { x = x + 0.5, y = y + 0.5 }, type = "resource" } end
      end
    end
    return out
  end,
  count_tiles_filtered = function() return 0 end,
  count_entities_filtered = function(q)
    if ORE_ON and q.type == "resource" and in_band(q.area[1][1], q.area[1][2], q.area[2][1], q.area[2][2]) then return 1 end
    return 0
  end,
}
local recipes = { ["underground-belt"] = { enabled = true } }
game = { -- luacheck: ignore
  tick = 100,
  forces = { player = { recipes = recipes } },
  entity_prototypes = { ["transport-belt"] = { belt_speed = 0.03125 } },
  get_filtered_entity_prototypes = function()
    return { ["underground-belt"] = { belt_speed = 0.03125, max_underground_distance = 5, items_to_place_this = { { name = "underground-belt" } }, has_flag = function() return false end } }
  end,
}

-- Charge les modules (réels ou mutants) dans un jeu de modules frais ------------------------------------
local function load_src(src, name)
  local chunk = assert(load(src, "@" .. name, "t", setmetatable({}, { __index = _G })))
  return chunk()
end
local function modules(tv_src, td_src)
  local saved = { package.loaded["shared.team.traversee"], package.loaded["script.team.traversee"] }
  local Tv = load_src(tv_src or TV_SRC, "traversee_shared")
  package.loaded["shared.team.traversee"] = Tv
  local Trav = load_src(TRAV_SRC, "traversee_script")
  package.loaded["script.team.traversee"] = Trav
  local Td = load_src(td_src or TD_SRC, "foreuses_tranches")
  package.loaded["shared.team.traversee"], package.loaded["script.team.traversee"] = saved[1], saved[2]
  return Tv, Trav, Td
end

--- Copie PROFONDE comme une sauvegarde : nombres, chaînes, booléens et tables seulement (une fonction ou un fil : erreur).
local function clone(v, seen)
  local t = type(v)
  if t == "number" or t == "string" or t == "boolean" or t == "nil" then return v end
  if t ~= "table" then error("etat non sauvegardable : " .. t) end
  seen = seen or {}
  if seen[v] then return seen[v] end
  local out = {}
  seen[v] = out
  for k, x in pairs(v) do out[clone(k, seen)] = clone(x, seen) end
  return out
end

-- Terrains ------------------------------------------------------------------------------------------------
local N = 120
local function terrain(dens, enclosed, ore_band, s, t, seed0)
  local seed = seed0 or 20261108
  local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
  local wall = {}
  for x = 0, N - 1 do for y = 0, N - 1 do if rnd() < dens then wall[x * 1000 + y] = true end end end
  for dx = -1, 1 do for dy = -1, 1 do wall[(s.x + dx) * 1000 + s.y + dy] = nil; wall[(t.x + dx) * 1000 + t.y + dy] = nil end end
  if enclosed then
    for dx = -2, 2 do for dy = -2, 2 do if math.max(math.abs(dx), math.abs(dy)) == 2 then wall[(t.x + dx) * 1000 + t.y + dy] = true end end end
  end
  local cost = function(x, y)
    if x < 0 or y < 0 or x >= N or y >= N or wall[x * 1000 + y] then return nil end
    return 1
  end
  local ore = ore_band and function(x, y) return x > 30 and x < 90 and y > 20 and y < 100 end or nil
  return cost, ore
end

local function same_tiles(a, b)
  if (a == nil) ~= (b == nil) then return false end
  if not a then return true end
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i].x ~= b[i].x or a[i].y ~= b[i].y or a[i].dir ~= b[i].dir or a[i].ug ~= b[i].ug then return false end
  end
  return true
end

---------------------------------------------------------------------------------------------------
-- §1 Tv.route par passes
---------------------------------------------------------------------------------------------------
local SLICE = 400 -- (Td.SLICE)
local S1 = {
  { "forêt 15 %", 0.15, false, false },
  { "forêt 30 % + gisement", 0.30, false, true },
  { "forêt 40 % + gisement", 0.40, false, true },
  { "arrivée murée", 0.20, true, false },
  { "arrivée murée + gisement", 0.20, true, true },
  { "boîte vide + gisement", 0.0, false, true },
}

--- Tout le §1 pour un module Tv : rend le nombre d'écarts, la pire passe (instructions), le plus grand nombre de passes.
local function suite1(Tv, quick)
  local bad, worst, most = {}, 0, 0
  local s, t = { x = 2, y = 2 }, { x = N - 3, y = N - 3 }
  local bounds = { x0 = 0, y0 = 0, x1 = N - 1, y1 = N - 1 }
  for si, sc in ipairs(S1) do
    for _, maxd in ipairs({ 0, 5 }) do
     if not quick or si == 2 or si == 5 then
      local cost, ore = terrain(sc[2], sc[3], sc[4], s, t)
      local function ctx() return { weight = 2, max = N * N, budget = { left = N * N }, ore = ore, maxd = maxd > 0 and maxd or nil, nature = function() return "arbre" end } end
      local c1 = ctx()
      local tiles, info = Tv.route(s, t, 0, bounds, cost, c1)
      local c2 = ctx()
      c2.phase_slice = SLICE
      local st, passes, tiles2, info2 = nil, 0, nil, nil
      repeat
        passes = passes + 1
        c2.phase_state = st and clone(st) or nil -- (sauvegardé puis rechargé entre deux passes)
        local n = 0
        debug.sethook(function() n = n + 1 end, "", 1000)
        local ok, a, b, c = pcall(Tv.route, s, t, 0, bounds, cost, c2)
        debug.sethook()
        if not ok then bad[#bad + 1] = sc[1] .. " : erreur " .. tostring(a); break end
        tiles2, info2, st = a, b, c
        if n * 1000 > worst then worst = n * 1000 end
      until info2 ~= "pending" or passes > 200
      if passes > most then most = passes end
      local label = sc[1] .. " maxd=" .. maxd
      local eq = same_tiles(tiles, tiles2)
      if tiles and tiles2 then
        for _, k in ipairs({ "len", "ore", "jumps", "base_len", "base_ore", "pen", "expanded", "searches", "phys" }) do
          if info[k] ~= info2[k] then eq = false; label = label .. " (" .. k .. " " .. tostring(info[k]) .. " contre " .. tostring(info2[k]) .. ")" end
        end
      else
        eq = eq and tostring(info) == tostring(info2)
      end
      if c1.budget.left ~= c2.budget.left then eq = false; label = label .. " (reste du budget " .. c1.budget.left .. " contre " .. c2.budget.left .. ")" end
      if not eq then bad[#bad + 1] = label end
     end
    end
  end
  return bad, worst, most
end

do
  local Tv = load_src(TV_SRC, "traversee_shared")
  local bad, worst, most = suite1(Tv)
  check(#bad == 0, "1.1 par passes = d'un seul appel (tuiles, info, reste du budget) sur 12 cas : " .. table.concat(bad, " ; "))
  check(worst <= PASS_MAX, "1.2 une passe ne dépasse pas " .. PASS_MAX .. " instructions (pire : " .. worst .. ")")
  check(most >= 15 and most <= 60, "1.3 la plus longue recherche se fait en " .. most .. " passes (15 à 60 attendues : 11 400 états en tranches de " .. SLICE .. ")")
  print(string.format("[TRANCHES-FOREUSES] §1 pire passe %d instructions (borne %d), plus longue recherche %d passes", worst, PASS_MAX, most))
end

---------------------------------------------------------------------------------------------------
-- §2 Td.trace : les trois essais du tapis, une tranche par pensée
---------------------------------------------------------------------------------------------------
local P_PITCH = 28 -- (P.PITCH de shared/team/plan.lua ; relu plus bas)
local ROUTE_WEIGHT = 2
local S2 = {
  -- nom, densité, arrivée murée, souterrain refusé (aucun souterrain débloqué), départ, arrivée
  { "court et libre (essai 1)", 0.0, false, false, { x = 10, y = 10 }, { x = 40, y = 30 } },
  { "forêt 15 %, 115 tuiles", 0.15, false, false, { x = 2, y = 2 }, { x = N - 3, y = N - 3 } },
  { "forêt 30 % + gisement", 0.30, false, false, { x = 2, y = 2 }, { x = N - 3, y = N - 3 }, true },
  { "arrivée murée loin, sans souterrain (essais 1 puis 3)", 0.20, true, true, { x = 2, y = 2 }, { x = N - 3, y = N - 3 } },
  { "arrivée murée loin, souterrain + gisement (essais 1 puis 3)", 0.20, true, false, { x = 2, y = 2 }, { x = N - 3, y = N - 3 }, true },
  { "arrivée murée près, sans souterrain (essais 1, 2 puis 3)", 0.20, true, true, { x = 30, y = 30 }, { x = 70, y = 60 } },
  -- le reste du budget de l'essai 1 décide de l'essai 2 : boîte de l'essai 2 plus petite que 4 000 états, plus grande que le reste
  { "arrivée murée très près, forêt 30 %, sans souterrain", 0.30, true, true, { x = 40, y = 40 }, { x = 60, y = 55 } },
}

local P = require("shared.team.plan")
check(P.PITCH == P_PITCH, "2.0 P.PITCH relu : " .. tostring(P.PITCH))

--- L'ancien enchaînement d'un seul appel (build.lua 0.6.72) : essai 1, essai 2 (marge d'un pas), essai 3 pondéré à budget propre.
local function reference(Tv, Trav, sc)
  local s, a = sc.s, sc.a
  local f = { key = "ref", force = "player", build = { stats = {}, order = {}, projects = {} } }
  local p = { id = 1 }
  local topts = function(budget) return { belt = "transport-belt", sd = 2, kind = "foreuses", budget = budget } end
  local budget = { left = Tv.PLAN_BUDGET }
  local b1 = sc.box1
  local tiles, n2 = Trav.route(f, surface, p, s, a, 2, b1, sc.cost, topts(budget))
  local ran = { 1 }
  if not tiles then
    local cx0, cy0 = math.min(s.x, a.x) - P_PITCH, math.min(s.y, a.y) - P_PITCH
    local cx1, cy1 = math.max(s.x, a.x) + P_PITCH, math.max(s.y, a.y) + P_PITCH
    if cx1 - cx0 <= 120 and cy1 - cy0 <= 120 then
      tiles, n2 = Trav.route(f, surface, p, s, a, 2, { x0 = cx0, y0 = cy0, x1 = cx1, y1 = cy1 }, sc.cost, topts(budget))
      ran[#ran + 1] = 2
    end
  end
  local first
  if not tiles and n2 == "trop long" then
    local mg = P_PITCH
    if math.max(math.abs(s.x - a.x), math.abs(s.y - a.y)) + 2 * mg > 120 then mg = 12 end
    local bx = { x0 = math.min(s.x, a.x) - mg, y0 = math.min(s.y, a.y) - mg, x1 = math.max(s.x, a.x) + mg, y1 = math.max(s.y, a.y) + mg }
    local area = (bx.x1 - bx.x0 + 1) * (bx.y1 - bx.y0 + 1)
    first = n2
    local o = topts({ left = area })
    o.weight, o.max = ROUTE_WEIGHT, area
    tiles, n2 = Trav.route(f, surface, p, s, a, 2, bx, sc.cost, o)
    ran[#ran + 1] = 3
  end
  return tiles, n2, first, ran
end

--- Td.trace par tranches. opts.forget : la mémoire locale est perdue (chargement) après chaque passe ; opts.sigs : liste de signatures à essayer par passe.
local function sliced_trace(Tv, Trav, Td, sc, opts)
  opts = opts or {}
  local f = { key = "sl", force = "player", build = { stats = {}, order = {}, projects = {} } }
  local p = { id = 2 }
  local s, a = sc.s, sc.a
  local masks_reads, worst, passes = 0, 0, 0
  local masks = { water = {}, blocked = {}, clear = {} }
  local tiles, n2, tn, first
  local sig = "scene:" .. sc.name
  repeat
    passes = passes + 1
    p = clone(p) -- sauvegarde puis rechargement du projet entre deux pensées
    if opts.forget then Td.forget() end
    local rsd = Td.resume(p, sig, game.tick)
    local e = { p = p, sig = sig, tick = game.tick, rsd = rsd, s = s, a = a, pitch = P_PITCH, box1 = sc.box1,
      topts = { belt = "transport-belt", sd = 2, kind = "foreuses" }, weight = ROUTE_WEIGHT,
      max_of = function(bx) return (bx.x1 - bx.x0 + 1) * (bx.y1 - bx.y0 + 1) end,
      read = function() masks_reads = masks_reads + 1; return { water = {}, blocked = {}, clear = {} } end,
      set_masks = function(m) masks.water, masks.blocked, masks.clear = m.water, m.blocked, m.clear end,
      route = function(bx, o) return Trav.route(f, surface, p, s, a, 2, bx, sc.cost, o) end }
    local n = 0
    debug.sethook(function() n = n + 1 end, "", 1000)
    local ok, r1, r2, r3, r4 = pcall(Td.trace, e)
    debug.sethook()
    if not ok then return nil, "erreur " .. tostring(r1), nil, worst, passes, masks_reads, p end
    if n * 1000 > worst then worst = n * 1000 end
    game.tick = game.tick + 5 -- (une pensée toutes les 5 ticks)
    if r1 ~= "pending" then tiles, n2, tn, first = r1, r2, r3, r4 end
  until (tiles ~= nil or n2 ~= nil) or passes > 400
  return tiles, n2, first, worst, passes, masks_reads, p
end

local function scenes2()
  local out = {}
  for _, d in ipairs(S2) do
    local s, a = d[5], d[6]
    local cost = terrain(d[2], d[3], false, s, a)
    out[#out + 1] = { name = d[1], s = s, a = a, cost = cost, ore = d[7] or nil, noug = d[4],
      box1 = { x0 = math.min(s.x, a.x) - 12, y0 = math.min(s.y, a.y) - 12, x1 = math.max(s.x, a.x) + 12, y1 = math.max(s.y, a.y) + 12 } }
  end
  return out
end

--- Tout le §2 pour un jeu de modules : rend la liste des écarts, la pire pensée, le plus grand nombre de passes.
local TICK0 = 100
local function suite2(Tv, Trav, Td, verbose, quick)
  local bad, worst, most = {}, 0, 0
  for si, sc in ipairs(scenes2()) do
   if not quick or si == 3 or si == 4 or si == 7 then
    TICK0 = TICK0 + 5000 -- (le cache des chunks de gisement du script vit 600 ticks : une scène neuve ne lit pas celui de la précédente)
    game.tick = TICK0
    ORE_ON = sc.ore ~= nil
    recipes["underground-belt"].enabled = not sc.noug
    local rt, rn, rfirst, ran = reference(Tv, Trav, sc)
    for _, variant in ipairs({ { forget = false }, { forget = true } }) do
      game.tick = TICK0
      local tiles, n2, first, w, passes, reads = sliced_trace(Tv, Trav, Td, sc, variant)
      local label = sc.name .. (variant.forget and " (mémoire locale perdue à chaque pensée)" or "")
      if w > worst then worst = w end
      if passes > most then most = passes end
      if not same_tiles(rt, tiles) then bad[#bad + 1] = label .. " : tuiles différentes" end
      if (rt == nil) and tostring(rn) ~= tostring(n2) then bad[#bad + 1] = label .. " : refus « " .. tostring(n2) .. " » contre « " .. tostring(rn) .. " »" end
      if tostring(rfirst) ~= tostring(first) then bad[#bad + 1] = label .. " : raison des essais exacts « " .. tostring(first) .. " » contre « " .. tostring(rfirst) .. " »" end
      if not variant.forget and reads > #ran then bad[#bad + 1] = label .. " : " .. reads .. " lecture(s) de masques pour " .. #ran .. " essai(s)" end
      if verbose then
        print(string.format("  %-52s essais %s : %s, %d pensée(s), pire %d instructions, %d lecture(s) de masques", label, table.concat(ran, "+"),
          tiles and ("tracé " .. #tiles) or tostring(n2), passes, w, reads))
      end
    end
   end
  end
  return bad, worst, most
end

do
  local Tv, Trav, Td = modules()
  local bad, worst, most = suite2(Tv, Trav, Td, true)
  check(#bad == 0, "2.1 trois essais par tranches = l'ancien enchaînement d'un seul appel, avec et sans mémoire locale : " .. table.concat(bad, " ; "))
  check(worst <= PASS_MAX, "2.2 une pensée ne dépasse pas " .. PASS_MAX .. " instructions (pire : " .. worst .. ")")
  check(most >= 20, "2.3 le pire cas demande bien plusieurs pensées (" .. most .. ")")
  print(string.format("[TRANCHES-FOREUSES] §2 pire pensée %d instructions (borne %d), plus longue recherche %d pensées", worst, PASS_MAX, most))

  ORE_ON, recipes["underground-belt"].enabled, game.tick = false, true, 900000 -- (hors des scènes : terrain sans gisement, souterrain débloqué)
  -- 2.4 un essai fini est gardé (p.rs_done) et rejoué sans recherche ; Td.clear le jette
  local sc = scenes2()[1]
  local f = { key = "d", force = "player", build = { stats = {}, order = {}, projects = {} } }
  local p = { id = 3 }
  local calls = 0
  local function e_for(rsd)
    return { p = p, sig = "k", tick = 100, rsd = rsd, s = sc.s, a = sc.a, pitch = P_PITCH, box1 = sc.box1, topts = { belt = "transport-belt", sd = 2, kind = "foreuses" },
      weight = ROUTE_WEIGHT, max_of = function() return 1 end, read = function() return { water = {}, blocked = {}, clear = {} } end, set_masks = function() end,
      route = function(bx, o) calls = calls + 1; return Trav.route(f, surface, p, sc.s, sc.a, 2, bx, sc.cost, o) end }
  end
  local t1 = Td.trace(e_for(nil))
  check(type(t1) == "table" and p.rs_done and p.rs_done.k and p.rs_done.k.done, "2.4 l'essai fini est gardé dans le projet")
  local before = calls
  local t2 = Td.trace(e_for(Td.resume(p, "k", 100)))
  check(t2 == p.rs_done.k.tiles and calls == before, "2.5 un essai fini est rejoué sans recherche (même tracé, aucun appel)")
  Td.clear(p)
  check(p.rs_done == nil and p.rs_drills == nil and Td.cache_empty(), "2.6 Td.clear jette l'état du projet et la mémoire locale")

  -- 2.7 une signature changée repart de zéro et compte ; trop de changements : instable
  local sc4 = scenes2()[4]
  recipes["underground-belt"].enabled, game.tick = false, 950000
  local p2 = { id = 4 }
  local f2 = { key = "e", force = "player", build = { stats = {}, order = {}, projects = {} } }
  local function e2(sig, rsd)
    return { p = p2, sig = sig, tick = 100, rsd = rsd, s = sc4.s, a = sc4.a, pitch = P_PITCH, box1 = sc4.box1, topts = { belt = "transport-belt", sd = 2, kind = "foreuses" },
      weight = ROUTE_WEIGHT, max_of = function(bx) return (bx.x1 - bx.x0 + 1) * (bx.y1 - bx.y0 + 1) end, read = function() return { water = {}, blocked = {}, clear = {} } end,
      set_masks = function() end, route = function(bx, o) return Trav.route(f2, surface, p2, sc4.s, sc4.a, 2, bx, sc4.cost, o) end }
  end
  check(Td.trace(e2("A", Td.resume(p2, "A", 100))) == "pending" and p2.rs_drills and p2.rs_drills.sig == "A", "2.7 la recherche commence et range son état (signature A)")
  check(Td.resume(p2, "B", 100) == nil and p2.rs_drills == nil and p2.rs_drills_n == 1, "2.8 une autre signature : état jeté et compté")
  for i = 1, Td.RESTARTS do
    Td.trace(e2("S" .. i, Td.resume(p2, "S" .. i, 100)))
    Td.resume(p2, "Z" .. i, 100)
  end
  check(Td.unstable(p2), "2.9 trop de signatures changées : tapis instable (refusé, jamais une attente sans fin)")
  check(Td.resume({ id = 5, rs_drills = { sig = "A", tick = 0 } }, "A", Td.CACHE_TTL + 1) == nil, "2.10 un état périmé est jeté")
end

---------------------------------------------------------------------------------------------------
-- §3 Branchement (texte)
---------------------------------------------------------------------------------------------------
do
  local B = read("script/team/build.lua")
  local FB = read("script/team/fonderie_bloc.lua")
  local nlocals = 0
  for _ in B:gmatch("\nlocal ") do nlocals = nlocals + 1 end
  check(nlocals <= 199, "3.1 build.lua : " .. nlocals .. " locales de niveau fichier (199 au plus)")
  check(B:find('Build.TrancheForeuses = require("script.team.foreuses_tranches")', 1, true) ~= nil, "3.2 le module est un champ de Build, pas une locale")
  check(B:find("tiles, n2, tnames, first = Tdr.trace({", 1, true) ~= nil and B:find("Build.Trav.route(f, surface, p, s, { x = a.x, y = a.y }, a.dir, bx, cost, o)", 1, true) ~= nil,
    "3.3 plan_drills passe par Tdr.trace (les trois essais en tranches)")
  check(B:find('return false, "foreuses : trace du tapis en cours (essai "', 1, true) ~= nil and B:find('"foreuses"\n    end', 1, true) ~= nil,
    "3.4 plan_drills rend l'attente « foreuses » sur « pending »")
  check(B:find("if wait then return false, why, wait end", 1, true) ~= nil, "3.5 plan_feed : l'attente remonte AVANT le repli sur un quai")
  check(B:find("if wait then p.parts, p.ents = {}, {}; return false, why, wait end", 1, true) ~= nil, "3.6 plan_alim : l'attente remonte")
  check(B:find("local ok, w2, w3 = plan_feed(f, surface, p, main, 1)", 1, true) ~= nil and B:find("if not ok then return false, w2, w3 end", 1, true) ~= nil,
    "3.7 plan_project : l'attente de plan_feed remonte")
  check(FB:find("if wait then p.parts, p.ents = {}, {}; return false,", 1, true) ~= nil, "3.8 fonderie_bloc : l'attente remonte")
  check(B:find('elseif wait == "foreuses" then', 1, true) ~= nil, "3.9 advance : l'attente « foreuses » rend les réservations et garde le projet en « plan »")
  local i0 = B:find('elseif wait == "foreuses" then', 1, true)
  local branch = i0 and B:sub(i0, B:find('elseif wait == "calcul" then', i0, true) or i0 + 900) or ""
  check(branch:find("b.occ[k] = nil", 1, true) ~= nil and branch:find("l.used = nil", 1, true) ~= nil and branch:find("b.net[n] = nil", 1, true) ~= nil
    and branch:find("p.state", 1, true) == nil, "3.10 la branche libère occ, lots et réseau, et ne change pas l'état du projet")
  check(B:find('if wait ~= "foreuses" then Build.TrancheForeuses.clear(p) end', 1, true) ~= nil, "3.11 l'état du tracé est jeté à la fin du plan")
  -- jamais de fonction dans l'état gardé : les seules écritures dans le projet sont p.rs_drills et p.rs_done, avec des valeurs de données
  check(TD_SRC:find("p%.rs_drills = {") ~= nil and TD_SRC:find("p%.rs_drills = [%w_]*function") == nil, "3.13 p.rs_drills est une table de données")
  -- masques : le moteur n'est relu qu'une fois par essai (read appelé seulement sans cache)
  check(TD_SRC:find("if not masks then masks = e.read(", 1, true) ~= nil, "3.14 les masques gardés évitent la relecture du moteur")
end

---------------------------------------------------------------------------------------------------
-- §4 Mutants : chacun doit être refusé par le §1 ou le §2
---------------------------------------------------------------------------------------------------
local function mutant(label, kind, a, b)
  local t0 = os.clock()
  local src = kind == "tv" and TV_SRC or TD_SRC
  local s, n = src:gsub(a, function() return b end, 1)
  if n == 0 then check(false, "4 mutant introuvable : " .. label) return end
  local refused = false
  if kind == "tv" then
    local Tv, Trav, Td = modules(s, nil)
    local ok, bad, worst = pcall(suite1, Tv, true)
    if not ok or #bad > 0 or worst > PASS_MAX then refused = true end
    if not refused then
      local ok2, bad2, worst2 = pcall(suite2, Tv, Trav, Td, false, true)
      if not ok2 or #bad2 > 0 or worst2 > PASS_MAX then refused = true end
    end
  else
    local Tv, Trav, Td = modules(nil, s)
    local ok, bad, worst = pcall(suite2, Tv, Trav, Td, false, true)
    if not ok or #bad > 0 or worst > PASS_MAX then refused = true end
  end
  check(refused, "4 mutant refusé : " .. label)
  print(string.format("  (mutant « %s » : %.1f s)", label, os.clock() - t0))
end
mutant("pas de limite de passe", "tv", "if pass and pass%.left <= 0 then", "if false then")
mutant("passe non décomptée", "tv", "if pass then pass%.left = pass%.left %- 1 end", "")
mutant("phase finie non rejouée", "tv", "if d then expanded = expanded %+ d%.used; return d%.el, d%.n end", "if false then end")
mutant("plafond de phase A non gardé", "tv", "if PS and PS%.capn%[name%] then capn = PS%.capn%[name%]", "if false then capn = nil")
mutant("reste du budget non rendu", "tv", "if PS and ctx%.budget and PS%.bl then ctx%.budget%.left = PS%.bl end", "")
mutant("budget non gardé entre passes", "tv", "PS%.bl = ctx2%.budget and ctx2%.budget%.left or nil", "")
mutant("tranche × 40", "td", "Td%.SLICE = 400", "Td.SLICE = 16000")
mutant("essai 2 sauté", "td", "nxt = geometry%(2, e%) and 2 or %(n2 == \"trop long\" and 3 or nil%)", "nxt = n2 == \"trop long\" and 3 or nil")
mutant("essai pondéré jamais", "td", "nxt = n2 == \"trop long\" and 3 or nil", "nxt = nil")
mutant("reste du budget exact oublié", "td", "o%.budget = { left = %(rs and rs%.bl%) or Tv%.PLAN_BUDGET }", "o.budget = { left = Tv.PLAN_BUDGET }")
mutant("masques relus à chaque pensée", "td", "local masks = %(c and c%.sigk == sigk and e%.tick %- c%.tick < Td%.CACHE_TTL%) and c%.masks or nil", "local masks = nil")
mutant("état repris sans l'essai", "td", "o%.phase_state = %(rs and rs%.stage == stage%) and rs%.st or nil", "o.phase_state = nil")

print(string.format("[TRANCHES-FOREUSES] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
