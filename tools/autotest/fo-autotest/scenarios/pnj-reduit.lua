--[[
  Lot PNJ-VÉRIF (24/10) : la partie « avec moins d'éléments » proposée au Directeur Créatif (GUIDE_PARTIE.md), jouée
  en moteur réel. Équivalent de : réglage « Factions : difficulté » = Facile, puis `/fo-war start 2 30 4` (2 factions,
  30 soldats au plus, 4 ouvriers au plus, QG à 480 tuiles), puis un coffre d'équipe garni près du départ.
  Contrôles au tick 107 000 (≈ 30 min) : 2 factions vivantes, plafonds tenus (soldats ≤ 30, ouvriers ≤ 4 par
  faction), économie en marche (avant-postes, fer livré), équipe du joueur active avec des ouvriers, difficulté Facile
  vue à chaque relevé, aucune attaque contre le joueur avant la fin de sa grâce. Journal : [FO-PNJ-REDUIT].
  Lancement : `fo-autotest.bat nopause 108000 pnj-reduit <source>`.
]]

local CHECK = 107000

local function count(s, type_, force)
  return s.count_entities_filtered({ type = type_, force = force })
end

return {
  description = "PNJ-VERIF : partie reduite (Facile, 2 factions, 30 soldats, 4 ouvriers, equipe du joueur)",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local ok = ctx.remote("fo-pvp", "set_difficulty", "easy")
    ctx.check(ok == true, "difficulte Facile imposee avant la guerre", tostring(ok))
    local started = ctx.call("war_start", 2, 30, 4)
    ctx.check(started == true, "guerre lancee : 2 factions, 30 soldats, 4 ouvriers", tostring(started))
    ctx.call("profiler", true)
    local s = ctx.surface()
    local c = game.forces.player.get_spawn_position(s)
    local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
    local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
    if chest then
      for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
        { "pistol", 3 }, { "firearm-magazine", 60 }, { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
        chest.insert({ name = it[1], count = it[2] })
      end
    end
    ctx.check(chest ~= nil, "coffre d'equipe pose")
  end,

  tick = function(ctx, e)
    if e.tick % 3600 ~= 0 or e.tick == 0 then return end
    local st = ctx.state()
    local s = ctx.surface()
    local pvp = ctx.remote("fo-pvp", "status")
    st.polls = (st.polls or 0) + 1
    if pvp.difficulty == "easy" then st.easy = (st.easy or 0) + 1 end
    st.max_soldiers, st.max_workers = st.max_soldiers or 0, st.max_workers or 0
    local parts = {}
    for _, f in ipairs(pvp.factions) do
      local force = "fo-" .. f.key
      local soldiers, workers = count(s, "unit", force), count(s, "character", force)
      if soldiers > st.max_soldiers then st.max_soldiers = soldiers end
      if workers > st.max_workers then st.max_workers = workers end
      if f.attacks > 0 and f.last_attack and f.grace_end and f.last_attack < f.grace_end then st.early = true end
      parts[#parts + 1] = string.format("%s soldats %d ouvriers %d attaques-joueur %d %s", f.key, soldiers, workers, f.attacks,
        f.declared and "guerre" or "treve")
    end
    local pw = count(s, "character", "player")
    if pw > (st.max_pworkers or 0) then st.max_pworkers = pw end
    ctx.log(string.format("minute %d | %s | ouvriers du joueur %d", e.tick / 3600, table.concat(parts, " ; "), pw))
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local poi = ctx.call("points_of_interest")
    ctx.check(#poi.factions == 2, "2 factions vivantes", #poi.factions)
    local outposts = {}
    for _, f in ipairs(poi.factions) do outposts[#outposts + 1] = f.key .. "=" .. #f.outposts end
    local ok_out = true
    for _, f in ipairs(poi.factions) do if #f.outposts < 3 then ok_out = false end end
    ctx.check(ok_out, "chaque faction a au moins 3 avant-postes", table.concat(outposts, ", "))
    ctx.check((st.max_soldiers or 0) <= 30 and (st.max_soldiers or 0) > 0, "soldats par faction : 1 a 30", st.max_soldiers)
    ctx.check((st.max_workers or 0) <= 4 and (st.max_workers or 0) > 0, "ouvriers par faction : 1 a 4", st.max_workers)
    ctx.check(st.polls and st.easy == st.polls, "difficulte Facile a chaque releve", tostring(st.easy) .. "/" .. tostring(st.polls))
    ctx.check(not st.early, "aucune attaque contre le joueur avant la fin de la grace")
    local line = ctx.call("team_status")
    ctx.check(line ~= nil, "equipe du joueur active", line and line:sub(1, 160))
    ctx.check((st.max_pworkers or 0) >= 2, "ouvriers de l'equipe du joueur (personnages de la force player)", st.max_pworkers)
    ctx.check(poi.player ~= nil and #poi.player.outposts >= 2, "avant-postes de l'equipe du joueur",
      poi.player and #poi.player.outposts)
  end,
}
