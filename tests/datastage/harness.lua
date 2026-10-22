--[[
  Banc DATA-STAGE hors-jeu : rejoue l'étape data réelle de Factorio 1.1 en Lua 5.2.

    lua5.2 tests/datastage/harness.lua <dossier data du jeu> [racine du mod] [--verbose]

  Déroulé (même ordre que le moteur) :
    settings : settings.lua du mod -> settings.startup
    data     : core/data.lua, base/data.lua, <mod>/data.lua
    updates  : base/data-updates.lua, <mod>/data-updates.lua
    final    : <mod>/data-final-fixes.lua
  Exécuté deux fois : vanilla seule (référence + étalonnage du validateur), puis avec le mod.
  Les prototypes ajoutés ou modifiés par le mod sont validés contre le schéma 1.1.91
  (tests/datastage/schema.lua, généré depuis la doc du jeu).

  Code de sortie 0 si aucune erreur nouvelle (absente de vanilla) n'est trouvée.
]]

local HERE = (arg[0]:match("^(.*)/[^/]+$") or ".")
local DATA_DIR = assert(arg[1], "usage : harness.lua <data_dir> [mod_root] [--verbose]")
local MOD_ROOT = (arg[2] and not arg[2]:match("^%-%-")) and arg[2] or "."
local VERBOSE, SHOW_SUPPRESSED = false, false
local DUMP_RECIPES = nil
local DUMP_PROTO = nil -- "--dump-proto type/name" : affiche un prototype VANILLA (outil de conception)
local DUMP_FINAL = nil -- "--dump-final type/name" : affiche un prototype tel que le mod le livre
for i, a in ipairs(arg) do
  if a == "--verbose" then VERBOSE = true end
  if a == "--show-suppressed" then SHOW_SUPPRESSED = true end
  if a == "--dump-recipes" then DUMP_RECIPES = arg[i + 1] end
  if a == "--dump-proto" then DUMP_PROTO = arg[i + 1] end
  if a == "--dump-final" then DUMP_FINAL = arg[i + 1] end
end

local MOD_NAME = "factorio-overhaul"
local schema = dofile(HERE .. "/schema.lua")
local Validator = dofile(HERE .. "/validator.lua")

local function file_exists(p)
  local f = io.open(p, "r")
  if f then f:close() return true end
  return false
end

---------------------------------------------------------------------------------------------------
-- Environnement global de l'étape data
---------------------------------------------------------------------------------------------------
local function deepcopy(t, seen)
  if type(t) ~= "table" then return t end
  seen = seen or {}
  if seen[t] then return seen[t] end
  local c = {}
  seen[t] = c
  for k, v in pairs(t) do c[deepcopy(k, seen)] = deepcopy(v, seen) end
  return setmetatable(c, getmetatable(t))
end

