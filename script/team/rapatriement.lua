--[[
  Lot RAPATRIEMENT (8/11, demande du DC en jouant la 0.6.65) : les LIGNES DE RAPATRIEMENT en jeu (règle pure : shared/team/rapatriement.lua, qui
  dit tout du pourquoi ; critères : fo-logs/2026-11-08_RAPATRIEMENT/CRITERES.md). Un coffre de SORTIE lointain (champ, fonderie, site) est relié
  par un tapis long à un coffre TAMPON placé près des consommateurs : coffre -> bras -> tapis -> bras -> tampon. Le tampon est une sortie comme
  les autres (p.outs, seuil Rp.TAMPON_AT) : le PNJ ne le vide qu'au court trajet vers le QG, et seulement si le stock du QG est sous
  Rp.KEEP_STOCK (p.keep_stock, garde existante de out_wanted) ; la liaison de quai ordinaire (script/team/liaison.lua) peut le servir aux quais
  voisins. Le repli est celui qui existe : tapis coupé ou tampon plein (barre), la sortie remonte au seuil de collecte et le PNJ reprend.

  1. RELEVÉ (Rap.step) : une fois par Rp.PERIOD, les projets FINIS de l'équipe (modules et sites ; ni centrale, ni raccordement, ni liaison, ni
     quartier, ni ligne de rapatriement) : quais d'entrée (coffre, objet, débit nominal p.inflow) et coffres de sortie lointains (objet lu au
     contenu, historique du contenu pour le débit).
  2. DÉCISION (Rp.candidates, Rp.decide) : sorties à Rp.MIN_DIST tuiles du QG et plus, valeur par PNJ-secondes économisées ; confirmée sur Rp.CONFIRM
     relevés ; ni ennemi à portée, ni QG menacé ; une ligne demandée par relevé, autant en construction que de PNJ libres.
  3. PROJET : Build.request({ rapatriement = ... }) ; le plan (Rap.plan, appelé par plan_project) lit les masques du moteur par chunks de 32
     le long du tracé, choisit le point libre du tampon près du point voulu (à portée d'un poteau du réseau), trace le tapis (P.belt_route, A*
     pondéré, ou le crochet Rap.route de traversee quand il existe), pose un bras contre chaque coffre et un poteau contre chaque bras.
  4. FIN : la barre du tampon (Rp.bar) ; relevé du contenu pour le compte des objets arrivés ; ligne « finie » au journal.
  5. SUIVI : un projet qui quitte « fini » est écrit « coupée » ; refusé, la sortie est libérée (nouvel essai après Rp.RETRY_AFTER).

  Réglage : fo-war-rapatriement (settings/rapatriement.lua, posé par l'intégrateur) ET réglage maître fo-war-industrie (Rsv.on) ; réglage absent :
  éteint. État : b.rapatriement (nombres, chaînes, tables ; jamais de fonction, jamais d'entité). Journal [FO-RAPATRIEMENT]. Interface de BANC
  (remote fo-rapatriement, jamais appelée par le mod) : inject, set_param, report.
]]

local Rp = require("shared.team.rapatriement")
local Li = require("shared.team.liaison")
local M = require("shared.team.modules")
local P = require("shared.team.plan")
local T = require("shared.team.config")
local State = require("script.faction.state")
local Conv = require("script.team.convoyeurs")
local Rsv = require("script.ai3.reserve") -- le réglage maître (fo-war-industrie)
local Registry = require("script.companion.registry")

local Rap = {}

Rap.SETTING = "fo-war-rapatriement"
local CHEST = T.outposts.coal.sink -- le coffre de sortie des projets du plan directeur (shared/team/config.lua), comme script/team/collecte.lua
local SKIP_KEYS = { "alim", "raccord", "enceinte", "liaison", "quartier", "rapatriement" } -- des sites (champ, pétrole) PORTENT des sorties : ils sont lus
local DEAD = { refuse = true }
local CHUNK = 32
local CELL = P.ANCHOR_STEP or 8
local ASTAR_MAX = 60000 -- noeuds développés au plus par tracé (P.ASTAR_MAX : 6000)
local ASTAR_WEIGHT = 1.4 -- A* pondéré : au plus 1,4 fois le meilleur chemin, bien moins de noeuds sur 150 tuiles
local MARGIN = 16 -- tuiles lues autour de la boîte des deux coffres
local BOX_MAX = 420 -- tuiles : plus grande dimension de la boîte lue
Rap.route = nil -- crochet du lot traversee : function(s, t, t_dir, bounds, cost, ctx) -> tiles (comme P.belt_route) ; nil : P.belt_route

local function sorted_keys(t)
  local ks = {}
  for k in next, t do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

function Rap.on(b)
  if b and b.rapatriement and b.rapatriement.force_on then return Rsv.on() end
  local ok, s = pcall(function() return settings.global[Rap.SETTING] end)
  return ok and s ~= nil and s.value == true and Rsv.on()
