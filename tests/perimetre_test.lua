--[[
  Lot PERIMETRE : banc HORS JEU de la règle shared/team/perimetre.lua (défense en périmètres et points sensibles). Lancement :
  lua5.2 tests/perimetre_test.lua (racine du mod). Mesure de couverture, cœur, anneaux emboîtés, postes d'anneau, postes « point »,
  relevé complet, choix du poste, emplacements, budget ; puis des mutants de la règle, chacun doit faire échouer au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path

local function read_src(path)
  local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s
end
local SRC = read_src("shared/team/perimetre.lua")
local function load_pe(src) return assert(load(src, "@shared.team.perimetre"))() end

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end
local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

--- La suite complète contre un module Pe ; rend la liste des échecs (messages).
local function suite(Pe)
  local fails = {}
  local n = 0
  local function check(cond, msg) n = n + 1 if not cond then fails[#fails + 1] = msg end end

  -- 1. poids et rayon
  check(Pe.role_w("fabrique") == 3 and Pe.role_w("qg") == 20 and Pe.role_w("logistique") == 0 and Pe.role_w("foreuse") == 1, "poids des rôles")
  check(near(Pe.cover_r(18), 14.4), "rayon couvert = 80 % de la portée")

  -- 2. couverture (armée / toutes)
  local pts = { { x = 0, y = 0, role = "fabrique" }, { x = 100, y = 0, role = "foreuse" }, { x = 50, y = 50, role = "qg" },
    { x = -14.4, y = 0, role = "labo" }, { x = 0, y = 300, role = "logistique" } }
  local tur = { { x = 0, y = 0, range = 18, armed = true }, { x = 100, y = 5, range = 18, armed = false } }
  local ca = Pe.coverage(pts, tur, true)
  check(ca.w == 27 and ca.n == 4, "couverture : poids et nombre des points sensibles (logistique exclue)")
  check(ca.wc == 6 and ca.nc == 2 and ca.cats.fab.c == 1 and ca.cats.labo.c == 1, "couverture armée : bord compris (14,4), tourelle vide exclue")
  local cb = Pe.coverage(pts, tur, false)
  check(cb.wc == 7 and cb.cats.foreuse.c == 1, "couverture de toutes les tourelles : la vide compte")
  check(Pe.pct(6, 27) == 22 and Pe.pct(0, 0) == 100, "pourcentage arrondi")

  -- 3. isolées
  check(Pe.isolated({ { x = 0, y = 0, range = 18 }, { x = 10, y = 0, range = 18 }, { x = 100, y = 100, range = 18 } }) == 1, "tourelles isolées")

  -- 4. cœur : chaîne de proche en proche
  local box, nc = Pe.core_box({ { x = 20, y = 0 }, { x = 45, y = 0 }, { x = 100, y = 0 }, { x = 0, y = -30 } }, { x = 0, y = 0 })
  check(nc == 3 and box.x0 == 0 and box.y0 == -30 and box.x1 == 45 and box.y1 == 0, "cœur : (45,0) relié par (20,0), (100,0) dehors")

  -- 5. anneau voulu, avec et sans mur
  local rb = Pe.ring_box({ x0 = 0, y0 = 0, x1 = 40, y1 = 20 })
  check(rb.x0 == -5 and rb.y0 == -5 and rb.x1 == 45 and rb.y1 == 25, "anneau = cœur + marge 5")
  local wb, isw = Pe.ring_box({ x0 = 0, y0 = 0, x1 = 1, y1 = 1 }, { -20, -20, 20, 20 })
  check(isw and wb.x0 == -16 and wb.y0 == -16 and wb.x1 == 17 and wb.y1 == 17, "anneau du mur : rentré de 3 tuiles (derrière le mur)")

  -- 6. anneaux emboîtés figés
  local rings = {}
  local w1, i1 = Pe.rings_update(rings, { x0 = 0, y0 = 0, x1 = 40, y1 = 40 }, nil, 10)
  local w2 = Pe.rings_update(rings, { x0 = 0, y0 = 0, x1 = 50, y1 = 40 }, nil, 20)
  local w3, i3 = Pe.rings_update(rings, { x0 = 6, y0 = 0, x1 = 60, y1 = 40 }, nil, 30)
  check(w1 == "nouveau" and i1 == 1 and w2 == nil, "anneau 1 né, croissance de 10 tuiles : rien")
  check(w3 == "nouveau" and i3 == 2 and rings[2].x0 == -5 and rings[2].x1 == 65, "anneau 2 né à 20 tuiles de croissance, union (ouest gardé)")
  check(rings[1].x1 == 45, "anneau 1 figé")
  local w4 = Pe.rings_update(rings, { x0 = 0, y0 = 0, x1 = 90, y1 = 40 }, nil, 40)
  local w5, i5 = Pe.rings_update(rings, { x0 = 0, y0 = 0, x1 = 120, y1 = 40 }, nil, 50)
  check(w4 == "nouveau" and #rings == 3 and w5 == "remplace" and i5 == 3 and #rings == 3 and rings[3].x1 == 125, "au plus 3 anneaux, le dernier remplacé")
  local w6, i6 = Pe.rings_update(rings, { x0 = 0, y0 = 0, x1 = 120, y1 = 40 }, { -30, -30, 50, 50 }, 60)
  local w7 = Pe.rings_update(rings, { x0 = 0, y0 = 0, x1 = 120, y1 = 40 }, { -30, -30, 50, 50 }, 70)
  check(w6 == "mur" and i6 == 1 and rings[1].wall == true and rings[1].x0 == -26 and w7 == nil, "le mur devient l'anneau 1, une fois")

  -- 7. postes d'anneau
  local rp = Pe.ring_posts({ x0 = 0, y0 = 0, x1 = 56, y1 = 56 }, 14.4)
  check(#rp == 8, "anneau de 56 : 4 coins + 4 milieux (" .. #rp .. ")")
  local corners = 0
  for _, p in ipairs(rp) do if p.corner then corners = corners + 1 end end
  check(corners == 4 and rp[1].x == 0 and rp[1].y == 0 and rp[2].x == 28 and rp[2].y == 0, "coins, puis milieu du côté nord")
  check(near(rp[1].tx, math.sqrt(0.5)) and near(rp[1].ty, -math.sqrt(0.5)) and near(rp[1].nx, math.sqrt(0.5)) and near(rp[1].ny, math.sqrt(0.5)),
    "coin NO : paire en travers de la diagonale, normale vers l'intérieur")
  local big = Pe.ring_posts({ x0 = 0, y0 = 0, x1 = 100, y1 = 60 }, 14.4)
  local maxgap = 0
  for i = 1, #big do
    local a, b = big[i], big[i == #big and 1 or i + 1]
    maxgap = math.max(maxgap, dist(a, b))
  end
  check(maxgap <= 28.8 + 1e-6 and #big == 14, "pas des postes <= 2 × rc tout le tour (" .. maxgap .. ", " .. #big .. ")")

  -- 8. repère et emplacements d'un poste « point »
  local tx, ty, nx, ny = Pe.frame(10, 0, { x = 0, y = 0 })
  check(near(tx, 0) and near(ty, -1) and near(nx, -1) and near(ny, 0), "repère : normale vers le QG, tangente perpendiculaire")
  local s = Pe.sites({ x = 10, y = 0, tx = tx, ty = ty, nx = nx, ny = ny })
  check(near(s[1].x, 10) and near(s[1].y, -3.5) and near(s[2].y, 3.5) and near(dist(s[1], s[2]), 7), "paire à ±3,5 : écart 7 (>= 6, < portée)")
  check(near(s[3].x, 3) and near(s[4].x, 17) and s[5].x == 10, "troisième emplacement en arrière, puis en avant, puis le centre")
  local f0 = { Pe.frame(0, 0, { x = 0, y = 0 }) }
  check(f0[1] == 1 and f0[4] == 1, "repère au QG : défaut")
  check(Pe.accepts({ x = 0, y = 0 }, 8, 0) and not Pe.accepts({ x = 0, y = 0 }, 8.1, 0), "pose refusée au-delà de 8 tuiles")

  -- 9. postes « point »
  local P = { { x = 40, y = 0, role = "fabrique" }, { x = 42, y = 0, role = "fabrique" }, { x = 44, y = 2, role = "fabrique" },
    { x = 0, y = 60, role = "fabrique" }, { x = 3, y = 60, role = "fabrique" }, { x = -40, y = 0, role = "fabrique" } }
  local T = { { x = -35, y = 0, range = 18 } }
  local pp = Pe.point_posts(P, T, {}, 14.4, 10)
  check(#pp == 2 and pp[1].w == 9 and pp[2].w == 6, "deux postes, le plus lourd d'abord, le point couvert sans poste")
  check(pp[1].x > 39 and pp[1].x < 45 and pp[2].y == 60, "centres aux barycentres des grappes")
  local pp2 = Pe.point_posts(P, T, { { x = 1, y = 60 } }, 14.4, 10)
  check(#pp2 == 1 and pp2[1].w == 9, "un poste en mémoire couvre déjà sa grappe : pas de doublon")
  check(#Pe.point_posts(P, T, {}, 14.4, 1) == 1, "au plus max postes")
  local Pr = {}
  for i = #P, 1, -1 do Pr[#Pr + 1] = P[i] end
  local pq = Pe.point_posts(Pr, T, {}, 14.4, 10)
  check(#pq == 2 and near(pq[1].x, pp[1].x, 1e-9) and near(pq[2].x, pp[2].x, 1e-9), "ordre des points sans effet (déterminisme)")
  check(Pe.weight_near(P, 41, 0, 14.4) == 9, "poids sensible près d'un centre")

  -- 10. relevé complet : sous 8 points du cœur, rien ; puis anneau 1, ses postes et les postes « point » ; mémoire stable
  local hq = { x = 0, y = 0 }
  local few = { { x = 5, y = 0, role = "fabrique" }, { x = 10, y = 0, role = "fabrique" } }
  local st0 = {}
  local ev0, in0 = Pe.update(st0, { points = few, turrets = {}, hq = hq, range = 18, tick = 1 })
  check(#ev0 == 0 and #st0.posts == 0 and in0.core == 2, "base trop petite : aucune prévision")
  local base = { { x = 0, y = 0, role = "qg" } }
  for i = 1, 6 do base[#base + 1] = { x = 10 + 4 * i, y = 0, role = "fabrique" } end
  for i = 1, 4 do base[#base + 1] = { x = 0, y = 20 + 4 * i, role = "fabrique" } end
  local turq = { { x = 0, y = -3, range = 18 } }
  local st = {}
  local ev, info = Pe.update(st, { points = base, turrets = turq, hq = hq, range = 18, tick = 100 })
  local nring, npoint = 0, 0
  for _, p in ipairs(st.posts) do if p.kind == "ring" then nring = nring + 1 else npoint = npoint + 1 end end
  check(#ev == 1 and ev[1].what == "nouveau" and ev[1].ring == 1 and #st.rings == 1, "anneau 1 né au premier relevé")
  check(nring == ev[1].n and nring >= 4 and npoint >= 2 and info.new == npoint, "postes d'anneau et postes « point » créés")
  local before = #st.posts
  local ev2, info2 = Pe.update(st, { points = base, turrets = turq, hq = hq, range = 18, tick = 200 })
  check(#ev2 == 0 and info2.new == 0 and #st.posts == before, "relevé suivant identique : rien de neuf (postes persistants)")
  local gone = { base[1] }
  for i = 2, 7 do gone[#gone + 1] = base[i] end
  gone[#gone + 1] = { x = 38, y = 0, role = "fabrique" }
  local _, info3 = Pe.update(st, { points = gone, turrets = turq, hq = hq, range = 18, tick = 300 })
  check(info3.dropped >= 1, "postes « point » sans bâtiment retirés")

  -- 11. choix du poste
  local posts = {
    { id = 1, key = "p1", kind = "point", x = 0, y = 0, w = 9 },
    { id = 2, key = "p2", kind = "ring", ring = 1, x = 100, y = 0, w = 0 },
    { id = 3, key = "p3", kind = "ring", ring = 1, x = 0, y = 100, w = 5 },
    { id = 4, key = "p4", kind = "point", x = 50, y = 50, w = 3 },
    { id = 5, key = "p5", kind = "ring", ring = 2, x = 200, y = 0, w = 50 },
  }
  local pl = Pe.plan({ posts = posts, turrets = { { x = 2, y = 0 }, { x = -2, y = 0 } }, threats = { { x = 110, y = 0, w = 400 } } })
  check(pl.served == 1 and pl.pick and pl.pick.key == "p4", "point servi (2 tourelles), l'autre point d'abord")
  local pl2 = Pe.plan({ posts = posts, turrets = { { x = 2, y = 0 }, { x = -2, y = 0 }, { x = 50, y = 46 }, { x = 50, y = 54 } },
    threats = { { x = 110, y = 0, w = 400 } } })
  check(pl2.pick and pl2.pick.key == "p2" and pl2.pick.want == 3 and pl2.pick.threat == 400, "anneau 1 : poste menacé d'abord, groupe de 3")
  local pl3 = Pe.plan({ posts = posts, turrets = { { x = 2, y = 0 }, { x = -2, y = 0 }, { x = 50, y = 46 }, { x = 50, y = 54 } },
    threats = {}, rest = { p3 = true }, allow = function(p) return p.key ~= "p2" end })
  check(pl3.pick and pl3.pick.key == "p5" and pl3.pick.want == 2, "repos et ennemi sautés, anneau 2 après l'anneau 1")
  local skips = {}
  for _, r in ipairs(pl3.rows) do if r.skip then skips[#skips + 1] = r.post.key .. ":" .. r.skip end end
  check(table.concat(skips, ",") == "p3:repos,p2:ennemi" and pl3.total == 5, "raison du saut gardée (" .. table.concat(skips, ",") .. ")")

  -- 12. budget
  check(Pe.allowed({ iron = 2793, floor = 150, unit = 120, pct = 15, held = 0, want = 2 }) == 2, "budget : 15 % de 2 643 = 3 tourelles, 2 voulues")
  check(Pe.allowed({ iron = 2793, floor = 150, unit = 120, pct = 15, held = 1, want = 3 }) == 2, "budget : moins les tourelles déjà posées")
  check(Pe.allowed({ iron = 2793, floor = 150, unit = 120, pct = 15, held = 3, want = 2 }) == 0, "budget épuisé")
  check(Pe.allowed({ iron = 100, floor = 150, unit = 120, want = 2 }) == 0 and Pe.allowed({ iron = 9000, floor = 150, unit = 0, want = 2 }) == 0,
    "sous le plancher, ou coût inconnu : rien")
  check(Pe.allowed({ iron = 12000, floor = 150, unit = 120, held = 10, want = 3 }) == 3, "équipe riche : 15 % de 11 850 = 14 tourelles")

  -- 13. repos
  check(Pe.rest_ticks(nil) == 7200 and Pe.rest_ticks(3) == 21600 and Pe.rest_ticks(10) == 43200, "repos croissant, plafonné")
  return fails, n
end

local fails, total = suite(load_pe(SRC))
for _, m in ipairs(fails) do print("  ECHEC : " .. m) end
local passes, failures = total - #fails, #fails

local function mutate(old, new)
  local a, b = SRC:find(old, 1, true)
  if not a then return nil end
  return SRC:sub(1, a - 1) .. new .. SRC:sub(b + 1)
end
local mutants = {
  { "rayon couvert à 100 %", "Pe.COVER_PCT = 80 ", "Pe.COVER_PCT = 100 " },
  { "bord exclu de la couverture", "          if d2(p.x, p.y, t.x, t.y) <= r * r then cov = true break end", "          if d2(p.x, p.y, t.x, t.y) < r * r then cov = true break end" },
  { "tourelles vides comptées armées", "if t.armed or not armed_only then", "if true then" },
  { "cœur sans chaîne", "    if p.y > box.y1 then box.y1 = p.y end\n    reach(p.x, p.y)", "    if p.y > box.y1 then box.y1 = p.y end" },
  { "nouvel anneau à la moindre croissance", "if grow < Pe.GROW then return nil end", "if grow <= 0 then return nil end" },
  { "anneau sans union", "local r = { x0 = math.min(env.x0, last.x0)", "local r = { x0 = env.x0" },
  { "anneaux sans plafond", "if #rings < Pe.MAX_RINGS then", "if true then" },
  { "tourelles devant le mur", "x0 = wall[1] + 1 + Pe.INSET", "x0 = wall[1] - Pe.INSET" },
  { "pas des postes à 4 × rc", "local step = math.max(8, Pe.SPACING_MUL * rc)", "local step = math.max(8, 4 * rc)" },
  { "pas de coin", "    out[#out + 1] = { x = s.ax, y = s.ay,", "    local _ = { x = s.ax, y = s.ay," },
  { "postes en mémoire ignorés", "if d2(p.x, p.y, q.x, q.y) <= reach2 then cov = true break end", "" },
  { "anneau extérieur avant l'intérieur", "then return (pa.ring or 0) < (pb.ring or 0) end", "then return (pa.ring or 0) > (pb.ring or 0) end" },
  { "pas de renfort sur menace", "want = th > 0 and Pe.GROUP_THREAT or Pe.GROUP", "want = Pe.GROUP" },
  { "budget sans les tourelles posées", "/ (100 * unit)) - (s.held or 0)", "/ (100 * unit))" },
  { "budget à 100 %", "math.floor((s.pct or Pe.BUDGET_PCT) * surplus / (100 * unit))", "math.floor(surplus / unit)" },
  { "prévision sans seuil de taille", "if ncore < Pe.MIN_POINTS then return ev, info end", "" },
  { "paire dans l'axe d'arrivée", "return -ny, nx, nx, ny", "return nx, ny, nx, ny" },
  { "postes « point » jamais retirés", "if p.kind == \"point\" and p.w <= 0 then", "if false then" },
  { "pose acceptée loin du poste", "return d2(post.x, post.y, x, y) <= Pe.ACCEPT * Pe.ACCEPT end", "return true end" },
  { "repos non plafonné", "math.min(math.max(zero or 1, 1), Pe.REST_MAX)", "math.max(zero or 1, 1)" },
}
local killed = 0
for _, m in ipairs(mutants) do
  local txt = mutate(m[2], m[3])
  if not txt then
    failures = failures + 1
    print("  ECHEC : mutant « " .. m[1] .. " » : texte introuvable")
  else
    local ok, f = pcall(function() return (suite(load_pe(txt))) end)
    local caught = (not ok) or #f > 0
    if caught then killed = killed + 1; passes = passes + 1 else failures = failures + 1; print("  ECHEC : mutant « " .. m[1] .. " » non détecté") end
  end
end
print(string.format("[PERIMETRE] mutants refusés : %d sur %d", killed, #mutants))
print(string.format("[PERIMETRE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
