--[[
  Lot BRIQUES (2/11) : preuve CIBLEE en moteur reel du partage des fours du QG, avec la regle ET sans elle (même code, l'interrupteur de
  banc `fo-ia1` set_regle_partage(« player », vrai ou faux) ; faux = le comportement de 0.6.37).

  Constat (fo-logs/2026-11-02_BRIQUES/RAPPORT.md) : les briques du centre n'avaient jamais de four. Deux causes, mesurees par le journal
  [FO-BRIQUES] sur 3 factions :
    « monopole » : tous les fours du QG fondent de l'acier, completes au tiers de leur pile par la demande d'acier, jamais vides : la tournee
                   de briques est refusee (« fours-occupes ») ; 35 a 50 min sans une brique, pierre 2 000 a 10 000 au coffre.
    « bloque »   : quatre fours charges de pierre, une plaque d'acier restee en sortie (statut full_output) : arretes pour toujours, la
                   sortie (4 plaques) est sous le seuil de tournee (10) ; briques constantes 50 min.
  Equipe du joueur (8 PNJ), 4 fours poses au QG (bench_smelters), coffre garni (plaques de fer, pierre, charbon), demande de fonte imposee
  (fo-ia1 bench_smelt_demand) : « monopole » = acier permanent + briques ; « bloque » = briques seules. Mesure pendant 5 min a partir du
  tick 600 : briques et acier produits (statistiques de production), etat des fours chaque minute.

  Journal : [FO-BRIQUES-MONOPOLE|BLOQUE, suffixe -TEMOIN] ; ligne « RESULTAT » en cle=valeur.
  Lancement : banc.py --qui BRIQUES -- 22000 briques-monopole <source>   (3 scenarios freres : -temoin, briques-bloque, briques-bloque-temoin).
]]

