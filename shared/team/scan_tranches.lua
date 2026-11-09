--[[
  Lot SCAN-TRANCHES (directive du DC du 9/11) : règles PURES des scans périodiques « time-sliced », anti-freeze.

  Une IMPULSION tombe à chaque multiple T de `period` ticks (18 000 = 5 min). Une équipe de rang r (0, 1, 2… dans l'ordre stable des
  équipes) est active sur la fenêtre [T + r × (slices + gap), T + r × (slices + gap) + slices) : `slices` ticks SUCCESSIFS (20), puis un
  trou de `gap` ticks (40) avant la fenêtre de l'équipe suivante. Deux équipes ne sont donc jamais actives au même tick (test §1).
  Une liste de n éléments relevée au début de la fenêtre est traitée par parts : la tranche s (0..slices-1) prend [a, b] (St.share) ;
  les parts couvrent la liste sans trou ni doublon (test §2).

  Ni temps mesuré ni ordre de `pairs` : tout est arithmétique sur le tick. Rien d'autre ici : le moteur (script/team/hygiene.lua) lit le
  monde et journalise.
]]

local St = {}

St.CFG = {
  period = 18000,     -- ticks entre deux impulsions (5 min)
  slices = 20,        -- tranches (ticks successifs) de la fenêtre d'une équipe
  gap = 40,           -- ticks de repos entre la fenêtre d'une équipe et celle de la suivante
  max_per_slice = 40, -- éléments traités au plus par tranche (garde ; le reste de la part est reporté, compté, jamais traité ici)
}

--- Longueur du pas d'une équipe à la suivante (fenêtre + repos).
function St.stride(cfg)
  cfg = cfg or St.CFG
  return cfg.slices + cfg.gap
end

--- Tick T de l'impulsion en cours (le dernier multiple de period ≤ tick).
function St.pulse_start(tick, cfg)
  cfg = cfg or St.CFG
  return tick - (tick % cfg.period)
end

--- (rang, tranche) de L'équipe active au tick `tick`, ou nil si aucune (repos ou hors de toute fenêtre).
--- rang = quotient de la phase par le pas ; tranche = reste, valable seulement sous `slices`.
function St.rank_at(tick, cfg)
  cfg = cfg or St.CFG
  local phase = tick % cfg.period
  local stride = St.stride(cfg)
  local slice = phase % stride
  if slice >= cfg.slices then return nil end
  return math.floor(phase / stride), slice
end

--- (actif, tranche 0..slices-1) pour l'équipe de rang `rank` au tick `tick`. Tranche nil quand inactif.
function St.window(tick, rank, cfg)
  local r, s = St.rank_at(tick, cfg)
  if r ~= rank then return false, nil end
  return true, s
end

--- Bornes [a, b] (indices 1..n, b < a : part vide) de la part d'une liste de n éléments traitée à la tranche `slice` (0..slices-1).
--- Les `slices` parts se suivent sans trou ni doublon et leurs tailles diffèrent d'au plus 1.
function St.share(n, slice, slices)
  local a = math.floor(n * slice / slices) + 1
  local b = math.floor(n * (slice + 1) / slices)
  return a, b
end

--- Part plafonnée à `max` éléments : rend a, b' et le nombre d'éléments de la part qui ne seront PAS traités (b - b').
function St.share_capped(n, slice, slices, max)
  local a, b = St.share(n, slice, slices)
  local b2 = b
  if max and b - a + 1 > max then b2 = a + max - 1 end
  return a, b2, b - b2
end

--- Le carré d'alimentation d'un poteau en (px, py), de demi-côté d (supply_area_distance), touche-t-il la boîte { x0, y0, x1, y1 } ?
--- Intervalles ouverts : une boîte qui ne fait que toucher le bord n'est pas alimentée (comme le moteur).
function St.covers(px, py, d, x0, y0, x1, y1)
  return x1 > px - d and x0 < px + d and y1 > py - d and y0 < py + d
end

--- Emprise en TUILES ENTIÈRES d'une boîte de collision (un poteau 1 × 1 a une boîte de 0,3 de côté : sa tuile est floor/ceil) ;
--- rétrécie de `eps` pour ne pas toucher les entités des tuiles voisines. Rend x0, y0, x1, y1.
function St.tile_box(x0, y0, x1, y1, eps)
  eps = eps or 0.05
  return math.floor(x0) + eps, math.floor(y0) + eps, math.ceil(x1) - eps, math.ceil(y1) - eps
end

--- Taille d'une boîte de chunks { x0, y0, x1, y1 } (bornes comprises) en chunks : le coût déclaré au jeton des travaux lourds.
function St.box_cost(box)
  if not box then return nil end
  return (box.x1 - box.x0 + 1) * (box.y1 - box.y0 + 1)
end

return St
