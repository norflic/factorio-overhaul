-- Lot KAIJUS-MUTANTS (10/11), au banc « content », en moteur réel (noms lus par l'interface distante « titans » : aucun nom en dur) :
--   (1) les prototypes des deux Kaijus (ères ouvertes), des trois Écorchés (par ère) et du Ravageur (six paliers) se chargent ; les
--       animations de corps du Ravageur (8 directions) existent (rendering.draw_animation les accepte) ;
--   (2) un Écorcheur de la première ère et un de l'ère de la PONTE, trois Écorchés (une variante chacun) posés sur la force naturelle vivent
--       et s'animent (vitesse de course non nulle, distance_per_frame) ;
--   (3) PONTE en moteur : l'Écorcheur de l'ère de la ponte, posé avec un mur INDESTRUCTIBLE du joueur à portée (ponte.radius), met bas des
--       Écorchés au balayage suivant (600 ticks) : des Écorchés de son ère sont comptés autour de lui et l'état « ponte » de l'interface les compte.
--   (les ères vont de era_min à era_max, données par l'interface : les listes de noms commencent à era_min, jamais de # sur elles)
local CIBLE_DX = 60   -- la zone du greffon est à part (prepare_zone) : rien d'autre n'y vit

return {
  setup = function(ctx)
    ctx.prepare_zone("grass-1")
    local z, s = ctx.zone, ctx.surface()
    local st = ctx.state()
    local T = ctx.call("titans")
    st.T = T
    local ennemi = game.forces.enemy
    -- Écorcheur : archétype qui porte une ponte (lu : kaijus[i].noms[era].ponte)
    local ec, ponte_era, first_era
    for _, k in ipairs(T.kaijus) do
      for era = k.era_min, k.era_max do
        local n = k.noms[era]
        if n and n.ponte and not ponte_era then ec, ponte_era, first_era = k, era, k.era_min end
      end
    end
    ctx.check(ec ~= nil and ponte_era ~= nil, "un archetype de Kaiju porte la ponte (regle)", ec and ec.id)
    st.ec, st.ponte_era = ec, ponte_era
    local x0, y0 = z.x0 + 30, z.y0 + 30
    -- (2) Écorcheur de la première ère ouverte, loin de tout, sans ennemi : il reste et vit
    st.jeune = ec and s.create_entity({ name = ec.noms[first_era].name, position = { x0, y0 }, force = ennemi })
    if st.jeune then st.jeune.set_command({ type = defines.command.wander, radius = 3 }) end
    -- (3) Écorcheur de l'ère de la ponte, avec un mur du joueur à 12 tuiles (ennemi à portée de la ponte)
    local px, py = x0 + CIBLE_DX, y0 + 40
    st.parent = ec and s.create_entity({ name = ec.noms[ponte_era].name, position = { px, py }, force = ennemi })
    st.mur = {}
    for i = -2, 2 do
      local w = s.create_entity({ name = "stone-wall", position = { px + 12, py + i }, force = game.forces.player })
      if w then
        w.destructible = false -- la cible reste : la ponte ne dépend pas de la vitesse à laquelle le parent la détruit
        st.mur[#st.mur + 1] = w
      end
    end
    if st.parent then st.parent.set_command({ type = defines.command.wander, radius = 2 }) end
    -- Écorchés : une variante chacun, de leur première ère, à part
    st.ecorches = {}
    for i, v in ipairs(T.ecorches) do
      local era = v.era_min
      local u = s.create_entity({ name = v.noms[era], position = { x0 + 10 * i, y0 + 80 }, force = ennemi })
      if u then u.set_command({ type = defines.command.wander, radius = 3 }) end
      st.ecorches[#st.ecorches + 1] = { v = v.id, e = u, name = v.noms[era] }
    end
    st.avant = s.count_entities_filtered({ position = { px, py }, radius = 40, force = ennemi }) -- parent + rien d'autre
  end,

  verify = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local T = st.T
    local p = game.entity_prototypes
    -- (1) prototypes
    local miss = {}
    for _, k in ipairs(T.kaijus) do
      for era = k.era_min, k.era_max do if not p[k.noms[era].name] then miss[#miss + 1] = k.noms[era].name end end
    end
    for _, v in ipairs(T.ecorches) do
      for era = v.era_min, v.era_max do if not p[v.noms[era]] then miss[#miss + 1] = v.noms[era] end end
    end
    local rav
    for _, r in ipairs(T.allies) do
      for _, nom in ipairs(r.noms) do if not p[nom] then miss[#miss + 1] = nom end end
      if r.id == "ravageur" then rav = r end
    end
    ctx.check(#miss == 0, "kaijus : tous les prototypes (Kaijus par ere, Ecorches par variante et ere, allies par palier) charges", table.concat(miss, " "))
    ctx.check(rav ~= nil and #rav.noms == 6 and rav.anime, "ravageur : six paliers, corps anime (regle)", rav and #rav.noms)
    if rav then
      local okanim, n = true, 0
      for _, an in ipairs(rav.animations) do
        local ok, id = pcall(rendering.draw_animation, { animation = an, target = { ctx.zone.x0 + 5, ctx.zone.y0 + 5 }, surface = s, time_to_live = 2 })
        if not (ok and id) then okanim = false else n = n + 1 end
      end
      ctx.check(okanim and n == 3, "ravageur : les animations de corps des trois stades existent (rendering.draw_animation)", n)
      local e1 = p[rav.noms[1]]
      ctx.check(e1 and e1.type == "spider-vehicle", "ravageur : spider-vehicle (comme le Juggernaut)", e1 and e1.type)
    end
    -- (2) vivants et animés
    ctx.check(st.jeune and st.jeune.valid and st.jeune.health > 0, "ecorcheur (premiere ere) : vivant au bout du banc", st.jeune and st.jeune.valid)
    local ej = st.jeune and st.jeune.valid and st.jeune.prototype
    ctx.check(ej and ej.running_speed > 0, "ecorcheur : unit qui court (vitesse de course non nulle)", ej and ej.running_speed)
    local vivants = 0
    for _, it in ipairs(st.ecorches) do if it.e and it.e.valid then vivants = vivants + 1 end end
    ctx.check(vivants == #st.ecorches and vivants == 3, "ecorches : les trois variantes vivent au bout du banc", vivants)
    -- (3) ponte
    local etat = ctx.call("titans").ponte
    -- enfants : les Écorchés de l'ère de la ponte (les témoins vivants du (2) sont de la première ère des Écorchés : d'autres noms)
    local noms_enfants = {}
    for _, v in ipairs(T.ecorches) do noms_enfants[#noms_enfants + 1] = v.noms[st.ponte_era] end
    local nes = 0
    if st.parent and st.parent.valid and #noms_enfants > 0 then
      nes = s.count_entities_filtered({ position = st.parent.position, radius = 40, name = noms_enfants, force = game.forces.enemy })
    end
    ctx.check(st.parent and st.parent.valid, "ecorcheur (ere de la ponte) : vivant", st.parent and st.parent.valid)
    ctx.check(nes >= 2, "ponte : des Ecorches sont nes autour de l'Ecorcheur (mur du joueur a portee)", nes .. " ne(s), avant " .. tostring(st.avant))
    ctx.check(etat and etat.ecorcheurs >= 1 and etat.enfants >= 2, "ponte : l'etat de l'interface compte le parent et ses enfants", etat and (etat.ecorcheurs .. "/" .. etat.enfants))
    ctx.check(etat and #etat.noms_ponte >= 1, "ponte : noms des Kaijus a ponte lus a la regle", etat and #etat.noms_ponte)
  end,
}
