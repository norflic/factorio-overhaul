--[[
  Scénario GREFFÉ « calcul-modulaire » (lot CALCUL-V2, 30/10) : le centre de calcul MODULAIRE en moteur réel.
  Règle pure : shared/content/compute_rack.lua (recopiée ICI, indépendamment du mod, pour les attendus : RULE ci-dessous).

  Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui CALCUL-V2 -- 1000 calcul-modulaire <source>

  1. Prototypes : 2 centres (4 × 4, 6 emplacements ; 6 × 6, 12), allowed_effects = { pollution } seul ; 7 baies (modules de
     catégorie fo-baie, seul effet pollution, limitation = recettes de refroidissement) ; tout AUTRE module porte un effet
     hors pollution (refusé par le centre, balises comprises) ; 13 machines neuves sans emplacement de module.
  2. Hypothèses moteur : H-CV2-1 une baie entre dans le centre et y agit (pollution_bonus) ; H-CV2-2 une baie est refusée
     par un assembleur qui a une autre recette ; un module de vitesse est refusé par le centre ; H-CV2-3 une baie dans une
     balise vanilla (fait relevé) ; aucune balise de complément MOD-1 sous un centre.
  3. Centres A à E garnis de baies, de fluides (eau glacée, azote, mélange à dilution) : au contrôle (tick 600), pour chaque
     centre, comptes lus = baies posées, r ≥ 0,99 si nourri, e ≥ 0,99 sur le réseau plein, et calcul / kW / chaleur =
     RÈGLE (± 1 %) ; compagnon : power_usage = kW des baies ; calcul de la force = somme ; vitesse de recherche = base + bonus.
     E sur un réseau BRIDÉ (une source de 50 % de la demande) : H-CV2-4, e entre 0,35 et 0,65, calcul = règle avec e lu.
  4. Baies retirées de A (tick 660) : son calcul suit la règle (tick 780). Centre B détruit (raise_destroy, tick 800) :
     son compagnon disparaît (tick 880).
]]

local X0, Y0 = 6200, 3000
local CHECK = 900
local T_READ, T_REMOVE, T_READ2, T_KILL, T_READ3 = 600, 660, 780, 800, 880

-- Règle (copie indépendante du plan §2, pour les attendus).
local RK = {
  ["fo-server-blade"] = { "cpu", 100, 1000, 1000 }, ["fo-memory-rack"] = { "memory", 0, 300, 300 },
  ["fo-storage-rack"] = { "storage", 0, 300, 300 }, ["fo-network-rack"] = { "network", 0, 200, 200 },
  ["fo-cooling-rack"] = { "cooling", 0, 150, 150 }, ["fo-gpu-blade"] = { "gpu", 400, 2500, 2500 },
  ["fo-quantum-rack"] = { "quantum", 2000, 1500, 500 },
}
local RACKS = { "fo-server-blade", "fo-memory-rack", "fo-storage-rack", "fo-network-rack", "fo-cooling-rack", "fo-gpu-blade", "fo-quantum-rack" }
local CEN = { ["fo-data-center"] = { base = 300, passive = 1500 }, ["fo-data-center-2"] = { base = 600, passive = 3000 } }
local K = { ["fo-dc-chilled-water"] = 1, ["fo-dc-liquid-nitrogen"] = 2.5, ["fo-dc-dilution"] = 1 }
local function RULE(racks, center, recipe, r, e)
  local n = { cpu = 0, memory = 0, storage = 0, network = 0, cooling = 0, gpu = 0, quantum = 0 }
  local kw, heat = CEN[center].base, 0
  for name, c in pairs(racks) do local x = RK[name]; n[x[1]] = n[x[1]] + c; kw = kw + c * x[3]; heat = heat + c * x[4] end
  local d = n.cpu + 3 * n.gpu
  local fm = d > 0 and math.min(1, 4 * n.memory / d) or 1
  local brut = (100 * n.cpu + 400 * n.gpu) * fm + ((recipe == "fo-dc-dilution") and 2000 * math.min(n.quantum, n.cpu) or 0)
  local cool = CEN[center].passive + (K[recipe] and r or 0) * n.cooling * 2000 * (K[recipe] or 0)
  local fh = heat > 0 and math.min(1, cool / heat) or 1
  local v = math.min(300 + 1000 * n.network, math.min(200 + 600 * n.storage, brut * fh * e))
  return v, kw, heat
