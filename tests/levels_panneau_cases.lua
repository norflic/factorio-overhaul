--[[
  Lot PANNEAU (4/11) : QUAND s'ouvre le panneau « Évolution » (règle pure shared/levels/panneau.lua, script/levels/panel.lua,
  réglage par joueur fo-levels-panneau). Joué par tests/levels_test.lua (fichier à part : le bloc principal de levels_test est
  à la limite des 200 variables locales de Lua 5.2).

  Demande du DC (4/11, vers 19 h 40) : « Aussi pour les pop-ups d'améliorations ou autre, dès que le curseur passe sur un truc,
  c'est ultra chiant. Il faudrait que ce soit déclenchable ou même dans l'interface uniquement quand on clique sur le bâtiment
  concerné. »

  Cases.pure    : la table de décision, déclencheur par déclencheur.
  Cases.runtime : 8 cas en « clic » dans le moteur simulé (le survol n'ouvre pas ; l'interface ouverte ouvre ; l'interface
                  fermée ferme ; U améliore sans ouvrir ; Maj+U ouvre puis ferme ; après une amélioration, le panneau suit la
                  nouvelle entité et son interface est rouverte ; interface fermée sans événement : fermé au rafraîchissement ;
                  panneau ouvert au survol puis passage en « clic » : fermé au rafraîchissement), puis CHAQUE cas rejoué avec
                  son mutant (Panneau.decide remplacé pour un seul déclencheur) : le cas doit échouer. Enfin le réglage, la
                  touche (étape data réelle, harnais) et les traductions FR et EN.
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

  local UI = function() return global.fo.levels_ui end
  local function panel() return player.gui.left["fo_lvl_panel"] end
  local function target() return UI().target[1] end
  local function via() return UI().via and UI().via[1] end
  local function reset()
    local f = panel()
    if f then f.destroy() end
    UI().target[1], UI().unit[1] = nil, nil
    if UI().via then UI().via[1] = nil end
    rawset(player, "opened", nil)
    rawset(player, "opened_gui_type", GT.none)
    rawset(player, "selected", nil)
    M.set_player_setting(1, P.SETTING, "clic")
  end
  local function hover(e)
    rawset(player, "selected", nil)
    rawset(player, "selected", e)
    M.dispatch(ev[defines.events.on_selected_entity_changed], { player_index = 1, tick = game.tick })
  end
  --- Le moteur ouvre l'interface (opened, opened_gui_type) PUIS lève on_gui_opened.
  local function open_gui(e)
    rawset(player, "opened", e)
    rawset(player, "opened_gui_type", GT.entity)
    M.dispatch(ev[defines.events.on_gui_opened], { player_index = 1, entity = e, gui_type = GT.entity, tick = game.tick })
  end
  local function close_gui(e)
    rawset(player, "opened", nil)
    rawset(player, "opened_gui_type", GT.none)
    M.dispatch(ev[defines.events.on_gui_closed], { player_index = 1, entity = e, gui_type = GT.entity, tick = game.tick })
  end
  local function key(name)
    M.dispatch(ev[name], { player_index = 1, input_name = name, tick = game.tick })
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
    M.dispatch(ev[defines.events.on_gui_click], { element = btn, player_index = 1, tick = game.tick })
    local g3 = s.find_entity(L.name(GUN, 3), pos)
    chk(not g.valid and g3 ~= nil and target() == g3 and via() == "gui", "clic : amélioration depuis le panneau, la cible est la nouvelle entité")
    chk(rawget(player, "opened") == g3, "clic : l'interface de la NOUVELLE entité est rouverte (player.opened écrit)")
    -- Ce que le moteur lève à l'écriture de `opened` (doc 1.1.91) : fermeture de l'ancienne interface (entité détruite), puis
    -- ouverture de la nouvelle. Le panneau ne bouge pas.
    M.dispatch(ev[defines.events.on_gui_closed], { player_index = 1, entity = g, gui_type = GT.entity, tick = game.tick })
    M.dispatch(ev[defines.events.on_gui_opened], { player_index = 1, entity = g3, gui_type = GT.entity, tick = game.tick })
    chk(panel() ~= nil and target() == g3, "clic : fermeture de l'ancienne interface (entité détruite) puis ouverture de la nouvelle : panneau gardé")
    M.run_ticks(60)
    chk(panel() ~= nil and target() == g3, "clic : panneau toujours ouvert 60 ticks après l'amélioration")
    close_gui(g3)
    chk(panel() == nil, "clic : fermer l'interface de la nouvelle entité ferme le panneau")
  end)

  case("muet", "interface fermée sans événement : fermé au rafraîchissement", function(chk)
    local g = new_at(GUN, 2)
    open_gui(g)
    rawset(player, "opened", nil) -- interface fermée sans on_gui_closed (mort du joueur, doc 1.1.91)
    rawset(player, "opened_gui_type", GT.none)
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

  -- Retour à l'état d'avant pour la suite du banc.
  reset()
  M.set_player_setting(1, P.SETTING, nil)
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
        "string-mod-setting.fo-levels-panneau-clic", "string-mod-setting.fo-levels-panneau-survol", "controls.fo-level-panel" }) do
      if not (keys[k] and #keys[k] > 0) then miss[#miss + 1] = k end
    end
    check(f ~= nil and #miss == 0, lang .. " : traductions du lot PANNEAU (réglage, valeurs, touche)" .. (#miss > 0 and (" ; manquent : " .. table.concat(miss, ", ")) or ""))
  end
end

return Cases
