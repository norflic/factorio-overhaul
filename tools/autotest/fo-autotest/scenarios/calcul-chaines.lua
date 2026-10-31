--[[
  Scénario GREFFÉ « calcul-chaines » (lot CALCUL, 30/10 ; refait au lot CALCUL-V2, 30/10) : la chaîne du calcul en moteur
  réel, UNE MACHINE PAR ÉTAPE (shared/content/compute_chain.lua, prototypes/compute_v2.lua, script/compute/compute.lua).

  Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui CALCUL-V2 -- 2800 calcul-chaines <source>   (2 800 ticks : la tireuse met 40 s par lingot, 2 400 ticks)
  Images    : même commande avec --captures --visuel="--no-atlas-cache"

  1. Prototypes v2 présents (13 machines, objets, baies, fluides, recettes, 7 technologies) ; recettes v1 CACHÉES mais
     présentes.
  2. Toutes les technologies du calcul (v1 et v2), recherchées par script, ouvrent leurs recettes.
  3. Chaque étape dans SA machine, garnie par script : au contrôle, chaque poste a fini au moins une fabrication et son
     produit est dans sa sortie (fluide : compté à la sortie). Deux recettes v1 cachées tournent encore (sauvegardes).
  4. Le CALCUL : 3 centres modulaires (CPU, GPU, quantique) en marche → « fo-calcul » lit la somme attendue (± 2 %) et la
     vitesse de recherche = base + bonus ; baies retirées (rangées dans un coffre) → 0 unité/s et la vitesse revient
     EXACTEMENT à la base (vitesse de recherche 2 recherchée en marche comprise : calcul non stockable) ; baies remises → le
     calcul revient ; aucune baie usée (capital, plus de consommable).
]]

local X0, Y0 = 4200, 3000
local CHECK = 2700 -- la recette du lingot dure 40 s (2 400 ticks) : le contrôle vient après sa première fabrication
local T_FULL, T_TECH, T_STOP, T_STOPPED, T_RESTART, T_BACK = 600, 900, 1200, 1330, 1400, 1630

local TECHS = { "fo-chip-foundry", "fo-wafer-fab", "fo-data-centers", "fo-gpu-computing", "fo-data-centers-2",
                "fo-regolith-degassing", "fo-quantum-computing" }
local ITEMS = { "fo-silicon-ingot", "fo-exposed-wafer", "fo-nand-die", "fo-flash-drive", "fo-optical-fiber", "fo-network-switch",
                "fo-server-blade", "fo-memory-rack", "fo-storage-rack", "fo-network-rack", "fo-cooling-rack", "fo-gpu-blade",
                "fo-quantum-rack" }
local FLUIDS = { "fo-chilled-water", "fo-warm-water", "fo-dilution-mix", "fo-photoresist", "fo-helium-3" }
local BUILDINGS = { "fo-crystal-puller", "fo-wire-saw", "fo-crystal-lithograph", "fo-plasma-etcher", "fo-die-prober",
                    "fo-packaging-line", "fo-smt-line", "fo-fiber-tower", "fo-rack-integrator", "fo-chiller", "fo-cooling-tower",
                    "fo-data-center", "fo-data-center-2", "fo-dilution-fridge", "fo-quantum-lab" }
local HIDDEN = { "fo-etched-wafer", "fo-logic-die", "fo-memory-module", "fo-server-blade", "fo-compute-classic", "fo-data-center" }

