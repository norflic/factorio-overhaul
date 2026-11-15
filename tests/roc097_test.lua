--[[
  ROC-097 (DC, 15/11). Test PUR, deux défauts :
  1. Fonderies déportées (colonne ailleurs, Co.away) : « elles marchent pour le cuivre, pas pour le fer ni le charbon ». Cause (prouvée par
     le journal de 0.9.6, fo-logs/2026-11-15_FINAL-096-seul) : shared/team/champ.lua, ONCE.bare, `if colonne and not t.refused` :
       - un bout dont la colonne a été REFUSÉE faute de voie de charbon (passes du refus, Ch.refuse_keeps) ne cherchait jamais de colonne
         ailleurs : fer du joueur, bandes -97 -89 -33 puis -61 -45 -37 -13 refusées, 24 + 72 foreuses non posées ; le cuivre du joueur
         gardait son coffre de tête (refus trop coûteux) et ses colonnes ;
       - un champ sans colonne de fours (charbon, pierre : fonderie à coffres) n'avait AUCUN déport : 0 colonne ailleurs sur tous les
         champs de charbon et de pierre, foreuses non posées (émeraude charbon 18, ambre charbon 9, émeraude pierre 44).
     Coupe : Ch.away_ok (toujours vrai) et la fonderie à coffres posée ailleurs (Fd.away_layout, option `layout` de Co.away).
  2. Déblaiement (shared/team/champ_deblai.lua) : règle des obstacles mineurs retirés à la pose d'une pièce de champ.
  Chaque maillon a son MUTANT (substitution unique dans le source rechargé : la suite doit échouer).
  Lancement (racine du mod) : lua5.2 tests/roc097_test.lua   -> [ROC-097] BILAN : N OK, 0 ECHEC(S)
]]
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1; print("[ROC-097] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local SRC_CH = read("shared/team/champ.lua")
local SRC_CO = read("shared/team/champ_colonne.lua")
local SRC_DB = read("shared/team/champ_deblai.lua")
local function sub1(src, a, b, name)
  local i, j = src:find(a, 1, true)
  assert(i, "mutant introuvable : " .. name)
  assert(not src:find(a, j + 1, true), "mutant ambigu : " .. name)
  return src:sub(1, i - 1) .. b .. src:sub(j + 1)
end
local function load_mods(ch_src, co_src)
  for _, m in ipairs({ "shared.team.champ_colonne", "shared.team.champ", "shared.team.champ_verif" }) do package.loaded[m] = nil end
  package.loaded["shared.team.champ_colonne"] = assert(load(co_src, "=shared/team/champ_colonne.lua", "t", _ENV))()
  package.loaded["shared.team.champ"] = assert(load(ch_src, "=shared/team/champ.lua", "t", _ENV))()
  return package.loaded["shared.team.champ"], require("shared.team.champ_verif")
end

-- formes (mêmes conventions que tests/c2_pavage_test.lua)
local function K(x, y) return (x + 50000) * 100000 + (y + 50000) end
local function ellipse(cx, cy, a, b, skip)
  local out = {}
  for x = cx - a, cx + a do for y = cy - b, cy + b do
    if ((x - cx) / a) ^ 2 + ((y - cy) / b) ^ 2 <= 1 and not (skip and skip(x, y)) then out[#out + 1] = x; out[#out + 1] = y end
  end end
  return out
end
local function set_of(l, s) s = s or {} for i = 1, #l - 1, 2 do s[K(l[i], l[i + 1])] = true end return s end
local function spec_of(ore, o)
  o = o or {}
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for i = 1, #ore - 1, 2 do
    x0, x1 = math.min(x0, ore[i]), math.max(x1, ore[i])
    y0, y1 = math.min(y0, ore[i + 1]), math.max(y1, ore[i + 1])
  end
  local win = (y1 - y0 > x1 - x0) and { x0 - 10, y0 - 120, x1 + 10, y1 + 120 } or { x0 - 120, y0 - 10, x1 + 120, y1 + 10 }
  local res, foreign = set_of(ore), {}
  for _, l in ipairs(o.others or {}) do set_of(l, res); set_of(l, foreign) end
  local coal = o.coal or ellipse(0, 70, 8, 8)
  set_of(coal, res)
  return { ore = ore, blocked = o.blocked or {}, mine = {}, soft = {}, foreign = foreign, nforeign = 0, resources = res,
    drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = { { lane = 7.5 } }, furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 }, inserter = { rate = 0.83 },
    target = o.target or { x = 0, y = 200 }, max_side = 8, design = "colonne", window = win,
    coal = { tiles = coal, rate = 0.5, foreign = {}, nforeign = 0 }, logistics = o.logistics or { splitter = false }, ug_tiles = {} }
end
-- gisement entre deux autres ressources (aucune place de fonderie dans le prolongement des bandes)
local function entre()
  local cu, co = ellipse(75, 0, 32, 34), ellipse(-75, 0, 32, 34)
  local cs = set_of(co, set_of(cu))
  return spec_of(ellipse(0, 0, 48, 28, function(x, y) return cs[K(x, y)] end), { others = { cu, co }, coal = co })
end
-- champ SANS four (charbon, pierre) : fonderie à coffres
local function sans_four(spec) spec.furnace, spec.design = nil, nil return spec end
-- colonnes des deux bouts refusées (un seul bout refusé : l'autre prend toute la bande) faute de voie de charbon (même entrée que les passes du refus : spec.refuse)
local function refuse_side(Ch, spec)
  local p = Ch.plan(spec)
  local keys = {}
  for k in pairs(p.frame.cols or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  local ref, n = {}, 0
  for _, k in ipairs(keys) do
    for _, sd in ipairs({ "-1", "1" }) do
      if p.frame.cols[k][sd] then ref[k .. ":" .. sd] = true; n = n + 1 end
    end
  end
  spec.refuse, spec.axis, spec.once = ref, p.frame.axis, true -- (même orientation : mêmes bandes)
  return spec, n
end

-- spec.once : UN plan_once (la passe du refus elle-même, sans le choix des variantes qui garderait le plan sans refus)
local function once(Ch, spec)
  local s = Ch.once_begin(spec)
  while not Ch.once_step(s) do end
  return Ch.once_result(s)
end
local function measure(Ch, Cv, spec)
  local ok, p = pcall(spec.once and function(sp) return once(Ch, sp) end or Ch.plan, spec)
  if not ok then return { err = tostring(p) } end
  if not p then return { err = "pas de plan" } end
  local rep = Cv.verify(p, spec)
  return { cov = rep.elec, away = p.stats.away or 0, orphans = p.stats.orphans or 0, rep = rep, p = p }
end
local function valid(r)
  local rep = r.rep
  return rep and rep.overlaps == 0 and rep.blocked == 0 and rep.unpowered == 0 and (rep.mixed or 0) == 0 and (rep.junction or 0) == 0
    and rep.starved == 0 and rep.components <= 1 and rep.arms == 0
end

-- cas : { nom, spec(Ch), attendu(r) }
local CASES = {
  { "charbon-entre", function() return sans_four(entre()) end,
    function(r) return r.cov and r.cov >= 0.95 and r.away > 0 and r.orphans == 0 and valid(r) end },
  { "charbon-joueur", function() return sans_four(dofile("tests/fixtures/champ_joueur_dc.lua").spec) end,
    function(r) return r.cov and r.cov >= 0.80 and r.away > 0 and r.orphans == 0 and valid(r) end },
  { "fer-refusee", function(Ch) local s, n = refuse_side(Ch, spec_of(ellipse(0, 0, 45, 28))); assert(n > 0) return s end,
    function(r) return r.cov and r.cov >= 0.95 and r.away > 0 and r.orphans == 0 and valid(r) end },
}

local function suite(Ch, Cv, label, quiet)
  local all = true
  for _, c in ipairs(CASES) do
    local r = measure(Ch, Cv, c[2](Ch))
    local good = c[3](r) and true or false
    if not quiet then
      print(string.format("[ROC-097] %-8s %-15s couverture %s, colonnes ailleurs %s, foreuses non posees %s%s", label, c[1],
        r.cov and string.format("%3d %%", math.floor(100 * r.cov + 0.5)) or "?", tostring(r.away), tostring(r.orphans), r.err and (" ; " .. r.err) or ""))
      check(good, c[1])
    end
    all = all and good
  end
  return all
end

-- 1. code livré
local Ch, Cv = load_mods(SRC_CH, SRC_CO)
suite(Ch, Cv, "livre")
-- déterminisme
do
  local a = measure(Ch, Cv, sans_four(entre())).p
  local b = measure(Ch, Cv, sans_four(entre())).p
  local function sig(p) local t = {} for _, e in ipairs(p.ents) do t[#t + 1] = e.kind .. e.x .. ":" .. e.y .. ":" .. e.dir end return table.concat(t, " ") end
  check(a and b and sig(a) == sig(b), "charbon-entre : plan déterministe")
end

-- 2. mutants du déport
local MUT = {
  { "refus+four", "ch", "function Ch.away_ok(colonne, refused)\n  return true", "function Ch.away_ok(colonne, refused)\n  return colonne and not refused" },
  { "refus", "ch", "function Ch.away_ok(colonne, refused)\n  return true", "function Ch.away_ok(colonne, refused)\n  return not refused" },
  { "sans-four", "ch", "function Ch.away_ok(colonne, refused)\n  return true", "function Ch.away_ok(colonne, refused)\n  return colonne" },
  { "layout", "ch", "layout = (not colonne) and function(n) return Fd.away_layout(spec, t.side, n) end or nil,", "layout = nil," },
  { "co-layout", "co", "if o.layout then base, len, info0 = o.layout(count) else", "if false then else" },
}
local killed = 0
for _, m in ipairs(MUT) do
  local ch, co = SRC_CH, SRC_CO
  if m[2] == "ch" then ch = sub1(SRC_CH, m[3], m[4], m[1]) else co = sub1(SRC_CO, m[3], m[4], m[1]) end
  local MCh, MCv = load_mods(ch, co)
  local dead = not suite(MCh, MCv, m[1], true)
  print(string.format("[ROC-097] mutant %-10s -> %s", m[1], dead and "refusé" or "SURVIT"))
  check(dead, "mutant " .. m[1])
  if dead then killed = killed + 1 end
end
load_mods(SRC_CH, SRC_CO)

-- 3. déblaiement : règle pure et mutants
local function load_db(src) return assert(load(src, "=shared/team/champ_deblai.lua", "t", _ENV))() end
local function db_ok(Db)
  return Db.minor("tree", false) == true and Db.minor("tree", nil) == true
    and Db.minor("simple-entity", true) == true and Db.minor("simple-entity", false) == false
    and Db.minor("simple-entity-with-owner", true) == false and Db.minor("cliff", true) == false and Db.minor("container", false) == false
    and Db.applies({ site = "champ" }) == true and Db.applies({ site = "module" }) == false and Db.applies(nil) == false
    and Db.lazy({ site = "champ" }) == true and Db.lazy({}) == false
end
check(db_ok(load_db(SRC_DB)), "deblai : règle livrée")
local DBM = {
  { "arbre", 'if kind == "tree" then return true end', "" },
  { "rocher", 'return kind == "simple-entity" and rock == true', "return false" },
  { "tout-simple", 'return kind == "simple-entity" and rock == true', 'return kind == "simple-entity"' },
  { "champ", 'return spec ~= nil and spec.site == "champ"', "return false" },
  { "partout", 'return spec ~= nil and spec.site == "champ"', "return spec ~= nil" },
}
for _, m in ipairs(DBM) do
  local dead = not db_ok(load_db(sub1(SRC_DB, m[2], m[3], m[1])))
  print(string.format("[ROC-097] mutant deblai %-11s -> %s", m[1], dead and "refusé" or "SURVIT"))
  check(dead, "mutant deblai " .. m[1])
  if dead then killed = killed + 1 end
end
-- 4. le runtime appelle la règle à la pose (place_ghost) et pour l'étape « defrichage »
do
  local b = read("script/team/build.lua")
  check(b:find("and not (Build.deblai(surface, f, p, e) > 0 and can_place())", 1, true) ~= nil, "build : déblaiement avant le refus « obstacle »")
  check(b:find("x.prototype.count_as_rock_for_filtered_deconstruction", 1, true) ~= nil, "build : drapeau de rocher lu au prototype")
  local _, n = b:gsub("place_ghost%(surface, f, e, p%)", "")
  check(n == 6, "build : place_ghost reçoit le projet (définition et 5 appels d'un projet : " .. n .. ")")
  local _, z = b:gsub("not Build%.Db%.lazy%(p%.spec%)", "")
  check(z == 2, "build : un champ ne s'arrête pas à l'étape defrichage (" .. z .. ")")
end
print(string.format("[ROC-097] MUTANTS : %d / %d refusés", killed, #MUT + #DBM))
print(string.format("[ROC-097] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
