--[[
  Lot JETONS (13/11/2026) : jetons de pose (Tokens.take_pose, script/team/tokens.lua), classe A6 (deux échelles pour une grandeur).
  La part d'une équipe dans Tokens.take vaut O.TICK_BUDGET / nombre d'équipes (100 à 4 équipes, 80 à 5), alors que le quota de pose est
  par pensée de PNJ (Build.REVIVE_PER_THINK pièces à Build.COST_REVIVE). À 5 équipes une pensée posait 1 pièce sur 6.
  Attendu : une pensée de pose entière passe, quel que soit le nombre d'équipes ; au plus une pensée pleine par équipe et par tick ;
  les unités de pose sont débitées de la part commune de l'équipe ; un poteau passe s'il ouvre la pensée ; refus comptés.
  Mutants (doivent être refusés) : pose renvoyée à la part commune, borne stricte, borne absente, pas de débit de la part commune,
  registre de pose non remis à zéro au tick suivant, registre commun à toutes les équipes, refus non compté, build.lua revenu à Tokens.take.

  Usage : lua5.2 tests/jetons_pose_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 print("OK     " .. msg) else fail_n = fail_n + 1 print("ECHEC : " .. msg) end
end

local function read(p) local h = io.open(p, "rb"); local s = h:read("*a"); h:close(); return (s:gsub("\r\n", "\n")) end
local TOKENS = read("script/team/tokens.lua")
local BUILD = read("script/team/build.lua")
local O = require("shared.team.org")

local KEYS = { "scarlet", "azure", "emerald", "amber", "violet", "ocre", "cyan" }

--- Charge le texte de tokens.lua avec `n_fac` factions vivantes, et votre équipe si `with_player`. Rend Tokens et la liste des équipes.
local function world(src, n_fac, with_player)
  local fac, alive, list = {}, {}, {}
  for i = 1, n_fac do
    fac[i] = { id = i, key = KEYS[i], team = { org = { stats = { token_refused = 0 } } } }
    alive[i] = i
    list[i] = fac[i]
  end
  if with_player then
    fac.player = { is_player = true, team = { org = { stats = { token_refused = 0 } } } }
    list[#list + 1] = fac.player
  end
  local state = { alive = function() return alive end, faction = function(id) return fac[id] end }
  local env = setmetatable({
    require = function(name)
      if name == "shared.team.org" then return O end
      if name == "script.faction.state" then return state end
      error("require inattendu : " .. tostring(name))
    end,
  }, { __index = _G })
  local chunk = assert(load(src, "=tokens.lua", "t", env))
  return chunk(), list
end

local function const(src, name)
  return tonumber(src:match("\nBuild%." .. name .. " = (%d+)"))
end

--- Rend le nombre de contrôles en échec (0 = tout passe).
local function suite(tok_src, build_src, quiet)
  local bad = 0
  local function c(cond, msg)
    if not cond then bad = bad + 1 end
    if not quiet then check(cond, msg) end
  end
  local PER, PIECE, POLE = const(build_src, "REVIVE_PER_THINK"), const(build_src, "COST_REVIVE"), const(build_src, "COST_REVIVE_POLE")
  c(PER and PIECE and POLE and PER > 1, "build.lua : REVIVE_PER_THINK, COST_REVIVE et COST_REVIVE_POLE lus")
  local THINK = PER * PIECE
  c(POLE <= THINK, "un poteau (" .. tostring(POLE) .. ") tient dans une pensée de pose (" .. tostring(THINK) .. ")")
  c(build_src:find("Tokens.take_pose(f, tick, cost, Build.REVIVE_PER_THINK * Build.COST_REVIVE)", 1, true) ~= nil,
    "build.lua : le ravivage d'une pièce prend ses jetons dans la part de pose (une pensée entière)")
  c(select(2, build_src:gsub("Tokens%.take%(f, tick, cost%)", "")) == 0, "build.lua : plus aucun ravivage payé sur la part commune")

  -- 1. une pensée entière passe pour chaque équipe au même tick, quel que soit le nombre d'équipes
  for _, cas in ipairs({ { 1, false }, { 4, false }, { 4, true }, { 7, true } }) do
    local T, list = world(tok_src, cas[1], cas[2])
    local worst = PER
    for _, f in ipairs(list) do
      local did = 0
      for _ = 1, PER do if T.take_pose(f, 1000, PIECE, THINK) then did = did + 1 end end
      if did < worst then worst = did end
    end
    c(worst == PER, string.format("%d équipe(s) : chaque équipe pose %d pièces sur %d dans la pensée (même tick)", #list, worst, PER))
  end

  -- 2. borne : une seule pensée pleine par équipe et par tick, refus compté, tick suivant rouvert
  do
    local T, list = world(tok_src, 4, true)
    local f = list[5]
    for _ = 1, PER do T.take_pose(f, 7, PIECE, THINK) end
    c(T.take_pose(f, 7, PIECE, THINK) == false, "la pièce de trop au même tick (deuxième PNJ de l'équipe) est refusée")
    c(f.team.org.stats.token_refused == 1, "le refus de pose est compté (token_refused)")
    c(T.take_pose(list[1], 7, PIECE, THINK) == true, "la pose d'une équipe ne prend rien à la pose d'une autre")
    c(T.take_pose(f, 8, PIECE, THINK) == true, "au tick suivant la pose est rouverte")
  end

  -- 3. poteau : passe s'il ouvre la pensée, attend la pensée suivante sinon
  do
    local T, list = world(tok_src, 4, true)
    local f = list[2]
    c(T.take_pose(f, 20, POLE, THINK) == true, "un poteau qui ouvre la pensée passe")
    c(T.take_pose(f, 20, POLE, THINK) == false or POLE * 2 <= THINK, "un second poteau au même tick attend")
    c(T.take_pose(f, 21, PIECE, THINK) == true and (T.take_pose(f, 21, POLE, THINK) == false or PIECE + POLE <= THINK),
      "un poteau après une pièce attend la pensée suivante")
    c(T.take_pose(f, 22, POLE, THINK) == true, "et passe à la pensée suivante")
  end

  -- 4. la pose débite la part commune de l'équipe (protection des UPS), sans être refusée par elle
  do
    local T, list = world(tok_src, 4, true)
    local f, g = list[1], list[3]
    local share = math.floor(O.TICK_BUDGET / #list)
    c(T.take(f, 30, share) == true, "la part commune entière est prise par l'équipe (" .. share .. ")")
    local did = 0
    for _ = 1, PER do if T.take_pose(f, 30, PIECE, THINK) then did = did + 1 end end
    c(did == PER, "part commune épuisée : la pensée de pose passe quand même (" .. did .. " sur " .. PER .. ")")
    c(T.take_pose(g, 31, PIECE, THINK) == true, "une pièce posée")
    c(T.take(g, 31, share - PIECE + 1) == false, "la pièce posée est débitée de la part commune (reste " .. (share - PIECE) .. ")")
    c(T.take(g, 31, share - PIECE) == true, "et le reste de la part commune passe")
    c(T.take_pose(list[2], 32, PIECE, THINK) == true and T.take(list[2], 32, O.TICK_BUDGET) == false,
      "après une pose, pas de grosse opération de l'équipe au même tick")
    c(T.take(list[4], 32, share) == true, "la pose d'une équipe ne débite pas la part commune d'une autre")
  end
  return bad
end

print("== règle réelle")
check(suite(TOKENS, BUILD) == 0, "suite complète sur tokens.lua et build.lua réels")
check(suite(TOKENS, BUILD, true) == 0, "deuxième passage : même résultat (déterministe)")

print("== mutants (doivent être refusés)")
local function mut(src, a, b)
  local i, j = src:find(a, 1, true)
  if not i then return nil end
  return src:sub(1, i - 1) .. b .. src:sub(j + 1)
end
local MUT = {
  { "pose renvoyée à la part commune (avant le lot)", mut(TOKENS, "  local used = ledger.pose[k] or 0\n", "  do return Tokens.take(f, tick, units) end\n  local used = ledger.pose[k] or 0\n"), BUILD },
  { "borne stricte (>=)", mut(TOKENS, "if used + units > per_think then", "if used + units >= per_think then"), BUILD },
  { "borne absente", mut(TOKENS, "if used + units > per_think then", "if false then"), BUILD },
  { "pas de débit de la part commune", mut(TOKENS, "  ledger.used[k] = (ledger.used[k] or 0) + units\n", ""), BUILD },
  { "registre de pose non remis à zéro", mut(TOKENS, "ledger.tick, ledger.used, ledger.grant, ledger.big, ledger.pose = tick, {}, nil, nil, {}", "ledger.tick, ledger.used, ledger.grant, ledger.big = tick, {}, nil, nil"), BUILD },
  { "registre de pose commun à toutes les équipes", mut(TOKENS, "  local used = ledger.pose[k] or 0\n", "  k = 1\n  local used = ledger.pose[k] or 0\n"), BUILD },
  { "refus de pose non compté", mut(TOKENS, "  if used + units > per_think then\n    if f.team and f.team.org then", "  if used + units > per_think then\n    if false then"), BUILD },
  { "build.lua revenu à Tokens.take", TOKENS, mut(BUILD, "Tokens.take_pose(f, tick, cost, Build.REVIVE_PER_THINK * Build.COST_REVIVE)", "Tokens.take(f, tick, cost)") },
  { "build.lua : part de pose d'une seule pièce", TOKENS, mut(BUILD, "Tokens.take_pose(f, tick, cost, Build.REVIVE_PER_THINK * Build.COST_REVIVE)", "Tokens.take_pose(f, tick, cost, Build.COST_REVIVE)") },
}
for _, m in ipairs(MUT) do
  if not (m[2] and m[3]) then
    check(false, "mutant non fabriqué : " .. m[1])
  else
    local ok, n = pcall(suite, m[2], m[3], true)
    check((not ok) or n > 0, "mutant refusé : " .. m[1] .. (ok and (" (" .. n .. " contrôle(s) en échec)") or " (erreur)"))
  end
end

print(string.format("\n[JETONS-POSE] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
