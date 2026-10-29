--[[
  Lot VEILLE (essai 2) : la reconnaissance régulière sur le MOTEUR SIMULÉ (tests/mock_engine.lua). Usage : lua5.2 tests/veille_moteur_test.lua
  Vérifie, sur 45 min de guerre à 4 factions : des ouvriers libres partent en veille à intervalle (jamais plus vite que l'intervalle
  minimal), le rayon ne diminue jamais, aucun soldat n'est touché (aucun éclaireur militaire), les refus sont comptés par raison, les
  lignes [FO-VEILLE] sont écrites, la veille éteinte (Veille.on = false) ne fait partir personne, deux parties de même graine donnent les
  mêmes lignes (déterminisme), l'état est sérialisable.
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

local function play(seed, on)
  M.new_game({ seed = seed, patches = patches(), p_busy = 0.02, p_nopath = 0.02, p_lost = 0.005 })
  -- Les modules sont rechargés à chaque partie : l'option passe par l'interface distante des bancs.
  check(remote.call("factorio-overhaul", "veille_options", { on = on }).on == on, "option de bancs veille_options")
  M.command("fo-war", "start 4 100 10 320")
  M.run_ticks(45 * 3600)
  return global.fo.war
end

section("Ouvriers libres en veille (4 factions, 45 min)")
local war = play(777, true)
local sent = 0
local all = logs("[FO-VEILLE] depart tick")
for _, f in ipairs(war.factions) do
  local vs = f.veille
  check(vs ~= nil, f.key .. " : état de la veille tenu")
  if vs then
    sent = sent + vs.sent
    -- Pas plus de départs que l'intervalle minimal (curiosité maximale, 5 min) ne le permet, plus le premier.
    check(vs.sent <= math.floor(45 * 3600 / (V.INTERVAL / 2)) + 1, f.key .. " : départs plafonnés par l'intervalle (" .. vs.sent .. ")")
    for _, s in pairs(f.soldiers) do check(not s.scout, f.key .. " : aucun soldat éclaireur") end
  end
end
do
  local Board = require("script.team.board")
  for _, f in ipairs(war.factions) do
    local open = Board.count(f)
    check(Board.takeable(f) <= open, f.key .. " : tâches prenables <= tâches libres (" .. Board.takeable(f) .. " <= " .. open .. ")")
  end
end
check(sent == #all, "une ligne [FO-VEILLE] depart par départ (" .. sent .. " et " .. #all .. ")")
check(sent >= 1, "au moins un ouvrier libre est parti en veille en 45 min (" .. sent .. ")")
check(#logs("[FO-VEILLE] bilan tick") >= 4, "bilans de 10 min écrits")
print(string.format("  départs %d ; fins %d ; buts %d ; refus : %s", sent, #logs("[FO-VEILLE] fin tick"), #logs("[FO-VEILLE] but tick"),
  (function()
    local acc = {}
    for _, f in ipairs(war.factions) do for r, n in pairs(f.veille.refus) do acc[r] = (acc[r] or 0) + n end end
    local keys = {}
    for r in pairs(acc) do keys[#keys + 1] = r end
    table.sort(keys)
    local out = {}
    for _, r in ipairs(keys) do out[#out + 1] = r .. "=" .. acc[r] end
    return table.concat(out, " ")
  end)()))

section("Intervalle et rayon")
do
  local by = {}
  for _, l in ipairs(all) do
    local t, fk, r = l:match("depart tick (%d+) (%w+) : .-rayon (%d+)")
    if t then by[fk] = by[fk] or {}; table.insert(by[fk], { tick = tonumber(t), r = tonumber(r) }) end
  end
  for fk, list in pairs(by) do
    check(list[1].r == V.R0, fk .. " : premier rayon " .. V.R0 .. " (" .. tostring(list[1].r) .. ")")
    for i = 2, #list do
      check(list[i].tick - list[i - 1].tick >= V.INTERVAL / 2, fk .. " : au moins l'intervalle minimal entre deux départs")
      check(list[i].r >= list[i - 1].r, fk .. " : le rayon ne diminue jamais")
    end
  end
end

section("Veille éteinte : personne ne part, le relevé de secteurs continue")
do
  local w2 = play(777, false)
  local s2 = 0
  for _, f in ipairs(w2.factions) do s2 = s2 + (f.veille and f.veille.sent or 0) end
  check(s2 == 0, "aucun départ de veille quand elle est éteinte (" .. s2 .. ")")
  check(#logs("[FO-VEILLE] bilan tick") >= 4 and #logs("veille eteinte") >= 4, "bilans publiés, veille éteinte")
end

section("Déterminisme : même graine, mêmes lignes")
do
  play(777, true)
  local a = logs("[FO-VEILLE]")
  play(777, true)
  local b = logs("[FO-VEILLE]")
  local same = #a == #b
  for i = 1, math.min(#a, #b) do if a[i] ~= b[i] then same = false end end
  check(same, "lignes [FO-VEILLE] identiques (" .. #a .. " et " .. #b .. ")")
end

section("Sérialisable")
check(pcall(M.serialize, global), "global sérialisable (état de la veille)")

print(string.format("[VEILLE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
