--[[
  Lot TITANS (9/11) : banc hors jeu des titans (shared/robots/titans.lua). Lua 5.2, depuis la racine du mod :
      lua5.2 tests/titans_test.lua
    §1 règle pure : paliers et ères lus dans shared/levels/config.lua et shared/robots/echelle.lua (bornes, monotonie) ; alliés (Juggernaut,
       Sentinelle, Léviathan) : PV = E2 de l'âge nominal, plaques qui montent, masse qui ralentit, armes cumulatives propres à chacun, noms
       de palier reconnus, drones du Léviathan (2 puis 3), singularité qui ralentit ; Kaiju : PV × hp_mult, échelle, arme par
       ère, lueur = couleur de l'ère ; vagues : premier Kaiju à la vague 20, un de plus toutes les 20 ; courbes des nids croissantes ;
    §2 DONNÉES CHANGÉES : la même règle sur une config à 18 époques et 2 époques par ère donne 9 ères et 9 paliers (rien en dur) ;
    §3 feuilles (D-6) : sprites.lua, chaque PNG présent, dimensions de l'en-tête PNG = sprites.lua, aucune feuille du Kaiju au-delà de
       2 048 px ; MANIFEST.json cite chaque fichier ;
    §4 traductions : chaque clé citée par les prototypes et le script existe en FR et EN, mêmes clés des deux côtés ;
    §5 forme : aucun pairs dans shared/robots/titans.lua, aucun require dans une fonction, `global` jamais nommé ; noms fo-titan- du
       script déclarés par un prototype ; aucune couleur translucide littérale (prémultiplication, gi1) ;
    §6 vagues : TD.compose sans âge inchangé (aucun Kaiju), avec âge : Kaiju de l'ère de l'âge, déterministe ;
    §7 mutants : chaque règle a un mutant, tous refusés.
    KAIJUS-MUTANTS (10/11) : §1 Ravageur (4e allié, animé : SERIE et FOULEE de ravageur.py, mitraille puis lames), Écorcheur (2e Kaiju : era_min,
       tir, PONTE : nombre et variantes), Écorchés (trois variantes : PV, vitesse, plaques, noms reconnus, courbes des nids), rotation des
       archétypes (T.kaiju_pour) ; §3 feuilles de l'Écorcheur, des Écorchés (variantes) et du Ravageur ; §6 vagues à deux archétypes ;
       §7 douze mutants de plus.
]]

package.path = "./?.lua;" .. package.path

local L = require("shared.levels.config")
local Ech = require("shared.robots.echelle")
local T = require("shared.robots.titans")
local TD = require("shared.td.waves")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[TITANS] ECHEC : " .. msg) end
end

local function read(p)
  local f = assert(io.open(p, "rb"), "lecture impossible : " .. p)
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/robots/titans.lua")

---------------------------------------------------------------------------------------------------
-- §1 règle pure
---------------------------------------------------------------------------------------------------
check(T.AGE_MIN == Ech.AGE_ZONE_MIN and T.AGE_MAX == L.EPOCHS, "§1 âges du Juggernaut : du premier âge des géants au dernier âge du jeu")
check(T.PALIERS == L.EPOCHS - Ech.AGE_ZONE_MIN + 1, "§1 un palier par âge")
check(T.ERAS == math.ceil(L.EPOCHS / L.ERA_EPOCHS), "§1 une ère par L.ERA_EPOCHS époques")
check(T.palier(1) == 1 and T.palier(T.AGE_MIN) == 1 and T.palier(T.AGE_MAX) == T.PALIERS and T.palier(T.AGE_MAX + 5) == T.PALIERS, "§1 palier borné")
local mono = true
for a = 1, L.EPOCHS - 1 do
  if T.palier(a + 1) < T.palier(a) or T.era(a + 1) < T.era(a) then mono = false end
  if T.era(a) ~= math.floor((a - 1) / L.ERA_EPOCHS) + 1 then mono = false end
end
check(mono, "§1 palier et ère croissants avec l'âge, ère = ⌈âge / L.ERA_EPOCHS⌉")
check(T.stage(1) == 1 and T.stage(T.PALIERS) == T.STAGES and T.stage(3) == 2, "§1 stades d'images : 1-2, 3-4, 5-6")
for e = 1, T.ERAS do
  local c, ref = T.era_color(e), L.epochs[math.min(L.EPOCHS, e * L.ERA_EPOCHS)].color
  check(c.r == ref.r and c.g == ref.g and c.b == ref.b, "§1 couleur de l'ère " .. e .. " = couleur de son dernier âge (config)")
