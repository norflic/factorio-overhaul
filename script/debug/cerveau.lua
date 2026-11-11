--[[
  Lot DEBUG-CERVEAU (demande du DC, 8/11) : la vue « Cerveau ». Un joueur voit, SUR LA CARTE et dans un panneau, les zones que le cerveau
  de l'équipe observée gère, leur état RÉEL mesuré, ce que le cerveau en sait (et depuis quand), les tâches prévues, les décisions
  récentes et les améliorations (existantes ou « n'existe pas dans le cerveau »).
  INDÉPENDANT de fo-debug-render et de fo-debug-trace-carte. AUCUNE écriture dans l'état des décisions : script/debug/lecture.lua lit,
  les règles sont pures (shared/debug/*.lua), le rendu est propre au joueur (rendering avec players = { index }).

  Accès : bouton de la barre de raccourcis « fo-dbg-cerveau », touche « fo-dbg-cerveau » (Ctrl + Maj + B par défaut), commande /fo-cerveau.
  Réglages par joueur (settings/debug_cerveau.lua) : textes sur la carte, zones à écart seulement.

  COÛT : rien quand personne ne regarde (un test sur st.open_n dans deux abonnements). Ouverte, UNE force par spectateur distinct :
    - toutes les Cv.SLICE ticks, une zone relevée au moteur (find_entities_filtered de sa seule emprise, Lec.ENT_MAX entités au plus) ;
    - toutes les Cv.REFRESH ticks (1 s), lecture des lectures du cerveau, calcul des écarts, redessin des zones et du panneau.
  DÉTERMINISME (multijoueur) : le relevé des zones est dans `global` (espace « debug_cerveau » : nombres et chaînes seulement, effacé à la
  fermeture de la dernière vue) parce que le rendu en dépend et que les objets de rendu sont de l'état de partie ; il est calculé par les
  gestionnaires d'événements chez tous les pairs, à partir de l'état de partie seul (aucune donnée locale, aucun temps mesuré, aucun
  pairs décisionnel). Les identifiants d'objets de rendu y sont aussi (pour les détruire).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local State = require("script.faction.state")
local Lec = require("script.debug.lecture")
local Rendu = require("script.debug.rendu")
local Panneau = require("script.debug.panneau")
local Ec = require("shared.debug.ecart")
local Lg = require("shared.debug.lignes")
local Am = require("shared.debug.ameliorations")
local An = require("script.debug.anneau")

local Cv = {}

Cv.SLICE = 3        -- ticks entre deux relevés de zone
Cv.REFRESH = 60     -- ticks entre deux redessins (1 s)
Cv.FIRST_PER_SLICE = 5 -- zones relevées par tranche pendant le premier cycle
Cv.SHORTCUT = "fo-dbg-cerveau"
Cv.INPUT = "fo-dbg-cerveau"
Cv.COMMAND = "fo-cerveau"
Cv.DRAW_KINDS = { module = true, fonderie = true, labos = true, centrale = true, champ = true, site = true, quartier = true, avant_poste = true }

Storage.declare("debug_cerveau", function() return { v = 1, open_n = 0, viewers = {}, snaps = {} } end)

local function ns()
  local ok, st = pcall(Storage.ns, "debug_cerveau")
  if not ok then return nil end
  return st
end

local function count_open(st)
  local n = 0
  for idx in pairs(st.viewers) do n = n + 1 end -- comptage seul : l'ordre ne compte pas
  st.open_n = n
end

local function sorted_viewers(st)
  return State.sorted_keys(st.viewers)
end

---------------------------------------------------------------------------------------------------
-- Ouverture et fermeture
---------------------------------------------------------------------------------------------------
function Cv.is_open(player_index)
  local st = ns()
  return st ~= nil and st.viewers[player_index] ~= nil
end

local function set_shortcut(player, on)
  if player and player.valid then pcall(player.set_shortcut_toggled, Cv.SHORTCUT, on) end
end

function Cv.open(player, fid)
  local st = ns()
  if not (st and player and player.valid) then return false end
  local v = st.viewers[player.index]
  if not v then
    v = { fid = fid or "player", sel = nil, tab = 1, sig = {}, render = {} }
    st.viewers[player.index] = v
    count_open(st)
  elseif fid then
    v.fid = fid
  end
  if not Lec.team(v.fid) then
    -- pas d'équipe de ce nom (par exemple pas de coffre d'équipe posé) : la première équipe observable
    local teams = Lec.teams()
    v.fid = teams[1] and teams[1].id or "player"
  end
  set_shortcut(player, true)
  Cv.refresh_one(player, st, v, game.tick)
  return true
end

function Cv.close(player)
  local st = ns()
  if not (st and player) then return false end
  local v = st.viewers[player.index]
  if v then
    Rendu.clear(v)
    st.viewers[player.index] = nil
    count_open(st)
    if st.open_n == 0 then st.snaps = {} end -- plus aucun spectateur : le relevé est effacé
  end
  if player.valid then
    Panneau.close_npc(player)
    Panneau.close(player)
    set_shortcut(player, false)
  end
  return v ~= nil
end

function Cv.toggle(player)
  if Cv.is_open(player.index) then Cv.close(player) else Cv.open(player) end
end

---------------------------------------------------------------------------------------------------
-- Relevé par tranches
---------------------------------------------------------------------------------------------------
local function snap_of(st, fid)
  local s = st.snaps[fid]
  if not s then
    s = { order = {}, zones = {}, cursor = 0, cycles = 0 }
    st.snaps[fid] = s
  end
  return s
end

--- Nouveau cycle : le recensement est refait, les mesures déjà prises sont gardées pour les zones dont l'état n'a pas changé.
local function new_cycle(f, s)
  local skel = Lec.skeletons(f)
  local zones, order = {}, {}
  for _, z in ipairs(skel) do
    local old = s.zones[z.key]
    if old and old.state == z.state and old.mtick then
      z.machines, z.aux, z.color, z.cause, z.ratio, z.n, z.top, z.mtick, z.run = old.machines, old.aux, old.color, old.cause, old.ratio, old.n, old.top, old.mtick, old.run
    end
    zones[z.key] = z
    order[#order + 1] = z.key
  end
  s.zones, s.order, s.cursor = zones, order, 1
  local st = ns()
  -- liaisons enregistrées (copies de nombres), refaites à chaque cycle ; lignes FICTIVES seulement si le banc d'images l'a demandé (remote « demo »)
  s.links = Lec.links(f, (st and st.demo == true) and Lec.demo_projects(skel) or nil)
  s.cycles = (s.cycles or 0) + 1
end

local function slice_force(st, fid, tick)
  local f = Lec.team(fid)
  if not f then return end
  local s = snap_of(st, fid)
  -- premier cycle après l'ouverture : 5 zones par tranche, pour que la vue ne reste pas grise (ensuite une seule)
  local per = (s.cycles or 0) <= 1 and Cv.FIRST_PER_SLICE or 1
  for _ = 1, per do
    if s.cursor == 0 or s.cursor > #s.order then new_cycle(f, s) end
    local key = s.order[s.cursor]
    s.cursor = s.cursor + 1
    local z = key and s.zones[key]
    if z then Lec.measure(f, z, tick) end
  end
end

Events.on_nth_tick(Cv.SLICE, function(e)
  local st = ns()
  if not st or st.open_n == 0 then return end
  local done = {}
  for _, idx in ipairs(sorted_viewers(st)) do
    local fid = st.viewers[idx].fid
    if not done[fid] then
      done[fid] = true
      local ok, err = pcall(slice_force, st, fid, e.tick)
      if not ok then
        local s = snap_of(st, fid)
        s.err = tostring(err):sub(1, 200)
        s.cursor = 0
      end
    end
  end
end)

---------------------------------------------------------------------------------------------------
-- Modèle de la vue (partagé par le rendu et le panneau)
---------------------------------------------------------------------------------------------------
--- Lignes de zones d'une force : { key, z, color, cause, reads, ecart }, triées (alertes d'abord, puis clé).
function Cv.rows(f, s, now)
  local rows = {}
  for _, key in ipairs(s.order) do
    local z = s.zones[key]
    if z then
      local color = z.color or "gris"
      local reads = Lec.reads(f, z)
      local ec = Ec.compare(reads, { color = color, cause = z.cause }, now)
      rows[#rows + 1] = { key = key, z = z, color = color, cause = z.cause, reads = reads, ecart = ec, sev = ec.sev }
    end
  end
  Ec.sort(rows)
  return rows
end

--- Zone retenue : celle choisie dans la liste, sinon celle où se trouve le joueur, sinon la première alerte.
local function selected_row(rows, v, player)
  if v.sel then
    for _, r in ipairs(rows) do if r.key == v.sel then return r end end
  end
  local pos = player and player.valid and player.position
  if pos then
    for _, r in ipairs(rows) do
      local z = r.z
      if z.x0 and pos.x >= z.x0 and pos.x <= z.x1 and pos.y >= z.y0 and pos.y <= z.y1 and Cv.DRAW_KINDS[z.kind] then return r end
    end
  end
  return rows[1]
end

function Cv.refresh_one(player, st, v, now)
  local f = Lec.team(v.fid)
  if not (f and player.valid) then return end
  local s = snap_of(st, v.fid)
  if s.cursor == 0 then new_cycle(f, s) end
  local rows = Cv.rows(f, s, now)
  local row = selected_row(rows, v, player)
  local tasks = Lec.tasks(f)
  local ctx = {
    now = now, rows = rows, sel = row, f = f, snap = s, teams = Lec.teams(),
    decisions = Lg.decisions(Lec.decision_rows(f), Lg.DECISIONS_MAX),
    sel_tasks = row and Lg.tasks_for_zone(tasks, { pid = row.z.pid, oid = row.z.oid }) or {},
    sel_piquage = row and row.z.pid and Lec.piquage_rows(f, row.z.pid) or {},
    sel_am_refus = row and row.z.pid and Lec.am_refus_rows(f, row.z.pid) or {},
    links = s.links or {},
    sel_links = {},
    improvements = Am.evaluate(Lec.improvement_facts(f)),
    sev_count = { alerte = 0, attention = 0, info = 0, ok = 0 },
  }
  for _, r in ipairs(rows) do ctx.sev_count[r.sev] = (ctx.sev_count[r.sev] or 0) + 1 end
  if row and row.z.pid then
    for _, l in ipairs(ctx.links) do
      if l.dock_pid == row.z.pid or l.src_pid == row.z.pid then ctx.sel_links[#ctx.sel_links + 1] = l end
    end
  end
  -- PNJ regardé (clic ou survol) : son état cognitif complet, relu à chaque redessin
  if v.npc then
    local agent = Lec.agent(v.npc)
    local af = Lec.team_of_agent(agent)
    if agent and af and agent.entity and agent.entity.valid then ctx.npc = Lec.npc(af, agent, now) else ctx.npc_gone = v.npc end
  end
  local opts = Rendu.options(player)
  Rendu.draw(player, v, rows, row and row.key or nil, opts, now, Lec.surface_of(f), s.links)
  Panneau.update(player, v, ctx)
end

Events.on_nth_tick(Cv.REFRESH, function(e)
  local st = ns()
  if not st or st.open_n == 0 then return end
  for _, idx in ipairs(sorted_viewers(st)) do
    local player = game.get_player(idx)
    local v = st.viewers[idx]
    if player and player.valid and player.connected and v then
      local ok, err = pcall(Cv.refresh_one, player, st, v, e.tick)
      if not ok then
        local s = snap_of(st, v.fid)
        s.err = tostring(err):sub(1, 200)
      end
    end
  end
end)

---------------------------------------------------------------------------------------------------
-- Entrées du joueur
---------------------------------------------------------------------------------------------------
Events.on(defines.events.on_lua_shortcut, function(e)
  if e.prototype_name ~= Cv.SHORTCUT then return end
  local player = game.get_player(e.player_index)
  if player then Cv.toggle(player) end
end)

-- F498 (CC-OVERLAY, partie du DC sur la 0.6.89) : le réglage de débogage de la partie (fo-debug-render) n'ouvrait QUE les étiquettes des PNJ ;
-- la vue des zones (boxes, chantiers prévus, liaisons) n'avait que le raccourci : le DC l'a activé à 58,5 min sans rien voir. Le basculer
-- ouvre (vrai) ou ferme (faux) la vue pour le joueur qui l'a basculé ; un changement fait par script (pas de joueur) ne touche aucune vue.
Cv.SETTING = "fo-debug-render"
Events.on(defines.events.on_runtime_mod_setting_changed, function(e)
  if e.setting ~= Cv.SETTING or not e.player_index then return end
  local player = game.get_player(e.player_index)
  if not player then return end
  if settings.global[Cv.SETTING].value then Cv.open(player) else Cv.close(player) end
end)

Events.on(Cv.INPUT, function(e)
  local player = game.get_player(e.player_index)
  if player then Cv.toggle(player) end
end)

-- Un PNJ pointé (survol) ou cliqué (le curseur est sur lui) pendant que la vue est ouverte : son panneau s'ouvre et le suit ; un autre PNJ le remplace.
Events.on(defines.events.on_selected_entity_changed, function(e)
  local st = ns()
  if not st or st.open_n == 0 then return end
  local v = st.viewers[e.player_index]
  local player = game.get_player(e.player_index)
  if not (v and player and player.valid) then return end
  local agent = Lec.agent_of_entity(player.selected)
  if agent and v.npc ~= agent.id then
    v.npc = agent.id
    v.sig.npc = nil
    local ok, err = pcall(Cv.refresh_one, player, st, v, game.tick)
    if not ok then snap_of(st, v.fid).err = tostring(err):sub(1, 200) end
  end
end)

Events.on(defines.events.on_gui_click, function(e)
  local el = e.element
  if not (el and el.valid) then return end
  local name = el.name
  if name:sub(1, 7) ~= "fo_dbg_" then return end
  local st = ns()
  local player = game.get_player(e.player_index)
  local v = st and st.viewers[e.player_index]
  if not (player and v) then return end
  if name == "fo_dbg_close" then
    Cv.close(player)
  elseif name == "fo_dbg_pnj_close" then
    v.npc = nil
    Panneau.close_npc(player)
  elseif name:sub(1, #Panneau.ZONE_PREFIX) == Panneau.ZONE_PREFIX then
    v.sel = el.tags and el.tags.key or nil
    v.sig = {}
    Cv.refresh_one(player, st, v, game.tick)
  elseif name == "fo_dbg_auto" then
    v.sel = nil
    v.sig = {}
    Cv.refresh_one(player, st, v, game.tick)
  end
end)

Events.on(defines.events.on_gui_selection_state_changed, function(e)
  local el = e.element
  if not (el and el.valid and el.name == "fo_dbg_force") then return end
  local st = ns()
  local player = game.get_player(e.player_index)
  local v = st and st.viewers[e.player_index]
  if not (player and v) then return end
  local teams = Lec.teams()
  local t = teams[el.selected_index]
  if t then
    v.fid, v.sel, v.sig = t.id, nil, {}
    Rendu.clear(v)
    Cv.refresh_one(player, st, v, game.tick)
  end
end)

Events.on(defines.events.on_gui_closed, function(e)
  local el = e.element
  if el and el.valid and el.name == "fo_dbg_frame" then
    local player = game.get_player(e.player_index)
    if player then Cv.close(player) end
  end
end)

local function leave(e)
  local player = game.get_player(e.player_index)
  local st = ns()
  if player and st and st.viewers[e.player_index] then Cv.close(player) end
end
Events.on(defines.events.on_player_left_game, leave)
Events.on(defines.events.on_player_removed, function(e)
  local st = ns()
  local v = st and st.viewers[e.player_index]
  if v then
    Rendu.clear(v)
    st.viewers[e.player_index] = nil
    count_open(st)
  end
end)

commands.add_command(Cv.COMMAND, { "fo-dbg-cerveau.commande-aide" }, function(cmd)
  local player = cmd.player_index and game.get_player(cmd.player_index)
  if player then Cv.toggle(player) end
end)

---------------------------------------------------------------------------------------------------
-- Interface distante (bancs et captures) : mêmes fonctions que les entrées du joueur
---------------------------------------------------------------------------------------------------
remote.add_interface("fo-dbg-cerveau", {
  open = function(index, fid)
    local p = game.get_player(index)
    return p ~= nil and Cv.open(p, fid)
  end,
  close = function(index)
    local p = game.get_player(index)
    return p ~= nil and Cv.close(p)
  end,
  select = function(index, key)
    local st = ns()
    local v = st and st.viewers[index]
    if not v then return false end
    v.sel, v.sig = key, {}
    return true
  end,
  refresh = function(index)
    local st = ns()
    local p = game.get_player(index)
    local v = st and st.viewers[index]
    if not (p and v) then return false end
    Cv.refresh_one(p, st, v, game.tick)
    return true
  end,
  -- BANC SANS JOUEUR (jamais appelé par le mod) : relève `slices` tranches de CHAQUE équipe observable, calcule les lignes et rend un résumé par
  -- équipe { id, key, zones, mesurees, couleurs = { vert, orange, rouge, gris }, alertes, anneau } ; une erreur Lua se PROPAGE (le banc la voit). Rien
  -- n'est laissé dans l'état de la vue si personne ne la regarde.
  probe_all = function(slices)
    local st = ns()
    if not st then return nil end
    local out = {}
    for _, t in ipairs(Lec.teams()) do
      local s = snap_of(st, t.id)
      for _ = 1, slices or 1 do slice_force(st, t.id, game.tick) end
      local rows = Cv.rows(t.f, s, game.tick)
      local c = { vert = 0, orange = 0, rouge = 0, gris = 0 }
      local alertes, mesurees, io_n = 0, 0, 0
      for _, r in ipairs(rows) do
        c[r.color] = (c[r.color] or 0) + 1
        if r.sev == "alerte" then alertes = alertes + 1 end
        if r.z.mtick then mesurees = mesurees + 1 end
        if r.z.io then io_n = io_n + #r.z.io.ins + #r.z.io.outs end
      end
      out[#out + 1] = { id = tostring(t.id), key = t.key, zones = #s.order, mesurees = mesurees, couleurs = c, alertes = alertes, anneau = #An.get(t.key), liens = #(s.links or {}), ios = io_n }
    end
    if st.open_n == 0 then st.snaps = {} end
    return out
  end,
  -- BANC D'IMAGES SEULEMENT : allume ou éteint les lignes fictives (Lec.demo_projects) ; le recensement est refait au prochain cycle.
  demo = function(on)
    local st = ns()
    if not st then return false end
    st.demo = on == true
    for _, s in pairs(st.snaps or {}) do s.cursor = 0 end -- remise à zéro seule : l'ordre ne compte pas
    return true
  end,
  -- PNJ : numero du premier agent (plus petit numero) de l'equipe `fid` dont le corps existe, ou nil. Le banc d'images l'utilise pour ouvrir le panneau.
  first_npc = function(fid)
    local S = Storage.ns("companion")
    local best
    for id, a in pairs(S and S.agents or {}) do -- minimum seul : l'ordre ne compte pas
      if a.faction == fid and a.entity and a.entity.valid and (best == nil or id < best) then best = id end
    end
    if best == nil then return nil end
    local pos = S.agents[best].entity.position
    return { id = best, x = pos.x, y = pos.y }
  end,
  watch_npc = function(index, id)
    local st = ns()
    local v = st and st.viewers[index]
    local p = game.get_player(index)
    if not (v and p and Lec.agent(id)) then return false end
    v.npc, v.sig.npc = id, nil
    Cv.refresh_one(p, st, v, game.tick)
    return true
  end,
  -- lecture : { n zones, cycles, erreur, lignes = { { key, kind, color, cause, ecart, sev } } } pour la force observée
  state = function(index)
    local st = ns()
    local v = st and st.viewers[index]
    if not v then return nil end
    local s = st.snaps[v.fid]
    local f = Lec.team(v.fid)
    if not (s and f) then return { n = 0 } end
    local out = { n = #s.order, cycles = s.cycles, err = s.err, lignes = {} }
    for _, r in ipairs(Cv.rows(f, s, game.tick)) do
      out.lignes[#out.lignes + 1] = { key = r.key, kind = r.z.kind, x0 = r.z.x0, y0 = r.z.y0, x1 = r.z.x1, y1 = r.z.y1, color = r.color, cause = r.cause, ecart = r.ecart.kind, sev = r.sev,
        reads = #r.reads, measured = r.z.mtick ~= nil }
    end
    return out
  end,
})

return Cv
