--[[
  Panneau de statistiques de la partie (lot PANEL-STATS, onglet « Partie » de la fenêtre « Équipe et factions »,
  lot IA1-i) : MODÈLE PUR.
  Lua pur, testable hors jeu (tests/stats_panel_test.lua) : aucun appel au moteur, aucune lecture de `global`, AUCUN
  nom d'objet de jeu (les objets sont des clés opaques : tri par flux, jamais par nom connu).

  Ce que le modèle décide (et rien d'autre) :
    - les RELEVÉS : un anneau borné d'échantillons de compteurs CUMULÉS (production, consommation, objets portés au
      coffre par les PNJ), un relevé toutes les M.PERIOD ticks, M.RING relevés gardés (donc un historique de
      (M.RING - 1) × M.PERIOD ticks) ; chaque relevé ne garde que les M.KEEP.* plus gros objets (état sauvegardé borné) ;
    - les DÉBITS par minute : écart de deux relevés de compteurs (jamais la moyenne du moteur, F242) ;
    - le tri des objets par flux (égalités par clé : déterministe, aucun ordre de `pairs`) ;
    - les décomptes de tâches des PNJ (la somme égale toujours l'effectif vivant) ;
    - le formatage des nombres (virgule décimale, comme M.permille de shared/gui/ia1i.lua : textes FR et EN identiques).
  Aucune décision de jeu n'en dépend : le panneau est en lecture seule.

  Deux sources de production, jamais mélangées (consigne du lot) :
    prod / cons  statistiques de production du moteur de la force (les machines de la force) ;
    hand         compteurs du mod : ce que les PNJ ont porté au coffre (les mains ; le moteur ne compte pas ce que les
                 PNJ minent ou fabriquent à la main, F319).
]]

local M = {}

M.PERIOD = 1800                          -- ticks entre deux relevés (30 s)
M.RING = 7                               -- relevés gardés par équipe (historique de 3 min)
M.KEEP = { prod = 16, cons = 12, hand = 8 } -- objets gardés par relevé
M.SHOWN = 8                              -- objets montrés par tableau
M.TICKS_PER_MIN = 3600

---------------------------------------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------------------------------------
--- Clés d'une table, triées (nombres avant chaînes, sinon ordre naturel).
function M.sorted_keys(t)
  local keys = {}
  for k in pairs(t or {}) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    return a < b
  end)
  return keys
end

--- Somme des valeurs numériques d'une table (clés triées).
function M.sum(t)
  local s = 0
  for _, k in ipairs(M.sorted_keys(t)) do
    local v = t[k]
    if type(v) == "number" then s = s + v end
  end
  return s
end

