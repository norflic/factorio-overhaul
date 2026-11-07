--[[
  Formes de champ des bancs hors jeu du lot CHAMP-COUVERTURE (tirées de tests/champ_couverture_test.lua, partagées avec
  tests/champ_tranches_test.lua) : disques, ellipse, L, couloir, rivière, tourelles, anneau, lacs, ouvertures, minerai brut ; et la spec
  du jeu de ces bancs. Pur, aucune API Factorio.
]]
local Ch = require("shared.team.champ")
local F = {}

local function disc(cx, cy, r, skip, out)
  out = out or {}
  for x = cx - r, cx + r do for y = cy - r, cy + r do
    if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r and not (skip and skip(x, y)) then out[#out + 1] = x; out[#out + 1] = y end
  end end
  return out
end
local function ellipse(a, b)
  local o = {}
  for x = -a, a do for y = -b, b do if (x / a) ^ 2 + (y / b) ^ 2 <= 1 then o[#o + 1] = x; o[#o + 1] = y end end end
  return o
end
local function rect(x0, y0, w, h, out)
  out = out or {}
  for x = x0, x0 + w - 1 do for y = y0, y0 + h - 1 do out[#out + 1] = x; out[#out + 1] = y end end
  return out
end

--- Spec du jeu (voir l'en-tête). o.brut : minerai porté brut (coffres) ; o.blocked ; o.target.
local function spec_of(ore, o)
  o = o or {}
  local sp = { ore = ore, blocked = o.blocked or {}, mine = {}, foreign = {}, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = { { lane = 7.5 } }, inserter = { rate = 0.83 }, target = o.target or { x = 0, y = 400 }, max_side = 8,
    logistics = { splitter = false, underground = (o.ug ~= false) and (o.ug or 5) or nil } }
  if not o.brut then
    sp.furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 }
    sp.design = "colonne"
    local bx, by = 0, 0
    for i = 1, #ore - 1, 2 do bx = math.max(bx, ore[i]); by = math.max(by, ore[i + 1]) end
    -- charbon : gisement de rayon 12 (452 tuiles) à ~45 tuiles en diagonale du coin du champ (au-delà des fonderies déplacées : la zone
    -- interdite au tracé du charbon est la boîte du champ ET des colonnes)
    sp.coal = { tiles = disc(bx + 45, by + 45, 12), rate = 0.5, foreign = {} }
    sp.soft, sp.ug_tiles = {}, {}
  end
  return sp
end

--- Formes (nom, minerai, options, cible de couverture, valeur d'essai-a).
local function shapes()
  local L = {}
  local function add(name, ore, o, target, before) L[#L + 1] = { name = name, ore = ore, o = o or {}, target = target, before = before } end
  add("disque r11", disc(0, 0, 11), nil, 0.98, 1.000)
  add("disque r20", disc(0, 0, 20), nil, 0.97, 0.990)
  add("disque r30", disc(0, 0, 30), nil, 0.80, 0.809)
  add("ellipse 70 x 30", ellipse(35, 15), nil, 0.73, 0.737)
  do
    local Lr = rect(0, 0, 60, 14)
    rect(0, 14, 14, 50, Lr)
    add("L 60 x 14 + 14 x 50", Lr, nil, 0.82, 0.826)
  end
  do
    local b = {}
    for x = -40, 40 do for y = 0, 1 do b[Ch.key(x, y)] = "couloir" end end
    add("r30 + couloir horizontal", disc(0, 0, 30), { blocked = b }, 0.77, 0.774)
  end
  do
    local b, w = {}, {}
    for x = -40, 40 do for y = -40, 40 do if math.abs(x - y) <= 2 then b[Ch.key(x, y)] = "eau"; w[Ch.key(x, y)] = true end end end
    -- (écart connu : la rivière fait 5 tuiles ; un souterrain jaune n'en saute que 4 ; le long tronçon d'une bande coupée n'a alors
    -- qu'une sortie et porte au plus une voie de tête de colonne, 15 foreuses au tapis jaune)
    add("r30 + riviere diagonale", disc(0, 0, 30, function(x, y) return w[Ch.key(x, y)] end), { blocked = b, known = "riviere de 5 tuiles, souterrain jaune de portee 5 (4 tuiles sautees) : le troncon long n'a qu'une sortie, 15 foreuses au plus" }, 0.75, 0.681)
    add("r30 + riviere, souterrain rapide (portee 7)", disc(0, 0, 30, function(x, y) return w[Ch.key(x, y)] end), { blocked = b, ug = 7 }, 0.75, nil)
  end
  do
    local b = {}
    for x = -36, 36, 12 do for y = -36, 36, 12 do for dx = 0, 1 do for dy = 0, 1 do b[Ch.key(x + dx, y + dy)] = "gun-turret" end end end end
    add("r30 + tourelles eparses sur le champ", disc(0, 0, 30), { blocked = b }, 0.72, 0.615)
  end
  do
    local b = {}
    for x = -40, 40 do for y = -40, 40 do
      local d2 = x * x + y * y
      if d2 >= 34 * 34 and d2 < 35 * 35 and (x + y) % 8 == 0 then for dx = 0, 1 do for dy = 0, 1 do b[Ch.key(x + dx, y + dy)] = "gun-turret" end end end
    end end
    add("r30 + anneau de tourelles (r34)", disc(0, 0, 30), { blocked = b }, 0.76, 0.485)
    -- sans souterrain débloqué (début de partie) : la sortie bouchée par une tourelle recule d'une foreuse (Cc.trim)
    add("r30 + anneau, sans souterrains", disc(0, 0, 30), { blocked = b, ug = false }, 0.75, nil)
  end
  -- (écart connu, mesuré le 7/11, accordé par le lead) entre le bout du champ et un lac, le couloir x = ±32 n'a qu'une tuile (x = ±31 : les
  -- foreuses du bout ; x = ±33 : le lac) : le tapis tracé l'occupe et aucun petit poteau ne s'y pose (fil 7,5 ; rangées de poteaux à 8 tuiles).
  -- La colonne déplacée d'une bande entre les lacs n'a de courant que par une AUTRE bande : refusée (une bande se bâtit seule en jeu).
  local LACS = "couloir d'une tuile entre le champ et le lac : aucun petit poteau de liaison (fil 7,5 < 8 tuiles entre rangees) ; "
    .. "colonne deplacee sans courant si sa bande est batie seule, donc refusee"
  do
    local b = {}
    for x = 33, 60 do for y = -15, 15 do b[Ch.key(x, y)] = "eau"; b[Ch.key(-x, y)] = "eau" end end
    add("r30 + lacs aux deux bouts", disc(0, 0, 30), { blocked = b, known = LACS }, 0.75, 0.230)
    -- lacs plus longs que le recul de la fonderie (48 tuiles) : elle passe sur une autre rangée de bande
    local b2 = {}
    for x = 33, 100 do for y = -15, 15 do b2[Ch.key(x, y)] = "eau"; b2[Ch.key(-x, y)] = "eau" end end
    add("r30 + grands lacs (33 a 100)", disc(0, 0, 30), { blocked = b2, known = LACS }, 0.75, nil)
  end
  do
    local b = {}
    for x = 14, 50 do for y = -20, 20 do if math.abs(y) > 1 then b[Ch.key(x, y)] = "eau"; b[Ch.key(-x, y)] = "eau" end end end
    add("r12 + eau aux bouts, ouverture de 3", disc(0, 0, 12), { blocked = b }, 0.85, 0.000)
  end
  do
    local b = {}
    for x = 33, 70 do for y = -40, 40 do if math.abs(y) > 2 then b[Ch.key(x, y)] = "eau"; b[Ch.key(-x, y)] = "eau" end end end
    add("r30 + eau aux bouts, ouverture de 5", disc(0, 0, 30), { blocked = b }, 0.70, 0.000)
  end
  add("r30 brut (coffres)", disc(0, 0, 30), { brut = true }, 0.84, 0.848)
  do
    local b = {}
    for x = 33, 60 do for y = -15, 15 do b[Ch.key(x, y)] = "eau"; b[Ch.key(-x, y)] = "eau" end end
    add("r30 brut + lacs aux deux bouts", disc(0, 0, 30), { blocked = b, brut = true, known = LACS }, 0.75, nil)
  end
  return L
end
--- Cadre réel relevé en jeu (tests/fixtures/champ_spec_*.txt, une ligne « clé=valeur | ... », comme tests/champ_colonne_test.lua) :
--- rend une fonction qui fabrique une spec neuve à chaque appel.
local function fixture(path)
  local function split(str, sep)
    local out = {}
    if str == nil or str == "" then return out end
    for part in (str .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
    return out
  end
  local function nums(str) local out = {} for _, x in ipairs(split(str, ",")) do out[#out + 1] = tonumber(x) end return out end
  local function set(str) local out = {} for _, x in ipairs(split(str, ",")) do out[tonumber(x)] = true end return out end
  local h = assert(io.open(path, "r"))
  local line = h:read("*l")
  h:close()
  local fl = {}
  for _, kv in ipairs(split(line, "|")) do local k, v = kv:match("^([%w_]+)=(.*)$"); if k then fl[k] = v end end
  return function()
    local d, pl, fu, tg = nums(fl.drill), nums(fl.pole), split(fl.furnace, ","), nums(fl.target)
    local belts = {}
    for _, x in ipairs(split(fl.belts, ";")) do belts[#belts + 1] = { lane = tonumber(x) } end
    return { ore = nums(fl.ore), blocked = set(fl.blocked), mine = set(fl.mine), soft = fl.soft ~= "" and set(fl.soft) or nil,
      drill = { size = d[1], reach = d[2], rate = d[3] }, pole = { reach = pl[1], wire = pl[2] }, belts = belts,
      furnace = { size = tonumber(fu[1]), rate = tonumber(fu[2]), fuel = fu[3] == "true", fuel_rate = tonumber(fu[4]) },
      inserter = { rate = tonumber(fl.ins) }, target = { x = tg[1], y = tg[2] }, max_side = tonumber(fl.max_side), design = "colonne",
      logistics = { underground = tonumber(fl.ug), splitter = fl.splitter == "true" }, coal = { tiles = nums(fl.coal), rate = tonumber(fl.coalrate) },
      ug_tiles = {} }
  end
end

--- Corpus de l'équivalence (coût de Ch.plan) : { { name, spec = fonction qui rend une spec neuve } } ; les 17 formes, le géant 200 x 200,
--- les cadres réels de scarlet (20261020) et du joueur (271828182).
local function corpus()
  local out = {}
  for _, s in ipairs(shapes()) do
    out[#out + 1] = { name = s.name, spec = function() return spec_of(s.ore, s.o) end }
  end
  local g = rect(0, 0, 200, 200)
  out[#out + 1] = { name = "geant 200 x 200", spec = function() return spec_of(g, {}) end }
  out[#out + 1] = { name = "scarlet 20261020", spec = fixture("tests/fixtures/champ_spec_scarlet_20261020.txt") }
  out[#out + 1] = { name = "joueur 271828182", spec = fixture("tests/fixtures/champ_spec_player_271828182.txt") }
  return out
end

F.disc, F.ellipse, F.rect, F.spec_of, F.shapes, F.fixture, F.corpus = disc, ellipse, rect, spec_of, shapes, fixture, corpus
return F
