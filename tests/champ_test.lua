--[[
  Tests hors jeu du lot CHAMP (retour du DC du 2/11 : « rangée poteaux électriques, rangée foreuses vers le bas, rangée convoyeur,
  rangée foreuses vers le haut, rangée poteaux électriques [...] et puis après on répète »). Pur, aucune API Factorio.
  Usage, depuis la racine du mod :   lua5.2 tests/champ_test.lua

  1. champs synthétiques (cercle, ellipses, L, trous, eau, géant 200 × 200, coffres, four électrique) : couverture électrique ≥ 85 %,
     100 % des foreuses et bras alimentés, un seul réseau de poteaux, aucun tapis hors de sa bande ni fini dans le champ, sorties des
     foreuses sur leur tapis, bras justes, fonderie ≥ foreuses, rien sur l'eau ni sur un autre bâtiment ;
  2. sortie vers le site de fonderie ; capacité des tapis (géant au tapis jaune : coupe aux deux bouts, écart écrit) ;
  3. stabilité : une bande planifiée seule (cadre figé) = la même bande du plan entier (bâtir bande par bande ne double rien) ;
  4. déterminisme ;
  5. mutants : chaque défaut injecté (plan ou règle) est vu.
]]
package.path = "./?.lua;" .. package.path

local Ch = require("shared.team.champ")
local Fd = require("shared.team.champ_fonderie")
local Cv = require("shared.team.champ_verif")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local BELTS3 = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }
local function spec_of(ore, o)
  o = o or {}
  local sp = { ore = ore, blocked = o.blocked or {}, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = o.belts or BELTS3, furnace = { size = 2, rate = 0.3125, fuel = true }, inserter = { rate = 0.83 },
    target = o.target or { x = 1000, y = 0 }, max_side = o.max_side, frame = o.frame }
  if o.chests then sp.furnace = nil end
  if o.electric then sp.furnace = { size = 2, rate = 0.625, fuel = false } end
  return sp
end

