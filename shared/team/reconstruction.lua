--[[
  Lot COUVERTURE, volet RECONSTRUCTION (constat du DC, 28/10 : « un endroit détruit n'a pas été remplacé alors que ça prend
  deux secondes et qu'ils ont toutes les ressources », « le labo de recherche attaqué n'est pas réparé », « une fonderie de
  cuivre touchée et ils ont quand même amélioré les fours qui sont morts »). PUR : aucune API Factorio, testé hors jeu
  (tests/couverture_test.lua §7) ; le runtime est script/team/reconstruction.lua.

  Un REGISTRE des pièces posées par l'équipe et détruites : { name, x, y, dir, item, recipe, value } où `item` est l'objet
  qui pose la pièce (lu au prototype par le runtime) et `value` sa valeur de rôle (shared/team/couverture.lua, Cov.ROLE_VALUE).
  Règles :
    - PATIENCE : une pièce n'est refaite qu'après Rc.CALM ticks (les assaillants sont encore là juste après) ; une pièce
      DÉTRUITE DE NOUVEAU au même endroit double la patience (jusqu'à Rc.CALM_MAX) et, au-delà de Rc.MAX_LOSSES destructions
      en Rc.RESET ticks, est ABANDONNÉE (on ne nourrit pas indéfiniment un point que l'ennemi tient) ;
    - ORDRE : la valeur décroissante (labo, centrale, fonderie avant le tapis), puis la date, puis la clé ;
    - LOT : le plus précieux et ses voisins à Rc.BATCH_RADIUS tuiles, au plus Rc.BATCH_MAX pièces : un voyage ;
    - une pièce dont une tâche est prise n'est plus proposée ; rendue (tâche abandonnée), elle revient ; différée (ennemis
      près d'elle) jusqu'à une date, et abandonnée après Rc.MAX_DEFERS reports ;
    - AMÉLIORER ATTEND : tant qu'une pièce refaisable (objet connu, non abandonnée, objet au stock si `have` est donné) est
      en attente, l'équipe n'améliore rien (Rc.hold_upgrades) : refaire ce qui est perdu avant d'améliorer ce qui reste.

  FRONTIÈRE avec le plan directeur (lot POTEAUX, 28/10) : UNE SEULE logique de reconstruction, celle de ce registre
  (événement de mort, patience, danger, abandon). Le plan directeur (script/team/build.lua) ne rouvre jamais un projet et
  n'envoie aucun PNJ refaire un poteau. Il reste un CONTRÔLE DE COHÉRENCE (Recon.audit, une fois par minute) : un poteau d'un
  projet marqué bâti mais ABSENT du monde et INCONNU du registre (retiré sans événement de mort vu, perdu avant la
  création du registre dans une sauvegarde plus ancienne…) y est inscrit (Rc.unknown) ; ce que le registre connaît déjà, en attente, prise ou ABANDONNÉE, n'est jamais
  réinscrit (pas de boucle) : l'abandon dure Rc.TTL, puis la place est oubliée et peut être inscrite une fois de nouveau.
  Une pièce inscrite dont l'objet n'est pas au stock reste en attente SANS tâche (règle du registre : l'objet doit être au
  stock) ; elle part dès que l'objet y est.
  Déterminisme : clés triées, entiers, aucun `pairs` décisionnel, aucun hasard, aucun temps mesuré.
]]

local Rc = {}

Rc.CALM = 600            -- 10 s : patience avant de refaire une pièce détruite
Rc.CALM_MAX = 7200       -- 2 min : plafond de la patience doublée
Rc.MAX_LOSSES = 5        -- plus de 5 destructions au même endroit en Rc.RESET ticks : abandonnée
Rc.RESET = 30 * 3600     -- la mémoire des destructions d'une place dure 30 min
Rc.TTL = 90 * 60 * 60    -- une perte jamais refaite est oubliée après 90 min
Rc.BATCH_RADIUS = 12     -- tuiles : un voyage refait toutes les pièces à 12 tuiles de la plus précieuse
Rc.BATCH_MAX = 12
Rc.MAX_DEFERS = 20       -- reports (ennemis près de la place) avant l'abandon
Rc.PRIO_BASE = 70        -- priorité de tâche : 70 + valeur du rôle, jamais l'urgence (90, O.URGENT_PRIO)
Rc.PRIO_MAX = 86

function Rc.new() return { lost = {}, hist = {} } end

local function sorted_keys(t)
  local ks = {}
  for k in next, t do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

function Rc.key(rec) return string.format("%s@%.2f,%.2f", rec.name, rec.x, rec.y) end

function Rc.calm_for(r)
  return math.min(Rc.CALM_MAX, Rc.CALM * (2 ^ (r.losses - 1)))
end

--- Une pièce vient d'être détruite. Rend sa clé. Une même place détruite de nouveau garde sa clé et ses destructions.
function Rc.record(st, rec, tick)
  local k = Rc.key(rec)
  local h = st.hist[k]
  local r = st.lost[k]
  local losses = 1
  if r then losses = r.losses + 1
  elseif h and tick - h.tick <= Rc.RESET then losses = h.losses + 1 end
  r = {
    key = k, name = rec.name, x = rec.x, y = rec.y, dir = rec.dir or 0, item = rec.item, recipe = rec.recipe,
    value = rec.value or 0, kind = rec.kind, oid = rec.oid, tick = tick, losses = losses, defers = 0,
  }
  if r.losses > Rc.MAX_LOSSES then r.abandoned = true end
  st.lost[k] = r
  st.hist[k] = { losses = losses, tick = tick }
  return k
end

--- Pièces refaisables en attente : non prises, non abandonnées, objet connu, patience écoulée, non différées. Triées :
--- valeur décroissante, date, clé.
function Rc.due(st, tick)
  local out = {}
  for _, k in ipairs(sorted_keys(st.lost)) do
    local r = st.lost[k]
    if not r.claimed and not r.abandoned and r.item
      and (not r.retry or tick >= r.retry) then
      if tick - r.tick >= Rc.calm_for(r) then
        out[#out + 1] = r
      end
    end
  end
  table.sort(out, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    if a.tick ~= b.tick then return a.tick < b.tick end
    return a.key < b.key
  end)
  return out
end

local function d2(a, b) local dx, dy = a.x - b.x, a.y - b.y; return dx * dx + dy * dy end

--- Lot d'un voyage : la pièce `seed` d'abord, puis celles de `due` à `radius` tuiles d'elle, `max` pièces au plus.
function Rc.batch(st, due, seed, max, radius)
  local out = { seed }
  for _, r in ipairs(due) do
    if #out < max and (r == seed or d2(r, seed) <= radius * radius) then
      if r ~= seed then out[#out + 1] = r end
    end
  end
  return out
end

--- Objets d'un lot : { {objet, n} } triés par nom.
function Rc.items(batch)
  local n = {}
  for _, r in ipairs(batch) do
    if r.item then n[r.item] = (n[r.item] or 0) + 1 end
  end
  local out = {}
  for _, it in ipairs(sorted_keys(n)) do out[#out + 1] = { it, n[it] } end
  return out
end

--- Contrôle de cohérence : parmi les pièces `absent` ({ name, x, y, … } marquées posées par un projet, absentes du monde),
--- celles que le registre NE CONNAÎT PAS (ni en attente, ni prise, ni abandonnée : une place connue n'est jamais réinscrite).
--- Ordre d'entrée conservé (l'appelant trie).
function Rc.unknown(st, absent)
  local out = {}
  for _, rec in ipairs(absent) do
    if not st.lost[Rc.key(rec)] then out[#out + 1] = rec end
  end
  return out
end

function Rc.claim(st, keys, id)
  for _, k in ipairs(keys) do
    local r = st.lost[k]
    if r then r.claimed = id end
  end
end

function Rc.release(st, id)
  for _, k in ipairs(sorted_keys(st.lost)) do
    local r = st.lost[k]
    if r.claimed == id then r.claimed = nil end
  end
end

function Rc.done(st, key) st.lost[key] = nil end

--- Ennemis près de la place : à refaire plus tard (date `until_tick`) ; trop de reports, abandonnée.
function Rc.defer(st, key, until_tick, tick)
  local r = st.lost[key]
  if not r then return end
  r.retry = until_tick
  r.defers = (r.defers or 0) + 1
  if r.defers > Rc.MAX_DEFERS then r.abandoned = true end
end

--- Pièces en attente de reconstruction (abandonnées et sans objet exclues).
function Rc.pending(st)
  local n = 0
  for _, k in ipairs(sorted_keys(st.lost)) do
    local r = st.lost[k]
    if not r.abandoned and r.item then n = n + 1 end
  end
  return n
end

--- L'équipe attend-elle avant d'améliorer ? Vrai tant qu'une pièce refaisable attend ; `have(objet)` (facultatif) : seules
--- comptent les pièces dont l'objet est au stock (sans objet, rien à refaire : l'amélioration d'autre chose ne les gêne pas).
function Rc.hold_upgrades(st, have)
  for _, k in ipairs(sorted_keys(st.lost)) do
    local r = st.lost[k]
    if not r.abandoned and r.item and (not have or have(r.item) > 0) then return true end
  end
  return false
end

--- Priorité de la tâche d'un lot dont la pièce la plus précieuse vaut `value`.
function Rc.task_prio(value)
  return math.min(Rc.PRIO_MAX, Rc.PRIO_BASE + value)
end

--- Oublie les pertes jamais refaites depuis plus de Rc.TTL et les mémoires de destruction périmées.
function Rc.prune(st, tick)
  for _, k in ipairs(sorted_keys(st.lost)) do
    local r = st.lost[k]
    if tick - r.tick > Rc.TTL then st.lost[k] = nil end
  end
  for _, k in ipairs(sorted_keys(st.hist)) do
    if tick - st.hist[k].tick > Rc.TTL then st.hist[k] = nil end
  end
end

return Rc
