--[[
  Feuilles des usines de robots hors de git (décision D-6, lot US-V1) : contrôle du MANIFESTE en Lua pur, pour le banc de l'étape data
  (harness.lua) et robots_test.lua, sur le modèle de centre_sheets.lua (lot QG-JEU). Un checkout ou un worktree NEUF n'a pas les PNG de
  graphics/robots/usines (ignorés par git) : ce contrôle le dit et imprime la commande qui les régénère.

  Contrôle : chaque PNG de graphics/robots/usines/MANIFEST.json (« fichiers ») existe, a la TAILLE (octets) et les DIMENSIONS (en-tête
  PNG) du manifeste ; chaque image nommée par sprites.lua (couches de chaque usine, icônes) est au manifeste, à ses dimensions ; les
  4 usines sont présentes.
]]

local HERE = (debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./")
local Images = dofile(HERE .. "images.lua")
local Gun = dofile(HERE .. "gun_sheets.lua")

local M = {}

M.DIR = "graphics/robots/usines"
M.REGEN = "py -3.9 tools/render/pieces/usines_robots/feuilles.py   (depuis la racine du mod ; sources dans "
  .. "fo-logs : 2026-11-01_USV1/production/sprites, à GARDER)"
M.USINES = { "atelier", "hall", "dock", "portique" }

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

local KINDS = { "main", "shadow", "glow" }

function M.check(mod_root)
  local dir = mod_root .. "/" .. M.DIR
  local r = { n = 0, manquants = {}, ecarts = {}, refs = 0 }
  local text = read_all(dir .. "/MANIFEST.json")
  if not text then
    r.erreur = "MANIFEST.json absent"
    return r
  end
  local list, why = Gun.parse(text)
  if not list then
    r.erreur = why
    return r
  end
  r.n = #list
  if #list == 0 then r.erreur = "manifeste vide" end
  local dims = {}
  for _, e in ipairs(list) do
    dims[e.nom] = { e.largeur, e.hauteur }
    local p = dir .. "/" .. e.nom
    local sz = file_size(p)
    if not sz then
      r.manquants[#r.manquants + 1] = e.nom
    else
      local w, h = Images.png_size(p)
      if sz ~= e.taille or w ~= e.largeur or h ~= e.hauteur then
        r.ecarts[#r.ecarts + 1] = string.format("%s : %s octets, %sx%s (manifeste : %s, %sx%s)", e.nom, tostring(sz),
          tostring(w), tostring(h), tostring(e.taille), tostring(e.largeur), tostring(e.hauteur))
      end
    end
  end
  local okl, spr = pcall(dofile, dir .. "/sprites.lua")
  if not okl or type(spr) ~= "table" then
    r.erreur = "sprites.lua illisible : " .. tostring(spr)
    return r
  end
  local function ref(fn, w, h, quoi)
    r.refs = r.refs + 1
    local d = dims[base(fn)]
    if not d then
      r.ecarts[#r.ecarts + 1] = quoi .. " : " .. base(fn) .. " absent du manifeste"
    elseif d[1] ~= w or d[2] ~= h then
      r.ecarts[#r.ecarts + 1] = string.format("%s : %s fait %dx%d, sprites.lua %dx%d", quoi, base(fn), d[1], d[2], w, h)
    end
  end
  for _, nom in ipairs(M.USINES) do
    local u = spr.usines and spr.usines[nom]
    if not u then
      r.ecarts[#r.ecarts + 1] = nom .. " absente de sprites.lua"
    else
      if not (u.main and u.shadow) then r.ecarts[#r.ecarts + 1] = nom .. " : sans couche principale ou sans ombre" end
      for _, k in ipairs(KINDS) do
        local c = u[k]
        if c then
          for _, q in ipairs({ "hr", "lr" }) do
            ref(c[q].filename, c[q].width, c[q].height, string.format("%s %s %s", nom, k, q))
          end
        end
      end
      if u.icone then ref(u.icone.filename, 120, 64, nom .. " icone")
      else r.ecarts[#r.ecarts + 1] = nom .. " sans icone" end
      if not (u.boite and u.map_color) then r.ecarts[#r.ecarts + 1] = nom .. " sans boite ou couleur de carte" end
    end
  end
  return r
end

function M.ok(r)
  return r.erreur == nil and #r.manquants == 0 and #r.ecarts == 0
end

function M.lines(r)
  local L = {}
  L[#L + 1] = string.format("Feuilles usines de robots (%s, D-6) : %d fichier(s) au manifeste, %d manquant(s), %d écart(s), "
    .. "%d image(s) de sprites.lua relue(s)%s", M.DIR, r.n, #r.manquants, #r.ecarts, r.refs or 0,
    r.erreur and (" ; " .. r.erreur) or "")
  for i = 1, math.min(#r.manquants, 10) do L[#L + 1] = "  FEUILLE MANQUANTE " .. r.manquants[i] end
  for i = 1, math.min(#r.ecarts, 10) do L[#L + 1] = "  FEUILLE DIFFERENTE " .. r.ecarts[i] end
  if not M.ok(r) then
    L[#L + 1] = "  => les PNG de " .. M.DIR .. " sont hors de git (D-6) : un checkout ou un worktree neuf doit les "
      .. "régénérer AVANT tout banc : " .. M.REGEN
  end
  return L
end

return M
