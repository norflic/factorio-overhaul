--[[
  Tests hors jeu du lot DEFENSE-FRONT : shared/team/front.lua (règle pure : mémoire des attaques, tourelles voulues, couverture des
  laboratoires, emplacements) et son branchement au planificateur permanent (shared/team/planner.lua, view.front).
  Usage : lua5.2 tests/front_test.lua
  Vérifie : mémoire (poids, centre, décroissance à pas fixe, oubli), classement des cellules, tourelles voulues par score avec plafond de
  cellule, REMPLACEMENT d'une tourelle détruite, lots, plafond d'équipe, réserve des cellules attaquées, couverture minimale des
  laboratoires, repos, pause, callback du moteur, emplacements écartés, tâche « fortify » du poste « front » du planificateur ; MUTANTS.
]]
package.path = "./?.lua;" .. package.path
local F = require("shared.team.front")
local T = require("shared.team.config")
local Book = require("shared.team.book")
local Planner = require("shared.team.planner")
local S = require("shared.team.scale")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

section("1. Mémoire des attaques")
local m = F.new(0)
local k1 = F.record(m, 100, 100, F.HIT)   -- cellule (6, 6)
F.record(m, 101, 101, F.HIT)
local cx, cy, key = F.cell_of(100, 100)
check(cx == 6 and cy == 6 and key == "6,6" and k1 == key, "cellule de (100,100) : 6,6")
check(m.cells[key].n == 2 * F.HIT, "deux morts : deux coups")
check(#F.top(m) == 1 and F.top(m)[1].score == 200, "deux coups : la cellule compte (seuil F.MIN_SCORE)")
local m1 = F.new(0)
F.record(m1, 100, 100, F.HIT)
check(#F.top(m1) == 0, "un seul coup : sous le seuil, aucune cellule")
check(F.weight("militaire") > F.weight("logistique") and F.weight("rien") == F.HIT, "une tourelle ou un mur pèse plus qu'un tapis")
local cm = F.new(0)
F.record(cm, 0, 0, 100); F.record(cm, 10, 0, 300)
local t = F.top(cm, 3, 1)[1]
check(math.abs(t.x - 7.5) < 1e-9 and math.abs(t.y) < 1e-9, "centre = moyenne pondérée des lieux de mort (7,5)")
check(F.record(cm, 5, 5, 0) == nil and F.record(cm, 5, 5, -3) == nil, "poids nul ou négatif : rien")

section("2. Décroissance à pas fixe")
local d = F.new(0)
for _ = 1, 10 do F.record(d, 100, 100, F.HIT) end -- 1000
check(F.decay(d, F.STEP - 1) == 0 and d.cells["6,6"].n == 1000, "avant un pas : rien ne bouge")
check(F.decay(d, F.STEP) == 1 and d.cells["6,6"].n == 966, "un pas : x 0,966")
check(F.decay(d, 21 * F.STEP) == 20, "20 pas de plus")
check(d.cells["6,6"].n >= 450 and d.cells["6,6"].n <= 510, "demi-vie d'environ 20 minutes (21 pas : environ la moitié de 1000)")
local cx0 = F.top(d, 3, 1)[1]
check(math.abs(cx0.x - 100) < 1e-6, "le centre ne bouge pas en décroissant")
F.decay(d, 600 * F.STEP)
check(next(d.cells) == nil, "très longtemps après : cellule oubliée")
local d2m = F.new(0)
F.record(d2m, 0, 0, F.HIT)
F.decay(d2m, 5 * F.STEP)
check(next(d2m.cells) ~= nil, "un coup après 5 minutes : encore là (le seuil du classement l'écarte seul)")
-- déterminisme : deux mémoires identiques donnent les mêmes cellules
local function build()
  local mm = F.new(0)
  for i = 1, 30 do F.record(mm, (i * 37) % 200, (i * 91) % 200, F.HIT) end
  F.decay(mm, 3 * F.STEP)
  local out = {}
  for _, c in ipairs(F.top(mm, 10, 1)) do out[#out + 1] = c.key .. "=" .. c.score end
  return table.concat(out, ";")
end
check(build() == build(), "déterministe : deux constructions identiques, même classement")

section("3. Classement et tourelles voulues")
local rk = F.new(0)
for _ = 1, 3 do F.record(rk, 20, 20, F.HIT) end     -- cellule 1,1 : 300
for _ = 1, 6 do F.record(rk, 100, 100, F.HIT) end   -- cellule 6,6 : 600
for _ = 1, 2 do F.record(rk, 300, 300, F.HIT) end   -- cellule 18,18 : 200
for _ = 1, 2 do F.record(rk, -40, 40, F.HIT) end    -- cellule -3,2 : 200
local top = F.top(rk)
check(#top == F.MAX_CELLS and top[1].key == "6,6" and top[2].key == "1,1", "les plus attaquées d'abord, au plus F.MAX_CELLS")
check(top[3].key == "-3,2", "égalité de score : l'ordre des coordonnées (cx puis cy)")
check(F.want(200) == F.BASE and F.want(F.PER_TURRET * 2 + 200) == F.BASE + 2, "une tourelle de plus par tranche de score")
check(F.want(1e9) == F.CELL_CAP, "plafond par cellule")
check(F.want(900) >= F.want(300), "plus attaquée : jamais moins de tourelles")

section("4. Plan : la cellule attaquée reçoit ses tourelles")
local cells = { { key = "6,6", cx = 6, cy = 6, score = 600, x = 100, y = 100 } }
local p0 = F.plan({ cells = cells, turrets = {} })
check(p0.pick and p0.pick.key == "6,6" and p0.pick.have == 0 and p0.pick.want == F.want(600), "aucune tourelle : la cellule est choisie")
check(p0.pick and p0.pick.count == math.min(F.want(600), F.BATCH), "lot d'au plus F.BATCH tourelles")
check(p0.pick and #p0.pick.sites == 8, "8 emplacements candidats")
local near = { { x = 105, y = 100 }, { x = 95, y = 100 } }
local p1 = F.plan({ cells = cells, turrets = near })
check(p1.pick and p1.pick.have == 2 and p1.pick.want == 3 and p1.pick.count == 1, "deux tourelles à portée, trois voulues : une de plus")
local p1b = F.plan({ cells = cells, turrets = { near[1], near[2], { x = 100, y = 108 } } })
check(p1b.pick == nil, "trois tourelles à portée : rien à poser")
-- REMPLACEMENT : une tourelle détruite fait redescendre le compte
local p1c = F.plan({ cells = cells, turrets = { near[1], { x = 100, y = 108 } } })
check(p1c.pick and p1c.pick.count == 1, "une tourelle détruite : elle est remplacée")
local far = F.plan({ cells = cells, turrets = { { x = 160, y = 100 }, { x = 100, y = 170 }, { x = 20, y = 20 } } })
check(far.pick and far.pick.have == 0, "les tourelles lointaines ne comptent pas")
check(F.plan({ cells = cells, turrets = {}, pause = true }).pick == nil, "pause : rien")
check(F.plan({ cells = cells, turrets = {}, rest = { ["6,6"] = true } }).pick == nil, "cellule au repos : rien")
local allowed = {}
local pa = F.plan({ cells = cells, turrets = {}, allow = function(r) allowed[#allowed + 1] = r.key; return false end })
check(pa.pick == nil and allowed[1] == "6,6", "le moteur refuse (ennemi sur place, aucun bâtiment) : rien")
local calls = 0
F.plan({ cells = cells, turrets = { near[1], near[2], { x = 100, y = 108 } }, allow = function() calls = calls + 1; return true end })
check(calls == 0, "cellule déjà servie : le moteur n'est pas interrogé")
-- deuxième cellule servie quand la première est refusée
local two = { cells[1], { key = "1,1", cx = 1, cy = 1, score = 300, x = 20, y = 20 } }
local p2 = F.plan({ cells = two, turrets = {}, allow = function(r) return r.key == "1,1" end })
check(p2.pick and p2.pick.key == "1,1", "la première refusée : la suivante est servie")
local p2b = F.plan({ cells = two, turrets = {} })
check(p2b.pick.key == "6,6", "la plus attaquée passe d'abord")

section("5. Plafonds")
local p3 = F.plan({ cells = cells, turrets = {}, placed = F.TEAM_CAP })
check(p3.pick == nil and p3.left == 0, "plafond d'équipe atteint : rien")
local p3b = F.plan({ cells = cells, turrets = {}, placed = F.TEAM_CAP - 1 })
check(p3b.pick and p3b.pick.count == 1 and p3b.left == 1, "une place sous le plafond : un seul")
local p3c = F.plan({ cells = { { key = "6,6", cx = 6, cy = 6, score = 1e6, x = 100, y = 100 } }, turrets = { near[1], near[2], { x = 100, y = 108 }, { x = 100, y = 92 }, { x = 108, y = 100 } } })
check(p3c.pick == nil, "plafond par cellule : 5 tourelles à portée, rien de plus même au score maximal")

section("6. Couverture minimale des laboratoires")
local labs = { { x = 50, y = 50 }, { x = 52, y = 50 }, { x = 56, y = 52 }, { x = 200, y = 200 } }
local cov = F.cover_clusters(labs)
check(#cov == 2 and cov[1].n == 3 and cov[1].key == "3,3", "trois laboratoires d'une cellule : un groupe, le plus fourni d'abord")
check(math.abs(cov[1].x - 158 / 3) < 1e-9, "centre du groupe = moyenne")
local many = {}
for i = 1, 10 do many[#many + 1] = { x = i * 40, y = 0 } end
check(#F.cover_clusters(many) == F.MAX_COVER, "au plus F.MAX_COVER groupes")
check(#F.cover_clusters({}) == 0 and #F.cover_clusters(nil) == 0, "sans laboratoire : aucun groupe")
local pc = F.plan({ cover = cov, turrets = {} })
check(pc.pick and pc.pick.kind == "couverture" and pc.pick.key == "3,3" and pc.pick.want == F.COVER_WANT, "laboratoires nus : couverture demandée")
check(pc.pick and pc.pick.count == F.COVER_WANT and F.COVER_WANT <= F.BATCH, "(cohérence : la couverture tient dans un lot)")
local pcc = F.plan({ cover = cov, turrets = { { x = 52, y = 48 }, { x = 48, y = 52 } } })
check(pcc.pick and pcc.pick.key == "12,12", "premier groupe couvert : on passe au suivant")
check(F.plan({ cover = { cov[1] }, turrets = { { x = 52, y = 48 }, { x = 48, y = 52 } } }).pick == nil, "couvert : rien")
-- une cellule attaquée passe avant la couverture
local pm = F.plan({ cells = cells, cover = cov, turrets = {} })
check(pm.pick.kind == "attaque", "la cellule attaquée passe avant la couverture")
-- la couverture ne prend pas les dernières places
local pr = F.plan({ cover = cov, turrets = {}, placed = F.TEAM_CAP - F.ATTACK_RESERVE })
check(pr.pick == nil, "il ne reste que la réserve des cellules attaquées : la couverture ne la prend pas")
local pr2 = F.plan({ cells = cells, cover = cov, turrets = {}, placed = F.TEAM_CAP - F.ATTACK_RESERVE })
check(pr2.pick and pr2.pick.kind == "attaque", "...mais une cellule attaquée la prend")
-- une cellule à la fois attaquée et couverte n'est pas doublée
local same = F.plan({ cells = { { key = "3,3", cx = 3, cy = 3, score = 200, x = 52, y = 51 } }, cover = { cov[1] }, turrets = { { x = 52, y = 52 }, { x = 54, y = 52 } } })
check(same.pick == nil, "attaque et couverture sur la même cellule : un seul compte (deux tourelles = voulues)")

section("7. Emplacements")
local s0 = F.sites(100, 100, {})
check(#s0 == 8 and s0[1].x == 106 and s0[1].y == 100, "sans tourelle : l'ordre des directions (est d'abord)")
local s1 = F.sites(100, 100, { { x = 106, y = 100 } })
check(not (s1[1].x == 106 and s1[1].y == 100), "une tourelle à l'est : le premier emplacement s'en écarte")
check(s1[1].x == 94 and s1[1].y == 100, "le plus écarté d'abord (ouest)")
check(F.accepts(100, 100, 106, 100) and not F.accepts(100, 100, 140, 100), "une pose lointaine est refusée")
local same_a, same_b = F.sites(1, 2, near), F.sites(1, 2, near)
check(same_a[1].x == same_b[1].x and same_a[3].y == same_b[3].y, "déterministe")

section("8. Planificateur permanent : tâche « fortify » du poste « front »")
local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)
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
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local rich = { ["iron-plate"] = 2000, ["copper-plate"] = 500, ["gun-turret"] = 6, [T.turret_ammo] = 200, coal = 100, stone = 100 }
local function front_task(plan)
  for _, t in ipairs(plan.tasks) do if t.kind == "fortify" and t.outpost == "front" then return t end end
  return nil
end
local function qty(t, name) for _, it in ipairs(t.items) do if it[1] == name then return it[2] end end return 0 end
local fv = { pick = p0.pick, busy = false }
local q1 = Planner.plan(view({ stock = rich, front = fv }), book)
local ft = front_task(q1)
check(ft ~= nil, "cellule à renforcer, matière au stock : tâche fortify « front »")
check(ft and qty(ft, "gun-turret") == p0.pick.count and qty(ft, T.turret_ammo) == p0.pick.count * T.defend_ammo, "coût : tourelles et chargeurs pris au stock")
check(ft and ft.cell_key == "6,6" and ft.pos and ft.pos.x == 100 and ft.sites and #ft.sites == 8, "la tâche porte la cellule, son centre et les emplacements")
check(ft and ft.defend == true and ft.prio == T.defend_prio, "priorité de défense")
check(front_task(Planner.plan(view({ stock = rich, front = { pick = p0.pick, busy = true } }), book)) == nil, "tâche déjà prise : pas de doublon")
check(front_task(Planner.plan(view({ stock = rich, front = fv, open = { ["fortify:front"] = true } }), book)) == nil, "clé déjà ouverte : pas de doublon")
check(front_task(Planner.plan(view({ stock = { ["iron-plate"] = 2000, ["copper-plate"] = 500 }, front = fv }), book)) == nil, "sans tourelle ni chargeurs au stock : pas de tâche gratuite")
check(front_task(Planner.plan(view({ stock = rich }), book)) == nil, "sans front : aucune tâche")
check(front_task(Planner.plan(view({ stock = rich, front = { busy = false } }), book)) == nil, "front sans cellule à renforcer : aucune tâche")
check(front_task(Planner.plan(view({ stock = rich, front = fv, defend_first = false }), book)) == nil, "sans « défendre d'abord » : règle d'avant")

section("9. Mutants")
-- mutant : la décroissance ne fait rien -> une cellule ancienne reste attaquée à jamais
local real_decay = F.decay
F.decay = function() return 0 end
local mm = F.new(0)
for _ = 1, 2 do F.record(mm, 0, 0, F.HIT) end
F.decay(mm, 600 * F.STEP)
local forever = #F.top(mm) == 1
F.decay = real_decay
check(forever and next((function() local z = F.new(0); F.record(z, 0, 0, F.HIT); F.record(z, 0, 0, F.HIT); F.decay(z, 600 * F.STEP); return z.cells end)()) == nil, "mutant « pas de décroissance » refusé")
-- mutant : le plafond d'équipe est ignoré
local real_cap = F.TEAM_CAP
F.TEAM_CAP = 1e9
local mc = F.plan({ cells = cells, turrets = {}, placed = real_cap })
F.TEAM_CAP = real_cap
check(mc.pick ~= nil and F.plan({ cells = cells, turrets = {}, placed = real_cap }).pick == nil, "mutant « plafond d'équipe ignoré » refusé")
-- mutant : plus de réserve pour les cellules attaquées
local real_res = F.ATTACK_RESERVE
F.ATTACK_RESERVE = 0
local mr = F.plan({ cover = cov, turrets = {}, placed = F.TEAM_CAP - real_res })
F.ATTACK_RESERVE = real_res
check(mr.pick ~= nil and F.plan({ cover = cov, turrets = {}, placed = F.TEAM_CAP - real_res }).pick == nil, "mutant « réserve ignorée » refusé")
-- mutant : le compte des tourelles à portée ignore la distance (tout compte) -> plus de remplacement
local real_count = F.count_near
F.count_near = function(ts) return #ts end
local mn = F.plan({ cells = cells, turrets = { { x = 900, y = 900 }, { x = 901, y = 900 }, { x = 902, y = 900 } } })
F.count_near = real_count
check(mn.pick == nil and F.plan({ cells = cells, turrets = { { x = 900, y = 900 }, { x = 901, y = 900 }, { x = 902, y = 900 } } }).pick ~= nil, "mutant « distance ignorée » refusé")
-- mutant : seuil de score ignoré -> un coup isolé déclenche une pose
local real_min = F.MIN_SCORE
F.MIN_SCORE = 0
local mt = #F.top(m1)
F.MIN_SCORE = real_min
check(mt == 1 and #F.top(m1) == 0, "mutant « seuil ignoré » refusé")
-- mutant : le moteur n'est pas consulté
local ma = F.plan({ cells = cells, turrets = {}, allow = nil })
check(ma.pick ~= nil and F.plan({ cells = cells, turrets = {}, allow = function() return false end }).pick == nil, "le callback du moteur est bien appliqué")
-- mutant : classement inversé -> la moins attaquée d'abord
local real_top = F.top
F.top = function(mem, n, min) local l = real_top(mem, n, min); table.sort(l, function(a, b) return a.score < b.score end); return l end
local inv = F.top(rk)
F.top = real_top
check(inv[1].score <= inv[#inv].score and real_top(rk)[1].score > real_top(rk)[#real_top(rk)].score, "mutant « classement inversé » refusé")


---------------------------------------------------------------------------------------------------
section("10. Lot DEFENSE-FACTIONS (D3 poste du QG, D4 commande partielle et plancher, D5 front avant le reste)")
-- D3 : poste de tourelles du QG d'une faction
check(F.hq_post({ turrets = 4, peak = 4, ago = 100 }) == 0, "D3 : QG attaqué mais aucune tourelle perdue : aucun poste")
check(F.hq_post({ turrets = 1, peak = 4, ago = nil }) == 0, "D3 : tourelle perdue mais QG jamais attaqué : aucun poste")
check(F.hq_post({ turrets = 1, peak = 4, ago = F.HQ_MEMORY + 1 }) == 0, "D3 : attaque trop ancienne : aucun poste")
check(F.hq_post({ turrets = 1, peak = 4, ago = 600 }) == F.HQ_POST and F.HQ_POST == 2, "D3 : tourelle perdue ET QG attaqué : 2 tourelles voulues")
check(F.hq_post({ turrets = 0, peak = 0, ago = 600 }) == 0, "D3 : jamais eu de tourelle au QG : aucun poste")
local function task_of(plan, id)
  for _, t in ipairs(plan.tasks) do if t.kind == "fortify" and t.outpost == id then return t end end
  return nil
end
local hq_stock = { ["gun-turret"] = 2, [T.turret_ammo] = 40, ["iron-plate"] = 0 }
local th = task_of(Planner.plan(view({ stock = hq_stock, hq_turrets = 1, hq_defend = F.HQ_POST }), book), "hq")
check(th and qty(th, "gun-turret") == 1, "D3 : poste du QG de 2 tourelles, une présente : une seule commandée")
check(task_of(Planner.plan(view({ stock = hq_stock, hq_turrets = 1, hq_defend = 0 }), book), "hq") == nil, "D3 : poste à 0 : aucune tâche au QG")
check(task_of(Planner.plan(view({ stock = hq_stock, hq_turrets = 2, hq_defend = F.HQ_POST }), book), "hq") == nil, "D3 : deux tourelles présentes : rien de plus")

-- D4 : plancher du front
local fi, fc, red = F.floors(F.HIGH_SCORE, true, 150, 30)
check(fi == F.FLOOR_IRON and fc == F.FLOOR_COPPER and red == true and fi > 0, "D4 : score élevé et fer produit : plancher réduit, jamais 0")
local ni, nc, nred = F.floors(F.HIGH_SCORE, false, 150, 30)
check(ni == 150 and nc == 30 and nred == false, "D4 : fer plus produit (remarque du DC) : plancher ordinaire, le coffre n'est pas vidé")
local li, _, lred = F.floors(F.HIGH_SCORE - 1, true, 150, 30)
check(li == 150 and lred == false, "D4 : score faible : plancher ordinaire")
check(select(1, F.floors(F.HIGH_SCORE, true, 40, 30)) == 40, "D4 : le plancher ordinaire plus bas que le réduit est gardé")

-- D4 : commande partielle et plancher dans le planificateur
local hi_cells = { { key = "6,6", cx = 6, cy = 6, score = 400, x = 100, y = 100 } }
local ph = F.plan({ cells = hi_cells, turrets = {} })
local function plan_front(stock, over)
  local v = view({ stock = stock, front = { pick = ph.pick, busy = false } })
  for k, x in pairs(over or {}) do v[k] = x end
  return Planner.plan(v, book)
end
local function crafts_of(plan, tag)
  local n = 0
  for _, t in ipairs(plan.tasks) do if t.kind == "craft" and t.tag == tag then n = n + 1 end end
  return n
end
local function front_post(plan)
  for _, d in ipairs(plan.defend and plan.defend.posts or {}) do if d.id == "front" then return d end end
  return nil
end
local prod = { { id = "o1", kind = "iron", drills = 8, turrets = 2, output = 0, idle_ticks = 0, has_task = false, full = false, coal_needed = 0 } }
local cu = 100
-- fer 250, sans production : la commande complète (240 fer + plancher 150) n'est pas payable, la partielle (80 fer) l'est
local a250 = plan_front({ ["iron-plate"] = 250, ["copper-plate"] = cu })
check(front_post(a250) and front_post(a250).why == "fabrication" and front_post(a250).partial == true and crafts_of(a250, "defense") >= 2,
  "D4 : fer 250 : commande PARTIELLE fabriquée (1 tourelle, 10 chargeurs) au lieu du tout-ou-rien")
-- fer 200, sans production : même la partielle ne passe pas (200 - 150 = 50 < 80) : cause « fer » avec le manque en chiffres
local a200 = plan_front({ ["iron-plate"] = 200, ["copper-plate"] = cu })
local f200 = front_post(a200)
check(f200 and f200.why == "fer" and f200.raw and f200.raw[T.outposts.iron.product] == 30 and crafts_of(a200, "defense") == 0,
  "D4 : fer 200 sous le plancher : rien n'est fabriqué, le journal dit « fer » et le manque (30)")
-- le fer est produit et le score est élevé : plancher 60, 200 suffit pour la partielle (80 + 60 = 140, après les besoins plus urgents)
local b200 = plan_front({ ["iron-plate"] = 200, ["copper-plate"] = cu }, { outposts = prod })
check(front_post(b200) and front_post(b200).reduced == true and front_post(b200).floor_i == F.FLOOR_IRON and front_post(b200).why == "fabrication"
  and crafts_of(b200, "defense") >= 2, "D4 : fer produit, score élevé, fer 200 : plancher réduit, partielle fabriquée")
-- même fer, mais plus de production : le plancher ordinaire protège le coffre (remarque du DC)
local c200 = plan_front({ ["iron-plate"] = 200, ["copper-plate"] = cu })
check(front_post(c200) and front_post(c200).reduced == nil and crafts_of(c200, "defense") == 0 and front_post(c200).why == "fer",
  "D4 : fer 200 sans production de fer : la défense ne vide pas le coffre")
-- jamais sous le plancher réduit
local d100 = plan_front({ ["iron-plate"] = 100, ["copper-plate"] = cu }, { outposts = prod })
check(front_post(d100) and front_post(d100).why == "fer" and crafts_of(d100, "defense") == 0, "D4 : fer 100 : sous 60 + 80, rien (le plancher réduit reste un plancher)")
-- score faible : plancher ordinaire même avec production
local low = F.plan({ cells = { { key = "6,6", cx = 6, cy = 6, score = 200, x = 100, y = 100 } }, turrets = {} })
local e = Planner.plan(view({ stock = { ["iron-plate"] = 200, ["copper-plate"] = cu }, outposts = prod, front = { pick = low.pick, busy = false } }), book)
check(front_post(e) and front_post(e).reduced == nil and crafts_of(e, "defense") == 0, "D4 : score faible : plancher ordinaire")
-- la partielle est posée quand le stock la contient (1 tourelle, 10 chargeurs), sans attendre la commande complète
local g = plan_front({ ["iron-plate"] = 150, ["copper-plate"] = cu, ["gun-turret"] = 1, [T.turret_ammo] = 10 })
local gt = task_of(g, "front")
check(gt and qty(gt, "gun-turret") == F.PARTIAL_COUNT and qty(gt, T.turret_ammo) == F.PARTIAL_COUNT * F.PARTIAL_AMMO,
  "D4 : 1 tourelle et 10 chargeurs au stock : tâche « fortify front » partielle")
-- la commande complète reste la règle quand elle est payable
local h = plan_front({ ["iron-plate"] = 2000, ["copper-plate"] = 500, ["gun-turret"] = 2, [T.turret_ammo] = 40 })
local ht = task_of(h, "front")
check(ht and qty(ht, "gun-turret") == 2 and qty(ht, T.turret_ammo) == 2 * T.defend_ammo, "D4 : stock complet : commande complète, comme avant")
-- D1 : recette fermée = cause « recette »
local closed_recipes = {}
for name, rec in pairs(dofile("tests/fixtures/recipes.lua")) do if name ~= "gun-turret" then closed_recipes[name] = rec end end
local closed_book = Book.new(closed_recipes)
local cv = view({ stock = { ["iron-plate"] = 2000, ["copper-plate"] = 500 }, front = { pick = ph.pick, busy = false } })
local cp = Planner.plan(cv, closed_book)
check(front_post(cp) and front_post(cp).why == "recette" and task_of(cp, "front") == nil, "D1 : recette de la tourelle fermée : cause « recette », aucune tâche")
local opened = plan_front({ ["iron-plate"] = 2000, ["copper-plate"] = 500 })
check(front_post(opened) and front_post(opened).why == "fabrication", "D1 : recette ouverte et fer suffisant : « fabrication »")

-- D5 : F.plan, le moteur est consulté AVANT la coupe à F.MAX_CELLS
local four = {
  { key = "9,9", cx = 9, cy = 9, score = 900, x = 150, y = 150 }, { key = "8,8", cx = 8, cy = 8, score = 800, x = 130, y = 130 },
  { key = "7,7", cx = 7, cy = 7, score = 700, x = 110, y = 110 }, { key = "6,6", cx = 6, cy = 6, score = 600, x = 100, y = 100 },
}
local pf = F.plan({ cells = four, turrets = {}, allow = function(r) return r.key == "6,6" end })
check(pf.pick and pf.pick.key == "6,6", "D5 : les 3 plus attaquées refusées par le moteur : la 4e est servie")
local skips = {}
for _, r in ipairs(pf.rows) do skips[r.key] = r.skip end
check(skips["9,9"] == "refus" and skips["8,8"] == "refus" and skips["6,6"] == nil, "D5 : les lignes disent pourquoi (refus)")
check(F.plan({ cells = four, turrets = {}, allow = function() return false end }).pick == nil, "D5 : toutes refusées : rien")
local pk3 = F.plan({ cells = four, turrets = {} })
local nrows = 0
for _, r in ipairs(pk3.rows) do if r.kind == "attaque" then nrows = nrows + 1 end end
check(nrows == F.MAX_CELLS and pk3.pick.key == "9,9", "D5 : toutes autorisées : coupe à F.MAX_CELLS cellules, la plus attaquée d'abord")
local rest_plan = F.plan({ cells = four, turrets = {}, rest = { ["9,9"] = true, ["8,8"] = true, ["7,7"] = true } })
check(rest_plan.pick == nil, "D5 : trois cellules au REPOS comptent dans la coupe (temporaire) : la 4e n'est pas servie")
local sk = {}
for _, r in ipairs(rest_plan.rows) do sk[r.key] = r.skip end
check(sk["9,9"] == "repos", "D5 : cause « repos » écrite")
check(F.plan({ cells = four, turrets = {}, placed = F.TEAM_CAP }).rows[1].skip == "plafond", "D1 : plafond d'équipe écrit")
check(F.plan({ cells = cells, turrets = { near[1], near[2], { x = 100, y = 108 } } }).rows[1].skip == "servie", "D1 : cellule servie écrite")
-- D5 : QG proche
local ph2 = F.plan({ cells = hi_cells, turrets = {}, hq = { x = 100 + F.NEAR_HQ - 1, y = 100 } })
local ph3 = F.plan({ cells = hi_cells, turrets = {}, hq = { x = 100 + F.NEAR_HQ + 1, y = 100 } })
check(ph2.pick.near_hq == true and ph3.pick.near_hq == false and ph.pick.near_hq == nil, "D5 : cellule à moins de F.NEAR_HQ du QG marquée, plus loin non, sans QG rien")
-- D5 : ordre des postes dans le planificateur (stock pour un seul poste)
local one_post = { ["gun-turret"] = 2, [T.turret_ammo] = 40, ["iron-plate"] = 0, ["copper-plate"] = 0 }
local und = { { id = "o1", kind = "iron", drills = 8, turrets = 1, output = 0, idle_ticks = 0, has_task = false, full = false, coal_needed = 0 } }
local pn = Planner.plan(view({ stock = one_post, outposts = und, front = { pick = ph2.pick, busy = false } }), book)
local pfar = Planner.plan(view({ stock = one_post, outposts = und, front = { pick = ph3.pick, busy = false } }), book)
check(task_of(pn, "front") ~= nil and task_of(pn, "o1") == nil, "D5 : cellule à moins de 40 tuiles du QG : le front est servi AVANT l'avant-poste non défendu")
check(task_of(pfar, "o1") ~= nil and task_of(pfar, "front") == nil, "D5 : cellule lointaine : l'avant-poste non défendu d'abord, comme avant")

-- mutants du lot
local real_fl = F.floors
F.floors = function(_, _, bi, bc) return bi, bc, false end
local m1 = plan_front({ ["iron-plate"] = 200, ["copper-plate"] = cu }, { outposts = prod })
F.floors = real_fl
check(crafts_of(m1, "defense") == 0 and crafts_of(b200, "defense") >= 2, "mutant « plancher jamais réduit » refusé")
local real_pc = F.PARTIAL_AMMO
F.PARTIAL_AMMO = 1000
local m2 = plan_front({ ["iron-plate"] = 250, ["copper-plate"] = cu })
F.PARTIAL_AMMO = real_pc
check(not (front_post(m2) and front_post(m2).why == "fabrication") and front_post(a250).why == "fabrication", "mutant « commande partielle hors de prix (retour au tout-ou-rien) » refusé")
local real_hp = F.hq_post
F.hq_post = function(a) return (a.turrets or 0) < (a.peak or 0) and F.HQ_POST or 0 end
local m3 = F.hq_post({ turrets = 1, peak = 4, ago = nil })
F.hq_post = real_hp
check(m3 == F.HQ_POST and F.hq_post({ turrets = 1, peak = 4, ago = nil }) == 0, "mutant « QG pas attaqué ignoré » refusé")
-- mutant : la coupe à 3 cellules AVANT le moteur (comportement d'avant le lot) ne sert rien quand les 3 premières sont refusées
local cut_first = F.plan({ cells = { four[1], four[2], four[3] }, turrets = {}, allow = function(r) return r.key == "6,6" end })
check(cut_first.pick == nil and pf.pick ~= nil, "mutant « coupe avant le moteur » refusé (c'était le défaut d'avant le lot)")

print(string.format("[FRONT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
