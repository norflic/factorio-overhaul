--[[
  Lot DEBUG-CERVEAU : banc HORS JEU du côté moteur de la vue « Cerveau » (script/debug/*.lua) sur un MOTEUR SIMULÉ minimal (équipe, plan
  directeur, surface, joueur, interface graphique et rendu factices). Il ne prouve rien du moteur réel (rendu, interface, styles : à voir sur
  capture) ; il prouve la logique : recensement, relevé par tranches, lectures du cerveau, écarts, tâches, décisions, rendu appelé pour le
  seul joueur, nettoyage à la fermeture, coût en instructions. Lancement, depuis la racine du mod :
    lua5.2 tests/debug_cerveau_vue_test.lua
  Sections :
     1. ouverture, relevé complet, couleurs et écarts des zones d'une faction ;
     2. rien ne tourne sans spectateur ; la vue n'écrit RIEN dans l'état des décisions (copie profonde avant / après) ;
     3. rendu : un rectangle par zone dessinée, pour le seul joueur, détruit au redessin et à la fermeture ;
     4. panneau : onglets, liste, détail, honnêteté (« n'existe pas dans le cerveau », « jamais lu ») ;
     5. équipe du joueur, changement d'équipe, réglage « écarts seuls » ;
     6. coût en INSTRUCTIONS d'un redessin et d'une tranche (60 zones).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end

---------------------------------------------------------------------------------------------------
-- Moteur simulé
---------------------------------------------------------------------------------------------------
log = function() end
local ES = { working = 1, no_power = 2, low_power = 3, no_fuel = 4, no_ingredients = 5, full_output = 6, waiting_for_space_in_destination = 7, normal = 8 }
defines = { entity_status = ES, events = { on_lua_shortcut = 101, on_gui_click = 102, on_gui_selection_state_changed = 103, on_gui_closed = 104,
  on_player_left_game = 105, on_player_removed = 106, on_selected_entity_changed = 107, on_runtime_mod_setting_changed = 108 } }
local nth, evs, cmds, remotes = {}, {}, {}, {}
package.loaded["script.core.events"] = {
  on = function(id, fn) evs[id] = evs[id] or {} table.insert(evs[id], fn) end,
  on_nth_tick = function(n, fn) nth[n] = nth[n] or {} table.insert(nth[n], fn) end,
}
local STORE = {}
package.loaded["script.core.storage"] = {
  declare = function(name, init) STORE[name] = STORE[name] or { _init = init } end,
  ns = function(name) local s = STORE[name] if not s then error("espace inconnu " .. name) end s.v = s.v or s._init() return s.v end,
}
package.loaded["script.team.reseau_vivant"] = { PERIOD = 1200 }
-- l'anneau (script/debug/anneau.lua) est le vrai module : son espace de stockage est déclaré plus bas avec les autres
commands = { add_command = function(name, help, fn) cmds[name] = fn end }
remote = { add_interface = function(name, t) remotes[name] = t end }
local PSET = { ["fo-dbg-cerveau-textes"] = { value = true }, ["fo-dbg-cerveau-ecarts-seuls"] = { value = false } }
settings = { get_player_settings = function() return PSET end }

-- rendu factice
local R = { next = 1, live = {}, calls = {} }
rendering = {
  is_valid = function(id) return R.live[id] == true end,
  destroy = function(id) R.live[id] = nil end,
}
-- Paramètres acceptés par le moteur (doc-html/runtime-api.json, LuaRendering) : un autre nom lève une erreur dans le moteur.
local DRAW_OK = {
  draw_rectangle = { "color", "draw_on_ground", "filled", "forces", "left_top", "left_top_offset", "only_in_alt_mode", "players", "right_bottom",
    "right_bottom_offset", "surface", "time_to_live", "visible", "width" },
  draw_line = { "color", "dash_length", "dash_offset", "draw_on_ground", "forces", "from", "from_offset", "gap_length", "only_in_alt_mode", "players", "surface",
    "time_to_live", "to", "to_offset", "visible", "width" },
  draw_circle = { "color", "draw_on_ground", "filled", "forces", "only_in_alt_mode", "players", "radius", "surface", "target", "target_offset",
    "time_to_live", "visible", "width" },
  draw_text = { "alignment", "color", "draw_on_ground", "font", "forces", "only_in_alt_mode", "orientation", "players", "scale", "scale_with_zoom",
    "surface", "target", "target_offset", "text", "time_to_live", "use_rich_text", "vertical_alignment", "visible" },
}
for _, kind in ipairs({ "draw_rectangle", "draw_circle", "draw_text", "draw_line" }) do
  local ok = {}
  for _, k in ipairs(DRAW_OK[kind]) do ok[k] = true end
  rendering[kind] = function(p)
    for k in pairs(p) do if not ok[k] then error(kind .. " : parametre '" .. k .. "' inconnu") end end -- contrôle seul : l'ordre ne compte pas
    local id = R.next
    R.next = R.next + 1
    R.live[id] = true
    R.calls[#R.calls + 1] = { kind = kind, p = p, id = id }
    return id
  end
end

-- interface graphique factice
-- Champs que le moteur accepte à la création, par type (doc-html/runtime-api.json, LuaGuiElement.add : paramètres communs + groupes de type).
-- Un champ hors de cette liste LÈVE une erreur dans le moteur : le faux la lève aussi (c'est ainsi que « direction » d'un scroll-pane est apparu).
local ADD_COMMON = { type = true, name = true, caption = true, tooltip = true, enabled = true, visible = true, ignored_by_interaction = true,
  style = true, tags = true, index = true, anchor = true, elem_tooltip = true }
local ADD_BY_TYPE = { flow = { direction = true }, frame = { direction = true }, ["scroll-pane"] = { horizontal_scroll_policy = true, vertical_scroll_policy = true },
  ["drop-down"] = { items = true, selected_index = true }, tab = { badge_text = true }, button = { auto_toggle = true, mouse_button_filter = true, toggled = true },
  ["tabbed-pane"] = {}, label = {}, ["empty-widget"] = {}, screen = {} }
local function check_spec(spec)
  local allowed = ADD_BY_TYPE[spec.type]
  if allowed == nil then error("type d'element non prevu par le faux : " .. tostring(spec.type)) end
  for k in pairs(spec) do -- contrôle seul : l'ordre ne compte pas
    if not ADD_COMMON[k] and not allowed[k] then error("champ '" .. k .. "' non applicable au type '" .. spec.type .. "'") end
  end
end
local function new_el(spec, parent)
  check_spec(spec)
  local el = { valid = true, children = {}, style = {}, parent = parent, tags = spec.tags }
  for k, v in pairs(spec) do el[k] = v end -- recopie des champs de la description (copie : l'ordre ne compte pas)
  el.style_name, el.style = spec.style, {} -- dans le moteur, `style` d'une description est un nom, puis l'élément porte un objet de style
  -- Règle du moteur (LuaGuiElement.add) : deux enfants d'un même parent ne portent jamais le même nom non vide ; le moteur lève alors
  -- « Gui element with name X already present in the parent element. » (crash du DC, partie 0.6.96, panneau.lua:220 fill_list).
  el.add = function(s)
    if s.name ~= nil and s.name ~= "" then
      for _, c in ipairs(el.children) do
        if c.valid and c.name == s.name then error("Gui element with name " .. s.name .. " already present in the parent element.") end
      end
    end
    local c = new_el(s, el) el.children[#el.children + 1] = c return c
  end -- méthodes du moteur : liées à l'objet (appel par point)
  el.clear = function() el.children = {} end
  el.destroy = function()
    el.valid = false
    if parent then for i, c in ipairs(parent.children) do if c == el then table.remove(parent.children, i) break end end end
  end
  el.add_tab = function(tab, content) tab.content = content end
  el.force_auto_center = function() end
  return el
end
local function new_player(index)
  local screen = new_el({ type = "screen" })
  local p = { index = index, valid = true, connected = true, position = { x = 0, y = 0 }, surface = { name = "nauvis" }, gui = { screen = nil }, toggled = {} }
  p.gui.screen = setmetatable({}, { __index = function(_, name)
    for _, c in ipairs(screen.children) do if c.name == name and c.valid then return c end end
    return nil
  end })
  p.gui.screen.add = function(spec) return screen.add(spec) end
  p.set_shortcut_toggled = function(name, on) p.toggled[name] = on end
  p._screen = screen
  return p
end
local P1 = new_player(1)
local players = { [1] = P1 }
game = { tick = 100000, get_player = function(i) return players[i] end, connected_players = { P1 } }

---------------------------------------------------------------------------------------------------
-- Équipe simulée : plan directeur, avant-poste, tableau, cerveau
---------------------------------------------------------------------------------------------------
local ents_of = {}   -- par zone : liste d'entités factices { type, status, x, y }
local scans = 0
local surface = {
  find_entities_filtered = function(a)
    scans = scans + 1
    local out = {}
    local x0, y0, x1, y1 = a.area[1][1], a.area[1][2], a.area[2][1], a.area[2][2]
    for _, e in ipairs(ents_of) do
      if e.position.x >= x0 and e.position.x <= x1 and e.position.y >= y0 and e.position.y <= y1 then out[#out + 1] = e end
    end
    return out
  end,
}
local function ent(x, y, ty, st) ents_of[#ents_of + 1] = { valid = true, position = { x = x, y = y }, type = ty, status = ES[st] } end
local function part(ox, oy, w, h, kind) return { ox = ox, oy = oy, w = w, h = h, kind = kind or "module", key = "k" } end

-- projet 1 : fonderie finie, 4 fours qui travaillent (vert) ; lu par le cerveau (courant bon, débit 40/60)
for i = 1, 4 do ent(10 + i * 2, 10, "furnace", "working") end
-- projet 2 : module fini, 3 assembleurs sans entrée (rouge) ; le cerveau croit que ça marche
for i = 1, 3 do ent(50 + i * 3, 10, "assembling-machine", "no_ingredients") end
-- projet 4 : bande du champ finie, 2 foreuses dont une sortie pleine, un bras sans courant (orange) ; JAMAIS lue
ent(100, 10, "mining-drill", "working") ent(103, 10, "mining-drill", "waiting_for_space_in_destination") ent(106, 10, "inserter", "no_power")
-- projet 5 : centrale finie, une chaudière qui travaille ; lue par la santé
ent(150, 10, "boiler", "working")
-- avant-poste : une foreuse sans combustible et un four qui travaille
ent(200, 200, "mining-drill", "no_fuel") ent(202, 200, "furnace", "working")

local NOW = game.tick
local f = {
  id = 7, key = "scarlet", force = "enemy_7", hq = { valid = true, surface = surface }, last_think = NOW - 150,
  outposts = { [1] = { id = 1, kind = "iron", pos = { x = 200, y = 200 }, drills = 2 } },
  build = {
    order = { 1, 2, 3, 4, 5, 6 },
    sante = { next = NOW + 1200 - 300, healthy = true, last_why = "" },
    projects = {
      [1] = { id = 1, state = "fini", parts = { part(10, 5, 12, 10) }, ents = { { built = true }, { built = true } }, spec = { gen = "smelter", product = "iron-plate" }, prio = 55 },
      [2] = { id = 2, state = "fini", parts = { part(50, 5, 12, 10) }, ents = { { built = true } }, spec = { gen = "assembler" }, prio = 55 },
      [3] = { id = 3, state = "chantier", parts = { part(80, 5, 8, 8) }, ents = { { built = true }, { built = false }, { built = false } }, spec = { gen = "assembler" }, prio = 55 },
      [4] = { id = 4, state = "fini", parts = { part(98, 5, 12, 10) }, ents = { { built = true } }, spec = { champ = { pr = 1 } }, prio = 52 },
      [5] = { id = 5, state = "fini", parts = { part(145, 5, 8, 10, "centrale") }, ents = { { built = true } }, spec = { gen = "steam" }, prio = 60 },
      [6] = { id = 6, state = "refuse", parts = {}, ents = {}, spec = {}, reason = "place" },
    },
  },
  team = {
    mq = { reads = { [1] = { power = true, read_tick = NOW - 2400 }, [2] = { power = true, read_tick = NOW - 1800 } }, res = { starved = {} } },
    ia3e = { last_min = math.floor(NOW / 3600),
      mods = { { id = 1, product = "iron-plate", state = "fini", rate_nom = 60, rate_meas = 40 }, { id = 2, product = "gear", state = "fini", rate_nom = 30, rate_meas = 25 } },
      logs = { { tick = NOW - 6000, text = "module 'gear' FINI" } } },
    board = { tasks = {
      ["service:1"] = { key = "service:1", kind = "service", prio = 95, outpost = 1 },
      ["ia1d:2:fill:1"] = { key = "ia1d:2:fill:1", kind = "carry", prio = 70, worker = 5, ia1d = { pid = 2, mode = "fill" } },
      ["mine:iron"] = { key = "mine:iron", kind = "mine", prio = 45, resource = "iron" },
    } },
    capi = { open = { { key = "couvrir:iron", kind = "couvrir", exec = "module", item = "iron-plate", n = 60, n_left = 30, opened = NOW - 9000, missing = { { "fast-inserter", 4 } } } },
      done = { { key = "chaine:gear", kind = "chaine", exec = "module", state = "fini", closed = NOW - 12000 } }, refused = { ["ouvrir:copper"] = NOW - 3000 } },
    capital = { current = { key = "gun-12" }, history = { { key = "gun-11", tick = NOW - 20000 } } },
  },
}
local pteam = nil
STORE["war"] = { v = { factions = { [7] = f }, by_force = {} } }
STORE["debug_cerveau_anneau"] = { v = { v = 1, rings = {} } }
STORE["pteam"] = { v = { team = pteam } }

local State = require("script.faction.state")
local Cv = require("script.debug.cerveau")
check(cmds["fo-cerveau"] ~= nil, "commande /fo-cerveau enregistrée")
check(remotes["fo-dbg-cerveau"] ~= nil, "interface distante enregistrée")
check(#nth[Cv.SLICE] == 1 and #nth[Cv.REFRESH] == 1, "un abonnement par cadence")

local function deepcopy(v, seen)
  if type(v) ~= "table" then return v end
  seen = seen or {}
  if seen[v] then return seen[v] end
  local c = {}
  seen[v] = c
  for k, x in pairs(v) do c[deepcopy(k, seen)] = deepcopy(x, seen) end -- copie : l'ordre ne compte pas
  return c
end
local function ser(v, depth)
  depth = depth or 0
  if type(v) ~= "table" then return tostring(v) end
  local ks = {}
  for k in pairs(v) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) if type(a) ~= type(b) then return type(a) < type(b) end return a < b end)
  local out = {}
  for _, k in ipairs(ks) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k], depth + 1) end
  return "{" .. table.concat(out, ",") .. "}"
end
local function run_slices(n, tick)
  for i = 1, n do for _, fn in ipairs(nth[Cv.SLICE]) do fn({ tick = tick + i * Cv.SLICE }) end end
end
local function run_refresh(tick) for _, fn in ipairs(nth[Cv.REFRESH]) do fn({ tick = tick }) end end

section("0. anneau borne")
do
  local An = require("script.debug.anneau")
  local g = { key = "borne" }
  for i = 1, 50 do An.note(g, i, { "k" .. i }, { { "r" .. i, string.rep("x", 500) } }) end
  local ring = An.get("borne")
  check(#ring == An.MAX, "l'anneau est borne a " .. An.MAX .. " entrees : " .. #ring)
  check(ring[#ring].k == "r50" and #ring[#ring].r == An.WHY_MAX, "le plus recent est garde, la raison coupee a " .. An.WHY_MAX)
  check(ring[1].t >= 34, "les plus anciens sont sortis")
  check(#An.get("inconnue") == 0, "equipe sans anneau : liste vide")
  -- le meme refus repete est rafraichi, pas empile
  local h = { key = "rep" }
  An.note(h, 10, {}, { { "a", "porte" }, { "b", "plafond" } })
  An.note(h, 20, {}, { { "a", "porte" } })
  local r = An.get("rep")
  check(#r == 2 and r[2].k == "a" and r[2].t == 20 and r[1].k == "b", "refus identique rafraichi (date du jour, remis en dernier), non empile")
  An.note(h, 30, {}, { { "a", "autre raison" } })
  check(#An.get("rep") == 3, "meme cle, autre raison : nouvelle entree")
  local big = {}
  for i = 1, 40 do big[i] = { "c" .. i, "r" } end
  local g2 = { key = "gros" }
  check(An.note(g2, 1, {}, big) == An.PER_NOTE, "au plus PER_NOTE entrees par decision")
end

section("2a. rien ne tourne sans spectateur")
scans = 0
run_slices(20, NOW)
run_refresh(NOW)
check(scans == 0, "aucun relevé du moteur sans spectateur")
check(#R.calls == 0, "aucun rendu sans spectateur")

section("1. ouverture et relevé complet")
-- l'anneau de la capitalisation : un ordre envoyé et un refus AVEC raison (crochet de decide_finish)
local An = require("script.debug.anneau")
check(An.note(f, NOW - 2000, { "couvrir:iron(module x60)" }, { { "ouvrir:copper", "porte L6 : transport sature" } }) == 2, "anneau : 2 entrees ajoutees")
local before = deepcopy({ f = f })
check(Cv.open(P1, 7) == true, "ouverture de la vue pour la faction 7")
check(P1.toggled["fo-dbg-cerveau"] == true, "bouton de la barre allumé")
run_slices(8, NOW)
local state = remotes["fo-dbg-cerveau"].state(1)
check(state and state.n == 6, "recensement : 5 projets (le refusé est écarté) + 1 avant-poste = 6 zones, vu " .. tostring(state and state.n))
local by = {}
for _, l in ipairs(state.lignes) do by[l.key] = l end
check(by.p1 and by.p1.color == "vert" and by.p1.measured, "p1 fonderie : vert, mesuré")
check(by.p1.ecart == "accord", "p1 : le cerveau (lecture + débit) concorde : " .. tostring(by.p1.ecart))
check(by.p2 and by.p2.color == "rouge" and by.p2.cause == "entree", "p2 module : rouge, entrée vide")
check(by.p2.ecart == "croit_marche" and by.p2.sev == "alerte", "p2 : le cerveau croit que ça marche (courant bon, quais) alors que rouge : " .. tostring(by.p2.ecart))
check(by.p3 and by.p3.color == "gris" and by.p3.ecart == "non_applicable", "p3 en chantier : gris, non applicable")
check(by.p4 and by.p4.color == "orange", "p4 bande du champ : orange (sortie pleine + bras sans courant), vu " .. tostring(by.p4 and by.p4.color))
check(by.p4.ecart == "jamais_lu", "p4 : jamais lue par le cerveau : " .. tostring(by.p4.ecart))
check(by.p5 and by.p5.color == "vert" and by.p5.ecart == "accord", "p5 centrale : vert, santé lue il y a 5 s")
check(by.o1 and by.o1.color == "rouge" and by.o1.cause == "combustible" or (by.o1 and by.o1.color == "orange"), "o1 avant-poste : foreuse sans combustible (dégradé ou arrêté), vu " .. tostring(by.o1 and by.o1.color) .. "/" .. tostring(by.o1 and by.o1.cause))
check(by.o1.ecart == "lu_sans_verdict", "o1 : lu à chaque pensée, verdict non conservé : " .. tostring(by.o1.ecart))
check(by.p6 == nil, "projet refusé : absent")

section("2b. la vue n'écrit rien dans l'état des décisions")
check(ser(before.f.build) == ser(f.build) and ser(before.f.team) == ser(f.team) and ser(before.f.outposts) == ser(f.outposts), "f.build, f.team, f.outposts inchangés après l'ouverture et les relevés")

section("3. rendu")
R.calls = {}
run_refresh(NOW + 60)
local rects, texts, circles = 0, 0, 0
local all_p1 = true
for _, c in ipairs(R.calls) do
  if c.kind == "draw_rectangle" then rects = rects + 1 elseif c.kind == "draw_text" then texts = texts + 1 else circles = circles + 1 end
  if not (c.p.players and c.p.players[1] == 1 and #c.p.players == 1) then all_p1 = false end
end
check(all_p1, "tout le rendu est propre au joueur 1")
check(texts == 6 and rects >= 6, "6 zones dessinées avec leur texte : " .. texts .. " textes, " .. rects .. " rectangles")
check(circles >= 2, "disque d'alerte pour les écarts (p2, p4, o1) : " .. circles)
local live = 0
for _ in pairs(R.live) do live = live + 1 end
R.calls = {}
local first_live = live
run_refresh(NOW + 120)
live = 0
for _ in pairs(R.live) do live = live + 1 end
check(live == first_live, "le redessin détruit les anciens objets (même nombre vivant : " .. live .. ")")
local v = STORE["debug_cerveau"].v.viewers[1]
local has_sel = false
for _, c in ipairs(R.calls) do if c.kind == "draw_rectangle" and c.p.width == 5 then has_sel = true end end
check(has_sel, "la zone retenue (alerte la plus grave) a un cadre épais")

section("4. panneau")
local frame = P1.gui.screen["fo_dbg_frame"]
check(frame ~= nil, "fenêtre créée")
local function find(el, name)
  for _, ch in ipairs(el.children) do
    if ch.name == name then return ch end
    local r = find(ch, name)
    if r then return r end
  end
end
local function count_captions(el, fn, acc)
  acc = acc or { n = 0 }
  for _, ch in ipairs(el.children) do
    if fn(ch) then acc.n = acc.n + 1 end
    count_captions(ch, fn, acc)
  end
  return acc.n
end
local list = find(frame, "fo_dbg_list")
check(list and #list.children == 6, "liste : 6 lignes de zones, vu " .. tostring(list and #list.children))
check(list.children[1].tags.key == "p2" or list.children[1].tags.key == "p4" or list.children[1].tags.key == "o1", "la première ligne est une alerte")
local detail = find(frame, "fo_dbg_detail")
local function caption_text(c)
  if type(c) == "table" then return tostring(c[1]) end
  return tostring(c)
end
local function all_captions(el, out)
  out = out or {}
  for _, ch in ipairs(el.children) do
    if ch.caption ~= nil then out[#out + 1] = caption_text(ch.caption) .. ((type(ch.caption) == "table" and ch.caption[2] and type(ch.caption[2]) == "table") and ("|" .. tostring(ch.caption[2][1])) or "") end
    all_captions(ch, out)
  end
  return out
end
local dcap = table.concat(all_captions(detail), "\n")
check(dcap:find("detail%-ia", 1) ~= nil, "détail : bloc « ce que l'IA en sait »")
check(dcap:find("charbon_tapis") ~= nil or dcap:find("detail%-amelioration") ~= nil, "détail : améliorations listées")
local am = find(frame, "fo_dbg_am")
local amcap = table.concat(all_captions(am), "\n")
local absent_n = 0
for _, c in ipairs(am.children) do
  if type(c.caption) == "table" and c.caption[1] == "fo-dbg-cerveau.am-ligne" and type(c.caption[3]) == "table" and c.caption[3][1] == "fo-dbg-cerveau.amstate-absente" then absent_n = absent_n + 1 end
end
check(absent_n == 2, "exactement 2 absences affichées (charbon -> tapis, bras -> répartiteur) : " .. absent_n)
local dec = find(frame, "fo_dbg_dec")
check(#dec.children >= 5, "décisions : ordre en cours, ordre fini, refus, module, capital : " .. #dec.children)
local refus_line = false
for _, c in ipairs(dec.children) do if type(c.caption) == "table" and type(c.caption[3]) == "table" and c.caption[3][1] == "fo-dbg-cerveau.decision-refus" then refus_line = true end end
check(refus_line, "le refus est affiché (clé decision-refus), avec sa raison")
local raison_line = false
for _, c in ipairs(dec.children) do if type(c.caption) == "table" and tostring(c.caption[4]):find("porte L6 : transport sature", 1, true) then raison_line = true end end
check(raison_line, "la RAISON du refus (porte L6 : transport sature) vient de l'anneau")
local sans_line = false
for _, c in ipairs(dec.children) do if type(c.caption) == "table" and type(c.caption[3]) == "table" and c.caption[3][1] == "fo-dbg-cerveau.decision-refus_sans_raison" then sans_line = true end end
check(not sans_line, "un refus connu de l'anneau n'est pas redit sans raison")
-- clic sur une zone
local btn = nil
for _, ch in ipairs(list.children) do if ch.tags.key == "p1" then btn = ch end end
for _, fn in ipairs(evs[defines.events.on_gui_click]) do fn({ element = btn, player_index = 1 }) end
check(STORE["debug_cerveau"].v.viewers[1].sel == "p1", "clic sur p1 : zone retenue")
detail = find(P1.gui.screen["fo_dbg_frame"], "fo_dbg_detail")
local sel_title = detail.children[1].caption
check(sel_title[3] == "p1", "le détail montre p1")
local tasks_lines = 0
for _, ch in ipairs(detail.children) do if type(ch.caption) == "table" and ch.caption[1] == "fo-dbg-cerveau.detail-tache" then tasks_lines = tasks_lines + 1 end end
check(tasks_lines == 0, "p1 : aucune tâche (le tableau ne la cite pas)")
Cv.refresh_one(P1, STORE["debug_cerveau"].v, STORE["debug_cerveau"].v.viewers[1], game.tick)
for _, ch in ipairs(list.children) do if ch.tags.key == "p2" then btn = ch end end
for _, fn in ipairs(evs[defines.events.on_gui_click]) do fn({ element = btn, player_index = 1 }) end
detail = find(P1.gui.screen["fo_dbg_frame"], "fo_dbg_detail")
tasks_lines = 0
for _, ch in ipairs(detail.children) do if type(ch.caption) == "table" and ch.caption[1] == "fo-dbg-cerveau.detail-tache" then tasks_lines = tasks_lines + 1 end end
check(tasks_lines == 1, "p2 : la tâche de remplissage du quai (prise) apparaît : " .. tasks_lines)
local ia_lines = 0
for _, ch in ipairs(detail.children) do if type(ch.caption) == "table" and ch.caption[1] == "fo-dbg-cerveau.detail-lecture" then ia_lines = ia_lines + 1 end end
check(ia_lines == 2, "p2 : deux lectures du cerveau citées (manque, débit) : " .. ia_lines)

section("5. équipe du joueur, changement d'équipe, réglage")
Cv.close(P1)
check(P1.gui.screen["fo_dbg_frame"] == nil, "fermeture : fenêtre détruite")
local alive = 0
for _ in pairs(R.live) do alive = alive + 1 end
check(alive == 0, "fermeture : tous les objets de rendu détruits (" .. alive .. ")")
check(STORE["debug_cerveau"].v.open_n == 0 and next(STORE["debug_cerveau"].v.snaps) == nil, "fermeture de la dernière vue : relevé effacé")
check(P1.toggled["fo-dbg-cerveau"] == false, "bouton éteint")
Cv.open(P1)
check(STORE["debug_cerveau"].v.viewers[1].fid == 7, "sans équipe du joueur : la première faction observable")
STORE["pteam"].v.team = { id = "player", key = "player", force = "player", is_player = true, build = nil, outposts = {}, team = {} }
Cv.close(P1)
Cv.open(P1)
check(STORE["debug_cerveau"].v.viewers[1].fid == "player", "avec une équipe du joueur : elle est observée d'abord")
run_slices(3, NOW)
check(remotes["fo-dbg-cerveau"].state(1).n == 0, "équipe sans plan directeur : aucune zone, sans erreur")
local frame2 = P1.gui.screen["fo_dbg_frame"]
local dd = find(frame2, "fo_dbg_force")
check(#dd.items == 2, "liste d'équipes : vous + 1 faction")
-- changement d'équipe par la liste
dd.selected_index = 2
for _, fn in ipairs(evs[defines.events.on_gui_selection_state_changed]) do fn({ element = dd, player_index = 1 }) end
check(STORE["debug_cerveau"].v.viewers[1].fid == 7, "liste déroulante : retour à la faction 7")
PSET["fo-dbg-cerveau-ecarts-seuls"].value = true
run_slices(10, NOW)
R.calls = {}
run_refresh(NOW + 300)
local drawn = 0
for _, c in ipairs(R.calls) do if c.kind == "draw_text" then drawn = drawn + 1 end end
check(drawn == 3, "réglage « écarts seuls » : 3 zones dessinées (p2, p4, o1), vu " .. drawn)
PSET["fo-dbg-cerveau-ecarts-seuls"].value = false
PSET["fo-dbg-cerveau-textes"].value = false
R.calls = {}
run_refresh(NOW + 360)
drawn = 0
for _, c in ipairs(R.calls) do if c.kind == "draw_text" then drawn = drawn + 1 end end
check(drawn == 0, "réglage « textes » éteint : aucun texte")
PSET["fo-dbg-cerveau-textes"].value = true

section("6. coût en instructions")
-- 60 zones : 30 fonderies finies avec 4 fours chacune, 30 projets en chantier
local f2 = { id = 8, key = "azure", force = "enemy_8", hq = { valid = true, surface = surface }, outposts = {}, last_think = NOW,
  build = { order = {}, projects = {} }, team = { mq = { reads = {}, res = { starved = {} } }, ia3e = { mods = {}, last_min = 0 }, board = { tasks = {} } } }
for i = 1, 60 do
  f2.build.order[i] = i
  f2.build.projects[i] = { id = i, state = i % 2 == 0 and "fini" or "chantier", parts = { part(10 + i * 14, 5, 12, 10) }, ents = {}, spec = { gen = "smelter" } }
  if i % 2 == 0 then for k = 1, 4 do ent(10 + i * 14 + k * 2, 10, "furnace", "working") end end
end
STORE["war"].v.factions[8] = f2
Cv.close(P1)
Cv.open(P1, 8)
run_slices(70, NOW)
local count = 0
debug.sethook(function() count = count + 1000 end, "", 1000)
run_refresh(NOW + 600)
debug.sethook()
check(count <= 1500000, "un redessin de 60 zones : " .. count .. " instructions (<= 1500000)")
print("  redessin de 60 zones : environ " .. count .. " instructions")
count = 0
debug.sethook(function() count = count + 1000 end, "", 1000)
run_slices(1, NOW + 700)
debug.sethook()
check(count <= 200000, "une tranche (1 zone relevée) : " .. count .. " instructions (<= 200000)")
print("  une tranche : moins de " .. math.max(count, 1000) .. " instructions (granularité du compteur : 1000)")
Cv.close(P1)

section("7. cas du DC (fonderie de 30 fours a 40 %) et lectures douteuses (revue-s)")
do
  local Lec = require("script.debug.lecture")
  local Lg = require("shared.debug.lignes")
  ents_of = {}
  for i = 1, 30 do ent(10 + (i % 15) * 2, 10 + math.floor(i / 15) * 3, "furnace", i <= 12 and "working" or "no_ingredients") end
  local f3 = { id = 9, key = "azure", force = "enemy_9", hq = { valid = true, surface = surface }, outposts = {}, last_think = NOW,
    build = { order = { 1 }, projects = { [1] = { id = 1, state = "fini", parts = { part(5, 5, 40, 12) }, ents = {}, spec = { gen = "smelter", product = "copper-plate" } } },
      sante = { next = NOW + 1200, healthy = false, last_why = "", decisions = 0 } },
    team = { mq = { reads = { [1] = { power = true, read_tick = NOW - 600 } }, res = { starved = {} } },
      ia3e = { last_min = math.floor(NOW / 3600), mods = { { id = 1, product = "copper-plate", state = "fini", rate_nom = 570, rate_meas = 227, finished_m = 0 } }, logs = {} },
      board = { tasks = {} } } }
  local sk = Lec.skeletons(f3)
  local z = sk[1]
  Lec.measure(f3, z, NOW)
  check(z.color == "orange" and z.cause == "entree" and z.n == 30 and z.run == 12, "fonderie de 30 fours, 12 en marche : orange, entree, 12/30 : " .. tostring(z.color) .. "/" .. tostring(z.cause) .. "/" .. tostring(z.run) .. "/" .. tostring(z.n))
  check(z.rate_meas == 227 and z.rate_nom == 570 and z.product == "copper-plate", "production attribuee et debits lus / vises")
  local lab = Lg.label(z)
  check(lab[3] == "227" and lab[4] == "570" and lab[7][2] == 12 and lab[7][3] == 30, "etiquette : 227/570 par min et 12/30 en marche, sans ouvrir de panneau")
  local rd = Lec.reads(f3, z)
  local ec = require("shared.debug.ecart").compare(rd, { color = z.color, cause = z.cause }, NOW)
  check(ec.kind == "croit_marche", "le cerveau lit courant bon + debit non nul : il croit que ca marche (ecart rendu evident) : " .. ec.kind)
  -- A : aucune machine trouvee par le cerveau (power nil) = inconnu, jamais marche
  f3.team.mq.reads[1] = { power = nil, read_tick = NOW - 600 }
  f3.team.ia3e.mods = {}
  rd = Lec.reads(f3, z)
  check(#rd == 1 and rd[1].verdict == "inconnu", "power nil : verdict inconnu (revue-s A)")
  -- D : debit nul sur un module fini depuis moins de 2 min = artefact, inconnu
  f3.team.ia3e.mods = { { id = 1, product = "copper-plate", state = "fini", rate_nom = 570, rate_meas = 0, finished_m = f3.team.ia3e.last_min } }
  f3.team.mq.reads[1] = nil
  rd = Lec.reads(f3, z)
  check(#rd == 1 and rd[1].verdict == "inconnu", "debit nul de la premiere minute : inconnu (revue-s D)")
  f3.team.ia3e.mods[1].finished_m = f3.team.ia3e.last_min - 5
  rd = Lec.reads(f3, z)
  check(rd[1].verdict == "arret" and rd[1].why == "debit_nul", "debit nul d'un module ancien : arret")
  -- PIQUAGE : f.build.piquage lu, le catalogue ne dit plus « n'existe pas » pour le repartiteur et le charbon
  f3.build.piquage = { quais = { ["1:q1"] = { verdict = "demande", cause = "ok", tick = NOW - 300 }, ["1:q2"] = { verdict = "refuse", cause = "trop_loin", tick = NOW - 100 } } }
  local facts = Lec.improvement_facts(f3)
  check(facts.bras_repartiteur and facts.bras_repartiteur.present and facts.bras_repartiteur.state == "en_cours", "piquage present : bras_repartiteur en cours")
  check(facts.charbon_tapis and facts.charbon_tapis.present, "piquage present : charbon_tapis couvert aussi (quai comme un autre)")
  check(facts.bras_repartiteur.why[1] == "fo-dbg-cerveau.pq-ligne" and facts.bras_repartiteur.why[2][1] == "fo-dbg-cerveau.pq-verdict-demande", "la raison est une chaine localisee a mots fixes")
  local prows = Lec.piquage_rows(f3, 1)
  check(#prows == 2 and prows[2].verdict == "refuse" and prows[2].cause == "trop_loin", "quais du projet 1")
  f3.build.piquage = nil
  check(Lec.improvement_facts(f3).bras_repartiteur == nil, "sans champ piquage : aucun fait (reste absente)")
  -- MINAGE-MAIN : f.team.sources.dec lu
  f3.team.sources = { dec = { ["iron-ore"] = { choix = "main", raison = "aucune_sortie", n = 0, d = 0, tick = NOW - 600, why = "libre" } } }
  local drows = Lec.decision_rows(f3)
  local found
  for _, r in ipairs(drows) do if r.kind == "source" then found = r end end
  check(found and found.ltext[3][1] == "fo-dbg-cerveau.src-choix-main" and found.ltext[4][1] == "fo-dbg-cerveau.src-raison-aucune_sortie", "decision de minage lue dans f.team.sources.dec")
  f3.team.sources = nil
  -- DEFENSE-STOCK : f.defstock.rows lu, au plus Lg.DEF_MAX lieux
  f3.defstock = { rows = {} }
  for i = 1, 10 do f3.defstock.rows[i] = { key = "l" .. i, kind = "site", have = 1, want = 3, skip = "stock", tick = NOW - 60 } end
  local n_def = 0
  for _, r in ipairs(Lec.decision_rows(f3)) do if r.kind == "defense" then n_def = n_def + 1 end end
  check(n_def == Lg.DEF_MAX, "lieux de defense : au plus " .. Lg.DEF_MAX .. " lignes sur 10 : " .. n_def)
  f3.defstock = nil
  -- AMELIORATION : f.team.capital.refus lu (decisions, niveau refuse, refus de la zone)
  f3.team.capital = { refus = { ["p1|furnace"] = { cause = "plafond-centre", tick = NOW - 30 }, ["qg|gun"] = { cause = "emprise", tick = NOW - 90 } }, history = {} }
  local n_am = 0
  for _, r in ipairs(Lec.decision_rows(f3)) do if r.kind == "amelioration_refus" then n_am = n_am + 1 end end
  check(n_am == 2, "refus d'amelioration dans les decisions : " .. n_am)
  local fa = Lec.improvement_facts(f3).niveau
  check(fa and fa.state == "refusee" and fa.why[1] == "fo-dbg-cerveau.am-refus-plafond-centre", "niveau : refusee, avec le refus le plus recent")
  local zr = Lec.am_refus_rows(f3, 1)
  check(#zr == 1 and zr[1].famille == "furnace", "refus de la zone p1 seulement")
  f3.team.capital = nil
  -- C : sante creee mais jamais relevee = aucune lecture ; relevee (healthy) = marche
  z.kind = "centrale"
  rd = Lec.reads(f3, z)
  local n_sante = 0
  for _, r in ipairs(rd) do if r.src == "sante" then n_sante = n_sante + 1 end end
  check(n_sante == 0, "sante jamais relevee : aucune lecture (revue-s C)")
  f3.build.sante.healthy = true
  rd = Lec.reads(f3, z)
  n_sante = 0
  for _, r in ipairs(rd) do if r.src == "sante" then n_sante = n_sante + 1 end end
  check(n_sante == 1, "sante relevee : une lecture")
  f3.build.sante.healthy, f3.build.sante.last_why = false, "attend la pompe"
  rd = Lec.reads(f3, z)
  local why
  for _, r in ipairs(rd) do if r.src == "sante" then why = r.why end end
  check(why == "autre", "last_why est un texte libre : la cause affichee est 'autre'")
end

section("8. PNJ (clic ou survol), blocs, entrees et sorties, liaisons (directive du DC, V2)")
do
  package.loaded["script.team.board"] = { strict_list = function(t) return t.strict end }
  package.loaded["shared.ai3.registre"] = { free = function(reg, item) return reg.free[item] or 0 end }
  local Lec = require("script.debug.lecture")
  Cv.close(P1)
  -- un bloc avec une entree et une sortie, une liaison de quai finie, une branche de piquage en chantier
  f.build.projects[1].quais = { { x = 12, y = 12, item = "coal" } }
  f.build.projects[1].outs = { { x = 20, y = 12 } }
  f.build.projects[20] = { id = 20, state = "fini", parts = {}, ents = {}, spec = { liaison = { item = "iron-plate", dock = { pid = 1, idx = 1, x = 12, y = 12 }, src = { pid = 2, idx = 1, x = 55, y = 12 } } } }
  f.build.projects[21] = { id = 21, state = "chantier", parts = {}, ents = {}, spec = { liaison = { piquage = true, item = "coal", geo = { x = 30.5, y = 5.5 }, dock = { pid = 1, idx = 1, x = 12, y = 12 } } } }
  f.build.projects[20].spec.liaison.key = "k20"
  f.build.projects[21].spec.liaison.key = "k21"
  -- une demande REFUSEE (doit se voir en rouge avec sa cause), une ligne de rapatriement, un piquage pose
  f.build.projects[22] = { id = 22, state = "refuse", reason = "ennemi a portee", parts = {}, ents = {}, spec = { liaison = { key = "k22", item = "copper-plate", dock = { pid = 1, idx = 1, x = 12, y = 14 }, src = { pid = 2, idx = 1, x = 30, y = 14 } } } }
  f.build.projects[23] = { id = 23, state = "fini", parts = { { kind = "liaison", ox = 41, oy = 21, w = 1, h = 1 } }, ents = {}, rap = { tampon_x = 41, tampon_y = 21 },
    spec = { rapatriement = { key = "r1", item = "iron-plate", src = { pid = 2, idx = 1, x = 70, y = 20 }, point = { x = 40, y = 20 } } } }
  f.build.projects[24] = { id = 24, state = "fini", parts = {}, ents = {}, spec = { liaison = { key = "k24", piquage = true, item = "transport-belt", geo = { x = 60.5, y = 30.5 }, dock = { pid = 1, idx = 1, x = 12, y = 12 } } } }
  f.build.piquage = { links = { k24 = { split = true } }, quais = {} }
  f.build.order = { 1, 2, 3, 4, 5, 6, 20, 21, 22, 23, 24 }
  local lk = Lec.links(f)
  check(#lk == 5 and lk[1].kind == "quai" and lk[2].kind == "piquage" and lk[3].status == "refuse" and lk[4].kind == "rapatriement" and lk[5].status == "actif",
    "lignes lues dans f.build : quai, piquage en chantier, REFUSEE, rapatriement, piquage pose : " .. #lk)
  local sk = Lec.skeletons(f)
  local has23 = false
  for _, z in ipairs(sk) do if z.pid == 23 and z.kind == "module" then has23 = true end end
  check(not has23, "un projet de rapatriement n'est pas un bloc 'module'")
  local dm = Lec.demo_projects({ { pid = 1, kind = "module", x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, { pid = 2, kind = "fonderie", x0 = 40, y0 = 0, x1 = 50, y1 = 10 } })
  local dl = Lec.links({ build = { order = {}, projects = {} } }, dm)
  check(#dm == 4 and #dl == 4 and dl[1].status == "actif" and dl[2].status == "refuse" and dl[3].status == "chantier" and dl[4].kind == "rapatriement",
    "lignes fictives du banc d'images : quai, refusee, piquage en chantier, rapatriement (jamais ecrites dans f.build)")
  check(#Lec.demo_projects({ { pid = 1, kind = "module", x0 = 0, y0 = 0, x1 = 1, y1 = 1 } }) == 0, "une seule zone : pas de ligne fictive")
  -- le tableau : une tache libre sans matiere, une en pause d'echec, une prise
  local t_mat = { key = "service:1", kind = "service", prio = 95, outpost = 1, strict = { { "iron-plate", 50 } } }
  local t_pause = { key = "mine:iron", kind = "mine", prio = 45 }
  local t_pris = { key = "ia1d:2:fill:1", kind = "carry", prio = 70, worker = 5, ia1d = { pid = 2, mode = "fill" } }
  f.team.board = { tasks = { ["service:1"] = t_mat, ["mine:iron"] = t_pause, ["ia1d:2:fill:1"] = t_pris }, list = { t_mat, t_pause, t_pris }, cooldown = { ["mine:iron"] = NOW + 900 } }
  f.team.reg = { free = { ["iron-plate"] = 10 } }
  local body = { valid = true, unit_number = 555, position = { x = 3, y = 4 }, get_main_inventory = function() return { get_contents = function() return { ["iron-plate"] = 12, coal = 3 } end } end }
  local agent = { id = 1, faction = 7, state = "idle", entity = body, org = { role = "executant", pole = "production" } }
  STORE["companion"] = { v = { agents = { [1] = agent }, by_unit = { [555] = 1 } } }
  check(Lec.agent_of_entity(body) == agent and Lec.agent_of_entity(nil) == nil and Lec.agent_of_entity({ valid = true, unit_number = 1 }) == nil, "corps de PNJ -> agent par le registre ; autre entite : nil")
  local npc = Lec.npc(f, agent, NOW)
  check(npc.explain.cause == "matiere" and npc.explain.item == "iron-plate" and npc.explain.need == 50 and npc.explain.free == 10, "PNJ inactif : cause = manque de matiere (iron-plate besoin 50, libre 10)")
  check(#npc.nexts == 2 and npc.nexts[1].key == "service:1" and npc.nexts[1].status == "matiere" and npc.nexts[2].status == "pause", "tâches suivantes : 2 libres (la prise est ecartee), matiere puis pause")
  check(npc.carry and npc.carry[1].item == "coal", "sac lu")
  check(npc.team_sur == nil, "sans f.team.org.sur : pas de ligne d'equipe")
  f.team.org = { sur = { last = { starved = 2, want = 3, service = 1, mine = 0 } } }
  npc = Lec.npc(f, agent, NOW)
  check(npc.team_idle == nil, "sans f.team.sources.idle : pas de ligne 'rien a faire'")
  f.team.sources = f.team.sources or {}
  f.team.sources.idle = { code = "matiere", tick = NOW - 600, n = 3 }
  npc = Lec.npc(f, agent, NOW)
  check(npc.team_idle and npc.team_idle.code == "matiere" and npc.team_idle.n == 3 and npc.team_idle.age == 600, "raison 'rien a faire' lue dans f.team.sources.idle")
  f.team.sources.idle.tick = NOW - 9000
  check(Lec.npc(f, agent, NOW).team_idle == nil, "raison perimee (plus de 2 min) : non montree")
  f.team.sources.idle = { code = "zz", tick = NOW, n = 1 }
  check(Lec.npc(f, agent, NOW).team_idle == nil, "code inconnu : non montre")
  f.team.sources.idle = nil
  check(npc.gate == nil and npc.zero_idle == nil, "sans champs ZERO-IDLE : rien")
  agent.gate_why, agent.gate_tick = "danger", NOW - 120
  f.team.zero_idle = { last = { tick = NOW - 300, libres = 4, emis = 1, restes = 3, cause = "servis" } }
  npc = Lec.npc(f, agent, NOW)
  check(npc.gate and npc.gate.why == "danger" and npc.gate.age == 120, "porte de comportement lue (agent.gate_why)")
  check(npc.zero_idle and npc.zero_idle.cause == "servis" and npc.zero_idle.restes == 3, "zero_idle lu dans f.team.zero_idle.last")
  f.team.zero_idle.last.cause = "zz"
  check(Lec.npc(f, agent, NOW).zero_idle == nil, "cause inconnue de zero_idle : non montree")
  agent.gate_why, agent.gate_tick, f.team.zero_idle = nil, nil, nil
  check(npc.team_sur and npc.team_sur.starved == 2 and npc.team_sur.want == 3, "ligne d'equipe lue dans f.team.org.sur.last")
  agent.state, agent.task, agent.steps, agent.pc = "step", { key = "ia1d:2:fill:1", kind = "carry", prio = 70, ia1d = { pid = 2, mode = "fill" } }, { { "home" }, { "goto", { x = 5, y = 6 } }, { "act", "x" } }, 2
  npc = Lec.npc(f, agent, NOW)
  check(npc.task.pid == 2 and npc.task.mode == "fill" and npc.steps.left == 2 and npc.steps.rows[1].kind == "goto" and npc.explain.cause == "en_marche", "PNJ au travail : tache, etapes restantes (2 sur 3), en marche")
  agent.state, agent.task, agent.steps, agent.pc = "idle", nil, nil, nil
  -- ouverture de la vue puis clic / survol du PNJ
  Cv.open(P1, 7)
  run_slices(12, NOW)
  P1.selected = body
  for _, fn in ipairs(evs[defines.events.on_selected_entity_changed]) do fn({ player_index = 1 }) end
  check(STORE["debug_cerveau"].v.viewers[1].npc == 1, "survol d'un PNJ : le panneau suit ce PNJ")
  local pf = P1.gui.screen["fo_dbg_pnj_frame"]
  check(pf ~= nil, "panneau du PNJ cree")
  local function flat(el, out)
    out = out or {}
    for _, ch in ipairs(el.children) do
      if ch.caption ~= nil then out[#out + 1] = ch.caption end
      flat(ch, out)
    end
    return out
  end
  local caps = flat(pf)
  local function has(key)
    for _, c in ipairs(caps) do if type(c) == "table" and c[1] == key then return c end end
    return nil
  end
  local ent = has("fo-dbg-cerveau.pnj-entete")
  check(ent and ent[4][1] == "fo-dbg-cerveau.pnj-etat-idle", "entete : etat idle")
  local cause = has("fo-dbg-cerveau.pnj-cause-matiere")
  check(cause and cause[2] == "service:1" and cause[4] == "50" and cause[5] == "10", "cause affichee : la tache qui attend, la matiere, le besoin et le libre")
  check(has("fo-dbg-cerveau.pnj-sans-tache") ~= nil, "aucune tache en cours : dit")
  local n_sv = 0
  for _, c in ipairs(caps) do if type(c) == "table" and c[1] == "fo-dbg-cerveau.pnj-suivante" then n_sv = n_sv + 1 end end
  check(n_sv == 2, "deux taches suivantes listees : " .. n_sv)
  -- rendu : entrees / sorties / liaisons
  R.calls = {}
  run_refresh(NOW + 60)
  local n_in, n_out, n_line, n_tampon, n_taprap, n_rep, n_rouge, n_cause = 0, 0, 0, 0, 0, 0, 0, 0
  local lines_dashed, lines_solid, rich_all = 0, 0, true
  for _, c in ipairs(R.calls) do
    local t = c.p.text
    if c.kind == "draw_line" then
      n_line = n_line + 1
      if c.p.dash_length then lines_dashed = lines_dashed + 1 else lines_solid = lines_solid + 1 end
      if c.p.color.r == 1 and c.p.color.g == 0.2 then n_rouge = n_rouge + 1 end
    elseif c.kind == "draw_text" and type(t) == "table" then
      if not c.p.use_rich_text then rich_all = false end
      if t[1] == "fo-dbg-cerveau.io-entree" then n_in = n_in + 1 end
      if t[1] == "fo-dbg-cerveau.io-sortie" then n_out = n_out + 1 end
      if t[1] == "fo-dbg-cerveau.lien-tampon" then n_tampon = n_tampon + 1 end
      if t[1] == "fo-dbg-cerveau.lien-tampon-rap" then n_taprap = n_taprap + 1 end
      if t[1] == "fo-dbg-cerveau.lien-repartiteur" then n_rep = n_rep + 1 end
      if t[1] == "fo-dbg-cerveau.lien-ligne" and type(t[4]) == "table" and t[4][1] == "fo-dbg-cerveau.lien-statut-cause" and t[4][3] == "ennemi a portee" then n_cause = n_cause + 1 end
    end
  end
  check(n_in >= 1 and n_out >= 1, "ENTREE et SORTIE ecrites sur le bloc : " .. n_in .. " / " .. n_out)
  check(n_line == 25 and lines_dashed == 1 and lines_solid == 24, "5 lignes (4 traits + pointes de fleche) : seule la branche en chantier est en pointille : " .. n_line .. " / " .. lines_dashed)
  check(n_rouge == 5, "la ligne REFUSEE est en rouge (trait et pointes) : " .. n_rouge)
  check(n_cause == 1, "la cause du refus est ecrite sur la ligne : " .. n_cause)
  check(n_tampon == 1 and n_taprap == 1 and n_rep == 1, "un coffre tampon (3 lignes vers le meme coffre), le tampon de rapatriement, un repartiteur pose : " .. n_tampon .. " / " .. n_taprap .. " / " .. n_rep)
  check(rich_all, "tous les textes de la carte sont dessines en texte riche (icones d'objets)")
  check(#R.calls <= 260, "objets de rendu plafonnes : " .. #R.calls)
  -- le detail du bloc cite ses liaisons
  local vv = STORE["debug_cerveau"].v.viewers[1]
  vv.sel = "p1"
  Cv.refresh_one(P1, STORE["debug_cerveau"].v, vv, NOW + 120)
  local detail = find(P1.gui.screen["fo_dbg_frame"], "fo_dbg_detail")
  local nl = 0
  for _, ch in ipairs(detail.children) do if type(ch.caption) == "table" and ch.caption[1] == "fo-dbg-cerveau.detail-liaison" then nl = nl + 1 end end
  check(nl == 4, "le detail du bloc p1 liste ses 4 liaisons (refusee comprise) : " .. nl)
  -- PNJ disparu
  body.valid = false
  Cv.refresh_one(P1, STORE["debug_cerveau"].v, vv, NOW + 180)
  local gone = false
  for _, c in ipairs(flat(P1.gui.screen["fo_dbg_pnj_frame"])) do if type(c) == "table" and c[1] == "fo-dbg-cerveau.pnj-disparu" then gone = true end end
  check(gone, "PNJ disparu : le panneau le dit")
  -- PIRE CAS mesure par debug.sethook : 60 blocs a 4 entrees et 2 sorties, 40 liaisons, PNJ regarde
  local f4 = { id = 11, key = "pire", force = "enemy_11", hq = { valid = true, surface = surface }, outposts = {}, last_think = NOW,
    build = { order = {}, projects = {} }, team = { mq = { reads = {}, res = { starved = {} } }, ia3e = { mods = {}, last_min = 0 }, board = { tasks = {}, list = {}, cooldown = {} } } }
  for i = 1, 100 do
    f4.build.order[i] = i
    if i <= 60 then
      local q, o = {}, {}
      for k = 1, 4 do q[k] = { x = 10 + i * 14 + k, y = 8, item = "coal" } end
      for k = 1, 2 do o[k] = { x = 10 + i * 14 + k, y = 14 } end
      f4.build.projects[i] = { id = i, state = i % 2 == 0 and "fini" or "chantier", parts = { part(10 + i * 14, 5, 12, 10) }, ents = {}, spec = { gen = "smelter", product = "iron-plate" }, quais = q, outs = o }
    else
      f4.build.projects[i] = { id = i, state = i % 2 == 0 and "fini" or "chantier", parts = {}, ents = {},
        spec = { liaison = { item = "iron-plate", dock = { pid = i - 60, x = 10 + (i - 60) * 14, y = 8 }, src = { pid = i - 59, x = 40 + i, y = 20 }, bus = i % 3 == 0 or nil } } }
    end
  end
  STORE["war"].v.factions[11] = f4
  Cv.open(P1, 11)
  run_slices(70, NOW)
  local vv2 = STORE["debug_cerveau"].v.viewers[1]
  P1.selected = body
  body.valid = true
  vv2.npc = nil
  for _, fn in ipairs(evs[defines.events.on_selected_entity_changed]) do fn({ player_index = 1 }) end
  R.calls = {}
  local cnt = 0
  debug.sethook(function() cnt = cnt + 1000 end, "", 1000)
  run_refresh(NOW + 1000)
  debug.sethook()
  check(#R.calls <= 260, "pire cas : objets de rendu plafonnes a 260 : " .. #R.calls)
  check(cnt <= 3000000, "pire cas (60 blocs, 40 liaisons, PNJ regarde) : " .. cnt .. " instructions par redessin (<= 3 000 000)")
  print("  pire cas : environ " .. cnt .. " instructions par redessin, " .. #R.calls .. " objets de rendu")
  Cv.close(P1)
  check(P1.gui.screen["fo_dbg_pnj_frame"] == nil, "fermeture de la vue : panneau du PNJ detruit")
end

section("7. F498 : le reglage de debogage de la partie ouvre et ferme la vue des zones du joueur qui le bascule")
do
  local GS = { ["fo-debug-render"] = { value = false } }
  settings.global = GS
  local function fire(ev) for _, fn in ipairs(evs[defines.events.on_runtime_mod_setting_changed] or {}) do fn(ev) end end
  check(evs[defines.events.on_runtime_mod_setting_changed] ~= nil, "la vue est abonnee au changement de reglage")
  if Cv.is_open(1) then Cv.close(P1) end
  GS["fo-debug-render"].value = true
  fire({ setting = "fo-debug-render", setting_type = "runtime", player_index = 1 })
  check(Cv.is_open(1), "reglage vrai par le joueur 1 : sa vue est ouverte")
  local vv = STORE["debug_cerveau"].v.viewers[1]
  check(vv ~= nil and vv.render ~= nil, "la vue ouverte a son etat de rendu")
  fire({ setting = "fo-debug-render", setting_type = "runtime", player_index = 1 })
  check(Cv.is_open(1), "un second passage a vrai ne referme pas la vue")
  GS["fo-debug-render"].value = false
  fire({ setting = "fo-war-mall-tronc", setting_type = "runtime", player_index = 1 })
  check(Cv.is_open(1), "un autre reglage ne touche pas la vue")
  fire({ setting = "fo-debug-render", setting_type = "runtime" })
  check(Cv.is_open(1), "un changement par script (sans joueur) ne touche pas la vue")
  fire({ setting = "fo-debug-render", setting_type = "runtime", player_index = 1 })
  check(not Cv.is_open(1), "reglage faux par le joueur 1 : sa vue est fermee")
  GS["fo-debug-render"].value = true
  fire({ setting = "fo-debug-render", setting_type = "runtime", player_index = 99 })
  check(not Cv.is_open(1), "un joueur inconnu ne fait rien")
end

section("9. Crash du DC (0.6.96, panneau.lua:220) : le reglage de debogage ouvre la vue sur PLUSIEURS zones, sans nom en double")
do
  local GS = { ["fo-debug-render"] = { value = false } }
  settings.global = GS
  local function fire(ev) for _, fn in ipairs(evs[defines.events.on_runtime_mod_setting_changed] or {}) do fn(ev) end end
  local Pn = require("script.debug.panneau")
  -- sans équipe du joueur, la vue s'ouvre sur la faction 7 et ses 6 zones (section 1) ; chaque ouverture relève puis redessine
  STORE["pteam"].v.team = nil
  local function open_full()
    GS["fo-debug-render"].value = true
    fire({ setting = "fo-debug-render", setting_type = "runtime", player_index = 1 })
    run_slices(8, NOW)
    local v1 = STORE["debug_cerveau"].v.viewers[1]
    v1.sig = {}
    Cv.refresh_one(P1, STORE["debug_cerveau"].v, v1, game.tick)
  end
  local function cycle(n)
    for _ = 1, n do
      open_full()
      GS["fo-debug-render"].value = false
      fire({ setting = "fo-debug-render", setting_type = "runtime", player_index = 1 })
    end
    open_full()
  end
  if Cv.is_open(1) then Cv.close(P1) end
  local ok, err = pcall(cycle, 3)
  check(ok, "trois bascules du reglage puis ouverture : aucune erreur (" .. tostring(err) .. ")")
  check(Cv.is_open(1), "la vue est ouverte")
  local lst = P1.gui.screen["fo_dbg_frame"] and find(P1.gui.screen["fo_dbg_frame"], "fo_dbg_list")
  local names, dup, keys = {}, false, 0
  for _, ch in ipairs(lst and lst.children or {}) do
    if ch.name and ch.name ~= "" then
      if names[ch.name] then dup = true end
      names[ch.name] = true
    end
    if ch.tags and ch.tags.key then keys = keys + 1 end
  end
  check(lst ~= nil and keys >= 2, "la liste porte au moins 2 zones (cas du crash) : " .. keys)
  check(not dup, "aucun nom en double parmi les lignes de la liste")
  -- un redessin force (signature effacee) refait la liste sans erreur
  local vv = STORE["debug_cerveau"].v.viewers[1]
  vv.sig = {}
  ok, err = pcall(Cv.refresh_one, P1, STORE["debug_cerveau"].v, vv, game.tick)
  check(ok, "redessin force de la liste : aucune erreur (" .. tostring(err) .. ")")
  -- clic sur la 2e ligne : la zone de ses tags est retenue
  lst = find(P1.gui.screen["fo_dbg_frame"], "fo_dbg_list")
  local b2 = nil
  for _, ch in ipairs(lst.children) do if ch.tags and ch.tags.key then if b2 == nil then b2 = false elseif b2 == false then b2 = ch end end end
  if b2 then
    for _, fn in ipairs(evs[defines.events.on_gui_click]) do fn({ element = b2, player_index = 1 }) end
    check(STORE["debug_cerveau"].v.viewers[1].sel == b2.tags.key, "clic sur la 2e ligne : sa zone (" .. tostring(b2.tags.key) .. ") est retenue")
  else
    check(false, "2e ligne introuvable")
  end
  Cv.close(P1)
  -- Mutants : le module muté remplace les fonctions du vrai (la vue garde sa référence à la table du module).
  local function mutant(name, path, old, new, ok_expected_false)
    local f = assert(io.open(path, "rb")) local src = f:read("*a") f:close()
    local i = src:find(old, 1, true)
    if not i then check(false, "mutant " .. name .. " : texte introuvable") return end
    local tbl = (path:find("panneau", 1, true)) and Pn or nil
    local saved = {}
    for k, v in pairs(tbl) do saved[k] = v end
    local m = assert(load(src:sub(1, i - 1) .. new .. src:sub(i + #old), "=" .. path))()
    for k, v in pairs(m) do tbl[k] = v end
    local refused = ok_expected_false()
    for k in pairs(m) do tbl[k] = saved[k] end
    if Cv.is_open(1) then pcall(Cv.close, P1) end
    check(refused, "mutant refuse : " .. name)
  end
  mutant("nom fixe pour chaque ligne (le crash du DC)", "script/debug/panneau.lua", "name = Panneau.ZONE_PREFIX .. i,", 'name = "fo_dbg_zone",',
    function() return not pcall(cycle, 1) end)
  mutant("prefixe sans rang (meme nom pour toutes les lignes)", "script/debug/panneau.lua", "name = Panneau.ZONE_PREFIX .. i,", "name = Panneau.ZONE_PREFIX,",
    function() return not pcall(cycle, 1) end)
end

print(string.format("[DEBUG-CERVEAU-VUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
