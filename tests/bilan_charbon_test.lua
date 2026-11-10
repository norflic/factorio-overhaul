-- Lot CHARBON-CAPACITE (F485) : bilan du combustible du planificateur, cadences lues aux données (shared/team/bilan_charbon.lua).
-- Lancer : lua5.2 tests/bilan_charbon_test.lua
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1; print("ECHEC : " .. msg) end end
local function near(a, b) return a and b and math.abs(a - b) < 1e-9 end

local path = "shared/team/bilan_charbon.lua"
local fh = assert(io.open(path, "rb")); local SRC = fh:read("*a"); fh:close()
local function load_rule(mut)
  local s = mut and mut(SRC) or SRC
  local f = assert(load(s, "=bilan_charbon"))
  return f()
end

-- Table de machines de banc (valeurs vanilla) et données changées (preuve « rien en dur »)
local SPEC = {
  ["burner-mining-drill"] = { speed = 0.25, burner_kw = 150 },
  ["stone-furnace"] = { burner_kw = 90 },
  ["iron-chest"] = {},
}
local CFG = {
  coal = { product = "coal", sink = "iron-chest" },
  iron = { product = "iron-plate", sink = "stone-furnace" },
  stone = { product = "stone", sink = "iron-chest" },
}
local function spec(n) return SPEC[n] end
local D = { spec = spec, drill = "burner-mining-drill", fuel_kj = 4000, mining_time = 1 }
local OUT = { { kind = "coal", drills = 4 }, { kind = "iron", drills = 8 } }

local function scenario(Bc)
  local r = {}
  local rates = Bc.rates(D)
  r.out, r.burn, r.furn = rates and rates.drill_out, rates and rates.drill_burn, rates and rates.burn_of("stone-furnace")
  r.coal, r.b = Bc.balance(OUT, CFG, "coal", rates, 2, "stone-furnace", 0.5)
  -- données changées : foreuse 2 fois plus lente, minerai 2 fois plus long, combustible 2 fois plus calorifique
  local spec2 = function(n)
    if n == "burner-mining-drill" then return { speed = 0.125, burner_kw = 150 } end
    return SPEC[n]
  end
  local r2 = Bc.rates({ spec = spec2, drill = "burner-mining-drill", fuel_kj = 8000, mining_time = 2 })
  r.out2, r.burn2 = r2 and r2.drill_out, r2 and r2.drill_burn
  -- un combustible autre que le charbon (données changées) : l'avant-poste qui le produit compte, plus celui du charbon
  r.coal3 = Bc.balance({ { kind = "coal", drills = 4 }, { kind = "stone", drills = 2 } }, CFG, "stone", rates, 0, "stone-furnace", 0)
  r.need_lo = Bc.need_more(1.0, 1.0) -- 1 < 1,4 : il en faut
  r.need_hi = Bc.need_more(1.5, 1.0) -- 1,5 >= 1,4 : non
  return r
end

-- §1 : la règle telle quelle
local Bc = load_rule()
local r = scenario(Bc)
check(near(r.out, 0.25), "cadence d'extraction = vitesse / temps de minage (0,25)")
check(near(r.burn, 0.0375), "brûlé d'une foreuse = 150 kW / 4 000 kJ (0,0375)")
check(near(r.furn, 0.0225), "brûlé d'un four = 90 kW / 4 000 kJ (0,0225)")
check(near(r.coal, 1.0), "production : 4 foreuses de charbon × 0,25 = 1")
-- brûlé : 12 foreuses × 0,0375 + 8 fours de l'avant-poste de fer × 0,0225 + 2 fours de fonderie × 0,0225 + 0,5 du plan
check(near(r.b, 12 * 0.0375 + 8 * 0.0225 + 2 * 0.0225 + 0.5), "brûlé : foreuses, fours des avant-postes et de la fonderie, plan directeur")
check(near(r.out2, 0.0625), "données changées : 0,125 / 2 = 0,0625 (rien en dur)")
check(near(r.burn2, 150 / 8000), "données changées : brûlé lu à la valeur du combustible")
check(near(r.coal3, 2 * 0.25), "combustible changé : l'avant-poste dont le PRODUIT est le combustible compte, pas un nom")
check(r.need_lo == true and r.need_hi == false, "seuil de marge 1,4 inchangé")
check(Bc.rates({ spec = spec, drill = "inconnue", fuel_kj = 4000, mining_time = 1 }) == nil, "foreuse inconnue : refus écrit")
check(Bc.rates({ spec = spec, drill = "burner-mining-drill", fuel_kj = 0, mining_time = 1 }) == nil, "combustible sans valeur : refus")

