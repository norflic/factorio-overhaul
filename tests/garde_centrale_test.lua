--[[
  Tests hors jeu du lot CENTRALE-GARDE : shared/team/garde_centrale.lua (règle pure) et son branchement au planificateur permanent
  (shared/team/planner.lua, view.plant). Usage : lua5.2 tests/garde_centrale_test.lua
  Vérifie : K selon les chaudières, tourelle qui GARDE (armée ET toutes les pièces à portée), emplacements à portée, besoin, tâche
  « fortify » du planificateur (coût payé sur le stock, pas de tâche sans matière ni sans besoin ni si déjà ouverte) ; MUTANTS.
]]
package.path = "./?.lua;" .. package.path
local G = require("shared.team.garde_centrale")
local T = require("shared.team.config")
local Book = require("shared.team.book")
local Planner = require("shared.team.planner")
local S = require("shared.team.scale")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local RANGE, LOW = 18, T.turret_ammo_low
-- une centrale d'une chaudière : pompe à l'ouest, chaudière au sud, deux machines au nord (gabarit steam, 5 x 15)
local pieces = { { x = 0, y = 13 }, { x = 4, y = 12 }, { x = 4, y = 6 }, { x = 4, y = 1 } }

section("1. K et gardes")
check(G.wanted(1) == 2 and G.wanted(2) == 3 and G.wanted(5) == 6 and G.wanted(20) == G.MAX, "K : 2 pour une chaudière, 3 pour deux, plafonné à " .. G.MAX)
check(G.wanted(0) == G.MIN and G.wanted(nil) == 2, "K : au moins " .. G.MIN)
check(G.covers(pieces, 4, 7, RANGE), "un point au milieu voit toutes les pièces")
check(not G.covers(pieces, 40, 7, RANGE), "un point à 36 tuiles ne voit pas toutes les pièces")
check(not G.covers({}, 0, 0, RANGE) and not G.covers(nil, 0, 0, RANGE), "aucune pièce : pas de couverture")
local turrets = {
  { x = 8, y = 7, rounds = 20 },    -- garde
  { x = -6, y = 7, rounds = 10 },   -- garde
  { x = 6, y = 7, rounds = 3 },     -- vide : ne garde pas
  { x = 40, y = 7, rounds = 20 },   -- trop loin : ne garde pas
}
check(G.guards(pieces, turrets, RANGE, LOW) == 2, "2 tourelles gardent (armée et à portée de toutes les pièces)")
check(G.guards(pieces, {}, RANGE, LOW) == 0 and G.guards(pieces, nil, RANGE, LOW) == 0, "aucune tourelle : 0")
check(G.guards(pieces, { { x = 8, y = 7, rounds = LOW } }, RANGE, LOW) == 1, "munitions = seuil : armée")
check(G.guards(pieces, { { x = 8, y = 7, rounds = LOW - 1 } }, RANGE, LOW) == 0, "sous le seuil : pas armée")

