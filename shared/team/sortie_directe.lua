--[[
  s42 bus-direct (chantier 1 du DC, partie de 4 h 15 en 0.7.96) : LIGNE DIRECTE d'une colonne de fours au tronc du mall. Règle PURE : aucune
  API du jeu, aucun nom d'objet. Testée hors jeu : tests/s42_bus-direct_test.lua.

  Constat du DC : les fours déchargent dans 8 à 16 coffres, puis UN bras par coffre alimente UNE ligne de rapatriement (demi-tapis, 0,83/s)
  vers un coffre tampon. Demande : dès qu'une équipe a plusieurs colonnes, une ligne complète part de la sortie des fours et arrive au mall
  sans coffre ni bras.

  La ligne directe : le BOUT de la ligne de plaques d'une colonne (shared/team/champ_colonne.lua : dernière tuile du trop-plein, `fin`) verse
  sur la première tuile de la ligne ; la dernière tuile verse sur la TÊTE d'une ligne du tronc du mall (shared/team/mall_tronc.lua : tuile la
  plus haute, où « une arrivée de tapis se pose »). Aucun bras, aucun coffre, aucun poteau. Le quai de la colonne reste (repli : rien n'est
  démonté) ; ses coffres sont barrés à ce qu'il faut pour une collecte (Sd.bar) : le reste des plaques continue sur la ligne.

  Déterminisme : listes en ordre fixe, départage par clé, aucun pairs.
]]

local Sd = {}

Sd.MIN_COLONNES = 2   -- bouts de ligne de plaques finis qu'il faut à l'équipe avant la première ligne directe (« plusieurs colonnes »)
Sd.QUAI_ALONG = 40    -- tuiles en amont du bout où un coffre de sortie est un coffre du quai de cette ligne de plaques
Sd.QUAI_SIDE = 2      -- rangées entre la ligne de plaques et les coffres du quai (bras entre les deux, shared/team/champ_colonne.lua)
Sd.RETRY = 20 * 3600  -- ticks avant un nouvel essai d'une paire refusée

local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
Sd.DV = DV

local function opp(d) return (d + 4) % 8 end

--- Tuile sur laquelle verse le tapis t = { x, y, dir }. nil si la direction n'est pas un des quatre axes.
function Sd.front(t)
  local v = DV[t.dir]
  if not v then return nil end
  return t.x + v[1], t.y + v[2]
end

--- Bouts du tracé pour le bout de colonne `exit` = { x, y, dir } et la tête de ligne `head` = { x, y, dir }, au format des sites de la liaison
--- (shared/team/liaison.lua : dir, ax, ay, bx, by) : src.a = le bout de colonne (déjà bâti), src.b = première tuile du tracé ; dst.a = la tête
--- (déjà bâtie), dst.b = dernière tuile du tracé, qui regarde la tête (Li.end_dir(dst) = head.dir). nil si une direction est fausse.
function Sd.ends(exit, head)
  local fx, fy = Sd.front(exit)
  local hv = DV[head.dir]
  if not (fx and hv) then return nil end
  return {
    src = { dir = exit.dir, ax = exit.x, ay = exit.y, bx = fx, by = fy },
    dst = { dir = opp(head.dir), ax = head.x, ay = head.y, bx = head.x - hv[1], by = head.y - hv[2] },
  }
end

--- Choix d'une paire. exits = { { key, x, y, dir, item } } (bouts de colonne bâtis), heads = { { k, item, x, y, dir } } (têtes bâties du tronc),
--- taken = { exits = { [key] = vrai }, heads = { [k] = vrai } } (déjà reliés ou en cours), blocked(exit, head) facultatif (paire refusée
--- récemment). Rend { exit, head, d } : pour la première tête libre (ordre des lignes du tronc), le bout libre du même objet le plus proche
--- (Manhattan, puis clé) ; ou nil et la raison.
function Sd.choose(exits, heads, taken, blocked)
  if #exits < Sd.MIN_COLONNES then return nil, string.format("%d bout(s) de colonne sur %d", #exits, Sd.MIN_COLONNES) end
  if #heads == 0 then return nil, "aucune tete de ligne du tronc batie" end
  taken = taken or {}
  local te, th = taken.exits or {}, taken.heads or {}
  local free_head = false
  for _, h in ipairs(heads) do
    if not th[h.k] then
      free_head = true
      local best, bd
      for _, e in ipairs(exits) do
        if e.item == h.item and not te[e.key] and not (blocked and blocked(e, h)) then
          local d = math.abs(e.x - h.x) + math.abs(e.y - h.y)
          if not best or d < bd or (d == bd and e.key < best.key) then best, bd = e, d end
        end
      end
      if best then return { exit = best, head = h, d = bd } end
    end
  end
  if not free_head then return nil, "toutes les tetes du tronc sont reliees" end
  return nil, "aucun bout de colonne libre pour l'objet d'une tete libre"
