--[[
  Lot RETROFIT-GABARITS (décision du DC du 10/11 : « rétrofit glissant à gabarits évolutifs : gérer les emprises distinctes (2×2 → 3×3)
  lors du passage aux fours électriques ou assembleurs supérieurs, par réservation d'espace (footprint buffering) pour n'écraser aucun
  convoyeur adjacent »). Réservation d'emprise à la POSE (shared/team/modules.lua : M.reserve, G.row, G.smelter ; règle pure
  shared/team/box_layout.lua) :
    §1 M.reserve : cible = prochain palier d'ère dont le côté grandit (L.footprints, L.parse : aucun nom en dur) ; sans famille, sans
       palier, au dernier palier : rien de réservé ; marges au sud-est (Bl.anchor) ;
    §2 GOLDEN : les gabarits SANS cible sont inchangés à l'octet (empreinte FNV-1a de M.serialize relevée sur release-0.6.77 avant le lot :
       fonderie en pierre, rangée d'assembleurs 1, foreuses, centrale) ;
    §3 four 2×2 avec cible 3×3 (fonderie en acier) : cellules de 3 (g.cell), fours au coin nord-ouest de leur cellule, bras sur la ligne
       d'interface de la cellule (court à l'ouest, LONG à l'est : marge d'une tuile), aucun chevauchement (M.check), toutes les cellules
       peuvent grandir sans toucher un tapis ni un poteau (Bl.plan évolutif) ; même chose pour une rangée d'assembleurs 2 (cellules de 4,
       sortie en bras longs au sud) ;
    §4 lot ILOTS-COLONNES (P4 du DC, 10/11) : les îlots à liaisons par colonne (circuits « C K C », moteurs « P M G », circuits rouges
       « A C A ») sont RÉSERVÉS : colonne de liaison sur la ligne d'interface est de la cellule (Bl.link), bras longs, nombre de machines
       par défaut tenu dans le lot ports compris (3 machines en cellules de 4 : 14 de large), évolutifs (Bl.plan) ; le nombre demandé
       explicitement au-delà (2 paires = 24 + ports) est repris sans réservation : géométrie d'avant à l'octet (clé « -5m », note) ; les
       îlots à l'assembleur 1 (sans cible) et les packs (étage B trop large) : inchangés à l'octet ; variante d'ère au niveau 7 réservée
       (cellules de 5, 17 de large) ; extension bornée au lot ports compris ;
    §5 mutants de modules.lua : marge ignorée (machine au centre), bras court à l'est, cellule = machine : refusés par M.check ou par Bl.plan ;
    §6 lot ILOTS-COLONNES : règle pure Bl.link (portées, bras long, hors de portée, lignes) et ses mutants (portée lue à la mauvaise marge,
       seuil du bras long, seuil du hors de portée) ; mutants de modules.lua (colonne de liaison dans la marge, bras court dans la colonne,
       lot sans les ports, côté cible lu dans le contexte) : refusés par le même détecteur (îlot réservé, valide, évolutif, clés distinctes).
  Usage : lua5.2 tests/gabarits_reserves_test.lua   (depuis la racine du mod ; quelques secondes)
]]
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function section(name) print("== " .. name) end

local M = require("shared.team.modules")
local L = require("shared.levels.config")
local Bl = require("shared.team.box_layout")

local function fnv(s)
  local h = 2166136261
  for i = 1, #s do h = bit32.band(bit32.bxor(h, s:byte(i)) * 16777619, 0xFFFFFFFF) end
  return string.format("%08x", h)
end
local function hash(g) return fnv(M.serialize(g)) end
--- Empreinte de la GÉOMÉTRIE d'un gabarit (tout sauf la clé et les notes : lot ILOTS-COLONNES, le gabarit repris sans réservation garde
--- la géométrie d'avant, sa clé et sa note changent).
local function geo(g) local t = {} for k, v in pairs(g) do if k ~= "notes" and k ~= "key" then t[k] = v end end return fnv(M.serialize(t)) end
local function near(a, b) return math.abs(a - b) < 1e-9 end

