--[[
  Lot s42 TUYAUX (chantier 5.1 du DC, « règle des 5 cases ») : une conduite RECTILIGNE de plus de Tu.MAX_RUN tuyaux consécutifs
  sans embranchement passe sous terre, pour garder le sol libre. PUR (aucune API Factorio, aucun nom du jeu) : la pièce souterraine
  est décrite par l'appelant, lue dans le prototype (script/ai3/petrole.lua, Pet.releve) :
    under = { name, reach (max_underground_distance : écart maximal entre les deux pièces d'une paire),
              open = { [0|2|4|6] = {dx, dy} } (tuile du raccord de SURFACE de la pièce, par direction) }.

  Tu.plan(tubes, keep, under, anchor) : `tubes` = { [clé] = fluide } (tuiles d'un tracé, clé de Tu.tkey), `keep` = { [clé] = vrai }
  (tuiles qui restent en surface : raccords des machines), `anchor` = { [clé] = vrai } (tuyaux d'un réseau EXISTANT, hors du tracé :
  une tuile du tracé qui en touche un reste en surface). Une tuile est ENTERRABLE si elle n'est pas gardée et a exactement deux
  voisines du même fluide, alignées (ni coude, ni embranchement, ni bout). Une suite maximale de L tuiles enterrables est toujours
  bordée de deux tuyaux de surface alignés : la conduite droite compte L + 2 tuyaux. Si L + 2 > Tu.MAX_RUN, la suite est découpée
  en tronçons égaux d'au plus reach + 1 tuiles ; chaque tronçon d'au moins Tu.MIN_SEG tuiles reçoit une pièce à chaque bout (raccord
  de surface tourné vers l'extérieur), ses tuiles du milieu sont libérées. Deux tronçons voisins se raccordent dos à dos.
  Rend { piece = { [clé] = direction }, mid = { [clé] = vrai }, pairs = { { a = {x, y, dir}, b = {x, y, dir}, n = tuiles libérées } },
         npieces, nmids } ; tout est trié (clés croissantes), aucun ordre de pairs() ne décide.

  Tu.buried(ents, infos) : relit des entités POSÉES (rôle Tu.ROLE) et rend les tuiles de leurs paires, bouts compris
  ({ {x, y, bout = vrai | nil} }, triées) : un planificateur suivant ne s'y raccorde pas (un bout ne se raccorde que par sa face
  ouverte, une tuile du milieu ne porte rien) et n'y pose pas de souterrain aligné (il s'apparierait avec la paire en place).

  Tu.next_conversion(plan, stock) : passe bornée des conduites EXISTANTES : la première paire du plan, si le stock porte ses deux
  pièces ; sinon (nil, raison). Un segment par appel.
]]

local Tu = {}

Tu.MAX_RUN = 5   -- règle du DC : au-delà de 5 tuyaux droits consécutifs, la conduite passe sous terre
Tu.MIN_SEG = 3   -- un tronçon plus court ne libère aucune tuile
Tu.ROLE = "tuyau_souterrain"

local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
local DIRS = { 0, 2, 4, 6 }

function Tu.tkey(x, y) return (x + 1048576) * 2097152 + (y + 1048576) end
local tkey = Tu.tkey
local function untkey(k) return math.floor(k / 2097152) - 1048576, k % 2097152 - 1048576 end
Tu.untkey = untkey

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Direction de la pièce dont le raccord de surface regarde (vx, vy), ou nil.
local function dir_open(under, vx, vy)
  for _, d in ipairs(DIRS) do
    local o = under.open and under.open[d]
    if o and o[1] == vx and o[2] == vy then return d end
  end
  return nil
end

--- Axe d'une tuile enterrable : 1 (horizontal), 2 (vertical), ou nil (gardée, coude, embranchement, bout).
local function axis_of(tubes, keep, anchor, k)
  if keep and keep[k] then return nil end
  local fl = tubes[k]
  local x, y = untkey(k)
  local n, h, v = 0, 0, 0
  for _, d in ipairs(DIRS) do
    local nk = tkey(x + DV[d][1], y + DV[d][2])
    if anchor and anchor[nk] then return nil end
    local g = tubes[nk]
    if g ~= nil then
      if g ~= fl then return nil end
      n = n + 1
      if DV[d][2] == 0 then h = h + 1 else v = v + 1 end
    end
  end
  if n ~= 2 then return nil end
  if h == 2 then return 1 end
  if v == 2 then return 2 end
  return nil
end

function Tu.plan(tubes, keep, under, anchor)
  local out = { piece = {}, mid = {}, pairs = {}, npieces = 0, nmids = 0 }
  if not (under and under.reach and under.reach >= Tu.MIN_SEG - 1) then return out end
  local axis = {}
  local keys = sorted_keys(tubes)
  for _, k in ipairs(keys) do axis[k] = axis_of(tubes, keep, anchor, k) or false end
  for _, k in ipairs(keys) do
    local a = axis[k]
    if a then
      local x, y = untkey(k)
      local vx, vy = (a == 1) and 1 or 0, (a == 2) and 1 or 0
      if axis[tkey(x - vx, y - vy)] ~= a then
        -- tête d'une suite : on la déroule dans le sens croissant
        local L = 1
        while axis[tkey(x + L * vx, y + L * vy)] == a do L = L + 1 end
        local da, db = dir_open(under, -vx, -vy), dir_open(under, vx, vy)
        if L + 2 > Tu.MAX_RUN and da and db then
          local span = under.reach + 1
          local nseg = math.ceil(L / span)
          local base, extra = math.floor(L / nseg), L % nseg
          local i = 0
          for sgi = 1, nseg do
            local m = base + ((sgi <= extra) and 1 or 0)
            if m >= Tu.MIN_SEG then
              local ax, ay = x + i * vx, y + i * vy
              local bx, by = x + (i + m - 1) * vx, y + (i + m - 1) * vy
              out.piece[tkey(ax, ay)] = da
              out.piece[tkey(bx, by)] = db
              for j = i + 1, i + m - 2 do out.mid[tkey(x + j * vx, y + j * vy)] = true end
              out.pairs[#out.pairs + 1] = { a = { x = ax, y = ay, dir = da }, b = { x = bx, y = by, dir = db }, n = m - 2 }
              out.npieces = out.npieces + 2
              out.nmids = out.nmids + m - 2
            end
            i = i + m
          end
        end
      end
    end
  end
  return out
end

--- Tuiles des paires d'entités posées. ents = { {name, x, y, dir, role} } ; infos = { [nom] = { under = {reach, open} } }.
function Tu.buried(ents, infos)
  local at, list = {}, {}
  for _, e in ipairs(ents or {}) do
    local u = e.role == Tu.ROLE and infos[e.name] and infos[e.name].under
    local o = u and u.open and u.open[e.dir or 0]
    if o then
      local k = tkey(math.floor(e.x), math.floor(e.y))
      if not at[k] then
        at[k] = { name = e.name, ox = o[1], oy = o[2], reach = u.reach }
        list[#list + 1] = k
      end
    end
  end
  table.sort(list)
  local seen, out = {}, {}
  local function add(k, bout)
    if not seen[k] then
      seen[k] = true
      local x, y = untkey(k)
      out[#out + 1] = { x = x, y = y, bout = bout or nil, k = k }
    end
  end
  for _, k in ipairs(list) do
    local p = at[k]
    add(k, true)
    local x, y = untkey(k)
    -- la galerie part à l'opposé du raccord de surface ; la partenaire est la première pièce de même nom tournée à l'inverse
    for step = 1, p.reach do
      local q = at[tkey(x - step * p.ox, y - step * p.oy)]
      if q then
        if q.name == p.name and q.ox == -p.ox and q.oy == -p.oy then
          for j = 1, step - 1 do add(tkey(x - j * p.ox, y - j * p.oy)) end
        end
        break
      end
    end
  end
  table.sort(out, function(a, b) return a.k < b.k end)
  for _, t in ipairs(out) do t.k = nil end
  return out
end

--- Passe bornée des conduites existantes : une paire par appel, seulement si ses deux pièces sont en stock.
function Tu.next_conversion(plan, stock)
  local pr = plan and plan.pairs and plan.pairs[1]
  if not pr then return nil, "aucune conduite droite a enterrer" end
  if (stock or 0) < 2 then return nil, "stock" end
  return pr
end

return Tu
