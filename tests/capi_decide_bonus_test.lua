--[[
  Lot CAPI-DECIDE, mutant « D.bonus d'une autre équipe laissé en place », jugé HORS de la partie simulée (7/11, décision du lead) :
  dans la partie de tests/capi_decide_test.lua, aucune machine ni foreuse, aucun chemin ne relit le bonus après la première unité
  (mesuré : 42 lectures des débits à bonus, 0 avec le bonus écrit par le banc), et la comparaison des sorties ne voyait pas le mutant.
  Ici, test PUR de la décision découpée (Ca.decide_begin, puis un Ca.decide_step par tranche), sur une scène avec des foreuses et un
  gisement ouvert : le bonus de minage est relu après la première unité (options d'extraction, couverture du compte rendu).
    §1 la décision découpée sans rien changer = Ca.decide d'un seul tenant (référence) ;
    §2 précondition : le bonus est LU après la première unité (Ca.drill_per_min appelé pendant les tranches) ;
    §3 le bonus d'une autre force écrit entre deux tranches, REMIS depuis l'instantané avant chaque tranche (ce que fait
       script/ai3/capitalisation.lua, decide_slice) : décision identique à la référence ;
    §4 mutant « laissé en place » (aucune remise) : la décision diffère de la référence (mutant vu) ; de même pour le seul bonus de
       minage. Le seul bonus de laboratoire n'a pas d'effet ici (information, voir §4) : la remise est contrôlée au moteur simulé.
  La remise elle-même (la ligne de decide_slice) est contrôlée au moteur simulé, tour par tour : tests/capi_decide_test.lua, C4.
  Usage : lua5.2 tests/capi_decide_bonus_test.lua   (depuis la racine du mod). Fichier de TEST : il nomme des objets vanilla.
]]

package.path = "./?.lua;" .. package.path
local F = require("tests.iag_fixture")
local Ca = require("shared.ai3.capitalisation")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    print("[CAPI-DECIDE-BONUS] ECHEC : " .. msg)
  end
end
local function say(s) print("[CAPI-DECIDE-BONUS] " .. s) end

local function sk(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end
local function ser(v)
  if type(v) == "table" then
    local parts = {}
    for _, k in ipairs(sk(v)) do
      if type(v[k]) ~= "function" then parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif type(v) == "number" then return string.format("%.17g", v) end
  return tostring(v)
end

-- Relevé vanilla (vitesses, aires, puissances) ; recettes des technologies fermées au départ.
local SP = { ["stone-furnace"] = 1, ["assembling-machine-1"] = 0.5, ["assembling-machine-2"] = 0.75, ["burner-mining-drill"] = 0.25,
  ["electric-mining-drill"] = 0.5, ["lab"] = 1 }
local AR = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 5 }
local KW = { ["stone-furnace"] = 90, ["burner-mining-drill"] = 150, ["electric-mining-drill"] = 90, ["assembling-machine-1"] = 75,
  ["assembling-machine-2"] = 150, ["lab"] = 60 }
local EXEC = { ["stone-furnace"] = true, ["burner-mining-drill"] = true, ["electric-mining-drill"] = true,
  ["assembling-machine-1"] = true, ["assembling-machine-2"] = true }
local function data()
  local d = F.dump()
  for _, t in ipairs(sk(d.techs)) do
    for _, r in ipairs(d.techs[t].unlocks or {}) do if d.recipes[r] then d.recipes[r].enabled = false end end
  end
  for _, e in ipairs(d.entities) do
    if SP[e.name] then e.speed = SP[e.name] end
    e.mining_area = AR[e.name]
    e.size = e.name == "burner-mining-drill" and 2 or 3
    e.energy_kw = KW[e.name]
  end
  for _, r in ipairs(d.resources) do r.mining_time = 1 end
  return Ca.data(d, { exec = EXEC, exec_roles = { main = true, labo = true } })
end

-- Foreuses électriques sur un gisement de fer OUVERT (minerai en manque : 12 fours pour une foreuse), engrenages voulus, laboratoires
-- et une recherche en file (le bonus de laboratoire est lu par la décision).
local function scene()
  return { data = data(), state = { techs = { automation = true } }, stock = { ["electronic-circuit"] = 1000 }, workers = 30, idle = 10,
    can_grow = true, traits = {}, weights = {}, open = {},
    deposits = { { id = "fer", resource = "iron-ore", tiles = 600, amount = 1e6, open = true, dist = 60 },
      { id = "ch", resource = "coal", tiles = 300, amount = 5e5, open = true, dist = 50 } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 1, deposit = "fer" },
      { entity = "electric-mining-drill", resource = "coal", n = 1, deposit = "ch" } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 12, where = "qg" } },
    labs = { { entity = "lab", n = 2 } },
    research = { queue = { { tech = "logistics", left = 200, time = 15, packs = { { "automation-science-pack", 1 } } } }, rate = 120 },
    flows = { ["iron-ore"] = { made = 30 }, ["iron-plate"] = { made = 30 }, ["coal"] = { made = 30 } },
    sinks = { { item = "iron-gear-wheel", rate = 60 } } }
