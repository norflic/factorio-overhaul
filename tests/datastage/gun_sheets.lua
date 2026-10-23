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
  -- têtes à 4 ou 64 directions (lot A3-jeu) : sprites.lua contre les dimensions du manifeste
  local dims = {}
  for _, e in ipairs(list) do dims[e.nom] = { e.largeur, e.hauteur } end
  local okl, spr = pcall(dofile, dir .. "/sprites.lua")
  if okl and type(spr) == "table" then
    r.tetes = M.check_tetes(spr, dims)
  else
    r.tetes = { n4 = 0, n64 = 0, erreurs = { "sprites.lua illisible : " .. tostring(spr) } }
  end
  r.auto = { M.self_test() }
  return r
end

--- Têtes (lot A3-jeu) : pour chaque âge 2 à 15 de `spr` (table de sprites.lua) et chaque couche de tête, hr et
--- normale : direction_count 4 (colonne, line_length 1) ou 64 (8 × 8, line_length 8) ; la feuille (dimensions du
--- manifeste, `dims[nom]` = { largeur, hauteur }) vaut exactement width × line_length sur height × rangées, 8 192 px
--- au plus (F144). Rend { n4, n64, erreurs = {} }.
function M.check_tetes(spr, dims)
  local r = { n4 = 0, n64 = 0, erreurs = {} }
  local function err(s) r.erreurs[#r.erreurs + 1] = s end
  for e = 2, 15 do
    local age = spr.ages and spr.ages[e]
    if not age or not age.tete or not age.tete.main then
      err("age " .. e .. " : tete absente")
    else
      local n = age.tete.main.hr.direction_count
      if n == 64 then r.n64 = r.n64 + 1 elseif n == 4 then r.n4 = r.n4 + 1 end
      for _, kind in ipairs({ "main", "glow", "shadow" }) do
        local c = age.tete[kind]
        for _, res in ipairs({ "hr", "lr" }) do
          local d = c and c[res]
          if d then
            local ll = (d.direction_count == 64) and 8 or 1
            if (d.direction_count ~= 4 and d.direction_count ~= 64) or d.line_length ~= ll or d.direction_count ~= n then
              err(string.format("age %d tete %s %s : direction_count %s, line_length %s", e, kind, res,
                tostring(d.direction_count), tostring(d.line_length)))
            else
              local nom = d.filename:match("([^/]+)$")
              local dm = dims[nom]
              local w, h = d.width * ll, d.height * math.ceil(d.direction_count / ll)
              if not dm then
                err(string.format("age %d tete %s %s : %s absent du manifeste", e, kind, res, nom))
              elseif dm[1] ~= w or dm[2] ~= h or w > 8192 or h > 8192 then
                err(string.format("age %d tete %s %s : feuille %dx%d, attendu %dx%d (8192 au plus)", e, kind, res,
                  dm[1], dm[2], w, h))
              end
            end
          end
        end
      end
    end
  end
  return r
end

--- Auto-contrôle de check_tetes : une tête à 64 directions juste est acceptée ; line_length faux, feuille trop
--- petite, 64 directions en colonne au-delà de 8 192 px : refusés. Rend (réussis, total).
function M.self_test()
  local function age(n, ll, w, h)
    local function c(f, s) return { filename = "x/" .. f, width = w / s, height = h / s, direction_count = n,
      line_length = ll } end
    return { tete = { main = { hr = c("hr-m.png", 1), lr = c("m.png", 2) } } }
  end
  local function spr(a)
    local t = { ages = {} }
    for e = 2, 15 do t.ages[e] = age(4, 1, 100, 80) end
    t.ages[5] = a
    return t
  end
  local cas = {
    { spr(age(64, 8, 400, 300)), { ["hr-m.png"] = { 3200, 2400 }, ["m.png"] = { 1600, 1200 } }, true },
    { spr(age(64, 1, 400, 300)), { ["hr-m.png"] = { 3200, 2400 }, ["m.png"] = { 1600, 1200 } }, false },
    { spr(age(64, 8, 400, 300)), { ["hr-m.png"] = { 3200, 2398 }, ["m.png"] = { 1600, 1200 } }, false },
    { spr(age(4, 1, 400, 3000)), { ["hr-m.png"] = { 400, 12000 }, ["m.png"] = { 200, 6000 } }, false },
  }
  local ok = 0
  for _, k in ipairs(cas) do
    local d = k[2]
    -- les âges à 4 directions du faux : même fichier, dimensions de la colonne
    local dims = { ["hr-m.png"] = d["hr-m.png"], ["m.png"] = d["m.png"] }
    local r = M.check_tetes(k[1], setmetatable(dims, { __index = function() return nil end }))
    -- seules les erreurs de l'âge 5 comptent (les autres âges du faux pointent vers le même nom de fichier)
    local e5 = 0
    for _, s in ipairs(r.erreurs) do if s:match("^age 5 ") then e5 = e5 + 1 end end
    if (e5 == 0) == k[3] then ok = ok + 1 end
  end
  return ok, #cas
end

function M.ok(r)
  return r.erreur == nil and #r.manquants == 0 and #r.ecarts == 0 and (not r.tetes or #r.tetes.erreurs == 0)
    and (not r.auto or r.auto[1] == r.auto[2])
end

--- Lignes à imprimer (bilan, détails, commande de régénération si quelque chose manque ou diffère).
function M.lines(r)
  local L = {}
  L[#L + 1] = string.format("Feuilles mitrailleuse (%s, D-6) : %d fichier(s) au manifeste, %d manquant(s), %d écart(s)%s",
    M.DIR, r.n, #r.manquants, #r.ecarts, r.erreur and (" ; " .. r.erreur) or "")
  for i = 1, math.min(#r.manquants, 10) do L[#L + 1] = "  FEUILLE MANQUANTE " .. r.manquants[i] end
  if #r.manquants > 10 then L[#L + 1] = "  … et " .. (#r.manquants - 10) .. " autre(s)" end
  for i = 1, math.min(#r.ecarts, 10) do L[#L + 1] = "  FEUILLE DIFFERENTE " .. r.ecarts[i] end
  if r.tetes then
    L[#L + 1] = string.format("Tetes mitrailleuse (A3-jeu) : %d age(s) a 64 directions, %d a 4, %d erreur(s) ; "
      .. "auto-controle %d/%d", r.tetes.n64, r.tetes.n4, #r.tetes.erreurs, r.auto and r.auto[1] or 0,
      r.auto and r.auto[2] or 0)
    for i = 1, math.min(#r.tetes.erreurs, 10) do L[#L + 1] = "  TETE " .. r.tetes.erreurs[i] end
  end
  if not M.ok(r) then
    L[#L + 1] = "  => les PNG de " .. M.DIR .. " sont hors de git (D-6) : un checkout ou un worktree neuf doit les "
      .. "régénérer AVANT tout banc : " .. M.REGEN
  end
  return L
end

return M
