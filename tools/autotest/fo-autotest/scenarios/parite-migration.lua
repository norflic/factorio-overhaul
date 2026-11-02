--[[
  Lot PARITE : une partie 0.6.35 (guerre en cours, VOTRE ÉQUIPE déjà lancée, sans tourelle de QG) rechargée par le lot.
  « Une équipe déjà lancée ne reçoit rien d'office » (CRITERES.md P1.6). Double source OBLIGATOIRE :
    FO_CREATE_SRC = `git archive` de main 0.6.35 (89c58400) + feuilles de la mitrailleuse (fo-logs/2026-11-02_PARITE/src-0.6.35) ;
    source = le lot. `banc.py --creation <src-0.6.35> --qui PARITE -- 700 parite-migration <source du lot>`.
  Création (0.6.35) : guerre de banc (war_start 2, 30, 4, aucun coffre d'office) ; coffre d'équipe posé par le banc.
  Benchmark (lot) : l'équipe existe toujours, SANS tourelle de QG ; le coffre retiré puis un coffre refabriqué et posé : l'équipe renaît,
  toujours aucune tourelle offerte. Journal : [FO-PARITE-MIGRATION].
]]
local TAG = "[FO-PARITE-MIGRATION] "

local function player_turrets(s)
  return #s.find_entities_filtered({ name = "gun-turret", force = "player" })
end

return {
  description = "PARITE : partie 0.6.35 avec equipe lancee, rechargee par le lot (double source) : aucun depart offert",
  check_tick = 600,

  init = function(ctx)
    local st = ctx.state()
    st.version_create = script.active_mods["factorio-overhaul"]
    st.war = remote.call("factorio-overhaul", "war_start", 2, 30, 4)
    local s = ctx.surface()
    local c = game.forces.player.get_spawn_position(s)
    local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
    local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
    if chest then chest.insert({ name = "iron-plate", count = 50 }) end
    st.chest_pos = p
    st.turrets_create = player_turrets(s)
    ctx.log(TAG .. string.format("creation : factorio-overhaul %s, guerre %s, coffre %s, tourelles du joueur %d", tostring(st.version_create),
      tostring(st.war), tostring(chest ~= nil), st.turrets_create))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == 60 then
      st.alive60 = ctx.call("team_status") ~= nil
      st.turrets60 = player_turrets(s)
      st.version_bench = script.active_mods["factorio-overhaul"]
      ctx.log(TAG .. string.format("tick 60 : equipe presente %s, tourelles du joueur %d (creation : %s)", tostring(st.alive60), st.turrets60, tostring(st.turrets_create)))
    end
    if e.tick == 120 then
      -- le joueur reprend son coffre (mine) : l'equipe prend fin
      local chest = s.find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
      if chest then chest.destroy() end
      st.ended = ctx.call("team_status") == nil
      ctx.log(TAG .. "tick 120 : coffre retire, equipe terminee " .. tostring(st.ended))
    end
    if e.tick == 180 then
      -- il en refabrique un et le pose : l'equipe renait, le depart n'est pas redonne
      local p = st.chest_pos and s.find_non_colliding_position("fo-team-chest", st.chest_pos, 20, 1)
      st.chest2 = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true }) or nil
      ctx.log(TAG .. "tick 180 : coffre refabrique et pose : " .. tostring(st.chest2 ~= nil))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    ctx.check(st.turrets_create == 0, "creation : l'equipe 0.6.35 n'avait aucune tourelle de QG", st.turrets_create)
    ctx.check(st.alive60 == true, "l'equipe lancee existe toujours apres la montee de version")
    ctx.check(st.turrets60 == 0, "P1.6 montee de version : aucune tourelle offerte a l'equipe deja lancee", st.turrets60)
    ctx.check(st.ended == true, "coffre retire : l'equipe prend fin")
    ctx.check(st.chest2 ~= nil and ctx.call("team_status") ~= nil, "coffre refabrique : l'equipe renait")
    ctx.check(player_turrets(s) == 0, "P1.6 coffre refabrique : toujours aucune tourelle offerte", player_turrets(s))
    ctx.check(st.version_bench ~= nil, "version du bench lue", st.version_bench)
  end,
}
