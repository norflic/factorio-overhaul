--[[
  Lot ENJAMBE (plainte du DC, 14/11 : « quand un convoyeur traverse un gisement, le pavage des foreuses s'arrête net devant l'obstacle et
  abandonne le reste de la rangée »). Pur, aucune API Factorio.
  Usage, depuis la racine du mod :   lua5.2 tests/champ_enjambe_test.lua

  1. Ch.belt_reach : obstacle enjambé (paire entrée / sortie, écart <= portée), trop large, sans souterrain, souterrain déjà dessous ;
  2. plan : gisement 60 × 20 traversé par un tapis étranger (colonne x = 30) : souterrains de part et d'autre, foreuses des deux côtés,
     rien sur la colonne, aucune foreuse orpheline, vérifications du champ à zéro ;
  3. mutants : souterrain non débloqué, obstacle trop large, souterrain étranger sous l'obstacle -> coupure d'avant ;
  4. garde du chantier : une pièce souterraine n'est jamais sautée (champ_saut).
]]
package.path = "./?.lua;" .. package.path

local Ch = require("shared.team.champ")
local Cv = require("shared.team.champ_verif")
local Sa = require("shared.team.champ_saut")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

-- 1. Ch.belt_reach sur un contexte minimal (axe x : u = x, v = y)
local function ctx(blocked)
  local c = { uv = function(x, y) return x, y end }
  c.free = function(u, v) return not blocked[Ch.key(u, v)] end
  return c
