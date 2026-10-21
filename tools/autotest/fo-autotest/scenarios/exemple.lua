-- Exemple de SCÉNARIO GREFFÉ (format : tools/autotest/README.md). Lancement : « 600 exemple » dans
-- <racine>\fo-autotest-params.txt, puis fo-autotest.bat ; captures : fo-captures.bat exemple.
-- Base témoin minimale : une machine d'assemblage 2, alimentée sans poteau visible, qui fabrique des engrenages.
local X, Y = 216.5, 216.5

return {
  description = "exemple : machine d'assemblage temoin qui fabrique des engrenages",
  base = nil,          -- ou le nom d'un scénario intégré à préparer d'abord (ex. "pteam" : guerre + équipe)
  check_tick = 300,    -- tick de `finish` puis du BILAN (le banc doit durer au moins autant)

  init = function(ctx) -- on_init, pendant la création de la carte (--create)
    local s = ctx.surface()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    ctx.prepare_area(X - 16, Y - 16, X + 16, Y + 16, "grass-1")
    local m = s.create_entity({ name = "assembling-machine-2", position = { X, Y }, force = "player" })
    if m then
      m.set_recipe("iron-gear-wheel")
      m.insert({ name = "iron-plate", count = 100 })
    end
    ctx.power(X, Y)
    local st = ctx.state()
    st.pos, st.working = m and m.position, 0
    ctx.check(m ~= nil, "machine temoin posee")
    ctx.check(ctx.has("factorio-overhaul", "levels_status"), "interface distante du mod disponible")
  end,

  tick = function(ctx, e) -- chaque tick (banc sans images ET session visuelle)
    if e.tick % 60 ~= 0 then return end
    local st = ctx.state()
    local m = st.pos and ctx.surface().find_entity("assembling-machine-2", st.pos)
    if m and m.status == defines.entity_status.working then st.working = st.working + 1 end
  end,

  finish = function(ctx) -- au tick check_tick ; le BILAN [FO-EXEMPLE] suit automatiquement
    local st = ctx.state()
    local m = st.pos and ctx.surface().find_entity("assembling-machine-2", st.pos)
    ctx.check(m and m.products_finished > 0, "la machine temoin a fabrique des engrenages", m and m.products_finished)
    ctx.check(st.working >= 3, "machine au travail (un echantillon par seconde)", st.working)
    local status = ctx.call("levels_status", "player")
    ctx.check(type(status) == "table", "appel distant levels_status", status and ("centre niveau " .. tostring(status.cc_level)))
  end,

  shots = function(ctx, add) -- facultatif : captures de la session visuelle (fo-captures.bat exemple)
    local st = ctx.state()
    if not st.pos then return end
    add("machine-temoin-jour", st.pos.x, st.pos.y - 0.5, 2, 0)
    add("machine-temoin-nuit", st.pos.x, st.pos.y - 0.5, 2, 0.5)
  end,
}
