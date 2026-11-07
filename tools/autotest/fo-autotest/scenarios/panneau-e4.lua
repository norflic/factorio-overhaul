--[[
  Lot PANNEAU-E4 (7/11) : le panneau « Évolution » au CLIC (livré en 0.6.52), joué par un VRAI joueur dans une session
  AVEC images. Objectif E4 d'OBJECTIFS.md : « Jamais vue à l'écran en moteur réel ». Lancement (place 1, par la file) :
    py -3.9 -B tools/autotest/banc.py --captures --qui PANNEAU --out <archive> -- 600 panneau-e4 "<source>"
  Sans images (fo-autotest.bat seul), aucun joueur n'est connecté : rien n'est joué, seule la pose est contrôlée.
  Journal : [FO-PANNEAU-E4] dans fo-shots\factorio.log ; captures fo-shots\x-panneau-NN-<geste>.png (show_gui).

  Ce que le MOTEUR fait lui-même (doc 1.1.91) : écrire p.opened = bâtiment ouvre son interface et lève on_gui_opened ;
  p.opened = nil la ferme et lève on_gui_closed ; écrire p.opened quand une interface est ouverte « prie » celle-ci de se fermer ;
  écrire p.selected lève on_selected_entity_changed. Ce qu'un script ne lève pas (touches U, Maj+U, clic gauche lié à
  « open-gui », bouton du panneau ; réglage par joueur d'un autre mod) passe par l'interface distante « fo-panneau » du mod,
  qui appelle les MÊMES gestionnaires (script/levels/panel.lua). Les raccourcis eux-mêmes (U, Maj+U, clic) restent à essayer
  à la main par le DC.

  Base : centre 15 de la force du joueur (paie), et en ligne : mitrailleuses niveau 2 G1 à G4, murs niveau 2 W1 et W2, une
  tourelle laser niveau 2 L1.

  v2 (7/11, vers 17 h 50) : premier passage c3ce6c0d : BILAN 29 OK, 0 ECHEC, mais la couche d'interface de chaque capture
  était celle du rendu PRÉCÉDENT (décor à jour) : captures prises 30 ticks après le geste, caméra décalée, gestes espacés.
  Les attendus ci-dessous ne changent pas.

  ATTENDUS (écrits AVANT le premier passage, 7/11 ; un écart est un ECHEC, jamais un attendu réécrit après coup) :
    E0  joueur connecté ; réglage « clic » écrit par le mod et relu (state.mode = clic) ; centre 15 de la force du joueur.
    E1  survol en « clic » : p.selected = G1 accepté, AUCUN panneau.
    E2  p.opened = G1 : interface ouverte (opened = G1, type entity), panneau ouvert sur G1, via « gui » ; boutons fo_lvl_up et
        fo_lvl_close présents.
    E3  70 ticks plus tard (2 rafraîchissements) : panneau toujours ouvert sur G1, interface toujours G1.
    E4  p.opened = nil : panneau fermé dans le même tick.
    E5  Maj+U (gestionnaire) sur le mur W1 survolé : panneau ouvert sur W1, via « key » ; Maj+U de nouveau : fermé.
    E6  U (gestionnaire) sur G2 survolée, sans panneau : G2 passe au niveau 3 (nouvelle entité à la même place), AUCUN panneau.
    E7  R2, LE POINT OUVERT : interface de G3 ouverte, clic « Améliorer » (bouton réel du panneau) : G3 passe au niveau 3, et
        DANS LE MÊME TICK l'interface ouverte est celle de la NOUVELLE entité (opened = son numéro, type entity), panneau ouvert
        sur elle, via « gui » ; 70 ticks plus tard, les deux tiennent toujours.
    E8  U (gestionnaire) avec l'interface de G3 (niveau 3) ouverte et G3 survolée : niveau 4, interface et panneau suivent la
        nouvelle entité. Puis p.opened = nil : fermé.
    E9  réglage par joueur passé à « survol » par le mod : survoler G4 ouvre son panneau (via « hover ») ; repassé à « clic » :
        ce panneau se ferme au rafraîchissement suivant (au plus 30 ticks).
    E10 clic gauche lié (gestionnaire de fo-level-open) sur le mur W2 survolé, main vide : panneau ouvert sur W2, via « click ».
    E11 bouton « Fermer » du panneau (élément réel) : panneau fermé.
    FAIT (relevé, pas un attendu) : p.opened = L1 (tourelle laser) est-il accepté par le moteur (interface ouverte) ?
]]

