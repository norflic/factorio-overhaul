--[[
  ANNEXES DU QG (lot COFFRE) : règles PURES (aucune API Factorio) ; l'exécution est script/team/stock.lua.

  Le coffre du QG d'une équipe a un nombre de cases fini. Plein, aucun ouvrier ne peut plus y déposer. Des coffres
  supplémentaires (annexes) se posent donc autour du QG dès que les cases se remplissent (T.annex,
  shared/team/config.lua), et l'excédent du coffre du QG y est rangé, par piles entières, avant qu'il soit plein.

    A.fill(used, size)                     remplissage 0..1 ;
    A.outward(y)                           face du QG tournée vers l'EXTÉRIEUR de la carte : -1 (nord) si le QG est au nord de
                                           l'origine, sinon +1 (sud) ;
    A.slots(sy, w, h)                      places du bloc des annexes { { dx, dy } }, de la plus proche du QG à la plus
                                           lointaine, dans le sens sy (lot STOCKAGE : le bloc grandit vers l'extérieur) ;
    A.capacity(sy, w, h)                   nombre de places du bloc = plafond d'annexes (borné par la place du lot du QG) ;
    A.watch(st, used, size, tick)          AGRANDISSEMENT RÉGULIER : tient la fenêtre « stock à T.annex.early_at ou plus » ;
    A.early_due(st, tick, refused_at)      vrai quand la fenêtre a duré T.annex.early_ticks, ou qu'un dépôt a été refusé il y
                                           a moins de T.annex.refused_ticks (coffre plein pour un objet) ;
    A.wanted(used, size, n_annex, have, early, cap)
                                           coffres à FABRIQUER ou à avoir en main : 0 tant que le total QG + annexes est sous
                                           T.annex.grow_at sans pose anticipée (early) ou que le maximum d'annexes est atteint,
                                           sinon T.annex.want moins ceux déjà en main ;
    A.need_chest(used, size, n_annex, early, cap)
                                           vrai quand il faut POSER un coffre maintenant ;
    A.park_plan(contents, stack_of, size, used, room)
                                           ce qu'on range : liste { { objet, nombre } } de piles ENTIÈRES, les objets qui
                                           prennent le plus de cases d'abord, une pile au moins laissée au QG
                                           (T.annex.keep), jusqu'à revenir à T.annex.park_to, dans la limite de `room`
                                           cases libres aux annexes ; vide sous T.annex.park_at.

  Déterminisme : objets triés par cases prises puis par nom, places triées par distance puis coordonnées (aucune décision
  selon l'ordre de pairs).
]]

local T = require("shared.team.config")

local A = {}

function A.fill(used, size)
  if not size or size <= 0 then return 1 end
  return (used or 0) / size
end

function A.outward(y)
  if (y or 0) < 0 then return -1 end
  return 1
end

--- Places du bloc pour une annexe de w × h tuiles, face sy (+1 sud, -1 nord) : colonnes de -half à +half (pas = largeur +
--- écart), rangées de near à far dans le sens sy (pas = hauteur + écart) ; triées par distance au QG (carré), puis rangée
--- la plus proche, puis colonne. Décalages en tuiles depuis le centre du QG ; l'appelant recale sur la grille (Pl.snap).
function A.slots(sy, w, h)
  local b = T.annex.block
  w, h = math.max(1, w or 1), math.max(1, h or 1)
  sy = (sy or 1) < 0 and -1 or 1
  local half = sy < 0 and b.half_north or b.half_south
  local px, py = w + T.annex.gap, h + T.annex.gap
  local out = {}
  local dx = -half
  while dx <= half do
    local r = b.near
    while r <= b.far do
      out[#out + 1] = { dx, sy * r, dx * dx + r * r, r }
      r = r + py
    end
    dx = dx + px
  end
  table.sort(out, function(a, c)
    if a[3] ~= c[3] then return a[3] < c[3] end
    if a[4] ~= c[4] then return a[4] < c[4] end
    return a[1] < c[1]
  end)
  for i, p in ipairs(out) do out[i] = { p[1], p[2] } end
  return out
end

function A.capacity(sy, w, h)
  return #A.slots(sy, w, h)
end

--- Fenêtre d'agrandissement régulier. st = { since = tick | nil } (nombres seuls : rangé dans l'équipe). Le total QG +
--- annexes à T.annex.early_at ou plus ouvre la fenêtre ; sous T.annex.early_keep elle se ferme (entre les deux : inchangée,
--- pour qu'une consommation passagère ne la relance pas à zéro).
function A.watch(st, used, size, tick)
  if not size or size <= 0 then st.since = nil; return st end
  local fill = A.fill(used, size)
  if fill >= T.annex.early_at then
    st.since = st.since or tick
  elseif fill < T.annex.early_keep then
    st.since = nil
  end
  return st
end

function A.early_due(st, tick, refused_at)
  -- dépôt refusé récemment : au plus une pose par T.annex.refused_ticks par ce chemin (st.placed_at = dernière pose)
  if refused_at and tick >= refused_at and tick - refused_at <= T.annex.refused_ticks
    and not (st and st.placed_at and tick - st.placed_at < T.annex.refused_ticks) then
    return true
  end
  return st ~= nil and st.since ~= nil and tick - st.since >= T.annex.early_ticks
end

function A.need_chest(used, size, n_annex, early, cap)
  if (n_annex or 0) >= (cap or T.annex.max) then return false end
  return early == true or A.fill(used, size) >= T.annex.grow_at
end

function A.wanted(used, size, n_annex, have, early, cap)
  if not A.need_chest(used, size, n_annex, early, cap) then return 0 end
  return math.max(0, T.annex.want - (have or 0))
end

function A.park_plan(contents, stack_of, size, used, room)
  local out = {}
  if (used or 0) < T.annex.park_at * size or (room or 0) <= 0 then return out end
  local rows = {}
  for name, n in pairs(contents or {}) do
    local stack = math.max(1, stack_of[name] or 1)
    local whole = math.floor((n - T.annex.keep * stack) / stack)
    if whole > 0 then rows[#rows + 1] = { name = name, stack = stack, whole = whole, slots = math.ceil(n / stack) } end
  end
  table.sort(rows, function(a, b)
    if a.slots ~= b.slots then return a.slots > b.slots end
    return a.name < b.name
  end)
  local to_free = used - math.floor(T.annex.park_to * size)
  for _, r in ipairs(rows) do
    if to_free <= 0 or room <= 0 then break end
    local k = math.min(r.whole, to_free, room)
    out[#out + 1] = { r.name, k * r.stack }
    to_free, room = to_free - k, room - k
  end
  return out
end

return A
