-- Scénario greffé du lot MOD-3 (25/10) : MIGRATION d'une partie 0.4.26 (barème D-15 : vitesse +50 … +320 %,
-- productivité ADDITIONNÉE, énergie au plafond = vitesse) vers le barème D-17 (vitesse +20 … +110 %, productivité
-- +10 … +55 % MULTIPLIÉE, énergie qui garde l'écart au plafond). Double source SEULEMENT (tools/autotest/README.md §1.1) :
--   $env:FO_CREATE_SRC = "<racine>\fo-logs\2026-10-25_MOD3\src-0.4.26\factorio-overhaul"   (= git archive dd80b09 + feuilles D-6)
--   & "<racine>\fo-autotest.bat" nopause 200 mod3-migration "<source MOD-3>"
--   $env:FO_CREATE_SRC = $null
-- À la création (0.4.26) : machines posées AVEC raise_built (suivies par MOD-1, balises de complément au barème D-15,
-- lots de MOD-2 choisis), SANS courant (rien ne se fabrique : contenu exact). Au chargement par MOD-3 :
-- on_configuration_changed → modules relus aux nouvelles valeurs, balises recalculées, lots rebasculés.

local X, Y = 9600.5, 9600.5
local S1, S2, S3 = "speed-module", "speed-module-2", "speed-module-3"
local S10, P3, P10 = "fo-speed-module-10", "productivity-module-3", "fo-productivity-module-10"

-- Valeurs D-17 (fractions), calculées ICI indépendamment du mod.
local VAL = {}
do
  local sn = { S1, S2, S3 }
  for k = 1, 10 do
    local b = 0.2 + 0.1 * (k - 1)
    VAL[k <= 3 and sn[k] or ("fo-speed-module-" .. k)] = { speed = b, consumption = 0.6 * b }
  end
  local pn = { "productivity-module", "productivity-module-2", P3 }
  for k = 1, 10 do
    local p = 0.1 + 0.05 * (k - 1)
    VAL[k <= 3 and pn[k] or ("fo-productivity-module-" .. k)] = { productivity = p, speed = ({ -0.02, -0.05, -0.07 })[math.min(k, 3)], consumption = 0.6 * p }
  end
  VAL["effectivity-module"] = { consumption = -0.3 }
end

local function rep(name, n)
  local t = {}
  for _ = 1, n do t[#t + 1] = name end
  return t
end

-- lot = lot voulu APRÈS la mise à jour (D-17) ; lot0 = lot attendu à la création (D-15, 0.4.26).
local CAS = {
  { id = "R1-am2-5xS3", m = "assembling-machine-2", rec = "iron-gear-wheel", mods = rep(S3, 5), dx = 0, lot0 = 10, lot = 1, plates = 100 },
  { id = "R2-niv30-34xS10", m = "fo-lvl-assembler-30", rec = "iron-gear-wheel", mods = rep(S10, 34), dx = 10.5, dy = 0.5, lot0 = 100, lot = 100 },
  { id = "R3-am2-2xP3", m = "assembling-machine-2", rec = "iron-gear-wheel", mods = rep(P3, 2), dx = 22, lot0 = 1, lot = 1 },
  { id = "R4-foreuse-3xS2", m = "electric-mining-drill", mods = rep(S2, 3), dx = 30, ore = true },
  { id = "R5-am2-1xS1", m = "assembling-machine-2", rec = "iron-gear-wheel", mods = { S1 }, dx = 38, lot0 = 1, lot = 1 },
  { id = "R6-am2-P1+E1", m = "assembling-machine-2", rec = "iron-gear-wheel", mods = { "productivity-module", "effectivity-module" }, dx = 46, lot0 = 1, lot = 1 },
  { id = "R7-niv30-34xP10", m = "fo-lvl-assembler-30", rec = "iron-gear-wheel", mods = rep(P10, 34), dx = 56.5, dy = 0.5, lot0 = 1, lot = 1 },
}

local function round(x) return math.floor(x + 0.5) end
local function clampT(t) if t < 20 then return 20 end if t > 32867 then return 32867 end return t end

--- Attendus D-17 (centièmes) : produits, plafond, énergie qui garde l'écart (logarithmes flottants), sommes.
local function attendu(mods)
  local ps, pc, pp, ls, lp, ss, sc, sp = 1, 1, 1, 0, 0, 0, 0, 0
  for _, n in ipairs(mods) do
    local v = VAL[n]
    if v.speed then ps = ps * math.max(0.2, 1 + v.speed); ls = ls + math.log(math.max(0.2, 1 + v.speed)); ss = ss + v.speed end
    if v.consumption then pc = pc * math.max(0.2, 1 + v.consumption); sc = sc + v.consumption end
    if v.productivity then pp = pp * (1 + v.productivity); lp = lp + math.log(1 + v.productivity); sp = sp + v.productivity end
  end
  local ts, tp, tc = clampT(round(ps * 100)), clampT(round(pp * 100)), clampT(round(pc * 100))
  local gap = false
  if round(ps * 100) > 32867 or round(pp * 100) > 32867 then
    local rs = round(ps * 100) > 32867 and math.log(328.67) / ls or 1
    local rp = round(pp * 100) > 32867 and math.log(328.67) / lp or 1
    local y = 0
    for _, n in ipairs(mods) do
      local v = VAL[n]
      if v.consumption then
        local l = math.log(math.max(0.2, 1 + v.consumption))
        if v.consumption > 0 and (v.speed or 0) > 0 then y = y + rs * l
        elseif v.consumption > 0 and (v.productivity or 0) > 0 then y = y + rp * l
        else y = y + l end
      end
    end
    local tg = clampT(round(math.exp(y) * 100))
    if tg < tc then tc, gap = tg, true end
  end
  local besoin = math.abs((ts - 100) / 100 - ss) > 0.004 or math.abs((tc - 100) / 100 - sc) > 0.004
    or math.abs((tp - 100) / 100 - sp) > 0.004
  return { s = (ts - 100) / 100, c = (tc - 100) / 100, p = (tp - 100) / 100, besoin = besoin, gap = gap }
end

local function lot_of(m)
  if m.type ~= "assembling-machine" then return nil, "" end
  local r = m.get_recipe()
  local name = r and r.name or ""
  local k = name:match("^fo%-lot(%d+)%-")
  return k and tonumber(k) or 1, name
end

local function lire(m)
  return { s = m.speed_bonus, c = m.consumption_bonus, p = m.productivity_bonus, v = m.type == "mining-drill" and 0 or m.crafting_speed }
end

local function plaques(m)
  local n = 0
  local inv = m.get_inventory(defines.inventory.assembling_machine_input)
  if inv then n = n + inv.get_item_count("iron-plate") end
  local ok, st = pcall(remote.call, "fo-lots", "state", m)
  if ok and st and st.pending then
    for _, it in ipairs(st.pending.items or {}) do
      if it.name == "iron-plate" or it[1] == "iron-plate" then n = n + (it.count or it[2] or 0) end
    end
  end
  return n
end

return {
  description = "MOD-3 : migration d'une partie 0.4.26 (bareme D-15) vers le bareme D-17 (productivite multipliee, ecart d'energie au plafond)",
  base = nil,
  check_tick = 120,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local f = game.forces.player
    f.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    local p10 = game.item_prototypes[S10]
    local v10 = p10 and p10.module_effects and p10.module_effects.speed and p10.module_effects.speed.bonus or 0
    ctx.check(math.abs(v10 - 3.2) < 1e-3, "carte creee par 0.4.26 (bareme D-15 : vitesse 10 a +320 %)", string.format("%.4f", v10))
    ctx.prepare_area(X - 12, Y - 12, X + 70, Y + 12, "grass-1")
    st.cas = {}
    local bad = {}
    for _, c in ipairs(CAS) do
      local px, py = X + c.dx, Y + (c.dy or 0)
      if c.ore then
        for tx = -3, 3 do for ty = -3, 3 do s.create_entity({ name = "iron-ore", position = { px + tx, py + ty }, amount = 1000000 }) end end
      end
      local m = s.create_entity({ name = c.m, position = { px, py }, force = f, raise_built = true })
      local n = 0
      if m then
        if c.rec then m.set_recipe(c.rec) end
        local inv = m.get_module_inventory()
        for _, nm in ipairs(c.mods) do n = n + inv.insert({ name = nm, count = 1 }) end
        pcall(remote.call, "fo-modules", "refresh", m, true)
        if c.plates then m.get_inventory(defines.inventory.assembling_machine_input).insert({ name = "iron-plate", count = c.plates }) end
        local avant = lire(m)
        local k, rn = lot_of(m)
        ctx.log(string.format("CREATION %s : %s, %d module(s) ; speed_bonus %.4f ; consumption_bonus %.4f ; productivity_bonus %.4f ; recette %s",
          c.id, m.name, n, avant.s, avant.c, avant.p, rn))
        if c.lot0 and k ~= c.lot0 then bad[#bad + 1] = c.id .. " lot " .. tostring(k) .. " (attendu " .. c.lot0 .. ")" end
        st.cas[#st.cas + 1] = { id = c.id, m = m, c = c, avant = avant, plates0 = c.plates and plaques(m) or nil }
      end
      if not m or n ~= #c.mods then bad[#bad + 1] = c.id .. " pose" end
    end
    ctx.check(#bad == 0, "machines 0.4.26 posees avec leurs modules, lots D-15 choisis (R1 au lot 10, R2 au lot 100)", table.concat(bad, " ; "))
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    ctx.check(remote.interfaces["fo-modules"] ~= nil, "partie rechargee par MOD-3 (interface fo-modules)")
    local p10 = game.item_prototypes[S10]
    local v10 = p10 and p10.module_effects.speed.bonus or 0
    ctx.check(math.abs(v10 - 1.1) < 1e-3, "bareme D-17 charge (vitesse 10 a +110 %)", string.format("%.4f", v10))
    local stats = remote.call("fo-modules", "stats")
    ctx.log("STATS " .. serpent.line(stats))
    ctx.check((stats.migrated or 0) >= 1, "migration jouee (on_configuration_changed)", serpent.line(stats))
    for _, e in ipairs(st.cas or {}) do
      local m = e.m
      if not (m and m.valid) then
        ctx.fail("migration " .. e.id, "machine absente")
      else
        local c = e.c
        local a = attendu(c.mods)
        local apres = lire(m)
        local inv = m.get_module_inventory()
        local stt = remote.call("fo-modules", "state", m)
        local bb = m.bounding_box
        local nb = s.count_entities_filtered({ name = "fo-mm-balise", area = { { bb.left_top.x, bb.left_top.y }, { bb.right_bottom.x, bb.right_bottom.y } } })
        local k, rn = lot_of(m)
        local ok = inv.get_item_count() == #c.mods and math.abs(apres.s - a.s) < 0.005 and math.abs(apres.c - a.c) < 0.005
          and math.abs(apres.p - a.p) < 0.005 and stt.tracked and nb == (a.besoin and 1 or 0) and (not c.lot or k == c.lot)
        ctx.check(ok, "migration " .. e.id .. " : modules gardes, valeurs D-17, balise " .. (a.besoin and "recalculee" or "absente")
          .. (c.lot and (", lot " .. c.lot) or ""),
          string.format("%s, %d module(s) ; vitesse %.4f -> %.4f (attendu %.4f) ; energie %.4f -> %.4f (attendu %.4f%s) ; productivite %.4f -> %.4f (attendu %.4f) ; balises %d ; recette %s",
            m.name, inv.get_item_count(), e.avant.s, apres.s, a.s, e.avant.c, apres.c, a.c, a.gap and ", ecart garde" or "",
            e.avant.p, apres.p, a.p, nb, rn))
        if e.plates0 then
          local n = plaques(m)
          ctx.check(n == e.plates0, "migration " .. e.id .. " : plaques gardees a la rebascule (" .. e.plates0 .. ")", n .. " plaque(s) apres")
        end
      end
    end
    -- Écart gardé au plafond : la machine R2 (34 × vitesse 10) avait, en 0.4.26, l'énergie au plafond (× 328,67).
    for _, e in ipairs(st.cas or {}) do
      if e.id == "R2-niv30-34xS10" and e.m.valid then
        ctx.check(e.avant.c > 327 and e.m.consumption_bonus < 52 and e.m.speed_bonus > 327,
          "R2 : energie au plafond en 0.4.26 (x 328,67), ecart garde apres (x 52,38) a vitesse egale (x 328,67)",
          string.format("energie %.2f -> %.2f ; vitesse %.2f -> %.2f", 1 + e.avant.c, 1 + e.m.consumption_bonus, 1 + e.avant.s, 1 + e.m.speed_bonus))
      end
    end
    local lst = remote.call("fo-lots", "stats")
    ctx.log("STATS lots " .. serpent.line(lst))
  end,
}
