--[[
  Lot PERF4 (tt:repair) : l'ENSEMBLE DES ENDOMMAGÉES (script/team/abimes.lua) rend, à CHAQUE relevé de Recon.repair_think, les mêmes
  entités que l'ancienne recherche sur toute la surface. L'ancienne recherche est recopiée ici (old_cands) :
  find_entities_filtered{force, type}, puis santé < 1. Critères écrits avant le code : fo-logs\2026-11-05_PERF4\CRITERES.md.

  Partie du moteur simulé : 4 factions et votre équipe, avec on_entity_damaged levé par LuaEntity.damage
  (opts.raise_damaged du moteur simulé, filtre « type » du moteur compris). Une AGITATION déterministe s'y ajoute, une fois par
  seconde de jeu :
    - coups partiels et coups mortels sur les tourelles et l'infrastructure des équipes ;
    - santé remise par écriture directe (sans événement) ;
    - tourelle posée raise_built puis blessée par écriture, comme un niveau ou le capital ;
    - tourelle posée sans événement à pleine santé ;
    - fantôme ravivé ;
    - remplacement rapide d'une tourelle blessée (santé gardée par écriture) ;
    - poteau, chaudière ou machine à vapeur de votre équipe posés blessés (on_built_entity, santé déjà basse comme un objet
      abîmé) ;
    - santé max d'un prototype changée, puis on_configuration_changed ;
    - sauvegarde rechargée SANS f.abimes, comme une partie d'avant ce lot.

  1. À chaque relevé : les candidates (unit_number, clé nom@x,y, santé) et le lot de Rc.repair_batch sont égaux à ceux de
     l'ancienne recherche. L'ensemble, restreint aux types relevés, ne garde aucune entité à pleine santé.
  2. Journal et global, f.abimes retiré : la même partie rejouée avec l'ancienne recherche (Ab.ENABLED = false) donne le même
     journal, ligne à ligne, et le même global.
  3. Mutants (texte de la source changé, chargé par package.preload) :
     - DOIVENT échouer : pas de relevé initial, pose oubliée, entité à pleine santé gardée, tourelles absentes du filtre du
       moteur, on_configuration_changed oublié ;
     - DOIT survivre (ordre sans effet : Rc.repair_batch trie) : ensemble parcouru par pairs au lieu de trié.
  4. Coût (moteur simulé, indicatif) : temps des relevés, nouveau contre ancien, sur les MÊMES états.

  Usage : lua5.2 tests/perf4_abimes_test.lua [minutes = 6] (mutants : la moitié, 4 min au moins ; environ 4 min en tout)
]]
package.path = "./?.lua;" .. package.path
local minutes = tonumber(arg[1]) or 6
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
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

