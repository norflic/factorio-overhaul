-- Lot RUINES-ATTENTE : Ru.prefer_scarce (shared/team/ruines.lua) : les pièces d'un avant-poste dont la matière manque passent d'abord, partition stable.
package.path = "./?.lua;" .. package.path
local Ru = require("shared.team.ruines")
local ok, bad = 0, 0
local function check(name, cond) if cond then ok = ok + 1 else bad = bad + 1 print("ECHEC : " .. name) end end
local function keys(list) local t = {} for _, r in ipairs(list) do t[#t + 1] = r.key end return table.concat(t, ",") end

-- cas de la partie neuve : charbon (16,1), cuivre (16,2), fer (16,3), valeurs égales ; le fer manque
local due = {
  { key = "c1", ore = "coal" }, { key = "c2", ore = "coal" }, { key = "u1", ore = "copper" },
  { key = "f1", ore = "iron" }, { key = "f2", ore = "iron" }, { key = "f3", ore = "iron" },
}
local function iron(r) return r.ore == "iron" end
check("le fer passe devant", keys(Ru.prefer_scarce(due, iron)) == "f1,f2,f3,c1,c2,u1")
check("l'ordre relatif est gardé (stable)", keys(Ru.prefer_scarce(due, function(r) return r.ore ~= "copper" end)) == "c1,c2,f1,f2,f3,u1")
check("rien ne manque : l'ordre d'avant", keys(Ru.prefer_scarce(due, function() return false end)) == "c1,c2,u1,f1,f2,f3")
check("tout manque : l'ordre d'avant", keys(Ru.prefer_scarce(due, function() return true end)) == "c1,c2,u1,f1,f2,f3")
check("liste vide", #Ru.prefer_scarce({}, iron) == 0)
check("la liste d'entrée n'est pas modifiée", keys(due) == "c1,c2,u1,f1,f2,f3")
check("déterministe", keys(Ru.prefer_scarce(due, iron)) == keys(Ru.prefer_scarce(due, iron)))

-- mutant : sans partition (rend la liste telle quelle) : le premier contrôle doit échouer
local real = Ru.prefer_scarce
Ru.prefer_scarce = function(d) return d end
local caught = keys(Ru.prefer_scarce(due, iron)) ~= "f1,f2,f3,c1,c2,u1"
Ru.prefer_scarce = real
check("mutant : sans partition, refusé", caught)

print(string.format("[RUINES-PRIORITE] BILAN : %d OK, %d ECHEC(S)", ok, bad))
os.exit(bad == 0 and 0 or 1)
