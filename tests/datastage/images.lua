--[[
  Règle « images » du banc de l'étape data (lot A2, 24/10) : tout fichier d'image cité par un prototype EXISTE, et
  chaque rectangle de sprite TIENT dans son image (dimensions lues dans l'en-tête PNG, IHDR).

  Définitions reconnues (doc prototype-api.json 1.1.91) :
    - Sprite et ses parents (SpriteParameters) : filename, width/height ou size, x/y ou position ;
    - Animation, RotatedAnimation, RotatedSprite, SpriteSheet, SpriteNWaySheet : images = frame_count × direction_count
      × variation_count (ou `frames` d'une feuille N-way), rangées par lignes de line_length images ;
    - stripes (width_in_frames × height_in_frames images chacune, à x/y) ; filenames + lines_per_file ;
    - icônes : icon (+ icon_size, icon_mipmaps : largeur ≥ taille × (1 + 1/2 + …), hauteur ≥ taille).
  line_length = 0 (défaut) : « toutes les images sur une ligne » (doc) pour une Animation ou un RotatedSprite ; pour une
  RotatedAnimation, la vanilla le lit comme frame_count par ligne (une direction par ligne : levée de la mitrailleuse,
  hr-gun-turret-raising.png 650 × 504 = 5 × 130 sur 4 × 126). Sans frame_count explicite, une table à direction_count
  peut être l'une ou l'autre : la règle accepte alors l'une OU l'autre lecture (ambiguïté dite, non tranchée).
  SpriteSheet sans line_length : variation_count par ligne (défaut de la doc).
  Étalonnage : la règle tourne d'abord sur TOUTE la vanilla ; une seule violation vanilla veut dire que la règle lit
  mal le format (le banc échoue : « étalonnage vanilla »).
]]

local M = {}

local SIG = "\137PNG\r\n\26\n"

local function be32(s, i)
  local a, b, c, d = s:byte(i, i + 3)
  return ((a * 256 + b) * 256 + c) * 256 + d
end

--- Dimensions d'un PNG (en-tête IHDR) : w, h ; ou nil et le motif.
function M.png_size(path)
  local f = io.open(path, "rb")
  if not f then return nil, "absent" end
  local head = f:read(24)
  f:close()
  if not head or #head < 24 or head:sub(1, 8) ~= SIG or head:sub(13, 16) ~= "IHDR" then return nil, "pas un PNG" end
  return be32(head, 17), be32(head, 21)
end

--- Vérificateur : roots = { core = dir, base = dir, [mod] = dir }. Rend un objet avec :check(raw, only, label).
function M.new(roots)
  local self = { roots = roots, cache = {}, files_seen = {} }

  local function size_of(name)
    local c = self.cache[name]
    if c then return c[1], c[2], c[3] end
    local mod, rest = name:match("^__([%w%-_]+)__/(.+)$")
    local w, h, why
    if not mod or not roots[mod] then
      w, h, why = nil, nil, "mod inconnu"
    else
      w, h = M.png_size(roots[mod] .. "/" .. rest)
      if not w then why, h = h, nil end
    end
    self.cache[name] = { w, h, why }
    return w, h, why
  end
  self.size_of = size_of

  -- dims d'une image (frame) de la définition
  local function dims(t)
    local w, h = t.width, t.height
    if type(t.size) == "table" then
      w, h = w or t.size[1] or t.size.x, h or t.size[2] or t.size.y
    elseif type(t.size) == "number" then
      w, h = w or t.size, h or t.size
    end
    return w, h
  end

  local function origin(t)
    local x, y = t.x or 0, t.y or 0
    if x == 0 and y == 0 and type(t.position) == "table" then
      x, y = t.position[1] or t.position.x or 0, t.position[2] or t.position.y or 0
    end
    return x, y
  end

  -- Lectures possibles de la disposition : liste de { nombre d'images, images par ligne }. La règle accepte une
  -- définition si UNE lecture tient dans l'image. Lectures (étalonnées sur la vanilla 1.1.91) :
  --   - line_length explicite ;
  --   - avec direction_count > 1 (RotatedAnimation, RotatedSprite) : une direction par ligne (frame_count images ;
  --     les biters vanilla en filenames ont line_length 16 mais 11 images par ligne), ou tout sur une ligne si
  --     line_length vaut 0 ;
  --   - avec variation_count (feuilles de variations, minerais, particules) : frame_count par ligne (une variation par
  --     ligne), sinon variation_count par ligne (défaut de la doc) ;
  --   - sans direction (Sprite ou Animation) : tout sur une ligne si line_length vaut 0 ; et, si frame_count > 1,
  --     la lecture « Sprite » (une seule image : un Sprite ignore frame_count ; coffre lié et voyant du lance-flammes
  --     vanilla). Une tête à directions n'a donc jamais la lecture « une image ».
  local function layout(t)
    local frames = t.frame_count or 1
    local dirs = t.direction_count or 1
    local vars = t.variation_count or 1
    local n = frames * dirs * vars
    if type(t.frames) == "number" then n = math.max(n, t.frames) end
    local c, seen = {}, {}
    local function add(cnt, ll)
      if not ll or ll <= 0 then return end
      local k = cnt .. "/" .. ll
      if not seen[k] then seen[k] = true c[#c + 1] = { cnt, ll } end
    end
    local explicit = t.line_length and t.line_length > 0
    if explicit then add(n, t.line_length) end
    if dirs > 1 then
      add(n, frames)
      if not explicit then add(n, n) end
    elseif t.variation_count then
      if frames > 1 then add(n, frames) end
      if not explicit then add(n, t.variation_count) end
    else
      if not explicit then add(n, n) end
      if frames > 1 then add(1, 1) end
    end
    return c
  end

  local function need(n, ll, w, h, x, y)
    ll = math.max(1, math.min(ll, n))
    local rows = math.ceil(n / ll)
    return x + ll * w, y + rows * h
  end

  local function report(out, where, what, msg)
    out[#out + 1] = { where = where, what = what, msg = msg }
  end

  local function check_file(out, where, name, needw, needh, label)
    self.files_seen[name] = true
    local W, H, why = size_of(name)
    if not W then
      report(out, where, "manquant", name .. " (" .. why .. ")")
      return false
    end
    if needw and needh and (needw > W or needh > H) then
      report(out, where, "hors image", string.format("%s : %s demande %dx%d, image %dx%d", name, label, needw, needh, W, H))
      return false
    end
    return true
  end

  -- une définition de sprite (avec filename, filenames ou stripes)
  local function check_sprite(out, where, t, counts)
    local w, h = dims(t)
    counts.defs = counts.defs + 1
    local cands = layout(t)
    local x, y = origin(t)
    if type(t.stripes) == "table" then
      if not (w and h) then report(out, where, "hors image", "stripes sans taille d'image") return end
      for i, s in ipairs(t.stripes) do
        local sx, sy = s.x or 0, s.y or 0
        check_file(out, where .. ".stripes[" .. i .. "]", s.filename, sx + (s.width_in_frames or 1) * w,
          sy + (s.height_in_frames or 1) * h, "bande " .. (s.width_in_frames or 1) .. "x" .. (s.height_in_frames or 1))
      end
      return
    end
    if type(t.filenames) == "table" then
      if not (w and h) then report(out, where, "hors image", "filenames sans taille d'image") return end
      local lpf = t.lines_per_file or 0
      local ok_any, errs = false, {}
      for _, cand in ipairs(cands) do
        local n = cand[1]
        local ll = math.max(1, math.min(cand[2], n))
        local rows = math.ceil(n / ll)
        local sub = {}
        for i, fn in ipairs(t.filenames) do
          local first = (i - 1) * lpf
          local r = (lpf > 0) and math.max(0, math.min(lpf, rows - first)) or rows
          check_file(sub, where .. ".filenames[" .. i .. "]", fn, x + ll * w, y + r * h, ll .. " par ligne, " .. r .. " ligne(s)")
        end
        if #sub == 0 then ok_any = true break end
        errs = sub
      end
      if not ok_any then for _, e in ipairs(errs) do out[#out + 1] = e end end
      return
    end
    if type(t.filename) ~= "string" then return end
    if not (w and h) then
      -- sans taille, seule l'existence se contrôle (ex. image entière d'un Sprite simple)
      check_file(out, where, t.filename, nil, nil, "")
      return
    end
    local sub_best
    for _, cand in ipairs(cands) do
      local n, ll = cand[1], cand[2]
      local sub = {}
      local nw, nh = need(n, ll, w, h, x, y)
      check_file(sub, where, t.filename, nw, nh, n .. " image(s) de " .. w .. "x" .. h .. " à (" .. x .. ", " .. y .. "), "
        .. math.min(ll, n) .. " par ligne")
      if #sub == 0 then return end
      sub_best = sub_best or sub
    end
    for _, e in ipairs(sub_best) do out[#out + 1] = e end
  end

  local function is_png(s) return type(s) == "string" and s:lower():match("%.png$") ~= nil end

  local function walk(out, where, t, counts, seen, icon_size, icon_mip)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    icon_size = t.icon_size or icon_size
    -- icon_size se transmet aux entrées de icons ; icon_mipmaps NON (vanilla : cancel.png 64 × 64 dans les icônes
    -- d'un prototype à 4 mipmaps)
    icon_mip = t.icon_mipmaps
    if is_png(t.icon) then
      counts.icons = counts.icons + 1
      local s, m = icon_size or 64, icon_mip or 0
      local wneed = 0
      for k = 0, math.max(0, m - 1) do wneed = wneed + s / (2 ^ k) end
      check_file(out, where .. ".icon", t.icon, math.ceil(wneed), s, "icône " .. s .. " px, " .. m .. " mipmap(s)")
    end
    if is_png(t.filename) or (type(t.filenames) == "table" and is_png(t.filenames[1]))
      or (type(t.stripes) == "table" and t.stripes[1] and is_png(t.stripes[1].filename)) then
      check_sprite(out, where, t, counts)
    end
    local keys = {}
    for k in pairs(t) do if k ~= "stripes" and k ~= "filenames" then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      walk(out, where .. "." .. tostring(k), t[k], counts, seen, icon_size, icon_mip)
    end
  end

  --- Contrôle les prototypes de raw (only : ensemble « type/nom », ou nil = tous). Rend violations et comptes.
  function self.check(raw, only)
    local out = {}
    local counts = { defs = 0, icons = 0, protos = 0 }
    local types = {}
    for ty in pairs(raw) do types[#types + 1] = ty end
    table.sort(types)
    for _, ty in ipairs(types) do
      local names = {}
      for n in pairs(raw[ty]) do names[#names + 1] = n end
      table.sort(names)
      for _, n in ipairs(names) do
        if not only or only[ty .. "/" .. n] then
          counts.protos = counts.protos + 1
          walk(out, ty .. "/" .. n, raw[ty][n], counts, {}, nil, nil)
        end
      end
    end
    return out, counts
  end

  return self
end

return M
