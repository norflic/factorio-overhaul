--[[
  Onglet « Partie » de la fenêtre « Équipe et factions » (lot PANEL-STATS ; demande du Directeur Créatif, 28/10 :
  un panneau de statistiques de la partie). Construit les éléments d'interface ; les valeurs viennent de
  script/gui/ia1i_stats.lua (lecture du moteur) et de shared/gui/stats.lua (modèle pur, formatage).

  Contenu :
    1. avancée et forces de CHAQUE équipe (la vôtre puis les factions vivantes) : niveau, technologies recherchées sur le
       total, avant-postes, soldats, PNJ, ennemis détruits, pertes, attaques lancées et contre vous ; recherches en cours ;
    2. pour l'équipe choisie (boutons) :
       - MACHINES : production et consommation par minute des objets qui coulent le plus, et cumul (statistiques du
         moteur de la force : toute l'usine de la force) ;
       - MAINS : ce que les PNJ minent, fabriquent et portent au coffre, compté par le mod (le moteur ne le compte pas,
         F319) ; affichés à part, jamais additionnés aux machines ;
       - PNJ : combien font quoi (minage avec la ressource visée, fabrication, tournée…), part au travail, causes
         d'inactivité.

  LECTURE SEULE, rien n'est décidé ici. Reconstruit toutes les 3 s (`every = 3` dans team_window.lua : 2,7 à 4,0 ms par reconstruction), fenêtre ouverte sur l'onglet seulement (comme les
  autres onglets, script/gui/team_window.lua). Aucun nom d'objet du jeu en dur : les objets sont affichés par leur
  nom localisé, triés par flux.
]]

local Stats = require("script.gui.ia1i_stats")
local S = require("shared.gui.stats")
local M = require("shared.gui.ia1i")
local State = require("script.faction.state")

local Partie = {}

local GREY = { r = 0.62, g = 0.62, b = 0.62 }
local DASH = "—"

--- Nom localisé d'un objet précédé de son icône (texte riche) ; nom brut si le prototype n'existe plus.
local function item_caption(name)
  local proto = game.item_prototypes[name]
  if not proto then return name end
  return { "", "[item=" .. name .. "] ", proto.localised_name }
end

local function team_caption(key)
  if key == "player" then return { "fo-panel.team-player" } end
  return { "fo-faction.name-" .. key }
end

local function num(v)
  if v == nil then return DASH end
  return S.fmt_total(v)
end

--- Construit la définition de l'onglet. `H` = outils de la fenêtre (team_window.lua) :
---   H.label(parent, caption, opts), H.heading(parent, caption), H.ui(player), H.width, H.task_text(kind), H.pole(p).
function Partie.tab(H)
  local def = {}

  --- Clé de l'équipe détaillée : celle du joueur (u.pteam), ou la vôtre si elle n'existe plus.
  local function selected(u)
    local want = u.pteam or "player"
    for _, t in ipairs(Stats.teams()) do
      if t.key == want then return want end
    end
    return "player"
  end

  def.sig = function(f, u)
    local keys = {}
    for _, t in ipairs(Stats.teams()) do keys[#keys + 1] = t.key end
    return selected(u) .. "|" .. table.concat(keys, ",")
  end

  -- Partie FIXE : les boutons de choix de l'équipe détaillée.
  def.fixed = function(c, player, f, u)
    local sel = selected(u)
    H.label(c, { "fo-panel.choose" }, { color = GREY })
    local row = c.add({ type = "flow", direction = "horizontal" })
    row.style.horizontal_spacing = 6
    for _, t in ipairs(Stats.teams()) do
      local b = row.add({ type = "button", name = "fo_ia1i_pteam_" .. t.key, caption = team_caption(t.key),
        style = (t.key == sel) and "green_button" or "button" })
      b.style.minimal_width = 110
    end
  end

  local function teams_table(c, data)
    H.heading(c, { "fo-panel.teams-title" })
    local tbl = c.add({ type = "table", column_count = 10, draw_horizontal_line_after_headers = true })
    tbl.style.horizontal_spacing = 12
    tbl.style.top_margin = 4
    for _, k in ipairs({ "team", "level", "tech", "outposts", "soldiers", "pnj", "kills", "lost", "att-out", "att-in" }) do
      local l = tbl.add({ type = "label", caption = { "fo-panel.col-" .. k }, style = "bold_label" })
      l.tooltip = { "fo-panel.tip-" .. k }
    end
    for _, r in ipairs(data.teams) do
      local name = tbl.add({ type = "label", caption = team_caption(r.key) })
      if r.color then name.style.font_color = r.color end
      tbl.add({ type = "label", caption = r.has_team and tostring(r.level) or DASH })
      tbl.add({ type = "label", caption = { "fo-panel.tech-value", r.techs_done, r.techs_total } })
      tbl.add({ type = "label", caption = r.has_team and tostring(r.outposts) or DASH })
      tbl.add({ type = "label", caption = r.has_team and tostring(r.soldiers) or DASH })
      tbl.add({ type = "label", caption = r.has_team and { "fo-panel.pnj-value", r.engineers, r.npc_max } or DASH })
      tbl.add({ type = "label", caption = num(r.kills) })
      tbl.add({ type = "label", caption = num(r.losses) })
      tbl.add({ type = "label", caption = r.attacks_out ~= nil and tostring(r.attacks_out) or DASH })
      tbl.add({ type = "label", caption = r.attacks_in ~= nil and tostring(r.attacks_in) or DASH })
    end
    H.label(c, { "fo-panel.teams-note" }, { color = GREY })

    H.heading(c, { "fo-panel.research-title" })
    for _, r in ipairs(data.teams) do
      if r.research then
        local proto = game.technology_prototypes[r.research.name]
        H.label(c, { "fo-panel.research-line", team_caption(r.key), proto and proto.localised_name or r.research.name,
          r.research.pct })
      else
        H.label(c, { "fo-panel.research-none", team_caption(r.key) }, { color = GREY })
      end
    end
  end

  local function flow_table(c, rows, with_cons, total_key)
    local tbl = c.add({ type = "table", column_count = with_cons and 4 or 3, draw_horizontal_line_after_headers = true })
    tbl.style.horizontal_spacing = 18
    tbl.style.top_margin = 4
    tbl.add({ type = "label", caption = { "fo-panel.col-item" }, style = "bold_label" })
    tbl.add({ type = "label", caption = { with_cons and "fo-panel.col-rate" or "fo-panel.col-rate-hand" }, style = "bold_label" })
    if with_cons then tbl.add({ type = "label", caption = { "fo-panel.col-cons" }, style = "bold_label" }) end
    tbl.add({ type = "label", caption = { total_key }, style = "bold_label" })
    for _, r in ipairs(rows) do
      tbl.add({ type = "label", caption = item_caption(r.name) })
      tbl.add({ type = "label", caption = S.fmt_rate(r.rate) })
      if with_cons then tbl.add({ type = "label", caption = S.fmt_rate(r.cons_rate) }) end
      tbl.add({ type = "label", caption = S.fmt_total(r.total) })
    end
  end

  local function rates_wait(c, d)
    if d.span <= 0 then H.label(c, { "fo-panel.rates-wait" }, { color = GREY }) end
  end

  local function machines_block(c, d)
    H.heading(c, { "fo-panel.machines-title", team_caption(d.key) })
    H.label(c, { "fo-panel.machines-note" }, { color = GREY })
    if #d.machines == 0 then
      H.label(c, { "fo-panel.machines-empty" }, { color = GREY })
      return
    end
    H.label(c, { "fo-panel.machines-sum", S.fmt_total(d.prod_total), S.fmt_total(d.cons_total), S.fmt_rate(d.span / 3600) })
    rates_wait(c, d)
    flow_table(c, d.machines, true, "fo-panel.col-total")
  end

  local function hands_block(c, d)
    H.heading(c, { "fo-panel.hands-title", team_caption(d.key) })
    if not d.hands then
      H.label(c, { "fo-panel.no-team" }, { color = GREY })
      return
    end
    local h = d.hands
    H.label(c, { "fo-panel.hands-note" }, { color = GREY })
    H.label(c, { "fo-panel.hands-line", S.fmt_total(h.mined), S.fmt_rate(h.mined_rate), S.fmt_total(h.crafted),
      S.fmt_rate(h.crafted_rate), S.fmt_total(h.delivered_total) })
    if #h.items == 0 then
      H.label(c, { "fo-panel.hands-empty" }, { color = GREY })
    else
      flow_table(c, h.items, false, "fo-panel.col-delivered")
    end
  end

  local function workers_block(c, d)
    H.heading(c, { "fo-panel.workers-title", team_caption(d.key) })
    local w = d.workers
    if not w then
      H.label(c, { "fo-panel.no-team" }, { color = GREY })
      return
    end
    H.label(c, { "fo-panel.workers-line", w.alive, w.max, w.busy or 0 })
    if #w.tasks > 0 then
      local tbl = c.add({ type = "table", column_count = 2, draw_horizontal_line_after_headers = true })
      tbl.style.horizontal_spacing = 24
      tbl.style.top_margin = 4
      tbl.add({ type = "label", caption = { "fo-panel.col-task" }, style = "bold_label" })
      tbl.add({ type = "label", caption = { "fo-panel.col-count" }, style = "bold_label" })
      for _, t in ipairs(w.tasks) do
        tbl.add({ type = "label", caption = H.task_text(t.key) })
        tbl.add({ type = "label", caption = tostring(t.n) })
      end
    end
    if #w.mining > 0 then
      local parts = { "" }
      for i, m in ipairs(w.mining) do
        if i > 1 then parts[#parts + 1] = ", " end
        parts[#parts + 1] = { "", item_caption(m.key), " × " .. m.n }
      end
      H.label(c, { "fo-panel.mining-line", parts })
    end
    if w.why then
      H.label(c, { "fo-panel.why-line", w.why.rien, w.why.bloque, w.why.manque }, { color = GREY })
    end
  end

  -- Partie VIVANTE : refaite chaque seconde.
  def.live = function(c, player, f, u)
    local tick = game.tick
    local data = Stats.collect(selected(u), tick)
    local war = State.war()
    H.label(c, { "fo-panel.head", M.clock(tick), war.active and { "fo-panel.war-on", #data.teams - 1 } or { "fo-panel.war-off" } },
      { font = "default-bold" })
    teams_table(c, data)
    machines_block(c, data.detail)
    hands_block(c, data.detail)
    workers_block(c, data.detail)
    return data
  end

  return def
end

return Partie
