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
local Ml = require("shared.ai3.mall") -- lot PILE-MALL
local Am = require("shared.ai3.amorce") -- lot VIDEO L7 : la main reste refusée après la 1re production (verrou de l'amorce)
local R = require("shared.ai3.reglages") -- lot IA-G : ressources clés de repli
local A = require("shared.ai3.automatiser") -- lot IA3-e : modules demandés au plan directeur (projets « module »)
local Bi = require("shared.ai3.bilan") -- lot BILAN : fabrications pondérées par production moins consommation

P.EMIT.module = A.emit(P)
local Cap = require("shared.ai3.capital") -- lot CAPITAL : buts « amélioration » (niveaux, centre), payés par le runtime
P.EMIT.upgrade = Cap.emit(P)
local Ca = require("shared.ai3.capitalisation") -- lot CAPIB : buts de FOND de la capitalisation (réglage fo-war-capi)
local Dm = require("shared.ai3.demande") -- lot C2 : capacités de plus selon les bras libres (puits ouvert)
P.EMIT.capi = Ca.emit(P)
local Gi = require("shared.team.gisement") -- lot GISEMENTS : matières en manque par rapport au besoin
local Fa = require("shared.ai3.famille_armee") -- lot TV-PILOTE (V10) : famille armée à parts réservées
local Pi = require("shared.ai3.pile") -- lot PILE-PRIORITE : réparer + protéger, puis produire, puis améliorer
local Rs = require("shared.ai3.reserve") -- lot INDUSTRIE I1 : le besoin évalué, le reste du stock s'investit
local Fx = require("shared.team.flux") -- lot FLUX : tournée des sorties pleines gardée (règle pure)
local Sp = require("shared.team.spirale") -- EFFONDREMENT : recrue gratuite de votre équipe sous l'effectif de départ
local Sa = require("shared.ai3.saturation") -- lot VIDEO-SAT (V79) : pente mesurée du stock, saturation jugée sur le stock projeté
local ZI = require("shared.ai3.zero_idle") -- lot ZERO-IDLE : agrandissement de fonderie par PNJ libre, tout de suite
local Ad = require("shared.ai3.anti_dispersion") -- lot IA-GARDE : garde anti-dispersion (sur-stockage d'un minerai brut)

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

-- Lot VIDEO-SAT : matières suivies par la pente du stock = celles dont B.saturated est demandé (C.raw_items : 8 sur les données vanilla).
local SAT_ITEMS = sorted_keys((C.raw_items()))

--- État persistant neuf (f.team.ia3) : nombres, chaînes et tables seulement (global).
function C.new_state(tick)
  return { v = 1, since = tick or 0, next_id = 1, projects = {}, targets = {}, short = {}, short_n = {}, need = {},
    ever = {}, log = {}, saturated = {}, explore = {} }
end

--- 1. Situation.
function C.situation(view, st, ctx)
  local cap = {}
  -- Lot C3 EXTENSION : avant-postes par type, avant-postes sous leur cible de tourelles et où un PNJ est mort récemment (shared/ai3/extension.lua).
  local nout, lethal_n = {}, 0
  for _, o in ipairs(view.outposts or {}) do
    nout[o.kind] = (nout[o.kind] or 0) + 1
    if o.lethal then lethal_n = lethal_n + 1 end
  end
  local undef, undef_n = Planner.undefended(view), 0
  for _, o in ipairs(view.outposts or {}) do if undef[o.id] then undef_n = undef_n + 1 end end
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
  -- Lot VIDEO-SAT (V79, étape 4 bis) : un relevé du stock libre par minute (Sa.observe) ; la fonte durable de chaque matière (s.drain) fait
  -- juger sa saturation sur le stock projeté à Sa.H minutes (B.saturated). État st.sat (nombres seulement), créé ici à la première pensée.
  st.sat = st.sat or Sa.new()
  Sa.observe(st.sat, ctx.tick or 0, view.stock or {}, SAT_ITEMS)
  return {
    is_player = ctx.is_player or false, workers = view.workers or 0, soldiers = view.soldiers or 0,
    soldiers_max = view.soldiers_max or 0, stock = view.stock or {}, cap = cap, pending = view.pending or {},
    army_cap = view.army_cap or 0, -- lot DEPENSES2 (R1) : plafond des factions, celui de l'armée de votre équipe (B.generate)
    sites = view.sites or {}, sites_near = view.sites_near or {}, nout = nout, undef_n = undef_n, lethal_n = lethal_n,
    threatened = view.threatened or false, expansion = ctx.expansion or 0, dominant = ctx.dominant or false,
    desired = ctx.desired, extension = ctx.industrie or false, room = room, smelters = view.smelters or 0, smelters_pending = view.smelters_pending or 0,
    -- Intégration 0.6.20 (SCALE-COMPLET x PLAFOND-FOREUSES) : l'équipe recrute encore vers son effectif voulu (lecteur : B.generate,
    -- buts de couverture).
    recruiting = (view.workers or 0) < (view.workers_wanted or 0) and not view.recruit_blocked and not view.recruit_held
      and not view.hold_recruits,
    weights = ctx.weights or {}, research = ctx.research, army_target = ctx.army_target or 0, need = st.need,
    army_alert = view.army_alert or false, army_need = view.army_need or 0, -- lot ARMEE-ANTICIPATION : vague annoncée (B.goals)
    at_war = ctx.at_war or view.threatened or false,
    ammo_reserve = ctx.ammo_reserve or 0, -- lot S1 : réserve de chargeurs voulue d'après la menace reçue (B.generate)
    -- Lot MUNITIONS : tourelles de l'équipe et chargeurs qui leur manquent pour leur cible (view.turret_groups, Mu.group) : le stock visé au
    -- coffre les suit (B.generate, Mu.stock_target). nil : vue sans ce relevé (règle d'avant).
    turrets_n = C.turrets_seen(view).n, ammo_missing = C.turrets_seen(view).missing,
    turret_ammo = view.turret_ammo, -- lot MUNITIONS : munition choisie (la meilleure fabricable) ; nil : munition de base
    -- Lot IA-V2 : l'économie est « faite » au fer II de l'ancienne échelle OU quand un avant-poste de fer tourne et que
    -- le fer est SATURÉ (st.economy_ok, collant) : le cerveau par besoins ne bâtit pas un 2e avant-poste de fer qui ne
    -- sert à rien, et la recherche restait plafonnée pour toujours (moteur réel, ia3c-reduit et ia3c-default graine
    -- 20261020 : fer II jamais, 2 700 plaques de fer au coffre, paliers 2 et 3 à 29 et 48 min à 8 PNJ).
    economy_done = st.iron2_done ~= nil or st.economy_ok ~= nil,
    -- Lot IA-G : ressources clés DÉDUITES du dépliage des buts (script/ai3/general.lua) ; repli : celles de l'échelle.
    key = (ctx.key and ctx.key.top and ctx.key.fuel) and ctx.key or R.FALLBACK_KEY,
    idle_grow = ctx.idle_grow or false, tick = ctx.tick or 0, -- lot IA-G : bras libres
    spare = ctx.spare, -- lot SCALE : nombre de bras libres durables (vague d'extraction d'avance, shared/ai3/bras.lua)
    -- Lot C2 : puits ouvert (écrit par la capitalisation, f.team.ia3.puits) : débit de chaque matière (saturation relative) et capacités de
    -- plus selon les bras libres.
    puits_flow = st.puits and st.puits.flow or nil, extra_cap = Dm.extra_cap(st.puits ~= nil, ctx.spare),
    drain = Sa.drains(st.sat), -- lot VIDEO-SAT : { [matière] = fonte durable par minute } (shared/ai3/saturation.lua)
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
  -- Lot PREVISION (relecture de la revue) : l'armée visée à MOYEN terme (view.army_soon) est un PROJET du cerveau (cible unique
  -- army_target, script/ai3/cerveau.lua, servie par B.goals) ; le planificateur permanent ne la recrute pas une seconde fois.
  local vb = setmetatable({ ladder = {}, no_research = true, done = done, deferred = {}, army_soon = false }, { __index = view })
  return vb
end

--- Lot MUNITIONS : tourelles de l'équipe et chargeurs manquants (sommes de view.turret_groups ; nil sans le relevé `missing`).
function C.turrets_seen(view)
  local n, missing, seen = 0, 0, false
  for _, g in ipairs(view.turret_groups or {}) do
    if g.missing ~= nil then
      seen = true
      -- (part URGENTE seulement : jusqu'à la cible ordinaire ; le surplus de la cible riche n'entre jamais dans le stock visé au coffre)
      n, missing = n + (g.n or 0), missing + (g.missing_base or g.missing)
    end
  end
  if not seen then return {} end
  return { n = n, missing = missing }
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
      local g = groups[t.group] -- lot MUNITIONS : ce que la tournée porte (t.count), sinon le manque du groupe, sinon la règle d'avant
      local a = view.turret_ammo or T.turret_ammo
      used[a] = (used[a] or 0) + (t.count or g.missing or g.low * T.turret_ammo_target)
    end
  end
  -- Lot DEFENSE-AP : fonds de défense (planificateur, Ga.fund) : le fer mis de côté pour la tourelle d'un avant-poste de fer sans défense n'est pas
  -- au stock libre des projets du cerveau (chargeurs de réserve, modules, science).
  for _, k in ipairs(sorted_keys(base.defense_hold or {})) do used[k] = (used[k] or 0) + base.defense_hold[k] end
  -- Lot CC-COMBUSTIBLE (partie du DC du 10/11, graine 3592985581) : le charbon des tournees des bruleurs, reserve par le planificateur
  -- (base.fuel_reserve, shared/team/planner.lua), n'est plus au stock virtuel des projets : avant, agrandissements (zero-idle, projets)
  -- et fabrications prenaient ce charbon pendant que les bruleurs deja poses restaient a sec (tournees parties a 0 charbon).
  if (base.fuel_reserve or 0) > 0 then used[T.fuel] = (used[T.fuel] or 0) + base.fuel_reserve end
  -- EFFONDREMENT : une recrue gratuite (base.recruit_free) ne prend rien au stock virtuel.
  if base.recruit_workers and not base.recruit_unarmed and not base.recruit_free then add(base.recruit_uses or view.recruit_cost) end
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
  st.defense_hold = base.defense_hold -- (lecteur : le stock libre du mall, script/ai3/industrie.lua)
  local avail = {}
  for _, k in ipairs(sorted_keys(view.stock)) do avail[k] = view.stock[k] end
  for _, k in ipairs(sorted_keys(view.incoming)) do avail[k] = (avail[k] or 0) + view.incoming[k] end
  for _, k in ipairs(sorted_keys(used)) do avail[k] = math.max(0, (avail[k] or 0) - used[k]) end
  local avail0 = {}
  for k, v in pairs(avail) do avail0[k] = v end
  -- 2 bis. Lot PILE-PRIORITE : la pile de priorité de l'équipe (shared/ai3/pile.lua), recalculée à chaque pensée depuis le
  -- planificateur permanent (postes sous leur minimum, manques bruts et leur priorité) et le runtime (ctx.pile : pièces
  -- détruites du registre, projet du plan directeur rouvert ; script/team/pile.lua). État dans st.pile (global).
  st.pile = st.pile or Pi.new()
  -- Lot PILE-BUDGET : améliorations au coût CONNU (liste d'objets), dans un ordre stable ; le budget se lit sur le stock libre.
  local ups = {}
  if ctx.capital and ctx.capital.cost then ups[#ups + 1] = { key = ctx.capital.key or "capital", cost = ctx.capital.cost } end
  local capi_open = {}
  for _, o in ipairs((ctx.capi and ctx.capi.open) or {}) do
    if o.key and o.kind ~= "techno" and o.missing and #o.missing > 0 then capi_open[#capi_open + 1] = o end
  end
  table.sort(capi_open, function(x, y) return tostring(x.key) < tostring(y.key) end)
  for _, o in ipairs(capi_open) do ups[#ups + 1] = { key = "capi:" .. tostring(o.key), cost = o.missing } end
  local sig = Pi.signals(view, base, ctx.pile, s, ctx, R.PILE_BUDGET and { book = book, avail = avail0, upgrades = ups } or nil)
  local pile = Pi.update(st.pile, sig, tick)
  -- Lot INDUSTRIE I1 (réglage fo-war-industrie, ctx.industrie) : le BESOIN de cette pensée est évalué sur le stock que voit la
  -- capitalisation (view.stock) ; elle investit le reste (shared/ai3/reserve.lua). Lu à la pensée suivante (Capi.think précède C.think).
  if ctx.industrie then
    local floor = (view.emergency and view.emergency.floor) or view.recover_floor
    local eff = view.effectif
    local n_rec, rec = Rs.recruits({ workers = view.workers, wanted = view.workers_wanted, floor = floor, blocked = view.recruit_blocked,
      held = view.recruit_held, reason = eff and eff.reason or nil, cost = Sp.cost(view, view.recruit_cost), -- EFFONDREMENT : gratuite sous le départ
      margin = eff and eff.margin_item and { eff.margin_item, eff.margin } or nil })
    st.noyau = Rs.state(book, view.stock, { posts = sig.posts, repair = sig.repair, plan_wants = sig.plan_wants,
      planned = used, recruit = rec, production_first = sig.production_first, raw_need = sig.raw_need,
      -- Intégration 0.6.33 : la réserve de chargeurs sur la menace (lot S1) est du besoin : ni les blocs d'I1 ni le puits de C2 n'en prennent le fer
      ammo = (ctx.ammo_reserve or 0) > 0 and { { T.turret_ammo, ctx.ammo_reserve } } or nil,
      -- Lot S1 : les packs de la recherche de la tourelle sont du besoin (les blocs de l'industrie n'en prennent pas le fer)
      research = (ctx.research and ctx.research.for_defense) and ctx.research.packs or nil }, tick)
    st.noyau.recruits = n_rec
  else
    st.noyau = nil
  end
  s.focus = pile.hold and pile.focus or nil -- lu par B.targets : une matière d'un cadre ouvert fait grandir son extraction
  -- Intégration 0.6.28 : matières en manque que la porte de la pile laisse passer, au stock de CETTE pensée (G.passent : un cadre ouvert plus en manque passe d'abord)
  local starved_pass = Gi.passent(Gi.penurie(Gi.rows(T.OUTPOST_ORDER, T.outposts, sorted_keys(T.smelter_inputs), view.stock, st.need)), pile.focus)
  -- 3. Buts ; 4. projets.
  local goals = A.goals(B.generate(s, st), ctx.auto, s.weights, s.research) -- lot IA3-e : modules demandés = projets
  -- Lot ZERO-IDLE (DC, 8/11) : PNJ libres et stock qui paie un kit de fonderie (foreuses + fours) : un agrandissement par PNJ libre, tout
  -- de suite, en FOND (shared/ai3/zero_idle.lua) ; ni la saturation, ni les capacités visées, ni la capitalisation ne le retiennent.
  if ZI.ON then
    local zres = ZI.decide(ZI.input(view, s, book, avail0, ctx, st.covered))
    for _, g in ipairs(ZI.goals(zres)) do goals[#goals + 1] = g end
    st.zi_last = ZI.summary(zres) -- relu par le runtime (script/ai3/zero_idle_rt.lua) : ligne [FO-ZERO-IDLE] de la minute
  else
    st.zi_last = nil
  end
  -- Lot CAPITAL : le but « amélioration » choisi par le runtime (valeur ÷ coût, shared/ai3/capital.lua), factions seulement.
  -- Lot PILE-PRIORITE : suspendu tant qu'un cadre de rang inférieur retient (il ne réserve plus sa matière, audit A3).
  -- Lot AGES : le centre dont le gel est levé (shared/team/degel.lua, ctx.thaw) passe la retenue de la pile ; lui seul.
  if ctx.capital and (Pi.allows(pile, "capital") or (ctx.thaw and ctx.capital.center)) then goals[#goals + 1] = ctx.capital
  elseif ctx.capital then Pi.suspend(pile, ctx.capital.key or "capital", "amelioration (capital) suspendue") end -- journal [FO-PILE]
  -- Lot CAPIB : un but de FOND par ordre ouvert de la capitalisation (ses exécutants ont reçu l'ordre au runtime ; le but
  -- fait ce qui leur manque, sur la part capi du stock virtuel).
  -- Lot PILE-PRIORITE : pile retenue, seuls ses INVESTISSEMENTS de production (g.invest : capacité d'une matière en manque)
  -- restent ; le reste de la capitalisation attend.
  if ctx.capi then
    if Pi.allows(pile, "capi") then Ca.goals(goals, nil, ctx.capi.open)
    else
      local held = {}
      Ca.goals(held, nil, ctx.capi.open)
      for _, g in ipairs(held) do
        -- Lot GISEMENTS : un ordre qui étend une matière en manque par rapport au besoin est un investissement de production, même sans
        -- manque brut (journal du DC : « capi:couvrir:copper-ore : suspendu » à 45 plaques de cuivre).
        local sv, ord = starved_pass, g.order or {}
        -- décision du DC du 8/11 : couvrir et ouvrir un gisement passent TOUJOURS (leurs manques sont fabriqués aussi)
        if g.invest or Pi.COVER_KINDS[ord.kind] or sv[ord.item] or sv[ord.resource] then goals[#goals + 1] = g
        else Pi.suspend(pile, g.key, "but de la capitalisation suspendu (pas un investissement de production)") end -- journal [FO-PILE]
      end
    end
  end
  -- Intégration 0.6.20 (SCALE-COMPLET x PILE-PRIORITE, rapport de SCALE-COMPLET §7) : la COUVERTURE (but de fond au-delà du
  -- besoin, « couverture:<type> », B.generate) passe elle aussi par la pile : réparer, protéger et survivre d'abord ; une
  -- matière d'un cadre ouvert (pile.focus) garde la sienne.
  -- Lot FUITES-PILE (fuite b) : un MODULE NEUF du plan directeur (but « auto:<produit> », famille g.pile capital, capi, invest ou
  -- migration, shared/ai3/automatiser.lua) est une amélioration : suspendu pendant la retenue, sauf s'il produit une matière d'un
  -- cadre ouvert ou une matière qui manque (Pi.porte) ; un module EN RECONSTRUCTION (g.pile = "reparer") passe toujours. Avant, les
  -- deux étaient des buts « capital » que la pile ne lisait pas : le cerveau fabriquait les fours d'une fonderie de cuivre neuve
  -- pendant que le QG manquait de tourelles.
  if pile.hold then
    local kept = {}
    -- (relecture : manques PROPRES de la pensée précédente, sans ceux des améliorations elles-mêmes, Pi.short_core ; une sauvegarde
    -- d'avant la relecture n'en a pas encore : aucune exception pendant une pensée)
    local short_prev = st.short_core or {}
    -- Lot GISEMENTS : une matière qui manque PAR RAPPORT AU BESOIN (stock de la matière et de sa plaque, st.starved) compte aussi, même
    -- quand aucun manque brut ne la nomme (cuivre à 45 plaques, fer à 9 300 : short_core ne portait que le brut des projets)
    local starved_prev = starved_pass
    for _, g in ipairs(goals) do
      local keep = true
      if type(g.key) == "string" and g.key:sub(1, 11) == "couverture:" then
        local sp = T.outposts[g.outpost]
        keep = Pi.allows(pile, "extraction", g.why) or (sp ~= nil and starved_prev[sp.product] == true) -- lot GISEMENTS : une matière en manque
      elseif g.releve and g.releve ~= "manque" then
        -- Intégration 0.6.32 (C3 x PILE-PRIORITE) : un nouveau site sans manque durable (« plein », « posture », « extension ») attend comme la
        -- couverture : réparer, protéger et survivre d'abord. Sans cela, « plein » (valeur jusqu'à 100) passait AVANT l'armée et les munitions.
        keep = Pi.allows(pile, "extraction", g.why) or starved_prev[g.why] == true
        if not keep then Pi.suspend(pile, g.key, "releve (" .. tostring(g.releve) .. ") : la pile d'abord") end
      elseif g.kind == "module" and g.pile then
        local it = g.item or g.product -- lot CHAMP : une bande du champ est jugée sur sa plaque, pas sur l'étiquette de son but
        local ok, why = Pi.porte(pile, g.pile, it, ((short_prev[it] or 0) > 0) or starved_prev[it] == true)
        if not ok then
          keep = false
          Pi.suspend(pile, g.key, "module neuf du plan directeur (" .. tostring(g.pile) .. ") : " .. tostring(why))
        end
      end
      if keep then kept[#kept + 1] = g end
    end
    goals = kept
  end
  -- Lot IA-GARDE (règle du DC, 11/11) : garde fermée (sous 2 colonnes de fonderie automatisées et 6 assembleurs actifs, ctx.dispersion posé
  -- par script/ai3/anti_dispersion.lua) : un but AU-DELÀ du besoin (« couverture:<type> », relève sans manque) d'un minerai BRUT est retiré,
  -- sauf si sa matière manque par rapport au besoin ; « extraction:<type> » (capacités visées) et la relève pour manque passent.
  st.ad_inhibe = nil
  local disp = ctx.dispersion
  if disp and not disp.ouvert then
    local kept, n = {}, 0
    for _, g in ipairs(goals) do
      local au_dela = type(g.key) == "string" and (g.key:sub(1, 11) == "couverture:" or (g.releve ~= nil and g.releve ~= "manque"))
      local ok = true
      if au_dela and g.outpost then
        local sp = T.outposts[g.outpost]
        ok = Ad.permet(disp, "surstock", { sorte = (disp.sortes or {})[g.outpost], manque = sp ~= nil and starved_pass[sp.product] == true })
      end
      if ok then kept[#kept + 1] = g else n = n + 1 end
    end
    goals = kept
    if n > 0 then st.ad_inhibe = n end -- relu par script/ai3/cerveau.lua (journal [FO-ANTI-DISPERSION])
  end
  -- Lot PILE-PRIORITE (le cerveau principal aussi) : pile retenue, une recherche CHÈRE ne dépasse pas B.RESEARCH_PRE (sous
  -- l'extraction et l'armée de départ) ; une recherche peu chère (g.short) ou attendue par l'automatisation garde sa valeur.
  if not Pi.allows(pile, "recherche") then
    for _, g in ipairs(goals) do
      if g.family == "recherche" and g.kind == "research" and not g.short and g.value > B.RESEARCH_PRE
        and not (s.research and s.research.for_auto) then g.value = B.RESEARCH_PRE end
    end
  end
  local order, K = P.update(st, goals, tick, s.workers)
  -- 5. Dépliage.
  local E = P.context(avail, book, view, st)
  E.base_used = used -- étage CIRCUITS : ce que le planificateur permanent a pris (Cap.ahead_clamp)
  E.priorite = base.priorite -- lot PRIORITE-RESSOURCES : production d'abord quand le fer ne paie pas la défense et la production
  -- Lot PILE-PRIORITE : les manques des rangs R0 et R1 (fer des tourelles, survie, reconstruction d'un avant-poste) entrent
  -- dans E.raw AVEC leur priorité : P.supply en fait la fonte, le minage par plusieurs PNJ, l'exploration ; st.short_n en fait
  -- la croissance de l'extraction (B.targets) : « pour protéger […] construire une usine, aller chercher un nouveau gisement ».
  -- Leur fonte n'est pas comptée deux fois (base.smelt les portait déjà).
  local pile_proj = { id = 0, key = "pile:proteger" }
  for _, k in ipairs(sorted_keys(pile.short)) do P.short_raw(E, pile_proj, k, pile.short[k].n, pile.short[k].prio) end
  for k, n in pairs(base.smelt or {}) do if not pile.short[k] then E.smelt[k] = n end end
  -- Pièces à refaire : leur objet au stock leur est gardé AVANT les projets (audit M7) ; l'objet qui manque est fabriqué au
  -- rang R1 (audit M4 : « perte sans objet » n'était ni fabriquée ni demandée), sa matière héritant de la priorité de la pièce.
  for _, it in ipairs(pile.reserve or {}) do E.avail[it[1]] = math.max(0, (E.avail[it[1]] or 0) - it[2]) end
  local repair_proj = { id = 0, key = "pile:reparer" }
  local pile_c0 = E.crafts
  -- lot RUINES-ATTENTE (partie neuve 20261020, [FO-PILE] « craft de pile » : foreuse de fer demandée x3 à x24, « parties 0 » pendant 25 min, fer qui manque
  -- alors que le coffre en tient) : la fabrication qui refait l'EXTRACTION de la plaque clé (it[4]) est payée sur le stock AVANT les consommations du
  -- plan permanent (used : tourelles, munitions, fonds de défense, recrues), sans fer il n'y a plus de défense. Ce qu'elle prend est ensuite retiré du
  -- stock libre du reste (le plan permanent garde son dû sur ce qui reste) ; la foreuse fabriquée n'est pas comptée deux fois.
  for _, it in ipairs(pile.crafts or {}) do
    if it[4] then
      local pre = {}
      for _, k in ipairs(sorted_keys(view.stock)) do pre[k] = view.stock[k] end
      for _, k in ipairs(sorted_keys(view.incoming or {})) do pre[k] = (pre[k] or 0) + view.incoming[k] end
      for _, r in ipairs(pile.reserve or {}) do pre[r[1]] = math.max(0, (pre[r[1]] or 0) - r[2]) end
      local pre0 = {}
      for _, k in ipairs(sorted_keys(pre)) do pre0[k] = pre[k] end
      local saved = E.avail
      E.avail = pre
      P.want(E, repair_proj, { { it[1], it[2] } }, it[3], false, "pile")
      E.avail = saved
      for _, k in ipairs(sorted_keys(pre0)) do
        local paid = pre0[k] - (pre[k] or 0)
        if paid > 0 and k ~= it[1] then saved[k] = math.max(0, pre0[k] - paid - (used[k] or 0)) end
      end
    else
      P.want(E, repair_proj, { { it[1], it[2] } }, it[3], false, "pile")
    end
  end
  -- trace (lecture seule, lue par script/team/pile.lua PileRt.journal) : ce que la pile a demandé de fabriquer, ce qui est parti, ce qui manque
  do
    local wants, short = {}, {}
    for _, it in ipairs(pile.crafts or {}) do wants[#wants + 1] = it[1] .. " x" .. it[2] .. " (stock libre " .. (E.avail[it[1]] or 0) .. ")" end
    for _, k in ipairs(sorted_keys(repair_proj.missing or {})) do
      short[#short + 1] = string.format("%s %d (coffre %d, en route %d, pris par le plan permanent %d dont fonds de defense %d, libre au depart %d)", k, repair_proj.missing[k],
        view.stock[k] or 0, (view.incoming or {})[k] or 0, used[k] or 0, (base.defense_hold or {})[k] or 0, avail0[k] or 0)
    end
    st.pile.craft_note = string.format("fabrications demandees [%s], parties %d, matiere qui manque [%s]", table.concat(wants, ", "), E.crafts - pile_c0,
      table.concat(short, ", "))
  end
  P.boot_smelters(E, st, s.cap) -- lot IA-V2 : fours du QG avant les projets (chemin critique)
  -- Ordre de SERVICE du stock virtuel : une COPIE de l'ordre (l'ordre d'origine garde le projet dominant, plus bas ; relecture de
  -- 16f1b3e0, point 1). Lot DEFAUT7 : l'amélioration exigée par le centre (chaîne Q16) servie d'abord ; étage 3 : le centre passé
  -- devant servi en tête, après les seuls projets qui produisent la matière qui lui manque (Cap.ahead_first).
  local served = Cap.ahead_first(Cap.chain_first(order), E.avail, T.outposts, T.smelter_inputs)
  -- Lot TV-PILOTE (V10) : FAMILLE ARMÉE à parts réservées (shared/ai3/famille_armee.lua). ctx.armee = { parts = { delta, alpha } } posé par le
  -- runtime quand le réglage fo-war-armee-famille est allumé (nil : la boucle d'avant, ligne pour ligne). La réserve de la famille (munitions et
  -- équipement des soldats, UNE liste) est prêtée aux projets qui n'en sont pas : ils servent le stock MOINS la réserve ; les membres le voient entier.
  local famres = nil
  if ctx.armee then
    local share, share_why = Fa.share(ctx.armee.parts)
    famres = Fa.reserve(E.avail, Fa.wants(goals, function(g) return P.army_kits(view, g) end),
      function(list) return E.book:plan(list, E.avail).raw end, share, share_why)
  end
  for _, proj in ipairs(served) do
    if famres and next(famres.left) ~= nil then
      if Fa.member(proj.goal) then
        local before = Fa.snapshot(E.avail, famres.left)
        P.emit(E, proj, ctx, tick)
        Fa.spend(famres.left, before, E.avail) -- ce que la famille a consommé n'est plus retenu pour les projets suivants
      else
        local taken = Fa.lend(E.avail, famres.left, false)
        P.emit(E, proj, ctx, tick)
        Fa.restore(E.avail, taken)
      end
    else
      P.emit(E, proj, ctx, tick)
    end
  end
  -- 6. Approvisionnement.
  local raw, minable = C.raw_items()
  -- Lot KIT : matières naturelles récoltables (le bois des poteaux, lu par le runtime sur les arbres) : à miner à la main
  -- comme un minerai, quand elles sont à portée (ctx.reach) ; sans arbre à portée, elles restent « inaccessibles ».
  local trees = {} -- lot ELECTRIQUE (d) : matières récoltées sur les arbres (tâche de minage marquée `trees`, votre équipe comprise)
  for _, k in ipairs(ctx.harvest or {}) do raw[k] = true minable[k] = true trees[k] = true end
  P.supply(E, { reach = ctx.reach, known = ctx.known, workers = s.workers, mines_open = ctx.mines_open, minable = minable, trees = trees,
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
  -- Lot PILE-MALL : ce que la main fabrique souvent (planificateur permanent et projets) devient la liste du mall (shared/ai3/mall.lua).
  if R.PILE_MALL then
    st.mall = st.mall or Ml.new()
    local now = {}
    for _, list in ipairs({ base.tasks or {}, E.tasks or {} }) do
      for _, t in ipairs(list) do
        if t.kind == "craft" and t.kit then -- lot POSE-PAR-LOTS : toutes les pièces d'un kit
          for _, w in ipairs(t.kit) do now[w[1]] = (now[w[1]] or 0) + w[2] end
        elseif t.kind == "craft" and t.item and (t.count or 0) > 0 then now[t.item] = (now[t.item] or 0) + t.count end
      end
    end
    Ml.note(st.mall, tick, now)
    Ml.decide(st.mall, book, { have = view.stock })
    -- Relecture : la main ne refait plus ce que le mall produit (après Ml.note : la demande reste comptée ; défense et réparations gardent la main).
    base.tasks = Am.filter_crafts(st.mall, base.tasks, view.stock, Pi.INJECT_PRIO, Ml) -- lot VIDEO L7 (Ml.filter_crafts + verrou)
    E.tasks = Am.filter_crafts(st.mall, E.tasks, view.stock, Pi.INJECT_PRIO, Ml)
  end
  -- Relecture FUITES-PILE : manques propres (sans ceux des améliorations hors des cadres ouverts), lus par la porte de la pile
  st.short_core = Pi.short_core(E.raw, order, pile.focus)
  st.need = st.need or {}
  for _, k in ipairs(sorted_keys(raw)) do
    local use = math.max(0, (avail0[k] or 0) - (E.avail[k] or 0))
    local now = use + (short[k] or 0)
    local kept = math.floor((st.need[k] or 0) * C.NEED_DECAY_PCT / 100)
    local v = now > kept and now or kept
    st.need[k] = v > 0 and v or nil
  end
  -- Lot GISEMENTS : matières en manque PAR RAPPORT AU BESOIN, toutes (fondues ou non) : stock du minerai et de sa plaque contre le besoin
  -- de la matière (plancher : la moitié du plus grand besoin, une matière oubliée manque quand même). Lu par la porte de la pile.
  -- (par TYPE d'avant-poste : les clés de T.outposts ne sont pas des objets, relecture : seuls « coal » et « stone » y tombaient par homonymie)
  local pen = Gi.penurie(Gi.rows(T.OUTPOST_ORDER, T.outposts, sorted_keys(T.smelter_inputs), view.stock, st.need))
  st.starved = pen.starved
  st.starved_rank = pen.ranking
  st.starved_open = Gi.passent(pen, pile.focus) -- lu par la porte du runtime (script/team/pile.lua) et la menace (script/ai3/capitalisation.lua)
  local saturated, held, lifted = {}, {}, {}
  for _, k in ipairs(sorted_keys(raw)) do
    if (view.stock[k] or 0) > 0 then
      local sat, why = B.saturated(s, k)
      if sat then saturated[k] = true
      else
        -- Lot VIDEO-SAT : au-dessus du seuil, mais le stock fond : la saturation est LEVÉE (fonte par minute, arrondie : journal [FO-SAT]).
        if why == "pente" then lifted[k] = math.floor(s.drain[k] + 0.5) end
        if s.puits_flow and B.saturated(s, k, true) then held[k] = true end -- lot C2 : saturée contre le plancher seul, tenue ouverte par le puits
      end
    end
  end
  st.saturated = saturated
  st.sat_held = held
  st.sat_lifted = lifted -- lot VIDEO-SAT : lu par le journal [FO-SAT] (script/ai3/cerveau.lua)
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
  local product_of, row_of = {}, {}
  for _, o in ipairs(view.outposts or {}) do product_of[o.id] = T.outposts[o.kind].product; row_of[o.id] = o end
  local tasks, keys = {}, {}
  local dropped, kept_unmeasured = 0, 0
  -- Lot IA3-e : « fini retire du travail à la main le débit nominal » : les tournées ordinaires (sous les urgences) des
  -- avant-postes dont le produit est COUVERT par un module fini sont retirées (le module livre ce flux).
  local covered = (ctx.auto and ctx.auto.covered) or {}
  st.covered = covered
  -- Lot PILE-PRIORITE : le minage d'appoint du planificateur (25 ou 45) d'une matière reprise par la pile est retiré quand le
  -- cerveau par besoins mine déjà cette ressource à la priorité héritée (les urgences à 90 restent).
  local ia3_mined = {}
  for _, t in ipairs(E.tasks) do if t.kind == "mine" and t.resource then ia3_mined[t.resource] = true end end
  local pile_mined = {}
  for _, k in ipairs(sorted_keys(pile.short)) do
    pile_mined[k] = true
    if T.smelter_inputs[k] then pile_mined[T.smelter_inputs[k][1]] = true end
  end
  for _, t in ipairs(base.tasks or {}) do
    local prod = product_of[t.outpost] or ""
    local drop = (other_short and t.kind == "service" and t.prio < 90 and saturated[prod])
      or (t.kind == "service" and t.prio < 90 and covered[prod])
      or (t.kind == "mine" and t.prio < 90 and t.resource ~= nil and pile_mined[t.resource] and ia3_mined[t.resource]
        and t.key == "mine:" .. t.resource) or false
    -- Lot FLUX : un produit saturé ou couvert garde la tournée de ses sorties PLEINES (le four s'arrête : 17 fours à 100 plaques de cuivre).
    if drop and t.kind == "service" then
      local why
      drop, why = Fx.drop_service(row_of[t.outpost], drop) -- lot 5b : rangée absente = sorties non mesurées = tournée gardée
      if why then kept_unmeasured = kept_unmeasured + 1 end
    end
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
    recruit_free = base.recruit_free, -- EFFONDREMENT : recrue gratuite (paiement sauté en E4, script/team/team.lua)
    emergency_unarmed = base.emergency_unarmed, emergency_recruit = base.emergency_recruit,
    recruit_blocked = base.recruit_blocked, recruit_held = base.recruit_held, unreachable = E.unreachable,
    grow_short = base.grow_short, -- lot FER-EQUIPE : la réserve de fer a retenu une recrue (journal [FO-FER])
    coal_rate = base.coal_rate, burn_rate = base.burn_rate, defend = base.defend, priorite = base.priorite,
    -- Intégration 0.6.33 : lus par SurvieQg.note_plan (Team.think) ; absents du plan du cerveau, allumé par défaut, les attentes de protection du
    -- lot S1 (reconstruction, agrandissement de survie) ne s'allumaient jamais.
    turret_ok = base.turret_ok, turret_payable = base.turret_payable,
    defchoix = base.defchoix, -- lot DEFENSE-CHOIX : tourelles du QG avant les soldats (journal [FO-DEFCHOIX], script/team/team.lua)
    ia3 = { K = K, active = n_active, productive = n_productive, dropped = dropped, kept_unmeasured = kept_unmeasured,
      explore = E.explore, saturated = saturated, dominant = dom and dom.key or nil,
      pile = { top = pile.top, hold = pile.hold, blocked = pile.blocked }, -- lot PILE-PRIORITE (l'état complet : st.pile)
      armee = famres, -- lot TV-PILOTE (V10) : réserve de la famille armée de cette pensée (journal [FO-ARMEE], script/ai3/cerveau.lua)
      pay = E.pay }, -- lot CAPITAL : améliorations dont le coût est réservé au stock virtuel, payées par le runtime
  }
end

return C
