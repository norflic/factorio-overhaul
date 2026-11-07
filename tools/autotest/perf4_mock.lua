--[[
  Lot PERF4 : MICRO-MESURE au moteur simulé (indicative) du coût Lua de chaque portée du profileur du mod, et des appels au
  moteur faits sous chaque portée (find_entities_filtered, count_entities_filtered, find_nearest_enemy,
  find_non_colliding_position, request_path), avec leur rayon.

  Même partie que tests/iag_scale_mock.lua (4 factions, 30 PNJ, financées). Le profileur du mod est remplacé par des
  chronomètres os.clock (portées ordinaires ET fines, fmark/fcredit compris) ; le temps passé DANS les fonctions du moteur
  simulé (balayages linéaires en Lua, sans rapport avec le vrai moteur) est retiré de toutes les portées ouvertes : il reste le
  coût Lua propre du mod, et le NOMBRE d'appels au moteur (dont le coût réel se mesure en jeu, pas ici).

  Usage (depuis la racine d'une source du mod) :
    lua5.2 <chemin>/perf4_mock.lua <minutes> <fichier de sortie> [échauffement en minutes = 0] [diag] [fn]
  Rien n'est écrit dans global ; aucune décision du mod ne lit ces chronomètres.
]]
package.path = "./?.lua;" .. package.path
local minutes = tonumber(arg[1]) or 20
local out_path = arg[2] or "perf4_mock.txt"
local warm = tonumber(arg[3]) or 0
local M = require("tests.mock_engine")

local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end

M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
M.world().settings["fo-recruit-idle-max"] = 60
M.world().settings["fo-war-workers"] = 30

---------------------------------------------------------------------------------------------------
-- Chronomètres
---------------------------------------------------------------------------------------------------
local clock = os.clock
local on = false
local E = 0 -- temps cumulé passé dans le moteur simulé
local stack = {} -- { name, t0, e0, child }
local incl, self_t, calls = {}, {}, {}
local marks = {}
local eng = {} -- [portée .. " | " .. fonction .. " r" .. rayon] = { n, t }

local function push(name)
  stack[#stack + 1] = { name = name, t0 = clock(), e0 = E, child = 0 }
end
local function pop(name)
  -- dépile jusqu'à la portée nommée (une portée oubliée ne casse pas la mesure)
  for i = #stack, 1, -1 do
    if stack[i].name == name then
      local now, en = clock(), E
      for j = #stack, i, -1 do
        local fr = stack[j]
        local d = (now - fr.t0) - (en - fr.e0)
        if on then
          incl[fr.name] = (incl[fr.name] or 0) + d
          self_t[fr.name] = (self_t[fr.name] or 0) + d - fr.child
          calls[fr.name] = (calls[fr.name] or 0) + 1
        end
        stack[j] = nil
        local parent = stack[j - 1]
        if parent then parent.child = parent.child + d end
      end
      return
    end
  end
end

local P = require("script.core.profiler")
P.start = function(name) push(name) end
P.stop = function(name) pop(name) end
P.fstart = function(name) push(name) end
P.fstop = function(name) pop(name) end
P.fmark = function(slot) marks[slot] = { t0 = clock(), e0 = E } end
P.fcredit = function(slot, name)
  local m = marks[slot]
  if not m then return end
  local d = (clock() - m.t0) - (E - m.e0)
  if on then
    incl[name] = (incl[name] or 0) + d
    self_t[name] = (self_t[name] or 0) + d -- attribuée après coup : comptée en propre, sans retrait aux mères
    calls[name] = (calls[name] or 0) + 1
  end
  marks[slot] = nil
end
P.fine = function() return true end
-- Profiler.enabled() allume des journaux et des mesures de diagnostic (board.lua note_miss, military.lua, soldats.lua...) : la
-- partie du DC tourne SANS profileur, donc faux par défaut ; « diag » en 4e argument les allume (coût du profileur lui-même).
local opts = {}
for i = 4, #arg do opts[arg[i]] = true end
local diag = opts.diag == true
P.enabled = function() return diag end

---------------------------------------------------------------------------------------------------
-- Appels au moteur simulé : comptés par portée, leur temps retiré des portées
---------------------------------------------------------------------------------------------------
local surface = M.world().surface
local depth = 0
local function radius_of(t)
  if type(t) ~= "table" then return "-" end
  if t.radius then return tostring(math.floor(t.radius)) end
  if t.max_distance then return tostring(math.floor(t.max_distance)) end
  if t.area then
    local a = t.area
    local lt, rb = a[1] or a.left_top, a[2] or a.right_bottom
    if lt and rb then
      local w = (rb.x or rb[1]) - (lt.x or lt[1])
      local h = (rb.y or rb[2]) - (lt.y or lt[2])
      return string.format("aire%dx%d", math.floor(w + 0.5), math.floor(h + 0.5))
    end
  end
  if t.position then return "point" end
  return "SURFACE" -- ni zone ni rayon : toute la surface
end
for _, fn in ipairs({ "find_entities_filtered", "count_entities_filtered", "find_nearest_enemy",
    "find_non_colliding_position", "request_path", "find_entity", "find_entities", "find_tiles_filtered",
    "count_tiles_filtered", "can_place_entity" }) do
  local orig = surface[fn]
  if orig then
    surface[fn] = function(...)
      if depth > 0 then return orig(...) end -- appel interne du moteur simulé : déjà compté par l'appel extérieur
      depth = depth + 1
      local t0 = clock()
      local r1, r2 = orig(...)
      local d = clock() - t0
      depth = depth - 1
      E = E + d
      if on then
        local first = select(1, ...)
        local key = (stack[#stack] and stack[#stack].name or "-") .. " | " .. fn .. " r" .. radius_of(first)
        local c = eng[key]
        if not c then c = { n = 0, t = 0 }; eng[key] = c end
        c.n = c.n + 1
        c.t = c.t + d
      end
      return r1, r2
    end
  end
end

-- Fonctions pures chronométrées comme des portées (« fn:... ») : elles sont appelées par leur table (Mod.f(...)), le
-- remplacement les attrape toutes.
local function wrap(mod, modname, fname)
  local m = require(modname)
  local orig = m[fname]
  if type(orig) ~= "function" then return end
  local scope = "fn:" .. mod .. "." .. fname
  m[fname] = function(...)
    push(scope)
    local r = table.pack(orig(...))
    pop(scope)
    return table.unpack(r, 1, r.n)
  end
end
if opts.fn then -- (option « fn » : le surcoût des enveloppes fausse un peu les portées mères)
  wrap("G", "shared.ai3.graphe", "prepare")
  wrap("G", "shared.ai3.graphe", "state_key")
  wrap("G", "shared.ai3.graphe", "unfold")
  wrap("Gen", "shared.ai3.general", "value")
  wrap("Gen", "shared.ai3.general", "resource_values")
  wrap("Gen", "shared.ai3.general", "summary")
  wrap("Gen", "shared.ai3.general", "choose")
  wrap("Gen", "shared.ai3.general", "chains")
end

assert(remote.call("factorio-overhaul", "war_start", 4, 100, nil, 320) == true)
remote.call("factorio-overhaul", "war_fund", 3000)
if warm > 0 then M.run_ticks(warm * 3600) end
on = true
local w0 = clock()
local E0 = E
M.run_ticks(minutes * 3600)
local wall = clock() - w0
local eng_t = E - E0
on = false

local ticks = minutes * 3600
local names = {}
for k in pairs(self_t) do names[#names + 1] = k end
table.sort(names, function(a, b) if self_t[a] ~= self_t[b] then return self_t[a] > self_t[b] end return a < b end)
local f = assert(io.open(out_path, "w"))
f:write(string.format("# perf4_mock : %d min (%d ticks) après %d min d'échauffement ; horloge %.2f s dont moteur simulé %.2f s\n",
  minutes, ticks, warm, wall, eng_t))
f:write("# portée ; propre µs/tick ; incluse µs/tick ; passages ; µs propres/passage\n")
for _, k in ipairs(names) do
  f:write(string.format("%-34s %9.2f %9.2f %8d %9.1f\n", k, self_t[k] * 1e6 / ticks, incl[k] * 1e6 / ticks, calls[k],
    self_t[k] * 1e6 / math.max(1, calls[k])))
end
f:write("# appels au moteur par portée (portée | fonction rayon) ; nombre ; par seconde de jeu\n")
local keys = {}
for k in pairs(eng) do keys[#keys + 1] = k end
table.sort(keys, function(a, b) if eng[a].n ~= eng[b].n then return eng[a].n > eng[b].n end return a < b end)
for _, k in ipairs(keys) do
  f:write(string.format("%-70s %8d %8.2f/s\n", k, eng[k].n, eng[k].n * 60 / ticks))
end
-- Taille de `global` (sérialisation approchée : nombre d'octets d'un dump texte, tables partagées comptées une fois) par clé de
-- premier et de deuxième niveau : la sauvegarde du jeu écrit `global`, une sauvegarde bloquante dure d'autant plus.
local seen = {}
local function size(v)
  local t = type(v)
  if t == "table" then
    if seen[v] then return 4 end
    seen[v] = true
    local n = 2
    for k, x in pairs(v) do n = n + size(k) + size(x) + 2 end
    return n
  elseif t == "string" then return #v + 2
  elseif t == "number" then return 8
  elseif t == "boolean" then return 1
  end
  return 4
end
local g = _G.global or {}
local rows = {}
local total = 0
for k, v in pairs(g) do
  local s = size(v)
  total = total + s
  rows[#rows + 1] = { tostring(k), s, v }
end
table.sort(rows, function(a, b) return a[2] > b[2] end)
f:write(string.format("# global : %.2f Mo en tout (approché)\n", total / 1e6))
for i = 1, math.min(12, #rows) do
  local r = rows[i]
  f:write(string.format("%-30s %10.1f ko\n", r[1], r[2] / 1e3))
  if type(r[3]) == "table" then
    local sub = {}
    seen = {}
    for k, v in pairs(r[3]) do sub[#sub + 1] = { tostring(k), size(v) } end
    table.sort(sub, function(a, b) return a[2] > b[2] end)
    for j = 1, math.min(8, #sub) do f:write(string.format("    %-36s %10.1f ko\n", sub[j][1], sub[j][2] / 1e3)) end
  end
end
f:close()
print("fini", out_path, string.format("horloge %.1f s", wall))
