--[[
  Lot UPS (13/11) : recensement du stockage persistant (outil de mesure des bancs, jamais appelé en partie).

  Parcourt la table persistante du mod et compte, par CHEMIN (clés de texte gardées, clés numériques réduites à « # »,
  profondeur bornée), le nombre d'entrées de table du sous-arbre, le nombre d'objets du jeu (LuaEntity, LuaForce...) et
  ceux qui ne sont plus valides. Lecture seule : rien n'est écrit dans le stockage, aucune décision ne lit ce résultat.
  Une table partagée par deux chemins est comptée au premier chemin rencontré (ordre des clés trié : compte stable).
]]

local R = {}

local function is_object(v)
  return type(rawget(v, "__self")) == "userdata"
end

local function sorted(t)
  local nums, strs, others = {}, {}, {}
  for k in pairs(t) do
    local tk = type(k)
    if tk == "number" then nums[#nums + 1] = k elseif tk == "string" then strs[#strs + 1] = k else others[#others + 1] = k end
  end
  table.sort(nums)
  table.sort(strs)
  local out = {}
  for _, k in ipairs(strs) do out[#out + 1] = k end
  for _, k in ipairs(nums) do out[#out + 1] = k end
  for _, k in ipairs(others) do out[#out + 1] = k end
  return out
end

--- Règle pure : rend { [chemin] = { n = entrées, obj = objets, bad = objets invalides } } pour `root`, chemins jusqu'à `depth`.
--- `valid(o)` dit si un objet du jeu est valide (doublure dans les tests).
function R.count(root, depth, valid)
  local acc, seen = {}, {}
  local function cell(path)
    local c = acc[path]
    if not c then
      c = { n = 0, obj = 0, bad = 0 }
      acc[path] = c
    end
    return c
  end
  local function walk(t, path, d)
    if seen[t] then return end
    seen[t] = true
    local c = cell(path)
    for _, k in ipairs(sorted(t)) do
      local v = t[k]
      c.n = c.n + 1
      if type(v) == "table" then
        if is_object(v) then
          c.obj = c.obj + 1
          if not valid(v) then c.bad = c.bad + 1 end
        else
          local sub = path
          if d < depth then sub = path .. "/" .. (type(k) == "number" and "#" or tostring(k)) end
          walk(v, sub, d + 1)
        end
      end
    end
  end
  walk(root, "", 0)
  return acc
end

--- Écrit le recensement au journal : une ligne par chemin d'au moins `min` entrées ou portant un objet invalide.
function R.log(root, label, depth, min)
  local acc = R.count(root, depth or 5, function(o)
    local ok, v = pcall(function() return o.valid end)
    return ok and v == true
  end)
  local paths = {}
  local total, bad = 0, 0
  for p, c in pairs(acc) do
    paths[#paths + 1] = p
    total = total + c.n
    bad = bad + c.bad
  end
  table.sort(paths)
  log(string.format("[FO-RECENSEMENT] %s total=%d invalides=%d chemins=%d", tostring(label), total, bad, #paths))
  for _, p in ipairs(paths) do
    local c = acc[p]
    if c.n >= (min or 200) or c.bad > 0 then
      log(string.format("[FO-RECENSEMENT] %s %s n=%d objets=%d invalides=%d", tostring(label), p == "" and "/" or p, c.n, c.obj, c.bad))
    end
  end
end

return R
