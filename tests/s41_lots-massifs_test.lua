--[[
  s41 lots-massifs : règle pure C.sweep (shared/team/collecte.lua) : sorties voisines du même projet vidées dans le même voyage de collecte.
  Usage : lua5.2 tests/s41_lots-massifs_test.lua
]]
package.path = "./?.lua;" .. package.path
local C = require("shared.team.collecte")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
end
local function same(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

local outs = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 0, y = 40 }, { x = 41, y = 0 }, { x = 30, y = 30 } }
check(same(C.sweep(outs, 1, false, false), { 2, 3 }), "champ sans keep_stock : les sorties à 40 tuiles au plus partent dans le voyage, ordre croissant")
check(same(C.sweep(outs, 2, false, false), { 1, 4, 5 }), "la sortie servie est exclue ; 31 et 36 tuiles : prises ; (0,40) à 41,2 tuiles : laissée")
check(same(C.sweep(outs, 1, false, true), {}), "bloc de mall (keep_stock) : une sortie par voyage")
check(same(C.sweep(outs, 1, true, true), { 2, 3 }), "site : règle d'origine, même avec keep")
check(same(C.sweep(outs, 1, true, false), { 2, 3 }), "site sans keep : règle d'origine")
check(same(C.sweep(outs, 9, false, false), {}), "indice absent : rien")
check(same(C.sweep(nil, 1, false, false), {}), "pas de sorties : rien")
check(same(C.sweep({ { x = 0, y = 0 }, {} }, 1, false, false), {}), "sortie sans position : ignorée")
check(C.SWEEP_R == 40, "rayon : celui des sites (lot PETROLE 2)")
-- la glu appelle bien la règle (plus de boucle réservée aux sites)
local fh = assert(io.open("script/team/build.lua", "rb"))
local src = fh:read("*a")
fh:close()
check(src:find("Build.Colr.sweep(p.outs, job.idx, site, p.keep_stock ~= nil)", 1, true) ~= nil, "build.lua : le voyage de collecte lit C.sweep")
check(src:find("sites seulement (les autres projets gardent une sortie par voyage)", 1, true) == nil, "build.lua : l'ancienne boucle réservée aux sites a disparu")

print(string.format("[S41-LOTS-MASSIFS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
