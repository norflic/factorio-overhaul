--[[
  Lot VIDEO L7 « amorce et retrait » (docs/VIDEO_AUTOMATISATION.md §6 L7 ; TODO_VIDEO V51 à V56, C11). Étend le mall (shared/ai3/mall.lua,
  Ml) sans le modifier :
    (a) GRAINE : la liste de matériel des Am.K prochains projets du plan directeur (bâtiments à poser, moins ce que le stock a déjà)
        entre comme demande de départ du mall (Ml.want, source « amorce »), dès la 1re pensée, sans attendre Ml.MIN_EPISODES épisodes
        de fabrication à la main (V52, V53 : le capital qui fabrique le capital d'abord). La graine ne dépasse jamais la liste de
        matériel : son débit est le manque ÷ Am.HORIZON_MIN, et la barre du coffre de sortie (Id.barre, 10 min) le ramène au manque ;
        elle n'écrase jamais une demande plus forte d'une autre source.
    (b) RETRAIT : la main est retirée dès la PREMIÈRE production OBSERVÉE d'une machine (V54, V55 ; M38 via L5), et le reste (verrou),
        même quand la machine s'arrête ensuite parce que sa sortie est pleine (Ml.set_running, lui, se relit chaque minute) ; jamais
        à la pose d'un module qui ne produit pas encore ; jamais à stock nul (invariant de mall.lua l.18). Le verrou tombe si plus
        aucun module ne produit l'objet (`alive`).
    (c) COMPTEUR D'AMORCE : cumul par objet de ce que la main a fourni avant la 1re production (V56, M39) ; gardé après le retrait
        (jamais remis à zéro) : c'est ce qui dimensionne un vrai kit de départ (C11). Ligne [FO-AMORCE] par objet au retrait.

  (d) CYCLE (lot VIDEO-COUVERTURE 5, critère C5.1, TODO V39) : une recette qui consomme son propre produit (catalyseur, enrichissement)
        ne démarre jamais sans une première quantité d'amorçage. rang.lua détecte les cycles de la décision (Rg.chain : seed = ingrédients
        INTERNES au cycle, quantité par fabrication) ; Am.flatten les met en liste, Am.seed y ajoute, pour chaque objet de cycle, de quoi
        faire Am.CYCLE_RUNS fabrications (au plus Am.CYCLE_HARD), moins le stock, AVEC sa cause écrite. Sans cycle : rien.

  (e) REMISE DIRECTE (correctif C3 de fo-logs/2026-11-07_VIDEO-COUVERTURE/DIAG_CONSO.md, M2 à M4) : un module de chaîne exige des assembleurs 2,
        qui exigent des circuits, que fabrique un module de chaîne : le cycle se coupait au coffre, qui refuse tout objet non vital quand il est
        plein (M0). Am.direct partage ce qu'un PNJ PORTE entre les modules en réserve qui l'attendent (leur manque), dans l'ordre de la file,
        pour qu'il aille à p.stock du module SANS passer par le coffre. Jamais plus que le manque ; rien pour un module qui n'attend pas.

  PUR : aucune API du jeu, aucun nom d'objet (anti-échelle de tests/iag_test.lua §8). État dans st.amorce (sérialisable, aucune
  fonction). Déterminisme : listes triées, entiers, ticks de jeu, aucune horloge mesurée. Testé hors jeu : tests/amorce_test.lua.
]]

local Am = {}

Am.K = 3              -- projets du plan directeur dont la liste de matériel sert de graine
Am.HORIZON_MIN = 10   -- le manque de la graine doit être couvert en 10 minutes de jeu (même horizon que Ml.HORIZON_MIN)
Am.SRC = "amorce"     -- source de la demande notée par Ml.want
Am.CYCLE_RUNS = 2     -- fabrications d'amorçage d'un cycle (de quoi tourner deux fois)
Am.CYCLE_HARD = 400   -- objets semés au plus pour un objet de cycle (borne absolue, recettes par lots comprises)

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

local function state(st)
  st.amorce = st.amorce or { seed = {}, hand = {}, since = {}, done = {} }
  local a = st.amorce
  a.seed, a.hand, a.since, a.done = a.seed or {}, a.hand or {}, a.since or {}, a.done or {}
  return a
end

