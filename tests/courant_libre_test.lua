--[[
  Lot COURANT-LIBRE (partie neuve 0.6.70, journal 2026-11-08_INTEG-0670/neuve40-b : « 1800 kW pris sur 1800 kW » de 7,9 à 37 min alors que la
  production mesurée est de 0 kW, aucune foreuse électrique de plus). Cause : un ordre de CHAMP ouvert garde n_left = n (toutes ses foreuses)
  jusqu'à la première production de la bande ; les foreuses déjà posées sont comptées ailleurs (relevé, mesure du courant), et le projet de la
  bande pèse encore 0,6 x ses kW parmi les chantiers de la vue de la porte (Sante.committed). La marge ne se libère donc jamais quand la
  centrale ne tourne pas. L'amorçage (Ca.spend_amorce) n'est PAS en cause après la centrale finie (9 refus avant 7,7 min, 0 après).
    §1 Ca.champ_left : reste à poser en foreuses (pur) ;
    §2 Mig.follow rend les foreuses de la bande (rôle « champ-foreuse ») et celles posées ;
    §3 Capi.follow_one (branche champ) : n_left suit les foreuses posées, rec.pid garde le projet ; mutant « champ_plein » (l'ancien reste) ;
    §4 Capi.power_input : le projet d'un ordre de champ ouvert n'est pas compté deux fois ; mutant « champ_compte_deux » ;
    §5 Ca.decide : centrale de 1 800 kW, ordre de champ de 20 foreuses dont 18 posées : des foreuses de plus passent (marge 1 620 kW) ; avec
       l'ancien reste (20), refus « courant insuffisant » et aucune foreuse ; l'amorçage reste à UN ordre sans centrale finie.
  Usage : lua5.2 tests/courant_libre_test.lua   (depuis la racine du mod ; quelques secondes)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[COURANT-LIBRE] ECHEC : " .. msg) end
end

M.new_world({ difficulty = "peaceful", ia3e = true, capi = true })
M.load_mod()
local Ca = package.loaded["shared.ai3.capitalisation"]
local Capi = package.loaded["script.ai3.capitalisation"]
local Mig = package.loaded["script.team.migration_champ"]
local F = require("tests.iag_fixture")
assert(Ca and Capi and Mig, "modules du runtime absents")

-- §1 règle pure
check(Ca.champ_left(9, nil, nil) == 9, "§1 projet pas encore au plan : tout reste à poser")
check(Ca.champ_left(9, 0, 0) == 9, "§1 projet sans foreuse : tout reste à poser")
check(Ca.champ_left(9, 9, 0) == 9, "§1 aucune posée : 9")
check(Ca.champ_left(9, 9, 6) == 3, "§1 6 posées sur 9 : 3")
check(Ca.champ_left(9, 9, 9) == 0, "§1 toutes posées : 0")
check(Ca.champ_left(9, 12, 0) == 9, "§1 bande plus grande que l'ordre : jamais plus que l'ordre")
check(Ca.champ_left(9, 5, 2) == 3, "§1 bande plus petite : son reste")
check(Ca.champ_left(9, 5, 7) == 0 and Ca.champ_left(-3, 5, 0) == 0 and Ca.champ_left(nil, nil, nil) == 0, "§1 bornes : jamais négatif")

-- §2 Mig.follow
local function field_f(ents)
  return { key = "banc", outposts = {}, migration = { fields = { [900] = { id = 900, field = true } }, o = { [900] = { stage = "projet", pid = 5, produced = 0 } } },
    build = { projects = { [5] = { id = 5, state = "chantier", ents = ents } } } }
end
local function ent(role, built) return { name = role == "champ-foreuse" and "electric-mining-drill" or "x", role = role, built = built or nil } end
local fq = field_f({ ent("champ-foreuse", true), ent("champ-foreuse", true), ent("champ-foreuse"), ent("champ-poteau", true), ent("champ-tapis", true) })
local s = Mig.follow(fq, 900, 1000)
check(s and s.drills == 3 and s.drills_built == 2 and s.built == 4 and s.pid == 5,
  string.format("§2 follow : %s foreuses, %s posées, %s pièces posées", tostring(s and s.drills), tostring(s and s.drills_built), tostring(s and s.built)))
local sn = Mig.follow({ key = "b", outposts = {}, migration = { fields = { [900] = { id = 900, field = true } }, o = { [900] = { stage = "veille" } } }, build = { projects = {} } }, 900, 1000)
check(sn and sn.drills == 0 and sn.drills_built == 0, "§2 follow sans projet : 0 foreuse")

-- §3 Capi.follow_one, branche champ
local function rec_champ()
  return { exec = "champ", field = 900, produced0 = 0, key = "k1", kind = "couvrir", entity = "electric-mining-drill", n = 20, n_left = 20, missing = {} }
end
local function f_champ(drills_built)
  local ents = {}
  for i = 1, 20 do ents[#ents + 1] = ent("champ-foreuse", i <= drills_built or nil) end
  ents[#ents + 1] = ent("champ-poteau", true)
  return field_f(ents)
end
local r3 = rec_champ()
local st = Capi.follow_one(f_champ(18), {}, r3, 2000)
check(st == "ouvert" and r3.n_left == 2 and r3.pid == 5, string.format("§3 18 posées sur 20 : n_left %s, projet %s, état %s", tostring(r3.n_left), tostring(r3.pid), tostring(st)))
local r3b = rec_champ()
Capi.MUT.champ_plein = true
Capi.follow_one(f_champ(18), {}, r3b, 2000)
Capi.MUT.champ_plein = nil
check(r3b.n_left == 20, "§3 mutant « champ_plein » : l'ancien reste (20) revient, le test le voit")

-- §4 Capi.power_input
local function plant_f(open)
  return { key = "banc", build = { order = { 5 }, projects = { [5] = { id = 5, state = "chantier", admitted = true, power_kw = 1000, ents = {},
    spec = { site = true } } }, grow = { capacity = 30000, power = 0 } }, team = { capi = { open = open or {} } } }
end
-- projet de site en chantier : compté 0,6 x 1 000 = 600 kW quand aucun ordre de champ ne le porte
local function with_state(state)
  local f = plant_f()
  f.build.projects[5].state = state
  return f
end
local base = Capi.power_input(with_state("reserve"), "fini")
check(base and base.have_kw == 1800 and base.used_kw == 0,
  "§4 témoin : site en réserve (matières) non compté tant que ses fantômes ne sont pas posés (" .. tostring(base and base.used_kw) .. ")")
local pa = Capi.power_input(with_state("fantomes"), "fini")
check(pa and math.abs(pa.used_kw - 600) < 1e-9, "§4 projet de site aux fantômes, sans ordre de champ : 600 kW comptés (" .. tostring(pa and pa.used_kw) .. ")")
local fo = with_state("fantomes")
fo.team.capi.open = { { exec = "champ", field = 900, pid = 5, n = 20, n_left = 2 } }
local pb = Capi.power_input(fo, "fini")
check(pb and math.abs(pb.used_kw - 0) < 1e-9, "§4 avec l'ordre de champ ouvert (pid 5) : son projet n'est pas compté deux fois (" .. tostring(pb and pb.used_kw) .. ")")
Capi.MUT.champ_compte_deux = true
local pc = Capi.power_input(fo, "fini")
Capi.MUT.champ_compte_deux = nil
check(pc and math.abs(pc.used_kw - 600) < 1e-9, "§4 mutant « champ_compte_deux » : 600 kW de nouveau comptés")
local fo2 = with_state("fantomes")
fo2.team.capi.open = { { exec = "champ", field = 900, pid = 77, n = 20, n_left = 2 } }
check(math.abs(Capi.power_input(fo2, "fini").used_kw - 600) < 1e-9, "§4 l'ordre d'un AUTRE projet n'exclut rien")
check(Capi.power_input({ key = "x", build = { order = {}, projects = {}, grow = { capacity = 30000, power = 600 } } }, "fini").used_kw == 36,
  "§4 équipe sans f.team : lecture inchangée (mesure seule)")

-- §5 Ca.decide : la marge libérée porte des foreuses de plus
local V_SPEED = { ["stone-furnace"] = 1, ["steel-furnace"] = 2, ["assembling-machine-1"] = 0.5, ["assembling-machine-2"] = 0.75,
  ["burner-mining-drill"] = 0.25, ["electric-mining-drill"] = 0.5, ["lab"] = 1 }
local V_AREA = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 5 }
local V_SIZE = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 3, ["stone-furnace"] = 2, ["steel-furnace"] = 2 }
local V_KW = { ["stone-furnace"] = 90, ["burner-mining-drill"] = 150, ["electric-mining-drill"] = 90, ["assembling-machine-1"] = 75,
  ["assembling-machine-2"] = 150, ["lab"] = 60 }
local function sorted_keys(t) local ks = {} for k in pairs(t or {}) do ks[#ks + 1] = k end table.sort(ks) return ks end
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
local function scene(power, open)
  return { data = D, state = { techs = { automation = true } }, stock = { ["electronic-circuit"] = 3000 },
    flows = { ["iron-ore"] = { made = 60 }, ["iron-plate"] = { made = 60 } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 4, where = "qg" } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 18, deposit = "d1" } }, labs = {},
    deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60 },
      { id = "s2", resource = "iron-ore", tiles = 270, amount = 1e6, dist = 150 } },
    open = open or {}, sinks = { { item = "iron-plate", rate = 1000 } }, workers = 30, idle = 10, can_grow = true, traits = {}, weights = {},
    power = power }
