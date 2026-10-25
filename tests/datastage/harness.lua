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
local DUMP_TECHS = nil -- "--dump-techs <fichier>" : technologies finales (lot IA3-0)
local DUMP_PROTO = nil -- "--dump-proto type/name" : affiche un prototype VANILLA (outil de conception)
local DUMP_FINAL = nil -- "--dump-final type/name" : affiche un prototype tel que le mod le livre
for i, a in ipairs(arg) do
  if a == "--verbose" then VERBOSE = true end
  if a == "--show-suppressed" then SHOW_SUPPRESSED = true end
  if a == "--dump-recipes" then DUMP_RECIPES = arg[i + 1] end
  if a == "--dump-techs" then DUMP_TECHS = arg[i + 1] end
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

-- Option --dump-techs <fichier> (lot IA3-0) : technologies FINALES (vanilla + mod, difficulté normale), au format de
-- tests/fixtures/tech_ai3.lua : { count, time, ingredients = {{pack, n}}, prerequisites, unlocks }. Le mod réécrit le
-- coût des technologies (automation : 1 unité au lieu de 10) : les tests du cerveau doivent lire CES coûts, pas ceux
-- de base/prototypes/technology.lua. Les technologies infinies (count_formula) sont omises.
if DUMP_TECHS then
  local names = {}
  for name in pairs(modded.technology or {}) do names[#names + 1] = name end
  table.sort(names)
  local lines = { "-- Généré par tests/datastage/harness.lua --dump-techs (vanilla 1.1.91 + mod, coûts FINAUX). Ne pas éditer.", "return {" }
  local n = 0
  for _, name in ipairs(names) do
    local t = modded.technology[name]
    local body = t.normal or t
    local unit = body.unit or t.unit
    if unit and unit.count then
      local ings = {}
      for _, i in ipairs(unit.ingredients or {}) do
        local iname, amount = i.name or i[1], i.amount or i[2] or 1
        ings[#ings + 1] = string.format("{ %q, %d }", iname, amount)
      end
      local unlocks = {}
      for _, e in ipairs(body.effects or t.effects or {}) do
        if e.type == "unlock-recipe" then unlocks[#unlocks + 1] = string.format("%q", e.recipe) end
      end
      local pre = {}
      for _, p in ipairs(body.prerequisites or t.prerequisites or {}) do pre[#pre + 1] = string.format("%q", p) end
      lines[#lines + 1] = string.format("  [%q] = { count = %d, time = %s, ingredients = { %s }, prerequisites = { %s }, unlocks = { %s } },",
        name, unit.count, tostring(unit.time), table.concat(ings, ", "), table.concat(pre, ", "), table.concat(unlocks, ", "))
      n = n + 1
    end
  end
  lines[#lines + 1] = "}"
  local f = assert(io.open(DUMP_TECHS, "w"))
  f:write(table.concat(lines, "\n"), "\n")
  f:close()
  print("Technologies ecrites : " .. n .. " -> " .. DUMP_TECHS)
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
-- Images (lot A2) : tout fichier cité existe et chaque rectangle tient dans son image (tests/datastage/images.lua).
-- Étalonnage sur TOUTE la vanilla d'abord (une violation vanilla = la règle lit mal le format : le banc échoue),
-- puis les prototypes ajoutés ou modifiés par le mod, comptés par famille à niveaux ; auto-contrôle par mutants.
---------------------------------------------------------------------------------------------------
local Images = dofile(HERE .. "/images.lua")
local img = Images.new(roots)
local img_vanilla, img_vc = img.check(vanilla, nil)
local img_errors, img_mc = img.check(modded, changed)
local img_fam = {}
for key in pairs(changed) do
  local ty, name = key:match("^(.-)/(.*)$")
  local fam = name:match("^fo%-lvl%-(%a+)%-")
  if fam then
    local _, c = img.check({ [ty] = { [name] = modded[ty][name] } }, nil)
    local f = img_fam[fam] or { protos = 0, defs = 0 }
    f.protos, f.defs = f.protos + 1, f.defs + c.defs
    img_fam[fam] = f
  end
end
-- Auto-contrôle : prototypes FABRIQUÉS (fichier vanilla réel, puis mutants), et mutants d'un VRAI niveau du mod.
local img_self_fail, img_self_total = {}, 0
do
  local BASE = "__base__/graphics/entity/gun-turret/hr-gun-turret-base.png"          -- 150 × 118
  local RAISE = "__base__/graphics/entity/gun-turret/hr-gun-turret-raising.png"      -- 650 × 504
  local SHOOT = "__base__/graphics/entity/gun-turret/hr-gun-turret-shooting-1.png"   -- 264 × 2080
  local cases = {
    { "sprite juste", { filename = BASE, width = 150, height = 118 }, {} },
    { "fichier absent", { filename = "__base__/graphics/entity/gun-turret/absent.png", width = 10, height = 10 }, { manquant = 1 } },
    { "fichier du mod absent", { filename = "__" .. MOD_NAME .. "__/graphics/levels/gun/absent.png", width = 10, height = 10 }, { manquant = 1 } },
    { "rectangle décalé hors image (x = 10)", { filename = BASE, x = 10, width = 150, height = 118 }, { ["hors image"] = 1 } },
    { "rectangle trop haut (119)", { filename = BASE, width = 150, height = 119 }, { ["hors image"] = 1 } },
    { "levée vanilla 4 directions × 5 images", { filename = RAISE, width = 130, height = 126, direction_count = 4, frame_count = 5 }, {} },
    { "levée : 5 directions (une ligne de trop)", { filename = RAISE, width = 130, height = 126, direction_count = 5, frame_count = 5 }, { ["hors image"] = 1 } },
    { "colonne de 4 directions sur une image d'une ligne", { filename = BASE, width = 150, height = 118, direction_count = 4, line_length = 1 }, { ["hors image"] = 1 } },
    { "bandes vanilla (2 × 16)", { width = 132, height = 130, direction_count = 64, frame_count = 2,
      stripes = { { filename = SHOOT, width_in_frames = 2, height_in_frames = 16 } } }, {} },
    { "bande trop longue (17 lignes)", { width = 132, height = 130, direction_count = 64, frame_count = 2,
      stripes = { { filename = SHOOT, width_in_frames = 2, height_in_frames = 17 } } }, { ["hors image"] = 1 } },
    { "icône 64 px, 4 mipmaps, sur une image de 150 × 118", { icon = BASE, icon_size = 64, icon_mipmaps = 4 }, {} },
    { "icône 100 px, 4 mipmaps (188 px de large), sur une image de 150 × 118", { icon = BASE, icon_size = 100, icon_mipmaps = 4 },
      { ["hors image"] = 1 } },
    { "Sprite avec frame_count ignoré (coffre lié vanilla : 7 images déclarées, une seule dans le fichier)",
      { filename = BASE, width = 150, height = 118, frame_count = 7 }, {} },
  }
  -- mutants d'un vrai niveau de la mitrailleuse (tête du niveau le plus haut), s'il existe
  local real
  for n = 30, 2, -1 do
    local p = modded["ammo-turret"] and modded["ammo-turret"]["fo-lvl-gun-" .. n]
    if p and p.prepared_animation and p.prepared_animation.layers then real = p break end
  end
  if real then
    local l = deepcopy(real.prepared_animation.layers[1])
    cases[#cases + 1] = { "niveau réel " .. real.name .. " : tête telle quelle", { prepared_animation = { layers = { deepcopy(l) } } }, {} }
    local m1 = deepcopy(l)
    local tm = m1.filename and m1 or m1.stripes[1]
    tm.filename = tm.filename:gsub("%.png$", "-absent.png")
    cases[#cases + 1] = { "niveau réel : fichier de tête renommé (mutant)", { prepared_animation = { layers = { m1 } } }, { manquant = 1 } }
    local m2 = deepcopy(l)
    if m2.stripes then
      m2.stripes[1].height_in_frames = m2.stripes[1].height_in_frames + 1
    else
      m2.direction_count = (m2.direction_count or 1) + 1
    end
    cases[#cases + 1] = { "niveau réel : une direction de plus que la feuille (mutant)", { prepared_animation = { layers = { m2 } } }, { ["hors image"] = 1 } }
    local m3 = deepcopy(l)
    m3.hr_version.height = m3.hr_version.height + 2
    cases[#cases + 1] = { "niveau réel : cadre hr plus haut de 2 px (mutant)", { prepared_animation = { layers = { m3 } } }, { ["hors image"] = 1 } }
  end
  for i, c in ipairs(cases) do
    local raw = { ["fo-cas"] = { ["cas-" .. i] = c[2] } }
    local got = {}
    for _, e in ipairs(img.check(raw, nil)) do got[e.what] = (got[e.what] or 0) + 1 end
    -- nombre exact attendu ; pour un mutant d'un vrai niveau (feuille à bandes : une violation par bande), « au moins 1 »
    local function same(k)
      local want, have = c[3][k] or 0, got[k] or 0
      if c[1]:find("niveau réel", 1, true) and want > 0 then return have >= 1 end
      return have == want
    end
    local ok = same("manquant") and same("hors image")
    if not ok then
      img_self_fail[#img_self_fail + 1] = c[1] .. " (manquant=" .. (got.manquant or 0) .. ", hors image=" .. (got["hors image"] or 0) .. ")"
    end
  end
  img_self_total = #cases
end

---------------------------------------------------------------------------------------------------
-- Sons (lot S0) : tout fichier son cité existe, a un format lu par le moteur (.ogg, .wav, .voc) et l'en-tête de
-- ce format (tests/datastage/sounds.lua). Étalonnage sur TOUTE la vanilla d'abord, puis les prototypes ajoutés ou
-- modifiés par le mod ; auto-contrôle par mutants (dont un vrai niveau de la mitrailleuse).
---------------------------------------------------------------------------------------------------
local Sounds = dofile(HERE .. "/sounds.lua")
local snd = Sounds.new(roots)
local snd_vanilla, snd_vc = snd.check(vanilla, nil)
local snd_vfiles = snd.nfiles()
local snd_errors, snd_mc = snd.check(modded, changed)
local snd_mod_files = {}
for name in pairs(snd.files_seen) do
  if name:match("^__" .. MOD_NAME:gsub("%-", "%%-") .. "__/") then snd_mod_files[#snd_mod_files + 1] = name end
end
table.sort(snd_mod_files)
local snd_self_fail, snd_self_total = {}, 0
do
  -- fichiers jetables pour les en-têtes (effacés aussitôt) : un faux .ogg (octets PNG), un vrai en-tête WAV et VOC
  local tmp = {
    { HERE .. "/_s0_mutant_png.ogg", "\137PNG\r\n\26\n0000000000000" },
    { HERE .. "/_s0_entete.wav", "RIFF\0\0\0\0WAVEfmt 00000000" },
    { HERE .. "/_s0_entete.voc", "Creative Voice File\26\0" },
    { HERE .. "/_s0_mutant_riff.wav", "RIFF\0\0\0\0AVI LIST0000000" },
  }
  -- lot S0-suite : mutants d'un VRAI tir vanilla (Ogg Vorbis), découpés page par page
  local vf = assert(io.open(roots.base .. "/sound/fight/gun-turret-gunshot-01.ogg", "rb"))
  local vdata = vf:read("*a")
  vf:close()
  local vpages = {} -- début (1-based) de chaque page
  do
    local p = 1
    while p + 26 <= #vdata and vdata:sub(p, p + 3) == "OggS" do
      vpages[#vpages + 1] = p
      local nseg, body = vdata:byte(p + 26), 0
      for k = 1, nseg do body = body + vdata:byte(p + 26 + k) end
      p = p + 27 + nseg + body
    end
  end
  assert(#vpages >= 4, "gun-turret-gunshot-01.ogg : moins de 4 pages Ogg")
  local mid = vpages[math.floor(#vpages / 2) + 1]
  local after_mid = vpages[math.floor(#vpages / 2) + 2]
  local ident = vpages[1] + 27 + vdata:byte(vpages[1] + 26) -- début du paquet d'identification
  local function poke(s, i, c) return s:sub(1, i - 1) .. c .. s:sub(i + #c) end
  tmp[#tmp + 1] = { HERE .. "/_s0_coupe_milieu.ogg", vdata:sub(1, math.floor(#vdata * 0.6)) }
  tmp[#tmp + 1] = { HERE .. "/_s0_coupe_page.ogg", vdata:sub(1, vpages[#vpages] - 1) }
  tmp[#tmp + 1] = { HERE .. "/_s0_page_otee.ogg", vdata:sub(1, mid - 1) .. vdata:sub(after_mid) }
  tmp[#tmp + 1] = { HERE .. "/_s0_vorbiz.ogg", poke(vdata, ident + 1, "vorbiz") }
  tmp[#tmp + 1] = { HERE .. "/_s0_zero_voie.ogg", poke(vdata, ident + 11, "\0") }
  tmp[#tmp + 1] = { HERE .. "/_s0_premiere_page.ogg", vdata:sub(1, vpages[2] - 1) }
  tmp[#tmp + 1] = { HERE .. "/_s0_oggs_seul.ogg", "OggS" }
  for _, t in ipairs(tmp) do
    local f = assert(io.open(t[1], "wb"))
    f:write(t[2])
    f:close()
  end
  local tsnd = Sounds.new({ base = roots.base, core = roots.core, [MOD_NAME] = roots[MOD_NAME], ["fo-s0-jetable"] = HERE })
  local OK = "__base__/sound/fight/gun-turret-gunshot-01.ogg"
  local cases = {
    { "son vanilla présent", { sound = { { filename = OK, volume = 0.4 } } }, {} },
    { "son vanilla absent", { sound = { { filename = "__base__/sound/fight/absent-01.ogg" } } }, { manquant = 1 } },
    { "son du mod absent", { working_sound = { sound = { filename = "__" .. MOD_NAME .. "__/sound/levels/gun/absent.ogg" } } },
      { manquant = 1 } },
    { "clé sans « sound » (utility-sounds) : reconnu par l'extension, absent", { gui_click = { filename = "__core__/sound/absent-clic.ogg" } },
      { manquant = 1 } },
    { "mp3 sous une clé sound (format non lu par le moteur)", { attack_parameters = { sound = { { filename = "__base__/sound/fight/gun-turret-gunshot-01.mp3" } } } },
      { format = 1 } },
    { "image sous une clé sound : ignorée", { sound = { filename = "__base__/graphics/entity/gun-turret/hr-gun-turret-base.png" } }, {} },
    { "faux .ogg (octets PNG)", { sound = { filename = "__fo-s0-jetable__/_s0_mutant_png.ogg" } }, { ["pas un son"] = 1 } },
    { "en-tête WAV juste", { sound = { filename = "__fo-s0-jetable__/_s0_entete.wav" } }, {} },
    { "en-tête VOC juste", { sound = { filename = "__fo-s0-jetable__/_s0_entete.voc" } }, {} },
    { "faux .wav (RIFF sans WAVE)", { sound = { filename = "__fo-s0-jetable__/_s0_mutant_riff.wav" } }, { ["pas un son"] = 1 } },
    -- lot S0-suite : codec et fichier entier (tests/datastage/fixtures : vrais flux encodés par PyAV)
    { "Ogg Vorbis d'un autre encodeur (PyAV) : accepté", { sound = { filename = "__fo-s0-jetable__/fixtures/s0-vorbis-pyav.ogg" } }, {} },
    { "Ogg OPUS sous .ogg (mutant)", { sound = { filename = "__fo-s0-jetable__/fixtures/s0-opus.ogg" } }, { codec = 1 } },
    { "FLAC dans Ogg sous .ogg (mutant)", { sound = { filename = "__fo-s0-jetable__/fixtures/s0-flac.ogg" } }, { codec = 1 } },
    { "tir vanilla coupé au milieu d'une page (mutant)", { sound = { filename = "__fo-s0-jetable__/_s0_coupe_milieu.ogg" } }, { ["tronqué"] = 1 } },
    { "tir vanilla coupé entre deux pages, sans fin de flux (mutant)", { sound = { filename = "__fo-s0-jetable__/_s0_coupe_page.ogg" } }, { ["tronqué"] = 1 } },
    { "tir vanilla privé d'une page du milieu (mutant)", { sound = { filename = "__fo-s0-jetable__/_s0_page_otee.ogg" } }, { ["tronqué"] = 1 } },
    { "identification « vorbiz » (mutant)", { sound = { filename = "__fo-s0-jetable__/_s0_vorbiz.ogg" } }, { codec = 1 } },
    { "identification à 0 voie (mutant)", { sound = { filename = "__fo-s0-jetable__/_s0_zero_voie.ogg" } }, { ["Vorbis invalide"] = 1 } },
    { "réduit à sa première page (mutant)", { sound = { filename = "__fo-s0-jetable__/_s0_premiere_page.ogg" } }, { ["Vorbis invalide"] = 1 } },
    { "« OggS » seul (mutant)", { sound = { filename = "__fo-s0-jetable__/_s0_oggs_seul.ogg" } }, { ["tronqué"] = 1 } },
  }
  -- mutants d'un vrai niveau de la mitrailleuse (le plus haut qui a un son du mod)
  local real
  for n = 30, 2, -1 do
    local p = modded["ammo-turret"] and modded["ammo-turret"]["fo-lvl-gun-" .. n]
    local s = p and p.attack_parameters and p.attack_parameters.sound
    if s and s[1] and type(s[1].filename) == "string" and s[1].filename:find("__" .. MOD_NAME .. "__", 1, true) then
      real = p break
    end
  end
  if real then
    local s = deepcopy(real.attack_parameters.sound)
    cases[#cases + 1] = { "niveau réel " .. real.name .. " : son du tir tel quel", { attack_parameters = { sound = s } }, {} }
    local m1 = deepcopy(s)
    m1[1].filename = m1[1].filename:gsub("%.ogg$", "-absent.ogg")
    cases[#cases + 1] = { "niveau réel : fichier du tir renommé (mutant)", { attack_parameters = { sound = m1 } }, { manquant = 1 } }
    local m2 = deepcopy(s)
    m2[2].filename = m2[2].filename:gsub("%.ogg$", ".mp3")
    cases[#cases + 1] = { "niveau réel : tir en .mp3 (mutant)", { attack_parameters = { sound = m2 } }, { format = 1 } }
    local m3 = deepcopy(s)
    m3[#m3].filename = "__fo-s0-jetable__/fixtures/s0-opus.ogg"
    cases[#cases + 1] = { "niveau réel : un tir remplacé par un Ogg Opus (mutant)", { attack_parameters = { sound = m3 } }, { codec = 1 } }
  else
    snd_self_fail[#snd_self_fail + 1] = "aucun niveau de la mitrailleuse n'a de son du mod (lot S0) : mutants réels non joués"
  end
  for i, c in ipairs(cases) do
    local got = {}
    for _, e in ipairs(tsnd.check({ ["fo-cas"] = { ["cas-" .. i] = c[2] } }, nil)) do got[e.what] = (got[e.what] or 0) + 1 end
    local ok = true
    local KINDS = { "manquant", "format", "pas un son", "codec", "Vorbis invalide", "tronqué" }
    for _, k in ipairs(KINDS) do
      if (got[k] or 0) ~= (c[3][k] or 0) then ok = false end
    end
    for k in pairs(got) do
      local known = false
      for _, kk in ipairs(KINDS) do if k == kk then known = true end end
      if not known then ok = false end
    end
    if not ok then
      local parts = {}
      for _, k in ipairs(KINDS) do parts[#parts + 1] = k .. "=" .. (got[k] or 0) end
      snd_self_fail[#snd_self_fail + 1] = c[1] .. " (" .. table.concat(parts, ", ") .. ")"
    end
  end
  snd_self_total = #cases
  for _, t in ipairs(tmp) do os.remove(t[1]) end
end

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
-- Un cas faux de l'auto-contrôle (plus bas) compte comme une violation : la ligne « Règles moteur » seule suffit
-- à juger le banc (correction de la suite : avant, seuls le code de sortie et une ligne à part le signalaient).
print(string.format("Règles moteur : %d violation(s)%s%s", #rule_errors + #selftest_fail,
  #selftest_fail > 0 and (" (dont " .. #selftest_fail .. " cas faux de l'auto-contrôle)") or "",
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
do
  local fl = {}
  local fams = {}
  for k in pairs(img_fam) do fams[#fams + 1] = k end
  table.sort(fams)
  for _, k in ipairs(fams) do fl[#fl + 1] = k .. " " .. img_fam[k].protos .. "/" .. img_fam[k].defs end
  local nfiles = 0
  for _ in pairs(img.files_seen) do nfiles = nfiles + 1 end
  print(string.format("Images : %d violation(s) (fichier manquant ou rectangle hors image) ; étalonnage vanilla : %d "
    .. "violation(s) sur %d prototypes, %d définitions, %d icônes ; mod : %d prototypes, %d définitions, %d icônes "
    .. "(familles, prototypes/définitions : %s) ; %d fichiers lus ; auto-contrôle %d/%d",
    #img_errors, #img_vanilla, img_vc.protos, img_vc.defs, img_vc.icons, img_mc.protos, img_mc.defs, img_mc.icons,
    table.concat(fl, ", "), nfiles, img_self_total - #img_self_fail, img_self_total))
  for i = 1, math.min(#img_vanilla, 30) do
    local e = img_vanilla[i]
    print("  IMAGE (ETALONNAGE VANILLA) " .. e.what .. " " .. e.where .. " : " .. e.msg)
  end
  for i = 1, math.min(#img_errors, 60) do
    local e = img_errors[i]
    print("  IMAGE " .. e.what .. " " .. e.where .. " : " .. e.msg)
  end
  for _, f in ipairs(img_self_fail) do print("  IMAGE AUTO-CONTROLE FAUX " .. f) end
end
-- Feuilles de la mitrailleuse hors de git (D-6, correction A2) : manifeste contrôlé (présence, taille, dimensions) ;
-- un checkout ou un worktree neuf reçoit ici la commande qui régénère les PNG.
local GunSheets = dofile(HERE .. "/gun_sheets.lua")
local gun_sheets = GunSheets.check(MOD_ROOT)
for _, l in ipairs(GunSheets.lines(gun_sheets)) do print(l) end
-- Sons (lot S0)
print(string.format("Sons : %d violation(s) (fichier manquant, format non lu par le moteur, en-tête faux, .ogg autre que "
  .. "Vorbis, en-têtes Vorbis invalides, fichier tronqué) ; étalonnage "
  .. "vanilla : %d violation(s) sur %d prototypes (%d avec un son), %d définitions, %d fichiers ; mod : %d prototypes "
  .. "(%d avec un son), %d définitions, %d fichier(s) du mod ; auto-contrôle %d/%d",
  #snd_errors, #snd_vanilla, snd_vc.protos, snd_vc.with_sound, snd_vc.defs, snd_vfiles, snd_mc.protos, snd_mc.with_sound,
  snd_mc.defs, #snd_mod_files, snd_self_total - #snd_self_fail, snd_self_total))
for i = 1, math.min(#snd_vanilla, 30) do
  local e = snd_vanilla[i]
  print("  SON (ETALONNAGE VANILLA) " .. e.what .. " " .. e.where .. " : " .. e.msg)
end
for i = 1, math.min(#snd_errors, 60) do
  local e = snd_errors[i]
  print("  SON " .. e.what .. " " .. e.where .. " : " .. e.msg)
end
for _, f in ipairs(snd_self_fail) do print("  SON AUTO-CONTROLE FAUX " .. f) end
if VERBOSE then for _, n in ipairs(snd_mod_files) do print("  SON DU MOD " .. n) end end
print(string.format("Localisation : %d clé(s) manquante(s)", #missing_locale))
for i = 1, math.min(#missing_locale, 60) do print("  LOCALE " .. missing_locale[i]) end
-- Lot PNJ-VÉRIF (défaut M1) : chaque technologie que le cerveau d'équipe débloque (shared/team/config.lua,
-- T.unlocks) doit exister dans les données finales ; un nom absent est ignoré EN SILENCE par team.lua unlock()
-- (« turrets » au lieu de « gun-turret » : aucune faction ne fabriquait de tourelle). Auto-contrôle : un nom
-- inventé doit être refusé, un nom vanilla accepté.
local unlock_errors, unlock_count, unlock_self = {}, 0, 0
do
  local TC = dofile(MOD_ROOT .. "/shared/team/config.lua")
  local techs = modded.technology or {}
  local function known(name) return techs[name] ~= nil end
  if not known("turrets") then unlock_self = unlock_self + 1 end
  if known("gun-turret") then unlock_self = unlock_self + 1 end
  local levels = {}
  for level in pairs(TC.unlocks) do levels[#levels + 1] = level end
  table.sort(levels)
  for _, level in ipairs(levels) do
    for _, name in ipairs(TC.unlocks[level]) do
      unlock_count = unlock_count + 1
      if not known(name) then
        unlock_errors[#unlock_errors + 1] = string.format("niveau %d : technologie « %s » absente des données", level, name)
      end
    end
  end
end
print(string.format("Technologies des équipes (T.unlocks) : %d nom(s), %d absent(s) ; auto-contrôle %d/2",
  unlock_count, #unlock_errors, unlock_self))
for _, e in ipairs(unlock_errors) do print("  T.UNLOCKS " .. e) end
-- Lot MOD-2 : recettes par lots (shared/content/recipe_lots.lua) : chaque lot = k × sa base (quantités, durée), même
-- catégorie, caché, désactivé. Auto-contrôle : une copie d'un lot faussée (un ingrédient × 2) doit être refusée.
local lot_errors, lot_self = {}, 0
local nlots, nlot_bases = 0, 0
do
  local RL = dofile(MOD_ROOT .. "/shared/content/recipe_lots.lua")
  nlots, nlot_bases, lot_errors = RL.verify(modded.recipe)
  local probe = modded.recipe["fo-lot10-iron-gear-wheel"]
  if probe and modded.recipe["iron-gear-wheel"] then
    if #RL.verify_lot(probe, modded.recipe["iron-gear-wheel"]) == 0 then lot_self = lot_self + 1 end
    local bad = RL.copy(probe)
    local blk = bad.normal or bad
    local ing = blk.ingredients[1]
    if ing.amount then ing.amount = ing.amount * 2 else ing[2] = ing[2] * 2 end
    if #RL.verify_lot(bad, modded.recipe["iron-gear-wheel"]) > 0 then lot_self = lot_self + 1 end
  end
end
print(string.format("Recettes par lots (MOD-2) : %d lot(s) pour %d recette(s), %d écart(s) ; auto-contrôle %d/2",
  nlots, nlot_bases, #lot_errors, lot_self))
for i = 1, math.min(#lot_errors, 40) do print("  LOT " .. lot_errors[i]) end
os.exit((#new_errors == 0 and #own_paths == 0 and #missing_locale == 0 and #rule_errors == 0 and #selftest_fail == 0
  and #unlock_errors == 0 and unlock_self == 2 and #lot_errors == 0 and lot_self == 2
  and #img_errors == 0 and #img_vanilla == 0 and #img_self_fail == 0 and GunSheets.ok(gun_sheets)
  and #snd_errors == 0 and #snd_vanilla == 0 and #snd_self_fail == 0) and 0 or 1)
