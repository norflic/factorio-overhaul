--[[
  Lot POULS (7/11, fo-logs\2026-11-07_POULS\CRITERES.md) : le relevé du réseau par BANDES (script/team/reseau_vivant.lua) rend ce que
  rendait le relevé d'un bloc (net_read, recopié ici tel qu'en 0.6.58, 0e340b99 : ref_net_read). Le JETON du tick (script/team/pouls_jeton.lua)
  ne laisse jamais une bande et un début de raccord (script/team/raccord.lua), ni deux débuts, sur le même tick.
  Monde simulé : la recherche par zone rend ce qui TOUCHE la zone (intervalles fermés, F96), avec de vraies boîtes (1 × 1 à 3 × 5).
    P1. Mode bloc (Rv.BANDS_PER_PULSE = math.huge) contre l'ancien chemin (sans boîte) : global de l'équipe et journal identiques, à
        chaque passe du pouls, sur une partie où la centrale perd des pièces et où des îlots apparaissent.
    P2. 200 mondes tirés d'une graine (entités sur les bords des bandes et à cheval, réseaux vivants dont le générateur est dans une
        autre bande, îlots, sans réseau, sans source électrique, chantiers) : par bandes (1 à 3 lignes de chunks, 1, 2 ou 3 bandes par
        passe) = d'un bloc (îlots, sans poteau, réseaux des îlots, réseaux vivants).
    P3. Par bandes (1 bande par passe), partie entière : à chaque fin de relevé, l'état est celui du relevé d'un bloc (monde figé pendant
        le relevé) ; décisions du journal identiques à P1, au décalage de quelques passes près.
    P4. Sauvegarde (copie de l'état) au milieu d'un relevé : même fin que la partie continue.
    P5. Jeton : 3 équipes dont les horloges tombent au même tick ; jamais deux relevés lourds sur un tick ; chaque raccord finit par
        partir.
    P6. Boîte des chunks (script/team/boite_chunks.lua) : relevée en entier à la première demande, puis tenue par on_chunk_generated.
    Mutants (texte de la source changé, par package.preload) : ils DOIVENT tous être vus.
  Usage : lua5.2 tests/pouls_test.lua
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 print("OK     " .. msg) else fail_n = fail_n + 1 print("ECHEC : " .. msg) end
end

local logs = {}
log = function(s) logs[#logs + 1] = s end
defines = defines or {}
defines.events = defines.events or { on_chunk_generated = 34 }
local PROTO = { ["small-electric-pole"] = { max_wire_distance = 7.5, supply_area_distance = 2.5 } }
game = { entity_prototypes = PROTO, tick = 0 }

---------------------------------------------------------------------------------------------------
-- Monde simulé (recherche par zone : boîte qui TOUCHE la zone, comme le moteur, F96)
---------------------------------------------------------------------------------------------------
local function new_world() return { ents = {}, enemies = {}, chunks = {} } end

local function add(w, e)
  e.valid = true
  e.force = e.force or "fo-test"
  local hw, hh = e.hw or 0.5, e.hh or 0.5
  e.box = { e.position.x - hw, e.position.y - hh, e.position.x + hw, e.position.y + hh }
  e.prototype = { electric_energy_source_prototype = e.consumer and {} or nil }
  w.ents[#w.ents + 1] = e
  return e
end

local function has_type(t, ty)
  if t == nil then return true end
  if type(t) == "string" then return t == ty end
  for _, x in ipairs(t) do if x == ty then return true end end
  return false
end

local function surface_of(w)
  return {
    index = 1, valid = true,
    find_entities_filtered = function(q)
      w.searches = (w.searches or 0) + 1
      local out = {}
      for _, e in ipairs(w.ents) do
        if e.valid and (q.force == nil or e.force == q.force) and has_type(q.type, e.type) then
          local ok = true
          if q.position then
            local dx, dy = e.position.x - (q.position[1] or q.position.x), e.position.y - (q.position[2] or q.position.y)
            ok = dx * dx + dy * dy <= (q.radius or 0) ^ 2 + 1e-9
          end
          if q.area then
            local a = q.area
            ok = ok and e.box[1] <= a[2][1] and e.box[3] >= a[1][1] and e.box[2] <= a[2][2] and e.box[4] >= a[1][2]
          end
          if ok then out[#out + 1] = e end
        end
      end
      return out
    end,
    get_chunks = function()
      local i = 0
      return function()
        i = i + 1
        local c = w.chunks[i]
        if c then return { x = c[1], y = c[2], area = { { c[1] * 32, c[2] * 32 }, { c[1] * 32 + 32, c[2] * 32 + 32 } } } end
      end
    end,
    find_nearest_enemy = function(q)
      local px, py = q.position.x or q.position[1], q.position.y or q.position[2]
      for _, en in ipairs(w.enemies) do
        if en.valid and (px - en.position.x) ^ 2 + (py - en.position.y) ^ 2 <= q.max_distance ^ 2 then return en end
      end
      return nil
    end,
  }
end

--- Chunks générés : tous ceux qui portent une entité (position), plus `extra`.
local function chunks_for(w, extra)
  local seen, list = {}, {}
  local function add_c(cx, cy)
    local k = cx .. ":" .. cy
    if not seen[k] then seen[k] = true; list[#list + 1] = { cx, cy } end
  end
  for _, e in ipairs(w.ents) do add_c(math.floor(e.position.x / 32), math.floor(e.position.y / 32)) end
  for _, c in ipairs(extra or {}) do add_c(c[1], c[2]) end
  w.chunks = list
end

local function box_of(w)
  local b
  for _, c in ipairs(w.chunks) do
    if b then
      b.x0, b.x1 = math.min(b.x0, c[1]), math.max(b.x1, c[1])
      b.y0, b.y1 = math.min(b.y0, c[2]), math.max(b.y1, c[2])
    else
      b = { x0 = c[1], y0 = c[2], x1 = c[1], y1 = c[2] }
    end
  end
  return b
end

---------------------------------------------------------------------------------------------------
-- La version d'AVANT (0.6.58, 0e340b99), recopiée : net_read et in_construction
---------------------------------------------------------------------------------------------------
local S = require("shared.team.reseau_sante")
local ELEC_TYPES = { "mining-drill", "assembling-machine", "lab", "inserter", "furnace" }
local function ref_in_construction(b, x, y)
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and S.exempts(q.state, q.retry_at) then
      for k = 1, 16 do
        local pt = q.parts and q.parts[k]
        if pt and pt.ox and x >= pt.ox - 3 and x <= pt.ox + (pt.w or 0) + 3 and y >= pt.oy - 3 and y <= pt.oy + (pt.h or 0) + 3 then
          return true
        end
      end
    end
  end
  return false
end
local function ref_net_read(f, surface, b)
  local gnets = {}
  for _, g in ipairs(surface.find_entities_filtered({ force = f.force, type = "generator" })) do
    local id = g.electric_network_id
    if id then gnets[id] = true end
  end
  local out = { islands = 0, uncovered = 0, nets = {}, live = gnets }
  for _, e in ipairs(surface.find_entities_filtered({ force = f.force, type = ELEC_TYPES })) do
    local id = e.electric_network_id
    if not (id and gnets[id]) and e.prototype.electric_energy_source_prototype
      and not ref_in_construction(b, e.position.x, e.position.y) then
      if id then out.islands = out.islands + 1; out.nets[id] = true else out.uncovered = out.uncovered + 1 end
    end
  end
  return out
end

local function keys_str(t)
  local k = {}
  for x in pairs(t) do k[#k + 1] = x end
  table.sort(k)
  return table.concat(k, ",")
end
local function nr_str(nr)
  return string.format("islands=%d uncovered=%d nets=[%s] live=[%s]", nr.islands, nr.uncovered, keys_str(nr.nets), keys_str(nr.live))
end

local function ser(v, out)
  out = out or {}
  local t = type(v)
  if t == "table" then
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
      if k ~= "nr_job" then
        out[#out + 1] = tostring(k) .. "="
        ser(v[k], out)
        out[#out + 1] = ","
      end
    end
    out[#out + 1] = "}"
  else
    out[#out + 1] = tostring(v)
  end
  return out
end
local function s(v) return table.concat(ser(v)) end
local function deep(v)
  if type(v) ~= "table" then return v end
  if v.box and v.position then return v end -- entité du monde simulé : une sauvegarde garde la RÉFÉRENCE (relevé par bandes, P4)
  local c = {}
  for k, x in pairs(v) do c[k] = deep(x) end
  return c
end

---------------------------------------------------------------------------------------------------
-- Chargement des modules (source éventuellement changée : mutant)
---------------------------------------------------------------------------------------------------
local function mutated(path, subs)
  local fh = assert(io.open(path, "rb"))
  local src = fh:read("*a")
  fh:close()
  for _, x in ipairs(subs or {}) do
    local a, b = src:find(x[1], 1, true)
    assert(a, "mutant : texte absent de " .. path .. " : " .. x[1])
    assert(not src:find(x[1], b + 1, true), "mutant : texte present plusieurs fois : " .. x[1])
    src = src:sub(1, a - 1) .. x[2] .. src:sub(b + 1)
  end
  return src
end

local events = {}
local store = {}
package.loaded["script.core.events"] = { on = function(id, fn) events[id] = fn end }
package.loaded["script.core.storage"] = {
  declare = function(name, init) store[name] = store[name] or init() end,
  ns = function(name) return store[name] end,
}

local function load_mods(mut)
  for _, m in ipairs({ "script.team.reseau_vivant", "script.team.raccord", "script.team.pouls_jeton", "script.team.boite_chunks" }) do
    package.loaded[m] = nil
    package.preload[m] = nil
  end
  if mut then
    local src = mutated(mut[2], mut[3])
    package.preload[mut[1]] = function(name) return assert(load(src, "=" .. mut[2]))(name) end
  end
  store = {}
  return require("script.team.reseau_vivant"), require("script.team.raccord"), require("script.team.pouls_jeton"),
    require("script.team.boite_chunks")
end

---------------------------------------------------------------------------------------------------
-- Équipe : centrale (projet 1, fini), un module fini (projet 2), un chantier (projet 3) dont l'emprise couvre des consommateurs
---------------------------------------------------------------------------------------------------
local function ent(name, type_, x, y, o)
  o = o or {}
  local e = { name = name, type = type_, position = { x = x, y = y }, consumer = o.consumer, electric_network_id = o.net,
    hw = o.hw, hh = o.hh, force = o.force, energy_generated_last_tick = o.kw and (o.kw * 1000 / 60) or 0 }
  if type_ == "boiler" then
    e.burner = { remaining_burning_fuel = 1 }
    e.get_fuel_inventory = function() return { is_empty = function() return false end } end
  end
  return e
end

local function team(w, key, force, ox, oy)
  local ents1 = {
    { name = "boiler", x = ox + 10, y = oy + 10, built = true }, { name = "steam-engine", x = ox + 10, y = oy + 2, built = true },
    { name = "offshore-pump", x = ox + 10, y = oy + 6, built = true }, { name = "small-electric-pole", x = ox + 4, y = oy, built = true },
  }
  local ents2 = { { name = "small-electric-pole", x = ox + 10, y = oy, built = true }, { name = "small-electric-pole", x = ox + 13, y = oy, built = true } }
  local f = { key = key, force = force, build = { order = { 1, 2, 3 }, plant = 1, opts = {}, occ = {}, projects = {
    [1] = { id = 1, state = "fini", ents = ents1, parts = { { ox = ox + 8, oy = oy + 4, w = 5, h = 14 } } },
    [2] = { id = 2, state = "fini", ents = ents2, parts = {} },
    [3] = { id = 3, state = "chantier", ents = {}, parts = { { ox = ox + 60, oy = oy + 60, w = 10, h = 10 } } },
  } } }
  local parts = {}
  parts.boiler = add(w, ent("boiler", "boiler", ox + 10, oy + 10, { force = force, hw = 1.5, hh = 1 }))
  parts.engine = add(w, ent("steam-engine", "generator", ox + 10, oy + 2, { net = 1, kw = 900, force = force, hw = 1.5, hh = 2.5 }))
  add(w, ent("offshore-pump", "offshore-pump", ox + 10, oy + 6, { force = force }))
  for _, x in ipairs({ ox + 4, ox + 10, ox + 13 }) do add(w, ent("small-electric-pole", "electric-pole", x, oy, { net = 1, force = force })) end
  return f, parts
end

local api_old = { cancel = function(f, id) f.build.projects[id].state = "refuse"; return true end, plant = function() return nil end }

---------------------------------------------------------------------------------------------------
-- Mondes tirés d'une graine (P2)
---------------------------------------------------------------------------------------------------
local function lcg(seed)
  local st = seed
  return function(n)
    st = (st * 1103515245 + 12345) % 2147483648
    return math.floor(st / 65536) % n + 1
  end
end

local SIZES = { { "inserter", "inserter", 0.15, 0.15 }, { "furnace", "electric-furnace", 1.5, 1.5 }, { "assembling-machine", "assembler", 1.5, 1.5 },
  { "mining-drill", "drill", 1.5, 1.5 }, { "lab", "lab", 1.5, 1.5 } }

local function random_world(seed, f_force)
  local r = lcg(seed)
  local w = new_world()
  local f, _ = team(w, "rnd", f_force, 0, 0)
  local nlive = r(4)
  for k = 1, nlive do
    -- générateur d'un réseau vivant (2 à 5), parfois loin, parfois sur un bord de bande
    local y = (r(9) - 5) * 32 + ({ 0, 0.5, 31.5, 16 })[r(4)]
    add(w, ent("steam-engine", "generator", r(200) - 100 + 0.5, y, { net = k + 1, kw = 900, force = f_force, hw = 1.5, hh = 2.5 }))
  end
  local n = 20 + r(80)
  for _ = 1, n do
    local sz = SIZES[r(#SIZES)]
    local cy = r(9) - 5
    local y = cy * 32 + ({ 0, 0.5, 1.5, 15.5, 30.5, 31.5, 32, 16 })[r(8)]
    local x = r(300) - 150 + ({ 0, 0.5 })[r(2)]
    local net
    local pick = r(10)
    if pick <= 4 then net = r(nlive) + 1 elseif pick <= 7 then net = 10 + r(5) elseif pick <= 8 then net = 1 end
    add(w, ent(sz[2], sz[1], x, y, { net = net, consumer = r(6) > 1, force = f_force, hw = sz[3], hh = sz[4] }))
  end
  -- chantier qui couvre une partie des consommateurs ; une autre force au même endroit (jamais comptée)
  f.build.projects[3].parts[1] = { ox = r(200) - 100, oy = r(200) - 100, w = 20 + r(30), h = 20 + r(30) }
  for _ = 1, 10 do add(w, ent("assembler", "assembling-machine", r(300) - 150, r(200) - 100, { net = 99, consumer = true, force = "autre" })) end
  chunks_for(w, { { -8, -8 } }) -- (lignes vides en haut ; la dernière ligne porte des entités : le mutant m2 se voit)
  return w, f
end

---------------------------------------------------------------------------------------------------
-- P2 : par bandes = d'un bloc
---------------------------------------------------------------------------------------------------
local function banded(Rv, f, surface, box, per)
  local j = Rv.bandes.new(box)
  local guard = 0
  repeat
    local done = false
    for _ = 1, per do
      done = Rv.bandes.band(f, surface, j)
      if done then break end
    end
    guard = guard + 1
  until done or guard > 10000
  return Rv.bandes.finish(f.build, j), j
end

local function p2(Rv, worlds)
  local diffs, runs, first = 0, 0, nil
  local saved_band = Rv.BAND
  for seed = 1, worlds do
    local w, f = random_world(seed, "fo-test")
    local sfc = surface_of(w)
    local want = nr_str(ref_net_read(f, sfc, f.build))
    for _, band in ipairs({ 1, 2, 3 }) do
      Rv.BAND = band
      for _, per in ipairs({ 1, 2, 3 }) do
        local got = nr_str((banded(Rv, f, sfc, box_of(w), per)))
        runs = runs + 1
        if got ~= want then
          diffs = diffs + 1
          first = first or string.format("graine %d, bande %d, %d par passe : par bandes %s ; d'un bloc %s", seed, band, per, got, want)
        end
      end
    end
  end
  Rv.BAND = saved_band
  return diffs, runs, first
end

---------------------------------------------------------------------------------------------------
-- P1, P3, P4 : parties du pouls (une passe toutes les 5 ticks)
---------------------------------------------------------------------------------------------------
--- Partie : centrale à (0, 0) ; îlots à partir de la minute 5 ; machine perdue à la minute 14. mode : "old" (sans boîte), "bloc", "bandes".
local function game_run(Rv, mode, opts)
  opts = opts or {}
  logs = {}
  local w = new_world()
  local f, parts = team(w, "pouls", "fo-test", 0, 0)
  -- consommateurs du réseau vivant, sur plusieurs lignes de chunks, dont des bords
  for k = 0, 40 do
    add(w, ent("assembler", "assembling-machine", -60 + k * 3, -100 + k * 6 + (k % 3 == 0 and 0 or 0.5), { net = 1, consumer = true, hw = 1.5, hh = 1.5 }))
  end
  chunks_for(w, { { -6, -6 }, { 6, 6 } })
  local sfc = surface_of(w)
  local box = box_of(w)
  local Jeton = require("script.team.pouls_jeton")
  Jeton.reset()
  local api = { cancel = api_old.cancel, plant = api_old.plant }
  if mode ~= "old" then
    api.box = function() return box end
    api.jeton = Jeton
  end
  Rv.BANDS_PER_PULSE = (mode == "bandes") and 1 or math.huge
  local trace, ends = {}, {}
  local saved
  for t = 0, 30 * 3600, 5 do
    game.tick = t
    -- changements du monde (seulement hors relevé en cours, pour garder le monde figé pendant un relevé par bandes)
    local idle = not (f.build.sante and f.build.sante.nr_job)
    if t >= 5 * 3600 and not w.islands_added and idle then
      w.islands_added = true
      for k = 0, 9 do add(w, ent("lab", "lab", 40 + k * 4, 70 + (k % 2) * 32, { net = 7, consumer = true, hw = 1.5, hh = 1.5 })) end
      for k = 0, 3 do add(w, ent("inserter", "inserter", -40 + k, 33 + k * 0.5, { consumer = true, hw = 0.15, hh = 0.15 })) end
      chunks_for(w, { { -6, -6 }, { 6, 6 } })
    end
    if t >= 14 * 3600 and not w.lost and idle then
      w.lost = true
      parts.engine.valid = false
    end
    local had_job = f.build.sante and f.build.sante.nr_job
    Rv.step(api, f, sfc, t)
    local sv = f.build.sante
    if had_job and sv and not sv.nr_job then
      -- fin d'un relevé par bandes : l'état est celui du relevé d'un bloc, sur ce monde figé
      local nr = ref_net_read(f, sfc, f.build)
      ends[#ends + 1] = (sv.islands == nr.islands and sv.uncovered == nr.uncovered)
    end
    if opts.reload_at and t == opts.reload_at then
      -- sauvegarde puis chargement : l'état de l'équipe recopié (tables neuves), la partie continue sur la copie
      saved = f.build.sante and f.build.sante.nr_job ~= nil
      f.build = deep(f.build)
    end
    trace[#trace + 1] = s(f.build.sante)
  end
  return { trace = trace, logs = logs, ends = ends, f = f, mid_job = saved }
end

local function strip_time(l) return (l:gsub(" a %d+%.%d min$", "")) end

local function p1_p3(Rv)
  local a = game_run(Rv, "old")
  local b = game_run(Rv, "bloc")
  local same_trace = #a.trace == #b.trace
  for i = 1, #a.trace do if a.trace[i] ~= b.trace[i] then same_trace = false break end end
  local same_logs = #a.logs == #b.logs
  for i = 1, #a.logs do if a.logs[i] ~= b.logs[i] then same_logs = false break end end
  local c = game_run(Rv, "bandes")
  local ends_ok = #c.ends > 0
  for _, x in ipairs(c.ends) do if not x then ends_ok = false end end
  -- (décalage de quelques passes : une ligne de l'ancien chemin à la dernière minute peut tomber après la fin de la partie par bandes ;
  -- seules les lignes d'avant la 29e minute sont comparées)
  local function before29(l)
    local m = tonumber(l:match(" a (%d+%.%d) min$") or "0")
    return m < 29
  end
  local la, lc = {}, {}
  for _, l in ipairs(a.logs) do if before29(l) then la[#la + 1] = strip_time(l) end end
  for _, l in ipairs(c.logs) do if before29(l) then lc[#lc + 1] = strip_time(l) end end
  local same_decisions = table.concat(la, "\n") == table.concat(lc, "\n")
  return { a = a, b = b, c = c, same_trace = same_trace, same_logs = same_logs, ends_ok = ends_ok, same_decisions = same_decisions }
end

---------------------------------------------------------------------------------------------------
-- P5 : jeton, 3 équipes, réseau et raccord
---------------------------------------------------------------------------------------------------
local function p5(Rv, Ra, Jeton)
  logs = {}
  local w = new_world()
  local teams = {}
  for i = 1, 3 do
    local f = team(w, "e" .. i, "f" .. i, (i - 1) * 64, 0)
    for k = 0, 20 do add(w, ent("assembler", "assembling-machine", (i - 1) * 64 + k * 2, -60 + k * 9, { net = 1, consumer = true, force = "f" .. i, hw = 1.5, hh = 1.5 })) end
    teams[i] = f
  end
  chunks_for(w, { { -4, -4 }, { 8, 4 } })
  local sfc = surface_of(w)
  local box = box_of(w)
  Jeton.reset()
  Rv.BANDS_PER_PULSE = 1
  local per_tick = {}
  local function prof_for(tag)
    return { fstart = function(name)
      if name == "rv:bande" or name == "ra:debut" then
        local t = game.tick
        per_tick[t] = per_tick[t] or {}
        per_tick[t][#per_tick[t] + 1] = tag .. ":" .. name
      end
    end, fstop = function() end }
  end
  local starts, due = {}, {}
  for t = 0, 16 * 3600, 5 do
    game.tick = t
    for i, f in ipairs(teams) do
      local p = prof_for(f.key)
      Rv.step({ cancel = api_old.cancel, plant = api_old.plant, box = function() return box end, jeton = Jeton, prof = p }, f, sfc, t)
      local st = f.build.raccord
      local before = st and st.next
      Ra.step({ request = function() return nil end, prio = 50, champ_live = false, jeton = Jeton, prof = p }, f, sfc, t)
      st = f.build.raccord
      if st and before and st.next ~= before then
        starts[#starts + 1] = { team = i, t = t, due = before }
      end
    end
  end
  local clash, heavy_ticks = 0, 0
  for _, l in pairs(per_tick) do
    heavy_ticks = heavy_ticks + 1
    if #l > 1 then clash = clash + 1 end
  end
  local late = 0
  for _, x in ipairs(starts) do if x.t - x.due > 600 then late = late + 1 end end
  return { clash = clash, heavy_ticks = heavy_ticks, starts = #starts, late = late }
end

---------------------------------------------------------------------------------------------------
-- P6 : boîte des chunks
---------------------------------------------------------------------------------------------------
local function p6(Rv, Box)
  local w, f = random_world(7, "fo-test")
  local sfc = surface_of(w)
  local b0 = Box.get(sfc)
  local first = b0 and string.format("%d,%d,%d,%d", b0.x0, b0.y0, b0.x1, b0.y1)
  local want0 = box_of(w)
  local ok0 = first == string.format("%d,%d,%d,%d", want0.x0, want0.y0, want0.x1, want0.y1)
  -- un chunk neuf, loin, avec un consommateur sur un îlot
  add(w, ent("lab", "lab", 20 * 32 + 5, 15 * 32 + 5, { net = 55, consumer = true, force = "fo-test", hw = 1.5, hh = 1.5 }))
  w.chunks[#w.chunks + 1] = { 20, 15 }
  events[defines.events.on_chunk_generated]({ surface = sfc, position = { x = 20, y = 15 } })
  local b1 = Box.get(sfc)
  local got = nr_str((banded(Rv, f, sfc, b1, 1)))
  local want = nr_str(ref_net_read(f, sfc, f.build))
  return ok0, got == want, got, want
end

---------------------------------------------------------------------------------------------------
-- P7 (revue de la 0.6.59, point 2) : le moteur renumérote un réseau qui se coupe ou se joint, en plein relevé
---------------------------------------------------------------------------------------------------
--- Monde : générateur (réseau 1) en haut (ligne de chunks −3), consommateurs du même réseau en bas (lignes 1 et 2), un îlot vrai (réseau
--- 9). Bandes d'une ligne, une par passe. Après la bande `at` (0 : avant la première), `change` est appliqué au monde. Rend la fin du
--- relevé par bandes et net_read lu à la fin (même instant).
local function p7_case(Rv, at, change, gen_y, cons_y)
  local w = new_world()
  local f = team(w, "p7", "fo-p7", 2000, 2000) -- (la centrale de l'équipe, loin du relevé : son propre réseau 1 ne gêne pas)
  for _, e in ipairs(w.ents) do e.valid = false end -- monde du cas seul
  w.ents = {}
  local g = add(w, ent("steam-engine", "generator", 10.5, gen_y, { net = 1, kw = 900, force = "fo-p7", hw = 1.5, hh = 2.5 }))
  local cons = {}
  for k = 0, 5 do cons[#cons + 1] = add(w, ent("assembler", "assembling-machine", 4 + k * 4, cons_y + (k % 2) * 33, { net = 1, consumer = true, force = "fo-p7", hw = 1.5, hh = 1.5 })) end
  local isl = add(w, ent("lab", "lab", 60.5, cons_y, { net = 9, consumer = true, force = "fo-p7", hw = 1.5, hh = 1.5 }))
  chunks_for(w, { { -3, -3 }, { 3, 3 } })
  local sfc = surface_of(w)
  local saved = Rv.BAND
  Rv.BAND = 1
  local j = Rv.bandes.new(box_of(w))
  local n, done = 0, false
  if at == 0 then change(g, cons, isl) end
  repeat
    done = Rv.bandes.band(f, sfc, j)
    n = n + 1
    if n == at then change(g, cons, isl) end
  until done or n > 100
  Rv.BAND = saved
  local got = Rv.bandes.finish(f.build, j)
  return nr_str(got), nr_str(ref_net_read(f, sfc, f.build)), got
end

local function p7(Rv)
  local out = {}
  -- (a) jonction : le réseau 1 devient 2 (générateur lu AVANT, consommateurs APRÈS) ; aucun îlot de plus que le vrai (9)
  local function renum(g, cons) g.electric_network_id = 2; for _, c in ipairs(cons) do c.electric_network_id = 2 end end
  local a1, r1 = p7_case(Rv, 1, renum, -90, 40)
  out[#out + 1] = { "générateur lu, puis renumérotation, puis consommateurs", a1, r1 }
  -- (b) les consommateurs lus AVANT la renumérotation, le générateur APRÈS
  local a2, r2 = p7_case(Rv, 1, renum, 40, -90)
  out[#out + 1] = { "consommateurs lus, puis renumérotation, puis générateur", a2, r2 }
  -- (c) coupure vraie : les consommateurs passent sur un réseau 3 sans générateur (îlot vrai, à compter)
  local function cut(g, cons) for _, c in ipairs(cons) do c.electric_network_id = 3 end end
  local a3, r3 = p7_case(Rv, 1, cut, -90, 40)
  out[#out + 1] = { "coupure vraie après le générateur", a3, r3 }
  -- (d) une machine détruite pendant le relevé
  local function gone(g, cons) cons[1].valid = false end
  local a4, r4 = p7_case(Rv, 1, gone, 40, -90)
  out[#out + 1] = { "machine détruite pendant le relevé", a4, r4 }
  return out
end

---------------------------------------------------------------------------------------------------
-- P8 (revue de la 0.6.59, point 3) : jeton équitable, 4 factions et votre équipe (appelée la dernière) en relevés longs à la fois
---------------------------------------------------------------------------------------------------
--- Rend, pour chaque demandeur, la plus longue suite de refus ET le plus grand nombre de demandeurs d'un même tick pendant cette suite ;
--- et le nombre de bandes faites par équipe.
local function p8(Rv, Ra, Jeton)
  logs = {}
  local w = new_world()
  local teams = {}
  local keys = { "f1", "f2", "f3", "f4", "player" }
  for i, key in ipairs(keys) do
    local force = "p8-" .. key
    local f = team(w, key, force, (i - 1) * 96, 0)
    for k = 0, 30 do add(w, ent("assembler", "assembling-machine", (i - 1) * 96 + (k % 8) * 4, -300 + k * 20, { net = 1, consumer = true, force = force, hw = 1.5, hh = 1.5 })) end
    teams[i] = f
  end
  chunks_for(w, { { -10, -10 }, { 16, 8 } })
  local sfc = surface_of(w)
  local box = box_of(w)
  Jeton.reset()
  local saved_band = Rv.BAND
  Rv.BAND, Rv.BANDS_PER_PULSE = 1, 1
  local asks = {} -- [tick] = { [who] = vrai/faux }
  local J = { take = function(t, who)
    local r = Jeton.take(t, who)
    asks[t] = asks[t] or {}
    asks[t][who] = r
    return r
  end }
  local bands = {}
  for t = 0, 4 * 3600, 5 do
    game.tick = t
    for _, f in ipairs(teams) do
      local p = { fstart = function(name) if name == "rv:bande" then bands[f.key] = (bands[f.key] or 0) + 1 end end, fstop = function() end }
      Rv.step({ cancel = api_old.cancel, plant = api_old.plant, box = function() return box end, jeton = J, prof = p }, f, sfc, t)
      Ra.step({ request = function() return nil end, prio = 50, champ_live = false, jeton = J, prof = p }, f, sfc, t)
    end
  end
  Rv.BAND = saved_band
  -- suites de refus par demandeur (demandes à des pouls successifs)
  local tl = {}
  for t in pairs(asks) do tl[#tl + 1] = t end
  table.sort(tl)
  local worst = {} -- [who] = { len, k }
  local run = {}
  for _, t in ipairs(tl) do
    local n = 0
    for _ in pairs(asks[t]) do n = n + 1 end
    for who, r in pairs(asks[t]) do
      local cur = run[who]
      if r then
        run[who] = nil
      else
        if cur and cur.t == t - 5 then cur.len, cur.t, cur.k = cur.len + 1, t, math.max(cur.k, n) else cur = { len = 1, t = t, k = n } end
        run[who] = cur
        local wv = worst[who]
        if not wv or cur.len > wv.len then worst[who] = { len = cur.len, k = cur.k } end
      end
    end
  end
  return worst, bands
end

---------------------------------------------------------------------------------------------------
-- Jeu de preuves sur la source du jeu
---------------------------------------------------------------------------------------------------
local Rv, Ra, Jeton, Box = load_mods(nil)
local d2, runs2, first2 = p2(Rv, 200)
check(runs2 == 1800 and d2 == 0, string.format("P2 : 200 mondes × 9 réglages : par bandes = d'un bloc (%d écart(s) sur %d)%s", d2, runs2,
  first2 and (" ; premier : " .. first2) or ""))
local r13 = p1_p3(Rv)
check(r13.same_trace, "P1 : mode bloc (boîte connue, toutes les bandes à la passe) = ancien chemin : état de santé identique à chaque passe")
check(r13.same_logs and #r13.a.logs > 0, string.format("P1 : journal identique ligne à ligne (%d ligne(s))", #r13.a.logs))
check(r13.ends_ok, string.format("P3 : par bandes, chaque fin de relevé donne l'état du relevé d'un bloc (%d relevé(s))", #r13.c.ends))
check(r13.same_decisions, "P3 : par bandes, mêmes décisions au journal que l'ancien chemin (heures retirées)")
do
  -- P4 : sauvegarde au milieu d'un relevé par bandes (le relevé de la minute 2 commence au tick 7 200, 7 bandes)
  local c1 = game_run(Rv, "bandes")
  local c2 = game_run(Rv, "bandes", { reload_at = 7210 })
  local same = #c1.trace == #c2.trace
  for i = 1, #c1.trace do if c1.trace[i] ~= c2.trace[i] then same = false break end end
  local NL = string.char(10)
  check(c2.mid_job == true and same and table.concat(c1.logs, NL) == table.concat(c2.logs, NL),
    "P4 : copie de l'état prise au milieu d'un relevé (" .. tostring(c2.mid_job) .. ") : même suite, même journal que la partie continue")
end
local r5 = p5(Rv, Ra, Jeton)
check(r5.clash == 0 and r5.heavy_ticks > 0, string.format("P5 : jamais deux relevés lourds sur un tick (%d tick(s) lourd(s), %d en conflit)", r5.heavy_ticks,
  r5.clash))
check(r5.starts >= 30 and r5.late == 0, string.format("P5 : chaque raccord part (%d départs), au plus 600 ticks après son heure (%d en retard)", r5.starts,
  r5.late))
local ok6a, ok6b, g6, w6 = p6(Rv, Box)
check(ok6a, "P6 : boîte relevée en entier à la première demande (surface.get_chunks)")
check(ok6b, "P6 : chunk généré après : boîte agrandie, son consommateur compté (" .. g6 .. ")")
for _, c in ipairs(p7(Rv)) do
  check(c[2] == c[3], string.format("P7 : %s : fin du relevé par bandes = net_read lu à la fin (%s)%s", c[1], c[2],
    c[2] ~= c[3] and (" ; net_read : " .. c[3]) or ""))
end
local function p8_ok(worst, bands)
  local bad, txt = {}, {}
  local whos = {}
  for who in pairs(worst) do whos[#whos + 1] = who end
  table.sort(whos)
  for _, who in ipairs(whos) do
    local x = worst[who]
    txt[#txt + 1] = string.format("%s %d/%d", who, x.len, x.k - 1)
    if x.len > x.k - 1 then bad[#bad + 1] = who end
  end
  return #bad == 0 and #whos > 0, table.concat(txt, ", "), bad
end
do
  local worst, bands = p8(Rv, Ra, Jeton)
  local ok8, txt8 = p8_ok(worst, bands)
  check(ok8, "P8 : jeton équitable : plus longue attente de chaque demandeur <= demandeurs simultanés - 1 (attente/borne : " .. txt8 .. ")")
  check((bands.player or 0) > 0 and worst["player:rv"] ~= nil and worst["player:rv"].len <= worst["player:rv"].k - 1,
    string.format("P8 : votre équipe, appelée la dernière, n'est jamais affamée (%d bande(s) faites)", bands.player or 0))
end

---------------------------------------------------------------------------------------------------
-- Mutants
---------------------------------------------------------------------------------------------------
local MUT = {
  { "m1 intervalle fermé [y0, y1]", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { "if p.y >= top and p.y < bottom then", "if p.y >= top and p.y <= bottom then" } }, "p2" },
  { "m2 dernière ligne de chunks sautée", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { "y_end = box.y1 + 1", "y_end = box.y1" } }, "p2" },
  { "m3 bande d'un chunk de large", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { "{ { j.x0 * 32, top }, { j.x1 * 32, bottom } }", "{ { j.x0 * 32, top }, { (j.x0 + 1) * 32, bottom } }" } }, "p2" },
  { "m4 jeton ignoré par le raccord", "script.team.raccord", "script/team/raccord.lua",
    { { 'if api.jeton and not api.jeton.take(tick, (f.key or "player") .. ":ra") then return end', "if false then return end" } }, "p5" },
  { "m5 boîte non tenue à on_chunk_generated", "script.team.boite_chunks", "script/team/boite_chunks.lua",
    { { "if b then grow(b, e.position.x, e.position.y) end", "if false then grow(b, e.position.x, e.position.y) end" } }, "p6" },
  { "m6 jeton ignoré par le relevé du réseau", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { 'if api.jeton and not api.jeton.take(tick, (f.key or "player") .. ":rv") then return nil end', "if false then return nil end" } }, "p5" },
  { "m8 jeton à priorité fixe (file ignorée)", "script.team.pouls_jeton", "script/team/pouls_jeton.lua",
    { { "(s.q[1] ~= nil and s.q[1] ~= who)", "false" } }, "p8" },
  { "m7 réseaux des générateurs non relus à la fin (numéros des bandes)", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { "local out = { islands = 0, uncovered = 0, nets = {}, live = live }", "live = j.gn; local out = { islands = 0, uncovered = 0, nets = {}, live = live }" } }, "p7" },
}
for _, m in ipairs(MUT) do
  local Rvm, Ram, Jm, Bm = load_mods({ m[2], m[3], m[4] })
  local seen
  if m[5] == "p2" then
    local d = p2(Rvm, 60)
    seen = d > 0
  elseif m[5] == "p5" then
    seen = p5(Rvm, Ram, Jm).clash > 0
  elseif m[5] == "p8" then
    seen = not (p8_ok(p8(Rvm, Ram, Jm)))
  elseif m[5] == "p7" then
    seen = false
    for _, c in ipairs(p7(Rvm)) do if c[2] ~= c[3] then seen = true end end
  else
    local _, okb = p6(Rvm, Bm)
    seen = not okb
  end
  check(seen, "mutant " .. m[1] .. " : vu")
end

print(string.format("BILAN : %d OK%s", ok_n, fail_n > 0 and (", " .. fail_n .. " ECHEC(S)") or ""))
os.exit(fail_n == 0 and 0 or 1)
