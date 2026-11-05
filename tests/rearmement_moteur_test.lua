--[[
  Lot REARMEMENT : banc HORS JEU de la chaîne, moteur simulé (tests/mock_engine.lua). Votre équipe (coffre posé) ET une faction (guerre lancée).
    chaîne : armes vidées (le scénario retire tous les chargeurs de l'emplacement des PNJ) -> tâches ordinaires -> étape « home » ->
    deposit_all -> rearm (Ra.take, plancher de la défense) -> emplacement à 10 ; journal [FO-REARMEMENT].
  Mutant de chaîne : T.rearm_on = faux (la règle d'avant) : les armes restent vides.
  Lancement : lua5.2 tests/rearmement_moteur_test.lua (racine du mod ; environ 1 min).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end

local function patches() -- même carte que tests/kit_moteur_test.lua (gisements autour des QG à 320 tuiles) + ceux du coffre du joueur
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

local AMMO, GUN = "firearm-magazine", "pistol"

--- Les PNJ armés d'une équipe : { total, armés, à 10 ou plus, vides }.
local function arms(f)
  local Registry = require("script.companion.registry")
  local State = require("script.faction.state")
  local out = { n = 0, gun = 0, full = 0, empty = 0 }
  for _, id in ipairs(State.sorted_keys(f.engineers or {})) do
    local a = Registry.get(id)
    local e = a and a.entity
    if e and e.valid then
      out.n = out.n + 1
      if e.get_inventory(defines.inventory.character_guns).get_item_count(GUN) > 0 then
        out.gun = out.gun + 1
        local c = e.get_inventory(defines.inventory.character_ammo).get_item_count(AMMO)
        if c >= 10 then out.full = out.full + 1 end
        if c == 0 then out.empty = out.empty + 1 end
      end
    end
  end
  return out
end

--- Vide l'emplacement des munitions de tous les PNJ de l'équipe ; rend le nombre de chargeurs retirés.
local function empty_guns(f)
  local Registry = require("script.companion.registry")
  local State = require("script.faction.state")
  local n = 0
  for _, id in ipairs(State.sorted_keys(f.engineers or {})) do
    local a = Registry.get(id)
    local e = a and a.entity
    if e and e.valid then
      local inv = e.get_inventory(defines.inventory.character_ammo)
      local c = inv.get_item_count(AMMO)
      if c > 0 then n = n + inv.remove({ name = AMMO, count = c }) end
    end
  end
  return n
end

local function run(rule_on)
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0, kit_egal = false })
  M.world().settings["fo-war-workers"] = 8
  local ok = remote.call("factorio-overhaul", "war_start", 2, 100, nil, 320)
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 200 }, { "stone-furnace", 8 },
      { GUN, 2 }, { AMMO, 200 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  M.world().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  M.run_ticks(900)
  local T = require("shared.team.config")
  T.rearm_on = rule_on
  local pteam = global.fo.pteam and global.fo.pteam.team
  local fac = global.fo.war and global.fo.war.factions and global.fo.war.factions[1]
  if fac and fac.hq and fac.hq.valid then fac.hq.insert({ name = AMMO, count = 200 }) end
  local res = { ok = ok == true and pteam ~= nil and fac ~= nil }
  res.removed_p = pteam and empty_guns(pteam) or 0
  res.removed_f = fac and empty_guns(fac) or 0
  local okr, err = pcall(M.run_ticks, 3 * 3600)
  res.sim_ok, res.err = okr, err
  res.p = pteam and arms(pteam) or { n = 0, gun = 0, full = 0, empty = 0 }
  res.f = fac and arms(fac) or { n = 0, gun = 0, full = 0, empty = 0 }
  res.p_rearm = pteam and pteam.team and pteam.team.rearm and pteam.team.rearm.n or 0
  res.f_rearm = fac and fac.team and fac.team.rearm and fac.team.rearm.n or 0
  res.logs = 0
  for _, l in ipairs(M.world().logs) do if l:find("[FO-REARMEMENT]", 1, true) then res.logs = res.logs + 1 end end
  res.fkey = fac and fac.key or "?"
  return res
end

section("1. Règle allumée : les armes vidées sont rechargées au dépôt (votre équipe et une faction, 3 min)")
local on = run(true)
check(on.ok, "partie lancée : votre équipe et une faction")
check(on.sim_ok, "simulation sans erreur (" .. tostring(on.err) .. ")")
print(string.format("   votre équipe : %d chargeurs retirés, %d PNJ armés, %d à 10 ou plus, %d vides, %d rechargements", on.removed_p, on.p.gun,
  on.p.full, on.p.empty, on.p_rearm))
print(string.format("   faction %s : %d chargeurs retirés, %d PNJ armés, %d à 10 ou plus, %d vides, %d rechargements", on.fkey, on.removed_f, on.f.gun,
  on.f.full, on.f.empty, on.f_rearm))
check(on.removed_p > 0 and on.removed_f > 0, "les armes des deux équipes ont bien été vidées")
check(on.p_rearm >= 1 and on.p.full * 4 >= on.p.gun * 3, "votre équipe : au moins 3 PNJ armés sur 4 à 10 chargeurs ou plus (" ..
  on.p.full .. "/" .. on.p.gun .. ")")
check(on.f_rearm >= 1 and on.f.full * 4 >= on.f.gun * 3, "faction : au moins 3 PNJ armés sur 4 à 10 chargeurs ou plus (" ..
  on.f.full .. "/" .. on.f.gun .. ")")
check(on.logs >= 2, "journal [FO-REARMEMENT] écrit (" .. on.logs .. " lignes)")

section("2. Mutant de chaîne : règle éteinte (T.rearm_on = faux), même partie")
local off = run(false)
print(string.format("   votre équipe : %d à 10 ou plus sur %d, %d vides ; faction : %d sur %d, %d vides", off.p.full, off.p.gun, off.p.empty,
  off.f.full, off.f.gun, off.f.empty))
check(off.p_rearm == 0 and off.f_rearm == 0, "règle éteinte : aucun rechargement")
check(on.p.full > off.p.full and on.f.full > off.f.full, "la règle remet des armes chargées que la règle d'avant laisse vides")

print(string.format("[REARMEMENT-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
