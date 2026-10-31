--[[
  Lot MAIN-INVENTAIRE (retour du DC du 31/10, points 4 et 5) : test hors jeu de shared/team/main_inventaire.lua.
    §1 minage a la main : refuse quand le stock couvre, combustible strict, survie exemptee ;
    §2 inventaire plein : continuer, deposer, finir (voyages bornes) ;
    §3 minerai au sol : piles entieres, les plus proches d'abord, bornees par la place et PICK_MAX, determinisme ;
    §4 service des fours au QG garde apres un rappel ; §5 cablage dans script/team/worker.lua ;
    §6 mutants : chaque regle faussee est vue ; §7 aucun nom d'objet du jeu dans le module.
  Usage : lua5.2 tests/main_inventaire_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/main_inventaire.lua")
local function load_mi(src)
  local fn = load(src, "=mi", "t")
  if not fn then return nil end
  local ok, m = pcall(fn)
  return ok and m or nil
end

local ok_n, bad = 0, 0
local function check(name, cond)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[MAIN] ECHEC : " .. name) end
end

--- Toutes les verifications du module (rejouees sur chaque mutant : le mutant doit en faire echouer au moins une).
local function suite(Mi)
  local res = {}
  local function c(name, cond) res[#res + 1] = { name, cond and true or false } end
  -- §1
  local ok, why = Mi.hand_verdict({ stock = 500, count = 50 })
  c("stock 500 couvre 50", ok == false and why == "stock")
  ok = Mi.hand_verdict({ stock = 0, count = 50 })
  c("stock 0 : on mine", ok == true)
  ok = Mi.hand_verdict({ stock = 60, count = 50 })
  c("stock 60 < 2 x 50 : on mine", ok == true)
  ok = Mi.hand_verdict({ stock = 100, count = 50 })
  c("stock 100 = 2 x 50 : couvert", ok == false)
  ok = Mi.hand_verdict({ stock = 120, count = 10, fuel = true })
  c("combustible : 120 en coffre, jamais a la main", ok == false)
  ok = Mi.hand_verdict({ stock = 99, count = 10, fuel = true })
  c("combustible : 99 < 100, on mine", ok == true)
  ok, why = Mi.hand_verdict({ stock = 9000, count = 50, fuel = true, survie = true })
  c("survie exemptee", ok == true and why == "survie")
  ok = Mi.hand_verdict({ stock = 30, count = 5 })
  c("plancher STOCK_MIN : 30 < 50, on mine", ok == true)
  ok = Mi.hand_verdict({ stock = 50, count = 5 })
  c("plancher STOCK_MIN : 50 couvre 5", ok == false)
  ok = Mi.hand_verdict({})
  c("entree vide : on mine", ok == true)
  -- §2
  c("continuer : place large", Mi.inventory_action({ room = 500, got = 10, count = 50, trips = 0 }) == "continue")
  c("deposer : plein", Mi.inventory_action({ room = 0, got = 10, count = 50, trips = 0 }) == "deposit")
  c("deposer : place 19 < 20", Mi.inventory_action({ room = 19, got = 10, count = 50, trips = 1 }) == "deposit")
  c("continuer : place 20", Mi.inventory_action({ room = 20, got = 10, count = 50, trips = 0 }) == "continue")
  c("finir : demande atteinte", Mi.inventory_action({ room = 0, got = 50, count = 50, trips = 0 }) == "finish")
  c("finir : voyages epuises", Mi.inventory_action({ room = 0, got = 10, count = 50, trips = Mi.TRIPS_MAX }) == "finish")
  c("continuer : il reste 3 et la place 3", Mi.inventory_action({ room = 3, got = 47, count = 50, trips = 0 }) == "continue")
  -- §3
  local stacks = {
    { i = 1, n = 5, d2 = 100, x = 1, y = 1 }, { i = 2, n = 5, d2 = 4, x = 2, y = 2 }, { i = 3, n = 50, d2 = 9, x = 3, y = 3 },
    { i = 4, n = 5, d2 = 4, x = 1, y = 9 },
  }
  local plan, total = Mi.pick_plan(stacks, 1000)
  c("ramassage : tout, les proches d'abord", table.concat(plan, ",") == "4,2,3,1" and total == 65)
  plan = Mi.pick_plan(stacks, 12)
  c("ramassage : place 12 -> deux piles de 5", table.concat(plan, ",") == "4,2")
  plan = Mi.pick_plan(stacks, 0)
  c("ramassage : aucune place", #plan == 0)
  c("ramassage : l'entree n'est pas modifiee", stacks[1].i == 1 and stacks[2].i == 2)
  local big = {}
  for i = 1, 100 do big[i] = { i = i, n = 10, d2 = i, x = i, y = 0 } end
  local _, tot = Mi.pick_plan(big, 100000)
  c("ramassage : borne PICK_MAX", tot == Mi.PICK_MAX)
  local p2 = Mi.pick_plan({ { i = 7, n = 3, d2 = 1, x = 0, y = 0 }, { i = 5, n = 3, d2 = 1, x = 0, y = 0 } }, 10)
  c("ramassage : egalite par indice", table.concat(p2, ",") == "5,7")
  c("ramassage : pile vide ignoree", #Mi.pick_plan({ { i = 1, n = 0, d2 = 0, x = 0, y = 0 } }, 10) == 0)
  -- §4
  c("service des fours garde au QG", Mi.keep_working("smelt", 100) == true and Mi.keep_working("smelters", 900) == true)
  c("service des fours : plus loin, rappele", Mi.keep_working("smelt", 31 * 31) == false)
  c("autre tache rappelee", Mi.keep_working("mine", 1) == false and Mi.keep_working("service", 1) == false)
  return res
end

local Mi = assert(load_mi(SRC), "module illisible")
for _, r in ipairs(suite(Mi)) do check(r[1], r[2]) end

-- §5 cablage (le module n'est utile que s'il est appele la ou le moteur decide)
local W = read("script/team/worker.lua")
check("worker : require du module", W:find('require("shared.team.main_inventaire")', 1, true) ~= nil)
check("worker : verdict avant le minage", W:find("Mi.hand_verdict", 1, true) ~= nil)
check("worker : inventaire plein", W:find("Mi.inventory_action", 1, true) ~= nil)
check("worker : ramassage au sol", W:find("pick_ground(agent, item)", 1, true) ~= nil and W:find('"item-on-ground"', 1, true) ~= nil)
check("worker : service des fours garde au rappel", W:find("Mi.keep_working", 1, true) ~= nil)
check("worker : journal [FO-MAIN]", select(2, W:gsub("%[FO%-MAIN%]", "")) >= 4)

-- §6 mutants
local MUTANTS = {
  { "stock non regarde", "if num(a.stock) >= need then return false, \"stock\" end", "if false then return false, \"stock\" end" },
  { "combustible comme un minerai", "need = Mi.FUEL_MIN", "need = math.max(Mi.STOCK_MIN, Mi.COVER * num(a.count))" },
  { "survie plus exemptee", "if a.survie then return true, \"survie\" end", "" },
  { "couverture a 1 fois", "Mi.COVER = 2", "Mi.COVER = 1" },
  { "jamais de depot", "if num(a.room) >= math.min(Mi.ROOM_MIN, remaining) then return \"continue\" end", "if true then return \"continue\" end" },
  { "voyages sans borne", "if num(a.trips) >= Mi.TRIPS_MAX then return \"finish\" end", "" },
  { "depot meme demande atteinte", "if remaining <= 0 then return \"finish\" end", "" },
  { "ramassage le plus loin d'abord", "if a.d2 ~= b.d2 then return a.d2 < b.d2 end", "if a.d2 ~= b.d2 then return a.d2 > b.d2 end" },
  { "ramassage sans borne de place", "if s.n <= left and total + s.n <= Mi.PICK_MAX then", "if total + s.n <= Mi.PICK_MAX then" },
  { "ramassage sans PICK_MAX", "if s.n <= left and total + s.n <= Mi.PICK_MAX then", "if s.n <= left then" },
  { "egalite sans indice", "return a.i < b.i", "return a.i > b.i" },
  { "fours rappeles", "Mi.SERVICE_KINDS = { smelt = true, smelters = true }", "Mi.SERVICE_KINDS = {}" },
  { "service garde partout", "<= Mi.SERVICE_R * Mi.SERVICE_R", "<= 1e12" },
  { "toutes les taches gardees", "return Mi.SERVICE_KINDS[kind] == true and", "return" },
}
local refused = 0
local kept = {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  local seen = false
  if not a then
    kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local src = SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1)
    local mod = load_mi(src)
    if not mod then
      seen = true
    else
      local okp, res = pcall(suite, mod)
      if not okp then seen = true else
        for _, r in ipairs(res) do if not r[2] then seen = true break end end
      end
    end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check("mutants tous refuses (" .. #kept .. " survivant(s) : " .. table.concat(kept, " ; ") .. ")", #kept == 0)
print(string.format("[MAIN] mutants refuses : %d sur %d", refused, #MUTANTS))

-- §7 aucun nom d'objet du jeu
local names = { "iron", "copper", "coal", "stone", "plate", "ore", "wood", "furnace", "transport%-belt" }
local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
local clean = true
for _, n in ipairs(names) do if code:find(n) then clean = false print("[MAIN] nom du jeu : " .. n) end end
check("aucun nom d'objet du jeu dans le module", clean)

print(string.format("[MAIN] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
