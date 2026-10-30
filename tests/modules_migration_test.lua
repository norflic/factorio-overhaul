--[[
  Banc hors jeu du lot MODULES-MIGRATION (30/10) : modules après le chargement d'une sauvegarde d'une version
  précédente. Usage, depuis la racine du mod :   lua5.2 tests/modules_migration_test.lua

  Fait de départ (fo-logs/2026-10-30_AMELIO/TEMOIN-MIGRATION/main-0619-depuis-0618) : le banc « content » créé par la
  0.6.18 et rejoué par la 0.6.19 donnait 21 ECHEC « module … » (vitesse de 4 speed-module +1,07 au lieu de +0,80).

  1. Le VRAI script/modules/mult.lua, chargé sur un petit modèle du moteur (le moteur ADDITIONNE les effets des modules
     de la machine et de sa balise, F190, F192), rejoue le cas du banc : 30 machines posées par script SANS
     raise_built, 4 modules chacune (non suivies : somme), puis on_configuration_changed (Mult.migrate) :
     produit exact de la règle, UNE balise par machine qui en a besoin ; un second on_configuration_changed, une
     machine déjà suivie et une balise orpheline ne changent rien (aucun complément posé deux fois).
  2. Le contrôle corrigé du banc (tools/autotest/fo-autotest/module_attendu.lua) accepte les 30 machines MESURÉES du
     témoin (moteur réel, après migration) et les 30 valeurs d'une carte neuve.
  3. MUTANTS : ancien contrôle (somme toujours), complément posé deux fois, machine non recensée par la migration,
     balise dupliquée, pollution multipliée à tort, balise jamais vidée dans mult.lua (le second
     on_configuration_changed double le complément) : chacun doit échouer.
]]

package.path = "./?.lua;./tools/autotest/fo-autotest/?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local MM = require("shared.content.module_mult")
local M = require("shared.content.modules")
local A = require("module_attendu")

