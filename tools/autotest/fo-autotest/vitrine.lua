--[[
  VITRINE (scénario « vitrine ») : chaque entité demandée est posée en tête d'une rangée, suivie des
  bâtiments vanilla de référence, sur un sol vanilla uniforme sans décor, puis capturée (shots.lua) :
  rangée entière au zoom 1, début de rangée au zoom 2, gros plans de l'entité, de jour et de nuit.

  Paramètres : fichier Lua qui renvoie une table (format dans tools/autotest/README.md).
    - <racine>\fo-vitrine.lua s'il existe : fo-autotest.bat le recopie ici sous le nom vitrine_params.lua ;
    - sinon l'exemple vanilla vitrine_exemple.lua.
  Les bâtiments sont alimentés par un poteau et une source invisibles (data.lua du mod de test) : aucun
  poteau ne vient encombrer les captures.

  Déroulé : V.start() pendant on_init (--create) ; V.shot_list() dans la session avec images (la sauvegarde
  est rechargée : tout ce qui sert aux captures vit dans global.vitrine).
]]

local Terrain = require("terrain")

local V = {}

local ok_p, PARAMS = pcall(require, "vitrine_params")
local SOURCE = "fo-vitrine.lua"
if not ok_p or type(PARAMS) ~= "table" then
  PARAMS = require("vitrine_exemple")
  SOURCE = "vitrine_exemple.lua (exemple integre)"
end

--- Références vanilla (OBJECTIFS §7, lot P1) ; chacune est mise en marche pour que sa lumière de travail
--- se voie la nuit (four allumé, machine qui fabrique, foreuse qui creuse, tourelles chargées).
local REFERENCES = {
  { name = "assembling-machine-2", recette = "electric-mining-drill" },
  { name = "steel-furnace", contenu = { { "coal", 20 }, { "iron-ore", 50 } } },
  { name = "gun-turret", contenu = { { "firearm-magazine", 10 } } },
  { name = "laser-turret" },
  { name = "stone-wall", rangee = 3 },
  { name = "electric-mining-drill", minerai = "iron-ore" },
}

