--[[
  IA3-c « le cerveau par besoins » : PROJETS (docs/IA3_CERVEAU.md §3.5) et ÉMISSION des tâches par besoin (§3.2,
  dépliage). PUR (aucune API Factorio).

  Un PROJET = un but retenu (shared/ai3/buts.lua), qui SURVIT d'une pensée à l'autre dans `st.projects` (global) :
    { id, key, family, value, prio, state = "actif" | "bloque" | "attente", cause, opened, since, waiting_since,
      emitted, missing }.
  - K projets ACTIFS au plus : K = 2 + ⌊PNJ ÷ 4⌋, au plus 10 (4 PNJ : 3 ; 8 : 4 ; 30 : 9) ; un projet BLOQUÉ (site
    inconnu, ressource sans source, recherche impayable) reste ouvert avec sa cause mais ne prend PAS de place : il ne
    bloque personne (fin des 12 min de patience de l'échelle).
  - Inertie : + 20 % de valeur pour un projet déjà ouvert ; vieillissement : + 1 par minute d'attente de matière,
    au plus + 20 (règle 5 du registre, §2.2).
  - Priorité des tâches d'un projet = 40 + 0,45 × valeur (41 à 85 : sous les urgences 90 et plus du planificateur
    permanent) ; l'étape qui TERMINE le projet (pose, armement) + 3 ; les matières brutes qui manquent (feuilles du
    dépliage, donc sur le CHEMIN CRITIQUE de tous les projets qui les attendent) + 2 au-dessus du projet le plus
    prioritaire qui les attend.

  Dépliage par besoin d'un objet manquant (P.want) : prendre au stock virtuel ; sinon fabriquer à la main ce que le
  livre sait faire (en PARTIE si les matières ne suffisent pas : plusieurs PNJ avancent pendant que la matière arrive,
  constat du DC du 25/10, 18 h 40 : « pas de parallélisme ») ; le reste devient un MANQUE de matière brute, servi
  ensuite par P.supply : fonderie (fours fabriqués et posés s'il n'y en a pas), minage à la main du minerai par
  plusieurs PNJ, avant-postes (famille extraction) ; une matière SANS source connue émet « explorer » (H5, H8).

  Déterminisme : listes triées, clés stables, aucun pairs décisionnel, aucun hasard.
]]

local T = require("shared.team.config")
local Planner = require("shared.team.planner")

local P = {}

