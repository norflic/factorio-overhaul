-- Lot ROBOTS-JEU (3/11) : le PLAFOND DE GÉANTS partagé, hors jeu. lua5.2 tests/robots_geants_test.lua
-- Charge le vrai script/robots/armee.lua (dépendances moteur bouchées) et appelle Armee.giants : géants du registre (Torique, Héliaste,
-- Couronné), Bourdons (Armee.hooks.extra_giants) et géants du lot EXPERIMENTAUX (interface « fo-xp », sous garde). Mutants à la fin.
package.path = "./?.lua;" .. package.path

local ok, bad = 0, 0
local function check(c, nom, detail)
  if c then ok = ok + 1 else bad = bad + 1; print("[ROBOTS-GEANTS] ECHEC " .. nom .. " " .. tostring(detail or "")) end
end

local function lire(p)
  local f = assert(io.open(p, "r"))
  local s = f:read("*a")
  f:close()
  return s
end

--- Charge armee.lua (source éventuellement mutée) dans un monde bouché ; rend Armee, le stockage, l'enregistreur d'interfaces.
local function monde(source)
  local store = {}
  local interfaces = {}
  local appels = {}
  _G.defines = { events = setmetatable({}, { __index = function(_, k) return k end }) }
  _G.remote = {
    interfaces = interfaces,
    call = function(nom, fn, ...)
      appels[#appels + 1] = { nom, fn, ... }
      return interfaces[nom][fn](...)
    end,
  }
  _G.settings = { global = {} }
  _G.log = function() end
  for _, m in ipairs({ "script.core.events", "script.core.storage", "script.faction.state", "script.faction.military", "script.levels.levels" }) do
    package.loaded[m] = nil
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
  local chunk = assert(load(source, "=armee.lua"))
  local Armee = chunk()
  return Armee, store, interfaces, appels
end

local Mo = require("shared.robots.modele")
local SRC = lire("script/robots/armee.lua")

local function scenario(source)
  local Armee, store, itf, appels = monde(source)
  local l = store.robots.ledger
  local res = {}
  res.vide = Armee.giants("player")
  Mo.add(l, "player", 101, "toroid", 12)
  Mo.add(l, "player", 102, "heliast", 12)
  Mo.add(l, "player", 201, "steam-trotter", 1) -- pas un géant
  Mo.add(l, "scarlet", 301, "crowned", 12)    -- autre force
  res.registre = Armee.giants("player")
  Armee.hooks.extra_giants = function(force_name) return force_name == "player" and 1 or 0 end
  res.bourdon = Armee.giants("player")
  itf["fo-xp"] = { autre = function() return 9 end } -- interface sans « geants » : ignorée
  res.sans_fn = Armee.giants("player")
  itf["fo-xp"] = { geants = function(force_name) return force_name == "player" and 2 or 5 end }
  res.xp = Armee.giants("player")
  res.xp_rouge = Armee.giants("scarlet")
  itf["fo-xp"] = { geants = function() return nil end }      -- réponse vide : 0
  res.xp_nil = Armee.giants("player")
  res.arg = appels[#appels] and appels[#appels][3]
  return res
end

local r = scenario(SRC)
check(r.vide == 0, "registre vide : 0 géant", r.vide)
check(r.registre == 2, "registre : Torique et Héliaste du joueur (le Trotte-Vapeur et le Couronné d'une autre force ne comptent pas)", r.registre)
check(r.bourdon == 3, "un Bourdon vivant compte pour un géant", r.bourdon)
check(r.sans_fn == 3, "interface fo-xp sans « geants » : ignorée", r.sans_fn)
check(r.xp == 5, "géants EXPERIMENTAUX (fo-xp) ajoutés au même plafond", r.xp)
check(r.xp_rouge == 6, "fo-xp reçoit la force : 1 Couronné + 5 de l'autre lot pour scarlet", r.xp_rouge)
check(r.xp_nil == 3, "fo-xp rend nil : compté 0", r.xp_nil)
check(r.arg == "player", "fo-xp reçoit le NOM de la force (chaîne)", tostring(r.arg))

-- Mutants : chacun doit changer au moins un résultat ci-dessus.
local function vu(source)
  local okm, rm = pcall(scenario, source)
  if not okm then return true end
  for k, v in pairs({ vide = 0, registre = 2, bourdon = 3, sans_fn = 3, xp = 5, xp_rouge = 6, xp_nil = 3 }) do
    if rm[k] ~= v then return true end
  end
  return false
end
local function muter(a, b)
  local s, n = SRC:gsub(a:gsub("%p", "%%%0"), (b:gsub("%%", "%%%%")))
  assert(n == 1, "mutant introuvable : " .. a)
  return s
end
local MUTANTS = {
  { "sans les géants fo-xp", 'n = n + (remote.call("fo-xp", "geants", force_name) or 0)', "n = n" },
  { "sans les Bourdons", "n = n + Armee.hooks.extra_giants(force_name)", "n = n" },
  { "fo-xp sans garde de la fonction", 'itf["fo-xp"] and itf["fo-xp"].geants', 'itf["fo-xp"]' },
  { "nil de fo-xp non ramené à 0", '(remote.call("fo-xp", "geants", force_name) or 0)', 'remote.call("fo-xp", "geants", force_name)' },
}
for _, m in ipairs(MUTANTS) do check(vu(muter(m[2], m[3])), "mutant refusé : " .. m[1]) end
check(not vu(SRC), "témoin : la source du lot passe ses propres cas")

print(string.format("[ROBOTS-GEANTS] BILAN : %d OK, %d ECHEC(S)", ok, bad))
os.exit(bad == 0 and 0 or 1)
