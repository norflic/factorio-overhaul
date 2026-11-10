--[[
  CHAMP, fonderie au bout d'un tapis (lot CHAMP). PUR : aucune API Factorio, aucun nom d'objet ; lu par shared/team/champ.lua.

  Le DC : « des rangées de 10 de fours ou de N fours justement en fonction du débit parce que le débit pourra augmenter ».
  N = plafond(débit du tapis / débit d'un four). Les fours vont par MODULES de largeur 2 × côté + 3 le long du tapis, deux de chaque côté :
      [four A][bras][coffre][bras][four B]     rangée la plus loin du tapis : bras four -> coffre de SORTIE
      [four A][bras][coffre][bras][four B]     rangée près du tapis : bras coffre de COMBUSTIBLE -> four (four à combustible)
      [ .. bras ..][poteau][.. bras .. ]       bras tapis -> four ; poteau au milieu (couvre les bras des deux côtés du tapis)
      ========== tapis ==========
  (et le miroir de l'autre côté). Les modules s'AJOUTENT au bout : agrandir la fonderie ne déplace rien. Sans four (charbon,
  pierre) : colonnes de bras tapis -> coffre, un poteau tous les 2 × portée + 1.
  Repère : u le long du tapis (s_edge = première colonne, `side` = sens de marche), v en travers ; rangée du tapis `b`.
]]

local Fd = {}

Fd.EPS = 1e-9

--- Fours qui absorbent `flow` (objets/s), un four en traitant `rate`.
function Fd.furnaces_for(flow, rate)
  if not (flow and rate and rate > 0) or flow <= 0 then return 0 end
  return math.ceil(flow / rate - Fd.EPS)
end

--- Nombre de fours (ou de bras vers coffres) pour `flow`.
function Fd.count(spec, flow)
  local n
  if spec.furnace then n = Fd.furnaces_for(flow, spec.furnace.rate)
  else n = math.ceil(flow / ((spec.inserter and spec.inserter.rate) or 1) - Fd.EPS) end
  return math.max(1, n)
end

--- Capacité (objets/s) de `count` fours ou bras.
function Fd.capacity(spec, count)
  if spec.furnace then return count * spec.furnace.rate end
  return count * ((spec.inserter and spec.inserter.rate) or 1)
end

--- Entités (espace u, v) : { kind, u (plus petite colonne), v (plus petite rangée), size, du, dv, role, module }, et la longueur.
function Fd.layout(spec, b, side, s_edge, count)
  local ents = {}
  local function put(kind, col, row, size, du, dv, role, m)
    local ua, ub = s_edge + side * col, s_edge + side * (col + size - 1)
    ents[#ents + 1] = { kind = kind, u = math.min(ua, ub), v = row, size = size, du = du, dv = dv, role = role, module = m }
  end
  local len, placed, m = 0, 0, 0
  local f = spec.furnace
  if f then
    local fs = f.size
    local W = 2 * fs + 3
    while placed < count do
      local c0 = m * W
      local here = { [-1] = 0, [1] = 0 }
      for _, half in ipairs({ { col = 0, ins = fs - 1, arm = fs }, { col = fs + 3, ins = fs + 3, arm = fs + 2 } }) do
        local to_furnace = half.col == 0 and -side or side -- le long de u, du coffre vers ce four
        for _, sg in ipairs({ -1, 1 }) do
          if placed < count then
            placed = placed + 1
            here[sg] = here[sg] + 1
            put("four", c0 + half.col, sg < 0 and (b - 1 - fs) or (b + 2), fs, 0, 0, nil, m)
            put("bras", c0 + half.ins, b + sg, 1, 0, -sg, nil, m)                      -- prend sur le tapis
            put("bras", c0 + half.arm, b + (1 + fs) * sg, 1, to_furnace, 0, nil, m)    -- prend dans le four
            if f.fuel then put("bras", c0 + half.arm, b + 2 * sg, 1, -to_furnace, 0, nil, m) end -- prend au coffre
          end
        end
      end
      for _, sg in ipairs({ -1, 1 }) do
        if here[sg] > 0 then
          put("coffre", c0 + fs + 1, b + (1 + fs) * sg, 1, 0, 0, "sortie", m)
          if f.fuel then put("coffre", c0 + fs + 1, b + 2 * sg, 1, 0, 0, "combustible", m) end
          put("poteau", c0 + fs + 1, b + sg, 1, 0, 0, nil, m)
        end
      end
      m = m + 1
      len = c0 + W
    end
  else
    local R = spec.pole.reach
    local W = 2 * R + 1
    while placed < count do
      local c0 = m * W
      for col = 0, W - 1 do
        if col ~= R then
          for _, sg in ipairs({ -1, 1 }) do
            if placed < count then
              placed = placed + 1
              put("bras", c0 + col, b + sg, 1, 0, -sg, nil, m)
              put("coffre", c0 + col, b + 2 * sg, 1, 0, 0, "sortie", m)
            end
          end
        end
      end
      put("poteau", c0 + R, b - 1, 1, 0, 0, nil, m)
      m = m + 1
      len = c0 + W
    end
  end
  return ents, len
end

--- Colonne (relative) des poteaux de la fonderie, où viennent les rangées de poteaux du champ.
function Fd.pole_col(spec)
  if spec.furnace then return spec.furnace.size + 1 end
  return spec.pole.reach
end

--- Place de la fonderie d'un groupe : (entités, longueur, s_edge, nombre) ou nil. `free(u, v)`, `is_res(u, v)` : lectures du
--- champ ; la fonderie recule (jusqu'à `shift` tuiles) pour trouver une place libre HORS DE TOUTE RESSOURCE (F500, directive du DC du
--- 10/11, 22 h : aucun four sur une tuile de ressource ; `is_res` = le minerai visé ET les autres ressources ; plus de seconde passe
--- qui acceptait le minerai) ; aucune place : nil (le groupe n'a pas de fonderie de ce côté).
function Fd.place(spec, b, side, edge, flow, gap, shift, free, is_res)
  local count = Fd.count(spec, flow)
  for t = 0, shift do
    local s_edge = edge + side * (gap + 1 + t)
    local list, len = Fd.layout(spec, b, side, s_edge, count)
    local ok = true
    -- le tapis : du bord du champ jusqu'au bout de la fonderie
    for u = edge + side, s_edge + side * (len - 1), side do if not free(u, b) then ok = false break end end
    for _, e in ipairs(list) do
      if not ok then break end
      for u = e.u, e.u + e.size - 1 do
        for v = e.v, e.v + e.size - 1 do
          if not free(u, v) or is_res(u, v) then ok = false end
        end
      end
    end
    if ok then return list, len, s_edge, count end
  end
  return nil
end

return Fd
