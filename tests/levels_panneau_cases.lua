--[[
  Lot PANNEAU (4/11) : QUAND s'ouvre le panneau « Évolution » (règle pure shared/levels/panneau.lua, script/levels/panel.lua,
  réglage par joueur fo-levels-panneau). Joué par tests/levels_test.lua (fichier à part : le bloc principal de levels_test est
  à la limite des 200 variables locales de Lua 5.2).

  Demande du DC (4/11, vers 19 h 40) : « Aussi pour les pop-ups d'améliorations ou autre, dès que le curseur passe sur un truc,
  c'est ultra chiant. Il faudrait que ce soit déclenchable ou même dans l'interface uniquement quand on clique sur le bâtiment
  concerné. »

  Cases.pure    : la table de décision, déclencheur par déclencheur.
  Cases.runtime : 11 cas en « clic » dans le moteur simulé (le survol n'ouvre pas ; l'interface ouverte ouvre ; l'interface
                  fermée ferme ; U améliore sans ouvrir ; Maj+U ouvre puis ferme ; après une amélioration, le panneau suit la
                  nouvelle entité et son interface est rouverte, l'ancienne interface étant fermée APRÈS le remplacement, ou
                  PENDANT, encore valide, par le bouton ou par U (relecture, R1) ; le clic gauche ouvre, avec ou sans
                  interface, dans les deux ordres clic / interface ; interface fermée sans événement : fermé au
                  rafraîchissement ; panneau ouvert au survol puis passage en « clic » : fermé au rafraîchissement), puis CHAQUE
                  cas rejoué avec son mutant (Panneau.decide remplacé pour un seul déclencheur) : le cas doit échouer. Puis le
                  journal [FO-REGLAGES] (rien pour un réglage par joueur). Cases.data : le réglage, les touches (étape data
                  réelle, harnais) et les traductions FR et EN.
  Les cas « survol » (comportement d'avant) restent ceux de levels_test et levels_clear_cases, joueur mis en « survol ».
]]

local Cases = {}

--- Bavard sur demande (FO_VERBOSE_PANNEAU=1) : chaque contrôle du banc, OK ou ECHEC, avec son message.
local function verbose(check)
  if not os.getenv("FO_VERBOSE_PANNEAU") then return check end
  return function(cond, msg)
    print((cond and "  OK " or "  ECHEC ") .. msg)
    check(cond, msg)
  end
end

