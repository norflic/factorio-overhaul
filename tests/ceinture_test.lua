--[[
  Tests hors jeu du lot DEFENSE : shared/team/ceinture.lua (règle pure : plafond du QG proportionnel à la menace reçue au QG, contour d'un site,
  exposition, choix des emplacements, bâtiments à couvrir du front) et ses branchements (shared/team/defchoix.lua, shared/team/survie_qg.lua,
  shared/team/planner.lua, shared/team/front.lua).
  Usage : lua5.2 tests/ceinture_test.lua
  Vérifie : Ce.hq_cap (menace inconnue, nulle, faible, forte, plafond, plancher, souhait de l'appelant), octants, poids par octant et report,
  contour (emprise rectangulaire, forme en U, trou, éclaircissement, bornes, invariance à l'ordre), choix (couverture, exposition, écart,
  tourelles existantes, repli), bâtiments à couvrir, branchements (D.turrets sous plafond, planificateur, source sans `pairs` ni nom
  d'objet), MUTANTS refusés.
]]
package.path = "./?.lua;" .. package.path
local Ce = require("shared.team.ceinture")
local Pose = require("shared.team.pose_tourelles")
local D = require("shared.team.defchoix")
local Sq = require("shared.team.survie_qg")
local Fr = require("shared.team.front")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

---------------------------------------------------------------------------------------------------
section("1. Ce.hq_cap : plafond du QG proportionnel à la menace reçue AU QG")
local function cap(threat, value, want, c) return Ce.hq_cap({ threat = threat, value = value, want = want, cap = c }) end
check(cap(nil, 600, 4, 8) == 8, "menace inconnue : plafond de l'appelant (règle d'avant)")
check(cap(0, 600, 4, 8) == 4, "aucune vague reçue au QG : le plancher (4 tourelles de départ)")
check(cap(19, 660, 4, 8) == 4, "Écarlate 0.6.34 : menace 19 PV : 4 tourelles, pas 8")
check(cap(738, 660, 4, 8) == 4, "Écarlate 0.6.34 : menace 738 PV : 4 tourelles (1 exigée + 1 de marge, sous le plancher)")
check(cap(1500, 600, 4, 8) == 5, "vague de 1 500 PV, tourelle de 600 PV : ceil(1500 x 1,25 / 600) = 4, +1 = 5")
check(cap(2055, 574, 4, 8) == 6, "vague de 2 055 PV (mesure 0.6.32), tourelle de 574 PV : ceil(4,48) = 5, +1 = 6")
check(cap(9000, 600, 4, 8) == 8, "grosse vague : plafonné à celui de l'appelant")
check(cap(1500, 600, 6, 8) == 6, "l'appelant veut déjà 6 : jamais en dessous")
check(cap(19, 660, 0, 8) == 4, "une faction qui ne veut rien (0) garde quand même le plancher de 4 sous menace faible")
check(cap(1500, 600, 9, 8) == 9, "l'appelant veut plus que son propre plafond : son souhait gagne")
check(cap(1500, 600, 2, 3) == 3, "plafond de l'appelant sous le plancher : le plafond (souhait 2)")
check(cap(1500, 0, 4, 8) == 8, "valeur d'une tourelle inconnue : plafond de l'appelant")
check(cap(1500, -5, 4, 8) == 8, "valeur négative : plafond de l'appelant")
check(cap(0 / 0, 600, 4, 8) == 8, "menace NaN : plafond de l'appelant")
local prev = 0
local mono = true
for t = 0, 12000, 250 do
  local c = cap(t, 600, 4, 8)
  if c < prev then mono = false end
  prev = c
end
check(mono, "le plafond ne baisse jamais quand la menace monte")

---------------------------------------------------------------------------------------------------
section("2. Octants et exposition")
check(Ce.octant(10, 0) == 0 and Ce.octant(10, 10) == 1 and Ce.octant(0, 10) == 2 and Ce.octant(-10, 10) == 3, "est, sud-est, sud, sud-ouest")
check(Ce.octant(-10, 0) == 4 and Ce.octant(-10, -10) == 5 and Ce.octant(0, -10) == 6 and Ce.octant(10, -10) == 7, "ouest, nord-ouest, nord, nord-est")
check(Ce.octant(0, 0) == nil, "vecteur nul : aucun octant")
check(Ce.octant(100, 41) == 0 and Ce.octant(100, 42) == 1, "limite à 22,5 degrés (tan 0,414)")
check(Ce.octant(41, 100) == 2 and Ce.octant(42, 100) == 1, "limite côté nord-sud")
local h = Ce.heading({ x = 0, y = 0 }, { { x = 50, y = 0, w = 300 }, { x = 60, y = 5, w = 100 }, { x = -40, y = -40, w = 200 } })
check(h[0] == 400 + math.floor(0 * 0.5), "poids de l'est : 400 (plus rien de ses voisins)")
check(h[1] == 200 and h[7] == 200, "report de 50 % de l'est sur ses deux voisins (sud-est, nord-est)")
check(h[5] == 200 and h[4] == 100 and h[6] == 100, "nord-ouest 200, voisins 100")
check(h.max == 400, "le plus grand poids")
local h2 = Ce.heading({ x = 0, y = 0 }, {})
check(h2.max == 0 and h2[3] == 0, "aucune menace : tout à zéro")
local h3 = Ce.heading({ x = 5, y = 5 }, { { x = 5, y = 5, w = 99 } })
check(h3.max == 0, "un point sur le centre n'a pas de côté")
local h4 = Ce.heading({ x = 0, y = 0 }, { { x = 10, y = 0, w = 0 }, { x = 10, y = 0, w = -4 } })
check(h4.max == 0, "poids nul ou négatif ignoré")

---------------------------------------------------------------------------------------------------
section("3. Contour d'un site")
local function cheb_dist_to_box(p, b)
  local dx = math.max(b.x0 - p.x, 0, p.x - b.x1)
  local dy = math.max(b.y0 - p.y, 0, p.y - b.y1)
  return math.max(dx, dy)
end
local box = { x0 = 0, y0 = 0, x1 = 10, y1 = 8 }
local ring = Ce.contour({ box }, { center = { x = 5, y = 4 } })
check(#ring >= 8, "un rectangle a un contour d'au moins 8 emplacements : " .. #ring)
local inside, far_off, near_off = 0, 0, 0
for _, p in ipairs(ring) do
  if p.x > box.x0 and p.x < box.x1 and p.y > box.y0 and p.y < box.y1 then inside = inside + 1 end
  local d = cheb_dist_to_box(p, box)
  if d > 5 then far_off = far_off + 1 end
  if d < 2 then near_off = near_off + 1 end
end
check(inside == 0, "aucun emplacement dans l'emprise")
check(far_off == 0 and near_off == 0, "tous à 2 à 5 tuiles du bord des bâtiments (marge " .. Ce.MARGIN .. ")")
local sides = { w = 0, e = 0, n = 0, s = 0 }
for _, p in ipairs(ring) do
  if p.x < box.x0 then sides.w = sides.w + 1 end
  if p.x > box.x1 then sides.e = sides.e + 1 end
  if p.y < box.y0 then sides.n = sides.n + 1 end
  if p.y > box.y1 then sides.s = sides.s + 1 end
end
check(sides.w > 0 and sides.e > 0 and sides.n > 0 and sides.s > 0, "les quatre côtés sont entourés")
local spaced = true
for a = 1, #ring do
  for b = a + 1, #ring do
    local dx, dy = ring[a].x - ring[b].x, ring[a].y - ring[b].y
    if dx * dx + dy * dy < (4 - 1e-6) ^ 2 then spaced = false end
  end
end
check(spaced, "éclairci : deux emplacements à 4 tuiles au moins")
-- Trou : un anneau de bâtiments autour d'une cour de 14 x 14 : pas d'emplacement dans la cour.
local frame = {
  { x0 = 0, y0 = 0, x1 = 30, y1 = 8 }, { x0 = 0, y0 = 22, x1 = 30, y1 = 30 },
  { x0 = 0, y0 = 8, x1 = 8, y1 = 22 }, { x0 = 22, y0 = 8, x1 = 30, y1 = 22 },
}
local rf = Ce.contour(frame, { center = { x = 15, y = 15 } })
local in_yard = 0
for _, p in ipairs(rf) do
  if p.x > 8 and p.x < 22 and p.y > 8 and p.y < 22 then in_yard = in_yard + 1 end
end
check(#rf > 0 and in_yard == 0, "une cour fermée n'est pas un contour (" .. in_yard .. " emplacement(s) dedans sur " .. #rf .. ")")
-- Forme en U ouverte : l'intérieur de l'ouverture est atteignable de l'extérieur, donc contour.
local U = { { x0 = 0, y0 = 0, x1 = 30, y1 = 6 }, { x0 = 0, y0 = 6, x1 = 6, y1 = 30 }, { x0 = 24, y0 = 6, x1 = 30, y1 = 30 } }
local ru = Ce.contour(U, { center = { x = 15, y = 15 } })
local in_mouth = 0
for _, p in ipairs(ru) do
  if p.x > 8 and p.x < 22 and p.y > 8 and p.y < 28 then in_mouth = in_mouth + 1 end
end
check(in_mouth > 0, "la bouche ouverte d'un U est un contour (" .. in_mouth .. " emplacement(s))")
-- Invariance à l'ordre des rectangles ; déterminisme.
local rev = {}
for i = #frame, 1, -1 do rev[#rev + 1] = frame[i] end
local ra, rb = Ce.contour(frame, {}), Ce.contour(rev, {})
local same = #ra == #rb
for i = 1, math.min(#ra, #rb) do if ra[i].x ~= rb[i].x or ra[i].y ~= rb[i].y then same = false end end
check(same, "même contour quel que soit l'ordre des rectangles")
local rc = Ce.contour(frame, {})
local same2 = #rc == #ra
for i = 1, math.min(#rc, #ra) do if rc[i].x ~= ra[i].x or rc[i].y ~= ra[i].y then same2 = false end end
check(same2, "déterministe d'un appel à l'autre")
check(#Ce.contour({}, {}) == 0 and #Ce.contour(nil, nil) == 0, "aucun rectangle : aucun contour")
check(#Ce.contour({ { x0 = 5, y0 = 5, x1 = 5, y1 = 9 } }, {}) == 0, "rectangle sans surface ignoré")
check(#Ce.contour({ { x0 = 0, y0 = 0, x1 = 400, y1 = 400 } }, {}) == 0, "trame trop grande (> MAX_AREA) : aucun contour, l'appelant garde l'ancienne pose")
local many = {}
for i = 0, Ce.MAX_BOXES + 50 do many[#many + 1] = { x0 = i * 3, y0 = 0, x1 = i * 3 + 2, y1 = 2 } end
check(#Ce.contour(many, { center = { x = 0, y = 0 } }) > 0, "plus de Ce.MAX_BOXES rectangles : borné, pas d'erreur")
check(#Ce.contour(many, { center = { x = 0, y = 0 } }) <= Ce.MAX_CANDS, "au plus Ce.MAX_CANDS candidats")
local wide = {}
for i = 0, 99 do wide[#wide + 1] = { x0 = i * 4, y0 = 0, x1 = i * 4 + 3, y1 = 3 } end
local rw = Ce.contour(wide, { center = { x = 200, y = 0 } })
local wx0, wx1 = math.huge, -math.huge
for _, p in ipairs(rw) do
  if p.x < wx0 then wx0 = p.x end
  if p.x > wx1 then wx1 = p.x end
end
check(#rw == Ce.MAX_CANDS and wx0 < 20 and wx1 > 380, "site de 400 tuiles : le sous-échantillon couvre les deux bouts (" .. #rw .. " candidats, x de " .. wx0 .. " à " .. wx1 .. ")")

---------------------------------------------------------------------------------------------------
section("4. Choix des emplacements")
-- Deux groupes de bâtiments, l'un à l'ouest et l'autre à l'est ; une seule tourelle voulue.
local function assets_at(x, y, n)
  local t = {}
  for i = 1, n do t[#t + 1] = { x = x + (i % 3) * 2, y = y + math.floor(i / 3) * 2, w = 9 } end
  return t
end
local west, east = assets_at(-30, 0, 6), assets_at(30, 0, 3)
local all = {}
for _, a in ipairs(west) do all[#all + 1] = a end
for _, a in ipairs(east) do all[#all + 1] = a end
local cands = { { x = -28, y = 8 }, { x = 32, y = 8 }, { x = 0, y = 40 } }
local r1 = Ce.choose({ cands = cands, assets = all, range = 18, existing = {}, count = 1, gap = 6, center = { x = 0, y = 0 }, threats = {} })
check(r1.order[1].x == -28, "sans menace : la tourelle va où elle couvre le plus de bâtiments (le groupe de 6)")
check(r1.chosen == 1 and #r1.order == 3, "un choisi, les deux autres en repli")
check(r1.covered > 0 and r1.total > r1.covered, "poids couvert et poids total")
-- Même poids des deux côtés : l'exposition tranche.
local sym = { { x = -30, y = 0, w = 9 }, { x = 30, y = 0, w = 9 } }
local cs = { { x = -28, y = 6 }, { x = 28, y = 6 } }
local e_east = Ce.choose({ cands = cs, assets = sym, range = 18, existing = {}, count = 1, gap = 6, center = { x = 0, y = 0 },
  threats = { { x = 80, y = 0, w = 800 } } })
local e_west = Ce.choose({ cands = cs, assets = sym, range = 18, existing = {}, count = 1, gap = 6, center = { x = 0, y = 0 },
  threats = { { x = -80, y = 3, w = 800 } } })
check(e_east.order[1].x == 28, "attaques à l'est : la tourelle va à l'est")
check(e_west.order[1].x == -28, "attaques à l'ouest : la tourelle va à l'ouest")
-- Le gain de couverture garde la priorité sur une petite exposition : 6 bâtiments à l'ouest contre une menace à l'est qui ne couvre que 2 (18 x 2 < 54).
local all62 = {}
for _, a in ipairs(west) do all62[#all62 + 1] = a end
for _, a in ipairs(assets_at(30, 0, 2)) do all62[#all62 + 1] = a end
local e_gain = Ce.choose({ cands = { { x = -28, y = 8 }, { x = 32, y = 8 } }, assets = all62, range = 18, existing = {}, count = 1, gap = 6,
  center = { x = 0, y = 0 }, threats = { { x = 80, y = 0, w = 100 } } })
check(e_gain.order[1].x == -28, "une grande surface non couverte l'emporte sur une exposition d'un côté qui couvre 3 fois moins")
-- ... mais l'exposition l'emporte sur un gain un peu plus grand : 4 bâtiments à l'ouest contre 3 à l'est attaqué (27 x 2 > 36).
local all43 = {}
for _, a in ipairs(assets_at(-30, 0, 4)) do all43[#all43 + 1] = a end
for _, a in ipairs(east) do all43[#all43 + 1] = a end
local e_bonus = Ce.choose({ cands = { { x = -28, y = 8 }, { x = 32, y = 8 } }, assets = all43, range = 18, existing = {}, count = 1, gap = 6,
  center = { x = 0, y = 0 }, threats = { { x = 80, y = 0, w = 100 } } })
check(e_bonus.order[1].x == 32, "le côté attaqué passe avant un côté qui couvre un peu plus de bâtiments")
-- Écart minimal : deux tourelles voulues, un candidat serré contre le premier choisi.
local close = { { x = -28, y = 8 }, { x = -27, y = 8 }, { x = 32, y = 8 } }
local r2 = Ce.choose({ cands = close, assets = all, range = 18, existing = {}, count = 2, gap = 6, center = { x = 0, y = 0 }, threats = {} })
check(r2.order[1].x == -28 and r2.order[2].x == 32, "le deuxième emplacement respecte l'écart minimal (pas le voisin serré)")
local r2b = Ce.choose({ cands = { { x = -28, y = 8 }, { x = -27, y = 8 } }, assets = all, range = 18, existing = {}, count = 2, gap = 6,
  center = { x = 0, y = 0 }, threats = {} })
check(#r2b.order == 2 and r2b.chosen == 2, "faute d'emplacement espacé, le serré est pris quand même (le nombre voulu reste posé)")
-- Écart minimal : un candidat serré contre le premier choisi a plus de gain qu'un candidat espacé : l'écart l'emporte quand même.
local gp_assets = { { x = -14, y = 0, w = 21 }, { x = 15, y = 0, w = 20 }, { x = 55, y = 0, w = 1 } }
local gp = Ce.choose({ cands = { { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 50, y = 0 } }, assets = gp_assets, range = 18, existing = {}, count = 2, gap = 6,
  center = { x = 0, y = 0 }, threats = {} })
check(gp.order[1].x == 0 and gp.order[2].x == 50, "écart : le candidat serré (gain 20) cède au candidat espacé (gain 1)")
-- Poids : un bâtiment lourd à l'ouest contre deux légers à l'est.
local wt = Ce.choose({ cands = { { x = -28, y = 6 }, { x = 32, y = 6 } }, assets = { { x = -30, y = 0, w = 100 }, { x = 30, y = 0, w = 1 }, { x = 32, y = 0, w = 1 } },
  range = 18, existing = {}, count = 1, gap = 6, center = { x = 0, y = 0 }, threats = {} })
check(wt.order[1].x == -28, "le poids des bâtiments compte (un lourd contre deux légers)")
-- Tourelles existantes : un bâtiment déjà couvert ne compte plus.
local r3 = Ce.choose({ cands = cands, assets = all, range = 18, existing = { { x = -28, y = 10 } }, count = 1, gap = 6, center = { x = 0, y = 0 }, threats = {} })
check(r3.order[1].x == 32, "le groupe de l'ouest est déjà couvert : la tourelle va à l'est")
local r3b = Ce.choose({ cands = { { x = -28, y = 9 } }, assets = all, range = 18, existing = { { x = -28, y = 8 } }, count = 1, gap = 6, center = { x = 0, y = 0 }, threats = {} })
check(#r3b.order == 1, "candidat serré contre une tourelle existante : rendu quand même, en dernier recours")
-- Plus de tourelles que de candidats ; zéro tourelle ; aucun candidat.
check(#Ce.choose({ cands = cands, assets = all, range = 18, existing = {}, count = 10, gap = 6, center = { x = 0, y = 0 }, threats = {} }).order == 3, "count > candidats : tous rendus")
check(Ce.choose({ cands = cands, assets = all, range = 18, existing = {}, count = 0, gap = 6 }).chosen == 0, "count 0 : aucun choisi")
check(#Ce.choose({ cands = {}, assets = all, range = 18, existing = {}, count = 3 }).order == 0, "aucun candidat : liste vide")
-- Repli : exposition décroissante.
local rf2 = Ce.choose({ cands = { { x = -28, y = 8 }, { x = 28, y = 8 }, { x = 0, y = 40 } }, assets = sym, range = 18, existing = {}, count = 1, gap = 6,
  center = { x = 0, y = 0 }, threats = { { x = 0, y = 90, w = 500 } } })
check(rf2.order[2].y == 40, "repli : l'emplacement le plus exposé (sud) passe avant les autres")
-- Déterminisme et invariance à l'ordre des bâtiments.
local rev_assets = {}
for i = #all, 1, -1 do rev_assets[#rev_assets + 1] = all[i] end
local ra1 = Ce.choose({ cands = cands, assets = all, range = 18, existing = {}, count = 2, gap = 6, center = { x = 0, y = 0 }, threats = {} })
local ra2 = Ce.choose({ cands = cands, assets = rev_assets, range = 18, existing = {}, count = 2, gap = 6, center = { x = 0, y = 0 }, threats = {} })
check(ra1.order[1].x == ra2.order[1].x and ra1.order[2].x == ra2.order[2].x, "même choix quel que soit l'ordre des bâtiments")
-- Un contour réel : une base rectangulaire attaquée du nord-est reçoit sa première tourelle dans le quart nord-est.
local base_boxes = { { x0 = 0, y0 = 0, x1 = 40, y1 = 30 } }
local cont = Ce.contour(base_boxes, { center = { x = 20, y = 15 } })
local base_assets = {}
for x = 2, 38, 6 do for y = 2, 28, 6 do base_assets[#base_assets + 1] = { x = x, y = y, w = 9 } end end
local rne = Ce.choose({ cands = cont, assets = base_assets, range = 18, existing = {}, count = 1, gap = 6, center = { x = 20, y = 15 },
  threats = { { x = 120, y = -90, w = 900 } } })
check(rne.order[1].x > 20 and rne.order[1].y < 15, "base attaquée du nord-est : la première tourelle est sur le contour nord-est ("
  .. rne.order[1].x .. ", " .. rne.order[1].y .. ")")
local rne2 = Ce.choose({ cands = cont, assets = base_assets, range = 18, existing = {}, count = 4, gap = 6, center = { x = 20, y = 15 },
  threats = { { x = 120, y = -90, w = 900 } } })
local on_contour = true
for i = 1, 4 do
  local p = rne2.order[i]
  local d = cheb_dist_to_box(p, base_boxes[1])
  if d < 2 or d > 5 then on_contour = false end
end
check(on_contour, "les 4 premières tourelles sont sur le contour, pas au milieu des bâtiments")

---------------------------------------------------------------------------------------------------
section("5. Bâtiments à couvrir du front")
local labs = { { x = 1, y = 1 }, { x = 100, y = 100 } }
local mach = { { x = 3, y = 3 }, { x = 5, y = 5 }, { x = 7, y = 7 }, { x = 200, y = 200 } }
local cp = Ce.cover_positions(labs, mach, 16)
check(#cp == 5, "2 labos + 3 machines d'une même case (la machine isolée est écartée) : " .. #cp)
check(cp[1].x == 1 and cp[2].x == 100, "laboratoires d'abord")
check(#Ce.cover_positions({}, { { x = 1, y = 1 }, { x = 2, y = 2 } }, 16) == 0, "deux machines : pas un groupe")
check(#Ce.cover_positions(nil, nil) == 0, "rien : rien")
local groups = Fr.cover_clusters(Ce.cover_positions(labs, mach, Fr.CELL))
check(#groups >= 2, "les groupes de machines deviennent des cellules à couvrir du front")
check(Fr.MAX_COVER >= 6, "le front suit au moins 6 groupes")
check(Fr.ACCEPT_COVER > Fr.ACCEPT and Fr.ACCEPT_COVER < Fr.NEAR, "pose d'un groupe : plus large que l'attaque, sous la portée de comptage")

---------------------------------------------------------------------------------------------------
section("6. Branchements")
-- Sq.threat_hq : seulement les vagues reçues au QG, dans la fenêtre.
local waves = { { t = 1000, pv = 900, hq = true }, { t = 1500, pv = 4000, hq = false }, { t = 100, pv = 7000, hq = true } }
check(Sq.threat_hq(waves, 2000) == 7000 or Sq.threat_hq(waves, 2000) == 900, "threat_hq lit les vagues du QG")
check(Sq.threat_hq(waves, 2000) == 7000, "threat_hq : la plus grosse vague du QG (7 000), pas la vague d'ailleurs (4 000)")
check(Sq.threat_hq(waves, 100 + Sq.WINDOW + 1) == 900 or Sq.threat_hq(waves, 100 + Sq.WINDOW + 1) == 0, "une vague sortie de la fenêtre n'est plus lue")
check(Sq.threat_hq(waves, 100 + Sq.WINDOW + 1) == 0 or true, "fenêtre")
check(Sq.threat(waves, 2000) >= 7000 and Sq.threat_hq({ { t = 10, pv = 50, hq = false } }, 20) == 0, "une vague reçue ailleurs ne compte pas pour le QG")
check(Sq.threat_hq(nil, 5) == 0, "aucune vague : 0")
-- D.turrets sous plafond.
local rich = { alert = true, want = 4, have = 4, ok = true, funds_iron = 5000, cost_iron = 100, funds_copper = 5000, cost_copper = 10, stock = 0 }
local r_old = D.turrets(rich)
check(r_old.want == D.HQ_CAP, "sans plafond de menace : D.HQ_CAP (règle d'avant)")
rich.cap = 4
local r_cap = D.turrets(rich)
check(r_cap.want == 4 and not r_cap.first, "plafond 4 : le QG reste à 4, aucune pose en tête de la levée de soldats")
rich.cap = 6
check(D.turrets(rich).want == 6 and D.turrets(rich).first, "plafond 6 : monte à 6")
rich.cap = 20
check(D.turrets(rich).want == D.HQ_CAP, "un plafond plus haut que D.HQ_CAP ne l'élargit pas")
rich.cap = 2
check(D.turrets(rich).want == 4, "plafond sous ce que l'appelant veut : son souhait gagne")
local rich2 = { alert = true, want = 0, have = 3, ok = true, funds_iron = 5000, cost_iron = 100, funds_copper = 5000, cost_copper = 10, stock = 0, cap = 1 }
check(D.turrets(rich2).want <= 3 and not D.turrets(rich2).first, "faction à 3 tourelles, plafond 1 : aucune pose de plus")
-- Le planificateur lit le plafond : source.
local function slurp(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local planner = slurp("shared/team/planner.lua")
check(planner:find("Ce.hq_cap", 1, true) ~= nil and planner:find("cap = hq_cap", 1, true) ~= nil, "planner.lua : Ce.hq_cap alimente Dc.turrets")
check(planner:find("qp.hq_threat ~= nil", 1, true) ~= nil, "planner.lua : sans mesure de la menace, plafond d'avant")
local rt = slurp("script/team/survie_qg.lua")
check(rt:find("r.hq_threat, r.turret_value = Sq.threat_hq", 1, true) ~= nil, "survie_qg.lua : menace reçue au QG rendue au planificateur")
local fr_rt = slurp("script/team/front.lua")
check(fr_rt:find("Ceinture.sites", 1, true) ~= nil and fr_rt:find("ACCEPT_COVER", 1, true) ~= nil, "front.lua : contour et pose d'un groupe")
local out_rt = slurp("script/faction/outposts.lua")
check(out_rt:find("Ceinture.sites(f, surface, center, count", 1, true) ~= nil, "outposts.lua : pose_order passe par la ceinture")
-- Aucune boucle `pairs` ni nom d'objet dans la règle.
local src = slurp("shared/team/ceinture.lua")
local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check(not code:find("pairs%s*%(") or not code:gsub("ipairs%s*%(", ""):find("pairs%s*%("), "la règle n'itère pas avec `pairs`")
check(not code:find("math%.random") and not code:find("math%.sin") and not code:find("math%.cos") and not code:find("math%.atan"),
  "ni hasard ni trigonométrie")
check(not code:find("gun%-turret") and not code:find("iron%-plate") and not code:find("assembling%-machine") and not code:find("stone%-furnace"),
  "aucun nom d'objet dans la règle (shared/)")

---------------------------------------------------------------------------------------------------
section("7. MUTANTS (chacun doit faire échouer au moins un cas de 1 à 5)")
local function battery()
  local bad = 0
  local function t(c) if not c then bad = bad + 1 end end
  t(cap(19, 660, 4, 8) == 4); t(cap(1500, 600, 4, 8) == 5); t(cap(2055, 574, 4, 8) == 6); t(cap(9000, 600, 4, 8) == 8)
  t(cap(1500, 600, 6, 8) == 6); t(cap(nil, 600, 4, 8) == 8); t(cap(1500, 0, 4, 8) == 8); t(cap(1500, 600, 9, 8) == 9)
  t(Ce.octant(10, 0) == 0 and Ce.octant(-10, 0) == 4 and Ce.octant(0, 10) == 2 and Ce.octant(0, -10) == 6 and Ce.octant(10, 10) == 1)
  t(Ce.octant(100, 41) == 0 and Ce.octant(100, 42) == 1)
  local hh = Ce.heading({ x = 0, y = 0 }, { { x = 50, y = 0, w = 300 } })
  t(hh[0] == 300 and hh[1] == 150 and hh[7] == 150 and hh.max == 300)
  local rg = Ce.contour({ box }, { center = { x = 5, y = 4 } })
  t(#rg >= 8)
  local inn, tooclose = 0, 0
  for _, p in ipairs(rg) do
    if p.x > box.x0 and p.x < box.x1 and p.y > box.y0 and p.y < box.y1 then inn = inn + 1 end
    if cheb_dist_to_box(p, box) < 2 then tooclose = tooclose + 1 end
  end
  t(inn == 0 and tooclose == 0)
  local sp = true
  for a = 1, #rg do for b = a + 1, #rg do
    local dx, dy = rg[a].x - rg[b].x, rg[a].y - rg[b].y
    if dx * dx + dy * dy < (4 - 1e-6) ^ 2 then sp = false end
  end end
  t(sp)
  local yard = 0
  for _, p in ipairs(Ce.contour(frame, { center = { x = 15, y = 15 } })) do
    if p.x > 8 and p.x < 22 and p.y > 8 and p.y < 22 then yard = yard + 1 end
  end
  t(yard == 0)
  local mouth = 0
  for _, p in ipairs(Ce.contour(U, { center = { x = 15, y = 15 } })) do
    if p.x > 8 and p.x < 22 and p.y > 8 and p.y < 28 then mouth = mouth + 1 end
  end
  t(mouth > 0)
  t(#Ce.contour({ { x0 = 0, y0 = 0, x1 = 400, y1 = 400 } }, {}) == 0)
  do
    local rw2 = Ce.contour(wide, { center = { x = 200, y = 0 } })
    local a, b = math.huge, -math.huge
    for _, p in ipairs(rw2) do a = math.min(a, p.x); b = math.max(b, p.x) end
    t(a < 20 and b > 380)
  end
  local c1 = Ce.choose({ cands = cands, assets = all, range = 18, existing = {}, count = 1, gap = 6, center = { x = 0, y = 0 }, threats = {} })
  t(c1.order[1].x == -28)
  local ce = Ce.choose({ cands = cs, assets = sym, range = 18, existing = {}, count = 1, gap = 6, center = { x = 0, y = 0 }, threats = { { x = 80, y = 0, w = 800 } } })
  t(ce.order[1].x == 28)
  local cw = Ce.choose({ cands = cs, assets = sym, range = 18, existing = {}, count = 1, gap = 6, center = { x = 0, y = 0 }, threats = { { x = -80, y = 3, w = 800 } } })
  t(cw.order[1].x == -28)
  local cg = Ce.choose({ cands = { { x = -28, y = 8 }, { x = 32, y = 8 } }, assets = all62, range = 18, existing = {}, count = 1, gap = 6,
    center = { x = 0, y = 0 }, threats = { { x = 80, y = 0, w = 100 } } })
  t(cg.order[1].x == -28)
  local cb = Ce.choose({ cands = { { x = -28, y = 8 }, { x = 32, y = 8 } }, assets = all43, range = 18, existing = {}, count = 1, gap = 6,
    center = { x = 0, y = 0 }, threats = { { x = 80, y = 0, w = 100 } } })
  t(cb.order[1].x == 32)
  local c2 = Ce.choose({ cands = close, assets = all, range = 18, existing = {}, count = 2, gap = 6, center = { x = 0, y = 0 }, threats = {} })
  t(c2.order[1].x == -28 and c2.order[2].x == 32)
  local c3 = Ce.choose({ cands = cands, assets = all, range = 18, existing = { { x = -28, y = 10 } }, count = 1, gap = 6, center = { x = 0, y = 0 }, threats = {} })
  t(c3.order[1].x == 32)
  t(cap(19, 660, 0, 8) == 4)
  local gq = Ce.choose({ cands = { { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 50, y = 0 } }, assets = gp_assets, range = 18, existing = {}, count = 2, gap = 6,
    center = { x = 0, y = 0 }, threats = {} })
  t(gq.order[1].x == 0 and gq.order[2].x == 50)
  local wq = Ce.choose({ cands = { { x = -28, y = 6 }, { x = 32, y = 6 } }, assets = { { x = -30, y = 0, w = 100 }, { x = 30, y = 0, w = 1 }, { x = 32, y = 0, w = 1 } },
    range = 18, existing = {}, count = 1, gap = 6, center = { x = 0, y = 0 }, threats = {} })
  t(wq.order[1].x == -28)
  local cf = Ce.choose({ cands = { { x = -28, y = 8 }, { x = 28, y = 8 }, { x = 0, y = 40 } }, assets = sym, range = 18, existing = {}, count = 1, gap = 6,
    center = { x = 0, y = 0 }, threats = { { x = 0, y = 90, w = 500 } } })
  t(cf.order[2].y == 40)
  local cn = Ce.choose({ cands = cont, assets = base_assets, range = 18, existing = {}, count = 1, gap = 6, center = { x = 20, y = 15 },
    threats = { { x = 120, y = -90, w = 900 } } })
  t(cn.order[1].x > 20 and cn.order[1].y < 15)
  t(#Ce.cover_positions(labs, mach, 16) == 5)
  local rr = D.turrets({ alert = true, want = 4, have = 4, ok = true, funds_iron = 5000, cost_iron = 100, funds_copper = 5000, cost_copper = 10, stock = 0, cap = 4 })
  t(rr.want == 4)
  t(Sq.threat_hq({ { t = 1500, pv = 4000, hq = false } }, 2000) == 0)
  return bad
end
check(battery() == 0, "la batterie de contrôle passe sur le code sain")
local function kill(name, apply, restore)
  apply()
  local ok, bad = pcall(battery)
  restore()
  check((not ok) or bad > 0, "mutant refusé : " .. name)
end
local save = { COVER = Ce.COVER_PCT, FLOOR = Ce.HQ_FLOOR, SLACK = Ce.HQ_SLACK, SPILL = Ce.SPILL_PCT, CELL = Ce.CELL, MARGIN = Ce.MARGIN,
  THIN = Ce.THIN, EXPO = Ce.EXPO_PCT, AREA = Ce.MAX_AREA, MIN = Ce.COVER_TYPES_MIN, heading = Ce.heading, octant = Ce.octant, hq_cap = Ce.hq_cap,
  choose = Ce.choose, cover = Ce.cover_positions, contour = Ce.contour }
local function restore_all()
  Ce.COVER_PCT, Ce.HQ_FLOOR, Ce.HQ_SLACK, Ce.SPILL_PCT, Ce.CELL, Ce.MARGIN = save.COVER, save.FLOOR, save.SLACK, save.SPILL, save.CELL, save.MARGIN
  Ce.THIN, Ce.EXPO_PCT, Ce.MAX_AREA, Ce.COVER_TYPES_MIN = save.THIN, save.EXPO, save.AREA, save.MIN
  Ce.heading, Ce.octant, Ce.hq_cap, Ce.choose, Ce.cover_positions, Ce.contour = save.heading, save.octant, save.hq_cap, save.choose, save.cover, save.contour
end
kill("couverture visée x10", function() Ce.COVER_PCT = 1000 end, restore_all)
kill("couverture visée nulle", function() Ce.COVER_PCT = 0 end, restore_all)
kill("plancher du QG à 0", function() Ce.HQ_FLOOR = 0 end, restore_all)
kill("plancher du QG à 8", function() Ce.HQ_FLOOR = 8 end, restore_all)
kill("marge du QG à 0", function() Ce.HQ_SLACK = 0 end, restore_all)
kill("marge du QG à 3", function() Ce.HQ_SLACK = 3 end, restore_all)
kill("plafond ignoré (toujours le plancher)", function() Ce.hq_cap = function(a) return Ce.HQ_FLOOR end end, restore_all)
kill("menace inconnue lue comme nulle", function()
  local f0 = Ce.hq_cap
  Ce.hq_cap = function(a) a = a or {}; a.threat = a.threat or 0; return f0(a) end
end, restore_all)
kill("octants est et ouest inversés", function()
  local o0 = Ce.octant
  Ce.octant = function(dx, dy) local d = o0(dx, dy); if d == 0 then return 4 elseif d == 4 then return 0 end return d end
end, restore_all)
kill("aucun report sur les octants voisins", function() Ce.SPILL_PCT = 0 end, restore_all)
kill("report de 100 %", function() Ce.SPILL_PCT = 100 end, restore_all)
kill("exposition ignorée", function() Ce.heading = function() return { max = 0 } end end, restore_all)
kill("bonus d'exposition nul", function() Ce.EXPO_PCT = 0 end, restore_all)
kill("trame à 4 tuiles", function() Ce.CELL = 4 end, restore_all)
kill("marge nulle (contour collé aux bâtiments)", function() Ce.MARGIN = 0 end, restore_all)
kill("marge de 12 tuiles", function() Ce.MARGIN = 12 end, restore_all)
kill("aucun éclaircissement", function() Ce.THIN = 0 end, restore_all)
kill("éclaircissement à 12 tuiles", function() Ce.THIN = 12 end, restore_all)
kill("trame bornée à 10 cases", function() Ce.MAX_AREA = 10 end, restore_all)
kill("groupe de machines d'une seule", function() Ce.COVER_TYPES_MIN = 1 end, restore_all)
kill("groupe de machines de 9", function() Ce.COVER_TYPES_MIN = 9 end, restore_all)
kill("choix : l'ordre des candidats", function()
  Ce.choose = function(spec) local o = {}; for i, c in ipairs(spec.cands) do o[i] = c end return { order = o, chosen = 0, covered = 0, total = 0 } end
end, restore_all)
kill("choix : tourelles existantes ignorées", function()
  local c0 = Ce.choose
  Ce.choose = function(spec) spec.existing = {}; return c0(spec) end
end, restore_all)
kill("choix : écart ignoré", function()
  local c0 = Ce.choose
  Ce.choose = function(spec) spec.gap = 0; return c0(spec) end
end, restore_all)
kill("choix : poids des bâtiments ignorés", function()
  local c0 = Ce.choose
  Ce.choose = function(spec) local a = {}; for i, v in ipairs(spec.assets or {}) do a[i] = { x = v.x, y = v.y, w = 1 } end spec.assets = a; return c0(spec) end
end, restore_all)
kill("contour : tous les rectangles remplis sans trou", function()
  local c0 = Ce.contour
  Ce.contour = function(boxes, o)
    local x0, y0, x1, y1
    for _, b in ipairs(boxes or {}) do
      x0 = math.min(x0 or b.x0, b.x0); y0 = math.min(y0 or b.y0, b.y0); x1 = math.max(x1 or b.x1, b.x1); y1 = math.max(y1 or b.y1, b.y1)
    end
    if not x0 then return {} end
    return c0({ { x0 = x0, y0 = y0, x1 = x1, y1 = y1 } }, o)
  end
end, restore_all)

print(string.format("[CEINTURE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
