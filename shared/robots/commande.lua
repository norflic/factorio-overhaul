--[[
  Lot RB-2 JOUEUR (1/11) : règles pures de la COMMANDE des robots par le joueur (aucune API du jeu ; tests/robots_ui_test.lua).
    - zone d'un outil : centre et rayon d'une zone tirée à la souris ; un clic sans glisser (zone nulle) donne le rayon minimal
      (RB0 E6 : ce que le moteur envoie pour un clic n'est pas prouvé ; zone nulle ou petite, le résultat est le même) ;
    - sélection : liste triée sans doublon, bornée, purgée de ses morts ;
    - « attaquer ce qui est encadré » : le point d'attaque est le centre des ennemis encadrés, sinon celui de la zone ;
    - « tous au ralliement » : chaque unité va au ralliement de SON atelier d'origine ;
    - alerte de pertes : au plus une alerte par force et par Ro.ALERT_COOLDOWN ticks, puis un bilan quand les pertes cessent.
  Les noms de prototypes viennent de shared/content/robots.lua ; ce fichier n'en nomme aucun.
]]

local Ro = require("shared.content.robots")

local Cm = {}

local floor, max, min, sqrt = math.floor, math.max, math.min, math.sqrt

local function xy(p) return p.x or p[1], p.y or p[2] end

---------------------------------------------------------------------------------------------------
-- 1. Zone d'un outil
---------------------------------------------------------------------------------------------------
--- Zone normalisée { x0, y0, x1, y1 } (x0 ≤ x1, y0 ≤ y1) depuis une BoundingBox du moteur (left_top / right_bottom, ou deux
--- couples) ; nil si elle est illisible.
function Cm.area(a)
  if type(a) ~= "table" then return nil end
  local lt, rb = a.left_top or a[1], a.right_bottom or a[2]
  if type(lt) ~= "table" or type(rb) ~= "table" then return nil end
  local ax, ay = xy(lt)
  local bx, by = xy(rb)
  if type(ax) ~= "number" or type(ay) ~= "number" or type(bx) ~= "number" or type(by) ~= "number" then return nil end
  if ax ~= ax or ay ~= ay or bx ~= bx or by ~= by then return nil end
  return { x0 = min(ax, bx), y0 = min(ay, by), x1 = max(ax, bx), y1 = max(ay, by) }
end

--- Centre de la zone ({ x, y }), ou nil.
function Cm.center(a)
  local z = Cm.area(a)
  if not z then return nil end
  return { x = (z.x0 + z.x1) / 2, y = (z.y0 + z.y1) / 2 }
end

--- Rayon d'une zone d'ordre : la demi-diagonale, entre Ro.MIN_ZONE (un clic) et Ro.ATTACK_RADIUS.
function Cm.radius(a)
  local z = Cm.area(a)
  if not z then return Ro.MIN_ZONE end
  local half = sqrt((z.x1 - z.x0) ^ 2 + (z.y1 - z.y0) ^ 2) / 2
  return max(Ro.MIN_ZONE, min(Ro.ATTACK_RADIUS, half))
end

--- Rayon d'arrêt d'une troupe de `count` unités envoyées au même point (« aller ») : elles s'étalent au lieu de se pousser.
function Cm.move_radius(count)
  return max(2, min(6, 1 + floor(sqrt(max(0, count or 0)))))
end

--- Action de l'événement d'un outil (« selected », « alt », « reverse », « alt_reverse »), ou nil.
function Cm.action_of(ev) return Ro.TOOL_ACTIONS[ev] end

--- Ordre du moteur (Ro.ORDERS) d'une action : « attack » -> marche-attaque, « strike » -> marche-attaque sur ce qui est encadré,
--- « move » -> aller ; « choose » n'est pas un ordre (nil).
function Cm.order_of(action)
  if action == "attack" or action == "strike" then return "attack" end
  if action == "move" then return "move" end
  return nil
end

---------------------------------------------------------------------------------------------------
-- 2. Sélection
---------------------------------------------------------------------------------------------------
--- Sélection neuve depuis une liste de numéros d'unité : triée, sans doublon, au plus Ro.SELECTION_MAX.
function Cm.choose(numbers)
  local seen, out = {}, {}
  for _, n in ipairs(numbers or {}) do
    if type(n) == "number" and not seen[n] then
      seen[n] = true
      out[#out + 1] = n
    end
  end
  table.sort(out)
  while #out > Ro.SELECTION_MAX do out[#out] = nil end
  return out
end

--- Retire les unités que `alive(numéro)` refuse ; rend (sélection restante, nombre retiré).
function Cm.purge(sel, alive)
  local out, gone = {}, 0
  for _, n in ipairs(sel or {}) do
    if alive(n) then out[#out + 1] = n else gone = gone + 1 end
  end
  return out, gone
end

---------------------------------------------------------------------------------------------------
-- 3. Attaquer ce qui est encadré
---------------------------------------------------------------------------------------------------
--- Point et rayon d'une attaque sur des ennemis encadrés : leur centre de gravité et la distance au plus lointain (+ 4 tuiles),
--- entre Ro.MIN_ZONE et Ro.ATTACK_RADIUS ; sans ennemi (ou positions illisibles), le centre et le rayon de la zone.
function Cm.strike(area, enemies)
  local n, sx, sy = 0, 0, 0
  for _, p in ipairs(enemies or {}) do
    local x, y = xy(p)
    if type(x) == "number" and type(y) == "number" then
      n, sx, sy = n + 1, sx + x, sy + y
    end
  end
  if n == 0 then return Cm.center(area), Cm.radius(area) end
  local cx, cy = sx / n, sy / n
  local far = 0
  for _, p in ipairs(enemies) do
    local x, y = xy(p)
    if type(x) == "number" and type(y) == "number" then far = max(far, sqrt((x - cx) ^ 2 + (y - cy) ^ 2)) end
  end
  return { x = cx, y = cy }, max(Ro.MIN_ZONE, min(Ro.ATTACK_RADIUS, far + 4))
end

---------------------------------------------------------------------------------------------------
-- 4. Tous au ralliement
---------------------------------------------------------------------------------------------------
--- Pour chaque unité de la liste triée `units`, le ralliement de son atelier d'origine : `ledger_units[numéro].home`, lu dans
--- `rallies[home]` = { x, y }. Une unité sans atelier connu (ou dont l'atelier n'a plus de ralliement) prend `fallback`
--- (ralliement du premier atelier de la force, ou nil). Rend (liste { unit, x, y } dans l'ordre des unités, nombre sans
--- destination).
function Cm.rally_all(units, ledger_units, rallies, fallback)
  local out, skipped = {}, 0
  for _, un in ipairs(units or {}) do
    local rec = ledger_units[un]
    local p = rec and rec.home and rallies[rec.home] or fallback
    if p then
      out[#out + 1] = { unit = un, x = p.x, y = p.y }
    else
      skipped = skipped + 1
    end
  end
  return out, skipped
end

---------------------------------------------------------------------------------------------------
-- 5. Alerte de pertes (état d'une force : { last_alert, n, x, y, t }, nombres seulement)
---------------------------------------------------------------------------------------------------
function Cm.new_loss() return { n = 0 } end

--- Une perte au tick `tick` en (x, y). Rend vrai s'il faut lever une alerte MAINTENANT (au plus une par Ro.ALERT_COOLDOWN).
function Cm.loss_note(st, tick, x, y)
  st.n = (st.n or 0) + 1
  st.x, st.y, st.t = x, y, tick
  if st.last_alert == nil or tick - st.last_alert >= Ro.ALERT_COOLDOWN then
    st.last_alert = tick
    return true
  end
  return false
end

--- Bilan des pertes : quand `Ro.LOSS_FLUSH` ticks se sont écoulés sans nouvelle perte, rend (nombre, x, y) de la salve et la
--- remet à zéro ; sinon nil.
function Cm.loss_flush(st, tick)
  if (st.n or 0) > 0 and tick - (st.t or tick) >= Ro.LOSS_FLUSH then
    local n, x, y = st.n, st.x, st.y
    st.n = 0
    return n, x, y
  end
  return nil
end

return Cm