--- Liste { { name, v }, ... } des n plus grandes valeurs STRICTEMENT positives, décroissantes, égalités par clé.
function M.top(counts, n)
  local list = {}
  for _, k in ipairs(M.sorted_keys(counts)) do
    local v = counts[k]
    if type(v) == "number" and v > 0 then list[#list + 1] = { name = k, v = v } end
  end
  table.sort(list, function(a, b)
    if a.v ~= b.v then return a.v > b.v end
    return a.name < b.name
  end)
  while #list > n do list[#list] = nil end
  return list
end

--- Table { [clé] = valeur } réduite aux n plus grandes valeurs (ce qu'un relevé garde).
function M.trim(counts, n)
  local out = {}
  for _, e in ipairs(M.top(counts, n)) do out[e.name] = e.v end
  return out
end

---------------------------------------------------------------------------------------------------
-- Relevés et débits
---------------------------------------------------------------------------------------------------
--- Relevé : { tick, prod, cons, hand, mined, crafted } construit à partir des compteurs cumulés (tables {objet = n}).
function M.make_sample(tick, prod, cons, hand, mined, crafted)
  return {
    tick = tick,
    prod = M.trim(prod, M.KEEP.prod), cons = M.trim(cons, M.KEEP.cons), hand = M.trim(hand, M.KEEP.hand),
    mined = mined or 0, crafted = crafted or 0,
  }
end

--- Ajoute un relevé à la fin de l'anneau, en gardant les `max` derniers. Un relevé du même tick remplace le dernier
--- (deux demandes dans le même tick ne doublent pas l'historique).
function M.push(ring, sample, max)
  local last = ring[#ring]
  if last and last.tick == sample.tick then
    ring[#ring] = sample
  else
    ring[#ring + 1] = sample
  end
  while #ring > (max or M.RING) do table.remove(ring, 1) end
  return ring
end

--- Débit par minute d'un objet pour le champ `field` (« prod », « cons », « hand ») : écart entre le dernier relevé et
--- le PLUS ANCIEN relevé qui contient l'objet, rapporté à leur durée. nil sans deux relevés (ou durée nulle).
--- Un compteur qui baisse (statistiques remises à zéro) donne 0, jamais un débit négatif.
function M.rate(ring, field, name)
  local last = ring[#ring]
  if not (last and last[field] and last[field][name]) then return nil end
  for i = 1, #ring - 1 do
    local old = ring[i]
    local ov = old[field] and old[field][name]
    if ov then
      local dt = last.tick - old.tick
      if dt <= 0 then return nil end
      local d = last[field][name] - ov
      if d < 0 then d = 0 end
      return d * M.TICKS_PER_MIN / dt
    end
  end
  return nil
end

--- Débit par minute d'un compteur scalaire (« mined », « crafted ») sur toute la fenêtre de l'anneau.
function M.rate_scalar(ring, field)
  local last, first = ring[#ring], ring[1]
  if not (last and first) or last == first then return nil end
  local dt = last.tick - first.tick
  if dt <= 0 then return nil end
  local d = (last[field] or 0) - (first[field] or 0)
  if d < 0 then d = 0 end
  return d * M.TICKS_PER_MIN / dt
end

--- Durée couverte par l'anneau en ticks (0 sans deux relevés).
function M.span(ring)
  if #ring < 2 then return 0 end
  return ring[#ring].tick - ring[1].tick
end

--- Tableau des flux d'un champ : les n premiers objets du DERNIER relevé, triés par débit décroissant (les objets sans
--- débit connu en dernier, par cumul), égalités par clé. Chaque ligne : { name, rate (nil si inconnu), total }.
function M.flows(ring, field, n)
  local last = ring[#ring]
  if not (last and last[field]) then return {} end
  local rows = {}
  for _, k in ipairs(M.sorted_keys(last[field])) do
    rows[#rows + 1] = { name = k, rate = M.rate(ring, field, k), total = last[field][k] }
  end
  table.sort(rows, function(a, b)
    local ra, rb = a.rate, b.rate
    if (ra ~= nil) ~= (rb ~= nil) then return ra ~= nil end
    if ra and ra ~= rb then return ra > rb end
    if a.total ~= b.total then return a.total > b.total end
    return a.name < b.name
  end)
  while #rows > n do rows[#rows] = nil end
  return rows
end

---------------------------------------------------------------------------------------------------
-- PNJ : décompte des tâches
---------------------------------------------------------------------------------------------------
--- Décompte des PNJ par tâche. `npcs` = liste { task = nil | « mine »…, resource = nil | clé } (Poles.status), `alive` =
--- effectif vivant de l'équipe. Les PNJ sans tâche sont « idle » ; ceux qui n'ont pas encore de rôle (absents de
--- `npcs`) sont « norole » : la somme des décomptes VAUT `alive` (si `alive` >= #npcs).
--- Rend { list = { { key, n }, ... } (décroissant, égalités par clé), total, mining = { { key, n }, ... } }.
function M.task_counts(npcs, alive)
  local by, res = {}, {}
  for _, n in ipairs(npcs or {}) do
    local k = n.task or "idle"
    by[k] = (by[k] or 0) + 1
    if n.task == "mine" and n.resource then res[n.resource] = (res[n.resource] or 0) + 1 end
  end
  local listed = #(npcs or {})
  local extra = (alive or listed) - listed
  if extra > 0 then by.norole = extra end
  local function ordered(t)
    local out = {}
    for _, k in ipairs(M.sorted_keys(t)) do out[#out + 1] = { key = k, n = t[k] } end
    table.sort(out, function(a, b)
      if a.n ~= b.n then return a.n > b.n end
      return a.key < b.key
    end)
    return out
  end
  local list = ordered(by)
  local total = 0
  for _, e in ipairs(list) do total = total + e.n end
  return { list = list, total = total, mining = ordered(res) }
end

--- Part de PNJ au travail en pour cent entier, comme l'onglet « Mon équipe » : (n − inactifs) / n, arrondi.
function M.busy_pct(n, idle)
  if not n or n <= 0 then return 0 end
  return math.floor(100 * (n - (idle or 0)) / n + 0.5)
end

---------------------------------------------------------------------------------------------------
-- Formatage (virgule décimale ; textes FR et EN identiques)
---------------------------------------------------------------------------------------------------
local function comma(s) return (s:gsub("%.", ",")) end

--- Entier arrondi, milliers séparés par une espace simple : « 1 234 ».
function M.int(v)
  local n = math.floor((v or 0) + 0.5)
  local neg = n < 0
  local s = tostring(neg and -n or n)
  local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
  return (neg and "-" or "") .. out
end

--- Débit par minute : « 0,5 », « 7,3 », « 120 », « 1,2 k ».
function M.fmt_rate(v)
  if v == nil then return "—" end
  if v < 0 then v = 0 end
  if v < 10 then return comma(string.format("%.1f", v)) end
  if v < 1000 then return tostring(math.floor(v + 0.5)) end
  if v < 1e6 then return comma(string.format("%.1f", v / 1000)) .. " k" end
  return comma(string.format("%.1f", v / 1e6)) .. " M"
end

--- Cumul : entier jusqu'à 99 999, puis « 123 k », « 4,5 M ».
function M.fmt_total(v)
  v = v or 0
  if v < 100000 then return M.int(v) end
  if v < 1e6 then return tostring(math.floor(v / 1000 + 0.5)) .. " k" end
  return comma(string.format("%.1f", v / 1e6)) .. " M"
end

--- Pourcentage entier d'une fraction 0..1 (recherche en cours), borné à 0..100.
function M.pct(x)
  local p = math.floor((x or 0) * 100 + 0.5)
  if p < 0 then return 0 end
  if p > 100 then return 100 end
  return p
end

return M
