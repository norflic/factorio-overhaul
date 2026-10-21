--[[
  GREFFONS : scénarios et contrôles ajoutés par d'autres lots, dans LEURS fichiers, sans modifier le banc.

  - scenarios/<nom>.lua : un scénario complet. Un nom de scénario inconnu de control.lua charge ce fichier
    (fo-autotest-params.txt : « <ticks> <nom> »).
  - checks/<nom>.lua, listés dans checks/index.lua : contrôles de plus pour le banc « content », comptés dans
    son BILAN ([FO-CONTENT]).

  Tous les require ont lieu au CHARGEMENT du mod, jamais pendant un événement (F24). Les crochets sont
  appelés sous pcall : une erreur Lua d'un greffon devient une ligne ECHEC (le banc continue et le BILAN la
  compte) au lieu d'arrêter la partie. Format et crochets : tools/autotest/README.md.
]]

local Terrain = require("terrain")

local G = {}

local MOD = "factorio-overhaul"
local ZONE_X0, ZONE_Y0, ZONE_W, ZONE_H, ZONE_STEP = 300, 240, 128, 96, 144

--- require qui distingue « fichier absent » (nil) d'un fichier présent mais en erreur (erreur levée).
local function try_require(path)
  local ok, res = pcall(require, path)
  if ok then return res end
  local msg = tostring(res)
  if msg:find("not found", 1, true) or msg:find("no such file", 1, true) then return nil, msg end
  error("greffon " .. path .. " illisible : " .. msg)
end

local function store()
  global.greffons = global.greffons or { state = {}, results = { ok = 0, fail = 0, failed = {} }, counts = {}, dead = {} }
  return global.greffons
end

