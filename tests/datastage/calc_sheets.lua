--[[
  Feuilles des 20 MACHINES DU CALCUL hors de git (décision D-6, lot MACHINES-CALCUL) : contrôle du MANIFESTE en Lua pur, pour le banc
  de l'étape data (harness.lua) et tests/calcul_feuilles_test.lua, sur le modèle d'usines_sheets.lua. Un checkout ou un worktree NEUF
  n'a pas les PNG de graphics/machines/calcul (ignorés par git) : ce contrôle le dit et imprime la commande qui les régénère.

  Contrôle : chaque PNG de graphics/machines/calcul/MANIFEST.json (« fichiers ») existe, a la TAILLE (octets) et les DIMENSIONS
  (en-tête PNG) du manifeste ; chaque image nommée par sprites.lua (corps, ombre, lueur, bande de la pièce mobile : largeur × images,
  hr et normale ; icône 120 × 64) est au manifeste, à ses dimensions ; les 20 machines sont là, chacune avec corps et ombre.
]]

local HERE = (debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./")
local Images = dofile(HERE .. "images.lua")
local Gun = dofile(HERE .. "gun_sheets.lua")

local M = {}

M.DIR = "graphics/machines/calcul"
M.REGEN = "py -3.9 tools/render/pieces/calcul/feuilles.py   (depuis la racine du mod, sans argument ; sources : "
  .. "fo-logs/2026-11-01_CALCUL-DESIGN/final, à GARDER)"
M.MACHINES = {
  "fo-arc-furnace", "fo-chiller", "fo-circuit-printer", "fo-cleanroom", "fo-cooling-tower", "fo-cryogenic-unit",
  "fo-crystal-lithograph", "fo-crystal-puller", "fo-data-center", "fo-data-center-2", "fo-die-prober", "fo-dilution-fridge",
  "fo-fiber-tower", "fo-packaging-line", "fo-plasma-etcher", "fo-quantum-lab", "fo-rack-integrator", "fo-sintering-furnace",
  "fo-smt-line", "fo-wire-saw",
}

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

local KINDS = { "main", "shadow", "glow", "mobile" }

function M.check(mod_root)
  M.ROOT = mod_root
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
  r.machines = 0
  for _, nom in ipairs(M.MACHINES) do
    local u = spr[nom]
    if not u then
      r.ecarts[#r.ecarts + 1] = nom .. " absente de sprites.lua"
    else
      r.machines = r.machines + 1
      local c = u.couches or {}
      if not (c.main and c.shadow) then r.ecarts[#r.ecarts + 1] = nom .. " : sans corps ou sans ombre" end
      for _, k in ipairs(KINDS) do
        local x = c[k]
        if x then
          local nb = x.images or 1
          for _, q in ipairs({ "hr", "lr" }) do
            ref(x[q].filename, x[q].width * nb, x[q].height, string.format("%s %s %s", nom, k, q))
          end
        end
      end
      if u.icone then ref(u.icone.icon, 120, 64, nom .. " icone")
      else r.ecarts[#r.ecarts + 1] = nom .. " sans icone" end
      if not (u.boite and u.map_color) then r.ecarts[#r.ecarts + 1] = nom .. " sans boite ou couleur de carte" end
    end
  end
  return r
end

function M.ok(r)
  return r.erreur == nil and #r.manquants == 0 and #r.ecarts == 0
end

--- Parcourt toutes les couches (tables avec filename, ou filenames) d'une valeur ; f(couche, chemin).
local function each_sprite(v, path, f, seen)
  if type(v) ~= "table" or seen[v] then return end
  seen[v] = true
  if v.filename or v.filenames then f(v, path) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do each_sprite(v[k], path .. "." .. tostring(k), f, seen) end
end

local PREF = "__factorio-overhaul__/" .. M.DIR .. "/"
local VISUELS = { "animation", "idle_animation", "working_visualisations", "integration_patch" }

--- Branchement dans les données FINALES (modded = prototypes du mod par type) : pour chacune des 20 machines, toutes les images de
--- ses couches viennent des feuilles (aucune image vanilla, aucune teinte), corps + ombre, aucune idle_animation ni
--- integration_patch ; sa boîte de collision tient dans l'emprise de sprites.lua ; icônes de la machine et de son objet dessinées ;
--- chaque boîte de fluide a ses raccords tracés (pipe_picture) et ses couvercles. Auto-contrôle : une copie teintée est refusée.
function M.check_protos(modded)
  local r = { n = 0, ecarts = {}, auto = 0 }
  local spr_ok, spr = pcall(dofile, (M.ROOT or ".") .. "/" .. M.DIR .. "/sprites.lua")
  local function une(e, name, ecarts)
    local n0 = #ecarts
    if not e then
      ecarts[#ecarts + 1] = name .. " : prototype absent"
      return false
    end
    local images, ombre = 0, false
    for _, k in ipairs(VISUELS) do
      each_sprite(e[k], k, function(s, path)
        images = images + 1
        local fn = s.filename or (s.filenames and s.filenames[1]) or ""
        if fn:sub(1, #PREF) ~= PREF then ecarts[#ecarts + 1] = name .. " " .. path .. " : image hors des feuilles " .. fn end
        if s.tint then ecarts[#ecarts + 1] = name .. " " .. path .. " : teinte" end
        if s.draw_as_shadow then ombre = true end
      end, {})
    end
    if images == 0 then ecarts[#ecarts + 1] = name .. " : aucune couche" end
    if not ombre then ecarts[#ecarts + 1] = name .. " : sans ombre" end
    if e.idle_animation or e.integration_patch then ecarts[#ecarts + 1] = name .. " : idle_animation ou integration_patch restant" end
    local ic = e.icons and e.icons[1]
    if not (ic and ic.icon and ic.icon:sub(1, #PREF) == PREF and not ic.tint) then ecarts[#ecarts + 1] = name .. " : icône de l'entité" end
    local it = modded.item and modded.item[name]
    local ii = it and it.icons and it.icons[1]
    if not (ii and ii.icon and ii.icon:sub(1, #PREF) == PREF and not ii.tint) then ecarts[#ecarts + 1] = name .. " : icône de l'objet" end
    if spr_ok and type(spr) == "table" and spr[name] and e.collision_box then
      local h = spr[name].cote / 2
      local cb = e.collision_box
      if cb[1][1] < -h or cb[1][2] < -h or cb[2][1] > h or cb[2][2] > h then
        ecarts[#ecarts + 1] = name .. " : boîte de collision hors de l'emprise dessinée (" .. spr[name].cote .. ")"
      end
      local sb = e.selection_box
      if not sb or math.abs(sb[1][1] + h) > 1e-6 or math.abs(sb[1][2] + h) > 1e-6 or math.abs(sb[2][1] - h) > 1e-6
        or math.abs(sb[2][2] - h) > 1e-6 then
        ecarts[#ecarts + 1] = name .. " : boîte de sélection différente de l'emprise dessinée (" .. spr[name].cote .. ")"
      end
    end
    for i, b in ipairs(e.fluid_boxes or {}) do
      if type(b) == "table" and not (b.pipe_picture and b.pipe_covers) then
        ecarts[#ecarts + 1] = name .. " : boîte de fluide " .. i .. " sans raccord tracé ou sans couvercle"
      end
    end
    return #ecarts == n0
  end
  for _, name in ipairs(M.MACHINES) do
    local e = (modded["assembling-machine"] or {})[name] or (modded.furnace or {})[name]
    r.n = r.n + 1
    une(e, name, r.ecarts)
  end
  -- auto-contrôle : une machine teintée à l'ancienne (image vanilla + teinte) doit être refusée
  local faux = { animation = { layers = { { filename = "__base__/graphics/entity/assembling-machine-3/assembling-machine-3.png",
    tint = { r = 0.9, g = 0.96, b = 1 } } } }, icons = { { icon = "__base__/graphics/icons/assembling-machine-3.png" } } }
  if not une(faux, "faux", {}) then r.auto = r.auto + 1 end
  return r
end

function M.ok_protos(r)
  return #r.ecarts == 0 and r.n == #M.MACHINES and r.auto == 1
end

function M.lines_protos(r)
  local L = { string.format("Machines du calcul en jeu (lot MACHINES-CALCUL) : %d machine(s) contrôlée(s), %d écart(s) "
    .. "(image hors des feuilles, teinte, sans ombre, icône, emprise, raccord de fluide) ; auto-contrôle %d/1",
    r.n, #r.ecarts, r.auto) }
  for i = 1, math.min(#r.ecarts, 20) do L[#L + 1] = "  MACHINE DU CALCUL " .. r.ecarts[i] end
  return L
end

function M.lines(r)
  local L = {}
  L[#L + 1] = string.format("Feuilles machines du calcul (%s, D-6) : %d fichier(s) au manifeste, %d manquant(s), %d écart(s), "
    .. "%d image(s) de sprites.lua relue(s), %d machine(s)%s", M.DIR, r.n, #r.manquants, #r.ecarts, r.refs or 0, r.machines or 0,
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
