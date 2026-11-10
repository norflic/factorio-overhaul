--[[
  Tests hors jeu du lot CHARBON-UNIFIE (directive « Mode Démon » du DC, 10/11, priorité 1) : une seule règle de réserve du charbon,
  shared/team/reserve_charbon.lua, lue par le planificateur, le quai de la centrale, l'amorce à la main et les tournées.
  1. Règle pure : parts dans l'ordre vital > brûleurs > confort > libre, besoin d'une centrale, tampon, avant-poste de combustible.
  2. Les deux falaises mesurées (RD_LOG F445 et F455) rejouées sur la règle.
  3. Chaîne statique : planner.lua, build.lua (quai_tasks), sante_centrale.lua, worker.lua, fond.lua lisent la règle ; plus aucun
     nom de gisement en dur (`kind == "coal"`).
  4. Mutants (la règle réécrite, la batterie doit casser).
  Usage, depuis la racine du mod :   lua5.2 tests/reserve_charbon_test.lua
]]
package.path = "./?.lua;" .. package.path
local Rc0 = require("shared.team.reserve_charbon")
local Cc = require("shared.team.charbon_centrale")
local S = require("shared.team.sante_centrale")
local M = require("shared.team.modules")
local T = require("shared.team.config")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
end
local function section(name) if not quiet then print("== " .. name) end end
local function slurp(path) local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s end

local RATE1 = M.BASE.boiler.burner_kw / M.COAL_J -- 0,45/s : une chaudière à pleine charge

