--[[
  Lot INDUSTRIE I7 (LIAISONS) : la LIAISON DE QUAI en jeu (règle pure : shared/team/liaison.lua ; plan : PLAN.md §4). Un quai d'entrée
  de module (coffre alimenté à la main par un PNJ, build.lua quai_tasks) est relié par un tapis au coffre de SORTIE d'un autre module
  qui porte le même objet : coffre -> bras -> tapis -> bras -> coffre. Tant que le tapis tient, le coffre d'entrée reste au-dessus de
  Build.QUAI_LOW et aucune tâche `carry` n'est émise ; le tapis coupé, le coffre baisse et le PNJ reprend tout seul : le repli est celui
  qui existait déjà. Ce fichier ne change donc ni quai_tasks ni les tâches de collecte.

  1. RELEVÉ (Liaison.step) : une fois par Ln.PERIOD, les projets FINIS de l'équipe (modules ; ni centrale, ni raccordement, ni site, ni
     liaison), Ln.UNITS_PER_PULSE projets par passe : quais d'entrée (coffre, objet, débit nominal p.inflow) et coffres de sortie
     (objet lu au contenu, gardé en mémoire quand le coffre est vide).
  2. DÉCISION (Ln.pairs, Ln.worth, Ln.decide) : un quai, le coffre de sortie le plus proche du même objet ; le prix du travail économisé
     contre le coût ; confirmé sur Ln.CONFIRM relevés ; ni ennemi à portée, ni QG menacé ; une liaison demandée par relevé, autant en
     construction que de PNJ libres (Ln.max_open).
  3. PROJET : Build.request({ liaison = ... }) ; le plan (Liaison.plan, appelé par plan_project) trace le tapis (P.belt_route sur les
     masques du moteur, évite les tuiles réservées par les projets de l'équipe et la tuile devant un tapis existant), pose un bras contre
     chaque coffre et un poteau contre chaque bras ; la machinerie ordinaire (réserve, défrichage, fantômes, PNJ, fils) fait le reste.
  4. FIN : la barre du coffre d'entrée est posée (Ln.bar : la charge d'un aller-retour), sinon le bras le remplirait en entier.
  5. SUIVI : un projet de liaison qui quitte « fini » (tapis détruit, reconstruction) est écrit « coupée » ; le PNJ a déjà repris.

  Réglage maître : fo-war-industrie (Rsv.on) ; éteint, aucun relevé ni aucune demande. Un projet de liaison est un investissement (famille « capital » de
  la pile) : sa réserve se suspend pendant qu'un cadre réparer, protéger ou survivre retient, comme un module neuf (Build.reserve_suspended).
  Journal [FO-LIAISON]. État : b.liaison (nombres, chaînes, tables ; jamais de fonction, jamais d'entité), créé à la première passe :
  les sauvegardes d'avant le lot le créent d'elles-mêmes. Rien n'est gardé hors de b.liaison.
  Interface de BANC (remote fo-liaison, jamais appelée par le mod) : inject (modules finis fictifs), set_param, report.
]]

local Ln = require("shared.team.liaison")
local Bus = require("script.team.bus") -- lot RESEAU-GRAPHE : bus de produits (liaison longue choisie par shared/team/reseau_graphe.lua)
local M = require("shared.team.modules")
local P = require("shared.team.plan")
local T = require("shared.team.config")
local State = require("script.faction.state")
local Conv = require("script.team.convoyeurs")
local Rsv = require("script.ai3.reserve") -- le réglage maître (fo-war-industrie)
local Registry = require("script.companion.registry")
local Trav = require("script.team.traversee") -- lot TRAVERSEE : tapis qui enjambent les obstacles par des souterrains, gisements évités
local Tv = require("shared.team.traversee")
local Pur = require("script.team.purete") -- lot PURETE-TAPIS : aucun tapis étranger ne verse sur un tracé, le tracé ne verse sur aucun tapis étranger

local Liaison = {}

