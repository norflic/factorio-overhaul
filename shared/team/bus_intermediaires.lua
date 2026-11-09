--[[
  Lot BUS-INTERMEDIAIRES (directive du DC du 9/11) : « élargir le bus principal aux intermédiaires clés : dès que le fer et le cuivre circulent
  (phase mid), tirer des lignes d'engrenages, de circuits et d'acier qui alimentent les malls et ateliers par piquage au lieu de micro-usines
  isolées ; zéro blocage : si un intermédiaire manque sur le bus, le mall accepte l'artisanat local du composant en repli. »

  Règle PURE : aucune API Factorio, AUCUN nom d'objet (les intermédiaires pivots sont DÉDUITS du graphe des recettes par le lot RECIPE-SOLVER :
  `Solver.hubs(s, demands, k)` rend { { item, rate, machines } } triés par débit décroissant ; ce fichier ne reçoit que cette liste). Testée hors
  jeu : tests/bus_intermediaires_test.lua (mutants compris).

  Ce que le fichier décide :
    (a) Bi.lines(hubs, phase, cfg) : les LIGNES d'intermédiaires à ouvrir. En phase "mid" ou "late" : les cfg.k premiers hubs dont le besoin vaut
        au moins cfg.min_machines machine entière (le débit minimal est DÉRIVÉ de là : rien d'écrit en objets/min), chacun avec son nombre de
        rangées = ⌈machines ÷ cfg.machines_par_rangee⌉. En early : liste vide (jamais nil). Triées (débit décroissant, nom) : l'ordre d'entrée
        ne compte pas.
    (b) Bi.fallback(line_state, cfg) : le mall doit-il accepter la fabrication À LA MAIN de l'intermédiaire ? Oui quand la ligne est absente,
        pas finie, ou que son coffre de sortie est vide depuis cfg.empty_releves relevés de suite (zéro blocage) ; non quand la ligne sert.
        line_state = { present, done, empty_releves } (nombres et booléens : écrit par le runtime, script/ai3/industrie.lua).
    (c) Le bus (script/team/bus.lua) : Bi.order_buses met DEVANT les bus dont l'objet est un hub, par débit du hub décroissant (le bonus de
        priorité est le débit lui-même, pas une constante) ; Bi.link_ok compte les liaisons d'intermédiaires À PART (plafond Bi.CFG.k) : le plafond
        Bus.MAX_LINKS des autres liaisons ne les arrête pas, et réciproquement.
    (d) Le mall (script/ai3/industrie.lua) : Bi.order_cands met devant les décisions dont un objet est un hub ; Bi.empty_count tient le compte des
        relevés sans production.
  Déterminisme : listes triées avec départage par nom, entiers, aucun `pairs` décisionnel, aucune horloge, aucune fonction dans l'état.
]]

local P = require("shared.team.patrons")

local Bi = {}

Bi.SRC = "bus"  -- source d'une demande notée par Ml.want (Ml.sources, Id.merge : srcs)

Bi.CFG = {
  k = 3,                            -- lignes d'intermédiaires ouvertes au plus (et liaisons de bus d'intermédiaires, comptées à part)
  min_machines = 1,                 -- une machine ENTIÈRE au moins : le débit minimal en découle (machines = débit ÷ débit d'une machine)
  machines_par_rangee = P.MAX_N,    -- machines d'une rangée au plus (le gabarit des rangées, shared/team/patrons.lua)
  empty_releves = 3,                -- relevés de suite d'un coffre de sortie vide (ligne finie) avant le repli à la main
}
Bi.EPS = 1e-9

local function num(x)
  if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then return 0 end
  return x
end

local function cfg_of(cfg)
  cfg = cfg or {}
  return {
    k = math.max(0, math.floor(num(cfg.k ~= nil and cfg.k or Bi.CFG.k))),
    min_machines = cfg.min_machines ~= nil and num(cfg.min_machines) or Bi.CFG.min_machines,
    min_rate = num(cfg.min_rate),
    machines_par_rangee = math.max(1, num(cfg.machines_par_rangee ~= nil and cfg.machines_par_rangee or Bi.CFG.machines_par_rangee)),
    empty_releves = math.max(1, num(cfg.empty_releves ~= nil and cfg.empty_releves or Bi.CFG.empty_releves)),
  }
end

--- La phase ouvre-t-elle des lignes d'intermédiaires ? (mid ou late ; early et toute autre valeur : non)
function Bi.phase_ok(phase)
  return phase == "mid" or phase == "late"
end

