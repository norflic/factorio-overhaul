--[[
  Lot DETOUR-BOUCLE (retour du DC sur 0.6.18, point 3 : « Ils font détour, détour, détour en boucle (mais au même endroit)
  et donc tournent un peu sur eux-même ») : MÉMOIRE DES DÉTOURS d'un PNJ et des buts où il a tourné en rond. PUR : aucune
  API Factorio, testable hors jeu (tests/detour_boucle_test.lua).

  Mécanisme de la boucle (cause, RAPPORT du lot) : la réaction (shared/ai3/reaction.lua, Re.decide) demande un « détour »
  pour une menace fixe CONNUE à moins de portée + Re.MARGIN (8) du reste du trajet ou du but, alors que l'itinéraire et la
  porte acceptent un trajet ou un but au-delà de portée + D.EXACT_MARGIN (4) (shared/ai3/danger.lua). Un détour = un nouvel
  itinéraire vers le MÊME but, donc le même trajet : détour sans fin, au même endroit (sortie de zone, retour, détour...).
  Les détours devant une menace fixe n'étaient comptés nulle part (seuls ceux devant des unités : a.urep).

  Série de détours d'un PNJ : mem = { x, y (lieu du premier détour de la série), gx, gy (but), n, t0, t (dernier) } | nil.
  Même série : même but (à 1 tuile près), à moins de Dt.NEAR tuiles du lieu du premier détour, moins de Dt.WINDOW ticks
  après le précédent. Au-delà de Dt.MAX détours dans la même série : BOUCLE (le PNJ ne progresse plus).

  Échecs par but (équipe) : tab = { [clé de case de 16 tuiles du but] = { u = tick de fin, x, y, t, n } }, Dt.FAIL_MAX au
  plus (la plus ancienne part ; clés triées : aucun ordre de pairs). Lu par la porte (script/ai3/comportement.lua, M.gate).
]]

local D = require("shared.ai3.danger")

local Dt = {}

Dt.NEAR = 16          -- tuiles : « au même endroit »
Dt.WINDOW = 1800      -- ticks (30 s) entre deux détours de la même série, au plus
Dt.MAX = 3            -- détours permis dans la même série ; le suivant casse la boucle
Dt.FAIL_TICKS = 18000 -- 5 min : un but où un PNJ a tourné en rond est refusé par la porte (autre tâche, autre site)
Dt.FAIL_MAX = 32

local function same_goal(m, g)
  if not g then return m.gx == nil end
  if m.gx == nil then return false end
  local dx, dy = m.gx - g.x, m.gy - g.y
  return dx * dx + dy * dy <= 1
end

--- Un détour de plus en p (position du PNJ) vers goal (but final, ou nil) au tick `tick`. Rend la série (nouvelle ou
--- prolongée). La table rendue est neuve quand la série recommence.
function Dt.note(mem, p, goal, tick)
  if mem and same_goal(mem, goal) and tick - mem.t <= Dt.WINDOW then
    local dx, dy = p.x - mem.x, p.y - mem.y
    if dx * dx + dy * dy <= Dt.NEAR * Dt.NEAR then
      mem.n, mem.t = mem.n + 1, tick
      return mem
    end
  end
  return { x = p.x, y = p.y, gx = goal and goal.x or nil, gy = goal and goal.y or nil, n = 1, t0 = tick, t = tick }
end

--- La série est-elle une boucle ?
function Dt.loop(mem)
  return mem ~= nil and mem.n > Dt.MAX
end

function Dt.key(x, y) return D.key(D.cell(x), D.cell(y)) end

--- Échec d'un but (x, y) au tick `tick` : refusé pendant Dt.FAIL_TICKS. Rend l'entrée.
function Dt.fail(tab, x, y, tick)
  local k = Dt.key(x, y)
  local old = tab[k]
  if not old then
    local keys = {}
    for kk in pairs(tab) do keys[#keys + 1] = kk end
    if #keys >= Dt.FAIL_MAX then
      table.sort(keys)
      local oldest = keys[1]
      for _, kk in ipairs(keys) do if tab[kk].t < tab[oldest].t then oldest = kk end end
      tab[oldest] = nil
    end
  end
  local e = { u = tick + Dt.FAIL_TICKS, x = x, y = y, t = tick, n = (old and old.n or 0) + 1 }
  tab[k] = e
  return e
end

--- Le but (x, y) est-il refusé au tick `tick` (échec de moins de Dt.FAIL_TICKS) ? Rend l'entrée ou nil.
function Dt.failed(tab, x, y, tick)
  if not tab then return nil end
  local e = tab[Dt.key(x, y)]
  if e and tick < e.u then return e end
  return nil
end

--- Issue d'une boucle cassée : "abandon" (le PNJ va vers le but d'une tâche : demi-tour, tâche rendue, but refusé
--- Dt.FAIL_TICKS) ou "suivre" (retour au QG, ou sans tâche : il suit son itinéraire sans plus de détour vers ce but).
function Dt.outcome(has_task, step_kind)
  if has_task and step_kind == "goto" then return "abandon" end
  return "suivre"
end

return Dt
