--[[
  s52 bandes (priorité du DC : gels de 2 à 5 s d'UNE variante du plan de gisement, carte à 600 %) : plan_once en machine à états
  (Ch.once_begin / Ch.once_step / Ch.once_result), un pas de Ch.plan_step = UNE étape (une phase, une bande, un réseau du charbon, ...).
  1. Même plan qu'avant s52 (empreintes du champ.lua de release-0.6.77, Ch.plan d'un bloc) : cadres neufs à 1, 2 et 3 variantes, sans
     charbon, à coffres, four électrique, bande seule d'un cadre figé ; pas à pas == Ch.plan.
  2. État sans fonction après chaque pas (contexte délié) ; étapes bornées : une bande ou une phase par pas, au plus un plan_order fini.
  3. Deux séquences entrelacées pas à pas (deux avant-postes dans la file FRAME_WAIT) : chacune donne son plan (aucun état caché partagé).
  4. Câblage : Champ.inner_step (script/team/champ.lua), Mig.INNER_GAP court entre étapes, Mig.STEP_GAP gardé entre variantes.
  Usage, depuis la racine du mod :   lua5.2 tests/s52_bandes_test.lua
]]
package.path = "./?.lua;" .. package.path
local Ch = require("shared.team.champ")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

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
local function ph(p, why) return p and hash(ser(p, {})) or ("nil:" .. tostring(why)) end

-- une fonction trouvée dans l'état (hors spec, donnée d'entrée ; hors `skip`), avec son chemin (test seul : ordre de pairs sans effet)
local function find_fn(v, path, seen, skip)
  if type(v) == "function" then return path end
  if type(v) ~= "table" or seen[v] then return nil end
  seen[v] = true
  for k, x in pairs(v) do
    if k ~= "spec" and k ~= skip and (type(x) == "table" or type(x) == "function") then
      local r = find_fn(x, path .. "." .. tostring(k), seen, skip)
      if r then return r end
    end
  end
  return nil
end

