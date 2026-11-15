--[[
  tests/expo_test.lua — lot EXPO (nuit 0.9.8, chantier 2 du DC : croissance géométrique). Usage : lua5.2 tests/expo_test.lua

  §1 Ent.closed : une bande refusée (état terminal) libère l'entrepreneur et n'est plus « en vol ».
  §2 Mg.held_bands : une bande déjà portée par un projet vivant du même cadre n'est jamais redemandée.
  §3 câblage du runtime (script/team/migration_champ.lua) : le scan, le pas de l'ordre, la relance et la liste des bandes en vol lisent
     Ent.closed ; begin_band et la bande en avance écartent les bandes portées.
  Mutants : l'ancienne règle (« fini » seul ; aucune bande portée) et l'ancien câblage échouent.
]]
package.path = "./?.lua;" .. package.path
local E = require("shared.team.entrepreneur")
local Mg = require("shared.team.migration_champ")

local ok, ko = 0, 0
local function check(cond, msg)
  if cond then ok = ok + 1 else ko = ko + 1; print("ECHEC : " .. msg) end
end

local function read(p)
  local fh = assert(io.open(p, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end

-- §1
local function suite_closed(closed)
  local r = {}
  r[#r + 1] = closed("fini") == true
  r[#r + 1] = closed("refuse") == true
  r[#r + 1] = closed(nil) == true
  for _, s in ipairs({ "plan", "attente", "reserve", "chantier", "bloque", "defrichage", "fantomes" }) do r[#r + 1] = closed(s) == false end
  for _, v in ipairs(r) do if not v then return false end end
  return true
end
check(suite_closed(E.closed), "Ent.closed : fini, refuse, disparu clos ; plan, reserve, chantier, bloque... ouverts")
check(not suite_closed(function(s) return s == "fini" end), "mutant : « fini » seul (0.9.7) doit échouer")

-- §2
do
  local fr, fr2 = {}, {}
  local projects = {
    { state = "reserve", champ = { oid = 1, pr = -47, frame = fr } },
    { state = "fini", champ = { oid = 1, pr = -55, frame = fr } },
    { state = "refuse", champ = { oid = 1, pr = -23, frame = fr } },
    { state = "chantier", abandoned = true, champ = { oid = 1, pr = -63, frame = fr } },
    { state = "plan", champ = { oid = 1, pr = -31, frame = fr, coal = 1 } },
    { state = "plan", champ = { oid = 1, pr = -39, frame = fr, coal = 1, link = 9 } },
    { state = "plan", champ = { oid = 2, pr = -15, frame = fr } },
    { state = "plan", champ = { oid = 1, pr = 9, frame = fr2 } },
    { state = "plan" },
  }
  local h = Mg.held_bands(projects, 1, fr)
  check(h["-47"] == true, "bande en vol (réserve) portée")
  check(h["-55"] == true, "bande posée (fini) portée")
  check(h["-23"] == nil, "bande refusée : pas portée")
  check(h["-63"] == nil, "bande abandonnée : pas portée")
  check(h["-31"] == nil and h["-39"] == nil, "réseau du charbon (coal, link) : pas une bande")
  check(h["-15"] == nil, "autre avant-poste : pas portée")
  check(h["9"] == nil, "autre cadre : pas portée")
  local n = 0
  for _ in next, h do n = n + 1 end
  check(n == 2, "deux bandes portées exactement (" .. n .. ")")
  check(next(Mg.held_bands(nil, 1, fr)) == nil, "liste absente : rien")
end

-- §3 câblage
do
  local src = read("script/team/migration_champ.lua")
  local _, nc = src:gsub("not %(cur and not Ent%.closed%(cur%.state%)%)", "")
  check(nc == 2, "scan et pas de l'ordre : chantier clos par Ent.closed (" .. nc .. ")")
  check(src:find("local busy = cur ~= nil and not Ent.closed(cur.state)", 1, true) ~= nil, "relance : chantier clos par Ent.closed")
  check(src:find("if p and not Ent.closed(p.state) and x.item", 1, true) ~= nil, "bandes en vol : une refusée n'en est pas")
  check(src:find("not (cur and cur.state ~= \"fini\")", 1, true) == nil, "mutant 0.9.7 : plus aucune lecture « fini » seul du chantier")
  local _, nh = src:gsub("and not held%[tostring%(x%)%]", "")
  check(nh == 2, "begin_band : les deux passes écartent les bandes portées (" .. nh .. ")")
  check(src:find("x ~= st.band_key and not held[k]", 1, true) ~= nil, "bande en avance : écarte les bandes portées")
  check(src:find("if not pr and next(held) ~= nil then", 1, true) ~= nil, "bandes restantes toutes en vol : attente, ni « posé » ni échec")
  -- mutant : l'ancien code (sans held) ne passe pas les gardes ci-dessus
  local old = src:gsub("and not held%[tostring%(x%)%]", ""):gsub(" and not held%[k%]", "")
  local _, nh2 = old:gsub("and not held%[tostring%(x%)%]", "")
  check(nh2 == 0 and old:find("x ~= st.band_key and not held[k]", 1, true) == nil, "mutant sans garde : détecté")
end

print(string.format("expo_test : %d OK, %d ECHEC", ok, ko))
if ko > 0 then os.exit(1) end
