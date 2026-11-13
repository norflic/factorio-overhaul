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

print("== p3 : alerte de site fusionnée dans une alerte de chasse")
check(SRC:find('if mode == "site" then a.site, a.role, a.n = true, nil, 4 end', 1, true) ~= nil,
  "fusion en mode site : le rôle de chasse tombe (l'alerte passe par Da.site_plan)")
check(SRC:find('if mode == "site" then a.site = true end', 1, true) == nil, "ancienne fusion (rôle de chasse gardé) retirée")
do
  -- Même fusion rejouée sur une alerte de chasse : la branche des sites de pass (`a.site and not a.role`) la prend.
  local a = { x = 0, y = 0, n = 3, role = "hunt", t = 0 }
  local mode = "site"
  if mode == "site" then a.site, a.role, a.n = true, nil, 4 end
  check(a.site and not a.role and a.n == 4, "alerte de chasse devenue alerte de site")
end

print("== p4 : une seule mise à l'abri par période pour votre équipe")
do
  local n = 0
  for _ in SRC:gmatch("Events%.on_nth_tick%(") do n = n + 1 end
  check(n == 2, "deux gestionnaires périodiques (factions, votre équipe), plus celui de 120 ticks : " .. n)
  check(SRC:find("Events.on_nth_tick(120", 1, true) == nil, "gestionnaire de 120 ticks retiré")
  check(SRC:find("if (f.soldiers_count or 0) > 0 then pass(f, e.tick) else hq_threat(f, C.team(f), surface, e.tick) end", 1, true) ~= nil,
    "votre équipe sans soldats : hq_threat à chaque période (réponse du QG et mise à l'abri)")
end

print("== p5 : avant-postes triés une fois par passage")
do
  local n = 0
  for _ in SRC:gmatch("State%.sorted_keys%(f%.outposts or {}%)") do n = n + 1 end
  check(n == 1, "un seul tri des avant-postes dans soldats.lua : " .. n)
  local a = SRC:find("local outpost_ids = State.sorted_keys(f.outposts or {})", 1, true)
  local b = SRC:find("for _, th in ipairs(t.map.threats) do", 1, true)
  check(a ~= nil and b ~= nil and a < b, "tri fait avant la boucle des menaces")
end

print(string.format("[S40-DEFENSE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