end

local function say(f, tick, text) log(text) end

local function note(st, f, tick, key, text)
  if st.said[key] == text then return end
  st.said[key] = text
  say(f, tick, text)
end

local function new_state(tick)
  return { next = tick + Rp.PERIOD, seen = {}, tries = {}, last_try = {}, lines = {}, said = {}, src_item = {}, hist = {}, flow = {},
    tampons = {}, log_next = 0, last_far = -1, n = { demandes = 0, finis = 0, refuses = 0, coupees = 0 } }
end

--- Un projet fini qui peut porter un quai ou une sortie de ligne (les sites de champ et de pétrole : oui).
local function eligible(p)
  if not p or p.state ~= "fini" or p.abandoned or not p.spec then return false end
  for _, k in ipairs(SKIP_KEYS) do if p.spec[k] then return false end end
  local first = p.parts and p.parts[1]
  if first and first.kind == "centrale" then return false end
  return true
end

local function chest_at(f, surface, x, y)
  return surface.find_entities_filtered({ position = { x, y }, radius = 0.4, force = f.force, type = "container", limit = 1 })[1]
end

local function inflow_of(st, p)
  if p.inflow then return p.inflow end
  local c = st.flow[p.id]
  if c == nil then
    c = false
    local spec = p.spec
    local fn = spec and spec.gen and M.GEN[spec.gen]
    if fn then
      local ok, g = pcall(M.with_pole, spec.pole, fn, table.unpack(spec.args or {}))
      if ok and g and g.inputs then
        c = {}
        for _, k in ipairs(sorted_keys(g.inputs)) do c[k] = g.inputs[k] end
      end
    end
    st.flow[p.id] = c
  end
  return c or nil
end

