--[[
  Lot IA1-b : protocole « 30 contre 10 » du banc « ia1-scale » (même protocole, même carte, même financement ; seule
  la taille des équipes change : fo-war-workers = N et fo-player-team-npc-max = N). Sert à la mesure demandée par le
  Directeur Créatif : « une équipe de 30 livre-t-elle plus qu'une équipe de 10 ? » (RD_LOG F182 comparait ia1-scale
  à ia0-normal, deux scénarios différents ; ici, une seule variable).
  Scénarios : ia1b-scale10 (N = 10) et ia1b-scale30 (N = 30). Lancement : « fo-autotest.bat nopause 216000
  ia1b-scale30 <source> » (banc épinglé). Journal : [FO-IA1B-SCALE30], mêmes lignes « minute N | ... » que
  [FO-IA1-SCALE] (tools/autotest/ia1_scale.py), plus « livre au QG ... » en fin de partie (tools/autotest/ia1b_livre.py).
  Ces fichiers ne dépendent que de l'interface « fo-ia1 » d'IA1-a : ils tournent aussi sur une source 0.4.25
  (mesure AVANT, en y recopiant les trois fichiers ia1b*).
]]

local MIN = 3600

return function(N)
local TARGET = math.floor(N * 9 / 10) -- 90 % de N

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
  description = "IA1-b : protocole 30 contre 10 du banc ia1-scale (4 factions x " .. N .. " + votre equipe a " .. N .. ", 60 min, epingle)",
  base = nil,
  check_tick = 215000,

  init = function(ctx)
    local held = ctx.remote("fo-ia1", "set_setting", "fo-recruit-idle-max", 60)
    ctx.check(held == 60, "frein par le travail leve (fo-recruit-idle-max = 60)", held)
    local pmax = ctx.remote("fo-ia1", "set_setting", "fo-player-team-npc-max", N)
    ctx.check(pmax == N, "votre equipe plafonnee a " .. N, pmax)
    local workers = ctx.remote("factorio-overhaul", "war_setting", "fo-war-workers", N)
    ctx.check(workers == N, "fo-war-workers regle a " .. N, workers)
    local ok = ctx.remote("fo-pvp", "set_difficulty", "peaceful")
    ctx.check(ok == true, "difficulte Paisible imposee avant la guerre")
    local started = ctx.call("war_start", 4, 100)
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
      ctx.log(string.format("%s : armee soldats min30 %s min59 %s fin %d ; tech %d",
        r.key, tostring(st.series[r.key .. ":30"]), tostring(st.series[r.key .. ":59"]), r.soldiers, r.tech))
      local d = r.delivered or {}
      ctx.log(string.format("%s : livre au QG fer %d cuivre %d charbon %d pierre %d minerai_fer %d ; produit (force) fer %d cuivre %d charbon %d pierre %d",
        r.key, d["iron-plate"] or 0, d["copper-plate"] or 0, d["coal"] or 0, d["stone"] or 0, d["iron-ore"] or 0,
        (r.produced or {})["iron-plate"] or 0, (r.produced or {})["copper-plate"] or 0, (r.produced or {})["coal"] or 0,
        (r.produced or {})["stone"] or 0))
    end
    local fail, total = sum_path(p)
    ctx.log(string.format("reponses du pathfinder en echec : %d sur %d", fail, total))
    ctx.check(p.agents <= 300, "agents riches <= fo-agents-max (300)", p.agents)
  end,
}
end