local BELTS3 = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }
local function ellipse(cx, cy, a, b)
  local out = {}
  for x = cx - a, cx + a do for y = cy - b, cy + b do if ((x - cx) / a) ^ 2 + ((y - cy) / b) ^ 2 <= 1 then out[#out + 1] = x; out[#out + 1] = y end end end
  return out
end
local function disc(cx, cy, r)
  local out = {}
  for x = cx - r, cx + r do for y = cy - r, cy + r do if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r then out[#out + 1] = x; out[#out + 1] = y end end end
  return out
end
local function spec46(ore, o)
  return { ore = ore, blocked = {}, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = BELTS3, furnace = o.furnace or { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 }, inserter = { rate = 0.83 },
    target = { x = 1000, y = 0 }, max_side = 8, design = "colonne", axis = o.axis,
    coal = o.coal and { tiles = o.coal, rate = 0.5 } or nil, logistics = { splitter = true, underground = 5 }, frame = o.frame }
end
local function split(str, sep)
  local out = {}
  if str == nil or str == "" then return out end
  for part in (str .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
  return out
end
local function nums(str) local out = {} for _, x in ipairs(split(str, ",")) do out[#out + 1] = tonumber(x) end return out end
local function set(str) local out = {} for _, x in ipairs(split(str, ",")) do out[tonumber(x)] = true end return out end
local function load_spec(path)
  local h = assert(io.open(path, "r"))
  local line = h:read("*l")
  h:close()
  local fl = {}
  for _, kv in ipairs(split(line, "|")) do local k, v = kv:match("^([%w_]+)=(.*)$"); if k then fl[k] = v end end
  return function()
    local d, pl, fu, tg = nums(fl.drill), nums(fl.pole), split(fl.furnace, ","), nums(fl.target)
    local belts = {}
    for _, x in ipairs(split(fl.belts, ";")) do belts[#belts + 1] = { lane = tonumber(x) } end
    return { ore = nums(fl.ore), blocked = set(fl.blocked), mine = set(fl.mine), soft = fl.soft ~= "" and set(fl.soft) or nil,
      drill = { size = d[1], reach = d[2], rate = d[3] }, pole = { reach = pl[1], wire = pl[2] }, belts = belts,
      furnace = { size = tonumber(fu[1]), rate = tonumber(fu[2]), fuel = fu[3] == "true", fuel_rate = tonumber(fu[4]) },
      inserter = { rate = tonumber(fl.ins) }, target = { x = tg[1], y = tg[2] }, max_side = tonumber(fl.max_side), design = "colonne",
      logistics = { underground = tonumber(fl.ug), splitter = fl.splitter == "true" }, coal = { tiles = nums(fl.coal), rate = tonumber(fl.coalrate) },
      ug_tiles = {} }
  end
end
-- bande seule : le cadre du plan de « ellipse 45x30 », sa deuxième bande
local function band_only()
  local p = Ch.plan(spec46(ellipse(0, 0, 45, 30), { coal = ellipse(0, 50, 8, 8) }))
  local pr = p.bands[2].pr
  local fr = {}
  for k, v in pairs(p.frame) do fr[k] = v end -- copie du cadre (pas une décision)
  fr.only = { [pr] = true }
  return spec46(ellipse(0, 0, 45, 30), { coal = ellipse(0, 50, 8, 8), frame = fr })
end

-- { nom, spec neuve, empreinte du plan de release-0.6.77 (Ch.plan d'avant s52, d'un bloc ; lua5.2 sur le champ.lua de 7b4ebf93) }
local CASES = {
  { "petit", function() return spec46(ellipse(0, 0, 12, 9), { coal = ellipse(0, 20, 5, 5) }) end, 1169538760 },
  { "ellipse 45x30", function() return spec46(ellipse(0, 0, 45, 30), { coal = ellipse(0, 50, 8, 8) }) end, 988782013 },
  { "disque sans charbon", function() return spec46(disc(0, 0, 20), {}) end, 1195242882 },
  { "joueur 271828182", load_spec("tests/fixtures/champ_spec_player_271828182.txt"), 1105317308 },
  { "coffres (sans four)", function() local s = spec46(disc(0, 0, 18), {}); s.furnace = nil; return s end, nil },
  { "four electrique", function() return spec46(ellipse(0, 0, 30, 16), { furnace = { size = 2, rate = 0.625, fuel = false } }) end, nil },
  { "bande seule (cadre fige)", band_only, nil },
}
local REF77 = dofile("tests/s52_bandes_ref.lua")
for _, cs in ipairs(CASES) do cs[3] = cs[3] or REF77[cs[1]] end

print("== s52 bandes : plan_once par étapes, même plan qu'avant")
local hs_of = {}
for _, cs in ipairs(CASES) do
  local st = Ch.plan_begin(cs[2]())
  local steps, fn_at, ends_ok, band_steps = 0, nil, true, 0
  local done = false
  while not done and steps < 20000 do
    local o0 = Ch.ORDERS
    local cur = st.cur
    local stage0 = cur and cur.o.once and cur.o.once.stage
    done = Ch.plan_step(st)
    steps = steps + 1
    if Ch.ORDERS - o0 > 1 then ends_ok = false end
    if stage0 == "band" then band_steps = band_steps + 1 end
    -- la mémoire de la séquence (st.memo, grande) relue tous les 16 pas et à la fin ; le reste de l'état à chaque pas
    fn_at = fn_at or find_fn(st, "st", {}, (steps % 16 ~= 0 and not done) and "memo" or nil)
  end
  local hs = ph(Ch.plan_result(st))
  hs_of[cs[1]] = hs
  check(done, cs[1] .. " : séquence finie")
  check(hs == cs[3], string.format("%s : empreinte %s == release-0.6.77 %s", cs[1], tostring(hs), tostring(cs[3])))
  local hp = ph(Ch.plan(cs[2]()))
  check(hp == hs, string.format("%s : pas à pas == Ch.plan (%s)", cs[1], tostring(hp)))
  check(fn_at == nil, string.format("%s : état sans fonction après chaque pas (%s)", cs[1], tostring(fn_at)))
  check(ends_ok and st.k == steps and st.n >= 1 and st.n <= 4, string.format("%s : %d pas, %d variante(s), au plus une finie par pas", cs[1], steps, st.n))
  print(string.format("  %s : %d variante(s) en %d pas (%d pas de bande), empreinte %s", cs[1], st.n, steps, band_steps, tostring(hs)))
end

-- étapes bornées : la première variante d'un cadre neuf fait la recherche de phase en `pas` étapes (une phase par pas), puis une bande par pas
do
  local s = Ch.once_begin(spec46(ellipse(0, 0, 45, 30), { coal = ellipse(0, 50, 8, 8) }))
  local seen, per = {}, {}
  local n = 0
  while not Ch.once_step(s) do
    n = n + 1
    seen[#seen + 1] = s.stage
    if s.stage == "band" or s.stage == "phase" then per[s.stage] = (per[s.stage] or 0) + 1 end
    check(s.c == nil or s.c.free == nil, "contexte délié entre deux étapes")
  end
  local p = Ch.once_result(s)
  -- (étape laissée en « phase » : après init, puis après chacune des phases 0 .. pas - 2 ; la dernière passe aux bandes)
  check(p ~= nil and (per.phase or 0) == 2 * 3 + 2, string.format("recherche de phase : une phase par étape (%s étapes en phase)", tostring(per.phase)))
  check(p ~= nil and (per.band or 0) >= #p.bands - 1, string.format("une bande par étape (%s étapes pour %d bandes)", tostring(per.band), p and #p.bands or -1))
  check(n >= #p.bands + 8, string.format("plan_once en %d étapes (au moins bandes + phases)", n))
  -- plan_once d'un bloc (enchaîné) == pas à pas
  local s2 = Ch.once_begin(spec46(ellipse(0, 0, 45, 30), { coal = ellipse(0, 50, 8, 8) }))
  while not Ch.once_step(s2) do end
  check(ph(Ch.once_result(s2)) == ph(p), "Ch.once_step enchaîné : même plan")
  -- données invalides : fini dès la première étape, raison rendue
  local bad = Ch.once_begin({ ore = {} })
  check(Ch.once_step(bad) and select(2, Ch.once_result(bad)) == "donnees", "spec invalide : nil, « donnees » en une étape")
end

-- deux séquences entrelacées (deux avant-postes dans la file) : chacune son plan, comme seule
do
  local a = Ch.plan_begin(CASES[2][2]())
  local b = Ch.plan_begin(CASES[4][2]())
  local da, db = false, false
  local guard = 0
  while not (da and db) and guard < 40000 do
    guard = guard + 1
    if not da then da = Ch.plan_step(a) end
    if not db then db = Ch.plan_step(b) end
  end
  check(ph(Ch.plan_result(a)) == hs_of[CASES[2][1]] and ph(Ch.plan_result(b)) == hs_of[CASES[4][1]],
    "deux séquences entrelacées : chacune le plan qu'elle a seule")
  -- reprise : séquence coupée (mémoire locale perdue au chargement), recommencée sur une spec neuve : même plan
  local c = Ch.plan_begin(CASES[2][2]())
  for _ = 1, 7 do Ch.plan_step(c) end
  local d = Ch.plan_begin(CASES[2][2]())
  while not Ch.plan_step(d) do end
  check(ph(Ch.plan_result(d)) == hs_of[CASES[2][1]], "séquence coupée au milieu d'une variante puis recommencée : même plan")
  -- st.inner : vrai au milieu d'une variante, faux quand le pas suivant commence une variante
  local e = Ch.plan_begin(CASES[2][2]())
  local inner_seen, boundary_seen = false, false
  local n0 = 0
  repeat
    local fin = Ch.plan_step(e)
    if e.inner then inner_seen = true end
    if e.n ~= n0 then
      check(not e.inner, "variante finie : le pas suivant commence une variante (st.inner faux)")
      boundary_seen, n0 = true, e.n
    end
  until fin
  check(inner_seen and boundary_seen, "st.inner vu au milieu d'une variante et faux à sa fin")
end

print("== s52 bandes : câblage")
do
  local function read(p) local h = assert(io.open(p, "r")); local s = h:read("*a"); h:close(); return s end
  local mg = read("script/team/migration_champ.lua")
  local inner = tonumber(mg:match("Mig%.INNER_GAP = (%d+)"))
  local gap = tonumber(mg:match("Mig%.STEP_GAP = (%d+)"))
  check(inner and gap and inner < gap and inner <= 60, string.format("étapes espacées de Mig.INNER_GAP (%s) < Mig.STEP_GAP (%s)", tostring(inner), tostring(gap)))
  local ti = mg:find("local function frame_take(", 1, true)
  local te = ti and mg:find("\nend\n", ti, true)
  local tb = (ti and te) and mg:sub(ti, te) or ""
  local a1 = tb:find("NEXT_STEP = tick + Mig.STEP_GAP", 1, true)
  local a2 = tb:find("local frame, order = Champ.frame(f, surface, o)", 1, true)
  local a3 = tb:find("if Champ.inner_step(f, o.id) then NEXT_STEP = tick + Mig.INNER_GAP end", 1, true)
  check(a1 and a2 and a3 and a1 < a2 and a2 < a3, "frame_take : STEP_GAP par défaut, INNER_GAP après une étape interne")
  local ch = read("script/team/champ.lua")
  local ci = ch:find("function Champ.inner_step(f, oid)", 1, true)
  local ce = ci and ch:find("\nend\n", ci, true)
  local cb = (ci and ce) and ch:sub(ci, ce) or ""
  check(cb:find("SEQ[okey(f, oid)]", 1, true) ~= nil and cb:find("seq.st.inner == true", 1, true) ~= nil, "Champ.inner_step lit la séquence locale (SEQ)")
  local sh = read("shared/team/champ.lua")
  check(not sh:find("global%s*[%.%[]"), "shared/team/champ.lua ne nomme pas global")
end

print(string.format("s52 bandes : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
