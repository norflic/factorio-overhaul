--[[
  Validateur de prototypes contre le schéma de la doc 1.1.91 (schema.lua).

  Contrôles, récursifs dans les structures :
    - propriétés requises absentes ;
    - propriétés inconnues (fautes de frappe : le moteur les ignore silencieusement en 1.1, d'où l'intérêt) ;
    - types de base (bool, nombres, chaînes), littéraux, tableaux, dictionnaires, tuples, unions ;
    - références croisées XxxID -> prototype existant dans data.raw (cause n°1 d'échec de chargement).

  Les erreurs portent une signature stable (sig) : celles qui apparaissent aussi sur vanilla sont du bruit
  du validateur (vanilla charge forcément) et sont ignorées par le harnais.
]]

local V = {}

local NUM = { double = true, float = true, int8 = true, int16 = true, int32 = true, int64 = true,
  uint8 = true, uint16 = true, uint32 = true, uint64 = true }

-- Parcours TOUJOURS trié : l'ordre de pairs varie d'une exécution à l'autre en Lua 5.2, et le bruit
-- vanilla de référence doit être identique à chaque passage (constaté : résultats instables sinon).
local function sorted_pairs(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    return a < b
  end)
  local i = 0
  return function()
    i = i + 1
    local k = keys[i]
    if k ~= nil then return k, t[k] end
  end
end

---------------------------------------------------------------------------------------------------
-- Index : typename -> classe ; classe -> ensemble des typenames descendants (pour les XxxID)
---------------------------------------------------------------------------------------------------
local function build_index(schema, raw)
  local idx = { typename = {}, descendants = {}, props_cache = {}, type_props_cache = {} }
  for cname, c in pairs(schema.classes) do
    if c.typename then idx.typename[c.typename] = cname end
  end
  for cname, c in pairs(schema.classes) do
    if c.typename then
      local p = cname
      while p do
        local set = idx.descendants[p]
        if not set then set = {} idx.descendants[p] = set end
        set[c.typename] = true
        p = schema.classes[p] and schema.classes[p].parent
      end
    end
  end
  idx.raw = raw
  return idx
end

local function class_props(schema, idx, cname)
  local cached = idx.props_cache[cname]
  if cached then return cached end
  local props, chain = {}, {}
  local c = cname
  while c do chain[#chain + 1] = c c = schema.classes[c] and schema.classes[c].parent end
  for i = #chain, 1, -1 do
    local cl = schema.classes[chain[i]]
    if cl then for k, v in pairs(cl.props) do props[k] = v end end
  end
  idx.props_cache[cname] = props
  return props
end

local function type_props(schema, idx, tname)
  local cached = idx.type_props_cache[tname]
  if cached then return cached end
  local props, chain = {}, {}
  local t = tname
  while t do chain[#chain + 1] = t t = schema.types[t] and schema.types[t].parent end
  for i = #chain, 1, -1 do
    local ty = schema.types[chain[i]]
    if ty then for k, v in pairs(ty.props) do props[k] = v end end
  end
  idx.type_props_cache[tname] = props
  return props
end

---------------------------------------------------------------------------------------------------
-- Vérification de types
---------------------------------------------------------------------------------------------------
local check_type -- forward

local function err(ctx, path, msg, sig)
  local list = ctx.errors
  ctx.count = ctx.count + 1
  list[#list + 1] = { where = ctx.proto .. path, msg = msg, sig = ctx.ptype .. "|" .. (sig or msg) }
end

local function check_struct(ctx, v, props, path, struct_name)
  if type(v) ~= "table" then
    err(ctx, path, "table attendue pour " .. struct_name .. ", obtenu " .. type(v), "nottable:" .. struct_name)
    return
  end
  for name, p in sorted_pairs(props) do
    if not p.optional and v[name] == nil and not (p.alt and v[p.alt] ~= nil) then
      err(ctx, path, "propriété requise absente '" .. name .. "' (" .. struct_name .. ")", "missing:" .. struct_name .. "." .. name)
    end
  end
  for k, val in sorted_pairs(v) do
    if type(k) == "string" then
      local p = props[k]
      if not p then
        for _, q in sorted_pairs(props) do if q.alt == k then p = q break end end
      end
      if not p then
        err(ctx, path, "propriété inconnue '" .. k .. "' (" .. struct_name .. ")", "unknown:" .. struct_name .. "." .. k)
      else
        check_type(ctx, val, p.type, path .. "." .. k)
      end
    end
  end
end

-- Essaie un type sans polluer les erreurs ; renvoie le nombre d'erreurs et la liste.
local function try_type(ctx, v, t, path)
  local sub = { errors = {}, count = 0, proto = ctx.proto, ptype = ctx.ptype, schema = ctx.schema, idx = ctx.idx, depth = ctx.depth }
  check_type(sub, v, t, path)
  return #sub.errors, sub.errors
end

local function check_id(ctx, v, tname, path)
  if type(v) ~= "string" then
    err(ctx, path, tname .. " doit être une chaîne", "idtype:" .. tname)
    return
  end
  local base = ctx.schema.id_refs[tname]
  if not base then return end
  local set = ctx.idx.descendants[base]
  if not set then return end
  for typename in pairs(set) do
    local list = ctx.idx.raw[typename]
    if list and list[v] then return end
  end
  err(ctx, path, "référence " .. tname .. " vers '" .. v .. "' introuvable", "ref:" .. tname .. ":" .. v)
end

check_type = function(ctx, v, t, path)
  ctx.depth = (ctx.depth or 0) + 1
  if ctx.depth > 40 then ctx.depth = ctx.depth - 1 return end
  local schema = ctx.schema
  if type(t) == "string" then
    if t == "bool" then
      if type(v) ~= "boolean" then err(ctx, path, "booléen attendu, obtenu " .. type(v), "bool") end
    elseif NUM[t] then
      if type(v) ~= "number" then err(ctx, path, "nombre attendu (" .. t .. "), obtenu " .. type(v), "num") end
    elseif t == "string" then
      if type(v) ~= "string" then err(ctx, path, "chaîne attendue, obtenu " .. type(v), "str") end
    elseif schema.id_refs[t] then
      check_id(ctx, v, t, path)
    elseif t:match("^Noise") then
      -- Expressions de bruit : unions récursives, coût exponentiel. Non validées en profondeur.
    elseif schema.types[t] then
      local ty = schema.types[t]
      local inner = ty.type
      if type(inner) == "table" and inner.ct == "struct" then
        check_struct(ctx, v, type_props(schema, ctx.idx, t), path, t)
      elseif type(inner) == "table" and inner.ct == "union" then
        -- Unions avec un membre "struct" : le struct est celui du type courant
        local best, best_n = nil, math.huge
        for _, opt in ipairs(inner.options) do
          local n, errs
          if type(opt) == "table" and opt.ct == "struct" then
            local sub = { errors = {}, count = 0, proto = ctx.proto, ptype = ctx.ptype, schema = schema, idx = ctx.idx, depth = ctx.depth }
            check_struct(sub, v, type_props(schema, ctx.idx, t), path, t)
            n, errs = #sub.errors, sub.errors
          else
            n, errs = try_type(ctx, v, opt, path)
          end
          if n == 0 then best = nil best_n = 0 break end
          if n < best_n then best, best_n = errs, n end
        end
        if best_n > 0 and best then
          for _, e in ipairs(best) do err(ctx, "", e.msg, e.sig:gsub("^[^|]*|", "")) ctx.errors[#ctx.errors].where = e.where end
        end
      else
        check_type(ctx, v, inner, path)
      end
    end
    -- types inconnus du schéma (builtins rares) : acceptés
  else
    local ct = t.ct
    if ct == "array" then
      if type(v) ~= "table" then
        err(ctx, path, "tableau attendu, obtenu " .. type(v), "array")
      else
        for i, x in ipairs(v) do check_type(ctx, x, t.value, path .. "[" .. i .. "]") end
      end
    elseif ct == "dictionary" then
      if type(v) ~= "table" then
        err(ctx, path, "dictionnaire attendu, obtenu " .. type(v), "dict")
      else
        for k, x in sorted_pairs(v) do check_type(ctx, x, t.value, path .. "[" .. tostring(k) .. "]") end
      end
    elseif ct == "literal" then
      if v ~= t.value then err(ctx, path, "valeur littérale " .. tostring(t.value) .. " attendue, obtenu " .. tostring(v),
        "literal:" .. tostring(t.value) .. ":" .. tostring(v)) end -- valeurs dans la signature : jamais masquées par le bruit vanilla
    elseif ct == "tuple" then
      if type(v) ~= "table" then
        err(ctx, path, "tuple attendu, obtenu " .. type(v), "tuple")
      else
        for i, vt in ipairs(t.values) do
          if v[i] ~= nil then check_type(ctx, v[i], vt, path .. "[" .. i .. "]") end
        end
      end
    elseif ct == "type" then
      check_type(ctx, v, t.value, path)
    elseif ct == "union" then
      local best, best_n = nil, math.huge
      for _, opt in ipairs(t.options) do
        local n, errs = try_type(ctx, v, opt, path)
        if n == 0 then best_n = 0 break end
        if n < best_n then best, best_n = errs, n end
      end
      if best_n > 0 and best then
        for _, e in ipairs(best) do err(ctx, "", e.msg, e.sig:gsub("^[^|]*|", "")) ctx.errors[#ctx.errors].where = e.where end
      end
    end
  end
  ctx.depth = ctx.depth - 1
end

---------------------------------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------------------------------
function V.validate(schema, raw, only)
  local idx = build_index(schema, raw)
  local report = { errors = {}, validated = 0 }
  for ptype, list in sorted_pairs(raw) do
    local cname = idx.typename[ptype]
    if cname then
      local props = class_props(schema, idx, cname)
      for name, proto in sorted_pairs(list) do
        local key = ptype .. "/" .. name
        if not only or only[key] then
          local ctx = { errors = report.errors, count = 0, proto = key, ptype = ptype, schema = schema, idx = idx, depth = 0 }
          check_struct(ctx, proto, props, "", cname)
          report.validated = report.validated + 1
        end
      end
    elseif not only then
      -- type de prototype inconnu du schéma
    elseif only then
      for name in pairs(list) do
        if only[ptype .. "/" .. name] then
          report.errors[#report.errors + 1] = { where = ptype .. "/" .. name, msg = "type de prototype inconnu en 1.1.91 : " .. ptype, sig = "unknown-type:" .. ptype }
        end
      end
    end
  end
  table.sort(report.errors, function(a, b) return a.where < b.where end)
  return report
end

-- Empreinte stable d'une valeur (clés triées) : détecte les prototypes modifiés.
local function fp(v, seen, out)
  local t = type(v)
  if t ~= "table" then out[#out + 1] = t:sub(1, 1) .. tostring(v) return end
  if seen[v] then out[#out + 1] = "@" return end
  seen[v] = true
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    return a < b
  end)
  out[#out + 1] = "{"
  for _, k in ipairs(keys) do
    out[#out + 1] = tostring(k) .. "="
    fp(v[k], seen, out)
  end
  out[#out + 1] = "}"
  seen[v] = nil
end

function V.fingerprints(raw)
  local res = {}
  for ptype, list in pairs(raw) do
    for name, proto in pairs(list) do
      local out = {}
      fp(proto, {}, out)
      res[ptype .. "/" .. name] = table.concat(out)
    end
  end
  return res
end

function V.changed(vanilla_fp, raw)
  local now = V.fingerprints(raw)
  local changed = {}
  for key, f in pairs(now) do
    if vanilla_fp[key] ~= f then changed[key] = true end
  end
  return changed
end

local function walk_paths(v, out, seen)
  local t = type(v)
  if t == "string" then
    if v:match("^__[%w%-_]+__/") then out[v] = true end
  elseif t == "table" then
    if seen[v] then return end
    seen[v] = true
    for _, x in pairs(v) do walk_paths(x, out, seen) end
  end
end

function V.collect_paths(raw, only)
  local out = {}
  for ptype, list in pairs(raw) do
    for name, proto in pairs(list) do
      if not only or only[ptype .. "/" .. name] then walk_paths(proto, out, {}) end
    end
  end
  return out
end

--- Ensemble des typenames descendant d'une classe (ex. "EntityPrototype").
function V.descendant_types(schema, base)
  local out = {}
  for cname, c in pairs(schema.classes) do
    if c.typename then
      local p = cname
      while p do
        if p == base then out[c.typename] = true break end
        p = schema.classes[p] and schema.classes[p].parent
      end
    end
  end
  return out
end

function V.count(raw)
  local n = 0
  for _, list in pairs(raw) do for _ in pairs(list) do n = n + 1 end end
  return n
end

function V.count_keys(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

return V