local SKIP_KEYS = { "alim", "alimquai", "raccord", "enceinte", "liaison", "site", "quartier" } -- projets qui ne sont pas des modules de fabrication (lot TV-ARCHI : les dépôts d'un quartier ne reçoivent pas de liaison à tapis)
local DEAD = { refuse = true }
local BUS_CACHE = {} -- lot RESEAU-GRAPHE : masques et garde du tracé de tronc en cours, par projet (MÉMOIRE LOCALE du script, hors sauvegarde ; vide au chargement)
local POLE_SET = {}
for _, name in ipairs(M.POLES) do POLE_SET[name] = true end -- les poteaux des données de modules.lua, aucun nom écrit ici

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function say(f, tick, text)
  log(string.format("[FO-LIAISON] %s : %s a %.1f min", f.key or "player", text, tick / 3600))
end

local function note(st, f, tick, key, text)
  if st.said[key] == text then return end
  st.said[key] = text
  say(f, tick, text)
end

local function new_state(tick)
  return { next = tick + Ln.PERIOD, seen = {}, tries = {}, last_try = {}, links = {}, said = {}, src_item = {}, flow = {},
    log_next = 0, last_docks = -1, n = { demandes = 0, finis = 0, refuses = 0, coupees = 0 } }
end

--- Un projet fini qui peut porter un quai ou une sortie de liaison.
local function eligible(p)
  if not p or p.state ~= "fini" or p.abandoned or not p.spec then return false end
  for _, k in ipairs(SKIP_KEYS) do if p.spec[k] then return false end end
  local first = p.parts and p.parts[1]
  if first and first.kind == "centrale" then return false end -- la centrale se nourrit par ses propres règles (charbon_centrale)
  return true
end

local function chest_at(f, surface, x, y)
  return surface.find_entities_filtered({ position = { x, y }, radius = 0.4, force = f.force, type = "container", limit = 1 })[1]
end

--- Débits nominaux des entrées d'un module { objet = objets/s } : gardés au plan (p.inflow), sinon relus au gabarit (module d'avant le
--- lot, ou fictif de banc) ; faux si inconnus. Mémoire dans l'état de la passe (nombres seuls).
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
  return { units = units, i = 1, docks = {}, srcs = {} }
end

