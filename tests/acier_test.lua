--[[
  Lot ACIER (directive du DC, 8/11, 17 h 20 : fonderie d'acier automatisée, plus de PNJ aux fours d'acier) : banc HORS JEU.
  Lancement : lua5.2 tests/acier_test.lua (racine du mod).
    1. gabarit de la rangée de fours (shared/team/modules.lua, G.simple avec un four) : contrôle complet, débits, charbon sur l'autre voie,
       bornes, extension, refus d'un mauvais gabarit ;
    2. règle pure (shared/team/acier.lua) : produit lu aux données, besoin, demande, coupure, hystérésis, mode survie ;
    3. runtime (script/team/acier.lua) sur un monde simulé, avec la VRAIE voie des rangées (script/ai3/rangees_asm.lua) : bloc demandé après
       confirmation, jamais deux en chantier, agrandi sur place, refusé (cause) puis redemandé, tâches d'acier retirées du plan seulement quand
       un bloc fini produit, reprise sous le seuil, survie exemptée, réglage éteint, déterminisme, journal [FO-ACIER] ;
    4. chaîne lue dans les sources (appel avant le filtre des tournées, aucun nom d'objet dans le runtime) ;
    5. coût en instructions Lua (debug.sethook) ;
    6. MUTANTS de la règle pure : chaque défaut injecté change au moins un fait observé.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local M = require("shared.team.modules")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end
local function read_src(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local STEEL = "steel-plate"
local IRON = "iron-plate"
local FURN1, FURN2 = "stone-furnace", "steel-furnace"

---------------------------------------------------------------------------------------------------
section("1. gabarit : rangee de fours d'acier")
for _, fu in ipairs({ FURN1, FURN2 }) do
  local speed = M.spec(fu).speed
  for _, n in ipairs({ 1, 2, 5, 6 }) do
    local g, why = M.GEN.simple(STEEL, n, fu)
    local errs, rep = {}, nil
    if g then errs, rep = M.check(g) end
    check(g ~= nil and #errs == 0, fu .. " x" .. n .. " : gabarit sans erreur (" .. tostring(why or errs[1]) .. ")")
    if g and #errs == 0 then
      local want = n * speed / 16
      check(math.abs((rep.outputs[STEEL] or 0) - want) < 1e-6, fu .. " x" .. n .. " : sortie " .. want .. " acier/s (" .. tostring(rep.outputs[STEEL]) .. ")")
      check(math.abs((rep.inputs[IRON] or 0) - 5 * want) < 1e-6, fu .. " x" .. n .. " : entree 5 plaques par acier")
      check((rep.inputs.coal or 0) > 0, fu .. " x" .. n .. " : le charbon des fours arrive sur l'autre voie du tapis")
    end
  end
  local g9 = M.GEN.simple(STEEL, 9, fu)
  check(g9 == nil or #M.check(g9) > 0, fu .. " : 9 fours depassent l'emprise (refus)")
  local g7 = M.GEN.simple(STEEL, 7, fu)
  check(g7 and g7.w + M.PORT_ROOM > M.MAX_SIDE, fu .. " : 7 fours = " .. tostring(g7 and g7.w) .. " tuiles + " .. M.PORT_ROOM .. " de ports, plus que le lot du plan (24) : borne a 6")
  local g = M.GEN.simple(STEEL, 3, fu)
  check(g and g.extensions[1].max == 6 and g.extensions[1].arg == 2, fu .. " : borne 6 fours (ports compris, 24 tuiles du lot), argument 2")
  local ge = g and M.extend(g, 6)
  check(ge and #M.check(ge) == 0 and ge.args[2] == 6 and ge.w + M.PORT_ROOM <= M.MAX_SIDE, fu .. " : extension a 6 fours refaite, controlee, dans le lot")
  local lanes
  for _, p in ipairs(g.ports) do if p.io == "in" and p.lanes then lanes = p.lanes end end
  check(lanes and lanes[1] == IRON and lanes[2] == "coal", fu .. " : voies d'entree = plaques de fer et charbon")
end
-- un assembleur reste un assembleur : la rangee de cables est inchangee (cle, borne)
---------------------------------------------------------------------------------------------------
section("1b. la borne tient dans le lot du plan directeur, ports compris (P.fit sur un lot entierement libre ; moteur reel : 8 fours -> \"trop grand\", 7 -> \"place\")")
do
  local P = require("shared.team.plan")
  local free = function() return true end
  local rect = { x0 = 0, y0 = 0, x1 = P.LOT, y1 = P.LOT }
  check(M.MAX_SIDE == P.LOT, "le lot du plan fait M.MAX_SIDE tuiles")
  for _, fu in ipairs({ FURN1, FURN2 }) do
    local bound = M.GEN.simple(STEEL, 1, fu).extensions[1].max
    for n = 1, bound + 1 do
      local g = M.GEN.simple(STEEL, n, fu)
      local fit, why = nil, "gabarit refuse"
      if g then fit, why = P.fit(g, rect, { free = free }) end
      if n <= bound then
        check(fit ~= nil, fu .. " x" .. n .. " : tient dans un lot libre du plan (" .. tostring(why) .. ")")
      else
        check(fit == nil, fu .. " x" .. n .. " (borne + 1) : refuse par le plan, la borne est donc la plus grande taille qui tient (" .. tostring(why) .. ")")
      end
    end
    -- la constante M.PORT_ROOM est la mesure de P.port_room : largeur des cases de ports - largeur du gabarit
    local g = M.GEN.simple(STEEL, 3, fu)
    local x0, x1 = math.huge, -math.huge
    for _, t in ipairs(P.port_room(M.instantiate(g, 0, 0, 0))) do x0, x1 = math.min(x0, t[1]), math.max(x1, t[1]) end
    check(x1 - x0 + 1 - g.w == M.PORT_ROOM, fu .. " : M.PORT_ROOM = " .. M.PORT_ROOM .. " = mesure de P.port_room (" .. tostring(x1 - x0 + 1 - g.w) .. ")")
  end
end
local gc = M.GEN.simple("copper-cable", 3, "assembling-machine-1")
check(gc and gc.extensions[1].max == 3 and #M.check(gc) == 0, "rangee d'assembleurs inchangee (cables a 3)")
-- refus : une recette d'assembleur dans un four, une recette de fonte dans un assembleur, une entite sans machine
check(M.GEN.simple("copper-cable", 2, FURN1) == nil, "four : une recette de fabrication est refusee")
check(M.GEN.simple(STEEL, 2, "assembling-machine-1") == nil, "assembleur : la recette de fonte est refusee")
check(M.GEN.simple(STEEL, 2, "transport-belt") == nil, "une entite qui n'est pas une machine est refusee")
-- mutant du gabarit : charbon retire de l'autre voie du tapis -> le controle le voit
do
  local g = M.GEN.simple(STEEL, 3, FURN2)
  for _, p in ipairs(g.ports) do if p.io == "in" and p.lanes then p.lanes[2] = IRON end end
  local errs = M.check(g)
  check(#errs > 0, "mutant : sans charbon sur le tapis, le controle refuse le gabarit (" .. tostring(errs[1]) .. ")")
end

---------------------------------------------------------------------------------------------------
section("2. regle pure (shared/team/acier.lua)")
local SRC_AC = read_src("shared/team/acier.lua")
local function load_ac(text)
  package.loaded["shared.team.config"] = T
  return assert(load(text or SRC_AC, "@shared/team/acier.lua"))()
end
local function ac_facts(Ac)
  local f = {}
  local H = Ac.HOLD
  f.item = Ac.ITEMS[1] -- (lot COLONNES : produits des colonnes dédiées, triés ; l'acier passe avant les briques)
  -- coupure
  f.no_block = Ac.decide_cut(nil, { finished = 0, flow = 50, need = 6, short = 60, tick = 1e6 })
  f.low = Ac.decide_cut(nil, { finished = 1, flow = 5, need = 6, short = 60, tick = 1e6 })
  f.ok = Ac.decide_cut(nil, { finished = 1, flow = 6, need = 6, short = 60, tick = 1e6 })
  f.zero_need = Ac.decide_cut(nil, { finished = 1, flow = 0, need = 0, short = 0, tick = 1e6 })
  f.survie = Ac.decide_cut(nil, { finished = 1, flow = 50, need = 6, short = 60, tick = 1e6, survie = true })
  f.survie_prev = Ac.decide_cut({ cut = true, since = 0 }, { finished = 1, flow = 50, need = 6, short = 60, tick = 1e6, survie = true })
  -- hystérésis : seuil 6, reprise sous 3, tenue de 3 min
  f.hold = Ac.decide_cut({ cut = true, since = 1000 }, { finished = 1, flow = 0, need = 6, short = 60, tick = 1000 + H - 1 })
  f.resume = Ac.decide_cut({ cut = true, since = 0 }, { finished = 1, flow = 2, need = 6, short = 60, tick = H + 1 })
  f.keep = Ac.decide_cut({ cut = true, since = 0 }, { finished = 1, flow = 4, need = 6, short = 60, tick = H + 1 })
  f.keep_nothing_short = Ac.decide_cut({ cut = true, since = 0 }, { finished = 1, flow = 0, need = 0, short = 0, tick = H + 1 })
  f.lost_block = Ac.decide_cut({ cut = true, since = 0 }, { finished = 0, flow = 0, need = 6, short = 60, tick = H + 1 })
  f.recut_hold = Ac.decide_cut({ cut = false, since = 5000 }, { finished = 1, flow = 50, need = 6, short = 60, tick = 5000 + H - 1 })
  -- besoin
  f.need_cons = Ac.need({ cons = 30, short = 0 })
  f.need_short = Ac.need({ cons = 0, short = 100 })
  f.need_min = Ac.need({ cons = 0, short = 10 })
  f.need_none = Ac.need({ cons = 0, short = 0 })
  f.need_nan = Ac.need({ cons = 0 / 0, short = nil })
  -- demande
  f.ask_wait = Ac.ask({ count = 1, need = 6, cap = 0, tick = 1e6, retry_at = 0 })
  f.ask_first = Ac.ask({ count = 2, need = 6, cap = 0, tick = 1e6, retry_at = 0 })
  f.ask_enough = Ac.ask({ count = 2, need = 6.5, cap = 7.5, tick = 1e6, retry_at = 0 })
  f.ask_grow = Ac.ask({ count = 2, need = 20, cap = 7.5, tick = 1e6, retry_at = 0 })
  f.ask_retry = Ac.ask({ count = 2, need = 20, cap = 7.5, tick = 100, retry_at = 100 + Ac.RETRY })
  f.seen_up = Ac.seen(0, 5)
  f.seen_cap = Ac.seen(50, 5)
  f.seen_down = Ac.seen(2, 0)
  f.seen_floor = Ac.seen(0, 0)
  return f
end
local Ac = load_ac()
local F0 = ac_facts(Ac)
check(F0.item == STEEL, "produit : l'acier est la fonte dont l'entree est elle-meme un produit de fonte (T.smelter_inputs)")
check(F0.no_block == false, "coupure refusee sans bloc fini (meme avec un debit)")
check(F0.low == false, "coupure refusee sous le seuil (5 < 6)")
check(F0.ok == true, "coupure au seuil (6 >= 6)")
check(F0.zero_need == false, "coupure refusee sans debit mesure (plancher Ac.FLOOR)")
check(F0.survie == false and F0.survie_prev == false, "mode survie : jamais coupe, meme deja coupe")
check(F0.hold == true, "tenue : la coupure ne s'inverse pas avant Ac.HOLD")
check(F0.resume == false, "reprise sous la moitie du seuil quand de l'acier manque (2 < 3)")
check(F0.keep == true, "hysteresis : reste coupe a 4 (entre 3 et 6)")
check(F0.keep_nothing_short == true, "reste coupe quand rien ne manque (aucune demande, pas de reprise)")
check(F0.lost_block == false, "bloc perdu (plus aucun fini) : reprise")
check(F0.recut_hold == false, "tenue apres une reprise : pas de nouvelle coupure avant Ac.HOLD")
check(F0.need_cons == 30 and F0.need_short == 10 and F0.need_min == 4 and F0.need_none == 0 and F0.need_nan == 0,
  "besoin : max(consommation, manque / horizon), plancher Ac.MIN_RATE quand il manque, 0 sinon, NaN ignore")
check(F0.ask_wait == 0, "demande : pas avant Ac.CONFIRM pensees")
check(math.abs(F0.ask_first - 7.5) < 1e-9, "demande : premiere rangee = besoin x (1 + marge) = 7,5")
check(F0.ask_enough == 0, "demande : capacite suffisante (6,5 <= 90 % de 7,5)")
check(math.abs(F0.ask_grow - (20 * 1.25 - 7.5)) < 1e-9, "demande : agrandissement = besoin x (1 + marge) - capacite")
check(F0.ask_retry == 0, "demande : rien avant la fin du delai apres un refus")
check(F0.seen_up == 1 and F0.seen_cap == Ac.CONFIRM + 4 and F0.seen_down == 1 and F0.seen_floor == 0, "compteur de pensees : monte, plafonne, decroit, jamais sous 0")

---------------------------------------------------------------------------------------------------
-- Lot TESTS-VERTS : F547 (lot COLONNES, f0797071) : une colonne par produit (Ac.ITEMS), état f.team.acier.by[produit], journal
-- « colonne <produit> : ... » (Ac.line), produits par Ac.items : repères du journal, de l'état et du mutant suivis.
section("3. runtime sur un monde simule (vraie voie des rangees)")
local LOG = {}
_G.log = function(s) LOG[#LOG + 1] = s end
local TICK = 0
local MODS, BRIEFS = {}, {}
local SUBMITS, GROWS = {}, {}
local SURVIE, NEXT_ID = false, 100
local MISSING = {} -- four -> objets manquants simulés
local A = require("shared.ai3.automatiser")

local Rg_on = true
local PLANT = "fini"
package.loaded["script.faction.state"] = { war = function() return { started = 0 } end, sorted_keys = function(t)
  local ks = {} for k in pairs(t or {}) do ks[#ks + 1] = k end table.sort(ks) return ks end }
package.loaded["script.team.harvest"] = { reachable = function() return {} end }
package.loaded["script.team.survie"] = { on = function() return SURVIE end }
package.loaded["script.team.convoyeurs"] = { belts = function() return {} end, usable = function() return function() return false end end }
package.loaded["script.team.build"] = {
  Rangee = { on = function() return Rg_on end,
    grow = function(f, id, n2, tick) GROWS[#GROWS + 1] = { id = id, n = n2 } return 2 end },
  brief = function(f, id) return BRIEFS[id] end,
  resize_waiting = function() return false end,
}
package.loaded["script.ai3.automatisation"] = {
  plant_state = function() return PLANT end, belt_flow = function() return nil end,
  submit = function(f, rq, tick)
    SUBMITS[#SUBMITS + 1] = rq
    NEXT_ID = NEXT_ID + 1
    f.team.ia3e.mods[#f.team.ia3e.mods + 1] = { id = NEXT_ID, product = rq.product, state = "attente", gen = rq.gen, args = rq.args,
      rate_nom = rq.rate_nom, rate = rq.rate, missing = {} }
    BRIEFS[NEXT_ID] = { state = "attente" }
    return NEXT_ID
  end,
}
package.loaded["script.ai3.capitalisation"] = {
  fit_module = function(meth, rate, book, stock, has_plant, harvest, belt_flow)
    local fu = meth.args[3]
    if MISSING[fu] then return nil, MISSING[fu] end
    return A.sized(meth, rate)
  end,
}
package.loaded["shared.ai3.rangees_asm"] = nil
package.loaded["script.ai3.rangees_asm"] = nil
package.loaded["shared.team.acier"] = load_ac()
package.loaded["script.team.acier"] = nil
local Acier = assert(load(read_src("script/team/acier.lua"), "@script/team/acier.lua"))()

local function world(opts)
  opts = opts or {}
  LOG, SUBMITS, GROWS, MISSING, SURVIE, BRIEFS = {}, {}, {}, {}, opts.survie or false, {}
  PLANT = opts.plant or "fini"
  Rg_on = true
  local mods = {}
  for _, m in ipairs(opts.mods or {}) do mods[#mods + 1] = m; if m.id then BRIEFS[m.id] = m.brief or { state = m.state } end end
  return { key = opts.key or "fa", started = 0, hq = { valid = true }, team = { ia3e = { mods = mods },
    ia3 = { bilan = { items = { [STEEL] = { c = opts.cons or 0 } } } } } }
end
local function plan_of(short, extra)
  local smelt = {}
  if short and short > 0 then smelt[STEEL] = short end
  local tasks = { { key = "craft:x", kind = "craft", item = "x" }, { key = "smelt", kind = "smelt", prio = 60, smelt = smelt } }
  for _, t in ipairs(extra or {}) do tasks[#tasks + 1] = t end
  return { smelt = smelt, tasks = tasks }
end
local VIEW = { stock = {}, smelter_output = 0, smelter_fuel_low = false, threatened = false }
local BOOK = { handcraftable = function() return true end }
local function has_task(plan, key) for _, t in ipairs(plan.tasks) do if t.key == key then return true end end return false end
local function logged(pat) for _, l in ipairs(LOG) do if l:find(pat, 1, true) then return true end end return false end
local function think(f, plan, tick, view) Acier.apply(f, view or VIEW, BOOK, plan, tick) end

-- a) demande : rien a la premiere pensee, un bloc a la deuxieme
do
  local f = world()
  local p1 = plan_of(60)
  think(f, p1, 1000)
  check(#SUBMITS == 0, "a) premiere pensee avec de l'acier demande : rien (confirmation)")
  check(p1.smelt[STEEL] == 60 and has_task(p1, "smelt"), "a) la main reste ouverte tant qu'aucun bloc ne produit")
  local p2 = plan_of(60)
  think(f, p2, 1300)
  check(#SUBMITS == 1, "a) deuxieme pensee : un bloc est demande")
  local rq = SUBMITS[1] or {}
  check(rq.product == STEEL and rq.gen == "simple" and rq.rangee == true and rq.feed == true, "a) bloc = rangee dynamique de fours (gen simple, spec.rangee)")
  check(rq.args and rq.args[1] == STEEL and rq.args[3] == FURN2, "a) le meilleur four dont les objets se fabriquent (" .. tostring(rq.args and rq.args[3]) .. ")")
  check(rq.args and rq.args[2] == 1, "a) un seul four au depart : besoin 6/min, un four de rang 2 en fait 7,5 (" .. tostring(rq.args and rq.args[2]) .. ")")
  check(rq.electric == true, "a) bras electriques : le module est electrique")
  check(logged("[FO-ACIER] fa : colonne " .. STEEL .. " : bloc DEMANDE : module 101"), "a) journal : bloc demande")
  -- b) un bloc en chantier : pas de second, meme si le besoin monte au-dela de sa capacite
  f.team.ia3.bilan.items[STEEL].c = 30
  local p3 = plan_of(60)
  think(f, p3, 1600)
  think(f, plan_of(60), 1900)
  check(#SUBMITS == 1, "b) bloc en chantier : jamais un deuxieme")
  check(has_task(p3, "smelt") and p3.smelt[STEEL] == 60, "b) bloc en chantier : l'acier reste au plan")
  local n_ask = 0
  for _, l in ipairs(LOG) do if l:find("[FO-ACIER]", 1, true) then n_ask = n_ask + 1 end end
  check(n_ask == 2, "b) une ligne de journal par changement (" .. n_ask .. " au lieu de 2)")
end

-- b bis) sans centrale finie : le bloc attend (il ne fait pas demander la centrale)
do
  local f = world({ plant = "chantier" })
  think(f, plan_of(60), 1000)
  think(f, plan_of(60), 1300)
  check(#SUBMITS == 0 and logged("bloc en attente : centrale de l'equipe non finie (etat chantier)"), "b bis) centrale non finie : aucune demande, cause au journal")
  PLANT = "fini"
  think(f, plan_of(60), 1600)
  check(#SUBMITS == 1, "b bis) centrale finie : le bloc est demande")
end

-- b ter) recette de l'acier verrouillee : aucun bloc (il ne fondrait rien), puis demande des l'ouverture de la recette
do
  local f = world()
  f.force = "fx"
  local fr = { recipes = { [STEEL] = { enabled = false } } }
  rawset(_G, "game", { forces = { fx = fr } })
  think(f, plan_of(60), 1000)
  think(f, plan_of(60), 1300)
  check(#SUBMITS == 0 and logged("colonne " .. STEEL .. " : bloc en attente : la recette est verrouillee"), "b ter) recette verrouillee : aucune demande, cause au journal")
  fr.recipes[STEEL].enabled = true
  think(f, plan_of(60), 1600)
  check(#SUBMITS == 1, "b ter) recette ouverte : le bloc est demande")
  rawset(_G, "game", nil)
end

-- c) refus : tous les fours manquent d'objets ; cause au journal ; nouvelle tentative apres le delai
do
  local f = world()
  MISSING[FURN1], MISSING[FURN2] = { "inserter" }, { "fast-inserter", "inserter" }
  think(f, plan_of(60), 1000)
  think(f, plan_of(60), 1300)
  check(#SUBMITS == 0 and logged("[FO-ACIER] fa : colonne " .. STEEL .. " : bloc REFUSE : objets impossibles : fast-inserter,inserter"), "c) objets introuvables : refus avec sa cause (four le plus rapide)")
  think(f, plan_of(60), 1600)
  local n = 0
  for _, l in ipairs(LOG) do if l:find("REFUSE", 1, true) then n = n + 1 end end
  check(n == 1, "c) pas de nouvelle tentative avant le delai (" .. n .. " ligne(s))")
  MISSING[FURN2] = { "inserter" }
  MISSING[FURN1] = nil
  think(f, plan_of(60), 1300 + 3 * 3600 + 1)
  check(#SUBMITS == 1 and SUBMITS[1].args[3] == FURN1, "c) apres le delai : repli sur le four suivant qui se fabrique (" .. tostring(SUBMITS[1] and SUBMITS[1].args[3]) .. ")")
end

-- c bis) bloc refuse par le plan directeur ("trop grand", moteur reel) : pas redemande a chaque pensee
do
  local f = world({ mods = { { id = 9, product = STEEL, state = "refuse", reason = "trop grand", rate_nom = 15 } } })
  think(f, plan_of(60), 1000)
  think(f, plan_of(60), 1300)
  think(f, plan_of(60), 1600)
  check(#SUBMITS == 0 and logged("bloc REFUSE par le plan directeur : trop grand"), "c bis) refus du plan directeur : aucune nouvelle demande, cause au journal")
  think(f, plan_of(60), 1000 + 3 * 3600 + 1)
  check(#SUBMITS == 1, "c bis) apres le delai : une nouvelle demande")
end

-- d) transition : un bloc fini qui produit retire l'acier du plan
local function fini(rate, id) return { id = id or 7, product = STEEL, state = "fini", gen = "simple", args = { STEEL, 2, FURN2 }, rate_nom = 15, rate_meas = rate,
  brief = { state = "fini", rangee = { n = 2, n_max = 6, held = 4 } } } end
do
  local f = world({ mods = { fini(20) } })
  local extra = { { key = "smelt2", kind = "smelt", prio = 60, smelt = { [STEEL] = 60, ["stone-brick"] = 10 } } }
  local plan = plan_of(60, extra)
  think(f, plan, 1000)
  check(plan.smelt[STEEL] == nil, "d) bloc fini a 20/min >= besoin 6/min : plus d'acier dans plan.smelt")
  check(not has_task(plan, "smelt"), "d) la tournee qui n'avait que l'acier a fondre disparait")
  check(has_task(plan, "smelt2") and plan.tasks[#plan.tasks].smelt["stone-brick"] == 10 and plan.tasks[#plan.tasks].smelt[STEEL] == nil,
    "d) une tournee qui fond aussi autre chose reste, sans l'acier")
  check(has_task(plan, "craft:x"), "d) les autres tâches sont intactes")
  check(logged("[FO-ACIER] fa : colonne " .. STEEL .. " : taches manuelles COUPEES"), "d) journal : taches manuelles coupees")
  -- une tournee appelee par une sortie ou un combustible reste
  local f2 = world({ mods = { fini(20) } })
  local plan2 = plan_of(60)
  think(f2, plan2, 1000, { stock = {}, smelter_output = 12, smelter_fuel_low = false })
  check(has_task(plan2, "smelt") and plan2.tasks[2].smelt[STEEL] == nil, "d) sortie a vider : la tournee reste mais sans acier")
  local f3 = world({ mods = { fini(20) } })
  local plan3 = plan_of(60)
  think(f3, plan3, 1000, { stock = {}, smelter_output = 0, smelter_fuel_low = true })
  check(has_task(plan3, "smelt"), "d) four a ravitailler en charbon : la tournee reste")
  -- pensee suivante : toujours coupe (meme plan reconstruit)
  local plan4 = plan_of(80)
  think(f, plan4, 1300)
  check(plan4.smelt[STEEL] == nil and not has_task(plan4, "smelt"), "d) la coupure tient d'une pensee a l'autre")
end

-- e) sans fonderie qui produit : rien n'est coupe
do
  local f = world({ mods = { fini(0) } })
  local plan = plan_of(60)
  think(f, plan, 1000)
  check(plan.smelt[STEEL] == 60 and has_task(plan, "smelt"), "e) bloc fini a 0/min : l'acier reste au plan (coupure refusee)")
  local f2 = world({ mods = { { id = 8, product = STEEL, state = "chantier", rate_nom = 15, rate_meas = 99 } } })
  local plan2 = plan_of(60)
  think(f2, plan2, 1000)
  check(plan2.smelt[STEEL] == 60, "e) bloc en chantier (meme avec un debit lu) : rien de coupe")
  local f3 = world({ mods = { { id = 9, product = STEEL, state = "refuse", rate_nom = 15, rate_meas = 99 } } })
  local plan3 = plan_of(60)
  think(f3, plan3, 1000)
  check(plan3.smelt[STEEL] == 60, "e) bloc refuse : rien de coupe")
  local f4 = world({ mods = { fini(5) } })
  local plan4 = plan_of(100)
  think(f4, plan4, 1000)
  check(plan4.smelt[STEEL] == 100, "e) bloc qui produit 5/min pour un besoin de 10/min : la main reste")
end

-- f) reprise sous la moitie du seuil, apres la tenue
do
  local f = world({ mods = { fini(20) } })
  think(f, plan_of(60), 1000)
  check(f.team.acier.by[STEEL].cut == true, "f) coupe")
  f.team.ia3e.mods[1].rate_meas = 4
  local p_hyst = plan_of(60)
  think(f, p_hyst, 1000 + 3 * 3600 + 1)
  check(p_hyst.smelt[STEEL] == nil, "f) hysteresis : a 4/min (seuil 6, reprise sous 3) l'acier reste coupe")
  f.team.ia3e.mods[1].rate_meas = 2
  local p_early = plan_of(60)
  think(f, p_early, 1300)
  check(p_early.smelt[STEEL] == nil, "f) tenue : pas de reprise dans les 3 minutes")
  local p_res = plan_of(60)
  think(f, p_res, 1000 + 3 * 3600 + 301)
  check(p_res.smelt[STEEL] == 60 and has_task(p_res, "smelt"), "f) debit 2/min < 3 apres la tenue : les taches manuelles reprennent")
  check(logged("colonne " .. STEEL .. " : taches manuelles REPRISES"), "f) journal : reprise")
end

-- g) mode survie, reglage eteint, equipe du joueur
do
  local f = world({ mods = { fini(20) }, survie = true })
  local plan = plan_of(60)
  think(f, plan, 1000)
  check(plan.smelt[STEEL] == 60 and has_task(plan, "smelt"), "g) mode survie : jamais coupe")
  local f2 = world({ mods = { fini(20) } })
  _G.settings = { global = { ["fo-war-acier"] = { value = false } } }
  local plan2 = plan_of(60)
  think(f2, plan2, 1000)
  think(f2, plan_of(60), 1300)
  _G.settings = nil
  check(plan2.smelt[STEEL] == 60 and #SUBMITS == 0 and f2.team.acier == nil, "g) reglage fo-war-acier eteint : plan intact, aucune demande, aucun etat")
  local fp = world({ mods = { fini(20) }, key = "player" })
  fp.is_player = true
  local plan3 = plan_of(60)
  think(fp, plan3, 1000)
  check(plan3.smelt[STEEL] == nil, "g) votre equipe : meme regle (fo-war-acier vaut pour les deux)")
  local fm = world({})
  local view_threat = { stock = {}, smelter_output = 0, threatened = true }
  think(fm, plan_of(60), 1000, view_threat)
  think(fm, plan_of(60), 1300, view_threat)
  check(#SUBMITS == 0, "g) equipe menacee : aucun bloc demande (leviers du QG seulement)")
end

-- h) agrandissement sur place : un bloc fini a 2 fours, besoin 20/min
do
  local f = world({ mods = { fini(5) } })
  f.team.ia3.bilan.items[STEEL].c = 20
  think(f, plan_of(60), 1000)
  think(f, plan_of(60), 1300)
  check(#SUBMITS == 0 and #GROWS == 1, "h) besoin 20/min, capacite 15/min : la rangee finie grandit sur place (aucun module de plus)")
  check(GROWS[1] and GROWS[1].id == 7 and GROWS[1].n > 2, "h) agrandie au-dela de 2 fours (" .. tostring(GROWS[1] and GROWS[1].n) .. ")")
  check(logged("[FO-ACIER] fa : colonne " .. STEEL .. " : bloc DEMANDE : module 7"), "h) journal : agrandissement du module 7")
end

-- i) determinisme : deux passages identiques, meme journal
do
  local function run()
    local f = world({ mods = { fini(20) } })
    local plan = plan_of(60)
    think(f, plan, 1000)
    think(f, plan_of(60), 1300)
    return table.concat(LOG, "\n")
  end
  check(run() == run(), "i) deux passages identiques : meme journal")
end

---------------------------------------------------------------------------------------------------
section("3 bis. rangee dynamique de fours (script/team/rangee_dyn.lua et shared/team/rangee_dyn.lua reels)")
do
  local Rg = require("script.team.rangee_dyn")
  local Rd = require("shared.team.rangee_dyn")
  local gs = M.GEN.simple(STEEL, 2, FURN2)
  local p = { id = 7, state = "plan", spec = { gen = "simple", args = { STEEL, 2, FURN2 }, rangee = true }, ents = {},
    outflow = { [STEEL] = 0 }, inflow = { [IRON] = 0 } }
  local f = { key = "test", build = { projects = { [7] = p } } }
  local gm = Rg.full(p, gs)
  check(gm.params.n == 6 and p.rangee_plan and p.rangee_plan.n == 2 and p.rangee_plan.n_max == 6, "gabarit de fours planifie a la borne (6), place entiere reservee")
  p.outflow[STEEL], p.inflow[IRON] = gm.nominal[STEEL], gm.inputs[IRON]
  local ents = {}
  for _, e in ipairs(gm.entities) do ents[#ents + 1] = { name = e.name, x = e.x, y = e.y, part = 1 } end
  Rg.tag(p, ents, gm)
  p.ents = ents
  Rg.after(f, p, true)
  local function nmach(list) local c = 0 for _, e in ipairs(list) do local s = M.spec(e.name) if s and (s.kind == "furnace") then c = c + 1 end end return c end
  check(p.rangee and p.rangee.n == 2 and nmach(p.ents) == 2 and #p.rangee.held > 0, "2 fours poses, 4 en attente avec leurs bras")
  check(math.abs(p.outflow[STEEL] - 2 * M.spec(FURN2).speed / 16) < 1e-6, "debit annonce a 2/6 de la rangee")
  -- chaque taille partielle (pieces en attente retirees) reste un gabarit valide, au debit de n fours
  for n = 1, 6 do
    local cols = Rd.columns(gm.entities, function(nm) local s = M.spec(nm) if s and s.kind == "furnace" then return "machine" end if s and s.kind == "inserter" then return "bras" end end,
      function(nm) return (gm.cell and gm.cell.w) or M.spec(nm).w end) -- (lot RETROFIT-GABARITS : colonne = cellule réservée du gabarit)
    local _, h = Rd.split(cols, #gm.entities, Rd.order(6, nil), n)
    local drop = {}
    for _, i in ipairs(h) do drop[i] = true end
    local gp = { entities = {}, ports = {}, w = gm.w, h = gm.h, key = gm.key, anchors = gm.anchors, fuel_ports = gm.fuel_ports, water = gm.water, notes = {}, params = gm.params }
    local remap = {}
    for i, e in ipairs(gm.entities) do if not drop[i] then gp.entities[#gp.entities + 1] = e remap[i] = #gp.entities end end
    for _, q in ipairs(gm.ports) do local c = {} for k, v in pairs(q) do c[k] = v end c.ent = remap[q.ent] gp.ports[#gp.ports + 1] = c end
    gp.power_pole = remap[gm.power_pole]
    local errs, rep = M.check(gp)
    check(#errs == 0 and math.abs((rep.outputs[STEEL] or 0) - n * M.spec(FURN2).speed / 16) < 1e-6, "rangee partielle " .. n .. "/6 : 0 erreur, " .. n * 0.125 .. " acier/s (" .. tostring(errs[1]) .. ")")
  end
  p.state = "fini"
  local mv = Rg.grow(f, 7, 5, 100)
  check(mv > 0 and p.rangee.n == 5 and nmach(p.ents) == 5 and p.state == "reserve", "finie : agrandie a 5 fours sur place, projet rouvert en reserve")
  check(math.abs(p.outflow[STEEL] - 5 * M.spec(FURN2).speed / 16) < 1e-6, "debit annonce a 5/6")
end

---------------------------------------------------------------------------------------------------
section("4. chaine lue dans les sources")
local TEAM = read_src("script/team/team.lua")
local i_ap = TEAM:find("Acier.apply(f, view, book_for(f), plan, tick)", 1, true)
local i_fl = TEAM:find("ChaineMain.filter_tasks(plan.tasks", 1, true)
local i_bs = TEAM:find("f.team.bench_smelt then", 1, true)
check(i_ap and i_fl and i_bs and i_bs < i_ap and i_ap < i_fl, "team.lua : Acier.apply apres le plan (bancs compris) et avant le filtre des tournees de fonte")
check(TEAM:find('local Acier = require("script.team.acier")', 1, true) ~= nil, "team.lua : require du runtime")
local RT = read_src("script/team/acier.lua")
local stripped = RT:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
for _, name in ipairs({ "steel", "iron", "coal", "plate", "stone" }) do
  check(not stripped:find('"[%w%-]*' .. name .. '[%w%-]*"'), "runtime : aucun nom d'objet ecrit (" .. name .. ")")
end
check(read_src("script/ai3/capitalisation.lua"):find("Capi.fit_module = fit_module", 1, true) ~= nil, "capitalisation : fit_module exporte pour le bloc d'acier")
check(read_src("script/team/rangee_dyn.lua"):find('sp.kind == "furnace"', 1, true) ~= nil, "rangee dynamique : un four est une machine de la rangee")
check(read_src("script/team/intermediaires.lua"):find("fondu", 1, true) ~= nil, "plafond D10 : l'acier (fondu d'une plaque) est suivi")
check(read_src("settings/acier.lua"):find('"fo-war-acier"', 1, true) ~= nil, "settings/acier.lua declare fo-war-acier")

---------------------------------------------------------------------------------------------------
section("5. cout en instructions Lua")
local function instr(fn)
  local n = 0
  debug.sethook(function() n = n + 1 end, "", 1)
  fn()
  debug.sethook()
  return n
end
LOG = {}
local f_idle = world({})
local p_idle = plan_of(0)
local c_idle = instr(function() think(f_idle, p_idle, 5000) end)
local f_hot = world({ mods = { fini(20) } })
think(f_hot, plan_of(60), 1000)
local p_hot = plan_of(60)
local c_hot = instr(function() think(f_hot, p_hot, 1300) end)
A.reset_cache() -- pire cas : gabarits dimensionnes a froid
local f_req = world({})
think(f_req, plan_of(60), 1000)
local p_req = plan_of(60)
local c_req = instr(function() think(f_req, p_req, 1300) end)
print(string.format("  instructions : pensee sans demande %d ; bloc fini et coupure %d ; demande d'un bloc (pire cas) %d", c_idle, c_hot, c_req))
check(c_idle < 3000, "cout : pensee sans demande d'acier < 3 000 instructions (" .. c_idle .. ")")
check(c_hot < 6000, "cout : pensee avec bloc fini (coupure tenue) < 6 000 instructions (" .. c_hot .. ")")
check(c_req < 60000, "cout : demande d'un bloc (gabarit dimensionne a froid, une fois) < 60 000 instructions (" .. c_req .. ")")

---------------------------------------------------------------------------------------------------
section("6. mutants de la regle pure")
local MUTANTS = {
  { "coupure sans bloc fini", 'if num(a.finished) < 1 then return false, "aucun bloc fini" end', "" },
  { "coupure sans debit suffisant", "if flow >= th then return true", "if true then return true" },
  { "plancher du seuil retire", "return math.max(Ac.FLOOR, num(need) * Ac.COVER)", "return num(need) * Ac.COVER" },
  { "reprise impossible", "flow < th * Ac.OFF then return false", "flow < -1 then return false" },
  { "pas d'hysteresis (OFF = 1)", "Ac.OFF = 0.5 ", "Ac.OFF = 1 " },
  { "mode survie ignore", "if a.survie then return false", "if false then return false" },
  { "tenue retiree", "< Ac.HOLD then return true", "< -1 then return true" },
  { "tenue apres reprise retiree", "num(a.tick) - num(prev.since) < Ac.HOLD then return false", "false then return false" },
  { "besoin sans consommation", "math.max(cons, short / Ac.HORIZON)", "short / Ac.HORIZON" },
  { "besoin sans plancher", "if short > 0 then n = math.max(n, Ac.MIN_RATE) end", "" },
  { "demande toujours", "if need <= cap * Ac.GROW_AT then", "if need <= 0 then" },
  { "demande sans confirmation", "if num(a.count) < Ac.CONFIRM then", "if false then" },
  { "demande sans delai de refus", "if num(a.tick) < num(a.retry_at) then", "if false then" },
  { "demande sans marge", "local rate = need * (1 + Ac.MARGIN) - cap", "local rate = need - cap" },
  { "compteur sans decroissance", "return math.max(0, count - 1)", "return count" },
  { "produit lu sur un autre critere", "if inputs[k] and not fielded[inputs[k][1]] then", "if inputs[k] then" },
}
local function plain_replace(s, old, new)
  local i, j = s:find(old, 1, true)
  assert(i, "motif absent de la regle : " .. old)
  return s:sub(1, i - 1) .. new .. s:sub(j + 1)
end
local function differs(a, b)
  for k, v in pairs(a) do if b[k] ~= v then return k end end
  for k, v in pairs(b) do if a[k] ~= v then return k end end
  return nil
end
for _, mu in ipairs(MUTANTS) do
  local ok, Am = pcall(load_ac, plain_replace(SRC_AC, mu[2], mu[3]))
  local diff = nil
  if ok then
    local ok2, fm = pcall(ac_facts, Am)
    if ok2 then diff = differs(F0, fm) else diff = "plantage" end
  else
    diff = "ne charge plus"
  end
  check(diff ~= nil, "mutant « " .. mu[1] .. " » : change un fait observe (" .. tostring(diff) .. ")")
end

print(string.format("[ACIER] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
