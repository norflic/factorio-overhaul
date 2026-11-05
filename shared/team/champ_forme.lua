--[[
  CHAMP-FORME (lot CHAMP-COUVERTURE, étape 0, accord du lead du 5/11) : la FORME d'un champ (entrées de la règle pure Ch.plan) écrite
  en UNE ligne de journal, puis relue hors jeu pour rejouer le plan à l'identique. PUR : aucune API Factorio, aucun nom d'objet.

  Pourquoi : la partie du DC du 5/11 donnait une couverture planifiée de 35,7 % (13 016 / 36 509 tuiles), sans que la cause puisse
  être prouvée plan par plan (les tuiles du gisement et les obstacles n'étaient pas au journal).

  Fo.encode(spec, res) -> chaîne sans saut de ligne ; res = { covered, tiles, drills, bands } (résultat attendu, comparé au rejeu).
  Fo.decode(chaine)    -> spec, res ; ou nil, raison.
  Champs (séparés par " | ", « clé=valeur », un champ vide est omis) :
    v1                       version
    r=c/t,d,b                tuiles couvertes / tuiles de minerai, foreuses, bandes posées (résultat du plan en jeu)
    d=size,reach,rate        foreuse          p=reach,wire       poteau          b=lane,lane,...   tapis
    f=size,rate,fuel,frate   four (fuel 0/1)  i=rate             bras            s=max_side        g=design
    l=splitter,underground   logistique (0/1, portée ; 0 = aucun souterrain)     t=x,y             cible (QG)
    nf=n                     tuiles étrangères comptées (journal seulement)
    O=, M=, F=, S=           minerai (liste), nos tuiles, autres ressources minables, arbres et rochers : plages par rangée
                             (« ~ » : ensemble présent mais vide)
    X=                       obstacles : plages par rangée suivies d'une lettre de classe (e eau, f falaise, r réserve, c couloir,
                             b bâtiment ou autre)
    C=rate,nforeign/plages   tuiles de charbon de la colonne, CF= leurs ressources étrangères, U=x,y;x,y;... souterrains posés
  Plages : « y:x+n,x+n;y:... » (rangées par y croissant, plages par x croissant, n tuiles à partir de x).
  Ordre des listes relues : minerai et charbon par (x, y) croissants (le runtime trie le charbon ainsi ; le plan ne dépend pas de
  l'ordre du minerai : tests/champ_forme_test.lua §2), souterrains dans l'ordre écrit.
  Déterminisme : les clés des ensembles sont TRIÉES avant l'écriture ; aucun `pairs` ne décide de rien.
]]

local Fo = {}

Fo.VERSION = "v1"
local BASE = 50000
local function key(x, y) return (x + BASE) * 100000 + (y + BASE) end -- même clé que Ch.key
local function unkey(k)
  local x = math.floor(k / 100000)
  return x - BASE, (k - x * 100000) - BASE
end
Fo.key, Fo.unkey = key, unkey

Fo.CLASS = { eau = "e", cliff = "f", reserve = "r", couloir = "c" }
Fo.UNCLASS = { e = "eau", f = "cliff", r = "reserve", c = "couloir", b = "b" }
local function class_of(v)
  if type(v) == "string" and Fo.CLASS[v] then return Fo.CLASS[v] end
  return "b"
end

local function num(v)
  if v == math.floor(v) and math.abs(v) < 2 ^ 53 then return string.format("%d", v) end
  return string.format("%.17g", v)
end

--- Tuiles (x, y) triées par y puis x, avec leur lettre (ou "") : rend la chaîne des plages.
local function rle(cells)
  table.sort(cells, function(a, b)
    if a[2] ~= b[2] then return a[2] < b[2] end
    return a[1] < b[1]
  end)
  local rows, i = {}, 1
  while i <= #cells do
    local y = cells[i][2]
    local runs = {}
    while i <= #cells and cells[i][2] == y do
      local x0, c = cells[i][1], cells[i][3] or ""
      local n = 1
      while i + n <= #cells and cells[i + n][2] == y and cells[i + n][1] == x0 + n and (cells[i + n][3] or "") == c do n = n + 1 end
      runs[#runs + 1] = x0 .. "+" .. n .. c
      i = i + n
    end
    rows[#rows + 1] = y .. ":" .. table.concat(runs, ",")
  end
  return table.concat(rows, ";")
end

local function set_cells(set, classed)
  local ks = {}
  for k in pairs(set or {}) do if set[k] then ks[#ks + 1] = k end end
  table.sort(ks)
  local cells = {}
  for _, k in ipairs(ks) do
    local x, y = unkey(k)
    cells[#cells + 1] = { x, y, classed and class_of(set[k]) or nil }
  end
  return cells
end

local function flat_cells(flat)
  local cells, seen = {}, {}
  for i = 1, #(flat or {}) - 1, 2 do
    local k = key(flat[i], flat[i + 1])
    if not seen[k] then seen[k] = true; cells[#cells + 1] = { flat[i], flat[i + 1] } end
  end
  return cells
end

--- Ligne de la forme (voir plus haut).
function Fo.encode(spec, res)
  local out = { Fo.VERSION }
  local function put(k, v) if v ~= nil and v ~= "" then out[#out + 1] = k .. "=" .. v end end
  res = res or {}
  put("r", string.format("%d/%d,%d,%d", res.covered or 0, res.tiles or 0, res.drills or 0, res.bands or 0))
  local d, p = spec.drill or {}, spec.pole or {}
  put("d", num(d.size or 0) .. "," .. num(d.reach or 0) .. "," .. num(d.rate or 0))
  put("p", num(p.reach or 0) .. "," .. num(p.wire or 0))
  local lanes = {}
  for _, bt in ipairs(spec.belts or {}) do lanes[#lanes + 1] = num(bt.lane) end
  put("b", table.concat(lanes, ","))
  local f = spec.furnace
  if f then put("f", num(f.size) .. "," .. num(f.rate) .. "," .. (f.fuel and "1" or "0") .. "," .. num(f.fuel_rate or 0) .. "," .. num(f.yield or 1)) end
  if spec.inserter then put("i", num(spec.inserter.rate or 0)) end
  if spec.max_side then put("s", num(spec.max_side)) end
  if spec.design then put("g", tostring(spec.design)) end
  local lg = spec.logistics
  if lg then put("l", (lg.splitter and "1" or "0") .. "," .. num(lg.underground or 0)) end
  if spec.target then put("t", num(spec.target.x) .. "," .. num(spec.target.y)) end
  if spec.nforeign then put("nf", num(spec.nforeign)) end
  put("O", rle(flat_cells(spec.ore)))
  put("X", rle(set_cells(spec.blocked, true)))
  put("M", rle(set_cells(spec.mine)))
  put("F", rle(set_cells(spec.foreign)))
  -- un ensemble présent mais vide s'écrit « ~ » (relu vide, pas absent)
  local function put_set(k, set) if set ~= nil then local r = rle(set_cells(set)); put(k, r ~= "" and r or "~") end end
  put_set("S", spec.soft)
  local co = spec.coal
  if co then
    put("C", num(co.rate or 0) .. "," .. num(co.nforeign or 0) .. "/" .. rle(flat_cells(co.tiles)))
    put_set("CF", co.foreign)
  end
  if spec.ug_tiles then
    local u = {}
    for _, t in ipairs(spec.ug_tiles) do u[#u + 1] = num(t[1]) .. "," .. num(t[2]) end
    put("U", table.concat(u, ";"))
  end
  return table.concat(out, " | ")
end

local function nums(s)
  local t = {}
  for x in string.gmatch(s or "", "[^,]+") do t[#t + 1] = tonumber(x) end
  return t
end

--- Plages -> liste de { x, y, lettre }, ou nil, raison.
local function unrle(s)
  local cells = {}
  if s == nil or s == "" then return cells end
  for row in string.gmatch(s, "[^;]+") do
    local y, runs = string.match(row, "^(-?%d+):(.*)$")
    if not y then return nil, "rangee illisible : " .. row end
    y = tonumber(y)
    for run in string.gmatch(runs, "[^,]+") do
      local x0, n, c = string.match(run, "^(-?%d+)%+(%d+)(%a?)$")
      if not x0 then return nil, "plage illisible : " .. run end
      x0, n = tonumber(x0), tonumber(n)
      for x = x0, x0 + n - 1 do cells[#cells + 1] = { x, y, c } end
    end
  end
  return cells
end

local function to_set(cells, classed)
  local s = {}
  for _, c in ipairs(cells) do s[key(c[1], c[2])] = classed and (Fo.UNCLASS[c[3]] or "b") or true end
  return s
end

local function to_flat_xy(cells)
  table.sort(cells, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
  local flat = {}
  for _, c in ipairs(cells) do flat[#flat + 1] = c[1]; flat[#flat + 1] = c[2] end
  return flat
end

--- Relecture d'une ligne (la partie après « : » du journal, ou la ligne entière : tout ce qui précède « v1 » est ignoré).
function Fo.decode(line)
  local body = string.match(line or "", Fo.VERSION .. " | (.*)$")
  if not body then return nil, "pas de forme " .. Fo.VERSION end
  local fields = {}
  for part in string.gmatch(body .. " | ", "(.-) | ") do
    local k, v = string.match(part, "^(%a+)=(.*)$")
    if not k then return nil, "champ illisible : " .. part end
    fields[k] = v
  end
  local res = {}
  do
    local c, t, dr, bd = string.match(fields.r or "", "^(%d+)/(%d+),(%d+),(%d+)$")
    if not c then return nil, "resultat illisible" end
    res = { covered = tonumber(c), tiles = tonumber(t), drills = tonumber(dr), bands = tonumber(bd) }
  end
  local spec = {}
  local d, p = nums(fields.d), nums(fields.p)
  spec.drill = { size = d[1], reach = d[2], rate = d[3] }
  spec.pole = { reach = p[1], wire = p[2] }
  spec.belts = {}
  for _, l in ipairs(nums(fields.b)) do spec.belts[#spec.belts + 1] = { lane = l } end
  if fields.f then
    local f = nums(fields.f)
    spec.furnace = { size = f[1], rate = f[2], fuel = f[3] == 1, fuel_rate = (f[4] and f[4] > 0) and f[4] or nil }
    if f[5] and f[5] ~= 1 then spec.furnace.yield = f[5] end
  end
  if fields.i then spec.inserter = { rate = tonumber(fields.i) } end
  if fields.s then spec.max_side = tonumber(fields.s) end
  if fields.g then spec.design = fields.g end
  if fields.l then
    local l = nums(fields.l)
    spec.logistics = { splitter = l[1] == 1, underground = (l[2] and l[2] > 0) and l[2] or nil }
  end
  if fields.t then local t = nums(fields.t); spec.target = { x = t[1], y = t[2] } end
  if fields.nf then spec.nforeign = tonumber(fields.nf) end
  local function cells(k)
    if fields[k] == "~" then return {} end
    local c, why = unrle(fields[k])
    if not c then error(k .. " : " .. why) end
    return c
  end
  local ok, err = pcall(function()
    spec.ore = to_flat_xy(cells("O"))
    spec.blocked = to_set(cells("X"), true)
    spec.mine = to_set(cells("M"))
    spec.foreign = to_set(cells("F"))
    if fields.S then spec.soft = to_set(cells("S")) end
    if fields.C then
      local rate, nfo, rest = string.match(fields.C, "^([^,]+),([^/]+)/(.*)$")
      if not rate then error("C illisible") end
      local cc, why = unrle(rest)
      if not cc then error("C : " .. why) end
      spec.coal = { rate = tonumber(rate), nforeign = tonumber(nfo), tiles = to_flat_xy(cc) }
      if spec.coal.rate == 0 then spec.coal.rate = nil end
      if fields.CF then spec.coal.foreign = to_set(cells("CF")) end
    end
    if fields.U then
      spec.ug_tiles = {}
      for pair in string.gmatch(fields.U, "[^;]+") do
        local x, y = string.match(pair, "^(-?%d+),(-?%d+)$")
        if not x then error("U illisible : " .. pair) end
        spec.ug_tiles[#spec.ug_tiles + 1] = { tonumber(x), tonumber(y) }
      end
    end
  end)
  if not ok then return nil, tostring(err) end
  return spec, res
end

return Fo
