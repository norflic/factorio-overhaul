--[[
  Lot SURVIE-PENURIE : le MODE SURVIE d'une équipe de PNJ (factions ET votre équipe). PUR (aucune API Factorio, aucun nom d'objet :
  l'appelant, script/team/survie.lua, passe les données lues dans shared/team/config.lua). Testé hors jeu (tests/survie_test.lua).

  Retours du Directeur Créatif du 29/10, en jouant la 0.6.16 (RETOUR_DC_2) :
    « ils sont incapables d'avoir une option survivaliste où on se dépêche le plus possible, on prend des ressources à la main et
      on met des fours, on remet des foreuses à max » ;
    Ordre Écarlate encerclé de nids : « il manque 83 plaques de fer […] ils avaient des fours en réserve, huit fours […] trop
      dangereux, ils font plus rien, ils attendent et ils farm même plus les ressources » ;
    « si on manque cruellement de ressources, l'objectif est ces ressources, pas la défense ».
  Cause (audits fo-logs/2026-10-29_VAGUE4/AUDIT4/tourelles-danger.md et AUDIT3/avant-poste.md, lecture du code) : la PORTE des tâches
  (script/ai3/comportement.lua, shared/ai3/danger.lua D.gate) refuse tout trajet qui croise un champ de danger moyen à une équipe de
  prudence >= 1000 sans escorte (« Trop dangereux ») et, avec 2 morts de l'heure sur la route, sans fin pendant 1 h ; les tâches
  refusées dorment 30 s ; les PNJ restent au coffre et plus rien ne produit. Rien ne distinguait « je refuse parce que je n'ai rien à
  perdre à attendre » de « je refuse alors que je meurs de faim ».

  Règle (Sv.decide), évaluée à chaque pensée de l'équipe :
    ENTRÉE   une matière clé manque DURABLEMENT (Sv.SHORT_TICKS de suite) ET l'équipe est PARALYSÉE : la porte a refusé au moins
             Sv.PARA_WAITS tâches en Sv.WINDOW avec au moins Sv.IDLE_PCT % de PNJ sans tâche, ou l'équipe est menacée avec au
             moins Sv.IDLE_PCT_THREAT % de PNJ sans tâche.
    SORTIE   la matière ne manque plus depuis Sv.EXIT_TICKS de suite (HYSTÉRÉSIS) et le séjour a duré au moins Sv.MIN_ON. Un refus de
             la porte, une pensée sans manque, la fin de la paralysie ne font PAS sortir : seule la fin de la pénurie.
  Ce que le mode change (chaque effet a son lecteur nommé dans RAPPORT.md ; aucun ne touche au fer d'une équipe qui n'est pas en pénurie) :
    1. la PORTE, pour les tâches qui produisent des ressources (Sv.GATE_KINDS) : une route qui croise un champ de danger moyen part
       (sans exiger l'escorte), moins de Sv.DEATHS_WAIT morts de l'heure sur la route ne bloquent plus, l'escalade vient dès
       Sv.ESCALADE_W refus. INCHANGÉ : un BUT à portée d'une menace, un chemin sans issue, Sv.DEATHS_WAIT morts ou plus -> attente ;
    2. la PRIORITÉ : la production passe avant la défense et l'armée (shared/team/priorite.lua, `survie`) ; la capitalisation ne prend
       aucune part pour la défense ni l'armée et la menace ne ferme plus ses leviers hors du QG (gisements dangereux toujours exclus) ;
    3. des TÂCHES propres : minage à la main de la matière qui manque par tous les PNJ sans tâche, fours de réserve posés au QG,
       foreuses ajoutées (à combustion s'il n'y a pas de courant : Outposts.extend) sur l'avant-poste le plus proche et sûr.
  Aucun `pairs` de décision, aucun hasard, aucun temps mesuré. Les durées sont en ticks. Seuils PROVISOIRES : non mesurés en partie
  (voir RAPPORT.md, « non prouvé »).
]]

local Sv = {}

-- Entrée / sortie (ticks).
Sv.SHORT_TICKS = 5 * 3600     -- manque continu avant d'entrer : 5 min (le manque d'objectif d'une pensée ordinaire dure moins)
Sv.WINDOW = 5 * 3600          -- fenêtre des refus de la porte
Sv.PARA_WAITS = 6             -- refus de la porte dans la fenêtre : paralysie
Sv.IDLE_PCT = 34              -- % de PNJ sans tâche qui, avec les refus, disent « paralysée »
Sv.IDLE_PCT_THREAT = 50       -- % de PNJ sans tâche qui, sous la menace seule, disent « paralysée »
Sv.EXIT_TICKS = 5 * 3600      -- pénurie finie depuis 5 min : sortie
Sv.MIN_ON = 3 * 3600          -- séjour minimal : pas de clignotement
Sv.BEAT = 10 * 3600           -- une ligne de bilan toutes les 10 min tant que le mode dure
Sv.WAITS_KEPT = 64            -- refus de la porte gardés (le plus ancien part)
-- Porte.
Sv.DEATHS_WAIT = 3            -- morts de l'heure sur la route à partir desquelles on attend quand même (2 en temps normal)
Sv.ESCALADE_W = 2             -- refus de suite avant l'escalade (4 pour une prudence de 1 000 en temps normal)
Sv.GATE_KINDS = { mine = true, extend = true, build = true, service = true }
-- Tâches.
Sv.MINE_DANGER_RADIUS = 30    -- tuiles : un minage de survie évite un nid ou un ver à moins de 30 tuiles (40 en temps normal) ;
                              -- 30 = portée d'un ver moyen. CHOIX NON MESURÉ.
Sv.MINERS_MAX = 8
Sv.MINE_MIN, Sv.MINE_MAX = 25, 50   -- minerais visés par tâche (comme le manque de plaques, shared/ai3/manque.lua)
Sv.SMELTERS_MAX = 8           -- fours posés au QG au plus (« huit fours en réserve » du retour du DC)
Sv.EXTEND_MAX = 2             -- agrandissements demandés à la fois
Sv.PRIO = 86                  -- sous l'urgence (90, réservée à la défense et aux relais), au-dessus des objectifs (80)
Sv.REPEAT = 1200              -- une tâche de survie redemandée dans ce délai (le tableau est refait à chaque pensée) n'est pas recomptée

local function num(x)
  if type(x) ~= "number" or x ~= x then return 0 end
  return x
end

--- État neuf (nombres et tables seulement : il vit dans f.team.survie, donc dans la sauvegarde).
function Sv.new()
  return { on = false, entries = 0, waits = {}, relaxed = 0, relax_why = {}, mines = 0, smelters = 0, extends = 0, said = {}, keys = {} }
end

---------------------------------------------------------------------------------------------------
-- Refus de la porte
---------------------------------------------------------------------------------------------------
--- Un refus de la porte est noté (ticks croissants, les plus anciens hors fenêtre ou au-delà de Sv.WAITS_KEPT partent).
function Sv.note_wait(st, tick)
  local w = st.waits
  w[#w + 1] = tick
  while #w > Sv.WAITS_KEPT or (#w > 0 and tick - w[1] >= Sv.WINDOW) do table.remove(w, 1) end
end

--- Refus de la fenêtre.
function Sv.waits(st, tick)
  local n = 0
  for _, t in ipairs(st.waits or {}) do
    if tick - t < Sv.WINDOW then n = n + 1 end
  end
  return n
end

---------------------------------------------------------------------------------------------------
-- Pénurie et paralysie
---------------------------------------------------------------------------------------------------
--- Matières clés qui manquent. missing = { { objet, n }, ... } (plan.missing) ; keys = { [objet] = true } (produits des avant-postes).
--- Rend { { item, n }, ... } trié (n décroissant, puis nom).
function Sv.shortages(missing, keys)
  local best = {}
  for _, m in ipairs(missing or {}) do
    local item, n = m[1], num(m[2])
    if type(item) == "string" and keys[item] and n > 0 then best[item] = math.max(best[item] or 0, n) end
  end
  local out = {}
  for item, n in pairs(best) do out[#out + 1] = { item, n } end
  table.sort(out, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
  return out
end

--- L'équipe est-elle paralysée ? a = { workers, idle, threatened }. Rend vrai et la raison ("porte" | "menace"), ou faux.
function Sv.paralysed(st, a, tick)
  local workers, idle = num(a.workers), num(a.idle)
  if workers <= 0 then return false end
  if Sv.waits(st, tick) >= Sv.PARA_WAITS and idle * 100 >= workers * Sv.IDLE_PCT then return true, "porte" end
  if a.threatened and idle * 100 >= workers * Sv.IDLE_PCT_THREAT then return true, "menace" end
  return false
end

local function short_text(short)
  local parts = {}
  for _, s in ipairs(short) do parts[#parts + 1] = string.format("%s %d", s[1], s[2]) end
  return table.concat(parts, ", ")
end

--- Décision de la pensée. a = { tick, short (Sv.shortages), workers, idle, threatened }. Met `st` à jour. Rend
--- { on, event ("entree" | "sortie" | "bilan" | nil), cause, short, para, minutes }.
function Sv.decide(st, a)
  local tick = a.tick
  local short = a.short or {}
  if #short > 0 then
    st.short_since = st.short_since or tick
    st.calm_since = nil
  else
    st.short_since = nil
    st.calm_since = st.calm_since or tick
  end
  local para, why = Sv.paralysed(st, a, tick)
  local out = { on = st.on, short = short, para = para, para_why = why }
  if not st.on then
    if #short > 0 and tick - st.short_since >= Sv.SHORT_TICKS and para then
      st.on, st.since, st.beat = true, tick, tick
      st.entries = (st.entries or 0) + 1
      st.cause = string.format("manque durable de %s depuis %.1f min ; paralysie par %s (%d refus de la porte en %d min, %d PNJ sans tache sur %d%s)",
        short_text(short), (tick - st.short_since) / 3600, why, Sv.waits(st, tick), math.floor(Sv.WINDOW / 3600), num(a.idle), num(a.workers),
        a.threatened and ", equipe menacee" or "")
      out.on, out.event, out.cause = true, "entree", st.cause
    end
  else
    if tick - st.since >= Sv.MIN_ON and st.calm_since and tick - st.calm_since >= Sv.EXIT_TICKS then
      out.cause = string.format("plus aucun manque de matiere cle depuis %.1f min (sejour de %.1f min)",
        (tick - (st.calm_since or tick)) / 3600, (tick - st.since) / 3600)
      st.on, st.since, st.beat = false, nil, nil
      out.on, out.event = false, "sortie"
    elseif tick - (st.beat or tick) >= Sv.BEAT then
      st.beat = tick
      out.event = "bilan"
      out.cause = string.format("en cours depuis %.1f min : manque %s", (tick - st.since) / 3600, #short > 0 and short_text(short) or "aucun a cet instant")
    end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Tâches
---------------------------------------------------------------------------------------------------
--- Minages à la main à ajouter. a = { short, ore_of = { [objet] = minerai }, stock (libre), idle, workers, have = { [minerai] = tâches
--- de minage déjà au tableau } }. Rend { { ore, k (numéro), count, item }, ... } : au plus Sv.MINERS_MAX minages en tout, partagés
--- entre les deux matières les plus en manque ; rien pour une matière dont le minerai attend déjà au coffre (c'est la fonte).
function Sv.mines(a)
  local out = {}
  local wanted = {}
  for _, s in ipairs(a.short or {}) do
    local ore = (a.ore_of or {})[s[1]]
    if ore and (a.stock or {})[ore] ~= nil and num(a.stock[ore]) >= s[2] then ore = nil end -- le minerai est au coffre
    if ore and #wanted < 2 then wanted[#wanted + 1] = { item = s[1], ore = ore, n = s[2] } end
  end
  if #wanted == 0 then return out end
  local total = math.min(Sv.MINERS_MAX, math.max(1, num(a.idle)), math.max(1, num(a.workers)))
  for i, w in ipairs(wanted) do
    local k = (i == 1) and math.ceil(total / #wanted) or math.floor(total / #wanted)
    if k > 0 then
      local have = num((a.have or {})[w.ore])
      local count = math.max(Sv.MINE_MIN, math.min(Sv.MINE_MAX, math.ceil(w.n / k)))
      for j = 1, k do
        if j > have then out[#out + 1] = { ore = w.ore, k = j, count = count, item = w.item } end
      end
    end
  end
  return out
end

--- Fours de réserve à poser au QG. a = { short, smelts = { [objet] = vrai } (la matière se fond), smelters (posés), pending,
--- stock_smelter (au coffre), stock_fuel, fuel_per }. Rend le nombre (0 si aucune matière en manque ne se fond).
function Sv.smelters(a)
  local needs = false
  for _, s in ipairs(a.short or {}) do if (a.smelts or {})[s[1]] then needs = true end end
  if not needs then return 0 end
  local room = Sv.SMELTERS_MAX - num(a.smelters) - num(a.pending)
  local fuel_n = math.floor(num(a.stock_fuel) / math.max(1, num(a.fuel_per)))
  return math.max(0, math.min(room, math.floor(num(a.stock_smelter)), fuel_n))
end

--- Avant-postes à agrandir. a = { short, kind_of = { [objet] = type d'avant-poste }, outposts = { { id, kind, drills, full, d2, max }, ... },
--- lethal = { [id] = vrai } (un PNJ y est mort en y allant), affordable = { [type] = vrai } (foreuses et fours au coffre).
--- Rend { { id, kind }, ... } : les plus PROCHES du QG d'abord, au plus Sv.EXTEND_MAX, sûrs, non pleins, sous leur plafond.
function Sv.extends(a)
  local cands = {}
  for rank, s in ipairs(a.short or {}) do
    local kind = (a.kind_of or {})[s[1]]
    if kind and (a.affordable or {})[kind] then
      for _, o in ipairs(a.outposts or {}) do
        if o.kind == kind and not o.full and num(o.drills) < num(o.max) and not (a.lethal or {})[o.id] then
          cands[#cands + 1] = { id = o.id, kind = kind, rank = rank, d2 = num(o.d2) }
        end
      end
    end
  end
  table.sort(cands, function(x, y)
    if x.rank ~= y.rank then return x.rank < y.rank end
    if x.d2 ~= y.d2 then return x.d2 < y.d2 end
    return tostring(x.id) < tostring(y.id)
  end)
  local out, seen = {}, {}
  for _, c in ipairs(cands) do
    if #out >= Sv.EXTEND_MAX then break end
    if not seen[c.id] then
      seen[c.id] = true
      out[#out + 1] = { id = c.id, kind = c.kind }
    end
  end
  return out
end

--- Une tâche de survie demandée à ce tick est-elle NOUVELLE (à compter au bilan) ? `keys` : { [clé] = dernier tick demandé }, mis à jour ;
--- les clés oubliées depuis plus de 2 × Sv.REPEAT partent (liste triée : aucun ordre de pairs).
function Sv.fresh(keys, key, tick)
  local last = keys[key]
  keys[key] = tick
  local ks = {}
  for k in pairs(keys) do ks[#ks + 1] = k end
  table.sort(ks)
  for _, k in ipairs(ks) do
    if tick - keys[k] > 2 * Sv.REPEAT then keys[k] = nil end
  end
  return last == nil or tick - last > Sv.REPEAT
end

---------------------------------------------------------------------------------------------------
-- Porte et capitalisation
---------------------------------------------------------------------------------------------------
--- Morts de l'heure à partir desquelles la porte attend, pour cette tâche ; nil : règle ordinaire (mode éteint ou tâche non productive).
function Sv.gate_deaths(on, kind)
  if on and Sv.GATE_KINDS[kind] then return Sv.DEATHS_WAIT end
  return nil
end

--- Refus avant l'escalade : le plus petit de l'ordinaire et de Sv.ESCALADE_W quand le mode s'applique à la tâche.
function Sv.escalade_w(w, relaxed)
  if relaxed then return math.min(w, Sv.ESCALADE_W) end
  return w
end

--- Réglages de la capitalisation : { threat, production_first }. En survie, la menace ne ferme plus les leviers hors du QG (les
--- gisements dangereux restent exclus par `danger`) et aucune part n'est prise pour la défense ni l'armée.
function Sv.capi(on, threatened, production_first)
  if on then return false, true end
  return threatened and true or false, production_first and true or false
end

return Sv