function Cases.pure(check, section)
  check = verbose(check)
  section("Panneau « Évolution » au clic (lot PANNEAU) : règle pure")
  local P = require("shared.levels.panneau")
  local function st(t)
    local out = { mode = P.CLIC, open = false, has = true, same = false, via = nil, bound = false }
    for k, v in pairs(t or {}) do out[k] = v end
    return out
  end
  local function is(trigger, t, act, via)
    local a, v = P.decide(trigger, st(t))
    return a == act and v == via
  end

  check(P.DEFAULT == "clic" and #P.VALUES == 2 and P.VALUES[1] == "clic" and P.VALUES[2] == "survol" and P.SETTING == "fo-levels-panneau",
    "règle : réglage fo-levels-panneau, valeurs « clic » et « survol », défaut « clic »")
  check(P.mode_of("survol") == "survol" and P.mode_of("clic") == "clic" and P.mode_of(nil) == "clic" and P.mode_of("autre") == "clic",
    "règle : une valeur inconnue ou absente vaut « clic »")
  -- Survol.
  check(is("hover", {}, "none") and is("hover", { open = true }, "none"), "règle (clic) : le survol n'ouvre rien, panneau fermé ou ouvert")
  check(is("hover", { mode = P.SURVOL }, "open", "hover") and is("hover", { mode = P.SURVOL, open = true, same = true }, "none")
    and is("hover", { mode = P.SURVOL, open = true }, "open", "hover") and is("hover", { mode = P.SURVOL, has = false }, "none"),
    "règle (survol) : comportement d'avant (ouvre un autre bâtiment, rien pour la cible déjà montrée)")
  -- Interface du bâtiment.
  check(is("gui-opened", {}, "open", "gui") and is("gui-opened", { open = true, via = "key" }, "open", "gui")
    and is("gui-opened", { has = false }, "none"), "règle (clic) : l'interface d'un bâtiment à niveaux ouvre son panneau")
  check(is("gui-opened", { mode = P.SURVOL }, "none"), "règle (survol) : l'interface n'ouvre rien (comportement d'avant)")
  -- Clic gauche sur un bâtiment (fo-level-open, avec ou sans interface).
  check(is("click", {}, "open", "click") and is("click", { open = true }, "open", "click") and is("click", { has = false }, "none")
    and is("click", { has = false, open = true }, "none"), "règle (clic) : un clic gauche sur un bâtiment à niveaux ouvre son panneau")
  check(is("click", { open = true, same = true, via = "gui" }, "none") and is("click", { open = true, same = true, via = "click" }, "none"),
    "règle (clic) : un clic sur la cible déjà montrée ne change rien (jamais de bascule ; l'interface garde le panneau)")
  check(is("click", { mode = P.SURVOL }, "none"), "règle (survol) : le clic n'ouvre rien de plus (comportement d'avant)")
  check(is("gui-closed", { open = true, via = "gui", same = true, upgrading = true }, "none"),
    "règle : pendant une amélioration du joueur, la fermeture de l'interface (ancienne entité) est ignorée")
  check(is("gui-closed", { open = true, via = "gui", same = true }, "close") and is("gui-closed", { open = true, via = "gui" }, "none")
    and is("gui-closed", { open = true, via = "key", same = true }, "none") and is("gui-closed", { open = true, via = "hover", same = true }, "none")
    and is("gui-closed", { mode = P.SURVOL, open = true, via = "gui", same = true }, "close"),
    "règle : fermer l'interface de la cible ferme un panneau ouvert par elle, et lui seul")
  -- Touches.
  check(is("key-up", {}, "none") and is("key-up", { open = true }, "refresh") and is("key-up", { mode = P.SURVOL }, "open", "hover")
    and is("key-up", { has = false, open = true }, "none"), "règle : U n'ouvre rien en « clic » (rafraîchit un panneau ouvert), ouvre en « survol »")
  check(is("key-panel", {}, "open", "key") and is("key-panel", { open = true, same = true, via = "gui" }, "close")
    and is("key-panel", { open = true, via = "gui" }, "open", "key") and is("key-panel", { has = false, open = true }, "close")
    and is("key-panel", { has = false }, "none") and is("key-panel", { mode = P.SURVOL, open = true, same = true }, "close"),
    "règle : Maj+U bascule le panneau du bâtiment survolé ; sans bâtiment survolé, ferme le panneau ouvert")
  -- Rafraîchissement.
  check(is("tick", {}, "none") and is("tick", { open = true, via = "gui", bound = true }, "refresh")
    and is("tick", { open = true, via = "gui" }, "close") and is("tick", { open = true, via = "key" }, "refresh")
    and is("tick", { open = true, via = "click" }, "refresh")
    and is("tick", { open = true, via = "hover" }, "close") and is("tick", { open = true }, "close"),
    "règle (clic) : au rafraîchissement, panneau d'interface gardé tant qu'elle est ouverte ; panneau de survol fermé")
  check(is("tick", { mode = P.SURVOL, open = true, via = "hover" }, "refresh") and is("tick", { mode = P.SURVOL, open = true }, "refresh")
    and is("tick", { mode = P.SURVOL, open = true, via = "key" }, "refresh"),
    "règle (survol) : au rafraîchissement, le panneau reste (sauvegarde d'avant comprise : via absent)")
  -- Après remplacement.
  check(is("replaced", { open = true, via = "gui" }, "reopen") and is("replaced", { open = true, via = "gui", bound = true }, "none")
    and is("replaced", { open = true, via = "key" }, "none") and is("replaced", {}, "none"),
    "règle : après une action, l'interface de la cible remplacée est rouverte si le panneau la suivait")
  check(not pcall(P.decide, "inconnu", st()), "règle : un déclencheur inconnu est une erreur")
end