local function disc(cx, cy, r, out, skip)
  out = out or {}
  for x = cx - r, cx + r do
    for y = cy - r, cy + r do
      if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r and not (skip and skip(x, y)) then out[#out + 1] = x; out[#out + 1] = y end
    end
  end
  return out
end
local function ellipse(cx, cy, a, b)
  local o = {}
  for x = cx - a, cx + a do
    for y = cy - b, cy + b do if ((x - cx) / a) ^ 2 + ((y - cy) / b) ^ 2 <= 1 then o[#o + 1] = x; o[#o + 1] = y end end
  end
  return o
end
local function rect(x0, y0, w, h, out)
  out = out or {}
  for x = x0, x0 + w - 1 do for y = y0, y0 + h - 1 do out[#out + 1] = x; out[#out + 1] = y end end
  return out
end
local function holes(x, y)
  for _, h in ipairs({ { -10, -8, 3 }, { 8, 6, 4 }, { 0, 14, 3 }, { -14, 10, 2 }, { 12, -12, 3 }, { 3, -2, 2 } }) do
    if (x - h[1]) ^ 2 + (y - h[2]) ^ 2 <= h[3] * h[3] then return true end
  end
  return false
end

--- Lac au milieu du disque et rivière qui coupe des rangées : l'eau n'est pas du minerai et rien ne s'y pose.
local function lake()
  local blocked, isw = {}, {}
  for x = -6, 6 do for y = -6, 6 do if x * x + y * y <= 36 then blocked[Ch.key(x, y)] = true; isw[Ch.key(x, y)] = true end end end
  for x = -30, -12 do for y = 3, 4 do blocked[Ch.key(x, y)] = true; isw[Ch.key(x, y)] = true end end
  local ore = disc(0, 0, 25, nil, function(x, y) return isw[Ch.key(x, y)] end)
  return ore, blocked
end

local function judge(name, sp, p, rep, o)
  o = o or {}
  check(p ~= nil, name .. " : plan rendu")
  if not p then return end
  local min_cov = o.min_cov or 0.85
  check(rep.elec >= min_cov, string.format("%s : couverture électrique %.1f %% >= %.0f %%", name, 100 * rep.elec, 100 * min_cov))
  check(rep.unpowered == 0, name .. " : foreuses et bras alimentés (" .. rep.unpowered .. " sans courant)")
  check(rep.components == 1, name .. " : un seul réseau de poteaux (" .. rep.components .. ")")
  check(rep.traverse == 0, name .. " : aucun tapis hors de sa bande (" .. rep.traverse .. ")")
  check(rep.inside == 0, name .. " : aucun tapis fini dans le champ (" .. rep.inside .. ")")
  check(rep.drops == 0, name .. " : sorties des foreuses sur leur tapis (" .. rep.drops .. ")")
  check(rep.arms == 0, name .. " : bras justes (" .. rep.arms .. ")")
  check(rep.starved == 0, name .. " : fonderie et voies à la mesure des foreuses (" .. rep.starved .. ")")
  check(rep.overlaps == 0 and rep.blocked == 0, name .. " : rien sur un autre bâtiment ni sur l'eau")
  print(string.format("  %s : axe %s, sortie %d, %d foreuses, %d poteaux, %d tapis, %d fours, %d bras, %d coffres, coupees %d ; %s", name,
    p.axis, p.exit, p.stats.drills, p.stats.poles, p.stats.belts, p.stats.furnaces, p.stats.inserters, p.stats.chests, p.stats.capped, Cv.line(rep)))
end

local function run(name, ore, o)
  local sp = spec_of(ore, o)
  local p, why = Ch.plan(sp)
  if not p then check(false, name .. " : refus " .. tostring(why)) return nil end
  local rep = Cv.verify(p, sp)
  judge(name, sp, p, rep, o)
  return p, rep, sp
end

local function sig(e) return string.format("%s:%.1f:%.1f:%d", e.kind, e.x, e.y, e.dir) end
local function serial(p)
  local t = {}
  for _, e in ipairs(p.ents) do t[#t + 1] = sig(e) .. ":" .. tostring(e.band) .. ":" .. tostring(e.group) end
  return table.concat(t, ";")
end

section("1. champs synthetiques")
local pc = run("cercle r20", disc(0, 0, 20))
local pe = run("ellipse 81 x 29", ellipse(0, 0, 40, 14), { target = { x = -500, y = 0 } })
check(pe and pe.axis == "x" and pe.exit == -1, "ellipse : rangées dans l'axe long (x), sortie vers le site à l'ouest")
local pv = run("ellipse verticale", ellipse(0, 0, 12, 35), { target = { x = 0, y = 400 } })
check(pv and pv.axis == "y" and pv.exit == 1, "ellipse verticale : axe y, sortie au sud vers le site")
local L = rect(0, 0, 60, 12)
rect(0, 12, 12, 50, L)
run("L", L)
run("trous", disc(0, 0, 25, nil, holes))
local ore_l, blocked_l = lake()
run("eau", ore_l, { blocked = blocked_l })
run("coffres (charbon)", disc(0, 0, 18), { chests = true })
run("four electrique", disc(0, 0, 18), { electric = true })

section("2. sortie, capacite des tapis, geant")
local t0 = os.clock()
local pg, rg = run("geant 200 x 200 (3 tapis)", rect(0, 0, 200, 200))
print(string.format("  geant : %.2f s", os.clock() - t0))
local py, ry = run("geant 200 x 200 (tapis jaune seul)", rect(0, 0, 200, 200), { belts = { { lane = 7.5 } }, min_cov = 0.40 })
if py then
  -- F555 : le nombre de foreuses ne dépend que du minerai couvert, jamais du débit du tapis ni de la fonderie
  check(py.stats.capped == 0, "géant au tapis jaune : aucune foreuse des rangées écartée (" .. py.stats.capped .. ")")
  local both = { [1] = 0, [-1] = 0 }
  for _, bd in ipairs(py.bands) do for _, g in ipairs(bd.groups) do
    both[g.side] = both[g.side] + 1
    check(g.flow <= 2 * 7.5 + 1e-9, "voie jaune : la fonderie dimensionnée sur le débit livré par le tapis (" .. g.flow .. ")")
  end end
  check(both[1] > 0 and both[-1] > 0, "géant au tapis jaune : les bandes sortent par les deux bouts, jamais par le milieu")
end
local pm, rm = run("cercle, 4 foreuses par cote au plus", disc(0, 0, 20), { max_side = 4, min_cov = 0.5 })
if pm then
  check(pm.stats.capped == 0, "F555 : max_side ne borne plus les foreuses (" .. pm.stats.capped .. " écartée(s))")
end
-- dimensionnement : un groupe de 15 + 15 foreuses à 0,5/s = 15/s, four à 0,3125/s -> 48 fours ; voie jaune -> 15 foreuses par côté
check(Fd.furnaces_for(15, 0.3125) == 48 and Fd.furnaces_for(0.3125, 0.3125) == 1 and Fd.furnaces_for(0.32, 0.3125) == 2, "N = plafond(débit / débit d'un four)")
check(Ch.lane_drills(7.5, 0.5) == 15 and Ch.lane_drills(22.5, 0.5) == 45, "foreuses par voie")

section("3. stabilite : une bande seule = la meme bande du plan entier")
--- Entités des bandes planifiées une à une (cadre figé du plan entier) absentes du plan entier : (absentes, total).
local function stability(ore)
  local sp = spec_of(ore)
  local full = Ch.plan(sp)
  local in_full = {}
  for _, e in ipairs(full.ents) do in_full[sig(e)] = true end
  local bad, total = 0, 0
  for _, bd in ipairs(full.bands) do
    local fr = {}
    for k, v in pairs(full.frame) do fr[k] = v end
    fr.only = { [bd.pr] = true }
    local part = Ch.plan(spec_of(ore, { frame = fr }))
    for _, e in ipairs(part and part.ents or {}) do
      total = total + 1
      if not in_full[sig(e)] then bad = bad + 1 end
    end
  end
  return bad, total
end
do
  for _, c in ipairs({ { "cercle", disc(0, 0, 20) }, { "trous", disc(0, 0, 25, nil, holes) }, { "L", L } }) do
    local bad, total = stability(c[2])
    check(total > 0 and bad == 0, string.format("%s, bandes seules : %d entités, %d absentes du plan entier", c[1], total, bad))
  end
end

section("4. determinisme")
do
  local a = Ch.plan(spec_of(disc(3, -7, 19, nil, holes)))
  local b = Ch.plan(spec_of(disc(3, -7, 19, nil, holes)))
  check(serial(a) == serial(b), "deux plans du même champ identiques")
end

section("5. mutants")
local function clone(p)
  local q = { axis = p.axis, exit = p.exit, bands = p.bands, stats = p.stats, ents = {} }
  for i, e in ipairs(p.ents) do local c = {}; for k, v in pairs(e) do c[k] = v end; q.ents[i] = c end
  return q
end
local base_sp = spec_of(disc(0, 0, 20))
local base = Ch.plan(base_sp)
local function first(p, kind, pred)
  for i, e in ipairs(p.ents) do if e.kind == kind and (not pred or pred(e)) then return i, e end end
end
local muts = {
  { "poteau envoye au loin", function(q) local i = first(q, "poteau"); q.ents[i].y = q.ents[i].y + 1000 end, function(r) return r.components > 1 end },
  { "poteaux d'une rangee du champ retires", function(q)
      local _, p0 = first(q, "poteau", function(e) return e.band == 0 end)
      local keep = {}
      for _, e in ipairs(q.ents) do if not (e.kind == "poteau" and e.band == 0 and e.pr == p0.pr and ((q.axis == "x" and e.y == p0.y) or (q.axis ~= "x" and e.x == p0.x))) then keep[#keep + 1] = e end end
      q.ents = keep end, function(r) return r.unpowered > 0 end },
  { "un four retire", function(q) local i = first(q, "four"); table.remove(q.ents, i) end, function(r) return r.arms > 0 or r.starved > 0 end },
  { "tapis pose dans la rangee de foreuses d'une autre bande", function(q)
      local _, e = first(q, "tapis", function(e) return e.band == 2 end)
      local c = {}; for k, v in pairs(e) do c[k] = v end
      if q.axis == "x" then c.y = c.y - 8 else c.x = c.x - 8 end
      q.ents[#q.ents + 1] = c end, function(r) return r.traverse > 0 or r.overlaps > 0 end },
  { "foreuse decalee d'une tuile en travers", function(q) local i = first(q, "foreuse"); if q.axis == "x" then q.ents[i].y = q.ents[i].y - 1 else q.ents[i].x = q.ents[i].x - 1 end end,
    function(r) return r.drops > 0 or r.overlaps > 0 end },
  { "bras retourne", function(q) local i = first(q, "bras"); q.ents[i].dir = (q.ents[i].dir + 4) % 8 end, function(r) return r.arms > 0 end },
  { "tapis a contresens", function(q) local i = first(q, "tapis"); q.ents[i].dir = (q.ents[i].dir + 4) % 8 end, function(r) return r.traverse > 0 end },
  { "poteau sur l'eau", function(q) local i = first(q, "poteau"); base_sp.blocked[Ch.key(math.floor(q.ents[i].x), math.floor(q.ents[i].y))] = true end,
    function(r) return r.blocked > 0 end },
}
for _, m in ipairs(muts) do
  local q = clone(base)
  local saved = {}
  for k, v in pairs(base_sp.blocked) do saved[k] = v end
  m[2](q)
  local r = Cv.verify(q, base_sp)
  check(m[3](r) and not r.ok, "mutant vu : " .. m[1])
  base_sp.blocked = saved
end
-- mutants des RÈGLES : la règle faussée, le contrôle la refuse
local rule_muts = {
  { "fours sous-dimensionnes (N - 1)", function() local o = Fd.furnaces_for; Fd.furnaces_for = function(f, r) return math.max(0, o(f, r) - 1) end; return function() Fd.furnaces_for = o end end,
    function(r) return r.starved > 0 end },
  { "aucune foreuse (seuil de minerai impossible)", function() local o = Ch.CFG.min_ore; Ch.CFG.min_ore = 26; return function() Ch.CFG.min_ore = o end end,
    function(r) return r.elec < 0.85 end },
  { "fours sur un debit nul (F555, Ch.delivered)", function() local o = Ch.delivered; Ch.delivered = function() return 0 end; return function() Ch.delivered = o end end,
    function(r) return r.starved > 0 end, { belts = { { lane = 7.5 } }, long = true } },
}
for _, m in ipairs(rule_muts) do
  local undo = m[2]()
  local ore = (m[4] and m[4].long) and ellipse(0, 0, 40, 14) or disc(0, 0, 20)
  local sp = spec_of(ore, m[4])
  if m[4] and m[4].plan_reach then sp.pole = { reach = m[4].plan_reach, wire = 7.5 } end
  local ok, p = pcall(Ch.plan, sp)
  local r = ok and p and Cv.verify(p, spec_of(ore, m[4]))
  undo()
  check(r and m[3](r), "mutant de règle vu : " .. m[1])
end
-- treillis faussé : les poteaux ne tombent plus aux mêmes places selon les bandes planifiées (bâtir bande par bande doublerait des poteaux)
do
  local o = Ch.lattice_step
  Ch.lattice_step = function(sp) return sp.drill.size + 2 * sp.pole.reach + 1 end
  local bad = stability(disc(0, 0, 20))
  Ch.lattice_step = o
  check(bad > 0, "mutant vu : treillis des poteaux trop lâche (" .. bad .. " poteaux déplacés entre bandes seules et plan entier)")
end
-- sortie : un plan dont la sortie est forcée à l'opposé du site est vu par le contrôle de sortie
do
  local p = Ch.plan(spec_of(ellipse(0, 0, 40, 14), { target = { x = -500, y = 0 } }))
  local fr = {}
  for k, v in pairs(p.frame) do fr[k] = v end
  fr.exit = -p.exit
  local q = Ch.plan(spec_of(ellipse(0, 0, 40, 14), { target = { x = -500, y = 0 }, frame = fr }))
  check(q and q.exit ~= p.exit and q.exit == 1, "mutant de sortie : forcé à l'est, loin du site, il est vu (" .. tostring(q and q.exit) .. ")")
end

print(string.format("[CHAMP] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
