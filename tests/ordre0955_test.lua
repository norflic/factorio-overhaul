--[[
  Lot ORDRE-0955 (partie du DC en 0.9.4) : la bande de l'ordre Maj+A n° 1 (projet 50, champ 100004) a attendu de 31,8 à 53,6 min derrière
  les bandes plus anciennes : l'entrepreneur attachait toujours inflight[1]. E.pick sert d'abord la bande d'un gisement voulu par un ordre.
  Lancement, depuis la racine du mod : lua5.2 tests/ordre0955_test.lua
]]
package.path = "./?.lua;" .. package.path
local ok, ko = 0, 0
local function check(c, msg) if c then ok = ok + 1 else ko = ko + 1; print("  ECHEC : " .. msg) end end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local function battery(E)
  local fails = 0
  local function ck(c) if not c then fails = fails + 1 end end
  local fl = { { pid = 35, oid = 100003 }, { pid = 50, oid = 100004 } }
  ck(E.pick(fl, { [100004] = true }) == 2)  -- la bande de l'ordre passe devant
  ck(E.pick(fl, {}) == 1)                    -- sans ordre : comme avant
  ck(E.pick(fl, nil) == 1)
  ck(E.pick({ { pid = 7 } }, { [100004] = true }) == 1)
  return fails
end
local E = require("shared.team.entrepreneur")
check(battery(E) == 0, "1. E.pick : bande d'ordre d'abord, sinon la première")
do
  local src = read("shared/team/entrepreneur.lua")
  local s2, n = src:gsub("if wanted and x%.oid ~= nil and wanted%[x%.oid%] then return i end", "", 1)
  check(n == 1 and battery(assert(load(s2))()) > 0, "1. mutant (préférence retirée) : la batterie échoue")
end
local MC = read("script/team/migration_champ.lua")
check(MC:find("inflight[Ent.pick(inflight, wanted)].pid", 1, true) ~= nil, "2. l'attache de l'entrepreneur passe par E.pick")
check(MC:find("pid = st.pid, oid = id,", 1, true) and MC:find("pid = st.ahead[k].pid, oid = oid,", 1, true), "2. Mig.projects nomme le gisement de chaque bande")
check(read("script/gui/commande.lua"):find("if ok and fid then o.band_fid = fid end", 1, true) ~= nil, "3. l'ordre retient le champ voulu (o.band_fid)")
print(string.format("[ORDRE-0955] BILAN : %d OK, %d ECHEC(S)", ok, ko))
if ko > 0 then os.exit(1) end
