--[[
  Lot POTEAUX-V2 : un poteau qui va etre pose est-il un DOUBLON d'un poteau deja pose ? Regle PURE (aucune API Factorio, aucun nom d'objet ;
  tests/pole_dedupe_test.lua). L'appelant (script/team/build.lua, revive_one) fournit les poteaux alentour tels que le moteur les voit.

  Un poteau `e` est un doublon, donc saute (compte pose, objet non consomme), seulement si TOUT ceci tient :
    (a) un poteau `q` REELLEMENT POSE est a D.DUP_R tuiles au plus de `e` ;
    (b) `q` est sur le reseau d'une centrale (gen[q.net]) : un poteau relie a rien d'utile n'excuse personne ;
    (c) chaque autre poteau `n` a portee de fil de `e` (portee = la plus courte des deux) est soit un poteau POSE du meme reseau que `q`, soit un poteau
        PREVU qui est aussi a portee de fil de `q` : retirer `e` ne coupe aucun lien et n'en isole aucun.
  Les poteaux `n` sont les AUTRES poteaux (e et les poteaux deja sautes sont exclus par l'appelant).
  Entrees : e = { x, y, wire } ; poles[i] = { x, y, wire, posed = bool, net = id | nil } ; gen = { [id reseau d'un generateur] = true }.
  Sortie : true, indice de q  |  false, raison.   Determinisme : le plus proche, ex aequo le plus petit (y, x).
]]

local D = {}

D.DUP_R = 2.0   -- tuiles : « a moins de 2 tuiles » (meme seuil que le releve des paires)

local function d2(a, b) local dx, dy = a.x - b.x, a.y - b.y; return dx * dx + dy * dy end
local function reach(a, b) return math.min(a.wire or 0, b.wire or 0) end

function D.redundant(e, poles, gen)
  local q, qd
  for i, p in ipairs(poles) do
    if p.posed and p.net ~= nil and gen[p.net] then
      local dd = d2(e, p)
      if dd <= D.DUP_R * D.DUP_R + 1e-9 then
        if not qd or dd < qd - 1e-9 or (math.abs(dd - qd) <= 1e-9 and (p.y < poles[q].y or (p.y == poles[q].y and p.x < poles[q].x))) then
          q, qd = i, dd
        end
      end
    end
  end
  if not q then return false, "aucun poteau pose et alimente a moins de " .. D.DUP_R .. " tuiles" end
  local pq = poles[q]
  for i, n in ipairs(poles) do
    if i ~= q then
      local r = reach(e, n)
      if d2(e, n) <= r * r + 1e-9 then
        if n.posed then
          if n.net == nil or n.net ~= pq.net then return false, "un poteau pose voisin n'est pas sur le reseau de q" end
        else
          local rq = reach(pq, n)
          if d2(pq, n) > rq * rq + 1e-9 then return false, "un poteau prevu voisin est hors de portee de q" end
        end
      end
    end
  end
  return true, q
end

return D
