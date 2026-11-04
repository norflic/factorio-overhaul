--[[
  Lot DA-ATELIERS (phase 3) : feuilles des bâtiments d'atelier hors de git (décision D-6), graphics/machines/ateliers.
    lua5.2 tests/ateliers_feuilles_test.lua            (depuis la racine du mod ; Lua pur, environ 1 s)
  §1 Manifeste : chaque PNG de MANIFEST.json existe, à sa TAILLE et à ses DIMENSIONS (en-tête PNG).
  §2 sprites.lua : chaque image nommée est au manifeste, à ses dimensions ; normale = moitié (arrondie au-dessus) de la HR ;
     aucune image au-delà de 8 192 px (F144) ; shifts sur la grille de 1/64 de tuile (la version normale tombe au pixel).
  §3 Branchement : chaque prototype de prototypes/ateliers_visuels.lua (PIECE) a sa pièce dans sprites.lua, avec principale,
     ombre et icône ; une machine à fluide a ses 4 tronçons de raccord (_tuyau_n, _e, _s, _o).
  §4 Mutants : le contrôle REFUSE un manifeste faussé (taille, dimensions, fichier absent) et un sprites.lua faussé.
  Un worktree neuf n'a pas les PNG : le test le dit et imprime la commande de feuilles.py.
]]

local Images = dofile("tests/datastage/images.lua")
local Gun = dofile("tests/datastage/gun_sheets.lua")

local DIR = "graphics/machines/ateliers"
local REGEN = "py -3.9 tools/render/pieces/ateliers/feuilles.py   (sources : fo-logs/2026-11-04_DA-ATELIERS/final, à GARDER)"
local ok_n, fail_n = 0, 0
local function check(c, m)
  if c then ok_n = ok_n + 1 print("[ATELIERS] OK     " .. m) else fail_n = fail_n + 1 print("[ATELIERS] ECHEC  " .. m) end
end

