--[[
  Lot RB-2 JOUEUR (1/11) : banc hors jeu de l'interface et des outils des robots (shared/robots/commande.lua, la file de
  shared/robots/modele.lua, et les règles de forme de script/robots/outils.lua, script/gui/robots.lua).
    §1 file d'un atelier : « maintenir N » = une entrée ; édition (valeur bornée, place gardée, entrée neuve en queue, refus d'un
       robot inconnu, plafond de la file), cible, déplacement, recette voulue, moment sûr du changement de recette ;
    §2 zone d'un outil : centre, rayon (clic sans glisser = rayon minimal, plafond), zones illisibles ;
    §3 actions des quatre événements, ordre du moteur, rayon d'arrêt d'une troupe ;
    §4 sélection : triée, sans doublon, bornée, purgée ;
    §5 attaquer ce qui est encadré : centre de gravité et étalement des ennemis ;
    §6 tous au ralliement : l'atelier d'origine, le repli, les unités sans destination ;
    §7 alerte de pertes : une alerte par période, un bilan quand les pertes cessent ;
    §8 registre : l'atelier d'origine d'une unité ;
    §9 déterminisme : mêmes opérations dans un autre ordre d'arrivée, même résultat ;
    §10 traductions FR et EN de tout ce que le lot cite, outils et raccourci déclarés, onglet « Armée » branché ;
    §11 mutants : chaque règle faussée est vue par au moins un contrôle.
  Le moteur réel est prouvé par les scénarios « rb-ui » (ordres par les gestionnaires des outils, panneau, onglet, alerte) et les captures.
  Usage : lua5.2 tests/robots_ui_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local RO_SRC = read("shared/content/robots.lua")
local MO_SRC = read("shared/robots/modele.lua")
local CM_SRC = read("shared/robots/commande.lua")

--- Charge les trois modules depuis leurs textes (mutants) ; rend (Ro, Mo, Cm) ou (nil, erreur).
local function load_all(ro_src, mo_src, cm_src)
  local f1, e1 = load(ro_src, "=robots", "t")
  if not f1 then return nil, e1 end
  local ok1, Ro = pcall(f1)
  if not ok1 then return nil, Ro end
  local saved = package.loaded["shared.content.robots"]
  package.loaded["shared.content.robots"] = Ro
  local function mod(src, name)
    local f, e = load(src, "=" .. name, "t")
    if not f then return nil, e end
    local ok, M = pcall(f)
    if not ok then return nil, M end
    return M
  end
  local Mo, e2 = mod(mo_src, "modele")
  local Cm, e3 = mod(cm_src, "commande")
  package.loaded["shared.content.robots"] = saved
  if not Mo then return nil, e2 end
  if not Cm then return nil, e3 end
  return Ro, Mo, Cm
end