end
local B = {}
for x = 10, 11 do B[Ch.key(x, 0)] = true end
local stop, hops = Ch.belt_reach(ctx(B), { logistics = { underground = 5 } }, 0, 20, 1, 0)
check(stop == nil and #hops == 1 and hops[1].inp == 9 and hops[1].out == 12, "obstacle de 2 tuiles enjambé (entrée 9, sortie 12)")
check(Ch.hop_at(hops, 9) == "input" and Ch.hop_at(hops, 12) == "output" and Ch.hop_at(hops, 10) == "gap" and Ch.hop_at(hops, 13) == nil,
  "rôles des tuiles du tapis")
stop = Ch.belt_reach(ctx(B), { logistics = { underground = 2 } }, 0, 20, 1, 0)
check(stop == 11, "écart 3 > portée 2 : coupure à la première tuile bloquée (" .. tostring(stop) .. ")")
stop = Ch.belt_reach(ctx(B), {}, 0, 20, 1, 0)
check(stop == 11, "sans souterrain débloqué : coupure d'avant")
stop = Ch.belt_reach(ctx(B), { logistics = { underground = 5 }, ug_tiles = { { 10, 0 } } }, 0, 20, 1, 0)
check(stop == 11, "souterrain déjà posé sous l'obstacle : coupure")
stop, hops = Ch.belt_reach(ctx(B), { logistics = { underground = 5 } }, 0, 0, -1, 20)
check(stop == nil and hops[1].inp == 12 and hops[1].out == 9, "sens inverse : entrée 12, sortie 9")
check(#Ch.hops_from({ { inp = 9, out = 12 } }, 5, 1) == 1 and #Ch.hops_from({ { inp = 9, out = 12 } }, 13, 1) == 0, "hops parcourus depuis la coupe")

-- 2. plan
local function spec_of(ug, extra)
  local ore, blocked = {}, {}
  for x = 0, 59 do for y = 0, 19 do ore[#ore + 1] = x; ore[#ore + 1] = y end end
  for y = -20, 40 do blocked[Ch.key(30, y)] = "transport-belt" end -- tapis étranger transversal
  for x = -40, -1 do for y = -20, 40 do blocked[Ch.key(x, y)] = "eau" end end -- bout ouest sans place de fonderie (cas du DC)
  local sp = { ore = ore, blocked = blocked, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }, furnace = { size = 2, rate = 0.625, fuel = false }, inserter = { rate = 0.83 },
    target = { x = 1000, y = 10 }, axis = "x", logistics = { underground = ug } }
  return sp
end
local function summary(p)
  local r = { left = 0, right = 0, ug_in = 0, ug_out = 0, on_col = 0 }
  for _, e in ipairs(p.ents) do
    local x0 = e.x - (e.w or e.size) / 2
    local x1 = x0 + (e.w or e.size) - 1
    if x0 <= 30 and x1 >= 30 then r.on_col = r.on_col + 1 end
    if e.kind == "foreuse" then if e.x < 30 then r.left = r.left + 1 else r.right = r.right + 1 end end
    if e.kind == "souterrain" and e.role ~= "charbon" and e.role ~= "lien" then
      if e.ug == "input" then r.ug_in = r.ug_in + 1 else r.ug_out = r.ug_out + 1 end
    end
  end
  return r
end

local sp = spec_of(5)
local p, why = Ch.plan(sp)
check(p ~= nil, "plan rendu (" .. tostring(why) .. ")")
if p then
  local r = summary(p)
  local rep = Cv.verify(p, sp)
  print(string.format("  avec souterrains : %d foreuses à gauche, %d à droite, %d entrées, %d sorties, orphelines %d, coupees %d ; %s",
    r.left, r.right, r.ug_in, r.ug_out, p.stats.orphans or -1, p.stats.capped or -1, Cv.line(rep)))
  check(r.ug_in >= 1 and r.ug_in == r.ug_out, "paires de souterrains posées")
  check(r.left >= 20 and r.right >= 20, "foreuses des deux côtés du tapis étranger")
  check(r.on_col == 0, "rien sur la colonne du tapis étranger (" .. r.on_col .. ")")
  check(rep.overlaps == 0 and rep.blocked == 0, "rien sur un autre bâtiment")
  check(rep.drops == 0, "sorties des foreuses sur leur tapis (" .. rep.drops .. ")")
  check(rep.traverse == 0, "aucun tapis hors de sa bande (" .. rep.traverse .. ")")
  check((p.stats.orphans or 0) == 0, "aucune foreuse orpheline")
  -- 3. mutants : la coupure d'avant revient
  local p0 = Ch.plan(spec_of(nil))
  local r0 = p0 and summary(p0)
  check(r0 and r0.ug_in == 0 and r0.left < r.left, "mutant sans souterrain : moins de foreuses à gauche (" .. tostring(r0 and r0.left) .. ")")
  local sp2 = spec_of(5)
  for x = 26, 34 do for y = -20, 40 do sp2.blocked[Ch.key(x, y)] = "mur" end end -- 9 tuiles : écart 10 > 5
  local p2 = Ch.plan(sp2)
  local r2 = p2 and summary(p2)
  check(r2 and r2.ug_in == 0, "mutant obstacle trop large : aucun souterrain")
  local sp3 = spec_of(5)
  sp3.ug_tiles = {}
  for y = -20, 40 do sp3.ug_tiles[#sp3.ug_tiles + 1] = { 30, y } end
  local p3 = Ch.plan(sp3)
  local r3 = p3 and summary(p3)
  check(r3 and r3.ug_in == 0, "mutant souterrain étranger dessous : aucun souterrain")
  -- déterminisme
  local q = Ch.plan(spec_of(5))
  local function ser(pl) local t = {} for _, e in ipairs(pl.ents) do t[#t + 1] = e.kind .. e.x .. ":" .. e.y .. ":" .. e.dir .. tostring(e.ug) end return table.concat(t, ";") end
  check(q and ser(q) == ser(p), "déterminisme")
end

-- 4. garde du chantier
check(Sa.skip("champ-souterrain", "occupe", 10, {}, 3) == false, "un souterrain de bande n'est jamais sauté")
check(Sa.skip("champ-foreuse", "occupe", 10, {}, 3) == true, "une foreuse de bande l'est (témoin)")

print(string.format("champ_enjambe : %d ok, %d echec(s)", passes, failures))
if failures > 0 then os.exit(1) end
