--[[
  Lot BOX-LAYOUT (directive du DC du 9/11) : urbanisme par gabarits réservés, règle pure shared/team/box_layout.lua.
    §1 footprint (2×2 → 3×3 ; 3×3 → 5×5 ; target nil ; max par axe sur des rectangles), anchor centré (impair vers le haut-gauche),
       grown contient l'ancien et reste dans la cellule réservée ;
    §2 pitch ; interface : géométrie PROUVÉE (la case atteinte par le bras, à sa portée, est dans la machine actuelle centrée ET
       dans l'empreinte cible) : différence 1 : entrée courte, sortie longue ; différence 2 : long des deux côtés ; 4 : impossible ;
    §3 grow sans collision / avec collision (conflits triés x puis y, une voisine compte), decide (4 combinaisons, jamais nil) ;
    §4 plan sur une ligne jouet (3 cellules : une grandit, une bloquée par un tapis, une par un poteau) ; déterminisme ;
    §5 mutants : max remplacé par now, centrage perdu, collision ignorée, decide qui upgrade malgré can_place faux, plan qui
       oublie les poteaux, interface sans bras long : chacun vu par les MÊMES détecteurs.
  Usage : lua5.2 tests/box_layout_test.lua   (depuis la racine du mod ; moins d'une seconde)
]]
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function section(name) print("== " .. name) end

local Bl = require("shared.team.box_layout")

local S = { s2 = { w = 2, h = 2 }, s3 = { w = 3, h = 3 }, s5 = { w = 5, h = 5 }, s6 = { w = 6, h = 6 } }
local function same(a, b) return a.w == b.w and a.h == b.h end
local function join(l) return table.concat(l, " ") end

---------------------------------------------------------------------------------------------------
-- Détecteurs partagés (§1 à §4 sur la règle, §5 sur les mutants) : rendent la liste des défauts vus.
---------------------------------------------------------------------------------------------------
local function det_footprint(fp)
  local bad = {}
  if not same(fp(S.s2, S.s3), S.s3) then bad[#bad + 1] = "2×2 → 3×3 réserve 3×3" end
  if not same(fp(S.s3, S.s5), S.s5) then bad[#bad + 1] = "3×3 → 5×5 réserve 5×5" end
  if not same(fp(S.s3, nil), S.s3) then bad[#bad + 1] = "target nil : now" end
  if not same(fp({ w = 3, h = 2 }, { w = 2, h = 5 }), { w = 3, h = 5 }) then bad[#bad + 1] = "max par axe (3×2, 2×5 → 3×5)" end
  if not same(fp(S.s5, S.s3), S.s5) then bad[#bad + 1] = "cible plus petite : max (jamais de rétrécissement)" end
  return bad
end

local function det_anchor(anchor)
  local bad = {}
  local a = anchor(nil, S.s2, S.s3)
  if not (a.x == 0 and a.y == 0) then bad[#bad + 1] = "2 dans 3 : (0,0) (impair vers le haut-gauche)" end
  a = anchor(nil, S.s3, S.s5)
  if not (a.x == 1 and a.y == 1) then bad[#bad + 1] = "3 dans 5 : (1,1) centré" end
  a = anchor(S.s6, S.s2)
  if not (a.x == 2 and a.y == 2) then bad[#bad + 1] = "2 dans 6 : (2,2) centré" end
  a = anchor({ w = 6, h = 3 }, S.s2)
  if not (a.x == 2 and a.y == 0) then bad[#bad + 1] = "2×2 dans 6×3 : (2,0)" end
  return bad
end

-- Preuve géométrique : l'agrandissement (machine cible centrée par la même règle) CONTIENT la machine actuelle et reste dans la cellule.
local function det_grown(anchor, grown)
  local bad = {}
  for _, c in ipairs({ { S.s2, S.s3 }, { S.s3, S.s5 }, { S.s2, S.s6 }, { S.s3, S.s6 }, { S.s5, S.s6 } }) do
    local now, tgt = c[1], c[2]
    local a = anchor(nil, now, tgt)
    local cur = { x = 10 + a.x, y = 20 + a.y, w = now.w, h = now.h } -- cellule réservée en (10,20)
    local g = grown(cur, tgt)
    local inside = g.x >= 10 and g.y >= 20 and g.x + g.w <= 10 + tgt.w and g.y + g.h <= 20 + tgt.h
    local contains = g.x <= cur.x and g.y <= cur.y and g.x + g.w >= cur.x + cur.w and g.y + g.h >= cur.y + cur.h
    if not (inside and contains and g.w == tgt.w and g.h == tgt.h) then
      bad[#bad + 1] = string.format("%d→%d : agrandi hors cellule ou ne contient pas l'actuelle", now.w, tgt.w)
    end
  end
  return bad
end

-- Preuve de l'interface : le bras, à sa portée, atteint une case qui est dans la machine actuelle (centrée) ET dans la cible.
local function reaches(a, from_y_dir, now_rect, tgt_rect)
  local ty = a.y + from_y_dir * a.reach
  local function inr(r) return a.x >= r.x and a.x < r.x + r.w and ty >= r.y and ty < r.y + r.h end
  return inr(now_rect) and inr(tgt_rect)
end
local function det_interface(interface, anchor)
  local bad = {}
  local function probe(now, tgt, want_in_long, want_out_long, want_ok)
    local it = interface(tgt, now)
    local a = anchor(nil, now, tgt)
    local now_rect = { x = a.x, y = a.y, w = now.w, h = now.h }
    local tgt_rect = { x = 0, y = 0, w = it.w, h = it.h }
    local label = string.format("%d→%d", now.w, tgt.w)
    if it["in"].long ~= want_in_long or it.out.long ~= want_out_long or it.ok ~= want_ok then
      bad[#bad + 1] = label .. " : drapeaux long/ok (" .. tostring(it["in"].long) .. "," .. tostring(it.out.long) .. "," .. tostring(it.ok) .. ")"
    end
    if it["in"].y ~= -1 or it.out.y ~= it.h then bad[#bad + 1] = label .. " : bras hors de la ligne d'interface (bord de la cible)" end
    if want_ok and not (reaches(it["in"], 1, now_rect, tgt_rect) and reaches(it.out, -1, now_rect, tgt_rect)) then
      bad[#bad + 1] = label .. " : un bras n'atteint pas la machine actuelle ET la future"
    end
    if it.long ~= (want_in_long or want_out_long) then bad[#bad + 1] = label .. " : résumé long" end
  end
  probe(S.s3, S.s3, false, false, true)  -- même gabarit : deux bras courts
  probe(S.s2, S.s3, false, true, true)   -- différence 1 : entrée courte (marge nord 0), sortie longue (marge sud 1)
  probe(S.s3, S.s5, true, true, true)    -- différence 2 : long des deux côtés
  probe(S.s2, S.s6, true, true, false)   -- différence 4 : marges 2 et 2, hors de portée : non évolutif
  probe(S.s3, S.s6, true, true, false)   -- différence 3 : sud à 2 : impossible
  -- un bras court avec une marge de 1 N'ATTEINT PAS la machine (limite physique, prouvée par la géométrie)
  local it = interface(S.s3, S.s2)
  local short_out = { x = it.out.x, y = it.out.y, reach = 1 }
  if reaches(short_out, -1, { x = 0, y = 0, w = 2, h = 2 }, { x = 0, y = 0, w = 3, h = 3 }) then bad[#bad + 1] = "un bras court franchirait une marge de 1" end
  return bad
end

local function det_grow(grow)
  local bad = {}
  local cells = { { x = 0, y = 0, w = 2, h = 2 }, { x = 10, y = 0, w = 2, h = 2 } }
  local ok, c = grow(cells, 1, S.s3, {})
  if not (ok and #c == 0) then bad[#bad + 1] = "sans collision : ok, aucun conflit" end
  local occ = { [Bl.key(2, 1)] = true, [Bl.key(0, 2)] = true, [Bl.key(2, 2)] = true, [Bl.key(1, 1)] = true } -- (1,1) : sous la machine, pas un conflit
  ok, c = grow(cells, 1, S.s3, occ)
  if ok or join(c) ~= "0,2 2,1 2,2" then bad[#bad + 1] = "avec collision : conflits triés x puis y (" .. join(c) .. ")" end
  -- une voisine compte : la cellule 1 (10,0) grandit vers le sud-est sur x 10..12 (arrondi haut-gauche) ; une cellule 2×2 en (12,0) touche la colonne 12
  local near = { { x = 10, y = 0, w = 2, h = 2 }, { x = 12, y = 0, w = 2, h = 2 } }
  ok, c = grow(near, 1, S.s3, {})
  if ok or join(c) ~= "12,0 12,1" then bad[#bad + 1] = "voisine : conflits (12,0) (12,1) (" .. join(c) .. ")" end
  ok, c = grow(cells, 9, S.s3, {})
  if ok or #c ~= 0 then bad[#bad + 1] = "cellule inexistante : refus, sans conflit" end
  return bad
end

local function det_decide(decide)
  local bad = {}
  local cases = { { true, true, "upgrade" }, { true, false, "ajourne" }, { false, true, "ajourne" }, { false, false, "ajourne" }, { nil, true, "ajourne" }, { true, nil, "ajourne" } }
  for _, c in ipairs(cases) do
    local got = decide(c[1], c[2])
    if got ~= c[3] then bad[#bad + 1] = string.format("decide(%s,%s) = %s au lieu de %s", tostring(c[1]), tostring(c[2]), tostring(got), c[3]) end
  end
  return bad
end

-- Ligne jouet : 3 fours 2×2 en (0,0), (5,0), (10,0) ; tapis sous la cellule 2 (y = 2) ; poteau à l'est de la cellule 3 (12,1).
local LINE = {
  cells = { { x = 0, y = 0, w = 2, h = 2 }, { x = 5, y = 0, w = 2, h = 2 }, { x = 10, y = 0, w = 2, h = 2 } },
  belts = { { 5, 2 }, { 6, 2 }, { 7, 2 }, { 3, 3 } },
  poles = { { 12, 1 } },
}
local function det_plan(plan)
  local bad = {}
  local p = plan(LINE, S.s3)
  if not (#p.grow == 1 and p.grow[1].i == 1) then bad[#bad + 1] = "une seule cellule grandit : la 1" end
  if not (#p.blocked == 2 and p.blocked[1].i == 2 and p.blocked[1].conflit == "5,2") then bad[#bad + 1] = "cellule 2 bloquée par le tapis (5,2)" end
  if not (p.blocked[2] and p.blocked[2].i == 3 and p.blocked[2].conflit == "12,1") then bad[#bad + 1] = "cellule 3 bloquée par le poteau (12,1)" end
  if p.evolutif ~= false then bad[#bad + 1] = "ligne non évolutive" end
  local q = plan({ cells = { { x = 0, y = 0, w = 3, h = 3 } }, belts = { { 0, -1 } }, poles = { { 3, 0 } } }, S.s3)
  if not (q.evolutif and #q.grow == 1) then bad[#bad + 1] = "même gabarit : tout grandit (rien à faire)" end
  return bad
end

---------------------------------------------------------------------------------------------------
section("§1 footprint, anchor, grown")
---------------------------------------------------------------------------------------------------
local bad = det_footprint(Bl.footprint)
check(#bad == 0, "footprint : " .. join(bad))
bad = det_anchor(Bl.anchor)
check(#bad == 0, "anchor : " .. join(bad))
bad = det_grown(Bl.anchor, Bl.grown)
check(#bad == 0, "grown : " .. join(bad))
check(same(Bl.footprint(nil, S.s3), S.s3), "now nil : target")
check(same(Bl.footprint({}, {}), { w = 0, h = 0 }), "tables vides : 0×0, jamais nil")

---------------------------------------------------------------------------------------------------
section("§2 pitch, interface")
---------------------------------------------------------------------------------------------------
check(Bl.pitch(S.s3) == 9, "pitch 3×3, un tapis, sans passage : 3×2+1+2 = 9")
check(Bl.pitch(S.s3, 2, 1) == 11, "pitch 3×3, deux tapis, passage 1 : 11")
check(Bl.pitch(S.s2, 1, 0) == 7 and Bl.pitch(S.s5, 1, 0) == 13, "pitch 2×2 : 7 ; 5×5 : 13")
check(Bl.pitch(S.s3) >= Bl.pitch(S.s2), "réserver la cible : le pas cible n'est jamais plus petit que l'actuel")
bad = det_interface(Bl.interface, Bl.anchor)
check(#bad == 0, "interface : " .. join(bad))
local it = Bl.interface(S.s3, S.s2)
check(it["in"].x == 1 and it.out.x == 1 and it["in"].reach == 1 and it.out.reach == 2, "2→3 : colonne centrale 1, portées 1 (nord) et 2 (sud)")
check(it["in"].margin == 0 and it.out.margin == 1, "2→3 : marges nord 0, sud 1")
it = Bl.interface(S.s5, S.s3)
check(it["in"].x == 2 and it.out.y == 5 and it["in"].margin == 1 and it.out.margin == 1, "3→5 : colonne 2, sortie à y = 5, marges 1 et 1")
check(Bl.interface(S.s3).ok and not Bl.interface(S.s3).long, "now absent : cible seule, bras courts")

---------------------------------------------------------------------------------------------------
section("§3 grow, decide")
---------------------------------------------------------------------------------------------------
bad = det_grow(Bl.grow)
check(#bad == 0, "grow : " .. join(bad))
bad = det_decide(Bl.decide)
check(#bad == 0, "decide : " .. join(bad))
check(Bl.decide("true", true) == "ajourne", "can_place non booléen : ajourne")
local never_nil = true
for _, a in ipairs({ true, false, 0, "x" }) do for _, b in ipairs({ true, false, 0, "x" }) do if Bl.decide(a, b) == nil then never_nil = false end end end
check(never_nil, "decide jamais nil")

---------------------------------------------------------------------------------------------------
section("§4 plan sur une ligne jouet, déterminisme")
---------------------------------------------------------------------------------------------------
bad = det_plan(Bl.plan)
check(#bad == 0, "plan : " .. join(bad))
local p = Bl.plan(LINE, S.s3)
check(p.blocked[1].rect.x == 5 and p.blocked[1].rect.y == 0 and p.blocked[1].rect.w == 3, "rect agrandi de la cellule 2 : (5,0) 3×3")
check(join(p.blocked[1].conflits) == "5,2 6,2 7,2", "cellule 2 : les trois tapis en conflit, triés")
-- déterminisme : la même ligne avec les listes à l'envers et un ensemble `occupied` rempli dans un autre ordre
local function rev(l) local o = {} for i = #l, 1, -1 do o[#o + 1] = l[i] end return o end
local p2 = Bl.plan({ cells = LINE.cells, belts = rev(LINE.belts), poles = rev(LINE.poles) }, S.s3)
local eq = #p2.grow == #p.grow and #p2.blocked == #p.blocked
for i, b in ipairs(p.blocked) do if p2.blocked[i].i ~= b.i or join(p2.blocked[i].conflits) ~= join(b.conflits) then eq = false end end
check(eq, "plan : listes à l'envers, même diagnostic")
local occ_a, occ_b = {}, {}
local keys = { Bl.key(2, 2), Bl.key(0, 2), Bl.key(2, 0), Bl.key(1, 2) }
for i = 1, #keys do occ_a[keys[i]] = true; occ_b[keys[#keys + 1 - i]] = true end
local _, ca = Bl.grow({ { x = 0, y = 0, w = 2, h = 2 } }, 1, S.s3, occ_a)
local _, cb = Bl.grow({ { x = 0, y = 0, w = 2, h = 2 } }, 1, S.s3, occ_b)
check(join(ca) == join(cb) and join(ca) == "0,2 1,2 2,0 2,2", "grow : même ensemble, autre insertion, mêmes conflits triés")
local r1, r2 = Bl.interface(S.s5, S.s3), Bl.interface(S.s5, S.s3)
check(r1["in"].x == r2["in"].x and r1.out.y == r2.out.y and r1.long == r2.long, "interface : deux appels, même résultat")

---------------------------------------------------------------------------------------------------
section("§5 mutants : chacun vu par les mêmes détecteurs")
---------------------------------------------------------------------------------------------------
-- M1 : max par axe remplacé par now (l'empreinte cible n'est pas réservée)
local function m_footprint(now, target) now = now or target; return { w = now.w or 0, h = now.h or 0 } end
check(#det_footprint(m_footprint) > 0, "mutant M1 (footprint = now) vu")
-- M2 : centrage perdu (machine toujours au coin nord-ouest)
local function m_anchor() return { x = 0, y = 0 } end
check(#det_anchor(m_anchor) > 0, "mutant M2 (centrage perdu) vu par det_anchor")
check(#det_grown(m_anchor, Bl.grown) > 0, "mutant M2 (centrage perdu) vu par la preuve de contenance (grown)")
-- M3 : collision ignorée (toujours ok)
local function m_grow() return true, {} end
check(#det_grow(m_grow) > 0, "mutant M3 (collision ignorée) vu")
-- M4 : decide qui upgrade malgré can_place faux
local function m_decide(_, ok) return ok and "upgrade" or "ajourne" end
check(#det_decide(m_decide) > 0, "mutant M4 (can_place ignoré) vu")
-- M5 : plan qui oublie les poteaux
local function m_plan(line, target) return Bl.plan({ cells = line.cells, belts = line.belts, poles = {} }, target) end
check(#det_plan(m_plan) > 0, "mutant M5 (poteaux oubliés) vu")
-- M6 : interface sans bras long (marge ignorée : tout court, tout ok)
local function m_interface(target, now)
  local it = Bl.interface(target, now)
  it["in"].long, it.out.long, it.long, it.ok = false, false, false, true
  it["in"].reach, it.out.reach = 1, 1
  return it
end
check(#det_interface(m_interface, Bl.anchor) > 0, "mutant M6 (bras long nié) vu")
-- M7 : conflits non triés (ordre d'insertion inverse)
local function m_grow_unsorted(cells, i, size, occ) local ok, c = Bl.grow(cells, i, size, occ); return ok, rev(c) end
check(#det_grow(m_grow_unsorted) > 0, "mutant M7 (conflits non triés) vu")

print(string.format("box_layout_test : %d OK, %d ECHEC", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