local function serialize_short(x)
  if type(x) ~= "table" then return tostring(x) end
  local parts = {}
  for k, v in pairs(x) do
    parts[#parts + 1] = tostring(k) .. "=" .. (type(v) == "table" and "{...}" or tostring(v))
    if #parts > 8 then break end
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end

local function install_globals(mods)
  _G.defines = deepcopy(schema.defines)
  _G.serpent = { block = serialize_short, line = serialize_short, dump = serialize_short }
  _G.log = function(s) if VERBOSE then io.stderr:write("[log] " .. tostring(s) .. "\n") end end
  _G.localised_print = function() end
  _G.table_size = function(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
  _G.mods = mods
end

---------------------------------------------------------------------------------------------------
-- require à la Factorio : relatif au fichier courant, puis à la racine du mod, puis à core/lualib.
-- Chemins "__mod__/a/b" supportés. Cache par mod.
---------------------------------------------------------------------------------------------------
local roots = { core = DATA_DIR .. "/core", base = DATA_DIR .. "/base", [MOD_NAME] = MOD_ROOT }
local current = { mod = nil, dirs = {} }
local loaded = {}

local STUBS = {
  -- Le menu principal n'existe pas hors-jeu : base/data.lua l'exige.
  ["base:menu-simulations/menu-simulations"] = function()
    return setmetatable({}, { __index = function() return {} end })
  end,
}

local function resolve(name)
  name = name:gsub("%.lua$", "")
  local mod, rest = name:match("^__([%w%-_]+)__/(.+)$")
  if mod then
    local stub = STUBS[mod .. ":" .. rest]
    if stub then return nil, stub end
    local p = roots[mod] .. "/" .. rest .. ".lua"
    return p, nil, mod
  end
  local rel = name:find("/") and name or name:gsub("%.", "/")
  local cands = {}
  local dir = current.dirs[#current.dirs]
  if dir then cands[#cands + 1] = dir .. "/" .. rel .. ".lua" end
  cands[#cands + 1] = roots[current.mod] .. "/" .. rel .. ".lua"
  cands[#cands + 1] = roots.core .. "/lualib/" .. rel .. ".lua"
  for _, p in ipairs(cands) do
    if file_exists(p) then return p end
  end
  error("require introuvable : '" .. name .. "' (mod " .. tostring(current.mod) .. ")", 3)
end

local function run_file(path, mod)
  if os.getenv("TRACE") then io.stderr:write(string.format("%.1f %s\n", os.clock(), path)) end
  local prev_mod = current.mod
  current.mod = mod or current.mod
  current.dirs[#current.dirs + 1] = path:match("^(.*)/[^/]+$")
  local chunk, err = loadfile(path)
  if not chunk then error("erreur de syntaxe : " .. err, 0) end
  local ok, res = pcall(chunk)
  current.dirs[#current.dirs] = nil
  current.mod = prev_mod
  if not ok then error(res, 0) end
  return res
end

_G.require = function(name)
  local path, stub, mod = resolve(name)
  if stub then return stub() end
  local key = path
  local cache = loaded[current.mod]
  if cache[key] ~= nil then return cache[key] end
  local res = run_file(path, mod)
  if res == nil then res = true end
  cache[key] = res
  return res
end

local function run_stage(mod, file)
  local path = roots[mod] .. "/" .. file
  if not file_exists(path) then return false end
  loaded[mod] = loaded[mod] or {}
  current.mod = mod
  run_file(path, mod)
  return true
end

---------------------------------------------------------------------------------------------------
-- Exécution complète
---------------------------------------------------------------------------------------------------
local function new_data()
  local loader = DATA_DIR .. "/core/lualib/dataloader.lua"
  _G.data = nil
  dofile(loader)
  return _G.data
end

local baseline_globals = nil

local function run_all(with_mod)
  -- Chaque exécution repart d'un état Lua vierge : les bibliothèques vanilla posent des globales
  -- (ex. resource_autoplace__patch_metasets) qui pointeraient sinon vers l'ancien data.raw.
  if not baseline_globals then
    baseline_globals = {}
    for k in pairs(_G) do baseline_globals[k] = true end
  else
    for k in pairs(_G) do if not baseline_globals[k] then _G[k] = nil end end
  end
  loaded = {}
  local mods = { base = "1.1.91" }
  if with_mod then mods[MOD_NAME] = "0.0.1" end
  install_globals(mods)

  -- settings
  _G.settings = { startup = {}, global = {}, player = {} }
  if with_mod then
    new_data()
    run_stage(MOD_NAME, "settings.lua")
    run_stage(MOD_NAME, "settings-updates.lua")
    run_stage(MOD_NAME, "settings-final-fixes.lua")
    for stype, list in pairs(data.raw) do
      if stype:match("%-setting$") then
        for name, s in pairs(list) do
          if s.setting_type == "startup" then
            _G.settings.startup[name] = { value = s.default_value }
          end
        end
      end
    end
  end

  -- data
  new_data()
  local order = { "core", "base" }
  if with_mod then order[#order + 1] = MOD_NAME end
  for _, m in ipairs(order) do run_stage(m, "data.lua") end
  for _, m in ipairs(order) do run_stage(m, "data-updates.lua") end
  for _, m in ipairs(order) do run_stage(m, "data-final-fixes.lua") end
  return data.raw
end

local function pp(v, ind, seen)
  if type(v) ~= "table" then return type(v) == "string" and string.format("%q", v) or tostring(v) end
  if seen[v] then return "<cycle>" end
  seen[v] = true
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do
    parts[#parts + 1] = ind .. "  " .. tostring(k) .. " = " .. pp(v[k], ind .. "  ", seen)
  end
  seen[v] = nil
  return "{\n" .. table.concat(parts, ",\n") .. "\n" .. ind .. "}"
end

local function dump(raw, spec)
  local ptype, pname = spec:match("^(.-)/(.*)$")
  local proto = raw[ptype] and raw[ptype][pname]
  print(proto and pp(proto, "", {}) or ("introuvable : " .. spec))
  os.exit(0)
end

local t0 = os.clock()
if DUMP_FINAL then dump(run_all(true), DUMP_FINAL) end
local vanilla = run_all(false)
if DUMP_PROTO then dump(vanilla, DUMP_PROTO) end
local vanilla_fp = Validator.fingerprints(vanilla)
local vanilla_report = Validator.validate(schema, vanilla, nil)
local vanilla_sigs = {}
-- Signature sans le type de prototype : un faux positif du schéma vu sur vanilla est ignoré partout.
local function gsig(e) return (e.sig:gsub("^[^|]*|", "")) end
for _, e in ipairs(vanilla_report.errors) do vanilla_sigs[gsig(e)] = (vanilla_sigs[gsig(e)] or 0) + 1 end
local vanilla_paths = Validator.collect_paths(vanilla)

local modded = run_all(true)

-- Option --dump-recipes <fichier> : recettes normalisées (difficulté normale), telles que le runtime les
-- voit dans game.recipe_prototypes. Sert de jeu de données aux tests hors-jeu du cerveau d'équipe.
if DUMP_RECIPES then
  local function norm_list(list)
    local out = {}
    for _, x in ipairs(list or {}) do
      if x.name then
        out[#out + 1] = { type = x.type or "item", name = x.name, amount = x.amount or ((x.amount_min and x.amount_max) and (x.amount_min + x.amount_max) / 2) or 1 }
      else
        out[#out + 1] = { type = "item", name = x[1], amount = x[2] or 1 }
      end
    end
    return out
  end
  local names = {}
  for name in pairs(modded.recipe) do names[#names + 1] = name end
  table.sort(names)
  local lines = { "-- Généré par tests/datastage/harness.lua --dump-recipes (vanilla 1.1.91 + mod). Ne pas éditer.", "return {" }
  local function ser(v)
    if type(v) == "table" then
      local parts = {}
      if #v > 0 then
        for _, x in ipairs(v) do parts[#parts + 1] = ser(x) end
      else
        local ks = {}
        for k in pairs(v) do ks[#ks + 1] = k end
        table.sort(ks)
        for _, k in ipairs(ks) do parts[#parts + 1] = k .. " = " .. ser(v[k]) end
      end
      return "{ " .. table.concat(parts, ", ") .. " }"
    elseif type(v) == "string" then
      return string.format("%q", v)
    end
    return tostring(v)
  end
  for _, name in ipairs(names) do
    local r = modded.recipe[name]
    local d = r.normal or r
    local products
    if d.results then products = norm_list(d.results)
    elseif d.result then products = { { type = "item", name = d.result, amount = d.result_count or 1 } }
    else products = {} end
    local rec = {
      category = r.category or "crafting", energy = d.energy_required or 0.5,
      ingredients = norm_list(d.ingredients), products = products,
      hidden = (d.hidden or r.hidden) and true or false,
    }
    lines[#lines + 1] = string.format("  [%q] = %s,", name, ser(rec))
  end
  lines[#lines + 1] = "}"
  local f = assert(io.open(DUMP_RECIPES, "w"))
  f:write(table.concat(lines, "\n"), "\n")
  f:close()
  print("Recettes ecrites : " .. #names .. " -> " .. DUMP_RECIPES)
end
local changed = Validator.changed(vanilla_fp, modded)
local report = Validator.validate(schema, modded, changed)

local new_errors, suppressed = {}, 0
for _, e in ipairs(report.errors) do
  if vanilla_sigs[gsig(e)] then
    suppressed = suppressed + 1
    if SHOW_SUPPRESSED then print("  (bruit) " .. e.where .. " : " .. e.msg) end
  else
    new_errors[#new_errors + 1] = e
  end
end

-- Règles de chargement du moteur (valeurs, cohérence) ; une règle qui se déclenche sur vanilla est ignorée.
local Rules = dofile(HERE .. "/engine_rules.lua")
local vanilla_rules = {}
local vanilla_pts, mod_pts = {}, {}
for _, e in ipairs(Rules.check(vanilla, nil, vanilla_pts)) do
  vanilla_rules[e.rule] = true
  if VERBOSE then print("  (règle violée par vanilla, désactivée) " .. e.rule .. " " .. e.where .. " : " .. e.msg) end
end
local rule_errors = {}
for _, e in ipairs(Rules.check(modded, changed, mod_pts)) do
  if not vanilla_rules[e.rule] then rule_errors[#rule_errors + 1] = e end
end
local disabled_rules = {}
for r in pairs(vanilla_rules) do disabled_rules[#disabled_rules + 1] = r end
table.sort(disabled_rules)

-- Auto-contrôle de la règle des points de jeu (engine_rules.lua) sur des prototypes FABRIQUÉS : chaque cas dit
-- quelles règles doivent se déclencher, combien de fois. Vanilla n'utilise jamais `positions` (raccords par
-- direction) ni de foreuse plus grande que 3×3 : sans ces cas, une rotation fausse ou une règle muette
-- passeraient inaperçues. Un cas faux compte comme une violation (code de sortie 1).
local selftest_fail, selftest_total = {}, 0
do
  local RULES = { "pipe-inside", "pipe-off-center", "drop-inside", "drop-on-footprint" }
  local function drill(side, drop, pipes)
    local c = side / 2 - 0.3
    local pcs = {}
    for _, q in ipairs(pipes) do pcs[#pcs + 1] = { position = q } end
    return { type = "mining-drill", collision_box = { { -c, -c }, { c, c } }, vector_to_place_result = drop,
      input_fluid_box = { pipe_connections = pcs } }
  end
  local function flamer(positions)
    return { type = "fluid-turret", collision_box = { { -0.7, -1.2 }, { 0.7, 1.2 } },
      fluid_box = { pipe_connections = { { positions = positions } } } }
  end
  local cases = {
    { "foreuse 3×3 vanilla", drill(3, { 0, -1.85 }, { { -2, 0 }, { 2, 0 }, { 0, 2 } }), {} },
    { "foreuse 6×6 aux points vanilla (move_point oublié)", drill(6, { 0, -1.85 }, { { -2, 0 }, { 2, 0 }, { 0, 2 } }),
      { ["pipe-inside"] = 3, ["pipe-off-center"] = 3, ["drop-inside"] = 1, ["drop-on-footprint"] = 1 } },
    { "foreuse 4×4 aux points vanilla (dépôt hors de la boîte, mais sur les tuiles)",
      drill(4, { 0, -1.85 }, { { -2, 0 }, { 2, 0 }, { 0, 2 } }), { ["pipe-off-center"] = 3, ["drop-on-footprint"] = 1 } },
    { "foreuse 6×6 aux points déplacés", drill(6, { -0.5, -3.35 }, { { -3.5, -0.5 }, { 3.5, -0.5 }, { -0.5, 3.5 } }), {} },
    { "foreuse 6×6, dépôt sur le bord", drill(6, { -0.5, -2.7 }, {}), { ["drop-inside"] = 1, ["drop-on-footprint"] = 1 } },
    { "foreuse 6×6, dépôt entre la boîte et le bord des tuiles", drill(6, { -0.5, -2.9 }, {}), { ["drop-on-footprint"] = 1 } },
    { "chevalet (fluide en sortie, dépôt en 0, 0)", { type = "mining-drill", collision_box = { { -1.2, -1.2 }, { 1.2, 1.2 } },
      vector_to_place_result = { 0, 0 }, output_fluid_box = { pipe_connections = { { position = { 1, -2 } } } } }, {} },
    { "lance-flammes 2×3, raccords par direction justes", flamer({ { -1.5, 1 }, { -1, -1.5 }, { 1.5, -1 }, { 1, 1.5 } }), {} },
    { "lance-flammes 2×3, raccord nord recopié à l'est et à l'ouest", flamer({ { -1.5, 1 }, { -1.5, 1 }, { 1.5, -1 }, { -1.5, 1 } }),
      { ["pipe-off-center"] = 2 } },
    { "lance-flammes 2×3, raccord dans la boîte tournée (est)", flamer({ { -1.5, 1 }, { -1, -0.5 }, { 1.5, -1 }, { 1, 1.5 } }),
      { ["pipe-inside"] = 1 } },
    { "entité hors grille, raccord hors des centres", { type = "pipe", flags = { "placeable-off-grid" },
      collision_box = { { -0.29, -0.29 }, { 0.29, 0.29 } }, fluid_box = { pipe_connections = { { position = { 0, -0.75 } } } } }, {} },
  }
  for i, c in ipairs(cases) do
    local raw = { [c[2].type] = { ["cas-" .. i] = c[2] } }
    local got = {}
    for _, e in ipairs(Rules.check(raw, nil)) do got[e.rule] = (got[e.rule] or 0) + 1 end
    local ok = true
    for _, r in ipairs(RULES) do
      if (got[r] or 0) ~= (c[3][r] or 0) then ok = false end
    end
    if not ok then
      local parts = {}
      for _, r in ipairs(RULES) do parts[#parts + 1] = r .. "=" .. (got[r] or 0) end
      selftest_fail[#selftest_fail + 1] = c[1] .. " (" .. table.concat(parts, ", ") .. ")"
    end
  end
  selftest_total = #cases
end

local unknown_paths = {}
for p in pairs(Validator.collect_paths(modded, changed)) do
  if not vanilla_paths[p] and not p:match("^__" .. MOD_NAME:gsub("%-", "%%-") .. "__/") then
    unknown_paths[#unknown_paths + 1] = p
  end
end
table.sort(unknown_paths)
local own_paths = {}
for p in pairs(Validator.collect_paths(modded, changed)) do
  if p:match("^__" .. MOD_NAME:gsub("%-", "%%-") .. "__/") then
    local rel = p:gsub("^__[^/]+__/", "")
    if not file_exists(MOD_ROOT .. "/" .. rel) then own_paths[#own_paths + 1] = p end
  end
end
table.sort(own_paths)

---------------------------------------------------------------------------------------------------
-- Localisation : chaque nom affiché doit exister dans les fichiers de langue (vanilla ou mod).
---------------------------------------------------------------------------------------------------
local function parse_cfg(path, keys)
  local f = io.open(path, "r")
  if not f then return false end
  local section = ""
  for line in f:lines() do
    local sec = line:match("^%[([^%]]+)%]")
    if sec then
      section = sec
    else
      local k = line:match("^([^=;#%s][^=]*)=")
      if k then keys[section .. "." .. k] = true end
    end
  end
  f:close()
  return true
end

local function list_cfg(dir)
  local files = {}
  -- io.popen passe par cmd.exe sous Windows : ni `ls` ni /dev/null n'y existent.
  local windows = package.config:sub(1, 1) == "\\"
  local h = io.popen(windows and ('dir /b "' .. dir:gsub("/", "\\") .. '" 2>nul')
                              or ('ls "' .. dir .. '" 2>/dev/null'))
  if h then
    for name in h:lines() do if name:match("%.cfg$") then files[#files + 1] = dir .. "/" .. name end end
    h:close()
  end
  return files
end

local entity_types = Validator.descendant_types(schema, "EntityPrototype")
local item_types = Validator.descendant_types(schema, "ItemPrototype")
local missing_locale = {}
for _, lang in ipairs({ "fr", "en" }) do
  local keys = {}
  local have_vanilla = parse_cfg(DATA_DIR .. "/base/locale/" .. lang .. "/base.cfg", keys)
  for _, path in ipairs(list_cfg(MOD_ROOT .. "/locale/" .. lang)) do parse_cfg(path, keys) end
  if have_vanilla then
    local function check_ls(ls, where)
      if type(ls) ~= "table" then return end
      local key = ls[1]
      if type(key) == "string" and key ~= "" and not keys[key] then
        missing_locale[#missing_locale + 1] = lang .. " : " .. key .. " (" .. where .. ")"
      end
      for i = 2, #ls do check_ls(ls[i], where) end
    end
    for key in pairs(changed) do
      local ptype, name = key:match("^(.-)/(.*)$")
      local proto = modded[ptype][name]
      if name:match("^fo%-") then
        if proto.localised_name then
          check_ls(proto.localised_name, key)
        else
          local default
          if entity_types[ptype] then default = "entity-name." .. name
          elseif item_types[ptype] then
            default = (proto.place_result and not keys["item-name." .. name]) and ("entity-name." .. proto.place_result) or ("item-name." .. name)
          elseif ptype == "fluid" then default = "fluid-name." .. name
          elseif ptype == "tile" then default = "tile-name." .. name
          elseif ptype == "technology" then default = "technology-name." .. name:gsub("%-%d+$", "")
          elseif ptype == "recipe" then
            local res = proto.result or proto.main_product
            if not keys["recipe-name." .. name] and res then
              if modded.fluid[res] then
                default = "fluid-name." .. res
              else
                for itype in pairs(item_types) do
                  local it = modded[itype] and modded[itype][res]
                  if it then
                    if it.localised_name then
                      default = nil
                      check_ls(it.localised_name, key)
                    elseif keys["item-name." .. res] or not it.place_result then
                      default = "item-name." .. res
                    else
                      default = "entity-name." .. it.place_result
                    end
                    break
                  end
                end
              end
            else
              default = "recipe-name." .. name
            end
          end
          if default and not keys[default] and not (ptype == "recipe" and modded.module[name]) then
            missing_locale[#missing_locale + 1] = lang .. " : " .. default .. " (" .. key .. ")"
          end
        end
        if proto.localised_description then check_ls(proto.localised_description, key) end
      end
    end
  end
end
table.sort(missing_locale)

-- Résumé
local nchanged, ntypes = 0, {}
for key in pairs(changed) do
  nchanged = nchanged + 1
  local t = key:match("^(.-)/")
  ntypes[t] = (ntypes[t] or 0) + 1
end
local tl = {}
for t, n in pairs(ntypes) do tl[#tl + 1] = t .. "=" .. n end
table.sort(tl)

print(string.format("DATA-STAGE %s | vanilla : %d prototypes, %d signatures de bruit du validateur | mod : %d prototypes ajoutés/modifiés (%s) | %.1fs",
  schema.version, Validator.count(vanilla), Validator.count_keys(vanilla_sigs), nchanged, table.concat(tl, " "), os.clock() - t0))
if VERBOSE then
  local sl = {}
  for s, n in pairs(vanilla_sigs) do sl[#sl + 1] = string.format("%5d  %s", n, s) end
  table.sort(sl)
  print("Bruit vanilla (ignoré) :")
  for i = 1, math.min(#sl, 60) do print("  " .. sl[i]) end
end
print(string.format("Erreurs nouvelles : %d (bruit vanilla ignoré : %d) | chemins hors vanilla : %d | fichiers du mod manquants : %d",
  #new_errors, suppressed, #unknown_paths, #own_paths))
for i = 1, math.min(#new_errors, 80) do
  local e = new_errors[i]
  print("  ERREUR " .. e.where .. " : " .. e.msg)
end
print(string.format("Règles moteur : %d violation(s)%s", #rule_errors,
  #disabled_rules > 0 and (" (désactivées car vanilla les viole : " .. table.concat(disabled_rules, ", ") .. ")") or ""))
for i = 1, math.min(#rule_errors, 60) do
  local e = rule_errors[i]
  print("  REGLE " .. e.rule .. " " .. e.where .. " : " .. e.msg)
end
-- Preuve que la règle des points de jeu (engine_rules.lua : pipe-inside, pipe-off-center, drop-inside,
-- drop-on-footprint) a lu des prototypes : vanilla entière, puis les prototypes ajoutés ou modifiés par le mod.
print(string.format("  Points de jeu contrôlés (raccords de tuyau, dépôts de foreuse) : vanilla %d entités / %d points ; mod %d entités / %d points",
  vanilla_pts.entities, vanilla_pts.points, mod_pts.entities, mod_pts.points))
if VERBOSE then print("  Points de jeu, entités vanilla lues : " .. table.concat(vanilla_pts.names, " ")) end
print(string.format("  Auto-contrôle de la règle des points de jeu : %d/%d cas justes", selftest_total - #selftest_fail, selftest_total))
for _, f in ipairs(selftest_fail) do print("  AUTO-CONTROLE FAUX " .. f) end
for _, p in ipairs(unknown_paths) do print("  CHEMIN A VERIFIER " .. p) end
for _, p in ipairs(own_paths) do print("  FICHIER MANQUANT " .. p) end
print(string.format("Localisation : %d clé(s) manquante(s)", #missing_locale))
for i = 1, math.min(#missing_locale, 60) do print("  LOCALE " .. missing_locale[i]) end
os.exit((#new_errors == 0 and #own_paths == 0 and #missing_locale == 0 and #rule_errors == 0 and #selftest_fail == 0) and 0 or 1)