local function read_all(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function file_size(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local n = f:seek("end")
  f:close()
  return n
end

local function base(fn) return (fn:match("([^/]+)$")) end
local function sorted_keys(t)
  local k = {}
  for x in pairs(t) do k[#k + 1] = x end
  table.sort(k)
  return k
end

--- Contrôle complet ; manifeste et sprites peuvent être donnés (mutants). Rend la liste des écarts.
local function controle(manifest_text, spr)
  local e = {}
  local list, why = Gun.parse(manifest_text or "")
  if not list then return { "manifeste illisible : " .. tostring(why) } end
  if #list == 0 then return { "manifeste vide" } end
  local dims = {}
  for _, f in ipairs(list) do
    dims[f.nom] = { f.largeur, f.hauteur }
    local p = DIR .. "/" .. f.nom
    local sz = file_size(p)
    if not sz then
      e[#e + 1] = "absent : " .. f.nom
    else
      local w, h = Images.png_size(p)
      if sz ~= f.taille or w ~= f.largeur or h ~= f.hauteur then
        e[#e + 1] = string.format("%s : %d octets %sx%s, manifeste %d octets %dx%d", f.nom, sz, tostring(w), tostring(h), f.taille, f.largeur, f.hauteur)
      end
    end
  end
  if type(spr) ~= "table" or type(spr.pieces) ~= "table" then return { "sprites.lua sans table pieces" } end
  for _, nom in ipairs(sorted_keys(spr.pieces)) do
    local p = spr.pieces[nom]
    for _, k in ipairs({ "main", "shadow", "glow", "light" }) do
      local c = p[k]
      if c then
        for _, q in ipairs({ "hr", "lr" }) do
          local d = dims[base(c[q].filename)]
          if not d then
            e[#e + 1] = string.format("%s %s %s : %s absent du manifeste", nom, k, q, base(c[q].filename))
          elseif d[1] ~= c[q].width or d[2] ~= c[q].height then
            e[#e + 1] = string.format("%s %s %s : %dx%d au manifeste, %dx%d dans sprites.lua", nom, k, q, d[1], d[2], c[q].width, c[q].height)
          end
          if c[q].width > 8192 or c[q].height > 8192 then e[#e + 1] = nom .. " " .. k .. " dépasse 8 192 px (F144)" end
        end
        if c.lr.width ~= math.ceil(c.hr.width / 2) or c.lr.height ~= math.ceil(c.hr.height / 2) then
          e[#e + 1] = string.format("%s %s : normale %dx%d, attendu la moitié de %dx%d", nom, k, c.lr.width, c.lr.height, c.hr.width, c.hr.height)
        end
        for i = 1, 2 do
          local s64 = c.hr.shift[i] * 64
          if math.abs(s64 - math.floor(s64 + 0.5)) > 1e-6 then e[#e + 1] = string.format("%s %s : shift %.6f hors de la grille de 1/64", nom, k, c.hr.shift[i]) end
        end
      end
    end
    if p.icone then
      local d = dims[base(p.icone.filename)]
      if not d or d[1] ~= 120 or d[2] ~= 64 then e[#e + 1] = nom .. " : icône absente ou pas en 64 px à 4 mipmaps (120 × 64)" end
    end
  end
  return e
end

local man = read_all(DIR .. "/MANIFEST.json")
local oks, spr = pcall(dofile, DIR .. "/sprites.lua")
if not man or not oks then
  check(false, "feuilles présentes (" .. DIR .. ") : " .. (man and tostring(spr) or "MANIFEST.json absent") .. " ; à régénérer : " .. REGEN)
else
  -- §1 et §2
  local e = controle(man, spr)
  check(#e == 0, string.format("§1-§2 manifeste, sprites.lua, moitiés, F144, grille de 1/64 (%d écart(s))%s", #e, #e > 0 and (" : " .. table.concat(e, " ; ", 1, math.min(#e, 6))) or ""))
  -- §3 branchement
  local src = read_all("prototypes/ateliers_visuels.lua") or ""
  local mapping = src:match("local PIECE = (%b{})") or ""
  local n, bons, defaut = 0, 0, {}
  for proto, nom in mapping:gmatch('%["([%w%-]+)"%]%s*=%s*"([%w_]+)"') do
    local p = spr.pieces[nom]
    if p then
      n = n + 1
      local ok = p.main and p.shadow and p.icone
      if proto == "fo-flare-stack" or proto == "fo-coil-winder" or proto == "fo-lapidary" then
        for _, d in ipairs({ "n", "e", "s", "o" }) do ok = ok and spr.pieces[nom .. "_tuyau_" .. d] ~= nil end
      end
      if ok then bons = bons + 1 else defaut[#defaut + 1] = proto end
    end
  end
  check(n >= 1 and bons == n, string.format("§3 prototypes habillés : %d sur %d avec principale, ombre, icône (et 4 raccords pour les machines à fluide)%s",
    bons, n, #defaut > 0 and (" ; incomplets : " .. table.concat(defaut, ", ")) or ""))
  -- §4 mutants
  local first = Gun.parse(man)[1]
  local m1 = man:gsub('"taille": ' .. first.taille, '"taille": ' .. (first.taille + 1), 1)
  check(#controle(m1, spr) > 0, "§4 mutant refusé : taille d'un PNG faussée au manifeste")
  local m2 = man:gsub('"largeur": ' .. first.largeur, '"largeur": ' .. (first.largeur + 2), 1)
  check(#controle(m2, spr) > 0, "§4 mutant refusé : largeur d'un PNG faussée au manifeste")
  local m3 = man:gsub(first.nom:gsub("%p", "%%%0"), "absent-" .. first.nom, 1)
  check(#controle(m3, spr) > 0, "§4 mutant refusé : fichier absent")
  local spr2 = dofile(DIR .. "/sprites.lua")
  local k1 = sorted_keys(spr2.pieces)[1]
  spr2.pieces[k1].main.hr.shift[1] = spr2.pieces[k1].main.hr.shift[1] + 0.003
  check(#controle(man, spr2) > 0, "§4 mutant refusé : shift hors de la grille de 1/64")
  local spr3 = dofile(DIR .. "/sprites.lua")
  spr3.pieces[k1].main.lr.width = spr3.pieces[k1].main.lr.width + 1
  check(#controle(man, spr3) > 0, "§4 mutant refusé : normale qui n'est pas la moitié de la HR")
end
print(string.format("[ATELIERS] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
