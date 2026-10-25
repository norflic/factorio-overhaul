--[[
  MODÈLE DE L'ADVERSAIRE (lot IA2-c, « mémoire et ennemis ») — PUR (aucune API Factorio), testable hors jeu
  (tests/adversaire_test.lua). Conception : fo-logs/2026-10-24_ANALYSE/IA_ADAPTATIVE.md §B3.2 (ce qui est vu, ce qui
  est estimé, style, réponses), §B6.1 (moment d'une attaque ±20 %), §B6.2 (hésiter au rassemblement) ; choix
  provisoires D-16 : brouillard partout, LE JOUEUR AUSSI ; 1re attaque contre le joueur entre 20 et 32 min en Normal.

  Ce module ne lit que des nombres et des positions déjà connues du script (calcul pur) :
    - VISION : un secteur de 64 × 64 tuiles est « vu » quand son centre est à moins de r + MARGIN tuiles d'un œil de
      la faction (QG, avant-poste, groupe en route, éclaireur ; rayons A.VISION) ;
    - DÉFENSE PAR CÔTÉ : tourelles VUES autour du point visé, réparties sur les 8 octants (C.octant) ; une tourelle à
      moins de SIDE_NEAR tuiles défend tous les côtés ;
    - CÔTÉ D'ARRIVÉE contre le joueur : le côté le moins défendu, pondéré par le détour (écart à la direction directe) ;
      octant d'une attaque repoussée pénalisé ; hasard borné entre les options à 90 % ou plus de la meilleure ;
    - STYLE (A.classify) : tortue, expansionniste, agresseur, bâtisseur (qui décolle), équilibré, inconnu, à partir de
      relevés (territoire vu, tourelles vues, croissance sur 10 min, coups reçus de lui) ;
    - CIBLE (A.pick_target) selon le style : la plus proche (règle d'IA0) ; contre une tortue, la moins défendue
      (harcèlement des avant-postes) ; contre un expansionniste, la plus isolée ;
    - GO / NO-GO au rassemblement (A.go) : la défense vue a grossi (≥ 1,5 × celle du départ + 1 tourelle) et le groupe
      n'a plus le rapport de force : la faction renonce ;
    - MOMENT de la 1re attaque de la partie contre le joueur (A.first_after) : valeur du niveau × tempo tiré à ±20 %
      (une fois par partie). L'intervalle entre deux attaques × tempo tiré à chaque attaque a été mesuré et NON
      retenu (il casse l'ordre strict des niveaux, S.player_cooldown).

  Déterminisme : entiers, listes triées, tirages injectés (`draw(n)` → 1 à n) ; aucune trigonométrie (octants par
  comparaisons, vecteurs constants de C.DIRS).
]]

local C = require("shared.faction.chef")

local A = {}

A.VISION = { hq = 160, outpost = 128, group = 96, scout = 128 }
A.MARGIN = 32               -- un secteur est vu quand son centre est à moins de r + 32 tuiles d'un œil
A.SECTOR = 64
A.TURRET_DEF = 8            -- défense d'une tourelle (équivalents fusiliers, comme F.pvp_rules.defense_per_turret)
A.DEF_RADIUS = 40           -- tourelles comptées autour du point visé (F.pvp_rules.defense_radius)
A.SIDE_NEAR = 8             -- une tourelle à moins de 8 tuiles du point visé défend tous les côtés
A.SIDE_RADIUS = 56          -- rassemblement avancé à 56 tuiles du point visé (C.SIDE_RADIUS)
A.GO_GROWTH = 1500          -- renonce si la défense vue ≥ 1,5 × celle du départ + 1 tourelle (et rapport de force perdu)
A.TEMPO = 200               -- moment : ±20 % (pour mille)
-- Moment nominal de la 1re attaque de la partie contre le joueur (min), par niveau : Normal 26 (milieu des bornes
-- D-16, 20 à 32 min) ; les autres niveaux gardent l'ordre strict (même tempo pour tous les niveaux d'une partie).
A.FIRST_MIN = { easy = 40, normal = 26, hard = 16, merciless = 9 }
A.SCOUT_LEAD = 10 * 3600    -- 1er éclaireur 10 min avant la fin de la grâce (6 au 2e essai : éclaireurs tués en route)
A.SCOUT_GAP = 5 * 3600      -- un éclaireur au plus toutes les 5 min par faction
A.STALE = 10 * 3600         -- un secteur connu non revu depuis 10 min : nouvel éclaireur
A.MEMORY = 8                -- attaques retenues
A.SNAPS = 16                -- relevés retenus (un par minute)
A.GROWTH_WINDOW = 10 * 3600 -- croissance mesurée sur 10 min
A.HIT_WINDOW = 15 * 3600    -- coups reçus « récents »

A.STYLES = { "inconnu", "equilibre", "batisseur", "expansionniste", "tortue", "agresseur" }

---------------------------------------------------------------------------------------------------
-- Secteurs
---------------------------------------------------------------------------------------------------
--- Clé d'un secteur (même formule que State.chunk_key).
function A.key(sx, sy) return (sx + 32768) * 65536 + (sy + 32768) end

function A.xy(key)
  local sx = math.floor(key / 65536) - 32768
  return sx, key - (sx + 32768) * 65536 - 32768
end

function A.sector_of(x, y) return math.floor(x / A.SECTOR), math.floor(y / A.SECTOR) end

function A.center(sx, sy) return sx * A.SECTOR + A.SECTOR / 2, sy * A.SECTOR + A.SECTOR / 2 end

--- Secteurs vus par une liste d'yeux { x, y, r } : liste de clés dans l'ordre des yeux puis des secteurs (sans
--- doublon). `seen` (facultatif) : ensemble à compléter (clé → true).
function A.visible(eyes, seen, out)
  seen, out = seen or {}, out or {}
  for _, e in ipairs(eyes) do
    local R = e.r + A.MARGIN
    local R2 = R * R
    local x0, x1 = math.floor((e.x - R) / A.SECTOR), math.floor((e.x + R) / A.SECTOR)
    local y0, y1 = math.floor((e.y - R) / A.SECTOR), math.floor((e.y + R) / A.SECTOR)
    for sy = y0, y1 do
      for sx = x0, x1 do
        local cx, cy = A.center(sx, sy)
        local dx, dy = cx - e.x, cy - e.y
        if dx * dx + dy * dy <= R2 then
          local k = A.key(sx, sy)
          if not seen[k] then
            seen[k] = true
            out[#out + 1] = k
          end
        end
      end
    end
  end
  return out, seen
end

--- Un point est-il vu par l'un des yeux ?
function A.sees(eyes, x, y)
  for _, e in ipairs(eyes) do
    local dx, dy = x - e.x, y - e.y
    if dx * dx + dy * dy <= e.r * e.r then return true end
  end
  return false
end

---------------------------------------------------------------------------------------------------
-- Défense vue, par côté
---------------------------------------------------------------------------------------------------
--- Tourelles (liste de positions) à moins de `radius` tuiles du point visé.
function A.turrets_near(turrets, target, radius)
  radius = radius or A.DEF_RADIUS
  local n = 0
  for _, t in ipairs(turrets) do
    local dx, dy = t.x - target.x, t.y - target.y
    if dx * dx + dy * dy <= radius * radius then n = n + 1 end
  end
  return n
end

--- Défense par octant (0 à 7, même découpage que C.octant) autour du point visé : chaque tourelle VUE à moins de
--- `radius` tuiles compte A.TURRET_DEF pour son octant et la moitié pour les deux voisins ; une tourelle à moins de
--- A.SIDE_NEAR tuiles compte pour tous les côtés. Renvoie une table [0..7] d'entiers.
function A.side_defense(turrets, target, radius)
  radius = radius or A.DEF_RADIUS
  local s = {}
  for o = 0, 7 do s[o] = 0 end
  local per, half = A.TURRET_DEF, math.floor(A.TURRET_DEF / 2)
  for _, t in ipairs(turrets) do
    local dx, dy = t.x - target.x, t.y - target.y
    local d2 = dx * dx + dy * dy
    if d2 <= radius * radius then
      if d2 < A.SIDE_NEAR * A.SIDE_NEAR then
        for o = 0, 7 do s[o] = s[o] + per end
      else
        local o = C.octant(dx, dy)
        s[o] = s[o] + per
        s[(o + 1) % 8] = s[(o + 1) % 8] + half
        s[(o + 7) % 8] = s[(o + 7) % 8] + half
      end
    end
  end
  return s
end

--- Choix du côté d'arrivée contre le joueur : score = détour (écart à la direction directe : 1 000, 800, 450, 150,
--- 50) × 8 / (8 + défense vue du côté : une tourelle divise par 2) ; × 0,3 pour un octant où une attaque a été
--- repoussée (`penal[o]` vrai) ;
--- hasard borné (C.pick : options à 90 % ou plus de la meilleure). `direct` : octant de notre QG vu de la cible.
--- Renvoie l'octant choisi et la liste notée (triée).
function A.pick_side(sides, direct, penal, draw)
  local base = { [0] = 1000, 800, 450, 150, 50 }
  if direct < 0 then direct = 0 end
  local list = {}
  for o = 0, 7 do
    local gap = math.abs(o - direct)
    if gap > 4 then gap = 8 - gap end
    local s = math.floor(base[gap] * 8 / (8 + (sides[o] or 0)))
    if penal and penal[o] then s = math.floor(s * 3 / 10) end
    list[#list + 1] = { key = o, score = math.max(1, s), i = o }
  end
  table.sort(list, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.i < b.i
  end)
  local pick = C.pick(list, draw)
  return pick.key, list
end

---------------------------------------------------------------------------------------------------
-- Go / no-go au rassemblement
---------------------------------------------------------------------------------------------------
--- La faction attaque-t-elle encore, arrivée au rassemblement ? Non si la défense VUE maintenant (`seen`) a grossi
--- (≥ GO_GROWTH × celle du départ `launch` + une tourelle) ET que la force du groupe (`force`, équivalents fusiliers)
--- n'atteint plus `ratio` × cette défense. Renvoie true (go) ou false (renonce).
function A.go(force, ratio, launch, seen)
  launch, seen = launch or 0, seen or 0
  local grew = seen * 1000 >= launch * A.GO_GROWTH + A.TURRET_DEF * 1000
  if grew and force < ratio * seen then return false end
  return true
end

---------------------------------------------------------------------------------------------------
-- Moment
---------------------------------------------------------------------------------------------------
--- Tempo (pour mille) tiré à ±A.TEMPO.
function A.draw_tempo(draw)
  return 1000 - A.TEMPO - 1 + draw(2 * A.TEMPO + 1)
end

--- Tick avant lequel aucune faction n'attaque le joueur pour la 1re fois de la partie : ancre + valeur du niveau ×
--- tempo. nil pour un niveau sans valeur (Paisible).
function A.first_after(anchor, level, tempo)
  local m = A.FIRST_MIN[level]
  if not m then return nil end
  return (anchor or 0) + math.floor(m * 3600 * (tempo or 1000) / 1000)
end

---------------------------------------------------------------------------------------------------
-- Style
---------------------------------------------------------------------------------------------------
--- Relevé (une fois par minute) : { tick, units (territoire vu : secteurs du joueur, avant-postes d'une rivale),
--- turrets (tourelles vues), spread (étendue vue, tuiles) }. Garde A.SNAPS relevés.
function A.snap(m, rec)
  m.snaps = m.snaps or {}
  m.snaps[#m.snaps + 1] = rec
  while #m.snaps > A.SNAPS do table.remove(m.snaps, 1) end
end

--- Croissance du territoire vu sur GROWTH_WINDOW (unités), depuis le plus ancien relevé de la fenêtre où quelque chose
--- était déjà vu (moteur réel, essai 1 du lot : la DÉCOUVERTE du joueur comptait comme une croissance, d'où un
--- « bâtisseur » à la première minute).
function A.growth(m, tick)
  local snaps = m.snaps or {}
  local last = snaps[#snaps]
  if not last then return 0 end
  local ref
  for _, s in ipairs(snaps) do
    if tick - s.tick <= A.GROWTH_WINDOW and s.units > 0 then ref = s break end
  end
  ref = ref or last
  return last.units - ref.units
end

--- Coups reçus de cet adversaire dans la fenêtre récente (liste de ticks).
function A.recent(list, tick, window)
  local n = 0
  for _, t in ipairs(list or {}) do if tick - t <= (window or A.HIT_WINDOW) then n = n + 1 end end
  return n
end

--- Classement du style (seuils simples, §B3.2) :
---   agresseur      : au moins `aggr` coups (bâtiments détruits, sites perdus) reçus de lui en 15 min ;
---   tortue         : au moins 2,5 tourelles vues par unité de territoire (`per_unit` : 1 000 = 1 par unité ; secteurs
---                    pour le joueur, avant-postes pour une rivale) ou au moins 2 attaques repoussées, et croissance ≤ 1 ;
---   expansionniste : territoire ≥ 4, croissance ≥ 2 en 10 min ou étendue ≥ 256 tuiles, moins de 1,5 tourelle par unité ;
---   bâtisseur      : croissance ≥ 1 et moins d'une tourelle par unité (« qui décolle ») ;
---   équilibré      : territoire vu, aucun des cas ; inconnu : rien de vu.
--- `o` = { units, turrets, growth, spread, hits, repulsed, aggr (seuil, 2 par défaut) }. Renvoie le style.
function A.classify(o)
  local units, turrets = o.units or 0, o.turrets or 0
  if (o.hits or 0) >= (o.aggr or 2) then return "agresseur" end
  if units <= 0 and (o.repulsed or 0) == 0 then return "inconnu" end
  local per = math.floor(turrets * 1000 / math.max(1, units))
  local growth = o.growth or 0
  if (per >= 2500 or (o.repulsed or 0) >= 2) and growth <= 1 then return "tortue" end
  if units >= 4 and (growth >= 2 or (o.spread or 0) >= 256) and per < 1500 then return "expansionniste" end
  if growth >= 1 and per < 1000 then return "batisseur" end
  if units <= 0 then return "inconnu" end
  return "equilibre"
end

---------------------------------------------------------------------------------------------------
-- Cible selon le style
---------------------------------------------------------------------------------------------------
--- Choix d'un secteur visé parmi `list` (secteurs connus : { key, x, y (installation visée), def (défense vue
--- autour) }), depuis `from` (notre QG) ; `home` : clé du secteur de départ (visé en dernier, comme un QG).
---   par défaut (équilibré, bâtisseur, agresseur, inconnu) : le plus proche (règle d'IA0) ;
---   tortue : le MOINS défendu, puis le plus proche (harcèlement des avant-postes, pas l'assaut des tourelles) ;
---   expansionniste : le plus ISOLÉ (moins de secteurs connus à 128 tuiles), puis le plus proche.
--- Renvoie l'élément choisi (ou nil).
function A.pick_target(list, from, home, style)
  local best, bk1, bk2
  for _, s in ipairs(list) do
    local dx, dy = s.x - from.x, s.y - from.y
    local d = dx * dx + dy * dy
    local k1 = 0
    if style == "tortue" then
      k1 = s.def or 0
    elseif style == "expansionniste" then
      for _, o in ipairs(list) do
        if o ~= s then
          local ex, ey = o.x - s.x, o.y - s.y
          if ex * ex + ey * ey <= 128 * 128 then k1 = k1 + 1 end
        end
      end
    end
    if s.key == home then k1 = k1 + 1e9 end
    if not best or k1 < bk1 or (k1 == bk1 and (d < bk2 or (d == bk2 and s.key < best.key))) then
      best, bk1, bk2 = s, k1, d
    end
  end
  return best
end

---------------------------------------------------------------------------------------------------
-- Mémoire des attaques données (contre le joueur)
---------------------------------------------------------------------------------------------------
function A.record_given(m, rec)
  m.given = m.given or {}
  m.given[#m.given + 1] = { gid = rec.gid, key = rec.key, octant = rec.octant, n = rec.n, tick = rec.tick }
  while #m.given > A.MEMORY do table.remove(m.given, 1) end
end

--- Issue d'une attaque donnée : « reussie », « repoussee », « aneantie », « dissous » (F174 : sans leçon) ou
--- « renonce » (go / no-go). Une attaque repoussée ou anéantie apprend la défense (soldats perdus) du secteur visé ;
--- une attaque réussie l'efface ; « renonce » retient la défense vue au rassemblement (`seen`).
function A.record_outcome(m, gid, outcome, sent, survivors, seen)
  for k = #(m.given or {}), 1, -1 do
    local a = m.given[k]
    if a.gid == gid and not a.outcome then
      a.outcome = outcome
      m.learned = m.learned or {}
      if outcome == "repoussee" or outcome == "aneantie" then
        local lost = math.max(0, (sent or 0) - (survivors or 0))
        if a.key then m.learned[a.key] = math.max(m.learned[a.key] or 0, lost) end
        m.repulsed = (m.repulsed or 0) + 1
      elseif outcome == "reussie" then
        if a.key then m.learned[a.key] = nil end
      elseif outcome == "renonce" then
        if a.key and seen then m.learned[a.key] = math.max(m.learned[a.key] or 0, math.floor(seen / 2)) end
      end
      return a
    end
  end
  return nil
end

--- Octants où une attaque contre ce secteur a été repoussée ou anéantie (ensemble octant → true).
function A.penalized(m, key)
  local out = {}
  for _, a in ipairs(m.given or {}) do
    if a.key == key and (a.outcome == "repoussee" or a.outcome == "aneantie") and a.octant then out[a.octant] = true end
  end
  return out
end

return A
