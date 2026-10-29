--[[
  Interface de gestion en jeu « Équipe et factions » (lot IA1-i, docs/EQUIPES_PNJ.md §8 ; demande du Directeur
  Créatif, 25/10 : « l'idée serait plutôt d'avoir une interface. Pas des commandes à taper »).

  Accès : bouton de la barre de raccourcis « fo-team-gui » et touche « fo-team-gui » (Maj + T par défaut ;
  prototypes/gui.lua). Échap ferme la fenêtre (elle est `player.opened`).

  Onglets (shared/gui/ia1i.lua, M.TABS) :
    Mon équipe   objectif, ce qui manque, effectifs par pôle, managers, coffre, journal récent ; sans équipe : comment
                 poser un coffre d'équipe ;
    Orientation  les 5 préréglages et leur effet ; « Renvoyer l'équipe » avec confirmation dans la fenêtre ;
    Factions     une carte par faction (caractère, relation avec vous, posture du chef, cible, forces, ce qu'elle sait
                 de vous) ; lancer ou arrêter la guerre (arrêt confirmé dans la fenêtre) ;
    PNJ          un PNJ par ligne (rôle, pôle, tâche, pôle de destination) ;
    Partie       statistiques de la partie (lot PANEL-STATS) : avancée et forces de chaque équipe, production des machines
                 et des mains des PNJ (séparées), tâches des PNJ ; lecture seule (script/gui/partie.lua) ;
    Territoire, Chantiers : « à venir » (lots IA1-g, IA1-d, IA1-f), sans faux chiffres.

  AUCUNE seconde logique : chaque bouton appelle la fonction de la commande correspondante :
    préréglage      -> Poles.set_orientation (comme « /fo-team orientation » et l'interface distante « fo-ia1 ») ;
    renvoi confirmé -> PlayerTeam.dismiss(f, true) (comme « /fo-team dismiss ») ;
    lancer          -> War.start(joueur, fo-war-factions, fo-war-soldiers, nil, F.defaults.distance) : les RÉGLAGES DE
                       CARTE, comme le lancement automatique (ouvriers nil : fo-war-workers suivi en cours de partie) ;
                       c'est « /fo-war start <factions> <soldats> » ; réservé aux administrateurs en multijoueur, comme
                       la commande (demande du coordinateur, 25/10 : pas les 100 soldats de la commande sans argument) ;
    arrêt confirmé  -> War.stop() (comme « /fo-war stop »).
  Les commandes restent (bancs, console).

  DÉTERMINISME (une partie multijoueur n'est pas jouable au banc ; raisonnement, pas preuve) :
    - l'interface LIT l'état ; elle n'écrit dans l'état de jeu que par les fonctions ci-dessus, appelées depuis
      on_gui_click, c'est-à-dire depuis une action de joueur que le moteur synchronise et rejoue au même tick chez
      tous les joueurs ;
    - les éléments d'interface et l'état de la fenêtre (onglet, confirmation en attente : espace « ia1i » de
      `global`) ne changent que dans des gestionnaires d'événements (clic, raccourci, touche, onglet, fermeture,
      on_nth_tick) : tous les joueurs les exécutent dans le même ordre ;
    - aucun `pairs` sur l'état du jeu (listes triées : State.sorted_keys), aucune lecture locale (résolution, échelle
      d'affichage, temps mesuré), aucun tirage ;
    - le rafraîchissement (une fois par seconde, M.REFRESH) ne touche que les fenêtres OUVERTES, et pour la partie
      qui bouge seulement : boutons et confirmations ne sont refaits qu'après une action ou quand ce qu'ils montrent
      change (signature), pour ne pas perdre un clic.
]]

local Events = require("script.core.events")
local Config = require("script.core.config")
local F = require("shared.faction.config")
local O = require("shared.team.org")
local Tr = require("shared.faction.traits")
local M = require("shared.gui.ia1i")
local State = require("script.faction.state")
local Stock = require("script.team.stock") -- lot COFFRE : stock = coffre du QG + annexes
local Team = require("script.team.team")
local Poles = require("script.team.poles")
local PlayerTeam = require("script.team.player_team")
local Auto3e = require("shared.ai3.automatiser")
-- Objets dont le module a sa propre clé de traduction (locale/*/ia3e.cfg) : les gabarits écrits, et la centrale.
local AUTO_NAMED = { centrale = true, migration = true } -- migration : lot MIGRATION-DECLENCHE (fo-team.goal-ia3-auto-migration)
for _, m in ipairs(Auto3e.METHODS) do AUTO_NAMED[m.product] = true end
local War = require("script.faction.war")
local PvP = require("script.faction.pvp")
local Vision = require("script.faction.vision")
local Journal = require("script.gui.ia1i_journal")
local Stats = require("script.gui.ia1i_stats") -- lot PANEL-STATS
local SM = require("shared.gui.stats")
local Partie = require("script.gui.partie")
local Paires = require("shared.team.pose_paires") -- lot EXTENSION-FER : libellé d'un projet d'avant-poste (agrandir, nouvel avant-poste, reconstruire)
local TCfg = require("shared.team.config")

local Gui = {}

local FRAME = "fo_ia1i_frame"
local DEEP = "fo_ia1i_deep"
local TABS = "fo_ia1i_tabs"
local SHORTCUT = "fo-team-gui"
local INPUT = "fo-team-gui"
local P = "fo_ia1i_"
local WIDTH = 780

local GREY = { r = 0.62, g = 0.62, b = 0.62 }
local GOOD = { r = 0.55, g = 0.95, b = 0.55 }
local WARN = { r = 1, g = 0.7, b = 0.3 }
local BAD = { r = 1, g = 0.45, b = 0.4 }

-- Types de tâches des PNJ qui ont un texte (les autres s'affichent tels quels).
local TASK_TEXT = { build = true, extend = true, mine = true, smelt = true, smelters = true, service = true, craft = true,
  refill = true, fortify = true, garrison = true, salvage = true }

local function ui(player)
  local ns = Journal.ns()
  local u = ns.ui[player.index]
  if not u then
    u = { tab = 1 }
    ns.ui[player.index] = u
  end
  return u
end

local function player_team()
  local f = State.faction("player")
  if f and f.hq and f.hq.valid and f.team then return f end
  return nil
end

local function admin_ok(player)
  return not (game.is_multiplayer() and not player.admin)
end

--- Réglages de carte de la guerre, lus comme le lancement automatique (script/faction/war.lua, autostart).
local function war_settings()
  local g = settings.global
  return { factions = g["fo-war-factions"].value, soldiers = g["fo-war-soldiers"].value }
end

---------------------------------------------------------------------------------------------------
-- Petits éléments
---------------------------------------------------------------------------------------------------
local function label(parent, caption, o)
  local l = parent.add({ type = "label", caption = caption })
  l.style.single_line = false
  l.style.maximal_width = (o and o.width) or (WIDTH - 40)
  if o and o.color then l.style.font_color = o.color end
  if o and o.font then l.style.font = o.font end
  if o and o.tooltip then l.tooltip = o.tooltip end
  return l
end

local function heading(parent, caption)
  local l = parent.add({ type = "label", caption = caption, style = "caption_label" })
  l.style.top_margin = 8
  return l
end

local function separator(parent)
  local l = parent.add({ type = "line", direction = "horizontal" })
  l.style.top_margin = 6
  l.style.bottom_margin = 2
end

local function coming(parent, key)
  local l = label(parent, { "fo-ia1i.coming", { "fo-ia1i." .. key } }, { color = GREY })
  l.style.top_margin = 10
  return l
end

local function item_button(parent, name, count)
  local proto = game.item_prototypes[name]
  if not proto then
    label(parent, name .. " × " .. tostring(count))
    return
  end
  parent.add({ type = "sprite-button", sprite = "item/" .. name, number = count, style = "slot_button",
    tooltip = proto.localised_name })
end

local function pole_name(p)
  if p == nil or p == "" then return "—" end
  return { "fo-ia1b.pole-" .. p }
end

local function faction_name(f) return { "fo-faction.name-" .. f.key } end

local function no_team(c)
  heading(c, { "fo-ia1i.none-title" })
  local recipe = game.recipe_prototypes["fo-team-chest"]
  local parts = { "" }
  for i, ing in ipairs(recipe and recipe.ingredients or {}) do
    if i > 1 then parts[#parts + 1] = ", " end
    local p = game.item_prototypes[ing.name]
    parts[#parts + 1] = { "", tostring(ing.amount), " × ", p and p.localised_name or ing.name }
  end
  local start = math.min(Config.get("npc_start"), Config.get("player_npc_max"))
  local row = c.add({ type = "flow", direction = "horizontal" })
  row.style.vertical_align = "center"
  row.style.horizontal_spacing = 10
  item_button(row, "fo-team-chest", nil)
  label(row, { "fo-ia1i.none-how", parts, start, Config.get("player_npc_max") }, { width = WIDTH - 100 })
end

---------------------------------------------------------------------------------------------------
-- Lot IA3-c : bloc « Projets en cours » du cerveau par besoins (lecture seule de f.team.ia3, script/ai3/cerveau.lua) :
-- projets, état et raison (ce qui manque, ce qui bloque), recherche en cours, ce qu'on cherche, ce qu'on ne ramasse plus.
-- Rien n'est affiché qui ne soit dans l'état de l'équipe (règle d'IA1-i : aucun faux chiffre).
---------------------------------------------------------------------------------------------------
local IA3_STATE_ORDER = { actif = 1, attente = 2, bloque = 3 }

local function proto_name(name)
  local p = game.item_prototypes[name] or game.entity_prototypes[name] or game.fluid_prototypes[name]
  return p and p.localised_name or name
end

local function ia3_list(names, max)
  local parts = { "" }
  for i, n in ipairs(names) do
    if i > max then break end
    if i > 1 then parts[#parts + 1] = ", " end
    parts[#parts + 1] = proto_name(n)
  end
  return parts
end

--- Lot EXTENSION-FER : libellé d'un projet « extraction:<minerai> » selon ce qu'il fait (pose_paires.mode), ou nil.
local function ia3_outpost_name(f, p, cause)
  local kind = p.key:match("^extraction:(.+)$")
  if not (kind and TCfg.outposts[kind]) then return nil end
  local tasks = {}
  local b = f.team and f.team.board
  for _, tk in ipairs((b and b.list) or {}) do
    if tk.ia3 == p.id then tasks[#tasks + 1] = { kind = tk.kind, lost = tk.site and tk.site.lost or false } end
  end
  local extendable = false
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    if o.kind == kind and not o.full and o.drills < TCfg.max_drills(kind) then extendable = true end
  end
  local mode = Paires.mode({ tasks = tasks, cause = cause, extendable = extendable })
  if not mode then return nil end
  return { "fo-team.goal-ia3-extraction-" .. mode, { "fo-team.outpost-" .. kind } }
end

local function ia3_projects(parent, f, w, compact)
  local t = f.team
  if not (t and t.ia3c and t.ia3) then
    if not compact then label(parent, { "fo-ia3c.projects-off" }, { width = w, color = GREY }) end
    return
  end
  local st = t.ia3
  if compact then
    label(parent, { "fo-ia3c.projects" }, { width = w, font = "default-bold" })
  else
    heading(parent, { "fo-ia3c.projects" })
  end
  local taken = {}
  local b = t.board
  for _, tk in ipairs((b and b.list) or {}) do if tk.worker and tk.ia3 then taken[tk.ia3] = true end end
  local list, n_act, n_taken, n_block = {}, 0, 0, 0
  for _, p in ipairs(st.projects or {}) do
    list[#list + 1] = p
    if p.state == "actif" then n_act = n_act + 1 end
    if p.state == "bloque" then n_block = n_block + 1 end
    if taken[p.id] then n_taken = n_taken + 1 end
  end
  if #list == 0 then
    label(parent, { "fo-ia3c.projects-none" }, { width = w, color = GREY })
  else
    label(parent, { "fo-ia3c.summary", n_act, (st.last_plan and st.last_plan.K) or 0, n_taken, n_block }, { width = w })
  end
  table.sort(list, function(a, x)
    local oa, ox = IA3_STATE_ORDER[a.state] or 9, IA3_STATE_ORDER[x.state] or 9
    if oa ~= ox then return oa < ox end
    return a.id < x.id
  end)
  for i, p in ipairs(list) do
    if compact and i > 4 then break end
    local name = { "fo-team.goal-" .. ("ia3-" .. p.key):gsub(":", "-") }
    name = ia3_outpost_name(f, p, p.cause or "") or name -- lot EXTENSION-FER
    -- Lot IA3-e : module GÉNÉRÉ pour un objet quelconque (sans clé de traduction propre) : nom de l'objet du jeu.
    local auto_item = p.key:match("^auto:(.+)$")
    if auto_item and not AUTO_NAMED[auto_item] then
      local proto = game.item_prototypes[auto_item]
      name = { "fo-team.goal-ia3-auto-objet", proto and proto.localised_name or auto_item }
    end
    local fed_item = p.key:match("^alim:(.+)$")
    if fed_item then
      local proto = game.item_prototypes[fed_item]
      name = { "fo-team.goal-ia3-alim", proto and proto.localised_name or fed_item }
    end
    local why
    local cause = p.cause or ""
    if p.state == "bloque" and cause:sub(1, 5) == "site:" then
      why = { "fo-ia3c.cause-site", { "fo-team.outpost-" .. cause:sub(6) } }
    elseif p.state == "bloque" and cause == "tourelles" then
      why = { "fo-ia3c.cause-tourelles" }
    elseif p.state == "bloque" and cause:sub(1, 10) == "impayable:" then
      why = { "fo-ia3c.cause-impayable", cause:sub(11) }
    elseif p.state == "bloque" then
      why = { "fo-ia3c.cause-other", cause }
    else
      local miss = {}
      for k, n in pairs(p.missing or {}) do miss[#miss + 1] = { k, n } end
      table.sort(miss, function(a, x) if a[2] ~= x[2] then return a[2] > x[2] end return a[1] < x[1] end)
      if #miss > 0 then
        local parts = { "" }
        for j, m in ipairs(miss) do
          if j > 3 then break end
          if j > 1 then parts[#parts + 1] = ", " end
          parts[#parts + 1] = { "", tostring(math.ceil(m[2])), " ", proto_name(m[1]) }
        end
        why = { "", { "fo-ia3c.state-" .. p.state }, " ; ", { "fo-ia3c.need", parts } }
      else
        why = { "fo-ia3c.state-" .. p.state }
      end
    end
    local color = p.state == "bloque" and WARN or (taken[p.id] and GOOD or nil)
    label(parent, { "fo-ia3c.project-line", name, why }, { width = w, color = color })
  end
  local lab = st.lab
  if lab and lab.tech then
    local proto = game.technology_prototypes[lab.tech]
    local count = proto and proto.research_unit_count or 1
    local n_labs = 0
    for _, e in ipairs(st.labs or {}) do if e.valid then n_labs = n_labs + 1 end end
    label(parent, { "fo-ia3c.research-line", proto and proto.localised_name or lab.tech,
      math.floor(100 * (lab.units or 0) / math.max(1, count)), n_labs }, { width = w })
  end
  local exp = State.sorted_keys(st.explore or {})
  if #exp > 0 then label(parent, { "fo-ia3c.explore-line", ia3_list(exp, 4) }, { width = w, color = WARN }) end
  if not compact then
    local sat = State.sorted_keys(st.saturated or {})
    if #sat > 0 then label(parent, { "fo-ia3c.saturated-line", ia3_list(sat, 6) }, { width = w, color = GREY }) end
  end
end

---------------------------------------------------------------------------------------------------
-- Onglets : chaque onglet a une partie FIXE (boutons, confirmation ; refaite après une action, ou quand sa
-- signature change) et une partie VIVANTE (refaite chaque seconde, fenêtre ouverte).
---------------------------------------------------------------------------------------------------
local tabs = {}

-- Mon équipe ---------------------------------------------------------------------------------------
tabs.equipe = {
  sig = function(f) return f and "t" or "-" end,
  live = function(c, player, f)
    if not f then return no_team(c) end
    local t = f.team
    heading(c, { "fo-ia1i.goal" })
    label(c, t.goal and { "fo-team.goal-" .. t.goal } or { "fo-team.goal-line-done" }, { font = "default-bold" })

    heading(c, { "fo-ia1i.missing" })
    local shown = 0
    local row = c.add({ type = "flow", direction = "horizontal" })
    row.style.vertical_align = "center"
    row.style.horizontal_spacing = 6
    for _, m in ipairs(t.missing or {}) do
      if shown >= M.MISSING_SHOWN then break end
      local name = m[1]
      if name:find("^site:") then
        label(row, { "fo-team.missing-site", { "fo-team.outpost-" .. name:sub(6) } }, { width = 200 })
      else
        item_button(row, name, m[2])
      end
      shown = shown + 1
    end
    if shown == 0 then label(row, { "fo-ia1i.missing-none" }, { color = GOOD }) end

    ia3_projects(c, f, WIDTH - 40, false) -- lot IA3-c

    heading(c, { "fo-ia1i.staff" })
    local org = t.org
    local L = org and org.last
    if not L then
      label(c, { "fo-ia1i.staff-wait" }, { color = GREY })
    else
      local busy = L.n > 0 and math.floor(100 * (L.n - L.idle) / L.n + 0.5) or 0
      label(c, { "fo-ia1i.staff-line", f.engineers_count or 0, Team.npc_max(f), busy, L.pending or 0 })
      local tbl = c.add({ type = "table", column_count = 4, draw_horizontal_line_after_headers = true })
      tbl.style.horizontal_spacing = 24
      tbl.style.top_margin = 4
      for _, k in ipairs({ "col-pole", "col-exec", "col-gen", "col-target" }) do
        tbl.add({ type = "label", caption = { "fo-ia1i." .. k }, style = "bold_label" })
      end
      for i, p in ipairs(O.POLES) do
        tbl.add({ type = "label", caption = pole_name(p) })
        tbl.add({ type = "label", caption = tostring(L.actual and L.actual[i] or 0) })
        tbl.add({ type = "label", caption = tostring(L.gens and L.gens[i] or 0) })
        tbl.add({ type = "label", caption = tostring(L.targets and L.targets[i] or 0) })
      end
      -- Pôles et managers sont ceux de la DERNIÈRE pensée (toutes les 5 s) : dit tel quel (un renvoi n'y apparaît
      -- qu'à la pensée suivante).
      label(c, { "fo-ia1i.staff-age", math.floor((game.tick - (L.tick or game.tick)) / 60) }, { color = GREY })
    end

    -- Journal AVANT les managers (captures du 25/10 : en bas, il sortait de la fenêtre à 720 px de haut).
    heading(c, { "fo-ia1i.journal" })
    local recent = Journal.recent(M.JOURNAL_SHOWN)
    if #recent == 0 then label(c, { "fo-ia1i.journal-empty" }, { color = GREY }) end
    for _, e in ipairs(recent) do label(c, Journal.text(e)) end

    heading(c, { "fo-ia1i.managers" })
    local lines = Poles.lines(f)
    if #lines <= 1 then
      label(c, lines[1] or { "fo-ia1b.no-report" }, { color = GREY })
    else
      for i = 3, #lines do label(c, lines[i]) end
    end

    heading(c, { "fo-ia1i.chest" })
    local contents = Stock.contents(f)
    local names = State.sorted_keys(contents)
    if #names == 0 then
      label(c, { "fo-ia1i.chest-empty" }, { color = WARN })
    else
      local grid = c.add({ type = "table", column_count = 12 })
      grid.style.horizontal_spacing = 2
      grid.style.vertical_spacing = 2
      for i, name in ipairs(names) do
        if i > 36 then break end
        item_button(grid, name, contents[name])
      end
    end

    coming(c, "coming-equipe")
  end,
}

-- Orientation --------------------------------------------------------------------------------------
tabs.orientation = {
  sig = function(f, u)
    if not f then return "-" end
    return M.current_preset(Poles.orientation(f)) .. "|" .. tostring(u.confirm)
  end,
  fixed = function(c, player, f, u)
    if not f then
      label(c, { "fo-ia1i.none-short" })
      return
    end
    local o = Poles.orientation(f)
    local cur = M.current_preset(o)
    local pts = O.normalize(o, false)
    local org = f.team.org
    label(c, { "fo-ia1i.orientation-now", { "fo-ia1i.preset-" .. cur }, pts[1], pts[2], pts[3] }, { font = "default-bold" })
    label(c, (org and org.orientation) and { "fo-ia1i.orientation-since", M.clock(org.orientation_tick or 0) }
      or { "fo-ia1i.orientation-default" }, { color = GREY })

    heading(c, { "fo-ia1i.presets" })
    local tbl = c.add({ type = "table", column_count = 3 })
    tbl.style.horizontal_spacing = 14
    tbl.style.vertical_spacing = 6
    for _, r in ipairs(M.preset_rows()) do
      local b = tbl.add({ type = "button", name = P .. "preset_" .. r.name, caption = { "fo-ia1i.preset-" .. r.name },
        style = (r.name == cur) and "green_button" or "button" })
      b.style.minimal_width = 170
      if r.name == cur then b.tooltip = { "fo-ia1i.preset-current" } end
      local pl = label(tbl, { "fo-ia1i.preset-pts", r.pts[1], r.pts[2], r.pts[3] }, { width = 260 })
      pl.style.minimal_width = 230
      label(tbl, { "fo-ia1i.effect-" .. r.name }, { width = 300, color = GREY })
    end
    label(c, { "fo-ia1i.orientation-note" }, { color = GREY }).style.top_margin = 6

    separator(c)
    heading(c, { "fo-ia1i.dismiss-title" })
    label(c, { "fo-ia1i.dismiss-text" })
    if u.confirm == "dismiss" then
      label(c, { "fo-ia1i.dismiss-ask", f.engineers_count or 0 }, { color = WARN, font = "default-bold" })
      local row = c.add({ type = "flow", direction = "horizontal" })
      row.style.horizontal_spacing = 12
      row.add({ type = "button", name = P .. "dismiss_no", caption = { "fo-ia1i.cancel" }, style = "back_button" })
      row.add({ type = "button", name = P .. "dismiss_yes", caption = { "fo-ia1i.dismiss-yes" }, style = "red_confirm_button" })
    else
      c.add({ type = "button", name = P .. "dismiss", caption = { "fo-ia1i.dismiss" }, style = "red_button" })
    end

    coming(c, "coming-orientation")
  end,
}

-- Factions -----------------------------------------------------------------------------------------
local function character_text(f)
  local arch = F.personalities[f.personality or ""] and f.personality or "balanced"
  local sal = M.salient(f.traits, Tr.ORDER)
  local parts = { "" }
  for i, s in ipairs(sal) do
    if i > 1 then parts[#parts + 1] = " · " end
    parts[#parts + 1] = { "fo-ia1i.trait-value", { "fo-ia1i.trait-" .. s.key }, M.permille(s.v) }
  end
  local tip = { "" }
  if f.traits then
    for i, k in ipairs(Tr.ORDER) do
      if i > 1 then tip[#tip + 1] = ", " end
      tip[#tip + 1] = { "fo-ia1i.trait-value", { "fo-ia1i.trait-" .. k }, M.permille(f.traits[k]) }
    end
  end
  -- 8 traits = 15 paramètres : sous la limite de 20 d'une chaîne localisée.
  return { "fo-ia1i.character", { "fo-ia1i.arch-" .. arch }, parts }, { "fo-ia1i.traits-tip", tip }
end

local function chef_texts(f, war)
  local ch = f.chef
  if not (ch and ch.mix and #ch.mix > 0) then return { "fo-ia1i.chef-none" }, nil end
  local mix = { "" }
  for i, m in ipairs(ch.mix) do
    if i > 9 then break end
    if i > 1 then mix[#mix + 1] = ", " end
    local name = War.CHEF_POSTURES[m.key] and { "fo-chef.posture-" .. m.key } or tostring(m.key)
    mix[#mix + 1] = { "fo-chef.mix", name, tostring(math.floor(m.w / 10 + 0.5)) }
  end
  local r = ch.reason or "-"
  local reason = War.CHEF_REASONS[r] and { "fo-chef.reason-" .. War.CHEF_REASONS[r] } or r
  local target = ch.target and war.factions[ch.target]
  return { "fo-ia1i.chef", mix, reason },
    { "fo-ia1i.chef-target", target and faction_name(target) or { "fo-ia1i.chef-target-none" } }
end

local function card(parent, f, rec, tick, war)
  local fr = parent.add({ type = "frame", style = "deep_frame_in_shallow_frame", direction = "vertical" })
  fr.style.width = (WIDTH - 44) / 2
  fr.style.vertically_stretchable = true
  local inner = fr.add({ type = "flow", direction = "vertical" })
  inner.style.padding = 8
  inner.style.vertical_spacing = 4
  local w = (WIDTH - 44) / 2 - 20
  local name = inner.add({ type = "label", caption = faction_name(f), style = "heading_2_label" })
  if f.color then name.style.font_color = f.color end

  local ctext, ctip = character_text(f)
  label(inner, ctext, { width = w, tooltip = ctip })

  local rel = M.relation(rec or { eliminated = f.eliminated }, tick)
  local key, color = "rel-" .. rel.kind, GOOD
  if rel.kind == "truce" and rel.minutes == 0 then key = "rel-truce-due" end
  if rel.kind == "war" or rel.kind == "provoked" then color = BAD end
  if rel.kind == "eliminated" then color = GREY end
  if rel.kind == "truce" and rel.minutes <= 5 then color = WARN end
  label(inner, { "fo-ia1i." .. key, rel.minutes or 0 }, { width = w, color = color, font = "default-bold" })
  if f.eliminated then return end

  local chef, target = chef_texts(f, war)
  label(inner, chef, { width = w })
  if target then label(inner, target, { width = w }) end

  local tech = tostring(f.tech or 0)
  if (f.upgrades or 0) > 0 then tech = tech .. " (+" .. f.upgrades .. ")" end
  label(inner, { "fo-ia1i.forces", f.soldiers_count or 0, f.garrison_count or 0, f.engineers_count or 0,
    Team.npc_max(f), f.outposts_count or 0, tech, rec and rec.attacks or 0 }, { width = w })
  local recruit = Team.effectif_text(f) -- lot IA3-d : pourquoi la faction recrute ou non
  if recruit then label(inner, recruit, { width = w, color = GREY }) end

  if f.team and f.team.ia3c then ia3_projects(inner, f, w, true) end -- lot IA3-c

  if rec and (rec.known or 0) > 0 then
    local seen = (f.pvp and f.pvp.vision) and #Vision.known_turrets(f.pvp.vision) or 0
    label(inner, { "fo-ia1i.knows", rec.known, seen, { "fo-ia1i.style-" .. (rec.style or "inconnu") } }, { width = w })
    if rec.target then
      label(inner, { "fo-ia1i.knows-target", math.floor(rec.target.x), math.floor(rec.target.y) }, { width = w, color = GREY })
    end
  else
    label(inner, { "fo-ia1i.knows-nothing" }, { width = w, color = GREY })
  end
end

tabs.factions = {
  sig = function(f, u, player)
    local w = war_settings()
    return tostring(State.war().active) .. "|" .. tostring(u.confirm) .. "|" .. tostring(admin_ok(player)) .. "|"
      .. tostring(w.factions) .. "|" .. tostring(w.soldiers) .. "|" .. tostring(Config.get("npc_max"))
  end,
  fixed = function(c, player, f, u)
    local war = State.war()
    local can = admin_ok(player)
    if not war.active then
      label(c, { "fo-ia1i.war-none" }, { font = "default-bold" })
      local w = war_settings()
      label(c, { "fo-ia1i.war-start-text", w.factions, w.soldiers, Config.get("npc_max"), F.defaults.distance })
      local b = c.add({ type = "button", name = P .. "war_start", caption = { "fo-ia1i.war-start" }, style = "confirm_button" })
      b.style.top_margin = 6
      if not can then
        b.enabled = false
        b.tooltip = { "fo-ia1i.admin-only" }
      end
      return
    end
    if u.confirm == "stop" then
      label(c, { "fo-ia1i.war-stop-ask" }, { color = WARN, font = "default-bold" })
      local row = c.add({ type = "flow", direction = "horizontal" })
      row.style.horizontal_spacing = 12
      row.add({ type = "button", name = P .. "war_stop_no", caption = { "fo-ia1i.cancel" }, style = "back_button" })
      row.add({ type = "button", name = P .. "war_stop_yes", caption = { "fo-ia1i.war-stop-yes" }, style = "red_confirm_button" })
    else
      local b = c.add({ type = "button", name = P .. "war_stop", caption = { "fo-ia1i.war-stop" }, style = "red_button" })
      if not can then
        b.enabled = false
        b.tooltip = { "fo-ia1i.admin-only" }
      end
    end
  end,
  live = function(c, player, f)
    local war = State.war()
    if not war.active then return end
    local tick = game.tick
    local st = PvP.status(tick)
    local recs = {}
    for _, r in ipairs(st.factions) do recs[r.key] = r end
    local ids = State.sorted_keys(war.factions)
    label(c, { "fo-ia1i.war-head", math.floor((tick - (war.started or tick)) / 3600), { "fo-pvp.level-" .. st.difficulty },
      #State.alive(), #ids }, { font = "default-bold" }).style.top_margin = 6
    local grid = c.add({ type = "table", column_count = 2 })
    grid.style.horizontal_spacing = 8
    grid.style.vertical_spacing = 8
    grid.style.top_margin = 6
    for _, id in ipairs(ids) do
      local fac = war.factions[id]
      card(grid, fac, recs[fac.key], tick, war)
    end
  end,
}

-- PNJ ----------------------------------------------------------------------------------------------
tabs.pnj = {
  sig = function(f) return f and "t" or "-" end,
  live = function(c, player, f)
    if not f then
      label(c, { "fo-ia1i.none-short" })
      return
    end
    label(c, { "fo-ia1i.pnj-head", f.engineers_count or 0, Team.npc_max(f) }, { font = "default-bold" })
    local s = Poles.status(f)
    if not (s and s.npcs and #s.npcs > 0) then
      label(c, { "fo-ia1i.staff-wait" }, { color = GREY })
    else
      local tbl = c.add({ type = "table", column_count = 5, draw_horizontal_line_after_headers = true })
      tbl.style.horizontal_spacing = 20
      tbl.style.top_margin = 6
      for _, k in ipairs({ "col-id", "col-role", "col-pole", "col-task", "col-dest" }) do
        tbl.add({ type = "label", caption = { "fo-ia1i." .. k }, style = "bold_label" })
      end
      for _, n in ipairs(s.npcs) do
        tbl.add({ type = "label", caption = tostring(n.id) })
        tbl.add({ type = "label", caption = { "fo-ia1i.role-" .. (n.role == "generalist" and "generalist" or "executant") } })
        tbl.add({ type = "label", caption = pole_name(n.pole) })
        local task = n.task and (TASK_TEXT[n.task] and { "fo-ia1i.task-" .. n.task } or n.task) or { "fo-ia1i.task-none" }
        tbl.add({ type = "label", caption = task })
        tbl.add({ type = "label", caption = n.dest and pole_name(n.dest) or "—" })
      end
    end
    coming(c, "coming-pnj")
  end,
}

-- Partie (lot PANEL-STATS) : statistiques de la partie, lecture seule (script/gui/partie.lua).
local PANEL_TASKS = { idle = true, norole = true, ghost = true, equiper = true, centrale = true, explore = true, clear = true,
  carry = true }
local function task_text(kind)
  if PANEL_TASKS[kind] then return { "fo-panel.task-" .. kind } end
  if TASK_TEXT[kind] then return { "fo-ia1i.task-" .. kind } end
  return { "fo-panel.task-other", tostring(kind) } -- type de tâche sans texte propre : traduit quand même, avec son nom
end
tabs.partie = Partie.tab({ label = label, heading = heading, task_text = task_text })
tabs.partie.every = 3 -- secondes entre deux rafraîchissements de l'onglet (les débits couvrent 3 min)

tabs.territoire = { fixed = function(c) coming(c, "coming-territoire") end }
tabs.chantiers = { fixed = function(c) coming(c, "coming-chantiers") end }

---------------------------------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------------------------------
local function frame_of(player)
  -- Un joueur sans `gui.screen` (moteur simulé des bancs hors jeu, `levels_test`) n'a pas de fenêtre : rien à rafraîchir.
  local screen = player.gui and player.gui.screen
  if not screen then return nil end
  local fr = screen[FRAME]
  if fr and fr.valid then return fr end
  return nil
end

local function pane_of(frame, k)
  return frame[DEEP][TABS][P .. "c_" .. k]
end

local function count_refresh()
  local ns = Journal.ns()
  ns.refreshes = (ns.refreshes or 0) + 1
end

--- (Re)construit l'onglet choisi : tout (`full`), ou la seule partie vivante si la signature de la partie fixe n'a pas
--- changé. Les autres onglets sont vidés à la reconstruction complète (rien de périmé dans un onglet caché).
local function build(player, full)
  local frame = frame_of(player)
  if not frame then return end
  local u = ui(player)
  local k = M.TABS[u.tab] or "equipe"
  local def = tabs[k]
  local f = player_team()
  local sig = def.sig and def.sig(f, u, player) or ""
  if sig ~= u.sig or u.built ~= k then full = true end
  local pane = pane_of(frame, k)
  if full then
    for _, other in ipairs(M.TABS) do
      if other ~= k then pane_of(frame, other).clear() end
    end
    pane.clear()
    local fixed = pane.add({ type = "flow", name = P .. "fixed", direction = "vertical" })
    fixed.style.vertical_spacing = 4
    local live = pane.add({ type = "flow", name = P .. "live", direction = "vertical" })
    live.style.vertical_spacing = 4
    if def.fixed then def.fixed(fixed, player, f, u) end
    u.sig, u.built, u.skipped = sig, k, 0
  elseif not def.live then
    return
  elseif def.every then
    -- Onglet qui change lentement (« Partie », lot PANEL-STATS) : refait une fois toutes les `every` secondes seulement
    -- (mesuré : 2,7 ms par rafraîchissement, dont la construction des éléments ; budget du lot 0,05 ms/tick).
    u.skipped = (u.skipped or 0) + 1
    if u.skipped < def.every then return end
    u.skipped = 0
  end
  if def.live then
    local live = pane[P .. "live"]
    live.clear()
    def.live(live, player, f, u)
  end
  count_refresh()
end

local function close(player)
  local frame = frame_of(player)
  local u = ui(player)
  u.confirm, u.sig, u.built = nil, nil, nil
  if frame then frame.destroy() end
  player.set_shortcut_toggled(SHORTCUT, false)
end

local function open(player, tab)
  local old = frame_of(player)
  if old then old.destroy() end
  local u = ui(player)
  if tab and M.TABS[tab] then u.tab = tab end
  u.confirm, u.sig, u.built = nil, nil, nil
  local frame = player.gui.screen.add({ type = "frame", name = FRAME, direction = "vertical" })
  local bar = frame.add({ type = "flow", name = P .. "bar", direction = "horizontal" })
  bar.drag_target = frame
  bar.style.horizontal_spacing = 8
  bar.add({ type = "label", caption = { "fo-ia1i.title" }, style = "frame_title", ignored_by_interaction = true })
  local drag = bar.add({ type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true })
  drag.style.height = 24
  drag.style.horizontally_stretchable = true
  drag.style.right_margin = 4
  bar.add({ type = "sprite-button", name = P .. "close", style = "frame_action_button", sprite = "utility/close_white",
    hovered_sprite = "utility/close_black", clicked_sprite = "utility/close_black", tooltip = { "fo-ia1i.close" } })
  local deep = frame.add({ type = "frame", name = DEEP, style = "inside_deep_frame_for_tabs" })
  local tp = deep.add({ type = "tabbed-pane", name = TABS })
  for _, k in ipairs(M.TABS) do
    local tab = tp.add({ type = "tab", caption = { "fo-ia1i.tab-" .. k } })
    local pane = tp.add({ type = "scroll-pane", name = P .. "c_" .. k, direction = "vertical",
      horizontal_scroll_policy = "never", vertical_scroll_policy = "auto", style = "naked_scroll_pane" })
    pane.style.width = WIDTH
    pane.style.maximal_height = 640
    pane.style.padding = 12
    tp.add_tab(tab, pane)
  end
  tp.selected_tab_index = u.tab
  frame.force_auto_center()
  player.opened = frame
  player.set_shortcut_toggled(SHORTCUT, true)
  build(player, true)
  return frame
end

local function toggle(player)
  if frame_of(player) then
    close(player)
  else
    open(player)
  end
end

local function select_tab(player, index)
  local u = ui(player)
  u.tab = M.TABS[index] and index or 1
  u.confirm = nil
  build(player, true)
end

---------------------------------------------------------------------------------------------------
-- Actions (clic) : les fonctions des commandes, rien d'autre
---------------------------------------------------------------------------------------------------
local function on_click(e)
  local el = e.element
  if not (el and el.valid) then return end
  local name = el.name
  if name:sub(1, #P) ~= P then return end
  local player = game.get_player(e.player_index)
  if not player then return end
  if name == P .. "close" then
    close(player)
    return
  end
  local u = ui(player)
  local f = player_team()
  local preset = name:match("^fo_ia1i_preset_(.+)$")
  local pteam = name:match("^fo_ia1i_pteam_(.+)$")
  if pteam then
    -- Onglet « Partie » : équipe détaillée (affichage seulement, aucun effet sur le jeu).
    u.pteam = pteam
  elseif preset then
    -- /fo-team orientation <préréglage>
    local pts = f and Poles.set_orientation(f, preset)
    if pts then player.print({ "fo-ia1b.orientation-set", pts[1], pts[2], pts[3] }) end
  elseif name == P .. "dismiss" then
    u.confirm = "dismiss"
  elseif name == P .. "dismiss_no" or name == P .. "war_stop_no" then
    u.confirm = nil
  elseif name == P .. "dismiss_yes" then
    u.confirm = nil
    -- /fo-team dismiss
    if f then
      PlayerTeam.dismiss(f, true)
      player.print({ "fo-team.dismissed" })
    end
  elseif name == P .. "war_start" then
    -- Réglages de carte, comme le lancement automatique (= /fo-war start <factions> <soldats>)
    if not admin_ok(player) then
      player.print({ "fo-ia1i.admin-only" })
    else
      local w = war_settings()
      local ok, err = War.start(player, w.factions, w.soldiers, nil, F.defaults.distance)
      if not ok then player.print("[FO-WAR] " .. tostring(err)) end
    end
  elseif name == P .. "war_stop" then
    if admin_ok(player) then u.confirm = "stop" end
  elseif name == P .. "war_stop_yes" then
    u.confirm = nil
    -- /fo-war stop
    if admin_ok(player) then
      player.print({ "fo-ia1i.war-stopped", War.stop() })
    else
      player.print({ "fo-ia1i.admin-only" })
    end
  else
    return
  end
  build(player, true)
end

Events.on(defines.events.on_gui_click, on_click)

Events.on(defines.events.on_gui_selected_tab_changed, function(e)
  local el = e.element
  if not (el and el.valid and el.name == TABS) then return end
  local player = game.get_player(e.player_index)
  if player then select_tab(player, el.selected_tab_index or 1) end
end)

Events.on(defines.events.on_gui_closed, function(e)
  local el = e.element
  if not (el and el.valid and el.name == FRAME) then return end
  local player = game.get_player(e.player_index)
  if player then close(player) end
end)

Events.on(defines.events.on_lua_shortcut, function(e)
  if e.prototype_name ~= SHORTCUT then return end
  local player = game.get_player(e.player_index)
  if player then toggle(player) end
end)

Events.on(INPUT, function(e)
  local player = game.get_player(e.player_index)
  if player then toggle(player) end
end)

-- Taille ou échelle d'affichage changée (fenêtre redimensionnée, bureau à distance : passage du 25/10, 1296 × 696 puis
-- 2203 × 1203 en cours de session) : la fenêtre ouverte est recentrée, sinon elle sort de l'écran.
local function recenter(e)
  local player = game.get_player(e.player_index)
  local frame = player and frame_of(player)
  if frame then frame.force_auto_center() end
end
Events.on(defines.events.on_player_display_resolution_changed, recenter)
Events.on(defines.events.on_player_display_scale_changed, recenter)

-- Lot PANEL-STATS : technologies recherchées recomptées dès qu'une recherche se termine (l'onglet « Partie » les lit en cache).
Events.on(defines.events.on_research_finished, function(e)
  local r = e.research
  if r and r.force then Stats.recount(r.force.name) end
end)

-- Une fois par seconde : relevé du journal, puis rafraîchissement des seules fenêtres OUVERTES.
Events.on_nth_tick(M.REFRESH, function(e)
  Journal.sample(e.tick)
  if e.tick % SM.PERIOD == 0 then Stats.sample(e.tick) end -- lot PANEL-STATS : relevé des compteurs (30 s)
  for _, player in ipairs(game.connected_players) do
    if frame_of(player) then build(player, false) end
  end
end)

---------------------------------------------------------------------------------------------------
-- Interface distante « fo-ia1i » (bancs et captures, docs §8.6) : ouvrir, fermer, choisir un onglet, CLIQUER un
-- bouton par son nom (même fonction que le clic : on_click), lire l'état de la fenêtre. Aucun objet du moteur rendu.
---------------------------------------------------------------------------------------------------
local function find(el, name)
  for _, ch in ipairs(el.children) do
    if ch.name == name then return ch end
    local r = find(ch, name)
    if r then return r end
  end
  return nil
end

local function collect(el, names, keys)
  for _, ch in ipairs(el.children) do
    if ch.name ~= "" then names[#names + 1] = ch.name end
    if ch.type == "label" or ch.type == "button" then
      local cap = ch.caption
      if type(cap) == "table" and type(cap[1]) == "string" then keys[#keys + 1] = cap[1] end
    end
    collect(ch, names, keys)
  end
end

-- Index de joueur valide seulement (un banc sans joueur passe 0).
local function get_player(index)
  if type(index) ~= "number" or index < 1 then return nil end
  return game.get_player(index)
end

remote.add_interface("fo-ia1i", {
  open = function(index, tab)
    local player = get_player(index)
    if not player then return false end
    open(player, M.TAB_INDEX[tab] or tonumber(tab))
    return true
  end,
  close = function(index)
    local player = get_player(index)
    if not player then return false end
    close(player)
    return true
  end,
  toggle = function(index)
    local player = get_player(index)
    if not player then return nil end
    toggle(player)
    return frame_of(player) ~= nil
  end,
  select = function(index, tab)
    local player = get_player(index)
    local frame = player and frame_of(player)
    local i = M.TAB_INDEX[tab] or tonumber(tab)
    if not (frame and i and M.TABS[i]) then return false end
    frame[DEEP][TABS].selected_tab_index = i
    select_tab(player, i)
    return true
  end,
  click = function(index, name)
    local player = get_player(index)
    local frame = player and frame_of(player)
    local el = frame and find(frame, name)
    if not el then return false end
    on_click({ element = el, player_index = index, button = defines.mouse_button_type.left, alt = false,
      control = false, shift = false, name = defines.events.on_gui_click, tick = game.tick })
    return true
  end,
  refresh = function(index, full)
    local player = get_player(index)
    if player then build(player, full and true or false) end
    return Journal.ns().refreshes
  end,
  state = function(index)
    local ns = Journal.ns()
    local player = get_player(index)
    if not player then return { refreshes = ns.refreshes } end
    local frame = frame_of(player)
    local u = ui(player)
    local ws = State.war().settings or {}
    local out = { open = frame ~= nil, tab = M.TABS[u.tab], confirm = u.confirm, refreshes = ns.refreshes,
      shortcut = player.is_shortcut_toggled(SHORTCUT), names = {}, keys = {},
      war = { active = State.war().active, soldiers_max = ws.soldiers_max, engineers_max = ws.engineers_max,
        npc_from_setting = ws.npc_from_setting or false } }
    local o = player.opened
    out.opened = (o ~= nil and o.object_name == "LuaGuiElement" and o.valid and o.name == FRAME) or false
    if frame then
      out.selected = frame[DEEP][TABS].selected_tab_index
      collect(frame, out.names, out.keys)
    end
    return out
  end,
  -- Relevé du journal (même fonction que le relevé de chaque seconde) : mesure de son coût par les bancs.
  sample = function()
    Journal.sample(game.tick)
    return #Journal.ns().journal
  end,
  -- Lot PANEL-STATS (bancs et captures) : ce que l'onglet « Partie » affiche (données, pas d'objet du moteur), relevé
  -- forcé des compteurs (même fonction que le relevé de 30 s), anneau de relevés d'une équipe, taille de l'état.
  panel = function(selected)
    return Stats.collect(selected or "player", game.tick)
  end,
  -- Défile le volet de l'onglet affiché (captures de l'onglet « Partie », plus haut que la fenêtre) : « top », « bottom »,
  -- ou la clé de traduction d'un titre à mettre en vue.
  scroll = function(index, where)
    local player = get_player(index)
    local frame = player and frame_of(player)
    if not frame then return false end
    local pane = pane_of(frame, M.TABS[ui(player).tab] or "equipe")
    if where == "top" then
      pane.scroll_to_top()
    elseif where == "bottom" then
      pane.scroll_to_bottom()
    else
      local function find_key(el)
        for _, ch in ipairs(el.children) do
          if ch.type == "label" and type(ch.caption) == "table" and ch.caption[1] == where then return ch end
          local r = find_key(ch)
          if r then return r end
        end
      end
      local el = find_key(pane)
      if not el then return false end
      pane.scroll_to_element(el, "top-third")
    end
    return true
  end,
  panel_sample = function()
    Stats.sample(game.tick)
    return game.tick
  end,
  panel_ring = function(key)
    return Stats.ring(key or "player")
  end,
  panel_bytes = function()
    local P = Journal.ns().panel
    return P and #serpent.block(P, { comment = false, sortkeys = false }) or 0
  end,
  journal = function()
    local out = {}
    for i, e in ipairs(Journal.ns().journal) do
      out[i] = { tick = e.tick, kind = e.kind, a = e.a, b = e.b, c = e.c }
    end
    return out
  end,
})

Gui.open, Gui.close, Gui.toggle, Gui.build = open, close, toggle, build
return Gui
