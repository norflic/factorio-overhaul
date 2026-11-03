--[[
  Lot EXPERIMENTAUX (3/11) : banc hors jeu des robots expérimentaux (shared/robots/experimentaux.lua). Lua 5.2, depuis la racine du mod :
      lua5.2 tests/experimentaux_test.lua
    §1 données : les 5 petits de FAISABILITE (âge, rôle, usine de l'âge, technologie de l'époque), ingrédients au plus 100, coût en MU
       à ±20 % (même fonction de MU que tests/robots_test.lua) ;
    §2 valeur pour la valeur : PV, dégâts par seconde, coup, charge = référence × mu / ref.mu (× 3 en PV pour une défense posée) ;
    §3 règles des effets : plus proche, sauts de l'arc, pointes, jets, chute des dégâts, zone, noms ;
    §4 feuilles (D-6) : sprites.lua, chaque PNG présent, dimensions lues dans l'en-tête PNG égales à sprites.lua, au plus 4 096 px ;
       MANIFEST.json cite chaque fichier ;
    §5 forme des fichiers : aucun pairs dans shared/robots/experimentaux.lua, aucun require dans une fonction (F24), `global` jamais nommé ;
    §6 traductions : chaque clé citée par le prototype existe en FR et EN, mêmes clés des deux côtés ;
    §7 mutants : chaque règle a un mutant, tous doivent être refusés.
]]

package.path = "./?.lua;" .. package.path

local X = require("shared.content.epochs")
local Lv = require("shared.levels.config")
local Cp = require("shared.content.compute")
local Pt = require("shared.content.robot_parts")
local Ro = require("shared.content.robots")

local function read(p)
  local f = assert(io.open(p, "rb"), "lecture impossible : " .. p)
  local s = f:read("*a")
  f:close()
  return s
end

local XP_SRC = read("shared/robots/experimentaux.lua")

-- MU d'un objet : même fonction que tests/robots_test.lua (monnaies, matières d'âge, pièces de robots, calcul)
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

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) * math.max(1, math.abs(b)) end

