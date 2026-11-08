--[[
  Sortie de spirale (shared/team/spirale.lua) : recrue GRATUITE de votre équipe sous son effectif de départ. Décision du DC (QCM,
  7/11 vers 14 h 25), mot pour mot : « je veux toujours n ouvriers minimum, donc 12 si 12 au départ. Au delas ça coute des
  ressources ». Lecture du lead : sous l'effectif de départ, ni plaques ni kit pris au stock, recrue équipée comme une autre, à
  2 PNJ comme à 1 ; au-delà, payée comme avant ; factions inchangées. Aucun minage d'urgence pour le kit d'une recrue gratuite
  (relecture du lead après la fusion de 0102eb36 : le kit ne coûte rien, la parité avec les factions ne tient pas, leur recrue est payée).
  État de la partie du DC sur 0.6.58 (fo-logs/2026-11-07_PARTIE-DC-0658/factorio-current-1415.log, votre équipe, 157,7 à 177 min) :
  2 PNJ sur 12, fer libre 0 ([FO-DEFENSE]), 194 chargeurs ([FO-REARMEMENT]), pierre et cuivre saturés ([FO-IA3C]).
  Sections : §1 règle pure ; §2 planificateur ; §3 lecteurs du cerveau (stock virtuel, budget de la pile) et copie d'E4 ;
  §4 câblage d'E4 (script/team/team.lua, structure) ; mutants de la règle, du planificateur, du cerveau, de la pile, de la copie.
  Le paiement en E4 est joué au moteur simulé par tests/pteam_test.lua (« Correction VERIF-NUIT (moteur simulé) »).
  Lancement : lua5.2 tests/spirale_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Sp = require("shared.team.spirale")
local T = require("shared.team.config")

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
end

local FE = T.outposts.iron.product

---------------------------------------------------------------------------------------------------
-- §1 Règle pure
---------------------------------------------------------------------------------------------------
local COST = { { FE, 22 }, { "pistol", 1 } }
local function suite_regle()
  check(Sp.free({ workers = 2, recover_floor = 12 }), "partie du DC (2 PNJ sur 12) : recrue gratuite")
  check(Sp.free({ workers = 1, recover_floor = 12 }) and Sp.free({ workers = 0, recover_floor = 12 }),
    "1 PNJ et 0 PNJ sur 12 : gratuite aussi (pas seulement sous 2)")
  check(Sp.free({ workers = 11, recover_floor = 12 }), "11 sur 12 : gratuite (la dernière qui manque)")
  check(not Sp.free({ workers = 12, recover_floor = 12 }) and not Sp.free({ workers = 13, recover_floor = 12 }),
    "12 et 13 sur 12 : payée (« au delas ça coute des ressources »)")
  check(not Sp.free({ workers = 1, recover_floor = 12, emergency = { floor = 12 } }), "faction (view.emergency) : jamais gratuite")
  check(not Sp.free({ workers = 1 }) and not Sp.free(nil), "sans effectif de départ connu, ou vue absente : jamais gratuite")
  local c = Sp.cost({ workers = 2, recover_floor = 12 }, COST)
  check(type(c) == "table" and #c == 0, "coût sous le départ : liste vide")
  check(Sp.cost({ workers = 12, recover_floor = 12 }, COST) == COST, "coût à l'effectif de départ : le coût tel quel")
  -- journal [FO-RECRUE] (choix (1) du lead : garde QGSURVIE gardée) : au plus une ligne par minute
  check(Sp.log_due(nil, 0) and not Sp.log_due(100, 3699) and Sp.log_due(100, 3700), "journal [FO-RECRUE] : au plus une ligne par minute")
  local tx = Sp.held_text({ key = "player", dist = 30.6, biters = 4, armed = 0, workers = 2, floor = 12, minutes = 157.7 })
  check(tx:find("[FO-RECRUE] player : recrue gratuite retenue : garde QG (biters a 31 tuiles, 0 tourelle(s) armee(s))", 1, true) == 1
    and tx:find("effectif 2/12 a 157.7 min", 1, true) ~= nil, "texte de [FO-RECRUE] : " .. tx)
  check(Sp.held_text({ key = "player" }):find("biters a ? tuiles", 1, true) ~= nil, "[FO-RECRUE] sans distance connue : « ? »")
end

---------------------------------------------------------------------------------------------------
-- §2 Planificateur (shared/team/planner.lua) : vues de votre équipe (recover_floor), livre des tests
---------------------------------------------------------------------------------------------------
local Planner = require("shared.team.planner")
local Book = require("shared.team.book")
local S = require("shared.team.scale")
local book = Book.new(dofile("tests/fixtures/recipes.lua"))
local function pview(over)
  local v = {
    tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {},
    outposts = {}, pending = {}, sites = {}, smelters = 2, smelters_pending = 0, smelter_task = false,
    smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0, turret_groups = {},
    soldiers = 0, soldiers_max = 0, workers = 2, workers_max = 30, workers_idle = 0, threatened = false, open = {},
    workers_wanted = 30, no_research = true, recover_floor = 12,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recover_floor == false then v.recover_floor = nil end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function has_task(plan, key)
  for _, t in ipairs(plan.tasks) do if t.key == key then return t end end
  return nil
end
local function wants_recruit(plan)
  for _, t in ipairs(plan.tasks) do if t.tag == "ouvrier" then return true end end
  return false
end
local DC = { ["firearm-magazine"] = 194, ["copper-plate"] = 5385, stone = 28888, coal = 300 }
local RICH = { [FE] = 2000, ["copper-plate"] = 500, coal = 100 }
local KIT = { [FE] = 2000, ["copper-plate"] = 500, coal = 100, pistol = 2, ["firearm-magazine"] = 30 }
local function free_armed(p)
  return p.recruit_workers == 1 and p.recruit_free == true and not p.recruit_unarmed and p.recruit_uses == nil
    and not wants_recruit(p)
end
local function suite_planner()
  local p2 = Planner.plan(pview({ workers = 2, stock = DC }), book)
  local mt = has_task(p2, "mine:iron-ore")
  check(free_armed(p2), "partie du DC (2 PNJ sur 12, fer 0) : recrue gratuite et équipée, rien de prélevé ni de fabriqué")
  check(mt == nil or mt.prio < 90, "partie du DC : AUCUN minage d'urgence pour le kit d'une recrue gratuite (le kit ne coûte rien)")
  check(free_armed(Planner.plan(pview({ workers = 1, stock = DC }), book)), "1 PNJ sur 12, fer 0 : gratuite et équipée (pas sans arme)")
  check(free_armed(Planner.plan(pview({ workers = 0, stock = {} }), book)), "équipe vide, coffre vide : gratuite et équipée")
  local pr = Planner.plan(pview({ workers = 5, stock = RICH }), book)
  check(free_armed(pr) and has_task(pr, "mine:iron-ore") == nil, "5 sur 12, 2 000 fer : gratuite (fer non pris), aucun minage d'urgence")
  local p12 = Planner.plan(pview({ workers = 12, stock = DC }), book)
  local m12 = has_task(p12, "mine:iron-ore")
  check(not p12.recruit_free and (m12 == nil or m12.prio < 90), "à l'effectif de départ : pas de recrue gratuite, pas de minage d'URGENCE")
  local p13 = Planner.plan(pview({ workers = 13, stock = KIT }), book)
  check(p13.recruit_workers == 1 and not p13.recruit_free and not p13.recruit_unarmed,
    "13 sur 12, kit et 2 000 fer au coffre : recrue de croissance PAYÉE (règle ordinaire)")
  local fac = Planner.plan(pview({ workers = 1, stock = RICH, recover_floor = false, emergency = { floor = 12, rebuild = false } }), book)
  check(fac.recruit_workers == 1 and not fac.recruit_free and fac.recruit_uses ~= nil, "faction (view.emergency) : payée avec les plaques, comme avant")
  local ph = Planner.plan(pview({ workers = 2, stock = DC, hold_recruits = true }), book)
  check(not ph.recruit_workers and not ph.recruit_free, "recrues retenues (garde QGSURVIE ou perte récente) : aucune recrue, gardée")
  local pb = Planner.plan(pview({ workers = 2, stock = DC, recruit_blocked = true }), book)
  check(not pb.recruit_free and not (pb.recruit_workers and not pb.recruit_unarmed), "plafond d'agents atteint : aucune recrue gratuite")
  -- filet de recul (décision du DC, 7/11 vers 16 h 56) : la vue dit « en recul » : ni recrue gratuite, ni recrue payée (§4), ni minage
  -- d'urgence pour un kit
  local pw = Planner.plan(pview({ workers = 2, stock = DC, recul_wait = true }), book)
  local mw = has_task(pw, "mine:iron-ore")
  check(not pw.recruit_workers and pw.recruit_recul and not pw.recruit_free and (mw == nil or mw.prio < 90),
    "en recul (2 sur 12, fer 0) : aucune recrue, aucun minage d'urgence")
  local pk2 = Planner.plan(pview({ workers = 5, stock = KIT, recul_wait = true }), book)
  check(not pk2.recruit_workers and pk2.recruit_recul, "en recul, kit et 2 000 fer au coffre : pas de recrue PAYÉE à la place (§4 sauté)")
  local pu = Planner.plan(pview({ workers = 13, stock = KIT, recul_wait = true }), book)
  check(pu.recruit_workers == 1 and not pu.recruit_recul, "au-delà du départ : le recul ne touche pas la recrue payée")
  local again = Planner.plan(pview({ workers = 2, stock = DC }), book)
  check(free_armed(again) and #again.tasks == #p2.tasks, "deux pensées identiques")
end

---------------------------------------------------------------------------------------------------
-- §3 Lecteurs du cerveau : stock virtuel (C.consumed), budget de la pile (Pi.signals), copie d'E4 (E.freeze)
---------------------------------------------------------------------------------------------------
local C = require("shared.ai3.cerveau")
local Pi = require("shared.ai3.pile")
local Et = require("shared.team.etapes")
local function suite_lecteurs()
  local v = pview({ workers = 2, stock = DC })
  local used_free = C.consumed({ tasks = {}, recruit_workers = 1, recruit_free = true }, v)
  local used_paid = C.consumed({ tasks = {}, recruit_workers = 1 }, v)
  check(used_free[FE] == nil and (used_paid[FE] or 0) > 0,
    string.format("stock virtuel : la recrue gratuite ne prend rien (fer %s ; payée : %s)", tostring(used_free[FE]), tostring(used_paid[FE])))
  local sp = Pi.signals({ workers = 2, recover_floor = 12, recruit_cost = { { FE, 30 } } }, {}, {}, {}, nil, nil)
  check(sp.survive == "effectif" and #(sp.recruit_claim or { 0 }) == 0,
    "budget de la pile, votre équipe sous le départ : survie « effectif » gardée, AUCUN fer réclamé pour les recrues")
  local sf = Pi.signals({ workers = 2, emergency = { floor = 12 }, recruit_cost = { { FE, 30 } } }, {}, {}, {}, nil, nil)
  check(sf.recruit_claim and sf.recruit_claim[1] and sf.recruit_claim[1][2] == 300, "budget de la pile, faction : 10 recrues à 30 fer = 300 (inchangé)")
  local fz = Et.freeze(v, { recruit_workers = 1, recruit_free = true })
  check(fz.plan.recruit_free == true, "copie d'E4 (shared/team/etapes.lua) : plan.recruit_free gardé de T à T + 3")
end

---------------------------------------------------------------------------------------------------
-- §5 Filet de recul (NON branché) : la recrue gratuite recule seulement si elle meurt vite
---------------------------------------------------------------------------------------------------
--- Simulation : 2 PNJ sur 12, une recrue gratuite par pensée (tick % 300 == 177) sous le départ ; chaque recrue meurt `kill_after`
--- ticks après son apparition tant que tick < camp_until (nil : jamais). Rend (recrues, effectif final, état).
local function sim(kill_after, minutes, filet, camp_until)
  local st, alive, workers, spawns = Sp.recul_new(), {}, 2, 0
  for tick = 0, minutes * 3600 do
    for i = #alive, 1, -1 do
      if kill_after and (not camp_until or alive[i] < camp_until) and tick - alive[i] >= kill_after then
        if filet then Sp.recul_death(st, alive[i], tick) end
        table.remove(alive, i)
        workers = workers - 1
      end
    end
    if tick % 300 == 177 and workers < 12 and (not filet or Sp.recul_ready(st, tick)) then
      spawns, workers = spawns + 1, workers + 1
      alive[#alive + 1] = tick
      if filet then Sp.recul_spawn(st, tick) end
    end
  end
  return spawns, workers, st
end
local function suite_recul()
  local st = Sp.recul_new()
  check(Sp.recul_ready(st, 0) and st.wait == 0, "recul : sans mort, la recrue part tout de suite")
  Sp.recul_death(st, 1000, 1600)
  check(st.wait == 600 and not Sp.recul_ready(st, 2199) and Sp.recul_ready(st, 2200), "recul : morte 10 s après son apparition : 600 ticks d'attente")
  for _, d in ipairs({ 3000, 5000, 9000, 14000 }) do Sp.recul_death(st, d - 600, d) end
  check(st.wait == 3600 and st.quick == 5, "recul : 600, 1 200, 2 400, puis plafond 3 600 (" .. st.wait .. ")")
  local slow = Sp.recul_new()
  Sp.recul_death(slow, 0, 3600)
  check(slow.wait == 0 and Sp.recul_ready(slow, 3600), "recul : une mort lente (60 s ou plus) ne change rien")
  check(not Sp.recul_ready(st, 14000 + 17999) or st.wait == 3600, "recul : pas de remise à 0 avant 5 min")
  check(Sp.recul_ready(st, 14000 + 18000) and st.wait == 0, "recul : 5 min sans mort rapide : attente remise à 0")
  -- partie : sans campeur, la cadence est inchangée (le DC veut ses 12)
  local n0, w0 = sim(nil, 2, true)
  check(n0 == 10 and w0 == 12, "sans campeur : 10 recrues, effectif 12 (" .. n0 .. ", " .. w0 .. ")")
  -- campeur qui tue chaque recrue 10 s après son apparition, 30 min (le cas de la partie du DC) : sans filet, ~ 12 morts par minute
  local nn = sim(600, 30, false)
  local nf, _, sf = sim(600, 30, true)
  check(nn >= 300 and nf <= 40 and nf >= 20, string.format("campeur 30 min : %d recrues sans filet, %d avec (au plus 1 par minute environ)", nn, nf))
  -- morts lentes (90 s) : le filet ne retient rien
  check(sim(5400, 30, true) == sim(5400, 30, false), "morts lentes (90 s) : autant de recrues avec et sans filet")
  -- le campeur part à 10 min : l'attente retombe à 0 et l'équipe revient à 12
  local _, wr, sr = sim(600, 30, true, 10 * 3600)
  local ready_after = Sp.recul_ready(sr, 30 * 3600)
  check(wr == 12 and ready_after and sr.wait == 0, string.format("campeur parti à 10 min : effectif %d ; à 30 min, recrue prête %s, attente %d",
    wr, tostring(ready_after), sr.wait))
  check(sf.wait == 3600, "campeur jusqu'au bout : attente au plafond (" .. sf.wait .. ")")
  local t1 = Sp.recul_text({ key = "player", age = 600, wait = 1200, minutes = 1.5 })
  local t2 = Sp.recul_held_text({ key = "player", left = 900, wait = 1200, workers = 2, floor = 12, minutes = 1.6 })
  check(t1 == "[FO-RECRUE] player : recrue gratuite tuee 10 s apres son arrivee : recul, attente 1200 ticks (20 s) avant la suivante a 1.5 min"
    and t2:find("[FO-RECRUE] player : recrue gratuite en recul : prochaine dans 15 s (attente 1200 ticks), effectif 2/12", 1, true) == 1,
    "journal [FO-RECRUE] du recul : " .. t1 .. " | " .. t2)
end

-- §5 parade du KIT OFFERT (décision du lead, 7/11 vers 19 h 05) : au plus 1 pistolet et les chargeurs non payés ; rien d'un kit payé
local function suite_kit()
  local G = { gun = 1, ammo = 10 }
  local function take(gift, pg, pa, paid) local g, a = Sp.kit_take(gift, { gun = pg, ammo = pa }, paid) return g .. "/" .. a end
  check(take(nil, 1, 10, 0) == "0/0", "kit : kit payé (pas de don) : rien de retiré")
  check(take(G, 1, 10, 0) == "1/10", "kit : mort sans tir ni réarmement : 1 pistolet, 10 chargeurs retirés")
  check(take(G, 1, 6, 0) == "1/6", "kit : 4 chargeurs tirés : les 6 restants (offerts) retirés")
  check(take(G, 1, 10, 4) == "1/6", "kit : 4 tirés puis 4 payés au réarmement : 6 retirés, les 4 payés laissés")
  check(take(G, 1, 6, 10) == "1/0", "kit : plus de payés que présents : aucun chargeur retiré (les offerts sont partis au tir)")
  check(take(G, 0, 10, 0) == "0/10", "kit : pistolet déjà absent du corps : rien à retirer pour lui")
  check(take(G, 3, 50, 0) == "1/10", "kit : jamais au-delà du don (3 pistolets, 50 chargeurs : 1 et 10)")
  local t = Sp.kit_text({ key = "player", unit = 77, gun = 1, ammo = 6, kept = 4, total_gun = 3, total_ammo = 26, minutes = 12.5 })
  check(t == "[FO-KIT-OFFERT] player : corps du PNJ 77 : kit offert retire (pistolet 1, chargeurs 6 ; chargeurs payes laisses 4) ; "
    .. "depuis le debut 3 pistolet(s), 26 chargeur(s) a 12.5 min", "journal [FO-KIT-OFFERT] : " .. t)
  check(Sp.KIT_TTL == 600, "kit : fiche de mort oubliée après 600 ticks")
end

suite_regle()
suite_planner()
suite_lecteurs()
suite_recul()
suite_kit()
local base_fail = failures

---------------------------------------------------------------------------------------------------
-- Mutants
---------------------------------------------------------------------------------------------------
local killed, total = 0, 0
local function run_all() suite_regle() suite_planner() suite_lecteurs() suite_recul() suite_kit() end
local function judge(name, ok, f0)
  local caught = (failures > f0) or not ok
  if caught then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. name) end
end
local real_free = Sp.free
local function rule_mutant(name, f)
  total = total + 1
  Sp.free = f
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(run_all)
  quiet = false
  Sp.free = real_free
  judge(name, ok, f0)
  passes, failures = p0, f0
end
rule_mutant("jamais gratuite (0.6.58 : payée avec les plaques)", function() return false end)
rule_mutant("gratuite aussi à l'effectif de départ (<=)", function(v)
  return v ~= nil and not v.emergency and v.recover_floor ~= nil and (v.workers or 0) <= v.recover_floor end)
rule_mutant("gratuite aussi pour les factions", function(v)
  local fl = v and (v.recover_floor or (v.emergency and v.emergency.floor))
  return fl ~= nil and (v.workers or 0) < fl end)
rule_mutant("gratuite seulement sous 2 PNJ (ancienne consigne)", function(v) return real_free(v) and (v.workers or 0) < 2 end)
do -- journal à chaque pensée au lieu d'une fois par minute
  total = total + 1
  local real_every = Sp.LOG_EVERY
  Sp.LOG_EVERY = 300
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(run_all)
  quiet = false
  Sp.LOG_EVERY = real_every
  judge("[FO-RECRUE] a chaque pensee (300 ticks)", ok, f0)
  passes, failures = p0, f0
end
-- mutants du filet de recul
local real_death, real_ready = Sp.recul_death, Sp.recul_ready
local function recul_mutant(name, death, ready)
  total = total + 1
  Sp.recul_death, Sp.recul_ready = death or real_death, ready or real_ready
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(run_all)
  quiet = false
  Sp.recul_death, Sp.recul_ready = real_death, real_ready
  judge(name, ok, f0)
  passes, failures = p0, f0
end
-- mutants de la parade du kit offert
local real_take = Sp.kit_take
local function kit_mutant(name, f)
  total = total + 1
  Sp.kit_take = f
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(run_all)
  quiet = false
  Sp.kit_take = real_take
  judge(name, ok, f0)
  passes, failures = p0, f0
end
kit_mutant("kit : chargeurs payés retirés aussi", function(g, p) if not g then return 0, 0 end return math.min(g.gun, p.gun or 0), math.min(g.ammo, p.ammo or 0) end)
kit_mutant("kit : au-delà du don", function(g, p, paid) if not g then return 0, 0 end return p.gun or 0, math.max(0, (p.ammo or 0) - (paid or 0)) end)
kit_mutant("kit : kit payé vidé aussi", function(g, p, paid) return real_take(g or { gun = 1, ammo = 10 }, p, paid) end)
kit_mutant("kit : pistolet compté même absent", function(g, p, paid) local a, b = real_take(g, p, paid) return g and 1 or a, b end)
recul_mutant("recul : attente jamais doublee", function(st, b, d)
  st = real_death(st, b, d) if st.wait > 0 then st.wait = Sp.RECUL_BASE st.next_at = d + Sp.RECUL_BASE end return st end)
recul_mutant("recul : sans plafond", function(st, b, d)
  st = st or Sp.recul_new()
  if b == nil or d == nil or d - b >= Sp.RECUL_VITE then return st end
  st.wait = (st.wait or 0) > 0 and st.wait * 2 or Sp.RECUL_BASE
  st.next_at, st.last_quick, st.quick = math.max(st.next_at or 0, d + st.wait), d, (st.quick or 0) + 1
  return st end)
recul_mutant("recul : jamais remis a 0", nil, function(st, tick) return not st or tick >= (st.next_at or 0) end)
recul_mutant("recul : les morts lentes comptent aussi", function(st, b, d) return real_death(st, b and (d - 1), d) end)
recul_mutant("recul : aucun filet", function(st) return st or Sp.recul_new() end)
do -- départ sans attente : deux recrues à une pensée d'écart avant la première mort
  total = total + 1
  local real_spawn = Sp.recul_spawn
  Sp.recul_spawn = function(st) return st end
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(run_all)
  quiet = false
  Sp.recul_spawn = real_spawn
  judge("recul : le depart ne repousse pas la suivante", ok, f0)
  passes, failures = p0, f0
end

local function src_of(path) local fh = assert(io.open(path, "rb")) local t = fh:read("*a") fh:close() return t end
local function mutate(src, from, to)
  local a, b = src:find(from, 1, true)
  if not a then return nil end
  return src:sub(1, a - 1) .. to .. src:sub(b + 1)
end
--- Copie mutée d'un module (path, nom local du module dans ce test), chargée à part, puis les suites.
local function module_mutant(name, path, from, to, set)
  total = total + 1
  local mutated = mutate(src_of(path), from, to)
  if not mutated then print("  MUTANT INTROUVABLE : " .. name) return end
  local M = assert(load(mutated, "=" .. path .. "-mutant"))()
  local restore = set(M)
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(run_all)
  quiet = false
  restore()
  judge(name, ok, f0)
  passes, failures = p0, f0
end
local function set_planner(M) local r = Planner Planner = M return function() Planner = r end end
local function set_cerveau(M) local r = C C = M return function() C = r end end
local function set_pile(M) local r = Pi Pi = M return function() Pi = r end end
local function set_etapes(M) local r = Et Et = M return function() Et = r end end
module_mutant("planificateur : pas de drapeau recruit_free (E4 paierait)", "shared/team/planner.lua",
  "out.recruit_free = true", "", set_planner)
module_mutant("planificateur : minage d'urgence pour le kit gratuit (0102eb36)", "shared/team/planner.lua",
  "      out.emergency_recruit = true\n    end\n  end",
  "      out.emergency_recruit = true\n    end\n"
    .. "    local p = book:plan(view.recruit_cost or kit_list(\"worker\", 1), real_avail())\n"
    .. "    if next(p.raw) ~= nil then emergency_mine(p.raw) end\n  end",
  set_planner)
module_mutant("planificateur : garde des recrues retenues ignorée", "shared/team/planner.lua",
  "if rf and not view.hold_recruits and not view.recruit_blocked and Sp.free(view) then",
  "if rf and not view.recruit_blocked and Sp.free(view) then", set_planner)
module_mutant("planificateur : plafond d'agents ignoré", "shared/team/planner.lua",
  "if rf and not view.hold_recruits and not view.recruit_blocked and Sp.free(view) then",
  "if rf and not view.hold_recruits and Sp.free(view) then", set_planner)
module_mutant("planificateur : recul ignore", "shared/team/planner.lua", "if view.recul_wait then", "if false then", set_planner)
module_mutant("planificateur : recrue payee pendant le recul (§4 non saute)", "shared/team/planner.lua",
  "and not out.recruit_recul then", "then", set_planner)
module_mutant("cerveau : la recrue gratuite prend au stock virtuel", "shared/ai3/cerveau.lua",
  "and not base.recruit_free then", "then", set_cerveau)
module_mutant("pile : les recrues gratuites réclament leur fer au budget", "shared/ai3/pile.lua",
  "ipairs(Sp.cost(view, view.recruit_cost) or {})", "ipairs(view.recruit_cost or {})", set_pile)
module_mutant("copie d'E4 : recruit_free perdu entre T et T + 3", "shared/team/etapes.lua",
  '"recruit_blocked", "recruit_free",', '"recruit_blocked",', set_etapes)

---------------------------------------------------------------------------------------------------
-- §4 Câblage hors du Lua pur (structure) : E4 saute le paiement, le besoin évalué ne compte pas les recrues gratuites
---------------------------------------------------------------------------------------------------
local function count(src, pat)
  local n, i = 0, 1
  while true do
    local x, y = src:find(pat, i, true)
    if not x then return n end
    n, i = n + 1, y + 1
  end
end
local WIRES = {
  { "script/team/team.lua", "local free = f.is_player and plan.recruit_free or false" },
  { "script/team/team.lua", "and (free or has_list(stock, pay)) then" },
  { "script/team/team.lua", "if not free then remove_list(f, pay) end" },
  { "script/team/team.lua", "local recruit = Worker.recruit(f, surface, tick, false, free)" },
  { "script/team/team.lua", "elseif not free then" },
  { "shared/ai3/cerveau.lua", "cost = Sp.cost(view, view.recruit_cost)," },
  { "shared/ai3/cerveau.lua", "recruit_free = base.recruit_free," },
  -- [FO-RECRUE] : dans la branche de la garde QGSURVIE (hold_recruits), recrue gratuite seulement, au plus 1 par minute
  { "script/team/team.lua", "if Sp.free({ workers = f.engineers_count or 0, recover_floor = floor }) and Sp.log_due(f.team.recrue_log, tick) then" },
  { "script/team/team.lua", "f.team.recrue_log = tick" },
  { "script/team/team.lua", "log(Sp.held_text({" },
  -- filet de recul : mort rapide (worker.lua), vue et journal « en recul », arrivée datée et départ en E4 (team.lua)
  { "script/team/worker.lua", "if f.is_player and f.team and agent.free_born and agent.death_cause then" },
  { "script/team/worker.lua", "f.team.recul = Sp.recul_death(f.team.recul, agent.free_born, now)" },
  { "script/team/team.lua", "and not Sp.recul_ready(f.team.recul, tick) then" },
  { "script/team/team.lua", "recul_wait = recul_wait," },
  { "script/team/team.lua", "recruit.free_born = tick" },
  { "script/team/team.lua", "if f.team.recul then Sp.recul_spawn(f.team.recul, tick) end" },
  -- parade du kit offert (worker.lua) : fiche à la recrue au kit offert, chargeurs payés au réarmement, retrait du corps rendu
  { "script/team/worker.lua", "if free and not unarmed then kit_give(f, e) end" },
  { "script/team/worker.lua", "kit_paid(e, put)" },
  { "script/team/worker.lua", "local gun, ammo = Sp.kit_take({ gun = 1, ammo = d.ammo }, present, d.paid)" },
  { "script/team/worker.lua", "Events.on(defines.events.on_post_entity_died, function(e)" },
  -- filtre moteur (relecture de revue-0657) : posé à on_init ET à on_load, limité aux personnages
  { "script/team/worker.lua", "Worker.KIT_POST_FILTER = { { filter = \"type\", type = \"character\" } }" },
  { "script/team/worker.lua", "Events.on_init(kit_post_filter)" },
  { "script/team/worker.lua", "Events.on_load(kit_post_filter)" },
}
local wired = true
for _, w in ipairs(WIRES) do if count(src_of(w[1]), w[2]) ~= 1 then wired = false print("  CABLAGE ABSENT : " .. w[1] .. " : " .. w[2]) end end
check(wired, "câblage : E4 (gratuite : rien de retiré ni rendu, kit offert), cerveau (besoin évalué, plan rendu)")
local tm_mut = 0
for _, w in ipairs(WIRES) do
  local src = src_of(w[1])
  local x, y = src:find(w[2], 1, true)
  local mutated = x and (src:sub(1, x - 1) .. "--" .. src:sub(y + 1)) or src
  if count(mutated, w[2]) ~= 1 then tm_mut = tm_mut + 1 end
end
check(tm_mut == #WIRES, string.format("mutants de texte du câblage : %d / %d vus", tm_mut, #WIRES))
-- Les anciennes sorties de la consigne remplacée (hold, recrue sans arme sous 2) n'existent plus.
check(count(src_of("shared/team/planner.lua"), "spirale_hold") == 0 and count(src_of("script/team/build.lua"), "spirale_hold") == 0,
  "plus de fer gardé (hold) : ni planificateur ni plan directeur")

print(string.format("[SPIRALE] MUTANTS : %d / %d refuses", killed, total))
print(string.format("[SPIRALE] BILAN : %d OK, %d ECHEC(S)%s", passes, failures + (total - killed), base_fail > 0 and " (suite de base en echec)" or ""))
os.exit((failures == 0 and killed == total) and 0 or 1)
