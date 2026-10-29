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

print(string.format("[FRONT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
