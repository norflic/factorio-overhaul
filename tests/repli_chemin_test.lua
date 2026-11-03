--[[
  Lot NAV2 (3/11, dernière tâche) : test hors jeu de shared/team/repli_chemin.lua (délai croissant des tâches au chemin raté).
    §1 compte par tâche : échecs « chemin » de suite, réussite = remise à zéro, autre motif = compte inchangé, tâches indépendantes ;
    §2 facteur : 1, 2, 4, 8, 16 puis plafond ; §3 suite simulée (tableau à 30 s) : tentatives en 10 min avec et sans la règle ;
    §4 câblage (script/team/board.lua, interface de banc) ; §5 mutants ; §6 aucun nom d'objet.
  Usage : lua5.2 tests/repli_chemin_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/repli_chemin.lua")
local function load_r(src)
  local fn = load(src, "=repli", "t")
  if not fn then return nil end
  local ok, m = pcall(fn)
  return ok and m or nil
end

local ok_n, bad = 0, 0
local function check(name, cond)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[REPLI] ECHEC : " .. name) end
end

-- tentatives d'une tâche au but injoignable en `window` ticks (chaque tentative : `walk` ticks puis échec), reprise après base x facteur
local function attempts(R, rule, window, base, walk)
  local counts, t, n = {}, 0, 0
  while t < window do
    t = t + walk
    n = n + 1
    local k = R.note(counts, "service:4", false, "chemin")
    t = t + base * (rule and R.factor(k) or 1)
  end
  return n
end

local function suite(R)
  local res = {}
  local function c(name, cond) res[#res + 1] = { name, cond and true or false } end
  local cnt = {}
  c("premier echec de chemin : 1", R.note(cnt, "a", false, "chemin") == 1)
  c("deuxieme : 2", R.note(cnt, "a", false, "chemin") == 2)
  c("autre motif : compte inchange", R.note(cnt, "a", false, "danger") == 2)
  c("autre tache independante", R.note(cnt, "b", false, "chemin") == 1 and cnt.a == 2)
  c("reussite : remise a zero", R.note(cnt, "a", true, nil) == 0 and cnt.a == nil)
  c("apres reussite, on repart de 1", R.note(cnt, "a", false, "chemin") == 1)
  c("facteur 1 au premier echec", R.factor(1) == 1 and R.factor(0) == 1 and R.factor(nil) == 1)
  c("facteur double a chaque echec", R.factor(2) == 2 and R.factor(3) == 4 and R.factor(4) == 8 and R.factor(5) == 16)
  c("facteur plafonne", R.factor(6) == R.CAP and R.factor(40) == R.CAP)
  local with, without = attempts(R, true, 36000, 1800, 600), attempts(R, false, 36000, 1800, 600)
  c(string.format("10 min, but injoignable : %d tentatives avec la regle, %d sans (<= moitie)", with, without), with * 2 <= without)
  res.with, res.without = with, without
  return res
end

local R0 = assert(load_r(SRC), "module illisible")
local base = suite(R0)
for _, r in ipairs(base) do check(r[1], r[2]) end
print(string.format("[REPLI] simulation 10 min (tentative de 10 s, reprise de base 30 s) : %d tentatives avec la regle, %d sans", base.with, base.without))

-- §4 câblage
local B = read("script/team/board.lua")
check("board charge la regle", B:find('require("shared.team.repli_chemin")', 1, true) ~= nil)
check("note a chaque fin de tache (reussie ou non)", B:find("local n_path = Rc.note(b.path_fails, task.key, ok, task.fail)", 1, true) ~= nil)
check("delai de reprise multiplie par le facteur", B:find("Ac.retry(task.fail, task.fond, RETRY_TICKS) * k_path", 1, true) ~= nil
  and B:find("Rc.factor(n_path)", 1, true) ~= nil)
check("interrupteur (bancs temoins)", B:find("f.team.repli_off and 1", 1, true) ~= nil)
check("journal [FO-NAV-REPLI] (12 lignes par equipe)", B:find("[FO-NAV-REPLI]", 1, true) ~= nil and B:find("repli_logs <= 12", 1, true) ~= nil)
check("interface de banc set_regle_repli", read("script/team/ia1_remote.lua"):find("set_regle_repli = function(key, on)", 1, true) ~= nil)
check("le motif compte est celui du worker", read("script/team/worker.lua"):find('abort(agent, f, tick, "chemin")', 1, true) ~= nil)

-- §5 mutants
local MUTANTS = {
  { "reussite sans effet", "    counts[key] = nil\n    return 0", "    return counts[key] or 0" },
  { "tout motif compte", "if R.FAILS[fail] then", "if true then" },
  { "autre motif remet a zero", "  return counts[key] or 0\nend", "  counts[key] = nil\n  return 0\nend" },
  { "pas de croissance", "local f = 2 ^ (n - 1)", "local f = 1" },
  { "croissance lineaire", "local f = 2 ^ (n - 1)", "local f = n" },
  { "sans plafond", "if f > R.CAP then f = R.CAP end", "" },
  { "facteur des le premier echec", "if not n or n <= 1 then return 1 end", "if not n then return 1 end" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif absent)"
  else
    local mod = load_r(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    local seen = mod == nil
    if not seen then
      local ok, res = pcall(suite, mod)
      if not ok then seen = true else for _, r in ipairs(res) do if not r[2] then seen = true break end end end
    end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, #MUTANTS, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUTANTS)

-- §6 aucun nom d'objet du jeu
local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
local names = { "coal", "stone", "iron", "chest", "furnace", "drill", "character", "companion", "water", "player" }
local found = {}
for _, n in ipairs(names) do if code:find(n, 1, true) then found[#found + 1] = n end end
check("aucun nom d'objet dans le module" .. (#found > 0 and (" : " .. table.concat(found, ",")) or ""), #found == 0)

print(string.format("[REPLI] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
