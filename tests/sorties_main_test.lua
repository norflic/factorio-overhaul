--[[
  Lot CHARBON-MAIN (retour du DC du 3/11) : test hors jeu de shared/team/sorties_main.lua.
    §1 avant-postes bruts (produit = ressource) lus dans les données ; §2 sorties comptées (meurtrier, dangereux, tournées ratées) ;
    §3 total et ordre des avant-postes garnis ; §4 minage à la main refusé quand les sorties en ont, crise seule exemptée ;
    §5 priorité de la tournée (urgence quand le coffre manque, jamais vers un avant-poste dangereux) ; §6 câblage (worker, planificateur,
    vue, interrupteur) ; §7 mutants : chaque règle faussée est vue ; §8 aucun nom d'objet du jeu dans le module.
  Usage : lua5.2 tests/sorties_main_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/sorties_main.lua")
local Bl = require("shared.team.bail") -- lot ETAGE4 : bail des tournées (durée lue, jamais recopiée)
local function load_sm(src)
  local fn = load(src, "=sm", "t")
  if not fn then return nil end
  local ok, m = pcall(fn)
  return ok and m or nil
end

local ok_n, bad = 0, 0
local function check(name, cond)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[SORTIES] ECHEC : " .. name) end
end

-- Données de test (noms quelconques : la règle ne connaît aucun objet du jeu)
local SPEC = {
  noir = { resource = "R1", product = "R1", sink = "boite" },  -- brut : sortie = ressource
  gris = { resource = "R2", product = "R2", sink = "boite" },
  rouge = { resource = "M1", product = "P1", sink = "four" },  -- fondu : sortie = plaque
}

local function suite(Sm)
  local res = {}
  local function c(name, cond) res[#res + 1] = { name, cond and true or false } end
  -- §1
  local raw = Sm.raw_kinds(SPEC)
  c("brut : noir", raw.noir == "R1")
  c("brut : gris", raw.gris == "R2")
  c("fondu exclu", raw.rouge == nil)
  c("aucune donnee : vide", next(Sm.raw_kinds(nil)) == nil)
  -- §2
  c("tournee libre : sorties comptees", Sm.counted({ tour = "libre" }) == true)
  c("meurtrier exclu", Sm.counted({ tour = "libre", lethal = true }) == false)
  c("dangereux exclu", Sm.counted({ tour = "libre", unsafe = true }) == false)
  c("2 tournees ratees : compte", Sm.counted({ tour = "libre", fails = Sm.FAILS_MAX - 1 }) == true)
  c("3 tournees ratees : exclu", Sm.counted({ tour = "libre", fails = Sm.FAILS_MAX }) == false)
  c("rangee absente : exclue", Sm.counted(nil) == false)
  c("tournee libre depuis peu : compte", Sm.counted({ tour = "libre", free_age = Sm.STALE_TICKS - 1 }) == true)
  c("tournee libre depuis 5 min : exclu", Sm.counted({ tour = "libre", free_age = Sm.STALE_TICKS }) == false)
  -- §2 bis (lot ETAGE4) : la tournée doit être VIVANTE
  c("aucune tournee (absente, en pause) : exclu", Sm.counted({}) == false)
  c("tournee prise qui progresse : compte", Sm.counted({ tour = "prise", stall = 0 }) == true)
  c("tournee prise, progres juste sous le bail : compte", Sm.counted({ tour = "prise", stall = Bl.LEASE - 1 }) == true)
  c("tournee prise sans progres depuis le bail : exclu (cas d'Emeraude)", Sm.counted({ tour = "prise", stall = Bl.LEASE }) == false)
  c("prise meme tres ancienne mais qui progresse : compte", Sm.counted({ tour = "prise", stall = 10, free_age = 1e9 }) == true)
  c("prise avant l'acte, tenue au-dela de la tenue maximale : exclu", Sm.counted({ tour = "prise", stall = 0, held = Bl.MAX_HOLD, pre_act = true }) == false)
  c("prise apres l'acte, longue mais qui progresse : compte (M1)", Sm.counted({ tour = "prise", stall = 0, held = 1e9, pre_act = false }) == true)
  c("sur : ni meurtrier ni dangereux ni ratees", Sm.safe({}) == true and Sm.safe({ unsafe = true }) == false
    and Sm.safe({ lethal = true }) == false and Sm.safe({ fails = Sm.FAILS_MAX }) == false and Sm.safe(nil) == false)
  -- §3
  local rows = {
    { id = 3, kind = "noir", outputs = { R1 = 300 }, tour = "libre" },
    { id = 1, kind = "noir", outputs = { R1 = 500 }, tour = "prise", stall = 60 },
    { id = 2, kind = "noir", outputs = { R1 = 300 }, tour = "libre" },
    { id = 4, kind = "noir", outputs = { R1 = 900 }, unsafe = true, tour = "libre" },
    { id = 5, kind = "gris", outputs = { R2 = 70 }, tour = "libre" },
    { id = 6, kind = "rouge", outputs = { P1 = 400, R1 = 50 }, tour = "libre" },
    { id = 7, kind = "noir", outputs = {}, tour = "libre" },
    { id = 8, kind = "noir", outputs = { R1 = 1666 }, tour = "prise", stall = 2479 * 60 }, -- Émeraude : tenue 41 min sans progrès
    { id = 9, kind = "noir", outputs = { R1 = 700 } },                                     -- aucune tournée au tableau
  }
  local total, ids = Sm.dormant(rows, raw, "R1")
  c("total des bruts comptes", total == 1100)
  c("ordre : le plus garni d'abord, puis id", ids[1] == 1 and ids[2] == 2 and ids[3] == 3 and #ids == 3)
  c("autre ressource a part", (Sm.dormant(rows, raw, "R2")) == 70)
  c("plaque d'un fondu jamais comptee", (Sm.dormant(rows, raw, "P1")) == 0)
  c("rien : 0", (Sm.dormant(nil, raw, "R1")) == 0)
  -- §4
  local ok, why = Sm.hand_ok({ dormant = 1100 })
  c("sorties garnies : minage refuse", ok == false and why == "sorties")
  c("juste au seuil : refuse", Sm.hand_ok({ dormant = Sm.MIN }) == false)
  c("sous le seuil : mine", Sm.hand_ok({ dormant = Sm.MIN - 1 }) == true)
  c("rien : mine", Sm.hand_ok({}) == true)
  ok, why = Sm.hand_ok({ dormant = 1100, crisis = true })
  c("crise injectee : mine", ok == true and why == "crise")
  -- §5
  local o = { kind = "noir", outputs = { R1 = 300 } }
  c("coffre vide : urgence", Sm.fetch_prio(70, o, raw, 0) == Sm.FETCH_PRIO)
  c("urgence au-dessus de 90", Sm.FETCH_PRIO > 90)
  c("a sec (95) garde 95", Sm.fetch_prio(95, o, raw, 0) == 95)
  c("coffre garni : inchange", Sm.fetch_prio(70, o, raw, Sm.COVER) == 70)
  c("coffre juste sous le seuil : urgence", Sm.fetch_prio(70, o, raw, Sm.COVER - 1) == Sm.FETCH_PRIO)
  c("sorties maigres : inchange", Sm.fetch_prio(70, { kind = "noir", outputs = { R1 = Sm.MIN - 1 } }, raw, 0) == 70)
  c("dangereux : inchange", Sm.fetch_prio(70, { kind = "noir", outputs = { R1 = 300 }, unsafe = true }, raw, 0) == 70)
  c("meurtrier : inchange", Sm.fetch_prio(70, { kind = "noir", outputs = { R1 = 300 }, lethal = true }, raw, 0) == 70)
  c("fondu : inchange", Sm.fetch_prio(70, { kind = "rouge", outputs = { P1 = 300 } }, raw, 0) == 70)
  c("urgence posee meme sans tournee au tableau (le planificateur la pose)", Sm.fetch_prio(70, { kind = "noir", outputs = { R1 = 300 } }, raw, 0) == Sm.FETCH_PRIO)
  c("tournee libre depuis 5 min : pas d'urgence", Sm.fetch_prio(70, { kind = "noir", outputs = { R1 = 300 }, free_age = Sm.STALE_TICKS }, raw, 0) == 70)
  c("interrupteur : nil = allume", Sm.on(nil) == true and Sm.on(true) == true and Sm.on(false) == false)
  -- §5 bis : combustible porté du coffre
  c("avant-poste ordinaire : tout le besoin", Sm.carry_fuel(120, false, 0) == 120)
  c("ordinaire : ses sorties n'y changent rien", Sm.carry_fuel(120, false, 500) == 120)
  c("combustible a sec, coffres vides : tout le besoin", Sm.carry_fuel(120, true, 0) == 120)
  c("combustible : le complement seulement", Sm.carry_fuel(120, true, 50) == 70)
  c("combustible : sorties qui couvrent -> rien", Sm.carry_fuel(120, true, 300) == 0)
  c("aucun besoin : rien", Sm.carry_fuel(0, true, 0) == 0 and Sm.carry_fuel(-5, false, 0) == 0)
  return res
end

local Sm = assert(load_sm(SRC), "module illisible")
for _, r in ipairs(suite(Sm)) do check(r[1], r[2]) end

-- §6 câblage
local W = read("script/team/worker.lua")
local S = read("script/team/sorties.lua")
local P = read("shared/team/planner.lua")
local TM = read("script/team/team.lua")
local R = read("script/team/ia1_remote.lua")
check("worker : require du lecteur", W:find('require("script.team.sorties")', 1, true) ~= nil)
check("worker : verdict des sorties au minage", W:find("Sorties.hand_ok(f, task.resource, tick, task.crisis)", 1, true) ~= nil)
check("worker : refus ecrit (main:sorties)", W:find('"main:sorties"', 1, true) ~= nil)
check("lecteur : regle pure", S:find("Sm.hand_ok(", 1, true) ~= nil and S:find("Sm.dormant(", 1, true) ~= nil)
check("lecteur : interrupteur", S:find("Sm.on(f.team.sorties_regle)", 1, true) ~= nil)
check("lecteur : danger releve", S:find("Poles.DANGER_RADIUS", 1, true) ~= nil and S:find("lethal_ticks", 1, true) ~= nil)
check("lecteur : etat de la tournee (prise, libre, sans progres)", S:find("local tour, free_age, stall, held, pre_act = S.tour(f, oid, tick)", 1, true) ~= nil
  and S:find("t.prog and t.prog.t", 1, true) ~= nil)
check("journal [FO-SEC] appele apres le plan", TM:find("SortiesLog.report(f, view, tick)", 1, true) ~= nil)
check("worker : complement de combustible vers l'avant-poste de combustible", W:find("carry = Sorties.carry_fuel(f, o, need)", 1, true) ~= nil)
check("worker : regle coupee = 0.6.41 (rien vers le combustible)", W:find('if o.kind == "coal" then carry = 0 end', 1, true) ~= nil)
check("planificateur : priorite de la tournee", P:find("Sm.fetch_prio(p, o, RAW, have)", 1, true) ~= nil)
check("planificateur : seulement quand le danger est releve", P:find("view.sorties_on and (o.fuel_low or o.output >= T.collect_at)", 1, true) ~= nil)
check("vue : interrupteur", TM:find("sorties_on = f.team.sorties_regle ~= false or nil", 1, true) ~= nil)
check("remote : interrupteur de banc", R:find("set_regle_sorties", 1, true) ~= nil)

-- §7 mutants
local MUTANTS = {
  { "fondu pris pour brut", "if s.resource ~= nil and s.product == s.resource then", "if s.resource ~= nil then" },
  { "meurtrier compte", "if not o or o.lethal or o.unsafe then return false end", "if not o or o.unsafe then return false end" },
  { "dangereux compte", "if not o or o.lethal or o.unsafe then return false end", "if not o or o.lethal then return false end" },
  { "tournees ratees ignorees", "return num(o.fails) < Sm.FAILS_MAX", "return true" },
  { "tournee non exigee (avant ETAGE4)", "return Bl.alive(o.tour, o.free_age, o.stall, Sm.STALE_TICKS, o.held, o.pre_act)", "return true" },
  { "urgence pour une tournee oubliee", "or num(o.free_age) >= Sm.STALE_TICKS then return base end", "then return base end" },
  { "sorties non comptees", "if raw[o.kind] == item and Sm.counted(o) then", "if raw[o.kind] == item then" },
  { "ordre inverse", "if a.n ~= b.n then return a.n > b.n end", "if a.n ~= b.n then return a.n < b.n end" },
  { "jamais refuse", "if num(a.dormant) >= Sm.MIN then return false, \"sorties\" end", "" },
  { "crise refusee", "if a.crisis then return true, \"crise\" end", "" },
  { "seuil strict", "if num(a.dormant) >= Sm.MIN then", "if num(a.dormant) > Sm.MIN then" },
  { "urgence meme coffre garni", "or num(have) >= Sm.COVER then return base end", "then return base end" },
  { "urgence vers un dangereux", "if not res or not Sm.safe(o) or", "if not res or" },
  { "sur sans les ratees", "return num(o.fails) < Sm.FAILS_MAX", "return true" },
  { "urgence abaisse le ravitaillement", "return math.max(num(base), Sm.FETCH_PRIO)", "return Sm.FETCH_PRIO" },
  { "urgence sous 90", "Sm.FETCH_PRIO = 91", "Sm.FETCH_PRIO = 89" },
  { "interrupteur inverse", "function Sm.on(flag) return flag ~= false end", "function Sm.on(flag) return flag == true end" },
  { "combustible jamais porte (0.6.41)", "return math.max(0, need - num(own))", "return 0" },
  { "sorties propres ignorees", "return math.max(0, need - num(own))", "return need" },
  { "besoin nul porte", "if need <= 0 then return 0 end", "" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local mut = load_sm(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    local seen = mut == nil
    if not seen then
      local ok, res = pcall(suite, mut)
      if not ok then seen = true else
        for _, r in ipairs(res) do if not r[2] then seen = true break end end
      end
    end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, #MUTANTS, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUTANTS)

-- §8 aucun nom d'objet du jeu dans le module (ni dans les chaînes de code, commentaires exclus)
local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
local names = { "coal", "stone", "iron", "copper", "chest", "furnace", "drill", "plate", "ore" }
local found = {}
for _, n in ipairs(names) do if code:find('"' .. n, 1, true) or code:find(n .. '"', 1, true) then found[#found + 1] = n end end
check("aucun nom d'objet dans le module" .. (#found > 0 and (" : " .. table.concat(found, ",")) or ""), #found == 0)

print(string.format("[SORTIES] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
