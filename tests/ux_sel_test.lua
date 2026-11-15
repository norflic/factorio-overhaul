--[[
  Lot ux-sel (0.9.8, chantier 3 du DC) : la zone d'un ordre Maj+A / Z / E / R est le RECTANGLE glissé à l'écran, pas un disque.
  Retour visuel, zone d'action et filtres « dans la zone » partagent UNE règle (Co.in_zone, shared/ai3/commande.lua).
  Mutants : le même jeu de contrôles rejoué sur le code où la règle redevient le disque d'avant (le test doit ÉCHOUER).
  Usage : lua5.2 tests/ux_sel_test.lua (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local function read(p) local fh = assert(io.open(p, "rb")) local s = fh:read("*a") fh:close() return s end
local passes, failures = 0, 0
local silent = false
local function check(c, msg)
  if c then passes = passes + 1 else failures = failures + 1 if not silent then print("  ECHEC : " .. msg) end end
end

local CO_SRC = read("shared/ai3/commande.lua")
local MG_SRC = read("shared/team/migration_champ.lua")
local DS_SRC = read("shared/team/defense_stock.lua")

-- Rectangle plat et long (60 x 4) : son disque (demi-diagonale ~30) déborde largement du rectangle en hauteur.
local FLAT = { id = 1, kind = "bastion", x = 100, y = 50, r = 30, x0 = 70, y0 = 48, x1 = 130, y1 = 52 }

local function suite(Co, Mg, Ds)
  local before = failures

  -- 1. Co.rect : arrondi vers l'extérieur, coins dans n'importe quel ordre, côtés bornés
  local r = Co.rect(10.3, 5.7, 50.2, 20.1)
  check(r.x0 == 10 and r.y0 == 5 and r.x1 == 51 and r.y1 == 21, "floor du coin haut-gauche, ceil du coin bas-droit")
  local s = Co.rect(50.2, 20.1, 10.3, 5.7)
  check(s.x0 == r.x0 and s.y0 == r.y0 and s.x1 == r.x1 and s.y1 == r.y1, "coins donnés dans l'ordre inverse : même rectangle")
  check(r.x == 30 and r.y == 13, "centre entier du rectangle")
  local f = Co.rect(0.2, 5.7, 60.1, 5.9)
  check(f.x0 == 0 and f.x1 == 61 and f.y1 - f.y0 >= Co.SIDE_MIN and f.y0 <= 5.7 and f.y1 >= 5.9, "rectangle très plat : côté minimal, sélection contenue")
  local t = Co.rect(10.5, 10.5, 10.5, 10.5)
  check(t.x1 - t.x0 == Co.SIDE_MIN and t.y1 - t.y0 == Co.SIDE_MIN, "simple clic : côté minimal")
  local big = Co.rect(-1000, -1000, 1000, 1000)
  check(big.x1 - big.x0 == Co.SIDE_MAX and big.y1 - big.y0 == Co.SIDE_MAX, "côté borné")
  check(r.r >= Co.R_MIN and r.r <= Co.R_MAX, "r (demi-diagonale bornée) gardé pour les lecteurs d'avant")

  -- 2. Co.in_zone : dedans / dehors / bords / marge
  check(Co.in_zone(FLAT, 100, 50), "centre : dans la zone")
  check(Co.in_zone(FLAT, 70, 48) and Co.in_zone(FLAT, 130, 52), "coins : dans la zone (bords compris)")
  check(not Co.in_zone(FLAT, 69.9, 50) and not Co.in_zone(FLAT, 130.1, 50), "juste hors des bords de la longueur")
  check(not Co.in_zone(FLAT, 100, 47.9) and not Co.in_zone(FLAT, 100, 52.1), "juste hors des bords de la hauteur")
  check(not Co.in_zone(FLAT, 100, 70), "rectangle plat : 20 tuiles au-dessus est dans l'ancien disque (r 30) mais HORS du rectangle")
  check(Co.in_zone(FLAT, 100, 55, 4) and not Co.in_zone(FLAT, 100, 57, 4), "marge : élargit chaque côté")
  check(Co.in_zone({ x = 0, y = 0, r = 10 }, 8, 8) == false and Co.in_zone({ x = 0, y = 0, r = 10 }, 6, 6), "ordre sans rectangle (d'avant) : son disque")
  check(Co.inside == Co.in_zone, "Co.inside et Co.in_zone : une seule règle")

  -- 3. Co.add garde le rectangle (et celui du point A)
  local st = Co.new_state()
  local id = Co.add(st, { kind = "liaison", x = 100, y = 50, r = 30, x0 = 70, y0 = 48, x1 = 130, y1 = 52, tick = 1,
    a = { x = 0, y = 0, r = 10, x0 = -20, y0 = -2, x1 = 20, y1 = 2 } })
  local o = st.orders[1]
  check(id == 1 and o.x0 == 70 and o.y1 == 52 and o.a.x0 == -20 and o.a.y1 == 2, "Co.add : rectangle de l'ordre et du point A conservés")
  local rect, sz = { Co.box_of(o) }, Co.size_of(o)
  check(rect[1] == 70 and rect[4] == 52 and sz == "60 x 4", "Co.box_of / Co.size_of")
  local x0, _, x1 = Co.box_of({ x = 10, y = 10, r = 5 })
  check(x0 == 5 and x1 == 15, "Co.box_of : ancien disque -> carré circonscrit")

  -- 4. les décisions qui filtrent « dans la zone »
  local G = { id = 2, kind = "gisement", resource = "r1", outpost = "k1", x = 100, y = 50, r = 30, x0 = 70, y0 = 48, x1 = 130, y1 = 52, after_oid = 0 }
  local site_in, site_out = { x = 100, y = 50, resource = "r1" }, { x = 100, y = 120, resource = "r1" } -- 70 au-dessus : hors rectangle + marge 24
  check(Co.designated(site_in, { G }) and not Co.designated(site_out, { G }), "Co.designated : site dans / hors du rectangle (marge de site)")
  local pr = Co.prefer({ site_out, site_in }, { G })
  check(pr[1] == site_in, "Co.prefer : site du rectangle d'abord")
  check(#Co.restrict({ site_out, site_in }, { G }) == 1, "Co.restrict : seuls les sites du rectangle")
  local near = { x = 100, y = 50 + 4 + Co.SITE_MARGIN + 0.5, resource = "r1" } -- dans l'ancien disque (r 30 + 24), hors rectangle + marge
  check(not Co.designated(near, { G }), "gisement : hors rectangle + marge de site, même dans l'ancien disque")
  check(#Co.resolve({ orders = { G } }, { { kind = "k1", x = 100, y = 50, id = 5 } }) == 1, "Co.resolve : avant-poste dans le rectangle")
  check(#Co.resolve({ orders = { G } }, { { kind = "k1", x = 100, y = 90, id = 5 } }) == 0, "Co.resolve : avant-poste hors rectangle + marge (dans l'ancien disque)")
  local goals = Co.goals({}, { G }, 1000, {})
  check(goals[1].zones[1].x0 == 70 and Co.in_zones(goals[1].zones, 100, 50) and not Co.in_zones(goals[1].zones, 100, 90), "Co.goals / Co.in_zones : zone du but = rectangle")
  local dep = Co.pick_deposit({ { id = "a", resource = "r1", tiles = 5, x0 = 90, y0 = 80, x1 = 95, y1 = 85 }, { id = "b", resource = "r1", tiles = 3, x0 = 90, y0 = 49, x1 = 95, y1 = 51 } }, G)
  check(dep.id == "b", "Co.pick_deposit : le gisement qui touche le rectangle (pas celui du disque)")
  local fall = Co.pick_deposit({}, G)
  check(fall.x0 == 70 and fall.y1 == 52, "Co.pick_deposit : repli = rectangle de l'ordre")

  local U = { id = 3, kind = "amelioration", x = 100, y = 50, r = 30, x0 = 70, y0 = 48, x1 = 130, y1 = 52 }
  check(Co.upgrade_rank({ U }, 80, 50) == 0 and Co.upgrade_rank({ U }, 100, 60) == 1, "Co.upgrade_rank (Maj+Z) : pièce dans / hors du rectangle")
  local bz = Co.bastion_zones({ orders = { FLAT } }, 8)
  check(#bz == 1 and bz[1].x0 == 70 and bz[1].y1 == 52, "Co.bastion_zones : le rectangle suit jusqu'à la pose des tourelles")

  local L = { id = 4, kind = "liaison", x = 100, y = 50, r = 30, x0 = 70, y0 = 48, x1 = 130, y1 = 52 }
  local pairs_ = { { dock = { x = 100, y = 70 }, src = { x = 100, y = 80 } }, { dock = { x = 100, y = 50 }, src = { x = 0, y = 0 } } }
  check(Co.prefer_pairs(pairs_, { L })[1] == pairs_[2], "Co.prefer_pairs (Maj+E) : paire dont un quai est dans le rectangle d'abord")
  check(Co.liaison_order({ L }, { x = 100, y = 70 }, { x = 100, y = 80 }, nil) == nil and Co.liaison_order({ L }, { x = 110, y = 50 }, nil, nil) == 4,
    "Co.liaison_order : quai dans / hors du rectangle")
  local A = { x = 0, y = 0, r = 10, x0 = -20, y0 = -2, x1 = 20, y1 = 2 }
  local fp = Co.forced_pairs({ { id = 5, kind = "liaison", x = 100, y = 50, r = 30, x0 = 70, y0 = 48, x1 = 130, y1 = 52, a = A } },
    { { key = "d", x = 100, y = 70, item = "i" }, { key = "d2", x = 90, y = 51, item = "i" } }, { { key = "s", x = -10, y = 1, item = "i" }, { key = "s2", x = 0, y = 9, item = "i" } })
  check(#fp == 1 and fp[1].dock.key == "d2" and fp[1].src.key == "s", "Co.forced_pairs : quai de B et sortie de A pris dans leurs rectangles")

  -- tâches : un ouvrier en route vers la zone (dans le rectangle) mais pas à 20 tuiles au-dessus
  local task_in = { created = 10, kind = "build", pos = { x = 100, y = 51 } }
  local task_out = { created = 10, kind = "build", pos = { x = 100, y = 70 } }
  local B = { id = 6, kind = "amelioration", tick = 0, x = 100, y = 50, r = 30, x0 = 70, y0 = 48, x1 = 130, y1 = 52 }
  check(Co.task_hits(B, task_in) and Co.task_hits(B, task_out) == false, "Co.task_hits : tâche dans le rectangle + marge, pas hors")

  -- 5. bande du cadre : celle qui coupe le RECTANGLE d'abord (rectangle plat vertical : seule la bande y = 48..52 le coupe)
  local bands = { 0, 16, 32, 48, 64, 80 } -- axe x : bandes en y, pas 16
  local out = Mg.near_order(bands, "x", FLAT)
  check(out[1] == 48 or out[1] == 32, "near_order : la bande qui coupe le rectangle d'abord (" .. tostring(out[1]) .. ")")
  local sw = Mg.order_swap(bands, "x", FLAT, 0, {})
  check(#sw >= 1 and (sw[1] == 48 or sw[1] == 32), "order_swap : bande en vol hors du rectangle -> bande qui le coupe")
  check(#Mg.order_swap(bands, "x", FLAT, 48, {}) == 0, "order_swap : la bande en vol coupe déjà le rectangle -> rien")
  -- une bande à 20 tuiles du centre est dans l'ancien disque (r 30) mais ne coupe pas le rectangle plat (y 48..52, bande 16 pas)
  check(#Mg.order_swap(bands, "x", FLAT, 80, {}) >= 1, "order_swap : une bande du disque d'avant (hors du rectangle) ne compte pas comme « dans la zone »")

  -- 6. emplacements d'un bastion : dans le rectangle, jamais dans l'ancien disque seulement
  local sp = Ds.spiral(FLAT.x, FLAT.y, FLAT.r, nil, { x0 = FLAT.x0, y0 = FLAT.y0, x1 = FLAT.x1, y1 = FLAT.y1 })
  local allin = #sp > 0
  for _, q in ipairs(sp) do if not Co.in_zone(FLAT, q.x, q.y) then allin = false end end
  check(allin and #sp >= 8 and #sp <= 200, "Ds.spiral (Maj+R) : emplacements tous dans le rectangle plat (" .. #sp .. ")")
  check(sp[1] and sp[1].x == 100 and sp[1].y == 50, "Ds.spiral : du centre vers les bords")
  local dsk = Ds.spiral(100, 50, 30)
  local out_n = 0
  for _, q in ipairs(dsk) do if not Co.in_zone(FLAT, q.x, q.y) then out_n = out_n + 1 end end
  check(out_n > 0, "contrôle : la spirale en disque d'avant sort bien du rectangle plat (" .. out_n .. " points)")
  return failures - before
end

local function load_mod(src, name) return assert(load(src, "=" .. name))() end
local function mutate(src, from, to)
  local a, b = src:find(from, 1, true)
  assert(a, "motif du mutant introuvable : " .. from)
  return src:sub(1, a - 1) .. to .. src:sub(b + 1)
end

print("== ux-sel : règles pures (code réel)")
local n_real = suite(load_mod(CO_SRC, "commande"), load_mod(MG_SRC, "migration_champ"), load_mod(DS_SRC, "defense_stock"))

print("== ux-sel : mutants (la règle redevient le disque d'avant : le test doit échouer)")
silent = true
local mut_co = mutate(CO_SRC, "  if o.x0 ~= nil then\n    return x >= o.x0", "  if false then\n    return x >= o.x0")
local n_mut1 = suite(load_mod(mut_co, "commande-mutant"), load_mod(MG_SRC, "migration_champ"), load_mod(DS_SRC, "defense_stock"))
local mut_mg = mutate(MG_SRC, "  if od.x0 ~= nil then\n    if axis", "  if false then\n    if axis")
local n_mut2 = suite(load_mod(CO_SRC, "commande"), load_mod(mut_mg, "migration_champ-mutant"), load_mod(DS_SRC, "defense_stock"))
silent = false
-- (les mutants rejouent la suite : on retire leurs échecs et leurs réussites du bilan)
failures = n_real
check(n_mut1 > 0, "mutant disque (Co.in_zone) détecté (" .. n_mut1 .. " contrôles échouent)")
check(n_mut2 > 0, "mutant disque (bandes du cadre) détecté (" .. n_mut2 .. " contrôles échouent)")

print("== ux-sel : branchement (texte du code)")
local GUI = read("script/gui/commande.lua")
local draw_src = GUI:match("local function draw%(f, o%).-\nend\n") or ""
check(draw_src:find("draw_rectangle", 1, true) and not draw_src:find("draw_circle", 1, true), "le retour visuel est un rectangle, plus un cercle")
check(draw_src:find('alignment = "left"', 1, true) and draw_src:find("y0 - 1.3", 1, true), "texte du type collé au coin haut-gauche")
check(GUI:find("bx0, y = by0 - 0.1", 1, true), "texte d'état collé au coin haut-gauche")
check(GUI:find("Co.rect(area_of(e))", 1, true), "les outils lisent le rectangle de la sélection")
check(not GUI:find("Co.zone(", 1, true), "plus d'appel à l'ancien disque Co.zone dans l'interface")
check(GUI:find("area = { { bx0, by0 }, { bx1, by1 } }", 1, true), "tourelles du bastion comptées dans le rectangle")
local CAP = read("script/ai3/capital.lua")
check(CAP:find("area = { { zx0, zy0 }, { zx1, zy1 } }", 1, true), "Maj+Z : pièces relevées dans le rectangle")
local DSR = read("script/team/defense_stock.lua")
check(DSR:find("Co.in_zone(zb, pos.x, pos.y)", 1, true), "Maj+R : tourelle posée dans le rectangle")
for _, lang in ipairs({ "fr", "en" }) do
  local cfg = read("locale/" .. lang .. "/commande.cfg")
  check(not cfg:find("ligne%-bastion=[^\n]*radius") and not cfg:find("ligne%-bastion=[^\n]*rayon"), "locale " .. lang .. " : le panneau ne parle plus de rayon")
end

print(string.format("ux_sel_test : %d OK, %d ECHEC", passes, failures))
os.exit(failures == 0 and 0 or 1)
