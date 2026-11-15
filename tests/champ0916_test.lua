--[[
  Lot CHAMP-0916 (partie du DC en 0.9.3, 47 min : fer en famine, une seule bande de fer posée, 5 -> 11 laboratoires de 33 à 38 min sur le seul
  cuivre qui dort) :
  1. shared/ai3/depenses.lua Dp.step : aucun laboratoire de plus tant qu'une plaque des fonderies est en manque (p.missing) ; mutant ;
  2. script/team/pile.lua : les pièces d'une bande de champ en attente (spec.champ, non rouverte) vont au budget de la pile (plan_growth),
     jamais au noyau (plan_wants). Le budget lui-même est éprouvé dans tests/pile_budget_test.lua (« CHAMP-0916 »).
  Lancement, depuis la racine du mod : lua5.2 tests/champ0916_test.lua
]]
package.path = "./?.lua;" .. package.path
local ok, ko = 0, 0
local function check(c, msg) if c then ok = ok + 1 else ko = ko + 1; print("  ECHEC : " .. msg) end end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end

local function labs_battery(Dp)
  local fails = 0
  local function ck(c) if not c then fails = fails + 1 end end
  local function run(iron_missing)
    local st
    local res
    -- le cuivre dort assez longtemps (Dp.N_DORT) avec 3 000 plaques libres ; le fer est en manque ou non
    for i = 0, math.ceil(Dp.N_DORT / 3600) + 1 do -- (un relevé par minute : sous Dp.GAP, le sommeil reste continu)
      st, res = Dp.step(st, { on = true, tick = i * 3600, products = {
        { key = "iron", free = 0, made = 0, missing = iron_missing },
        { key = "copper", free = 3000, made = 0, missing = false },
        { key = "stone", free = 500, made = 0, missing = false, def_only = true } } })
    end
    return res
  end
  local r1 = run(true)
  ck(r1.research > 0 and r1.labs == 0 and r1.famine == "iron")
  local r2 = run(false)
  ck(r2.labs >= 1)
  return fails
end

local Dp = require("shared.ai3.depenses")
check(labs_battery(Dp) == 0, "1. cuivre qui dort, fer en manque : aucun laboratoire (famine:iron) ; fer sans manque : laboratoires comme avant")
do -- mutant : la garde de famine retirée
  local src = read("shared/ai3/depenses.lua")
  local old = 'if not p.def_only and p.missing then res.labs, res.famine = 0, tostring(p.key) break end'
  local s2, n = src:gsub(old:gsub("%p", "%%%0"), "", 1)
  check(n == 1, "1. mutant : garde introuvable")
  local M = assert(load(s2))()
  check(labs_battery(M) > 0, "1. mutant (garde de famine retirée) : la batterie échoue")
end

local S = read("script/team/pile.lua")
check(S:find("if q and q.spec and q.spec.champ and not Rule.rebuilding(q) and Rule.HOLD_STATES[q.state] then", 1, true) ~= nil,
  "2. pile : une bande de champ en attente (non rouverte) est lue")
check(S:find("growth[#growth + 1] = { it[1], it[2] - (held[it[1]] or 0) }", 1, true) ~= nil and S:find("plan_growth = growth", 1, true) ~= nil,
  "2. pile : ses pièces manquantes vont à plan_growth (budget), pas à plan_wants (noyau)")
local P = read("shared/ai3/pile.lua")
check(P:find("plan_growth = inp.plan_growth", 1, true) ~= nil and P:find("for _, it in ipairs(sig.plan_growth or {}) do claims.rebuild", 1, true) ~= nil,
  "2. pile : plan_growth transmis au signal et compté au budget")
local C = read("shared/ai3/cerveau.lua")
check(not C:find("plan_growth", 1, true), "2. le noyau de la réserve (cerveau.lua, Rs.state) ne lit pas plan_growth")

-- 3. Lot CHAMP-0916 : marge électrique de la migration (Mg.power_spare), lue en plus de la santé du réseau
local function spare_battery(Mg)
  local fails = 0
  local function ck(c) if not c then fails = fails + 1 end end
  ck(Mg.power_spare({ capacity = 30000, power = 8000, saturated = false }) == true)   -- centrale finie, 1/4 de sa capacité : marge
  ck(not Mg.power_spare({ capacity = 30000, power = 29000, saturated = true }))       -- saturée : pas de marge
  ck(not Mg.power_spare({ capacity = 30000, power = 0, saturated = false }))          -- ne produit pas (chaudières à sec, rien de branché)
  ck(not Mg.power_spare({ capacity = 0, power = 0 }))                                 -- aucune centrale finie
  ck(not Mg.power_spare(nil))
  return fails
end
local Mg = require("shared.team.migration_champ")
check(spare_battery(Mg) == 0, "3. marge électrique : centrale finie qui produit sans saturer = marge ; saturée, à sec ou absente : non")
do
  local src = read("shared/team/migration_champ.lua")
  local old = "and not g.saturated"
  local s2, n = src:gsub(old:gsub("%p", "%%%0"), "", 1)
  local M2 = assert(load(s2))()
  check(n == 1 and spare_battery(M2) > 0, "3. mutant (saturation ignorée) : la batterie échoue")
end
local MC = read("script/team/migration_champ.lua")
check(MC:find("return (b.sante ~= nil and b.sante.healthy == true) or Mg.power_spare(b.grow)", 1, true) ~= nil,
  "3. power_ok : réseau sain OU centrale qui produit avec marge (une pièce manquante ne gèle plus la migration)")

print(string.format("[CHAMP-0916] BILAN : %d OK, %d ECHEC(S)", ok, ko))
if ko > 0 then os.exit(1) end
