-- Lot CHAUDIERES : réserve des brûleurs retirée du coffre du QG avant la centrale = tournées DUES seulement (Cc.tour_reserve,
-- shared/team/charbon_centrale.lua). Lancer : lua5.2 tests/charbon_reserve_test.lua
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1; print("ECHEC : " .. msg) end end

local path = "shared/team/charbon_centrale.lua"
local fh = assert(io.open(path, "rb")); local SRC = fh:read("*a"); fh:close()
local function load_rule(mut)
  local s = SRC
  if mut then
    local s2, n = mut(SRC)
    assert(n and n > 0, "mutant sans effet")
    s = s2
  end
  return assert(load(s, "=charbon_centrale"))()
end

-- valeurs de banc (config : niveau 10, seuil bas 3) et données changées (niveau 20, seuil 6 : rien en dur)
local function scenario(Cc, fill, low)
  local r = {}
  -- banc CHAUDIERES graine 2507543475, player vers 10 min : 50 charbons au coffre, fours à 6, foreuses de fer à 4 à 9 : aucune tournée due
  local calm = { { fill = fill, levels = { 6, 6 } }, { fill = fill, levels = { 4, 9, 5, 7 } } }
  r.calm = Cc.tour_reserve(calm, low)
  r.free_calm = Cc.free_fuel(50, r.calm)
  r.fill_calm = Cc.refill(0, 0.45, r.free_calm, 1600, false)
  -- un brûleur sous le seuil : le groupe entier est complété par la tournée (garde du lot BRULEURS-A-SEC conservée)
  local dry = { { fill = fill, levels = { 6, 6 } }, { fill = fill, levels = { 0, 9, 5, 7 } } }
  r.dry = Cc.tour_reserve(dry, low)
  r.free_dry = Cc.free_fuel(20, r.dry)
  r.fill_dry = Cc.refill(0, 0.45, r.free_dry, 1600, false)
  -- au seuil exact : pas sous le seuil (même comparaison que Outposts.status : fuel < T.fuel_low)
  r.edge = Cc.tour_reserve({ { fill = fill, levels = { low } } }, low)
  r.none = Cc.tour_reserve({}, low)
  return r
end

local function suite(Cc)
  local fails0 = fail_n
  local r = scenario(Cc, 10, 3)
  check(r.calm == 0, "aucun brûleur sous 3 : rien de réservé (" .. tostring(r.calm) .. ")")
  check(r.free_calm == 50, "le coffre entier est libre pour la centrale")
  check(r.fill_calm.due == true and r.fill_calm.count == 50, "la centrale à sec reçoit ses 50 charbons")
  check(r.dry == 10 + 1 + 5 + 3, "groupe avec un brûleur à 0 : complément du groupe à 10 (19), l'autre groupe rien (" .. tostring(r.dry) .. ")")
  check(r.free_dry == 1, "20 au coffre, 19 réservés : 1 libre")
  check(r.edge == 0, "brûleur au seuil exact : pas de tournée due")
  check(r.none == 0, "aucun groupe : 0")
  local r2 = scenario(Cc, 20, 6)
  check(r2.calm == (20 - 4) + (20 - 9) + (20 - 5) + (20 - 7), "données changées (seuil 6) : 4 < 6, le second groupe dû (55), le premier à 6 non (" .. tostring(r2.calm) .. ")")
  check(r2.dry == 20 + 11 + 15 + 13, "données changées : niveau 20 lu du groupe (59)")
  return fail_n == fails0
end

print("== 1. Règle")
suite(load_rule())

print("== 2. Mutants (chacun doit échouer)")
local mutants = {
  { "réserve de tous les brûleurs (avant le lot)", function(s) return s:gsub("if due then n = n %+ need end", "n = n + need") end },
  { "seuil au sens large", function(s) return s:gsub("if x < low then due = true end", "if x <= low then due = true end") end },
  { "niveau visé ignoré", function(s) return s:gsub("%(g%.fill or 0%) %- x", "10 - x") end },
  { "réserve nulle (garde BRULEURS-A-SEC supprimée)", function(s) return s:gsub("if due then n = n %+ need end", "") end },
}
for _, m in ipairs(mutants) do
  local before = fail_n
  local quiet = print
  print = function() end
  local okload, Cc = pcall(load_rule, m[2])
  local passed = okload and suite(Cc)
  print = quiet
  fail_n = before
  check(not passed, "mutant « " .. m[1] .. " » tué")
end

print(string.format("[CHAUDIERES] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
