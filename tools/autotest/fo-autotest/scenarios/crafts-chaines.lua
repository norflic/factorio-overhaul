--[[
  Scénario GREFFÉ « crafts-chaines » (lot AMELIO-CRAFTS, nuit du 29 au 30/10) : les chaînes des âges 2, 3, 6 et 11 en
  moteur réel (shared/content/crafts.lua, prototypes/crafts.lua).

  Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui amelio-crafts -- 1300 crafts-chaines <source>
  Images    : même commande avec --captures

  1. Prototypes présents : 8 objets, 3 bâtiments, 15 recettes du lot (12 de X0, 3 hors X0), 8 technologies, avec les
     packs vanilla de leur âge et des prérequis qui existent.
  2. Les 8 technologies, recherchées par script, ouvrent leurs 25 recettes (bâtiments compris).
  3. Chaque recette de procédé dans SA machine (haut fourneau, concasseur, four à arc, bobineuse, assembleur 3, usine
     chimique, four à coke), garnie par script (objets, combustible, fluides) : au contrôle (tick 1 200), chaque machine
     a fini au moins une fabrication et son produit principal est dans sa sortie (ou un fluide dans sa boîte de sortie).
  4. Productivité : le module vanilla de productivité 3 admet les recettes « prod » de X0 du lot (graphite, bobine...),
     jamais une recette hors X0.
  5. Captures (session avec images) : la rangée de machines, de jour et de nuit (visuels PROVISOIRES).
]]

local X0, Y0 = 3800, 3000
local CHECK = 1200

local TECHS = { "fo-coking", "fo-blast-furnace", "fo-crushing", "fo-cement-concrete", "fo-arc-smelting", "fo-electrical-steel",
                "fo-titanium-alloys", "fo-brine-byproducts", "fo-glassworks", "fo-flaring", "fo-steam-cracking" }
local ITEMS = { "fo-slag", "fo-cement", "fo-sand", "fo-graphite", "fo-magnetic-steel", "fo-enameled-wire", "fo-coil", "fo-titanium-composite",
                "fo-glass", "fo-manometer" }
local BUILDINGS = { "fo-blast-furnace", "fo-crusher", "fo-coil-winder", "fo-flare-stack", "fo-steam-cracker" }
local PROD = { "fo-glass", "fo-manometer", "fo-polyethylene", "fo-graphite", "fo-magnetic-steel", "fo-enameled-wire", "fo-coil", "fo-titanium-composite", "fo-titanium-lds" }
local NOT_PROD = { "fo-flare-hydrogen", "fo-steam-cracking", "fo-slag-landfill", "fo-sorel-concrete", "fo-hydrocracking", "fo-arc-steel", "fo-blast-furnace-steel" }

-- Postes : machine, recette, produit principal (type), garniture { objets }, { fluides }, combustible ?
local POSTES = {
  { key = "coke", m = "fo-coke-oven", r = "fo-coke", p = "fo-coke", items = { { "coal", 30 } }, fuel = true },
  { key = "acier", m = "fo-blast-furnace", r = "fo-blast-furnace-steel", p = "steel-plate", items = { { "iron-plate", 40 }, { "fo-coke", 10 } }, fuel = true },
  { key = "sable", m = "fo-crusher", r = "fo-sand", p = "fo-sand", items = { { "stone", 20 } }, fuel = true },
  { key = "ciment", m = "fo-crusher", r = "fo-slag-cement", p = "fo-cement", items = { { "fo-slag", 20 }, { "stone", 10 } }, fuel = true },
  { key = "beton", m = "assembling-machine-3", r = "fo-cement-concrete", p = "concrete", items = { { "fo-cement", 8 }, { "fo-sand", 12 } }, fluids = { { "water", 200 } } },
  { key = "verre", m = "stone-furnace", furnace = true, r = "fo-glass", p = "fo-glass", items = { { "fo-sand", 20 } }, fuel = true },
  { key = "manometre", m = "assembling-machine-3", r = "fo-manometer", p = "fo-manometer",
    items = { { "fo-glass", 2 }, { "iron-gear-wheel", 2 }, { "pipe", 2 } } },
  { key = "vapocraquage", m = "fo-steam-cracker", r = "fo-steam-cracking", p = "fo-ethylene", fluid_out = true,
    fluids = { { "petroleum-gas", 200 }, { "steam", 200 } } },
  { key = "polyethylene", m = "chemical-plant", r = "fo-polyethylene", p = "plastic-bar", items = { { "coal", 5 } },
    fluids = { { "fo-ethylene", 200 } } },
  { key = "torchere", m = "fo-flare-stack", r = "fo-flare-hydrogen", p = nil, fluids = { { "fo-hydrogen", 300 } } },
  { key = "graphite", m = "fo-arc-furnace", r = "fo-graphite", p = "fo-graphite", items = { { "fo-coke", 20 } } },
  { key = "acier-arc", m = "fo-arc-furnace", r = "fo-arc-steel", p = "steel-plate", items = { { "iron-plate", 12 }, { "fo-graphite", 4 } } },
  { key = "tole", m = "fo-arc-furnace", r = "fo-magnetic-steel", p = "fo-magnetic-steel", items = { { "steel-plate", 8 }, { "fo-sand", 4 } } },
  { key = "fil", m = "fo-coil-winder", r = "fo-enameled-wire", p = "fo-enameled-wire", items = { { "copper-cable", 8 }, { "plastic-bar", 4 } } },
  { key = "bobine", m = "fo-coil-winder", r = "fo-coil", p = "fo-coil", items = { { "fo-enameled-wire", 8 }, { "fo-magnetic-steel", 4 } } },
  { key = "moteur", m = "assembling-machine-3", r = "fo-wound-electric-engine", p = "electric-engine-unit",
    items = { { "engine-unit", 2 }, { "fo-coil", 2 }, { "electronic-circuit", 4 } } },
  { key = "composite", m = "assembling-machine-3", r = "fo-titanium-composite", p = "fo-titanium-composite",
    items = { { "fo-titanium-plate", 2 }, { "plastic-bar", 4 }, { "fo-graphite", 2 } } },
  { key = "lds", m = "assembling-machine-3", r = "fo-titanium-lds", p = "low-density-structure", items = { { "fo-titanium-composite", 2 }, { "copper-plate", 8 } } },
  { key = "remblai", m = "assembling-machine-3", r = "fo-slag-landfill", p = "landfill", items = { { "fo-slag", 40 } } },
  { key = "sorel", m = "chemical-plant", r = "fo-sorel-concrete", p = "refined-concrete",
    items = { { "fo-magnesium-chloride", 4 }, { "fo-caustic-soda", 4 }, { "concrete", 20 } }, fluids = { { "water", 200 } } },
  { key = "hydro", m = "chemical-plant", r = "fo-hydrocracking", p = "light-oil", fluid_out = true,
    fluids = { { "heavy-oil", 200 }, { "fo-hydrogen", 200 } } },
}

