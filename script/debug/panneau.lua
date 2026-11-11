--[[
  Lot DEBUG-CERVEAU : panneau de la vue « Cerveau » (fenêtre au centre de l'écran, propre au joueur).
  Trois onglets :
    Zones          liste des zones de la force observée (alertes d'abord) et, pour la zone retenue (cliquée, sinon celle où se tient le
                   joueur) : état RÉEL, ce que le cerveau en sait et depuis quand, écart, production attribuée, tâches prévues ou en cours,
                   améliorations (état, ou « n'existe pas dans le cerveau ») ;
    Décisions      ordres ouverts et terminés de la capitalisation, refus (la RAISON du refus n'est pas conservée par le cerveau : dit tel
                   quel), modules, améliorations choisies ;
    Améliorations  le catalogue : ce qui existe, ce qui n'existe pas dans le cerveau.
  Aucune seconde logique : tout vient de script/debug/cerveau.lua (le modèle) et des règles pures de shared/debug/. Le contenu d'un onglet n'est
  refait que si sa signature change (la liste), sauf le détail, refait à chaque redessin (il porte des âges qui avancent).
]]

local Lg = require("shared.debug.lignes")

local Panneau = {}

-- Boutons des lignes de zone : « fo_dbg_zone_<rang> » (nom unique par ligne, la clé de la zone est dans tags.key).
Panneau.ZONE_PREFIX = "fo_dbg_zone_"

local FRAME = "fo_dbg_frame"
local COLORS = {
  vert = { r = 0.35, g = 0.9, b = 0.4 }, orange = { r = 1, g = 0.7, b = 0.2 }, rouge = { r = 1, g = 0.3, b = 0.3 }, gris = { r = 0.75, g = 0.75, b = 0.75 },
}
local SEV_MARK = { alerte = "[!!]", attention = "[!]", info = "[i]", ok = "[ok]" }
local SEV_COLOR = { alerte = { r = 1, g = 0.3, b = 0.3 }, attention = { r = 1, g = 0.7, b = 0.2 }, info = { r = 0.7, g = 0.8, b = 1 }, ok = { r = 0.6, g = 1, b = 0.6 } }
local ABSENT_COLOR = { r = 1, g = 0.7, b = 0.2 }

local function frame_of(player) return player.gui.screen[FRAME] end

local function find(el, name)
  for _, ch in ipairs(el.children) do
    if ch.name == name then return ch end
    local r = find(ch, name)
    if r then return r end
  end
  return nil
end

local function lbl(parent, caption, color, wrap)
  local l = parent.add({ type = "label", caption = caption })
  if color then l.style.font_color = color end
  if wrap then l.style.single_line = false l.style.maximal_width = 440 end
  return l
end

local function build_frame(player)
  local frame = player.gui.screen.add({ type = "frame", name = FRAME, direction = "vertical", caption = { "fo-dbg-cerveau.titre" } })
  frame.auto_center = true
  local top = frame.add({ type = "flow", direction = "horizontal" })
  top.style.vertical_align = "center"
  top.add({ type = "label", caption = { "fo-dbg-cerveau.force" } })
  top.add({ type = "drop-down", name = "fo_dbg_force", items = {} })
  local sum = top.add({ type = "label", name = "fo_dbg_resume" })
  sum.style.left_margin = 12
  local sp = top.add({ type = "empty-widget" })
  sp.style.horizontally_stretchable = true
  top.add({ type = "button", name = "fo_dbg_close", caption = { "fo-dbg-cerveau.fermer" } })
  local err = frame.add({ type = "label", name = "fo_dbg_err" })
  err.style.font_color = { r = 1, g = 0.3, b = 0.3 }
  err.visible = false
  local tabs = frame.add({ type = "tabbed-pane", name = "fo_dbg_tabs" })
  local t1 = tabs.add({ type = "tab", caption = { "fo-dbg-cerveau.onglet-zones" } })
  local c1 = tabs.add({ type = "flow", name = "fo_dbg_t1", direction = "horizontal" })
  tabs.add_tab(t1, c1)
  local left = c1.add({ type = "flow", direction = "vertical" })
  left.add({ type = "button", name = "fo_dbg_auto", caption = { "fo-dbg-cerveau.auto" }, tooltip = { "fo-dbg-cerveau.auto-aide" } })
  local list = left.add({ type = "scroll-pane", name = "fo_dbg_list" })
  list.style.minimal_width = 370
  list.style.maximal_width = 370
  list.style.minimal_height = 440
  list.style.maximal_height = 440
  local detail = c1.add({ type = "scroll-pane", name = "fo_dbg_detail" })
  detail.style.minimal_width = 470
  detail.style.minimal_height = 480
  detail.style.maximal_height = 480
  local t2 = tabs.add({ type = "tab", caption = { "fo-dbg-cerveau.onglet-decisions" } })
  local c2 = tabs.add({ type = "scroll-pane", name = "fo_dbg_dec" })
  c2.style.minimal_width = 860
  c2.style.minimal_height = 480
  c2.style.maximal_height = 480
  tabs.add_tab(t2, c2)
  local t3 = tabs.add({ type = "tab", caption = { "fo-dbg-cerveau.onglet-ameliorations" } })
  local c3 = tabs.add({ type = "scroll-pane", name = "fo_dbg_am" })
  c3.style.minimal_width = 860
  c3.style.minimal_height = 480
  c3.style.maximal_height = 480
  tabs.add_tab(t3, c3)
  tabs.selected_tab_index = 1
  player.opened = frame
  return frame
end

function Panneau.close(player)
  local frame = frame_of(player)
  if frame then frame.destroy() end
end

local NPC = "fo_dbg_pnj_frame"

function Panneau.close_npc(player)
  local f = player.gui.screen[NPC]
  if f then f.destroy() end
end

local function npc_task_line(t)
  local target = ""
  if t.outpost then target = "avant-poste " .. tostring(t.outpost)
  elseif t.pid then target = "projet " .. tostring(t.pid) .. (t.mode and (" / " .. tostring(t.mode)) or "")
  elseif t.resource then target = tostring(t.resource) end
  return { "fo-dbg-cerveau.pnj-tache", { "fo-dbg-cerveau.tache-" .. Lg.task_key(t.kind, t.mode) }, tostring(t.key), target, tostring(t.prio or "?") }
end

local function explain_line(ex)
  local c = ex.cause
  if c == "matiere" then
    return { "fo-dbg-cerveau.pnj-cause-matiere", tostring(ex.key), Lg.item(ex.item), tostring(ex.need or "?"), tostring(ex.free or "?"), tostring(ex.n or 0) }
  elseif c == "pauses" then
    return { "fo-dbg-cerveau.pnj-cause-pauses", tostring(ex.key), Lg.ago(ex.left), tostring(ex.n or 0) }
  elseif c == "pret" then
    return { "fo-dbg-cerveau.pnj-cause-pret", tostring(ex.key), tostring(ex.n or 0), tostring(ex.n_pause or 0), tostring(ex.n_matiere or 0) }
  elseif c == "attente" then
    return { "fo-dbg-cerveau.pnj-cause-attente", string.format("%.0f", (ex.left or 0) / 60) }
  elseif c == "marche_echec" then
    return { "fo-dbg-cerveau.pnj-cause-marche_echec", tostring(ex.why) }
  end
  return { "fo-dbg-cerveau.pnj-cause-" .. c }
end

--- Panneau d'un PNJ (état cognitif complet) : tâche en cours, étapes restantes, cause d'inactivité, tâches suivantes du tableau, sac. `npc` : Lec.npc.
function Panneau.update_npc(player, v, npc, gone)
  if not npc and not gone then Panneau.close_npc(player) return end
  local frame = player.gui.screen[NPC]
  if not frame then
    frame = player.gui.screen.add({ type = "frame", name = NPC, direction = "vertical", caption = { "fo-dbg-cerveau.pnj-titre" } })
    frame.location = { x = 12, y = 110 }
  end
  frame.clear()
  local top = frame.add({ type = "flow", direction = "horizontal" })
  local sp = top.add({ type = "empty-widget" })
  sp.style.horizontally_stretchable = true
  top.add({ type = "button", name = "fo_dbg_pnj_close", caption = { "fo-dbg-cerveau.fermer" } })
  if gone or not npc then
    lbl(frame, { "fo-dbg-cerveau.pnj-disparu" }, nil, true)
    return
  end
  local now = npc.now
  local h = lbl(frame, { "fo-dbg-cerveau.pnj-entete", tostring(npc.id), npc.team, { "fo-dbg-cerveau.pnj-etat-" .. npc.state }, tostring(npc.role or "?"), tostring(npc.pole or "?") })
  h.style.font = "default-bold"
  -- tâche en cours
  local t1 = lbl(frame, { "fo-dbg-cerveau.pnj-h-tache" })
  t1.style.font = "default-bold"
  if npc.task then lbl(frame, npc_task_line(npc.task), nil, true) else lbl(frame, { "fo-dbg-cerveau.pnj-sans-tache" }) end
  -- étapes
  if npc.task then
    local t2 = lbl(frame, { "fo-dbg-cerveau.pnj-h-etapes", npc.steps.left, npc.steps.total })
    t2.style.font = "default-bold"
    for _, r in ipairs(npc.steps.rows) do
      lbl(frame, { "fo-dbg-cerveau.pnj-etape", r.current and ">" or " ", { "fo-dbg-cerveau.pnj-etape-" .. r.kind }, r.arg }, r.current and { r = 1, g = 1, b = 0.6 } or nil)
    end
  end
  -- cause
  local t3 = lbl(frame, { "fo-dbg-cerveau.pnj-h-cause" })
  t3.style.font = "default-bold"
  local ex = lbl(frame, explain_line(npc.explain), (npc.explain.cause == "en_marche") and nil or { r = 1, g = 0.75, b = 0.3 }, true)
  ex.style.maximal_width = 420
  -- tâches suivantes
  local t4 = lbl(frame, { "fo-dbg-cerveau.pnj-h-suivantes" })
  t4.style.font = "default-bold"
  if #npc.nexts == 0 then lbl(frame, { "fo-dbg-cerveau.pnj-aucune-suivante" }) end
  for _, r in ipairs(npc.nexts) do
    local st
    if r.status == "pause" then st = { "fo-dbg-cerveau.pnj-sv-pause", Lg.ago(r.pause) }
    elseif r.status == "matiere" then st = { "fo-dbg-cerveau.pnj-sv-matiere", Lg.item(r.item), tostring(r.need or "?"), tostring(r.free or "?") }
    else st = { "fo-dbg-cerveau.pnj-sv-ok" } end
    lbl(frame, { "fo-dbg-cerveau.pnj-suivante", { "fo-dbg-cerveau.tache-" .. Lg.task_key(r.kind, nil) }, tostring(r.key), tostring(r.prio or "?"), st }, nil, true)
  end
  if npc.team_sur then
    lbl(frame, { "fo-dbg-cerveau.pnj-equipe", tostring(npc.team_sur.starved or "?"), tostring(npc.team_sur.want or "?"), tostring(npc.team_sur.service or "?"), tostring(npc.team_sur.mine or "?") }, nil, true)
  end
  if npc.gate then
    lbl(frame, { "fo-dbg-cerveau.pnj-porte", npc.gate.why, Lg.ago(npc.gate.age) }, nil, true)
  end
  if npc.zero_idle then
    local z = npc.zero_idle
    lbl(frame, { "fo-dbg-cerveau.pnj-zero", tostring(z.libres or "?"), tostring(z.emis or "?"), tostring(z.restes or "?"), { "fo-dbg-cerveau.pnj-zero-" .. z.cause }, Lg.ago(z.age) }, nil, true)
  end
  if npc.team_idle then
    lbl(frame, { "fo-dbg-cerveau.pnj-rien", tostring(npc.team_idle.n or "?"), { "fo-dbg-cerveau.pnj-rien-" .. npc.team_idle.code }, Lg.ago(npc.team_idle.age) }, nil, true)
  end
  -- sac
  if npc.carry and #npc.carry > 0 then
    local parts = {}
    for _, c in ipairs(npc.carry) do parts[#parts + 1] = tostring(c.item) .. " " .. tostring(c.n) end
    lbl(frame, { "fo-dbg-cerveau.pnj-sac", table.concat(parts, ", ") }, nil, true)
  end
end

local function team_label(t)
  if t.id == "player" then return { "fo-dbg-cerveau.equipe-joueur" } end
  return tostring(t.key)
end

local function zone_title(z)
  return { "fo-dbg-cerveau.detail-titre", { "fo-dbg-cerveau.sorte-" .. tostring(z.kind) }, tostring(z.key), { "fo-dbg-cerveau.etat-" .. tostring(z.state) } }
end

local function cause_text(row)
  if row.color == "vert" then return { "fo-dbg-cerveau.cause-aucune" } end
  return { "fo-dbg-cerveau.cause-" .. tostring(row.cause or "inconnu") }
end

local function list_sig(ctx, v)
  local parts = { tostring(v.fid), tostring(ctx.sel and ctx.sel.key) }
  for _, r in ipairs(ctx.rows) do parts[#parts + 1] = r.key .. ":" .. r.color .. ":" .. r.sev .. ":" .. tostring(r.cause) end
  return table.concat(parts, "|")
end

local function fill_list(list, ctx)
  list.clear()
  for i, r in ipairs(ctx.rows) do
    local z = r.z
    -- Un nom par ligne : le moteur refuse deux enfants de même nom (crash du DC en 0.6.96 dès 2 zones) ; la clé reste dans tags.
    local b = list.add({ type = "button", name = Panneau.ZONE_PREFIX .. i, style = "list_box_item", tags = { key = r.key },
      caption = { "fo-dbg-cerveau.ligne-zone", SEV_MARK[r.sev] or "", tostring(r.key), { "fo-dbg-cerveau.sorte-" .. tostring(z.kind) }, cause_text(r) } })
    b.style.horizontally_stretchable = true
    b.style.font_color = COLORS[r.color] or COLORS.gris
    if ctx.sel and ctx.sel.key == r.key then b.style.font = "default-bold" end
  end
  if #ctx.rows == 0 then lbl(list, { "fo-dbg-cerveau.aucune-zone" }, nil, true) end
end

local function fill_detail(detail, ctx)
  detail.clear()
  local row = ctx.sel
  if not row then
    lbl(detail, { "fo-dbg-cerveau.aucune-zone" }, nil, true)
    return
  end
  local z, now = row.z, ctx.now
  local h = lbl(detail, zone_title(z))
  h.style.font = "default-bold"
  if z.reason then lbl(detail, { "fo-dbg-cerveau.detail-raison", tostring(z.reason) }, nil, true) end
  if z.total and z.total > 0 then lbl(detail, { "fo-dbg-cerveau.detail-pose", z.built or 0, z.total }) end
  -- production attribuée
  if z.product then
    lbl(detail, { "fo-dbg-cerveau.detail-produit", Lg.item(z.product), z.rate_meas and string.format("%.0f", z.rate_meas) or "?",
      z.rate_nom and string.format("%.0f", z.rate_nom) or "?" })
  end
  -- état réel
  lbl(detail, "")
  local real = lbl(detail, { "fo-dbg-cerveau.detail-reel", { "fo-dbg-cerveau.couleur-" .. row.color }, cause_text(row) }, COLORS[row.color], true)
  real.style.font = "default-bold"
  if z.n and z.n > 0 then
    lbl(detail, { "fo-dbg-cerveau.detail-machines", z.n, string.format("%.0f", (z.ratio or 0) * 100), Lg.ago(z.mtick and (now - z.mtick) or nil) })
    for i, t in ipairs(z.top or {}) do
      if i > 3 then break end
      lbl(detail, { "fo-dbg-cerveau.detail-top", t.n, { "fo-dbg-cerveau.cause-" .. t.cause } })
    end
  elseif row.color ~= "gris" or z.cause == "non_mesure" then
    lbl(detail, { "fo-dbg-cerveau.detail-non-mesure" }, nil, true)
  end
  -- ce que le cerveau en sait
  lbl(detail, "")
  local h2 = lbl(detail, { "fo-dbg-cerveau.detail-ia" })
  h2.style.font = "default-bold"
  if #row.reads == 0 then
    lbl(detail, { "fo-dbg-cerveau.detail-ia-rien" }, nil, true)
  else
    for _, rd in ipairs(row.reads) do
      local ag = rd.tick and (now - rd.tick) or nil
      lbl(detail, { "fo-dbg-cerveau.detail-lecture", { "fo-dbg-cerveau.source-" .. tostring(rd.src) }, { "fo-dbg-cerveau.verdict-" .. tostring(rd.verdict) },
        rd.why and { "fo-dbg-cerveau.cause-" .. tostring(rd.why) } or "", Lg.ago(ag) }, nil, true)
    end
  end
  local ec = row.ecart
  local el = lbl(detail, { "fo-dbg-cerveau.detail-ecart", ec.text, SEV_MARK[ec.sev] or "" }, SEV_COLOR[ec.sev], true)
  el.style.font = "default-bold"
  -- tâches
  lbl(detail, "")
  local h3 = lbl(detail, { "fo-dbg-cerveau.detail-taches" })
  h3.style.font = "default-bold"
  if #ctx.sel_tasks == 0 then
    lbl(detail, { "fo-dbg-cerveau.detail-taches-aucune" }, nil, true)
  else
    for _, t in ipairs(ctx.sel_tasks) do
      lbl(detail, { "fo-dbg-cerveau.detail-tache", { "fo-dbg-cerveau.tache-" .. Lg.task_key(t.kind, t.mode) },
        { t.taken and "fo-dbg-cerveau.tache-prise" or "fo-dbg-cerveau.tache-libre" }, t.item and Lg.item(t.item) or "", tostring(t.prio or "?") }, nil, true)
    end
  end
  -- liaisons enregistrées qui touchent ce bloc
  local h5 = lbl(detail, { "fo-dbg-cerveau.detail-liaisons" })
  h5.style.font = "default-bold"
  if #(ctx.sel_links or {}) == 0 then lbl(detail, { "fo-dbg-cerveau.detail-liaisons-aucune" }, nil, true) end
  for _, l in ipairs(ctx.sel_links or {}) do
    local sens = (l.dock_pid == row.z.pid) and "entree" or "sortie"
    local autre = sens == "entree" and l.src_pid or l.dock_pid
    lbl(detail, { "fo-dbg-cerveau.detail-liaison", { "fo-dbg-cerveau.lien-" .. l.kind }, { "fo-dbg-cerveau.lien-sens-" .. sens }, l.item and Lg.item(l.item) or "?",
      autre and { "fo-dbg-cerveau.lien-source-bloc", tostring(autre) } or { "fo-dbg-cerveau.lien-source-tapis" },
      l.status == "actif" and { "fo-dbg-cerveau.lien-statut-actif" } or Lg.link_state(l) }, nil, true)
  end
  -- piquage des quais d'entrée de la zone (lot PIQUAGE)
  for _, q in ipairs(ctx.sel_piquage or {}) do
    lbl(detail, { "fo-dbg-cerveau.detail-piquage", q.i, { "fo-dbg-cerveau.pq-verdict-" .. q.verdict }, { "fo-dbg-cerveau.pq-cause-" .. q.cause },
      Lg.ago(q.tick and (now - q.tick) or nil) }, nil, true)
  end
  -- refus d'amélioration de niveau de la zone (lot AMELIORATION)
  for _, a in ipairs(ctx.sel_am_refus or {}) do
    lbl(detail, { "fo-dbg-cerveau.detail-am-refus", a.famille, { "fo-dbg-cerveau.am-refus-" .. a.cause }, Lg.ago(a.tick and (now - a.tick) or nil) }, nil, true)
  end
  -- améliorations
  lbl(detail, "")
  local h4 = lbl(detail, { "fo-dbg-cerveau.detail-ameliorations" })
  h4.style.font = "default-bold"
  for _, a in ipairs(ctx.improvements) do
    local cap = { "fo-dbg-cerveau.detail-amelioration", { "fo-dbg-cerveau.am-" .. a.key }, { "fo-dbg-cerveau.amstate-" .. a.state }, a.why and { "", " : ", a.why } or "" }
    lbl(detail, cap, a.state == "absente" and ABSENT_COLOR or nil, true)
  end
end

local function fill_decisions(el, ctx)
  el.clear()
  if #ctx.decisions == 0 then lbl(el, { "fo-dbg-cerveau.aucune-decision" }, nil, true) return end
  for _, d in ipairs(ctx.decisions) do
    local ag = d.tick and (ctx.now - d.tick) or nil
    local l = lbl(el, { "fo-dbg-cerveau.ligne-decision", Lg.ago(ag), { "fo-dbg-cerveau.decision-" .. tostring(d.kind) }, d.ltext or tostring(d.text) }, nil, true)
    l.style.maximal_width = 840
  end
end

local function fill_ameliorations(el, ctx)
  el.clear()
  local intro = lbl(el, { "fo-dbg-cerveau.am-intro" }, nil, true)
  intro.style.maximal_width = 840
  for _, a in ipairs(ctx.improvements) do
    local h = lbl(el, { "fo-dbg-cerveau.am-ligne", { "fo-dbg-cerveau.am-" .. a.key }, { "fo-dbg-cerveau.amstate-" .. a.state } }, a.state == "absente" and ABSENT_COLOR or nil)
    h.style.font = "default-bold"
    local n = lbl(el, { "fo-dbg-cerveau.am-note-" .. a.key .. (a.present and "-present" or "") }, nil, true)
    n.style.left_margin = 16
    n.style.maximal_width = 820
    if a.owner then
      local o = lbl(el, { "fo-dbg-cerveau.am-ou", tostring(a.owner) }, nil, true)
      o.style.left_margin = 16
    end
    if a.why then
      local w = lbl(el, { "fo-dbg-cerveau.am-pourquoi", a.why }, nil, true)
      w.style.left_margin = 16
    end
  end
end

--- Met la fenêtre à jour (la crée si besoin). ctx : modèle de script/debug/cerveau.lua (Cv.refresh_one).
function Panneau.update(player, v, ctx)
  local frame = frame_of(player) or build_frame(player)
  local s = ctx.snap
  -- barre du haut
  local dd = find(frame, "fo_dbg_force")
  local items, idx = {}, 1
  for i, t in ipairs(ctx.teams) do
    items[i] = team_label(t)
    if t.id == v.fid then idx = i end
  end
  local sig_top = tostring(#items) .. ":" .. tostring(idx)
  if v.sig.top ~= sig_top then
    v.sig.top = sig_top
    dd.items = items
    dd.selected_index = idx
  end
  find(frame, "fo_dbg_resume").caption = { "fo-dbg-cerveau.resume", #ctx.rows, ctx.sev_count.alerte or 0, ctx.sev_count.attention or 0, s.cycles or 0 }
  local err = find(frame, "fo_dbg_err")
  err.visible = s.err ~= nil
  if s.err then err.caption = { "fo-dbg-cerveau.erreur", s.err } end
  -- onglets
  local sl = list_sig(ctx, v)
  if v.sig.list ~= sl then
    v.sig.list = sl
    fill_list(find(frame, "fo_dbg_list"), ctx)
  end
  fill_detail(find(frame, "fo_dbg_detail"), ctx)
  if ctx.npc then ctx.npc.now = ctx.now end
  Panneau.update_npc(player, v, ctx.npc, ctx.npc_gone)
  local sd = tostring(#ctx.decisions) .. ":" .. (ctx.decisions[1] and (tostring(ctx.decisions[1].tick) .. tostring(ctx.decisions[1].text)) or "")
  if v.sig.dec ~= sd then
    v.sig.dec = sd
    fill_decisions(find(frame, "fo_dbg_dec"), ctx)
  end
  local sa = {}
  for _, a in ipairs(ctx.improvements) do sa[#sa + 1] = a.key .. a.state .. (type(a.why) == "table" and table.concat({ tostring(a.why[2] and a.why[2][1]), tostring(a.why[3] and a.why[3][1]), tostring(a.why[4]) }, ",") or tostring(a.why)) end
  sa = table.concat(sa, "|")
  if v.sig.am ~= sa then
    v.sig.am = sa
    fill_ameliorations(find(frame, "fo_dbg_am"), ctx)
  end
end

--- Pour les bancs : onglet affiché.
function Panneau.select_tab(player, index)
  local frame = frame_of(player)
  local tabs = frame and find(frame, "fo_dbg_tabs")
  if tabs then tabs.selected_tab_index = index end
end

return Panneau