---------------------------------------------------------------------------------------------------
-- Témoin mesuré en moteur réel (benchmark.log du témoin, 30 lignes « module ») :
-- { nom, vitesse, productivité, conso, pollution MESURÉES,   puis les 4 valeurs « att. » de l'ancien contrôle }
---------------------------------------------------------------------------------------------------
local TEMOIN = {
  { "speed-module", 1.07, 0.00, 0.57, 0.00,   0.80, 0.00, 0.48, 0.00 },
  { "speed-module-2", 1.86, 0.00, 0.94, 0.00,   1.20, 0.00, 0.72, 0.00 },
  { "speed-module-3", 2.84, 0.00, 1.36, 0.00,   1.60, 0.00, 0.96, 0.00 },
  { "fo-speed-module-4", 4.06, 0.00, 1.86, 0.00,   2.00, 0.00, 1.20, 0.00 },
  { "fo-speed-module-5", 5.55, 0.00, 2.42, 0.00,   2.40, 0.00, 1.44, 0.00 },
  { "fo-speed-module-6", 7.35, 0.00, 3.07, 0.00,   2.80, 0.00, 1.68, 0.00 },
  { "fo-speed-module-7", 9.50, 0.00, 3.80, 0.00,   3.20, 0.00, 1.92, 0.00 },
  { "fo-speed-module-8", 12.03, 0.00, 4.62, 0.00,   3.60, 0.00, 2.16, 0.00 },
  { "fo-speed-module-9", 15.00, 0.00, 5.55, 0.00,   4.00, 0.00, 2.40, 0.00 },
  { "fo-speed-module-10", 18.45, 0.00, 6.59, 0.00,   4.40, 0.00, 2.64, 0.00 },
  { "productivity-module", -0.08, 0.46, 0.26, 0.20,   -0.08, 0.40, 0.24, 0.20 },
  { "productivity-module-2", -0.19, 0.75, 0.41, 0.28,   -0.20, 0.60, 0.36, 0.28 },
  { "productivity-module-3", -0.25, 1.07, 0.57, 0.40,   -0.28, 0.80, 0.48, 0.40 },
  { "fo-productivity-module-4", -0.25, 1.44, 0.75, 0.48,   -0.28, 1.00, 0.60, 0.48 },
  { "fo-productivity-module-5", -0.25, 1.86, 0.94, 0.56,   -0.28, 1.20, 0.72, 0.56 },
  { "fo-productivity-module-6", -0.25, 2.32, 1.14, 0.64,   -0.28, 1.40, 0.84, 0.64 },
  { "fo-productivity-module-7", -0.25, 2.84, 1.36, 0.72,   -0.28, 1.60, 0.96, 0.72 },
  { "fo-productivity-module-8", -0.25, 3.42, 1.60, 0.80,   -0.28, 1.80, 1.08, 0.80 },
  { "fo-productivity-module-9", -0.25, 4.06, 1.86, 0.88,   -0.28, 2.00, 1.20, 0.88 },
  { "fo-productivity-module-10", -0.25, 4.77, 2.13, 1.00,   -0.28, 2.20, 1.32, 1.00 },
  { "effectivity-module", 0.00, 0.00, -0.76, 0.00,   0.00, 0.00, -0.80, 0.00 },
  { "effectivity-module-2", 0.00, 0.00, -0.80, 0.00,   0.00, 0.00, -0.80, 0.00 },
  { "effectivity-module-3", 0.00, 0.00, -0.80, 0.00,   0.00, 0.00, -0.80, 0.00 },
  { "fo-effectivity-module-4", 0.00, 0.00, -0.80, -0.20,   0.00, 0.00, -0.80, -0.20 },
  { "fo-effectivity-module-5", 0.00, 0.00, -0.80, -0.40,   0.00, 0.00, -0.80, -0.40 },
  { "fo-effectivity-module-6", 0.00, 0.00, -0.80, -0.60,   0.00, 0.00, -0.80, -0.60 },
  { "fo-effectivity-module-7", 0.00, 0.00, -0.80, -0.80,   0.00, 0.00, -0.80, -0.80 },
  { "fo-effectivity-module-8", 0.00, 0.00, -0.80, -0.80,   0.00, 0.00, -0.80, -0.80 },
  { "fo-effectivity-module-9", 0.00, 0.00, -0.80, -0.80,   0.00, 0.00, -0.80, -0.80 },
  { "fo-effectivity-module-10", 0.00, 0.00, -0.80, -0.80,   0.00, 0.00, -0.80, -0.80 },
}
-- Balises comptées par le journal du mod au rejeu du témoin : « 200 machine(s) à modules suivie(s), 31 balise(s) ».
local TEMOIN_BALISES_JOURNAL = 31

-- Familles et paliers, dans l'ordre du banc (setup_modules : M.ORDER puis k = 1 … M.TIERS).
local CAS = {}
for _, fam in ipairs(M.ORDER) do
  for k = 1, M.TIERS do CAS[#CAS + 1] = { fam = fam, k = k, name = M.name(fam, k) } end
end

---------------------------------------------------------------------------------------------------
-- Modèle du moteur : prototypes, machines, balises, surfaces
---------------------------------------------------------------------------------------------------
local ENG = {}

local function make_protos()
  local protos = {}
  for _, c in ipairs(CAS) do protos[c.name] = { name = c.name, module_effects = M.effect(c.fam, c.k) } end
  -- Intégration 0.6.22 : limitation des modules de productivité (le moteur la donne par LuaItemPrototype.limitations) ;
  -- les piles d'uranium n'y sont pas (data-final-fixes.lua, piste CALCULS). Les autres modules : aucune limitation.
  for _, c in ipairs(CAS) do
    protos[c.name].limitations = c.fam == "productivity" and { "iron-gear-wheel", "processing-unit" } or {}
  end
  for _, h in ipairs(MM.all_modules()) do
    protos[h.name] = { name = h.name, module_effects = { [h.effect] = { bonus = h.value } } }
  end
  return protos
end

local function new_inventory(size)
  local inv = { slots = {}, size = size }
  local mt = { __len = function(t) return t.size end, __index = {} }
  function mt.__index.get_contents()
    local out = {}
    for _, s in ipairs(inv.slots) do out[s] = (out[s] or 0) + 1 end
    return out
  end
  function mt.__index.get_item_count() return #inv.slots end
  function mt.__index.clear() inv.slots = {} end
  function mt.__index.remove(stack) -- intégration 0.6.22
    local got, keep = 0, {}
    for _, s in ipairs(inv.slots) do
      if s == stack.name and got < (stack.count or 1) then got = got + 1 else keep[#keep + 1] = s end
    end
    inv.slots = keep
    return got
  end
  function mt.__index.insert(stack)
    local put = 0
    for _ = 1, stack.count or 1 do
      if #inv.slots >= inv.size then break end
      inv.slots[#inv.slots + 1] = stack.name
      put = put + 1
    end
    return put
  end
  return setmetatable(inv, mt)
end

local function new_entity(surface, name, typ, pos, slots)
  ENG.next_unit = ENG.next_unit + 1
  local e = { name = name, type = typ, position = { x = pos.x, y = pos.y }, force = "player", surface = surface,
    unit_number = ENG.next_unit, valid = true, inv = new_inventory(slots) }
  function e.get_module_inventory() return e.inv end
  function e.get_recipe() return e.recipe and { name = e.recipe } or nil end -- intégration 0.6.22 (e.recipe : nom, ou nil)
  function e.destroy()
    e.valid = false
    for i, x in ipairs(surface.entities) do
      if x == e then table.remove(surface.entities, i) break end
    end
  end
  surface.entities[#surface.entities + 1] = e
  return e
end

local function new_surface(index)
  local s = { index = index, entities = {}, spilled = {} }
  function s.spill_item_stack(pos, stack, looted, force, belts) -- intégration 0.6.22 : relevé des objets rendus
    s.spilled[#s.spilled + 1] = { x = pos.x, y = pos.y, name = stack.name, count = stack.count, looted = looted, force = force,
      belts = belts }
  end
  function s.create_entity(p)
    local typ = p.name == MM.BEACON and "beacon" or "assembling-machine"
    return new_entity(s, p.name, typ, { x = p.position.x or p.position[1], y = p.position.y or p.position[2] },
      p.name == MM.BEACON and MM.BEACON_SLOTS or 4)
  end
  function s.find_entities_filtered(f)
    local out = {}
    local tset
    if f.type then
      tset = {}
      for _, t in ipairs(type(f.type) == "table" and f.type or { f.type }) do tset[t] = true end
    end
    for _, e in ipairs(s.entities) do
      local okk = e.valid
      if f.name and e.name ~= f.name then okk = false end
      if tset and not tset[e.type] then okk = false end
      if f.area then
        local a = f.area
        if e.position.x < a[1][1] or e.position.x > a[2][1] or e.position.y < a[1][2] or e.position.y > a[2][2] then
          okk = false
        end
      end
      if okk then out[#out + 1] = e end
    end
    return out
  end
  return s
end

--- Effets que le moteur donne à la machine : SOMME des effets des modules de la machine et de la balise à son
--- centre (F190 : additif ; F192 : la balise cachée agit sur la machine), en centièmes ; planchers du moteur.
local function engine_effects(e)
  local protos = ENG.protos
  local tot = { speed = 0, consumption = 0, productivity = 0, pollution = 0 }
  local function add(name)
    for key, v in pairs(protos[name].module_effects) do tot[key] = tot[key] + MM.engine_cents(v.bonus) end
  end
  for _, nm in ipairs(e.inv.slots) do add(nm) end
  for _, b in ipairs(e.surface.find_entities_filtered({ name = MM.BEACON,
    area = { { e.position.x - 0.25, e.position.y - 0.25 }, { e.position.x + 0.25, e.position.y + 0.25 } } })) do
    for _, nm in ipairs(b.inv.slots) do add(nm) end
  end
  return {
    speed = math.max(tot.speed, -80) / 100, cons = math.max(tot.consumption, -80) / 100,
    prod = math.max(tot.productivity, 0) / 100, poll = math.max(tot.pollution, -80) / 100,
  }
end

--- Charge script/modules/mult.lua (source éventuellement modifiée : mutants) sur un moteur neuf.
local function load_mult(patch)
  ENG = { next_unit = 0, protos = make_protos(), handlers = {}, config = {}, storage = {} }
  ENG.surface = new_surface(1)
  local stubs = {
    ["script.core.events"] = {
      on = function(id, fn) ENG.handlers[id] = fn end,
      on_nth_tick = function() end,
      on_configuration_changed = function(fn) ENG.config[#ENG.config + 1] = fn end,
      on_load = function() end,
      on_init = function() end,
    },
    ["script.core.storage"] = {
      declare = function(name, fn) ENG.storage[name] = fn() end,
      ns = function(name) return ENG.storage[name] end,
    },
    ["script.core.scheduler"] = {
      define_lane = function() end, add = function() end, remove = function() end,
      count = function() return 0 end,
    },
    ["script.levels.levels"] = { on_modules_moved = {}, on_replaced = {} },
    ["script.modules.lots"] = { consider = function() end, panel_line = function() return nil end },
  }
  for name, mod in pairs(stubs) do package.loaded[name] = mod end
  _G.defines = setmetatable({}, { __index = function(_, k)
    return setmetatable({}, { __index = function(_, kk) return k .. "." .. kk end })
  end })
  _G.game = {
    surfaces = { ENG.surface },
    item_prototypes = ENG.protos, -- intégration 0.6.22 : limitations des modules
    connected_players = {},
    get_filtered_item_prototypes = function()
      local out = {}
      for name, p in pairs(ENG.protos) do out[name] = p end
      return out
    end,
  }
  _G.remote = { add_interface = function() end }
  _G.log = function(s) ENG.last_log = s end
  local f = assert(io.open("script/modules/mult.lua", "rb"))
  local src = f:read("*a")
  f:close()
  if patch then
    local n
    src, n = src:gsub(patch[1], patch[2], 1)
    assert(n == 1, "motif du mutant introuvable : " .. patch[1])
  end
  local chunk = assert(load(src, "=mult.lua"))
  return chunk()
end

local function config_changed()
  for _, fn in ipairs(ENG.config) do fn({ mod_changes = {} }) end
end

local function count_beacons()
  return #ENG.surface.find_entities_filtered({ name = MM.BEACON })
end

--- Pose les 30 machines du banc « content » (create_entity SANS raise_built, 4 modules versés par script).
local function place_bench()
  local list = {}
  for i, c in ipairs(CAS) do
    local m = ENG.surface.create_entity({ name = "assembling-machine-3", position = { x = (i % 10) * 6 + 0.5,
      y = math.floor(i / 10) * 6 + 0.5 } })
    m.inv.insert({ name = c.name, count = 4 })
    list[#list + 1] = { cas = c, m = m }
  end
  return list
end

--- Compare toutes les machines au contrôle du banc (multiplie = machines suivies). Renvoie le nombre d'écarts.
local function ecarts(list, multiplie)
  local n = 0
  for _, x in ipairs(list) do
    local want, besoin = A.attendu(MM, A.cents(M, x.cas.fam, x.cas.k), 4, multiplie)
    local got = engine_effects(x.m)
    local bad = false
    for _, key in ipairs({ "speed", "prod", "cons", "poll" }) do
      if math.abs(got[key] - want[key]) > A.TOLERANCE then bad = true end
    end
    local b = #ENG.surface.find_entities_filtered({ name = MM.BEACON, area = { { x.m.position.x - 0.25,
      x.m.position.y - 0.25 }, { x.m.position.x + 0.25, x.m.position.y + 0.25 } } })
    if b ~= ((multiplie and besoin) and 1 or 0) then bad = true end
    if bad then n = n + 1 end
  end
  return n
end

--- Scénario complet sur un mult.lua (éventuellement muté). Renvoie la liste des contrôles ratés (noms).
local function scenario(patch)
  local fails = {}
  local function c(cond, name) if not cond then fails[#fails + 1] = name end end
  local Mult = load_mult(patch)
  local list = place_bench()
  -- Carte neuve : aucune machine suivie, le moteur additionne.
  c(ecarts(list, false) == 0, "carte neuve : somme du moteur")
  c(count_beacons() == 0, "carte neuve : aucune balise")
  -- Une machine posée par un joueur (on_built_entity) AVANT la mise à jour : suivie tout de suite.
  local joueur = ENG.surface.create_entity({ name = "assembling-machine-3", position = { x = 100.5, y = 100.5 } })
  joueur.inv.insert({ name = "speed-module-2", count = 4 })
  ENG.handlers["events.on_built_entity"]({ created_entity = joueur })
  local want_j = A.attendu(MM, A.cents(M, "speed", 2), 4, true)
  c(math.abs(engine_effects(joueur).speed - want_j.speed) <= A.TOLERANCE, "machine du joueur suivie à la pose")
  -- Balise orpheline au centre d'une machine du banc (ancienne version, propriétaire inconnu).
  local orph = ENG.surface.create_entity({ name = MM.BEACON, position = list[1].m.position })
  orph.inv.insert({ name = MM.module_name("speed", 1, 6), count = 1 })
  -- Mise à jour du mod (sauvegarde de la version précédente) : on_configuration_changed.
  config_changed()
  c(ecarts(list, true) == 0, "après migration : produit, une balise par machine")
  c(math.abs(engine_effects(joueur).speed - want_j.speed) <= A.TOLERANCE, "machine du joueur : inchangée")
  local b1 = count_beacons()
  -- Deuxième on_configuration_changed (nouvelle version, ou contenu changé, F130) : rien ne doit changer.
  config_changed()
  c(ecarts(list, true) == 0, "second on_configuration_changed : produit inchangé")
  c(count_beacons() == b1, "second on_configuration_changed : même nombre de balises")
  -- Relecture forcée de toutes les machines (Ctrl+clic, interface) : inchangé.
  for _, x in ipairs(list) do Mult.refresh(x.m, true) end
  c(ecarts(list, true) == 0, "relecture forcée : produit inchangé")
  return fails, b1
end

---------------------------------------------------------------------------------------------------
-- Partie 1 : le vrai mult.lua sur le modèle du moteur
---------------------------------------------------------------------------------------------------
section("1. mult.lua : carte neuve, migration, seconde migration, machine du joueur, orpheline")
local fails, b1 = scenario(nil)
for _, f in ipairs(fails) do check(false, f) end
check(#fails == 0, "scénario complet sans écart (" .. #fails .. " écart(s))")
-- 30 machines du banc : 30 balises (les 30 compléments sont non nuls) + celle de la machine du joueur. Le témoin en
-- compte 31 sur 200 machines : 30 du contrôle « module » + 1 du greffon levels_machines (2 speed-module).
check(b1 == 31, "31 balises après migration (30 du banc + 1 du joueur) ; obtenu " .. tostring(b1))
check(b1 == TEMOIN_BALISES_JOURNAL, "même nombre de balises que le journal du témoin en moteur réel (31)")
-- Vitesse de 4 speed-module après migration : exactement 1,2^4 − 1 (produit, un seul complément).
do
  local want = A.attendu(MM, A.cents(M, "speed", 1), 4, true)
  check(math.abs(want.speed - (1.2 ^ 4 - 1)) < 0.006, "speed-module × 4 : +1,07 = 1,2^4 − 1")
  check(math.abs(want.speed - 0.80) > 0.2, "speed-module × 4 : la somme (+0,80) n'est PAS la règle après migration")
end

---------------------------------------------------------------------------------------------------
-- Partie 2 : le contrôle corrigé contre les mesures du moteur réel
---------------------------------------------------------------------------------------------------
section("2. contrôle du banc contre le témoin (moteur réel) et la carte neuve")
check(#TEMOIN == #CAS, "30 lignes au témoin")
local function juge_temoin(juger, sel)
  local rejets = 0
  for i, row in ipairs(TEMOIN) do
    local c = CAS[i]
    assert(row[1] == c.name, "ordre du témoin : " .. row[1] .. " / " .. c.name)
    local got = sel == "mesure" and { speed = row[2], prod = row[3], cons = row[4], poll = row[5] }
      or { speed = row[6], prod = row[7], cons = row[8], poll = row[9] }
    local migre = sel == "mesure"
    local besoin = select(2, A.attendu(MM, A.cents(M, c.fam, c.k), 4, migre))
    local etat = { migre = migre, suivie = migre, balises = (migre and besoin) and 1 or 0 }
    local bon = juger(A.cents(M, c.fam, c.k), etat, got)
    if not bon then rejets = rejets + 1 end
  end
  return rejets
end
local function juger_vrai(c, etat, got) return (A.juger(MM, c, 4, etat, got)) end
check(juge_temoin(juger_vrai, "mesure") == 0, "témoin APRÈS migration (mesuré) : 30 machines acceptées")
check(juge_temoin(juger_vrai, "neuve") == 0, "carte neuve (valeurs de la somme) : 30 machines acceptées")
-- Les cents lus par le contrôle sont ceux du mod (M.cents) pour les effets de la règle.
do
  local same = true
  for _, c in ipairs(CAS) do
    local a, b = A.cents(M, c.fam, c.k), M.cents(c.fam, c.k)
    for _, key in ipairs({ "speed", "consumption", "productivity", "pollution" }) do
      if (a[key] or 0) ~= (b[key] or 0) then same = false end
    end
  end
  check(same, "A.cents = M.cents sur les 30 modules")
end
-- Carte migrée mais machine NON suivie : refusée, même avec les valeurs de la somme.
do
  local c = A.cents(M, "speed", 1)
  local bon = A.juger(MM, c, 4, { migre = true, suivie = false, balises = 0 },
    { speed = 0.80, prod = 0, cons = 0.48, poll = 0 })
  check(not bon, "migration : une machine non recensée est refusée")
end

---------------------------------------------------------------------------------------------------
-- Partie 3 : mutants
---------------------------------------------------------------------------------------------------
section("3. mutants")
local mutants = 0
local function mutant(name, detected)
  mutants = mutants + 1
  check(detected, "mutant « " .. name .. " » détecté")
end
-- M1 : ancien contrôle (la somme, toujours) contre le témoin mesuré.
mutant("ancien contrôle : somme toujours", juge_temoin(function(c, etat, got)
  local want = A.attendu(MM, c, 4, false)
  for _, key in ipairs({ "speed", "prod", "cons", "poll" }) do
    if math.abs(got[key] - want[key]) > A.TOLERANCE then return false end
  end
  return true
end, "mesure") == 21)
-- M2 : complément posé deux fois (S + 2C) : rejeté sur les 30 machines.
do
  local rejets = 0
  for _, c in ipairs(CAS) do
    local cc = A.cents(M, c.fam, c.k)
    local one = { speed = cc.speed, consumption = cc.consumption, productivity = cc.productivity }
    local comp = MM.complements({ one, one, one, one })
    local function dbl(eff) return comp[eff].s + 2 * comp[eff].c end
    local got = { speed = math.max(dbl("speed"), -80) / 100, cons = math.max(dbl("consumption"), -80) / 100,
      prod = math.max(dbl("productivity"), 0) / 100, poll = math.max(cc.pollution * 4, -80) / 100 }
    if not A.juger(MM, cc, 4, { migre = true, suivie = true, balises = 1 }, got) then rejets = rejets + 1 end
  end
  -- Efficacité 2 à 10 : la somme et le produit sont tous deux au plancher (−80 %) : invisibles aux valeurs.
  mutant("complément posé deux fois", rejets >= 21)
end
-- M3 : migration qui ne recense pas (valeurs de la somme, machine non suivie, carte migrée).
mutant("machine non recensée par la migration", juge_temoin(function(c, etat, got)
  return (A.juger(MM, c, 4, { migre = true, suivie = false, balises = 0 }, got))
end, "neuve") == 30)
-- M4 : balise dupliquée (2 balises au centre) : refusée par le compte, même si les valeurs étaient justes.
mutant("balise dupliquée", juge_temoin(function(c, etat, got)
  local besoin = select(2, A.attendu(MM, c, 4, true))
  return (A.juger(MM, c, 4, { migre = true, suivie = true, balises = besoin and 2 or 1 }, got))
end, "mesure") == 30)
-- M5 : pollution multipliée à tort par le contrôle : rejette des machines justes.
mutant("pollution multipliée à tort", juge_temoin(function(c, etat, got)
  local want = A.attendu(MM, c, 4, true)
  if (c.pollution or 0) ~= 0 then
    want.poll = math.max(((100 + c.pollution) ^ 4 / 100 ^ 3 - 100) / 100, -0.8)
  end
  for _, key in ipairs({ "speed", "prod", "cons", "poll" }) do
    if math.abs(got[key] - want[key]) > A.TOLERANCE then return false end
  end
  return true
end, "mesure") > 0)
-- M6 : mult.lua dont la balise n'est jamais vidée avant d'être remplie : le second on_configuration_changed
-- doublerait le complément (hypothèse « complément posé deux fois » de la consigne).
do
  local f6 = scenario({ "inv%.clear%(%)\n", "\n" })
  mutant("mult.lua : balise jamais vidée (complément doublé)", #f6 > 0)
end
-- M7 : mult.lua dont la migration crée une NOUVELLE balise à chaque appel (balise dupliquée).
do
  local f7 = scenario({ "if not %(b and b%.valid%) then\n    b = e%.surface%.create_entity",
    "if true then\n    b = e.surface.create_entity" })
  mutant("mult.lua : nouvelle balise à chaque relecture", #f7 > 0)
end
-- M8 : mult.lua dont la migration ne recense pas les machines (Mult.track retiré de migrate).
do
  local f8 = scenario({ "local rec = Mult%.track%(e%)\n      if rec then", "local rec = nil\n      if rec then" })
  mutant("mult.lua : migration qui ne recense pas", #f8 > 0)
end

---------------------------------------------------------------------------------------------------
-- Partie 4 (intégration 0.6.22, piste CALCULS, risque 1 de son relecteur) : une sauvegarde où des modules de productivité
-- sont dans une machine de piles d'uranium (productivité retirée de ces recettes) : la migration les rend.
---------------------------------------------------------------------------------------------------
section("4. modules interdits par la recette rendus à la migration")
local function scenario_eject(patch)
  load_mult(patch)
  local function machine(x, recipe, mod)
    local m = ENG.surface.create_entity({ name = "assembling-machine-3", position = { x = x, y = 0.5 } })
    m.recipe = recipe
    m.inv.insert({ name = mod, count = 4 })
    return m
  end
  local u = machine(200.5, "uranium-fuel-cell", "productivity-module-3")
  local g = machine(210.5, "iron-gear-wheel", "productivity-module-3")
  local v = machine(220.5, "uranium-fuel-cell", "speed-module-3")
  local n = machine(230.5, nil, "productivity-module-2") -- sans recette : rien n'est jugé
  config_changed()
  return u, g, v, n
end
do
  local u, g, v, n = scenario_eject(nil)
  local sp = ENG.surface.spilled
  check(u.inv.get_item_count() == 0, "piles d'uranium : les 4 modules de productivité sont sortis de la machine")
  check(#sp == 1 and sp[1].name == "productivity-module-3" and sp[1].count == 4 and sp[1].x == u.position.x
    and sp[1].looted == true and sp[1].force == u.force, "rendus au sol près de la machine, à ramasser par sa force")
  local bu = #ENG.surface.find_entities_filtered({ name = MM.BEACON, area = { { u.position.x - 0.25, u.position.y - 0.25 },
    { u.position.x + 0.25, u.position.y + 0.25 } } })
  check(bu == 0, "piles d'uranium : aucune balise de complément (plus de boucle de matière)")
  check(g.inv.get_item_count() == 4 and engine_effects(g).prod > 0, "engrenages : modules de productivité gardés et multipliés")
  check(v.inv.get_item_count() == 4 and n.inv.get_item_count() == 4, "module de vitesse, machine sans recette : gardés")
  config_changed()
  check(#ENG.surface.spilled == 1, "second on_configuration_changed : rien de plus n'est rendu")
  -- M9 : migration sans le retrait (le risque du relecteur) : les modules restent dans la machine des piles.
  local u9 = scenario_eject({ "ejected = ejected %+ Mult%.eject_forbidden%(e%)", "ejected = ejected" })
  mutant("mult.lua : modules interdits laissés dans la machine", u9.inv.get_item_count() == 4)
end

print(string.format("[MODULES-MIGRATION] BILAN : %d OK, %d ECHEC(S) ; %d mutants", passes, failures, mutants))
os.exit(failures == 0 and 0 or 1)