--- Liste de matériel des K premiers projets d'une file (ordre de la file) : projets = { { bom = { [objet] = n } } } ; rend
--- { [objet] = n } (somme) et la liste triée des objets.
function Am.bom(projets, k)
  k = k or Am.K
  local sum = {}
  for i = 1, math.min(k, #(projets or {})) do
    local b = projets[i].bom or {}
    for _, it in ipairs(sorted_keys(b)) do
      local n = math.floor(b[it] or 0)
      if n > 0 then sum[it] = (sum[it] or 0) + n end
    end
  end
  return sum, sorted_keys(sum)
end

local function pos(n) return type(n) == "number" and n == n and n > 0 and n < math.huge end

--- (d) Les objets de cycle d'une décision (Rg.chain) en liste triée et sérialisable : c = { seed = { [membre] = { { ingrédient interne,
--- quantité par fabrication } } }, cyc = { [membre] = id du cycle } } (nil ou sans cycle : liste vide). Un objet n'y est qu'une fois (la
--- plus grande quantité) ; une entrée sans nom ou à quantité invalide est écartée (fermé par défaut : on ne sème pas une mesure illisible).
function Am.flatten(c)
  local out = {}
  if type(c) ~= "table" or type(c.seed) ~= "table" then return out end
  local best = {}
  for _, m in ipairs(sorted_keys(c.seed)) do
    for _, e in ipairs(c.seed[m]) do
      local it, n = e[1], e[2]
      if type(it) == "string" and it ~= "" and pos(n) and (best[it] == nil or n > best[it].amount) then
        best[it] = { item = it, member = m, amount = n, id = (type(c.cyc) == "table" and c.cyc[m]) or m }
      end
    end
  end
  for _, it in ipairs(sorted_keys(best)) do out[#out + 1] = best[it] end
  return out
end

--- (a) La graine. projets : file du plan directeur (les K premiers comptent) ; have = { [objet] = stock } ; book : livre (recipe_for) ;
--- Ml : la règle du mall (injectée : aucun require croisé) ; cyc : (d) liste de Am.flatten (nil : aucun cycle). Rend la liste triée
--- { { item, need, rate, cause } } des objets semés (cause : le texte écrit, qui dit d'où vient la graine), puis la liste des objets
--- de CYCLE non semés faute de recette à la main { { item, need, cause } } (le journal les écrit).
function Am.seed(st, tick, projets, have, book, Ml, cyc)
  local a = state(st)
  local sum, items = Am.bom(projets, Am.K)
  local want, cause = {}, {}
  local bom_why = "materiel des " .. Am.K .. " prochains projets"
  for _, it in ipairs(items) do want[it], cause[it] = sum[it], bom_why end
  for _, e in ipairs(cyc or {}) do
    if type(e) == "table" and type(e.item) == "string" and e.item ~= "" and pos(e.amount) then
      local n = math.min(Am.CYCLE_HARD, math.ceil(e.amount * Am.CYCLE_RUNS))
      local why = string.format("cycle %s : %s consomme %s (%g par fabrication, %d fabrications d'amorcage)", tostring(e.id),
        tostring(e.member), e.item, e.amount, Am.CYCLE_RUNS)
      if want[e.item] == nil then want[e.item], cause[e.item] = n, why
      else
        want[e.item] = math.max(want[e.item], n)
        cause[e.item] = cause[e.item] .. " ; " .. why
      end
    end
  end
  local out, skipped = {}, {}
  a.seed = {}
  for _, it in ipairs((cyc and #cyc > 0) and sorted_keys(want) or items) do
    local need = want[it] - math.floor((have or {})[it] or 0)
    if need > 0 and book and book.recipe_for and book:recipe_for(it) ~= nil then -- la demande reste après le retrait de la main
      local rate = need / Am.HORIZON_MIN
      local cur = st.want and st.want[it]
      local fresh = cur and (tick - (cur.tick or 0) <= Ml.WANT_TTL)
      if not (fresh and cur.src ~= Am.SRC and (cur.rate or 0) >= rate) then
        Ml.want(st, tick, it, rate, Am.SRC)
      end
      a.seed[it] = need
      out[#out + 1] = { item = it, need = need, rate = rate, cause = cause[it] }
    elseif need > 0 and cause[it]:find("cycle ", 1, true) then
      -- un objet de cycle que la main ne sait pas fabriquer (aucune recette à la main) : refus ÉCRIT, jamais une graine muette
      skipped[#skipped + 1] = { item = it, need = need, cause = cause[it] }
    end
  end
  return out, skipped
end

--- (e) Remise directe. projects : file du plan directeur { { id, state, reason, rebuilding, missing = { { objet, manque } } } } ; item, n : ce que
--- le PNJ porte. Rend la liste { { id, item, n, rebuild } } des remises (somme <= n, chacune <= le manque restant du module). Attendent, dans l'ordre
--- de la file : D'ABORD les projets ROUVERTS pour reconstruction (rebuilding, Sw.rebuilding : leur chantier a repris avec ce qu'il y avait,
--- REBUILD-RAPIDE, et refresh_missing tient leur manque), PUIS les modules en état « reserve ». Lot CHARBON-CENTRALE (V0675-A, graine 1618033988) :
--- les 30 tapis du projet 3 (charbon de la centrale 1), rouvert en chantier après l'attaque de 33,6 min, n'étaient servis par personne : seule la
--- réserve attendait, et la centrale 4 en réserve prenait chaque tapis déposé au QG ; « manque au coffre {transport-beltx30} » de 38,6 à 59 min,
--- centrale 1 à sec à 43,5, 51,0, 56,3 et 59,6 min. Un module suspendu par la pile ou le QG (raison « pile », « qg » : objets rendus, manques
--- effacés) n'attend rien. Fermé par défaut : quantité nulle, négative, NaN, infinie ou absente = rien ; manque illisible écarté.
function Am.direct(projects, item, n)
  local out = {}
  if type(item) ~= "string" or item == "" or not pos(n) then return out end
  local left = math.floor(n)
  for pass = 1, 2 do -- 1 : les projets rouverts pour reconstruction ; 2 : les réserves
    for _, p in ipairs(projects or {}) do
      if left <= 0 then break end
      local rebuild = p.rebuilding == true
      local waits = (pass == 1 and rebuild) or (pass == 2 and not rebuild and (p.state == "reserve" or p.progressif == true)) -- (progressif : lot EXPANSION-LOINTAINE)
      if waits and p.reason ~= "pile" and p.reason ~= "qg" then
        local want = 0
        for _, m in ipairs(p.missing or {}) do
          if m[1] == item and pos(m[2]) then want = want + math.floor(m[2]) end
        end
        local k = math.min(left, want)
        if k > 0 then
          out[#out + 1] = { id = p.id, item = item, n = k, rebuild = rebuild or nil }
          left = left - k
        end
      end
    end
  end
  return out
end

--- Ligne du journal [FO-AMORCE] d'une remise directe (aucune décision ne la lit).
function Am.describe_direct(a, tick_min)
  return string.format("remise directe : %d %s au module %s sans passer par le coffre (il les attendait %s) a %.1f min", a.n, a.item,
    tostring(a.id), a.rebuild and "pour sa reconstruction" or "en reserve", tick_min or 0)
end

--- (b) et (c) Relevé d'une minute : flows[objet] = { made, hand } (tout ce qui est produit, dont la main) ; alive = { [objet] = vrai }
--- les objets qu'un module posé du plan directeur fabrique (nil : non relu, le verrou ne tombe pas). Cumule la main des objets
--- suivis tant que leur machine n'a rien produit ; pose le verrou à la 1re production d'une machine. Rend la liste triée des
--- retraits de cette minute { { item, hand, tick } } (journal [FO-AMORCE]).
function Am.observe(st, tick, flows, alive)
  local a = state(st)
  local track = {}
  for _, it in ipairs(st.items or {}) do track[it.item] = true end
  for _, k in ipairs(sorted_keys(st.want)) do track[k] = true end
  for _, k in ipairs(sorted_keys(a.seed)) do track[k] = true end
  for _, k in ipairs(sorted_keys(a.hand)) do track[k] = true end
  local retraits = {}
  for _, it in ipairs(sorted_keys(track)) do
    local fl = (flows or {})[it]
    local hand = fl and math.floor(fl.hand or 0) or 0
    local machine = fl and ((fl.made or 0) - (fl.hand or 0)) or 0
    if a.done[it] then
      if alive and not alive[it] then a.done[it] = nil end -- plus aucun producteur : la main revient (le compteur reste)
    elseif machine > 0 then
      a.done[it] = tick
      retraits[#retraits + 1] = { item = it, hand = a.hand[it] or 0, tick = tick }
    elseif hand > 0 then
      a.hand[it] = (a.hand[it] or 0) + hand
      a.since[it] = a.since[it] or tick
    end
  end
  return retraits
end

--- La main est-elle permise ? Refusée dès la 1re production observée (verrou), ou quand le mall tourne (Ml.hand_allowed) ; toujours
--- permise à stock nul.
function Am.hand_allowed(st, item, have, Ml)
  if (have or 0) <= 0 then return true end
  local a = st and st.amorce
  if a and a.done and a.done[item] then return false end
  return Ml.hand_allowed(st, item, have)
end

--- Ml.filter_crafts avec le verrou d'amorce : retire les fabrications à la main que le producteur assure, sous la priorité `urgent`.
function Am.filter_crafts(st, tasks, stock, urgent, Ml)
  local out = {}
  for _, t in ipairs(tasks or {}) do
    if t.kind ~= "craft" or (t.prio or 0) >= urgent or Am.hand_allowed(st, t.item, (stock or {})[t.item], Ml) then out[#out + 1] = t end
  end
  return out
end

--- Compteur d'amorce d'un objet (objets fournis à la main avant la 1re production).
function Am.supplied(st, item)
  return (st and st.amorce and st.amorce.hand and st.amorce.hand[item]) or 0
end

--- (f) KIT DE DÉPART ÉCRIT (lot TV-PILOTE, TODO D02, C11) : la liste minimale d'amorçage est EXPLICITE (shared/team/amorce_kit.lua, K.MINIMAL,
--- passée ici en paramètre : aucun nom d'objet dans cette règle) et se compare au compteur d'amorce. minimal = { { item, n, per, why } } ;
--- workers = ouvriers de départ de l'équipe ; opts.min_extra = main fournie avant la 1re production à partir de laquelle un objet HORS liste
--- est signalé (Am.KIT_EXTRA_MIN) ; opts.max_extra = nombre d'objets hors liste rapportés (Am.KIT_EXTRA_N). Rend
---   rows  = { { item, listed (total de la liste), hand (compteur d'amorce), why } } dans l'ordre de la liste ;
---   extra = { { item, hand } } objets fournis à la main HORS liste, du plus fourni au moins fourni, au plus max_extra ;
---   text  = ligne lisible : « kit minimal : A x8, B x80 | main hors liste : C 25, D 12 ».
--- FERMÉ PAR DÉFAUT : une liste absente rend nil et la raison (jamais « aucun kit » par défaut).
Am.KIT_EXTRA_MIN = 10
Am.KIT_EXTRA_N = 8
function Am.kit_report(st, minimal, workers, opts)
  if type(minimal) ~= "table" then return nil, "kit minimal absent" end
  local w = type(workers) == "number" and workers == workers and workers >= 0 and math.floor(workers) or nil
  if w == nil then return nil, "ouvriers de depart absents" end
  local min_extra = (opts and opts.min_extra) or Am.KIT_EXTRA_MIN
  local max_extra = (opts and opts.max_extra) or Am.KIT_EXTRA_N
  local rows, listed = {}, {}
  for _, el in ipairs(minimal) do
    local total = (el.per == "ouvrier") and (el.n or 0) * w or (el.n or 0)
    rows[#rows + 1] = { item = el.item, listed = total, hand = Am.supplied(st, el.item), why = el.why }
    listed[el.item] = true
  end
  local extra = {}
  local hand = (st and st.amorce and st.amorce.hand) or {}
  for _, it in ipairs(sorted_keys(hand)) do
    if not listed[it] and (hand[it] or 0) >= min_extra then extra[#extra + 1] = { item = it, hand = hand[it] } end
  end
  table.sort(extra, function(a, b)
    if a.hand ~= b.hand then return a.hand > b.hand end
    return a.item < b.item
  end)
  while #extra > max_extra do extra[#extra] = nil end
  local parts = {}
  for _, r in ipairs(rows) do parts[#parts + 1] = string.format("%s x%d", tostring(r.item), r.listed) end
  local ex = {}
  for _, e in ipairs(extra) do ex[#ex + 1] = string.format("%s %d", e.item, e.hand) end
  local text = string.format("kit minimal : %s | main avant la 1re production, hors liste : %s", table.concat(parts, ", "),
    #ex > 0 and table.concat(ex, ", ") or "aucun")
  return { rows = rows, extra = extra, text = text }
end

--- Ligne du journal [FO-AMORCE] d'un retrait (aucune décision ne la lit).
function Am.describe(r, st)
  local since = st and st.amorce and st.amorce.since and st.amorce.since[r.item]
  return string.format("%s : main retiree a la 1re production (tick %d) ; %d fourni(s) a la main avant%s", r.item, r.tick, r.hand,
    since and string.format(" (depuis le tick %d, %.1f min)", since, (r.tick - since) / 3600) or "")
end

return Am
