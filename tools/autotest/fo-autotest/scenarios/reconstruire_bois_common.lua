--[[
  Lot CORR-RECONSTRUIRE (micro-banc, preuve CIBLÉE de la remarque 2 du DC) : des poteaux posés à la main sont détruits alors que
  le coffre d'équipe n'a NI bois NI acier NI poteau tout fait (le bois de départ est épuisé : constat de 555555555, un poteau a attendu
  jusqu'à 32 min), et des arbres poussent à ~25 tuiles.
  Deux poteaux détruits à 600 ticks par die() (comme une attaque) : un petit (le bois manque) et un moyen (l'acier manque : il faut
  le petit poteau à la place). Règle : l'équipe coupe du bois, fabrique le petit poteau et refait les deux à leur place exacte.
  « avec » (reconstruire-bois) : règle allumée, les deux poteaux sont refaits en moins de 2 min ;
  « sans » (reconstruire-bois-sans) : MÊME code, règle coupée par l'interface fo-recon (set_gather false) : AUCUN poteau refait.
  Mesures : ticks de la destruction à chaque reconstruction, bois au coffre, journal [FO-RECON].
  Lancement : banc.py -- 9300 reconstruire-bois <source>   puis   9300 reconstruire-bois-sans <source>.
]]

return function(with_rule)
  local HALF = 90
  local DEADLINE = 7200 -- 2 min
  local TAG = with_rule and "[FO-RECONSTRUIRE-BOIS] " or "[FO-RECONSTRUIRE-BOIS-SANS] "
  local PLANT = {
    { "small-electric-pole", 10, 10 }, { "small-electric-pole", 14, 10 }, { "medium-electric-pole", 18, 10 },
    { "medium-electric-pole", 22, 10 }, { "small-electric-pole", 26, 10 },
  }

  local function tree_name()
    local names = {}
    for name in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "tree" } })) do names[#names + 1] = name end
    table.sort(names)
    for _, n in ipairs(names) do
      for _, p in ipairs(game.entity_prototypes[n].mineable_properties.products or {}) do
        if p.name == "wood" then return n end
      end
    end
    return names[1]
  end

  return {
    description = "CORR-RECONSTRUIRE : poteaux detruits sans bois ni acier, arbres a portee : "
      .. (with_rule and "recolte du bois (regle allumee)" or "regle coupee (temoin)"),
    check_tick = 9000,

    init = function(ctx)
      local s = ctx.surface()
      local st = ctx.state()
      local c = { x = 0, y = 0 }
      s.request_to_generate_chunks({ c.x, c.y }, 4)
      s.force_generate_chunk_requests()
      local area = { { c.x - HALF, c.y - HALF }, { c.x + HALF, c.y + HALF } }
      for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
        if e.valid then e.destroy() end
      end
      local tiles = {}
      for y = c.y - HALF, c.y + HALF - 1 do for x = c.x - HALF, c.x + HALF - 1 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
      s.set_tiles(tiles, true)
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local chest = s.create_entity({ name = "fo-team-chest", position = { c.x + 0.5, c.y + 0.5 }, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      -- Stock : du fer et du cuivre, AUCUN bois, AUCUN acier, AUCUN poteau tout fait.
      for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 200 }, { "stone", 100 }, { "coal", 200 },
          { "pistol", 10 }, { "firearm-magazine", 100 }, { "iron-gear-wheel", 40 } }) do
        chest.insert({ name = it[1], count = it[2] })
      end
      -- Des arbres a 20-30 tuiles du coffre (aucun nid : la carte est nettoyee)
      local tn = tree_name()
      ctx.check(tn ~= nil, "un arbre qui donne du bois existe", tn)
      local planted = 0
      for i = 0, 11 do
        local x, y = c.x + 22 + (i % 4) * 2, c.y + 18 + math.floor(i / 4) * 2
        if tn and s.create_entity({ name = tn, position = { x, y } }) then planted = planted + 1 end
      end
      ctx.check(planted >= 8, "arbres plantes pres du coffre", planted)
      st.ents = {}
      for _, p in ipairs(PLANT) do
        local e = s.create_entity({ name = p[1], position = { p[2] + 0.5, p[3] + 0.5 }, force = "player", raise_built = true })
        ctx.check(e ~= nil, "pose de " .. p[1], p[1])
        st.ents[#st.ents + 1] = { name = p[1], x = e and e.position.x or p[2], y = e and e.position.y or p[3] }
      end
      st.t0 = game.tick
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.t0 then return end
      local t = e.tick - st.t0
      local s = ctx.surface()
      -- Le reglage est LOCAL au jeu en cours (hors sauvegarde) : repose toutes les 300 ticks, bien avant la premiere decision (t = 780).
      if e.tick % 300 == 0 then
        local got = ctx.remote("fo-recon", "set_gather", with_rule)
        if not st.sw_checked then
          st.sw_checked = true
          ctx.check(got == with_rule, "regle " .. (with_rule and "allumee" or "coupee"))
        end
      end
      if t == 600 and not st.killed then
        st.killed = t
        st.status0 = ctx.remote("fo-recon", "status", "player")
        st.targets = { st.ents[2], st.ents[3] } -- un petit et un moyen
        for _, tg in ipairs(st.targets) do
          local real = s.find_entity(tg.name, { tg.x, tg.y })
          if real and real.valid then real.die("enemy") end
        end
        ctx.log(TAG .. "destruction de 2 poteaux (petit et moyen) a " .. t .. " ticks, aucun bois ni acier au coffre")
      end
      if st.killed and t > st.killed and t % 30 == 0 then
        st.done = st.done or {}
        for i, tg in ipairs(st.targets) do
          if not st.done[i] then
            local real = s.find_entity(tg.name, { tg.x, tg.y })
            if real and real.valid and real.force.name == "player" then
              st.done[i] = t - st.killed
              ctx.log(string.format("%s%s refait %d ticks (%.1f s) apres la destruction", TAG, tg.name, t - st.killed, (t - st.killed) / 60))
            end
          end
        end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local final = ctx.remote("fo-recon", "status", "player")
      ctx.check(st.killed ~= nil and #(st.targets or {}) == 2, "2 poteaux detruits par die()")
      ctx.check(final ~= nil and final.recorded - (st.status0 and st.status0.recorded or 0) == 2, "chaque poteau detruit est inscrit au registre", final and final.recorded)
      local n = 0
      for i = 1, 2 do if st.done and st.done[i] then n = n + 1 end end
      ctx.log(string.format("%sFAIT poteaux refaits : %d sur 2 (petit %s, moyen %s) ; registre : %s", TAG, n, tostring(st.done and st.done[1]),
        tostring(st.done and st.done[2]), final and string.format("%d refaite(s), %d tache(s)", final.rebuilt, final.tasks) or "?"))
      if with_rule then
        ctx.check(n == 2, "les deux poteaux sont refaits a leur place exacte (bois coupe, petit poteau fabrique)", n)
        ctx.check(n == 2 and st.done[1] <= DEADLINE and st.done[2] <= DEADLINE, "reconstruction en moins de " .. DEADLINE .. " ticks")
      else
        ctx.check(n == 0, "regle coupee : aucun poteau refait faute de bois (comportement d'avant)", n)
      end
    end,
  }
end
