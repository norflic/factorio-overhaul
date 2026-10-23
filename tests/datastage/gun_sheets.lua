--[[
  Feuilles de la mitrailleuse hors de git (décision D-6, correction A2) : contrôle du MANIFESTE en Lua pur, pour le
  banc de l'étape data (harness.lua) et levels_test.lua. Un checkout ou un worktree NEUF n'a pas les PNG de
  graphics/levels/gun (ignorés par git) : ce contrôle le dit et imprime la commande qui les régénère.

  Contrôle : chaque PNG listé dans graphics/levels/gun/MANIFEST.json (« fichiers ») existe, a la TAILLE (octets) et
  les DIMENSIONS (en-tête PNG) du manifeste. Le sha256 et l'absence de PNG en trop ne sont vérifiés que par
  tools/render/pieces/levels/gun_e/check_gun_sheets.py (Python).
]]

local Images = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./") .. "images.lua")

local M = {}

M.DIR = "graphics/levels/gun"
M.REGEN = "py -3.9 tools/render/pieces/levels/gun_e/feuilles.py   (depuis la racine du mod ; sources dans fo-logs : "
  .. "2026-10-23_V3E-p5, 2026-10-23_V3E-ereV, 2026-10-24_A2/sprites ; puis check_gun_sheets.py)"

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

--- Entrées « fichiers » du manifeste (JSON écrit par feuilles.py : indent 1, clés triées) : liste triée de
--- { nom, taille, largeur, hauteur } ; ou nil et le motif.
function M.parse(text)
  local bloc = text:match('"fichiers"%s*:%s*(%b{})')
  if not bloc then return nil, "bloc « fichiers » introuvable" end
  local out = {}
  for nom, corps in bloc:gmatch('"([^"]+%.png)"%s*:%s*(%b{})') do
    out[#out + 1] = { nom = nom, taille = tonumber(corps:match('"taille"%s*:%s*(%d+)')),
      largeur = tonumber(corps:match('"largeur"%s*:%s*(%d+)')), hauteur = tonumber(corps:match('"hauteur"%s*:%s*(%d+)')) }
  end
  table.sort(out, function(a, b) return a.nom < b.nom end)
  return out
end

--- Contrôle du dossier `mod_root`/graphics/levels/gun. Rend { n = fichiers listés, manquants = {}, ecarts = {},
--- erreur = motif ou nil }.
function M.check(mod_root)
  local dir = mod_root .. "/" .. M.DIR
  local r = { n = 0, manquants = {}, ecarts = {} }
  local text = read_all(dir .. "/MANIFEST.json")
  if not text then
    r.erreur = "MANIFEST.json absent"
    return r
  end
  local list, why = M.parse(text)
  if not list then
    r.erreur = why
    return r
  end
  r.n = #list
  if #list == 0 then r.erreur = "manifeste vide" end
  for _, e in ipairs(list) do
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
  return r
end

function M.ok(r)
  return r.erreur == nil and #r.manquants == 0 and #r.ecarts == 0
end

--- Lignes à imprimer (bilan, détails, commande de régénération si quelque chose manque ou diffère).
function M.lines(r)
  local L = {}
  L[#L + 1] = string.format("Feuilles mitrailleuse (%s, D-6) : %d fichier(s) au manifeste, %d manquant(s), %d écart(s)%s",
    M.DIR, r.n, #r.manquants, #r.ecarts, r.erreur and (" ; " .. r.erreur) or "")
  for i = 1, math.min(#r.manquants, 10) do L[#L + 1] = "  FEUILLE MANQUANTE " .. r.manquants[i] end
  if #r.manquants > 10 then L[#L + 1] = "  … et " .. (#r.manquants - 10) .. " autre(s)" end
  for i = 1, math.min(#r.ecarts, 10) do L[#L + 1] = "  FEUILLE DIFFERENTE " .. r.ecarts[i] end
  if not M.ok(r) then
    L[#L + 1] = "  => les PNG de " .. M.DIR .. " sont hors de git (D-6) : un checkout ou un worktree neuf doit les "
      .. "régénérer AVANT tout banc : " .. M.REGEN
  end
  return L
end

return M
