--[[
  Lot RESEAU-GRAPHE, suite de l'audit (décision de l'intégrateur, 8/11) : DIMENSIONNEMENT DU QUAI D'ENTRÉE par le débit. Règle PURE : aucune API
  du jeu, aucun nom d'objet (les bras viennent de M.ARMS, rangés du plus lent au plus rapide, lus dans les données de modules.lua) ; lue hors
  jeu (tests/quai_debit_test.lua). Conception : docs/conception/RESEAU_GRAPHE.md §10.

  Défaut constaté par l'audit (shared/team/blocs_audit.lua) : P.feeder pose UN bras de base par objet et par port tapis (0,83/s, 0,75/s avec la
  marge de 10 %), quel que soit le débit de la recette : 21 gabarits sur 51 en écart. Les sorties, elles, choisissent leur bras par le débit
  (build.lua out_arms). Cette règle fait de même pour les entrées :
    1. Qd.arm_for : le bras le plus lent des données, en 1 ou 2 exemplaires par voie, qui porte le débit d'une voie (M.choose_inserters, du
       coffre au tapis : sans le coefficient de prise sur tapis) ; sinon le plus rapide, en 2 exemplaires.
    2. Qd.max_n : si même cela ne suffit pas, le paramètre d'extension du gabarit (n) est borné à ce que le quai porte (le débit d'entrée est
       proportionnel à n) ; un minerai servi par tapis de foreuses (skip) n'est pas jugé.
    3. Qd.cap : débit réel d'une entrée (objets/s) = nombre de ports x bras x cadence x marge ; Li.worth lit min(nominal, cap).
  Déterminisme : listes triées, aucun pairs, aucune horloge.
]]

local Qd = {}

Qd.MAX_ARMS = 2 -- bras au plus par voie d'entrée (profondeur 3 de la tête d'alimentation, P.FEED_DEPTH)
Qd.ORE_BELT_FLOW = 1.0 -- objets/s : au-delà, un minerai est servi par foreuses et tapis (P.AUTO_FLOW, build.lua plan_feed)

local function sorted_set(set)
  local out = {}
  for k in next, set do out[#out + 1] = k end
  table.sort(out)
  return out
end

--- Ports tapis d'entrée du gabarit g : pour chaque objet servi par QUAI, le nombre de sources (une par port, un objet présent sur les deux
--- voies d'un port compte une fois : build.lua plan_feed). skip(objet) -> vrai : servi autrement (foreuses et tapis), non jugé.
function Qd.sources(g, skip)
  local n = {}
  for _, p in ipairs(g.ports or {}) do
    if p.kind == "tapis" and p.io == "in" and p.lanes then
      local seen = {}
      for lane = 1, 2 do
        local it = p.lanes[lane]
        if it and not seen[it] and not (skip and skip(it)) then seen[it] = true; n[it] = (n[it] or 0) + 1 end
      end
    end
  end
  return n
end

--- Fonction « servi autrement » de build.lua plan_feed : un minerai (M.ORES) dont le débit d'entrée atteint Qd.ORE_BELT_FLOW est servi par
--- foreuses et tapis (sauf feed = "quai" : passer `quai_only`), jamais par quai.
function Qd.skip(M, g, quai_only)
  return function(it)
    return not quai_only and M.ORES[it] ~= nil and ((g.inputs or {})[it] or 0) >= Qd.ORE_BELT_FLOW
  end
end

--- Débit d'une voie par objet (objets/s) : débit d'entrée du gabarit divisé par le nombre de ses sources.
function Qd.lane_flows(g, skip)
  local src, out = Qd.sources(g, skip), {}
  for _, it in ipairs(sorted_set(src)) do out[it] = ((g.inputs or {})[it] or 0) / src[it] end
  return out
end

--- Capacité d'une voie servie par `count` bras `name` (objets/s), marge comprise.
function Qd.arm_cap(M, name, count)
  return M.spec(name).rate * M.MARGIN * count
end

--- Bras du quai pour un débit de voie `flow` (objets/s) : rend nom, nombre (1 à Qd.MAX_ARMS), tenu (vrai si la voie suit). Du coffre au tapis.
function Qd.arm_for(M, flow, max_arms, usable)
  local arms = usable or M.ARMS or {} -- lot RECHERCHE-BRAS : `usable` = bras obtenables du gabarit (g.arms) ; nil : tous
  local name, count = M.choose_inserters(flow, false, math.min(max_arms or Qd.MAX_ARMS, Qd.MAX_ARMS), arms)
  if name then return name, count, true end
  return arms[#arms] or M.ELECTRIC_ARM, math.min(max_arms or Qd.MAX_ARMS, Qd.MAX_ARMS), false
end

--- Plan du quai d'un gabarit : { arm, count, flow (plus gros débit de voie), ok, caps = { [objet] = débit tenu (objets/s) } }.
function Qd.plan(M, g, skip, max_arms)
  local flows = Qd.lane_flows(g, skip)
  local top = 0
  for _, it in ipairs(sorted_set(flows)) do if flows[it] > top then top = flows[it] end end
  local name, count, ok = Qd.arm_for(M, top, max_arms, g.arms)
  local src, caps = Qd.sources(g, skip), {}
  local cap = Qd.arm_cap(M, name, count)
  for _, it in ipairs(sorted_set(src)) do caps[it] = cap * src[it] end
  return { arm = name, count = count, flow = top, ok = ok, caps = caps }
end

--- Plus grand n (paramètre d'extension, 1 à celui du gabarit) dont toutes les voies tiennent avec le meilleur quai ; rend n, gabarit. `cur` =
--- valeur actuelle. Le gabarit est refait par M.extend ; n = cur si tout tient d'emblée.
function Qd.max_n(M, g, skip, max_arms)
  local ex = g.extensions and g.extensions[1]
  if not ex then return nil, g end
  local cur = g.args[ex.arg]
  local function fits(h)
    return Qd.plan(M, h, skip, max_arms).ok
  end
  if fits(g) then return cur, g end
  local flows = Qd.lane_flows(g, skip)
  local top = 0
  for _, it in ipairs(sorted_set(flows)) do if flows[it] > top then top = flows[it] end end
  local arms = g.arms or M.ARMS
  local best = Qd.arm_cap(M, arms[#arms], math.min(max_arms or Qd.MAX_ARMS, Qd.MAX_ARMS))
  local n = math.max(1, math.floor(cur * best / top + 1e-9))
  while n >= 1 do
    local h = n == cur and g or M.extend(g, n)
    if h and fits(h) then return n, h end
    if n == 1 then return 1, h or g end
    n = n - 1
  end
  return 1, g
end

return Qd
