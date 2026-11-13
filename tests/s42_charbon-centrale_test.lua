--[[
  Tests hors jeu du lot s42 charbon-centrale (chantier 3.1 du DC) : deux entrées de combustible par centrale neuve, ligne de charbon
  dédiée dimensionnée à la consommation nominale × 1,3. Règles pures (shared/team/charbon_centrale.lua, P.feeder) et chaîne statique.
  Usage, depuis la racine du mod :   lua5.2 tests/s42_charbon-centrale_test.lua
]]
package.path = "./?.lua;" .. package.path
local Cc = require("shared.team.charbon_centrale")
local M = require("shared.team.modules")
local P = require("shared.team.plan")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function near(a, b) return math.abs(a - b) < 1e-9 end

print("== 1. Ligne dédiée : consommation nominale x 1,3")
local kw = M.BASE.boiler.burner_kw
check(Cc.ALIM_MARGIN == 1.3, "marge de 1,3")
check(near(Cc.alim_rate(kw, M.COAL_J), 1.3 * kw / M.COAL_J), "une chaudière : nominal x 1,3")
check(near(Cc.alim_rate(4 * kw, M.COAL_J), 4 * Cc.alim_rate(kw, M.COAL_J)), "linéaire en chaudières")
check(Cc.alim_rate(0, M.COAL_J) == 0 and Cc.alim_rate(nil, nil) == 0, "rien : 0")
check(Cc.alim_rate(kw, M.COAL_J) > Cc.rate(kw, M.COAL_J), "toujours au-dessus du nominal")

print("== 2. Entrées de combustible")
local n, arm = Cc.entries("thermique", "electrique", 3)
check(n == 2 and arm == "electrique", "bras électrique au coffre : 2 entrées, la seconde électrique")
n, arm = Cc.entries("thermique", "electrique", 0)
check(n == 2 and arm == "thermique", "aucun bras électrique au coffre : la seconde reste à combustion")
n, arm = Cc.entries("thermique", nil, 5)
check(n == 2 and arm == "thermique", "pas de bras électrique connu : combustion")
n, arm = Cc.entries("thermique", "thermique", 5)
check(arm == "thermique", "même bras : combustion")
n, arm = Cc.entries("thermique", "electrique", nil)
check(arm == "thermique", "stock inconnu : combustion")

print("== 3. Consommation par coffre")
check(Cc.chest_rate(0.45, 1) == 0.45 and Cc.chest_rate(0.45, nil) == 0.45 and Cc.chest_rate(0.45, 0) == 0.45, "un coffre : inchangé")
check(near(Cc.chest_rate(0.9, 2), 0.45), "deux coffres : la moitié chacun")
check(Cc.chest_rate(nil, 2) == 0, "rien : 0")
local r1 = Cc.refill(0, Cc.chest_rate(3.6, 1), 50000, nil, false)
local r2 = Cc.refill(0, Cc.chest_rate(3.6, 2), 50000, nil, false)
check(2 * r2.target == r1.target and 2 * r2.low == r1.low, "au-dessus des planchers, deux coffres retiennent ensemble ce qu'un seul retenait")

print("== 4. Tête à deux entrées (P.feeder)")
local port = { x = 10, y = 10, dir = 0, lanes = { "coal", "coal" }, io = "in" }
for d = 0, 6, 2 do
  port.dir = d
  local one = P.feeder(port, { "quai", nil }, "thermique", nil, 1)
  local two = P.feeder(port, { "quai", nil }, "thermique", nil, 2, "electrique")
  check(#one.chests == 1 and #two.chests == 2, "dir " .. d .. " : 1 puis 2 coffres")
  local arms, burner, electric, tiles, dup = 0, 0, 0, {}, false
  for _, e in ipairs(two.entities) do
    if e.role == "quai-bras" then
      arms = arms + 1
      if e.name == "thermique" then burner = burner + 1 elseif e.name == "electrique" then electric = electric + 1 end
    end
    local k = e.x .. "," .. e.y
    if tiles[k] then dup = true end
    tiles[k] = true
  end
  check(arms == 2 and burner == 1 and electric == 1, "dir " .. d .. " : un bras à combustion (démarrage à froid) et un bras électrique")
  check(not dup, "dir " .. d .. " : aucune tuile en double")
  check(two.chests[1].x ~= two.chests[2].x or two.chests[1].y ~= two.chests[2].y, "dir " .. d .. " : deux coffres distincts")
  -- la première entrée est celle de la tête à une entrée (bras à combustion, même coffre)
  check(one.chests[1].x == two.chests[1].x and one.chests[1].y == two.chests[1].y, "dir " .. d .. " : premier coffre inchangé")
  local ex = Cc.extras(one.entities, two.entities)
  check(#ex == #two.entities - #one.entities, "dir " .. d .. " : pièces de plus = différence des deux têtes")
  for _, e in ipairs(ex) do
    for _, o in ipairs(one.entities) do check(not (o.x == e.x and o.y == e.y), "dir " .. d .. " : pièce de plus hors de la tête simple") end
  end
  -- sans arm2 : comme avant le lot (même bras)
  local same = P.feeder(port, { "quai", nil }, "thermique", nil, 2)
  local nb = 0
  for _, e in ipairs(same.entities) do if e.role == "quai-bras" and e.name == "thermique" then nb = nb + 1 end end
  check(nb == 2, "dir " .. d .. " : sans arm2, deux bras identiques")
end
check(#Cc.extras(nil, nil) == 0 and #Cc.extras({}, { { x = 1, y = 2 } }) == 1, "extras : bornes")

print("== 5. Chaîne statique (script/team/build.lua)")
local fh = assert(io.open("script/team/build.lua", "rb"))
local src = fh:read("*a")
fh:close()
check(src:find("local rate = Cc.alim_rate(kw, M.COAL_J)", 1, true) ~= nil, "plan_alim dimensionne la ligne par Cc.alim_rate")
check(src:find("Cc.entries(M.BURNER_ARM, M.ELECTRIC_ARM", 1, true) ~= nil, "plan_feed demande les entrées par Cc.entries")
check(src:find("Cc.chest_rate(Cc.rate(kw, M.COAL_J), #p.quais)", 1, true) ~= nil, "quai_tasks partage la consommation entre les coffres")
check(src:find('local quai_ins = (g.gen == "steam") and M.BURNER_ARM or "inserter"', 1, true) ~= nil, "le premier bras de la centrale reste à combustion")
local a = src:find("Cc.entries(M.BURNER_ARM, M.ELECTRIC_ARM", 1, true) or 1
local z = src:find("local quay_ents = {}", a, true) or a
local blk = src:sub(a, z)
local _, refus = blk:gsub("return false, \"tete d'alimentation\"", "")
check(refus == 2, "le repli sur une entrée garde le refus d'avant, sans en ajouter (" .. refus .. ")")
check(blk:find("place.masks.free", 1, true) ~= nil, "le terrain des pièces de plus est vérifié")

print(string.format("s42 charbon-centrale : %d OK, %d ECHEC", passes, failures))
os.exit(failures == 0 and 0 or 1)
