--[[
  Lot UI-FLUX (chantier 4 du DC, 15/11) : le panneau « Flux de l'IA », une VUE en lecture seule des décisions budgétaires de l'équipe
  du joueur. Un bouton compact dans la barre du haut (fo_flux_button, comme fo_cmd_button de script/gui/commande.lua) déplie, à gauche,
  un petit panneau en deux étages, avec des barres de progression :
    - étage 1, RESSOURCES : fer (plaques), cuivre (plaques), charbon, pierre ; pour chacune, une barre par destination (rangées de
      foreuses / champ, fonderies, énergie, mall / usines, recherche, défense) et une barre « stock libre » ;
    - étage 2, PROJETS ACTIFS : part du total engagé de chaque grande catégorie, et temps écoulé depuis le lancement du plus ancien
      projet actif de la catégorie (mm:ss).
  Aucune comptabilité parallèle : les règles pures (shared/gui/flux_ia.lua) lisent ce que l'IA tient déjà : projets du plan directeur
  (f.build.projects : spec, état, `created`, ce qu'il reste à poser par Build.needs_of, déplié en matières premières par le livre de
  recettes de l'équipe), buts de l'IA3 (f.team.ia3.projects : famille, `opened`), demande de défense (f.team.depenses.defense_want),
  recherche en cours (force.current_research), stock libre (f.team.ia3.noyau, sinon le coffre).

  Coût : rien tant qu'aucun panneau n'est ouvert. Ouvert : un rafraîchissement par seconde au plus (on_nth_tick 60), en lisant des tables ;
  l'agrégation des projets (la seule partie qui parcourt des listes) est refaite toutes les REBUILD_EVERY ticks, le reste (stock libre,
  pourcentages, temps écoulé, éléments de la fenêtre modifiés en place) à chaque rafraîchissement. Aucun find_entities, aucun pairs
  décisionnel, rien n'est écrit dans l'état de l'IA.

  État de vue : `global` (script/core/storage.lua, espace « gui_flux »), PAR JOUEUR : { open = { [numéro de joueur] = true } } ; jamais lu
  par l'IA. Les mémos du module (agrégat, coûts unitaires) sont des caches locaux, jamais dans `global`, qui n'influencent que l'affichage.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local State = require("script.faction.state")
local T = require("shared.team.config")
local Fx = require("shared.gui.flux_ia")
local Build = require("script.team.build")
local Stock = require("script.team.stock")
local Rsv = require("script.ai3.reserve")
local FoSwap = require("script.team.foreuse_swap") -- FoSwap.book_of : livre de recettes de l'équipe (posé par script/team/team.lua)

local Flux = {}

local BUTTON, FRAME = "fo_flux_button", "fo_flux_frame"
Flux.REFRESH_EVERY = 60
Flux.REBUILD_EVERY = 300
-- Matières suivies, dans l'ordre d'affichage : les types d'avant-poste (T.OUTPOST_ORDER) ; ceux qui rendent une PLAQUE (produit différent de
-- la ressource : fonderie) d'abord, puis ceux qui rendent la matière brute. Le produit (T.outposts[k].product) donne la matière.
Flux.KINDS = {}
for _, brut in ipairs({ false, true }) do
  for _, k in ipairs(T.OUTPOST_ORDER) do
    local o = T.outposts[k]
    if o and ((o.product == o.resource) == brut) then Flux.KINDS[#Flux.KINDS + 1] = k end
  end
end
local COLOR = {
  champ = { r = 0.35, g = 0.8, b = 0.4 }, fonderies = { r = 0.95, g = 0.55, b = 0.2 }, energie = { r = 1, g = 0.85, b = 0.2 },
  mall = { r = 0.35, g = 0.65, b = 1 }, recherche = { r = 0.75, g = 0.45, b = 0.95 }, defense = { r = 0.9, g = 0.3, b = 0.3 },
  libre = { r = 0.7, g = 0.7, b = 0.7 },
}

Storage.declare("gui_flux", function() return { open = {} } end)
local function state() return Storage.ns("gui_flux") end
local shown = {} -- mémo local de la fenêtre de chaque joueur (voir refs_of) : jamais dans `global`

local function resources()
  local list = {}
  for _, k in ipairs(Flux.KINDS) do
    local o = T.outposts[k]
    if o then list[#list + 1] = o.product end
  end
  return list
end

local function team_of(player)
  local f = State.faction("player")
  if f and f.team and f.force == player.force.name then return f end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Lecture des engagements de l'IA (aucune écriture)
---------------------------------------------------------------------------------------------------
local unit_cost = setmetatable({}, { __mode = "k" }) -- livre -> { [objet] = { [matière] = coût d'une unité } }

--- Coût d'un objet en matières premières du livre (mesuré sur 1000 unités : pas d'arrondi par fournée), mémorisé par livre.
local function unit_of(book, item)
  local memo = unit_cost[book]
  if not memo then memo = {}; unit_cost[book] = memo end
  local u = memo[item]
  if not u then
    u = {}
    for k, n in pairs(book:raw_cost({ { item, 1000 } })) do u[k] = n / 1000 end -- (ensemble de matières : l'ordre est sans effet)
    memo[item] = u
  end
  return u
end

local function add_raw(acc, book, item, n, tracked)
  if n <= 0 then return end
  if tracked[item] then
    acc[item] = (acc[item] or 0) + n
    return
  end
  if not book then return end
  for k, per in pairs(unit_of(book, item)) do -- (somme commutative)
    if tracked[k] then acc[k] = (acc[k] or 0) + per * n end
  end
end

local sorted_ids = function(t)
  local ids = {}
  for id in pairs(t or {}) do ids[#ids + 1] = id end -- (la vue trie : aucune décision)
  table.sort(ids)
  return ids
end

--- Agrégat lourd : projets ACTIFS du plan directeur, avec leur coût restant en matières suivies ; mémo toutes les REBUILD_EVERY ticks.
local memo = { tick = nil, key = nil, builds = nil }
local function builds_of(f, tick, res)
  if memo.builds and memo.key == f.force and memo.tick and tick >= memo.tick and tick - memo.tick < Flux.REBUILD_EVERY then return memo.builds end
  local tracked = {}
  for _, r in ipairs(res) do tracked[r] = true end
  local book = FoSwap.book_of and FoSwap.book_of(f) or nil
  local out = {}
  local b = f.build
  for _, id in ipairs(sorted_ids(b and b.projects)) do
    local p = b.projects[id]
    if Fx.active(p.state) then
      local raw = {}
      for item, n in pairs(Build.needs_of(p)) do add_raw(raw, book, item, n, tracked) end -- (somme commutative)
      out[#out + 1] = { cat = Fx.classify(p.spec), created = p.created, raw = raw }
    end
  end
  memo.tick, memo.key, memo.builds = tick, f.force, out
  return out
end

local function goals_of(f)
  local out = {}
  local st = f.team and f.team.ia3
  for _, p in ipairs(st and st.projects or {}) do
    if p.state == "actif" then
      local c = Fx.family_cat(p.family)
      if c then out[#out + 1] = { cat = c, opened = p.opened } end
    end
  end
  return out
end

--- Engagements hors projets : demande de défense du périmètre, et paquets de la recherche en cours (reste à faire, en matières premières).
local function extra_of(f, res)
  local extra = {}
  local d = f.team and f.team.depenses
  if d and type(d.defense_want) == "table" then
    local ex = {}
    for _, r in ipairs(res) do ex[r] = d.defense_want[r] end
    extra.defense = ex
  end
  local force = game.forces[f.force]
  local tech = force and force.current_research
  if tech and tech.valid then
    local book = FoSwap.book_of and FoSwap.book_of(f) or nil
    local tracked = {}
    for _, r in ipairs(res) do tracked[r] = true end
    local left = math.max(0, tech.research_unit_count * (1 - (force.research_progress or 0)))
    local ex = {}
    for _, ing in ipairs(tech.research_unit_ingredients or {}) do add_raw(ex, book, ing.name, ing.amount * left, tracked) end
    extra.recherche = ex
  end
  return extra
end

local function free_of(f, tick, res)
  local free = {}
  local rin = Rsv.input(f, tick)
  for _, r in ipairs(res) do
    if rin and rin.free then free[r] = rin.free[r] or 0 -- (absente de `free` : le besoin évalué la prend en entier)
    elseif f.hq and f.hq.valid then free[r] = Stock.count(f, r) end
  end
  return free
end

--- Vue complète pour l'équipe `f` : { sm = synthèse (shared/gui/flux_ia.lua), res = liste des matières, coal = { need, capacity } ou nil }.
function Flux.view(f, tick)
  local res = resources()
  local sm = Fx.summarize({ tick = tick, resources = res, builds = builds_of(f, tick, res), goals = goals_of(f), extra = extra_of(f, res),
    free = free_of(f, tick, res) })
  local cc = f.coal_cap
  return { sm = sm, res = res, coal = cc and { need = (cc.need or 0) * 60, capacity = (cc.capacity or 0) * 60 } or nil }
end

---------------------------------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------------------------------
local function bar(parent, name, color, width)
  local pb = parent.add({ type = "progressbar", name = name, value = 0 })
  pb.style.width = width or 150
  pb.style.color = color
  return pb
end

local function build(player)
  local left = player.gui.left
  if left[FRAME] then left[FRAME].destroy() end
  shown[player.index] = nil
  local frame = left.add({ type = "frame", name = FRAME, direction = "vertical", caption = { "fo-flux.titre" } })
  frame.style.minimal_width = 380
  frame.add({ type = "label", name = "etat", caption = "" })
  frame.add({ type = "label", caption = { "fo-flux.etage1" }, style = "caption_label" })
  for _, kind in ipairs(Flux.KINDS) do
    local o = T.outposts[kind]
    if o then
      frame.add({ type = "label", name = "h_" .. kind, caption = { "item-name." .. o.product }, style = "caption_label" })
      local tbl = frame.add({ type = "table", name = "t_" .. kind, column_count = 3 })
      tbl.style.horizontal_spacing = 8
      tbl.style.vertical_spacing = 1
      for _, c in ipairs(Fx.CATS) do
        tbl.add({ type = "label", name = "l_" .. c, caption = { "fo-flux.cat-" .. c } })
        bar(tbl, "b_" .. c, COLOR[c])
        tbl.add({ type = "label", name = "p_" .. c, caption = "" })
      end
      tbl.add({ type = "label", name = "l_" .. Fx.FREE, caption = { "fo-flux.libre" } })
      bar(tbl, "b_" .. Fx.FREE, COLOR.libre)
      tbl.add({ type = "label", name = "p_" .. Fx.FREE, caption = "" })
    end
  end
  local cl = frame.add({ type = "label", name = "charbon", caption = "" })
  cl.style.single_line = false
  cl.style.maximal_width = 400
  frame.add({ type = "line" })
  frame.add({ type = "label", caption = { "fo-flux.etage2" }, style = "caption_label" })
  local t2 = frame.add({ type = "table", name = "t_cats", column_count = 4 })
  t2.style.horizontal_spacing = 8
  t2.style.vertical_spacing = 1
  for _, c in ipairs(Fx.CATS) do
    t2.add({ type = "label", name = "l_" .. c, caption = { "fo-flux.cat-" .. c } })
    bar(t2, "b_" .. c, COLOR[c], 110)
    t2.add({ type = "label", name = "p_" .. c, caption = "" })
    t2.add({ type = "label", name = "t_" .. c, caption = "" })
  end
  local note = frame.add({ type = "label", name = "note", caption = { "fo-flux.note" } })
  note.style.single_line = false
  note.style.maximal_width = 400
  note.style.font_color = { r = 0.7, g = 0.7, b = 0.7 }
  return frame
end

--- Références des éléments (une passe de lectures par fenêtre, mémo local : perdu au chargement, relu alors) et dernières valeurs écrites :
--- un rafraîchissement n'écrit que ce qui a changé (le coût d'une passe vient des lectures et écritures de la fenêtre, pas du calcul).
local function refs_of(player, frame)
  local s = shown[player.index]
  if s and s.frame == frame and frame.valid then return s end
  s = { frame = frame, last = {}, kinds = {}, cats = {} }
  s.etat, s.charbon, s.t2 = frame["etat"], frame["charbon"], frame["t_cats"]
  for _, kind in ipairs(Flux.KINDS) do
    local tbl = frame["t_" .. kind]
    if tbl then
      local k = { head = frame["h_" .. kind], l = {}, b = {}, p = {} }
      for _, c in ipairs(Fx.CATS) do k.l[c], k.b[c], k.p[c] = tbl["l_" .. c], tbl["b_" .. c], tbl["p_" .. c] end
      k.l[Fx.FREE], k.b[Fx.FREE], k.p[Fx.FREE] = tbl["l_" .. Fx.FREE], tbl["b_" .. Fx.FREE], tbl["p_" .. Fx.FREE]
      s.kinds[kind] = k
    end
  end
  for _, c in ipairs(Fx.CATS) do s.cats[c] = { b = s.t2["b_" .. c], p = s.t2["p_" .. c], t = s.t2["t_" .. c] } end
  shown[player.index] = s
  return s
end

local function put(s, key, sig, el, prop, value)
  if s.last[key] == sig then return end
  s.last[key] = sig
  el[prop] = value
end

--- Écrit la vue dans la fenêtre du joueur (éléments modifiés en place, seulement si leur valeur change ; la fenêtre est refaite si elle est
--- d'une autre version).
local function paint(player, view)
  local frame = player.gui.left[FRAME]
  if not frame then return end
  if not frame["t_cats"] then frame = build(player) end
  local s = refs_of(player, frame)
  put(s, "etat", "", s.etat, "caption", "")
  for _, kind in ipairs(Flux.KINDS) do
    local o = T.outposts[kind]
    local k = o and s.kinds[kind]
    if k then
      local rs = view.sm.res[o.product]
      local by = {}
      for _, b in ipairs(rs and rs.bars or {}) do by[b.cat] = b end
      local total = rs and rs.total or 0
      local tot = math.floor(total)
      put(s, "h" .. kind, tot, k.head, "caption", { "fo-flux.entete", { "item-name." .. o.product }, tot })
      for _, c in ipairs(Fx.CATS) do
        local b = by[c]
        local show = b ~= nil
        local key = kind .. c
        if s.last["v" .. key] ~= show then
          s.last["v" .. key] = show
          k.l[c].visible, k.b[c].visible, k.p[c].visible = show, show, show
        end
        if show then
          local n = math.floor(b.n)
          put(s, "p" .. key, b.pct * 1e7 + n, k.p[c], "caption", { "fo-flux.part", b.pct, n })
          put(s, "b" .. key, b.n / math.max(total, 1), k.b[c], "value", math.min(1, b.n / math.max(total, 1)))
        end
      end
    end
  end
  local cl = s.charbon
  if view.coal then
    local need, cap = string.format("%.0f", view.coal.need), string.format("%.0f", view.coal.capacity)
    put(s, "charbon", need .. "/" .. cap, cl, "caption", { "fo-flux.charbon", need, cap })
  end
  if s.last.charbon_vis ~= (view.coal ~= nil) then
    s.last.charbon_vis = view.coal ~= nil
    cl.visible = view.coal ~= nil
  end
  for _, c in ipairs(Fx.CATS) do
    local cs, r = view.sm.cats[c], s.cats[c]
    put(s, "cb" .. c, cs.pct, r.b, "value", cs.pct / 100)
    put(s, "cp" .. c, cs.pct, r.p, "caption", { "fo-flux.pct", cs.pct })
    local tm = Fx.mmss(cs.since)
    put(s, "ct" .. c, tm .. cs.count, r.t, "caption", { "fo-flux.temps", tm, cs.count })
  end
end

local function open(player)
  if not (player and player.valid) then return end
  local ns = state()
  local f = team_of(player)
  ns.open[player.index] = true
  local frame = build(player)
  if not f then
    frame["etat"].caption = { "fo-flux.sans-equipe" }
    return
  end
  paint(player, Flux.view(f, game.tick))
end

local function close(player)
  if not (player and player.valid) then return end
  state().open[player.index] = nil
  if player.gui.left[FRAME] then player.gui.left[FRAME].destroy() end
end

local function ensure_button(player)
  local top = player.gui.top
  if not top[BUTTON] then
    top.add({ type = "sprite-button", name = BUTTON, sprite = "item/" .. T.outposts[Flux.KINDS[1]].product, tooltip = { "fo-flux.bouton" } })
  end
end

Events.on(defines.events.on_gui_click, function(e)
  local el = e.element
  if not (el and el.valid and el.name == BUTTON) then return end
  local player = game.get_player(e.player_index)
  if player.gui.left[FRAME] then close(player) else open(player) end
end)

--- Rafraîchissement : seulement si un panneau est ouvert ; une vue par équipe et par passe.
Events.on_nth_tick(Flux.REFRESH_EVERY, function(e)
  local ns = state()
  if not (ns and next(ns.open)) then return end -- (vide ou non : aucun ordre en jeu)
  local view
  for _, p in ipairs(game.connected_players) do
    if ns.open[p.index] and p.gui.left[FRAME] then
      local f = team_of(p)
      if f then
        view = view or Flux.view(f, e.tick)
        paint(p, view)
      end
    end
  end
end)

local function all_buttons()
  for _, p in pairs(game.players) do ensure_button(p) end
end
Events.on_init(all_buttons)
Events.on_configuration_changed(all_buttons)
Events.on(defines.events.on_player_created, function(e) ensure_button(game.get_player(e.player_index)) end)
Events.on(defines.events.on_player_removed, function(e) local ns = state(); if ns then ns.open[e.player_index] = nil end end)

---------------------------------------------------------------------------------------------------
-- Interface de BANC (lecture et ouverture du panneau, journal [FO-FLUX-IA]) : aucune décision ne la lit
---------------------------------------------------------------------------------------------------
remote.add_interface("fo-flux", {
  --- Écrit la ligne [FO-FLUX-IA] de l'équipe du joueur (minute donnée) et la rend ; nil sans équipe.
  ligne = function(minute)
    local f = State.faction("player")
    if not (f and f.team) then return nil end
    memo.tick = nil -- (relevé frais)
    local text = Fx.line(f.key or "player", minute or math.floor(game.tick / 3600), Flux.view(f, game.tick).sm)
    log(text)
    return text
  end,
  --- Ouvre le panneau du joueur (numéro) : rend vrai si la fenêtre existe.
  ouvrir = function(index)
    local p = game.get_player(index)
    if not p then return false end
    ensure_button(p)
    open(p)
    return p.gui.left[FRAME] ~= nil
  end,
  fermer = function(index)
    local p = game.get_player(index)
    if p then close(p) end
  end,
  --- Mesure du coût d'un rafraîchissement pour le joueur `index`, `n` passes chacune : la VUE (lecture et calcul, agrégat en mémo), la PEINTURE
  --- (valeurs inchangées : passe ordinaire), puis une passe à FROID (agrégat refait) et une OUVERTURE (tous les éléments relus et réécrits).
  --- Une ligne [FO-FLUX-COUT] avec les profileurs du moteur.
  cout = function(index, n)
    local p = game.get_player(index)
    local f = State.faction("player")
    if not (p and f and f.team) then return false end
    n = n or 20
    if not p.gui.left[FRAME] then open(p) end
    local view = Flux.view(f, game.tick)
    local t_view = game.create_profiler()
    for _ = 1, n do view = Flux.view(f, game.tick) end
    t_view.stop()
    local t_paint = game.create_profiler()
    for _ = 1, n do paint(p, view) end
    t_paint.stop()
    local t_cold = game.create_profiler()
    memo.tick = nil
    view = Flux.view(f, game.tick)
    t_cold.stop()
    local t_open = game.create_profiler()
    shown[p.index] = nil
    paint(p, view)
    t_open.stop()
    t_view.divide(n)
    t_paint.divide(n)
    log({ "", "[FO-FLUX-COUT] passes de ", n, " : vue ", t_view, " ; peinture inchangee ", t_paint, " ; vue a froid (agregat refait) ", t_cold,
      " ; ouverture (tout relu et reecrit) ", t_open })
    return true
  end,
})

return Flux
