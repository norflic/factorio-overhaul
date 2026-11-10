--[[
  Lot MALL-DIRECTIONS (directive du DC du 10/11, priorité 2) : banc HORS JEU des séries de mall dans les QUATRE directions.
    lua5.2 tests/serie_dirs_test.lua   -> [SERIE-DIRS] BILAN : N OK, 0 ECHEC(S)
    §1 shared/team/serie_dirs.lua : repères (frame, dir_of, cross), voisins, candidats rangés (préférée, distance au bus, ordre canonique),
       refus écrits, choix, rotations, déterminisme ;
    §2 Mp.serie_dir / Mp.check_serie_dir (shared/team/mall_paving.lua) : vers l'ouest et le nord par reflet, symétriques de l'est et du sud
       (entrée sur la dernière tuile avant la rue, sortie sur la première après, corps à une tuile), refus (portée) ; Mp.pave_origin_dir ;
    §3 Mr.rues (shared/team/mall_rangee.lua) : rues du treillis en abscisse canonique aux 4 repères ;
    §4 Mr.serie_cells : cellules poussées après la rue, entrée libre ou dans la dernière tuile de la cellule précédente, portée ;
    §5 Mr.section avec série : souterrains typés, rallonge, poteaux relais dans la rangée de passage, rien sur la rue, lignes avec `ug`,
       répartition entre deux sections (celle qui porte l'entrée la pose) ;
    §6 câblage (sources) : P.fit opts.rot, ruban orientable, Build.Pave.rotations / serie_dir / pave_origin_dir, Rt.cells_max, journal ;
    §7 MUTANTS (substitution du source) : préférence ignorée, distance ignorée, lot pris accepté, reflet des sections faux, reflet des tuiles
       faux, cellule laissée sur la rue, portée ignorée, sortie du souterrain absente.
]]
package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("  ECHEC : " .. label) end
  return cond
end
local function read(path) local fh = assert(io.open(path, "rb")) local s = fh:read("*a") fh:close() return s end
local function load_src(path, src) return assert(load(src or read(path), "=" .. path, "t", _ENV))() end

local SD_PATH, MP_PATH, MR_PATH = "shared/team/serie_dirs.lua", "shared/team/mall_paving.lua", "shared/team/mall_rangee.lua"
local Sd = load_src(SD_PATH)
local Mp = load_src(MP_PATH)
local Mr = load_src(MR_PATH)
local Cat = require("shared.team.motifs.catalogue")
local P = require("shared.team.plan")

local LOTS = { pitch = 28, lot = 24, ox = 0, oy = 0 } -- lot i en [28 i, 28 i + 24), rue [28 i + 24, 28 i + 28)
local STREET = { w = 4, underground_reach = 5 }

---------------------------------------------------------------------------------------------------
print("== §1 serie_dirs : reperes, voisins, candidats")
---------------------------------------------------------------------------------------------------
check(Sd.frame(2) == 0 and Sd.frame(4) == 1 and Sd.frame(6) == 2 and Sd.frame(0) == 3, "frame : est 0, sud 1, ouest 2, nord 3")
for k = 0, 3 do check(Sd.frame(Sd.dir_of(k)) == k, "dir_of inverse de frame (k = " .. k .. ")") end
check(Sd.cross(7, 0, 14) == 7 and Sd.cross(7, 1, 14) == 6 and Sd.cross(7, 2, 14) == 6 and Sd.cross(7, 3, 14) == 7, "cross : ligne y = 7 d'un gabarit de 14 -> 7, 6, 6, 7")
do
  -- la même ligne, par M.rotate : la tuile (0, 7) d'un gabarit 11 x 14
  local M = require("shared.team.modules")
  for k = 0, 3 do
    local g = { w = 11, h = 14, entities = { { name = "transport-belt", x = 0.5, y = 7.5, dir = 2 } }, anchors = {}, ports = {} }
    local r = M.rotate(g, k)
    local e = r.entities[1]
    local across = (k % 2 == 0) and math.floor(e.y) or math.floor(e.x)
    check(across == Sd.cross(7, k, 14), "cross suit M.rotate (k = " .. k .. " : " .. across .. ")")
  end
end
local v = Sd.voisin({ i = 3, j = -2 }, 6)
check(v.i == 2 and v.j == -2, "voisin ouest de 3:-2 = 2:-2")
check(Sd.along(10, 5, 6) == -10 and Sd.along(10, 5, 4) == 5, "along : projection signee")

local function rect_of(i, j) return 28 * i, 28 * j, 28 * i + 24, 28 * j + 24 end
local function occ_of(t)
  return function(i, j)
    local o = t[i .. ":" .. j]
    if o == nil then return false, "hors du treillis" end
    if o == true then return true end
    return false, o
  end
end
do
  local occ = occ_of({ ["1:0"] = "projet 5", ["0:1"] = true, ["-1:0"] = true, ["0:-1"] = nil })
  local cands, refus = Sd.candidats({ i = 0, j = 0 }, rect_of, occ, { bus = { x = -40, y = 12 } })
  check(#cands == 2 and cands[1].dir == 6 and cands[2].dir == 4, "bus a l'ouest : ouest avant sud (" .. tostring(cands[1] and cands[1].nom) .. ")")
  check(#refus == 2 and refus[1].dir == 2 and refus[1].cause == "projet 5" and refus[2].dir == 0 and refus[2].cause == "hors du treillis", "refus ecrits : est (projet 5), nord (hors du treillis)")
  check(cands[1].key == "-1:0" and cands[1].rect.x0 == -28 and cands[1].rect.x1 == -4 and cands[1].k == 2, "candidat : cle, rectangle du lot voisin, rotation k = 2")
  local c2 = Sd.candidats({ i = 0, j = 0 }, rect_of, occ, { bus = { x = -40, y = 12 }, prefer = 4 })
  check(c2[1].dir == 4 and c2[2].dir == 6, "continuite : la direction deja prise passe d'abord")
  local c3 = Sd.candidats({ i = 0, j = 0 }, rect_of, occ, {})
  check(c3[1].dir == 4 and c3[2].dir == 6, "sans bus ni preference : ordre canonique est, sud, ouest, nord (est pris)")
  local rots = Sd.rotations(cands)
  check(#rots == 4 and rots[1] == 2 and rots[2] == 1 and rots[3] == 0 and rots[4] == 3, "rotations : les voisins libres d'abord (ouest 2, sud 1), puis le reste (0, 3)")
  local pick = Sd.choisir(cands, refus)
  check(pick and pick.dir == 6, "choisir : le premier")
  local none, why = Sd.choisir({}, refus)
  check(none == nil and why == "aucun lot voisin libre (est : projet 5, nord : hors du treillis)", "choisir sans candidat : raison ecrite (" .. tostring(why) .. ")")
  -- déterminisme : deux appels identiques
  local a1 = Sd.candidats({ i = 0, j = 0 }, rect_of, occ, { bus = { x = 0, y = 0 } })
  local a2 = Sd.candidats({ i = 0, j = 0 }, rect_of, occ, { bus = { x = 0, y = 0 } })
  check(a1[1].dir == a2[1].dir and a1[2].dir == a2[2].dir, "deterministe")
  -- égalité de distance : ordre canonique
  local occ4 = occ_of({ ["1:0"] = true, ["0:1"] = true, ["-1:0"] = true, ["0:-1"] = true })
  local c4 = Sd.candidats({ i = 0, j = 0 }, rect_of, occ4, { bus = { x = 12, y = 12 } })
  check(c4[1].dir == 2 and c4[2].dir == 4 and c4[3].dir == 6 and c4[4].dir == 0, "egalite de distance : est, sud, ouest, nord")
end

---------------------------------------------------------------------------------------------------
print("== §2 Mp.serie_dir : les quatre directions par reflet")
---------------------------------------------------------------------------------------------------
do
  local function origin(x, y) return { x = x, y = y, w = 11, h = 14, belts = { 7 } } end
  local sizes = { { w = 11, h = 14 }, { w = 11, h = 14 } }
  local e = assert(Mp.serie_dir(origin(4, 3), sizes, 2, LOTS, Mp.GAP, STREET))
  check(e.dir == 2 and e.sections[2].x == 29 and e.sections[2].lot.i == 1, "est : section 2 en x = 29 (lot 1), comme Mp.serie")
  check(Mp.check_serie_dir(e, LOTS, STREET), "est : check_serie_dir")
  local w = assert(Mp.serie_dir(origin(29, 3), sizes, 6, LOTS, Mp.GAP, STREET))
  check(w.dir == 6 and w.sections[1].x == 29 and w.sections[2].x == 12 and w.sections[2].y == 3 and w.sections[2].lot.i == 0 and w.sections[2].lot.j == 0,
    "ouest : section 2 en x = 12 (corps 12..22, a une tuile de la rue 24..27), lot 0:0 (" .. tostring(w.sections[2].x) .. ")")
  local t = w.traversees[1]
  check(t and t.entree.x == 28 and t.sortie.x == 23 and t.entree.y == 10 and t.sortie.y == 10 and t.dir == 6 and t.ecart == 5 and #t.rallonge == 0,
    "ouest : entree sur la premiere tuile du lot 1 (28), sortie sur la derniere du lot 0 (23), ligne y = 10, vers l'ouest")
  local okw, whyw = Mp.check_serie_dir(w, LOTS, STREET)
  check(okw, "ouest : check_serie_dir (" .. tostring(whyw) .. ")")
  local s = assert(Mp.serie_dir({ x = 3, y = 4, w = 14, h = 11, belts = { 7 } }, { { w = 14, h = 11 }, { w = 14, h = 11 } }, 4, LOTS, Mp.GAP, STREET))
  check(s.dir == 4 and s.sections[2].y == 29 and s.sections[2].lot.j == 1, "sud : section 2 en y = 29 (lot 0:1)")
  local n = assert(Mp.serie_dir({ x = 3, y = 29, w = 14, h = 11, belts = { 7 } }, { { w = 14, h = 11 }, { w = 14, h = 11 } }, 0, LOTS, Mp.GAP, STREET))
  check(n.dir == 0 and n.sections[2].y == 12 and n.sections[2].x == 3 and n.sections[2].lot.j == 0 and n.sections[2].lot.i == 0, "nord : section 2 en y = 12, lot 0:0")
  local tn = n.traversees[1]
  check(tn and tn.entree.y == 28 and tn.sortie.y == 23 and tn.entree.x == 10 and tn.dir == 0, "nord : entree y = 28, sortie y = 23, colonne x = 10")
  check(Mp.check_serie_dir(n, LOTS, STREET) and Mp.check_serie_dir(s, LOTS, STREET), "sud et nord : check_serie_dir")
  -- symétrie exacte est / ouest : les tuiles du corridor de l'une sont le reflet de l'autre (x <-> 51 - x : le reflet autour du milieu des lots 0 et 1)
  local function tiles(res)
    local out = {}
    for _, tr in ipairs(res.traversees) do
      out[#out + 1] = tr.entree.x; out[#out + 1] = tr.sortie.x
      for _, r in ipairs(tr.rallonge) do out[#out + 1] = r.x end
    end
    table.sort(out)
    return out
  end
  local e2 = assert(Mp.serie_dir(origin(12, 3), sizes, 2, LOTS, Mp.GAP, STREET))
  local te, tw = tiles(e2), tiles(w)
  local sym = #te == #tw
  for i = 1, #te do if te[i] ~= 51 - tw[#tw + 1 - i] then sym = false end end
  check(sym, "est depuis x = 12 et ouest depuis x = 29 : corridors reflets l'un de l'autre")
  -- refus : portée
  local bad, why = Mp.serie_dir(origin(29, 3), sizes, 6, LOTS, Mp.GAP, { w = 4, underground_reach = 4 })
  check(bad == nil and why:find("portee insuffisante", 1, true), "ouest, portee 4 : refus ecrit")
  -- rallonge vers l'ouest : section 1 plus loin de la rue
  local w2 = assert(Mp.serie_dir(origin(36, 3), sizes, 6, LOTS, Mp.GAP, STREET))
  local t2 = w2.traversees[1]
  check(#t2.rallonge == 7 and t2.rallonge[1].x == 35 and t2.rallonge[7].x == 29 and t2.entree.x == 28, "ouest : rallonge de 35 a 29 puis entree en 28")
  -- pave_origin_dir
  local prev = { x0 = 31, y0 = 3, x1 = 42, y1 = 17 }
  local rect = { x0 = 28, y0 = 0, x1 = 52, y1 = 24 }
  local ow = assert(Mp.pave_origin_dir(prev, { w = 1, h = 14 }, rect, 1, 1, 6))
  check(ow.x == 29 and ow.y == 3 and ow.dir == 6, "pave_origin_dir ouest : colle a l'ouest du precedent (x = 29, a la marge de la rue)")
  local oe = assert(Mp.pave_origin_dir(prev, { w = 5, h = 14 }, rect, 1, 1, 2))
  check(oe.x == 43 and oe.axis == "x", "pave_origin_dir est : Mp.pave_origin (x = 43)")
  local no = select(2, Mp.pave_origin_dir(prev, { w = 11, h = 14 }, rect, 1, 1, 6))
  check(type(no) == "string" and no:find("lot plein", 1, true), "pave_origin_dir ouest : lot plein ecrit")
  local on = assert(Mp.pave_origin_dir({ x0 = 31, y0 = 12, x1 = 42, y1 = 20 }, { w = 11, h = 8 }, rect, 1, 1, 0))
  check(on.y == 3 and on.x == 31, "pave_origin_dir nord : au nord du precedent (y = 3)")
end

---------------------------------------------------------------------------------------------------
print("== §3 Mr.rues : rues du treillis en abscisse canonique")
---------------------------------------------------------------------------------------------------
do
  local r0 = Mr.rues({ ox = 10, oy = 0, k = 0 }, LOTS, 0, 60)
  check(#r0 == 2 and r0[1].a0 == 14 and r0[1].a1 == 18 and r0[2].a0 == 42 and r0[2].a1 == 46, "k = 0 (est), ox = 10 : rues en a = 14..17 et 42..45")
  local r2 = Mr.rues({ ox = 50, oy = 0, k = 2 }, LOTS, 0, 60)
  check(#r2 == 2 and r2[1].a0 == 22 and r2[1].a1 == 26 and r2[2].a0 == 50 and r2[2].a1 == 54, "k = 2 (ouest), ox = 50 : rue 24..27 -> a = 22..25, rue -4..-1 -> a = 50..53")
  local r1 = Mr.rues({ ox = 0, oy = 10, k = 1 }, LOTS, 0, 60)
  check(#r1 == 2 and r1[1].a0 == 14 and r1[2].a0 == 42, "k = 1 (sud), oy = 10 : comme l'est le long de y")
  local r3 = Mr.rues({ ox = 0, oy = 50, k = 3 }, LOTS, 0, 60)
  check(#r3 == 2 and r3[1].a0 == 22 and r3[2].a0 == 50, "k = 3 (nord), oy = 50 : comme l'ouest le long de y")
  check(#Mr.rues({ ox = 10, oy = 0, k = 0 }, LOTS, 20, 60) == 1, "a_min = 20 : la rue en 14 est ecartee")
  check(#Mr.rues({ ox = 10, oy = 0, k = 0 }, { pitch = 24, lot = 24, ox = 0, oy = 0 }, 0, 60) == 0, "sans rue (pitch = lot) : rien")
  -- la tuile canonique a et la tuile du monde se correspondent (k = 2 : ox - a - 1)
  local wx = select(1, Mr.to_world(22 + 0.5, 6.5, 2, 2, 50, 0, 1))
  check(math.floor(wx) == 27, "k = 2 : la tuile canonique 22 est la tuile du monde 27 (derniere de la rue)")
end

---------------------------------------------------------------------------------------------------
print("== §4 Mr.serie_cells : cellules poussees apres la rue")
---------------------------------------------------------------------------------------------------
do
  local sc = assert(Mr.serie_cells(6, { { a0 = 14, a1 = 18 } }, 5))
  check(sc.shift[3] == 0 and sc.shift[4] == 6 and sc.shift[5] == 6 and sc.shift[6] == 6, "cellule 4 (12..15) touche la rue 14..17 : poussee en 18 (decalage 6), les suivantes aussi")
  local t = sc.trav[1]
  check(#sc.trav == 1 and t.avant == 4 and t.a_in == 13 and t.a_out == 18 and #t.rallonge == 1 and t.rallonge[1] == 12, "traversee : entree 13, sortie 18, rallonge { 12 }, avant la cellule 4")
  local fl = assert(Mr.serie_cells(6, { { a0 = 12, a1 = 16 } }, 5))
  check(fl.shift[4] == 4 and fl.trav[1].a_in == 11 and fl.trav[1].a_out == 16 and #fl.trav[1].rallonge == 0, "fin de cellule collee a la rue : entree 11 (derniere tuile de la cellule 3), aucune rallonge")
  local two = assert(Mr.serie_cells(12, { { a0 = 14, a1 = 18 }, { a0 = 42, a1 = 46 } }, 5))
  check(#two.trav == 2 and two.trav[2].avant == 10 and two.trav[2].a_in == 41 and two.shift[12] == 10 and two.shift[9] == 6, "deux rues : deux traversees (cellule 10 en 46), decalages cumules 6 puis 10")
  local none = assert(Mr.serie_cells(3, { { a0 = 14, a1 = 18 } }, 5))
  check(#none.trav == 0 and none.shift[3] == 0, "trois cellules avant la rue : rien a franchir")
  local bad, why = Mr.serie_cells(6, { { a0 = 14, a1 = 18 } }, 4)
  check(bad == nil and why:find("hors de la portee", 1, true), "portee 4 pour un ecart de 5 : refus ecrit")
  local nor = select(2, Mr.serie_cells(6, { { a0 = 14, a1 = 18 } }, nil))
  check(type(nor) == "string", "portee inconnue : refus")
  check(#assert(Mr.serie_cells(6, {}, nil)).trav == 0, "sans rue : rien, meme sans portee")
end

---------------------------------------------------------------------------------------------------
print("== §5 Mr.section avec serie : souterrains, rallonge, poteaux relais, rien sur la rue")
---------------------------------------------------------------------------------------------------
local NAMES = { machine = "assembling-machine-1", bras = "inserter", bras_long = "long-handed-inserter", tapis = "transport-belt", poteau = "small-electric-pole",
  coffre = "iron-chest", souterrain = "underground-belt" }
local function modele()
  local inst = Cat.instancier(Mr.MOTIF, 1, { rot = 0, miroir = false })
  return assert(Mr.modele(inst.pieces))
end
local function row_of(n)
  local cells = {}
  for i = 1, n do cells[i] = { h = "r-h" .. i, b = "r-b" .. i, ih = "it-h" .. i, ib = "it-b" .. i } end
  return { j = 1, voies = { "fer", "cuivre", "acier", "pierre" }, cells = cells }
end
local function count(ents, fn) local n = 0 for _, e in ipairs(ents) do if fn(e) then n = n + 1 end end return n end
do
  local rep = { ox = 0, oy = 0, k = 0 }
  local serie = assert(Mr.serie_cells(6, { { a0 = 14, a1 = 18 } }, 5))
  local sec = Mr.section(P, modele(), row_of(5), 1, 5, NAMES, rep, false, nil, serie)
  local ents = sec.ents
  check(count(ents, function(e) return e.name == "underground-belt" and e.type == "input" and math.floor(e.x) == 13 end) == 2, "deux entrees de souterrain en x = 13 (lignes 6 et 7)")
  check(count(ents, function(e) return e.name == "underground-belt" and e.type == "output" and math.floor(e.x) == 18 end) == 2, "deux sorties en x = 18 (premiere tuile de la cellule 4)")
  check(count(ents, function(e) return e.name == "transport-belt" and math.floor(e.x) == 12 and e.role == "mall-serie" end) == 2, "rallonge : deux tapis en x = 12")
  check(count(ents, function(e) return math.floor(e.x) >= 14 and math.floor(e.x) <= 17 end) == 0, "rien sur la rue (x = 14..17)")
  check(count(ents, function(e) return e.role == "mall-poteau" and math.floor(e.y) == -1 and (math.floor(e.x) == 13 or math.floor(e.x) == 18) end) == 2, "deux poteaux relais dans la rangee de passage (y = -1), en 13 et 18")
  check(count(ents, function(e) return e.name == "assembling-machine-1" and e.x == 23.5 end) == 2, "cellule 5 poussee de 6 : machines en x = 23,5")
  check(count(ents, function(e) return e.name == "transport-belt" and math.floor(e.x) == 18 end) == 0, "la premiere tuile de tapis de la cellule 4 est remplacee (aucun tapis en 18)")
  local ug_line = 0
  for _, l in ipairs(sec.lines[1]) do if l.ug == "input" or l.ug == "output" then ug_line = ug_line + 1 end end
  check(ug_line == 2, "la ligne 1 porte l'entree et la sortie marquees ug (purete)")
  -- continuité de flux : les tapis de la ligne 1 rangés par flow couvrent 0..13 puis 18..
  local xs = {}
  for _, l in ipairs(sec.lines[1]) do xs[#xs + 1] = l.x end
  table.sort(xs)
  local cont = xs[1] == 0 and xs[14] == 13 and xs[15] == 18 and #xs == 14 + 2 * 4
  check(cont, "ligne 1 : tuiles 0..13 puis 18..25, continue de part et d'autre du souterrain (" .. #xs .. ")")
  -- fin collée : l'entrée dans la dernière tuile de la cellule 3, posée par la section qui porte la cellule 3
  local fl = assert(Mr.serie_cells(6, { { a0 = 12, a1 = 16 } }, 5))
  local s13 = Mr.section(P, modele(), row_of(5), 1, 3, NAMES, rep, false, nil, fl)
  check(count(s13.ents, function(e) return e.name == "underground-belt" and e.type == "input" and math.floor(e.x) == 11 end) == 2
    and count(s13.ents, function(e) return e.name == "transport-belt" and math.floor(e.x) == 11 end) == 0, "section 1-3 : la derniere tuile de la cellule 3 est l'entree (x = 11)")
  check(count(s13.ents, function(e) return e.name == "underground-belt" and e.type == "output" end) == 0 and count(s13.ents, function(e) return math.floor(e.y) == -1 end) == 0,
    "section 1-3 : ni sortie ni poteau relais (ils vont avec la cellule 4)")
  local s45 = Mr.section(P, modele(), row_of(5), 4, 5, NAMES, rep, false, nil, fl)
  check(count(s45.ents, function(e) return e.name == "underground-belt" and e.type == "output" and math.floor(e.x) == 16 end) == 2
    and count(s45.ents, function(e) return e.name == "underground-belt" and e.type == "input" end) == 0
    and count(s45.ents, function(e) return math.floor(e.y) == -1 end) == 2, "section 4-5 : les sorties (x = 16) et les deux relais, aucune entree en double")
  -- aux quatre repères : rien sur la rue du monde
  for _, k in ipairs({ 0, 1, 2, 3 }) do
    local rp = { ox = 0, oy = 0, k = k }
    local sk = Mr.section(P, modele(), row_of(5), 1, 5, NAMES, rp, false, nil, serie)
    local on_street = 0
    for _, e in ipairs(sk.ents) do
      local a = select(1, Mr.from_world(e.x, e.y, k, 0, 0))
      if a >= 14 and a < 18 then on_street = on_street + 1 end
    end
    local ugs = count(sk.ents, function(e) return e.name == "underground-belt" end)
    local d = nil
    for _, e in ipairs(sk.ents) do if e.name == "underground-belt" then d = e.dir end end
    check(on_street == 0 and ugs == 4 and d == Sd.dir_of(k), "k = " .. k .. " : rien sur la rue, 4 souterrains orientes " .. tostring(d))
  end
  -- sans série : inchangé (aucun souterrain, aucun décalage)
  local plain = Mr.section(P, modele(), row_of(5), 1, 5, NAMES, rep, false, nil, nil)
  check(count(plain.ents, function(e) return e.name == "underground-belt" end) == 0 and count(plain.ents, function(e) return e.name == "assembling-machine-1" and e.x == 17.5 end) == 2, "sans serie : geometrie d'avant")
end

---------------------------------------------------------------------------------------------------
print("== §6 cablage (sources)")
---------------------------------------------------------------------------------------------------
do
  local PL = read("shared/team/plan.lua")
  check(PL:find("for _, k in ipairs(opts.rot or P.ROT_ALL) do", 1, true), "plan.lua : P.fit n'essaie que les rotations permises (opts.rot)")
  local PT = read("shared/team/patrons.lua")
  check(not PT:find("b.g.no_rotate = true\n  b.g.ruban", 1, true) and PT:find('b.g.ruban = { belts = { yB }, port = firstA, fam = "ruban-" .. machine }', 1, true), "patrons.lua : le ruban est orientable")
  local B = read("script/team/build.lua")
  check(B:find("function Build.Pave.rotations(b, c, states, toward)", 1, true) and B:find("Sd.candidats({ i = c.l.i, j = c.l.j }, rect_of, occupation, { bus = toward })", 1, true), "build.lua : Build.Pave.rotations par Sd.candidats")
  check(B:find("Mp.serie_dir({ x = prev.ox, y = prev.oy, w = prev.w, h = prev.h, belts = belts },", 1, true) and B:find("belts[i] = Sd.cross(off, k, g.h)", 1, true), "build.lua : Build.Pave.serie dans la direction de la section precedente, lignes tournees")
  check(B:find("fo.free, fo.within, fo.fed, fo.rot = masks.free, sr.within, { [g.ruban.port] = true }, { sr.k }", 1, true), "build.lua : try_serie garde l'orientation de la serie")
  check(B:find('corridor en souterrain (%d voies), direction %s', 1, true), "build.lua : la direction dans la ligne [FO-MALL] serie")
  check(B:find("Mp.pave_origin_dir(prev, { w = r.w, h = r.h, lead = lead }, rect, Mp.GAP, fopts.margin, g.gen == \"ruban\" and Build.Pave.Sd.dir_of(k) or nil)", 1, true), "build.lua : pin colle du cote ou la serie avance")
  check(not B:find("if (prev.k or 0) ~= 0 or prev.h ~= g.h then", 1, true), "build.lua : plus de refus des sections tournees")
  local RT = read("script/team/mall_rangee.lua")
  check(RT:find("function Rt.cells_max(f, st, names)", 1, true) and RT:find("function Rt.serie_of(f, st, row, to, souterrain)", 1, true), "mall_rangee.lua : plafond et serie de la rangee")
  check(RT:find("local serie, swhy = Rt.serie_of(f, st, row, sp.to, sp.names.souterrain)", 1, true) and RT:find("Mr.section(P, modele(), row, sp.from, sp.to, sp.names, st.rep, sp.head == true, extra, serie)", 1, true), "mall_rangee.lua : le plan de section recoit la serie")
  check(RT:find('return nil, "obstacle:rue (souterrain non debloque)"', 1, true), "mall_rangee.lua : sans souterrain, la section qui franchirait est refusee (la rangee s'arrete)")
  check(RT:find("serie : section %d-%d de la rangee %d franchit %d rue(s) en souterrain", 1, true), "mall_rangee.lua : journal [FO-MALL] serie : section ... direction")
  local n_old = 0
  for _ in RT:gmatch("cells_in %+ floor%(%(st%.sect%.ext or 0%) / Mr%.PERIODE%)") do n_old = n_old + 1 end
  check(n_old == 1, "mall_rangee.lua : un seul plafond du secteur (Rt.cap_secteur), " .. n_old)
  -- aucun nom d'objet en dur dans les règles pures
  local SRC = read(SD_PATH) .. read(MP_PATH)
  check(not SRC:find("transport%-belt") and not SRC:find("underground%-belt") and not SRC:find("small%-electric%-pole"), "regles pures : aucun nom de tapis, souterrain ou poteau")
  check(not read(SD_PATH):find("[^i]pairs%("), "serie_dirs.lua : aucun pairs")
end

---------------------------------------------------------------------------------------------------
print("== §7 mutants")
---------------------------------------------------------------------------------------------------
local function mutant(path, from, to)
  local src = read(path)
  local s, n = src:gsub(from, to, 1)
  if n ~= 1 then return nil, "mutation absente : " .. from end
  local ok, mod = pcall(load_src, path, s)
  if not ok then return nil, tostring(mod) end
  return mod
end
local function refuses(label, path, from, to, probe)
  local mod, err = mutant(path, from, to)
  if not mod then check(false, label .. " (" .. tostring(err) .. ")") return end
  local ok, alive = pcall(probe, mod)
  check(not (ok and alive), "mutant refuse : " .. label)
end
local occ_m = occ_of({ ["1:0"] = "projet 5", ["0:1"] = true, ["-1:0"] = true })
refuses("preference ignoree", SD_PATH, "if a%.prefer ~= b%.prefer then return a%.prefer end", "", function(S)
  local c = S.candidats({ i = 0, j = 0 }, rect_of, occ_m, { bus = { x = -40, y = 12 }, prefer = 4 })
  return c[1].dir == 4
end)
refuses("distance ignoree", SD_PATH, "if a%.d ~= b%.d then return a%.d < b%.d end", "", function(S)
  local c = S.candidats({ i = 0, j = 0 }, rect_of, occ_m, { bus = { x = -40, y = 12 } })
  return c[1].dir == 6
end)
refuses("lot pris accepte", SD_PATH, "if libre then", "if true then", function(S)
  local c = S.candidats({ i = 0, j = 0 }, rect_of, occ_m, {})
  return #c == 2 and c[1].dir == 4
end)
refuses("reflet des sections faux", MP_PATH, "t%[A%.a%] = %-%(s%[A%.a%] %+ s%[A%.w%]%)", "t[A.a] = -s[A.a]", function(Q)
  local w = Q.serie_dir({ x = 29, y = 3, w = 11, h = 14, belts = { 7 } }, { { w = 11, h = 14 }, { w = 11, h = 14 } }, 6, LOTS, Q.GAP, STREET)
  return w and w.sections[2].x == 12 and Q.check_serie_dir(w, LOTS, STREET)
end)
refuses("reflet des tuiles faux", MP_PATH, "q%[A%.a%] = %-p%[A%.a%] %- 1", "q[A.a] = -p[A.a]", function(Q)
  local w = Q.serie_dir({ x = 29, y = 3, w = 11, h = 14, belts = { 7 } }, { { w = 11, h = 14 }, { w = 11, h = 14 } }, 6, LOTS, Q.GAP, STREET)
  return w and w.traversees[1].entree.x == 28 and w.traversees[1].sortie.x == 23 and Q.check_serie_dir(w, LOTS, STREET)
end)
refuses("cellule laissee sur la rue", MR_PATH, "if rue and a %+ Mr%.PERIODE > rue%.a0 then", "if rue and a + Mr.PERIODE > rue.a1 then", function(R)
  local sc = R.serie_cells(6, { { a0 = 14, a1 = 18 } }, 5)
  return sc and sc.shift[4] == 6
end)
refuses("portee ignoree", MR_PATH, "if not reach or ecart > reach or ecart < 2 then", "if false then", function(R)
  local bad = R.serie_cells(6, { { a0 = 14, a1 = 18 } }, 4)
  return bad == nil
end)
refuses("sortie du souterrain absente", MR_PATH, 'sw%[t%.a_out%] = "output"', "", function(R)
  local serie = R.serie_cells(6, { { a0 = 14, a1 = 18 } }, 5)
  local sec = R.section(P, modele(), row_of(5), 1, 5, NAMES, { ox = 0, oy = 0, k = 0 }, false, nil, serie)
  return count(sec.ents, function(e) return e.name == "underground-belt" and e.type == "output" end) == 2
end)
refuses("rallonge absente", MR_PATH, "for q = a, a_in %- 1 do t%.rallonge%[#t%.rallonge %+ 1%] = q end", "", function(R)
  local serie = R.serie_cells(6, { { a0 = 14, a1 = 18 } }, 5)
  local sec = R.section(P, modele(), row_of(5), 1, 5, NAMES, { ox = 0, oy = 0, k = 0 }, false, nil, serie)
  return count(sec.ents, function(e) return e.name == "transport-belt" and math.floor(e.x) == 12 end) == 2
end)

print(string.format("[SERIE-DIRS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
