--[[
  POSE DES PAIRES d'un avant-poste (lot EXTENSION-FER, audit du 29/10 : « avant-poste de fer » alors que la base touche un énorme
  gisement de fer). Règles PURES (aucune API Factorio) ; l'exécution est script/faction/outposts.lua (place_pairs).

  Défaut corrigé : `place_pairs` essayait les tuiles de minerai triées par distance au centre du site et comptait CHAQUE tuile
  essayée, libre ou non, jusqu'à 40. Un agrandissement relançait le même parcours depuis le même centre : les 40 premières tuiles
  sont celles que la construction avait déjà occupées (8 foreuses 2x2 et leurs fours), 40 essais perdus, `#drills == 0`, et
  l'avant-poste était marqué `full` pour toute la partie (mesuré : Azur 4 avant-postes de fer x 8 foreuses, Ambre un seul,
  gisement de 1 200 tuiles couvert à 9 %). Trois remèdes, tous ici :

    * un emplacement DÉJÀ OCCUPÉ (tuiles de la foreuse prises) est écarté SANS COÛT : il ne compte pas dans les essais ;
    * un emplacement essayé en vain est mémorisé (`dead`) : l'appel suivant reprend où le précédent s'est arrêté, au lieu de
      refaire les mêmes 40 essais ;
    * `full` n'est dit que par un balayage COMPLET (`exhausted`) sans pose, ou à la couverture P.KAPPA (P.verdict ; le plafond de
      foreuses est supprimé depuis le lot PLAFOND-FOREUSES) ; jamais parce que le plafond d'essais a été atteint ni parce que
      l'ouvrier n'avait plus d'objets.

  Le parcours d'agrandissement ne retient que les tuiles du MÊME gisement que le centre (composante connexe, trous de P.GAP
  tuiles tolérés) dans un rayon de P.EXTEND_RADIUS : le gisement entier, sans aller prendre celui d'un autre avant-poste.

    P.key(x, y)                    -> clé d'une tuile
    P.tiles(pos, w, h)             -> clés des tuiles d'une emprise w x h centrée en pos
    P.box_tiles(lx, ty, rx, by)    -> clés des tuiles recouvertes (au sens strict) par une boîte
    P.sorted(resources, center)    -> copie triée (distance au centre, puis x, puis y)
    P.component(sorted, gap, center) -> tuiles du gisement de la première tuile (ordre conservé)
    P.new(spec)                    -> parcours (planner) : next(), occupy(keys), fail(pos), report()
    P.verdict(v)                   -> { full, fail, why }
    P.mode(c)                      -> "extend" | "build" | "rebuild" | nil (libellé d'un projet d'avant-poste)

  Déterminisme : aucune décision selon l'ordre de pairs, aucune mesure de temps, aucun hasard.
]]

local P = {}