--- (a) hubs = { { item, rate (objets/min), machines } } (Solver.hubs) ; phase = Dt.phase ; cfg (facultatif) = clés de Bi.CFG, et min_rate
--- (objets/min, facultatif : un seuil de plus, jamais à la place des machines). Rend la liste triée { { item, rate, machines, rows } }.
function Bi.lines(hubs, phase, cfg)
  local out = {}
  if not Bi.phase_ok(phase) then return out end
  local c = cfg_of(cfg)
  local cands = {}
  for _, h in ipairs(hubs or {}) do
    local rate, m = num(h.rate), num(h.machines)
    if type(h.item) == "string" and m + Bi.EPS >= c.min_machines and rate > c.min_rate and rate > 0 then
      cands[#cands + 1] = { item = h.item, rate = rate, machines = m }
    end
  end
  table.sort(cands, function(a, b)
    if a.rate ~= b.rate then return a.rate > b.rate end
    return a.item < b.item
  end)
  for i = 1, math.min(c.k, #cands) do
    local l = cands[i]
    l.rows = math.max(1, math.ceil(l.machines / c.machines_par_rangee - Bi.EPS))
    out[#out + 1] = l
  end
  return out
end

--- Débits des hubs par objet : { [item] = rate } (ensemble lu par le bus et le mall ; les sommes seules, l'ordre n'a aucun effet).
function Bi.hub_rates(lines)
  local out = {}
  for _, l in ipairs(lines or {}) do out[l.item] = num(l.rate) end
  return out
end

--- (b) Repli : rend (vrai = la main est permise, cause). line_state absent ou ligne absente : vrai (zéro blocage).
function Bi.fallback(ls, cfg)
  local c = cfg_of(cfg)
  if type(ls) ~= "table" or ls.present ~= true then return true, "ligne absente" end
  if ls.done ~= true then return true, "ligne pas finie" end
  local n = num(ls.empty_releves)
  if n >= c.empty_releves then return true, string.format("coffre de sortie vide depuis %d releves", math.floor(n)) end
  return false, "ligne servie"
end

--- Compte des relevés de suite sans production : remis à zéro dès qu'une machine a produit (produced vrai), sinon +1.
function Bi.empty_count(prev, produced)
  if produced then return 0 end
  return math.floor(num(prev)) + 1
end

--- Ordre d'une liste dont chaque élément porte un objet (`item_of(e)` rend l'objet, ou une liste d'objets) : les éléments dont un objet est un
--- hub d'abord, par débit du hub décroissant puis rang d'origine ; les autres ensuite, dans leur ordre. Liste neuve.
local function order_by_hubs(list, hubs, item_of)
  hubs = hubs or {}
  local first, rest = {}, {}
  for i, e in ipairs(list or {}) do
    local best = nil
    local its = item_of(e)
    if type(its) ~= "table" then its = { its } end
    for _, it in ipairs(its) do
      local r = it ~= nil and hubs[it] or nil
      if r ~= nil and (best == nil or num(r) > best) then best = num(r) end
    end
    if best ~= nil then first[#first + 1] = { e = e, bonus = best, i = i } else rest[#rest + 1] = e end
  end
  table.sort(first, function(a, b)
    if a.bonus ~= b.bonus then return a.bonus > b.bonus end
    return a.i < b.i
  end)
  local out = {}
  for _, x in ipairs(first) do out[#out + 1] = x.e end
  for _, e in ipairs(rest) do out[#out + 1] = e end
  return out
end

--- (c) Bus (Rg.result : { item, ... }) : ceux d'un hub devant, par débit du hub décroissant. hubs = Bi.hub_rates.
function Bi.order_buses(buses, hubs)
  return order_by_hubs(buses, hubs, function(b) return b.item end)
end

--- (d) Décisions du mall (Id.order : { items = { ... } }) : celles dont un objet est un hub devant.
function Bi.order_cands(cands, hubs)
  return order_by_hubs(cands, hubs, function(c) return c.items or {} end)
end

--- Liaisons de bus ouvertes ou finies, comptées à part : { hubs = n, autres = n }. links = { [clé] = { bus, item, done } } (clés triées :
--- des sommes, l'ordre n'a aucun effet).
function Bi.count_links(links, hubs)
  local out = { hubs = 0, autres = 0 }
  hubs = hubs or {}
  local keys = {}
  for k in next, links or {} do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do
    local l = links[k]
    if type(l) == "table" and l.bus then
      if l.item ~= nil and hubs[l.item] ~= nil then out.hubs = out.hubs + 1 else out.autres = out.autres + 1 end
    end
  end
  return out
end

--- Une liaison de bus de plus pour cet objet est-elle permise ? Hub : moins de cfg.k liaisons d'intermédiaires ; autre objet : moins de max_links
--- autres liaisons. Rend (permise, cause).
function Bi.link_ok(counts, item, hubs, max_links, cfg)
  local c = cfg_of(cfg)
  counts = counts or { hubs = 0, autres = 0 }
  if item ~= nil and (hubs or {})[item] ~= nil then
    if num(counts.hubs) < c.k then return true, "intermediaire" end
    return false, string.format("%d liaison(s) d'intermediaire sur %d", math.floor(num(counts.hubs)), c.k)
  end
  if num(counts.autres) < num(max_links) then return true, "" end
  return false, string.format("%d liaison(s) sur %d", math.floor(num(counts.autres)), math.floor(num(max_links)))
end

--- Ligne du journal [FO-MALL] (aucune décision ne la lit).
function Bi.describe(lines, fallback)
  local parts = {}
  for _, l in ipairs(lines or {}) do
    parts[#parts + 1] = string.format("%s %d rangee(s) (%.1f/min, %.1f machine(s)%s)", l.item, l.rows or 0, l.rate or 0, l.machines or 0,
      (fallback or {})[l.item] and ", main permise" or "")
  end
  return #parts > 0 and table.concat(parts, " ; ") or "aucune"
end

return Bi
