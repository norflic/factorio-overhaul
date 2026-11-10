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
    §4 limites physiques : îlot à liaisons par colonne (circuits) et gabarit réservé trop grand pour le lot (ports compris) : le gabarit
       d'avant, raison dans g.notes ; les bornes d'extension sont celles d'avant ;
    §5 mutants de modules.lua : marge ignorée (machine au centre), bras court à l'est, cellule = machine : refusés par M.check ou par Bl.plan.
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
section("§4 limites physiques : gabarit d'avant gardé et noté")
---------------------------------------------------------------------------------------------------
local gc = M.get("circuits-verts")
check(gc and gc.cell == nil and gc.notes[1] ~= nil and gc.notes[1]:find("liaisons par colonne", 1, true) ~= nil, "îlot de circuits (liaisons par colonne) : non réservé, noté : " .. tostring(gc and gc.notes[1]))
check(gc and gc.w == 19, "îlot de circuits : 19 de large comme avant")
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

print(string.format("\n[GABARITS-RESERVES] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
