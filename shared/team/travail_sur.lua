--[[
  Lot INDUSTRIE, sous-lot I2 « INACTIFS » (retour du DC du 31/10 : les compagnons « en théorie ils ne devraient jamais attendre,
  avec "rien à faire" ou "inactif" ») : règles PURES (aucun appel au moteur, aucun nom d'objet du jeu : l'appelant nomme les
  ressources) de la FILE SÛRE des PNJ qui n'ont plus de tâche.

  Constat (ia1-poles sur 0.6.28, équipe occupée 51,7 % pour 85 % visés ; F241) : le travail de fond (shared/team/fond.lua) ne
  propose que ce que le stock et la carte permettent aujourd'hui, et il est COUPÉ pour une équipe qui n'a pas dépassé son effectif
  de départ (une faction : `n > floor`) ; un PNJ dont le pôle n'a rien à lui donner attend alors la pensée suivante, puis la
  suivante. Le fond entier ne peut pas être rouvert pour eux (F241 : sorties, morts, équipe perdue). Cette file ne rouvre que du
  travail qui ne coûte AUCUN objet du coffre et ne bâtit rien :
    1. rapporter ce qu'un avant-poste proche a produit, dès le premier objet (le fond attend T.transport_min) ;
    2. miner à la main, près du coffre, la ressource que les coffres n'ont pas déjà en suffisance (la décision « main ou
       stock » reste celle de MAIN-INVENTAIRE : l'appelant ne passe que les ressources qu'elle permet).

  Un PNJ est AFFAMÉ quand il est resté sans tâche à S.STARVE_THINKS pensées de suite : une tâche libre mais non prenable (matière,
  pause, porte) ne cache pas un PNJ qui attend. Un PNJ FRAIS (sans tâche depuis cette pensée) n'est servi par la file que pour ce
  que le fond ouvert dans la MÊME pensée ne couvre pas : il attendrait sinon 2 pensées (10 s) entre deux tâches courtes (essai 1
  du banc ind-inactifs : 9,9 % de PNJ sans tâche avec le seul seuil des 2 pensées). Le nombre de tâches de la file ouvertes est
  borné par ces PNJ, moins celles déjà ouvertes.

  S.cause classe l'attente d'une pensée : « menace » (QG menacé : tout le monde au coffre, voulu), « bloque » (des tâches libres
  que personne ne peut prendre), « rien » (aucune tâche au tableau). Le journal [FO-INACTIF] les compte en PNJ-pensées.

  Déterminisme : aucune itération par `pairs` dans une décision (identifiants et ressources triés), aucune horloge.
]]

local S = {}

