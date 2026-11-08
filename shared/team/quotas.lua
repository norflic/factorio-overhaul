--[[
  Lot VIDEO L4 « quotas dans le gabarit » (docs/VIDEO_AUTOMATISATION.md §6 L4 ; TODO_VIDEO V24, V25, V27, C08) : le MODULE se règle,
  le cerveau décide. Chaque module du plan directeur :
    - borne sa SORTIE à Q.SORTIE_MIN minutes de son débit nominal : barre du coffre de sortie (F95 : la barre limite aussi `insert`,
      la machine s'arrête seule quand le coffre est plein, ce qui est VOULU) ;
    - demande en ENTRÉE Q.ENTREE_MIN minute(s) d'ingrédients (V25), jamais plus que ce que le coffre d'entrée tient (I2) ;
    - n'est plus ALIMENTÉ quand ses sorties dépassent Q.FULL_PM ‰ de leur capacité sous la barre (V27 : un module plein n'avale pas
      d'ingrédients, qui restent pour les autres) ; la COLLECTE, elle, n'est jamais retenue (sinon interblocage), et son seuil ne
      dépasse jamais Q.COLLECT_PM ‰ de la capacité sous la barre (une sortie bornée sous le seuil de collecte ne serait jamais vidée).
  Défaut visé (IA_WORKFLOW §5, D2, partie du DC du 7/11) : fours « sortie pleine », ingrédients portés à des modules pleins.

  Lot VIDEO-COUVERTURE 3 (C11, C3.2) : un coffre de sortie à PLUSIEURS produits partage ses cases ouvertes en PARTS par produit (Q.share) : chaque
  produit garde au plus Q.SORTIE_MIN minutes de son débit, la somme des parts ne dépasse jamais la barre du coffre, un produit garde au moins une
  case quand la barre en offre une à chacun (res.outs[i].shares[objet] = { cases, cap }).

  PUR : aucune API du jeu, AUCUN nom d'objet, de machine ou de coffre (anti-échelle de tests/iag_test.lua §8 bis). Les débits viennent du
  gabarit (`nominal`, `inputs` : objets par seconde, calculés par M.analyze de shared/team/modules.lua, jamais écrits à la main : I1) ; la
  pile d'un objet et le nombre de cases d'un coffre sont LUS par l'appelant (prototypes) et passés en arguments. Un objet sans pile
  connue (fluide, électricité) n'a pas de quota. Testé hors jeu : tests/quotas_test.lua.

  Déterminisme : listes triées par nom, entiers, ‰ entiers, aucun pairs décisionnel, aucune horloge (I3).
]]

local Q = {}

Q.SORTIE_MIN = 10   -- minutes de débit nominal gardées aux coffres de sortie (même horizon que Ml.HORIZON_MIN et Id.HORIZON_MIN ;
                    -- la vidéo dit 1 min avec des tapis qui vident en continu ; nos PNJ collectent par voyages : à mesurer)
Q.ENTREE_MIN = 1    -- minutes de consommation nominale demandées à l'entrée (V25)
Q.FULL_PM = 900     -- ‰ : sorties à 90 % ou plus de leur capacité sous la barre → plus d'alimentation (feed_ok faux)
Q.COLLECT_PM = 500  -- ‰ : le seuil de collecte d'une sortie ne dépasse pas la moitié de sa capacité sous la barre
Q.LOW_PM = 500      -- ‰ : une entrée se remplit quand elle passe sous la moitié de sa demande

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local EPS = 1e-9

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

local function stack_of(opts, item)
  local s = opts.stack
  local v
  if type(s) == "function" then v = s(item) elseif type(s) == "table" then v = s[item] end
  if type(v) == "number" and v >= 1 then return floor(v) end
  return nil
end

--- Produit principal d'un gabarit : le plus fort débit nominal parmi les objets qui ont une pile (clé en cas d'égalité).
function Q.main(nominal, opts)
  local best, rate
  for _, k in ipairs(sorted_keys(nominal)) do
    local r = nominal[k]
    if type(r) == "number" and r > 0 and stack_of(opts or {}, k) and (rate == nil or r > rate + EPS) then best, rate = k, r end
  end
  return best
end

