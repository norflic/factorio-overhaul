--[[
  Monde factice des tests de l'exécutant des foreuses (script/team/foreuse_swap.lua) : moteur minimal (entités, boîtes, poteaux reliés par
  fil, réseau = composante connexe d'une source, statistiques, inventaires), dépendances factices (State, Stock, Board, Scheduler,
  Outposts.reserved, Melange, Sante), passes jouées comme par la pensée et les minuteries des tranches. Extrait de
  tests/foreuse_tranches_test.lua (lot TRANCHES) pour servir aussi à tests/foreuse_reserve_test.lua (réserve d'amorçage) ; rien n'y change.
  Mo.fresh(text, sliced, slice, build) : module chargé depuis `text` (mutants), monde bâti par build(W) -> hq, avant-postes, source.
  Mo.play(R, passes) : R.hook(R), s'il existe, est appelé après chaque tranche jouée par la minuterie.
  W.no_targets = true : aucune foreuse n'a de drop_target (posée avant son récepteur, rien déposé encore).
  Partie C (repli thermique) : statut d'une électrique lu à la couverture des poteaux d'un réseau vivant (au travail, ou no_power ;
  W.low : low_power ; no_power au tick de sa pose par create_entity, e.born, comme en moteur réel ; W.dead : source qui ne produit
  plus, réseau intact ; W.stats_lag : flux de la dernière minute encore positif) ; e.mine (W.full : coffre plein) ; Stock.inventories ; defines.entity_status.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local SRC_PATH = "script/team/foreuse_swap.lua"

local Mo = {}

local function sorted_keys(t)
  local k = {}
  for x in pairs(t or {}) do k[#k + 1] = x end
  table.sort(k, function(a, b) if type(a) == type(b) then return a < b end return type(a) == "number" end)
  return k
end
Mo.sorted_keys = sorted_keys

---------------------------------------------------------------------------------------------------
-- Monde factice
---------------------------------------------------------------------------------------------------
local PROTO = {
  ["burner-mining-drill"] = { type = "mining-drill", w = 2, burner = true, drop = T.drill_drop },
  ["electric-mining-drill"] = { type = "mining-drill", w = 3, drop = T.drill_electric.drop, mining_drill_radius = 2.49, energy_usage = 1500 },
  ["stone-furnace"] = { type = "furnace", w = 2 },
  ["iron-chest"] = { type = "container", w = 1 },
  ["fo-team-chest"] = { type = "container", w = 1 },
  ["small-electric-pole"] = { type = "electric-pole", w = 1, supply_area_distance = 2.5, max_wire_distance = 7.5 },
  ["medium-electric-pole"] = { type = "electric-pole", w = 1, supply_area_distance = 3.5, max_wire_distance = 9 },
  ["iron-ore"] = { type = "resource", w = 1 },
}
for name, p in pairs(PROTO) do p.name = name; p.tile_width, p.tile_height = p.w, p.w end
Mo.PROTO = PROTO

local function world()
  local W = { ents = {}, next_u = 1, logs = {} }
  local function box(e)
    local h = PROTO[e.name].w / 2
    return { left_top = { x = e.position.x - h, y = e.position.y - h }, right_bottom = { x = e.position.x + h, y = e.position.y + h } }
  end
  local function inside(b, x, y) return x > b.left_top.x and x < b.right_bottom.x and y > b.left_top.y and y < b.right_bottom.y end
  local function net_root(e)
    local seen, stack = { [e] = true }, { e }
    while #stack > 0 do
      local c = table.remove(stack)
      if c.source then return c.unit_number end
      for _, n in ipairs(c.wires) do if n.valid and not seen[n] then seen[n] = true; stack[#stack + 1] = n end end
    end
    return nil
  end
  local mt = {}
  mt.__index = function(e, k)
    local p = PROTO[e.name]
    if k == "prototype" then return p end
    if k == "type" then return p.type end
    if k == "bounding_box" then return box(e) end
    if k == "burner" then return p.burner and {} or nil end
    if k == "drop_target" then
      if not p.drop then return nil end
      -- W.no_targets : comme une foreuse posée avant son récepteur qui n'a encore rien déposé (banc foreuses-dense du 7/11)
      if W.no_targets then return nil end
      local S = require("shared.team.foreuse_swap")
      local vx, vy = S.rotate(e.direction, p.drop[1], p.drop[2])
      local x, y = e.position.x + vx, e.position.y + vy
      for _, o in ipairs(W.ents) do
        if o.valid and (PROTO[o.name].type == "furnace" or PROTO[o.name].type == "container") and inside(box(o), x, y) then return o end
      end
      return nil
    end
    if k == "electric_network_id" then
      if p.type ~= "electric-pole" then return nil end
      return net_root(e) or (100000 + e.unit_number)
    end
    if k == "electric_network_statistics" then
      -- W.dead : la source ne produit plus (réseau intact : mêmes fils, même numéro) ; W.stats_lag : après une coupure, le moteur lit
      -- encore le flux de la DERNIÈRE MINUTE (banc foreuses-panne-diag du 8/11)
      local live = (net_root(e) ~= nil and not W.dead) or W.stats_lag == true
      return { input_counts = live and { gen = 1 } or {}, get_flow_count = function() return live and 1 or 0 end }
    end
    if k == "neighbours" then return { copper = e.wires } end
    if k == "status" then
      -- partie C : électrique sous la zone d'alimentation d'un poteau d'un réseau vivant : au travail (1), ou low_power (3) si W.low ;
      -- sinon sans courant (2, no_power). Modèle PESSIMISTE : une foreuse figée (active == false) rend aussi no_power (le moteur rend
      -- disabled_by_script) : le compte de l'exécutant doit l'exclure lui-même.
      if p.type ~= "mining-drill" or p.burner then return 1 end
      -- banc foreuses-panne-diag du 8/11 (mesuré) : une électrique posée par script est sans courant AU TICK de sa pose (tampon vide)
      if rawget(e, "born") ~= nil and rawget(e, "born") == game.tick then return 2 end
      local b = box(e)
      for _, q in ipairs(W.ents) do
        local qp = PROTO[q.name]
        if q.valid and qp.type == "electric-pole" and net_root(q) and not W.dead then
          local r = qp.supply_area_distance
          if q.position.x - r < b.right_bottom.x and q.position.x + r > b.left_top.x and q.position.y - r < b.right_bottom.y
              and q.position.y + r > b.left_top.y then
            return W.low and 3 or 1
          end
        end
      end
      return 2
    end
    if k == "mine" then
      return function(o)
        if W.full then return false end
        o.inventory.insert({ name = e.name, count = 1 })
        e.valid = false
        return true
      end
    end
    if k == "destroy" then return function() e.valid = false end end
    if k == "connect_neighbour" then
      return function(o)
        local d2 = (e.position.x - o.position.x) ^ 2 + (e.position.y - o.position.y) ^ 2
        if not o.valid or d2 > math.min(p.max_wire_distance or 0, PROTO[o.name].max_wire_distance or 0) ^ 2 + 1e-9 then return false end
        e.wires[#e.wires + 1] = o; o.wires[#o.wires + 1] = e
        return true
      end
    end
    if k == "disconnect_neighbour" then
      return function(o)
        for i = #e.wires, 1, -1 do if e.wires[i] == o then table.remove(e.wires, i) end end
        for i = #o.wires, 1, -1 do if o.wires[i] == e then table.remove(o.wires, i) end end
      end
    end
    local function inv_of(t)
      return {
        get_item_count = function(n) return t[n] or 0 end,
        insert = function(s) t[s.name] = (t[s.name] or 0) + s.count; return s.count end,
        get_contents = function() local c = {} for n, v in pairs(t) do if v > 0 then c[n] = v end end return c end,
      }
    end
    if k == "get_fuel_inventory" then return function() return inv_of(e.inv.fuel) end end
    if k == "get_inventory" then return function(i) return inv_of(e.inv[i] or {}) end end
    return nil
  end
  function W.add(name, x, y, dir, extra)
    local e = setmetatable({ name = name, position = { x = x, y = y }, direction = dir or 0, valid = true, unit_number = W.next_u, wires = {},
      inv = { fuel = {}, [2] = {}, [3] = {}, [4] = {}, [1] = {} } }, mt)
    W.next_u = W.next_u + 1
    for kk, v in pairs(extra or {}) do e[kk] = v end
    W.ents[#W.ents + 1] = e
    return e
  end
  local function types_ok(want, t)
    if not want then return true end
    if type(want) == "string" then return want == t end
    for _, w in ipairs(want) do if w == t then return true end end
    return false
  end
  local function find(o)
    local out = {}
    for _, e in ipairs(W.ents) do
      if e.valid then
        local p = PROTO[e.name]
        local keep = types_ok(o.type, p.type) and (not o.name or o.name == e.name) and (not o.force or e.force == o.force or p.type == "resource")
        if keep and o.collision_mask and p.type == "resource" then keep = false end
        if keep and o.area then
          local b = box(e)
          keep = b.left_top.x <= o.area[2][1] and b.right_bottom.x >= o.area[1][1] and b.left_top.y <= o.area[2][2] and b.right_bottom.y >= o.area[1][2]
        end
        if keep and o.position and o.radius then
          local px, py = o.position.x or o.position[1], o.position.y or o.position[2]
          keep = (e.position.x - px) ^ 2 + (e.position.y - py) ^ 2 <= o.radius ^ 2
        end
        if keep then out[#out + 1] = e end
      end
    end
    return out
  end
  W.surface = {
    find_entities_filtered = find,
    count_entities_filtered = function(o) return #find(o) end,
    count_tiles_filtered = function() return 0 end,
    find_tiles_filtered = function() return {} end,
    find_nearest_enemy = function() return nil end,
    can_place_entity = function(o)
      local h = PROTO[o.name].w / 2
      local px, py = o.position.x or o.position[1], o.position.y or o.position[2]
      for _, e in ipairs(W.ents) do
        if e.valid and PROTO[e.name].type ~= "resource" then
          local b = box(e)
          if b.left_top.x < px + h - 1e-9 and b.right_bottom.x > px - h + 1e-9 and b.left_top.y < py + h - 1e-9 and b.right_bottom.y > py - h + 1e-9 then return false end
        end
      end
      return true
    end,
    create_entity = function(o)
      local px, py = o.position.x or o.position[1], o.position.y or o.position[2]
      return W.add(o.name, px, py, o.direction or 0, { force = o.force, born = game.tick })
    end,
  }
  return W
end
Mo.world = world

---------------------------------------------------------------------------------------------------
-- Module chargé dans un environnement neuf (dépendances factices) ; `text` : source (mutants)
---------------------------------------------------------------------------------------------------
function Mo.fresh(text, sliced, slice, build)
  local W = world()
  local env = { own = {}, stock = { ["electric-mining-drill"] = 4, ["small-electric-pole"] = 30, coal = 100, ["iron-plate"] = 200 }, board = {}, queue = {},
    timers = {} }
  local F
  local State = { sorted_keys = sorted_keys,
    own = function(e, fid, kind, oid) env.own[e.unit_number] = { f = fid, kind = kind, oid = oid } end,
    disown = function(u) env.own[u] = nil end,
    owner = function(u) return env.own[u] end,
    faction = function(id) return F and F.id == id and F or nil end }
  local Stock = {
    count = function(_, n) return env.stock[n] or 0 end,
    remove = function(_, n, c) local h = env.stock[n] or 0; local t = math.min(h, c); env.stock[n] = h - t; return t end,
    insert = function(_, n, c) env.stock[n] = (env.stock[n] or 0) + c; return c end,
    inventories = function() return { { valid = true, insert = function(st) env.stock[st.name] = (env.stock[st.name] or 0) + st.count; return st.count end } } end,
  }
  local Board = { add = function(_, tasks, tick)
    for _, t in ipairs(tasks) do env.board[#env.board + 1] = string.format("%s %s %d @%d", t.key, t.item, t.count, tick) end
    return #tasks
  end }
  local Scheduler = {
    define_timer = function(name, h) env.timers[name] = h end,
    after = function(d, name, p) env.queue[#env.queue + 1] = { at = game.tick + d, name = name, p = p } end,
  }
  local stubs = {
    ["script.faction.state"] = State, ["script.team.board"] = Board, ["script.team.stock"] = Stock,
    ["script.faction.outposts"] = { reserved = function() return false end },
    ["script.team.melange"] = { zone_at = function() return "ok", {} end },
    ["script.team.sante_centrale"] = { committed = function() return 0 end },
    ["script.core.scheduler"] = Scheduler,
  }
  local saved = {}
  for k, v in pairs(stubs) do saved[k] = package.loaded[k]; package.loaded[k] = v end
  _G.game = { tick = 0, entity_prototypes = PROTO, item_prototypes = PROTO }
  _G.defines = { inventory = { fuel = "fuel", furnace_source = 2, furnace_result = 3, chest = 4 }, flow_precision_index = { one_minute = 1 },
    entity_status = { working = 1, no_power = 2, low_power = 3, disabled_by_script = 4, no_fuel = 5 } }
  _G.log = function(s) W.logs[#W.logs + 1] = s end
  local chunk = assert(load(text, "=" .. SRC_PATH))
  local Swap = chunk()
  for k, v in pairs(saved) do package.loaded[k] = v end
  Swap.SLICED = sliced
  if slice then Swap.SLICE = slice end
  Swap.RETRY = T.swap.every + 1 -- refus d'une passe encore en cours au départ de la suivante, fini une tranche plus tard : lu à pass.t0
  local hq, outposts, src = build(W)
  F = { id = "player", key = "player", force = "player", hq = hq, hq_pos = { x = 20.5, y = 60.5 }, outposts = outposts, team = {}, started = 0 }
  env.own[src.unit_number] = { f = "player", kind = "pole" }
  Swap.book_of = function() return env.book end
  env.book = { handcraftable = function() return true end, plan = function() return { raw = {}, crafts = {}, uses = {} } end }
  return { W = W, env = env, f = F, Swap = Swap, game = _G.game, log = _G.log }
end

--- Le module lit `game` et `log` globaux à l'appel : chaque essai rend les siens avant de jouer.
function Mo.use(R) _G.game, _G.log = R.game, R.log end

--- Joue `passes` passes (une pensée toutes les T.swap.every ticks ; entre deux, les minuteries des tranches au tick suivant).
function Mo.play(R, passes)
  Mo.use(R)
  local tick, slices = 0, 0
  for k = 1, passes do
    tick = (k - 1) * T.swap.every
    game.tick = tick
    local free = {}
    for _, n in ipairs(sorted_keys(R.env.stock)) do free[n] = R.env.stock[n] end
    R.Swap.think(R.f, R.W.surface, R.env.book, free, tick)
    local guard = 0
    while #R.env.queue > 0 and guard < 1000 do
      guard = guard + 1
      local q = table.remove(R.env.queue, 1)
      game.tick = q.at
      R.env.timers[q.name](q.p, q.at)
      if R.hook then R.hook(R) end
      slices = slices + 1
      if R.f.swap and R.f.swap.pass then
        -- la passe gardée dans global ne contient aucune fonction
        local function nofn(v, seen)
          if type(v) == "function" then return false end
          if type(v) ~= "table" or seen[v] or getmetatable(v) then return true end
          seen[v] = true
          for kk, x in pairs(v) do if not nofn(kk, seen) or not nofn(x, seen) then return false end end
          return true
        end
        if not nofn(R.f.swap.pass, {}) then R.fn_in_global = true end
      end
    end
    if R.f.swap and R.f.swap.pass then R.stuck = true end
  end
  return slices
end

--- Monde de départ : avant-poste 1 (16 paires serrées sur du fer, 2 rangées), avant-poste 2 (3 paires loin de tout poteau), source alimentée.
function Mo.build_fer(W)
  for x = 0, 44 do for y = 4, 20 do W.add("iron-ore", x + 0.5, y + 0.5, 0) end end
  for x = 100, 140 do for y = 4, 16 do W.add("iron-ore", x + 0.5, y + 0.5, 0) end end
  local hq = W.add("fo-team-chest", 20.5, 60.5, 0, { force = "player" })
  hq.surface = W.surface
  local function outpost(id, pos, pairs_at)
    local o = { id = id, kind = "iron", pos = pos, drill_list = {}, sinks = {}, drills = 0 }
    for _, q in ipairs(pairs_at) do
      local d = W.add("burner-mining-drill", q[1], q[2], 0, { force = "player" })
      d.inv.fuel.coal = 5
      local s = W.add("stone-furnace", q[1] - 1, q[2] - 2, 0, { force = "player" })
      s.inv[2]["iron-ore"] = 7
      s.inv[3]["iron-plate"] = 11
      o.drill_list[#o.drill_list + 1] = d
      o.sinks[#o.sinks + 1] = s
      o.drills = o.drills + 1
    end
    return o
  end
  local row = {}
  for i = 0, 7 do row[#row + 1] = { 10 + 2 * i, 10 } end
  for i = 0, 7 do row[#row + 1] = { 10 + 2 * i, 14 } end
  local o1 = outpost(1, { x = 17, y = 12 }, row)
  local o2 = outpost(2, { x = 120, y = 10 }, { { 110, 10 }, { 114, 10 }, { 118, 10 } })
  local src = W.add("small-electric-pole", 20.5, 30.5, 0, { force = "player", source = true })
  return hq, { [1] = o1, [2] = o2 }, src
end

--- Image de l'état : global (f.swap sans la passe, avant-postes), propriétaires, stock, tâches, monde, fils, journal.
function Mo.snapshot(R)
  local out = {}
  local function put(s) out[#out + 1] = s end
  local function ser(v, depth)
    depth = depth or 0
    if type(v) ~= "table" then return tostring(v) end
    if v.unit_number and v.position then return string.format("E%d", v.unit_number) end
    local parts = {}
    for _, k in ipairs(sorted_keys(v)) do if not (depth == 0 and k == "pass") then parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k], depth + 1) end end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  put("swap " .. ser(R.f.swap or {}))
  for _, oid in ipairs(sorted_keys(R.f.outposts)) do
    local o = R.f.outposts[oid]
    local dl, sl, pl = {}, {}, {}
    for _, d in ipairs(o.drill_list) do dl[#dl + 1] = (d.valid and "" or "x") .. d.unit_number end
    for _, s in ipairs(o.sinks) do sl[#sl + 1] = (s.valid and "" or "x") .. s.unit_number end
    for _, p in ipairs(o.swap_poles or {}) do pl[#pl + 1] = p.unit_number end
    put(string.format("o%d drills=%d [%s] sinks [%s] poles [%s]", oid, o.drills, table.concat(dl, " "), table.concat(sl, " "), table.concat(pl, " ")))
  end
  put("own " .. ser(R.env.own))
  put("stock " .. ser(R.env.stock))
  put("board " .. table.concat(R.env.board, " | "))
  for _, e in ipairs(R.W.ents) do
    if e.name ~= "iron-ore" then
      local w = {}
      for _, n in ipairs(e.wires) do if n.valid then w[#w + 1] = n.unit_number end end
      table.sort(w)
      put(string.format("e%d %s %.2f %.2f %d %s [%s]", e.unit_number, e.name, e.position.x, e.position.y, e.direction, tostring(e.valid), table.concat(w, " ")))
    end
  end
  for _, l in ipairs(R.W.logs) do put("log " .. l) end
  return out
end

function Mo.compare(a, b)
  local n = math.max(#a, #b)
  for i = 1, n do if a[i] ~= b[i] then return false, string.format("ligne %d :\n  bloc    %s\n  tranches %s", i, tostring(a[i]), tostring(b[i])) end end
  return true
end

return Mo
