--[[
  Lot TV-ARCHI (V23 de docs/TODO_VIDEO.md, l.89 ; V22 l.88 ; G38 l.215) : QUARTIERS du treillis et ENVELOPPE D'AVANCE. Règle PURE
  (aucune API du jeu), testée hors jeu (tests/quartiers_test.lua) ; le runtime est script/team/quartiers.lua.

  La vidéo : « building a blank Mega tile then filling each of the eight empty tiles » : l'enveloppe commune (logistique, défense,
  courant) d'abord, les modules ensuite. Ici, une couche AU-DESSUS du treillis de shared/team/plan.lua (rien n'y change) :
    - QUARTIER (méga-tuile) = 3 × 3 lots : le lot (i, j) est dans le quartier (⌊(i+1)/3⌋, ⌊(j+1)/3⌋). Le quartier (0, 0) est le CŒUR :
      son centre est le lot du QG, déjà en place (plan.lua l.9 : « la 1re couronne du QG est le CŒUR »).
    - PÔLE d'un quartier = son lot central (3I, 3J) ; pris, refusé ou dehors : le lot utilisable du quartier le plus proche du centre.
    - Un quartier est OUVERT quand son projet « quartier » du plan directeur est fini (poteau relié au réseau, coffres de dépôt, lot
      central défriché ; rues défrichées par le plan directeur).
    - BESOIN ANTICIPÉ : lots pris par des modules pendant Q.WINDOW (15 min), ramenés à Q.LEAD (10 min) d'avance, bornés à [Q.NEED_MIN,
      Q.NEED_MAX]. Le quartier suivant s'ouvre quand les lots LIBRES des quartiers ouverts (cœur compris) passent sous ce besoin,
      AVANT que les modules ne manquent de place : on anticipe la croissance au lieu d'y réagir.
    - Portes : réglage allumé, réseau électrique existant (centrale finie), aucun quartier en chantier, au moins Q.IDLE_MIN PNJ inactif,
      aucune retenue de la pile, pas de mode survie. Sinon la raison est rendue (journal [FO-ENVELOPPE]).
    - Choix : le quartier le plus proche du cœur (anneau de Chebyshev), puis le plus de lots libres, puis le pôle le plus proche du QG,
      puis J, puis I (aucune égalité laissée au hasard).
  Défense (tranche 1) : seuls les lots que le plan directeur juge utilisables comptent (pas `out` : hors du contour de l'enceinte ;
  pas mauvais) ; aucune tourelle neuve (tranche 3).

  Déterminisme : clés triées, aucun `pairs` non trié pour décider, aucune horloge mesurée ; entrées et sorties : nombres, chaînes, tables.
]]

local Q = {}

