--[[
  Tests hors jeu du lot BUS-LONG (shared/team/troncons.lua, Lua pur). Usage, depuis la racine du mod :   lua5.2 tests/troncons_test.lua
  Critères : fo-logs/2026-11-09_BUS-LONG/CRITERES.md (C1 à C8). La batterie est appliquée au module réel (0 échec), puis à chaque MUTANT (au moins 1 échec).
  Le coût se mesure en instructions Lua (debug.sethook), jamais à l'horloge.
]]
package.path = "./?.lua;" .. package.path

local Tv = require("shared.team.traversee")

-- Monde : solid(x, y) -> vrai si une pièce ne peut pas s'y poser
local function world(solid, maxd, ug_axis)
  local ctx = { maxd = maxd, ug_axis = ug_axis }
  ctx.solid = solid
  ctx.cost = function(x, y) if solid(x, y) then return nil end return 1 end
  return ctx
end

local function deep(o, seen)
  if type(o) == "function" then error("fonction dans l'etat") end
  if type(o) ~= "table" then return o end
  seen = seen or {}
  if seen[o] then return seen[o] end
  local c = {}
  seen[o] = c
  for k, v in next, o do c[k] = deep(v, seen) end
  return c
end

-- Fait tourner le tracé. opts : serial (état copié entre chaque tranche), hook (mesure du pire appel), at = { [appel] = fn }, grid, lim. Rend st, statut, raison, appels, pire appel, barrière.
local function run(Tc, ctx, s, t, t_dir, box, opts)
  opts = opts or {}
  local st = Tc.new({ s = s, t = t, t_dir = t_dir or 2, sd = opts.sd, box = box, lim = opts.lim or (math.abs(s.x - t.x) + math.abs(s.y - t.y)) * 2 + 200 })
  local calls, worst, status, why, barrier = 0, 0
  while true do
    calls = calls + 1
    if opts.at and opts.at[calls] then opts.at[calls]() end
    if opts.each then opts.each(st) end
    if opts.serial then st = deep(st) end
    local n = 0
    if opts.hook then debug.sethook(function() n = n + 1 end, "", 1000) end
    status, why, barrier = Tc.step(st, ctx)
    if opts.hook then debug.sethook() end
    if n * 1000 > worst then worst = n * 1000 end
    if status ~= "more" then break end
    if calls > (opts.max_calls or 20000) then status, why = "boucle", "boucle sans fin" break end
  end
  return st, status, why, calls, worst, barrier
end

