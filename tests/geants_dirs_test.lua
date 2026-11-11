--[[
  Lot ART-GEANTS (11/11, F525) : corps ORIENTÉ des géants expérimentaux (interdit du DC : aucune unité qui glisse sans s'orienter).
  Lua 5.2, depuis la racine du mod :
      lua5.2 tests/geants_dirs_test.lua
    §1 règle pure : Xp.pose (Ixion : 16 directions de marche, 8 poses, direction d -> pose d mod 8 ; secteur le plus proche ; nil pour un
       géant à une seule image), Xp.sprite_corps (suffixe -dNN), couches ombre, corps, lueur-1 ; chaque géant de Xp.CORPS_DIRS est un géant ;
    §2 DONNÉES CHANGÉES : la même règle sur une table de directions changée (Cairn à 8 poses, Ixion retiré) : aucun nom en dur ;
    §3 feuilles (D-6) : ixion_dirs.lua (directions et poses = Xp.CORPS_DIRS), chaque PNG présent, en-tête PNG = table, cité par
       MANIFEST-ixion-dirs.json ; budget : au plus 80 Mpx de feuilles HR pour Ixion (corps, lueur, ombre de toutes les poses) ;
    §4 prototype : le torse des géants tourne (vitesse du torse de l'araignée vanilla lue dans data.raw, comme les titans F507) ; chaque
       pose déclarée comme sprite par Xp.sprite_corps ;
    §5 script : la pose se lit dans le TORSE (torso_orientation), jamais dans LuaEntity.orientation (toujours 0 en marche, F507) ; elle
       change par rendering.set_sprite au balayage ; partie d'avant F525 : sprites d'une image retirés puis corps reposé ; pas de trigonométrie ;
    §6 mutants : chaque règle a un mutant, tous refusés.
]]

package.path = "./?.lua;" .. package.path

local Xp = require("shared.robots.experimentaux")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[GEANTS-DIRS] ECHEC : " .. msg) end
end

local function read(p)
  local f = assert(io.open(p, "rb"), "lecture impossible : " .. p)
  local s = f:read("*a")
  f:close()
  return s
end

local PROTO = read("prototypes/experimentaux_geants.lua")
local SCR = read("script/robots/experimentaux_geants.lua")

--- Les règles, jugées sur un module X (Xp ou un mutant) et sur les sources du prototype et du script. Rend la liste des échecs (vide : tout tient).
local function juge(X, proto, scr)
  local ko = {}
  local function c(cond, msg) if not cond then ko[#ko + 1] = msg end end
  if type(X.pose) ~= "function" or type(X.sprite_corps) ~= "function" or type(X.CORPS_DIRS) ~= "table" then
    return { "§1 Xp.pose, Xp.sprite_corps et Xp.CORPS_DIRS existent" }
  end
  -- §1 Ixion : 16 directions, 8 poses ; pose = direction mod 8 (la roue est la même à 180° près)
  local d = X.CORPS_DIRS.ixion
  c(d and d.directions == 16 and d.poses == 8, "§1 Ixion : 16 directions de marche servies par 8 poses")
  if d then
    local tout = true
    for k = 0, d.directions - 1 do
      if X.pose("ixion", k / d.directions) ~= k % d.poses then tout = false end
    end
    c(tout, "§1 chaque direction de marche k/16 donne la pose k mod 8")
  end
  c(X.pose("ixion", 0.03) == 0 and X.pose("ixion", 0.032) == 1 and X.pose("ixion", 0.97) == 0 and X.pose("ixion", 0.94) == 7,
    "§1 secteur le plus proche (0,03 -> 0 ; 0,032 -> 1 ; 0,97 -> 0 ; 0,94 -> 7)")
  c(X.pose("ixion", 0.25) == 4 and X.pose("ixion", 0.75) == 4 and X.pose("ixion", 0.5) == 0, "§1 marche opposée, même pose (est et ouest, nord et sud)")
  c(X.pose("ixion", 1.0) == 0 and X.pose("ixion", nil) == 0, "§1 orientation 1 = 0 ; orientation absente = nord")
  for _, id in ipairs({ "cairn", "stylet", "trombe", "tournesol" }) do
    c(X.pose(id, 0.3) == nil and X.sprite_corps(id, "corps", X.pose(id, 0.3)) == X.PREFIX .. id .. "-corps", "§1 " .. id .. " : une seule image (pose nil, sprite d'origine)")
  end
  c(X.sprite_corps("ixion", "corps", 3) == X.PREFIX .. "ixion-corps-d03" and X.sprite_corps("ixion", "lueur-1", 7) == X.PREFIX .. "ixion-lueur-1-d07"
    and X.sprite_corps("ixion", "ombre", 0) == X.PREFIX .. "ixion-ombre-d00", "§1 noms des poses : <préfixe><id>-<couche>-dNN")
  c(X.sprite_corps("ixion", "corps", nil) == X.PREFIX .. "ixion-corps", "§1 sans pose : le sprite d'une image")
  c(("fo-xp-ixion-corps-d05"):match("%-corps%-d(%d+)$") == "05", "§1 le banc geants-marche relit la pose dans le nom")
  c(type(X.CORPS_COUCHES) == "table" and #X.CORPS_COUCHES == 3 and X.CORPS_COUCHES[1] == "ombre" and X.CORPS_COUCHES[2] == "corps"
    and X.CORPS_COUCHES[3] == "lueur-1", "§1 trois couches, l'ombre dessous")
  local ids = {}
  for _, g in ipairs(X.GEANTS) do ids[g.id] = true end
  local seuls = true
  for _, g in ipairs(X.GEANTS) do
    local cd = X.CORPS_DIRS[g.id]
    if cd and not (cd.poses >= 1 and cd.directions >= cd.poses and cd.directions % cd.poses == 0) then seuls = false end
  end
  c(seuls and X.CORPS_DIRS.ixion ~= nil and ids.ixion, "§1 Xp.CORPS_DIRS : géants existants, poses qui divisent les directions")
  -- §4 prototype : torse libéré, poses déclarées
  c(proto:find("torso_rotation_speed = ARAIGNEE.torso_rotation_speed", 1, true) ~= nil and proto:find('data.raw["spider-vehicle"]["spidertron"]', 1, true) ~= nil
    and not proto:find("torso_rotation_speed = 0[,%s]"), "§4 prototype : le torse des géants tourne (vitesse du torse de l'araignée vanilla)")
  c(proto:find('Xp.sprite_corps(r.id, "corps", k - 1)', 1, true) ~= nil and proto:find('Xp.sprite_corps(r.id, "lueur-1", k - 1)', 1, true) ~= nil
    and proto:find('Xp.sprite_corps(r.id, "ombre", k - 1)', 1, true) ~= nil and proto:find("Xp.CORPS_DIRS[r.id]", 1, true) ~= nil,
    "§4 prototype : une pose par sprite (corps, lueur, ombre), pour chaque géant de Xp.CORPS_DIRS")
  -- §5 script : torse, set_sprite, migration, aucune trigonométrie
  c(scr:find("Xp.pose(r.id, e.torso_orientation)", 1, true) ~= nil and not scr:find("e%.orientation%f[^%w_]"),
    "§5 script : la pose se lit dans le torse (F507), jamais dans LuaEntity.orientation")
  c(scr:find("rendering.set_sprite(id, Xp.sprite_corps(r.id, c, pose))", 1, true) ~= nil and scr:find("if pose == g.pose then return end", 1, true) ~= nil,
    "§5 script : la pose change par rendering.set_sprite, seulement quand elle change")
  c(scr:find("Xp.CORPS_DIRS[g.id] then orienter(g, Xp.robot(g.id))", 1, true) ~= nil, "§5 script : le balayage oriente chaque géant au corps orienté")
  c(scr:find("if not g.rid then", 1, true) ~= nil and scr:find("rendering.destroy(id)", 1, true) ~= nil and scr:find("nom == Xp.sprite_corps(r.id, c)", 1, true) ~= nil,
    "§5 script : partie d'avant F525, sprites d'une image retirés puis corps reposé")
  c(not scr:find("math%.atan") and not scr:find("math%.sin") and not scr:find("math%.cos"), "§5 script : aucune trigonométrie")
  return ko
end

-- §1, §4, §5 sur le vrai module et les vraies sources
local ko = juge(Xp, PROTO, SCR)
for _, m in ipairs(ko) do check(false, m) end
check(#ko == 0, "§1-§5 toutes les règles tiennent (" .. #ko .. " échec(s))")

-- §2 DONNÉES CHANGÉES : la règle lit Xp.CORPS_DIRS (aucun nom en dur)
if type(Xp.pose) == "function" then
  local orig = Xp.CORPS_DIRS
  Xp.CORPS_DIRS = { cairn = { directions = 8, poses = 8 } }
  check(Xp.pose("cairn", 0.125) == 1 and Xp.pose("cairn", 0.6) == 5 and Xp.pose("ixion", 0.3) == nil,
    "§2 données changées : Cairn à 8 poses (0,125 -> 1 ; 0,6 -> 5), Ixion à une image")
  Xp.CORPS_DIRS = { ixion = { directions = 32, poses = 16 } }
  check(Xp.pose("ixion", 17 / 32) == 1 and Xp.pose("ixion", 15 / 32) == 15, "§2 données changées : Ixion à 32 directions et 16 poses")
  Xp.CORPS_DIRS = orig
else
  check(false, "§2 Xp.pose absente")
end

-- §3 feuilles (D-6)
local function png_size(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local h = f:read(24)
  f:close()
  if not h or #h < 24 or h:sub(1, 8) ~= string.char(137, 80, 78, 71, 13, 10, 26, 10) then return nil end
  local function u32(s, i) local a, b, cc, dd = s:byte(i, i + 3); return ((a * 256 + b) * 256 + cc) * 256 + dd end
  return u32(h, 17), u32(h, 21)
end
local DIR = "graphics/robots/experimentaux/"
local okd, D = pcall(dofile, DIR .. "ixion_dirs.lua")
check(okd and type(D) == "table", "§3 ixion_dirs.lua lisible (sinon : py -3.9 tools/render/pieces/experimentaux/feuilles_ixion_dirs.py)")
if okd and type(D) == "table" and type(Xp.CORPS_DIRS) == "table" and Xp.CORPS_DIRS.ixion then
  local cd = Xp.CORPS_DIRS.ixion
  check(D.directions == cd.directions and #D.poses == cd.poses, "§3 ixion_dirs.lua : directions et poses = Xp.CORPS_DIRS.ixion")
  local man = {}
  local okm, txt = pcall(read, DIR .. "MANIFEST-ixion-dirs.json")
  if okm then for n in txt:gmatch('"([%w%-_%.]+%.png)"') do man[n] = true end end
  local mpx, n_png, mauvais = 0, 0, {}
  for k, p in ipairs(D.poses) do
    check(#(p.lueurs or {}) == 1, "§3 pose " .. (k - 1) .. " : une lueur (couche additive fondue)")
    for _, l in ipairs({ p.main, p.lueurs and p.lueurs[1], p.ombre }) do
      for _, r in ipairs({ l.hr, l.lr }) do
        local f = r.filename:gsub("^__factorio%-overhaul__/", "")
        local w, h = png_size(f)
        n_png = n_png + 1
        if not (w == r.width and h == r.height) then mauvais[#mauvais + 1] = f end
        if not man[f:match("[^/]+$")] then mauvais[#mauvais + 1] = "absent du MANIFEST : " .. f end
        if r == l.hr and w and h then mpx = mpx + w * h / 1e6 end
      end
    end
  end
  check(n_png == 6 * cd.poses and #mauvais == 0, "§3 chaque PNG présent, en-tête = table, cité par le MANIFEST (" .. n_png .. " fichiers ; " .. table.concat(mauvais, ", ") .. ")")
  check(mpx > 0 and mpx <= 80, string.format("§3 budget : %.1f Mpx de feuilles HR pour Ixion (au plus 80)", mpx))
  print(string.format("[GEANTS-DIRS] Ixion : %d poses, %.1f Mpx HR", #D.poses, mpx))
end

-- §6 mutants : chaque règle a un mutant, tous refusés
local function mut(champs) return setmetatable(champs, { __index = Xp }) end
local MUTANTS = {
  { "pose sans arrondi au plus proche", mut({ pose = function(id, o)
    local d = Xp.CORPS_DIRS[id]; if not d then return nil end
    return math.floor((o or 0) * d.directions) % d.directions % d.poses end }) },
  { "pose = direction (sans le mod 8 de la roue)", mut({ pose = function(id, o)
    local d = Xp.CORPS_DIRS[id]; if not d then return nil end
    return math.floor((o or 0) * d.directions + 0.5) % d.directions end }) },
  { "pose sur 8 secteurs (16 directions perdues)", mut({ pose = function(id, o)
    local d = Xp.CORPS_DIRS[id]; if not d then return nil end
    return math.floor((o or 0) * d.poses + 0.5) % d.poses end }) },
  { "tous les géants orientés", mut({ pose = function(_, o) return math.floor((o or 0) * 16 + 0.5) % 16 % 8 end }) },
  { "Ixion à une image", mut({ CORPS_DIRS = {} }) },
  { "suffixe sans zéro de tête", mut({ sprite_corps = function(id, couche, pose) return Xp.PREFIX .. id .. "-" .. couche .. (pose and ("-d" .. pose) or "") end }) },
  { "couches dans le désordre", mut({ CORPS_COUCHES = { "corps", "ombre", "lueur-1" } }) },
}
if type(Xp.pose) == "function" then
  for _, m in ipairs(MUTANTS) do
    check(#juge(m[2], PROTO, SCR) > 0, "§6 mutant refusé : " .. m[1])
  end
end
local SOURCES = {
  { "torse figé (torso_rotation_speed = 0)", PROTO:gsub("torso_rotation_speed = ARAIGNEE%.torso_rotation_speed", "torso_rotation_speed = 0"), SCR },
  { "poses non déclarées", PROTO:gsub('Xp%.sprite_corps%(r%.id, "corps", k %- 1%)', 'Xp.PREFIX .. r.id .. "-corps"'), SCR },
  { "pose lue dans LuaEntity.orientation", PROTO, SCR:gsub("Xp%.pose%(r%.id, e%.torso_orientation%)", "Xp.pose(r.id, e.orientation)") },
  { "corps jamais retourné (pas de set_sprite)", PROTO, SCR:gsub("rendering%.set_sprite%(id, Xp%.sprite_corps%(r%.id, c, pose%)%)", "local _ = id") },
  { "balayage sans orientation", PROTO, SCR:gsub("then orienter%(g, Xp%.robot%(g%.id%)%)", "then local _ = g") },
  { "partie ancienne : sprites d'une image laissés", PROTO, SCR:gsub("rendering%.destroy%(id%)", "local _ = id") },
}
for _, m in ipairs(SOURCES) do
  check(m[2] ~= PROTO or m[3] ~= SCR, "§6 mutant appliqué : " .. m[1])
  check(#juge(Xp, m[2], m[3]) > 0, "§6 mutant refusé : " .. m[1])
end

print(string.format("[GEANTS-DIRS] %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
