--[[
  Feuilles des bâtiments d'atelier hors de git (décision D-6, lot DA-ATELIERS) : contrôle du MANIFESTE en Lua pur, pour le banc de
  l'étape data (harness.lua, dans un bloc : limite de 200 locales du chunk) et tests/ateliers_feuilles_test.lua.
  Un checkout ou un worktree NEUF n'a pas les PNG de graphics/machines/ateliers : ce contrôle le dit et imprime la commande.

  Contrôle : chaque PNG de MANIFEST.json existe, à sa TAILLE et à ses DIMENSIONS ; chaque image nommée par sprites.lua est au
  manifeste, à ses dimensions ; normale = moitié (arrondie au-dessus) de la HR ; 8 192 px au plus (F144) ; shifts sur la grille de
  1/64 de tuile ; icône en 64 px à 4 mipmaps (120 × 64).
]]

local HERE = (debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./")
local Images = dofile(HERE .. "images.lua")
local Gun = dofile(HERE .. "gun_sheets.lua")

local M = {}

M.DIR = "graphics/machines/ateliers"
M.REGEN = "py -3.9 tools/render/pieces/ateliers/feuilles.py   (depuis la racine du mod ; sources dans fo-logs : "
  .. "2026-11-04_DA-ATELIERS/final, à GARDER)"

local function file_size(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local n = f:seek("end")
  f:close()
  return n
end

local function read_all(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function base(fn) return (fn:match("([^/]+)$")) end

local function sorted_keys(t)
  local k = {}
  for x in pairs(t) do k[#k + 1] = x end
  table.sort(k)
  return k
end

--- Écarts entre un manifeste (texte JSON), des sprites (table de sprites.lua) et les fichiers du dossier dir.
function M.ecarts(dir, manifest_text, spr)
  local e = {}
  local list, why = Gun.parse(manifest_text or "")
  if not list then return { "manifeste illisible : " .. tostring(why) }, 0, 0 end
  if #list == 0 then return { "manifeste vide" }, 0, 0 end
  local dims, manquants = {}, 0
  for _, f in ipairs(list) do
    dims[f.nom] = { f.largeur, f.hauteur }
    local p = dir .. "/" .. f.nom
    local sz = file_size(p)
    if not sz then
      manquants = manquants + 1
      e[#e + 1] = "absent : " .. f.nom
    else
      local w, h = Images.png_size(p)
      if sz ~= f.taille or w ~= f.largeur or h ~= f.hauteur then
        e[#e + 1] = string.format("%s : %d octets %sx%s, manifeste %d octets %dx%d", f.nom, sz, tostring(w), tostring(h), f.taille, f.largeur, f.hauteur)
      end
    end
  end
  if type(spr) ~= "table" or type(spr.pieces) ~= "table" then
    e[#e + 1] = "sprites.lua sans table pieces"
    return e, #list, manquants
  end
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
          if math.abs(s64 - math.floor(s64 + 0.5)) > 1e-6 then
            e[#e + 1] = string.format("%s %s : shift %.6f hors de la grille de 1/64", nom, k, c.hr.shift[i])
          end
        end
      end
    end
    if p.icone then
      local d = dims[base(p.icone.filename)]
      if not d or d[1] ~= 120 or d[2] ~= 64 then e[#e + 1] = nom .. " : icône absente ou pas en 64 px à 4 mipmaps (120 × 64)" end
    end
  end
  return e, #list, manquants
end

function M.check(mod_root)
  local dir = mod_root .. "/" .. M.DIR
  local r = { n = 0, manquants = 0, ecarts = {} }
  local text = read_all(dir .. "/MANIFEST.json")
  if not text then
    r.erreur = "MANIFEST.json absent"
    return r
  end
  local okl, spr = pcall(dofile, dir .. "/sprites.lua")
  if not okl then
    r.erreur = "sprites.lua illisible : " .. tostring(spr)
    return r
  end
  r.ecarts, r.n, r.manquants = M.ecarts(dir, text, spr)
  return r
end

function M.ok(r)
  return r.erreur == nil and #r.ecarts == 0
end

function M.lines(r)
  local L = {}
  L[#L + 1] = string.format("Feuilles bâtiments d'atelier (%s, D-6) : %d fichier(s) au manifeste, %d manquant(s), %d écart(s)%s",
    M.DIR, r.n, r.manquants, #r.ecarts, r.erreur and (" ; " .. r.erreur) or "")
  for i = 1, math.min(#r.ecarts, 10) do L[#L + 1] = "  FEUILLE ATELIER " .. r.ecarts[i] end
  if not M.ok(r) then
    L[#L + 1] = "  => les PNG de " .. M.DIR .. " sont hors de git (D-6) : un checkout ou un worktree neuf doit les régénérer AVANT "
      .. "tout banc : " .. M.REGEN
  end
  return L
end

return M
