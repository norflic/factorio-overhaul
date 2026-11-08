--[[
  MESURE DU DÉBIT D'UN MODULE FINI (lot MESURE-MODULE, 8/11/2026). Règle PURE : Lua sans moteur, testée hors jeu
  (tests/mesure_module_test.lua). Le runtime (script/ai3/automatisation.lua, measure_module) ne fait que LIRE les machines
  du module et appliquer ce calcul ; l'état rendu tient dans `m.mm` (nombres et tables seulement, rien d'autre dans global).

  Ce que lisait l'ancienne mesure (somme des products_finished du module, différence d'une minute à l'autre) et ce qui n'allait pas :
    - une montée de niveau (Levels) REMPLACE l'entité : nouveau numéro, products_finished repart de 0 ; la somme baissait,
      math.max(0, …) avalait la minute et le compteur de référence retombait ;
    - une machine absente d'une lecture (détruite, pas encore reposée) puis revenue donnait un creux puis un PIC ;
    - products_finished compte des FABRICATIONS, pas des objets (copper-cable : 2 par fabrication ; lot de recette ×10) ;
    - « 0/min » voulait dire aussi « pas encore de mesure » (aucun projet lu, première lecture après une réouverture) ;
    - tout four du rectangle était compté, quelle que soit sa recette.
  Règle : un compteur par MACHINE (son numéro d'unité), jamais une somme.
    - machine connue : (pf − pf précédent) × objets par fabrication, ramené à la minute (écart de minutes entre deux lectures) ;
    - machine NOUVELLE (numéro jamais vu) : née depuis la dernière lecture, son compteur compte en entier, borné par ce
      qu'elle peut fabriquer (`cap`, objets/min) : une machine adoptée déjà vieille ne fait pas de pic ;
    - machine DISPARUE (remplacée par une montée de niveau, détruite) : elle a travaillé en moyenne la moitié de l'intervalle
      avant de disparaître ; sa part est estimée à la moitié de son débit connu (sans débit connu : 0) ;
    - sans aucune machine lue, ou à la première lecture : PAS DE MESURE (nil), jamais 0.
  Montée de niveau de trois machines sur quatre au milieu d'une minute : débit rendu inchangé (tests, mutants).
]]

local Mm = {}

Mm.VERSION = 1
Mm.CHECK_RATIO = 1.5   -- le contenu des coffres de sortie monte de plus de 1,5 × le débit mesuré (+ Mm.CHECK_SLACK) : écart signalé
Mm.CHECK_SLACK = 2     -- objets/min de tolérance du recoupement avec les coffres

local function num(x)
  return type(x) == "number" and x == x and x > -math.huge and x < math.huge and x or nil
end

local floor = math.floor

--- Arrondi à 0,01 (le débit est un nombre à virgule : on évite des flottants bruyants dans global et dans le journal).
local function round2(x) return floor(x * 100 + 0.5) / 100 end
Mm.round2 = round2

--- Objets par fabrication pour `item` : produits d'une recette { { name, amount, amount_min, amount_max, probability } }.
--- Rend 0 si la recette ne donne pas l'objet. Espérance : (min+max)/2 × probabilité quand la quantité est un intervalle.
function Mm.amount_of(products, item)
  local total = 0
  for _, pr in ipairs(products or {}) do
    if pr.name == item then
      local a = num(pr.amount)
      if not a then
        local lo, hi = num(pr.amount_min), num(pr.amount_max)
        a = (lo and hi) and (lo + hi) / 2 or 1
      end
      local pb = num(pr.probability) or 1
      total = total + a * pb
    end
  end
  return total
end

