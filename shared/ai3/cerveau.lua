--[[
  IA3-c « le cerveau par besoins » : la PENSÉE d'une équipe (docs/IA3_CERVEAU.md §1.1, §3, §5.3). PUR (aucune API
  Factorio) : le runtime (script/ai3/cerveau.lua) lui donne la vue de l'équipe (script/team/team.lua, Team.view), le
  livre de recettes, l'état PERSISTANT de l'équipe `st` (f.team.ia3, dans global) et le contexte de la pensée (poids
  du chef, recherche, gisements atteignables) ; il rend un PLAN au format du planificateur (tasks, missing, goal,
  site_needs, smelt, recrues, train) : le tableau des tâches (script/team/board.lua) et les ouvriers sont inchangés.

  Phases d'une pensée (une pensée par équipe toutes les 300 ticks, chaque équipe à son créneau de l'ordonnanceur ;
  état entre deux pensées dans `st`, donc dans global : revue B1, aucune phase ne lit un cache tiré de l'état de partie) :
    1. observer  : situation (capacités d'extraction, stock, manques des pensées passées) ;
    2. permanent : le planificateur d'aujourd'hui, appelé SANS échelle et SANS recherche, sert les familles que la
                   conception GARDE telles quelles (§3.1 : entretien, réserve, survie d'IA2-a2 et VERIF-NUIT, défense
                   d'IA1-b2, recrues) ; il sert le stock virtuel EN PREMIER (urgences, puis réserve, §2.2) ;
    3. buts      : générateurs par famille (shared/ai3/buts.lua), valeurs pondérées par le chef ;
    4. projets   : K projets actifs, inertie, bloqués sans place (shared/ai3/projets.lua) ;
    5. dépliage  : chaque projet, dans l'ordre de priorité, émet ses tâches depuis ce qui reste au stock virtuel ;
    6. approvisionnement : les matières brutes qui manquent (fonderie et ses fours, minage à la main par plusieurs PNJ,
                   exploration d'une ressource sans source connue) ;
    7. besoin et saturation : le besoin de chaque matière (manque + usage) est gardé ; une matière dont le stock dépasse
                   B.SAT_FACTOR fois le besoin n'est plus extraite (tournées de collecte ordinaires retirées ; le fond est
                   filtré par le runtime) ;
    8. plan      : tâches triées (priorité décroissante, puis clé), projet dominant et son manque (fenêtre, étiquette).
  Coût : celui du planificateur (≈ 0,6 ms) plus un plan de livre par fabrication émise (12 au plus) ; mesuré au banc.

  Déterminisme : listes triées, clés stables, entiers, aucun hasard, aucun pairs décisionnel.
]]

local T = require("shared.team.config")
local Planner = require("shared.team.planner")
local B = require("shared.ai3.buts")
local P = require("shared.ai3.projets")
local R = require("shared.ai3.reglages") -- lot IA-G : ressources clés de repli
local A = require("shared.ai3.automatiser") -- lot IA3-e : modules demandés au plan directeur (projets « module »)
local Bi = require("shared.ai3.bilan") -- lot BILAN : fabrications pondérées par production moins consommation

P.EMIT.module = A.emit(P)
local Cap = require("shared.ai3.capital") -- lot CAPITAL : buts « amélioration » (niveaux, centre), payés par le runtime
P.EMIT.upgrade = Cap.emit(P)
local Ca = require("shared.ai3.capitalisation") -- lot CAPIB : buts de FOND de la capitalisation (réglage fo-war-capi)
P.EMIT.capi = Ca.emit(P)

local C = {}

C.NEED_DECAY_PCT = 90 -- besoin gardé d'une pensée à l'autre : pic décroissant de 10 % par pensée

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Matières « brutes » (données de shared/team/config.lua) : produits et ressources des avant-postes, produits de la
--- fonderie. Ressources minables à la main.
function C.raw_items()
  local raw, minable = {}, {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local spec = T.outposts[kind]
    raw[spec.product] = true
    raw[spec.resource] = true
    minable[spec.resource] = true
  end
  for _, p in ipairs(sorted_keys(T.smelter_inputs)) do
    raw[p] = true
    raw[T.smelter_inputs[p][1]] = true
  end
  return raw, minable
end

--- État persistant neuf (f.team.ia3) : nombres, chaînes et tables seulement (global).
function C.new_state(tick)
  return { v = 1, since = tick or 0, next_id = 1, projects = {}, targets = {}, short = {}, short_n = {}, need = {},
    ever = {}, log = {}, saturated = {}, explore = {} }
end

--- 1. Situation.
function C.situation(view, st, ctx)
  local cap = {}
  -- Lot SCALE-COMPLET : types dont un avant-poste a encore des places (ni plein, sous le plafond de foreuses ; lecteur :
  -- B.generate, buts de couverture).
  local room = {}
  for _, o in ipairs(view.outposts or {}) do
    cap[o.kind] = (cap[o.kind] or 0) + (o.drills or 0) / T.outposts[o.kind].drills
    if not o.full and (o.drills or 0) < T.max_drills(o.kind) then room[o.kind] = true end
  end
  for _, kind in ipairs(T.OUTPOST_ORDER) do if (cap[kind] or 0) > 0 then st.ever[kind] = true end end
  -- Lot IA3-e : un module FINI (fonderie électrique et ses foreuses) compte comme capacité d'extraction de son produit
  -- (en unités d'avant-poste) : le cerveau ne bâtit plus l'avant-poste que le module remplace. Après `ever` : un module
  -- n'est pas un avant-poste à reconstruire.
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local add = ctx.auto and ctx.auto.cap and ctx.auto.cap[kind] or 0
    if add > 0 then cap[kind] = (cap[kind] or 0) + add end
  end
  if (view.soldiers or 0) >= B.ARMY_FIRST_N then st.army_done = true end
  return {
    is_player = ctx.is_player or false, workers = view.workers or 0, soldiers = view.soldiers or 0,
    soldiers_max = view.soldiers_max or 0, stock = view.stock or {}, cap = cap, pending = view.pending or {},
    sites = view.sites or {}, room = room, smelters = view.smelters or 0, smelters_pending = view.smelters_pending or 0,
    weights = ctx.weights or {}, research = ctx.research, army_target = ctx.army_target or 0, need = st.need,
    at_war = ctx.at_war or view.threatened or false,
    -- Lot IA-V2 : l'économie est « faite » au fer II de l'ancienne échelle OU quand un avant-poste de fer tourne et que
    -- le fer est SATURÉ (st.economy_ok, collant) : le cerveau par besoins ne bâtit pas un 2e avant-poste de fer qui ne
    -- sert à rien, et la recherche restait plafonnée pour toujours (moteur réel, ia3c-reduit et ia3c-default graine
    -- 20261020 : fer II jamais, 2 700 plaques de fer au coffre, paliers 2 et 3 à 29 et 48 min à 8 PNJ).
    economy_done = st.iron2_done ~= nil or st.economy_ok ~= nil,
    -- Lot IA-G : ressources clés DÉDUITES du dépliage des buts (script/ai3/general.lua) ; repli : celles de l'échelle.
    key = (ctx.key and ctx.key.top and ctx.key.fuel) and ctx.key or R.FALLBACK_KEY,
    idle_grow = ctx.idle_grow or false, tick = ctx.tick or 0, -- lot IA-G : bras libres
    spare = ctx.spare, -- lot SCALE : nombre de bras libres durables (vague d'extraction d'avance, shared/ai3/bras.lua)
  }
end

--- 2. Vue du planificateur permanent : la vue de l'équipe, sans échelle ni recherche ; `done` = types d'avant-postes
--- déjà bâtis une fois (reconstruction d'un avant-poste perdu), et « army » seulement en reconstruction ou menacée
--- (garde de survie d'IA2-a2) : l'armée ordinaire est un projet.
function C.base_view(view, st)
  local done = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do if st.ever[kind] then done[kind] = true end end
  local em = view.emergency
  if st.army_done and (view.threatened or (em and em.rebuild)) then done.army = true end
  local vb = setmetatable({ ladder = {}, no_research = true, done = done, deferred = {} }, { __index = view })
  return vb
end

--- Consommation du stock virtuel par les tâches et décisions du planificateur permanent.
function C.consumed(base, view)
  local used = {}
  local function add(list, times)
    for _, it in ipairs(list or {}) do used[it[1]] = (used[it[1]] or 0) + it[2] * (times or 1) end
  end
  local groups = {}
  for _, g in ipairs(view.turret_groups or {}) do groups[g.key] = g end
  for _, t in ipairs(base.tasks or {}) do
    if t.uses then add(t.uses)
    elseif t.items then add(t.items)
    elseif t.kind == "refill" and groups[t.group] then
      used[T.turret_ammo] = (used[T.turret_ammo] or 0) + groups[t.group].low * T.turret_ammo_target
    end
  end
  if base.recruit_workers and not base.recruit_unarmed then add(base.recruit_uses or view.recruit_cost) end
  local tr = base.train
  if tr then
    if tr.uses then add(tr.uses) else add(T.kits[tr.unit], tr.count) end
  end
  return used
end

--- La pensée. ctx = { tick, is_player, weights, research, reach = { [ressource] = rayon }, mines_open, iron_floor,
--- army_target, home_known (faux : abords du QG pas encore vus, aucune exploration ; lot IA-V2) }. Renvoie le plan (format du planificateur) ; plan.ia3 = compte rendu (projets, exploration, saturées).
function C.think(view, book, st, ctx)
  local tick = ctx.tick or 0
  -- 1. Observer.
  local s = C.situation(view, st, ctx)
  -- 2. Familles permanentes (planificateur sans échelle).
  local base = Planner.plan(C.base_view(view, st), book)
  local used = C.consumed(base, view)
  local avail = {}
  for _, k in ipairs(sorted_keys(view.stock)) do avail[k] = view.stock[k] end
  for _, k in ipairs(sorted_keys(view.incoming)) do avail[k] = (avail[k] or 0) + view.incoming[k] end
  for _, k in ipairs(sorted_keys(used)) do avail[k] = math.max(0, (avail[k] or 0) - used[k]) end
  local avail0 = {}
  for k, v in pairs(avail) do avail0[k] = v end
  -- 3. Buts ; 4. projets.
  local goals = A.goals(B.generate(s, st), ctx.auto, s.weights, s.research) -- lot IA3-e : modules demandés = projets
  -- Lot CAPITAL : le but « amélioration » choisi par le runtime (valeur ÷ coût, shared/ai3/capital.lua), factions seulement.
  if ctx.capital then goals[#goals + 1] = ctx.capital end
  -- Lot CAPIB : un but de FOND par ordre ouvert de la capitalisation (ses exécutants ont reçu l'ordre au runtime ; le but
  -- fait ce qui leur manque, sur la part capi du stock virtuel).
  if ctx.capi then Ca.goals(goals, nil, ctx.capi.open) end
  local order, K = P.update(st, goals, tick, s.workers)
  -- 5. Dépliage.
  local E = P.context(avail, book, view, st)
  E.priorite = base.priorite -- lot PRIORITE-RESSOURCES : production d'abord quand le fer ne paie pas la défense et la production
  for k, n in pairs(base.smelt or {}) do E.smelt[k] = n end
  P.boot_smelters(E, st, s.cap) -- lot IA-V2 : fours du QG avant les projets (chemin critique)
  for _, proj in ipairs(order) do P.emit(E, proj, ctx, tick) end
  -- 6. Approvisionnement.
  local raw, minable = C.raw_items()
  -- Lot KIT : matières naturelles récoltables (le bois des poteaux, lu par le runtime sur les arbres) : à miner à la main
  -- comme un minerai, quand elles sont à portée (ctx.reach) ; sans arbre à portée, elles restent « inaccessibles ».
  for _, k in ipairs(ctx.harvest or {}) do raw[k] = true minable[k] = true end
  P.supply(E, { reach = ctx.reach, known = ctx.known, workers = s.workers, mines_open = ctx.mines_open, minable = minable,
    cap = s.cap, home_known = ctx.home_known, bilan = ctx.bilan })
  -- Lot IA-V2 : pas d'exploration demandée avant que les abords du QG soient vus (ctx.home_known faux : brouillard
  -- d'IA3-f, regard en cours) ; le projet reste bloqué sur sa cause (« site: »), rien d'autre ne change.
  if ctx.home_known == false then E.explore = {} end
  -- 7. Besoin, manques persistants, saturation.
  local short = {}
  for _, k in ipairs(sorted_keys(E.raw)) do short[k] = math.ceil(E.raw[k].n) end
  st.short_n = st.short_n or {}
  for _, k in ipairs(sorted_keys(raw)) do
    if (short[k] or 0) > 0 then st.short_n[k] = (st.short_n[k] or 0) + 1 else st.short_n[k] = nil end
  end
  st.short = short
  st.need = st.need or {}
  for _, k in ipairs(sorted_keys(raw)) do
    local use = math.max(0, (avail0[k] or 0) - (E.avail[k] or 0))
    local now = use + (short[k] or 0)
    local kept = math.floor((st.need[k] or 0) * C.NEED_DECAY_PCT / 100)
    local v = now > kept and now or kept
    st.need[k] = v > 0 and v or nil
  end
  local saturated = {}
  for _, k in ipairs(sorted_keys(raw)) do
    if (view.stock[k] or 0) > 0 and B.saturated(s, k) then saturated[k] = true end
  end
  st.saturated = saturated
  -- … et seulement quand l'équipe a son effectif visé (ses recrues se paient en fer : moteur simulé, ia1_scale_test, une
  -- faction à 26 PNJ sur 30 en 12 min quand la recherche déplafonnée prenait le fer des recrues).
  local top = s.key.top -- lot IA-G : la ressource la plus demandée (le fer sur les données vanilla)
  if not st.economy_ok and (s.cap[top] or 0) >= 0.75 and saturated[T.outposts[top].product]
    and ((view.workers or 0) >= (view.workers_wanted or 0) or view.workers_enough) then st.economy_ok = tick end
  -- (lot IA3-d : view.workers_enough = la règle d'effectif dit qu'aucun bras ne manque ; une faction plafonnée à 30 qui
  -- n'a pas besoin de grandir a son effectif visé.)
  -- Lot IA-V2 : une matière saturée ne libère ses bras que si une AUTRE manque (critère A5 : « aucune matière au-dessus
  -- de 3 fois son besoin PENDANT qu'une autre manque » ; constat du DC du 25/10 : pierre et charbon ramassés pendant que
  -- le fer manquait). Rien ne manque : la collecte et le fond continuent (moteur réel, ia3c-dc-apres, 27/10 : sans cette
  -- règle, 5 à 8 PNJ sur 8 inactifs de 16 à 20 min, tout étant « saturé » faute de besoin).
  local other_short = false
  for _, k in ipairs(sorted_keys(short)) do
    if short[k] > 0 and not saturated[k] then other_short = true end
  end
  st.other_short = other_short
  st.explore = E.explore
  -- 8. Plan.
  local product_of = {}
  for _, o in ipairs(view.outposts or {}) do product_of[o.id] = T.outposts[o.kind].product end
  local tasks, keys = {}, {}
  local dropped = 0
  -- Lot IA3-e : « fini retire du travail à la main le débit nominal » : les tournées ordinaires (sous les urgences) des
  -- avant-postes dont le produit est COUVERT par un module fini sont retirées (le module livre ce flux).
  local covered = (ctx.auto and ctx.auto.covered) or {}
  st.covered = covered
  for _, t in ipairs(base.tasks or {}) do
    local prod = product_of[t.outpost] or ""
    local drop = (other_short and t.kind == "service" and t.prio < 90 and saturated[prod])
      or (t.kind == "service" and t.prio < 90 and covered[prod]) or false
    if drop then dropped = dropped + 1 else
      tasks[#tasks + 1] = t
      keys[t.key] = true
    end
  end
  for _, t in ipairs(E.tasks) do
    -- Lot BILAN : une fabrication d'un objet en sous-production durable passe devant (jamais au niveau d'une urgence).
    if t.kind == "craft" and t.item and ctx.bilan then t.prio = Bi.craft(t.prio, ctx.bilan[t.item]) end
    if not keys[t.key] then
      tasks[#tasks + 1] = t
      keys[t.key] = true
    end
  end
  local smelt = base.smelt or {}
  for _, k in ipairs(sorted_keys(E.smelt)) do smelt[k] = E.smelt[k] end
  local has_smelt = false
  for _, t in ipairs(tasks) do
    if t.kind == "smelt" then
      has_smelt = true
      t.smelt = smelt
      if E.smelt_prio > t.prio then t.prio = E.smelt_prio end
    end
  end
  if not has_smelt and (view.smelters or 0) > 0 and not view.smelter_task and next(smelt) ~= nil
    and not (view.open or {})["smelt"] then
    tasks[#tasks + 1] = { key = "smelt", kind = "smelt", prio = math.max(60, E.smelt_prio), smelt = smelt }
  end
  table.sort(tasks, function(a, b)
    if a.prio ~= b.prio then return a.prio > b.prio end
    return a.key < b.key
  end)
  local site_needs = {}
  for k, n in pairs(base.site_needs or {}) do site_needs[k] = n end
  for _, k in ipairs(sorted_keys(E.site_needs)) do site_needs[k] = math.max(site_needs[k] or 0, E.site_needs[k]) end
  -- Projet dominant (le premier actif, sinon le premier ouvert) et son manque.
  local dom = nil
  for _, p in ipairs(order) do if p.state == "actif" then dom = p break end end
  dom = dom or order[1]
  local missing = {}
  if dom then
    for _, k in ipairs(sorted_keys(dom.missing)) do missing[#missing + 1] = { k, math.ceil(dom.missing[k]) } end
    table.sort(missing, function(a, b)
      if a[2] ~= b[2] then return a[2] > b[2] end
      return a[1] < b[1]
    end)
    if dom.cause and dom.cause:sub(1, 5) == "site:" then table.insert(missing, 1, { dom.cause, 1 }) end
  end
  local n_active, n_productive = 0, 0
  for _, p in ipairs(st.projects) do
    if p.state == "actif" then
      n_active = n_active + 1
      if (p.emitted or 0) > 0 or p.status == "en_cours" then n_productive = n_productive + 1 end
    end
  end
  return {
    tasks = tasks, missing = missing, reached = {}, site_needs = site_needs, smelt = smelt,
    goal = dom and ("ia3-" .. dom.key:gsub(":", "-")) or nil,
    research = nil, train = base.train or E.train,
    recruit_workers = base.recruit_workers, recruit_uses = base.recruit_uses, recruit_unarmed = base.recruit_unarmed,
    emergency_unarmed = base.emergency_unarmed, emergency_recruit = base.emergency_recruit,
    recruit_blocked = base.recruit_blocked, recruit_held = base.recruit_held, unreachable = E.unreachable,
    grow_short = base.grow_short, -- lot FER-EQUIPE : la réserve de fer a retenu une recrue (journal [FO-FER])
    coal_rate = base.coal_rate, burn_rate = base.burn_rate, defend = base.defend, priorite = base.priorite,
    ia3 = { K = K, active = n_active, productive = n_productive, dropped = dropped,
      explore = E.explore, saturated = saturated, dominant = dom and dom.key or nil,
      pay = E.pay }, -- lot CAPITAL : améliorations dont le coût est réservé au stock virtuel, payées par le runtime
  }
end

return C
