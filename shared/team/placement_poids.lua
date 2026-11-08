--[[
  Lot RESEAU-GRAPHE, ajout du DC (8/11 vers 11 h 55) : PLACEMENT PONDÉRÉ d'un module consommateur. Règle PURE : aucune API du jeu, aucun nom
  d'objet ; lue hors jeu (tests/placement_poids_test.lua). Conception : docs/conception/RESEAU_GRAPHE.md §9.

  « Avoir des usines dont l'input est nécessaire, par exemple du fer ou du cuivre, à mi-chemin entre les deux ou disons le plus proche de
  l'un ou de l'autre en fonction du besoin de l'input. Ça évitera de faire de trop longues distances pour remplir des coffres au début
  et même pour relier les ressources vers les usines. »

  Problème de localisation (point de Weber) en distance de Manhattan, celle du plan directeur (shared/team/plan.lua) : choisir, parmi les LOTS
  PERMIS (candidates() de build.lua les donne), celui qui minimise  somme  poids x distance^p  aux sources d'entrée, aux clients de sortie
  et au QG pour ce qui est porté à la main.
    - Une DEMANDE = { w (objets/min), x, y } ou { w, alts = { {x, y}, ... } } : plusieurs sources du même objet, la plus proche compte.
    - p = 1 (défaut, Pp.POWER) : coût proportionnel au travail de transport ; l'optimum est la médiane pondérée, par axe (Pp.point) : il se
      pose SUR la source qui pèse plus de la moitié, et reste à plat entre deux sources de poids égaux (départage : le plus près du QG).
    - p > 1 (p = 2 : barycentre) : une longue distance coûte plus que proportionnellement (danger, tapis coupé : F251) ; l'optimum devient
      intérieur : plus près de la source lourde, sans s'y poser.
  Branchement prévu (non fait ici) : place_module reçoit `opts.simple_lots` = une liste { l, d, k, shared } ; Pp.order range une telle liste
  par ce coût (d = coût), et Pp.point donne le `toward` de P.fit (côté du lot où poser le gabarit).

  Déterminisme : listes triées, égalités départagées (coût, distance au QG, clé), aucun pairs, aucune trigonométrie, aucune horloge.
]]

local Li = require("shared.team.liaison")

local Pp = {}

Pp.POWER = 1
Pp.EPS = 1e-9
Pp.FILL_BATCH = 340 -- objets par trajet de remplissage (Build.QUAI_FILL - Build.QUAI_LOW, comme shared/team/reseau_graphe.lua)

local function manhattan(ax, ay, bx, by) return math.abs(ax - bx) + math.abs(ay - by) end

--- Distance d'une demande à un point : la plus proche de ses sources.
local function dist_to(d, x, y)
  if d.alts then
    local best
    for _, a in ipairs(d.alts) do
      local m = manhattan(x, y, a.x, a.y)
      if not best or m < best then best = m end
    end
    return best or 0
  end
  return manhattan(x, y, d.x, d.y)
end

--- Coût d'un point (x, y) : somme des poids x distance^p.
function Pp.cost(x, y, demands, power)
  local p = power or Pp.POWER
  local total = 0
  for _, d in ipairs(demands) do
    if (d.w or 0) > 0 then total = total + d.w * dist_to(d, x, y) ^ p end
  end
  return total
end