local TRACKED = { ["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true,
  ["electric-pole"] = true, boiler = true, generator = true, ["offshore-pump"] = true }

--- L'ANCIENNE recherche de Recon.repair_think (0.6.56, 53368c7d), recopiée : toutes les entités de la force et de ces types.
local function old_list(f, surface, types)
  return surface.find_entities_filtered({ force = f.force, type = types })
end

--- Candidates comme les bâtit Recon.repair_think (même clé, même santé), triées, en une chaîne ; et leur liste.
local function cands_of(list)
  local cands, sig = {}, {}
  for _, e in ipairs(list) do
    local ratio = e.valid and e.get_health_ratio() or nil
    if ratio and ratio < 1 then
      local key = e.name .. "@" .. string.format("%.1f,%.1f", e.position.x, e.position.y)
      cands[#cands + 1] = { key = key, name = e.name, x = e.position.x, y = e.position.y, ratio = ratio, unit = e.unit_number }
      sig[#sig + 1] = string.format("%d %s %.9f", e.unit_number, key, ratio)
    end
  end
  table.sort(sig)
  return cands, table.concat(sig, ";"), #sig
end

local function batch_sig(Rc, cands, below)
  local b = Rc.repair_batch(cands, below)
  local t = {}
  for _, c in ipairs(b) do t[#t + 1] = c.key .. " " .. string.format("%.9f", c.ratio) end
  return table.concat(t, ";")
end

local function teams()
  local out = {}
  local w = global.fo.war
  local ids = {}
  for id in pairs(w.factions or {}) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do out[#out + 1] = w.factions[id] end
  if global.fo.pteam and global.fo.pteam.team then out[#out + 1] = global.fo.pteam.team end
  return out
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
    assert(a, "mutant : texte absent de " .. path .. " : " .. s[1])
    assert(not src:find(s[1], b + 1, true), "mutant : texte présent plusieurs fois dans " .. path .. " : " .. s[1])
    src = src:sub(1, a - 1) .. s[2] .. src:sub(b + 1)
  end
  return src
end

local MUTANTS = {
  sans_releve = { "script.team.abimes", "script/team/abimes.lua",
    { { "if r and r < 1 then ab.set[u] = e end", "if false then ab.set[u] = e end" } } },
  sans_pose = { "script.team.abimes", "script/team/abimes.lua",
    { { "if TRACKED[etype] then Ab.note(ent, etype) end", "if false then Ab.note(ent, etype) end" } } },
  garde_pleine = { "script.team.abimes", "script/team/abimes.lua", { { "if not r or r >= 1 then", "if not r then" } } },
  filtre_sans_tourelles = { "script.team.reparation", "script/team/reparation.lua",
    { { "for _, t in ipairs(Ab.filter_types()) do", "for _, t in ipairs({}) do" } } },
  config_oubliee = { "script.team.abimes", "script/team/abimes.lua",
    { { "if f then f.abimes = nil end", "if f then end" }, { "if p then p.abimes = nil end", "if p then end" } } },
  sans_tri = { "script.team.abimes", "script/team/abimes.lua",
    { { "for _, u in ipairs(sorted_units(set)) do", "for u in pairs(set) do" } } },
}

--- Joue la partie. mode : "jeu" (ensemble des endommagées, contrôlé à chaque relevé contre l'ancienne recherche), "ref"
--- (ancienne recherche : Ab.ENABLED = false) ou un nom de MUTANTS. Rend { scans, diffs, bdiffs, full_kept, cands, logs, glob,
--- t_new, t_old, first }.
local function play(mode, mins)
  local mut = MUTANTS[mode]
  package.preload["script.team.abimes"] = nil
  package.preload["script.team.reparation"] = nil
  if mut then
    local src = mutated(mut[2], mut[3])
    package.preload[mut[1]] = function(name) return assert(load(src, "=" .. mut[2]))(name) end
  end
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0, raise_damaged = true })
  local W = M.world()
  W.settings["fo-recruit-idle-max"] = 60
  W.settings["fo-war-workers"] = 30
  local r = { scans = 0, diffs = 0, bdiffs = 0, full_kept = 0, cands = 0, t_new = 0, t_old = 0, events = 0, built = 0 }

  local function install()
    local Ab = require("script.team.abimes")
    local Recon = require("script.team.reconstruction")
    local Rc = require("shared.team.reconstruction")
    local Ac = require("shared.team.actif")
    if mode == "ref" then Ab.ENABLED = false end
    local orig = Recon.damaged
    assert(orig == Ab.damaged, "crochet Recon.damaged posé par script/team/abimes.lua")
    Recon.damaged = function(f, surface, types)
      local c0 = os.clock()
      local got = orig(f, surface, types)
      local c1 = os.clock()
      local old = old_list(f, surface, types)
      local c2 = os.clock()
      r.t_new, r.t_old = r.t_new + (c1 - c0), r.t_old + (c2 - c1)
      r.scans = r.scans + 1
      local ca, sa = cands_of(got)
      local cb, sb, nb = cands_of(old)
      r.cands = r.cands + nb
      if sa ~= sb then
        r.diffs = r.diffs + 1
        r.first = r.first or string.format("tick %d, %s, %s : nouveau [%s] ancien [%s]", game.tick, tostring(f.key or "player"),
          table.concat(types, ","), sa:sub(1, 200), sb:sub(1, 200))
      end
      local below = (types[1] == Ac.REPAIR_TYPES[1]) and Ac.TURRET_REPAIR_BELOW or nil
      if batch_sig(Rc, ca, below) ~= batch_sig(Rc, cb, below) then r.bdiffs = r.bdiffs + 1 end
      -- Ensemble restreint aux types relevés : aucune entité valide à pleine santé n'y reste après le relevé.
      if f.abimes and Ab.ENABLED then
        local want = {}
        for _, t in ipairs(types) do want[t] = true end
        for _, e in pairs(f.abimes.set) do
          if e.valid and want[e.type] and (e.get_health_ratio() or 1) >= 1 then r.full_kept = r.full_kept + 1 end
        end
      end
      return got
    end
  end
  install()

  assert(remote.call("factorio-overhaul", "war_start", 4, 100, nil, 320) == true)
  remote.call("factorio-overhaul", "war_fund", 3000)
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W.events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })

  local roll = lcg(20261107)
  local function team_ents()
    local out = {}
    for _, e in ipairs(W.entities) do
      if e.valid and TRACKED[e.type] and e.force.name ~= "enemy" and e.force.name ~= "neutral" then out[#out + 1] = e end
    end
    return out
  end
  local function pick(list) return list[roll(#list)] end
  local function spot(f, k)
    local p = f.hq_pos or (f.hq and f.hq.valid and f.hq.position) or { x = 5, y = 5 }
    return { x = math.floor(p.x) + 12 + (k % 9) * 3 + 0.5, y = math.floor(p.y) - 14 + math.floor(k / 9) % 9 * 3 + 0.5 }
  end
  local placed = 0
  local function place(f, name, raise, hp_frac, event)
    placed = placed + 1
    local pos = spot(f, placed)
    local e = s.create_entity({ name = name, position = pos, force = f.force, raise_built = raise or nil })
    if not e then return nil end
    if hp_frac then e.health = e.prototype.max_health * hp_frac end
    if event then
      W.events[defines.events.on_built_entity]({ created_entity = e, player_index = 1, tick = game.tick })
      r.built = r.built + 1
    end
    return e
  end

  local total = mins * 60
  local reload_at, config_at = math.floor(total * 0.45), math.floor(total * 0.7)
  for step = 1, total do
    M.run_ticks(60)
    local ts = teams()
    local ents = team_ents()
    -- coups partiels (1 à 3 par seconde), un coup mortel toutes les 11 s
    if #ents > 0 then
      for _ = 1, roll(3) do
        local e = pick(ents)
        if e.valid then
          e.damage(e.prototype.max_health * roll(40) / 100, "enemy", "physical")
          r.events = r.events + 1
        end
      end
      if step % 11 == 0 then
        local e = pick(ents)
        if e.valid then e.damage(e.prototype.max_health * 2, "enemy", "physical") end
      end
      -- santé REMONTÉE par écriture directe (réparation d'un autre lot, joueur), sans événement : en partie ou en entier. Jamais
      -- baissée : une baisse par écriture sans pose est la limite dite de l'ensemble (script/team/abimes.lua) et le mod n'en fait
      -- aucune (relevé du 7/11).
      if step % 7 == 0 then
        local e = pick(ents)
        if e.valid then
          local mx = e.prototype.max_health
          local target = (roll(2) == 1) and mx or mx * 0.95
          if target > e.health then e.health = target end
        end
      end
    end
    if #ts > 0 then
      local f = ts[(step % #ts) + 1]
      if f.force and f.hq and f.hq.valid then
        if step % 13 == 0 then place(f, "gun-turret", true, 0.3 + roll(5) / 10) end      -- niveau, capital : pose puis santé
        if step % 17 == 0 then place(f, "gun-turret", false) end                         -- avant-poste : pleine santé, sans événement
        if step % 19 == 0 then
          placed = placed + 1
          local pos = spot(f, placed)
          local g = s.create_entity({ name = "entity-ghost", inner_name = "gun-turret", position = pos, force = f.force })
          if g and g.revive then g.revive({ raise_revive = true }) end
        end
        if step % 23 == 0 then
          -- remplacement rapide d'une tourelle blessée de l'équipe, santé gardée par écriture (Levels.replace)
          for _, e in ipairs(ents) do
            if e.valid and e.force.name == f.force and e.type == "ammo-turret" and (e.get_health_ratio() or 1) < 1 then
              local ratio, pos = e.get_health_ratio(), e.position
              local new = s.create_entity({ name = e.name, position = pos, force = f.force, fast_replace = true, raise_built = true })
              if new then new.health = new.prototype.max_health * ratio end
              break
            end
          end
        end
      end
    end
    local pt = global.fo.pteam and global.fo.pteam.team
    if pt and pt.force and pt.hq and pt.hq.valid then
      if step % 5 == 0 then
        local names = { "medium-electric-pole", "big-electric-pole", "boiler", "steam-engine", "offshore-pump" }
        place(pt, names[roll(#names)], false, 0.2 + roll(7) / 10, true)                  -- objet abîmé posé par le joueur
      end
      if step % 29 == 0 then place(pt, "medium-electric-pole", false) end                -- posé sans événement, plein
    end
    if step == reload_at then
      -- Sauvegarde rechargée, f.abimes retiré : une partie d'avant ce lot (relevé complet au prochain relevé).
      for _, f in ipairs(teams()) do f.abimes = nil end
      local saved = M.deepcopy_global(global)
      M.load_mod()
      _G.global = saved
      M.dispatch(W.on_load)
      install()
    end
    if step == config_at then
      -- Données changées : santé max des tourelles et des poteaux moyens augmentée, aucun événement par entité.
      W.prototypes["gun-turret"].max_health = 500
      W.prototypes["medium-electric-pole"].max_health = 120
      M.dispatch(W.on_config, { mod_changes = {}, mod_startup_settings_changed = false, migration_applied = false })
    end
  end
  W.prototypes["gun-turret"].max_health = 400
  W.prototypes["medium-electric-pole"].max_health = 100
  r.logs = W.logs
  local keep = {}
  for _, f in ipairs(teams()) do
    keep[f] = f.abimes
    f.abimes = nil
  end
  r.glob = M.serialize(global)
  for f, ab in pairs(keep) do f.abimes = ab end
  return r
end

local t0 = os.clock()
local a = play("jeu", minutes)
print(string.format("[PERF4-ABIMES] partie (%d min) : %d relevé(s), %d candidate(s) en tout, %d coup(s) donnés, %d pose(s) du joueur ; " ..
  "%d écart(s) de candidates, %d de lot, %d entité(s) pleines gardées (%.1f s)", minutes, a.scans, a.cands, a.events, a.built, a.diffs,
  a.bdiffs, a.full_kept, os.clock() - t0))
if a.first then print("   premier écart : " .. a.first) end
print(string.format("[PERF4-ABIMES] coût des relevés (moteur simulé, MÊMES états) : ancien %.3f ms par relevé, nouveau %.3f ms",
  a.t_old * 1e3 / math.max(1, a.scans), a.t_new * 1e3 / math.max(1, a.scans)))
check(a.scans >= 20, "la partie relève les endommagées (" .. a.scans .. " relevé(s))")
check(a.cands >= 20, "des entités endommagées sont relevées (" .. a.cands .. " candidate(s) en tout)")
check(a.diffs == 0, "à chaque relevé, mêmes candidates (numéro, clé, santé) que l'ancienne recherche (" .. a.diffs .. " écart(s))")
check(a.bdiffs == 0, "à chaque relevé, même lot de Rc.repair_batch (" .. a.bdiffs .. " écart(s))")
check(a.full_kept == 0, "aucune entité à pleine santé gardée dans l'ensemble après un relevé (" .. a.full_kept .. ")")

local b = play("ref", minutes)
local same_logs = #a.logs == #b.logs
local first_log
for i = 1, math.max(#a.logs, #b.logs) do
  if a.logs[i] ~= b.logs[i] then
    same_logs = false
    first_log = string.format("ligne %d : [%s] / [%s]", i, tostring(a.logs[i]):sub(1, 160), tostring(b.logs[i]):sub(1, 160))
    break
  end
end
print(string.format("[PERF4-ABIMES] journal : %d ligne(s) avec l'ensemble, %d avec l'ancienne recherche", #a.logs, #b.logs))
if first_log then print("   premier écart : " .. first_log) end
check(#a.logs > 100 and same_logs, "journal identique ligne à ligne à celui de l'ancienne recherche")
check(a.glob == b.glob, "global identique (f.abimes retiré) à celui de l'ancienne recherche")

local mins_mut = math.max(4, math.floor(minutes / 2))
for _, name in ipairs({ "sans_releve", "sans_pose", "garde_pleine", "filtre_sans_tourelles", "config_oubliee" }) do
  local m = play(name, mins_mut)
  local seen = m.diffs + m.bdiffs + m.full_kept
  check(seen > 0, string.format("mutant %s : vu (%d écart(s) de candidates, %d de lot, %d pleine(s) gardée(s), sur %d relevé(s))", name,
    m.diffs, m.bdiffs, m.full_kept, m.scans))
end
do
  local m = play("sans_tri", mins_mut)
  check(m.diffs == 0 and m.bdiffs == 0 and m.full_kept == 0 and m.scans >= 10,
    string.format("mutant sans_tri : SURVIT (ordre sans effet sur la sortie : Rc.repair_batch trie), %d relevé(s)", m.scans))
end

print(string.format("BILAN : %d OK%s", ok_n, fail_n > 0 and (", " .. fail_n .. " ECHEC(S)") or ""))
os.exit(fail_n == 0 and 0 or 1)