--- Coffres de sortie d'un gabarit M (ports « quai » de sortie, un coffre par entité, ses objets triés). Les sorties en tapis d'un
--- gabarit (fonderie) reçoivent leur coffre au plan directeur (P.out_quai) : l'appelant les passe alors sans objet ({}), et le
--- coffre porte le produit principal.
function Q.out_chests(g)
  local by, order = {}, {}
  for _, p in ipairs((g and g.ports) or {}) do
    if p.kind == "quai" and p.io == "out" and not p.unite and p.ent then
      if not by[p.ent] then by[p.ent] = {}; order[#order + 1] = p.ent end
      if p.item then by[p.ent][#by[p.ent] + 1] = p.item end
    end
  end
  table.sort(order)
  local out = {}
  for _, e in ipairs(order) do
    table.sort(by[e])
    out[#out + 1] = { ent = e, items = by[e] }
  end
  return out
end

--- Lot VIDEO-COUVERTURE 3 (C11, C3.2) : PARTAGE des `slots` cases ouvertes d'un coffre entre ses produits. wanted = liste de { item, cases
--- (cases voulues : Q.SORTIE_MIN minutes de son débit), rate }, dans l'ordre de l'appelant. Rend la liste des cases accordées, alignée sur
--- `wanted`. Règles : (1) aucun produit n'a plus que ce qu'il veut ; (2) la somme ne dépasse jamais `slots` ; (3) tout produit a au moins une case
--- quand `slots` en offre une à chacun (sinon les cases vont aux plus forts débits, puis au nom) ; (4) le reste se partage en proportion des
--- cases voulues au-delà de la première (plus forts restes d'abord, puis le nom : entiers, aucun hasard). Tout tient : rien n'est réduit.
function Q.share(wanted, slots)
  local n = #wanted
  local alloc = {}
  local total = 0
  for k, w in ipairs(wanted) do alloc[k] = w.cases total = total + w.cases end
  if total <= slots then return alloc end
  local order = {}
  for k = 1, n do order[k] = k end
  if slots < n then
    table.sort(order, function(a, b)
      local ra, rb = wanted[a].rate or 0, wanted[b].rate or 0
      if ra ~= rb then return ra > rb end
      return tostring(wanted[a].item) < tostring(wanted[b].item)
    end)
    for k = 1, n do alloc[k] = 0 end
    for j = 1, slots do alloc[order[j]] = 1 end
    return alloc
  end
  local rest, extra_total = slots - n, 0
  for k = 1, n do alloc[k] = 1 extra_total = extra_total + wanted[k].cases - 1 end
  if rest <= 0 or extra_total <= 0 then return alloc end
  local rem = {}
  local given = 0
  for k = 1, n do
    local e = wanted[k].cases - 1
    local part = floor(rest * e / extra_total + EPS)
    alloc[k] = alloc[k] + part
    given = given + part
    rem[k] = { k = k, r = rest * e - part * extra_total, room = e - part }
  end
  table.sort(rem, function(a, b)
    if a.r ~= b.r then return a.r > b.r end
    return tostring(wanted[a.k].item) < tostring(wanted[b.k].item)
  end)
  for _, x in ipairs(rem) do
    if given >= rest then break end
    if x.room > 0 and x.r > 0 then alloc[x.k] = alloc[x.k] + 1 given = given + 1 end
  end
  return alloc
end

--- Les quotas d'un module.
---   nominal, inputs : { [objet] = objets/s } (gabarit) ;
---   outs : liste des coffres de sortie { items = { objets } } (vide : produit principal) ;
---   ins : liste des coffres d'entrée { item } ;
---   opts = { stack = fonction ou table objet -> pile, slots = cases ouvertes d'un coffre de sortie (sous sa barre, s'il en a une),
---            in_slots = cases d'un coffre d'entrée (défaut : slots), collect_at = seuil de collecte de l'appelant,
---            lot_min = charge minimale d'un voyage d'alimentation (objets, ou fonction objet -> objets ; 0 par défaut : nos PNJ portent
---            par voyages, une minute d'un ingrédient lent ferait des voyages de 3 objets), sortie_min, entree_min }.
--- Rend { main, outs = { { items, cases, cap, collect_at, shares = { [objet] = { cases, cap } } } } (même ordre que `outs`), ins = { { item, want, low, cap } ou
--- { item, free = true } } (même ordre que `ins` : `free` = objet sans consommation nominale, l'appelant garde sa règle) }.
function Q.quotas(nominal, inputs, outs, ins, opts)
  opts = opts or {}
  local slots = (type(opts.slots) == "number" and opts.slots >= 1) and floor(opts.slots) or 1
  local in_slots = (type(opts.in_slots) == "number" and opts.in_slots >= 1) and floor(opts.in_slots) or slots
  local smin = opts.sortie_min or Q.SORTIE_MIN
  local emin = opts.entree_min or Q.ENTREE_MIN
  local main = Q.main(nominal, opts)
  -- coffres de sortie par objet (un coffre sans objet porte le produit principal)
  local carry = {}
  local n_of = {}
  for i, c in ipairs(outs or {}) do
    local items = (c.items and #c.items > 0) and c.items or (main and { main } or {})
    carry[i] = items
    for _, it in ipairs(items) do n_of[it] = (n_of[it] or 0) + 1 end
  end
  local res = { main = main, outs = {}, ins = {} }
  for i = 1, #(outs or {}) do
    -- Cases voulues par produit (Q.SORTIE_MIN minutes de SON débit), puis partage des cases ouvertes du coffre en PARTS (Q.share).
    local wanted = {}
    for _, it in ipairs(carry[i]) do
      local st = stack_of(opts, it)
      local r = (nominal or {})[it]
      if st and type(r) == "number" and r > 0 then
        local target = ceil(smin * 60 * r - EPS)                -- objets gardés pour tout le module
        local per_chest = ceil(target / n_of[it] - EPS)         -- partagés entre ses coffres
        wanted[#wanted + 1] = { item = it, cases = max(1, ceil(per_chest / st - EPS)), stack = st, rate = r }
      end
    end
    local alloc = Q.share(wanted, slots)
    local cases, cap, shares = 0, 0, {}
    for k, w in ipairs(wanted) do
      cases, cap = cases + alloc[k], cap + alloc[k] * w.stack
      shares[w.item] = { cases = alloc[k], cap = alloc[k] * w.stack }
    end
    local cat = nil
    if cases > 0 then
      cat = max(1, floor(cap * Q.COLLECT_PM / 1000 + EPS))
      if type(opts.collect_at) == "number" and opts.collect_at >= 1 then cat = min(cat, floor(opts.collect_at)) end
    end
    res.outs[i] = { items = carry[i], cases = cases, cap = cap, collect_at = cat, shares = shares }
  end
  -- coffres d'entrée : la minute d'ingrédients partagée entre les coffres du même objet
  local nin = {}
  for _, c in ipairs(ins or {}) do if c.item then nin[c.item] = (nin[c.item] or 0) + 1 end end
  for j, c in ipairs(ins or {}) do
    local it = c.item
    local r = it and (inputs or {})[it]
    local st = it and stack_of(opts, it)
    if not (st and type(r) == "number" and r > 0) then
      res.ins[j] = { item = it, free = true }
    else
      local cap = in_slots * st                                    -- I2 : ce que le coffre d'entrée tient
      local want = ceil(emin * 60 * r / nin[it] - EPS)
      local lot = opts.lot_min
      if type(lot) == "function" then lot = lot(it) end
      lot = (type(lot) == "number" and lot > 0) and floor(lot) or 0
      want = min(cap, max(1, want, lot))
      res.ins[j] = { item = it, want = want, low = max(1, ceil(want * Q.LOW_PM / 1000 - EPS)), cap = cap }
    end
  end
  return res
end

--- Raccourci : les quotas d'un gabarit M (nominal, inputs, coffres de sortie de ses ports ; `outs` remplace ces derniers quand le
--- plan directeur pose lui-même les coffres de sortie).
function Q.of_gabarit(g, ins, opts, outs)
  return Q.quotas(g and g.nominal, g and g.inputs, outs or Q.out_chests(g), ins, opts)
end

--- Le module peut-il être alimenté ? counts = liste alignée sur q.outs (objets au coffre ; nil ou < 0 : coffre absent, non compté).
--- Faux quand le total des sorties atteint Q.FULL_PM ‰ de leur capacité sous la barre. Un module sans coffre de sortie borné
--- (centrale, sortie en tapis vers un autre module) est toujours alimenté.
function Q.feed_ok(q, counts)
  local have, cap = 0, 0
  for i, o in ipairs((q and q.outs) or {}) do
    local n = (counts or {})[i]
    if type(n) == "number" and n >= 0 and (o.cap or 0) > 0 then have, cap = have + n, cap + o.cap end
  end
  if cap <= 0 then return true end
  return have * 1000 < cap * Q.FULL_PM
end

--- Remplissage d'une entrée : n objets au coffre, `have` au stock. Rend { due, count } : dû sous `low`, jusqu'à `want`, borné au stock.
function Q.refill(qin, n, have)
  if not qin or qin.free then return { due = false, count = 0 } end
  n, have = n or 0, have or 0
  if n >= qin.low or have <= 0 then return { due = false, count = 0 } end
  local c = min(qin.want - n, have)
  return { due = c > 0, count = max(0, c) }
end

--- Filtre E2 des tournées du plan directeur : retire l'ALIMENTATION (t.ia1d.mode == "fill") d'un projet dont le verdict est faux
--- (verdicts[pid] == false) ; garde la collecte et tout le reste. Liste neuve, même ordre.
--- ORPHELIN (inventaire W04, point 10) : aucun appelant à l'exécution, seulement tests/quotas_test.lua. Chemin réel : Build.Quotas.feed_ok,
--- script/team/build.lua:4002 (une sortie pleine n'émet plus de tournée de remplissage, build.lua:4018 ; la collecte n'est jamais retenue).
function Q.filter(tasks, verdicts)
  local out = {}
  for _, t in ipairs(tasks or {}) do
    local j = t.ia1d
    if not (j and j.mode == "fill" and verdicts and verdicts[j.pid] == false) then out[#out + 1] = t end
  end
  return out
end

--- Ligne du journal [FO-QUOTA] (aucune décision ne la lit).
function Q.describe(q, counts)
  local parts = {}
  for i, o in ipairs((q and q.outs) or {}) do
    parts[#parts + 1] = string.format("s%d %d/%d (%d case(s), collecte a %s)", i, (counts or {})[i] or -1, o.cap or 0, o.cases or 0,
      tostring(o.collect_at))
  end
  for _, c in ipairs((q and q.ins) or {}) do
    if not c.free then parts[#parts + 1] = string.format("e %s %d (sous %d)", tostring(c.item), c.want, c.low) end
  end
  return string.format("principal %s, alimentation %s ; %s", tostring(q and q.main), Q.feed_ok(q, counts) and "oui" or "NON",
    #parts > 0 and table.concat(parts, " ; ") or "aucun quota")
end


--[[ Lot TV-FLUX (C11, docs/TODO_VIDEO.md l.306 : « sans modules, recalculer les quotas ») : les quotas suivent les machines RÉELLEMENT posées.
  Le débit nominal du gabarit (M.analyze) suppose toutes ses machines à recette (fours, assembleurs) posées ; tant que des pièces manquent
  (chantier en cours, machine détruite en attente de reconstruction), le module ne produit ni ne mange ce débit : un quota calculé sur le
  nominal garde un coffre trop grand et porte trop d'ingrédients à un module qui ne les avale pas (défaut D2). Q.pieces compte, Q.scale
  recalcule. PUR, aucun nom d'objet. ]]

--- Machines à recette d'un projet : (posées, prévues). Une entité sans recette (tapis, bras, poteau, coffre) ne compte pas.
function Q.pieces(ents)
  local num, den = 0, 0
  for _, e in ipairs(ents or {}) do
    if e.recipe then
      den = den + 1
      if e.built then num = num + 1 end
    end
  end
  return num, den
end

--- Débits (objets/s) ramenés à la part de machines posées num/den. Table neuve, mêmes clés. Rien de prévu (den <= 0) ou tout posé :
--- les mêmes débits (copie). num est borné à [0, den].
function Q.scale(flows, num, den)
  local out = {}
  local k = nil
  if type(num) == "number" and type(den) == "number" and den > 0 then k = max(0, min(num, den)) / den end
  for key, v in next, flows or {} do
    if type(v) == "number" and k and k < 1 then out[key] = v * k else out[key] = v end
  end
  return out
end

return Q