function Cases.runtime(check, section)
  check = verbose(check)
  section("Panneau « Évolution » au clic (lot PANNEAU) : moteur simulé et mutants")
  local M = require("tests.mock_engine")
  local Wd = M.world()
  local L = require("shared.levels.config")
  local Levels = require("script.levels.levels")
  local P = require("shared.levels.panneau")
  local GUN, CCF, WALL = L.by_key.gun, L.by_key.command, L.by_key.wall
  local s = game.surfaces[1]
  local ev = Wd.events
  local player = Wd.player
  local GT = defines.gui_type

  local FORCE = "fo-panneau-sim"
  game.create_force(FORCE)
  local cc = s.create_entity({ name = L.name(CCF, 15), position = { x = 5000.5, y = 5000.5 }, force = FORCE, raise_built = true })
  local cinv = cc.get_inventory(defines.inventory.chest)
  for _ = 1, 40 do for _, c in ipairs(L.cost(GUN, 3)) do cinv.insert({ name = c[1], count = c[2] }) end end
  check(Levels.cc(game.forces[FORCE]) == cc, "moteur simulé : force du banc avec son centre 15 (paie les améliorations)")

  -- Interface simulée avec clear et style (comme la section « Panneau » de levels_test).
  local function fake_gui()
    local c = { _children = {}, _list = {}, style = {} }
    c.add = function(spec)
      local el = fake_gui()
      for k, v in pairs(spec) do el[k] = v end
      el.valid = true
      el.destroy = function() el.valid = false; if spec.name then c._children[spec.name] = nil end end
      if spec.name then c._children[spec.name] = el end
      c._list[#c._list + 1] = el
      return el
    end
    c.clear = function() c._children, c._list = {}, {} end
    return setmetatable(c, { __index = function(t, k) return rawget(t, "_children")[k] end })
  end
  local function find_el(el, name)
    for _, ch in ipairs(el and rawget(el, "_list") or {}) do
      if ch.name == name then return ch end
      local f = find_el(ch, name)
      if f then return f end
    end
    return nil
  end

  local home, gui0 = player.force, player.gui
  local opened0, gtype0, sel0 = rawget(player, "opened"), rawget(player, "opened_gui_type"), rawget(player, "selected")
  rawset(player, "force", game.forces[FORCE])
  player.gui = { left = fake_gui(), top = fake_gui(), screen = fake_gui() }

  -- Interface ouverte du joueur, émulée comme LuaControl.opened (doc 1.1.91), le temps de ces cas seulement (le moteur simulé
  -- partagé garde un champ simple : ia1i_test l'écrit aussi). Lecture : opened et opened_gui_type. ÉCRITURE par le script :
  -- l'interface ouverte est « priée de se fermer » (on_gui_closed), puis on_gui_opened est levé aussitôt, opened_gui_type
  -- devient entity. Les gestes du joueur (open_gui, close_gui) passent par `eng` sans écriture du script.
  local eng = { opened = nil, gtype = GT.none, writes = 0 }
  local mt0 = getmetatable(player)
  rawset(player, "opened", nil)
  rawset(player, "opened_gui_type", nil)
  setmetatable(player, {
    __index = function(t, k)
      if k == "opened" then return eng.opened end
      if k == "opened_gui_type" then return eng.gtype end
      local i = mt0 and mt0.__index
      if type(i) == "function" then return i(t, k) end
      return i and i[k]
    end,
    __newindex = function(t, k, v)
      if k == "opened_gui_type" then error("opened_gui_type est en lecture seule") end
      if k ~= "opened" then return rawset(t, k, v) end
      eng.writes = eng.writes + 1
      local prev = eng.opened
      if prev ~= nil then
        eng.opened, eng.gtype = nil, GT.none
        M.dispatch(ev[defines.events.on_gui_closed], { player_index = 1, entity = prev, gui_type = GT.entity, tick = game.tick })
      end
      if v == nil then return end
      eng.opened, eng.gtype = v, GT.entity
      M.dispatch(ev[defines.events.on_gui_opened], { player_index = 1, entity = v, gui_type = GT.entity, tick = game.tick })
    end,
  })

  local UI = function() return global.fo.levels_ui end
  local function panel() return player.gui.left["fo_lvl_panel"] end
  local function target() return UI().target[1] end
  local function via() return UI().via and UI().via[1] end
  local function reset()
    local f = panel()
    if f then f.destroy() end
    UI().target[1], UI().unit[1] = nil, nil
    if UI().via then UI().via[1] = nil end
    if UI().upgrading then UI().upgrading[1] = nil end
    rawset(player, "cursor_stack", nil)
    eng.opened, eng.gtype = nil, GT.none
    rawset(player, "selected", nil)
    M.set_player_setting(1, P.SETTING, "clic")
  end
  local function hover(e)
    rawset(player, "selected", nil)
    rawset(player, "selected", e)
    M.dispatch(ev[defines.events.on_selected_entity_changed], { player_index = 1, tick = game.tick })
  end
  --- Geste du joueur : le moteur ouvre l'interface (opened, opened_gui_type) PUIS lève on_gui_opened.
  local function open_gui(e)
    eng.opened, eng.gtype = e, GT.entity
    M.dispatch(ev[defines.events.on_gui_opened], { player_index = 1, entity = e, gui_type = GT.entity, tick = game.tick })
  end
  --- Geste du joueur : Échap ou E ferme l'interface.
  local function close_gui(e)
    eng.opened, eng.gtype = nil, GT.none
    M.dispatch(ev[defines.events.on_gui_closed], { player_index = 1, entity = e, gui_type = GT.entity, tick = game.tick })
  end
  local function key(name)
    M.dispatch(ev[name], { player_index = 1, input_name = name, tick = game.tick })
  end
  --- Relecture (R1) : le moteur ferme l'interface de l'ANCIENNE entité, encore valide, PENDANT le remplacement, avant que la
  --- cible ne suive la nouvelle. create_entity{fast_replace} du moteur simulé enveloppé : on_gui_closed levé d'abord.
  --- Renvoie la fonction qui retire l'enveloppe et rend le nombre de fermetures levées.
  local function close_during_replace(old)
    local raw = s.create_entity
    local hits = 0
    s.create_entity = function(spec)
      if spec.fast_replace and old.valid then
        hits = hits + 1
        eng.opened, eng.gtype = nil, GT.none
        M.dispatch(ev[defines.events.on_gui_closed], { player_index = 1, entity = old, gui_type = GT.entity, tick = game.tick })
      end
      return raw(spec)
    end
    return function() s.create_entity = raw; return hits end
  end
  local slot = 0
  local function new_at(family, n)
    slot = slot + 1
    local x = 5100 + 8 * slot
    local pos = family == WALL and { x = x + 0.5, y = 5000.5 } or { x = x, y = 5000 }
    return s.create_entity({ name = L.name(family, n), position = pos, force = FORCE }), pos
  end

  -- Chaque cas reçoit `chk` (le contrôle du banc, ou un compteur d'échecs pour son mutant).
  local CASES = {}
  local ORDER = {}
  local function case(id, label, fn)
    CASES[id] = { label = label, fn = fn }
    ORDER[#ORDER + 1] = id
  end

  case("survol", "le survol n'ouvre pas", function(chk)
    local g = new_at(GUN, 2)
    hover(g)
    chk(panel() == nil and target() == nil, "clic : survoler une mitrailleuse de sa force n'ouvre AUCUN panneau")
    -- Contraste : le même survol en « survol » ouvre (le déclencheur arrive bien au panneau).
    reset()
    M.set_player_setting(1, P.SETTING, "survol")
    hover(g)
    chk(panel() ~= nil and target() == g and via() == "hover", "survol : le même survol ouvre le panneau (comportement d'avant)")
  end)

  case("ouvre", "l'interface ouverte ouvre", function(chk)
    local g = new_at(GUN, 2)
    local other = new_at(GUN, 2)
    open_gui(g)
    chk(panel() ~= nil and target() == g and via() == "gui", "clic : ouvrir l'interface de la mitrailleuse ouvre son panneau")
    hover(other)
    chk(target() == g, "clic : survoler un autre bâtiment ne change pas le panneau ouvert")
    M.run_ticks(60)
    chk(panel() ~= nil and target() == g, "clic : le panneau reste tant que l'interface est ouverte (2 rafraîchissements)")
  end)

  case("ferme", "l'interface fermée ferme", function(chk)
    local g = new_at(GUN, 2)
    open_gui(g)
    chk(panel() ~= nil, "clic : panneau ouvert avec l'interface")
    close_gui(g)
    chk(panel() == nil and target() == nil, "clic : fermer l'interface ferme le panneau aussitôt")
  end)

  case("u", "U n'ouvre pas", function(chk)
    local g, pos = new_at(GUN, 2)
    local nt = Wd.local_texts and #Wd.local_texts or 0
    rawset(player, "selected", g)
    key("fo-level-up")
    local g3 = s.find_entity(L.name(GUN, 3), pos)
    chk(not g.valid and g3 ~= nil, "clic : U améliore la mitrailleuse survolée (niveau 2 → 3)")
    chk(panel() == nil and target() == nil, "clic : U n'ouvre PAS le panneau")
    chk(Wd.local_texts and Wd.local_texts[nt + 1] and Wd.local_texts[nt + 1]:find("fo-levels.msg-done", 1, true) ~= nil,
      "clic : le texte flottant dit le résultat (" .. tostring(Wd.local_texts and Wd.local_texts[nt + 1]) .. ")")
  end)

  case("maju", "Maj+U ouvre puis ferme", function(chk)
    local w = new_at(WALL, 2)
    rawset(player, "selected", w)
    key("fo-level-panel")
    chk(panel() ~= nil and target() == w and via() == "key", "clic : Maj+U sur un mur (sans interface) ouvre son panneau")
    M.run_ticks(60)
    chk(panel() ~= nil and target() == w, "clic : le panneau ouvert par Maj+U reste (2 rafraîchissements)")
    key("fo-level-panel")
    chk(panel() == nil and target() == nil, "clic : Maj+U de nouveau le ferme")
    key("fo-level-panel")
    rawset(player, "selected", nil)
    key("fo-level-panel")
    chk(panel() == nil and target() == nil, "clic : Maj+U sans bâtiment survolé ferme le panneau ouvert")
  end)

  case("suit", "après amélioration, le panneau suit la nouvelle entité", function(chk)
    local g, pos = new_at(GUN, 2)
    open_gui(g)
    local btn = find_el(panel(), "fo_lvl_up")
    chk(btn ~= nil and btn.enabled == true, "clic : bouton « Améliorer » du panneau ouvert avec l'interface")
    -- Ordre « après » : le remplacement ne ferme rien ; l'interface ouverte reste celle de l'ancienne entité (détruite) jusqu'à
    -- l'écriture de `opened` par le script, qui la « prie de se fermer » (on_gui_closed, entité invalide) puis lève on_gui_opened.
    local w0 = eng.writes
    M.dispatch(ev[defines.events.on_gui_click], { element = btn, player_index = 1, tick = game.tick })
    local g3 = s.find_entity(L.name(GUN, 3), pos)
    chk(not g.valid and g3 ~= nil and target() == g3 and via() == "gui", "clic : amélioration depuis le panneau, la cible est la nouvelle entité")
    chk(player.opened == g3 and player.opened_gui_type == GT.entity and eng.writes == w0 + 1,
      "clic : l'interface de la NOUVELLE entité est rouverte (player.opened écrit 1 fois ; " .. (eng.writes - w0) .. ")")
    -- Fermeture TARDIVE de l'ancienne interface (entité détruite), si le moteur la lève encore : le panneau ne bouge pas.
    M.dispatch(ev[defines.events.on_gui_closed], { player_index = 1, entity = g, gui_type = GT.entity, tick = game.tick })
    chk(panel() ~= nil and target() == g3, "clic : ancienne interface fermée (entité détruite), avant ou après la nouvelle : panneau gardé")
    M.run_ticks(60)
    chk(panel() ~= nil and target() == g3, "clic : panneau toujours ouvert 60 ticks après l'amélioration")
    close_gui(g3)
    chk(panel() == nil, "clic : fermer l'interface de la nouvelle entité ferme le panneau")
  end)

  -- Relecture (R1), l'AUTRE ordre : l'interface de l'ancienne entité, encore valide, est fermée pendant le remplacement.
  case("pendant-clic", "fermeture pendant le remplacement (bouton « Améliorer »)", function(chk)
    local g, pos = new_at(GUN, 2)
    open_gui(g)
    local btn = find_el(panel(), "fo_lvl_up")
    local unhook = close_during_replace(g)
    local okc, errc = pcall(M.dispatch, ev[defines.events.on_gui_click], { element = btn, player_index = 1, tick = game.tick })
    local hits = unhook()
    local g3 = s.find_entity(L.name(GUN, 3), pos)
    chk(okc and hits == 1 and not g.valid and g3 ~= nil,
      "ordre « pendant » : l'interface de l'ancienne entité, encore valide, est fermée pendant le remplacement (" .. hits .. " fois"
      .. (okc and "" or (", " .. tostring(errc))) .. ")")
    chk(panel() ~= nil and target() == g3 and via() == "gui" and player.opened == g3,
      "ordre « pendant » : panneau gardé sur la nouvelle entité, son interface rouverte")
    chk(not (UI().upgrading and UI().upgrading[1]), "drapeau d'amélioration retiré à la fin du clic")
    M.run_ticks(60)
    chk(panel() ~= nil and target() == g3, "ordre « pendant » : panneau toujours ouvert 60 ticks après")
    close_gui(g3)
    chk(panel() == nil, "ordre « pendant » : fermer ensuite l'interface ferme le panneau (drapeau retiré)")
  end)

  case("pendant-u", "fermeture pendant le remplacement (touche U, interface ouverte)", function(chk)
    local g, pos = new_at(GUN, 2)
    open_gui(g)
    rawset(player, "selected", g)
    local unhook = close_during_replace(g)
    local oku, erru = pcall(key, "fo-level-up")
    local hits = unhook()
    local g3 = s.find_entity(L.name(GUN, 3), pos)
    chk(oku and hits == 1 and not g.valid and g3 ~= nil, "U, ordre « pendant » : amélioration faite, ancienne interface fermée pendant le remplacement"
      .. (oku and "" or (" (" .. tostring(erru) .. ")")))
    chk(panel() ~= nil and target() == g3 and player.opened == g3,
      "U, ordre « pendant » : panneau gardé sur la nouvelle entité, son interface rouverte")
    chk(not (UI().upgrading and UI().upgrading[1]), "drapeau d'amélioration retiré à la fin de U")
  end)

  -- Relecture : clic gauche sur TOUT bâtiment à niveaux (fo-level-open, liée à « open-gui »), interface ou non.
  case("clic", "le clic gauche ouvre (avec ou sans interface)", function(chk)
    local w = new_at(WALL, 2)
    rawset(player, "selected", w)
    key("fo-level-open")
    chk(panel() ~= nil and target() == w and via() == "click", "clic gauche sur un mur (sans interface) : son panneau s'ouvre")
    M.run_ticks(60)
    key("fo-level-open")
    chk(panel() ~= nil and target() == w, "le panneau ouvert au clic reste (2 rafraîchissements), un 2e clic ne le referme pas")
    -- Bâtiment avec interface, ordre de la doc 1.1.91 : la touche non consommée passe AVANT l'événement du jeu.
    local g = new_at(GUN, 2)
    rawset(player, "selected", g)
    key("fo-level-open")
    open_gui(g)
    chk(panel() ~= nil and target() == g and via() == "gui", "clic puis interface : le panneau passe à la mitrailleuse et suit son interface")
    close_gui(g)
    chk(panel() == nil, "clic puis interface : fermer l'interface ferme le panneau")
    -- Ordre inverse : l'interface d'abord, puis le clic.
    local g2 = new_at(GUN, 2)
    open_gui(g2)
    rawset(player, "selected", g2)
    key("fo-level-open")
    chk(panel() ~= nil and target() == g2 and via() == "gui", "interface puis clic : le clic ne referme pas le panneau et ne le détache pas de l'interface")
    close_gui(g2)
    chk(panel() == nil, "interface puis clic : fermer l'interface ferme le panneau")
    -- Objet en main : le clic gauche pose un bâtiment, il n'ouvre rien.
    local w2 = new_at(WALL, 2)
    rawset(player, "selected", w2)
    rawset(player, "cursor_stack", { valid_for_read = true, name = "stone-wall", count = 10 })
    key("fo-level-open")
    rawset(player, "cursor_stack", nil)
    chk(panel() == nil, "objet en main : le clic gauche n'ouvre pas le panneau")
  end)

  case("muet", "interface fermée sans événement : fermé au rafraîchissement", function(chk)
    local g = new_at(GUN, 2)
    open_gui(g)
    eng.opened, eng.gtype = nil, GT.none -- interface fermée sans on_gui_closed (mort du joueur, doc 1.1.91)
    M.run_ticks(30)
    chk(panel() == nil and target() == nil, "clic : interface fermée sans événement, panneau fermé au rafraîchissement suivant")
  end)

  case("bascule", "passage de « survol » à « clic » : panneau de survol fermé", function(chk)
    local g = new_at(GUN, 2)
    M.set_player_setting(1, P.SETTING, "survol")
    hover(g)
    chk(panel() ~= nil and via() == "hover", "survol : panneau ouvert au survol")
    M.set_player_setting(1, P.SETTING, "clic")
    M.run_ticks(30)
    chk(panel() == nil and target() == nil, "passage en « clic » : le panneau ouvert au survol se ferme au rafraîchissement suivant")
  end)

  -- Témoin : tous les cas, contrôlés par le banc.
  for _, id in ipairs(ORDER) do
    reset()
    local ok, err = pcall(CASES[id].fn, check)
    check(ok, "cas « " .. CASES[id].label .. " » joué sans erreur" .. (ok and "" or (" (" .. tostring(err) .. ")")))
  end
  reset()

  -- Mutants : la règle remplacée pour UN déclencheur ; le cas visé doit échouer.
  local MUTANTS = {
    { case = "survol", name = "le survol ouvre aussi en « clic »", trigger = "hover",
      patch = function(orig, st) if st.has and not (st.open and st.same) then return "open", "hover" end return orig("hover", st) end },
    { case = "ouvre", name = "l'interface n'ouvre rien", trigger = "gui-opened",
      patch = function() return "none" end },
    { case = "ferme", name = "fermer l'interface ne ferme rien", trigger = "gui-closed",
      patch = function() return "none" end },
    { case = "u", name = "U ouvre le panneau en « clic »", trigger = "key-up",
      patch = function(orig, st) if st.has then return "open", "hover" end return orig("key-up", st) end },
    { case = "maju", name = "Maj+U ne ferme jamais", trigger = "key-panel",
      patch = function(orig, st) if st.has then return "open", "key" end return "none" end },
    { case = "maju", name = "Maj+U n'ouvre jamais", trigger = "key-panel",
      patch = function(orig, st) local a, v = orig("key-panel", st); if a == "open" then return "none" end return a, v end },
    { case = "suit", name = "l'interface de la nouvelle entité n'est pas rouverte", trigger = "replaced",
      patch = function() return "none" end },
    { case = "pendant-clic", name = "la fermeture pendant l'amélioration ferme le panneau (drapeau ignoré)", trigger = "gui-closed",
      patch = function(orig, st) if st.open and st.via == "gui" and st.same then return "close" end return "none" end },
    { case = "pendant-u", name = "la fermeture pendant U ferme le panneau (drapeau ignoré)", trigger = "gui-closed",
      patch = function(orig, st) if st.open and st.via == "gui" and st.same then return "close" end return "none" end },
    { case = "clic", name = "le clic gauche n'ouvre rien", trigger = "click",
      patch = function() return "none" end },
    { case = "clic", name = "le clic gauche bascule (referme la cible déjà montrée)", trigger = "click",
      patch = function(orig, st) if st.open and st.same then return "close" end return orig("click", st) end },
    { case = "muet", name = "le rafraîchissement garde un panneau dont l'interface est fermée", trigger = "tick",
      patch = function(orig, st) if st.open and st.via == "gui" then return "refresh" end return orig("tick", st) end },
    { case = "bascule", name = "le rafraîchissement garde en « clic » un panneau ouvert au survol", trigger = "tick",
      patch = function(orig, st) if st.open and st.via ~= "gui" then return "refresh" end return orig("tick", st) end },
  }
  local covered = {}
  for _, m in ipairs(MUTANTS) do
    local orig = P.decide
    P.decide = function(trigger, st)
      if trigger == m.trigger then return m.patch(orig, st) end
      return orig(trigger, st)
    end
    reset()
    local failed = {}
    local ok, err = pcall(CASES[m.case].fn, function(cond, msg) if not cond then failed[#failed + 1] = msg end end)
    P.decide = orig
    reset()
    local detected = #failed > 0 or not ok
    if detected then covered[m.case] = true end
    check(detected, "mutant « " .. m.name .. " » détecté par le cas « " .. CASES[m.case].label .. " » ("
      .. (ok and (#failed .. " contrôle(s) en échec : " .. tostring(failed[1])) or ("erreur : " .. tostring(err))) .. ")")
  end
  local uncovered = {}
  for _, id in ipairs(ORDER) do if not covered[id] then uncovered[#uncovered + 1] = id end end
  check(#uncovered == 0, "chaque cas « clic » a un mutant détecté (" .. #ORDER .. " cas" .. (#uncovered > 0 and (" ; sans : " .. table.concat(uncovered, ", ")) or "") .. ")")

  -- Relecture : changer le réglage PAR JOUEUR n'écrit pas de ligne [FO-REGLAGES] (script/faction/journaux_dc.lua) ; un réglage de
  -- carte en écrit toujours une (contraste).
  local function reglages_after(spec)
    local n0 = #Wd.logs
    spec.tick = game.tick
    local ok = pcall(M.dispatch, ev[defines.events.on_runtime_mod_setting_changed], spec)
    local n = 0
    for i = n0 + 1, #Wd.logs do if Wd.logs[i]:find("[FO-REGLAGES]", 1, true) then n = n + 1 end end
    return ok, n
  end
  local okj1, nj1 = reglages_after({ player_index = 1, setting = P.SETTING, setting_type = "runtime-per-user" })
  check(okj1 and nj1 == 0, "journal : changer le réglage par joueur fo-levels-panneau n'écrit AUCUNE ligne [FO-REGLAGES] (" .. nj1 .. ")")
  local okj2, nj2 = reglages_after({ player_index = 1, setting = "fo-war-robots", setting_type = "runtime-global" })
  check(okj2 and nj2 == 1, "journal : un réglage de carte (fo-war-robots) écrit toujours sa ligne [FO-REGLAGES] (" .. nj2 .. ")")

  -- Retour à l'état d'avant pour la suite du banc.
  reset()
  M.set_player_setting(1, P.SETTING, nil)
  setmetatable(player, mt0)
  rawset(player, "opened", opened0)
  rawset(player, "opened_gui_type", gtype0)
  rawset(player, "selected", sel0)
  rawset(player, "force", home)
  player.gui = gui0
end

--- Réglage, touche (étape data réelle par le harnais) et traductions.
function Cases.data(check, section, game_data_dir)
  check = verbose(check)
  section("Panneau « Évolution » au clic (lot PANNEAU) : réglage, touche, traductions")
  -- Réglage : settings/levels_panneau.lua lu avec un data:extend simulé.
  local declared = {}
  local data0 = rawget(_G, "data")
  _G.data = { extend = function(_, list) for _, p in ipairs(list) do declared[#declared + 1] = p end end }
  package.loaded["settings.levels_panneau"] = nil
  local okr, errr = pcall(require, "settings.levels_panneau")
  package.loaded["settings.levels_panneau"] = nil
  _G.data = data0
  local sp = declared[1]
  check(okr and #declared == 1 and sp.type == "string-setting" and sp.name == "fo-levels-panneau" and sp.setting_type == "runtime-per-user"
    and sp.default_value == "clic" and sp.allowed_values and sp.allowed_values[1] == "clic" and sp.allowed_values[2] == "survol",
    "réglage fo-levels-panneau : chaîne, par joueur, « clic » (défaut) ou « survol »" .. (okr and "" or (" (" .. tostring(errr) .. ")")))
  local fh = io.open("settings.lua", "rb")
  local stxt = fh and fh:read("*a") or ""
  if fh then fh:close() end
  check(stxt:find('\nrequire("settings.levels_panneau")', 1, true) ~= nil, "settings.lua requiert settings/levels_panneau.lua")

  -- Touche : le prototype final de l'étape data réelle (core, base, le mod), par le harnais.
  if game_data_dir then
    local lua = (arg and arg[-1]) or "lua5.2"
    local ph = io.popen(lua .. ' tests/datastage/harness.lua "' .. game_data_dir .. '" . --dump-final custom-input/fo-level-panel 2>&1', "r")
    local out = ph and ph:read("*a") or ""
    if ph then ph:close() end
    check(out:find('key_sequence = "SHIFT + U"', 1, true) ~= nil and out:find('name = "fo-level-panel"', 1, true) ~= nil
      and out:find('consuming = "none"', 1, true) ~= nil,
      "touche fo-level-panel déclarée à l'étape data réelle : Maj+U, non consommée")
    local ph2 = io.popen(lua .. ' tests/datastage/harness.lua "' .. game_data_dir .. '" . --dump-final custom-input/fo-level-up 2>&1', "r")
    local out2 = ph2 and ph2:read("*a") or ""
    if ph2 then ph2:close() end
    check(out2:find('key_sequence = "U"', 1, true) ~= nil, "touche fo-level-up inchangée (U)")
    local ph3 = io.popen(lua .. ' tests/datastage/harness.lua "' .. game_data_dir .. '" . --dump-final custom-input/fo-level-open 2>&1', "r")
    local out3 = ph3 and ph3:read("*a") or ""
    if ph3 then ph3:close() end
    check(out3:find('linked_game_control = "open-gui"', 1, true) ~= nil and out3:find('consuming = "none"', 1, true) ~= nil
      and out3:find('name = "fo-level-open"', 1, true) ~= nil,
      "touche fo-level-open déclarée à l'étape data réelle : liée au clic « open-gui », non consommée")
  else
    check(false, "données du jeu introuvables : touche non vérifiée à l'étape data")
  end

  -- Traductions FR et EN (fichiers du lot).
  for _, lang in ipairs({ "fr", "en" }) do
    local keys, sec = {}, ""
    local f = io.open("locale/" .. lang .. "/levels_panneau.cfg", "r")
    if f then
      for line in f:lines() do
        local h = line:match("^%[(.-)%]")
        if h then sec = h else
          local k, v = line:match("^([^=;#]+)=(.*)$")
          if k then keys[sec .. "." .. k] = v end
        end
      end
      f:close()
    end
    local miss = {}
    for _, k in ipairs({ "mod-setting-name.fo-levels-panneau", "mod-setting-description.fo-levels-panneau",
        "string-mod-setting.fo-levels-panneau-clic", "string-mod-setting.fo-levels-panneau-survol", "controls.fo-level-panel",
        "controls.fo-level-open" }) do
      if not (keys[k] and #keys[k] > 0) then miss[#miss + 1] = k end
    end
    check(f ~= nil and #miss == 0, lang .. " : traductions du lot PANNEAU (réglage, valeurs, touche)" .. (#miss > 0 and (" ; manquent : " .. table.concat(miss, ", ")) or ""))
  end
end

return Cases
