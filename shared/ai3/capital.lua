--[[
  Lot CAPITAL « améliorer, et monter les époques » (décision D-20 (3) du DC, 27/10, 10 h 15 : « si l'IA est autonome elle
  le fera d'elle même, il faut que ce soit un choix logique et non encré en dur c'est très important » ; conception
  docs/IA3_CERVEAU.md §3.1, famille Capital, « améliorer un niveau » ; §3.7 « payer le niveau du centre »). PUR (aucune API
  Factorio) : testé hors jeu (tests/capital_test.lua) ; le runtime (script/ai3/capital.lua) lui donne le relevé des
  bâtiments à niveaux de la force, les prototypes de leurs niveaux et le coût de fabrication de chaque objet (graphe du
  cerveau général), puis il PAIE le niveau choisi par le même mécanisme que le joueur (script/levels/levels.lua).

  Ce qu'un joueur fait : il améliore ce qui rapporte le plus pour ce que ça coûte, et il monte son centre quand le centre
  ouvre des améliorations qui valent la peine (la condition du centre l'oblige d'abord à monter un bâtiment de chaque
  famille qu'il possède). En calcul, pour chaque bâtiment à niveaux de la force (et son centre) :

  1. CANDIDAT = le niveau suivant, s'il est permis (règles des DONNÉES des niveaux, Ld = shared/levels/config.lua ou une
     copie : Ld.check, Ld.max_level, Ld.cc_condition_level, Ld.cc_blockers). La famille « centre » n'est pas nommée : c'est
     celle dont les niveaux n'exigent aucun centre (Ld.required_cc = 0).
  2. COÛT LU DANS LES DONNÉES : la liste { {objet, n} } de Ld.cost(famille, n + 1) (le centre absent : l'objet qui le
     pose, lu dans son prototype). Coût en travail = Σ n × coût unitaire de l'objet (point fixe min-plus du graphe du
     cerveau général : fabrication, ingrédients, machines ; ctx.unit_cost), l'objet déjà au stock compté à
     Cap.STOCK_PCT % (investir un stock qui dort, H4). Un objet dont le coût unitaire est inconnu (nil : aucune façon
     connue de l'obtenir) rend le candidat IMPAYABLE (règle H8 : rien n'est fabriqué pour lui ; ses objets sont rendus
     dans `wanted`, la recherche qui les débloque prend de la valeur, H9).
  3. VALEUR LUE DANS LES PROTOTYPES des deux niveaux (ctx.proto(nom) -> { role, speed, dps, health, item }), par RÔLE du
     type de l'entité (shared/ai3/reglages.lua, R.ENTITY_ROLE : mots du moteur) :
       fabrique, foreuse : DÉBIT, gain = vitesse(n + 1) ÷ vitesse(n) − 1, × l'usage du bâtiment (en marche : 1 ; à
                           l'arrêt : Cap.IDLE_USE) × Cap.V_DEBIT ;
       militaire         : DÉFENSE, gain = (dps × vie)(n + 1) ÷ (dps × vie)(n) − 1 (la force d'un combattant croît comme
                           le produit de ses dégâts et de sa vie), × Cap.V_COMBAT, × Cap.THREAT_PCT % sous menace ;
       centre            : ÉPOQUE, Cap.V_EPOCH (ouvrir l'époque suivante) + ce que le centre DÉBLOQUE : la valeur des
                           améliorations que son plafond interdit aujourd'hui (bâtiments au plafond), ÷ Cap.LOOK_DIV.
     Chaque terme est pondéré par le poids de sa famille de buts (chef d'IA2-a, traits d'IA2-0 : capital, defense).
  4. CONDITION DU CENTRE (Q16) : une famille possédée sous le niveau exigé BLOQUE le centre ; son bâtiment le plus haut
     hérite de Cap.CHAIN_PCT % de la valeur du centre (la chaîne des pourquoi : « monter cette tourelle ouvre l'époque »).
  5. CHOIX : score = valeur × 1 000 ÷ (coût + Cap.COST_FLOOR), inertie de Cap.INERTIA_PCT % pour le candidat en cours ;
     égalités départagées par la clé.
  Le BUT rendu au cerveau (Cap.goal) porte la liste { {objet, n} } du coût : le dépliage (shared/ai3/projets.lua, P.want ;
  shared/ai3/general.lua, Gen.summary) la sert comme n'importe quel besoin, sans rien savoir des niveaux. Un coût qui
  contiendra demain une pièce montée est fabriqué (main), produit ou automatisé (machine, IA3-e) sans une ligne de plus.

  Aucun nom du jeu ici (test anti-échelle, tests/iag_test.lua §8). Déterminisme : listes triées par numéro d'entité et
  par clé, entiers pour les scores, aucun hasard, aucun pairs décisionnel.
]]

local Cap = {}

Cap.V_DEBIT = 100       -- un bâtiment en marche dont la vitesse doublerait vaut 100 (même échelle que Gen.V_PACK)
Cap.V_COMBAT = 60       -- un combattant dont la force doublerait vaut 60 (militaire : Gen.V_MIL 40 + son bonus 25, arrondi)
Cap.V_EPOCH = 100       -- ouvrir l'époque suivante (la progression : comme un pack nouveau, Gen.V_PACK)
Cap.IDLE_USE = 25       -- % : un bâtiment à l'arrêt ne rapporte qu'un quart de son gain (il servira peut-être)
Cap.THREAT_PCT = 200    -- % : sous menace, la défense vaut le double (H4 : l'horizon se raccourcit)
Cap.LOOK_DIV = 2        -- ce qu'un centre débloque compte pour moitié (gain d'après, pas d'aujourd'hui)
Cap.CHAIN_PCT = 50      -- part de la valeur du centre héritée par le bâtiment qui le bloque (condition Q16)
Cap.STOCK_PCT = 50      -- % : un objet déjà au stock libre coûte moitié (il dort ; son usage ailleurs a un prix)
Cap.COST_FLOOR = 10
Cap.INERTIA_PCT = 20
Cap.TOP = 3             -- candidats gardés pour le journal
-- Valeur du BUT au cerveau (échelle des projets, 0 à 100 ; shared/ai3/buts.lua) : sous l'armée qui grandit (46) et la
-- croissance de l'extraction (55), au-dessus du travail de fond ; + Cap.GOAL_STOCK quand tout le coût dort déjà au
-- stock libre (investir, H4 : aucun travail, rien ne manque) ; le centre (l'époque) + Cap.GOAL_EPOCH.
Cap.GOAL_VALUE = 30
Cap.GOAL_STOCK = 12
Cap.GOAL_EPOCH = 6
-- Le but est de FOND (shared/ai3/projets.lua, P.update : g.fond) : aucune des K places de projet, servi après tous les
-- autres projets, avec ce qui reste au stock virtuel ; ses tâches (fabrication, manques) à la priorité de sa valeur (53 à
-- 61, sous la recherche et l'extraction). Moteur réel, bancs c1 et c1-temoin (27/10, graine 271828182, même code, capital
-- coupé au témoin) : servi comme un projet ordinaire (valeur 40 à 58, une place sur K), il retardait la recherche
-- (palier 3 : 1 faction sur 4 en 60 min contre 3 au témoin ; palier 2 en médiane 24,3 min contre 14,3).
-- Travail COURT (règle « le plus court d'abord » d'IA-G, shared/ai3/projets.lua, P.update) : un pas du CENTRE dont le coût
-- en travail ne dépasse pas Cap.SHORT_WORK (la pose du centre : 541 en jeu) passe devant les familles permanentes (armée, réserve), comme une recherche peu
-- chère. Moteur réel, banc c1 (27/10, graine 271828182) : servie APRÈS l'armée, la pose du centre (coût 541, environ 90
-- plaques de fer) attendait 60 min chez 2 factions sur 4, l'armée prenant tout le fer ; le passage du centre (coût 3 024)
-- n'est pas court et reste derrière l'armée. Les BÂTIMENTS ne sont jamais courts : au moteur simulé
-- (tests/capital_moteur_test.lua, 45 min, Normal), les mitrailleuses servies avant l'armée prenaient son fer (59
-- améliorations, 214 soldats envoyés contre 329 au témoin) ; servies après, elles n'ont que ce que l'armée laisse.
Cap.SHORT_WORK = 800
-- Lot AMELIORER : machines HORS des familles à niveaux (celles que les équipes posent réellement avant la première
-- machine d'une famille : four de pierre, premier assembleur) remplacées SUR PLACE par la machine supérieure, lue dans
-- les prototypes (Cap.successors). Au plus Cap.REPLACE_BATCH machines identiques par décision (un paiement par pensée).
Cap.REPLACE_BATCH = 4
-- Lot AGES « le passage d'âge ne meurt pas de faim » (retour du DC du 2/11, points 8 et 17 : l'âge 2 vu une fois sur huit
-- parties). Le choix est un rapport valeur ÷ coût (règle de Smith) : exact pour un ensemble FINI de travaux, mais le centre
-- (un gros prix qui ouvre l'époque, rapport 170 à 560) passait derrière un flux qui ne tarit pas (chaque tourelle, mur ou
-- foreuse posé offre une amélioration à 700 à 14 000) : mesuré sur 2 graines de 3 h, 1 faction sur 6 a monté son centre.
-- Règle du « loueur de skis » (compétitive : on ne perd jamais plus du double), comptée en VALEUR : tant que le centre est
-- payable, on peut le reporter pour des travaux de meilleur rapport, mais pas au-delà du moment où ces reports ont rapporté
-- AU TOTAL autant que le centre lui-même (Cap.DEFER_PCT % de sa valeur) : il passe alors devant (d.starved), et son but est
-- servi comme un travail court (juste après le premier projet : l'armée et les réserves ne lui prennent plus son fer).
-- (Essai 2, mesuré : compté en COÛT, le report d'un centre de l'époque 3 — 80 acier — dépassait l'heure pour une faction
-- qui paie 40 de travail par minute ; en valeur, il faut la valeur d'environ 25 tourelles.)
Cap.DEFER_PCT = 100
-- Lot DEFAUT7, étage 3 (« la matière du centre quand il passe devant » ; sonde [FO-FER-DIAG], banc fd-croiss-123456789 sur
-- 16f1b3e0) : le centre d'Émeraude passe devant à 31,0 min, mais (1) « alim:logistic-science-pack », PREMIER projet, prend avant lui
-- tout le fer du stock virtuel (fer à son tour : 0 à 2 dans 25 relevés ; 738 des 908 plaques entrées en 28 min parties en fabrications
-- de ce projet), et (2) à 36,0 min la valeur du centre monte (218 -> 356 : les tourelles payées débloquent plus), le report retombe
-- sous le seuil et le centre redevient un but de fond servi EN DERNIER. Règle : un centre qui a passé devant RESTE devant (collant)
-- et il est servi EN TÊTE du stock virtuel (Cap.ahead_first), sauf les projets qui produisent la matière qui lui manque (exemption :
-- sinon une faction sans autre source ne sortirait jamais de l'impasse). BORNE : au plus Cap.AHEAD_TICKS ; ensuite il retombe à la
-- règle d'avant (Cap.starved sur les reports), sans se réarmer pour la même cible. 15 min : le plus lent des cas mesurés couvre son
-- manque en 11,6 min (Émeraude, 370 plaques de fer à 32 plaques/min de fonte à la main) ; au-delà, c'est la PRODUCTION qui manque (la
-- tournée de charbon tenue par un PNJ coincé, étage 4), et le centre ne doit pas geler la faction.
Cap.AHEAD_TICKS = 15 * 3600

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function wf(w, fam) return ((w or {})[fam] or 1000) / 1000 end

--- Famille « centre » des données : celle dont les niveaux n'exigent aucun centre (aucun nom écrit).
function Cap.center_family(Ld)
  for _, fam in ipairs(Ld.families) do
    if fam.max >= 2 and Ld.required_cc(fam, 2) == 0 then return fam end
  end
  return nil
end

--- Gain relatif du niveau n au niveau n + 1, lu dans les prototypes ; rend gain (≥ 0), sorte (« debit », « combat » ou
--- nil).
function Cap.gain(Ld, proto, fam, n)
  if n >= fam.max then return 0, nil end
  local p0, p1 = proto(Ld.name(fam, n)), proto(Ld.name(fam, n + 1))
  if not (p0 and p1) then return 0, nil end
  local role = p0.role
  if (role == "fabrique" or role == "foreuse") and (p0.speed or 0) > 0 and (p1.speed or 0) > 0 then
    return math.max(0, p1.speed / p0.speed - 1), "debit"
  end
  if role == "militaire" and (p0.health or 0) > 0 and (p1.health or 0) > 0 then
    local f0 = (p0.dps or 1) * p0.health
    local f1 = (p1.dps or 1) * p1.health
    return math.max(0, f1 / f0 - 1), "combat"
  end
  return 0, nil
end

--- Valeur propre de l'amélioration d'un bâtiment (sans chaîne) : v, raison { sorte, gain en % }.
function Cap.building_value(Ld, proto, fam, n, working, ctx)
  local g, kind = Cap.gain(Ld, proto, fam, n)
  if not kind or g <= 0 then return 0, nil end
  local w = ctx and ctx.weights
  local v
  if kind == "debit" then
    local use = working and 100 or Cap.IDLE_USE
    v = Cap.V_DEBIT * g * use / 100 * wf(w, "capital")
  else
    local th = (ctx and ctx.threat) and Cap.THREAT_PCT or 100
    v = Cap.V_COMBAT * g * th / 100 * wf(w, "defense")
  end
  return math.floor(v + 0.5), { kind, math.floor(g * 1000 + 0.5) / 10 }
end

--- Coût en travail d'une liste { {objet, n} } (ctx.unit_cost ; stock libre ctx.stock à Cap.STOCK_PCT %) ; rend coût,
--- objets sans coût connu (liste triée), objets du coût tous au stock (vrai/faux).
function Cap.work_cost(list, ctx)
  local c, missing, all_in = 0, {}, true
  local stock = (ctx and ctx.stock) or {}
  for _, it in ipairs(list) do
    local item, n = it[1], it[2]
    local u = ctx and ctx.unit_cost and ctx.unit_cost(item)
    if u == nil then
      missing[#missing + 1] = item
    else
      local have = math.min(n, stock[item] or 0)
      if have < n then all_in = false end
      c = c + (n - have) * u + have * u * Cap.STOCK_PCT / 100
    end
  end
  table.sort(missing)
  if #missing > 0 then all_in = false end
  return math.floor(c + 0.5), missing, all_in
end


--- Une table de catégories (nom -> vrai) en couvre-t-elle une autre ?
local function covers(big, small)
  for k in pairs(small or {}) do
    if not (big and big[k]) then return false end
  end
  return true
end

--- Lot AMELIORER : machines vers lesquelles `name` se remplace sur place, lues dans les PROTOTYPES (ctx.mproto(nom) ->
--- { type, group (groupe de remplacement rapide), w, h (emprise), energy (sorte d'énergie), cats (catégories de fabrication,
--- nom -> vrai), speed, item (objet qui la pose) } ; ctx.machines = noms des machines connues, triés). Une cible a le même
--- type, le même groupe de remplacement rapide, la même emprise et la même sorte d'énergie, fait au moins les mêmes
--- catégories, va plus vite, et n'est jamais un niveau supérieur à 1 d'une famille (ceux-là sont l'amélioration
--- ordinaire, qui exige le centre). Rend les noms triés : vitesse croissante, puis nom. Aucun nom écrit ici.
function Cap.successors(Ld, ctx, name)
  local p0 = ctx.mproto and ctx.mproto(name)
  if not (p0 and p0.group and (p0.speed or 0) > 0) then return {} end
  local out = {}
  for _, t in ipairs(ctx.machines or {}) do
    local p1 = (t ~= name) and ctx.mproto(t) or nil
    if p1 and p1.item and p1.type == p0.type and p1.group == p0.group and p1.w == p0.w and p1.h == p0.h
        and p1.energy == p0.energy and (p1.speed or 0) > p0.speed and covers(p1.cats, p0.cats) then
      local fam, n = Ld.parse(t)
      if fam == nil or n == 1 then out[#out + 1] = t end
    end
  end
  table.sort(out, function(a, b)
    local sa, sb = ctx.mproto(a).speed, ctx.mproto(b).speed
    if sa ~= sb then return sa < sb end
    return a < b
  end)
  return out
end

--- Candidats « remplacer » (lot AMELIORER) : pour chaque machine du relevé (census.machines : { id, name, working }, triées
--- par id) hors famille à niveaux, la cible de meilleur score (valeur ÷ coût) parmi ses successeurs payables ; les machines
--- de même (source, cible) forment UN candidat (au plus Cap.REPLACE_BATCH, moins si le stock libre en tient moins). Valeur
--- = gain de vitesse × usage (en marche : 1, à l'arrêt : Cap.IDLE_USE) × Cap.V_DEBIT, comme un bâtiment à niveaux.
--- Rend candidats (non scorés), impayables (cible sans coût connu : la recherche qui la débloque n'est PAS réclamée).
function Cap.replace_candidates(Ld, census, ctx)
  local out, blocked = {}, {}
  if not (ctx.mproto and census.machines) then return out, blocked end
  local groups, order = {}, {}
  local blocked_seen = {}
  local machines = {}
  for i, m in ipairs(census.machines) do machines[i] = m end
  table.sort(machines, function(a, b) return a.id < b.id end)
  for _, m in ipairs(machines) do
    if Ld.parse(m.name) == nil and not (ctx.exclude and ctx.exclude["m:" .. m.id]) then
      local p0 = ctx.mproto(m.name)
      local best
      local first_missing
      for _, t in ipairs(Cap.successors(Ld, ctx, m.name)) do
        local p1 = ctx.mproto(t)
        local g = p1.speed / p0.speed - 1
        local use = m.working and 100 or Cap.IDLE_USE
        local v = math.floor(Cap.V_DEBIT * g * use / 100 * wf(ctx.weights, "capital") + 0.5)
        local cost, missing = Cap.work_cost({ { p1.item, 1 } }, ctx)
        -- « Dès qu'elle est débloquée » : une cible que la force ne sait pas encore fabriquer (recette désactivée, ctx.available)
        -- attend ; sa recherche n'est pas réclamée (no_want) et son coût de recherche n'entre pas dans le choix.
        if #missing == 0 and ctx.available and not ctx.available(p1.item) then missing = { p1.item } end
        if #missing > 0 then
          first_missing = first_missing or { to = t, causes = missing }
        elseif v > 0 then
          local score = v * 1000 / (cost + Cap.COST_FLOOR)
          if not best or score > best.score then best = { to = t, v = v, score = score, item = p1.item } end
        end
      end
      if best then
        local gk = m.name .. ">" .. best.to
        local grp = groups[gk]
        if not grp then
          grp = { from = m.name, to = best.to, item = best.item, ids = {}, value = 0 }
          groups[gk] = grp
          order[#order + 1] = gk
        end
        grp.ids[#grp.ids + 1] = m.id
        grp.value = grp.value + best.v
        grp.vals = grp.vals or {}
        grp.vals[#grp.vals + 1] = best.v
      elseif first_missing then
        local bk = "remplacer:" .. m.name .. ">" .. first_missing.to
        if not blocked_seen[bk] then
          blocked_seen[bk] = true
          blocked[#blocked + 1] = { key = bk, family = "remplacer", from = 0, to = 1, value = 0, causes = first_missing.causes,
            no_want = true, cost = { { ctx.mproto(first_missing.to).item, 1 } } }
        end
      end
    end
  end
  table.sort(order)
  for _, gk in ipairs(order) do
    local grp = groups[gk]
    local have = (ctx.stock or {})[grp.item] or 0
    local n = math.max(1, math.min(Cap.REPLACE_BATCH, #grp.ids, have))
    local ids, value = {}, 0
    for i = 1, n do ids[i] = grp.ids[i]; value = value + grp.vals[i] end
    out[#out + 1] = { key = "remplacer:" .. gk .. ":" .. ids[1], id = ids[1], ids = ids, family = "remplacer", from = 0, to = 1,
      cost = { { grp.item, n } }, value = value, replace = { from = grp.from, to = grp.to, n = n },
      why = { { "debit", math.floor((ctx.mproto(grp.to).speed / ctx.mproto(grp.from).speed - 1) * 1000 + 0.5) / 10 },
        { "machines", n } } }
  end
  return out, blocked
end

--- Candidats. census = { list = { {id, name, working} } (bâtiments à niveaux, triés par id), center = { id, name } ou
--- nil } ; ctx = { proto, unit_cost, stock, weights, threat, current }. Rend { cands (triés : score décroissant, clé),
--- blocked (impayables ou bloqués, triés), center_fam, blockers }.
function Cap.candidates(Ld, census, ctx)
  local proto = ctx.proto
  local cfam = Cap.center_family(Ld)
  local cc_level = 0
  local center = census.center
  if center and cfam then
    local f, n = Ld.parse(center.name)
    if f == cfam then cc_level = n end
  end
  -- Bâtiments par famille (le plus haut d'abord pour la chaîne Q16) et recensement Q16 de la force.
  local rows = {}
  local cond = cc_level > 0 and Ld.cc_condition_level(cc_level) or nil
  local q16 = {}
  local top_of = {}
  for _, b in ipairs(census.list or {}) do
    local fam, n = Ld.parse(b.name)
    if fam and fam ~= cfam then
      rows[#rows + 1] = { b = b, fam = fam, n = n }
      local c = q16[fam.key] or { any = true, top = false }
      if cond and n >= math.min(cond, fam.max) then c.top = true end
      q16[fam.key] = c
      -- Le bâtiment de la chaîne Q16 : le plus haut ; à niveau égal, celui qui est en marche (il rapporte aussi par
      -- lui-même) ; puis le plus petit numéro.
      local t = top_of[fam.key]
      local better = not t or n > t.n
      if t and n == t.n then
        local bw, tw = b.working and 1 or 0, t.b.working and 1 or 0
        better = bw > tw or (bw == tw and b.id < t.b.id)
      end
      if better then top_of[fam.key] = rows[#rows] end
    end
  end
  local cands, blocked = {}, {}
  local function add(c)
    -- Refus récent de l'exécutant (place, condition vue autrement par le jeu) : écarté jusqu'à son échéance (ctx.exclude).
    if ctx.exclude and ctx.exclude[c.key] then
      c.causes = { "refus" }
      blocked[#blocked + 1] = c
      return
    end
    local cost, missing, all_in = Cap.work_cost(c.cost, ctx)
    c.work, c.all_in = cost, all_in
    if #missing > 0 then
      c.causes = missing
      blocked[#blocked + 1] = c
      return
    end
    if c.value <= 0 then return end
    local score = math.floor(c.value * 1000 / (cost + Cap.COST_FLOOR))
    if ctx.current and c.key == ctx.current then score = math.floor(score * (100 + Cap.INERTIA_PCT) / 100) end
    c.score = score
    cands[#cands + 1] = c
  end
  -- Bâtiments : leur niveau suivant (permis par le plafond du centre).
  local own = {}
  for _, r in ipairs(rows) do
    local fam, n = r.fam, r.n
    local v, why = Cap.building_value(Ld, proto, fam, n, r.b.working, ctx)
    own[#own + 1] = { r = r, v = v, why = why }
    if n < fam.max and Ld.check(fam, n + 1, cc_level) then
      r.cand = { key = fam.key .. ":" .. (n + 1) .. ":" .. r.b.id, id = r.b.id, family = fam.key, from = n, to = n + 1,
        cost = Ld.cost(fam, n + 1), value = v, why = { why } }
    end
  end
  -- Centre : le poser (aucun) ou le monter. Valeur = l'époque + ce que son plafond débloque (÷ LOOK_DIV).
  local blockers = {}
  -- Lot C1 : l'état du centre à CETTE décision, pour le journal (une cause par refus, jamais un silence) :
  -- { state, key, causes }. state : equipe-joueur | famille-absente | objet-absent | niveau-max | pose | monte | sans-valeur.
  local centre = { state = (cfam and census.no_center) and "equipe-joueur" or (not cfam) and "famille-absente" or nil }
  if cfam and not census.no_center then -- no_center : votre équipe (lot AMELIORER), ni centre ni bâtiments du joueur
    local cap_now = cc_level > 0 and Ld.building_cap(cc_level) or Ld.building_cap(0)
    local unlocked = 0
    for _, o in ipairs(own) do
      local fam, n = o.r.fam, o.r.n
      if n >= cap_now and n < fam.max then unlocked = unlocked + o.v end
    end
    local cv = math.floor((Cap.V_EPOCH * wf(ctx.weights, "capital") + unlocked / Cap.LOOK_DIV) + 0.5)
    local cc
    if cc_level == 0 then
      local p = proto(Ld.name(cfam, 1))
      local item = p and p.item
      if not item then centre.state = "objet-absent" end
      if item then
        cc = { key = cfam.key .. ":1:pose", family = cfam.key, from = 0, to = 1, build = true, cost = { { item, 1 } },
          value = cv, why = { { "epoque", 1 }, { "debloque", unlocked } }, center = true }
      end
    elseif cc_level >= cfam.max then
      centre.state = "niveau-max"
    else
      cc = { key = cfam.key .. ":" .. (cc_level + 1) .. ":" .. center.id, id = center.id, family = cfam.key,
        from = cc_level, to = cc_level + 1, cost = Ld.cost(cfam, cc_level + 1), value = cv,
        why = { { "epoque", cc_level + 1 }, { "debloque", unlocked } }, center = true }
      -- Lot AGES : le relevé peut porter la condition telle que le JEU la compte (census.blockers : toute la surface) ; le
      -- planificateur ne voit sinon que la base et choisissait un centre que l'exécutant refusait (« cc-families »).
      blockers = census.blockers or Ld.cc_blockers(q16)
    end
    if cc then
      centre.state, centre.key = cc_level == 0 and "pose" or "monte", cc.key
      if #blockers > 0 then
        cc.causes = {}
        for _, k in ipairs(blockers) do cc.causes[#cc.causes + 1] = "condition:" .. k end
        blocked[#blocked + 1] = cc
        -- Chaîne Q16 : le bâtiment le plus haut de chaque famille qui bloque hérite d'une part de la valeur du centre.
        local share = math.floor(cv * Cap.CHAIN_PCT / 100)
        for _, k in ipairs(blockers) do
          local t = top_of[k]
          if t and t.cand then
            t.cand.value = t.cand.value + share
            t.cand.chain = { target = cc.key, v = share }
          end
        end
      else
        add(cc)
      end
      centre.causes = cc.causes
      if not cc.causes and not cc.score then centre.state = "sans-valeur" end
    end
  end
  for _, r in ipairs(rows) do if r.cand then add(r.cand) end end
  -- Lot AMELIORER : machines hors famille remplacées sur place par la machine supérieure.
  local rep, rep_blocked = Cap.replace_candidates(Ld, census, ctx)
  for _, c in ipairs(rep) do add(c) end
  for _, c in ipairs(rep_blocked) do blocked[#blocked + 1] = c end
  table.sort(cands, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.key < b.key
  end)
  table.sort(blocked, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.key < b.key
  end)
  return { cands = cands, blocked = blocked, center_fam = cfam, cc_level = cc_level, blockers = blockers, centre = centre }
end

--- Le choix : le meilleur candidat (nil s'il n'y en a pas) ; d.ranked = les Cap.TOP premiers { clé, score } ;
--- d.wanted = objets sans coût connu des candidats de valeur bloqués par eux (H8 -> H9).
function Cap.choose(Ld, census, ctx)
  local res = Cap.candidates(Ld, census, ctx)
  -- Lot AGES : le centre reporté plus que son prix passe devant (Cap.starved).
  local first = res.cands[1]
  local starved = false
  for _, c in ipairs(res.cands) do
    if c.center and (Cap.starved(ctx.defer, c, ctx.tick) or ctx.thaw) then first, starved = c, true end -- ctx.thaw : le gel du centre est levé (shared/team/degel.lua)
  end
  local d = first and {} or { none = true }
  for k, v in pairs(first or {}) do d[k] = v end
  d.starved = starved or nil
  -- Lot DEFAUT7, étage 3 : le centre passé devant est servi en tête, tant que la borne de sa cible n'est pas atteinte.
  d.ahead = (starved and not Cap.ahead_expired(ctx.defer, first.key, ctx.tick)) or nil
  d.gate_open = Cap.gate_open(res.centre)
  d.gate_key = res.centre and res.centre.key or nil
  d.ranked = {}
  for i = 1, math.min(Cap.TOP, #res.cands) do d.ranked[i] = { res.cands[i].key, res.cands[i].score } end
  d.n_cands = #res.cands
  d.blocked = res.blocked
  d.cc_level = res.cc_level
  d.centre = res.centre
  local wanted = {}
  for _, b in ipairs(res.blocked) do
    for _, c in ipairs(b.causes or {}) do
      -- Une machine à remplacer dont la cible n'est pas encore faisable n'attire pas la recherche : elle attend (no_want).
      if c:sub(1, 10) ~= "condition:" and not b.no_want then wanted[c] = true end
    end
  end
  d.wanted = wanted
  return d
end

--- Le centre a-t-il été reporté assez longtemps ? defer = { key, spent } (VALEUR des améliorations payées pendant que le centre
--- `key` était payable, tenue par le runtime), gate = le candidat centre (gate.value : sa valeur).
function Cap.starved(defer, gate, now)
  if not (defer and gate and gate.center and gate.key and defer.key == gate.key) then return false end
  if Cap.ahead_active(defer, gate, now) then return true end -- lot DEFAUT7, étage 3 : passé devant, il y reste (borné)
  local value = gate.value or 0
  if value <= 0 then return false end
  return (defer.spent or 0) * 100 >= value * Cap.DEFER_PCT
end

--- Lot DEFAUT7, étage 3 : le centre `gate` est-il encore « collant » ? defer.ahead_since = tick où il a passé devant (posé par
--- Cap.ahead_step), defer.ahead_done = borne atteinte pour cette cible (jamais réarmé).
function Cap.ahead_active(defer, gate, now)
  if not (defer and gate and gate.center and gate.key and defer.key == gate.key) then return false end
  if defer.ahead_since == nil or defer.ahead_done then return false end
  return ((now or 0) - defer.ahead_since) < Cap.AHEAD_TICKS
end

--- Lot DEFAUT7, étage 3 : un pas de l'état collant après la décision d (tenue par le runtime dans defer, nombres et booléens).
--- Rend l'événement : "debut" (le centre passe devant : la borne court), "borne" (Cap.AHEAD_TICKS atteint : retour à la règle des
--- reports), ou nil.
function Cap.ahead_step(defer, d, now)
  if not defer or defer.ahead_done then return nil end
  if defer.ahead_since ~= nil then
    if (now or 0) - defer.ahead_since >= Cap.AHEAD_TICKS then
      defer.ahead_done = true
      return "borne"
    end
    return nil
  end
  if d and d.center and d.key and d.key == defer.key and d.starved then
    defer.ahead_since = now or 0
    return "debut"
  end
  return nil
end

--- Étage 3 : la borne de la cible `key` est-elle atteinte (ou déjà passée) ?
function Cap.ahead_expired(defer, key, now)
  if not (defer and key and defer.key == key) then return false end
  if defer.ahead_done then return true end
  return defer.ahead_since ~= nil and ((now or 0) - defer.ahead_since) >= Cap.AHEAD_TICKS
end

--- Le centre est-il PAYABLE à cette décision (aucune condition qui le bloque, pas de refus récent) ? centre = res.centre de
--- Cap.candidates. Vrai : les améliorations moins chères payées ensuite le reportent (defer.spent).
function Cap.gate_open(centre)
  return centre ~= nil and centre.key ~= nil and (centre.state == "monte" or centre.state == "pose") and centre.causes == nil
end

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

--- But du cerveau (shared/ai3/projets.lua) pour une décision : la liste du coût et la cible. Clé PROPRE à la cible
--- (« capital:<famille>:<niveau>:<numéro> ») : une amélioration faite ferme son projet (annoncé « fini »).
function Cap.goal(d, weights)
  if not d or d.none or not d.key then return nil end
  local base = Cap.GOAL_VALUE + (d.all_in and Cap.GOAL_STOCK or 0) + (d.center and Cap.GOAL_EPOCH or 0)
  local w = math.max(1000, (weights or {}).capital or 1000) -- le caractère avance l'investissement, sans le retarder
  return { key = "capital:" .. d.key, family = "capital", kind = "upgrade", cost = d.cost, target = d.key,
    value = clamp(math.floor(base * w / 1000), 1, 100), center = d.center or nil, fond = true,
    short = (d.center and d.work ~= nil and (d.work <= Cap.SHORT_WORK or d.starved)) or nil, replace = d.replace and true or nil,
    -- lot DEFAUT7 : bâtiment de la chaîne Q16 (sa montée est la condition du centre) ; essai 2 : aussi l'amélioration d'un bâtiment
    -- pendant que le centre est PAYABLE (porte ouverte) : ses paiements sont le chemin du centre (règle du loueur de skis, Cap.starved).
    -- Étage 3 (relecture de 16f1b3e0, point 2) : porte ouverte, un REMPLACEMENT de machines n'est pas « sur le chemin » (pas un bâtiment
    -- à niveaux) ; seule la chaîne Q16 le met en tête.
    opens = (not d.center and (d.chain ~= nil or (d.gate_open == true and not d.replace))) or nil,
    -- Étage 3 : le centre passé devant, servi en tête du stock virtuel (Cap.ahead_first) tant que la borne n'est pas atteinte.
    ahead = (d.center and d.ahead) or nil }
end

--- Émission du projet (enregistrée dans P.EMIT.upgrade par shared/ai3/cerveau.lua) : tout le coût au stock virtuel ->
--- payé à cette pensée (E.pay, lu par le runtime après le tableau) ; sinon le dépliage le sert comme un besoin ordinaire
--- (prendre, main, matières brutes).
--- Un BÂTIMENT (pas le centre) ne fait travailler que des BRAS LIBRES (règle des bras libres d'IA-G, H4 : investir ce qui
--- dort, stock ou bras) : sans PNJ sans tâche à cette pensée, il ne prend que ce qui reste au stock virtuel, rien n'est
--- fabriqué ni extrait pour lui. Moteur réel, banc c4 (27/10, graine 271828182) : but de fond qui fabriquait quand même ses
--- engrenages et demandait son fer, palier 3 de recherche à 20,8 / 40,0 / 51,4 min contre 16,5 / 24,5 / 28,3 au témoin.
function Cap.emit(P)
  return function(E, proj, g)
    if P.take(E, g.cost) then
      E.pay = E.pay or {}
      E.pay[#E.pay + 1] = { key = g.key, target = g.target, cost = g.cost }
      return "ok"
    end
    if not g.center and not g.opens and not g.replace and ((E.view and E.view.workers_idle) or 0) <= 0 then return "matiere" end
    P.want(E, proj, g.cost, proj.prio, false, "niveau")
    return "matiere"
  end
end

--- Lot DEFAUT7 (journal du DC du 3/11 et banc ageblocage-dc 717152950 sur 0.6.50, [FO-CAPITAL-DIAG]) : l'amélioration EXIGÉE par le
--- centre (bâtiment de la chaîne Q16, g.opens) était servie EN DERNIER (rang 10 à 14 sur 14) : à son tour, le fer et les engrenages du
--- stock virtuel étaient déjà pris par les projets servis avant (fer épuisé dans 23 relevés sur 33), et Cap.emit ne fabriquait rien sans
--- bras libre : 0 fabrication émise pour elle dans 31 relevés sur 33, Azur une amélioration payée en 60 min, jamais l'âge 2.
--- Essai 2 (dc-croissance 123456789, essai 1 : une fois la chaîne payée, le centre devient payable mais l'amélioration suivante
--- d'Émeraude, une tourelle ordinaire, reste impayée 38 min : 0 engrenage à son tour, 2 améliorations en 60 min, la règle du loueur de
--- skis ne passe jamais ; 0 âge 2 contre 2 au témoin) : `opens` vaut aussi pour l'amélioration d'un bâtiment quand le centre est payable.
--- Règle : le projet du bâtiment de la chaîne passe EN TÊTE de l'ordre de service (ses quelques objets pris au stock virtuel avant les
--- autres projets) ; les autres projets gardent leur ordre. Sa valeur et sa priorité ne changent pas ; le centre n'est pas concerné.
--- order = liste des projets (P.update) ; rend une nouvelle liste.
function Cap.chain_first(order)
  local out, chain = {}, nil
  for _, p in ipairs(order or {}) do
    if not chain and p.goal and p.goal.opens then chain = p else out[#out + 1] = p end
  end
  if chain then table.insert(out, 1, chain) end
  return out
end

--- Lot DEFAUT7, étage 3 : ce que PRODUIT un but (sans nom d'objet) : son produit (module, bande), l'objet ou la ressource de son ordre
--- (capitalisation : ouvrir, couvrir, chaîne), le produit et la ressource de son avant-poste (extraction, couverture, relève).
--- outposts = T.outposts (types d'avant-poste -> { product, resource }).
function Cap.products(g, outposts)
  local out = {}
  if not g then return out end
  if g.product then out[#out + 1] = g.product end
  if g.item then out[#out + 1] = g.item end
  local o = g.order
  if type(o) == "table" then
    if o.item then out[#out + 1] = o.item end
    if o.resource then out[#out + 1] = o.resource end
  end
  local sp = g.outpost and outposts and outposts[g.outpost]
  if sp then
    if sp.product then out[#out + 1] = sp.product end
    if sp.resource then out[#out + 1] = sp.resource end
  end
  return out
end

--- Étage 3 : matières qui MANQUENT au coût `cost` au stock virtuel `avail`, et l'entrée de leur fonte (inputs = T.smelter_inputs :
--- produit -> { entrée, quantité }) : { [objet] = true }.
function Cap.missing_set(cost, avail, inputs)
  local m = {}
  for _, it in ipairs(cost or {}) do
    if ((avail or {})[it[1]] or 0) < it[2] then
      m[it[1]] = true
      local inp = inputs and inputs[it[1]]
      if inp then m[inp[1]] = true end
    end
  end
  return m
end

--- Étage 3 : ordre de SERVICE (une copie ; l'ordre d'origine garde le projet dominant) quand un centre est passé devant (g.ahead) :
--- d'abord, dans leur ordre relatif, les projets EXEMPTÉS : la DÉFENSE MINIMALE (règle D1 de shared/ai3/buts.lua, « jamais retenue » :
--- premiers soldats et armée d'alerte g.minimal / g.alert, part minimale de la réserve de munitions g.minimal_n > 0) et ceux qui
--- PRODUISENT une matière qui manque au centre ; puis le centre ; puis tous les autres dans leur ordre. Sans centre passé devant :
--- l'ordre tel quel. Le planificateur permanent et la pile (réparer, protéger) sont servis avant les projets (shared/ai3/cerveau.lua).
--- (Essai 1 de l'étage, 3c9666e7, relecture : la défense minimale passait APRÈS le centre ; moteur simulé, 57 soldats en vie contre 62.)
function Cap.minimal_defense(g)
  return g ~= nil and (g.minimal == true or g.alert == true or (g.minimal_n or 0) > 0)
end

function Cap.ahead_first(order, avail, outposts, inputs)
  local centre = nil
  for _, p in ipairs(order or {}) do
    if p.goal and p.goal.ahead then centre = p break end
  end
  if not centre then return order end
  local missing = Cap.missing_set(centre.goal.cost, avail, inputs)
  local out, rest = {}, {}
  for _, p in ipairs(order) do
    if p ~= centre then
      local feeds = Cap.minimal_defense(p.goal)
      if not feeds then
        for _, item in ipairs(Cap.products(p.goal, outposts)) do
          if missing[item] then feeds = true break end
        end
      end
      if feeds then out[#out + 1] = p else rest[#rest + 1] = p end
    end
  end
  out[#out + 1] = centre
  for _, p in ipairs(rest) do out[#out + 1] = p end
  return out
end

--- Texte de journal d'une décision (ASCII).
function Cap.why_text(d)
  if not d or d.none then
    local b = {}
    for i = 1, math.min(3, #((d and d.blocked) or {})) do
      local x = d.blocked[i]
      b[#b + 1] = x.key .. " [" .. table.concat(x.causes or {}, " ") .. "]"
    end
    return "aucune amelioration payable ; bloquees : " .. table.concat(b, ", ")
  end
  local parts = {}
  for _, w in ipairs(d.why or {}) do
    if w then parts[#parts + 1] = tostring(w[1]) .. " " .. tostring(w[2]) end
  end
  local cost = {}
  for _, it in ipairs(d.cost or {}) do cost[#cost + 1] = it[1] .. " " .. it[2] end
  local txt = "raisons [" .. table.concat(parts, ", ") .. "] cout [" .. table.concat(cost, ", ") .. "]"
  if d.chain then txt = txt .. " ; ouvre '" .. d.chain.target .. "' (+" .. d.chain.v .. ")" end
  if d.starved then txt = txt .. " ; PRIORITAIRE (reporte plus que son prix)" end
  local r = {}
  for i = 2, #(d.ranked or {}) do r[#r + 1] = d.ranked[i][1] .. " " .. d.ranked[i][2] end
  if #r > 0 then txt = txt .. " ; suivantes : " .. table.concat(r, ", ") end
  local bl = {}
  for i = 1, math.min(2, #(d.blocked or {})) do
    bl[#bl + 1] = d.blocked[i].key .. " [" .. table.concat(d.blocked[i].causes or {}, " ") .. "]"
  end
  if #bl > 0 then txt = txt .. " ; bloquees : " .. table.concat(bl, ", ") end
  return txt
end

Cap.sorted_keys = sorted_keys

return Cap