S.STARVE_THINKS = 2         -- pensées de suite sans tâche avant d'être affamé (une pensée = 300 ticks, 5 s)
S.PRIO = 10                 -- sous tout le fond (garde 18 comprise) : la file ne passe jamais devant du vrai travail
S.SERVICE_MIN = 1           -- objets à rapporter qui justifient une tournée de la file (le fond : T.transport_min)
S.REPORT_EVERY = 18000      -- journal [FO-INACTIF] : un bilan par équipe toutes les 5 min
S.MINE_TRIES = 64           -- indices de clé essayés au plus pour une ressource (clés déjà au tableau sautées)
S.KEY_PREFIX = "sur:"       -- clés des tâches de la file ("service:<id>" est la clé commune de la tournée du fond)
S.RECALL_EVERY = 1800       -- un PNJ de la file rappelé pour le travail ordinaire du cerveau, au plus toutes les 30 s (une urgence : aussitôt)
S.HOLD_TICKS = 600          -- une mission d'éclaireur attend un PNJ libre : la file n'ouvre rien et en rappelle un pendant 10 s (renouvelé tant qu'elle attend)

--- Suites d'attente : `prev` = { [id] = pensées de suite sans tâche } de la pensée précédente, `idle_ids` = PNJ sans tâche à
--- celle-ci. Rend la nouvelle table (un PNJ occupé ou disparu est oublié), le nombre de PNJ affamés (S.STARVE_THINKS pensées de
--- suite) et le nombre de PNJ FRAIS (sans tâche depuis cette pensée seulement : le fond ouvert dans la même pensée les servira).
function S.track(prev, idle_ids)
  local out, starved, fresh = {}, 0, 0
  for _, id in ipairs(idle_ids or {}) do
    local n = ((prev or {})[id] or 0) + 1
    out[id] = n
    if n >= S.STARVE_THINKS then starved = starved + 1 elseif n == 1 then fresh = fresh + 1 end
  end
  return out, starved, fresh
end

--- Cause de l'attente d'un PNJ à cette pensée : `threat` (QG menacé), `free` (tâches libres au tableau).
function S.cause(threat, free)
  if threat then return "menace" end
  if (free or 0) > 0 then return "bloque" end
  return "rien"
end

--- Mise à l'écart d'une ressource dont le minage de la file a échoué (essai ia1-poles : 54 minages de fer ouverts en 5 min, 54 échecs,
--- « 0 entité trouvée » ou stock devenu suffisant) : `bad` = { [ressource] = { k = échecs de suite, till = tick } }, table simple.
--- Chaque échec de suite DOUBLE la durée (S.BACKOFF_BASE, au plus S.BACKOFF_MAX doublements) ; une réussite l'efface. Un refus pour
--- danger, abri ou fuite est passager (la porte rejuge dans 10 s) : il ne compte pas.
S.BACKOFF_BASE = 7200   -- 2 min au premier échec
S.BACKOFF_MAX = 4       -- 2, 4, 8, 16 min
S.TRANSIENT = { abri = true, danger = true, fuite = true, preempte = true }

function S.blocked(bad, res, tick)
  local b = bad and bad[res]
  return b ~= nil and tick < b.till
end

function S.fail(bad, res, tick, why)
  if S.TRANSIENT[why or ""] then return end
  local b = bad[res] or { k = 0, till = 0 }
  b.k = math.min(S.BACKOFF_MAX, b.k + 1)
  b.till = tick + S.BACKOFF_BASE * math.floor(2 ^ (b.k - 1))
  bad[res] = b
end

function S.success(bad, res)
  bad[res] = nil
end

--- PNJ de la file à rappeler (PLAN §5, ③ : la file passe après tout) : toutes les urgences que les PNJ sans tâche (`free`) ne couvrent pas ; pour le reste du
--- travail du cerveau (`wanted`), un seul toutes les S.RECALL_EVERY ticks (`since` : ticks depuis le dernier rappel) : des tâches libres qu'aucun PNJ ne peut
--- prendre, porte de danger comprise, dominent certaines parties (ia1-poles) : sans cette borne, les PNJ feraient l'aller-retour à chaque pensée.
function S.recall_n(urgent, wanted, free, since)
  local n = math.max(0, (urgent or 0) - (free or 0))
  if n == 0 and (since or 0) >= S.RECALL_EVERY and (wanted or 0) > (free or 0) then n = 1 end
  return n
end

--- La matière `item` (et sa plaque fondue `fondu`, pour un minerai) est-elle retirée du fond par le cerveau ? `st` = f.team.ia3 : même règle
--- que Ia3.after_poles (saturée seulement si une autre matière manque, couverte par un module toujours), qui lit `fond` sur toute tâche.
function S.withdrawn(st, item, fondu)
  if not (st and item) then return false end
  if st.other_short ~= false and st.saturated and st.saturated[item] then return true end
  local cov = st.covered
  return cov ~= nil and (cov[item] == true or (fondu ~= nil and cov[fondu] == true))
end

--- Tâches de la file à ouvrir.
--- ctx = {
---   starved = PNJ affamés, fresh = PNJ sans tâche depuis cette pensée, open = tâches de la file ouvertes et non prises,
---   threat, prudent, floor_ok = faux pour une équipe décimée (sous son effectif de départ : F241, aucun fond),
---   keys = { [clé] = vrai } (tableau et pauses), also = tâches ouvertes dans la même pensée, batch = fournée de minage, radius = rayon de minage,
---   outposts = { { id, output, d2, danger, undefended, has_task }, ... } (ordre de la vue), near_d2 = distance² au plus (ou nil),
---   resources = { { res, gap (pour mille), ok (minage permis) }, ... } }
--- Rend { tasks = {...}, want = nombre voulu, service = n, mine = n, left = voulu non servi }.
function S.plan(ctx)
  -- Affamés + frais que le fond de cette pensée (`ctx.also`) ne sert pas, moins les tâches de la file déjà ouvertes.
  local fresh = math.max(0, (ctx.fresh or 0) - #(ctx.also or {}))
  local want = math.max(0, (ctx.starved or 0) + fresh - (ctx.open or 0))
  local r = { tasks = {}, want = want, service = 0, mine = 0, left = want }
  if want == 0 or ctx.threat or ctx.prudent or ctx.floor_ok == false then return r end
  local keys = ctx.keys or {}
  local taken = {} -- clés prises par cette décision ou ouvertes dans la même pensée (`ctx.also` : liste de tâches)
  for _, t in ipairs(ctx.also or {}) do taken[t.key] = true end
  -- 1. Tournées : l'avant-poste qui a le plus à rapporter d'abord (à égalité, le plus petit identifiant).
  local posts = {}
  for _, o in ipairs(ctx.outposts or {}) do
    if (o.output or 0) >= S.SERVICE_MIN and not o.danger and not o.undefended and not o.has_task
      and (ctx.near_d2 == nil or (o.d2 or 0) <= ctx.near_d2) and not keys["service:" .. tostring(o.id)] and not taken["service:" .. tostring(o.id)] then
      posts[#posts + 1] = o
    end
  end
  table.sort(posts, function(a, b)
    if (a.output or 0) ~= (b.output or 0) then return (a.output or 0) > (b.output or 0) end
    return tostring(a.id) < tostring(b.id)
  end)
  for _, o in ipairs(posts) do
    if r.left == 0 then break end
    r.tasks[#r.tasks + 1] = { key = "service:" .. tostring(o.id), kind = "service", prio = S.PRIO, outpost = o.id, fond = true,
      safe = true, domain = "gisements" }
    r.service, r.left = r.service + 1, r.left - 1
  end
  -- 2. Minage près du coffre : la ressource la plus en manque d'abord, puis à tour de rôle.
  local list = {}
  for i, m in ipairs(ctx.resources or {}) do
    if m.ok then list[#list + 1] = { res = m.res, gap = m.gap or 0, i = i } end
  end
  table.sort(list, function(a, b)
    if a.gap ~= b.gap then return a.gap > b.gap end
    return a.i < b.i
  end)
  local used = {}
  local k = 0
  while r.left > 0 and #list > 0 and k < S.MINE_TRIES * #list do
    local m = list[k % #list + 1]
    local j = used[m.res] or 0
    -- Indice suivant de la ressource dont la clé n'est pas déjà au tableau.
    repeat
      j = j + 1
    until (not keys[S.KEY_PREFIX .. "mine:" .. m.res .. ":" .. j] and not taken[S.KEY_PREFIX .. "mine:" .. m.res .. ":" .. j])
      or j > S.MINE_TRIES
    used[m.res] = j
    k = k + 1
    local key = S.KEY_PREFIX .. "mine:" .. m.res .. ":" .. j
    if j <= S.MINE_TRIES then
      taken[key] = true
      r.tasks[#r.tasks + 1] = { key = key, kind = "mine", prio = S.PRIO, resource = m.res, count = ctx.batch or 50,
        radius = ctx.radius, fond = true, safe = true, domain = "gisements" }
      r.mine, r.left = r.mine + 1, r.left - 1
    end
  end
  return r
end

--- Cumuls du journal : `acc` (table simple) reçoit une pensée.
--- a = { n = PNJ, idle = sans tâche, starved = affamés, cause = S.cause, opened_service, opened_mine }
function S.note(acc, a)
  acc.thinks = (acc.thinks or 0) + 1
  acc.n = (acc.n or 0) + (a.n or 0)
  acc.idle = (acc.idle or 0) + (a.idle or 0)
  acc.starved = (acc.starved or 0) + (a.starved or 0)
  if (a.idle or 0) > 0 and a.cause then acc[a.cause] = (acc[a.cause] or 0) + a.idle end
  acc.opened_service = (acc.opened_service or 0) + (a.opened_service or 0)
  acc.opened_mine = (acc.opened_mine or 0) + (a.opened_mine or 0)
  -- Genres des tâches libres au tableau quand des PNJ attendent (cause « bloque » : ce que personne n'a pris).
  if (a.idle or 0) > 0 and a.kinds then
    acc.kinds = acc.kinds or {}
    for _, k in ipairs(S.kind_list(a.kinds)) do acc.kinds[k] = (acc.kinds[k] or 0) + a.kinds[k] end
  end
end

--- Genres d'une table { [genre] = nombre }, triés (aucun ordre de `pairs` ne décide).
function S.kind_list(kinds)
  local out = {}
  for k in pairs(kinds or {}) do out[#out + 1] = k end
  table.sort(out)
  return out
end

--- Fin d'une tâche de la file (réussie ou non).
function S.done(acc, ok)
  if ok then acc.done_ok = (acc.done_ok or 0) + 1 else acc.done_fail = (acc.done_fail or 0) + 1 end
end

local function pct(a, b)
  if (b or 0) <= 0 then return 0 end
  return 100 * a / b
end

--- Ligne du bilan [FO-INACTIF] (texte seul). Les parts sont en PNJ-pensées ; « hors menace » exclut les attentes voulues du QG
--- menacé (critère du lot : inactifs ≤ 5 % hors menace, cause « rien » ≤ 2 %).
function S.report_line(key, tick, acc, on)
  local n = acc.n or 0
  local menace = acc.menace or 0
  local hors = math.max(0, (acc.idle or 0) - menace)
  return string.format("[FO-INACTIF] %s : bilan a %.1f min (5 min, %s) : %d pensee(s), inactifs %.1f %% des PNJ-pensees (hors menace %.1f %%), affames %.1f %% ; causes (PNJ-pensees) : menace %d, bloque %d, rien %d (rien %.1f %%) ; file sure : %d tournee(s) et %d minage(s) ouverts, %d finis, %d en echec",
    tostring(key), tick / 3600, on and "file sure allumee" or "file sure eteinte", acc.thinks or 0, pct(acc.idle or 0, n),
    pct(hors, math.max(1, n - menace)), pct(acc.starved or 0, n), menace, acc.bloque or 0, acc.rien or 0, pct(acc.rien or 0, n),
    acc.opened_service or 0, acc.opened_mine or 0, acc.done_ok or 0, acc.done_fail or 0)
    .. S.kinds_text(acc.kinds)
end

--- Fin de ligne : genres des tâches libres vues pendant les attentes (« ; libres pendant l'attente : craft 12, garrison 3 »).
function S.kinds_text(kinds)
  local parts = {}
  for _, k in ipairs(S.kind_list(kinds)) do parts[#parts + 1] = k .. " " .. kinds[k] end
  if #parts == 0 then return "" end
  return " ; libres pendant l'attente (tache-pensees) : " .. table.concat(parts, ", ")
end

return S
