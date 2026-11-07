--[[
  Feuilles de la tourelle laser hors de git (décision D-6, lot F1-C, 4/11) : contrôle du MANIFESTE en Lua pur, pour le banc de
  l'étape data (harness.lua), sur le modèle de four_sheets.lua et da_energie_sheets.lua. Un checkout ou un worktree NEUF n'a pas
  les PNG de graphics/levels/laser (ignorés par git) : ce contrôle le dit et imprime la commande qui les régénère.

  Contrôle : chaque PNG de graphics/levels/laser/MANIFEST.json (« fichiers ») existe, a la TAILLE (octets) et les DIMENSIONS
  (en-tête PNG) du manifeste ; chaque image nommée par sprites.lua (pièce e01, socle, pièce et tête des âges 2 à 15, icônes)
  est au manifeste, à ses dimensions (tête : direction_count 32 ou 64, line_length 8, feuille = 8 cellules × rangées) ; tir
  (source_offset, hauteur) présent ; un manifeste d'ESSAI (feuilles.py --essai : poses remplacées, échantillons quelconques) est
  REFUSÉ.
]]

local HERE = (debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./")
local Images = dofile(HERE .. "images.lua")
local Gun = dofile(HERE .. "gun_sheets.lua")

local M = {}

M.DIR = "graphics/levels/laser"
M.REGEN = "py -3.9 tools/render/pieces/levels/laser_e/feuilles.py   (depuis la racine du mod ; sources dans fo-logs : "
  .. "2026-11-04_LASER-F1C/production/sprites, à GARDER)"
local FIXES = { "main", "shadow", "glow", "light" }
local TETES = { "main", "shadow", "glow" }

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

function M.check(mod_root)
  local dir = mod_root .. "/" .. M.DIR
  local r = { n = 0, manquants = {}, ecarts = {}, refs = 0, ages = 0 }
  local text = read_all(dir .. "/MANIFEST.json")
  if not text then
    r.erreur = "MANIFEST.json absent"
    return r
  end
  if text:find('"essai"%s*:%s*true') then
    r.erreur = "manifeste d'ESSAI (feuilles.py --essai) : régénérer depuis la production"
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
  if not okl or type(spr) ~= "table" or type(spr.ages) ~= "table" then
    r.erreur = "sprites.lua illisible : " .. tostring(spr)
    return r
  end
  if spr.essai then r.erreur = "sprites.lua d'ESSAI (feuilles.py --essai)" end
  local function ref(fn, w, h, quoi)
    r.refs = r.refs + 1
    local d = dims[base(fn)]
    if not d then
      r.ecarts[#r.ecarts + 1] = quoi .. " : " .. base(fn) .. " absent du manifeste"
    elseif d[1] ~= w or d[2] ~= h then
      r.ecarts[#r.ecarts + 1] = string.format("%s : %s fait %dx%d, sprites.lua %dx%d", quoi, base(fn), d[1], d[2], w, h)
    end
  end
  local function fixe(partie, quoi)
    if type(partie) ~= "table" or not partie.main then
      r.ecarts[#r.ecarts + 1] = quoi .. " : sans couche principale"
      return
    end
    for _, k in ipairs(FIXES) do
      local c = partie[k]
      if c then
        for _, q in ipairs({ "hr", "lr" }) do ref(c[q].filename, c[q].width, c[q].height, quoi .. " " .. k .. " " .. q) end
        if c.lr.width * 2 ~= c.hr.width or c.lr.height * 2 ~= c.hr.height then
          r.ecarts[#r.ecarts + 1] = quoi .. " " .. k .. " : normale ≠ hr / 2"
        end
      end
    end
  end
  fixe(spr.ages[1] and spr.ages[1].piece, "âge 1 pièce")
  for e = 2, 15 do
    local A = spr.ages[e]
    if not A then
      r.ecarts[#r.ecarts + 1] = "âge " .. e .. " absent de sprites.lua"
    else
      r.ages = r.ages + 1
      fixe(A.socle, "âge " .. e .. " socle")
      fixe(A.piece, "âge " .. e .. " pièce")
      if not (A.tete and A.tete.main and A.tete.shadow) then
        r.ecarts[#r.ecarts + 1] = "âge " .. e .. " tête sans couche principale ou sans ombre"
      end
      for _, k in ipairs(TETES) do
        local c = A.tete and A.tete[k]
        if c then
          for _, q in ipairs({ "hr", "lr" }) do
            local t = c[q]
            if (t.direction_count ~= 32 and t.direction_count ~= 64) or t.line_length ~= 8 then
              r.ecarts[#r.ecarts + 1] = string.format("âge %d tête %s %s : direction_count %s, line_length %s (32 ou 64 "
                .. "et 8 attendus)", e, k, q, tostring(t.direction_count), tostring(t.line_length))
            else
              ref(t.filename, t.width * t.line_length, t.height * math.floor(t.direction_count / t.line_length),
                string.format("âge %d tête %s %s", e, k, q))
            end
          end
        end
      end
      if A.icone then ref(A.icone.filename, 120, 64, "âge " .. e .. " icône")
      else r.ecarts[#r.ecarts + 1] = "âge " .. e .. " sans icône" end
      if not (A.boite and A.tir and A.tir.source_offset and type(A.tir.hauteur) == "number") then
        r.ecarts[#r.ecarts + 1] = "âge " .. e .. " sans boîte ou sans tir (source_offset, hauteur)"
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
  L[#L + 1] = string.format("Feuilles laser (%s, D-6) : %d fichier(s) au manifeste, %d manquant(s), %d écart(s), "
    .. "%d image(s) de sprites.lua relue(s), %d âge(s)%s", M.DIR, r.n, #r.manquants, #r.ecarts, r.refs or 0, r.ages or 0,
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
