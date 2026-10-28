--[[
  Lot VEILLE : la reconnaissance régulière sur le MOTEUR SIMULÉ (tests/mock_engine.lua). Usage : lua5.2 tests/veille_moteur_test.lua
  Vérifie, sur 40 min de guerre à 4 factions : le vivier est fabriqué après l'armée de départ, il n'entre ni dans la garnison ni dans
  f.soldiers_count, des éclaireurs partent à intervalle avec un rayon croissant, aucun soldat du vivier n'est pris par une attaque,
  les refus sont comptés par raison, les lignes [FO-VEILLE] sont écrites, deux parties de même graine donnent les mêmes lignes
  (déterminisme). Rien de la visée des attaques n'est touché : le test de lignes [FO-STRAT] attaque est celui de war_test.
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local V = require("shared.faction.veille")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for ri, r in ipairs({ 40, 64, 88, 150 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1], amount = 10000 * ((ri + di) % 5 + 1) }
      end
    end
  end
  return out
end

local function logs(pattern)
  local out = {}
  for _, l in ipairs(M.world().logs) do if l:find(pattern, 1, true) then out[#out + 1] = l end end
  return out
end

local function play(seed)
  M.new_game({ seed = seed, patches = patches(), p_busy = 0.02, p_nopath = 0.02, p_lost = 0.005 })
  M.command("fo-war", "start 4 100 10 320")
  M.run_ticks(40 * 3600)
  return global.fo.war
end

section("Vivier et départs à intervalle (4 factions, 40 min)")
local war = play(777)
local trained, sent, arrived = 0, 0, 0
local any_ready_in_garrison = false
for _, f in ipairs(war.factions) do
  local vs = f.veille
  check(vs ~= nil, f.key .. " : état de la veille tenu")
  if vs then
    trained, sent, arrived = trained + vs.trained, sent + vs.sent, arrived + vs.arrived
    local scouts, plain = 0, 0
    for _, s in pairs(f.soldiers) do
      if s.scout then scouts = scouts + 1 else plain = plain + 1 end
    end
    check(f.soldiers_count == plain, f.key .. " : f.soldiers_count ne compte pas le vivier (" .. f.soldiers_count .. " = " .. plain .. ")")
    check(scouts <= V.VIVIER, f.key .. " : au plus " .. V.VIVIER .. " éclaireur du vivier vivant (" .. scouts .. ")")
    local near = require("script.faction.military").garrison_near(f)
    check(near <= plain, f.key .. " : la garnison ne compte pas le vivier (" .. near .. " <= " .. plain .. ")")
    -- Les départs ne dépassent pas la cadence : un par intervalle de base au plus, plus un par rayon élargi sans but.
    check(vs.sent <= 40 / 10 + 1, f.key .. " : au plus un départ par intervalle de 10 min (" .. vs.sent .. ")")
    local n = 0
    for _, c in pairs(vs.refus) do n = n + c end
    check(vs.trained > 0 or n > 0, f.key .. " : le vivier est fabriqué ou le refus compté (" .. vs.trained .. " fabriqués, " .. n .. " refus)")
  end
end
check(trained >= 1, "au moins un éclaireur du vivier fabriqué en 40 min (" .. trained .. ")")
check(#logs("[FO-VEILLE] vivier tick") == trained, "une ligne [FO-VEILLE] vivier par éclaireur fabriqué")
check(#logs("[FO-VEILLE] depart tick") == sent, "une ligne [FO-VEILLE] depart par départ (" .. sent .. ")")
check(#logs("[FO-VEILLE] bilan tick") >= 4, "bilans de 10 min écrits")
print(string.format("  fabriqués %d, partis %d, arrivés %d ; lignes depart %d", trained, sent, arrived, #logs("[FO-VEILLE] depart tick")))

section("Aucun soldat du vivier dans une attaque")
local bad = false
for _, f in ipairs(war.factions) do
  for _, g in pairs(f.groups or {}) do
    if g.state == "attack" then
      for _, id in ipairs(g.ids or {}) do
        local s = f.soldiers[id]
        if s and s.scout then bad = true end
      end
    end
  end
end
check(not bad, "aucun éclaireur du vivier dans un groupe d'attaque")

section("Rayon croissant")
do
  local radii = {}
  for _, l in ipairs(logs("[FO-VEILLE] depart tick")) do
    local fk, r = l:match("tick %d+ (%w+) : .- rayon (%d+)")
    if fk then radii[fk] = radii[fk] or {}; table.insert(radii[fk], tonumber(r)) end
  end
  local ok = true
  for fk, list in pairs(radii) do
    for i = 2, #list do if list[i] < list[i - 1] then ok = false end end
    check(list[1] == V.R0, fk .. " : premier rayon " .. V.R0 .. " (" .. tostring(list[1]) .. ")")
  end
  check(ok, "le rayon ne diminue jamais d'un départ au suivant")
end

section("Déterminisme : même graine, mêmes lignes")
do
  local a = logs("[FO-VEILLE]")
  play(777)
  local b = logs("[FO-VEILLE]")
  local same = #a == #b
  for i = 1, math.min(#a, #b) do if a[i] ~= b[i] then same = false end end
  check(same, "lignes [FO-VEILLE] identiques (" .. #a .. " et " .. #b .. ")")
end

section("Sérialisable")
check(pcall(M.serialize, global), "global sérialisable (état de la veille)")

print(string.format("[VEILLE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
