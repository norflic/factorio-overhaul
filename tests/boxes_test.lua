--[[
  Lot BOXES (directive du DC du 9/11) : cycle de vie des boxes (gisement, fonderie, energie, mall).
    §1 shared/team/boxes.lua : statuts (MAXED, VIDE, UPGRADE_REQUISE, le `else` EN_COURS), skip, wake, tech_new, inside / maxed_at,
       summary / line, déterminisme (mêmes entrées dans un autre ordre : mêmes réponses) ;
    §2 mutants : MAXED sans courant, MAXED malgré tech_new, VIDE ignoré, skip inversé : chacun refusé par les MÊMES détecteurs ;
    §3 câblage textuel : hygiene.lua (require, relevé à la tranche 0, poteaux sautés, « ignores (box MAXED) ») et boxes_rt.lua
       (abonnement on_research_finished, tech_tick, pas de `global`) ;
    §4 script/team/boxes_rt.lua sur un moteur minimal (modules du dépôt doublés) : relevé, statuts par sorte, ligne [FO-BOX],
       règle d'or (une box MAXED n'est pas remesurée : une foreuse sans courant la laisse MAXED), réveils (épuisement, recherche
       applicable -> UPGRADE_REQUISE, hystérésis, levée quand la box change), skip_at, état en données pures.
  Usage : lua5.2 tests/boxes_test.lua   (depuis la racine du mod ; moins d'une seconde)
]]
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function section(name) print("== " .. name) end

local Bx = require("shared.team.boxes")

