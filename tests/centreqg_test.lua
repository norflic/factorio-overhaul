--[[
  Lot PD-CENTREQG (D20) : le QG d'une faction est son centre de commandement (script/faction/centre_qg.lua), moteur simulé.
  Usage, depuis la racine du mod :   lua5.2 tests/centreqg_test.lua

  Vérifie : (1) fondation : chaque faction a un centre de niveau 1 lié (Levels.cc de sa force), indestructible et non
  minable, le corps du QG (fo-faction-hq, coffre) inchangé, une ligne [FO-CENTRE-QG] par pose ; (2) étiquette : l'âge est
  affiché ; (3) amélioration par le chemin de CAPITAL (remote fo-centre-qg.upgrade) : niveau 2, payé au coffre du QG, le
  nouveau centre est relié et reverrouillé ; refus faute de ressources : l'ancien reste relié et verrouillé ; (4) veille :
  un lien perdu (drapeaux remis par un autre module) est refait ; (5) migration 0.6.18 : QG sans centre -> centre de
  niveau 1 posé, coffre du QG intact (mêmes objets, même entité) ; QG avec un centre déjà posé par CAPITAL -> relié sans
  pose ; (6) élimination : le centre part avec le QG ; (7) votre équipe n'est jamais touchée ; (8) déterminisme ;
  (9) mutants : sans le verrou, sans la chute à l'élimination, sans la pose à la migration -> au moins un contrôle échoue.
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

local function count_logs(pat)
  local n = 0
  for _, l in ipairs(W().logs) do if l:find(pat, 1, true) then n = n + 1 end end
  return n
end

local function entities(name, force)
  local out = {}
  for _, e in ipairs(W().entities) do
    if e.valid and e.name == name and (not force or e.force.name == force) then out[#out + 1] = e end
  end
  return out
end

local function contents(inv)
  local keys, out = {}, {}
  for k in pairs(inv._items) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do out[#out + 1] = k .. "=" .. inv._items[k] end
  return table.concat(out, ",")
end

-- Prototypes des centres (comme tests/centre_test.lua) : emprise de la règle des niveaux (4 x 4 aux niveaux 1 à 3), boîtes.
local function box(x0, y0, x1, y1) return { left_top = { x = x0, y = y0 }, right_bottom = { x = x1, y = y1 } } end
local function start()
  M.new_world({ seed = 3 })
  local w = M.world()
  local Lc = require("shared.levels.config")
  for n = 1, Lc.by_key.command.max do
    local name = Lc.name(Lc.by_key.command, n)
    local h = Lc.footprint(Lc.by_key.command, n) / 2
    rawset(w.prototypes, name, { type = "container", max_health = 3000, collision_box = box(-h + 0.3, -h + 0.3, h - 0.3, h - 0.3),
      selection_box = box(-h, -h, h, h), collision_mask = w.prototypes["gun-turret"].collision_mask,
      items_to_place_this = { { name = name, count = 1 } } })
  end
  M.load_mod()
  M.dispatch(w.on_init)
  M.command("fo-war", "start 2 10 4 320")
end

local Levels, CQ, L
local function mods()
  Levels = require("script.levels.levels")
  CQ = require("script.faction.centre_qg")
  L = require("shared.levels.config")
end

---------------------------------------------------------------------------------------------------
section("1. Fondation : centre de niveau 1 lié au QG")
start()
mods()
local war = global.fo.war
check(war.active and #war.factions == 2, "guerre lancée, 2 factions")
for _, f in ipairs(war.factions) do
  local force = game.forces[f.force]
  local cc = Levels.cc(force)
  check(cc ~= nil and cc.name == L.name(L.by_key.command, 1), f.key .. " : centre de commandement de niveau 1 enregistré pour la force")
  check(cc ~= nil and f.centre_qg == cc.unit_number, f.key .. " : le QG est relié à ce centre (f.centre_qg)")
  check(cc ~= nil and cc.destructible == false and cc.minable == false, f.key .. " : centre lié indestructible et non minable")
  check(CQ.level(f) == 1 and Levels.cc_level(force) == 1, f.key .. " : le QG porte l'époque 1")
  check(f.hq and f.hq.valid and f.hq.name == "fo-faction-hq", f.key .. " : le corps du QG reste l'épave fo-faction-hq (coffre, 25 000 PV)")
  check(#entities(L.name(L.by_key.command, 1), f.force) == 1, f.key .. " : un seul centre pour la force")
end
check(count_logs("[FO-CENTRE-QG]") >= 2, "journal [FO-CENTRE-QG] écrit à la fondation")

---------------------------------------------------------------------------------------------------
section("2. Étiquette du QG : l'âge affiché")
M.run_ticks(600)
local f1 = war.factions[1]
local txt = W().renders[f1.label] and M.ls_to_string(W().renders[f1.label].text) or ""
check(txt:find("fo-centreqg.label-age", 1, true) ~= nil, "l'étiquette du QG porte l'âge du centre (" .. txt .. ")")

---------------------------------------------------------------------------------------------------
section("3. Amélioration par le chemin de CAPITAL")
local Stock = require("script.team.stock")
local api = W().remote["fo-centre-qg"]
check(api ~= nil and api.status ~= nil and api.upgrade ~= nil, "interface distante fo-centre-qg (status, upgrade)")
-- Refus faute de ressources : rien ne change, l'ancien reste relié et verrouillé.
local hq_inv = f1.hq.get_inventory(defines.inventory.chest)
for k in pairs(hq_inv._items) do hq_inv._items[k] = nil end
local old = Levels.cc(game.forces[f1.force])
local ok, why = api.upgrade(f1.key)
check(not ok, "refus sans ressources (" .. tostring(why) .. ")")
local cc = Levels.cc(game.forces[f1.force])
check(cc == old and cc.destructible == false and cc.minable == false and f1.centre_qg == cc.unit_number,
  "après un refus : l'ancien centre reste relié et verrouillé")
-- Condition Q16 (comme pour le joueur) : les bâtiments à niveaux de la faction (tourelles du QG) bloqueraient le passage
-- 1 -> 2 ; ils sont retirés pour ce cas (la condition elle-même est contrôlée par levels_test).
local blockers = 0
for _, e in ipairs(W().entities) do
  local fam = e.valid and e.force.name == f1.force and L.parse(e.name)
  if fam and fam.key ~= "command" then e.destroy(); blockers = blockers + 1 end
end
check(blockers >= 0, "bâtiments à niveaux retirés : " .. blockers)
-- Payé au coffre du QG.
for _, c in ipairs(L.cost(L.by_key.command, 2)) do Stock.insert(f1, c[1], c[2]) end
ok, why = api.upgrade(f1.key)
cc = Levels.cc(game.forces[f1.force])
check(ok == true, "amélioration du centre lié faite (" .. tostring(why) .. ")")
check(cc ~= nil and cc ~= old and cc.name == L.name(L.by_key.command, 2), "nouveau centre de niveau 2")
check(cc ~= nil and f1.centre_qg == cc.unit_number and cc.destructible == false and cc.minable == false,
  "le nouveau centre est relié au QG et reverrouillé")
check(CQ.level(f1) == 2, "le QG porte l'époque 2")
local left = 0
for _, c in ipairs(L.cost(L.by_key.command, 2)) do left = left + Stock.count(f1, c[1]) end
check(left == 0, "coût prélevé au coffre du QG (reste " .. left .. ")")
local st = api.status()
check(#st == 2 and st[1].level == 2 and st[1].linked == st[1].centre, "status : niveau 2 et lien lus à distance")

---------------------------------------------------------------------------------------------------
section("4. Veille : lien perdu refait")
cc.destructible = true
f1.centre_qg = nil
M.run_ticks(600)
check(f1.centre_qg == cc.unit_number and cc.destructible == false, "la veille des étiquettes relie de nouveau le centre")

---------------------------------------------------------------------------------------------------
section("5. Migration d'une sauvegarde 0.6.18")
local f2 = war.factions[2]
-- 0.6.18 : aucune faction n'a de centre lié ; f2 sans centre (fo-war-capital éteint), f1 avec le centre posé par CAPITAL.
local c2 = Levels.cc(game.forces[f2.force])
c2.destroy()
f2.centre_qg = nil
f1.centre_qg = nil
cc.destructible, cc.minable = true, true
local hq2, inv2 = f2.hq, contents(f2.hq.get_inventory(defines.inventory.chest))
local logs0 = count_logs("cause migration")
local okm, err = pcall(M.dispatch, W().on_config, { mod_changes = { ["factorio-overhaul"] = { old_version = "0.6.18", new_version = "0.6.19" } } })
check(okm, "on_configuration_changed sans erreur (" .. tostring(err) .. ")")
local n2 = Levels.cc(game.forces[f2.force])
check(n2 ~= nil and n2 ~= c2 and n2.name == L.name(L.by_key.command, 1) and f2.centre_qg == n2.unit_number,
  "QG sans centre : centre de niveau 1 posé et relié")
check(f2.hq == hq2 and f2.hq.valid and contents(f2.hq.get_inventory(defines.inventory.chest)) == inv2,
  "corps du QG et coffre intacts (même entité, mêmes objets)")
check(Levels.cc(game.forces[f1.force]) == cc and f1.centre_qg == cc.unit_number and cc.destructible == false,
  "QG avec un centre posé par CAPITAL : relié sans nouvelle pose (niveau gardé : " .. CQ.level(f1) .. ")")
check(CQ.level(f1) == 2, "le niveau du centre de CAPITAL est gardé")
check(count_logs("cause migration") - logs0 >= 2, "journal [FO-CENTRE-QG] de la migration")

---------------------------------------------------------------------------------------------------
section("6. Élimination : le centre part avec le QG")
local ccf2 = Levels.cc(game.forces[f2.force])
f2.hq.die(game.forces[f1.force])
M.run_ticks(2)
check(f2.eliminated == true, "faction 2 éliminée à la perte de son QG")
check(not ccf2.valid and Levels.cc(game.forces[f2.force]) == nil, "son centre lié est retiré avec le QG")
check(f2.centre_qg == nil, "lien effacé")
M.run_ticks(600)
check(Levels.cc(game.forces[f2.force]) == nil, "la veille ne repose rien pour une faction éliminée")

---------------------------------------------------------------------------------------------------
section("7. Votre équipe : jamais touchée")
local fake = { is_player = true, key = "player", force = "player", hq = f1.hq, hq_pos = f1.hq_pos }
local e, w = CQ.ensure(fake, "test")
check(e == nil and w == "hors" and fake.centre_qg == nil, "CQ.ensure ignore votre équipe")
check(CQ.level(fake) == 0 and CQ.centre(fake) == nil, "votre équipe : ni niveau ni centre lus par ce module")

---------------------------------------------------------------------------------------------------
section("8. Déterminisme")
local function run()
  start()
  M.run_ticks(1200)
  return M.serialize(global)
end
check(run() == run(), "deux parties identiques donnent le même état global")

---------------------------------------------------------------------------------------------------
section("9. Mutants")
local function mutant(name, patch)
  start()
  mods()
  local saved = {}
  for k, v in pairs(patch) do saved[k] = CQ[k]; CQ[k] = v end
  local bad = false
  local wr = global.fo.war
  -- Fondation déjà faite avant le patch : on rejoue les cas 1, 5 et 6 en abrégé.
  local f = wr.factions[1]
  local ok1 = pcall(function()
    local c = Levels.cc(game.forces[f.force])
    c.destructible, c.minable = true, true
    f.centre_qg = nil
    CQ.ensure(f, "mutant")
    if c.destructible ~= false then bad = true end
    local g = wr.factions[2]
    local cg = Levels.cc(game.forces[g.force])
    cg.destroy()
    g.centre_qg = nil
    M.dispatch(W().on_config, { mod_changes = {} })
    if Levels.cc(game.forces[g.force]) == nil then bad = true end
    local cf = Levels.cc(game.forces[f.force])
    f.hq.die(game.forces[g.force])
    M.run_ticks(2)
    if cf and cf.valid then bad = true end
  end)
  for k, v in pairs(saved) do CQ[k] = v end
  if name == "temoin" then
    check(ok1 and not bad, "témoin sans mutation : rien de détecté")
  else
    check(bad or not ok1, "mutant « " .. name .. " » détecté")
  end
end
mutant("temoin", {})
mutant("sans verrou", { link = function(f, e) f.centre_qg = e.unit_number end })
mutant("sans chute", { drop = function() return false end })
mutant("sans pose", { ensure = function(f) local c = CQ.centre(f); if c then f.centre_qg = c.unit_number; c.destructible = false end return c end })

print(string.format("[CENTREQG] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
