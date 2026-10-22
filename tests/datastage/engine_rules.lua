--[[
  Règles de chargement du moteur 1.1.91 que le schéma de la doc ne peut pas exprimer
  (contraintes de valeur, cohérence entre champs). Chaque règle vient d'une erreur réelle du moteur
  ou d'une contrainte documentée en prose. Exécutées sur vanilla d'abord : une règle qui se déclenche
  sur vanilla est fausse et n'est pas appliquée au mod.

  Origine : session 3, premier passage en moteur réel — "Invalid range mode 'center-to-bounding-box'"
  était masqué par le bruit du validateur (signature trop générique, corrigée dans validator.lua).
]]

local R = {}

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

local ENERGY_KEYS = {
  energy_usage = true, energy_consumption = true, buffer_capacity = true, input_flow_limit = true,
  output_flow_limit = true, drain = true, energy_per_shot = true, fuel_value = true,
  max_power_output = true, energy_per_movement = true, energy_per_rotation = true,
  heating_energy = true, energy_per_nutrient = true, consumption = true, movement_energy_consumption = true,
}
local ENERGY_PATTERN = "^%-?%d+%.?%d*[kKMGTPEZY]?[JW]$"  -- le moteur accepte "50KJ" (vanilla)

local function walk(v, path, fn, seen)
  if type(v) ~= "table" then return end
  seen = seen or {}
  if seen[v] then return end
  seen[v] = true
  for _, k in ipairs(sorted_keys(v)) do
    local x = v[k]
    local p = path .. "." .. tostring(k)
    fn(k, x, p)
    walk(x, p, fn, seen)
  end
end

local function spawn_evo(sp) return sp.evolution_factor or sp[1] end

local function product_count(rec)
  if rec.results then return #rec.results end
  if rec.result then return 1 end
  return 0
end

