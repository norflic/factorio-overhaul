--[[
  Scénario GREFFÉ « x1-titane » (lot X1-TITANE, 25/10) : le titane de l'âge 11 en moteur réel.

  Lancement : & "<racine>\fo-autotest.bat" nopause 3800 x1-titane "<source>"   (contrôle final au tick 3 600)
  Images    : & "<racine>\fo-captures.bat" x1-titane "<source>"

  1. Le CHAMP DE CRATÈRES garanti (fo-monde, posé à on_init) est retrouvé : gisement d'ilménite complet, 3 puits de
     saumure, sol des champs de cratères, distance 400-900.
  2. Sur ce champ : 4 foreuses électriques minent l'ilménite (catégorie fo-hard-solid) dans des coffres ; un chevalet de
     pompage pompe la saumure.
  3. La CHAÎNE du scénario X0, chaque recette dans SA machine (technologies du titane recherchées par script) : four à
     coke (coke), concentrateur (concentré d'ilménite), four à arc (laitier + fer), électrolyseur (saumure → chlore,
     hydrogène, soude, chlorure de magnésium), électrolyseur (chlorure de magnésium → magnésium + chlore), usine chimique
     (chloration → tétrachlorure), réacteur de Kroll (éponge + chlorure recyclé), four à arc (plaque de titane) ; et le
     puits à sous-produits : tungstène par voie humide (soude + hydrogène). Les objets et fluides passent d'une machine à
     la suivante PAR SCRIPT toutes les 20 ticks (pas de bras ni de tuyaux : ce banc prouve les recettes, les machines et
     leurs boîtes de fluide, pas une usine posée).
  4. Un NIVEAU DE L'ÂGE 11 payé avec la plaque : force à part, centre 15, mur 20 → 21 (coût du scénario : plaques de
     titane, plus de structure basse densité) ; les plaques produites par la chaîne, complétées par script jusqu'au coût.
  5. Captures (session avec images) : planche de 6 gisements de 9 × 9 aux 8 stades sur le sol des cratères (fer,
     ILMÉNITE, tungstène / charbon, pierre, uranium : même géométrie que m1-minerai, mesurée par
     tools/autotest/x1_lisibilite.py), même planche sur l'herbe (ilménite sur son sol), gros plans au zoom 2 à côté du
     fer et du tungstène, de jour et de nuit ; le champ garanti ; la chaîne de machines (visuels provisoires).
]]

local MONDE = "fo-monde"
local LV = require("__factorio-overhaul__/shared/levels/config")

local X0, Y0 = 3600, 3600
local PAS = 11
local R = 4
local ORDRE = { "iron-ore", "fo-ilmenite", "fo-tungsten-ore", "coal", "stone", "uranium-ore" }
local IL = 2
local CX, CY = 3600, 3720          -- chaîne de machines
local LX, LY = 3640, 3720          -- force à part : mur en (LX, LY), centre 15 à 20 tuiles à l'est
local T_SITE, STEP, T_LEVEL, CHECK = 2, 20, 3400, 3600
local FORCE = "x1-titane"

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

local function out_inv(e) return e.get_inventory(defines.inventory.assembling_machine_output) end
local function in_inv(e) return e.get_inventory(defines.inventory.assembling_machine_input) end

--- Objets : de l'inventaire `from` vers l'entrée de la machine `to` (au plus `max`). Renvoie le nombre passé.
local function give(from, to, item, max)
  if not (from and from.valid and to and to.valid) then return 0 end
  local n = from.get_item_count(item)
  if max then n = math.min(n, max) end
  if n <= 0 then return 0 end
  local ins = in_inv(to).insert({ name = item, count = n })
  if ins > 0 then from.remove({ name = item, count = ins }) end
  return ins
end

--- Fluide : de l'entité `from` vers l'entité `to` (au plus `max`). Renvoie la quantité passée.
local function pour(from, to, fluid, max)
  if not (from and from.valid and to and to.valid) then return 0 end
  local a = from.get_fluid_count(fluid)
  if max then a = math.min(a, max) end
  if a < 1 then return 0 end
  local ins = to.insert_fluid({ name = fluid, amount = a })
  if ins > 0 then from.remove_fluid({ name = fluid, amount = ins }) end
  return ins
end