P.K_MIN, P.K_PER, P.K_MAX = 2, 4, 10
P.INERTIA_PCT = 20
P.AGING_TICKS = 3600
P.AGING_MAX = 20
P.MAX_CRAFTS = 12        -- fabrications émises par pensée (le planificateur permanent en a 8 de son côté)
P.CHUNK_SECONDS = 30     -- une fabrication ≈ 30 s de travail : plusieurs PNJ avancent une grosse commande
P.MINE_BATCH = 50
P.FINISH_BONUS = 3
P.SUPPLY_BONUS = 2
P.SMELTERS_BOOT = 2      -- fonderie d'amorçage (aucun four au QG : votre équipe au départ)
P.SMELTERS_BOOT_MORE = 4 -- … et 4 pour un manque d'au moins P.SMELT_MORE plaques (règle d'IA3-b, moteur réel du 25/10 :
P.SMELT_MORE = 50        -- 2 fours fondent 37 plaques par minute, le minerai attendait au coffre ; lot IA-V2)
P.APPOINT_PRIO = 30      -- fonderie et minage d'APPOINT d'une matière qu'un avant-poste produit déjà
P.BOOT_PRIO = 93         -- fonderie d'amorçage : chemin critique (aucune plaque sans four), avant les projets (lot IA-V2)
P.PLATE_PER_MINER = 20   -- plaque sans avant-poste : un mineur par 20 plaques qui manquent (règle d'IA3-b, lot IA-V2)
P.DEFER_PRIO = 40        -- matières des autres branches pendant qu'une plaque critique manque (lot IA-V2, §3.5)
P.TURRET_WAIT = 2 * 3600 -- avant-poste qui attend ses tourelles depuis 2 min : le projet les fabrique lui-même (lot IA-V2)
P.LOG_MAX = 24           -- annonces gardées (fenêtre, journal)
-- Données du mod (comme shared/team/config.lua ; le planificateur permanent les nomme de même) : la tourelle des règles
-- « défendre d'abord » d'IA1-b2, le soldat de repli (clé de T.kits), la plaque de la garde de l'économie (produit de
-- l'avant-poste de fer). Aucune autre chaîne du jeu dans la logique de ce module.
P.TURRET = "gun-turret"
P.FALLBACK_UNIT = "rifleman"
P.IRON = T.outposts.iron.product

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function sorted_uses(uses)
  local out = {}
  for _, k in ipairs(sorted_keys(uses)) do out[#out + 1] = { k, uses[k] } end
  return out
end

function P.K(workers)
  local k = P.K_MIN + math.floor((workers or 0) / P.K_PER)
  if k > P.K_MAX then k = P.K_MAX end
  return k
end

function P.prio_of(value) return 40 + math.floor((value or 0) * 45 / 100) end

local function announce(st, tick, kind, key, extra)
  st.log = st.log or {}
  st.log_seq = (st.log_seq or 0) + 1
  st.log[#st.log + 1] = { seq = st.log_seq, tick = tick, kind = kind, key = key, extra = extra }
  while #st.log > P.LOG_MAX do table.remove(st.log, 1) end
end
P.announce = announce

--- Effective (inertie, vieillissement) d'un but, projet ouvert ou non.
local function effective(goal, proj, tick)
  local e = goal.value
  if proj then
    e = e + math.floor(goal.value * P.INERTIA_PCT / 100)
    if proj.waiting_since then
      local age = math.floor((tick - proj.waiting_since) / P.AGING_TICKS)
      e = e + (age < P.AGING_MAX and age or P.AGING_MAX)
    end
  end
  return e
end

--- Met à jour les projets d'après les buts de la pensée. Renvoie la liste des projets à DÉPLIER (actifs dans l'ordre
--- de priorité effective, puis les bloqués à revoir), et le nombre de places K.
function P.update(st, goals, tick, workers)
  st.projects = st.projects or {}
  st.next_id = st.next_id or 1
  local by_key = {}
  for _, p in ipairs(st.projects) do by_key[p.key] = p end
  local wanted = {}
  for _, g in ipairs(goals) do wanted[g.key] = g end
  -- Projets finis (leur but n'existe plus) : fermés et annoncés.
  local kept = {}
  for _, p in ipairs(st.projects) do
    if wanted[p.key] then kept[#kept + 1] = p
    else announce(st, tick, "fini", p.key, math.floor((tick - (p.opened or tick)) / 60)) end
  end
  st.projects = kept
  by_key = {}
  for _, p in ipairs(kept) do by_key[p.key] = p end
  -- Classement des buts par valeur effective.
  local ranked = {}
  for _, g in ipairs(goals) do
    ranked[#ranked + 1] = { g = g, p = by_key[g.key], e = effective(g, by_key[g.key], tick) }
  end
  table.sort(ranked, function(a, b)
    if a.e ~= b.e then return a.e > b.e end
    return a.g.key < b.g.key
  end)
  local K = P.K(workers)
  local active, blocked, n_active = {}, {}, 0
  for _, r in ipairs(ranked) do
    local p, g = r.p, r.g
    if p and p.state == "bloque" then
      p.goal, p.value, p.eff = g, g.value, r.e
      blocked[#blocked + 1] = p
    elseif n_active < K or g.permanent then
      if not p then
        p = { id = st.next_id, key = g.key, family = g.family, opened = tick, state = "actif" }
        st.next_id = st.next_id + 1
        st.projects[#st.projects + 1] = p
        by_key[g.key] = p
        announce(st, tick, "ouvert", g.key, g.value)
      elseif p.state == "attente" then
        p.state = "actif"
      end
      p.goal, p.value, p.eff = g, g.value, r.e
      p.prio = P.prio_of(math.min(100, r.e))
      if not g.permanent then n_active = n_active + 1 end
      active[#active + 1] = p
    elseif p then
      p.goal, p.value, p.eff = g, g.value, r.e
      p.state = "attente"
    end
  end
  table.sort(st.projects, function(a, b) return a.id < b.id end)
  for _, p in ipairs(blocked) do p.prio = P.prio_of(math.min(100, p.eff or p.value)) end
  -- Ordre de service du stock virtuel : le PREMIER projet ordinaire (l'objectif du moment), puis les familles
  -- PERMANENTES (armée, réserve), puis les autres projets, puis les bloqués. C'est l'équilibre de l'ancien cerveau
  -- (objectif 50 > armée 45 > recherche 40) gardé pour les ressources, avec K projets qui avancent sur le reste.
  -- Moteur simulé de pvp_test, essais 2 à 5 de ce lot : servie APRÈS tous les projets, l'armée n'avait plus de fer
  -- (0 soldat à 15 min, 441 fers manquants) et Difficile n'attaquait pas plus que Normal.
  local out, perm, rest = {}, {}, {}
  local first = nil
  for _, p in ipairs(active) do
    if p.goal.permanent then perm[#perm + 1] = p
    elseif not first then first = p
    else rest[#rest + 1] = p end
  end
  if first then out[#out + 1] = first end
  for _, p in ipairs(perm) do out[#out + 1] = p end
  for _, p in ipairs(rest) do out[#out + 1] = p end
  for _, p in ipairs(blocked) do out[#out + 1] = p end
  return out, K
end

---------------------------------------------------------------------------------------------------
-- Émission : stock virtuel, fabrications, manques de matière
---------------------------------------------------------------------------------------------------
--- E = { avail, book, view, tasks, keys, open, raw, crafts, explore, smelt, smelt_prio, site_needs } (P.context).
function P.context(avail, book, view, st)
  return { avail = avail, book = book, view = view, st = st or {}, tasks = {}, keys = {}, open = view.open or {},
    raw = {}, crafts = 0, explore = {}, smelt = {}, smelt_prio = 0, site_needs = {} }
end

function P.add(E, t)
  if E.keys[t.key] or E.open[t.key] then return false end
  E.keys[t.key] = true
  E.tasks[#E.tasks + 1] = t
  return true
end

--- Prise tout ou rien au stock virtuel.
function P.take(E, list)
  for _, it in ipairs(list) do
    if (E.avail[it[1]] or 0) < it[2] then return false end
  end
  for _, it in ipairs(list) do E.avail[it[1]] = E.avail[it[1]] - it[2] end
  return true
end

local function short_raw(E, proj, item, n, prio)
  if n <= 0 then return end
  local r = E.raw[item]
  if not r then
    r = { n = 0, prio = 0, pid = nil, why = nil }
    E.raw[item] = r
  end
  r.n = r.n + n
  if prio > r.prio then r.prio, r.pid, r.why = prio, proj and proj.id, proj and proj.key end
  if proj then
    proj.missing = proj.missing or {}
    proj.missing[item] = (proj.missing[item] or 0) + n
  end
end
P.short_raw = short_raw

--- Plus grand nombre (≤ n) d'objets fabricables à la main sans matière manquante (dichotomie, 7 plans au plus).
local function craftable_count(book, item, n, avail)
  if n <= 0 then return 0 end
  if next(book:plan({ { item, n } }, avail).raw) == nil then return n end -- cas courant : tout se fabrique (1 plan)
  local lo, hi = 0, n - 1
  local steps = 0
  while lo < hi and steps < 8 do
    steps = steps + 1
    local mid = math.floor((lo + hi + 1) / 2)
    local p = book:plan({ { item, mid } }, avail)
    if next(p.raw) == nil then lo = mid else hi = mid - 1 end
  end
  return lo
end

--- Fabrique `n` × item à la main pour le projet (lots de ≈ CHUNK_SECONDS), depuis le stock virtuel.
local function craft(E, proj, item, n, prio, tag)
  local p0 = E.book:plan({ { item, n } }, E.avail)
  local energy = 0
  for _, c in ipairs(p0.crafts) do energy = energy + c.energy end
  local room = P.MAX_CRAFTS - E.crafts
  if room <= 0 then return 0 end
  local chunks = math.max(1, math.min(n, math.ceil(energy / P.CHUNK_SECONDS), room))
  local per = math.ceil(n / chunks)
  local left, i, made = n, 0, 0
  while left > 0 and E.crafts < P.MAX_CRAFTS do
    i = i + 1
    local k = math.min(per, left)
    local q = E.book:plan({ { item, k } }, E.avail)
    E.avail = q.avail
    E.crafts = E.crafts + 1
    left = left - k
    made = made + k
    P.add(E, { key = "ia3:" .. proj.id .. ":craft:" .. item .. ":" .. tag .. ":" .. i, kind = "craft", prio = prio,
      item = item, count = k, steps = q.crafts, uses = sorted_uses(q.uses), tag = "ia3", ia3 = proj.id,
      why = proj.key })
  end
  if left > 0 then E.avail = E.book:plan({ { item, left } }, E.avail).avail end
  return made
end

--- Besoin d'objets `list` ({ {objet, n} }) pour le projet. fresh = besoin d'ACCUMULATION (stock visé, packs) : la
--- quantité est à fabriquer en plus du stock. Renvoie vrai si tout est servi (au stock ou en fabrication).
function P.want(E, proj, list, prio, fresh, tag)
  local ok = true
  for _, it in ipairs(list) do
    local item, n = it[1], it[2]
    local have = fresh and 0 or (E.avail[item] or 0)
    if have >= n then
      E.avail[item] = have - n
    else
      local short = n - have
      if not fresh then E.avail[item] = 0 end
      if E.book:handcraftable(item) then
        local saved = E.avail[item]
        if fresh then E.avail[item] = 0 end
        local k = craftable_count(E.book, item, short, E.avail)
        local made = k > 0 and craft(E, proj, item, k, prio, tag or "b") or 0
        if made < short then
          ok = false
          local rest = E.book:plan({ { item, short - made } }, E.avail)
          for _, r in ipairs(sorted_keys(rest.raw)) do short_raw(E, proj, r, math.ceil(rest.raw[r]), prio) end
          if next(rest.raw) == nil then short_raw(E, proj, item, short - made, prio) end -- plafond de fabrications
        end
        if fresh then E.avail[item] = saved end
      else
        ok = false
        short_raw(E, proj, item, short, prio)
      end
    end
  end
  return ok
end

---------------------------------------------------------------------------------------------------
-- Émission par type de projet
---------------------------------------------------------------------------------------------------
local function count_kind(view, kind)
  local n = 0
  for _, o in ipairs(view.outposts or {}) do if o.kind == kind then n = n + 1 end end
  return n
end

local function extendable(view, kind, undefended)
  for _, o in ipairs(view.outposts or {}) do
    if o.kind == kind and not o.full and o.drills < T.max_drills(kind) and not (undefended and undefended[o.id]) then
      return o
    end
  end
  return nil
end

local EMIT = {}

--- Avant-poste (construction ou agrandissement) : comme l'échelle d'avant, mais PAR BESOIN et en parallèle.
EMIT.outpost = function(E, proj, g, ctx)
  local view, kind = E.view, g.outpost
  local spec = T.outposts[kind]
  local prio = proj.prio
  if (view.pending[kind] or 0) > 0 then return "en_cours" end
  local df = view.defend_first and true or false
  local turret_ok = df and (E.book:handcraftable(P.TURRET) or (E.avail[P.TURRET] or 0) > 0) or false
  local und = Planner.no_go(view, turret_ok)
  local items = Planner.outpost_items(kind)
  local ext = extendable(view, kind, und)
  if ext then
    local key = "extend:" .. ext.id
    if E.open[key] then return "en_cours" end
    if P.take(E, items) then
      P.add(E, { key = key, kind = "extend", prio = prio + P.FINISH_BONUS, outpost = ext.id, outpost_kind = kind,
        items = items, ia3 = proj.id, why = proj.key })
      return "ok"
    end
    P.want(E, proj, items, prio, false, kind)
    return "matiere"
  end
  local wait = df and extendable(view, kind)
  if wait then
    -- Défendre d'abord (IA1-b2) : l'avant-poste attend ses tourelles, que le planificateur permanent fabrique et pose
    -- en URGENCE (want_defense, au-dessus de son plancher de fer et de cuivre : les recrues de survie d'abord). Le projet
    -- attend sans rien prendre (essai 4 de ce lot, moteur simulé : tourelles et chargeurs demandés ICI sans plancher,
    -- fer à 17 à 5 min, armée à 0). Sans recette de tourelle : bloqué.
    if not turret_ok then return "bloque", "tourelles" end
    local nt = math.max(1, T.defend_turrets(wait.drills) - (wait.turrets or 0))
    proj.missing = { [P.TURRET] = nt }
    -- Lot IA-V2 (piège de pauvreté, moteur réel, ia3c-default graine 20261020 : Écarlate, avant-postes de fer et de
    -- charbon « manque [gun-turretx1] » pendant 2 h, le fer mangé par l'armée et les munitions, 4 à 5 PNJ sur 8 sans
    -- tâche) : après P.TURRET_WAIT d'attente, le projet FABRIQUE ses tourelles et leurs chargeurs, à sa propre priorité
    -- (la pose reste au planificateur permanent). Pas avant : l'essai 4 d'IA3-c (tourelles demandées dès la 1re minute)
    -- avait effondré l'économie au moteur simulé.
    local since = proj.waiting_since
    if since and ctx and ctx.tick and ctx.tick - since >= P.TURRET_WAIT then
      P.want(E, proj, { { P.TURRET, nt }, { T.turret_ammo, nt * T.defend_ammo } }, prio, false, "tourelle")
    end
    return "matiere"
  end
  -- Construction : avec ses tourelles (défendre d'abord, IA1-b2) quand une tourelle est possible et que ce n'est pas
  -- le premier avant-poste de ce type.
  local list = items
  if turret_ok and count_kind(view, kind) > 0 then
    list = {}
    for _, it in ipairs(items) do list[#list + 1] = it end
    local nt = T.defend_turrets(spec.drills)
    list[#list + 1] = { P.TURRET, nt }
    list[#list + 1] = { T.turret_ammo, nt * T.defend_ammo }
  end
  E.site_needs[kind] = math.max(E.site_needs[kind] or 0, 1)
  local key = "build:" .. kind
  if E.open[key] then return "en_cours" end
  if (view.sites[kind] or 0) > 0 then
    if P.take(E, list) then
      P.add(E, { key = key, kind = "build", prio = prio + P.FINISH_BONUS, outpost_kind = kind, items = list,
        ia3 = proj.id, why = proj.key })
      return "ok"
    end
    P.want(E, proj, list, prio, false, kind)
    return "matiere"
  end
  -- Aucun site connu : explorer, et préparer les objets pendant ce temps (un joueur fabrique ses foreuses en route).
  -- Lot IA-V2 : un gisement CONNU (ctx.known, carte d'IA3-f) n'est pas à explorer : son site attend la prospection.
  if not (ctx and ctx.known and ctx.known[spec.resource]) then
    E.explore[spec.resource] = math.max(E.explore[spec.resource] or 0, prio)
  end
  P.want(E, proj, list, prio - 5, false, kind)
  return "bloque", "site:" .. kind
end

--- Fonderie du QG : fours posés au QG.
EMIT.smelters = function(E, proj, g)
  if E.open["smelters"] or (E.view.smelters_pending or 0) > 0 then return "en_cours" end
  local items = { { T.SMELTER, g.n }, { T.fuel, T.fuel_per_burner * g.n } }
  if P.take(E, items) then
    P.add(E, { key = "smelters", kind = "smelters", prio = proj.prio + P.FINISH_BONUS, count = g.n, items = items,
      ia3 = proj.id, why = proj.key })
    return "ok"
  end
  P.want(E, proj, items, proj.prio, false, "four")
  return "matiere"
end

--- Réserve d'un objet (munitions) : besoin d'accumulation.
EMIT.stock = function(E, proj, g)
  return P.want(E, proj, { { g.item, g.n } }, proj.prio, true, "stock") and "ok" or "matiere"
end

--- Armée : un lot de T.kit_batch soldats. Le soldat est le MEILLEUR dont l'équipement est au stock ou se fabrique
--- MAINTENANT avec ce qui reste (« le meilleur équipement payable », §3.1) ; sinon le soldat le plus simple, fabriqué en
--- partie. Échelle des soldats : celle du planificateur (Planner.best_unit du niveau, puis des niveaux inférieurs).
--- Moteur simulé de pvp_test, essai 6 de ce lot : toujours le grenadier (8 grenades, 80 charbons par soldat) faute
--- de mieux, charbon à 9, l'armée ne se refaisait plus après une attaque (19 soldats de 20 à 30 min).
EMIT.army = function(E, proj, g, ctx)
  local view = E.view
  local n = math.min(T.kit_batch, (g.target or 0) - (view.soldiers or 0))
  if n <= 0 or E.train then return "ok" end
  local units, seen = {}, {}
  for t = (view.tech or 0), 0, -1 do
    local u = Planner.best_unit(t)
    if not seen[u] then seen[u] = true units[#units + 1] = u end
  end
  if not seen[P.FALLBACK_UNIT] then units[#units + 1] = P.FALLBACK_UNIT end
  local function kits_of(unit)
    local kits = {}
    for _, it in ipairs(T.kits[unit]) do kits[#kits + 1] = { it[1], it[2] * n } end
    return kits
  end
  for _, unit in ipairs(units) do
    if P.take(E, kits_of(unit)) then
      E.train = { unit = unit, count = n, ia3 = proj.id }
      return "ok"
    end
  end
  for _, unit in ipairs(units) do
    local kits = kits_of(unit)
    if next(E.book:plan(kits, E.avail).raw) == nil then
      P.want(E, proj, kits, proj.prio, false, "kit")
      return "matiere"
    end
  end
  P.want(E, proj, kits_of(units[#units]), proj.prio, false, "kit")
  return "matiere"
end

--- Recherche (factions, laboratoire du QG) : laboratoires à fabriquer et packs à accumuler, donnés par le runtime
--- (ctx.research : { tech, payable, causes, packs = { {pack, n} }, lab_item, labs_craft }). Recherche IMPAYABLE : rien
--- n'est fabriqué (H8, critère K6). Garde de l'économie (revue B3) : avant « fer II », les packs ne puisent pas sous le
--- plancher de fer (`ctx.iron_floor`).
EMIT.research = function(E, proj, g, ctx)
  local r = ctx.research
  if not r then return "bloque", "aucune" end
  if not r.payable then return "bloque", "impayable:" .. table.concat(r.causes or {}, ",") end
  local prio = proj.prio
  local status = "ok"
  if r.lab_item and (r.labs_craft or 0) > 0 then
    if not P.want(E, proj, { { r.lab_item, r.labs_craft } }, prio + P.FINISH_BONUS, false, "labo") then status = "matiere" end
  end
  if r.packs and #r.packs > 0 then
    local floor = ctx.iron_floor or 0
    local keep = math.min(E.avail[P.IRON] or 0, floor)
    E.avail[P.IRON] = (E.avail[P.IRON] or 0) - keep
    if not P.want(E, proj, r.packs, prio, true, "pack") then status = "matiere" end
    E.avail[P.IRON] = (E.avail[P.IRON] or 0) + keep
  end
  return status
end

--- Émet les tâches d'un projet ; met à jour son état (actif, bloqué + cause) et ses manques.
function P.emit(E, proj, ctx, tick)
  proj.missing = {}
  local before = #E.tasks
  local fn = EMIT[proj.goal.kind]
  local status, cause = "bloque", "type"
  if fn then status, cause = fn(E, proj, proj.goal, ctx) end
  proj.emitted = #E.tasks - before
  local was = proj.state
  if status == "bloque" then
    proj.state, proj.cause = "bloque", cause
    if was ~= "bloque" then announce(E.st, tick, "bloque", proj.key, cause) end
  else
    proj.state, proj.cause = "actif", nil
  end
  if status == "matiere" then proj.waiting_since = proj.waiting_since or tick else proj.waiting_since = nil end
  proj.status = status
  return status
end

---------------------------------------------------------------------------------------------------
-- Fonderie d'amorçage (lot IA-V2) : AVANT les projets
---------------------------------------------------------------------------------------------------
--- Une plaque manquait à la pensée précédente (st.short) et aucun avant-poste ne la produit : les fours du QG passent
--- AVANT les projets, sur le stock virtuel entier (chemin critique : aucune plaque sans four). Moteur réel, ia3b-fer,
--- 27/10 (1bd0801) : les projets d'avant-postes (fours sur site) prenaient d'abord les fours du stock, l'approvisionnement
--- n'en recevait jamais : 0 four au QG pendant 15 min, 301 minerais de fer au coffre, 0 plaque. Pose de ce que le
--- charbon permet (comme IA3-b), le reste fabriqué. Renvoie vrai si l'amorçage est pris en charge ici.
function P.boot_smelters(E, st, cap)
  local view = E.view
  local short, unfed = 0, false
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local plate = T.outposts[kind].product
    if T.smelter_inputs[plate] and (cap[kind] or 0) <= 0 then
      unfed = true
      short = math.max(short, (st.short or {})[plate] or 0)
    end
  end
  local have = (view.smelters or 0) + (view.smelters_pending or 0)
  -- Aucun four au QG et aucune plaque produite par un avant-poste : l'amorçage part dès la PREMIÈRE pensée (un joueur
  -- pose ses fours avant tout ; moteur réel, ia3b-fer sur 5ddcd70 : sans cela, la 1re pensée fabriquait les fours des
  -- avant-postes avec toute la pierre, 1 four au QG à 2 min, 4 à 4 min, 62 plaques à 7,3 min).
  if E.open["smelters"] or (short <= 0 and not (have == 0 and unfed)) then return false end
  local n = short >= P.SMELT_MORE and P.SMELTERS_BOOT_MORE or P.SMELTERS_BOOT
  if have >= n then return false end
  local need = n - have
  local put = math.min(need, E.avail[T.SMELTER] or 0, math.floor((E.avail[T.fuel] or 0) / T.fuel_per_burner))
  local proj = { id = 0, key = "fonderie" }
  if put > 0 then
    local list = { { T.SMELTER, put }, { T.fuel, T.fuel_per_burner * put } }
    P.take(E, list)
    P.add(E, { key = "smelters", kind = "smelters", prio = P.BOOT_PRIO, count = put, items = list, why = "fonderie" })
  end
  if put < need then
    P.want(E, proj, { { T.SMELTER, need - put }, { T.fuel, T.fuel_per_burner * (need - put) } }, P.BOOT_PRIO, false, "four")
  end
  E.booted = true
  return true
end

---------------------------------------------------------------------------------------------------
-- Approvisionnement : les matières brutes qui manquent (feuilles du dépliage)
---------------------------------------------------------------------------------------------------
--- Sert les manques E.raw : fonderie (et ses fours s'il n'y en a pas), minage à la main par plusieurs PNJ, exploration
--- d'une ressource sans source connue. ctx = { reach = { [ressource] = rayon en tuiles, ou nil : inconnue },
--- workers, mines_open = { [ressource] = tâches de minage déjà prises } }. Trois tours au plus (l'acier demande des
--- plaques, les plaques du minerai, les fours de la pierre).
function P.supply(E, ctx)
  local view = E.view
  local done = {}
  local smelters = (view.smelters or 0) + (view.smelters_pending or 0)
  -- Jusqu'à la moitié des PNJ au minage à la main d'une matière qui manque (constat du DC : « plein qui foutent rien »).
  local mine_room = math.max(1, math.floor((ctx.workers or 0) / 2))
  -- Lot IA-V2 (chemin critique, §3.5) : une plaque fondue au QG qu'aucun avant-poste ne produit, et qui manque, bloque
  -- tous les projets qui en ont besoin : les AUTRES matières brutes de leurs composants (pierre des fours d'avant-poste…)
  -- attendent (P.DEFER_PRIO), sauf celles de la fonderie d'amorçage (« fonderie »). Moteur réel, ia3b-fer sur c06a97b :
  -- 2,7 PNJ sur la pierre et le charbon pendant la 1re minute, 62 plaques à 7,3 min.
  local function unfed_plate(item)
    for _, k in ipairs(T.OUTPOST_ORDER) do
      local spec = T.outposts[k]
      if (spec.product == item or spec.resource == item) and T.smelter_inputs[spec.product] then
        return ((ctx.cap or {})[k] or 0) <= 0
      end
    end
    return false
  end
  -- Le GOULOT (H2) : la plaque sans avant-poste qui manque le plus ; elle seule passe à la priorité de l'amorçage (deux
  -- plaques au même rang se partageaient les mineurs : moteur réel, ia3b-fer sur b33efe6, 1 mineur de fer au plus, le
  -- cuivre au même rang).
  -- Fours du QG à court de combustible (charbon du coffre sous la recharge des fours posés).
  local smelter_dry = (view.smelters or 0) > 0 and (view.smelter_fuel_low or
    (E.avail[T.fuel] or 0) < T.fuel_per_burner * (view.smelters or 0))
  local blocked_by_plate, bottleneck, worst = false, nil, 0
  for _, k in ipairs(sorted_keys(E.raw)) do
    if T.smelter_inputs[k] and E.raw[k].n > 0 and unfed_plate(k) then
      blocked_by_plate = true
      if E.raw[k].n > worst then bottleneck, worst = k, E.raw[k].n end
    end
  end
  for _ = 1, 4 do
    local items = {}
    for _, k in ipairs(sorted_keys(E.raw)) do if not done[k] then items[#items + 1] = k end end
    if #items == 0 then break end
    for _, item in ipairs(items) do
      done[item] = true
      local r = E.raw[item]
      local prio = math.min(85, r.prio + P.SUPPLY_BONUS)
      local proj = { id = r.pid or 0, key = r.why or "approvisionnement" }
      local input = T.smelter_inputs[item]
      -- Une matière dont un AVANT-POSTE tourne déjà (capacité > 0) vient de ses tournées : la fonderie et le minage à
      -- la main ne sont qu'un APPOINT (priorité basse, un PNJ au plus), comme l'ancien cerveau ; c'est à la famille
      -- extraction d'agrandir. Sans avant-poste (le cas du DC), ils sont la source et passent devant (+ SUPPLY_BONUS).
      -- Moteur simulé de pvp_test, essai 4 de ce lot : 3 PNJ sur 6 au minage à la main à 85, armée à 0 à 15 min.
      local kind = nil
      for _, k in ipairs(T.OUTPOST_ORDER) do
        local spec = T.outposts[k]
        if spec.product == item or spec.resource == item then kind = k end
      end
      local fed = kind ~= nil and ((ctx.cap or {})[kind] or 0) > 0
      if fed then prio = math.min(prio, P.APPOINT_PRIO) end
      -- Lot IA-V2 (K3, constat du DC « plein qui foutent rien ») : une matière qui manque alors qu'un avant-poste la produit
      -- déjà garde son minage d'APPOINT à priorité basse, mais avec autant de mineurs que de PNJ sans tâche (au plus la
      -- moitié de l'équipe) : moteur réel, ia3c-reduit graine 20261020 (938e08e), seul le fer manquait, tout le reste
      -- saturé, un seul mineur d'appoint : 24 % de PNJ sans tâche de 30 à 90 min (5 % avant le lot).
      local room = fed and math.max(1, math.min(mine_room, view.workers_idle or 0)) or mine_room
      -- Lot IA-V2 : une PLAQUE (fondue au QG) qu'aucun avant-poste ne produit est sur le chemin critique de tout projet
      -- qui en a besoin : son minerai et sa fonte passent à la priorité de l'amorçage, devant la pierre et le charbon des
      -- composants (moteur réel, ia3b-fer sur 968dc38 : 1re minute, 2,7 PNJ sur la pierre et le charbon des fours des
      -- avant-postes, 0 sur le fer ; 62 plaques à 5,6 min contre 4,7 avec IA3-b seul).
      local plate_kind = kind and T.smelter_inputs[T.outposts[kind].product] and kind or nil
      local critical = plate_kind ~= nil and not fed and bottleneck == T.outposts[plate_kind].product
      if critical then prio = math.max(prio, P.BOOT_PRIO)
      elseif blocked_by_plate and item == T.fuel and smelter_dry then
        -- Lot IA-V2 : le COMBUSTIBLE des fours du QG est sur le chemin critique de la plaque quand les fours en manquent
        -- (moteur réel, ia3b-fer sur 0302af1 : charbon reporté avec les autres matières, fours à sec, plaques bloquées à
        -- 44 pendant 3 min). Seulement dans ce cas, et 2 mineurs au plus (au moteur simulé, le charbon des foreuses des
        -- avant-postes passait aussi devant : ia1_scale_test, une faction à 26 PNJ sur 30 en 12 min).
        prio = math.max(prio, P.BOOT_PRIO - 1)
        room = math.min(room, 2)
      elseif blocked_by_plate and r.why ~= "fonderie" then prio = math.min(prio, P.DEFER_PRIO) end
      if input then
        -- Fondre : la fonderie du QG (ses fours d'abord s'il n'y en a pas).
        E.smelt[item] = (E.smelt[item] or 0) + r.n
        if prio > E.smelt_prio then E.smelt_prio = prio end
        if smelters == 0 and not E.open["smelters"] and not E.booted then
          local n = r.n >= P.SMELT_MORE and P.SMELTERS_BOOT_MORE or P.SMELTERS_BOOT
          local list = { { T.SMELTER, n }, { T.fuel, T.fuel_per_burner * n } }
          if P.take(E, list) then
            P.add(E, { key = "smelters", kind = "smelters", prio = prio + 1, count = n, items = list, ia3 = r.pid,
              why = item .. ">" .. proj.key })
          else
            P.want(E, proj, list, prio + 1, false, "four")
          end
          smelters = n
        end
        local need = r.n * input[2]
        local have = E.avail[input[1]] or 0
        local use = have < need and have or need
        E.avail[input[1]] = have - use
        if need - use > 0 then short_raw(E, proj, input[1], need - use, r.prio) end
      elseif ctx.minable and ctx.minable[item] then
        -- Miner à la main : plusieurs PNJ en parallèle, sur un gisement connu (sinon explorer).
        local radius = ctx.reach and ctx.reach[item]
        if not radius then
          -- Lot IA-V2 : connu mais hors de portée de la main : pas d'exploration (l'avant-poste ira le chercher).
          if not (ctx.known and ctx.known[item]) then E.explore[item] = math.max(E.explore[item] or 0, prio) end
        else
          local want = math.min(room, math.ceil(r.n / (critical and P.PLATE_PER_MINER or P.MINE_BATCH)))
          if fed and (view.workers_idle or 0) > 0 then want = room end -- lot IA-V2 : appoint par les PNJ sans tâche
          local busy = (ctx.mines_open and ctx.mines_open[item]) or 0
          local n = 0
          for i = 1, room do
            if n >= want - busy then break end
            if P.add(E, { key = "ia3:mine:" .. item .. ":" .. i, kind = "mine", prio = prio, resource = item, prudent = true,
              count = P.MINE_BATCH, radius = radius, ia3 = r.pid, why = item .. ">" .. proj.key }) then n = n + 1 end
          end
        end
      else
        E.unreachable = E.unreachable or {}
        E.unreachable[#E.unreachable + 1] = item
      end
    end
  end
end

return P
