-- BLITZ-D : tests purs des points 48 et 50 de l'audit des 50 angles morts.
package.path = "./?.lua;" .. package.path
local Rp = require("shared.team.repli_place")
local fails = 0
local function ok(c, m) if not c then fails = fails + 1; print("ECHEC : " .. m) end end

-- Point 48 : purge au-delà de RETRY.
local function purge_case(purge)
  local bad = { a = 0, b = 100, c = 5000 }
  purge(bad, Rp.RETRY + 50)
  return bad.a == nil and bad.b ~= nil and bad.c ~= nil
end
ok(purge_case(Rp.purge_bad), "48 : purge des fenêtres échues")
ok(Rp.purge_bad(nil, 10) == 0, "48 : table absente")
-- mutant : purge inerte
ok(not purge_case(function() end), "48 : le mutant (aucune purge) doit échouer")
-- mutant : seuil inversé (purge les récentes)
ok(not purge_case(function(b, t) for k, v in pairs(b) do if t - v < Rp.RETRY then b[k] = nil end end end), "48 : mutant seuil inversé")

-- Point 50 : l'unité la plus proche n'est pas comptée deux fois (liste vide au départ).
local function count_profiles(init_with_en)
  local en = { id = 1 }
  local found = { en, { id = 2 } } -- la recherche autour de la menace rend aussi `en`
  local seen = init_with_en and { en } or {}
  for _, u in ipairs(found) do seen[#seen + 1] = u end
  return #seen
end
local f = io.open("script/ai3/soldats.lua", "r"); local src = f:read("*a"); f:close()
ok(src:find("local seen_foes = {}", 1, true) ~= nil and src:find("local seen_foes = { en }", 1, true) == nil, "50 : liste vide au départ")
ok(count_profiles(false) == 2, "50 : chaque unité une fois")
ok(count_profiles(true) ~= 2, "50 : le mutant (en en tête) doit compter double")

if fails > 0 then print("blitz_d_test : " .. fails .. " echec(s)"); os.exit(1) end
print("blitz_d_test : OK")
