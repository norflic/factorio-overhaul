-- Scénario greffé du lot INDUSTRIE I4 (31/10) : LA LECTURE GÉNÉRIQUE des recettes et machines (cat.fab, cat.kit) contre le
-- moteur réel. 100 ticks :
--   & "<racine>\fo-autotest.bat" nopause 100 ind-lecture "<source>"
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui IND-I4 -- 100 ind-lecture <source>
-- Sur le mod livré, et sur la copie jetable (tools/autotest/ind/jetable.py : machine inventée, catégorie neuve, objet à
-- 3 solides et 1 fluide, bras neuf), où le scénario attend en plus l'objet inventé (variable `ind_jetable` du mod de test :
-- le scénario le détecte à la présence du prototype « fo-ind-jetable-machine »).
-- Contrôles :
--   1. le catalogue se lit (remote « fo-iag », lecture) : N recettes, N patronnables, chaque refus a sa raison écrite ;
--   2. le nombre de recettes lues = le compte INDÉPENDANT fait ici dans les prototypes (non cachées, actives au départ ou
--      débloquées par une technologie recherchable) ;
--   3. CÔTÉ POSITIF : pour chaque machine d'assemblage donnée à une recette patronnable, la machine est posée et
--      `set_recipe` est accepté (la recette tient dans la machine) ;
--   4. CÔTÉ NÉGATIF : une paire (machine, recette) de catégorie étrangère est refusée par le moteur ; les autres refus
--      (ingrédients, boîtes) sont comptés et journalisés (FAIT) ;
--   5. kit : chaque pièce choisie existe et a les nombres attendus pour son TYPE (portée 1 et 2 des bras, vitesse du tapis,
--      cases du coffre, fil du poteau), relus dans le prototype du moteur.
-- Journal du mod (hors scénario) : « [FO-IND-LECTURE] N recettes lues, N patronnables … » à la première lecture.

local X0, Y0 = 4200, 4200
local COLS, STEP = 12, 9

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

