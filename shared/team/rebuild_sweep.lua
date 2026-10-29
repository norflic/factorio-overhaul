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

--- Lot INTEG-RECONSTRUCTION (D4) : un projet du plan directeur ROUVERT retient-il les améliorations ? (« refaire avant d'améliorer » : le
--- registre de reconstruction, seul lu par Rc.hold_upgrades, ne contient plus les pièces des projets depuis REBUILD-TOUT, donc Capital.pay
--- dépensait les plaques de la réserve d'une fonderie à refaire.) Vrai si le projet a été rouvert il y a au plus Sw.HOLD_MAX ticks
--- (q.reopened_tick, écrit par le relevé et le réseau vivant), est encore à refaire (réserve, défrichage, fantômes, chantier) et garde
--- des pièces à refaire (Sw.todo). Pas de condition sur le stock : ce qui manque se fabrique avec les plaques que l'amélioration prendrait.
--- Lecteur : script/team/reconstruction.lua (Recon.hold_upgrades) -> script/team/team.lua (Capital.pay).
Sw.HOLD_MAX = 20 * 3600  -- comme Rc.HOLD_MAX : un site tenu par l'ennemi ne gèle pas les améliorations
Sw.HOLD_STATES = { reserve = true, defrichage = true, fantomes = true, chantier = true }
function Sw.project_holds(q, tick)
  if not (q and q.reopened and q.reopened_tick and Sw.HOLD_STATES[q.state]) then return false end
  if tick - q.reopened_tick > Sw.HOLD_MAX then return false end
  local _, pieces = Sw.todo(q)
  return pieces > 0
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
