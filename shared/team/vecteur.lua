--[[
  s44 vecteur : AXE D'APPROCHE d'une attaque et LIGNE de tourelles entre l'ennemi et la structure touchée. Règle PURE (aucune API
  Factorio, aucun nom d'objet), déterministe (racine carrée seulement, pas de trigonométrie), testée par tests/s44_vecteur_test.lua.

  Constat (partie du DC 0.7.102, 2 h 30) : une centrale attaquée (production électrique en chute de 80-90 %) recevait ses tourelles de
  garde sur un anneau FIXE (est, ouest, sud, nord, puis diagonales : shared/team/garde_centrale.lua, G.sites), quel que soit le côté
  d'où venait l'ennemi ; la garde attaquée n'était pas non plus servie en premier.

  - V.ligne(sx, sy, ax, ay, d, n, pas) : structure en (sx, sy), attaquant (ou nid, ou vague connue) en (ax, ay). Axe u = attaquant -
    structure, normé. Centre de ligne c = structure + u * d (d tuiles DEVANT la structure, côté ennemi ; jamais au-delà de l'attaquant).
    Rend n emplacements { x, y } entiers sur la perpendiculaire à u passant par c, du centre vers les bords (0, +1, -1, +2, -2...) x pas.
    Attaquant confondu avec la structure : {} (pas d'axe).
  - V.fresh(v, tick, ttl) : relevé d'attaque encore valable (moins de ttl ticks).
]]
local V = {}

V.TTL = 3 * 3600 -- un relevé d'attaque reste valable 3 minutes
V.PAS = 3        -- écart entre deux emplacements de la ligne (tourelle de 2 tuiles + 1)
V.N = 5          -- emplacements proposés par ligne

function V.ligne(sx, sy, ax, ay, d, n, pas)
  local ux, uy = ax - sx, ay - sy
  local len = math.sqrt(ux * ux + uy * uy)
  if len < 1e-6 then return {} end
  ux, uy = ux / len, uy / len
  if d > len then d = len end
  local cx, cy = sx + ux * d, sy + uy * d
  local px, py = -uy, ux -- perpendiculaire
  pas = pas or V.PAS
  local out = {}
  for i = 0, (n or V.N) - 1 do
    local k = (i % 2 == 1) and ((i + 1) / 2) or -(i / 2) -- 0, 1, -1, 2, -2...
    out[#out + 1] = { x = math.floor(cx + px * k * pas + 0.5), y = math.floor(cy + py * k * pas + 0.5) }
  end
  return out
end

function V.fresh(v, tick, ttl)
  return v ~= nil and v.ax ~= nil and tick - (v.t or -math.huge) < (ttl or V.TTL)
end

return V
