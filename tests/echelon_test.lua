--[[
  Lot ECHELON : banc HORS JEU de la règle pure shared/ai3/echelon.lua. Lancement, depuis la racine du mod : lua5.2 tests/echelon_test.lua
    1. l'arriéré des chantiers (Ech.backlog, Ech.sources) ;
    2. le débit d'entrée et les lignes (Ech.input_cap, Ech.lines) ;
    3. le nombre de machines (Ech.plan) : cas « science rouge » (la demande monte, N passe de 1 à N+1 par pas, borné par l'entrée et le plafond) ;
    4. les quais (Ech.fill) et le producteur d'abord (Ech.held_back, Ech.take_limit) ;
    5. SIMULATION « tapis » : un MODELE (hypothèses écrites ci-dessous, affichées), pas le jeu ; critères K2 et K4 de CRITERES.md ;
    6. mutants.
  Les noms d'objets de ce fichier sont des DONNEES DE BANC ; la règle, elle, n'en connaît aucun (tests/iag_test.lua §8).
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end

local BELT, GEAR, PLATE, PACK, CABLE = "transport-belt", "iron-gear-wheel", "iron-plate", "automation-science-pack", "copper-plate" -- données du banc
local TM = 3600

---------------------------------------------------------------------------------------------------
-- Simulation « tapis »
---------------------------------------------------------------------------------------------------
-- HYPOTHESES (mesurées au journal, ou posées et dites) :
--   H1 (mesuré, 2 parties) : le module des tapis est en « reserve:materiaux » 17 à 19 min parce qu'il exige 8 tapis ; les chantiers plus anciens,
--      qui en exigent 52 + 47, prennent ce qui est libre projet après projet. Offre de tapis au stock : 5,5/min (calée sur ces 17 à 19 min).
--   H2 (mesuré) : une machine de 120 tapis/min (le journal dit 180 nominaux pour une machine plus rapide), 1,5 plaque par tapis.
--   H3 (POSE) : un porteur met 3 minutes à venir quand un quai passe sous son seuil, puis remplit jusqu'à `fill` ; avant : fill 400, seuil 60.
--   H4 (POSE) : les chantiers consomment 50 tapis/min en régime établi ; le coffre de sortie garde 10 minutes de demande au plus ; le stock de
--      plaques fournit 100 plaques/min (66 tapis/min : l'entrée ne borne pas la demande de 50).
local function sim_boot(Ech, mode)
  -- amorçage : minutes écoulées avant que le module ait ses 8 tapis. mode "avant" : ordre de création ; mode "apres" : le producteur d'abord.
  local stock, supply = 0, 5.5
  local waiters = { { id = 1, need = 52, got = 0 }, { id = 2, need = 47, got = 0 }, { id = 3, need = 8, got = 0, producer = true } }
  local t, dt = 0, 0.1
  while t < 120 do
    stock = stock + supply * dt
    local projects = {}
    for _, w in ipairs(waiters) do
      projects[#projects + 1] = { id = w.id, state = "reserve", since = 0, produces = w.producer and { [BELT] = true } or nil,
        missing = { { BELT, w.need - w.got } } }
    end
    local held = (mode == "apres") and Ech.held_back(projects, t * TM) or {}
    for _, w in ipairs(waiters) do
      local free = Ech.take_limit(stock, held[BELT] or 0, w.producer == true)
      local take = math.min(w.need - w.got, free)
      w.got, stock = w.got + take, stock - take
    end
    if waiters[3].got >= 8 - 1e-9 then return t end
    t = t + dt
  end
  return t
end

local function sim_steady(Ech, mode)
  -- régime établi : rend (production moyenne / demande, attente en minutes d'un chantier qui demande 52 tapis).
  local par, per, demand = 120, 1.5, 50
  local fill, low
  if mode == "avant" then fill, low = 400, 60 else
    local q = Ech.fill(demand, per, 400, 60, 3200)
    fill, low = q.fill, q.low
  end
  local c, ob, produced, backlog = fill, 0, 0, 0
  local refill_at = nil
  local t, dt, T = 0, 0.1, 40
  local out_cap = demand * 10
  while t < T do
    -- quai : un porteur est appelé sous le seuil, arrive 3 minutes plus tard
    if c < low and not refill_at then refill_at = t + 3 end
    if refill_at and t >= refill_at then c, refill_at = fill, nil end
    -- module : tourne tant que son coffre de sortie n'est pas plein et qu'il a de la matière
    if ob < out_cap then
      local make = math.min(par * dt, c / per)
      c, ob = c - make * per, ob + make
      if t >= 10 then produced = produced + make end
    end
    -- chantiers : consomment la demande dans le coffre de sortie, le manque s'accumule
    local want = demand * dt
    local got = math.min(want, ob)
    ob = ob - got
    backlog = backlog + (want - got)
    t = t + dt
  end
  local ratio = produced / ((T - 10) * demand)
  -- attente d'un chantier de 52 tapis qui arrive à T : ce qui est déjà en retard + 52, servi au rythme de la production courante (>= demande si servi)
  local rate = math.max(demand * ratio, 1e-9)
  local wait = (backlog + 52 - ob) / rate
  if wait < 0 then wait = 0 end
  return ratio, wait
end

---------------------------------------------------------------------------------------------------
-- La batterie (rejouée pour chaque mutant)
---------------------------------------------------------------------------------------------------
local function battery(Ech, verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 if verbose then print("  ECHEC : " .. msg) end end
    if verbose then check(c, msg) end
  end
  -- 1. arriéré
  local rows = Ech.backlog({
    { id = 1, since = 0, missing = { { BELT, 52 }, { PLATE, 10 } } },
    { id = 2, since = 1 * TM, missing = { { BELT, 47 } } },
    { id = 3, since = 5 * TM, missing = { { GEAR, 0 }, { "x", -3 } } },
  }, 3 * TM)
  ck(#rows == 2 and rows[1].item == BELT and rows[2].item == PLATE, "1a. deux objets en manque, le plus gros d'abord (zéro et négatif ignorés)")
  ck(rows[1].qty == 99 and rows[1].projects == 2, "1b. quantités et chantiers cumulés (99, 2)")
  ck(rows[1].oldest == 3 * TM and rows[1].due == true, "1c. le plus ancien attend 3 min : échu")
  ck(math.abs(rows[1].rate - 33) < 1e-9, "1d. débit pour rattraper en 3 min : 99 / 3 = 33")
  local fresh = Ech.backlog({ { id = 1, since = 3 * TM - 30, missing = { { BELT, 5 } } } }, 3 * TM)
  ck(fresh[1].due == false and #Ech.sources(fresh) == 0, "1e. un chantier qui attend depuis moins de 2 min ne fait aucune demande")
  local src = Ech.sources(rows)
  ck(#src == 2 and src[1].src == "chantier" and src[1].item == BELT, "1f. les arriérés échus deviennent des sources de demande")
  ck(#Ech.backlog(nil, 0) == 0 and #Ech.backlog({}, 0) == 0, "1g. rien à lire : liste vide")
  -- 2. entrée
  local ins = { { name = PLATE, per = 1.5 } }
  local cap, bind = Ech.input_cap(ins, { [PLATE] = 60 })
  ck(math.abs(cap - 40) < 1e-9 and bind == PLATE, "2a. 60 plaques/min à 1,5 par objet : 40 objets/min, borné par la plaque")
  cap = Ech.input_cap({ { name = PLATE, per = 1 }, { name = GEAR, per = 1 } }, { [PLATE] = 100, [GEAR] = 30 })
  ck(cap == 30, "2b. deux entrées : la plus étroite borne")
  cap, bind = Ech.input_cap({ { name = PLATE, per = 1 } }, {})
  ck(cap == math.huge and bind == nil, "2c. entrée sans débit connu : non bornée")
  local ln = Ech.lines(120, ins)
  ck(ln[1].lines == 1 and not ln[1].capped, "2d. 180 plaques/min : une ligne de 200")
  ln = Ech.lines(400, ins)
  ck(ln[1].lines == 3 and ln[1].flow == 600, "2e. 600 plaques/min : 3 lignes")
  ln = Ech.lines(5000, ins)
  ck(ln[1].lines == Ech.MAX_LINES and ln[1].capped == true, "2f. au-delà du plafond de lignes : plafonné et dit")
  -- 3. science rouge : machines de 6 objets/min, entrées 1 engrenage + 1 cuivre
  local pack_ins = { { name = GEAR, per = 1 }, { name = CABLE, per = 1 } }
  local st = {}
  local n, tick, log = 1, 0, {}
  local demand = 20
  for _ = 1, 20 do
    local made = math.min(n * 6, 60) * 0.95
    local p = Ech.plan(st, { tick = tick, n = n, par_min = 6, demand = demand, made = made, inputs = pack_ins,
      supply = { [GEAR] = 60, [CABLE] = 60 } })
    log[#log + 1] = p.bound
    n = n + p.add
    tick = tick + 1 * TM
  end
  ck(n == 3, "3a. science rouge, demande 20/min : N passe de 1 à 3 (3 machines = 17,1/min = 85 % de la demande, assez), vu " .. n)
  ck(st.last_add ~= nil, "3b. l'état garde le tick du dernier ajout")
  -- un pas à la fois : deux ajouts ne se suivent pas à moins de COOLDOWN_MIN minutes
  local st2 = {}
  local p1 = Ech.plan(st2, { tick = 0, n = 1, par_min = 6, demand = 20, made = 5, inputs = pack_ins, supply = { [GEAR] = 60, [CABLE] = 60 } })
  local p2 = Ech.plan(st2, { tick = 1 * TM, n = 2, par_min = 6, demand = 20, made = 5, inputs = pack_ins, supply = { [GEAR] = 60, [CABLE] = 60 } })
  local p3 = Ech.plan(st2, { tick = 2 * TM, n = 2, par_min = 6, demand = 20, made = 5, inputs = pack_ins, supply = { [GEAR] = 60, [CABLE] = 60 } })
  ck(p1.add == 1 and p2.add == 0 and p2.bound == "delai" and p3.add == 1, "3c. +1 puis délai puis +1 (" .. p1.add .. ", " .. p2.bound .. ", " .. p3.add .. ")")
  -- l'entrée borne : 13 cuivre/min -> 13 objets/min -> 2 machines au plus, plus rien ne sert d'en poser
  local n2, st3, last = 1, {}, nil
  for i = 1, 20 do
    local made = math.min(n2 * 6, 13) * 0.95
    last = Ech.plan(st3, { tick = i * TM, n = n2, par_min = 6, demand = 20, made = made, inputs = pack_ins, supply = { [GEAR] = 60, [CABLE] = 13 } })
    n2 = n2 + last.add
  end
  ck(n2 == 2 and last.bound == "entree" and last.lever == "entree" and last.bind == CABLE,
    "3d. entrée de 13/min : 2 machines et pas une de plus, cause = l'entrée cuivre (" .. n2 .. ", " .. tostring(last.bound) .. ")")
  -- le plafond
  local n3, st4, last3 = 1, {}, nil
  for i = 1, 60 do
    last3 = Ech.plan(st4, { tick = i * TM, n = n3, par_min = 6, demand = 400, made = n3 * 6 * 0.9, inputs = pack_ins, supply = { [GEAR] = 1e6, [CABLE] = 1e6 } })
    n3 = n3 + last3.add
  end
  ck(n3 == Ech.MAX_COPIES and last3.bound == "plafond", "3e. demande énorme : plafond de " .. Ech.MAX_COPIES .. " machines (" .. n3 .. ", " .. tostring(last3.bound) .. ")")
  -- cibles rapportées : le plafond et l'entrée bornent aussi le nombre VOULU, pas seulement l'ajout
  local pc = Ech.plan({}, { tick = 0, n = 1, par_min = 6, demand = 400, made = 1, inputs = pack_ins, supply = { [GEAR] = 1e6, [CABLE] = 1e6 } })
  ck(pc.n_target == Ech.MAX_COPIES, "3e2. demande énorme : le nombre voulu est le plafond (" .. pc.n_target .. ")")
  local pe = Ech.plan({}, { tick = 0, n = 1, par_min = 6, demand = 20, made = 1, inputs = pack_ins, supply = { [GEAR] = 60, [CABLE] = 13 } })
  ck(pe.n_target == 2, "3d2. entrée de 13/min : le nombre voulu est 2 (" .. pe.n_target .. ")")
  -- les machines posées portent déjà la demande mais la production est basse : l'entrée n'arrive pas, AUCUNE machine de plus
  local pm = Ech.plan({}, { tick = 0, n = 4, par_min = 6, demand = 20, made = 5, inputs = pack_ins, supply = { [GEAR] = 1e6, [CABLE] = 1e6 } })
  ck(pm.add == 0 and pm.bound == "entree" and pm.lever == "entree", "3d3. 4 machines (24/min) pour 20/min demandés, sortie 5/min : l'entrée, pas une machine (" .. pm.bound .. ", +" .. pm.add .. ")")
  -- servi : rien ne change
  local ps = Ech.plan({}, { tick = 0, n = 2, par_min = 6, demand = 10, made = 9, inputs = pack_ins, supply = {} })
  ck(ps.add == 0 and ps.bound == "servi", "3f. production à 90 % de la demande : servi, aucune machine de plus")
  -- sans module : la règle ne pose rien
  local pn = Ech.plan({}, { tick = 0, n = 0, par_min = 6, demand = 10, made = 0 })
  ck(pn.add == 0 and pn.bound == "aucun", "3g. aucun module posé : l'ouverture n'est pas son affaire")
  -- l'arriéré seul (sans demande régulière) déclenche aussi
  local back = Ech.backlog({ { id = 1, since = 0, missing = { { PACK, 60 } } } }, 3 * TM)[1]
  local pb = Ech.plan({}, { tick = 0, n = 1, par_min = 6, backlog = back, demand = 0, made = 1, inputs = pack_ins, supply = {} })
  ck(pb.add == 1 and pb.target_rate == 20 and pb.n_target == 4, "3h. 60 en arriéré, 3 min : 20/min à servir, 4 machines voulues (" .. pb.add .. ", " .. pb.target_rate .. ", " .. pb.n_target .. ")")
  local young = Ech.backlog({ { id = 1, since = 3 * TM - 10, missing = { { PACK, 60 } } } }, 3 * TM)[1]
  local py = Ech.plan({}, { tick = 0, n = 1, par_min = 6, backlog = young, demand = 0, made = 1 })
  ck(py.add == 0, "3i. arriéré pas encore échu : aucune machine de plus")
  -- tapis : la machine suffit, c'est l'entrée
  local belt_back = Ech.backlog({ { id = 1, since = 0, missing = { { BELT, 52 } } } }, 3 * TM)[1]
  local pt = Ech.plan({}, { tick = 0, n = 1, par_min = 120, backlog = belt_back, demand = 2.2, made = 9, inputs = { { name = PLATE, per = 1.5 } }, supply = { [PLATE] = 20 } })
  ck(pt.add == 0 and pt.bound == "entree" and pt.lever == "entree", "3j. tapis : 1 machine de 120/min pour 17/min demandés, sortie 9/min : cause = l'entrée, aucune machine de plus (" .. pt.bound .. ")")
  ck(Ech.module_cap(2, belt_back) == Ech.MAX_MODULES and Ech.module_cap(2, nil) == 2 and Ech.module_cap(2, fresh[1]) == 2,
    "3k. modules finis permis : plafond relevé seulement sous un arriéré échu")
  -- 4. quais
  local q = Ech.fill(120, 1.5, 400, 60, 3200)
  ck(q.fill == 1800 and q.low == 540, "4a. 180 plaques/min : 10 min gardées (1800), relève à 3 min (540), vu " .. q.fill .. "/" .. q.low)
  q = Ech.fill(1, 1, 400, 60, 3200)
  ck(q.fill == 400 and q.low == 60, "4b. petit module : jamais sous les constantes d'avant")
  q = Ech.fill(120, 1.5, 400, 60, 500)
  ck(q.fill == 500 and q.low < q.fill, "4c. le coffre borne le remplissage et le seuil reste dessous")
  -- producteur d'abord
  local projs = {
    { id = 1, state = "reserve", since = 0, missing = { { BELT, 52 } } },
    { id = 2, state = "reserve", since = 0, produces = { [BELT] = true }, missing = { { BELT, 8 }, { GEAR, 3 } } },
    { id = 3, state = "chantier", since = 0, produces = { [BELT] = true }, missing = { { BELT, 100 } } },
    { id = 4, state = "reserve", since = 0, produces = { [PLATE] = true }, missing = { { BELT, 6 } } },
  }
  local held = Ech.held_back(projs, 1 * TM)
  ck(held[BELT] == 8 and held[GEAR] == nil, "4d. retenu : 8 tapis du producteur en réserve (ni le chantier déjà ouvert, ni un autre producteur de tapis manquants)")
  ck(Ech.take_limit(10, 8, false) == 2 and Ech.take_limit(10, 8, true) == 10 and Ech.take_limit(5, 8, false) == 0, "4e. un autre projet laisse la part retenue, le producteur prend tout")
  local late = Ech.held_back(projs, (Ech.GUARD_MAX_MIN + 1) * TM)
  ck(next(late) == nil, "4f. filet : un producteur qui attend depuis plus de " .. Ech.GUARD_MAX_MIN .. " min ne retient plus rien")
  -- 5. simulation tapis
  local b_old, b_new = sim_boot(Ech, "avant"), sim_boot(Ech, "apres")
  ck(b_old >= 15, string.format("5a. témoin, amorçage : %.1f min >= 15 (mesuré : 17 à 19)", b_old))
  ck(b_new <= 3, string.format("5b. amorçage avec le producteur d'abord : %.1f min <= 3", b_new))
  local r_old, w_old = sim_steady(Ech, "avant")
  local r_new, w_new = sim_steady(Ech, "apres")
  ck(r_new >= 0.8, string.format("5c. régime établi, quais à la demande : production %.0f %% >= 80 %% de la demande", r_new * 100))
  ck(w_new <= 3, string.format("5d. régime établi : un chantier de 52 tapis attend %.1f min <= 3", w_new))
  -- (le témoin n'est PAS un critère : ce modèle ne reproduit pas les 9 tapis/min mesurés avec l'ancien quai, le coffre de sortie absorbe les
  -- creux ; il est affiché plus bas pour que personne ne prenne ce modèle pour une preuve de la règle des quais, voir RAPPORT.md §3)
  if verbose then
    print(string.format("   MODELE tapis : amorçage %.1f -> %.1f min ; régime établi : production %.0f%% -> %.0f%%, attente de 52 tapis %.1f -> %.1f min",
      b_old, b_new, r_old * 100, r_new * 100, w_old, w_new))
  end
  -- 6. journal
  local line = Ech.describe(BELT, pt, belt_back)
  ck(type(line) == "string" and line:find("entree", 1, true) and line:find("52", 1, true), "6a. la ligne du journal dit la cause et l'arriéré")
  ck(#Ech.limits() >= 9, "6b. les plafonds sont rendus au journal")
  return fails
end

print("== 1 à 6. Règle et simulation")
battery(dofile("shared/ai3/echelon.lua"), true)

---------------------------------------------------------------------------------------------------
-- 6 bis. Le côté runtime (script/team/echelon.lua) sur une équipe simulée
---------------------------------------------------------------------------------------------------
print("== 6 bis. Runtime (équipe simulée)")
do
  local said = {}
  _G.log = function(s) said[#said + 1] = s end
  _G.settings = { global = { ["fo-war-echelon"] = { value = true } } }
  package.loaded["script.team.echelon"] = nil
  local Ex = require("script.team.echelon")
  local Ech = dofile("shared/ai3/echelon.lua")
  local f = { key = "azure", build = { order = { 1, 2, 3, 4 }, projects = {
    [1] = { id = 1, state = "reserve", started = 0, spec = { product = "smelter" }, missing = { { BELT, 52 } } },
    [2] = { id = 2, state = "reserve", started = 600, spec = { product = BELT }, missing = { { BELT, 8 }, { GEAR, 3 } } },
    [3] = { id = 3, state = "chantier", started = 0, spec = { product = BELT }, missing = { { BELT, 99 } } },
    [4] = { id = 4, state = "reserve", started = 0, spec = {}, missing = {} },
  } } }
  check(Ex.on() == true, "R1. réglage allumé")
  local w = Ex.waiters(f)
  check(#w == 2 and w[1].id == 1 and w[2].id == 2 and w[2].since == 600, "R2. deux chantiers en attente de matière (le chantier ouvert et le projet sans manque sont écartés)")
  local held = Ex.held(f, 1800)
  check(held and held[BELT] == 8 and held[GEAR] == nil, "R3. le producteur retient ses 8 tapis, pas les engrenages qu'il ne fabrique pas")
  check(Ex.limit(held, Ex.produces(f.build.projects[1]), BELT, 10) == 2, "R4. un autre projet laisse la part retenue")
  check(Ex.limit(held, Ex.produces(f.build.projects[2]), BELT, 10) == 10, "R5. le producteur prend tout")
  check(Ex.limit(held, Ex.produces(f.build.projects[1]), "autre", 10) == 10 and Ex.limit(nil, {}, BELT, 10) == 10, "R6. objet non retenu ou rien de retenu : inchangé")
  check(Ex.held(f, (Ech.GUARD_MAX_MIN + 2) * TM + 600) == nil, "R7. filet : passé le délai, plus rien n'est retenu")
  _G.settings.global["fo-war-echelon"].value = false
  check(Ex.on() == false and Ex.held(f, 1800) == nil, "R8. réglage éteint : rien n'est retenu")
  _G.settings = nil
  check(Ex.on() == false, "R9. sans réglage lisible : éteint")
  check(#said >= 1 and said[1]:find("passe d'abord", 1, true), "R9b. Ex.held écrit une ligne quand il retient")
  for n = #said, 1, -1 do said[n] = nil end
  f.build.echelon, f.build.echelon_tick = nil, nil
  Ex.say(f, 7200, "k", "texte")
  Ex.say(f, 7300, "k", "texte")
  Ex.say(f, 7400, "k", "autre")                 -- texte changé mais moins de 5 min après : non dit
  check(#said == 1, "R10. le journal ne répète pas une ligne identique et attend 5 min pour une ligne changée (" .. #said .. ")")
  Ex.say(f, 7200 + Ex.SAY_GAP, "k", "autre")
  check(#said == 2 and said[1]:find("[FO-ECHELON] azure minute 2.0", 1, true), "R11. ligne changée après 5 min : dite (" .. #said .. ")")
  _G.log, _G.settings = nil, nil
end

---------------------------------------------------------------------------------------------------
-- 7. Mutants
---------------------------------------------------------------------------------------------------
print("== 7. Mutants")
local function slurp(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local killed, total = 0, 0
local M = "shared/ai3/echelon.lua"
local function mut(from, to, name)
  total = total + 1
  local src = slurp(M)
  local i, j = src:find(from, 1, true)
  if not i then check(false, "mutant '" .. name .. "' : texte introuvable") return end
  local tmp = os.tmpname()
  local f = assert(io.open(tmp, "wb")) f:write(src:sub(1, i - 1) .. to .. src:sub(j + 1)) f:close()
  local ok, mod = pcall(dofile, tmp)
  os.remove(tmp)
  local n = ok and select(2, pcall(battery, mod, false)) or 1
  if type(n) ~= "number" or n > 0 then killed = killed + 1 else check(false, "mutant survivant : " .. name) end
end
mut("r.rate = r.qty / Ech.CATCHUP_MIN", "r.rate = r.qty", "arriéré : débit sans la durée de rattrapage")
mut("r.due = r.oldest >= Ech.WAIT_MIN * Ech.TICKS_MIN", "r.due = true", "arriéré : jamais échu")
mut("if type(item) == \"string\" and type(n) == \"number\" and n > Ech.EPS then", "if type(item) == \"string\" then", "arriéré : manque nul compté")
mut("if waited > r.oldest then r.oldest = waited end", "", "arriéré : ancienneté oubliée")
mut("if a.qty ~= b.qty then return a.qty > b.qty end", "if a.qty ~= b.qty then return a.qty < b.qty end", "arriéré : ordre inversé")
mut("if r.due then out[#out + 1]", "if true then out[#out + 1]", "sources : arriéré pas échu admis")
mut("local c = s / i.per", "local c = s", "entrée : débit sans le coût par objet")
mut("if c < cap - Ech.EPS or", "if c > cap + Ech.EPS or", "entrée : la plus large borne")
mut("if n > Ech.MAX_LINES then n, capped = Ech.MAX_LINES, true end", "", "lignes : plafond retiré")
mut("local n_target = math.min(n_need, Ech.MAX_COPIES, n_in)", "local n_target = math.min(n_need, n_in)", "machines : plafond retiré")
mut("local n_target = math.min(n_need, Ech.MAX_COPIES, n_in)", "local n_target = math.min(n_need, Ech.MAX_COPIES)", "machines : entrée ignorée")
mut("if n >= Ech.MAX_COPIES then", "if false then", "machines : plafond jamais constaté")
mut("if n * par + Ech.EPS >= target_rate then", "if false then", "machines : ajoute même quand elles suffisent")
mut("local add = math.min(Ech.STEP, n_target - n)", "local add = n_target - n", "machines : tout d'un coup au lieu de N+1")
mut("if st and st.last_add and (inp.tick or 0) - st.last_add < Ech.COOLDOWN_MIN * Ech.TICKS_MIN then", "if false then", "machines : pas de délai")
mut("if st then st.last_add = inp.tick or 0 end", "", "machines : dernier ajout non noté")
mut("made >= Ech.SERVE * target_rate - Ech.EPS", "made >= 2 * target_rate", "machines : servi jamais constaté")
mut("local need = math.max(demand * Ech.LEAD, back)", "local need = demand * Ech.LEAD", "machines : l'arriéré ne compte pas")
mut("local back = inp.backlog and inp.backlog.due and inp.backlog.rate or 0", "local back = inp.backlog and inp.backlog.rate or 0", "machines : arriéré pas échu compté")
mut("if backlog and backlog.due then return math.max(base or 0, Ech.MAX_MODULES) end", "return math.max(base or 0, Ech.MAX_MODULES)", "modules : plafond relevé sans arriéré")
mut("local fill = math.max(base_fill or 0, math.ceil(flow * Ech.FILL_MIN - Ech.EPS))", "local fill = base_fill or 0", "quai : remplissage constant")
mut("local low = math.max(base_low or 0, math.ceil(flow * Ech.LOW_MIN - Ech.EPS))", "local low = base_low or 0", "quai : seuil constant")
mut("if fill > cap then fill = cap end", "", "quai : coffre ignoré")
mut("if p.produces[m[1]] and type(m[2]) == \"number\" and m[2] > 0 then", "if type(m[2]) == \"number\" and m[2] > 0 then", "producteur : tout manque retenu")
mut("if p.state == \"reserve\" and p.produces then", "if p.produces then", "producteur : projet hors réserve retenu")
mut("if waited <= Ech.GUARD_MAX_MIN * Ech.TICKS_MIN then", "if true then", "producteur : filet retiré")
mut("if is_producer then return free end", "", "producteur : pas prioritaire")
mut("return math.max(0, free - math.max(0, held or 0))", "return free", "producteur : rien n'est laissé")
print(string.format("   mutants refusés : %d / %d", killed, total))
check(killed == total, "tous les mutants refusés")
print(string.format("[ECHELON] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, total))
os.exit(failures == 0 and 0 or 1)
