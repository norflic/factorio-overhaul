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
local Rv = require("shared.team.ravitaillement") -- lot MALL
local M = require("shared.team.modules")
local P = require("shared.team.plan")
local T = require("shared.team.config")
local State = require("script.faction.state")
local Conv = require("script.team.convoyeurs")
local Rsv = require("script.ai3.reserve") -- le réglage maître (fo-war-industrie)
local Registry = require("script.companion.registry")

local Liaison = {}

local SKIP_KEYS = { "alim", "raccord", "enceinte", "liaison", "site" } -- projets qui ne sont pas des modules de fabrication
local DEAD = { refuse = true }
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

--- Lot MALL : le projet est-il un mall (rangée « patron » ou bloc partagé) ? `spec.mall` : modules fictifs de banc.
local function is_mall(p)
  local s = p.spec
  return s.gen == "patron" or s.gen == "bloc" or s.mall == true
end

--- Un projet fini qui peut porter un quai ou une sortie de liaison.
local function eligible(p)
  if not p or p.state ~= "fini" or p.abandoned or not p.spec then return false end
  for _, k in ipairs(SKIP_KEYS) do if p.spec[k] then return false end end
  local first = p.parts and p.parts[1]
  if first and first.kind == "centrale" then return false end -- la centrale se nourrit par ses propres règles (charbon_centrale)
  return true
end

--- Lot MALL : un projet dont le chantier n'est pas fini (quelques pièces manquent, raccordement en cours) fabrique déjà : son coffre de sortie peut
--- servir de départ à une ligne si on le VOIT plein d'un seul objet. Jamais un quai d'arrivée : le module doit être fini (eligible).
local PRODUCING = { chantier = true, raccordement = true }
local function eligible_source(p)
  if not p or p.abandoned or not p.spec or not PRODUCING[p.state] then return false end
  for _, k in ipairs(SKIP_KEYS) do if p.spec[k] then return false end end
  local first = p.parts and p.parts[1]
  return not (first and first.kind == "centrale")
end

local function chest_at(f, surface, x, y)
  return surface.find_entities_filtered({ position = { x, y }, radius = 0.4, force = f.force, type = "container", limit = 1 })[1]
end

