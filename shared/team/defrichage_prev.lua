--[[
  Lot TV-PLACE, point G38 (docs/TODO_VIDEO.md l.215 : « Défrichage (plan 109) sur 50 × 50 pendant la sonde » ; lot L8). Règle PURE, testée
  hors jeu : tests/defrichage_prev_test.lua.

  Pourquoi. Un module planifié sur un lot « à défricher » passe d'abord par l'état « défrichage » (script/team/build.lua) : il tient son
  emplacement d'automatisation (A.MAX_OPEN) pendant que le PNJ coupe, et la matière réservée dort (en-tête de shared/ai3/emplacements.lua).
  La vidéo prépare la place AVANT la décision : pendant la sonde, la méga-tuile est défrichée sur 50 × 50. Mesure du lot L8 sur la partie du
  DC (0.6.58, 177 min) : 21 défrichages, tous de moins de 2 min, 0 place tenue plus de 5 min : le volet préventif ne résolvait pas un
  défaut observé ; le DC veut pourtant les 100 % des points de la vidéo. Il est donc livré BORNÉ, sous le budget des travaux lourds
  (script/core/lourd.lua) et à la priorité la plus basse du tableau : il ne prend jamais la place d'un travail réel.

  Ce que la règle décide.
    * Zone : 50 × 50 centrée sur le lot (13 tuiles de plus de chaque côté d'un lot de 24), découpée en QUATRE quarts de 25 × 25 (un PNJ coupe
      à 18 tuiles de son point d'appui au plus : le centre d'un quart couvre tout le quart, comme les moitiés de rues).
    * Un seul lot à la fois par équipe ; le plus proche du QG (couronne, distance, j, i) parmi les lots « défricher », libres (ni pris, ni
      hors contour, ni écartés par deux échecs), à Dp.RING_MAX couronnes au plus du QG ; au plus Dp.MAX_TRIES tentatives par lot.
    * Jamais pendant qu'un projet de l'équipe est en défrichage (la vraie coupe d'abord), ni pendant une menace.
    * Un repos de Dp.COOLDOWN ticks après chaque lot ; abandon d'un lot qui traîne plus de Dp.GIVE_UP ticks.
  Déterminisme : tri total, aucun hasard, aucun temps mesuré.
]]

local Dp = {}

Dp.SIZE = 50          -- côté de la zone défrichée (G38)
Dp.QUARTERS = 4
Dp.RING_MAX = 3       -- couronnes autour du QG
Dp.MAX_TRIES = 2      -- tentatives par lot
Dp.COOLDOWN = 3600    -- ticks de repos après un lot fini ou abandonné
Dp.GIVE_UP = 21600    -- ticks (6 min) : un lot qui traîne est abandonné
Dp.COST = 2           -- chunks DÉCLARÉS au jeton des travaux lourds par pas d'un quart (un quart de 25 x 25 touche 1 à 4 chunks)
Dp.PERIOD = 30        -- ticks entre deux demandes au jeton d'un même PNJ
Dp.WAIT_MAX = 40      -- refus consécutifs du jeton après lesquels le PNJ rend la tâche

function Dp.new() return { open = nil, since = nil, last = -1000000, q = {} } end

--- Zone de 50 x 50 centrée sur le lot [x0, x1) x [y0, y1) : x0, y0, x1, y1.
function Dp.rect(x0, y0, x1, y1)
  local mx = math.max(0, math.floor((Dp.SIZE - (x1 - x0)) / 2))
  local my = math.max(0, math.floor((Dp.SIZE - (y1 - y0)) / 2))
  return x0 - mx, y0 - my, x1 + mx, y1 + my
end

--- Quatre quarts d'une zone : { q = 1..4, x0, y0, x1, y1, ax, ay } (ax, ay : point d'appui = centre du quart). Ordre : NO, NE, SO, SE.
function Dp.quarters(x0, y0, x1, y1)
  local mx, my = (x0 + x1) / 2, (y0 + y1) / 2
  local boxes = {
    { x0, y0, mx, my }, { mx, y0, x1, my }, { x0, my, mx, y1 }, { mx, my, x1, y1 },
  }
  local out = {}
  for q, b in ipairs(boxes) do
    out[q] = { q = q, x0 = b[1], y0 = b[2], x1 = b[3], y1 = b[4], ax = (b[1] + b[3]) / 2, ay = (b[2] + b[4]) / 2 }
  end
  return out
end

local function ring(l) return math.max(math.abs(l.i), math.abs(l.j)) end

--- Un lot peut-il être ouvert maintenant ? nil si oui, sinon la raison (bon marché : l'appelant ne construit la liste des lots qu'ensuite).
function Dp.gate(st, tick, ctx)
  ctx = ctx or {}
  if st.open then return "en cours" end
  if (ctx.clearing or 0) > 0 then return "projet en defrichage" end
  if ctx.threatened then return "menace" end
  if tick - (st.last or -1000000) < Dp.COOLDOWN then return "repos" end
  return nil
end

--- Lot à défricher d'avance, ou nil et la raison. lots = liste de { k, i, j, state, used, bad, out, pre_n } ; st = Dp.new() ; ctx = { clearing =
--- projets de l'équipe en défrichage, threatened = menace en cours }.
function Dp.pick(lots, st, tick, ctx)
  local why = Dp.gate(st, tick, ctx)
  if why then return nil, why end
  local list = {}
  for _, l in ipairs(lots or {}) do
    if l.state == "defricher" and not l.used and not l.out and not (l.bad and l.bad >= 2) and not (l.i == 0 and l.j == 0)
      and ring(l) <= Dp.RING_MAX and (l.pre_n or 0) < Dp.MAX_TRIES then
      list[#list + 1] = l
    end
  end
  if #list == 0 then return nil, "aucun lot" end
  table.sort(list, function(a, b)
    local ra, rb = ring(a), ring(b)
    if ra ~= rb then return ra < rb end
    local da, db = a.i * a.i + a.j * a.j, b.i * b.i + b.j * b.j
    if da ~= db then return da < db end
    if a.j ~= b.j then return a.j < b.j end
    if a.i ~= b.i then return a.i < b.i end
    return tostring(a.k) < tostring(b.k)
  end)
  return list[1].k
end

--- Ouvre le défrichage du lot `k` à `tick`.
function Dp.start(st, k, tick)
  st.open, st.since = k, tick
  st.q = { false, false, false, false }
end

--- Quarts encore à couper (numéros, ordre croissant).
function Dp.pending(st)
  local out = {}
  if not st.open then return out end
  for q = 1, Dp.QUARTERS do
    if not (st.q and st.q[q]) then out[#out + 1] = q end
  end
  return out
end

--- Un quart est coupé. Rend vrai quand les QUATRE le sont (le lot est fini).
function Dp.quarter_done(st, q)
  if not st.open or type(q) ~= "number" or q < 1 or q > Dp.QUARTERS then return false end
  st.q = st.q or {}
  st.q[q] = true
  return #Dp.pending(st) == 0
end

--- Le lot ouvert traîne-t-il trop ?
function Dp.expired(st, tick)
  return st.open ~= nil and tick - (st.since or tick) > Dp.GIVE_UP
end

--- Ferme le lot ouvert (fini ou abandonné) : repos.
function Dp.finish(st, tick)
  st.open, st.since, st.q, st.last = nil, nil, {}, tick
end

return Dp
