--[[
  Lot VIDEO-L5 « CONFIRMATION OBSERVÉE » (feuille de route validée par le DC le 7/11 : docs/VIDEO_AUTOMATISATION.md §6 L5,
  docs/TODO_VIDEO.md §G rang 4, lignes V54, V72, G17, G18, G29, G36). Règle PURE, testée hors jeu (tests/confirmation_test.lua).
  BRANCHÉE : Cf.* dans script/ai3/capitalisation.lua (carnet cs.cf créé à :265 ; Cf.engage :410, Cf.counts :419, Cf.step :542).

  La leçon de l'auteur de la vidéo (gist l.219-225) : « we can't trust the input from the outside world … we wait for the
  numbers … to match ». Un COMPTEUR D'INTENTION (ce qu'on a engagé), une OBSERVATION SÉPARÉE (ce qui produit vraiment), la
  décision suspendue tant qu'ils ne concordent pas, la RÉ-ÉMISSION IDENTIQUE si le chantier traîne (G29 : « refaire le même
  plan »), et une ISSUE D'ÉCHEC explicite pour ne jamais rester engagé pour toujours (V72 : « no way to detect or fix » ; nous
  pouvons détecter).

  Défaut visé (docs/IA_WORKFLOW.md §5, D1 et D2, partie du DC du 7/11) : des fours et des foreuses posés mais arrêtés (sortie
  pleine, sans courant) comptaient comme CAPACITÉ.

  Unité suivie : un `id` (numéro d'unité d'une machine, ou identifiant d'un module du plan directeur), une seule fois. Son
  `item` est la clé sous laquelle sa capacité s'additionne et sous laquelle la décision est suspendue (le produit en général).

  États d'un id :
    engage   : intention, aucune production observée ; jamais une capacité ; suspend les décisions sur son objet ;
    confirme : première production observée (hausse du compteur) ; capacité ;
    arrete   : confirmé, puis aucune hausse depuis Cf.QUIET ; capacité seulement si sa cause est dans Cf.KEEP ;
    echec    : engagé sans progrès depuis Cf.STALL, ou depuis l'engagement plus de Cf.MAX_AGE ; ni capacité ni suspension ;
               l'observation continue : une hausse plus tard le confirme (production tardive, réelle).

  Règles :
    1. PRODUCTION = le compteur MONTE : lecture strictement au-dessus de la lecture précédente, ou, pour la première lecture, au
       dessus de `base` (compteur à l'engagement, s'il est connu). Une baisse n'en est jamais une (coffre de sortie vidé par la
       collecte) ; une première lecture sans base fixe seulement la référence (un reste dans un coffre n'est pas une preuve).
       Compteur monotone (produits finis d'une machine) ou non (objets dans un coffre de sortie) : la même règle vaut.
    2. PROGRÈS d'un engagé = `progress` (entités bâties d'un chantier, par exemple) qui monte ; il repousse Cf.STALL, jamais
       Cf.MAX_AGE (borne ABSOLUE : un engagé ne bloque jamais au-delà de Cf.MAX_AGE après son engagement).
    3. RÉ-ÉMISSION identique : un engagé sans progrès depuis Cf.RETRY est rendu dans `retry` (copie de sa spécification), une
       fois par fenêtre de Cf.RETRY ; elle ne crée aucune intention et ne touche à aucune horloge.
    4. ÉCHEC avec CAUSE : la dernière cause lue (`cause` de l'observation : « courant », « entree », « sortie », « place »,
       « danger », « chantier »… mots du runtime), sinon Cf.CAUSE_UNREAD (jamais lu) ou Cf.CAUSE_NONE (lu, rien produit).
       Une observation `lost` (entité ou module disparu) retire l'id avec la cause Cf.CAUSE_LOST.
    5. ARRÊT d'un confirmé : aucune hausse depuis Cf.QUIET (nil : jamais) ; une hausse le rend confirmé. Une sortie PLEINE garde
       sa capacité (Cf.KEEP) : la capacité existe, c'est la collecte qui manque (D2) ; la retirer ferait poser d'autres machines
       que personne ne viderait non plus.
    6. JAMAIS DEUX FOIS : un id n'a qu'une entrée ; un second engagement du même id est sans effet (horloges gardées, même s'il
       est en échec : seul Cf.forget efface un id) ; chaque id est compté dans une seule catégorie.
    7. FERMÉ PAR DÉFAUT (lot L13) : une intention sans id valide ou sans objet est refusée ; un tick absent ne fait rien avancer.
  Déterminisme : ids parcourus triés (nombres avant chaînes), objets triés, aucun hasard, aucune horloge mesurée ; le carnet ne
  garde que des nombres, des chaînes, des booléens et des tables (aucune fonction : il peut aller dans global).
  Aucun nom du jeu ici (test anti-échelle, tests/iag_test.lua §8).
]]

