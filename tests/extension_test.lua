--[[
  Lot C3 EXTENSION : test hors jeu de la RÈGLE DE RELÈVE (shared/ai3/extension.lua) et de son branchement aux buts (shared/ai3/buts.lua).
    §1 allure : l'intervalle baisse avec le poids de l'extraction, la posture « expansion » et les bras libres, plancher Ex.EVERY_MIN ;
    §2 posture : poids, domination ; avant-postes visés (strategy.desired_outposts) ;
    §3 survie : tourelles d'abord, pertes récentes, menace, escorte d'un site loin (exigence qui croît avec la distance) ;
    §4 relève : causes manque / plein / posture / extension, types sans cause (place, chantier, rien d'exploité, optionnel), refus écrits,
       concurrence, ordre, veille poussée, journal ;
    §5 portée : étendue, rayon de base, bonus de portée, sites gardés selon la défense, régions bloquées ;
    §6 branchement : B.generate émet « releve:<type> » (fond pour l'allure), jamais pour votre équipe ni réglage éteint ; V.reach ;
    §7 déterminisme ; aucun nom du jeu dans le fichier ;
    §8 MUTANTS : chaque règle retirée est vue.
  Usage : lua5.2 tests/extension_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local V = require("shared.faction.valeur")

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/ai3/extension.lua")

local function load_ex(src)
  local fn, err = load(src, "=extension", "t")
  if not fn then return nil, err end
  local ok, mod = pcall(fn)
  if not ok then return nil, mod end
  return mod
end

local KINDS = T.OUTPOST_ORDER
local K1, K2, K3 = KINDS[1], KINDS[2], KINDS[3]
local MIN = 3600

--- Ligne d'un type : exploité (1 avant-poste), plein, aucun site, produit non saturé.
local function row(kind, o)
  local r = { kind = kind, n = 1, cap = 5.5, room = false, sites = 0, near = nil, pending = 0, saturated = false, short = 0, short_n = 0,
    optional = false }
  for k, v in next, o or {} do r[k] = v end
  return r
end

local function sit(kinds, o)
  local s = { tick = 40 * MIN, kinds = kinds, w_ext = 1000, expansion = 0, dominant = false, desired = nil, spare = 0, soldiers = 10,
    undefended = 0, lethal = 0, threatened = false, hold = false }
  for k, v in next, o or {} do s[k] = v end
  return s
end

local function goal_of(out, kind)
  for _, g in ipairs(out.goals) do if g.kind == kind then return g end end
  return nil
end

local function suite(Ex)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end

  -- §1 Allure.
  check(Ex.interval(1000, 0, 0) == Ex.EVERY, "§1 allure neutre : " .. Ex.interval(1000, 0, 0))
  check(Ex.interval(2000, 0, 0) < Ex.interval(1000, 0, 0) and Ex.interval(500, 0, 0) > Ex.interval(1000, 0, 0), "§1 le poids de l'extraction raccourcit l'allure")
  check(Ex.interval(1000, 800, 0) < Ex.interval(1000, 0, 0), "§1 la posture expansion raccourcit l'allure")
  check(Ex.interval(1000, 0, 6) < Ex.interval(1000, 0, 0) and Ex.interval(1000, 0, 3) < Ex.interval(1000, 0, 0), "§1 les bras libres raccourcissent l'allure")
  check(Ex.interval(2000, 1000, 60) == Ex.EVERY_MIN, "§1 plancher de l'allure : " .. Ex.interval(2000, 1000, 60))
  check(Ex.weight(10, 0) == Ex.W_MIN and Ex.weight(5000, 5000) == Ex.W_MAX, "§1 poids borné")

  -- §2 Posture.
  do
    local w, dom = Ex.posture({ { key = "expansion", w = 500 }, { key = "armee", w = 300 } }, "expansion")
    check(w == 500 and dom, "§2 expansion 500 contre 300 : dominante")
    w, dom = Ex.posture({ { key = "expansion", w = 500 }, { key = "armee", w = 600 } }, "expansion")
    check(w == 500 and not dom, "§2 expansion 500 contre 600 : pas dominante")
    w, dom = Ex.posture({ { key = "expansion", w = 300 } }, "expansion")
    check(w == 300 and not dom, "§2 expansion sous Ex.DOMINANT : pas dominante")
    w, dom = Ex.posture(nil, "expansion")
    check(w == 0 and not dom, "§2 sans mélange : rien")
    check(Ex.desired(0, 1000) == 3 and Ex.desired(2, 1500) == 11, "§2 avant-postes visés : (3 + 2 tech) x avidité")
  end

  -- §3 Survie.
  do
    check(Ex.guard({ near = 100, soldiers = 0 }), "§3 site proche, rien d'autre : part")
    local ok, why = Ex.guard({ undefended = 1 })
    check(not ok and why:find("tourelles", 1, true), "§3 un avant-poste sous sa cible de tourelles : tourelles d'abord")
    check(Ex.guard({ undefended = 1, outposts = 3 }) and not Ex.guard({ undefended = 2, outposts = 3 }) and not Ex.guard({ undefended = 1, outposts = 2 }),
      "§3 tolérance : 1 avant-poste sur 3 peut être en retard de tourelles, pas 2 sur 3 ni 1 sur 2")
    ok, why = Ex.guard({ lethal = 1 })
    check(not ok and why:find("pertes", 1, true), "§3 un PNJ mort récemment en route : pas de relève")
    ok, why = Ex.guard({ threatened = true })
    check(not ok and why:find("menace", 1, true), "§3 équipe menacée : pas de relève")
    check(Ex.escort(100) == 0 and Ex.escort(160) == 0 and Ex.escort(161) == Ex.ESCORT_MIN, "§3 escorte : aucune jusqu'à 160 tuiles, deux au-delà")
    check(Ex.escort(300) > Ex.escort(200) and Ex.escort(5000) == Ex.ESCORT_MAX, "§3 escorte : croît avec la distance, bornée")
    ok, why = Ex.guard({ near = 300, soldiers = 2 })
    check(not ok and why:find("escorte", 1, true), "§3 site loin sans assez de soldats : escorte")
    check(Ex.guard({ near = 300, soldiers = Ex.escort(300) }), "§3 site loin avec l'escorte : part")
  end

  -- §4 Relève.
  do
    local es = Ex.new()
    -- plein : le gisement pris est plein, le produit n'est pas saturé, un site existe
    local out = Ex.releve(sit({ row(K1, { sites = 1, near = 100 }), row(K2, { room = true }) }, { spare = 12 }), es)
    local g = goal_of(out, K1)
    check(g and g.why == "plein", "§4 type plein, produit non saturé : cause « plein »")
    check(goal_of(out, K2) == nil, "§4 type avec place : aucun but")
    -- aucun avant-poste, chantier en cours
    out = Ex.releve(sit({ row(K1, { n = 0, cap = 0 }), row(K2, { pending = 1 }) }), Ex.new())
    check(#out.goals == 0, "§4 type jamais exploité ou chantier en cours : aucun but")
    -- manque durable
    out = Ex.releve(sit({ row(K1, { short = 400, short_n = 7, saturated = false, sites = 1 }) }), Ex.new())
    check(goal_of(out, K1) and goal_of(out, K1).why == "manque", "§4 manque durable : cause « manque »")
    out = Ex.releve(sit({ row(K1, { short = 400, short_n = 3, saturated = false }) }), Ex.new())
    check(goal_of(out, K1) and goal_of(out, K1).why == "plein", "§4 manque trop court : « plein » seulement")
    -- saturé : rien tant que l'allure n'est pas échue
    es = Ex.new()
    out = Ex.releve(sit({ row(K1, { saturated = true, sites = 1 }) }, { tick = 10 * MIN }), es)
    check(#out.goals == 0 and not out.due, "§4 saturé, allure non échue : aucun but")
    out = Ex.releve(sit({ row(K1, { saturated = true, sites = 1 }) }, { tick = 10 * MIN + Ex.EVERY }), es)
    check(out.due and goal_of(out, K1) and goal_of(out, K1).why == "extension", "§4 saturé, allure échue : cause « extension » (la base grandit quand même)")
    -- posture : en retard sur les avant-postes visés
    es = Ex.new()
    out = Ex.releve(sit({ row(K1, { saturated = true, sites = 1 }) }, { tick = 10 * MIN, dominant = true, desired = 5 }), es)
    check(goal_of(out, K1) and goal_of(out, K1).why == "posture", "§4 posture dominante et 1 avant-poste sur 5 visés : cause « posture »")
    out = Ex.releve(sit({ row(K1, { saturated = true, sites = 1 }) }, { tick = 10 * MIN, dominant = true, desired = 1 }), Ex.new())
    check(#out.goals == 0, "§4 posture dominante mais objectif atteint : aucun but")
    out = Ex.releve(sit({ row(K1, { saturated = true, sites = 1 }) }, { tick = 10 * MIN, dominant = false, desired = 5 }), Ex.new())
    check(#out.goals == 0, "§4 posture non dominante : rien")
    -- type optionnel : « manque » seulement
    out = Ex.releve(sit({ row(K1, { optional = true, sites = 1 }) }), Ex.new())
    check(#out.goals == 0, "§4 type optionnel non saturé : rien")
    out = Ex.releve(sit({ row(K1, { optional = true, short = 400, short_n = 9 }) }), Ex.new())
    check(goal_of(out, K1) and goal_of(out, K1).why == "manque", "§4 type optionnel qui manque durablement : relevé")
    out = Ex.releve(sit({ row(K1, { optional = true, saturated = true }) }, { tick = 10 * MIN + Ex.EVERY }), Ex.new())
    check(#out.goals == 0, "§4 type optionnel saturé, allure échue : rien")
    -- l'équipe recrute : l'allure et la posture attendent, « plein » non
    out = Ex.releve(sit({ row(K1, { saturated = true }) }, { tick = 10 * MIN + Ex.EVERY, hold = true }), Ex.new())
    check(#out.goals == 0, "§4 équipe qui recrute : l'allure attend")
    out = Ex.releve(sit({ row(K1, {}) }, { hold = true }), Ex.new())
    check(goal_of(out, K1) and goal_of(out, K1).why == "plein", "§4 équipe qui recrute : « plein » part quand même")
    -- survie : refus écrits
    out = Ex.releve(sit({ row(K1, { sites = 1 }) }, { undefended = 1 }), Ex.new())
    check(#out.goals == 0 and #out.blocked == 1 and out.blocked[1].why:find("tourelles", 1, true) and out.blocked[1].cause == "plein",
      "§4 avant-poste sous sa cible de tourelles : aucun but, refus « tourelles d'abord » écrit avec sa cause")
    out = Ex.releve(sit({ row(K1, { sites = 1, near = 400 }) }, { soldiers = 1 }), Ex.new())
    check(#out.goals == 0 and out.blocked[1] and out.blocked[1].why:find("escorte", 1, true), "§4 site loin sans escorte : refus écrit")
    -- concurrence : une relève à la fois, plus avec des bras libres
    local two = { row(K1, { sites = 1 }), row(K2, { sites = 1 }), row(K3, { sites = 1 }) }
    out = Ex.releve(sit(two), Ex.new())
    check(#out.goals == 1, "§4 sans bras libre : une seule relève (" .. #out.goals .. ")")
    out = Ex.releve(sit(two, { spare = 6 }), Ex.new())
    check(#out.goals == 2, "§4 6 bras libres : deux relèves (" .. #out.goals .. ")")
    out = Ex.releve(sit(two, { spare = 40 }), Ex.new())
    check(#out.goals == 3, "§4 beaucoup de bras libres : trois relèves, plafond Ex.SLOTS_MAX (" .. #out.goals .. ")")
    out = Ex.releve(sit({ row(K1, { sites = 1 }), row(K2, { sites = 1, pending = 1 }) }), Ex.new())
    check(#out.goals == 0, "§4 un chantier ouvert occupe la place de relève")
    do
      local es2 = Ex.new()
      Ex.releve(sit({ row(K1, { sites = 1 }), row(K2, { sites = 1 }) }), es2)
      local n2 = #es2.log
      Ex.releve(sit({ row(K1, { sites = 1, pending = 1 }), row(K2, { sites = 1 }) }, { tick = 41 * MIN }), es2)
      check(#es2.log == n2 + 1 and es2.why[K2] == nil, "§4 une place de relève prise par un autre type n'est pas une cause : seule la perte du but de " .. K1 .. " est écrite")
    end
    out = Ex.releve(sit({ row(K1, { sites = 1, pending = 1 }), row(K2, { sites = 1 }) }, { spare = 12 }), Ex.new())
    check(goal_of(out, K1) == nil and goal_of(out, K2) ~= nil, "§4 le type dont un chantier est ouvert ne reçoit pas un 2e but, les autres oui")
    -- ordre : « manque » avant « plein », puis un type qui a un site avant un type sans site
    out = Ex.releve(sit({ row(K1, { sites = 1 }), row(K2, { short = 400, short_n = 7 }) }, { spare = 6 }), Ex.new())
    check(out.goals[1] and out.goals[1].kind == K2 and out.goals[1].why == "manque", "§4 « manque » passe avant « plein »")
    out = Ex.releve(sit({ row(K1, { sites = 0 }), row(K2, { sites = 2 }) }, { spare = 6 }), Ex.new())
    check(out.goals[1] and out.goals[1].kind == K2, "§4 à cause égale, le type qui a un site passe d'abord")
    -- veille poussée
    out = Ex.releve(sit({ row(K1, { sites = 0 }) }), Ex.new())
    check(out.push == true, "§4 une relève attend un site : veille poussée")
    out = Ex.releve(sit({ row(K1, { sites = 2 }) }), Ex.new())
    check(out.push == false, "§4 un site existe : veille ordinaire")
    out = Ex.releve(sit({ row(K1, { sites = 0 }) }, { undefended = 1 }), Ex.new())
    check(out.push == false, "§4 relève refusée (tourelles) : la veille n'est pas poussée")
    -- état et journal : un avant-poste gagné remet l'allure à zéro
    es = Ex.new()
    Ex.releve(sit({ row(K1, { saturated = true }) }, { tick = 10 * MIN }), es)
    check(es.last == 10 * MIN and es.grown == 0, "§4 première lecture : la date de départ de l'allure est posée")
    out = Ex.releve(sit({ row(K1, { saturated = true, n = 2, room = true }) }, { tick = 20 * MIN }), es)
    check(es.last == 20 * MIN and es.grown == 1, "§4 un avant-poste gagné : allure repartie, extension comptée")
    local joined = {}
    for _, e in ipairs(es.log) do joined[#joined + 1] = e.text end
    check(table.concat(joined, "|"):find("avant-poste gagne", 1, true) ~= nil, "§4 le gain est écrit au journal")
    local n0 = #es.log
    Ex.releve(sit({ row(K1, { saturated = true, n = 2, room = true }) }, { tick = 21 * MIN }), es)
    check(#es.log == n0, "§4 aucune ligne de journal sans changement de cause")
    es = Ex.new()
    Ex.releve(sit({ row(K1, { sites = 1 }) }), es)
    local n1 = #es.log
    Ex.releve(sit({ row(K1, { sites = 1 }) }, { tick = 41 * MIN }), es)
    check(n1 >= 1 and #es.log == n1, "§4 une cause stable n'écrit qu'une ligne (" .. n1 .. ")")
    check(es.log[1].text:find("plein", 1, true) and es.log[1].text:find("sites 1", 1, true), "§4 la ligne dit la cause et les sites")
    Ex.releve(sit({ row(K1, { sites = 1 }) }, { undefended = 1, tick = 42 * MIN }), es)
    check(es.log[#es.log].text:find("attend", 1, true) and es.log[#es.log].text:find("tourelles", 1, true), "§4 le refus est écrit avec sa raison")
  end

  -- §5 Portée.
  do
    check(Ex.extent({ 100 * 100, 250 * 250, 30 * 30 }) == 250 and Ex.extent({}) == 0, "§5 étendue : l'avant-poste le plus lointain")
    check(Ex.base_radius(0) == Ex.RADIUS_MIN and Ex.base_radius(200) == 264 and Ex.base_radius(5000) == Ex.RADIUS_MAX, "§5 rayon de base : plancher, étendue + marge, plafond")
    check(Ex.reach_bonus(0) == 1000 and Ex.reach_bonus(96) == 1000 and Ex.reach_bonus(300) > Ex.reach_bonus(200) and Ex.reach_bonus(200) > 1000,
      "§5 bonus de portée : 1 000 jusqu'au rayon minimal, croît ensuite")
    local per, total = Ex.site_limits(1)
    check(per == Ex.PER_KIND and total == Ex.TOTAL + 1, "§5 défense minimale : 3 sites par ressource, 13 en tout (" .. per .. ", " .. total .. ")")
    local per8, total8 = Ex.site_limits(9)
    check(per8 == Ex.PER_KIND + 2 and total8 == Ex.TOTAL + 9, "§5 défense de 9 : 5 par ressource, 21 en tout (" .. per8 .. ", " .. total8 .. ")")
    local perM, totalM = Ex.site_limits(1000)
    check(perM == Ex.PER_KIND_MAX and totalM == Ex.TOTAL_MAX, "§5 sites gardés bornés")
    check(Ex.defense_capacity(0, 0) == 1 and Ex.defense_capacity(3, 12) == 6, "§5 capacité de défense : QG + avant-postes défendus + soldats / 6")
    local r0, t0 = Ex.block_params(0)
    local r4, t4 = Ex.block_params(Ex.BLOCK_FREE)
    local r10, t10 = Ex.block_params(10)
    local r99, t99 = Ex.block_params(99)
    check(r0 == Ex.BLOCK_R and t0 == Ex.BLOCK_TTL and r4 == Ex.BLOCK_R and t4 == Ex.BLOCK_TTL, "§5 régions bloquées : rayon et durée pleins jusqu'à 4")
    check(r10 < r4 and t10 < t4 and r99 == Ex.BLOCK_R_MIN and t99 == Ex.BLOCK_TTL_MIN, "§5 régions bloquées : rétrécissent, planchers")
  end

  return pass, fail, msgs
end

local Ex0 = assert(load_ex(SRC))
local pass, fail, msgs = suite(Ex0)

-- §6 Branchement aux buts.
local B = require("shared.ai3.buts")
do
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end
  local function situation(o)
    local s = { workers = 12, soldiers = 10, soldiers_max = 20, stock = {}, cap = { [K1] = 5.5 }, pending = {}, sites = { [K1] = 1 }, sites_near = { [K1] = 120 },
      nout = { [K1] = 1 }, room = {}, smelters = 4, smelters_pending = 0, weights = { extraction = 1000 }, tick = 40 * MIN, is_player = false,
      extension = true, undef_n = 0, lethal_n = 0, threatened = false, expansion = 0, dominant = false, key = B.key({}),
      need = {}, research = nil, army_target = 0, at_war = false }
    for k, v in next, o or {} do s[k] = v end
    return s
  end
  local function find(goals, key)
    for _, g in ipairs(goals) do if g.key == key then return g end end
    return nil
  end
  local st = { short = {}, short_n = {}, targets = {}, ever = {} }
  local goals = B.generate(situation(), st)
  local g = find(goals, "releve:" .. K1)
  check(g and g.releve == "plein" and g.outpost == K1 and g.family == "extraction" and g.fond == nil, "§6 B.generate : « releve:" .. K1 .. " », cause « plein », projet ordinaire")
  check(g and g.value >= 1 and g.value <= 100, "§6 valeur bornée")
  goals = B.generate(situation({ stock = { [T.outposts[K1].product] = 100000 } }), { short = {}, short_n = {}, targets = {}, ever = {} })
  check(find(goals, "releve:" .. K1) == nil, "§6 produit saturé, allure non échue : aucun but de relève")
  goals = B.generate(situation({ stock = { [T.outposts[K1].product] = 100000 }, tick = 90 * MIN }), { short = {}, short_n = {}, targets = {},
    ever = {}, ext = { last = 10 * MIN, n_out = 1, grown = 0, why = {}, log = {}, seq = 0, open = {} } })
  g = find(goals, "releve:" .. K1)
  check(g and g.releve == "extension" and g.fond == true and g.value <= B.COVER_MAX, "§6 allure échue : but de FOND borné comme la couverture")
  goals = B.generate(situation({ is_player = true }), { short = {}, short_n = {}, targets = {}, ever = {} })
  check(find(goals, "releve:" .. K1) == nil, "§6 votre équipe : aucune relève")
  goals = B.generate(situation({ extension = false }), { short = {}, short_n = {}, targets = {}, ever = {} })
  check(find(goals, "releve:" .. K1) == nil, "§6 réglage maître éteint : aucune relève")
  goals = B.generate(situation({ room = { [K1] = true } }), { short = {}, short_n = {}, targets = {}, ever = {} })
  check(find(goals, "releve:" .. K1) == nil, "§6 un avant-poste a encore de la place : on l'agrandit, pas de relève")
  goals = B.generate(situation({ undef_n = 1 }), { short = {}, short_n = {}, targets = {}, ever = {} })
  check(find(goals, "releve:" .. K1) == nil, "§6 un avant-poste sous sa cible de tourelles : aucune relève")
  -- intégration 0.6.32 (C2 x C3) : capacité visée au-delà du plafond d'avant, sans place : la relève et sa garde, jamais « extraction: » sans garde
  do
    local Br = require("shared.ai3.bras")
    local want = Br.cap_max(12, B.GROW_MAX) + 4
    local function st_over() return { short = {}, short_n = {}, targets = { [K1] = want }, ever = {} } end
    local over = { extra_cap = 6, cap = { [K1] = 2 } }
    local g0 = B.generate(situation(over), st_over())
    check(find(g0, "extraction:" .. K1) == nil and find(g0, "releve:" .. K1) ~= nil, "§6 capacité due au puits, sans place : relève, pas de but sans garde")
    over.undef_n = 1
    local g1 = B.generate(situation(over), st_over())
    check(find(g1, "extraction:" .. K1) == nil and find(g1, "releve:" .. K1) == nil, "§6 … et sa garde la retient (tourelles d'abord)")
    local g2 = B.generate(situation({ extra_cap = 6, cap = { [K1] = 2 }, room = { [K1] = true } }), st_over())
    check(find(g2, "extraction:" .. K1) ~= nil, "§6 avec une place : agrandir reste un but ordinaire")
    local g3 = B.generate(situation({ extra_cap = 6, cap = { [K1] = 2 }, extension = false }), st_over())
    check(find(g3, "extraction:" .. K1) ~= nil, "§6 réglage maître éteint : la règle d'avant")
  end
  local st2 = { short = {}, short_n = {}, targets = {}, ever = {} }
  B.generate(situation({ sites = { [K1] = 0 } }), st2)
  check(st2.ext and st2.ext.push == true, "§6 la relève sans site pousse la veille (st.ext.push)")
  -- V.reach : portée de valeur
  check(V.reach(1000, 1000) == V.reach(1000, 1000, 1000) and V.reach(1000, 1000, nil) == 220, "§6 V.reach sans bonus : la règle d'avant")
  check(V.reach(1000, 1000, 1800) > 220 and V.reach(1000, 1000, 1800) == 396, "§6 V.reach avec le bonus de l'étendue : 220 x 1,8")
  check(V.reach(1500, 1300, 3000) <= V.REACH_MAX, "§6 V.reach borné par V.REACH_MAX")
end

-- §7 Déterminisme et aucun nom du jeu.
do
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end
  local function run()
    local es = Ex0.new()
    local acc = {}
    for t = 1, 6 do
      local out = Ex0.releve(sit({ row(K1, { sites = t % 2 }), row(K2, { saturated = true }), row(K3, { short = 300, short_n = t + 3 }) },
        { tick = t * 13 * MIN, spare = t }), es)
      for _, g in ipairs(out.goals) do acc[#acc + 1] = t .. g.kind .. g.why end
      for _, b in ipairs(out.blocked) do acc[#acc + 1] = t .. b.kind .. b.why end
    end
    for _, e in ipairs(es.log) do acc[#acc + 1] = e.text end
    return table.concat(acc, "|")
  end
  check(run() == run(), "§7 même entrée, même sortie")
  local names = {}
  for _, kind in ipairs(KINDS) do
    names[#names + 1] = T.outposts[kind].product
    names[#names + 1] = T.outposts[kind].resource
  end
  names[#names + 1] = T.turret_ammo
  local hits = {}
  for _, line in ipairs((function() local l = {} for x in SRC:gmatch("[^\n]+") do l[#l + 1] = x end return l end)()) do
    local code = line:gsub("%-%-.*$", "")
    for _, n in ipairs(names) do
      if code:find('"' .. n .. '"', 1, true) then hits[#hits + 1] = n end
    end
  end
  check(#hits == 0, "§7 aucun nom d'objet entre guillemets dans shared/ai3/extension.lua : " .. table.concat(hits, " "))
end

-- §9 Câblage : les modules du runtime lisent bien la règle (texte des fichiers ; un fil coupé est vu, comme l'audit n°25 : « un fil coupé, pas une borne »).
do
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end
  local WIRES = {
    { "shared/ai3/buts.lua", "local rel = B.releve(s, st)", "B.generate émet les buts de relève" },
    { "shared/ai3/buts.lua", "if s.extension and not s.is_player then", "la relève : factions seulement, réglage maître allumé" },
    { "shared/ai3/cerveau.lua", "extension = ctx.industrie or false", "C.situation lit le réglage maître" },
    { "script/ai3/cerveau.lua", "Ex.posture(f.chef and f.chef.mix, \"expansion\")", "la posture du chef entre dans la pensée" },
    { "script/ai3/cerveau.lua", "Ext.after(f, view, st, tick)", "Ia3.plan range les mesures et écrit le journal [FO-EXTENSION]" },
    { "script/faction/sites.lua", "if not f.is_player then per, total = faction_limits(f) end", "Sites.room_for : sites gardés selon la défense" },
    { "script/faction/sites.lua", "faction_limits(f)), need + FACTION_EXTRA", "Sites : sites voulus par ressource selon la défense" },
    { "script/faction/sites.lua", "ctx.reach_bonus = es.reach", "la portée de valeur suit l'étendue" },
    { "script/ai3/capitalisation.lua", "local scan_r = scan_radius(f)", "la capitalisation recense le rayon de la base" },
    -- (lot PERIMETRE2 G3 essai 3 : par Build.radius_frozen = enceinte ni complète ni de votre équipe en construction ; factions : la règle d'avant)
    { "script/ai3/capitalisation.lua", "if enc and not Build.radius_frozen(f.build) then enc = nil end", "enceinte complète : un gisement au-delà n'est plus « hors du plan directeur »" },
    { "script/team/build.lua", "enc_r = Build.radius_frozen(b) and b.enc.r or nil", "enceinte complète : la croissance vers un gisement n'est plus refusée" },
    { "script/team/build.lua", "return b.enc ~= nil and not Build.beyond_wall(b) and not b.enc.grow", "Build.radius_frozen : figé sauf enceinte complète (ou celle de votre équipe en construction)" },
    { "script/ai3/capitalisation.lua", "Dm.blocked_next(cs.blocked_slots, Dm.count_blocked(res.refus))", "les emplacements lisent les ordres retenus" },
    { "script/ai3/exploration.lua", "K.blocked_near(k.blocked, bx, by, tick, block_params(k))", "régions bloquées : rayon et durée variables" },
    { "script/ai3/exploration.lua", "push = push,", "la veille reçoit la poussée de l'extension" },
    { "script/ai3/exploration.lua", "Poles.sur_hold(f, tick)", "veille poussée : un PNJ est libéré" },
    { "script/faction/veille.lua", "vs.last_start = tick", "veille : date du dernier départ" },
    { "shared/faction/veille.lua", "if c.push and need > 1 then need = need - 1 end", "V.want : un PNJ libre de moins exigé quand la veille est poussée" },
    { "shared/faction/valeur.lua", "V.reach(ctx.ambition, ctx.appetite, ctx.reach_bonus)", "V.components : portée avec le bonus de l'étendue" },
  }
  for _, w in ipairs(WIRES) do
    local text = read(w[1])
    check(text:find(w[2], 1, true) ~= nil, "§9 câblage " .. w[1] .. " : " .. w[3])
  end
end

-- §8 Mutants.
local MUTANTS = {
  { "relève sans la place", "not k%.room and", "true and" },
  { "relève sans le chantier en cours", "and %(k%.pending or 0%) == 0 then", "then" },
  { "type optionnel relevé comme les autres", "if k%.optional then return nil end", "" },
  { "« plein » même saturé", "if not k%.saturated then return \"plein\" end", "return \"plein\"" },
  { "manque sans durée", "%(k%.short_n or 0%) >= Ex%.SHORT_THINKS and ", "" },
  { "allure jamais échue", "local due = not s%.hold and tick %- %(es%.last or tick%) >= interval", "local due = false" },
  { "allure toujours échue", "local due = not s%.hold and tick %- %(es%.last or tick%) >= interval", "local due = true" },
  { "posture sans objectif", "local behind = s%.dominant == true and s%.desired ~= nil and n_out < s%.desired", "local behind = s.dominant == true" },
  { "survie : tourelles ignorées", "if %(g%.undefended or 0%) > math%.floor%(%(g%.outposts or 0%) / Ex%.UNDEF_DIV%) then return false, \"tourelles d'abord\" end", "" },
  { "survie : aucune tolérance", "math%.floor%(%(g%.outposts or 0%) / Ex%.UNDEF_DIV%)", "0" },
  { "survie : pertes ignorées", "if %(g%.lethal or 0%) > 0 then return false, \"pertes recentes\" end", "" },
  { "survie : menace ignorée", "if g%.threatened then return false, \"menace\" end", "" },
  { "survie : escorte ignorée", "if %(g%.soldiers or 0%) < need then", "if false then" },
  { "escorte constante", "return clamp%(Ex%.ESCORT_MIN %+ math%.floor%(%(%(d or 0%) %- Ex%.SAFE_D%) / Ex%.ESCORT_STEP%), Ex%.ESCORT_MIN, Ex%.ESCORT_MAX%)", "return Ex.ESCORT_MIN" },
  { "concurrence illimitée", "return clamp%(1 %+ math%.floor%(math%.max%(0, spare or 0%) / Ex%.HANDS_PER_SLOT%), 1, Ex%.SLOTS_MAX%)", "return 99" },
  { "concurrence sans bras libres", "return clamp%(1 %+ math%.floor%(math%.max%(0, spare or 0%) / Ex%.HANDS_PER_SLOT%), 1, Ex%.SLOTS_MAX%)", "return 1" },
  { "allure sans bras libres", "local hands = 1000 %+ math%.floor%(1000 %* math%.max%(0, spare or 0%) / Ex%.HANDS_PER%)", "local hands = 1000" },
  { "allure sans plancher", "return math%.max%(Ex%.EVERY_MIN, math%.floor%(base %* 1000 / hands%)%)", "return math.floor(base * 1000 / hands)" },
  { "ordre : manque après plein", "Ex%.RANK = { manque = 1, plein = 2,", "Ex.RANK = { manque = 3, plein = 2," },
  { "veille jamais poussée", "if g%.sites == 0 then out%.push = true end", "" },
  { "journal à chaque pensée", "if now ~= es%.why%[k%.kind%] then", "if true then" },
  { "gain d'avant-poste sans effet", "es%.last = tick\n    push_log%(es, tick, string%.format%(\"avant%-poste gagne", "push_log(es, tick, string.format(\"avant-poste gagne" },
  { "sites gardés sans défense", "local per = clamp%(Ex%.PER_KIND %+ math%.floor%(d / Ex%.DEFEND_PER%), Ex%.PER_KIND, Ex%.PER_KIND_MAX%)", "local per = Ex.PER_KIND" },
  { "régions bloquées figées", "local r = clamp%(Ex%.BLOCK_R %- 8 %* extra, Ex%.BLOCK_R_MIN, Ex%.BLOCK_R%)", "local r = Ex.BLOCK_R" },
  { "rayon de base sans plafond", "return clamp%(%(extent or 0%) %+ Ex%.RADIUS_MARGIN, Ex%.RADIUS_MIN, Ex%.RADIUS_MAX%)", "return (extent or 0) + Ex.RADIUS_MARGIN" },
  { "portée sans étendue", "return 1000 %+ e %* Ex%.REACH_STEP", "return 1000" },
  { "domination sans seuil", "return w, w > 0 and w >= best and w >= Ex%.DOMINANT", "return w, w > 0 and w >= best" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local src, n = SRC:gsub(m[2], function() return m[3] end)
  local ok = false
  if n == 1 then
    local Ex = load_ex(src)
    if Ex then
      local okp, p, f = pcall(suite, Ex)
      ok = (not okp) or f > 0
    else
      ok = true
    end
  end
  if n ~= 1 then kept[#kept + 1] = m[1] .. " (motif trouvé " .. n .. " fois)" elseif ok then refused = refused + 1 else kept[#kept + 1] = m[1] end
end
if #kept > 0 then
  fail = fail + 1
  msgs[#msgs + 1] = "§8 mutants NON refusés : " .. table.concat(kept, " ; ")
end
print(string.format("[EXTENSION] mutants refusés : %d sur %d", refused, #MUTANTS))

for _, m in ipairs(msgs) do print("  ECHEC : " .. m) end
print(string.format("[EXTENSION] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
