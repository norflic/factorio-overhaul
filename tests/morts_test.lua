--[[
  Lot MORTS (7/11) : aiguillage des abonnés à on_entity_died par INTÉRÊT déclaré (script/core/events.lua, Events.on_died).
  Critères écrits avant le code : fo-logs\2026-11-07_MORTS\CRITERES.md.

  P5. Bus seul (copie neuve de events.lua, moteur et profileur bouchés) :
      - un abonné par Events.on(on_entity_died) reçoit TOUTES les morts ;
      - un abonné déclaré, seulement les siennes ;
      - entité invalide ou aiguillage éteint (Events.MORTS_TRIES = false) : tous ;
      - ordre d'enregistrement gardé.
  P2. Déclarations du mod :
      - 23 abonnés recensés ; chaque abonné déclaré a l'intérêt du recensement (table ATTENDU ci-dessous) ;
      - un abonné qui ne déclare rien reste « tout », il est permis et listé (groupe écarté) ;
      - pour chaque type et chaque force (« enemy » ou non), Events.died_for rend exactement les abonnés de cet intérêt, dans
        l'ordre d'enregistrement.
  P3. A/B au moteur simulé : la même partie (4 factions, votre équipe, morts de biters, de soldats, de bâtiments, de nids, d'un QG),
      avec l'aiguillage et sans lui (Events.MORTS_TRIES = false). Journal identique ligne à ligne, global identique, au moins 100 morts
      de types variés.
  P1. Hors de son intérêt, chaque abonné déclaré ne fait RIEN. Sur l'état de fin de partie, plus des entités de TOUS les noms du
      moteur simulé et de types ajoutés, à chaque force, posées près de chaque QG :
      - on appelle l'abonné SEUL, pour chaque mort hors de son intérêt et chaque tueur (aucun ; enemy, player, deux factions ; avec
        et sans cause) ;
      - global, journal, entités du monde (nombre, positions, santé), messages et dessins doivent être identiques avant et après.
      Limite dite telle quelle : exhaustif sur ces combinaisons et sur cet état, pas sur tous les états possibles.
  P4. Mutants « intérêt trop étroit », vus par P3 (journal ou global différent) ET par P1 :
      - prevision déclarée sans « unit » ;
      - reconstruction sans « electric-pole ».

  Usage : lua5.2 tests/morts_test.lua [minutes = 4]
]]
package.path = "./?.lua;" .. package.path
local minutes = tonumber(arg[1]) or 4
local M = require("tests.mock_engine")

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 print("OK     " .. msg) else fail_n = fail_n + 1 print("ECHEC : " .. msg) end
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) < type(b)
  end)
  return ks
end

--- Générateur pseudo-aléatoire déterministe (congruentiel), 1..n.
local function lcg(seed)
  local s = seed
  return function(n)
    s = (s * 1103515245 + 12345) % 2147483648
    return math.floor(s / 65536) % n + 1
  end
end

--- Source d'un module, changée (mutant) : `subs` = { { ancien, nouveau }, ... }, chaque ancien présent UNE fois exactement.
local function mutated(path, subs)
  local fh = assert(io.open(path, "rb"))
  local src = fh:read("*a")
  fh:close()
  for _, s in ipairs(subs) do
    local a, b = src:find(s[1], 1, true)
    if not a then return nil, "texte absent de " .. path .. " : " .. s[1] end
    assert(not src:find(s[1], b + 1, true), "mutant : texte présent plusieurs fois dans " .. path .. " : " .. s[1])
    src = src:sub(1, a - 1) .. s[2] .. src:sub(b + 1)
  end
  return src
end

local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

