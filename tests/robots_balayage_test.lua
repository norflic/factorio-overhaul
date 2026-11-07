-- Lot BOURDON-MINEURS (4/11) : le BALAYAGE des usines de robots ne compte qu'une fois un géant sorti pendant le même balayage. lua5.2 tests/robots_balayage_test.lua
-- Charge les vrais script/robots/armee.lua et script/robots/usine.lua (dépendances du moteur bouchées) et balaie un Portique dont la sortie
-- contient deux kits de géant (Torique, Héliaste) et un Bourdon fini, à l'âge 14 (2 géants admis). Armee.create inscrit le géant au registre
-- (Mo.add) : Armee.giants le compte déjà ; le compte « giants_made » d'avant le lot l'ajoutait une 2e fois et refusait le 2e géant.
-- Mutants à la fin : chacun est vu.
package.path = "./?.lua;" .. package.path

local ok, bad = 0, 0
local function check(c, nom, detail)
  if c then ok = ok + 1 else bad = bad + 1; print("[ROBOTS-BALAYAGE] ECHEC " .. nom .. " " .. tostring(detail or "")) end
end

local function lire(p)
  local f = assert(io.open(p, "r"))
  local s = f:read("*a")
  f:close()
  return s
end

local ARMEE, USINE = lire("script/robots/armee.lua"), lire("script/robots/usine.lua")

