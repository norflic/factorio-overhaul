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
_G.defines = { inventory = { chest = 1 }, entity_status = { working = 1, low_power = 2, no_ingredients = 3 } }
local PROTOS = {}
_G.game = { tick = 0, entity_prototypes = PROTOS, item_prototypes = setmetatable({}, { __index = function() return { stack_size = 50 } end }) }

local RELEASED = {}
local REQ = {}
local PUR = { ok = true, why = nil, calls = 0 }
local Build = { SITES = {}, QUAI_CHEST = "iron-chest", Mall = { OCC = -1, on = function() return true end },
  Pur = { check_route = function() PUR.calls = PUR.calls + 1; return PUR.ok, PUR.why end } }
function Build.request(f, spec)
  local id = f.build.next_id
  f.build.next_id = id + 1
  f.build.projects[id] = { id = id, spec = spec, state = "attente", ents = {}, outs = {}, quais = {} }
  REQ[#REQ + 1] = spec
  return id
end
package.loaded["script.team.build"] = Build
package.loaded["script.team.champ"] = { _raccord_tous = function() return 0 end }
package.loaded["script.faction.state"] = { faction = function() return nil end, alive = function() return {} end }
package.loaded["script.core.events"] = { on_load = function() end }
local LEC = { fab = {} }
package.loaded["shared.ai3.automatiser"] = { declare = function() end, lecture = function() return LEC end,
  patron_kit = function() return { bras = "inserter", bras_long = "long-handed-inserter", tapis = "transport-belt", coffre = "iron-chest", poteau = "small-electric-pole", decl = { kit = {}, machines = {} } } end }

local P = require("shared.team.plan")
local Mr = require("shared.team.mall_rangee")
local Rt = require("script.team.mall_rangee")

local NAMES = { machine = "assembling-machine-1", bras = "inserter", bras_long = "long-handed-inserter", tapis = "transport-belt", poteau = "small-electric-pole", coffre = "iron-chest" }
local M = require("shared.team.modules")
M.BASE["assembling-machine-1"] = M.BASE["assembling-machine-1"] or { kind = "assembler", w = 3, h = 3, speed = 0.5 }
M.BASE["slow-asm"] = { kind = "assembler", w = 3, h = 3, speed = 0.5 }

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
  -- pureté : refus du tracé
  st.sans_raccord = true
  PUR.ok, PUR.why = false, "pointe_vers_etranger"
  local lay5, why5 = Build.SITES.mall(f, {}, p, { read_masks = mock_masks() })
  check(lay5 == nil and tostring(why5):find("purete", 1, true) ~= nil and PUR.calls >= 1, "§5 pureté : refus avec cause (" .. tostring(why5) .. ")")
  PUR.ok, PUR.why = true, nil
  PUR.calls = 0
  local lay6 = Build.SITES.mall(f, {}, p, { read_masks = mock_masks() })
  check(lay6 ~= nil and PUR.calls == 2, "§5 pureté : les deux tapis contrôlés (" .. PUR.calls .. ")")
  f.build.occ[P.tkey(t0[1], t0[2])] = -1
  -- raccord sauté si pas de site ; plan accepté
  st.sans_raccord = true
  local lay4 = Build.SITES.mall(f, nil, p, { read_masks = mock_masks() })
  check(lay4 ~= nil and #lay4.ents > 0 and #lay4.outs == 2 * #st.rows[1].cells and #lay4.quais == 2 * Mr.ARMS, "§5 plan accepté (pièces, sorties, quais)")
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
  check(st.fab.made == 92, "§6 cumul des objets fabriqués (" .. tostring(st.fab.made) .. ")")
  -- une machine détruite : la somme des compteurs baisse, le cumul reste
  p.ents[1] = { role = "mall-machine_asm", name = "assembling-machine-1", x = 99.5, y = 99.5 }
  Rt.minute(f, surf, { fab = {} }, {}, afford, 10900)
  check(st.fab.made == 92 and st.fab.machines == 1, "§6 machine détruite : le cumul ne redescend pas (" .. tostring(st.fab.made) .. ", " .. tostring(st.fab.machines) .. ")")
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

---------------------------------------------------------------------------------------------------
-- §7w intermédiaires d'abord : engrenage avant tapis, câble avant circuit avant inserteur
---------------------------------------------------------------------------------------------------
do
  game.entity_prototypes.asm = { type = "assembling-machine" }
  game.entity_prototypes.four = { type = "furnace" }
  local M = { { item = "asm", entity = "asm", par_min = 30 } }
  local function rec(prod, sol) return { solides = sol, produits = { prod }, patronnable = true, category = "crafting", machines = M, fluides_in = {} } end
  local lec = { fab = {
    belt = rec("belt", { { name = "gear", amount = 1 }, { name = "iron-plate", amount = 1 } }),
    gear = rec("gear", { { name = "iron-plate", amount = 2 } }),
    cable = rec("cable", { { name = "copper-plate", amount = 1 } }),
    circ = rec("circ", { { name = "cable", amount = 3 }, { name = "iron-plate", amount = 1 } }),
    bras = rec("bras", { { name = "circ", amount = 1 }, { name = "gear", amount = 1 }, { name = "iron-plate", amount = 1 } }),
    fluide = { solides = { { name = "iron-plate", amount = 1 } }, produits = { "fluide" }, patronnable = true, category = "crafting", machines = M, fluides_in = { { name = "eau" } } },
    tuyau = rec("tuyau", { { name = "fluide", amount = 1 } }),
    acier = { solides = { { name = "iron-plate", amount = 5 } }, produits = { "acier" }, patronnable = true, category = "smelting", machines = { { item = "four", entity = "four", par_min = 12 } }, fluides_in = {} },
    moteur = rec("moteur", { { name = "acier", amount = 1 }, { name = "iron-plate", amount = 1 } }),
  } }
  local kit = { decl = { kit = {} }, bras = NAMES.bras, bras_long = NAMES.bras_long, tapis = NAMES.tapis, poteau = NAMES.poteau, coffre = NAMES.coffre }
  local mod = { args = { 0, 0, kit } }
  local function bloc(item) return { kind = "bloc", items = { item }, dec = { recipes = { [item] = item }, rates = { [item] = 30 } } } end
  local function oui() return true end
  local f = team()
  local st = f.build.mall
  check(Rt.accueille(f, bloc("belt"), mod, lec, 10, afford, oui) == true, "§7w tapis : pris")
  check(Rt.served(f).gear == true and Rt.served(f).belt == nil, "§7w d'abord l'engrenage, pas le tapis")
  check(#st.rows == 1 and table.concat(st.rows[1].voies, ",") == "iron-plate", "§7w rangée de plaques seulement (" .. table.concat(st.rows[1].voies, ",") .. ")")
  check(Mr.compte(st.rows[1], "gear") == 2, "§7w machines d'après le débit réel : 30/min x 1 x 2 / 30 = 2 (" .. Mr.compte(st.rows[1], "gear") .. ")")
  check(Rt.accueille(f, bloc("belt"), mod, lec, 20, afford, oui) == true and Rt.served(f).belt == true, "§7w puis le tapis")
  local f2 = team()
  check(Rt.accueille(f2, bloc("bras"), mod, lec, 10, afford, oui) == true and Rt.served(f2).cable == true and Rt.served(f2).circ == nil and Rt.served(f2).bras == nil, "§7w le plus profond d'abord : le câble")
  check(Rt.accueille(f2, bloc("bras"), mod, lec, 20, afford, oui) == true and Rt.served(f2).circ == true and Rt.served(f2).bras == nil, "§7w puis le circuit")
  check(Rt.accueille(f2, bloc("bras"), mod, lec, 30, afford, oui) == true and Rt.served(f2).gear == true and Rt.served(f2).bras == nil, "§7w puis l'engrenage")
  check(Rt.accueille(f2, bloc("bras"), mod, lec, 40, afford, oui) == true and Rt.served(f2).bras == true, "§7w enfin l'inserteur")
  -- une entrée que le patron ne sait pas faire (fluide) : pas d'intermédiaire, la recette passe comme avant
  local f3 = team()
  local ok3 = Rt.accueille(f3, bloc("tuyau"), mod, lec, 10, afford, oui)
  check(ok3 == true and Rt.served(f3).tuyau == true and Rt.served(f3).fluide == nil, "§7w intermédiaire à fluide : recette gardée (" .. tostring(ok3) .. ")")
  -- une recette de four n'est pas un intermédiaire : la recette demandée passe, l'acier reste une entrée
  local f5 = team()
  local ok5 = Rt.accueille(f5, bloc("moteur"), mod, lec, 10, afford, oui)
  check(ok5 == true and Rt.served(f5).moteur == true and Rt.served(f5).acier == nil, "§7w recette de four : pas de rangée d'intermédiaire (" .. tostring(ok5) .. ")")
  -- matériel refusé : on attend, sans poser la recette demandée
  local f4 = team()
  local ok4, why4, wait4 = Rt.accueille(f4, bloc("belt"), mod, lec, 10, function() return false, "rien" end, oui)
  check(ok4 == false and wait4 == true and #f4.build.mall.rows == 0, "§7w matériel refusé : attente (" .. tostring(why4) .. ")")
end

---------------------------------------------------------------------------------------------------
-- §7x tapis et bras d'abord ; famille des chantiers dans la pile
---------------------------------------------------------------------------------------------------
do
  local old_items = game.item_prototypes
  game.item_prototypes = {
    tapis = { place_result = { type = "transport-belt" } }, bras = { place_result = { type = "inserter" } },
    gear = { }, mur = { place_result = { type = "wall" } },
  }
  local a, b, c, d = { items = { "gear" } }, { items = { "gear", "bras" } }, { items = { "mur" } }, { items = { "tapis" } }
  local o = Rt.ordonne({ a, b, c, d })
  check(o[1] == b and o[2] == d and o[3] == a and o[4] == c, "§7x tapis et bras devant, ordre relatif gardé")
  check(#Rt.ordonne({}) == 0, "§7x liste vide")
  game.item_prototypes = old_items

  local f = team()
  local id = Rt.place(f, { dem("belt", 2, { "fer", "gear" }) }, NAMES, 100, afford, "t")
  local p = f.build.projects[id]
  p.state = "chantier"
  local old_brief = Build.brief
  Build.brief = function() return { state = "chantier", missing = {} } end
  local mods = {}
  Rt.contexte(f, mods, {}, {}, nil, 200)
  check(#mods == 1 and mods[1].pile == "capi", "§7x famille par défaut : capi (" .. tostring(mods[1] and mods[1].pile) .. ")")
  Build.Mall.preparer_on = function() return true end
  mods = {}
  Rt.contexte(f, mods, {}, {}, nil, 200)
  check(#mods == 1 and mods[1].pile == "preparer", "§7x réglage allumé : preparer (" .. tostring(mods[1] and mods[1].pile) .. ")")
  Build.Mall.preparer_on = nil
  Build.brief = old_brief
end

---------------------------------------------------------------------------------------------------
-- §7y raccord : la chaîne peut passer sur les tuiles que les rangées n'utilisent jamais
---------------------------------------------------------------------------------------------------
do
  local f = team()
  local id = Rt.place(f, { dem("belt", 2, { "fer", "gear" }) }, NAMES, 100, afford, "t")
  local st = f.build.mall
  local p = f.build.projects[id]
  local CAPT
  local champ = package.loaded["script.team.champ"]
  local old = champ._raccord_tous
  champ._raccord_tous = function(_, _, bd) CAPT = bd; return 0 end
  Build.Mall.OCC = Build.Mall.OCC or -1
  st.sans_raccord = nil
  local lay = Build.SITES.mall(f, {}, p, { read_masks = function() return { water = {}, blocked = {}, clear = {} } end })
  champ._raccord_tous = old
  check(lay ~= nil and CAPT ~= nil and CAPT.occ_libre ~= nil, "§7y le raccord reçoit la règle des tuiles libres")
  if CAPT and CAPT.occ_libre then
    local r = st.rep
    local function monde(cx, cy)
      local x, y = Mr.to_world(cx + 0.5, cy + 0.5, 0, r.k, r.ox, r.oy, 1)
      return math.floor(x), math.floor(y)
    end
    local px, py = monde(10, 14)
    local qx, qy = monde(10, 5)
    check(CAPT.occ_libre(px, py, Build.Mall.OCC) == true, "§7y passage entre rangées : ouvert à la chaîne")
    check(CAPT.occ_libre(qx, qy, Build.Mall.OCC) == false, "§7y tuile de rangée : fermée")
    check(CAPT.occ_libre(px, py, 12) == false, "§7y tuile d'un autre projet : fermée")
  end
  -- rangée 2 : sa précédente vit, le poteau relais suffit ; sa précédente refusée, elle cherche le réseau
  local id2 = Rt.place(f, { dem("x", 2, { "a", "b", "c" }) }, NAMES, 200, afford, "t")
  check(id2 ~= nil and #st.rows == 2, "§7y deuxième rangée ouverte")
  local p2 = f.build.projects[id2]
  local n_raccord = 0
  champ._raccord_tous = function() n_raccord = n_raccord + 1; return 0 end
  local masks = function() return { water = {}, blocked = {}, clear = {} } end
  local lay2 = Build.SITES.mall(f, {}, p2, { read_masks = masks })
  check(lay2 ~= nil and n_raccord == 0, "§7y rangée 1 vivante : pas de raccord pour la rangée 2 (" .. n_raccord .. ")")
  f.build.projects[id].state = "refuse"
  lay2 = Build.SITES.mall(f, {}, p2, { read_masks = masks })
  check(lay2 ~= nil and n_raccord == 1, "§7y rangée 1 refusée : la rangée 2 cherche le réseau (" .. n_raccord .. ")")
  champ._raccord_tous = old
end

---------------------------------------------------------------------------------------------------
-- §7z rangée à l'arrêt : le journal dit pourquoi
---------------------------------------------------------------------------------------------------
do
  local f = team()
  local id = Rt.place(f, { dem("belt", 2, { "fer", "gear" }) }, NAMES, 100, afford, "t")
  local p = f.build.projects[id]
  p.state = "fini"
  p.quais = { { x = 0.5, y = 0.5, item = "fer" }, { x = 1.5, y = 0.5, item = "gear" } }
  p.ents = { { role = "mall-machine_asm", name = "assembling-machine-1", x = 1.5, y = 3.5 }, { role = "mall-machine_asm", name = "assembling-machine-1", x = 1.5, y = 10.5 } }
  local vide = { get_item_count = function() return 0 end }
  local plein = { get_item_count = function() return 5 end }
  local cv = { get_inventory = function() return vide end }
  local cp = { get_inventory = function() return plein end }
  local mk = function() return { force = { name = "player" }, products_finished = 0, status = defines.entity_status.no_ingredients } end
  local surf = surface_mock({ ["assembling-machine-11.5:3.5"] = mk(), ["assembling-machine-11.5:10.5"] = mk() }, { ["iron-chest0.5:0.5"] = cv, ["iron-chest1.5:0.5"] = cp })
  local machines_ok = false
  for _, e in ipairs(p.ents) do if e.role == "mall-machine_asm" then machines_ok = true end end
  check(machines_ok, "§7z le projet a des machines")
  LOG = {}
  Rt.minute(f, surf, { fab = {} }, {}, afford, 4000)
  local n_arret, ligne = 0, nil
  for _, l in ipairs(LOG) do if l:find("ARRET rangee", 1, true) then n_arret = n_arret + 1; ligne = l end end
  check(n_arret == 1 and ligne:find("no_ingredients=", 1, true) ~= nil and ligne:find("quais vides 1 sur 2 {fer}", 1, true) ~= nil, "§7z ligne ARRET : états et quais vides (" .. tostring(ligne) .. ")")
  LOG = {}
  Rt.minute(f, surf, { fab = {} }, {}, afford, 4000 + 3600)
  local again = false
  for _, l in ipairs(LOG) do if l:find("ARRET rangee", 1, true) then again = true end end
  check(not again, "§7z au plus une ligne par 5 min")
end

---------------------------------------------------------------------------------------------------
-- §8b S2 partiel, reprise après un refus de raccord
---------------------------------------------------------------------------------------------------
do
  local f = team()
  local st = f.build.mall
  st.pret = nil
  st.partiel = { ok = { fer = true }, all = { fer = true, cuivre = true } }
  check(Rt.ouvert(f) == true, "§8b S2 partiel : ouvert")
  local _, why = Rt.place(f, { dem("cable", 1, { "cuivre" }) }, NAMES, 10, afford, "t")
  check(tostring(why):find("S2 partiel", 1, true) ~= nil, "§8b objet d'une plaque qui ne coule pas : refusé (" .. tostring(why) .. ")")
  local id = Rt.place(f, { dem("gear", 1, { "fer" }), dem("cable", 1, { "cuivre" }) }, NAMES, 10, afford, "t")
  check(id ~= nil and #st.rows == 1 and Mr.compte(st.rows[1], "r-gear") >= 1 and Mr.compte(st.rows[1], "r-cable") == 0, "§8b seul l'objet dont la plaque coule entre")
  local p = f.build.projects[id]
  p.state, p.reason = "refuse", "mall raccord : 1 composante(s)"
  Rt.minute(f, surface_mock({}, {}), { fab = {} }, {}, afford, 100)
  local r = st.rows[1]
  check(#r.cells == 0 and r.stop == nil and r.retry_at == 100 + Rt.RETRY_TICKS, "§8b refus de raccord : cellules rendues, nouvel essai plus tard (" .. tostring(r.retry_at) .. ")")
  local n0 = #st.rows
  local id2 = Rt.place(f, { dem("gear", 1, { "fer" }) }, NAMES, 200, afford, "t")
  check(id2 ~= nil and #st.rows == n0 + 1, "§8b pendant le délai, la rangée en attente n'est pas reprise")
  local r2 = st.rows[2]
  r2.stop = "obstacle:test"
  local id3 = Rt.place(f, { dem("gear", 2, { "fer" }) }, NAMES, 100 + Rt.RETRY_TICKS + 1, afford, "t")
  check(id3 ~= nil and #st.rows == n0 + 1 and #r.cells >= 1, "§8b après le délai, la rangée est reprise")
end

---------------------------------------------------------------------------------------------------
-- §9 ordre « chaine » de la capitalisation
---------------------------------------------------------------------------------------------------
do
  local book = { handcraftable = function() return true end }
  local function entry(sol)
    local solides = {}
    for _, n in ipairs(sol) do solides[#solides + 1] = { name = n, amount = 1 } end
    return { patronnable = true, solides = solides, fluides_in = {}, category = "crafting", machines = { { entity = "slow-asm", item = "slow-asm", par_min = 30 },
      { entity = NAMES.machine, item = NAMES.machine, par_min = 60 } }, produits = {} }
  end
  LEC.fab = { ["r-a"] = entry({ "fer" }), ["r-b"] = entry({ "cuivre", "fer" }), ["r-c"] = entry({ "a", "b", "c", "d", "e" }) }
  LEC.fab["r-a"].produits = { "a" }; LEC.fab["r-b"].produits = { "b" }; LEC.fab["r-c"].produits = { "c1" }
  LEC.par_produit = nil
  local Id = require("shared.ai3.industrie")
  local real = Id.recipe_of
  Id.recipe_of = function(fab, item)
    local r = ({ a = "r-a", b = "r-b", c1 = "r-c" })[item]
    if r and fab[r] then return r, fab[r] end
    return nil
  end
  local f = team()
  f.build.mall.pret = nil
  check(select(2, Rt.chaine(f, { item = "a", rate = 60 }, book, {}, 10, "small-electric-pole")) == "ferme", "§9 fermé : le chemin d'avant")
  f.build.mall.pret = true
  REQ = {}
  local id = Rt.chaine(f, { item = "a", rate = 60 }, book, {}, 10, "small-electric-pole")
  check(type(id) == "number" and REQ[1] and REQ[1].mall.names.poteau == "small-electric-pole", "§9 ordre chaine : une rangée demandée (poteau de l'appelant)")
  local r1 = f.build.mall.rows[1]
  check(r1.cells[1].m == "slow-asm", "§9 la machine la moins rapide utilisable (" .. tostring(r1.cells[1].m) .. ")")
  check(#r1.cells == 2 and Mr.compte(r1, "r-a") == 4, "§9 machines dimensionnées (60/min × LEAD 2 ÷ 30 = 4 machines) : " .. Mr.compte(r1, "r-a"))
  check(Rt.chaine(f, { item = "a", rate = 60 }, book, {}, 20, nil) == true, "§9 déjà servi : vrai, sans nouvelle section")
  check(#REQ == 1, "§9 pas de seconde demande")
  local nb = #REQ
  local id2 = Rt.chaine(f, { item = "a", rate = 120 }, book, {}, 30, nil)
  check(type(id2) == "number" and #REQ == nb + 1 and REQ[nb + 1].mall.from == 3, "§9 débit en hausse : section suivante de la même rangée")
  local id3 = Rt.chaine(f, { item = "b", rate = 30 }, book, {}, 40, nil)
  check(type(id3) == "number" and #f.build.mall.rows == 2, "§9 autre recette, autres voies : rangée dédiée")
  local none, why = Rt.chaine(f, { item = "c1", rate = 30 }, book, {}, 50, nil)
  check(none == nil and tostring(why):find("4 voies", 1, true) ~= nil, "§9 plus de 4 entrées : hors du mall, cause (" .. tostring(why) .. ")")
  local logged
  for _, l in ipairs(LOG) do if l:find("hors du mall", 1, true) then logged = true end end
  check(logged, "§9 la cause est écrite")
  Id.recipe_of = real
end

---------------------------------------------------------------------------------------------------
-- §10 tronc : rangée alimentée par le tronc (plaques), plan de site, retour à l'état d'avant
---------------------------------------------------------------------------------------------------
do
  local TRONC = true
  Build.Mall.tronc_on = function() return TRONC end
  Rt.logistique = function() return { repartiteur = "splitter", souterrain = "underground-belt" } end
  local Mt = require("shared.team.mall_tronc")
  local f = team()
  f.team = { ia3 = {} }
  local st = f.build.mall
  REQ = {}
  local id = Rt.place(f, { dem("a", 2, { "iron-plate" }), dem("b", 2, { "copper-plate", "iron-plate" }) }, NAMES, 10, afford, "t")
  check(id ~= nil, "§10 rangée du tronc demandée")
  local r = st.rows[1]
  check(r.bus and r.bus.a == 1 and r.bus.b == 2, "§10 deux lignes, A = la plus petite (" .. tostring(r.bus and r.bus.a) .. ")")
  check(table.concat(r.voies, ",") == "copper-plate,copper-plate,iron-plate,iron-plate", "§10 un objet par tapis (" .. table.concat(r.voies, ",") .. ")")
  check(#st.lines == 2 and st.lines[1].y_to == 7 and st.lines[2].y_to == 7, "§10 lignes prévues jusqu'à yb (" .. tostring(st.lines[1].y_to) .. ")")
  check(st.rep.west == Mt.WEST and st.rep.north == Mt.NORTH, "§10 le repère réserve la place du tronc")
  local spec = REQ[1].mall
  check(spec.bus == true and spec.head == false and spec.lines ~= nil and spec.names.repartiteur == "splitter", "§10 spec : tronc, instantané des lignes, noms des prises")
  check(spec.lines[1].y_to == nil, "§10 instantané pris AVANT d'avoir prolongé les lignes")
  -- rangée 2, mêmes plaques : les lignes sont prolongées à partir de leur étendue
  local id2 = Rt.place(f, { dem("c", 2, { "iron-plate" }) }, NAMES, 20, afford, "t")
  check(id2 ~= nil, "§10 demande suivante acceptée")
  check(#st.rows == 1 and REQ[2].mall.from == 3, "§10 même rangée : cellules à la suite, sans tronc")
  check(REQ[2].mall.lines == nil, "§10 pas de tronc dans une section d'allongement")
  -- matériel refusé : les lignes reviennent à leur état
  AFFORD = false
  local nl = #st.lines
  local _, why_w, w = Rt.place(f, { dem("d", 1, { "stone-brick" }) }, NAMES, 30, afford, "t")
  AFFORD = true
  check(#st.lines == nl, "§10 matériel refusé : lignes inchangées (" .. #st.lines .. ")")
  -- seuls répartiteur et souterrain manquent : pas d'attente, la rangée d'avant (à quais) prend le relais
  do
    local f3 = team()
    f3.team = { ia3 = {} }
    local function sans_logi(list)
      for _, it in ipairs(list) do if it[1] == "splitter" or it[1] == "underground-belt" then return false, "manque " .. it[1] end end
      return true
    end
    local id3 = Rt.place(f3, { dem("a", 2, { "iron-plate" }) }, NAMES, 40, sans_logi, "t")
    local st3 = f3.build.mall
    check(id3 ~= nil and #st3.rows == 1 and st3.rows[1].bus == nil, "§10 sans répartiteur disponible : rangée à quais")
    check(#(st3.lines or {}) == 0, "§10 sans répartiteur disponible : aucune ligne réservée")
    local function rien() return false, "rien" end
    local id4, why4, wait4 = Rt.place(team(), { dem("a", 2, { "iron-plate" }) }, NAMES, 40, rien, "t")
    check(id4 == nil and wait4 == true, "§10 autre manque : on attend, comme avant (" .. tostring(why4) .. ")")
  end
  -- plan du site : les pièces viennent du tronc et des cellules, avec la bonne étendue
  local p = f.build.projects[id]
  local masks = function() return { water = {}, blocked = {}, clear = {} } end
  st.sans_raccord = true
  PUR.calls = 0
  local lay = Build.SITES.mall(f, {}, p, { read_masks = masks })
  check(lay ~= nil, "§10 plan du site accepté")
  check(PUR.calls == 8, "§10 pureté : 2 tapis de rangée, 4 segments de lignes, 2 prises (" .. PUR.calls .. ")")
  if lay then
    local ns, nu = 0, 0
    for _, e in ipairs(lay.ents) do
      if e.name == "splitter" then ns = ns + 1 end
      if e.name == "underground-belt" then nu = nu + 1 end
    end
    check(ns == 2, "§10 deux répartiteurs (" .. ns .. ")")
    check(nu == 2, "§10 un souterrain (entrée, sortie) pour la ligne 2 (" .. nu .. ")")
    check(#lay.quais == 4, "§10 quatre coffres de tête (deux par ligne) (" .. #lay.quais .. ")")
    check(#lay.outs == 4, "§10 une sortie par machine (2 + 2 demandées), pas de quai de rangée (" .. #lay.outs .. ")")
    local n_inflow = 0
    for _ in pairs(p.inflow or {}) do n_inflow = n_inflow + 1 end
    check(n_inflow == 2 and math.abs(p.inflow["iron-plate"] - 1) < 1e-9 and math.abs(p.inflow["copper-plate"] - 0.5) < 1e-9, "§10 débit nominal des têtes de ligne, en objets/s (fer " .. tostring(p.inflow and p.inflow["iron-plate"]) .. ")")
    local ok_b, bad = true, nil
    for _, e in ipairs(lay.ents) do if e.role == "mall-tete" then ok_b, bad = false, e.name end end
    check(ok_b, "§10 aucune tête à quais sur une rangée du tronc (" .. tostring(bad) .. ")")
  end
  -- section refusée : lignes rendues
  st.rows[1].projects[1].lines_prev = { { k = 1, item = "x", y_to = 42 } }
  f.build.projects[id].state = "refuse"; f.build.projects[id].reason = "obstacle:eau"
  Rt.minute(f, surface_mock({}, {}), { fab = {} }, {}, afford, 100)
  check(st.lines[1].y_to == 42, "§10 section refusée : les lignes reviennent à leur état d'avant")
  Build.Mall.tronc_on = nil
  Rt.logistique = nil
end

print(string.format("[MALL-RANGEE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", ok_n, ko_n))
os.exit(ko_n == 0 and 0 or 1)
