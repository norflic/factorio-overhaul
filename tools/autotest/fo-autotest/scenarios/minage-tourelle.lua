--[[
  Lot TOURELLE-JOURNAL (7/11, retour du DC sur 0.6.58 : tourelles « volontairement enlevées », « très très fortes chances que ce soit les
  pnj qui les aient prises ») : un PNJ de VOTRE équipe mine-t-il une tourelle posée sur du minerai ?
  Chemin suspect (script/team/worker.lua, étape « mine ») : update_selected_entity(position du minerai) sélectionne ce que la souris
  survolerait, donc la tourelle posée dessus, et mining_state la mine (même force « player »). Relevé en moteur réel du même mécanisme
  pour une autre ressource posée sur la tuile (script/team/harvest.lua, Harvest.foreign_resource : 2 cristaux au coffre, 0 charbon).
  Mise en place : coffre d'équipe SANS fer ; à 8 tuiles à l'est, UNE tuile de minerai de fer libre (1 minerai) et, juste à côté, 4 tuiles
  de fer (1000 chacune) sous une mitrailleuse de base posée par script (force « player », hors du registre de l'équipe, comme celle d'un
  joueur). La tâche de minage ne peut viser que la tuile libre (les tuiles sous un bâtiment sont écartées à la création de la tâche) ; une
  fois épuisée, l'étape « mine » cherche le minerai à 2,5 tuiles (mining_entity) et tombe sous la tourelle.
  Contrôles : MINE (précondition) la tuile libre est minée avant la fin ; RESTE la mitrailleuse est toujours là à la fin.
    témoin 0e340b99 : RESTE doit ÉCHOUER (la tourelle part ; où va-t-elle : sacs des PNJ et coffre, journalisés) ;
    branche tourelle-journal : RESTE doit passer (minage refusé, ligne [FO-TOURELLE-RETIREE] « minage refuse » au journal du mod).
  Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui <lot> -- 2500 minage-tourelle <source>. Journal : [FO-MINAGE-TOURELLE].
]]
local CHECK = 2400
local POLL = 30
local EAST = 8

local function d2(a, b) return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 end

return {
  description = "TOURELLE-JOURNAL : un PNJ de votre equipe mine-t-il une tourelle posee sur du minerai ?",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 2) == 2, "effectif de depart 2")
    local s = ctx.surface()
    local c0 = game.forces.player.get_spawn_position(s)
    local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
    local hq = { x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.5 }
    -- Aucun autre minerai de fer à 100 tuiles : seule la tuile libre peut être visée.
    for _, e in ipairs(s.find_entities_filtered({ position = hq, radius = 100, name = "iron-ore" })) do e.destroy() end
    local a, b = math.floor(hq.x) + EAST, math.floor(hq.y)
    for _, e in ipairs(s.find_entities_filtered({ area = { { a - 2, b - 2 }, { a + 5, b + 4 } } })) do
      if e.valid and e.type ~= "character" then e.destroy() end
    end
    local free = s.create_entity({ name = "iron-ore", position = { a + 0.5, b + 0.5 }, amount = 1 })
    local under = {}
    for _, o in ipairs({ { 1.5, 0.5 }, { 2.5, 0.5 }, { 1.5, 1.5 }, { 2.5, 1.5 } }) do
      under[#under + 1] = s.create_entity({ name = "iron-ore", position = { a + o[1], b + o[2] }, amount = 1000 })
    end
    local tu = s.create_entity({ name = "gun-turret", position = { a + 2, b + 1 }, force = "player" })
    if tu then tu.insert({ name = "firearm-magazine", count = 10 }) end
    local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
    ctx.check(chest ~= nil and free ~= nil and #under == 4 and tu ~= nil, "coffre, tuile libre, 4 tuiles sous la tourelle, mitrailleuse posee",
      string.format("tuile libre (%.1f, %.1f), tourelle (%.1f, %.1f)", a + 0.5, b + 0.5, a + 2, b + 1))
    if not (chest and tu) then return end
    -- Kit SANS fer (le fer vient du minage à la main) : pierre et charbon pour un four, munitions.
    for _, it in ipairs({ { "stone", 50 }, { "coal", 50 }, { "stone-furnace", 2 }, { "pistol", 2 }, { "firearm-magazine", 20 } }) do
      chest.insert({ name = it[1], count = it[2] })
    end
    st.hq, st.free_pos, st.tu, st.tu_pos, st.chest = hq, { x = a + 0.5, y = b + 0.5 }, tu, { x = a + 2, y = b + 1 }, chest
    st.free = free
    ctx.log(string.format("[FO-MINAGE-TOURELLE] coffre en (%.1f, %.1f) ; tuile libre (%.1f, %.1f) a 1 minerai ; mitrailleuse en (%.1f, %.1f) sur 4 tuiles de fer",
      chest.position.x, chest.position.y, a + 0.5, b + 0.5, a + 2, b + 1))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.tu_pos or e.tick % POLL ~= 0 then return end
    if not st.mined_at and not (st.free and st.free.valid) then
      st.mined_at = e.tick
      ctx.log(string.format("[FO-MINAGE-TOURELLE] tuile libre epuisee au tick %d", e.tick))
    end
    if not st.gone_at and not (st.tu and st.tu.valid) then
      st.gone_at = e.tick
      local s = ctx.surface()
      local in_bags = 0
      for _, c in ipairs(s.find_entities_filtered({ position = st.tu_pos, radius = 60, name = "fo-companion" })) do
        in_bags = in_bags + c.get_item_count("gun-turret")
      end
      ctx.log(string.format("[FO-MINAGE-TOURELLE] mitrailleuse DISPARUE au tick %d ; gun-turret dans les sacs des PNJ %d, au coffre %d", e.tick, in_bags,
        st.chest and st.chest.valid and st.chest.get_item_count("gun-turret") or -1))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.tu_pos then
      ctx.fail("banc prepare", "mise en place incomplete")
      return
    end
    local s = ctx.surface()
    local in_bags = 0
    for _, c in ipairs(s.find_entities_filtered({ position = st.tu_pos, radius = 80, name = "fo-companion" })) do
      in_bags = in_bags + c.get_item_count("gun-turret")
    end
    local in_chest = st.chest and st.chest.valid and st.chest.get_item_count("gun-turret") or -1
    ctx.check(st.mined_at ~= nil, "MINE (precondition) : la tuile libre est minee avant la fin",
      st.mined_at and ("tick " .. st.mined_at) or "jamais : banc non concluant")
    ctx.check(st.tu and st.tu.valid, "RESTE : la mitrailleuse posee sur le minerai est toujours la",
      string.format("%s ; gun-turret dans les sacs des PNJ %d, au coffre %d", st.gone_at and ("disparue au tick " .. st.gone_at) or "en place", in_bags, in_chest))
  end,
}
