--[[
  TREILLIS (lot INDUSTRIE I3, 31/10) : jusqu'où le treillis grandit pour atteindre un gisement, et pourquoi un plan est refusé quand
  il ne l'atteint pas. Règles PURES : aucune API Factorio, aucun nom d'objet (tests/treillis_test.lua).

  Constats du journal du DC (0.6.27) : « gisement : cuivre hors du treillis » 2 566 refus, « tapis des foreuses » 1 821. Le plafond du
  rayon (Build.RADIUS_MAX = 5, 154 tuiles de demi-côté) n'est pas le seul mur : un refus « hors du treillis » se répétait aussi
  sans que le treillis grandisse jamais, ou grandissait d'un anneau à chaque refus sans savoir s'il y avait quelque chose à
  atteindre. La règle sonde d'abord les anneaux de lots au-delà du treillis (un minerai s'y trouve-t-il ?), puis fait grandir
  d'UN coup jusqu'à lui, ou refuse avec une CAUSE écrite.

  Tr.decide(s)            -> { cause, action, radius } : "ok", "grandir", "sonder", "attendre" ou "refuser".
  Tr.grow_target(far, …)  -> rayon qui contient un gisement dont le centre est à `far` tuiles du QG (cerveau, qui connaît le site).
  Tr.ring_bands(k)        -> bandes de lots (indices) de l'anneau k ; le moteur y compte le minerai.
  Tr.chunks(x0, y0, x1, y1) -> chunks que couvre un rectangle de tuiles (un lot lointain n'est relevé que si tous sont générés).
  Tr.line(t)              -> ligne de journal [FO-TREILLIS].
  Déterminisme : aucune table parcourue par pairs, aucun temps mesuré.
]]

local Tr = {}

Tr.CAP = 12               -- rayon (en lots) au plus de la croissance vers un gisement : 25 × 25 lots, 700 tuiles de côté
Tr.MARGIN_PROBE = 1       -- anneaux gardés au-delà du premier anneau où la sonde trouve du minerai (son cœur est plus loin)
Tr.PROBE_EVERY = 3600     -- ticks entre deux sondes du même minerai (les chunks se génèrent : « rien » peut changer)
Tr.RETRY_UNGEN = 1800     -- ticks entre deux nouveaux essais d'un lot dont un chunk n'est pas généré
Tr.CHUNK = 32

local floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs

--- Anneau (distance de Tchebychev, en lots) du lot (i, j).
function Tr.ring(i, j) return max(abs(i), abs(j)) end

--- Anneau du lot qui contient le point (x, y), pour un treillis ancré en (ox, oy) de pas `pitch`.
function Tr.ring_of_point(ox, oy, x, y, pitch)
  return floor(max(abs(x - ox), abs(y - oy)) / pitch + 0.5)
end

--- Rayon qui contient un gisement dont le centre est à `far` tuiles (Tchebychev) du QG : celui que le cerveau demande à
--- Build.grow quand il ouvre un site. Jamais plus que `cap`. `margin` : anneaux de plus (0 par défaut, le centre est connu).
function Tr.grow_target(far, pitch, cap, margin)
  return min(cap or Tr.CAP, ceil(far / pitch) + (margin or 0))
end

--- Rayon à partir duquel un gisement est « hors du plan directeur » : celui que l'enceinte a figé, sinon le plafond.
function Tr.reach_radius(enc_r, cap) return enc_r or cap or Tr.CAP end

