--[[
  Lot X10-GEL, palier A : micro-banc en moteur réel (fo-logs/2026-11-07_X10/L1_CRITERES.md §4, C1, C2, C4 à C7).
    py -3.9 -B tools/autotest/banc.py --qui X10-GEL --out <archive> -- 2500 x10-gel-arene <source>

  Trois rangées identiques de 12 îlots (4 foreuses thermiques -> four, 4 foreuses thermiques -> coffre, 4 fours remplis à la main),
  sur trois forces : A et B sont des GROUPES DE BANC de la règle commune (interface « fo-gel », script/faction/gel_banc.lua), T est
  la jumelle TÉMOIN, jamais adoptée (le moteur la fait tourner). Aucun joueur pour A et B (liste vide : « loin »).
    tick 10    : arène posée, îlots de A et B adoptés ;
    ~640       : A et B figés (600 ticks de calme + guet) ;
    1 600      : un joueur posé à 100 tuiles de B : réveil au guet suivant (C5) ;
    2 380      : attaque sur A : réveil au guet suivant (C5) ;
    2 450      : bilan : A et B contre T (produits, gisement, charbon, statistiques de la force, products_finished) (C1) ;
               B après son réveil : pas de bouffée (C2) ; statistiques de A pendant le gel = plaques comptées (on_flow) ;
               rien d'autre de figé (C4).
               C1b : îlot par îlot à ± 1 fabrication de la jumelle (B à 1 630 après le pas dû ; A et B à la fin ; B après son réveil).
  Faits relevés : statut d'un inactif au moteur ; Gel.status rendu ; on_flow ; énergie des prototypes.
]]

local X0, Y0 = 4000, -3000
local ROWS = { A = 0, B = 24, T = 48 }
local FORCES = { A = "fo-gel-a", B = "fo-gel-b", T = "fo-gel-t" }
local N = 4
local COAL = 10
local ORE = 1000

local function iron_on(s, px, py)
  for _, dx in ipairs({ -0.5, 0.5 }) do
    for _, dy in ipairs({ -0.5, 0.5 }) do s.create_entity({ name = "iron-ore", position = { px + dx, py + dy }, amount = ORE }) end
  end
end

local function build_row(s, key)
  local y, force = Y0 + ROWS[key], FORCES[key]
  local row = { pairs4 = {}, chests = {}, qg = {}, res = {} }
  for i = 1, N do
    -- (a) foreuse -> four
    local px, py = X0 + (i - 1) * 4, y
    iron_on(s, px, py)
    local d = s.create_entity({ name = "burner-mining-drill", position = { px, py }, direction = defines.direction.north, force = force })
    local f = s.create_entity({ name = "stone-furnace", position = { px, py - 2 }, force = force })
    d.insert({ name = "coal", count = COAL })
    f.insert({ name = "coal", count = COAL })
    row.pairs4[i] = { d = d, f = f }
    -- (b) foreuse -> coffre
    px = X0 + 20 + (i - 1) * 4
    iron_on(s, px, py)
    local d2 = s.create_entity({ name = "burner-mining-drill", position = { px, py }, direction = defines.direction.north, force = force })
    local dp = d2.drop_position
    local c = s.create_entity({ name = "wooden-chest", position = { math.floor(dp.x) + 0.5, math.floor(dp.y) + 0.5 }, force = force })
    d2.insert({ name = "coal", count = COAL })
    row.chests[i] = { d = d2, c = c }
    -- (c) four du QG rempli à la main
    px = X0 + 40 + (i - 1) * 4
    local q = s.create_entity({ name = "stone-furnace", position = { px, py }, force = force })
    q.insert({ name = "coal", count = COAL })
    q.get_inventory(defines.inventory.furnace_source).insert({ name = "iron-ore", count = 30 })
    row.qg[i] = q
  end
  return row
end