local function strip(src) return (src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")) end

local function suite(Ro, Mo, Cm)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end
  local known = { ["steam-trotter"] = true, ["other"] = true, ["third"] = true }
  local function q(...)
    local out = {}
    for _, e in ipairs({ ... }) do out[#out + 1] = { id = e[1], n = e[2] } end
    return out
  end
  local function same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i].id ~= b[i].id or a[i].n ~= b[i].n then return false end end
    return true
  end

  -- §1 File.
  local f1, c1 = Mo.queue_set({}, "steam-trotter", 3, known)
  check(same(f1, q({ "steam-trotter", 3 })) and c1, "§1 une entrée neuve s'ajoute")
  local base = q({ "steam-trotter", 3 }, { "other", 2 })
  local f2, c2 = Mo.queue_set(base, "steam-trotter", 5, known)
  check(same(f2, q({ "steam-trotter", 5 }, { "other", 2 })) and c2, "§1 une entrée présente garde sa place")
  check(same(base, q({ "steam-trotter", 3 }, { "other", 2 })), "§1 la file reçue n'est jamais modifiée")
  local _, c3 = Mo.queue_set(base, "steam-trotter", 3, known)
  check(c3 == false, "§1 même valeur : rien n'a changé")
  check(Mo.queue_target(Mo.queue_set({}, "steam-trotter", 500, known), "steam-trotter") == Ro.KEEP_MAX, "§1 N borné en haut")
  check(Mo.queue_target(Mo.queue_set({}, "steam-trotter", -4, known), "steam-trotter") == 0, "§1 N borné en bas")
  check(Mo.queue_target(Mo.queue_set({}, "steam-trotter", 2.7, known), "steam-trotter") == 2, "§1 N entier")
  local _, c4 = Mo.queue_set({}, "inconnu", 3, known)
  check(c4 == false and #Mo.queue_set({}, "inconnu", 3, known) == 0, "§1 un robot inconnu est refusé")
  local _, c5 = Mo.queue_set({}, "steam-trotter", 0 / 0, known)
  check(c5 == false, "§1 N non numérique refusé")
  local f6 = Mo.queue_set(base, "steam-trotter", nil, known)
  check(same(f6, q({ "other", 2 })), "§1 N nil retire l'entrée")
  local _, c7 = Mo.queue_set(base, "third", nil, known)
  check(c7 == false, "§1 retirer une entrée absente ne change rien")
  local long = {}
  for i = 1, Ro.QUEUE_MAX do long[i] = { id = "steam-trotter", n = 1 } end
  local _, c8 = Mo.queue_set(long, "other", 1, known)
  check(c8 == false, "§1 la file est bornée à " .. Ro.QUEUE_MAX .. " entrées")
  check(Mo.queue_target(base, "other") == 2 and Mo.queue_target(base, "third") == nil, "§1 cible d'un robot : sa valeur, ou nil")
  local m1 = Mo.queue_move(q({ "steam-trotter", 1 }, { "other", 2 }, { "third", 3 }), "other", -1)
  check(same(m1, q({ "other", 2 }, { "steam-trotter", 1 }, { "third", 3 })), "§1 monter d'un cran")
  local m2 = Mo.queue_move(q({ "steam-trotter", 1 }, { "other", 2 }, { "third", 3 }), "other", 1)
  check(same(m2, q({ "steam-trotter", 1 }, { "third", 3 }, { "other", 2 })), "§1 descendre d'un cran")
  local _, mc = Mo.queue_move(q({ "steam-trotter", 1 }, { "other", 2 }), "steam-trotter", -1)
  check(mc == false, "§1 monter la première entrée est sans effet")
  local _, mc2 = Mo.queue_move(q({ "steam-trotter", 1 }, { "other", 2 }), "other", 1)
  check(mc2 == false, "§1 descendre la dernière entrée est sans effet")

  -- Recette voulue.
  local have = { ["steam-trotter"] = 0, other = 0, third = 0 }
  check(Mo.recipe_wanted({}, have, nil) == nil, "§1 file vide : aucune recette imposée")
  check(Mo.recipe_wanted(q({ "steam-trotter", 3 }), have, "steam-trotter") == nil, "§1 une entrée et une recette : la recette reste la vôtre")
  check(Mo.recipe_wanted(q({ "steam-trotter", 3 }), have, "other") == nil, "§1 une entrée, recette autre : on n'y touche pas")
  check(Mo.recipe_wanted(q({ "steam-trotter", 3 }), have, nil) == "steam-trotter", "§1 sans recette, la file en pose une")
  check(Mo.recipe_wanted(q({ "steam-trotter", 3 }), { ["steam-trotter"] = 3 }, nil) == nil, "§1 sans recette mais cible atteinte : rien")
  local two = q({ "steam-trotter", 2 }, { "other", 2 })
  check(Mo.recipe_wanted(two, { ["steam-trotter"] = 2, other = 0 }, "steam-trotter") == "other", "§1 deux entrées : la première atteinte, la seconde voulue")
  check(Mo.recipe_wanted(two, { ["steam-trotter"] = 1, other = 0 }, "other") == "steam-trotter", "§1 deux entrées : retour à la première sous sa cible")
  check(Mo.recipe_wanted(two, { ["steam-trotter"] = 1, other = 0 }, "steam-trotter") == nil, "§1 déjà la bonne recette : rien")
  check(Mo.recipe_wanted(two, { ["steam-trotter"] = 2, other = 2 }, "other") == nil, "§1 deux cibles atteintes : rien à changer")
  check(Mo.recipe_wanted(q({ "steam-trotter", 0 }, { "other", 2 }), have, "steam-trotter") == "other", "§1 une cible 0 est sautée")

  -- Moment sûr.
  local ok = { current = "a", progress = 0, output_empty = true, output_blocked = false, since = 1000, min_gap = 480 }
  local function sw(o)
    local p = {}
    for k, v in pairs(ok) do p[k] = v end
    for k, v in pairs(o) do p[k] = v end
    if o.nocurrent then p.current = nil end
    return Mo.recipe_switch_ok(p)
  end
  check(sw({}) == true, "§1 changement permis : machine au repos, sortie vide, assez de temps")
  check(sw({ nocurrent = true, progress = 0.5, output_empty = false, since = 0 }) == true, "§1 sans recette : toujours permis")
  check(sw({ progress = 0.3 }) == false, "§1 pas de changement en cours de fabrication")
  check(sw({ output_empty = false }) == false, "§1 pas de changement avec un kit utile en sortie")
  check(sw({ output_empty = false, output_blocked = true }) == true, "§1 des kits bloqués ne retiennent pas le changement")
  check(sw({ since = 100 }) == false, "§1 pas de changement avant qu'une fabrication entière ait pu s'achever (RB0 E7)")
  check(sw({ since = 480 }) == true, "§1 changement permis à la durée exacte d'une fabrication")

  -- §2 Zone.
  local box = { left_top = { x = 2, y = 4 }, right_bottom = { x = 10, y = 10 } }
  local a = Cm.area(box)
  check(a and a.x0 == 2 and a.y0 == 4 and a.x1 == 10 and a.y1 == 10, "§2 zone lue")
  local r = Cm.area({ left_top = { x = 10, y = 10 }, right_bottom = { x = 2, y = 4 } })
  check(r and r.x0 == 2 and r.y0 == 4 and r.x1 == 10 and r.y1 == 10, "§2 coins inversés remis dans l'ordre")
  local arr = Cm.area({ { 1, 2 }, { 3, 6 } })
  check(arr and arr.x0 == 1 and arr.y1 == 6, "§2 zone en couples")
  check(Cm.area(nil) == nil and Cm.area({}) == nil and Cm.area({ left_top = { x = "a", y = 1 }, right_bottom = { x = 2, y = 2 } }) == nil
    and Cm.area({ left_top = { x = 0 / 0, y = 1 }, right_bottom = { x = 2, y = 2 } }) == nil, "§2 zone illisible : nil")
  local c = Cm.center(box)
  check(c.x == 6 and c.y == 7, "§2 centre de la zone")
  check(Cm.center(nil) == nil, "§2 pas de centre sans zone")
  local click = { left_top = { x = 5, y = 5 }, right_bottom = { x = 5, y = 5 } }
  check(Cm.radius(click) == Ro.MIN_ZONE, "§2 un clic sans glisser (zone nulle) donne le rayon minimal")
  check(Cm.center(click).x == 5 and Cm.center(click).y == 5, "§2 le centre d'un clic est le clic")
  check(Cm.radius({ left_top = { x = 0, y = 0 }, right_bottom = { x = 1, y = 1 } }) == Ro.MIN_ZONE, "§2 petite zone : rayon minimal")
  check(Cm.radius({ left_top = { x = 0, y = 0 }, right_bottom = { x = 500, y = 500 } }) == Ro.ATTACK_RADIUS, "§2 grande zone : rayon plafonné")
  local mid = Cm.radius({ left_top = { x = 0, y = 0 }, right_bottom = { x = 24, y = 18 } })
  check(mid == 15, "§2 zone moyenne : demi-diagonale (" .. tostring(mid) .. ")")
  check(Cm.radius(nil) == Ro.MIN_ZONE, "§2 zone illisible : rayon minimal")

  -- §3 Actions.
  check(Cm.action_of("selected") == "choose" and Cm.action_of("alt") == "attack" and Cm.action_of("reverse") == "strike"
    and Cm.action_of("alt_reverse") == "move" and Cm.action_of("autre") == nil, "§3 les quatre événements, quatre actions")
  check(Cm.order_of("attack") == "attack" and Cm.order_of("strike") == "attack" and Cm.order_of("move") == "move"
    and Cm.order_of("choose") == nil and Cm.order_of(nil) == nil, "§3 ordre du moteur de chaque action")
  for _, act in ipairs({ "attack", "strike", "move" }) do
    check(Mo.is_order(Cm.order_of(act)), "§3 l'ordre de " .. act .. " est connu du modèle")
  end
  check(Cm.move_radius(1) == 2 and Cm.move_radius(0) == 2 and Cm.move_radius(9) == 4 and Cm.move_radius(10000) == 6
    and Cm.move_radius(nil) == 2, "§3 rayon d'arrêt d'une troupe : de 2 à 6 selon l'effectif")

  -- §4 Sélection.
  local ch = Cm.choose({ 9, 3, 3, 7, "x", 1 })
  check(#ch == 4 and ch[1] == 1 and ch[2] == 3 and ch[3] == 7 and ch[4] == 9, "§4 triée, sans doublon, numéros seulement")
  local many = {}
  for i = 1, Ro.SELECTION_MAX + 50 do many[i] = i end
  check(#Cm.choose(many) == Ro.SELECTION_MAX, "§4 bornée à " .. Ro.SELECTION_MAX)
  check(#Cm.choose(nil) == 0, "§4 sélection vide")
  local kept, gone = Cm.purge({ 1, 2, 3, 4 }, function(n) return n % 2 == 0 end)
  check(#kept == 2 and kept[1] == 2 and kept[2] == 4 and gone == 2, "§4 purge des morts : restants et nombre retiré")

  -- §5 Attaquer ce qui est encadré.
  local p0, r0 = Cm.strike(box, {})
  check(p0.x == 6 and p0.y == 7 and r0 == Cm.radius(box), "§5 sans ennemi : le centre et le rayon de la zone")
  local p1, r1 = Cm.strike(box, { { x = 10, y = 10 }, { x = 20, y = 10 } })
  check(p1.x == 15 and p1.y == 10 and r1 == 9, "§5 centre de gravité des ennemis, rayon = étalement + 4 (" .. tostring(r1) .. ")")
  local _, r2 = Cm.strike(box, { { x = 10, y = 10 } })
  check(r2 == Ro.MIN_ZONE, "§5 un seul ennemi : rayon minimal")
  local _, r3 = Cm.strike(box, { { x = 0, y = 0 }, { x = 400, y = 0 } })
  check(r3 == Ro.ATTACK_RADIUS, "§5 ennemis très étalés : rayon plafonné")
  local p4 = Cm.strike(box, { { 4, 4 }, { 8, 8 } })
  check(p4.x == 6 and p4.y == 6, "§5 positions en couples")
  local p5 = Cm.strike(box, { { x = "a", y = 2 } })
  check(p5.x == 6 and p5.y == 7, "§5 positions illisibles : repli sur la zone")

  -- §6 Tous au ralliement.
  local led = { [10] = { home = 100 }, [11] = { home = 200 }, [12] = {}, [13] = { home = 300 } }
  local rallies = { [100] = { x = 1, y = 2 }, [200] = { x = 3, y = 4 } }
  local plan, skipped = Cm.rally_all({ 10, 11, 12, 13 }, led, rallies, { x = 9, y = 9 })
  check(#plan == 4 and skipped == 0, "§6 avec repli : toutes les unités ont une destination")
  check(plan[1].unit == 10 and plan[1].x == 1 and plan[1].y == 2 and plan[2].x == 3 and plan[2].y == 4, "§6 chacune va au ralliement de SON atelier")
  check(plan[3].x == 9 and plan[4].x == 9, "§6 sans atelier connu, ou atelier disparu : le repli")
  local plan2, skipped2 = Cm.rally_all({ 10, 12, 99 }, led, rallies, nil)
  check(#plan2 == 1 and skipped2 == 2 and plan2[1].unit == 10, "§6 sans repli : les unités sans destination sont comptées")

  -- §7 Pertes.
  local st = Cm.new_loss()
  check(Cm.loss_note(st, 1000, 5, 6) == true, "§7 la première perte lève une alerte")
  check(Cm.loss_note(st, 1100, 7, 8) == false and Cm.loss_note(st, 1000 + Ro.ALERT_COOLDOWN - 1, 7, 8) == false,
    "§7 pas de seconde alerte dans la période")
  check(Cm.loss_note(st, 1000 + Ro.ALERT_COOLDOWN, 9, 9) == true, "§7 une alerte à la fin de la période")
  check(st.n == 4, "§7 toutes les pertes sont comptées (" .. tostring(st.n) .. ")")
  check(Cm.loss_flush(st, 1000 + Ro.ALERT_COOLDOWN + Ro.LOSS_FLUSH - 1) == nil, "§7 pas de bilan tant que les pertes continuent")
  local fn, fx, fy = Cm.loss_flush(st, 1000 + Ro.ALERT_COOLDOWN + Ro.LOSS_FLUSH)
  check(fn == 4 and fx == 9 and fy == 9, "§7 bilan : nombre et dernière position")
  check(st.n == 0 and Cm.loss_flush(st, 99999) == nil, "§7 le bilan remet la salve à zéro, sans second bilan")

  -- §8 Registre : atelier d'origine.
  local l = Mo.new_ledger()
  Mo.add(l, "player", 30, "steam-trotter", 1, 500)
  Mo.add(l, "player", 31, "steam-trotter", 1, 500)
  Mo.add(l, "player", 32, "steam-trotter", 1, 600)
  Mo.add(l, "player", 33, "steam-trotter", 1)
  check(l.units[30].home == 500 and l.units[33].home == nil, "§8 l'atelier d'origine est gardé (nil si inconnu)")
  local at = Mo.units_at(l, 500)
  check(#at == 2 and at[1] == 30 and at[2] == 31, "§8 unités d'un atelier, triées")
  Mo.remove(l, 30)
  check(#Mo.units_at(l, 500) == 1 and Mo.check(l), "§8 une unité retirée sort de son atelier, registre cohérent")

  -- §9 Déterminisme.
  local function build(order)
    local out = Mo.new_ledger()
    for _, un in ipairs(order) do Mo.add(out, "player", un, "steam-trotter", 1, 500 + un % 2) end
    return out
  end
  local A, B = build({ 5, 3, 9, 1 }), build({ 1, 9, 3, 5 })
  local ua, ub = Mo.units_at(A, 501), Mo.units_at(B, 501)
  check(table.concat(A.order, ",") == table.concat(B.order, ",") and table.concat(ua, ",") == table.concat(ub, ","),
    "§9 même registre quel que soit l'ordre d'arrivée")
  check(table.concat(Cm.choose({ 5, 3, 9, 1 }), ",") == table.concat(Cm.choose({ 1, 9, 3, 5 }), ","), "§9 même sélection quel que soit l'ordre")
  local qa = Mo.queue_set(Mo.queue_set({}, "steam-trotter", 2, known), "other", 1, known)
  local qb = Mo.queue_set(Mo.queue_set({}, "other", 1, known), "steam-trotter", 2, known)
  check(not same(qa, qb), "§9 l'ordre de la file est celui des ajouts (c'est voulu : le joueur le règle)")

  return pass, fail, msgs
end

-- Exécution normale.
local Ro, Mo, Cm = load_all(RO_SRC, MO_SRC, CM_SRC)
assert(Ro, Mo)
local pass, fail, msgs = suite(Ro, Mo, Cm)
local function check10(c, m)
  if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
end

-- §10 Traductions, déclarations, branchements.
local function cfg_keys(path)
  local keys, section = {}, nil
  for line in read(path):gmatch("[^\r\n]+") do
    local s = line:match("^%[([%w%-_]+)%]$")
    if s then section = s
    elseif section and not line:match("^%s*;") then
      local k = line:match("^([^=]+)=")
      if k then keys[section .. "." .. k] = true end
    end
  end
  return keys
end
local FR, EN = cfg_keys("locale/fr/robots.cfg"), cfg_keys("locale/en/robots.cfg")
-- un fichier de traduction ne répète jamais un en-tête de section : le moteur refuse le chargement (« Duplicate key », 1/11)
for _, path in ipairs({ "locale/fr/robots.cfg", "locale/en/robots.cfg" }) do
  local seen, dup = {}, nil
  for line in read(path):gmatch("[^\r\n]+") do
    local sec = line:match("^%[([%w%-_]+)%]$")
    if sec then
      if seen[sec] then dup = sec end
      seen[sec] = true
    end
  end
  check10(dup == nil, "§10 section répétée dans " .. path .. " : " .. tostring(dup))
end
local function keys_of(path, prefix)
  local code = read(path)
  local out, seen = {}, {}
  for key in code:gmatch('"(' .. prefix .. '%.[%w%-_]+)"') do
    if not seen[key] then seen[key] = true out[#out + 1] = key end
  end
  return out
end
local needed = {}
for _, path in ipairs({ "script/gui/robots.lua", "script/robots/outils.lua", "script/robots/usine.lua", "prototypes/robots.lua" }) do
  for _, prefix in ipairs({ "fo%-robots%-ui", "fo%-robots", "item%-name", "shortcut%-name" }) do
    for _, k in ipairs(keys_of(path, prefix)) do needed[k] = true end
  end
end
-- clés composées dans une boucle (« fo-robots-ui.. k », « item-name.. name »)
for _, k in ipairs({ "tab-intro", "key-choose", "key-attack", "key-strike", "key-move", "col-robot", "col-alive", "col-points" }) do
  needed["fo-robots-ui." .. k] = true
end
needed["item-name." .. Ro.TOOL_ORDER], needed["item-name." .. Ro.TOOL_RALLY] = true, true
needed["item-description." .. Ro.TOOL_ORDER], needed["item-description." .. Ro.TOOL_RALLY] = true, true
needed["shortcut-name." .. Ro.SHORTCUT], needed["controls." .. Ro.SHORTCUT] = true, true
needed["fo-ia1i.tab-armee"] = true
local list = {}
for k in pairs(needed) do list[#list + 1] = k end -- trié juste après
table.sort(list)
for _, k in ipairs(list) do
  if not k:find("%.%.") and not k:find("%.$") and not k:find("name%-$") and not k:find("desc%-$") then
    check10(FR[k] ~= nil, "§10 traduction FR absente : " .. k)
    check10(EN[k] ~= nil, "§10 traduction EN absente : " .. k)
  end
end
local same_keys = true
for k in pairs(FR) do if not EN[k] then same_keys = false end end
for k in pairs(EN) do if not FR[k] then same_keys = false end end
check10(same_keys, "§10 FR et EN : mêmes clés")
-- les paramètres __n__ de chaque clé du lot sont les mêmes en FR et en EN
local function params(path)
  local out, section = {}, nil
  for line in read(path):gmatch("[^\r\n]+") do
    local s = line:match("^%[([%w%-_]+)%]$")
    if s then section = s
    else
      local k, v = line:match("^([^=;]+)=(.*)$")
      if k and section then
        local ps = {}
        for n in v:gmatch("__(%d)__") do ps[n] = true end
        local flat = {}
        for n = 1, 9 do if ps[tostring(n)] then flat[#flat + 1] = n end end
        out[section .. "." .. k] = table.concat(flat, ",")
      end
    end
  end
  return out
end
local PF, PE = params("locale/fr/robots.cfg"), params("locale/en/robots.cfg")
local pbad = {}
for k, v in pairs(PF) do if PE[k] ~= v then pbad[#pbad + 1] = k end end -- trié juste après
table.sort(pbad)
check10(#pbad == 0, "§10 paramètres différents entre FR et EN : " .. table.concat(pbad, " "))

-- outils et raccourci déclarés au prototype
local proto = strip(read("prototypes/robots.lua"))
check10(proto:find('type = "selection%-tool"') and proto:find("entity_type_filters") and proto:find("reverse_entity_type_filters"),
  "§10 l'outil d'ordre est un outil de sélection filtré (unités et araignées ; ennemis au bouton droit)")
check10(proto:find('"same%-force"') and proto:find('"enemy"'), "§10 modes : mes robots au glisser, l'ennemi au bouton droit")
check10(proto:find('type = "shortcut"') and proto:find('type = "custom%-input"') and proto:find('action = "spawn%-item"')
  and proto:find("technology_to_unlock"), "§10 raccourci et touche qui donnent l'outil, ouverts par la technologie")
check10(proto:find("Ro%.TOOL_ORDER") and proto:find("Ro%.TOOL_RALLY"), "§10 les deux outils sont déclarés")
check10(Ro.TOOL_ORDER ~= Ro.TOOL_RALLY and Ro.INPUT_KEY ~= "", "§10 deux outils distincts, une touche par défaut")
local tabs = read("shared/gui/ia1i.lua")
check10(tabs:find('"armee"'), "§10 l'onglet « Armée » est dans la liste des onglets")
local tw = read("script/gui/team_window.lua")
check10(tw:find("tabs%.armee = RobotsGui%.tab") and tw:find("RobotsGui%.set_refresh"), "§10 l'onglet « Armée » est branché dans la fenêtre")
local ctl = read("control.lua")
check10(ctl:find('require%("script%.robots%.outils"%)'), "§10 les outils sont chargés par control.lua")
-- les boutons du panneau et de l'onglet sont ceux que Gui.click sait traiter
local gui = strip(read("script/gui/robots.lua"))
for _, name in ipairs({ "rally_pick", "rally_here", "rally_reset", "army_tool", "army_all", "army_none", "army_rally" }) do
  check10(gui:find('P %.%. "' .. name .. '"') ~= nil, "§10 bouton « " .. name .. " » traité")
end

for _, m in ipairs(msgs) do print("[ROBOTS-UI] ECHEC " .. m) end

-- §11 Mutants.
local MO_MUT = {
  { "N sans borne haute", "n = max(0, min(Ro.KEEP_MAX, floor(n)))", "n = max(0, floor(n))" },
  { "N sans borne basse", "n = max(0, min(Ro.KEEP_MAX, floor(n)))", "n = min(Ro.KEEP_MAX, floor(n))" },
  { "N non entier", "n = max(0, min(Ro.KEEP_MAX, floor(n)))", "n = max(0, min(Ro.KEEP_MAX, n))" },
  { "robot inconnu accepté", "if known and not known[id] then return out, false end", "" },
  { "file sans borne", "if #out >= Ro.QUEUE_MAX then return out, false end", "" },
  { "entrée présente remise en queue", "      q.n = n\n      return out, changed", "      table.remove(out, _) out[#out + 1] = { id = id, n = n }\n      return out, changed" },
  { "file reçue modifiée", "local function copy_queue(queue)\n  local out = {}\n  for i, q in ipairs(queue or {}) do out[i] = { id = q.id, n = q.n } end\n  return out\nend",
    "local function copy_queue(queue) return queue or {} end" },
  { "retrait d'une entrée sans effet", "if q.id == id then table.remove(out, i) return out, true end", "if q.id == id then return out, true end" },
  { "monter descend", "local j = i + (delta < 0 and -1 or 1)", "local j = i + (delta < 0 and 1 or -1)" },
  { "monter sans borne", "if j < 1 or j > #out then return out, false end", "if j > #out then return out, false end" },
  { "une entrée suffit à imposer la recette", "if n < 2 and current_id ~= nil then return nil end", "" },
  { "la recette voulue est toujours changée", "if want == nil or want == current_id then return nil end\n  return want", "if want == nil then return nil end\n  return want" },
  { "changement en cours de fabrication", "if (p.progress or 0) > 0 then return false end", "" },
  { "changement avec un kit utile en sortie", "if not (p.output_empty or p.output_blocked) then return false end", "" },
  { "changement trop tôt", "return (p.since or 0) >= (p.min_gap or 0)", "return true" },
  { "changement sans recette refusé", "if p.current == nil then return true end", "" },
  { "atelier d'origine perdu", "l.units[unit_number] = { force = force, id = id, points = points, home = home }", "l.units[unit_number] = { force = force, id = id, points = points }" },
  { "unités d'un atelier non triées", "function M.units_at(l, home)\n  local out = {}\n  for _, un in ipairs(l.order) do\n    if l.units[un].home == home then out[#out + 1] = un end\n  end\n  return out",
    "function M.units_at(l, home)\n  local out = {}\n  for _, un in ipairs(l.order) do\n    if l.units[un].home == home then table.insert(out, 1, un) end\n  end\n  return out" },
}
local CM_MUT = {
  { "coins non remis dans l'ordre", "return { x0 = min(ax, bx), y0 = min(ay, by), x1 = max(ax, bx), y1 = max(ay, by) }", "return { x0 = ax, y0 = ay, x1 = bx, y1 = by }" },
  { "zone non finie acceptée", "if ax ~= ax or ay ~= ay or bx ~= bx or by ~= by then return nil end", "" },
  { "centre au coin", "return { x = (z.x0 + z.x1) / 2, y = (z.y0 + z.y1) / 2 }", "return { x = z.x0, y = z.y0 }" },
  { "rayon sans plafond", "return max(Ro.MIN_ZONE, min(Ro.ATTACK_RADIUS, half))", "return max(Ro.MIN_ZONE, half)" },
  { "rayon sans minimum", "return max(Ro.MIN_ZONE, min(Ro.ATTACK_RADIUS, half))", "return min(Ro.ATTACK_RADIUS, half)" },
  { "rayon au diamètre", "local half = sqrt((z.x1 - z.x0) ^ 2 + (z.y1 - z.y0) ^ 2) / 2", "local half = sqrt((z.x1 - z.x0) ^ 2 + (z.y1 - z.y0) ^ 2)" },
  { "frappe prend un ordre de marche", "if action == \"attack\" or action == \"strike\" then return \"attack\" end", "if action == \"attack\" then return \"attack\" end" },
  { "choisir donne un ordre", "if action == \"move\" then return \"move\" end\n  return nil", "return \"move\"" },
  { "rayon d'arrêt sans plafond", "return max(2, min(6, 1 + floor(sqrt(max(0, count or 0)))))", "return max(2, 1 + floor(sqrt(max(0, count or 0))))" },
  { "sélection non triée", "  table.sort(out)\n  while #out > Ro.SELECTION_MAX", "  while #out > Ro.SELECTION_MAX" },
  { "sélection avec doublons", "if type(n) == \"number\" and not seen[n] then", "if type(n) == \"number\" then" },
  { "sélection sans borne", "  while #out > Ro.SELECTION_MAX do out[#out] = nil end\n", "" },
  { "purge inversée", "if alive(n) then out[#out + 1] = n else gone = gone + 1 end", "if not alive(n) then out[#out + 1] = n else gone = gone + 1 end" },
  { "frappe au premier ennemi", "local cx, cy = sx / n, sy / n", "local cx, cy = sx, sy" },
  { "frappe sans étalement", "return { x = cx, y = cy }, max(Ro.MIN_ZONE, min(Ro.ATTACK_RADIUS, far + 4))", "return { x = cx, y = cy }, Ro.MIN_ZONE" },
  { "frappe sans plafond", "max(Ro.MIN_ZONE, min(Ro.ATTACK_RADIUS, far + 4))", "max(Ro.MIN_ZONE, far + 4)" },
  { "ralliement : le repli d'abord", "local p = rec and rec.home and rallies[rec.home] or fallback", "local p = fallback or (rec and rec.home and rallies[rec.home])" },
  { "ralliement : sans destination non compté", "      skipped = skipped + 1\n", "" },
  { "alerte à chaque perte", "if st.last_alert == nil or tick - st.last_alert >= Ro.ALERT_COOLDOWN then", "if true then" },
  { "alerte jamais renouvelée", "tick - st.last_alert >= Ro.ALERT_COOLDOWN", "tick - st.last_alert > Ro.ALERT_COOLDOWN * 100" },
  { "alerte une tick trop tard", "tick - st.last_alert >= Ro.ALERT_COOLDOWN", "tick - st.last_alert > Ro.ALERT_COOLDOWN" },
  { "pertes non comptées", "st.n = (st.n or 0) + 1", "st.n = 1" },
  { "bilan trop tôt", "tick - (st.t or tick) >= Ro.LOSS_FLUSH", "tick - (st.t or tick) >= 0" },
  { "bilan sans remise à zéro", "    st.n = 0\n    return n, x, y", "    return n, x, y" },
}
local refused, kept = 0, {}
local function try(label, ro_src, mo_src, cm_src)
  local R, M, C = load_all(ro_src, mo_src, cm_src)
  local f2 = 1
  if R then
    local ok, _, ff = pcall(suite, R, M, C)
    f2 = ok and ff or 1
  end
  if f2 > 0 then refused = refused + 1 else kept[#kept + 1] = label end
end
for _, m in ipairs(MO_MUT) do
  local a, b = MO_SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else try(m[1], RO_SRC, MO_SRC:sub(1, a - 1) .. m[3] .. MO_SRC:sub(b + 1), CM_SRC) end
end
for _, m in ipairs(CM_MUT) do
  local a, b = CM_SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else try(m[1], RO_SRC, MO_SRC, CM_SRC:sub(1, a - 1) .. m[3] .. CM_SRC:sub(b + 1)) end
end
if #kept == 0 then pass = pass + 1 else
  fail = fail + 1
  print("[ROBOTS-UI] ECHEC §11 mutants NON refusés : " .. table.concat(kept, " ; "))
end
print(string.format("[ROBOTS-UI] mutants refusés : %d sur %d", refused, #MO_MUT + #CM_MUT))
print(string.format("[ROBOTS-UI] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
