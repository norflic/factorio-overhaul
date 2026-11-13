--[[
  Sprint s41, chantier « pavage-trous » : micro-trous des grilles de foreuses et poteaux en trop au bout des rangées (plan pur,
  shared/team/champ.lua). Gisements synthétiques, aucune API Factorio. Lancement : lua5.2 tests/s41_pavage-trous_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(c, msg) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end end

local Ch = require("shared.team.champ")

local BELTS3 = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }
local function rect(x0, y0, w, h) local o = {} for x = x0, x0 + w - 1 do for y = y0, y0 + h - 1 do o[#o + 1] = x; o[#o + 1] = y end end return o end
local function disc(cx, cy, r)
  local o = {}
  for x = cx - r, cx + r do for y = cy - r, cy + r do if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r then o[#o + 1] = x; o[#o + 1] = y end end end
  return o
end
local function spec_of(ore, o)
  o = o or {}
  return { ore = ore, blocked = o.blocked or {}, drill = { size = 3, reach = o.reach or 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = BELTS3, furnace = { size = 2, rate = 0.3125, fuel = true }, inserter = { rate = 0.83 }, target = { x = 1000, y = 0 },
    design = o.design, max_side = 8, logistics = {}, frame = o.frame, no_row_opt = o.no_row_opt }
end

--- Relevé d'un plan : minerai hors de toute zone de foreuse et libre, poteaux, foreuses et bras sans courant, réseaux, poteaux voisins.
local function survey(p, sp)
  local R, W, r = sp.pole.reach, sp.pole.wire, sp.drill.reach
  local poles, cons, occ, mined, drills = {}, {}, {}, {}, {}
  for _, e in ipairs(p.ents) do
    local s = e.size or 1
    local bx, by = math.floor(e.x - (s - 1) / 2 + 0.001), math.floor(e.y - (s - 1) / 2 + 0.001)
    for x = bx, bx + s - 1 do for y = by, by + s - 1 do occ[Ch.key(x, y)] = true end end
    if e.kind == "poteau" then poles[#poles + 1] = { x = bx, y = by }
    elseif e.kind == "foreuse" or e.kind == "bras" then cons[#cons + 1] = { x0 = bx, y0 = by, x1 = bx + s - 1, y1 = by + s - 1 } end
    if e.kind == "foreuse" then
      drills[#drills + 1] = bx .. ":" .. by
      for x = bx - r, bx + s - 1 + r do for y = by - r, by + s - 1 + r do mined[Ch.key(x, y)] = true end end
    end
  end
  table.sort(drills)
  local out = { holes = 0, poles = #poles, dark = 0, nets = 0, adjacent = 0, drills = table.concat(drills, " "), ndrills = #drills }
  for i = 1, #sp.ore - 1, 2 do
    local k = Ch.key(sp.ore[i], sp.ore[i + 1])
    if not mined[k] and not occ[k] then out.holes = out.holes + 1 end
  end
  for _, c in ipairs(cons) do
    local f = false
    for _, q in ipairs(poles) do if q.x >= c.x0 - R and q.x <= c.x1 + R and q.y >= c.y0 - R and q.y <= c.y1 + R then f = true break end end
    if not f then out.dark = out.dark + 1 end
  end
  local seen = {}
  for i = 1, #poles do
    if not seen[i] then
      out.nets = out.nets + 1
      seen[i] = true
      local st = { i }
      while #st > 0 do
        local a = table.remove(st)
        for j = 1, #poles do
          if not seen[j] and (poles[a].x - poles[j].x) ^ 2 + (poles[a].y - poles[j].y) ^ 2 <= W * W then seen[j] = true; st[#st + 1] = j end
        end
      end
    end
  end
  for i = 1, #poles do for j = i + 1, #poles do
    if math.abs(poles[i].x - poles[j].x) + math.abs(poles[i].y - poles[j].y) == 1 then out.adjacent = out.adjacent + 1 end
  end end
  return out
end

local OBST = {}
for _, q in ipairs({ { 3, 4 }, { -7, 9 }, { 10, -11 }, { -12, -5 }, { 0, 15 } }) do OBST[Ch.key(q[1], q[2])] = true end

local CASES = {
  { "rectangle 40 x 30", function() return rect(0, 0, 40, 30) end, nil },
  { "disque 22", function() return disc(0, 0, 22) end, nil },
  { "disque 22, obstacles", function() return disc(0, 0, 22) end, OBST },
}
local gain = 0
for _, design in ipairs({ "colonne", "coffres" }) do
  for _, cs in ipairs(CASES) do
    local name = design .. ", " .. cs[1]
    local d = design == "colonne" and "colonne" or nil
    local sp = spec_of(cs[2](), { design = d, blocked = cs[3] })
    local p = Ch.plan(sp)
    local spg = spec_of(cs[2](), { design = d, blocked = cs[3], no_row_opt = true })
    local pg = Ch.plan(spg)
    check(p ~= nil and pg ~= nil, name .. " : plan rendu")
    if p and pg then
      local a, g = survey(p, sp), survey(pg, spg)
      -- 1. micro-trous : aucune tuile de minerai libre hors de toute zone de foreuse ; jamais plus qu'avec le glouton seul
      -- (colonne : un plan qui garde un coffre de tête retombe sur le glouton s'il en a moins ; le trou est alors le prix de la voie du charbon)
      local repli = d == "colonne" and a.drills == g.drills and a.holes > 0
      if repli then
        local so = false
        for _, off in pairs(p.frame.offsets) do if off[1] == 3 or off[2] == 3 then so = true end end
        check(not so, name .. " : repli sur le glouton, aucun décalage optimal dans le cadre")
      end
      check(a.holes == 0 or repli, name .. " : 0 tuile de minerai libre hors de toute zone (" .. a.holes .. " ; glouton seul : " .. g.holes .. ")")
      check(a.holes <= g.holes and a.ndrills >= g.ndrills, name .. " : pas plus de trous ni moins de foreuses que le glouton seul (" ..
        a.ndrills .. " / " .. g.ndrills .. ")")
      gain = gain + (g.holes - a.holes)
      -- 2. poteaux : tout alimenté, un seul réseau, aucun poteau collé à un autre
      check(a.dark == 0, name .. " : foreuses et bras tous alimentés (" .. a.dark .. " sans courant)")
      check(a.nets == 1, name .. " : un seul réseau de poteaux (" .. a.nets .. ")")
      check(a.adjacent == 0, name .. " : aucun poteau collé à un autre (" .. a.adjacent .. " paire(s))")
      -- 3. le cadre rejoue le même plan (décalage s gardé dans le cadre) ; déterminisme
      local sp2 = spec_of(cs[2](), { design = d, blocked = cs[3], frame = p.frame })
      local p2 = Ch.plan(sp2)
      check(p2 ~= nil and survey(p2, sp2).drills == a.drills, name .. " : le cadre rejoue les mêmes foreuses")
      local p3 = Ch.plan(spec_of(cs[2](), { design = d, blocked = cs[3] }))
      check(p3 ~= nil and #p3.ents == #p.ents and survey(p3, sp).drills == a.drills, name .. " : deux plans identiques")
      -- 4. un cadre d'avant le lot (décalages 0..s-1) rejoue ses rangées gloutonnes à l'identique
      local old = true
      for _, off in pairs(pg.frame.offsets) do if off[1] == 3 or off[2] == 3 then old = false end end
      local sp4 = spec_of(cs[2](), { design = d, blocked = cs[3], frame = pg.frame })
      local p4 = Ch.plan(sp4)
      check(old and p4 ~= nil and survey(p4, sp4).drills == g.drills, name .. " : cadre d'avant le lot rejoué à l'identique")
    end
  end
end
-- mutant : sans la rangée optimale, des trous reviennent sur au moins un gisement (le test voit le défaut)
check(gain > 0, "mutant « glouton seul » vu : des tuiles de minerai hors de toute zone reviennent (" .. gain .. ")")

print(string.format("[S41-PAVAGE-TROUS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
