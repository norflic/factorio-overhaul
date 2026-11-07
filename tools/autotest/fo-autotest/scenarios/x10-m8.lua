--[[
  Lot X10, mesure M8 (7/11) : la TAILLE d'un pic de fin de cycle du ramasse-miettes, avec des tables ou avec des objets du moteur.
  Attendus écrits avant : fo-logs\2026-11-07_X10\M8_CRITERES.md. Allocations faites dans le Lua du MOD DE TEST, dont le tas est
  lesté de 20 Mo de petites tables vivantes (environ 86 000 tables de 4 champs, 237 octets chacune, étalon hors jeu lua5.2).
  Phases, en ticks depuis le premier tick du processus (la création et le benchmark sont deux processus ; le lest est refait dans
  chacun, car c'est une variable locale) :
    échauffement 0 à 600 (lest bâti au premier tick) ;
    A, témoin, 600 à 1 900 : le lest seul ;
    B, tables, 1 900 à 3 200 : 1 700 petites tables par tick (environ 400 Ko), jetées au tick suivant ;
    C, objets, 3 200 à 4 500 : un find_entities_filtered par tick sur la zone de K = 2 000 coffres posés à la création, résultat jeté
       au tick suivant.
  Journal [FO-X10-M8] : sondes de collectgarbage et de __gc, Ko par tick mesurés par phase (si collectgarbage("count") est permis),
  et le tick de chaque FIN DE CYCLE du ramasse-miettes du mod de test (sentinelle à __gc réarmée à chaque fin), avec sa phase.
  Les pics (luaGarbageIncremental, benchmark-verbose) se lisent ensuite au tick des fins de cycle.
  Lancement : banc.py --seul --out <archive> --qui X10 -- 4700 x10-m8 <source>.
]]

local K = 2000
local ZX, ZY = 1200, 1200
local BALLAST_N = 86000
local B_PER_TICK = 1700
local PH = { { "echauffement", 0 }, { "A", 600 }, { "B", 1900 }, { "C", 3200 }, { "fin", 4500 } }

local ballast, junk, t0 = nil, nil, nil
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
    log("[FO-X10-M8] fin de cycle du ramasse-miettes : tick " .. game.tick .. " (+" .. dt .. ", phase " .. phase_of(dt) .. ")")
  end
  arm()
end
arm = function()
  local ok = pcall(function() setmetatable({}, { __gc = function() on_cycle_end() end }) end)
  gc_ok = gc_ok or ok
end

return {
  description = "M8 : taille du pic de fin de cycle du ramasse-miettes, tables contre objets du moteur (lest 20 Mo)",
  check_tick = 4550,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if not t0 then
      t0 = e.tick
      local ok, v = pcall(collectgarbage, "count")
      cnt_ok = ok and type(v) == "number"
      ctx.log("sonde collectgarbage(\"count\") : " .. (cnt_ok and ("permis, " .. string.format("%.0f", v) .. " Ko") or ("refuse : " .. tostring(v))))
      ballast = {}
      for i = 1, BALLAST_N do ballast[i] = { a = i, b = i, c = i, d = i } end
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
      junk = j
    elseif ph == "C" then
      junk = s.find_entities_filtered({ area = { { ZX, ZY }, { ZX + 50, ZY + 42 } }, name = "wooden-chest" })
    else
      junk = nil
    end
    local m1 = count()
    if m0 and m1 and m1 >= m0 then
      local a = acc[ph] or { ko = 0, n = 0 }
      a.ko, a.n = a.ko + (m1 - m0), a.n + 1
      acc[ph] = a
    end
    if dt == 4499 then
      for _, p in ipairs({ "A", "B", "C" }) do
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
    local by = { A = 0, B = 0, C = 0 }
    for _, c in ipairs(cycles) do if by[c.phase] then by[c.phase] = by[c.phase] + 1 end end
    ctx.check((st.chests or 0) == K, "coffres de la phase C poses", tostring(st.chests))
    ctx.check(gc_ok, "sentinelle __gc armee (fins de cycle datees)")
    ctx.check(by.B > 0, "H1 : fins de cycle en B (tables)", string.format("A %d, B %d, C %d", by.A, by.B, by.C))
    ctx.check(by.A == 0, "banc juste : aucune fin de cycle en A (lest seul)", tostring(by.A))
  end,
}