local X0, Y0 = 300, 300 -- coin haut-gauche de la vitrine (loin du départ : le personnage n'est pas cadré)
local GAP = 3           -- tuiles entre deux bâtiments d'une rangée
local ROW_GAP = 7       -- tuiles entre deux rangées (place pour les sprites hauts)
local MARGIN = 24       -- sol préparé autour de la vitrine

local function vlog(msg)
  log("[FO-VITRINE] " .. msg)
end

--- Entrée normalisée : une chaîne devient { name = chaîne }.
local function entry(e)
  if type(e) == "string" then return { name = e } end
  if type(e) == "table" and type(e.name) == "string" then return e end
  return nil
end

--- Nom de fichier sûr (les noms de prototypes sont déjà en [a-z0-9-] en pratique).
local function safe(name)
  return (name:gsub("[^%w%-]", "_"))
end

--- Emprise en tuiles d'une entrée (une rangée de murs compte pour n tuiles).
local function footprint(e)
  local p = game.entity_prototypes[e.name]
  if not p then return nil end
  local w, h = p.tile_width, p.tile_height
  if w == 0 or h == 0 then
    local cb = p.collision_box
    w = math.max(1, math.ceil(cb.right_bottom.x - cb.left_top.x))
    h = math.max(1, math.ceil(cb.right_bottom.y - cb.left_top.y))
  end
  if e.rangee and e.rangee > 1 then w = w * e.rangee end
  return w, h, p
end

local function insert_all(e, list, errs)
  for _, it in ipairs(list or {}) do
    local ok, err = pcall(function() return e.insert({ name = it[1], count = it[2] }) end)
    if not ok then errs[#errs + 1] = "insert " .. tostring(it[1]) .. " : " .. tostring(err) end
  end
end

--- Pose une entrée centrée en (cx, cy) ; renvoie l'entité principale et la liste des erreurs.
local function place(s, e, cx, cy, w, h, proto)
  local errs = {}
  local force = e.force or "player"
  local dir = e.direction and defines.direction[e.direction] or nil
  if proto.type == "mining-drill" then
    -- Exactement la zone d'extraction (foreuse électrique : rayon 2,49, donc 5×5 tuiles).
    local r = proto.mining_drill_radius or 1
    local ore = e.minerai or "iron-ore"
    for x = math.floor(cx - r), math.floor(cx + r) do
      for y = math.floor(cy - r), math.floor(cy + r) do
        s.create_entity({ name = ore, position = { x + 0.5, y + 0.5 }, amount = 100000 })
      end
    end
  end
  local n = (e.rangee and e.rangee > 1) and e.rangee or 1
  local main
  for k = 1, n do
    local px = (n > 1) and (cx - w / 2 + (k - 0.5) * (w / n)) or cx
    local ok, ent = pcall(s.create_entity, {
      name = e.name, position = { px, cy }, force = force, direction = dir, raise_built = e.raise_built == true,
    })
    if not ok then
      errs[#errs + 1] = "create_entity : " .. tostring(ent)
    elseif not ent then
      errs[#errs + 1] = "create_entity a renvoye nil"
    elseif k == math.ceil(n / 2) or not main then
      main = ent
    end
  end
  if not main then return nil, errs end
  if e.recette then
    local ok, err = pcall(function() main.set_recipe(e.recette) end)
    if not ok then
      errs[#errs + 1] = "set_recipe " .. e.recette .. " : " .. tostring(err)
    else
      local r = game.recipe_prototypes[e.recette]
      for _, ing in ipairs(r and r.ingredients or {}) do
        if ing.type == "item" then insert_all(main, { { ing.name, ing.amount * 20 } }, errs) end
      end
    end
  end
  insert_all(main, e.contenu, errs)
  if e.actif == false or (proto.type == "unit" and e.actif == nil) then main.active = false end
  return main, errs
end

function V.start()
  local s = game.surfaces[1]
  -- Sol par défaut : béton vanilla, gris neutre (grass-1 sort jaune olive sur les captures).
  local sol = type(PARAMS.sol) == "string" and PARAMS.sol or "concrete"
  if not game.tile_prototypes[sol] then
    vlog("ECHEC sol inconnu : " .. sol .. " (remplace par concrete)")
    sol = "concrete"
  end
  local refs = {}
  for _, r in ipairs(type(PARAMS.references) == "table" and PARAMS.references or REFERENCES) do
    local e = entry(r)
    if e then refs[#refs + 1] = e end
  end
  local wanted = {}
  for _, raw in ipairs(type(PARAMS.entites) == "table" and PARAMS.entites or {}) do
    local e = entry(raw)
    if e then wanted[#wanted + 1] = e else vlog("ECHEC entree illisible ignoree") end
  end
  vlog("parametres : " .. SOURCE .. ", " .. #wanted .. " entite(s), " .. #refs .. " reference(s), sol " .. sol)

  -- Plan : une rangée par entité demandée (entité en tête, puis les références).
  local rows, y, width = {}, Y0, 0
  for k, e in ipairs(wanted) do
    local items = { e }
    for _, r in ipairs(refs) do items[#items + 1] = r end
    local row = { key = string.format("%02d-%s", k, safe(e.name)), name = e.name, items = {}, errors = {},
      cadre = type(e.cadre) == "table" and e.cadre or nil }
    local x, hmax = X0, 1
    for _, it in ipairs(items) do
      local w, h, p = footprint(it)
      if not w then
        if it == e then row.errors[#row.errors + 1] = "prototype d'entite inconnu" end
        w, h = 3, 3
      end
      row.items[#row.items + 1] = { e = it, w = w, h = h, p = p, x = x }
      x = x + w + GAP
      hmax = math.max(hmax, h)
    end
    row.x0, row.x1, row.h, row.top = X0, x - GAP, hmax, y
    row.y = y + hmax / 2
    y = y + hmax + ROW_GAP
    width = math.max(width, row.x1 - X0)
    rows[#rows + 1] = row
  end
  local x1, y1 = X0 + math.max(width, 10), math.max(y, Y0 + 10)
  Terrain.prepare_area(s, X0 - MARGIN, Y0 - MARGIN, x1 + MARGIN, y1 + MARGIN, sol)
  -- Faune : cessez-le-feu et zone vidée (les biters ne doivent ni attaquer ni passer dans le cadre).
  game.forces.player.set_cease_fire("enemy", true)
  game.forces.enemy.set_cease_fire("player", true)
  game.map_settings.enemy_expansion.enabled = false
  for _, u in ipairs(s.find_entities_filtered({ area = { { X0 - 160, Y0 - 160 }, { x1 + 160, y1 + 160 } }, force = "enemy" })) do
    u.destroy()
  end

  local out = { sol = sol, source = SOURCE, rows = {}, x0 = X0, y0 = Y0, x1 = x1, y1 = y1, opt = {
    alt_mode = PARAMS.alt_mode == true, anti_alias = PARAMS.anti_alias == true,
    gros_plans = type(PARAMS.gros_plans) == "table" and PARAMS.gros_plans or { 2 },
  } }
  local failures = 0
  for _, row in ipairs(rows) do
    for idx, it in ipairs(row.items) do
      -- Centre aligné sur la grille : tuiles entières à gauche et en haut, quelle que soit la parité.
      local cy = row.top + math.floor((row.h - it.h) / 2) + it.h / 2
      if it.p then
        local cx = it.x + it.w / 2
        local ent, errs = place(s, it.e, cx, cy, it.w, it.h, it.p)
        if idx == 1 then
          for _, er in ipairs(errs) do row.errors[#row.errors + 1] = er end
          if not ent and #errs == 0 then row.errors[#row.errors + 1] = "entite absente" end
          row.ex, row.ey, row.ew, row.eh = cx, cy, it.w, it.h
        elseif #errs > 0 then
          vlog("ECHEC reference " .. it.e.name .. " : " .. table.concat(errs, " ; "))
          failures = failures + 1
        end
      elseif idx == 1 then
        row.ex, row.ey, row.ew, row.eh = it.x + it.w / 2, cy, it.w, it.h
      end
    end
    local powered = Terrain.power(s, (row.x0 + row.x1) / 2, row.y) ~= nil
    if #row.errors > 0 then
      failures = failures + 1
      vlog("ECHEC " .. row.name .. " : " .. table.concat(row.errors, " ; "))
    else
      vlog("OK     " .. row.name .. " pose en (" .. row.ex .. ", " .. row.ey .. "), emprise " .. row.ew .. "x" .. row.eh
        .. (powered and ", alimente" or ", SANS alimentation"))
    end
    out.rows[#out.rows + 1] = {
      key = row.key, name = row.name, x0 = row.x0, x1 = row.x1, y = row.y, h = row.h,
      ex = row.ex, ey = row.ey, ew = row.ew, eh = row.eh, errors = row.errors, cadre = row.cadre,
    }
  end
  out.failures = failures
  global.vitrine = out
  vlog("BILAN : " .. (#rows - failures) .. " rangee(s) OK, " .. failures .. " ECHEC(S)")
end

--- Boîte des gros plans (tuiles, relative à la position de l'entité) : gauche, haut, droite, bas.
local function cadre_of(r)
  local c = r.cadre
  if type(c) == "table" and #c == 4 then return c[1], c[2], c[3], c[4] end
  local hw, hh = (r.ew or 1) / 2, (r.eh or 1) / 2
  local l, t, rt, b = -hw, -hh, hw, hh
  local p = game.entity_prototypes[r.name]
  if p then
    for _, box in ipairs({ p.selection_box, p.drawing_box }) do
      if box and box.left_top and box.right_bottom then
        l = math.min(l, box.left_top.x)
        t = math.min(t, box.left_top.y)
        rt = math.max(rt, box.right_bottom.x)
        b = math.max(b, box.right_bottom.y)
      end
    end
  end
  -- ombre : bande plein est, longueur au plus 1,3 × la hauteur à l'écran, partant du bord ouest au pire
  rt = math.max(rt, l + 1.3 * (b - t))
  return l, t, rt, b
end

--- Liste des captures (ordre et noms déterministes). night = valeur de daytime pour la nuit.
function V.shot_list(night)
  local list = {}
  local W = global.vitrine
  if not W then return list end
  local o = W.opt
  local function add(name, x, y, zoom, daytime, res)
    list[#list + 1] = { name = name, x = x, y = y, zoom = zoom, daytime = daytime, res = res or { 1600, 900 },
      info = o.alt_mode, aa = o.anti_alias }
  end
  local times = { { 0, "jour" }, { night, "nuit" } }
  if #W.rows > 1 then
    local cx, cy = (W.x0 + W.x1) / 2, (W.y0 + W.y1) / 2
    local zoom = math.min(1, 1600 / (32 * (W.x1 - W.x0 + 6)), 900 / (32 * (W.y1 - W.y0 + 6)))
    for _, t in ipairs(times) do add("vitrine-ensemble-" .. t[2], cx, cy, zoom, t[1]) end
  end
  for _, r in ipairs(W.rows) do
    local p = "vitrine-" .. r.key
    for _, t in ipairs(times) do
      -- Rangée entière, zoom 1 (centrée) ; début de rangée, zoom 2 (l'entité et ses premiers voisins).
      add(p .. "-rangee-z1-" .. t[2], (r.x0 + r.x1) / 2, r.y - 0.5, 1, t[1])
      add(p .. "-debut-z2-" .. t[2], r.x0 - 1 + 12.5, r.y - 0.5, 2, t[1])
    end
    -- Gros plans de l'entité seule. V0b : cadre sur la réunion des couches, OMBRE comprise, plus 16 px de
    -- marge (V0 : cadre sur l'emprise, qui coupait l'ombre du four). Boîte (tuiles, relative à l'entité) :
    -- `cadre = { gauche, haut, droite, bas }` de l'entrée si donné ; sinon drawing_box du prototype (ou sa
    -- selection_box) étendue vers l'est pour l'ombre : les ombres partent plein est et mesurent au plus
    -- 1,3 fois la hauteur à l'écran (F47, CALIBRATION §3.1).
    local bl, bt, br, bb = cadre_of(r)
    for _, z in ipairs(o.gros_plans) do
      local k = 32 * z            -- pixels par tuile
      local m = 16 / k
      -- tailles paires et centre sur la grille des pixels : les texels tombent sur les pixels comme en V0
      local pw = math.min(4096, math.max(256, 2 * math.ceil((br - bl + 2 * m) * k / 2)))
      local ph = math.min(4096, math.max(256, 2 * math.ceil((bb - bt + 2 * m) * k / 2)))
      local cx = math.floor((r.ex + (bl + br) / 2) * k + 0.5) / k
      local cy = math.floor((r.ey + (bt + bb) / 2) * k + 0.5) / k
      for _, t in ipairs(times) do
        add(string.format("%s-gros-plan-z%g-%s", p, z, t[2]), cx, cy, z, t[1], { pw, ph })
      end
    end
  end
  return list
end

return V
