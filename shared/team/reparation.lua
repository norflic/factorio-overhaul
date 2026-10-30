--[[
  Lot PD-REPARATION (D79, retour du DC du 28/10 vers 14 h 45, en jouant la 0.6.5 : « pas de réparation » (labo, fonderie de
  cuivre touchés), « ça a pas été remplacé alors que ça prend deux secondes »). Avant ce lot, seule l'infrastructure électrique
  de VOTRE équipe était réparée (lot RECONSTRUIRE, script/team/reconstruction.lua, Recon.repair_think) ; le lot COMPAGNONS-ACTIFS
  ajoute les TOURELLES de toutes les équipes dans le même relevé. Ce lot étend la réparation à TOUS les autres bâtiments
  (laboratoires, fours, assembleurs, foreuses, centrale des factions, murs, logistique), pour TOUTES les équipes, sans refaire
  ce que ces deux relevés couvrent déjà.

  COÛT (question Q12 de docs/QUESTIONS_DC.md, OPTION PAR DÉFAUT appliquée) : réparation GRATUITE, aucun paquet de réparation
  consommé (Rp.COST). Q12 retenait « gratuite pour l'infrastructure électrique seulement » ; D67 de l'inventaire la dit
  étendue aux tourelles de COMPAGNONS-ACTIFS ; ce lot l'étend aux autres bâtiments (le DC peut la changer : Rp.COST).

  Règles PURES (aucun appel au moteur, testées hors jeu : tests/reparation_test.lua). Types du moteur seulement
  (LuaEntityPrototype.type), aucun nom d'objet ni de bâtiment du jeu.
    - RELEVÉ borné par tick : l'événement on_entity_damaged (filtré par type au moteur) note l'entité dans st.ents (clé :
      unit_number) en O(1) ; au plus Rp.PENDING_MAX entrées par équipe et par classe (au-delà, compté dans st.over, l'entité revient au
      prochain coup reçu). Une entité au-dessus du seuil de sa classe est retirée (elle revient au prochain coup).
    - PRIORITÉ selon l'importance : classe (production > énergie > défense passive > logistique, Rp.PRIO), puis la plus
      abîmée, puis la clé. Lot des voisines à Rp.BATCH_RADIUS tuiles, au plus Rp.BATCH_MAX.
    - PAS PENDANT UNE ATTAQUE LOCALE : une entité touchée depuis moins de Rp.CALM ticks, ou à moins de Rp.ATTACK_RADIUS tuiles
      d'une entité touchée depuis moins de Rp.CALM ticks, n'est pas réparée (le runtime ajoute les unités ennemies proches).
  Déterminisme : clés triées, entiers et rapports de santé lus au moteur, aucun hasard, aucun temps mesuré.
]]

local R = require("shared.ai3.reglages")

local Rp = {}

Rp.ENABLED = true
Rp.COST = "gratuit"       -- Q12, option par défaut : aucun paquet de réparation consommé
-- Entités endommagées gardées par équipe et par classe (des murs criblés ne prennent pas la place des laboratoires).
Rp.PENDING_MAX = { production = 200, energie = 100, defense = 150, logistique = 150 }
Rp.CALM = 600             -- 10 s sans coup reçu avant de réparer (attaque locale finie)
Rp.ATTACK_RADIUS = 24     -- tuiles : une voisine touchée depuis moins de Rp.CALM ticks marque une attaque locale
Rp.BATCH_RADIUS = 12      -- tuiles : un voyage répare les voisines de la pièce choisie
Rp.BATCH_MAX = 6
Rp.SEEDS_MAX = 12         -- pièces examinées au plus par pensée pour trouver une pièce calme (borne du coût)
Rp.LOGS = 40              -- lignes [FO-REPARE] d'ouverture et de fin par équipe (le bilan périodique n'est pas compté)
Rp.REPORT_EVERY = 18000   -- 5 min : bilan [FO-REPARE] par équipe