local function size_of(name)
  local p = game.entity_prototypes[name]
  local b = p.collision_box
  return math.ceil(b.right_bottom.x - b.left_top.x)
end

return {
  description = "AMELIO-CRAFTS : chaines des ages 2, 3, 6 et 11 (haut fourneau, concassage, arc, bobinage, composite, debouches)",
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
    for _, n in ipairs(BUILDINGS) do if not game.entity_prototypes[n] then miss[#miss + 1] = n end end
    for _, n in ipairs(TECHS) do if not game.technology_prototypes[n] then miss[#miss + 1] = n end end
    for _, p in ipairs(POSTES) do if not game.recipe_prototypes[p.r] then miss[#miss + 1] = p.r end end
    ctx.check(#miss == 0, "prototypes du lot presents (10 objets, 5 batiments, 11 technologies, 21 recettes de poste)",
      #miss > 0 and table.concat(miss, ", ") or nil)
    -- Packs et prérequis
    local bad = {}
    for _, n in ipairs(TECHS) do
      local t = game.technology_prototypes[n]
      if t then
        for _, ing in ipairs(t.research_unit_ingredients) do
          if ing.name:find("^fo%-") then bad[#bad + 1] = n .. ":" .. ing.name end
        end
        for pn in pairs(t.prerequisites) do
          if not game.technology_prototypes[pn] then bad[#bad + 1] = n .. "<-" .. pn end
        end
      end
    end
    local t2 = game.technology_prototypes["fo-coking"]
    ctx.check(#bad == 0 and t2 and #t2.research_unit_ingredients == 2, "technologies : packs vanilla (age 2 : rouge et vert), prerequis existants",
      #bad > 0 and table.concat(bad, ", ") or (t2 and (#t2.research_unit_ingredients .. " packs, " .. t2.research_unit_count .. " unites")))
    -- 2. Recherche par script
    local f = game.forces.player
    f.technologies["fo-titanium-processing"].researched = true
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
    ctx.check(#closed == 0 and n >= 32, #TECHS .. " technologies : " .. n .. " recettes ouvertes", #closed > 0 and table.concat(closed, ", ") or nil)
    -- 4. Productivité
    local lim = game.item_prototypes["productivity-module-3"] and game.item_prototypes["productivity-module-3"].limitations or {}
    local set = {}
    for _, r in ipairs(lim) do set[r] = true end
    local wrong = {}
    for _, r in ipairs(PROD) do if not set[r] then wrong[#wrong + 1] = "absent:" .. r end end
    for _, r in ipairs(NOT_PROD) do if set[r] then wrong[#wrong + 1] = "admis:" .. r end end
    ctx.check(#wrong == 0, "productivite : recettes prod de X0 admises, hors X0 refusees", #wrong > 0 and table.concat(wrong, ", ") or nil)

    -- 3. Postes
    ctx.prepare_area(X0 - 6, Y0 - 10, X0 + 120, Y0 + 12, "refined-concrete")
    for _, e in ipairs(s.find_entities_filtered({ area = { { X0 - 120, Y0 - 120 }, { X0 + 240, Y0 + 120 } }, force = "enemy" })) do e.destroy() end
    ctx.power(X0 + 56, Y0 + 8)
    st.postes = {}
    local x = X0
    local placed, fails = 0, {}
    for i, p in ipairs(POSTES) do
      local side = size_of(p.m)
      local px, py = x + side / 2, Y0 + (side % 2 == 1 and 0.5 or 0)
      local e = s.create_entity({ name = p.m, position = { px, py }, force = "player", raise_built = true })
      if e then
        if not p.furnace then e.set_recipe(p.r) end
        if p.fuel then e.get_fuel_inventory().insert({ name = "coal", count = 50 }) end
        local inv = e.get_inventory(p.furnace and defines.inventory.furnace_source or defines.inventory.assembling_machine_input)
        for _, it in ipairs(p.items or {}) do inv.insert({ name = it[1], count = it[2] }) end
        for _, fl in ipairs(p.fluids or {}) do e.insert_fluid({ name = fl[1], amount = fl[2] }) end
        placed = placed + 1
      else
        fails[#fails + 1] = p.key
      end
      st.postes[i] = { key = p.key, e = e, x = px, y = py, side = side }
      x = x + side + 2
    end
    st.x1 = x
    ctx.check(placed == #POSTES, placed .. " postes poses, recette posee", #fails > 0 and table.concat(fails, ", ") or nil)
  end,

  tick = function(ctx, e)
    -- Les fluides s'épuisent vite (boîtes de 1 000 au plus) : regarnir toutes les 120 ticks.
    if e.tick % 120 ~= 0 or e.tick >= CHECK then return end
    local st = ctx.state()
    for i, p in ipairs(POSTES) do
      local m = st.postes[i] and st.postes[i].e
      if m and m.valid then
        for _, fl in ipairs(p.fluids or {}) do
          if m.get_fluid_count(fl[1]) < fl[2] then m.insert_fluid({ name = fl[1], amount = fl[2] }) end
        end
        if p.fluid_out then
          -- la sortie d'huile légère pleine bloquerait la machine : compter puis vider
          local c = m.get_fluid_count(p.p)
          if c > 0 then
            st.out = st.out or {}
            st.out[p.key] = (st.out[p.key] or 0) + c
            m.remove_fluid({ name = p.p, amount = c })
          end
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local ok, ko = 0, {}
    for i, p in ipairs(POSTES) do
      local m = st.postes[i] and st.postes[i].e
      local got = 0
      if m and m.valid then
        if not p.p then
          got = m.products_finished
        elseif p.fluid_out then
          got = (st.out and st.out[p.key] or 0) + m.get_fluid_count(p.p)
        elseif p.furnace then
          got = m.get_inventory(defines.inventory.furnace_result).get_item_count(p.p)
        else
          got = m.get_inventory(defines.inventory.assembling_machine_output).get_item_count(p.p)
        end
      end
      local fin = m and m.valid and m.products_finished or 0
      if got > 0 and fin > 0 then ok = ok + 1 else ko[#ko + 1] = p.key .. "(" .. fin .. " fab., " .. got .. " " .. tostring(p.p) .. ")" end
      ctx.log(string.format("poste %s : %s, %d fabrication(s), %s %s", p.key, p.r, fin, tostring(got), tostring(p.p)))
    end
    ctx.check(ok == #POSTES, "chaque poste a fabrique son produit principal", ok .. " / " .. #POSTES ..
      (#ko > 0 and (" ; " .. table.concat(ko, ", ")) or ""))
    -- Le haut fourneau rend du laitier avec l'acier (sous-produit), la boucle laitier -> remblai tourne.
    local bf
    for i, p in ipairs(POSTES) do if p.key == "acier" then bf = st.postes[i].e end end
    local slag = bf and bf.valid and bf.get_inventory(defines.inventory.assembling_machine_output).get_item_count("fo-slag") or 0
    ctx.check(slag > 0, "haut fourneau : laitier rendu avec l'acier", tostring(slag))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local x0, x1 = X0 - 2, st.x1 or (X0 + 100)
    local half = math.ceil((x1 - x0) / 2)
    -- deux moitiés au zoom 1, puis les 3 bâtiments neufs au zoom 2
    for k = 0, 1 do
      local cx = x0 + half / 2 + k * half
      for _, nuit in ipairs({ false, true }) do
        add(string.format("rangee-%d-z1-%s", k + 1, nuit and "nuit" or "jour"), cx, Y0, 1, nuit and 0.5 or 0,
          { res = { (half + 4) * 32, 12 * 32 }, info = false, aa = true })
      end
    end
    for _, key in ipairs({ "acier", "sable", "fil" }) do
      for _, pp in ipairs(st.postes) do
        if pp.key == key then
          add("batiment-" .. key .. "-z2-jour", pp.x, pp.y, 2, 0, { res = { (pp.side + 4) * 64, (pp.side + 4) * 64 }, info = true, aa = true })
        end
      end
    end
  end,
}
