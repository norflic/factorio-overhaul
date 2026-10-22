--[[
  Scénario GREFFÉ « t4-production » (lot V3-T4) : le greffon checks/levels_production.lua joué SEUL (mêmes mesures
  que dans le banc content : fours, assembleurs, foreuses aux niveaux 1, 6, 7, 30 ; mitrailleuses et lasers 1 et 30),
  plus la POLLUTION par objet, mesurée par les statistiques de pollution du jeu (dans le banc content, d'autres
  greffons font tourner des machines de même nom : la mesure n'y est pas propre). Pollution de la carte activée.
  Correction du lot (E58) : seconde fenêtre de 40 s (ticks 2 760 à 5 160), après la mesure de pollution : assembleur 30
  et foreuses 30 avec modules de vitesse 10 (plafond d'une fabrication par tick, coffre, tapis express), six tourelles
  contre un blindé (formule de résistance du moteur). Zone supplémentaire : (588, 352) à (868, 472).
  Commande : & "<racine>\fo-autotest.bat" nopause 5300 t4-production "<source>" (depuis PowerShell).
  Attendu : « [FO-T4-PRODUCTION] BILAN : 20 OK, 0 ECHEC(S) ». Format : tools/autotest/README.md §4.
]]

local Prod = require("checks/levels_production").module

local ZONE = { x0 = 588, y0 = 240, x1 = 716, y1 = 336 }

local function solo(ctx)
  ctx.zone = ZONE
  ctx.solo = true
  return ctx
end

return {
  description = "V3-T4 : la production suit la surface, mesuree en moteur reel (greffon levels_production seul, pollution comprise)",
  base = nil,
  check_tick = Prod.X1 + 60,

  init = function(ctx)
    solo(ctx)
    game.map_settings.pollution.enabled = true
    ctx.prepare_area(ZONE.x0, ZONE.y0, ZONE.x1, ZONE.y1, "grass-1")
    local foes = 0
    for _, en in ipairs(ctx.surface().find_entities_filtered({ area = { { ZONE.x0 - 64, ZONE.y0 - 64 }, { ZONE.x1 + 64, ZONE.y1 + 64 } }, force = "enemy" })) do
      if en.valid then en.destroy(); foes = foes + 1 end
    end
    ctx.log("ennemis retires autour de la zone : " .. foes)
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    Prod.setup(ctx)
  end,

  tick = function(ctx, e)
    Prod.tick(solo(ctx), e.tick)
  end,

  finish = function(ctx)
    Prod.verify(solo(ctx))
  end,

  shots = function(ctx, add)
    Prod.shots(solo(ctx), add)
  end,
}
