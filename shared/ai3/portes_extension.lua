--[[
  Lot L6 de la feuille de route « Factorio Automated » (docs/VIDEO_AUTOMATISATION.md §6 L6 ; docs/TODO_VIDEO.md V21, V73, V77, V78,
  G07, G12, G13, G27, G47, G51) : LES PORTES AVANT D'ÉTENDRE, à seuils qui suivent la taille. Règle PURE (aucune API Factorio, aucun nom
  d'objet : anti-échelle de tests/iag_test.lua §8). Testée hors jeu : tests/portes_extension_test.lua. NON BRANCHÉE (plan dans le rapport).

  Défaut visé, mesuré le 7/11 (docs/IA_WORKFLOW.md §5 D1, journal de la partie du DC, [FO-ACTIF] minute 175) : « 0 PNJ libre(s), 16 tache(s)
  libre(s) » : la base ajoute des chantiers et des tournées que personne ne peut servir ; la collecte du fer (priorité 52) perd.

  Trois portes, évaluées dans l'ordre sur la liste des ordres d'UNE décision (déjà triée par l'appelant, Ca.before) :
    (c) TRANSPORT SATURÉ (G13 « libres < total ÷ 10 » : « logistic shock ») : `tendu` quand la part de PNJ libres passe SOUS Pe.IDLE_PM ‰
        de l'effectif, OU quand les tâches libres dépassent Pe.BACKLOG_PER × PNJ + Pe.BACKLOG_BASE (seuil qui suit l'effectif). La porte se
        FERME après Pe.SAT_THINKS mesures tendues de suite et ne se rouvre qu'après Pe.SAT_THINKS mesures DÉTENDUES de suite (part libre
        au moins Pe.IDLE_EXIT_PM ‰ ET tâches libres au plus Pe.BACKLOG_EXIT_PER × PNJ + Pe.BACKLOG_BASE) : hystérésis, pas de clignotement.
        Fermée : aucun ordre de rang >= 2 qui AJOUTE des tournées (o.tours) ; un tapis (o.belt) reste permis (il RETIRE des tournées).
        Effectif nul ou mesure absente : la porte est fermée (garde fermée par défaut, L13).
    (b) BRAS À SEUIL CROISSANT (G12 « occupés > mégatuiles ÷ 25 + 1 → attendre », V73) : au plus ⌊modules ÷ Pe.MODULES_PER_SITE⌋ + 1
        chantiers ouverts à la fois ; un ordre qui OUVRE un chantier (o.site) n'est permis que s'il reste une place. Écart [DÉDUIT] à la
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

Pe.IDLE_PM = 100          -- ‰ : transport tendu sous 10 % de PNJ libres (G13 : total ÷ 10)
Pe.IDLE_EXIT_PM = 200     -- ‰ : détendu à partir de 20 % de PNJ libres
Pe.BACKLOG_PER = 3        -- tendu au-delà de 3 tâches libres par PNJ (+ base) ; 2 PNJ : 8 ; 30 PNJ : 92
Pe.BACKLOG_EXIT_PER = 2   -- détendu à 2 tâches libres par PNJ au plus (+ base)
Pe.BACKLOG_BASE = 2
Pe.SAT_THINKS = 2         -- mesures de suite pour fermer, puis pour rouvrir (« pendant 2 pensées de suite »)
Pe.MODULES_PER_SITE = 25  -- G12 : un chantier parallèle de plus par 25 modules posés
Pe.SAFE_RANK = 1          -- rangs <= 1 (R0 survivre, R1 réparer et protéger) jamais retenus (I2)

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
  local tense = idle * 1000 < w * Pe.IDLE_PM or free > y
  local calm = idle * 1000 >= w * Pe.IDLE_EXIT_PM and free <= y_exit
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
function Pe.site_room(batis, open_sites)
  local limit = math.floor(math.max(0, int(batis) or 0) / Pe.MODULES_PER_SITE) + 1
  return math.max(0, limit - math.max(0, int(open_sites) or 0)), limit
end

--- Une décision. a = { workers, idle, free_tasks, batis (modules et bâtiments posés), open_sites } (état du jeu à cette pensée) ; orders = liste triée de
--- { key, item, n, rank, tours, belt, site, measured, alone }. Rend { kept = { ordres (copies, n réduit) }, refused = { { key, why } },
--- closed, room, limit, cause }. Met st à jour (porte du transport, dernier objet mesuré).
function Pe.decide(st, a, orders)
  local closed, cause = Pe.transport(st, a)
  local tense = closed or st.tense_now or st.unknown
  local room, limit = Pe.site_room(a and a.batis, a and a.open_sites)
  local kept, refused = {}, {}
  local last_measured = nil
  for _, o in ipairs(orders or {}) do
    local rank = int(o.rank) or 3
    local why = nil
    if rank > Pe.SAFE_RANK then
      if closed and o.tours and not o.belt then
        why = "transport sature : " .. tostring(cause)
      elseif o.site and room <= 0 then
        why = string.format("bras : %d chantier(s) ouvert(s) au plus pour %d module(s)", limit, int(a and a.batis) or 0)
      elseif o.measured and o.item ~= nil and o.item == st.last_item and not o.alone then
        why = "repetition : meme objet qu'a la decision precedente (signal en retard sur la pose)"
      end
    end
    if why then
      refused[#refused + 1] = { key = o.key, why = why }
    else
      local c = {}
      for _, k in ipairs({ "key", "item", "n", "rank", "tours", "belt", "site", "measured", "alone" }) do c[k] = o[k] end
      if rank > Pe.SAFE_RANK and (tense or o.measured) and (int(o.n) or 1) > 1 then c.n, c.reduced = 1, true end
      if o.site and rank > Pe.SAFE_RANK then room = room - 1 end
      if o.measured and rank > Pe.SAFE_RANK then last_measured = o.item end
      kept[#kept + 1] = c
    end
  end
  st.last_item = last_measured
  return { kept = kept, refused = refused, closed = closed, room = room, limit = limit, cause = cause }
end

--- Ligne de journal (aucune décision ne la lit).
function Pe.describe(st, res)
  return string.format("transport %s (%d fermeture(s)), %d ordre(s) gardes, %d retenu(s), places de chantier %d sur %d ; %s",
    res.closed and "SATURE" or "libre", st.closes or 0, #res.kept, #res.refused, res.room, res.limit, tostring(res.cause))
end

return Pe