local LV = require("__factorio-overhaul__/shared/levels/config")

local X, Y = 400, 400
local CHECK = 760
local G, W, LA, CC = LV.by_key.gun, LV.by_key.wall, LV.by_key.laser, LV.by_key.command

local function P(ctx, fn, ...) return ctx.remote("fo-panneau", fn, ...) end

local function at(name, pos)
  local list = game.surfaces[1].find_entities_filtered({ name = name, position = pos, radius = 0.6 })
  return list[1]
end

local function gun_at(n, pos) return at(LV.name(G, n), pos) end

-- v2 (7/11, après le passage c3ce6c0d) : la couche d'INTERFACE d'une capture est celle du dernier rendu AVANT la demande (le
-- décor, lui, est à jour) : chaque capture est donc prise SHOT_DELAY ticks après le geste, l'état restant stable jusque-là ; la
-- caméra est décalée de SHOT_DX tuiles vers l'est pour que le bâtiment visé sorte de sous l'interface et la fenêtre du journal.
local SHOT_DELAY, SHOT_DX = 30, 12

local function take(ctx, p, c)
  local st = ctx.state()
  local r = p.display_resolution
  local w, h = math.min(4096, math.max(640, r.width)), math.min(4096, math.max(360, r.height))
  game.take_screenshot({ path = "fo-shots/" .. c.file, player = p, show_gui = true, position = { c.x + SHOT_DX, c.y }, zoom = 1.5,
    resolution = { w, h }, daytime = 0, force_render = true, allow_in_replay = true })
  st.files = st.files or {}
  st.files[#st.files + 1] = c.file
  ctx.log(string.format("capture %s prise au tick %d (geste au tick %d ; %d x %d, echelle %.2f)", c.file, game.tick, c.asked, w, h,
    p.display_scale))
end

local function shot(ctx, p, name, pos, delay)
  local st = ctx.state()
  st.n = (st.n or 0) + 1
  st.pending = st.pending or {}
  st.pending[#st.pending + 1] = { file = string.format("x-panneau-%02d-%s.png", st.n, name), x = pos.x, y = pos.y,
    asked = game.tick, at = game.tick + (delay or SHOT_DELAY) }
end

--- Joueur près d'une position (portée de l'interface d'un personnage), sans le poser sur un bâtiment.
local function near(p, pos)
  local s = game.surfaces[1]
  local q = s.find_non_colliding_position("character", { pos.x, pos.y + 3 }, 6, 0.5) or { pos.x, pos.y + 3 }
  p.teleport(q, s)
end

local function S(ctx, p) return P(ctx, "state", p.index) or {} end

local function fmt_state(s)
  return string.format("mode=%s open=%s via=%s target=%s opened=%s type=%s selected=%s", tostring(s.mode), tostring(s.open),
    tostring(s.via), tostring(s.target), tostring(s.opened), tostring(s.opened_type), tostring(s.selected))
end

local function has_button(s, name)
  for _, b in ipairs(s.buttons or {}) do if b == name then return true end end
  return false
end

local steps = {}

steps[60] = function(ctx, p, st)
  st.player_seen = true
  ctx.log("joueur " .. p.index .. " : controleur " .. tostring(p.controller_type) .. ", personnage " .. tostring(p.character ~= nil))
  p.opened = nil
  local m = P(ctx, "set_mode", p.index, "clic")
  local s = S(ctx, p)
  ctx.check(m == "clic" and s.mode == "clic" and not s.open, "E0 reglage par joueur ecrit par le mod et relu : clic", fmt_state(s))
end

steps[100] = function(ctx, p, st)
  local g1 = at(LV.name(G, 2), st.g1)
  near(p, g1.position)
  p.selected = g1
  local s = S(ctx, p)
  ctx.check(s.selected == g1.unit_number, "E1 survol accepte par le moteur (p.selected = G1)", fmt_state(s))
  ctx.check(not s.open and not s.frame, "E1 survol en clic : aucun panneau", fmt_state(s))
  shot(ctx, p, "survol-clic", g1.position)
end

steps[140] = function(ctx, p, st)
  local g1 = at(LV.name(G, 2), st.g1)
  p.opened = g1
  local s = S(ctx, p)
  ctx.check(s.opened == g1.unit_number and s.opened_type == defines.gui_type.entity, "E2 interface de G1 ouverte par le moteur", fmt_state(s))
  ctx.check(s.open and s.frame and s.target == g1.unit_number and s.via == "gui", "E2 panneau ouvert sur G1 par l'interface", fmt_state(s))
  ctx.check(has_button(s, "fo_lvl_up") and has_button(s, "fo_lvl_close"), "E2 boutons Ameliorer et Fermer", table.concat(s.buttons or {}, ","))
  shot(ctx, p, "interface-ouverte", g1.position)
end

steps[210] = function(ctx, p, st)
  local g1 = at(LV.name(G, 2), st.g1)
  local s = S(ctx, p)
  ctx.check(s.open and s.target == g1.unit_number and s.opened == g1.unit_number, "E3 70 ticks apres : panneau et interface tiennent", fmt_state(s))
end

steps[220] = function(ctx, p, st)
  local g1 = at(LV.name(G, 2), st.g1)
  p.opened = nil
  local s = S(ctx, p)
  ctx.check(not s.open and not s.frame and s.opened == nil, "E4 interface fermee : panneau ferme dans le meme tick", fmt_state(s))
  shot(ctx, p, "interface-fermee", g1.position)
end

steps[260] = function(ctx, p, st)
  local w1 = at(LV.name(W, 2), st.w1)
  near(p, w1.position)
  p.selected = w1
  local ok = P(ctx, "input", p.index, "fo-level-panel")
  local s = S(ctx, p)
  ctx.check(ok and s.open and s.target == w1.unit_number and s.via == "key", "E5 Maj+U sur le mur W1 : panneau ouvert", fmt_state(s))
  shot(ctx, p, "majU-mur", w1.position)
end

steps[300] = function(ctx, p, st)
  local w1 = at(LV.name(W, 2), st.w1)
  p.selected = w1
  P(ctx, "input", p.index, "fo-level-panel")
  local s = S(ctx, p)
  ctx.check(not s.open and not s.frame, "E5 Maj+U de nouveau : panneau ferme", fmt_state(s))
end

steps[340] = function(ctx, p, st)
  local g2 = at(LV.name(G, 2), st.g2)
  near(p, g2.position)
  p.selected = g2
  P(ctx, "input", p.index, "fo-level-up")
  local g2b = gun_at(3, st.g2)
  local s = S(ctx, p)
  ctx.check(not g2.valid and g2b ~= nil, "E6 U sur G2 survolee : niveau 3", g2b and g2b.name)
  ctx.check(not s.open and not s.frame, "E6 U en clic : aucun panneau", fmt_state(s))
  shot(ctx, p, "U-sans-panneau", st.g2)
end

steps[380] = function(ctx, p, st)
  local g3 = at(LV.name(G, 2), st.g3)
  near(p, g3.position)
  p.opened = g3
  local s = S(ctx, p)
  st.g3_unit = g3.unit_number
  ctx.check(s.open and s.target == g3.unit_number and s.opened == g3.unit_number, "E7 avant : interface et panneau de G3 (niveau 2)", fmt_state(s))
  shot(ctx, p, "avant-amelioration", g3.position)
end

steps[420] = function(ctx, p, st)
  local clicked = P(ctx, "click", p.index, "fo_lvl_up")
  local g3b = gun_at(3, st.g3)
  local s = S(ctx, p)
  st.g3b_unit = g3b and g3b.unit_number
  ctx.check(clicked and g3b ~= nil and g3b.unit_number ~= st.g3_unit, "E7 clic Ameliorer : G3 au niveau 3, nouvelle entite",
    string.format("clic=%s nouvelle=%s ancienne=%s", tostring(clicked), tostring(st.g3b_unit), tostring(st.g3_unit)))
  ctx.check(g3b ~= nil and s.opened == g3b.unit_number and s.opened_type == defines.gui_type.entity,
    "E7 R2 : dans le meme tick, l'interface ouverte est celle de la NOUVELLE entite", fmt_state(s))
  ctx.check(g3b ~= nil and s.open and s.target == g3b.unit_number and s.via == "gui", "E7 R2 : panneau ouvert sur la nouvelle entite", fmt_state(s))
  shot(ctx, p, "juste-apres-amelioration", st.g3)
end

steps[490] = function(ctx, p, st)
  local s = S(ctx, p)
  ctx.check(st.g3b_unit ~= nil and s.opened == st.g3b_unit and s.open and s.target == st.g3b_unit,
    "E7 R2 : 70 ticks apres, interface et panneau tiennent sur la nouvelle entite", fmt_state(s))
  shot(ctx, p, "70-ticks-apres", st.g3, 0)
end

steps[500] = function(ctx, p, st)
  local g3b = gun_at(3, st.g3)
  if g3b then p.selected = g3b end
  P(ctx, "input", p.index, "fo-level-up")
  local g3c = gun_at(4, st.g3)
  local s = S(ctx, p)
  ctx.check(g3c ~= nil and s.opened == g3c.unit_number and s.open and s.target == g3c.unit_number,
    "E8 U interface ouverte : niveau 4, interface et panneau suivent", fmt_state(s))
  shot(ctx, p, "U-interface-ouverte", st.g3)
end

steps[540] = function(ctx, p, st)
  p.opened = nil
  local s = S(ctx, p)
  ctx.check(not s.open and not s.frame, "E8 interface fermee : panneau ferme", fmt_state(s))
end

steps[560] = function(ctx, p, st)
  local g4 = at(LV.name(G, 2), st.g4)
  near(p, g4.position)
  local m = P(ctx, "set_mode", p.index, "survol")
  p.selected = nil
  p.selected = g4
  local s = S(ctx, p)
  ctx.check(m == "survol" and s.mode == "survol", "E9 reglage par joueur passe a survol", fmt_state(s))
  ctx.check(s.open and s.target == g4.unit_number and s.via == "hover", "E9 survol : le survol ouvre le panneau", fmt_state(s))
  shot(ctx, p, "survol", g4.position)
end

steps[600] = function(ctx, p, st)
  local m = P(ctx, "set_mode", p.index, "clic")
  st.back_tick = game.tick
  ctx.check(m == "clic", "E9 reglage repasse a clic", tostring(m))
end

steps[640] = function(ctx, p, st)
  local s = S(ctx, p)
  ctx.check(not s.open and not s.frame, "E9 repasse en clic : panneau de survol ferme au rafraichissement", fmt_state(s))
end

steps[660] = function(ctx, p, st)
  local w2 = at(LV.name(W, 2), st.w2)
  near(p, w2.position)
  p.selected = w2
  local cs = p.cursor_stack
  local empty = not (cs and cs.valid_for_read)
  local ok = P(ctx, "input", p.index, "fo-level-open")
  local s = S(ctx, p)
  ctx.check(ok and empty and s.open and s.target == w2.unit_number and s.via == "click",
    "E10 clic gauche lie sur le mur W2, main vide : panneau ouvert", fmt_state(s) .. " main_vide=" .. tostring(empty))
  shot(ctx, p, "clic-mur", w2.position)
end

steps[700] = function(ctx, p, st)
  local closed = P(ctx, "click", p.index, "fo_lvl_close")
  local s = S(ctx, p)
  ctx.check(closed and not s.open and not s.frame, "E11 bouton Fermer : panneau ferme", fmt_state(s))
  -- FAIT : l'interface d'une tourelle laser (electric-turret) s'ouvre-t-elle ?
  local l1 = at(LV.name(LA, 2), st.l1)
  if l1 then
    near(p, l1.position)
    p.opened = l1
    local s2 = S(ctx, p)
    st.laser_fact = string.format("p.opened = laser : opened=%s type=%s (laser %s), panneau open=%s via=%s", tostring(s2.opened),
      tostring(s2.opened_type), tostring(l1.unit_number), tostring(s2.open), tostring(s2.via))
    ctx.log("FAIT " .. st.laser_fact)
    p.opened = nil
  end
  st.done = true
end

return {
  description = "PANNEAU-E4 : panneau Evolution au clic, joue par un vrai joueur (session avec images)",
  base = nil,
  check_tick = CHECK,
  shots_delay = CHECK + 60,

  init = function(ctx)
    local s = ctx.surface()
    ctx.prepare_area(X - 8, Y - 16, X + 44, Y + 12, "grass-1")
    local st = ctx.state()
    local cc = s.create_entity({ name = LV.name(CC, 15), position = { X + 18, Y - 9 }, force = "player", raise_built = true })
    local inv = cc and cc.get_inventory(defines.inventory.chest)
    if inv then
      for _ = 1, 4 do
        for n = 3, 4 do for _, c in ipairs(LV.cost(G, n)) do inv.insert({ name = c[1], count = c[2] }) end end
      end
    end
    local status = ctx.call("levels_status", "player")
    ctx.check(cc ~= nil and status and status.cc_level == 15, "E0 centre 15 de la force du joueur", status and status.cc_level)
    local function put(family, n, x, y)
      local e = s.create_entity({ name = LV.name(family, n), position = { x, y }, force = "player", raise_built = true })
      return e and e.position
    end
    st.g1 = put(G, 2, X, Y)
    st.w1 = put(W, 2, X + 6.5, Y + 0.5)
    st.g2 = put(G, 2, X + 12, Y)
    st.g3 = put(G, 2, X + 18, Y)
    st.g4 = put(G, 2, X + 24, Y)
    st.w2 = put(W, 2, X + 30.5, Y + 0.5)
    st.l1 = put(LA, 2, X + 36, Y)
    ctx.check(st.g1 and st.w1 and st.g2 and st.g3 and st.g4 and st.w2 and st.l1, "E0 base posee (4 mitrailleuses, 2 murs, 1 laser, niveau 2)")
    ctx.check(ctx.has("fo-panneau", "state") and ctx.has("fo-panneau", "click"), "E0 interface distante fo-panneau du mod")
  end,

  tick = function(ctx, e)
    local st0 = ctx.state()
    local p0 = game.connected_players[1]
    if p0 and st0.pending and #st0.pending > 0 then
      local keep = {}
      for _, c in ipairs(st0.pending) do
        if c.at <= e.tick then take(ctx, p0, c) else keep[#keep + 1] = c end
      end
      st0.pending = keep
    end
    local fn = steps[e.tick]
    if not fn then return end
    local p = game.connected_players[1]
    if not p then
      if e.tick == 60 then ctx.log("aucun joueur connecte (banc sans images) : rien n'est joue") end
      return
    end
    fn(ctx, p, ctx.state())
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.player_seen then
      ctx.log("banc sans images : aucun geste joue (attendu)")
      return
    end
    ctx.check(st.done == true, "tous les gestes joues (E0 a E11)")
    ctx.log("captures : " .. table.concat(st.files or {}, ", "))
    if st.laser_fact then ctx.log("FAIT " .. st.laser_fact) end
  end,

  shots = function(ctx, add)
    add("panneau-e4-sol", X + 18, Y, 1, 0)
  end,
}
