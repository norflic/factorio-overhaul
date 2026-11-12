--[[
  Lot CHANTIERS-FANTOMES (12/11) : TOURNÉE DE POSE. PUR : aucune API du moteur, aucun nom d'objet.
  Défaut mesuré en moteur réel (fo-logs/2026-11-13_CHANTIERS-FANTOMES-avant-123, journal [FO-GHOST-BILAN], partie-reelle-60) : une tâche de
  pose (kind « ghost », script/team/build.lua batch_tasks) servait UN point d'appui ; les points d'appui d'un champ hors du treillis sont les
  cases de 8 × 8 et ceux d'une ligne de poteaux sont espacés d'un poteau : 1,3 à 7 pièces par voyage (amber à 37,6 min : 240 tâches,
  1 217 pièces, 5,1 par tâche ; 38 % du temps à l'aller, 38 % au retour, 18 % à poser). 40 s d'aller-retour pour 1 poteau.
  Règle : les points d'appui d'un même projet sont groupés en tournées. Une tournée part du point d'appui le plus proche de l'origine (le QG),
  puis va de proche en proche au point d'appui libre le plus proche, à Tp.MAX_HOP tuiles au plus du précédent, tant que la tournée reste sous
  Tp.MAX_PIECES pièces et Tp.MAX_SLOTS piles d'inventaire. Un point d'appui seul plus gros que ces bornes fait sa tournée à lui seul.
    Tp.group(anchors, origin, stack) -> liste de tournées, chacune une liste d'indices dans `anchors`, dans l'ordre de passage.
      anchors : liste de { k = clé, x, y, n = pièces, items = { { nom, compte }, ... } }, triée par clé (ordre déterministe) ;
      origin  : { x, y } ; stack(nom) -> taille de pile (lue au prototype par l'appelant ; défaut 1 : prudent).
  Égalités départagées par la clé : même entrée, même résultat.
]]
local Tp = {}
Tp.MAX_PIECES = 48 -- pièces par tournée (6 posées par pensée : 8 s de pose)
Tp.MAX_SLOTS = 30  -- piles portées par tournée (inventaire du personnage : 80 ; marge pour le reste du sac)
Tp.MAX_HOP = 40    -- tuiles au plus entre deux points d'appui de suite d'une tournée

local function d2(a, b) return (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y) end

local function slots_of(counts, names, stack)
  local s = 0
  for _, nm in ipairs(names) do
    local sz = stack and stack(nm) or 1
    if type(sz) ~= "number" or sz < 1 then sz = 1 end
    s = s + math.ceil(counts[nm] / sz)
  end
  return s
end

--- La tournée `tour` (comptes `counts`, noms `names`) peut-elle prendre le point d'appui `a` ?
local function fits(tour_n, counts, names, a, stack)
  if tour_n + (a.n or 0) > Tp.MAX_PIECES then return false end
  local c2, n2 = {}, {}
  for _, nm in ipairs(names) do c2[nm] = counts[nm]; n2[#n2 + 1] = nm end
  for _, it in ipairs(a.items or {}) do
    if c2[it[1]] == nil then c2[it[1]] = 0; n2[#n2 + 1] = it[1] end
    c2[it[1]] = c2[it[1]] + it[2]
  end
  return slots_of(c2, n2, stack) <= Tp.MAX_SLOTS
end

local function add(counts, names, a)
  for _, it in ipairs(a.items or {}) do
    if counts[it[1]] == nil then counts[it[1]] = 0; names[#names + 1] = it[1] end
    counts[it[1]] = counts[it[1]] + it[2]
  end
end

--- Plus proche point d'appui libre de `from` (à `lim2` au plus si donné) ; égalité : la plus petite clé (ordre de la liste).
local function nearest(anchors, used, from, lim2)
  local best, bd
  for i, a in ipairs(anchors) do
    if not used[i] then
      local d = d2(a, from)
      if (not lim2 or d <= lim2) and (bd == nil or d < bd or (d == bd and tostring(a.k) < tostring(anchors[best].k))) then
        best, bd = i, d
      end
    end
  end
  return best
end

function Tp.group(anchors, origin, stack)
  local tours = {}
  local used = {}
  local left = #anchors
  local hop2 = Tp.MAX_HOP * Tp.MAX_HOP
  while left > 0 do
    local i = nearest(anchors, used, origin or anchors[1], nil)
    local tour, counts, names = { i }, {}, {}
    used[i], left = true, left - 1
    add(counts, names, anchors[i])
    local n = anchors[i].n or 0
    local last = anchors[i]
    while left > 0 do
      local j = nearest(anchors, used, last, hop2)
      if not j or not fits(n, counts, names, anchors[j], stack) then break end
      tour[#tour + 1] = j
      used[j], left = true, left - 1
      add(counts, names, anchors[j])
      n = n + (anchors[j].n or 0)
      last = anchors[j]
    end
    tours[#tours + 1] = tour
  end
  return tours
end

return Tp
