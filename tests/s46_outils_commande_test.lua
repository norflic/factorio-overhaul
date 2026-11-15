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

-- 2 bis. commandes-0716 : un ordre ne s'arrête pas au chantier d'un autre avant-poste du type ; sa construction a sa clé
do
  local view = { outposts = { far }, pending = { [kind] = 1 }, sites = { [kind] = 1 }, stock = {} }
  local avail = setmetatable({}, { __index = function() return 1e6 end })
  local E2 = P.context(avail, { handcraftable = function() return false end }, view, {})
  local st2 = P.EMIT.outpost(E2, { prio = 50, id = 1, key = "x" }, { outpost = kind, ordre = 3, zones = { { x = 300, y = 0, r = 20 } } }, { tick = 0 })
  local t2 = E2.tasks[#E2.tasks]
  ok(st2 == "ok" and t2 and t2.kind == "build" and t2.key == "build:ordre:" .. kind, "ordre : construit malgre un chantier du type, cle propre")
  local E3 = P.context(avail, { handcraftable = function() return false end }, view, {})
  ok(P.EMIT.outpost(E3, { prio = 50, id = 1, key = "x" }, { outpost = kind }, { tick = 0 }) == "en_cours", "sans ordre : attend le chantier (regle d'avant)")
  local fuel_items = P.order_fuel({ { "a", 4 }, { T.fuel, 8 } }, 3)
  ok(#fuel_items == 2 and fuel_items[2][2] == 3, "ordre : combustible ramene au stock")
  fuel_items = P.order_fuel({ { "a", 4 }, { T.fuel, 8 } }, 0)
  ok(#fuel_items == 1 and fuel_items[1][1] == "a", "ordre : sans combustible au stock, l'avant-poste part quand meme")
  local view4 = { outposts = {}, pending = {}, sites = { [kind] = 1 }, stock = {} }
  local avail4 = setmetatable({ [T.fuel] = 0 }, { __index = function() return 1e6 end })
  local E4 = P.context(avail4, { handcraftable = function() return false end }, view4, {})
  ok(P.EMIT.outpost(E4, { prio = 50, id = 1, key = "x" }, { outpost = kind, ordre = 3, zones = { { x = 300, y = 0, r = 20 } } }, { tick = 0 }) == "ok",
    "ordre : construit sans combustible au stock")
  local E5 = P.context(avail4, { handcraftable = function() return false end }, view4, {})
  ok(P.EMIT.outpost(E5, { prio = 50, id = 1, key = "x" }, { outpost = kind }, { tick = 0 }) == "matiere", "sans ordre : attend son combustible (regle d'avant)")
  local s9 = Co.new_state()
  Co.add(s9, { kind = "gisement", x = 0, y = 0, r = 10, outpost = "k1", after_oid = 0 })
  ok(#Co.resolve(s9, { { kind = "k1", x = 30, y = 0, id = 1 } }) == 1, "ordre rempli a la marge de Co.ready (r + 24)")
end

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
-- ordres-0715 : l'ordre du joueur en tete absolue
do
  local st = { projects = {} }
  local gs = {}
  for i = 1, 6 do gs[#gs + 1] = { key = "autre" .. i, family = "extraction", value = 95 } end
  gs[#gs + 1] = { key = "ordre:x", family = "extraction", value = 88, ordre = 1 }
  local out = P.update(st, gs, 0, 0, nil)
  ok(out[1] and out[1].key == "ordre:x", "ordres-0715 : l'ordre est servi le premier, devant des buts plus chers")
  local found = false
  for _, p in ipairs(st.projects) do if p.key == "ordre:x" and p.state == "actif" then found = true end end
  ok(found, "ordres-0715 : l'ordre est actif meme sans place (K)")
  local g = { { key = "extraction:k", family = "extraction", outpost = "k", value = 40, releve = "plein", take_only = true } }
  Co.goals(g, { { id = 3, kind = "gisement", outpost = "k", x = 0, y = 0, r = 8 } }, 1000, {})
  ok(g[1].ordre == 3 and g[1].releve == nil and g[1].take_only == nil, "ordres-0715 : but greffe sans releve ni take_only")
  local cs = Co.new_state()
  Co.add(cs, { kind = "bastion", x = 0, y = 0, r = 10 })
  ok(Co.bastion_want(cs) == Co.BASTION_WANT and Co.bastion_want(Co.new_state()) == 0, "ordres-0715 : tourelles voulues par bastion")
  local csrc = io.open("shared/ai3/cerveau.lua"):read("*a")
  ok(csrc:find("if g.ordre then", 1, true) and csrc:find("not g.ordre and type(g.key)", 1, true) and csrc:find("ctx.capital.zone", 1, true),
    "ordres-0715 : filtres de la pile et anti-dispersion passes, zone d'amelioration permise")
  local bsrc = io.open("script/team/build.lua"):read("*a")
  ok(bsrc:find("if p.spec and p.spec.ordre then return nil end", 1, true), "ordres-0715 : projet d'ordre jamais suspendu par la pile")
end
do -- ordres-0715 (B) : spirale du coffre d'office
  local D = require("shared.team.depart")
  local a, b = D.spiral_spots(), D.spiral_spots()
  ok(#a == D.SPIRAL_BUDGET and a[1][1] == b[1][1] and a[#a][2] == b[#b][2], "spirale : bornee et deterministe")
  local mx = 0
  for _, o in ipairs(a) do mx = math.max(mx, math.abs(o[1]), math.abs(o[2])) end
  ok(mx <= D.SPIRAL_MAX and mx > 26, "spirale : au-dela des places fixes, sous le rayon maximal")
  ok(D.pick_chest({ { pos = { x = 0, y = 0 }, ore = 5 }, { pos = { x = 40, y = 0 }, ore = 0 } }) == 2, "pick_chest : place sans minerai retenue")
end
do -- commandes-0716 : jalons des délais (Co.progress), un seul relevé par jalon, pose sans route vue
  local o = { id = 1, tick = 100 }
  ok(Co.status_word(o) == "attente", "delais : attente au depart")
  local m = Co.progress(o, { route = true }, 160)
  ok(#m == 1 and m[1].what == "route" and m[1].ticks == 60 and o.t_route == 160, "delais : route notee")
  ok(#Co.progress(o, { route = true }, 220) == 0, "delais : route notee une seule fois")
  m = Co.progress(o, { ghost = true, pose = true }, 400)
  ok(#m == 2 and m[1].what == "ghost" and m[2].what == "pose" and m[2].ticks == 300, "delais : plan et pose dans l'ordre fixe")
  ok(Co.status_word(o) == "pose", "delais : mot d'etat pose")
  m = Co.progress(o, { fin = true }, 1000)
  ok(#m == 1 and m[1].what == "fin" and Co.status_word(o) == "fin", "delais : fin")
  local q = { id = 2, tick = 0 }
  m = Co.progress(q, { pose = true }, 600)
  ok(m[1].what == "route" and m[1].ticks == 600 and q.t_route == 600, "delais : une pose vaut un ouvrier venu")
  ok(#Co.progress(nil, {}, 0) == 0, "delais : sans ordre, rien")
  local q2 = { id = 3, tick = 0 }
  m = Co.progress(q2, { fin = true }, 1500)
  ok(#m == 3 and m[1].what == "route" and m[2].what == "pose" and m[3].what == "fin" and q2.t_pose == 1500, "delais : un effet complet vaut pose et route")
  -- bastion devant le front de couverture et la centrale non visée, borné dans le temps
  local yf, yp = Co.bastion_yield(8, "couverture", true, false)
  ok(yf and yp, "bastion : front de couverture et centrale en attente")
  yf, yp = Co.bastion_yield(8, "attaque", true, true)
  ok(not yf and not yp, "bastion : front attaque et centrale visee gardent leurs tourelles")
  yf, yp = Co.bastion_yield(0, "couverture", true, false)
  ok(not yf and not yp, "bastion servi : rien en attente")
  local cb = Co.new_state()
  Co.add(cb, { kind = "bastion", x = 0, y = 0, r = 10, tick = 1000 })
  ok(Co.bastion_want(cb, 1000 + Co.BASTION_YIELD_TICKS, Co.BASTION_YIELD_TICKS) == Co.BASTION_WANT
    and Co.bastion_want(cb, 1001 + Co.BASTION_YIELD_TICKS, Co.BASTION_YIELD_TICKS) == 0 and Co.bastion_want(cb) == Co.BASTION_WANT,
    "bastion : priorite bornee a Co.BASTION_YIELD_TICKS, fabrication non bornee")
  local tsrc = io.open("script/team/team.lua"):read("*a")
  ok(tsrc:find("CoCmd.bastion_yield(", 1, true), "bastion : regle branchee dans la vue de l'equipe")
  local ssrc = io.open("script/faction/sites.lua"):read("*a")
  ok(ssrc:find("prospect_blocker(f, site, designated and best or nil)", 1, true) and ssrc:find("State.war(), res ~= nil)", 1, true),
    "gisement designe : seul un site de sa ressource le gene (branche par Sites.probe_at)")
  local gsrc = io.open("script/gui/commande.lua"):read("*a")
  ok(gsrc:find("track_init(f, order)", 1, true) and gsrc:find("Events.on_nth_tick(60", 1, true), "delais : suivi branche a la pose et chaque seconde")
  for _, lang in ipairs({ "fr", "en" }) do
    local cfg = io.open("locale/" .. lang .. "/commande.cfg"):read("*a")
    for _, k in ipairs({ "etat-attente", "etat-route", "etat-plan", "etat-pose", "etat-fin", "jalon-route", "jalon-ghost", "jalon-pose", "jalon-fin" }) do
      ok(cfg:find("\n" .. k .. "=", 1, true), "traduction " .. lang .. " : " .. k)
    end
  end
end
print(string.format("s46_outils_commande_test OK (%d)", n))
