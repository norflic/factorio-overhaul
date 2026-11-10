--[[
  Lot CC-PLAN-FIGE (F512, 10/11/2026) : le gros jeton du tick (Tokens.take, script/team/tokens.lua : une opération plus chère que la part
  d'une équipe, UNE seule pour tout le mod, au premier demandeur) et l'ordre de service des équipes de la passe du plan directeur
  (build.lua, on_nth_tick(Build.PULSE)).
  Défaut (classe B3, ordre d'évaluation dans le tick) : les équipes étaient servies dans un ordre FIXE (factions, puis votre équipe). Partie
  0.6.89 du DC (4 factions) et sonde fo-logs/2026-11-10_CC-PLAN-FIGE-SONDE2-4271945338 (graine 4271945338, réglages du DC) : de 30 à 43 min,
  Écarlate, dont 4 lignes de rapatriement se planifiaient par tranches (une tranche = un plan = le gros jeton), prend 611 à 677 gros jetons
  sur 720 passes par minute ; les plans de votre équipe sont refusés 555 à 4 092 fois par minute « gros jeton déjà pris par scarlet », et
  ses projets s'entassent en « plan » à 0 essai (15, 16, 17, 18, 19, 20 à 43 min ; bande 51 du fer de 29,7 à 82 min chez le DC).
  Contrôles : la règle pure O.serve_order (shared/team/org.lua), la passe de build.lua qui la suit (source), et une simulation de la
  passe avec le VRAI Tokens.take (5 équipes, 720 passes : chaque équipe qui veut un plan à chaque passe en obtient 144).
  Mutants (doivent être refusés) : ordre fixe, rotation sur tick % n (repliée par la période : 5 équipes à 5 ticks = toujours la même),
  ordre non permutation, indices à partir de 0, règle non exportée par Tokens, passe de build.lua revenue à l'ordre fixe.
  Usage : lua5.2 tests/jetons_tour_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 print("OK     " .. msg) else fail_n = fail_n + 1 print("ECHEC : " .. msg) end
end

-- État des factions simulé (lu par Tokens.take pour le partage) : 4 factions vivantes, puis votre équipe
local FAC = {}
local KEYS = { "scarlet", "azure", "emerald", "amber" }
for i, k in ipairs(KEYS) do FAC[i] = { id = i, key = k, team = { org = { stats = { token_refused = 0 } } } } end
FAC.player = { key = nil, is_player = true, team = { org = { stats = { token_refused = 0 } } } }
package.loaded["script.faction.state"] = {
  alive = function() return { 1, 2, 3, 4 } end,
  faction = function(id) return FAC[id] end,
}
local O = require("shared.team.org")
local Tokens = require("script.team.tokens")

local PULSE, PASSES, PLAN = 5, 720, 200 -- build.lua : Build.PULSE, une minute de passes, Build.COST_PLAN

local function read(p) local h = io.open(p, "rb"); local s = h:read("*a"); h:close(); return (s:gsub("\r\n", "\n")) end
local BUILD = read("script/team/build.lua")

--- Une minute de passes : à chaque passe, les équipes sont servies dans l'ordre `order_fn` ; chaque équipe de `wants` demande un plan.
--- Rend les gros jetons obtenus par clé d'équipe.
local function minute(order_fn, wants, t0)
  local list = { FAC[1], FAC[2], FAC[3], FAC[4], FAC.player } -- (build.lua, teams() : factions vivantes, puis votre équipe)
  local got = {}
  for p = 0, PASSES - 1 do
    local tick = (t0 or 0) + p * PULSE
    for _, i in ipairs(order_fn(#list, tick, PULSE)) do
      local f = list[i]
      local k = f.is_player and "player" or f.key
      if wants[k] and Tokens.take(f, tick, PLAN) then got[k] = (got[k] or 0) + 1 end
    end
  end
  return got
end

local function is_perm(t, n)
  if #t ~= n then return false end
  local seen = {}
  for _, i in ipairs(t) do
    if type(i) ~= "number" or i < 1 or i > n or i % 1 ~= 0 or seen[i] then return false end
    seen[i] = true
  end
  return true
end

--- La suite de contrôles, sur une règle d'ordre et une source de build.lua ; rend le nombre d'échecs (sans rien imprimer si quiet).
local function suite(order_fn, exported, src, quiet)
  local fails = 0
  local function c(cond, msg)
    if not cond then fails = fails + 1 end
    if not quiet then check(cond, msg) end
  end
  -- 1. règle pure : une permutation, le premier servi tourne à chaque passe, même quand le nombre d'équipes divise la période
  local perms, firsts = true, {}
  for p = 0, 4 do
    local o = order_fn(5, p * PULSE, PULSE)
    perms = perms and is_perm(o, 5)
    firsts[#firsts + 1] = o[1] or -1
  end
  c(perms, "5 équipes : chaque ordre est une permutation de 1..5")
  table.sort(firsts)
  c(table.concat(firsts, ",") == "1,2,3,4,5", "5 équipes à 5 ticks : sur 5 passes, chaque équipe est servie la première une fois (" .. table.concat(firsts, ",") .. ")")
  local f3 = {}
  for p = 0, 2 do local o = order_fn(3, 1000 + p * PULSE, PULSE); f3[#f3 + 1] = o[1] or -1 end
  table.sort(f3)
  c(table.concat(f3, ",") == "1,2,3", "3 équipes : chaque équipe servie la première une fois sur 3 passes")
  local o1 = order_fn(1, 35, PULSE)
  c(#o1 == 1 and o1[1] == 1 and #order_fn(0, 35, PULSE) == 0, "une équipe : servie seule ; aucune équipe : ordre vide")
  -- 2. Tokens exporte la règle que la passe lit
  c(exported == order_fn, "Tokens.serve_order est la règle d'ordre (shared/team/org.lua)")
  -- 3. la passe du plan directeur la suit (build.lua)
  c(src:find("for _, i in ipairs(Tokens.serve_order(#list, e.tick, Build.PULSE)) do", 1, true) ~= nil
    and src:find("Events.on_nth_tick(Build.PULSE, function(e)\n  for _, f in ipairs(teams()) do", 1, true) == nil,
    "build.lua : la passe sert les équipes dans l'ordre de Tokens.serve_order (et non plus dans l'ordre fixe de teams())")
  -- 4. simulation, le vrai Tokens.take : l'état de la sonde (Écarlate planifie par tranches à chaque passe, votre équipe veut un plan)
  local g = minute(order_fn, { scarlet = true, player = true })
  c((g.player or 0) >= PASSES / 5, string.format("Écarlate en tranches à chaque passe : votre équipe obtient %d gros jetons sur %d passes (au moins 1/5)", g.player or 0, PASSES))
  c((g.scarlet or 0) >= PASSES / 5, string.format("Écarlate garde au moins 1/5 des passes (%d)", g.scarlet or 0))
  -- toutes les équipes veulent un plan à chaque passe : partage égal
  local all = minute(order_fn, { scarlet = true, azure = true, emerald = true, amber = true, player = true }, 7)
  local eq = true
  for _, k in ipairs({ "scarlet", "azure", "emerald", "amber", "player" }) do eq = eq and (all[k] or 0) == PASSES / 5 end
  c(eq, string.format("5 équipes qui veulent un plan à chaque passe : %d/%d/%d/%d/%d gros jetons (144 chacune)", all.scarlet or 0, all.azure or 0,
    all.emerald or 0, all.amber or 0, all.player or 0))
  -- un seul gros jeton par passe pour tout le mod (la garde IA3-e reste entière)
  local tot = 0
  for _, v in pairs(all) do tot = tot + v end
  c(tot == PASSES, "un seul gros jeton par passe pour tout le mod (" .. tot .. " sur " .. PASSES .. ")")
  return fails
end

print("== règle réelle")
check(suite(O.serve_order, Tokens.serve_order, BUILD) == 0, "suite complète sur la règle réelle et la passe réelle")
check(suite(O.serve_order, Tokens.serve_order, BUILD, true) == 0, "deuxième passage : même résultat (déterministe)")

print("== mutants (doivent être refusés)")
local function fixed(n) local o = {} for i = 1, n do o[i] = i end return o end
local function by_tick(n, tick)
  local o = {}
  if n <= 0 then return o end
  local s = tick % n
  for i = 0, n - 1 do o[#o + 1] = (s + i) % n + 1 end
  return o
end
local function not_perm(n, tick, period)
  local o = O.serve_order(n, tick, period)
  if n > 1 then o[#o] = o[1] end
  return o
end
local function zero_based(n, tick, period)
  local o = {}
  if n <= 0 then return o end
  local s = math.floor(tick / period) % n
  for i = 0, n - 1 do o[#o + 1] = (s + i) % n end
  return o
end
local OLD = BUILD:gsub("  local list = teams%(%)\n  for _, i in ipairs%(Tokens%.serve_order%(#list, e%.tick, Build%.PULSE%)%) do\n    local f = list%[i%]\n",
  "  for _, f in ipairs(teams()) do\n")
check(OLD ~= BUILD, "le mutant de la passe (ordre fixe de teams()) a bien été fabriqué")
local MUT = {
  { "ordre fixe (factions, puis votre équipe)", fixed, fixed, BUILD },
  { "rotation sur tick % n (repliée par la période)", by_tick, by_tick, BUILD },
  { "ordre qui n'est pas une permutation", not_perm, not_perm, BUILD },
  { "indices à partir de 0", zero_based, zero_based, BUILD },
  { "règle non exportée par Tokens", O.serve_order, nil, BUILD },
  { "passe de build.lua revenue à l'ordre fixe", O.serve_order, O.serve_order, OLD },
}
for _, m in ipairs(MUT) do
  local ok, n = pcall(suite, m[2], m[3], m[4], true)
  check((not ok) or n > 0, "mutant refusé : " .. m[1] .. (ok and (" (" .. n .. " contrôle(s) en échec)") or " (erreur)"))
end

print(string.format("\n[JETONS-TOUR] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