local function battery(Tc, silent)
  local fails = 0
  local function check(c, msg)
    if not c then
      fails = fails + 1
      if not silent then print("  ECHEC : " .. msg) end
    end
  end
  local function has_tile(st, x, y)
    for _, e in ipairs(st.tiles) do if e.x == x and e.y == y then return true end end
    return false
  end

  -- C1 : ligne libre de 300 tuiles
  do
    local ctx = world(function() return false end)
    local box = { x0 = -30, y0 = -60, x1 = 330, y1 = 100 }
    local st, status, why, calls = run(Tc, ctx, { x = 0, y = 0 }, { x = 300, y = 40 }, 2, box)
    check(status == "done", "C1 libre : statut " .. tostring(status) .. " " .. tostring(why))
    if status == "done" then
      check(#Tv.verify(st.tiles, st.s, st.t, 2, 0, ctx.cost) == 0, "C1 preuve Tv.verify")
      check(#st.tiles <= 340 + 40, "C1 detour borne, longueur " .. #st.tiles)
      check(#st.legs >= 6, "C1 decoupe en troncons : " .. #st.legs)
      check(st.total < 12000, "C1 peu d'etats en terrain libre : " .. st.total)
    end
    check(calls < 600, "C1 nombre d'appels : " .. calls)
  end

  -- C2 : mur fin et long (3 tuiles d'épaisseur, 440 de long) sans souterrain : le détour passe au bout du mur
  do
    local function wall(x, y) return x >= 150 and x <= 152 and y >= -220 and y <= 220 end
    local ctx = world(wall)
    local box = { x0 = -20, y0 = -280, x1 = 320, y1 = 280 }
    local st, status, why, calls = run(Tc, ctx, { x = 0, y = 0 }, { x = 300, y = 0 }, 2, box, { lim = 900 })
    check(status == "done", "C2 mur long : statut " .. tostring(status) .. " " .. tostring(why))
    if status == "done" then
      check(#Tv.verify(st.tiles, st.s, st.t, 2, 0, ctx.cost) == 0, "C2 preuve")
      local my = 0
      for _, e in ipairs(st.tiles) do if math.abs(e.y) > my then my = math.abs(e.y) end end
      check(my >= 220, "C2 contourne le bout du mur, ecart max " .. my)
    end
    check(calls < 6000, "C2 appels bornes : " .. calls)
  end

  -- C3 : ligne de tapis en travers : franchie par souterrain ; sans souterrain, refus avec cause
  do
    local function column(x, y) return x == 200 end
    local box = { x0 = -20, y0 = -60, x1 = 320, y1 = 60 }
    local ctx = world(column, 4)
    local st, status, why = run(Tc, ctx, { x = 0, y = 0 }, { x = 300, y = 0 }, 2, box)
    check(status == "done", "C3 souterrain : statut " .. tostring(status) .. " " .. tostring(why))
    if status == "done" then
      check(#Tv.verify(st.tiles, st.s, st.t, 2, 4, ctx.cost) == 0, "C3 preuve")
      local j = 0
      for _, e in ipairs(st.tiles) do
        if e.ug == "input" then j = j + 1 end
        check(e.x ~= 200, "C3 aucune piece sur la ligne de tapis")
      end
      check(j >= 1, "C3 au moins une paire souterraine : " .. j)
    end
    local st2, status2, why2, calls2 = run(Tc, world(column), { x = 0, y = 0 }, { x = 300, y = 0 }, 2, box)
    check(status2 == "fail", "C3 sans souterrain : refus, statut " .. tostring(status2))
    check(type(why2) == "string" and #why2 > 0, "C3 sans souterrain : cause donnee")
    check(calls2 < 4000, "C3 sans souterrain : refus borne, appels " .. calls2)
  end

  -- C4 : aucun souterrain sous un souterrain de même axe
  do
    local function column(x, y) return x == 200 end
    local box = { x0 = -20, y0 = -40, x1 = 320, y1 = 40 }
    local same = world(column, 4, function(x, y) if x == 200 then return 2 end end)
    local _, status = run(Tc, same, { x = 0, y = 0 }, { x = 300, y = 0 }, 2, box)
    check(status == "fail", "C4 souterrain de meme axe dessous : le tracé ne passe pas, statut " .. tostring(status))
    local cross = world(column, 4, function(x, y) if x == 200 then return 1 end end)
    local st2, status2 = run(Tc, cross, { x = 0, y = 0 }, { x = 300, y = 0 }, 2, box)
    check(status2 == "done", "C4 souterrain d'axe croise : passe, statut " .. tostring(status2))
    if status2 == "done" then check(#Tv.verify(st2.tiles, st2.s, st2.t, 2, 4, nil, { ug_axis = cross.ug_axis }) == 0, "C4 preuve") end
  end

  -- C5 : région fermée : refus borné
  do
    local function ring(x, y)
      local dx, dy = math.abs(x - 300), math.abs(y)
      local d = math.max(dx, dy)
      return d >= 10 and d <= 18
    end
    local ctx = world(ring, 4)
    local box = { x0 = -20, y0 = -80, x1 = 340, y1 = 80 }
    local st, status, why, calls = run(Tc, ctx, { x = 0, y = 0 }, { x = 300, y = 0 }, 2, box)
    check(status == "fail", "C5 region fermee : statut " .. tostring(status))
    check(calls < 12000, "C5 refus borne, appels " .. calls)
    check(type(why) == "string", "C5 cause donnee")
  end

  -- C5b : poche fermée autour de la cible : refus immédiat, avec la cause (avant : 14 000 à 20 000 noeuds pour dire « aucun chemin »)
  do
    local function ring(x, y)
      local d = math.max(math.abs(x - 300), math.abs(y))
      return d >= 4 and d <= 8
    end
    local _, status, why, calls = run(Tc, world(ring, 4), { x = 0, y = 0 }, { x = 300, y = 0 }, 2, { x0 = -20, y0 = -40, x1 = 330, y1 = 40 })
    check(status == "fail" and tostring(why):find("enfermee", 1, true) ~= nil, "C5b poche autour de la cible : " .. tostring(why))
    check(calls <= 2, "C5b refus au premier appel, appels " .. calls)
  end

  -- C6 : le monde change entre deux tranches
  do
    local blocked = {}
    local solid = function(x, y) return blocked[x .. ":" .. y] == true end
    local ctx = world(solid)
    local box = { x0 = -30, y0 = -60, x1 = 330, y1 = 60 }
    -- (a) une tuile d'un tronçon DÉJÀ tracé est prise pendant que la suite se cherche
    local st0 = run(Tc, ctx, { x = 0, y = 0 }, { x = 300, y = 0 }, 2, box)
    local victim = st0.tiles[30]
    local vx, vy = victim.x, victim.y
    blocked = {}
    local fired = false
    local st, status, why = run(Tc, ctx, { x = 0, y = 0 }, { x = 300, y = 0 }, 2, box, { each = function(s0)
      if not fired and #s0.legs >= 4 then fired = true; blocked[vx .. ":" .. vy] = true end end })
    check(fired, "C6a le changement du monde a bien eu lieu pendant le trace")
    check(status == "done", "C6a tuile prise sur un troncon fini : statut " .. tostring(status) .. " " .. tostring(why))
    if status == "done" then
      check(not has_tile(st, vx, vy), "C6a le trace final evite la tuile prise")
      check(#Tv.verify(st.tiles, st.s, st.t, 2, 0, ctx.cost) == 0, "C6a preuve")
    end
    -- (d) s40 p26 : la tuile de POINTE (juste après le dernier tronçon posé) est prise : le tronçon fautif est défait en une réparation, sans bande interdite
    blocked = {}
    local fired_d, bans_d, rep_d = false, nil, nil
    local std, statusd, whyd = run(Tc, ctx, { x = 0, y = 0 }, { x = 300, y = 0 }, 2, box, { each = function(s0)
      if not fired_d and #s0.legs >= 3 and s0.phase == "leg" and not s0.rs then
        fired_d = true
        local l = s0.tiles[#s0.tiles]
        local dv = ({ [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } })[l.dir]
        blocked[(l.x + dv[1]) .. ":" .. (l.y + dv[2])] = true
      elseif fired_d and not bans_d and s0.repairs_total and s0.repairs_total >= 1 then
        bans_d, rep_d = 0, #s0.legs
        for _ in next, s0.ban do bans_d = bans_d + 1 end
      end end })
    check(fired_d, "C6d la pointe a bien ete bouchee")
    check(statusd == "done", "C6d pointe bouchee : statut " .. tostring(statusd) .. " " .. tostring(whyd))
    check(bans_d ~= nil and bans_d <= 1, "C6d une seule case interdite (celle du troncon defait), pas de bande : " .. tostring(bans_d))
    check((std.repairs_total or 0) <= 2, "C6d reparations : " .. tostring(std.repairs_total))
    if statusd == "done" then check(#Tv.verify(std.tiles, std.s, std.t, 2, 0, ctx.cost) == 0, "C6d preuve") end
    -- (b) la cible est prise pendant le tracé : refus motivé, pas de plantage
    blocked = {}
    local _, status2, why2 = run(Tc, ctx, { x = 0, y = 0 }, { x = 300, y = 0 }, 2, box, { at = { [6] = function() blocked["300:0"] = true end } })
    check(status2 == "fail", "C6b cible prise : statut " .. tostring(status2))
    check(type(why2) == "string", "C6b cause donnee")
    -- (c) une tuile devant la pointe est prise pendant une tranche d'A* (etat encore ouvert) : aucun plantage
    blocked = {}
    local ctx3 = world(solid, 4)
    local st3, status3, why3 = run(Tc, ctx3, { x = 0, y = 0 }, { x = 300, y = 0 }, 2, box, { at = { [12] = function()
      for y = -60, 60 do blocked["41:" .. y] = true end end, [30] = function() blocked = {} end } })
    check(status3 == "done" or status3 == "fail", "C6c mur tombe entre deux tranches : termine sans erreur, statut " .. tostring(status3) .. " " .. tostring(why3))
    if status3 == "done" then check(#Tv.verify(st3.tiles, st3.s, st3.t, 2, 4, nil) == 0, "C6c preuve") end
  end

  -- C8 : état sauvegardable, identique relu entre chaque tranche, déterminisme
  do
    local function column(x, y) return x == 120 and math.abs(y) < 200 end
    local box = { x0 = -30, y0 = -80, x1 = 330, y1 = 80 }
    local a = run(Tc, world(column, 4), { x = 0, y = 0 }, { x = 300, y = 20 }, 2, box, { serial = true })
    local b = run(Tc, world(column, 4), { x = 0, y = 0 }, { x = 300, y = 20 }, 2, box)
    local c = run(Tc, world(column, 4), { x = 0, y = 0 }, { x = 300, y = 20 }, 2, box)
    local function sig(st) local o = {} for _, e in ipairs(st.tiles) do o[#o + 1] = e.x .. ":" .. e.y .. ":" .. e.dir .. ":" .. tostring(e.ug) end return table.concat(o, ",") end
    check(a.done and sig(a) == sig(b), "C8 meme trace avec l'etat relu entre chaque tranche")
    check(sig(b) == sig(c), "C8 deux passes identiques")
    check(#a.tiles > 200, "C8 trace non vide : " .. #a.tiles)
  end

  -- C7 : budget PROPRE par tronçon, coût d'un appel borné à l'échelle 600 %
  do
    local function walls(x, y)
      -- rangées de murs décalés toutes les 40 tuiles : chaque tronçon cherche sa porte
      if x % 40 < 3 then return (y + (x >= 0 and (math.floor(x / 40) % 2) or 0) * 30) % 80 ~= 37 end
      return false
    end
    local box = { x0 = -10, y0 = -120, x1 = 650, y1 = 120 }
    local st, status, why, calls, worst = run(Tc, world(walls, 3), { x = 5, y = 2 }, { x = 625, y = 2 }, 2, box, { hook = true, lim = 3000, max_calls = 30000 })
    check(status == "done", "C7 labyrinthe de 620 tuiles : statut " .. tostring(status) .. " " .. tostring(why))
    if status == "done" then
      check(st.total > Tv.PLAN_BUDGET, "C7 le budget partage aurait refuse : etats " .. st.total)
      check(worst <= 800000, "C7 pire appel " .. worst .. " > 800000 instructions")
    end
    -- pire cas plein, 640 x 640 tuiles, lectures par closure du monde
    local n = 0
    local function dense(x, y)
      n = n + 1
      if (x + y * 3) % 97 < 6 then return true end
      return (x % 64 < 28 and y % 64 < 28)
    end
    local st2, status2, why2, calls2, worst2 = run(Tc, world(dense, 4), { x = 40, y = 40 }, { x = 630, y = 610 }, 2, { x0 = -10, y0 = -10, x1 = 640, y1 = 640 }, { hook = true, lim = 3000, max_calls = 30000 })
    check(status2 == "done" or status2 == "fail", "C7 600 % : termine, statut " .. tostring(status2) .. " " .. tostring(why2))
    check(worst2 <= 800000, "C7 600 % : pire appel " .. worst2 .. " > 800000 instructions")
    if not silent then
      print(string.format("  mesure C7 : labyrinthe : %d appels, pire %d instr, %d etats, %d troncons ; dense 640x640 : statut %s (%s), %d appels, pire %d instr, %d tuiles", calls, worst, st.total, #st.legs, tostring(status2), tostring(why2), calls2, worst2, #st2.tiles))
    end
  end

  return fails
end

local Tc = require("shared.team.troncons")
local fails = battery(Tc)
print(string.format("[TRONCONS] batterie : %d echec(s)", fails))

-- Mutants : chaque ligne de chaque mutant doit faire échouer la batterie
local f = assert(io.open("shared/team/troncons.lua", "rb"))
local SRC = f:read("*a")
f:close()
local MUT = {
  { "budget partage entre troncons", "max = budget, slice", "max = 300, slice" },
  { "souterrains oublies", "local rctx = { maxd = ctx.maxd,", "local rctx = { maxd = nil," },
  { "validation du monde retiree", "if not ctx.cost(t.x, t.y) then broke = true break end", "" },
  { "etat de reprise perdu", "    st.rs = state\n", "    st.rs = nil\n" },
  { "cases toutes bouchees", "if free >= Tc.MIN_FREE then", "if free >= 17 then" },
  { "aucune reparation", "if st.repairs > Tc.MAX_REPAIRS or", "if st.repairs > 0 or" },
  { "poche ignoree", "if shut then return \"fail\", string.format(\"arrivee enfermee", "if false then return \"fail\", string.format(\"arrivee enfermee" },
  { "plan grossier sans tranche", "if left <= 0 then return \"more\" end", "" },
  { "lecture des cases sans tranche", "if n >= Tc.SAMPLE_CELLS then return false end", "" },
  { "raccord des troncons rompu", "return l.x + v[1], l.y + v[2], l.dir", "return l.x + v[1], l.y + v[2] + 1, l.dir" },
  { "preuve finale absente", 'st.phase, st.vi = "validate", 1', 'st.phase, st.vi, st.done = "fini", 1, true ; do return "done" end' },
  { "pointe sur nos pieces ignoree", "if taken[tk(x, y)] then return nil end", "" },
  { "bande interdite reduite a rien", "local function ban_stripe(st, wp, sx, sy)\n  if not wp.cx then return end", "local function ban_stripe(st, wp, sx, sy)\n  do return end\n  if not wp.cx then return end" },
}
local killed, survivors = 0, {}
for _, m in ipairs(MUT) do
  local i, j = SRC:find(m[2], 1, true)
  if not i then
    fails = fails + 1
    print("  MUTANT introuvable : " .. m[1])
  else
    local mutated = SRC:sub(1, i - 1) .. m[3] .. SRC:sub(j + 1)
    local fn, e = load(mutated, "=mutant", "t", _ENV)
    if not fn then
      fails = fails + 1
      print("  MUTANT ne se charge pas : " .. m[1] .. " : " .. tostring(e))
    else
      local ok, n = pcall(function() return battery(fn(), true) end)
      debug.sethook()
      if not ok or n > 0 then killed = killed + 1 else survivors[#survivors + 1] = m[1] end
    end
  end
end
for _, s in ipairs(survivors) do print("  MUTANT SURVIVANT : " .. s) end
fails = fails + #survivors
print(string.format("[TRONCONS] BILAN : %d OK (batterie), %d ECHEC(S) ; mutants %d/%d refuses", fails == 0 and 1 or 0, fails, killed, #MUT))
os.exit(fails == 0 and 0 or 1)