-- Classe de chaque type du moteur (R.ENTITY_ROLE donne la liste des bâtiments que le cerveau connaît ; « main » exclu).
Rp.CLASS_OF_ROLE = {
  labo = "production", fabrique = "production", foreuse = "production",
  chauffe = "energie", generateur = "energie", pompe = "energie",
  militaire = "defense",
  logistique = "logistique",
}
-- Le poteau est classé « logistique » par R.ENTITY_ROLE ; pour la réparation il est de l'énergie (il coupe une ligne).
Rp.TYPE_CLASS_OVERRIDE = { ["electric-pole"] = "energie" }
-- Seuil (% de la santé max) sous lequel une pièce est réparée, par classe. L'infrastructure électrique garde le seuil du lot
-- RECONSTRUIRE (60 %) ; murs et logistique 50 % (le mur est fait pour encaisser : pas de va-et-vient pour un éclat).
Rp.BELOW = { production = 80, energie = 60, defense = 50, logistique = 50 }
-- Priorité de la tâche au tableau, par classe : sous la reconstruction (70 et plus, refaire avant de réparer) et sous la
-- réparation des tourelles et de l'électrique de votre équipe (66, Rc.REPAIR_PRIO).
Rp.PRIO = { production = 65, energie = 64, defense = 62, logistique = 58 }
Rp.DOMAIN = { production = "production", energie = "infrastructures", defense = "defense", logistique = "logistique" }

--- Types déjà réparés par un autre relevé, donc exclus ici (sans les dupliquer) :
---   - les tourelles (R.TURRET_TYPES) : lot COMPAGNONS-ACTIFS, toutes les équipes (Rp.TURRETS_ELSEWHERE) ;
---   - l'infrastructure électrique de VOTRE équipe (R.INFRA_TYPES) : lot RECONSTRUIRE (les factions, elles, passent ici).
Rp.TURRETS_ELSEWHERE = true

--- Classe d'un type du moteur pour une équipe, ou nil (exclu : personnage, type inconnu, déjà couvert ailleurs).
function Rp.class_of(etype, is_player)
  if Rp.TURRETS_ELSEWHERE then
    for _, t in ipairs(R.TURRET_TYPES) do if t == etype then return nil end end
  end
  if is_player and R.INFRA_TYPES[etype] then return nil end
  local over = Rp.TYPE_CLASS_OVERRIDE[etype]
  if over then return over end
  local role = R.ENTITY_ROLE[etype]
  return role and Rp.CLASS_OF_ROLE[role] or nil
end

