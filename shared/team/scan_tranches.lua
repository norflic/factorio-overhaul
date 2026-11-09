--[[
  Lot SCAN-TRANCHES (directive du DC du 9/11) : règles PURES des scans périodiques « time-sliced », anti-freeze.

  Une IMPULSION tombe à chaque multiple T de `period` ticks (18 000 = 5 min). Une équipe de rang r (0, 1, 2… dans l'ordre stable des
  équipes) est active sur la fenêtre [T + r × (slices + gap), T + r × (slices + gap) + slices) : `slices` ticks SUCCESSIFS (20), puis un
  trou de `gap` ticks (40) avant la fenêtre de l'équipe suivante. Deux équipes ne sont donc jamais actives au même tick (test §1).
  Une liste de n éléments relevée au début de la fenêtre est traitée par parts : la tranche s (0..slices-1) prend [a, b] (St.share) ;
  les parts couvrent la liste sans trou ni doublon (test §2).

  Lot SCAN-EVENEMENTS (directive du DC du 9/11, « bannissement du H24 ») : la période passe à 3 min (10 800 ticks) et une impulsion part
  AUSSI sur un RÉVEIL événementiel (recherche débloquée, palier de stock, coupure d'énergie, rupture d'une ressource critique ; déclencheurs :
  script/team/scan_reveil.lua). État par équipe `st` (f.team.scan, données pures) : st.wake = { tick, why, n } (réveil posé, non servi ;
  un second réveil avant service ne fait que compter : une seule passe), st.served = tick de départ de la dernière passe, st.why = sa cause.
    St.due(st, t0, cfg, rank) : une passe est-elle due au départ de fenêtre t0 ? refusée pendant une fenêtre en cours ; « periode » si
      t0 est le départ de la fenêtre périodique du rang ; sinon la cause du réveil posé ; St.ack(st, t0, why) marque la passe servie.
    VOIES DE RÉVEIL : la période est un train de créneaux k = 0, 1, 2… de `stride` ticks ; le créneau k appartient au rang k mod n
      (n équipes). Les créneaux k < n sont les fenêtres périodiques (k = rang) ; les suivants, libres, servent les réveils. Deux rangs
      distincts n'ont jamais le même créneau : une fenêtre de réveil est disjointe de toute autre fenêtre (test §6). Le prochain créneau
      de la voie du rang r est à moins de n × stride ticks (4 équipes : 240 ticks, 4 s) : St.wake_start.
  Ni temps mesuré ni ordre de `pairs` : tout est arithmétique sur le tick. Rien d'autre ici : le moteur (script/team/hygiene.lua) lit le
  monde et journalise.
]]

local St = {}

St.CFG = {
  period = 10800,     -- ticks entre deux impulsions (3 min, directive du DC du 9/11)
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

---------------------------------------------------------------------------------------------------
-- Réveils (lot SCAN-EVENEMENTS) : état `st` = f.team.scan de l'équipe, données pures
---------------------------------------------------------------------------------------------------

--- Pose le réveil `why` (« recherche », « stock », « energie », « ressource ») au tick `tick`. Un réveil déjà posé et non servi est gardé
--- (le premier gagne, le second est compté) : jamais deux passes pour deux réveils rapprochés. Rend vrai si le réveil est nouveau.
function St.wake(st, tick, why)
  if st.wake then
    st.wake.n = (st.wake.n or 1) + 1
    return false
  end
  st.wake = { tick = tick, why = why, n = 1 }
  return true
end

--- Une passe est-elle due au départ de fenêtre `t0` pour l'équipe de rang `rank` ? Rend (vrai, cause) ou (faux, raison).
--- Refusée tant que la dernière passe servie (st.served) a sa fenêtre en cours (pas de double passe) ; « periode » quand t0 est le début
--- de la fenêtre périodique du rang (T + rang × stride, T multiple de period) ; sinon la cause du réveil posé et non servi.
function St.due(st, t0, cfg, rank)
  cfg = cfg or St.CFG
  if st.served and t0 >= st.served and t0 < st.served + cfg.slices then return false, "fenetre en cours" end
  if (t0 - (rank or 0) * St.stride(cfg)) % cfg.period == 0 then return true, "periode" end
  if st.wake then return true, st.wake.why end
  return false, "rien"
end

--- La passe partie au tick `t0` pour la cause `why` est servie : le réveil posé (s'il y en a un) est consommé.
function St.ack(st, t0, why)
  st.served, st.why, st.wake = t0, why or "periode", nil
end

--- (actif, tranche) de la VOIE du rang `rank` parmi `n` équipes au tick `tick` : les créneaux k ≡ rank (mod n) ; la fenêtre périodique
--- (k = rank) en fait partie. Même forme que St.window ; St.window(tick, r) actif implique St.lane(tick, r, n) actif.
function St.lane(tick, rank, n, cfg)
  local k, s = St.rank_at(tick, cfg)
  if k == nil or n == nil or n < 1 or k % n ~= rank then return false, nil end
  return true, s
end

--- Départ de la prochaine fenêtre de réveil du rang `rank` (n équipes) à partir de `tick` : le premier créneau de sa voie dont le début
--- est ≥ tick. Toujours à moins de n × stride ticks ; nil si n < 1.
function St.wake_start(tick, rank, n, cfg)
  cfg = cfg or St.CFG
  if not n or n < 1 then return nil end
  local stride = St.stride(cfg)
  local t = tick + (stride - tick % stride) % stride
  for _ = 1, n do
    local k = math.floor((t % cfg.period) / stride)
    if k % n == rank then return t end
    t = t + stride
  end
  return nil
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
