--[[
  Lot IA1-a « Échelle 30 » (docs/EQUIPES_PNJ.md §16) : 4 factions × 30 PNJ + votre équipe à 30, 60 min de jeu,
  banc ÉPINGLÉ (F30). Lancement : « 216000 ia1-scale <source> » (fo-autotest.bat nopause 216000 ia1-scale <source>).
  Journal : [FO-IA1-SCALE]. Post-analyse (temps script, seuils, tableaux) : tools/autotest/ia1_scale.py.

  Préparation (au tick 0, dans la carte créée) :
    - PvP « Paisible » (comme les scénarios de guerre intégrés : comparable à ia0-normal et à E17-E22) ;
    - guerre lancée SANS nombre d'ouvriers : la taille suit fo-team-npc-max (30) ; 8 PNJ offerts par faction ;
    - chaque faction reçoit 2 500 plaques de fer (et 625 cuivre, 1 250 charbon, 1 250 pierre, War.fund) : de
      quoi payer les 22 recrues (1 617 fer et 110 cuivre, kits compris) ; SANS ce financement, la montée
      dépend de l'économie de départ (non mesurée ici) ;
    - votre équipe : coffre d'équipe posé près du départ, garni (2 500 fer, 400 cuivre, 300 charbon, 100 pierre,
      8 foreuses, 8 fours, 4 coffres) ; 8 PNJ offerts, les suivants payés au coffre.
  Relevé toutes les 3 600 ticks (une minute ; pas plus souvent, pour ne pas peser sur le temps script mesuré) :
  effectif par équipe, recrues, inactivité RÉELLE (moyenne de la minute), exécutants AU-DELÀ DU CARNET (moyenne),
  production de la force en MU par minute (le m de Q-IA1-1), demandes de chemin (émises, échecs, « but occupé »).
  Contrôles (finish, tick 215 000) : effectif ≥ 27 (90 % de 30) atteint par chaque équipe ; échecs de chemin
  ≤ 5 % ; « but occupé » ≤ 20 ; au plus 6 demandes en vol et 2 émises par tick ; agents ≤ fo-agents-max.
  Le temps script (≤ 0,25 ms par tick) se lit dans benchmark-stdout.txt : ia1_scale.py.
]]

local MIN = 3600
local TARGET = 27 -- 90 % de 30

