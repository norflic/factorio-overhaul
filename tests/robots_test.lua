--[[
  Lot RB-1 CHAÎNE (31/10) : banc hors jeu des robots (shared/content/robots.lua, shared/robots/modele.lua, et les règles de
  forme des fichiers de script/robots/ et prototypes/robots.lua).
    §1 données : un robot (Trotte-Vapeur, âge 3), prix contre la valeur visée (200 MU, monnaies de shared/content/epochs.lua),
       ingrédients d'au plus 100 (un bras ne livre pas plus, RB0-1), DPS = dégâts × 60 / cadence, noms, relecture des noms d'unité,
       propriétaires = joueur + factions du mod ;
    §2 plafond en points (12 + 6 × âge ; réglage), kit retiré seulement s'il reste de la place et si « maintenir N » n'est pas atteint ;
    §3 registre des unités vivantes : points et effectifs par force, ajout et retrait idempotents, liste triée, balayage, cohérence,
       déterminisme (mêmes opérations, même état, quel que soit l'ordre d'arrivée) ;
    §4 file d'une usine (premier robot sous sa cible) ; §5 géométrie de la sortie et du ralliement ; ordres ;
    §6 forme des fichiers : aucun pairs dans une décision, aucun require dans une fonction (F24), `global` jamais nommé, aucun
       hasard ni horloge, aucun nom d'objet du lot dans shared/ai3 ni script/ai3 (le cerveau lira les prototypes, RB-3) ;
    §7 traductions FR et EN de tout ce que le lot déclare (clés localisées lues dans les sources) ;
    §8 mutants : chaque règle faussée est vue par au moins un contrôle.
  Usage : lua5.2 tests/robots_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local RO_SRC = read("shared/content/robots.lua")
local MO_SRC = read("shared/robots/modele.lua")

--- Charge les deux modules depuis un texte (mutants) ; rend (Ro, Mo) ou (nil, erreur).
local function load_all(ro_src, mo_src)
  local f1, e1 = load(ro_src, "=robots", "t")
  if not f1 then return nil, e1 end
  local ok1, Ro = pcall(f1)
  if not ok1 then return nil, Ro end
  local saved = package.loaded["shared.content.robots"]
  package.loaded["shared.content.robots"] = Ro
  local f2, e2 = load(mo_src, "=modele", "t")
  if not f2 then package.loaded["shared.content.robots"] = saved return nil, e2 end
  local ok2, Mo = pcall(f2)
  package.loaded["shared.content.robots"] = saved
  if not ok2 then return nil, Mo end
  return Ro, Mo
end

local X = require("shared.content.epochs")
local F = require("shared.faction.config")

local function strip(src) return (src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")) end

local function suite(Ro, Mo)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end

  -- §1 Données.
  check(#Ro.ROBOTS == 1 and Ro.ROBOTS[1].id == "steam-trotter", "§1 un seul robot en RB-1 : le Trotte-Vapeur")
  local tr = Ro.robot("steam-trotter")
  check(tr and tr.age == 3 and tr.class == "P" and tr.points == 1, "§1 Trotte-Vapeur : âge 3, petit, 1 point")
  check(tr and tr.hp == 900 and tr.dps == 100 and tr.range == 18 and tr.speed == 0.14, "§1 Trotte-Vapeur : 900 PV, 100 DPS, portée 18, vitesse 0,14")
  check(tr and tr.dps == tr.shot.damage * 60 / tr.shot.cooldown, "§1 DPS = dégâts × 60 / cadence")
  check(tr and tr.half <= 0.9 and tr.range <= 45, "§1 boîte ±0,9 au plus, portée ≤ 45 (PLAN §3)")
  local mu = 0
  local value = {}
  for _, c in ipairs(X.currencies) do value[c.item] = c.value end
  for _, g in ipairs(tr.ingredients) do mu = mu + (value[g[1]] or 0) * g[2] end
  check(mu == tr.mu and mu == 200, "§1 coût en MU = 200 (10 moteurs × 9 + 22 aciers × 5)", tostring(mu))
  local worst = 0
  for _, g in ipairs(tr.ingredients) do worst = math.max(worst, g[2]) end
  for _, w in ipairs(Ro.WORKSHOPS) do for _, g in ipairs(w.ingredients) do worst = math.max(worst, g[2]) end end
  check(worst <= 100, "§1 aucun ingrédient au-delà de 100 (un bras ne livre pas plus, RB0-1)", tostring(worst))
  check(#tr.ingredients == 2, "§1 deux solides : un coffre et un bras par ingrédient (RB0-2)")
  check(Ro.kit_name("steam-trotter") == "fo-robot-kit-steam-trotter" and tr.kit == Ro.kit_name("steam-trotter"), "§1 nom du kit")
  check(Ro.recipe_name("steam-trotter") == tr.recipe and Ro.robot_of_kit(tr.kit) == tr, "§1 recette et relecture du kit")
  check(Ro.unit_name("azure", "steam-trotter") == "fo-robot-azure-steam-trotter", "§1 nom d'unité par propriétaire")
  -- relecture des noms d'unité, pour tous les propriétaires
  local roundtrip = true
  for _, owner in ipairs(Ro.OWNERS) do
    local o, id = Ro.parse_unit(Ro.unit_name(owner, "steam-trotter"))
    if o ~= owner or id ~= "steam-trotter" then roundtrip = false end
  end
  check(roundtrip, "§1 relecture du nom d'unité : propriétaire et robot")
  check(Ro.parse_unit("fo-robot-azure-inconnu") == nil and Ro.parse_unit("fo-azure-rifleman") == nil
    and Ro.parse_unit("fo-robot-workshop") == nil and Ro.parse_unit(nil) == nil, "§1 un autre nom n'est pas une unité de robot")
  check(#Ro.unit_names() == #Ro.OWNERS * #Ro.ROBOTS, "§1 un prototype par propriétaire et par robot")
  check(Ro.OWNERS[1] == Ro.PLAYER_OWNER and #Ro.OWNERS == 1 + #F.factions, "§1 propriétaires : le joueur puis les factions")
  local same = true
  for i, f in ipairs(F.factions) do if Ro.OWNERS[i + 1] ~= f.key then same = false end end
  check(same, "§1 les propriétaires suivent F.factions (clés et ordre)")
  check(Ro.owner_of("scarlet", { scarlet = "scarlet" }) == "scarlet" and Ro.owner_of("player", { scarlet = "scarlet" }) == "player"
    and Ro.owner_of("x") == "player", "§1 propriétaire d'une force : la faction, sinon le joueur")
  local w = Ro.workshop("fo-robot-workshop")
  check(w and w.size == 3 and w.age == 3 and w.category == "fo-robots-1" and Ro.is_workshop("fo-robot-workshop")
    and not Ro.is_workshop("assembling-machine-2"), "§1 atelier : 3 × 3, âge 3, catégorie fo-robots-1")
  check(#Ro.robots_of("fo-robot-workshop") == 1 and #Ro.robots_of("nom-inconnu") == 0, "§1 robots d'un bâtiment")
  check(Ro.POINTS.P == 1 and Ro.POINTS.M == 2 and Ro.POINTS.G == 4 and Ro.POINTS.giant == 12, "§1 points : P 1, M 2, G 4, géant 12")
  local unlocks = Ro.tech_unlocks()
  check(#unlocks == 2 and unlocks[1] == "fo-robot-workshop" and unlocks[2] == tr.recipe, "§1 la technologie débloque l'atelier et le kit")
  check(Ro.TECH.epoch == 3 and Ro.TECH.prerequisites[1] == "engine", "§1 technologie de l'âge 3, après le moteur")

  -- §2 Plafond.
  check(Mo.cap(3) == 30 and Mo.cap(1) == 18 and Mo.cap(15) == 102, "§2 plafond 12 + 6 × âge : 30 à l'âge 3, 102 à l'âge 15",
    Mo.cap(3) .. " " .. Mo.cap(15))
  check(Mo.cap(0) == 18 and Mo.cap(-4) == 18 and Mo.cap(99) == 102 and Mo.cap(nil) == 18 and Mo.cap(3.9) == 30,
    "§2 âge ramené dans 1 à 15")
  check(Mo.cap(3, 2) == 2 and Mo.cap(3, 0) == 30 and Mo.cap(3, nil) == 30 and Mo.cap(15, 500) == 500, "§2 le réglage > 0 remplace le plafond")
  check(Mo.room(5, 30) == 25 and Mo.room(40, 30) == 0, "§2 points libres, jamais négatifs")
  local function rel(used, cap, pts, have, keep) return Mo.can_release({ used = used, cap = cap, points = pts, have = have, keep = keep }) end
  check(rel(0, 2, 1, 0) and rel(1, 2, 1, 1) and not rel(2, 2, 1, 2), "§2 plafond 2 : le 3e kit reste")
  check(not rel(29, 30, 2, 5) and rel(28, 30, 2, 5), "§2 un robot de 2 points exige 2 points libres")
  check(rel(0, 30, 1, 3, nil) and rel(0, 30, 1, 3, 4) and not rel(0, 30, 1, 4, 4) and not rel(0, 30, 1, 9, 4) and rel(0, 30, 1, 0, 1),
    "§2 maintenir N : le kit reste quand l'effectif a atteint N")
  check(not rel(0, 30, 1, 0, 0), "§2 maintenir 0 : aucun robot")

  -- §3 Registre.
  local l = Mo.new_ledger()
  check(Mo.count(l) == 0 and Mo.used(l, "player") == 0 and Mo.have(l, "player", "steam-trotter") == 0, "§3 registre vide")
  check(Mo.add(l, "player", 30, "steam-trotter", 1) and Mo.add(l, "player", 10, "steam-trotter", 1) and Mo.add(l, "scarlet", 20, "steam-trotter", 2),
    "§3 ajouts")
  check(not Mo.add(l, "player", 10, "steam-trotter", 1), "§3 ajouter deux fois la même unité : refusé")
  check(Mo.used(l, "player") == 2 and Mo.used(l, "scarlet") == 2 and Mo.have(l, "player", "steam-trotter") == 2, "§3 points et effectifs par force")
  check(table.concat(l.order, ",") == "10,20,30", "§3 liste triée par numéro d'unité malgré l'ordre d'arrivée", table.concat(l.order, ","))
  check(table.concat(Mo.units_of(l, "player"), ",") == "10,30" and table.concat(Mo.units_of(l, "scarlet"), ",") == "20", "§3 unités d'une force")
  check(table.concat(l.forces, ",") == "player,scarlet", "§3 forces triées")
  local f1, id1, p1 = Mo.remove(l, 10)
  check(f1 == "player" and id1 == "steam-trotter" and p1 == 1 and Mo.used(l, "player") == 1, "§3 retrait : les points sont rendus")
  check(Mo.remove(l, 10) == nil and Mo.used(l, "player") == 1, "§3 retirer deux fois : sans effet (idempotent)")
  check(Mo.remove(l, 999) == nil, "§3 retirer une inconnue : sans effet")
  check(Mo.check(l), "§3 cohérence interne")
  Mo.add(l, "player", 11, "steam-trotter", 1)
  Mo.add(l, "player", 12, "steam-trotter", 1)
  local gone = Mo.prune(l, function(un) return un ~= 11 and un ~= 30 end)
  check(#gone == 2 and gone[1] == 11 and gone[2] == 30 and Mo.used(l, "player") == 1 and Mo.have(l, "player", "steam-trotter") == 1,
    "§3 balayage : retire les unités refusées, dans l'ordre", table.concat(gone, ","))
  check(Mo.check(l), "§3 cohérence après balayage")
  local bad = Mo.new_ledger()
  Mo.add(bad, "player", 1, "steam-trotter", 1)
  bad.used.player = 5
  check(select(1, Mo.check(bad)) == false, "§3 une incohérence de points est vue")
  local bad2 = Mo.new_ledger()
  Mo.add(bad2, "player", 2, "steam-trotter", 1)
  Mo.add(bad2, "player", 1, "steam-trotter", 1)
  bad2.order = { 2, 1 }
  check(select(1, Mo.check(bad2)) == false, "§3 une liste non triée est vue")
  -- déterminisme : tous les ordres d'arrivée donnent le même état
  local function serial(order)
    local lg = Mo.new_ledger()
    for _, un in ipairs(order) do Mo.add(lg, un % 2 == 0 and "player" or "azure", un, "steam-trotter", 1) end
    Mo.remove(lg, 3)
    return table.concat(lg.order, ",") .. "|" .. table.concat(lg.forces, ",") .. "|" .. Mo.used(lg, "player") .. "," .. Mo.used(lg, "azure")
  end
  check(serial({ 5, 2, 3, 8, 1 }) == serial({ 1, 8, 3, 2, 5 }) and serial({ 1, 2, 3, 5, 8 }) == serial({ 3, 1, 5, 8, 2 }), "§3 état identique quel que soit l'ordre d'arrivée")

  -- §4 File.
  local q = { { id = "a", n = 2 }, { id = "b", n = 1 }, { id = "c", n = 0 } }
  check(Mo.queue_next(q, {}) == "a" and Mo.queue_next(q, { a = 2 }) == "b" and Mo.queue_next(q, { a = 2, b = 1 }) == nil, "§4 file : premier robot sous sa cible")
  check(Mo.queue_next(q, { a = 5, b = 0 }) == "b" and Mo.queue_next({}, {}) == nil and Mo.queue_next(nil, {}) == nil, "§4 file : trop de a, b manque ; file vide")
  check(Mo.queue_next({ { id = "c", n = 0 }, { id = "a", n = -1 } }, {}) == nil, "§4 file : cible nulle ou négative sautée")
  check(Mo.queue_valid(q, { a = true, b = true, c = true }) and not Mo.queue_valid(q, { a = true, b = true })
    and not Mo.queue_valid({ { id = "a", n = 1.5 } }, { a = true }) and not Mo.queue_valid({ { id = "a", n = -1 } }, { a = true }), "§4 file valide : robots connus, n entier ≥ 0")

  -- §5 Géométrie, ordres.
  local o = Mo.out_point({ x = 10, y = 20 }, 3)
  check(o.x == 10 and o.y == 23.5, "§5 sortie : sous le bord sud + 2 tuiles", tostring(o.y))
  local r = Mo.default_rally({ x = 10, y = 20 }, 3)
  check(r.x == 10 and r.y == 23.5 + Ro.RALLY_DEPTH, "§5 ralliement : au sud de la sortie")
  check(Mo.dist({ x = 0, y = 0 }, { x = 3, y = 4 }) == 5, "§5 distance")
  check(Mo.valid_point({ x = 1, y = 2 }) and Mo.valid_point({ 1, 2 }) and not Mo.valid_point({ x = 1 }) and not Mo.valid_point(nil)
    and not Mo.valid_point({ x = 0 / 0, y = 1 }) and not Mo.valid_point({ x = 1e9, y = 0 }), "§5 point d'ordre valide")
  check(Mo.is_order("move") and Mo.is_order("attack") and not Mo.is_order("flee"), "§5 ordres connus")
  return pass, fail, msgs
end

local Ro0, Mo0 = assert(load_all(RO_SRC, MO_SRC))
local pass, fail, msgs = suite(Ro0, Mo0)

-- §6 Forme des fichiers.
local FILES = { "shared/content/robots.lua", "shared/robots/modele.lua", "script/robots/armee.lua", "script/robots/usine.lua",
  "script/robots/ordres.lua", "prototypes/robots.lua", "settings/robots.lua" }
local function check6(c, m)
  if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
end
for _, path in ipairs(FILES) do
  local code = strip(read(path))
  -- pairs() n'est toléré que sur les collections du moteur triées juste après (game.surfaces)
  local bare = false
  for line in code:gmatch("[^\n]+") do
    if line:find("[^i_%w]pairs%s*%(") and not line:find("game%.surfaces") then bare = true end
  end
  check6(not bare, "§6 " .. path .. " : pairs() dans une décision")
  check6(not code:find("math%.random") and not code:find("os%.time") and not code:find("os%.clock") and not code:find("game%.tick"),
    "§6 " .. path .. " : hasard ou horloge")
  check6(not code:find("[^%.%w_%-]global%f[^%w_]"), "§6 " .. path .. " : `global` nommé (seul script/core/storage.lua le nomme)")
  -- F24 : aucun require dans une fonction (ligne indentée)
  local indented = false
  for line in code:gmatch("[^\n]+") do
    if line:match("^%s+.-require%s*%(") and not line:match("^%s*local%s+[%w_]+%s*=%s*require") then indented = true end
    if line:match("^%s+local%s+[%w_]+%s*=%s*require") then indented = true end
  end
  check6(not indented, "§6 " .. path .. " : require dans une fonction (F24)")
end
-- les fichiers de shared/ ne touchent pas à l'API du jeu
for _, path in ipairs({ "shared/content/robots.lua", "shared/robots/modele.lua" }) do
  local code = strip(read(path))
  check6(not code:find("%f[%w_]game%.") and not code:find("%f[%w_]defines%.") and not code:find("%f[%w_]script%.") and not code:find("%f[%w_]settings%.")
    and not code:find("%f[%w_]data:extend") and not code:find("%f[%w_]log%s*%("), "§6 " .. path .. " : Lua pur (aucune API du jeu)")
end
-- aucun nom du lot dans le cerveau (tests/iag_test.lua §8 le contrôle aussi, par permutation)
local brain_hits = {}
local p = assert(io.popen('git ls-files "shared/ai3/*.lua" "script/ai3/*.lua"'))
local brain_files = {}
for path in p:lines() do brain_files[#brain_files + 1] = path end
p:close()
for _, path in ipairs(brain_files) do
  local code = strip(read(path))
  if code:find("fo%-robot") or code:find("steam%-trotter") then brain_hits[#brain_hits + 1] = path end
end
check6(#brain_files > 0 and #brain_hits == 0, "§6 aucun nom de robot dans shared/ai3 ni script/ai3 : " .. table.concat(brain_hits, " "))

-- §7 Traductions : toute clé localisée citée par les sources du lot existe en FR et EN.
local function cfg_keys(path)
  local keys, section = {}, nil
  for line in read(path):gmatch("[^\r\n]+") do
    local s = line:match("^%[([%w%-_]+)%]$")
    if s then section = s
    elseif section and not line:match("^%s*;") then
      local k = line:match("^([^=]+)=")
      if k then keys[section .. "." .. k] = true end
    end
  end
  return keys
end
local FR, EN = cfg_keys("locale/fr/robots.cfg"), cfg_keys("locale/en/robots.cfg")
local needed = { "fo-robots.name-steam-trotter", "fo-robots.unit-name", "fo-robots.unit-desc", "item-subgroup-name.fo-robots",
  "ammo-category-name.fo-robot", "entity-name.fo-robot-workshop", "entity-description.fo-robot-workshop",
  "item-name.fo-robot-workshop", "item-name.fo-robot-kit-steam-trotter", "item-description.fo-robot-kit-steam-trotter",
  "technology-name." .. Ro0.TECH.name, "technology-description." .. Ro0.TECH.name,
  "mod-setting-name." .. Ro0.SETTING, "mod-setting-description." .. Ro0.SETTING,
  "mod-setting-name." .. Ro0.SETTING_CAP, "mod-setting-description." .. Ro0.SETTING_CAP }
for _, k in ipairs(needed) do
  check6(FR[k] ~= nil, "§7 traduction FR absente : " .. k)
  check6(EN[k] ~= nil, "§7 traduction EN absente : " .. k)
end
-- le prototype ne cite que des clés présentes : on relit ses chaînes { "section.clé" }
local proto = read("prototypes/robots.lua")
for key in proto:gmatch('{%s*"([%w%-_]+%.[%w%-_]+)"') do
  local base = key
  local found = FR[base] ~= nil or key:match("^entity%-name%.fo%-robot%-workshop$") ~= nil
  -- les noms par robot sont composés (name-<id>) : lus dans la boucle des robots
  if not found and (key == "fo-robots.name-" or key:find("^fo%-robots%.name%-")) then found = true end
  check6(found, "§7 clé du prototype absente du locale FR : " .. key)
end
for _, r in ipairs(Ro0.ROBOTS) do
  check6(FR["fo-robots.name-" .. r.id] ~= nil and EN["fo-robots.name-" .. r.id] ~= nil, "§7 nom du robot " .. r.id .. " en FR et EN")
end
-- chaque section du FR a la même liste de clés en EN
local same = true
for k in pairs(FR) do if not EN[k] then same = false end end
for k in pairs(EN) do if not FR[k] then same = false end end
check6(same, "§7 FR et EN : mêmes clés")

-- §8 Mutants.
local MUTANTS = {
  { "plafond sans âge", "return Ro.CAP_BASE + Ro.CAP_PER_AGE * M.age_clamped(age)", "return Ro.CAP_BASE + Ro.CAP_PER_AGE" },
  { "âge sans borne haute", "return max(1, min(Ro.AGES, floor(tonumber(age) or 1)))", "return max(1, floor(tonumber(age) or 1))" },
  { "âge sans borne basse", "return max(1, min(Ro.AGES, floor(tonumber(age) or 1)))", "return min(Ro.AGES, floor(tonumber(age) or 1))" },
  { "réglage ignoré", "if override and override > 0 then return floor(override) end", "" },
  { "réglage nul compté", "if override and override > 0 then return floor(override) end", "if override then return floor(override) end" },
  { "points libres négatifs", "return max(0, cap - used)", "return cap - used" },
  { "plafond dépassable d'un point", "if p.used + p.points > p.cap then return false end", "if p.used + p.points > p.cap + 1 then return false end" },
  { "plafond sans les points du robot", "if p.used + p.points > p.cap then return false end", "if p.used > p.cap then return false end" },
  { "maintenir N ignoré", "if p.keep ~= nil and p.have >= p.keep then return false end", "" },
  { "maintenir N d'une unité de trop", "if p.keep ~= nil and p.have >= p.keep then return false end", "if p.keep ~= nil and p.have > p.keep then return false end" },
  { "points non ajoutés", "l.used[force] = l.used[force] + points", "l.used[force] = l.used[force] + 0" },
  { "points non rendus", "l.used[u.force] = l.used[u.force] - u.points", "l.used[u.force] = l.used[u.force] - 0" },
  { "double ajout accepté", "if l.units[unit_number] then return false end\n  l.units[unit_number] = { force = force", "l.units[unit_number] = { force = force" },
  { "retrait non idempotent", "  local u = l.units[unit_number]\n  if not u then return nil end", "  local u = l.units[unit_number] or { force = 'player', id = 'steam-trotter', points = 1 }" },
  { "liste non triée", "while i >= 1 and list[i] > v do i = i - 1 end", "" },
  { "effectif non tenu", "l.by_id[force][id] = (l.by_id[force][id] or 0) + 1", "" },
  { "balayage sans retrait", "      M.remove(l, un)\n", "" },
  { "file sans effectif", "if (have[q.id] or 0) < q.n then return q.id end", "if q.n > 0 then return q.id end" },
  { "file jusqu'à la cible comprise", "if (have[q.id] or 0) < q.n then return q.id end", "if (have[q.id] or 0) <= q.n then return q.id end" },
  { "file inconnue acceptée", "if not known[q.id] then return false end", "" },
  { "sortie au nord", "return { x = pos.x, y = pos.y + size / 2 + 2 }", "return { x = pos.x, y = pos.y - size / 2 - 2 }" },
  { "ralliement sur la sortie", "return { x = o.x, y = o.y + Ro.RALLY_DEPTH }", "return { x = o.x, y = o.y }" },
  { "point non fini accepté", "return x == x and y == y and math.abs(x) < 1e7 and math.abs(y) < 1e7", "return true" },
  { "ordre inconnu accepté", "if k == kind then return true end", "return true" },
}
-- mutants des données
local RO_MUTANTS = {
  { "petit robot à 2 points", "P = 1, M = 2", "P = 2, M = 2" },
  { "base du plafond à 13", "Ro.CAP_BASE = 12", "Ro.CAP_BASE = 13" },
  { "pas du plafond à 5", "Ro.CAP_PER_AGE = 6", "Ro.CAP_PER_AGE = 5" },
  { "PV changés", "hp = 900,", "hp = 800," },
  { "cadence changée", "shot = { damage = 50, cooldown = 30 }", "shot = { damage = 50, cooldown = 20 }" },
  { "coût en acier changé", '{ "steel-plate", 22 }', '{ "steel-plate", 30 }' },
  { "ingrédient au-delà de 100", '{ "engine-unit", 10 }, { "steel-plate", 22 }', '{ "engine-unit", 10 }, { "steel-plate", 220 }' },
  { "premier robot à l'âge 7", "id = \"steam-trotter\", age = 3", "id = \"steam-trotter\", age = 7" },
  { "propriétaire manquant", '{ "player", "scarlet", "azure", "emerald", "amber" }', '{ "player", "scarlet", "azure", "emerald" }' },
  { "propriétaires dans un autre ordre", '{ "player", "scarlet", "azure", "emerald", "amber" }', '{ "player", "azure", "scarlet", "emerald", "amber" }' },
  { "nom d'unité changé", 'return Ro.PREFIX .. owner .. "-" .. id', 'return Ro.PREFIX .. id .. "-" .. owner' },
}
local refused, kept = 0, {}
local function try(label, ro_src, mo_src)
  local Ro, Mo = load_all(ro_src, mo_src)
  local f2 = 1
  if Ro then
    local ok, _, ff = pcall(suite, Ro, Mo)
    f2 = ok and ff or 1
  end
  if f2 > 0 then refused = refused + 1 else kept[#kept + 1] = label end
end
for _, m in ipairs(MUTANTS) do
  local a, b = MO_SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else
    try(m[1], RO_SRC, MO_SRC:sub(1, a - 1) .. m[3] .. MO_SRC:sub(b + 1))
  end
end
for _, m in ipairs(RO_MUTANTS) do
  local a, b = RO_SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else
    try(m[1], RO_SRC:sub(1, a - 1) .. m[3] .. RO_SRC:sub(b + 1), MO_SRC)
  end
end
if #kept == 0 then pass = pass + 1 else
  fail = fail + 1
  msgs[#msgs + 1] = "§8 mutants NON refusés : " .. table.concat(kept, " ; ")
end

for _, m in ipairs(msgs) do print("[ROBOTS] ECHEC " .. m) end
print(string.format("[ROBOTS] mutants refusés : %d sur %d", refused, #MUTANTS + #RO_MUTANTS))
print(string.format("[ROBOTS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