end
-- Juggernaut
local prev
for a = T.AGE_MIN, T.AGE_MAX do
  local j = T.juggernaut(a)
  check(j.hp == Ech.pv(a), "§1 Juggernaut âge " .. a .. " : PV = règle d'échelle E2")
  check(j.salve == Ech.salve(a, T.JUGGERNAUT.dtype) and j.zone == Ech.rayon(a) and j.cratere == Ech.cratere(a), "§1 Juggernaut âge " .. a .. " : salve, zone, cratère des géants")
  check(j.name == T.juggernaut_name(j.palier) and T.juggernaut_palier(j.name) == j.palier, "§1 Juggernaut âge " .. a .. " : nom du palier")
  local base = Ech.resistances(a)
  local ok = #j.resistances == #base
  for i, r in ipairs(j.resistances) do
    if r.type ~= base[i].type or r.decrease ~= base[i].decrease or r.percent ~= math.min(T.PLAQUE_MAX, base[i].percent + T.PLAQUE_PCT * (j.palier - 1)) then ok = false end
  end
  check(ok, "§1 Juggernaut âge " .. a .. " : plaques = E1 + " .. T.PLAQUE_PCT .. " % par palier")
  if prev then
    check(j.hp > prev.hp and j.speed < prev.speed and #j.liste_armes >= #prev.liste_armes, "§1 Juggernaut âge " .. a .. " : plus de PV, plus lent, pas moins d'armes")
  end
  prev = j
end
local a1, a6 = T.juggernaut(T.AGE_MIN), T.juggernaut(T.AGE_MAX)
check(a1.armes.griffes and not a1.armes.canon and not a1.armes.salve, "§1 palier 1 : les griffes seulement")
check(a6.armes.griffes and a6.armes.canon and a6.armes.salve and a6.armes.resonance, "§1 dernier palier : toutes les armes")
check(a6.cooldown * 2 <= a1.cooldown, "§1 résonance : cadence doublée")
check(T.juggernaut_palier("fo-titan-juggernaut-0") == nil and T.juggernaut_palier("fo-titan-juggernaut-x") == nil and T.juggernaut_palier("fo-xp-cairn") == nil, "§1 noms étrangers refusés")
-- les trois alliés : même règle d'échelle, armes propres, noms de palier
check(#T.ALLIES == 4 and T.ALLIES[1] == T.JUGGERNAUT and T.ALLIES[2] == T.SENTINELLE and T.ALLIES[3] == T.LEVIATHAN and T.ALLIES[4] == T.RAVAGEUR, "§1 quatre archétypes alliés, Juggernaut en tête, Ravageur en queue")
for _, r in ipairs(T.ALLIES) do
  check(T.allie_of_id(r.id) == r and r.name == T.PREFIX .. r.id and r.tech == r.name and r.ingredients[1][1] == r.segment_item and r.ingredients[1][2] == T.SEGMENTS, "§1 " .. r.id .. " : noms, technologie, 10 segments")
  local prev2
  for a = T.AGE_MIN, T.AGE_MAX do
    local j = T.allie(r, a)
    check(j.hp == Ech.pv(a) and j.salve == Ech.salve(a, r.dtype) and j.stage == T.stage(j.palier), "§1 " .. r.id .. " âge " .. a .. " : PV E2, salve E3, stade")
    local rr, p = T.allie_palier(j.name)
    check(rr == r and p == j.palier, "§1 " .. r.id .. " âge " .. a .. " : nom du palier reconnu")
    check(j.bouche and #j.bouche == 2, "§1 " .. r.id .. " âge " .. a .. " : bouche du canon donnée par la règle")
    if prev2 then check(j.hp > prev2.hp and j.speed < prev2.speed and #j.liste_armes >= #prev2.liste_armes, "§1 " .. r.id .. " âge " .. a .. " : plus de PV, plus lent, pas moins d'armes") end
    prev2 = j
  end
  local j1, j6 = T.allie(r, T.AGE_MIN), T.allie(r, T.AGE_MAX)
  check(#j1.liste_armes == 1 and j1.liste_armes[1] == r.armes[1].id and r.armes[1].palier == 1, "§1 " .. r.id .. " : une seule arme au palier 1, la sienne")
  check((j6.armes.canon or j6.armes.mitraille) and j6.armes.salve and j6.armes.resonance and j6.cooldown * 2 <= j1.cooldown, "§1 " .. r.id .. " : canon (ou mitraille), salve et résonance au dernier palier")
  check(T.allie_palier(r.name .. "-0") == nil and T.allie_palier(r.name .. "-7") == nil and T.allie_palier(r.name) == nil, "§1 " .. r.id .. " : paliers hors bornes refusés")
end
check(T.allie(T.SENTINELLE, T.AGE_MIN).armes.singularite and not T.allie(T.SENTINELLE, T.AGE_MIN).armes.canon, "§1 Sentinelle : la singularité d'abord, le canon au palier 2")
check(T.SENTINELLE.singularite.slow < 1 and T.SENTINELLE.singularite.slow > 0 and T.SENTINELLE.singularite.slow_ticks > 0, "§1 Sentinelle : la singularité ralentit (0 < slow < 1)")
check(T.allie(T.LEVIATHAN, T.AGE_MIN).armes.drones and not T.allie(T.LEVIATHAN, T.AGE_MIN).armes.canon and T.allie(T.LEVIATHAN, T.AGE_MIN + 2).armes.canon, "§1 Léviathan : les drones d'abord, le canon au palier 3")
check(T.drones(1) == 2 and T.drones(3) == 2 and T.drones(4) == 3 and T.drones(T.PALIERS) == 3, "§1 Léviathan : 2 drones, 3 dès le palier 4")
check(T.allie(T.LEVIATHAN, T.AGE_MIN).n_drones == 2 and T.allie(T.LEVIATHAN, T.AGE_MAX).n_drones == 3 and T.juggernaut(T.AGE_MIN).n_drones == nil, "§1 drones : seul le Léviathan en a")
check(T.JUGGERNAUT.age < T.SENTINELLE.age and T.SENTINELLE.age < T.LEVIATHAN.age and T.LEVIATHAN.age < T.RAVAGEUR.age and T.RAVAGEUR.age <= T.AGE_MAX, "§1 âges des quatre alliés croissants")
-- FINITIONS (10/11) : Juggernaut animé (8 directions × images), règles pures de l'animation
local JU = read("tools/render/pieces/titans/juggernaut.py")
local function py_num(expr)
  local f = load("return " .. expr:gsub("%s+$", ""), "=py", "t", {})
  return f and f()
end
local SERIE = {}
for k, v in JU:match("\nSERIE = {(.-)}"):gmatch('"(%a+)":%s*([%d%.]+)') do SERIE[k] = tonumber(v) end
local FOULEE = py_num(JU:match("\nFOULEE = ([^#\n]+)"))
check(type(T.JUGGERNAUT.anime) == "table" and T.JUGGERNAUT.anime.images.course == SERIE.course and T.JUGGERNAUT.anime.images.attaque == SERIE.attaque,
  "§1 Juggernaut animé : images de course et d'attaque = SERIE du modèle (juggernaut.py)")
check(FOULEE and math.abs(T.JUGGERNAUT.anime.foulee - FOULEE) < 1e-6, "§1 Juggernaut animé : foulée de la règle = FOULEE du modèle (" .. tostring(FOULEE) .. ")")
check(T.JUGGERNAUT.anime.attaque_ticks > 0 and T.JUGGERNAUT.anime.attaque_ticks % 1 == 0, "§1 Juggernaut animé : durée de salve entière, positive")
-- TITANS-8DIR (10/11) : la Sentinelle et le Léviathan sont animés à leur tour (SERIE et FOULEE de sentinelle.py / leviathan.py)
local SE_PY, LE_PY = read("tools/render/pieces/titans/sentinelle.py"), read("tools/render/pieces/titans/leviathan.py")
local SERIE_SE, SERIE_LE = {}, {}
for k, v in SE_PY:match("\nSERIE = {(.-)}"):gmatch('"(%a+)":%s*([%d%.]+)') do SERIE_SE[k] = tonumber(v) end
for k, v in LE_PY:match("\nSERIE = {(.-)}"):gmatch('"(%a+)":%s*([%d%.]+)') do SERIE_LE[k] = tonumber(v) end
local FOULEE_SE, FOULEE_LE = py_num(SE_PY:match("\nFOULEE = ([^#\n]+)")), py_num(LE_PY:match("\nFOULEE = ([^#\n]+)"))
for _, c in ipairs({ { T.SENTINELLE, SERIE_SE, FOULEE_SE, "Sentinelle" }, { T.LEVIATHAN, SERIE_LE, FOULEE_LE, "Léviathan" } }) do
  local r, se, fo, nom = c[1], c[2], c[3], c[4]
  check(type(r.anime) == "table" and r.anime.images.course == se.course and r.anime.images.attaque == se.attaque,
    "§1 " .. nom .. " animé(e) : images de marche et de salve = SERIE du modèle")
  check(fo and math.abs(r.anime.foulee - fo) < 1e-6, "§1 " .. nom .. " animé(e) : foulée de la règle = FOULEE du modèle (" .. tostring(fo) .. ")")
  check(r.anime.attaque_ticks > 0 and r.anime.attaque_ticks % 1 == 0, "§1 " .. nom .. " animé(e) : durée de salve entière, positive")
  -- LEVIATHAN2 (11/11) : le DC lève le plafond du Léviathan (détail jugé pauvre) : 22 px par unité, borne 24 (feuilles : 32 Mpx HR en
  -- 0.6.94 à 15 px, environ 70 attendus quand tête, segments et queue seront tous rendus à 22 px)
  local dmax = (nom == "Léviathan") and 24 or 16
  check(se.densite and se.R and se.zmax and se.densite <= dmax, "§1 " .. nom .. " : série à densité bornée (≤ " .. dmax .. " px par unité)")
end
for _, r in ipairs(T.ALLIES) do check(r.anime ~= nil, "§1 " .. r.id .. " : corps animé (les quatre alliés)") end
local SCR = read("script/robots/titans.lua")
check(SCR:find("j.singularite.cooldown\n          if not j.armes.canon then anim_attaque(g, r, ev.tick) end", 1, true) ~= nil,
  "§1 script : au palier 1 de la Sentinelle, la singularité joue la salve à l'écran")
check(SCR:match("local function drones_tirer.-anim_attaque%(g, archetype%(g%), tick%)") ~= nil, "§1 script : la salve de drones du Léviathan joue la salve à l'écran")
-- KAIJUS-MUTANTS : le Ravageur est animé comme le Juggernaut (SERIE et FOULEE de ravageur.py)
local RA = read("tools/render/pieces/titans/ravageur.py")
local SERIE_RA = {}
for k, v in RA:match("\nSERIE = {(.-)}"):gmatch('"(%a+)":%s*([%d%.]+)') do SERIE_RA[k] = tonumber(v) end
local FOULEE_RA = py_num(RA:match("\nFOULEE = ([^#\n]+)"))
check(type(T.RAVAGEUR.anime) == "table" and T.RAVAGEUR.anime.images.course == SERIE_RA.course and T.RAVAGEUR.anime.images.attaque == SERIE_RA.attaque,
  "§1 Ravageur animé : images = SERIE du modèle (ravageur.py)")
check(FOULEE_RA and math.abs(T.RAVAGEUR.anime.foulee - FOULEE_RA) < 1e-3, "§1 Ravageur animé : foulée de la règle = FOULEE du modèle (" .. tostring(FOULEE_RA) .. ")")
-- ART-16DIR (11/11, mandat du DC : « 16 directions d'orientation réelles ») : Juggernaut, Sentinelle et Ravageur en 16 directions, le Léviathan
-- en 8 ; la règle (r.anime.directions) = SERIE["dirs"] du modèle = directions des feuilles (§3) ; T.direction au secteur le plus proche
for _, x in ipairs({ { T.JUGGERNAUT, SERIE }, { T.SENTINELLE, SERIE_SE }, { T.RAVAGEUR, SERIE_RA }, { T.LEVIATHAN, SERIE_LE } }) do
  check(x[1].anime.directions == (x[2].dirs or 8), "§1 " .. x[1].id .. " : directions de la règle = SERIE du modèle (" .. tostring(x[2].dirs or 8) .. ")")
end
check(T.JUGGERNAUT.anime.directions == 16 and T.SENTINELLE.anime.directions == 16 and T.RAVAGEUR.anime.directions == 16,
  "§1 ART-16DIR : Juggernaut, Sentinelle et Ravageur en 16 directions (demande du DC)")
check(T.direction(0, 16) == 0 and T.direction(0.0625, 16) == 1 and T.direction(0.5, 16) == 8 and T.direction(0.97, 16) == 0 and T.direction(0.94, 16) == 15
  and T.direction(0.03, 16) == 0 and T.direction(nil, 16) == 0, "§1 direction à 16 secteurs : secteur le plus proche, 1 revient à 0")
local r1, r2, r6 = T.allie(T.RAVAGEUR, T.AGE_MIN), T.allie(T.RAVAGEUR, T.AGE_MIN + 1), T.allie(T.RAVAGEUR, T.AGE_MAX)
check(r1.armes.mitraille and not r1.armes.lames and r2.armes.lames and not r1.armes.canon and r6.armes.salve, "§1 Ravageur : mitraille d'abord, lames au palier 2, jamais de canon annulaire, salve plus tard")
check(r1.mitraille and r1.mitraille.n > 1 and r1.mitraille.part > 0 and r1.mitraille.part <= 1 and r1.lames and r1.lames.radius > 0, "§1 Ravageur : rafale de plusieurs projectiles, part de salve bornée, lames à rayon")
check(T.RAVAGEUR.speed < T.JUGGERNAUT.speed and T.allie(T.RAVAGEUR, T.AGE_MIN).cooldown < T.allie(T.JUGGERNAUT, T.AGE_MIN).cooldown, "§1 Ravageur : plus lent que le Juggernaut, cadence plus courte")
check(T.direction8(0) == 0 and T.direction8(0.25) == 2 and T.direction8(0.5) == 4 and T.direction8(0.75) == 6, "§1 direction8 : nord, est, sud, ouest")
check(T.direction8(0.07) == 1 and T.direction8(0.06) == 0 and T.direction8(0.99) == 0 and T.direction8(0.93) == 7 and T.direction8(nil) == 0, "§1 direction8 : secteur le plus proche, 1 revient à 0")
check(T.vitesse_anim(0, 6.9, 8) == 0 and T.vitesse_anim(nil, 6.9, 8) == 0 and T.vitesse_anim(0.12, 0, 8) == 0, "§1 vitesse_anim : 0 à l'arrêt ou sans foulée")
check(math.abs(T.vitesse_anim(0.12, 6.9, 8) - 0.12 * 8 / 6.9) < 1e-12 and T.vitesse_anim(-0.12, 6.9, 8) == T.vitesse_anim(0.12, 6.9, 8), "§1 vitesse_anim : vitesse × images / foulée, marche arrière comprise")
check(T.anim_name(T.JUGGERNAUT, 2, "course", 3, "corps") == "fo-titan-juggernaut-2-course-3-corps", "§1 anim_name : préfixe, archétype, stade, animation, direction, couche")
check(#T.COUCHES_ANIM == 3 and T.COUCHES_ANIM[1][1] == "ombre" and T.COUCHES_ANIM[2][1] == "corps" and T.COUCHES_ANIM[3][1] == "lueur", "§1 trois couches animées, l'ombre dessous")
-- Kaiju
prev = nil
for e = 1, T.ERAS do
  local k = T.kaiju(e)
  local age = math.min(L.EPOCHS, e * L.ERA_EPOCHS)
  check(k.age == age and k.hp == Ech.pv(age) * T.KAIJU.hp_mult, "§1 Kaiju ère " .. e .. " : PV = hp_mult × E2 du dernier âge de l'ère")
  check(k.name == T.kaiju_name(e) and T.kaiju_era_of_name(k.name) == e, "§1 Kaiju ère " .. e .. " : nom")
  check(k.tint.r == T.era_color(e).r and k.glow > 0 and k.glow <= 1, "§1 Kaiju ère " .. e .. " : lueur de la couleur de l'ère")
  check(k.morsure == Ech.dechiqueteur(Ech.palier(age)).morsure * T.KAIJU.morsure_mult, "§1 Kaiju ère " .. e .. " : morsure = multiple du déchiqueteur du palier")
  if prev then check(k.hp > prev.hp and k.scale > prev.scale and k.speed < prev.speed and k.glow > prev.glow, "§1 Kaiju ère " .. e .. " : plus lourd, plus lent, plus lumineux") end
  local c = T.kaiju_curve(e)
  check(c[1][1] < c[2][1] and c[2][1] <= c[3][1] and c[1][2] == 0 and c[3][2] > 0, "§1 Kaiju ère " .. e .. " : courbe des nids croissante")
  if prev then check(c[1][1] > T.kaiju_curve(e - 1)[1][1], "§1 Kaiju ère " .. e .. " : plus tard dans l'évolution que l'ère d'avant") end
  prev = k
end
check(T.kaiju(1).arme == "morsure" and T.kaiju(2).arme == "griffes" and T.kaiju(3).arme == "impulsion" and T.kaiju(T.ERAS).arme == "impulsion", "§1 Kaiju : morsure, griffes, impulsion")
-- KAIJUS-MUTANTS : archétypes de Kaiju, rotation par les données, Écorcheur, ponte, Écorchés
check(#T.KAIJUS == 2 and T.KAIJUS[1] == T.KAIJU and T.KAIJUS[2] == T.ECORCHEUR and T.KAIJU.era_min == 1 and T.ECORCHEUR.era_min > 1, "§1 deux archétypes de Kaiju, le cristallin d'abord et dès l'ère 1, l'Écorcheur plus tard")
check(T.kaiju_pour(1, 1) == T.KAIJU and T.kaiju_pour(1, 2) == T.KAIJU and T.kaiju_pour(T.ECORCHEUR.era_min, 1) == T.KAIJU and T.kaiju_pour(T.ECORCHEUR.era_min, 2) == T.ECORCHEUR
  and T.kaiju_pour(T.ERAS, 3) == T.KAIJU and T.kaiju_pour(T.ERAS, nil) == T.KAIJU, "§1 rotation : seul le cristallin avant l'ère de l'Écorcheur, puis alternance par le numéro")
check(#T.kaijus_ouverts(1) == 1 and #T.kaijus_ouverts(T.ERAS) == 2, "§1 archétypes ouverts par l'ère (era_min)")
for e = 1, T.ERAS do
  local ok = true
  for _, kk in ipairs(T.KAIJUS) do
    local j = T.kaiju(e, kk)
    local k2, e2 = T.kaiju_of_name(j.name)
    if k2 ~= kk or e2 ~= e or T.kaiju_era_of_name(j.name) ~= e or j.name ~= T.kaiju_name(e, kk) then ok = false end
  end
  check(ok, "§1 ère " .. e .. " : noms des deux archétypes reconnus (archétype et ère)")
  local ec = T.kaiju(e, T.ECORCHEUR)
  check(ec.hp < T.kaiju(e).hp and ec.speed > T.kaiju(e).speed, "§1 ère " .. e .. " : l'Écorcheur est plus léger et plus vif que le cristallin")
end
check(T.kaiju(1, T.ECORCHEUR).arme == "morsure" and T.kaiju(2, T.ECORCHEUR).arme == "tir" and T.kaiju(3, T.ECORCHEUR).arme == "ponte" and T.kaiju(T.ERAS, T.ECORCHEUR).armes.tir,
  "§1 Écorcheur : morsure, tir (ère 2), ponte (ère 3), le tir reste")
check(T.kaiju(2, T.ECORCHEUR).ponte == nil and type(T.kaiju(3, T.ECORCHEUR).ponte) == "table", "§1 Écorcheur : la ponte n'existe qu'à partir de son ère")
local function total(l) local n = 0; for _, it in ipairs(l) do n = n + it[2] end; return n end
check(total(T.ponte(3)) == T.ECORCHEUR.ponte.base and total(T.ponte(4)) == T.ECORCHEUR.ponte.base + T.ECORCHEUR.ponte.plus_era and total(T.ponte(T.ERAS)) > total(T.ponte(3)),
  "§1 ponte : base à son ère, plus_era de plus par ère")
check(#T.ponte(3) == math.min(T.ECORCHEUR.ponte.base, #T.ECORCHE.variants) and #T.ponte(5) == #T.ECORCHE.variants and T.ecorche_of_name(T.ponte(3)[1][1]) ~= nil,
  "§1 ponte : les variantes tournent (noms d'Écorchés reconnus), une entrée par nom")
check(#T.ECORCHE.variants == 3 and T.ECORCHE.era_min >= 1 and T.ECORCHE.era_min <= T.ERAS, "§1 trois variantes d'Écorchés, ère d'ouverture bornée")
do
  local ro, po, hu = T.ECORCHE.variants[1], T.ECORCHE.variants[2], T.ECORCHE.variants[3]
  for e = T.ECORCHE.era_min, T.ERAS do
    local a, b, c = T.ecorche(ro, e), T.ecorche(po, e), T.ecorche(hu, e)
    local d = Ech.dechiqueteur(Ech.palier(T.age_of_era(e)))
    check(a.hp == d.pv * T.ECORCHE.hp_mult * ro.hp and b.hp > a.hp and a.speed > b.speed and b.resistances[1].percent > a.resistances[1].percent,
      "§1 Écorchés ère " .. e .. " : PV = déchiqueteur × multiplicateurs ; le porteur plus lourd et plus blindé, le rôdeur plus vif")
    check(c.cri_radius and c.cri_radius > 0 and a.cri_radius == nil and c.morsure > a.morsure, "§1 Écorchés ère " .. e .. " : seul le hurleur crie (zone), et mord plus fort")
    local ok = true
    for _, v in ipairs(T.ECORCHE.variants) do
      local m = T.ecorche(v, e)
      local v2, e2 = T.ecorche_of_name(m.name)
      local tv = T.ecorche_tint(v, e)   -- VISUELS-DISTINCTS : couleur de la variante mêlée à celle de l'ère
      if v2 ~= v or e2 ~= e or m.tint.r ~= tv.r or m.tint.g ~= tv.g or m.tint.b ~= tv.b then ok = false end
      local cv = T.ecorche_curve(v, e)
      if not (cv[1][1] < cv[2][1] and cv[1][2] == 0 and cv[3][2] > 0) then ok = false end
      if e > T.ECORCHE.era_min and not (cv[1][1] > T.ecorche_curve(v, e - 1)[1][1]) then ok = false end
    end
    check(ok, "§1 Écorchés ère " .. e .. " : noms reconnus, lueur de la variante mêlée à l'ère, courbes des nids croissantes avec l'ère")
  end
  check(T.ecorche_curve(po, 3)[1][1] > T.ecorche_curve(ro, 3)[1][1] and T.ecorche_curve(ro, 3)[1][1] < T.kaiju_curve(1)[1][1], "§1 nids : le porteur après le rôdeur, les Écorchés avant tout Kaiju")
  check(T.ecorche_of_name("fo-titan-ecorche-rodeur-0") == nil and T.ecorche_of_name("fo-titan-ecorche-x-2") == nil and T.ecorche_of_name("fo-titan-kaiju-2") == nil, "§1 Écorchés : noms étrangers refusés")
  check(T.kaiju_curve(2, T.ECORCHEUR)[1][1] > T.kaiju_curve(2, T.KAIJU)[1][1], "§1 nids : l'Écorcheur après le cristallin de la même ère")
end
-- règle du MOTEUR : les évolutions d'une courbe de nid sont STRICTEMENT croissantes, dans [0, 1], la dernière vaut 1 (sinon « Wrong
-- SpawnPoints definition » au chargement : banc content KAIJUS du 10/11) ; toutes les courbes de ce fichier, toutes les ères
local function courbe_ok(c)
  if #c < 2 or c[#c][1] ~= 1.0 then return false end
  for i, pt in ipairs(c) do
    if pt[1] < 0 or pt[1] > 1 or pt[2] < 0 or (i > 1 and not (pt[1] > c[i - 1][1])) then return false end
  end
  return true
end
do
  local bad = {}
  for _, kk in ipairs(T.KAIJUS) do
    for e = 1, T.ERAS do if not courbe_ok(T.kaiju_curve(e, kk)) then bad[#bad + 1] = kk.id .. "-" .. e end end
  end
  for _, v in ipairs(T.ECORCHE.variants) do
    for e = T.ECORCHE.era_min, T.ERAS do if not courbe_ok(T.ecorche_curve(v, e)) then bad[#bad + 1] = v.id .. "-" .. e end end
  end
  check(#bad == 0, "§1 nids : toutes les courbes strictement croissantes, finies à 1 (" .. table.concat(bad, " ") .. ")")
end
check(T.kaiju_in_wave(19, 5) == 0 and T.kaiju_in_wave(21, 5) == 0 and T.kaiju_in_wave(20, 5) == 1 and T.kaiju_in_wave(35, 5) == 1 and T.kaiju_in_wave(40, 5) == 2 and T.kaiju_in_wave(60, 5) == 3,
  "§1 vagues : premier Kaiju à la vague 20 (vague de boss), un de plus toutes les 20")

---------------------------------------------------------------------------------------------------
-- §2 données changées : la même règle sur une autre config
---------------------------------------------------------------------------------------------------
local function charger(src, config)
  local env = setmetatable({}, { __index = _G })
  local vrai_require = require
  env.require = function(n)
    if n == "shared.levels.config" and config then return config end
    return vrai_require(n)
  end
  local chunk = assert(load(src, "=titans", "t", env))
  return chunk()
end
do
  local faux = { EPOCHS = 18, ERA_EPOCHS = 2, epochs = {} }
  for i = 1, 18 do faux.epochs[i] = { key = "e" .. i, color = { r = i / 18, g = 0.5, b = 1 - i / 18 } } end
  local T2 = charger(SRC, faux)
  check(T2.ERAS == 9 and T2.PALIERS == 9 and T2.AGE_MAX == 18, "§2 config à 18 époques, 2 par ère : 9 ères, 9 paliers")
  check(T2.era(5) == 3 and T2.era(18) == 9 and T2.era_color(2).r == 4 / 18, "§2 ères et couleurs relues dans la config changée")
  check(T2.juggernaut(18).palier == 9 and T2.kaiju(9).age == 18, "§2 dernier palier et dernière ère suivent la config")
  check(T2.kaiju(9, T2.ECORCHEUR).age == 18 and T2.kaiju_pour(9, 2) == T2.ECORCHEUR and #T2.ponte(9) == #T2.ECORCHE.variants and T2.ecorche(T2.ECORCHE.variants[1], 9).age == 18,
    "§2 Écorcheur, rotation, ponte et Écorchés suivent la config changée")
end

---------------------------------------------------------------------------------------------------
-- §3 feuilles (D-6)
---------------------------------------------------------------------------------------------------
local function png_size(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local h = f:read(24)
  f:close()
  if not h or #h < 24 or h:sub(1, 8) ~= "\137PNG\r\n\26\n" then return nil end
  local function u32(s, i) local a, b, c, d = s:byte(i, i + 3); return ((a * 256 + b) * 256 + c) * 256 + d end
  return u32(h, 17), u32(h, 21)
end
local SPR_PATH = "graphics/robots/titans/sprites.lua"
local okspr, SPR = pcall(dofile, SPR_PATH)
check(okspr and type(SPR) == "table", "§3 sprites.lua lisible (sinon : py -3.9 tools/render/pieces/titans/feuilles_titans.py)")
local MAN = {}
if okspr then
  local okm, txt = pcall(read, "graphics/robots/titans/MANIFEST.json")
  if okm then for n in txt:gmatch('"([%w%-_%.]+%.png)"') do MAN[n] = true end end
  -- ART-TITANS2 (11/11, F536) : budget porté à 85 Mpx (le DC lève les plafonds de texture ; Juggernaut re-modelé : 82,1 Mpx).
  -- ART-16DIR (11/11) : budget de mémoire vidéo de chaque allié animé, 80 Mpx de feuilles HR (poids_mpx du MANIFEST : aire utile des images,
  -- lueur et ombre à leur densité) ; 16 directions ne passent qu'avec la densité réduite et la lueur à demi-densité, l'ombre au quart
  local function hors_budget(t)
    local l = {}
    for nom, h in (t or ""):gmatch('"(%a+)": {%s*"haute": ([%d%.]+)') do
      for _, r in ipairs(T.ALLIES) do
        if r.id == nom and r.anime and tonumber(h) > 85 then l[#l + 1] = nom .. " " .. h end
      end
    end
    return l
  end
  local hb = hors_budget(okm and txt)
  check(okm and txt:find('"poids_mpx"', 1, true) ~= nil and #hb == 0, "§3 budget : chaque allié animé ≤ 85 Mpx HR (" .. table.concat(hb, ", ") .. ")")
  check(#hors_budget([["poids_mpx": {
  "sentinelle": {
   "haute": 90.27,]]) == 1, "§3 mutant refusé : Sentinelle à 90,27 Mpx (avant ART-16DIR)")
  local function fichier(name) return (name:gsub("^__factorio%-overhaul__/", "")) end
  local function verifie(what, d, w, h)
    local p = fichier(d)
    local pw, ph = png_size(p)
    check(pw == w and ph == h, "§3 " .. what .. " : PNG présent, " .. tostring(pw) .. " × " .. tostring(ph) .. " = sprites.lua (" .. w .. " × " .. h .. ")")
    check(MAN[p:match("([^/]+)$")] == true, "§3 MANIFEST cite " .. p:match("([^/]+)$"))
  end
  for _, r in ipairs(T.ALLIES) do
    local cles = {}
    for st = 1, T.STAGES do cles[#cles + 1] = tostring(st) end
    if r.drones then cles[#cles + 1] = "drone" end
    local A = SPR[r.id]
    if r.segmente then
      cles = r.drones and { "drone" } or {}   -- LEVIATHAN-SEG : la tête et les pièces ont leurs propres feuilles (bloc « articulé » ci-dessous)
    else
      check((A and A.anime == true) == (r.anime ~= nil), "§3 " .. r.id .. " : feuilles animées si et seulement si la règle dit `anime`")
    end
    for _, st in ipairs(cles) do
      local e = A and A[st]
      check(e ~= nil, "§3 " .. r.id .. " : feuille du stade " .. st)
      if e and e.course then
        -- FINITIONS : stade animé (directions × images, un fichier par direction et par couche, densité propre à chaque couche) ;
        -- ART-16DIR : directions des feuilles = directions de la règle (16 pour Juggernaut, Sentinelle, Ravageur)
        check(A.directions == (r.anime.directions or 8) and e.course.images == r.anime.images.course and e.attaque.images == r.anime.images.attaque and math.abs(A.foulee - r.anime.foulee) < 1e-6,
          "§3 " .. r.id .. " " .. st .. " : " .. tostring(A.directions) .. " directions (règle " .. tostring(r.anime.directions) .. "), images et foulée = règle")
        for _, anim in ipairs({ "course", "attaque" }) do
          local a = e[anim]
          for _, nomc in ipairs({ "main", "glow", "shadow" }) do
            local c = a.couches[nomc]
            check(#c.hr == A.directions and #c.lr == A.directions and c.ll * c.lpf == a.images and c.dens > 0 and c.dens <= a.densite, "§3 " .. r.id .. " " .. st .. " " .. anim .. " " .. nomc .. " : un fichier par direction, grille exacte, densité")
            check(c.w * c.ll <= 4096 and c.h * c.lpf <= 4096, "§3 " .. r.id .. " " .. st .. " " .. anim .. " " .. nomc .. " : feuille ≤ 4 096 px")
            for k = 1, A.directions do
              verifie(r.id .. " " .. st .. " " .. anim .. " " .. nomc .. " " .. k, c.hr[k], c.w * c.ll, c.h * c.lpf)
              verifie(r.id .. " " .. st .. " " .. anim .. " " .. nomc .. " " .. k, c.lr[k], c.lw * c.ll, c.lh * c.lpf)
            end
          end
        end
        check(e.icone and e.icone.size == 64, "§3 " .. r.id .. " " .. st .. " : icône")
      elseif e then
        for _, c in ipairs({ e.main, e.ombre, e.lueurs[1] }) do
          verifie(r.id .. " " .. st, c.hr.filename, c.hr.width, c.hr.height)
          verifie(r.id .. " " .. st, c.lr.filename, c.lr.width, c.lr.height)
        end
        check(#e.lueurs >= 1 and e.icone and e.icone.size == 64, "§3 " .. r.id .. " " .. st .. " : lueur fondue et icône")
      end
    end
  end
  -- LEVIATHAN-SEG (11/11) : titan ARTICULÉ : tête animée (n directions, images = règle), pièces fixes (segment, queue : une image par
  -- direction et par couche), icône du titan entier ; feuilles dans graphics/robots/titans/<archétype>/ (sprites.lua, MANIFEST.json)
  for _, r in ipairs(T.ALLIES) do
    if r.segmente then
      local base = "graphics/robots/titans/" .. r.id .. "/"
      local okg, G = pcall(dofile, base .. "sprites.lua")
      check(okg and type(G) == "table", "§3 " .. r.id .. " articulé : sprites.lua lisible (sinon : py -3.9 tools/render/pieces/titans/feuilles_leviathan.py)")
      local MS = {}
      local okm, txt = pcall(read, base .. "MANIFEST.json")
      if okm then for n in txt:gmatch('"([%w%-_%.]+%.png)"') do MS[n] = true end end
      local function v2(what, d, w, h)
        local pth = fichier(d)
        local pw, ph = png_size(pth)
        check(pw == w and ph == h, "§3 " .. what .. " : PNG présent, " .. tostring(pw) .. " × " .. tostring(ph) .. " = sprites.lua (" .. w .. " × " .. h .. ")")
        check(MS[pth:match("([^/]+)$")] == true, "§3 MANIFEST (" .. r.id .. ") cite " .. pth:match("([^/]+)$"))
      end
      local nd = r.segmente.directions
      local function couches(qui, a, n_images)
        for _, nomc in ipairs({ "main", "glow", "shadow" }) do
          local c = a.couches[nomc]
          check(#c.hr == nd and #c.lr == nd and c.ll * c.lpf == n_images and c.dens > 0 and c.dens <= a.densite,
            "§3 " .. qui .. " " .. nomc .. " : un fichier par direction (" .. nd .. "), grille exacte, densité")
          check(c.w * c.ll <= 4096 and c.h * c.lpf <= 4096, "§3 " .. qui .. " " .. nomc .. " : feuille ≤ 4 096 px")
          for k = 1, nd do
            v2(qui .. " " .. nomc .. " " .. k, c.hr[k], c.w * c.ll, c.h * c.lpf)
            v2(qui .. " " .. nomc .. " " .. k, c.lr[k], c.lw * c.ll, c.lh * c.lpf)
          end
        end
      end
      if okg then
        check(G.tete and G.tete.anime == true and G.tete.directions == nd and r.anime.directions == nd and math.abs(G.tete.foulee - r.anime.foulee) < 1e-6,
          "§3 " .. r.id .. " articulé : tête animée en " .. nd .. " directions, foulée = règle")
        for st = 1, T.STAGES do
          local e = G.tete[tostring(st)]
          check(e and e.course and e.attaque and e.course.images == r.anime.images.course and e.attaque.images == r.anime.images.attaque,
            "§3 " .. r.id .. " articulé " .. st .. " : tête, images de marche et de salve = règle")
          if e and e.course then
            couches(r.id .. " tête " .. st .. " course", e.course, r.anime.images.course)
            couches(r.id .. " tête " .. st .. " attaque", e.attaque, r.anime.images.attaque)
            check(e.icone and e.icone.size == 64 and png_size(fichier(e.icone.filename)) == 64, "§3 " .. r.id .. " articulé " .. st .. " : icône du titan entier (64 px)")
          end
          for _, piece in ipairs(r.segmente.pieces) do
            local P = G[piece]
            local a = P and P[tostring(st)] and P[tostring(st)].pose
            check(P and P.directions == nd and a and a.images == 1, "§3 " .. r.id .. " " .. piece .. " " .. st .. " : pièce fixe, une image par direction")
            if a then couches(r.id .. " " .. piece .. " " .. st, a, 1) end
          end
        end
      end
    end
  end
  -- ennemis à une série (Kaiju cristallin, Écorcheur : KAIJUS-MUTANTS), puis les Écorchés (feuilles par variante, comme un allié animé)
  local function serie(K, qui, maxpx)
    for _, anim in ipairs({ "course", "attaque" }) do
      local a = K[anim]
      for _, nomc in ipairs({ "main", "glow", "shadow" }) do
        local c = a.couches[nomc]
        check(#c.hr == 8 and #c.lr == 8, "§3 " .. qui .. " " .. anim .. " " .. nomc .. " : un fichier par direction")
        check(c.ll * c.lpf >= a.images, "§3 " .. qui .. " " .. anim .. " " .. nomc .. " : la grille tient toutes les images")
        for k = 1, 8 do
          verifie(qui .. " " .. anim .. " " .. nomc .. " " .. k, c.hr[k], c.w * c.ll, c.h * c.lpf)
          verifie(qui .. " " .. anim .. " " .. nomc .. " " .. k, c.lr[k], c.lw * c.ll, c.lh * c.lpf)
        end
        check(c.w * c.ll <= maxpx and c.h * c.lpf <= maxpx, "§3 " .. qui .. " " .. anim .. " " .. nomc .. " : feuille ≤ " .. maxpx .. " px")
      end
    end
    check(K.icone and K.icone.size == 64, "§3 " .. qui .. " : icône")
  end
  for _, kk in ipairs(T.KAIJUS) do
    local K = SPR[kk.id]
    check(K and K.directions == 8 and K.course and K.course.images == 8 and K.attaque and K.attaque.images == 4, "§3 " .. kk.id .. " : 8 directions, course 8 images, attaque 4")
    if K and K.course then
      serie(K, kk.id, 4096)   -- s43 : Kaiju titanesque (15 tuiles de haut) : feuilles jusqu'à 4 096 px comme les alliés animés
      local PY = read("tools/render/pieces/titans/" .. kk.id .. ".py")
      local FO = py_num(PY:match("\nFOULEE = ([^#\n]+)"))
      check(K.foulee > 0 and FO and math.abs(K.foulee - FO) < 1e-3, "§3 " .. kk.id .. " : foulée des feuilles = FOULEE du modèle")
    end
  end
  local EC = SPR[T.ECORCHE.id]
  check(EC and EC.anime == true and EC.directions == 8 and EC.foulee > 0, "§3 Écorchés : feuilles animées, 8 directions, foulée")
  if EC and EC.anime then
    for iv, v in ipairs(T.ECORCHE.variants) do
      local e = EC[tostring(iv)]
      check(e and e.course and e.attaque and e.course.images == 8 and e.attaque.images == 4, "§3 Écorché " .. v.id .. " : course 8 images, attaque 4")
      if e and e.course then serie(e, "ecorche-" .. v.id, 2048) end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- §4 traductions
---------------------------------------------------------------------------------------------------
-- KAIJUS-MUTANTS : le moteur REFUSE le mod si une section ([entity-name]…) apparaît deux fois dans UN fichier (« Duplicate key "entity-name"
-- in property tree », banc content KAIJUS du 10/11) : chaque fichier est lu seul, ses sections comptées ; les clés des deux fichiers fusionnent.
local function cfg(p, t)
  t = t or {}
  local sec, vues, doubles = "", {}, {}
  for line in read(p):gmatch("[^\r\n]+") do
    local s = line:match("^%[([%w%-_]+)%]$")
    if s then
      if vues[s] then doubles[#doubles + 1] = s end
      vues[s], sec = true, s
    else
      local k, v = line:match("^([%w%-_]+)=(.*)$")
      if k then t[sec .. "." .. k] = v end
    end
  end
  check(#doubles == 0, "§4 " .. p .. " : aucune section en double dans le fichier (" .. table.concat(doubles, ", ") .. ")")
  return t
end
local FR, EN = cfg("locale/fr/titans.cfg"), cfg("locale/en/titans.cfg")
cfg("locale/fr/kaijus.cfg", FR)
cfg("locale/en/kaijus.cfg", EN)
local keys = { "entity-name." .. T.PREFIX .. "canon", "entity-name." .. T.PREFIX .. "griffe", "entity-name." .. T.PREFIX .. "singularite",
  "entity-name." .. T.PREFIX .. "singularite-eclair", "entity-name." .. T.PREFIX .. "drone-tir",
  "entity-name." .. T.PREFIX .. "impulsion", "entity-description." .. T.PREFIX .. T.KAIJU.id, "fo-titan.plafond", "fo-titan.evolue" }
for _, r in ipairs(T.ALLIES) do
  for _, k in ipairs({ "entity-name." .. r.name, "entity-description." .. r.name, "item-description." .. r.name, "item-name." .. r.segment_item,
    "item-description." .. r.segment_item, "technology-name." .. r.tech, "technology-description." .. r.tech }) do keys[#keys + 1] = k end
  for p = 1, T.PALIERS do keys[#keys + 1] = "entity-name." .. T.allie_name(r, p) end
end
for _, kk in ipairs(T.KAIJUS) do
  keys[#keys + 1] = "entity-description." .. T.PREFIX .. kk.id
  for e = kk.era_min, T.ERAS do keys[#keys + 1] = "entity-name." .. T.kaiju_name(e, kk) end
end
for _, v in ipairs(T.ECORCHE.variants) do
  keys[#keys + 1] = "entity-description." .. T.PREFIX .. T.ECORCHE.id .. "-" .. v.id
  for e = T.ECORCHE.era_min, T.ERAS do keys[#keys + 1] = "entity-name." .. T.ecorche_name(v, e) end
end
keys[#keys + 1] = "entity-name." .. T.PREFIX .. "mitraille"
for _, k in ipairs(keys) do check(FR[k] ~= nil and EN[k] ~= nil and FR[k] ~= "" and EN[k] ~= "", "§4 clé en FR et EN : " .. k) end
local same = true
for k in pairs(FR) do if not EN[k] then same = false end end -- comparaison d'ensembles : l'ordre ne compte pas
for k in pairs(EN) do if not FR[k] then same = false end end
check(same, "§4 FR et EN : mêmes clés")

---------------------------------------------------------------------------------------------------
-- §5 forme
---------------------------------------------------------------------------------------------------
check(not SRC:find("[^i]pairs%("), "§5 shared/robots/titans.lua : aucun pairs")
check(not SRC:find("\n%s+require%("), "§5 shared/robots/titans.lua : aucun require dans une fonction")
check(not SRC:find("%f[%w_]global%f[^%w_]"), "§5 shared/robots/titans.lua : global jamais nommé")
local PROTOS = read("prototypes/titans.lua") .. read("prototypes/titans_kaiju.lua")
local function prefix_names(src)
  local set = {}
  for n in src:gmatch("T%.PREFIX%s*%.%.%s*\"([^\"]+)\"") do set[n] = true end
  return set
end
local DECL = prefix_names(PROTOS)
for _, p in ipairs({ "script/robots/titans.lua", "shared/td/waves.lua" }) do
  local src = read(p)
  local missing = {}
  for n in pairs(prefix_names(src)) do if not DECL[n] then missing[#missing + 1] = n end end
  table.sort(missing)
  check(#missing == 0, "§5 " .. p .. " : noms T.PREFIX déclarés par un prototype (manquent : " .. table.concat(missing, ", ") .. ")")
  local brut = {}
  for line in src:gmatch("[^\n]*") do
    local code = line:gsub("%-%-.*$", "")
    if code:find("[%w_]+%s*=%s*{[^}]*%f[%w]a%s*=%s*0?%.%d") then brut[#brut + 1] = code:match("^%s*(.-)%s*$"):sub(1, 60) end
  end
  check(#brut == 0, "§5 " .. p .. " : aucune couleur translucide littérale (non prémultipliée) : " .. table.concat(brut, " | "))
  check(not src:find("%f[%w_]global%f[^%w_]"), "§5 " .. p .. " : global jamais nommé")
end
check(read("script/td/director.lua"):find("TD.compose(st.wave, RNG.float, Armee.age(game.forces[DEFENDER]))", 1, true) ~= nil, "§5 le directeur passe l'âge de la partie aux vagues")
-- FINITIONS : les noms des animations de corps sont bâtis par la SEULE T.anim_name, côté prototypes (déclaration) comme côté script (dessin) ;
-- le script choisit la direction par T.direction8 et la vitesse par T.vitesse_anim (jamais de trigonométrie, jamais de temps mesuré)
do
  local proto, scr = read("prototypes/titans.lua"), read("script/robots/titans.lua")
  check(proto:find("T.anim_name(", 1, true) ~= nil and proto:find('type = "animation"', 1, true) ~= nil, "§5 prototypes : animations de corps déclarées par T.anim_name")
  check(scr:find("T.anim_name(", 1, true) ~= nil and scr:find("rendering.draw_animation(", 1, true) ~= nil and scr:find("T.direction(", 1, true) ~= nil
    and scr:find("r.anime.directions", 1, true) ~= nil and scr:find("T.vitesse_anim(", 1, true) ~= nil,
    "§5 script : corps animé par rendering.draw_animation, direction et vitesse par la règle pure")
  check(not scr:find("math%.atan") and not scr:find("math%.sin") and not scr:find("math%.cos"), "§5 script : aucune trigonométrie")
  -- F507 (ART-16DIR, banc titans-marche 11/11 : orientation = 0,000 et torse = 0,375 sur 252 relevés en marche dans 8 directions, corps
  -- toujours dessiné au nord) : sur un spider-vehicle, seul le TORSE suit la marche ; le prototype le laisse tourner (vitesse du torse de
  -- l'araignée vanilla) et le script dessine le corps dans sa direction, jamais dans `orientation`
  check(scr:find("T.direction(g.e.torso_orientation, r.anime.directions)", 1, true) ~= nil and not scr:find("e%.orientation%f[^%w_]"),
    "§5 script : direction du corps = torse du spider-vehicle (F507), jamais LuaEntity.orientation (toujours 0 en marche)")
  check(proto:find('torso_rotation_speed = ARAIGNEE.torso_rotation_speed', 1, true) ~= nil and proto:find('data.raw["spider-vehicle"]["spidertron"]', 1, true) ~= nil
    and not proto:find("torso_rotation_speed = 0[,%s]"), "§5 prototypes : le torse des titans tourne (vitesse du torse de l'araignée vanilla, F507)")
end
-- F-TITANS (banc content V0677) : une RotatedAnimation à `filenames` exige `slice` et `lines_per_file` (prototype-api.json : « Mandatory if
-- filenames is defined » ; le schéma du harness les voit facultatifs : il ne l'attrape pas). Contrôle textuel sur TOUT prototypes/ : chaque
-- table qui pose `filenames =` pose aussi `slice =` (ou en hérite : arsenal_special le complète), et la grille d'un fichier du Kaiju est exacte.
do
  local function lua_files(dir, out)
    local p = io.popen('dir /b /s "' .. dir:gsub("/", "\\") .. '\\*.lua" 2>nul')
    if p then
      for line in p:lines() do out[#out + 1] = line end
      p:close()
    end
    return out
  end
  local files = lua_files("prototypes", {})
  check(#files > 10, "§5 prototypes/ listé (" .. #files .. " fichiers)")
  for _, f in ipairs(files) do
    local src = read(f)
    if src:find("filenames%s*=") then
      check(src:find("slice%s*=") ~= nil, "§5 " .. f .. " : `filenames` sans `slice` (le moteur refuse la RotatedAnimation)")
    end
  end
  if okspr and SPR.kaiju and SPR.kaiju.course then
    for _, anim in ipairs({ "course", "attaque" }) do
      for _, nomc in ipairs({ "main", "glow", "shadow" }) do
        local c = SPR.kaiju[anim].couches[nomc]
        check(c.ll * c.lpf == SPR.kaiju[anim].images, "§5 Kaiju " .. anim .. " " .. nomc .. " : grille exacte ll × lpf = images (lecture continue de filenames)")
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- §6 vagues
---------------------------------------------------------------------------------------------------
local function lcg(seed)
  local s = seed
  return function() s = (s * 48271) % 2147483647; return (s - 1) / 2147483646 end
end
local function kaijus(list)
  local n = 0
  for _, it in ipairs(list) do if T.kaiju_era_of_name(it[1]) then n = n + it[2] end end
  return n
end
local sans = true
for w = 1, 60 do if kaijus(TD.compose(w, lcg(7))) ~= 0 then sans = false end end
check(sans, "§6 sans âge : aucun Kaiju (vagues d'avant inchangées)")
for _, age in ipairs({ 1, 7, 12, 15 }) do
  local l20 = TD.compose(20, lcg(7), age)
  check(kaijus(l20) == 1 and l20[1][1] == T.kaiju_name(T.era(age)), "§6 vague 20, âge " .. age .. " : un Kaiju de l'ère " .. T.era(age) .. " en tête")
  check(kaijus(TD.compose(19, lcg(7), age)) == 0 and kaijus(TD.compose(40, lcg(7), age)) == 2, "§6 âge " .. age .. " : aucun à la vague 19, deux à la 40")
end
local a, b = TD.compose(25, lcg(3), 11), TD.compose(25, lcg(3), 11)
check(#a == #b and a[1][1] == b[1][1] and a[2][1] == b[2][1] and a[2][2] == b[2][2], "§6 composition déterministe avec l'âge")
-- KAIJUS-MUTANTS : à deux Kaijus (vague 40) et une ère où l'Écorcheur est ouvert, les deux archétypes mènent la vague ; à l'ère 1, deux cristallins
do
  local age_ec = T.age_of_era(T.ECORCHEUR.era_min)
  local l40 = TD.compose(40, lcg(7), age_ec)
  local noms = {}
  for _, it in ipairs(l40) do if T.kaiju_era_of_name(it[1]) then noms[#noms + 1] = it[1] end end
  check(#noms == 2 and noms[1] == T.kaiju_name(T.ECORCHEUR.era_min, T.KAIJU) and noms[2] == T.kaiju_name(T.ECORCHEUR.era_min, T.ECORCHEUR), "§6 vague 40 à l'ère de l'Écorcheur : un cristallin puis un Écorcheur")
  local l40b = TD.compose(40, lcg(7), 1)
  check(kaijus(l40b) == 2 and l40b[1][1] == T.kaiju_name(1) and l40b[1][2] == 2, "§6 vague 40 à l'ère 1 : deux cristallins (seul archétype ouvert)")
end

---------------------------------------------------------------------------------------------------
-- §7 mutants
---------------------------------------------------------------------------------------------------
local function refuse(T2)
  local ok, err = pcall(function()
    local j1, j6 = T2.juggernaut(T2.AGE_MIN), T2.juggernaut(T2.AGE_MAX)
    assert(j6.resistances[1].percent > j1.resistances[1].percent, "plaques")
    assert(j6.speed < j1.speed, "masse")
    assert(not j1.armes.canon and j6.armes.canon, "armes")
    assert(T2.kaiju_in_wave(40, 5) == 2, "vagues")
    assert(T2.kaiju(2).hp == Ech.pv(T2.age_of_era(2)) * T2.KAIJU.hp_mult, "pv du kaiju")
    assert(j1.hp == Ech.pv(T2.AGE_MIN), "pv du juggernaut")
    assert(T2.era_color(2).r == L.epochs[2 * L.ERA_EPOCHS].color.r, "couleur d'ère")
    assert(T2.SENTINELLE.singularite.slow < 1, "singularité qui ralentit")
    assert(T2.drones(T2.PALIERS) > T2.drones(1), "drones qui s'ajoutent")
    assert(not T2.allie(T2.LEVIATHAN, T2.AGE_MIN).armes.canon and T2.allie(T2.LEVIATHAN, T2.AGE_MAX).armes.canon, "canon du Léviathan plus tard")
    assert(T2.allie(T2.SENTINELLE, T2.AGE_MIN).speed < T2.allie(T2.JUGGERNAUT, T2.AGE_MIN).speed, "la Sentinelle plus lente que le Juggernaut")
    assert(T2.direction8(0.07) == 1 and T2.direction8(0.99) == 0, "direction8 au plus proche")
    assert(T2.direction(0.97, 16) == 0 and T2.direction(0.94, 16) == 15 and T2.direction(0.0625, 16) == 1, "direction au plus proche à 16 secteurs")
    assert(T2.JUGGERNAUT.anime.directions == (SERIE.dirs or 8) and T2.SENTINELLE.anime.directions == (SERIE_SE.dirs or 8)
      and T2.RAVAGEUR.anime.directions == (SERIE_RA.dirs or 8) and T2.LEVIATHAN.anime.directions == (SERIE_LE.dirs or 8), "directions = SERIE des modèles")
    assert(math.abs(T2.vitesse_anim(0.12, 6.9, 8) - 0.12 * 8 / 6.9) < 1e-12, "vitesse d'animation par la foulée")
    assert(T2.JUGGERNAUT.anime.images.course == SERIE.course and math.abs(T2.JUGGERNAUT.anime.foulee - FOULEE) < 1e-6, "animation = SERIE du modèle")
    -- KAIJUS-MUTANTS
    assert(T2.kaiju_pour(1, 2) == T2.KAIJU and T2.kaiju_pour(T2.ECORCHEUR.era_min, 2) == T2.ECORCHEUR, "rotation des archétypes")
    assert(T2.ECORCHEUR.era_min > 1, "Écorcheur plus tard que l'ère 1")
    local function tot(l) local n = 0; for _, it in ipairs(l) do n = n + it[2] end; return n end
    assert(tot(T2.ponte(T2.ERAS)) > tot(T2.ponte(3)) and #T2.ponte(5) == #T2.ECORCHE.variants, "ponte qui grandit et tourne")
    local ro, po = T2.ECORCHE.variants[1], T2.ECORCHE.variants[2]
    assert(T2.ecorche(ro, 2).hp < T2.ecorche(po, 2).hp and T2.ecorche(ro, 2).speed > T2.ecorche(po, 2).speed, "Écorchés : rôdeur léger et vif")
    assert(T2.ecorche(po, 2).resistances[1].percent > T2.ecorche(ro, 2).resistances[1].percent, "plaques du porteur")
    assert(not T2.kaiju(1, T2.ECORCHEUR).armes.tir and T2.kaiju(2, T2.ECORCHEUR).armes.tir, "tir de l'Écorcheur à l'ère 2")
    assert(T2.kaiju(2, T2.ECORCHEUR).hp < T2.kaiju(2).hp, "Écorcheur plus léger que le cristallin")
    assert(T2.ecorche_curve(ro, 3)[1][1] > T2.ecorche_curve(ro, 2)[1][1], "courbe des Écorchés par l'ère")
    assert(not T2.allie(T2.RAVAGEUR, T2.AGE_MIN).armes.lames and T2.allie(T2.RAVAGEUR, T2.AGE_MIN + 1).armes.lames, "lames au palier 2")
    assert(T2.RAVAGEUR.mitraille.n > 1, "mitraille à plusieurs projectiles")
    assert(T2.RAVAGEUR.anime.images.course == SERIE_RA.course and math.abs(T2.RAVAGEUR.anime.foulee - FOULEE_RA) < 1e-3, "animation du Ravageur = SERIE du modèle")
    -- TITANS-8DIR
    for _, c in ipairs({ { T2.SENTINELLE, SERIE_SE, FOULEE_SE }, { T2.LEVIATHAN, SERIE_LE, FOULEE_LE } }) do
      local a = c[1].anime
      assert(a and a.images.course == c[2].course and a.images.attaque == c[2].attaque and math.abs(a.foulee - c[3]) < 1e-6, "animation de " .. c[1].id .. " = SERIE du modèle")
    end
    -- LEVIATHAN-SEG : le Léviathan est articulé, tête et pièces dans les directions des feuilles (SERIE du modèle)
    local sg = T2.LEVIATHAN.segmente
    assert(sg and sg.n >= 2 and sg.directions == SERIE_LE.dirs and T2.LEVIATHAN.anime.directions == sg.directions, "Léviathan articulé, directions = SERIE")
    for _, kk in ipairs(T2.KAIJUS) do
      local c = T2.kaiju_curve(T2.ERAS, kk)
      assert(c[1][1] < c[2][1] and c[2][1] < c[3][1], "courbe de nid strictement croissante (" .. kk.id .. ")")
    end
    local faux = { EPOCHS = 18, ERA_EPOCHS = 2, epochs = {} }
    for i = 1, 18 do faux.epochs[i] = { key = "e" .. i, color = { r = i / 18, g = 0.5, b = 1 - i / 18 } } end
    local T3 = charger(T2.__src, faux)
    assert(T3.ERAS == 9 and T3.PALIERS == 9, "config")
  end)
  return not ok, err
end
local MUTANTS = {
  { "plaques nulles", "T.PLAQUE_PCT = 5", "T.PLAQUE_PCT = 0" },
  { "masse sans effet sur la vitesse", "T.LENTEUR_PART = 0.05", "T.LENTEUR_PART = 0" },
  { "canon dès le palier 1", '{ id = "canon", palier = 2 }', '{ id = "canon", palier = 1 }' },
  { "un seul Kaiju par vague", "return 1 + math.floor((wave - T.KAIJU_FIRST_WAVE) / T.KAIJU_PLUS_TOUTES)", "return 1" },
  { "Kaiju aux PV d'un géant", "hp = Ech.pv(a) * k.hp_mult", "hp = Ech.pv(a)" },
  { "Juggernaut aux PV doublés", "hp = Ech.pv(a), resistances = T.plaques(a, palier)", "hp = Ech.pv(a) * 2, resistances = T.plaques(a, palier)" },
  { "ères écrites en dur", "T.ERAS = math.ceil(L.EPOCHS / L.ERA_EPOCHS)", "T.ERAS = 5" },
  { "paliers écrits en dur", "T.PALIERS = T.AGE_MAX - T.AGE_MIN + 1", "T.PALIERS = 6" },
  { "couleur du premier âge de l'ère", "local e = L.epochs[T.age_of_era(era)]", "local e = L.epochs[era]" },
  { "singularité sans ralentissement", "slow = 0.5, slow_ticks = 120", "slow = 1, slow_ticks = 120" },
  { "drones figés à 2", "return d.base + (palier >= d.plus_palier and 1 or 0)", "return d.base" },
  { "canon du Léviathan dès le palier 1", '{ id = "canon", palier = 3 }', '{ id = "canon", palier = 1 }' },
  { "Sentinelle aussi rapide que le Juggernaut", 'dtype = "laser", speed = 0.10, effect = "titan", armes = T.ARMES_SENTINELLE', 'dtype = "laser", speed = 0.12, effect = "titan", armes = T.ARMES_SENTINELLE' },
  { "direction sans arrondi au plus proche", "return math.floor(o * n + 0.5) % n", "return math.floor(o * n) % n" },
  -- ART-16DIR
  { "direction à 8 secteurs en dur", "return math.floor(o * n + 0.5) % n", "return math.floor(o * 8 + 0.5) % 8" },
  { "Juggernaut à 8 directions", "foulee = 6.9, attaque_ticks = 30, directions = 16 }", "foulee = 6.9, attaque_ticks = 30, directions = 8 }" },
  { "Sentinelle à 8 directions", "foulee = 6.0, attaque_ticks = 30, directions = 16 }", "foulee = 6.0, attaque_ticks = 30, directions = 8 }" },
  { "Ravageur à 8 directions", "foulee = 4.472, attaque_ticks = 30, directions = 16 }", "foulee = 4.472, attaque_ticks = 30, directions = 8 }" },
  { "vitesse d'animation sans la foulée", "return speed * images / foulee", "return speed * images" },
  { "images de course écrites en dur fausses", "images = { course = 8, attaque = 4 }", "images = { course = 4, attaque = 4 }" },
  { "foulée écrite en dur fausse", "foulee = 6.9, attaque_ticks = 30", "foulee = 4, attaque_ticks = 30" },
  -- KAIJUS-MUTANTS
  { "rotation des archétypes ignorée", "return l[(n - 1) % #l + 1]", "return l[1]" },
  { "Écorcheur ouvert dès l'ère 1", 'id = "ecorcheur", era_min = 2,', 'id = "ecorcheur", era_min = 1,' },
  { "ponte constante", "local n = k.ponte.base + k.ponte.plus_era * math.max(0, clamp(era, 1, T.ERAS) - e_ponte)", "local n = k.ponte.base" },
  { "ponte d'une seule variante", "local v = T.ECORCHE.variants[(i - 1) % #T.ECORCHE.variants + 1]", "local v = T.ECORCHE.variants[1]" },
  { "Écorché sans multiplicateur de PV", "hp = d.pv * k.hp_mult * v.hp,", "hp = d.pv * k.hp_mult," },
  { "rôdeur pas plus vif", '{ id = "rodeur", hp = 0.6, dmg = 0.8, speed = 1.35,', '{ id = "rodeur", hp = 0.6, dmg = 0.8, speed = 0.8,' },
  { "plaques du porteur ignorées", "percent = math.min(T.PLAQUE_MAX, r.percent + v.plaques)", "percent = math.min(T.PLAQUE_MAX, r.percent)" },
  { "tir de l'Écorcheur dès l'ère 1", '{ id = "tir", era = 2 }', '{ id = "tir", era = 1 }' },
  { "Écorcheur aux PV du cristallin", 'speed = 0.19, hp_mult = 2.2,', 'speed = 0.19, hp_mult = 3,' },
  { "courbe des Écorchés sans l'ère", "T.ECORCHE_EVO_PAS * (era - T.ECORCHE.era_min)", "0" },
  { "lames du Ravageur dès le palier 1", '{ id = "lames", palier = 2 }', '{ id = "lames", palier = 1 }' },
  { "mitraille à un seul projectile", "mitraille = { n = 6,", "mitraille = { n = 1," },
  { "courbe de nid d'avant (0,98 et 1 : l'Écorcheur de l'ère V donnait 0,97, 1, 1, refusé par le moteur)",
    "local e0 = math.min(0.96, T.KAIJU_EVO0 + T.KAIJU_EVO_PAS * (era - 1) + 0.01 * (rang - 1))\n  return { { e0, 0.0 }, { math.min(0.99, e0 + 0.03)",
    "local e0 = math.min(0.98, T.KAIJU_EVO0 + T.KAIJU_EVO_PAS * (era - 1) + 0.01 * (rang - 1))\n  return { { e0, 0.0 }, { math.min(1.0, e0 + 0.03)" },
  { "images du Ravageur écrites en dur fausses", "anime = { images = { course = 8, attaque = 4 }, foulee = 4.472, attaque_ticks = 30, directions = 16 }", "anime = { images = { course = 6, attaque = 4 }, foulee = 4.472, attaque_ticks = 30, directions = 16 }" },
  -- TITANS-8DIR
  { "Sentinelle sans corps animé", "anime = { images = { course = 8, attaque = 4 }, foulee = 6.0, attaque_ticks = 30, directions = 16 }", "anime = nil" },
  { "foulée de la Sentinelle fausse", "foulee = 6.0, attaque_ticks = 30", "foulee = 4.0, attaque_ticks = 30" },
  { "salve de la Sentinelle à 2 images", "attaque = 4 }, foulee = 6.0", "attaque = 2 }, foulee = 6.0" },
  { "Léviathan sans corps animé", "anime = { images = { course = 4, attaque = 4 }, foulee = 4.5, attaque_ticks = 30, directions = 16 }", "anime = nil" },
  { "foulée du Léviathan fausse", "foulee = 4.5, attaque_ticks = 30", "foulee = 6.9, attaque_ticks = 30" },
  { "marche de la tête du Léviathan à 6 images", "course = 4, attaque = 4 }, foulee = 4.5", "course = 6, attaque = 4 }, foulee = 4.5" },
  -- LEVIATHAN-SEG (11/11)
  { "Léviathan d'un seul tenant (non articulé)", "segmente = { n = 4,", "segmente_ = { n = 4," },
  { "tête du Léviathan en 8 directions", "attaque_ticks = 30, directions = 16 }", "attaque_ticks = 30, directions = 8 }" },
}
local T0 = charger(SRC, nil)
T0.__src = SRC
local r0, e0 = refuse(T0)
check(not r0, "§7 la règle d'origine passe ses propres contrôles (" .. tostring(e0) .. ")")
for _, m in ipairs(MUTANTS) do
  local nom, de, vers = m[1], m[2], m[3]
  check(SRC:find(de, 1, true) ~= nil, "§7 mutant « " .. nom .. " » : la règle d'origine est là")
  local src2 = SRC:gsub(de:gsub("%p", "%%%0"), (vers:gsub("%%", "%%%%")), 1)
  local okload, T2 = pcall(charger, src2, nil)
  if okload then T2.__src = src2 end
  local ref, err = true, "chargement"
  if okload then ref, err = refuse(T2) end
  check(ref, "§7 mutant refusé : " .. nom .. (ref and "" or " (accepté : " .. tostring(err) .. ")"))
end

---------------------------------------------------------------------------------------------------
-- §8 (VISUELS-DISTINCTS, 10/11) : Écorchés lisibles de loin. Chaque variante a sa lueur propre (données), deux à deux éloignées, et sa
-- teinte en jeu reste distincte à chaque ère ; les feuilles le PROUVENT : luminance moyenne mesurée de la course (feuilles_titans.py,
-- sprites.lua ecorche.mesure) rôdeur > hurleur > porteur, écarts >= 0,03, et chaque paire séparée par la luminance (>= 0,06) ou la
-- couleur moyenne (distance RVB >= 0,08) (s43 3d-ecorches).
---------------------------------------------------------------------------------------------------
local function dist(a, b) return math.sqrt((a.r - b.r) ^ 2 + (a.g - b.g) ^ 2 + (a.b - b.b) ^ 2) end
local function juge_ecorches(TT, MES)
  local refus = {}
  local function non(t) refus[#refus + 1] = t end
  local V = TT.ECORCHE.variants
  for i = 1, #V do
    for j = i + 1, #V do
      local a, b = V[i].lueur, V[j].lueur
      if not a or not b then non("variante sans lueur propre")
      elseif dist(a, b) < 0.5 then non("lueurs trop proches " .. V[i].id .. "/" .. V[j].id) end
      for era = TT.ECORCHE.era_min, TT.ERAS do
        if dist(TT.ecorche(V[i], era).tint, TT.ecorche(V[j], era).tint) < 0.35 then
          non("teintes en jeu trop proches à l'ère " .. era .. " : " .. V[i].id .. "/" .. V[j].id)
        end
      end
    end
  end
  local l = {}
  for i, v in ipairs(V) do l[v.id] = MES and MES[tostring(i)] and MES[tostring(i)].luminance end
  if not (l.rodeur and l.porteur and l.hurleur) then non("luminances non mesurées (feuilles_titans.py non relancé)")
  elseif l.rodeur - l.hurleur < 0.03 or l.hurleur - l.porteur < 0.03 then
    non(string.format("luminances trop proches ou dans le mauvais ordre : rôdeur %.3f, hurleur %.3f, porteur %.3f", l.rodeur, l.hurleur, l.porteur))
  else
    -- s43 3d-ecorches : distinction en TEINTE + luminance : deux variantes se séparent par un écart de luminance >= 0,06 OU par leur
    -- couleur moyenne mesurée (distance RVB >= 0,08) ; l'ordre rôdeur > hurleur > porteur reste exigé (écarts >= 0,03)
    for i = 1, #V do
      for j = i + 1, #V do
        local a, b = MES[tostring(i)], MES[tostring(j)]
        local dl = math.abs(a.luminance - b.luminance)
        local dc = (a.rgb and b.rgb) and math.sqrt((a.rgb[1] - b.rgb[1]) ^ 2 + (a.rgb[2] - b.rgb[2]) ^ 2 + (a.rgb[3] - b.rgb[3]) ^ 2) or 0
        if dl < 0.06 and dc < 0.08 then non(string.format("%s/%s confondus : écart de luminance %.3f, de couleur %.3f", V[i].id, V[j].id, dl, dc)) end
      end
    end
  end
  return refus
end
local MES = SPR and SPR.ecorche and SPR.ecorche.mesure
local r8 = juge_ecorches(T, MES)
check(#r8 == 0, "§8 Écorchés lisibles de loin : " .. table.concat(r8, " ; "))
if MES then
  for i, v in ipairs(T.ECORCHE.variants) do
    local m = MES[tostring(i)]
    if m then print(string.format("[TITANS] §8 %s : luminance %.3f, couleur moyenne (%.2f, %.2f, %.2f)", v.id, m.luminance, m.rgb[1], m.rgb[2], m.rgb[3])) end
  end
end
local function mut8(nom, de, vers)
  check(SRC:find(de, 1, true) ~= nil, "§8 mutant « " .. nom .. " » : le texte d'origine est là")
  local src2 = SRC:gsub(de:gsub("%p", "%%%0"), (vers:gsub("%%", "%%%%")), 1)
  local okload, T2 = pcall(charger, src2, nil)
  check(not okload or #juge_ecorches(T2, MES) > 0, "§8 mutant refusé : " .. nom)
end
mut8("lueur du porteur copiée du rôdeur", "lueur = { r = 1.00, g = 0.50, b = 0.08 }", "lueur = { r = 0.70, g = 0.97, b = 1.00 }")
mut8("teinte de l'ère seule (part de la variante nulle)", "part_variante = 0.75,", "part_variante = 0,")
mut8("teinte d'avant (couleur de l'ère)", "tint = T.ecorche_tint(v, era),", "tint = T.era_color(era),")
for _, m in ipairs({ { "luminances confondues", function(M) M["1"].luminance = M["3"].luminance end },
  { "porteur clair", function(M) M["2"].luminance = 0.9 end }, { "mesures absentes", function(M) M["1"] = nil end },
  { "rôdeur et hurleur de même couleur, luminances proches", function(M) M["1"].rgb = M["3"].rgb; M["1"].luminance = M["3"].luminance + 0.04 end } }) do
  local M2 = {}
  for k, v in pairs(MES or {}) do M2[k] = { luminance = v.luminance, rgb = v.rgb } end
  local ok = pcall(m[2], M2)
  check(ok and #juge_ecorches(T, M2) > 0, "§8 mutant refusé : " .. m[1])
end

print(string.format("[TITANS] %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
