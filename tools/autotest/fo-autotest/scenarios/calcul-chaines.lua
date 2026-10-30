--[[
  Scénario GREFFÉ « calcul-chaines » (lot CALCUL, 30/10) : la chaîne du calcul en moteur réel (shared/content/compute.lua,
  prototypes/compute.lua, script/compute/compute.lua).

  Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui calcul -- 2500 calcul-chaines <source>
  Images    : même commande avec --captures --visuel="--no-atlas-cache"

  1. Prototypes du lot présents (objets, fluides, 2 bâtiments, recettes, 5 technologies, packs vanilla, prérequis réels) ;
     le centre de calcul : 4 × 4, 10 MW, aucun emplacement de module.
  2. Les 5 technologies, recherchées par script, ouvrent leurs recettes.
  3. Chaque étape dans SA machine, garnie par script : au contrôle, chaque poste a fini au moins une fabrication et son
     produit est dans sa sortie (fluide : compté à la sortie).
  4. Le CALCUL : 3 centres (classique, accéléré, quantique) en marche → l'interface « fo-calcul » lit 2 500 unités/s
     (± 2 %) et la vitesse de recherche de la force = base des technologies + le bonus plafonné ; centres arrêtés
     (active = false) → 0 unité/s et la vitesse revient EXACTEMENT à la base (calcul non stockable) ; relancés → le calcul
     revient ; chaque centre a usé sa pièce (baie, baie d'accélérateurs, processeur quantique).
]]

local X0, Y0 = 4200, 3000
local CHECK = 2400
local T_FULL, T_TECH, T_STOP, T_STOPPED, T_RESTART, T_BACK = 600, 900, 1200, 1330, 1400, 1630

local TECHS = { "fo-chip-foundry", "fo-data-centers", "fo-gpu-computing", "fo-regolith-degassing", "fo-quantum-computing" }
local ITEMS = { "fo-photomask", "fo-etched-wafer", "fo-crystal-laser", "fo-logic-die", "fo-dram-die", "fo-sram-die", "fo-heat-sink",
                "fo-memory-module", "fo-motherboard", "fo-server-blade", "fo-graphics-card", "fo-gpu-blade", "fo-degassed-ilmenite",
                "fo-qubit-chip", "fo-dilution-stage", "fo-quantum-processor", "fo-crystal-lithograph", "fo-data-center" }
local FLUIDS = { "fo-photoresist", "fo-helium-3" }
local BUILDINGS = { "fo-crystal-lithograph", "fo-data-center" }

-- Postes : machine, recette, produit principal, garniture { objets }, { fluides }, sortie fluide ?
local POSTES = {
  { key = "resine", m = "chemical-plant", r = "fo-photoresist", p = "fo-photoresist", fluid_out = true,
    items = { { "sulfur", 10 } }, fluids = { { "fo-epoxy-resin", 200 }, { "light-oil", 100 } } },
  { key = "masque", m = "fo-cleanroom", r = "fo-photomask", p = "fo-photomask",
    items = { { "fo-glass", 4 }, { "fo-tungsten-plate", 2 }, { "advanced-circuit", 2 } } },
  { key = "laser", m = "assembling-machine-3", r = "fo-crystal-laser", p = "fo-crystal-laser",
    items = { { "fo-cut-crystal", 2 }, { "fo-resonance-lens", 4 }, { "fo-coil", 4 }, { "fo-aluminium-plate", 2 } } },
  { key = "gravure", m = "fo-crystal-lithograph", r = "fo-etched-wafer", p = "fo-etched-wafer",
    items = { { "fo-silicon-wafer", 20 }, { "fo-photomask", 2 } }, fluids = { { "fo-photoresist", 50 }, { "sulfuric-acid", 100 } } },
  { key = "logique", m = "fo-cleanroom", r = "fo-logic-die", p = "fo-logic-die", items = { { "fo-etched-wafer", 4 } } },
  { key = "dram", m = "fo-cleanroom", r = "fo-dram-die", p = "fo-dram-die", items = { { "fo-etched-wafer", 4 } } },
  { key = "sram", m = "fo-cleanroom", r = "fo-sram-die", p = "fo-sram-die", items = { { "fo-etched-wafer", 4 } } },
  { key = "radiateur", m = "assembling-machine-3", r = "fo-heat-sink", p = "fo-heat-sink",
    items = { { "fo-aluminium-plate", 4 }, { "copper-plate", 2 } } },
  { key = "processeur", m = "fo-cleanroom", r = "fo-chip-processor", p = "processing-unit",
    items = { { "fo-logic-die", 2 }, { "fo-sram-die", 4 }, { "fo-printed-circuit-board", 2 }, { "fo-heat-sink", 2 },
              { "electronic-circuit", 24 }, { "advanced-circuit", 4 } } },
  { key = "memoire", m = "fo-cleanroom", r = "fo-memory-module", p = "fo-memory-module",
    items = { { "fo-dram-die", 16 }, { "fo-printed-circuit-board", 2 }, { "fo-tin-plate", 2 } } },
  { key = "carte-mere", m = "fo-circuit-printer", r = "fo-motherboard", p = "fo-motherboard",
    items = { { "fo-printed-circuit-board", 4 }, { "fo-crystal-oscillator", 2 }, { "advanced-circuit", 4 }, { "copper-cable", 8 } } },
  { key = "baie", m = "assembling-machine-3", r = "fo-server-blade", p = "fo-server-blade",
    items = { { "fo-motherboard", 1 }, { "processing-unit", 2 }, { "fo-memory-module", 4 }, { "fo-heat-sink", 2 }, { "steel-plate", 5 } } },
  { key = "centre", m = "assembling-machine-3", r = "fo-data-center", p = "fo-data-center",
    items = { { "fo-server-blade", 4 }, { "steel-plate", 20 }, { "concrete", 20 }, { "pipe", 10 } } },
  { key = "carte-graphique", m = "fo-cleanroom", r = "fo-graphics-card", p = "fo-graphics-card",
    items = { { "fo-logic-die", 4 }, { "fo-dram-die", 8 }, { "fo-printed-circuit-board", 1 }, { "fo-heat-sink", 2 }, { "fo-titanium-plate", 1 } } },
  { key = "baie-gpu", m = "assembling-machine-3", r = "fo-gpu-blade", p = "fo-gpu-blade",
    items = { { "fo-motherboard", 1 }, { "processing-unit", 1 }, { "fo-graphics-card", 4 }, { "fo-memory-module", 2 } } },
  { key = "degazage", m = "fo-sintering-furnace", r = "fo-regolith-degassing", p = "fo-degassed-ilmenite",
    items = { { "fo-ilmenite-concentrate", 20 } }, also_fluid = "fo-helium-3" },
  { key = "ilmenite-degazee", m = "fo-arc-furnace", r = "fo-degassed-ilmenite-smelting", p = "iron-plate",
    items = { { "fo-degassed-ilmenite", 4 }, { "fo-coke", 4 } } },
  { key = "qubits", m = "fo-crystal-lithograph", r = "fo-qubit-chip", p = "fo-qubit-chip",
    items = { { "fo-etched-wafer", 2 }, { "fo-superconducting-tape", 4 } } },
  { key = "dilution", m = "fo-cryogenic-unit", r = "fo-dilution-stage", p = "fo-dilution-stage",
    items = { { "fo-cryostat", 1 } }, fluids = { { "fo-helium-3", 40 }, { "fo-liquid-nitrogen", 20 } } },
  { key = "quantique", m = "fo-cleanroom", r = "fo-quantum-processor", p = "fo-quantum-processor",
    items = { { "fo-qubit-chip", 4 }, { "fo-dilution-stage", 1 }, { "fo-logic-die", 2 }, { "fo-sram-die", 4 }, { "fo-motherboard", 1 } } },
}
-- Centres de calcul : recette, pièce usée, unités/s attendues.
local CENTRES = {
  { key = "dc-classique", r = "fo-compute-classic", part = "fo-server-blade", n = 2, fluids = { { "water", 3000 } }, rate = 100 },
  { key = "dc-accelere", r = "fo-compute-accelerated", part = "fo-gpu-blade", n = 2, fluids = { { "water", 3000 } }, rate = 400 },
  { key = "dc-quantique", r = "fo-compute-quantum", part = "fo-quantum-processor", n = 2,
    fluids = { { "water", 6000 }, { "fo-helium-3", 3000 } }, rate = 2000 },
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

return {
  description = "CALCUL : puces, processeur, memoire, carte mere, baies, carte graphique, processeur quantique, centre de calcul et calcul par script",
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
    for _, c in ipairs(CENTRES) do if not game.recipe_prototypes[c.r] then miss[#miss + 1] = c.r end end
    ctx.check(#miss == 0, "prototypes du lot presents (" .. #ITEMS .. " objets, " .. #FLUIDS .. " fluides, " .. #TECHS
      .. " technologies, " .. (#POSTES + #CENTRES) .. " recettes)", #miss > 0 and table.concat(miss, ", ") or nil)
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
    local dc = game.entity_prototypes["fo-data-center"]
    ctx.check(dc and size_of("fo-data-center") == 4 and math.abs(dc.max_energy_usage * 60 - 10e6) < 1e3
      and (dc.module_inventory_size or 0) == 0 and #dc.fluidbox_prototypes == 2,
      "centre de calcul : 4 x 4, 10 MW, 0 module, 2 entrees de fluide",
      dc and (size_of("fo-data-center") .. ", " .. (dc.max_energy_usage * 60) .. " W, " .. tostring(dc.module_inventory_size)
        .. " modules, " .. #dc.fluidbox_prototypes .. " boites") or "absent")
    for _, c in ipairs(CENTRES) do
      local r = game.recipe_prototypes[c.r]
      if r then ctx.check(#r.products == 0, c.r .. " : aucun produit (calcul non stockable)", #r.products .. " produit(s)") end
    end
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
    ctx.check(#closed == 0 and n >= 24, #TECHS .. " technologies : " .. n .. " recettes ouvertes", #closed > 0 and table.concat(closed, ", ") or nil)
    -- Base des technologies NON nulle : vitesse de recherche 1 (vanilla) ; vitesse de recherche 2 sera recherchée EN
    -- MARCHE (tick T_TECH), entre deux fenêtres : le piège du champ partagé avec les technologies (plan CALCUL §3).
    f.technologies["research-speed-1"].researched = true
    st.base = f.laboratory_speed_modifier
    st.rs2 = 0
    for _, eff in ipairs(game.technology_prototypes["research-speed-2"].effects) do
      if eff.type == "laboratory-speed" then st.rs2 = st.rs2 + eff.modifier end
    end

    -- 3. Postes et centres
    ctx.prepare_area(X0 - 6, Y0 - 10, X0 + 175, Y0 + 12, "refined-concrete")
    for _, e in ipairs(s.find_entities_filtered({ area = { { X0 - 120, Y0 - 120 }, { X0 + 300, Y0 + 120 } }, force = "enemy" })) do e.destroy() end
    ctx.power(X0 + 40, Y0 + 9)
    ctx.power(X0 + 130, Y0 + 9)
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
      local e, px, py, side = place(s, x, "fo-data-center", c.r)
      if e then
        local inv = e.get_inventory(defines.inventory.assembling_machine_input)
        inv.insert({ name = c.part, count = c.n })
        for _, fl in ipairs(c.fluids) do e.insert_fluid({ name = fl[1], amount = fl[2] }) end
        placed = placed + 1
      else
        fails[#fails + 1] = c.key
      end
      st.centres[i] = { key = c.key, e = e, x = px, y = py, side = side }
      x = x + side + 2
    end
    st.x1 = x
    ctx.check(placed == #POSTES + #CENTRES, placed .. " postes et centres poses, recette posee", #fails > 0 and table.concat(fails, ", ") or nil)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    -- Fluides : regarnir toutes les 120 ticks, compter et vider les sorties fluides.
    if e.tick % 120 == 0 and e.tick < CHECK then
      for i, p in ipairs(POSTES) do
        local m = st.postes[i] and st.postes[i].e
        if m and m.valid then
          for _, fl in ipairs(p.fluids or {}) do
            if m.get_fluid_count(fl[1]) < fl[2] then m.insert_fluid({ name = fl[1], amount = fl[2] }) end
          end
          local outf = p.fluid_out and p.p or p.also_fluid
          if outf then
            local c = m.get_fluid_count(outf)
            if c > 0 then
              st.out = st.out or {}
              st.out[p.key] = (st.out[p.key] or 0) + c
              m.remove_fluid({ name = outf, amount = c })
            end
          end
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
      local cs = state()
      st.tech = { mod = game.forces.player.laboratory_speed_modifier, bonus = cs.bonus }
    elseif e.tick == T_STOP then
      for _, c in ipairs(st.centres) do if c.e and c.e.valid then c.e.active = false end end
    elseif e.tick == T_STOPPED then
      local cs = state()
      st.stopped = { rate = cs.rate, bonus = cs.bonus, mod = game.forces.player.laboratory_speed_modifier }
      ctx.log(string.format("centres arretes (tick %d) : %.1f unites/s, vitesse de recherche %.6f", e.tick, cs.rate, st.stopped.mod))
    elseif e.tick == T_RESTART then
      for _, c in ipairs(st.centres) do if c.e and c.e.valid then c.e.active = true end end
    elseif e.tick == T_BACK then
      local cs = state()
      st.back = { rate = cs.rate, mod = game.forces.player.laboratory_speed_modifier }
      ctx.log(string.format("centres relances (tick %d) : %.1f unites/s", e.tick, cs.rate))
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
      ctx.log(string.format("poste %s : %s, %d fabrication(s), %s %s", p.key, p.r, fin, tostring(got), p.p))
    end
    ctx.check(ok == #POSTES, "chaque etape a fabrique son produit", ok .. " / " .. #POSTES .. (#ko > 0 and (" ; " .. table.concat(ko, ", ")) or ""))
    local he3 = st.out and st.out["degazage"] or 0
    ctx.check(he3 > 0, "degazage du regolithe : helium-3 rendu", string.format("%.2f", he3))
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
      "centres arretes : 0 unite/s, vitesse revenue exactement a la base des technologies, recherche faite en marche comprise (non stockable)",
      string.format("%.1f, %.6f contre %.6f (vitesse 1 : %.3f, vitesse 2 recherchee au tick %d : +%.3f)", sp.rate, sp.mod, base2, st.base, T_TECH, st.rs2 or 0))
    local bk = st.back or { rate = -1 }
    ctx.check(math.abs(bk.rate - want) <= 0.02 * want, "centres relances : le calcul revient", string.format("%.1f", bk.rate))
    local used, detail = 0, {}
    for i, c in ipairs(CENTRES) do
      local e = st.centres[i] and st.centres[i].e
      local left = e and e.valid and e.get_inventory(defines.inventory.assembling_machine_input).get_item_count(c.part) or -1
      if left == c.n - 1 then used = used + 1 end
      detail[#detail + 1] = c.key .. ":" .. left .. "/" .. c.n
    end
    ctx.check(used == #CENTRES, "chaque centre a use une piece (baie, baie GPU, processeur quantique)", table.concat(detail, ", "))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local x0, x1 = X0 - 2, st.x1 or (X0 + 160)
    local half = math.ceil((x1 - x0) / 2)
    for k = 0, 1 do
      local cx = x0 + half / 2 + k * half
      add(string.format("rangee-%d-z1-jour", k + 1), cx, Y0, 1, 0, { res = { (half + 4) * 32, 12 * 32 }, info = false, aa = true })
    end
    for _, c in ipairs(st.centres or {}) do
      add("centre-" .. c.key .. "-z2-jour", c.x, c.y, 2, 0, { res = { (c.side + 6) * 64, (c.side + 6) * 64 }, info = true, aa = true })
    end
    for _, pp in ipairs(st.postes or {}) do
      if pp.key == "gravure" then
        add("lithographe-z2-jour", pp.x, pp.y, 2, 0, { res = { (pp.side + 6) * 64, (pp.side + 6) * 64 }, info = true, aa = true })
      end
    end
  end,
}
