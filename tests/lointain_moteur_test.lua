--[[
  Lot CENTRALE : la centrale à distance au MOTEUR SIMULÉ (tests/mock_engine.lua) : une guerre à 2 factions sur une carte sans
  aucune eau dans le treillis (±140 tuiles du QG) ni dans l'oeil du QG (160 tuiles), avec un lac à l'est à 450 tuiles du QG de la
  première faction. Contrôles : la centrale est planifiée en « lointain » (rive du lac, jamais d'étang posé : aucune tuile
  écrite par script), la ligne de poteaux forme une chaîne continue à la portée des données, aucun poteau sur l'eau, deux
  parties identiques donnent le même plan, et un lac absent laisse la centrale en attente (exploration demandée, pas de
  refus). Le moteur simulé ne génère pas de terrain (tout est « généré ») et ne pose aucun fantôme à distance : ce test prouve
  la DÉCISION (plan, rive, ligne), pas la pose (moteur réel : banc etape1-guide).
  Usage : lua5.2 tests/lointain_moteur_test.lua   (depuis la racine du mod ; environ 20 s)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local MIN = 3600
local pass, fail = 0, 0
local function check(c, msg) if c then pass = pass + 1 else fail = fail + 1; print("  ECHEC : " .. msg) end end

local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end

--- Lac à l'est (x de 640 à 760, y de −400 à 400) ; `lake` faux : aucune eau nulle part.
local function play(minutes, lake)
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "normal", ia3e = true,
    tile_at = function(x, y)
      if lake and x >= 640 and x < 760 and y >= -400 and y < 400 then return "water" end
      return "grass-1"
    end })
  M.command("fo-war", "start 2 60 8 320")
  M.run_ticks(minutes * MIN)
  local logs = {}
  for _, l in ipairs(M.world().logs) do if l:find("FO%-LOINTAIN") or l:find("FO%-IA1D") then logs[#logs + 1] = l end end
  local res = {}
  for _, id in ipairs({ 1, 2 }) do
    local f = global.fo.war.factions[id]
    local b = f and f.build
    local p = b and b.projects[b.plant or 0]
    -- la centrale peut avoir été annulée puis redemandée : le projet courant est celui de b.plant
    res[#res + 1] = { f = f, b = b, p = p }
  end
  return res, logs, M.world()
end

local function sig(res)
  local out = {}
  for i, r in ipairs(res) do
    local p = r.p
    local s = tostring(i) .. ":" .. tostring(p and p.state) .. ":" .. tostring(p and p.parts[1] and p.parts[1].lot)
    if p then
      for _, e in ipairs(p.ents) do s = s .. string.format("|%s@%.1f,%.1f", e.name, e.x, e.y) end
    end
    out[#out + 1] = s
  end
  return table.concat(out, "\n")
end

-- 1. Lac lointain : la centrale est planifiée au lac
local res, logs, W = play(40, true)
local planned = 0
for i, r in ipairs(res) do
  local p = r.p
  if p and p.parts[1] and p.parts[1].lot == "lointain" then
    planned = planned + 1
    local ents = p.ents
    local line = {}
    local pump
    for _, e in ipairs(ents) do
      if e.role == "ligne" then line[#line + 1] = e end
      if e.name == "offshore-pump" then pump = e end
    end
    check(#line >= 20, string.format("faction %d : au moins 20 poteaux de ligne (%d)", i, #line))
    check(pump ~= nil and pump.x >= 600, "faction " .. i .. " : la pompe est au lac")
    -- chaîne continue : on part du premier poteau du gabarit (role nil, nom de poteau, le plus proche du premier de la ligne)
    local reach = require("shared.team.plan").wire(line[1] and line[1].name or "small-electric-pole") or 7.5
    local poles = {}
    for _, e in ipairs(ents) do if e.name:find("electric%-pole") then poles[#poles + 1] = e end end
    local linked = 0
    for _, a in ipairs(line) do
      local best = math.huge
      for _, b2 in ipairs(poles) do
        if b2 ~= a then
          local d = math.sqrt((a.x - b2.x) ^ 2 + (a.y - b2.y) ^ 2)
          if d < best then best = d end
        end
      end
      if best <= reach + 1e-6 then linked = linked + 1 end
    end
    check(linked == #line, string.format("faction %d : chaque poteau de ligne a un voisin à la portée %.1f (%d/%d)", i, reach, linked, #line))
    local onwater = 0
    for _, e in ipairs(line) do if e.x >= 640 and e.x < 760 and e.y >= -400 and e.y < 400 then onwater = onwater + 1 end end
    check(onwater == 0, "faction " .. i .. " : aucun poteau de ligne sur l'eau")
    local tiles = {}
    local dup = false
    for _, e in ipairs(ents) do
      for _, t in ipairs(require("shared.team.plan").tiles_of(e)) do
        local k = t[1] .. "," .. t[2]
        if tiles[k] then dup = true end
        tiles[k] = true
      end
    end
    check(not dup, "faction " .. i .. " : aucune tuile occupée deux fois par le projet")
    local node
    for k, n in pairs(r.b.net) do if n.pid == p.id then node = n end end
    check(node ~= nil, "faction " .. i .. " : un carrefour du treillis est relié par la ligne")
  end
end
check(planned >= 1, "au moins une faction a planifié sa centrale au lac lointain (" .. planned .. ")")
local pond = 0
for _, v in pairs(W.tile_override or {}) do if v:find("water", 1, true) then pond = pond + 1 end end
check(pond == 0, "aucune tuile écrite par script (0 étang) : " .. pond)
local lo = 0
for _, l in ipairs(logs) do if l:find("FO%-LOINTAIN") then lo = lo + 1 end end
check(lo > 0, "le journal [FO-LOINTAIN] dit ce qui est fait")
local s1 = sig(res)

-- 2. Même partie, mêmes décisions
local res2 = play(40, true)
check(sig(res2) == s1, "deux parties identiques donnent le même plan (déterminisme)")

-- 3. Aucune eau nulle part : la centrale attend, demande l'exploration de l'eau, n'est pas refusée, aucun étang
local res3, logs3, W3 = play(25, false)
for i, r in ipairs(res3) do
  local b = r.b
  check(b ~= nil and b.remote ~= nil and b.remote.want_water == true, "faction " .. i .. " : l'eau est demandée (want_water)")
  check(r.p ~= nil and r.p.state == "attente", "faction " .. i .. " : la centrale attend (" .. tostring(r.p and r.p.state) .. ")")
  local req = r.f.ai3f and r.f.ai3f.req and r.f.ai3f.req["eau"]
  check(req ~= nil, "faction " .. i .. " : demande d'exploration de l'eau ouverte")
end
local pond3 = 0
for _, v in pairs(W3.tile_override or {}) do if v:find("water", 1, true) then pond3 = pond3 + 1 end end
check(pond3 == 0, "sans eau : toujours aucun étang posé")

print(string.format("[LOINTAIN-MOTEUR] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
