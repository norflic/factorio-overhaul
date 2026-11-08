--[[
  Lot X10, mesure M8 bis (7/11) : ce qui fait la TAILLE d'un pic de fin de cycle du ramasse-miettes.
  Attendus et premier passage : fo-logs\2026-11-07_X10\M8_CRITERES.md (§3 bis : le premier passage rangeait sa table jetable dans une
  upvalue fermée, ce qui bloque le marquage de Lua 5.2 ; ici, comme le mod, elle est rangée dans un CHAMP de table).
  Allocations faites dans le Lua du MOD DE TEST, tas lesté de 100 Mo de petites tables vivantes (430 000 tables de 4 champs, 237 octets
  chacune, étalon hors jeu lua5.2). Phases, en ticks depuis le premier tick du processus :
    échauffement 0 à 500 (lest bâti au premier tick) ;
    A, témoin, 500 à 1 600 : le lest seul ;
    B, tables, 1 600 à 2 700 : 1 700 petites tables par tick (environ 400 Ko), rangées dans un champ, jetées au tick suivant ;
    C, objets, 2 700 à 3 800 : un find_entities_filtered par tick sur K = 2 000 coffres posés au premier tick, rangé de même ;
    D, tables modifiées, 3 800 à 4 900 : la même allocation que B, PLUS, à chaque tick, UNE petite table neuve écrite dans 20 000
       tables du lest tirées d'une suite fixe (20 000 tables à reparcourir par la phase atomique : piste G3 ; l'écart D − B en est
       l'effet).
  Journal [FO-X10-M8] : sondes, Ko par tick par phase, et le tick de chaque FIN DE CYCLE (sentinelle à __gc réarmée à chaque fin).
  Les pics (luaGarbageIncremental, benchmark-verbose) se lisent au tick des fins de cycle (script-outils\x10_m8.py).
  Lancement : banc.py --seul --out <archive> --qui X10 -- 5000 x10-m8 <source>.
]]

local K = 2000
local ZX, ZY = 1200, 1200
local BALLAST_N = 430000
local B_PER_TICK = 1700
local D_WRITES = 20000
local PH = { { "echauffement", 0 }, { "A", 500 }, { "B", 1600 }, { "C", 2700 }, { "D", 3800 }, { "fin", 4900 } }

local H = { ballast = nil, junk = nil } -- tout ce qui change est rangé dans des CHAMPS de cette table (barrière arrière, comme le mod)
local t0 = nil
local cnt_ok = false
local gc_ok = false
local cycles = {}
local acc = {} -- [phase] = { ko = somme, n = ticks }

local function phase_of(dt)
  local name = PH[1][1]
  for _, p in ipairs(PH) do if dt >= p[2] then name = p[1] end end
  return name
end

local function count()
  if not cnt_ok then return nil end
  return collectgarbage("count")
end

local arm
local function on_cycle_end()
  if t0 then
    local dt = game.tick - t0
    cycles[#cycles + 1] = { tick = game.tick, dt = dt, phase = phase_of(dt) }
    log("[FO-X10-M8] fin de cycle du ramasse-miettes : tick " .. game.tick .. " (+" .. dt .. ", phase " .. phase_of(dt) .. ")"
      .. (cnt_ok and string.format(", tas %.0f Ko", collectgarbage("count")) or ""))
  end
  arm()
end
arm = function()
  local ok = pcall(function() setmetatable({}, { __gc = function() on_cycle_end() end }) end)
  gc_ok = gc_ok or ok
end

return {
  description = "M8 bis : taille du pic de fin de cycle du ramasse-miettes, tables, objets du moteur, tables modifiees (lest 100 Mo)",
  check_tick = 4950,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if not t0 then
      t0 = e.tick
      local ok, v = pcall(collectgarbage, "count")
      cnt_ok = ok and type(v) == "number"
      ctx.log("sonde collectgarbage(\"count\") : " .. (cnt_ok and ("permis, " .. string.format("%.0f", v) .. " Ko") or ("refuse : " .. tostring(v))))
      local b = {}
      for i = 1, BALLAST_N do b[i] = { a = i, b = i, c = i, d = i } end
      H.ballast = b
      local after = count()
      ctx.log("lest bati au tick " .. e.tick .. " : " .. BALLAST_N .. " tables" .. (after and string.format(", tas %.0f Ko", after) or ""))
      arm()
      ctx.log("sonde __gc : " .. (gc_ok and "sentinelle armee" or "refusee"))
      if not st.chests then
        st.chests = 0
        ctx.prepare_area(ZX - 2, ZY - 2, ZX + 52, ZY + 44, "grass-1")
        for i = 0, K - 1 do
          local c = s.create_entity({ name = "wooden-chest", position = { ZX + (i % 50) + 0.5, ZY + math.floor(i / 50) + 0.5 }, force = "player" })
          if c then st.chests = st.chests + 1 end
        end
        ctx.log("coffres poses : " .. st.chests)
      end
      return
    end
    local dt = e.tick - t0
    local ph = phase_of(dt)
    local m0 = count()
    if ph == "B" then
      local j = {}
      for i = 1, B_PER_TICK do j[i] = { a = i, b = i, c = i, d = i } end
      H.junk = j
    elseif ph == "C" then
      H.junk = s.find_entities_filtered({ area = { { ZX, ZY }, { ZX + 50, ZY + 42 } }, name = "wooden-chest" })
    elseif ph == "D" then
      -- la même allocation que B (pour que les cycles avancent pareil), PLUS les écritures dans le lest : l'écart D − B est l'effet G3
      local j = {}
      for i = 1, B_PER_TICK do j[i] = { a = i, b = i, c = i, d = i } end
      H.junk = j
      local fresh = { t = e.tick }
      local b = H.ballast
      for i = 1, D_WRITES do
        b[(e.tick * 7919 + i * 104729) % BALLAST_N + 1].b = fresh
      end
    else
      H.junk = nil
    end
    local m1 = count()
    if m0 and m1 and m1 >= m0 then
      local a = acc[ph] or { ko = 0, n = 0 }
      a.ko, a.n = a.ko + (m1 - m0), a.n + 1
      acc[ph] = a
    end
    if dt == 4899 then
      for _, p in ipairs({ "A", "B", "C", "D" }) do
        local a = acc[p]
        local nc = 0
        for _, c in ipairs(cycles) do if c.phase == p then nc = nc + 1 end end
        ctx.log(string.format("phase %s : %s Ko alloues par tick (mesure locale, hors pas du ramasse-miettes), %d fin(s) de cycle", p,
          a and a.n > 0 and string.format("%.1f", a.ko / a.n) or "?", nc))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local by = { A = 0, B = 0, C = 0, D = 0 }
    for _, c in ipairs(cycles) do if by[c.phase] then by[c.phase] = by[c.phase] + 1 end end
    ctx.check((st.chests or 0) == K, "coffres de la phase C poses", tostring(st.chests))
    ctx.check(gc_ok, "sentinelle __gc armee (fins de cycle datees)")
    ctx.check(by.B >= 2, "fins de cycle repetees en B (allocation rangee dans un champ)", string.format("A %d, B %d, C %d, D %d", by.A, by.B, by.C, by.D))
    ctx.check(by.D >= 1, "au moins une fin de cycle en D (tables modifiees)", tostring(by.D))
  end,
}
