--[[
  Lot c4c (preuve du chantier 4, maillon 1) : sur la carte du DC (graine 123456789), le plan de l'autre axe du champ 100001 du joueur
  s'arrêtait à 10,5 min (étape 4 623) : la file des plans (Mig.frame_tick) JETAIT son entrée pendant la vérification du cadre d'un autre
  avant-poste (ms.verify_due) ; la reprise n'arrivait qu'à 15,7 min, séquence périmée (SEQ_GAP 30 s) : plan refait de zéro, fini à 21,1 min.
  Ax.wait_fate garde l'entrée en file pendant cet empêchement passager. Batterie + mutant, câblage.
  Lancement, depuis la racine du mod : lua5.2 tests/c4c_cadre_test.lua
]]
package.path = "./?.lua;" .. package.path
local ok, ko = 0, 0
local function check(c, msg) if c then ok = ok + 1 else ko = ko + 1; print("  ECHEC : " .. msg) end end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local function battery(Ax)
  local fails = 0
  local function ck(c) if not c then fails = fails + 1 end end
  ck(Ax.wait_fate(true, false, false, true) == "garder")   -- vérification d'un autre cadre : l'entrée reste en file
  ck(Ax.wait_fate(true, false, false, false) == "pas")     -- le pas part
  ck(Ax.wait_fate(true, true, false, true) == "laisser")   -- cadre déjà pris
  ck(Ax.wait_fate(true, false, true, false) == "laisser")  -- abandon
  ck(Ax.wait_fate(false, false, false, true) == "laisser") -- cible perdue
  return fails
end
local Ax = require("shared.team.champ_axe")
check(battery(Ax) == 0, "1. Ax.wait_fate : garder pendant la vérification, laisser sinon")
do
  local s2, n = read("shared/team/champ_axe.lua"):gsub('if verify_due then return "garder" end', 'if verify_due then return "laisser" end', 1)
  check(n == 1 and battery(assert(load(s2))()) > 0, "1. mutant (entrée jetée pendant la vérification, comme avant) : la batterie échoue")
end
local MC = read("script/team/migration_champ.lua")
local fi = MC:find("function Mig.frame_tick(tick)", 1, true)
local blk = fi and MC:sub(fi, (MC:find("\nend\n", fi, true) or #MC))
check(blk ~= nil and blk:find("Ax.wait_fate(", 1, true) ~= nil and blk:find('if fate == "garder" then', 1, true) ~= nil
  and blk:find("Ax.push(FRAME_WAIT, w)", 1, true) ~= nil, "2. Mig.frame_tick remet l'entrée en file pendant la vérification")
check(blk ~= nil and not blk:find("or ms.verify_due then return false end", 1, true), "2. plus d'entrée jetée sur ms.verify_due")
print(string.format("[C4C-CADRE] BILAN : %d OK, %d ECHEC(S)", ok, ko))
if ko > 0 then os.exit(1) end