local function battery(Rc)
  section("1a. Parts dans l'ordre : vital > bruleurs > confort > libre")
  local p = Rc.parts(1000, { vital = 100, bruleurs = 300, confort = 200 })
  check(p.vital == 100 and p.bruleurs == 300 and p.confort == 200 and p.libre == 400 and p.stock == 1000, "stock large : chaque part a son besoin, 400 libres")
  p = Rc.parts(250, { vital = 100, bruleurs = 300, confort = 200 })
  check(p.vital == 100 and p.bruleurs == 150 and p.confort == 0 and p.libre == 0, "stock court : le vital d'abord, les bruleurs prennent le reste, rien au confort")
  p = Rc.parts(50, { vital = 100, bruleurs = 300, confort = 200 })
  check(p.vital == 50 and p.bruleurs == 0 and p.confort == 0 and p.libre == 0, "stock plus court que le vital : tout au vital")
  p = Rc.parts(0, { vital = 100 })
  check(p.vital == 0 and p.libre == 0 and p.stock == 0, "coffre vide : rien, jamais negatif")
  p = Rc.parts(nil, nil)
  check(p.vital == 0 and p.bruleurs == 0 and p.confort == 0 and p.libre == 0, "sans stock ni besoin : zeros")
  p = Rc.parts(-5, { vital = -3, bruleurs = 2.7 })
  check(p.stock == 0 and p.vital == 0 and p.bruleurs == 0 and p.libre == 0, "valeurs negatives : ramenees a 0 (entiers)")
  p = Rc.parts(10.9, { bruleurs = 2.7 })
  check(p.stock == 10 and p.bruleurs == 2 and p.libre == 8, "fractions : parties entieres")
  p = Rc.parts(600, { bruleurs = 300, confort = 200 })
  check(p.vital == 0 and p.bruleurs == 300 and p.confort == 200 and p.libre == 100, "sans besoin vital : les bruleurs puis le confort")
  check(Rc.centrale(1000, { vital = 100, bruleurs = 300, confort = 200 }) == 300, "part de la centrale = vital + confort")
  check(Rc.vital(1000, { vital = 100, bruleurs = 300, confort = 200 }) == 100 and Rc.vital(40, { vital = 100 }) == 40, "part de l'amorce = vital")
  check(Rc.libre(1000, { vital = 100, bruleurs = 300, confort = 200 }) == 400 and Rc.libre(500, { vital = 100, bruleurs = 300, confort = 200 }) == 0, "part libre")
  check(Rc.ORDER[1] == "vital" and Rc.ORDER[2] == "bruleurs" and Rc.ORDER[3] == "confort" and #Rc.ORDER == 3, "ordre fixe des parts")

  section("1b. Besoin d'une centrale nourrie a la main (seuil d'avance, cible, amorce)")
  local r = Cc.refill(0, RATE1, nil, 1600) -- 1 chaudiere : seuil 108, cible 540
  check(r.low == 108 and r.target == 540, "Cc.refill rend le seuil (108) et la cible (540) sans stock")
  local n = Rc.need_centrale(0, 108, 540, 0)
  check(n.vital == 108 and n.confort == 432, "coffre a 0 : vital 108 (jusqu'au seuil), confort 432 (du seuil a la cible)")
  n = Rc.need_centrale(100, 108, 540, 0)
  check(n.vital == 8 and n.confort == 432, "coffre a 100 : vital 8, confort 432")
  n = Rc.need_centrale(300, 108, 540, 0)
  check(n.vital == 0 and n.confort == 240, "coffre a 300 (au-dessus du seuil) : vital 0, confort 240")
  n = Rc.need_centrale(600, 108, 540, 0)
  check(n.vital == 0 and n.confort == 0, "coffre au-dessus de la cible : rien")
  n = Rc.need_centrale(0, 108, 540, 150)
  check(n.vital == 258 and n.confort == 432, "amorce due de 150 (3 chaudieres a sec x 50) : dans le vital")
  n = Rc.need_centrale(nil, nil, nil, nil)
  check(n.vital == 0 and n.confort == 0, "sans valeurs : zeros")

  section("1c. Tampon des bruleurs (consommation x horizon)")
  check(Rc.HORIZON_S == 120, "horizon : une tournee (120 s)")
  check(Rc.buffer(0) == 0 and Rc.buffer(nil) == 0 and Rc.buffer(-1) == 0, "sans consommation : 0")
  check(Rc.buffer(0.0375 * 20) == 90, "20 foreuses a combustible (0,0375/s chacune) : 90 charbons sur 120 s")
  check(Rc.buffer(0.45, 100) == 45, "horizon donne : 0,45/s x 100 s = 45")
  check(Rc.buffer(0.001) == 1, "arrondi au-dessus : jamais 0 pour une consommation non nulle")

  section("1d. Avant-poste de combustible : par les donnees (produit = combustible), jamais par le nom du gisement")
  check(Rc.is_fuel_outpost({ product = "coal" }, "coal") == true, "produit = combustible : oui")
  check(Rc.is_fuel_outpost({ product = "iron-plate" }, "coal") == false, "produit autre : non")
  check(Rc.is_fuel_outpost({ resource = "coal", product = "briquette" }, "briquette") == true, "un autre combustible des donnees : oui, par le produit")
  check(Rc.is_fuel_outpost(nil, "coal") == false and Rc.is_fuel_outpost({ product = "coal" }, nil) == false, "sans spec ou sans combustible : non")
  for _, k in ipairs(T.OUTPOST_ORDER) do
    check(Rc.is_fuel_outpost(T.outposts[k], T.fuel) == (T.outposts[k].product == T.fuel), "T.outposts." .. k .. " : verdict des donnees")
  end

  section("1e. Journal")
  local line = Rc.line("player centrale 1", 36.3, Rc.parts(400, { vital = 108, bruleurs = 588, confort = 432 }), { vital = 108, bruleurs = 588, confort = 432 })
  check(line:find("[FO-CHARBON] player centrale 1 : coffre du QG 400 charbon(s) a 36.3 min : vital 108/108, bruleurs 292/588, confort 0/432, libre 0", 1, true) ~= nil, "ligne [FO-CHARBON] : " .. line)

  section("2. Les deux falaises mesurees, rejouees sur la regle")
  -- F445 (B4, banc V0676-D, 36,3 min) : 400 au coffre du QG, centrale (1 chaudiere, coffre a 0), 46 bruleurs de fer a sec (deficit 588) :
  -- avant : la centrale prenait les 400 (cible 1080) ; avec la regle : son seuil d'avance (108) d'abord, les bruleurs ensuite (292), le confort attend
  local need = Rc.need_centrale(0, 108, 540, 0)
  need.bruleurs = 588
  p = Rc.parts(400, need)
  check(p.vital == 108 and p.bruleurs == 292 and p.confort == 0 and p.libre == 0, "F445 : centrale 108 (vital), bruleurs 292, confort 0 : plus de coffre du QG vide par la centrale")
  check(Rc.centrale(400, need) == 108 and Rc.libre(400, need) == 0, "F445 : la centrale porte 108, rien de libre pour la fabrication")
  -- F455 (banc V0677-FINAL-A, 15,9 min) : 79 au coffre, 2 chaudieres a sec (amorce 100), reserve des bruleurs 300 > stock :
  -- avant (coupe BRULEURS-60) : « pas d'amorce (stock de combustible insuffisant) » ; avec la regle : l'amorce est VITALE, servie d'abord
  local st = {}
  local pr = S.prime(st, 2, Rc.vital(79, { vital = 2 * S.PRIME, bruleurs = 300 }), 1000)
  check(pr ~= nil and pr.boilers == 2 and pr.total == 78, "F455 : l'amorce prend 78 des 79 charbons malgre 300 reserves aux bruleurs (le courant d'abord)")
  pr = S.prime({}, 2, Rc.vital(5, { vital = 2 * S.PRIME, bruleurs = 300 }), 1000)
  check(pr == nil, "F455 : 5 charbons : pas d'amorce utile (regle de S.prime), la cause reste rendue")
  -- F455 (2) : les bruleurs viennent d'etre remplis (deficit 0) : avant, la centrale vidait le coffre pour sa cible de 20 min ;
  -- avec la regle, le tampon d'une tournee reste au coffre
  need = Rc.need_centrale(108, 108, 540, 0)
  need.bruleurs = 0 + Rc.buffer(0.0375 * 60 + 0.0225 * 60) -- 60 foreuses et 60 fours a combustible : 432
  p = Rc.parts(500, need)
  check(need.bruleurs == 432 and p.bruleurs == 432 and p.confort == 68, "F455 (2) : bruleurs pleins, le tampon de la tournee suivante (432) reste, le confort de la centrale prend 68")
end

battery(Rc0)

section("3. Chaine statique")
do
  local planner = slurp("shared/team/planner.lua")
  check(planner:find('o.kind ~= "coal"', 1, true) == nil and planner:find('o.kind == "coal"', 1, true) == nil, "planner.lua : plus d'exclusion du charbon par son nom")
  check(planner:find('kind == "coal" and 2 *', 1, true) == nil, "planner.lua : l'amorce d'un avant-poste de combustible n'est plus par le nom")
  check(planner:find('require("shared.team.reserve_charbon")', 1, true) ~= nil, "planner.lua : lit la regle")
  check(planner:find("avail[T.fuel] = Rc.libre(avail[T.fuel] or 0, fuel_need)", 1, true) ~= nil, "planner.lua : la fabrication prend la part LIBRE")
  check(planner:find("fuel_need.bruleurs = fuel_need.bruleurs + Rc.buffer(tour_rate)", 1, true) ~= nil, "planner.lua : le tampon d'une tournee est dans la part des bruleurs")
  check(planner:find("vital = plant_coal.vital or 0, confort = plant_coal.confort or 0", 1, true) ~= nil, "planner.lua : la centrale (vue) a ses parts vital et confort")
  local a = planner:find("local coal_rate, burn_rate = 0, 0", 1, true)
  local b = planner:find("avail[T.fuel] = Rc.libre(", 1, true)
  local c = planner:find("tour_rate = burn_rate", 1, true)
  check(a and b and c and a < c and c < b, "planner.lua : le bilan du charbon (tour_rate) precede la reserve")

  local build = slurp("script/team/build.lua")
  check(build:find('Build.Rc = require("shared.team.reserve_charbon")', 1, true) ~= nil, "build.lua : lit la regle (champ de Build)")
  check(build:find("have = parts.vital + parts.confort", 1, true) ~= nil and build:find("local parts = Rc.parts(have, need)", 1, true) ~= nil, "build.lua quai_tasks : la centrale prend vital + confort")
  check(build:find("have = Rc.libre(have, { bruleurs = burners })", 1, true) ~= nil, "build.lua quai_tasks : le quai de combustible d'un champ prend le libre")
  check(build:find("Cc.free_fuel(have, burner_fuel_reserve())", 1, true) == nil, "build.lua : plus de lecteur « stock moins reserve »")
  check(build:find("function Build.plant_fuel_need(f, tick)", 1, true) ~= nil and build:find("Build.Rc.need_centrale(n, r.low, r.target, Sante.prime_need(f, p))", 1, true) ~= nil, "build.lua : besoin des centrales pour la vue")
  check(build:find("return n + Rc.buffer(rate)", 1, true) ~= nil and build:find("if not Rc.is_fuel_outpost(spec, T.fuel) then n = n + Outposts.coal_needed(o, fill) end", 1, true) ~= nil, "build.lua : reserve des bruleurs = deficit + tampon, avant-poste de combustible par les donnees")
  check(build:find("log(Rc.line(", 1, true) ~= nil and build:find("if first and sig == \"vc\" then return end", 1, true) ~= nil, "build.lua : journal [FO-CHARBON] par Rc.line, une ligne par changement")

  local team = slurp("script/team/team.lua")
  check(team:find("plant_coal = Profiler.fwrap(\"view:5-centrale\", Build.plant_fuel_need, f, tick)", 1, true) ~= nil, "team.lua : la vue porte plant_coal")

  local sante = slurp("script/team/sante_centrale.lua")
  check(sante:find("local stock = Rc.vital(Stock.count(f, T.fuel), { vital = c.boilers.dry * S.PRIME })", 1, true) ~= nil, "sante_centrale.lua : l'amorce prend la part vitale")
  check(sante:find("function Sante.prime_need(f, p)", 1, true) ~= nil, "sante_centrale.lua : amorce due exposee (Sante.prime_need)")

  local worker = slurp("script/team/worker.lua")
  check(worker:find('if o.kind == "coal" then carry = 0 end', 1, true) == nil and worker:find("if Rsv.is_fuel_outpost(T.outposts[o.kind], T.fuel) then carry = 0 end", 1, true) ~= nil and worker:find("local Rc = require(\"shared.team.repli_chemin\")", 1, true) ~= nil, "worker.lua : avant-poste de combustible par les donnees")
  local fond = slurp("shared/team/fond.lua")
  check(fond:find('kind == "coal"', 1, true) == nil and fond:find("Rc.is_fuel_outpost(spec, T.fuel) and 2 * pairs", 1, true) ~= nil, "fond.lua : idem")
  for _, path in ipairs({ "script/team/build.lua", "script/team/worker.lua", "shared/team/planner.lua", "shared/team/fond.lua", "script/team/sante_centrale.lua", "script/team/team.lua" }) do
    local src = slurp(path)
    check(src:find('kind == "coal"', 1, true) == nil and src:find('kind ~= "coal"', 1, true) == nil, path .. " : aucun test du genre d'avant-poste par le nom « coal »")
  end
end

section("4. Mutants")
local SRC = slurp("shared/team/reserve_charbon.lua")
local function load_rule(edit)
  local s = edit(SRC)
  assert(s ~= SRC, "mutant sans effet")
  return assert(load(s, "reserve_charbon_mutant", "t"))()
end
local function survivors(edit)
  local ok, Rc = pcall(load_rule, edit)
  if not ok then return 1 end
  local p0, f0, q0 = passes, failures, quiet
  quiet = true
  local okb = pcall(battery, Rc)
  local died = (not okb) or failures > f0
  passes, failures, quiet = p0, f0, q0
  return died and 1 or 0
end
local function mutant(label, edit) check(survivors(edit) > 0, "mutant refuse : " .. label) end
mutant("bruleurs servis avant la centrale", function(s) return (s:gsub('Rc.ORDER = { "vital", "bruleurs", "confort" }', 'Rc.ORDER = { "bruleurs", "vital", "confort" }')) end)
mutant("confort servi avant les bruleurs", function(s) return (s:gsub('Rc.ORDER = { "vital", "bruleurs", "confort" }', 'Rc.ORDER = { "vital", "confort", "bruleurs" }')) end)
mutant("rien de reserve (tout libre)", function(s) return (s:gsub("    local take = n < rest and n or rest\n", "    local take = 0\n")) end)
mutant("part non bornee par le reste", function(s) return (s:gsub("    local take = n < rest and n or rest\n", "    local take = n\n")) end)
mutant("besoins negatifs non ramenes a 0", function(s) return (s:gsub("if n < 0 then return 0 end", "")) end)
mutant("amorce hors du vital", function(s) return (s:gsub("local vital = %(low > n and low %- n or 0%) %+ whole%(prime%)", "local vital = (low > n and low - n or 0)")) end)
mutant("confort compte depuis le coffre, pas depuis le seuil", function(s) return (s:gsub("local base = n > low and n or low", "local base = n")) end)
mutant("tampon nul", function(s) return (s:gsub("return math.ceil%(rate %* %(horizon or Rc.HORIZON_S%) %- 1e%-9%)", "return 0")) end)
mutant("avant-poste de combustible par le nom du gisement", function(s) return (s:gsub("return spec ~= nil and fuel ~= nil and spec.product == fuel", 'return spec ~= nil and spec.resource == "coal"')) end)
mutant("part de la centrale sans le confort", function(s) return (s:gsub("return p.vital %+ p.confort", "return p.vital")) end)

print(string.format("[RESERVE-CHARBON] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
