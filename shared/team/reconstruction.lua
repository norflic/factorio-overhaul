--[[
  Lot RECONSTRUIRE (issu du volet reconstruction du lot COUVERTURE ; constat du DC, 28/10 : « un endroit détruit n'a pas été remplacé alors que ça prend
  deux secondes et qu'ils ont toutes les ressources », « le labo de recherche attaqué n'est pas réparé », « une fonderie de
  cuivre touchée et ils ont quand même amélioré les fours qui sont morts »). PUR : aucune API Factorio, testé hors jeu
  (tests/reconstruction_test.lua) ; le runtime est script/team/reconstruction.lua.

  Un REGISTRE des pièces posées par l'équipe et détruites : { name, x, y, dir, item, recipe, value } où `item` est l'objet
  qui pose la pièce (lu au prototype par le runtime) et `value` sa valeur de rôle (Rc.ROLE_VALUE).
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
Rc.HOLD_MAX = 20 * 3600  -- « améliorer attend » au plus 20 min après la perte : un site tenu par l'ennemi ne gèle pas les améliorations
Rc.MAX_DEFERS = 20       -- reports (ennemis près de la place) avant l'abandon
Rc.MAX_BLOCKS = 4        -- poses refusées par le moteur (place prise par autre chose) avant l'abandon
Rc.PRIO_BASE = 70        -- priorité de tâche : 70 + valeur du rôle, jamais l'urgence (90, O.URGENT_PRIO)
Rc.PRIO_MAX = 86

-- Valeur de rôle d'une pièce (R.ENTITY_ROLE) : le laboratoire et la centrale avant la fonderie, le tapis en dernier.
Rc.ROLE_VALUE = { labo = 8, generateur = 8, chauffe = 6, fabrique = 5, pompe = 4, foreuse = 3, logistique = 1 }
function Rc.role_value(role) return Rc.ROLE_VALUE[role] or 0 end

-- INFRASTRUCTURE ÉLECTRIQUE (poteau, chaudière, machine à vapeur, pompe) : refaite d'abord et plus vite, parce qu'une seule
-- pièce coupe toute une ligne de consommateurs. Valeur d'une pièce de production d'énergie : Rc.INFRA_VALUE (au-dessus du labo) ;
-- valeur d'un poteau : Rc.POLE_BASE + les consommateurs COUPÉS près de lui (lus au moteur, état « sans courant »), au plus
-- Rc.POLE_CAP. Patience courte : Rc.CALM_INFRA (le poteau est posé à une portée de fil de l'ennemi, pas dessus).
Rc.CALM_INFRA = 180      -- 3 s
Rc.INFRA_VALUE = 14
Rc.POLE_BASE = 2
Rc.POLE_CAP = 12
--- La pièce est-elle un poteau dont la valeur se relit au moteur ? (infrastructure, valeur dans la plage des poteaux)
function Rc.is_pole_value(r) return r.infra and r.value < Rc.INFRA_VALUE end
function Rc.pole_value(cut) return Rc.POLE_BASE + math.max(0, math.min(Rc.POLE_CAP - Rc.POLE_BASE, cut or 0)) end

function Rc.new() return { lost = {}, hist = {} } end

local function sorted_keys(t)
  local ks = {}
  for k in next, t do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

function Rc.key(rec) return string.format("%s@%.2f,%.2f", rec.name, rec.x, rec.y) end

function Rc.calm_for(r)
  return math.min(Rc.CALM_MAX, (r.infra and Rc.CALM_INFRA or Rc.CALM) * (2 ^ (r.losses - 1)))
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
    value = rec.value or 0, kind = rec.kind, oid = rec.oid, infra = rec.infra or nil, tick = tick, losses = losses, defers = 0,
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

--- Objets à FABRIQUER pour refaire l'infrastructure électrique : les pièces d'infrastructure dues (patience écoulée, non prises, non
--- abandonnées) dont l'objet manque au stock. Rend { { objet, quantité } } trié par objet, au plus Rc.SPARE_CAP par objet (deux
--- poteaux détruits ne font pas fabriquer cent poteaux). `have(item)` : stock libre de l'équipe.
Rc.SPARE_CAP = 6
function Rc.demand(st, tick, have)
  local need = {}
  for _, r in ipairs(Rc.due(st, tick)) do
    if r.infra then need[r.item] = (need[r.item] or 0) + 1 end
  end
  local out = {}
  for _, item in ipairs(sorted_keys(need)) do
    local n = math.min(Rc.SPARE_CAP, need[item]) - have(item)
    if n > 0 then out[#out + 1] = { item, n } end
  end
  return out
end

--- RÉPARATION des pièces ENDOMMAGÉES (LuaEntity.health, lecture/écriture : doc runtime 1.1.91, bornée à [0, max]). `cands` :
--- { { key, x, y, ratio } } (ratio = santé / santé max). Rend, pour la plus abîmée sous Rc.REPAIR_BELOW (en %), le lot de ses voisines à
--- Rc.BATCH_RADIUS tuiles (elles aussi sous le seuil), au plus Rc.REPAIR_MAX pièces : ordre ratio croissant puis clé.
Rc.REPAIR_BELOW = 60
Rc.REPAIR_MAX = 6
Rc.REPAIR_PRIO = 66      -- sous la reconstruction (70 et plus) : refaire avant de réparer
function Rc.repair_batch(cands, below)
  local low = {}
  for _, c in ipairs(cands) do
    if c.ratio * 100 < (below or Rc.REPAIR_BELOW) then low[#low + 1] = c end
  end
  table.sort(low, function(a, b)
    if a.ratio ~= b.ratio then return a.ratio < b.ratio end
    return a.key < b.key
  end)
  local out = {}
  local seed = low[1]
  if not seed then return out end
  for _, c in ipairs(low) do
    if #out < Rc.REPAIR_MAX and (c == seed or ((c.x - seed.x) ^ 2 + (c.y - seed.y) ^ 2) <= Rc.BATCH_RADIUS * Rc.BATCH_RADIUS) then
      out[#out + 1] = c
    end
  end
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

--- Le moteur refuse la pose (place prise) : trop de refus, la pièce est abandonnée (elle ne gèle plus « améliorer attend »).
function Rc.block(st, key)
  local r = st.lost[key]
  if not r then return end
  r.blocks = (r.blocks or 0) + 1
  if r.blocks > Rc.MAX_BLOCKS then r.abandoned = true end
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
--- comptent les pièces dont l'objet est au stock (sans objet, rien à refaire : l'amélioration d'autre chose ne les gêne pas) ;
--- `tick` (facultatif) : une perte vieille de plus de Rc.HOLD_MAX ticks ne retient plus (le site est tenu par l'ennemi ou
--- inaccessible : refaire attend, mais améliorer ailleurs n'attend plus).
function Rc.hold_upgrades(st, have, tick)
  for _, k in ipairs(sorted_keys(st.lost)) do
    local r = st.lost[k]
    if not r.abandoned and r.item and (not have or have(r.item) > 0) and (not tick or tick - r.tick <= Rc.HOLD_MAX) then return true end
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
