--[[
  Tests hors jeu du lot VAPEUR (14/11) : demande nominale, capacité, extension (shared/team/vapeur.lua) et son branchement dans la
  croissance de la centrale (shared/team/centrale.lua, n.nominal_kw).
  Usage :   lua5.2 tests/vapeur_test.lua
]]
package.path = "./?.lua;" .. package.path
local V = require("shared.team.vapeur")
local C = require("shared.team.centrale")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

print("== 1. Demande et capacite nominales")
check(V.demand_kw({ { count = 10, kw = 90 }, { count = 2, kw = 150 } }) == 1200, "somme count x kW")
check(V.demand_kw({ { count = -1, kw = 90 }, { count = 3, kw = 0 / 0 } }) == 0, "valeurs absurdes ignorees")
check(V.demand_kw(nil) == 0, "rien : 0")
check(V.capacity_kw(1800, 1800) == 1800 and V.capacity_kw(3600, 1800) == 1800 and V.capacity_kw(900, 1800) == 900, "min machines / chaudieres")
check(V.capacity_kw(1800, nil) == 1800, "chaudieres inconnues : machines seules")

print("== 2. Extension a la demande nominale + 30 %")
check(V.missing_kw(1000, 1800, 0) == 0, "1300 <= 1800 : suffisante")
check(math.abs(V.missing_kw(1500, 1800, 0) - 150) < 1e-9, "1950 - 1800 = 150 kW manquants")
check(V.missing_kw(1500, 1800, 1800) == 0, "les chantiers ouverts comptent")
check(V.missing_kw(1384, 1800, 0) == 0 and V.missing_kw(1385, 1800, 0) > 0, "seuil a capacite / 1,3")
check(V.fed_share(1, 2) == 0.5 and V.fed_share(0, 0) == nil, "part alimentee")
check(V.line({ team = "player", tick = 108000, demand = 1500, cap = 1800, missing = 150, fed = 1, boilers = 1, auto = 1, plants = 1 }):find("[FO-VAPEUR] player", 1, true) ~= nil,
  "ligne de journal")

print("== 3. Branchement dans C.growth")
local function base() return { done = 1, pending = 0, refused = 0, hold = false, off = false, boiler_kw = 1800, load = 0.1 } end
local st = {}
local nb, why = C.growth(st, base())
check(nb == nil and why == "pas saturee", "sans declencheur : rien")
local n = base(); n.nominal_kw = 150
nb, why = C.growth({}, n)
check(nb == 1, "demande nominale au-dela : une chaudiere, malgre une charge mesuree de 10 % (" .. tostring(nb) .. ", " .. tostring(why) .. ")")
n = base(); n.nominal_kw = 4000
nb = C.growth({}, n)
check(nb == 3, "taille a la demande manquante : 4000 / 1800 -> 3 chaudieres (" .. tostring(nb) .. ")")
n = base(); n.nominal_kw = 150; n.coal_short = true
nb, why = C.growth({}, n)
check(nb == nil and why == C.COAL_REASON, "chaudieres a sec : le charbon d'abord")
n = base(); n.nominal_kw = 150; n.pending = 1
nb = C.growth({}, n)
check(nb == 1, "un chantier ouvert ne retient pas quand la demande nominale manque encore apres lui")
n = base(); n.nominal_kw = 150; n.pending = C.MAX_PARALLEL
nb, why = C.growth({}, n)
check(nb == nil and why == "un chantier de centrale est ouvert", "au plus C.MAX_PARALLEL chantiers")
n = base(); n.nominal_kw = 150; n.done = C.MAX_PLANTS
nb, why = C.growth({}, n)
check(nb == nil and why == "plafond de centrales", "plafond de centrales garde")
n = base(); n.nominal_kw = 150; n.cool = true
nb = C.growth({}, n)
check(nb == nil, "pause apres refus gardee")

n = base(); n.nominal_kw = 150; n.refused = C.MAX_REFUSED
nb = C.growth({}, n)
check(nb == 1, "sous la demande nominale, jamais de renoncement apres C.MAX_REFUSED refus")
n = base(); n.refused = C.MAX_REFUSED; n.deficit_kw = 500
nb = C.growth({ def_n = C.DEFICIT_CHECKS }, n)
check(nb == nil, "hors demande nominale : le renoncement reste (charge mesuree 10 %)")
check(V.COOL_TICKS < C.COOL, "pause courte sous la demande nominale")

n = base(); n.nominal_kw = 5777; n.done = 0; n.pending = 1; n.rebuilding = 1
nb = C.growth({}, n)
check(nb ~= nil and nb >= 1, "centrale batie rouverte (piece manquante) : l'extension nominale part quand meme (azure, VAPEUR-4)")
n = base(); n.nominal_kw = 4485; n.done = 0; n.pending = 0; n.rebuilding = 0; n.built = 1
nb = C.growth({}, n)
check(nb ~= nil, "reconstruction figee (retiree des chantiers) mais chaudiere vivante : l'extension part (player, 123456789, 30,1 min)")
n = base(); n.nominal_kw = 5777; n.done = 0; n.pending = 1; n.rebuilding = 0
nb, why = C.growth({}, n)
check(nb == nil and why == "aucune centrale finie", "premiere centrale encore en chantier : on l'attend")

