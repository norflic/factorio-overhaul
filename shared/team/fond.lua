--[[
  TRAVAIL DE FOND des équipes de PNJ (lot IA1-b, docs/EQUIPES_PNJ.md §4.2 point 3) : PUR (aucune API Factorio).

  « Les exécutants au-delà du carnet vont aux pôles selon la seule orientation, et le cerveau leur ouvre des tâches
  de fond (agrandir, prospecter, renforcer). » Chaque manager propose, dans l'ordre de sa préférence, les tâches de
  fond que le stock et la carte permettent AUJOURD'HUI ; le runtime (script/team/poles.lua) n'en ouvre que ce qu'il
  faut pour les PNJ inactifs de chaque pôle, plus une marge. Le nombre de candidats d'un pôle est sa CAPACITÉ de
  fond (`room` d'O.plan) : un pôle qui n'a plus rien à ouvrir (stock vide) ne reçoit plus de surplus.

  Ce module n'invente aucune tâche nouvelle pour le cerveau (shared/team/planner.lua) : les verbes sont ceux des
  ouvriers (extend, build, smelt, mine, craft), plus `garrison` (garde d'un avant-poste, autodéfense des PNJ).
    Extraction (gisements)  : agrandir un avant-poste (2 paires foreuse + réceptacle), construire un avant-poste
                              sur un site connu, fondre le minerai du QG, miner à la main (plafonné, §4.5) ;
    Base (production)       : fabriquer une RÉSERVE de biens d'équipement (foreuses, fours, coffres, chargeurs)
                              qui sert aux agrandissements suivants (capital) ;
    Territoire (défense)    : garnison aux avant-postes et au QG (le PNJ tire sur ce qui approche, rayon 18).
  Toute tâche rendue porte `fond = true` (elle n'entre pas dans le besoin d'O.plan, sinon le fond nourrirait sa
  propre demande) et son domaine.

  F.candidates(view, free, ctx) -> { extraction = {...}, base = {...}, territoire = {...} } listes ordonnées
    view : vue du cerveau (shared/team/planner.lua : outposts, sites, smelters, stock, incoming) ;
    free : stock LIBRE (stock du QG moins ce que les tâches ouvertes du cerveau y ont réservé ; table modifiée) ;
    ctx  : { book (livre de recettes, shared/team/book.lua), keys = { [clé] = vrai } (tâches déjà au tableau),
             mine_left = minages à la main encore permis (plafond O.manual_cap moins ceux en cours),
             reserve = surcharge de F.RESERVE (facultatif),
             lot FER-EQUIPE : iron_extra = { res, n } (minages de fer de renfort pour les inactifs),
             lot IA1-b2 (D-17) : defend_first (tourelle possible : un nouvel avant-poste se bâtit avec ses tourelles),
             undefended = { [id] = vrai } avant-postes où l'on ne va pas (shared/team/planner.lua, P.no_go),
             turrets_ok, no_outpost_guard (votre équipe : plus de garde d'avant-poste), no_reserve_floor,
             lot SITE-PROCHE (R4) : saturated = { [produit] = vrai } (matières saturées du cerveau, `f.team.ia3.saturated`) :
             le fond ne BÂTIT plus d'avant-poste d'un produit saturé, même quand aucune autre matière ne manque }.
  Lot SCALE-COMPLET : F.candidates ÉCRIT ctx.far_builds = { { kind, d_room, d_site }, ... } (builds lointains refusés par
  F.far_build ; lecteur : le journal [FO-LOIN] de script/team/poles.lua).
  Déterminisme : avant-postes dans l'ordre de la vue (id), types dans T.OUTPOST_ORDER, ressources dans un ordre fixe,
  aucun `pairs` dans une décision.
]]

local T = require("shared.team.config")
local ChaineMain = require("shared.team.chaine_main") -- lot FOURS : pas de tournée de fonte à vide
local V = require("shared.faction.valeur") -- lot SITE-PROCHE : V.extension_refused (R1)

local F = {}

-- Priorités du fond : sous tout le travail du cerveau (minage d'appoint 25 compris). La garde passe en dernier : elle ne
-- produit rien tant qu'aucune menace n'approche (essai 1 du banc ia1-poles : 37 % du temps en garde, F239 proposé).
F.PRIO = { extend = 24, build = 23, craft = 22, smelt = 21, transport = 21, mine = 20, garrison = 18 }
F.PAIRS = 2              -- un agrandissement de fond pose 2 paires (foreuse + réceptacle)
F.MINE_BATCH = 50        -- minage à la main : 50 unités par sortie (comme le cerveau)
F.SMELT_MIN = 10         -- minerai au QG qui justifie une tournée de fonderie de fond
F.SMELT_BATCH = 50
F.GARRISON_TICKS = 3600  -- une garde dure 60 s sur place
F.GARRISON_PER_POST = 1  -- une garde par avant-poste (et une au QG)
F.CRAFT_BATCH = 10       -- une fabrication de fond : 10 objets (essai 1 : 4 objets = 8 s de travail, trop court)
F.CRAFT_TASKS = 8        -- au plus 8 fabrications de fond par objet et par pensée
F.AHEAD = 8              -- lot COFFRE : paires d'avance au plus pour la réserve de biens d'équipement (F.potential)
-- Lot ADOPTE : VOTRE équipe garde moins de paires d'avance que les factions (graine 123456789, 60 min : 8 fours et 8 foreuses d'avance
-- restaient au coffre toute la partie, les « 12 fours dormants » du constat du DC ; ses extensions réussissent, la réserve ne sert
-- qu'à gagner quelques secondes de fabrication).
F.PLAYER_AHEAD = 4
-- Réserve de biens d'équipement visée (stock + fabrications en cours), ordre FIXE (celui des préférences) : au moins
-- `min`, et autant que les agrandissements possibles (paires restantes des avant-postes + sites connus), au plus `max`.
F.RESERVE = {
  { "burner-mining-drill", 8, 40 },
  { "stone-furnace", 8, 40 },
  { "iron-chest", 4, 12 },
  { "firearm-magazine", 40, 40 },
}
-- Biens d'équipement (posés aux avant-postes) : leur réserve suit les places à poser (F.potential).
F.EQUIPMENT = { ["burner-mining-drill"] = true, ["stone-furnace"] = true, ["iron-chest"] = true }
-- Lot IA1-b2 (R-QCM-25c (c), « Donner du travail ») : réserve de VOTRE équipe, travail du pôle Base au coffre : les biens
-- d'équipement, plus des chargeurs (tourelles, recrues, joueur) et des engrenages pour le joueur.
F.PLAYER_RESERVE = {
  { "burner-mining-drill", 8, 40 },
  { "stone-furnace", 8, 40 },
  { "iron-chest", 4, 12 },
  { "firearm-magazine", 200, 200 },
  { "iron-gear-wheel", 100, 100 },
}
-- Plancher laissé au cerveau : le fond ne fabrique pas avec les dernières plaques (objectifs, recherche, armée).
F.FLOOR = { ["iron-plate"] = 200, ["copper-plate"] = 50, ["stone"] = 50 }
-- Minage à la main : ressources dans un ordre fixe et stock de référence (la plus en manque d'abord ; le minerai ne
-- sert que s'il y a des fours au QG). Toujours permis dans le plafond du travail manuel (§4.5) : c'est de la matière.
F.MINE_TARGETS = {
  { "coal", 400, false }, { "stone", 200, false }, { "iron-ore", 200, true }, { "copper-ore", 100, true },
}

local function sorted_uses(uses)
  local ks = {}
  for k in pairs(uses) do ks[#ks + 1] = k end
  table.sort(ks)
  local out = {}
  for _, k in ipairs(ks) do out[#out + 1] = { k, uses[k] } end
  return out
end

local function has(free, list)
  for _, it in ipairs(list) do
    if (free[it[1]] or 0) < it[2] then return false end
  end
  return true
end

local function take(free, list)
  for _, it in ipairs(list) do free[it[1]] = (free[it[1]] or 0) - it[2] end
end

--- Objets d'un agrandissement ou d'un petit avant-poste de `pairs` paires (combustible compris, comme le cerveau).
function F.pair_items(kind, pairs)
  local spec = T.outposts[kind]
  local fuel = kind == "coal" and 2 * pairs or T.fuel_per_burner * pairs * (spec.sink == "stone-furnace" and 2 or 1)
  return { { T.DRILL, pairs }, { spec.sink, pairs }, { T.fuel, fuel } }
end

--- Lot IA1-b2 (défendre d'abord) : tourelles d'un nouvel avant-poste de `pairs` paires, ajoutées à `items` si le stock
--- libre les a ; nil sinon (le fond ne construit pas d'avant-poste non défendu). Sans ctx.defend_first : `items`.
local function with_turrets(free, ctx, items, np)
  if not ctx.defend_first then return items end
  local n = T.defend_turrets(np)
  local all = {}
  for _, it in ipairs(items) do all[#all + 1] = it end
  all[#all + 1] = { "gun-turret", n }
  all[#all + 1] = { T.turret_ammo, n * T.defend_ammo }
  if has(free, all) then return all end
  return nil
end

--- Lot SITE-PROCHE (R4) : vrai si le produit de ce type d'avant-poste est SATURÉ (ctx.saturated) : le fond n'y bâtit pas
--- de nouvel avant-poste (agrandir et miner restent permis : proches). Le retrait du fond saturé par le cerveau
--- (script/ai3/cerveau.lua, Ia3.after_poles) est désarmé quand aucune autre matière ne manque ; celui-ci ne l'est pas.
function F.saturated_build(ctx, kind)
  local sat = ctx and ctx.saturated
  local spec = T.outposts[kind]
  return sat ~= nil and spec ~= nil and sat[spec.product] == true
end

--- Lot SITE-PROCHE (R1) : vrai si l'avant-poste `o` est trop LOIN pour que le fond l'agrandisse parce qu'un site admissible
--- de la même ressource est connu bien plus près (V.extension_refused, `view.sites_near`, factions seulement) : le fond
--- bâtit alors au site proche (ni agrandissement, ni « il reste de la place » qui interdit le build).
function F.far_from_site(view, o)
  local near = view.sites_near and view.sites_near[o.kind] or nil
  return near ~= nil and V.extension_refused(math.sqrt(o.d2 or 0), near)
end

--- Lot SCALE-COMPLET (retour du DC du 29/10, 21 h 40, Écarlate en 0.6.18 : avant-poste de charbon n° 5 bâti à 157 tuiles vers
--- 27 min alors que le charbon de départ, à 42 tuiles, n'était couvert qu'à 243 pour mille) : vrai si un NOUVEL avant-poste de
--- ce type serait LOINTAIN alors qu'un avant-poste du type a encore des places, plus près (V.build_refused : à moins de 0,6 × la
--- distance du site admissible le plus proche, `view.sites_near`, et 60 tuiles plus près ; factions seulement). L'avant-poste
--- proche compte même dangereux ou non défendu : on l'agrandit quand il redevient sûr (ou le lot NETTOYAGE-SITE le dégage), on
--- ne part pas au loin. Rend aussi les deux distances (journal [FO-LOIN] de script/team/poles.lua).
function F.far_build(view, kind)
  local near = view.sites_near and view.sites_near[kind] or nil
  local d_room = V.room_distance(view.outposts, kind, T.max_drills(kind))
  if V.build_refused(d_room, near) then return true, d_room, near end
  return false
end

local function extraction(view, free, ctx, out)
  local keys = ctx.keys or {}
  -- Prudence (pertes récentes de PNJ, script/team/poles.lua) : rien hors du QG ; seule la fonderie du QG reste.
  local prudent = ctx.prudent
  -- 1. Agrandir (le plus ancien avant-poste d'abord). Lot IA1-b2 : jamais un avant-poste non défendu (ctx.undefended).
  local extendable = {}
  local danger = ctx.danger or {}
  local undefended = ctx.undefended or {}
  -- R-QCM-25c (c) : ctx.safe_only (votre équipe à son effectif de départ, sans tourelle possible) : ni agrandir ni bâtir
  -- (l'expansion sans défense perdait l'équipe, essais 2 et 5 du lot) ; transport, fonderie, minage près du coffre.
  local safe = ctx.safe_only
  for _, o in ipairs(view.outposts or {}) do
    local room = T.max_drills(o.kind) - (o.drills or 0)
    if F.far_from_site(view, o) then room = 0 end -- lot SITE-PROCHE (R1) : site proche libre, on n'agrandit pas le lointain
    if undefended[o.id] and not o.full and room > 0 then extendable[o.kind] = true end -- il attend ses tourelles
    if not o.full and room > 0 and not danger[o.id] and not undefended[o.id] and not prudent and not safe then
      extendable[o.kind] = true
      local key = "extend:" .. o.id
      local items = F.pair_items(o.kind, math.min(F.PAIRS, room))
      if not keys[key] and has(free, items) then
        take(free, items)
        out[#out + 1] = { key = key, kind = "extend", prio = F.PRIO.extend, outpost = o.id, outpost_kind = o.kind,
          items = items, fond = true, domain = "gisements" }
      end
    end
  end
  -- 2. Construire un avant-poste là où plus aucun ne peut s'agrandir (site déjà connu).
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local key = "build:" .. kind
    local pairs_n = math.min(F.PAIRS, T.outposts[kind].drills)
    local items = with_turrets(free, ctx, F.pair_items(kind, pairs_n), pairs_n)
    local far, d_room, d_site = false, nil, nil
    if items and not prudent and not safe and not extendable[kind] and (view.sites and view.sites[kind] or 0) > 0 then
      far, d_room, d_site = F.far_build(view, kind) -- lot SCALE-COMPLET
      if far then
        ctx.far_builds = ctx.far_builds or {}
        ctx.far_builds[#ctx.far_builds + 1] = { kind = kind, d_room = d_room, d_site = d_site }
      end
    end
    if items and not prudent and not safe and not extendable[kind] and (view.sites and view.sites[kind] or 0) > 0
      and not far and not F.saturated_build(ctx, kind) and not keys[key] and has(free, items) then
      take(free, items)
      out[#out + 1] = { key = key, kind = "build", prio = F.PRIO.build, outpost_kind = kind, items = items,
        fond = true, domain = "gisements" }
    end
  end
  -- 3. Fondre le minerai rapporté au QG.
  if (view.smelters or 0) > 0 and not keys["smelt"] then
    local smelt, any = {}, false
    for _, p in ipairs({ "iron-plate", "copper-plate" }) do
      local input = T.smelter_inputs[p]
      local ore = input and (free[input[1]] or 0) or 0
      if ore >= F.SMELT_MIN then
        smelt[p] = math.min(F.SMELT_BATCH, math.floor(ore / input[2]))
        any = true
      end
    end
    -- Lot FOURS : et seulement si la tournée sert (view.four_rule : fours libres ou à compléter, shared/team/chaine_main.lua).
    if any and view.four_rule and not ChaineMain.smelt_worth({ smelt = smelt, inputs = T.smelter_inputs, stock = free,
      output = view.smelter_output, fuel_low = view.smelter_fuel_low, fuel_stock = free[T.fuel] or 0, free = view.smelters_free,
      loads = view.smelter_loads, collect_min = T.smelt_collect_min }) then
      any = false
    end
    if any then
      out[#out + 1] = { key = "smelt", kind = "smelt", prio = F.PRIO.smelt, smelt = smelt, fond = true, domain = "gisements" }
    end
  end
  -- 3 bis. R-QCM-25c (c) « transporter entre avant-postes et coffre » (ctx.transport) : tournée de fond d'un avant-poste
  -- qui a au moins T.transport_min objets à rapporter, ni dangereux ni « où l'on ne va pas » ; sans tourelle possible
  -- (ctx.transport_d2), seulement à moins de T.transport_near tuiles du QG. Même clé que la tournée du cerveau.
  -- Deux porteurs au plus par avant-poste (le second : clé « fond:transport:<id> », dès 2 × T.transport_min objets).
  if ctx.transport and not prudent then
    for _, o in ipairs(view.outposts or {}) do
      local out_n = o.output or 0
      if not danger[o.id] and not undefended[o.id] and out_n >= T.transport_min
        and (not ctx.transport_d2 or (o.d2 or 0) <= ctx.transport_d2) then
        local key = "service:" .. o.id
        if not o.has_task and not keys[key] then
          out[#out + 1] = { key = key, kind = "service", prio = F.PRIO.transport, outpost = o.id, fond = true,
            domain = "gisements" }
        end
        -- Porteurs suivants (2 à T.transport_porters) : le k-ième dès k × T.transport_min objets à rapporter.
        for k = 2, T.transport_porters do
          local key2 = k == 2 and ("fond:transport:" .. o.id) or ("fond:transport:" .. o.id .. ":" .. k)
          if out_n >= k * T.transport_min and not keys[key2] then
            out[#out + 1] = { key = key2, kind = "service", prio = F.PRIO.transport, outpost = o.id, fond = true,
              domain = "gisements" }
          end
        end
      end
    end
  end
  -- 4. Miner à la main (plafond du travail manuel, §4.5) : la ressource la plus en manque d'abord, puis à tour de rôle.
  local left = prudent and 0 or (ctx.mine_left or 0)
  if left > 0 then
    local list = {}
    for i, m in ipairs(F.MINE_TARGETS) do
      if (not m[3] or (view.smelters or 0) > 0) and not (ctx.mine_skip and ctx.mine_skip[m[1]]) then
        local have = math.max(0, free[m[1]] or 0)
        list[#list + 1] = { res = m[1], gap = math.floor(math.max(0, m[2] - have) * 1000 / m[2]), i = i }
      end
    end
    table.sort(list, function(a, b)
      if a.gap ~= b.gap then return a.gap > b.gap end
      return a.i < b.i
    end)
    local k = 0
    while left > 0 and #list > 0 do
      k = k + 1
      local m = list[(k - 1) % #list + 1]
      local key = "fond:mine:" .. m.res .. ":" .. k
      if not keys[key] then
        out[#out + 1] = { key = key, kind = "mine", prio = F.PRIO.mine, resource = m.res, count = F.MINE_BATCH,
          fond = true, domain = "gisements", radius = ctx.mine_radius }
        left = left - 1
      end
      if k > 64 then break end
    end
  end
  -- 4 bis. Lot FER-EQUIPE (ctx.iron_extra = { res, n }, shared/team/fer_equipe.lua) : minage à la main de renfort pour le
  -- PNJ inactif, hors du plafond du travail manuel ; clés propres, jamais deux fois sur le tableau.
  for _, t in ipairs(F.iron_extra_tasks({ iron_extra = ctx.iron_extra, keys = keys, mine_skip = ctx.mine_skip, prudent = prudent,
    mine_radius = ctx.mine_radius })) do
    out[#out + 1] = t
  end
end

--- Lot FER-EQUIPE : tâches de minage de fer de renfort (ctx.iron_extra = { res, n }, ctx.keys, ctx.mine_skip, ctx.prudent,
--- ctx.mine_radius). À part : script/team/poles.lua l'appelle aussi quand le fond est COUPÉ (votre équipe sous son effectif de
--- départ, qui ne peut plus recruter faute de fer : parties du 29/10, 6 PNJ sur 8, 100 % inactifs, fer à 0 pendant 34 min).
function F.iron_extra_tasks(ctx)
  local out = {}
  local ie = ctx.iron_extra
  local keys = ctx.keys or {}
  if ie and (ie.n or 0) > 0 and not ctx.prudent and not (ctx.mine_skip and ctx.mine_skip[ie.res]) then
    for j = 1, ie.n do
      local key = "fond:mine:" .. ie.res .. ":fer:" .. j
      if not keys[key] then
        out[#out + 1] = { key = key, kind = "mine", prio = F.PRIO.mine, resource = ie.res, count = F.MINE_BATCH,
          fond = true, domain = "gisements", radius = ctx.mine_radius }
      end
    end
  end
  return out
end

--- Paires que le fond peut POSER à brève échéance (lot COFFRE, K-D du constat du DC du 27/10, 18 h 50 : « 40 fours en pierre »,
--- 37 foreuses à combustion dormantes, jamais posés, et leurs plaques manquaient aux tourelles). Ce n'est plus « toutes les
--- places restantes de la carte » mais ce que les règles d'`extraction` poseraient vraiment :
---   * un agrandissement (F.PAIRS paires au plus) par avant-poste que le fond agrandirait (ni plein, ni dangereux, ni non défendu ;
---     ni prudence, ni fond sûr : ces deux-là ne posent rien) ;
---   * une construction (F.PAIRS paires au plus) par type qui a un site connu et qu'aucun avant-poste ne peut agrandir, et, sous
---     « défendre d'abord », seulement si les tourelles et leurs chargeurs sont DÉJÀ au stock libre (`free` : fabricables ne
---     suffit pas, elles viennent du cerveau, pas de la réserve), puisque sinon la construction attend ses tourelles ;
--- au plus F.AHEAD paires d'avance.
function F.potential(view, ctx, free)
  ctx = ctx or {}
  if ctx.prudent or ctx.safe_only then return 0 end
  local undefended = ctx.undefended or {}
  local danger = ctx.danger or {}
  local n = 0
  local extendable = {}
  for _, o in ipairs(view.outposts or {}) do
    local room = T.max_drills(o.kind) - (o.drills or 0)
    if F.far_from_site(view, o) then room = 0 end -- lot SITE-PROCHE (R1)
    if not o.full and room > 0 then
      if undefended[o.id] then
        extendable[o.kind] = true -- il attend ses tourelles : pas de nouvel avant-poste de ce type
      elseif not danger[o.id] then
        extendable[o.kind] = true
        n = n + math.min(F.PAIRS, room)
      end
    end
  end
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    if not extendable[kind] and (view.sites and view.sites[kind] or 0) > 0 and not F.saturated_build(ctx, kind)
      and not F.far_build(view, kind) then -- lot SCALE-COMPLET : pas de build lointain, donc pas de paires d'avance pour lui
      local pairs_n = math.min(F.PAIRS, T.outposts[kind].drills)
      local ready = true
      if ctx.defend_first then
        local t = T.defend_turrets(pairs_n)
        ready = free ~= nil and (free["gun-turret"] or 0) >= t and (free[T.turret_ammo] or 0) >= t * T.defend_ammo
      end
      if ready then n = n + pairs_n end
    end
  end
  return math.min((ctx.reserve ~= nil and ctx.reserve == F.PLAYER_RESERVE) and F.PLAYER_AHEAD or F.AHEAD, n)
end

local function base(view, free, ctx, out)
  local book = ctx.book
  if not book then return end
  local keys = ctx.keys or {}
  local incoming = view.incoming or {}
  local pot = F.potential(view, ctx, free)
  -- Le fond ne descend pas sous les planchers du cerveau : ils sont retirés du stock libre le temps du calcul.
  local floors = {}
  for _, k in ipairs({ "copper-plate", "iron-plate", "stone" }) do
    floors[k] = math.min(F.FLOOR[k], math.max(0, free[k] or 0))
    free[k] = (free[k] or 0) - floors[k]
  end
  local planned = {} -- objets dont une fabrication de fond vient d'être proposée (comptés dans `have` de la suite)
  -- Fabrique `n` de `item` si le stock libre a la matière ; rend le nombre proposé (0 : matière absente).
  local function craft(item, n, key)
    local saved = free[item]
    free[item] = 0 -- besoin d'accumulation : l'objet lui-même n'est pas pris au stock (comme `fresh` dans le cerveau)
    local p = book:plan({ { item, n } }, free)
    free[item] = saved
    if next(p.raw) ~= nil then return 0 end -- matières premières absentes
    if not keys[key] then
      -- Les ingrédients pris par le plan sortent du stock libre (l'objet lui-même garde son compte).
      for _, u in ipairs(sorted_uses(p.uses)) do
        if u[1] ~= item then free[u[1]] = (free[u[1]] or 0) - u[2] end
      end
      out[#out + 1] = { key = key, kind = "craft", prio = F.PRIO.craft, item = item, count = n, steps = p.crafts,
        uses = sorted_uses(p.uses), fond = true, domain = "production", tag = "fond" }
    end
    planned[item] = (planned[item] or 0) + n
    return n
  end
  -- Cerveau EN MANQUE d'objets (tourelles, packs, plaques…) : le fond ne fabrique rien, les plaques vont à ses
  -- objectifs. Moteur réel, verif-guide graine 1618033988 : objectif « tourelles » jamais atteint (fer 53 à 206 au
  -- coffre, réserve de foreuses en cours), coffre détruit vers 22 min.
  if not ctx.brain_short then
    for _, r in ipairs(ctx.reserve or F.RESERVE) do
      local item = r[1]
      local want = math.max(r[2], math.min(r[3] or r[2], pot))
      -- Lot COFFRE (K-D) : un bien d'équipement n'est fabriqué que pour ce qui se POSE (F.potential) ; plus de plancher de
      -- réserve (8 foreuses et 8 fours d'avance pour rien : les factions en gardaient 8, votre équipe 40).
      if F.EQUIPMENT[item] then want = math.min(r[3] or r[2], pot) end
      if book:handcraftable(item) then
        local have = (free[item] or 0) + (incoming[item] or 0) + (planned[item] or 0)
        local i = 0
        while have < want and i < F.CRAFT_TASKS do
          i = i + 1
          local n = math.min(F.CRAFT_BATCH, want - have)
          if craft(item, n, "fond:craft:" .. item .. ":" .. i) == 0 then break end
          have = have + n
        end
      end
    end
  end
  -- Lot COFFRE (K-C) : coffres pour les ANNEXES du QG (script/team/stock.lua) quand les cases se remplissent. Cerveau en
  -- manque : seulement ceux qui ne coûtent aucune plaque (T.annex.kinds[].cheap), le coffre plein bloque tout le monde.
  local need = ctx.annex_want or 0
  if need > 0 then
    for _, k in ipairs(T.annex.kinds) do
      need = need - (free[k.item] or 0) - (incoming[k.item] or 0) - (planned[k.item] or 0)
    end
    for _, k in ipairs(T.annex.kinds) do
      if need <= 0 then break end
      if (k.cheap or not ctx.brain_short) and book:handcraftable(k.item) then
        local n = craft(k.item, math.min(need, F.CRAFT_BATCH), "fond:craft:" .. k.item .. ":annexe")
        need = need - n
      end
    end
  end
  for _, k in ipairs({ "copper-plate", "iron-plate", "stone" }) do free[k] = free[k] + floors[k] end
end

local function territory(view, ctx, out)
  local keys = ctx.keys or {}
  -- Une garde au QG et une par avant-poste. Essai sans les gardes d'avant-postes (fo-logs\2026-10-25_IA1-b\apres2) :
  -- PNJ tués par les ennemis en 60 min 150 contre 117 avec elles (les gardes ne sont donc pas la cause des morts ; la
  -- sortie des PNJ au travail et la pollution des foreuses en plus, si) ; équipe occupée 70,6 % au lieu de 93 %.
  -- Leur valeur défensive n'est pas mesurée (lot IA1-g : zones et tourelles).
  -- R-QCM-25c (c) : ctx.no_hq_guard (votre équipe) : plus de garde de fond au coffre non plus (le DC voyait ses PNJ
  -- « retourner au coffre et attendre ») ; les gardes armés du coffre en guerre sont des tâches du cerveau.
  local posts = ctx.no_hq_guard and {} or { "hq" }
  local danger = ctx.danger or {}
  -- Lot IA1-b2 (D-17, « Couper les gardes ») : ctx.no_outpost_guard (votre équipe) : plus de garde d'avant-poste.
  for _, o in ipairs(view.outposts or {}) do
    if not danger[o.id] and not ctx.prudent and not ctx.no_outpost_guard and not (ctx.undefended or {})[o.id] then
      posts[#posts + 1] = o.id
    end
  end
  for k = 1, F.GARRISON_PER_POST do
    for _, p in ipairs(posts) do
      local key = "fond:garde:" .. tostring(p) .. ":" .. k
      if not keys[key] then
        out[#out + 1] = { key = key, kind = "garrison", prio = F.PRIO.garrison, post = p, wait = F.GARRISON_TICKS,
          fond = true, domain = "defense" }
      end
    end
  end
end

function F.candidates(view, free, ctx)
  ctx = ctx or {}
  local c = { extraction = {}, base = {}, territoire = {} }
  extraction(view, free, ctx, c.extraction)
  base(view, free, ctx, c.base)
  territory(view, ctx, c.territoire)
  return c
end

--- Stock LIBRE : stock du QG moins les objets réservés par les tâches du tableau (`items` ou `uses`) qui ne les ont
--- pas encore pris (tâche libre, ou prise dont l'étape « take » n'a pas eu lieu : `took` posé par l'ouvrier).
function F.free_stock(stock, tasks)
  local free = {}
  for k, v in pairs(stock or {}) do free[k] = v end
  for _, t in ipairs(tasks or {}) do
    if not t.took then
      for _, it in ipairs(t.items or t.uses or {}) do free[it[1]] = (free[it[1]] or 0) - it[2] end
    end
  end
  return free
end

return F
