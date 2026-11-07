--[[
  Lot COLLECTE : règle pure shared/team/collecte.lua (coffres de sortie du champ jamais vidés, partie du DC en 0.6.58).
  Usage : lua5.2 tests/collecte_test.lua ; les mutants sont rejoués sur le module rechargé.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local M = require("shared.ai3.marche")

local passes, failures = 0, 0
local current
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC" .. (current and (" [mutant " .. current .. "]") or "") .. " : " .. msg) end
  end
end
local function same(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

local function checks(C)
  -- §1 manque : fer libre sous le besoin ET équipe sous son effectif
  check(C.shortfall({ free = 0, reserve = 400, missing = 0, n = 2, floor = 5 }) == 400, "fer 0, besoin 400, équipe 2 sur 5 : 400 plaques manquent")
  check(C.shortfall({ free = 0, reserve = 400, missing = 150, n = 2, floor = 5 }) == 550, "le manque de l'objectif s'ajoute à la réserve")
  check(C.shortfall({ free = 400, reserve = 400, missing = 0, n = 2, floor = 5 }) == 0, "stock qui couvre : la règle dort")
  check(C.shortfall({ free = 9000, reserve = 400, missing = 150, n = 2, floor = 5 }) == 0, "stock largement au-dessus : 0, jamais négatif")
  check(C.shortfall({ free = 0, reserve = 400, missing = 0, n = 5, floor = 5 }) == 0, "équipe au complet : la règle dort")
  check(C.shortfall({ free = 0, reserve = 400, missing = 0, n = 8, floor = 5 }) == 0, "équipe au-dessus de l'effectif : la règle dort")
  check(C.shortfall({ free = 100, reserve = 400, missing = 0, n = 4, floor = 5 }) == 300, "manque = besoin - libre")
  check(C.shortfall({ free = 0, reserve = 0, missing = 80, n = 1, floor = 5 }) == 80, "sans réserve : le manque de l'objectif seul")

  -- §2 sûreté
  check(C.safe({}, 100000) == true, "coffre sans danger : sûr")
  check(C.safe({ enemy = true }, 100000) == false, "nid ou ver proche : pas sûr")
  check(C.safe({ loss = true }, 100000) == false, "perte récente alentour : pas sûr")
  check(C.safe({ lethal_tick = 100000 - C.LETHAL_TICKS + 1 }, 100000) == false, "avant-poste meurtrier : pas sûr")
  check(C.safe({ lethal_tick = 100000 - C.LETHAL_TICKS }, 100000) == true, "meurtrier depuis 10 min pile : sûr")
  check(C.refusal({ enemy = true, loss = true }, 0) == "ennemi" and C.refusal({ loss = true }, 0) == "perte"
    and C.refusal({ lethal_tick = 99999 }, 100000) == "meurtrier" and C.refusal({}, 0) == nil, "cause du refus : ennemi, perte, meurtrier, aucune")
  check(C.LETHAL_TICKS == T.lethal_ticks, "la copie de T.lethal_ticks suit les données")

  -- §3 choix : le plus proche d'abord, jamais un coffre dangereux, borné, arrêt quand le manque est couvert
  local cands = {
    { key = "c:far", d2 = 90000, n = 700, at = 200 },
    { key = "c:near", d2 = 400, n = 300, at = 200 },
    { key = "c:mid", d2 = 10000, n = 500, at = 200 },
    { key = "c:low", d2 = 100, n = 150, at = 200 },           -- sous le seuil : pas de tâche
  }
  check(same(C.pick(cands, 1000, 0), { "c:near", "c:mid" }), "le plus proche d'abord, borné à C.MAX_TASKS, coffre sous le seuil écarté")
  check(same(C.pick(cands, 250, 0), { "c:near" }), "manque couvert par le premier coffre : un seul")
  check(same(C.pick(cands, 0, 0), {}), "manque nul : aucun")
  check(same(C.pick({}, 500, 0), {}), "aucun candidat : aucun")
  local dang = {
    { key = "a:enemy", d2 = 100, n = 800, at = 200, enemy = true },
    { key = "b:loss", d2 = 200, n = 800, at = 200, loss = true },
    { key = "c:lethal", d2 = 300, n = 800, at = 200, lethal_tick = 99000 },
    { key = "d:ok", d2 = 90000, n = 400, at = 200 },
  }
  check(same(C.pick(dang, 400, 100000), { "d:ok" }), "les coffres proches mais dangereux sont écartés, le sûr lointain est pris")
  local tie = { { key = "z", d2 = 500, n = 300, at = 200 }, { key = "a", d2 = 500, n = 300, at = 200 } }
  check(same(C.pick(tie, 600, 0), { "a", "z" }), "à distance égale, la clé croissante (ordre déterministe)")
  check(#C.pick({ { key = "1", d2 = 1, n = 300, at = 200 }, { key = "2", d2 = 2, n = 300, at = 200 }, { key = "3", d2 = 3, n = 300, at = 200 } }, 5000, 0) == 2,
    "jamais plus de C.MAX_TASKS (2) coffres à la fois")
  check(same(C.pick({ { key = "x", d2 = 1, n = 0, at = 0 } }, 100, 0), {}), "un coffre vide n'est jamais choisi, même à seuil 0")

  -- §3 bis : états servis et voyage à vide (cartes de l'IA, maillons 2 et 3)
  check(C.collects_outs("fini", 3) and C.collects_outs("chantier", 1), "bandes finies et en chantier : coffres vidés")
  check(C.collects_outs("reserve", 8) and C.collects_outs("refuse", 2), "bandes en réserve ou refusées : coffres vidés aussi")
  check(not C.collects_outs("reserve", 0) and not C.collects_outs(nil, 3), "sans coffre de sortie, ou sans état : rien")
  check(C.outcome(600, 0) == "fail", "coffre plein de plaques, rien entré dans le sac : voyage à vide = échec")
  check(C.outcome(600, 120) == "done" and C.outcome(0, 0) == "done", "voyage utile ou coffre déjà vidé : done")
  check(C.outcome(5, -1) == "fail" and C.outcome(nil, nil) == "done", "bornes : retour négatif = échec, valeurs absentes = done")

  -- §3 ter : ce que le stock écarte reste au coffre, fer et charbon d'abord
  local skip = function(it) return it == "stone" or it == "copper-plate" end
  local T = require("shared.team.config")
  local fe, cl = T.outposts.iron.product, T.outposts.coal.product
  check(same(C.take_list({ "copper-plate", "stone", fe, "wood" }, skip), { fe, "wood" }), "pierre et cuivre écartés restent au coffre")
  check(same(C.take_list({ "stone", "wood", fe, cl }, nil), { cl, fe, "stone", "wood" }) or same(C.take_list({ "stone", "wood", fe, cl }, nil), { fe, cl, "stone", "wood" }),
    "sans prédicat : tout est pris, le fer et le charbon d'abord")
  check(C.take_list({ "stone", fe }, nil)[1] == fe, "le fer passe avant la pierre même si la pierre est triée avant")
  check(same(C.take_list({ "stone", "copper-plate" }, skip), {}), "tout écarté : rien à prendre")
  check(same(C.take_list(nil, nil), {}), "liste absente : rien")

  -- §4 priorité : devant le minage urgent du fer à la place de marché, derrière la garde du QG
  local npc = { id = 1, pos = { x = 0, y = 0 } }
  local home = { x = 0, y = 0 }
  local mine = M.score(npc, { kind = "mine", prio = 90, resource = "iron-ore" }, 0, home, M.NEED_SHORT)
  local flat = M.score(npc, { kind = "carry", prio = 55 }, 0, home, 1)
  local urgent = M.score(npc, { kind = "carry", prio = C.PRIO, critical = C.CRITICAL or nil, no_rush = true }, 0, home, 1)
  local mine45 = M.score(npc, { kind = "mine", prio = 45, resource = "iron-ore" }, 0, home, M.NEED_SHORT)
  check(flat < mine45, "constat d'avant la règle : la collecte à 55 perd contre un minage de fer à 45 quand le facteur de besoin (x 1,5) joue")
  check(urgent > mine, "avec la règle : la collecte en urgence passe devant le minage urgent du fer (90 x 1,5)")
  check(C.PRIO < 96, "elle reste sous la défense d'urgence du QG (96)")
end

local function fresh()
  package.loaded["shared.team.collecte"] = nil
  return require("shared.team.collecte")
end

checks(fresh())

local function copy(c, over)
  local o = { key = c.key, d2 = c.d2, n = c.n, at = c.at, enemy = c.enemy, loss = c.loss, lethal_tick = c.lethal_tick }
  for k, v in pairs(over or {}) do o[k] = v end
  return o
end
local function wrap(C, f)
  local o = C.pick
  C.pick = function(cands, short, now)
    local c2 = {}
    for i, c in ipairs(cands) do c2[i] = f(c) end
    return o(c2, short, now)
  end
end

local MUTANTS = {
  { "short-ignore-floor", function(C) C.shortfall = function(s) local d = (s.reserve or 0) + (s.missing or 0) - (s.free or 0); return d > 0 and d or 0 end end },
  { "short-ignore-reserve", function(C) C.shortfall = function(s) if (s.n or 0) >= (s.floor or 0) then return 0 end local d = (s.missing or 0) - (s.free or 0); return d > 0 and d or 0 end end },
  { "short-ignore-missing", function(C) C.shortfall = function(s) if (s.n or 0) >= (s.floor or 0) then return 0 end local d = (s.reserve or 0) - (s.free or 0); return d > 0 and d or 0 end end },
  { "short-negative", function(C) C.shortfall = function(s) if (s.n or 0) >= (s.floor or 0) then return 0 end return (s.reserve or 0) + (s.missing or 0) - (s.free or 0) end end },
  { "short-floor-le", function(C) C.shortfall = function(s) if (s.n or 0) > (s.floor or 0) then return 0 end local d = (s.reserve or 0) + (s.missing or 0) - (s.free or 0); return d > 0 and d or 0 end end },
  { "safe-enemy-ignored", function(C) C.safe = function(c, now) if c.loss then return false end return not (c.lethal_tick ~= nil and now - c.lethal_tick < C.LETHAL_TICKS) end end },
  { "safe-loss-ignored", function(C) C.safe = function(c, now) if c.enemy then return false end return not (c.lethal_tick ~= nil and now - c.lethal_tick < C.LETHAL_TICKS) end end },
  { "refusal-wrong-cause", function(C) C.refusal = function(c, now) if c.enemy or c.loss then return "perte" end if c.lethal_tick ~= nil and now - c.lethal_tick < C.LETHAL_TICKS then return "meurtrier" end return nil end end },
  { "safe-lethal-ignored", function(C) C.safe = function(c) return not (c.enemy or c.loss) end end },
  { "safe-lethal-forever", function(C) C.safe = function(c) return not (c.enemy or c.loss or c.lethal_tick ~= nil) end end },
  { "pick-farthest-first", function(C) wrap(C, function(c) return copy(c, { d2 = -c.d2 }) end) end },
  { "pick-unsafe-allowed", function(C) wrap(C, function(c) return { key = c.key, d2 = c.d2, n = c.n, at = c.at } end) end },
  { "pick-below-threshold", function(C) wrap(C, function(c) return copy(c, { at = 0 }) end) end },
  { "pick-unbounded", function(C) C.MAX_TASKS = 99 end },
  { "pick-no-stop-when-covered", function(C) local o = C.pick; C.pick = function(cands, short, now) return o(cands, (short or 0) * 1000000, now) end end },
  { "pick-when-no-shortfall", function(C) local o = C.pick; C.pick = function(cands, short, now) return o(cands, 1000000, now) end end },
  { "pick-key-desc", function(C) wrap(C, function(c) return copy(c, { d2 = 0 }) end); local o = C.pick; C.pick = function(cands, short, now)
      local r = o(cands, short, now); table.sort(r, function(a, b) return a > b end); return r end end },
  { "serves-only-built", function(C) C.collects_outs = function(s, n) return (n or 0) > 0 and (s == "fini" or s == "chantier") end end },
  { "serves-no-outs", function(C) C.collects_outs = function(s) return s ~= nil end end },
  { "outcome-always-done", function(C) C.outcome = function() return "done" end end },
  { "outcome-ignores-before", function(C) C.outcome = function(b, g) if (g or 0) <= 0 then return "fail" end return "done" end end },
  { "outcome-partial-fails", function(C) C.outcome = function(b, g) if (b or 0) > 0 and (g or 0) < b then return "fail" end return "done" end end },
  { "take-ignores-skip", function(C) local o = C.take_list; C.take_list = function(items) return o(items, nil) end end },
  { "take-vital-last", function(C) C.take_list = function(items, skipped) local r = {} for _, it in ipairs(items or {}) do if not (skipped and skipped(it)) then r[#r + 1] = it end end table.sort(r, function(a, b) return (C.VITAL[a] and 1 or 0) < (C.VITAL[b] and 1 or 0) end) return r end end },
  { "take-no-order", function(C) C.take_list = function(items, skipped) local r = {} for _, it in ipairs(items or {}) do if not (skipped and skipped(it)) then r[#r + 1] = it end end return r end end },
  { "prio-too-low", function(C) C.PRIO = 55 end },
  { "prio-not-critical", function(C) C.CRITICAL = false end },
  { "prio-above-guard", function(C) C.PRIO = 99 end },
}

local killed = 0
for _, m in ipairs(MUTANTS) do
  local before, pbefore = failures, passes
  local C = fresh()
  m[2](C)
  current, quiet = m[1], true
  checks(C)
  current, quiet = nil, false
  local dead = failures > before
  if dead then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. m[1]) end
  failures, passes = before, pbefore
end
if killed < #MUTANTS then failures = failures + (#MUTANTS - killed) end
print(string.format("[COLLECTE] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
