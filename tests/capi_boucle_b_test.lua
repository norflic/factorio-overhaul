--[[
  Étape 5a de VIDEO-INTEG, choix (a) du lead (7/11 vers 17 h 05) : la BOUCLE B du courant, de bout en bout, avec les VRAIES fonctions du
  runtime (chargées par le moteur simulé, tests/mock_engine.lua : Capi.power_input, Sante.committed, Sante.growth) et la vraie règle
  (shared/ai3/capitalisation.lua, données vanilla comme tests/ai3_capitalisation_test.lua). Le moteur simulé n'a ni centrale ni plan
  directeur pour les factions : l'équipe est une table posée ici (f.build.grow = relevé de PA.watch, f.build.order et projects).
    §1 pas d'étouffement : 12 assembleurs électriques posés (1 800 kW NOMINAUX) pour une centrale de 1 800 kW qui n'en produit que 900 :
       vue de la porte (mesure + 0,6 × chantiers) → des foreuses électriques sont décidées ; mutant « used_kw nominal »
       (Capi.MUT.nominal) → aucune, refus de courant (l'étouffement que la vue de la porte évite) ;
    §2 boucle B : centrale à 1 200 kW produits sur 1 800 : la décision veut plus de foreuses que la marge n'en porte, des kW sont
       retenus (res.kw.blocked) ; versés à la croissance (f.team.capi.kw_blocked, comme decide_finish), ils font demander une centrale
       de plus AVANT la saturation (Sante.growth puis C.growth) ; sans eux (témoin), rien : 1 200 kW < 70 % de 1 800 ;
    §3 mutant « kW retenus ignorés par la centrale » (S.capi_kw rend 0) : §2 échoue.
  Usage : lua5.2 tests/capi_boucle_b_test.lua   (depuis la racine du mod ; quelques secondes)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[CAPI-BOUCLE-B] ECHEC : " .. msg) end
end
local function say(s) print("[CAPI-BOUCLE-B] " .. s) end

M.new_world({ difficulty = "peaceful", ia3e = true, capi = true })
M.load_mod()
local Ca = package.loaded["shared.ai3.capitalisation"]
local Capi = package.loaded["script.ai3.capitalisation"]
local Sante = package.loaded["script.team.sante_centrale"]
local S = package.loaded["shared.team.sante_centrale"]
local C = package.loaded["shared.team.centrale"] or require("shared.team.centrale")
local F = require("tests.iag_fixture")
assert(Ca and Capi and Sante and S and C, "modules du runtime absents")

-- Données vanilla (copie de tests/ai3_capitalisation_test.lua : vitesses, aires, puissances de data/base 1.1.91).
local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end
local V_SPEED = { ["stone-furnace"] = 1, ["steel-furnace"] = 2, ["electric-furnace"] = 2, ["assembling-machine-1"] = 0.5,
  ["assembling-machine-2"] = 0.75, ["assembling-machine-3"] = 1.25, ["burner-mining-drill"] = 0.25,
  ["electric-mining-drill"] = 0.5, ["pumpjack"] = 1, ["lab"] = 1, ["chemical-plant"] = 1, ["oil-refinery"] = 1, ["centrifuge"] = 1 }
local V_AREA = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 5, ["pumpjack"] = 1 }
local V_SIZE = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 3, ["stone-furnace"] = 2, ["steel-furnace"] = 2 }
local V_KW = { ["stone-furnace"] = 90, ["steel-furnace"] = 90, ["electric-furnace"] = 180, ["burner-mining-drill"] = 150,
  ["electric-mining-drill"] = 90, ["assembling-machine-1"] = 75, ["assembling-machine-2"] = 150,
  ["assembling-machine-3"] = 375, ["lab"] = 60, ["boiler"] = 1800 }
local function vdata()
  local d = F.dump()
  for _, e in ipairs(d.entities) do
    if V_SPEED[e.name] then e.speed = V_SPEED[e.name] end
    e.mining_area = V_AREA[e.name]
    e.size = V_SIZE[e.name] or 3
    e.energy_kw = V_KW[e.name]
  end
  for _, t in ipairs(sorted_keys(d.techs)) do
    for _, r in ipairs(d.techs[t].unlocks) do if d.recipes[r] then d.recipes[r].enabled = false end end
  end
  for _, r in ipairs(d.resources) do r.mining_time = (r.entity == "uranium-ore") and 2 or 1 end
  local exec = { ["stone-furnace"] = true, ["steel-furnace"] = true, ["burner-mining-drill"] = true, ["electric-mining-drill"] = true,
    ["assembling-machine-1"] = true, ["assembling-machine-2"] = true }
  return Ca.data(d, { exec = exec, exec_roles = { main = true, labo = true } })
end
local D = vdata()

-- Gisement de fer ouvert (2 foreuses électriques posées) et un site connu ; puits de fer de 1 000/min.
local function scene(power, machines)
  local ms = { { entity = "stone-furnace", recipe = "iron-plate", n = 4, where = "qg" } }
  for _, m in ipairs(machines or {}) do ms[#ms + 1] = m end
  return { data = D, state = { techs = { automation = true } }, stock = { ["electronic-circuit"] = 3000 },
    flows = { ["iron-ore"] = { made = 60 }, ["iron-plate"] = { made = 60 } }, machines = ms,
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 2, deposit = "d1" } }, labs = {},
    deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60 },
      { id = "s2", resource = "iron-ore", tiles = 270, amount = 1e6, dist = 150 } },
    open = {}, sinks = { { item = "iron-plate", rate = 1000 } }, workers = 30, idle = 10, can_grow = true, traits = {}, weights = {},
    power = power }
