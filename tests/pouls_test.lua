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
    P5. Jeton : 3 équipes dont les horloges tombent au même tick ; chaque raccord finit par partir. Lot LOURD (point 2) : au budget du
        tick (script/core/lourd.lua), tout relevé lourd tombe sur un tick où son demandeur est servi, plusieurs par tick sans dépasser le
        budget ; témoin J.COSTS = faux (règle de la 0.6.61) : jamais deux relevés lourds sur un tick.
    P14. Témoin d'identité (lot LOURD, point 2) : la partie de P8 avec le jeton de la 0.6.61 (tests/fixtures/pouls_jeton_0661.lua) et avec
        l'ordonnanceur à J.COSTS = faux : demandes, journal et fin identiques ; à budget infini : aucun refus, mêmes décisions et même fin.
    P15. Coût déclaré au jeton (Rv.cout, Ra.cout) = chunks vraiment relevés au pas suivant.
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
local inits, configs = {}, {}
package.loaded["script.core.events"] = { on = function(id, fn) events[id] = fn end,
  on_init = function(fn) inits[#inits + 1] = fn end, on_configuration_changed = function(fn) configs[#configs + 1] = fn end }
package.loaded["script.core.storage"] = {
  declare = function(name, init) store[name] = store[name] or init() end,
  ns = function(name) return store[name] end,
}

local function load_mods(mut)
  for _, m in ipairs({ "script.team.reseau_vivant", "script.team.raccord", "script.team.pouls_jeton", "script.team.boite_chunks",
    "script.core.lourd" }) do
    package.loaded[m] = nil
    package.preload[m] = nil
  end
  if mut then
    local src = mutated(mut[2], mut[3])
    package.preload[mut[1]] = function(name) return assert(load(src, "=" .. mut[2]))(name) end
  end
  store = {}
  inits, configs = {}, {}
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
  local saved_band, saved_cols = Rv.BAND, Rv.COLS
  for seed = 1, worlds do
    local w, f = random_world(seed, "fo-test")
    local sfc = surface_of(w)
    local want = nr_str(ref_net_read(f, sfc, f.build))
    for _, band in ipairs({ 1, 2, 3 }) do
      Rv.BAND = band
      -- lot LOURD (point 1 bis) : tranches de 1, 2, 3 chunks de large, et toute la largeur
      for _, cols in ipairs({ 1, 2, 3, math.huge }) do
        Rv.COLS = cols
        for _, per in ipairs({ 1, 2, 3 }) do
          local got = nr_str((banded(Rv, f, sfc, box_of(w), per)))
          runs = runs + 1
          if got ~= want then
            diffs = diffs + 1
            first = first or string.format("graine %d, bande %d, tranche %s, %d par passe : par bandes %s ; d'un bloc %s", seed, band,
              tostring(cols), per, got, want)
          end
        end
      end
    end
  end
  Rv.BAND, Rv.COLS = saved_band, saved_cols
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
      -- (lot LOURD : le début du raccord se fait par bandes, ra:bande ; à la dernière, ra:debut suit dans le MÊME tick, sous le même
      -- jeton : un travail lourd est compté par DEMANDEUR du jeton, « équipe:rv » ou « équipe:ra »)
      if name == "rv:bande" or name == "ra:debut" or name == "ra:bande" then
        local t = game.tick
        local who = tag .. ":" .. name:sub(1, 2)
        local l = per_tick[t] or {}
        per_tick[t] = l
        local seen = false
        for _, x in ipairs(l) do if x == who then seen = true end end
        if not seen then l[#l + 1] = who end
      end
    end, fstop = function() end }
  end
  -- lot LOURD (point 2) : jetons donnés, par tick : nombre, somme des coûts déclarés (comptés comme l'ordonnanceur), demandeurs servis
  local grants = {}
  local JW = { take = function(t, who, per, cost)
    local r = Jeton.take(t, who, per, cost)
    if r then
      local g = grants[t] or { n = 0, sum = 0, who = {} }
      grants[t] = g
      g.n = g.n + 1
      g.sum = g.sum + ((Jeton.COSTS and cost) or Jeton.BUDGET)
      g.who[who] = true
    end
    return r
  end }
  local starts, due = {}, {}
  for t = 0, 16 * 3600, 5 do
    game.tick = t
    for i, f in ipairs(teams) do
      local p = prof_for(f.key)
      Rv.step({ cancel = api_old.cancel, plant = api_old.plant, box = function() return box end, jeton = JW, prof = p }, f, sfc, t)
      local st = f.build.raccord
      local before = st and st.next
      Ra.step({ request = function() return nil end, prio = 50, champ_live = false, jeton = JW, prof = p, box = function() return box end }, f, sfc, t)
      st = f.build.raccord
      if st and before and st.next ~= before then
        starts[#starts + 1] = { team = i, t = t, due = before }
      end
    end
  end
  local clash, heavy_ticks, ungranted = 0, 0, 0
  for t, l in pairs(per_tick) do
    heavy_ticks = heavy_ticks + 1
    if #l > 1 then clash = clash + 1 end
    for _, who in ipairs(l) do if not (grants[t] and grants[t].who[who]) then ungranted = ungranted + 1 end end
  end
  local over, shared = 0, 0
  for _, g in pairs(grants) do
    if g.n > 1 then
      shared = shared + 1
      if g.sum > Jeton.BUDGET then over = over + 1 end
    end
  end
  local late = 0
  for _, x in ipairs(starts) do if x.t - x.due > 600 then late = late + 1 end end
  return { clash = clash, heavy_ticks = heavy_ticks, starts = #starts, late = late, ungranted = ungranted, over = over, shared = shared }
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
-- P12 (revue de la 0.6.59, point 4) : la centrale est lue et réparée PENDANT un relevé long du réseau
---------------------------------------------------------------------------------------------------
--- Une équipe, 301 lignes de chunks, une bande d'une ligne par passe : le relevé du NET_PERIOD (tick 7 200) dure 301 passes (1 505 ticks,
--- plus que Rv.PERIOD). La machine à vapeur est perdue au début du relevé. Rend le tick de la perte, celui de la repose décidée, et si le
--- relevé était encore en cours à la repose.
local function p12(Rv)
  logs = {}
  local w = new_world()
  local f, parts = team(w, "p12", "fo-test", 0, 0)
  for k = 0, 40 do add(w, ent("assembler", "assembling-machine", -60 + k * 3, -100 + k * 6, { net = 1, consumer = true, hw = 1.5, hh = 1.5 })) end
  chunks_for(w, { { -150, -150 }, { 150, 150 } })
  local sfc = surface_of(w)
  local box = box_of(w)
  local Jeton = require("script.team.pouls_jeton")
  Jeton.reset()
  local api = { cancel = api_old.cancel, plant = api_old.plant, box = function() return box end, jeton = Jeton }
  local saved = Rv.BAND
  Rv.BAND, Rv.BANDS_PER_PULSE = 1, 1
  local lost_at, fixed_at, during
  for t = 0, 4 * 3600, 5 do
    game.tick = t
    local sv = f.build.sante
    if not lost_at and sv and sv.nr_job and sv.nr_job.bands >= 5 then
      lost_at = t
      parts.engine.valid = false
    end
    local n0 = #logs
    Rv.step(api, f, sfc, t)
    if lost_at and not fixed_at then
      for i = n0 + 1, #logs do
        if logs[i]:find("centrale:", 1, true) and logs[i]:find("rouverte", 1, true) then
          fixed_at = t
          during = f.build.sante.nr_job ~= nil
        end
      end
    end
  end
  Rv.BAND = saved
  return lost_at, fixed_at, during
end

---------------------------------------------------------------------------------------------------
-- Lot LOURD (point 2, P14) : trace des demandes (tick, demandeur, réponse), journal et état final de chaque équipe, pour comparer deux
-- ordonnanceurs sur la même partie
---------------------------------------------------------------------------------------------------
local function capture(asks, teams)
  local tl = {}
  for t in pairs(asks) do tl[#tl + 1] = t end
  table.sort(tl)
  local tr = {}
  for _, t in ipairs(tl) do
    local ws = {}
    for who in pairs(asks[t]) do ws[#ws + 1] = who end
    table.sort(ws)
    for _, who in ipairs(ws) do tr[#tr + 1] = t .. ":" .. who .. "=" .. (asks[t][who] and "1" or "0") end
  end
  local finals = {}
  for _, f in ipairs(teams) do
    local sv, st = f.build.sante or {}, f.build.raccord or {}
    local n = st.n or {}
    finals[#finals + 1] = string.format("%s ilots %s sans %s demande %s sain %s perdus %s decisions %s ; raccord %s/%s/%s/%s/%s", f.key,
      tostring(sv.islands), tostring(sv.uncovered), tostring(sv.demand), tostring(sv.healthy), tostring(sv.lost_links),
      tostring(sv.decisions), tostring(n.demandes), tostring(n.finis), tostring(n.refuses), tostring(n.repares), tostring(n.fils))
  end
  local lg = {}
  for i, l in ipairs(logs) do lg[i] = l end
  return { trace = tr, logs = lg, finals = finals }
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
  local J = { take = function(t, who, per, cost)
    local r = Jeton.take(t, who, per, cost)
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
      Ra.step({ request = function() return nil end, prio = 50, champ_live = false, jeton = J, prof = p, box = function() return box end }, f, sfc, t)
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
  return worst, bands, capture(asks, teams)
end

---------------------------------------------------------------------------------------------------
-- P9 (revue de la 0.6.59, point 1) : les chemins lourds sous le jeton, « relier » sans relevé frais et fin du raccordement compris
---------------------------------------------------------------------------------------------------
--- 3 équipes : centrale finie à production NULLE (demande nominale 75 kW), un îlot vrai : « production nulle » confirmée, puis « relier »
--- (avec le relevé du NET_PERIOD, puis 5 min plus tard sans relevé frais). Toute recherche lourde (sur toute la surface, ou une bande de
--- toute la largeur) faite par Rv.step ou Ra.step d'une équipe X à un tick t, et toute fin du raccordement (ra:fin), DOIT tomber sur un
--- tick où le jeton est allé à X (« X:rv » ou « X:ra »).
local function p9(Rv, Ra, Jeton)
  logs = {}
  local w = new_world()
  local teams = {}
  for i = 1, 3 do
    local force = "p9-" .. i
    local f, parts = team(w, "q" .. i, force, (i - 1) * 96, 0)
    parts.engine.energy_generated_last_tick = 0
    local q2 = f.build.projects[2]
    q2.ents[#q2.ents + 1] = { name = "assembling-machine-1", x = (i - 1) * 96 + 20, y = 20, built = true }
    for k = 0, 5 do add(w, ent("lab", "lab", (i - 1) * 96 + 30 + k * 4, 90, { net = 70 + i, consumer = true, force = force, hw = 1.5, hh = 1.5 })) end
    for k = 0, 10 do add(w, ent("assembler", "assembling-machine", (i - 1) * 96 + k * 3, -200 + k * 30, { net = 1, consumer = true, force = force, hw = 1.5, hh = 1.5 })) end
    teams[i] = f
  end
  chunks_for(w, { { -8, -8 }, { 10, 6 } })
  local base = surface_of(w)
  local box = box_of(w)
  local width = (box.x1 - box.x0 + 1) * 32
  local cur = {}
  local heavy = {} -- { t, who }
  local sfc = setmetatable({ find_entities_filtered = function(q)
    local wide = (q.area == nil and q.position == nil) or (q.area and q.area[2][1] - q.area[1][1] >= width)
    if wide then heavy[#heavy + 1] = { t = game.tick, who = cur.who } end
    return base.find_entities_filtered(q)
  end }, { __index = base })
  Jeton.reset()
  local saved_band = Rv.BAND
  Rv.BAND, Rv.BANDS_PER_PULSE = 1, 1
  local grants, asks = {}, {}
  local J = { take = function(t, who, per, cost)
    local r = Jeton.take(t, who, per, cost)
    if r then grants[t] = grants[t] or {}; grants[t][who] = true end
    asks[t] = asks[t] or {}
    asks[t][who] = r
    return r
  end }
  local fins, deferred = {}, 0
  for t = 0, 20 * 3600, 5 do
    game.tick = t
    for _, f in ipairs(teams) do
      local p = { fstart = function(name) if name == "ra:fin" then fins[#fins + 1] = { t = t, who = f.key .. ":ra" } end end, fstop = function() end }
      cur.who = f.key .. ":rv"
      Rv.step({ cancel = api_old.cancel, plant = api_old.plant, box = function() return box end, jeton = J, prof = p }, f, sfc, t)
      if f.build.sante and f.build.sante.relier then deferred = deferred + 1 end
      cur.who = f.key .. ":ra"
      Ra.step({ request = function() return nil end, prio = 50, champ_live = false, jeton = J, prof = p, box = function() return box end }, f, sfc, t)
    end
  end
  Rv.BAND = saved_band
  local bad, first = 0, nil
  for _, h in ipairs(heavy) do
    if not (grants[h.t] and grants[h.t][h.who]) then
      bad = bad + 1
      first = first or string.format("tick %d, %s", h.t, tostring(h.who))
    end
  end
  local bad_fin = 0
  for _, x in ipairs(fins) do if not (grants[x.t] and grants[x.t][x.who]) then bad_fin = bad_fin + 1 end end
  local reliers = 0
  for _, l in ipairs(logs) do if l:find("reseau: production nulle", 1, true) then reliers = reliers + 1 end end
  return { heavy = #heavy, bad = bad, first = first, fins = #fins, bad_fin = bad_fin, deferred = deferred, reliers = reliers,
    cap = capture(asks, teams) }
end

---------------------------------------------------------------------------------------------------
-- P10 (revue de la 0.6.59, point 6) : boîte relevée au chargement, jamais au premier pouls
---------------------------------------------------------------------------------------------------
local function counted(sfc, idx)
  local n = { 0 }
  local inner = sfc.get_chunks
  sfc.get_chunks = function() n[1] = n[1] + 1; return inner() end
  sfc.index = idx
  return n
end

local function p10(Box)
  -- partie d'avant ce point (aucune boîte), puis chargement : on_configuration_changed
  local w1 = random_world(11, "fo-test")
  local s1 = surface_of(w1)
  local n1 = counted(s1, 1)
  game.surfaces = { [1] = s1 }
  store.boite_chunks = { by = {} }
  for _, fn in ipairs(configs) do fn({ mod_changes = {} }) end
  local at_load = n1[1]
  local b1 = Box.get(s1)
  local want1 = box_of(w1)
  local same1 = b1 and b1.x0 == want1.x0 and b1.y0 == want1.y0 and b1.x1 == want1.x1 and b1.y1 == want1.y1
  local after_get = n1[1] - at_load
  -- surface neuve après le chargement : ses chunks arrivent par on_chunk_generated seul
  local w2 = random_world(12, "fo-test")
  local s2 = surface_of(w2)
  local n2 = counted(s2, 2)
  game.surfaces[2] = s2
  for _, c in ipairs(w2.chunks) do events[defines.events.on_chunk_generated]({ surface = s2, position = { x = c[1], y = c[2] } }) end
  local b2 = Box.get(s2)
  local want2 = box_of(w2)
  local same2 = b2 and b2.x0 == want2.x0 and b2.y0 == want2.y0 and b2.x1 == want2.x1 and b2.y1 == want2.y1
  game.surfaces = nil
  return { at_load = at_load, after_get = after_get, same1 = same1, same2 = same2, n2 = n2[1] }
end

---------------------------------------------------------------------------------------------------
-- P11 (revue de la 0.6.59, point 7) : une équipe sans centrale finie ne prend jamais le jeton du raccordement
---------------------------------------------------------------------------------------------------
local function p11(Ra, Jeton)
  logs = {}
  local w = new_world()
  local fa = team(w, "sans", "p11-a", 0, 0)
  fa.build.projects[1].state = "chantier"
  local fb = team(w, "avec", "p11-b", 96, 0)
  chunks_for(w, { { -2, -2 }, { 4, 2 } })
  local sfc = surface_of(w)
  Jeton.reset()
  local got = {}
  local J = { take = function(t, who, per, cost)
    local r = Jeton.take(t, who, per, cost)
    if r then got[who] = (got[who] or 0) + 1 end
    return r
  end }
  for t = 0, 3 * 3600, 5 do
    game.tick = t
    for _, f in ipairs({ fa, fb }) do
      Ra.step({ request = function() return nil end, prio = 50, champ_live = false, jeton = J }, f, sfc, t)
    end
  end
  return got["sans:ra"] or 0, got["avec:ra"] or 0
end

---------------------------------------------------------------------------------------------------
-- P15 (lot LOURD, point 2) : le coût DÉCLARÉ au jeton (Rv.cout, Ra.cout) = les chunks que le pas suivant relève vraiment (somme des
-- zones passées à find_entities_filtered), à chaque pas, réglages variés, boîte de 76 × 8 chunks (bords coupés en largeur et en hauteur)
---------------------------------------------------------------------------------------------------
local function p15(Rv, Ra)
  logs = {}
  local w = new_world()
  local f = team(w, "c", "p15", 0, 0)
  chunks_for(w, { { -5, -3 }, { 70, 4 } })
  local base = surface_of(w)
  local box = box_of(w)
  local covered = 0
  local sfc = setmetatable({ find_entities_filtered = function(q)
    if q.area then covered = covered + (q.area[2][1] - q.area[1][1]) * (q.area[2][2] - q.area[1][2]) / 1024 end
    return base.find_entities_filtered(q)
  end }, { __index = base })
  local saved = { Rv.BAND, Rv.COLS, Rv.BANDS_PER_PULSE, Ra.BAND, Ra.BANDS_PER_PULSE }
  local bad, n, first = 0, 0, nil
  local function note(what, want, got)
    n = n + 1
    if want ~= got then
      bad = bad + 1
      first = first or string.format("%s : déclaré %s, relevé %s", what, tostring(want), tostring(got))
    end
  end
  for _, set in ipairs({ { 1, 32, 1 }, { 1, 32, 2 }, { 2, 7, 3 }, { 3, math.huge, 1 }, { 1, 1, 1 }, { 3, 5, 2 } }) do
    Rv.BAND, Rv.COLS, Rv.BANDS_PER_PULSE = set[1], set[2], set[3]
    local j = Rv.bandes.new(box)
    local done = false
    repeat
      local want = Rv.cout(j)
      covered = 0
      for _ = 1, Rv.BANDS_PER_PULSE do
        done = Rv.bandes.band(f, sfc, j)
        if done then break end
      end
      note(string.format("rv %d×%s×%d ligne %d", set[1], tostring(set[2]), set[3], j.y), want, covered)
    until done
  end
  for _, set in ipairs({ { 2, 1 }, { 3, 1 }, { 1, 2 }, { 3, 2 } }) do
    Ra.BAND, Ra.BANDS_PER_PULSE = set[1], set[2]
    local j = Ra.generateurs.new(box)
    local done = false
    repeat
      local want = Ra.cout(j.y, j.y_end, j.x1 - j.x0)
      covered = 0
      for _ = 1, Ra.BANDS_PER_PULSE do
        done = Ra.generateurs.band(f, sfc, j)
        if done then break end
      end
      note(string.format("ra %d×%d ligne %d", set[1], set[2], j.y), want, covered)
    until done
  end
  Rv.BAND, Rv.COLS, Rv.BANDS_PER_PULSE, Ra.BAND, Ra.BANDS_PER_PULSE = saved[1], saved[2], saved[3], saved[4], saved[5]
  return bad, n, first
end

---------------------------------------------------------------------------------------------------
-- P16 (lot LOURD, point 2 ; demande du lead, 7/11) : SATURATION sur la ligne de 76 de la sauvegarde du DC. 5 équipes (4 factions et votre
-- équipe), boîte de 76 × 76 chunks (R = 76, mesuré au détail de B-0659), relevés du réseau (Rv, toutes les Rv.NET_PERIOD) et du raccord
-- (Ra, toutes les R.PERIOD) à leur cadence : DEMANDE (à la cadence nominale, déduite des pas d'un relevé) et DÉBIT SERVI (mesuré), en
-- passes du pouls par minute (720 = une passe toutes les Build.PULSE ticks ; un travail de coût c vaut min(1, c / budget) passe), pour :
-- la 0.6.61 (lignes entières, un travail par tick), f72b7865 seul (tranches de 32 chunks, un travail par tick), b4be4c89 (tranches de 32,
-- budget de 64). Durée des relevés du réseau en régime établi (après 8 min).
---------------------------------------------------------------------------------------------------
-- Lot X10-S4 (8/11) : `gens` vrai = registre des génératrices allumé (script/team/generateurs.lua : le raccord commence d'un bloc, sans
-- bandes). Les trois configurations d'avant S4 se jouent registre ÉTEINT, sinon elles ne sont plus celles qu'elles nomment.
local function p16(Rv, Ra, Jeton, cols, costs, gens)
  local Gens = require("script.team.generateurs")
  local gens_saved = Gens.ENABLED
  Gens.ENABLED = gens and true or false
  logs = {}
  local w = new_world()
  local teams = {}
  for i, key in ipairs({ "f1", "f2", "f3", "f4", "player" }) do teams[i] = team(w, key, "p16-" .. key, (i - 1) * 96, 0) end
  chunks_for(w, { { -10, -10 }, { 65, 65 } })
  local sfc = surface_of(w)
  local box = box_of(w)
  local saved = { Rv.BAND, Rv.COLS, Rv.BANDS_PER_PULSE, Ra.BAND, Ra.BANDS_PER_PULSE, Jeton.COSTS }
  Rv.BAND, Rv.COLS, Rv.BANDS_PER_PULSE, Ra.BAND, Ra.BANDS_PER_PULSE, Jeton.COSTS = 1, cols, 1, 2, 1, costs
  Jeton.reset()
  local B = Jeton.BUDGET
  local function pass_of(cost) return math.min(1, ((Jeton.COSTS and cost) or B) / B) end
  local served = 0
  local J = { take = function(t, who, per, cost)
    local r = Jeton.take(t, who, per, cost)
    if r then served = served + pass_of(cost) end
    return r
  end }
  -- demande nominale : pas d'un relevé complet (coûts déclarés), à la cadence de chaque relevé
  local rows, width = box.y1 - box.y0 + 1, box.x1 - box.x0 + 1
  local rv_pass = 0
  do
    local j = { y = box.y0, y_end = box.y1 + 1, x0 = box.x0, x1 = box.x1 + 1, x = box.x0 }
    while j.y < j.y_end do
      local c = Rv.cout(j)
      rv_pass = rv_pass + pass_of(c)
      local xb = math.min(j.x + Rv.COLS, j.x1)
      if xb >= j.x1 then j.x, j.y = j.x0, j.y + Rv.BAND else j.x = xb end
    end
  end
  local ra_pass = 1 -- (la fin du raccordement : tout le budget)
  do
    local y = box.y0
    while y < box.y1 + 1 do
      ra_pass = ra_pass + pass_of(Ra.cout(y, box.y1 + 1, width))
      y = math.min(y + Ra.BAND, box.y1 + 1)
    end
  end
  local demand = #teams * (rv_pass * 3600 / Rv.NET_PERIOD + ra_pass * 3600 / require("shared.team.raccord").PERIOD)
  local T, WARM = 24 * 3600, 8 * 3600
  local served0
  local job, t0, durs = {}, {}, {}
  for t = 0, T, 5 do
    game.tick = t
    if t == WARM then served0 = served end
    for i, f in ipairs(teams) do
      Rv.step({ cancel = api_old.cancel, plant = api_old.plant, box = function() return box end, jeton = J }, f, sfc, t)
      local now = f.build.sante and f.build.sante.nr_job
      if job[i] and now ~= job[i] then
        if t0[i] >= WARM then durs[#durs + 1] = t - t0[i] end
        job[i] = nil
      end
      if now and not job[i] then job[i], t0[i] = now, t end
      Ra.step({ request = function() return nil end, prio = 50, champ_live = false, jeton = J, box = function() return box end }, f, sfc, t)
    end
  end
  Rv.BAND, Rv.COLS, Rv.BANDS_PER_PULSE, Ra.BAND, Ra.BANDS_PER_PULSE, Jeton.COSTS = saved[1], saved[2], saved[3], saved[4], saved[5], saved[6]
  Gens.ENABLED = gens_saved
  local mx, sum = 0, 0
  for _, d in ipairs(durs) do mx = math.max(mx, d); sum = sum + d end
  return { rows = rows, width = width, demand = demand, served = (served - served0) * 3600 / (T - WARM), rv_max = mx,
    rv_mean = #durs > 0 and sum / #durs or 0, rv_n = #durs, rv_pass = rv_pass, ra_pass = ra_pass }
end

---------------------------------------------------------------------------------------------------
-- Jeu de preuves sur la source du jeu
---------------------------------------------------------------------------------------------------
local Rv, Ra, Jeton, Box = load_mods(nil)
local d2, runs2, first2 = p2(Rv, 200)
check(runs2 == 7200 and d2 == 0, string.format("P2 : 200 mondes × 36 réglages (bandes de 1 à 3 lignes, tranches de 1, 2, 3 chunks ou toute la largeur, 1 à 3 par passe) : par bandes = d'un bloc (%d écart(s) sur %d)%s", d2, runs2,
  first2 and (" ; premier : " .. first2) or ""))
-- Lot LOURD (point 1 bis) : ORDRE TOTAL des tranches (ligne puis colonne, chaque case une fois), et reprise d'un relevé d'avant ce point
-- (sauvegarde : pas de j.x, toujours en début de ligne).
do
  local zones = {}
  local stub = { find_entities_filtered = function(q) zones[#zones + 1] = string.format("%g,%g-%g,%g", q.area[1][1] / 32, q.area[1][2] / 32,
    q.area[2][1] / 32, q.area[2][2] / 32); return {} end }
  local saved_band, saved_cols = Rv.BAND, Rv.COLS
  Rv.BAND, Rv.COLS = 1, 3
  local j = Rv.bandes.new({ x0 = 0, y0 = 0, x1 = 6, y1 = 2 })
  local n = 0
  repeat n = n + 1 until Rv.bandes.band({ force = "x" }, stub, j) or n > 50
  local want = { "0,0-3,1", "3,0-6,1", "6,0-7,1", "0,1-3,2", "3,1-6,2", "6,1-7,2", "0,2-3,3", "3,2-6,3", "6,2-7,3" }
  check(table.concat(zones, " ") == table.concat(want, " "), "P13 : tranches dans l'ordre ligne puis colonne, chaque case une fois (" ..
    table.concat(zones, " ") .. ")")
  local w, f = random_world(5, "fo-test")
  local sfc = surface_of(w)
  local jo = Rv.bandes.new(box_of(w))
  jo.x = nil -- relevé commencé avant ce point (sauvegarde) : début de ligne
  local k = 0
  repeat k = k + 1 until Rv.bandes.band(f, sfc, jo) or k > 10000
  check(nr_str(Rv.bandes.finish(f.build, jo)) == nr_str(ref_net_read(f, sfc, f.build)),
    "P13 : relevé d'une sauvegarde d'avant ce point (sans j.x) : même fin que net_read d'un bloc")
  Rv.BAND, Rv.COLS = saved_band, saved_cols
end
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
-- lot LOURD (point 2) : P5 au budget du tick (coûts déclarés : chunks couverts), puis le témoin à la règle de la 0.6.61 (J.COSTS = faux)
local r5 = p5(Rv, Ra, Jeton)
check(r5.heavy_ticks > 0 and r5.ungranted == 0 and r5.over == 0 and r5.shared > 0,
  string.format("P5 : budget du tick (%d unités) : tout relevé lourd tombe sur un tick où son demandeur est servi (%d hors jeton) ; plusieurs servis sur %d tick(s), jamais au-delà du budget (%d dépassement(s)) ; %d tick(s) lourd(s)",
    Jeton.BUDGET, r5.ungranted, r5.shared, r5.over, r5.heavy_ticks))
check(r5.starts >= 30 and r5.late == 0, string.format("P5 : chaque raccord part (%d départs), au plus 600 ticks après son heure (%d en retard)", r5.starts,
  r5.late))
Jeton.COSTS = false
local r5b = p5(Rv, Ra, Jeton)
Jeton.COSTS = true
check(r5b.clash == 0 and r5b.heavy_ticks > 0 and r5b.ungranted == 0 and r5b.shared == 0,
  string.format("P5 (témoin J.COSTS = faux, la règle de la 0.6.61) : jamais deux relevés lourds sur un tick (%d tick(s) lourd(s), %d en conflit)",
    r5b.heavy_ticks, r5b.clash))
check(r5b.starts >= 30 and r5b.late == 0, string.format("P5 (témoin) : chaque raccord part (%d départs, %d en retard)", r5b.starts, r5b.late))
local ok6a, ok6b, g6, w6 = p6(Rv, Box)
check(ok6a, "P6 : boîte relevée en entier à la première demande (surface.get_chunks)")
check(ok6b, "P6 : chunk généré après : boîte agrandie, son consommateur compté (" .. g6 .. ")")
do
  local lost_at, fixed_at, during = p12(Rv)
  check(lost_at and fixed_at and fixed_at - lost_at <= Rv.PERIOD + 5 and during,
    string.format("P12 : machine à vapeur perdue au tick %s pendant un relevé de 301 passes : repose décidée au tick %s (%s ticks après, au plus Rv.PERIOD), relevé encore en cours : %s",
      tostring(lost_at), tostring(fixed_at), tostring(fixed_at and lost_at and fixed_at - lost_at), tostring(during)))
end
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
  local sans, avec = p11(Ra, Jeton)
  check(sans == 0 and avec > 0, string.format("P11 : sans centrale finie, le raccordement ne prend jamais le jeton (%d fois ; l'équipe à la centrale finie : %d)", sans, avec))
end
do
  local r10 = p10(Box)
  check(r10.at_load == 1 and r10.after_get == 0 and r10.same1, string.format("P10 : boîte relevée au chargement (on_configuration_changed : %d passage(s)), plus aucun au premier Box.get (%d), juste",
    r10.at_load, r10.after_get))
  check(r10.same2 and r10.n2 == 0, string.format("P10 : surface neuve tenue par on_chunk_generated seul (%d passage(s) de get_chunks), boîte juste", r10.n2))
end
do
  local r9 = p9(Rv, Ra, Jeton)
  check(r9.reliers >= 3 and r9.deferred > 0, string.format("P9 : « relier » joué (%d fois), dont sans relevé frais par un relevé par bandes (%d passe(s) en attente)",
    r9.reliers, r9.deferred))
  check(r9.heavy > 0 and r9.bad == 0, string.format("P9 : toute recherche lourde de Rv.step et Ra.step tombe sur un tick où le jeton est à l'équipe (%d, %d hors jeton%s)",
    r9.heavy, r9.bad, r9.first and (" ; premier : " .. r9.first) or ""))
  check(r9.fins > 0 and r9.bad_fin == 0, string.format("P9 : chaque fin du raccordement prend le jeton (%d fin(s), %d sans)", r9.fins, r9.bad_fin))
end
do
  local worst, bands = p8(Rv, Ra, Jeton)
  local ok8, txt8 = p8_ok(worst, bands)
  check(ok8, "P8 : jeton équitable : plus longue attente de chaque demandeur <= demandeurs simultanés - 1 (attente/borne : " .. txt8 .. ")")
  check((bands.player or 0) > 0 and worst["player:rv"] ~= nil and worst["player:rv"].len <= worst["player:rv"].k - 1,
    string.format("P8 : votre équipe, appelée la dernière, n'est jamais affamée (%d bande(s) faites)", bands.player or 0))
end
do
  -- P14 (lot LOURD, point 2) : TÉMOIN D'IDENTITÉ. Deux parties, jouées avec le jeton de la 0.6.61 (tests/fixtures/pouls_jeton_0661.lua, copie
  -- exacte de script/team/pouls_jeton.lua à a5df66a4), puis avec l'ordonnanceur : la partie de P8 (5 équipes, relevés du réseau et du
  -- raccord à la fois) et celle de P9 (3 équipes, production nulle, « relier », fins du raccordement).
  -- (1) J.COSTS = faux (chaque travail coûte tout le budget) : même trace de demandes tick par tick, même journal, même fin ;
  -- (2) budget infini : rien n'est différé ; mêmes décisions au journal (heures retirées) et même état final que la 0.6.61.
  local J61 = assert(loadfile("tests/fixtures/pouls_jeton_0661.lua"))("script.team.pouls_jeton")
  local NL = string.char(10)
  local worlds = {
    { "P8 (5 équipes)", function(J) local _, _, cap = p8(Rv, Ra, J); return cap end },
    { "P9 (3 équipes, relier)", function(J) return p9(Rv, Ra, J).cap end },
  }
  for _, wd in ipairs(worlds) do
    local A = wd[2](J61)
    Jeton.COSTS = false
    local B = wd[2](Jeton)
    Jeton.COSTS = true
    local saved_budget = Jeton.BUDGET
    Jeton.BUDGET = math.huge
    local C = wd[2](Jeton)
    Jeton.BUDGET = saved_budget
    check(#A.trace > 0 and table.concat(A.trace, NL) == table.concat(B.trace, NL) and table.concat(A.logs, NL) == table.concat(B.logs, NL)
      and table.concat(A.finals, NL) == table.concat(B.finals, NL),
      string.format("P14 %s : J.COSTS = faux = jeton de la 0.6.61 : %d demandes identiques tick par tick, journal (%d lignes) et fin identiques",
        wd[1], #A.trace, #A.logs))
    local la, lc = {}, {}
    for i, l in ipairs(A.logs) do la[i] = strip_time(l) end
    for i, l in ipairs(C.logs) do lc[i] = strip_time(l) end
    local refused = 0
    for _, x in ipairs(C.trace) do if x:sub(-2) == "=0" then refused = refused + 1 end end
    local same_end = table.concat(A.finals, NL) == table.concat(C.finals, NL)
    local same_dec = table.concat(la, NL) == table.concat(lc, NL)
    local diff1 = nil
    for i = 1, math.max(#la, #lc) do if la[i] ~= lc[i] then diff1 = string.format("ligne %d : %s / %s", i, tostring(la[i]), tostring(lc[i])) break end end
    check(refused == 0 and same_dec and same_end,
      string.format("P14 %s : budget infini : %d refus ; mêmes décisions au journal que la 0.6.61 (%d lignes, heures retirées) et même état final%s%s",
        wd[1], refused, #la, same_end and "" or (" ; 0.6.61 : " .. A.finals[1] .. " / infini : " .. C.finals[1]), diff1 and (" ; " .. diff1) or ""))
  end
end

do
  local bad15, n15, first15 = p15(Rv, Ra)
  check(n15 > 30 and bad15 == 0, string.format("P15 : coût déclaré au jeton (Rv.cout, Ra.cout) = chunks vraiment relevés au pas suivant (%d pas, %d écart(s))%s",
    n15, bad15, first15 and (" ; premier : " .. first15) or ""))
end

do
  -- P16 : saturation sur la ligne de 76 (voir p16)
  local cap = 3600 / 5
  local a = p16(Rv, Ra, Jeton, math.huge, false, false)
  local b = p16(Rv, Ra, Jeton, 32, false, false)
  local c = p16(Rv, Ra, Jeton, 32, true, false)
  local d = p16(Rv, Ra, Jeton, 32, false, true) -- (lot X10-S4 : la configuration de b, registre des génératrices allumé)
  local function txt(name, r)
    return string.format("%s : demande %.1f, servi %.1f passes par minute sur %d (demande %.1f %%, servi %.1f %%) ; un relevé du réseau = %.2f passes, un cycle du raccord = %.0f ; relevé du réseau en régime : %.0f ticks en moyenne, %d au pire (%d relevés ; période %d)",
      name, r.demand, r.served, cap, 100 * r.demand / cap, 100 * r.served / cap, r.rv_pass, r.ra_pass, r.rv_mean, r.rv_max, r.rv_n, Rv.NET_PERIOD)
  end
  check(a.rows == 76 and a.width == 76 and a.demand < cap and a.rv_n > 0 and a.rv_max <= Rv.NET_PERIOD,
    "P16 0.6.61 (lignes entières, un travail par tick) : " .. txt("5 équipes, boîte 76 × 76", a))
  check(b.demand > cap and b.rv_max > Rv.NET_PERIOD,
    "P16 f72b7865 seul (tranches de 32, un travail par tick) : SATURÉ, " .. txt("5 équipes, boîte 76 × 76", b))
  check(c.demand < cap and c.served < cap and c.rv_n > 0 and c.rv_max <= Rv.NET_PERIOD,
    "P16 b4be4c89 (tranches de 32, budget de " .. Jeton.BUDGET .. ") : sous la capacité, " .. txt("5 équipes, boîte 76 × 76", c))
  -- Lot X10-S4 : avec le registre, le raccord prend un seul jeton par début de cycle (plus de bandes) : moins de passes servies que b
  -- et le relevé du réseau ne déborde plus sa période (mesuré le 8/11 : servi 580,1 contre 694,8, au pire 5 795 ticks contre 7 795).
  check(d.served < b.served and d.rv_n > 0 and d.rv_max <= Rv.NET_PERIOD,
    "P16 f72b7865 + registre des génératrices (X10-S4) : moins servi que sans registre (" .. string.format("%.1f contre %.1f", d.served, b.served)
    .. "), relevé du réseau dans sa période, " .. txt("5 équipes, boîte 76 × 76", d))
end

---------------------------------------------------------------------------------------------------
-- Mutants
---------------------------------------------------------------------------------------------------
local MUT = {
  { "m1 intervalle fermé [y0, y1]", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { "if p.y >= top and p.y < bottom and p.x", "if p.y >= top and p.y <= bottom and p.x" } }, "p2" },
  { "m2 dernière ligne de chunks sautée", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { "y_end = box.y1 + 1", "y_end = box.y1" } }, "p2" },
  { "m3 bande d'un chunk de large", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { "{ { left, top }, { right, bottom } }, force = f.force," .. string.char(10) .. "    type = BAND_TYPES",
      "{ { left, top }, { left + 32, bottom } }, force = f.force," .. string.char(10) .. "    type = BAND_TYPES" } }, "p2" },
  -- lot LOURD (point 1 bis) : tranches en largeur
  { "m15 intervalle fermé en x [gauche, droite]", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { "and p.x >= left and p.x < right then", "and p.x >= left and p.x <= right then" } }, "p2" },
  { "m16 dernière tranche d'une ligne sautée", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { "  if xb >= j.x1 then" .. string.char(10) .. "    j.x, j.y = j.x0, yb", "  if xb >= j.x1 - 1 then" .. string.char(10) .. "    j.x, j.y = j.x0, yb" } }, "p2" },
  { "m17 tranche qui n'avance pas de toute sa largeur", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { "    j.x = xb" .. string.char(10), "    j.x = xa + 1" .. string.char(10) } }, "p2" },
  { "m4 jeton ignoré par le raccord", "script.team.raccord", "script/team/raccord.lua",
    { { 'if api.jeton and not api.jeton.take(tick, (f.key or "player") .. ":ra", nil, cost) then return end', "if false then return end" } }, "p5" },
  { "m5 boîte non tenue à on_chunk_generated", "script.team.boite_chunks", "script/team/boite_chunks.lua",
    { { "if b then grow(b, e.position.x, e.position.y) else", "if b then elseif false then" } }, "p6" },
  { "m6 jeton ignoré par le relevé du réseau", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { 'if api.jeton and not api.jeton.take(tick, (f.key or "player") .. ":rv", nil, Rv.cout(j)) then return nil end', "if false then return nil end" } }, "p5" },
  { "m9 relier sans relevé frais par net_read d'un bloc (hors jeton)", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { "local rbox = api.box and api.box(surface)", "local rbox = nil" } }, "p9" },
  { "m10 fin du raccordement sans le jeton", "script.team.raccord", "script/team/raccord.lua",
    { { "if api.jeton and not api.jeton.take(tick, fin_par) then return end", "if false then return end" } }, "p9fin" },
  { "m11 boîte non relevée à on_configuration_changed", "script.team.boite_chunks", "script/team/boite_chunks.lua",
    { { "Events.on_configuration_changed(rebuild_all)", "" } }, "p10" },
  { "m12 raccord : jeton pris avant de lire la centrale (ordre d'avant)", "script.team.raccord", "script/team/raccord.lua",
    { { "    -- (revue de la 0.6.59, point 7 : la centrale est lue AVANT le jeton ; rien à relever, le jeton reste aux autres)",
      "    if api.jeton and not api.jeton.take(tick, (f.key or 'player') .. ':ra') then return end" } }, "p11" },
  { "m8 jeton à priorité fixe (file ignorée)", "script.core.lourd", "script/core/lourd.lua",
    { { "local ok = (used + r + c <= J.BUDGET) or (used == 0 and not ahead)", "local ok = (used + c <= J.BUDGET) or (used == 0)" } }, "p8" },
  -- lot LOURD (point 2) : coût déclaré = chunks vraiment relevés
  { "m18 Rv.cout sans la tranche coupée au bord droit", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { "math.min(x + Rv.COLS, j.x1)", "(x + Rv.COLS)" } }, "p15" },
  { "m19 Ra.cout sans la dernière bande coupée", "script.team.raccord", "script/team/raccord.lua",
    { { "    n = n + (yb - y) * width", "    n = n + Ra.BAND * width" } }, "p15" },
  { "m20 coût déclaré ignoré par l'ordonnanceur (un travail par tick)", "script.core.lourd", "script/core/lourd.lua",
    { { "local c = (J.COSTS and cost) or J.BUDGET", "local c = J.BUDGET" } }, "p5budget" },
  { "m13 la centrale attend la fin du relevé (avant le point 4)", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { "  do" .. string.char(10) .. "    if tick < sv.next then return end",
      "  if sv.nr_job then return end" .. string.char(10) .. "  do" .. string.char(10) .. "    if tick < sv.next then return end" } }, "p12" },
  { "m7 réseaux des générateurs non relus à la fin (numéros des bandes)", "script.team.reseau_vivant", "script/team/reseau_vivant.lua",
    { { "local out = { islands = 0, uncovered = 0, nets = {}, live = live }", "live = j.gn; local out = { islands = 0, uncovered = 0, nets = {}, live = live }" } }, "p7" },
  -- lot LOURD : les bandes suivantes du relevé des générateurs (début du raccord) prennent le jeton
  { "m14 raccord : bandes des générateurs sans le jeton", "script.team.raccord", "script/team/raccord.lua",
    { { 'elseif api.jeton and not api.jeton.take(tick, (f.key or "player") .. ":ra", nil, Ra.cout(lj.y, lj.y_end, lj.x1 - lj.x0)) then', "elseif false then" } }, "p9" },
}
for _, m in ipairs(MUT) do
  local Rvm, Ram, Jm, Bm = load_mods({ m[2], m[3], m[4] })
  local seen
  if m[5] == "p2" then
    local d = p2(Rvm, 60)
    seen = d > 0
  elseif m[5] == "p5" then
    seen = p5(Rvm, Ram, Jm).ungranted > 0
  elseif m[5] == "p5budget" then
    seen = p5(Rvm, Ram, Jm).shared == 0
  elseif m[5] == "p15" then
    seen = p15(Rvm, Ram) > 0
  elseif m[5] == "p12" then
    local lost_at, fixed_at = p12(Rvm)
    seen = not (lost_at and fixed_at and fixed_at - lost_at <= Rvm.PERIOD + 5)
  elseif m[5] == "p11" then
    local sans = p11(Ram, Jm)
    seen = sans > 0
  elseif m[5] == "p10" then
    local r = p10(Bm)
    seen = not (r.at_load == 1 and r.after_get == 0)
  elseif m[5] == "p9" then
    local r = p9(Rvm, Ram, Jm)
    seen = r.bad > 0
  elseif m[5] == "p9fin" then
    local r = p9(Rvm, Ram, Jm)
    seen = r.bad_fin > 0
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
