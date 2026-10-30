--[[
  Scénario GREFFÉ « x2-supra » (lot X2, 25/10) : les ressources de l'âge 12 en moteur réel (prototypes, garantie,
  chaîne à transferts PAR SCRIPT, niveau payé en bobines, captures). La petite usine SANS script est « x2-usine ».

  Lancement : & "<racine>\fo-autotest.bat" nopause 2600 x2-supra "<source>"   (contrôle final au tick 2 400)
  Images    : & "<racine>\fo-captures.bat" x2-supra "<source>" puis py -3.9 tools/autotest/x2_lisibilite.py <captures>

  1. Prototypes (noms du scénario X0) : monazite (catégorie basic-solid, minage 2 s, produit fo-monazite-ore), sables
     noirs, objets, fluides, machines ; bobine : pile 100, monnaie de l'âge 12 dans la config ; recettes ouvertes.
  2. Les 2 TACHES DE SABLES NOIRS garanties (fo-monde, posées à on_init) : monazite, sol, distance 400-900, sans arbre.
  3. Une foreuse électrique ET une foreuse à combustible minent la monazite de la tache 1 (catégorie basic-solid).
  4. Chaque recette de la chaîne dans SA machine, ingrédients mis PAR SCRIPT dans la machine (pas de bras) : concentré,
     lessivage, extraction par solvant, distillation de l'air, électrolyse de l'eau, ruban, aimant, cryostat, bobine.
  5. Un NIVEAU DE L'ÂGE 12 payé avec la bobine : force à part, centre 15, mur 22 → 23 (coût : bobines, plus de moteur
     électrique).
  6. Captures : planches de gisements de 9 × 9 aux 8 stades sur les sables noirs (« sables » : fer, MONAZITE, cuivre /
     charbon, pierre, uranium ; « mod » : tungstène, MONAZITE, ilménite / cristal, pierre, cuivre), planche « natif »
     (chacun sur son sol), paires au zoom 2, jour et nuit ; une tache garantie ; les 4 machines (visuel provisoire).
]]

local MONDE = "fo-monde"
local LV = require("__factorio-overhaul__/shared/levels/config")

local X0, Y0 = 3600, 3600
local PAS = 11
local R = 4
local PLANCHES = {
  { nom = "sables", ordre = { "iron-ore", "fo-monazite", "copper-ore", "coal", "stone", "uranium-ore" } },
  { nom = "mod", ordre = { "fo-tungsten-ore", "fo-monazite", "fo-ilmenite", "fo-resonance-crystal", "stone", "copper-ore" } },
  { nom = "natif", ordre = { "iron-ore", "fo-monazite", "copper-ore", "coal", "stone", "uranium-ore" } },
}
local SOL_NATIF = { ["fo-monazite"] = "fo-black-sands" }
local CX, CY = 3600, 3740          -- machines (chaîne par script)
local LX, LY = 3660, 3740          -- force à part : mur en (LX, LY), centre 15 à 20 tuiles à l'est
local T_SITE, T_LEVEL, CHECK = 2, 2200, 2400
local FORCE = "x2-supra"

local function quantite(d)
  local t = math.min(1, d / (R + 0.5))
  return math.max(30, math.floor(20000 * (1 - t) ^ 2.2 + 40))
end

local function centre(planche, i)
  local col, lig = (i - 1) % 3, math.floor((i - 1) / 3)
  return X0 + (col - 1) * PAS, Y0 + planche * 40 + lig * PAS - 5
end

