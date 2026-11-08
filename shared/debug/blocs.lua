--[[
  Lot DEBUG-CERVEAU, V2 (directive du DC, 8/11) : les BLOCS d'organisation, leurs ENTRÉES et SORTIES, et leurs LIAISONS, tels que le cerveau les a
  enregistrés. Règles PURES (tests/debug_cerveau_test.lua). Entrées : des copies de nombres et de chaînes prises dans f.build (jamais d'entité).
  Les LIGNES (quai, bus, piquage, rapatriement), leur état et leurs tampons sont dans shared/debug/liens.lua (lot DEBUG-BLOCS) ; ce module ne garde
  que les entrées et sorties d'un bloc, les répartiteurs et le plafond d'objets.
]]

local Bl = {}

local function num(v) return type(v) == "number" and v == v and v or nil end

--- Répartiteurs de piquage : { x, y, item } triés.
function Bl.splitters(lines)
  local out = {}
  for _, l in ipairs(lines or {}) do
    -- le répartiteur n'existe que si la branche est posée : ni refusée, ni en chantier, ni en attente
    if l.kind == "piquage" and (l.status == "actif" or l.status == "inerte" or l.status == "coupe") then out[#out + 1] = { x = l.from.x, y = l.from.y, item = l.item } end
  end
  table.sort(out, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  return out
end

--- Entrées et sorties d'un bloc (copies prises à p.quais et p.outs) : { ins = { { x, y, item } }, outs = { { x, y } } }, au plus `max` de chaque.
function Bl.io(quais, outs, max)
  max = max or 6
  local r = { ins = {}, outs = {} }
  for _, q in ipairs(type(quais) == "table" and quais or {}) do
    if #r.ins >= max then break end
    if type(q) == "table" and num(q.x) and num(q.y) then r.ins[#r.ins + 1] = { x = q.x, y = q.y, item = type(q.item) == "string" and q.item or nil } end
  end
  for _, o in ipairs(type(outs) == "table" and outs or {}) do
    if #r.outs >= max then break end
    if type(o) == "table" and num(o.x) and num(o.y) then r.outs[#r.outs + 1] = { x = o.x, y = o.y } end
  end
  return r
end

--- Plafond d'objets de rendu : les `budget` premiers éléments d'une liste déjà classée par importance.
function Bl.cap(list, budget)
  local out = {}
  for i = 1, math.min(#list, math.max(0, budget or 0)) do out[i] = list[i] end
  return out
end

return Bl