-- Types ajoutés au moteur simulé pour P1 (il n'en a pas de prototype) : un nom par type.
local EXTRA = {
  ["biter-spawner"] = "unit-spawner", ["small-worm-turret"] = "turret", ["stone-wall"] = "wall", ["gate"] = "gate",
  ["laser-turret"] = "electric-turret", ["flamethrower-turret"] = "fluid-turret", ["artillery-turret"] = "artillery-turret",
  ["spidertron"] = "spider-vehicle", ["radar"] = "radar", ["roboport"] = "roboport", ["pipe"] = "pipe",
  ["pipe-to-ground"] = "pipe-to-ground", ["underground-belt"] = "underground-belt", ["splitter"] = "splitter",
  ["logistic-chest-storage"] = "logistic-container", ["rocket-silo"] = "rocket-silo", ["car"] = "car",
  ["rock-big"] = "simple-entity", ["small-electric-pole"] = "electric-pole", ["electric-furnace"] = "furnace",
  ["item-on-ground"] = "item-entity", ["defender"] = "combat-robot", ["land-mine"] = "land-mine",
  ["electric-energy-interface"] = "electric-energy-interface", ["locomotive"] = "locomotive",
}

local MUTANTS = {
  prevision_sans_unit = { "script.ai3.prevision", "script/ai3/prevision.lua",
    { { 'types = { "unit" }, ennemi = true', 'types = { "unit-spawner" }, ennemi = true' } } },
  recon_sans_poteau = { "script.team.reconstruction", "script/team/reconstruction.lua",
    { { 'if R.ENTITY_ROLE[t] ~= "main" then', 'if R.ENTITY_ROLE[t] ~= "main" and t ~= "electric-pole" then' } } },
}

local DIED -- defines.events.on_entity_died (le moteur simulé le définit)

--- Fichier source d'une fonction (« script/ai3/prevision.lua »), chargée par require ou par un mutant.
local function src_of(fn)
  local s = debug.getinfo(fn, "S").source
  s = s:gsub("^[@=]", ""):gsub("\\", "/"):gsub("^%./", "")
  return s
end

---------------------------------------------------------------------------------------------------
-- P5 : le bus seul
---------------------------------------------------------------------------------------------------
local function p5()
  M.new_world({})
  DIED = defines.events.on_entity_died
  local saved_events, saved_prof = package.loaded["script.core.events"], package.loaded["script.core.profiler"]
  package.loaded["script.core.events"] = nil
  package.loaded["script.core.profiler"] = { start = function() end, stop = function() end }
  local real_script = _G.script
  local bound = {}
  _G.script = {
    on_init = function() end, on_load = function() end, on_configuration_changed = function() end,
    on_event = function(id, f) bound[id] = f end, on_nth_tick = function() end,
  }
  local ok, err = pcall(function()
    local Ev = require("script.core.events")
    local calls = {}
    local function rec(tag) return function() calls[#calls + 1] = tag end end
    Ev.on(DIED, rec("tout1"))
    Ev.on_died(rec("unite-ennemie"), { types = { "unit" }, ennemi = true })
    Ev.on_died(rec("jamais-enemy"), { ennemi = false })
    Ev.on_died(rec("par-nom"), { noms = { "fo-team-chest", "absent-du-jeu" } })
    Ev.on(DIED, rec("tout2"))
    Ev.bind()
    local h = bound[DIED]
    local surf = game.surfaces[1]
    local function fire(ent)
      calls = {}
      h({ entity = ent, tick = 1 })
      return table.concat(calls, ",")
    end
    local biter = M.new_entity("small-biter", 0, 0, surf, "enemy")
    local soldat = M.new_entity("small-biter", 0, 0, surf, "player")
    local coffre = M.new_entity("fo-team-chest", 0, 0, surf, "player")
    local tour = M.new_entity("gun-turret", 0, 0, surf, "enemy")
    check(fire(biter) == "tout1,unite-ennemie,tout2", "P5 bus : biter de la force enemy -> tout1, unite-ennemie, tout2 (" .. fire(biter) .. ")")
    check(fire(soldat) == "tout1,jamais-enemy,tout2", "P5 bus : unité d'une autre force -> tout1, jamais-enemy, tout2 (" .. fire(soldat) .. ")")
    check(fire(coffre) == "tout1,jamais-enemy,par-nom,tout2",
      "P5 bus : coffre d'équipe -> tout1, jamais-enemy, par-nom (type lu au prototype), tout2 (" .. fire(coffre) .. ")")
    check(fire(tour) == "tout1,tout2", "P5 bus : tourelle de la force enemy -> tout1, tout2 seulement (" .. fire(tour) .. ")")
    local mort = M.new_entity("small-biter", 0, 0, surf, "enemy")
    mort.valid = false
    local all = "tout1,unite-ennemie,jamais-enemy,par-nom,tout2"
    check(fire(mort) == all, "P5 bus : entité invalide -> tous, dans l'ordre d'enregistrement (" .. fire(mort) .. ")")
    calls = {}
    h({ tick = 1 })
    check(table.concat(calls, ",") == all, "P5 bus : événement sans entité -> tous")
    Ev.MORTS_TRIES = false
    check(fire(tour) == all, "P5 bus : aiguillage éteint (MORTS_TRIES = false) -> tous (" .. fire(tour) .. ")")
    Ev.MORTS_TRIES = true
    local guarded = not pcall(Ev.on_died, function() end, {})
    check(guarded, "P5 bus : Events.on_died après Events.bind refusé (abonnement dynamique interdit)")
  end)
  _G.script = real_script
  package.loaded["script.core.events"] = saved_events
  package.loaded["script.core.profiler"] = saved_prof
  if not ok then check(false, "P5 bus : erreur " .. tostring(err)) end
end

---------------------------------------------------------------------------------------------------
-- Intérêts attendus (recensement, CRITERES.md §2)
---------------------------------------------------------------------------------------------------
local function set_of(list)
  local s = {}
  for _, x in ipairs(list) do s[x] = true end
  return s
end

local function attendu()
  local Rg = require("shared.ai3.reglages")
  local Mult = require("script.modules.mult")
  local Compute = require("script.compute.compute")
  local E = require("shared.content.enemies")
  local P = game.entity_prototypes
  local function by_names(list)
    local s = {}
    for _, n in ipairs(list) do
      local p = P[n]
      if p then s[p.type] = true end
    end
    return s
  end
  local pieces = {}
  for _, t in ipairs(Rg.ENTITY_TYPES) do if Rg.ENTITY_ROLE[t] ~= "main" then pieces[#pieces + 1] = t end end
  local brood = {}
  for _, kind in ipairs({ "biter", "spitter" }) do
    for tier = 2, E.TIERS do brood[#brood + 1] = E.unit_name(kind, tier, "brood") end
  end
  local NE = { ennemi = false }
  return {
    ["script/faction/chef.lua"] = NE, ["script/faction/commander.lua"] = NE, ["script/faction/journaux_dc.lua"] = NE,
    ["script/faction/pvp.lua"] = NE, ["script/faction/vision.lua"] = NE,
    ["script/team/centrale_mort.lua"] = { types = set_of(Rg.PLANT_TYPES), ennemi = false },
    ["script/team/front.lua"] = { types = set_of(pieces), ennemi = false },
    ["script/team/player_team.lua"] = { types = by_names({ "fo-team-chest" }), ennemi = false },
    ["script/team/qg_groupe.lua"] = NE,
    -- qg_tourelle s'abonne aux types du journal des tourelles (artillerie comprise) depuis 040d1f8c (tourelle-journal)
    ["script/team/qg_tourelle.lua"] = { types = set_of(require("script.team.tourelle_journal").TURRET_TYPES), ennemi = false },
    ["script/team/reconstruction.lua"] = { types = set_of(pieces), ennemi = false },
    ["script/levels/levels.lua"] = NE, ["script/levels/centre.lua"] = NE, ["script/modules/lots.lua"] = NE,
    ["script/modules/mult.lua"] = { types = set_of(Mult.TYPES) },
    ["script/compute/compute.lua"] = { types = by_names(Compute.NAMES) },
    ["script/robots/armee.lua"] = { types = set_of({ "unit", "spider-vehicle" }) },
    ["script/robots/outils.lua"] = { types = set_of({ "unit", "spider-vehicle" }) },
    ["script/ai3/prevision.lua"] = { types = set_of({ "unit" }), ennemi = true },
    ["script/companion/registry.lua"] = { types = set_of({ "character" }) },
    -- EFFONDREMENT (parade du kit offert, 7/11) : la mort d'un PNJ au kit offert note sa fiche ; jamais la force « enemy »
    ["script/team/worker.lua"] = { types = set_of({ "character" }), ennemi = false },
    -- MINAGE-MAIN (d9694bdf, 8/11) : registre des coffres de sortie, oublié à la mort d'un coffre, d'un bras ou d'une foreuse de l'équipe
    ["script/team/sources.lua"] = { types = set_of({ "container", "inserter", "mining-drill" }), ennemi = false },
    ["script/scenario/journal.lua"] = { types = set_of({ "unit-spawner" }) },
    ["script/td/director.lua"] = { types = set_of({ "unit" }) },
    ["script/world/enemy_mechanics.lua"] = { types = by_names(brood) },
  }
end

local function declared(d) return d.types ~= nil or d.ennemi ~= nil end

local function same_set(a, b)
  if (a == nil) ~= (b == nil) then return false end
  if a == nil then return true end
  for k in pairs(a) do if not b[k] then return false end end
  for k in pairs(b) do if not a[k] then return false end end
  return true
end

local function set_text(s)
  if not s then return "tous" end
  return table.concat(sorted_keys(s), ",")
end

local function matches(d, etype, enemy)
  return (d.types == nil or d.types[etype] == true) and (d.ennemi == nil or d.ennemi == enemy)
end

---------------------------------------------------------------------------------------------------
-- La partie
---------------------------------------------------------------------------------------------------
local function teams()
  local out = {}
  local w = global.fo.war
  for _, id in ipairs(sorted_keys(w.factions or {})) do
    local f = w.factions[id]
    if not f.eliminated and f.hq and f.hq.valid then out[#out + 1] = f end
  end
  local pt = global.fo.pteam and global.fo.pteam.team
  if pt and pt.hq and pt.hq.valid then out[#out + 1] = pt end
  return out
end

--- Joue la partie. mode : "tri" (aiguillage), "tout" (Events.MORTS_TRIES = false) ou un nom de MUTANTS (aiguillage).
--- Rend { logs, glob, deaths, keys, called, n_died, events, mutant_absent }.
local function play(mode, mins)
  local mut = MUTANTS[mode]
  for _, m in pairs(MUTANTS) do package.preload[m[1]] = nil end
  if mut then
    local src, why = mutated(mut[2], mut[3])
    if not src then return { mutant_absent = why } end
    package.preload[mut[1]] = function(name) return assert(load(src, "=" .. mut[2]))(name) end
  end
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
  local W = M.world()
  W.settings["fo-recruit-idle-max"] = 60
  W.settings["fo-war-workers"] = 30
  local Events = require("script.core.events")
  Events.MORTS_TRIES = (mode ~= "tout")
  local r = { deaths = 0, keys = {}, called = 0, n_died = #Events.died_list() }
  local inner = W.events[DIED]
  W.events[DIED] = function(e)
    local ent = e.entity
    if ent and ent.valid then
      local enemy = ent.force.name == "enemy"
      local key = (enemy and "enemy|" or "") .. ent.type
      r.keys[key] = (r.keys[key] or 0) + 1
      r.called = r.called + #Events.died_for(ent.type, enemy)
    else
      r.called = r.called + r.n_died
    end
    r.deaths = r.deaths + 1
    return inner(e)
  end

  assert(remote.call("factorio-overhaul", "war_start", 4, 100, nil, 320) == true)
  remote.call("factorio-overhaul", "war_fund", 3000)
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W.events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  rawset(W.prototypes, "biter-spawner", { type = "unit-spawner", max_health = 350 })

  local roll = lcg(20261107)
  local HQ_NAMES = { ["fo-faction-hq"] = true, ["fo-team-chest"] = true }
  local KILLABLE = { unit = true, character = true, ["ammo-turret"] = true, ["electric-pole"] = true, inserter = true,
    ["transport-belt"] = true, ["mining-drill"] = true, furnace = true, container = true, boiler = true, generator = true,
    ["assembling-machine"] = true, lab = true, ["offshore-pump"] = true }
  local pending = {} -- entités posées à tuer à la seconde suivante : { e, tueur }
  local placed = 0
  local hq_killed = false
  local total = mins * 60
  for step = 1, total do
    M.run_ticks(60)
    for _, p in ipairs(pending) do
      if p[1].valid then p[1].die(p[2]) end
    end
    pending = {}
    local ts = teams()
    if #ts > 0 then
      local t = ts[step % #ts + 1]
      local hp = t.hq_pos
      -- Biters tués près d'un QG : par l'équipe (prévision), sans tueur, par la force enemy.
      for k = 1, 2 do
        local b = s.create_entity({ name = (k == 1) and "small-biter" or "small-spitter", position = { x = hp.x + 7 + k, y = hp.y }, force = "enemy" })
        if b then
          local w = roll(4)
          b.die(w <= 2 and t.force or (w == 3 and "enemy" or nil))
        end
      end
      -- Une pièce d'équipe (soldat, personnage, bâtiment, hors QG) tuée par la force enemy ou par une autre équipe.
      if step % 3 == 0 then
        local cands = {}
        for _, e in ipairs(W.entities) do
          if e.valid and KILLABLE[e.type] and not HQ_NAMES[e.name] and e.force.name == t.force then cands[#cands + 1] = e end
        end
        if #cands > 0 then
          local e = cands[roll(#cands)]
          local other = ts[roll(#ts)]
          e.die(roll(10) <= 7 and "enemy" or other.force)
        end
      end
      -- Infrastructure et tourelle de votre équipe posées près du coffre puis tuées par la force enemy (reconstruction, centrale,
      -- tourelles du QG).
      local pt = global.fo.pteam and global.fo.pteam.team
      if pt and pt.hq and pt.hq.valid and step % 5 == 0 then
        placed = placed + 1
        local names = { "medium-electric-pole", "boiler", "steam-engine", "gun-turret", "big-electric-pole" }
        local name = names[placed % #names + 1]
        local pos = { x = pt.hq_pos.x + 10 + placed % 7 * 2, y = pt.hq_pos.y - 8 - math.floor(placed / 7) % 5 * 2 }
        local e = s.create_entity({ name = name, position = pos, force = "player" })
        if e then pending[#pending + 1] = { e, "enemy" } end
      end
      -- Nid détruit par le joueur (jalon du journal), puis par une faction.
      if step % 20 == 0 then
        local n = s.create_entity({ name = "biter-spawner", position = { x = hp.x + 30, y = hp.y + 30 }, force = "enemy" })
        if n then n.die(roll(2) == 1 and "player" or ts[1].force) end
      end
    end
    -- QG d'une faction détruit par le joueur (journaux_dc, élimination).
    if not hq_killed and step >= math.floor(total * 0.75) then
      local w = global.fo.war
      local f = w.factions and w.factions[1]
      if f and f.hq and f.hq.valid then
        f.hq.die("player")
        hq_killed = true
      end
    end
  end
  r.events = W.events
  r.logs = {}
  for i, l in ipairs(W.logs) do r.logs[i] = l end
  r.glob = M.serialize(global)
  return r
end

local function compare(a, b)
  local same_logs = #a.logs == #b.logs
  local first
  for i = 1, math.max(#a.logs, #b.logs) do
    if a.logs[i] ~= b.logs[i] then
      same_logs = false
      first = string.format("ligne %d : [%s] / [%s]", i, tostring(a.logs[i]):sub(1, 160), tostring(b.logs[i]):sub(1, 160))
      break
    end
  end
  return same_logs, a.glob == b.glob, first
end

---------------------------------------------------------------------------------------------------
-- P1 : hors de son intérêt, rien
---------------------------------------------------------------------------------------------------
local function world_sig(W)
  local n, sx, sy, sh = 0, 0, 0, 0
  for _, e in ipairs(W.entities) do
    if e.valid then
      n = n + 1
      sx, sy, sh = sx + e._x, sy + e._y, sh + (e._health or 0)
    end
  end
  return string.format("n=%d u=%d x=%.6f y=%.6f h=%.6f logs=%d prints=%d gprints=%d renders=%d reg=%d dq=%d", n, W.unit, sx, sy, sh,
    #W.logs, #W.prints, #W.game_prints, W.render_id, W.reg, #W.destroyed_queue)
end

local function first_diff(a, b)
  local n = math.min(#a, #b)
  local i = 1
  while i <= n and a:byte(i) == b:byte(i) do i = i + 1 end
  return string.format("octet %d : [%s] / [%s]", i, a:sub(math.max(1, i - 60), i + 60), b:sub(math.max(1, i - 60), i + 60))
end

--- Pose les entités de P1 (tous les noms, chaque force, près de chaque QG) et rend la liste des candidates (vivantes, triées par numéro).
local function p1_world()
  local W = M.world()
  local s = game.surfaces[1]
  for _, n in ipairs(sorted_keys(EXTRA)) do
    if rawget(W.prototypes, n) == nil then rawset(W.prototypes, n, { type = EXTRA[n], max_health = 300 }) end
  end
  local names = sorted_keys(W.prototypes) -- noms bruts du moteur simulé (pairs ne voit pas la métatable)
  local forces = sorted_keys(W.forces)
  local spots = {}
  for _, t in ipairs(teams()) do spots[#spots + 1] = { x = t.hq_pos.x, y = t.hq_pos.y } end
  spots[#spots + 1] = { x = 30000, y = 30000 }
  for _, sp in ipairs(spots) do
    local i = 0
    for _, fname in ipairs(forces) do
      for _, n in ipairs(names) do
        if n ~= "entity-ghost" then
          i = i + 1
          M.new_entity(n, sp.x + (i % 13 - 6) * 1.5, sp.y + (math.floor(i / 13) % 13 - 6) * 1.5, s, fname)
        end
      end
    end
  end
  local cands = {}
  for _, e in ipairs(W.entities) do if e.valid then cands[#cands + 1] = e end end
  return cands, forces
end

--- Tueurs : aucun ; puis pour enemy, player et deux factions, sans cause et avec une cause de leur force (et un type de dégâts).
local function p1_killers(cands)
  local w = global.fo.war
  local fa = {}
  for _, id in ipairs(sorted_keys(w.factions or {})) do fa[#fa + 1] = w.factions[id].force end
  local list = { { force = nil } }
  for _, fname in ipairs({ "enemy", "player", fa[1], fa[2] }) do
    local cause
    for _, e in ipairs(cands) do
      if e.valid and e.force.name == fname and (e.type == "unit" or e.type == "ammo-turret") then cause = e break end
    end
    list[#list + 1] = { force = fname }
    list[#list + 1] = { force = fname, cause = cause, damage_type = { name = "physical" } }
  end
  return list
end

--- Appelle d (seul) pour chaque candidate hors de son intérêt et chaque tueur ; rend le nombre d'appels et la liste des écarts.
local function p1_run(Events, d, cands, killers)
  local W = M.world()
  local calls, errs = 0, {}
  local before_g, before_w = M.serialize(global), world_sig(W)
  for ki, k in ipairs(killers) do
    for _, e in ipairs(cands) do
      if e.valid then
        local enemy = e.force.name == "enemy"
        local inside = false
        for _, fn in ipairs(Events.died_for(e.type, enemy)) do if fn == d.fn then inside = true break end end
        if not inside then
          calls = calls + 1
          local killer = k.force and game.forces[k.force] or nil
          local ok, err = pcall(M.dispatch, d.fn, { entity = e, force = killer, cause = k.cause, damage_type = k.damage_type, tick = game.tick })
          if not ok then errs[#errs + 1] = string.format("erreur %s (%s, %s, tueur %s)", tostring(err):sub(1, 200), e.name, e.force.name, tostring(k.force)) end
        end
      end
    end
    local g, wsig = M.serialize(global), world_sig(W)
    if g ~= before_g then errs[#errs + 1] = string.format("global changé (tueurs %d) : %s", ki, first_diff(before_g, g)) end
    if wsig ~= before_w then errs[#errs + 1] = string.format("monde changé (tueurs %d) : %s / %s", ki, before_w, wsig) end
    if #errs > 0 then
      for i = #W.logs - 2, #W.logs do if W.logs[i] then errs[#errs + 1] = "   journal : " .. tostring(W.logs[i]):sub(1, 200) end end
      break
    end
  end
  return calls, errs
end

--- P1 sur l'état courant. `only` : un seul fichier ; `mutant` : l'abonné DOIT changer quelque chose (intérêt trop étroit vu).
local function p1(label, only, mutant)
  local Events = require("script.core.events")
  local cands = p1_world()
  local killers = p1_killers(cands)
  local total_calls, n_subs = 0, 0
  for _, d in ipairs(Events.died_list()) do
    local src = src_of(d.fn)
    if declared(d) and (not only or src == only) then
      n_subs = n_subs + 1
      local calls, errs = p1_run(Events, d, cands, killers)
      total_calls = total_calls + calls
      local what = string.format("%s, hors de son intérêt (%s%s) : %d appel(s) sur %d entités et %d tueurs", src, set_text(d.types),
        d.ennemi == nil and "" or (d.ennemi and ", enemy seulement" or ", jamais enemy"), calls, #cands, #killers)
      if mutant then
        check(#errs > 0, string.format("P4 %s : vu par P1 (%s ; %s)", label, what, errs[1] or "rien de changé"))
      else
        check(#errs == 0 and calls > 0, string.format("P1 %s : %s, ne fait rien%s", label, what,
          #errs > 0 and (" ; " .. table.concat(errs, " | ")) or ""))
      end
    end
  end
  if only and n_subs == 0 then check(false, "P1 " .. label .. " : abonné " .. only .. " absent ou non déclaré") end
  return total_calls, n_subs
end

---------------------------------------------------------------------------------------------------
-- Déroulé
---------------------------------------------------------------------------------------------------
local t0 = os.clock()
p5()

local a = play("tri", minutes)
local ta = os.clock() - t0
local Events = require("script.core.events")
local died = Events.died_list()

-- P2 : déclarations
do
  local want = attendu()
  check(#died == 25, "P2 : 25 abonnés à on_entity_died recensés (" .. #died .. ")") -- 23 + worker.lua (parade du kit offert, EFFONDREMENT) + sources.lua (MINAGE-MAIN)
  local tout, bad = {}, {}
  local seen = {}
  for i, d in ipairs(died) do
    local src = src_of(d.fn)
    seen[src] = true
    local w = want[src]
    if not w then
      bad[#bad + 1] = src .. " (hors recensement)"
    elseif not declared(d) then
      tout[#tout + 1] = src
    elseif not (same_set(d.types, w.types) and d.ennemi == w.ennemi) then
      bad[#bad + 1] = string.format("%s : déclaré (%s, ennemi %s), attendu (%s, ennemi %s)", src, set_text(d.types), tostring(d.ennemi),
        set_text(w.types), tostring(w.ennemi))
    end
    d.index = i
  end
  for _, src in ipairs(sorted_keys(want)) do if not seen[src] then bad[#bad + 1] = src .. " (recensé, absent du bus)" end end
  check(#bad == 0, "P2 : chaque abonné déclaré a l'intérêt du recensement" .. (#bad > 0 and (" ; " .. table.concat(bad, " | ")) or ""))
  print(string.format("   %d abonné(s) déclaré(s), %d « tout » (aucune déclaration%s)", #died - #tout, #tout,
    #tout > 0 and (" : " .. table.concat(tout, ", ")) or ""))
  -- Listes de l'aiguillage : exactement les abonnés de chaque clé, dans l'ordre d'enregistrement.
  local types = {}
  for n, p in pairs(M.world().prototypes) do types[p.type] = true end
  for _, ty in pairs(EXTRA) do types[ty] = true end
  for _, d in ipairs(died) do for ty in pairs(d.types or {}) do types[ty] = true end end
  local wrong, keys = {}, 0
  for _, ty in ipairs(sorted_keys(types)) do
    for _, enemy in ipairs({ true, false }) do
      keys = keys + 1
      local got = Events.died_for(ty, enemy)
      local exp = {}
      for _, d in ipairs(died) do if matches(d, ty, enemy) then exp[#exp + 1] = d.fn end end
      local same = #got == #exp
      for i = 1, #exp do if got[i] ~= exp[i] then same = false end end
      for _, d in ipairs(died) do
        if not declared(d) then
          local found = false
          for _, fn in ipairs(got) do if fn == d.fn then found = true end end
          if not found then same = false end
        end
      end
      if not same then wrong[#wrong + 1] = (enemy and "enemy|" or "") .. ty end
    end
  end
  check(#wrong == 0, string.format("P2/P5 : sur %d clés (type, enemy ou non), l'aiguillage rend exactement les abonnés de l'intérêt, " ..
    "dans l'ordre d'enregistrement, et tous les « tout »%s", keys, #wrong > 0 and (" ; faux : " .. table.concat(wrong, ", ")) or ""))
  local bit = Events.died_for("unit", true)
  local names = {}
  for _, fn in ipairs(bit) do names[#names + 1] = src_of(fn):match("([^/]+)%.lua$") end
  print(string.format("   biter de la force enemy : %d abonné(s) sur %d (%s)", #bit, #died, table.concat(names, ", ")))
  if #tout == 0 then
    -- Le moteur simulé donne le type « unit » à tout nom fo-* inconnu de lui, centres de données compris (en jeu : assembling-machine,
    -- prototypes/compute.lua et compute_v2.lua) : compute est alors dans la liste du biter, ici seulement.
    local want_names = { prevision = true, armee = true, outils = true, director = true, enemy_mechanics = true }
    local mock_dc = game.entity_prototypes["fo-data-center"]
    if mock_dc and mock_dc.type == "unit" then want_names.compute = true end
    local same = true
    for _, n in ipairs(names) do if not want_names[n] then same = false end end
    local nw = 0
    for _ in pairs(want_names) do nw = nw + 1 end
    check(same and #names == nw, string.format("P2 : un biter de la force enemy appelle %d abonnés sur 23 : prevision, armee, outils, " ..
      "director, enemy_mechanics%s", nw, want_names.compute and " (+ compute, au moteur simulé seulement : en jeu 5 sur 23)" or ""))
  end
  for _, ty in ipairs({ "unit", "character", "electric-pole", "ammo-turret", "assembling-machine", "container", "unit-spawner" }) do
    print(string.format("   %-20s autre force : %2d abonné(s) ; force enemy : %2d", ty, #Events.died_for(ty, false), #Events.died_for(ty, true)))
  end
end

-- P3 : A/B
local kinds = sorted_keys(a.keys)
local kt = {}
for _, k in ipairs(kinds) do kt[#kt + 1] = k .. " " .. a.keys[k] end
print(string.format("[MORTS] partie avec l'aiguillage (%d min, %.1f s) : %d mort(s), %d abonné(s) appelés en tout, soit %.2f par mort sur %d",
  minutes, ta, a.deaths, a.called, a.called / math.max(1, a.deaths), a.n_died))
print("   morts par clé : " .. table.concat(kt, ", "))
check(a.deaths >= 100 and #kinds >= 8, string.format("P3 : au moins 100 morts de 8 clés (type, enemy) au moins (%d morts, %d clés)", a.deaths, #kinds))
local tb = os.clock()
local b = play("tout", minutes)
print(string.format("[MORTS] partie sans l'aiguillage (%.1f s) : %d mort(s), %d appels (%.2f par mort)", os.clock() - tb, b.deaths, b.called,
  b.called / math.max(1, b.deaths)))
local sl, sg, first = compare(a, b)
if first then print("   premier écart du journal : " .. first) end
check(#a.logs > 100 and sl, string.format("P3 : journal identique ligne à ligne avec et sans l'aiguillage (%d / %d lignes)", #a.logs, #b.logs))
check(sg, "P3 : global identique avec et sans l'aiguillage" .. (sg and "" or (" ; " .. first_diff(a.glob, b.glob))))
check(a.deaths == b.deaths, string.format("P3 : même nombre de morts (%d / %d)", a.deaths, b.deaths))

-- P1 sur l'état de fin de la partie « tout » (le dernier joué), après les comparaisons.
local tp = os.clock()
local calls, n_subs = p1("partie", nil)
print(string.format("[MORTS] P1 : %d abonné(s) déclaré(s), %d appel(s) hors intérêt en tout (%.1f s)", n_subs, calls, os.clock() - tp))

-- P4 : mutants
for _, name in ipairs(sorted_keys(MUTANTS)) do
  local m = play(name, minutes)
  if m.mutant_absent then
    print("   mutant " .. name .. " : sans objet (" .. m.mutant_absent .. ")")
  else
    local ml, mg = compare(m, b)
    check(not (ml and mg), string.format("P4 mutant %s : vu par P3 (journal %s, global %s)", name, ml and "identique" or "différent",
      mg and "identique" or "différent"))
    p1("mutant " .. name, MUTANTS[name][2], true)
  end
end

print(string.format("BILAN : %d OK%s (%.0f s)", ok_n, fail_n > 0 and (", " .. fail_n .. " ECHEC(S)") or "", os.clock() - t0))
os.exit(fail_n == 0 and 0 or 1)
