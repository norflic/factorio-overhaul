--[[
  Lot L2 « la porte de rang ciblée » (docs/VIDEO_AUTOMATISATION.md §6 L2, docs/TODO_VIDEO.md §H). PUR (aucune API Factorio),
  testé hors jeu (tests/porte_rang_test.lua). RIEN N'EST BRANCHÉ : la capitalisation garde ses règles d'emplacement.

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
  -- Manques qui bloquent : ceux qui ont une option, triés par (rang, nom).
  local def = {}
  for _, s in ipairs(input.short or {}) do
    if s.option and s.item ~= nil and s.rank ~= nil then def[#def + 1] = s end
  end
  table.sort(def, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.item < b.item
  end)
  local rstar = def[1] and def[1].rank or nil
  local deps = input.deps or {}
  local allowed, held = {}, {}
  for _, o in ipairs(input.orders or {}) do
    local cause = nil
    if (o.pile or 2) > Pr.KEEP_PILE and o.rank ~= nil then
      local up = deps[o.item] or {}
      for _, s in ipairs(def) do
        if cause == nil and s.rank < o.rank and up[s.item] then
          cause = string.format("rang : %s (rang %d) d'abord", s.item, s.rank)
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
  return { allowed = allowed, held = held, rstar = rstar }
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

return Pr