end

-- Centres : clé, nom, recette, baies, fluides à garder, réseau
local CENTRES = {
  { key = "A-cpu", name = "fo-data-center", r = "fo-dc-chilled-water",
    racks = { ["fo-server-blade"] = 3, ["fo-memory-rack"] = 1, ["fo-cooling-rack"] = 1, ["fo-storage-rack"] = 1 },
    fluids = { { "fo-chilled-water", 200 } } },
  { key = "B-passif", name = "fo-data-center", r = "fo-dc-chilled-water",
    racks = { ["fo-server-blade"] = 3, ["fo-memory-rack"] = 1, ["fo-cooling-rack"] = 1, ["fo-storage-rack"] = 1 },
    fluids = {}, starve = true },
  { key = "C-gpu-azote", name = "fo-data-center-2", r = "fo-dc-liquid-nitrogen",
    racks = { ["fo-gpu-blade"] = 3, ["fo-server-blade"] = 2, ["fo-memory-rack"] = 3, ["fo-cooling-rack"] = 1,
              ["fo-storage-rack"] = 2, ["fo-network-rack"] = 1 },
    fluids = { { "fo-liquid-nitrogen", 200 } } },
  { key = "D-quantique", name = "fo-data-center-2", r = "fo-dc-dilution",
    racks = { ["fo-quantum-rack"] = 2, ["fo-server-blade"] = 2, ["fo-memory-rack"] = 1, ["fo-cooling-rack"] = 2,
              ["fo-storage-rack"] = 3, ["fo-network-rack"] = 2 },
    fluids = { { "fo-chilled-water", 200 }, { "fo-dilution-mix", 40 } } },
  { key = "E-bride", name = "fo-data-center", r = nil, racks = { ["fo-server-blade"] = 1, ["fo-memory-rack"] = 1 },
    fluids = {}, limited = true },
}
local WARM = "fo-warm-water"

local function size_of(name)
  local b = game.entity_prototypes[name].collision_box
  return math.ceil(b.right_bottom.x - b.left_top.x)
end
local function center_of(e) return remote.call("fo-calcul", "center", e) end

