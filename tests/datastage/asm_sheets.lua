--[[
  Feuilles de la MACHINE D'ASSEMBLAGE hors de git (décision D-6, lot F3-B) : contrôle du MANIFESTE en Lua pur, pour le
  banc de l'étape data (harness.lua) et levels_test.lua, sur le modèle de four_sheets.lua (lot F2-B). Un checkout ou un
  worktree NEUF n'a pas les PNG de graphics/levels/assembleur (ignorés par git) : ce contrôle le dit et imprime la
  commande qui les régénère.

  Contrôle : chaque PNG de graphics/levels/assembleur/MANIFEST.json (« fichiers ») existe, a la TAILLE (octets) et les
  DIMENSIONS (en-tête PNG) du manifeste ; chaque image nommée par sprites.lua (couches de la machine et de la pièce,
  icônes) est au manifeste, à ses dimensions ; les 15 âges sont présents (âge 1 : la pièce seule).
]]

local HERE = (debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./")
local Images = dofile(HERE .. "images.lua")
local Gun = dofile(HERE .. "gun_sheets.lua")

local M = {}

M.DIR = "graphics/levels/assembleur"
M.REGEN = "py -3.9 tools/render/pieces/levels/assembleur_e/feuilles.py   (depuis la racine du mod ; sources dans "
  .. "fo-logs : 2026-10-25_F3/production/sprites, à GARDER)"

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

local KINDS = { "main", "glow", "light", "shadow" }

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
  for e = 1, 15 do
    local age = spr.ages and spr.ages[e]
    if not age then
      r.ecarts[#r.ecarts + 1] = "age " .. e .. " absent de sprites.lua"
    else
      local parties = e == 1 and { "piece" } or { "machine", "piece" }
      for _, partie in ipairs(parties) do
        if not (age[partie] and age[partie].main) then
          r.ecarts[#r.ecarts + 1] = string.format("age %d : %s sans couche principale", e, partie)
        end
        for _, k in ipairs(KINDS) do
          local c = age[partie] and age[partie][k]
          if c then
            for _, q in ipairs({ "hr", "lr" }) do
              ref(c[q].filename, c[q].width, c[q].height, string.format("age %d %s %s %s", e, partie, k, q))
            end
          end
        end
      end
      if e > 1 then
        if age.icone then ref(age.icone.filename, 120, 64, "age " .. e .. " icone")
        else r.ecarts[#r.ecarts + 1] = "age " .. e .. " sans icone" end
      end
    end
  end
  return r
end

function M.ok(r)
  return r.erreur == nil and #r.manquants == 0 and #r.ecarts == 0
end

function M.lines(r)
  local L = {}
  L[#L + 1] = string.format("Feuilles assembleur (%s, D-6) : %d fichier(s) au manifeste, %d manquant(s), %d écart(s), "
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