--- Médiane pondérée d'une liste de { c, w } triée : rend (bas, haut) de l'intervalle optimal (égaux sauf poids exactement partagés).
local function wmedian(list, total)
  table.sort(list, function(a, b)
    if a.c ~= b.c then return a.c < b.c end
    return a.i < b.i
  end)
  local half, cum = total / 2, 0
  for i, e in ipairs(list) do
    cum = cum + e.w
    if cum >= half - Pp.EPS then
      if math.abs(cum - half) <= Pp.EPS and list[i + 1] then return e.c, list[i + 1].c end
      return e.c, e.c
    end
  end
  local last = list[#list]
  return last and last.c or 0, last and last.c or 0
end

--- Point de Weber en Manhattan (p = 1) : médiane pondérée par axe. Rend { x, y, x_hi, y_hi, cost } ; (x_hi, y_hi) = autre bout de l'intervalle
--- optimal quand deux demandes pèsent exactement la moitié chacune. Les demandes à plusieurs sources comptent leur première source.
--- Rend nil sans demande de poids positif.
function Pp.point(demands)
  local xs, ys, total = {}, {}, 0
  for i, d in ipairs(demands) do
    if (d.w or 0) > 0 then
      local x, y = d.x, d.y
      if d.alts and d.alts[1] then x, y = d.alts[1].x, d.alts[1].y end
      xs[#xs + 1] = { c = x, w = d.w, i = i }
      ys[#ys + 1] = { c = y, w = d.w, i = i }
      total = total + d.w
    end
  end
  if total <= 0 then return nil end
  local x, x_hi = wmedian(xs, total)
  local y, y_hi = wmedian(ys, total)
  return { x = x, y = y, x_hi = x_hi, y_hi = y_hi, cost = Pp.cost(x, y, demands, 1) }
end

--- Lots rangés du meilleur au pire. lots = { { key, x, y } } (centre du lot), opts = { hub = {x, y}, power }. Départage : coût, distance au QG,
--- clé. Rend une liste de { key, x, y, cost, hub_d, ref = entrée d'origine }.
function Pp.rank(lots, demands, opts)
  local power = opts and opts.power or Pp.POWER
  local hub = opts and opts.hub
  local out = {}
  for _, l in ipairs(lots) do
    out[#out + 1] = { key = l.key, x = l.x, y = l.y, cost = Pp.cost(l.x, l.y, demands, power),
      hub_d = hub and manhattan(l.x, l.y, hub.x, hub.y) or 0, ref = l }
  end
  table.sort(out, function(a, b)
    if math.abs(a.cost - b.cost) > Pp.EPS * math.max(1, math.abs(a.cost)) then return a.cost < b.cost end
    if a.hub_d ~= b.hub_d then return a.hub_d < b.hub_d end
    return a.key < b.key
  end)
  return out
end

--- Liste de candidats de place_module ({ l, d, k, shared }) rangée par ce coût : `xy(c)` rend le centre du lot du candidat. Le champ d de chaque
--- candidat est remplacé par le coût. Rend la nouvelle liste (les mêmes tables).
function Pp.order(cands, demands, xy, opts)
  local lots = {}
  for i, c in ipairs(cands) do
    local x, y = xy(c)
    lots[i] = { key = c.k or tostring(i), x = x, y = y, c = c }
  end
  local out = {}
  for _, r in ipairs(Pp.rank(lots, demands, opts)) do
    r.ref.c.d = r.cost
    out[#out + 1] = r.ref.c
  end
  return out
end

--- Demandes d'un module : entrées (objet -> débit, source(s) donnée(s) par where_in(objet) = liste { x, y } ou nil : le QG, porté à la main),
--- sorties (objet -> débit, clients donnés par where_out(objet) ou nil : le QG). opts = { unit (facteur de débit, 60 pour passer des /s aux /min),
--- out_factor (poids relatif d'un objet sorti, défaut 1) }. Rend la liste triée par (entrées d'abord, objet).
function Pp.demands(inputs, outputs, where_in, where_out, hub, opts)
  local unit = opts and opts.unit or 1
  local ofac = opts and opts.out_factor or 1
  local out = {}
  local function add(map, where, kind, factor)
    local names = {}
    for name in next, map or {} do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
      local w = map[name] * unit * factor
      if w > 0 then
        local at = where and where(name) or nil
        local d = { w = w, item = name, kind = kind }
        if at and #at > 0 then
          if #at == 1 then d.x, d.y = at[1].x, at[1].y else d.alts = at; d.x, d.y = at[1].x, at[1].y end
        else
          d.x, d.y = hub.x, hub.y
        end
        out[#out + 1] = d
      end
    end
  end
  add(inputs, where_in, "in", 1)
  add(outputs, where_out, "out", ofac)
  return out
end

--- Coût en PNJ-secondes par minute d'un coût (objets/min x tuiles) : un aller-retour par lot de remplissage (comme Li.worth).
function Pp.pnj_s_min(cost)
  return cost * 2 / Li.WALK / Pp.FILL_BATCH
end

--- Le placement actuel (le lot le plus proche d'UN point `toward`, build.lua candidates()) contre le placement pondéré. Rend
--- { old = rang, new = rang, saving (coût), saving_pct, saving_pnj_s_min }.
function Pp.compare(lots, demands, baseline, opts)
  local power = opts and opts.power or Pp.POWER
  local old
  for _, l in ipairs(lots) do
    local d = manhattan(l.x, l.y, baseline.x, baseline.y)
    if not old or d < old.d or (d == old.d and l.key < old.key) then old = { key = l.key, x = l.x, y = l.y, d = d } end
  end
  local ranked = Pp.rank(lots, demands, opts)
  local new = ranked[1]
  if not old or not new then return nil end
  local old_cost = Pp.cost(old.x, old.y, demands, power)
  local saving = old_cost - new.cost
  return { old = { key = old.key, cost = old_cost }, new = { key = new.key, cost = new.cost }, saving = saving,
    saving_pct = old_cost > 0 and 100 * saving / old_cost or 0, saving_pnj_s_min = Pp.pnj_s_min(saving) }
end

return Pp
