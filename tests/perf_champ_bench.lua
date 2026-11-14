--[[
  s49 opti : banc HORS JEU de Ch.plan (shared/team/champ.lua). Specs réalistes (dont un pire cas « charbon sans voie » : les 4
  plan_order, colonnes refusées, et le disque coupé par une rivière), temps os.clock du Ch.plan entier et par sous-fonction (enveloppes
  posées par debug.setupvalue sur les fonctions locales du module, et sur les champs de Co), appels comptés, états de Co.route.
  Empreinte de chaque plan (même empreinte que tests/s46_champ-cout_test.lua) comparée à tests/perf_champ_ref.lua : un plan changé
  est un ÉCHEC.
  Usage, depuis la racine du mod :   lua5.2 tests/perf_champ_bench.lua [--ref] [--nowrap] [nom]
    --ref     écrit tests/perf_champ_ref.lua (empreintes de référence, à faire sur le code d'avant l'optimisation)
    --nowrap  sans enveloppes (temps nu) ; --reps=N : N passes, le temps le plus court
    --memo-par-pas  (s49 tranches) mémoire neuve à chaque pas : coût d'un pas sans le partage des mémoires entre variantes
]]
package.path = "./?.lua;" .. package.path
local Ch = require("shared.team.champ")
local Co = require("shared.team.champ_colonne")

local ARGS = {}
for _, a in ipairs(arg or {}) do ARGS[a] = true end
local ONLY, REPS = nil, 1
for _, a in ipairs(arg or {}) do
  if a:match("^%-%-reps=%d+$") then REPS = tonumber(a:match("%d+")) elseif a:sub(1, 2) ~= "--" then ONLY = a end
end

---------------------------------------------------------------------------------------------------
-- Empreinte (celle de s46_champ-cout_test)
---------------------------------------------------------------------------------------------------
local function ser(v, seen)
  if type(v) ~= "table" then return tostring(v) end
  if seen[v] then return "<cyc>" end
  seen[v] = true
  local ks = {}
  for k in pairs(v) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  local o = {}
  for _, k in ipairs(ks) do local x = v[k]; if type(x) ~= "function" then o[#o + 1] = tostring(k) .. "=" .. ser(x, seen) end end
  seen[v] = nil
  return "{" .. table.concat(o, ",") .. "}"
end
local function hash(s)
  local h = 0
  for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
  return h
end

---------------------------------------------------------------------------------------------------
-- Specs
---------------------------------------------------------------------------------------------------
local K = Ch.key
local BELTS3 = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }
local function ellipse(cx, cy, a, b, skip)
  local out = {}
  for x = cx - a, cx + a do
    for y = cy - b, cy + b do
      if ((x - cx) / a) ^ 2 + ((y - cy) / b) ^ 2 <= 1 and not (skip and skip(x, y)) then out[#out + 1] = x; out[#out + 1] = y end
    end
  end
  return out
end
local function spec_of(ore, o)
  return { ore = ore, blocked = o.blocked or {}, soft = o.soft, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = BELTS3, furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 }, inserter = { rate = 0.83 },
    target = o.target or { x = 1000, y = 0 }, max_side = 8, design = "colonne", axis = o.axis, window = o.window,
    coal = { tiles = o.coal, rate = 0.5 }, logistics = { splitter = true, underground = 5 } }
end
-- disque de rayon 40 coupé par une rivière nord-sud (x de -2 à 2, bloquée sur toute la hauteur lue)
local function riviere()
  local blocked = {}
  for x = -2, 2 do for y = -120, 120 do blocked[K(x, y)] = true end end
  local ore = ellipse(0, 0, 40, 40, function(x) return x >= -2 and x <= 2 end)
  return spec_of(ore, { blocked = blocked, coal = ellipse(-20, 62, 8, 8), window = { -100, -100, 100, 100 } })
end
-- pire cas du type emerald (cuivre, une vingtaine de foreuses) : le charbon derrière un fleuve qui barre toute la largeur lue ; les
-- tracés du charbon des deux côtés échouent (aucun passage : la preuve rapide ne tranche pas, l'A* va au plafond d'états), toutes les
-- colonnes retombent au coffre de tête, le refus coûte trop : autre ordre des côtés, rangées gloutonnes, soit 4 plan_order
local function emerald()
  local blocked = {}
  for x = -300, 300 do for y = 22, 29 do blocked[K(x, y)] = true end end
  local ore = ellipse(0, 0, 17, 6)
  return spec_of(ore, { blocked = blocked, coal = ellipse(0, 64, 9, 9), window = { -90, -40, 90, 95 } })