local MIN = 3600
local W0 = 3000          -- les fours sont arranges et la demande imposee a ce tick (apres la mise en route de l'equipe)
local WINDOW = 5 * MIN
local CHECK = W0 + WINDOW + 100

local function chest_of(ctx)
  return ctx.surface().find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
end

local function furnaces_of(ctx, hq)
  local list = ctx.surface().find_entities_filtered({ name = "stone-furnace", force = "player", position = hq, radius = 30 })
  table.sort(list, function(a, b) return a.unit_number < b.unit_number end)
  return list
end

local function state_text(list)
  local parts = {}
  for _, e in ipairs(list) do
    if e.valid then
      local src = e.get_inventory(defines.inventory.furnace_source)[1]
      local out = e.get_output_inventory()
      local o = {}
      for name, n in pairs(out.get_contents()) do o[#o + 1] = name .. n end
      table.sort(o)
      parts[#parts + 1] = string.format("[%s %s %s]", (src and src.valid_for_read) and (src.name .. src.count) or "vide",
        table.concat(o, "+"), tostring(e.status))
    end
  end
  return table.concat(parts, " ")
end

return function(mode, rule)
  return {
    description = string.format("BRIQUES (%s) : %s, fenetre de 5 min", mode,
      rule and "partage des fours ALLUME" or "TEMOIN (regle coupee : comportement de 0.6.37)"),
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local st = ctx.state()
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local s = ctx.surface()
      local c0 = game.forces.player.get_spawn_position(s)
      local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
      local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      local inv = chest.get_inventory(defines.inventory.chest)
      inv.insert({ name = "coal", count = 400 })
      inv.insert({ name = "stone", count = 800 })
      inv.insert({ name = "iron-plate", count = mode == "monopole" and 3000 or 100 })
      local v = ctx.remote("fo-ia1", "set_regle_partage", "player", rule)
      ctx.check(v == rule, "interrupteur de la regle : " .. (rule and "allumee" or "coupee"), tostring(v))
      local placed = ctx.remote("fo-ia1", "bench_smelters", "player", 4)
      ctx.check(placed == 4, "4 fours poses au QG", tostring(placed))
      st.hq = { x = chest.position.x, y = chest.position.y }
      local list = furnaces_of(ctx, chest.position)
      ctx.check(#list == 4, "4 fours trouves", tostring(#list))
      st.n_fours = #list
      -- Le moteur refuse d'inserer une matiere dont aucune recette n'est ouverte : l'acier (recherche) est ouvert pour le banc.
      game.forces.player.recipes["steel-plate"].enabled = true
      ctx.log("depart : " .. state_text(list))
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.hq or e.tick < 10 then return end
      local stats = game.forces.player.item_production_statistics
      if e.tick == W0 then
        local list = furnaces_of(ctx, st.hq)
        local put = {}
        for _, f in ipairs(list) do
          f.get_inventory(defines.inventory.furnace_source).clear()
          f.get_output_inventory().clear()
          if mode == "monopole" then
            put[#put + 1] = f.get_inventory(defines.inventory.furnace_source).insert({ name = "iron-plate", count = 40 })
          else
            -- Le cas mesure (azure) : une fabrication d'acier est EN COURS (ses 5 plaques sont consommees, la case d'entree est vide),
            -- la tournee charge de la pierre dans le four « vide » ; l'acier termine, sa plaque bloque la sortie.
            put[#put + 1] = f.get_inventory(defines.inventory.furnace_source).insert({ name = "iron-plate", count = 5 })
          end
          if f.get_fuel_inventory().get_item_count("coal") < 20 then f.get_fuel_inventory().insert({ name = "coal", count = 20 }) end
        end
        local demand = mode == "monopole" and { ["steel-plate"] = 100000, ["stone-brick"] = 200 } or { ["stone-brick"] = 200 }
        ctx.check(ctx.remote("fo-ia1", "bench_smelt_demand", "player", demand, mode ~= "monopole") == true, "demande de fonte imposee")
        ctx.log("arrangement : insertions " .. table.concat(put, " ") .. " | " .. state_text(list))
        st.t0 = e.tick
        st.brick0 = stats.get_input_count("stone-brick")
        st.steel0 = stats.get_input_count("steel-plate")
        st.mod0 = ctx.remote("fo-ia1", "smelt_stats", "player") or {}
      end
      if mode == "bloque" and e.tick == W0 + 60 then
        local n = 0
        for _, f in ipairs(furnaces_of(ctx, st.hq)) do
          local src = f.get_inventory(defines.inventory.furnace_source)
          if src.is_empty() then n = n + src.insert({ name = "stone", count = 18 }) end
        end
        ctx.log("pierre chargee dans les fours a case vide (acier en cours) : " .. n)
      end
      if st.t0 and e.tick > W0 and (e.tick - W0) % MIN == 0 and e.tick <= W0 + WINDOW then
        local list = furnaces_of(ctx, st.hq)
        ctx.log(string.format("minute %d | briques %d, acier %d | fours %s", math.floor((e.tick - W0) / MIN),
          stats.get_input_count("stone-brick") - st.brick0, stats.get_input_count("steel-plate") - st.steel0, state_text(list)))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      if not st.t0 then
        ctx.check(false, "la mesure a commence", "tick " .. tostring(CHECK))
        return
      end
      local stats = game.forces.player.item_production_statistics
      local bricks = stats.get_input_count("stone-brick") - st.brick0
      local steel = stats.get_input_count("steel-plate") - st.steel0
      local mod = ctx.remote("fo-ia1", "smelt_stats", "player") or {}
      local m0 = st.mod0 or {}
      local chest = chest_of(ctx)
      local inv = chest and chest.valid and chest.get_inventory(defines.inventory.chest)
      local in_chest = inv and inv.get_item_count("stone-brick") or 0
      ctx.log(string.format("RESULTAT mode=%s regle=%s briques=%d acier=%d briques_coffre=%d visites=%d a_vide=%d fours_repris=%d fours=%d",
        mode, tostring(rule), bricks, steel, in_chest, (mod.visits or 0) - (m0.visits or 0), (mod.empty or 0) - (m0.empty or 0),
        (mod.freed or 0) - (m0.freed or 0), st.n_fours or 0))
      ctx.check(mod.rule ~= nil, "l'etat de la fonderie est lu", tostring(mod.rule))
      if rule then
        ctx.check(bricks >= 20, "des briques sont fondues pour la demande (regle allumee)", tostring(bricks))
        if mode == "monopole" then
          ctx.check(steel >= 1, "l'acier n'est pas affame : au moins une fabrication", tostring(steel))
          ctx.check((mod.freed or 0) - (m0.freed or 0) >= 1, "un four a ete repris a l'acier", tostring(mod.freed))
        end
      elseif mode == "monopole" then
        ctx.check(steel >= 1, "temoin : l'acier se fond (sanity)", tostring(steel))
      end
    end,
  }
end
