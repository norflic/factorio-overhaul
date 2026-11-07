--[[
  Lot VIDEO-L13 « garde fermée par défaut », branchement au runtime (critère G4 de fo-logs/2026-11-07_VIDEO-INTEG/CRITERES.md), au
  moteur simulé (tests/mock_engine.lua) : la liste des machines du relevé retirée à une faction, la décision est refusée
  (script/ai3/capitalisation.lua, decide_start, Ca.absent_input) au lieu de décider sur « rien de posé ».
    §1 liste retirée à la faction 1 pendant 4 min : au moins 2 lignes « decision refusee : entree absente : machines », aucune
       décision de plus après la première, aucun instantané cs.dj ; la faction 2 (témoin) décide et n'écrit aucune de ces lignes ;
    §2 mutant (Ca.absent_input rend toujours nil) : §1 échoue (la faction décide sur une liste absente).
  Ce n'est pas une preuve en jeu. Usage : lua5.2 tests/capi_garde_test.lua   (depuis la racine du mod ; environ 1 min)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[CAPI-GARDE] ECHEC : " .. msg) end
end
local function say(s) print("[CAPI-GARDE] " .. s) end
local function W() return M.world() end
local MIN = 3600

-- Gisements larges, comme tests/capi_moteur_test.lua.
local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end

local function count(key, text)
  local n = 0
  for _, l in ipairs(W().logs) do
    if l:find("[FO-CAPI] " .. key .. " : " .. text, 1, true) then n = n + 1 end
  end
  return n
end

--- Partie de 2 min, puis 4 min avec la liste des machines du relevé retirée à la faction 1 (après chaque tick).
local function run(mutant)
  M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
  M.load_mod()
  local Ca = package.loaded["shared.ai3.capitalisation"]
  local orig = Ca.absent_input
  if mutant then Ca.absent_input = function() return nil end end
  M.dispatch(W().on_init)
  M.command("fo-war", "start 2 30 30 320")
  local out = { ok = true }
  local ok, err = pcall(M.run_ticks, 2 * MIN)
  local f1, f2 = global.fo.war.factions[1], global.fo.war.factions[2]
  local c1 = f1 and f1.team and f1.team.capi
  local c2 = f2 and f2.team and f2.team.capi
  out.k1, out.k2 = f1 and f1.key or "?", f2 and f2.key or "?"
  out.d2_0 = c2 and c2.decisions or 0
  out.d1_0 = c1 and c1.decisions or 0
  local refus = "decision refusee : entree absente : machines"
  local needle = "[FO-CAPI] " .. out.k1 .. " : " .. refus
  local seen = #W().logs
  out.dj_after = false
  for _ = 1, 4 * MIN do
    if not ok then break end
    ok, err = pcall(M.run_ticks, 1)
    c1 = f1.team and f1.team.capi
    if c1 and c1.scan then c1.scan.machines = nil end
    if out.d1_at == nil then
      local logs = W().logs
      for i = seen + 1, #logs do
        if logs[i]:find(needle, 1, true) then out.d1_at = c1.decisions break end
      end
      seen = #logs
    end
    if out.d1_at ~= nil and c1 and c1.dj ~= nil then out.dj_after = true end
  end
  out.ok, out.err = ok, err
  out.r1, out.r2 = count(out.k1, refus), count(out.k2, "decision refusee : entree absente")
  out.d1 = c1 and c1.decisions or 0
  out.d2 = c2 and c2.decisions or 0
  Ca.absent_input = orig
  return out
end

local function verdict(o, quiet)
  local ok = {
    o.ok,
    o.r1 >= 2,
    o.d1_at ~= nil and o.d1 == o.d1_at,
    not o.dj_after,
    o.d2 - o.d2_0 >= 2 and o.r2 == 0,
  }
  local msgs = {
    "§1 partie sans erreur (" .. tostring(o.err) .. ")",
    string.format("§1 faction %s : au moins 2 refus « entree absente : machines » en 4 min (%d)", o.k1, o.r1),
    string.format("§1 faction %s : aucune decision de plus apres le premier refus (%s puis %d)", o.k1, tostring(o.d1_at), o.d1),
    string.format("§1 faction %s : aucun instantane cs.dj apres le premier refus", o.k1),
    string.format("§1 temoin %s : decide (%d -> %d) et n'ecrit aucun refus (%d)", o.k2, o.d2_0, o.d2, o.r2),
  }
  local all = true
  for i = 1, #ok do
    if not quiet then check(ok[i], msgs[i]) end
    all = all and ok[i]
  end
  return all
end

local a = run(false)
say(string.format("§1 faction %s : %d decision(s) avant, %d refus ; temoin %s : %d -> %d decisions", a.k1, a.d1_0, a.r1, a.k2, a.d2_0, a.d2))
verdict(a, false)

local b = run(true)
say(string.format("§2 mutant : faction %s : %d refus, decisions %d -> %d (ok %s)", b.k1, b.r1, b.d1_0, b.d1, tostring(b.ok)))
check(not verdict(b, true), "§2 mutant refuse : Ca.absent_input rend toujours nil")

print(string.format("[CAPI-GARDE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
