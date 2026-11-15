-- Lot RECONSTRUCTION-0716 : Ru.demand (shared/team/ruines.lua) : foreuses des ruines vivantes à fabriquer (au plus `cap` par objet, moins le stock libre).
package.path = "./?.lua;" .. package.path
local Ru = require("shared.team.ruines")
local ok, bad = 0, 0
local function check(name, cond) if cond then ok = ok + 1 else bad = bad + 1 print("ECHEC : " .. name) end end
local function str(out) local t = {} for _, w in ipairs(out) do t[#t + 1] = w[1] .. "x" .. w[2] .. "@" .. w[3] end return table.concat(t, ",") end

local ruins = { [2] = { oid = 2 }, [3] = { oid = 3 } }
local function H(t) return function(oid) return t[oid] ~= nil end end
local due = {
  { key = "a", kind = "drill", oid = 2, item = "d1" }, { key = "b", kind = "sink", oid = 2, item = "c1" },
  { key = "c", kind = "drill", oid = 2, item = "d1" }, { key = "d", kind = "drill", oid = 3, item = "d1" },
  { key = "e", kind = "drill", oid = 9, item = "d1" }, -- avant-poste 9 : hors de `host` sauf au contrôle « vivant »
  { key = "f", kind = "drill", oid = 3, item = "d2" }, { key = "g", kind = "drill", oid = 3, item = "d1", abandoned = true },
  { key = "h", infra = true, item = "p1" },
}
local none = function() return 0 end
check("avant-poste vivant compte aussi", str(Ru.demand(due, H({ [2] = 1, [3] = 1, [9] = 1 }), none, 9)) == "d1x4@2,d2x1@3,c1x1@2")
check("foreuses des ruines seulement, ordre de rencontre", str(Ru.demand(due, H(ruins), none, 4)) == "d1x3@2,d2x1@3,c1x1@2")
check("plafond par objet", str(Ru.demand(due, H(ruins), none, 2)) == "d1x2@2,d2x1@3,c1x1@2")
check("stock libre deduit", str(Ru.demand(due, H(ruins), function(i) return i == "d1" and 2 or 0 end, 4)) == "d1x1@2,d2x1@3,c1x1@2")
check("stock suffisant : rien", #Ru.demand(due, H(ruins), function() return 9 end, 4) == 0)
check("sans ruine : rien", #Ru.demand(due, H({}), none, 4) == 0)
check("liste vide", #Ru.demand({}, H(ruins), none, 4) == 0)
check("deterministe", str(Ru.demand(due, H(ruins), none, 4)) == str(Ru.demand(due, H(ruins), none, 4)))

-- mutant : ruines ignorées (toutes les foreuses dues) : le premier contrôle doit échouer
local real = Ru.demand
Ru.demand = function(d, r, h, c) return real(d, function() return true end, h, c) end
local caught = str(Ru.demand(due, H(ruins), none, 4)) ~= "d1x3@2,d2x1@3,c1x1@2"
Ru.demand = real
check("mutant : sans filtre des ruines, refuse", caught)

print(string.format("[RUINES-FABRIQUE] BILAN : %d OK, %d ECHEC(S)", ok, bad))
os.exit(bad == 0 and 0 or 1)