Q.WINDOW = 15 * 3600   -- ticks : fenêtre de la consommation de lots
Q.LEAD = 10 * 3600     -- ticks : avance voulue
Q.NEED_MIN = 2         -- lots libres gardés au moins dans les quartiers ouverts
Q.NEED_MAX = 4         -- … au plus
Q.IDLE_MIN = 1         -- PNJ inactifs au moins pour ouvrir un quartier (l'enveloppe ne prend pas de bras à la production)
Q.REFUS_MAX = 2        -- plans refusés au plus pour un quartier avant de l'écarter

local USABLE = { libre = true, defricher = true }

--- Quartier (I, J) du lot (i, j).
function Q.of_lot(i, j) return math.floor((i + 1) / 3), math.floor((j + 1) / 3) end

function Q.key(I, J) return I .. ":" .. J end

--- Lot central du quartier (I, J).
function Q.center(I, J) return 3 * I, 3 * J end

--- Lot utilisable par un module (comme les candidats du plan directeur : libre ou à défricher, ni pris, ni dehors, ni mauvais).
function Q.usable(l)
  return l ~= nil and USABLE[l.state] == true and not l.used and not l.out and not ((l.bad or 0) >= 2)
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Lot du pôle du quartier (I, J) : clé du lot central s'il est utilisable, sinon le lot utilisable du quartier le plus proche du
--- centre (Manhattan, puis j, puis i) ; nil si aucun. `lots` : { [clé "i:j"] = { i, j, state, used, out, bad } }.
function Q.hub_lot(lots, I, J)
  local ci, cj = Q.center(I, J)
  local best, bd, bi, bj
  for dj = -1, 1 do
    for di = -1, 1 do
      local i, j = ci + di, cj + dj
      local l = lots[i .. ":" .. j]
      if Q.usable(l) then
        local d = math.abs(di) + math.abs(dj)
        if not best or d < bd or (d == bd and (j < bj or (j == bj and i < bi))) then best, bd, bi, bj = i .. ":" .. j, d, i, j end
      end
    end
  end
  return best
end

--- Lots utilisables du quartier (I, J), le lot `except` mis à part.
function Q.free_in(lots, I, J, except)
  local ci, cj = Q.center(I, J)
  local n = 0
  for dj = -1, 1 do
    for di = -1, 1 do
      local k = (ci + di) .. ":" .. (cj + dj)
      if k ~= except and Q.usable(lots[k]) then n = n + 1 end
    end
  end
  return n
end

--- Lots libres des quartiers OUVERTS (cœur compris). `open` : { [clé du quartier] = true }.
function Q.free_open(lots, open)
  local n = 0
  for _, k in ipairs(sorted_keys(lots)) do
    local l = lots[k]
    local I, J = Q.of_lot(l.i, l.j)
    if Q.usable(l) and ((I == 0 and J == 0) or open[Q.key(I, J)]) then n = n + 1 end
  end
  return n
end

--- Besoin anticipé : `starts` = ticks de plan des modules posés dans un lot (liste). Rend (besoin, lots pris dans la fenêtre).
function Q.need(starts, tick)
  local n = 0
  for _, t in ipairs(starts or {}) do if t <= tick and tick - t < Q.WINDOW then n = n + 1 end end
  local want = math.ceil(n * Q.LEAD / Q.WINDOW - 1e-9)
  return math.max(Q.NEED_MIN, math.min(Q.NEED_MAX, want)), n
end

--- Quartiers ouvrables, triés : ni le cœur, ni ouverts ni en chantier (`known` : { [clé] = { refus } }), avec un pôle et au moins un
--- lot libre de plus. Rend une liste de { I, J, key, hub, free, d }.
function Q.candidates(lots, known)
  local seen, out = {}, {}
  for _, k in ipairs(sorted_keys(lots)) do
    local l = lots[k]
    local I, J = Q.of_lot(l.i, l.j)
    local qk = Q.key(I, J)
    if not seen[qk] and not (I == 0 and J == 0) then
      seen[qk] = true
      local kn = known and known[qk]
      if not kn or (not kn.pid and (kn.refus or 0) < Q.REFUS_MAX) then
        local hub = Q.hub_lot(lots, I, J)
        local free = hub and Q.free_in(lots, I, J, hub) or 0
        if hub and free >= 1 then
          local h = lots[hub]
          out[#out + 1] = { I = I, J = J, key = qk, hub = hub, free = free, d = math.max(math.abs(I), math.abs(J)),
            hd = math.abs(h.i) + math.abs(h.j) }
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.d ~= b.d then return a.d < b.d end
    if a.free ~= b.free then return a.free > b.free end
    if a.hd ~= b.hd then return a.hd < b.hd end
    if a.J ~= b.J then return a.J < b.J end
    return a.I < b.I
  end)
  return out
end

---------------------------------------------------------------------------------------------------
-- Tranche 2 (V91, l.157 : « minifactory that is self-contained … unconnected logistic networks ») : DÉPÔT du quartier.
-- Les coffres du pôle sont des quais du projet « quartier » (remplis depuis le QG par les tournées de quais existantes) ; un quai d'un
-- module du quartier est rempli DEPUIS le dépôt quand il en a assez (trajet dépôt -> quai au lieu de QG -> quai -> QG).
---------------------------------------------------------------------------------------------------
--- Objets du dépôt : `counts` = { [objet] = nombre de quais du quartier qui le demandent } ; les `n` plus demandés (puis par nom).
function Q.depot_items(counts, n)
  local list = {}
  for _, k in ipairs(sorted_keys(counts)) do if (counts[k] or 0) > 0 then list[#list + 1] = k end end
  table.sort(list, function(a, b) if counts[a] ~= counts[b] then return counts[a] > counts[b] end return a < b end)
  local out = {}
  for i = 1, math.min(n or 0, #list) do out[i] = list[i] end
  return out
end

--- Le dépôt sert-il la tournée ? Il faut TOUT le lot de la tournée au dépôt (pas de tournée à moitié vide).
function Q.depot_serves(have, need) return (need or 0) > 0 and (have or 0) >= need end

--- Décision : { open = candidat } ou { why = raison }. `s` = { on, plant, busy, free, need, idle, hold, survie, cands }.
function Q.decide(s)
  if not s.on then return { why = "eteint" } end
  if not s.plant then return { why = "pas de reseau (centrale non finie)" } end
  if s.busy then return { why = "quartier en chantier" } end
  if (s.free or 0) >= (s.need or Q.NEED_MIN) then return { why = "assez de lots libres" } end
  if (s.idle or 0) < Q.IDLE_MIN then return { why = "aucun PNJ inactif" } end
  if s.hold then return { why = "pile en retenue" } end
  if s.survie then return { why = "mode survie" } end
  local c = s.cands and s.cands[1]
  if not c then return { why = "aucun quartier ouvrable" } end
  return { open = c }
end

return Q
