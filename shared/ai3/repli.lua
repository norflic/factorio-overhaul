--[[
  Lot CAPI-REPLI (29/10, retour du DC : « le vrai probleme du fer c'est qu'ils ne capitalisent pas assez » ; « si on manque
  cruellement de ressources, l'objectif est ces ressources, pas la defense »). Règle PURE du repli des ordres de
  capitalisation refusés par l'exécutant (plan directeur), testée hors jeu (tests/ai3_capitalisation_test.lua §14).

  Mesuré sur la partie du DC (audit CAPI-AUDIT, T1) : un ordre de fer n'était émis que dans 2 à 5 % des décisions alors que
  des places étaient libres ; Azur est resté 40 min (79,6 à 119,8) sans ordre de fer, 281 places libres, plus de 200
  d'épargne. Cause : l'ancien repli était porté par le PRODUIT (donc par tous les gisements du minerai à la fois), jamais
  remis à zéro (10 × 2^(n-1) min, 40 au plus, n ne faisait que croître) et se déclenchait aussi sur un échec de MATÉRIAUX
  (pénurie : « materiaux introuvables (15 min sans progres) »), c'est-à-dire quand le gisement en avait le plus besoin.

  Règles d'ici (clé = (produit, gisement) ; « produit » est une chaîne opaque, aucun nom du jeu) :
    1. PAR GISEMENT : un refus du plan directeur sur un gisement ne ferme pas les autres gisements du même produit.
    2. n REMIS À ZÉRO quand un module de cette clé est TERMINÉ (Rp.done), et DÉCROISSANT avec le temps (un cran par
       Rp.DECAY sans nouvel échec).
    3. UN ÉCHEC DE MATÉRIAUX NE BLOQUE PAS le gisement : il (a) RÉDUIT la taille du module suivant (facteur 1/2 par échec,
       jusqu'à 1/2^Rp.SHRINK_MAX) et (b) garde les objets qui manquaient en « préparation » (Rp.prep) : le runtime les
       donne au cerveau comme but de fabrication pendant Rp.PREP_TTL.
    4. PLAFOND Rp.MAX_STARVED (5 min) quand la couverture du gisement est sous Rp.COVER_LOW ‰ et que le besoin n'est pas
       servi (opts.kappa, opts.unserved) : on réessaie vite quand on manque de la matière.
  L'état est un livre { [clé] = { n, shrink, last, until_tick, fail_tick, why, prep, prep_until } } de nombres, chaînes et
  tables : il va dans `global` côté runtime. Déterminisme : aucun pairs décisionnel (Rp.prep et Rp.prune trient les clés),
  aucun temps mesuré, aucun hasard.
]]

local Rp = {}

Rp.BASE = 10 * 3600          -- premier repli d'un refus du plan directeur (ticks) : 10 min × 2^(n-1)
Rp.MAX = 40 * 3600           -- au plus 40 min
Rp.MAX_STARVED = 5 * 3600    -- au plus 5 min quand la couverture est basse et le besoin non servi
Rp.COVER_LOW = 500           -- ‰ des tuiles sous une foreuse : « couverture basse »
Rp.DECAY = 30 * 3600         -- un cran de n (et de réduction) de moins par 30 min sans nouvel échec
Rp.SHRINK_MAX = 2            -- réduction du module au plus 1/4 (2 échecs de matériaux de suite)
Rp.PREP_TTL = 20 * 3600      -- les objets manquants restent un but de fabrication 20 min après l'échec
Rp.MATERIAL_MARK = "materiaux introuvables" -- texte de la raison écrite par l'exécutant (Auto.RESERVE_MAX sans progrès)

--- Clé d'un repli : (produit, gisement) ; sans gisement (chaînes, rangées), le produit seul.
function Rp.key(product, deposit)
  if deposit == nil or deposit == "" then return tostring(product) end
  return tostring(product) .. "@" .. tostring(deposit)
end

--- La raison d'un échec est-elle un manque de matériaux (pénurie) et non un refus du plan ?
function Rp.is_material(why)
  return type(why) == "string" and why:find(Rp.MATERIAL_MARK, 1, true) ~= nil
end

--- Valeur d'un compteur (n ou shrink) après décroissance : un cran de moins par Rp.DECAY écoulé depuis le dernier échec.
function Rp.eff(b, tick, field)
  if not b then return 0 end
  local v = b[field] or 0
  if v <= 0 then return 0 end
  local steps = math.floor(math.max(0, tick - (b.last or tick)) / Rp.DECAY)
  return math.max(0, v - steps)
end

--- Couverture basse et besoin non servi : le plafond court s'applique.
function Rp.starved(opts)
  return opts ~= nil and opts.unserved == true and (opts.kappa or 1000) < Rp.COVER_LOW
end

--- Enregistre un échec. `missing` : objets qui manquaient ({ {objet, n}, ... }), pour un échec de matériaux.
--- Rend "materiaux" ou "plan".
function Rp.fail(book, key, why, tick, missing)
  local b = book[key] or { n = 0, shrink = 0, last = tick }
  -- les compteurs sont figés à leur valeur décroissée AVANT de repartir l'horloge de décroissance
  local n0, s0 = Rp.eff(b, tick, "n"), Rp.eff(b, tick, "shrink")
  b.n, b.shrink, b.last, b.why = n0, s0, tick, tostring(why)
  book[key] = b
  if Rp.is_material(why) then
    b.shrink = math.min(Rp.SHRINK_MAX, s0 + 1)
    local keep = {}
    for _, it in ipairs(missing or {}) do
      if type(it) == "table" and it[1] and (it[2] or 0) > 0 then keep[#keep + 1] = { it[1], it[2] } end
    end
    if #keep > 0 then b.prep, b.prep_until = keep, tick + Rp.PREP_TTL end
    return "materiaux"
  end
  b.n = n0 + 1
  b.fail_tick = tick
  b.until_tick = tick + math.min(Rp.MAX, Rp.BASE * 2 ^ (b.n - 1))
  return "plan"
end

--- La clé est-elle en repli ? Rend la raison écrite, ou nil. opts : { kappa (‰ couverts), unserved (besoin non servi) }.
function Rp.held(book, key, tick, opts)
  local b = book[key]
  if not (b and b.until_tick) then return nil end
  local until_t = b.until_tick
  if Rp.starved(opts) then until_t = math.min(until_t, (b.fail_tick or tick) + Rp.MAX_STARVED) end
  if tick >= until_t then return nil end
  return string.format("repli apres %d refus du plan directeur (%s) jusqu'a %.1f min%s", b.n or 0, tostring(b.why), until_t / 3600,
    Rp.starved(opts) and ", plafonne : couverture basse et besoin non servi" or "")
end

--- Facteur de taille du prochain module de cette clé : 1, 1/2 ou 1/4.
function Rp.factor(book, key, tick)
  return 1 / 2 ^ Rp.eff(book[key], tick, "shrink")
end

--- Un module de cette clé est terminé : le repli et la réduction repartent de zéro.
function Rp.done(book, key)
  book[key] = nil
end

--- Objets à fabriquer pour la prochaine tentative : { { key, missing }, ... } triés par clé.
function Rp.prep(book, tick)
  local keys = {}
  for k in pairs(book) do keys[#keys + 1] = k end
  table.sort(keys)
  local out = {}
  for _, k in ipairs(keys) do
    local b = book[k]
    if b.prep and tick < (b.prep_until or 0) then out[#out + 1] = { key = k, missing = b.prep } end
  end
  return out
end

--- Retire les entrées mortes (repli fini, compteurs retombés à zéro, préparation expirée). Rend le nombre retiré.
function Rp.prune(book, tick)
  local keys = {}
  for k in pairs(book) do keys[#keys + 1] = k end
  table.sort(keys)
  local n = 0
  for _, k in ipairs(keys) do
    local b = book[k]
    local live = (b.until_tick and tick < b.until_tick) or (b.prep and tick < (b.prep_until or 0))
      or Rp.eff(b, tick, "n") > 0 or Rp.eff(b, tick, "shrink") > 0
    if not live then book[k] = nil n = n + 1 end
  end
  return n
end

--- Texte court d'une clé pour le journal ([FO-CAPI-COUV]) : « n=1 reduction=1/2 repli jusqu'a 12.0 min », ou "-".
function Rp.describe(book, key, tick, opts)
  local b = book[key]
  if not b then return "-" end
  local parts = {}
  local n, s = Rp.eff(b, tick, "n"), Rp.eff(b, tick, "shrink")
  if n > 0 then parts[#parts + 1] = "n=" .. n end
  if s > 0 then parts[#parts + 1] = "module reduit a 1/" .. (2 ^ s) end
  local h = Rp.held(book, key, tick, opts)
  if h then parts[#parts + 1] = h end
  if b.prep and tick < (b.prep_until or 0) then parts[#parts + 1] = "materiaux en preparation" end
  if #parts == 0 then return "-" end
  return table.concat(parts, " ; ")
end

return Rp
