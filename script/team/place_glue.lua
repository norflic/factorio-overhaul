--[[
  Lot TV-PLACE, branchement du plan directeur (script/team/build.lua) : sonde de 30 x 30 (G37), défrichage préventif de 50 x 50 (G38) et repli
  de placement simple (C07). Règles pures : shared/team/sonde_lot.lua, shared/team/defrichage_prev.lua, shared/team/place_simple.lua. Requis
  au CHARGEMENT dans un champ de Build (`Build.Place`) : le bloc principal de build.lua est à 199 locales sur 200. Le point G57 (sites des
  factions) est branché dans script/faction/sites.lua, sans passer par ici.

  Chaîne de chaque point (déclencheur -> décision -> action -> effet visible) :
    G37  eval_one (lot) -> Pg.evaluated : un lot libre ou à défricher dont la sonde de 30 x 30 voit un gisement qui n'est pas dans le lot
         (Sl.edge) -> l.edge = minerai -> Pg.states_for (appelé par Lots_minerai.states) marque `no_edge` -> candidates() écarte le lot
         pour une fabrique -> la fabrique va dans un autre lot ou le treillis grandit ; ligne [FO-SONDE].
    G38  Build.think (tâches) -> Pg.defprev_tasks : lot « à défricher » proche du QG (Dp.pick) -> quatre tâches « clear » de 25 x 25 à la
         priorité la plus basse (pid 0, seg « pre:<lot>:<quart> ») -> Build.work (mode clear) passe par Pg.defprev_gate (jeton des travaux
         lourds, Lourd.take) puis coupe ; Build.street_cleared -> Pg.defprev_cleared ; au quatrième quart le lot est remis à la file
         d'évaluation -> Pg.evaluated écrit le résultat ; lignes [FO-DEFRICHAGE-PREV].
    C07  plan_project : place_module n'a rien trouvé -> Pg.simple (spirale, marge 0, mêmes états) -> projet planifié sans faire grandir le
         treillis ; ligne [FO-PLACE-SIMPLE] (pose ou échec).
  État : f.build.defprev = { open, since, q, last } (chaînes, nombres, booléens), l.edge (chaîne), l.pre_n (nombre), f.build.place_n
  (compteurs) ; aucune fonction dans global.
]]

local Lm = require("shared.team.lot_minerai")
local Sl = require("shared.team.sonde_lot")
local Dp = require("shared.team.defrichage_prev")
local Ps = require("shared.team.place_simple")
local P = require("shared.team.plan")
local Lourd = require("script.core.lourd")

local Pg = {}
Pg.LOGS = 12      -- lignes de journal par équipe et par cause, au plus (les compteurs restent exacts)
Pg.PRIO_PREV = 40 -- priorité des tâches de défrichage préventif : sous toutes celles du plan directeur (Build.PRIO = 55)

local function setting(name)
  local ok, v = pcall(function() return settings.global[name].value end)
  return ok and v == true
end
function Pg.sonde_on() return setting("fo-war-sonde-30") end
function Pg.sites_on() return setting("fo-war-sites-10") end
function Pg.defprev_on() return setting("fo-war-defrichage-prev") end
function Pg.simple_on() return setting("fo-war-place-simple") end