local function place_team_chest(ctx)
  local s = ctx.surface()
  local c = game.forces.player.get_spawn_position(s)
  local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
  local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
  if not chest then return false end
  for _, it in ipairs({ { "iron-plate", 2500 }, { "copper-plate", 400 }, { "coal", 300 }, { "stone", 100 },
    { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  return true
end

local function sum_path(p)
  local fail = (p.fail or 0) + (p.timeout or 0)
  local total = (p.ok or 0) + fail
  return fail, total
end

return {
  description = "IA1-a : echelle 30, 4 factions x 30 + votre equipe a 30 (60 min, banc epingle)",
  base = nil,
  check_tick = 215000,

  init = function(ctx)
    -- Correction IA1-a : banc d'ÉCHELLE (150 PNJ) ; le frein par le travail (fo-recruit-idle-max, défaut 0)
    -- garderait les équipes vers 8 PNJ : il est levé ici (60 = seul le stock freine).
    local held = ctx.remote("fo-ia1", "set_setting", "fo-recruit-idle-max", 60)
    ctx.check(held == 60, "frein par le travail leve (fo-recruit-idle-max = 60)", held)
    local ok = ctx.remote("fo-pvp", "set_difficulty", "peaceful")
    ctx.check(ok == true, "difficulte Paisible imposee avant la guerre")
    local started = ctx.call("war_start", 4, 100) -- sans nombre d'ouvriers : fo-team-npc-max
    ctx.check(started == true, "guerre lancee (4 factions, taille par le reglage)")
    local funded = ctx.call("war_fund", 2500)
    ctx.check(funded == 4, "4 factions financees (2 500 fer)", funded)
    ctx.check(place_team_chest(ctx), "coffre d'equipe pose et garni")
    ctx.call("profiler", true)
    ctx.call("reset_stats")
    local rows = ctx.remote("fo-ia1", "teams")
    local parts = {}
    for _, r in ipairs(rows) do parts[#parts + 1] = r.key .. " " .. r.n .. "/" .. r.max end
    ctx.check(#rows == 5, "5 equipes au depart (4 factions + votre equipe)", table.concat(parts, ", "))
    local st = ctx.state()
    st.prev, st.reach, st.max_n, st.series = {}, {}, {}, {}
  end,

  tick = function(ctx, e)
    if e.tick % MIN ~= 0 or e.tick == 0 then return end
    local st = ctx.state()
    local minute = e.tick / MIN
    local rows = ctx.remote("fo-ia1", "teams")
    local p = ctx.remote("fo-ia1", "path")
    local parts = {}
    for _, r in ipairs(rows) do
      local prev = st.prev[r.key] or { thinks = 0, n_sum = 0, idle_sum = 0, surplus_sum = 0, mu = 0 }
      local dthinks = r.thinks - prev.thinks
      local dn = r.n_sum - prev.n_sum
      local idle_pct = dn > 0 and (100 * (r.idle_sum - prev.idle_sum) / dn) or 0
      local surplus = dthinks > 0 and ((r.surplus_sum - prev.surplus_sum) / dthinks) or 0
      local dmu = r.produced_mu >= 0 and (r.produced_mu - prev.mu) or -1
      st.prev[r.key] = { thinks = r.thinks, n_sum = r.n_sum, idle_sum = r.idle_sum, surplus_sum = r.surplus_sum, mu = r.produced_mu }
      st.max_n[r.key] = math.max(st.max_n[r.key] or 0, r.n)
      if r.n >= TARGET and not st.reach[r.key] then st.reach[r.key] = minute end
      if minute == 30 or minute == 59 then st.series[r.key .. ":" .. minute] = r.soldiers end
      parts[#parts + 1] = string.format("%s n=%d/%d recrues=%d garde=%d frein=%d inactifs=%.0f%% au-dela=%.1f mu=%d tech=%d ap=%d soldats=%d chemins_ko=%d buts_deplaces=%d",
        r.key, r.n, r.max, r.recruited, r.guard, r.held or 0, idle_pct, surplus, dmu, r.tech, r.outposts, r.soldiers, r.nav_fail, r.goal_moved)
    end
    local fail, total = sum_path(p)
    ctx.log(string.format("minute %d | agents %d | chemins demandes %d emis %d ok %d echecs %d (%.1f %%) but_occupe %d depart %d eau %d autre %d | en vol max %d file max %d emis/tick max %d",
      minute, p.agents, p.requested, p.issued, p.ok, fail, total > 0 and 100 * fail / total or 0, p.fail_blocked,
      p.fail_start, p.fail_water, p.fail_other, p.inflight_max, p.queue_max, p.issued_tick_max))
    for _, s in ipairs(parts) do ctx.log("minute " .. minute .. " | " .. s) end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local rows = ctx.remote("fo-ia1", "teams")
    local p = ctx.remote("fo-ia1", "path")
    for _, r in ipairs(rows) do
      local reached = st.reach[r.key]
      ctx.check(reached ~= nil, r.key .. " : effectif >= " .. TARGET .. " atteint",
        string.format("minute %s, maximum %d, fin %d/%d, recrues payees %d", tostring(reached), st.max_n[r.key] or 0, r.n, r.max, r.recruited))
      local idle = r.n_sum > 0 and 100 * r.idle_sum / r.n_sum or 0
      local surplus = r.thinks > 0 and r.surplus_sum / r.thinks or 0
      ctx.log(string.format("%s : sur toute la partie, inactivite reelle %.1f %% ; au-dela du carnet %.1f PNJ en moyenne (publies, non bornes dans ce lot) ; production %d MU ; cases bloquees %d, prises %d",
        r.key, idle, surplus, r.produced_mu, r.slots_bad, r.slots_owned))
      -- Correction IA1-a (défaut M2) : armée publiée à 30 min et en fin de partie (relevé de la minute 59 ; la
      -- minute 60 tombe après le contrôle du tick 215 000), et au contrôle.
      ctx.log(string.format("%s : armee soldats min30 %s min59 %s fin %d ; tech %d",
        r.key, tostring(st.series[r.key .. ":30"]), tostring(st.series[r.key .. ":59"]), r.soldiers, r.tech))
    end
    local fail, total = sum_path(p)
    local rate = total > 0 and fail / total or 0
    ctx.check(rate <= 0.05, "echecs de chemin <= 5 %", string.format("%.2f %% (%d sur %d)", 100 * rate, fail, total))
    ctx.check((p.fail_blocked or 0) <= 20, "but occupe <= 20", p.fail_blocked)
    ctx.check((p.inflight_max or 0) <= 6, "au plus 6 demandes de chemin en vol", p.inflight_max)
    ctx.check((p.issued_tick_max or 0) <= 2, "au plus 2 demandes emises par tick", p.issued_tick_max)
    ctx.check(p.agents <= 300, "agents riches <= fo-agents-max (300)", p.agents)
  end,
}
