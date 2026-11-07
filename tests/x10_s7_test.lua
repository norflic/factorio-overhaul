--[[
  Lot S7 (X10, QUEUE DE LA VUE ; critères : fo-logs/2026-11-07_X10/S7_CRITERES.md). Aucune décision ne doit changer :
    A tourelles lues une fois par vue (script/team/vue_tourelles.lua) ; B registre des laboratoires (script/team/front.lua) ;
    C danger d'un avant-poste lu une fois par tick et gardé tant que son nid vit (script/team/danger_ap.lua) ;
    D pièces de la centrale gardées (script/team/garde_centrale.lua) ; E fer et cuivre de Front.view lus une fois.

  Partie de banc au moteur simulé (4 factions, plan directeur, centrales, votre équipe ; montage de tests/decoupage_pensee_test.lua)
  avec une AGITATION déterministe : laboratoires posés par le joueur, par robot, par script (raise_built), ravivés, clonés, posés SANS
  événement, posés par le « cerveau » (f.team.ia3.labs), tués, détruits ; tourelles tuées ; nids et vers posés près des avant-postes
  puis tués ou détruits ; accès d'un avant-poste déplacé ; chaudière d'une centrale tuée puis refaite sans événement ; sauvegarde
  rechargée ; on_configuration_changed.

  Un passage = un PROCESSUS (moteur et modules neufs) :
    lua5.2 tests/x10_s7_test.lua --run <mode> <minutes> <sortie>
  modes : jeu (journal et global, pour l'A/B), ombre (Q1 : chaque lecture nouvelle comparée à l'ancien calcul au même instant ;
  relevés complets des laboratoires comptés contre l'attendu), et pour Q4, sur Team.view et Poles.think : cout (instructions Lua
  du mod, debug.sethook), memoire (Ko alloués), appels (appels au moteur simulé par sorte). FO_S7_MUT=<id> : mutant (patch exact de la
  source au chargement). Les modes jeu, cout, memoire et appels tournent AUSSI sur l'ancien code : lancer ce fichier depuis le dossier
  de l'ancien code.

  Sans argument : banc complet. Q1 (ombre, 0 écart), Q3 (chaque mutant vu par l'ombre), et si FO_S7_OLD=<dossier de l'ancien code>
  (copie de d96f61ed) : Q2 (journal et global identiques à l'ancien code) et Q4 (coût avant et après). FO_MIN : minutes de l'ombre,
  de l'A/B, du coût et du mutant des centrales (défaut 22 : une centrale finie vers 20 min) ; FO_MIN_MUT : autres mutants (défaut 10) ;
  FO_PAR : passages en même temps (défaut 3). Environ 15 min avec FO_S7_OLD, 3 passages à la fois.
]]
package.path = "./?.lua;" .. package.path

local SELF = debug.getinfo(1, "S").source:sub(2)
local LUA = arg[-1] or "lua5.2"

---------------------------------------------------------------------------------------------------
-- Mutants : patch exact (une seule occurrence) d'un module au chargement
---------------------------------------------------------------------------------------------------
local MUTS = {
  ["labs-valid"] = { "script.team.front", "if r.e.valid and r.e.force.name == f.force then keys[#keys + 1] = u else set[u] = nil end",
    "if true then keys[#keys + 1] = u else set[u] = nil end" },
  ["labs-pose"] = { "script.team.front", "if reg and u then reg.set[u] = lab_entry(ent) end", "if false then reg.set[u] = lab_entry(ent) end" },
  ["labs-cerveau"] = { "script.team.front", "  note_brain_labs(f, set)\n", "\n" },
  ["labs-controle"] = { "script.team.front", "if n ~= want then", "if false then" },
  ["labs-noms"] = { "script.team.front", "for _, name in ipairs(lab_names()) do", "for _, name in ipairs({ \"lab\" }) do" },
  ["labs-config"] = { "script.team.front", "if f and f.front_mem then f.front_mem.labs = nil end", "if f and f.front_mem then end" },
  ["labs-premier"] = { "script.team.front", "local reg = st.labs or labs_full_scan(f, st)",
    "local reg = st.labs or { set = {}, scans = 0 }; st.labs = reg" },
  ["tourelles-mortes"] = { "script.team.vue_tourelles", "    if t.valid then\n      local pos = t.position", "    if true then\n      local pos = t.position" },
  ["tourelles-gardees"] = { "script.team.vue_tourelles", "function VT.releve(f, rank_of)\n  local list = {}",
    "local MEMO = {}\nfunction VT.releve(f, rank_of)\n  if MEMO[f] then return MEMO[f] end\n  local list = {}\n  MEMO[f] = list" },
  ["refs-valid"] = { "script.team.garde_centrale", "r.y == e.y and r.e.valid then return r.e end", "r.y == e.y then return r.e end" },
  ["danger-absence"] = { "script.team.danger_ap", "if m.hit and m.w and m.w.valid then",
    "if not m.hit then\n      m.t = tick\n      return false\n    end\n    if m.hit and m.w and m.w.valid then" },
  ["danger-temoin"] = { "script.team.danger_ap", "if m.hit and m.w and m.w.valid then", "if m.hit then" },
  ["danger-position"] = { "script.team.danger_ap", "if m and m.x == pos.x and m.y == pos.y and m.r == radius then", "if m then" },
  ["danger-mobile"] = { "script.team.danger_ap", "w = (w and FIXE[w.type]) and w or nil", "w = w" },
  ["stock-fer"] = { "script.team.team", "front = Front.view(f, fortify_open, tur, stock0[T.outposts.iron.product] or 0,",
    "front = Front.view(f, fortify_open, tur, (stock0[T.outposts.iron.product] or 0) + 1," },
}
local MUT_ORDER = { "labs-valid", "labs-pose", "labs-cerveau", "labs-controle", "labs-noms", "labs-config", "labs-premier",
  "tourelles-mortes", "tourelles-gardees", "refs-valid", "danger-absence", "danger-temoin", "danger-position", "danger-mobile", "stock-fer" }

local function install_mutant(id)
  local m = MUTS[id]
  assert(m, "mutant inconnu : " .. tostring(id))
  local modname, old, new = m[1], m[2], m[3]
  table.insert(package.searchers, 2, function(name)
    if name ~= modname then return nil end
    local path = name:gsub("%.", "/") .. ".lua"
    local h = assert(io.open(path, "rb"))
    local src = h:read("*a")
    h:close()
    local i = src:find(old, 1, true)
    assert(i, "mutant " .. id .. " : texte introuvable dans " .. path)
    assert(not src:find(old, i + 1, true), "mutant " .. id .. " : texte présent deux fois dans " .. path)
    src = src:sub(1, i - 1) .. new .. src:sub(i + #old)
    return assert(load(src, "@" .. path))
  end)
end

---------------------------------------------------------------------------------------------------
-- Une partie
---------------------------------------------------------------------------------------------------
local function run(mode, min, out)
  local mut = os.getenv("FO_S7_MUT")
  if mut and mut ~= "" then install_mutant(mut) end
  local M = require("tests.mock_engine")
  local function patches()
    local o = {}
    local d = 0.7071
    local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
    local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
      { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for _, c in ipairs(corners) do
      local hx, hy = c[1] * 320, c[2] * 320
      for ri, r in ipairs({ 40, 64, 88 }) do
        for di, v in ipairs(dirs) do o[#o + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] } end
      end
    end
    for i = 0, 11 do
      local a = i * math.pi / 6
      o[#o + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
    end
    return o
  end
  local PONDS = {}
  do
    local d = 0.7071
    for _, c in ipairs({ { d, -d }, { d, d }, { -d, d }, { -d, -d } }) do PONDS[#PONDS + 1] = { x = c[1] * 320 + 30, y = c[2] * 320 + 2 } end
  end
  local function tile_at(x, y)
    for _, q in ipairs(PONDS) do
      local dx, dy = x + 0.5 - q.x, y + 0.5 - q.y
      if dx * dx + dy * dy <= 49 then return "water" end
    end
    return "grass-1"
  end
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0, ia3e = true, tile_at = tile_at })
  local W = M.world()
  -- Nids et vers (types du moteur), absents du moteur simulé
  W.prototypes["biter-spawner"] = { type = "unit-spawner", max_health = 350, collision_box = W.prototypes["lab"].collision_box,
    collision_mask = W.prototypes["lab"].collision_mask }
  W.prototypes["small-worm-turret"] = { type = "turret", max_health = 200, collision_box = W.prototypes["lab"].collision_box,
    collision_mask = W.prototypes["lab"].collision_mask }
  -- Un 2e prototype de laboratoire (autre nom, même type) : le compte du registre se fait par force ET par nom (demande du lead)
  do
    local c = {}
    for k, v in pairs(W.prototypes["lab"]) do c[k] = v end
    W.prototypes["x10-labo-2"] = c
  end
  -- Portée de la tourelle (absente du moteur simulé : sans elle, GardeCentrale.view rend toujours nil et la garde n'est jamais jouée)
  W.prototypes["gun-turret"].attack_parameters = { range = 18 }
  W.prototypes["gun-turret"].turret_range = 18
  for _, p in pairs(W.prototypes) do if p.has_flag == nil then p.has_flag = function() return false end end end
  W.settings["fo-recruit-idle-max"] = 60
  W.settings["fo-war-workers"] = 4
  assert(remote.call("factorio-overhaul", "war_start", 4, 100, nil, 320) == true)
  remote.call("factorio-overhaul", "war_fund", 3000)
  do
    local s = game.surfaces[1]
    local find = s.find_tiles_filtered
    s.count_tiles_filtered = function(t)
      if t.collision_mask ~= "water-tile" then return 0 end
      local area, cx, cy, r2 = t.area, nil, nil, nil
      if not area then
        local p, r = t.position, t.radius
        cx, cy, r2 = p.x or p[1], p.y or p[2], r * r
        area = { { math.floor(cx - r), math.floor(cy - r) }, { math.ceil(cx + r), math.ceil(cy + r) } }
      end
      local n = 0
      for _, tl in ipairs(find({ area = area, collision_mask = "water-tile" })) do
        local ok = true
        if r2 then local dx, dy = tl.position.x + 0.5 - cx, tl.position.y + 0.5 - cy; ok = dx * dx + dy * dy <= r2 end
        if ok then n = n + 1; if t.limit and n >= t.limit then return n end end
      end
      return n
    end
  end
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
    { "pistol", 2 }, { "firearm-magazine", 40 }, { "burner-mining-drill", 6 }, { "stone-furnace", 6 }, { "iron-chest", 4 },
    { "gun-turret", 6 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W.events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })

  local Build = require("script.team.build")
  local State = require("script.faction.state")
  local Team = require("script.team.team")
  local Stock = require("script.team.stock")
  local Outposts = require("script.faction.outposts")
  local Front = require("script.team.front")
  local GardeCentrale = require("script.team.garde_centrale")
  local Ilots = require("script.team.ilots")
  local Poles = require("script.team.poles")
  local Fr = require("shared.team.front")
  local Mu = require("shared.team.munitions")
  local T = require("shared.team.config")
  local Mo = require("shared.team.modules")
  local Dd = require("shared.team.automatisation_donnees")
  local okVT, VT = pcall(require, "script.team.vue_tourelles")
  local okD, DangerAp = pcall(require, "script.team.danger_ap")
  if not okVT then VT = nil end
  if not okD then DangerAp = nil end
  M.run_ticks(120)
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    Build.enable(f, { radius = 3 })
    Build.plant(f)
    Build.request(f, { gen = "gears", args = { 2, "assembling-machine-1" }, feed = true, prio = 60 })
    Build.request(f, { gen = "simple", args = { "iron-gear-wheel", 1, "assembling-machine-1" }, feed = true, prio = 55 })
  end

  local function teams()
    local list = {}
    for _, id in ipairs(State.alive()) do list[#list + 1] = State.faction(id) end
    list[#list + 1] = State.faction("player")
    return list
  end
  local function key_of(f) return f.key or "player" end
  local EV = defines.events
  local function event_id(name) return rawget(EV, name) end

  ---------------------------------------------------------------------------------------------------
  -- Q1 : ombre
  ---------------------------------------------------------------------------------------------------
  local diffs, ndiff = {}, 0
  local checks = 0
  local function bad(what)
    ndiff = ndiff + 1
    if #diffs < 30 then diffs[#diffs + 1] = string.format("t%d %s", game.tick, what) end
  end
  local function same(a, b, path)
    checks = checks + 1
    if type(a) ~= type(b) then bad(path .. " : type " .. type(a) .. " / " .. type(b)) return false end
    if type(a) ~= "table" then
      if a ~= b then bad(path .. " : " .. tostring(a) .. " / " .. tostring(b)) return false end
      return true
    end
    if rawget(a, "_lua_object") or rawget(b, "_lua_object") then
      if a ~= b then bad(path .. " : entité différente") return false end
      return true
    end
    local keys, seen = {}, {}
    for k in pairs(a) do if not seen[k] then seen[k] = true; keys[#keys + 1] = k end end
    for k in pairs(b) do if not seen[k] then seen[k] = true; keys[#keys + 1] = k end end
    table.sort(keys, function(x, y) if type(x) == type(y) then return x < y end return type(x) < type(y) end)
    for _, k in ipairs(keys) do if not same(a[k], b[k], path .. "." .. tostring(k)) then return false end end
    return true
  end
  -- Anciens calculs, copiés tels quels de d96f61ed
  local function old_front_turrets(f)
    local list, placed = {}, 0
    for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
      local t = f.turrets[id]
      if t.valid then
        list[#list + 1] = { x = t.position.x, y = t.position.y }
        local o = State.owner(id)
        if o and type(o.oid) == "string" and o.oid:sub(1, 5) == "front" then placed = placed + 1 end
      end
    end
    return list, placed
  end
  local function old_ilot_turrets(f)
    local list, placed = {}, 0
    for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
      local t = f.turrets[id]
      if t.valid then
        list[#list + 1] = { x = t.position.x, y = t.position.y }
        local o = State.owner(id)
        if o and type(o.oid) == "string" and o.oid:sub(1, #Ilots.OID) == Ilots.OID then placed = placed + 1 end
      end
    end
    return list, placed
  end
  local function old_gc_turrets(f)
    local turrets = {}
    for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
      local t = f.turrets[id]
      if t.valid then
        local inv = t.get_inventory(defines.inventory.turret_ammo)
        turrets[#turrets + 1] = { x = t.position.x, y = t.position.y, rounds = inv and inv.get_item_count() or 0 }
      end
    end
    return turrets
  end
  local function old_ammo_of(t)
    local inv = t.get_inventory(defines.inventory.turret_ammo)
    return inv and inv.get_item_count() or 0
  end
  local AMMO_RANK = {}
  for i, name in ipairs(T.turret_ammo_ladder) do AMMO_RANK[name] = i end
  local function old_ammo_rank(t)
    local inv = t.get_inventory(defines.inventory.turret_ammo)
    if not inv or inv.is_empty() then return 0 end
    local st = inv[1]
    return st.valid_for_read and (AMMO_RANK[st.name] or 0) or 0
  end
  local function old_turret_groups(f) -- (sans la purge : le relevé l'a déjà faite)
    local groups, by_key = {}, {}
    local target = Outposts.ammo_target(f)
    for _, id in ipairs(State.sorted_keys(f.turrets)) do
      local t = f.turrets[id]
      if t.valid then
        local owner = State.owner(id)
        local oid = owner and owner.oid
        local key = oid and ("o" .. oid) or "hq"
        local g = by_key[key]
        if not g then
          local pos = f.hq_pos
          if oid then pos = f.outposts[oid] and f.outposts[oid].pos or t.position end
          g = { key = key, pos = pos, list = {}, low = 0, have = {}, ranks = {} }
          by_key[key] = g
          groups[#groups + 1] = g
        end
        g.list[#g.list + 1] = t
        local a = old_ammo_of(t)
        g.have[#g.have + 1] = a
        g.ranks[#g.ranks + 1] = old_ammo_rank(t)
        if a < T.turret_ammo_low then g.low = g.low + 1 end
      else
        bad("turret_groups : tourelle morte encore dans f.turrets après le relevé")
      end
    end
    local best = AMMO_RANK[Outposts.ammo_name(nil, f)] or 1
    for _, g in ipairs(groups) do
      local m = Mu.group(g.have, target, T.turret_ammo_low, T.turret_ammo_target, g.ranks, best)
      local sum = 0
      for _, a in ipairs(g.have) do sum = sum + a end
      g.short, g.missing, g.ammo, g.have = m.short, m.missing, sum, nil
      g.missing_base, g.short_base = m.missing_base, m.short_base
      g.worse, g.worse_need, g.ranks = m.worse, m.worse_need, nil
    end
    return groups
  end
  local function old_cover(f, surface)
    local pos = {}
    for _, e in ipairs(surface.find_entities_filtered({ force = f.force, type = "lab" })) do
      if e.valid then pos[#pos + 1] = { x = e.position.x, y = e.position.y } end
    end
    table.sort(pos, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
    return Fr.cover_clusters(pos)
  end
  local function old_plants(f, surface)
    local b = f.build
    local ids, plants = {}, {}
    if not b then return plants end
    if b.plant then ids[1] = b.plant end
    for _, id in ipairs(b.extra_plants or {}) do ids[#ids + 1] = id end
    local done = {}
    for _, pid in ipairs(ids) do
      if not done[pid] then
        done[pid] = true
        local p = b.projects[pid]
        if p and p.state == "fini" and p.spec and p.spec.gen == Dd.PLANT.gen then
          local pieces, boilers = {}, 0
          for _, e in ipairs(p.ents) do
            local sp = Mo.spec(e.name) or {}
            if sp.water or sp.power_out or sp.kind == "offshore" then
              local real = surface.find_entity(e.name, { e.x, e.y })
              if real and real.valid and real.force.name == f.force then
                pieces[#pieces + 1] = { x = e.x, y = e.y }
                if sp.water then boilers = boilers + 1 end
              end
            end
          end
          if #pieces > 0 and boilers > 0 then plants[#plants + 1] = { id = pid, pieces = pieces, boilers = boilers } end
        end
      end
    end
    return plants
  end

  -- Comptes de l'ombre (diagnostic : la partie exerce-t-elle ce qu'elle doit exercer ?)
  local stat = { views = 0, front_turrets = 0, gc_views = 0, gc_plants = 0, ilot_views = 0, groups = 0, refreshes = 0, labs_seen = 0,
    scans = 0, scans_want = 0, danger = 0, danger_hit = 0, danger_memo = 0, iron = 0 }
  local untracked = {} -- [force] = { [unit_number] = true } : laboratoires posés par le banc sans événement ni cerveau
  local cfg = {}       -- [clé d'équipe] = vrai : on_configuration_changed depuis le dernier relevé

  if mode == "ombre" then
    assert(VT and DangerAp, "le mode ombre demande le nouveau code")
    -- Cas du danger sur une surface réduite (exigence du lead) : témoin FIXE gardé d'une pensée à l'autre, témoin MOBILE (unité restée
    -- valide mais sortie du rayon) recompté ; même tick : une seule recherche.
    do
      local fake = { n = 0, ret = nil }
      fake.find_entities_filtered = function() fake.n = fake.n + 1 return fake.ret and { fake.ret } or {} end
      local ff = {}
      local P = { x = 0.5, y = 0.5 }
      local nest = { valid = true, type = "unit-spawner" }
      fake.ret = nest
      same(DangerAp.near(ff, fake, 1, P, 100, 40), true, "danger.cas fixe trouvé")
      same(DangerAp.near(ff, fake, 1, P, 400, 40), true, "danger.cas fixe gardé")
      same(fake.n, 1, "danger.cas fixe : une seule recherche")
      nest.valid, fake.ret = false, nil
      same(DangerAp.near(ff, fake, 1, P, 700, 40), false, "danger.cas fixe mort : recompté")
      same(fake.n, 2, "danger.cas fixe mort : nouvelle recherche")
      local unit = { valid = true, type = "unit" }
      fake.ret = unit
      same(DangerAp.near(ff, fake, 2, P, 1000, 40), true, "danger.cas mobile trouvé")
      same(DangerAp.near(ff, fake, 2, P, 1000, 40), true, "danger.cas mobile même tick")
      same(fake.n, 3, "danger.cas mobile même tick : une seule recherche")
      fake.ret = nil -- l'unité est sortie du rayon, toujours valide
      same(DangerAp.near(ff, fake, 2, P, 1300, 40), false, "danger.cas mobile sorti du rayon : recompté")
      same(fake.n, 4, "danger.cas mobile : nouvelle recherche")
    end
    local real_front = Front.view
    Front.view = function(f, fo, releve, iron, copper)
      if releve then
        stat.front_turrets = stat.front_turrets + 1
        local ol, op = old_front_turrets(f)
        local nl, np = VT.positions(releve, "front")
        same(ol, nl, "front.tourelles")
        same(op, np, "front.placed")
      else
        bad("Front.view sans relevé dans la vue")
      end
      if iron then
        stat.iron = stat.iron + 1
        same(Stock.count(f, T.outposts.iron.product), iron, "front.fer")
        same(Stock.count(f, T.outposts.copper.product), copper, "front.cuivre")
      end
      local st0 = f.front_mem
      local reg0 = st0 and st0.labs
      local scans0 = reg0 and reg0.scans or 0
      local k = key_of(f)
      -- relevé complet ATTENDU (code juste) : premier relevé, configuration changée, ou laboratoire du banc posé sans événement
      local want = (reg0 == nil) or cfg[k] or false
      for u in pairs(untracked[f.force] or {}) do
        for _, e in ipairs(W.entities) do if e.unit_number == u and e.valid then want = true end end
      end
      local r = real_front(f, fo, releve, iron, copper)
      local st = f.front_mem
      if st and st.cover_tick == game.tick and f.hq and f.hq.valid then
        stat.refreshes = stat.refreshes + 1
        same(old_cover(f, f.hq.surface), st.cover, "front.couverture " .. k)
        local reg = st.labs
        local delta = 0
        if reg then delta = (reg == reg0) and (reg.scans - scans0) or reg.scans end
        stat.scans, stat.scans_want = stat.scans + delta, stat.scans_want + (want and 1 or 0)
        if delta ~= (want and 1 or 0) then bad(string.format("labos %s : %d relevé(s) complet(s), %d attendu", k, delta, want and 1 or 0)) end
        for _ in pairs(reg and reg.set or {}) do stat.labs_seen = stat.labs_seen + 1 end
        cfg[k] = nil
        if delta > 0 then untracked[f.force] = {} end
      end
      return r
    end
    local real_gc = GardeCentrale.view
    GardeCentrale.view = function(f, fo, iron, releve)
      local surface = f.hq and f.hq.valid and f.hq.surface or nil
      local op = surface and old_plants(f, surface) or {}
      local r = real_gc(f, fo, iron, releve)
      stat.gc_views = stat.gc_views + 1
      if r then
        stat.gc_plants = stat.gc_plants + #r.plants
        local plants = {}
        for i, pl in ipairs(r.plants) do plants[i] = { id = pl.id, pieces = pl.pieces, boilers = pl.boilers } end
        same(op, plants, "centrale.pieces")
        same(old_gc_turrets(f), r.turrets, "centrale.tourelles")
      elseif #op > 0 then
        bad("centrale : vue nil, l'ancien calcul a " .. #op .. " centrale(s)")
      end
      return r
    end
    local real_il = Ilots.view
    Ilots.view = function(f, fo, iron, releve)
      local h = f.build and f.build.ilots
      if releve and h and #h.list > 0 then
        stat.ilot_views = stat.ilot_views + 1
        local ol, op = old_ilot_turrets(f)
        local nl, np = VT.positions(releve, Ilots.OID)
        same(ol, nl, "ilots.tourelles")
        same(op, np, "ilots.placed")
      end
      return real_il(f, fo, iron, releve)
    end
    local real_tg = Outposts.turret_groups
    Outposts.turret_groups = function(f, releve)
      local g, by = real_tg(f, releve)
      if releve then
        stat.groups = stat.groups + 1
        stat.views = stat.views + 1
        local og = old_turret_groups(f)
        same(#og, #g, "groupes.nombre")
        for i = 1, math.max(#og, #g) do
          local a, b = og[i] or {}, g[i] or {}
          for _, fld in ipairs({ "key", "low", "short", "missing", "ammo", "missing_base", "short_base", "worse", "worse_need" }) do
            same(a[fld], b[fld], "groupes." .. i .. "." .. fld)
          end
          same(a.pos and a.pos.x, b.pos and b.pos.x, "groupes." .. i .. ".pos.x")
          same(a.pos and a.pos.y, b.pos and b.pos.y, "groupes." .. i .. ".pos.y")
          same(a.list, b.list, "groupes." .. i .. ".list")
        end
      end
      return g, by
    end
    local real_near = DangerAp.near
    DangerAp.near = function(f, surface, oid, pos, tick, radius)
      local was = f.danger_ap and f.danger_ap[oid]
      local memo = was and was.t == tick
      local old = surface.count_entities_filtered({ position = pos, radius = radius, force = "enemy", type = { "unit-spawner", "turret" },
        limit = 1 }) > 0
      local new = real_near(f, surface, oid, pos, tick, radius)
      stat.danger = stat.danger + 1
      if new then stat.danger_hit = stat.danger_hit + 1 end
      if memo then stat.danger_memo = stat.danger_memo + 1 end
      same(old, new, "danger " .. key_of(f) .. " ap " .. tostring(oid))
      return new
    end
  end

  ---------------------------------------------------------------------------------------------------
  -- Q4 : coût (instructions, appels au moteur simulé, mémoire)
  ---------------------------------------------------------------------------------------------------
  -- Trois mesures séparées (chaque outil fausserait les autres) : cout = instructions Lua du MOD (crochet) ; memoire = Ko alloués,
  -- ramasse-miettes arrêté, moteur simulé compris (il alloue où le moteur alloue aussi : positions, objets rendus) ; appels = appels au
  -- moteur simulé par sorte (les lectures brutes comme `valid` ne sont pas vues). Sur Team.view et Poles.think (pensée E1).
  local cost = { view = { calls = 0, ins = 0, kb = 0 }, poles = { calls = 0, ins = 0, kb = 0 }, api = {} }
  if mode == "cout" or mode == "appels" or mode == "memoire" then
    local ins = 0
    local active = false
    -- Instructions du MOD seulement (script/, shared/) : celles du moteur simulé et de ce banc (dossier tests) ne comptent pas, car en
    -- jeu les recherches et les lectures sont du C++. Pile des appels tenue par les événements call / return du crochet.
    local stack, sp = { [0] = false }, 0
    local cls = setmetatable({}, { __mode = "k" })
    local function hook(ev)
      if ev == "count" then
        if stack[sp] then ins = ins + 1 end
        return
      end
      if ev == "return" then
        if sp > 0 then sp = sp - 1 end
        return
      end
      local info = debug.getinfo(2, "Sf")
      local c = info and cls[info.func]
      if info and c == nil then
        local src = info.source or ""
        c = src:sub(1, 1) == "@" and not src:find("tests", 1, true)
        cls[info.func] = c
      end
      if ev == "call" then sp = sp + 1 end
      stack[sp] = c or false
    end
    local function measure(slot, fn, ...)
      if active then return fn(...) end
      active = true
      local kb0, i0
      if mode == "memoire" then
        collectgarbage("stop")
        kb0 = collectgarbage("count")
      elseif mode == "cout" then
        i0 = ins
        sp = 0
        debug.sethook(hook, "cr", 1)
      end
      local r = table.pack(fn(...))
      if mode == "cout" then
        debug.sethook()
        cost[slot].ins = cost[slot].ins + (ins - i0)
      elseif mode == "memoire" then
        local kb1 = collectgarbage("count")
        collectgarbage("restart")
        cost[slot].kb = cost[slot].kb + (kb1 - kb0)
      end
      cost[slot].calls = cost[slot].calls + 1
      active = false
      return table.unpack(r, 1, r.n)
    end
    if mode == "appels" then
      local inner = false
      local function api(k) cost.api[k] = (cost.api[k] or 0) + 1 end
      for _, fn in ipairs({ "find_entities_filtered", "count_entities_filtered", "find_entity", "find_nearest_enemy" }) do
        local o = s[fn]
        s[fn] = function(t, ...)
          if active and not inner then
            local tag = fn
            if type(t) == "table" and t.radius then tag = tag .. "(r" .. tostring(t.radius) .. ")" end
            if type(t) == "table" and not t.area and not t.position and fn == "find_entities_filtered" then tag = tag .. "(SURFACE)" end
            api(tag)
          end
          local was = inner
          inner = true
          local r = table.pack(o(t, ...))
          inner = was
          return table.unpack(r, 1, r.n)
        end
      end
      local probe = s.create_entity({ name = "wooden-chest", position = { x = 900, y = 900 }, force = "neutral" })
      local mt = getmetatable(probe)
      local oidx = mt.__index
      mt.__index = function(t, k)
        if active and not inner then api("." .. tostring(k)) end
        return oidx(t, k)
      end
      probe.destroy()
    end
    local real_view = Team.view
    Team.view = function(...) return measure("view", real_view, ...) end
    local real_poles = Poles.think
    Poles.think = function(...) return measure("poles", real_poles, ...) end
  end

  ---------------------------------------------------------------------------------------------------
  -- Agitation
  ---------------------------------------------------------------------------------------------------
  local enemy = game.forces.enemy
  local test_labs = {}
  local nests = {}
  local plant_redo = {}
  local function fire(id, ev) if id and W.events[id] then W.events[id](ev) end end
  local function new_lab(f, i, how)
    local c = f.hq_pos
    local pos = { x = math.floor(c.x) + 24 + (i % 8) * 4 + 0.5, y = math.floor(c.y) - 28 - math.floor(i / 8) * 4 + 0.5 }
    local lab_name = i % 3 == 0 and "x10-labo-2" or "lab"
    local e
    if how == "raise" then
      e = s.create_entity({ name = lab_name, position = pos, force = f.force, raise_built = true })
    elseif how == "revive" then
      local g = s.create_entity({ name = "entity-ghost", inner_name = lab_name, position = pos, force = f.force })
      local _, ent = g.revive({ raise_revive = true })
      e = ent
    else
      e = s.create_entity({ name = lab_name, position = pos, force = f.force })
      if how == "joueur" then
        fire(EV.on_built_entity, { created_entity = e, player_index = 1, tick = game.tick })
      elseif how == "robot" then
        fire(EV.on_robot_built_entity, { created_entity = e, tick = game.tick })
      elseif how == "clone" then
        local id = event_id("on_entity_cloned")
        if id and W.events[id] then W.events[id]({ source = e, destination = e, tick = game.tick }) end
      elseif how == "cerveau" then
        local ia3 = f.team and f.team.ia3
        if ia3 then
          ia3.labs = ia3.labs or {}
          ia3.labs[#ia3.labs + 1] = e
        else
          how = "muet"
        end
      end
      if how == "muet" then
        untracked[f.force] = untracked[f.force] or {}
        untracked[f.force][e.unit_number] = true
      end
    end
    if e then test_labs[#test_labs + 1] = e end
  end
  local function outposts_of(f)
    local list = {}
    for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
      local o = f.outposts[oid]
      if o.access or o.pos then list[#list + 1] = { oid = oid, o = o } end
    end
    return list
  end
  local HOWS = { "joueur", "robot", "raise", "revive", "clone", "muet", "cerveau" }
  local step, nlab, nfate, nnest = 0, 0, 0, 0
  local function agitate(tick)
    if tick % 600 ~= 0 or tick < 900 then return end
    step = step + 1
    local list = teams()
    -- l'équipe tourne d'une action à l'autre ET d'un cycle à l'autre (sinon une action tomberait toujours sur la même équipe)
    local f = list[((step - 1) + math.floor((step - 1) / 10)) % #list + 1]
    if not (f and f.hq_pos and not f.eliminated) then return end
    local act = (step - 1) % 10
    if act <= 2 or act == 8 then
      nlab = nlab + 1
      new_lab(f, step, HOWS[(nlab - 1) % #HOWS + 1])
    elseif act == 3 then
      -- un laboratoire du banc meurt (tué, ou détruit sans événement)
      for i, e in ipairs(test_labs) do
        if e.valid then
          if step % 2 == 0 then e.die(enemy) else e.destroy() end
          table.remove(test_labs, i)
          break
        end
      end
    elseif act == 4 then
      -- une tourelle de l'équipe tuée par l'ennemi (cellule du front, relevé)
      local ids = State.sorted_keys(f.turrets or {})
      local t = #ids > 0 and f.turrets[ids[math.floor(#ids / 2) + 1]]
      if t and t.valid then t.die(enemy) end
    elseif act == 5 or act == 9 then
      -- un nid ou un ver à 39 tuiles de l'accès d'un avant-poste (posé sans événement, comme un banc)
      nnest = nnest + 1
      local ops = outposts_of(f)
      local o = ops[(nnest % math.max(1, #ops)) + 1]
      if o then
        local p = o.o.access or o.o.pos
        nests[#nests + 1] = { e = s.create_entity({ name = nnest % 2 == 0 and "biter-spawner" or "small-worm-turret",
          position = { x = p.x + 39, y = p.y }, force = "enemy" }), fkey = key_of(f), oid = o.oid }
      end
    elseif act == 6 then
      -- le plus vieux nid : l'accès de son avant-poste recule de 3 tuiles (le nid passe à 42 tuiles), ou il meurt, ou il est détruit
      local n = nests[1]
      if n and n.e.valid then
        nfate = nfate + 1
        local g
        for _, x in ipairs(teams()) do if key_of(x) == n.fkey then g = x end end
        local o = g and g.outposts and g.outposts[n.oid]
        if nfate % 3 == 1 and o then
          local p = o.access or o.pos
          o.access = { x = p.x - 3, y = p.y }
        elseif nfate % 3 == 2 then
          n.e.die(game.forces.player)
          table.remove(nests, 1)
        else
          n.e.destroy()
          table.remove(nests, 1)
        end
      elseif n then
        table.remove(nests, 1)
      end
    elseif act == 7 then
      -- une chaudière d'une centrale finie tuée, refaite 300 ticks plus tard sans événement
      local b = f.build
      local p = b and b.plant and b.projects[b.plant]
      if p and p.state == "fini" then
        for _, e in ipairs(p.ents) do
          local sp = Mo.spec(e.name) or {}
          if sp.water then
            local real = s.find_entity(e.name, { e.x, e.y })
            if real and real.valid then
              real.die(enemy)
              plant_redo[#plant_redo + 1] = { at = tick + 300, name = e.name, x = e.x, y = e.y, force = f.force }
              break
            end
          end
        end
      end
    end
  end
  -- Une tourelle tuée le tick JUSTE AVANT la pensée de son équipe : on_entity_destroyed (qui la retire de f.turrets) ne vient qu'à la fin
  -- du tick suivant, la vue la voit donc morte dans f.turrets (comme en jeu, où l'événement vient à la fin du tick ou du suivant). Une
  -- par bloc de 1 800 ticks, équipe tournante ; phases des pensées : 7, 82, 157, 232 (factions par rang, Commander.slot_for), 174 (vous).
  local function kill_before_think(tick)
    local list = teams()
    local n = #list - 1
    local j = math.floor(tick / 1800) % #list + 1
    local f = list[j]
    if not (f and f.hq_pos and not f.eliminated and n > 0) then return end
    local phase = f.is_player and 174 or (math.floor((j - 1) * 300 / n) + 7)
    if tick % 1800 ~= (phase - 1) % 300 + 300 then return end
    local ids = State.sorted_keys(f.turrets or {})
    local t = #ids > 0 and f.turrets[ids[1]]
    if t and t.valid then t.die(enemy) end
  end
  local function redo(tick)
    local keep = {}
    for _, r in ipairs(plant_redo) do
      if tick >= r.at then s.create_entity({ name = r.name, position = { x = r.x, y = r.y }, force = r.force }) else keep[#keep + 1] = r end
    end
    plant_redo = keep
  end
  local function restore(copy)
    for k in pairs(global) do global[k] = nil end
    local c = M.deepcopy_global(copy)
    for k, v in pairs(c) do global[k] = v end
  end

  local total = min * 3600
  for i = 1, total do
    M.run_ticks(1)
    local tick = game.tick
    agitate(tick)
    kill_before_think(tick)
    redo(tick)
    if i == math.floor(total / 3) then restore(M.deepcopy_global(global)) end
    if i == math.floor(total / 2) then
      W.on_config({ mod_changes = {} })
      for _, f in ipairs(teams()) do cfg[key_of(f)] = true end
    end
  end

  local function wr(suffix, text)
    local h = assert(io.open(out .. suffix, "w"))
    h:write(text)
    h:close()
  end
  -- Global sans les champs nouveaux du lot (liste exacte), pour l'A/B
  local saved = {}
  for _, f in ipairs(teams()) do
    if f then
      saved[#saved + 1] = { f, f.front_mem and f.front_mem.labs, f.danger_ap, f.build and f.build.garde_refs }
      if f.front_mem then f.front_mem.labs = nil end
      f.danger_ap = nil
      if f.build then f.build.garde_refs = nil end
    end
  end
  wr("_global.txt", M.serialize(global))
  local jl = {}
  for _, l in ipairs(W.logs) do jl[#jl + 1] = tostring(l) end
  wr("_journal.txt", table.concat(jl, "\n"))
  local info = { "mode " .. mode .. (mut and (" mutant " .. mut) or ""), "minutes " .. min, "agitations " .. step }
  local nlabs, nturrets, nout = 0, 0, 0
  for _, e in ipairs(W.entities) do if e.valid and e.type == "lab" then nlabs = nlabs + 1 end end
  for _, f in ipairs(teams()) do
    if f then
      local nt = 0
      for _, id in ipairs(State.sorted_keys(f.turrets or {})) do if f.turrets[id].valid then nt = nt + 1 end end
      nturrets = nturrets + nt
      nout = nout + #State.sorted_keys(f.outposts or {})
      local b = f.build
      local pl = b and b.plant and b.projects[b.plant]
      local np, nf = 0, 0
      if pl and f.hq and f.hq.valid then
        for _, e in ipairs(pl.ents) do
          local sp = Mo.spec(e.name) or {}
          if sp.water or sp.power_out or sp.kind == "offshore" then
            np = np + 1
            local real = s.find_entity(e.name, { e.x, e.y })
            if real and real.valid and real.force.name == f.force then nf = nf + 1 end
          end
        end
      end
      info[#info + 1] = string.format("equipe %s : tourelles %d, avant-postes %d, centrale %s (%s, pieces %d dont %d trouvees)", key_of(f), nt,
        #State.sorted_keys(f.outposts or {}), pl and tostring(pl.state) or "-", pl and pl.spec and tostring(pl.spec.gen) or "-", np, nf)
    end
  end
  info[#info + 1] = string.format("laboratoires vivants %d, tourelles %d, avant-postes %d", nlabs, nturrets, nout)
  if mode == "ombre" then
    local ks = {}
    for k in pairs(stat) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do info[#info + 1] = "stat " .. k .. " " .. stat[k] end
    info[#info + 1] = "comparaisons " .. checks
    info[#info + 1] = "ecarts " .. ndiff
    for _, d in ipairs(diffs) do info[#info + 1] = "ECART " .. d end
  end
  if mode == "cout" or mode == "appels" or mode == "memoire" then
    for _, slot in ipairs({ "view", "poles" }) do
      local c = cost[slot]
      info[#info + 1] = string.format("cout %s appels %d instructions %d ko %.1f", slot, c.calls, c.ins, c.kb)
    end
    local ks = {}
    for k in pairs(cost.api) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do info[#info + 1] = "api " .. k .. " " .. cost.api[k] end
  end
  wr("_info.txt", table.concat(info, "\n"))
  for _, x in ipairs(saved) do
    local f = x[1]
    if f.front_mem then f.front_mem.labs = x[2] end
    f.danger_ap = x[3]
    if f.build then f.build.garde_refs = x[4] end
  end
  print("[X10-S7-RUN] " .. mode .. " fini")
end

if arg[1] == "--run" then
  run(arg[2], tonumber(arg[3]), arg[4])
  return
end

---------------------------------------------------------------------------------------------------
-- Banc complet
---------------------------------------------------------------------------------------------------
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 end
  print((cond and "  OK : " or "  ECHEC : ") .. msg)
end
local TMP = os.getenv("FO_TMP") or os.getenv("TEMP") or "."
local MIN = tonumber(os.getenv("FO_MIN") or "") or 22        -- ombre, A/B, coût, mutant des centrales (une centrale finie vers 20 min)
local MIN_MUT = tonumber(os.getenv("FO_MIN_MUT") or "") or 10 -- autres mutants
local PAR = tonumber(os.getenv("FO_PAR") or "") or 3          -- passages en même temps
local OLD = os.getenv("FO_S7_OLD")
local function slurp(path)
  local h = io.open(path, "r")
  if not h then return nil end
  local t = h:read("*a")
  h:close()
  return t
end
--- Passages en lots de PAR processus : io.popen lance le processus tout de suite, la lecture attend sa fin.
local function runs(jobs)
  local res = {}
  for i0 = 1, #jobs, PAR do
    local open = {}
    for i = i0, math.min(#jobs, i0 + PAR - 1) do
      local j = jobs[i]
      local out = TMP .. "/x10s7_" .. j.tag
      local env = j.mut and ('FO_S7_MUT=' .. j.mut .. ' ') or 'FO_S7_MUT= '
      local cd = j.dir and ('cd "' .. j.dir .. '" && ') or ''
      local cmd = string.format('%s%s%s "%s" --run %s %s "%s" 2>&1', cd, env, LUA, SELF, j.mode, j.min, out)
      open[#open + 1] = { j = j, out = out, h = io.popen(cmd) }
    end
    for _, o in ipairs(open) do
      local text = o.h:read("*a")
      o.h:close()
      res[o.j.tag] = { ok = text:find("[X10-S7-RUN] " .. o.j.mode .. " fini", 1, true) ~= nil, out = o.out, text = text }
    end
  end
  return res
end
local function info_of(out)
  local t = slurp(out .. "_info.txt") or ""
  return t, tonumber(t:match("ecarts (%d+)") or "-1")
end

local jobs = { { mode = "ombre", min = MIN, tag = "ombre" } }
for _, id in ipairs(MUT_ORDER) do
  jobs[#jobs + 1] = { mode = "ombre", min = id == "refs-valid" and MIN or MIN_MUT, tag = "mut_" .. id, mut = id }
end
if OLD then
  for _, m in ipairs({ "jeu", "cout", "memoire", "appels" }) do
    jobs[#jobs + 1] = { mode = m, min = MIN, tag = m .. "_ancien", dir = OLD }
    jobs[#jobs + 1] = { mode = m, min = MIN, tag = m .. "_nouveau" }
  end
end
print(string.format("%d passage(s), %d à la fois", #jobs, PAR))
local R = runs(jobs)

print("== Q1 : ombre (" .. MIN .. " min)")
local r = R.ombre
check(r.ok, "partie jouée" .. (r.ok and "" or (" : " .. r.text:sub(-600))))
local inf, nd = info_of(r.out)
print(inf)
check(nd == 0, "0 écart entre les lectures nouvelles et l'ancien calcul (" .. nd .. ")")
for _, k in ipairs({ "front_turrets", "gc_plants", "refreshes", "scans", "danger_hit", "danger_memo", "groups", "iron" }) do
  local n = tonumber(inf:match("stat " .. k .. " (%d+)") or "0")
  check(n > 0, "la partie exerce " .. k .. " (" .. n .. ")")
end
local sc, sw = tonumber(inf:match("stat scans (%d+)") or "-1"), tonumber(inf:match("stat scans_want (%d+)") or "-2")
check(sc == sw, string.format("relevés complets des laboratoires : %d, attendus %d", sc, sw))

print("== Q3 : mutants (" .. MIN_MUT .. " min chacun ; refs-valid " .. MIN .. " min)")
for _, id in ipairs(MUT_ORDER) do
  local m = R["mut_" .. id]
  local _, ndm = info_of(m.out)
  check(m.ok and ndm > 0, "mutant " .. id .. " vu par l'ombre (" .. ndm .. " écart(s))" .. (m.ok and "" or (" : " .. m.text:sub(-300))))
end

if OLD then
  print("== Q2 : A/B contre l'ancien code (" .. OLD .. ", " .. MIN .. " min)")
  local a, b = R.jeu_ancien, R.jeu_nouveau
  check(a.ok and b.ok, "deux parties jouées" .. ((a.ok and b.ok) and "" or (" : " .. (a.ok and b.text or a.text):sub(-600))))
  local ja, jb = slurp(a.out .. "_journal.txt"), slurp(b.out .. "_journal.txt")
  local ga, gb = slurp(a.out .. "_global.txt"), slurp(b.out .. "_global.txt")
  local nl = 0
  for _ in (ja or ""):gmatch("[^\n]+") do nl = nl + 1 end
  check(ja ~= nil and ja == jb, "journal identique ligne pour ligne (" .. nl .. " lignes)")
  check(ga ~= nil and ga == gb, "global identique (" .. #(ga or "") .. " octets), champs nouveaux retirés")
  print("== Q4 : coût avant et après (" .. MIN .. " min)")
  for _, m in ipairs({ "cout", "memoire", "appels" }) do
    local c, d = R[m .. "_ancien"], R[m .. "_nouveau"]
    check(c.ok and d.ok, "deux parties mesurées (" .. m .. ")")
    print("-- ancien (" .. m .. ")\n" .. (slurp(c.out .. "_info.txt") or "?"))
    print("-- nouveau (" .. m .. ")\n" .. (slurp(d.out .. "_info.txt") or "?"))
  end
end

print(string.format("[X10-S7] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
