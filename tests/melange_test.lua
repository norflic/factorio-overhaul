--[[
  Tests hors jeu du lot MELANGE (retour du DC du 3/11 : « dans cette zone il est possible qu'il y ait 2 minerais ou plus [...] les
  minerais de charbon prennent la place des minerais de fer sur les convoyeurs »). Pur, aucune API Factorio.
  Usage, depuis la racine du mod :   lua5.2 tests/melange_test.lua

  1. zone d'une foreuse : portée tirée du rayon (base 2,49, niveaux agrandis, thermique), égale au relevé « centre de tuile < rayon » ;
  2. plan du champ (shared/team/champ.lua) sur un gisement de fer qui touche du charbon (bord, enclave, pointillé) : AUCUNE foreuse dont la
     zone touche une tuile étrangère (contrôle indépendant de la règle), le fer loin du charbon reste couvert comme sans charbon, et le
     contrôle du plan (champ_verif) dit « zones melangees 0 » ;
  3. sans tuile étrangère : plan identique à celui d'avant (aucune régression) ;
  4. tapis : objets étrangers à relever, « encombré » quand l'étranger est majoritaire ;
  5. mutants : chaque défaut injecté est vu.
]]
package.path = "./?.lua;" .. package.path

local M = require("shared.team.melange")
local Ch = require("shared.team.champ")
local Cv = require("shared.team.champ_verif")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local BELTS3 = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }
local function spec_of(ore, foreign)
  return { ore = ore, blocked = {}, foreign = foreign, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = BELTS3, furnace = { size = 2, rate = 0.3125, fuel = true }, inserter = { rate = 0.83 }, target = { x = 1000, y = 0 } }
end