end

--- Preuve géométrique d'une ligne directe. tiles = { { x, y, dir, ug } } dans l'ordre du flux (tracé VIRTUEL : une paire souterraine est
--- rendue en tapis droits). Le bout de colonne verse sur la première tuile, qui ne lui fait pas face ; chaque tuile verse sur la suivante ;
--- la dernière verse sur la tête, dans le sens de la tête (les deux voies entrent par l'arrière). Rend la liste des écarts (vide : juste).
function Sd.verify(tiles, exit, head)
  local bad = {}
  if #tiles == 0 then bad[#bad + 1] = "aucune tuile" return bad end
  local fx, fy = Sd.front(exit)
  local t1 = tiles[1]
  if not (fx == t1.x and fy == t1.y) then bad[#bad + 1] = "le bout de la colonne ne verse pas sur la premiere tuile" end
  if t1.dir == opp(exit.dir) then bad[#bad + 1] = "la premiere tuile fait face au bout de la colonne" end
  local seen = {}
  for i, t in ipairs(tiles) do
    local k = t.x .. ":" .. t.y
    if seen[k] then bad[#bad + 1] = "deux tapis sur " .. k end
    seen[k] = true
    if (t.x == exit.x and t.y == exit.y) or (t.x == head.x and t.y == head.y) then bad[#bad + 1] = "une tuile du trace sur un bout deja bati (" .. k .. ")" end
    local nx, ny = Sd.front(t)
    if not nx then bad[#bad + 1] = "direction fausse en " .. k return bad end
    local n = tiles[i + 1]
    if n then
      if n.x ~= nx or n.y ~= ny then bad[#bad + 1] = "le tapis s'arrete en " .. k .. " sans atteindre la tete" return bad end
    else
      if nx ~= head.x or ny ~= head.y then bad[#bad + 1] = "la derniere tuile " .. k .. " ne verse pas sur la tete de la ligne du tronc" end
      if t.dir ~= head.dir then bad[#bad + 1] = "la derniere tuile n'entre pas dans la tete par l'arriere" end
    end
  end
  return bad
end

--- Coffres du quai de la ligne de plaques qui finit en `exit` : indices (croissants) de `outs` = { { x, y } } (centres) dont la tuile est à
--- Sd.QUAI_SIDE rangées de la ligne, de 1 à Sd.QUAI_ALONG tuiles en amont du bout. (Colonne double : les deux quais, un de chaque côté.)
function Sd.quai(exit, outs)
  local v = DV[exit.dir]
  local out = {}
  if not v then return out end
  for i, o in ipairs(outs or {}) do
    local dx, dy = exit.x - math.floor(o.x), exit.y - math.floor(o.y)
    local along = dx * v[1] + dy * v[2]
    local side = math.abs(dx * v[2] - dy * v[1])
    if along >= 1 and along <= Sd.QUAI_ALONG and side == Sd.QUAI_SIDE then out[#out + 1] = i end
  end
  return out
end

--- Barre d'un coffre du quai d'une colonne reliée (première case bloquée) : les cases qu'il faut pour `at` objets (le seuil de collecte du
--- coffre), jamais plus que le coffre (`slots`). Le coffre garde de quoi remplir un trajet de collecte ; le reste part sur la ligne.
function Sd.bar(at, stack, slots)
  local n = math.max(1, math.ceil(math.max(1, at or 1) / math.max(1, stack or 1)))
  if slots and n > slots then n = slots end
  return n + 1
end

--- Ligne de journal (une forme, un seul endroit).
function Sd.text(kind, d)
  local head = string.format("[FO-BUS-DIRECT] %s : ", d.team or "player")
  local tail = string.format(" a %.1f min", (d.tick or 0) / 3600)
  if kind == "demandee" then
    return head .. string.format("ligne directe demandee (projet %d) : bout de colonne (%d, %d) du projet %d -> tete de la ligne %d du tronc (%d, %d), %s, %d tuiles a vol d'oiseau",
      d.pid, d.ex, d.ey, d.src_pid, d.k, d.hx, d.hy, tostring(d.item), d.d) .. tail
  elseif kind == "finie" then
    return head .. string.format("ligne directe finie (projet %d, %s) : %d piece(s), %d coffre(s) du quai barre(s) a %d case(s)", d.pid, tostring(d.item), d.pieces, d.barres, d.cases) .. tail
  elseif kind == "refusee" then
    return head .. string.format("ligne directe refusee (projet %d) : %s", d.pid, tostring(d.cause)) .. tail
  elseif kind == "coupee" then
    return head .. string.format("ligne directe coupee (projet %d, etat %s) : %d coffre(s) du quai debarre(s)", d.pid, tostring(d.state), d.barres) .. tail
  end
  return head .. string.format("aucune ligne directe : %s", tostring(d.cause)) .. tail
end

return Sd