--- Bandes de lots de l'anneau k, en indices { i0, j0, i1, j1 } (bornes incluses) : bords nord et sud en entier, bords ouest et est
--- sans les coins. L'anneau 0 est le lot du QG.
function Tr.ring_bands(k)
  if k <= 0 then return { { i0 = 0, j0 = 0, i1 = 0, j1 = 0 } } end
  local out = {
    { i0 = -k, j0 = -k, i1 = k, j1 = -k },
    { i0 = -k, j0 = k, i1 = k, j1 = k },
  }
  if k >= 2 then
    out[#out + 1] = { i0 = -k, j0 = -k + 1, i1 = -k, j1 = k - 1 }
    out[#out + 1] = { i0 = k, j0 = -k + 1, i1 = k, j1 = k - 1 }
  else
    out[#out + 1] = { i0 = -1, j0 = 0, i1 = -1, j1 = 0 }
    out[#out + 1] = { i0 = 1, j0 = 0, i1 = 1, j1 = 0 }
  end
  return out
end

--- Anneaux à sonder : radius + 1 … cap.
function Tr.rings_to_probe(radius, cap)
  local out = {}
  for k = radius + 1, cap or Tr.CAP do out[#out + 1] = k end
  return out
end

--- Chunks { x, y } qu'un rectangle de tuiles (x0, y0 inclus, x1, y1 exclus) recouvre, ordre fixe (y puis x).
function Tr.chunks(x0, y0, x1, y1)
  local out = {}
  for cy = floor(y0 / Tr.CHUNK), floor((y1 - 1) / Tr.CHUNK) do
    for cx = floor(x0 / Tr.CHUNK), floor((x1 - 1) / Tr.CHUNK) do out[#out + 1] = { x = cx, y = cy } end
  end
  return out
end

--- Décision devant un gisement que le plan de la fonderie n'atteint pas.
--- s = {
---   found    : un lot du treillis porte ce minerai ;
---   dist     : tuiles du module au lot de minerai (si found) ; reach : tuiles que le tapis des foreuses peut franchir ;
---   deposit_ring : anneau de ce lot (si found) ;
---   radius   : rayon du treillis ; cap : plafond de croissance ; enc_r : rayon figé par une enceinte (nil : aucune) ;
---   pending  : évaluations de lots encore en file ;
---   probe    : nil (pas sondé), false (sondé, rien jusqu'à cap) ou l'anneau le plus proche où la sonde a trouvé du minerai.
--- }
--- Rend { cause, action, radius } ; `radius` : rayon à demander à Build.grow quand action = "grandir".
function Tr.decide(s)
  local cap = s.cap or Tr.CAP
  local radius = s.radius or 0
  local function grow_or_wall(ring, cause_grow)
    local target = min(cap, ring + Tr.MARGIN_PROBE)
    if s.enc_r then target = min(target, s.enc_r) end
    if target > radius then return { cause = cause_grow, action = "grandir", radius = target } end
    return nil
  end
  if s.found then
    if (s.dist or 0) <= (s.reach or 0) then return { cause = "a_portee", action = "ok" } end
    -- le lot de minerai est dans le treillis mais aucun lot libre ne tient à portée du tapis
    local ring = s.deposit_ring or radius
    local g = grow_or_wall(ring, "trop_loin_bord")
    if g then return g end
    if (s.pending or 0) > 0 then return { cause = "trop_loin_en_cours", action = "attendre" } end
    if s.enc_r and min(cap, ring + Tr.MARGIN_PROBE) > s.enc_r then return { cause = "enceinte", action = "refuser" } end
    return { cause = "trop_loin_plein", action = "refuser" }
  end
  if s.probe == nil then return { cause = "a_sonder", action = "sonder" } end
  if s.probe == false then return { cause = "aucun_gisement", action = "refuser" } end
  if s.probe > cap then return { cause = "hors_plafond", action = "refuser" } end
  if s.probe <= radius then
    -- le minerai est DANS le treillis : les lots l'ont déjà ou vont l'avoir ; s'ils ne le portent pas, ils sont refusés
    if (s.pending or 0) > 0 then return { cause = "en_cours", action = "attendre" } end
    return { cause = "lot_refuse", action = "refuser" }
  end
  local g = grow_or_wall(s.probe, "hors_grandir")
  if g then return g end
  if s.enc_r then return { cause = "enceinte", action = "refuser" } end
  return { cause = "en_cours", action = "attendre" }
end

--- Ligne de journal. t = { team, tick, res, cause, action, from, to, probe, dist, reach, pending }.
function Tr.line(t)
  local grow = (t.action == "grandir") and string.format(" : rayon %d -> %d", t.from or 0, t.to or 0) or ""
  local probe = (t.probe ~= nil) and (t.probe and string.format(", minerai a l'anneau %d", t.probe) or ", rien jusqu'a l'anneau " .. tostring(t.cap or Tr.CAP)) or ""
  local reach = (t.dist ~= nil) and string.format(", %d tuiles du lot pour %d de portee", floor(t.dist), floor(t.reach or 0)) or ""
  return string.format("[FO-TREILLIS] %s : %s, cause %s -> %s%s%s%s (%.1f min)", tostring(t.team or "?"), tostring(t.res or "?"),
    tostring(t.cause), tostring(t.action), grow, probe, reach, (t.tick or 0) / 3600)
end

return Tr