end

--- Décision découpée : decide_begin, puis une tranche (un decide_step) à la fois. Avant chaque tranche, `write` écrit le bonus d'une
--- AUTRE force dans D.bonus (comme la décision d'une autre équipe), puis `restore` remet celui de l'instantané (decide_slice).
local function sliced(write, restore)
  local inp = scene()
  local D = inp.data
  local snap = { mining = D.bonus.mining or 0, lab = D.bonus.lab or 0 }
  local J = Ca.decide_begin(inp, {})
  local steps, reads = 0, 0
  local d0 = Ca.drill_per_min
  Ca.drill_per_min = function(...) reads = reads + 1 return d0(...) end
  local ok, err = pcall(function()
    repeat
      steps = steps + 1
      if write then for k, v in pairs(write) do D.bonus[k] = v end end
      if restore then D.bonus.mining, D.bonus.lab = snap.mining, snap.lab end
    until Ca.decide_step(J)
  end)
  Ca.drill_per_min = d0
  D.bonus.mining, D.bonus.lab = snap.mining, snap.lab
  if not ok then error(err, 0) end
  return J.res, steps, reads
end
local function keys(res)
  local t = {}
  for _, o in ipairs(res.orders) do t[#t + 1] = o.key .. " x" .. tostring(o.n) end
  return table.concat(t, ", ")
end

-- §1 Référence.
local ref, steps = sliced(nil, false)
local whole = Ca.decide(scene(), {})
check(ser(ref) == ser(whole), "§1 decision decoupee sans changement = Ca.decide d'un seul tenant")
check(steps >= 2 and #ref.orders >= 1, "§1 scene : decision en " .. steps .. " tranche(s), ordres : " .. keys(ref))

-- §2 Précondition : le bonus de minage est relu après la première unité.
local _, _, reads = sliced({ mining = 9, lab = 9 }, true)
check(reads >= 1, "§2 precondition : Ca.drill_per_min appele pendant les tranches (" .. reads .. " fois)")

-- §3 Bonus d'une autre force écrit entre deux tranches, remis avant chaque tranche : décision identique.
local kept = sliced({ mining = 9, lab = 9 }, true)
check(ser(kept) == ser(ref), "§3 bonus remis depuis l'instantane a chaque tranche : decision identique a la reference")

-- §4 Mutants : bonus laissé en place (aucune remise).
local m_all = sliced({ mining = 9, lab = 9 }, false)
check(ser(m_all) ~= ser(ref), "§4 mutant « D.bonus d'une autre equipe laisse en place » vu : la decision differe (" .. keys(m_all)
  .. " contre " .. keys(ref) .. ")")
local m_mine = sliced({ mining = 9 }, false)
check(ser(m_mine) ~= ser(ref), "§4 mutant, bonus de MINAGE seul laisse en place : vu (" .. keys(m_mine) .. ")")
-- Bonus de LABORATOIRE seul laissé en place : MESURÉ invisible ici (7/11). Après la première unité, la décision ne le relit que par
-- Ca.apply d'un ordre « labos » (add_labs : plan.lab_cap) ; le débit d'un laboratoire est pris au début (ctx.lab_rate, prepare) et
-- cette scène ne décide aucun laboratoire. La remise du bonus de laboratoire reste contrôlée tour par tour au moteur simulé
-- (tests/capi_decide_test.lua, C4 : un tour qui voit 9 en minage OU en laboratoire est compté).
local m_lab = sliced({ lab = 9 }, false)
say("information : bonus de laboratoire seul laisse en place " .. (ser(m_lab) == ser(ref) and "SANS effet sur cette decision"
  or "change la decision") .. " (" .. keys(m_lab) .. ")")

say(string.format("reference : %s ; mutant : %s", keys(ref), keys(m_all)))
print(string.format("[CAPI-DECIDE-BONUS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
