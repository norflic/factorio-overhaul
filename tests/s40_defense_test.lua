--[[
  Sprint 40, axe défense : règles pures de shared/ai3/reaction.lua et leur branchement dans script/ai3/soldats.lua (lu au texte).
  Lancement : lua5.2 tests/s40_defense_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Re = require("shared.ai3.reaction")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function source(path)
  local h = assert(io.open(path, "rb"))
  local s = h:read("*a")
  h:close()
  return s
end
local SRC = source("script/ai3/soldats.lua")

print("== p1 : rôles qui éloignent légitimement du QG")
check(Re.far_role("escort", false) and Re.far_role("clear", false), "escorte et nettoyage : toujours")
check(Re.far_role("guard", true) and not Re.far_role("guard", false), "garde : seulement loin du QG")
check(Re.far_role("defense", true) and Re.far_role("hunt", true), "défense et chasse lointaines : pas de rappel")
check(not Re.far_role("defense", false) and not Re.far_role("hunt", false), "défense et chasse près du QG : pas de drapeau")
check(not Re.far_role("patrol", true) and not Re.far_role("muster", true) and not Re.far_role(nil, true), "patrouille, regroupement, sans rôle : jamais")
check(SRC:find("local far_role = Re.far_role(o.role, d2(o, f.hq_pos) > Sd.NEAR_HQ * Sd.NEAR_HQ)", 1, true) ~= nil,
  "soldats.lua pose le drapeau par Re.far_role")

print(string.format("[S40-DEFENSE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
