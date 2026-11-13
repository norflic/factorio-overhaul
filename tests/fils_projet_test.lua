--[[
  Lot UPS (13/11) : fils d'un projet fini (script/team/build.lua, Build.wire_poles). La règle d'avant lisait le moteur à chaque
  comparaison du tri et à chaque paire de poteaux, et cherchait chaque voisin déjà relié par une comparaison d'entités avec TOUS les
  poteaux (959 ms dans un seul tick à 72 min, graine 123456789). La nouvelle lit chaque poteau une fois.

  Q1 : sur des semis de poteaux tirés au sort (portées mêlées, poteaux déjà reliés, poteaux saturés à 5 fils qui refusent), la
       nouvelle règle fait EXACTEMENT les mêmes appels connect_neighbour, dans le même ordre, avec les mêmes réponses, et rend les
       mêmes comptes (fils posés, liaisons) que l'ancienne (recopiée ici telle quelle, témoin).
  Q2 : elle lit le moteur O(poteaux) fois, l'ancienne O(poteaux²) : compte des lectures de position et de prototype.
  Q3 : mutants de la nouvelle règle, vus par Q1.

  Usage : lua5.2 tests/fils_projet_test.lua    (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 print("OK     " .. msg) else fail_n = fail_n + 1 print("ECHEC : " .. msg) end
end

local function dist2(a, b) local dx, dy = a.x - b.x, a.y - b.y; return dx * dx + dy * dy end

--- L'ANCIENNE règle (script/team/build.lua de la 0.7.93, wire_project à partir de la liste des poteaux), recopiée telle quelle.
local function old_wire(poles)
  table.sort(poles, function(a, c) if a.position.y ~= c.position.y then return a.position.y < c.position.y end return a.position.x < c.position.x end)
  local cand = {}
  for a = 1, #poles do
    for c = a + 1, #poles do
      local pa, pc = poles[a], poles[c]
      local reach = math.min(pa.prototype.max_wire_distance, pc.prototype.max_wire_distance)
      local d2 = dist2(pa.position, pc.position)
      if d2 <= reach * reach + 1e-6 then cand[#cand + 1] = { d2, a, c } end
    end
  end
  table.sort(cand, function(u, v) if u[1] ~= v[1] then return u[1] < v[1] end if u[2] ~= v[2] then return u[2] < v[2] end return u[3] < v[3] end)
  local parent = {}
  for i = 1, #poles do parent[i] = i end
  local function find(x) while parent[x] ~= x do x = parent[x] end return x end
  for a = 1, #poles do
    for _, nb in ipairs((poles[a].neighbours or {}).copper or {}) do
      for c = 1, #poles do if poles[c] == nb then local ra, rc = find(a), find(c); if ra ~= rc then parent[rc] = ra end end end
    end
  end
  local n = 0
  for _, c in ipairs(cand) do
    local ra, rc = find(c[2]), find(c[3])
    if ra ~= rc then
      if poles[c[2]].connect_neighbour(poles[c[3]]) then
        n = n + 1
        parent[rc] = ra
      end
    end
  end
  local links, idx = 0, {}
  for i, ent in ipairs(poles) do idx[ent.unit_number] = i end
  for a = 1, #poles do
    for _, nb in ipairs((poles[a].neighbours or {}).copper or {}) do
      if nb.valid and idx[nb.unit_number] and idx[nb.unit_number] > a then links = links + 1 end
    end
  end
  return n, links
end

local function lcg(seed)
  local s = seed
  return function(n)
    s = (s * 1103515245 + 12345) % 2147483648
    return math.floor(s / 65536) % n + 1
  end
end

--- Semis de `n` poteaux (graine) : faux moteur qui compte les lectures et journalise les fils demandés.
local function world(seed, n)
  local roll = lcg(seed)
  local w = { calls = {}, reads = { position = 0, prototype = 0, neighbours = 0 }, poles = {} }
  local wires = {} -- [u] = { [u2] = true }
  local taken = {}
  local outsiders = {}
  local function degree(u)
    local d = 0
    for _ in pairs(wires[u]) do d = d + 1 end
    return d
  end
  local function make(u, x, y, reach)
    local raw = { x = x, y = y }
    local proto = { max_wire_distance = reach }
    local ent = { valid = true, unit_number = u }
    wires[u] = {}
    ent.connect_neighbour = function(other)
      local o = other.unit_number
      local okc = not wires[u][o] and degree(u) < 5 and degree(o) < 5
      w.calls[#w.calls + 1] = u .. ">" .. o .. (okc and "+" or "-")
      if okc then wires[u][o], wires[o][u] = true, true end
      return okc
    end
    setmetatable(ent, { __index = function(_, k)
      if k == "position" then
        w.reads.position = w.reads.position + 1
        return { x = raw.x, y = raw.y }
      elseif k == "prototype" then
        w.reads.prototype = w.reads.prototype + 1
        return proto
      elseif k == "neighbours" then
        w.reads.neighbours = w.reads.neighbours + 1
        local us = {}
        for o in pairs(wires[u]) do us[#us + 1] = o end
        table.sort(us)
        local list = {}
        for _, o in ipairs(us) do list[#list + 1] = w.by_u[o] end
        return { copper = list }
      end
    end })
    return ent
  end
  w.by_u = {}
  local reaches = { 7.5, 9, 30 }
  local u = 100
  while #w.poles < n do
    local x, y = roll(60) + 0.5, roll(60) + 0.5
    local key = x .. ":" .. y
    if not taken[key] then
      taken[key] = true
      u = u + roll(3)
      local e = make(u, x, y, reaches[roll(3)])
      w.by_u[u] = e
      w.poles[#w.poles + 1] = e
    end
  end
  -- un poteau HORS de la liste (autre projet, autre force) relié à quelques poteaux de la liste : un voisin inconnu de la règle
  for i = 1, 3 do
    u = u + 1
    local e = make(u, 200 + i, 200, 9)
    w.by_u[u] = e
    outsiders[#outsiders + 1] = e
  end
  -- fils déjà posés (le moteur relie un poteau ravivé à ses voisins), dont assez pour saturer certains poteaux
  for _ = 1, n do
    local a, b = w.poles[roll(n)], w.poles[roll(n)]
    if a ~= b and degree(a.unit_number) < 5 and degree(b.unit_number) < 5 then
      wires[a.unit_number][b.unit_number], wires[b.unit_number][a.unit_number] = true, true
    end
  end
  for i, o in ipairs(outsiders) do
    local a = w.poles[(i * 7) % n + 1]
    if degree(a.unit_number) < 5 then wires[a.unit_number][o.unit_number], wires[o.unit_number][a.unit_number] = true, true end
  end
  -- ordre d'arrivée de la liste : celui d'un relevé (mêlé), le même pour les deux règles
  for i = #w.poles, 2, -1 do
    local j = roll(i)
    w.poles[i], w.poles[j] = w.poles[j], w.poles[i]
  end
  w.calls = {}
  w.reads = { position = 0, prototype = 0, neighbours = 0 }
  return w
end

local function read_file(path)
  local fh = assert(io.open(path, "rb"))
  local src = fh:read("*a")
  fh:close()
  return src
end

local B = "script/team/build.lua"
local MUTANTS = {
  tri_inverse = { "  table.sort(recs, function(a, c) if a.y ~= c.y then return a.y < c.y end return a.x < c.x end)\n",
    "  table.sort(recs, function(a, c) if a.x ~= c.x then return a.x < c.x end return a.y < c.y end)\n" },
  portee_du_premier = { "      local reach = math.min(pa.reach, pc.reach)\n", "      local reach = pa.reach\n" },
  voisins_oublies = { "      if c then local ra, rc = find(a), find(c); if ra ~= rc then parent[rc] = ra end end\n", "\n" },
  refus_compte = { "      if recs[c[2]].ent.connect_neighbour(recs[c[3]].ent) then\n        n = n + 1\n        parent[rc] = ra\n      end\n",
    "      recs[c[2]].ent.connect_neighbour(recs[c[3]].ent)\n      n = n + 1\n      parent[rc] = ra\n" },
}

local function load_build(mutant)
  package.preload["script.team.build"] = nil
  if mutant then
    local src = read_file(B):gsub("\r\n", "\n")
    local s = MUTANTS[mutant]
    local a, b = src:find(s[1], 1, true)
    assert(a, "mutant : texte absent : " .. mutant)
    assert(not src:find(s[1], b + 1, true), "mutant : texte présent plusieurs fois : " .. mutant)
    src = src:sub(1, a - 1) .. s[2] .. src:sub(b + 1)
    package.preload["script.team.build"] = function(name) return assert(load(src, "=" .. B))(name) end
  end
  M.new_game({ p_busy = 0, p_nopath = 0, p_lost = 0 })
  return require("script.team.build")
end

--- Compare les deux règles sur `cases` semis ; rend le nombre d'écarts, le total des fils demandés, et les lectures de chacune.
local function compare(Build, cases)
  local diffs, calls, first = 0, 0, nil
  local ro, rn = { position = 0, prototype = 0 }, { position = 0, prototype = 0 }
  local poles_n = 0
  for k = 1, cases do
    local n = 5 + (k * 13) % 120
    local wa, wb = world(1000 + k, n), world(1000 + k, n)
    local no, lo = old_wire(wa.poles)
    local nn, ln = Build.wire_poles(wb.poles)
    local a, b = table.concat(wa.calls, " "), table.concat(wb.calls, " ")
    calls = calls + #wa.calls
    poles_n = poles_n + n
    ro.position, ro.prototype = ro.position + wa.reads.position, ro.prototype + wa.reads.prototype
    rn.position, rn.prototype = rn.position + wb.reads.position, rn.prototype + wb.reads.prototype
    if a ~= b or no ~= nn or lo ~= ln then
      diffs = diffs + 1
      first = first or string.format("semis %d (%d poteaux) : fils %d/%d, liaisons %d/%d, appels %s", k, n, no, nn, lo, ln, a == b and "égaux" or "différents")
    end
  end
  return diffs, calls, ro, rn, poles_n, first
end

local Build = load_build(nil)
local diffs, calls, ro, rn, poles_n, first = compare(Build, 200)
if first then print("   premier écart : " .. first) end
check(calls > 2000, "Q1 : des fils demandés sur 200 semis (" .. calls .. " appels connect_neighbour, refus compris)")
check(diffs == 0, "Q1 : mêmes appels connect_neighbour dans le même ordre, mêmes réponses, mêmes comptes que l'ancienne règle (" .. diffs .. " écart(s))")
check(rn.position == poles_n and rn.prototype == poles_n,
  string.format("Q2 : une lecture de position et de prototype par poteau (%d et %d pour %d poteaux ; l'ancienne : %d et %d)",
    rn.position, rn.prototype, poles_n, ro.position, ro.prototype))
for _, name in ipairs({ "tri_inverse", "portee_du_premier", "voisins_oublies", "refus_compte" }) do
  local okm, d = pcall(function() return (compare(load_build(name), 200)) end)
  check((not okm) or d > 0, string.format("Q3 : mutant %s vu (%s)", name, okm and (d .. " écart(s)") or ("plante : " .. tostring(d):sub(1, 80))))
end

print(string.format("[FILS] BILAN : %d OK%s", ok_n, fail_n > 0 and (", " .. fail_n .. " ECHEC(S)") or ""))
os.exit(fail_n == 0 and 0 or 1)
