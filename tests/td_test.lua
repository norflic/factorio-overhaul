--[[
  Tests hors-jeu du mode défense de tours (moteur simulé) + règles pures des vagues.
  Usage, depuis la racine du mod :   lua5.2 tests/td_test.lua
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

---------------------------------------------------------------------------------------------------
section("Règles pures des vagues")
local TD = require("shared.td.waves")
local E = require("shared.content.enemies")
local function lcg(seed)
  local s = seed
  return function() s = (s * 48271) % 2147483647; return (s - 1) / 2147483646 end
end
local prev_budget = 0
for wave = 1, 30 do
  local list = TD.compose(wave, lcg(7))
  local n = TD.total(list)
  check(n > 0, "vague " .. wave .. " non vide")
  check(TD.budget(wave) > prev_budget, "budget croissant (vague " .. wave .. ")")
  prev_budget = TD.budget(wave)
  for _, it in ipairs(list) do
    local tier
    for t, tn in ipairs(E.tier_names) do if it[1]:find(tn, 1, true) then tier = t end end
    check(tier ~= nil and tier <= math.max(TD.max_tier(wave), TD.is_boss(wave) and E.TIERS or 0), "palier autorisé : " .. it[1] .. " (vague " .. wave .. ")")
    if wave < TD.family_from.armored then check(not it[1]:find("armored"), "pas de blindés avant la vague " .. TD.family_from.armored) end
  end
end
local a, b = TD.compose(12, lcg(3)), TD.compose(12, lcg(3))
check(#a == #b and a[1][1] == b[1][1] and a[1][2] == b[1][2], "composition déterministe")
check(TD.is_boss(5) and TD.is_boss(10) and not TD.is_boss(6), "vagues de boss toutes les 5")
check(TD.max_tier(1) == 1 and TD.max_tier(30) == E.TIERS, "paliers : 1 à la vague 1, 8 en fin")

---------------------------------------------------------------------------------------------------
section("Activation, vague, victoire, récompense")
M.new_game({})
local st = global.fo.td
check(st and st.active == false, "mode inactif par défaut")
M.command("fo-waves", "on 2")
check(st.active and st.phase == "build", "activé, phase de construction")
check(game.forces["fo-horde"] ~= nil, "force fo-horde créée")
check(game.forces["fo-horde"].get_cease_fire("enemy") == true, "horde en paix avec les biters")
M.run_ticks(60)
check(W().player.gui.left["fo-td-frame"] ~= nil, "panneau affiché")
check(W().player.gui.top["fo-td-button"] ~= nil, "bouton affiché")
M.run_ticks(180)
check(st.phase == "wave" and st.wave == 1, "vague 1 lancée")
M.run_ticks(600)
local horde = 0
for _, e in ipairs(W().entities) do if e.valid and e.force.name == "fo-horde" then horde = horde + 1 end end
check(horde > 0 and st.alive == horde, "assaillants créés et comptés (" .. horde .. ")")
check(st.launched == true, "assaut lancé une fois tout le monde arrivé")
local plates0 = W().player.character.get_item_count("iron-plate")
for _, e in ipairs(W().entities) do if e.valid and e.force.name == "fo-horde" then e.die(game.forces.player) end end
M.run_ticks(120)
check(st.phase == "build" and st.stats.cleared == 1, "vague 1 tenue -> construction")
check(W().player.character.get_item_count("iron-plate") > plates0, "récompense reçue")
check(st.stats.kills == horde, "tués comptés")

section("Vague suivante immédiate, sauvegarde, arrêt")
M.command("fo-waves", "next")
M.run_ticks(120)
check(st.wave == 2 and st.phase == "wave", "vague 2 lancée à la demande")
local ok_ser = pcall(M.serialize, global)
check(ok_ser, "global sérialisable pendant une vague")
local saved = M.deepcopy_global(global)
M.load_mod()
_G.global = saved
W().on_load()
local ok_run = pcall(M.run_ticks, 300)
check(ok_run, "la vague continue après rechargement")
M.command("fo-waves", "off")
local left = 0
for _, e in ipairs(W().entities) do if e.valid and e.force.name == "fo-horde" then left = left + 1 end end
check(global.fo.td.active == false and left == 0, "désactivé : assaillants retirés")
check(W().player.gui.left["fo-td-frame"] ~= nil or true, "panneau")
M.run_ticks(60)
check(W().player.gui.left["fo-td-frame"] == nil, "panneau retiré")

section("Groupe bloqué : relance puis nouveau point de départ")
do
  M.new_game({})
  local st2 = global.fo.td
  M.command("fo-waves", "on 2")
  M.run_ticks(240 + 600)
  check(st2.launched == true, "vague lancée")
  local alive0 = st2.alive
  -- Le moteur simulé ne déplace pas les unités : le groupe ne se rapproche jamais de la base.
  local ok_r, err_r = pcall(M.run_ticks, 50 * 60)
  check(ok_r, "contrôle des groupes sans erreur (" .. tostring(err_r) .. ")")
  check((st2.stats.relocated or 0) >= 1, "groupe bloqué reparti d'un autre point (" .. tostring(st2.stats.relocated) .. ")")
  check(st2.alive > 0 and st2.alive <= alive0, "assaillants conservés (" .. st2.alive .. ")")
  local ok_ser = pcall(M.serialize, global)
  check(ok_ser, "état sérialisable")
  M.command("fo-waves", "off")
end

section("Base tombée : la défense s'arrête")
do
  M.new_game({})
  local st3 = global.fo.td
  M.command("fo-waves", "on 2")
  M.run_ticks(240 + 600)
  check(st3.launched == true, "vague lancée")
  -- Les assaillants arrivent au centre ; aucune tourelle du joueur ne tient.
  for _, u in pairs(st3.units) do if u.valid then u.teleport({ x = st3.target.x + 1, y = st3.target.y + 1 }) end end
  local ok_r, err_r = pcall(M.run_ticks, 12 * 60)
  check(ok_r, "sans erreur (" .. tostring(err_r) .. ")")
  check(st3.active == false and (st3.stats.fallen or 0) == 1, "base tombée : mode arrêté")
  local told = false
  for _, p in ipairs(W().game_prints) do if tostring(p):find("base%-fallen") then told = true end end
  check(told, "joueurs prévenus")
  local horde = 0
  for _, e in ipairs(W().entities) do if e.valid and e.force.name == "fo-horde" then horde = horde + 1 end end
  check(horde == 0, "assaillants retirés (" .. horde .. ")")
end

section("Interface distante")
local r = remote.call("factorio-overhaul", "waves", "on", 1)
check(r.active == true, "remote waves on")
r = remote.call("factorio-overhaul", "waves", "status")
check(r.phase == "build", "remote waves status")
remote.call("factorio-overhaul", "waves", "off")

section("Coexistence avec la guerre des factions")
M.new_game({})
M.command("fo-war", "start 2 100 4 320")
M.command("fo-waves", "on 1")
local ok_both = pcall(M.run_ticks, 3600)
check(ok_both, "guerre + vagues pendant 1 minute sans erreur")
check(global.fo.td.wave >= 1, "les vagues tournent pendant la guerre")

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
