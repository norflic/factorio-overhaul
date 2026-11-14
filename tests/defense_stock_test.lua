--[[
  Tests hors jeu du lot DEFENSE-STOCK : shared/team/defense_stock.lua (règle pure : les tourelles qui dorment au coffre sont posées en
  groupes, au-dessus d'une petite réserve, là où l'ennemi arrive).
  Usage : lua5.2 tests/defense_stock_test.lua
  Vérifie : surplus au-dessus de la réserve, taille des groupes (croît avec le score, plafonnée), lot par voyage, munitions (cible, demi-dose,
  refus), jamais une tourelle isolée, ordre de service (QG, prévision, attaque, site, couverture), repos, pause, course avec le front,
  plafond du poste, refus du moteur, un seul lieu par pensée, déterminisme, absence de nom d'objet ; 17 MUTANTS (chacun refusé).
]]
package.path = "./?.lua;" .. package.path
local S = require("shared.team.defense_stock")

local passes, failures = 0, 0
local CAP0, MIN_SCORE0, DIST0 = S.TEAM_CAP, S.MIN_SCORE, S.MAX_DIST -- valeurs de la règle non mutée (les mutants changent les constantes, pas les attendus)
local function suite()
  local f0 = failures
  local function check(cond, msg)
    if cond then passes = passes + 1 else failures = failures + 1; if not S._silent then print("  ECHEC : " .. msg) end end
  end

  -- 1. surplus
  check(S.surplus(485) == 485 - S.RESERVE, "surplus = stock - réserve")
  check(S.surplus(S.RESERVE) == 0 and S.surplus(3) == 0 and S.surplus(nil) == 0, "sous la réserve : surplus nul")

  -- 2. taille des groupes
  check(S.group_want("attaque", 0) == S.MIN_GROUP, "score nul : groupe minimal")
  check(S.group_want("attaque", 3848) > 5, "score 3848 : plus que le plafond de 5 du front")
  check(S.group_want("attaque", 3848) > S.group_want("attaque", 900), "le groupe grandit avec le score")
  check(S.group_want("attaque", 999999) == S.GROUP_CAP, "plafond du groupe")
  check(S.group_want("qg", 0, 1) == S.MIN_GROUP, "un voulu imposé de 1 est relevé au groupe minimal")
  check(S.group_want("prevu", 0, 6) == 6, "voulu imposé (prévision) gardé")
  check(S.group_want("site", 0) == S.MIN_GROUP and S.group_want("couverture", 0) == S.MIN_GROUP, "site et couverture : groupe minimal")

  -- 3. munitions et lot
  check(S.ammo_plan(4, 4 * S.AMMO_FULL) == S.AMMO_FULL, "chargeurs de la cible payables : cible")
  check(S.ammo_plan(4, 4 * S.AMMO_FULL - 1) == S.AMMO_LOW, "un chargeur de moins : demi-dose")
  check(S.ammo_plan(4, 4 * S.AMMO_LOW - 1) == nil, "sous la demi-dose : rien")
  check(S.ammo_plan(0, 999) == nil, "zéro tourelle : rien")
  local n, each = S.lot(8, 400, 40, 10000)
  check(n == S.LOT and each == S.AMMO_FULL, "lot borné par S.LOT")
  n = S.lot(2, 400, 40, 10000)
  check(n == 2, "lot borné par le manque")
  n = S.lot(8, 3, 40, 10000)
  check(n == 3, "lot borné par le surplus")
  n = S.lot(8, 400, 1, 10000)
  check(n == 1, "lot borné par la place sous le plafond")
  n, each = S.lot(8, 400, 40, 3 * S.AMMO_LOW)
  check(n == 3 and each == S.AMMO_LOW, "chargeurs insuffisants : le lot rétrécit jusqu'à ce que la demi-dose paie")
  n = S.lot(8, 400, 40, 5)
  check(n == 0, "presque aucun chargeur : aucun lot")

  -- 4. planification
  local function zone(key, kind, score, have, extra)
    local z = { key = key, kind = kind, x = 100, y = 100, score = score, have = have }
    for k, v in pairs(extra or {}) do z[k] = v end
    return z
  end
  local base = { stock = 485, ammo = 5000, placed = 0, turrets = {} }
  local function plan(zones, extra)
    local p = {}
    for k, v in pairs(base) do p[k] = v end
    for k, v in pairs(extra or {}) do p[k] = v end
    p.zones = zones
    return S.plan(p)
  end
  -- le cas mesuré du DC : 485 au coffre, cellules attaquées 3848 / 2975 / 2395, 0 / 1 / 1 tourelle à portée
  local r = plan({ zone("26,-29", "attaque", 3848, 0), zone("25,-36", "attaque", 2975, 1), zone("26,-36", "attaque", 2395, 1) })
  check(r.pick and r.pick.key == "26,-29", "la cellule la plus attaquée est servie d'abord")
  check(r.pick and r.pick.count == S.LOT, "un lot complet par voyage")
  check(r.pick and r.pick.want == S.group_want("attaque", 3848), "voulu : le groupe de la règle, pas le plafond de 5")
  check(r.pick and #r.pick.sites == 8, "huit emplacements candidats")
  check(r.rows[2].skip == "suivante" and r.rows[3].skip == "suivante", "un seul lieu par pensée")
  check(r.surplus == 485 - S.RESERVE, "surplus rapporté")
  -- jamais une tourelle isolée
  r = plan({ zone("a", "attaque", 400, 0) }, { stock = S.RESERVE + 1 })
  check(r.pick == nil and r.rows[1].skip == "groupe", "un surplus d'une tourelle sur une cellule vide : pas de tourelle isolée")
  r = plan({ zone("a", "attaque", 400, 2) }, { stock = S.RESERVE + 1 })
  check(r.pick ~= nil and r.pick.count == 1, "une tourelle de plus à côté de deux : un groupe de trois")
  -- sous la réserve
  r = plan({ zone("a", "attaque", 3000, 0) }, { stock = S.RESERVE })
  check(r.pick == nil and r.rows[1].skip == "stock", "stock à la réserve : rien ne sort")
  r = plan({ zone("a", "attaque", 3000, 0) }, { stock = 14 })
  check(r.pick == nil and r.rows[1].skip == "stock" or (r.pick and r.pick.count <= 6), "stock de 14 : au plus le surplus")
  -- ordre de service
  r = plan({ zone("c", "couverture", 0, 0), zone("s", "site", 0, 0), zone("a", "attaque", 5000, 0), zone("p", "prevu", 0, 0, { want = 5 }),
    zone("q", "qg", 0, 1, { want = 4 }) })
  check(r.pick and r.pick.key == "q", "le QG qui a perdu ses tourelles passe avant tout")
  r = plan({ zone("c", "couverture", 0, 0), zone("s", "site", 0, 0), zone("a", "attaque", 5000, 0), zone("p", "prevu", 0, 0, { want = 5 }) })
  check(r.pick and r.pick.key == "p", "puis la prévision")
  r = plan({ zone("c", "couverture", 0, 0), zone("s", "site", 0, 0), zone("a", "attaque", 5000, 0) })
  check(r.pick and r.pick.key == "a", "puis la cellule attaquée")
  r = plan({ zone("c", "couverture", 0, 0), zone("s", "site", 0, 0) })
  check(r.pick and r.pick.key == "s", "puis le site, puis la couverture")
  r = plan({ zone("b", "attaque", 2000, 0), zone("a", "attaque", 2000, 0) })
  check(r.pick and r.pick.key == "a", "égalité de score : la clé la plus petite (déterminisme)")
  -- seuil d'attaque
  r = plan({ zone("a", "attaque", MIN_SCORE0 - 1, 0) })
  check(r.pick == nil, "une attaque sous le seuil n'est pas servie")
  -- cellule servie
  r = plan({ zone("a", "attaque", 3000, S.group_want("attaque", 3000)) })
  check(r.pick == nil and r.rows[1].skip == "servie", "groupe complet : servie")
  -- repos, pause, course, plafond, refus
  r = plan({ zone("a", "attaque", 3000, 0), zone("b", "attaque", 2000, 0) }, { rest = { a = true } })
  check(r.rows[1].skip == "repos" and r.pick and r.pick.key == "b", "cellule au repos sautée, la suivante servie")
  r = plan({ zone("a", "attaque", 3000, 0) }, { pause = true })
  check(r.pick == nil and r.rows[1].skip == "pause", "pause : rien")
  r = plan({ zone("a", "attaque", 3000, 0), zone("b", "attaque", 2000, 0) }, { avoid = "a" })
  check(r.rows[1].skip == "course" and r.pick and r.pick.key == "b", "cellule que le front sert : pas de course")
  r = plan({ zone("a", "attaque", 3000, 0) }, { placed = CAP0 })
  check(r.pick == nil and r.rows[1].skip == "plafond", "plafond du poste atteint : rien")
  r = plan({ zone("a", "attaque", 3000, 0) }, { placed = CAP0 - 3 })
  check(r.pick and r.pick.count == 3 and r.pick.have + r.pick.count >= S.MIN_GROUP, "il reste 3 places : un lot de 3")
  r = plan({ zone("a", "attaque", 3000, 0), zone("b", "attaque", 2000, 0) }, { allow = function(z) return z.key ~= "a" end })
  check(r.rows[1].skip == "refus" and r.pick and r.pick.key == "b", "le moteur refuse la première : la suivante est servie")
  local asked = 0
  r = plan({ zone("a", "attaque", 3000, 0), zone("b", "attaque", 2000, 0), zone("c", "attaque", 1000, 0) }, { allow = function() asked = asked + 1; return true end })
  check(asked == 1, "le moteur n'est consulté que jusqu'au premier lieu retenu")
  r = plan({ zone("a", "attaque", 3000, 0, { hold = true, why = "ennemi sur place" }) })
  check(r.pick == nil and r.rows[1].skip == "tenue" and r.rows[1].why == "ennemi sur place", "lieu tenu: cause gardée")
  -- munitions
  r = plan({ zone("a", "attaque", 3000, 0) }, { ammo = 3 * S.AMMO_LOW })
  check(r.pick and r.pick.count == 3 and r.pick.ammo_each == S.AMMO_LOW, "peu de chargeurs : lot de 3 en demi-dose")
  r = plan({ zone("a", "attaque", 3000, 0) }, { ammo = 4 })
  check(r.pick == nil and r.rows[1].skip == "munitions", "pas de chargeurs : refus « munitions »")
  -- emplacements : le plus écarté des tourelles déjà là d'abord
  r = plan({ zone("a", "attaque", 3000, 0) }, { turrets = { { x = 106, y = 100 } } })
  check(r.pick and not (r.pick.sites[1].x == 106 and r.pick.sites[1].y == 100), "le premier emplacement n'est pas sur une tourelle déjà là")
  -- distance : au-delà de S.MAX_DIST du QG, seulement près d'un avant-poste de l'équipe (tournées de ravitaillement)
  r = plan({ zone("a", "attaque", 3000, 0, { dist = DIST0 + 50 }), zone("b", "attaque", 2000, 0, { dist = DIST0 + 50, served = true }) })
  check(r.rows[1].skip == "loin" and r.pick and r.pick.key == "b", "trop loin du QG hors des avant-postes : refus « loin » ; servi par un avant-poste : posé")
  r = plan({ zone("a", "attaque", 3000, 0, { dist = DIST0 }) })
  check(r.pick and r.pick.key == "a", "à la distance maximale : posé")
  -- refus du moteur : la cause est un mot fixe, gardée dans la ligne
  r = plan({ zone("a", "attaque", 3000, 0) }, { allow = function() return false, "danger" end })
  check(r.rows[1].skip == "refus" and r.rows[1].why == "danger", "refus du moteur : cause « danger » gardée")
  -- plafond de fabrication des tourelles (le poste ne peut plus poser au-delà)
  check(S.stock_cap(0, 0) == S.RESERVE + S.TEAM_CAP + S.MALL_MARGIN, "plafond de stock : réserve + toutes les places + marge")
  check(S.stock_cap(S.TEAM_CAP, 0) == S.RESERVE + S.MALL_MARGIN, "poste plein : réserve + marge seulement")
  check(S.stock_cap(S.TEAM_CAP + 10, 5) == S.RESERVE + 5 + S.MALL_MARGIN, "places négatives ramenées à zéro, demande ajoutée")
  check(S.stock_cap(0, -3) == S.stock_cap(0, 0), "demande négative ignorée")
  check(S.stock_cap(10, 0) < S.stock_cap(0, 0), "le plafond baisse à mesure que le poste pose")
  -- déterminisme
  local r1 = plan({ zone("26,-29", "attaque", 3848, 0), zone("25,-36", "attaque", 2975, 1) })
  local r2 = plan({ zone("26,-29", "attaque", 3848, 0), zone("25,-36", "attaque", 2975, 1) })
  check(r1.pick.key == r2.pick.key and r1.pick.count == r2.pick.count and r1.pick.sites[1].x == r2.pick.sites[1].x, "mêmes entrées, mêmes sorties")
  return failures - f0
end

print("== DEFENSE-STOCK : règle pure")
suite()

-- Branchement au planificateur permanent : tâche « fortify » du poste « reserve », stock seulement
local function planner_suite(Planner)
  local f0 = failures
  local T = require("shared.team.config")
  local Book = require("shared.team.book")
  local Sc = require("shared.team.scale")
  local book = Book.new(dofile("tests/fixtures/recipes.lua"))
  local function check(cond, msg)
    if cond then passes = passes + 1 else failures = failures + 1; if not S._silent then print("  ECHEC : " .. msg) end end
  end
  local function view(over)
    local v = {
      tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true },
      deferred = {}, stock = {}, incoming = {}, outposts = {}, pending = {}, sites = {}, smelters = 2,
      smelters_pending = 0, smelter_task = false, smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0,
      turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 8, workers_max = 30, workers_idle = 0,
      threatened = false, open = {}, workers_wanted = 30, no_research = true, ladder = T.player_ladder,
      hq_turrets = T.defend_hq, defend_first = true,
    }
    for k, x in pairs(over or {}) do v[k] = x end
    if v.recruit_cost == nil then v.recruit_cost = Sc.recruit_cost(v.workers) end
    return v
  end
  local function rtask(plan)
    for _, t in ipairs(plan.tasks) do if t.kind == "fortify" and t.outpost == "reserve" then return t end end
    return nil
  end
  local function qty(t, name) for _, it in ipairs(t.items) do if it[1] == name then return it[2] end end return 0 end
  local pk = { key = "26,-29", kind = "attaque", x = 100, y = 100, score = 3848, have = 0, want = 6, count = 4, ammo_each = 20,
    sites = { { x = 106, y = 100 }, { x = 94, y = 100 } } }
  local rich = { ["iron-plate"] = 2000, ["copper-plate"] = 500, ["gun-turret"] = 485, [T.turret_ammo] = 5000, coal = 100, stone = 100 }
  local pl = Planner.plan(view({ stock = rich, reserve = { pick = pk, busy = false } }), book)
  local t = rtask(pl)
  check(t ~= nil, "pick du poste, stock au-dessus de la réserve : tâche fortify « reserve »")
  check(t and t.key == "fortify:reserve" and qty(t, "gun-turret") == 4 and qty(t, T.turret_ammo) == 4 * S.AMMO_FULL, "coût : 4 tourelles et leurs chargeurs, pris au stock")
  check(t and t.cell_key == "26,-29" and t.pos and t.pos.x == 100 and t.sites and #t.sites == 2, "la tâche porte le lieu, son centre et les emplacements")
  check(t and t.prio == S.PRIO and t.defend == nil, "priorité ordinaire (pas l'urgence de défense), non exemptée du rappel")
  check(pl.reserve and pl.reserve.why == "tache_creee" and pl.reserve.count == 4, "out.reserve dit la cause « tache_creee »")
  local pk2 = {}
  for k, v in pairs(pk) do pk2[k] = v end
  pk2.kind = "prevu"
  check(rtask(Planner.plan(view({ stock = rich, reserve = { pick = pk2 } }), book)).prio == S.PRIO_URGENT, "prévision : priorité d'urgence (sous les recharges)")
  check(rtask(Planner.plan(view({ stock = rich, reserve = { pick = pk, busy = true } }), book)) == nil, "tâche déjà prise : pas de doublon")
  check(rtask(Planner.plan(view({ stock = rich, reserve = { pick = pk }, open = { ["fortify:reserve"] = true } }), book)) == nil, "clé déjà ouverte : pas de doublon")
  check(rtask(Planner.plan(view({ stock = rich }), book)) == nil, "sans poste : aucune tâche")
  check(rtask(Planner.plan(view({ stock = rich, reserve = { pick = pk }, defend_first = false }), book)) == nil, "sans « défendre d'abord » : règle d'avant")
  -- aucune fabrication : sous la réserve, rien ne part et RIEN n'est commandé pour ce poste
  local poor = { ["iron-plate"] = 20000, ["copper-plate"] = 5000, ["gun-turret"] = S.RESERVE, [T.turret_ammo] = 5000, coal = 100, stone = 100 }
  local pp = Planner.plan(view({ stock = poor, reserve = { pick = pk } }), book)
  check(rtask(pp) == nil and pp.reserve and pp.reserve.why == "stock", "stock = réserve : pas de tâche, cause « stock »")
  local few = { ["iron-plate"] = 20000, ["copper-plate"] = 5000, ["gun-turret"] = S.RESERVE + 2, [T.turret_ammo] = 5000, coal = 100, stone = 100 }
  local pf = Planner.plan(view({ stock = few, reserve = { pick = pk } }), book)
  check(rtask(pf) == nil and pf.reserve and pf.reserve.why == "groupe", "surplus de 2 sur un lieu vide : pas de groupe, pas de tourelle isolée")
  -- chargeurs : demi-dose
  local lowammo = { ["iron-plate"] = 2000, ["copper-plate"] = 500, ["gun-turret"] = 485, [T.turret_ammo] = 3 * S.AMMO_LOW, coal = 100, stone = 100 }
  local pa = Planner.plan(view({ stock = lowammo, reserve = { pick = pk } }), book)
  local ta = rtask(pa)
  check(ta and qty(ta, "gun-turret") == 3 and qty(ta, T.turret_ammo) == 3 * S.AMMO_LOW, "peu de chargeurs : lot de 3 en demi-dose")
  -- équipe décimée : ni tourelle de réserve (le QG et les recrues d'abord)
  check(rtask(Planner.plan(view({ stock = rich, reserve = { pick = pk }, recover_floor = 100 }), book)) == nil, "équipe décimée : rien")
  -- la liste out.defend.posts (lue par la pile et l'armée) ne contient jamais le poste
  local has = false
  for _, d in ipairs((pl.defend and pl.defend.posts) or {}) do if d.id == "reserve" then has = true end end
  check(not has, "out.defend.posts ne contient pas le poste (la pile et l'armée ne le voient pas)")
  return failures - f0
end
print("== Planificateur permanent : poste « reserve »")
planner_suite(require("shared.team.planner"))

-- Branchement du plafond de fabrication (script/team/intermediaires.lua, D10) : lu dans la source (le runtime D10 est joué par
-- intermediaires_test avec des doublures ; le plafond des tourelles est prouvé en moteur réel par [FO-INTERMEDIAIRE] ... plafond du poste reserve)
do
  local fh = io.open("script/team/intermediaires.lua", "rb")
  local src = fh and fh:read("*a") or ""
  if fh then fh:close() end
  local ok = src:find("Dsr.stock_cap(placed, a.demand)", 1, true) ~= nil and src:find("p == T.turret", 1, true) ~= nil
    and src:find("if c2 < cap then", 1, true) ~= nil
  if ok then passes = passes + 1 else failures = failures + 1; print("  ECHEC : le plafond des tourelles n'est pas branché au D10") end
end

-- Aucun nom d'objet dans la règle (anti-échelle) : lecture du fichier
do
  local fh = io.open("shared/team/defense_stock.lua", "rb")
  local src = fh and fh:read("*a") or ""
  if fh then fh:close() end
  local bad = {}
  for _, w in ipairs({ "gun%-turret", "firearm%-magazine", "iron%-plate", "copper%-plate", "piercing" }) do
    if src:find(w) then bad[#bad + 1] = w end
  end
  local ok = #src > 0 and #bad == 0
  if ok then passes = passes + 1 else failures = failures + 1; print("  ECHEC : nom d'objet dans la règle : " .. table.concat(bad, ", ")) end
  local pairs_use = src:gsub("%-%-%[%[.-%]%]", ""):find("[^%w_]pairs%(")
  if not pairs_use then passes = passes + 1 else failures = failures + 1; print("  ECHEC : pairs dans la règle") end
end

-- MUTANTS : chacun doit faire échouer la suite
print("== MUTANTS")
local orig = {}
for k, v in pairs(S) do orig[k] = v end
local function restore() for k, v in pairs(orig) do S[k] = v end end
local function mutant(name, patch)
  restore()
  patch()
  local before = failures
  S._silent = true
  local p0 = passes
  local ok = pcall(suite) -- un plantage du mutant compte comme une détection
  S._silent = nil
  local caught = (not ok) or failures > before
  -- les échecs du mutant ne comptent pas comme des échecs du banc : seule sa détection compte
  failures, passes = before, p0
  restore()
  if caught then passes = passes + 1 else failures = failures + 1; print("  ECHEC : mutant non refusé : " .. name) end
end
mutant("réserve ignorée", function() S.surplus = function(s) return s or 0 end end)
mutant("réserve nulle", function() S.RESERVE = 0 end)
mutant("groupe plafonné à 5", function() S.GROUP_CAP = 5 end)
mutant("groupe indépendant du score", function() S.PER = 1e9 end)
mutant("lot illimité", function() S.LOT = 99 end)
mutant("lot d'une tourelle", function() S.LOT = 1 end)
mutant("tourelle isolée permise", function() S.MIN_GROUP = 1 end)
mutant("plafond du poste ignoré", function() S.TEAM_CAP = 1e9 end)
mutant("munitions ignorées", function() S.ammo_plan = function(n) return S.AMMO_FULL end end)
mutant("demi-dose à zéro", function() S.AMMO_LOW = 0 end)
mutant("ordre inversé", function() S.TIER = { qg = 5, prevu = 4, attaque = 3, site = 2, couverture = 1 } end)
mutant("seuil d'attaque nul", function() S.MIN_SCORE = -1 end)
mutant("voulu imposé ignoré", function()
  local gw = orig.group_want
  S.group_want = function(kind, score) return gw(kind, score, nil) end
end)
mutant("distance ignorée", function() S.MAX_DIST = 1e9 end)
mutant("plafond de fabrication ignoré", function() S.stock_cap = function() return 1e9 end end)
mutant("plafond de fabrication sans places", function() S.stock_cap = function(placed, demand) return S.RESERVE + S.TEAM_CAP + S.MALL_MARGIN end end)
mutant("lot sans borne de surplus", function()
  local lot = orig.lot
  S.lot = function(missing, surplus, room, ammo) return lot(missing, 1e9, room, ammo) end
end)
restore()
print("== MUTANTS du planificateur")
local function planner_mutant(name, from, to)
  local fh = io.open("shared/team/planner.lua", "rb")
  local src = fh:read("*a")
  fh:close()
  local a, b = src:find(from, 1, true)
  if not a then failures = failures + 1; print("  ECHEC : motif du mutant introuvable : " .. name); return end
  local mutated = src:sub(1, a - 1) .. to .. src:sub(b + 1)
  local chunk = assert(load(mutated, "=planner_mutant"))
  local Pm = chunk()
  local before, p0 = failures, passes
  S._silent = true
  local ok = pcall(planner_suite, Pm)
  S._silent = nil
  local caught = (not ok) or failures > before
  failures, passes = before, p0
  if caught then passes = passes + 1 else failures = failures + 1; print("  ECHEC : mutant non refusé : " .. name) end
end
planner_mutant("planificateur : réserve ignorée", "Dsr.surplus(avail[T.turret] or 0)", "(avail[T.turret] or 0)")
planner_mutant("planificateur : groupe minimal ignoré", "pk.have + n < Dsr.MIN_GROUP", "false")
planner_mutant("planificateur : pose en équipe décimée", "local gate = Dsr.gate(pk.kind, pri.production_first, decimated)", "local gate = nil") -- s44 : porte dans la règle pure
planner_mutant("planificateur : doublon de tâche", "not rs.busy and not open[\"fortify:reserve\"]", "true")
planner_mutant("planificateur : priorité d'urgence ignorée", "prio = Dsr.prio(pk.kind)", "prio = Dsr.PRIO")
planner_mutant("planificateur : tâche exemptée du rappel", "pos = { x = pk.x, y = pk.y }, cell_key = pk.key, reserve = true", "pos = { x = pk.x, y = pk.y }, cell_key = pk.key, defend = true")

print(string.format("[DEFENSE-STOCK] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
