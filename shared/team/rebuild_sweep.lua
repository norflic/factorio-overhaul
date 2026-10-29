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
    - PLAFONDS : au plus Sw.PASS_MAX pièces rouvertes par passe ; par projet et par heure, max(Sw.HOUR_MIN, la moitié du projet) ;
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

--- Classe d'une pièce selon le TYPE du moteur : 1 = entrée de production, 2 = le reste, nil = laissée à un autre mécanisme.
function Sw.class_of(ty, first, skip)
  if not ty or (skip and skip[ty]) then return nil end
  if first and first[ty] then return 1 end
  return 2
end

--- Plafond horaire de réouvertures d'un projet de `n` pièces.
function Sw.hour_cap(n) return math.max(Sw.HOUR_MIN, math.floor((n or 0) / 2)) end

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
        gave[#gave + 1] = c
      else
        if not q.sw_t or tick - q.sw_t >= Sw.HOUR then q.sw_t, q.sw_n = tick, 0 end
        if (q.sw_n or 0) < Sw.hour_cap(#q.ents) and (not safe or safe(c)) then
          q.sw_n = (q.sw_n or 0) + 1
          e.rb, e.rb_t = (e.rb or 0) + 1, tick
          picked[#picked + 1] = c
        end
      end
    end
  end
  return picked, gave
end

return Sw
