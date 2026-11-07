--[[
  Lot FOREUSES (retour du DC du 29/10, partie de 1 h 30 sur 0.6.13 : « des foreuses thermiques encore presentes malgre la tech 2,
  alors qu'ils peuvent mettre des foreuses electriques a la place »). PUR (aucune API Factorio, aucun nom d'objet : les noms et
  les dimensions viennent de shared/team/config.lua et du moteur, passes par l'appelant).

  Regle : le TYPE de foreuse suit l'objet (obtenable : au stock ou fabricable) ET le courant (un poteau de l'equipe dont la zone
  d'alimentation touche la foreuse, sur un reseau qui produit). Une foreuse a combustion deja posee, dont le recepteur (four ou
  coffre) recoit le minerai, est remplacee sur place par une electrique de 3 x 3 : meme direction, recepteur inchange, centre
  choisi pour que le point de depot de l'electrique tombe dans le recepteur sans que la nouvelle boite le recouvre.

  Directions : 0 nord, 2 est, 4 sud, 6 ouest (defines.direction). Boites : { x, y, w, h } (centre et taille, en tuiles).
]]

local S = {}

local EPS = 1e-6
local abs = math.abs
local OFF = { -0.5, 0.5 } -- lot S5 (×10) : décalages de S.electric_center, sans table à chaque appel

--- Vecteur (x, y) tourne selon la direction (sens horaire, depuis le nord) : meme regle que le depot d'une foreuse du moteur.
function S.rotate(dir, x, y)
  if dir == 2 then return -y, x end
  if dir == 4 then return -x, -y end
  if dir == 6 then return y, -x end
  return x, y
end

--- Deux boites se recouvrent-elles (les contacts par un bord ne comptent pas) ?
function S.overlap(a, b)
  return math.abs(a.x - b.x) < (a.w + b.w) / 2 - EPS and math.abs(a.y - b.y) < (a.h + b.h) / 2 - EPS
end

--- Le point est-il dans la boite (intervalle ouvert) ?
function S.inside(box, px, py)
  return math.abs(px - box.x) < box.w / 2 - EPS and math.abs(py - box.y) < box.h / 2 - EPS
end

--- Centre de la foreuse electrique qui remplace une foreuse a combustion posee en (bx, by) dans la direction `dir`, ou nil.
--- `sink` : boite du recepteur ; `spec` = { size = 3, drop = { dx, dy } } (point de depot de l'electrique vers le nord).
--- La boite de l'electrique (size x size, centree sur un demi-entier) doit contenir l'ancienne emprise (2 x 2 centree sur un entier :
--- centres a demi-tuile), ne pas recouvrir le recepteur, et deposer dans le recepteur. Choix : le plus proche de l'ancien centre,
--- puis x, puis y croissants (deterministe).
function S.electric_center(bx, by, dir, sink, spec)
  -- Lot S5 (×10) : même calcul, mêmes opérations flottantes dans le même ordre, sans table allouée (la boîte { cx, cy, size, size }
  -- de S.overlap est écrite en ligne ; le meilleur est gardé dans deux nombres).
  local bcx, bcy, best_d
  local vx, vy = S.rotate(dir, spec.drop[1], spec.drop[2])
  local size = spec.size
  for i = 1, 2 do
    local ox = OFF[i]
    for j = 1, 2 do
      local oy = OFF[j]
      local cx, cy = bx + ox, by + oy
      if S.inside(sink, cx + vx, cy + vy)
        and not (abs(cx - sink.x) < (size + sink.w) / 2 - EPS and abs(cy - sink.y) < (size + sink.h) / 2 - EPS) then
        local d = ox * ox + oy * oy
        if not best_d or d < best_d - EPS or (abs(d - best_d) <= EPS and (cx < bcx or (cx == bcx and cy < bcy))) then
          bcx, bcy, best_d = cx, cy, d
        end
      end
    end
  end
  if not best_d then return nil end
  return bcx, bcy
end

--- La zone d'alimentation (carre de demi-cote `dist` autour du poteau) touche-t-elle la boite de la foreuse ?
function S.covered(px, py, dist, box)
  return S.overlap({ x = px, y = py, w = 2 * dist, h = 2 * dist }, box)
end

--- Type de foreuse choisi : "electric" quand l'objet est obtenable ET le courant arrive ; "burner" sinon.
function S.choose_type(obtainable, powered)
  if obtainable and powered then return "electric" end
  return "burner"
end

--- Remplacements a faire cette fois. entries : liste de { id, x, y, dir, sink = boite } (foreuses a combustion posees) ;
--- ctx = { poles = { { x, y, dist, powered } }, electric = spec, have = nombre d'objets electriques au stock, obtainable = bool,
--- limit = remplacements au plus }. Rend une liste triee par id de { id, cx, cy } (au plus min(limit, have)), et le nombre de
--- candidats alimentes (`n_ready`, pour fabriquer ce qui manque).
function S.plan(entries, ctx)
  local ready = {}
  local list = {}
  for _, e in ipairs(entries) do list[#list + 1] = e end
  table.sort(list, function(a, b) return a.id < b.id end)
  -- Lot S5 (×10) : S.covered(p.x, p.y, p.dist, boîte) écrit en ligne, sans table par paire (avant : une boîte par foreuse ET une
  -- zone par paire). Les poteaux alimentés sont filtrés une fois, dans le même ordre ; la borne (2 * dist + size) / 2 - EPS de
  -- S.overlap est calculée une fois par poteau (mêmes opérandes, même valeur) ; |d| < L s'écrit d < L et d > -L (même réponse, la
  -- négation est exacte). Sans objet obtenable, aucune foreuse n'est « electric » quel que soit le courant : boucle sautée.
  local size = ctx.electric.size
  local pxs, pys, lims, npw = {}, {}, {}, 0
  if ctx.obtainable then
    for _, p in ipairs(ctx.poles) do
      if p.powered then
        npw = npw + 1
        pxs[npw], pys[npw], lims[npw] = p.x, p.y, (2 * p.dist + size) / 2 - EPS
      end
    end
  end
  for _, e in ipairs(list) do
    local cx, cy = S.electric_center(e.x, e.y, e.dir, e.sink, ctx.electric)
    if cx then
      local powered = false
      for i = 1, npw do
        local l = lims[i]
        local dx = pxs[i] - cx
        if dx < l and dx > -l then
          local dy = pys[i] - cy
          if dy < l and dy > -l then powered = true break end
        end
      end
      if S.choose_type(ctx.obtainable, powered) == "electric" then ready[#ready + 1] = { id = e.id, cx = cx, cy = cy } end
    end
  end
  local out = {}
  local n = math.min(ctx.limit or #ready, ctx.have or 0)
  for i = 1, math.min(n, #ready) do out[i] = ready[i] end
  return out, #ready
end

--- Objets electriques a fabriquer : les candidats alimentes (au plus `cap`) moins ceux deja au stock.
function S.demand(n_ready, have, cap)
  return math.max(0, math.min(n_ready, cap) - have)
end

return S