local function machine(s, name, x, y, recipe)
  local e = s.create_entity({ name = name, position = { x, y }, force = "player", raise_built = true })
  if e and recipe then e.set_recipe(recipe) end
  return e
end

return {
  description = "x1-titane : champ de crateres garanti, ilmenite minee, chaine de Kroll jusqu'a la plaque, niveau de l'age 11 paye",
  check_tick = CHECK,
  shots_delay = 300,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    -- Prototypes du lot, noms gardés du scénario X0.
    local need = { { "entity", "fo-ilmenite" }, { "entity", "fo-brine" }, { "item", "fo-ilmenite-ore" }, { "item", "fo-titanium-plate" },
      { "entity", "fo-kroll-reactor" }, { "entity", "fo-arc-furnace" }, { "entity", "fo-electrolyzer" }, { "entity", "fo-ore-concentrator" },
      { "entity", "fo-coke-oven" }, { "fluid", "fo-chlorine" }, { "fluid", "fo-titanium-tetrachloride" }, { "fluid", "fo-hydrogen" },
      { "tile", "fo-crater-fields" } }
    local miss = {}
    for _, n in ipairs(need) do
      local t = n[1] == "entity" and game.entity_prototypes or n[1] == "item" and game.item_prototypes
        or n[1] == "fluid" and game.fluid_prototypes or game.tile_prototypes
      if not t[n[2]] then miss[#miss + 1] = n[2] end
    end
    ctx.check(#miss == 0, "prototypes du titane presents (ressources, objets, fluides, machines, sol)", #miss > 0 and table.concat(miss, ", ") or nil)
    local p = game.entity_prototypes["fo-ilmenite"]
    ctx.check(p and p.resource_category == "fo-hard-solid" and p.mineable_properties.products[1].name == "fo-ilmenite-ore"
      and game.entity_prototypes["fo-brine"].infinite_resource,
      "ilmenite : minerai dur, produit fo-ilmenite-ore ; saumure : gisement infini")
    -- Plaque : pile du scénario X0 (100), matériau d'époque de l'âge 11 dans la config.
    local ip = game.item_prototypes["fo-titanium-plate"]
    local m = LV.epoch_materials[11]
    ctx.check(ip and ip.stack_size == 100 and m.item == "fo-titanium-plate" and not m.provisional,
      "plaque de titane : pile 100, monnaie de l'age 11 (plus de remplacant)", m.item)
    -- Technologies : recherchées par script, puis recettes ouvertes.
    local f = game.forces.player
    f.technologies["fo-titanium-processing"].researched = true
    f.technologies["fo-wet-tungsten"].researched = true
    local closed = {}
    for _, r in ipairs({ "fo-coke", "fo-ilmenite-concentrate", "fo-ilmenite-smelting", "fo-brine-electrolysis", "fo-chlorination",
      "fo-kroll-reduction", "fo-magnesium-electrolysis", "fo-titanium-plate", "fo-wet-tungsten", "fo-kroll-reactor", "fo-arc-furnace",
      "fo-electrolyzer", "fo-ore-concentrator", "fo-coke-oven" }) do
      if not (f.recipes[r] and f.recipes[r].enabled) then closed[#closed + 1] = r end
    end
    ctx.check(#closed == 0, "technologies du titane : 14 recettes ouvertes", #closed > 0 and table.concat(closed, ", ") or nil)

    -- Planches de gisements (captures).
    ctx.prepare_area(X0 - 40, Y0 - 30, X0 + 70, Y0 + 140, "grass-1")
    for _, e in ipairs(s.find_entities_filtered({ area = { { X0 - 120, Y0 - 120 }, { X0 + 160, Y0 + 220 } }, force = "enemy" })) do e.destroy() end
    local n_ok = 0
    for planche = 0, 1 do
      for i, nom in ipairs(ORDRE) do
        local cx, cy = centre(planche, i)
        local sol = (planche == 0 or nom == "fo-ilmenite") and "fo-crater-fields" or "grass-1"
        if poser(s, nom, cx, cy, sol) >= 60 then n_ok = n_ok + 1 end
      end
    end
    ctx.check(n_ok == 12, "12 gisements de planche poses (9 x 9, 8 stades)", n_ok)

    -- Chaîne de machines (visuels provisoires), alimentée.
    st.m = {
      coke = machine(s, "fo-coke-oven", CX - 30.5, CY + 0.5, "fo-coke"),
      conc = machine(s, "fo-ore-concentrator", CX - 25, CY, "fo-ilmenite-concentrate"),
      arc1 = machine(s, "fo-arc-furnace", CX - 20, CY, "fo-ilmenite-smelting"),
      ela = machine(s, "fo-electrolyzer", CX - 13.5, CY + 0.5, "fo-brine-electrolysis"),
      elb = machine(s, "fo-electrolyzer", CX - 8.5, CY + 0.5, "fo-magnesium-electrolysis"),
      chl = machine(s, "chemical-plant", CX - 3.5, CY + 0.5, "fo-chlorination"),
      kroll = machine(s, "fo-kroll-reactor", CX + 2, CY, "fo-kroll-reduction"),
      arc2 = machine(s, "fo-arc-furnace", CX + 8, CY, "fo-titanium-plate"),
      wet = machine(s, "chemical-plant", CX + 13.5, CY + 0.5, "fo-wet-tungsten"),
    }
    ctx.power(CX - 8, CY + 6)
    -- Force à part pour le niveau de l'âge 11 : centre 15 et mur au niveau 20 (levels_points en modèle).
    local lf = game.forces[FORCE] or game.create_force(FORCE)
    st.cc = s.create_entity({ name = LV.name(LV.by_key.command, 15), position = { LX + 20, LY }, force = lf, raise_built = true })
    st.wall = s.create_entity({ name = LV.name(LV.by_key.wall, 20), position = { LX + 0.5, LY + 0.5 }, force = lf, raise_built = true })
    ctx.check(st.cc and st.wall, "force a part : centre 15 et mur 20 poses")
    local placed, bad = 0, {}
    for _, k in ipairs({ "coke", "conc", "arc1", "ela", "elb", "chl", "kroll", "arc2", "wet" }) do
      local e = st.m[k]
      if e and e.valid and e.get_recipe() then placed = placed + 1 else bad[#bad + 1] = k end
    end
    ctx.check(placed == 9, "chaine : 9 machines posees, chacune avec sa recette", #bad > 0 and table.concat(bad, ", ") or nil)
    if st.m.coke then
      st.m.coke.get_fuel_inventory().insert({ name = "coal", count = 20 })
      in_inv(st.m.coke).insert({ name = "coal", count = 30 })
    end
    if st.m.wet then in_inv(st.m.wet).insert({ name = "fo-tungsten-ore", count = 10 }) end
    st.moved = { ore = 0, brine = 0, chlorine = 0, h2 = 0, ticl4 = 0, mg = 0 }
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == T_SITE then
      -- 1. Champ de cratères garanti.
      local specs = ctx.remote(MONDE, "specs")
      local spec = by_key(specs, "ilmenite")
      local d = by_key(ctx.remote(MONDE, "status").done, "ilmenite")
      local site = d and d.sites and d.sites[1]
      ctx.check(spec and d and d.ok and d.phase == "init" and site, "champ de crateres garanti pose a on_init (fo-monde)",
        site and string.format("(%d, %d) a %.1f tuiles, candidat %d", site.x, site.y, site.dist, site.try) or "absent")
      if not (spec and site) then return end
      st.site = { x = site.x, y = site.y }
      local c = { site.x + 0.5, site.y + 0.5 }
      local ore = s.find_entities_filtered({ name = "fo-ilmenite", position = c, radius = spec.core_radius + 1.5 })
      local wells = s.find_entities_filtered({ name = "fo-brine", position = c, radius = spec.core_radius + 1.5 })
      local total, wrong = 0, 0
      for _, r in ipairs(ore) do
        total = total + r.amount
        if s.get_tile(math.floor(r.position.x), math.floor(r.position.y)).name ~= "fo-crater-fields" then wrong = wrong + 1 end
      end
      for _, w in ipairs(wells) do
        if s.get_tile(math.floor(w.position.x), math.floor(w.position.y)).name ~= "fo-crater-fields" then wrong = wrong + 1 end
      end
      ctx.check(#ore == site.entities and total == site.total and total >= spec.min_total and #wells == 3 and wrong == 0
        and site.dist >= spec.dmin and site.dist <= spec.dmax,
        "champ complet : ilmenite (>= min_total) et 3 puits de saumure sur le sol des crateres, a 400-900 tuiles",
        string.format("%d entites, %d ; puits %d ; hors sol %d ; distance %.1f", #ore, total, #wells, wrong, site.dist))
      local trees = s.count_entities_filtered({ position = c, radius = spec.site_radius - 2, type = { "tree", "simple-entity" } })
      ctx.check(trees == 0, "champ : aucun arbre ni rocher sur le disque de regolithe", trees)
      -- 2. Foreuses sur l'ilménite (centre du gisement : décalage du champ), chevalet sur le premier puits.
      local ox, oy = site.x + spec.ore_offset[1], site.y + spec.ore_offset[2]
      ctx.power(ox, oy)
      st.drills, st.chests = {}, {}
      for _, p in ipairs({ { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }) do
        local dr = s.create_entity({ name = "electric-mining-drill", position = { ox + p[1] + 0.5, oy + p[2] + 0.5 }, force = "player",
          direction = defines.direction.north })
        if dr then
          st.drills[#st.drills + 1] = dr
          st.chests[#st.chests + 1] = s.create_entity({ name = "iron-chest", position = dr.drop_position, force = "player" })
        end
      end
      ctx.check(#st.drills == 4 and #st.chests == 4, "4 foreuses electriques et leurs coffres poses sur l'ilmenite du champ")
      local w1 = wells[1]
      st.pump = w1 and s.create_entity({ name = "pumpjack", position = w1.position, force = "player", direction = defines.direction.north })
      ctx.check(st.pump ~= nil, "chevalet de pompage pose sur un puits de saumure du champ")
      return
    end
    if e.tick == T_LEVEL and st.m then
      -- 4. Niveau de l'âge 11 payé avec la plaque : les plaques produites, complétées par script jusqu'au coût.
      local out2 = st.m.arc2 and st.m.arc2.valid and out_inv(st.m.arc2)
      local made = out2 and out2.get_item_count("fo-titanium-plate") or 0
      st.plates_made = made
      st.level = { ok = false, cost_ok = false }
      if not (st.cc and st.cc.valid and st.wall and st.wall.valid) then
        st.level.detail = "centre ou mur absent"
        return
      end
      local cost = LV.cost(LV.by_key.wall, 21)
      local parts, need, has_ti, has_lds = {}, 0, false, false
      for _, c in ipairs(cost) do
        parts[#parts + 1] = c[1] .. " " .. c[2]
        if c[1] == "fo-titanium-plate" then need, has_ti = c[2], true end
        if c[1] == "low-density-structure" then has_lds = true end
      end
      st.level.cost = table.concat(parts, ", ")
      st.level.cost_ok = has_ti and not has_lds and LV.pay_epoch(LV.by_key.wall, 21) == 11
      local chest = st.cc.get_inventory(defines.inventory.chest)
      local moved = made > 0 and out2.remove({ name = "fo-titanium-plate", count = math.min(made, need) }) or 0
      if moved > 0 then chest.insert({ name = "fo-titanium-plate", count = moved }) end
      for _, c in ipairs(cost) do
        local have = chest.get_item_count(c[1])
        if have < c[2] then chest.insert({ name = c[1], count = c[2] - have }) end
      end
      local before = chest.get_item_count("fo-titanium-plate")
      local r = ctx.call("levels_upgrade", st.wall)
      local after = chest.get_item_count("fo-titanium-plate")
      local new = r and r.entity
      st.level.ok = r and r.ok and r.reason == "done" and new and new.valid and new.name == LV.name(LV.by_key.wall, 21)
        and before - after == need
      st.level.detail = string.format("%s ; plaques de la chaine %d, completees par script %d ; coffre du centre %d -> %d (cout %d)",
        tostring(r and r.reason), moved, need - moved, before, after, need)
      return
    end
    if e.tick % STEP ~= 0 or not st.m or e.tick > T_LEVEL then return end
    -- 3. Transferts par script entre les machines de la chaîne.
    local m = st.m
    for _, ch in ipairs(st.chests or {}) do
      if ch.valid then st.moved.ore = st.moved.ore + give(ch.get_inventory(defines.inventory.chest), m.conc, "fo-ilmenite-ore", 16) end
    end
    st.moved.brine = st.moved.brine + pour(st.pump, m.ela, "fo-brine", 400)
    -- Coke : la chloration d'abord (au plus 3 en attente), le four à arc ensuite (au plus 4) ; passage 1 : le four à
    -- arc gardait tout le coke et la chloration n'en recevait pas.
    give(out_inv(m.coke), m.chl, "fo-coke", math.max(0, 3 - in_inv(m.chl).get_item_count("fo-coke")))
    give(out_inv(m.coke), m.arc1, "fo-coke", math.max(0, 4 - in_inv(m.arc1).get_item_count("fo-coke")))
    give(out_inv(m.conc), m.arc1, "fo-ilmenite-concentrate")
    give(out_inv(m.arc1), m.chl, "fo-titanium-slag")
    st.moved.chlorine = st.moved.chlorine + pour(m.ela, m.chl, "fo-chlorine") + pour(m.elb, m.chl, "fo-chlorine")
    st.moved.h2 = st.moved.h2 + pour(m.ela, m.wet, "fo-hydrogen")
    give(out_inv(m.ela), m.wet, "fo-caustic-soda")
    give(out_inv(m.ela), m.elb, "fo-magnesium-chloride")
    give(out_inv(m.kroll), m.elb, "fo-magnesium-chloride")
    st.moved.mg = st.moved.mg + give(out_inv(m.elb), m.kroll, "fo-magnesium")
    st.moved.ticl4 = st.moved.ticl4 + pour(m.chl, m.kroll, "fo-titanium-tetrachloride")
    give(out_inv(m.kroll), m.arc2, "fo-titanium-sponge")
    -- Pas de torchère en jeu (âge 4, hors lot) : l'excès d'hydrogène et de chlore que les machines suivantes n'acceptent
    -- plus (une machine à recette n'accepte que 2 fois le besoin d'une fabrication, vu au passage 2) est RETIRÉ par
    -- script, compté à part, pour que l'électrolyseur ne s'arrête pas sur sortie pleine.
    st.vented = st.vented or { h2 = 0, cl = 0 }
    for _, k in ipairs({ "ela", "elb" }) do
      local e = m[k]
      if e and e.valid then
        local h = e.get_fluid_count("fo-hydrogen")
        if h > 100 then st.vented.h2 = st.vented.h2 + e.remove_fluid({ name = "fo-hydrogen", amount = h - 100 }) end
        local c = e.get_fluid_count("fo-chlorine")
        if c > 200 then st.vented.cl = st.vented.cl + e.remove_fluid({ name = "fo-chlorine", amount = c - 200 }) end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local m = st.m or {}
    local function done(k) return m[k] and m[k].valid and m[k].products_finished or 0 end
    local mined = st.moved.ore
    for _, ch in ipairs(st.chests or {}) do if ch.valid then mined = mined + ch.get_item_count("fo-ilmenite-ore") end end
    ctx.check(mined >= 16, "les foreuses electriques ont mine l'ilmenite du champ garanti", mined .. " minerais")
    ctx.check(st.moved.brine >= 300, "le chevalet a pompe la saumure du champ garanti", string.format("%.0f saumure", st.moved.brine))
    local steps = {
      { "coke", 2, "four a coke : coke (charbon x 3 -> coke x 2)" },
      { "conc", 2, "concentrateur : concentre d'ilmenite (8 minerais -> 1)" },
      { "arc1", 1, "four a arc : laitier titanifere (+ 6 plaques de fer)" },
      { "ela", 2, "electrolyseur : saumure -> chlore, hydrogene, soude, chlorure de magnesium" },
      { "elb", 2, "electrolyseur : chlorure de magnesium -> magnesium + chlore" },
      { "chl", 1, "usine chimique : chloration -> tetrachlorure de titane" },
      { "kroll", 1, "reacteur de Kroll : eponge de titane (+ chlorure recycle)" },
      { "arc2", 1, "four a arc : refusion -> PLAQUE DE TITANE" },
      { "wet", 1, "usine chimique : tungstene par voie humide (soude + hydrogene de la saumure)" },
    }
    for _, sp in ipairs(steps) do
      ctx.check(done(sp[1]) >= sp[2], "chaine : " .. sp[3], done(sp[1]) .. " produit(s) fini(s)")
    end
    local fe = m.arc1 and m.arc1.valid and out_inv(m.arc1).get_item_count("iron-plate") or 0
    ctx.check(fe >= 6, "sous-produit du four a arc : plaques de fer", fe)
    ctx.log(string.format("transferts : minerai %d, saumure %.0f, chlore %.0f, hydrogene %.0f, tetrachlorure %.0f, magnesium %d ; retires (sans torchere) : hydrogene %.0f, chlore %.0f",
      st.moved.ore, st.moved.brine, st.moved.chlorine, st.moved.h2, st.moved.ticl4, st.moved.mg,
      st.vented and st.vented.h2 or 0, st.vented and st.vented.cl or 0))
    -- État de chaque machine (diagnostic : statut, entrées, sorties, boîtes de fluide).
    local status_name = {}
    for k, v in pairs(defines.entity_status) do status_name[v] = k end
    for _, k in ipairs({ "coke", "conc", "arc1", "ela", "elb", "chl", "kroll", "arc2", "wet" }) do
      local e = m[k]
      if e and e.valid then
        local function inv(i)
          local parts = {}
          local c = i and i.get_contents() or {}
          local names = {}
          for n in pairs(c) do names[#names + 1] = n end
          table.sort(names)
          for _, n in ipairs(names) do parts[#parts + 1] = n .. " " .. c[n] end
          return table.concat(parts, ", ")
        end
        local fb = {}
        for i = 1, #e.fluidbox do
          local f = e.fluidbox[i]
          fb[#fb + 1] = i .. ":" .. (f and (f.name .. " " .. string.format("%.0f", f.amount)) or "-")
        end
        ctx.log(string.format("machine %s (%s) : statut %s ; entree [%s] ; sortie [%s] ; fluides [%s]", k, e.name,
          tostring(status_name[e.status]), inv(in_inv(e)), inv(out_inv(e)), table.concat(fb, " ")))
      end
    end
    ctx.check((st.plates_made or 0) >= 1, "plaques de titane sorties de la chaine (avant le paiement du niveau)", st.plates_made or 0)
    -- 4. Niveau de l'âge 11 (fait au tick T_LEVEL, résultat relu ici).
    local L = st.level or {}
    ctx.check(L.ok, "niveau de l'age 11 paye avec la plaque de titane : mur 20 -> 21", L.detail)
    ctx.check(L.cost_ok, "cout du mur 21 : plaques de titane, aucune structure basse densite", L.cost)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local opt = { aa = false }
    for _, pn in ipairs({ { 0, "crateres" }, { 1, "natif" } }) do
      local planche, nom = pn[1], pn[2]
      local cx, cy = centre(planche, 5)
      local _, hy = centre(planche, 2)
      add("planche-" .. nom .. "-z1-jour", cx + 0.5, (cy + hy) / 2 + 0.5, 1, 0, opt)
      add("planche-" .. nom .. "-z1-nuit", cx + 0.5, (cy + hy) / 2 + 0.5, 1, 0.5, opt)
    end
    local ix, iy = centre(0, IL)
    local fx = centre(0, 1)
    local tx = centre(0, 3)
    add("crateres-fer-ilmenite-z2-jour", (ix + fx) / 2 + 0.5, iy + 0.5, 2, 0, opt)
    add("crateres-fer-ilmenite-z2-nuit", (ix + fx) / 2 + 0.5, iy + 0.5, 2, 0.5, opt)
    add("crateres-ilmenite-tungstene-z2-jour", (ix + tx) / 2 + 0.5, iy + 0.5, 2, 0, opt)
    add("crateres-ilmenite-tungstene-z2-nuit", (ix + tx) / 2 + 0.5, iy + 0.5, 2, 0.5, opt)
    add("ilmenite-seul-z4-jour", ix + 0.5, iy + 0.5, 4, 0, opt)
    if st.site then
      add("champ-garanti-z05-jour", st.site.x + 0.5, st.site.y + 0.5, 0.5, 0, opt)
      add("champ-garanti-z05-nuit", st.site.x + 0.5, st.site.y + 0.5, 0.5, 0.5, opt)
    end
    add("chaine-z1-jour", CX - 9, CY + 1, 1, 0, opt)
  end,
}
