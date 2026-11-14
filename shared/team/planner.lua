--[[
  CERVEAU D'ÉQUIPE — PUR (aucune API Factorio). Un seul par équipe : il sait ce qu'il reste à faire et
  comment le faire ; les ouvriers exécutent ses tâches.

  P.plan(view, book) renvoie :
    goal     = clé de l'objectif poursuivi (premier palier non atteint de T.ladder), nil si échelle gravie
    reached  = { clé, ... } paliers atteints à cette pensée (mémorisés par l'appelant : jamais réouverts)
    missing  = { {objet, n}, ... } ce qui manque pour l'objectif (affichage « il manque »)
    tasks    = { tâche, ... } triées par priorité décroissante ; une tâche = { key, kind, prio, ... }
    site_needs = { [type d'avant-poste] = n } sites à prospecter
    research = niveau dont les packs sont au stock (le runtime les consomme), ou nil
    smelt    = { [produit] = n } production demandée à la fonderie du QG

  view = {
    tech, personality, done = { [clé] = true },
    stock = { [objet] = n }, incoming = { [objet] = n },     -- QG ; fabrications en cours
    outposts = { { id, kind, drills, turrets, fuel_low, output, idle_ticks, has_task }, ... },
    pending = { [type] = n }, sites = { [type] = n },
    smelters = n, smelters_pending = n, smelter_task = bool, smelter_output = n, smelter_fuel_low = bool,
    turret_groups = { { key, low, has_task }, ... },
    soldiers, soldiers_max, workers, workers_max, threatened,
    open = { [clé de tâche] = true },                       -- tâches en cours (affectées)
  }

  Priorités : 95 ravitaillement urgent > 90 munitions des tourelles > 80 objectif (pose) > 70 entretien >
  60 fonderie > 55 ouvriers > 50 objectif (fabrication) > 45 armée > 40 recherche > 30 minage d'appoint.
]]

local T = require("shared.team.config")
local F = require("shared.faction.config") -- drapeau `rocket` : soldat à attaque de zone (lot GRENADES)
local Guard = require("shared.team.garde_centrale") -- lot CENTRALE-GARDE : tourelles armées autour de la centrale
local Pr = require("shared.team.priorite") -- lot PRIORITE-RESSOURCES : production avant défense quand le fer ne paie pas les deux
local Fr = require("shared.team.front") -- lot DEFENSE-FACTIONS : planchers du front, commande partielle (constantes de ce module)
local Dsr = require("shared.team.defense_stock") -- lot DEFENSE-STOCK : tourelles du coffre posées en groupes (règle pure)
local V = require("shared.faction.valeur") -- lot SITE-PROCHE : V.extension_refused (R1)
local Dc = require("shared.team.defchoix") -- lot DEFENSE-CHOIX : tourelles du QG avant les soldats quand la base est menacée
local Ga = require("shared.team.garde_ap") -- lot DEFENSE-AP : garde d'avant-poste, assurance du QG, fonds de défense
local Sq = require("shared.team.survie_qg") -- lot S1 : QG en péril (planchers réduits, tourelles voulues, remplissage partiel)
local Pt = require("shared.team.premiere_tourelle") -- lot EQUIPE : premier palier de la défense du QG (planchers réduits sous P.FIRST_N tourelles)
local Fx = require("shared.team.flux") -- lot FLUX : priorité des tournées d'avant-poste (règle pure)
local Bc = require("shared.team.bilan_charbon") -- lot PURGE-FER-CHARBON : plafond du combustible (Bc.room)
local Th = require("shared.team.thermique") -- lot THERMIQUE2 (essai 3) : plus de brûleur pour un minerai brut plein (Th.raw_full)
local Mu = require("shared.team.munitions") -- lot MUNITIONS : recharge au plein, partielle, des tourelles (règle pure)
local Sp = require("shared.team.spirale") -- EFFONDREMENT (décision du DC, 7/11) : recrue gratuite sous l'effectif de départ

local P = {}

local MAX_CRAFT_TASKS = 8
local CHUNK_SECONDS = 30
local MINE_BATCH = 50
local VITAL = Fx.vital(T.outposts, T.fuel, T.smelter_inputs) -- lot FLUX : types d'avant-poste dont le ravitaillement passe en tête
local Sm = require("shared.team.sorties_main") -- lot CHARBON-MAIN : sorties brutes rapportées avant de miner à la main
local RAW = Sm.raw_kinds(T.outposts)
local MINE_MIN = 20 -- une sortie de minage rapporte au moins 20 minerais (9 plaques manquantes : 9 minerais, trop peu)

local function sorted_uses(uses)
  local ks = {}
  for k in pairs(uses) do ks[#ks + 1] = k end
  table.sort(ks)
  local out = {}
  for _, k in ipairs(ks) do out[#out + 1] = { k, uses[k] } end
  return out
end

-- Matières premières : d'où elles viennent quand le livre ne sait pas les fabriquer à la main.
local SOURCE = {
  ["coal"] = { outpost = "coal", mine = "coal" },
  ["stone"] = { outpost = "stone", mine = "stone" },
  ["iron-ore"] = { mine = "iron-ore" },
  ["copper-ore"] = { mine = "copper-ore" },
  ["iron-plate"] = { outpost = "iron", smelt = "iron-plate", mine = "iron-ore" },
  ["copper-plate"] = { outpost = "copper", smelt = "copper-plate", mine = "copper-ore" },
  ["steel-plate"] = { smelt = "steel-plate" },
  ["stone-brick"] = { smelt = "stone-brick" },
}

local function count_kind(view, kind)
  local n = 0
  for _, o in ipairs(view.outposts) do if o.kind == kind then n = n + 1 end end
  return n
end

--- Capacité d'extraction d'un type, en « avant-postes équivalents » (foreuses / foreuses par avant-poste).
local function capacity(view, kind)
  local drills = 0
  for _, o in ipairs(view.outposts) do if o.kind == kind then drills = drills + o.drills end end
  return drills / T.outposts[kind].drills
end

--- Avant-poste de ce type qui peut encore s'agrandir (le plus proche du QG d'abord, lot SITE-PROCHE), ou nil. Lot IA1-b2 (défendre d'abord) :
--- un avant-poste de `undefended` (moins de tourelles que T.defend_turrets) ne s'agrandit pas.
local function extendable(view, kind, undefended)
  -- Lot SITE-PROCHE (R1, relecture) : le plus PROCHE du QG (`d2`, à égalité le plus ancien), et pas celui qu'un site
  -- admissible connu bien plus près doit remplacer (V.extension_refused, `view.sites_near`, factions seulement). Ce chemin
  -- (charbon sous 1,4 × la consommation, goulot de plaques) agrandissait encore l'avant-poste de charbon à 201 tuiles.
  local near = view.sites_near and view.sites_near[kind] or nil
  local best, best_d2
  for _, o in ipairs(view.outposts) do
    if o.kind == kind and not o.full and o.drills < T.max_drills(kind) and not (undefended and undefended[o.id]) then
      local d2 = o.d2 or 0
      if (near == nil or not V.extension_refused(math.sqrt(d2), near)) and (best == nil or d2 < best_d2) then best, best_d2 = o, d2 end
    end
  end
  return best
end

--- Lot IA1-b2 : avant-postes NON défendus (moins de tourelles que T.defend_turrets(foreuses)), { [id] = vrai } ; vide si
--- la vue ne demande pas « défendre d'abord » (view.defend_first nil : règle d'avant).
function P.undefended(view)
  local out = {}
  if not view.defend_first then return out end
  for _, o in ipairs(view.outposts or {}) do
    if (o.turrets or 0) < T.defend_turrets(o.drills) then out[o.id] = true end
  end
  return out
end

--- Lot IA1-b2 : avant-postes où PERSONNE NE VA travailler (agrandir, fond), { [id] = vrai } : non défendus quand une
--- tourelle est possible (`turret_ok` : au stock ou fabricable), et, tourelle possible ou non, non défendus MEURTRIERS
--- (un PNJ tué en y allant il y a moins de T.lethal_ticks). Vide sans view.defend_first.
function P.no_go(view, turret_ok)
  local out = {}
  local und = P.undefended(view)
  for _, o in ipairs(view.outposts or {}) do
    -- lot FORCE-0674 (DC) : la plaque clé en famine s'agrandit avant sa tourelle, sauf site meurtrier
    if und[o.id] and (o.lethal or (turret_ok and not o.famine)) then out[o.id] = true end
  end
  return out
end

local function outpost_items(kind)
  local spec = T.outposts[kind]
  -- Un avant-poste de charbon démarre avec 2 charbons par foreuse puis se ravitaille sur sa production.
  local fuel = kind == "coal" and 2 * spec.drills or T.fuel_per_burner * spec.drills * (spec.sink == "stone-furnace" and 2 or 1)
  return { { T.DRILL, spec.drills }, { spec.sink, spec.drills }, { T.fuel, fuel } }
end

function P.outpost_items(kind) return outpost_items(kind) end

--- Avant-poste minimal (reconstruction) : 2 paires et leur combustible.
local function minimal_items(kind)
  local spec = T.outposts[kind]
  local n = math.min(2, spec.drills)
  local fuel = kind == "coal" and 2 * n or T.fuel_per_burner * n * (spec.sink == "stone-furnace" and 2 or 1)
  return { { T.DRILL, n }, { spec.sink, n }, { T.fuel, fuel } }
end

function P.minimal_items(kind) return minimal_items(kind) end -- lot SURVIE-PENURIE (shared/team/survie.lua : agrandissement avec 2 paires)

--- Le palier `goal` est-il atteint ? Renvoie atteint, liste des besoins (avant-postes, objets...).
local function goal_status(goal, view)
  local need = goal.need
  local reached = true
  local parts = {}
  if need.outposts then
    for _, kind in ipairs(T.OUTPOST_ORDER) do
      local want = need.outposts[kind]
      if want then
        -- Atteint à 75 % de la capacité visée (un gisement étroit n'accueille pas toujours toutes les paires).
        local have = capacity(view, kind)
        local pend = view.pending[kind] or 0
        if have < want * 0.75 then
          reached = false
          if have + pend < want * 0.75 then parts[#parts + 1] = { outpost = kind, n = math.max(1, math.ceil(want - have - pend)) } end
        end
      end
    end
  end
  if need.smelters and view.smelters < need.smelters then
    reached = false
    if view.smelters + view.smelters_pending < need.smelters then
      parts[#parts + 1] = { smelters = need.smelters - view.smelters - view.smelters_pending }
    end
  end
  if need.tech and view.tech < need.tech then
    reached = false
    parts[#parts + 1] = { tech = view.tech + 1 }
  end
  if need.soldiers and view.soldiers < need.soldiers then
    reached = false
    parts[#parts + 1] = { soldiers = need.soldiers - view.soldiers }
  end
  if need.stock then
    -- Lot IA1-a : objets parcourus dans l'ordre de leurs noms (l'ordre de `pairs` décidait l'ordre des besoins,
    -- règle 5 ; sans effet tant que l'échelle n'a qu'un objet de stock, faux dès le deuxième).
    local items = {}
    for item in pairs(need.stock) do items[#items + 1] = item end
    table.sort(items)
    for _, item in ipairs(items) do
      local n = need.stock[item]
      if (view.stock[item] or 0) < n then
        reached = false
        parts[#parts + 1] = { item = item, n = n - (view.stock[item] or 0) }
      end
    end
  end
  if need.outpost_turrets then
    -- Atteint quand 75 % des avant-postes sont défendus (moteur réel, E16 it. 10 : « tous » n'était
    -- jamais atteint, des tourelles tombant sous les attaques pendant qu'on fortifiait les autres).
    local ok_n, todo = 0, {}
    for _, o in ipairs(view.outposts) do
      if o.turrets >= need.outpost_turrets then
        ok_n = ok_n + 1
      elseif not o.has_fortify then
        todo[#todo + 1] = { fortify = o.id, n = need.outpost_turrets - o.turrets }
      end
    end
    if ok_n < math.ceil(0.75 * #view.outposts) then
      reached = false
      for _, part in ipairs(todo) do parts[#parts + 1] = part end
    end
  end
  return reached, parts
end

--- Un soldat à attaque de zone (grenade) ? Lu à la donnée qui fabrique son prototype (prototypes/faction.lua : drapeau
--- `rocket`), sans nom. Sa grenade blesse tout dans 6,5 tuiles, base comprise (lot GRENADES).
function P.zone_unit(unit)
  local s = F.soldiers[unit]
  return s ~= nil and s.rocket == true
end

--- Meilleur soldat que l'équipe fabrique au niveau `tech` : le plus haut barreau de T.unit_ladder débloqué, hors soldat de
--- zone tant que T.zone_units est faux (on reste alors sur le barreau précédent : plus de grenades fabriquées).
function P.best_unit(tech)
  local best = T.unit_ladder[1][2]
  for _, step in ipairs(T.unit_ladder) do
    if tech >= step[1] and (T.zone_units or not P.zone_unit(step[2])) then best = step[2] end
  end
  return best
end

function P.army_target(view)
  local share = T.army_share[view.personality] or 0.6
  return math.floor(view.soldiers_max * share)
end

local function kit_list(kit, n)
  local out = {}
  for _, it in ipairs(T.kits[kit]) do out[#out + 1] = { it[1], it[2] * n } end
  return out
end

function P.plan(view, book)
  local out = { tasks = {}, missing = {}, reached = {}, site_needs = {}, smelt = {} }
  local tasks = out.tasks
  local open = view.open or {}
  local function add(t)
    if not open[t.key] then tasks[#tasks + 1] = t end
  end

  -- Stock virtuel : stock du QG + fabrications en cours. Chaque besoin servi y puise, du plus urgent au
  -- moins urgent : deux tâches ne comptent jamais sur les mêmes plaques.
  local avail = {}
  for k, v in pairs(view.stock) do avail[k] = v end
  for k, v in pairs(view.incoming or {}) do avail[k] = (avail[k] or 0) + v end
  local function take(list)
    for _, it in ipairs(list) do
      if (avail[it[1]] or 0) < it[2] then return false end
    end
    for _, it in ipairs(list) do avail[it[1]] = avail[it[1]] - it[2] end
    return true
  end

  local raw_short = {}   -- matières premières manquantes (toutes demandes confondues)
  local raw_prio = {}    -- lot PILE-PRIORITE : priorité la plus haute des demandes de chaque matière manquante (out.raw_need)
  local last_raw = {}    -- matières manquantes de la dernière demande (affichage « il manque »)
  local crafts = 0
  --- Fait fabriquer `list` (fabrication à la main depuis le stock virtuel). Renvoie true si tout est servi.
  --- fresh = besoin d'ACCUMULATION (stock visé, packs de recherche) : la quantité demandée est à fabriquer
  --- en plus du stock, elle n'y est pas prélevée.
  local function want(list, prio, tag, fresh)
    local missing_here = false
    last_raw = {}
    local function short_raw(item, n)
      raw_short[item] = (raw_short[item] or 0) + n
      last_raw[item] = (last_raw[item] or 0) + n
      if (raw_prio[item] or -1) < prio then raw_prio[item] = prio end -- lot PILE-PRIORITE : le manque garde la priorité de son demandeur
    end
    for _, it in ipairs(list) do
      local item, n = it[1], it[2]
      local have = fresh and 0 or (avail[item] or 0)
      if have >= n then
        avail[item] = have - n
      else
        local short = n - have
        if not fresh then avail[item] = 0 end
        if book:handcraftable(item) then
          -- Besoin d'accumulation : l'objet lui-même ne doit pas être « pris » au stock par le plan.
          local saved = avail[item]
          if fresh then avail[item] = 0 end
          local p = book:plan({ { item, short } }, avail)
          if next(p.raw) == nil then
            -- Les grosses commandes sont partagées entre plusieurs ouvriers (lots de ~CHUNK_SECONDS de
            -- fabrication) : toute l'équipe fabrique en parallèle.
            local energy = 0
            for _, c in ipairs(p.crafts) do energy = energy + c.energy end
            local chunks = math.max(1, math.min(short, math.ceil(energy / CHUNK_SECONDS), MAX_CRAFT_TASKS - crafts))
            local per = math.ceil(short / chunks)
            local left = short
            local i = 0
            while left > 0 and crafts < MAX_CRAFT_TASKS do
              i = i + 1
              local n = math.min(per, left)
              local q = book:plan({ { item, n } }, avail)
              crafts = crafts + 1
              left = left - n
              avail = q.avail
              add({ key = "craft:" .. item .. ":" .. tag .. ":" .. i, kind = "craft", prio = prio, item = item, count = n,
                steps = q.crafts, uses = sorted_uses(q.uses), tag = tag })
            end
            if left > 0 then avail = book:plan({ { item, left } }, avail).avail end
            if fresh then avail[item] = saved end
          else
            if fresh then avail[item] = saved end
            missing_here = true
            for r, k in pairs(p.raw) do short_raw(r, k) end
          end
        else
          missing_here = true
          short_raw(item, short)
        end
      end
    end
    return not missing_here
  end

  ---------------------------------------------------------------------------------------------------
  -- DÉFENDRE D'ABORD (lot IA1-b2, décision D-17 du 25/10) : view.defend_first (vrai) ; sans lui, règle d'avant.
  --  - un avant-poste NON défendu (moins de T.defend_turrets(foreuses) tourelles) reçoit ses tourelles en URGENCE
  --    (tâche « fortify », priorité T.defend_prio) et ne s'agrandit pas avant ;
  --  - un NOUVEL avant-poste d'un type déjà exploité se construit AVEC ses tourelles (le constructeur les pose en
  --    arrivant) : sans elles au stock, il attend (elles sont fabriquées si la recette est connue) ;
  --  - RÈGLE DE REPLI (aucune tourelle au stock, recette inconnue : votre force n'a pas la recherche « Tourelles ») :
  --    l'équipe travaille comme avant, mais un avant-poste MEURTRIER (un PNJ tué en y allant) n'est plus visité pendant
  --    T.lethal_ticks (ni tournée, ni agrandissement, ni fond). Essai 1 du lot (repli plus strict : premier avant-poste
  --    de chaque ressource seulement, aucun agrandissement) : production de votre équipe -42 % et -16 % sur les deux
  --    graines du guide pour 4 et 6 morts de moins ; écarté ;
  --  - le QG reçoit d'abord T.defend_hq tourelles ; la défense ne fabrique pas sous T.defend_iron_floor plaques de fer ;
  --    un avant-poste MEURTRIER non défendu ne reçoit plus que ses tourelles (et sa tournée si sa ressource manque) ;
  --  - équipe DÉCIMÉE (sous son effectif de départ) : ni nouvel avant-poste, ni fond ; la défense continue ;
  --  - la croissance (frein levé par le travail qui attend, script/team/team.lua) ne vaut qu'avec une tourelle possible.
  ---------------------------------------------------------------------------------------------------
  local df = view.defend_first and true or false
  local turret_craftable = df and book:handcraftable("gun-turret") or false
  local turret_ok = df and (turret_craftable or (avail["gun-turret"] or 0) > 0) or false
  -- `undefended` : avant-postes où l'on ne va ni agrandir ni travailler au fond (P.no_go) ; `lacking` : tous les non
  -- défendus (tourelles à poser dès qu'elles existent).
  local lacking = P.undefended(view)
  -- Équipe DÉCIMÉE (sous son effectif de départ) : le QG et les recrues d'abord ; ni tourelle d'avant-poste ni nouvel
  -- avant-poste (essai 3 du lot, ia1b2-guide graine 1618033988 : tourelles portées par des PNJ tués en route, fer à 0
  -- pendant 30 min, QG perdu à 45 min).
  local floor0 = view.recover_floor or (view.emergency and view.emergency.floor) or 0
  local decimated = df and view.workers < floor0
  local function turret_items(n, ammo_each) return { { "gun-turret", n }, { T.turret_ammo, n * (ammo_each or T.defend_ammo) } } end
  local PARTIAL_POSTS = { hq = true, plant = true, front = true } -- postes servis par une commande partielle (lot INTEG-DEFENSE 3.4)
  local iron_key = T.outposts.iron.product -- (PRIORITE-RESSOURCES) clé du fer, lue à la config ; remontée avant les postes pour le drapeau `iron` (DEFENSE-FACTIONS D5)
  -- Postes à défendre (le QG, les avant-postes sans leurs tourelles, la centrale, le front), dans l'ordre où l'urgence les sert.
  -- Lot PRIORITE-RESSOURCES : construits ICI (sans effet de bord) parce que leur coût décide de l'ordre production / défense.
  local posts = {}
  -- Lot DEFENSE-CHOIX (défaut 5 du DC, 0.6.18 : « 600 de fer [...] ils peuvent faire des tourelles [...] payer des soldats, des fois c'est
  -- peut-être pas la meilleure solution ») : base menacée (view.base_alert, script/faction/defchoix.lua) et fer + cuivre au-dessus des
  -- planchers qui paient une tourelle avec ses chargeurs : le QG veut des tourelles (jusqu'à Dc.HQ_CAP), AVANT la levée de soldats
  -- d'urgence plus bas (shared/team/defchoix.lua). Lecteurs de out.defchoix : la levée d'urgence ci-dessous, le journal [FO-DEFCHOIX]
  -- (script/team/team.lua).
  local dc = { want = view.hq_defend or T.defend_hq, first = false, hold_soldiers = false }
  -- Lot S1 : QG EN PÉRIL (shared/team/survie_qg.lua, view.qg_peril = résultat de Sq.peril) : planchers de fer et de cuivre de la défense
  -- réduits, tourelles voulues au QG = celles qui couvrent la menace mémorisée.
  local qp = view.qg_peril
  local peril_seen = (qp and qp.peril) and true or false
  -- Lot S1 : AVANT-POSTES touchés par des vagues et sans leurs tourelles (view.outposts[i].protect) : on les protège avant de les agrandir ou
  -- de les refaire (le DC : « réparer + protéger puis améliorer » ; « les ressources d'abord » : protéger le fer, c'est le garder). Le péril
  -- met la production derrière la défense (Pr.decide) : `block` ci-dessous exclut alors tout avant-poste sans tourelles de l'agrandissement.
  local protect_any = false
  if df and turret_ok then
    for _, o in ipairs(view.outposts or {}) do
      if o.protect and (o.turrets or 0) < (o.want_t or T.defend_turrets(o.drills)) then protect_any = true end -- (DEFENSE-AP : garde voulue sur la menace)
    end
  end
  out.turret_ok = turret_ok -- lot S1 : lu par script/team/survie_qg.lua (reconstruction et agrandissement de survie attendent les tourelles)
  -- La défense d'abord n'a de sens que si une tourelle peut être posée (au stock ou fabricable) : sans recette (0.6.32, votre équipe : 34 min de péril
  -- sans « gun-turret » recherchée), le péril ne prend pas le pas sur la production. Le remplissage des tourelles posées n'a pas besoin de recette.
  local qg_peril = peril_seen and turret_ok
  local in_peril = qg_peril or protect_any
  local fl_i, fl_c = Sq.floors(in_peril, T.defend_iron_floor, T.defend_copper_floor)
  if df and view.base_alert then
    local cu_key = T.outposts.copper.product
    local rc = book:raw_cost(turret_items(1))
    dc = Dc.turrets({ alert = true, want = view.hq_defend or T.defend_hq, have = view.hq_turrets or 0, ok = turret_ok,
      busy = (view.hq_fortify or open["fortify:hq"]) and true or false,
      funds_iron = (avail[iron_key] or 0) - fl_i, cost_iron = rc[iron_key] or 0,
      funds_copper = (avail[cu_key] or 0) - fl_c, cost_copper = rc[cu_key] or 0, stock = avail[T.turret] or 0 })
  end
  out.defchoix = dc
  if df then
    -- lot HQ-RECENSEMENT (après QG-GROUPE2) : en péril, le groupe « hq » veut hq + fresh (qp.hq_want, sinon view.hq_turrets + qp.fresh).
    -- qp.want compte le recensement à 48 tuiles (tourelles des avant-postes voisins comprises) contre `have` = groupe « hq » seul : une pose
    -- en appelait une autre (fo-logs/2026-11-03_QGGROUPE/g1-123456789 : 22 tourelles « hq » posées). Plus de « qp.want » ici.
    local qwant = qp and (qp.hq_want or (view.hq_turrets or 0) + (qp.fresh or 0)) or 0
    posts[1] = { id = "hq", want = qg_peril and math.max(dc.want, qwant) or dc.want, have = view.hq_turrets or 0, busy = view.hq_fortify }
    for _, o in ipairs(view.outposts) do
      -- Lot DEFENSE-AP (mesure diag1, 9/11) : un avant-poste « défendu » selon ses foreuses mais sous la garde que sa menace exige (vague prévue
      -- ou reçue, shared/team/garde_ap.lua) reçoit aussi ses tourelles : la règle d'avant (1 + foreuses / 8 = 3) laissait l'avant-poste de fer
      -- face à 1750 PV de vague avec 1724 PV de défense, puis à 2457 PV ; il tombait à 15 min, le fer ne revenait plus. N'agit pas sur
      -- `lacking` (agrandissement, tournées de fond : règles d'avant) ; ne retire rien à la défense.
      local wt = math.min(T.defend_outpost_max, math.max(o.want_t or 0, T.defend_turrets(o.drills))) -- (F489 : plafond du DC par avant-poste)
      if lacking[o.id] or (o.turrets or 0) < wt then
        local ospec = T.outposts[o.kind]
        posts[#posts + 1] = { id = o.id, want = wt, have = o.turrets or 0, busy = o.has_fortify,
          iron = (ospec and ospec.product == iron_key) or nil } -- lot DEFENSE-FACTIONS D5 : un avant-poste de fer non défendu passe AVANT le front
      end
    end
    -- Lot CENTRALE-GARDE : la centrale FINIE (view.plant) est un poste comme un avant-poste : K tourelles ARMÉES à portée de toutes ses
    -- pièces (shared/team/garde_centrale.lua), posées par la même tâche « fortify », payées sur le stock.
    if view.plant then
      local pl = view.plant
      -- Lot GARDE-MULTI : TOUTES les centrales finies (pl.plants) ; un seul poste « plant » à la fois (une tâche ouverte par équipe),
      -- la centrale la moins gardée d'abord, sous le plafond de tourelles de l'équipe (Guard.plan). Forme ancienne : une centrale (pl).
      local plan = (not pl.pause) and Guard.plan(pl.plants or { pl }, pl.turrets, pl.range, pl.low, pl.cap) or nil
      local pick = plan and plan.pick
      if pick then
        posts[#posts + 1] = { id = "plant", want = pick.need.near + pick.missing, have = pick.need.near, busy = pl.fortify,
          sites = pick.need.sites, pos = pick.need.center, range = pl.range, pieces = pick.pieces, plant_id = pick.id }
      end
    end
    -- Lot DEFENSE-FRONT : la cellule la plus attaquée (ou un groupe de laboratoires à couvrir) reçoit ses tourelles en plus, par lots,
    -- sous le plafond de l'équipe (shared/team/front.lua) ; un seul poste « front » à la fois, payé sur le stock comme les autres.
    if view.front and view.front.pick then
      local pk = view.front.pick
      local fp = { id = "front", want = pk.have + pk.count, have = pk.have, busy = view.front.busy,
        sites = pk.sites, pos = { x = pk.x, y = pk.y }, cell_key = pk.key, score = pk.score }
      -- Lot DEFENSE-FACTIONS D5 : une cellule à moins de Fr.NEAR_HQ tuiles du QG passe APRÈS le QG mais AVANT les avant-postes non défendus
      -- et la centrale ; jamais devant un avant-poste de FER non défendu (remarque du DC : les ressources d'abord, la défense juste après).
      if pk.near_hq then
        local at = 2
        while posts[at] and posts[at].iron do at = at + 1 end
        table.insert(posts, at, fp)
      else
        posts[#posts + 1] = fp
      end
    end
    -- Lot ILOTS-MURS (arbitrage du DC, 29/10 : « l'entourer d'un mur et d'une ou 2 tourelle », « ressources d'abord ») : l'îlot isolé hors de
    -- l'enceinte le plus en manque (script/team/ilots.lua, attaqué d'abord) ; poste FACULTATIF, le dernier : hors du coût de la défense
    -- (jamais il ne fait passer la défense avant la production), servi seulement hors « production d'abord », au-dessus de planchers doublés.
    if view.ilot and view.ilot.pick then
      local pk = view.ilot.pick
      posts[#posts + 1] = { id = "ilot", want = pk.want, have = pk.have, busy = view.ilot.busy, sites = pk.sites, pos = pk.pos,
        ilot = pk.key, box = pk.box, optional = true, floor_i = view.ilot.floor_i, floor_cu = view.ilot.floor_cu }
    end
  end
  -- Lot PRIORITE-RESSOURCES (remarque du DC, 29/10 : « si on manque cruellement de ressources, l'objectif est justement ces
  -- ressources, pas la défense […] mais si on peut pas se l'acheter, on investit les ressources dans la production de plus de
  -- ressources ») : le fer paie-t-il la défense voulue ET le prochain pas de production ? Sinon la production passe d'abord
  -- (shared/team/priorite.lua). Tout en plaques de la clé (le fer), lues au livre de recettes. Sans « défendre d'abord » : règle d'avant.
  local pri = Pr.decide({})
  if df then
    -- Fer total d'une liste (déjà au stock compris), `stock` : le stock à compter ; nil si une autre matière manque (pas faisable).
    local function iron_cost(list, stock)
      local p = book:plan(list, stock or avail)
      return (p.uses[iron_key] or 0) + (p.raw[iron_key] or 0), p
    end
    -- Lot INTEG-DEFENSE D-C : le coût de la défense est celui de ce qui est RÉELLEMENT servi : le QG, la centrale et le front le sont par
    -- une commande PARTIELLE quand la complète n'est pas payable (Fr.PARTIAL_COUNT tourelle, Fr.PARTIAL_AMMO chargeurs) ; compter leur
    -- commande complète (240 de fer pour 2 tourelles du front, 480 pour le QG) gardait « production d'abord » jusqu'à ~410 de fer alors
    -- que la défense se servait dès 230.
    local n_miss, n_part = 0, 0
    for _, p in ipairs(posts) do
      if p.have < p.want and not p.busy and not open["fortify:" .. p.id] and not p.optional then -- (ILOTS-MURS : poste facultatif hors du coût)
        local n = p.want - p.have
        if not turret_craftable then n = math.min(n, avail[T.turret] or 0) end
        if PARTIAL_POSTS[p.id] then n_part = n_part + math.min(n, math.max(1, Fr.PARTIAL_COUNT)) else n_miss = n_miss + n end
      end
    end
    local cd = 0
    if n_miss + n_part > 0 then
      local list = turret_items(n_miss + n_part)
      list[2][2] = n_miss * T.defend_ammo + n_part * math.max(1, Fr.PARTIAL_AMMO)
      cd = iron_cost(list)
    end
    -- Premier objectif de l'échelle non atteint, s'il est militaire : son coût s'ajoute (les tourelles sont déjà comptées).
    do
      local done_g, deferred_g = view.done or {}, view.deferred or {}
      for _, g in ipairs(view.ladder or T.ladder) do
        if not done_g[g.key] and not deferred_g[g.key] then
          local reached, parts0 = goal_status(g, view)
          if not reached then
            if Pr.military_need(g.need, T.turret_ammo) then
              for _, part in ipairs(parts0) do
                if part.soldiers then
                  cd = cd + iron_cost(kit_list(P.best_unit(view.tech), part.soldiers))
                elseif part.item then
                  cd = cd + iron_cost({ { part.item, part.n } }, {})
                end
              end
            end
            break
          end
        end
      end
    end
    -- Pas de production utile (le moins cher des FAISABLES : aucune autre matière ne manque que le fer ; ni un avant-poste
    -- meurtrier, ni un pas déjà au tableau) : agrandir un avant-poste (2 paires), bâtir le premier d'un type (2 paires) ou, quand
    -- aucun avant-poste du type ne peut s'agrandir, en bâtir un autre : celui-là porte ses tourelles (build_items), dont le coût
    -- s'ajoute à la défense à payer.
    local steps = {}
    local function step(kind)
      local c, p = iron_cost(minimal_items(kind))
      for r in pairs(p.raw) do if r ~= iron_key then return false end end
      steps[#steps + 1] = c
      return true
    end
    local lethal_only = P.no_go(view, false)
    local growable, stepped = {}, {}
    for _, o in ipairs(view.outposts) do
      if not o.full and o.drills < T.max_drills(o.kind) and not lethal_only[o.id] then
        growable[o.kind] = true
        if not stepped[o.kind] and not open["extend:" .. o.id] and (view.pending[o.kind] or 0) == 0 then
          stepped[o.kind] = true -- un seul calcul par type (même coût d'un avant-poste à l'autre)
          step(o.kind)
        end
      end
    end
    for _, kind in ipairs(T.OUTPOST_ORDER) do
      if not growable[kind] and (view.pending[kind] or 0) == 0 and (view.sites[kind] or 0) > 0 and not open["build:" .. kind] then
        if step(kind) and turret_ok and count_kind(view, kind) > 0 then
          cd = cd + iron_cost(turret_items(T.defend_turrets(T.outposts[kind].drills)))
        end
      end
    end
    -- Fer que la défense peut dépenser : au-dessus de T.defend_iron_floor (la fabrication des tourelles ne descend pas dessous,
    -- want_defense) ; sans cela le mode « défense payée » restait vrai à 140 de fer alors que rien ne pouvait s'acheter.
    pri = Pr.decide({ funds = (avail[iron_key] or 0) - fl_i, defense_cost = cd, production_cost = Pr.cheapest(steps),
      peril = in_peril, -- lot S1 : le QG ne tient pas la menace reçue : la défense d'abord, même en mode survie
      survie = view.survie, -- lot SURVIE-PENURIE : mode survie de l'équipe (script/team/survie.lua) -> la production d'abord
      survival = decimated,
      prev_pf = view.priorite_pf, streak = view.priorite_streak or 0 }) -- lot INTEG-DEFENSE D-D : bascule confirmée sur 2 pensées
  end
  out.priorite = pri
  -- Production d'abord : un avant-poste sans sa tourelle s'agrandit quand même et un nouvel avant-poste se bâtit sans les siennes
  -- (ils attendaient leurs tourelles, que le fer ne paie pas) ; seul un avant-poste MEURTRIER (un PNJ tué en y allant) reste exclu.
  local block = turret_ok and not pri.production_first
  local undefended = P.no_go(view, block)
  --- Fabrication des tourelles (et de leurs chargeurs) SANS descendre sous T.defend_iron_floor plaques de fer : la
  --- défense ne prend pas le fer des recrues de survie (essai 1 du lot, ia1b2-guide graine 1618033988 : fer 615 -> 26 en
  --- 5 min, tourelles perdues avec leurs porteurs, équipe perdue à 23 min).
  --- Lot DEFENSE-FACTIONS : `floor_i` et `floor_cu` (facultatifs) remplacent les planchers ordinaires (poste « front » à score élevé,
  --- shared/team/front.lua F.floors) ; rend vrai si tout est servi (fabrications lancées ou au stock), faux sinon (`last_raw` dit quoi).
  local function want_defense(list, floor_i, floor_cu)
    -- Fer ET cuivre (essai 6, ia1b2-guide graine 314159265 : 8 tourelles mangent les 100 cuivres du coffre, aucun
    -- gisement de cuivre trouvé, plus un seul pistolet pour les recrues pendant 20 min).
    local keep = math.min(avail["iron-plate"] or 0, floor_i or fl_i)
    local keep_cu = math.min(avail["copper-plate"] or 0, floor_cu or fl_c)
    avail["iron-plate"] = (avail["iron-plate"] or 0) - keep
    avail["copper-plate"] = (avail["copper-plate"] or 0) - keep_cu
    local ok = want(list, T.defend_prio, "defense")
    avail["iron-plate"] = (avail["iron-plate"] or 0) + keep
    avail["copper-plate"] = (avail["copper-plate"] or 0) + keep_cu
    return ok
  end
  --- Lot DEFENSE-FACTIONS : `list` est-elle faisable (stock et fabrication à la main) au-dessus des planchers donnés ? Sans effet de bord.
  local def_iron, def_copper = T.outposts.iron.product, T.outposts.copper.product
  local function affordable(list, floor_i, floor_cu)
    local si, sc = avail[def_iron] or 0, avail[def_copper] or 0
    avail[def_iron], avail[def_copper] = si - math.min(si, floor_i), sc - math.min(sc, floor_cu)
    local p = book:plan(list, avail)
    avail[def_iron], avail[def_copper] = si, sc
    return next(p.raw) == nil, p
  end
  -- Intégration 0.6.33 : une tourelle est-elle posable TOUT DE SUITE (au stock, ou payable au-dessus des planchers) ? `turret_ok` ne dit que « recette
  -- connue » : à 0 de fer, la seule foreuse de fer au coffre attendait une tourelle que seul ce fer aurait payée (reconstruction, agrandissement de survie).
  out.turret_payable = turret_ok and ((avail[T.turret] or 0) > 0 or (affordable({ { T.turret, 1 } }, fl_i, fl_c))) or false
  -- L'équipe produit-elle encore du fer ? (un avant-poste de fer avec des foreuses) : sinon le coffre est sa dernière réserve et le plancher
  -- du front ne baisse pas (F.floors).
  local iron_producing = false
  for _, o in ipairs(view.outposts) do
    local spec = T.outposts[o.kind]
    if spec and spec.product == def_iron and (o.drills or 0) > 0 then iron_producing = true end
  end
  -- Lot INTEG-DEFENSE D-A : le fer qui coule des fonderies du plan directeur (pas des avant-postes) compte aussi (view.iron_flow, statistiques de la force)
  if view.iron_flow then iron_producing = true end
  --- Objets d'une construction d'avant-poste `kind` de `n_drills` foreuses : `items`, plus ses tourelles si elles sont
  --- au stock virtuel. nil : la construction attend ses tourelles (demandées ici si la recette est connue) ou n'a pas
  --- lieu (règle de repli).
  local function build_items(kind, items, n_drills)
    if not block then return items end -- règle de repli (et production d'abord, lot PRIORITE-RESSOURCES) : construction comme avant
    if decimated and count_kind(view, kind) > 0 then return nil end -- décimée : pas de nouvel avant-poste
    local t = turret_items(T.defend_turrets(n_drills))
    local have_t = true
    for _, it in ipairs(t) do if (avail[it[1]] or 0) < it[2] then have_t = false end end
    if have_t then
      local all = {}
      for _, it in ipairs(items) do all[#all + 1] = it end
      for _, it in ipairs(t) do all[#all + 1] = it end
      return all
    end
    if count_kind(view, kind) == 0 then return items end -- premier avant-poste de ce type (départ, reconstruction)
    if turret_craftable then want_defense(t) end
    out.defend_wait = (out.defend_wait or 0) + 1
    return nil
  end

  ---------------------------------------------------------------------------------------------------
  -- 1. Entretien : brûleurs, production en attente, munitions des tourelles
  ---------------------------------------------------------------------------------------------------
  local fuel_reserve = view.smelter_coal or 0
  for _, o in ipairs(view.outposts) do
    if o.kind ~= "coal" then fuel_reserve = fuel_reserve + (o.coal_needed or 0) end
    if df and o.lethal and lacking[o.id] and (view.stock[T.outposts[o.kind].product] or 0) >= T.lethal_need then
      -- Lot IA1-b2 : avant-poste MEURTRIER (un PNJ tué en y allant, il y a moins de T.lethal_ticks) et non défendu :
      -- pas de tournée (on n'y retourne qu'avec ses tourelles), SAUF si sa ressource manque au coffre (moins de
      -- T.lethal_need : essai 5 du lot, graine 314159265, cuivre à 0 pendant 26 min, aucun pistolet pour les recrues).
      out.lethal_skip = (out.lethal_skip or 0) + 1
    elseif not o.has_task then
      -- Lot FLUX : ravitailler ce qui produit (96) et vider des sorties pleines quand le coffre manque du produit (88) passent devant
      -- le minage ; sinon les priorités d'avant (95 et 70), qui vieillissent à la synchronisation du tableau (script/team/board.lua).
      local product = T.outposts[o.kind] and T.outposts[o.kind].product
      local have = product and (view.stock[product] or 0) or 0
      -- Lot CHARBON-MAIN : un avant-poste BRUT (sortie = sa ressource) dont les coffres en ont pendant que le coffre du QG en manque : sa
      -- tournée passe en urgence (Sm.FETCH_PRIO), devant le minage à la main de cette ressource (refusé au même moment, worker.lua).
      local function prio_of(base)
        local p = Fx.service_prio(base, o, VITAL[o.kind], have)
        -- (le danger de l'avant-poste, o.unsafe, n'est relevé que dans ces deux cas : script/team/team.lua)
        if view.sorties_on and (o.fuel_low or o.output >= T.collect_at) then p = Sm.fetch_prio(p, o, RAW, have) end
        return p
      end
      if o.fuel_low then
        add({ key = "service:" .. o.id, kind = "service", prio = prio_of(95), outpost = o.id })
      elseif o.output >= T.collect_at or o.idle_ticks >= T.service_period then
        add({ key = "service:" .. o.id, kind = "service", prio = prio_of(70), outpost = o.id })
      end
    end
  end
  -- Lot PURGE-FER-CHARBON (DC 11/11) : un avant-poste de charbon de plus seulement sous le besoin réel des chaudières et des brûleurs actifs, lu en
  -- jeu (view.coal_cap, shared/team/bilan_charbon.lua) ; il remplace le bilan à cadences et sa marge de 40 %. Avant la réserve de tournée.
  do
    if #view.outposts > 0 and Bc.room(view.coal_cap) and (view.pending.coal or 0) == 0
      and not Th.raw_full(T.outposts.coal, view.stock) then
      local items = outpost_items("coal")
      local ext = extendable(view, "coal", undefended)
      if ext and not open["extend:" .. ext.id] then
        if take(items) then
          add({ key = "extend:" .. ext.id, kind = "extend", prio = 85, outpost = ext.id, outpost_kind = "coal", items = items })
        else
          want(items, 52, "charbon")
        end
      elseif not ext and not (df and extendable(view, "coal")) then
        -- (lot IA1-b2 : un avant-poste de charbon qui attend ses tourelles pour s'agrandir ne fait pas bâtir ailleurs)
        out.site_needs.coal = math.max(out.site_needs.coal or 0, 1)
        local list = build_items("coal", items, T.outposts.coal.drills)
        if list then
          if (view.sites.coal or 0) > 0 and take(list) then
            add({ key = "build:coal", kind = "build", prio = 85, outpost_kind = "coal", items = list })
          else
            want(list, 52, "charbon")
          end
        end
      end
    end
  end

  -- Le charbon nécessaire aux tournées est réservé avant toute fabrication (grenades, etc.).
  avail[T.fuel] = math.max(0, (avail[T.fuel] or 0) - math.min(fuel_reserve, avail[T.fuel] or 0))
  out.fuel_reserve = fuel_reserve -- lot CC-COMBUSTIBLE : la meme reserve, retiree du stock virtuel du cerveau (shared/ai3/cerveau.lua, C.consumed)

  -- Lot MUNITIONS : la munition FABRIQUÉE et PORTÉE aux tourelles (view.turret_ammo : la meilleure fabricable, Mu.best_ammo) ; la pose d'une
  -- tourelle reste payée en munition de base (base_ammo, Outposts.add_turret).
  local base_ammo = T.turret_ammo
  local ammo = view.turret_ammo or base_ammo
  local surplus = {} -- lot MUNITIONS : surplus de la cible riche, servi APRÈS les recrues (section 4)
  -- Lot S1 : en péril, le groupe du QG est servi AVANT les autres (la commande de chargeurs d'un avant-poste réservait le stock, le QG n'en avait plus).
  local groups = view.turret_groups
  if peril_seen then
    groups = {}
    for _, g in ipairs(view.turret_groups) do if g.key == "hq" then groups[#groups + 1] = g end end
    for _, g in ipairs(view.turret_groups) do if g.key ~= "hq" then groups[#groups + 1] = g end end
  end
  for _, g in ipairs(groups) do
    if g.short ~= nil then
      -- Lot MUNITIONS (shared/team/munitions.lua) : une tourelle sous 75 % de sa cible est rechargée AU PLEIN (g.missing chargeurs) ; la
      -- tournée part avec ce que le stock donne (Mu.take, recharge partielle) et le reste se fabrique aussitôt, à la même priorité. Avant :
      -- seulement sous le seuil bas, et tout ou rien hors péril (QG à 120 chargeurs pour 8 tourelles quand la vague de 140 min l'a vidé).
      -- Part URGENTE (jusqu'à la cible ordinaire, g.missing_base) : priorité 90, avant les recrues ; SURPLUS de la cible riche : après elles
      -- (essai 1, verif-guide 271828182 : 988 chargeurs au coffre, 14 PNJ contre 23).
      if Mu.due(g) and not g.has_task then
        local n = g.missing
        local nb = math.min(n, g.missing_base or n)
        local stock = avail[ammo] or 0
        local part = Mu.take(nb, math.max(1, g.short_base or g.short), stock, g.low) -- (revue M1 : les tourelles vides d'abord)
        local task = nil
        if part > 0 then
          task = { key = "refill:" .. g.key, kind = "refill", prio = 90, group = g.key, count = part }
          add(task)
          avail[ammo] = stock - part
        end
        -- (essai 3 : la munition choisie n'est quittée qu'après 5 min sans pouvoir la fabriquer ; pendant ce temps la part urgente se fait en
        -- munition de base, jamais une tourelle laissée vide faute d'acier)
        if part < nb and not want({ { ammo, nb - part } }, 90, "munitions") and ammo ~= base_ammo then
          want({ { base_ammo, nb - part } }, 90, "munitions")
        end
        if n > nb then surplus[#surplus + 1] = { g = g, n = n - nb, task = task } end
      end
    elseif g.low > 0 and not g.has_task then
      local n = g.low * T.turret_ammo_target
      -- Lot S1 : au QG en péril, un stock de chargeurs incomplet remplit quand même les tourelles vides (tout ou rien avant : 160 chargeurs
      -- pour 8 tourelles, jamais atteints avec 0 fer, et les tourelles restaient vides).
      local part = (g.key == "hq" and peril_seen) and Sq.refill_take(g.low, T.turret_ammo_target, avail[ammo] or 0, true) or 0
      if (avail[ammo] or 0) >= n or (avail["firearm-magazine"] or 0) >= n or part > 0 then
        add({ key = "refill:" .. g.key, kind = "refill", prio = 90, group = g.key })
        local use = (avail[ammo] or 0) >= n and ammo or "firearm-magazine"
        avail[use] = math.max(0, (avail[use] or 0) - ((part > 0 and part < n) and part or n))
      else
        want({ { ammo, n } }, 90, "munitions")
      end
    end
  end

  -- Lot IA1-b2 (défendre d'abord) : tourelles des avant-postes non défendus, en urgence (ordre des id). Sans recette,
  -- seulement les tourelles déjà au stock (règle de repli sinon).
  -- Le QG d'abord (T.defend_hq tourelles : les PNJ y vivent, la fonderie y pollue ; essai 1 du lot, graine 1618033988 :
  -- QG attaqué dès 17 min, équipe perdue à 23 min). Un avant-poste MEURTRIER ne reçoit plus que ses tourelles.
  if df then
    local waiting = 0
    for _, o in ipairs(view.outposts) do if lacking[o.id] then waiting = waiting + 1 end end
    -- Lot PRIORITE-RESSOURCES : en « production d'abord », le fer du prochain pas de production (pri.hold) est mis de côté le temps
    -- d'acheter la défense : elle ne dépense que le fer au-delà. Il revient au stock juste après (reconstruction, objectif).
    -- Lot INTEG-DEFENSE 3.3 : le QG est servi AVANT le hold (le fer mis de côté ne retient pas le QG : « le QG d'abord » d'IA1-b2 ne devient
    -- pas « le QG après un pas de production ») ; le hold est retiré du stock au premier poste suivant, et rendu après la boucle.
    local held = math.min(pri.hold or 0, avail[iron_key] or 0)
    local held_taken = false
    -- Lot DEFENSE-FACTIONS D1 : pourquoi chaque poste n'est pas servi (journal [FO-DEFENSE], script/team/defense_log.lua) ; aucune décision n'en dépend.
    local dposts = {}
    local fund_hold = 0 -- lot DEFENSE-AP : fer mis de côté pour un avant-poste de fer sans tourelle
    for _, p in ipairs(posts) do
      if p.id ~= "hq" and not held_taken then
        avail[iron_key] = (avail[iron_key] or 0) - held
        held_taken = true
      end
      local key = "fortify:" .. p.id
      local d = nil
      if p.have < p.want then
        d = { id = p.id, have = p.have, want = p.want, iron = avail[def_iron] or 0, copper = avail[def_copper] or 0 }
        if p.busy or open[key] then
          d.why = "tache"
        else
          local n = p.want - p.have
          if not turret_craftable then n = math.min(n, avail["gun-turret"] or 0) end
          if n <= 0 then
            d.why = "recette"
          else
            local items = turret_items(n)
            d.claim = items -- lot PILE-BUDGET : objets à payer pour ce poste (shared/ai3/budget.lua), annulé si la tâche les a déjà pris
            local function task_of(list)
              add({ key = key, kind = "fortify", prio = T.defend_prio, outpost = p.id, items = list, defend = true,
                sites = p.sites, pos = p.pos, range = p.range, pieces = p.pieces, plant_id = p.plant_id, cell_key = p.cell_key,
                ilot = p.ilot, box = p.box }) -- (ILOTS-MURS : îlot et emprise de la pose)
            end
            if p.optional then
              -- Lot ILOTS-MURS : « ressources d'abord ». Rien en « production d'abord » (pénurie comprise) ni pour une équipe décimée ; sinon
              -- les tourelles du stock, ou leur fabrication si elle est payable au-dessus des planchers doublés (I.floors) ; pas payable : rien,
              -- et aucune demande de matière (pas de minage ni de fonte pour un îlot).
              d.floor_i, d.floor_cu = p.floor_i, p.floor_cu
              if pri.production_first or decimated then
                d.why = "ressources"
              elseif take(items) then
                task_of(items)
                d.why = "tache_creee"
              elseif affordable(items, p.floor_i or T.defend_iron_floor, p.floor_cu or T.defend_copper_floor) then
                d.why = want_defense(items, p.floor_i, p.floor_cu) and "fabrication" or "manque"
                if d.why == "manque" then d.raw = last_raw end
              else
                d.why = "ressources" -- attente voulue (pas un blocage de la défense : [FO-DEFENSE] ne la compte pas, BLOCKED)
              end
            elseif take(items) then
              task_of(items)
              d.claim = nil
              d.why = "tache_creee"
            elseif PARTIAL_POSTS[p.id] then
              -- Lot DEFENSE-FACTIONS D4 : plancher réduit si la cellule est très attaquée et que le fer est encore produit (Fr.floors), puis,
              -- si la commande complète n'est pas payable, une commande PARTIELLE (Fr.PARTIAL_COUNT tourelle, Fr.PARTIAL_AMMO chargeurs)
              -- au lieu du tout-ou-rien d'avant (240 fer pour 2 tourelles pleines au-dessus d'un plancher de 150).
              -- (lot INTEG-DEFENSE 3.4 : le QG et la centrale ont la même commande partielle, aux planchers ordinaires ;
              -- D3 : le plancher réduit du front garde au moins le fer du prochain pas de production, pri.production_cost)
              local fi, fc, reduced = T.defend_iron_floor, T.defend_copper_floor, false
              if p.id == "hq" and (qg_peril or protect_any) then fi, fc, reduced = fl_i, fl_c, true end -- lot S1 : le QG en péril
              -- Lot EQUIPE : le QG sous son premier palier de tourelles (shared/team/premiere_tourelle.lua) se paie au plancher réduit, péril ou non
              local first_tier
              fi, fc, first_tier = Pt.floors(p.id, p.have, fi, fc, Sq.FLOOR_IRON, Sq.FLOOR_COPPER)
              if first_tier then reduced, d.first = true, true end
              if p.id == "front" then
                fi, fc, reduced = Fr.floors(p.score, iron_producing, T.defend_iron_floor, T.defend_copper_floor, pri.production_cost)
              end
              d.floor_i, d.floor_cu, d.reduced = fi, fc, reduced or nil
              if affordable(items, fi, fc) then
                d.why = want_defense(items, fi, fc) and "fabrication" or "manque"
                if d.why == "manque" then d.raw = last_raw end
              else
                local part = turret_items(math.min(n, math.max(1, Fr.PARTIAL_COUNT)), math.max(1, Fr.PARTIAL_AMMO))
                d.claim = part
                if take(part) then
                  task_of(part)
                  d.claim = nil -- déjà pris au stock par la tâche
                  d.why, d.partial = "tache_creee", true
                elseif affordable(part, fi, fc) then
                  d.why, d.partial = want_defense(part, fi, fc) and "fabrication" or "manque", true
                  if d.why == "manque" then d.raw = last_raw end
                else
                  local _, pp = affordable(part, fi, fc)
                  d.why, d.partial, d.raw = "fer", true, pp.raw
                  -- Intégration 0.6.18 : le QG et la centrale gardent leur DEMANDE de matières (ce qui manque à la commande partielle
                  -- au-dessus des planchers), comme want_defense le faisait avant 3.4 ; sans elle, ni minage ni fonte du fer de leurs
                  -- tourelles (tests/survie_moteur_test.lua §4). Le front garde la règle de D4 (aucune demande).
                  if p.id ~= "front" then
                    local ks = {}
                    for k in pairs(pp.raw) do ks[#ks + 1] = k end
                    table.sort(ks)
                    for _, k in ipairs(ks) do
                      raw_short[k] = (raw_short[k] or 0) + pp.raw[k]
                      if (raw_prio[k] or -1) < T.defend_prio then raw_prio[k] = T.defend_prio end -- lot PILE-PRIORITE
                    end
                  end
                end
              end
            else
              -- Lot DEFENSE-AP : fonds de défense (shared/team/garde_ap.lua) : avant-poste de fer sans aucune tourelle.
              local crit = Ga.critical(p.iron, p.have, p.want) -- (le fer du pas de production, pri.hold, est déjà retiré de `avail` plus haut : le fonds ne prend que le reste)
              local fi_p, fc_p
              if crit then fi_p, fc_p = math.min(fl_i, Sq.FLOOR_IRON), math.min(fl_c, Sq.FLOOR_COPPER) end
              d.why = want_defense(items, fi_p, fc_p) and "fabrication" or "manque"
              if d.why == "manque" then
                d.raw = last_raw
                if crit then
                  local s0 = {}
                  for k, v in pairs(avail) do s0[k] = v end -- (copie, aucune décision n'en dépend)
                  s0[iron_key], s0[def_copper] = 0, 0
                  local cost = book:plan(items, s0).raw[iron_key] or 0 -- fer de ce qui manque (chargeurs déjà au coffre non recomptés)
                  local h = Ga.fund({ critical = true, avail = avail[iron_key] or 0, cost = cost + (fi_p or 0) }) -- coût PLUS plancher : sans lui le fer ne dépasserait jamais le seuil de fabrication
                  if h > fund_hold then fund_hold = h end
                  d.fonds = h
                end
              end
            end
          end
        end
      end
      if d then dposts[#dposts + 1] = d end
    end
    if held_taken then avail[iron_key] = (avail[iron_key] or 0) + held end
    if fund_hold > 0 then out.defense_hold = { [iron_key] = fund_hold } end -- lu par C.consumed (shared/ai3/cerveau.lua) : le cerveau ne dépense pas ce fer
    out.defend = { undefended = waiting, craftable = turret_craftable, hq = view.hq_turrets or 0, posts = dposts }
    -- Lot DEFENSE-STOCK : les tourelles qui DORMENT au coffre (au-dessus d'une petite réserve) sont posées en groupes là où l'ennemi arrive
    -- (shared/team/defense_stock.lua, script/team/defense_stock.lua : view.reserve.pick). Poste FACULTATIF et SANS fabrication : le stock
    -- seulement (coût matière 0) ; hors de out.defend.posts (lu par la pile et l'armée : aucun effet sur eux). Rien en « production d'abord »
    -- ni pour une équipe décimée. Lot rétréci au surplus et aux chargeurs RÉELLEMENT libres à ce point de la pensée (Dsr.lot).
    local rs = view.reserve
    if rs and rs.pick and not rs.busy and not open["fortify:reserve"] then
      local pk = rs.pick
      out.reserve = { key = pk.key, kind = pk.kind, have = pk.have, want = pk.want }
      local gate = Dsr.gate(pk.kind, pri.production_first, decimated) -- s44 : le stock payé se pose sur un lieu attaqué même en « production d'abord »
      if gate then
        out.reserve.why = gate
      else
        local n, each = Dsr.lot(pk.count, Dsr.surplus(avail[T.turret] or 0), pk.count, avail[T.turret_ammo] or 0)
        if n <= 0 then
          out.reserve.why = "stock"
        elseif pk.have + n < Dsr.MIN_GROUP then
          out.reserve.why = "groupe"
        else
          local items = turret_items(n, each)
          if take(items) then
            add({ key = "fortify:reserve", kind = "fortify", prio = Dsr.prio(pk.kind), outpost = "reserve", items = items, sites = pk.sites,
              pos = { x = pk.x, y = pk.y }, cell_key = pk.key, reserve = true })
            out.reserve.why, out.reserve.count = "tache_creee", n
          else
            out.reserve.why = "stock"
          end
        end
      end
    end
    -- Lot DEFENSE-CHOIX (relecture) : la levée d'urgence n'est retenue que si le QG est RÉELLEMENT servi à cette pensée (tâche de pose
    -- créée ou tourelles en fabrication). Dc.turrets juge sur le stock d'avant les recharges ; si elles ont mangé le fer (QG « fer » ou
    -- « manque »), retenir la levée laissait la base sans tourelle NI soldat à chaque pensée de l'alerte (famine). Lecteur : la levée plus bas.
    if dc.hold_soldiers then
      local served = false
      for _, d in ipairs(dposts) do
        if d.id == "hq" and (d.why == "tache_creee" or d.why == "fabrication") then served = true end
      end
      if not served then dc.hold_soldiers, dc.why = false, "non_servi" end
    end
  end
  -- R-QCM-25c (b) « L'équipe le défend » : view.hq_guards PNJ armés au coffre (guerre déclarée au joueur), relevés.
  -- QG menacé (view.hq_threat) : gardes en URGENCE (T.guard_threat_prio), courtes (T.guard_threat_ticks).
  for i = 1, view.hq_guards or 0 do
    add({ key = "garde:qg:" .. i, kind = "garrison", prio = view.hq_threat and T.guard_threat_prio or T.guard_prio,
      post = "hq", wait = view.hq_threat and T.guard_threat_ticks or T.guard_ticks })
  end

  -- Reconstruction : un avant-poste détruit (attaque d'une faction, déchiqueteurs) dont l'objectif était
  -- atteint est reconstruit. Un objectif atteint n'étant jamais réouvert, une équipe vivait sans pierre ni
  -- cuivre après la perte de son avant-poste (moteur réel, E16 it. 10). Placée avant l'objectif : les
  -- foreuses en stock vont d'abord à la reconstruction, puis aux agrandissements.
  local done0 = view.done or {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    if done0[kind] and count_kind(view, kind) == 0 and (view.pending[kind] or 0) == 0 then
      local key = "build:" .. kind
      if (view.sites[kind] or 0) > 0 then
        if not open[key] then
          -- Kit complet si le stock le permet, sinon un avant-poste minimal (2 paires) qui relance la
          -- production : sans fer, une équipe ne pouvait plus fabriquer les 8 foreuses d'un avant-poste
          -- de fer complet (moteur réel, E16 it. 11 : fer livré figé à 412 pendant 50 min).
          local items = build_items(kind, outpost_items(kind), T.outposts[kind].drills)
          local mini = build_items(kind, minimal_items(kind), math.min(2, T.outposts[kind].drills))
          if take(items) then
            add({ key = key, kind = "build", prio = 80, outpost_kind = kind, items = items })
          elseif take(mini) then
            add({ key = key, kind = "build", prio = 80, outpost_kind = kind, items = mini })
          else
            want(mini, 60, "reconstruction")
          end
        end
      else
        out.site_needs[kind] = math.max(out.site_needs[kind] or 0, 1)
      end
    end
  end

  ---------------------------------------------------------------------------------------------------
  -- 1 bis. Survie (lot IA2-a2, factions seulement : view.emergency) : AVANT l'objectif, qui pouvait vider le stock
  -- virtuel. Moteur réel (IA2-a, graine 777) : Écarlate, réduite à 1 ouvrier, garda 1 ouvrier et 0 soldat de 23 à
  -- 120 min avec jusqu'à 3 785 plaques de fer au stock : le pistolet de la recrue (fabrication, priorité 55) n'était
  -- jamais fait, son seul ouvrier enchaînant les tournées (priorité 70 à 95). Défaut connu depuis IA1-a (§6.8).
  --  - sous l'effectif de départ (emergency.floor), la recrue est équipée AU QG avec les plaques du stock
  --    (out.recruit_uses : objets prélevés, une recrue par pensée) ; sans les plaques, un 2e ouvrier sans arme est
  --    embauché (secours, comme pour une équipe vide) ; sinon l'équipement est demandé en priorité 96 ;
  --  - en reconstruction (chef) ou menacée, l'objectif « armée » atteint, la GARDE (un tiers de l'armée visée, 5 au
  --    moins) est équipée au QG de même (out.train.uses), un lot de T.kit_batch soldats par pensée.
  ---------------------------------------------------------------------------------------------------
  local em = view.emergency
  local function real_avail()
    local r = {}
    for k, n in pairs(avail) do
      local s = view.stock[k] or 0
      r[k] = n < s and n or s
    end
    return r
  end
  local function consume(uses)
    for k, n in pairs(uses) do avail[k] = (avail[k] or 0) - n end
  end
  -- Sans les plaques : minage À LA MAIN du minerai qui manque, priorité 90 (devant les tournées). 2e essai du lot
  -- (moteur réel, graine 20261020) : Azur, 2 ouvriers toujours en tournée, fer 1 pendant 55 min, jamais reconstruite
  -- (le minage à la main n'était proposé qu'aux ouvriers SANS tâche quand un avant-poste existe).
  local emerg_mine = {}
  local function emergency_mine(raw)
    for _, it in ipairs({ { "iron-plate", "iron-ore" }, { "copper-plate", "copper-ore" } }) do
      local ore = it[2]
      if (raw[it[1]] or 0) > 0 and view.smelters > 0 and not open["mine:" .. ore] and not emerg_mine[ore]
        and (view.stock[ore] or 0) < MINE_BATCH then
        emerg_mine[ore] = true
        add({ key = "mine:" .. ore, kind = "mine", prio = 90, resource = ore, count = MINE_BATCH })
      end
    end
  end
  -- Fonderie du QG détruite (4e essai, graine 3141592653 : Écarlate, fonderie 0 et fer 9 de 55 à 100 min, ouvriers
  -- inactifs : l'objectif « fonderie », atteint, n'est jamais rouvert) : reposée en priorité 92 (pierre du stock).
  if em and view.smelters + (view.smelters_pending or 0) == 0 and not open["smelters"] then
    local n = T.hq_smelters -- lot KIT : taille de la fonderie de secours (T.start_smelters vaut 0 : kit égal)
    local items = { { T.SMELTER, n }, { T.fuel, T.fuel_per_burner * n } }
    if take(items) then
      add({ key = "smelters", kind = "smelters", prio = 92, count = n, items = items })
    else
      want(items, 92, "survie")
    end
    out.emergency_smelters = true
  end
  -- Lot IA1-b2 : view.hold_recruits (perte d'un PNJ dans la dernière minute) : aucune recrue, ni de survie ni ordinaire.
  if view.hold_recruits then out.recruit_hold_loss = true end
  if em and not view.hold_recruits and not view.recruit_blocked and view.workers < (em.floor or 0) then
    local cost0 = view.recruit_cost or kit_list("worker", 1)
    if take(cost0) then
      out.recruit_workers = 1
    else
      local p = book:plan(cost0, real_avail())
      if next(p.raw) == nil then
        out.recruit_workers = 1
        out.recruit_uses = sorted_uses(p.uses)
        consume(p.uses)
      else
        if view.workers < 2 then
          out.recruit_workers = 1
          out.recruit_unarmed = true
          out.emergency_unarmed = true
        end
        want(cost0, 96, "ouvrier")
        emergency_mine(p.raw)
      end
    end
    out.emergency_recruit = true
  end
  -- Correction VERIF-NUIT (25/10, essai D2) : l'équipe du JOUEUR sous son effectif de départ (view.recover_floor)
  -- équipe elle aussi sa recrue AU QG avec les plaques du coffre (une par pensée), sans attendre qu'un ouvrier fabrique
  -- le pistolet (priorité 55, jamais servie tant que les seuls ouvriers enchaînent les tournées). Moteur réel
  -- (verif-guide, graines 271828182 et 1618033988) : sans cette règle, l'équipe restait à 1 ouvrier de 5 à 20 min,
  -- coffre plein de fer. RIEN d'autre de la survie des factions : la forme large (view.emergency donné tel quel, essai
  -- D1) reposait la fonderie du QG et minait à la main ; coffre vidé (fer 11) et équipe perdue à 57 min.
  -- EFFONDREMENT (décision du DC, 7/11 : « je veux toujours n ouvriers minimum, donc 12 si 12 au départ. Au delas ça coute des
  -- ressources ») : sous l'effectif de départ, la recrue est GRATUITE et équipée (shared/team/spirale.lua) : rien n'est pris au
  -- stock virtuel ni au coffre (out.recruit_free ; paiement sauté en E4, script/team/team.lua). Avant : payée avec les plaques du
  -- livre, et rien sans elles (partie du DC sur 0.6.58 : 2 PNJ sur 12, fer libre 0, de 133 à 177 min). AUCUN minage d'urgence pour
  -- le kit d'une recrue gratuite (relecture du lead, 7/11 après la fusion de 0102eb36 : le PNJ partait miner du fer pour un kit qui ne
  -- coûte rien ; la parité ne tient pas, la recrue des factions est payée). Filet de RECUL (décision du DC, 7/11 vers 16 h 56) :
  -- view.recul_wait (recrues gratuites tuées vite, Sp.recul_ready au runtime) : la recrue attend, et aucune recrue payée ne la
  -- remplace (§4 sauté : out.recruit_recul).
  local rf = (not em) and view.recover_floor or nil
  if rf and not view.hold_recruits and not view.recruit_blocked and Sp.free(view) then
    if view.recul_wait then
      out.recruit_recul = true
    else
      out.recruit_workers = 1
      out.recruit_free = true
      out.emergency_recruit = true
    end
  end
  if em and (em.rebuild or view.threatened or view.army_alert) and (view.done or {})["army"] then
    local guard = math.min(math.max(5, math.floor(P.army_target(view) / 3)), view.soldiers_max)
    -- Lot ARMEE-ANTICIPATION : vague annoncée : la garde équipée au QG pendant la survie couvre le besoin estimé.
    if view.army_alert and view.army_need then guard = math.min(math.max(guard, view.army_need), view.soldiers_max) end
    if view.soldiers < guard then
      local n = math.min(T.kit_batch, guard - view.soldiers)
      local units = { P.best_unit(view.tech) }
      if units[1] ~= "rifleman" then units[2] = "rifleman" end
      local last_raw_kits
      for _, unit in ipairs(units) do
        local kits = kit_list(unit, n)
        if take(kits) then
          out.train = { unit = unit, count = n }
          break
        end
        local p = book:plan(kits, real_avail())
        if next(p.raw) == nil then
          out.train = { unit = unit, count = n, uses = sorted_uses(p.uses) }
          consume(p.uses)
          break
        end
        last_raw_kits = p.raw
      end
      if not out.train and last_raw_kits then emergency_mine(last_raw_kits) end
      out.emergency_guard = guard
    end
  end

  ---------------------------------------------------------------------------------------------------
  -- 2. Objectif : premier palier non atteint
  ---------------------------------------------------------------------------------------------------
  local done = view.done or {}
  local goal, parts
  local deferred = view.deferred or {}
  local ladder = view.ladder or T.ladder
  for _, g in ipairs(ladder) do
    if not done[g.key] and not deferred[g.key] then
      local reached, p = goal_status(g, view)
      if reached then
        out.reached[#out.reached + 1] = g.key
      elseif Pr.skip_goal(pri, g.need, T.turret_ammo) then
        -- Lot PRIORITE-RESSOURCES : le fer ne paie pas la défense ET la production : un objectif MILITAIRE (armée, fortifier,
        -- munitions) passe après les objectifs de production (il revient dès que le fer paie les deux). Sauté, ni atteint ni retenu.
        out.skipped_goals = (out.skipped_goals or 0) + 1
      else
        goal, parts = g, p
        break
      end
    end
  end
  out.goal = goal and goal.key or nil

  -- Anticipation : on prospecte aussi pour les deux prochains paliers d'avant-postes (un site se trouve
  -- en arrière-plan ; l'attendre au dernier moment coûtait plusieurs minutes par palier).
  do
    local seen, ahead = false, 0
    for _, g in ipairs(view.ladder or T.ladder) do
      if g == goal then seen = true end
      if seen and g ~= goal and g.need.outposts and ahead < 2 then
        ahead = ahead + 1
        for _, kind in ipairs(T.OUTPOST_ORDER) do -- ordre fixe (lot IA1-a ; résultat inchangé : un maximum)
          local n = g.need.outposts[kind]
          local missing_n = n and (n - capacity(view, kind) - (view.pending[kind] or 0)) or 0
          if missing_n > 0 then out.site_needs[kind] = math.max(out.site_needs[kind] or 0, 1) end
        end
      end
    end
  end

  local missing_index = {}
  local function add_missing(raw)
    local ks = {}
    for k in pairs(raw) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do
      local i = missing_index[k]
      if i then
        out.missing[i][2] = out.missing[i][2] + math.ceil(raw[k])
      else
        out.missing[#out.missing + 1] = { k, math.ceil(raw[k]) }
        missing_index[k] = #out.missing
      end
    end
  end

  local army_now = false
  local research_now = false
  if goal then
    for _, part in ipairs(parts) do
      if part.outpost and Th.raw_full(T.outposts[part.outpost], view.stock) then
        -- lot THERMIQUE2 (essai 3) : minerai brut plein (stock libre au seuil) : ni agrandissement ni avant-poste en brûleurs
        out.raw_full = out.raw_full or {}
        out.raw_full[part.outpost] = true
      elseif part.outpost then
        local kind = part.outpost
        local items = outpost_items(kind)
        local ext = extendable(view, kind, undefended)
        if ext then
          -- D'abord agrandir un avant-poste existant : pas de prospection, trajets connus.
          if take(items) then
            add({ key = "extend:" .. ext.id, kind = "extend", prio = 80, outpost = ext.id, outpost_kind = kind, items = items })
          elseif not want(items, 50, "objectif") then
            add_missing(last_raw)
          end
        elseif df and extendable(view, kind) then -- (avant-poste non défendu ou meurtrier : il attend)
          -- Lot IA1-b2 : l'avant-poste à agrandir attend ses tourelles (tâche « fortify » plus haut).
          add_missing({ ["gun-turret"] = 1 })
        else
          local sites = view.sites[kind] or 0
          out.site_needs[kind] = (out.site_needs[kind] or 0) + part.n
          local list = build_items(kind, items, T.outposts[kind].drills)
          if not list then
            add_missing({ ["gun-turret"] = T.defend_turrets(T.outposts[kind].drills) })
          elseif sites > 0 and take(list) then
            add({ key = "build:" .. kind, kind = "build", prio = 80, outpost_kind = kind, items = list })
          elseif not want(list, 50, "objectif") then
            add_missing(last_raw)
          end
          if sites == 0 then add_missing({ ["site:" .. kind] = 1 }) end
        end
      elseif part.smelters and not out.emergency_smelters then -- lot IA2-a2 : fonderie déjà reposée (survie)
        local items = { { T.SMELTER, part.smelters }, { T.fuel, T.fuel_per_burner * part.smelters } }
        if take(items) then
          add({ key = "smelters", kind = "smelters", prio = 80, count = part.smelters, items = items })
        elseif not want(items, 50, "objectif") then
          add_missing(last_raw)
        end
      elseif part.item then
        if not want({ { part.item, part.n } }, 50, "objectif", true) then add_missing(last_raw) end
      elseif part.soldiers then
        army_now = true
      elseif part.tech then
        research_now = true
      elseif part.fortify and df and lacking[part.fortify] then
        -- Lot IA1-b2 : déjà demandé en urgence (défendre d'abord, plus haut) ; seul le manque s'affiche.
        if not turret_craftable and (avail["gun-turret"] or 0) == 0 then add_missing({ ["gun-turret"] = part.n }) end
      elseif part.fortify then
        local items = { { "gun-turret", part.n }, { base_ammo, part.n * T.turret_ammo_target } }
        if take(items) then
          add({ key = "fortify:" .. part.fortify, kind = "fortify", prio = 75, outpost = part.fortify, items = items })
        elseif not want(items, 50, "objectif") then
          add_missing(last_raw)
        end
      end
    end
  end

  ---------------------------------------------------------------------------------------------------
  -- 3. Fonderie du QG : production demandée (acier, briques ; plaques si aucun avant-poste)
  ---------------------------------------------------------------------------------------------------
  -- (les besoins en matières premières sont connus après les demandes : on les traite en fin de plan)

  ---------------------------------------------------------------------------------------------------
  -- 4. Ouvriers, armée, recherche (fond permanent, par ordre de priorité)
  ---------------------------------------------------------------------------------------------------
  -- Lot IA1-a (Q-IA1-2 (2), « 30 dès l'époque 1 ») : le runtime donne `workers_wanted` (le plafond de l'époque,
  -- shared/team/scale.lua) et le coût d'une recrue `recruit_cost` (kit + (10 + effectif) fer) : seul le stock
  -- freine. Sans ces champs (vues construites par les tests d'avant IA1-a) : règle d'avant, 2 + 1 par
  -- avant-poste, recrue au prix du kit. `recruit_blocked` : garde d'agents (fo-agents-max) atteinte.
  local workers_wanted = view.workers_wanted or T.workers_wanted(#view.outposts, view.workers_max)
  local recruit_cost = view.recruit_cost or kit_list("worker", 1)
  if view.workers < workers_wanted and not out.emergency_recruit and not view.hold_recruits
    and not out.recruit_recul then -- lot IA2-a2 : la survie a déjà décidé ; EFFONDREMENT : recrue gratuite en recul
    if view.recruit_blocked then
      out.recruit_blocked = true
      if view.workers == 0 then
        -- Secours conservé sous la garde d'agents : un seul PNJ, sans arme, pour une équipe vide.
        out.recruit_workers = 1
        out.recruit_unarmed = true
      end
    elseif view.recruit_held and view.workers > 0 then
      -- Correction IA1-a (frein par le travail, réglage fo-recruit-idle-max) : trop de PNJ sans tâche, aucune
      -- recrue ; le stock n'est ni pris ni demandé (pas de pistolet fabriqué pour une recrue inutile).
      out.recruit_held = true
    elseif (view.iron_reserve or view.grow_reserve) and view.workers >= (view.recover_floor or 0)
      and (avail["iron-plate"] or 0) < (view.iron_reserve or view.grow_reserve) + (function()
        local n = 0
        for _, it in ipairs(recruit_cost) do if it[1] == "iron-plate" then n = n + it[2] end end
        return n
      end)() then
      -- Lot IA1-b2 : votre équipe ne GRANDIT (au-delà de son effectif de départ) qu'en gardant view.iron_reserve (lot FER-EQUIPE :
      -- shared/team/fer_equipe.lua ; à défaut view.grow_reserve) plaques de fer au coffre (munitions, tourelles, recrues de survie). Essai 6, ia1b2-guide graine 577215664 : 8 -> 14 PNJ
      -- de 17 à 25 min, fer à 56, QG perdu à 52 min.
      out.recruit_held = true
      out.grow_short = true
    elseif take(recruit_cost) then
      out.recruit_workers = 1
    elseif view.workers == 0 then
      -- Secours (moteur réel, E16 it. 9) : une équipe dont tous les ouvriers sont morts ne pouvait plus
      -- rien fabriquer, pas même le pistolet d'un nouvel ouvrier. Le QG embauche un ouvrier SANS arme.
      out.recruit_workers = 1
      out.recruit_unarmed = true
    else
      want(recruit_cost, view.recruit_prio or 55, "ouvrier") -- lot IA3-d : priorité du travail que la recrue débloque
    end
  end

  local army_goal_passed = done["army"] or army_now
  -- Lot DEFENSE-CHOIX : la pensée qui commande les tourelles du QG (dc.hold_soldiers) ne lance pas aussi la levée d'urgence ; elle
  -- reprend à la pensée suivante (tâche de pose ouverte) avec le fer qui reste. L'armée ordinaire (army_goal_passed) n'est pas touchée.
  local surge = view.threatened and not dc.hold_soldiers
  -- Lot ARMEE-ANTICIPATION (« recruter un maximum de soldats », DC 29/10) : une vague annoncée (view.army_alert) arme l'équipe
  -- AVANT la première perte, jusqu'au besoin estimé (view.army_need), avec la priorité de la défense (protéger avant produire)
  -- tant que l'effectif est SOUS ce besoin ; au-delà, l'armée visée ordinaire garde sa priorité (45 : produire d'abord).
  -- (Intégration 0.6.20, résolution proposée par DEFENSE-CHOIX : `surge` remplace `view.threatened` ; la levée anticipée reste entière.)
  local alert_need = (view.army_alert and view.army_need) or 0
  local urgent = surge or view.soldiers < alert_need
  -- Lot PREVISION : armée visée à MOYEN terme (vague prévue à 15 min qui dépasse les tourelles, script/ai3/prevision.lua) : relève la
  -- cible ordinaire, à la priorité ordinaire (45 : produire d'abord) ; seule l'alerte (vague imminente) a la priorité de la défense.
  local soon = view.army_soon or 0
  if surge or alert_need > 0 or soon > 0 or army_goal_passed then
    local target = surge and math.max(P.army_target(view), view.soldiers + T.kit_batch)
      or (army_goal_passed and P.army_target(view) or 0)
    if alert_need > target then target = alert_need end
    if soon > target then target = soon end
    if army_now and goal and goal.need.soldiers then target = math.max(target, goal.need.soldiers) end
    target = math.min(target, view.soldiers_max)
    if view.soldiers < target and not out.train then -- lot IA2-a2 : garde déjà équipée au QG à cette pensée
      local unit = P.best_unit(view.tech)
      local n = math.min(T.kit_batch, target - view.soldiers)
      local kits = kit_list(unit, n)
      if take(kits) then
        out.train = { unit = unit, count = n }
      else
        -- Repli sur le fusilier si l'équipement du meilleur soldat n'est pas encore fabricable.
        local ok = want(kits, urgent and 85 or 45, "armee")
        if not ok and army_now then add_missing(last_raw) end
        if not ok and unit ~= "rifleman" then
          local fallback = kit_list("rifleman", n)
          if take(fallback) then out.train = { unit = "rifleman", count = n } else want(fallback, 45, "armee") end
        end
      end
    end
  end

  local next_tech = view.tech + 1
  if not view.no_research and (research_now or done["tech1"]) and T.research[next_tech] then
    local packs = T.research[next_tech]
    local have_all = true
    for _, it in ipairs(packs) do
      if (view.stock[it[1]] or 0) < it[2] then have_all = false break end
    end
    if have_all then
      out.research = next_tech
    else
      local short = {}
      for _, it in ipairs(packs) do
        local h = view.stock[it[1]] or 0
        if h < it[2] then short[#short + 1] = { it[1], math.min(10, it[2] - h) } end
      end
      if not want(short, 40, "recherche", true) and research_now then add_missing(last_raw) end
    end
  end

  -- Réserve de munitions pour les tourelles.
  if (view.stock[ammo] or 0) < 40 then want({ { ammo, 20 } }, 35, "reserve", true) end

  -- Lot MUNITIONS : le SURPLUS de la cible riche, APRÈS les recrues, l'armée et la recherche (dernier usage du fer de la section 4) : la
  -- tournée prend ce qui reste au coffre (au plus le surplus), le reste se fabrique à Mu.SURPLUS_PRIO avec le fer que les recrues n'ont pas pris.
  for _, sp in ipairs(surplus) do
    local stock = avail[ammo] or 0
    local got = math.min(sp.n, stock)
    if sp.task then
      sp.task.count = sp.task.count + got
    elseif got >= Mu.TRIP_MIN or (got > 0 and (sp.g.low or 0) > 0) then
      add({ key = "refill:" .. sp.g.key, kind = "refill", prio = 90, group = sp.g.key, count = got })
    else
      got = 0
    end
    avail[ammo] = stock - got
    if got < sp.n then want({ { ammo, sp.n - got } }, Mu.SURPLUS_PRIO, "munitions-surplus") end
  end
  -- Lot MUNITIONS : ÉCHANGE des tourelles pleines d'une munition moins bonne (balles perforantes dès qu'elles se fabriquent ; partie du DC :
  -- « military-2 » faite à 116 min, inutile), avec le stock seulement (Mu.upgrade_take : rien n'est fabriqué pour cela), après les recrues.
  for _, g in ipairs(view.turret_groups or {}) do
    if (g.worse or 0) > 0 and not g.has_task then
      local stock = avail[ammo] or 0
      local got = Mu.upgrade_take(g.worse_need, stock)
      if got > 0 then
        local t = nil
        for _, x in ipairs(tasks) do if x.key == "refill:" .. g.key then t = x break end end
        if t then t.count = (t.count or 0) + got
        else add({ key = "refill:" .. g.key, kind = "refill", prio = 90, group = g.key, count = got }) end
        avail[ammo] = stock - got
      end
    end
  end

  ---------------------------------------------------------------------------------------------------
  -- 5. Matières premières manquantes : avant-poste existant (on attend sa tournée), fonderie, minage
  ---------------------------------------------------------------------------------------------------
  local raws = {}
  for k in pairs(raw_short) do raws[#raws + 1] = k end
  table.sort(raws)
  -- Lot PILE-PRIORITE (ajout pur) : chaque matière manquante avec la priorité la plus haute de ses demandeurs (défense 90,
  -- survie, reconstruction 60…). Lecteur : shared/ai3/cerveau.lua (C.think) -> shared/ai3/pile.lua (Pi.signals) : les
  -- manques des rangs R0 et R1 passent au cerveau par besoins avec leur priorité (fonte, minage, croissance de l'extraction).
  out.raw_need = {}
  for _, k in ipairs(raws) do out.raw_need[k] = { n = raw_short[k], prio = raw_prio[k] or 0 } end
  -- Ouvriers sans tâche : ils minent à la main la matière qui manque le plus (comme un joueur au début),
  -- le minerai est fondu dans la fonderie du QG. Moteur réel (session 4) : sans cela, une équipe privée de
  -- plaques de fer (avant-poste de fer perdu ou introuvable) restait bloquée pour toute la partie.
  local idle = view.workers_idle or 0
  local mines = 0
  for _, item in ipairs(raws) do
    local n = raw_short[item]
    local src = SOURCE[item]
    if src then
      local has_outpost = src.outpost and count_kind(view, src.outpost) > 0
      if src.smelt then
        if view.smelters > 0 then out.smelt[src.smelt] = (out.smelt[src.smelt] or 0) + n end
        local ore = T.smelter_inputs[src.smelt][1]
        local minable = src.mine and src.mine ~= item
        if minable and view.smelters > 0 and (view.stock[ore] or 0) < n and (not has_outpost or idle > mines)
          and not open["mine:" .. ore] and not emerg_mine[ore] then
          add({ key = "mine:" .. ore, kind = "mine", prio = has_outpost and 25 or 45, resource = ore, count = math.min(MINE_BATCH, math.max(n, MINE_MIN)), short = n })
          mines = mines + 1
        end
      elseif src.mine == item and (not has_outpost or idle > mines) and not open["mine:" .. item] and not emerg_mine[item] then
        add({ key = "mine:" .. item, kind = "mine", prio = has_outpost and 25 or 45, resource = item, count = math.min(MINE_BATCH, math.max(n, MINE_MIN)), short = n })
        mines = mines + 1
      end
    else
      out.unreachable = out.unreachable or {}
      out.unreachable[#out.unreachable + 1] = item
    end
  end

  -- Goulot d'étranglement : une plaque qui manque durablement (plus de 120 en attente) fait agrandir son
  -- avant-poste, même hors de l'échelle d'objectifs. Moteur réel (session 4) : le fer manquait à toutes
  -- les équipes (cuivre et pierre s'entassaient), l'armée restait à 0-5 soldats à 30 min.
  for _, item in ipairs({ "iron-plate", "copper-plate" }) do
    local short = raw_short[item] or 0
    local kind = item == "iron-plate" and "iron" or "copper"
    if short > 120 and (view.pending[kind] or 0) == 0 then
      local items = outpost_items(kind)
      local ext = extendable(view, kind, undefended)
      local waits = not ext and df and extendable(view, kind) ~= nil -- lot IA1-b2 : agrandissement après les tourelles
      if not ext and not waits then items = build_items(kind, items, T.outposts[kind].drills) end
      local key = ext and ("extend:" .. ext.id) or ("build:" .. kind)
      if items and not waits and not open[key] and (ext or (view.sites[kind] or 0) > 0) and take(items) then
        add({ key = key, kind = ext and "extend" or "build", prio = 78, outpost = ext and ext.id or nil, outpost_kind = kind, items = items })
      elseif not ext and not waits then
        out.site_needs[kind] = math.max(out.site_needs[kind] or 0, 1)
      end
    end
  end

  -- Lot IA2-b (F209) : réceptacles orphelins d'un avant-poste perdu depuis 30 min et pas reconstruit : un ouvrier va les
  -- démonter (objets et contenu rapportés au QG). Priorité basse : après tout le reste, sauf le minage d'appoint.
  for _, g in ipairs(view.orphans or {}) do
    add({ key = "salvage:" .. g.oid, kind = "salvage", prio = 30, orphan = g.oid, pos = { x = g.x, y = g.y } })
  end

  -- Fonderie : une tournée si elle a quelque chose à produire, à vider ou à ravitailler.
  if view.smelters > 0 and not view.smelter_task then
    if next(out.smelt) ~= nil or view.smelter_output > 0 or view.smelter_fuel_low then
      add({ key = "smelt", kind = "smelt", prio = view.smelter_fuel_low and 65 or 60, smelt = out.smelt })
    end
  end

  table.sort(tasks, function(a, b)
    if a.prio ~= b.prio then return a.prio > b.prio end
    return a.key < b.key
  end)
  return out
end

return P
