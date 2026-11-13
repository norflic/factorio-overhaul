-- Banc hors jeu du lot S42 TAPIS-TEINTES (chantier 2.4 du DC) : deux paliers de tapis n'ont jamais le même aspect.
--   lua5.2 tests/s42_tapis-teintes_test.lua      -> [S42-TAPIS-TEINTES] BILAN : N OK, 0 ECHEC(S)
-- §1 teintes des rangs toutes distinctes ; §2 plan (paliers du jeu intacts, doublons teintés, une vitesse = une teinte) ;
-- §3 la passe du stade data rejouée sur des prototypes fictifs (planches partagées, hr_version, icônes, objets) ;
-- §4 animation proportionnelle à la vitesse ; §5 déterminisme ; §6 mutants.
package.path = "./?.lua;" .. package.path
local T = require("shared.content.tapis_teintes")

local ok_n, fail_n = 0, 0
local function check(cond, what, detail)
  if cond then ok_n = ok_n + 1 else
    fail_n = fail_n + 1
    print("ECHEC " .. what .. (detail and (" : " .. tostring(detail)) or ""))
  end
end
local function near(a, b) return math.abs(a - b) < 1e-9 end

local function deepcopy(t, seen)
  if type(t) ~= "table" then return t end
  seen = seen or {}
  if seen[t] then return seen[t] end
  local c = {}
  seen[t] = c
  for k, v in pairs(t) do c[deepcopy(k, seen)] = deepcopy(v, seen) end
  return c
end
table.deepcopy = table.deepcopy or deepcopy

-- §1 teintes : 60 rangs, 60 teintes ; aucune n'est le blanc (une teinte blanche ne change rien)
do
  local seen, dup, white = {}, nil, nil
  for slot = 1, 60 do
    local k = T.tint_key(T.tint(slot))
    if seen[k] then dup = slot .. " = " .. seen[k] end
    seen[k] = slot
    if k == "1.000/1.000/1.000/1.000" then white = slot end
  end
  check(not dup, "60 rangs, 60 teintes distinctes", dup)
  check(not white, "aucune teinte blanche", white)
  check(T.tint_key(T.tint(3)) == T.tint_key(T.tint(3)), "teinte d'un rang stable")
end

-- Prototypes fictifs : trois paliers « du jeu » (planches propres), puis des paliers du mod clonés du troisième (mêmes tables).
local J, R, B = 0.03125, 0.0625, 0.09375
local KINDS = { "transport-belt", "underground-belt", "splitter" }
local function sheet(file) -- même forme que les planches du jeu : couche + hr_version
  return { animation_set = { filename = file .. ".png", frame_count = 16, direction_count = 20,
    hr_version = { filename = "hr-" .. file .. ".png", frame_count = 16, direction_count = 20, scale = 0.5 } } }
end
local function structure(file)
  return { north = { filename = file .. "-north.png", hr_version = { filename = "hr-" .. file .. "-north.png" } },
    east = { filename = file .. "-east.png", hr_version = { filename = "hr-" .. file .. "-east.png" } } }
end
local function fixture(extra)
  local raw = { ["transport-belt"] = {}, ["underground-belt"] = {}, splitter = {}, item = {} }
  local sets = {}
  local function tier(prefix, speed, look)
    sets[look] = sets[look] or { belt = sheet(look .. "belt"), ug = structure(look .. "underground"), sp = structure(look .. "splitter") }
    local s = sets[look]
    local function add(kind, base, fields)
      local name = prefix .. base
      local p = { type = kind, name = name, speed = speed, animation_speed_coefficient = 32,
        icon = "icons/" .. look .. base .. ".png", icon_size = 64, icon_mipmaps = 4, belt_animation_set = s.belt }
      for k, v in pairs(fields) do p[k] = v end
      raw[kind][name] = p
      raw.item[name] = { type = "item", name = name, place_result = name, icon = p.icon, icon_size = 64, icon_mipmaps = 4 }
    end
    add("transport-belt", "transport-belt", {})
    add("underground-belt", "underground-belt", { structure = s.ug })
    add("splitter", "splitter", { structure = s.sp, structure_patch = s.sp })
  end
  tier("", J, "")
  tier("fast-", R, "fast-")
  tier("express-", B, "express-")
  for _, e in ipairs(extra or {}) do tier(e.prefix, e.speed, e.look) end
  return raw
end
local MOD = { { prefix = "p4-", speed = 0.125, look = "express-" }, { prefix = "p5-", speed = 0.1875, look = "express-" },
  { prefix = "p6-", speed = 1.0, look = "fast-" } }