local function poser(s, nom, cx, cy, sol)
  local tiles = {}
  for dx = -R - 1, R + 1 do
    for dy = -R - 1, R + 1 do tiles[#tiles + 1] = { name = sol, position = { cx + dx, cy + dy } } end
  end
  s.set_tiles(tiles) -- les tuiles AVANT les entités (F135)
  local n = 0
  for dx = -R, R do
    for dy = -R, R do
      local d = math.sqrt(dx * dx + dy * dy)
      if d <= R + 0.5 then
        if s.create_entity({ name = nom, position = { cx + dx + 0.5, cy + dy + 0.5 }, amount = quantite(d) }) then n = n + 1 end
      end
    end
  end
  return n
end

local function by_key(list, key)
  for _, d in ipairs(list or {}) do if d.key == key then return d end end
end

local function in_inv(e) return e.get_inventory(defines.inventory.assembling_machine_input) end
local function out_inv(e) return e.get_inventory(defines.inventory.assembling_machine_output) end

-- Recettes de la chaîne : machine, recette, objets et fluides d'entrée remplis par script.
local CHAINE = {
  { k = "conc", machine = "fo-ore-concentrator", recipe = "fo-monazite-concentrate", items = { { "fo-monazite-ore", 32 } } },
  { k = "leach", machine = "chemical-plant", recipe = "fo-monazite-leaching", items = { { "fo-monazite-concentrate", 4 } },
    fluids = { { "sulfuric-acid", 40 } } },
  { k = "extr", machine = "fo-extraction-column", recipe = "fo-solvent-extraction", items = { { "fo-rare-earth-concentrate", 8 } },
    fluids = { { "light-oil", 20 } } },
  { k = "air", machine = "fo-cryogenic-unit", recipe = "fo-air-distillation" },
  { k = "elec", machine = "fo-electrolyzer", recipe = "fo-water-electrolysis", fluids = { { "water", 200 } } },
  { k = "tape", machine = "fo-sintering-furnace", recipe = "fo-superconducting-tape", items = { { "fo-yttrium", 2 }, { "copper-plate", 6 } },
    fluids = { { "fo-oxygen", 40 } } },
  { k = "magnet", machine = "fo-sintering-furnace", recipe = "fo-permanent-magnet", items = { { "fo-neodymium", 2 }, { "iron-plate", 4 } } },
  { k = "cryostat", machine = "assembling-machine-3", recipe = "fo-cryostat",
    items = { { "fo-titanium-plate", 2 }, { "plastic-bar", 4 }, { "processing-unit", 2 } } },
  { k = "coil", machine = "fo-coil-winder", recipe = "fo-superconducting-coil", items = { { "fo-superconducting-tape", 8 }, { "fo-cryostat", 2 } },
    fluids = { { "fo-liquid-nitrogen", 40 } } },
}

return {
  description = "x2-supra : monazite et sables noirs garantis, chaine de la bobine (transferts par script), niveau de l'age 12 paye",
  check_tick = CHECK,
  shots_delay = 300,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    local need = { { "entity", "fo-monazite" }, { "item", "fo-monazite-ore" }, { "item", "fo-superconducting-coil" },
      { "item", "fo-cryostat" }, { "item", "fo-superconducting-tape" }, { "item", "fo-yttrium" }, { "item", "fo-neodymium" },
      { "item", "fo-thorium-oxide" }, { "item", "fo-rare-earth-concentrate" }, { "item", "fo-monazite-concentrate" },
      { "item", "fo-permanent-magnet" }, { "entity", "fo-cryogenic-unit" }, { "entity", "fo-extraction-column" },
      { "entity", "fo-sintering-furnace" }, { "entity", "fo-coil-winder" }, { "fluid", "fo-liquid-nitrogen" },
      { "fluid", "fo-liquid-oxygen" }, { "fluid", "fo-oxygen" }, { "tile", "fo-black-sands" } }
    local miss = {}
    for _, n in ipairs(need) do
      local t = n[1] == "entity" and game.entity_prototypes or n[1] == "item" and game.item_prototypes
        or n[1] == "fluid" and game.fluid_prototypes or game.tile_prototypes
      if not t[n[2]] then miss[#miss + 1] = n[2] end
    end
    ctx.check(#miss == 0, "prototypes de l'age 12 presents (ressource, objets, fluides, machines, sol)", #miss > 0 and table.concat(miss, ", ") or nil)
    local p = game.entity_prototypes["fo-monazite"]
    ctx.check(p and p.resource_category == "basic-solid" and p.mineable_properties.products[1].name == "fo-monazite-ore"
      and p.mineable_properties.mining_time == 2 and not p.infinite_resource,
      "monazite : basic-solid, minage 2 s, produit fo-monazite-ore, gisement fini")
    local ip = game.item_prototypes["fo-superconducting-coil"]
    local m = LV.epoch_materials[12]
    ctx.check(ip and ip.stack_size == 100 and m.item == "fo-superconducting-coil" and not m.provisional and m.value == 60,
      "bobine supraconductrice : pile 100, monnaie de l'age 12 (valeur 60, plus de remplacant)", m.item)
    local lt = game.fluid_prototypes["fo-liquid-nitrogen"]
    ctx.check(lt and lt.default_temperature == -196, "azote liquide : -196 degres (X0)", lt and lt.default_temperature)
    local f = game.forces.player
    f.technologies["fo-cryostat"].researched = true
    if f.technologies["fo-electrical-steel"] then f.technologies["fo-electrical-steel"].researched = true end -- bobineuse (AMELIO-CRAFTS)
    f.technologies["fo-superconductors"].researched = true
    local closed = {}
    for _, r in ipairs({ "fo-monazite-concentrate", "fo-monazite-leaching", "fo-solvent-extraction", "fo-air-distillation",
      "fo-water-electrolysis", "fo-superconducting-tape", "fo-permanent-magnet", "fo-cryostat", "fo-superconducting-coil",
      "fo-cryogenic-unit", "fo-extraction-column", "fo-sintering-furnace", "fo-coil-winder" }) do
      if not (f.recipes[r] and f.recipes[r].enabled) then closed[#closed + 1] = r end
    end
    ctx.check(#closed == 0, "technologies cryostat et supraconducteurs : 13 recettes ouvertes", #closed > 0 and table.concat(closed, ", ") or nil)

    -- Planches de gisements (captures).
    ctx.prepare_area(X0 - 40, Y0 - 30, X0 + 100, Y0 + 170, "grass-1")
    for _, e in ipairs(s.find_entities_filtered({ area = { { X0 - 140, Y0 - 140 }, { X0 + 200, Y0 + 260 } }, force = "enemy" })) do e.destroy() end
    local n_ok = 0
    for pl, def in ipairs(PLANCHES) do
      for i, nom in ipairs(def.ordre) do
        local cx, cy = centre(pl - 1, i)
        local sol = def.nom == "natif" and (SOL_NATIF[nom] or "grass-1") or "fo-black-sands"
        if poser(s, nom, cx, cy, sol) >= 60 then n_ok = n_ok + 1 end
      end
    end
    ctx.check(n_ok == 18, "18 gisements de planche poses (9 x 9, 8 stades)", n_ok)

    -- Chaîne : une machine par recette, ingrédients mis par script.
    st.m = {}
    local placed, bad = 0, {}
    for i, c in ipairs(CHAINE) do
      local x = CX - 32 + (i - 1) * 8 + (c.machine == "fo-coil-winder" and 0 or 0.5)
      local y = CY + (c.machine == "fo-coil-winder" and 0 or 0.5)
      local e = s.create_entity({ name = c.machine, position = { x, y }, force = "player", raise_built = true })
      if e then
        e.set_recipe(c.recipe)
        for _, it in ipairs(c.items or {}) do in_inv(e).insert({ name = it[1], count = it[2] }) end
        for _, fl in ipairs(c.fluids or {}) do e.insert_fluid({ name = fl[1], amount = fl[2] }) end
        st.m[c.k] = e
        if e.get_recipe() and e.get_recipe().name == c.recipe then placed = placed + 1 else bad[#bad + 1] = c.k end
      else
        bad[#bad + 1] = c.k
      end
    end
    ctx.check(placed == #CHAINE, "chaine : 9 machines posees, chacune avec sa recette (ingredients mis par script)",
      #bad > 0 and table.concat(bad, ", ") or nil)
    ctx.power(CX - 8, CY + 6)
    -- Force à part pour le niveau de l'âge 12 : centre 15 et mur au niveau 22.
    local lf = game.forces[FORCE] or game.create_force(FORCE)
    st.cc = s.create_entity({ name = LV.name(LV.by_key.command, 15), position = { LX + 20, LY }, force = lf, raise_built = true })
    st.wall = s.create_entity({ name = LV.name(LV.by_key.wall, 22), position = { LX + 0.5, LY + 0.5 }, force = lf, raise_built = true })
    ctx.check(st.cc and st.wall, "force a part : centre 15 et mur 22 poses")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == T_SITE then
      local specs = ctx.remote(MONDE, "specs")
      local spec = by_key(specs, "monazite")
      local d = by_key(ctx.remote(MONDE, "status").done, "monazite")
      local sites = d and d.sites or {}
      ctx.check(spec and d and d.ok and d.phase == "init" and #sites == 2, "2 taches de sables noirs garanties posees a on_init (fo-monde)",
        #sites > 0 and string.format("(%d, %d) a %.1f ; %s", sites[1].x, sites[1].y, sites[1].dist,
          sites[2] and string.format("(%d, %d) a %.1f", sites[2].x, sites[2].y, sites[2].dist) or "pas de 2e") or "absent")
      if not (spec and #sites == 2) then return end
      st.sites = { { x = sites[1].x, y = sites[1].y }, { x = sites[2].x, y = sites[2].y } }
      local bad, trees, total = {}, 0, 0
      for i, site in ipairs(sites) do
        local c = { site.x + 0.5, site.y + 0.5 }
        local ore = s.find_entities_filtered({ name = "fo-monazite", position = c, radius = spec.core_radius + 1.5 })
        local amt, wrong = 0, 0
        for _, r in ipairs(ore) do
          amt = amt + r.amount
          if s.get_tile(math.floor(r.position.x), math.floor(r.position.y)).name ~= "fo-black-sands" then wrong = wrong + 1 end
        end
        total = total + amt
        if not (#ore == site.entities and amt == site.total and amt >= spec.min_total and wrong == 0
          and site.dist >= spec.dmin and site.dist <= spec.dmax) then
          bad[#bad + 1] = string.format("tache %d : %d entites, %d, hors sol %d, distance %.1f", i, #ore, amt, wrong, site.dist)
        end
        trees = trees + s.count_entities_filtered({ position = c, radius = spec.site_radius - 2, type = { "tree", "simple-entity" } })
      end
      local dx, dy = sites[1].x - sites[2].x, sites[1].y - sites[2].y
      ctx.check(#bad == 0 and math.sqrt(dx * dx + dy * dy) > 2 * spec.site_radius,
        "2 taches completes : monazite (>= min_total chacune) sur les sables noirs, a 400-900 tuiles, disjointes",
        #bad > 0 and table.concat(bad, " ; ") or string.format("%d minerais en tout", total))
      ctx.check(trees == 0, "taches : aucun arbre ni rocher sur les sables noirs", trees)
      -- Foreuses : électrique et à combustible (basic-solid), sur la tache 1.
      local c1 = sites[1]
      ctx.power(c1.x, c1.y)
      st.ed = s.create_entity({ name = "electric-mining-drill", position = { c1.x - 2.5, c1.y + 0.5 }, force = "player", direction = defines.direction.north })
      st.bd = s.create_entity({ name = "burner-mining-drill", position = { c1.x + 3, c1.y + 1 }, force = "player", direction = defines.direction.north })
      if st.ed then st.ed_chest = s.create_entity({ name = "iron-chest", position = st.ed.drop_position, force = "player" }) end
      if st.bd then
        st.bd_chest = s.create_entity({ name = "iron-chest", position = st.bd.drop_position, force = "player" })
        st.bd.insert({ name = "coal", count = 20 })
      end
      ctx.check(st.ed and st.bd and st.ed_chest and st.bd_chest, "foreuse electrique et foreuse a combustible posees sur la monazite")
      return
    end
    if e.tick == T_LEVEL and st.m then
      st.coils_made = st.m.coil and st.m.coil.valid and out_inv(st.m.coil).get_item_count("fo-superconducting-coil") or 0
      st.level = { ok = false, cost_ok = false }
      if not (st.cc and st.cc.valid and st.wall and st.wall.valid) then st.level.detail = "centre ou mur absent"; return end
      local cost = LV.cost(LV.by_key.wall, 23)
      local parts, need, has_coil, has_eng = {}, 0, false, false
      for _, c in ipairs(cost) do
        parts[#parts + 1] = c[1] .. " " .. c[2]
        if c[1] == "fo-superconducting-coil" then need, has_coil = c[2], true end
        if c[1] == "electric-engine-unit" then has_eng = true end
      end
      st.level.cost = table.concat(parts, ", ")
      st.level.cost_ok = has_coil and not has_eng and LV.pay_epoch(LV.by_key.wall, 23) == 12
      local chest = st.cc.get_inventory(defines.inventory.chest)
      local moved = st.coils_made > 0 and out_inv(st.m.coil).remove({ name = "fo-superconducting-coil", count = math.min(st.coils_made, need) }) or 0
      if moved > 0 then chest.insert({ name = "fo-superconducting-coil", count = moved }) end
      for _, c in ipairs(cost) do
        local have = chest.get_item_count(c[1])
        if have < c[2] then chest.insert({ name = c[1], count = c[2] - have }) end
      end
      local before = chest.get_item_count("fo-superconducting-coil")
      local r = ctx.call("levels_upgrade", st.wall)
      local after = chest.get_item_count("fo-superconducting-coil")
      local new = r and r.entity
      st.level.ok = r and r.ok and r.reason == "done" and new and new.valid and new.name == LV.name(LV.by_key.wall, 23)
        and before - after == need
      st.level.detail = string.format("%s ; bobines de la chaine %d, completees par script %d ; coffre du centre %d -> %d (cout %d)",
        tostring(r and r.reason), moved, need - moved, before, after, need)
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local m = st.m or {}
    local ed = st.ed_chest and st.ed_chest.valid and st.ed_chest.get_item_count("fo-monazite-ore") or 0
    local bd = st.bd_chest and st.bd_chest.valid and st.bd_chest.get_item_count("fo-monazite-ore") or 0
    ctx.check(ed >= 4, "la foreuse electrique mine la monazite de la tache garantie", ed .. " minerais")
    ctx.check(bd >= 1, "la foreuse a combustible la mine aussi (basic-solid, X0)", bd .. " minerais")
    local function done(k) return m[k] and m[k].valid and m[k].products_finished or 0 end
    local steps = {
      { "conc", 2, "concentrateur : concentre de monazite (8 minerais -> 1)" },
      { "leach", 2, "usine chimique : lessivage (acide sulfurique) -> terres rares + oxyde de thorium" },
      { "extr", 2, "colonne d'extraction : solvant (huile legere) -> neodyme + yttrium" },
      { "air", 2, "unite cryogenique : distillation de l'air -> azote et oxygene liquides" },
      { "elec", 2, "electrolyseur : electrolyse de l'eau -> hydrogene + oxygene" },
      { "tape", 2, "four de frittage : ruban supraconducteur (yttrium, cuivre, oxygene)" },
      { "magnet", 2, "four de frittage : aimant permanent (neodyme, fer)" },
      { "cryostat", 2, "assembleur : cryostat (titane, plastique, processeur ; ecart du biopolymere)" },
      { "coil", 2, "bobineuse : BOBINE SUPRACONDUCTRICE (4 rubans, cryostat, azote liquide)" },
    }
    for _, sp in ipairs(steps) do
      ctx.check(done(sp[1]) >= sp[2], "chaine : " .. sp[3], done(sp[1]) .. " fabrication(s)")
    end
    local th = m.leach and m.leach.valid and out_inv(m.leach).get_item_count("fo-thorium-oxide") or 0
    local nd = m.extr and m.extr.valid and out_inv(m.extr).get_item_count("fo-neodymium") or 0
    local lox = m.air and m.air.valid and m.air.get_fluid_count("fo-liquid-oxygen") or 0
    ctx.check(th >= 2 and nd >= 4 and lox >= 15, "sous-produits de X : oxyde de thorium, neodyme, oxygene liquide",
      string.format("%d, %d, %.0f", th, nd, lox))
    local L = st.level or {}
    ctx.check((st.coils_made or 0) >= 2, "bobines sorties de la bobineuse (avant le paiement du niveau)", st.coils_made or 0)
    ctx.check(L.ok, "niveau de l'age 12 paye avec la bobine supraconductrice : mur 22 -> 23", L.detail)
    ctx.check(L.cost_ok, "cout du mur 23 : bobines supraconductrices, aucun moteur electrique", L.cost)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local opt = { aa = false }
    for pl, def in ipairs(PLANCHES) do
      local cx, cy = centre(pl - 1, 5)
      local _, hy = centre(pl - 1, 2)
      add("planche-" .. def.nom .. "-z1-jour", cx + 0.5, (cy + hy) / 2 + 0.5, 1, 0, opt)
      add("planche-" .. def.nom .. "-z1-nuit", cx + 0.5, (cy + hy) / 2 + 0.5, 1, 0.5, opt)
    end
    local mx, my = centre(0, 2)
    local fx = centre(0, 1)
    local cux = centre(0, 3)
    local m2x, m2y = centre(1, 2)
    local ilx = centre(1, 3)
    for _, mo in ipairs({ { "jour", 0 }, { "nuit", 0.5 } }) do
      add("monazite-cuivre-z2-" .. mo[1], (mx + cux) / 2 + 0.5, my + 0.5, 2, mo[2], opt)
      add("fer-monazite-z2-" .. mo[1], (fx + mx) / 2 + 0.5, my + 0.5, 2, mo[2], opt)
      add("monazite-ilmenite-z2-" .. mo[1], (m2x + ilx) / 2 + 0.5, m2y + 0.5, 2, mo[2], opt)
    end
    add("monazite-seule-z4-jour", mx + 0.5, my + 0.5, 4, 0, opt)
    if st.sites then
      add("tache-garantie-z05-jour", st.sites[1].x + 0.5, st.sites[1].y + 0.5, 0.5, 0, opt)
      add("tache-garantie-z05-nuit", st.sites[1].x + 0.5, st.sites[1].y + 0.5, 0.5, 0.5, opt)
    end
    add("machines-z1-jour", CX - 8, CY + 1, 1, 0, opt)
  end,
}
