-- Scénario greffé du lot RB-2 JOUEUR (1/11) : l'interface et les outils des robots en moteur réel.
--   avec images (UN JOUEUR EST CONNECTÉ : indispensable aux outils, au panneau et à l'onglet) :
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache --ticks 4700" --qui RB23 -- 4600 rb-ui <source>
--   sans images (aucun joueur) : seule la partie sans interface tourne (persistance, maintenir N sur l'atelier).
-- LIMITE (RB0 E6) : aucun script ne produit un événement de sélection à la souris. Les gestionnaires des quatre événements de l'outil
-- sont rejoués par `fo-robots-ui.tool`, avec la zone et les entités que le moteur leur donnerait (même fonction que l'événement) ;
-- ce que seul un joueur peut prouver : la zone reçue pour un clic sans glisser, en vue carte, et les touches.
-- Un Atelier d'automates garni par deux coffres et deux bras, « maintenir 2 » réglé par les BOUTONS du panneau, ralliement choisi par
-- l'outil, puis des ordres. Chronologie (ticks) :
--     5  persistance : file et ralliement écrits à la création, relus (a)
--    10  panneau ouvert sur l'atelier (b) ; boutons − + ∞ (c) ; ralliement « ici », « par défaut », outil, événement (d)
--  2300  maintenir 2 : 2 robots, le 3e kit bloqué en sortie (e) ; ils sont au ralliement choisi (f)
--  2310  2 robots posés en plus ; sélection par l'outil, zone vide, tout choisir (g)
--  2330  Maj + glisser réduit à un clic : marche-attaque (h) ; 2400 : elle a avancé
--  2410  2 mordeurs ; bouton droit : attaquer ce qui est encadré (i) ; Maj + droit : aller (j)
--  3350  onglet « Armée » : boutons (k) ; 3400 « Tous au ralliement » ; 4000 : au ralliement
--  4100  3 pertes : une alerte, puis un bilan (l) ; 4300 : réglage éteint, aucun ordre (m)
-- Journal : [FO-RB-UI].

local X0, Y0 = 1500, 1500
local CHECK = 4500
local KIT = "fo-robot-kit-steam-trotter"
local TROTTE = "steam-trotter"
local TOOL, RALLY = "fo-robot-order", "fo-robot-rally"
local RALLY_PICK = { x = X0 + 14, y = Y0 + 24 }

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

local function R(ctx, fn, ...) return ctx.remote("fo-robots", fn, ...) end
local function U(ctx, fn, ...) return ctx.remote("fo-robots-ui", fn, ...) end
local function G(ctx, fn, ...) return ctx.remote("fo-robots-gui", fn, ...) end
local function W(ctx, fn, ...) return ctx.remote("fo-ia1i", fn, ...) end

local function player() return game.connected_players[1] end

local function pos_of(ctx, un)
  local i = un and R(ctx, "unit_info", un)
  return i and { x = i.x, y = i.y } or nil
end

local function mean_dist(ctx, units, p)
  local sum, n = 0, 0
  for _, un in ipairs(units) do
    local q = pos_of(ctx, un)
    if q then sum, n = sum + dist(q, p), n + 1 end
  end
  return n > 0 and sum / n or nil, n
end

local function box(cx, cy, r) return { cx - r, cy - r, cx + r, cy + r } end

--- Événement d'un outil sur une zone carrée de centre (cx, cy) et de demi-côté r (r = 0 : un clic).
local function tool(ctx, p, ev, item, cx, cy, r)
  return U(ctx, "tool", p.index, ev, item, cx - r, cy - r, cx + r, cy + r)
end

local function shot(ctx, p, name, x, y, zoom)
  local st = ctx.state()
  local res = p.display_resolution
  local w, h = math.min(4096, math.max(640, res.width)), math.min(4096, math.max(360, res.height))
  game.take_screenshot({ path = "fo-shots/x-rbui-" .. name .. ".png", player = p, show_gui = true, position = { x = x, y = y },
    zoom = zoom or 1, resolution = { w, h }, daytime = 0, force_render = true, allow_in_replay = true })
  st.shots = (st.shots or 0) + 1
  ctx.log(string.format("capture x-rbui-%s.png demandee au tick %d", name, game.tick))
end

local function kits_en_sortie(w)
  local inv = w.get_output_inventory()
  return inv and inv.get_item_count(KIT) or -1
end

local function garnir(s, w, force, ingredients)
  local pos = w.position
  for i, ing in ipairs(ingredients) do
    local x = pos.x - 1 + (i - 1) * 2
    local c = s.create_entity({ name = "steel-chest", position = { x, pos.y - 3 }, force = force })
    c.insert({ name = ing[1], count = ing[2] })
    local b = s.create_entity({ name = "fast-inserter", position = { x, pos.y - 2 }, force = force })
    b.pickup_position = { x, pos.y - 3 }
    b.drop_position = { x, pos.y - 1 }
  end
end

local steps = {}

---------------------------------------------------------------------------------------------------
steps[5] = function(ctx, st)
  -- la fenetre d'introduction du mod (« Arche-5 ») couvre l'ecran et reprend `opened` : fermee avant tout
  local p0 = player()
  if p0 then p0.gui.screen.clear() end
  -- (a) persistance : écrit à la création (init), relu après chargement
  local w = R(ctx, "workshop", st.w.unit_number)
  ctx.check(w and w.queue and #w.queue == 1 and w.queue[1].id == TROTTE and w.queue[1].n == 5 and w.keep[TROTTE] == 5
    and w.rally and w.rally.x == X0 + 3 and w.rally.y == Y0 + 20,
    "(a) relu apres sauvegarde : la file (maintenir 5) et le ralliement de l'atelier",
    w and string.format("file %d entree(s), n=%s, ralliement %s", #w.queue, tostring(w.queue[1] and w.queue[1].n),
      w.rally and (w.rally.x .. "," .. w.rally.y) or "nil") or "atelier absent")
  R(ctx, "set_keep", st.w.unit_number, TROTTE, nil)
  R(ctx, "set_rally", st.w.unit_number)
end

steps[10] = function(ctx, st)
  local p = player()
  if not p then
    ctx.log("aucun joueur : interface, outils, onglet et alertes ne sont pas jouables (session sans images)")
    st.keep_direct = true
    R(ctx, "set_keep", st.w.unit_number, TROTTE, 2)
    return
  end
  st.p = p.index
  p.teleport({ X0 + 4, Y0 + 12 })
  -- (b) panneau de l'atelier
  local ok = G(ctx, "open", p.index, st.w.unit_number)
  local pn = G(ctx, "panel", p.index)
  ctx.check(ok == true and pn and pn.visible == true and pn.army == "fo-robots-ui.army" and pn.keys[TROTTE] == "inf"
    and pn.rally == "fo-robots-ui.rally-default",
    "(b) panneau de l'atelier : ouvert, armee, robot sans limite, ralliement par defaut",
    pn and string.format("visible=%s armee=%s cle=%s ralliement=%s", tostring(pn.visible), tostring(pn.army), tostring(pn.keys[TROTTE]),
      tostring(pn.rally)) or "panneau absent")
  -- (c) les boutons : + + - ∞ + +
  local function keep() local w = R(ctx, "workshop", st.w.unit_number) return w and w.keep[TROTTE] end
  G(ctx, "click", p.index, "fo_rb_inc_" .. TROTTE); G(ctx, "click", p.index, "fo_rb_inc_" .. TROTTE)
  local a = keep()
  G(ctx, "click", p.index, "fo_rb_dec_" .. TROTTE)
  local b = keep()
  G(ctx, "click", p.index, "fo_rb_inf_" .. TROTTE)
  local c = keep()
  local w0 = R(ctx, "workshop", st.w.unit_number)
  G(ctx, "click", p.index, "fo_rb_inc_" .. TROTTE); G(ctx, "click", p.index, "fo_rb_inc_" .. TROTTE)
  local pn2 = G(ctx, "panel", p.index)
  ctx.check(a == 2 and b == 1 and c == nil and #w0.queue == 0 and keep() == 2 and pn2.keys[TROTTE] == "2" and pn2.ups[TROTTE] == false,
    "(c) boutons + + - infini + + : 2, 1, sans limite (file vide), 2 ; le panneau montre 2, sans fleches avec une seule entree",
    string.format("%s %s %s file %d final %s affiche %s", tostring(a), tostring(b), tostring(c), #w0.queue, tostring(keep()), tostring(pn2.keys[TROTTE])))
  -- (d) ralliement : ici, par défaut, outil, événement
  p.teleport({ X0 + 9, Y0 + 15 })
  G(ctx, "click", p.index, "fo_rb_rally_here")
  local w1 = R(ctx, "workshop", st.w.unit_number)
  local here = w1.rally and dist(w1.rally, p.position) <= 1
  G(ctx, "click", p.index, "fo_rb_rally_reset")
  local w2 = R(ctx, "workshop", st.w.unit_number)
  G(ctx, "click", p.index, "fo_rb_rally_pick")
  local pend = U(ctx, "rally_pending", p.index)
  local cur = p.character and U(ctx, "cursor", p.index) or RALLY
  tool(ctx, p, "selected", RALLY, RALLY_PICK.x, RALLY_PICK.y, 2)
  local w3 = R(ctx, "workshop", st.w.unit_number)
  local pend2 = U(ctx, "rally_pending", p.index)
  tool(ctx, p, "alt", RALLY, X0 - 40, Y0 - 40, 2) -- plus d'atelier en attente : sans effet
  local w4 = R(ctx, "workshop", st.w.unit_number)
  ctx.check(here and w2.rally == nil and pend == st.w.unit_number and cur == RALLY and w3.rally and dist(w3.rally, RALLY_PICK) < 0.01
    and pend2 == nil and w4.rally and dist(w4.rally, RALLY_PICK) < 0.01,
    "(d) ralliement : ici, par defaut, outil en main, un evenement de l'outil le fixe (une seule fois)",
    string.format("ici=%s, apres defaut %s, en attente %s, outil en main %s, fixe %s, apres %s, deuxieme evenement sans effet %s",
      tostring(here), tostring(w2.rally), tostring(pend), tostring(cur), w3.rally and (w3.rally.x .. "," .. w3.rally.y) or "nil",
      tostring(pend2), tostring(w4.rally and dist(w4.rally, RALLY_PICK) < 0.01)))
  st.shot_panel = true
end

steps[110] = function(ctx, st)
  local p = player()
  -- la capture du moteur ne montre pas la fenetre d'une machine ouverte : le MEME panneau est pose dans l'ecran (apercu)
  if p and st.shot_panel then ctx.check(G(ctx, "preview", p.index, st.w.unit_number) == true, "apercu du panneau de l'atelier pose pour la capture") end
end

steps[140] = function(ctx, st)
  local p = player()
  if p and st.shot_panel then shot(ctx, p, "panneau", X0 + 6, Y0 + 12, 1) end
end

---------------------------------------------------------------------------------------------------
steps[2300] = function(ctx, st)
  local etat = R(ctx, "state", "player")
  local kits = kits_en_sortie(st.w)
  -- (e) maintenir 2 : deux robots, le 3e kit reste en sortie, la machine est arrêtée
  ctx.check(etat.by_id[TROTTE] == 2 and #etat.units == 2 and kits == 1 and etat.stats.created == 2 and etat.stats.kits_removed == 2,
    "(e) maintenir 2 : 2 robots, un 3e kit attend en sortie (la machine s'arrete d'elle-meme)",
    string.format("robots %s, unites %d, kits en sortie %d, crees %d, kits retires %d, statut %s", tostring(etat.by_id[TROTTE]), #etat.units,
      kits, etat.stats.created, etat.stats.kits_removed, tostring(st.w.status)))
  -- (f) ils sont au ralliement choisi
  local cible = st.p and RALLY_PICK or { x = X0 + 0.5, y = Y0 + 13 } -- sans joueur : le ralliement par defaut (9 tuiles au sud de la sortie)
  local d, n = mean_dist(ctx, etat.units, cible)
  ctx.check(n == 2 and d and d <= 6, "(f) les robots nes de l'atelier marchent au ralliement (choisi par l'outil, ou par defaut sans joueur)",
    string.format("%d robot(s), distance moyenne au ralliement %s", n, tostring(d)))
  st.made = etat.units
end

steps[2310] = function(ctx, st)
  local extra = {}
  for i = 1, 2 do
    local un = R(ctx, "spawn", "player", TROTTE, X0 + 6 + 3 * i, Y0 + 6)
    extra[#extra + 1] = un
  end
  st.extra = extra
  local p = player()
  if not p then return end
  local etat = R(ctx, "state", "player")
  st.all = etat.units
  -- (g) sélection par l'outil : tout, zone vide, tout
  local cx, cy = X0 + 8, Y0 + 15
  local before = #U(ctx, "selection", p.index)
  tool(ctx, p, "selected", TOOL, cx, cy, 30)
  local s1 = U(ctx, "selection", p.index)
  tool(ctx, p, "selected", TOOL, X0 - 300, Y0 - 300, 5)
  local s2 = U(ctx, "selection", p.index)
  tool(ctx, p, "selected", TOOL, cx, cy, 30)
  local s3 = U(ctx, "selection", p.index)
  local sorted = true
  for i = 2, #s3 do if s3[i - 1] >= s3[i] then sorted = false end end
  -- l'outil n'obéit qu'à lui : l'événement d'un autre objet est ignoré
  tool(ctx, p, "selected", "iron-plate", X0 - 300, Y0 - 300, 5)
  local s4 = U(ctx, "selection", p.index)
  ctx.check(before == 0 and #s1 == 4 and #s2 == 0 and #s3 == 4 and sorted and #s4 == 4,
    "(g) l'outil choisit les robots d'une zone (4), une zone vide vide la selection, la liste est triee, un autre objet est ignore",
    string.format("avant %d, zone %d, zone vide %d, de nouveau %d (triee %s), autre objet %d", before, #s1, #s2, #s3, tostring(sorted), #s4))
  st.sel4 = s3
  st.p0 = mean_dist(ctx, s3, { x = X0 + 40, y = Y0 + 30 })
end

steps[2330] = function(ctx, st)
  local p = player()
  if not p then return end
  -- (h) Maj + glisser réduit à un clic (zone nulle) : marche-attaque vers le point, rayon minimal
  local o0 = R(ctx, "state", "player").stats.ordered
  tool(ctx, p, "alt", TOOL, X0 + 40, Y0 + 30, 0)
  local o1 = R(ctx, "state", "player").stats.ordered
  ctx.check(o1 - o0 == 4, "(h) Maj + glisser, meme reduit a un clic : marche-attaque donnee aux 4 robots choisis",
    string.format("ordres donnes %d", o1 - o0))
end

steps[2345] = function(ctx, st)
  local p = player()
  if p then shot(ctx, p, "selection", X0 + 12, Y0 + 20, 1) end -- les cercles de selection se dessinent tous les 30 ticks (duree 35)
end

steps[2400] = function(ctx, st)
  if not st.sel4 then return end
  local d, n = mean_dist(ctx, st.sel4, { x = X0 + 40, y = Y0 + 30 })
  ctx.check(n == 4 and d and st.p0 and st.p0 - d >= 4, "(h) ils marchent vers le point d'attaque (rapprochement d'au moins 4 tuiles en 70 ticks)",
    string.format("%d robot(s), distance moyenne %s -> %s", n, tostring(st.p0), tostring(d)))
end

steps[2410] = function(ctx, st)
  local p = player()
  if not p then return end
  local s = ctx.surface()
  st.biters = {}
  for i = 1, 2 do
    st.biters[i] = s.create_entity({ name = "medium-biter", position = { X0 + 47 + 3 * i, Y0 + 70 }, force = "enemy" })
  end
  -- (i) bouton droit : attaquer ce qui est encadré (le centre des ennemis, pas le centre de la zone)
  local o0 = R(ctx, "state", "player").stats.ordered
  tool(ctx, p, "reverse", TOOL, X0 + 51, Y0 + 70, 12)
  local o1 = R(ctx, "state", "player").stats.ordered
  ctx.check(o1 - o0 == 4 and st.biters[1] and st.biters[2], "(i) bouton droit : attaque ce qui est encadre, donnee aux 4 robots choisis",
    string.format("ordres donnes %d, mordeurs poses %s", o1 - o0, tostring(st.biters[1] ~= nil)))
end

steps[2420] = function(ctx, st)
  local p = player()
  if not p then return end
  -- (j) Maj + bouton droit : aller (réponse sans combat voulu : les robots ripostent en route)
  local o0 = R(ctx, "state", "player").stats.ordered
  tool(ctx, p, "alt_reverse", TOOL, X0 + 20, Y0 + 20, 3)
  local o1 = R(ctx, "state", "player").stats.ordered
  tool(ctx, p, "reverse", TOOL, X0 + 51, Y0 + 70, 12) -- puis de nouveau l'attaque : les mordeurs doivent mourir
  ctx.check(o1 - o0 == 4, "(j) Maj + bouton droit : aller, donne aux 4 robots choisis", string.format("ordres donnes %d", o1 - o0))
end

steps[3350] = function(ctx, st)
  local p = player()
  if not p then return end
  local dead = true
  for _, b in ipairs(st.biters or {}) do if b.valid then dead = false end end
  ctx.check(dead and #(st.biters or {}) == 2, "(i) les robots ont tue les 2 mordeurs encadres",
    string.format("mordeurs morts %s", tostring(dead)))
  -- (k) onglet « Armée » : ouvert, boutons présents, choisir tout, désélectionner, tous au ralliement
  G(ctx, "close", p.index)
  W(ctx, "open", p.index, "armee")
  local s = W(ctx, "state", p.index)
  local has = {}
  for _, n in ipairs(s.names or {}) do has[n] = true end
  local keys = {}
  for _, k in ipairs(s.keys or {}) do keys[k] = true end
  ctx.check(s.open and s.tab == "armee" and has.fo_rb_army_tool and has.fo_rb_army_all and has.fo_rb_army_none and has.fo_rb_army_rally
    and keys["fo-robots-ui.tab-intro"],
    "(k) onglet Armee : fenetre ouverte sur l'onglet, les 4 boutons et le texte d'introduction",
    string.format("ouverte %s, onglet %s, boutons %s %s %s %s", tostring(s.open), tostring(s.tab), tostring(has.fo_rb_army_tool),
      tostring(has.fo_rb_army_all), tostring(has.fo_rb_army_none), tostring(has.fo_rb_army_rally)))
  G(ctx, "click", p.index, "fo_rb_army_none")
  local n0 = #U(ctx, "selection", p.index)
  G(ctx, "click", p.index, "fo_rb_army_all")
  local n1 = #U(ctx, "selection", p.index)
  local etat = R(ctx, "state", "player")
  ctx.check(n0 == 0 and n1 == #etat.units and n1 >= 4,
    "(k) Desselectionner vide la selection, Choisir tous mes robots les prend tous", string.format("%d puis %d (robots %d)", n0, n1, #etat.units))
  local cur = G(ctx, "click", p.index, "fo_rb_army_tool")
  ctx.log("bouton Prendre l'outil d'ordre : " .. tostring(cur) .. " ; en main : " .. tostring(U(ctx, "cursor", p.index)))
  st.units_k = etat.units
end

steps[3380] = function(ctx, st)
  local p = player()
  if p then shot(ctx, p, "onglet-armee", X0 + 8, Y0 + 14, 1) end
end

steps[3400] = function(ctx, st)
  local p = player()
  if not p then return end
  local r = G(ctx, "click", p.index, "fo_rb_army_rally")
  ctx.check(r == true, "(k) Tous au ralliement : bouton traite", tostring(r))
  st.rally_d0 = mean_dist(ctx, st.units_k or {}, RALLY_PICK)
end

steps[4000] = function(ctx, st)
  local p = player()
  if not p then return end
  local d, n = mean_dist(ctx, st.units_k or {}, RALLY_PICK)
  ctx.check(n >= 4 and d and d <= 9, "(k) Tous au ralliement : chaque robot est revenu au ralliement de son atelier (ou du premier atelier)",
    string.format("%d robot(s), distance moyenne %s -> %s", n, tostring(st.rally_d0), tostring(d)))
end

steps[4100] = function(ctx, st)
  local p = player()
  if not p then return end
  -- (l) trois pertes dans le même tick : une seule alerte, un bilan 2 secondes plus tard
  local before = U(ctx, "alerts")
  st.alerts0 = before
  local etat = R(ctx, "state", "player")
  st.lost0 = etat.stats.lost
  local used0 = etat.used
  for i = 1, 3 do R(ctx, "kill", etat.units[i]) end
  st.used_k = used0
end

steps[4110] = function(ctx, st)
  local p = player()
  if not p then return end
  local a = U(ctx, "alerts")
  local etat = R(ctx, "state", "player")
  ctx.check(a.alerts - st.alerts0.alerts == 1 and a.loss_notes == st.alerts0.loss_notes and etat.stats.lost - st.lost0 == 3
    and etat.used == st.used_k - 3,
    "(l) 3 pertes dans le meme tick : une seule alerte, points rendus, bilan pas encore ecrit",
    string.format("alertes +%d, bilans +%d, pertes +%d, points %d -> %d", a.alerts - st.alerts0.alerts, a.loss_notes - st.alerts0.loss_notes,
      etat.stats.lost - st.lost0, st.used_k, etat.used))
end

steps[4300] = function(ctx, st)
  local p = player()
  if not p then return end
  local a = U(ctx, "alerts")
  ctx.check(a.loss_notes - st.alerts0.loss_notes == 1, "(l) le bilan des pertes est ecrit quand elles cessent (une seule fois)",
    string.format("bilans +%d", a.loss_notes - st.alerts0.loss_notes))
  -- (m) réglage maître éteint : l'outil ne donne aucun ordre
  local etat = R(ctx, "state", "player")
  local o0 = etat.stats.ordered
  ctx.call("war_setting", "fo-war-robots", false)
  tool(ctx, p, "alt", TOOL, X0 + 30, Y0 + 30, 0)
  local o1 = R(ctx, "state", "player").stats.ordered
  ctx.call("war_setting", "fo-war-robots", true)
  tool(ctx, p, "alt", TOOL, X0 + 30, Y0 + 30, 0)
  local o2 = R(ctx, "state", "player").stats.ordered
  ctx.check(o1 == o0 and o2 > o1, "(m) reglage maitre eteint : l'outil ne donne aucun ordre ; rallume, il en donne",
    string.format("ordres %d -> %d (eteint) -> %d (allume)", o0, o1, o2))
end

---------------------------------------------------------------------------------------------------
return {
  description = "RB-2 : interface des robots (panneau de l'atelier, onglet Armee), outils d'ordre et de ralliement, alertes",
  base = nil,
  check_tick = CHECK,
  shots_delay = CHECK + 60,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(X0 - 40, Y0 - 25, X0 + 100, Y0 + 95, "grass-1")
    for _, e in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 160, Y0 - 160 }, { X0 + 200, Y0 + 200 } } })) do e.destroy() end
    game.map_settings.enemy_expansion.enabled = false
    ctx.power(X0 + 10, Y0)
    st.prototypes = game.entity_prototypes["fo-robot-workshop"] ~= nil and game.item_prototypes[TOOL] ~= nil
      and game.item_prototypes[RALLY] ~= nil and game.shortcut_prototypes ~= nil
    if not st.prototypes then
      ctx.fail("prototypes du lot presents (atelier, outil d'ordre, outil de ralliement)")
      return
    end
    ctx.check(game.shortcut_prototypes[TOOL] ~= nil, "raccourci « Armee » declare", tostring(game.shortcut_prototypes[TOOL]))
    ctx.check(game.item_prototypes[TOOL].type == "selection-tool" and game.item_prototypes[RALLY].type == "selection-tool",
      "les deux outils sont des outils de selection charges par le jeu")
    st.w = s.create_entity({ name = "fo-robot-workshop", position = { X0 + 0.5, Y0 + 0.5 }, force = "player", raise_built = true })
    st.w.set_recipe("fo-robot-make-" .. TROTTE)
    garnir(s, st.w, "player", { { "engine-unit", 60 }, { "steel-plate", 132 } })
    -- persistance (a) : file et ralliement écrits à la création
    R(ctx, "set_keep", st.w.unit_number, TROTTE, 5)
    R(ctx, "set_rally", st.w.unit_number, X0 + 3, Y0 + 20)
    ctx.log(string.format("atelier %s pose, file et ralliement ecrits", tostring(st.w.unit_number)))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.prototypes then return end
    local fn = steps[e.tick]
    if fn then fn(ctx, st) end
    -- sans joueur : « maintenir 2 » posé à la main, vérifié au tick 2300 par (e) comme avec joueur
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.prototypes then return end
    local ok, why = R(ctx, "check")
    local etat = R(ctx, "state", "player")
    ctx.check(ok == true and etat.stats.create_failed == 0, "registre coherent, aucun echec de creation",
      string.format("coherent=%s (%s), echecs %d, creees %d, pertes %d, ordonnees %d", tostring(ok), tostring(why), etat.stats.create_failed,
        etat.stats.created, etat.stats.lost, etat.stats.ordered))
    if player() then
      ctx.check((st.shots or 0) == 3, "3 captures demandees", tostring(st.shots))
    else
      ctx.log("session sans joueur : interface, outils et alertes non jouees")
    end
  end,

  shots = function(ctx, add)
    add("atelier-et-robots", X0 + 8, Y0 + 10, 1, 0)
  end,
}