P.MAX_ATTEMPTS = 40     -- essais AU MOTEUR (emplacements libres) par appel : celui d'avant le lot
P.BUILD_RADIUS = 14     -- rayon de la construction initiale (inchangé)
P.EXTEND_RADIUS = 32    -- rayon d'agrandissement (18 avant le lot) ; le gisement entier, borné par la portée des tourelles
-- (lot PLAFOND-FOREUSES : FAUX sans plafond de foreuses ; les tourelles des 8 points à 9 tuiles du centre couvrent environ 27
-- tuiles avec la portée vanilla de 18 : l'anneau de 27 à 32 tuiles n'est pas protégé, décision du DC attendue)
P.GAP = 2               -- tuiles vides tolérées entre deux tuiles de minerai d'un même gisement
P.SEED_MAX = 18         -- le gisement du centre commence à moins de 18 tuiles (portée des tourelles) ; sinon il est épuisé ici
P.LOGS = 60             -- lignes [FO-EXTEND] au plus par équipe
-- Lot PLAFOND-FOREUSES : couverture (‰ des tuiles du gisement minées par une foreuse de l'avant-poste) qui rend le gisement plein ;
-- la même que la capitalisation (Ca.KAPPA, shared/ai3/capitalisation.lua ; égalité vérifiée par tests/pose_paires_test.lua).
P.KAPPA = 800
local EPS = 0.01

function P.key(x, y) return x * 65536 + y end

--- Clés des tuiles d'une emprise w x h centrée en `pos` ({x, y}).
function P.tiles(pos, w, h)
  local x0, y0 = math.floor(pos.x - w / 2 + EPS), math.floor(pos.y - h / 2 + EPS)
  local out = {}
  for ty = y0, y0 + h - 1 do
    for tx = x0, x0 + w - 1 do out[#out + 1] = P.key(tx, ty) end
  end
  return out
end

--- Clés des tuiles recouvertes par la boîte (lx, ty) - (rx, by) ; un contact par le bord ne compte pas (F96).
function P.box_tiles(lx, ty, rx, by)
  local out = {}
  for y = math.floor(ty + EPS), math.ceil(by - EPS) - 1 do
    for x = math.floor(lx + EPS), math.ceil(rx - EPS) - 1 do out[#out + 1] = P.key(x, y) end
  end
  return out
end

--- Copie triée des tuiles de minerai ({x, y}) : distance au centre, puis x, puis y.
function P.sorted(resources, center)
  local out = {}
  for i, r in ipairs(resources) do out[i] = { x = r.x, y = r.y } end
  table.sort(out, function(a, b)
    local da = (a.x - center.x) ^ 2 + (a.y - center.y) ^ 2
    local db = (b.x - center.x) ^ 2 + (b.y - center.y) ^ 2
    if da ~= db then return da < db end
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)
  return out
end

--- Composante connexe de la première tuile de `sorted` (la plus proche du centre) : une tuile y entre si une autre tuile de la
--- composante est à moins de gap + 1 tuiles (Tchebychev). L'ordre d'entrée est conservé. Avec `center`, une première tuile à plus de
--- P.SEED_MAX tuiles du centre ne désigne pas le gisement de l'avant-poste (épuisé) : rien n'est rendu.
function P.component(sorted, gap, center)
  if #sorted == 0 then return {} end
  gap = gap or P.GAP
  if center and (sorted[1].x - center.x) ^ 2 + (sorted[1].y - center.y) ^ 2 > P.SEED_MAX * P.SEED_MAX then return {} end
  local reach = gap + 1
  local at = {}
  for i, r in ipairs(sorted) do at[P.key(math.floor(r.x), math.floor(r.y))] = i end
  local seen = {}
  local first = sorted[1]
  local queue, head = { { math.floor(first.x), math.floor(first.y) } }, 1
  seen[P.key(queue[1][1], queue[1][2])] = true
  while head <= #queue do
    local cx, cy = queue[head][1], queue[head][2]
    head = head + 1
    for dy = -reach, reach do
      for dx = -reach, reach do
        local k = P.key(cx + dx, cy + dy)
        if at[k] and not seen[k] then
          seen[k] = true
          queue[#queue + 1] = { cx + dx, cy + dy }
        end
      end
    end
  end
  local out = {}
  for _, r in ipairs(sorted) do
    if seen[P.key(math.floor(r.x), math.floor(r.y))] then out[#out + 1] = r end
  end
  return out
end

--- Parcours des emplacements de foreuse. spec = {
---   resources = tuiles triées ({x, y}, centres de tuile), cap = essais au moteur au plus (P.MAX_ATTEMPTS),
---   w, h = emprise de la foreuse (2, 2), occupied = ensemble de clés de tuiles déjà prises, dead = ensemble des emplacements
---   déjà essayés en vain (les deux sont lus ET complétés par le parcours) }
--- next() rend le prochain emplacement { x, y } À ESSAYER AU MOTEUR (centre entier de la foreuse), ou nil : balayage fini
--- (report().exhausted) ou plafond d'essais atteint (report().capped).
function P.new(spec)
  local res = spec.resources
  local cap = spec.cap or P.MAX_ATTEMPTS
  local w, h = spec.w or 2, spec.h or 2
  local occupied = spec.occupied or {}
  local dead = spec.dead or {}
  local mined = spec.mined or {} -- lot PLAFOND-FOREUSES : tuiles minées par une foreuse de l'avant-poste (lu par report().covered)
  local pl = { attempts = 0, skipped_occupied = 0, skipped_dead = 0, exhausted = false, capped = false }
  local tried, i = {}, 0

  function pl.occupy(keys)
    for _, k in ipairs(keys) do occupied[k] = true end
  end

  function pl.cover(keys)
    for _, k in ipairs(keys) do mined[k] = true end
  end

  function pl.fail(pos)
    dead[P.key(pos.x, pos.y)] = true
  end

  function pl.next()
    while true do
      local r = res[i + 1]
      if not r then
        pl.exhausted = true
        return nil
      end
      local pos = { x = math.floor(r.x + 0.5), y = math.floor(r.y + 0.5) }
      local key = P.key(pos.x, pos.y)
      if tried[key] then
        i = i + 1
      elseif dead[key] then
        i = i + 1
        tried[key] = true
        pl.skipped_dead = pl.skipped_dead + 1
      else
        local taken = false
        for _, k in ipairs(P.tiles(pos, w, h)) do
          if occupied[k] then taken = true break end
        end
        if taken then
          i = i + 1
          tried[key] = true
          pl.skipped_occupied = pl.skipped_occupied + 1
        elseif pl.attempts >= cap then
          pl.capped = true
          return nil
        else
          i = i + 1
          tried[key] = true
          pl.attempts = pl.attempts + 1
          return pos
        end
      end
    end
  end

  function pl.report()
    -- covered : tuiles du parcours (le gisement) minées par une foreuse (spec.mined, complété par pl.cover)
    local covered = 0
    for _, r in ipairs(res) do
      if mined[P.key(math.floor(r.x), math.floor(r.y))] then covered = covered + 1 end
    end
    return { attempts = pl.attempts, occupied = pl.skipped_occupied, dead = pl.skipped_dead,
      exhausted = pl.exhausted, capped = pl.capped, tiles = #res, covered = covered }
  end
  return pl
end

--- Couverture en ‰ (entier) : `covered` tuiles minées sur `tiles` ; 0 sans tuile.
function P.permille(covered, tiles)
  if not tiles or tiles <= 0 then return 0 end
  return math.floor(1000 * (covered or 0) / tiles)
end

--- Fin d'un agrandissement. v = { placed, drills_after, drills_max, exhausted, capped, lacking, covered, tiles }.
--- Rend { full, fail, why } : full = l'avant-poste ne peut plus grandir : balayage COMPLET du gisement sans emplacement restant,
--- ou gisement couvert à P.KAPPA ‰ (lot PLAFOND-FOREUSES) ; `drills_max` (facultatif, l'infini depuis ce lot : T.max_drills) n'est
--- plus qu'un garde-fou ; fail = rien posé faute d'essais (le prochain appel reprend plus loin).
function P.verdict(v)
  if v.drills_max and v.drills_after >= v.drills_max then return { full = true, fail = false, why = "plafond" } end
  if v.exhausted then return { full = true, fail = false, why = "gisement" } end
  if (v.tiles or 0) > 0 and P.permille(v.covered, v.tiles) >= P.KAPPA then return { full = true, fail = false, why = "couverture" } end
  if v.placed > 0 then return { full = false, fail = false, why = "pose" } end
  if v.lacking then return { full = false, fail = false, why = "objets" } end
  if v.capped then return { full = false, fail = true, why = "essais" } end
  return { full = false, fail = false, why = "rien" }
end

--- Libellé d'un projet d'avant-poste (lot EXTENSION-FER, point C). c = { tasks = { { kind, lost }... } des tâches ouvertes du
--- projet, cause = cause du blocage ("site:iron"...), extendable = un avant-poste du type peut encore grandir }.
--- "extend" : agrandir l'extraction sur le gisement de la base ; "build" : nouvel avant-poste ailleurs ; "rebuild" : refaire un
--- avant-poste perdu (site rendu à la réserve) ; nil : rien d'assez précis.
function P.mode(c)
  for _, t in ipairs(c.tasks or {}) do
    if t.kind == "extend" then return "extend" end
  end
  for _, t in ipairs(c.tasks or {}) do
    if t.kind == "build" then return t.lost and "rebuild" or "build" end
  end
  if type(c.cause) == "string" and c.cause:sub(1, 5) == "site:" then return "build" end
  if c.extendable then return "extend" end
  return nil
end

return P