-- machines à niveaux lues aux données : le four (famille de type furnace, niveau 1 = four en acier), l'assembleur
local FURN, ASM = nil, nil
for _, fam in ipairs(L.families) do
  if fam.key == "furnace" then FURN = fam end
  if fam.key == "assembler" then ASM = fam end
end
local STEEL, ASM2 = L.name(FURN, 1), L.name(ASM, 1)
local STONE, ASM1 = "stone-furnace", "assembling-machine-1" -- (sans famille à niveaux : témoins « aucune cible » ; noms des DONNÉES vanilla, test seulement)

---------------------------------------------------------------------------------------------------
section("§1 M.reserve : cible lue aux paliers d'ère")
---------------------------------------------------------------------------------------------------
local r = M.reserve(STEEL)
check(r.target ~= nil and r.cell.w == 3 and r.cell.h == 3 and r.west == 0 and r.north == 0 and r.east == 1 and r.south == 1,
  "four en acier (2×2) : cellule 3×3 réservée, marges est et sud")
check(r.target.w == L.footprint(FURN, M.footprint_steps(FURN)[1]), "la cible est le premier palier d'ère qui grandit")
r = M.reserve(ASM2)
check(r.target ~= nil and r.cell.w == 4 and r.east == 1 and r.south == 1, "assembleur 2 (3×3) : cellule 4×4")
r = M.reserve(STONE)
check(r.target == nil and r.cell.w == 2 and r.east == 0 and r.south == 0, "four en pierre (sans famille) : rien de réservé")
r = M.reserve(L.name(FURN, FURN.max))
check(r.target == nil and r.cell.w == L.footprint(FURN, FURN.max), "dernier niveau du four : rien de réservé")
r = M.reserve(L.name(FURN, 7))
check(r.target ~= nil and r.cell.w == L.footprint(FURN, 13), "four de niveau 7 : cellule du palier suivant (niveau 13)")
check(M.reserve(STEEL, true).target == nil, "plain : rien de réservé")
check(#M.LONG_ARMS >= 1 and M.spec(M.LONG_ARMS[1]).reach == Bl.REACH_LONG, "bras longs lus dans BASE (portée 2)")

---------------------------------------------------------------------------------------------------
section("§2 golden : gabarits sans cible inchangés à l'octet (release-0.6.77)")
---------------------------------------------------------------------------------------------------
local GOLD = {
  { "fonderie en pierre, 3 paires", function() return M.GEN.smelter(STONE, "iron-ore", 3) end, "e6f3a699" },
  { "rangée d'engrenages, 3 assembleurs 1", function() return M.GEN.simple("iron-gear-wheel", 3, ASM1) end, "c5d0c103" },
  { "catalogue fonderie-fer-pierre", function() return M.get("fonderie-fer-pierre") end, "e338e968" },
  { "catalogue foreuses-fer", function() return M.get("foreuses-fer") end, "faaf94fc" },
  { "catalogue centrale-vapeur-2", function() return M.get("centrale-vapeur-2") end, "31f71f61" },
  { "catalogue labos-4", function() return M.get("labos-4") end, "fd00034c" },
}
for _, c in ipairs(GOLD) do
  local g = c[2]()
  check(g ~= nil and hash(g) == c[3], c[1] .. " : empreinte " .. tostring(g and hash(g)) .. " = " .. c[3])
  check(g ~= nil and g.cell == nil and #(g.notes or {}) == 0, c[1] .. " : ni cellule ni note")
end

---------------------------------------------------------------------------------------------------
section("§3 four 2×2 avec cible 3×3 : cellules, bras sur la ligne d'interface, aucun chevauchement, évolutif")
---------------------------------------------------------------------------------------------------
--- Cellules (tuiles) des machines de la sorte `kind`, tapis et poteaux d'un gabarit : la ligne de Bl.plan.
local function line_of(g, kind)
  local line = { cells = {}, belts = {}, poles = {} }
  for _, e in ipairs(g.entities) do
    local sp = M.spec(e.name)
    if sp.kind == kind then
      line.cells[#line.cells + 1] = { x = math.floor(e.x - sp.w / 2 + 0.01), y = math.floor(e.y - sp.h / 2 + 0.01), w = sp.w, h = sp.h }
    elseif sp.kind == "belt" then line.belts[#line.belts + 1] = { math.floor(e.x), math.floor(e.y) }
    elseif sp.kind == "pole" or sp.kind == "inserter" then line.poles[#line.poles + 1] = { math.floor(e.x), math.floor(e.y) } end
  end
  return line
end
local function count(g, name) local n = 0 for _, e in ipairs(g.entities) do if e.name == name then n = n + 1 end end return n end

local g = M.GEN.smelter(STEEL, "iron-ore", 3)
check(g ~= nil and g.cell and g.cell.w == 3 and g.cell.h == 3, "fonderie en acier : g.cell = 3×3")
check(g and #M.check(g) == 0, "fonderie en acier réservée : M.check sans erreur (" .. tostring(g and M.check(g)[1]) .. ")")
check(g and g.w == 15 and g.h == 9, "15 × 9 (3 paires de cellules de 3 ; colonnes : tapis, bras, cellule, bras long, vide, tapis, bras, cellule, bras long, vide, tapis)")
local furn = {}
for _, e in ipairs(g.entities) do if e.name == STEEL then furn[#furn + 1] = e end end
local nw_ok = true
for _, e in ipairs(furn) do
  -- four 2×2 au coin nord-ouest d'une cellule de 3 : centre x à 3 ou 10 (+1), y = 1, 4, 7
  if not ((e.x == 3 or e.x == 10) and (e.y - 1) % 3 == 0) then nw_ok = false end
end
check(#furn == 6 and nw_ok, "6 fours au coin nord-ouest de leur cellule (Bl.anchor)")
local long = M.LONG_ARMS[1]
check(count(g, long) == 6, "6 bras longs (entrée ouest à l'est de sa cellule, sortie est à l'est de la sienne), " .. count(g, long))
local plan = Bl.plan(line_of(g, "furnace"), M.reserve(STEEL).target)
check(plan.evolutif and #plan.grow == 6, "Bl.plan : les 6 cellules grandissent vers 3×3 sans toucher tapis, bras ni poteaux (" .. #plan.blocked .. " bloquées)")
-- l'ancien gabarit (sans réservation) n'était PAS évolutif : preuve de la limite d'avant
local g0 = M.with_pole(nil, function() local p = M.reserving M.reserving = false local x = M.GEN.smelter(STEEL, "iron-ore", 3) M.reserving = p return x end)
local plan0 = Bl.plan(line_of(g0, "furnace"), M.reserve(STEEL).target)
check(g0.w == 11 and not plan0.evolutif and #plan0.blocked == 6, "sans réservation (le gabarit d'avant, 11 de large) : aucune cellule ne pouvait grandir")
check(M.reserving == true, "contexte de réservation rétabli")

-- rangée d'assembleurs 2 : cellules de 4, sortie en bras longs au sud, tapis de sortie deux tuiles plus bas
local gr = M.GEN.simple("iron-gear-wheel", 3, ASM2)
check(gr and gr.cell and gr.cell.w == 4 and #M.check(gr) == 0 and gr.w == 14 and gr.h == 9, "rangée de 3 assembleurs 2 : cellules de 4, 14 × 9, contrôle vert")
local out_long, y_out = 0, nil
for _, e in ipairs(gr.entities) do if e.name == long then out_long = out_long + 1 y_out = e.y end end
check(out_long == 6 and y_out == 6.5, "bras de sortie LONGS (2 par assembleur) sur la ligne d'interface sud (y = 6,5) ; tapis en y = 8,5")
local planr = Bl.plan(line_of(gr, "assembler"), M.reserve(ASM2).target)
check(planr.evolutif and #planr.grow == 3, "Bl.plan : les 3 cellules de la rangée grandissent vers 4×4")
-- extension : même règle à chaque taille, bornes d'avant
local ge = M.extend(gr, gr.extensions[1].max)
check(ge ~= nil and #M.check(ge) == 0 and gr.extensions[1].max == 5, "extension à la borne (5, comme avant) valide")

---------------------------------------------------------------------------------------------------
section("§4 limites physiques : gabarit d'avant gardé et noté ; lot ILOTS-COLONNES : îlots à liaisons réservés")
---------------------------------------------------------------------------------------------------
-- lot ILOTS-COLONNES (P4 du DC) : l'îlot de circuits (liaisons par colonne) est RÉSERVÉ : 3 machines « C K C » dans des cellules de 4 (le
-- lot, ports compris, ne tient pas 5 cellules de 4 : 24 + 5 > 24), colonne de liaison sur la ligne d'interface est, bras LONGS
local gc = M.get("circuits-verts")
check(gc and gc.cell and gc.cell.w == 4 and gc.w == 14 and gc.h == 9 and #gc.notes == 0 and #M.check(gc) == 0, "îlot de circuits : réservé (cellules de 4), 14 × 9, sans note, contrôle vert (" .. tostring(gc and (gc.notes[1] or M.check(gc)[1])) .. ")")
check(gc and near(gc.nominal["electronic-circuit"], 1.5), "C K C : 1,5 circuit/s")
local lk = Bl.link(M.reserve(ASM2).cell, M.reserve(ASM2).now)
check(lk.x == 4 and lk.to_west == 2 and lk.to_east == 1 and lk.long and not lk.impossible and lk.rows == 3, "Bl.link (3×3 dans 4×4) : colonne en x = 4, portée 2 vers la machine, 1 vers la voisine, bras long, 3 lignes")
-- bras de liaison : longs, dans les colonnes x = 4 et x = 9 (lignes d'interface est des cellules 1 et 2), dans les lignes de la machine
local nlink, bad_link = 0, 0
for _, e in ipairs(gc.entities) do
  local sp = M.spec(e.name)
  if sp.kind == "inserter" and (e.dir == M.W or e.dir == M.E) then
    nlink = nlink + 1
    if not (e.name == long and (e.x == 4.5 or e.x == 9.5) and e.y >= 2.5 and e.y <= 4.5) then bad_link = bad_link + 1 end
  end
end
check(nlink == 5 and bad_link == 0, "5 bras de liaison longs dans les colonnes de liaison (3 pour C → K à gauche, 2 à droite), lignes de la machine (" .. nlink .. ", " .. bad_link .. " hors place)")
local planc = Bl.plan(line_of(gc, "assembler"), M.reserve(ASM2).target)
check(planc.evolutif and #planc.grow == 3, "Bl.plan : les 3 cellules de l'îlot grandissent vers 4×4 sans toucher tapis, bras de liaison ni poteaux")
-- moteurs et circuits rouges (2e tapis à bras longs, marge nord nulle) : réservés aussi
local gm, ga = M.get("moteurs"), M.get("circuits-rouges")
check(gm and gm.cell and gm.w == 14 and #M.check(gm) == 0 and Bl.plan(line_of(gm, "assembler"), M.reserve(ASM2).target).evolutif, "moteurs « P M G » : réservé, 14 de large, évolutif")
check(ga and ga.cell and ga.w == 14 and #M.check(ga) == 0 and Bl.plan(line_of(ga, "assembler"), M.reserve(ASM2).target).evolutif, "circuits rouges « A C A » (2e tapis) : réservé, 14 de large, évolutif")
-- le nombre demandé explicitement reste servi : 5 machines réservées = 24 + ports > lot → repris sans réservation = le gabarit d'avant, à
-- la géométrie près (la clé « -5m » et la note changent ; empreintes de géométrie relevées sur release-0.6.77 @ d5c3d840)
local g5m = M.GEN.circuits(ASM2, 2)
check(g5m and g5m.key == "circuits-verts-5m" and g5m.cell == nil and g5m.w == 19 and g5m.notes[1] ~= nil and g5m.notes[1]:find("emprise non réservée", 1, true) ~= nil, "circuits à 2 paires (demandées) : repris sans réservation, 19 de large, clé « -5m », noté : " .. tostring(g5m and g5m.notes[1]))
check(g5m and geo(g5m) == "edb3ed81", "… géométrie de l'ancien « circuits-verts » à l'octet (hors clé et note) : " .. tostring(g5m and geo(g5m)))
check(geo(M.GEN.engines(ASM2, 2)) == "41cb3081" and geo(M.GEN.advanced_circuits(ASM2, 2)) == "e08106aa", "moteurs et circuits rouges à 2 (demandés) : géométrie d'avant à l'octet")
check(geo(M.get("packs-verts")) == "1bf26e56" and geo(M.get("packs-rouges")) == "e5f84300", "packs (étage B trop large pour le lot réservé) : géométrie d'avant à l'octet, repris sans réservation")
-- îlots sans cible (assembleur 1, sans famille) : inchangés à l'octet, clés comprises
check(hash(M.GEN.circuits(ASM1, 1)) == "b4ab9531" and hash(M.GEN.circuits(ASM1)) == "701627a2" and hash(M.GEN.engines(ASM1)) == "11d43199" and hash(M.GEN.advanced_circuits(ASM1)) == "1eeb049b", "îlots à l'assembleur 1 (sans cible) : inchangés à l'octet")
-- variantes d'ère au niveau 7 (4×4, cible 13 = 5×5) : moteurs et circuits rouges, 3 machines en cellules de 5 : 17 de large, réservés ;
-- circuits : LIMITE PHYSIQUE, la liaison C → K (4,44 câbles/s au niveau 7) dépasse 4 bras longs dans les 4 lignes de la machine : repris
-- sans réservation (14 de large, pas de 5), noté
local m7, a7, g7 = M.get_any("moteurs-n7"), M.get_any("circuits-rouges-n7"), M.get_any("circuits-verts-n7")
check(m7 ~= nil and m7.cell ~= nil and m7.cell.w == 5 and m7.w == 17 and #M.check(m7) == 0, "moteurs au niveau 7 : cellules de 5, 17 de large, réservés")
check(a7 ~= nil and a7.cell ~= nil and a7.cell.w == 5 and a7.w == 17 and #M.check(a7) == 0, "circuits rouges au niveau 7 : cellules de 5, 17 de large, réservés")
check(g7 ~= nil and g7.cell == nil and g7.w == 14 and #M.check(g7) == 0 and g7.notes[1] ~= nil and g7.notes[1]:find("liaison 1 → 2 impossible", 1, true) ~= nil, "circuits au niveau 7 : liaison au-delà des bras longs, repris sans réservation (14 de large), noté : " .. tostring(g7 and g7.notes[1]))
-- bornes d'extension d'un îlot réservé : 1 paire (le lot, ports compris) ; M.extend refuse 2
check(gc.extensions[1].max == 1 and M.extend(gc, 2) == nil, "îlot réservé : extension bornée à 1 paire (ports compris), 2 refusé")
local g5 = M.GEN.gears(5, ASM2)
check(g5 and g5.cell == nil and g5.notes[1] ~= nil and g5.notes[1]:find("emprise non réservée", 1, true) ~= nil and g5.w == 19, "5 engrenages réservés = 24 + ports > lot : repris sans réservation (19 de large), noté : " .. tostring(g5 and g5.notes[1]))
local g4 = M.GEN.gears(4, ASM2)
check(g4 and g4.cell ~= nil and g4.w == 19, "4 engrenages réservés : 19 de large (+ 5 de ports = le lot), gardés")
check(#M.catalogue_errors() == 0, "catalogue sans refus (" .. table.concat(M.catalogue_errors(), " | ") .. ")")

---------------------------------------------------------------------------------------------------
section("§5 mutants de modules.lua")
---------------------------------------------------------------------------------------------------
local src
do local fh = assert(io.open("shared/team/modules.lua", "rb")) src = fh:read("*a") fh:close() end
local function load_mod(name, from, to)
  local s, n = src:gsub(from, function() return to end)
  check(n == 1, "mutant « " .. name .. " » : retouche appliquée une fois (" .. n .. ")")
  package.loaded["shared.team.modules"] = nil
  local Mm = assert(load(s, "=" .. name))()
  package.loaded["shared.team.modules"] = M
  return Mm
end
local function refused(name, Mm)
  local gm = Mm.GEN.smelter(STEEL, "iron-ore", 3)
  if not gm then return true end
  if #Mm.check(gm) > 0 then return true end
  -- gabarit réservé invalide : GEN rejoue sans réservation (gabarit d'avant, note « emprise non réservée ») : la réservation est PERDUE,
  -- vue par Bl.plan (plus évolutif) ; un mutant qui garde un gabarit réservé évolutif aurait survécu
  local p = Bl.plan(line_of(gm, "furnace"), M.reserve(STEEL).target)
  return not p.evolutif
end
-- marge ignorée : le four posé au centre de sa cellule (marge ouest) : les bras courts ne l'atteignent plus
local Mm = load_mod("machine décalée dans la cellule", "b:put%(furnace, x_f_w %+ rs%.west, y %+ rs%.north, N,", "b:put(furnace, x_f_w + rs.east, y + rs.north, N,")
check(refused("décalée", Mm), "mutant « four décalé dans sa cellule » refusé (bras dans le vide)")
-- bras court du côté de la marge
Mm = load_mod("bras court à l'est", "if margin > 0 then return M%.choose_inserters%(need, from_belt, sp%.h, M%.LONG_ARMS%) end", "")
check(refused("court", Mm), "mutant « bras court derrière la marge » refusé")
-- cellule = machine (réservation perdue) : gabarit d'avant, non évolutif
Mm = load_mod("cellule = machine", "local cell = Bl%.footprint%(now, target%)", "local cell = { w = now.w, h = now.h }")
local gm = Mm.GEN.smelter(STEEL, "iron-ore", 3)
check(gm and #Mm.check(gm) == 0 and not Bl.plan(line_of(gm, "furnace"), M.reserve(STEEL).target).evolutif, "mutant « cellule = machine » : gabarit valide mais plus évolutif (vu par Bl.plan)")

---------------------------------------------------------------------------------------------------
section("§6 lot ILOTS-COLONNES : règle Bl.link et mutants")
---------------------------------------------------------------------------------------------------
--- Détecteur de la règle Bl.link (partagé par la règle et ses mutants) : rend la liste des défauts.
local function link_faults(B)
  local bad = {}
  local l = B.link({ w = 4, h = 4 }, { w = 3, h = 3 })
  if not (l.x == 4 and l.to_west == 2 and l.to_east == 1 and l.reach == 2 and l.long and not l.impossible and l.rows == 3 and l.row0 == 0) then bad[#bad + 1] = "3 dans 4" end
  l = B.link({ w = 3, h = 3 }, { w = 3, h = 3 })
  if not (l.to_west == 1 and l.to_east == 1 and not l.long and not l.impossible) then bad[#bad + 1] = "sans marge : portée courte" end
  l = B.link({ w = 5, h = 5 }, { w = 3, h = 3 })
  if not (l.to_west == 2 and l.to_east == 2 and l.long and not l.impossible and l.row0 == 1) then bad[#bad + 1] = "3 dans 5 : long des deux côtés" end
  l = B.link({ w = 6, h = 6 }, { w = 3, h = 3 })
  if not (l.to_west == 3 and l.impossible) then bad[#bad + 1] = "3 dans 6 : hors de portée" end
  l = B.link({ w = 3, h = 3 }, { w = 2, h = 2 })
  if not (l.to_west == 2 and l.to_east == 1 and l.long and l.rows == 2) then bad[#bad + 1] = "four 2 dans 3" end
  return bad
end
check(#link_faults(Bl) == 0, "Bl.link : règle conforme (" .. table.concat(link_faults(Bl), " | ") .. ")")
local bsrc
do local fh = assert(io.open("shared/team/box_layout.lua", "rb")) bsrc = fh:read("*a") fh:close() end
local function load_bl(name, from, to)
  local s, n = bsrc:gsub(from, function() return to end)
  check(n == 1, "mutant « " .. name .. " » : retouche appliquée une fois (" .. n .. ")")
  return assert(load(s, "=" .. name))()
end
for _, m in ipairs({
  { "portée vers la machine lue à la marge ouest", 'local to_west = dim%(cell, "w"%) %- a%.x %- dim%(now, "w"%) %+ 1', "local to_west = a.x + 1" },
  { "bras long seulement au-delà de la portée longue", "long = reach >= Bl%.REACH_LONG,", "long = reach > Bl.REACH_LONG," },
  { "hors de portée dès la portée longue", "long = reach >= Bl%.REACH_LONG,\n    impossible = reach > Bl%.REACH_LONG,", "long = reach >= Bl.REACH_LONG,\n    impossible = reach >= Bl.REACH_LONG," },
}) do
  local Bm = load_bl(m[1], m[2], m[3])
  check(#link_faults(Bm) > 0, "mutant « " .. m[1] .. " » refusé (" .. tostring(link_faults(Bm)[1]) .. ")")
end
--- Détecteur des mutants de modules.lua : l'îlot de circuits par défaut est réservé (cellules de 4), valide, évolutif, et sa clé ne se
--- confond pas avec celle de l'îlot à 2 paires repris sans réservation. Rend (refusé, raison).
local function island_refused(Mm)
  local g = Mm.get("circuits-verts")
  if not g then return true, "aucun gabarit" end
  if not (g.cell and g.cell.w == 4) then return true, "réservation perdue (" .. tostring(g.notes[1]) .. ")" end
  if #Mm.check(g) > 0 then return true, Mm.check(g)[1] end
  if not Bl.plan(line_of(g, "assembler"), M.reserve(ASM2).target).evolutif then return true, "plus évolutif" end
  local g2 = Mm.GEN.circuits(ASM2, 2)
  if g2 and g2.key == g.key then return true, "collision de clés (" .. g.key .. ")" end
  return false
end
check(island_refused(M) == false, "règle : l'îlot par défaut passe le détecteur")
for _, m in ipairs({
  { "colonne de liaison dans la marge", "local gx = xs%[gap%] %+ g%.link%.x", "local gx = xs[gap] + g.link.x - 1" },
  { "bras court dans la colonne de liaison", "side_pick%(l%.flow %* M%.arm_f, false, g%.slots_n, g%.link%.reach %- 1%)", "side_pick(l.flow * M.arm_f, false, g.slots_n, 0)" },
  { "lot sans les ports", "local function lot_width%(sp, s%) return %(s > sp%.w%) and %(M%.MAX_SIDE %- M%.PORT_ROOM%) or M%.MAX_SIDE end", "local function lot_width(sp, s) return M.MAX_SIDE end" },
  { "côté cible lu dans le contexte", "M%.reserving = true\n  local r = M%.reserve%(name%)", "local r = M.reserve(name)" },
}) do
  local Mm = load_mod(m[1], m[2], m[3])
  local r, why = island_refused(Mm)
  check(r == true, "mutant « " .. m[1] .. " » refusé (" .. tostring(why) .. ")")
end

print(string.format("\n[GABARITS-RESERVES] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