return {
  description = "I4 : lecture générique des recettes, des machines et du kit contre le moteur",
  base = nil,
  check_tick = 90,

  init = function(ctx)
    ctx.prepare_area(X0 - 8, Y0 - 8, X0 + COLS * STEP + 8, Y0 + 12 * STEP + 8, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    ctx.check(ctx.power(X0 + COLS * STEP / 2, Y0 + 6 * STEP) ~= nil, "alimentation invisible du mod de test")
  end,

  -- Tick 10 : un four de chaque machine à four donnée à une recette, garni de l'ingrédient de la première recette à un solide
  -- qu'on lui donne ; au contrôle (tick 90), il doit AVOIR TRAVAILLÉ (un four n'a pas de set_recipe : la preuve est la marche).
  tick = function(ctx, e)
    if e.tick ~= 10 then return end
    local st = ctx.state()
    st.furnaces = {}
    local ok, info = pcall(remote.call, "fo-iag", "lecture")
    if not (ok and type(info) == "table") then return end
    local s = ctx.surface()
    local first = {}
    for _, rn in ipairs(sorted_keys(info.fab)) do
      local f = info.fab[rn]
      if f.patronnable and f.s == 1 and f.fluides_in == 0 then
        for _, mn in ipairs(f.machines) do
          local proto = game.entity_prototypes[mn]
          if proto and proto.type == "furnace" and not first[mn] then first[mn] = rn end
        end
      end
    end
    local idx = 0
    for _, mn in ipairs(sorted_keys(first)) do
      local rn = first[mn]
      local col, row = idx % COLS, 8 + math.floor(idx / COLS)
      idx = idx + 1
      local m = s.create_entity({ name = mn, position = { X0 + col * STEP + 4, Y0 + row * STEP + 4 }, force = "player" })
      if m then
        game.forces.player.recipes[rn].enabled = true
        local ing = game.recipe_prototypes[rn].ingredients[1]
        m.insert({ name = ing.name, count = math.max(1, ing.amount) * 2 })
        local fuel = m.get_fuel_inventory()
        if fuel then fuel.insert({ name = "coal", count = 5 }) end
      end
      st.furnaces[#st.furnaces + 1] = { m = m, name = mn, recipe = rn }
    end
  end,

  finish = function(ctx)
    local s = ctx.surface()
    local ok, info = pcall(remote.call, "fo-iag", "lecture")
    ctx.check(ok and type(info) == "table" and info.summary ~= nil, "la lecture du catalogue répond (fo-iag, lecture)",
      ok and "" or tostring(info))
    if not (ok and type(info) == "table") then return end
    local sum = info.summary
    ctx.log("FAIT " .. info.line)
    ctx.log("FAIT " .. info.kit)
    ctx.check(sum.total > 0 and sum.patronnables > 0 and sum.patronnables <= sum.total,
      "recettes lues et patronnables", sum.total .. " lues, " .. sum.patronnables .. " patronnables")

    -- 1. chaque refus a sa raison
    local mute = 0
    for _, name in ipairs(sorted_keys(info.fab)) do
      local e = info.fab[name]
      if not e.patronnable and not (e.refus and e.texte and e.texte:sub(1, 8) == "limite :") then mute = mute + 1 end
      if e.patronnable and #e.machines == 0 then mute = mute + 1 end
    end
    ctx.check(mute == 0, "chaque refus garde sa raison écrite, chaque recette patronnable a une machine", mute .. " muet(s)")

    -- 2. compte indépendant des recettes
    local unlockable = {}
    for _, tn in ipairs(sorted_keys(game.technology_prototypes)) do
      local t = game.technology_prototypes[tn]
      if not t.research_unit_count_formula and t.enabled and not t.hidden then
        for _, ef in ipairs(t.effects or {}) do
          if ef.type == "unlock-recipe" then unlockable[ef.recipe] = true end
        end
      end
    end
    local n_ref, n_visible = 0, 0
    for _, rn in ipairs(sorted_keys(game.recipe_prototypes)) do
      local r = game.recipe_prototypes[rn]
      if not r.hidden then
        n_visible = n_visible + 1
        if r.enabled or unlockable[rn] then n_ref = n_ref + 1 end
      end
    end
    ctx.check(n_ref == sum.total, "recettes lues = compte indépendant dans les prototypes",
      sum.total .. " lues, " .. n_ref .. " comptées (" .. n_visible .. " non cachées)")

    -- 3. et 4. machines d'assemblage : posées une fois chacune, la recette posée à chaque paire
    local machines, per_machine = {}, {}
    for _, name in ipairs(sorted_keys(info.fab)) do
      local e = info.fab[name]
      for _, m in ipairs(e.machines or {}) do
        per_machine[m] = per_machine[m] or {}
        table.insert(per_machine[m], name)
        machines[m] = true
      end
    end
    local list = sorted_keys(machines)
    local placed, furnaces, pairs_ok, pairs_bad, bad_ex = {}, 0, 0, 0, {}
    local idx = 0
    local function spot()
      local col, row = idx % COLS, math.floor(idx / COLS)
      idx = idx + 1
      return { X0 + col * STEP + 4, Y0 + row * STEP + 4 }
    end
    for _, mn in ipairs(list) do
      local proto = game.entity_prototypes[mn]
      if proto and proto.type == "assembling-machine" then
        local m = s.create_entity({ name = mn, position = spot(), force = "player" })
        placed[mn] = m
        if m then
          for _, rn in ipairs(per_machine[mn]) do
            local okset = pcall(function() m.set_recipe(rn) end)
            local rec = okset and m.get_recipe() or nil
            if rec and rec.name == rn then
              pairs_ok = pairs_ok + 1
            else
              pairs_bad = pairs_bad + 1
              if #bad_ex < 8 then bad_ex[#bad_ex + 1] = mn .. " / " .. rn end
            end
          end
        end
      else
        furnaces = furnaces + 1
      end
    end
    local n_placed = 0
    for _, mn in ipairs(sorted_keys(placed)) do if placed[mn] then n_placed = n_placed + 1 end end
    ctx.log(string.format("FAIT machines données aux recettes : %d (dont %d d'assemblage posées au banc, %d autres : fours, non vérifiées par set_recipe)",
      #list, n_placed, furnaces))
    ctx.check(n_placed + furnaces == #list, "chaque machine d'assemblage donnée à une recette est posable", (#list - n_placed - furnaces) .. " non posée(s)")
    ctx.check(pairs_bad == 0 and pairs_ok > 0, "côté positif : le moteur accepte chaque (machine, recette) que la lecture donne",
      pairs_ok .. " acceptée(s), " .. pairs_bad .. " refusée(s) " .. table.concat(bad_ex, " ; "))

    -- fours : la marche prouve que le four prend la recette que la lecture lui donne
    local st = ctx.state()
    local f_ok, f_bad, f_ex = 0, 0, {}
    for _, f in ipairs(st.furnaces or {}) do
      local m = f.m
      local worked = false
      if m and m.valid then
        local out = m.get_output_inventory()
        worked = m.is_crafting() or m.crafting_progress > 0 or (out ~= nil and not out.is_empty())
      end
      if worked then f_ok = f_ok + 1 else
        f_bad = f_bad + 1
        if #f_ex < 6 then f_ex[#f_ex + 1] = f.name .. " / " .. f.recipe end
      end
    end
    ctx.log(string.format("FAIT fours : %d posés au tick 10, %d ont travaillé", #(st.furnaces or {}), f_ok))
    ctx.check(f_bad == 0 and f_ok == furnaces, "fours : chaque four donné à une recette travaille sur la première recette à un solide qu'on lui donne",
      f_ok .. " en marche sur " .. furnaces .. " ; arrêtés : " .. table.concat(f_ex, " ; "))

    -- côté négatif : paires dont la lecture dit non (catégorie étrangère, trop d'ingrédients, pas assez de boîtes)
    local neg = { categorie = { 0, 0 }, ingredients = { 0, 0 }, boites = { 0, 0 } } -- { refusées par le moteur, acceptées }
    local neg_ex = {}
    local PER = 6
    for _, mn in ipairs(sorted_keys(placed)) do
      local m = placed[mn]
      local proto = game.entity_prototypes[mn]
      if m and m.valid then
        local done = { categorie = 0, ingredients = 0, boites = 0 }
        local n_in = 0
        for _, fb in ipairs(proto.fluidbox_prototypes or {}) do if fb.production_type == "input" then n_in = n_in + 1 end end
        for _, rn in ipairs(sorted_keys(game.recipe_prototypes)) do
          local r = game.recipe_prototypes[rn]
          local why
          if not r.hidden then
            if not proto.crafting_categories[r.category] then
              why = "categorie"
            else
              local solids, fluids = 0, 0
              for _, i in ipairs(r.ingredients) do if i.type == "fluid" then fluids = fluids + 1 else solids = solids + 1 end end
              if solids > proto.ingredient_count then why = "ingredients"
              elseif fluids > n_in then why = "boites" end
            end
          end
          if why and done[why] < PER then
            done[why] = done[why] + 1
            local okset = pcall(function() m.set_recipe(rn) end)
            local rec = okset and m.get_recipe() or nil
            local accepted = rec ~= nil and rec.name == rn
            neg[why][accepted and 2 or 1] = neg[why][accepted and 2 or 1] + 1
            if accepted and #neg_ex < 8 then neg_ex[#neg_ex + 1] = why .. " : " .. mn .. " / " .. rn end
            pcall(function() m.set_recipe(nil) end)
          end
        end
      end
    end
    for _, w in ipairs({ "categorie", "ingredients", "boites" }) do
      ctx.log(string.format("FAIT côté négatif %s : %d refusée(s) par le moteur, %d acceptée(s)", w, neg[w][1], neg[w][2]))
    end
    for _, e in ipairs(neg_ex) do ctx.log("FAIT négatif accepté par le moteur : " .. e) end
    ctx.check(neg.categorie[2] == 0 and neg.categorie[1] > 0, "côté négatif : une catégorie étrangère est refusée par le moteur",
      neg.categorie[1] .. " refusée(s), " .. neg.categorie[2] .. " acceptée(s)")

    -- 5. kit relu dans le moteur
    local kit = info.kit_items
    local function proto_of(item)
      local it = item and game.item_prototypes[item]
      return it and it.place_result or nil
    end
    local want_type = { bras = "inserter", bras_long = "inserter", tapis = "transport-belt", coffre = "container", poteau = "electric-pole" }
    local bad_kit = {}
    for _, k in ipairs({ "bras", "bras_long", "tapis", "coffre", "poteau" }) do
      local p = proto_of(kit[k])
      if not p then
        bad_kit[#bad_kit + 1] = k .. " absent"
      elseif p.type ~= want_type[k] then
        bad_kit[#bad_kit + 1] = k .. " type " .. p.type
      elseif k == "bras" or k == "bras_long" then
        local reach = math.floor(math.max(math.abs(p.inserter_pickup_position.x or p.inserter_pickup_position[1] or 0),
          math.abs(p.inserter_pickup_position.y or p.inserter_pickup_position[2] or 0)) + 0.5)
        if reach ~= (k == "bras" and 1 or 2) then bad_kit[#bad_kit + 1] = k .. " portée " .. reach end
        if (p.filter_count or 0) ~= 0 then bad_kit[#bad_kit + 1] = k .. " a un filtre" end
      elseif k == "tapis" then
        if not (p.belt_speed and p.belt_speed > 0) then bad_kit[#bad_kit + 1] = "tapis sans vitesse" end
      elseif k == "coffre" then
        if not ((p.get_inventory_size(defines.inventory.chest) or 0) > 0) then bad_kit[#bad_kit + 1] = "coffre sans case" end
      else
        if not ((p.max_wire_distance or 0) > 0 and (p.supply_area_distance or 0) > 0) then bad_kit[#bad_kit + 1] = "poteau sans fil ni couverture" end
      end
      ctx.log("FAIT kit " .. k .. " : " .. tostring(kit[k]))
    end
    ctx.check(#bad_kit == 0, "kit : chaque pièce a son type et ses nombres dans le moteur", table.concat(bad_kit, " ; "))

    -- 6. copie jetable : l'objet inventé (machine 4 × 4, catégorie neuve, 3 solides et 1 fluide) est lu sans code
    if game.entity_prototypes["fo-ind-jetable-machine"] then
      local e = info.fab["fo-ind-jetable-noyau"]
      local ms = e and table.concat(e.machines, ",") or "-"
      ctx.check(e ~= nil and e.patronnable and e.s == 3 and e.fluides_in == 1 and ms == "fo-ind-jetable-machine",
        "copie jetable : la recette inventée (3 solides, 1 fluide, catégorie neuve) est lue et patronnable sur la machine inventée",
        e and (tostring(e.patronnable) .. " s=" .. e.s .. " fluides=" .. e.fluides_in .. " machines=" .. ms .. " " .. tostring(e.texte)) or "absente")
      local pm = placed["fo-ind-jetable-machine"]
      local okset = pm and pm.valid and pcall(function() pm.set_recipe("fo-ind-jetable-noyau") end)
      ctx.check(okset and pm.get_recipe() ~= nil and pm.get_recipe().name == "fo-ind-jetable-noyau",
        "copie jetable : la machine inventée est posée et accepte la recette inventée")
      ctx.check(kit.bras == "fo-ind-jetable-bras", "copie jetable : le bras inventé (une plaque) est le bras le moins cher du kit", tostring(kit.bras))
    end
  end,
}
