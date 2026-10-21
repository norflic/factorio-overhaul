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

function R.check(raw, only)
  local errors = {}
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
      end
    end
  end
  return errors
end

return R
