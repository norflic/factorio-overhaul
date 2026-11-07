--[[
  Lot STOCKAGE-VITAL (objets au sol, 7/11 : 1 774 objets au pied du coffre de l'équipe dans la sauvegarde du DC, autosave1-2121 de 0.6.53 ;
  recensement de x10-sprites : copper-plate 1 168, coal 603, iron-plate 2, iron-chest 1, en disque de 8,5 tuiles autour du coffre ; source :
  script/team/migration_champ.lua, give, qui répandait au pied du QG ce que le stock plein refusait) : micro-banc de Stock.pick_ground en
  moteur réel, sans sauvegarde.

  Scène (votre équipe naît à la pose du coffre d'équipe au tick 0 ; au tick SETUP = 300) : au pied du coffre, exactement comme give de
  0.6.53 (spill_item_stack, ni marque de ramassage ni force) : 1 168 copper-plate, 603 coal, 2 iron-plate, 1 iron-chest ; TÉMOIN : 50
  copper-plate répandues à 25 tuiles à l'est du coffre (hors du rayon de Stock.GROUND_RADIUS = 10). Le coffre (96 cases) a la place.

  CRITÈRES (écrits AVANT le premier passage) :
    S1  scène posée : au moins 1 700 objets au sol à 10 tuiles au plus du coffre (S = ce nombre), au moins 45 au témoin (5 tuiles) ;
    G1  à CHECK : 0 objet au sol à 10 tuiles au plus du coffre ;
    G2  le stock a repris au moins S objets du sol (compteur f.stats.ground_taken, lu par la sonde fo-ia1 stock_cost) ;
    G3  au moins ceil(S / 200) passages qui trouvent des objets (f.stats.ground_passes : une ligne [FO-STOCKAGE] « sol du QG » chacun ;
        200 = Stock.GROUND_LIMIT) ;
    G4  le témoin hors du rayon reste au sol (au moins 45 objets à 5 tuiles de lui).
  Durée : 200 objets au plus par passage, un passage par pensée de l'équipe (300 ticks) : 9 passages pour 1 774 objets, d'où CHECK = 3 600.
  Banc : `banc.py ... -- 3700 stockage-sol <source>` ; journal : [FO-STOCKAGE-SOL].
  Témoin de version : la même scène sur a84ebce9 (0.6.59, sans Stock.pick_ground), où G1 à G3 doivent échouer.
]]
local SETUP, CHECK = 300, 3600
local SPILL = { { "copper-plate", 1168 }, { "coal", 603 }, { "iron-plate", 2 }, { "iron-chest", 1 } }
local WITNESS = { name = "copper-plate", count = 50, dx = 25 }
local R = 10

local function on_ground(s, pos, radius)
  return s.count_entities_filtered({ name = "item-on-ground", position = pos, radius = radius })
end

local function probe(ctx)
  if not ctx.has("fo-ia1", "stock_cost") then return {} end
  local ok, res = pcall(ctx.remote, "fo-ia1", "stock_cost", "player", "iron-plate", 1, 1)
  return ok and res or {}
end

return {
  description = "STOCKAGE-VITAL : objets au sol autour du coffre d'equipe (1 168 copper-plate, 603 coal), repris par le stock",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local c = game.forces.player.get_spawn_position(s)
    local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
    local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
    if chest then
      for _, it in ipairs({ { "pistol", 3 }, { "firearm-magazine", 60 }, { "coal", 200 }, { "copper-plate", 100 }, { "iron-plate", 100 } }) do
        chest.insert({ name = it[1], count = it[2] })
      end
    end
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    ctx.state().chest = chest
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local qg = st.chest
    if not (qg and qg.valid) then return end
    local s = ctx.surface()
    local t = e.tick
    if t == SETUP then
      for _, it in ipairs(SPILL) do s.spill_item_stack(qg.position, { name = it[1], count = it[2] }, false) end
      st.wpos = { x = qg.position.x + WITNESS.dx, y = qg.position.y }
      s.spill_item_stack(st.wpos, { name = WITNESS.name, count = WITNESS.count }, false)
      st.s0 = on_ground(s, qg.position, R)
      st.w0 = on_ground(s, st.wpos, 5)
      local pr = probe(ctx)
      st.taken0, st.passes0 = pr.ground_taken or 0, pr.ground_passes or 0
      ctx.log(string.format("scene : %d objet(s) au sol a %d tuiles du coffre, temoin %d a 25 tuiles ; repris jusqu'ici %d en %d passage(s)",
        st.s0, R, st.w0, st.taken0, st.passes0))
    elseif t > SETUP and t % 600 == 0 then
      local pr = probe(ctx)
      ctx.log(string.format("t+%d s : au sol %d (rayon %d), temoin %d, repris %d en %d passage(s)", (t - SETUP) / 60, on_ground(s, qg.position, R),
        R, on_ground(s, st.wpos, 5), (pr.ground_taken or 0) - st.taken0, (pr.ground_passes or 0) - st.passes0))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local qg = st.chest
    if not (qg and qg.valid and st.s0) then
      ctx.check(false, "coffre d'equipe present et scene posee")
      return
    end
    local pr = probe(ctx)
    local taken = (pr.ground_taken or 0) - (st.taken0 or 0)
    local passes = (pr.ground_passes or 0) - (st.passes0 or 0)
    local left = on_ground(s, qg.position, R)
    local w = on_ground(s, st.wpos, 5)
    ctx.check(st.s0 >= 1700 and st.w0 >= 45, "S1 scene : objets au sol au pied du coffre et temoin", string.format("%d, temoin %d", st.s0, st.w0))
    ctx.check(left == 0, "G1 plus aucun objet au sol a 10 tuiles du coffre", left)
    ctx.check(taken >= st.s0, "G2 le stock a repris les objets du sol (f.stats.ground_taken)", string.format("%d pour %d", taken, st.s0))
    ctx.check(passes >= math.ceil(st.s0 / 200), "G3 un passage par pensee, 200 objets au plus chacun (f.stats.ground_passes)",
      string.format("%d passage(s) pour %d attendus", passes, math.ceil(st.s0 / 200)))
    ctx.check(w >= 45, "G4 le temoin hors du rayon reste au sol", w)
    ctx.log(string.format("fin : au sol %d, temoin %d, repris %d en %d passage(s), coffre copper-plate %d coal %d", left, w, taken, passes,
      qg.get_item_count("copper-plate"), qg.get_item_count("coal")))
  end,
}
