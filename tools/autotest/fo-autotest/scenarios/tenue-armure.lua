-- Scénario greffé du lot TENUE (2/11) : la FORMULE des résistances du moteur, mesurée (LuaEntity.damage rend les dégâts réellement
-- appliqués après résistances). Sert de fixture à tests/tenue_test.lua (Pv.hit) : le modèle de défense de la prévision lisait des dégâts
-- nominaux, sans résistances (un coup de 5 contre un biter moyen à -4 plats et 10 % ne fait pas 5).
--   & "<racine>\fo-autotest.bat" nopause 120 tenue-armure "<source>"
-- Journal : « [FO-TENUE-ARMURE] M <unité> <type> d=<coup> plat=<lu> pct=<lu> rendu=<dégâts appliqués> » ; les valeurs plat/pct sont celles
-- de LuaEntityPrototype.resistances, lues telles quelles (pct est-il une fraction ou un pourcentage ? c'est ce que la mesure dit).
local X0, Y0 = 2600, 3000
local UNITES = { "small-biter", "medium-biter", "big-biter", "behemoth-biter", "small-spitter", "medium-spitter", "big-spitter",
  "behemoth-spitter" }
local TYPES = { "physical", "explosion", "fire" }
local COUPS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20, 30, 50 }

return {
  description = "TENUE-ARMURE : formule des resistances du moteur (degats appliques apres resistances)",
  base = nil,
  check_tick = 60,

  init = function(ctx)
    local s = ctx.surface()
    ctx.prepare_area(X0 - 10, Y0 - 10, X0 + 10, Y0 + 10, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    local st = ctx.state()
    st.mesures, st.vus = 0, 0
    for _, nom in ipairs(UNITES) do
      local p = game.entity_prototypes[nom]
      if p then
        st.vus = st.vus + 1
        local res = p.resistances or {}
        local pv = p.max_health
        for _, ty in ipairs(TYPES) do
          local r = res[ty]
          local plat, pct = r and r.decrease or 0, r and r.percent or 0
          for _, d in ipairs(COUPS) do
            -- une unité neuve par coup (les PV ne comptent pas : on ne mesure que les coups qui ne la tuent pas)
            if d * 1.0 < pv * 0.9 then
              local u = s.create_entity({ name = nom, position = { X0, Y0 }, force = "enemy" })
              if u then
                local rendu = u.damage(d, game.forces.player, ty)
                log(string.format("[FO-TENUE-ARMURE] M %s %s d=%s plat=%s pct=%s rendu=%s", nom, ty, d, plat, pct, rendu))
                st.mesures = st.mesures + 1
                u.destroy()
              end
            end
          end
        end
      end
    end
    ctx.check(st.vus >= 6, "unites ennemies lues aux prototypes", st.vus .. " / " .. #UNITES)
    ctx.check(st.mesures >= 200, "coups mesures", tostring(st.mesures))
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.mesures >= 200, "mesures gardees", tostring(st.mesures))
  end,
}
