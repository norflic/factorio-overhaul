--[[
  Lot CONVEYOR-SCALING (directive du DC du 9/11, « multiplication du débit logistique ») : règles PURES de la montée de palier des
  convoyeurs d'une équipe. Aucune API Factorio, aucun nom d'objet : les paliers sont des VITESSES (`belt_speed` des prototypes de type
  transport-belt, lues par l'appelant), les objets du kit sont des clés opaques. Tests : tests/conveyor_scaling_test.lua.

    Cs.capacity(speed, lanes)          débit d'un tapis entier (2 voies) : belt_speed × 480 objets/s (0,03125 → 15/s) ; `lanes` = 1 pour une voie
    Cs.rank(segments, cfg)             ordre de remplacement : troncs du bus, puis sorties de méga-fonderie, puis liaisons, bandes, le reste ;
                                       à sorte égale le plus SATURÉ d'abord (débit / capacité du palier actuel). Laissés (second résultat,
                                       avec la raison) : palier cible absent (non activé), débit inconnu, remplissage sous cfg.min_fill.
    Cs.budget(ranked, kit, opts)       ce que le stock de tapis cibles paie, dans l'ordre : pay / waiting / short (manques par objet).
                                       Zéro inactivité : un segment non payé n'est jamais retiré, l'existant continue.
    Cs.braid(width, lanes, cfg)        motif d'un couloir « tressé » : `lanes` voies dans `width` tuiles de large grâce aux souterrains.
                                       En Factorio 1.1 deux souterrains du MÊME palier ne se croisent pas : une colonne porte k voies
                                       tressées seulement avec k paliers de souterrains DISTINCTS, chacun de portée ≥ 2k − 1 ; un seul
                                       palier = une voie par colonne (aucun gain). nil + raison quand c'est impossible.
    Cs.line(team, paid, short)         texte du journal [FO-CONVOYEURS] « montée de palier : … ; en attente : … »
  Ni temps mesuré, ni ordre de `pairs` : les listes sont triées sur des clés stables.
]]

local Cs = {}

Cs.BELT_FACTOR = 480 -- objets/s par unité de belt_speed pour un tapis ENTIER (8 objets par tuile × 60 ticks/s) : 0,03125 → 15/s
Cs.CFG = { min_fill = 0.6 } -- part de la capacité actuelle sous laquelle un segment n'est « pas saturé » (directive : 60 %)
Cs.ORDER = { tronc = 1, ["sortie-fonderie"] = 2, liaison = 3, bande = 4, autre = 5 } -- priorité du DC

local floor = math.floor

--- Débit (objets/s) d'un tapis de vitesse `speed` sur `lanes` voies (2 par défaut : le tapis entier). 0 quand la vitesse est invalide.
function Cs.capacity(speed, lanes)
  if type(speed) ~= "number" or speed <= 0 then return 0 end
  local l = lanes or 2
  if type(l) ~= "number" or l <= 0 then l = 2 end
  return speed * Cs.BELT_FACTOR * (l / 2)
end

--- Remplissage d'un segment : débit / capacité du palier actuel ; nil si le débit est inconnu ou la capacité nulle.
function Cs.fill(seg)
  if type(seg.flow) ~= "number" or seg.flow < 0 then return nil end
  local cap = Cs.capacity(seg.tier_now, seg.lanes)
  if cap <= 0 then return nil end
  return seg.flow / cap
end

local function key_of(id) return tostring(id) end

--- Raison pour laquelle un segment est laissé, ou nil s'il est candidat (son remplissage est alors rendu en second).
local function reject(seg, cfg)
  if type(seg) ~= "table" or seg.id == nil then return "segment invalide" end
  if type(seg.tier_now) ~= "number" or seg.tier_now <= 0 then return "palier actuel inconnu" end
  if type(seg.tier_target) ~= "number" or seg.tier_target <= seg.tier_now then return "pas de palier cible activé" end
  if type(seg.len) ~= "number" or seg.len <= 0 then return "aucune tuile" end
  local fill = Cs.fill(seg)
  if fill == nil then return "débit inconnu" end
  if fill < (cfg.min_fill or Cs.CFG.min_fill) - 1e-9 then return string.format("pas saturé (%d %%)", floor(fill * 100 + 0.5)) end
  return nil, fill