print("== 4. Liaison au charbon : refus et parallele")
local Cv = require("shared.team.champ_vapeur")
local Cc = require("shared.team.charbon_centrale")
check(Cv.after_refusal("foreuses : pas de lot", true) == "grandir", "pas de lot : le treillis grandit (partie du DC 0.7.103)")
check(Cv.after_refusal("foreuses : pas de lot", false) == "attendre", "treillis au maximum : on attend")
check(Cc.MAX_OPEN >= 2, "deux projets d'alimentation a la fois")
check(Cc.RETRY_TICKS <= 7200 and Cc.LONG_RETRY_TICKS <= 36000, "pauses courtes : 2 min puis 10 min")

print("== 5. Lots ecartes apres un tapis impossible")
local sk = V.mark_skip(nil, "3,4", 100)
local l = V.skip_lots({ { k = "1,1" }, { k = "3,4" }, { k = "5,5" } }, sk, 200)
check(#l == 2 and l[1].k == "1,1" and l[2].k == "5,5", "le lot ecarte sort de la liste, ordre garde")
l = V.skip_lots({ { k = "3,4" } }, sk, 100 + V.SKIP_TICKS)
check(#l == 1, "a l'echeance le lot revient")
check(#V.skip_lots({ { k = "a" } }, nil, 0) == 1, "sans ecart : liste inchangee")
local big = nil
for i = 1, V.SKIP_MAX + 5 do big = V.mark_skip(big, "L" .. i, i) end
local nk = 0
for _ in pairs(big) do nk = nk + 1 end
check(nk == V.SKIP_MAX and big["L1"] == nil and big["L" .. (V.SKIP_MAX + 5)] ~= nil, "au plus V.SKIP_MAX lots, les plus anciens sortent")
big = V.mark_skip(big, "Z", 10 * V.SKIP_TICKS)
nk = 0
for _ in pairs(big) do nk = nk + 1 end
check(nk == 1, "les echus sont purges")

print("== 6. Priorite de l'alimentation (cablage de build.lua)")
local fb = assert(io.open("script/team/build.lua", "rb"))
local bsrc = fb:read("*a")
fb:close()
local a0 = bsrc:find("function Build.alim_first(f, p, tick)", 1, true)
local a1 = a0 and bsrc:find("\nend\n", a0, true)
local body = a0 and a1 and bsrc:sub(a0, a1) or ""
check(body ~= "", "Build.alim_first existe")
check(not body:find("sp.site", 1, true), "les sites (bandes de champ, lignes, mall) ne sont pas exemptes : seuls projets neufs de player (banc VAPEUR-5)")
check(body:find("p.missing = {}", 1, true) ~= nil, "un projet retenu ne fait plus fabriquer ses manques")
check(bsrc:find("if Build.alim_first(f, p, tick) then return true end", 1, true) ~= nil, "branchee dans Build.reserve_suspended")

print("== 6 bis. C3-BOUCLE : la bande de l'entrepreneur n'est jamais retenue par l'alimentation (V.exempt)")
check(type(V.exempt) == "function", "V.exempt existe")
if type(V.exempt) == "function" then
  check(V.exempt({ champ = { pr = 18 }, site = true }, 0, false, true) == true, "bande entrepreneur (monopole), neuve : exemptee")
  check(V.exempt({ champ = { pr = -55 }, site = true }, 0, false, false) == false, "bande ordinaire neuve : retenue (banc VAPEUR-5 garde)")
  check(V.exempt({ champ = { pr = 2 } }, nil, false, nil) == false, "sans monopole lu : retenue")
  check(V.exempt({ alim = 24 }, 0, false, false) and V.exempt({}, 3, false, false) and V.exempt({}, 0, true, false), "alimentation, reconstruction, centrale : exemptees")
end
check(bsrc:find("Build.Vap.exempt(sp, p.reopened, plant, Ent.monopoly(sp))", 1, true) ~= nil, "alim_first lit le monopole de l'entrepreneur")

print("== 7. Matiere premiere disputee (gel cible)")
local REC = { belt = { "gear", "plate" }, gear = { "plate" }, plate = { "ore" }, furnace = { "stone" }, drill = { "gear", "circuit" },
  circuit = { "cable", "plate" }, cable = { "copper" }, loop = { "loop" } }
local function ings(it) return REC[it] end
local raws = V.raw_of("drill", ings, {})
check(raws.ore and raws.copper and not raws.gear, "matieres premieres d'une foreuse : minerai et cuivre")
check(next(V.raw_of("loop", ings, {})) == nil or true, "recette en boucle : pas de recursion infinie")
local hit, r = V.competes({ belt = 10 }, { { "drill", 2 } }, ings, {})
check(hit and r == "ore", "un projet de tapis dispute le minerai de fer d'une alimentation qui manque de foreuses")
hit = V.competes({ furnace = 4 }, { { "drill", 2 } }, ings, {})
check(not hit, "un projet de fours en pierre passe")
hit = V.competes({ belt = 10 }, { { "drill", 0 } }, ings, {})
check(not hit, "rien ne manque a l'alimentation : rien n'est retenu")
check(V.FIRST_TICKS <= 18000, "gel borne a 5 min")

print(string.format("\nResultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
