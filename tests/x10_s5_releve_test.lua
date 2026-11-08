--[[
  Lot S5 du ×10, relevé de FoSwap (sur essai-0662 4c312474) : preuves hors jeu de script/team/foreuse_swap.lua, survey_step, sink_tiles et
  receiver_of. Changements : plan_pole_tiles(f) lu UNE fois par appel de survey_step (au premier poteau), au lieu d'une fois par poteau ;
  clé de tuile numérique tx * 4194304 + ty dans sink_tiles et receiver_of, au lieu de « tx:ty ».
  Critères (écrits avant le code, demande du lead du 7/11 : « identité stricte, mutants, avant/après ») :
    R1 relevé en tranches (budgets tirés, 1 à 12 unités, ou sans borne une fois sur 8) : mêmes (coût, fini) à chaque appel, mêmes pass.entries, pass.refs
       (identités comprises), pass.poles, pass.burners que la référence ; le plan directeur (f.build), les poteaux posés (f.swap.pole_pos) et
       les propriétaires changent ENTRE deux appels, jamais pendant (comme en jeu : un appel ne rend pas la main) ;
    R2 receiver_of(d, sink_tiles(o)) : même récepteur que la référence pour toutes les foreuses valides (coordonnées jusqu'à ±999 000) ;
    R3 mutants qui DOIVENT être vus ;
    R4 coût sur un modèle d'azure (sauvegarde du DC : 133 projets, 7 avant-postes, 137 foreuses ; 250 poteaux dans le rayon 78) :
       instructions (debug.sethook, compte 1), conversions nombre -> chaîne, mémoire allouée ; même relevé.
  Référence : tests/fixtures/x10_s5_foreuse_swap_script_ref.lua, copie EXACTE (objet git 058f3279) de script/team/foreuse_swap.lua à 4c312474.
  Les entités sont des doublures à lecture par métatable : leurs lectures coûtent des instructions Lua, absentes en jeu (lectures en C), ce qui
  DILUE le gain mesuré en R4 (borne basse).
  Usage (racine du mod) : lua5.2 tests/x10_s5_releve_test.lua [--court]
]]
package.path = "./?.lua;" .. package.path

local COURT = arg and arg[1] == "--court"
local T = require("shared.team.config")
local S = require("shared.team.foreuse_swap")
local P = require("shared.team.plan")
local ok_n, ko_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 else ko_n = ko_n + 1 print("  ECHEC : " .. msg) end
end
local function read(p) local h = assert(io.open(p, "rb")) local s = h:read("*a") h:close() return s end

local function Rng(seed)
  local s = seed % 2147483647
  if s <= 0 then s = s + 2147483646 end
  local r = {}
  function r.next() s = (s * 16807) % 2147483647 return s end
  function r.int(a, b) return a + (r.next() % (b - a + 1)) end
  function r.pick(t) return t[r.int(1, #t)] end
  return r
end

-- doublures du moteur et des modules ----------------------------------------------------------------------------------------------
defines = { flow_precision_index = { one_minute = 1 }, events = {} }
game = { tick = 100000, entity_prototypes = {} }
function log() end
local OWN = {}
package.loaded["script.faction.state"] = {
  sorted_keys = function(t) local k = {} for key in next, t do k[#k + 1] = key end table.sort(k, function(a, b) return tostring(a) < tostring(b) end) return k end,
  owner = function(u) return OWN[u] end, own = function() end, disown = function() end,
}
package.loaded["script.team.board"] = { add = function() return 0 end }
package.loaded["script.team.stock"] = { count = function() return 0 end }
package.loaded["script.faction.outposts"] = {}
package.loaded["script.team.melange"] = {}
package.loaded["script.team.sante_centrale"] = {}
package.loaded["script.core.scheduler"] = setmetatable({}, { __index = function() return function() end end })
package.loaded["script.core.profiler"] = { fstart = function() end, fstop = function() end }

local function patch(src, a, b)
  local i, j = src:find(a, 1, true)
  assert(i, "motif introuvable : " .. a)
  assert(not src:find(a, j + 1, true), "motif en double : " .. a)
  return src:sub(1, i - 1) .. b .. src:sub(j + 1)
end
local EXPOSE = "\nSwap._survey_step, Swap._sink_tiles, Swap._receiver_of = survey_step, sink_tiles, receiver_of\nreturn Swap"
local function load_swap(src, name)
  src = patch(src, "\nreturn Swap", EXPOSE)
  local fn = assert(load(src, "=" .. name, "t"))
  return fn()
end
local REF_SRC = read("tests/fixtures/x10_s5_foreuse_swap_script_ref.lua"):gsub("\r\n", "\n")
local NEW_SRC = read("script/team/foreuse_swap.lua"):gsub("\r\n", "\n")
local R = load_swap(REF_SRC, "foreuse_swap_ref")
local N = load_swap(NEW_SRC, "foreuse_swap")

-- entités à lectures (position : table neuve à chaque lecture, comme le moteur) ---------------------------------------------------------
local function entity(data)
  return setmetatable({}, { __index = function(_, k)
    local v = data[k]
    if k == "position" then return { x = v.x, y = v.y } end
    return v
  end })
end
local P_FUR = entity({ tile_width = 2, tile_height = 2 })
local P_CHEST = entity({ tile_width = 1, tile_height = 1 })
local P_SMALL = entity({ supply_area_distance = 2.5, max_wire_distance = 7.5 })
local P_MED = entity({ supply_area_distance = 3.5, max_wire_distance = 9 })

-- modèle d'azure (sauvegarde du DC, 7/11) : minerai, migration, foreuses par avant-poste
local AZURE = { { "copper", "en cours", 0 }, { "iron", "en cours", 0 }, { "stone", nil, 18 }, { "copper", "en cours", 0 }, { "iron", nil, 11 },
  { "coal", nil, 66 }, { "coal", nil, 42 } }

--- Monde tiré : avant-postes (foreuses et réceptacles), poteaux. Lu seulement par le relevé : partagé par la référence et le nouveau code.
--- `big` : modèle d'azure, sans cas tordus.
local function world(r, big)
  local unit = 1000
  local function rare(n) return (not big) and r.int(1, n) == 1 end
  local outposts, poles = {}, {}
  local n_out = big and #AZURE or r.int(1, 6)
  for oid = 1, n_out do
    local far = big and 0 or r.pick({ 0, 0, 0, 0, 999000, -999000 })
    local ox, oy = r.int(-30, 30) * 20 + far, r.int(-30, 30) * 20 - far
    local spec = big and AZURE[oid] or { r.pick({ "coal", "iron", "copper", "stone" }), rare(8) and "en cours" or nil, r.int(0, 25) }
    local drills, sinks = {}, {}
    for k = 1, spec[3] do
      unit = unit + 1
      local x, y = ox + (k % 8) * 4, oy + math.floor(k / 8) * 6
      if rare(12) then x = x + r.int(1, 255) / 256 end -- (hors grille : virgule fixe du moteur)
      local dir = r.pick({ 0, 2, 4, 6 })
      local name = rare(7) and T.DRILL_ELECTRIC or T.DRILL
      local v = (name == T.DRILL) and T.drill_drop or T.drill_electric.drop
      local ddx, ddy = S.rotate(dir, v[1], v[2])
      local sx, sy = x + ddx, y + ddy
      -- réceptacle sous le point de dépôt (four 2 x 2 au centre entier, ou coffre 1 x 1), parfois loin, invalide ou sans numéro
      local u = r.int(1, 10)
      local sink
      unit = unit + 1
      if u <= 6 or (big and spec[1] ~= "coal") then
        sink = entity({ valid = not rare(15), unit_number = (not rare(20)) and unit or nil,
          position = { x = math.floor(sx) + r.int(0, 1), y = math.floor(sy) + r.int(0, 1) }, prototype = P_FUR })
      elseif u <= 9 or big then
        sink = entity({ valid = true, unit_number = unit, position = { x = math.floor(sx) + 0.5, y = math.floor(sy) + 0.5 }, prototype = P_CHEST })
      else
        sink = entity({ valid = true, unit_number = unit, position = { x = sx + 3, y = sy - 2 }, prototype = P_FUR })
      end
      sinks[#sinks + 1] = sink
      local t = r.int(1, 6)
      local tgt = (t <= 2) and sink or ((t == 3 and not big) and entity({ valid = false }) or nil) -- connu, invalide, ou rien encore déposé
      unit = unit + 1
      drills[k] = entity({ valid = not rare(25), name = name, unit_number = (not rare(30)) and unit or nil, position = { x = x, y = y },
        direction = dir, drop_target = tgt })
    end
    for i = #sinks, 2, -1 do local j = r.int(1, i) sinks[i], sinks[j] = sinks[j], sinks[i] end
    outposts[oid] = { id = oid, kind = spec[1], migr = spec[2], pos = { x = ox + 15, y = oy + 15 }, drill_list = drills, sinks = sinks }
  end
  local np = big and 250 or r.int(0, 60)
  for k = 1, np do
    unit = unit + 1
    local o = outposts[1 + (k % n_out)]
    local net = r.int(1, 6)
    poles[k] = entity({ valid = not rare(20), unit_number = (not rare(25)) and unit or nil,
      position = { x = o.pos.x + r.int(-75, 75) + 0.5, y = o.pos.y + r.int(-75, 75) + 0.5 }, prototype = (k % 3 == 0) and P_MED or P_SMALL,
      electric_network_id = (not rare(12)) and net or nil,
      electric_network_statistics = { input_counts = { ["steam-engine"] = 1 }, get_flow_count = function() return (net <= 2) and 5 or 0 end } })
  end
  local surface = { find_entities_filtered = function(a)
    local out = {}
    for _, p in ipairs(poles) do
      local pos = p.position
      if (pos.x - a.position.x) ^ 2 + (pos.y - a.position.y) ^ 2 <= a.radius ^ 2 then out[#out + 1] = p end
    end
    return out
  end }
  return { outposts = outposts, poles = poles, surface = surface }
end

--- Équipe (parties mutables : plan directeur, poteaux posés, délais), refaite à l'identique depuis une graine.
local function team(seed, w, key, big)
  local r = Rng(seed)
  local order, projects = {}, {}
  for pid = 1, (big and 133 or r.int(0, 40)) do
    order[pid] = pid
    local ents = {}
    for e = 1, r.int(0, big and 60 or 12) do
      local pole = r.int(1, 6) == 1
      local x, y
      if pole and #w.poles > 0 and r.int(1, 2) == 1 then
        local pos = w.poles[r.int(1, #w.poles)].position -- poteau du plan directeur déjà debout
        x, y = pos.x, pos.y
      else
        x, y = r.int(-700, 700) + 0.5, r.int(-700, 700) + 0.5
      end
      ents[e] = { name = pole and "small-electric-pole" or "assembling-machine-1", x = x, y = y }
    end
    projects[pid] = { ents = ents }
  end
  local retry = {}
  for _, o in ipairs(w.outposts) do
    for _, d in ipairs(o.drill_list) do
      if r.int(1, 6) == 1 then
        local pos = d.position
        retry[pos.x .. ":" .. pos.y] = (r.int(1, 2) == 1) and game.tick + 5000 or game.tick - 5000
      end
    end
  end
  local pole_pos = {}
  for _, p in ipairs(w.poles) do
    if r.int(1, 10) == 1 then pole_pos[P.tkey(math.floor(p.position.x), math.floor(p.position.y))] = true end
  end
  return { id = 2, key = key, force = "f", outposts = w.outposts, build = { order = order, projects = projects }, swap = { retry = retry, pole_pos = pole_pos } }
end

local function new_pass(f)
  local oids = {}
  for oid in next, f.outposts do oids[#oids + 1] = oid end
  table.sort(oids)
  return { oids = oids, oi = 1, di = 1, entries = {}, refs = {}, poles = {}, seen = {}, nets = {}, t0 = game.tick, any = false, burners = {} }
end

--- Changement ENTRE deux appels (tiré) : projet ajouté avec un poteau debout, poteau ajouté à un projet, poteau posé retenu, propriétaire changé.
local function mutate_between(r, f, w)
  local u = r.int(1, 6)
  local b = f.build
  local p = (#w.poles > 0) and w.poles[r.int(1, #w.poles)] or nil
  if not p then return end
  if u == 1 then
    local pid = #b.order + 1
    b.order[pid] = pid
    b.projects[pid] = { ents = { { name = "small-electric-pole", x = p.position.x, y = p.position.y } } }
  elseif u == 2 and #b.order > 0 then
    local q = b.projects[b.order[r.int(1, #b.order)]]
    q.ents[#q.ents + 1] = { name = "medium-electric-pole", x = p.position.x, y = p.position.y }
  elseif u == 3 then
    f.swap.pole_pos[P.tkey(math.floor(p.position.x), math.floor(p.position.y))] = true
  elseif u == 4 then
    local un = p.unit_number
    if un then OWN[un] = (OWN[un] == nil) and { f = 2 } or nil end
  end
end

local function same_pass(a, b)
  if #a.entries ~= #b.entries then return false, "entries " .. #a.entries .. " / " .. #b.entries end
  for i = 1, #a.entries do
    local x, y = a.entries[i], b.entries[i]
    for _, k in ipairs({ "id", "x", "y", "dir", "o" }) do if x[k] ~= y[k] then return false, "entrée " .. i .. " " .. k end end
    for _, k in ipairs({ "x", "y", "w", "h" }) do if x.sink[k] ~= y.sink[k] then return false, "récepteur " .. i end end
  end
  for id, x in next, a.refs do
    local y = b.refs[id]
    if not (y and x.oid == y.oid and x.index == y.index and x.drill == y.drill and x.key == y.key and x.sink_ent == y.sink_ent) then
      return false, "ref " .. tostring(id)
    end
  end
  for id in next, b.refs do if not a.refs[id] then return false, "ref en trop" end end
  if #a.poles ~= #b.poles then return false, "poteaux " .. #a.poles .. " / " .. #b.poles end
  for i = 1, #a.poles do
    local x, y = a.poles[i], b.poles[i]
    for _, k in ipairs({ "id", "x", "y", "dist", "wire", "powered", "ent" }) do if x[k] ~= y[k] then return false, "poteau " .. i .. " " .. k end end
  end
  for k, v in next, a.burners do if b.burners[k] ~= v then return false, "thermiques" end end
  for k in next, b.burners do if a.burners[k] == nil then return false, "thermiques en trop" end end
  for _, k in ipairs({ "oi", "di", "any" }) do if a[k] ~= b[k] then return false, "curseur " .. k end end
  return true
end

--- Un relevé complet en tranches, avec les changements entre deux appels tirés de `seed`.
local function run_survey(SW, w, seed, key, owners0)
  for k in next, OWN do OWN[k] = nil end
  for k, v in next, owners0 do OWN[k] = v end
  local f = team(seed, w, key, false)
  local pass = new_pass(f)
  local r = Rng(seed + 7)
  local calls = {}
  for _ = 1, 10000 do
    local budget = (r.int(1, 8) == 1) and math.huge or r.int(1, 12)
    local used, done = SW._survey_step(f, w.surface, pass, budget)
    calls[#calls + 1] = tostring(used) .. "/" .. tostring(done)
    if done then break end
    mutate_between(r, f, w)
  end
  return pass, table.concat(calls, " "), #calls
end

local RUN_TAG = 0
local function r1_run(SW, n, seed0)
  RUN_TAG = RUN_TAG + 1 -- (clés d'équipe neuves à chaque série : mémoire plan_poles de chaque module)
  local bad, first, n_e, n_p, n_c = 0, nil, 0, 0, 0
  local rr = Rng(seed0)
  for t = 1, n do
    local w = world(rr, false)
    local owners0 = {}
    for _, p in ipairs(w.poles) do local un = p.unit_number if un and rr.int(1, 2) == 1 then owners0[un] = { f = 2 } end end
    local seed = rr.int(1, 1000000)
    local key = "s" .. RUN_TAG .. "e" .. t
    local a, ca, nc = run_survey(R, w, seed, key, owners0)
    local b, cb = run_survey(SW, w, seed, key, owners0)
    n_e, n_p, n_c = n_e + #a.entries, n_p + #a.poles, n_c + nc
    local ok, why = same_pass(a, b)
    if not (ok and ca == cb) then
      bad = bad + 1
      first = first or ("équipe " .. t .. " : " .. (why or ("appels " .. ca .. " / " .. cb)))
    end
  end
  return bad, first, n_e, n_p, n_c
end

do
  local n = COURT and 300 or 1500
  local bad, first, n_e, n_p, n_c = r1_run(N, n, 31)
  print(string.format("[X10-S5-RELEVE] R1 relevé en tranches : %d équipes, %d appels, %d entrées et %d poteaux de référence, %d écart(s)%s",
    n, n_c, n_e, n_p, bad, first and (" ; premier : " .. first) or ""))
  check(bad == 0, "R1 : même relevé que la référence, tranche par tranche (" .. bad .. " écarts)")
  check(n_e > n and n_p > n and n_c > 3 * n, "R1 : les modèles produisent des entrées, des poteaux et des tranches (" .. n_e .. ", " .. n_p .. ", " .. n_c .. ")")
end

-- R2 : receiver_of(d, sink_tiles(o)) ------------------------------------------------------------------------------------------------
local function r2_run(SW, n, seed)
  local rr = Rng(seed)
  local bad, seen, found = 0, 0, 0
  for _ = 1, n do
    local w = world(rr, false)
    for _, o in ipairs(w.outposts) do
      local a0, a1 = R._sink_tiles(o), SW._sink_tiles(o)
      for _, d in ipairs(o.drill_list) do
        if d.valid then
          seen = seen + 1
          local x = R._receiver_of(d, a0)
          if x ~= SW._receiver_of(d, a1) then bad = bad + 1 end
          if x and x ~= d.drop_target then found = found + 1 end
        end
      end
    end
  end
  return bad, seen, found
end
do
  local n = COURT and 300 or 1500
  local bad, seen, found = r2_run(N, n, 77)
  print(string.format("[X10-S5-RELEVE] R2 receiver_of(sink_tiles) : %d foreuses, %d réceptacles trouvés par la tuile, %d écart(s)", seen, found, bad))
  check(bad == 0, "R2 : même récepteur que la référence (" .. bad .. " écarts)")
  check(found > n, "R2 : des réceptacles trouvés par la tuile (" .. found .. ")")
end

-- R3 : mutants -----------------------------------------------------------------------------------------------------------------------
do
  local MUT = {
    { "pset gardé d'un appel à l'autre (mémoire de module)", { { "  local pset\n  pass.burners = pass.burners or {}", "  pass.burners = pass.burners or {}" },
      { "local function survey_step(f, surface, pass, budget)", "local pset\nlocal function survey_step(f, surface, pass, budget)" } }, "r1" },
    { "pset gardé dans la passe (lu une fois par relevé)", { { "if not pset then pset = plan_pole_tiles(f) end", "pass.pset = pass.pset or plan_pole_tiles(f) pset = pass.pset" } }, "r1" },
    { "plan directeur ignoré", { { "if team_pole(f, p, pset) then", "if team_pole(f, p, {}) then" } }, "r1" },
    { "clé de tuile sans le décalage (sink_tiles)", { { "at[tx * 4194304 + ty] = k", "at[tx + ty] = k" } }, "r2" },
    { "décalage trop petit (sink_tiles), collisions", { { "at[tx * 4194304 + ty] = k", "at[tx * 4 + ty] = k" } }, "r2" },
    { "clé de tuile inversée (receiver_of)", { { "return at[math.floor(px) * 4194304 + math.floor(py)]", "return at[math.floor(py) * 4194304 + math.floor(px)]" } }, "r2" },
    { "troncature vers zéro au lieu de floor (receiver_of)", { { "return at[math.floor(px) * 4194304 + math.floor(py)]",
      "return at[(px < 0 and math.ceil(px) or math.floor(px)) * 4194304 + (py < 0 and math.ceil(py) or math.floor(py))]" } }, "r2" },
  }
  local seen_n = 0
  for _, mu in ipairs(MUT) do
    local src = NEW_SRC
    for _, ab in ipairs(mu[2]) do src = patch(src, ab[1], ab[2]) end
    local ok, M = pcall(load_swap, src, "mutant")
    local caught = not ok
    if ok then
      local ok2, bad
      if mu[3] == "r1" then ok2, bad = pcall(r1_run, M, COURT and 300 or 600, 31) else ok2, bad = pcall(r2_run, M, COURT and 300 or 600, 77) end
      caught = (not ok2) or bad > 0
    end
    if caught then seen_n = seen_n + 1 end
    print(string.format("[X10-S5-RELEVE] R3 mutant « %s » : %s", mu[1], caught and "vu" or "NON VU"))
  end
  print(string.format("[X10-S5-RELEVE] R3 : mutants vus %d sur %d", seen_n, #MUT))
  check(seen_n == #MUT, "R3 : tous les mutants vus (" .. seen_n .. " sur " .. #MUT .. ")")
end

-- R4 : coût, modèle d'azure ----------------------------------------------------------------------------------------------------------
do
  local CONV = 0
  __S5K = function(a, b) CONV = CONV + 2 return a .. ":" .. b end
  __S5KT = function(a, b) CONV = CONV + 2 return tostring(a) .. ":" .. tostring(b) end
  -- copie où chaque clé « a:b » passe par un compteur qui rend la même chaîne ; nombre de remplacements contrôlé
  local function counted(src, want)
    local s, n, got = src, 0, {}
    s, n = s:gsub('at%[tx %.%. ":" %.%. ty%] = k', 'at[__S5K(tx, ty)] = k') got[1] = n
    s, n = s:gsub('return at%[math%.floor%(px%) %.%. ":" %.%. math%.floor%(py%)%]', 'return at[__S5K(math.floor(px), math.floor(py))]') got[2] = n
    s, n = s:gsub('tostring%(pid%) %.%. ":" %.%. tostring%(p and p%.ents and #p%.ents or 0%)', '__S5KT(pid, p and p.ents and #p.ents or 0)') got[3] = n
    s, n = s:gsub('local key = pos%.x %.%. ":" %.%. pos%.y\n', 'local key = __S5K(pos.x, pos.y)\n') got[4] = n
    check(table.concat(got, ",") == want, "R4 : copie de comptage (" .. table.concat(got, ",") .. " au lieu de " .. want .. ")")
    return load_swap(s, "compte")
  end
  local RC, NC = counted(REF_SRC, "1,1,1,1"), counted(NEW_SRC, "0,0,1,1")
  local w = world(Rng(5), true)
  for k in next, OWN do OWN[k] = nil end
  for k, p in ipairs(w.poles) do if k % 2 == 0 then OWN[p.unit_number] = { f = 2 } end end
  local function measure(SW, SC, key)
    local f = team(9, w, key, true)
    SW._survey_step(f, w.surface, new_pass(f), math.huge) -- (régime établi : mémoire de plan_pole_tiles faite)
    local c = 0
    local pass = new_pass(f)
    debug.sethook(function() c = c + 1 end, "", 1)
    SW._survey_step(f, w.surface, pass, math.huge)
    debug.sethook()
    collectgarbage("collect") collectgarbage("stop")
    local m0 = collectgarbage("count")
    SW._survey_step(f, w.surface, new_pass(f), math.huge)
    local kb = collectgarbage("count") - m0
    collectgarbage("restart")
    local fc = team(9, w, key .. "c", true)
    SC._survey_step(fc, w.surface, new_pass(fc), math.huge)
    CONV = 0
    SC._survey_step(fc, w.surface, new_pass(fc), math.huge)
    return c, kb, CONV, pass
  end
  local i0, k0, c0, p0 = measure(R, RC, "azur-ref")
  local i1, k1, c1, p1 = measure(N, NC, "azur-new")
  print(string.format("[X10-S5-RELEVE] R4 modèle d'azure (133 projets, 7 avant-postes, 137 foreuses, 250 poteaux) : %d entrées, %d poteaux gardés",
    #p0.entries, #p0.poles))
  print(string.format("[X10-S5-RELEVE] R4 relevé : instructions %d -> %d (/%.1f) ; conversions nombre -> chaîne %d -> %d ; mémoire %.0f -> %.0f Ko",
    i0, i1, i0 / math.max(1, i1), c0, c1, k0, k1))
  check(same_pass(p0, p1), "R4 : même relevé")
  check(#p0.entries > 50 and #p0.poles > 50, "R4 : le modèle relève des foreuses et des poteaux")
  check(i0 >= 3 * i1, "R4 : instructions du relevé divisées par au moins 3")
  check(c1 * 10 <= c0, "R4 : conversions divisées par au moins 10")
  check(k1 < k0, "R4 : moins de mémoire allouée")
end

print(string.format("[X10-S5-RELEVE] BILAN : %d OK, %d ECHEC(S)", ok_n, ko_n))
os.exit(ko_n == 0 and 0 or 1)