end
local function elec_drills(res)
  local n = 0
  for _, o in ipairs(res.orders) do
    if (o.kind == "couvrir" or o.kind == "ouvrir") and o.entity == "electric-mining-drill" then n = n + (o.n or 0) end
  end
  return n
end
local function courant_refus(res)
  local n = 0
  for _, r in ipairs(res.refus) do if r.why and r.why:find("courant insuffisant", 1, true) then n = n + 1 end end
  return n
end
-- L'équipe : relevé de PA.watch (J/tick) et plan directeur sans chantier.
local function team(cap_j, power_j)
  return { key = "banc", build = { order = {}, projects = {}, grow = { capacity = cap_j, power = power_j } }, team = { capi = {} } }
end

-- §1 pas d'étouffement : 12 assembleurs 2 posés (12 × 150 = 1 800 kW nominaux), centrale de 1 800 kW à 900 kW produits.
local ASM = { { entity = "assembling-machine-2", recipe = "iron-gear-wheel", n = 12, where = "qg" } }
local function case1()
  local f = team(30000, 15000)
  local pw = Capi.power_input(f, "fini")
  local r = Ca.decide(scene(pw, ASM), {})
  return pw, r
end
local pw1, r1 = case1()
check(pw1 and pw1.have_kw == 1800 and math.abs(pw1.used_kw - 900) < 1e-9,
  string.format("§1 vue de la porte : capacité %s kW, mesure + chantiers %s kW", tostring(pw1 and pw1.have_kw), tostring(pw1 and pw1.used_kw)))
check(elec_drills(r1) >= 1 and r1.kw and r1.kw.nominal >= 1800,
  string.format("§1 vue de la porte : %d foreuse(s) électrique(s) décidée(s), nominal relevé %s kW (journal seulement)", elec_drills(r1),
    tostring(r1.kw and r1.kw.nominal)))
Capi.MUT.nominal = true
local pwn, rn = case1()
Capi.MUT.nominal = nil
check(pwn and pwn.used_kw == nil and elec_drills(rn) == 0 and courant_refus(rn) >= 1,
  string.format("§1 mutant « used_kw nominal » : %d foreuse(s), %d refus de courant (étouffement)", elec_drills(rn), courant_refus(rn)))

-- §2 boucle B : 1 200 kW produits sur 1 800 kW, aucune machine électrique de plus.
local function case2(capi_kw_fn)
  local f = team(30000, 20000)
  local r = Ca.decide(scene(Capi.power_input(f, "fini")), {})
  local blocked = r.kw and r.kw.blocked or 0
  -- versement comme decide_finish (script/ai3/capitalisation.lua : cs.kw_blocked = { kw, tick })
  f.team.capi.kw_blocked = blocked > 0 and { kw = blocked, tick = 1000 } or nil
  local old = S.capi_kw
  if capi_kw_fn then S.capi_kw = capi_kw_fn end
  local fin = { id = 1, state = "fini", ents = {} }
  local ant, comm
  for _ = 1, S.ANTICIPATE_CHECKS do ant, _, _, comm = Sante.growth(f, 1000, { fin }, 20000, 30000) end
  S.capi_kw = old
  local nb = C.growth({ sat = 0, saturated = false }, { done = 1, pending = 0, refused = 0, hold = false, cool = false, off = false, built = 1,
    lane_cap = 6, anticipate = ant })
  -- témoin : la même équipe sans kW retenus
  local w = team(30000, 20000)
  local ant_w
  for _ = 1, S.ANTICIPATE_CHECKS do ant_w = Sante.growth(w, 1000, { fin }, 20000, 30000) end
  return { r = r, blocked = blocked, ant = ant, comm = comm, nb = nb, ant_w = ant_w }
end
local b = case2()
say(string.format("§2 %d foreuse(s) décidée(s), %s kW retenus, avance %s (chantiers comptés %s kW), centrale demandée %s ; témoin : avance %s",
  elec_drills(b.r), tostring(b.blocked), tostring(b.ant), tostring(b.comm), tostring(b.nb), tostring(b.ant_w)))
check(elec_drills(b.r) >= 1 and b.blocked > 0, string.format("§2 la décision pose ce que la marge porte (%d foreuses) et retient le reste (%s kW)",
  elec_drills(b.r), tostring(b.blocked)))
check(b.ant == true and b.comm == b.blocked and b.nb ~= nil and b.ant_w == false,
  string.format("§2 les kW retenus font demander une centrale AVANT la saturation (avance %s, centrale %s) ; sans eux, rien (%s)", tostring(b.ant),
    tostring(b.nb), tostring(b.ant_w)))

-- §3 mutant : la centrale ignore les kW retenus.
local bm = case2(function() return 0 end)
check(not (bm.ant == true and bm.nb ~= nil), "§3 mutant refusé : kW retenus ignorés par la centrale, aucune avance (" .. tostring(bm.ant) .. ")")

print(string.format("[CAPI-BOUCLE-B] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