--- Un monde bouché, les deux modules chargés depuis leurs sources (éventuellement mutées). Rend un résultat de balayage.
local function balayer(armee_src, usine_src, age, kits)
  local store, crees, extra = {}, {}, {}
  local un = 1000
  _G.defines = { events = setmetatable({}, { __index = function(_, k) return k end }) }
  _G.remote = { interfaces = {}, call = function() return nil end, add_interface = function() end }
  _G.settings = { global = { ["fo-war-robots"] = { value = true }, ["fo-war-robots-cap"] = { value = 0 } } }
  _G.log = function() end
  _G.script = { register_on_entity_destroyed = function() return 1 end }
  for _, m in ipairs({ "script.core.events", "script.core.storage", "script.faction.state", "script.faction.military", "script.levels.levels",
    "script.robots.armee", "script.robots.ordres", "script.robots.soutien", "script.robots.geant", "script.robots.usine" }) do
    package.loaded[m] = nil
    package.preload[m] = nil
  end
  package.preload["script.core.events"] = function()
    return { on = function() end, on_died = function() end, on_nth_tick = function() end, on_init = function() end, on_configuration_changed = function() end }
  end
  package.preload["script.core.storage"] = function()
    return { declare = function(name, f) store[name] = f() end, ns = function(name) return store[name] end }
  end
  package.preload["script.faction.state"] = function() return { by_force = function() return nil end } end
  package.preload["script.faction.military"] = function() return {} end
  package.preload["script.levels.levels"] = function() return { cc_level = function() return 1 end } end
  package.preload["script.robots.ordres"] = function() return {} end
  package.preload["script.robots.soutien"] = function() return {} end
  package.preload["script.robots.geant"] = function() return {} end
  package.preload["script.robots.armee"] = function() return assert(load(armee_src, "=armee.lua"))() end
  local Armee = require("script.robots.armee")
  local Usine = assert(load(usine_src, "=usine.lua"))()
  local force = { name = "player" }
  local surface = {
    find_non_colliding_position = function(_, near) return near end,
    create_entity = function(t)
      un = un + 1
      local e = { name = t.name, type = "spider-vehicle", valid = true, unit_number = un, force = force, position = t.position } -- géants : des araignées
      crees[#crees + 1] = t.name
      return e
    end,
  }
  local contenu = {}
  for k, n in pairs(kits) do contenu[k] = n end
  local inv = {
    get_item_count = function(name) return contenu[name] or 0 end,
    remove = function(t) local n = math.min(contenu[t.name] or 0, t.count); contenu[t.name] = (contenu[t.name] or 0) - n; return n end,
    insert = function(t) contenu[t.name] = (contenu[t.name] or 0) + t.count; return t.count end,
    is_empty = function()
      for _, n in pairs(contenu) do if n > 0 then return false end end
      return true
    end,
  }
  local portique = { name = "fo-robot-gantry", valid = true, unit_number = 7, force = force, surface = surface, position = { x = 0, y = 0 },
    get_output_inventory = function() return inv end, get_recipe = function() return nil end }
  local s = store.robots
  s.age_override = { player = age }
  s.list = { 7 }
  s.factories[7] = { e = portique }
  Armee.hooks.extra_release = function(e, i, rally, ...)
    extra = { appel = true, args = select("#", ...), giants = Armee.giants("player") }
    return 0
  end
  Usine.sweep(nil)
  return { crees = crees, giants = Armee.giants("player"), extra = extra, reste = contenu }
end

local KITS = { ["fo-robot-kit-toroid"] = 1, ["fo-robot-kit-heliast"] = 1, ["fo-bourdon-item"] = 1 }
local r = balayer(ARMEE, USINE, 14, KITS)
check(#r.crees == 2 and r.giants == 2, "âge 14, 2 géants admis : les 2 kits sortent dans le même balayage", #r.crees .. " créé(s), " .. r.giants .. " géant(s)")
check(r.reste["fo-robot-kit-toroid"] == 0 and r.reste["fo-robot-kit-heliast"] == 0, "les deux kits ont quitté la sortie")
check(r.extra.appel and r.extra.args == 0, "le crochet de sortie (Bourdon) reçoit l'usine, la sortie et le ralliement, sans compte de géants en plus",
  tostring(r.extra.args))
check(r.extra.giants == 2, "au moment du crochet, Armee.giants compte déjà les 2 géants sortis (registre)", tostring(r.extra.giants))
local r13 = balayer(ARMEE, USINE, 13, KITS)
check(#r13.crees == 1 and r13.reste["fo-robot-kit-heliast"] == 1, "âge 13, 1 géant admis : le 2e kit reste en sortie", #r13.crees .. " créé(s)")

-- Mutants : l'ancien double compte (giants_made) et l'oubli du registre doivent être vus.
local function vu(armee_src, usine_src)
  local okm, rm = pcall(balayer, armee_src, usine_src, 14, KITS)
  if not okm then return true end
  local okm2, rm13 = pcall(balayer, armee_src, usine_src, 13, KITS)
  if not okm2 then return true end
  return not (#rm.crees == 2 and rm.extra.args == 0 and #rm13.crees == 1)
end
local function muter(src, a, b)
  local s, n = src:gsub(a:gsub("%p", "%%%0"), (b:gsub("%%", "%%%%")))
  assert(n == 1, "mutant introuvable : " .. a)
  return s
end
local double = muter(USINE, "local ok = Mo.can_release(Armee.release_params(force, r, Mo.queue_target(rec.queue, r.id), used))",
  "local ok = Mo.can_release(Armee.release_params(force, r, Mo.queue_target(rec.queue, r.id), used, made))")
check(vu(ARMEE, double), "mutant « géant du balayage compté deux fois » vu")
local crochet = muter(USINE, "Armee.hooks.extra_release(e, inv, rec.rally or Mo.default_rally(e.position, w.size))",
  "Armee.hooks.extra_release(e, inv, rec.rally or Mo.default_rally(e.position, w.size), made)")
check(vu(ARMEE, crochet), "mutant « compte en plus passé au crochet du Bourdon » vu")
local sans_plafond = muter(ARMEE, "local n = s and Mo.giants_of(s.ledger, force_name) or 0", "local n = 0")
check(vu(sans_plafond, USINE), "mutant « Armee.giants oublie le registre » vu")
check(not vu(ARMEE, USINE), "témoin : les sources du lot passent leurs propres cas")

print(string.format("[ROBOTS-BALAYAGE] BILAN : %d OK, %d ECHEC(S)", ok, bad))
os.exit(bad == 0 and 0 or 1)