--- Types filtrés au moteur (tous ceux qu'une équipe peut faire réparer ici), triés. Le filtre de l'événement ne connaît pas
--- l'équipe : l'infrastructure électrique y est, l'exclusion de votre équipe se fait à la note.
function Rp.filter_types()
  local out = {}
  for etype in next, R.ENTITY_ROLE do
    if Rp.class_of(etype, false) then out[#out + 1] = etype end
  end
  table.sort(out)
  return out
end

local function sorted_units(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- État d'une équipe (créé à la première note, donc en événement).
function Rp.new_state()
  return { ents = {}, count = 0, per = {}, over = 0, logs = 0,
    stats = { noted = 0, opened = 0, repaired = 0, deferred = 0, dropped = 0, done = 0 } }
end

--- Note d'un coup reçu : `unit` (unit_number), `name`, position, `ratio` (santé / max APRÈS le coup), `cls`, `tick`. Rend
--- « add », « upd », « del » (au-dessus du seuil), « over » (plus de place) ou nil.
function Rp.note(st, unit, name, x, y, ratio, cls, tick)
  local e = st.ents[unit]
  if ratio * 100 >= (Rp.BELOW[cls] or 0) then
    if e then
      Rp.drop(st, unit)
      return "del"
    end
    return nil
  end
  if e then
    e.r, e.t = ratio, tick
    return "upd"
  end
  st.per = st.per or {}
  if (st.per[cls] or 0) >= (Rp.PENDING_MAX[cls] or 0) then
    st.over = st.over + 1
    return "over"
  end
  st.ents[unit] = { n = name, x = x, y = y, r = ratio, c = cls, t = tick }
  st.count = st.count + 1
  st.per[cls] = (st.per[cls] or 0) + 1
  st.stats.noted = st.stats.noted + 1
  return "add"
end

function Rp.drop(st, unit)
  local e = st.ents[unit]
  if e then
    st.ents[unit] = nil
    st.count = st.count - 1
    st.per = st.per or {}
    st.per[e.c] = (st.per[e.c] or 1) - 1
  end
end

--- Une entrée est-elle sous attaque locale ? Touchée depuis moins de Rp.CALM ticks, ou une entrée touchée depuis moins de
--- Rp.CALM ticks à moins de Rp.ATTACK_RADIUS tuiles. `hot` : entrées récentes (liste).
local function attacked(e, hot, tick)
  if tick - e.t < Rp.CALM then return true end
  local r2 = Rp.ATTACK_RADIUS * Rp.ATTACK_RADIUS
  for _, h in ipairs(hot) do
    local dx, dy = h.x - e.x, h.y - e.y
    if dx * dx + dy * dy <= r2 then return true end
  end
  return false
end

--- Lot à réparer : liste { { unit, name, x, y, ratio, cls } } (la pièce choisie en tête) ou {} ; second résultat : nombre de
--- pièces sous attaque locale écartées.
function Rp.pick(st, tick)
  local units = sorted_units(st.ents)
  local hot, list = {}, {}
  for _, u in ipairs(units) do
    local e = st.ents[u]
    if tick - e.t < Rp.CALM then hot[#hot + 1] = e end
    list[#list + 1] = { unit = u, e = e }
  end
  table.sort(list, function(a, b)
    local pa, pb = Rp.PRIO[a.e.c] or 0, Rp.PRIO[b.e.c] or 0
    if pa ~= pb then return pa > pb end
    if a.e.r ~= b.e.r then return a.e.r < b.e.r end
    return a.unit < b.unit
  end)
  local seed, skipped = nil, 0
  for i = 1, math.min(#list, Rp.SEEDS_MAX) do
    if not attacked(list[i].e, hot, tick) then seed = list[i] break end
    skipped = skipped + 1
  end
  if not seed then return {}, skipped end
  local out = {}
  local r2 = Rp.BATCH_RADIUS * Rp.BATCH_RADIUS
  for _, it in ipairs(list) do
    if #out >= Rp.BATCH_MAX then break end
    local e = it.e
    local dx, dy = e.x - seed.e.x, e.y - seed.e.y
    if it == seed or (dx * dx + dy * dy <= r2 and tick - e.t >= Rp.CALM) then
      out[#out + 1] = { unit = it.unit, name = e.n, x = e.x, y = e.y, ratio = e.r, cls = e.c }
    end
  end
  return out, skipped
end

--- Tâche du tableau pour un lot. Kind « repare » (pas « repair ») : la réparation des tourelles et de l'électrique
--- (Recon.repair_think) ne s'ouvre que sans tâche « repair » en cours ; une réparation de labo en cours ne doit pas la retarder.
--- Le programme et l'acte sont les mêmes (script/team/worker.lua : Recon.repair_program, ACTS.repare = ACTS.repair).
function Rp.task(batch)
  local s = batch[1]
  local targets = {}
  for _, c in ipairs(batch) do targets[#targets + 1] = { name = c.name, x = c.x, y = c.y, unit = c.unit } end
  return { key = string.format("repare:%s@%.1f,%.1f", s.name, s.x, s.y), kind = "repare", prio = Rp.PRIO[s.cls] or 58,
    domain = Rp.DOMAIN[s.cls] or "production", work = 10 + 2 * #batch, targets = targets, pos = { x = s.x, y = s.y }, repare = s.cls }
end

--- Compte des entrées en attente par classe (journal).
function Rp.by_class(st)
  local n = { production = 0, energie = 0, defense = 0, logistique = 0 }
  for _, u in ipairs(sorted_units(st.ents)) do
    local c = st.ents[u].c
    n[c] = (n[c] or 0) + 1
  end
  return n
end

function Rp.report_line(key, tick, st)
  local c = Rp.by_class(st)
  local s = st.stats
  return string.format("[FO-REPARE] %s : bilan a %.1f min : %d piece(s) endommagee(s) en attente (production %d, energie %d, defense %d, " ..
    "logistique %d), %d hors place ; %d relevee(s), %d reparation(s) ouverte(s), %d terminee(s), %d piece(s) reparee(s), %d report(s) pour attaque locale, " ..
    "%d retiree(s) (detruite(s) ou reparee(s) ailleurs) ; cout : %s", tostring(key), tick / 3600, st.count, c.production, c.energie, c.defense,
    c.logistique, st.over, s.noted, s.opened, s.done, s.repaired, s.deferred, s.dropped, Rp.COST)
end

return Rp
