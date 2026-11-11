--[[
  Lot C2 « DEMANDE OUVERTE » : banc HORS JEU du puits ouvert (shared/ai3/demande.lua) et de ses branchements : capitalisation
  (Ca.decide : puits, coût d'opportunité nul, Tmax), saturation (B.saturated), décision de l'automatisation (A.decide : débit voulu,
  seuil du tapis par le coût réel), emplacements et capacités. Lancement, depuis la racine du mod : lua5.2 tests/demande_test.lua
    1. lecture des données : candidats du puits (science, équipement), aucun nom d'objet dans la règle ;
    2. le sommeil du stock (2 fois le besoin évalué) ;
    3. le puits : croît tant que le stock dort, plafonné par le stock libre et par la production, décroît sinon, classes, arbre fini ;
    4. la capitalisation : à stock dormant des ordres s'ouvrent, sans puits (réglage éteint, menace, besoin non évalué) rien ne change ;
    5. coût d'opportunité nul et Tmax qui croît avec le sommeil ;
    6. saturation relative au puits ;
    7. décision sur le débit voulu et seuil du tapis par le coût réel ;
    8. emplacements et capacités selon les bras libres ;
    9. déterminisme ; état sans fonction ;
   10. mutants : chaque règle retirée fait échouer au moins un contrôle.
  Ce fichier est du TEST : il nomme les prototypes vanilla (comme le moteur) ; la règle n'en voit rien.
]]
package.path = "./?.lua;" .. package.path
local F = require("tests.iag_fixture")
local Book = require("shared.team.book")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end

local function sorted_keys(t) local ks = {} for k in pairs(t or {}) do ks[#ks + 1] = k end table.sort(ks) return ks end
local function slurp(p) local f = assert(io.open(p, "rb")) local x = f:read("*a") f:close() return x end

-- Les modules sous test : rechargés à neuf (les mutants remplacent un fichier ; les dépendants le voient par package.loaded).
local PATHS = { Dm = "shared/ai3/demande.lua", Ca = "shared/ai3/capitalisation.lua", B = "shared/ai3/buts.lua",
  A = "shared/ai3/automatiser.lua" }
local LOADED = { Dm = "shared.ai3.demande", Ca = "shared.ai3.capitalisation", B = "shared.ai3.buts", A = "shared.ai3.automatiser" }
local ORDER = { "Dm", "Ca", "B", "A" }
local function load_source(path, mutate)
  local src = slurp(path)
  if mutate then
    local i, j = src:find(mutate[1], 1, true)
    if not i then return nil, "texte introuvable : " .. mutate[1] end
    src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  end
  local fn, err = load(src, "@" .. path)
  if not fn then return nil, err end
  return fn()
end
local function build(which, mutate)
  local saved = {}
  for _, k in ipairs(ORDER) do saved[k] = package.loaded[LOADED[k]] end
  local mods, err = {}, nil
  for _, k in ipairs(ORDER) do
    local m, e = load_source(PATHS[k], (k == which) and mutate or nil)
    if not m then err = e break end
    mods[k] = m
    package.loaded[LOADED[k]] = m
  end
  for _, k in ipairs(ORDER) do package.loaded[LOADED[k]] = saved[k] end
  return mods, err
end

-- Relevé vanilla réaliste (vitesses de data/base 1.1.91) : copie réduite de tests/reserve_test.lua.
local V_SPEED = { ["stone-furnace"] = 1, ["steel-furnace"] = 2, ["electric-furnace"] = 2, ["assembling-machine-1"] = 0.5,
  ["assembling-machine-2"] = 0.75, ["assembling-machine-3"] = 1.25, ["burner-mining-drill"] = 0.25,
  ["electric-mining-drill"] = 0.5, ["pumpjack"] = 1, ["lab"] = 1, ["chemical-plant"] = 1, ["oil-refinery"] = 1, ["centrifuge"] = 1 }
local EXEC = { ["stone-furnace"] = true, ["steel-furnace"] = true, ["burner-mining-drill"] = true,
  ["electric-mining-drill"] = true, ["assembling-machine-1"] = true, ["assembling-machine-2"] = true }
local function vanilla_dump()
  local d = F.dump()
  for _, e in ipairs(d.entities) do
    if V_SPEED[e.name] then e.speed = V_SPEED[e.name] end
    e.size = 3
    e.mining_area = e.name == "electric-mining-drill" and 5 or nil
  end
  for _, k in ipairs(sorted_keys(d.techs)) do
    for _, r in ipairs(d.techs[k].unlocks) do if d.recipes[r] then d.recipes[r].enabled = false end end
  end
  for _, r in ipairs(d.resources) do r.mining_time = 1 end
  return d
end

local STOCK = { ["iron-plate"] = 24700, ["copper-plate"] = 8000, ["electronic-circuit"] = 2000, ["iron-gear-wheel"] = 3000, stone = 500 }
local function scene(D, over)
  local inp = { data = D, state = { techs = { automation = true } }, stock = STOCK, flows = { ["iron-plate"] = { made = 100 } },
    machines = { { entity = "assembling-machine-1", recipe = "iron-gear-wheel", n = 2, where = "qg" } },
    drills = {}, labs = {}, deposits = {}, open = {}, sinks = {}, workers = 30, idle = 10, can_grow = true, traits = {}, weights = {},
    reserve = { free = STOCK }, demande = true }
  for k, v in pairs(over or {}) do inp[k] = v end
  return inp
end

local function run_all(M)
  local Dm, Ca, B, A = M.Dm, M.Ca, M.B, M.A
  local D = Ca.data(vanilla_dump(), { exec = EXEC, exec_roles = { main = true, labo = true } })
  local ok_all = function() return true end

  -------------------------------------------------------------------------------------------------
  section("1. Lecture des données")
  -------------------------------------------------------------------------------------------------
  do
    local c = Dm.candidates(D, ok_all)
    check(#c.science >= 1, "des objets de science sont lus dans les entrées des laboratoires (" .. #c.science .. ")")
    check(#c.equipement >= 1 and #c.equipement <= Dm.EQUIP_MAX, "des biens d'équipement, au plus " .. Dm.EQUIP_MAX .. " (" .. #c.equipement .. ")")
    for i = 2, #c.equipement do
      check(c.equipement[i - 1].mu >= c.equipement[i].mu, "équipement trié par valeur décroissante")
    end
    -- intégration 0.6.32 : un bien qu'aucun exécutant ne pose n'est pas candidat, même le plus cher
    do
      local top = c.equipement[1]
      local machine
      for _, list in ipairs({ D.makers, D.drills, D.labs }) do
        for _, m in ipairs(list) do if m.item == top.item and not machine then machine = m end end
      end
      local saved = machine.exec
      machine.exec = false
      local c3 = Dm.candidates(D, ok_all)
      machine.exec = saved
      local still = false
      for _, e in ipairs(c3.equipement) do if e.item == top.item then still = true end end
      check(not still, "un bien qu'aucun exécutant ne pose n'est pas candidat (" .. top.item .. ")")
    end
    local c2 = Dm.candidates(D, function(i) return i ~= c.equipement[1].item end)
    local found = false
    for _, e in ipairs(c2.equipement) do if e.item == c.equipement[1].item then found = true end end
    check(not found, "un bien que l'équipe ne sait pas obtenir n'est pas candidat")
    local none = Dm.candidates(D, function() return false end)
    check(#none.science == 0 and #none.equipement == 0, "rien d'obtenable : aucun candidat")
    check(#Dm.candidates(nil, ok_all).science == 0, "pas de données : aucun candidat, pas d'erreur")
    -- anti-échelle : la règle ne nomme aucun objet du jeu
    local src = slurp(PATHS.Dm)
    local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
    local literals = {}
    for lit in code:gmatch('"([^"]*)"') do literals[#literals + 1] = lit end
    for _, name in ipairs({ "iron", "copper", "gear", "circuit", "assembling", "mining", "inserter", "coal", "stone", "transport" }) do
      local hit = false
      for _, lit in ipairs(literals) do if lit:find(name, 1, true) then hit = true end end
      check(not hit, "demande.lua ne nomme pas '" .. name .. "' dans une chaîne")
    end
  end

  -------------------------------------------------------------------------------------------------
  section("2. Le sommeil du stock")
  -------------------------------------------------------------------------------------------------
  do
    check(Dm.dormant(2001, 1000), "stock 2001 contre un besoin de 1000 : dort (au-delà de 2 fois)")
    check(not Dm.dormant(2000, 1000), "stock égal à 2 fois le besoin : ne dort pas")
    check(not Dm.dormant(1500, 1000), "stock 1,5 fois le besoin : ne dort pas")
    check(Dm.dormant(10, 0), "besoin nul : le plancher du besoin évite la division par zéro, un stock non nul dort")
    check(not Dm.dormant(0, 0), "rien au stock : ne dort pas")
    -- Lot BLOCAGE-SORTIE-2 : Dm.sleeping, lecture hors décision (mêmes MU que l'entrée de Dm.step)
    local RD = { mu = { a = 2, b = 1, m = 5, x = 9 }, convertible = { a = true, b = true, m = true }, mil = { m = true } }
    local dort, smu, fmu = Dm.sleeping(RD, { a = 1000, b = 100, m = 50, x = 40 }, { a = 900, b = 0, m = 50, x = 40 })
    check(dort and smu == 2100 and fmu == 1800, "sleeping : MU du stock 2 100 (a, b ; ni militaire ni non convertible), libres 1 800, dort")
    dort = Dm.sleeping(RD, { a = 1000 }, { a = 600 })
    check(dort == true, "sleeping : stock 2 000 contre un besoin de 800 : dort (2 000 > 1 600)")
    dort = Dm.sleeping(RD, { a = 1000 }, { a = 400 })
    check(dort == false, "sleeping : stock 2 000, besoin 1 200 : ne dort pas")
    check(Dm.sleeping(RD, { a = 1000 }, { a = 0 }) == false, "sleeping : rien de libre : ne dort pas")
    check(Dm.sleeping(RD, nil, {}) == false and Dm.sleeping(RD, {}, nil) == false and Dm.sleeping(nil, {}, {}) == false,
      "sleeping : entrée absente : ne dort pas (garde fermée)")
    -- Lot BLOCAGE-SORTIE-2 : Dm.closed_cause, une cause DISTINCTE par branche (avant : une phrase pour trois causes)
    local OPEN = { on = true, off = false, threat = false, reserve = true }
    local function cause(over) local c = {} for k, v in pairs(OPEN) do c[k] = v end for k, v in pairs(over or {}) do c[k] = v end return Dm.closed_cause(c) end
    local k1, t1 = cause({ on = false })
    local k2, t2 = cause({ off = true })
    local k3, t3 = cause({ threat = true, threat_why = "menace tenue (view.threat_held)" })
    local k4, t4 = cause({ reserve = false })
    local k5, t5 = cause({ palier_why = "palier (fo-war-paliers) : instable, 1 manque(s)" })
    local k6, t6 = cause({})
    check(k1 == "maitre" and k2 == "banc" and k3 == "menace" and k4 == "besoin" and k5 == "palier" and k6 == "inconnu", "closed_cause : six clés distinctes")
    check(t3:find("view.threat_held", 1, true) and t5:find("instable", 1, true) and t1 ~= t2 and t2 ~= t3 and t3 ~= t4 and t4 ~= t5, "closed_cause : textes distincts, origine et raison reprises")
    -- ordre de la décision : le maître passe avant la menace, la menace avant le besoin, le besoin avant le palier
    check(cause({ on = false, threat = true, reserve = false, palier_why = "x" }) == "maitre", "closed_cause : maître d'abord")
    check(cause({ threat = true, reserve = false, palier_why = "x" }) == "menace", "closed_cause : menace avant besoin")
    check(cause({ reserve = false, palier_why = "x" }) == "besoin", "closed_cause : besoin avant palier")
    check(cause({ off = true, threat = true }) == "banc", "closed_cause : le banc avant la menace")
    -- la partie du DC (journal) : maître allumé, pas de menace, besoin évalué, palier de la vidéo qui ferme -> "palier", jamais "maitre/menace/besoin"
    check(Dm.closed_cause({ on = true, threat = false, reserve = true, palier_why = "palier (fo-war-paliers) : instable, 1 manque(s)" }) == "palier", "DC : le palier ferme le puits")
    local d5, _, f5 = Dm.sleeping(RD, { a = 1000 }, { a = 5000 })
    check(d5 == true and f5 == 2000, "sleeping : le libre ne dépasse jamais le stock (2 000 MU)")
  end

  -------------------------------------------------------------------------------------------------
  section("3. Le puits")
  -------------------------------------------------------------------------------------------------
  do
    local c = Dm.candidates(D, ok_all)
    local st = Dm.new()
    local inp = { stock_mu = 60000, free_mu = 60000, Y = 500, cands = c, research = true }
    local o1 = Dm.step(st, inp)
    check(o1.dormant and o1.p > 0, "stock dormant : un débit visé est ouvert (" .. string.format("%.1f", o1.p) .. " MU/min)")
    check(#o1.sinks >= 2 and o1.sinks[1].elastic == true and o1.sinks[1].rate > 0, "des puits élastiques d'objets, débit positif")
    local classes = {}
    for _, s in ipairs(o1.sinks) do classes[s.class] = (classes[s.class] or 0) + s.rate * (function() for _, x in ipairs(c[s.class]) do if x.item == s.item then return x.mu end end end)() end
    check(classes.science and classes.equipement and math.abs(classes.science - classes.equipement) < 1e-6,
      "part égale en MU entre science et équipement")
    local prev = o1.p
    local grew = true
    for _ = 1, 10 do
      local o = Dm.step(st, inp)
      if o.p < prev - 1e-9 then grew = false end
      prev = o.p
    end
    check(grew and prev > o1.p, "tant que le stock dort, le débit visé ne baisse jamais et croît")
    -- plafond : stock libre / DRAIN_H, ou DM.Y_MULT x production
    for _ = 1, 200 do Dm.step(st, inp) end
    local cap = math.min(60000 / Dm.DRAIN_H, Dm.Y_MULT * 500)
    check(math.abs(st.p - cap) < 1e-6, "plafonné (" .. string.format("%.1f vs %.1f", st.p, cap) .. ")")
    local st2 = Dm.new()
    local lowprod = { stock_mu = 60000, free_mu = 60000, Y = 20, cands = c, research = true }
    for _ = 1, 200 do Dm.step(st2, lowprod) end
    check(math.abs(st2.p - Dm.Y_MULT * 20) < 1e-6, "plafond de la production : " .. Dm.Y_MULT .. " fois la production mesurée, qui monte avec elle")
    local st3 = Dm.new()
    local lowstock = { stock_mu = 7000, free_mu = 4000, Y = 5000, cands = c, research = true }
    for _ = 1, 200 do Dm.step(st3, lowstock) end
    check(math.abs(st3.p - 4000 / Dm.DRAIN_H) < 1e-6, "plafond du stock libre : il doit nourrir le débit " .. Dm.DRAIN_H .. " min")
    -- le stock ne dort plus : décroît
    local awake = { stock_mu = 1500, free_mu = 500, Y = 500, cands = c, research = true }
    local o = Dm.step(st, awake)
    check(not o.dormant and o.p == 0, "stock éveillé : puits fermé net (lot FIX-P1)")
    for _ = 1, 400 do o = Dm.step(st, awake) end
    check(o.p == 0 and #o.sinks == 0, "stock éveillé longtemps : puits fermé, plus aucun puits")
    check(o.cause:find("ferme", 1, true) ~= nil, "cause écrite : puits fermé")
    -- arbre fini : tout va à l'équipement, cause écrite
    local st4 = Dm.new()
    local fin = Dm.step(st4, { stock_mu = 60000, free_mu = 60000, Y = 500, cands = c, research = false })
    local only_equip = #fin.sinks > 0
    for _, s in ipairs(fin.sinks) do if s.class ~= "equipement" then only_equip = false end end
    check(only_equip, "sans technologie restante : tout le débit va à l'équipement")
    check(fin.cause:find("formule", 1, true) ~= nil, "cause : suite = technologies à formule et matières nouvelles")
    -- aucune destination
    local st5 = Dm.new()
    local nod = Dm.step(st5, { stock_mu = 60000, free_mu = 60000, Y = 500, cands = { science = {}, equipement = {} }, research = true })
    check(#nod.sinks == 0 and nod.cause:find("aucune destination", 1, true) ~= nil, "aucune destination : cause écrite, aucun puits")
    -- stock dormant mais rien de libre
    local st6 = Dm.new()
    local nf = Dm.step(st6, { stock_mu = 60000, free_mu = 0, Y = 500, cands = c, research = true })
    check(not nf.dormant and #nf.sinks == 0, "tout le stock est du besoin (rien de libre) : le puits ne s'ouvre pas")
  end

  -------------------------------------------------------------------------------------------------
  section("4. La capitalisation")
  -------------------------------------------------------------------------------------------------
  do
    local st = {}
    local without = Ca.decide(scene(D, { demande = false }), {})
    check(#without.orders == 0, "sans puits : aucun ordre à stock dormant (la mesure d'Emerald)")
    check(without.demande == nil, "sans puits : pas de compte rendu du puits")
    local res
    for _ = 1, 3 do res = Ca.decide(scene(D), st) end
    check(#res.orders >= 1, "avec le puits : des ordres s'ouvrent à stock dormant (" .. #res.orders .. ")")
    check(res.demande and res.demande.dormant and res.demande.p > 0, "compte rendu du puits : dormant, débit visé > 0")
    local seen = {}
    for _, o in ipairs(res.orders) do seen[o.item or ""] = true end
    local sink_item = res.demande.sinks[1].item
    check((res.R[sink_item] or 0) > 0, "le puits est une demande : son objet entre dans le besoin (R)")
    local inp_t = scene(D, { threat = true })
    inp_t.reserve = nil
    local thr = Ca.decide(inp_t, {})
    check(thr.demande == nil, "sous menace (pas de besoin évalué) : le puits ne s'ouvre pas")
    local inp_n = scene(D)
    inp_n.reserve = nil
    local nor = Ca.decide(inp_n, {})
    check(nor.demande == nil, "besoin non évalué : le puits ne s'ouvre pas")
    check(#nor.orders == 0, "besoin non évalué : la règle d'avant, ligne pour ligne")
    -- le noyau d'I1 est intouché : une matière prise par le besoin n'alimente pas le puits
    local taken = Ca.decide(scene(D, { reserve = { free = {}, zero = { ["iron-plate"] = true } } }), {})
    check(taken.demande and not taken.demande.dormant and #taken.orders == 0, "le besoin prend tout le stock : le puits reste fermé, aucun ordre")
    -- le budget borne la dépense : jamais plus que le stock libre
    check(res.spent <= res.budget + 1e-6, "la dépense ne dépasse pas le budget")
    -- le puits ne fabrique pas à l'infini : il croît d'un cycle à l'autre
    local st2, p1, p2 = {}, nil, nil
    Ca.decide(scene(D), st2); p1 = st2.dm.p
    for _ = 1, 5 do Ca.decide(scene(D), st2) end
    p2 = st2.dm.p
    check(p2 > p1, "le débit visé croît d'un cycle à l'autre tant que le stock dort")
  end

  -------------------------------------------------------------------------------------------------
  section("5. Coût d'opportunité nul et Tmax")
  -------------------------------------------------------------------------------------------------
  do
    check(Dm.tmax(20, 0) == 20, "stock éveillé : Tmax inchangé")
    check(Dm.tmax(20, 80) == 80, "stock qui dormirait 80 min : Tmax 80")
    check(Dm.tmax(20, 5) == 20, "jamais sous le Tmax du caractère")
    check(Dm.tmax(20, 9999) == Dm.TMAX_CAP, "jamais au-delà de " .. Dm.TMAX_CAP .. " min")
    -- intégration 0.6.32 : au-dessus du seuil ne suffit pas, le stock dort après Dm.SLEEP_CYCLES décisions de suite
    do
      local N = Dm.SLEEP_CYCLES
      check(N >= 2, "un stock ne dort jamais à la 1re décision (" .. N .. ")")
      local st_s = {}
      local function dec(over)
        local o = { demande_sleep = N }
        for k, v in pairs(over or {}) do o[k] = v end
        return Ca.decide(scene(D, o), st_s)
      end
      for i = 1, N - 1 do
        local r = dec()
        check(r.demande.p == 0 and not r.demande.dormant and (r.demande.left or 0) == 0, "décision " .. i .. " : le puits reste fermé, aucune remise")
        for _, o in ipairs(r.orders) do check(not o.dormant_mu or o.dormant_mu == 0, "décision " .. i .. " : ordre sans remise") end
      end
      local r3 = dec()
      check(r3.demande.dormant and r3.demande.p > 0, "décision " .. N .. " : le stock dort, le puits s'ouvre")
      local st_b = {}
      Ca.decide(scene(D, { demande_sleep = N }), st_b)
      Ca.decide(scene(D, { demande_sleep = N, reserve = { free = {}, zero = { ["iron-plate"] = true } } }), st_b)
      check(st_b.dm.dormant_cycles == 0, "le stock repasse sous le seuil : le compte repart de zéro")
    end
    local res = Ca.decide(scene(D), {})
    local n_orders = #res.orders
    -- sans la remise du coût d'opportunité : des options sont refusées pour leur retour
    local with_disc, no_disc = 0, 0
    for _, o in ipairs(res.orders) do if (o.dormant_mu or 0) > 0 then with_disc = with_disc + 1 end end
    check(with_disc >= 1, "au moins un ordre a une part de ses matières payée par le stock qui dort (" .. with_disc .. ")")
    local sum = 0
    for _, o in ipairs(res.orders) do sum = sum + (o.dormant_mu or 0) end
    check(sum <= res.demande.left0 + 1e-6, "la remise totale ne dépasse jamais le stock qui dort (" .. string.format("%.0f", sum) .. ")")
    check(n_orders >= 1, "des ordres passent")
    -- le stock qui dort est limité : un stock libre à peine au-dessus du besoin ne remise que sa part, ordre après ordre
    -- (on cherche la finesse du stock libre où les ordres coûtent plus que le stock qui dort : la scène est déterministe)
    local r2, sum2, cost2
    for i = 1, 40 do
      local frac = 0.5000 + i * 0.00005
      local free = {}
      for k, v in pairs(STOCK) do free[k] = math.floor(v * frac) end
      local st2 = {}
      for _ = 1, 3 do r2 = Ca.decide(scene(D, { reserve = { free = free } }), st2) end
      sum2, cost2 = 0, 0
      for _, o in ipairs(r2.orders) do sum2 = sum2 + (o.dormant_mu or 0) cost2 = cost2 + o.cost_m end
      if #r2.orders >= 2 and r2.demande.left0 < cost2 then break end
    end
    check(r2.demande.dormant and r2.demande.left0 > 0 and r2.demande.left0 < cost2, "scène à stock dormant étroit : il dort peu (" .. string.format("%.0f", r2.demande.left0) .. " MU) et les ordres coûtent plus (" .. string.format("%.0f", cost2) .. ")")
    check(sum2 <= r2.demande.left0 + 1e-6 and math.abs(sum2 + r2.demande.left - r2.demande.left0) < 1e-6, "la remise totale ne dépasse pas le stock qui dort et l'entame d'autant (" .. string.format("%.1f <= %.1f", sum2, r2.demande.left0) .. ")")
    check(sum2 > 0, "et il est bien entamé")
    -- Tmax : un retour de 100 min passe quand le stock dormirait 80 min de plus que le caractère, sinon il est refusé
    local function opt() return { key = "k", kind = "chaine", item = "x", cost_m = 1000, work = 0, gain = 10 } end
    local base_ctx = { ch = { tmax = 20 }, lambda = 0, refus = {}, threat = false, input = {} }
    check(Ca.H.finish(base_ctx, opt()) == nil, "retour 100 min > Tmax 20 : refusé sans stock qui dort")
    local sleepy = { ch = { tmax = 20 }, lambda = 0, refus = {}, threat = false, input = {}, dm = { tmax_sleep = 120, left = 0 } }
    check(Ca.H.finish(sleepy, opt()) ~= nil, "retour 100 min <= 120 min de sommeil : accepté")
    local disc = { ch = { tmax = 20 }, lambda = 0, refus = {}, threat = false, input = {}, dm = { tmax_sleep = 0, left = 950 } }
    local od = Ca.H.finish(disc, opt())
    check(od ~= nil and od.dormant_mu == 950 and od.cost == 50 and od.T == 5, "950 MU de stock qui dort remisés du coût : retour 5 min")
  end

  -------------------------------------------------------------------------------------------------
  section("6. Saturation relative au puits")
  -------------------------------------------------------------------------------------------------
  do
    check(Dm.sat_need(100, 40, nil) == 100, "sans puits : le plancher")
    check(Dm.sat_need(100, 400, nil) == 400, "le besoin des buts dépasse le plancher")
    check(Dm.sat_need(100, 40, 50) == 50 * Dm.SAT_H, "avec le puits : le débit du puits sur " .. Dm.SAT_H .. " min")
    local s = { workers = 8, stock = { ["iron-plate"] = 24700 }, need = {}, cap = {}, pending = {} }
    check(B.saturated(s, "iron-plate"), "sans puits : 24 700 fer sont saturés contre le plancher (3 x 100)")
    s.puits_flow = { ["iron-plate"] = 2000 }
    check(not B.saturated(s, "iron-plate"), "avec un puits à 2 000/min : 24 700 fer ne sont plus saturés (3 x 20 000)")
    check(B.saturated(s, "iron-plate", true), "contre le plancher seul : toujours saturé (pour le journal)")
    s.puits_flow = { ["iron-plate"] = 2000, copper = 1 }
    s.stock["iron-plate"] = 70000
    check(B.saturated(s, "iron-plate"), "le stock dépasse 3 fois le débit du puits : saturé")
    s.puits_flow = { ["copper-plate"] = 100 }
    check(B.saturated(s, "iron-plate"), "un puits qui ne demande pas la matière ne la tient pas ouverte")
  end

  -------------------------------------------------------------------------------------------------
  section("7. Débit voulu et seuil du tapis")
  -------------------------------------------------------------------------------------------------
  do
    local L, Dd, ch = Dm.load(0.12, 10, 40)
    check(ch and math.abs(L - 0.48) < 1e-9 and Dd == 40, "charge 0,12 PNJ à 10/min : 0,48 PNJ au débit voulu de 40/min")
    local L2, D2, ch2 = Dm.load(0.12, 10, 5)
    check(not ch2 and L2 == 0.12 and D2 == 10, "débit voulu sous le mesuré : rien ne change")
    local L3, _, ch3 = Dm.load(0, 0, 40)
    check(not ch3 and L3 == 0, "aucun débit mesuré : la charge par objet est inconnue, rien ne change")
    local L4, _, ch4 = Dm.load(0.12, 10, nil)
    check(not ch4 and L4 == 0.12, "pas de débit voulu : rien ne change")
    -- A.decide : un objet qui chargeait 0,167 PNJ à 60/min
    local recipes = dofile("tests/fixtures/recipes.lua")
    local book = Book.new(recipes)
    local function win(n, loads, mades)
      local w = {}
      for i = 1, n do
        local b = { m = i, load = {}, made = {}, logi = {} }
        for k, v in pairs(loads) do b.load[k] = v end
        for k, v in pairs(mades) do b.made[k] = v end
        w[i] = b
      end
      return w
    end
    local w = win(10, { ["iron-plate"] = 600 }, { ["iron-plate"] = 60 })
    local r0 = A.decide({ window = w, obtainable = ok_all, book = book })
    local v0
    for _, v in ipairs(r0.verdicts) do if v.product == "iron-plate" then v0 = v end end
    check(v0 and v0.verdict == "non" and v0.why:find("charge", 1, true) ~= nil, "charge 0,17 PNJ : non, comme avant")
    local r1 = A.decide({ window = w, obtainable = ok_all, book = book, wanted = { ["iron-plate"] = 240 } })
    local v1
    for _, v in ipairs(r1.verdicts) do if v.product == "iron-plate" then v1 = v end end
    check(v1 and not (v1.verdict == "non" and v1.why:find("charge", 1, true)), "débit voulu 240/min : la charge mise à l'échelle (0,67 PNJ) passe le seuil de 0,25")
    check(#r1.demande >= 1 and r1.demande[1].item == "iron-plate" and r1.demande[1].D == 240, "le compte rendu dit l'échelle")
    check(v1 and v1.D == 240, "le verdict porte le débit voulu")
    -- seuil du tapis
    check(Dm.belt_flow(200, 1, 20, 1.0) == 200 / (60 * 1 * 20), "seuil = coût / (60 x porteur x retour)")
    check(Dm.belt_flow(1e9, 1, 20, 1.0) == 1.0, "jamais plus strict que l'ancien seuil constant")
    check(Dm.belt_flow(nil, 1, 20, 1.0) == 1.0 and Dm.belt_flow(0, 1, 20, 1.0) == 1.0, "coût inconnu : l'ancien seuil")
    local thr = A.belt_flow({ book = book, stock = {} }, 20)
    check(type(thr) == "number" and thr > 0 and thr < A.BELT_FLOW, "coût réel lu au livre : seuil sous 1 minerai/s (" .. tostring(thr) .. ")")
    check(thr < 0.63, "le cuivre à 0,63/s passe le tapis (152 refus mesurés à Emerald)")
    local thr_fast = A.belt_flow({ book = book, stock = {} }, 5)
    check(thr_fast > thr, "un retour accepté plus court exige un flux plus grand")
    check(A.belt_flow({ book = nil }, 20) == A.BELT_FLOW, "sans livre : l'ancien seuil")
    check(r0.belt_flow == nil and r1.belt_flow == nil, "réglage éteint : A.decide n'écrit pas de seuil")
    local r2 = A.decide({ window = w, obtainable = ok_all, book = book, demande = true })
    check(type(r2.belt_flow) == "number" and r2.belt_flow < A.BELT_FLOW, "réglage allumé : A.decide écrit le seuil du coût réel (" .. tostring(r2.belt_flow) .. ")")
    -- le seuil change ce que le module pose : à 0,625 minerai/s, des foreuses et du tapis sous le seuil réel, un quai sous l'ancien
    for _, m in ipairs(A.METHODS) do
      if m.ore then
        local g = A.sized(m, 20)
        local _, items_old = A.cost(m, g, { belt_flow = A.BELT_FLOW })
        local _, items_new = A.cost(m, g, { belt_flow = thr })
        local n_old, n_new = 0, 0
        for _, v in pairs(items_old) do n_old = n_old + v end
        for _, v in pairs(items_new) do n_new = n_new + v end
        check(g.inputs[m.ore] < A.BELT_FLOW and g.inputs[m.ore] >= thr and n_new > n_old, "à " .. string.format("%.3f", g.inputs[m.ore]) .. " minerai/s : foreuses et tapis au seuil réel (" .. n_new .. " pièces), quai sous l'ancien (" .. n_old .. ")")
        break
      end
    end
  end

  -------------------------------------------------------------------------------------------------
  section("8. Emplacements et capacités")
  -------------------------------------------------------------------------------------------------
  do
    -- intégration 0.6.32 : les ordres retenus sont lus comme Ca.options les écrit, avec son préfixe (le texte vient de la vraie règle)
    local busy = require("shared.ai3.emplacements").busy_text({ why = "2 module(s) ouvert(s)" })
    check(Dm.count_blocked({ { why = "executant : " .. busy }, { why = busy }, { why = "retour 9 min > 3" }, {} }) == 2, "ordres retenus : préfixe de l'exécutant compris")
    check(Dm.blocked_next(nil, 3) == 3 and Dm.blocked_next(3, 0) == 2 and Dm.blocked_next(1, 0) == 0 and Dm.blocked_next(0, 0) == 0, "un emplacement gagné se perd d'un cran par décision")
    check(Dm.blocked_next(2, 5) == 5, "de nouveaux ordres retenus l'emportent")
    check(Dm.slots(2, false, 12, 5) == 2, "puits fermé : la base")
    check(Dm.slots(2, true, 12, 0) == 2, "aucun ordre retenu : la base")
    check(Dm.slots(2, true, 12, 1) == 3, "un ordre retenu, 12 bras libres : un emplacement de plus")
    check(Dm.slots(2, true, 4, 9) == 4, "9 ordres retenus mais 4 bras libres : 2 emplacements de plus (jamais plus que les bras n'en occupent)")
    check(Dm.slots(2, true, 1, 9) == 2, "un seul bras libre : pas de chantier neuf")
    check(Dm.slots(2, true, 100, 100) == Dm.SLOTS_HARD, "plafond de sûreté " .. Dm.SLOTS_HARD)
    check(Dm.slots(10, true, 100, 100) == 10, "jamais sous la base, même au-dessus du plafond")
    check(Dm.extra_cap(false, 30) == 0, "puits fermé : aucune capacité de plus")
    check(Dm.extra_cap(true, 7) == 2, "7 bras libres : 2 capacités de plus")
    check(Dm.extra_cap(true, 300) == Dm.CAP_EXTRA_MAX, "au plus " .. Dm.CAP_EXTRA_MAX)
    local Br = require("shared.ai3.bras")
    check(Br.cap_max(30, 5, 0) == Br.cap_max(30, 5) and Br.cap_max(30, 5, 2) == Br.cap_max(30, 5) + 2, "Br.cap_max ajoute les capacités de plus")
    check(Br.labs_max(30, 3, 2) == Br.labs_max(30, 3) + 2 and Br.smelt_max(30, 4, 3) == Br.smelt_max(30, 4) + 3, "labos et fours aussi")
  end

  -------------------------------------------------------------------------------------------------
  section("9. Déterminisme et état")
  -------------------------------------------------------------------------------------------------
  do
    local function sig()
      local st = {}
      local res
      for _ = 1, 6 do res = Ca.decide(scene(D), st) end
      local ks = {}
      for _, o in ipairs(res.orders) do ks[#ks + 1] = o.key .. ":" .. o.n end
      return table.concat(ks, ",") .. "|" .. string.format("%.9f", st.dm.p) .. "|" .. res.demande.cause, st
    end
    local a, st = sig()
    local b = sig()
    check(a == b, "deux passages identiques : mêmes ordres, même débit visé, même cause")
    local function plain(t, depth)
      if depth > 6 then return false end
      for _, v in pairs(t) do
        if type(v) == "function" or type(v) == "userdata" then return false end
        if type(v) == "table" and not plain(v, depth + 1) then return false end
      end
      return true
    end
    check(plain(st.dm, 0), "l'état du puits ne garde que des nombres et des tables")
  end
end

local function suite(M, label)
  local p0, f0 = passes, failures
  run_all(M)
  return passes - p0, failures - f0
end

local base = build(nil, nil)
suite(base, "base")

---------------------------------------------------------------------------------------------------
section("10. Mutants")
---------------------------------------------------------------------------------------------------
local MUTANTS = {
  { "Dm", "un stock dort dès la 1re décision", { "local waiting = dormant and st.dormant_cycles < (inp.sleep or 0)", "local waiting = false" } },
  { "Dm", "le compte du sommeil ne repart pas de zéro", { "st.dormant_cycles = dormant and st.dormant_cycles + 1 or 0", "st.dormant_cycles = st.dormant_cycles + (dormant and 1 or 0)" } },
  { "Ca", "la capitalisation ne transmet pas le sommeil", { "Y = Y, sleep = input.demande_sleep,", "Y = Y," } },
  { "Dm", "un bien sans exécutant redevient candidat", { "if i and m.exec ~= false and not seen[i]", "if i and not seen[i]" } },
  { "Dm", "les ordres retenus ne sont lus qu'au début du texte", { "if tostring(r.why):find(Dm.BUSY_TEXT, 1, true) then", "if tostring(r.why):sub(1, #Dm.BUSY_TEXT) == Dm.BUSY_TEXT then" } },
  { "Dm", "un emplacement gagné se perd d'un coup", { "return math.max(blocked or 0, (prev or 0) - 1)", "return blocked or 0" } },
  { "Dm", "stock > 2 fois le besoin devient 1 fois", { "Dm.DORM_FACTOR = 2 ", "Dm.DORM_FACTOR = 0 " } },
  { "Dm", "sleeping : les militaires comptent", { "if m and D.convertible and D.convertible[k] and not (D.mil and D.mil[k]) then", "if m and D.convertible and D.convertible[k] then" } },
  { "Dm", "sleeping : le non convertible compte", { "if m and D.convertible and D.convertible[k] and not (D.mil and D.mil[k]) then", "if m and not (D.mil and D.mil[k]) then" } },
  { "Dm", "sleeping : le libre dépasse le stock", { "free_mu = free_mu + math.min(have, free[k] or 0) * m", "free_mu = free_mu + (free[k] or 0) * m" } },
  { "Dm", "closed_cause : maître ignoré", { "if not c.on then return \"maitre\"", "if false then return \"maitre\"" } },
  { "Dm", "closed_cause : menace confondue avec le besoin", { "if c.threat then return \"menace\"", "if c.threat then return \"besoin\"" } },
  { "Dm", "closed_cause : palier non lu", { "if c.palier_why then return \"palier\"", "if false then return \"palier\"" } },
  { "Dm", "closed_cause : besoin avant menace", { "  if c.off then return \"banc\", \"puits ferme : eteint par le banc (temoin)\" end\n  if c.threat then", "  if c.off then return \"banc\", \"puits ferme : eteint par le banc (temoin)\" end\n  if not c.reserve then return \"besoin\", \"x\" end\n  if c.threat then" } },
  { "Dm", "le puits ne croît plus", { "Dm.GROW = 100 ", "Dm.GROW = 0 " } },
  { "Dm", "le plafond de la production disparaît", { "if by_prod < cap then cap, cap_why = by_prod, Dm.Y_MULT .. \" x production\" end", "" } },
  { "Dm", "le plafond du stock libre disparaît", { "local cap, cap_why = by_stock, \"stock libre / \" .. Dm.DRAIN_H .. \" min\"", "local cap, cap_why = by_prod, \"x\"" } },
  { "Dm", "le puits ne décroît jamais", { "    p = 0 -- lot FIX-P1", "    p = p -- " } },
  { "Dm", "la science est toujours visée", { "if inp.research and #(cands.science or {}) > 0 then", "if #(cands.science or {}) > 0 then" } },
  { "Dm", "l'équipement n'est plus candidat", { "if #(cands.equipement or {}) > 0 then classes", "if false then classes" } },
  { "Dm", "le sommeil n'allonge pas Tmax", { "return math.max(tmax, math.min(Dm.TMAX_CAP, sleep_min))", "return tmax" } },
  { "Dm", "Tmax sans plafond", { "return math.max(tmax, math.min(Dm.TMAX_CAP, sleep_min))", "return math.max(tmax, sleep_min)" } },
  { "Dm", "la saturation ne lit plus le débit du puits", { "return math.max(floor or 0, need or 0, (flow or 0) * Dm.SAT_H)", "return math.max(floor or 0, need or 0)" } },
  { "Dm", "la charge n'est plus mise à l'échelle", { "return L * wanted / D, wanted, true", "return L, D, false" } },
  { "Dm", "le seuil du tapis dépasse l'ancien seuil", { "if ceiling and f > ceiling then return ceiling end", "" } },
  { "Dm", "les emplacements ignorent les bras", { "math.floor(math.max(0, hands or 0) / Dm.HANDS_PER_SITE + 1e-9)", "math.huge" } },
  { "Dm", "les emplacements sans plafond de sûreté", { "math.min(Dm.SLOTS_HARD, base + extra)", "base + extra" } },
  { "Dm", "les capacités de plus ignorent le puits fermé", { "if not open then return 0 end\n  return math.min(Dm.CAP_EXTRA_MAX", "return math.min(Dm.CAP_EXTRA_MAX" } },
  { "Ca", "le puits n'entre plus dans les puits de la capitalisation", { "      sinks_in = merged\n", "" } },
  { "Ca", "le coût d'opportunité n'est plus nul", { "    o.cost = o.cost - disc\n", "" } },
  { "Ca", "le stock qui dort n'est pas entamé", { "if ctx.dm and pick.dormant_mu then ctx.dm.left", "if false then ctx.dm.left" } },
  { "Ca", "Tmax ne tient pas compte du sommeil", { "  if ctx.dm then tmax = Dm.tmax(tmax, ctx.dm.tmax_sleep) end\n", "" } },
  { "Ca", "le puits s'ouvre sans le besoin évalué", { "if input.demande and ctx.reserve then", "if input.demande then" } },
  { "B", "la saturation redevient un plancher", { "s.puits_flow and s.puits_flow[item] or nil)", "nil)" } },
  { "A", "la décision lit la charge d'aujourd'hui", { "L, D, scaled = Dm.load(L, D, input.wanted and input.wanted[item])", "scaled = nil" } },
  { "A", "le seuil du tapis reste constant", { "belt = A.belt_flow({ book = input.book, stock = input.stock, dist = input.dist, price = price }, H) or A.BELT_FLOW", "belt = A.BELT_FLOW" } },
}
local killed = 0
quiet = true
for _, m in ipairs(MUTANTS) do
  local mods, err = build(m[1], m[3])
  local dead
  if not mods then
    dead = true -- le texte à muter a disparu : le mutant ne se construit pas, donc le test ne le couvre plus (échec visible)
    quiet = false
    check(false, "mutant '" .. m[2] .. "' : " .. tostring(err))
    quiet = true
  else
    local p0, f0 = passes, failures
    local okrun, e = pcall(run_all, mods)
    dead = (not okrun) or (failures - f0) > 0
    -- on retire les ECHEC du mutant du bilan (ils prouvent seulement qu'il est refusé)
    failures = f0
    passes = p0
  end
  if dead then killed = killed + 1 else
    quiet = false
    check(false, "mutant SURVIVANT : " .. m[2])
    quiet = true
  end
end
quiet = false
print(string.format("   mutants refusés : %d / %d", killed, #MUTANTS))
check(killed == #MUTANTS, "tous les mutants sont refusés")

print(string.format("[DEMANDE] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
