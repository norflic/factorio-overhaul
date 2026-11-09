--[[
  Lot MALL, tranche 2 : contrôle hors jeu de la décision du runtime de la rangée du mall (script/team/mall_rangee.lua) sur des doublures : ouverture (état S), première rangée
  et ses voies, rangée qui accepte, matériel refusé (rien n'est retenu), section refusée (cellules rendues, arrêt), allongement à la minute, plan de site (obstacles, réserve du
  secteur rendue), compteurs, coût mesuré par debug.sethook.
  Usage : lua5.2 tests/mall_rangee_moteur_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, ko_n = 0, 0
local function check(cond, what)
  if cond then ok_n = ok_n + 1 else ko_n = ko_n + 1; print("ECHEC : " .. what) end
end

local LOG = {}
_G.log = function(s) LOG[#LOG + 1] = s end
_G.remote = { add_interface = function() end }
_G.defines = { inventory = { chest = 1 }, entity_status = { working = 1, low_power = 2 } }
local PROTOS = {}
_G.game = { tick = 0, entity_prototypes = PROTOS, item_prototypes = setmetatable({}, { __index = function() return { stack_size = 50 } end }) }

local RELEASED = {}
local REQ = {}
local Build = { SITES = {}, QUAI_CHEST = "iron-chest", Mall = { OCC = -1, on = function() return true end } }
function Build.request(f, spec)
  local id = f.build.next_id
  f.build.next_id = id + 1
  f.build.projects[id] = { id = id, spec = spec, state = "attente", ents = {}, outs = {}, quais = {} }
  REQ[#REQ + 1] = spec
  return id
end
package.loaded["script.team.build"] = Build
package.loaded["script.team.champ"] = { _raccord_tous = function() return 0 end }
package.loaded["script.team.stock"] = {}
package.loaded["script.faction.state"] = { faction = function() return nil end, alive = function() return {} end }
package.loaded["script.core.events"] = { on_load = function() end }
package.loaded["shared.ai3.automatiser"] = { declare = function() end }

local P = require("shared.team.plan")
local Mr = require("shared.team.mall_rangee")
local Rt = require("script.team.mall_rangee")

local NAMES = { machine = "assembling-machine-1", bras = "inserter", bras_long = "long-handed-inserter", tapis = "transport-belt", poteau = "small-electric-pole", coffre = "iron-chest" }
local M = require("shared.team.modules")
M.BASE["assembling-machine-1"] = M.BASE["assembling-machine-1"] or { kind = "assembler", w = 3, h = 3, speed = 0.5 }

local SECT = { x0 = 16, y0 = -48, x1 = 80, y1 = 16, dir = 2, ext = 16 }

local function team(opts)
  opts = opts or {}
  return { key = "t", force = "player", build = { next_id = 1, projects = {}, occ = {}, order = {}, mall = { v = 1, phase = "choisi", logs = 0, sect = SECT, pret = opts.pret ~= false } } }
end

local function dem(item, machines, solides, rate)
  return { item = item, recipe = "r-" .. item, machine = NAMES.machine, machines = machines, solides = solides, rate = rate or 30 }
end

---------------------------------------------------------------------------------------------------
-- §1 ouverture
---------------------------------------------------------------------------------------------------
do
  local f = team({ pret = false })
  f.build.mall.pret = nil
  check(Rt.ouvert(f) == false, "§1 état S faux : fermé")
  f.build.mall.pret = true
  check(Rt.ouvert(f) == true, "§1 état S vrai et secteur : ouvert")
  f.build.mall.sect = nil
  check(Rt.ouvert(f) == false, "§1 pas de secteur : fermé")
  f.build.mall.sect = SECT
  f.build.mall.pret = nil
  f.build.mall.force_pret = true
  check(Rt.ouvert(f) == true, "§1 forcé par un banc : ouvert")
end

---------------------------------------------------------------------------------------------------
-- §2 première rangée, voies, rangée qui accepte
---------------------------------------------------------------------------------------------------
local AFFORD = true
local function afford(list)
  if AFFORD then return true end
  return false, "stock hors besoin insuffisant"
end

do
  local f = team()
  REQ = {}
  local id = Rt.place(f, { dem("belt", 2, { "fer", "gear" }), dem("chest", 2, { "fer" }) }, NAMES, 100, afford, "test")
  check(id ~= nil, "§2 premier placement accepté")
  local st = f.build.mall
  check(#st.rows == 1 and st.rows[1].j == 1, "§2 rangée 1 ouverte")
  check(table.concat(st.rows[1].voies, ",") == "fer,gear", "§2 voies triées par usages")
  check(#st.rows[1].cells == 2, "§2 deux cellules (4 machines)")
  check(REQ[1] and REQ[1].site == "mall" and REQ[1].mall.head == true and REQ[1].mall.from == 1, "§2 projet de site avec la tête")
  check(f.build.projects[id].keep_stock and f.build.projects[id].keep_stock.belt ~= nil, "§2 cible de stock posée (keep_stock)")
  local sv = Rt.served(f)
  check(sv.belt == true and sv.chest == true, "§2 objets servis (Rt.served)")
  -- objet compatible : même rangée, nouvelle section sans tête
  local id2 = Rt.place(f, { dem("pipe", 1, { "fer" }) }, NAMES, 200, afford, "test")
  check(id2 ~= nil and #st.rows == 1, "§2 même rangée quand les voies l'acceptent")
  check(REQ[2].mall.head == false and REQ[2].mall.from == 3, "§2 section suivante, sans tête, à la suite")
  -- objet incompatible : rangée neuve
  local id3 = Rt.place(f, { dem("cable", 2, { "cuivre" }) }, NAMES, 300, afford, "test")
  check(id3 ~= nil and #st.rows == 2 and st.rows[2].j == 2, "§2 rangée neuve pour d'autres voies")
  -- un objet qui est une voie de la rangée 1 n'y entre pas : il ouvre une rangée
  local id4 = Rt.place(f, { dem("gear", 1, { "fer" }) }, NAMES, 400, afford, "test")
  check(id4 ~= nil and #st.rows == 3 and table.concat(st.rows[3].voies, ",") == "fer", "§2 objet-voie de la rangée 1 : rangée neuve (" .. #st.rows .. ")")
  check(Mr.compte(st.rows[1], "r-gear") == 0, "§2 l'objet-voie n'entre pas dans la rangée 1")
end

---------------------------------------------------------------------------------------------------
-- §3 matériel refusé : rien n'est retenu
---------------------------------------------------------------------------------------------------
do
  local f = team()
  AFFORD = false
  local id, why, wait = Rt.place(f, { dem("belt", 2, { "fer", "gear" }) }, NAMES, 100, afford, "test")
  AFFORD = true
  check(id == nil and wait == true and why ~= nil, "§3 matériel insuffisant : attente")
  local st = f.build.mall
  check(#st.rows == 0, "§3 aucune rangée créée (" .. #st.rows .. ")")
  check(next(Rt.served(f)) == nil, "§3 rien de servi")
end

---------------------------------------------------------------------------------------------------
-- §4 capacité, mall plein
---------------------------------------------------------------------------------------------------
do
  local f = team()
  local rows_max = Mr.capacite(SECT)
  for i = 1, rows_max do
    check(Rt.place(f, { dem("x" .. i, 1, { "e" .. i }) }, NAMES, 10, afford, "t") ~= nil, "§4 rangée " .. i)
  end
  local id, why = Rt.place(f, { dem("y", 1, { "autre" }) }, NAMES, 10, afford, "t")
  check(id == nil and tostring(why):find("mall plein", 1, true) ~= nil, "§4 mall plein (" .. tostring(why) .. ")")
end

---------------------------------------------------------------------------------------------------
-- §5 plan de site : obstacles, réserve rendue
---------------------------------------------------------------------------------------------------
local function mock_masks(water, blocked)
  return function() return { water = water or {}, blocked = blocked or {}, clear = {} } end
end

do
  local f = team()
  local id = Rt.place(f, { dem("belt", 2, { "fer", "gear" }) }, NAMES, 100, afford, "t")
  local p = f.build.projects[id]
  local st = f.build.mall
  -- réserve du secteur sous la section
  for y = SECT.y0, SECT.y1 - 1 do for x = SECT.x0, SECT.x1 - 1 do f.build.occ[P.tkey(x, y)] = -1 end end
  local sec = Mr.section(P, (function()
    local Cat = require("shared.team.motifs.catalogue")
    return assert(Mr.modele(Cat.instancier(Mr.MOTIF, 1, { rot = 0, miroir = false }).pieces))
  end)(), st.rows[1], 1, 1, NAMES, st.rep, true)
  check(st.rep ~= nil and st.rep.k == 0, "§5 repère du secteur")
  -- eau sous la première pièce
  local t0 = P.tiles_of(sec.ents[1])[1]
  local lay, why = Build.SITES.mall(f, nil, p, { read_masks = mock_masks({ [P.tkey(t0[1], t0[2])] = true }) })
  check(lay == nil and tostring(why):find("obstacle:eau", 1, true) ~= nil, "§5 eau : refus avec cause (" .. tostring(why) .. ")")
  check(f.build.occ[P.tkey(t0[1], t0[2])] == -1, "§5 un refus laisse la réserve en place")
  -- bâtiment
  local lay2, why2 = Build.SITES.mall(f, nil, p, { read_masks = mock_masks(nil, { [P.tkey(t0[1], t0[2])] = true }) })
  check(lay2 == nil and tostring(why2):find("obstacle:batiment", 1, true) ~= nil, "§5 bâtiment : refus avec cause")
  -- tuile d'un autre projet
  f.build.occ[P.tkey(t0[1], t0[2])] = 77
  local lay3, why3 = Build.SITES.mall(f, nil, p, { read_masks = mock_masks() })
  check(lay3 == nil and tostring(why3):find("obstacle:reserve", 1, true) ~= nil, "§5 tuile d'un autre projet : refus")
  f.build.occ[P.tkey(t0[1], t0[2])] = -1
  -- raccord sauté si pas de site ; plan accepté
  st.sans_raccord = true
  local lay4 = Build.SITES.mall(f, nil, p, { read_masks = mock_masks() })
  check(lay4 ~= nil and #lay4.ents > 0 and #lay4.outs == 2 * #st.rows[1].cells and #lay4.quais == 2, "§5 plan accepté (pièces, sorties, quais)")
  check(f.build.occ[P.tkey(t0[1], t0[2])] == nil, "§5 les tuiles du plan quittent la réserve du secteur")
  check(f.build.occ[P.tkey(SECT.x1 - 1, SECT.y1 - 1)] == -1, "§5 le reste du secteur reste réservé")
end

---------------------------------------------------------------------------------------------------
-- §6 la minute : section refusée, allongement, compteurs
---------------------------------------------------------------------------------------------------
local function surface_mock(machines, chests)
  return { find_entity = function(name, pos)
    local k = name .. pos[1] .. ":" .. pos[2]
    if machines[k] then return machines[k] end
    if name == "iron-chest" then return chests[k] or nil end
    return nil
  end }
end

do
  local f = team()
  local id = Rt.place(f, { dem("belt", 2, { "fer", "gear" }) }, NAMES, 100, afford, "t")
  local st = f.build.mall
  local p = f.build.projects[id]
  local r = st.rows[1]
  -- la section refusée rend ses cellules et arrête la rangée (obstacle)
  local id2 = Rt.place(f, { dem("belt", 4, { "fer", "gear" }) }, NAMES, 200, afford, "t")
  check(id2 ~= nil and #r.cells == 2, "§6 deuxième section (2 machines de plus, 1 cellule)")
  local p2 = f.build.projects[id2]
  p2.state = "refuse"; p2.reason = "obstacle:eau en (1, 2)"
  Rt.minute(f, surface_mock({}, {}), { fab = {} }, {}, afford, 300)
  check(#r.cells == 1 and r.stop ~= nil and tostring(r.stop):find("eau", 1, true) ~= nil, "§6 section refusée : cellules rendues et cause d'arrêt (" .. #r.cells .. ", " .. tostring(r.stop) .. ")")
  -- compteurs : machines réelles lues
  p.state = "fini"
  p.ents = {
    { role = "mall-machine_asm", name = "assembling-machine-1", x = 1.5, y = 3.5 },
    { role = "mall-machine_asm", name = "assembling-machine-1", x = 1.5, y = 10.5 },
    { role = "mall-sortie", name = "iron-chest", x = 2.5, y = 0.5 },
  }
  p.outs = { { x = 2.5, y = 0.5, item = "belt" } }
  local inv = { supports_bar = function() return true end, get_item_count = function() return 17 end }
  inv.set_bar = function(n) inv.bar = n end
  local chest = { get_inventory = function() return inv end }
  local m1 = { force = { name = "player" }, products_finished = 40, status = defines.entity_status.working }
  local m2 = { force = { name = "player" }, products_finished = 2, status = 99 }
  local surf = surface_mock({ ["assembling-machine-11.5:3.5"] = m1, ["assembling-machine-11.5:10.5"] = m2 }, { ["iron-chest2.5:0.5"] = chest })
  r.stop = nil
  Rt.minute(f, surf, { fab = {} }, {}, afford, 3700)
  check(st.fab.made == 42 and st.fab.machines == 2 and st.fab.run == 1 and st.fab.chests == 17, "§6 compteurs lus (" .. tostring(st.fab.made) .. ")")
  check(p.mall_barre == true and inv.bar ~= nil, "§6 barre posée sur les coffres de sortie")
  m1.products_finished = 90
  Rt.minute(f, surf, { fab = {} }, {}, afford, 7300)
  local got
  for _, l in ipairs(LOG) do if l:find("PRODUCTION", 1, true) and l:find("+50", 1, true) then got = true end end
  check(got, "§6 ligne PRODUCTION : delta depuis la dernière minute")
end

---------------------------------------------------------------------------------------------------
-- §7 allongement à la minute (demande en hausse)
---------------------------------------------------------------------------------------------------
do
  local f = team()
  local id = Rt.place(f, { dem("belt", 2, { "fer", "gear" }) }, NAMES, 100, afford, "t")
  local st = f.build.mall
  st.names_kit = NAMES
  local p = f.build.projects[id]
  p.state = "fini"
  local fab = { ["r-belt"] = { solides = { { name = "fer" }, { name = "gear" } }, machines = { { entity = NAMES.machine, par_min = 30 } } } }
  REQ = {}
  Rt.minute(f, surface_mock({}, {}), { fab = fab }, { { item = "belt", rate = 300 } }, afford, 3700)
  local r = st.rows[1]
  check(#REQ == 1 and REQ[1].mall.from == 2 and #r.cells >= 2, "§7 demande en hausse : allongement (" .. #REQ .. ", " .. #r.cells .. ")")
  -- une section en cours : pas de seconde demande
  local cnt = #REQ
  Rt.minute(f, surface_mock({}, {}), { fab = fab }, { { item = "belt", rate = 300 } }, afford, 7300)
  check(#REQ == cnt, "§7 une seule demande tant que la section n'est pas finie")
  -- demande satisfaite : rien
  for _, q in ipairs(r.projects) do f.build.projects[q.id].state = "fini" end
  local cnt2 = #REQ
  Rt.minute(f, surface_mock({}, {}), { fab = fab }, { { item = "belt", rate = 10 } }, afford, 10900)
  check(#REQ == cnt2, "§7 demande satisfaite : aucune section")
end

---------------------------------------------------------------------------------------------------
-- §8 coût au pire cas (debug.sethook)
---------------------------------------------------------------------------------------------------
do
  local f = team()
  local st = f.build.mall
  st.rows = {}
  st.names_kit = NAMES
  st.rep = { ox = 0, oy = 0, k = 0 }
  local ents = {}
  for _ = 1, 80 do ents[#ents + 1] = { role = "mall-machine_asm", name = "assembling-machine-1", x = 1.5, y = 3.5 } end
  for _ = 1, 80 do ents[#ents + 1] = { role = "mall-sortie", name = "iron-chest", x = 2.5, y = 0.5 } end
  for j = 1, 4 do
    local cells = {}
    for i = 1, 40 do cells[i] = { h = "r", b = "r", ih = "it", ib = "it", m = NAMES.machine } end
    local id = f.build.next_id
    f.build.next_id = id + 1
    f.build.projects[id] = { id = id, state = "fini", ents = ents, outs = {}, mall_barre = true }
    st.rows[j] = { j = j, voies = { "fer" }, cells = cells, projects = { { id = id, from = 1, to = 40 } }, made0 = 1 }
  end
  local m = { force = { name = "player" }, products_finished = 2, status = 1 }
  local inv = { get_item_count = function() return 1 end }
  local ch = { get_inventory = function() return inv end }
  local surf = { find_entity = function(name) if name == "iron-chest" then return ch end return m end }
  local count = 0
  debug.sethook(function() count = count + 100 end, "", 100)
  Rt.minute(f, surf, { fab = {} }, {}, afford, 100)
  debug.sethook()
  print("[MALL-RANGEE-MOTEUR] minute, 4 rangées de 320 machines et coffres : " .. count .. " instructions")
  check(count <= 370000, "§8 coût de la minute ≤ 370 k instructions (" .. count .. ")")
end

print(string.format("[MALL-RANGEE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", ok_n, ko_n))
os.exit(ko_n == 0 and 0 or 1)
