--[[
  Lot L2 « la porte de rang ciblée » (docs/VIDEO_AUTOMATISATION.md §6 L2, docs/TODO_VIDEO.md §H). PUR (aucune API Factorio),
  testé hors jeu (tests/porte_rang_test.lua). BRANCHÉ (lot L2) : Ca.PORTE_RANG = true (shared/ai3/capitalisation.lua:154, demande Ca.RANG) ;
  Pr.decide est appelé dans rank_gate (shared/ai3/capitalisation.lua:1907, branché à :1948).

  Règle : un ordre de production dont la chaîne DÉPEND (même indirectement, par les recettes choisies) d'un objet EN MANQUE
  d'un rang strictement INFÉRIEUR ne prend pas d'emplacement : il attend que ce manque soit servi. Un ordre sans cette
  dépendance passe (la porte n'est pas globale : la vidéo bloque tout rang supérieur, nous connaissons le graphe).
    - un manque SANS ISSUE (aucune option : ni recette, ni machine, ni gisement) ne bloque rien ;
    - les ordres des étages R0 et R1 de la pile (survivre, réparer et protéger) ne sont jamais retenus ;
    - même rang (cycle contracté compris) : pas de blocage.
  Cas mesuré visé (EFFONDREMENT, partie du DC 717152950 en 0.6.51, Ca.blocked_items) : deux modules qui attendaient du fer
  tenaient les deux emplacements du plan directeur ; la foreuse de fer était refusée « plan directeur occupe ». La porte
  retient les modules (ils dépendent du minerai de fer en manque, rang 0) : la foreuse passe.
  ANTI-RÉPÉTITION (gist de l'auteur, l.181-204) : parmi les ordres permis d'un même rang, l'objet posé au tour précédent
  (`last`) est retenu s'il y en a un autre à ce rang ; seul de son rang, il passe quand même.

  Pr.deps(R) : fermeture des dépendances par objet, depuis un rang de décision (Rg.chain : rec, list). deps[i] = { [amont] =
  vrai } le long des recettes choisies (sans l'objet lui-même).
  Pr.decide(input) -> { allowed = { ordres }, held = { { order, cause } }, rstar } avec input = {
    orders = { { key, item, rank, pile } } (dans l'ordre de priorité ; pile = étage de la pile, 0 à 3, nil : 2),
    short = { { item, rank, option } } (manques ; option = vrai : une option existe pour le servir),
    deps = { [objet] = { [amont] = vrai } }, last = objet posé au tour précédent (ou nil) }.
  Aucun nom du jeu ; listes triées, causes départagées par (rang, nom) ; aucun pairs qui décide sans tri.

  Lot VIDEO-ORDRE (7/11, lot 1 de la couverture ; DC : « dans le rang retenu, construire d'abord ce qui couvre le PLUS GROS manque
  net mesuré […] ne pas reposer le même objet tant que le manque mesuré n'a pas bougé […] pas deux grosses unités de suite ») :
    Pr.order(options, rstar, manque) -> ordonnées, anciennes : les options du rang retenu `rstar` changent de place ENTRE ELLES, au
      plus gros manque net d'abord (arrondi au millionième), puis l'ancien ordre (retour Tq, profondeur, clé). Les autres options
      gardent leur place : `ordonnees[j]` prend la place de `anciennes[j]` (Ca.before lit ces places) ;
    Pr.tick / Pr.note / Pr.recent : mémoire des objets posés (st.posed, st.clock, des nombres) ; un objet posé n'est re-ordonné
      que si le signal MESURÉ (view.mq.build) a bougé depuis la pose (Pr.SIG_MOVE) OU après Pr.RETRY_MIN minutes (= Cf.RETRY) ;
      sans signal (L3 éteint) : jamais « récent », la règle d'avant ;
    Pr.big / Pr.median / Pr.big_hold : une option dont le coût dépasse Pr.BIG_K fois la médiane des options est une grosse unité ;
      la suivante d'un ordre qui en était une cède sa place à une autre option (si une autre existe).
  Le manque net est celui de Ca.options (R − N − stock ÷ H_STOCK) : un FLUIDE se juge sur ses stocks (barils, cuves) exactement
  comme un objet, aucune branche particulière.

  Lot CONSOLIDATION-TIERS (8/11 ; DC : « est-ce qu'ils ont effectivement respecté l'ordre des tiers [...] construit des machines
  d'assemblage de tiers supérieurs avant d'avoir fait et solidifié et consolidé les tiers inférieurs » ; critères :
  fo-logs/2026-11-08_CONSOLIDATION-TIERS/CRITERES.md). La porte d'avant n'attend qu'un MANQUE déclaré (R − N − stock) : dès qu'un
  ordre est posé, N (nominal) couvre R et la porte s'ouvre, même si la chaîne ne produit encore rien (scarlet, partie 0.6.58 :
  circuits FINI à 79,3 min, circuits avancés DEMANDÉS à 79,8 min). Ici une condition de MATURITÉ, mesurée :
    - Pr.solid_step : par chaîne x (rang >= 1, non fluide, demandée), fenêtre de Pr.SOLID_WINDOW débits MESURÉS (hors main), couverture
      = (moyenne + stock ÷ H) ÷ demande ; CONSOLIDÉE quand elle atteint Pr.SOLID_PCT % depuis au moins Pr.SOLID_MIN minutes
      (hystérésis : perdue sous Pr.SOLID_DROP %) ; une chaîne arrêtée (toutes ses unités retirées par la confirmation) ne l'est pas ;
    - Pr.decide(input.solid) : un ordre de rang r attend tant qu'une dépendance x de rang < r est dans input.solid (non consolidée
      ET avec une issue : option ce tour, machines ou ordre déjà là) ; cause « rang r : chaine x de rang k non consolidee : débit
      a/b depuis t min » ; x avec option compte pour r* (priorité à la consolidation) ;
    - sans issue (ni option, ni machine, ni ordre), sans mesure (fluide, flux absent) : rien n'est retenu ;
    - LIVENESS : l'attente sur x (minutes où x a retenu un ordre) est bornée par Pr.WAIT_MAX, puis LEVÉE (une ligne de journal).
  Pur : l'état S (st.solid) ne garde que des nombres et des tables ; tests/consolidation_test.lua.
]]

local Pr = {}

Pr.KEEP_PILE = 1 -- étages de la pile jamais retenus : R0 et R1

--- Fermeture des dépendances, objets dans l'ordre du rang croissant (les ingrédients d'abord, hors cycle).
function Pr.deps(R)
  local deps = {}
  for _, i in ipairs(R.list) do
    local d = {}
    local r = R.rec[i]
    for _, ing in ipairs((r and r.ingredients) or {}) do
      local j = ing.name
      if j ~= i then
        d[j] = true
        for k in pairs(deps[j] or {}) do if k ~= i then d[k] = true end end
      end
    end
    deps[i] = d
  end
  return deps
end

function Pr.decide(input)
  -- Manques qui bloquent : ceux qui ont une option (triés plus bas par (rang, nom), avec les chaînes non consolidées).
  local def = {}
  for _, s in ipairs(input.short or {}) do
    if s.option and s.item ~= nil and s.rank ~= nil then def[#def + 1] = s end
  end
  -- Lot CONSOLIDATION-TIERS : chaînes non consolidées qui ont une issue (input.solid = { { item, rank, option, text } }, sans objet
  -- en double). Un objet à la fois manque et non consolidé garde la ligne de la consolidation (la plus riche : le débit mesuré).
  local sol, blk = {}, {}
  for _, s in ipairs(input.solid or {}) do
    if s.item ~= nil and s.rank ~= nil and sol[s.item] == nil then
      sol[s.item] = true
      blk[#blk + 1] = { item = s.item, rank = s.rank, solid = s }
    end
  end
  for _, s in ipairs(def) do
    if sol[s.item] == nil then blk[#blk + 1] = { item = s.item, rank = s.rank } end
  end
  table.sort(blk, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.item < b.item
  end)
  local rstar = nil
  for _, b in ipairs(blk) do
    if b.solid == nil or b.solid.option then rstar = b.rank break end
  end
  local deps = input.deps or {}
  local allowed, held, waiting = {}, {}, {}
  for _, o in ipairs(input.orders or {}) do
    local cause = nil
    if (o.pile or 2) > Pr.KEEP_PILE and o.rank ~= nil then
      local up = deps[o.item] or {}
      for _, s in ipairs(blk) do
        if cause == nil and s.rank < o.rank and up[s.item] then
          if s.solid then
            cause = string.format("rang %d : chaine %s de rang %d non consolidee : %s", o.rank, s.item, s.rank, tostring(s.solid.text))
          else
            cause = string.format("rang : %s (rang %d) d'abord", s.item, s.rank)
          end
        end
      end
      -- L'attente de TOUTES les chaînes non consolidées qui retiennent cet ordre court en parallèle (pas seulement celle de la cause) :
      -- l'ordre n'attend jamais plus de Pr.WAIT_MAX minutes en tout, quel que soit le nombre de rangs en panne.
      if cause then
        for _, s in ipairs(blk) do
          if s.solid and up[s.item] and s.rank < o.rank then waiting[s.item] = true end
        end
      end
    end
    if cause then held[#held + 1] = { order = o, cause = cause } else allowed[#allowed + 1] = o end
  end
  -- Anti-répétition : l'objet du tour précédent cède sa place à un autre objet du même rang.
  local last = input.last
  if last ~= nil then
    local others = {}
    for _, o in ipairs(allowed) do
      if o.item ~= last and o.rank ~= nil then others[o.rank] = true end
    end
    local kept = {}
    for _, o in ipairs(allowed) do
      if o.item == last and o.rank ~= nil and others[o.rank] and (o.pile or 2) > Pr.KEEP_PILE then
        held[#held + 1] = { order = o, cause = "anti-repetition : " .. tostring(last) .. " pose au tour precedent" }
      else
        kept[#kept + 1] = o
      end
    end
    allowed = kept
  end
  return { allowed = allowed, held = held, rstar = rstar, waiting = waiting }
end

---------------------------------------------------------------------------------------------------
-- Lot VIDEO-ORDRE
---------------------------------------------------------------------------------------------------
Pr.BIG_K = 2        -- une option est une GROSSE unité quand son coût dépasse 2 fois la médiane des options du tour (donnée)
Pr.RETRY_MIN = 5    -- minutes : un objet posé peut être re-ordonné après ce délai même si le signal n'a pas bougé (= Cf.RETRY ÷ 3600)
Pr.SIG_MOVE = 0.5   -- le signal mesuré (objets par minute) a bougé quand il s'écarte de plus que cela de celui de la pose

local function micro(x) return math.floor((x or 0) * 1e6 + 0.5) end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Ancien ordre des options (Ca.before) : retour (Tq, arrondi au millionième), profondeur (l'amont d'abord), clé.
function Pr.old_before(a, b)
  local at, bt = a.Tq or 0, b.Tq or 0
  if at ~= bt then return at < bt end
  local ad, bd = a.depth or 0, b.depth or 0
  if ad ~= bd then return ad < bd end
  return a.key < b.key
end

--- options = { { key, item, rank, Tq, depth } } (dans un ordre quelconque), rstar = rang retenu (nil : rien ne change),
--- manque = { [objet] = manque net } (absent : 0). Rend (ordonnees, anciennes), deux listes des MÊMES options : `anciennes` est
--- l'ancien ordre ; `ordonnees` le nouveau, où seules les options du rang retenu ont changé de place, entre elles.
function Pr.order(options, rstar, manque)
  local old = {}
  for _, o in ipairs(options or {}) do old[#old + 1] = o end
  table.sort(old, Pr.old_before)
  if rstar == nil then return old, old end
  local slots, at = {}, {}
  for j, o in ipairs(old) do
    if o.rank == rstar then slots[#slots + 1] = o at[#at + 1] = j end
  end
  if #slots < 2 then return old, old end
  local m = manque or {}
  table.sort(slots, function(a, b)
    local am, bm = micro(m[a.item]), micro(m[b.item])
    if am ~= bm then return am > bm end
    return Pr.old_before(a, b)
  end)
  local new = {}
  for j, o in ipairs(old) do new[j] = o end
  for k, j in ipairs(at) do new[j] = slots[k] end
  return new, old
end

--- Horloge de la mémoire des objets posés : `dt` minutes de plus ; oublie ce qui a plus de Pr.RETRY_MIN minutes.
function Pr.tick(st, dt)
  st.clock = (st.clock or 0) + (dt or 0)
  for _, k in ipairs(sorted_keys(st.posed)) do
    if st.clock - st.posed[k].at >= Pr.RETRY_MIN then st.posed[k] = nil end
  end
end

--- L'objet vient d'être posé, le signal mesuré valait `sig` (nil : rien n'est mesuré, rien n'est retenu).
function Pr.note(st, item, sig)
  if item == nil or sig == nil then return end
  st.posed = st.posed or {}
  st.posed[item] = { sig = sig, at = st.clock or 0 }
end

--- Vrai quand l'objet a été posé il y a moins de Pr.RETRY_MIN minutes et que le signal mesuré n'a pas bougé depuis.
function Pr.recent(st, item, sig)
  if sig == nil or st == nil or st.posed == nil then return false end
  local p = st.posed[item]
  if p == nil then return false end
  if (st.clock or 0) - p.at >= Pr.RETRY_MIN then return false end
  return math.abs(sig - p.sig) <= Pr.SIG_MOVE
end

--- Coût `cost` d'une grosse unité par rapport à la médiane `median` des options (médiane nulle : aucune n'est grosse).
function Pr.big(cost, median, k)
  if cost == nil or median == nil or median <= 0 then return false end
  return cost > (k or Pr.BIG_K) * median
end

--- Médiane (valeur inférieure quand le nombre est pair) d'une liste de nombres ; nil si vide.
function Pr.median(values)
  local v = {}
  for _, x in ipairs(values or {}) do v[#v + 1] = x end
  if #v == 0 then return nil end
  table.sort(v)
  return v[math.floor((#v + 1) / 2)]
end

--- Pas deux grosses unités de suite. items = { { key, cost } } ; last_big = l'ordre précédent en était une. Rend { [clé] = vrai }
--- des options à retenir (les grosses, quand la précédente l'était) et la médiane jugée. L'option médiane n'est jamais grosse
--- (coût > K × elle-même, K ≥ 1) : quand une option est retenue, une autre existe toujours pour prendre sa place.
function Pr.big_hold(last_big, items, k)
  local costs = {}
  for _, it in ipairs(items or {}) do if it.cost ~= nil then costs[#costs + 1] = it.cost end end
  local med = Pr.median(costs)
  local hold = {}
  if last_big then
    for _, it in ipairs(items or {}) do
      if Pr.big(it.cost, med, k) then hold[it.key] = true end
    end
  end
  return hold, med
end

---------------------------------------------------------------------------------------------------
-- Lot CONSOLIDATION-TIERS : une chaîne est CONSOLIDÉE quand son débit MESURÉ tient sa demande, sans interruption
---------------------------------------------------------------------------------------------------
Pr.SOLID_PCT = 80     -- % de la demande que la couverture doit atteindre (donnée écrite : « une part écrite de sa demande »)
Pr.SOLID_DROP = 60    -- % : une chaîne consolidée ne perd son statut qu'en dessous (hystérésis : une rafale creuse ne la défait pas)
Pr.SOLID_MIN = 3      -- relevés d'une minute CONSÉCUTIFS au-dessus du seuil avant de la dire consolidée
Pr.SOLID_WINDOW = 5   -- relevés d'une minute moyennés (une machine lente fabrique par à-coups)
Pr.WAIT_MAX = 20      -- minutes pendant lesquelles une chaîne non consolidée a retenu un ordre, puis LEVÉE (jamais d'attente éternelle)
Pr.SOLID_KEEP = 10    -- minutes sans demande avant d'oublier la mémoire d'une chaîne
Pr.EPS = 1e-9

--- État neuf (nombres et tables seulement : il va dans st.solid, donc dans global).
function Pr.solid_new() return { clock = 0, items = {} } end

--- Un relevé par décision (une minute de plus : dt). rows = liste de { item, rank, demand (objets/min, > 0), stock_cover (stock ÷
--- H_STOCK, objets/min), rate (débit mesuré hors main, objets/min ; nil : non mesuré), stopped (toutes les unités posées sont
--- retirées de la capacité) } dans un ordre quelconque. Rend (verdicts, lignes) : verdicts[item] = { item, rank, demand, mean,
--- pct, ok (consolidée), unmeasured (rien à juger), lifted (attente épuisée), bad_min (minutes sans consolidation), text } ;
--- lignes = comptes rendus de consolidation et de levée (texte sans préfixe).
function Pr.solid_step(S, dt, rows)
  S.items = S.items or {}
  S.clock = (S.clock or 0) + (dt or 0)
  local clock = S.clock
  local list = {}
  for _, r in ipairs(rows or {}) do
    if r.item ~= nil and r.demand ~= nil and r.demand > Pr.EPS then list[#list + 1] = r end
  end
  table.sort(list, function(a, b) return a.item < b.item end)
  local verdicts, lines = {}, {}
  for _, r in ipairs(list) do
    local x = r.item
    local e = S.items[x]
    if e == nil then
      e = { w = {}, wait = 0 }
      S.items[x] = e
    end
    e.seen = clock
    local v = { item = x, rank = r.rank, demand = r.demand }
    if r.rate == nil then
      -- Rien de mesuré (fluide, flux absent) : la chaîne ne retient rien, sa mémoire repart de zéro.
      e.w, e.run, e.solid, e.bad, e.wait, e.blk, e.said = {}, 0, false, nil, 0, false, nil
      v.unmeasured, v.ok = true, false
    else
      local w = e.w
      w[#w + 1] = r.rate
      while #w > Pr.SOLID_WINDOW do table.remove(w, 1) end
      local sum = 0
      for _, q in ipairs(w) do sum = sum + q end
      local mean = sum / #w
      local stock = r.stock_cover or 0
      local pct = (mean + stock) * 100 / r.demand
      -- Arrêtée : ni débit ni consolidation, sauf si le stock seul tient déjà la demande.
      local stopped = r.stopped == true and stock * 100 / r.demand < Pr.SOLID_PCT
      local thr = e.solid and Pr.SOLID_DROP or Pr.SOLID_PCT
      local good = pct >= thr - Pr.EPS and not stopped
      if good then e.run = (e.run or 0) + 1 else e.run, e.solid = 0, false end
      if e.run >= Pr.SOLID_MIN then e.solid = true end
      v.mean, v.pct, v.stock, v.stopped = mean, pct, stock, stopped
      v.ok = e.solid == true
      if v.ok then
        if e.said ~= nil then
          lines[#lines + 1] = string.format("chaine %s (rang %s) consolidee : debit %.1f/%.1f, %s", x, tostring(r.rank), mean, r.demand,
            e.said == "lifted" and "apres la levee de l'attente" or "attente finie")
        end
        e.bad, e.wait, e.said = nil, 0, nil
      else
        e.bad = e.bad or clock
        if e.blk then e.wait = e.wait + (dt or 0) end
        v.bad_min = math.floor(clock - e.bad + 0.5)
        v.lifted = e.wait >= Pr.WAIT_MAX - Pr.EPS
        v.text = string.format("debit %.1f/%.1f %s%s%s", mean, r.demand,
          good and string.format("tenu %d/%d min", e.run, Pr.SOLID_MIN) or string.format("sous %d%% depuis %d min", Pr.SOLID_PCT, v.bad_min),
          stock > 0 and string.format(" (+ stock %.1f)", stock) or "", stopped and ", arretee" or "")
        if v.lifted and e.said ~= "lifted" then
          e.said = "lifted"
          lines[#lines + 1] = string.format("attente LEVEE sur la chaine %s (rang %s) apres %d min d'ordres retenus : %s", x, tostring(r.rank),
            math.floor(e.wait + 0.5), v.text)
        end
      end
      e.blk = false
    end
    verdicts[x] = v
  end
  -- Oubli des chaînes qui n'ont plus de demande depuis Pr.SOLID_KEEP minutes.
  for _, k in ipairs(sorted_keys(S.items)) do
    if clock - (S.items[k].seen or 0) > Pr.SOLID_KEEP then S.items[k] = nil end
  end
  return verdicts, lines
end

--- La chaîne x a retenu un ordre dans cette décision : son attente compte (à la minute suivante). Rend la ligne de journal de la
--- PREMIÈRE attente (nil ensuite : une ligne par attente), `text` = verdict.text.
function Pr.solid_mark(S, x, text)
  local e = S.items and S.items[x]
  if e == nil then return nil end
  e.blk = true
  if e.said == nil then
    e.said = "wait"
    return string.format("ordres de rang superieur en attente sur la chaine %s : %s", x, tostring(text))
  end
  return nil
end

--- Les éléments de `list` (déjà dans l'ordre voulu) pour lesquels front(e) est vrai passent devant, l'ordre relatif de chaque groupe gardé.
function Pr.front(list, front)
  local a, b = {}, {}
  for _, e in ipairs(list) do
    if front(e) then a[#a + 1] = e else b[#b + 1] = e end
  end
  for _, e in ipairs(b) do a[#a + 1] = e end
  return a
end

--- Filtre de décision : de verdicts (Pr.solid_step) et d'une fonction d'issue rend la liste input.solid de Pr.decide.
--- `issue(item)` rend (option, existe) ; une chaîne non consolidée sans option ni machine ni ordre ne retient rien.
function Pr.solid_list(verdicts, issue)
  local out = {}
  for _, x in ipairs(sorted_keys(verdicts)) do
    local v = verdicts[x]
    if not v.ok and not v.unmeasured and not v.lifted then
      local option, exists = issue(x)
      if option or exists or v.stopped then
        out[#out + 1] = { item = x, rank = v.rank, option = option and true or false, text = v.text }
      end
    end
  end
  return out
end

return Pr
