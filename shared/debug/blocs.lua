--[[
  Lot DEBUG-CERVEAU, V2 (directive du DC, 8/11) : les BLOCS d'organisation, leurs ENTRÉES et SORTIES, et leurs LIAISONS, tels que le cerveau les a
  enregistrés. Règles PURES (tests/debug_cerveau_test.lua). Entrées : des copies de nombres et de chaînes prises dans f.build (jamais d'entité).
    liaison de quai   projet dont spec.liaison a un coffre de SORTIE d'un bloc (src) et le coffre d'ENTRÉE d'un autre (dock) ;
    tronc de bus      la même, avec lc.bus (script/team/bus.lua) ;
    branche de piquage lc.piquage : du répartiteur (lc.geo, posé sur un tapis existant) au coffre d'entrée (dock) ;
    tampon            le coffre d'entrée (dock) d'une liaison ou d'un piquage non refusé : il est « tampon » de sa ligne.
  La « ligne de rapatriement » du DC n'a pas de structure lisible dans cette version : la vue le dit (Bl.MISSING), elle ne l'invente pas.
]]

local Bl = {}

Bl.KINDS = { "quai", "bus", "piquage" }
Bl.MISSING = { "rapatriement" }
Bl.DEAD = { refuse = true }

local function num(v) return type(v) == "number" and v == v and v or nil end

--- Genre d'une liaison (lc = spec.liaison).
function Bl.kind(lc)
  if type(lc) ~= "table" then return nil end
  if lc.piquage then return "piquage" end
  if lc.bus then return "bus" end
  return "quai"
end

local function pt(t)
  if type(t) == "table" and num(t.x) and num(t.y) then return { x = t.x, y = t.y } end
  return nil
end

--- Lignes de liaison. projects : liste de { pid, state, lc = spec.liaison (ou nil) }. Rend, triées par pid :
--- { pid, kind, item, state, from = {x,y}, to = {x,y}, dock_pid, src_pid, done }. Un projet refusé est écarté ; une liaison sans extrémités lisibles aussi.
function Bl.lines(projects)
  local out = {}
  for _, p in ipairs(type(projects) == "table" and projects or {}) do
    local lc = type(p) == "table" and p.lc
    local kind = Bl.kind(lc)
    if kind and not Bl.DEAD[p.state] then
      local to = pt(lc.dock)
      local from = (kind == "piquage") and pt(lc.geo) or pt(lc.src)
      if from and to then
        out[#out + 1] = { pid = p.pid, kind = kind, item = type(lc.item) == "string" and lc.item or nil, state = p.state, from = from, to = to,
          dock_pid = lc.dock and lc.dock.pid, src_pid = (kind ~= "piquage" and lc.src) and lc.src.pid or nil, done = p.state == "fini" }
      end
    end
  end
  table.sort(out, function(a, b) return a.pid < b.pid end)
  return out
end

--- Coffres tampons : un par extrémité d'entrée de ligne. Rend { x, y, item, kind, source } triés par position ; source = pid du bloc d'où vient la ligne
--- (nil pour un piquage : il vient d'un tapis).
function Bl.buffers(lines)
  local out, seen = {}, {}
  for _, l in ipairs(lines or {}) do
    local key = string.format("%.1f:%.1f", l.to.x, l.to.y)
    if not seen[key] then
      seen[key] = true
      out[#out + 1] = { x = l.to.x, y = l.to.y, item = l.item, kind = l.kind, source = l.src_pid, pid = l.dock_pid }
    end
  end
  table.sort(out, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  return out
end

--- Répartiteurs de piquage : { x, y, item } triés.
function Bl.splitters(lines)
  local out = {}
  for _, l in ipairs(lines or {}) do
    if l.kind == "piquage" then out[#out + 1] = { x = l.from.x, y = l.from.y, item = l.item, done = l.done } end
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
