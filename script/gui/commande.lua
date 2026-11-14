--[[
  Lot s43 UX-COMMANDE (pilier B, agent 5) : le COMMANDEMENT de votre équipe d'IA, sans micro-gestion. Règles pures :
  shared/ai3/commande.lua (orientation bornée, buts des gisements désignés, sites et liaisons désignés d'abord).

  Interface : un bouton dans la barre du haut (fo_cmd_button) ouvre un petit panneau (à gauche, non modal) :
    - orientation de l'équipe : Aucune, Expansion économique, Amélioration massive, Défense / Offensive (bouton vert = choisie) ;
    - « Désigner » met en main l'outil de commandement (prototypes/commande.lua) :
        glisser sur un gisement           -> coloniser ce gisement tout de suite (but d'extraction de son type, site de la zone d'abord) ;
        Maj + glisser                     -> liaison prioritaire (les quais et sorties de la zone sont reliés d'abord) ;
        glisser avec le bouton droit      -> annuler les ordres de la zone ;
    - la liste des ordres vivants, chacun avec son bouton « Annuler ».
  Chaque ordre se voit sur la carte : cercle et texte (rendering, force de l'équipe) et une étiquette de carte. Un ordre de gisement
  est rempli (et retiré) dès qu'un avant-poste de son type est posé dans sa zone.

  État : f.team.commande (shared/ai3/commande.lua, Co.new_state ; nombres et chaînes ; numéros des dessins et des étiquettes). Écrit
  seulement depuis les gestionnaires d'événements du joueur (clic, sélection) et la passe de résolution (on_nth_tick), dans le même
  ordre chez tous les joueurs. Aucun pairs décisionnel, aucune lecture locale.
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local Sites = require("script.faction.sites")
local T = require("shared.team.config")
local Co = require("shared.ai3.commande")
local Om = require("shared.team.outil_main") -- s46 crash
local Ds_rule = require("shared.team.defense_stock") -- s46 outils : tourelles voulues d'un bastion (GROUP_CAP)
local TURRET_TYPES = { "ammo-turret", "electric-turret", "fluid-turret" } -- types moteur (aucun nom d'objet)

local Cmd = {}

Cmd.TOOL = "fo-commande-outil"
local BUTTON, FRAME = "fo_cmd_button", "fo_cmd_frame"
local P_ORIENT, P_TOOL, P_CLOSE, P_CANCEL = "fo_cmd_or_", "fo_cmd_tool", "fo_cmd_close", "fo_cmd_cancel_"
local P_GIVE = "fo_cmd_give_" -- lot s45 OUTILS : boutons des quatre outils
Cmd.TOOLS = { "fo-cmd-gisement", "fo-cmd-amelioration", "fo-cmd-liaison", "fo-cmd-bastion" }
local RESOLVE_EVERY = 300
local COLOR = { gisement = { r = 0.25, g = 0.85, b = 0.35, a = 0.8 }, liaison = { r = 0.3, g = 0.6, b = 1, a = 0.8 },
  amelioration = { r = 1, g = 0.75, b = 0.2, a = 0.8 }, bastion = { r = 0.85, g = 0.3, b = 0.85, a = 0.8 } } -- lot s44 COMMANDE-UPGRADE

--- Équipe commandée par ce joueur (celle de sa force), ou nil.
local function team_of(player)
  local f = State.faction("player")
  if f and f.team and f.force == player.force.name then return f end
  return nil
end

--- Lot s45 OUTILS : met l'outil `name` dans la main du joueur (joueur d'une équipe seulement).
-- s46 crash : gardes valid / nil (joueur, prototype, main sans curseur, outil déjà en main) dans shared/team/outil_main.lua.
local function give_tool(player, name)
  if not (player and player.valid) then return end
  if not team_of(player) then
    player.print({ "fo-commande.sans-equipe-outil" }) -- s46 outils : plus de touche muette sans coffre d'équipe
    return
  end
  Om.give(player, name, name ~= nil and game.item_prototypes[name] ~= nil)
end

local function cstate(f)
  if not f.team.commande then f.team.commande = Co.new_state() end
  return f.team.commande
end

---------------------------------------------------------------------------------------------------
-- Carte : dessins et étiquettes d'un ordre
---------------------------------------------------------------------------------------------------
local function order_text(o)
  if o.kind == "gisement" then return { "fo-commande.carte-gisement", { "entity-name." .. tostring(o.resource) } } end
  if o.kind == "amelioration" then return { "fo-commande.carte-amelioration" } end
  if o.kind == "bastion" then return { "fo-commande.carte-bastion" } end -- lot s45 OUTILS -- lot s44 COMMANDE-UPGRADE
  return { "fo-commande.carte-liaison" }
end

local function draw(f, o)
  local surface = game.surfaces[o.surface or 1]
  local force = game.forces[f.force]
  if not (surface and force) then return end
  local c = COLOR[o.kind] or COLOR.liaison
  o.draw = {
    rendering.draw_circle({ color = c, radius = o.r, width = 4, filled = false, target = { x = o.x, y = o.y }, surface = surface,
      forces = { force }, draw_on_ground = true }),
    rendering.draw_text({ text = order_text(o), color = c, target = { x = o.x, y = o.y - o.r - 1 }, surface = surface,
      forces = { force }, scale = 2, alignment = "center" }),
  }
  -- Étiquette de carte : texte riche sans langue (icône du minerai, numéro de l'ordre).
  local ok, tag = pcall(force.add_chart_tag, surface, { position = { x = o.x, y = o.y },
    text = o.kind == "gisement" and ("[entity=" .. tostring(o.resource) .. "] #" .. o.id) or (o.kind == "amelioration" and ("^ #" .. o.id) or (o.kind == "bastion" and ("[!] #" .. o.id) or ("<-> #" .. o.id))) })
  if ok and tag then o.tag = tag.tag_number end
end

local function undraw(f, o)
  for _, id in ipairs(o.draw or {}) do
    if rendering.is_valid(id) then rendering.destroy(id) end
  end
  o.draw = nil
  if o.tag then
    local force, surface = game.forces[f.force], game.surfaces[o.surface or 1]
    if force and surface then
      for _, tag in ipairs(force.find_chart_tags(surface, { { o.x - 1, o.y - 1 }, { o.x + 1, o.y + 1 } })) do
        if tag.valid and tag.tag_number == o.tag then tag.destroy() end
      end
    end
    o.tag = nil
  end
end

---------------------------------------------------------------------------------------------------
-- Panneau
---------------------------------------------------------------------------------------------------
local function ensure_button(player)
  local top = player.gui.top
  if not top[BUTTON] then
    top.add({ type = "sprite-button", name = BUTTON, sprite = "item/" .. Cmd.TOOL, tooltip = { "fo-commande.bouton" } })
  end
end

local function build(player)
  local left = player.gui.left
  if left[FRAME] then left[FRAME].destroy() end
  local f = team_of(player)
  local frame = left.add({ type = "frame", name = FRAME, direction = "vertical", caption = { "fo-commande.titre" } })
  if not f then
    frame.add({ type = "label", caption = { "fo-commande.sans-equipe" } })
    frame.add({ type = "button", name = P_CLOSE, caption = { "fo-commande.fermer" } })
    return
  end
  local cs = cstate(f)
  frame.add({ type = "label", caption = { "fo-commande.orientation" }, style = "caption_label" })
  local row = frame.add({ type = "flow", direction = "horizontal" })
  for _, k in ipairs(Co.ORIENTATIONS) do
    row.add({ type = "button", name = P_ORIENT .. k, caption = { "fo-commande.or-" .. k }, tooltip = { "fo-commande.or-" .. k .. "-aide" },
      style = (cs.orient == k) and "green_button" or "button" })
  end
  frame.add({ type = "line" })
  frame.add({ type = "button", name = P_TOOL, caption = { "fo-commande.designer" }, tooltip = { "fo-commande.designer-aide" } })
  local tools = frame.add({ type = "flow", direction = "horizontal" }) -- lot s45 OUTILS : un outil par action
  for _, name in ipairs(Cmd.TOOLS) do
    tools.add({ type = "sprite-button", name = P_GIVE .. name, sprite = "item/" .. name, tooltip = { "item-description." .. name } })
  end
  local hint = frame.add({ type = "label", caption = { "fo-commande.aide" } })
  hint.style.single_line = false
  hint.style.maximal_width = 420
  local hint2 = frame.add({ type = "label", caption = { "fo-commande.aide-amelioration" } }) -- lot s44 COMMANDE-UPGRADE
  hint2.style.single_line = false
  hint2.style.maximal_width = 420
  frame.add({ type = "line" })
  frame.add({ type = "label", caption = { "fo-commande.ordres", #cs.orders, Co.MAX_ORDERS }, style = "caption_label" })
  for _, o in ipairs(cs.orders) do
    local r = frame.add({ type = "flow", direction = "horizontal" })
    if o.kind == "gisement" then
      r.add({ type = "label", caption = { "fo-commande.ligne-gisement", o.id, { "entity-name." .. tostring(o.resource) }, o.x, o.y } })
    elseif o.kind == "bastion" then -- lot s45 OUTILS
      r.add({ type = "label", caption = { "fo-commande.ligne-bastion", o.id, o.x, o.y, o.r } })
    elseif o.kind == "amelioration" then -- lot s44 COMMANDE-UPGRADE
      r.add({ type = "label", caption = { "fo-commande.ligne-amelioration", o.id, o.x, o.y, o.r } })
    else
      r.add({ type = "label", caption = { "fo-commande.ligne-liaison", o.id, o.x, o.y } })
    end
    r.add({ type = "button", name = P_CANCEL .. o.id, caption = { "fo-commande.annuler" }, style = "red_button" })
  end
  frame.add({ type = "button", name = P_CLOSE, caption = { "fo-commande.fermer" } })
end

--- Rafraîchit le panneau des joueurs de la force qui l'ont ouvert.
local function refresh(f)
  for _, p in ipairs(game.forces[f.force] and game.forces[f.force].connected_players or {}) do
    if p.gui.left[FRAME] then build(p) end
  end
end

local function cancel(f, id, player)
  local o = Co.cancel(cstate(f), id)
  if not o then return end
  undraw(f, o)
  if player then player.print({ "fo-commande.annule", id }) end
  log(string.format("[FO-COMMANDE] %s : ordre %d (%s) annule", tostring(f.key or f.id), id, o.kind))
end

Events.on(defines.events.on_gui_click, function(e)
  local el = e.element
  if not (el and el.valid) then return end
  local name = el.name
  if name:sub(1, #P_GIVE) == P_GIVE then -- lot s45 OUTILS
    give_tool(game.get_player(e.player_index), name:sub(#P_GIVE + 1))
    return
  end
  if name ~= BUTTON and name ~= P_TOOL and name ~= P_CLOSE and name:sub(1, #P_ORIENT) ~= P_ORIENT and name:sub(1, #P_CANCEL) ~= P_CANCEL then
    return
  end
  local player = game.get_player(e.player_index)
  if name == BUTTON then
    if player.gui.left[FRAME] then player.gui.left[FRAME].destroy() else build(player) end
    return
  end
  if name == P_CLOSE then
    if player.gui.left[FRAME] then player.gui.left[FRAME].destroy() end
    return
  end
  local f = team_of(player)
  if not f then return end
  if name == P_TOOL then
    if player.clear_cursor() then player.cursor_stack.set_stack({ name = Cmd.TOOL, count = 1 }) end
    return
  end
  if name:sub(1, #P_ORIENT) == P_ORIENT then
    local k = name:sub(#P_ORIENT + 1)
    if Co.valid_orientation(k) then
      cstate(f).orient = k
      game.forces[f.force].print({ "fo-commande.orient-choisie", player.name, { "fo-commande.or-" .. k } })
      log(string.format("[FO-COMMANDE] %s : orientation %s (tick %d)", tostring(f.key or f.id), k, game.tick))
    end
  else
    local id = tonumber(name:sub(#P_CANCEL + 1))
    if id then cancel(f, id, player) end
  end
  refresh(f)
end)

---------------------------------------------------------------------------------------------------
-- Outil de commandement
---------------------------------------------------------------------------------------------------
local function area_of(e)
  local a = e.area
  return a.left_top.x, a.left_top.y, a.right_bottom.x, a.right_bottom.y
end

local function add_order(f, player, o)
  local cs = cstate(f)
  -- s46 outils : plafond atteint : le plus ancien ordre (liaison, amélioration, bastion d'abord) est remplacé au lieu d'un refus « plein »
  local id, why, old = Co.add_replacing(cs, o)
  if not id then
    player.print({ "fo-commande.refus-" .. why })
    log(string.format("[FO-COMMANDE] %s : ordre %s refuse (%s, tick %d)", tostring(f.key or f.id), o.kind, tostring(why), game.tick))
    return
  end
  if old then
    undraw(f, old)
    player.print({ "fo-commande.remplace", old.id, id })
    log(string.format("[FO-COMMANDE] %s : ordre %d (%s) remplace par l'ordre %d (plafond de %d ordres, tick %d)", tostring(f.key or f.id),
      old.id, old.kind, id, Co.MAX_ORDERS, game.tick))
  end
  local order = cs.orders[#cs.orders]
  draw(f, order)
  log(string.format("[FO-COMMANDE] %s : ordre %d %s %s en (%d, %d) rayon %d (tick %d)", tostring(f.key or f.id), id, o.kind,
    tostring(o.resource or "-"), o.x, o.y, order.r, game.tick))
  player.print({ "fo-commande.pose-" .. o.kind, id })
end

local function do_gisement(e, player, f)
  local names = {}
  for _, ent in ipairs(e.entities or {}) do
    if ent.valid and ent.type == "resource" then names[#names + 1] = ent.name end
  end
  local res = Co.majority(names)
  if not res then
    player.print({ "fo-commande.refus-vide" })
    return
  end
  local kind = Co.kind_of(res, T.outposts, T.OUTPOST_ORDER)
  if not kind then
    player.print({ "fo-commande.refus-ressource" })
    return
  end
  local sx, sy, n = 0, 0, 0
  for _, ent in ipairs(e.entities) do
    if ent.valid and ent.name == res then sx, sy, n = sx + ent.position.x, sy + ent.position.y, n + 1 end
  end
  local x0, y0, x1, y1 = area_of(e)
  local _, _, r = Co.zone(x0, y0, x1, y1)
  local cx, cy = math.floor(sx / n), math.floor(sy / n)
  add_order(f, player, { kind = "gisement", x = cx, y = cy, r = r, resource = res, outpost = kind, tick = game.tick,
    surface = e.surface.index, after_oid = f.next_oid or 0 })
  -- Le gisement entre dans la réserve de sites tout de suite (mêmes règles que la prospection), même hors du disque prospecté.
  -- s44 : sonde de LA ressource désignée, réserve pleine ou ressource pas encore voulue comprises (Sites.probe_at, 5e argument).
  if f.hq_pos then Sites.probe_at(f, e.surface, cx, cy, game.tick, res) end
  refresh(f)
end

local function do_liaison(e, player, f)
  local x0, y0, x1, y1 = area_of(e)
  local cx, cy, r = Co.zone(x0, y0, x1, y1)
  -- s44 commande-liaison : premier Maj + glisser = point A (départ), second = point B (arrivée) ; l'ordre porte les deux zones
  local st = cstate(f)
  if not st.liaison_a then
    st.liaison_a = { x = cx, y = cy, r = r, surface = e.surface.index }
    player.print({ "fo-commande.liaison-a", cx, cy })
    log(string.format("[FO-COMMANDE] %s : liaison point A en (%d, %d) rayon %d (tick %d) : glisser encore sur le point B",
      tostring(f.key or f.id), cx, cy, r, game.tick))
    return
  end
  local a = st.liaison_a
  st.liaison_a = nil
  if a and a.surface ~= e.surface.index then a = nil end
  add_order(f, player, { kind = "liaison", x = cx, y = cy, r = r, a = a, tick = game.tick, surface = e.surface.index })
  refresh(f)
end

-- Lot s44 COMMANDE-UPGRADE : Maj + glisser avec le bouton droit -> zone d'amélioration prioritaire (les bâtiments de l'équipe de la zone
-- qui ont une version supérieure passent en tête des remplacements : shared/ai3/commande.lua Co.upgrade_rank, shared/ai3/capital.lua).
-- Annulation : bouton « Annuler » du panneau ou bouton droit sur la zone.
local function zone_order(kind)
  return function(e, player, f)
    local x0, y0, x1, y1 = area_of(e)
    local cx, cy, r = Co.zone(x0, y0, x1, y1)
    add_order(f, player, { kind = kind, x = cx, y = cy, r = r, tick = game.tick, surface = e.surface.index })
    refresh(f)
  end
end
local do_amelioration, do_bastion = zone_order("amelioration"), zone_order("bastion")

local function do_cancel_area(e, player, f)
  if not f.team.commande then return end
  local x0, y0, x1, y1 = area_of(e)
  for _, id in ipairs(Co.hit(f.team.commande, x0, y0, x1, y1)) do cancel(f, id, player) end
  refresh(f)
end

-- Lot s45 OUTILS : un outil par action. [outil] = { glisser, Maj + glisser, bouton droit, Maj + bouton droit }.
-- L'ancien outil garde ses quatre gestes (compatibilité).
local ACTIONS = {
  [Cmd.TOOL] = { do_gisement, do_liaison, do_cancel_area, do_amelioration },
  ["fo-cmd-gisement"] = { do_gisement, do_gisement, do_cancel_area, do_cancel_area },
  ["fo-cmd-amelioration"] = { do_amelioration, do_amelioration, do_cancel_area, do_cancel_area },
  ["fo-cmd-liaison"] = { do_liaison, do_liaison, do_cancel_area, do_cancel_area },
  ["fo-cmd-bastion"] = { do_bastion, do_bastion, do_cancel_area, do_cancel_area },
}

--- Gestionnaire commun d'une sélection (vraie souris ou interface de banc fo-commande) : rend vrai si l'action a été appelée.
local function handle(slot, e, player)
  local acts = ACTIONS[e.item]
  if not (acts and player) then return false end
  local f = team_of(player)
  if not f then
    player.print({ "fo-commande.sans-equipe-outil" }) -- s46 outils : plus de refus muet sans équipe
    return false
  end
  acts[slot](e, player, f)
  return true
end

local function dispatch(slot)
  return function(e)
    if not ACTIONS[e.item] then return end
    handle(slot, e, game.get_player(e.player_index))
  end
end
Events.on(defines.events.on_player_selected_area, dispatch(1))
Events.on(defines.events.on_player_alt_selected_area, dispatch(2))
Events.on(defines.events.on_player_reverse_selected_area, dispatch(3))
Events.on(defines.events.on_player_alt_reverse_selected_area, dispatch(4))

for _, name in ipairs(Cmd.TOOLS) do
  Events.on(name .. "-touche", function(e) give_tool(game.get_player(e.player_index), name) end)
end


---------------------------------------------------------------------------------------------------
-- Résolution : un avant-poste posé dans la zone remplit l'ordre de gisement
---------------------------------------------------------------------------------------------------
Events.on_nth_tick(RESOLVE_EVERY, function()
  local f = State.faction("player")
  if not (f and f.team and f.team.commande and #f.team.commande.orders > 0) then return end
  local ops = {}
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    if o.pos then ops[#ops + 1] = { kind = o.kind, x = o.pos.x, y = o.pos.y, id = o.id or oid, key = oid,
      covered = o.full and Co.truly_full(o.full_why) or nil,
      saturated = (o.drills or 0) >= T.max_drills(o.kind) or nil } end -- s46 outils : agrandi jusqu'au plafond de foreuses
  end
  -- s45 saturer : un ordre posé sur un avant-poste déjà là le sature : plein levé (sauf gisement vraiment couvert, migration en cours).
  local by_id = {}
  for _, op in ipairs(ops) do by_id[op.id] = op end
  for _, sat in ipairs(Co.saturations(f.team.commande, ops)) do
    local op = by_id[sat.oid]
    local o = op and f.outposts[op.key]
    if o and Co.liftable(o) then
      o.full, o.full_by, o.full_why, o.hold_until, o.ext_fails = false, nil, nil, nil, 0
      log(string.format("[FO-COMMANDE] %s : ordre %d sature l'avant-poste %s (plein leve, tick %d)", tostring(f.key or f.id), sat.order,
        tostring(sat.oid), game.tick))
    end
    if o then o.sat_req = sat.order end
  end
  local done = Co.resolve(f.team.commande, ops)
  -- Un ordre sans site en réserve (réserve pleine, ressource pas encore voulue) : une nouvelle sonde par passe, la plus ancienne d'abord.
  local ready = {}
  for _, o in ipairs(Co.ready(Co.deposits(f.team.commande), f.prospects)) do ready[o.id] = true end
  for _, o in ipairs(Co.deposits(f.team.commande)) do
    local surface = game.surfaces[o.surface or 1]
    if not ready[o.id] and f.hq_pos and surface then
      Sites.probe_at(f, surface, o.x, o.y, game.tick, o.resource)
      break
    end
  end
  for _, id in ipairs(done) do
    local o = Co.cancel(f.team.commande, id)
    if o then
      undraw(f, o)
      if game.forces[f.force] then game.forces[f.force].print({ "fo-commande.rempli", id, { "entity-name." .. tostring(o.resource) } }) end
      log(string.format("[FO-COMMANDE] %s : ordre %d rempli (avant-poste %s pose dans la zone, tick %d)", tostring(f.key or f.id), id,
        tostring(o.outpost), game.tick))
    end
  end
  -- s46 outils : bastion servi (tourelles de l'équipe dans la zone, Ds_rule.GROUP_CAP au moins) : marqué fini. Liaison finie ou refusée :
  -- marquée par script/team/liaison.lua. Les ordres marqués sont retirés ici (plus de plafond de 8 ordres jamais vidé).
  local cs = f.team.commande
  local lst = f.build and f.build.liaison
  for _, o in ipairs(cs.orders) do
    if o.kind == "liaison" and not (lst and lst.seen_docks) then
      -- le relevé des liaisons ne tourne qu'avec la centrale finie et des modules finis (script/team/liaison.lua) : la cause est écrite
      if Co.note(cs, o.id, "liaison en attente : aucun releve des quais et sorties (centrale et modules finis requis)") then
        log(string.format("[FO-COMMANDE] %s : ordre %d liaison en attente : aucun releve des quais et sorties (centrale et modules finis requis, tick %d)",
          tostring(f.key or f.id), o.id, game.tick))
      end
    end
    if o.kind == "bastion" and not o.done then
      local surface = game.surfaces[o.surface or 1]
      local n = surface and surface.count_entities_filtered({ position = { o.x, o.y }, radius = o.r, force = f.force,
        type = TURRET_TYPES }) or 0
      if n ~= o.have then
        o.have = n
        if Co.note(cs, o.id, string.format("bastion : %d tourelle(s) dans la zone sur %d voulues", n, Ds_rule.GROUP_CAP)) then
          log(string.format("[FO-COMMANDE] %s : ordre %d bastion : %d tourelle(s) dans la zone sur %d voulues (tick %d)",
            tostring(f.key or f.id), o.id, n, Ds_rule.GROUP_CAP, game.tick))
        end
      end
      if n >= Ds_rule.GROUP_CAP then Co.mark(cs, o.id, "fini") end
    end
  end
  local n_fin = 0
  for _, id in ipairs(Co.finished(cs)) do
    local o = Co.cancel(cs, id)
    if o then
      n_fin = n_fin + 1
      undraw(f, o)
      if game.forces[f.force] then game.forces[f.force].print({ "fo-commande.fini-" .. o.kind, id }) end
      log(string.format("[FO-COMMANDE] %s : ordre %d (%s) retire : %s (tick %d)", tostring(f.key or f.id), id, o.kind, tostring(o.done), game.tick))
    end
  end
  if #done > 0 or n_fin > 0 then refresh(f) end
end)

local function all_buttons()
  for _, p in pairs(game.players) do ensure_button(p) end
end
Events.on_init(all_buttons)
Events.on_configuration_changed(all_buttons)
Events.on(defines.events.on_player_created, function(e) ensure_button(game.get_player(e.player_index)) end)

---------------------------------------------------------------------------------------------------
-- s46 outils : interface de BANC (aucun joueur connecté) : une sélection construite comme celle du moteur, passée au MÊME gestionnaire
-- (handle) pour l'équipe de la force « player » ; le joueur factice écrit ses messages au journal ([FO-COMMANDE-BANC]).
---------------------------------------------------------------------------------------------------
local function bench_player(prints)
  local force = game.forces.player
  return { valid = true, name = "banc", index = 0, force = force,
    print = function(msg)
      local text = serpent.line(msg)
      prints[#prints + 1] = text
      log("[FO-COMMANDE-BANC] " .. text)
    end }
end

remote.add_interface("fo-commande", {
  --- Sélection de l'outil `outil` (slot 1 glisser, 2 Maj + glisser, 3 bouton droit, 4 Maj + bouton droit) sur la zone donnée.
  --- Rend { appel = vrai si le gestionnaire a tourné, id = ordre posé ou nil, prints = messages au joueur }.
  ordre = function(outil, slot, x0, y0, x1, y1)
    local surface = game.surfaces[1]
    local area = { left_top = { x = math.min(x0, x1), y = math.min(y0, y1) }, right_bottom = { x = math.max(x0, x1), y = math.max(y0, y1) } }
    local box = { { area.left_top.x, area.left_top.y }, { area.right_bottom.x, area.right_bottom.y } }
    local mode_res = outil == "fo-cmd-gisement" and slot <= 2
    local ents = mode_res and surface.find_entities_filtered({ area = box, type = "resource" }) or surface.find_entities_filtered({ area = box })
    local e = { item = outil, area = area, surface = surface, entities = ents, tick = game.tick, player_index = 0 }
    local prints = {}
    local f = State.faction("player")
    local before = f and f.team and f.team.commande and f.team.commande.next_id or 1
    local called = handle(slot, e, bench_player(prints))
    local after = f and f.team and f.team.commande and f.team.commande.next_id or 1
    log(string.format("[FO-COMMANDE-BANC] ordre %s slot %d zone (%d, %d)-(%d, %d) : %d entite(s), gestionnaire %s, ordre %s (tick %d)",
      tostring(outil), slot, x0, y0, x1, y1, #ents, tostring(called), after > before and tostring(after - 1) or "aucun", game.tick))
    return { appel = called, id = after > before and (after - 1) or nil, prints = prints }
  end,
  --- État lisible : QG, ordres vivants, traces (Co.note), avant-postes de l'équipe, liaison point A.
  etat = function()
    local f = State.faction("player")
    if not (f and f.team) then return { equipe = false } end
    local cs = f.team.commande or Co.new_state()
    local out = { equipe = true, force = f.force, hq = f.hq_pos and { x = f.hq_pos.x, y = f.hq_pos.y } or nil, orders = {}, hist = {},
      outposts = {}, liaison_a = cs.liaison_a, next_id = cs.next_id }
    for _, o in ipairs(cs.orders) do
      out.orders[#out.orders + 1] = { id = o.id, kind = o.kind, x = o.x, y = o.y, r = o.r, resource = o.resource, outpost = o.outpost,
        after_oid = o.after_oid, done = o.done, have = o.have }
    end
    for _, h in ipairs(cs.hist or {}) do out.hist[#out.hist + 1] = { id = h.id, text = h.text } end
    for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
      local o = f.outposts[oid]
      if o.pos then out.outposts[#out.outposts + 1] = { id = o.id or oid, kind = o.kind, x = o.pos.x, y = o.pos.y, drills = o.drills or 0,
        full = o.full, full_why = o.full_why } end
    end
    local lst = f.build and f.build.liaison
    out.docks, out.srcs = lst and lst.seen_docks or {}, lst and lst.seen_srcs or {}
    return out
  end,
})

return Cmd
