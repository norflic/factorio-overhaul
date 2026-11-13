--[[
  Lot UPS (13/11) : REGISTRE DES MACHINES par force et par type (script/team/registre_types.lua) à la place des recherches sur toute
  la surface de cinq fichiers, et les trois raccourcis de script/team/build.lua (un arbre de rues par pensée, revue des obstacles
  sautée quand tous sont faits, boucle des refus du chantier sautée quand aucun refus n'a été compté).

  Partie du moteur simulé (montage de tests/x10_s4_test.lua) : 4 factions et votre équipe, plan directeur et centrale, et une AGITATION
  déterministe, une fois par seconde de jeu : machines des cinq types posées par le joueur (on_built_entity), par script avec
  raise_built, par fantôme ravivé, SANS événement puis notées (RegT.note, comme les onze sites du mod), une machine posée sans
  événement avant toute lecture (le relevé complet doit la voir), machines détruites, sauvegarde rechargée SANS registre suivie de
  on_configuration_changed, puis un second on_configuration_changed après une pose sans événement ni note.

  Q1 : à CHAQUE lecture (celles du mod et celles du test), RegT.list et RegT.named rendent le même ENSEMBLE d'entités que l'ancienne
       recherche faite au même instant, sans doublon.
  Q2 : la même partie avec RegT.ENABLED = false donne le même journal ligne à ligne et le même global (espace « regtypes » retiré) ;
       la même partie avec les trois raccourcis de build.lua retirés aussi (champs obst_faits et fails_lus retirés du global).
  Q3 : mutants (source changée, chargée par package.preload) qui DOIVENT être vus par Q1.
  Q4 : garde de dérive : les create_entity de script/ sans « raise_built = true » sont ceux du relevé du 13/11 ; chacun de ceux qui
       peuvent poser une machine d'un type tenu est suivi d'un RegT.note.

  Usage : lua5.2 tests/registre_types_test.lua [minutes = 2]    (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local minutes = tonumber(arg[1]) or 2
local M = require("tests.mock_engine")

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 print("OK     " .. msg) else fail_n = fail_n + 1 print("ECHEC : " .. msg) end
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
  return out
end

local function read_file(path)
  local fh = assert(io.open(path, "rb"))
  local src = fh:read("*a")
  fh:close()
  return src
end

local function mutated(path, subs)
  local src = read_file(path):gsub("\r\n", "\n")
  for _, s in ipairs(subs) do
    local a, b = src:find(s[1], 1, true)
    assert(a, "mutant : texte absent de " .. path .. " : " .. s[1])
    assert(not src:find(s[1], b + 1, true), "mutant : texte présent plusieurs fois dans " .. path .. " : " .. s[1])
    src = src:sub(1, a - 1) .. s[2] .. src:sub(b + 1)
  end
  return src
end

local R = "script/team/registre_types.lua"
local B = "script/team/build.lua"
local MUTANTS = {
  sans_releve = { R, { { "  local bs = S.by[idx] or scan_all(S, surface)\n",
    "  local bs = S.by[idx] or (function() S.by[idx] = {}; return S.by[idx] end)()\n" },
    { "  for _, i in ipairs(idx) do scan_all(S, game.surfaces[i]) end\n", "" } } },
  pose_ignoree = { R, { { "  add(bucket(bs, ent.force.name, etype), ent)\nend", "end" } } },
  invalides_gardees = { R, { { "        if e.valid then\n          j = j + 1", "        if true then\n          j = j + 1" } } },
  config_gardee = { R, { { "  if S then rescan_all(S) end", "  if S then end" } } },
  type_non_tenu = { R, { { "    if not TRACKED[t] then return nil end\n", "" } } },
  force_melangee = { R, { { "      local b = bucket(bs, fname, t)\n", "      local b = bucket(bs, \"player\", t)\n" } } },
  nom_ignore = { R, { { "    if e.name == name then out[#out + 1] = e end", "    out[#out + 1] = e" } } },
  -- témoin de Q2 : build.lua SANS les trois raccourcis du lot (le journal et le global doivent rester ceux du lot)
  build_sans_raccourcis = { B, {
    { "  if p.obst_faits ~= nil and p.obst_faits == p.obstacles then return 0 end\n", "" },
    { "    elseif p.fails_lus ~= true then\n", "    else\n" },
    { "      tree = tree or P.route_tree({ i = hi, j = hj }, passable, b.radius)\n      local nodes = P.tree_path(tree, { i = ti, j = tj })\n",
      "      local nodes = P.route_nodes({ i = hi, j = hj }, { i = ti, j = tj }, passable, b.radius)\n" },
  } },
}
local MODULE = { [R] = "script.team.registre_types", [B] = "script.team.build" }

local function lcg(seed)
  local s = seed
  return function(n)
    s = (s * 1103515245 + 12345) % 2147483648
    return math.floor(s / 65536) % n + 1
  end
end

local KINDS = { "burner-mining-drill", "stone-furnace", "boiler", "assembling-machine-1", "electric-mining-drill" }
local TYPES = { "assembling-machine", "boiler", "furnace", "lab", "mining-drill" }

--- Retire du global (copie) les champs que le lot ajoute, pour comparer à une partie sans le lot.
local function strip(v, seen)
  if type(v) ~= "table" or seen[v] then return end
  seen[v] = true
  if getmetatable(v) ~= nil then return end -- (entité du moteur simulé)
  if rawget(v, "obst_faits") ~= nil then v.obst_faits = nil end
  if rawget(v, "fails_lus") ~= nil then v.fails_lus = nil end
  for _, x in pairs(v) do strip(x, seen) end
end

--- mode : "jeu" (registre, contrôlé), "ref" (RegT.ENABLED = false) ou un nom de MUTANTS.
local function play(mode, mins)
  package.preload["script.team.registre_types"] = nil
  package.preload["script.team.build"] = nil
  local mut = MUTANTS[mode]
  if mut then
    local src = mutated(mut[1], mut[2])
    package.preload[MODULE[mut[1]]] = function(name) return assert(load(src, "=" .. mut[1]))(name) end
  end
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0, ia3e = true })
  local W = M.world()
  for _, p in pairs(W.prototypes) do if p.has_flag == nil then p.has_flag = function() return false end end end
  W.settings["fo-recruit-idle-max"] = 60
  W.settings["fo-war-workers"] = 30
  local r = { reads = 0, mod_reads = 0, diffs = 0, first = nil, max = 0, test_reading = false, named = 0 }
  local s = game.surfaces[1]
  -- Une foreuse posée SANS événement avant toute lecture (une partie d'avant ce lot) : le relevé complet doit la voir.
  s.create_entity({ name = "burner-mining-drill", position = { x = 40.5, y = 40.5 }, force = "player" })

  local function sig(list)
    local t, seen, dup = {}, {}, false
    for _, e in ipairs(list) do
      if e.valid then
        local u = e.unit_number
        if seen[u] then dup = true end
        seen[u] = true
        t[#t + 1] = u
      else
        t[#t + 1] = -1
      end
    end
    table.sort(t)
    return table.concat(t, ",") .. (dup and " DOUBLON" or "")
  end
  local function install()
    local RegT = require("script.team.registre_types")
    if mode == "ref" then RegT.ENABLED = false end
    local o_list, o_named = RegT.list, RegT.named
    local in_named = false
    RegT.list = function(surface, force, types, site)
      local got = o_list(surface, force, types, site)
      if in_named then return got end
      local want = surface.find_entities_filtered({ force = force, type = types })
      r.reads = r.reads + 1
      if not r.test_reading then r.mod_reads = r.mod_reads + 1 end
      if #want > r.max then r.max = #want end
      local a, b = sig(got), sig(want)
      if a ~= b then
        r.diffs = r.diffs + 1
        r.first = r.first or string.format("tick %d, %s : registre [%s] recherche [%s]", game.tick, tostring(force), a, b)
      end
      return got
    end
    RegT.named = function(surface, force, name, site)
      in_named = true
      local got = o_named(surface, force, name, site)
      in_named = false
      local want = surface.find_entities_filtered({ force = force, name = name })
      r.reads, r.named = r.reads + 1, r.named + 1
      if not r.test_reading then r.mod_reads = r.mod_reads + 1 end
      local a, b = sig(got), sig(want)
      if a ~= b then
        r.diffs = r.diffs + 1
        r.first = r.first or string.format("tick %d, %s, nom %s : registre [%s] recherche [%s]", game.tick, tostring(force), name, a, b)
      end
      return got
    end
    return RegT
  end
  local RegT = install()

  assert(remote.call("factorio-overhaul", "war_start", 4, 100, nil, 320) == true)
  remote.call("factorio-overhaul", "war_fund", 3000)
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W.events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  local Build = require("script.team.build")
  local State = require("script.faction.state")
  M.run_ticks(120)
  local function teams()
    local all = {}
    for _, id in ipairs(State.alive()) do all[#all + 1] = State.faction(id) end
    all[#all + 1] = State.faction("player")
    return all
  end
  for _, f in ipairs(teams()) do
    if f and f.hq and f.hq.valid then
      Build.enable(f, { radius = 3 })
      Build.plant(f)
    end
  end

  local roll = lcg(20261113)
  local placed = 0
  local function spot(f)
    placed = placed + 1
    local p = f.hq_pos or { x = 5, y = 5 }
    return { x = math.floor(p.x) - 30 - (placed % 6) * 4 + 0.5, y = math.floor(p.y) + 20 + math.floor(placed / 6) % 6 * 6 + 0.5 }
  end
  local function machines()
    local out = {}
    for _, e in ipairs(W.entities) do
      if e.valid then
        for _, t in ipairs(TYPES) do if e.type == t then out[#out + 1] = e end end
      end
    end
    return out
  end
  local total = mins * 60
  local reload_at, config_at = math.floor(total * 0.45), math.floor(total * 0.7)
  for step = 1, total do
    M.run_ticks(60)
    local ts = teams()
    local f = ts[(step % #ts) + 1]
    local kind = KINDS[step % #KINDS + 1]
    if f and f.hq and f.hq.valid then
      if step % 4 == 0 then
        local e = s.create_entity({ name = kind, position = spot(f), force = f.force })
        if e then W.events[defines.events.on_built_entity]({ created_entity = e, player_index = 1, tick = game.tick }) end
      elseif step % 4 == 1 then
        s.create_entity({ name = kind, position = spot(f), force = f.force, raise_built = true })
      elseif step % 4 == 2 then
        local g = s.create_entity({ name = "entity-ghost", inner_name = kind, position = spot(f), force = f.force })
        if g and g.revive then g.revive({ raise_revive = true }) end
      else
        RegT.note(s.create_entity({ name = kind, position = spot(f), force = f.force })) -- pose sans événement, notée (les onze sites)
      end
    end
    if step % 7 == 0 then
      local list = machines()
      if #list > 0 then
        local e = list[roll(#list)]
        if e.valid then e.destroy() end
      end
    end
    -- lectures du test : toutes les équipes, chaque seconde (comparées par l'enveloppe)
    r.test_reading = true
    for _, t in ipairs(ts) do
      if t and t.force then
        RegT.list(s, t.force, "mining-drill")
        RegT.list(s, t.force, { "boiler", "furnace", "mining-drill" })
        RegT.list(s, t.force, { "lab" })
        RegT.list(s, t.force, "assembling-machine")
        RegT.named(s, t.force, "electric-mining-drill")
        RegT.named(s, t.force, "burner-mining-drill")
        RegT.named(s, t.force, "objet-inconnu-du-jeu")
      end
    end
    r.test_reading = false
    if step == reload_at then
      local saved = M.deepcopy_global(global)
      if saved.fo then saved.fo.regtypes = nil end
      M.load_mod()
      _G.global = saved
      RegT = install()
      Build = require("script.team.build")
      State = require("script.faction.state")
      M.dispatch(W.on_load)
      local sc0 = RegT.stats.scans
      M.dispatch(W.on_config, { mod_changes = {} })
      r.cfg_scans = r.cfg_scans or {}
      r.cfg_scans[#r.cfg_scans + 1] = RegT.stats.scans - sc0
      r.reloads = (r.reloads or 0) + 1
    end
    if step == config_at then
      -- une machine apparue SANS événement ni note (données ou autre mod changés), puis on_configuration_changed
      local pf = State.faction("player")
      if pf and pf.hq and pf.hq.valid then s.create_entity({ name = "stone-furnace", position = spot(pf), force = pf.force }) end
      local sc0 = RegT.stats.scans
      M.dispatch(W.on_config, { mod_changes = {} })
      r.cfg_scans = r.cfg_scans or {}
      r.cfg_scans[#r.cfg_scans + 1] = RegT.stats.scans - sc0
      r.configs = (r.configs or 0) + 1
    end
  end
  r.untracked = #RegT.list(s, "player", "container") -- type non tenu : l'ancienne recherche (comparée par l'enveloppe)
  r.logs = W.logs
  r.ready = RegT.ready()
  local copy = M.deepcopy_global(global)
  if copy.fo then copy.fo.regtypes = nil end
  strip(copy, {})
  r.glob = M.serialize(copy)
  return r
end

local t0 = os.clock()
local a = play("jeu", minutes)
print(string.format("[REGISTRE] partie (%d min) : %d lecture(s) comparées (%d par nom, %d par le mod), au plus %d machine(s) d'une force ; %d écart(s) (%.0f s)",
  minutes, a.reads, a.named, a.mod_reads, a.max, a.diffs, os.clock() - t0))
if a.first then print("   premier écart : " .. a.first) end
check(a.reads >= 500 and a.max >= 5, "Q1 : des lectures sur des forces qui ont des machines (" .. a.reads .. " lectures, " .. a.max .. " machines au plus)")
check(a.mod_reads > 0, "Q1 : le mod lit lui-même le registre (" .. a.mod_reads .. " lecture(s))")
check(a.reloads == 1 and a.configs == 1, "Q1 : rechargement sans registre et on_configuration_changed joués")
check(a.diffs == 0, "Q1 : à chaque lecture, le même ensemble de machines que l'ancienne recherche, sans doublon (" .. a.diffs .. " écart(s))")
check(a.untracked > 0, "Q1 : type non tenu (« container ») : l'ancienne recherche rend " .. a.untracked .. " entité(s)")
local cs = a.cfg_scans or {}
check(#cs == 2 and cs[1] == 1 and cs[2] == 1, "Q1 : relevé complet dans on_configuration_changed, un par surface (" .. table.concat(cs, ", ") .. ")")

local function same_logs(x, y)
  for i = 1, math.max(#x, #y) do
    if x[i] ~= y[i] then return false, string.format("ligne %d : [%s] / [%s]", i, tostring(x[i]):sub(1, 160), tostring(y[i]):sub(1, 160)) end
  end
  return true
end
local b = play("ref", minutes)
check(a.ready == true and b.ready == false, "Q2 : registre prêt en partie, pas prêt éteint")
local same, where = same_logs(a.logs, b.logs)
if where then print("   premier écart de journal : " .. where) end
check(#a.logs > 100 and same, string.format("Q2 : journal identique ligne à ligne à l'ancienne recherche (%d ligne(s))", #a.logs))
check(a.glob == b.glob, "Q2 : global identique à l'ancienne recherche (espace « regtypes » retiré)")
local c = play("build_sans_raccourcis", minutes)
same, where = same_logs(a.logs, c.logs)
if where then print("   premier écart de journal : " .. where) end
check(same, string.format("Q2 : journal identique ligne à ligne à build.lua sans les trois raccourcis (%d ligne(s))", #c.logs))
check(a.glob == c.glob, "Q2 : global identique à build.lua sans les trois raccourcis (champs obst_faits et fails_lus retirés)")

local mm = math.max(2, math.floor(minutes / 2))
for _, name in ipairs({ "sans_releve", "pose_ignoree", "invalides_gardees", "config_gardee", "type_non_tenu", "force_melangee", "nom_ignore" }) do
  local ok, m = pcall(play, name, mm)
  local seen = (not ok) or m.diffs > 0
  check(seen, string.format("Q3 : mutant %s vu (%s)", name, ok and (m.diffs .. " écart(s)") or ("la partie plante : " .. tostring(m):sub(1, 80))))
end

-- Q4 : garde de dérive des poses sans événement. Fichiers de script/ : liste de git (le dépôt), sinon la liste connue.
local SITES = { -- fichier = { poses sans raise_built = true, dont suivies d'un RegT.note }
  ["script/ai3/cerveau.lua"] = { 1, 1 }, ["script/faction/outposts.lua"] = { 2, 2 }, ["script/team/foreuse_swap.lua"] = { 2, 2 },
  ["script/team/migration_champ.lua"] = { 2, 2 }, ["script/team/quartiers.lua"] = { 1, 1 }, ["script/team/stock.lua"] = { 1, 1 },
  ["script/team/swap_entity.lua"] = { 1, 1 }, ["script/team/ia1_remote.lua"] = { 1, 1 }, ["script/team/manque_banc.lua"] = { 2, 2 },
  -- jamais une machine d'un type tenu : unités, QG, coffres, tourelle, tapis et répartiteur (remplacement sur place), décors
  ["script/combat/assaut_titan.lua"] = { 1, 0 }, ["script/companion/registry.lua"] = { 1, 0 }, ["script/faction/military.lua"] = { 1, 0 },
  ["script/faction/war.lua"] = { 1, 0 }, ["script/robots/armee.lua"] = { 1, 0 }, ["script/robots/kaijus.lua"] = { 1, 0 },
  ["script/td/director.lua"] = { 1, 0 }, ["script/team/convoyeurs.lua"] = { 1, 0 }, ["script/team/piquage.lua"] = { 1, 0 },
  ["script/team/player_team.lua"] = { 1, 0 }, ["script/team/team.lua"] = { 1, 0 }, ["script/world/enemy_mechanics.lua"] = { 1, 0 },
}
-- (poses de décors, de tirs et de ressources : jamais une machine ; reconnues à leur texte, hors du compte)
local DECOR = { "flying%-text", "explosion", "entity%-ghost", "projectile", "beam", "smoke", "corpse", "sticker", "highlight", "speech",
  "scorchmark", "flamme", "ORBE", "GRIFFE", "SINGULARITE", "MITRAILLE", "CANON", "DRONE_TIR", "ECLAIR", "FUSION", "ZONE", "PILIER",
  "CHAIN_BEAM", "SARR", "N%.trace", "N%.dard", "N%.trait", "amount =", "CRATERE", "Xp%.PREFIX", "noms%[i%]", "source_offset" }
local function silent_sites(src)
  local n, noted = 0, 0
  local pos = 1
  while true do
    local a, b = src:find("create_entity%s*%(%s*{", pos)
    if not a then break end
    local i, depth = b + 1, 1
    while depth > 0 and i <= #src do
      local ch = src:sub(i, i)
      if ch == "{" then depth = depth + 1 elseif ch == "}" then depth = depth - 1 end
      i = i + 1
    end
    local body = src:sub(b + 1, i - 1)
    local ls = a
    while ls > 1 and src:sub(ls - 1, ls - 1) ~= "\n" do ls = ls - 1 end
    local comment = src:sub(ls, a):match("^%s*%-%-") ~= nil
    local decor = false
    for _, d in ipairs(DECOR) do if body:find(d) then decor = true break end end
    if not comment and not decor and not body:find("raise_built = true", 1, true) then
      n = n + 1
      -- suivi d'un RegT.note dans les 6 lignes qui suivent la pose (deux poses de suite partagent leurs notes)
      local rest = src:sub(i, i + 900)
      local lines = 0
      for line in rest:gmatch("[^\n]*\n") do
        lines = lines + 1
        if lines > 6 then break end
        if line:find("RegT.note(", 1, true) then noted = noted + 1 break end
      end
    end
    pos = i
  end
  return n, noted
end
local files = {}
local h = io.popen("git ls-files script 2>&1")
if h then
  for line in h:lines() do if line:match("^script/.*%.lua$") then files[#files + 1] = line end end
  h:close()
end
check(#files > 200, "Q4 : fichiers de script/ lus par git ls-files (" .. #files .. ")")
local drift = {}
local seen_files = {}
for _, path in ipairs(files) do
  local n, noted = silent_sites(read_file(path))
  local want = SITES[path]
  seen_files[path] = true
  if n > 0 or want then
    if not want or want[1] ~= n or want[2] ~= noted then
      drift[#drift + 1] = string.format("%s : %d pose(s) sans événement dont %d notée(s), attendu %s", path, n, noted,
        want and (want[1] .. " dont " .. want[2]) or "aucune")
    end
  end
end
for path in pairs(SITES) do if not seen_files[path] then drift[#drift + 1] = path .. " : fichier absent" end end
table.sort(drift)
for _, d in ipairs(drift) do print("   " .. d) end
check(#drift == 0, "Q4 : poses sans événement de script/ égales au relevé du 13/11, celles qui peuvent poser une machine suivies de RegT.note (" .. #drift .. " écart(s))")
-- mutant de Q4 : une note retirée doit être vue
do
  local src = read_file("script/team/foreuse_swap.lua")
  local cut = src:gsub("RegT%.note%(new%)", "", 1)
  local _, noted = silent_sites(cut)
  check(noted == 1, "Q4 : mutant « note retirée » vu (foreuse_swap : " .. noted .. " note(s) au lieu de 2)")
end

print(string.format("[REGISTRE] BILAN : %d OK%s", ok_n, fail_n > 0 and (", " .. fail_n .. " ECHEC(S)") or ""))
os.exit(fail_n == 0 and 0 or 1)
