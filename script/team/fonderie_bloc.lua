--[[
  Lot FONDERIE-BLOC (retour du DC du 8/11, 0.6.66) : le COFFRE DE CHARBON d'une fonderie de champ devient une entrée de bloc reliée par un tapis
  au charbon. Règle pure : shared/team/fonderie_bloc.lua ; ce fichier la branche au jeu.

  Chaîne (diagnostic au journal de la partie du DC, 14 h 30) : le plan du champ garde le coffre de tête d'une colonne quand il ne trouve pas de
  voie de charbon (shared/team/champ.lua, repli 0.6.42) ; ce coffre est un quai d'entrée garni à la main par les tournées « fill ». Il n'était
  JAMAIS relié : débit nul pour la liaison et le piquage (corrigé à la source : le quai porte `flow`), aucune source de charbon à portée, et
  aucune demande. Ici :

  1. RELEVÉ (FB.step) : une fois par Fb.PERIOD, les quais de combustible des projets de champ FINIS (ceux qui portent un `flow`), Fb.BUSY quais
     par passe de Build.
  2. DÉCISION (Fb.decide) : ni liaison ni piquage ne le servent et le piquage a conclu (sa cause est lue dans b.piquage.quais) : une ALIMENTATION DE
     QUAI est demandée (une à la fois par équipe), jamais le QG menacé ni un ennemi à portée du coffre.
  3. PROJET (FB.plan, appelé par plan_project) : un bras contre le coffre et son poteau (Fb.sites), puis la ligne de foreuses sur le gisement du
     combustible le plus proche et son tapis jusqu'à la tuile derrière le bras (Build.plan_drills, comme l'alimentation de la centrale, plan_alim) ;
     la fin du plan (courant, points d'appui, défrichage) est celle de tous les projets (plan_finish).
  4. SUIVI : un projet fini est « servi » ; refusé, il est écrit avec sa cause et le PNJ continue à la main (le coffre reste en tampon : il
     baisse sous Build.QUAI_LOW et la tournée reprend toute seule) ; rouvert (tapis détruit), il redevient « coupé ».

  Réglage maître : fo-war-industrie (Rsv.on), comme la liaison. Journal FONDERIE-BLOC (format : Fb.line). État : b.fonderie_bloc (nombres,
  chaînes, tables ; jamais de fonction, jamais d'entité), créé à la première passe : les sauvegardes d'avant le lot le créent d'elles-mêmes.
  Interface de BANC (jamais appelée par le mod) : FB.report(f).
]]

local Fb = require("shared.team.fonderie_bloc")
local M = require("shared.team.modules")
local P = require("shared.team.plan")
local T = require("shared.team.config")
local State = require("script.faction.state")
local Rsv = require("script.ai3.reserve")
local Registry = require("script.companion.registry")

local FB = {}

local DEAD = { refuse = true }
local POLE_SET = {}
for _, name in ipairs(M.POLES) do POLE_SET[name] = true end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function minutes(tick) return tick / 3600 end

local function say(f, dock, tick, verdict, why)
  log(Fb.line(f.key or "player", dock, verdict, why, minutes(tick)))
end

--- Une ligne par changement de verdict et par quai (pas de répétition à chaque relevé).
local function note(st, f, dock, tick, verdict, why)
  local text = verdict .. "|" .. why
  if st.said[dock.key] == text then return end
  st.said[dock.key] = text
  say(f, dock, tick, verdict, why)
end

local function new_state(tick)
  return { next = tick + Fb.PERIOD, seen = {}, tries = {}, last_try = {}, links = {}, said = {}, n = { demandes = 0, finis = 0, refuses = 0, coupees = 0 } }
end

local function chest_at(f, surface, x, y)
  return surface.find_entities_filtered({ position = { x, y }, radius = 0.4, force = f.force, type = "container", limit = 1 })[1]
end

local function hq_threat(f, surface)
  if not (f.hq and f.hq.valid and f.hq_pos) then return false end
  return surface.count_entities_filtered({ position = f.hq_pos, radius = T.hq_threat_radius, force = "enemy", type = "unit", limit = 1 }) > 0
end

local function enemy_near(f, surface, x, y)
  return surface.find_nearest_enemy({ position = { x = x, y = y }, max_distance = Fb.ENEMY_R, force = f.force }) ~= nil
end

--- PNJ libres de l'équipe : sans tâche, ou sur la file sûre (comme la liaison).
local function free_workers(f)
  local n = 0
  for _, id in ipairs(State.sorted_keys(f.engineers or {})) do
    local a = Registry.get(id)
    if a and a.entity and a.entity.valid and (not a.task or a.task.safe) then n = n + 1 end
  end
  return n
end

---------------------------------------------------------------------------------------------------
-- Relevé
---------------------------------------------------------------------------------------------------
--- Quais de combustible des projets de champ finis : { key, pid, idx, x, y, item, flow }.
local function collect(b)
  local docks = {}
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and p.state == "fini" and not p.abandoned and p.spec and p.spec.champ then
      for idx, q in ipairs(p.quais or {}) do
        if q.item and (q.flow or 0) >= Fb.MIN_FLOW then
          docks[#docks + 1] = { key = pid .. ":q" .. idx, pid = pid, idx = idx, x = math.floor(q.x), y = math.floor(q.y), item = q.item, flow = q.flow }
        end
      end
    end
  end
  return docks
end

--- Le quai est-il servi par une liaison, un piquage ou une alimentation (finie ou en cours) ?
local function served_by_other(b, key)
  local ln, pq = b.liaison, b.piquage
  return (ln ~= nil and ln.links ~= nil and ln.links[key] ~= nil) or (pq ~= nil and pq.links ~= nil and pq.links[key] ~= nil)
end

local function pq_cause(b, key)
  local pq = b.piquage
  local q = pq and pq.quais and pq.quais[key]
  return q and q.cause or nil
end

local function open_count(st)
  local n = 0
  for _, k in ipairs(sorted_keys(st.links)) do if not st.links[k].done then n = n + 1 end end
  return n
end

local function follow_links(f, b, st, tick)
  for _, key in ipairs(sorted_keys(st.links)) do
    local link = st.links[key]
    local q = b.projects[link.pid]
    local dock = { key = key, item = link.item, flow = link.flow }
    if not q then
      st.links[key] = nil
    elseif q.state == "fini" then
      if not link.done then
        link.done = true
        st.n.finis = st.n.finis + 1
        st.said[key] = nil
        say(f, dock, tick, "alimentation finie", string.format("projet %d, %d piece(s), %d fil(s) tire(s) : le coffre est garni par la ligne, le PNJ n'a plus a porter",
          q.id, #q.ents, q.wired or 0))
      end
    elseif DEAD[q.state] or q.abandoned then
      st.n.refuses = st.n.refuses + 1
      st.said[key] = nil
      say(f, dock, tick, "alimentation refusee", string.format("projet %d : %s ; le PNJ continue a la main", q.id, tostring(q.reason)))
      st.links[key] = nil
    elseif link.done then
      link.done = false
      st.n.coupees = st.n.coupees + 1
      say(f, dock, tick, "alimentation coupee", string.format("projet %d rouvert (etat %s) : le coffre baisse, le PNJ reprend le quai", q.id, q.state))
    end
  end
end

local function arm_and_pole(dp)
  return Fb.pick_names(dp.ents or {}, function(n) return M.spec(n) end, function(n) return POLE_SET[n] == true end)
end

local function examine(api, f, surface, b, st, tick, d, ctx)
  local dp = b.projects[d.pid]
  local q = dp and dp.quais and dp.quais[d.idx]
  if not (q and q.item) then return end
  if not chest_at(f, surface, d.x + 0.5, d.y + 0.5) then return end -- coffre détruit : la reconstruction le refait, rien à relier d'ici là
  local link = st.links[d.key]
  local served = served_by_other(b, d.key) or (link ~= nil and link.done)
  if served then st.seen[d.key] = nil else st.seen[d.key] = (st.seen[d.key] or 0) + 1 end
  local inp = { flow = d.flow, served = served, open = link ~= nil and not link.done, open_total = ctx.open, pq_cause = pq_cause(b, d.key) or false,
    seen = st.seen[d.key] or 0, tries = st.tries[d.key] or 0, since_try = st.last_try[d.key] and (tick - st.last_try[d.key]) or Fb.RETRY_AFTER,
    threat = ctx.threat, enemies = 0, free = ctx.free }
  local action, why = Fb.decide(inp)
  if action == "demander" then
    inp.enemies = enemy_near(f, surface, d.x, d.y) and 1 or 0
    action, why = Fb.decide(inp)
  end
  if action ~= "demander" then
    if not served then note(st, f, d, tick, action, why) end -- (une ligne par changement de raison : la cause d'une attente est écrite)
    return
  end
  local arm, pole = arm_and_pole(dp)
  if not (arm and pole) then
    note(st, f, d, tick, "laisser", "pas de bras electrique ni de poteau 1 x 1 dans le champ")
    return
  end
  local spec = { alimquai = { key = d.key, item = d.item, flow = d.flow, arm = arm, pole = pole, dock = { pid = d.pid, idx = d.idx, x = d.x, y = d.y } },
    prio = api.prio, domain = "infrastructures", pile = "capital", product = d.item, pole = dp.spec and dp.spec.pole }
  local id = api.request(f, spec)
  if not id then return end
  st.tries[d.key] = (st.tries[d.key] or 0) + 1
  if st.tries[d.key] > Fb.MAX_TRIES then st.tries[d.key] = Fb.MAX_TRIES end
  st.last_try[d.key] = tick
  st.links[d.key] = { pid = id, item = d.item, flow = d.flow, dock_pid = d.pid, dock_idx = d.idx, done = false, since = tick }
  st.n.demandes = st.n.demandes + 1
  ctx.open = ctx.open + 1
  ctx.free = math.max(0, ctx.free - 1)
  st.said[d.key] = nil
  say(f, d, tick, "alimentation demandee", string.format("projet %d : ligne de foreuses sur le gisement le plus proche et tapis jusqu'au coffre (%d, %d), %s (essai %d/%d)",
    id, d.x, d.y, why, st.tries[d.key], Fb.MAX_TRIES))
end

--- api = { request = Build.request, prio }.
function FB.step(api, f, surface, tick)
  local b = f.build
  if not b then return end
  local st = b.fonderie_bloc
  if not st then
    if not Rsv.on() then return end -- réglage maître éteint : aucun état (sauvegarde inchangée)
    st = new_state(tick)
    b.fonderie_bloc = st
  end
  if st.off then return end -- interrupteur D'ESSAI (banc)
  local c = st.cyc
  if not c then
    if tick < st.next then return end
    st.next = tick + (st.period or Fb.PERIOD)
    if not Rsv.on() then return end
    -- une ligne sans courant ne sert à rien : la centrale d'abord
    local pp = b.plant and b.projects[b.plant]
    if not (pp and pp.state == "fini") then return end
    local docks = collect(b)
    if #docks == 0 then return end
    st.cyc = { docks = docks, i = 1, ctx = nil }
    return
  end
  if not c.ctx then
    follow_links(f, b, st, tick)
    c.ctx = { open = open_count(st), threat = hq_threat(f, surface), free = free_workers(f) }
  end
  for _ = 1, Fb.BUSY do
    local d = c.docks[c.i]
    if not d then break end
    c.i = c.i + 1
    examine(api, f, surface, b, st, tick, d, c.ctx)
  end
  if c.i > #c.docks then st.cyc = nil end
end

---------------------------------------------------------------------------------------------------
-- Plan d'un projet d'alimentation de quai (appelé par plan_project de build.lua)
---------------------------------------------------------------------------------------------------
local function release(b, p, ents)
  for _, e in ipairs(ents) do
    for _, t in ipairs(P.tiles_of(e)) do
      local k = P.tkey(t[1], t[2])
      if b.occ[k] == p.id then b.occ[k] = nil end
    end
  end
end

--- api = { read_masks(x0, y0, x1, y1), reserve_tiles(b, p, list), finish = plan_finish, plan_drills = Build.plan_drills } : les aides de build.lua.
--- Rend true, ou false et la raison.
function FB.plan(api, f, surface, p)
  local b = f.build
  local ac = p.spec.alimquai
  local dock = ac.dock
  local dp = b.projects[dock.pid]
  if not (dp and dp.state == "fini") then return false, "alimentation de quai: projet du quai absent ou en chantier" end
  if not chest_at(f, surface, dock.x + 0.5, dock.y + 0.5) then return false, "alimentation de quai: coffre du quai disparu" end
  if not (ac.arm and ac.pole) then return false, "alimentation de quai: pieces inconnues" end
  local mg = 6
  local x0, y0, x1, y1 = dock.x - mg, dock.y - mg, dock.x + mg, dock.y + mg
  local masks = api.read_masks(x0, y0, x1 + 1, y1 + 1)
  -- la tuile devant un tapis planifié ou bâti (d'un projet de l'équipe) reste libre : son bout n'y déverse rien (comme la liaison)
  local guard = {}
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and q ~= p and not q.abandoned and not DEAD[q.state] then
      for _, e in ipairs(q.ents) do
        -- (seules les entités de la boîte du coffre comptent : le test de position avant celui du nom, 30 000 entités en 120 000 instructions)
        if e.x >= x0 - 1 and e.x <= x1 + 2 and e.y >= y0 - 1 and e.y <= y1 + 2 and e.name:find("belt", 1, true) then
          local v = P.DV[e.dir or 0]
          if v then guard[P.tkey(math.floor(e.x) + v[1], math.floor(e.y) + v[2])] = true end
        end
      end
    end
  end
  local function free(x, y)
    if x < x0 or x > x1 or y < y0 or y > y1 then return false end
    local k = P.tkey(x, y)
    return not (masks.water[k] or masks.blocked[k] or b.occ[k] or guard[k])
  end
  local cands = Fb.sites(dock.x, dock.y, free, nil)
  if #cands == 0 then return false, "alimentation de quai: aucune place pour un bras, un tapis et un poteau contre le coffre" end
  local last = "aucune arrivee"
  for _, c in ipairs(cands) do
    p.parts, p.ents = {}, {}
    local ents = Fb.entities({ site = c.site, pole = c.pole, names = { arm = ac.arm, pole = ac.pole } })
    local arr = Fb.arrival(c.site)
    local bad = Fb.verify(ents, arr, { x = dock.x, y = dock.y })
    if #bad > 0 then return false, "alimentation de quai: geometrie fausse (" .. bad[1] .. ")" end
    for _, e in ipairs(ents) do e.part = 2 end
    if api.reserve_tiles(b, p, ents) then
      local ok, why = api.plan_drills(f, surface, p, ac.item, ac.flow, arr, nil)
      if ok then
        p.parts[2] = { kind = "liaison", key = "alimquai", ox = c.site.ax, oy = c.site.ay, w = 1, h = 1, power = false }
        p.counted = true -- une alimentation de quai n'est pas un module : finish_project ne la compte pas aux modules finis
        local ax0, ay0, ax1, ay1 = math.huge, math.huge, -math.huge, -math.huge
        local route = 0
        for _, e in ipairs(p.ents) do
          ax0, ay0, ax1, ay1 = math.min(ax0, e.x), math.min(ay0, e.y), math.max(ax1, e.x), math.max(ay1, e.y)
          if e.role == "liaison-tapis" then route = route + 1 end
        end
        local m2 = api.read_masks(math.floor(ax0) - 32, math.floor(ay0) - 32, math.ceil(ax1) + 32, math.ceil(ay1) + 32)
        log(Fb.line(f.key or "player", { key = ac.key, item = ac.item, flow = ac.flow }, "alimentation planifiee",
          string.format("projet %d : %d foreuse(s) pour %.2f/s, tapis de %d tuile(s) jusqu'a la tuile (%d, %d) derriere le bras du coffre (%d, %d)",
            p.id, p.parts[1] and p.parts[1].drills or 0, ac.flow or 0, route, arr.x, arr.y, dock.x, dock.y), minutes(game.tick)))
        return api.finish(f, surface, p, m2, false)
      end
      last = tostring(why) -- (plan_drills ne réserve rien quand il échoue)
      release(b, p, ents)
    else
      last = "tuiles du bras ou du poteau prises"
    end
  end
  p.parts, p.ents = {}, {}
  return false, "alimentation de quai: foreuses : " .. last
end

---------------------------------------------------------------------------------------------------
-- Interface de BANC (jamais appelée par le mod)
---------------------------------------------------------------------------------------------------
--- Une ligne de bilan de l'équipe (nombres seuls).
function FB.report(f)
  local st = f.build and f.build.fonderie_bloc
  if not st then return nil end
  return { demandes = st.n.demandes, finis = st.n.finis, refuses = st.n.refuses, coupees = st.n.coupees, ouverts = open_count(st) }
end

return FB
