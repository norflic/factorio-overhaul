--[[
  Lot TOURELLES « où poser les tourelles d'un avant-poste ou du QG » (remarque 8 du DC, 29/10 : « bien reverifier les espaces
  proteges par les tourelles pour qu'elles couvrent un max de perimetre (sur une zone utile evidemment qui protege un batiment
  de l'equipe) »). PUR : aucune API Factorio, testé hors jeu (tests/pose_tourelles_test.lua).

  Avant le lot, `Outposts.fortify` posait les tourelles sur 8 emplacements fixes (les 4 diagonales à 7 tuiles, puis les 4 axes à
  9 tuiles du centre) dans CET ordre : une ou deux tourelles tombaient du même côté et un bâtiment à 14 tuiles du centre, de
  l'autre côté, restait hors de portée.

  Ici, on ne change NI les emplacements candidats (ils sont les mêmes, avec leur repli du moteur : `find_non_colliding_position`),
  NI le nombre de tourelles, NI leur coût, NI la tâche : on choisit seulement LESQUELS des candidats prendre, et dans quel ordre.

  Objectif : maximiser l'AIRE UTILE couverte. Les bâtiments de l'équipe sont échantillonnés en cases de Pose.CELL tuiles
  (poids = aire de leur emprise × facteur de rôle ; le coffre d'équipe pèse davantage) ; une tourelle couvre une case si son centre
  est à moins de Pose.COVER_PCT % de sa portée (lue au prototype : un assaillant s'arrête à quelques tuiles de ce qu'il attaque).
  Les tourelles déjà posées comptent (elles couvrent déjà ; inutile d'en rajouter une sur leur zone).

  Choix : parmi C(n, k) ensembles, si C ≤ Pose.MAX_COMBOS (force brute, exact : n ≤ 8 en pratique, C(8,4) = 70), sinon le glouton
  (le plus grand gain marginal à chaque tour). Départage à score égal : l'ensemble le plus ÉCARTÉ (plus grande distance minimale
  entre tourelles, existantes comprises : « tous les côtés »), puis l'ordre d'origine des candidats (donc, sans bâtiment ni
  différence de portée, EXACTEMENT l'ancien comportement). L'ordre de pose : gain marginal décroissant dans l'ensemble choisi,
  puis les candidats non choisis dans leur ordre d'origine (repli si une pose est refusée par le moteur).

  Aucun nom d'objet du jeu : les rôles sont ceux de shared/ai3/reglages.lua (R.ENTITY_ROLE). Aucun `pairs`, aucune
  trigonométrie, aucun hasard.

  Lot PD-ESPACEMENT (D07, DC 28/10 14 h 45 : « les tourelles couvrent pas assez d'espace […] une tourelle à deux cases d'une
  autre » ; 28/10 soir : « couvrir un max de périmètre utile ») : ESPACEMENT MINIMAL entre deux tourelles de l'équipe.
  - `gap(range)` : écart voulu entre centres (Pose.GAP tuiles, réduit pour une portée courte, jamais sous Pose.GAP_MIN) ;
  - `spaced(x, y, list, gap)` / `nearest(x, y, list)` : contrôle d'une position contre les tourelles déjà là ;
  - `choose` avec `spec.gap` : un ensemble qui serre deux tourelles (ou une tourelle contre une existante) passe APRÈS un
    ensemble espacé, quel que soit son score (la pose le pousserait de toute façon ailleurs) ; sans `spec.gap` : règle d'avant.
  La pose (Outposts.fortify_at, commune au QG, aux avant-postes, au front, aux îlots et à la garde de centrale) fait deux passes :
  écart Pose.gap d'abord, puis Pose.GAP_MIN (place trop serrée : le nombre voulu reste posé, jamais deux tourelles collées).
]]

local Pose = {}

Pose.CELL = 2             -- tuiles : côté d'une case d'échantillonnage des bâtiments
Pose.COVER_PCT = 80       -- une case est protégée à moins de 80 % de la portée de la tourelle
Pose.MAX_CELLS = 400      -- cases gardées au plus (les plus lourdes) : borne le coût
Pose.MAX_COMBOS = 2000    -- au-delà, le glouton
Pose.HQ_WEIGHT = 40       -- poids du coffre d'équipe (tout le stock y dort)
Pose.DEDUP = 2            -- tuiles : deux candidats plus proches que cela sont le même emplacement
-- Lot PD-ESPACEMENT : écarts entre CENTRES de tourelles (une tourelle de 2 x 2 : 6 = quatre tuiles libres entre elles). 6 garde
-- utilisables les 8 emplacements d'avant (Outposts : diagonales à 7, axes à 9 ; leur plus petit écart est 7,3).
Pose.GAP = 6              -- tuiles : écart voulu (première passe)
Pose.GAP_MIN = 3          -- tuiles : plancher (seconde passe, place trop serrée) : au moins une tuile libre entre deux tourelles
Pose.GAP_RANGE_DIV = 3    -- une portée courte réduit l'écart voulu à portée / 3 (jamais sous GAP_MIN)

-- Poids par RÔLE du moteur (shared/ai3/reglages.lua : R.ENTITY_ROLE). Un rôle absent pèse 0 : les tourelles et murs
-- ("militaire") et le personnage ne sont pas des bâtiments à protéger.
Pose.ROLE_FACTOR = { labo = 3, generateur = 3, chauffe = 3, fabrique = 3, pompe = 2, foreuse = 3, logistique = 1 }
function Pose.role_factor(role) return Pose.ROLE_FACTOR[role] or 0 end

local function d2(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return dx * dx + dy * dy end

--- Lot PD-ESPACEMENT : écart voulu entre centres de tourelles pour cette portée (tuiles). Portée inconnue : Pose.GAP.
function Pose.gap(range)
  local g = Pose.GAP
  if range and range > 0 then
    local r = range / Pose.GAP_RANGE_DIV
    if r < g then g = r end
  end
  if g < Pose.GAP_MIN then g = Pose.GAP_MIN end
  return g
end

--- Lot PD-ESPACEMENT : (x, y) est-il à au moins `gap` tuiles (centre à centre) de toutes les tourelles de `list` ({ {x, y} }) ?
--- Tolérance de 1/256 de tuile sur la distance (positions du moteur en virgule fixe, F92).
function Pose.spaced(x, y, list, gap)
  if not gap or gap <= 0 then return true end
  local g = gap - 1 / 256
  local lim = g * g
  for _, t in ipairs(list or {}) do
    if d2(x, y, t.x, t.y) < lim then return false end
  end
  return true
end

--- Lot PD-ESPACEMENT : distance à la tourelle la plus proche de `list` (nil si la liste est vide). Mesure de journal et de test.
function Pose.nearest(x, y, list)
  local m
  for _, t in ipairs(list or {}) do
    local q = d2(x, y, t.x, t.y)
    if m == nil or q < m then m = q end
  end
  return m and math.sqrt(m) or nil
end

--- Lot PD-ESPACEMENT : plus petite distance (centre à centre) entre deux tourelles d'une liste (nil sous deux tourelles).
function Pose.min_gap(list)
  local m
  for a = 1, #(list or {}) do
    for b = a + 1, #list do
      local q = d2(list[a].x, list[a].y, list[b].x, list[b].y)
      if m == nil or q < m then m = q end
    end
  end
  return m and math.sqrt(m) or nil
end

--- Bâtiments { {x, y, w} } (w entier > 0) -> cases { {x, y, w} } triées par clé de case, au plus MAX_CELLS (les plus lourdes).
function Pose.cells(assets)
  local by, keys = {}, {}
  local cell = Pose.CELL
  for _, a in ipairs(assets or {}) do
    local w = a.w or 0
    if w > 0 then
      local k = (math.floor(a.x / cell) + 32768) * 65536 + (math.floor(a.y / cell) + 32768)
      local c = by[k]
      if not c then
        c = { sx = 0, sy = 0, w = 0 }
        by[k] = c
        keys[#keys + 1] = k
      end
      c.sx, c.sy, c.w = c.sx + a.x * w, c.sy + a.y * w, c.w + w
    end
  end
  table.sort(keys)
  local out = {}
  for _, k in ipairs(keys) do
    local c = by[k]
    out[#out + 1] = { x = c.sx / c.w, y = c.sy / c.w, w = c.w, key = k }
  end
  if #out > Pose.MAX_CELLS then
    table.sort(out, function(a, b)
      if a.w ~= b.w then return a.w > b.w end
      return a.key < b.key
    end)
    local keep = {}
    for i = 1, Pose.MAX_CELLS do keep[i] = out[i] end
    table.sort(keep, function(a, b) return a.key < b.key end)
    out = keep
  end
  return out
end

--- Candidats sans doublon (ordre d'origine gardé ; un candidat à moins de DEDUP d'un précédent est écarté).
function Pose.dedup(cands)
  local out, from = {}, {}
  local lim = Pose.DEDUP * Pose.DEDUP
  for i, c in ipairs(cands or {}) do
    local dup = false
    for _, o in ipairs(out) do
      if d2(c.x, c.y, o.x, o.y) < lim then dup = true break end
    end
    if not dup then out[#out + 1] = c; from[#from + 1] = i end
  end
  return out, from
end

local function binom_capped(n, k, cap)
  if k < 0 or k > n then return 0 end
  if k > n - k then k = n - k end
  local r = 1
  for i = 1, k do
    r = r * (n - k + i) / i
    if r > cap then return cap + 1 end
  end
  return r
end

--- spec = {
---   candidates = { {x, y} }   emplacements dans l'ordre de l'ancienne règle (repli compris),
---   assets     = { {x, y, w} } bâtiments à protéger (w entier > 0),
---   range      = portée de la tourelle (tuiles, lue au prototype),
---   existing   = { {x, y} }   tourelles déjà posées (couvrent déjà, comptent dans l'écartement),
---   count      = nombre de tourelles à poser,
---   gap        = (lot PD-ESPACEMENT, facultatif) écart minimal entre centres de tourelles ; nil : règle d'avant,
--- }
--- Rend { order = {indices dans spec.candidates, dans l'ordre de pose}, chosen = n (les n premiers sont l'ensemble choisi),
---        score = aire couverte par l'ensemble choisi (en plus de l'existante), base = aire déjà couverte, total = aire totale,
---        viol = paires trop serrées dans l'ensemble choisi (existantes comprises ; 0 sans `gap`) }.
function Pose.choose(spec)
  local cands = spec.candidates or {}
  local n = #cands
  local existing = spec.existing or {}
  -- Lot PD-ESPACEMENT : un candidat à moins de `gap` d'une tourelle existante est « serré » (la pose le pousserait ailleurs).
  local g2 = (spec.gap and spec.gap > 0) and ((spec.gap - 1 / 256) * (spec.gap - 1 / 256)) or nil
  local tight = {}
  if g2 then
    for i, p in ipairs(cands) do
      for _, t in ipairs(existing) do
        if d2(p.x, p.y, t.x, t.y) < g2 then tight[i] = true break end
      end
    end
  end
  -- Ordre de repli (sans bâtiment) : l'ordre d'origine, les candidats serrés à la fin (ordre stable).
  local order = {}
  for i = 1, n do if not tight[i] then order[#order + 1] = i end end
  for i = 1, n do if tight[i] then order[#order + 1] = i end end
  local k = math.min(spec.count or 0, n)
  local range = spec.range or 0
  local cells = Pose.cells(spec.assets)
  local out = { order = order, chosen = 0, score = 0, base = 0, total = 0, viol = 0 }
  for _, c in ipairs(cells) do out.total = out.total + c.w end
  if k <= 0 or range <= 0 or #cells == 0 then return out end

  local rc = range * Pose.COVER_PCT / 100
  local rc2 = rc * rc
  -- Cases couvertes par chaque candidat, et par les tourelles existantes.
  local base = {}
  for _, t in ipairs(spec.existing or {}) do
    for j, c in ipairs(cells) do
      if d2(t.x, t.y, c.x, c.y) <= rc2 then base[j] = true end
    end
  end
  local cov = {}
  for i, p in ipairs(cands) do
    local list = {}
    for j, c in ipairs(cells) do
      if not base[j] and d2(p.x, p.y, c.x, c.y) <= rc2 then list[#list + 1] = j end
    end
    cov[i] = list
  end
  for j, c in ipairs(cells) do if base[j] then out.base = out.base + c.w end end

  -- Score d'un ensemble (liste d'indices) : poids des cases couvertes en plus de la base.
  local mark = {}
  local stamp = 0
  local function score_of(set)
    stamp = stamp + 1
    local s = 0
    for _, i in ipairs(set) do
      for _, j in ipairs(cov[i]) do
        if mark[j] ~= stamp then mark[j] = stamp; s = s + cells[j].w end
      end
    end
    return s
  end
  -- Écartement : plus petite distance (au carré) entre deux tourelles de l'ensemble ou existantes ; grande si une seule.
  local BIG = 1e12
  local function spread_of(set)
    local m = BIG
    for a = 1, #set do
      local pa = cands[set[a]]
      for b = a + 1, #set do
        local pb = cands[set[b]]
        local q = d2(pa.x, pa.y, pb.x, pb.y)
        if q < m then m = q end
      end
      for _, t in ipairs(spec.existing or {}) do
        local q = d2(pa.x, pa.y, t.x, t.y)
        if q < m then m = q end
      end
    end
    return m
  end
  -- Lot PD-ESPACEMENT : paires trop serrées d'un ensemble (entre elles, et contre les tourelles existantes) ; 0 sans `gap`.
  local function viol_of(set)
    if not g2 then return 0 end
    local v = 0
    for a = 1, #set do
      local pa = cands[set[a]]
      for b = a + 1, #set do
        local pb = cands[set[b]]
        if d2(pa.x, pa.y, pb.x, pb.y) < g2 then v = v + 1 end
      end
      if tight[set[a]] then v = v + 1 end
    end
    return v
  end
  -- Meilleur : moins de paires serrées, puis plus d'aire couverte, puis plus écarté (puis le premier rencontré).
  local function better(v, s, sp, bv, bs, bsp)
    if v ~= bv then return v < bv end
    if s ~= bs then return s > bs end
    return sp > bsp
  end

  local best, best_s, best_sp, best_v
  local function consider(set)
    local s = score_of(set)
    local sp = spread_of(set)
    local v = viol_of(set)
    if best == nil or better(v, s, sp, best_v, best_s, best_sp) then
      best, best_s, best_sp, best_v = { table.unpack(set) }, s, sp, v
    end
  end

  if binom_capped(n, k, Pose.MAX_COMBOS) <= Pose.MAX_COMBOS then
    -- Force brute, combinaisons en ordre lexicographique : à égalité parfaite, la première (= l'ancien ordre) reste.
    local set = {}
    local function rec(start, depth)
      if depth > k then consider(set) return end
      for i = start, n - (k - depth) do
        set[depth] = i
        rec(i + 1, depth + 1)
      end
      set[depth] = nil
    end
    rec(1, 1)
  else
    -- Glouton : gain marginal le plus grand, départage par l'écartement puis l'ordre (PD-ESPACEMENT : moins serré d'abord).
    local set, taken = {}, {}
    for _ = 1, k do
      local pick, ps, psp, pv
      for i = 1, n do
        if not taken[i] then
          set[#set + 1] = i
          local s, sp, v = score_of(set), spread_of(set), viol_of(set)
          set[#set] = nil
          if pick == nil or better(v, s, sp, pv, ps, psp) then pick, ps, psp, pv = i, s, sp, v end
        end
      end
      set[#set + 1] = pick
      taken[pick] = true
    end
    best = set
    best_s = score_of(set)
    best_v = viol_of(set)
  end

  -- Ordre de pose : à l'intérieur de l'ensemble, gain marginal décroissant (ordre d'origine à égalité), puis les autres.
  local ordered, used = {}, {}
  local left = {}
  for _, i in ipairs(best) do left[#left + 1] = i end
  table.sort(left)
  local acc = {}
  while #left > 0 do
    local bi, bg
    for pos, i in ipairs(left) do
      acc[#acc + 1] = i
      local g = score_of(acc)
      acc[#acc] = nil
      if bg == nil or g > bg then bi, bg = pos, g end
    end
    local i = table.remove(left, bi)
    acc[#acc + 1] = i
    ordered[#ordered + 1] = i
    used[i] = true
  end
  -- les autres : dans l'ordre de repli (PD-ESPACEMENT : les serrés à la fin ; sans `gap`, l'ordre d'origine)
  for _, i in ipairs(order) do if not used[i] then ordered[#ordered + 1] = i end end
  out.order, out.chosen, out.score, out.viol = ordered, #best, best_s, best_v or 0
  return out
end

--- Aire couverte (poids) par un ensemble de tourelles { {x, y} } : mesure de test et de journal.
function Pose.covered(assets, turrets, range)
  local rc = range * Pose.COVER_PCT / 100
  local rc2 = rc * rc
  local s, tot = 0, 0
  for _, c in ipairs(Pose.cells(assets)) do
    tot = tot + c.w
    for _, t in ipairs(turrets or {}) do
      if d2(t.x, t.y, c.x, c.y) <= rc2 then s = s + c.w break end
    end
  end
  return s, tot
end

return Pose
