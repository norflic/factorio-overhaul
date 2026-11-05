--[[
  Lot DESIGN-MODULES (5/11) : banc hors jeu des MODULES DES GÉANTS (shared/robots/experimentaux_modules.lua, prototypes et script).
  Lua 5.2, depuis la racine du mod :
      lua5.2 tests/experimentaux_modules_test.lua
    §1 données : 2 types, 3 paliers aux âges 10, 12, 14 (âges des géants qui les ouvrent), usines de robots de l'âge, technologies de
       géant prérequises, bonus croissants, plafonds, emplacements de CHAQUE géant de Xp.GEANTS et de lui seul ;
    §2 coûts : au plus 100 de chaque ingrédient, aucun en double, aucun plus tardif que l'âge du palier, MU à ± 25 % du dixième du géant
       de l'âge (même fonction de MU que tests/experimentaux_test.lua) ;
    §3 règle : bonus nul, somme, plafond, noms inconnus ignorés, ordre de lecture indifférent, portée et coup effectifs, bonus maximal,
       cible au-delà de la portée de base, garniture des factions ;
    §4 prototypes : prototypes/experimentaux_modules.lua joué sur une étape data simulée (grilles posées sur les 5 géants, catégorie
       propre, équipement 2 × 2 sans capacité, objet, recette à l'usine de l'âge, technologie, images présentes aux bonnes dimensions) ;
    §5 forme des fichiers : aucun pairs, `global` jamais nommé, aucun require dans une fonction (F24), couleurs translucides prémultipliées ;
    §6 traductions : chaque clé citée en FR et en EN, mêmes clés des deux côtés ;
    §7 icônes : MANIFEST.json et icons.lua d'accord, chaque PNG présent, dimensions lues dans l'en-tête ;
    §8 mutants de la règle et des données : tous refusés.
]]

package.path = "./?.lua;" .. package.path

local X = require("shared.content.epochs")
local Lv = require("shared.levels.config")
local Cp = require("shared.content.compute")
local Pt = require("shared.content.robot_parts")
local Ro = require("shared.content.robots")
local C = require("shared.content.crafts")
local Xp = require("shared.robots.experimentaux")

local function read(p)
  local f = assert(io.open(p, "rb"), "lecture impossible : " .. p)
  local s = f:read("*a")
  f:close()
  return s
end

local SRC = read("shared/robots/experimentaux_modules.lua")
local PROTO_SRC = read("prototypes/experimentaux_modules.lua")
local SCRIPT_SRC = read("script/robots/experimentaux_modules.lua")

-- MU d'un objet : même fonction que tests/experimentaux_test.lua
local value = {}
for _, c in ipairs(X.currencies) do value[c.item] = c.value end
for e = 2, 12 do local m = Lv.epoch_materials[e]; if m then value[m.item] = m.value end end
local memo = {}
local function mu_of(item)
  if memo[item] then return memo[item] end
  local v
  if Pt.present(item) then
    local rr = Pt.recipe(item)
    local s = 0
    for _, g in ipairs(rr.ingredients) do s = s + mu_of(g[1]) * g[2] end
    v = s / rr.results[1][2]
  elseif value[item] then v = value[item]
  elseif Ro.MU_ASSUMED[item] then v = Ro.MU_ASSUMED[item]
  else v = Cp.mu(item) end
  memo[item] = v
  return v
end

-- Âge des ingrédients : la table de tests/experimentaux_test.lua (page du graphe du 4/11). Absent = refusé.
local INGREDIENT_AGE = {
  ["copper-cable"] = 1, ["electronic-circuit"] = 1, ["fo-methane-barrel"] = 1, ["steel-plate"] = 2, ["engine-unit"] = 3,
  ["advanced-circuit"] = 4, ["plastic-bar"] = 4, battery = 6, ["fo-controller"] = 7, ["fo-optical-sensor"] = 7, ["fo-titanium-composite"] = 8,
  ["fo-resonance-crystal"] = 7, ["fo-servo-motor"] = 7, ["fo-lead-plate"] = 9, ["uranium-238"] = 9, ["fo-guidance-core"] = 10,
  ["processing-unit"] = 10, ["low-density-structure"] = 10, ["fo-graphics-card"] = 11, ["fo-titanium-plate"] = 11, ["fo-laser-module"] = 12,
  ["fo-magnetic-actuator"] = 12, ["fo-superconducting-coil"] = 12,
}

