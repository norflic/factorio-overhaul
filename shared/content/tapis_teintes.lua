--[[
  Lot S42 TAPIS-TEINTES (chantier 2.4 du DC, stade data) : règles PURES qui rendent chaque palier de convoyeur reconnaissable
  d'un coup d'œil. Aucune API Factorio, aucun nom d'objet : un palier est une VITESSE (`speed` du prototype), un aspect est la
  liste des planches (`filename`) et des teintes que le prototype dessine. Tests : tests/s42_tapis-teintes_test.lua.

    T.signature(proto)            aspect d'un prototype : planches et teintes de T.FIELDS + icône, triées (aucun ordre de pairs)
    T.tint(slot)                  teinte du rang `slot` (1, 2, …) : 6 couleurs fixes puis angle d'or ; deux rangs = deux teintes
    T.plan(entries)               entries = { { key, kind, speed, sig } } ; rend { [key] = { tint, slot } } pour les SEULS
                                  prototypes dont l'aspect est déjà pris par un palier plus lent de la même sorte, puis le
                                  recensement (paliers, doublons). Une vitesse = un rang : tapis, souterrain et répartiteur du
                                  même palier portent la même teinte.
    T.apply(proto, tint)          pose la teinte (multipliée à l'existante) sur toutes les couches de T.FIELDS et sur l'icône
    T.coefficient(speed, frames)  animation_speed_coefficient : 32 (valeur du jeu : l'animation avance de speed × 32 images par
                                  tick, donc proportionnelle à la vitesse) tant que l'animation ne « recule » pas à l'œil
                                  (moins de la moitié des images par tick) ; au-delà, le plus grand coefficient sans repli.
]]

local T = {}

T.FIELDS = { "belt_animation_set", "structure", "structure_patch" } -- ce que dessinent tapis, souterrains et répartiteurs
T.ANIM_COEF = 32 -- coefficient des trois paliers du jeu de base
T.FRAMES = 16 -- images par direction des planches de tapis du jeu de base

-- Six teintes fixes, éloignées du jaune, du rouge et du bleu des paliers du jeu ; ensuite l'angle d'or.
T.PALETTE = {
  { r = 0.40, g = 1.00, b = 0.45 }, -- vert
  { r = 0.78, g = 0.45, b = 1.00 }, -- violet
  { r = 0.35, g = 1.00, b = 1.00 }, -- cyan
  { r = 1.00, g = 0.50, b = 0.85 }, -- rose
  { r = 1.00, g = 0.62, b = 0.25 }, -- orange
  { r = 0.62, g = 0.62, b = 0.62 }, -- gris acier
}

local function round3(x) return math.floor(x * 1000 + 0.5) / 1000 end

local function hsv(h, s, v)
  local i = math.floor(h * 6) % 6
  local f = h * 6 - math.floor(h * 6)
  local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
  if i == 0 then return v, t, p elseif i == 1 then return q, v, p elseif i == 2 then return p, v, t
  elseif i == 3 then return p, q, v elseif i == 4 then return t, p, v end
  return v, p, q
end

function T.tint_key(t)
  if type(t) ~= "table" then return "-" end
  return string.format("%.3f/%.3f/%.3f/%.3f", t.r or t[1] or 0, t.g or t[2] or 0, t.b or t[3] or 0, t.a or t[4] or 1)
end

--- Teinte du rang `slot` (entier ≥ 1). Déterministe ; deux rangs distincts rendent deux teintes distinctes
-- (vérifié sur 60 rangs par le test ; au-delà de la palette, la valeur porte le rang : 0,4 % par rang).
function T.tint(slot)
  local n = #T.PALETTE
  if slot <= n then
    local c = T.PALETTE[slot]
    return { r = c.r, g = c.g, b = c.b, a = 1 }
  end
  local k = slot - n
  local r, g, b = hsv((0.07 + k * 0.61803398875) % 1, 0.70, 0.95 - 0.004 * ((k - 1) % 100))
  return { r = round3(r), g = round3(g), b = round3(b), a = 1 }
end

local function collect(node, out, depth)
  if type(node) ~= "table" or depth > 12 then return end
  if type(node.filename) == "string" then out[#out + 1] = node.filename .. "#" .. T.tint_key(node.tint) end
  if type(node.filenames) == "table" then
    for _, f in ipairs(node.filenames) do out[#out + 1] = tostring(f) .. "#" .. T.tint_key(node.tint) end
  end
  for _, v in pairs(node) do -- ordre sans effet : la liste est triée par l'appelant
    if type(v) == "table" then collect(v, out, depth + 1) end
  end
end

--- Aspect d'un prototype : chaîne stable faite des planches et teintes de T.FIELDS et de l'icône.
function T.signature(proto)
  local out = {}
  for _, f in ipairs(T.FIELDS) do collect(proto[f], out, 0) end
  table.sort(out)
  local icon = {}
  if type(proto.icons) == "table" then
    for _, l in ipairs(proto.icons) do icon[#icon + 1] = tostring(l.icon or proto.icon) .. "#" .. T.tint_key(l.tint) end
  elseif proto.icon then
    icon[1] = tostring(proto.icon) .. "#-"
  end
  return table.concat(out, "|") .. "||" .. table.concat(icon, "|")
end

--- Plan de teinte. entries = { { key = , kind = , speed = , sig = } }.
-- Rend plan[key] = { tint = , slot = } pour les seuls doublons d'aspect, et le recensement
-- { tiers = nombre de vitesses, entries = n, shared = { { key, twin } } }.
function T.plan(entries)
  local list = {}
  for i, e in ipairs(entries) do list[i] = e end
  table.sort(list, function(a, b)
    if a.speed ~= b.speed then return a.speed < b.speed end
    if a.kind ~= b.kind then return tostring(a.kind) < tostring(b.kind) end
    return tostring(a.key) < tostring(b.key)
  end)
  local plan, census = {}, { tiers = 0, entries = #list, shared = {} }
  local seen_speed, taken = {}, {} -- taken[kind .. sig] = clé du premier porteur de l'aspect
  local slot_of_speed, next_slot = {}, 0
  local used = {} -- used[kind .. slot] = vrai : une sorte ne reçoit jamais deux fois le même rang
  for _, e in ipairs(list) do
    if not seen_speed[e.speed] then seen_speed[e.speed] = true; census.tiers = census.tiers + 1 end
    local k = tostring(e.kind) .. "\0" .. tostring(e.sig)
    if not taken[k] then
      taken[k] = e.key
    else
      census.shared[#census.shared + 1] = { key = e.key, twin = taken[k] }
      local slot = slot_of_speed[e.speed]
      if not slot or used[tostring(e.kind) .. "\0" .. slot] then
        next_slot = next_slot + 1
        slot = next_slot
        if not slot_of_speed[e.speed] then slot_of_speed[e.speed] = slot end
      end
      used[tostring(e.kind) .. "\0" .. slot] = true
      plan[e.key] = { tint = T.tint(slot), slot = slot }
    end
  end
  return plan, census
end

local function mul(old, t)
  if type(old) ~= "table" then return { r = t.r, g = t.g, b = t.b, a = t.a } end
  return { r = (old.r or old[1] or 1) * t.r, g = (old.g or old[2] or 1) * t.g, b = (old.b or old[3] or 1) * t.b,
    a = (old.a or old[4] or 1) * t.a }
end

local function paint(node, tint, depth, seen)
  if type(node) ~= "table" or depth > 12 or seen[node] then return end
  seen[node] = true
  local old = node.tint
  for _, v in pairs(node) do -- chaque couche reçoit la même teinte : l'ordre est sans effet
    if type(v) == "table" and v ~= old then paint(v, tint, depth + 1, seen) end
  end
  if type(node.filename) == "string" or type(node.filenames) == "table" then node.tint = mul(old, tint) end
end

--- Teinte l'icône d'un prototype (entité ou objet) : `icon` devient une couche de `icons` teintée.
function T.apply_icon(proto, tint)
  if type(proto.icons) == "table" then
    for _, l in ipairs(proto.icons) do l.tint = mul(l.tint, tint) end
  elseif proto.icon then
    proto.icons = { { icon = proto.icon, icon_size = proto.icon_size, icon_mipmaps = proto.icon_mipmaps,
      tint = { r = tint.r, g = tint.g, b = tint.b, a = tint.a } } }
  end
end

--- Teinte toutes les couches de sprites de T.FIELDS et l'icône. Les tables partagées entre prototypes doivent être copiées
-- par l'appelant AVANT (sinon le palier d'origine serait teinté lui aussi).
function T.apply(proto, tint)
  local seen = {}
  for _, f in ipairs(T.FIELDS) do paint(proto[f], tint, 0, seen) end
  T.apply_icon(proto, tint)
end

--- animation_speed_coefficient d'un palier : T.ANIM_COEF tant que speed × coefficient reste sous la moitié des images
-- (au-delà l'œil voit le tapis reculer) ; sinon le plus grand coefficient qui tient cette borne.
function T.coefficient(speed, frames)
  if type(speed) ~= "number" or speed <= 0 then return T.ANIM_COEF end
  local n = (type(frames) == "number" and frames > 0) and frames or T.FRAMES
  local limit = n / 2 - 1 -- images par tick au plus
  if speed * T.ANIM_COEF <= limit then return T.ANIM_COEF end
  return limit / speed
end

return T
