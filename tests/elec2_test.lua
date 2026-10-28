--[[
  Lot ELEC2 : kit des avant-postes (shared/team/config.lua, T.pair_kit) et plan de remplacement.
    §1 sans contexte électrique : exactement le kit d'avant (foreuse à combustible, réceptacle, combustible) ;
    §2 contexte électrique : la moitié des foreuses (une électrique en vaut `per`), le four seul brûle, les poteaux de la
       ligne ; un avant-poste de charbon ou de pierre (coffre) n'a aucun combustible ;
    §3 le planificateur des équipes lit ce kit (Planner.outpost_items) et le contexte ne fuit pas (nil par défaut) ;
    §4 mutant : le kit électrique ignorant `per` est vu.
  Usage : lua5.2 tests/elec2_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Planner = require("shared.team.planner")

local pass, fail = 0, 0
local function check(c, m)
  if c then pass = pass + 1 else fail = fail + 1 print("[ELEC2] ECHEC : " .. m) end
end
local function count(list, name)
  for _, it in ipairs(list) do if it[1] == name then return it[2] end end
  return 0
end

check(T.elec == nil, "§1 pas de contexte électrique par défaut")
for _, kind in ipairs(T.OUTPOST_ORDER) do
  local spec = T.outposts[kind]
  local k = T.pair_kit(kind, spec.drills)
  local fuel = kind == "coal" and 2 * spec.drills or T.fuel_per_burner * spec.drills * (spec.sink == "stone-furnace" and 2 or 1)
  check(count(k, T.DRILL) == spec.drills and count(k, spec.sink) == spec.drills and count(k, T.fuel) == fuel,
    "§1 kit à combustible inchangé : " .. kind)
  local p = Planner.outpost_items(kind)
  check(count(p, T.DRILL) == spec.drills, "§3 le planificateur lit le kit : " .. kind)
end

local function with_elec(per)
  T.elec = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do T.elec[kind] = { drill = "edrill", pole = "epole", poles = 12, per = per } end
end
with_elec(2)
for _, kind in ipairs(T.OUTPOST_ORDER) do
  local spec = T.outposts[kind]
  local k = T.pair_kit(kind, spec.drills)
  local m = math.ceil(spec.drills / 2)
  check(count(k, "edrill") == m and count(k, spec.sink) == m and count(k, T.DRILL) == 0, "§2 électrique : moitié des foreuses : " .. kind)
  check(count(k, "epole") == 12, "§2 les poteaux de la ligne : " .. kind)
  check(count(k, T.fuel) == (spec.sink == T.SMELTER and T.fuel_per_burner * m or 0), "§2 combustible du seul four : " .. kind)
  local p = Planner.outpost_items(kind)
  check(count(p, "edrill") == m, "§3 le planificateur lit le kit électrique : " .. kind)
end
check(count(T.pair_kit("iron", 1), "edrill") == 1, "§2 un minimum d'une foreuse")
-- mutant : per ignoré (une électrique vaut une à combustible) => autant de foreuses
with_elec(1)
check(count(T.pair_kit("iron", 8), "edrill") == 8, "§4 per = 1 : autant de foreuses électriques")
T.elec = nil
check(count(T.pair_kit("iron", 8), T.DRILL) == 8, "§3 le contexte retiré rend le kit à combustible")

print(string.format("[ELEC2] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
