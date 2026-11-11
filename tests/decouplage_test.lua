--[[
  Tests hors jeu du lot DECOUPLAGE (directive du DC du 11/11 : « Cesse de concevoir des bandes hybrides qui associent foreuses et
  fours dans un même gabarit » ; BOX_MINAGE sur le minerai, BOX_FONDERIE sur le sol neutre). Pur, aucune API Factorio.
  Usage, depuis la racine du mod :   lua5.2 tests/decouplage_test.lua

  1. Sm.mining_box : foreuses + poteaux + tapis = BOX_MINAGE ; un seul four, bras ou coffre = BOX_FONDERIE ; sans lecteur de type : strict ;
  2. P.fit, BOX_FONDERIE (colonne de fours) : ressource sur la moitié du lot -> posée sur l'autre moitié, aucune tuile de l'emprise ni
     des têtes sur une ressource ; ressource partout -> refus ; sans `res` -> comme avant ;
  3. P.fit, BOX_MINAGE (ligne de foreuses) : posée sur le minerai malgré `res` ;
  4. Co.place, cadre figé (`fixed`) : une colonne figée sur une ressource est refusée (le cadre d'avant F500 ne la gardait pas) ;
  5. mutants : chaque coupe retirée est vue.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local function read(path) local h = assert(io.open(path, "rb")); local s = h:read("*a"); h:close(); return s end

local MODS = { sm = "shared.team.sol_minerai", p = "shared.team.plan", co = "shared.team.champ_colonne" }
-- type de prototype des entités des gabarits de test (le moteur le lit dans game.entity_prototypes)
local TYPE_OF_KIND = { drill = "mining-drill", pole = "electric-pole", belt = "transport-belt", furnace = "furnace",
  inserter = "inserter", chest = "container" }

local function load_mods(mut)
  for _, m in pairs(MODS) do package.loaded[m] = nil end
  if mut then
    local s2, n = read(mut.file):gsub(mut.from, mut.to, 1)
    assert(n == 1, "mutant introuvable : " .. mut.name)
    package.loaded[mut.mod] = assert(load(s2, "=" .. mut.name))()
  end
  local Sm, P, Co = require(MODS.sm), require(MODS.p), require(MODS.co)
  local M = require("shared.team.modules")
  Sm.type_of = function(name) local s = M.spec(name); return s and TYPE_OF_KIND[s.kind] end
  return Sm, P, Co, M
end

-- tuiles d'un gabarit posé (emprise et têtes) qui tombent sur `res`
local function hits(P, M, g, fit, res)
  local inst = M.instantiate(g, fit.k, fit.ox, fit.oy)
  local n = 0
  for _, e in ipairs(inst.entities) do
    for _, t in ipairs(P.tiles_of({ name = e.name, x = e.position.x, y = e.position.y, dir = e.direction })) do
      if res[P.tkey(t[1], t[2])] then n = n + 1 end
    end
  end
  for _, t in ipairs(P.port_room(inst)) do if res[P.tkey(t[1], t[2])] then n = n + 1 end end
  return n
end

local function scenario(tag, Sm, P, Co, M)
  local lat = P.lattice({ x = 0, y = 0 })
  local x0, y0, x1, y1 = P.lot_rect(lat, 1, 0)
  local rect = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  local smelter = M.GEN.smelter("stone-furnace", "iron-ore", 2)
  local drills = M.GEN.drills("iron-ore", 2)
  local half, all = {}, {}
  for y = y0, y1 - 1 do
    for x = x0, x1 - 1 do
      all[P.tkey(x, y)] = true
      if x >= x0 + 12 then half[P.tkey(x, y)] = true end
    end
  end
  -- 1.
  check(Sm.mining_box(drills) == true, tag .. "ligne de foreuses (foreuses, tapis, poteaux) : BOX_MINAGE")
  check(Sm.mining_box(smelter) == false, tag .. "colonne de fours : BOX_FONDERIE")
  -- 2.
  local f0 = P.fit(smelter, rect, { toward = { x = x1, y = y0 } })
  check(f0 ~= nil, tag .. "fonderie sans `res` : posée (comme avant)")
  local f1 = P.fit(smelter, rect, { toward = { x = x1, y = y0 }, res = half })
  check(f1 ~= nil and hits(P, M, smelter, f1, half) == 0,
    tag .. "fonderie, ressource sur la moitié est : aucune tuile de l'emprise ni des têtes sur la ressource ("
      .. tostring(f1 and hits(P, M, smelter, f1, half)) .. ")")
  if f0 then -- ressource sous la seule emprise de la meilleure place (pas sous ses têtes) : la fonderie va ailleurs
    local inst, under = M.instantiate(smelter, f0.k, f0.ox, f0.oy), {}
    for _, e in ipairs(inst.entities) do
      for _, t in ipairs(P.tiles_of({ name = e.name, x = e.position.x, y = e.position.y, dir = e.direction })) do under[P.tkey(t[1], t[2])] = true end
    end
    local fu = P.fit(smelter, rect, { toward = { x = x1, y = y0 }, res = under })
    check(fu ~= nil and hits(P, M, smelter, fu, under) == 0, tag .. "fonderie, ressource sous l'emprise seule : déplacée hors de la ressource")
  end
  local f2 = P.fit(smelter, rect, { res = all })
  check(f2 == nil, tag .. "fonderie, ressource partout : refus")
  -- 3.
  local f3 = P.fit(drills, rect, { ore = all, res = all })
  check(f3 ~= nil, tag .. "foreuses sur le minerai : posées malgré `res` (BOX_MINAGE)")
  -- 4.
  local spec = { furnace = { size = 2, rate = 0.3125 }, inserter = { rate = 0.83 }, pole = { reach = 2, wire = 7.5 } }
  local function free() return true end
  local count = 2
  local c0, _, s0 = Co.place(spec, 0, 1, 0, count, 2, 0, free, function() return false end, nil, nil)
  check(c0 ~= nil, tag .. "colonne sans minerai : posée")
  local cf = Co.place(spec, 0, 1, 0, count, 2, 0, free, function() return true end, nil, { s_edge = s0, count = count })
  check(cf == nil, tag .. "colonne d'un cadre figé sur une ressource : refusée")
end

section("1 à 4. Règle BOX_MINAGE / BOX_FONDERIE")
scenario("", load_mods())

-- sans lecteur de type : tout gabarit est une BOX_FONDERIE (le plus strict)
do
  local Sm, P, _, M = load_mods()
  Sm.type_of = nil
  check(Sm.mining_box(M.GEN.drills("iron-ore", 1)) == false, "sans lecteur de type : BOX_FONDERIE (strict)")
end

section("5. mutants")
local MUTANTS = {
  { name = "P.fit : emprise sur la ressource", mod = MODS.p, file = "shared/team/plan.lua",
    from = "and %(%(not rsat%) or count%(rsat, ox %- rect%.x0, oy %- rect%.y0, r%.w, r%.h%) == 0%)", to = "" },
  { name = "P.fit : têtes sur la ressource", mod = MODS.p, file = "shared/team/plan.lua",
    from = " or %(rsat and opts%.res%[tkey%(tx, ty%)%]%)", to = "" },
  { name = "P.fit : BOX_MINAGE refusée", mod = MODS.p, file = "shared/team/plan.lua",
    from = "opts%.res and not Sm%.mining_box%(g%)", to = "opts.res" },
  { name = "Co.place : cadre figé sur la ressource", mod = MODS.co, file = "shared/team/champ_colonne.lua",
    from = "if not free%(u, v%) or is_ore%(u, v%) then return false end", to = "if not free(u, v) then return false end" },
}
for _, mu in ipairs(MUTANTS) do
  local p0, f0 = passes, failures
  scenario("[" .. mu.name .. "] ", load_mods(mu))
  local seen = failures > f0
  passes, failures = p0, f0
  check(seen, "mutant vu : " .. mu.name)
end

print(string.format("[DECOUPLAGE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