---------------------------------------------------------------------------------------------------
-- Détecteurs partagés par §1 et §2 : des cas et leurs réponses attendues ; une règle (ou un mutant) passe par les mêmes cas.
---------------------------------------------------------------------------------------------------
local CASES = {
  { b = { planned = 4, built = 4, powered = 4 }, want = "MAXED", why = "tout bâti, tout alimenté" },
  { b = { planned = 4, built = 4, powered = 3 }, want = "EN_COURS", why = "un consommateur sans courant" },
  { b = { planned = 4, built = 3, powered = 3 }, want = "EN_COURS", why = "une pièce manque" },
  { b = { planned = 0, built = 0, powered = 0 }, want = "EN_COURS", why = "rien de prévu : jamais MAXED" },
  { b = { planned = -1, built = 5, powered = 5 }, want = "EN_COURS", why = "planned inconnu (sans cadre) : jamais MAXED" },
  { b = { planned = 4, built = 4, powered = 4, exhausted = true }, want = "VIDE", why = "épuisé prime sur tout" },
  { b = { planned = 4, built = 4, powered = 4, exhausted = true, tech_new = true, last = "MAXED" }, want = "VIDE", why = "épuisé prime sur le déblocage" },
  { b = { planned = 4, built = 4, powered = 4, tech_new = true, last = "MAXED" }, want = "UPGRADE_REQUISE", why = "déblocage applicable après MAXED" },
  { b = { planned = 4, built = 4, powered = 4, tech_new = true, last = "UPGRADE_REQUISE" }, want = "UPGRADE_REQUISE", why = "hystérésis : reste en UPGRADE_REQUISE" },
  { b = { planned = 4, built = 4, powered = 4, tech_new = true, last = "EN_COURS" }, want = "EN_COURS", why = "déblocage mais jamais MAXED : pas MAXED, pas UPGRADE" },
  { b = { planned = 4, built = 2, powered = 2, tech_new = true, last = nil }, want = "EN_COURS", why = "déblocage sans passé : en cours" },
  { b = { planned = 4, built = 4, powered = 4, last = "UPGRADE_REQUISE" }, want = "MAXED", why = "déblocage levé : MAXED de nouveau" },
  { b = {}, want = "EN_COURS", why = "table vide : le else" },
}
local function run_cases(status)
  local bad = {}
  for i, c in ipairs(CASES) do
    local got = status(c.b)
    if got ~= c.want then bad[#bad + 1] = string.format("cas %d (%s) : %s au lieu de %s", i, c.why, tostring(got), c.want) end
  end
  return bad
end
local SKIP_CASES = { { "MAXED", true }, { "EN_COURS", false }, { "UPGRADE_REQUISE", false }, { "VIDE", false }, { nil, false } }
local function run_skip(skip)
  local bad = {}
  for _, c in ipairs(SKIP_CASES) do if skip(c[1]) ~= c[2] then bad[#bad + 1] = tostring(c[1]) end end
  return bad
end

---------------------------------------------------------------------------------------------------
section("§1 règle pure : statuts, skip, wake, tech_new, géométrie, résumé, déterminisme")
---------------------------------------------------------------------------------------------------
local bad = run_cases(Bx.status)
check(#bad == 0, "statuts attendus : " .. table.concat(bad, " ; "))
check(#run_skip(Bx.skip) == 0, "skip vrai pour MAXED seulement")
-- toute réponse est l'un des quatre statuts (le else est garanti), sur une grille d'entrées
local only4, set = true, { MAXED = true, EN_COURS = true, UPGRADE_REQUISE = true, VIDE = true }
for planned = -1, 3 do for built = 0, 3 do for powered = 0, 3 do for ex = 0, 1 do for tn = 0, 1 do
  for _, last in ipairs({ "MAXED", "EN_COURS", "UPGRADE_REQUISE", "VIDE", "nil" }) do
    local s = Bx.status({ planned = planned, built = built, powered = powered, exhausted = ex == 1, tech_new = tn == 1, last = last ~= "nil" and last or nil })
    if not set[s] then only4 = false end
    if s == "MAXED" and not (planned > 0 and built == planned and powered == built and ex == 0 and tn == 0) then only4 = false end
  end
end end end end end
check(only4, "grille : quatre statuts seulement, MAXED exactement sous ses cinq conditions")
-- wake
check(Bx.wake("MAXED", {}) == "MAXED", "wake sans événement : inchangé")
check(Bx.wake("MAXED", { exhausted = true }) == "VIDE", "wake épuisement : VIDE")
check(Bx.wake("MAXED", { tech_new = true }) == "UPGRADE_REQUISE", "wake déblocage : UPGRADE_REQUISE")
check(Bx.wake("MAXED", { tech_new = true, exhausted = true }) == "VIDE", "wake les deux : VIDE")
check(Bx.wake("EN_COURS", { tech_new = true }) == "EN_COURS", "wake déblocage sur EN_COURS : inchangé")
check(Bx.wake("UPGRADE_REQUISE", { tech_new = true }) == "UPGRADE_REQUISE", "wake sur UPGRADE_REQUISE : inchangé")
-- tech_new
check(Bx.tech_new(5, 4) and not Bx.tech_new(4, 4) and not Bx.tech_new(3, 4) and not Bx.tech_new(5, nil), "tech_new : compte qui a grandi depuis le MAXED, jamais sans MAXED")
check(Bx.count_for("energie", { generator = 2, boiler = 1, furnace = 9 }) == 3 and Bx.count_for("fonderie", { furnace = 9 }) == 9 and Bx.count_for("x", {}) == 0,
  "count_for : somme des types de la sorte")
-- géométrie
local box = { x0 = 8, y0 = 8, x1 = 20, y1 = 14, status = "MAXED" }
check(Bx.inside(box, 8, 8) and Bx.inside(box, 20, 14) and Bx.inside(box, 10.5, 12.5) and not Bx.inside(box, 7.9, 10) and not Bx.inside(box, 10, 14.1), "inside : bornes comprises")
local list = { { x0 = 0, y0 = 0, x1 = 5, y1 = 5, status = "EN_COURS" }, box, { x0 = 30, y0 = 30, x1 = 40, y1 = 40, status = "VIDE" } }
check(Bx.maxed_at(list, 10, 10) and not Bx.maxed_at(list, 2, 2) and not Bx.maxed_at(list, 35, 35) and not Bx.maxed_at(nil, 10, 10), "maxed_at : seule la box MAXED fait sauter")
-- résumé et ligne
local L = { { kind = "gisement", id = 1, status = "MAXED" }, { kind = "gisement", id = 2, status = "VIDE" }, { kind = "fonderie", id = 7, status = "MAXED" },
  { kind = "mall", id = 1, status = "EN_COURS" }, { kind = "energie", id = 3, status = "UPGRADE_REQUISE" } }
local c, wakes = Bx.summary(L, { ["gisement:2"] = "MAXED", ["energie:3"] = "MAXED", ["gisement:1"] = "MAXED" })
check(c.gisement.n == 2 and c.gisement.maxed == 1 and c.fonderie.n == 1 and c.fonderie.maxed == 1 and c.mall.n == 1 and c.mall.maxed == 0 and c.energie.n == 1 and wakes == 2,
  "summary : comptes par sorte et 2 réveils (gisement 2 -> VIDE, energie 3 -> UPGRADE)")
check(Bx.line("player", 36000, c, wakes) == "[FO-BOX] player : impulsion a 10.0 min : 2 gisements (1 MAXED), 1 fonderies (1 MAXED), 1 energie (0 MAXED), 1 mall (0 MAXED) ; reveils : 2",
  "ligne [FO-BOX] : " .. Bx.line("player", 36000, c, wakes))
-- déterminisme : la liste dans l'ordre inverse donne les mêmes comptes ; chaque cas rejoué donne la même réponse
local R = {}
for i = #L, 1, -1 do R[#R + 1] = L[i] end
local c2, w2 = Bx.summary(R, { ["gisement:2"] = "MAXED", ["energie:3"] = "MAXED", ["gisement:1"] = "MAXED" })
check(c2.gisement.maxed == c.gisement.maxed and c2.mall.n == c.mall.n and w2 == wakes, "summary : même réponse en ordre inverse")
local same = true
for _, cc in ipairs(CASES) do if Bx.status(cc.b) ~= Bx.status(cc.b) then same = false end end
check(same, "status : même réponse au second appel")

---------------------------------------------------------------------------------------------------
section("§2 mutants")
---------------------------------------------------------------------------------------------------
local function m_sans_courant(b) -- MAXED sans regarder l'alimentation
  if b.exhausted then return "VIDE" end
  if b.tech_new and (b.last == "MAXED" or b.last == "UPGRADE_REQUISE") then return "UPGRADE_REQUISE" end
  if (b.planned or 0) > 0 and (b.built or 0) == b.planned and not b.tech_new then return "MAXED" end
  return "EN_COURS"
end
local function m_tech_ignore(b) -- MAXED malgré un déblocage applicable
  if b.exhausted then return "VIDE" end
  if (b.planned or 0) > 0 and (b.built or 0) == b.planned and (b.powered or 0) == b.built then return "MAXED" end
  return "EN_COURS"
end
local function m_vide_ignore(b) -- l'épuisement n'est pas lu
  return Bx.status({ planned = b.planned, built = b.built, powered = b.powered, tech_new = b.tech_new, last = b.last })
end
local function m_skip_inverse(s) return s ~= "MAXED" end
check(#run_cases(m_sans_courant) > 0, "mutant « MAXED sans courant » refusé")
check(#run_cases(m_tech_ignore) > 0, "mutant « MAXED malgré tech_new » refusé")
check(#run_cases(m_vide_ignore) > 0, "mutant « VIDE ignoré » refusé")
check(#run_skip(m_skip_inverse) > 0, "mutant « skip inversé » refusé")

---------------------------------------------------------------------------------------------------
section("§3 câblage textuel")
---------------------------------------------------------------------------------------------------
local function slurp(path)
  local fh = io.open(path, "r")
  if not fh then return "" end
  local s = fh:read("*a")
  fh:close()
  return s
end
local hy = slurp("script/team/hygiene.lua")
local rt = slurp("script/team/boxes_rt.lua")
check(hy:find('local Boxes = require("script.team.boxes_rt")', 1, true) ~= nil, "hygiene.lua requiert boxes_rt")
check(hy:find("if slice == 0 then Boxes.releve(f, surface, tick) end", 1, true) ~= nil, "hygiene.lua : relevé des boxes à la tranche 0 (Hy.step)")
check(hy:find("Boxes.skip_at(f, h.poles[i][2], h.poles[i][3])", 1, true) ~= nil, "hygiene.lua : slice_step saute les poteaux d'une box MAXED")
check(hy:find("ignores (box MAXED)", 1, true) ~= nil, "hygiene.lua : la ligne [FO-HYGIENE] compte les ignorés")
local _, n_boxes = hy:gsub("lot BOXES", "")
check(n_boxes >= 4, "chaque retouche d'hygiene.lua porte « lot BOXES » (" .. n_boxes .. ")")
check(rt:find("Events.on(defines.events.on_research_finished", 1, true) ~= nil, "boxes_rt.lua : abonnement statique à on_research_finished")
check(rt:find("tech_tick = e.tick", 1, true) ~= nil, "boxes_rt.lua : la recherche finie pose tech_tick")
check(rt:find("%f[%w_]global%f[^%w_]") == nil, "boxes_rt.lua ne nomme pas `global`")
check(rt:find("find_entities_filtered", 1, true) == nil, "boxes_rt.lua : aucune recherche d'entités par zone")

---------------------------------------------------------------------------------------------------
section("§4 moteur script/team/boxes_rt.lua sur un moteur minimal")
---------------------------------------------------------------------------------------------------
local research_fn
package.loaded["script.core.events"] = { on = function(id, fn) if id == 18 then research_fn = fn end end }
-- Lot UPS : le registre des machines (script/team/registre_types.lua) et le vrai stockage s abonnent au chargement (on_init, on_load,
-- on_configuration_changed) : tout abonnement absent du bouchon est sans effet.
setmetatable(package.loaded["script.core.events"], { __index = function() return function() end end })
local factions = {}
package.loaded["script.faction.state"] = {
  alive = function()
    local ids = {}
    for id in pairs(factions) do if id ~= "player" then ids[#ids + 1] = id end end
    table.sort(ids)
    return ids
  end,
  faction = function(id) return factions[id] end,
}
defines = { events = { on_research_finished = 18 }, -- luacheck: ignore
  entity_status = { working = 1, no_power = 2, low_power = 3, no_fuel = 4, no_minable_resources = 5, waiting_for_space_in_destination = 6 } }
local logs = {}
function log(text) logs[#logs + 1] = text end -- luacheck: ignore
local recipes = { a = { enabled = true, products = { { type = "item", name = "it-furnace" } } }, b = { enabled = false, products = { { type = "item", name = "it-drill" } } } }
game = { item_prototypes = { ["it-furnace"] = { place_result = { type = "furnace" } }, ["it-drill"] = { place_result = { type = "mining-drill" } } }, -- luacheck: ignore
  forces = { f1 = { recipes = recipes } } }

local Boxes = require("script.team.boxes_rt")
local Mr = require("shared.team.mall_rangee")
check(type(research_fn) == "function", "le moteur s'abonne à on_research_finished au chargement")

local S = defines.entity_status
local world = {}
local function at(x, y) return x .. "," .. y end
local function ent(name, x, y, status, consumer)
  local e = { name = name, valid = true, status = status or S.working, position = { x = x, y = y },
    prototype = { electric_energy_source_prototype = consumer and {} or nil } }
  world[at(x, y)] = e
  return e
end
local surface = { find_entity = function(name, pos) local e = world[at(pos[1], pos[2])] return (e and e.name == name) and e or nil end }
local function piece(name, x, y, role, built) return { name = name, x = x, y = y, role = role, built = built ~= false } end

local d1, d2 = ent("d", 10, 10, S.working, true), ent("d", 13, 10, S.working, true)
local d3 = ent("d", 50, 50, S.no_minable_resources, true)
local f = { key = 1, force = "f1", team = {},
  outposts = {
    [1] = { kind = "iron", pos = { x = 10, y = 10 }, drills = 2, migr = "fini", drill_list = { d1, d2 } },
    [2] = { kind = "coal", pos = { x = 50, y = 50 }, drills = 1, drill_list = { d3 } },
    [3] = { kind = "stone", pos = { x = 90, y = 90 }, drills = 0, drill_list = {} },
  },
  migration = { o = {} },
  build = {
    order = { 1, 2, 3, 4 }, plant = 2, sante = { healthy = true },
    projects = {
      [1] = { state = "fini", spec = { site = "champ", champ = { oid = 1, pr = 0 } }, ents = { piece("fr", 100, 10, "champ-four"), piece("fr", 102, 10, "champ-four"), piece("in", 100, 12, "champ-bras") } },
      [2] = { state = "fini", spec = { gen = "steam" }, ents = { piece("bo", 200, 10, "centrale"), piece("ge", 203, 10, "centrale") } },
      [3] = { state = "fini", spec = { site = "mall" }, ents = { piece("am", 300, 10, "mall"), piece("am", 304, 10, "mall") } },
      [4] = { state = "chantier", spec = { site = "champ", champ = { oid = 2, pr = 1 } }, ents = { piece("fr", 60, 50, "champ-four", false) } },
    },
    mall = { rows = { { j = 1, cells = { {}, {} }, projects = { { id = 3, from = 1, to = 2 } }, stop = "obstacle:secteur" } } },
  } }
factions[1] = f
ent("fr", 100, 10, S.working, false); ent("fr", 102, 10, S.working, false); ent("in", 100, 12, S.working, true)
ent("am", 300, 10, S.working, true); ent("am", 304, 10, S.working, true)

local function by(kind, id)
  for _, b in ipairs(f.team.boxes.list) do if b.kind == kind and b.id == id then return b end end
  return nil
end
Boxes.releve(f, surface, 18000)
check(f.team.boxes and #f.team.boxes.list == 7, "7 boxes relevées (3 gisements, 2 fonderies, 1 energie, 1 mall) : " .. tostring(f.team.boxes and #f.team.boxes.list))
local g1, g2, g3, fo1, fo4, en, ma = by("gisement", 1), by("gisement", 2), by("gisement", 3), by("fonderie", 1), by("fonderie", 4), by("energie", 2), by("mall", 1)
check(g1 and g1.status == "MAXED" and g1.planned == 2 and g1.built == 2 and g1.powered == 2, "gisement 1 (migr fini, 2 foreuses alimentées) : MAXED")
check(g2 and g2.status == "VIDE" and g2.exhausted, "gisement 2 (foreuse sans minerai) : VIDE")
check(g3 and g3.status == "EN_COURS" and g3.planned == Bx.UNKNOWN, "gisement 3 (sans cadre, sans foreuse) : EN_COURS, planned inconnu")
check(fo1 and fo1.status == "MAXED" and fo1.planned == 3 and fo1.built == 3 and fo1.powered == 3, "fonderie 1 (bande finie, bras alimenté) : MAXED")
check(fo4 and fo4.status == "VIDE", "fonderie 4 (bande du gisement 2 épuisé) : VIDE")
check(en and en.status == "MAXED" and en.planned == 2 and en.built == 2, "energie (centrale finie, réseau sain) : MAXED")
check(ma and ma.status == "MAXED" and ma.planned == 2 and ma.built == 2 and ma.powered == 2, "mall rangée 1 (arrêtée au bout du secteur, section finie) : MAXED")
check(g1.x0 == 8 and g1.x1 == 15 and g1.y0 == 8 and g1.y1 == 12, "boîte du gisement 1 = emprise des foreuses ± 2")
check(g3.x0 == 90 - 6 - 2 and g3.x1 == 90 + 6 + 2, "boîte d'un gisement sans foreuse = o.pos ± rayon de la sorte (pierre : 6) ± 2")
check(#logs == 1 and logs[1] == "[FO-BOX] 1 : impulsion a 5.0 min : 3 gisements (1 MAXED), 2 fonderies (1 MAXED), 1 energie (1 MAXED), 1 mall (1 MAXED) ; reveils : 0",
  "ligne [FO-BOX] : " .. tostring(logs[1]))
check(Boxes.skip_at(f, 10, 10) and Boxes.skip_at(f, 101, 11) and not Boxes.skip_at(f, 50, 50) and not Boxes.skip_at(f, 60, 50) and not Boxes.skip_at(f, 500, 500),
  "skip_at : vrai dans les boxes MAXED, faux dans une VIDE ou hors de tout")
-- règle d'or : une box MAXED n'est pas remesurée ; une foreuse qui perd le courant, un réseau malade ne la réveillent pas
d1.status = S.no_power
f.build.sante.healthy = false
logs = {}
Boxes.releve(f, surface, 36000)
check(by("gisement", 1).status == "MAXED" and by("energie", 2).status == "MAXED", "MAXED gardé sans réveil (foreuse sans courant, réseau malade)")
check(logs[1]:find("reveils : 0", 1, true) ~= nil, "aucun réveil")
d1.status = S.working
-- réveil technologique : recherche finie (événement), puis une recette activée de plus qui pose une foreuse : le gisement MAXED passe en
-- UPGRADE_REQUISE ; la fonderie (fours : aucune recette de plus) reste MAXED
research_fn({ research = { force = { name = "f1" } }, tick = 40000 })
check(f.team.boxes.tech_tick == 40000, "tech_tick posé par la recherche finie")
recipes.b.enabled = true
logs = {}
Boxes.releve(f, surface, 54000)
check(by("gisement", 1).status == "UPGRADE_REQUISE" and by("fonderie", 1).status == "MAXED" and by("mall", 1).status == "MAXED", "déblocage applicable aux foreuses : gisement 1 en UPGRADE_REQUISE, les autres MAXED")
check(logs[1]:find("3 gisements (0 MAXED)", 1, true) ~= nil and logs[1]:find("reveils : 1", 1, true) ~= nil, "journal : 1 réveil")
check(not Boxes.skip_at(f, 10, 10), "une box en UPGRADE_REQUISE n'est plus sautée")
Boxes.releve(f, surface, 72000)
check(by("gisement", 1).status == "UPGRADE_REQUISE", "hystérésis : reste en UPGRADE_REQUISE tant que la box ne change pas")
-- la box change (une foreuse de plus) : nouveau cycle, MAXED de nouveau avec le compte de recettes refait
local d4 = ent("d", 16, 10, S.working, true)
f.outposts[1].drill_list[3] = d4
Boxes.releve(f, surface, 90000)
check(by("gisement", 1).status == "MAXED" and by("gisement", 1).at_maxed.recipes == 1, "box changée après le déblocage : MAXED, compte des recettes refait (1)")
-- une recherche sans recette applicable de plus ne réveille rien
research_fn({ research = { force = { name = "f1" } }, tick = 95000 })
Boxes.releve(f, surface, 108000)
check(by("gisement", 1).status == "MAXED" and by("fonderie", 1).status == "MAXED", "recherche sans recette applicable : rien ne bouge")
-- une recherche d'une AUTRE force ne marque pas l'équipe
local before = f.team.boxes.tech_tick
research_fn({ research = { force = { name = "f9" } }, tick = 110000 })
check(f.team.boxes.tech_tick == before, "recherche d'une autre force : ignorée")
-- épuisement d'une box MAXED : VIDE ; sa fonderie suit
d1.status, d2.status, d4.status = S.no_minable_resources, S.no_minable_resources, S.no_minable_resources
logs = {}
Boxes.releve(f, surface, 126000)
check(by("gisement", 1).status == "VIDE" and by("fonderie", 1).status == "VIDE", "gisement 1 épuisé : VIDE, fonderie 1 VIDE")
check(logs[1]:find("reveils : 2", 1, true) ~= nil, "journal : 2 réveils")
-- une bande en chantier : EN_COURS sans lecture d'entité (powered = 0) ; une équipe sans box : aucune ligne
f.outposts[2].drill_list[1].status = S.working
Boxes.releve(f, surface, 144000)
check(by("fonderie", 4).status == "EN_COURS" and by("fonderie", 4).powered == 0 and by("fonderie", 4).built == 0, "bande en chantier : EN_COURS")
logs = {}
local empty = { key = 2, force = "f2", team = {} }
Boxes.releve(empty, surface, 144000)
check(#logs == 0 and empty.team.boxes and #empty.team.boxes.list == 0, "équipe sans box : liste vide, pas de ligne")
-- l'état gardé ne contient que des nombres, booléens, chaînes et tables
local function pure(t)
  for k, v in pairs(t) do
    local tv = type(v)
    if tv == "table" then if not pure(v) then return false end
    elseif tv ~= "number" and tv ~= "boolean" and tv ~= "string" then return false end
    if type(k) == "function" or type(k) == "userdata" then return false end
  end
  return true
end
check(pure(f.team.boxes), "état f.team.boxes en données pures")
check(Mr.MAX_CELLS == 64, "planned d'une rangée ouverte = Mr.MAX_CELLS (64)")

print(string.format("boxes_test : %d OK, %d ECHEC", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