local function machines(row)
  local out = {}
  for i = 1, N do
    out[#out + 1] = row.pairs4[i].d
    out[#out + 1] = row.pairs4[i].f
    out[#out + 1] = row.chests[i].d
    out[#out + 1] = row.qg[i]
  end
  return out
end

-- Relevé d'une rangée : plaques et minerai produits, gisement restant, énergie de combustible restante, products_finished.
local function measure(s, row, force)
  local m = { plates_a = 0, ore_b = 0, plates_c = 0, ore_left = 0, fuel_j = 0, finished = 0 }
  for i = 1, N do
    local p, c, q = row.pairs4[i], row.chests[i], row.qg[i]
    m.plates_a = m.plates_a + p.f.get_inventory(defines.inventory.furnace_result).get_item_count("iron-plate")
    m.ore_b = m.ore_b + c.c.get_inventory(defines.inventory.chest).get_item_count("iron-ore")
    m.plates_c = m.plates_c + q.get_inventory(defines.inventory.furnace_result).get_item_count("iron-plate")
    m.finished = m.finished + p.f.products_finished + q.products_finished
    for _, e in ipairs({ p.d, p.f, c.d, q }) do
      local b = e.burner
      m.fuel_j = m.fuel_j + b.inventory.get_item_count("coal") * 4000000 + (b.remaining_burning_fuel or 0)
    end
  end
  for _, r in ipairs(s.find_entities_filtered({ area = { { X0 - 3, Y0 + ROWS[force] - 3 }, { X0 + 60, Y0 + ROWS[force] + 3 } }, type = "resource" })) do
    m.ore_left = m.ore_left + r.amount
  end
  local st = game.forces[FORCES[force]].item_production_statistics
  m.stat_plates = st.get_input_count("iron-plate")
  m.stat_ore = st.get_input_count("iron-ore")
  m.stat_ore_out = st.get_output_count("iron-ore")
  return m
end

-- Lot X10-GEL, C1b (demande du lead, 7/11 vers 20 h 45) : produit livré ÎLOT PAR ÎLOT (plaques du four, minerai du coffre, plaques
-- du four du QG), pour la comparaison à ± 1 fabrication avec la jumelle de même rang.
local function per_ilot(row)
  local out = {}
  for i = 1, N do
    out[#out + 1] = row.pairs4[i].f.get_inventory(defines.inventory.furnace_result).get_item_count("iron-plate")
    out[#out + 1] = row.chests[i].c.get_inventory(defines.inventory.chest).get_item_count("iron-ore")
    out[#out + 1] = row.qg[i].get_inventory(defines.inventory.furnace_result).get_item_count("iron-plate")
  end
  return out
end

--- Écart îlot par îlot de deux relevés : (nombre d'îlots hors de ± tol, plus grand écart, détail).
local function ilot_gap(m, t, tol)
  local bad, worst, parts = 0, 0, {}
  for i = 1, #t do
    local d = m[i] - t[i]
    if math.abs(d) > tol then bad = bad + 1 end
    if math.abs(d) > math.abs(worst) then worst = d end
    parts[#parts + 1] = m[i] .. "/" .. t[i]
  end
  return bad, worst, table.concat(parts, " ")
end

local function near(a, b, rel, abs_tol)
  return math.abs(a - b) <= math.max(abs_tol, rel * math.max(math.abs(a), math.abs(b)))
end

local function count_inactive(list)
  local n = 0
  for _, e in ipairs(list) do if e.valid and not e.active then n = n + 1 end end
  return n
end

return {
  description = "X10-GEL palier A : avant-postes et fours figes contre une jumelle active",
  check_tick = 2450,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    local t = e.tick
    if t == 10 then
      ctx.prepare_area(X0 - 8, Y0 - 8, X0 + 60, Y0 + 56, "grass-1")
      for _, k in ipairs({ "A", "B", "T" }) do
        if not game.forces[FORCES[k]] then game.create_force(FORCES[k]) end
        game.forces[FORCES[k]].set_cease_fire("enemy", true)
        game.forces.enemy.set_cease_fire(FORCES[k], true)
      end
      for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 160, Y0 - 160 }, { X0 + 220, Y0 + 220 } } })) do en.destroy() end
      st.rows = { A = build_row(s, "A"), B = build_row(s, "B"), T = build_row(s, "T") }
      -- La cible est relue sur drop_position : drop_target reste nil tant que la foreuse n'a rien déposé (fait du 8/11, relevé ici).
      local ok_targets, nil_targets = 0, 0
      local function at_drop(d)
        local dp = d.drop_position
        local fx, fy = math.floor(dp.x), math.floor(dp.y)
        local l = s.find_entities_filtered({ area = { { fx + 0.01, fy + 0.01 }, { fx + 0.99, fy + 0.99 } }, type = { "furnace", "container" } })
        return l[1] and l[1].unit_number
      end
      for _, k in ipairs({ "A", "B", "T" }) do
        for i = 1, N do
          local p, c = st.rows[k].pairs4[i], st.rows[k].chests[i]
          if at_drop(p.d) == p.f.unit_number then ok_targets = ok_targets + 1 end
          if at_drop(c.d) == c.c.unit_number then ok_targets = ok_targets + 1 end
          if p.d.drop_target == nil then nil_targets = nil_targets + 1 end
          if c.d.drop_target == nil then nil_targets = nil_targets + 1 end
        end
      end
      ctx.check(ok_targets == 3 * 2 * N, "arene : chaque foreuse a son four ou son coffre sur la tuile de drop_position", ok_targets .. " / " .. (3 * 2 * N))
      do -- fait : recherche au POINT de drop_position (colliding with that position) contre la tuile
        local d, c = st.rows.T.chests[1].d, st.rows.T.chests[1].c
        local at_point = #s.find_entities_filtered({ position = d.drop_position, type = "container" })
        local bb = c.bounding_box
        ctx.log(string.format("fait : coffre de la foreuse : drop_position (%.3f, %.3f), boite du coffre (%.3f, %.3f)-(%.3f, %.3f), trouve au point : %d",
          d.drop_position.x, d.drop_position.y, bb.left_top.x, bb.left_top.y, bb.right_bottom.x, bb.right_bottom.y, at_point))
      end
      ctx.log(string.format("fait : drop_target nil au tick 10 (foreuses posees par script, rien depose) : %d / %d", nil_targets, 3 * 2 * N))
      local adopted, why = 0, {}
      for _, k in ipairs({ "A", "B" }) do
        ctx.remote("fo-gel", "banc", k, FORCES[k])
        ctx.remote("fo-gel", "joueurs", k, {})
        for i = 1, N do
          for _, ent in ipairs({ st.rows[k].pairs4[i].d, st.rows[k].chests[i].d, st.rows[k].qg[i] }) do
            local r = ctx.remote("fo-gel", "adopte", k, ent)
            if r and r.id then adopted = adopted + 1 else why[#why + 1] = tostring(r and r.why) end
          end
        end
      end
      ctx.check(adopted == 2 * 3 * N, "A et B : 24 ilots adoptes", adopted .. (#why > 0 and (" ; refus : " .. table.concat(why, ",")) or ""))
      do -- fait : sens de on_flow (positif : entrée ; négatif : sortie ?), sur une force à part
        if not game.forces["fo-gel-flux"] then game.create_force("fo-gel-flux") end
        local fs = game.forces["fo-gel-flux"].item_production_statistics
        local i0, o0 = fs.get_input_count("wood"), fs.get_output_count("wood")
        fs.on_flow("wood", 5)
        fs.on_flow("wood", -3)
        local di, dout = fs.get_input_count("wood") - i0, fs.get_output_count("wood") - o0
        ctx.log(string.format("fait : on_flow(+5) puis on_flow(-3) : entree %+d, sortie %+d", di, dout))
        ctx.check(di == 5 and dout == 3, "fait : on_flow negatif compte en SORTIE (consommation), positif en entree", di .. " / " .. dout)
      end
      local c = ctx.remote("fo-gel", "constantes")
      ctx.log(string.format("constantes : STEP %d, CALM %d, GUET %d, WAKE_R %d, FREEZE_R %d, WRITES %d", c.STEP, c.CALM, c.GUET, c.WAKE_R, c.FREEZE_R, c.WRITES))
      local d = st.rows.T.pairs4[1].d
      ctx.log(string.format("prototypes : foreuse energy_usage %.1f J/tick, mining_speed %.3f ; four energy_usage %.1f J/tick, crafting_speed %.2f",
        d.prototype.energy_usage, d.prototype.mining_speed, st.rows.T.qg[1].prototype.energy_usage, st.rows.T.qg[1].crafting_speed))
    elseif t == 700 then
      local fa, fb, ft = count_inactive(machines(st.rows.A)), count_inactive(machines(st.rows.B)), count_inactive(machines(st.rows.T))
      ctx.check(fa == 4 * N and fb == 4 * N, "C1 : A et B figes au tick 700 (machines inactives)", fa .. " et " .. fb .. " / " .. 4 * N)
      local dn = 0
      for _, k in ipairs({ "A", "T" }) do for i = 1, N do if st.rows[k].pairs4[i].d.drop_target == nil then dn = dn + 1 end end end
      ctx.log(string.format("fait : drop_target nil au tick 700 (A figee, T active ; foreuses -> four) : %d / %d", dn, 2 * N))
      ctx.check(ft == 0, "C4 : la jumelle T n'est jamais figee", ft .. " inactive(s)")
      local d = st.rows.A.pairs4[1].d
      ctx.log(string.format("fait : statut moteur d'une foreuse figee = %s (disabled_by_script = %s) ; Gel.status = %s (working = %s)", tostring(d.status),
        tostring(defines.entity_status.disabled_by_script), tostring(ctx.remote("fo-gel", "statut", d)), tostring(defines.entity_status.working)))
      ctx.check(d.status == defines.entity_status.disabled_by_script, "fait : un inactif rend disabled_by_script au moteur")
      ctx.check(ctx.remote("fo-gel", "statut", d) ~= defines.entity_status.disabled_by_script, "C6 : Gel.status ne rend jamais disabled_by_script pour une figee")
      st.a700 = measure(s, st.rows.A, "A")
    elseif t == 1600 then
      ctx.remote("fo-gel", "joueurs", "B", { { x = X0 + 20, y = Y0 + ROWS.B + 100 } })
      st.wake_b_from = t
    elseif t == 1625 then
      local fb = count_inactive(machines(st.rows.B))
      ctx.check(fb == 0, "C5 : joueur a 100 tuiles de B : B reveille en 20 ticks au plus", fb .. " inactive(s) au tick 1625")
    elseif t == 1630 then
      st.b1630, st.t1630 = measure(s, st.rows.B, "B"), measure(s, st.rows.T, "T")
      st.ib1630, st.it1630 = per_ilot(st.rows.B), per_ilot(st.rows.T)
      local bad, worst, detail = ilot_gap(st.ib1630, st.it1630, 1)
      ctx.check(bad == 0, "C1b (1) : B juste apres son reveil (pas du credite) : chaque ilot a +-1 fabrication de sa jumelle",
        bad .. " ilot(s) hors, ecart max " .. worst .. " ; " .. detail)
    elseif t == 2370 then
      st.a2370 = measure(s, st.rows.A, "A")
    elseif t == 2380 then
      ctx.remote("fo-gel", "cause", "A", "attack_t", t)
    elseif t == 2420 then
      local fa = count_inactive(machines(st.rows.A))
      ctx.check(fa == 0, "C5 : attaque sur A : A reveille au guet suivant", fa .. " inactive(s) au tick 2420")
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local A, B, T = measure(s, st.rows.A, "A"), measure(s, st.rows.B, "B"), measure(s, st.rows.T, "T")
    local function line(k, m)
      return string.format("%s : plaques four %d, minerai coffre %d, plaques QG %d, gisement %d, combustible %.1f MJ, products_finished %d, stats plaques %d minerai %d (consomme %d)",
        k, m.plates_a, m.ore_b, m.plates_c, m.ore_left, m.fuel_j / 1e6, m.finished, m.stat_plates, m.stat_ore, m.stat_ore_out)
    end
    ctx.log(line("A", A)); ctx.log(line("B", B)); ctx.log(line("T", T))
    for _, k in ipairs({ "A", "B" }) do
      local M = (k == "A") and A or B
      ctx.check(near(M.plates_a, T.plates_a, 0.05, 2), "C1 " .. k .. " : plaques foreuse -> four a +-5 % (ou 2) de T", M.plates_a .. " / " .. T.plates_a)
      ctx.check(near(M.ore_b, T.ore_b, 0.05, 2), "C1 " .. k .. " : minerai foreuse -> coffre a +-5 % (ou 2) de T", M.ore_b .. " / " .. T.ore_b)
      ctx.check(near(M.plates_c, T.plates_c, 0.05, 2), "C1 " .. k .. " : plaques des fours du QG a +-5 % (ou 2) de T", M.plates_c .. " / " .. T.plates_c)
      local mined_m, mined_t = 2 * N * 4 * ORE - M.ore_left, 2 * N * 4 * ORE - T.ore_left
      ctx.check(near(mined_m, mined_t, 0.05, 2), "C1 " .. k .. " : minerai retire du gisement a +-5 % (ou 2) de T", mined_m .. " / " .. mined_t)
      local burn_m, burn_t = 4 * N * COAL * 4e6 - M.fuel_j, 4 * N * COAL * 4e6 - T.fuel_j
      ctx.check(near(burn_m, burn_t, 0.10, 4e6), "C1 " .. k .. " : combustible brule a +-10 % (ou 1 charbon) de T",
        string.format("%.1f / %.1f MJ", burn_m / 1e6, burn_t / 1e6))
      ctx.check(near(M.stat_plates, T.stat_plates, 0.05, 2), "C1 " .. k .. " : statistiques de la force (plaques) a +-5 % (ou 2) de T", M.stat_plates .. " / " .. T.stat_plates)
      ctx.check(near(M.finished, T.finished, 0.05, 2), "C1 " .. k .. " : products_finished a +-5 % (ou 2) de T", M.finished .. " / " .. T.finished)
      ctx.check(near(M.stat_ore, T.stat_ore, 0.05, 2), "C1 " .. k .. " : statistiques de la force (minerai produit) a +-5 % (ou 2) de T", M.stat_ore .. " / " .. T.stat_ore)
      ctx.check(near(M.stat_ore_out, T.stat_ore_out, 0.05, 2), "C1 " .. k .. " : statistiques de la force (minerai consomme) a +-5 % (ou 2) de T", M.stat_ore_out .. " / " .. T.stat_ore_out)
    end
    -- on_flow : pendant le gel de A (700 à 2370), statistiques = plaques déposées aux sorties
    if st.a700 and st.a2370 then
      local dstat = st.a2370.stat_plates - st.a700.stat_plates
      local dplates = (st.a2370.plates_a + st.a2370.plates_c) - (st.a700.plates_a + st.a700.plates_c)
      ctx.check(dstat == dplates and dplates > 0, "fait : on_flow(+n) monte les statistiques de n (A figee, 700 a 2370)", dstat .. " / " .. dplates)
    end
    -- pas de bouffée : B après son réveil (1630 à 2450) au plus T + 5 % + 2
    if st.b1630 and st.t1630 then
      local db = (B.plates_a + B.ore_b + B.plates_c) - (st.b1630.plates_a + st.b1630.ore_b + st.b1630.plates_c)
      local dt = (T.plates_a + T.ore_b + T.plates_c) - (st.t1630.plates_a + st.t1630.ore_b + st.t1630.plates_c)
      ctx.check(db <= dt * 1.05 + 2, "C2 : B apres son reveil : pas de bouffee (au plus T + 5 % + 2)", db .. " / " .. dt)
    end
    -- C1b (2) et (3) : îlot par îlot, à la fin ; B après son réveil, pas de saut au double
    local iA, iB, iT = per_ilot(st.rows.A), per_ilot(st.rows.B), per_ilot(st.rows.T)
    for _, k in ipairs({ "A", "B" }) do
      local bad, worst, detail = ilot_gap(k == "A" and iA or iB, iT, 1)
      ctx.check(bad == 0, "C1b (2) " .. k .. " : a la fin, chaque ilot a +-1 fabrication de sa jumelle", bad .. " ilot(s) hors, ecart max " .. worst .. " ; " .. detail)
    end
    if st.ib1630 then
      local jump, worst = 0, 0
      for i = 1, #iT do
        local d = (iB[i] - st.ib1630[i]) - (iT[i] - st.it1630[i])
        if d > 1 then jump = jump + 1 end
        if d > worst then worst = d end
      end
      ctx.check(jump == 0, "C1b (3) : B de 1630 a la fin : chaque ilot au plus la jumelle + 1 (pas de saut au double)", jump .. " ilot(s), exces max " .. worst)
    end
    local all = {}
    for _, k in ipairs({ "A", "B", "T" }) do for _, m in ipairs(machines(st.rows[k])) do all[#all + 1] = m end end
    ctx.check(count_inactive(all) == 0, "C4 : plus rien de fige a la fin", count_inactive(all) .. " inactive(s)")
    local ea, eb = ctx.remote("fo-gel", "etat", "A"), ctx.remote("fo-gel", "etat", "B")
    ctx.check(ea.pertes == 0 and eb.pertes == 0, "C2 : aucune perte au depot (insert refuse)", ea.pertes .. " et " .. eb.pertes)
  end,
}
