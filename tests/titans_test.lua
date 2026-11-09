--[[
  Lot TITANS (9/11) : banc hors jeu des titans (shared/robots/titans.lua). Lua 5.2, depuis la racine du mod :
      lua5.2 tests/titans_test.lua
    §1 règle pure : paliers et ères lus dans shared/levels/config.lua et shared/robots/echelle.lua (bornes, monotonie) ; Juggernaut :
       PV = E2 de l'âge nominal, plaques qui montent, masse qui ralentit, armes cumulatives ; Kaiju : PV × hp_mult, échelle, arme par
       ère, lueur = couleur de l'ère ; vagues : premier Kaiju à la vague 20, un de plus toutes les 20 ; courbes des nids croissantes ;
    §2 DONNÉES CHANGÉES : la même règle sur une config à 18 époques et 2 époques par ère donne 9 ères et 9 paliers (rien en dur) ;
    §3 feuilles (D-6) : sprites.lua, chaque PNG présent, dimensions de l'en-tête PNG = sprites.lua, aucune feuille du Kaiju au-delà de
       2 048 px ; MANIFEST.json cite chaque fichier ;
    §4 traductions : chaque clé citée par les prototypes et le script existe en FR et EN, mêmes clés des deux côtés ;
    §5 forme : aucun pairs dans shared/robots/titans.lua, aucun require dans une fonction, `global` jamais nommé ; noms fo-titan- du
       script déclarés par un prototype ; aucune couleur translucide littérale (prémultiplication, gi1) ;
    §6 vagues : TD.compose sans âge inchangé (aucun Kaiju), avec âge : Kaiju de l'ère de l'âge, déterministe ;
    §7 mutants : chaque règle a un mutant, tous refusés.
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
  local function fichier(name) return (name:gsub("^__factorio%-overhaul__/", "")) end
  local function verifie(what, d, w, h)
    local p = fichier(d)
    local pw, ph = png_size(p)
    check(pw == w and ph == h, "§3 " .. what .. " : PNG présent, " .. tostring(pw) .. " × " .. tostring(ph) .. " = sprites.lua (" .. w .. " × " .. h .. ")")
    check(MAN[p:match("([^/]+)$")] == true, "§3 MANIFEST cite " .. p:match("([^/]+)$"))
  end
  for st = 1, T.STAGES do
    local e = SPR.juggernaut[tostring(st)]
    check(e ~= nil, "§3 Juggernaut : feuille du stade " .. st)
    if e then
      for _, c in ipairs({ e.main, e.ombre, e.lueurs[1] }) do
        verifie("juggernaut " .. st, c.hr.filename, c.hr.width, c.hr.height)
        verifie("juggernaut " .. st, c.lr.filename, c.lr.width, c.lr.height)
      end
      check(#e.lueurs >= 1 and e.icone and e.icone.size == 64, "§3 Juggernaut " .. st .. " : lueur fondue et icône")
    end
  end
  local K = SPR.kaiju
  check(K and K.directions == 8 and K.course and K.course.images == 8 and K.attaque and K.attaque.images == 4, "§3 Kaiju : 8 directions, course 8 images, attaque 4")
  if K and K.course then
    for _, anim in ipairs({ "course", "attaque" }) do
      local a = K[anim]
      for _, nomc in ipairs({ "main", "glow", "shadow" }) do
        local c = a.couches[nomc]
        check(#c.hr == 8 and #c.lr == 8, "§3 Kaiju " .. anim .. " " .. nomc .. " : un fichier par direction")
        check(c.ll * c.lpf >= a.images, "§3 Kaiju " .. anim .. " " .. nomc .. " : la grille tient toutes les images")
        for k = 1, 8 do
          verifie("kaiju " .. anim .. " " .. nomc .. " " .. k, c.hr[k], c.w * c.ll, c.h * c.lpf)
          verifie("kaiju " .. anim .. " " .. nomc .. " " .. k, c.lr[k], c.lw * c.ll, c.lh * c.lpf)
        end
        check(c.w * c.ll <= 2048 and c.h * c.lpf <= 2048, "§3 Kaiju " .. anim .. " " .. nomc .. " : feuille ≤ 2 048 px")
      end
    end
    check(K.icone and K.icone.size == 64 and K.foulee > 0, "§3 Kaiju : icône et foulée")
  end
end

---------------------------------------------------------------------------------------------------
-- §4 traductions
---------------------------------------------------------------------------------------------------
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
local FR, EN = cfg("locale/fr/titans.cfg"), cfg("locale/en/titans.cfg")
local keys = { "entity-name." .. T.JUGGERNAUT.name, "entity-description." .. T.JUGGERNAUT.name, "item-description." .. T.JUGGERNAUT.name,
  "item-name." .. T.JUGGERNAUT.segment_item, "item-description." .. T.JUGGERNAUT.segment_item, "technology-name." .. T.JUGGERNAUT.tech,
  "technology-description." .. T.JUGGERNAUT.tech, "entity-name." .. T.PREFIX .. "canon", "entity-name." .. T.PREFIX .. "griffe",
  "entity-name." .. T.PREFIX .. "impulsion", "entity-description." .. T.PREFIX .. T.KAIJU.id, "fo-titan.plafond", "fo-titan.evolue" }
for p = 1, T.PALIERS do keys[#keys + 1] = "entity-name." .. T.juggernaut_name(p) end
for e = 1, T.ERAS do keys[#keys + 1] = "entity-name." .. T.kaiju_name(e) end
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

print(string.format("[TITANS] %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