-- §2 : forme (code seul, commentaires retirés)
local CODE = SRC:gsub("%-%-[^\n]*", "")
check(not CODE:find("0%.0375") and not CODE:find("0%.0225") and not CODE:find("0%.25[^%d]"), "aucune cadence en dur dans la règle")
check(not CODE:find('"coal"') and not CODE:find('"stone%-furnace"'), "aucun nom d'objet en dur dans la règle")
check(not CODE:find("[^i]pairs%("), "aucun pairs dans la règle")

-- §3 : câblage
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local planner = read("shared/team/planner.lua")
check(planner:find("Bc.rates({ spec = Mach.spec, drill = T.DRILL, fuel_kj = Mach.COAL_J", 1, true) ~= nil, "le planificateur lit les cadences aux données")
check(planner:find("Bc.need_more(coal_rate, burn_rate)", 1, true) ~= nil, "le planificateur décide par Bc.need_more")
check(not planner:find("o.drills * 0.25", 1, true) and not planner:find("o.drills * 0.0375", 1, true), "plus de cadence en dur dans le planificateur")
local build = read("script/team/build.lua")
check(build:find('if sp and sp.kind == "drill" and sp.burner_kw then kw = kw + sp.burner_kw end', 1, true) ~= nil,
  "Build.burn_rate compte les foreuses à brûleur des bandes du plan")
local team = read("script/team/team.lua")
check(team:find("fuel_mining_time = fuel_mining_time()", 1, true) ~= nil, "la vue publie le temps de minage du combustible")

-- §4 : mutants (chacun doit faire échouer au moins un contrôle du scénario)
local function differs(mut)
  local okl, B = pcall(load_rule, mut)
  if not okl then return true end
  local okr, m = pcall(scenario, B)
  if not okr then return true end
  return not (near(m.out, r.out) and near(m.burn, r.burn) and near(m.furn, r.furn) and near(m.coal, r.coal) and near(m.b, r.b)
    and near(m.out2, r.out2) and near(m.burn2, r.burn2) and near(m.coal3, r.coal3) and m.need_lo == r.need_lo and m.need_hi == r.need_hi)
end
local MUT = {
  { "constante en dur remise (extraction 0,25)", function(s) return (s:gsub("drill_out = ds%.speed / d%.mining_time", "drill_out = 0.25")) end },
  { "valeur du combustible ignorée", function(s) return (s:gsub("s%.burner_kw / fuel_kj", "s.burner_kw / 4000")) end },
  { "temps de minage ignoré", function(s) return (s:gsub("ds%.speed / d%.mining_time", "ds.speed")) end },
  { "seuil de marge changé", function(s) return (s:gsub("Bc%.MARGIN = 1%.4", "Bc.MARGIN = 1.6")) end },
  { "fours de fonderie oubliés", function(s) return (s:gsub("%(smelters or 0%) %* r%.burn_of%(smelter_name%)", "0")) end },
  { "fours des avant-postes oubliés", function(s) return (s:gsub(" %+ o%.drills %* r%.burn_of%(spec and spec%.sink%)", "")) end },
  { "avant-poste de combustible par son nom", function(s) return (s:gsub("spec%.product == fuel", 'o.kind == "coal"')) end },
  { "plan directeur oublié", function(s) return (s:gsub(" %+ %(build_burn or 0%)", "")) end },
}
local refused = 0
for _, m in ipairs(MUT) do
  local d = differs(m[2])
  if d then refused = refused + 1 else print("mutant survivant : " .. m[1]) end
  check(d, "mutant refusé : " .. m[1])
end

print(string.format("[BILAN-CHARBON] BILAN : %d OK, %d ECHEC(S) (%d mutants refusés sur %d)", ok_n, fail_n, refused, #MUT))
os.exit(fail_n == 0 and 0 or 1)
