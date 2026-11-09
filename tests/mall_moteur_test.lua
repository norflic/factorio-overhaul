--[[
  Lot MALL, tranche 1 : test hors jeu du runtime du secteur (script/team/mall.lua) sur un moteur simulé MINIMAL (surface, forces,
  prototypes, réglages fabriqués ici) et de son branchement dans script/team/build.lua (lu comme texte).
    §1 réglage absent ou éteint : rien ; §2 relevé par chunks sous le jeton, choix, réservation (b.occ = -1) ; §3 eau, minerai, projet
    déjà réservé évités ; §4 lots du treillis dans le secteur ; §5 aucune fenêtre : cause, nouvel essai ; §6 réglage éteint en cours :
    réservation rendue ; §7 état S et journal à chaque changement ; §8 coût par passe (debug.sethook) ; §9 branchement.
  Usage : lua5.2 tests/mall_moteur_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, ko_n = 0, 0
local function check(cond, what)
  if cond then ok_n = ok_n + 1 else ko_n = ko_n + 1; print("ECHEC : " .. what) end
end
local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

-- Moteur simulé ----------------------------------------------------------------------------------
_G.defines = { flow_precision_index = { one_minute = 1 } }
_G.FLOW = {}
local LOG = {}
_G.log = function(s) LOG[#LOG + 1] = s end
local SETTING = nil
_G.settings = setmetatable({}, { __index = function(_, k)
  if k == "global" then
    if SETTING == nil then return {} end
    return { ["fo-war-mall"] = { value = SETTING } }
  end
end })
local RECIPES = { ["assembling-machine-1"] = { enabled = false } }
_G.game = {
  forces = { player = { recipes = RECIPES, item_production_statistics = { get_flow_count = function(t) return (FLOW or {})[t.name] or 0 end } } },
  get_filtered_entity_prototypes = function()
    return { ["assembling-machine-1"] = { items_to_place_this = { { name = "assembling-machine-1" } } } }
  end,
}

local function world(opts)
  -- opts.water(tx, ty), opts.ore(tx, ty), opts.objects = { { x, y, type } }, opts.gen(cx, cy)
  local W = { calls = 0 }
  local function inside(a, x, y) return x >= a[1][1] and x <= a[2][1] and y >= a[1][2] and y <= a[2][2] end
  function W.is_chunk_generated(c) return not opts.gen or opts.gen(c[1], c[2]) end
  function W.count_tiles_filtered(q)
    W.calls = W.calls + 1
    if not opts.water then return 0 end
    local a = q.area
    for ty = math.floor(a[1][2]), math.floor(a[2][2]) do
      for tx = math.floor(a[1][1]), math.floor(a[2][1]) do
        if opts.water(tx, ty) then return 1 end
      end
    end
    return 0
  end
  function W.count_entities_filtered(q)
    W.calls = W.calls + 1
    local a = q.area
    local n = 0
    if q.type == "resource" then
      if not opts.ore then return 0 end
      for ty = math.floor(a[1][2]), math.floor(a[2][2]) do
        for tx = math.floor(a[1][1]), math.floor(a[2][1]) do if opts.ore(tx, ty) then return 1 end end
      end
      return 0
    end
    for _, e in ipairs(opts.objects or {}) do
      if inside(a, e.x, e.y) then
        local soft = e.type == "tree" or e.type == "simple-entity"
        if q.collision_mask == "object-layer" then n = n + 1
        elseif type(q.type) == "table" and soft then n = n + 1 end
      end
    end
    return n
  end
  return W
end

local P = require("shared.team.plan")
local Mp = require("shared.team.mall_plan")
local Mall = require("script.team.mall")

local function team(qx, qy)
  local f = { key = "player", force = "player", hq = { valid = true }, hq_pos = { x = qx, y = qy }, team = {}, outposts = {} }
  f.build = { lat = P.lattice({ x = qx, y = qy }), occ = {}, projects = {}, order = {}, lots = {} }
  return f
end
local JETON_OK = true
local H = { couloirs = function() return {} end, jeton = { take = function() return JETON_OK end }, pulse = 5 }
local function run(f, surface, t0, passes)
  local t = t0
  for _ = 1, passes do Mall.step(H, f, surface, t); t = t + 5 end
  return t
end
local function count_occ(b, v)
  local n = 0
  for _, o in pairs(b.occ) do if o == v then n = n + 1 end end
  return n
end

-- §1 réglage absent ou éteint
do
  SETTING = nil
  local f = team(100, -40)
  run(f, world({}), 0, 5)
  check(f.build.mall == nil, "§1 réglage absent : aucun état")
  SETTING = false
  run(f, world({}), 0, 5)
  check(f.build.mall == nil, "§1 réglage éteint : aucun état")
end

-- §2 relevé, choix, réservation
local f2
do
  SETTING = true
  LOG = {}
  local f = team(100, -40)
  f2 = f
  local w = world({})
  Mall.step(H, f, w, 0)
  check(f.build.mall and f.build.mall.phase == "lecture", "§2 recherche lancée")
  local total = f.build.mall.nch * f.build.mall.nch
  check(total == 225, "§2 225 chunks à relever")
  -- jeton refusé : aucune lecture
  JETON_OK = false
  run(f, w, 5, 3)
  check(f.build.mall.k == 0, "§2 jeton refusé : rien n'est lu")
  JETON_OK = true
  local passes = math.ceil(total / Mall.CHUNKS_PER_PASS)
  run(f, w, 20, passes)
  check(f.build.mall.phase == "choix", "§2 relevé fini en " .. passes .. " passes")
  run(f, w, 2000, 1)
  local st = f.build.mall
  check(st.phase == "choisi" and st.sect ~= nil, "§2 secteur choisi")
  check(st.grid == nil, "§2 grille libérée après le choix")
  local s = st.sect
  check(count_occ(f.build, Mall.OCC) == (s.x1 - s.x0) * (s.y1 - s.y0), "§2 toutes les tuiles du secteur réservées (-1)")
  local x0, y0, x1, y1 = P.lot_rect(f.build.lat, 0, 0)
  check(not (s.x0 < x1 and s.x1 > x0 and s.y0 < y1 and s.y1 > y0), "§2 hors du lot du QG")
  local found = false
  for _, l in ipairs(LOG) do if l:find("SECTEUR (", 1, true) then found = true end end
  check(found, "§2 ligne SECTEUR au journal")
  -- une passe de plus ne refait rien
  local n0 = count_occ(f.build, Mall.OCC)
  run(f, w, 2100, 3)
  check(count_occ(f.build, Mall.OCC) == n0 and f.build.mall.sect == s, "§2 rien ne change après le choix")
end

-- §3 eau, minerai, projet déjà réservé
do
  SETTING = true
  local ref = f2.build.mall.sect
  local f = team(100, -40)
  -- un projet tient déjà une tuile au milieu du secteur de référence
  f.build.occ[P.tkey(ref.x0 + 30, ref.y0 + 30)] = 7
  local w = world({
    water = function(tx, ty) return tx >= ref.x0 + 40 and tx < ref.x0 + 44 and ty >= ref.y0 and ty < ref.y0 + 4 end,
    ore = function(tx, ty) return tx >= ref.x0 and tx < ref.x0 + 4 and ty >= ref.y0 + 50 and ty < ref.y0 + 54 end,
  })
  run(f, w, 0, 1 + 113 + 3)
  local s = f.build.mall.sect
  check(s ~= nil, "§3 un secteur malgré l'eau, le minerai et le projet")
  if s then
    check(f.build.occ[P.tkey(ref.x0 + 30, ref.y0 + 30)] == 7, "§3 la tuile du projet n'est pas reprise")
    local overlap = s.x0 < ref.x0 + 44 and s.x1 > ref.x0 + 40 and s.y0 < ref.y0 + 4 and s.y1 > ref.y0
    check(not overlap, "§3 le secteur évite l'eau")
    local oo = s.x0 < ref.x0 + 4 and s.x1 > ref.x0 and s.y0 < ref.y0 + 54 and s.y1 > ref.y0 + 50
    check(not oo, "§3 le secteur évite le minerai")
    local op = s.x0 <= ref.x0 + 30 and s.x1 > ref.x0 + 30 and s.y0 <= ref.y0 + 30 and s.y1 > ref.y0 + 30
    check(not op, "§3 le secteur évite la tuile d'un projet")
  end
  -- un bâtiment (objet non défrichable) et des arbres : le bâtiment interdit, les arbres non
  local f3 = team(100, -40)
  local w3 = world({ objects = { { x = ref.x0 + 10.5, y = ref.y0 + 10.5, type = "container" } } })
  run(f3, w3, 0, 1 + 113 + 3)
  local s3 = f3.build.mall.sect
  check(s3 and not (s3.x0 <= ref.x0 + 10 and s3.x1 > ref.x0 + 10 and s3.y0 <= ref.y0 + 10 and s3.y1 > ref.y0 + 10), "§3 le secteur évite un bâtiment")
  local f4 = team(100, -40)
  local trees = {}
  for k = 0, 7 do trees[#trees + 1] = { x = ref.x0 + 4.5 + 8 * k, y = ref.y0 + 4.5, type = "tree" } end
  run(f4, world({ objects = trees }), 0, 1 + 113 + 3)
  check(f4.build.mall.sect ~= nil, "§3 des arbres n'empêchent pas un secteur")
end

-- §4 lots du treillis dans le secteur
do
  local b = f2.build
  local s = b.mall.sect
  local inside, partial = nil, nil
  for i = -6, 6 do
    for j = -6, 6 do
      local x0, y0, x1, y1 = P.lot_rect(b.lat, i, j)
      if Mp.inside(s, x0, y0, x1, y1) then inside = inside or { i = i, j = j }
      elseif x0 < s.x1 and x1 > s.x0 and y0 < s.y1 and y1 > s.y0 then partial = partial or { i = i, j = j } end
    end
  end
  check(inside ~= nil, "§4 au moins un lot entier dans un secteur de 64 tuiles")
  if inside then check(Mall.lot_inside(b, inside), "§4 lot entier : exclu des candidats") end
  if partial then check(not Mall.lot_inside(b, partial), "§4 lot à cheval : reste candidat (P.fit voit les tuiles réservées)") end
  check(not Mall.lot_inside({ lat = b.lat }, { i = 0, j = 0 }), "§4 sans secteur : aucun lot exclu")
end

-- §5 aucune fenêtre : tout en eau autour du QG
do
  LOG = {}
  local f = team(100, -40)
  local w = world({ water = function(tx, ty) return not (math.abs(tx - 100) < 6 and math.abs(ty + 40) < 6) end })
  local t = run(f, w, 0, 1 + 113 + #Mp.TRIES) -- (un essai de Mp.TRIES par passe)
  check(f.build.mall.phase == "aucun", "§5 aucune fenêtre : phase « aucun »")
  local found = false
  for _, l in ipairs(LOG) do if l:find("SECTEUR aucun", 1, true) and l:find("cause dominante : eau", 1, true) then found = true end end
  check(found, "§5 cause dominante eau au journal")
  check(count_occ(f.build, Mall.OCC) == 0, "§5 rien de réservé")
  run(f, w, t, 2)
  check(f.build.mall.phase == "aucun", "§5 pas de nouvel essai avant 10 min")
  run(f, w, t + Mall.RETRY, 1)
  check(f.build.mall.phase == "lecture", "§5 nouvel essai après 10 min")
end

-- §6 réglage éteint en cours de partie : réservation rendue
do
  local f = team(100, -40)
  SETTING = true
  run(f, world({}), 0, 1 + 113 + 3)
  check(count_occ(f.build, Mall.OCC) > 0, "§6 secteur réservé")
  f.build.occ[P.tkey(0, 0)] = 9
  SETTING = false
  run(f, world({}), 5000, 1)
  check(count_occ(f.build, Mall.OCC) == 0 and f.build.mall == nil, "§6 réservation rendue")
  check(f.build.occ[P.tkey(0, 0)] == 9, "§6 les tuiles des projets restent")
  SETTING = true
end

-- §7b S2 lu au débit mesuré (plaques produites par minute), sans projet fini
do
  LOG = {}
  local f = team(100, -40)
  local b = f.build
  b.projects[1] = { id = 1, state = "fini", spec = { gen = "steam" } }
  b.order = { 1 }
  b.plant = 1
  b.plant_watch = { first_power = 100 }
  _G.FLOW = { ["iron-plate"] = Mp.S2_PLAQUES_MIN, ["copper-plate"] = Mp.S2_PLAQUES_MIN - 1 }
  Mall.step(H, f, world({}), 0)
  local found = false
  for _, l in ipairs(LOG) do if l:find("attente S2", 1, true) and l:find("copper-plate", 1, true) and not l:find("iron-plate", 1, true) then found = true end end
  check(found, "§7b S2 : le fer au seuil compte, le cuivre sous le seuil manque")
  _G.FLOW = { ["iron-plate"] = Mp.S2_PLAQUES_MIN, ["copper-plate"] = Mp.S2_PLAQUES_MIN }
  LOG = {}
  Mall.step(H, f, world({}), Mall.ETAT_EVERY + 1)
  local still = false
  for _, l in ipairs(LOG) do if l:find("attente S2", 1, true) then still = true end end
  check(not still, "§7b S2 : les deux plaques au seuil, S2 levé")
  _G.FLOW = {}
end

-- §7 état S
do
  LOG = {}
  local f = team(100, -40)
  local b = f.build
  local function etat_lines()
    local out = {}
    for _, l in ipairs(LOG) do if l:find(" : etat ", 1, true) then out[#out + 1] = l end end
    return out
  end
  run(f, world({}), 0, 1)
  check(#etat_lines() == 1 and etat_lines()[1]:find("attente S1", 1, true), "§7 S1 sans centrale")
  run(f, world({}), 5, 3)
  check(#etat_lines() == 1, "§7 une ligne par changement seulement")
  -- centrale finie, premier courant
  b.projects[1] = { id = 1, state = "fini", spec = { gen = "steam" } }
  b.order = { 1 }
  b.plant = 1
  b.plant_watch = { first_power = 100 }
  Mall.step(H, f, world({}), 3600)
  local l = etat_lines()
  check(#l == 2 and l[2]:find("attente S2", 1, true) and l[2]:find("iron-plate", 1, true) and l[2]:find("copper-plate", 1, true), "§7 S2 : fer et cuivre sans source")
  -- bande de champ de fer finie, fonderie de cuivre finie
  f.outposts[11] = { kind = "iron" }
  b.projects[2] = { id = 2, state = "fini", spec = { site = "champ", champ = { oid = 11 } } }
  b.projects[3] = { id = 3, state = "chantier", spec = { gen = "smelter", args = { "stone-furnace", "copper-ore", 4 } } }
  b.order = { 1, 2, 3 }
  Mall.step(H, f, world({}), 7200)
  l = etat_lines()
  check(l[#l]:find("copper-plate", 1, true) and not l[#l]:find("iron-plate", 1, true), "§7 S2 : le cuivre manque encore (fonderie en chantier)")
  b.projects[3].state = "fini"
  f.team.survie = { on = true }
  Mall.step(H, f, world({}), 10800)
  l = etat_lines()
  check(l[#l]:find("attente S3", 1, true) and l[#l]:find("survie", 1, true), "§7 S3 : survie")
  f.team.survie = nil
  f.team.ia3 = { pile = { hold = true, top = 1 } }
  Mall.step(H, f, world({}), 14400)
  l = etat_lines()
  check(l[#l]:find("pile R1", 1, true), "§7 S3 : la pile retient")
  f.team.ia3 = nil
  Mall.step(H, f, world({}), 18000)
  l = etat_lines()
  check(l[#l]:find("attente S4", 1, true), "§7 S4 : assembleur non débloqué")
  RECIPES["assembling-machine-1"].enabled = true
  Mall.step(H, f, world({}), 21600)
  l = etat_lines()
  check(l[#l]:find("PRET", 1, true) and b.mall.pret == true, "§7 S vrai : PRET")
  RECIPES["assembling-machine-1"].enabled = false
end

-- §8 coût par passe (Lua du module seul : la surface simulée renvoie 0 sans calcul)
do
  local function cost(fn)
    local n = 0
    debug.sethook(function() n = n + 1 end, "", 1)
    fn()
    debug.sethook()
    return n
  end
  local flat = { is_chunk_generated = function() return true end, count_tiles_filtered = function() return 0 end,
    count_entities_filtered = function() return 0 end }
  local f = team(100, -40)
  Mall.step(H, f, flat, 0)
  local worst_read = 0
  local t = 5
  while f.build.mall.phase == "lecture" do
    local c = cost(function() Mall.step(H, f, flat, t) end)
    if c > worst_read then worst_read = c end
    t = t + 5
  end
  local worst_choice = 0
  while f.build.mall.phase == "choix" do
    local c = cost(function() Mall.step(H, f, flat, t) end)
    if c > worst_choice then worst_choice = c end
    t = t + 5
  end
  print(string.format("  cout par passe : releve %d, choix + reservation %d instructions", worst_read, worst_choice))
  check(worst_read <= 370000, "§8 relevé ≤ 370 k instructions par passe (" .. worst_read .. ")")
  check(worst_choice <= 370000, "§8 choix + réservation ≤ 370 k instructions par passe (" .. worst_choice .. ")")
end

-- §9 branchement dans build.lua
do
  local src = read("script/team/build.lua")
  check(src:find('Build.Mall = require("script.team.mall")', 1, true) ~= nil, "§9 Build.Mall requis au chargement (champ, pas une locale)")
  check(src:find("if b.mall and b.mall.sect and Build.Mall.lot_inside(b, l) then ok_state = false end", 1, true) ~= nil, "§9 candidates exclut les lots du secteur")
  check(src:find("Build.Mall.step({ couloirs = Build.couloirs, jeton = Jeton, pulse = Build.PULSE }, f, surface, tick)", 1, true) ~= nil, "§9 passe du plan directeur")
  local set = read("settings.lua")
  check(set:find('require("settings.mall")', 1, true) ~= nil, "§9 réglage requis par settings.lua")
  for _, lang in ipairs({ "fr", "en" }) do
    local loc = read("locale/" .. lang .. "/mall.cfg")
    check(loc:find("[mod-setting-name]", 1, true) and loc:find("fo-war-mall=", 1, true), "§9 traduction " .. lang)
  end
  local code = read("script/team/mall.lua"):gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find("global%."), "§9 global n'est pas nommé")
  check(not code:find("require%(", 1) or select(2, code:gsub("require%(", "")) == 3, "§9 trois require au chargement seulement")
end

print(string.format("[MALL-MOTEUR] BILAN : %d OK, %d ECHEC(S)", ok_n, ko_n))
if ko_n > 0 then os.exit(1) end