---------------------------------------------------------------------------------------------------
-- Relevé
---------------------------------------------------------------------------------------------------
local function start_cycle(b)
  local units = {}
  for _, pid in ipairs(b.order) do
    if eligible(b.projects[pid]) then units[#units + 1] = pid end
  end
  return { units = units, i = 1, docks = {}, srcs = {}, far = 0 }
end

local function push_hist(st, key, tick, n)
  local h = st.hist[key]
  if not h then h = {}; st.hist[key] = h end
  h[#h + 1] = { tick, n }
  while #h > Rp.HIST do table.remove(h, 1) end
end

local function scan_unit(f, surface, b, st, c, pid, tick)
  local p = b.projects[pid]
  if not eligible(p) then return end
  local hq = f.hq_pos
  local flows = inflow_of(st, p)
  local seen = {}
  for idx, q in ipairs(p.quais or {}) do
    local ch = q.item and chest_at(f, surface, q.x, q.y)
    local tk = math.floor(q.x) .. ":" .. math.floor(q.y) .. ":" .. tostring(q.item)
    if ch and not seen[tk] then
      seen[tk] = true
      local key = pid .. ":q" .. idx
      local lk = b.liaison and b.liaison.links and b.liaison.links[key] -- la liaison ordinaire sert déjà ce quai
      c.docks[#c.docks + 1] = { key = key, pid = pid, idx = idx, x = math.floor(q.x), y = math.floor(q.y), item = q.item,
        flow = flows and flows[q.item] or 0, served = (lk ~= nil and lk.done == true) }
    end
  end
  if not hq then return end
  for idx, o in ipairs(p.outs or {}) do
    if Rp.manhattan(o.x, o.y, hq.x, hq.y) >= Rp.MIN_DIST then -- les sorties proches ne sont pas notre affaire (liaison ordinaire, main)
      local ch = chest_at(f, surface, o.x, o.y)
      if ch then
        local key = pid .. ":o" .. idx
        local inv = ch.get_inventory(defines.inventory.chest)
        local names = sorted_keys(inv.get_contents())
        local item
        if #names == 1 then item = names[1]; st.src_item[key] = item
        elseif #names == 0 then item = st.src_item[key] end
        local n = item and ch.get_item_count(item) or 0
        push_hist(st, key, tick, n)
        c.far = c.far + 1
        c.srcs[#c.srcs + 1] = { key = key, pid = pid, idx = idx, x = math.floor(o.x), y = math.floor(o.y), item = item, n = n, at = o.at or 200 }
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Pièces : lues aux projets (aucun nom écrit ici)
---------------------------------------------------------------------------------------------------
--- Bras électrique de portée 1 le plus RAPIDE connu de l'équipe (un module ou un site qu'elle a déjà posé), poteau 1 x 1 de plus long fil.
local function pick_names(b, plist)
  local arm, rate, pole, wire
  local function scan(p)
    for _, e in ipairs(p and p.ents or {}) do
      local s = M.spec(e.name)
      if s and s.kind == "inserter" and not s.burner and s.reach == 1 then
        if not rate or s.rate > rate or (s.rate == rate and e.name < arm) then arm, rate = e.name, s.rate end
      elseif s and s.kind == "pole" and s.w == 1 and s.h == 1 then
        if not wire or s.wire > wire or (s.wire == wire and e.name < pole) then pole, wire = e.name, s.wire end
      end
    end
  end
  for _, p in ipairs(plist) do scan(p) end
  if not arm then -- aucun bras dans la source ni dans le quai : n'importe quel projet de l'équipe
    for _, pid in ipairs(b.order) do
      local p = b.projects[pid]
      if p and (p.state == "fini" or p.state == "chantier") then scan(p) end
      if arm then break end
    end
  end
  return arm, rate, pole or M.DEFAULT_POLE
end

--- Pièces d'une ligne partant du projet `pid` (mémoire de l'état : chaînes et nombres seuls, refaite si le projet change de numéro).
local function names_of(st, b, pid)
  st.names = st.names or {}
  local c = st.names[pid]
  if not c then
    local arm, rate, pole = pick_names(b, { b.projects[pid] })
    c = { arm = arm or false, rate = rate or false, pole = pole }
    st.names[pid] = c
  end
  return c.arm or nil, c.rate or nil, c.pole
end

local function dist_hq(f, x, y)
  local hq = f.hq_pos
  if not hq then return 0 end
  return math.abs(x - hq.x) + math.abs(y - hq.y)
end

local function enemy_near(f, surface, x, y)
  return surface.find_nearest_enemy({ position = { x = x, y = y }, max_distance = Rp.ENEMY_R, force = f.force }) ~= nil
end

local function hq_threat(f, surface)
  if not (f.hq and f.hq.valid and f.hq_pos) then return false end
  return surface.count_entities_filtered({ position = f.hq_pos, radius = T.hq_threat_radius, force = "enemy", type = "unit", limit = 1 }) > 0
end

local function free_workers(f)
  local n = 0
  for _, id in ipairs(State.sorted_keys(f.engineers or {})) do
    local a = Registry.get(id)
    if a and a.entity and a.entity.valid and (not a.task or a.task.safe) then n = n + 1 end
  end
  return n
end

---------------------------------------------------------------------------------------------------
-- Suivi des lignes
---------------------------------------------------------------------------------------------------
--- Objets arrivés au tampon depuis le dernier relevé : hausse du coffre plus ce que les PNJ en ont pris (o.collected, build.lua), nombres seuls.
local function track_arrivals(f, surface, b, st, line, q)
  local o = q.outs and q.outs[1]
  if not o then return end
  local ch = chest_at(f, surface, o.x, o.y)
  if not ch then return end
  local n = ch.get_item_count(line.item)
  local took = o.collected or 0
  if line.last_n then
    local d = (n - line.last_n) + (took - (line.last_took or 0))
    if d > 0 then
      line.arrived = (line.arrived or 0) + d
      b.stats.rapatrie = (b.stats.rapatrie or 0) + d
    end
  end
  line.last_n, line.last_took = n, took
end

--- Barre du tampon d'une ligne finie : somme des débits des lignes qui y mènent (idempotente : relue à chaque relevé).
local function apply_bar(f, surface, b, st, line, q)
  local o = q.outs and q.outs[1]
  if not o then return end
  local ch = chest_at(f, surface, o.x, o.y)
  if not ch then return end
  local flows = {}
  for _, k in ipairs(sorted_keys(st.lines)) do
    local l = st.lines[k]
    if l.item == line.item and l.tampon.x == line.tampon.x and l.tampon.y == line.tampon.y then flows[#flows + 1] = l.flow end
  end
  local proto = game.item_prototypes[line.item]
  local inv = ch.get_inventory(defines.inventory.chest)
  local want = Rp.bar_total(flows, proto and proto.stack_size or 1)
  if inv.supports_bar() and inv.get_bar() ~= want then inv.set_bar(want) end
end

local function follow_lines(f, surface, b, st, tick)
  for _, key in ipairs(sorted_keys(st.lines)) do
    local line = st.lines[key]
    local q = b.projects[line.pid]
    if not q then
      st.lines[key] = nil
    elseif q.state == "fini" then
      if not line.done then
        line.done = true
        st.n.finis = st.n.finis + 1
        say(f, tick, Rp.text("finie", { team = f.key, tick = tick, pid = q.id, pieces = #q.ents, wires = q.wired or 0, item = line.item, key = key,
          x = line.tampon.x, y = line.tampon.y }))
      end
      if line.owner then
        apply_bar(f, surface, b, st, line, q)
        track_arrivals(f, surface, b, st, line, q)
      end
    elseif DEAD[q.state] or q.abandoned then
      st.n.refuses = st.n.refuses + 1
      say(f, tick, Rp.text("refusee", { team = f.key, tick = tick, pid = q.id, key = key, cause = tostring(q.reason) }))
      st.lines[key] = nil
    elseif line.done then
      line.done = false
      st.n.coupees = st.n.coupees + 1
      say(f, tick, Rp.text("coupee", { team = f.key, tick = tick, pid = q.id, state = q.state, key = key }))
    end
  end
end

local function rebuild_tampons(b, st)
  local out = {}
  for _, key in ipairs(sorted_keys(st.lines)) do
    local l = st.lines[key]
    local q = b.projects[l.pid]
    if q and q.state == "fini" and l.owner == true then
      local t
      for _, e in ipairs(out) do if e.x == l.tampon.x and e.y == l.tampon.y and e.item == l.item then t = e end end
      if not t then t = { x = l.tampon.x, y = l.tampon.y, item = l.item, lines = 0 }; out[#out + 1] = t end
    end
  end
  for _, key in ipairs(sorted_keys(st.lines)) do
    local l = st.lines[key]
    for _, t in ipairs(out) do if t.x == l.tampon.x and t.y == l.tampon.y and t.item == l.item then t.lines = t.lines + 1 end end
  end
  st.tampons = out
end

local function finish_cycle(api, f, surface, b, st, c, tick)
  follow_lines(f, surface, b, st, tick)
  rebuild_tampons(b, st)
  for _, s in ipairs(c.srcs) do
    s.linked = st.lines[s.key] ~= nil
    local _, ar = names_of(st, b, s.pid)
    s.rate, s.nature = Rp.rate_of(st.hist[s.key], s.at, ar) -- borné par le bras de la ligne (le plus rapide connu de l'équipe)
  end
  local hub = f.hq_pos
  local cands = hub and Rp.candidates(c.srcs, c.docks, { x = hub.x, y = hub.y }, { tampons = st.tampons }) or {}
  local present = {}
  for _, cd in ipairs(cands) do
    present[cd.src.key] = true
    st.seen[cd.src.key] = (st.seen[cd.src.key] or 0) + 1
  end
  for _, k in ipairs(sorted_keys(st.seen)) do if not present[k] then st.seen[k] = nil end end
  local done, open, worth = 0, 0, 0
  for _, k in ipairs(sorted_keys(st.lines)) do
    if st.lines[k].done then done = done + 1 else open = open + 1 end
  end
  for _, cd in ipairs(cands) do if cd.ok then worth = worth + 1 end end
  if (c.far > 0 or done + open > 0) and (tick >= st.log_next or c.far ~= st.last_far) then
    st.log_next = tick + Rp.LOG_EVERY
    say(f, tick, Rp.text("releve", { team = f.key, tick = tick, far = c.far, worth = worth, done = done, open = open, demandes = st.n.demandes,
      finis = st.n.finis, refuses = st.n.refuses, coupees = st.n.coupees }))
    for _, k in ipairs(sorted_keys(st.lines)) do -- ce que les lignes finies ont fait depuis leur fin
      local l = st.lines[k]
      if l.done and l.owner then
        local p0 = b.projects[tonumber((k:match("^(%d+):")))]
        local o0 = p0 and p0.outs and p0.outs[tonumber((k:match(":o(%d+)$")))]
        say(f, tick, string.format("[FO-RAPATRIEMENT] %s : ligne %s (%s, tampon (%d, %d)) : %d objet(s) arrive(s) au tampon par tapis depuis sa fin, %d trajet(s) de collecte de la sortie depuis la demande (avant : %d) a %.1f min",
          f.key or "player", k, tostring(l.item), l.tampon.x, l.tampon.y, math.floor(l.arrived or 0), (o0 and o0.trips or 0) - (l.trips0 or 0), l.trips0 or 0, tick / 3600))
      end
    end
  end
  st.last_far = c.far
  if #cands == 0 then return end
  local threat = hq_threat(f, surface)
  local free = free_workers(f)
  local nlines = 0
  for _ in next, st.lines do nlines = nlines + 1 end
  local asked, reads = false, 0
  for _, cd in ipairs(cands) do
    if asked then break end
    local s = cd.src
    local last = st.last_try[s.key]
    local seen = st.seen[s.key] or 0
    if st.confirm then seen = seen >= st.confirm and Rp.CONFIRM or 0 end
    local inp = { worth = cd.ok, worth_why = cd.why, open_total = open, free = free, seen = seen, tries = st.tries[s.key] or 0,
      since_try = last and (tick - last) or Rp.RETRY_AFTER, threat = threat, lines = nlines, enemies = 0 }
    if cd.ok and seen >= Rp.CONFIRM and not threat and nlines < Rp.MAX_LINES and reads < 4 then
      reads = reads + 1
      inp.enemies = (enemy_near(f, surface, s.x, s.y) or enemy_near(f, surface, cd.point.x, cd.point.y)) and 1 or 0
    end
    local action, reason = Rp.decide(inp)
    if action == "relier" then
      local sp = b.projects[s.pid]
      local arm, arm_rate, pole = names_of(st, b, s.pid)
      local flow = math.min(cd.flow, arm_rate or cd.flow)
      local belt = Conv.choose(f, flow)
      if not (arm and belt) then
        note(st, f, tick, s.key, Rp.text("laissee", { team = f.key, tick = tick, key = s.key, item = s.item, flow = cd.flow, d_src = cd.d_src, x = cd.point.x, y = cd.point.y,
          action = "pas de ligne", cause = not arm and "aucun bras electrique connu de l'equipe" or "aucun tapis debloque" }))
      else
        asked = true
        if (st.tries[s.key] or 0) >= Rp.MAX_TRIES then st.tries[s.key] = Rp.MAX_TRIES - 1 end
        st.tries[s.key] = (st.tries[s.key] or 0) + 1
        st.last_try[s.key] = tick
        local spec = { rapatriement = { key = s.key, item = s.item, flow = flow, arm = arm, pole = pole, belt = belt, chest = CHEST,
          src = { pid = s.pid, idx = s.idx, x = s.x, y = s.y }, point = { x = cd.point.x, y = cd.point.y },
          reuse = cd.reuse and { x = cd.reuse.x, y = cd.reuse.y } or nil, nature = s.nature, d_src = cd.d_src, d_tam = cd.d_tam, phi = cd.det.phi },
          prio = api.prio, domain = "infrastructures", pile = "capital", product = s.item }
        local id = api.request(f, spec)
        if id then
          local o0 = sp and sp.outs and sp.outs[s.idx]
          st.lines[s.key] = { pid = id, item = s.item, flow = flow, tampon = { x = cd.point.x, y = cd.point.y }, owner = cd.reuse == nil, done = false, since = tick,
            trips0 = o0 and o0.trips or 0 }
          st.n.demandes = st.n.demandes + 1
          st.said[s.key] = nil
          say(f, tick, Rp.text("demandee", { team = f.key, tick = tick, pid = id, key = s.key, item = s.item, flow = flow, nature = s.nature, d_src = cd.d_src, x = cd.point.x,
            y = cd.point.y, d_tam = cd.d_tam, reuse = cd.reuse ~= nil, tiles = cd.det.tiles, why = cd.why, phi = cd.det.phi }))
        end
      end
    else
      note(st, f, tick, s.key, Rp.text("laissee", { team = f.key, tick = tick, key = s.key, item = s.item, flow = cd.flow, d_src = cd.d_src, x = cd.point.x, y = cd.point.y,
        action = action, cause = reason }))
    end
  end
end

--- api = { request = Build.request, prio } (build.lua n'est pas requis ici).
function Rap.step(api, f, surface, tick)
  local b = f.build
  if not b then return end
  local st = b.rapatriement
  if not st then
    if not Rap.on(nil) then return end -- réglage éteint ou absent : aucun état (sauvegarde inchangée)
    st = new_state(tick)
    b.rapatriement = st
  end
  if st.off then return end
  local c = st.cyc
  if not c then
    if tick < st.next then return end
    st.next = tick + (st.period or Rp.PERIOD)
    if not Rap.on(b) then return end
    local pp = b.plant and b.projects[b.plant]
    if not (st.sans_centrale or (pp and pp.state == "fini")) then return end -- un tapis sans courant ne sert à rien : la centrale d'abord
    st.cyc = start_cycle(b)
    return
  end
  for _ = 1, Rp.UNITS_PER_PULSE do
    local pid = c.units[c.i]
    if not pid then break end
    c.i = c.i + 1
    scan_unit(f, surface, b, st, c, pid, tick)
  end
  if c.i > #c.units then
    st.cyc = nil
    finish_cycle(api, f, surface, b, st, c, tick)
  end
end

---------------------------------------------------------------------------------------------------
-- Plan d'un projet de ligne (appelé par plan_project de build.lua)
---------------------------------------------------------------------------------------------------
--- Masques par chunks de 32, lus à la demande (un chunk non généré est un obstacle) ; `merged` rend les tables { water, blocked, clear } réunies
--- des chunks lus (pour free_spot et les obstacles).
local function chunk_masks(api, surface)
  local chunks = {}
  local function chunk(cx, cy)
    local ck = cx .. ":" .. cy
    local c = chunks[ck]
    if c == nil then
      if surface.is_chunk_generated({ x = cx, y = cy }) then
        local m = api.read_masks(cx * CHUNK, cy * CHUNK, cx * CHUNK + CHUNK, cy * CHUNK + CHUNK)
        c = { water = m.water, blocked = m.blocked, clear = m.clear }
      else
        c = false
      end
      chunks[ck] = c
    end
    return c
  end
  local function merged()
    local w, bl, cl = {}, {}, {}
    local ks = {}
    for k in next, chunks do ks[#ks + 1] = k end
    table.sort(ks)
    for _, ck in ipairs(ks) do
      local c = chunks[ck]
      if c then
        for k in next, c.water do w[k] = true end
        for k in next, c.blocked do bl[k] = true end
        for k in next, c.clear do cl[k] = true end
      end
    end
    return { water = w, blocked = bl, clear = cl }
  end
  return chunk, merged
end

--- Poteaux du réseau de l'équipe autour d'un point : le coffre est « à portée du courant » si l'un est à `reach` tuiles au plus.
local function pole_probe(f, surface, x, y, r)
  local list = {}
  for _, e in ipairs(surface.find_entities_filtered({ position = { x, y }, radius = r, type = "electric-pole", force = f.force })) do
    list[#list + 1] = { e.position.x, e.position.y }
  end
  return function(tx, ty, reach)
    for _, q in ipairs(list) do
      if (q[1] - tx - 0.5) ^ 2 + (q[2] - ty - 0.5) ^ 2 <= reach * reach then return true end
    end
    return false
  end
end

--- api = { read_masks(x0, y0, x1, y1), reserve_tiles(b, p, list), wood_of(surface, ents), free_spot(b, masks, x, y, wood), add_obstacle(p, o),
---   item_of(name), seg_passable(b), REACH } : les aides locales de build.lua. Rend true, ou false et la raison.
function Rap.plan(api, f, surface, p)
  local b = f.build
  local lc = p.spec.rapatriement
  local src = lc.src
  if not chest_at(f, surface, src.x + 0.5, src.y + 0.5) then return false, "rapatriement: coffre de sortie disparu" end
  if not (lc.arm and lc.belt and lc.pole and lc.chest) then return false, "rapatriement: pieces inconnues" end
  local reuse = lc.reuse
  if reuse and not chest_at(f, surface, reuse.x + 0.5, reuse.y + 0.5) then reuse = nil end -- tampon disparu : on en pose un neuf
  local px, py = lc.point.x, lc.point.y
  if reuse then px, py = reuse.x, reuse.y end
  local mg = MARGIN
  local x0, y0 = math.min(src.x, px) - mg - Rp.SPOT_RADIUS, math.min(src.y, py) - mg - Rp.SPOT_RADIUS
  local x1, y1 = math.max(src.x, px) + mg + Rp.SPOT_RADIUS, math.max(src.y, py) + mg + Rp.SPOT_RADIUS
  if x1 - x0 > BOX_MAX or y1 - y0 > BOX_MAX then return false, "rapatriement: trop loin" end
  local chunk, merged = chunk_masks(api, surface)
  local function ground(x, y)
    if x < x0 or x > x1 or y < y0 or y > y1 then return nil end
    local c = chunk(math.floor(x / CHUNK), math.floor(y / CHUNK))
    if not c then return nil end
    local k = P.tkey(x, y)
    if c.water[k] or c.blocked[k] or b.occ[k] then return nil end
    return c, k
  end
  -- la tuile devant un tapis planifié ou bâti (d'un projet de l'équipe) reste libre : son bout n'y déverse rien
  local guard = {}
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and q ~= p and not q.abandoned and not DEAD[q.state] then
      for _, e in ipairs(q.ents) do
        if e.name:find("belt", 1, true) then
          local v = P.DV[e.dir or 0]
          if v then guard[P.tkey(math.floor(e.x) + v[1], math.floor(e.y) + v[2])] = true end
        end
      end
    end
  end
  local planned = {}
  local function free(x, y)
    local c, k = ground(x, y)
    return c ~= nil and not (guard[k] or planned[k])
  end
  local S, D
  local spots
  local wire = (M.spec(lc.pole) or {}).wire or 7.5
  local near = wire - 2
  local at_src = pole_probe(f, surface, src.x, src.y, near + 4)
  if not at_src(src.x, src.y, near) then return false, "rapatriement: aucun poteau du reseau pres de la sortie" end
  if reuse then
    D = { x = reuse.x, y = reuse.y }
    spots = { { x = D.x, y = D.y, sites = Li.sites(D.x, D.y, free) } }
  else
    local at_tam = pole_probe(f, surface, px, py, Rp.SPOT_RADIUS + near + 4)
    local geom = { pitch = P.PITCH, lot = P.LOT, half = P.HALF }
    -- le coffre tampon au BORD d'une rue (Rp.street_edge) : ni au milieu d'un lot (le module veut son rectangle entier), ni au milieu de la rue
    -- (marche des PNJ) ; repli : n'importe quelle tuile libre hors rue
    local function free_chest(x, y, edge)
      local c, k = ground(x, y)
      if not c or guard[k] or planned[k] or c.clear[k] then return false end
      if edge then
        if not Rp.street_edge(b.lat, geom, x, y) then return false end
      elseif P.in_street(b.lat, x, y) then
        return false
      end
      return at_tam(x, y, near)
    end
    spots = Rp.pick_spots(px, py, function(x, y) return free_chest(x, y, true) end, Rp.SPOT_TRIES)
    if #spots == 0 then spots = Rp.pick_spots(px, py, function(x, y) return free_chest(x, y, false) end, Rp.SPOT_TRIES) end
    if #spots == 0 then return false, "rapatriement: aucune place pour le tampon a portee d'un poteau" end
  end
  S = { x = src.x, y = src.y }
  local bounds = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  local last_why = "aucun chemin"
  local chosen
  local runs = 0
  local router = Rap.route or function(s, t, t_dir, bnds, cost) return P.belt_route(s, t, t_dir, bnds, cost, { weight = ASTAR_WEIGHT, max = ASTAR_MAX }) end
  for _, sp in ipairs(spots) do
    D = { x = sp.x, y = sp.y }
    local ends = Li.pick_ends(S, D, free, Rp.ROUTE_TRIES)
    for _, e in ipairs(ends) do
      if runs >= Rp.ROUTE_TRIES then break end
      runs = runs + 1
      planned = { [P.tkey(e.src.ax, e.src.ay)] = true, [P.tkey(e.dst.ax, e.dst.ay)] = true, [P.tkey(D.x, D.y)] = true }
      local function cost(x, y)
        if not free(x, y) then return nil end
        local c, k = ground(x, y)
        local v = 1
        if P.in_street(b.lat, x, y) then v = P.STREET_COST end
        if c.clear[k] then v = v + 1 end
        return v
      end
      local tiles, why = router({ x = e.src.bx, y = e.src.by }, { x = e.dst.bx, y = e.dst.by }, Li.end_dir(e.dst), bounds, cost)
      if tiles then
        local ok, w2 = Rp.route_ok(#tiles, Li.manhattan(e.src.bx, e.src.by, e.dst.bx, e.dst.by))
        if ok then chosen = { e = e, tiles = tiles, D = D } break end
        last_why = w2
      else
        last_why = tostring(why)
      end
    end
    if chosen or runs >= Rp.ROUTE_TRIES then break end
  end
  if not chosen then return false, "rapatriement: " .. last_why end
  local e, tiles = chosen.e, chosen.tiles
  D = chosen.D
  planned = { [P.tkey(e.src.ax, e.src.ay)] = true, [P.tkey(e.dst.ax, e.dst.ay)] = true, [P.tkey(D.x, D.y)] = true }
  local taken = {}
  for _, t in ipairs(tiles) do planned[P.tkey(t.x, t.y)] = true; taken[t.x .. ":" .. t.y] = true end
  taken[e.src.ax .. ":" .. e.src.ay], taken[e.dst.ax .. ":" .. e.dst.ay], taken[D.x .. ":" .. D.y] = true, true, true
  local poles = {}
  for _, site in ipairs({ e.src, e.dst }) do
    local ptx, pty = Li.pole_tile(site, free, taken)
    if not ptx then return false, "rapatriement: aucune place pour un poteau contre un bras" end
    taken[ptx .. ":" .. pty] = true
    planned[P.tkey(ptx, pty)] = true
    poles[#poles + 1] = { ptx, pty }
  end
  local ents = Rp.entities({ src = e.src, dst = e.dst, route = tiles, names = { arm = lc.arm, belt = lc.belt, pole = lc.pole, chest = lc.chest }, poles = poles,
    reuse = reuse ~= nil })
  local bad = Rp.verify(ents, S, D, function(x) return x.role == "liaison-tapis" end, function(x) return x.role == "liaison-bras" end,
    function(x) return x.role == "tampon" end, reuse ~= nil)
  if #bad > 0 then return false, "rapatriement: geometrie fausse (" .. bad[1] .. ")" end
  for _, x in ipairs(ents) do x.part = 1 end
  if not api.reserve_tiles(b, p, ents) then return false, "place" end
  -- points d'appui et obstacles à défricher : comme la liaison de quai
  local masks = merged()
  local passable = api.seg_passable(b)
  local wood = api.wood_of(surface, p.ents)
  for _, x in ipairs(p.ents) do
    local a = P.anchor_for(b.lat, x.x, x.y, passable)
    local ax, ay
    if a then ax, ay = a.x, a.y else ax, ay = math.floor(x.x / CELL) * CELL + 4, math.floor(x.y / CELL) * CELL + 4 end
    local fx, fy = api.free_spot(b, masks, ax, ay, wood)
    if (fx - x.x) * (fx - x.x) + (fy - x.y) * (fy - x.y) > api.REACH * api.REACH then fx, fy = api.free_spot(b, masks, x.x, x.y, wood) end
    x.ax, x.ay = fx, fy
    x.anchor = string.format("%s%g:%g", a and "" or "c", fx, fy)
    x.item = api.item_of(x.name)
  end
  P.sort_build(p.ents)
  p.obstacles, p.obst_keys = {}, {}
  for _, x in ipairs(p.ents) do
    for _, t in ipairs(P.tiles_of(x)) do
      local k = P.tkey(t[1], t[2])
      if masks.clear[k] or wood[k] then api.add_obstacle(p, { x = t[1] + 0.5, y = t[2] + 0.5, anchor = x.anchor, ax = x.ax, ay = x.ay }) end
    end
  end
  p.parts[1] = { kind = "liaison", key = "rapatriement", ox = S.x, oy = S.y, w = 1, h = 1, power = false }
  p.counted = true -- une ligne n'est pas un module : finish_project ne la compte pas aux modules finis
  if not reuse then
    -- le tampon est une sortie comme les autres : collecté à Rp.TAMPON_AT, et seulement si le QG est sous Rp.KEEP_STOCK (out_wanted)
    p.outs[#p.outs + 1] = { x = D.x + 0.5, y = D.y + 0.5, at = Rp.TAMPON_AT }
    p.keep_stock = { [lc.item] = Rp.KEEP_STOCK }
  end
  p.rap = { item = lc.item, flow = lc.flow, tampon_x = D.x, tampon_y = D.y }
  log(string.format("[FO-RAPATRIEMENT] %s : projet %d planifie (sortie %s, %s) : %d tuile(s) de tapis %s, 2 bras %s, 2 poteau(x) %s, du coffre (%d, %d) au tampon (%d, %d)%s, %d obstacle(s)",
    f.key or "player", p.id, tostring(lc.key), tostring(lc.item), #tiles, lc.belt, lc.arm, lc.pole, S.x, S.y, D.x, D.y, reuse and " (tampon reutilise)" or "", #p.obstacles))
  return true
end

---------------------------------------------------------------------------------------------------
-- Interface de BANC (jamais appelée par le mod)
---------------------------------------------------------------------------------------------------
local function team_of_key(key)
  if key == "player" then return State.faction("player") end
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and (f.key == key or id == key) then return f end
  end
  return nil
end

remote.add_interface("fo-rapatriement", {
  --- Module FINI fictif : d = { quais = { {x, y, item} }, outs = { {x, y} }, inflow = { objet = objets/s }, names = { arm, pole } }. Les coffres sont posés par le
  --- banc ; rien n'est bâti ici. Rend le numéro du projet.
  inject = function(key, d)
    local f = team_of_key(key)
    local b = f and f.build
    if not (b and type(d) == "table") then return nil end
    local id = b.next_id
    b.next_id = id + 1
    local x, y = 0, 0
    for _, q in ipairs(d.quais or {}) do x, y = q.x, q.y end
    for _, o in ipairs(d.outs or {}) do x, y = o.x, o.y end
    local p = {
      id = id, spec = { gen = "banc", names = d.names }, state = "fini", created = game.tick, finished = game.tick, parts = {}, ents = {}, wires = {},
      stock = {}, quais = {}, outs = {}, obstacles = {}, fails = 0, prio = 55, domain = "production", counted = true, inflow = d.inflow,
    }
    p.parts[1] = { kind = "module", key = "banc", ox = math.floor(x), oy = math.floor(y), w = 1, h = 1, power = true }
    for _, q in ipairs(d.quais or {}) do p.quais[#p.quais + 1] = { x = q.x, y = q.y, item = q.item } end
    for _, o in ipairs(d.outs or {}) do p.outs[#p.outs + 1] = { x = o.x, y = o.y } end
    b.projects[id] = p
    b.order[#b.order + 1] = id
    return id
  end,
  --- Réglages de banc : period (ticks), confirm (relevés), sans_centrale (bool), off (bool), force_on (bool : comme le réglage de carte allumé).
  set_param = function(key, name, value)
    local f = team_of_key(key)
    local b = f and f.build
    if not b then return nil end
    b.rapatriement = b.rapatriement or new_state(game.tick)
    local st = b.rapatriement
    if name == "period" then st.period = value; st.next = game.tick
    elseif name == "confirm" then st.confirm = value
    elseif name == "sans_centrale" then st.sans_centrale = value and true or false
    elseif name == "off" then st.off = value and true or false
    elseif name == "force_on" then st.force_on = value and true or false
    else return nil end
    return value
  end,
  report = function(key)
    local f = team_of_key(key)
    local st = f and f.build and f.build.rapatriement
    if not st then return nil end
    local lines = {}
    for _, k in ipairs(sorted_keys(st.lines)) do
      local l = st.lines[k]
      local q = f.build.projects[l.pid]
      lines[#lines + 1] = { src = k, pid = l.pid, done = l.done, state = q and q.state or "?", reason = q and q.reason or nil, built = q and #q.ents or 0,
        arrived = l.arrived or 0, tampon = l.tampon }
    end
    return { n = st.n, lines = lines, tries = st.tries, rapatrie = f.build.stats.rapatrie or 0 }
  end,
})

return Rap