section("2. Emplacements")
local sites, c = G.sites(pieces, RANGE, 4)
check(#sites == 4 and c ~= nil, "4 emplacements et un centre")
for i, s in ipairs(sites) do check(G.covers(pieces, s.x, s.y, RANGE), "emplacement " .. i .. " : toutes les pièces à portée") end
local sites8 = G.sites(pieces, RANGE, 20)
check(#sites8 == 8, "au plus 8 emplacements")
local wide = { { x = 0, y = 0 }, { x = 30, y = 0 } }
local sw = G.sites(wide, RANGE, 2)
check(#sw == 2, "centrale étendue : emplacements rendus quand même (rayon plancher)")
check(#G.sites({}, RANGE, 4) == 0, "sans pièce : aucun emplacement")

section("3. Besoin")
local need = G.need(pieces, 1, turrets, RANGE, LOW)
check(need.wanted == 2 and need.have == 2 and need.missing == 0, "deux gardes pour une chaudière : rien ne manque")
local need2 = G.need(pieces, 1, {}, RANGE, LOW)
check(need2.missing == 2 and #need2.sites >= 2, "aucune tourelle : 2 manquent")
local need3 = G.need(pieces, 2, { turrets[1] }, RANGE, LOW)
check(need3.wanted == 3 and need3.missing == 2, "deux chaudières, une garde : 2 manquent")
check(G.need({}, 1, {}, RANGE, LOW) == nil, "sans pièce : nil")

section("4. Planificateur permanent : tâche « fortify » de la centrale")
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
local function plant(over)
  local p = { pieces = pieces, boilers = 1, turrets = {}, range = RANGE, low = LOW, fortify = false }
  for k, x in pairs(over or {}) do p[k] = x end
  return p
end
local function guard_task(plan)
  for _, t in ipairs(plan.tasks) do if t.kind == "fortify" and t.outpost == "plant" then return t end end
  return nil
end
local function qty(t, name) for _, it in ipairs(t.items) do if it[1] == name then return it[2] end end return 0 end
local p1 = Planner.plan(view({ stock = rich, plant = plant() }), book)
local t1 = guard_task(p1)
check(t1 ~= nil, "centrale sans garde, matière au stock : tâche fortify « plant »")
check(t1 and qty(t1, "gun-turret") == 2 and qty(t1, T.turret_ammo) == 2 * T.defend_ammo, "coût : 2 tourelles et leurs chargeurs, pris au stock")
check(t1 and t1.sites and #t1.sites >= 2 and t1.pos and t1.range == RANGE, "la tâche porte emplacements, centre et portée")
check(t1 and t1.defend == true and t1.prio == T.defend_prio, "priorité de défense")
local p2 = Planner.plan(view({ stock = rich, plant = plant({ turrets = turrets }) }), book)
check(guard_task(p2) == nil, "deux gardes déjà là : aucune tâche")
local p3 = Planner.plan(view({ stock = rich, plant = plant({ fortify = true }) }), book)
check(guard_task(p3) == nil, "tâche déjà prise (fortify ouverte) : pas de doublon")
local p4 = Planner.plan(view({ stock = rich, plant = plant(), open = { ["fortify:plant"] = true } }), book)
check(guard_task(p4) == nil, "clé déjà ouverte au tableau : pas de doublon")
local p5 = Planner.plan(view({ stock = { ["iron-plate"] = 2000, ["copper-plate"] = 500 }, plant = plant() }), book)
check(guard_task(p5) == nil, "sans tourelle ni chargeurs au stock : pas de tâche (la fabrication est demandée d'abord, jamais de tourelle gratuite)")
local p6 = Planner.plan(view({ stock = rich }), book)
check(guard_task(p6) == nil, "sans centrale (view.plant nil) : aucune tâche")
local p7 = Planner.plan(view({ stock = rich, plant = plant(), defend_first = false }), book)
check(guard_task(p7) == nil, "sans « défendre d'abord » : règle d'avant, aucune tâche")
local p8 = Planner.plan(view({ stock = rich, plant = plant({ boilers = 2 }) }), book)
local t8 = guard_task(p8)
check(t8 and qty(t8, "gun-turret") == 3, "deux chaudières : 3 tourelles voulues")
local p9 = Planner.plan(view({ stock = rich, plant = plant({ turrets = { turrets[1] } }) }), book)
local t9 = guard_task(p9)
check(t9 and qty(t9, "gun-turret") == 1, "une garde déjà là pour une chaudière : une seule de plus")

section("5. Sur-pose bornée, centrale détruite, pièces éloignées, grande centrale")
do
  -- (C) deux tourelles vides à portée occupent leurs places : rien de plus à poser (le ravitaillement s'en charge)
  local empty = { { x = 8, y = 7, rounds = 0 }, { x = -6, y = 7, rounds = 2 } }
  local ne = G.need(pieces, 1, empty, RANGE, LOW)
  check(ne.have == 0 and ne.near == 2 and ne.missing == 0, "deux tourelles vides à portée : 0 gardes armées, 2 places occupées, rien à ajouter")
  local pe = Planner.plan(view({ stock = rich, plant = plant({ turrets = empty }) }), book)
  check(guard_task(pe) == nil, "planificateur : pas de tourelle de plus au-dessus de deux tourelles vides")
  local ne1 = G.need(pieces, 1, { { x = 8, y = 7, rounds = 0 } }, RANGE, LOW)
  check(ne1.missing == 1, "une vide pour deux voulues : une seule de plus")
  -- (A) centrale détruite : plus de pièce => pas de besoin, pas de tâche
  check(G.need({}, 1, {}, RANGE, LOW) == nil, "centrale détruite (aucune pièce vivante) : aucun besoin")
  local pd = Planner.plan(view({ stock = rich, plant = nil }), book)
  check(guard_task(pd) == nil, "centrale détruite (view.plant nil) : aucune tâche")
  -- une seule pièce vivante
  local one = { { x = 3, y = 3 } }
  local n1 = G.need(one, 1, {}, RANGE, LOW)
  check(n1 and n1.missing == 2 and #n1.sites >= 2, "une seule pièce vivante : deux gardes voulues, emplacements trouvés")
  for i, st in ipairs(n1.sites) do check(G.covers(one, st.x, st.y, RANGE), "une pièce : emplacement " .. i .. " à portée") end
  -- (A) pièces éloignées : infaisable, aucune pose répétée
  local apart = { { x = 0, y = 0 }, { x = 80, y = 0 } }
  check(not G.feasible(apart, RANGE) and G.need(apart, 2, {}, RANGE, LOW) == nil, "deux groupes de pièces à 80 tuiles : infaisable, aucun besoin")
  local near2 = { { x = 0, y = 0 }, { x = 40, y = 0 } }
  check(not G.feasible(near2, RANGE) and G.need(near2, 2, {}, RANGE, LOW) == nil, "deux pièces à 40 tuiles : infaisable")
  check(G.feasible(pieces, RANGE), "la centrale du gabarit est faisable")
  -- plus de 6 chaudières : K plafonné, emplacements encore à portée
  local big = {}
  for k = 0, 8 do big[#big + 1] = { x = 1 + 3 * k, y = 12 } ; big[#big + 1] = { x = 1 + 3 * k, y = 6 } ; big[#big + 1] = { x = 1 + 3 * k, y = 1 } end
  big[#big + 1] = { x = -6, y = 12 }
  local nb = G.need(big, 9, {}, RANGE, LOW)
  if nb then
    check(nb.wanted == G.MAX, "9 chaudières : K plafonné à " .. G.MAX)
    for i, st in ipairs(nb.sites) do check(G.covers(big, st.x, st.y, RANGE), "grande centrale : emplacement " .. i .. " à portée") end
  else
    check(not G.feasible(big, RANGE), "grande centrale infaisable : aucun besoin plutôt qu'une pose impossible")
  end
  -- centrale à la limite du faisable : tous les emplacements restent à portée de toutes les pièces
  local edge = { { x = 0, y = 0 }, { x = 33, y = 0 } }  -- centre à 16,5 : portée 18 - 16,5 - 1 = 0,5 : infaisable
  check(not G.feasible(edge, RANGE), "centrale à 33 tuiles de large : infaisable")
  local edge2 = { { x = 0, y = 0 }, { x = 31, y = 0 } } -- centre à 15,5 : 18 - 15,5 - 1 = 1,5 : faisable de justesse
  local sedge = G.sites(edge2, RANGE, 4)
  check(G.feasible(edge2, RANGE), "centrale de 31 tuiles : faisable de justesse")
  local covered = 0
  for _, st in ipairs(sedge) do if G.covers(edge2, st.x, st.y, RANGE) then covered = covered + 1 end end
  check(covered >= 2, "à la limite du faisable, au moins deux emplacements de l'anneau voient toutes les pièces (" .. covered .. " sur 4)")
  -- (B) pause après la mort d'un porteur en route : pas de tâche
  local pp = Planner.plan(view({ stock = rich, plant = plant({ pause = true }) }), book)
  check(guard_task(pp) == nil, "pause (PNJ tué en route vers la centrale) : aucune tâche")
  local pq = Planner.plan(view({ stock = rich, plant = plant({ pause = false }) }), book)
  check(guard_task(pq) ~= nil, "fin de la pause : la tâche revient")
end

section("6. Mutants")
do
  local real_guards = G.guards
  G.guards = function(pc, ts, r, low) -- mutant : tout ce qui est près compte, même vide
    local n = 0
    for _, t in ipairs(ts or {}) do if G.covers(pc, t.x, t.y, r) then n = n + 1 end end
    return n
  end
  local m = G.need(pieces, 1, { { x = 8, y = 7, rounds = 0 }, { x = -6, y = 7, rounds = 0 } }, RANGE, LOW)
  G.guards = real_guards
  local ok = G.need(pieces, 1, { { x = 8, y = 7, rounds = 0 }, { x = -6, y = 7, rounds = 0 } }, RANGE, LOW)
  check(m.have == 2 and ok.have == 0, "mutant « tourelle vide = garde armée » refusé : 0 armée avec des tourelles vides")
  local real_covers = G.covers
  G.covers = function() return true end -- mutant : la portée n'est plus vérifiée
  local far = G.guards(pieces, { { x = 400, y = 400, rounds = 20 } }, RANGE, LOW)
  local far_n = G.near(pieces, { { x = 400, y = 400, rounds = 20 } }, RANGE)
  local far_sites = G.sites({ { x = 0, y = 0 }, { x = 80, y = 0 } }, RANGE, 2)
  local sites_ok = true
  for _, st in ipairs(far_sites) do if not real_covers({ { x = 0, y = 0 }, { x = 80, y = 0 } }, st.x, st.y, RANGE) then sites_ok = false end end
  G.covers = real_covers
  check(far == 1 and far_n == 1 and G.guards(pieces, { { x = 400, y = 400, rounds = 20 } }, RANGE, LOW) == 0
    and G.near(pieces, { { x = 400, y = 400, rounds = 20 } }, RANGE) == 0, "mutant « portée ignorée » refusé : une tourelle à 400 tuiles ne garde pas et n'occupe aucune place")
  check(not sites_ok, "G.covers rejette les emplacements qui ne voient pas toutes les pièces (témoin : ils existent mais ne couvrent pas)")
  local real_wanted = G.wanted
  G.wanted = function() return 0 end -- mutant : K nul
  local nul = G.need(pieces, 1, {}, RANGE, LOW)
  G.wanted = real_wanted
  check(nul.missing == 0 and G.need(pieces, 1, {}, RANGE, LOW).missing == 2, "mutant « K nul » refusé")
  local real_sites = G.sites
  G.sites = function(pc, r, n) return { { x = 400, y = 400 } }, { x = 400, y = 400 } end -- mutant : emplacements hors portée
  local msite = G.need(pieces, 1, {}, RANGE, LOW)
  G.sites = real_sites
  check(not G.covers(pieces, msite.sites[1].x, msite.sites[1].y, RANGE) and G.covers(pieces, G.need(pieces, 1, {}, RANGE, LOW).sites[1].x,
    G.need(pieces, 1, {}, RANGE, LOW).sites[1].y, RANGE), "mutant « emplacements hors portée » refusé")
  local real_near = G.near
  G.near = function() return 0 end -- mutant : les tourelles vides ne tiennent plus leur place (sur-pose)
  local sur = G.need(pieces, 1, { { x = 8, y = 7, rounds = 0 }, { x = -6, y = 7, rounds = 0 } }, RANGE, LOW)
  G.near = real_near
  check(sur.missing == 2 and G.need(pieces, 1, { { x = 8, y = 7, rounds = 0 }, { x = -6, y = 7, rounds = 0 } }, RANGE, LOW).missing == 0,
    "mutant « places vides ignorées » refusé : il reposerait 2 tourelles par-dessus les vides")
end

print(string.format("[GARDE-CENTRALE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
