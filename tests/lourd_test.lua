--[[
  Lot LOURD (S6 de l'objectif x10, fo-logs\2026-11-07_LOURD\CRITERES.md §1) : le relevé des générateurs du début du raccordement
  (script/team/raccord.lua, Ra.step) se fait par BANDES de lignes de chunks, une par passe, sous le jeton du tick, au lieu d'une recherche
  sur toute la surface (live_networks, recopié ici tel qu'en 0e340b99).
  Monde simulé : la recherche par zone rend ce qui TOUCHE la zone (intervalles fermés, F96), avec de vraies boîtes.
    L1. 200 mondes tirés d'une graine (générateurs des trois types sur les bords des bandes, à cheval, d'une autre force, dans la dernière
        ligne) : par bandes (1 à 3 lignes, 1 à 3 bandes par passe) = d'un bloc (réseaux vivants et leur nombre).
    L2. Renumérotation d'un réseau entre deux bandes : la fin rend les réseaux de live_networks lu à la fin.
    L3. Chaîne entière (centrale, module relié, île, machine sous aucun poteau, île reliée, île nouvelle) : journal [FO-RACCORD] et
        demandes égaux au chemin d'un bloc, heures retirées (décalage du relevé des générateurs) ; mode bloc (Ra.BANDS_PER_PULSE =
        math.huge) : journal heures comprises et état égaux.
    L5. Sauvegarde en plein relevé des générateurs (état recopié, module rechargé) : même fin.
    L6. Cadence : sans concurrence, les relevés des générateurs commencent toutes les R.PERIOD, comme les cycles d'avant.
    Rv.BAND = 1 (bandes du relevé du réseau deux fois plus étroites).
    Mutants (texte de la source changé, par package.preload) : ils DOIVENT tous être vus.
  Le jeton (budget du tick depuis le point 2, script/core/lourd.lua ; bandes de Ra comprises) est contrôlé par tests/pouls_test.lua (P5,
  P8, P9, P14, P15, m14) et tests/lourd_jeton_test.lua.
  Usage : lua5.2 tests/lourd_test.lua
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 print("OK     " .. msg) else fail_n = fail_n + 1 print("ECHEC : " .. msg) end
end

local logs = {}
log = function(s) logs[#logs + 1] = s end
local PROTOS = { ["medium-electric-pole"] = { max_wire_distance = 9, tile_width = 1 } }
game = { entity_prototypes = PROTOS, tick = 0 }
-- Lot TESTS-VERTS : script/team/zone_equipe.lua (UPS-HYGIENE, a9010348) requiert script/team/boite_chunks.lua, abonné à
-- defines.events.on_chunk_generated au chargement (POULS, c03b7f67).
defines = defines or {}
defines.events = defines.events or { on_chunk_generated = 34 }

local store = {}
package.loaded["script.core.events"] = { on = function() end, on_init = function() end, on_configuration_changed = function() end }
package.loaded["script.core.storage"] = {
  declare = function(name, init) store[name] = store[name] or init() end,
  ns = function(name) return store[name] end,
}

---------------------------------------------------------------------------------------------------
-- Monde simulé
---------------------------------------------------------------------------------------------------
local function new_world() return { ents = {}, un = 0, extra = {} } end

local function add(w, name, type_, x, y, net, o)
  o = o or {}
  w.un = w.un + 1
  local hw, hh = o.hw or 0.5, o.hh or 0.5
  local e = { name = name, type = type_, position = { x = x, y = y }, electric_network_id = net, unit_number = w.un, valid = true,
    force = o.force or "f1", box = { x - hw, y - hh, x + hw, y + hh },
    bounding_box = { left_top = { x = x - hw, y = y - hh }, right_bottom = { x = x + hw, y = y + hh } },
    prototype = { electric_energy_source_prototype = (not o.burner) and {} or nil, max_wire_distance = o.wire or 9 } }
  e.connect_neighbour = function(other) e.wired_to = other; return true end
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
            local px, py = q.position.x or q.position[1], q.position.y or q.position[2]
            local dx, dy = e.position.x - px, e.position.y - py
            ok = dx * dx + dy * dy <= (q.radius or 0) ^ 2 + 1e-9
          end
          if q.area then
            local a = q.area
            ok = ok and e.box[1] <= a[2][1] and e.box[3] >= a[1][1] and e.box[2] <= a[2][2] and e.box[4] >= a[1][2]
          end
          if ok then
            out[#out + 1] = e
            if q.limit and #out >= q.limit then break end
          end
        end
      end
      return out
    end,
    find_nearest_enemy = function() return nil end,
  }
end

--- Boîte des chunks générés : ceux qui portent une entité (position), plus w.extra.
local function box_of(w)
  local b
  local function grow(cx, cy)
    if b then
      b.x0, b.x1, b.y0, b.y1 = math.min(b.x0, cx), math.max(b.x1, cx), math.min(b.y0, cy), math.max(b.y1, cy)
    else
      b = { x0 = cx, y0 = cy, x1 = cx, y1 = cy }
    end
  end
  for _, e in ipairs(w.ents) do grow(math.floor(e.position.x / 32), math.floor(e.position.y / 32)) end
  for _, c in ipairs(w.extra) do grow(c[1], c[2]) end
  return b
end

---------------------------------------------------------------------------------------------------
-- La version d'AVANT (0e340b99), recopiée : live_networks
---------------------------------------------------------------------------------------------------
local GEN_TYPES = { "generator", "burner-generator", "solar-panel" }
local function ref_live(f, surface)
  local live, n = {}, 0
  for _, g in ipairs(surface.find_entities_filtered({ force = f.force, type = GEN_TYPES })) do
    local id = g.electric_network_id
    if id and not live[id] then live[id] = true; n = n + 1 end
  end
  return live, n
end

local function live_str(live, n)
  local k = {}
  for x in pairs(live) do k[#k + 1] = x end
  table.sort(k)
  return string.format("n=%d [%s]", n, table.concat(k, ","))
end

local function ser(v, out)
  out = out or {}
  if type(v) == "table" then
    if v.unit_number and v.position then out[#out + 1] = "E" .. v.unit_number return out end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
      out[#out + 1] = tostring(k) .. "="
      ser(v[k], out)
      out[#out + 1] = ","
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
  if v.unit_number and v.position then return v end -- entité : une sauvegarde garde la RÉFÉRENCE
  local c = {}
  for k, x in pairs(v) do c[k] = deep(x) end
  return c
end

---------------------------------------------------------------------------------------------------
-- Chargement (source éventuellement changée : mutant)
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

local function load_mods(subs)
  for _, m in ipairs({ "script.team.reseau_vivant", "script.team.raccord", "script.team.pouls_jeton", "script.core.lourd" }) do
    package.loaded[m] = nil
    package.preload[m] = nil
  end
  if subs then
    local src = mutated("script/team/raccord.lua", subs)
    package.preload["script.team.raccord"] = function(name) return assert(load(src, "=script/team/raccord.lua"))(name) end
  end
  store = {}
  return require("script.team.raccord"), require("script.team.pouls_jeton"), require("script.team.reseau_vivant")
end

local function lcg(seed)
  local st = seed
  return function(n)
    st = (st * 1103515245 + 12345) % 2147483648
    return math.floor(st / 65536) % n + 1
  end
end

--- Relevé des générateurs par bandes jusqu'au bout ; `between(k)` est appelé après la bande k.
local function banded(Ra, f, sfc, box, per, between)
  local G = Ra.generateurs
  local j = G.new(box)
  local k, done = 0, false
  repeat
    for _ = 1, per do
      done = G.band(f, sfc, j)
      k = k + 1
      if between then between(k) end
      if done then break end
    end
  until done or k > 10000
  return G.finish(j)
end

---------------------------------------------------------------------------------------------------
-- L1 : par bandes = d'un bloc
---------------------------------------------------------------------------------------------------
local GSIZE = { ["generator"] = { 1.5, 2.5 }, ["burner-generator"] = { 1.5, 1.5 }, ["solar-panel"] = { 1.5, 1.5 } }
local function random_world(seed)
  local r = lcg(seed)
  local w = new_world()
  local f = { key = "rnd", force = "fo-test" }
  local n = 5 + r(25)
  for _ = 1, n do
    local ty = GEN_TYPES[r(3)]
    local cy = r(9) - 5
    local y = cy * 32 + ({ 0, 0.5, 1.5, 16, 30.5, 31.5, 32 })[r(7)]
    local net = r(8) <= 7 and r(6) or nil
    add(w, ty, ty, r(300) - 150 + 0.5, y, net, { force = r(10) <= 8 and "fo-test" or "autre", hw = GSIZE[ty][1], hh = GSIZE[ty][2] })
  end
  for _ = 1, 10 do add(w, "assembler", "assembling-machine", r(300) - 150, r(200) - 100, 50 + r(3)) end -- consommateurs : jamais gardés
  -- un générateur dans la DERNIÈRE ligne de la boîte, d'un réseau à lui (le mutant « dernière bande sautée » se voit)
  add(w, "solar-panel", "solar-panel", 10.5, 6 * 32 + 10.5, 77, { force = "fo-test", hw = 1.5, hh = 1.5 })
  w.extra = { { -8, -8 } } -- (lignes vides en haut)
  return w, f
end

local function l1(Ra, worlds)
  local diffs, runs, first = 0, 0, nil
  local saved = Ra.BAND
  for seed = 1, worlds do
    local w, f = random_world(seed)
    local sfc = surface_of(w)
    local want = live_str(ref_live(f, sfc))
    for _, band in ipairs({ 1, 2, 3 }) do
      Ra.BAND = band
      for _, per in ipairs({ 1, 2, 3 }) do
        local got = live_str(banded(Ra, f, sfc, box_of(w), per))
        runs = runs + 1
        if got ~= want then
          diffs = diffs + 1
          first = first or string.format("graine %d, bande %d, %d par passe : par bandes %s ; d'un bloc %s", seed, band, per, got, want)
        end
      end
    end
  end
  Ra.BAND = saved
  return diffs, runs, first
end

---------------------------------------------------------------------------------------------------
-- L2 : renumérotation entre deux bandes (générateur A lu tôt, B lu tard ; leur réseau change après la première bande)
---------------------------------------------------------------------------------------------------
local function l2(Ra)
  local out = {}
  local cases = {
    { "coupure : A passe sur un réseau neuf 9", function(a, b) a.electric_network_id = 9 end },
    { "jonction : A et B passent sur 12", function(a, b) a.electric_network_id = 12; b.electric_network_id = 12 end },
    { "A détruit", function(a, b) a.valid = false end },
  }
  local saved = Ra.BAND
  Ra.BAND = 1
  for _, c in ipairs(cases) do
    local w = new_world()
    local f = { key = "l2", force = "f1" }
    local a = add(w, "steam-engine", "generator", 10.5, -90, 5, { hw = 1.5, hh = 2.5 })
    local b = add(w, "solar-panel", "solar-panel", 40.5, 70, 5, { hw = 1.5, hh = 1.5 })
    w.extra = { { -3, -3 }, { 3, 3 } }
    local sfc = surface_of(w)
    local got = live_str(banded(Ra, f, sfc, box_of(w), 1, function(k) if k == 1 then c[2](a, b) end end))
    out[#out + 1] = { c[1], got, live_str(ref_live(f, sfc)) }
  end
  Ra.BAND = saved
  return out
end

---------------------------------------------------------------------------------------------------
-- L3 : chaîne entière, d'un bloc contre par bandes
---------------------------------------------------------------------------------------------------
local function proj(id, state, ents, spec)
  return { id = id, state = state, ents = ents, spec = spec or { gen = "x" }, parts = { { ox = 0, oy = 0, w = 1, h = 1 } } }
end

--- Équipe de tests/raccord_script_test.lua (centrale, module relié, île, machine sous aucun poteau), plus deux générateurs loin (lignes
--- de chunks 7 et 15) : le relevé des générateurs a plusieurs bandes.
local function l3_world()
  local w = new_world()
  add(w, "steam-engine", "generator", 0, 0, 1, { hw = 1.5, hh = 1.5 })
  add(w, "medium-electric-pole", "electric-pole", 3, 0, 1)
  add(w, "medium-electric-pole", "electric-pole", 40, 0, 1)
  add(w, "assembling-machine-1", "assembling-machine", 40, 3, 1, { hw = 1.5, hh = 1.5 })
  add(w, "medium-electric-pole", "electric-pole", 60, 0, 2)
  add(w, "assembling-machine-1", "assembling-machine", 60, 3, 2, { hw = 1.5, hh = 1.5 })
  add(w, "assembling-machine-1", "assembling-machine", 63, 3, 2, { hw = 1.5, hh = 1.5 })
  add(w, "electric-mining-drill", "mining-drill", 10, 40, nil, { hw = 1.5, hh = 1.5 })
  add(w, "solar-panel", "solar-panel", 20.5, 250.5, 1, { hw = 1.5, hh = 1.5 })
  add(w, "burner-generator", "burner-generator", 30.5, 500.5, 8, { hw = 1.5, hh = 1.5 })
  local b = { order = { 1, 2, 3, 4 }, plant = 1, opts = {}, projects = {
    [1] = proj(1, "fini", { { name = "steam-engine", x = 0, y = 0, built = true, part = 1 }, { name = "medium-electric-pole", x = 3, y = 0, built = true, part = 1 } },
      { gen = "steam" }),
    [2] = proj(2, "fini", { { name = "assembling-machine-1", x = 40, y = 3, built = true, part = 1 }, { name = "medium-electric-pole", x = 40, y = 0, built = true, part = 1 } }),
    [3] = proj(3, "fini", { { name = "assembling-machine-1", x = 60, y = 3, built = true, part = 1 }, { name = "assembling-machine-1", x = 63, y = 3, built = true, part = 1 },
      { name = "medium-electric-pole", x = 60, y = 0, built = true, part = 1 } }),
    [4] = proj(4, "fini", { { name = "electric-mining-drill", x = 10, y = 40, built = true, part = 2 } }),
  } }
  return w, { key = "f1", force = "f1", build = b }
end

--- Monde changé après la fin du cycle k (les deux chemins voient les mêmes changements, entre deux cycles).
local function l3_change(w, f, k)
  local b = f.build
  if k == 2 and b.projects[100] then
    b.projects[100].state, b.projects[100].wired = "fini", 2
    for _, e in ipairs(w.ents) do if e.electric_network_id == 2 then e.electric_network_id = 1 end end
  elseif k == 4 then
    add(w, "medium-electric-pole", "electric-pole", 48, 0, 5)
    add(w, "assembling-machine-1", "assembling-machine", 48, 3, 5, { hw = 1.5, hh = 1.5 })
    b.projects[5] = proj(5, "fini", { { name = "assembling-machine-1", x = 48, y = 3, built = true, part = 1 }, { name = "medium-electric-pole", x = 48, y = 0, built = true, part = 1 } })
    b.order[#b.order + 1] = 5
  end
end

local function strip_time(l) return (l:gsub(" a %d+%.%d min$", "")) end

--- mode : "bloc" (sans boîte, chemin d'avant) ou "bandes" (boîte et jeton). Rend journal, demandes, état, ticks de fin des cycles.
local function l3_run(subs, mode, cycles, per)
  local Ra, Jeton = load_mods(subs)
  local saved_band, saved_per = Ra.BAND, Ra.BANDS_PER_PULSE
  Ra.BAND, Ra.BANDS_PER_PULSE = 1, per or 1
  Jeton.reset()
  logs = {}
  local w, f = l3_world()
  local sfc = surface_of(w)
  local reqs, fins = {}, {}
  local api = { prio = 59, champ_live = false, request = function(ff, spec)
    local id = 100 + #reqs
    reqs[#reqs + 1] = spec.raccord
    ff.build.projects[id] = proj(id, "reserve", {}, spec)
    ff.build.order[#ff.build.order + 1] = id
    return id
  end, prof = { fstart = function(name) if name == "ra:fin" then fins[#fins + 1] = game.tick end end, fstop = function() end } }
  if mode == "bandes" then
    api.box = function() return box_of(w) end
    api.jeton = Jeton
  end
  local t, done = 0, 0
  while done < cycles and t < 40 * 3600 do
    t = t + 5
    game.tick = t
    local n0 = #fins
    Ra.step(api, f, sfc, t)
    if #fins > n0 then
      done = done + 1
      l3_change(w, f, done)
    end
  end
  Ra.BAND, Ra.BANDS_PER_PULSE = saved_band, saved_per
  return logs, reqs, f.build.raccord, fins
end

local function journal(l, timed)
  local out = {}
  for _, x in ipairs(l) do if x:find("[FO-RACCORD]", 1, true) then out[#out + 1] = timed and x or strip_time(x) end end
  return table.concat(out, "\n")
end

---------------------------------------------------------------------------------------------------
-- L5 : sauvegarde en plein relevé des générateurs ; L6 : cadence
---------------------------------------------------------------------------------------------------
local function tall_world()
  local w = new_world()
  local f = { key = "t", force = "f1", build = { order = { 1 }, plant = 1, opts = {}, projects = {
    [1] = proj(1, "fini", { { name = "steam-engine", x = 0, y = 0, built = true, part = 1 } }, { gen = "steam" }) } } }
  add(w, "steam-engine", "generator", 0.5, 0.5, 1, { force = "f1", hw = 1.5, hh = 2.5 })
  for k = 0, 19 do add(w, "solar-panel", "solar-panel", 40.5 + k, k * 32 + 16.5, 1 + (k % 4), { force = "f1", hw = 1.5, hh = 1.5 }) end
  return w, f
end

local function l5(subs)
  local function run(copy_at)
    local Ra, Jeton = load_mods(subs)
    Ra.BAND, Ra.BANDS_PER_PULSE = 1, 1
    Jeton.reset()
    local w, f = tall_world()
    local sfc = surface_of(w)
    local api = { prio = 59, champ_live = false, request = function() return nil end, box = function() return box_of(w) end, jeton = Jeton }
    local copied = false
    for t = 5, 2 * 3600, 5 do
      game.tick = t
      local st = f.build.raccord
      if copy_at and not copied and st and st.lj and st.lj.bands == copy_at then
        f.build.raccord = deep(st) -- (sauvegarde puis chargement : état recopié, module rechargé, jeton local rendu)
        Ra, Jeton = load_mods(subs)
        Ra.BAND, Ra.BANDS_PER_PULSE = 1, 1
        api.jeton = Jeton
        copied = true
      end
      Ra.step(api, f, sfc, t)
      st = f.build.raccord
      if st and st.cyc and not st.lj then return s(st.cyc), t, copied end
    end
    return "pas de cycle", -1, copied
  end
  local a, ta = run(nil)
  local b, tb, copied = run(7)
  return a == b and ta == tb and copied, ta, tb
end

local function l6(subs)
  local Ra, Jeton = load_mods(subs)
  Ra.BAND, Ra.BANDS_PER_PULSE = 1, 1
  Jeton.reset()
  local w, f = tall_world()
  local sfc = surface_of(w)
  local api = { prio = 59, champ_live = false, request = function() return nil end, box = function() return box_of(w) end, jeton = Jeton }
  local starts, had = {}, false
  for t = 5, 6 * 3600, 5 do
    game.tick = t
    Ra.step(api, f, sfc, t)
    local st = f.build.raccord
    local has = st and st.lj ~= nil
    if has and not had then starts[#starts + 1] = t end
    had = has
  end
  local gaps = {}
  for i = 2, #starts do gaps[#gaps + 1] = starts[i] - starts[i - 1] end
  local R = require("shared.team.raccord")
  local ok = #gaps >= 3
  for _, g in ipairs(gaps) do if g ~= R.PERIOD then ok = false end end
  return ok, table.concat(gaps, ",")
end

---------------------------------------------------------------------------------------------------
-- Contrôles
---------------------------------------------------------------------------------------------------
local Ra0, _, Rv0 = load_mods(nil)
check(Rv0.BAND == 1, "Rv.BAND = 1 : bandes du relevé du réseau d'une ligne de chunks (rv:bande 8,15 ms au pire à 2 lignes, AB-0659)")
check(Ra0.BAND >= 1 and Ra0.BANDS_PER_PULSE == 1, string.format("Ra.BAND = %d ligne(s), une bande par passe", Ra0.BAND))

local d1, n1, first1 = l1(Ra0, 200)
check(d1 == 0, string.format("L1 : par bandes = d'un bloc sur 200 mondes (%d relevés, %d écart(s))%s", n1, d1, first1 and (" : " .. first1) or ""))

for _, c in ipairs(l2(Ra0)) do check(c[2] == c[3], string.format("L2 : %s : par bandes %s = d'un bloc lu à la fin %s", c[1], c[2], c[3])) end

local lb, rb, stb, fb = l3_run(nil, "bloc", 7)
local lp, rp, stp, fp = l3_run(nil, "bandes", 7)
local jb, jp = journal(lb), journal(lp)
check(#fb == 7 and #fp == 7 and jb == jp and #jb > 0, string.format("L3 : 7 cycles, journal [FO-RACCORD] égal, heures retirées (%d et %d lignes)",
  select(2, jb:gsub("\n", "")) + 1, select(2, jp:gsub("\n", "")) + 1))
check(#rb >= 2 and s(rb) == s(rp), string.format("L3 : mêmes demandes de raccordement (%d et %d)", #rb, #rp))
local lag = (fp[1] or 0) - (fb[1] or 0)
check(lag > 0 and lag <= 40 * 5, string.format("L3 : décalage du premier cycle = relevé des générateurs par bandes (%d ticks)", lag))
local lh, rh, sth = l3_run(nil, "bandes", 7, math.huge)
check(journal(lh, true) == journal(lb, true) and s(rh) == s(rb) and s(sth) == s(stb),
  "L3 : mode bloc (Ra.BANDS_PER_PULSE = math.huge) : journal heures comprises, demandes et état égaux au chemin d'avant")

local ok5, ta, tb = l5(nil)
check(ok5, string.format("L5 : sauvegarde à la 7e bande du relevé des générateurs, module rechargé : même cycle, même tick (%d, %d)", ta, tb))
local ok6, gaps = l6(nil)
check(ok6, "L6 : sans concurrence, un relevé des générateurs toutes les R.PERIOD (écarts " .. gaps .. ")")

local MUT = {
  { "dernière bande sautée", { { "return j.y >= j.y_end", "return j.y >= j.y_end - 1" } }, "l1" },
  { "bande d'un chunk de large", { { "{ j.x1 * 32, bottom }", "{ (j.x0 + 1) * 32, bottom }" } }, "l1" },
  { "réseaux des générateurs non relus à la fin (numéros des bandes)", {
    { "if y >= top and y < bottom then j.gens[#j.gens + 1] = g end", "if y >= top and y < bottom then g.band_net = g.electric_network_id; j.gens[#j.gens + 1] = g end" },
    { "      local id = g.electric_network_id\n      if id and not live[id] then live[id] = true; n = n + 1 end\n    end\n  end\n  return live, n\nend\n\n-- Bancs",
      "      local id = g.band_net\n      if id and not live[id] then live[id] = true; n = n + 1 end\n    end\n  end\n  return live, n\nend\n\n-- Bancs" } }, "l2" },
  { "horloge posée à la fin du relevé des générateurs (cadence décalée)", {
    { "      st.next = tick + R.PERIOD\n      -- Lot LOURD : boîte", "      -- Lot LOURD : boîte" },
    { "    st.lj = nil\n", "    st.lj = nil\n    st.next = tick + R.PERIOD\n" } }, "l6" },
}
for _, m in ipairs(MUT) do
  local seen
  if m[3] == "l1" then
    local Rm = load_mods(m[2])
    seen = (l1(Rm, 60)) > 0
  elseif m[3] == "l2" then
    local Rm = load_mods(m[2])
    seen = false
    for _, c in ipairs(l2(Rm)) do if c[2] ~= c[3] then seen = true end end
  else
    seen = not (l6(m[2]))
  end
  check(seen, "mutant " .. m[1] .. " : vu")
end

print(string.format("[LOURD] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