local function sorted_keys(t)
  local ks = {}
  for k in next, t do ks[#ks + 1] = k end
  table.sort(ks, function(a, c) return tostring(a) < tostring(c) end)
  return ks
end

--- Compteurs de l'équipe (nombres seulement).
local function counters(f)
  local b = f.build
  b.place_n = b.place_n or {}
  return b.place_n
end
local function bump(f, name, n)
  local c = counters(f)
  c[name] = (c[name] or 0) + (n or 1)
  return c[name]
end
--- Une ligne de journal au plus Pg.LOGS fois par cause ; faux si la limite est atteinte.
local function may_log(f, cause)
  return bump(f, "logs_" .. cause) <= Pg.LOGS
end

---------------------------------------------------------------------------------------------------
-- G37 : sonde de 30 x 30
---------------------------------------------------------------------------------------------------
--- États de lots d'une sorte (Lots_minerai.states) : la marque `no_edge` de la fabrique quand la sonde est allumée.
function Pg.states_for(kind)
  if Pg.sonde_on() then return Sl.states_for(kind) end
  return Lm.states_for(kind)
end

--- eval_one (lot), après Lots_minerai.evaluated : relevé de la sonde large (minerai seulement) d'un lot libre ou à défricher.
--- `survey_amount(s, e, seg)` : la fonction de quantité du relevé (Lots_minerai.amount) ; `seuils` : Lots_minerai.seuils() (nil : défaut).
function Pg.evaluated(f, surface, tick, k, l, s, x0, y0, x1, y1, old, survey_amount, seuils)
  local was = l.edge
  l.edge = nil
  -- résultat d'un défrichage préventif : la remise à la file d'évaluation a posé l.pre_wait (état d'avant)
  if l.pre_wait then
    if may_log(f, "prev_res") then
      log(string.format("[FO-DEFRICHAGE-PREV] %s : lot %s releve apres le defrichage preventif : %s -> %s (%d obstacle(s) restant(s)) a %.1f min",
        f.key or "player", tostring(k), tostring(l.pre_wait), tostring(l.state), (l.trees or 0), tick / 3600))
    end
    bump(f, l.state == "libre" and "prev_libre" or "prev_encore")
    l.pre_wait = nil
  end
  if not Pg.sonde_on() then return end
  if l.state ~= "libre" and l.state ~= "defricher" then return end
  local wx0, wy0, wx1, wy1 = Sl.rect(x0, y0, x1, y1)
  local area = { { wx0 + 0.01, wy0 + 0.01 }, { wx1 - 0.01, wy1 - 0.01 } }
  if surface.count_entities_filtered({ area = area, type = "resource", limit = 1 }) == 0 then
    if was then bump(f, "edge_gone") end
    return
  end
  local w = { res = {} }
  for _, e in ipairs(surface.find_entities_filtered({ area = area, type = "resource" })) do
    w.res[e.name] = (w.res[e.name] or 0) + 1
    if survey_amount then survey_amount(w, e, false) end
  end
  local main, n_wide, n_in = Sl.edge(s, w, seuils)
  if not main then
    if was then bump(f, "edge_gone") end
    return
  end
  l.edge = main
  if not was then
    bump(f, "edge")
    if may_log(f, "edge") then
      log(string.format("[FO-SONDE] %s : lot %s en BORD de gisement (%s : %d tuile(s) dans la sonde de %dx%d, %d dans le lot) a %.1f min : reserve a la fonte et aux foreuses, plus donne aux fabriques",
        f.key or "player", tostring(k), tostring(main), n_wide, Sl.SIZE, Sl.SIZE, n_in, tick / 3600))
    end
  end
end

---------------------------------------------------------------------------------------------------
-- C07 : repli de placement simple
---------------------------------------------------------------------------------------------------
--- Lots du repli simple pour un ensemble d'états : liste de { l, d, k } dans l'ordre de la spirale (place_module les lit à la place de candidates).
function Pg.simple_candidates(b, states)
  local lots = {}
  -- l'ordre de parcours de b.lots est sans effet : Ps.order trie TOUT (couronne, distance, j, i, clé) ; on ne garde que les lots éligibles
  -- avant de trier (361 lots au rayon 9 : le tri des seuls éligibles coûte moins du quart)
  for k, l in next, b.lots do
    if Ps.eligible(l, states) then lots[#lots + 1] = { k = k, i = l.i, j = l.j, state = l.state, reason = l.reason, used = l.used, out = l.out, edge = l.edge } end
  end
  local out = {}
  for _, k in ipairs(Ps.order(lots, states)) do out[#out + 1] = { l = b.lots[k], d = 0, k = k } end
  return out
end

--- plan_project : place_module n'a pas trouvé de place pour `g`. `states_list` : ensembles d'états de la sorte, dans l'ordre ;
--- `try(states, fopts)` : place_module avec ces états et ces options (fopts.simple_lots posé). Rend (place, raison) comme place_module.
function Pg.simple(f, p, g, why, states_list, try, tick)
  local b = f.build
  local tried, first_states = 0, nil
  for _, states in ipairs(states_list) do
    local cands = Pg.simple_candidates(b, states)
    if #cands > 0 then
      tried = tried + #cands
      first_states = first_states or states
      local fo = Ps.fit_opts()
      fo.simple_lots = cands
      local m, w = try(states, fo)
      if m then
        bump(f, "simple_ok")
        if may_log(f, "simple") then
          local l = b.lots[m.lot]
          log(string.format("[FO-PLACE-SIMPLE] %s : projet %d (%s) sans place par le plan (%s) : repli simple, lot %s (couronne %d) pose apres %d lot(s) en spirale a %.1f min, le treillis ne grandit pas",
            f.key or "player", p.id, tostring(g.gen), tostring(why), tostring(m.lot), l and math.max(math.abs(l.i), math.abs(l.j)) or -1, tried, tick / 3600))
        end
        return m, w
      end
    end
  end
  bump(f, "simple_ko")
  if may_log(f, "simple") then
    log(string.format("[FO-PLACE-SIMPLE] %s : projet %d (%s) sans place par le plan (%s) : repli simple sans effet (%d lot(s) en spirale essaye(s)), le treillis grandit a %.1f min",
      f.key or "player", p.id, tostring(g.gen), tostring(why), tried, tick / 3600))
  end
  return nil, why
end

---------------------------------------------------------------------------------------------------
-- G38 : défrichage préventif de 50 x 50
---------------------------------------------------------------------------------------------------
local function seg_key(k, q) return "pre:" .. k .. ":" .. q end
local function parse_seg(seg)
  local k, q = tostring(seg):match("^pre:(.+):(%d)$")
  return k, tonumber(q)
end

local function abandon(f, st, tick, why)
  local k = st.open
  local l = k and f.build.lots[k]
  bump(f, "prev_abandon")
  if may_log(f, "prev_stop") then
    log(string.format("[FO-DEFRICHAGE-PREV] %s : lot %s abandonne (%s) apres %.1f min, %d quart(s) coupe(s) sur 4",
      f.key or "player", tostring(k), why, (tick - (st.since or tick)) / 3600, Dp.QUARTERS - #Dp.pending(st)))
  end
  if l then l.pre_wait = nil end
  Dp.finish(st, tick)
end

--- Build.think (tâches du tableau, après les rues) : ouvre au besoin un lot à défricher d'avance et pose les tâches de ses quarts à couper.
function Pg.defprev_tasks(f, out, tick)
  if not Pg.defprev_on() then return end
  local b = f.build
  if not (b and b.lots and b.lat) then return end
  local st = b.defprev
  if not st then st = Dp.new(); b.defprev = st end
  if Dp.expired(st, tick) then abandon(f, st, tick, "trop long") end
  if not st.open then
    local clearing = 0
    for _, id in ipairs(b.order or {}) do
      local p = b.projects[id]
      if p and p.state == "defrichage" then clearing = clearing + 1 end
    end
    local ctx = { clearing = clearing, threatened = tick < (f.threatened_until or 0) }
    if Dp.gate(st, tick, ctx) then return end
    local lots = {}
    for _, k in ipairs(sorted_keys(b.lots)) do
      local l = b.lots[k]
      if l.state == "defricher" then
        lots[#lots + 1] = { k = k, i = l.i, j = l.j, state = l.state, used = l.used, bad = l.bad, out = l.out, pre_n = l.pre_n }
      end
    end
    local k = Dp.pick(lots, st, tick, ctx)
    if not k then return end
    local l = b.lots[k]
    Dp.start(st, k, tick)
    l.pre_n = (l.pre_n or 0) + 1
    bump(f, "prev_lots")
    if may_log(f, "prev_start") then
      log(string.format("[FO-DEFRICHAGE-PREV] %s : lot %s (couronne %d, %d obstacle(s) releve(s), tentative %d) : defrichage preventif %dx%d en %d quarts a %.1f min",
        f.key or "player", k, math.max(math.abs(l.i), math.abs(l.j)), l.trees or 0, l.pre_n, Dp.SIZE, Dp.SIZE, Dp.QUARTERS, tick / 3600))
    end
  end
  local l = b.lots[st.open]
  if not l then Dp.finish(st, tick) return end
  local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
  local qs = Dp.quarters(Dp.rect(x0, y0, x1, y1))
  for _, q in ipairs(Dp.pending(st)) do
    local r = qs[q]
    out[#out + 1] = {
      key = "ia1d:pre:" .. st.open .. ":" .. q, kind = "clear", prio = Pg.PRIO_PREV, domain = "logistique", work = 40,
      ia1d = { pid = 0, mode = "clear", seg = seg_key(st.open, q), ax = r.ax, ay = r.ay, rect = { r.x0, r.y0, r.x1, r.y1 } },
    }
  end
end

--- Build.street_cleared : un quart est coupé. Au quatrième, le lot est remis à la file d'évaluation (résultat écrit par Pg.evaluated).
function Pg.defprev_cleared(f, seg, tick)
  local b = f.build
  local st = b and b.defprev
  local k, q = parse_seg(seg)
  if not (st and k and st.open == k) then return end
  if Dp.quarter_done(st, q) then
    local l = b.lots[k]
    if l then
      l.pre_wait = l.state
      b.queue[#b.queue + 1] = { "lot", k }
    end
    if may_log(f, "prev_end") then
      log(string.format("[FO-DEFRICHAGE-PREV] %s : lot %s, 4 quarts coupes en %.1f min : releve a refaire a %.1f min",
        f.key or "player", k, (tick - (st.since or tick)) / 3600, tick / 3600))
    end
    bump(f, "prev_done")
    st.done = st.done or {}
    if #st.done < 8 then st.done[#st.done + 1] = k end
    Dp.finish(st, tick)
  end
end

--- Build.work (mode clear d'une tâche « pre: ») : le relevé du quart passe sous le jeton des travaux lourds. Rend nil (on coupe), "more" (le
--- jeton est pris par d'autres : le PNJ réessaie à sa pensée suivante) ou "done" (patience épuisée : la tâche sera reposée).
function Pg.defprev_gate(f, job, tick)
  if not (job and type(job.seg) == "string" and job.seg:sub(1, 4) == "pre:") then return nil end
  if Lourd.take(tick, "defprev:" .. tostring(f.key or "player"), nil, Dp.COST) then
    job.waits = nil
    return nil
  end
  job.waits = (job.waits or 0) + 1
  bump(f, "prev_wait")
  if job.waits > Dp.WAIT_MAX then
    job.waits = nil
    bump(f, "prev_giveup")
    return "done"
  end
  return "more"
end

--- Build.work : `n` obstacles coupés par une tâche « pre: » (compteur du journal).
function Pg.cut(f, seg, n)
  if n > 0 and type(seg) == "string" and seg:sub(1, 4) == "pre:" then bump(f, "prev_cut", n) end
end

--- Lecture pour les bancs (remote fo-ia1d.place) : compteurs de l'équipe et lots en bord de gisement.
function Pg.remote(f, cmd)
  local b = f and f.build
  if not b then return nil end
  if cmd ~= "report" then return nil end
  local edges = {}
  for _, k in ipairs(sorted_keys(b.lots or {})) do
    local l = b.lots[k]
    if l.edge then edges[#edges + 1] = k .. "=" .. l.edge end
  end
  local c = {}
  for _, n in ipairs(sorted_keys(b.place_n or {})) do c[n] = b.place_n[n] end
  local st = b.defprev
  return { counters = c, edges = edges, open = st and st.open, last = st and st.last, done = st and st.done or {}, sonde = Pg.sonde_on(), sites = Pg.sites_on(),
    defprev = Pg.defprev_on(), simple = Pg.simple_on() }
end

return Pg
