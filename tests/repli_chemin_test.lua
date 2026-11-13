--[[
  Lot NAV2 (3/11, dernière tâche) : test hors jeu de shared/team/repli_chemin.lua (délai croissant des tâches au chemin raté).
    §1 compte par tâche : échecs « chemin » de suite, réussite = remise à zéro, autre motif = compte inchangé, tâches indépendantes ;
    §2 facteur : 1, 2, 4, 8, 16 puis plafond ; §3 suite simulée (tableau à 30 s) : tentatives en 10 min avec et sans la règle ;
    §4 câblage (script/team/board.lua, interface de banc) ; §5 mutants ; §6 aucun nom d'objet.
  Lot CHARBON3 (revue du 3/11) : §1 b B1 (le facteur ne vaut que pour un échec de chemin : Rc.delay), Q2 (tâche vitale : 60 s au
    plus ; purge des comptes anciens, format d'avant lu), B2 (essais de marche : Rc.walk_fail, remise à 0 à l'arrivée et à la prise :
    suite simulée « stuck, arrivée » sur la vie d'un PNJ).
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
  c("autre tache independante", R.note(cnt, "b", false, "chemin") == 1 and R.count(cnt.a) == 2)
  c("reussite : remise a zero", R.note(cnt, "a", true, nil) == 0 and cnt.a == nil)
  c("apres reussite, on repart de 1", R.note(cnt, "a", false, "chemin") == 1)
  c("facteur 1 au premier echec", R.factor(1) == 1 and R.factor(0) == 1 and R.factor(nil) == 1)
  c("facteur double a chaque echec", R.factor(2) == 2 and R.factor(3) == 4 and R.factor(4) == 8 and R.factor(5) == 16)
  c("facteur plafonne", R.factor(6) == R.CAP and R.factor(40) == R.CAP)
  -- B1 : le facteur ne vaut que pour un échec de CHEMIN
  local d, k = R.delay(1800, 5, "chemin", 70, false)
  c("B1 echec de chemin n=5 : x16", d == 1800 * 16 and k == 16)
  d, k = R.delay(600, 5, "danger", 70, false)
  c("B1 refus de porte n=5 : 10 s, x1 (160 s avant)", d == 600 and k == 1)
  d, k = R.delay(1800, 5, "programme", 70, false)
  c("B1 echec de programme n=5 : 30 s, x1 (8 min avant)", d == 1800 and k == 1)
  d, k = R.delay(1800, 5, "chemin", 70, true)
  c("regle coupee : x1", d == 1800 and k == 1)
  -- Q2 : tâche vitale plafonnée à 60 s
  d, k = R.delay(1800, 5, "chemin", 90, false)
  c("Q2 vitale (90) n=5 : 60 s au plus", d == R.VITAL_CAP and k == 16)
  d = R.delay(1800, 5, "chemin", 96, false)
  c("Q2 garde du QG (96) n=5 : 60 s au plus", d == R.VITAL_CAP)
  d = R.delay(1800, 2, "chemin", 90, false)
  c("Q2 vitale n=2 : 60 s (x2)", d == 3600)
  d = R.delay(3600, 3, "chemin", 95, false)
  c("Q2 vitale du fond (base 60 s) : jamais sous sa base", d == 3600)
  d = R.delay(1800, 5, "chemin", 89, false)
  c("Q2 non vitale (89) : x16 garde", d == 1800 * 16)
  d = R.delay(600, 1, "danger", 96, false)
  c("Q2 vitale, refus de porte : 10 s", d == 600)
  -- Q2 : compte daté, purge des anciens
  local pc = {}
  R.note(pc, "x", false, "chemin", 100)
  R.note(pc, "y", false, "chemin", 100 + R.FORGET)
  pc.z = 7 -- format d'avant (nombre seul)
  c("format d'avant lu", R.count(pc.z) == 7 and R.note(pc, "z", false, "danger", 5) == 7)
  c("compte date", type(pc.x) == "table" and pc.x.n == 1 and pc.x.t == 100)
  local np = R.purge(pc, 100 + R.FORGET)
  c("purge : ancien et sans date retires, recent garde", np == 2 and pc.x == nil and pc.z == nil and R.count(pc.y) == 1)
  c("purge due : jamais, puis toutes les 5 min", R.purge_due(nil, 0) and not R.purge_due(0, R.PURGE_EVERY - 1) and R.purge_due(0, R.PURGE_EVERY))
  c("echec de chemin apres une ancienne entree : compte continue", R.note(pc, "y", false, "chemin", 200 + R.FORGET) == 2 and pc.y.t == 200 + R.FORGET)
  -- B2 : essais de marche (3 repris sur place, jamais no_path ; l'abandon remet à 0)
  local a1, n1 = R.walk_fail(0, "stuck")
  local a4, n4 = R.walk_fail(3, "stuck")
  local an, nn = R.walk_fail(0, "no_path")
  c("B2 premier stuck : nouvel essai", a1 == true and n1 == 1)
  c("B2 quatrieme stuck de suite : abandon, compte a 0", a4 == false and n4 == 0)
  c("B2 no_path : abandon aussitot", an == false and nn == 0)
  -- vie d'un PNJ : 6 trajets, chacun un « stuck » puis une arrivée ; avec la remise à 0 à l'arrivée : aucun abandon ; sans : le 4e abandonne
  local function life(reset)
    local n, aborts = 0, 0
    for _ = 1, 6 do
      local again
      again, n = R.walk_fail(n, "stuck")
      if not again then aborts = aborts + 1 end
      if reset then n = 0 end -- arrivée (script/team/worker.lua nav_arrived)
    end
    return aborts
  end
  c("B2 vie d'un PNJ, remise a 0 a l'arrivee : 0 abandon", life(true) == 0)
  c("B2 vie d'un PNJ sans remise : abandon au 4e stuck", life(false) == 1)
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
check("note a chaque fin de tache (reussie ou non), datee", B:find("local n_path = Rc.note(b.path_fails, task.key, ok, task.fail, tick)", 1, true) ~= nil)
-- Lot ROUGES-0659 : depuis fa246935 (ETAGE4 m4, voulu), la pause posée par la règle ne RACCOURCIT plus une pause plus longue déjà posée
-- (tournée en pause après des bails, script/team/bail.lua) : « b.cooldown[task.key] = math.max(tick + delay, …) ». La propriété contrôlée
-- reste la même : la reprise est à tick + le délai de Rc.delay, sans facteur ajouté (« * k_path » absent).
check("delai de reprise par la regle (B1, Q2)", B:find("Rc.delay(Ac.retry(task.fail, task.fond, RETRY_TICKS), n_path, task.fail, task.prio, f.team.repli_off)", 1, true) ~= nil
  and B:find("b.cooldown[task.key] = math.max(tick + delay, b.cooldown[task.key] or 0)", 1, true) ~= nil and B:find("* k_path", 1, true) == nil)
check("purge des comptes anciens (Q2)", B:find("if Rc.purge_due(b.path_purge_t, tick) then", 1, true) ~= nil
  and B:find("Rc.purge(b.path_fails, tick)", 1, true) ~= nil)
local W = read("script/team/worker.lua")
local arr = W:match("nav_arrived = function%(agent, tick%)\n(.-)\n      end,")
check("B2 remise a 0 a l'arrivee (nav_arrived)", arr ~= nil and arr:find("agent.walk_retries = 0", 1, true) ~= nil)
-- Lot CHANTIERS-FANTOMES : la mesure de la tâche de pose (task.gt) s'intercale entre la prise et la remise ; le contrôle porte sur le
-- bloc de prise entier (de l'affectation de agent.task au passage à l'état « step »), où la remise doit toujours figurer.
local take = W:match("agent%.task, agent%.steps, agent%.pc, agent%.failed = task, steps, 1, nil\n(.-)\n      set%(agent, \"step\", tick%)")
check("B2 remise a 0 a la prise de tache", take ~= nil and take:find("\n      agent.walk_retries = 0", 1, true) ~= nil)
check("B2 essais par la regle", W:find("again, agent.walk_retries = Rc.walk_fail(agent.walk_retries, reason)", 1, true) ~= nil
  and W:find("agent.walk_retries <= 3", 1, true) == nil)
check("journal [FO-NAV-REPLI] (12 lignes par equipe)", B:find("[FO-NAV-REPLI]", 1, true) ~= nil and B:find("repli_logs <= 12", 1, true) ~= nil)
check("interface de banc set_regle_repli", read("script/team/ia1_remote.lua"):find("set_regle_repli = function(key, on)", 1, true) ~= nil)
check("le motif compte est celui du worker", read("script/team/worker.lua"):find('abort(agent, f, tick, "chemin")', 1, true) ~= nil)

-- §5 mutants
local MUTANTS = {
  { "reussite sans effet", "    counts[key] = nil\n    return 0", "    return counts[key] or 0" },
  { "tout motif compte", "if R.FAILS[fail] then", "if true then" },
  { "autre motif remet a zero", "  return R.count(counts[key])\nend","  counts[key] = nil\n  return 0\nend" },
  { "pas de croissance", "local f = 2 ^ (n - 1)", "local f = 1" },
  { "croissance lineaire", "local f = 2 ^ (n - 1)", "local f = n" },
  { "sans plafond", "if f > R.CAP then f = R.CAP end", "" },
  { "facteur des le premier echec", "if not n or n <= 1 then return 1 end", "if not n then return 1 end" },
  { "B1 facteur pour tout motif", "if not off and R.FAILS[fail] then k = R.factor(n) end", "if not off then k = R.factor(n) end" },
  { "Q2 sans plafond vital", "    if d > cap then d = cap end", "" },
  { "Q2 plafond vital sous la base", "local cap = math.max(base, R.VITAL_CAP)", "local cap = R.VITAL_CAP / 2" },
  { "Q2 purge sans effet", "      counts[k] = nil\n      n = n + 1", "      n = n + 1" },
  { "Q2 purge ignore la date", "e.t == nil or tick - e.t >= R.FORGET", "e.t == nil" },
  { "Q2 note sans date", "counts[key] = { n = n, t = tick }", "counts[key] = { n = n }" },
  { "B2 abandon sans remise a 0", "  return false, 0\nend", "  return false, n\nend" },
  { "B2 no_path repris", "if n <= R.WALK_RETRIES and reason ~= \"no_path\" then", "if n <= R.WALK_RETRIES then" },
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