---------------------------------------------------------------------------------------------------
-- Points de jeu d'une entité (suite du lot V3-T, défaut 9) : raccords de tuyau et point de dépôt d'une foreuse.
-- Règles de jeu que le schéma ne dit pas (conséquences en jeu ; ce que fait le CHARGEUR du moteur d'un prototype
-- qui les viole n'a pas été observé : il n'est pas prouvé qu'il le refuse) :
--   - « pipe-inside » : un raccord (pipe_connections[i].position, ou positions[d] pour la direction d) désigne
--     la tuile VOISINE où doit se trouver le tuyau : il tombe HORS de la boîte de collision, sinon aucun tuyau ne
--     peut s'y poser et la boîte à fluide ne se raccorde jamais ;
--   - « pipe-off-center » : ce raccord tombe sur un CENTRE de tuile une fois l'entité posée sur la grille ; la
--     grille dépend de la largeur en tuiles (tile_width, tile_height ; par défaut la boîte de collision arrondie
--     au-dessus, doc 1.1.91) : centre en x,5 pour une largeur impaire, sur un bord de tuile pour une paire ;
--     contrôle sauté pour une entité « placeable-off-grid » (posée hors grille) ;
--   - « drop-inside » : le point de dépôt d'une foreuse (vector_to_place_result) tombe HORS de sa boîte, sinon le
--     minerai tombe dans la foreuse elle-même. Exception légitime de vanilla : le chevalet de pompage (pumpjack)
--     dépose en (0, 0), mais il sort un FLUIDE par son output_fluid_box et ne dépose jamais d'objet ; une
--     foreuse à output_fluid_box n'est donc pas contrôlée (vérifié : sans cette exception, la règle se déclenche
--     sur mining-drill/pumpjack et le harness la désactive ; doc 1.1.91 de vector_to_place_result : « If the drill
--     does not produce any solid items but uses a fluidbox output instead (e.g. pumpjacks), a vector of {0,0}
--     disables the yellow arrow alt-mode indicator ») ;
--   - « drop-on-footprint » (plus stricte que la précédente, ajoutée par la suite d'intégration de V3-T) : le
--     point de dépôt tombe aussi HORS des tuiles de la foreuse (± tile_width / 2, ± tile_height / 2). Un point
--     hors de la boîte de collision mais sur les tuiles de la foreuse (marge de 0,3 tuile) tombe sur une tuile où
--     ni tapis ni coffre ne peut se poser : la foreuse 4×4 aux points vanilla (dépôt en −1,85, boîte ±1,7,
--     tuiles ±2) passe « drop-inside » et échoue ici. Vanilla la respecte : foreuse à combustible (−1,3 pour
--     des tuiles ±1) et foreuse électrique (−1,85 pour ±1,5).
-- Boîtes à fluide lues : fluid_box, input_fluid_box, output_fluid_box, fluid_boxes[i], energy_source.fluid_box
-- (même liste que fluid_boxes_of, prototypes/levels/common.lua, réécrite ici exprès : une erreur dans common.lua
-- ne doit pas aveugler le banc). Un point de la liste positions[d] (doc 1.1.91 : 4 positions, une par direction,
-- « one after another ») est contrôlé contre la boîte TOURNÉE dans la direction d (nord, est, sud, ouest ; ordre
-- supposé, aucun prototype vanilla n'utilise `positions`), largeur et hauteur échangées à l'est et à l'ouest. Le bord de la boîte
-- compte comme dedans (même convention que footprint_problems). Une entité sans collision_box n'est pas lue.
---------------------------------------------------------------------------------------------------
local EPS = 1e-9

local function xy(pt)
  if type(pt) ~= "table" then return nil end
  local x, y = pt.x or pt[1], pt.y or pt[2]
  if type(x) ~= "number" or type(y) ~= "number" then return nil end
  return x, y
end

--- Boîte { x0, y0, x1, y1 } d'une collision_box au format de l'étape data ({ {x, y}, {x, y} } ou left_top /
--- right_bottom), tournée dans la direction d (1 nord, 2 est, 3 sud, 4 ouest ; rotation horaire, y vers le sud).
local function rotated_box(cb, d)
  local lt, rb = cb.left_top or cb[1], cb.right_bottom or cb[2]
  local l, t = xy(lt)
  local r, b = xy(rb)
  if not (l and t and r and b) then return nil end
  if d == 2 then return { x0 = -b, y0 = l, x1 = -t, y1 = r } end
  if d == 3 then return { x0 = -r, y0 = -b, x1 = -l, y1 = -t } end
  if d == 4 then return { x0 = t, y0 = -r, x1 = b, y1 = -l } end
  return { x0 = l, y0 = t, x1 = r, y1 = b }
end

local function fluid_boxes_of(p)
  local out = {}
  for _, k in ipairs({ "fluid_box", "input_fluid_box", "output_fluid_box" }) do
    if type(p[k]) == "table" then out[#out + 1] = { box = p[k], where = "." .. k } end
  end
  if type(p.fluid_boxes) == "table" then
    for i, fb in ipairs(p.fluid_boxes) do
      if type(fb) == "table" then out[#out + 1] = { box = fb, where = ".fluid_boxes[" .. i .. "]" } end
    end
  end
  local es = p.energy_source
  if type(es) == "table" and type(es.fluid_box) == "table" then out[#out + 1] = { box = es.fluid_box, where = ".energy_source.fluid_box" } end
  return out
end

local function has_flag(p, flag)
  for _, f in ipairs(type(p.flags) == "table" and p.flags or {}) do if f == flag then return true end end
  return false
end

local function fmt(v) return (string.format("%.4g", v)) end

--- Contrôle les points de jeu du prototype p (clé key). add(where, rule, msg) ; stats compte entités et points lus.
local function check_points(key, p, add, stats)
  if type(p.collision_box) ~= "table" then return end
  local north = rotated_box(p.collision_box, 1)
  if not north then return end
  local w = p.tile_width or math.ceil(north.x1 - north.x0 - EPS)
  local h = p.tile_height or math.ceil(north.y1 - north.y0 - EPS)
  local grid = not has_flag(p, "placeable-off-grid")
  local seen = false
  local function inside(box, x, y)
    return x >= box.x0 - EPS and x <= box.x1 + EPS and y >= box.y0 - EPS and y <= box.y1 + EPS
  end
  local function on_center(v, tiles) return math.abs((v + tiles / 2) % 1 - 0.5) < 1e-6 end
  local function pipe(where, pt, d)
    local x, y = xy(pt)
    if not x then return end
    seen = true
    stats.points = stats.points + 1
    local box = rotated_box(p.collision_box, d)
    if inside(box, x, y) then
      add(key .. where, "pipe-inside", "raccord de tuyau (" .. fmt(x) .. ", " .. fmt(y) .. ") dans la boîte de collision ["
        .. fmt(box.x0) .. ", " .. fmt(box.x1) .. "] × [" .. fmt(box.y0) .. ", " .. fmt(box.y1) .. "]")
    end
    local tw, th = w, h
    if d == 2 or d == 4 then tw, th = h, w end
    if grid and not (on_center(x, tw) and on_center(y, th)) then
      add(key .. where, "pipe-off-center", "raccord de tuyau (" .. fmt(x) .. ", " .. fmt(y) .. ") hors des centres de tuile (entité "
        .. tw .. "×" .. th .. " tuiles)")
    end
  end
  for _, fb in ipairs(fluid_boxes_of(p)) do
    for i, pc in ipairs(type(fb.box.pipe_connections) == "table" and fb.box.pipe_connections or {}) do
      if type(pc) == "table" then
        local where = fb.where .. ".pipe_connections[" .. i .. "]"
        if pc.position then pipe(where .. ".position", pc.position, 1) end
        if type(pc.positions) == "table" then
          for d, q in ipairs(pc.positions) do pipe(where .. ".positions[" .. d .. "]", q, d) end
        end
      end
    end
  end
  if p.vector_to_place_result and not p.output_fluid_box then
    local x, y = xy(p.vector_to_place_result)
    if x then
      seen = true
      stats.points = stats.points + 1
      if inside(north, x, y) then
        add(key .. ".vector_to_place_result", "drop-inside", "point de dépôt (" .. fmt(x) .. ", " .. fmt(y)
          .. ") dans la boîte de collision [" .. fmt(north.x0) .. ", " .. fmt(north.x1) .. "] × [" .. fmt(north.y0) .. ", " .. fmt(north.y1) .. "]")
      end
      if inside({ x0 = -w / 2, y0 = -h / 2, x1 = w / 2, y1 = h / 2 }, x, y) then
        add(key .. ".vector_to_place_result", "drop-on-footprint", "point de dépôt (" .. fmt(x) .. ", " .. fmt(y)
          .. ") sur les tuiles de la foreuse (" .. w .. "×" .. h .. ", ±" .. fmt(w / 2) .. " × ±" .. fmt(h / 2) .. ")")
      end
    end
  end
  if seen then
    stats.entities = stats.entities + 1
    stats.names[#stats.names + 1] = key
  end
end

--- stats (facultatif) : { entities, points } remplis par la règle des points de jeu (preuve qu'elle a lu quelque chose).
function R.check(raw, only, stats)
  local errors = {}
  stats = stats or {}
  stats.entities, stats.points, stats.names = 0, 0, {}
  local function add(where, rule, msg) errors[#errors + 1] = { where = where, rule = rule, msg = msg } end

  for _, ptype in ipairs(sorted_keys(raw)) do
    local list = raw[ptype]
    for _, name in ipairs(sorted_keys(list)) do
      local key = ptype .. "/" .. name
      if not only or only[key] then
        local p = list[name]

        -- Chaînes d'énergie analysables ("2.5MW", "800kJ")
        walk(p, "", function(k, x, path)
          if ENERGY_KEYS[k] and type(x) == "string" and not x:match(ENERGY_PATTERN) then
            add(key .. path, "energy", "chaîne d'énergie invalide '" .. x .. "'")
          end
          -- Résistances : pourcentage <= 100
          if k == "resistances" and type(x) == "table" then
            for i, r in ipairs(x) do
              if type(r) == "table" and type(r.percent) == "number" and r.percent > 100 then
                add(key .. path .. "[" .. i .. "]", "resist", "pourcentage de résistance > 100 (" .. r.percent .. ")")
              end
            end
          end
          if k == "scale" and type(x) == "number" and x <= 0 then
            add(key .. path, "scale", "échelle de sprite <= 0")
          end
        end)

        -- Icônes : chaque couche doit connaître sa taille
        if p.icons then
          for i, layer in ipairs(p.icons) do
            if not (layer.icon_size or p.icon_size) then
              add(key .. ".icons[" .. i .. "]", "icon_size", "couche d'icône sans icon_size")
            end
          end
        elseif p.icon and not p.icon_size and type(p.icon) == "string" and ptype ~= "technology" and ptype ~= "shortcut" then
          add(key, "icon_size", "icon sans icon_size")
        end

        if ptype == "unit" then
          if (p.vision_distance or 0) > 100 then
            add(key, "vision", "vision_distance > 100 (" .. p.vision_distance .. ")")
          end
          local ap = p.attack_parameters
          if ap then
            if (ap.range or 0) <= 0 then add(key, "unit-range", "portée d'attaque <= 0") end
            if (ap.cooldown or 0) <= 0 then add(key, "unit-cooldown", "cooldown d'attaque <= 0") end
            if ap.range_mode and ap.range_mode ~= "center-to-center" and ap.range_mode ~= "bounding-box-to-bounding-box" then
              add(key, "range-mode", "range_mode invalide '" .. ap.range_mode .. "'")
            end
          end
          if (p.movement_speed or 0) <= 0 then add(key, "unit-speed", "movement_speed <= 0") end
        end

        if ptype == "unit-spawner" then
          if not p.result_units or #p.result_units == 0 then add(key, "spawner-empty", "result_units vide") end
          for i, ru in ipairs(p.result_units or {}) do
            local uname = ru.unit or ru[1]
            local pts = ru.spawn_points or ru[2] or {}
            if not (raw.unit and raw.unit[uname]) then
              add(key .. ".result_units[" .. i .. "]", "spawner-unit", "unité inconnue '" .. tostring(uname) .. "'")
            end
            local prev = -math.huge
            for j, sp in ipairs(pts) do
              local e = spawn_evo(sp)
              if e < prev then
                add(key .. ".result_units[" .. i .. "].spawn_points[" .. j .. "]", "spawn-order",
                  "points d'apparition non triés par évolution")
              end
              prev = e
            end
          end
        end

        if ptype == "recipe" then
          for _, variant in ipairs({ p, p.normal, p.expensive }) do
            if type(variant) == "table" and product_count(variant) > 1 and not (variant.main_product or p.main_product) then
              if not ((p.icon or p.icons) and p.subgroup) then
                add(key, "recipe-multi", "plusieurs produits sans main_product ni icône + sous-groupe")
              end
            end
            if type(variant) == "table" then
              for _, ing in ipairs(variant.ingredients or {}) do
                local amount = ing.amount or ing[2]
                if type(amount) == "number" and amount <= 0 then add(key, "recipe-amount", "ingrédient en quantité <= 0") end
              end
            end
          end
        end

        if ptype == "module" then
          for ek, ev in pairs(p.effect or {}) do
            if ek ~= "speed" and ek ~= "productivity" and ek ~= "consumption" and ek ~= "pollution" then
              add(key, "module-effect", "effet inconnu '" .. tostring(ek) .. "'")
            elseif type(ev) ~= "table" or type(ev.bonus) ~= "number" then
              add(key, "module-effect", "effet '" .. ek .. "' sans bonus numérique")
            end
          end
          for _, rname in ipairs(p.limitation or {}) do
            if not (raw.recipe and raw.recipe[rname]) then
              add(key, "module-limitation", "recette de limitation inconnue '" .. rname .. "'")
            end
          end
        end

        if ptype == "autoplace-control" then
          local c = p.category
          if c ~= "resource" and c ~= "terrain" and c ~= "enemy" then
            add(key, "autoplace-category", "catégorie invalide '" .. tostring(c) .. "'")
          end
        end

        if ptype == "tile" and type(p.layer) == "number" and (p.layer < 0 or p.layer > 255) then
          add(key, "tile-layer", "layer hors de [0, 255]")
        end

        if ptype == "technology" then
          for _, v in ipairs({ p, p.normal, p.expensive }) do
            if type(v) == "table" and v.unit then
              if not (v.unit.count or v.unit.count_formula) then add(key, "tech-count", "unit sans count ni count_formula") end
              if (v.unit.time or 0) <= 0 then add(key, "tech-time", "unit.time <= 0") end
            end
          end
        end

        -- Animations tournantes de tourelle (RotatedAnimation) : à fichiers multiples, « slice » est
        -- obligatoire (moteur réel, session 4 : « Key "slice" not found » sur un fût d'artillerie
        -- RotatedSprite réemployé comme animation).
        if ptype == "ammo-turret" or ptype == "electric-turret" or ptype == "fluid-turret" or ptype == "turret" then
          for _, field in ipairs({ "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation",
            "folding_animation", "ending_attack_animation", "starting_attack_animation", "energy_glow_animation" }) do
            walk({ v = p[field] }, "." .. field, function(k, x, path)
              if type(x) == "table" and x.filenames and x.slice == nil then
                add(key .. path, "rotated-slice", "animation à fichiers multiples sans slice")
              end
            end)
          end
        end

        -- Session 4, moteur réel : « Key "colors" not found » pour un arbre à variations sans palette.
        if ptype == "tree" and p.variations and not p.colors then
          add(key, "tree-colors", "arbre à variations sans colors")
        end

        if (p.max_health and p.max_health <= 0) then add(key, "health", "max_health <= 0") end

        -- Points de jeu : raccords de tuyau et point de dépôt hors de la boîte (en tête du fichier).
        check_points(key, p, add, stats)
      end
    end
  end
  return errors
end

return R
