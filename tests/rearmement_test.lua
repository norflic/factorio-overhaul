--[[
  Lot REARMEMENT : banc HORS JEU de la règle pure (shared/team/rearmement.lua) et de sa chaîne dans les sources. Lancement :
  lua5.2 tests/rearmement_test.lua (racine du mod, moins d'une seconde).
    1. Ra.take : dotation complétée, jamais au-delà du stock au-dessus du plancher, rien si l'emplacement est plein ;
    2. Ra.floor : réserve minimale ou part urgente des tourelles, la plus grande ;
    3. la chaîne : dépôt au QG -> rechargement (worker.lua), journal [FO-REARMEMENT] (team.lua), dotation protégée (deposit, bg_absorb) ;
    4. mutants : chaque règle cassée change au moins un fait.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end
local function read_src(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local function load_ra(src) return assert(load(src, "@shared.team.rearmement"))() end
local SRC = read_src("shared/team/rearmement.lua")

local function facts(Ra)
  local f = {}
  f.empty = Ra.take(0, 10, 200, 20)        -- arme vide, coffre riche : 10
  f.half = Ra.take(4, 10, 200, 20)         -- 4 dans l'emplacement : 6
  f.full = Ra.take(10, 10, 200, 20)        -- pleine : 0
  f.over = Ra.take(12, 10, 200, 20)        -- au-delà de la dotation : 0
  f.floor_cut = Ra.take(0, 10, 25, 20)     -- 5 au-dessus du plancher : 5
  f.floor_none = Ra.take(0, 10, 20, 20)    -- au plancher : 0
  f.below = Ra.take(0, 10, 12, 20)         -- sous le plancher : 0
  f.bad = Ra.take(-3, 10, 0 / 0, 20)       -- entrées invalides : 0
  f.fl_min = Ra.floor(20, 5)
  f.fl_turrets = Ra.floor(20, 140)
  f.fl_bad = Ra.floor(nil, -4)
  return f
end

local F0 = facts(load_ra(SRC))

section("1. Ra.take")
check(F0.empty == 10 and F0.half == 6, "arme vide : 10 ; 4 dans l'emplacement : 6 (" .. F0.empty .. ", " .. F0.half .. ")")
check(F0.full == 0 and F0.over == 0, "emplacement plein ou au-delà de la dotation : rien")
check(F0.floor_cut == 5 and F0.floor_none == 0 and F0.below == 0,
  "jamais sous le plancher de la défense : 5 au-dessus -> 5 ; au plancher ou dessous -> 0")
check(F0.bad == 0, "entrées invalides : rien")

section("2. Ra.floor")
check(F0.fl_min == 20 and F0.fl_turrets == 140 and F0.fl_bad == 0, "plancher = max(réserve minimale, part urgente des tourelles)")

section("3. La chaîne dans les sources")
local function has(path, pat) return read_src(path):find(pat, 1, true) ~= nil end
check(has("script/team/worker.lua", "rearm(agent, f) -- lot REARMEMENT : après le dépôt"), "deposit_all recharge l'arme après le dépôt")
check(has("script/team/worker.lua", "local n = Ra.take(ammo.get_item_count(T.worker_ammo), T.worker_ammo_keep, Stock.count(f, T.worker_ammo), rearm_floor(f))"),
  "le rechargement passe par Ra.take avec le plancher de la défense")
check(has("script/team/worker.lua", "return Ra.floor(Bt.AMMO_MIN, urgent)"), "plancher : réserve minimale (Bt.AMMO_MIN) ou part urgente des tourelles")
check(has("script/team/worker.lua", "if not (guns and guns.get_item_count(T.worker_gun) > 0) then return end"), "seul un PNJ armé (pistolet) est rechargé")
check(has("script/team/worker.lua", "if ammo then deposit_inventory(f, ammo, KEEP_AMMO) end")
  and has("script/team/worker.lua", "local spare = inv and (inv.get_item_count(item) - (s[2][item] or 0)) or 0"),
  "la dotation est protégée : le dépôt et bg_absorb ne reprennent que l'excédent au-delà de KEEP_AMMO")
check(has("script/team/team.lua", "Worker.rearm_report(f, tick)"), "journal [FO-REARMEMENT] écrit à la pensée de l'équipe (votre équipe et factions)")
check(T.rearm_on == true and T.worker_ammo_keep == 10, "réglage : règle allumée, dotation 10")

section("4. Mutants")
local function mutate(from, to)
  local s, n = SRC:gsub(from:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"), (to:gsub("%%", "%%%%")), 1)
  assert(n == 1, "mutant introuvable : " .. from)
  return s
end
local MUTANTS = {
  { "plancher ignoré", mutate("local free = stock - floor", "local free = stock") },
  { "dotation ignorée", mutate("if slot >= keep then return 0 end", "") },
  { "prise au-delà du stock", mutate("return n < free and n or free", "return n") },
  { "plancher = réserve seule", mutate("return min_reserve > turret_urgent and min_reserve or turret_urgent", "return min_reserve") },
}
local killed = 0
local keys = {}
for k in pairs(F0) do keys[#keys + 1] = k end
table.sort(keys)
for _, m in ipairs(MUTANTS) do
  local ok, Fm = pcall(function() return facts(load_ra(m[2])) end)
  local diff, which = not ok, (not ok) and "erreur" or nil
  if ok then for _, k in ipairs(keys) do if Fm[k] ~= F0[k] then diff, which = true, k break end end end
  if diff then killed = killed + 1 end
  check(diff, "mutant « " .. m[1] .. " » vu" .. (which and (" (" .. which .. ")") or ""))
end
print(string.format("[REARMEMENT] mutants : %d/%d vus", killed, #MUTANTS))
print(string.format("[REARMEMENT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
