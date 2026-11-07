--[[
  Lot X10-S4 (7/11) : REGISTRE DES GÉNÉRATRICES (script/team/generateurs.lua) à la place de six recherches sur toute la surface.
  Critères écrits avant le code : fo-logs\2026-11-07_X10\S4_CRITERES.md.

  Partie du moteur simulé : 4 factions et votre équipe, plan directeur et centrale pour toutes les équipes (montage de
  tests/decoupage_pensee_test.lua), et une AGITATION déterministe, une fois par seconde de jeu :
    - machine à vapeur posée « par le joueur » (on_built_entity), par script avec raise_built, fantôme ravivé avec raise_revive ;
    - une machine posée SANS événement au départ (avant toute lecture : le relevé complet doit la voir), et une juste avant un
      on_configuration_changed joué REGISTRE EN PLACE (il doit être refait) : aucune pose sans événement n'est donc suivie d'une
      lecture sans relevé complet entre les deux (la limite du module, comptée hors Q1) ;
    - génératrice détruite ; numéro de réseau électrique changé (le moteur simulé n'en a pas : écrit par le test) ;
    - sauvegarde rechargée SANS registre, suivie de on_configuration_changed comme au moteur (F130) ; plus tard, un second
      on_configuration_changed.
  Q1 : à CHAQUE lecture (celles du mod, et celles du test : chaque équipe, chaque seconde), Gens.list rend les mêmes entités, dans
       l'ordre des unit_number, que l'ancienne recherche faite au même instant ; Gens.networks le même ensemble de réseaux.
  Q2 : la même partie avec Gens.ENABLED = false donne le même journal ligne à ligne et le même global (espace « gens » retiré).
  Q3 : mutants (source changée, chargée par package.preload) qui DOIVENT être vus par Q1 : pas de relevé complet, pose ignorée,
       invalides gardées, registre gardé à on_configuration_changed.

  Usage : lua5.2 tests/x10_s4_test.lua [minutes = 2]    (depuis la racine du mod ; environ 35 s le 7/11)
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

local function mutated(path, subs)
  local fh = assert(io.open(path, "rb"))
  local src = fh:read("*a")
  fh:close()
  for _, s in ipairs(subs) do
    local a, b = src:find(s[1], 1, true)
    assert(a, "mutant : texte absent de " .. path .. " : " .. s[1])
    assert(not src:find(s[1], b + 1, true), "mutant : texte présent plusieurs fois dans " .. path .. " : " .. s[1])
    src = src:sub(1, a - 1) .. s[2] .. src:sub(b + 1)
  end
  return src
end

local G = "script/team/generateurs.lua"
local MUTANTS = {
  sans_releve = { { "local b = bucket(S, surface.index, fname) or full_scan(S, surface, fname)",
    "local b = bucket(S, surface.index, fname) or (function() S.by[surface.index] = S.by[surface.index] or {}; " ..
    "S.by[surface.index][fname] = { list = {}, type = {}, unit = {}, seen = {} }; return S.by[surface.index][fname] end)()" } },
  pose_ignoree = { { "  if b then add(b, ent, etype) end", "  if false then add(b, ent, etype) end" } },
  invalides_gardees = { { "    if e.valid then\n      j = j + 1", "    if true then\n      j = j + 1" } },
  config_gardee = { { "  if S then S.by = {} end", "  if S then end" } },
}

local function lcg(seed)
  local s = seed
  return function(n)
    s = (s * 1103515245 + 12345) % 2147483648
    return math.floor(s / 65536) % n + 1
  end
end

--- mode : "jeu" (registre, contrôlé), "ref" (Gens.ENABLED = false) ou un nom de MUTANTS.
local function play(mode, mins)
  package.preload["script.team.generateurs"] = nil
  local mut = MUTANTS[mode]
  if mut then
    local src = mutated(G, mut)
    package.preload["script.team.generateurs"] = function(name) return assert(load(src, "=" .. G))(name) end
  end
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0, ia3e = true })
  local W = M.world()
  for _, p in pairs(W.prototypes) do if p.has_flag == nil then p.has_flag = function() return false end end end
  W.settings["fo-recruit-idle-max"] = 60
  W.settings["fo-war-workers"] = 30
  local r = { reads = 0, mod_reads = 0, diffs = 0, ndiffs = 0, first = nil, gens_max = 0, test_reading = false, calls = {}, powered = 0 }
  local s = game.surfaces[1]
  -- Une machine à vapeur posée SANS événement avant toute lecture (une partie d'avant ce lot) : le relevé complet doit la voir.
  local e0 = s.create_entity({ name = "steam-engine", position = { x = 40.5, y = 40.5 }, force = "player" })
  if e0 then rawset(e0, "electric_network_id", 7) end

  local function install()
    local Gens = require("script.team.generateurs")
    if mode == "ref" then Gens.ENABLED = false end
    local o_list = Gens.list
    local function old_list(surface, force, types)
      local out = {}
      for _, e in ipairs(surface.find_entities_filtered({ force = force, type = types })) do
        if e.valid then out[#out + 1] = e end
      end
      table.sort(out, function(a, b) return a.unit_number < b.unit_number end)
      return out
    end
    local function sig(list)
      local t = {}
      for _, e in ipairs(list) do t[#t + 1] = tostring(e.valid and e.unit_number or "X") end
      return table.concat(t, ",")
    end
    Gens.list = function(surface, force, types)
      local got = o_list(surface, force, types)
      local want = old_list(surface, force, types)
      r.reads = r.reads + 1
      if not r.test_reading then r.mod_reads = r.mod_reads + 1 end
      if #want > r.gens_max then r.gens_max = #want end
      local a, b = sig(got), sig(want)
      if a ~= b then
        r.diffs = r.diffs + 1
        r.first = r.first or string.format("tick %d, %s : registre [%s] recherche [%s]", game.tick, tostring(force), a, b)
      end
      return got
    end
    local o_net = Gens.networks
    Gens.networks = function(surface, force, types)
      local live, n = o_net(surface, force, types)
      local want, wn = {}, 0
      for _, g in ipairs(old_list(surface, force, types)) do
        local id = g.electric_network_id
        if id and not want[id] then want[id] = true wn = wn + 1 end
      end
      local same = n == wn
      for id in pairs(want) do if not live[id] then same = false end end
      if not same then
        r.ndiffs = r.ndiffs + 1
        r.first = r.first or string.format("tick %d, %s : réseaux %d contre %d", game.tick, tostring(force), n, wn)
      end
      return live, n
    end
    return Gens
  end
  local Gens = install()

  assert(remote.call("factorio-overhaul", "war_start", 4, 100, nil, 320) == true)
  remote.call("factorio-overhaul", "war_fund", 3000)
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W.events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  local Build = require("script.team.build")
  local State = require("script.faction.state") -- relu après le rechargement (modules rechargés)
  local Rv = require("script.team.reseau_vivant")
  local Champ = require("script.team.champ")
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

  local roll = lcg(20261107)
  local placed = 0
  local function spot(f)
    placed = placed + 1
    local p = f.hq_pos or { x = 5, y = 5 }
    return { x = math.floor(p.x) - 30 - (placed % 6) * 4 + 0.5, y = math.floor(p.y) + 20 + math.floor(placed / 6) % 6 * 6 + 0.5 }
  end
  local function gens_all()
    local out = {}
    for _, e in ipairs(W.entities) do if e.valid and e.type == "generator" then out[#out + 1] = e end end
    return out
  end
  local total = mins * 60
  local reload_at, config_at = math.floor(total * 0.45), math.floor(total * 0.7)
  for step = 1, total do
    M.run_ticks(60)
    -- numéros de réseau (le moteur simulé n'en a pas) : posés, puis changés de temps en temps
    for _, g in ipairs(gens_all()) do
      if rawget(g, "electric_network_id") == nil or step % 17 == 0 then rawset(g, "electric_network_id", g.unit_number % 3 + 1) end
    end
    for _, p in ipairs(W.entities) do
      if p.valid and p.type == "electric-pole" and (rawget(p, "electric_network_id") == nil or step % 17 == 0) then
        rawset(p, "electric_network_id", p.unit_number % 4 + 1)
      end
    end
    local ts = teams()
    local f = ts[(step % #ts) + 1]
    if f and f.hq and f.hq.valid then
      if step % 9 == 0 then
        local e = s.create_entity({ name = "steam-engine", position = spot(f), force = f.force })
        if e then W.events[defines.events.on_built_entity]({ created_entity = e, player_index = 1, tick = game.tick }) end
      local sp = spot(f)
      s.create_entity({ name = "medium-electric-pole", position = { x = sp.x, y = sp.y }, force = f.force })
      elseif step % 9 == 3 then
        s.create_entity({ name = "steam-engine", position = spot(f), force = f.force, raise_built = true })
      elseif step % 9 == 6 then
        local g = s.create_entity({ name = "entity-ghost", inner_name = "steam-engine", position = spot(f), force = f.force })
        if g and g.revive then g.revive({ raise_revive = true }) end
      end
    end
    if step % 13 == 0 then
      local list = gens_all()
      if #list > 0 then
        local e = list[roll(#list)]
        if e.valid then e.destroy() end
      end
    end
    -- lectures du test : toutes les équipes, chaque seconde (comparées par l'enveloppe)
    r.test_reading = true
    for _, t in ipairs(ts) do
      if t and t.force then
        Gens.list(s, t.force, "generator")
        Gens.networks(s, t.force, { "generator", "burner-generator", "solar-panel" })
      end
    end
    r.test_reading = false
    -- appels du MOD lui-même (les deux fonctions exportées ; la partie simulée n'atteint pas les autres) : comparés entre registre
    -- et ancienne recherche par Q2 (r.calls), et à chaque lecture par Q1
    for _, t in ipairs(ts) do
      if t and t.force and t.hq and t.hq.valid and t.hq_pos then
        local nr = Rv.net_read(t, s, t.build)
        local live = {}
        for id in pairs(nr.live) do live[#live + 1] = id end
        table.sort(live)
        local pp = Champ.powered_pole(t, s, t.hq_pos.x, t.hq_pos.y, 96)
        if pp then r.powered = r.powered + 1 end
        r.calls[#r.calls + 1] = string.format("%d %s vivants=%s ilots=%d poteau=%s", game.tick, tostring(t.force), table.concat(live, ","),
          nr.islands, pp and (pp.x .. "," .. pp.y) or "-")
      end
    end
    if step == reload_at then
      -- partie d'avant ce lot : pas de registre ; le moteur appelle alors on_configuration_changed (contenu du mod changé, F130)
      local saved = M.deepcopy_global(global)
      if saved.fo then saved.fo.gens = nil end
      M.load_mod()
      _G.global = saved
      Gens = install()
      State = require("script.faction.state")
      Rv = require("script.team.reseau_vivant")
      Champ = require("script.team.champ")
      M.dispatch(W.on_load)
      M.dispatch(W.on_config, { mod_changes = {} })
      r.reloads = (r.reloads or 0) + 1
    end
    if step == config_at then
      -- une machine apparue SANS événement (données ou autre mod changés), puis on_configuration_changed
      local pf = State.faction("player")
      if pf and pf.hq and pf.hq.valid then
        local e = s.create_entity({ name = "steam-engine", position = spot(pf), force = pf.force })
        if e then rawset(e, "electric_network_id", 9) end
      end
      -- registre EN PLACE ici : un registre gardé (mutant config_gardee) ne verrait pas cette machine
      M.dispatch(W.on_config, { mod_changes = {} })
      r.configs = (r.configs or 0) + 1
    end
  end
  r.logs = W.logs
  local saved = global.fo.gens
  global.fo.gens = nil
  r.glob = M.serialize(global)
  global.fo.gens = saved
  return r
end

local t0 = os.clock()
local a = play("jeu", minutes)
print(string.format("[X10-S4] partie (%d min) : %d lecture(s) comparées, au plus %d génératrice(s) d'une force ; %d écart(s) de liste, %d de réseaux (%.0f s)",
  minutes, a.reads, a.gens_max, a.diffs, a.ndiffs, os.clock() - t0))
if a.first then print("   premier écart : " .. a.first) end
check(a.reads >= 500 and a.gens_max >= 3, "Q1 : des lectures sur des forces qui ont des génératrices (" .. a.reads .. " lectures)")
check(a.mod_reads > 0 and a.powered > 0, string.format("Q1 : le mod lit lui-même le registre (%d lecture(s) par Rv.net_read et Champ.powered_pole ; %d poteau(x) alimenté(s) trouvé(s))",
  a.mod_reads, a.powered))
check(a.reloads == 1 and a.configs == 1, "Q1 : rechargement sans registre et on_configuration_changed joués")
check(a.diffs == 0, "Q1 : à chaque lecture, mêmes génératrices, dans le même ordre, que l'ancienne recherche (" .. a.diffs .. " écart(s))")
check(a.ndiffs == 0, "Q1 : à chaque lecture, même ensemble de réseaux (" .. a.ndiffs .. " écart(s))")

local b = play("ref", minutes)
local same = #a.logs == #b.logs
local fl
for i = 1, math.max(#a.logs, #b.logs) do
  if a.logs[i] ~= b.logs[i] then
    same = false
    fl = string.format("ligne %d : [%s] / [%s]", i, tostring(a.logs[i]):sub(1, 160), tostring(b.logs[i]):sub(1, 160))
    break
  end
end
if fl then print("   premier écart de journal : " .. fl) end
check(#a.logs > 100 and same, string.format("Q2 : journal identique ligne à ligne à l'ancienne recherche (%d ligne(s))", #a.logs))
check(a.glob == b.glob, "Q2 : global identique (espace « gens » retiré)")
local cs = #a.calls == #b.calls
for i = 1, #a.calls do if a.calls[i] ~= b.calls[i] then cs = false print("   premier écart des appels : " .. a.calls[i] .. " / " .. tostring(b.calls[i])) break end end
check(#a.calls > 100 and cs, string.format("Q2 : Rv.net_read et Champ.powered_pole rendent la même chose qu'avec l'ancienne recherche (%d appel(s))", #a.calls))

local mm = math.max(2, math.floor(minutes / 2))
for _, name in ipairs({ "sans_releve", "pose_ignoree", "invalides_gardees", "config_gardee" }) do
  local ok, m = pcall(play, name, mm)
  local seen = (not ok) or (m.diffs + m.ndiffs > 0)
  check(seen, string.format("Q3 : mutant %s vu (%s)", name, ok and (m.diffs .. " écart(s) de liste, " .. m.ndiffs .. " de réseaux")
    or ("la partie plante : " .. tostring(m):sub(1, 80))))
end

print(string.format("[X10-S4] BILAN : %d OK%s", ok_n, fail_n > 0 and (", " .. fail_n .. " ECHEC(S)") or ""))
os.exit(fail_n == 0 and 0 or 1)