local Cf = {}

Cf.STALL = 10 * 3600   -- ticks sans progrès ni production : un engagé passe en échec (comme Em.STALL)
Cf.MAX_AGE = 60 * 3600 -- ticks depuis l'engagement : borne absolue, que le progrès ne repousse pas
Cf.RETRY = 5 * 3600    -- ticks sans progrès : ré-émission identique, une fois par fenêtre
Cf.QUIET = 15 * 3600   -- ticks sans hausse : un confirmé est « arrêté » (nil : jamais)
Cf.KEEP = { sortie = true } -- causes d'arrêt qui gardent la capacité

Cf.CAUSE_NONE = "rien produit"
Cf.CAUSE_UNREAD = "jamais lu"
Cf.CAUSE_LOST = "perdu"

local STATES = { "engage", "confirme", "arrete", "echec" }

---------------------------------------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------------------------------------
local function finite(v)
  return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function valid_id(id)
  return finite(id) or (type(id) == "string" and id ~= "")
end

--- Ordre total des ids : nombres avant chaînes, puis valeur.
local function id_before(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then return ta == "number" end
  return a < b
end
Cf.id_before = id_before

local function sorted_ids(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks, id_before)
  return ks
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

--- Copie profonde sans fonction (spécification gardée pour la ré-émission identique ; table sans cycle).
local function copy(v)
  if type(v) ~= "table" then
    if type(v) == "function" then return nil end
    return v
  end
  local out = {}
  for _, k in ipairs(sorted_keys(v)) do
    local x = copy(v[k])
    if x ~= nil then out[k] = x end
  end
  return out
end

local function minutes(t) return string.format("%.1f", (t or 0) / 3600) end

---------------------------------------------------------------------------------------------------
-- Carnet
---------------------------------------------------------------------------------------------------
--- Carnet : ids = { [id] = entrée }, list = ids triés (tenue à l'engagement et à l'oubli, qui sont rares : le pas de chaque
--- minute ne trie rien).
function Cf.new() return { ids = {}, list = {} } end

--- Liste triée des ids du carnet ; rebâtie si elle manque (carnet écrit avant elle). Seuls Cf.engage, Cf.forget et
--- Cf.step la tiennent : ne jamais écrire book.ids à la main.
local function list_of(book)
  local l = book.list
  if type(l) ~= "table" then
    l = sorted_ids(book.ids)
    book.list = l
  end
  return l
end

local function list_insert(book, id)
  local l = list_of(book)
  local lo, hi = 1, #l
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    if id_before(l[mid], id) then lo = mid + 1 else hi = mid - 1 end
  end
  table.insert(l, lo, id)
end

local function list_remove(book, id)
  local l = list_of(book)
  for i = 1, #l do
    if l[i] == id then table.remove(l, i) return end
  end
end

--- Engage une intention. it = { id, item, recipe (facultatif), rate (poids de capacité, défaut 1), base (compteur à
--- l'engagement, facultatif), progress (progrès à l'engagement, facultatif), spec (table rendue telle quelle à la
--- ré-émission) }. Rend vrai si une intention NOUVELLE est créée ; faux et la raison sinon (refus, ou id déjà suivi).
function Cf.engage(book, it, tick)
  if type(book) ~= "table" or type(book.ids) ~= "table" then return false, "carnet absent" end
  if not finite(tick) then return false, "tick absent" end
  if type(it) ~= "table" or not valid_id(it.id) then return false, "intention sans id valide" end
  if type(it.item) ~= "string" or it.item == "" then return false, "intention sans objet" end
  local old = book.ids[it.id]
  if old then
    if old.item ~= it.item then return false, "id deja suivi pour " .. old.item .. " (Cf.forget d'abord)" end
    return false, "id deja suivi (" .. old.state .. ")"
  end
  local rate = it.rate
  if not finite(rate) or rate < 0 then rate = 1 end
  book.ids[it.id] = {
    id = it.id, item = it.item, recipe = it.recipe, rate = rate, spec = copy(it.spec),
    t0 = tick, t_prog = tick, t_retry = nil, tries = 0,
    base = finite(it.base) and it.base or nil, last = nil,
    prog = finite(it.progress) and it.progress or nil,
    state = "engage", t_conf = nil, t_rise = nil, cause = nil, late = nil,
  }
  list_insert(book, it.id)
  return true
end

--- Oublie un id (ordre annulé, machine démontée). Rend vrai s'il était suivi.
function Cf.forget(book, id)
  if type(book) ~= "table" or type(book.ids) ~= "table" or book.ids[id] == nil then return false end
  book.ids[id] = nil
  list_remove(book, id)
  return true
end

--- État d'un id ("engage", "confirme", "arrete", "echec") ou nil s'il n'est pas suivi.
function Cf.state(book, id)
  local u = book and book.ids and book.ids[id]
  return u and u.state or nil
end

--- Un id compte-t-il comme capacité ? (confirmé, ou arrêté pour une cause de Cf.KEEP)
local function is_capacity(u)
  return u.state == "confirme" or (u.state == "arrete" and Cf.KEEP[u.cause or ""] == true)
end
function Cf.counts(book, id)
  local u = book and book.ids and book.ids[id]
  return u ~= nil and is_capacity(u)
end

---------------------------------------------------------------------------------------------------
-- Observation
---------------------------------------------------------------------------------------------------
local function event(u, tick, extra)
  local e = { id = u.id, item = u.item, rate = u.rate, age = tick - u.t0 }
  for _, k in ipairs(sorted_keys(extra)) do e[k] = extra[k] end
  return e
end

--- Lit une observation pour un id. Rend vrai si le compteur a monté (règle 1).
local function read(u, o, tick)
  local given = type(o.cause) == "string" and o.cause ~= ""
  if given then u.cause = o.cause end
  if finite(o.progress) then
    if u.prog ~= nil and o.progress > u.prog then u.t_prog = tick end
    if u.prog == nil or o.progress > u.prog then u.prog = o.progress end
  end
  if not finite(o.count) then return false end
  local ref = u.last
  if ref == nil then ref = u.base end
  u.last = o.count
  local rose = ref ~= nil and o.count > ref
  if rose and not given then u.cause = nil end -- une production efface la cause d'un arrêt passé
  return rose
end

--- Range un id dans UNE catégorie de son objet (règle 6).
local function tally(res, seen, oldest, u)
  local it = u.item
  if not seen[it] then seen[it] = true res.items[#res.items + 1] = it end
  res.n[u.state] = res.n[u.state] + 1
  if is_capacity(u) then res.cap[it] = (res.cap[it] or 0) + u.rate
  elseif u.state == "engage" then
    res.pending[it] = (res.pending[it] or 0) + u.rate
    local h = oldest[it] or { n = 0, t0 = u.t0 }
    h.n = h.n + 1
    if u.t0 < h.t0 then h.t0 = u.t0 end
    oldest[it] = h
  elseif u.state == "arrete" then res.stopped[it] = (res.stopped[it] or 0) + u.rate
  else res.failed[it] = (res.failed[it] or 0) + u.rate end
end

--- Un pas d'observation. obs ={ [id] = { count, progress, cause, lost } } (lectures du runtime ; une lecture absente ne
--- change rien, l'horloge court) ; opts = { complete = vrai : obs couvre tous les ids vivants, un id absent est perdu }.
--- Rend res = {
---   cap, pending, stopped, failed = { [objet] = somme des poids }, items (objets triés), n = { [état] = nombre },
---   hold = { [objet] = raison } (objets dont une décision attend : au moins un engagé),
---   confirmed_now, failed_now, stopped_now, lost_now, retry (listes triées par id, événements de ce pas) }.
--- Rend nil et la raison si le carnet ou le tick manque (rien n'avance).
function Cf.step(book, obs, tick, opts)
  if type(book) ~= "table" or type(book.ids) ~= "table" then return nil, "carnet absent" end
  if not finite(tick) then return nil, "tick absent" end
  obs = obs or {}
  local complete = opts and opts.complete == true
  local res = { cap = {}, pending = {}, stopped = {}, failed = {}, items = {}, n = {}, hold = {},
    confirmed_now = {}, failed_now = {}, stopped_now = {}, lost_now = {}, retry = {} }
  for _, s in ipairs(STATES) do res.n[s] = 0 end
  local ids = list_of(book)
  local n_lost = 0
  for _, id in ipairs(ids) do
    local u = book.ids[id]
    local o = obs[id]
    if (type(o) == "table" and o.lost) or (complete and o == nil) then
      res.lost_now[#res.lost_now + 1] = event(u, tick, { state = u.state, cause = Cf.CAUSE_LOST })
      book.ids[id] = nil
      n_lost = n_lost + 1
    else
      local rose = type(o) == "table" and read(u, o, tick) or false
      if rose then
        if u.state == "engage" or u.state == "echec" then
          if u.state == "echec" then u.late = true end
          u.state, u.t_conf = "confirme", tick
          res.confirmed_now[#res.confirmed_now + 1] = event(u, tick, { late = u.late })
        elseif u.state == "arrete" then
          u.state = "confirme"
        end
        u.t_rise = tick
      elseif u.state == "engage" then
        local idle = tick - u.t_prog
        if tick - u.t0 >= Cf.MAX_AGE or idle >= Cf.STALL then
          u.state = "echec"
          if not u.cause then u.cause = (u.last == nil) and Cf.CAUSE_UNREAD or Cf.CAUSE_NONE end
          local why = (tick - u.t0 >= Cf.MAX_AGE) and ("engage depuis " .. minutes(tick - u.t0) .. " min")
            or ("aucun progres en " .. minutes(idle) .. " min")
          res.failed_now[#res.failed_now + 1] = event(u, tick, { cause = u.cause, why = why, tries = u.tries })
        elseif idle >= Cf.RETRY and (u.t_retry == nil or tick - u.t_retry >= Cf.RETRY) then
          u.t_retry, u.tries = tick, u.tries + 1
          res.retry[#res.retry + 1] = { id = u.id, item = u.item, recipe = u.recipe, rate = u.rate, spec = copy(u.spec),
            tries = u.tries, age = tick - u.t0 }
        end
      elseif u.state == "confirme" and Cf.QUIET ~= nil and tick - (u.t_rise or u.t_conf or u.t0) >= Cf.QUIET then
        u.state = "arrete"
        res.stopped_now[#res.stopped_now + 1] = event(u, tick, { cause = u.cause or Cf.CAUSE_NONE,
          keep = Cf.KEEP[u.cause or ""] == true })
      end
    end
  end
  -- Ids perdus à ce pas : retirés de la liste (une seule passe).
  if n_lost > 0 then
    local keep = {}
    for _, id in ipairs(ids) do if book.ids[id] then keep[#keep + 1] = id end end
    book.list, ids = keep, keep
  end
  -- Bilan par objet (une seule catégorie par id : règle 6).
  local seen, oldest = {}, {}
  for _, id in ipairs(ids) do tally(res, seen, oldest, book.ids[id]) end
  table.sort(res.items)
  for _, it in ipairs(sorted_keys(oldest)) do
    local h = oldest[it]
    res.hold[it] = string.format("attente de confirmation : %d engage(s), le plus ancien depuis %s min", h.n, minutes(tick - h.t0))
  end
  return res
end

--- Raison de suspendre une décision sur `item` (règle G18 : pas de nouvelle décision tant que l'observé n'a pas rattrapé
--- l'intention), ou nil. res : rendu de Cf.step.
function Cf.holds(res, item)
  return res and res.hold and res.hold[item] or nil
end

--- Intention contre observation pour un objet : engagés + confirmés + arrêtés (intention vivante) contre confirmés et arrêtés
--- (observés). Concordent quand aucun engagé ne reste.
function Cf.match(book, item)
  local intended, observed = 0, 0
  if type(book) ~= "table" or type(book.ids) ~= "table" then return 0, 0 end
  for _, id in ipairs(list_of(book)) do
    local u = book.ids[id]
    if u.item == item and u.state ~= "echec" then
      intended = intended + 1
      if u.state ~= "engage" then observed = observed + 1 end
    end
  end
  return intended, observed
end

return Cf
