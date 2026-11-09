--[[
  LIGNE ÉLECTRIQUE DE BANDE (lot RACCORD-BANDE 2, partie neuve 0.6.72 : « plus proche cible a 163 / 166 / 173 / 177 / 274 / 276 / 281 tuiles »).
  Règle PURE (aucune API Factorio) : une LIGNE de poteaux d'un poteau alimenté jusqu'à une bande de champ trop éloignée du réseau pour le raccord
  local (shared/team/champ_raccord.lua). Comme un joueur : une ligne droite de poteaux de portée `reach`, contournant eau, falaises, bâtiments.

  La recherche est découpée en TRANCHES (`legs`) : une étape = un tronçon d'au plus Lb.LEG tuiles, cherché par P.pole_chain (gloutonne puis A*, plafonds
  de shared/team/poteaux.lua) ; l'état (st) ne contient que des nombres et des tables de nombres (il vit dans le projet, donc dans global). Le coût
  d'une étape est celui d'une recherche de ~40 tuiles (mesuré par debug.sethook, tests/ligne_bande_test.lua), pas celui d'une ligne de 280 tuiles.

  Un tronçon vise un POINT INTERMÉDIAIRE sur la droite de la pointe au but, décalé de côté (Lb.SHIFTS) si aucun tronçon ne passe : l'eau ou une falaise en
  travers se contourne par le côté ; en dernier recours, à travers les arbres (défrichés sous les poteaux), comme Far.line (centrale lointaine).
  Le dernier tronçon vise le poteau de la bande (déjà posé ou planifié, non rendu).

    Lb.new(a, b, reach)  -> st   a : poteau alimenté (point de départ, existant), b : poteau de la bande (but), reach : portée de fil
    Lb.step(st, ctx)     -> "more" | "done" | "fail", raison
        ctx = { free = function(x, y, trees) -> vrai si un poteau peut être posé là (tuile libre ; trees : les arbres comptent comme libres),
                pole_chain = P.pole_chain, opts = function(dist) -> options de Poteaux.path pour un tronçon de `dist` tuiles }
    st.poles = { { x, y }... } poteaux NEUFS de a vers b (a et b exclus), st.done, st.tip.
]]

local Lb = {}

Lb.LEG = 36                       -- tuiles au plus par tronçon (hors dernier)
Lb.MAX_POLES = 80                 -- même plafond que la centrale lointaine (Cl.MAX_POLES)
Lb.SHIFTS = { 0, 12, -12, 24, -24, 40, -40, 60, -60, 90, -90 } -- décalages latéraux du point intermédiaire, dans l'ordre d'essai
Lb.SNAP = 6                       -- rayon (tuiles) de la recherche d'une tuile libre autour du point intermédiaire

local floor, sqrt, max, abs = math.floor, math.sqrt, math.max, math.abs

local function key(x, y) return (floor(x) + 50000) * 100000 + (floor(y) + 50000) end

function Lb.new(a, b, reach)
  return { a = { x = a.x, y = a.y }, goal = { x = b.x, y = b.y }, tip = { x = a.x, y = a.y }, reach = reach, poles = {}, taken = {},
    legs = 0, fails = 0, shift = 1, trees = false, done = false }
end

--- Tuile libre la plus proche de (x, y) à Lb.SNAP tuiles au plus (anneaux de Chebyshev, puis distance, y, x). Rend x, y (centre de la tuile) ou nil.
local function snap(x, y, free, trees)
  local x0, y0 = floor(x), floor(y)
  for r = 0, Lb.SNAP do
    local best, bd
    for dy = -r, r do
      for dx = -r, r do
        if max(abs(dx), abs(dy)) == r then
          local d = dx * dx + dy * dy
          if (bd == nil or d < bd or (d == bd and (dy < best[2] or (dy == best[2] and dx < best[1])))) and free(x0 + dx + 0.5, y0 + dy + 0.5, trees) then
            best, bd = { dx, dy }, d
          end
        end
      end
    end
    if best then return x0 + best[1] + 0.5, y0 + best[2] + 0.5 end
  end
  return nil
end

--- Une étape de la recherche. Rend "done" (la ligne est complète : st.poles), "more" (appeler encore), ou "fail", raison.
function Lb.step(st, ctx)
  if st.done then return "done" end
  local reach = st.reach
  local tip, goal = st.tip, st.goal
  local dx, dy = goal.x - tip.x, goal.y - tip.y
  local d = sqrt(dx * dx + dy * dy)
  if d <= reach + 1e-9 then st.done = true return "done" end
  -- la pointe est un poteau posé ou planifié : les tuiles déjà prises par la ligne ne sont plus libres
  local function free(x, y, trees)
    if st.taken[key(x, y)] then return false end
    return ctx.free(x, y, trees)
  end
  local final = d <= Lb.LEG + reach
  local target
  if final then
    target = goal
  else
    local ux, uy = dx / d, dy / d
    local sh = Lb.SHIFTS[st.shift]
    -- le point intermédiaire : à Lb.LEG tuiles sur la droite, décalé de côté si aucun tronçon ne passe
    local gx, gy = tip.x + ux * Lb.LEG - uy * sh, tip.y + uy * Lb.LEG + ux * sh
    local sx, sy = snap(gx, gy, free, st.trees)
    if sx then target = { x = sx, y = sy } end
  end
  local chain
  if target then chain = ctx.pole_chain(tip, target, reach, false, function(x, y) return free(x, y, st.trees) end, nil, ctx.opts(sqrt((target.x - tip.x) ^ 2 + (target.y - tip.y) ^ 2))) end
  if not chain then
    st.fails = st.fails + 1
    st.shift = st.shift + 1
    if st.shift > #Lb.SHIFTS then
      if not st.trees then
        st.trees, st.shift = true, 1 -- second essai : à travers bois (les arbres sous les poteaux seront défrichés)
        return "more"
      end
      return "fail", string.format("aucun troncon de ligne ne passe de (%.0f, %.0f) vers (%.0f, %.0f) (%d poteau(x) deja poses, %d essai(s))",
        tip.x, tip.y, goal.x, goal.y, #st.poles, st.fails)
    end
    return "more"
  end
  for _, c in ipairs(chain) do
    st.poles[#st.poles + 1] = { x = c.x, y = c.y }
    st.taken[key(c.x, c.y)] = true
  end
  if not final then
    st.poles[#st.poles + 1] = { x = target.x, y = target.y }
    st.taken[key(target.x, target.y)] = true
    st.tip = { x = target.x, y = target.y }
  end
  st.legs, st.shift = st.legs + 1, 1
  if #st.poles > Lb.MAX_POLES then return "fail", string.format("ligne de %d poteaux au-dela de %d", #st.poles, Lb.MAX_POLES) end
  if final then st.done = true return "done" end
  return "more"
end

--- Distance restante estimée (tuiles) de la pointe au but, pour le journal.
function Lb.remaining(st)
  local dx, dy = st.goal.x - st.tip.x, st.goal.y - st.tip.y
  return sqrt(dx * dx + dy * dy)
end

return Lb