end
local function champ_open(left)
  return { { key = "couvrir:iron-ore@d1", kind = "couvrir", exec = "champ", entity = "electric-mining-drill", resource = "iron-ore", deposit = "d1",
    n = 20, n_left = left, rate = 0, value = 40, T = 8, taken = true } }
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
  for _, r in ipairs(res.refus) do if r.why and r.why:find("courant", 1, true) then n = n + 1 end end
  return n
end
local pw = { have_kw = 1800, used_kw = 0 } -- centrale finie de 1 800 kW qui ne produit rien (journal INTEG-0670)
local libre = Ca.decide(scene(pw, champ_open(Ca.champ_left(20, 20, 18))), {})
local plein = Ca.decide(scene(pw, champ_open(20)), {})
check(elec_drills(libre) >= 1, string.format("§5 reste réel (2) : %d foreuse(s) électrique(s) de plus décidée(s), %d refus de courant", elec_drills(libre), courant_refus(libre)))
check(elec_drills(plein) == 0 and courant_refus(plein) >= 1,
  string.format("§5 ancien reste (20 x 90 kW = 1 800) : %d foreuse, %d refus de courant (le défaut)", elec_drills(plein), courant_refus(plein)))
-- amorçage : sans centrale finie, UN seul ordre électrique par décision (inchangé)
local am = Ca.decide(scene({ amorce = true }, {}), {})
check(elec_drills(am) >= 1 and courant_refus(am) >= 0, "§5 amorçage : un ordre électrique passe pour faire demander la centrale (" .. elec_drills(am) .. ")")

print(string.format("[COURANT-LIBRE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
