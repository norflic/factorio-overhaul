--[[
  Lot IA1-b : une partie 0.4.25 (guerre en cours, votre équipe, PNJ avant les pôles) rechargée par le lot.
  Double source OBLIGATOIRE :
    FO_CREATE_SRC = `git archive` de main 0.4.25 (+ feuilles de la mitrailleuse, + ce fichier recopié dans
    tools\autotest\fo-autotest\scenarios) ; source = le lot.
    fo-autotest.bat nopause 37000 ia1b-migration <source du lot>
  Création (0.4.25) : PvP Paisible ; guerre de la partie du guide (war_start 2, 30, 4) ; coffre d'équipe garni.
  Benchmark (lot) : personnages de la création vivants au tick 60 ; état d'organisation publié pour chaque équipe ;
  tous les PNJ placés dans un pôle ; une pensée par période ; aucune tâche interrompue ; travail de fond ouvert ;
  contrôles au tick 36 000 (10 min). Journal : [FO-IA1B-MIGRATION].
]]

local MIN = 3600

local function characters(s)
  local by = {}
  for _, e in ipairs(s.find_entities_filtered({ type = "character" })) do
    if e.valid and e.unit_number then
      local f = e.force.name
      by[f] = by[f] or {}
      by[f][#by[f] + 1] = e.unit_number
    end
  end
  return by
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function place_team_chest(ctx)
  local s = ctx.surface()
  local c = game.forces.player.get_spawn_position(s)
  local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
  local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
  if not chest then return false end
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
    { "pistol", 3 }, { "firearm-magazine", 60 }, { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  return true
end

return {
  description = "IA1-b : partie 0.4.25 en guerre rechargee par le lot (double source)",
  base = nil,
  check_tick = 36000,

  init = function(ctx)
    local st = ctx.state()
    st.version_create = script.active_mods["factorio-overhaul"]
    if remote.interfaces["fo-pvp"] then remote.call("fo-pvp", "set_difficulty", "peaceful") end
    st.war = remote.call("factorio-overhaul", "war_start", 2, 30, 4)
    st.chest = place_team_chest(ctx)
    st.chars = characters(ctx.surface())
    st.create_has_poles = remote.interfaces["fo-ia1"] ~= nil and remote.interfaces["fo-ia1"].team_status ~= nil
    local parts = {}
    for _, f in ipairs(sorted_keys(st.chars)) do parts[#parts + 1] = f .. "=" .. #st.chars[f] end
    ctx.log("creation : factorio-overhaul " .. tostring(st.version_create) .. ", poles " .. tostring(st.create_has_poles)
      .. ", guerre " .. tostring(st.war) .. ", coffre " .. tostring(st.chest) .. ", personnages " .. table.concat(parts, " "))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == 60 then
      local now = characters(ctx.surface())
      local alive, lost = 0, 0
      for _, f in ipairs(sorted_keys(st.chars)) do
        local set = {}
        for _, u in ipairs(now[f] or {}) do set[u] = true end
        for _, u in ipairs(st.chars[f]) do if set[u] then alive = alive + 1 else lost = lost + 1 end end
      end
      st.alive60, st.lost60 = alive, lost
      st.bench_has_poles = remote.interfaces["fo-ia1"] ~= nil and remote.interfaces["fo-ia1"].team_status ~= nil
      ctx.log(string.format("tick 60 (poles %s) : personnages de la creation vivants %d, perdus %d",
        tostring(st.bench_has_poles), alive, lost))
    end
    if e.tick % MIN == 0 and e.tick > 0 and st.bench_has_poles then
      for _, r in ipairs(remote.call("fo-ia1", "teams")) do
        local s = remote.call("fo-ia1", "team_status", r.key)
        if s and s.last then
          ctx.log(string.format("minute %d | %s n=%d inactifs=%d cibles=%d/%d/%d reels=%d/%d/%d gen=%d/%d/%d pensees=%d interrompues=%d fond=%d",
            e.tick / MIN, r.key, s.last.n, s.last.idle, s.last.targets[1], s.last.targets[2], s.last.targets[3],
            s.last.actual[1], s.last.actual[2], s.last.actual[3], s.last.gens[1], s.last.gens[2], s.last.gens[3],
            s.stats.thinks, s.stats.interrupted, s.stats.fond_opened))
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.version_create ~= nil and st.create_has_poles == false,
      "carte creee par une source sans les poles (0.4.25)", tostring(st.version_create))
    ctx.check(st.bench_has_poles == true, "benchmark joue par le lot (team_status)")
    ctx.check((st.lost60 or 1) == 0 and (st.alive60 or 0) > 0, "PNJ de la sauvegarde 0.4.25 vivants au tick 60",
      string.format("%d vivants, %d perdus", st.alive60 or 0, st.lost60 or -1))
    local teams = 0
    for _, r in ipairs(remote.call("fo-ia1", "teams")) do
      teams = teams + 1
      local s = remote.call("fo-ia1", "team_status", r.key)
      ctx.check(s ~= nil and s.last ~= nil, r.key .. " : organisation publiee apres la migration")
      if s and s.last then
        local unplaced = 0
        for _, npc in ipairs(s.npcs) do if npc.pole == nil then unplaced = unplaced + 1 end end
        ctx.check(unplaced == 0 and #s.npcs == r.n, r.key .. " : tous les PNJ places dans un pole",
          string.format("%d sans pole sur %d", unplaced, #s.npcs))
        local expected = math.floor((36000 - 60) / 300)
        ctx.check(s.stats.double_think == 0 and math.abs(s.stats.thinks - expected) <= 2, r.key .. " : une pensee par periode",
          string.format("%d pensees, %d en double", s.stats.thinks, s.stats.double_think))
        ctx.check(s.stats.interrupted == 0, r.key .. " : aucune tache interrompue", s.stats.interrupted)
        local gens = s.last.gens[1] + s.last.gens[2] + s.last.gens[3]
        ctx.check(gens >= 1, r.key .. " : generalistes designes", gens .. " pour " .. r.n .. " PNJ")
      end
    end
    ctx.check(teams == 3, "2 factions et votre equipe apres la migration", teams)
  end,
}
