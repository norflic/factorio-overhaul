--[[
  Lot FOURS (29/10) : remarques 12 et 13 du DC (D-26), preuve CIBLÉE en moteur réel, avec la règle ET sans elle (même code,
  l'interrupteur de banc `fo-ia1` set_regle_four(« player », vrai ou faux) ; faux = le comportement de 0.6.10).

  « refill » : « quand un agent refill un four, en charbon ou en ressource à fondre, en mettre un max pour éviter de passer
  toutes les 2 minutes ». Votre équipe de 8 PNJ, 4 fours posés au QG (bench_smelters), coffre garni de minerai de fer (1 200) et
  de charbon (300), AUCUNE plaque : la demande de plaques est permanente (le banc retire les plaques du coffre au-delà de 20,
  toutes les 5 s : une consommation forte). Mesure pendant 5 min à partir du tick 600, par ÉCHANTILLON tous les 5 ticks des fours
  eux-mêmes (indépendant du mod) : un « passage de refill » d'un four = une hausse de son entrée ou de son combustible (deux hausses
  à moins de 60 ticks l'une de l'autre = un seul passage) ; secondes sans entrée, secondes sans combustible ; plaques fondues
  (statistiques de production). Compteurs du mod : visites de la fonderie, dont « à vide » (rien chargé, vidé ni ravitaillé).

  « mains » (courant coupé) : « minage à la main sans fonte quand l'électricité est coupée (les workers minent le fer à la main, le
  laissent non fondu...) ». Même équipe et mêmes fours, coffre SANS minerai ni plaque, gisement de fer à 40 tuiles : aucun avant-poste
  ni courant, seul le minage à la main alimente la fonte, pendant 10 min. Les tournées de fonte « à vide » (compteur du mod) et le
  minerai porté ou gardé sont lus.

  Lecture comparée (avec / sans) : tools/autotest/fours_mesures.py. Journal : [FO-FOURS-REFILL|MAINS, suffixe -TEMOIN] ; ligne
  « RESULTAT » en clé=valeur.
  Lancement : banc.py --out <archive> --qui FOURS -- 19000 fours-refill <source>   (3 scénarios frères : -temoin ; 37000 ticks
  pour fours-mains et fours-mains-temoin).
]]

local MIN = 3600
local W0 = 600           -- début de la mesure
local STEP = 5           -- échantillon des fours
local MERGE = 60         -- deux hausses à moins de 60 ticks = un passage
local KEEP_PLATES = 20   -- plaques gardées au coffre (refill) : le reste est consommé par le banc

local function patch(s, name, c, r, amount)
  for _, e in ipairs(s.find_entities_filtered({ position = c, radius = r + 2 })) do
    if e.valid and e.type ~= "character" and e.name ~= "fo-team-chest" then e.destroy() end
  end
  local n = 0
  for dx = -r, r do
    for dy = -r, r do
      if dx * dx + dy * dy <= r * r then
        s.create_entity({ name = name, position = { c.x + dx, c.y + dy }, amount = amount })
        n = n + 1
      end
    end
  end
  return n
end

local function chest_of(ctx)
  local st = ctx.state()
  local s = ctx.surface()
  local c = s.find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
  return c, st
end