--- Toutes les permutations d'une petite liste (ordre de lecture de la grille).
local function permutations(list)
  local out = {}
  local function rec(prefix, rest)
    if #rest == 0 then out[#out + 1] = prefix return end
    for i = 1, #rest do
      local p, r = {}, {}
      for _, v in ipairs(prefix) do p[#p + 1] = v end
      p[#p + 1] = rest[i]
      for j, v in ipairs(rest) do if j ~= i then r[#r + 1] = v end end
      rec(p, r)
    end
  end
  rec({}, list)
  return out
end

--- La suite de la règle et des données : rend (ok, échecs, messages). `M` : le module (réel ou mutant).
local function suite(M)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = m end end

  -- §1 données
  check(#M.TYPES == 2 and M.TYPES[1].id == "portee" and M.TYPES[1].stat == "range" and M.TYPES[2].id == "puissance"
    and M.TYPES[2].stat == "shot", "§1 deux types : portée (range), puissance (shot)")
  check(M.type("portee").cap == 50 and M.type("puissance").cap == 100, "§1 plafonds : portée +50 %, puissance +100 %")
  local want_tiers = { { 1, 10, "fo-robot-dock", "cairn" }, { 2, 12, "fo-robot-dock", "trombe" }, { 3, 14, "fo-robot-gantry", "tournesol" } }
  check(#M.TIERS == 3, "§1 trois paliers")
  for i, w in ipairs(want_tiers) do
    local t = M.TIERS[i]
    local g = Xp.robot(w[4])
    check(t and t.tier == w[1] and t.age == w[2] and t.factory == w[3] and t.after == Xp.tech_name(w[4]),
      "§1 palier " .. w[1] .. " : âge " .. w[2] .. ", usine " .. w[3] .. ", après la technologie du " .. w[4])
    check(g and g.is_giant and t and g.age == t.age and t.ref_mu == g.mu, "§1 palier " .. w[1] .. " : géant de son âge, MU de référence = le sien")
    local f = t and Ro.factory(t.factory)
    check(f and f.age <= t.age, "§1 palier " .. w[1] .. " : son usine existe et arrive avant lui")
    -- l'usine la plus tardive admise à l'âge du palier
    local best
    for _, ff in ipairs(Ro.FACTORIES) do if t and ff.age <= t.age and (not best or ff.age > best.age) then best = ff end end
    check(best and t and best.name == t.factory, "§1 palier " .. w[1] .. " : usine la plus tardive de son âge")
  end
  local want_bonus = { portee = { 10, 15, 25 }, puissance = { 15, 30, 50 } }
  check(#M.MODULES == 6, "§1 six modules")
  for _, m in ipairs(M.MODULES) do
    local wb = want_bonus[m.type]
    check(wb and wb[m.tier] == m.bonus, "§1 " .. tostring(m.name) .. " : bonus " .. tostring(wb and wb[m.tier]))
    check(m.name == M.name(m.type, m.tier) and m.recipe == M.recipe_name(m.type, m.tier) and m.tech == M.tech_name(m.type, m.tier),
      "§1 " .. tostring(m.name) .. " : noms")
    check(M.of_name(m.name) == m, "§1 " .. tostring(m.name) .. " : retrouvé par son nom")
    local t = M.tier(m.tier)
    check(t and m.age == t.age and m.factory == t.factory and m.prerequisites[1] == t.after, "§1 " .. tostring(m.name) .. " : âge, usine, prérequis du palier")
    if m.tier > 1 then
      check(m.prerequisites[2] == M.tech_name(m.type, m.tier - 1) and #m.prerequisites == 2, "§1 " .. m.name .. " : après le palier précédent du même type")
    else
      check(#m.prerequisites == 1, "§1 " .. m.name .. " : palier I après le seul géant")
    end
  end
  check(M.of_name("speed-module") == nil and M.of_name(nil) == nil and M.of_name("fo-xp-module-portee-4") == nil, "§1 nom étranger : nil")
  for _, tid in ipairs({ "portee", "puissance" }) do
    local prev = 0
    for k = 1, 3 do
      local m = M.of_name(M.name(tid, k))
      check(m and m.bonus > prev, "§1 " .. tid .. " : bonus croissant au palier " .. k)
      prev = m and m.bonus or prev
    end
  end
  local want_slots = { cairn = 2, stylet = 2, trombe = 3, ixion = 3, tournesol = 4 }
  check(#M.SLOTS == #Xp.GEANTS, "§1 un nombre d'emplacements par géant, pas plus")
  for _, g in ipairs(Xp.GEANTS) do
    check(M.slots(g.id) == want_slots[g.id], "§1 " .. g.id .. " : " .. tostring(want_slots[g.id]) .. " emplacements")
    local w, h = M.grid_size(g.id)
    check(w == 2 * want_slots[g.id] and h == 2, "§1 " .. g.id .. " : grille " .. 2 * want_slots[g.id] .. " x 2")
  end
  check(M.slots("bourdon") == 0, "§1 pas de grille hors des géants expérimentaux")
  -- grand géant, plus d'emplacements (non décroissant dans l'ordre des âges)
  local prev_age, prev_s = 0, 0
  for _, g in ipairs(Xp.GEANTS) do
    check(g.age >= prev_age and M.slots(g.id) >= prev_s, "§1 " .. g.id .. " : pas moins d'emplacements qu'un géant plus ancien")
    prev_age, prev_s = g.age, M.slots(g.id)
  end

  -- §2 coûts
  for _, m in ipairs(M.MODULES) do
    local seen, mu, ok100, late = {}, 0, true, {}
    for _, g in ipairs(m.ingredients) do
      if g[2] > 100 or g[2] < 1 then ok100 = false end
      check(not seen[g[1]], "§2 " .. m.name .. " : " .. g[1] .. " une seule fois")
      seen[g[1]] = true
      local a = INGREDIENT_AGE[g[1]]
      if not a or a > m.age then late[#late + 1] = g[1] .. " (" .. tostring(a) .. ")" end
      local okm, v = pcall(mu_of, g[1])
      check(okm and type(v) == "number" and v > 0, "§2 " .. m.name .. " : MU connue pour " .. g[1])
      mu = mu + (okm and v or 0) * g[2]
    end
    check(ok100, "§2 " .. m.name .. " : au plus 100 de chaque ingrédient")
    check(#late == 0, "§2 " .. m.name .. " : aucun ingrédient plus tardif que l'âge " .. m.age .. " : " .. table.concat(late, ", "))
    local target = M.COST_SHARE * M.tier(m.tier).ref_mu
    check(math.abs(mu - target) <= 0.25 * target, string.format("§2 %s : %.0f MU pour une cible de %.0f (± 25 %%)", m.name, mu, target))
  end
  check(M.COST_SHARE == 0.1 and M.TIME == 30, "§2 un dixième du géant de l'âge, 30 s")

  -- §3 règle
  local z = M.bonus({})
  check(z.portee == 0 and z.puissance == 0 and M.ZERO.portee == 0 and M.ZERO.puissance == 0, "§3 grille vide : bonus nul")
  check(M.bonus(nil).portee == 0, "§3 sans liste : bonus nul")
  local b1 = M.bonus({ M.name("portee", 1) })
  check(b1.portee == 10 and b1.puissance == 0, "§3 un module de portée I : +10 %, puissance 0")
  local b2 = M.bonus({ M.name("puissance", 2), M.name("portee", 1), M.name("puissance", 1) })
  check(b2.puissance == 45 and b2.portee == 10, "§3 somme par type : puissance 30 + 15, portée 10")
  local b3 = M.bonus({ M.name("portee", 3), M.name("portee", 3), M.name("portee", 3), M.name("portee", 3) })
  check(b3.portee == 50 and b3.brut.portee == 100, "§3 plafond de portée : 4 × 25 = 100 ramené à 50")
  local b4 = M.bonus({ M.name("puissance", 3), M.name("puissance", 3), M.name("puissance", 3) })
  check(b4.puissance == 100 and b4.brut.puissance == 150, "§3 plafond de puissance : 3 × 50 = 150 ramené à 100")
  local b5 = M.bonus({ "energy-shield-equipment", "fo-xp-module-portee-9", M.name("puissance", 1), "exoskeleton-equipment" })
  check(b5.puissance == 15 and b5.portee == 0, "§3 équipements étrangers ignorés")
  local same = true
  local liste = { M.name("portee", 2), M.name("puissance", 3), M.name("portee", 1), M.name("puissance", 1) }
  local ref = M.bonus(liste)
  for _, p in ipairs(permutations(liste)) do
    local b = M.bonus(p)
    if b.portee ~= ref.portee or b.puissance ~= ref.puissance then same = false end
  end
  check(same and ref.portee == 25 and ref.puissance == 65, "§3 ordre de lecture indifférent (24 permutations)")
  local cairn, tournesol = Xp.robot("cairn"), Xp.robot("tournesol")
  check(M.range(cairn, M.ZERO) == cairn.range and M.shot(cairn, M.ZERO) == cairn.shot and M.range(cairn) == cairn.range,
    "§3 sans module : portée et coup de base")
  check(math.abs(M.range(cairn, { portee = 50, puissance = 0 }) - 60) < 1e-9, "§3 Cairn : 40 × 1,5 = 60 tuiles")
  check(math.abs(M.range(tournesol, { portee = 50, puissance = 0 }) - 90) < 1e-9, "§3 Tournesol : 60 × 1,5 = 90 tuiles")
  check(math.abs(M.shot(cairn, { portee = 0, puissance = 100 }) - 2 * cairn.shot) < 1e-6, "§3 Cairn : coup doublé à +100 %")
  check(math.abs(M.apply(200, 15) - 230) < 1e-9 and M.apply(7, nil) == 7, "§3 apply : base × (100 + p) / 100")
  local mx = M.max_bonus("tournesol", 14)
  check(mx.portee == 50 and mx.puissance == 100, "§3 Tournesol à l'âge 14 : plafonds atteints")
  local mc = M.max_bonus("cairn", 10)
  check(mc.portee == 20 and mc.puissance == 30, "§3 Cairn à l'âge 10 : 2 × palier I")
  local mc12 = M.max_bonus("cairn", 12)
  check(mc12.portee == 30 and mc12.puissance == 60, "§3 Cairn à l'âge 12 : 2 × palier II")
  -- propriété : chaque plafond est atteint EXACTEMENT par deux modules du meilleur palier (aucun point perdu)
  for _, t in ipairs(M.TYPES) do
    local best = 0
    for _, m in ipairs(M.MODULES) do if m.type == t.id and m.bonus > best then best = m.bonus end end
    check(2 * best == t.cap, "§3 " .. t.id .. " : plafond = 2 × le palier III (" .. 2 * best .. " contre " .. t.cap .. ")")
  end
  check(M.beyond_base(cairn, 40.5) and not M.beyond_base(cairn, 40) and not M.beyond_base(cairn, 12), "§3 au-delà de la portée de base seulement")
  local lt = M.loadout("tournesol", 14)
  check(#lt == 4 and lt[1] == M.name("puissance", 3) and lt[2] == M.name("puissance", 3) and lt[3] == M.name("portee", 3)
    and lt[4] == M.name("portee", 3), "§3 garniture du Tournesol à 14 : 2 puissance III, 2 portée III")
  local lc = M.loadout("cairn", 10)
  check(#lc == 2 and lc[1] == M.name("puissance", 1) and lc[2] == M.name("puissance", 1), "§3 garniture du Cairn à 10 : 2 puissance I")
  check(#M.loadout("cairn", 9) == 0 and #M.loadout("inconnu", 15) == 0, "§3 garniture vide avant l'âge 10 ou sans grille")
  local lx = M.loadout("trombe", 12)
  check(#lx == 3 and lx[1] == M.name("puissance", 2) and lx[3] == M.name("puissance", 2), "§3 garniture de la Trombe à 12 : 3 puissance II (90 < 100)")

  return pass, fail, msgs
end

local pass, fail, msgs = suite(require("shared.robots.experimentaux_modules"))
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = m end end
local Mod = require("shared.robots.experimentaux_modules")

-- §4 prototypes : étape data simulée
local function png_size(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local h = f:read(24)
  f:close()
  if not h or #h < 24 or h:sub(2, 4) ~= "PNG" then return nil end
  local function u32(s, i) local a, b, c, d = s:byte(i, i + 3) return ((a * 256 + b) * 256 + c) * 256 + d end
  return u32(h, 17), u32(h, 21)
end
local function mod_path(fn) return (fn:gsub("^__factorio%-overhaul__/", "")) end

local extended = {}
local raw = { ["spider-vehicle"] = {} }
for _, g in ipairs(Xp.GEANTS) do raw["spider-vehicle"][g.name] = { type = "spider-vehicle", name = g.name } end
_G.data = { raw = raw, extend = function(_, list) for _, p in ipairs(list) do extended[#extended + 1] = p end end }
package.preload["__factorio-overhaul__/graphics/modules-geants/icons"] = function() return dofile("graphics/modules-geants/icons.lua") end
package.preload["__factorio-overhaul__/graphics/robots/experimentaux/sprites"] = function() return dofile("graphics/robots/experimentaux/sprites.lua") end
local SPRX = dofile("graphics/robots/experimentaux/sprites.lua")
local okp, errp = pcall(dofile, "prototypes/experimentaux_modules.lua")
check(okp, "§4 étape data simulée sans erreur : " .. tostring(errp))
local by = {}
for _, p in ipairs(extended) do
  by[p.type] = by[p.type] or {}
  check(by[p.type][p.name] == nil, "§4 " .. p.type .. "/" .. tostring(p.name) .. " déclaré une fois")
  by[p.type][p.name] = p
end
local function get(t, n) return by[t] and by[t][n] end
check(get("equipment-category", Mod.CATEGORY) ~= nil, "§4 catégorie d'équipement " .. Mod.CATEGORY)
check(get("item-subgroup", Mod.SUBGROUP) ~= nil, "§4 sous-groupe " .. Mod.SUBGROUP)
for _, g in ipairs(Xp.GEANTS) do
  local gr = get("equipment-grid", Mod.grid_name(g.id))
  local w = Mod.grid_size(g.id)
  check(gr and gr.width == w and gr.height == 2 and #gr.equipment_categories == 1 and gr.equipment_categories[1] == Mod.CATEGORY,
    "§4 grille de " .. g.id .. " : " .. w .. " x 2, notre seule catégorie")
  check(raw["spider-vehicle"][g.name].equipment_grid == Mod.grid_name(g.id), "§4 " .. g.id .. " porte sa grille")
end
local KEYS = {}
for _, m in ipairs(Mod.MODULES) do
  local eq = get("battery-equipment", m.name)
  check(eq ~= nil, "§4 équipement " .. m.name)
  if eq then
    check(eq.shape.width == 2 and eq.shape.height == 2 and eq.shape.type == "full", "§4 " .. m.name .. " : 2 × 2 cases pleines")
    check(#eq.categories == 1 and eq.categories[1] == Mod.CATEGORY, "§4 " .. m.name .. " : seulement dans la grille d'un géant")
    check(eq.energy_source.type == "electric" and eq.energy_source.buffer_capacity == nil, "§4 " .. m.name .. " : sans capacité (ne fait rien seul)")
    check(eq.take_result == m.name, "§4 " .. m.name .. " : rend son objet")
    local s = eq.sprite
    local w1, h1 = png_size(mod_path(s.filename))
    local w2, h2 = png_size(mod_path(s.hr_version.filename))
    check(w1 == s.width and h1 == s.height and w1 == 64 and w2 == s.hr_version.width and h2 == s.hr_version.height and w2 == 128
      and s.hr_version.scale == 0.5, "§4 " .. m.name .. " : image de la grille 64 px et hr 128 px (scale 0,5) présentes")
    check(eq.background_color and eq.background_color.a and eq.background_border_color, "§4 " .. m.name .. " : fond de case à la couleur du type")
    KEYS[#KEYS + 1] = eq.localised_name[1]
    KEYS[#KEYS + 1] = eq.localised_description[1]
    check(type(eq.localised_description[2]) == "string" and type(eq.localised_description[3]) == "string", "§4 " .. m.name .. " : paramètres en chaînes (F43)")
  end
  local it = get("item", m.name)
  check(it and it.placed_as_equipment_result == m.name and it.subgroup == Mod.SUBGROUP, "§4 objet " .. m.name .. " posé comme équipement")
  if it then
    local w, h = png_size(mod_path(it.icons[1].icon))
    check(w == 120 and h == 64 and it.icons[1].icon_size == 64 and it.icons[1].icon_mipmaps == 4, "§4 " .. m.name .. " : icône 64 px + 3 mipmaps")
  end
  local rc = get("recipe", m.recipe)
  local f = Ro.factory(m.factory)
  check(rc and f and rc.category == f.category and rc.enabled == false and rc.energy_required == Mod.TIME and rc.results[1].name == m.name,
    "§4 recette " .. m.recipe .. " à l'usine de l'âge (" .. tostring(f and f.category) .. ")")
  if rc then check(#rc.ingredients == #m.ingredients, "§4 " .. m.recipe .. " : ingrédients des données") end
  local tc = get("technology", m.tech)
  check(tc ~= nil, "§4 technologie " .. m.tech)
  if tc then
    check(#tc.effects == 1 and tc.effects[1].type == "unlock-recipe" and tc.effects[1].recipe == m.recipe, "§4 " .. m.tech .. " : ouvre sa recette")
    check(#tc.prerequisites == #m.prerequisites and tc.prerequisites[1] == m.prerequisites[1], "§4 " .. m.tech .. " : prérequis")
    local packs = C.packs(m.age)
    check(#tc.unit.ingredients == #packs, "§4 " .. m.tech .. " : packs de l'âge " .. m.age)
    local giant = Xp.robot(Mod.tier(m.tier).after:sub(#Xp.PREFIX + 1))
    check(tc.unit.count == Xp.tech_units(C.tech_count(Ro.tech(giant.after))), "§4 " .. m.tech .. " : autant d'unités que la technologie du " .. giant.id)
    local gi = SPRX.corps[giant.id].icone
    check(#tc.icons == 2 and tc.icons[1].icon == gi.filename and tc.icons[1].icon_size == gi.size,
      "§4 " .. m.tech .. " : icône = le " .. giant.id .. " (couche 1)")
    local w, h = png_size(mod_path(tc.icons[2].icon))
    check(w == 480 and h == 256 and tc.icons[2].scale == 0.5 and tc.icons[2].shift[1] == 64 and tc.icons[2].shift[2] == 64,
      "§4 " .. m.tech .. " : module en surimpression, quart bas droit (256 px + 3 mipmaps)")
    KEYS[#KEYS + 1] = tc.localised_name[1]
    KEYS[#KEYS + 1] = tc.localised_description[1]
  end
end
-- prérequis : géants déclarés par le lot EXPERIMENTAUX ou modules de ce lot
for _, m in ipairs(Mod.MODULES) do
  for _, p in ipairs(m.prerequisites) do
    local okp2 = get("technology", p) ~= nil
    if not okp2 then for _, g in ipairs(Xp.GEANTS) do if g.tech == p then okp2 = true end end end
    check(okp2, "§4 " .. m.tech .. " : prérequis connu " .. p)
  end
end

-- §5 forme des fichiers
local function no_require_in_function(src)
  local depth = 0
  for line in src:gmatch("[^\n]*") do
    local code = line:gsub("%-%-.*$", "")
    if depth > 0 and code:find("require%s*%(") then return false end
    for _ in code:gmatch("%f[%w]function%f[%W]") do depth = depth + 1 end
    for _ in code:gmatch("%f[%w]do%f[%W]") do depth = depth + 1 end
    for _ in code:gmatch("%f[%w]then%f[%W]") do depth = depth + 1 end
    for _ in code:gmatch("%f[%w]repeat%f[%W]") do depth = depth + 1 end
    for _ in code:gmatch("%f[%w]end%f[%W]") do depth = depth - 1 end
    for _ in code:gmatch("%f[%w]elseif%f[%W]") do depth = depth - 1 end
    for _ in code:gmatch("%f[%w]until%f[%W]") do depth = depth - 1 end
  end
  return true
end
for _, it in ipairs({ { "shared/robots/experimentaux_modules.lua", SRC }, { "script/robots/experimentaux_modules.lua", SCRIPT_SRC },
  { "prototypes/experimentaux_modules.lua", PROTO_SRC } }) do
  local p, src = it[1], it[2]
  local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find("[^i]pairs%("), "§5 " .. p .. " : aucun pairs")
  check(not code:find("%f[%w]global%f[%W]"), "§5 " .. p .. " : `global` jamais nommé")
  check(no_require_in_function(src), "§5 " .. p .. " : aucun require dans une fonction (F24)")
end
do
  local brut = {}
  for line in SCRIPT_SRC:gmatch("[^\n]*") do
    local code = line:gsub("%-%-.*$", "")
    if code:find("{[^}]*%f[%w]a%s*=%s*0?%.%d") then brut[#brut + 1] = code:match("^%s*(.-)%s*$"):sub(1, 60) end
  end
  check(#brut == 0, "§5 script : aucune couleur translucide littérale (non prémultipliée) : " .. table.concat(brut, " | "))
  check(SCRIPT_SRC:find("for _, eq in ipairs(grid.equipment) do", 1, true) ~= nil, "§5 script : la grille est lue en LISTE (equipment), pas en dictionnaire")
  check(not SCRIPT_SRC:find("get_contents", 1, true), "§5 script : get_contents (dictionnaire) jamais lu")
  local code_script = SCRIPT_SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not code_script:find("storage", 1, true) and not code_script:find("K.S()", 1, true), "§5 script : aucun état gardé (ni storage ni K.S())")
end

-- §5 bis script joué sur un moteur simulé (rendering, grille) : bonus, portée et coup effectifs, marques visibles aux bons moments
do
  local appels = {}
  local function enregistre(kind) return function(t) appels[#appels + 1] = { kind = kind, t = t } return #appels end end
  _G.rendering = { draw_line = enregistre("line"), draw_circle = enregistre("circle"), draw_light = enregistre("light"),
    draw_sprite = enregistre("sprite") }
  _G.defines = { events = { on_player_placed_equipment = 1, on_player_removed_equipment = 2 } }
  local abonnes = {}
  package.preload["script.core.events"] = function() return { on = function(ev, f) abonnes[#abonnes + 1] = { ev = ev, f = f } end } end
  local okx, XM = pcall(dofile, "script/robots/experimentaux_modules.lua")
  check(okx and type(XM) == "table", "§5 bis script chargé hors jeu : " .. tostring(not okx and XM or ""))
  check(#abonnes == 2 and abonnes[1].ev == 1 and abonnes[2].ev == 2, "§5 bis texte au joueur : pose et retrait d'équipement")
  if okx then
    local cairn = Xp.robot("cairn")
    local function geant(noms_eq)
      local eqs = {}
      for _, n in ipairs(noms_eq) do eqs[#eqs + 1] = { name = n } end
      return { valid = true, position = { x = 0, y = 0 }, surface = {}, grid = { equipment = eqs } }
    end
    local sans = { valid = true, position = { x = 0, y = 0 }, surface = {} }
    check(XM.bonus(sans).portee == 0 and XM.bonus(sans).puissance == 0, "§5 bis géant sans grille : bonus nul")
    local g2 = geant({ Mod.name("portee", 3), Mod.name("puissance", 2), "energy-shield-equipment" })
    local st = XM.stats(g2, cairn)
    check(math.abs(st.range - 50) < 1e-9 and math.abs(st.shot - cairn.shot * 1.3) < 1e-6 and st.bonus.portee == 25,
      "§5 bis Cairn avec portée III et puissance II : 50 tuiles, coup × 1,3")
    -- visée : seulement si la portée en plus sert, sur la POSITION relevée avant le coup
    appels = {}
    check(XM.visee(g2, cairn, st.bonus, { x = 30, y = 0 }) == false and #appels == 0, "§5 bis visée : rien dans la portée de base")
    check(XM.visee(geant({}), cairn, Mod.ZERO, { x = 45, y = 0 }) == false and #appels == 0, "§5 bis visée : rien sans module de portée")
    check(XM.visee(g2, cairn, st.bonus, { x = 45, y = 0 }) == true, "§5 bis visée : cible à 45 tuiles, au-delà des 40 de base")
    local ligne, cercle = nil, nil
    for _, a in ipairs(appels) do
      if a.kind == "line" and a.t.dash_length then ligne = a.t end
      if a.kind == "circle" then cercle = a.t end
    end
    check(ligne and ligne.gap_length and ligne.time_to_live >= 60 and cercle and cercle.time_to_live >= 60,
      "§5 bis visée : trait en tirets et cercle de verrouillage, au moins 60 ticks")
    -- impact : à chaque point touché, visible de jour (cercle au sol), et de nuit (lumière)
    appels = {}
    check(XM.impact(g2, Mod.ZERO, { x = 3, y = 4 }) == false and #appels == 0, "§5 bis impact : rien sans module de puissance")
    check(XM.impact(g2, st.bonus, { x = 3, y = 4 }) == true, "§5 bis impact : coup renforcé")
    local sol, lum = nil, nil
    for _, a in ipairs(appels) do
      if a.kind == "circle" and a.t.filled and a.t.draw_on_ground then sol = a.t end
      if a.kind == "light" then lum = a.t end
    end
    check(sol and sol.time_to_live >= 60 and sol.target[1] == 3 and sol.target[2] == 4 and lum ~= nil,
      "§5 bis impact : brûlure au sol (de jour) et lumière")
    appels = {}
    check(XM.aura(g2, st.bonus) == true and #appels >= 1 and appels[1].kind == "circle" and appels[1].t.time_to_live >= 60,
      "§5 bis aura : halo au sol sous le géant, au moins 60 ticks")
    local gp = geant({ Mod.name("portee", 1) })
    check(XM.aura(gp, XM.bonus(gp)) == false, "§5 bis aura : rien sans puissance")
    -- couleurs prémultipliées : chaque composante au plus alpha
    local premul = true
    appels = {}
    XM.visee(g2, cairn, st.bonus, { x = 45, y = 0 })
    XM.impact(g2, st.bonus, { x = 1, y = 1 })
    XM.aura(g2, st.bonus)
    for _, a in ipairs(appels) do
      local c = a.t.color
      if c and c.a and (c.r > c.a + 1e-9 or c.g > c.a + 1e-9 or c.b > c.a + 1e-9) then premul = false end
    end
    check(premul, "§5 bis couleurs du rendering prémultipliées")
    check(XM.TTL_VISEE >= 60 and XM.TTL_IMPACT >= 60 and XM.TTL_AURA >= 60, "§5 bis durées d'au moins 60 ticks (tirs toutes les 30 à 300)")
  end
end

--- Contrat du branchement dans script/robots/experimentaux_geants.lua (lot EXPERIMENTAUX) : actif dès que ce fichier charge le nôtre.
local function contrat(src)
  local ok_, ko = 0, {}
  local function c(cond, m) if cond then ok_ = ok_ + 1 else ko[#ko + 1] = m end end
  c(src:find('require("script.robots.experimentaux_modules")', 1, true) ~= nil, "charge script/robots/experimentaux_modules")
  c(src:find("max_distance = eff.range", 1, true) ~= nil and not src:find("max_distance = r.range", 1, true), "cherche la cible à la portée effective")
  c(not src:find("Xp.split(r.shot", 1, true) and not src:find("K.hit(r, target, r.shot", 1, true), "aucun coup lu sans le bonus")
  local n_hit, n_imp = 0, 0
  for _ in src:gmatch("K%.hit%(") do n_hit = n_hit + 1 end
  for _ in src:gmatch("K%.blast%(") do n_hit = n_hit + 1 end
  for _ in src:gmatch("XM%.impact%(") do n_imp = n_imp + 1 end
  c(n_hit > 0 and n_imp == n_hit, "une marque d'impact par point de dégâts (" .. n_imp .. " pour " .. n_hit .. ")")
  c(src:find("XM.visee(e, r, eff.bonus, tp)", 1, true) ~= nil, "visée sur la position relevée avant le coup")
  c(src:find("rendre_modules(player, e)\n    rendre(player, e, name)", 1, true) ~= nil, "un géant refusé au plafond rend ses modules")
  return ok_, ko
end
do
  local geants_src = read("script/robots/experimentaux_geants.lua")
  if geants_src:find('require("script.robots.experimentaux_modules")', 1, true) then
    local _, ko = contrat(geants_src)
    check(#ko == 0, "§9 branchement : " .. table.concat(ko, " ; "))
  else
    print("[XP-MODULES] branchement dans experimentaux_geants.lua : ABSENT (attendu avant intégration ; contrôle §9 en attente)")
  end
  if arg and arg[1] == "--contrat" and arg[2] then
    local okc, ko = contrat(read(arg[2]))
    print(string.format("[XP-MODULES] contrat de %s : %d OK, %d ECHEC(S)%s", arg[2], okc, #ko, #ko > 0 and (" : " .. table.concat(ko, " ; ")) or ""))
    check(#ko == 0, "§9 contrat du fichier donné : " .. table.concat(ko, " ; "))
  end
end

-- §6 traductions
local function cfg(p)
  local t, sec = {}, ""
  for line in read(p):gmatch("[^\r\n]+") do
    local s = line:match("^%[([%w%-_]+)%]$")
    if s then sec = s else
      local k, v = line:match("^([%w%-_]+)=(.*)$")
      if k then t[sec .. "." .. k] = v end
    end
  end
  return t
end
local FR, EN = cfg("locale/fr/experimentaux_modules.cfg"), cfg("locale/en/experimentaux_modules.cfg")
KEYS[#KEYS + 1] = "item-subgroup-name." .. Mod.SUBGROUP
KEYS[#KEYS + 1] = "fo-xp-modules.bilan"
check(SCRIPT_SRC:find('"fo-xp-modules.bilan"', 1, true) ~= nil, "§6 le script cite fo-xp-modules.bilan")
for _, k in ipairs(KEYS) do check(FR[k] ~= nil and EN[k] ~= nil and FR[k] ~= "" and EN[k] ~= "", "§6 clé en FR et EN : " .. k) end
local samek = true
for k in pairs(FR) do if not EN[k] then samek = false end end -- comparaison d'ensembles : l'ordre ne compte pas
for k in pairs(EN) do if not FR[k] then samek = false end end
check(samek, "§6 FR et EN : mêmes clés")
for _, m in ipairs(Mod.MODULES) do
  local d = FR["item-description." .. m.name] or ""
  check(d:find("__1__", 1, true) and d:find("__2__", 1, true), "§6 " .. m.name .. " : description chiffrée (bonus, plafond)")
end

-- §7 icônes : icons.lua et MANIFEST d'accord, fichiers présents
local ICONS = dofile("graphics/modules-geants/icons.lua")
local MAN = read("graphics/modules-geants/MANIFEST.json")
for _, m in ipairs(Mod.MODULES) do
  check(ICONS.objets[m.name] and ICONS.equipements[m.name] and ICONS.technos[m.tech], "§7 " .. m.name .. " : objet, équipement, technologie dans icons.lua")
  check(MAN:find('"' .. m.name .. '"', 1, true) and MAN:find('"' .. m.tech .. '"', 1, true), "§7 " .. m.name .. " : dans MANIFEST.json")
  check(ICONS.objets[m.name] and ICONS.objets[m.name].age == m.age and ICONS.objets[m.name].palier == m.tier, "§7 " .. m.name .. " : âge et palier de l'icône")
end
check(ICONS.version == 1, "§7 version de l'outil")

-- §8 mutants
local MUTANTS = {
  { "plafond de portée oublié", "out[t.id] = math.min(brut[t.id], t.cap)", "out[t.id] = brut[t.id]" },
  { "plafond de portée à 60", '{ id = "portee", stat = "range", cap = 50 }', '{ id = "portee", stat = "range", cap = 60 }' },
  { "un seul module compte", "brut[m.type] = brut[m.type] + m.bonus", "brut[m.type] = m.bonus" },
  { "étranger compté", "if m then brut[m.type] = brut[m.type] + m.bonus end", "if m then brut[m.type] = brut[m.type] + m.bonus else brut.portee = brut.portee + 1 end" },
  { "bonus additif au lieu de multiplicatif", "return base * (100 + (pct or 0)) / 100", "return base + (pct or 0)" },
  { "portée lue dans la puissance", "return M.apply(r.range, (b or M.ZERO).portee)", "return M.apply(r.range, (b or M.ZERO).puissance)" },
  { "puissance III à +60", '{ type = "puissance", tier = 3, bonus = 50,', '{ type = "puissance", tier = 3, bonus = 60,' },
  { "portée I à l'âge 9", "{ tier = 1, age = 10, factory", "{ tier = 1, age = 9, factory" },
  { "palier III au Dock", '{ tier = 3, age = 14, factory = "fo-robot-gantry"', '{ tier = 3, age = 14, factory = "fo-robot-dock"' },
  { "palier II sans le palier I", "if m.tier > 1 then m.prerequisites[2] = M.tech_name(m.type, m.tier - 1) end", "" },
  { "Tournesol à 3 emplacements", '{ id = "tournesol", slots = 4 }', '{ id = "tournesol", slots = 3 }' },
  { "module de 1 case", "M.SIDE = 2 ", "M.SIDE = 1 " },
  { "ingrédient au-delà de 100", '{ "fo-optical-sensor", 100 }, { "fo-guidance-core", 20 }', '{ "fo-optical-sensor", 101 }, { "fo-guidance-core", 20 }' },
  { "palier I avec une pièce de l'âge 12", '{ "battery", 100 }, { "fo-servo-motor", 30 }', '{ "fo-laser-module", 10 }, { "fo-servo-motor", 30 }' },
  { "palier III bradé", '{ "fo-superconducting-coil", 100 }, { "fo-magnetic-actuator", 100 }, { "fo-laser-module", 100 }',
    '{ "fo-superconducting-coil", 10 }, { "fo-magnetic-actuator", 10 }, { "fo-laser-module", 10 }' },
  { "cible au-delà comptée au bord", "return d > r.range", "return d >= r.range" },
  { "garniture qui dépasse le plafond", "while #out < n and sum < cap do", "while #out < n do" },
  { "garniture portée d'abord", 'local order = { "puissance", "portee" }', 'local order = { "portee", "puissance" }' },
  { "garniture d'un palier futur", "if m.type == tid and m.age <= (age or 0) and", "if m.type == tid and" },
  { "bonus maximal sans plafond", "out[t.id] = math.min(best * n, t.cap)", "out[t.id] = best * n" },
}
local refused, kept = 0, {}
for _, mu in ipairs(MUTANTS) do
  local a, b = SRC:find(mu[2], 1, true)
  if not a then kept[#kept + 1] = mu[1] .. " (motif absent)" else
    local src = SRC:sub(1, a - 1) .. mu[3] .. SRC:sub(b + 1)
    local f = load(src, "=mutant", "t")
    local f2 = 1
    if f then
      local ok, M = pcall(f)
      if ok and type(M) == "table" then
        local ok2, _, ff = pcall(suite, M)
        f2 = ok2 and ff or 1
      end
    end
    if f2 > 0 then refused = refused + 1 else kept[#kept + 1] = mu[1] end
  end
end
check(#kept == 0, "§8 mutants NON refusés : " .. table.concat(kept, " ; "))

for _, m in ipairs(msgs) do print("[XP-MODULES] ECHEC " .. m) end
print(string.format("[XP-MODULES] mutants refusés : %d sur %d", refused, #MUTANTS))
print(string.format("[XP-MODULES] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