return {
  description = "CALCUL-V2 : centre de calcul modulaire (baies), regle pure en moteur reel, courant bride, exclusivite des modules",
  check_tick = CHECK,
  shots_delay = 300,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    -- 1. Prototypes
    local bad = {}
    for cname, slots in pairs({ ["fo-data-center"] = 6, ["fo-data-center-2"] = 12 }) do
      local p = game.entity_prototypes[cname]
      if not p then bad[#bad + 1] = cname .. " absent"
      else
        if (p.module_inventory_size or 0) ~= slots then bad[#bad + 1] = cname .. " : " .. tostring(p.module_inventory_size) .. " emplacements" end
        local ae, n = p.allowed_effects or {}, 0
        for k, v in pairs(ae) do if v then n = n + 1; if k ~= "pollution" then bad[#bad + 1] = cname .. " admet " .. k end end end
        if not ae.pollution or n ~= 1 then bad[#bad + 1] = cname .. " : allowed_effects " .. serpent.line(ae) end
      end
    end
    ctx.check(#bad == 0, "centres : 6 et 12 emplacements, allowed_effects = { pollution } seul", table.concat(bad, " ; "))
    local cool = {}
    for _, n in ipairs({ "fo-dc-chilled-water", "fo-dc-liquid-nitrogen", "fo-dc-dilution" }) do cool[n] = true end
    bad = {}
    for _, n in ipairs(RACKS) do
      local p = game.item_prototypes[n]
      if not (p and p.type == "module") then bad[#bad + 1] = n .. " pas un module"
      else
        local eff = p.module_effects or {}
        for k in pairs(eff) do if k ~= "pollution" then bad[#bad + 1] = n .. " effet " .. k end end
        if not eff.pollution then bad[#bad + 1] = n .. " sans pollution" end
        local lim = p.limitations or {}
        local okl = #lim == 3
        for _, r in ipairs(lim) do if not cool[r] then okl = false end end
        if not okl then bad[#bad + 1] = n .. " limitation " .. serpent.line(lim) end
        if p.category ~= "fo-baie" then bad[#bad + 1] = n .. " categorie " .. tostring(p.category) end
      end
    end
    ctx.check(#bad == 0, "7 baies : modules fo-baie, seul effet pollution, limitation = 3 refroidissements", table.concat(bad, " ; "))
    local others, wrong = 0, {}
    local names = {}
    for n in pairs(game.get_filtered_item_prototypes({ { filter = "type", type = "module" } })) do names[#names + 1] = n end
    table.sort(names)
    for _, n in ipairs(names) do
      if not RK[n] then
        others = others + 1
        local outside = false
        for k in pairs(game.item_prototypes[n].module_effects or {}) do if k ~= "pollution" then outside = true end end
        if not outside then wrong[#wrong + 1] = n end
      end
    end
    ctx.check(others > 0 and #wrong == 0, others .. " autres modules (vanilla, mod, balises) : tous portent un effet hors pollution (refuses par le centre)",
      table.concat(wrong, ", "))
    local MACH = { "fo-crystal-puller", "fo-wire-saw", "fo-plasma-etcher", "fo-die-prober", "fo-packaging-line", "fo-smt-line",
                   "fo-fiber-tower", "fo-rack-integrator", "fo-chiller", "fo-cooling-tower", "fo-dilution-fridge", "fo-quantum-lab" }
    bad = {}
    for _, n in ipairs(MACH) do
      local p = game.entity_prototypes[n]
      if not p then bad[#bad + 1] = n .. " absent" elseif (p.module_inventory_size or 0) ~= 0 then bad[#bad + 1] = n .. " a des emplacements" end
    end
    ctx.check(#bad == 0, #MACH .. " machines d'etape presentes, aucun emplacement de module (pas de module d'effet pour le calcul)", table.concat(bad, " ; "))

    -- Recherche
    local f = game.forces.player
    f.research_all_technologies()
    st.base = f.laboratory_speed_modifier

    -- 3. Terrain, courant, centres
    ctx.prepare_area(X0 - 6, Y0 - 12, X0 + 240, Y0 + 14, "refined-concrete")
    for _, e in ipairs(s.find_entities_filtered({ area = { { X0 - 120, Y0 - 120 }, { X0 + 360, Y0 + 120 } }, force = "enemy" })) do e.destroy() end
    ctx.power(X0 + 30, Y0 + 11)
    st.centres = {}
    local x = X0
    for i, c in ipairs(CENTRES) do
      if c.limited then x = X0 + 200 end
      local side = size_of(c.name)
      local px, py = x + side / 2, Y0
      local e = s.create_entity({ name = c.name, position = { px, py }, force = "player", raise_built = true })
      if e then
        if c.r then e.set_recipe(c.r) end
        local inv = e.get_module_inventory()
        for _, n in ipairs(RACKS) do if c.racks[n] then inv.insert({ name = n, count = c.racks[n] }) end end
        for _, fl in ipairs(c.fluids) do e.insert_fluid({ name = fl[1], amount = fl[2] }) end
      end
      st.centres[i] = { key = c.key, e = e, x = px, y = py, side = side }
      x = x + side + 3
    end
    -- Réseau bridé pour E : sa propre source, 50 % de la demande de ses baies (1 300 kW).
    do
      local c = st.centres[5]
      s.create_entity({ name = "fo-autotest-power-pole", position = { c.x, c.y + 5 }, force = "player" })
      local src = s.create_entity({ name = "fo-autotest-power-source", position = { c.x, c.y + 5 }, force = "player" })
      local per_tick = 0.5 * 1300e3 / 60
      src.power_production = per_tick
      src.electric_buffer_size = per_tick
      src.energy = 0
      st.limited_src = src
    end
    local placed = 0
    for _, c in ipairs(st.centres) do if c.e then placed = placed + 1 end end
    ctx.check(placed == #CENTRES, placed .. " centres poses, baies et fluides verses")

    -- 2. Hypothèses moteur
    local A = st.centres[1].e
    local inv = A.get_module_inventory()
    local speed = inv.insert({ name = "speed-module-3", count = 1 })
    ctx.log("H-CV2 : module de vitesse insere par script dans le centre : " .. speed)
    st.speed_in_center = speed
    if speed > 0 then inv.remove({ name = "speed-module-3", count = speed }) end
    local am = s.create_entity({ name = "assembling-machine-3", position = { X0 + 20, Y0 + 9 }, force = "player" })
    am.set_recipe("iron-gear-wheel")
    st.blade_in_asm = am.get_module_inventory().insert({ name = "fo-server-blade", count = 1 })
    local bc = s.create_entity({ name = "beacon", position = { X0 + 26, Y0 + 9 }, force = "player" })
    st.blade_in_beacon = bc and bc.get_module_inventory().insert({ name = "fo-server-blade", count = 1 }) or -1
    if bc then bc.destroy() end
    ctx.log(string.format("H-CV2-2 : baie inseree par script dans un assembleur (engrenages) : %d ; H-CV2-3 : dans une balise vanilla : %d",
      st.blade_in_asm, st.blade_in_beacon))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick % 30 == 0 and e.tick < CHECK then
      for i, c in ipairs(CENTRES) do
        local m = st.centres[i] and st.centres[i].e
        if m and m.valid then
          for _, fl in ipairs(c.fluids) do
            if m.get_fluid_count(fl[1]) < fl[2] then m.insert_fluid({ name = fl[1], amount = fl[2] - m.get_fluid_count(fl[1]) }) end
          end
          local w = m.get_fluid_count(WARM)
          if w > 0 then m.remove_fluid({ name = WARM, amount = w }) end
        end
      end
    end
    local function read(tag)
      local out = {}
      for i, c in ipairs(st.centres) do
        if c.e and c.e.valid then
          local ev = center_of(c.e)
          local p = remote.call("fo-calcul", "companion", c.e)
          out[i] = { ev = ev and { compute = ev.compute, kw = ev.kw, heat = ev.heat, r = ev.r, e = ev.e, limit = ev.limit,
                                   counts = ev.counts } or nil,
                     usage = p and p.valid and p.power_usage or -1, p_unit = p and p.valid and p.unit_number or -1,
                     poll = c.e.pollution_bonus, contents = c.e.get_module_inventory().get_contents() }
          if ev then
            ctx.log(string.format("%s %s : %.2f u/s, %.0f kW, chaleur %.0f, r %.3f, e %.3f, limite %s, compagnon %.1f J/tick",
              tag, c.key, ev.compute, ev.kw, ev.heat, ev.r, ev.e, ev.limit, out[i].usage))
          end
        end
      end
      local cs = remote.call("fo-calcul", "state", "player")
      return { centres = out, rate = cs.rate, bonus = cs.bonus, mod = game.forces.player.laboratory_speed_modifier }
    end
    if e.tick == T_READ then
      st.r1 = read("LECTURE")
      local mm = 0
      for _, c in ipairs(st.centres) do
        if c.e and c.e.valid then
          local p = c.e.position
          mm = mm + c.e.surface.count_entities_filtered({ name = "fo-mm-balise", area = { { p.x - 0.5, p.y - 0.5 }, { p.x + 0.5, p.y + 0.5 } } })
        end
      end
      st.mm = mm
    elseif e.tick == T_REMOVE then
      local inv = st.centres[1].e.get_module_inventory()
      inv.remove({ name = "fo-server-blade", count = 2 })
      inv.remove({ name = "fo-cooling-rack", count = 1 })
    elseif e.tick == T_READ2 then
      st.r2 = read("APRES RETRAIT")
    elseif e.tick == T_KILL then
      local b = st.centres[2]
      st.b_unit = b.e.unit_number
      st.b_comp = remote.call("fo-calcul", "companion", b.e)
      b.e.destroy({ raise_destroy = true })
    elseif e.tick == T_READ3 then
      st.b_comp_valid = st.b_comp and st.b_comp.valid or false
      st.r3 = read("APRES DESTRUCTION")
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    -- 2. hypothèses
    ctx.check(st.speed_in_center == 0, "H-CV2 : module de vitesse refuse par le centre (insertion par script)", st.speed_in_center)
    ctx.check(st.blade_in_asm == 0, "H-CV2-2 : baie refusee par un assembleur sur une autre recette (insertion par script)", st.blade_in_asm)
    ctx.log("H-CV2-3 (fait) : baie dans une balise vanilla = " .. tostring(st.blade_in_beacon))
    ctx.check(st.mm == 0, "aucune balise de complement MOD-1 sous un centre", st.mm)
    -- 3. lecture au tick T_READ
    local r1 = st.r1 or { centres = {} }
    local sum, okc, detail = 0, 0, {}
    for i, c in ipairs(CENTRES) do
      local got = r1.centres[i]
      local ev = got and got.ev
      local fault = nil
      if not ev then fault = "pas d'evaluation"
      else
        local counts_ok = true
        for _, n in ipairs(RACKS) do if (got.contents[n] or 0) ~= (c.racks[n] or 0) then counts_ok = false end end
        local r_want = (c.r and not c.starve) and 1 or 0
        local e_used = ev.e
        if not c.limited and ev.e < 0.99 then fault = string.format("e %.3f < 0,99 sur le reseau plein", ev.e) end
        if c.limited and (ev.e < 0.35 or ev.e > 0.65) then fault = string.format("e %.3f hors de [0,35 ; 0,65] sur le reseau bride", ev.e) end
        if r_want == 1 and ev.r < 0.99 then fault = string.format("r %.3f < 0,99 (recette nourrie)", ev.r) end
        if r_want == 0 and ev.r > 0.01 then fault = string.format("r %.3f > 0 (sans fluide)", ev.r) end
        local v, kw, heat = RULE(c.racks, c.name, c.r, r_want, c.limited and e_used or 1)
        if not fault and math.abs(ev.compute - v) > 0.01 * math.max(v, 1) then fault = string.format("calcul %.2f contre %.2f", ev.compute, v) end
        if not fault and math.abs(ev.kw - kw) > 1e-6 then fault = string.format("kW %.1f contre %.1f", ev.kw, kw) end
        if not fault and math.abs(ev.heat - heat) > 1e-6 then fault = "chaleur " .. ev.heat .. " contre " .. heat end
        if not fault and math.abs(got.usage - (kw - CEN[c.name].base) * 1000 / 60) > 1e-3 then fault = "compagnon " .. got.usage end
        if not fault and not counts_ok then fault = "baies lues differentes des baies posees" end
        local nr = 0
        for _, n in pairs(c.racks) do nr = nr + n end
        if not fault and math.abs(got.poll - 0.05 * nr) > 1e-6 then fault = string.format("pollution_bonus %.3f contre %.3f (H-CV2-1)", got.poll, 0.05 * nr) end
        detail[#detail + 1] = string.format("%s %.1f/%.1f", c.key, ev.compute, v)
        sum = sum + ev.compute
      end
      ctx.check(fault == nil, "centre " .. c.key .. " : calcul, kW, chaleur, compagnon = regle pure (r, e lus), baies actives (pollution)", fault)
      if not fault then okc = okc + 1 end
    end
    ctx.check(math.abs((r1.rate or -1) - sum) < 1e-6 and sum > 0, "calcul de la force = somme des centres", string.format("%.2f = %.2f", r1.rate or -1, sum))
    ctx.check(math.abs((r1.mod or -1) - (st.base + (r1.bonus or 0))) < 1e-9 and (r1.bonus or 0) > 0,
      "vitesse de recherche = base des technologies + bonus", string.format("%.4f = %.4f + %.4f", r1.mod or -1, st.base, r1.bonus or 0))
    -- 4. baies retirées de A
    local a2 = st.r2 and st.r2.centres[1] and st.r2.centres[1].ev
    local left = { ["fo-server-blade"] = 1, ["fo-memory-rack"] = 1, ["fo-storage-rack"] = 1 }
    local v2 = RULE(left, "fo-data-center", "fo-dc-chilled-water", 1, 1)
    ctx.check(a2 and math.abs(a2.compute - v2) <= 0.01 * v2, "baies retirees du centre A : calcul = regle (1 CPU, 1 memoire, 1 stockage)",
      a2 and string.format("%.2f contre %.2f", a2.compute, v2) or "absent")
    ctx.check(st.b_comp ~= nil and st.b_comp_valid == false, "centre B detruit : son compagnon d'energie retire", tostring(st.b_comp_valid))
    local r3 = st.r3 or { centres = {} }
    local after = 0
    for i = 1, #CENTRES do local c = r3.centres[i]; if c and c.ev and i ~= 2 then after = after + c.ev.compute end end
    ctx.check(r3.centres[2] == nil and math.abs((r3.rate or -1) - after) < 1e-6, "force apres destruction : somme des centres restants",
      string.format("%.2f", r3.rate or -1))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    for _, c in ipairs(st.centres or {}) do
      add("centre-" .. c.key .. "-z2-jour", c.x, c.y, 2, 0, { res = { (c.side + 6) * 64, (c.side + 6) * 64 }, info = true, aa = true })
    end
  end,
}