local function scan_unit(f, surface, b, st, c, pid)
  local p = b.projects[pid]
  if not eligible(p) then return end
  local flows = inflow_of(st, p)
  local seen = {} -- p.quais garde les quais des plans précédents d'un projet replanifié : un coffre ne compte qu'une fois (sinon, deux liaisons vers lui)
  for idx, q in ipairs(p.quais or {}) do
    local ch = q.item and chest_at(f, surface, q.x, q.y)
    local tk = math.floor(q.x) .. ":" .. math.floor(q.y) .. ":" .. tostring(q.item)
    if ch and not seen[tk] then
      seen[tk] = true
      c.docks[#c.docks + 1] = { key = pid .. ":q" .. idx, pid = pid, idx = idx, x = math.floor(q.x), y = math.floor(q.y), item = q.item,
        flow = q.flow or (flows and flows[q.item]) or 0, n = ch.get_item_count(q.item) }
    end
  end
  for idx, o in ipairs(p.outs or {}) do
    local ch = chest_at(f, surface, o.x, o.y)
    if ch then
      local key = pid .. ":o" .. idx
      local names = sorted_keys(ch.get_inventory(defines.inventory.chest).get_contents())
      local item
      if #names == 1 then item = names[1]; st.src_item[key] = item
      elseif #names == 0 then item = st.src_item[key] end -- sortie vide : l'objet vu la dernière fois
      c.srcs[#c.srcs + 1] = { key = key, pid = pid, idx = idx, x = math.floor(o.x), y = math.floor(o.y), item = item, n = item and ch.get_item_count(item) or 0 }
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Noms des pièces : lus aux projets des deux modules (aucun nom écrit ici)
---------------------------------------------------------------------------------------------------
local function ent_names(p)
  local out = {}
  for _, e in ipairs(p and p.ents or {}) do out[#out + 1] = e end
  return out
end

--- Bras du quai d'entrée du module d'arrivée (dimensionné pour son débit), sinon celui de la sortie du module de départ : le plus lent
--- des bras électriques de portée 1 (rôles quai-bras, sortie-bras) ; poteau 1 x 1 de plus long fil ; spec.names d'un module fictif de banc.
local function pick_names(dp, sp)
  local arm, pole
  for _, p in ipairs({ dp, sp }) do
    local nm = p.spec and p.spec.names
    local best_arm, best_rate, best_pole, best_wire
    for _, e in ipairs(ent_names(p)) do
      local s = M.spec(e.name)
      if s and (e.role == "quai-bras" or e.role == "sortie-bras") and not s.burner and s.reach == 1 then
        if not best_rate or s.rate < best_rate or (s.rate == best_rate and e.name < best_arm) then best_arm, best_rate = e.name, s.rate end
      elseif s and POLE_SET[e.name] and s.w == 1 and s.h == 1 then
        if not best_wire or s.wire > best_wire or (s.wire == best_wire and e.name < best_pole) then best_pole, best_wire = e.name, s.wire end
      end
    end
    arm = arm or (nm and nm.arm) or best_arm
    pole = pole or (nm and nm.pole) or best_pole
  end
  return arm, pole or M.DEFAULT_POLE
end

---------------------------------------------------------------------------------------------------
-- Suivi des liaisons ouvertes, décisions
---------------------------------------------------------------------------------------------------
local function dist_hq(f, x, y)
  local hq = f.hq_pos
  if not hq then return 0 end
  local dx, dy = x - hq.x, y - hq.y
  return math.sqrt(dx * dx + dy * dy)
end

local function enemy_near(f, surface, x, y)
  local foe = surface.find_nearest_enemy({ position = { x = x, y = y }, max_distance = Ln.ENEMY_R, force = f.force })
  return foe ~= nil
end

local function hq_threat(f, surface)
  if not (f.hq and f.hq.valid and f.hq_pos) then return false end
  return surface.count_entities_filtered({ position = f.hq_pos, radius = T.hq_threat_radius, force = "enemy", type = "unit", limit = 1 }) > 0
end

--- PNJ libres de l'équipe : sans tâche, ou sur la file sûre (rappelés dès qu'un travail les attend, script/team/poles.lua).
local function free_workers(f)
  local n = 0
  for _, id in ipairs(State.sorted_keys(f.engineers or {})) do
    local a = Registry.get(id)
    if a and a.entity and a.entity.valid and (not a.task or a.task.safe) then n = n + 1 end
  end
  return n
end

--- Barre du coffre d'entrée d'une liaison finie (idempotente : relue à chaque relevé, le coffre refait par une reconstruction la perd).
local function apply_bar(api, f, surface, b, link)
  local dp = b.projects[link.dock_pid]
  local q = dp and dp.quais and dp.quais[link.dock_idx]
  if not (q and q.item) then return end
  local ch = chest_at(f, surface, q.x, q.y)
  if not ch then return end
  local proto = game.item_prototypes[q.item]
  local inv = ch.get_inventory(defines.inventory.chest)
  local want = Ln.bar(api.fill, proto and proto.stack_size or 1)
  if inv.supports_bar() and inv.get_bar() ~= want then inv.set_bar(want) end
end

local function follow_links(api, f, surface, b, st, tick)
  for _, dkey in ipairs(sorted_keys(st.links)) do
    local link = st.links[dkey]
    local q = b.projects[link.pid]
    if not q then
      st.links[dkey] = nil
    elseif q.state == "fini" then
      if not link.done then
        link.done = true
        st.n.finis = st.n.finis + 1
        say(f, tick, string.format("quai %s : liaison finie (projet %d, %d piece(s), %d fil(s) tire(s)) : %s de %s, le PNJ n'a plus a porter", dkey, q.id, #q.ents,
          q.wired or 0, tostring(link.item), tostring(link.src)))
        if link.bus then Bus.say(f, tick, string.format("tronc pose : quai %s relie a %s (%s, projet %d, %d piece(s)) en %.1f min", dkey, tostring(link.src), tostring(link.item), q.id, #q.ents, (tick - (link.since or tick)) / 3600)) end
      end
      apply_bar(api, f, surface, b, link)
    elseif DEAD[q.state] or q.abandoned then
      st.n.refuses = st.n.refuses + 1
      say(f, tick, string.format("quai %s : liaison refusee (projet %d : %s), le PNJ continue a la main", dkey, q.id, tostring(q.reason)))
      if link.bus then Bus.say(f, tick, string.format("tronc refuse : quai %s <- %s (%s, projet %d), cause : %s ; le PNJ continue a la main", dkey, tostring(link.src), tostring(link.item), q.id, tostring(q.reason))) end
      st.links[dkey] = nil
    elseif link.done then
      link.done = false
      st.n.coupees = st.n.coupees + 1
      say(f, tick, string.format("quai %s : liaison coupee (projet %d rouvert, etat %s) : le coffre baisse, le PNJ reprend le quai (carry)", dkey, q.id, q.state))
    end
  end
end

-- aides passées au bus (lot RESEAU-GRAPHE) : les locales de ce fichier, sans les exporter
local BUS_H = {
  max_open = function(free) return Ln.max_open(free) end,
  free_workers = function(f) return free_workers(f) end,
  hq_threat = function(f, surface) return hq_threat(f, surface) end,
  enemy_near = function(f, surface, x, y) return enemy_near(f, surface, x, y) end,
  pick_names = function(dp, sp) return pick_names(dp, sp) end,
  belt = function(f, flow) return Conv.choose(f, flow) end,
}

local function finish_cycle(api, f, surface, b, st, c, tick)
  follow_links(api, f, surface, b, st, tick)
  -- appariement
  local taken = {}
  for _, dkey in ipairs(sorted_keys(st.links)) do taken[st.links[dkey].src] = true end
  for _, d in ipairs(c.docks) do d.linked = st.links[d.key] ~= nil or (b.piquage ~= nil and b.piquage.links[d.key] ~= nil) end -- un quai servi par un piquage (lot PIQUAGE) n'est plus apparié par la liaison
  for _, s in ipairs(c.srcs) do s.linked = taken[s.key] == true end
  local pairs_ = Ln.pairs(c.docks, c.srcs)
  -- synthèse : quais servis par tapis
  local served, active, open = 0, 0, 0
  for _, dkey in ipairs(sorted_keys(st.links)) do
    if st.links[dkey].done then active = active + 1 else open = open + 1 end
  end
  for _, d in ipairs(c.docks) do if st.links[d.key] and st.links[d.key].done then served = served + 1 end end
  if (#c.docks > 0 or active + open > 0) and (tick >= st.log_next or #c.docks ~= st.last_docks) then
    st.log_next = tick + Ln.LOG_EVERY
    say(f, tick, string.format("releve : %d quai(s) d'entree, %d coffre(s) de sortie, %d paire(s) possible(s) ; quais servis par tapis %d sur %d "
      .. "(liaisons actives %d, en construction %d) ; demandes %d, finies %d, refusees %d, coupees %d", #c.docks, #c.srcs, #pairs_, served, #c.docks,
      active, open, st.n.demandes, st.n.finis, st.n.refuses, st.n.coupees))
  end
  st.last_docks = #c.docks
  Bus.start(BUS_H, f, surface, tick, b, st, c) -- lot RESEAU-GRAPHE : un calcul de bus par tranches (Bus.advance, une unité par passe)
  if #pairs_ == 0 then return end
  -- décisions (au plus une liaison demandée par relevé)
  local threat = hq_threat(f, surface)
  local free = free_workers(f)
  local asked = false
  for _, pr in ipairs(pairs_) do
    if asked then break end -- une liaison demandée par relevé
    local d, s = pr.dock, pr.src
    local inp = { open = false, open_total = open, free = free, threat = threat, enemies = 0 }
    if not threat then inp.enemies = (enemy_near(f, surface, d.x, d.y) or enemy_near(f, surface, s.x, s.y)) and 1 or 0 end
    local action, reason = Ln.decide(inp)
    if action == "relier" then
      local dp, sp = b.projects[d.pid], b.projects[s.pid]
      local arm, pole = pick_names(dp, sp)
      local belt = Conv.choose(f, d.flow)
      if not (arm and belt) then
        note(st, f, tick, d.key, string.format("quai %s : pas de liaison (%s)", d.key, not arm and "aucun bras electrique connu des deux modules" or "aucun tapis debloque"))
      else
        asked = true
        local spec = { liaison = { key = d.key, item = d.item, flow = d.flow, arm = arm, pole = pole, belt = belt,
          dock = { pid = d.pid, idx = d.idx, x = d.x, y = d.y }, src = { pid = s.pid, idx = s.idx, x = s.x, y = s.y, key = s.key } },
          prio = api.prio, domain = "infrastructures", pile = "capital", product = d.item }
        local id = api.request(f, spec)
        if id then
          st.links[d.key] = { pid = id, src = s.key, item = d.item, dock_pid = d.pid, dock_idx = d.idx, done = false, since = tick }
          st.n.demandes = st.n.demandes + 1
          open = open + 1
          free = math.max(0, free - 1)
          st.said[d.key] = nil
          say(f, tick, string.format("quai %s (%s, %.2f/s, a %.0f tuiles du QG) : liaison demandee (projet %d) depuis la sortie %s a %d tuiles : %s",
            d.key, d.item, d.flow, dist_hq(f, d.x, d.y), id, s.key, pr.span, reason))
        end
      end
    else
      note(st, f, tick, d.key, string.format("quai %s (%s, %.2f/s) <- sortie %s a %d tuiles : %s : %s", d.key, tostring(d.item), d.flow or 0, s.key, pr.span,
        action, reason))
    end
  end
end

--- api = { request = Build.request, prio, fill = Build.QUAI_FILL, low = Build.QUAI_LOW } (build.lua n'est pas requis ici).
function Liaison.step(api, f, surface, tick)
  local b = f.build
  if not b then return end
  local st = b.liaison
  if not st then
    if not Rsv.on() then return end -- réglage maître éteint : aucun état (sauvegarde inchangée)
    st = new_state(tick)
    b.liaison = st
  end
  if st.off then return end -- interrupteur D'ESSAI (remote fo-liaison set_param off) : témoin des bancs
  Bus.advance(BUS_H, api, f, surface, tick) -- lot RESEAU-GRAPHE : une unité du calcul du bus (rien si le réglage est éteint ou absent)
  local c = st.cyc
  if not c then
    if tick < st.next then return end
    st.next = tick + (st.period or Ln.PERIOD)
    if not Rsv.on() then return end
    -- un tapis sans courant ne sert à rien : la centrale d'abord (réglage de banc : st.sans_centrale)
    local pp = b.plant and b.projects[b.plant]
    if not (st.sans_centrale or (pp and pp.state == "fini")) then return end
    st.cyc = start_cycle(b)
    return
  end
  for _ = 1, Ln.UNITS_PER_PULSE do
    local pid = c.units[c.i]
    if not pid then break end
    c.i = c.i + 1
    scan_unit(f, surface, b, st, c, pid)
  end
  if c.i > #c.units then
    st.cyc = nil
    finish_cycle(api, f, surface, b, st, c, tick)
  end
end

---------------------------------------------------------------------------------------------------
-- Plan d'un projet de liaison (appelé par plan_project de build.lua)
---------------------------------------------------------------------------------------------------
--- api = { read_masks(x0, y0, x1, y1), reserve_tiles(b, p, list), wood_of(surface, ents), free_spot(b, masks, x, y, wood),
---   add_obstacle(p, o), item_of(name), seg_passable(b), REACH } : les aides locales de build.lua. Rend true, ou false et la raison.
function Liaison.plan(api, f, surface, p)
  local b = f.build
  local lc = p.spec.liaison
  local dock, src = lc.dock, lc.src
  -- s40 p30 : un refus précoce vide l'état de reprise et les masques gardés du tracé de tronc (avant : gardés jusqu'à une fin de plan qui ne venait plus)
  local function early(why) p.rs, BUS_CACHE[p.id] = nil, nil; return false, why end
  if not chest_at(f, surface, dock.x + 0.5, dock.y + 0.5) then return early("liaison: coffre du quai disparu") end
  if not chest_at(f, surface, src.x + 0.5, src.y + 0.5) then return early("liaison: coffre de sortie disparu") end
  if not (lc.arm and lc.belt and lc.pole) then return early("liaison: pieces inconnues") end
  local mg = 6
  local x0, y0 = math.min(dock.x, src.x) - mg, math.min(dock.y, src.y) - mg
  local x1, y1 = math.max(dock.x, src.x) + mg, math.max(dock.y, src.y) + mg
  local box = lc.bus and Bus.MAX_BOX or 120 -- lot RESEAU-GRAPHE : un tracé de bus va plus loin qu'une liaison de quai
  if x1 - x0 > box or y1 - y0 > box then return early("liaison: trop loin") end
  -- lot RESEAU-GRAPHE : le tracé d'un tronc de bus se cherche PAR TRANCHES (Bus.SLICE etats par passe, p.rs = etat de reprise) ; les
  -- masques et la garde, lus une fois, restent en memoire LOCALE (hors sauvegarde) pendant la recherche : sans eux (chargement
  -- d'une sauvegarde), la recherche repart de zero
  local tick_now = game and game.tick or 0
  local rs = lc.bus and p.rs or nil
  local cache = lc.bus and BUS_CACHE[p.id] or nil
  if rs and not (cache and cache.box == x0 .. ":" .. y0 .. ":" .. x1 .. ":" .. y1 and tick_now - cache.tick < Bus.CACHE_TTL) then rs, p.rs, cache = nil, nil, nil end
  local masks = cache and cache.masks or api.read_masks(x0, y0, x1 + 1, y1 + 1)
  -- la tuile devant un tapis planifié ou bâti (d'un projet de l'équipe) reste libre : son bout n'y déverse rien
  local guard = cache and cache.guard or {}
  if not cache then
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
  end
  local planned = {}
  local function inside(x, y) return x >= x0 and x <= x1 and y >= y0 and y <= y1 end
  -- lot PURETE-TAPIS : la tuile où un tapis du MONDE (hors plan : usine du joueur, autre force, fantôme, répartiteur) d'un autre objet verse reste libre
  local worldf = Pur.fronts(f, surface, lc.item, p, { world_only = true })
  local function free(x, y)
    if not inside(x, y) then return false end
    local k = P.tkey(x, y)
    return not (masks.water[k] or masks.blocked[k] or b.occ[k] or guard[k] or planned[k]) and not worldf(x, y)
  end
  local S, D = { x = src.x, y = src.y }, { x = dock.x, y = dock.y }
  local ends = Ln.pick_ends(S, D, free, Ln.ROUTE_TRIES)
  if #ends == 0 then return early("liaison: aucune place pour un bras et un tapis contre les coffres") end
  local bounds = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  local last_why = "aucun chemin"
  local chosen
  local first_end = 1
  if rs then
    local e0 = ends[rs.ie]
    if e0 and Bus.end_sig(e0) == rs.sig then first_end = rs.ie else rs, p.rs = nil, nil end
  end
  for ie = first_end, #ends do
    local e = ends[ie]
    planned = { [P.tkey(e.src.ax, e.src.ay)] = true, [P.tkey(e.dst.ax, e.dst.ay)] = true }
    local function cost(x, y)
      if not free(x, y) then return nil end
      local k = P.tkey(x, y)
      local c = 1
      if P.in_street(b.lat, x, y) then c = P.STREET_COST end
      if masks.clear[k] then c = c + 1 end
      return c
    end
    -- lot TRAVERSEE : l'obstacle infranchissable court (poteau, tapis, bâtiment) est franchi par une paire de souterrains, le gisement évité
    local ropts = { belt = lc.belt, sd = e.src.dir, kind = "liaison" }
    if lc.bus then
      -- tronc de bus : heuristique pondérée, plafond d'états sur le TOTAL des tranches, pas de détour de gisement, pas de diagnostic de refus
      ropts.weight, ropts.max, ropts.slice, ropts.no_detour, ropts.no_diag = Bus.WEIGHT, Bus.MAX_STATES, Bus.SLICE, true, true
      if rs and rs.ie == ie then ropts.resume = rs.S end
    end
    local tiles, why, tnames = Trav.route(f, surface, p, { x = e.src.bx, y = e.src.by }, { x = e.dst.bx, y = e.dst.by }, Ln.end_dir(e.dst), bounds, cost, ropts)
    if not tiles and why == "pending" then
      p.rs = { ie = ie, sig = Bus.end_sig(e), S = tnames }
      BUS_CACHE[p.id] = cache or { box = x0 .. ":" .. y0 .. ":" .. x1 .. ":" .. y1, tick = tick_now, masks = masks, guard = guard }
      return false, "liaison: trace du tronc en cours (" .. tostring(p.rs.S.expanded) .. " etats)", "calcul"
    end
    if tiles then
      local m = Ln.manhattan(e.src.bx, e.src.by, e.dst.bx, e.dst.by)
      local ok, w2
      if lc.bus then ok, w2 = Bus.route_ok(#tiles, m) else ok, w2 = Ln.route_ok(#tiles, m) end
      if ok then -- lot PURETE-TAPIS : la preuve de pureté du tracé (causes a, b, c, d) contre une lecture fraîche du monde ; refus : le bout suivant
        ok, w2 = Pur.check_route(f, surface, p, lc.bus and "bus" or "liaison", tiles, lc.item, { [P.tkey(e.dst.ax, e.dst.ay)] = true }, nil)
      end
      if ok then
        -- lot RESEAU-GRAPHE : les poteaux se cherchent POUR CE BOUT ; sans place, on essaie le bout suivant (avant : refus au premier bout)
        local taken = {}
        planned = { [P.tkey(e.src.ax, e.src.ay)] = true, [P.tkey(e.dst.ax, e.dst.ay)] = true }
        for _, t in ipairs(tiles) do planned[P.tkey(t.x, t.y)] = true; taken[t.x .. ":" .. t.y] = true end
        taken[e.src.ax .. ":" .. e.src.ay], taken[e.dst.ax .. ":" .. e.dst.ay] = true, true
        local poles, lack = {}, nil
        for i, site in ipairs({ e.src, e.dst }) do
          -- lot TRAVERSEE : de préférence une tuile sans gisement
          local px, py = Tv.pole_tile(function(fr) return Ln.pole_tile(site, fr, taken) end, free, Trav.ore_lookup(surface))
          if not px then lack = i == 1 and "la sortie" or "le quai" break end
          taken[px .. ":" .. py] = true
          planned[P.tkey(px, py)] = true
          poles[#poles + 1] = { px, py }
        end
        if not lack then
          -- s40 p28 : la preuve géométrique se fait POUR CE BOUT ; un écart passe au bout suivant (avant : preuve après la boucle, refus de toute la liaison)
          local vents = Ln.entities({ src = e.src, dst = e.dst, route = Tv.virtual_belts(tiles), names = { arm = lc.arm, belt = lc.belt, pole = lc.pole }, poles = poles })
          local bad = Ln.verify(vents, S, D, function(x) return x.role == "liaison-tapis" end, function(x) return x.role == "liaison-bras" end)
          if #bad == 0 then
            bad = Tv.verify(tiles, { x = e.src.bx, y = e.src.by }, { x = e.dst.bx, y = e.dst.by }, Ln.end_dir(e.dst), tnames and tnames.maxd or 0, nil)
          end
          if #bad == 0 then chosen = { e = e, tiles = tiles, names = tnames, poles = poles } break end
          last_why = "geometrie fausse (" .. bad[1] .. ")"
        else
          last_why = "aucune place pour un poteau contre un bras (contre " .. lack .. ")"
        end
      else
        last_why = w2
      end
    else
      last_why = tostring(why)
      -- tronc de bus : au premier « aucun chemin » ou « trop long » on s'arrete (les autres bouts coutent autant)
      if lc.bus and (why == "aucun chemin" or why == "trop long") then break end
    end
    rs, p.rs = nil, nil
  end
  p.rs, BUS_CACHE[p.id] = nil, nil
  if not chosen then return false, "liaison: " .. last_why end
  local e, tiles = chosen.e, chosen.tiles
  planned = { [P.tkey(e.src.ax, e.src.ay)] = true, [P.tkey(e.dst.ax, e.dst.ay)] = true }
  for _, t in ipairs(tiles) do planned[P.tkey(t.x, t.y)] = true end
  local poles = chosen.poles
  for _, pl in ipairs(poles) do planned[P.tkey(pl[1], pl[2])] = true end
  local ents = Ln.entities({ src = e.src, dst = e.dst, route = tiles, names = { arm = lc.arm, belt = lc.belt, pole = lc.pole, ug = chosen.names and chosen.names.ug }, poles = poles })
  -- preuve géométrique sur le tracé VIRTUEL (une paire souterraine = des tapis droits entre l'entrée et la sortie), puis celle des paires
  local vents = Ln.entities({ src = e.src, dst = e.dst, route = Tv.virtual_belts(tiles), names = { arm = lc.arm, belt = lc.belt, pole = lc.pole }, poles = poles })
  local bad = Ln.verify(vents, S, D, function(x) return x.role == "liaison-tapis" end, function(x) return x.role == "liaison-bras" end)
  if #bad == 0 then
    bad = Tv.verify(tiles, { x = e.src.bx, y = e.src.by }, { x = e.dst.bx, y = e.dst.by }, Ln.end_dir(e.dst), chosen.names and chosen.names.maxd or 0, nil)
  end
  if #bad > 0 then return false, "liaison: geometrie fausse (" .. bad[1] .. ")" end
  for _, x in ipairs(ents) do x.part = 1 end
  if not api.reserve_tiles(b, p, ents) then return false, "place" end
  -- points d'appui et obstacles à défricher : comme le raccordement (plan_raccord)
  local passable = api.seg_passable(b)
  local wood = api.wood_of(surface, p.ents)
  for _, x in ipairs(p.ents) do
    local a = P.anchor_for(b.lat, x.x, x.y, passable)
    local ax, ay
    if a then ax, ay = a.x, a.y else ax, ay = math.floor(x.x / 8) * 8 + 4, math.floor(x.y / 8) * 8 + 4 end
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
  p.parts[1] = { kind = "liaison", key = "liaison", ox = S.x, oy = S.y, w = 1, h = 1, power = false }
  p.counted = true -- une liaison n'est pas un module : finish_project ne la compte pas aux modules finis
  log(string.format("[FO-LIAISON] %s : projet %d planifie (quai %s, %s) : %d tuile(s) de tapis %s, 2 bras %s, 2 poteau(x) %s, de la sortie (%d, %d) au quai (%d, %d), %d obstacle(s)",
    f.key or "player", p.id, tostring(lc.key), tostring(lc.item), #tiles, lc.belt, lc.arm, lc.pole, S.x, S.y, D.x, D.y, #p.obstacles))
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

remote.add_interface("fo-liaison", {
  --- Module FINI fictif : d = { quais = { {x, y, item} }, outs = { {x, y} }, inflow = { objet = objets/s }, names = { arm, pole } }.
  --- Les coffres sont posés par le banc ; rien n'est bâti ici. Rend le numéro du projet.
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
  --- Réglages de banc : period (ticks), confirm (relevés), sans_centrale (bool), off (bool : la règle est éteinte).
  set_param = function(key, name, value)
    local f = team_of_key(key)
    local b = f and f.build
    if not b then return nil end
    b.liaison = b.liaison or new_state(game.tick)
    local st = b.liaison
    if name == "period" then st.period = value; st.next = game.tick
    elseif name == "confirm" then st.confirm = value
    elseif name == "sans_centrale" then st.sans_centrale = value and true or false
    elseif name == "off" then st.off = value and true or false
    elseif name == "bus_period" or name == "bus_confirm" then return Bus.set_param(st, name, value)
    else return nil end
    return value
  end,
  report = function(key)
    local f = team_of_key(key)
    local st = f and f.build and f.build.liaison
    if not st then return nil end
    local links = {}
    for _, k in ipairs(sorted_keys(st.links)) do
      local l = st.links[k]
      local q = f.build.projects[l.pid]
      links[#links + 1] = { dock = k, pid = l.pid, src = l.src, done = l.done, state = q and q.state or "?", reason = q and q.reason or nil,
        built = q and #q.ents or 0 }
    end
    return { n = st.n, links = links, tries = st.tries }
  end,
})

return Liaison
