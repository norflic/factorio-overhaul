-- s43 3d-leviathan-ravager : les feuilles RE-RENDUES (V3) du Ravageur et du Léviathan articulé gardent le FORMAT que lit le prototype
-- (prototypes/titans.lua, script/robots/titans_serpent.lua) : 16 directions, mêmes animations et mêmes nombres d'images, trois couches
-- par animation (main, glow, shadow), une feuille par direction et par couche, grille exacte (ll × lpf = images), PNG présents.
-- Lancement : lua5.2 tests/s43_3d-leviathan-ravager_test.lua   (depuis la racine du mod ; feuilles hors de git, D-6)
package.path = "./?.lua;" .. package.path

local ok_n, ko_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 else ko_n = ko_n + 1; print("ÉCHEC : " .. msg) end
end

local function existe(chemin)
  local f = io.open((chemin:gsub("^__factorio%-overhaul__/", "")), "rb")
  if f then f:close() return true end
  return false
end

local COUCHES = { "main", "glow", "shadow" }

local function anim_ok(nom, a, images, ndirs)
  check(type(a) == "table", nom .. " : animation présente")
  if type(a) ~= "table" then return end
  check(a.images == images, nom .. " : " .. tostring(a.images) .. " images (attendu " .. images .. ")")
  for _, c in ipairs(COUCHES) do
    local L = a.couches and a.couches[c]
    check(type(L) == "table", nom .. " " .. c .. " : couche présente")
    if type(L) == "table" then
      check(#L.hr == ndirs and #L.lr == ndirs, nom .. " " .. c .. " : une feuille par direction (" .. #L.hr .. ")")
      check(L.ll * L.lpf == images, nom .. " " .. c .. " : grille exacte " .. L.ll .. " × " .. L.lpf)
      check(L.w > 0 and L.h > 0 and type(L.sx) == "number" and type(L.sy) == "number", nom .. " " .. c .. " : taille et décalage")
      local manque = 0
      for k = 1, ndirs do
        if not existe(L.hr[k]) then manque = manque + 1 end
        if not existe(L.lr[k]) then manque = manque + 1 end
      end
      check(manque == 0, nom .. " " .. c .. " : " .. manque .. " PNG absent(s)")
    end
  end
end

-- Ravageur (feuilles_titans.py --seul ravageur)
local okr, SPR = pcall(dofile, "graphics/robots/titans/sprites.lua")
check(okr and type(SPR) == "table" and type(SPR.ravageur) == "table", "sprites.lua des titans lisible, entrée ravageur")
if okr and SPR.ravageur then
  local r = SPR.ravageur
  check(r.anime == true and r.directions == 16, "ravageur : animé, 16 directions")
  for _, st in ipairs({ "1", "2", "3" }) do
    anim_ok("ravageur " .. st .. " course", r[st] and r[st].course, 8, 16)
    anim_ok("ravageur " .. st .. " attaque", r[st] and r[st].attaque, 4, 16)
  end
end

-- Léviathan articulé (feuilles_leviathan.py) : tête animée, segment et queue fixes
local okl, LEV = pcall(dofile, "graphics/robots/titans/leviathan/sprites.lua")
check(okl and type(LEV) == "table", "sprites.lua du Léviathan lisible")
if okl then
  check(LEV.tete and LEV.tete.anime == true and LEV.tete.directions == 16, "léviathan tête : animée, 16 directions")
  for _, st in ipairs({ "1", "2", "3" }) do
    anim_ok("léviathan tête " .. st .. " course", LEV.tete[st] and LEV.tete[st].course, 4, 16)
    anim_ok("léviathan tête " .. st .. " attaque", LEV.tete[st] and LEV.tete[st].attaque, 4, 16)
    for _, p in ipairs({ "segment", "queue" }) do
      check(LEV[p] and LEV[p].directions == 16, "léviathan " .. p .. " : 16 directions")
      anim_ok("léviathan " .. p .. " " .. st, LEV[p] and LEV[p][st] and LEV[p][st].pose, 1, 16)
    end
  end
end

print(string.format("s43_3d-leviathan-ravager_test : %d OK, %d ÉCHEC", ok_n, ko_n))
if ko_n > 0 then os.exit(1) end
