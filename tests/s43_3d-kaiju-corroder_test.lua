-- s43 3d-kaiju-corroder : refonte 3D du Kaiju cristallin et de l'Écorcheur (pilier D).
-- Vérifie hors jeu : (1) feuilles du Kaiju et de l'Écorcheur dans sprites.lua (8 directions, course 8 / attaque 4, lueur et ombre à
-- demi-densité du corps, feuilles ≤ 4 096 px) ; (2) le modèle du Kaiju est titanesque (hauteur englobante ≥ 15 tuiles) et ses cristaux
-- ont un noyau émissif ; (3) l'Écorcheur a sa palette propre (muscle, os ivoire) et plus d'anneaux flottants.
-- Lancer depuis la racine du mod : lua5.2 tests/s43_3d-kaiju-corroder_test.lua
local ok_n, ko_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 else ko_n = ko_n + 1; print("ÉCHEC : " .. msg) end
end
local function read(p)
  local f = assert(io.open(p, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local SPR = dofile("graphics/robots/titans/sprites.lua")
for _, id in ipairs({ "kaiju", "ecorcheur" }) do
  local K = SPR[id]
  check(K and K.directions == 8 and K.course and K.course.images == 8 and K.attaque and K.attaque.images == 4, id .. " : 8 directions, 8 + 4 images")
  if K and K.course then
    for _, anim in ipairs({ "course", "attaque" }) do
      local c = K[anim].couches
      check(math.abs(c.glow.dens * 2 - c.main.dens) < 1e-6 and math.abs(c.shadow.dens * 2 - c.main.dens) < 1e-6,
        id .. " " .. anim .. " : lueur et ombre à demi-densité du corps")
      for _, nomc in ipairs({ "main", "glow", "shadow" }) do
        local x = c[nomc]
        check(#x.hr == 8 and #x.lr == 8 and x.w * x.ll <= 4096 and x.h * x.lpf <= 4096 and x.ll * x.lpf == K[anim].images,
          id .. " " .. anim .. " " .. nomc .. " : 8 fichiers, grille exacte, ≤ 4 096 px")
      end
    end
  end
end

local KA = read("tools/render/pieces/titans/kaiju.py")
local zmax = tonumber(KA:match('"zmax":%s*([%d%.]+)'))
check(zmax and zmax >= 15, "Kaiju : hauteur englobante titanesque (≥ 15 tuiles)")
check(KA:find('M%["noyau"%]') and KA:find("def grappe") and not KA:find("anneau%("), "Kaiju : grappes de cristaux à noyau émissif, sans anneaux flottants")
-- les feuilles rendues suivent le modèle : la hauteur de l'image du corps (px / densité) dépasse 12 tuiles
if SPR.kaiju and SPR.kaiju.course then
  local m = SPR.kaiju.course.couches.main
  check(m.h / m.dens >= 12, "Kaiju : image du corps de plus de 12 tuiles de haut (feuilles refaites)")
end

local EC = read("tools/render/pieces/titans/ecorcheur.py")
check(EC:find("def matieres") and EC:find("muscle") and EC:find("os_ivoire") and EC:find("CAGE THORACIQUE"), "Écorcheur : palette propre et cage thoracique")
check(not EC:find('M%["anneau"%], G%.oriente%(ring'), "Écorcheur : plus d'anneaux flottants à la queue")

print(string.format("s43_3d-kaiju-corroder : %d OK, %d échecs", ok_n, ko_n))
if ko_n > 0 then os.exit(1) end
