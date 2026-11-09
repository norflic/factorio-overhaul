--[[
  Micro-banc « mall-s2 » du lot MALL : la tenue du débit de S2 contre les vraies statistiques de la force (LuaFlowStatistics). get_flow_count(one_minute) rend ce qui est entré dans la dernière minute :
  le fer reçoit 2 plaques par seconde (au moins 30 en 15 s), le cuivre 1 toutes les 3 s (au plus 20 dans la fenêtre, jamais 30).
  Tenue ramenée à 900 ticks et relecture toutes les secondes par réglage de banc (fo-mall set_param), électricité simulée (force_plant).
  Attendu : le fer ouvre, pas avant sa tenue ; le cuivre n'ouvre jamais ; S2 partiel pendant que le fer coule ; le fer referme après l'arrêt, sous le seuil bas.
  Lancement : py -3.9 -B <banc.py> --out <archive> --qui mall -- 6200 mall-s2 <source>
]]

local TAG = "FO-MALL-S2"
local TENUE = 900
local T_ON, T_OFF = 300, 2400
local SECT = { x0 = 20, y0 = -48, x1 = 84, y1 = 16, dir = 2, ext = 0 }

return {
  description = "MALL : tenue du debit de S2 lue aux statistiques reelles",
  base = nil,
  check_tick = 6100,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    for _, r in ipairs({ "assembling-machine-1", "assembling-machine-2" }) do game.forces.player.recipes[r].enabled = true end
    local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    ctx.check(ctx.call("war_setting", "fo-war-ia3e", false) == false, "reglage fo-war-ia3e coupe")
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 1 }) == true, "plan directeur active")
    ctx.check(ctx.remote("fo-mall", "set_param", "player", "sect", SECT) ~= nil, "secteur impose")
    ctx.check(ctx.remote("fo-mall", "set_param", "player", "force_plant", true) == true, "centrale simulee (banc)")
    ctx.check(ctx.remote("fo-mall", "set_param", "player", "s2_tenue", TENUE) == TENUE, "tenue ramenee a 900 ticks (banc)")
    ctx.check(ctx.remote("fo-mall", "set_param", "player", "etat_every", 60) == 60, "relecture chaque seconde (banc)")
    st.t0 = game.tick
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local t = e.tick - st.t0
    if t % 60 ~= 0 then return end
    local fs = game.forces.player.item_production_statistics
    if t >= T_ON and t < T_OFF then
      fs.on_flow("iron-plate", 2)
      if t % 180 == 0 then fs.on_flow("copper-plate", 1) end
    end
    local rep = ctx.remote("fo-mall", "report", "player")
    if not rep and not st.rep_nil then
      st.rep_nil = t
      ctx.log(string.format("[%s] RAPPORT NIL a t=%d", TAG, t))
    end
    local fe = rep and rep.s2 and rep.s2["iron-plate"]
    local cu = rep and rep.s2 and rep.s2["copper-plate"]
    if fe and fe.since and not st.since_fe then st.since_fe = t; st.since_abs = fe.since end
    if fe and fe.open and not st.open_fe then st.open_fe = t; st.since_at_open = fe.since end
    if cu and cu.open then st.cu_open = t end
    if st.open_fe and rep.partiel then st.partiel_vu = t end
    if st.open_fe and fe and not fe.open and not st.close_fe then st.close_fe = t end
    if t % 600 == 0 then
      ctx.log(string.format("[%s] t=%d fer %.1f/min cuivre %.1f/min | s2 fer since=%s open=%s | cuivre since=%s open=%s | pret=%s partiel=%s", TAG, t,
        fs.get_flow_count({ name = "iron-plate", input = true, precision_index = defines.flow_precision_index.one_minute }),
        fs.get_flow_count({ name = "copper-plate", input = true, precision_index = defines.flow_precision_index.one_minute }),
        tostring(fe and fe.since), tostring(fe and fe.open), tostring(cu and cu.since), tostring(cu and cu.open), tostring(rep and rep.pret), tostring(rep and rep.partiel)))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.rep_nil == nil, "le rapport du mall reste lisible", tostring(st.rep_nil))
    ctx.check(st.since_fe ~= nil and st.since_fe >= T_ON, "la tenue du fer commence avec le debit", tostring(st.since_fe))
    ctx.check(st.open_fe ~= nil, "le fer ouvre", tostring(st.open_fe))
    ctx.check(st.open_fe ~= nil and st.since_fe ~= nil and st.open_fe - st.since_fe >= TENUE - 60, "le fer n'ouvre pas avant sa tenue", string.format("depart %s, ouverture %s", tostring(st.since_fe), tostring(st.open_fe)))
    ctx.check(st.cu_open == nil, "le cuivre a 20/min n'ouvre jamais", tostring(st.cu_open))
    ctx.check(st.partiel_vu ~= nil, "S2 partiel vu pendant que le fer coule", tostring(st.partiel_vu))
    ctx.check(st.close_fe ~= nil and st.close_fe > T_OFF, "le fer referme apres l'arret du debit", tostring(st.close_fe))
    ctx.log(string.format("[%s] BILAN-FAITS : depart %s, ouverture %s, partiel %s, fermeture %s", TAG, tostring(st.since_fe), tostring(st.open_fe), tostring(st.partiel_vu), tostring(st.close_fe)))
  end,
}