local function entries_of(raw)
  local out = {}
  for _, kind in ipairs(KINDS) do
    local names = {}
    for n in pairs(raw[kind]) do names[#names + 1] = n end
    table.sort(names)
    for _, n in ipairs(names) do
      out[#out + 1] = { key = kind .. "/" .. n, kind = kind, speed = raw[kind][n].speed, sig = T.signature(raw[kind][n]) }
    end
  end
  return out
end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

-- §2 plan
do
  local plan, census = T.plan(entries_of(fixture()))
  check(count(plan) == 0, "paliers du jeu seuls : rien à teindre", count(plan))
  check(census.tiers == 3 and census.entries == 9 and #census.shared == 0, "recensement du jeu : 3 paliers, 9 prototypes, 0 doublon")
  local plan2, census2 = T.plan(entries_of(fixture(MOD)))
  check(count(plan2) == 9 and #census2.shared == 9 and census2.tiers == 6, "3 paliers clonés : 9 doublons teintés", count(plan2))
  check(not plan2["transport-belt/express-transport-belt"] and not plan2["transport-belt/transport-belt"], "le palier d'origine garde son aspect")
  local a, b, c = plan2["transport-belt/p4-transport-belt"], plan2["transport-belt/p5-transport-belt"], plan2["transport-belt/p6-transport-belt"]
  check(a and b and c and T.tint_key(a.tint) ~= T.tint_key(b.tint) and T.tint_key(b.tint) ~= T.tint_key(c.tint)
    and T.tint_key(a.tint) ~= T.tint_key(c.tint), "trois paliers clonés : trois teintes")
  check(a and T.tint_key(a.tint) == T.tint_key(plan2["underground-belt/p4-underground-belt"].tint)
    and T.tint_key(a.tint) == T.tint_key(plan2["splitter/p4-splitter"].tint), "tapis, souterrain et répartiteur d'un palier : même teinte")
  -- deux prototypes de MÊME vitesse et de même aspect : deux teintes quand même
  local twin = { { key = "a", kind = "k", speed = 1, sig = "s" }, { key = "b", kind = "k", speed = 2, sig = "s" }, { key = "c", kind = "k", speed = 2, sig = "s" } }
  local p3 = T.plan(twin)
  check(p3.b and p3.c and not p3.a and T.tint_key(p3.b.tint) ~= T.tint_key(p3.c.tint), "même vitesse, même aspect : teintes distinctes")
end

-- §3 la passe du stade data, rejouée
local LOGS = {}
local function run_pass(raw)
  data = { raw = raw }
  local old_log = log
  log = function(s) LOGS[#LOGS + 1] = s end
  dofile("prototypes/tapis_teintes.lua")
  log = old_log
  data = nil
  return raw
end
local function all_distinct(raw)
  for _, kind in ipairs(KINDS) do
    local seen = {}
    local names = {}
    for n in pairs(raw[kind]) do names[#names + 1] = n end
    table.sort(names)
    for _, n in ipairs(names) do
      local sig = T.signature(raw[kind][n])
      if seen[sig] then return false, kind .. " : " .. n .. " = " .. seen[sig] end
      seen[sig] = n
    end
  end
  return true
end
do
  local before = fixture(MOD)
  check(not all_distinct(before), "avant la passe : des paliers partagent un aspect")
  local raw = run_pass(fixture(MOD))
  local ok, why = all_distinct(raw)
  check(ok, "après la passe : deux paliers n'ont jamais le même aspect", why)
  check(LOGS[#LOGS] and LOGS[#LOGS]:find("restants : aucun", 1, true), "journal : aucun doublon restant", LOGS[#LOGS])
  for _, kind in ipairs(KINDS) do
    for _, n in ipairs({ "", "fast-", "express-" }) do
      local name = n .. kind
      check(T.signature(raw[kind][name]) == T.signature(before[kind][name]) and raw[kind][name].icons == nil,
        "palier du jeu intact : " .. name)
    end
  end
  local belt = raw["transport-belt"]["p4-transport-belt"]
  local set = belt.belt_animation_set.animation_set
  check(set.tint and set.hr_version.tint and T.tint_key(set.tint) == T.tint_key(set.hr_version.tint), "couche et hr_version teintées pareil")
  check(raw["transport-belt"]["express-transport-belt"].belt_animation_set.animation_set.tint == nil, "la planche d'origine n'est pas teintée (copie)")
  check(belt.icons and T.tint_key(belt.icons[1].tint) == T.tint_key(set.tint) and belt.icons[1].icon == belt.icon
    and belt.icons[1].icon_size == 64, "icône de l'entité teintée de la même couleur")
  local item = raw.item["p4-transport-belt"]
  check(item.icons and T.tint_key(item.icons[1].tint) == T.tint_key(set.tint), "icône d'inventaire teintée de la même couleur")
  check(raw.item["express-transport-belt"].icons == nil, "icône d'inventaire du palier d'origine intacte")
  local sp = raw.splitter["p5-splitter"]
  check(sp.structure.north.tint and sp.structure_patch.east.hr_version.tint and
    T.tint_key(sp.structure.north.tint) == T.tint_key(raw["transport-belt"]["p5-transport-belt"].belt_animation_set.animation_set.tint),
    "répartiteur : structure et patch à la teinte du palier")
  check(T.tint_key(sp.structure.north.tint) == T.tint_key(T.tint(2)), "une seule application (structure et patch partagés non teintés deux fois)",
    T.tint_key(sp.structure.north.tint))
  -- teinte déjà présente : multipliée, pas écrasée
  local p = { belt_animation_set = { animation_set = { filename = "x.png", tint = { r = 0.5, g = 0.5, b = 0.5, a = 1 } } } }
  T.apply(p, { r = 0.4, g = 1, b = 0.5, a = 1 })
  local t = p.belt_animation_set.animation_set.tint
  check(near(t.r, 0.2) and near(t.g, 0.5) and near(t.b, 0.25), "teinte existante multipliée")
  -- seconde passe : rien ne change (idempotente)
  local sig1 = T.signature(belt)
  run_pass(raw)
  check(T.signature(raw["transport-belt"]["p4-transport-belt"]) == sig1, "passe rejouée : aucun changement")
end

-- §4 animation proportionnelle à la vitesse
do
  check(T.coefficient(J) == 32 and T.coefficient(R) == 32 and T.coefficient(B) == 32, "paliers du jeu : coefficient 32")
  check(near(T.coefficient(0.125) * 0.125 / (T.coefficient(J) * J), 0.125 / J), "animation proportionnelle à la vitesse (× 4 à vitesse × 4)")
  check(T.coefficient(1.0) * 1.0 <= 7 + 1e-9 and T.coefficient(1.0) < 32, "palier très rapide : pas de repli de l'animation", T.coefficient(1.0))
  check(T.coefficient(nil) == 32 and T.coefficient(0) == 32, "vitesse invalide : coefficient du jeu")
  local raw = run_pass(fixture(MOD))
  check(raw["transport-belt"]["p4-transport-belt"].animation_speed_coefficient == 32, "palier cloné : coefficient 32")
  check(near(raw["transport-belt"]["p6-transport-belt"].animation_speed_coefficient, 7), "palier cloné très rapide : coefficient borné")
  check(raw["transport-belt"]["express-transport-belt"].animation_speed_coefficient == 32, "palier du jeu : coefficient inchangé")
end

-- §5 déterminisme : deux passes sur deux jeux identiques rendent les mêmes aspects
do
  local a, b = run_pass(fixture(MOD)), run_pass(fixture(MOD))
  local same = true
  for _, kind in ipairs(KINDS) do
    for n, p in pairs(a[kind]) do
      if T.signature(p) ~= T.signature(b[kind][n]) then same = false end
    end
  end
  check(same, "déterminisme")
end

-- §6 mutants : chaque règle cassée est vue
local function mutant(what, set, unset, still_ok)
  set()
  local ok, res = pcall(still_ok)
  unset()
  check(not (ok and res), "mutant vu : " .. what)
end
local TINT, PLAN = T.tint, T.plan
mutant("teinte unique pour tous les rangs", function() T.tint = function() return { r = 0.4, g = 1, b = 0.45, a = 1 } end end,
  function() T.tint = TINT end, function() return (all_distinct(run_pass(fixture(MOD)))) end)
mutant("plan vide (rien n'est teinté)", function() T.plan = function(e) return {}, { tiers = 0, entries = #e, shared = {} } end end,
  function() T.plan = PLAN end, function() return (all_distinct(run_pass(fixture(MOD)))) end)
mutant("teinte blanche", function() T.tint = function() return { r = 1, g = 1, b = 1, a = 1 } end end,
  function() T.tint = TINT end, function()
    local raw = run_pass(fixture(MOD))
    return T.tint_key(raw["transport-belt"]["p4-transport-belt"].belt_animation_set.animation_set.tint)
      ~= T.tint_key(raw["transport-belt"]["p5-transport-belt"].belt_animation_set.animation_set.tint)
  end)

print(string.format("[S42-TAPIS-TEINTES] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