end
-- grand champ au charbon joignable par une forêt (arbres : tuiles « soft ») et un lac à contourner
local function foret()
  local blocked, soft = {}, {}
  for x = -30, 30 do for y = 40, 46 do if (x * x) / 900 + ((y - 43) ^ 2) / 9 <= 1 then blocked[K(x, y)] = true end end end
  for x = -50, 50 do for y = 30, 39 do if (x * 7 + y * 13) % 5 == 0 then soft[K(x, y)] = true end end end
  local ore = ellipse(0, 0, 55, 25)
  return spec_of(ore, { blocked = blocked, soft = soft, coal = ellipse(10, 60, 7, 7), window = { -120, -80, 120, 90 } })
end

local CASES = {
  { "petit", function() return spec_of(ellipse(0, 0, 12, 9), { coal = ellipse(0, 20, 5, 5) }) end },
  { "ellipse 45x30", function() return spec_of(ellipse(0, 0, 45, 30), { coal = ellipse(0, 50, 8, 8) }) end },
  { "ellipse 45x30 axe y", function() return spec_of(ellipse(0, 0, 45, 30), { coal = ellipse(0, 50, 8, 8), axis = "y" }) end },
  { "riviere disque 40", riviere },
  { "emerald charbon sans voie", emerald },
  { "foret 55x25", foret },
}
-- s52 mesure : specs RÉELLES de la carte du DC (ressources 600 %, graine 271828182), relevées par Profiler.dump("champ-frame") au banc
-- s52-dump-champ (profileur détail) : { spec, cfg }. Chaque passe relit le fichier (tables neuves).
for _, fx in ipairs({ { "dc joueur fer 1", "tests/fixtures/champ_joueur_dc.lua" }, { "dc emerald fer 3", "tests/fixtures/champ_emerald_dc.lua" } }) do
  local fh = io.open(fx[2], "r")
  if fh then
    fh:close()
    CASES[#CASES + 1] = { fx[1], function() return dofile(fx[2]).spec end }
  end
end

---------------------------------------------------------------------------------------------------
-- Enveloppes (temporaires : seulement dans ce processus)
---------------------------------------------------------------------------------------------------
local T, N = {}, {}
local function wrap(name, f)
  return function(...)
    local t0 = os.clock()
    local r = table.pack(f(...))
    T[name] = (T[name] or 0) + (os.clock() - t0)
    N[name] = (N[name] or 0) + 1
    return table.unpack(r, 1, r.n)
  end
end
local function find_up(f, name)
  for i = 1, 200 do
    local n, v = debug.getupvalue(f, i)
    if not n then return nil end
    if n == name then return i, v end
  end
end
local wrapped = {}
local function wrap_up(owner, name)
  local i, v = find_up(owner, name)
  if not i or type(v) ~= "function" then return nil end
  if not wrapped[name] then
    wrapped[name] = v
    debug.setupvalue(owner, i, wrap(name, v))
  end
  return v
end
if not ARGS["--nowrap"] then
  local plan_order = wrap_up(Ch.plan_step, "plan_order") -- s49 tranches : plan_order n'est plus appelé que par Ch.plan_step
  local plan_once = wrap_up(plan_order, "plan_once")
  for _, nm in ipairs({ "bands_for", "bridge", "bridge_0641", "row_poles", "take_group", "context" }) do wrap_up(plan_once, nm) end
  local bands_for = wrapped.bands_for
  if bands_for then
    local best_row = wrap_up(bands_for, "best_row")
    if best_row then wrap_up(best_row, "row_drills") end
  end
  for _, nm in ipairs({ "route", "network", "place", "away", "coal_line", "unreachable", "layout" }) do Co[nm] = wrap("Co." .. nm, Co[nm]) end
end

---------------------------------------------------------------------------------------------------
-- Banc
---------------------------------------------------------------------------------------------------
local REF_PATH = "tests/perf_champ_ref.lua"
local REF = {}
do local f = io.open(REF_PATH, "r"); if f then f:close(); REF = dofile(REF_PATH) end end
local S46 = dofile("tests/s46_champ-cout_ref.lua")
local out_ref = {}
local PAS_MAX, PAS_N = 0, 0
local fails = 0
local total = 0
for _, cs in ipairs(CASES) do
  if not ONLY or ONLY == cs[1] then
    -- REPS passes (le PC est partagé : le temps retenu est le plus court, avec son détail), chaque passe sur des tables neuves
    local p, why, dt, h
    local BT, BN, BX = {}, {}, 0
    for rep = 1, REPS do
      for k in pairs(T) do T[k] = nil end
      for k in pairs(N) do N[k] = nil end
      Co.EXPANDED = 0
      local spec = cs[2]()
      -- s49 tranches : les pas de Ch.plan un à un (un plan_order par pas, un pas par tick en jeu) : temps du pas le plus long.
      -- --memo-par-pas : mémoire neuve à chaque pas (comparaison : sans le partage des mémoires entre les variantes d'un plan)
      local t0 = os.clock()
      local sq, smax, done = Ch.plan_begin(spec), 0, false
      while not done do
        if ARGS["--memo-par-pas"] then sq.memo = {} end
        local s0 = os.clock()
        done = Ch.plan_step(sq)
        smax = math.max(smax, os.clock() - s0)
      end
      p, why = Ch.plan_result(sq)
      local d1 = os.clock() - t0
      if not dt or d1 < dt then PAS_MAX, PAS_N = smax, sq.n end
      if not dt or d1 < dt then
        dt = d1
        BT, BN, BX = {}, {}, Co.EXPANDED
        for k, v in pairs(T) do BT[k] = v end
        for k, v in pairs(N) do BN[k] = v end
      end
      local h1 = p and hash(ser(p, {})) or -1
      if h and h1 ~= h then fails = fails + 1; print("   ECHEC : plan different d'une passe a l'autre") end
      h = h1
    end
    total = total + dt
    out_ref[cs[1]] = h
    local ref = REF[cs[1]] or S46[cs[1]]
    local same = ref == nil and "?" or (ref == h and "=" or "DIFFERENT")
    if ref and ref ~= h then fails = fails + 1 end
    local st = p and p.stats or {}
    print(string.format("== %-26s %8.0f ms  empreinte %d %s  foreuses %s fours %s coffres %d refusees %d swap %s why %s",
      cs[1], dt * 1000, h, same, tostring(st.drills), tostring(st.furnaces), p and Ch.head_chests(p) or -1,
      p and p.refused and #p.refused or 0, tostring(p and p.order_swapped ~= nil), tostring(why)))
    print(string.format("   pas : %d plan_order, le plus long %.0f ms", PAS_N, PAS_MAX * 1000))
    if p and p.coffre_cost then print(string.format("   coffre_cost %d %% sur %d colonne(s)", p.coffre_cost, p.coffre_cols or 0)) end
    for _, c in ipairs(st.coal or {}) do print(string.format("   charbon cote %d : voie %s, %s", c.side, tostring(c.voie), tostring(c.why))) end
    T, N = BT, BN
    local names = {}
    for k in pairs(T) do names[#names + 1] = k end
    table.sort(names, function(a, b) return T[a] > T[b] end)
    for _, k in ipairs(names) do
      print(string.format("   %-16s %8.1f ms %5.1f %%  %6d appels", k, T[k] * 1000, 100 * T[k] / dt, N[k]))
    end
    print(string.format("   etats Co.route : %d", BX))
  end
end
print(string.format("TOTAL %.0f ms", total * 1000))
if ARGS["--ref"] then
  local f = io.open(REF_PATH, "w")
  f:write("-- s49 opti : empreintes des plans de v0.7.107 (avant l'optimisation), tests/perf_champ_bench.lua\nreturn {\n")
  for _, cs in ipairs(CASES) do if out_ref[cs[1]] then f:write(string.format("  [%q] = %d,\n", cs[1], out_ref[cs[1]])) end end
  f:write("}\n")
  f:close()
  print("references ecrites : " .. REF_PATH)
end
if fails > 0 then print(string.format("ECHEC : %d plan(s) different(s)", fails)); os.exit(1) end