--- Lot MALL : l'objet qu'une sortie de mall fabriquera, lu à la recette de la machine la plus proche du coffre (sortie VIDE jamais vue seule : sans
--- cela, la sortie d'un mall neuf ou aussitôt vidée par la collecte n'a pas d'objet et aucun quai n'est relié à elle, cause « sans-sortie » du témoin
--- main 0.6.35). Une recette à un seul produit de type objet seulement ; la machine la plus proche, la plus au nord-ouest en cas d'égalité.
local function made_by_neighbour(f, surface, x, y)
  local best, bd
  for _, m in ipairs(surface.find_entities_filtered({ position = { x, y }, radius = 4.5, force = f.force, type = "assembling-machine" })) do
    local dx, dy = m.position.x - x, m.position.y - y
    local d = dx * dx + dy * dy
    if not bd or d < bd - 1e-6 or (math.abs(d - bd) <= 1e-6 and (m.position.y < best.position.y or (m.position.y == best.position.y and m.position.x < best.position.x))) then
      best, bd = m, d
    end
  end
  local rec = best and best.get_recipe()
  if rec and #rec.products == 1 and rec.products[1].type == "item" then return rec.products[1].name end
  return nil
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
    if eligible(b.projects[pid]) or eligible_source(b.projects[pid]) then units[#units + 1] = pid end
  end
  return { units = units, i = 1, docks = {}, srcs = {}, made = {} }
end

local function scan_unit(f, surface, b, st, c, pid)
  local p = b.projects[pid]
  local fini = eligible(p)
  if not fini and not eligible_source(p) then return end
  local flows = fini and inflow_of(st, p) or nil
  local seen = {} -- p.quais garde les quais des plans précédents d'un projet replanifié : un coffre ne compte qu'une fois (sinon, deux liaisons vers lui)
  for idx, q in ipairs(fini and p.quais or {}) do
    local ch = q.item and chest_at(f, surface, q.x, q.y)
    local tk = math.floor(q.x) .. ":" .. math.floor(q.y) .. ":" .. tostring(q.item)
    if ch and not seen[tk] then
      seen[tk] = true
      c.docks[#c.docks + 1] = { key = pid .. ":q" .. idx, pid = pid, idx = idx, x = math.floor(q.x), y = math.floor(q.y), item = q.item,
        flow = flows and flows[q.item] or 0, n = ch.get_item_count(q.item), mall = is_mall(p) }
    end
  end
  for idx, o in ipairs(p.outs or {}) do
    local ch = chest_at(f, surface, o.x, o.y)
    if ch then
      local key = pid .. ":o" .. idx
      local names = sorted_keys(ch.get_inventory(defines.inventory.chest).get_contents())
      local item
      if #names == 1 then item = names[1]; st.src_item[key] = item
      elseif #names == 0 and fini then
        item = st.src_item[key] -- sortie vide : l'objet vu la dernière fois
        if not item then -- lot MALL : sinon, celui de la machine voisine (malls, rangées d'engrenages, de câbles, de tuyaux… : un assembleur)
          item = made_by_neighbour(f, surface, o.x, o.y)
          if item then st.src_item[key] = item end
        end
      end
      if item and is_mall(p) then c.made[item] = true end -- lot MALL : objets fabriqués par les malls (diagnostic)
      c.srcs[#c.srcs + 1] = { key = key, pid = pid, idx = idx, x = math.floor(o.x), y = math.floor(o.y), item = item, mixed = #names >= 2 or nil }
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

--- Lot MALL : le quai du module d'arrivée a-t-il une ligne FINIE ? p.line_ok[indice du quai] (booléens, lu par le portage de script/team/build.lua :
--- une ligne finie baisse le seuil du portage à la main, Rv.rescue_low).
local function mark_line(b, link, on)
  local dp = b.projects[link.dock_pid]
  if not dp then return end
  if on then
    dp.line_ok = dp.line_ok or {}
    dp.line_ok[link.dock_idx] = true
  elseif dp.line_ok then
    dp.line_ok[link.dock_idx] = nil
  end
end

local function follow_links(api, f, surface, b, st, tick)
  for _, dkey in ipairs(sorted_keys(st.links)) do
    local link = st.links[dkey]
    local q = b.projects[link.pid]
    mark_line(b, link, q ~= nil and q.state == "fini")
    if not q then
      st.links[dkey] = nil
    elseif q.state == "fini" then
      if not link.done then
        link.done = true
        st.n.finis = st.n.finis + 1
        say(f, tick, string.format("quai %s : liaison finie (projet %d, %d piece(s), %d fil(s) tire(s)) : %s de %s, le PNJ n'a plus a porter", dkey, q.id, #q.ents,
          q.wired or 0, tostring(link.item), tostring(link.src)))
      end
      apply_bar(api, f, surface, b, link)
    elseif DEAD[q.state] or q.abandoned then
      st.n.refuses = st.n.refuses + 1
      say(f, tick, string.format("quai %s : liaison refusee (projet %d : %s), le PNJ continue a la main", dkey, q.id, tostring(q.reason)))
      st.links[dkey] = nil
    elseif link.done then
      link.done = false
      st.n.coupees = st.n.coupees + 1
      say(f, tick, string.format("quai %s : liaison coupee (projet %d rouvert, etat %s) : le coffre baisse, le PNJ reprend le quai (carry)", dkey, q.id, q.state))
    end
  end
end

local function finish_cycle(api, f, surface, b, st, c, tick)
  follow_links(api, f, surface, b, st, tick)
  -- appariement
  local taken = {}
  for _, dkey in ipairs(sorted_keys(st.links)) do taken[st.links[dkey].src] = (taken[st.links[dkey].src] or 0) + 1 end
  for _, d in ipairs(c.docks) do
    d.linked = st.links[d.key] ~= nil
    d.building = d.linked and not st.links[d.key].done or nil -- lot MALL (diagnostic) : liaison demandée, pas encore finie
  end
  for _, s in ipairs(c.srcs) do s.taken = taken[s.key] or 0; s.linked = s.taken > 0 end -- lot MALL : une sortie sert jusqu'à Rv.fan quais de mall
  local pairs_ = Ln.pairs(c.docks, c.srcs)
  local present = {}
  for _, pr in ipairs(pairs_) do
    local pk = pr.dock.key .. ">" .. pr.src.key
    present[pk] = true
    st.seen[pk] = (st.seen[pk] or 0) + 1
  end
  for _, k in ipairs(sorted_keys(st.seen)) do if not present[k] then st.seen[k] = nil end end
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
  -- lot MALL (diagnostic, lecture seule) : pourquoi les quais ne sont pas servis par tapis, et ce que le portage à la main a coûté
  if #c.docks > 0 and tick >= (st.diag_next or 0) then
    st.diag_next = tick + Ln.LOG_EVERY
    local nn, sp = Ln.diagnose(c.docks, c.srcs)
    local sb = b.stats or {}
    -- objets fabriqués par les malls depuis le dernier relevé (statistiques de production de la force : compteurs cumulés)
    local made, n_items = 0, 0
    local stats = game.forces[f.force] and game.forces[f.force].item_production_statistics
    if stats then
      for _, it in ipairs(sorted_keys(c.made)) do made = made + stats.get_input_count(it); n_items = n_items + 1 end
    end
    local per_min = (st.made_tick and tick > st.made_tick) and (made - (st.made_total or 0)) * 3600 / (tick - st.made_tick) or 0
    st.made_total, st.made_tick = made, tick
    local by, by_keys = sb.fill_by or {}, {}
    for _, k in ipairs(sorted_keys(by)) do by_keys[#by_keys + 1] = k end
    table.sort(by_keys, function(u, v) if by[u].n ~= by[v].n then return by[u].n > by[v].n end return u < v end)
    local top = {}
    for i = 1, math.min(#by_keys, 6) do top[#top + 1] = string.format("%s %d voy/%d", by_keys[i], by[by_keys[i]].t, by[by_keys[i]].n) end
    say(f, tick, string.format("[FO-MALL-ALIM] quais sans tapis : %s | portage a la main : %d voyage(s), %d objet(s) dont %d voyage(s) et %d objet(s) vers des malls | malls : %d objet(s) suivis, %.1f fabrique(s)/min depuis le dernier releve | portage des malls par objet [%s]",
      Ln.diagnose_text(nn, sp), sb.fill_trips or 0, sb.filled or 0, sb.fill_mall_trips or 0, sb.fill_mall or 0, n_items, per_min, table.concat(top, ", ")))
  end
  if #pairs_ == 0 then return end
  -- décisions (au plus une liaison demandée par relevé)
  local threat = hq_threat(f, surface)
  local free = free_workers(f)
  local asked = false
  local reads = 0 -- paires qui lisent le moteur : bornées ; les paires laissées (ne se paie pas, essais épuisés) ne cachent plus celles qui suivent
  for _, pr in ipairs(pairs_) do
    if asked and reads >= Ln.DECIDE_MAX then break end
    local d, s = pr.dock, pr.src
    local pk = d.key .. ">" .. s.key
    local ok, why, det = Ln.worth({ flow = d.flow, dist = dist_hq(f, d.x, d.y), span = pr.span, fill = api.fill, low = api.low, threat = threat,
      tmax = Rv.tmax(d, Ln.TMAX) })
    local last = st.last_try[d.key]
    local seen = st.seen[pk] or 0
    if st.confirm then seen = seen >= st.confirm and Ln.CONFIRM or 0 end -- (réglage de banc)
    local inp = { worth = ok, worth_why = why, open = false, open_total = open, free = free, seen = seen, tries = st.tries[d.key] or 0,
      since_try = last and (tick - last) or Ln.RETRY_AFTER, threat = threat }
    local deferred = false -- plus de lecture du moteur à ce relevé : la paire attend le suivant, sans raison au journal
    if ok and seen >= Ln.CONFIRM and not threat then
      if reads < Ln.DECIDE_MAX then
        reads = reads + 1
        inp.enemies = (enemy_near(f, surface, d.x, d.y) or enemy_near(f, surface, s.x, s.y)) and 1 or 0
      else
        deferred = true
        inp.enemies = 1
      end
    end
    local action, reason = Ln.decide(inp)
    if action == "relier" and asked then action, reason = "attendre", "une liaison par releve" end
    if action == "relier" then
      local dp, sp = b.projects[d.pid], b.projects[s.pid]
      local arm, pole = pick_names(dp, sp)
      local belt = Conv.choose(f, d.flow)
      if not (arm and belt) then
        note(st, f, tick, d.key, string.format("quai %s : pas de liaison (%s)", d.key, not arm and "aucun bras electrique connu des deux modules" or "aucun tapis debloque"))
      else
        asked = true
        if (st.tries[d.key] or 0) >= Ln.MAX_TRIES then st.tries[d.key] = Ln.MAX_TRIES - 1 end -- essai de plus après Ln.RETRY_AFTER
        st.tries[d.key] = (st.tries[d.key] or 0) + 1
        st.last_try[d.key] = tick
        local spec = { liaison = { key = d.key, item = d.item, flow = d.flow, arm = arm, pole = pole, belt = belt,
          dock = { pid = d.pid, idx = d.idx, x = d.x, y = d.y }, src = { pid = s.pid, idx = s.idx, x = s.x, y = s.y, key = s.key }, mall = d.mall },
          prio = api.prio, domain = "infrastructures", pile = "capital", product = d.item }
        local id = api.request(f, spec)
        if id then
          st.links[d.key] = { pid = id, src = s.key, item = d.item, dock_pid = d.pid, dock_idx = d.idx, done = false, since = tick }
          st.n.demandes = st.n.demandes + 1
          open = open + 1
          free = math.max(0, free - 1)
          st.said[d.key] = nil
          say(f, tick, string.format("quai %s (%s, %.2f/s, a %.0f tuiles du QG) : liaison demandee (projet %d) depuis la sortie %s a %d tuiles : %s (essai %d/%d)",
            d.key, d.item, d.flow, dist_hq(f, d.x, d.y), id, s.key, pr.span, why, st.tries[d.key], Ln.MAX_TRIES))
        end
      end
    elseif not deferred then
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
  if not chest_at(f, surface, dock.x + 0.5, dock.y + 0.5) then return false, "liaison: coffre du quai disparu" end
  if not chest_at(f, surface, src.x + 0.5, src.y + 0.5) then return false, "liaison: coffre de sortie disparu" end
  if not (lc.arm and lc.belt and lc.pole) then return false, "liaison: pieces inconnues" end
  local mg = 6
  local x0, y0 = math.min(dock.x, src.x) - mg, math.min(dock.y, src.y) - mg
  local x1, y1 = math.max(dock.x, src.x) + mg, math.max(dock.y, src.y) + mg
  if x1 - x0 > 120 or y1 - y0 > 120 then return false, "liaison: trop loin" end
  local masks = api.read_masks(x0, y0, x1 + 1, y1 + 1)
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
  local function inside(x, y) return x >= x0 and x <= x1 and y >= y0 and y <= y1 end
  local function free(x, y)
    if not inside(x, y) then return false end
    local k = P.tkey(x, y)
    return not (masks.water[k] or masks.blocked[k] or b.occ[k] or guard[k] or planned[k])
  end
  local S, D = { x = src.x, y = src.y }, { x = dock.x, y = dock.y }
  local ends = Ln.pick_ends(S, D, free, Ln.ROUTE_TRIES)
  if #ends == 0 then return false, "liaison: aucune place pour un bras et un tapis contre les coffres" end
  local bounds = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  local last_why = "aucun chemin"
  local chosen
  for _, e in ipairs(ends) do
    planned = { [P.tkey(e.src.ax, e.src.ay)] = true, [P.tkey(e.dst.ax, e.dst.ay)] = true }
    local function cost(x, y)
      if not free(x, y) then return nil end
      local k = P.tkey(x, y)
      local c = 1
      if P.in_street(b.lat, x, y) then c = P.STREET_COST end
      if masks.clear[k] then c = c + 1 end
      return c
    end
    local tiles, why = P.belt_route({ x = e.src.bx, y = e.src.by }, { x = e.dst.bx, y = e.dst.by }, Ln.end_dir(e.dst), bounds, cost)
    if tiles then
      local ok, w2 = Ln.route_ok(#tiles, Ln.manhattan(e.src.bx, e.src.by, e.dst.bx, e.dst.by), Rv.len_max({ mall = lc.mall }, Ln.MAX_LEN))
      if ok then chosen = { e = e, tiles = tiles } break end
      last_why = w2
    else
      last_why = tostring(why)
    end
  end
  if not chosen then return false, "liaison: " .. last_why end
  local e, tiles = chosen.e, chosen.tiles
  planned = { [P.tkey(e.src.ax, e.src.ay)] = true, [P.tkey(e.dst.ax, e.dst.ay)] = true }
  local taken = {}
  for _, t in ipairs(tiles) do planned[P.tkey(t.x, t.y)] = true; taken[t.x .. ":" .. t.y] = true end
  taken[e.src.ax .. ":" .. e.src.ay], taken[e.dst.ax .. ":" .. e.dst.ay] = true, true
  local poles = {}
  for _, site in ipairs({ e.src, e.dst }) do
    local px, py = Ln.pole_tile(site, free, taken)
    if not px then return false, "liaison: aucune place pour un poteau contre un bras" end
    taken[px .. ":" .. py] = true
    planned[P.tkey(px, py)] = true
    poles[#poles + 1] = { px, py }
  end
  local ents = Ln.entities({ src = e.src, dst = e.dst, route = tiles, names = { arm = lc.arm, belt = lc.belt, pole = lc.pole }, poles = poles })
  local bad = Ln.verify(ents, S, D, function(x) return x.role == "liaison-tapis" end, function(x) return x.role == "liaison-bras" end)
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
  --- Module FINI fictif : d = { quais = { {x, y, item} }, outs = { {x, y} }, inflow = { objet = objets/s }, names = { arm, pole }, mall = bool }.
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
      id = id, spec = { gen = "banc", names = d.names, mall = d.mall and true or nil }, state = "fini", created = game.tick, finished = game.tick, parts = {}, ents = {}, wires = {},
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