local PCB, OSC = "fo-printed-circuit-board", "fo-crystal-oscillator"
-- Postes : machine, recette, produit principal, garniture { objets }, { fluides }, sortie fluide ?
local POSTES = {
  { key = "lingot", m = "fo-crystal-puller", r = "fo-silicon-ingot", p = "fo-silicon-ingot",
    items = { { "fo-pure-silicon", 20 }, { "fo-graphite", 2 } } },
  { key = "sciage", m = "fo-wire-saw", r = "fo-ingot-sawing", p = "fo-silicon-wafer",
    items = { { "fo-silicon-ingot", 2 }, { "fo-crystal-powder", 4 } }, fluids = { { "water", 100 } } },
  { key = "insolation", m = "fo-crystal-lithograph", r = "fo-wafer-exposure", p = "fo-exposed-wafer",
    items = { { "fo-silicon-wafer", 20 }, { "fo-photomask", 2 } }, fluids = { { "fo-photoresist", 50 } } },
  { key = "gravure", m = "fo-plasma-etcher", r = "fo-plasma-etching", p = "fo-etched-wafer",
    items = { { "fo-exposed-wafer", 20 } }, fluids = { { "sulfuric-acid", 50 }, { "fo-hydrogen", 100 } } },
  { key = "logique", m = "fo-die-prober", r = "fo-die-test-logic", p = "fo-logic-die", items = { { "fo-etched-wafer", 4 } } },
  { key = "dram", m = "fo-die-prober", r = "fo-die-test-dram", p = "fo-dram-die", items = { { "fo-etched-wafer", 4 } } },
  { key = "sram", m = "fo-die-prober", r = "fo-die-test-sram", p = "fo-sram-die", items = { { "fo-etched-wafer", 4 } } },
  { key = "nand", m = "fo-die-prober", r = "fo-die-test-nand", p = "fo-nand-die", items = { { "fo-etched-wafer", 4 } } },
  { key = "processeur", m = "fo-packaging-line", r = "fo-packaged-processor", p = "processing-unit",
    items = { { "fo-logic-die", 2 }, { "fo-sram-die", 4 }, { PCB, 2 }, { "fo-heat-sink", 2 }, { "electronic-circuit", 24 }, { "advanced-circuit", 4 } } },
  { key = "flash", m = "fo-packaging-line", r = "fo-flash-drive", p = "fo-flash-drive",
    items = { { "fo-nand-die", 16 }, { PCB, 2 }, { "plastic-bar", 4 } } },
  { key = "fibre", m = "fo-fiber-tower", r = "fo-optical-fiber", p = "fo-optical-fiber", items = { { "fo-glass", 4 }, { "fo-crystal-powder", 2 } } },
  { key = "carte-mere", m = "fo-smt-line", r = "fo-smt-motherboard", p = "fo-motherboard",
    items = { { PCB, 4 }, { OSC, 2 }, { "advanced-circuit", 4 }, { "copper-cable", 8 } } },
  { key = "barrette", m = "fo-smt-line", r = "fo-smt-memory-module", p = "fo-memory-module",
    items = { { "fo-dram-die", 16 }, { PCB, 2 }, { "fo-tin-plate", 2 } } },
  { key = "commutateur", m = "fo-smt-line", r = "fo-network-switch", p = "fo-network-switch",
    items = { { "fo-optical-fiber", 16 }, { "fo-logic-die", 4 }, { PCB, 2 }, { "copper-cable", 8 } } },
  { key = "carte-graphique", m = "fo-smt-line", r = "fo-smt-graphics-card", p = "fo-graphics-card",
    items = { { "fo-logic-die", 4 }, { "fo-dram-die", 8 }, { PCB, 1 }, { "fo-heat-sink", 2 }, { "fo-titanium-plate", 1 } } },
  { key = "baie-cpu", m = "fo-rack-integrator", r = "fo-rack-cpu", p = "fo-server-blade",
    items = { { "fo-motherboard", 1 }, { "processing-unit", 2 }, { "fo-memory-module", 2 }, { "fo-heat-sink", 2 }, { "steel-plate", 5 } } },
  { key = "baie-memoire", m = "fo-rack-integrator", r = "fo-rack-memory", p = "fo-memory-rack",
    items = { { "fo-motherboard", 1 }, { "fo-memory-module", 30 }, { "fo-heat-sink", 2 }, { "steel-plate", 5 } } },
  { key = "baie-stockage", m = "fo-rack-integrator", r = "fo-rack-storage", p = "fo-storage-rack",
    items = { { "fo-motherboard", 1 }, { "fo-flash-drive", 16 }, { "processing-unit", 1 }, { "steel-plate", 5 } } },
  { key = "baie-reseau", m = "fo-rack-integrator", r = "fo-rack-network", p = "fo-network-rack",
    items = { { "fo-network-switch", 6 }, { "fo-optical-fiber", 20 }, { "processing-unit", 1 }, { "steel-plate", 5 } } },
  { key = "baie-froid", m = "fo-rack-integrator", r = "fo-rack-cooling", p = "fo-cooling-rack",
    items = { { "fo-heat-sink", 6 }, { "pipe", 10 }, { "electric-engine-unit", 4 }, { "fo-aluminium-plate", 10 }, { "steel-plate", 5 } } },
  { key = "baie-gpu", m = "fo-rack-integrator", r = "fo-rack-gpu", p = "fo-gpu-blade",
    items = { { "fo-motherboard", 1 }, { "processing-unit", 1 }, { "fo-graphics-card", 4 }, { "fo-memory-module", 2 } } },
  { key = "baie-quantique", m = "fo-rack-integrator", r = "fo-rack-quantum", p = "fo-quantum-rack",
    items = { { "fo-quantum-processor", 1 }, { "fo-heat-sink", 2 }, { "steel-plate", 10 } } },
  { key = "groupe-froid", m = "fo-chiller", r = "fo-water-chilling", p = "fo-chilled-water", fluid_out = true, fluids = { { "water", 200 } } },
  { key = "tour", m = "fo-cooling-tower", r = "fo-warm-water-cooling", p = "water", fluid_out = true, fluids = { { "fo-warm-water", 400 } } },
  { key = "bati", m = "assembling-machine-3", r = "fo-data-center-frame", p = "fo-data-center",
    items = { { "steel-plate", 20 }, { "concrete", 20 }, { "pipe", 10 }, { "fo-motherboard", 2 }, { "fo-network-switch", 1 } } },
  { key = "degazage", m = "fo-sintering-furnace", r = "fo-regolith-degassing", p = "fo-degassed-ilmenite",
    items = { { "fo-ilmenite-concentrate", 20 } }, also_fluid = "fo-helium-3" },
  { key = "melange", m = "fo-dilution-fridge", r = "fo-dilution-mix", p = "fo-dilution-mix", fluid_out = true,
    fluids = { { "fo-helium-3", 10 }, { "fo-liquid-nitrogen", 50 } } },
  { key = "etage", m = "fo-dilution-fridge", r = "fo-fridge-dilution-stage", p = "fo-dilution-stage",
    items = { { "fo-cryostat", 1 } }, fluids = { { "fo-helium-3", 40 }, { "fo-liquid-nitrogen", 20 } } },
  { key = "qubits", m = "fo-quantum-lab", r = "fo-qlab-qubit-chip", p = "fo-qubit-chip",
    items = { { "fo-etched-wafer", 2 }, { "fo-superconducting-tape", 4 } } },
  { key = "quantique", m = "fo-quantum-lab", r = "fo-qlab-quantum-processor", p = "fo-quantum-processor",
    items = { { "fo-qubit-chip", 4 }, { "fo-dilution-stage", 1 }, { "fo-logic-die", 2 }, { "fo-sram-die", 4 }, { "fo-motherboard", 1 } } },
  -- v1 CACHÉES : toujours valides dans leurs machines (sauvegardes 0.6.27)
  { key = "v1-gravure", m = "fo-crystal-lithograph", r = "fo-etched-wafer", p = "fo-etched-wafer",
    items = { { "fo-silicon-wafer", 20 }, { "fo-photomask", 2 } }, fluids = { { "fo-photoresist", 50 }, { "sulfuric-acid", 100 } } },
  { key = "v1-logique", m = "fo-cleanroom", r = "fo-logic-die", p = "fo-logic-die", items = { { "fo-etched-wafer", 4 } } },
}
-- Centres de calcul modulaires : baies, recette, fluides, unités/s attendues (règle du plan §2, calculées à la main).
local CENTRES = {
  { key = "dc-cpu", name = "fo-data-center", r = "fo-dc-chilled-water", rate = 280,
    racks = { { "fo-server-blade", 3 }, { "fo-memory-rack", 1 }, { "fo-cooling-rack", 1 }, { "fo-storage-rack", 1 } },
    fluids = { { "fo-chilled-water", 200 } } },
  { key = "dc-gpu", name = "fo-data-center", r = "fo-dc-chilled-water", rate = 400,
    racks = { { "fo-gpu-blade", 1 }, { "fo-memory-rack", 1 }, { "fo-cooling-rack", 2 }, { "fo-storage-rack", 1 }, { "fo-network-rack", 1 } },
    fluids = { { "fo-chilled-water", 200 } } },
  { key = "dc-quantique", name = "fo-data-center-2", r = "fo-dc-dilution", rate = 2000,
    racks = { { "fo-quantum-rack", 2 }, { "fo-server-blade", 2 }, { "fo-memory-rack", 1 }, { "fo-cooling-rack", 2 },
              { "fo-storage-rack", 3 }, { "fo-network-rack", 2 } },
    fluids = { { "fo-chilled-water", 200 }, { "fo-dilution-mix", 40 } } },
}

