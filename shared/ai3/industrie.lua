--[[
  Lot INDUSTRIE I6 « choix » (PLAN INDUSTRIE §2, §3 ; demande du DC du 31/10 : « un systeme de choix dynamique de mall a faire et
  de patern a copier », « si un élément devient trop répétitif a construire à la main, elles doivent l'automatiser EN FONCTION DU
  BESOIN (c'est à dire qu'on ne met pas qu'un seul pauvre assembleur) », « peu importe le mod »).

  Règle PURE (aucune API Factorio ; AUCUN nom d'objet, de machine, de recette ou de catégorie : soumise à l'anti-échelle de
  tests/iag_test.lua §8). Elle choisit, pour chaque objet demandé, un PATRON et un NOMBRE DE COPIES d'après le besoin ; les
  gabarits eux-mêmes sont ceux du lot I5 (shared/team/patrons.lua), la lecture des recettes et des machines celle du lot I4
  (shared/ai3/lecture.lua, cat.fab).

  Pour chaque objet i de demande Di (objets par minute) :
    1. recette et machine : la recette qui fait l'objet (cat.fab), la machine UTILISABLE la plus rapide qui la prend ; son débit
       par minute (lecture : par_min) ;
    2. besoin en machines : N = Di × Id.LEAD ÷ par_min (la capacité vise le double de la demande, comme Ca.LEAD) ;
    3. choix du patron :
         N ≥ Id.ROW_MIN (une demi-machine : le seuil où la capitalisation ouvre une chaîne, Ca.count) et la capitalisation n'a pas refusé
              → RANGÉE : ⌈N⌉ copies de la cellule, une recette (la capitalisation la pose, l'exécutant `patron`) ;
         N < Id.ROW_MIN, ou objet que la capitalisation vient de refuser (source Id.SRC_REFUS : personne d'autre ne le poserait)
              → BLOC DE MALL partagé : une machine par objet, 4 voies d'entrée communes (P.groups) ;
         plus de 4 entrées solides et N < Id.ROW_MIN → une cellule seule, une machine ;
       un objet à fluide en entrée ou sans recette lue est refusé, raison écrite (jamais silencieux).
    4. un bloc s'ouvre quand il a Id.GROUP_MIN objets, qu'il est plein, ou que son plus vieux objet attend depuis Id.GROUP_WAIT
       ticks de jeu (aucun temps mesuré) : on ne pose pas un bloc de 8 machines pour un objet, et personne n'attend sans fin.
  Sources de demande (Id.merge) : la demande de la main (Ml.note), la demande non servie du cerveau (refus « manque sous une
  demi-machine » de la capitalisation, Id.parse_refus), toute autre liste que le runtime fournit. La demande d'un objet est le
  MAXIMUM de ses sources (la même demande vue par deux voies n'est pas comptée deux fois).
  Déterminisme : listes triées par (demande décroissante, nom), entiers et flottants calculés dans un ordre fixe, aucun pairs
  décisionnel, aucune horloge mesurée ; l'état `st` (nombres et chaînes) est sérialisable.
]]

local P = require("shared.team.patrons")

local Id = {}

Id.LEAD = 2              -- capacité visée = 2 fois la demande (Ca.LEAD, Ml.LEAD)
Id.ROW_MIN = 0.5         -- machines : à partir d'une demi-machine, une rangée (Ca.U_MIN % : la capitalisation ouvre alors une chaîne)
Id.GROUP_MIN = 3         -- objets qui ouvrent un bloc de mall
Id.GROUP_WAIT = 3 * 3600 -- ticks de jeu qu'un objet attend un bloc avant qu'un bloc plus petit s'ouvre pour lui
Id.HORIZON_MIN = 10      -- minutes de demande gardées au coffre de sortie (la VRAIE réserve : Ml.HORIZON_MIN)
Id.EPS = 1e-9
Id.SRC_REFUS = "refus"   -- source de demande : la capitalisation a refusé l'objet (« manque sous une demi-machine »)
Id.SRC_REFUS = "refus"   -- source de demande : la capitalisation a refusé l'objet (« manque sous une demi-machine »)

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

---------------------------------------------------------------------------------------------------
-- Lecture
---------------------------------------------------------------------------------------------------
--- Demande non servie lue dans le texte d'un refus de la capitalisation : « manque sous une demi-machine (X/min) » → X, sinon nil.
--- (Le seul refus qui porte un débit ; les autres refus ont une cause qui n'est pas un manque de machine.)
function Id.parse_refus(why)
  if type(why) ~= "string" then return nil end
  local x = why:match("^manque sous une demi%-machine %(([%d%.]+)/min%)")
  x = x and tonumber(x)
  if x and x > 0 then return x end
  return nil
end

--- Recette de l'objet dans le relevé de lecture `fab` : celle qui porte son nom si elle le produit, sinon la première (par nom)
--- qui le produit. Rend (nom, entrée) ou nil.
function Id.recipe_of(fab, item)
  if type(fab) ~= "table" then return nil end
  local own = fab[item]
  if own then
    for _, p in ipairs(own.produits or {}) do if p == item then return item, own end end
  end
  for _, name in ipairs(sorted_keys(fab)) do
    local e = fab[name]
    for _, p in ipairs(e.produits or {}) do
      if p == item then return name, e end
    end
  end
  return nil
end

--- La machine utilisable la plus rapide d'une entrée du relevé (`usable(objet)` : fonction, ensemble ou nil : toutes). Les machines
--- sont triées du moins rapide au plus rapide : la dernière utilisable gagne.
function Id.pick_machine(entry, usable)
  local best
  for _, m in ipairs(entry and entry.machines or {}) do
    local ok = true
    if usable ~= nil then
      if type(usable) == "function" then ok = usable(m.item) and true or false else ok = usable[m.item] and true or false end
    end
    if ok then best = m end
  end
  return best
end

--- Profil d'un objet : { recipe, entry, machine, par_min, s, solides = { noms triés }, fluides } ou (nil, raison).
function Id.profile(fab, item, usable)
  local rname, e = Id.recipe_of(fab, item)
  if not rname then return nil, "limite : aucune recette ne fabrique " .. tostring(item) end
  if not e.patronnable then
    return nil, (e.refus and e.refus.texte) or ("limite : " .. rname .. " hors patron")
  end
  if #(e.fluides_in or {}) > 0 then
    return nil, "limite : " .. rname .. " demande un fluide (source non fournie)"
  end
  local m = Id.pick_machine(e, usable)
  if not m then return nil, "recherche : aucune machine utilisable pour " .. rname end
  local names = {}
  for _, s in ipairs(e.solides or {}) do names[#names + 1] = s.name end
  table.sort(names)
  return { recipe = rname, entry = e, machine = m, par_min = m.par_min or 0, s = #names, solides = names,
    fluides = #(e.fluides_in or {}) }
end

---------------------------------------------------------------------------------------------------
-- Demande
---------------------------------------------------------------------------------------------------
--- Fusionne des listes de demande { { item, rate, src } } : une ligne par objet, demande = le maximum des sources, sources triées.
--- Triée par (demande décroissante, nom).
function Id.merge(sources)
  local by = {}
  for _, list in ipairs(sources or {}) do
    for _, c in ipairs(list) do
      if type(c.item) == "string" and type(c.rate) == "number" and c.rate > Id.EPS then
        local cur = by[c.item]
        if not cur then
          cur = { item = c.item, rate = c.rate, srcs = {} }
          by[c.item] = cur
        elseif c.rate > cur.rate then
          cur.rate = c.rate
        end
        cur.srcs[c.src or "?"] = true
      end
    end
  end
  local out = {}
  for _, k in ipairs(sorted_keys(by)) do
    local c = by[k]
    c.srcs = sorted_keys(c.srcs)
    out[#out + 1] = c
  end
  table.sort(out, function(a, b)
    if a.rate ~= b.rate then return a.rate > b.rate end
    return a.item < b.item
  end)
  return out
end

--- Cases ouvertes du coffre de sortie (la barre, F95) pour garder `Id.HORIZON_MIN` minutes de demande : ⌈cible ÷ pile⌉, de 1 à `slots`.
function Id.barre(rate, stack, slots)
  if type(stack) ~= "number" or stack < 1 then stack = 1 end
  local target = math.max(1, math.ceil((rate or 0) * Id.HORIZON_MIN - Id.EPS))
  local n = math.ceil(target / stack - Id.EPS)
  if n < 1 then n = 1 end
  if type(slots) == "number" and slots >= 1 and n > slots then n = slots end
  return n
end

---------------------------------------------------------------------------------------------------
-- Décision
---------------------------------------------------------------------------------------------------
--- inp = {
---   tick,
---   sources = { liste de { item, rate (objets/min), src } },
---   fab   = cat.fab (shared/ai3/lecture.lua), usable = objet -> bool (ou ensemble, ou nil),
---   served = { [objet] = vrai } : objets déjà servis (machine posée ou module ouvert),
---   bloc_max = function(entité de machine) -> machines d'un bloc au plus (P.bloc_max), ou nombre,
--- }
--- Rend { cands, rows = { { item, recipe, machine, n, need, par_min, rate } }, blocs = { { machine, items = { noms }, voies,
--- rates = { [objet] = débit }, recipes = { [objet] = recette }, waited } }, seuls = { { item, recipe, machine, rate, need } },
--- wait = { { item, since } }, refus = { { item, why } } }.
--- st (sérialisable) : first[objet] = tick où l'objet est devenu candidat sans être servi.
function Id.decide(st, inp)
  st.first = st.first or {}
  local tick = inp.tick or 0
  local cands = Id.merge(inp.sources)
  local out = { cands = cands, rows = {}, blocs = {}, seuls = {}, wait = {}, refus = {} }
  local pend, seen = {}, {}
  for _, c in ipairs(cands) do
    seen[c.item] = true
    if inp.served and inp.served[c.item] then
      st.first[c.item] = nil
    else
      local pr, why = Id.profile(inp.fab, c.item, inp.usable)
      if not pr then
        out.refus[#out.refus + 1] = { item = c.item, why = why }
      elseif pr.par_min <= 0 then
        out.refus[#out.refus + 1] = { item = c.item, why = "limite : " .. pr.recipe .. " sans debit" }
      else
        local need = c.rate * Id.LEAD / pr.par_min
        -- Relecture 0.6.31 : le refus de la capitalisation porte le MANQUE (demande moins stock et main) sous une demi-machine : avec LEAD, de 0,25 à
        -- 0,5 machine de manque tombait en « rangée », que la capitalisation venait justement de refuser : aucune des deux règles ne le servait.
        local refused = false
        for _, src in ipairs(c.srcs) do if src == Id.SRC_REFUS then refused = true end end
        if need >= Id.ROW_MIN - Id.EPS and not refused then
          out.rows[#out.rows + 1] = { item = c.item, recipe = pr.recipe, machine = pr.machine.entity, n = P.copies(c.rate * Id.LEAD, pr.par_min),
            need = need, par_min = pr.par_min, rate = c.rate }
          st.first[c.item] = nil
        else
          st.first[c.item] = st.first[c.item] or tick
          pend[#pend + 1] = { name = c.item, solides = pr.solides, machine = pr.machine.entity, recipe = pr.recipe, rate = c.rate,
            need = need, s = pr.s }
        end
      end
    end
  end
  for _, k in ipairs(sorted_keys(st.first)) do if not seen[k] then st.first[k] = nil end end
  -- blocs : par classe de machine (un bloc n'a qu'une machine), objets à plus de 4 entrées à part
  local classes, by_class = {}, {}
  for _, o in ipairs(pend) do
    if o.s > P.BLOC_VOIES then
      local waited = tick - (st.first[o.name] or tick)
      if waited >= Id.GROUP_WAIT then
        out.seuls[#out.seuls + 1] = { item = o.name, recipe = o.recipe, machine = o.machine, rate = o.rate, need = o.need }
      else
        out.wait[#out.wait + 1] = { item = o.name, since = st.first[o.name] }
      end
    else
      if not by_class[o.machine] then by_class[o.machine] = {} classes[#classes + 1] = o.machine end
      table.insert(by_class[o.machine], o)
    end
  end
  table.sort(classes)
  for _, cl in ipairs(classes) do
    local list = by_class[cl]
    local cap = inp.bloc_max
    if type(cap) == "function" then cap = cap(cl) end
    if type(cap) ~= "number" or cap < 1 then cap = 1 end
    local objs = {}
    for _, o in ipairs(list) do objs[#objs + 1] = { name = o.name, solides = o.solides, machine = cl } end
    local g = P.groups(objs, { max = cap })
    local info = {}
    for _, o in ipairs(list) do info[o.name] = o end
    for _, bl in ipairs(g.blocs) do
      local oldest = nil
      for _, nm in ipairs(bl.objets) do
        local f = st.first[nm] or tick
        if oldest == nil or f < oldest then oldest = f end
      end
      local waited = tick - (oldest or tick)
      if #bl.objets >= Id.GROUP_MIN or #bl.objets >= cap or waited >= Id.GROUP_WAIT then
        local items = {}
        for i, nm in ipairs(bl.objets) do items[i] = nm end
        table.sort(items)
        local rates, recipes = {}, {}
        for _, nm in ipairs(items) do rates[nm] = info[nm].rate recipes[nm] = info[nm].recipe end
        out.blocs[#out.blocs + 1] = { machine = cl, items = items, voies = bl.voies, rates = rates, recipes = recipes, waited = waited }
      else
        for _, nm in ipairs(bl.objets) do out.wait[#out.wait + 1] = { item = nm, since = st.first[nm] } end
      end
    end
    for _, nm in ipairs(g.seuls) do
      local o = info[nm]
      out.seuls[#out.seuls + 1] = { item = nm, recipe = o.recipe, machine = cl, rate = o.rate, need = o.need }
    end
  end
  table.sort(out.blocs, function(a, b)
    if #a.items ~= #b.items then return #a.items > #b.items end
    return a.items[1] < b.items[1]
  end)
  table.sort(out.seuls, function(a, b) return a.item < b.item end)
  table.sort(out.wait, function(a, b) return a.item < b.item end)
  table.sort(out.refus, function(a, b) return a.item < b.item end)
  return out
end

--- Une ligne du journal [FO-MALL] (aucune décision ne la lit).
function Id.describe(out)
  local rows, blocs = {}, {}
  for _, r in ipairs(out.rows or {}) do rows[#rows + 1] = string.format("%s x%d (%.2f machine(s) voulue(s))", r.item, r.n, r.need) end
  for _, b in ipairs(out.blocs or {}) do blocs[#blocs + 1] = "[" .. table.concat(b.items, ",") .. "]" end
  return string.format("%d candidat(s) : %d rangee(s) {%s}, %d bloc(s) {%s}, %d cellule(s) seule(s), %d en attente, %d refus",
    #(out.cands or {}), #(out.rows or {}), table.concat(rows, " ; "), #(out.blocs or {}), table.concat(blocs, " "),
    #(out.seuls or {}), #(out.wait or {}), #(out.refus or {}))
end

return Id