return function(kind, rule)
  local TAG = "FOURS-" .. string.upper(kind) .. (rule and "" or "-TEMOIN")
  local WINDOW = (kind == "refill" and 5 or 10) * MIN
  local CHECK = W0 + WINDOW + 100
  return {
    description = string.format("FOURS (%s) : %s, fenetre de %d min", kind,
      rule and "regle de charge a la pile et tournee utile ALLUMEE" or "TEMOIN (regle coupee : comportement de 0.6.10)", WINDOW / MIN),
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local st = ctx.state()
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local s = ctx.surface()
      local c0 = game.forces.player.get_spawn_position(s)
      local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
      local hq = { x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.5 }
      local n_fe = patch(s, "iron-ore", { x = hq.x + 40, y = hq.y }, 5, 3000)
      local n_c = patch(s, "coal", { x = hq.x, y = hq.y + 45 }, 5, 3000)
      local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose", string.format("gisements fer %d, charbon %d tuiles", n_fe, n_c))
      if not chest then return end
      local inv = chest.get_inventory(defines.inventory.chest)
      local coal = inv.insert({ name = "coal", count = 300 })
      local ore = kind == "refill" and inv.insert({ name = "iron-ore", count = 1200 }) or 0
      local v = ctx.remote("fo-ia1", "set_regle_four", "player", rule)
      ctx.check(v == rule, "interrupteur de la regle : " .. (rule and "allumee" or "coupee"), tostring(v))
      local placed = ctx.remote("fo-ia1", "bench_smelters", "player", 4)
      ctx.check(placed == 4, "4 fours poses au QG", tostring(placed))
      st.hq = { x = chest.position.x, y = chest.position.y }
      st.furn = {}
      for _, e in ipairs(s.find_entities_filtered({ name = "stone-furnace", force = "player", position = chest.position, radius = 30 })) do
        st.furn[#st.furn + 1] = { u = e.unit_number, last_in = 0, last_fuel = 0, last_pass = -1000, passes = 0, load_in = 0, load_fuel = 0 }
      end
      table.sort(st.furn, function(a, b) return a.u < b.u end)
      st.dry_in, st.dry_fuel, st.samples = 0, 0, 0
      st.removed = 0
      st.t0 = nil
      ctx.log(string.format("depart : coffre en %.1f,%.1f ; minerai %d, charbon %d ; %d four(s) ; regle %s", hq.x, hq.y, ore, coal,
        #st.furn, rule and "allumee" or "COUPEE"))
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.hq or e.tick < 10 then return end
      local s = ctx.surface()
      local t = e.tick
      -- Consommation du banc (refill) : les plaques du coffre au-delà de KEEP_PLATES sont retirées toutes les 5 s.
      if kind == "refill" and t % 300 == 0 then
        local chest = chest_of(ctx)
        if chest and chest.valid then
          local inv = chest.get_inventory(defines.inventory.chest)
          local n = inv.get_item_count("iron-plate")
          if n > KEEP_PLATES then st.removed = st.removed + inv.remove({ name = "iron-plate", count = n - KEEP_PLATES }) end
        end
      end
      if t == W0 then
        st.t0 = t
        st.prod0 = game.forces.player.item_production_statistics.get_input_count("iron-plate")
        st.mod0 = ctx.remote("fo-ia1", "smelt_stats", "player")
        st.removed0 = st.removed
        for _, f in ipairs(st.furn) do f.passes, f.load_in, f.load_fuel, f.last_pass = 0, 0, 0, -1000 end
        -- état de départ des fours (la hausse suivante est un passage)
        for _, f in ipairs(st.furn) do
          local ent = nil
          for _, x in ipairs(s.find_entities_filtered({ name = "stone-furnace", force = "player", position = st.hq, radius = 30 })) do
            if x.unit_number == f.u then ent = x end
          end
          f.ent = ent
          f.last_in = ent and ent.get_inventory(defines.inventory.furnace_source).get_item_count() or 0
          f.last_fuel = ent and ent.get_fuel_inventory().get_item_count() or 0
        end
      end
      if not st.t0 or t < W0 or t > W0 + WINDOW or t % STEP ~= 0 then return end
      st.samples = st.samples + 1
      local any_in, any_fuel = false, false
      for _, f in ipairs(st.furn) do
        local ent = f.ent
        if ent and ent.valid then
          local n_in = ent.get_inventory(defines.inventory.furnace_source).get_item_count()
          local n_fuel = ent.get_fuel_inventory().get_item_count()
          local up = false
          if n_in > f.last_in then f.load_in = f.load_in + 1; up = true; any_in = true end
          if n_fuel > f.last_fuel then f.load_fuel = f.load_fuel + 1; up = true; any_fuel = true end
          if up then
            if t - f.last_pass > MERGE then f.passes = f.passes + 1 end
            f.last_pass = t
          end
          f.last_in, f.last_fuel = n_in, n_fuel
          local status = ent.status
          if status == defines.entity_status.no_ingredients then st.dry_in = st.dry_in + STEP end
          if status == defines.entity_status.no_fuel then st.dry_fuel = st.dry_fuel + STEP end
        end
      end
      if (t - W0) % MIN == 0 then
        local chest = chest_of(ctx)
        local inv = chest and chest.valid and chest.get_inventory(defines.inventory.chest)
        local passes = 0
        for _, f in ipairs(st.furn) do passes = passes + f.passes end
        local mod = ctx.remote("fo-ia1", "smelt_stats", "player") or {}
        ctx.log(string.format("minute %d | passages %d | secondes sans entree %.0f, sans combustible %.0f | coffre minerai %d plaques %d charbon %d | visites du mod %d (a vide %d)",
          math.floor((t - W0) / MIN), passes, st.dry_in / 60, st.dry_fuel / 60, inv and inv.get_item_count("iron-ore") or 0,
          inv and inv.get_item_count("iron-plate") or 0, inv and inv.get_item_count("coal") or 0,
          (mod.visits or 0) - ((st.mod0 and st.mod0.visits) or 0), (mod.empty or 0) - ((st.mod0 and st.mod0.empty) or 0)))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      if not st.t0 then
        ctx.check(false, "la mesure a commence", "tick " .. tostring(CHECK))
        return
      end
      local s = ctx.surface()
      local passes, load_in, load_fuel = 0, 0, 0
      for _, f in ipairs(st.furn) do
        passes = passes + f.passes
        load_in = load_in + f.load_in
        load_fuel = load_fuel + f.load_fuel
      end
      local mod = ctx.remote("fo-ia1", "smelt_stats", "player") or {}
      local m0 = st.mod0 or {}
      local d = function(k) return (mod[k] or 0) - (m0[k] or 0) end
      local made = game.forces.player.item_production_statistics.get_input_count("iron-plate") - st.prod0
      -- minerai porté par les PNJ et gardé au coffre et dans les fours à la fin
      local carried = 0
      for _, c in ipairs(s.find_entities_filtered({ type = "character", force = "player" })) do
        if c.valid then
          local inv = c.get_main_inventory()
          carried = carried + (inv and inv.get_item_count("iron-ore") or 0)
        end
      end
      local chest = chest_of(ctx)
      local inv = chest and chest.valid and chest.get_inventory(defines.inventory.chest)
      local chest_ore = inv and inv.get_item_count("iron-ore") or 0
      local in_furn = 0
      for _, f in ipairs(st.furn) do
        if f.ent and f.ent.valid then in_furn = in_furn + f.ent.get_inventory(defines.inventory.furnace_source).get_item_count() end
      end
      ctx.log(string.format("RESULTAT passages=%d charges_entree=%d charges_combustible=%d visites=%d visites_a_vide=%d charge_mod=%d vide_mod=%d collecte_mod=%d charbon_mod=%d plaques=%d sec_sans_entree=%.0f sec_sans_combustible=%.0f minerai_porte=%d minerai_coffre=%d minerai_fours=%d fours=%d minutes=%d",
        passes, load_in, load_fuel, d("visits"), d("empty"), d("loaded"), d("empty"), d("collected"), d("fueled"), made,
        st.dry_in / 60, st.dry_fuel / 60, carried, chest_ore, in_furn, #st.furn, math.floor(WINDOW / MIN)))
      ctx.check(#st.furn == 4, "4 fours suivis", tostring(#st.furn))
      ctx.check(st.samples >= WINDOW / STEP - 2, "la fenetre complete est echantillonnee", tostring(st.samples))
      ctx.check(made > 0, "des plaques ont ete fondues dans la fenetre", tostring(made))
      ctx.check(mod.rule == rule, "l'interrupteur tient jusqu'a la fin", tostring(mod.rule))
      if kind == "refill" then
        ctx.check(passes >= 1, "le scenario provoque des passages de refill", tostring(passes))
        if rule then
          -- Absolu (la comparaison avec le temoin est faite par fours_mesures.py) : les fours se remplissent a la pile.
          ctx.check(load_in >= 1, "les fours sont charges", tostring(load_in))
        end
      else
        ctx.check(d("visits") >= 0, "visites de fonderie lues", tostring(d("visits")))
        if rule then
          ctx.check(d("empty") == 0, "aucune tournee de fonte a vide (courant coupe, minage a la main)", tostring(d("empty")))
        end
      end
    end,
  }
end
