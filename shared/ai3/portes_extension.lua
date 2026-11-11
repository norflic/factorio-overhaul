--[[
  Lot L6 de la feuille de route « Factorio Automated » (docs/VIDEO_AUTOMATISATION.md §6 L6 ; docs/TODO_VIDEO.md V21, V73, V77, V78,
  G07, G12, G13, G27, G47, G51) : LES PORTES AVANT D'ÉTENDRE, à seuils qui suivent la taille. Règle PURE (aucune API Factorio, aucun nom
  d'objet : anti-échelle de tests/iag_test.lua §8). Testée hors jeu : tests/portes_extension_test.lua. BRANCHÉE : Pe.filter dans
  script/ai3/capitalisation.lua:1007 (réglage fo-war-portes ALLUMÉ par défaut, settings/video.lua:24).

  Défaut visé, mesuré le 7/11 (docs/IA_WORKFLOW.md §5 D1, journal de la partie du DC, [FO-ACTIF] minute 175) : « 0 PNJ libre(s), 16 tache(s)
  libre(s) » : la base ajoute des chantiers et des tournées que personne ne peut servir ; la collecte du fer (priorité 52) perd.

  Trois portes, évaluées dans l'ordre sur la liste des ordres d'UNE décision (déjà triée par l'appelant, Ca.before) :
    (c) TRANSPORT SATURÉ (G13 « logistic shock ») : `tendu` quand les tâches libres dépassent Pe.BACKLOG_PER × PNJ + Pe.BACKLOG_BASE
        (seuil qui suit l'effectif). La porte se FERME après Pe.SAT_THINKS mesures tendues de suite et ne se rouvre qu'après Pe.SAT_THINKS
        mesures DÉTENDUES de suite (tâches libres au plus Pe.BACKLOG_EXIT_PER × PNJ + Pe.BACKLOG_BASE) : hystérésis, pas de clignotement.
        Lot IA-CAPI (partie du DC 0.6.96) : la part de PNJ LIBRES ne compte plus. Les règles I2 (file sûre) et ZERO-IDLE donnent une tâche
        à tout PNJ sans tâche (le DC, 31/10 : « ils ne devraient jamais attendre ») : 0 ou 1 PNJ libre par construction, la porte fermait
        de la minute 16 à la 114 avec 4 tâches libres pour un seuil de 68 et retenait toutes les rangées d'assembleurs.
        Fermée : aucun ordre de rang >= 2 qui AJOUTE des tournées (o.tours) ; un tapis (o.belt) reste permis (il RETIRE des tournées).
        Lot VIDEO-COUVERTURE 3 (G73) : la RECHERCHE est coupée EXPLICITEMENT : un ordre qui la nourrit (o.research : sortes Pe.RESEARCH_KINDS,
        packs et laboratoires) est retenu porte fermée, qu'il compte ou non parmi les tournées de l'appelant, avec sa raison (« recherche coupee »).
        La recherche DÉJÀ commencée continue (les laboratoires du QG paient leurs packs au coffre) ; elle ne grandit plus tant que le transport sature.
        Effectif nul ou mesure absente : la porte est fermée (garde fermée par défaut, L13).
    (b) BRAS À SEUIL CROISSANT (G12 « occupés > mégatuiles ÷ 25 + 1 → attendre », V73) : au plus ⌊modules ÷ Pe.MODULES_PER_SITE⌋ + 1
        chantiers ouverts à la fois ; un ordre qui OUVRE un chantier (o.site) n'est permis que s'il reste une place. Lot COUVERTURE : plancher a.site_floor (les emplacements de chantier de la capitalisation, Em.slots) : la limite ne descend jamais sous lui ; les modules posés comptés par Capi.slots sont cumulés (Cv.batis). Écart [DÉDUIT] à la
        source : le gist comptait des robots occupés, nous comptons des chantiers ouverts (un chantier occupe les bras jusqu'à sa fin).
    (a) PETITES MARCHES (V21, V77, V78) : quand le transport est tendu (porte fermée OU mesure tendue) ou quand l'ordre vient d'un manque
        MESURÉ (o.measured), il ne pose qu'UNE unité de capacité (o.n ramené à 1) ; la remesure dira s'il en faut une de plus.
    (d) ANTI-RÉPÉTITION (G27, G47, G51) : un ordre sur un manque MESURÉ ne vise pas le même objet que l'ordre mesuré de la décision
        précédente (le signal est en retard sur la pose), sauf s'il est le seul en manque de son rang (o.alone).
  Invariants : (I1) jamais plus d'ordres qui ouvrent un chantier que de places de (b) ; (I2) les rangs R0 et R1 (o.rank <= 1 : survivre,
  réparer, protéger) ne sont JAMAIS retenus ni réduits par ces portes.
  Déterminisme : la liste est lue dans l'ordre reçu, entiers en ‰, aucun `pairs`, aucun hasard, aucun temps mesuré (mesures = état du jeu).
  Coût : O(nombre d'ordres) par décision, O(1) par mesure.
]]

local Pe = {}

Pe.BACKLOG_PER = 3        -- tendu au-delà de 3 tâches libres par PNJ (+ base) ; 2 PNJ : 8 ; 30 PNJ : 92
Pe.BACKLOG_EXIT_PER = 2   -- détendu à 2 tâches libres par PNJ au plus (+ base)
Pe.BACKLOG_BASE = 2
Pe.SAT_THINKS = 2         -- mesures de suite pour fermer, puis pour rouvrir (« pendant 2 pensées de suite »)
Pe.MODULES_PER_SITE = 25  -- G12 : un chantier parallèle de plus par 25 modules posés
Pe.SAFE_RANK = 1          -- rangs <= 1 (R0 survivre, R1 réparer et protéger) jamais retenus (I2)
-- Sortes d'ordres de la capitalisation qui nourrissent la RECHERCHE (G73) : des packs de plus, des laboratoires de plus. Des NOMS DE SORTES d'ordres
-- (shared/ai3/capitalisation.lua, Pi.order_family), pas des objets du jeu.
Pe.RESEARCH_KINDS = { packs = true, labos = true }

local function int(v) if type(v) ~= "number" or v ~= v then return nil end return math.floor(v) end

function Pe.new() return { closed = false, tense_n = 0, calm_n = 0, last_item = nil, closes = 0 } end

--- Mesure du transport. a = { workers (PNJ), idle (PNJ libres), free_tasks (tâches libres qui attendent) }.
--- Rend tendu, detendu, cause (texte), ou nil, nil, cause pour une mesure absente.
function Pe.measure(a)
  local w, idle, free = int(a and a.workers), int(a and a.idle), int(a and a.free_tasks)
  if not w or not idle or not free then return nil, nil, "mesure absente" end
  if w <= 0 then return true, false, "aucun PNJ" end
  local y = Pe.BACKLOG_PER * w + Pe.BACKLOG_BASE
  local y_exit = Pe.BACKLOG_EXIT_PER * w + Pe.BACKLOG_BASE
  local tense = free > y
  local calm = free <= y_exit
  return tense, calm, string.format("%d PNJ libre(s) sur %d, %d tache(s) libre(s) (tendu au-dela de %d)", idle, w, free, y)
end

--- Une mesure (une pensée) : met la porte du transport à jour. Rend st.closed, cause.
function Pe.transport(st, a)
  local tense, calm, cause = Pe.measure(a)
  if tense == nil then
    st.unknown = true
    return true, cause -- garde fermée par défaut ; l'état mémorisé ne bouge pas
  end
  st.unknown = false
  st.tense_now = tense
  if not st.closed then
    st.tense_n = tense and (st.tense_n or 0) + 1 or 0
    if st.tense_n >= Pe.SAT_THINKS then
      st.closed, st.calm_n, st.closes = true, 0, (st.closes or 0) + 1
    end
  else
    st.calm_n = calm and (st.calm_n or 0) + 1 or 0
    if st.calm_n >= Pe.SAT_THINKS then st.closed, st.tense_n = false, 0 end
  end
  return st.closed, cause
end

--- Places de chantier (b) : ⌊modules ÷ Pe.MODULES_PER_SITE⌋ + 1 moins les chantiers ouverts (jamais négatif).
--- FERMÉ PAR DÉFAUT (lot 5b, W04 n°1) : un nombre de modules posés ou de chantiers ouverts ABSENT ne vaut pas zéro (avant : limite 1 et
--- aucun chantier ouvert = une place de chantier offerte sur une mesure manquante) ; aucune place, la raison nomme l'entrée. Rend
--- room, limit, raison (nil quand les deux mesures sont là).
function Pe.site_room(batis, open_sites, floor)
  local b, o = int(batis), int(open_sites)
  if b == nil or o == nil then return 0, 0, "mesure absente : " .. (b == nil and "batis (modules poses)" or "open_sites (chantiers ouverts)") end
  local limit = math.floor(math.max(0, b) / Pe.MODULES_PER_SITE) + 1
  -- Lot COUVERTURE : plancher = les emplacements de chantier de la capitalisation (Em.slots : 2 de base, plus un par tranche de stock de
  -- plaques) ; la limite de G12 suit les modules posés, trop basse pour une force qui a le stock de poser (mesuré : 1 chantier à la fois à la
  -- minute 257). Absent : la limite d'avant.
  local fl = int(floor)
  if fl ~= nil and fl > limit then limit = fl end
  return math.max(0, limit - math.max(0, o)), limit
end

--- Porte d'UNE décision (unité 1 d'une décision découpée : Ca.decide_begin). a = { workers, idle, free_tasks, batis (modules et
--- bâtiments posés), open_sites } (état du jeu à cette pensée). Met la porte du transport à jour (st) et rend g = { closed, tense,
--- room, limit, batis, last_item, cause } : table de TRAVAIL de la décision (nombres, booléens, une chaîne), lue option par option.
function Pe.gate(st, a)
  local closed, cause = Pe.transport(st, a)
  local room, limit, site_why = Pe.site_room(a and a.batis, a and a.open_sites, a and a.site_floor)
  return { closed = closed, tense = closed or st.tense_now or st.unknown or false, room = room, limit = limit, site_why = site_why,
    batis = int(a and a.batis) or 0, last_item = st.last_item, measured_item = nil, cause = cause }
end

--- Une option (un tour de la boucle des ordres : decide_turn) : nil si elle passe, sinon la raison. o = { item, n, rank, tours,
--- belt, site, measured, alone }.
function Pe.check(g, o)
  local rank = int(o.rank) or 3
  if rank > Pe.SAFE_RANK then
    if g.closed and o.research and not o.belt then
      return "recherche coupee : transport sature : " .. tostring(g.cause)
    elseif g.closed and o.tours and not o.belt and not o.root then
      return "transport sature : " .. tostring(g.cause)
    elseif o.site and g.room <= 0 then
      if g.site_why then return "bras : " .. g.site_why .. " (aucun chantier de plus sans mesure)" end
      return string.format("bras : %d chantier(s) ouvert(s) au plus pour %d module(s)", g.limit, g.batis)
    elseif o.measured and o.item ~= nil and o.item == g.last_item and not o.alone then
      return "repetition : meme objet qu'a la decision precedente (signal en retard sur la pose)"
    end
  end
  return nil
end

--- Unités permises pour une option qui passe : 1 si tendu ou manque mesuré (petite marche), sinon o.n. Rend (n, réduit).
function Pe.units(g, o)
  local rank = int(o.rank) or 3
  if rank > Pe.SAFE_RANK and (g.tense or o.measured) and (int(o.n) or 1) > 1 then return 1, true end
  return o.n, false
end

--- L'option choisie est prise : une place de chantier de moins, objet mesuré noté.
function Pe.take(g, o)
  local rank = int(o.rank) or 3
  if o.site and rank > Pe.SAFE_RANK then g.room = g.room - 1 end
  if o.measured and rank > Pe.SAFE_RANK then g.measured_item = o.item end
end

--- Fin de la décision (compte rendu) : l'objet mesuré de cette décision devient celui de l'anti-répétition suivante.
function Pe.finish(st, g) st.last_item = g.measured_item end

--- Une décision sur une liste déjà triée (branchement après coup, ou banc) : Pe.gate, puis Pe.check, Pe.units, Pe.take par ordre,
--- puis Pe.finish. orders = { { key, item, n, rank, tours, belt, site, measured, alone, root } }. Rend { kept = { copies, n réduit },
--- refused = { { key, why } }, closed, room, limit, cause }.
function Pe.decide(st, a, orders)
  local g = Pe.gate(st, a)
  local kept, refused = {}, {}
  for _, o in ipairs(orders or {}) do
    local why = Pe.check(g, o)
    if why then
      refused[#refused + 1] = { key = o.key, why = why }
    else
      local c = {}
      for _, k in ipairs({ "key", "item", "n", "rank", "tours", "belt", "site", "measured", "alone", "research", "root" }) do c[k] = o[k] end
      c.n, c.reduced = Pe.units(g, o)
      if not c.reduced then c.reduced = nil end
      Pe.take(g, o)
      kept[#kept + 1] = c
    end
  end
  Pe.finish(st, g)
  return { kept = kept, refused = refused, closed = g.closed, room = g.room, limit = g.limit, cause = g.cause }
end

--- Traduction d'un ordre de la capitalisation (shared/ai3/capitalisation.lua, res.orders) en ordre de la porte. ctx = {
---   family_of = fonction (kind -> famille, Pi.order_family), family_rank = { [famille] = rang } (Pi.FAMILY_RANK),
---   site_kinds = { [kind] = vrai } : ordres qui OUVRENT un chantier du plan directeur (Capi.MODULE_KINDS, champ compris),
---   tours_kinds = { [kind] = vrai } : ordres qui AJOUTENT des tournées de PNJ (chantiers, laboratoires servis à la main),
---   measured = { [objet] = n } : manque net MESURÉ de L3 (view.mq.build, shared/ai3/manque_local.lua ; nil : L3 éteint, rien n'est
---   mesuré), measured_n = nombre d'objets en manque mesuré (un seul : la répétition est permise, G27) }.
--- `belt` reste faux : aucun ordre de la capitalisation n'est une voie à tapis seule.
function Pe.translate(o, ctx)
  local fam = ctx.family_of and ctx.family_of(o.kind) or nil
  local site = (ctx.site_kinds or {})[o.kind] == true
  local item = o.item or o.resource
  local measured = item ~= nil and ((ctx.measured or {})[item] or 0) > 0
  local research = Pe.RESEARCH_KINDS[o.kind] == true
  -- RACINE (lot tv-fer) : un ordre qui crée la source d'un objet en manque (ctx.root_of(o) rend le manque, n > 0) ne subit pas la porte
  -- du transport : le « 0 PNJ libre » vient de ce manque (les PNJ le remplacent à la main), la porte le retiendrait pour toujours.
  local root_n = ctx.root_of and ctx.root_of(o) or nil
  local root = type(root_n) == "number" and root_n > 0 and not research
  return { key = o.key, root = root or nil, root_n = root and root_n or nil, item = item, n = o.n, rank = (fam ~= nil and (ctx.family_rank or {})[fam]) or 3,
    site = site, tours = research or (ctx.tours_kinds or {})[o.kind] == true, belt = false, measured = measured,
    alone = measured and (ctx.measured_n or 0) == 1, research = research }
end

--- Filtre d'une décision (branchement dans le runtime, script/ai3/capitalisation.lua decide_finish, AVANT la boucle d'envoi). Rend
--- { why = { [clé] = raison } (ordres retenus), kept (nombre), refused (nombre), reduced (ordres qu'une petite marche aurait réduits :
--- la taille ne se change pas après la décision, coût et objets étant calculés pour o.n ; mesure seulement), closed, room, limit, cause }.
function Pe.filter(st, a, orders, ctx)
  local g = Pe.gate(st, a)
  local why, kept, refused, reduced, roots = {}, 0, 0, 0, {}
  for _, o in ipairs(orders or {}) do
    local p = Pe.translate(o, ctx)
    local w = Pe.check(g, p)
    if w then
      why[o.key] = w
      refused = refused + 1
    else
      if p.root and g.closed and p.tours and not p.belt and p.rank > Pe.SAFE_RANK then
        roots[#roots + 1] = { key = o.key, item = p.item, need = p.root_n } -- passe la porte FERMÉE parce que racine (journal)
      end
      local _, red = Pe.units(g, p)
      if red then reduced = reduced + 1 end
      Pe.take(g, p)
      kept = kept + 1
    end
  end
  Pe.finish(st, g)
  return { why = why, kept = kept, refused = refused, reduced = reduced, roots = roots, closed = g.closed, room = g.room, limit = g.limit,
    cause = g.cause }
end

--- Ligne de journal (aucune décision ne la lit).
function Pe.describe(st, res)
  return string.format("transport %s (%d fermeture(s)), %d ordre(s) gardes, %d retenu(s), places de chantier %d sur %d ; %s",
    res.closed and "SATURE" or "libre", st.closes or 0, #res.kept, #res.refused, res.room, res.limit, tostring(res.cause))
end

return Pe
