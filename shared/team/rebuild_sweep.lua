--[[
  Lot REBUILD-TOUT : règle PURE du relevé de reconstruction des projets du plan directeur (script/team/rebuild_sweep.lua en est
  l'exécutant). Constat du DC (29/10, 1 h 30 de partie sur 0.6.13) : « il y a des productions qui ont été détruites, des
  bâtiments, convoyeurs, améliorations qui n'ont pas été remplacés [...] c'est très bête et méchant de retenir l'emplacement des
  bâtiments qui ont été posés [...] il faut reconstruire impérativement parce que la production peut très vite se couper ».
  Les projets (b.projects[].ents) gardent déjà l'emplacement de tout ce qui a été posé (e.built) : ce relevé compare ces places au
  monde, par TRANCHES, et remet à « à bâtir » (e.built = false, donc fantôme puis ravivage par les PNJ du plan) ce qui a disparu.

  Règles :
    - TRANCHES : jamais toute la surface d'un coup. Un curseur (projet, pièce) avance de Sw.SLICE pièces par passe, une passe toutes
      les Sw.EVERY ticks ; il boucle sur tous les projets de l'équipe.
    - DEUX VUES : une pièce vue absente n'est qu'inscrite (e.miss = date) ; elle n'est rouverte que si elle est ENCORE absente à
      une vue ultérieure, au moins Sw.CALM ticks après (patience : les assaillants sont encore là, un remplacement par script ne
      doit pas se confondre avec une perte). Revue en place : l'inscription est effacée.
    - ORDRE : d'abord les ENTRÉES DE PRODUCTION (classe 1 : foreuses, tapis, bras, fours), puis le reste (classe 2), puis le projet
      et la place dans le projet.
    - PLAFONDS : au plus Sw.PASS_MAX pièces rouvertes par passe ; par projet et par heure, max(Sw.HOUR_MIN, la moitié du projet) pour le
      reste (classe 2) et max(Sw.HOUR_MIN, le projet entier) pour les ENTRÉES DE PRODUCTION (classe 1, compteur à part : lot REBUILD-SUIVI,
      la fonderie 6 d'Azur, 122 pièces, en rouvrait 61 puis attendait l'heure suivante) ;
      une même pièce détruite plus de Sw.MAX_REBUILD fois en Sw.FORGET ticks est ABANDONNÉE (e.gave_up : on ne nourrit pas
      indéfiniment un point que l'ennemi tient).
    - DANGER : `safe(c)` (fourni par l'exécutant : aucun ennemi près de la place) est consulté pièce par pièce ; une pièce en danger
      reste inscrite, sans compter dans les plafonds.
  Les types du moteur qui comptent comme « entrées de production » et ceux que le relevé laisse à d'autres mécanismes (infrastructure
  électrique) sont dans shared/ai3/reglages.lua (R.REBUILD_FIRST, R.INFRA_TYPES) : ce fichier ne nomme aucun objet du jeu.
  Déterminisme : indices, entiers, aucune itération par `pairs`, aucun hasard, aucun temps mesuré.
]]

local Sw = {}

Sw.EVERY = 180         -- 3 s entre deux passes
Sw.SLICE = 100         -- pièces regardées par passe
Sw.CALM = 600          -- 10 s : patience entre la première vue « absente » et la réouverture
Sw.PASS_MAX = 40       -- pièces rouvertes par passe au plus
Sw.HOUR = 3600 * 60    -- 1 h
Sw.HOUR_MIN = 40       -- plafond horaire par projet (au moins) ; la moitié du projet au-delà de 80 pièces
Sw.MAX_REBUILD = 4     -- détruite plus de 4 fois dans Sw.FORGET : abandonnée
Sw.FORGET = 40 * 3600  -- 40 min
Sw.GAVE_KEEP = 2 * Sw.FORGET -- lot INTEG-RECONSTRUCTION (D3) : un abandon (point tenu par l'ennemi) est levé au bout de 80 min

--- Classe d'une pièce selon le TYPE du moteur : 1 = entrée de production, 2 = le reste, nil = laissée à un autre mécanisme.
function Sw.class_of(ty, first, skip)
  if not ty or (skip and skip[ty]) then return nil end
  if first and first[ty] then return 1 end
  return 2
end

--- Plafond horaire de réouvertures d'un projet de `n` pièces : la moitié du projet (au moins Sw.HOUR_MIN), le projet entier pour les
--- entrées de production (`class` = 1 ; compteur q.sw_n1 à part de q.sw_n).
function Sw.hour_cap(n, class)
  if class == 1 then return math.max(Sw.HOUR_MIN, n or 0) end
  return math.max(Sw.HOUR_MIN, math.floor((n or 0) / 2))
end

--- Tranche suivante. `sizes` : nombre de pièces de chaque projet (dans l'ordre du plan) ; (pi, ei) : curseur (projet, pièce) ; `budget` :
--- pièces à regarder au plus. Rend les segments { { pi, de, a }, ... } et le nouveau curseur (pi, ei). Le curseur boucle ; un projet
--- vide est sauté. Une passe ne regarde jamais plus de `budget` pièces, ni plus d'un tour complet.
function Sw.slice(sizes, pi, ei, budget)
  local out, n = {}, #sizes
  if n == 0 or budget <= 0 then return out, 1, 1 end
  if pi < 1 or pi > n then pi, ei = 1, 1 end
  local left, visited = budget, 0
  while left > 0 and visited < n do
    local size = sizes[pi]
    if ei > size then
      pi, ei, visited = pi % n + 1, 1, visited + 1
    else
      local last = math.min(size, ei + left - 1)
      out[#out + 1] = { pi, ei, last }
      left = left - (last - ei + 1)
      ei = last + 1
      if ei > size then pi, ei, visited = pi % n + 1, 1, visited + 1 end
    end
  end
  return out, pi, ei
end

--- Vue d'une pièce posée : `present` = une entité de ce genre est là. Rend "ok" (en place), "marque" (première vue absente) ou
--- "due" (absente à deux vues espacées de Sw.CALM : à rouvrir si les plafonds le permettent). Écrit e.miss.
function Sw.observe(e, present, tick)
  if present then
    e.miss = nil
    return "ok"
  end
  if not e.miss then
    e.miss = tick
    return "marque"
  end
  if tick - e.miss >= Sw.CALM then return "due" end
  return "marque"
end

--- Choix des pièces à rouvrir. `cands` : { { q = projet, pi = rang du projet, i = rang de la pièce, e = pièce, class = 1|2 } }.
--- `safe(c)` : vrai si aucun danger près de la place. Rend la liste choisie (ordre : classe, projet, pièce) et la liste des pièces
--- abandonnées (e.gave_up posé). Écrit q.sw_t, q.sw_n (fenêtre horaire du projet) et e.rb, e.rb_t (historique de la pièce).
function Sw.select(cands, tick, safe)
  table.sort(cands, function(a, b)
    if a.class ~= b.class then return a.class < b.class end
    if a.pi ~= b.pi then return a.pi < b.pi end
    return a.i < b.i
  end)
  local picked, gave = {}, {}
  for _, c in ipairs(cands) do
    if #picked >= Sw.PASS_MAX then break end
    local q, e = c.q, c.e
    if not e.gave_up then
      -- historique de la pièce : oubli après Sw.FORGET sans réouverture, abandon au-delà de Sw.MAX_REBUILD
      if e.rb and e.rb_t and tick - e.rb_t > Sw.FORGET then e.rb = nil end
      if (e.rb or 0) >= Sw.MAX_REBUILD then
        e.gave_up = true
        e.gave_t = tick -- lot INTEG-RECONSTRUCTION (D3) : date de l'abandon (Sw.gave_expired)
        gave[#gave + 1] = c
      else
        if not q.sw_t or tick - q.sw_t >= Sw.HOUR then q.sw_t, q.sw_n, q.sw_n1 = tick, 0, 0 end
        local used = c.class == 1 and q.sw_n1 or q.sw_n
        if (used or 0) < Sw.hour_cap(#q.ents, c.class) and (not safe or safe(c)) then
          if c.class == 1 then q.sw_n1 = (q.sw_n1 or 0) + 1 else q.sw_n = (q.sw_n or 0) + 1 end
          e.rb, e.rb_t = (e.rb or 0) + 1, tick
          picked[#picked + 1] = c
        end
      end
    end
  end
  return picked, gave
end

---------------------------------------------------------------------------------------------------
-- Lot REBUILD-SUIVI : suivi d'un projet ROUVERT par le relevé (règles pures, appelées par les exécutants)
---------------------------------------------------------------------------------------------------
-- Cause (audit 29/10, Ligue Azur) : le cerveau suit ses demandes de module (script/ai3/automatisation.lua) tant qu'elles ne sont pas
-- « fini » ; un module fini n'était plus relu. Le relevé repassait la fonderie en « reserve » sans que personne le sache : aucun but
-- ne fabriquait les fours, tapis et bras à refaire, et la fonderie restait « fini(95/95)=0/min » plus d'une heure.

--- États d'un projet de plan directeur qui valent « encore à faire » pour un module que le cerveau croyait fini.
Sw.REOPEN_STATES = { reserve = true, defrichage = true, fantomes = true, chantier = true, raccordement = true, bloque = true }

--- Lignes d'état d'un projet rouvert : toutes les 5 minutes de jeu.
Sw.ETAT_EVERY = 5 * 3600
Sw.ETAT_LOGS = 60      -- lignes [FO-REBUILD-ETAT] par équipe au plus
Sw.ETAT_ITEMS = 6      -- objets manquants cités au plus par ligne

--- Un module `m` (enregistrement du cerveau) tenu pour fini dont le projet `s` (Build.brief) est de nouveau à faire : il redevient
--- un module OUVERT (état, manques, construits relus ; production mesurée et compteur de fabrication remis à 0), donc visible des buts « module ». Rend vrai
--- si l'enregistrement a changé. Écrit m.state, m.reason, m.missing, m.built, m.total, m.reopened_at, m.reopened_n, m.rate_meas, m.made_prev.
function Sw.follow(m, s, tick)
  if not (m and s and m.state == "fini" and Sw.REOPEN_STATES[s.state]) then return false end
  m.state, m.reason = s.state, s.reason
  m.missing = s.missing or {}
  m.built, m.total = s.built or m.built, s.total or m.total
  m.reopened_at = m.reopened_at or tick
  m.reopened_n = (m.reopened_n or 0) + 1
  m.rate_meas = 0
  m.made_prev = nil -- compteur de fabrication relu à zéro au retour à « fini » (sinon la production de toute la réparation compte dans UNE minute)
  m.reserve_since, m.reserve_left = nil, nil
  return true
end

--- Lot SANS-GEL (arbitrage du DC, 29/10 vers 20 h 50, gel des améliorations pendant un siège : « Supprimer le gel »). INTEG-RECONSTRUCTION
--- (D4, 0.6.18) retenait TOUTES les améliorations (Capital.pay) jusqu'à 20 min après la dernière réouverture d'un projet : un gel dans le temps,
--- supprimé. Reste un ARBITRAGE DE MATIÈRE, sans durée : une amélioration ne se paie que sur le stock qui reste APRÈS ce que la reconstruction
--- des projets rouverts doit encore prendre au coffre (« refaire d'abord » à matière égale) ; tout ce que la reconstruction ne demande pas
--- reste libre pour améliorer, tout de suite.
--- Projets concernés (comme D4) : rouverts par le relevé ou le réseau vivant (q.reopened, q.reopened_tick : les murs d'enceinte rouverts sans
--- date n'en sont pas), encore à refaire (réserve, défrichage, fantômes, chantier), pièces à refaire (Sw.todo : ni abandonnées ni retirées).
Sw.HOLD_STATES = { reserve = true, defrichage = true, fantomes = true, chantier = true }

--- Lot FUITES-PILE (fuite b) : le projet `q` est-il EN RECONSTRUCTION (pièces DÉTRUITES à refaire, rang « s'adapter » de la pile) ? Rouvert
--- par le relevé ou le réseau vivant (q.reopened_tick) APRÈS sa dernière fin (q.finished, script/team/build.lua finish_project) ; un projet
--- jamais fini rouvert pendant sa construction : vrai. q.reopened_tick n'est jamais effacé : sans la comparaison, un pas d'AGRANDISSEMENT
--- d'une ligne déjà réparée une fois (FONDERIE-DYNAMIQUE, ligne_open : q.reopened sans date) passait pour une reconstruction (cadre
--- « réparer » qui retient l'amélioration, priorité de reconstruction, chantier lancé sans toute sa matière, stock retenu aux améliorations).
--- Lecteurs : Sw.project_needs, shared/team/rebuild_rapide.lua (Rr.partial_go), script/team/pile.lua, script/team/build.lua (Build.brief).
function Sw.rebuilding(q)
  -- (q.reopened : compteur ; un vrai booléen est accepté aussi, comme les autres lecteurs qui ne testent que sa présence)
  return (q ~= nil and q.reopened ~= nil and q.reopened ~= false and q.reopened ~= 0 and q.reopened_tick ~= nil
    and (q.finished == nil or q.reopened_tick >= q.finished)) or false
end

--- Objets qu'un projet rouvert doit encore prendre au coffre : ses pièces à refaire (Sw.todo) moins ce que sa réserve tient déjà (q.stock,
--- retiré du coffre). Liste { {objet, n} } (ordre de Sw.todo), vide si le projet n'est pas concerné. Lecteur : Sw.rebuild_needs.
function Sw.project_needs(q)
  local out = {}
  if not (Sw.rebuilding(q) and Sw.HOLD_STATES[q.state]) then return out end -- lot FUITES-PILE : un agrandissement n'en est pas
  local held = q.stock or {}
  for _, it in ipairs((Sw.todo(q))) do
    local n = it[2] - (held[it[1]] or 0)
    if n > 0 then out[#out + 1] = { it[1], n } end
  end
  return out
end

--- Besoins de reconstruction d'une équipe : somme de Sw.project_needs sur ses projets, dans l'ordre `order` (b.order). Rend la liste
--- { {objet, n} } triée par nom et la liste des projets concernés (identifiants, ordre de `order`). Lecteur : script/team/rebuild_sweep.lua
--- (Sweep.upgrade_stock).
function Sw.rebuild_needs(projects, order)
  local count, names, ids = {}, {}, {}
  for _, pid in ipairs(order or {}) do
    local need = Sw.project_needs(projects and projects[pid])
    if #need > 0 then
      ids[#ids + 1] = pid
      for _, it in ipairs(need) do
        if not count[it[1]] then count[it[1]] = 0 names[#names + 1] = it[1] end
        count[it[1]] = count[it[1]] + it[2]
      end
    end
  end
  table.sort(names)
  local out = {}
  for i, n in ipairs(names) do out[i] = { n, count[n] } end
  return out, ids
end

--- Stock laissé aux améliorations : `stock` ({ [objet] = n }, non modifié) moins ce que la reconstruction (`needs`, Sw.rebuild_needs) y
--- prendra, objets à refaire ET, s'ils manquent, leurs ingrédients (livre de recettes `book`, shared/team/book.lua : Book:plan dépile le
--- stock comme le ferait la fabrication). Sans livre : les objets eux-mêmes seulement. Rend le stock libre et ce qui est retenu
--- ({ {objet, n} } trié par nom, vide si rien). Aucune durée : dès que la reconstruction est couverte ou finie, plus rien n'est retenu.
function Sw.upgrade_stock(stock, needs, book)
  stock = stock or {}
  if not needs or #needs == 0 then return stock, {} end
  local names = {}
  for k in next, stock do names[#names + 1] = k end -- clés seules, aussitôt triées : aucun ordre de parcours n'est suivi
  table.sort(names)
  local free
  if book then
    free = book:plan(needs, stock).avail
  else
    free = {}
    for _, k in ipairs(names) do free[k] = stock[k] end
    for _, it in ipairs(needs) do
      if free[it[1]] then free[it[1]] = math.max(0, free[it[1]] - it[2]) end
    end
  end
  local held = {}
  for _, k in ipairs(names) do
    local n = (stock[k] or 0) - (free[k] or 0)
    if n > 0 then held[#held + 1] = { k, n } end
  end
  return free, held
end

--- L'amélioration de coût `cost` ({ {objet, n} }) est-elle payable sur `stock` mais pas sur `free` (la reconstruction passe d'abord) ?
--- Lecteur : script/team/rebuild_sweep.lua (journal [FO-REBUILD-PRIO]).
function Sw.defers(stock, free, cost)
  if not cost or #cost == 0 then return false end
  local function covers(s)
    for _, it in ipairs(cost) do
      if ((s or {})[it[1]] or 0) < it[2] then return false end
    end
    return true
  end
  return covers(stock) and not covers(free)
end

--- Lot INTEG-RECONSTRUCTION (D3) : l'abandon d'une pièce détruite trop souvent (e.gave_up par Sw.select) est-il levé ? Vrai au bout de
--- Sw.GAVE_KEEP ticks : le point n'est plus tenu depuis longtemps, la pièce redevient observable (historique remis à zéro). Jamais pour une
--- pièce retirée à la main (e.hand_gave : voulu par le joueur) ni pour un abandon sans date (sauvegarde d'avant ce lot : on ne sait pas si
--- c'était un retrait à la main, il reste définitif comme avant). Lecteur : script/team/rebuild_sweep.lua (Sweep.step).
function Sw.gave_expired(e, tick)
  if not e.gave_up or e.hand_gave or not e.gave_t then return false end
  return tick - e.gave_t >= Sw.GAVE_KEEP
end

--- Lot INTEG-RECONSTRUCTION (D2) : un fantôme refusé trop souvent dans un projet. Un projet ordinaire est « bloque » (reprises à retardement,
--- puis abandon du projet) ; un projet ROUVERT (`reopened` > 0) dont les `max_retries` reprises sont épuisées abandonne la PIÈCE refusée
--- ("abandon") : sans cela il mourait « bloque » sans reprise, objets réservés gelés et emplacement d'automatisation (A.MAX_OPEN) occupé
--- pour la partie. Lecteur : script/team/build.lua (advance, état « chantier »).
function Sw.refusal_verdict(reopened, retries, max_retries)
  if (reopened or 0) > 0 and (retries or 0) >= max_retries then return "abandon" end
  return "bloque"
end

--- Lot INTEG-RECONSTRUCTION (D1) : l'enregistrement `m` du cerveau fait-il un but « auto:<produit> » ? Un module ordinaire : oui. Un module
--- demandé par la capitalisation (m.capi) : non, son ordre CAPI porte le but, SAUF s'il a été rouvert par le relevé (m.reopened_at) : l'ordre
--- est alors fermé depuis que tous ses modules étaient finis, et aucun autre émetteur ne demanderait les objets à refaire.
function Sw.goal_for_module(m)
  return not m.capi or m.reopened_at ~= nil
end

--- Le module `m` est de nouveau fini : rend la durée de la réparation en ticks (nil s'il n'avait pas été rouvert) et efface la marque.
function Sw.repaired(m, tick)
  if not (m and m.reopened_at) then return nil end
  local d = tick - m.reopened_at
  m.reopened_at = nil
  return d
end

--- Objets à refaire d'un projet (pièces `built = false` qui ont un objet) : liste { { objet, nombre } } triée par nombre décroissant
--- puis par nom, et le nombre de pièces à refaire.
function Sw.todo(q)
  local count, names, pieces = {}, {}, 0
  for _, e in ipairs(q.ents or {}) do
    if not e.built and not e.gave_up and not e.dropped then
      pieces = pieces + 1
      if e.item then
        if not count[e.item] then count[e.item] = 0 names[#names + 1] = e.item end
        count[e.item] = count[e.item] + 1
      end
    end
  end
  table.sort(names, function(a, b)
    if count[a] ~= count[b] then return count[a] > count[b] end
    return a < b
  end)
  local out = {}
  for i, n in ipairs(names) do out[i] = { n, count[n] } end
  return out, pieces
end

--- Texte « objet xN, ... » (au plus `max` objets, puis « ... »).
function Sw.items_text(list, max)
  local parts = {}
  for i, it in ipairs(list or {}) do
    if i > (max or Sw.ETAT_ITEMS) then parts[#parts + 1] = "..." break end
    parts[#parts + 1] = it[1] .. "x" .. it[2]
  end
  return table.concat(parts, ",")
end

return Sw
