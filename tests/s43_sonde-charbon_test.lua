--[[
  Sprint s43, sonde-charbon : l'enveloppe tools/autotest/fo-autotest/scenarios/sonde_charbon.lua jouée contre un monde fictif (remote fo-ia1
  avec et sans champ `fuel`, coffre du QG), et le champ `fuel` du remote (script/team/ia1_remote.lua, lu comme texte).
  Usage : lua5.2 tests/s43_sonde-charbon_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;./tools/autotest/fo-autotest/?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function read(path) local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s end

local LOGS = {}
log = function(s) LOGS[#LOGS + 1] = s end
local ROWS
remote = { call = function(i, f) assert(i == "fo-ia1" and f == "teams"); return ROWS end }
local HQ = { valid = true, items = { coal = 120, wood = 30, ["iron-plate"] = 500 } }
HQ.get_item_count = function(n) return HQ.items[n] or 0 end
game = { item_prototypes = { coal = { fuel_value = 4e6 }, wood = { fuel_value = 2e6 }, ["iron-plate"] = { fuel_value = 0 } } }
local SURF = { find_entities_filtered = function(q) if q.force == "f1" and q.name == "fo-faction-hq" then return { HQ } end return {} end }
local STATE = {}
local CHECKS = {}
local ctx = { surface = function() return SURF end, state = function() return STATE end, check = function(c, m) CHECKS[#CHECKS + 1] = { c, m } end }

local inner_ticks, inner_fin = 0, 0
local scen = { tick = function() inner_ticks = inner_ticks + 1 end, finish = function() inner_fin = inner_fin + 1 end }
local S = require("scenarios/sonde_charbon")(scen, 2)

-- avec le champ fuel (release) : source stock
ROWS = { { key = "amber", force = "f1", fuel = 77 } }
S.tick(ctx, { tick = 3600 })
check(#LOGS == 1 and LOGS[1]:find("minute=1 equipe=amber source=stock combustible_qg=77 charbon_qg=120", 1, true), "ligne source stock : " .. tostring(LOGS[1]))
-- sans le champ (v0.7.96) : coffre du QG seul, tous les combustibles (charbon 120 + bois 30)
ROWS = { { key = "amber", force = "f1" } }
S.tick(ctx, { tick = 7200 })
check(LOGS[2] and LOGS[2]:find("minute=2 equipe=amber source=qg combustible_qg=150 charbon_qg=120", 1, true), "ligne source qg : " .. tostring(LOGS[2]))
-- hors des minutes, et entre deux minutes : rien
S.tick(ctx, { tick = 10800 }); S.tick(ctx, { tick = 3601 })
check(#LOGS == 2, "rien au-delà de la durée ni entre deux minutes")
check(inner_ticks == 4, "le tick du scénario enveloppé est toujours appelé")
S.finish(ctx)
check(inner_fin == 1 and #CHECKS == 1 and CHECKS[1][1] == true, "finish enveloppé et contrôle sans erreur")
-- erreur dans la sonde : notée, jamais propagée
remote.call = function() error("boum") end
ROWS = nil
S.tick(ctx, { tick = 3600 })
check(STATE.sonde_err == nil, "remote en échec : la sonde se tait (pcall du remote)")

local R = read("script/team/ia1_remote.lua")
check(R:find("fuel = Stock.count(f, T.fuel)", 1, true) ~= nil, "remote fo-ia1 teams : champ fuel (Stock.count, combustible de la config)")
check(read("tools/autotest/fo-autotest/scenarios/partie-reelle-60.lua"):find('require("scenarios/sonde_charbon")', 1, true) ~= nil, "partie-reelle-60 enveloppé")

print(string.format("s43_sonde-charbon : %d OK, %d ECHEC", ok_n, fail_n))
if fail_n > 0 then os.exit(1) end