--- Une lecture de machine : { id (numéro d'unité), pf (products_finished), amount (objets par fabrication, > 0), cap (objets/min
--- au plus, facultatif) }. Rend la liste des lectures valides triées par numéro (déterminisme).
local function clean(readings)
  local out = {}
  for _, r in ipairs(readings or {}) do
    local id, pf, am = num(r.id), num(r.pf), num(r.amount)
    if id and pf and pf >= 0 and am and am > 0 then
      out[#out + 1] = { id = id, pf = pf, amount = am, cap = num(r.cap) }
    end
  end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end

local function ids_sorted(per)
  local ks = {}
  for k in pairs(per or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Pas de mesure (une fois par minute entière `now_min`, compteur de minutes du jeu).
--- state : nil, ou { v, min, per = { [id] = { pf, rate (objets/min, ou nil) } } } rendu par le pas précédent.
--- Rend state', rate (objets/min, arrondi à 0,01 ; nil = PAS ENCORE DE MESURE), info
--- info = { n (machines lues), new, gone, partial (vrai si une part est estimée), why (raison d'un nil), gap (minutes) }.
function Mm.step(state, readings, now_min)
  local rs = clean(readings)
  local info = { n = #rs, new = 0, gone = 0, partial = false }
  now_min = num(now_min) or 0
  if #rs == 0 then
    -- rien lu (projet sans machine, chunk absent, pas de surface) : l'état est gardé, la mesure est inconnue
    info.why = "aucune machine lue"
    return state, nil, info
  end
  local per = {}
  for _, r in ipairs(rs) do per[r.id] = { pf = r.pf, rate = nil } end
  if type(state) ~= "table" or state.v ~= Mm.VERSION or type(state.per) ~= "table" or not num(state.min) then
    info.why = "premiere lecture"
    return { v = Mm.VERSION, min = now_min, per = per }, nil, info
  end
  local gap = now_min - state.min
  if gap < 1 then
    -- même minute : rien à comparer, l'état ne bouge pas
    info.why = "meme minute"
    return state, nil, info
  end
  info.gap = gap
  local total = 0
  local seen = {}
  for _, r in ipairs(rs) do
    local b = state.per[r.id]
    seen[r.id] = true
    if b then
      local d = r.pf - b.pf
      if d < 0 then d = 0; info.anomaly = (info.anomaly or 0) + 1 end
      local made = d * r.amount / gap
      per[r.id].rate = made
      total = total + made
    else
      -- machine née depuis la dernière lecture : son compteur compte en entier, bornée par ce qu'elle peut fabriquer
      local made = r.pf * r.amount
      if r.cap and made > r.cap * gap then made = r.cap * gap; info.capped = (info.capped or 0) + 1 end
      per[r.id].rate = nil
      total = total + made / gap
      info.new = info.new + 1
      info.partial = true
    end
  end
  for _, id in ipairs(ids_sorted(state.per)) do
    if not seen[id] then
      local b = state.per[id]
      info.gone = info.gone + 1
      info.partial = true
      local rt = num(b and b.rate)
      if rt and rt > 0 then total = total + 0.5 * rt end
    end
  end
  return { v = Mm.VERSION, min = now_min, per = per }, round2(total), info
end

--- Somme des compteurs actuels (objets) des machines de l'état : valeur de compatibilité de `m.made_prev` (le suivi de
--- reconstruction, rebuild_sweep.follow, la remet à nil pour demander une nouvelle référence).
function Mm.sentinel(readings)
  local s = 0
  for _, r in ipairs(clean(readings)) do s = s + r.pf * r.amount end
  return s
end

--- Recoupement avec les coffres de sortie. measured : débit mesuré des modules du produit (objets/min, nil si inconnu) ;
--- gain : hausse du contenu des coffres de sortie du produit par minute, SANS les retraits (borne basse du flux : un PNJ qui
--- vide un coffre ne la gonfle pas). Rend "ecart" quand les coffres montent nettement plus vite que la mesure, nil sinon
--- (rien à dire : mesure inconnue, gain non lisible, ou accord à la tolérance près).
function Mm.crosscheck(measured, gain)
  local m, g = num(measured), num(gain)
  if not (m and g) or g <= 0 then return nil end
  if g > m * Mm.CHECK_RATIO + Mm.CHECK_SLACK then return "ecart" end
  return nil
end

return Mm
