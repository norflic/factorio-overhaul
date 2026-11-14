-- Lot s46 OUTILS-COMMANDE : zone de l'ordre de gisement portée au but et lue par EMIT.outpost, ordres retirés ou remplacés,
-- Maj + glisser identique au glisser, touches « game-only ». Usage : lua5.2 tests/s46_outils_commande_test.lua
package.path = "./?.lua;" .. package.path
local Co = require("shared.ai3.commande")
local T = require("shared.team.config")
local P = require("shared.ai3.projets")

local n = 0
local function ok(c, msg) assert(c, msg); n = n + 1 end

-- 1. Co.goals : la zone de l'ordre va dans le but (neuf ou relevé)
local orders = { { id = 3, kind = "gisement", outpost = "k1", x = 100, y = 0, r = 20 }, { id = 4, kind = "gisement", outpost = "k1", x = -50, y = 0, r = 10 } }
local g = Co.goals({}, orders, 1000, {})
ok(g[1].zone and g[1].zone.x == 100 and g[1].zone.r == 20, "zone du premier ordre dans le but neuf")
ok(#g[1].zones == 2 and g[1].zones[2].x == -50, "toutes les zones du type dans le but")
g = Co.goals({ { family = "extraction", kind = "outpost", outpost = "k1", value = 50 } }, orders, 1000, {})
ok(g[1].zones and #g[1].zones == 2, "but existant relevé : zones aussi")
ok(Co.in_zones(nil, 1, 1) and Co.in_zones({}, 1, 1), "sans zone : tout avant-poste passe")
ok(Co.in_zones(g[1].zones, 120, 10) and not Co.in_zones(g[1].zones, 0, 0) and not Co.in_zones(g[1].zones, nil, nil), "dans / hors zone")

-- 2. EMIT.outpost : avec une zone, l'avant-poste non plein HORS zone n'est plus agrandi ; celui de la zone l'est ; aucun : on bâtit
local kind = T.OUTPOST_ORDER[1]
local function E_of(outposts)
  local view = { outposts = outposts, pending = {}, sites = { [kind] = 1 }, stock = {} }
  local avail = setmetatable({}, { __index = function() return 1e6 end })
  return P.context(avail, { handcraftable = function() return false end }, view, {})
end
local far = { id = 1, kind = kind, drills = 1, full = false, d2 = 100, x = 10, y = 0 }
local inzone = { id = 2, kind = kind, drills = 1, full = false, d2 = 90000, x = 300, y = 5 }
local zg = { outpost = kind, zones = { { x = 300, y = 0, r = 20 } } }
local function emitted(E) return E.tasks[#E.tasks] end
local E = E_of({ far })
local okc, st = pcall(P.EMIT.outpost, E, { prio = 50, id = 1, key = "x" }, zg, { tick = 0 })
ok(okc, "EMIT.outpost sans erreur : " .. tostring(st))
local t = emitted(E)
ok(t == nil or t.kind ~= "extend", "avant-poste hors zone : pas agrandi")
ok(t and t.kind == "build", "aucun avant-poste dans la zone : construction (site de la zone d'abord)")
E = E_of({ far, inzone })
P.EMIT.outpost(E, { prio = 50, id = 1, key = "x" }, zg, { tick = 0 })
t = emitted(E)
ok(t and t.kind == "extend" and t.outpost == 2, "avant-poste DANS la zone agrandi, même loin du QG")
E = E_of({ far, inzone })
P.EMIT.outpost(E, { prio = 50, id = 1, key = "x" }, { outpost = kind }, { tick = 0 })
t = emitted(E)
ok(t and t.kind == "extend" and t.outpost == 1, "sans zone : le plus proche du QG (règle d'avant)")

-- 3. Co.resolve : un avant-poste déjà là, agrandi au plafond, remplit l'ordre
local s = Co.new_state()
Co.add(s, { kind = "gisement", x = 0, y = 0, r = 10, outpost = "k1", after_oid = 5 })
ok(#Co.resolve(s, { { kind = "k1", x = 2, y = 2, id = 3 } }) == 0, "déjà là, pas saturé : non rempli")
ok(#Co.resolve(s, { { kind = "k1", x = 2, y = 2, id = 3, saturated = true } }) == 1, "déjà là, saturé : rempli")

-- 4. retrait et remplacement
s = Co.new_state()
Co.add(s, { kind = "gisement", x = 0, y = 0, r = 10, outpost = "k1" })
for i = 2, Co.MAX_ORDERS do Co.add(s, { kind = (i % 2 == 0) and "liaison" or "bastion", x = i * 100, y = 0, r = 10 }) end
local id, why, old = Co.add_replacing(s, { kind = "bastion", x = 9, y = 9, r = 10 })
ok(id == Co.MAX_ORDERS + 1 and why == nil and old and old.id == 2 and old.kind == "liaison", "plein : le plus ancien non-gisement remplacé")
ok(#s.orders == Co.MAX_ORDERS and s.orders[1].kind == "gisement", "le gisement reste, le plafond tient")
local id2, why2 = Co.add(s, { kind = "bastion", x = 9, y = 9, r = 10 })
ok(id2 == nil and why2 == "plein", "Co.add garde son refus « plein »")
ok(Co.mark(s, 3, "fini") and Co.mark(s, 3, "autre").done == "fini", "marque gardée")
ok(#Co.finished(s) == 1 and Co.finished(s)[1] == 3, "ordres marqués")
ok(Co.mark(s, 999, "fini") == nil, "ordre inconnu")

-- 5. liaison : ordre servi, cause sans paire
local lo = { { id = 7, kind = "liaison", x = 0, y = 0, r = 10, a = { x = 100, y = 0, r = 10 } } }
ok(Co.liaison_order(lo, { x = 1, y = 1 }, nil) == 7, "quai dans la zone : ordre trouvé")
ok(Co.liaison_order(lo, { x = 500, y = 1 }, { x = 500, y = 0 }) == nil, "hors zone : aucun")
ok(Co.liaison_order(lo, nil, nil, 9) == 9, "paire imposée : son ordre")
ok(Co.forced_why(lo[1], {}, {}) == "sortie", "sans sortie : « sortie »")
ok(Co.forced_why(lo[1], {}, { { x = 100, y = 0, item = "a" } }) == "quai", "sans quai : « quai »")
ok(Co.forced_why(lo[1], { { x = 0, y = 0, item = "b" } }, { { x = 100, y = 0, item = "a" } }) == "objet", "objets différents : « objet »")
ok(Co.forced_why(lo[1], { { x = 0, y = 0, item = "a" } }, { { x = 100, y = 0, item = "a" } }) == nil, "paire possible : nil")

-- 6. trace bornée, sans doublon
s = Co.new_state()
ok(Co.note(s, 1, "a") and not Co.note(s, 1, "a") and Co.note(s, 1, "b"), "une ligne nouvelle seulement")
for i = 1, 40 do Co.note(s, i + 10, "x") end
ok(#s.hist == Co.HIST_MAX, "trace bornée")

-- 7. prototypes : Maj + glisser non vide, touches game-only
local src = io.open("prototypes/commande.lua"):read("*a")
ok(src:find("alt_selection_mode = t.mode, alt_entity_type_filters", 1, true), "alt identique au mode normal")
ok(src:find('consuming = "game-only"', 1, true) and not src:find('consuming = "none"', 1, true), "touches game-only")
local gui = io.open("script/gui/commande.lua"):read("*a")
ok(gui:find('["fo-cmd-gisement"] = { do_gisement, do_gisement', 1, true), "slot 2 du gisement = même action")
ok(gui:find('remote.add_interface("fo-commande"', 1, true) and gui:find("handle(slot, e, bench_player(prints))", 1, true), "banc : même gestionnaire")
for _, lang in ipairs({ "fr", "en" }) do
  local l = io.open("locale/" .. lang .. "/commande.cfg"):read("*a")
  for _, k in ipairs({ "sans-equipe-outil", "remplace", "fini-liaison", "fini-bastion" }) do ok(l:find("\n" .. k .. "=", 1, true), lang .. " " .. k) end
end
-- 8. bastion du joueur : sous la réserve, groupe d'une tourelle, d'abord, places en spirale dans le rayon de l'ordre
local Dsr = require("shared.team.defense_stock")
ok(Dsr.surplus_for(5, true) == 5 and Dsr.surplus_for(5, false) == 0 and Dsr.surplus_for(-1, true) == 0, "bastion : tout le stock")
ok(Dsr.min_group(true) == 1 and Dsr.min_group(nil) == Dsr.MIN_GROUP, "bastion : groupe d'une tourelle")
local sp = Dsr.spiral(66, 6, 14)
ok(#sp > 8 and #sp <= 160, "spirale : plus que les huit points de l'anneau, bornée (" .. #sp .. ")")
ok(sp[1].x == 66 and sp[1].y == 6, "spirale : le centre d'abord")
local okr, prev = true, -1
for _, q in ipairs(sp) do
  local d2 = (q.x - 66) ^ 2 + (q.y - 6) ^ 2
  if d2 > 14 * 14 or d2 < prev then okr = false end
  prev = d2
end
ok(okr, "spirale : dans le rayon, du plus proche au plus loin")
ok(#Dsr.spiral(0, 0, 96) <= 240, "spirale : bornée pour le plus grand rayon")
local function plan_with(stock, ordre)
  return Dsr.plan({ stock = stock, ammo = 200, placed = 0, turrets = {},
    zones = { { key = "qg", kind = "qg", x = 0, y = 0, score = 0, want = 4, have = 0 },
      { key = "bastion4", kind = "qg", x = 66, y = 6, score = 0, want = 8, have = 0, ordre = ordre, r = 14 } } })
end
local pl = plan_with(6, true)
ok(pl.pick and pl.pick.key == "bastion4" and pl.pick.count >= 1 and pl.pick.ordre and pl.pick.zr == 14, "bastion servi d'abord, sous la réserve (stock 6)")
ok(#pl.pick.sites == #sp, "bastion : emplacements en spirale")
ok(plan_with(6, nil).pick == nil, "sans ordre : sous la réserve, rien (règle d'avant)")
ok(Dsr.plan({ stock = 9, ammo = 200, placed = 0, turrets = {}, zones = { { key = "b", kind = "qg", x = 0, y = 0, want = 8, have = 0 } } }).pick == nil,
  "sans ordre : surplus 1, groupe de 3 refusé (règle d'avant)")
local psrc = io.open("shared/team/planner.lua"):read("*a")
ok(psrc:find("Dsr.surplus_for(avail[T.turret] or 0, pk.ordre)", 1, true) and psrc:find("ordre_r = pk.ordre", 1, true), "planificateur : même exception")
print(string.format("s46_outils_commande_test OK (%d)", n))