end

--- Ordre de remplacement. segments = { { id, kind, flow, len, tier_now, tier_target, lanes?, item?, target? } }. Rend (ranked, left) :
--- ranked = copies des candidats avec `fill` et `prio`, triés par sorte (Cs.ORDER), remplissage décroissant, longueur décroissante,
--- identifiant ; left = { { id, kind, why } } dans l'ordre d'entrée. Les sortes inconnues sont « autre ». Déterministe.
function Cs.rank(segments, cfg)
  cfg = cfg or Cs.CFG
  local ranked, left = {}, {}
  for _, seg in ipairs(segments or {}) do
    local why, fill = reject(seg, cfg)
    if why then
      left[#left + 1] = { id = type(seg) == "table" and seg.id or nil, kind = type(seg) == "table" and seg.kind or nil, why = why }
    else
      local kind = Cs.ORDER[seg.kind] and seg.kind or "autre"
      ranked[#ranked + 1] = { id = seg.id, kind = kind, prio = Cs.ORDER[kind], fill = fill, flow = seg.flow, len = seg.len,
        lanes = seg.lanes, tier_now = seg.tier_now, tier_target = seg.tier_target, item = seg.item, target = seg.target, ref = seg.ref }
    end
  end
  table.sort(ranked, function(a, b)
    if a.prio ~= b.prio then return a.prio < b.prio end
    if math.abs(a.fill - b.fill) > 1e-9 then return a.fill > b.fill end
    if a.len ~= b.len then return a.len > b.len end
    return key_of(a.id) < key_of(b.id)
  end)
  return ranked, left
end

--- Budget : `kit` = { [objet] = pièces en stock } ; un segment demande `len` pièces de `item`. Il est payé quand le kit couvre
--- min(len, opts.min_pieces or len) pièces (opts.min_pieces : un lot suffit à commencer, le reste suit) ; le kit est débité de ce
--- qu'il couvre. Rend { pay = {segments payés, dans l'ordre}, waiting = { { id, kind, item, need, have } }, short = { { item, n } }
--- (manque total par objet, trié par objet) }. Un segment sans objet cible est en attente (« objet inconnu »).
function Cs.budget(ranked, kit, opts)
  kit = kit or {}
  local left = {}
  for item, n in pairs(kit) do if type(n) == "number" then left[item] = n end end -- (copie : l'appelant garde son kit intact)
  local out = { pay = {}, waiting = {}, short = {} }
  local missing = {}
  for _, seg in ipairs(ranked or {}) do
    local item, len = seg.item, seg.len or 0
    local have = item and left[item] or 0
    local min_pieces = math.min(len, (opts and opts.min_pieces) or len)
    if item and len > 0 and have >= math.max(1, min_pieces) then
      out.pay[#out.pay + 1] = seg
      local taken = math.min(len, have)
      left[item] = have - taken
      if taken < len then missing[item] = (missing[item] or 0) + (len - taken) end
    else
      out.waiting[#out.waiting + 1] = { id = seg.id, kind = seg.kind, item = item, need = len, have = have }
      if item then missing[item] = (missing[item] or 0) + math.max(0, len - have) end
    end
  end
  local items = {}
  for item in pairs(missing) do items[#items + 1] = item end
  table.sort(items)
  for _, item in ipairs(items) do if missing[item] > 0 then out.short[#out.short + 1] = { item = item, n = missing[item] } end end
  return out
end

--- Portées des paliers de souterrains disponibles, triées décroissantes : cfg.tiers = { { reach } } ou cfg.underground_reach (nombre
--- ou liste de nombres). Chaque entrée est un palier DISTINCT (un palier ne figure qu'une fois).
local function reaches(cfg)
  local out = {}
  local src = cfg and (cfg.tiers or cfg.underground_reach)
  if type(src) == "number" then out[1] = src
  elseif type(src) == "table" then
    for _, t in ipairs(src) do
      local r = type(t) == "table" and t.reach or t
      if type(r) == "number" and r >= 2 then out[#out + 1] = r end
    end
  end
  table.sort(out, function(a, b) return a > b end)
  return out
end

--- Motif pur d'un couloir tressé : `lanes` voies dans `width` colonnes. Les voies sont réparties au plus égal entre les colonnes
--- (les premières colonnes prennent le reste) ; une colonne à k voies les tresse sur k paliers distincts : la voie j (0..k−1), sur
--- le palier j, SORT du souterrain au rang 2j et y RENTRE au rang 2j + 1 d'une période de 2k tuiles, cachée sous les 2k − 2 autres
--- (distance entrée → sortie suivante 2k − 1 ≤ portée du palier). k = 1 : tapis de surface, sans souterrain.
--- Rend { width, lanes, period, columns = { { col, k, lanes = { { lane, tier, exit, entry, hidden } } } } } ou nil, raison.
function Cs.braid(width, lanes, cfg)
  if type(width) ~= "number" or width < 1 or type(lanes) ~= "number" or lanes < 1 then return nil, "largeur ou voies invalides" end
  width, lanes = floor(width), floor(lanes)
  local rs = reaches(cfg)
  local per_col_max = math.max(1, #rs)
  if lanes > 2 * width and lanes > per_col_max * width then
    return nil, string.format("%d voies > %d (2 × %d tuiles)", lanes, 2 * width, width)
  end
  if lanes > per_col_max * width then
    return nil, string.format("%d voies pour %d tuiles : il faut %d paliers de souterrains distincts, %d disponible(s)",
      lanes, width, math.ceil(lanes / width), #rs)
  end
  local out = { width = width, lanes = lanes, period = 1, columns = {} }
  local base, extra, lane_no = floor(lanes / width), lanes % width, 0
  for c = 0, width - 1 do
    local k = base + ((c < extra) and 1 or 0)
    local col = { col = c, k = k, lanes = {} }
    if k >= 2 then
      local need = 2 * k - 1
      for j = 1, k do
        if rs[j] < need then
          return nil, string.format("colonne %d : %d voies demandent %d paliers de portée ≥ %d, le palier %d porte %d", c, k, k, need, j, rs[j])
        end
      end
      out.period = math.max(out.period, 2 * k)
    end
    for j = 0, k - 1 do
      lane_no = lane_no + 1
      if k == 1 then col.lanes[1] = { lane = lane_no, tier = nil, exit = nil, entry = nil, hidden = 0 }
      else col.lanes[j + 1] = { lane = lane_no, tier = j + 1, exit = 2 * j, entry = 2 * j + 1, hidden = 2 * k - 2 } end
    end
    out.columns[#out.columns + 1] = col
  end
  return out
end

--- Texte du journal : « montée de palier : tronc 12 (40 tuiles) puis sortie-fonderie 7 (18 tuiles) ; en attente : <objet> x<n> ».
--- `paid` = liste de segments (id, kind, len) dans l'ordre ; `short` = Cs.budget(...).short. Sans rien : « rien à monter ».
function Cs.line(team, paid, short)
  local parts = {}
  for _, s in ipairs(paid or {}) do parts[#parts + 1] = string.format("%s %s (%d tuiles)", tostring(s.kind), tostring(s.id), s.len or 0) end
  local text = #parts > 0 and ("montée de palier : " .. table.concat(parts, " puis ")) or "montée de palier : rien à monter"
  local waits = {}
  for _, w in ipairs(short or {}) do waits[#waits + 1] = string.format("%s x%d", tostring(w.item), w.n or 0) end
  if #waits > 0 then text = text .. " ; en attente : " .. table.concat(waits, ", ") end
  return string.format("[FO-CONVOYEURS] %s : %s", tostring(team or "player"), text)
end

return Cs