local function size_of(name)
  local p = game.entity_prototypes[name]
  local b = p.collision_box
  return math.ceil(b.right_bottom.x - b.left_top.x)
end

local function state() return remote.call("fo-calcul", "state", "player") end

local function place(s, x, name, recipe)
  local side = size_of(name)
  local px, py = x + side / 2, Y0 + (side % 2 == 1 and 0.5 or 0)
  local e = s.create_entity({ name = name, position = { px, py }, force = "player", raise_built = true })
  if e and recipe then e.set_recipe(recipe) end
  return e, px, py, side
end

local function garnish(e, p)
  local inv = e.get_inventory(defines.inventory.assembling_machine_input)
  for _, it in ipairs(p.items or {}) do inv.insert({ name = it[1], count = it[2] }) end
  for _, fl in ipairs(p.fluids or {}) do e.insert_fluid({ name = fl[1], amount = fl[2] }) end
end

local function racks_in(e, c)
  local inv = e.get_module_inventory()
  for _, rk in ipairs(c.racks) do inv.insert({ name = rk[1], count = rk[2] }) end
end

return {
  description = "CALCUL-V2 : une machine par etape (lingot, sciage, insolation, gravure, test, boitier, CMS, fibre, baies, froid, quantique), centres modulaires",
  check_tick = CHECK,
  shots_delay = 400,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    -- 1. Prototypes
    local miss = {}
    for _, n in ipairs(ITEMS) do if not game.item_prototypes[n] then miss[#miss + 1] = n end end
    for _, n in ipairs(FLUIDS) do if not game.fluid_prototypes[n] then miss[#miss + 1] = n end end
    for _, n in ipairs(BUILDINGS) do if not game.entity_prototypes[n] then miss[#miss + 1] = n end end
    for _, n in ipairs(TECHS) do if not game.technology_prototypes[n] then miss[#miss + 1] = n end end
    for _, p in ipairs(POSTES) do if not game.recipe_prototypes[p.r] then miss[#miss + 1] = p.r end end
    ctx.check(#miss == 0, "prototypes du lot presents (" .. #ITEMS .. " objets, " .. #FLUIDS .. " fluides, " .. #BUILDINGS
      .. " batiments, " .. #TECHS .. " technologies, " .. #POSTES .. " recettes de poste)", #miss > 0 and table.concat(miss, ", ") or nil)
    local shown = {}
    for _, n in ipairs(HIDDEN) do local r = game.recipe_prototypes[n]; if not (r and r.hidden) then shown[#shown + 1] = n end end
    ctx.check(#shown == 0, #HIDDEN .. " recettes v1 controlees : presentes et cachees", table.concat(shown, ", "))
    local bad = {}
    for _, n in ipairs(TECHS) do
      local t = game.technology_prototypes[n]
      if t then
        for _, ing in ipairs(t.research_unit_ingredients) do if ing.name:find("^fo%-") then bad[#bad + 1] = n .. ":" .. ing.name end end
        if #t.research_unit_ingredients < 6 then bad[#bad + 1] = n .. ":" .. #t.research_unit_ingredients .. " packs" end
        for pn in pairs(t.prerequisites) do if not game.technology_prototypes[pn] then bad[#bad + 1] = n .. "<-" .. pn end end
      end
    end
    ctx.check(#bad == 0, "technologies : packs vanilla (6 au moins), prerequis existants", #bad > 0 and table.concat(bad, ", ") or nil)
    -- 2. Recherche par script
    local f = game.forces.player
    local closed, n = {}, 0
    for _, tn in ipairs(TECHS) do
      f.technologies[tn].researched = true
      for _, eff in ipairs(game.technology_prototypes[tn].effects) do
        if eff.type == "unlock-recipe" then
          n = n + 1
          if not (f.recipes[eff.recipe] and f.recipes[eff.recipe].enabled) then closed[#closed + 1] = eff.recipe end
        end
      end
    end
    ctx.check(#closed == 0 and n >= 69, #TECHS .. " technologies : " .. n .. " recettes ouvertes", #closed > 0 and table.concat(closed, ", ") or nil)
    f.technologies["research-speed-1"].researched = true
    st.base = f.laboratory_speed_modifier
    st.rs2 = 0
    for _, eff in ipairs(game.technology_prototypes["research-speed-2"].effects) do
      if eff.type == "laboratory-speed" then st.rs2 = st.rs2 + eff.modifier end
    end

    -- 3. Postes et centres
    ctx.prepare_area(X0 - 6, Y0 - 10, X0 + 240, Y0 + 12, "refined-concrete")
    for _, e in ipairs(s.find_entities_filtered({ area = { { X0 - 120, Y0 - 120 }, { X0 + 360, Y0 + 120 } }, force = "enemy" })) do e.destroy() end
    ctx.power(X0 + 40, Y0 + 9)
    ctx.power(X0 + 160, Y0 + 9)
    st.postes, st.centres = {}, {}
    local x = X0
    local placed, fails = 0, {}
    for i, p in ipairs(POSTES) do
      local e, px, py, side = place(s, x, p.m, p.r)
      if e then garnish(e, p); placed = placed + 1 else fails[#fails + 1] = p.key end
      st.postes[i] = { key = p.key, e = e, x = px, y = py, side = side }
      x = x + side + 2
    end
    for i, c in ipairs(CENTRES) do
      local e, px, py, side = place(s, x, c.name, c.r)
      if e then
        racks_in(e, c)
        for _, fl in ipairs(c.fluids) do e.insert_fluid({ name = fl[1], amount = fl[2] }) end
        placed = placed + 1
      else
        fails[#fails + 1] = c.key
      end
      st.centres[i] = { key = c.key, e = e, x = px, y = py, side = side }
      x = x + side + 2
    end
    st.chest = s.create_entity({ name = "steel-chest", position = { x + 2, Y0 + 6 }, force = "player" })
    st.x1 = x
    ctx.check(placed == #POSTES + #CENTRES, placed .. " postes et centres poses, recette posee", #fails > 0 and table.concat(fails, ", ") or nil)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    -- Fluides : regarnir toutes les 60 ticks, compter et vider les sorties fluides.
    if e.tick % 60 == 0 and e.tick < CHECK then
      for i, p in ipairs(POSTES) do
        local m = st.postes[i] and st.postes[i].e
        if m and m.valid then
          for _, fl in ipairs(p.fluids or {}) do
            if m.get_fluid_count(fl[1]) < fl[2] then m.insert_fluid({ name = fl[1], amount = fl[2] }) end
          end
          local outf = p.fluid_out and p.p or p.also_fluid
          if outf then
            local c = m.get_fluid_count(outf)
            -- (groupe froid et tour : l'entrée et la sortie ne partagent pas le fluide, sauf la tour, eau en sortie seulement)
            if c > 0 then
              st.out = st.out or {}
              st.out[p.key] = (st.out[p.key] or 0) + c
              m.remove_fluid({ name = outf, amount = c })
            end
          end
        end
      end
      for i, c in ipairs(CENTRES) do
        local m = st.centres[i] and st.centres[i].e
        if m and m.valid then
          for _, fl in ipairs(c.fluids) do
            if m.get_fluid_count(fl[1]) < fl[2] then m.insert_fluid({ name = fl[1], amount = fl[2] - m.get_fluid_count(fl[1]) }) end
          end
          local w = m.get_fluid_count("fo-warm-water")
          if w > 0 then m.remove_fluid({ name = "fo-warm-water", amount = w }) end
        end
      end
    end
    if e.tick == T_FULL then
      local cs = state()
      st.full = { rate = cs.rate, bonus = cs.bonus, centers = cs.centers, mod = game.forces.player.laboratory_speed_modifier }
      ctx.log(string.format("calcul en marche (tick %d) : %.1f unites/s, bonus %.3f, %d centre(s), vitesse de recherche %.3f (base %.3f)",
        e.tick, cs.rate, cs.bonus, cs.centers, st.full.mod, st.base))
    elseif e.tick == T_TECH then
      game.forces.player.technologies["research-speed-2"].researched = true
    elseif e.tick == T_STOP then
      -- baies retirées, rangées dans un coffre
      for _, c in ipairs(st.centres) do
        if c.e and c.e.valid then
          local inv = c.e.get_module_inventory()
          for n, k in pairs(inv.get_contents()) do st.chest.insert({ name = n, count = k }) end
          inv.clear()
        end
      end
    elseif e.tick == T_STOPPED then
      local cs = state()
      st.stopped = { rate = cs.rate, bonus = cs.bonus, mod = game.forces.player.laboratory_speed_modifier }
      ctx.log(string.format("baies retirees (tick %d) : %.1f unites/s, vitesse de recherche %.6f", e.tick, cs.rate, st.stopped.mod))
    elseif e.tick == T_RESTART then
      for i, c in ipairs(CENTRES) do
        local m = st.centres[i].e
        if m and m.valid then
          for _, rk in ipairs(c.racks) do
            local got = st.chest.remove_item({ name = rk[1], count = rk[2] })
            m.get_module_inventory().insert({ name = rk[1], count = got })
          end
        end
      end
    elseif e.tick == T_BACK then
      local cs = state()
      st.back = { rate = cs.rate, mod = game.forces.player.laboratory_speed_modifier }
      ctx.log(string.format("baies remises (tick %d) : %.1f unites/s", e.tick, cs.rate))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local ok, ko = 0, {}
    for i, p in ipairs(POSTES) do
      local m = st.postes[i] and st.postes[i].e
      local got = 0
      if m and m.valid then
        if p.fluid_out then
          got = (st.out and st.out[p.key] or 0) + m.get_fluid_count(p.p)
        else
          got = m.get_inventory(defines.inventory.assembling_machine_output).get_item_count(p.p)
        end
      end
      local fin = m and m.valid and m.products_finished or 0
      if got > 0 and fin > 0 then ok = ok + 1 else ko[#ko + 1] = p.key .. "(" .. fin .. " fab., " .. got .. " " .. p.p .. ")" end
      ctx.log(string.format("poste %s : %s dans %s, %d fabrication(s), %s %s", p.key, p.r, p.m, fin, tostring(got), p.p))
    end
    ctx.check(ok == #POSTES, "chaque etape a fabrique son produit dans sa machine", ok .. " / " .. #POSTES .. (#ko > 0 and (" ; " .. table.concat(ko, ", ")) or ""))
    -- 4. Le calcul
    local want = 0
    for _, c in ipairs(CENTRES) do want = want + c.rate end
    local full = st.full or { rate = -1, bonus = -1, mod = -1, centers = -1 }
    ctx.check(math.abs(full.rate - want) <= 0.02 * want and full.centers == #CENTRES,
      string.format("calcul en marche : %d unites/s attendues", want), string.format("%.1f lues, %d centre(s)", full.rate, full.centers))
    ctx.check(math.abs(full.mod - (st.base + full.bonus)) < 1e-6 and full.bonus > 0,
      "vitesse de recherche = base des technologies + bonus du calcul", string.format("%.4f = %.4f + %.4f", full.mod, st.base, full.bonus))
    local sp = st.stopped or { rate = -1, mod = -1 }
    local base2 = st.base + (st.rs2 or 0)
    ctx.check(st.base > 0 and (st.rs2 or 0) > 0 and sp.rate == 0 and math.abs(sp.mod - base2) < 1e-9,
      "baies retirees : 0 unite/s, vitesse revenue exactement a la base des technologies, recherche faite en marche comprise (non stockable)",
      string.format("%.1f, %.6f contre %.6f", sp.rate, sp.mod, base2))
    local bk = st.back or { rate = -1 }
    ctx.check(math.abs(bk.rate - want) <= 0.02 * want, "baies remises : le calcul revient", string.format("%.1f", bk.rate))
    local kept, detail = 0, {}
    for i, c in ipairs(CENTRES) do
      local m = st.centres[i] and st.centres[i].e
      local inv = m and m.valid and m.get_module_inventory()
      local all = true
      for _, rk in ipairs(c.racks) do if not inv or inv.get_item_count(rk[1]) ~= rk[2] then all = false end end
      if all then kept = kept + 1 end
      detail[#detail + 1] = c.key .. (all and ":ok" or ":manque")
    end
    ctx.check(kept == #CENTRES, "aucune baie usee : chaque centre a toutes ses baies (capital)", table.concat(detail, ", "))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local x0, x1 = X0 - 2, st.x1 or (X0 + 200)
    local third = math.ceil((x1 - x0) / 3)
    for k = 0, 2 do
      local cx = x0 + third / 2 + k * third
      add(string.format("rangee-%d-z1-jour", k + 1), cx, Y0, 1, 0, { res = { (third + 4) * 32, 12 * 32 }, info = false, aa = true })
    end
    for _, c in ipairs(st.centres or {}) do
      add("centre-" .. c.key .. "-z2-jour", c.x, c.y, 2, 0, { res = { (c.side + 6) * 64, (c.side + 6) * 64 }, info = true, aa = true })
    end
  end,
}