--- Contexte commun passé à chaque crochet (aucune fonction n'est stockée dans global).
local function make_ctx(tag, name)
  local ctx = { name = name, tag = tag }
  function ctx.log(msg) log(tag .. " " .. msg) end
  function ctx.surface() return game.surfaces[1] end
  function ctx.call(fn, ...) return remote.call(MOD, fn, ...) end
  function ctx.remote(iface, fn, ...) return remote.call(iface, fn, ...) end
  function ctx.has(iface, fn)
    local i = remote.interfaces[iface]
    return i ~= nil and (fn == nil or i[fn] == true)
  end
  --- Table persistante propre au greffon (global du mod de test) ; à n'appeler que dans un crochet.
  function ctx.state()
    local st = store().state
    st[name] = st[name] or {}
    return st[name]
  end
  ctx.prepare_area = function(x0, y0, x1, y1, tile) return Terrain.prepare_area(game.surfaces[1], x0, y0, x1, y1, tile) end
  ctx.power = function(x, y, force) return Terrain.power(game.surfaces[1], x, y, force) end
  return ctx
end

--- Appel protégé d'un crochet ; une erreur devient un ECHEC (et le crochet `tick` est coupé).
local function run(ctx, hook, fn, ...)
  if type(fn) ~= "function" then return true end
  local ok, err = pcall(fn, ctx, ...)
  if not ok then
    ctx.fail("erreur Lua dans " .. hook, tostring(err))
    if hook == "tick" then store().dead[ctx.name] = true end
  end
  return ok
end

---------------------------------------------------------------------------------------------------
-- Scénarios greffés
---------------------------------------------------------------------------------------------------
local SCEN, SCEN_CTX, SCEN_NAME

--- Au chargement : charge scenarios/<nom>.lua si le nom n'est pas un scénario intégré. Renvoie la table.
function G.load_scenario(name, builtin)
  if builtin[name] then return nil end
  local mod, why = try_require("scenarios/" .. name)
  if not mod then
    G.missing = why
    return nil
  end
  if type(mod) ~= "table" then error("scenarios/" .. name .. ".lua doit renvoyer une table") end
  SCEN, SCEN_NAME = mod, name
  local tag = "[FO-" .. name:upper() .. "]"
  SCEN_CTX = make_ctx(tag, "scenario:" .. name)
  local function R() return store().results end
  function SCEN_CTX.ok(check, detail)
    local r = R()
    r.ok = r.ok + 1
    log(tag .. " OK     " .. check .. (detail and (" : " .. tostring(detail)) or ""))
  end
  function SCEN_CTX.fail(check, detail)
    local r = R()
    r.fail = r.fail + 1
    r.failed[#r.failed + 1] = check
    log(tag .. " ECHEC  " .. check .. (detail and (" : " .. tostring(detail)) or ""))
  end
  function SCEN_CTX.check(cond, check, detail)
    if cond then SCEN_CTX.ok(check, detail) else SCEN_CTX.fail(check, detail) end
  end
  return mod
end

function G.scenario_init()
  if not SCEN then return end
  SCEN_CTX.log("init (on_init) : " .. tostring(SCEN.description or SCEN_NAME))
  run(SCEN_CTX, "init", SCEN.init)
end

function G.scenario_tick(e)
  if not SCEN then return end
  local g = global.greffons
  if SCEN.tick and not (g and g.dead[SCEN_CTX.name]) then run(SCEN_CTX, "tick", SCEN.tick, e) end
  if e.tick == (SCEN.check_tick or 3000) and not (g and g.finished) then
    store().finished = true
    run(SCEN_CTX, "finish", SCEN.finish)
    local r = store().results
    log(string.format("%s BILAN : %d OK, %d ECHEC(S)%s", SCEN_CTX.tag, r.ok, r.fail,
      #r.failed > 0 and (" : " .. table.concat(r.failed, " | ")) or ""))
  end
end

--- Captures du scénario greffé (session avec images) ; nil si le scénario n'en déclare pas.
function G.scenario_shots(add)
  if not (SCEN and type(SCEN.shots) == "function") then return nil end
  run(SCEN_CTX, "shots", SCEN.shots, add)
  return true
end

function G.scenario_shot_delay()
  return SCEN and SCEN.shots and (SCEN.shots_delay or 90) or nil
end

---------------------------------------------------------------------------------------------------
-- Contrôles greffés au banc « content » (checks/index.lua)
---------------------------------------------------------------------------------------------------
local CHECKS = {} -- { { name, mod, ctx } } dans l'ordre de l'index

--- Au chargement de content_test.lua : charge l'index et chaque fichier listé ; `lib` = ok/fail du banc.
function G.load_checks(lib)
  local index = try_require("checks/index")
  for k, name in ipairs(type(index) == "table" and index or {}) do
    local mod = try_require("checks/" .. name)
    if type(mod) ~= "table" then error("checks/" .. name .. ".lua absent ou ne renvoie pas une table") end
    local ctx = make_ctx("[FO-CONTENT]", "check:" .. name)
    local function count(field)
      local c = store().counts
      c[name] = c[name] or { ok = 0, fail = 0 }
      c[name][field] = c[name][field] + 1
    end
    function ctx.ok(check, detail) count("ok"); lib.ok(name .. " : " .. check, detail and tostring(detail)) end
    function ctx.fail(check, detail) count("fail"); lib.fail(name .. " : " .. check, detail and tostring(detail)) end
    function ctx.check(cond, check, detail)
      if cond then ctx.ok(check, detail) else ctx.fail(check, detail) end
    end
    -- Zone réservée au greffon (hors de l'arène du banc), dans l'ordre de l'index.
    local x0 = ZONE_X0 + (k - 1) * ZONE_STEP
    ctx.zone = { x0 = x0, y0 = ZONE_Y0, x1 = x0 + ZONE_W, y1 = ZONE_Y0 + ZONE_H }
    ctx.prepare_zone = function(tile) return ctx.prepare_area(ctx.zone.x0, ctx.zone.y0, ctx.zone.x1, ctx.zone.y1, tile) end
    CHECKS[#CHECKS + 1] = { name = name, mod = mod, ctx = ctx }
  end
end

function G.content_setup()
  for _, c in ipairs(CHECKS) do run(c.ctx, "setup", c.mod.setup) end
end

function G.content_tick(e)
  local g = global.greffons
  for _, c in ipairs(CHECKS) do
    if c.mod.tick and not (g and g.dead[c.ctx.name]) then run(c.ctx, "tick", c.mod.tick, e) end
  end
end

--- Au tick de vérification du banc, avant son BILAN : verify de chaque greffon, puis une ligne de détail.
function G.content_verify()
  for _, c in ipairs(CHECKS) do run(c.ctx, "verify", c.mod.verify) end
  if #CHECKS > 0 then
    local parts = {}
    local counts = store().counts
    for _, c in ipairs(CHECKS) do
      local n = counts[c.name] or { ok = 0, fail = 0 }
      parts[#parts + 1] = string.format("%s %d OK %d ECHEC", c.name, n.ok, n.fail)
    end
    log("[FO-CONTENT] greffons (checks/index.lua) : " .. table.concat(parts, ", "))
  end
end

--- Captures déclarées par les contrôles greffés (ajoutées à la galerie « content »).
function G.content_shots(add)
  for _, c in ipairs(CHECKS) do
    if type(c.mod.shots) == "function" then
      run(c.ctx, "shots", c.mod.shots, function(name, x, y, zoom, daytime, opt)
        add("greffon-" .. c.name .. "-" .. name, x, y, zoom, daytime, opt)
      end)
    end
  end
end

return G