-- gisement : fer sur un rectangle, charbon sur les tuiles `coal(x, y)` (prises au fer), plus une bande de charbon sous le fer
local function field(coal)
  local ore, foreign, fl = {}, {}, {}
  for x = 0, 59 do
    for y = 0, 23 do
      if coal(x, y) then foreign[Ch.key(x, y)] = true; fl[#fl + 1] = { x, y }
      else ore[#ore + 1] = x; ore[#ore + 1] = y end
    end
  end
  for x = 20, 34 do for y = 24, 29 do foreign[Ch.key(x, y)] = true; fl[#fl + 1] = { x, y } end end
  return ore, foreign, fl
end

-- contrôle INDÉPENDANT : tuiles minées d'une foreuse du plan relues par le centre de tuile (règle du moteur), sans M.zone
local function mixed_drills(plan, foreign, radius)
  local n = 0
  for _, e in ipairs(plan.ents) do
    if e.kind == "foreuse" then
      local hit = false
      for x = math.floor(e.x - radius) - 1, math.floor(e.x + radius) + 1 do
        for y = math.floor(e.y - radius) - 1, math.floor(e.y + radius) + 1 do
          local dx, dy = x + 0.5 - e.x, y + 0.5 - e.y
          if math.abs(dx) < radius and math.abs(dy) < radius and foreign[Ch.key(x, y)] then hit = true end
        end
      end
      if hit then n = n + 1 end
    end
  end
  return n
end

local function covered_far(plan, ore, fl, dist)
  local cov = {}
  for _, e in ipairs(plan.ents) do
    if e.kind == "foreuse" then
      for x = math.floor(e.x - 2.49), math.floor(e.x + 2.49) do
        for y = math.floor(e.y - 2.49), math.floor(e.y + 2.49) do
          if math.abs(x + 0.5 - e.x) < 2.49 and math.abs(y + 0.5 - e.y) < 2.49 then cov[Ch.key(x, y)] = true end
        end
      end
    end
  end
  local n, c = 0, 0
  for i = 1, #ore - 1, 2 do
    local x, y = ore[i], ore[i + 1]
    local far = true
    for _, t in ipairs(fl) do if math.abs(t[1] - x) <= dist and math.abs(t[2] - y) <= dist then far = false break end end
    if far then n = n + 1; if cov[Ch.key(x, y)] then c = c + 1 end end
  end
  return c, n
end

local function suite(rule)
  local ok_all = true
  local function chk(cond, msg) if not cond then ok_all = false end; if rule.report then check(cond, msg) end end
  -- 1. zone
  chk(rule.reach(3, 2.49) == 1, "portee foreuse electrique de base (3, 2,49) = 1, lu " .. tostring(rule.reach(3, 2.49)))
  chk(rule.reach(5, 3.49) == 1, "portee niveau agrandi (5, 3,49) = 1, lu " .. tostring(rule.reach(5, 3.49)))
  chk(rule.reach(2, 0.99) == 0, "portee foreuse thermique (2, 0,99) = 0, lu " .. tostring(rule.reach(2, 0.99)))
  chk(rule.reach(3, 2.5) == 1, "portee (3, 2,5) = 1 (centre a 3 tuiles = hors zone), lu " .. tostring(rule.reach(3, 2.5)))
  for _, c in ipairs({ { 3, 2.49 }, { 5, 3.49 }, { 2, 0.99 }, { 4, 2.99 }, { 7, 4.49 } }) do
    local s, rad = c[1], c[2]
    local r = rule.reach(s, rad)
    local x0, y0, x1, y1 = rule.zone(10, 20, s, r)
    local cx, cy = 10 + s / 2, 20 + s / 2
    local same = true
    for x = 0, 40 do
      for y = 10, 40 do
        local inr = x >= x0 and x <= x1 and y >= y0 and y <= y1
        if inr ~= rule.in_zone(x + 0.5 - cx, y + 0.5 - cy, rad) then same = false end
        local truth = math.abs(x + 0.5 - cx) < rad and math.abs(y + 0.5 - cy) < rad
        if inr ~= truth then same = false end
      end
    end
    chk(same, string.format("zone (cote %d, rayon %.2f) = tuiles dont le centre est a moins du rayon", s, rad))
  end
  chk(rule.count(0, 0, 4, 4, function(x, y) return x == 4 and y == 0 end) == 1, "count : une tuile vue au coin")
  -- 4. tapis et verdict de zone
  local t = { ["m"] = true }
  local b = rule.belt_verdict({ m = 3, c = 5 }, t)
  chk(b.majority and b.foreign == 5 and b.target == 3 and #b.clear == 1 and b.clear[1][1] == "c" and b.clear[1][2] == 5,
    "tapis 3 minerai / 5 etranger : encombre, 5 a relever")
  b = rule.belt_verdict({ m = 5, c = 1 }, t)
  chk(not b.majority and b.foreign == 1, "tapis 5 / 1 : pas encombre, 1 a relever")
  b = rule.belt_verdict({ m = 2, c = 2 }, t)
  chk(not b.majority, "tapis 2 / 2 : pas majoritaire")
  b = rule.belt_verdict({ z = 1, c = 2, m = 0 }, t)
  chk(b.majority and #b.clear == 2 and b.clear[1][1] == "c" and b.clear[2][1] == "z", "tapis sans minerai : deux etrangers, tries par nom")
  b = rule.belt_verdict({}, t)
  chk(not b.majority and b.foreign == 0 and #b.clear == 0, "tapis vide")
  local v, l = rule.zone_verdict({ { "m", 20 }, { "c", 3 } }, t)
  chk(v == "melange" and #l == 1 and l[1][1] == "c", "zone fer + charbon : melange")
  v, l = rule.zone_verdict({ { "m", 25 } }, t)
  chk(v == "ok" and #l == 0, "zone de fer seul : ok")
  v = rule.zone_verdict({ { "m", 25 }, { "c", 0 } }, t)
  chk(v == "ok", "ressource epuisee (0) : ok")
  return ok_all
end

section("1 et 4. zone, tapis, verdicts")
suite({ reach = M.reach, zone = M.zone, in_zone = M.in_zone, count = M.count, belt_verdict = M.belt_verdict,
  zone_verdict = M.zone_verdict, report = true })

section("2. plan du champ sur un gisement qui touche du charbon")
local CASES = {
  { "bord : charbon sous le fer", function() return false end },
  { "enclave de charbon 4 x 4 dans le fer", function(x, y) return x >= 40 and x <= 43 and y >= 8 and y <= 11 end },
  { "pointille : une tuile de charbon sur 37", function(x, y) return (x * 7 + y * 13) % 37 == 0 end },
}
local function plan_cases(report)
  local bad = 0
  for _, cs in ipairs(CASES) do
    local ore, foreign, fl = field(cs[2])
    local plan = Ch.plan(spec_of(ore, foreign))
    local base = Ch.plan(spec_of(ore, nil))
    local mx = plan and mixed_drills(plan, foreign, 2.49) or -1
    local rep = plan and Cv.verify(plan, spec_of(ore, foreign))
    local c, n = 0, 0
    local cb, nb = 0, 0
    if plan then c, n = covered_far(plan, ore, fl, 3); cb, nb = covered_far(base, ore, fl, 3) end
    local bmx = base and mixed_drills(base, foreign, 2.49) or 0
    if report then
      print(string.format("  %s : %d foreuses (%d sans la regle, dont %d melangees), fer loin du charbon couvert %d/%d (%d/%d sans la regle) ; %s",
        cs[1], plan and plan.stats.drills or 0, base and base.stats.drills or 0, bmx, c, n, cb, nb, rep and Cv.line(rep) or "-"))
      check(plan ~= nil and plan.stats.drills > 0, cs[1] .. " : un plan, des foreuses")
      check(mx == 0, cs[1] .. " : aucune foreuse dont la zone touche le charbon (controle independant), lu " .. mx)
      check(rep and rep.mixed == 0 and rep.ok, cs[1] .. " : champ_verif dit zones melangees 0 et ok")
      check(n > 0 and c >= math.floor(0.9 * cb), string.format("%s : fer loin du charbon couvert %d >= 90 %% de %d (sans la regle)", cs[1], c, cb))
      check(bmx > 0, cs[1] .. " : temoin, sans la regle des foreuses melangees existent (" .. bmx .. ")")
    end
    if mx ~= 0 then bad = bad + 1 end
  end
  return bad
end
plan_cases(true)

section("3. sans tuile etrangere : plan identique")
local function sig(plan)
  local t = {}
  for _, e in ipairs(plan.ents) do t[#t + 1] = string.format("%s %.1f %.1f %d", e.kind, e.x, e.y, e.dir) end
  return table.concat(t, ";")
end
do
  local ore = {}
  for x = 0, 59 do for y = 0, 23 do ore[#ore + 1] = x; ore[#ore + 1] = y end end
  local a, b2 = Ch.plan(spec_of(ore, nil)), Ch.plan(spec_of(ore, {}))
  check(a and b2 and sig(a) == sig(b2), "foreign absent ou vide : meme plan")
  local far = { [Ch.key(500, 500)] = true }
  local c3 = Ch.plan(spec_of(ore, far))
  check(c3 and sig(c3) == sig(a), "tuile etrangere loin du champ : meme plan")
  -- une tuile du minerai vise qui serait aussi notee etrangere reste du minerai (le minerai gagne)
  local self = { [Ch.key(10, 10)] = true }
  local c4 = Ch.plan(spec_of(ore, self))
  check(c4 and sig(c4) == sig(a), "tuile de minerai notee etrangere : ignoree")
  local d1, d2 = Ch.plan(spec_of(field(CASES[3][2]))), Ch.plan(spec_of(field(CASES[3][2])))
  check(d1 and d2 and sig(d1) == sig(d2), "determinisme avec charbon")
end

section("5. mutants")
local mutants, seen = 0, 0
local function mutant(name, detected)
  mutants = mutants + 1
  if detected then seen = seen + 1 end
  check(detected, "mutant non vu : " .. name)
end
local base = { reach = M.reach, zone = M.zone, in_zone = M.in_zone, count = M.count, belt_verdict = M.belt_verdict, zone_verdict = M.zone_verdict }
local function with(k, fn)
  local r = {}
  for _, n in ipairs({ "reach", "zone", "in_zone", "count", "belt_verdict", "zone_verdict" }) do r[n] = base[n] end
  r[k] = fn
  return r
end
mutant("portee tronquee (rayon - cote / 2)", not suite(with("reach", function(s, rad) return math.floor(rad - s / 2) end)))
mutant("portee + 1", not suite(with("reach", function(s, rad) return M.reach(s, rad) + 1 end)))
mutant("zone sans portee", not suite(with("zone", function(x, y, s, r) return x, y, x + s - 1, y + s - 1 end)))
mutant("in_zone large (<=)", not suite(with("in_zone", function(dx, dy, rad) return math.abs(dx) <= rad + 0.6 and math.abs(dy) <= rad + 0.6 end)))
mutant("encombre a egalite", not suite(with("belt_verdict", function(c, t)
  local r = M.belt_verdict(c, t); r.majority = r.foreign >= r.target and r.foreign > 0; return r end)))
mutant("le minerai releve aussi", not suite(with("belt_verdict", function(c, t)
  local r = M.belt_verdict(c, t); if (c.m or 0) > 0 then r.clear[#r.clear + 1] = { "m", c.m } end; return r end)))
mutant("verdict ignore les petites quantites", not suite(with("zone_verdict", function(f, t)
  local g = {}; for _, it in ipairs(f) do if it[2] >= 5 then g[#g + 1] = it end end; return M.zone_verdict(g, t) end)))
-- règle du plan coupée : le champ redevient mêlé, le contrôle indépendant le voit
do
  local keep = M.count
  M.count = function() return 0 end
  local bad = plan_cases(false)
  M.count = keep
  mutant("plan du champ sans la regle MELANGE", bad > 0)
end
-- champ_verif : une foreuse posée sur la zone mêlée dans un plan juste
do
  local ore, foreign = field(CASES[1][2])
  local spec = spec_of(ore, foreign)
  local plan = Ch.plan(spec)
  plan.ents[#plan.ents + 1] = { kind = "foreuse", x = 27.5, y = 23.5, size = 3, dir = 0, band = 1, group = 1 }
  local rep = Cv.verify(plan, spec)
  mutant("champ_verif : foreuse injectee sur le charbon", rep.mixed >= 1 and not rep.ok)
end
print(string.format("== mutants : %d/%d vus", seen, mutants))

print(string.format("[MELANGE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