--- La suite : rend (ok, échecs, messages). `Xp` : le module (réel ou mutant).
local function suite(Xp)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = m end end

  -- §1 données
  local want = {
    { "mat-foudre", 6, "turret-electric", "fo-robot-workshop", 1800, 30 },
    { "geode", 7, "unit-capsule", "fo-robotics-bay", 3400, 30 },
    { "sarracenie", 8, "turret", "fo-robotics-bay", 6200, 30 },
    { "demi-vie", 9, "unit-capsule", "fo-robotics-bay", 7500, 20 },
    { "veilleuse", 13, "turret", "fo-robot-gantry", 42000, 10 },
  }
  check(#Xp.ROBOTS == #want, "§1 cinq petits")
  for i, w in ipairs(want) do
    local r = Xp.ROBOTS[i]
    check(r and r.id == w[1] and r.age == w[2] and r.kind == w[3] and r.factory == w[4] and r.mu == w[5] and r.time == w[6],
      "§1 " .. w[1] .. " : âge, rôle, usine, coût et durée de FAISABILITE")
    if r then
      local f = Ro.factory(r.factory)
      check(f and f.age <= r.age, "§1 " .. r.id .. " : son usine existe et arrive avant lui")
      -- l'usine de son âge : la plus récente arrivée à son âge
      local best
      for _, ff in ipairs(Ro.FACTORIES) do if ff.age <= r.age and (not best or ff.age > best.age) then best = ff end end
      check(best and f == best, "§1 " .. r.id .. " : usine de robots de SON âge (la plus récente)")
      check(Xp.category(r) == (f and f.category), "§1 " .. r.id .. " : catégorie de fabrication de l'usine")
      local t = Ro.tech(r.after)
      check(t and t.epoch == r.age, "§1 " .. r.id .. " : technologie de robot d'époque égale à son âge (" .. tostring(r.after) .. ")")
      local ok100, dup, seen = true, false, {}
      for _, g in ipairs(r.ingredients) do
        if g[2] > 100 or g[2] < 1 then ok100 = false end
        if seen[g[1]] then dup = true end
        seen[g[1]] = true
      end
      check(ok100 and not dup, "§1 " .. r.id .. " : ingrédients de 1 à 100, sans doublon")
      local c = 0
      for _, g in ipairs(r.ingredients) do c = c + mu_of(g[1]) * g[2] end
      local ratio = c / r.mu
      check(ratio >= 0.8 and ratio <= 1.2, string.format("§1 %s : coût %.0f MU contre %d (±20 %%)", r.id, c, r.mu))
      check(r.name == "fo-xp-" .. r.id and r.recipe == "fo-xp-make-" .. r.id and r.tech == "fo-xp-" .. r.id, "§1 " .. r.id .. " : noms")
      check(Xp.of_name(r.name) == r and Xp.robot(r.id) == r, "§1 " .. r.id .. " : retrouvé par son nom")
      check((r.kind == "unit-capsule") == r.is_unit, "§1 " .. r.id .. " : unité si et seulement si lancé")
      if r.is_unit then
        check(r.half and r.half <= 1.5 and r.speed and r.speed > 0, "§1 " .. r.id .. " : unité de demi-boîte au plus 1,5 (chemins), vitesse > 0")
      else
        check(r.foot and r.foot >= 3 and r.foot % 1 == 0, "§1 " .. r.id .. " : emprise entière d'au moins 3")
      end
      check(r.range > 0 and r.cooldown > 0, "§1 " .. r.id .. " : portée et cadence")
      check((r.single_use == true) == (r.id == "demi-vie"), "§1 " .. r.id .. " : usage unique pour la seule Demi-Vie")
    end
  end

  -- §2 valeur pour la valeur
  for _, r in ipairs(Xp.ROBOTS) do
    local ref = Ro.robot(r.ref)
    check(ref ~= nil, "§2 " .. r.id .. " : robot de référence " .. tostring(r.ref))
    if ref then
      check(ref.age <= r.age and (ref.dps or 0) > 0, "§2 " .. r.id .. " : référence d'âge au plus égal, qui tire")
      local k = r.mu / ref.mu
      local hp = ref.hp * k * (r.is_unit and 1 or Xp.HP_POSE)
      check(near(r.hp, math.floor(hp + 0.5), 1e-9), string.format("§2 %s : PV %s = %.0f", r.id, tostring(r.hp), hp))
      check(near(r.dps, ref.dps * k, 1e-3), "§2 " .. r.id .. " : dégâts par seconde = référence × coût")
      check(near(r.shot, r.dps * r.cooldown / 60, 1e-3), "§2 " .. r.id .. " : coup = dégâts par seconde × cadence")
      if r.single_use then
        check(near(r.burst, ref.dps * k * Xp.BURST_SECONDS, 1e-3), "§2 " .. r.id .. " : charge = 30 s de dégâts")
      else
        check(r.burst == nil, "§2 " .. r.id .. " : pas de charge hors usage unique")
      end
    end
  end
  check(Xp.HP_POSE == 3 and Xp.BURST_SECONDS == 30, "§2 constantes : défense posée × 3, charge de 30 s")

  -- §3 règles
  local P = function(x, y, id) return { x = x, y = y, id = id } end
  local c3 = { P(3, 0, 7), P(0, 3, 5), P(-3, 0, 9), P(10, 10, 1) }
  check(Xp.nearest(P(0, 0, 0), c3).id == 5, "§3 plus proche : égalité de distance -> plus petit numéro")
  check(Xp.nearest(P(0, 0, 0), c3, 2) == nil, "§3 plus proche : rien au-delà de la distance maximale")
  check(Xp.nearest(P(0, 0, 0), {}) == nil, "§3 plus proche : liste vide")
  local first = P(0, 0, 100)
  local line = { first, P(4, 0, 2), P(8, 0, 3), P(12, 0, 4), P(30, 0, 5) }
  local ch = Xp.chain(first, line, 2, 5)
  check(#ch == 2 and ch[1].id == 2 and ch[2].id == 3, "§3 arc : deux sauts, chacun vers le plus proche du précédent")
  local ch3 = Xp.chain(first, line, 10, 5)
  check(#ch3 == 3 and ch3[3].id == 4, "§3 arc : s'arrête quand plus rien n'est à portée (la 5e cible est à 18)")
  local ids = {}
  local rep = false
  for _, c in ipairs(Xp.chain(first, { first, P(1, 0, 2), P(2, 0, 3) }, 5, 5)) do
    if ids[c.id] or c.id == first.id then rep = true end
    ids[c.id] = true
  end
  check(not rep, "§3 arc : jamais deux fois la même cible, jamais la première")
  check(#Xp.chain(first, { first }, 2, 8) == 0, "§3 arc : aucune autre cible, aucun saut")
  local sp = Xp.spike_points(P(0, 0), P(8, -4), 8)
  check(#sp == 8 and near(sp[8].x, 8) and near(sp[8].y, -4) and near(sp[1].x, 1) and near(sp[1].y, -0.5), "§3 pointes : 8 points, le dernier sur la cible")
  local eq = true
  for i = 2, #sp do
    local dx, dy = sp[i].x - sp[i - 1].x, sp[i].y - sp[i - 1].y
    if not near(dx * dx + dy * dy, 1.25) then eq = false end
  end
  check(eq, "§3 pointes : également espacées")
  local jp = Xp.jet_points(P(0, 0), P(10, 0), 3, 3)
  check(#jp == 3 and near(jp[1].x, 10) and near(jp[1].y, 0), "§3 jets : le premier tombe sur la cible")
  check(jp[2] and jp[3] and near(jp[2].x, 10) and near(jp[3].x, 10) and near(jp[2].y + jp[3].y, 0) and near(math.abs(jp[2].y), 3),
    "§3 jets : deux de part et d'autre, à 3 tuiles, perpendiculaires au tir")
  local jp0 = Xp.jet_points(P(5, 5), P(5, 5), 3, 3)
  check(#jp0 == 3 and near(jp0[2].x, 5) and near(jp0[2].y, 5), "§3 jets : tir à bout portant, pas de division par zéro")
  check(near(Xp.falloff(100, 0, 12, 0.5), 100) and near(Xp.falloff(100, 12, 12, 0.5), 50) and near(Xp.falloff(100, 6, 12, 0.5), 75),
    "§3 chute : 100 au centre, 50 au bord, linéaire")
  check(Xp.falloff(100, 12.01, 12, 0.5) == 0, "§3 chute : rien au-delà du rayon")
  local ir = Xp.in_radius(P(0, 0), { P(2, 0, 9), P(0, 2, 3), P(1, 0, 8), P(5, 5, 1) }, 2)
  check(#ir == 3 and ir[1].c.id == 8 and ir[2].c.id == 3 and ir[3].c.id == 9, "§3 zone : bord compris, triés par distance puis numéro")
  local dv = Xp.robot("demi-vie")
  check(dv and Xp.zone_alive(dv, 100, 100 + dv.contamination.duration - 1) and not Xp.zone_alive(dv, 100, 100 + dv.contamination.duration),
    "§3 zone contaminée : vit exactement sa durée")
  check(dv and near(Xp.contamination_pulse(dv), dv.burst * dv.contamination.share), "§3 zone contaminée : impulsion = charge × part")
  check(Xp.of_launch_effect(Xp.launch_effect("geode")) == Xp.robot("geode") and Xp.of_launch_effect(Xp.launch_effect("veilleuse")) == nil,
    "§3 capsule : effet de lancer d'un attaquant seulement")
  check(Xp.of_name("fo-xp-inconnu") == nil and Xp.of_name("fo-robot-geode") == nil and Xp.of_name(nil) == nil, "§3 nom inconnu : nil")
  local dups = {}
  local uniq = true
  for _, v in ipairs({ Xp.EFFECT.arc, Xp.EFFECT.buisson, Xp.EFFECT.crachat, Xp.EFFECT.jet, Xp.EFFECT.fusion, Xp.EFFECT.goutte, Xp.EFFECT.lance }) do
    if dups[v] then uniq = false end
    dups[v] = true
  end
  check(uniq, "§3 effets script : identifiants distincts")
  return pass, fail, msgs
end

local Xp = require("shared.robots.experimentaux")
local pass, fail, msgs = suite(Xp)
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = m end end

-- §4 feuilles (D-6)
local SPR_PATH = "graphics/robots/experimentaux/sprites.lua"
local okspr, SPR = pcall(dofile, SPR_PATH)
check(okspr and type(SPR) == "table", "§4 sprites.lua lisible (sinon : py -3.9 tools/render/pieces/experimentaux/feuilles_xp.py)")
local function png_size(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local h = f:read(24)
  f:close()
  if not h or #h < 24 or h:sub(2, 4) ~= "PNG" then return nil end
  local function u32(s) local a, b, c, d = s:byte(1, 4) return ((a * 256 + b) * 256 + c) * 256 + d end
  return u32(h:sub(17, 20)), u32(h:sub(21, 24))
end
local MAN = okspr and read("graphics/robots/experimentaux/MANIFEST.json") or ""
local function file_of(fn) return fn:gsub("^__factorio%-overhaul__/", "") end
local nfiles = 0
local function check_img(def, what)
  for _, q in ipairs({ "hr", "lr" }) do
    local d = def[q]
    local p = file_of(d.filename)
    local w, h = png_size(p)
    nfiles = nfiles + 1
    check(w == d.width and h == d.height, "§4 " .. what .. " " .. q .. " : PNG présent, " .. tostring(w) .. " × " .. tostring(h) .. " = sprites.lua")
    check(d.width <= 4096 and d.height <= 4096, "§4 " .. what .. " " .. q .. " : au plus 4 096 px")
    check(MAN:find('"' .. p:match("[^/]+$") .. '"', 1, true) ~= nil, "§4 " .. what .. " " .. q .. " : cité au MANIFEST")
  end
end
if okspr then
  for _, r in ipairs(Xp.ROBOTS) do
    local s = SPR.corps[r.id]
    check(s and s.main and s.ombre and s.icone and #s.lueurs >= 1, "§4 " .. r.id .. " : corps, ombre, icône, au moins une lueur")
    if s then
      check_img(s.main, r.id)
      check_img(s.ombre, r.id .. " ombre")
      for _, g in ipairs(s.lueurs) do check_img(g, r.id .. " lueur " .. tostring(g.nom)) end
      local w, h = png_size(file_of(s.icone.filename))
      check(w == 64 and h == 64, "§4 " .. r.id .. " : icône 64 × 64")
      check(near(s.main.hr.scale * s.px_rendu, 32, 1e-3) and near(s.main.lr.scale, 2), "§4 " .. r.id .. " : échelles 32 / px du rendu et 2 (16 px par tuile)")
    end
  end
  for _, k in ipairs({ "pointe", "pointe-lueur", "eclair", "verre" }) do
    check(SPR.effets[k] ~= nil, "§4 effet " .. k)
    if SPR.effets[k] then check_img(SPR.effets[k], "effet " .. k) end
  end
end

-- §5 forme des fichiers
local SCRIPT = read("script/robots/experimentaux.lua")
local PROTO = read("prototypes/experimentaux.lua")
check(not (XP_SRC:gsub("ipairs%(", "")):find("pairs%("), "§5 shared : aucun pairs")
local function no_require_in_function(src)
  local depth = 0
  for line in src:gmatch("[^\n]*") do
    local code = line:gsub("%-%-.*$", "")
    if depth > 0 and code:find("require%(") then return false end
    for _ in code:gmatch("%f[%w]function%f[%W]") do depth = depth + 1 end
    for _ in code:gmatch("%f[%w]do%f[%W]") do depth = depth + 1 end
    for _ in code:gmatch("%f[%w]then%f[%W]") do depth = depth + 1 end
    for _ in code:gmatch("%f[%w]end%f[%W]") do depth = depth - 1 end
    for _ in code:gmatch("%f[%w]elseif%f[%W]") do depth = depth - 1 end
  end
  return true
end
check(no_require_in_function(SCRIPT), "§5 script : aucun require dans une fonction (F24)")
check(not SCRIPT:find("%f[%w]global%f[%W]%s*[%.%[]") and not XP_SRC:find("%f[%w]global%f[%W]%s*[%.%[]"), "§5 `global` jamais nommé")
local pairs_ok = true
for line in SCRIPT:gmatch("[^\n]*") do
  if line:find("[^i]pairs%(") and not line:find("trié juste après") then pairs_ok = false end
end
check(pairs_ok, "§5 script : un seul pairs, sur game.forces, trié juste après")

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
local FR, EN = cfg("locale/fr/experimentaux.cfg"), cfg("locale/en/experimentaux.cfg")
local keys = {}
for _, r in ipairs(Xp.ROBOTS) do
  for _, k in ipairs({ "entity-name.", "entity-description.", "item-description.", "technology-name.", "technology-description." }) do
    keys[#keys + 1] = k .. r.name
  end
end
-- noms des effets que le prototype nomme par { "entity-name." .. Xp.PREFIX .. "<effet>" } ou { "entity-name." .. f.name }
for rest in PROTO:gmatch('"entity%-name%." %.%. Xp%.PREFIX %.%. "([%w%-_]+)"') do keys[#keys + 1] = "entity-name.fo-xp-" .. rest end
keys[#keys + 1] = "entity-name.fo-xp-demi-vie-fusion"
keys[#keys + 1] = "item-subgroup-name." .. Xp.SUBGROUP
keys[#keys + 1] = "ammo-category-name." .. Xp.AMMO_CATEGORY
for _, k in ipairs(keys) do check(FR[k] ~= nil and EN[k] ~= nil and FR[k] ~= "" and EN[k] ~= "", "§6 clé en FR et EN : " .. k) end
local same = true
for k in pairs(FR) do if not EN[k] then same = false end end -- comparaison d'ensembles : l'ordre ne compte pas
for k in pairs(EN) do if not FR[k] then same = false end end
check(same, "§6 FR et EN : mêmes clés")

-- §7 mutants (chaque règle de shared/robots/experimentaux.lua)
local MUTANTS = {
  { "Mât-Foudre à l'âge 5", 'id = "mat-foudre", src = "mat_foudre", age = 6', 'id = "mat-foudre", src = "mat_foudre", age = 5' },
  { "Géode à l'Atelier", 'kind = "unit-capsule", factory = "fo-robotics-bay", after = "fo-robot-bay"', 'kind = "unit-capsule", factory = "fo-robot-workshop", after = "fo-robot-bay"' },
  { "Veilleuse après une technologie d'un autre âge", 'factory = "fo-robot-gantry", after = "fo-robot-gantry"', 'factory = "fo-robot-gantry", after = "fo-robot-levite"' },
  { "ingrédient au-delà de 100", '{ "battery", 100 }, { "steel-plate", 100 }, { "engine-unit", 60 }', '{ "battery", 101 }, { "steel-plate", 100 }, { "engine-unit", 60 }' },
  { "coût de la Sarracénie divisé", '{ "fo-methane-barrel", 100 }, { "fo-servo-motor", 50 }', '{ "fo-methane-barrel", 10 }, { "fo-servo-motor", 5 }' },
  { "ingrédient en double", '{ "fo-lead-plate", 100 }, { "processing-unit", 40 }', '{ "uranium-238", 100 }, { "processing-unit", 40 }' },
  { "PV sans le facteur des défenses", 'if r.kind ~= "unit-capsule" then hp = hp * Xp.HP_POSE end', '' },
  { "valeur sans le rapport des coûts", "local k = r.mu / ref.mu", "local k = 1" },
  { "coup sans la cadence", "shot = round(dps * r.cooldown / 60, 0.1)", "shot = round(dps, 0.1)" },
  { "plus proche sans départage", "(d == bd and c.id < best.id)", "(d == bd and c.id > best.id)" },
  { "plus proche sans borne", "if d <= lim and", "if" },
  { "arc qui revient sur ses pas", "if not used[c.id] then pool[#pool + 1] = c end", "pool[#pool + 1] = c" },
  { "arc depuis la première cible à chaque saut", "    cur = nx\n", "\n" },
  { "pointes qui s'arrêtent avant la cible", "local t = i / count", "local t = i / (count + 1)" },
  { "jets du même côté", "local side = (#out % 2 == 1) and 1 or -1", "local side = 1" },
  { "chute à l'envers", "return amount * (1 - (1 - edge) * d / radius)", "return amount * (edge + (1 - edge) * d / radius)" },
  { "chute sans bord", "if d > radius then return 0 end", "" },
  { "zone triée sans départage", "return a.c.id < b.c.id", "return a.c.id > b.c.id" },
  { "zone qui dure un tick de trop", "return tick - t0 < r.contamination.duration", "return tick - t0 <= r.contamination.duration" },
  { "capsule de défense acceptée", "return r and r.is_unit and r or nil", "return r" },
  { "Demi-Vie réutilisable", "speed = 0.16, single_use = true,", "speed = 0.16," },
  { "charge de 20 s", "Xp.BURST_SECONDS = 30", "Xp.BURST_SECONDS = 20" },
  { "unité trop large pour les chemins", 'half = 1.2, range = 3', 'half = 2.5, range = 3' },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = XP_SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else
    local src = XP_SRC:sub(1, a - 1) .. m[3] .. XP_SRC:sub(b + 1)
    local f = load(src, "=mutant", "t")
    local f2 = 1
    if f then
      local ok, M = pcall(f)
      if ok and type(M) == "table" then
        local ok2, _, ff = pcall(suite, M)
        f2 = ok2 and ff or 1
      end
    end
    if f2 > 0 then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(#kept == 0, "§7 mutants NON refusés : " .. table.concat(kept, " ; "))

for _, m in ipairs(msgs) do print("[EXPERIMENTAUX] ECHEC " .. m) end
print(string.format("[EXPERIMENTAUX] feuilles relues : %d ; mutants refusés : %d sur %d", nfiles, refused, #MUTANTS))
print(string.format("[EXPERIMENTAUX] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
