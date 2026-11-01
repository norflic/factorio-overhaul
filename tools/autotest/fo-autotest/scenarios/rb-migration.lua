-- Scénario greffé du lot RB-1 CHAÎNE (31/10) : MIGRATION d'une sauvegarde d'AVANT le lot (aucun robot, aucun espace de stockage
-- « robots ») rechargée par la version du lot. DOUBLE SOURCE obligatoire :
--   py -3.9 -B tools/autotest/banc.py --out <archive> --creation "<racine>/fo-logs/2026-10-30_CALCUL-V2/src-0.6.27/factorio-overhaul" \
--     --qui RB1 -- 1500 rb-migration <source du lot>
-- Création (0.6.27) : une zone plate et alimentée, une partie de guerre, rien du lot. Benchmark (lot) :
--   - l'espace « robots » est créé par on_configuration_changed (interface fo-robots répond, registre cohérent et vide) ;
--   - un atelier posé APRÈS le chargement fabrique un kit et le balayage en fait un robot (la chaîne marche sur une carte migrée) ;
--   - la guerre de la création continue (des factions vivent).
-- Journal : [FO-RB-MIGRATION].

local X0, Y0 = 1500, 1500
local CHECK = 1400

local function R(ctx, fn, ...) return ctx.remote("fo-robots", fn, ...) end

return {
  description = "RB-1 : migration d'une sauvegarde sans robots (double source), atelier pose apres le chargement",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    st.version_create = script.active_mods["factorio-overhaul"]
    st.create_has_robots = remote.interfaces["fo-robots"] ~= nil
    ctx.prepare_area(X0 - 20, Y0 - 20, X0 + 40, Y0 + 40, "grass-1")
    for _, e in ipairs(ctx.surface().find_entities_filtered({ force = "enemy", area = { { X0 - 120, Y0 - 120 }, { X0 + 140, Y0 + 140 } } })) do e.destroy() end
    ctx.power(X0 + 10, Y0)
    if remote.interfaces["fo-pvp"] then remote.call("fo-pvp", "set_difficulty", "peaceful") end
    st.war = remote.call("factorio-overhaul", "war_start", 1, 30, 4)
    ctx.log("creation : factorio-overhaul " .. tostring(st.version_create) .. ", interface fo-robots " .. tostring(st.create_has_robots)
      .. ", guerre " .. tostring(st.war))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == 30 then
      local etat = R(ctx, "state", "player")
      local ok_ledger = R(ctx, "check")
      ctx.check(not st.create_has_robots and etat ~= nil and etat.used == 0 and #etat.units == 0 and etat.workshops == 0 and ok_ledger == true,
        "migration : la carte creee sans le lot a maintenant l'espace robots, vide et coherent",
        string.format("interface a la creation %s, etat %s, ateliers %s, registre %s", tostring(st.create_has_robots), etat and "present" or "absent",
          tostring(etat and etat.workshops), tostring(ok_ledger)))
      -- un atelier posé après le chargement, garni comme par un coffre et un bras par ingrédient
      local w = s.create_entity({ name = "fo-robot-workshop", position = { X0 + 0.5, Y0 + 0.5 }, force = "player", raise_built = true })
      if w then w.set_recipe("fo-robot-make-steam-trotter") end
      st.w = w
      for i, ing in ipairs({ { "engine-unit", 20 }, { "steel-plate", 44 } }) do
        local x = X0 + 0.5 - 1 + (i - 1) * 2
        local c = s.create_entity({ name = "steel-chest", position = { x, Y0 - 2.5 }, force = "player" })
        c.insert({ name = ing[1], count = ing[2] })
        local b = s.create_entity({ name = "fast-inserter", position = { x, Y0 - 1.5 }, force = "player" })
        b.pickup_position = { x, Y0 - 2.5 }
        b.drop_position = { x, Y0 - 0.5 }
      end
      ctx.check(w ~= nil and R(ctx, "state", "player").workshops == 1, "migration : l'atelier pose apres le chargement est suivi")
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local etat = R(ctx, "state", "player")
    local w = st.w
    ctx.check(etat and etat.stats.created >= 1 and etat.stats.kits_removed >= 1 and w and w.valid and w.products_finished >= 1,
      "migration : l'atelier fabrique un kit et le balayage en fait un robot",
      string.format("creees %s, kits retires %s, fabriques %s, unites %s", tostring(etat and etat.stats.created), tostring(etat and etat.stats.kits_removed),
        tostring(w and w.valid and w.products_finished), tostring(etat and #etat.units)))
    local rows = ctx.remote("fo-ia1", "teams") or {}
    ctx.check(#rows >= 1, "migration : la guerre de la creation continue (des factions vivent)", tostring(#rows) .. " faction(s)")
    local ok_ledger = R(ctx, "check")
    ctx.check(ok_ledger == true, "migration : registre coherent a la fin")
  end,
}
