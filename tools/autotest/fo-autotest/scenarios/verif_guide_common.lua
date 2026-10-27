--[[
  Vérification adverse de la nuit du 24 au 25/10 (VERIF-NUIT) : la partie du GUIDE (fo-logs\2026-10-24_PNJ\
  GUIDE_PARTIE.md) jouée telle que le Directeur Créatif la lancera, SANS console : réglages de carte écrits par le
  relais du mod (2 factions, 30 soldats, 4 ouvriers, « lancer la guerre au début de la partie » coché), difficulté
  Facile écrite dans le réglage de partie (PvP.set_difficulty écrit fo-pvp-difficulty), coffre d'équipe garni.
  Différence avec `pnj-reduit` : la guerre part par le lancement AUTOMATIQUE (ouvriers = nil, taille suivie en cours
  de partie) et non par war_start(2, 30, 4).
  Relevé par minute ; contrôles au tick 214 000 (≈ 59,4 min).
  Correction VERIF-NUIT (25/10) : contrôle RECONSTRUCTION de votre équipe. Défaut prouvé sur 0.4.23 (graines
  271828182 et 1618033988) : effectif tombé à 3 puis 1, jamais reconstruit, coffre plein de fer. Le contrôle échoue
  si, pendant RUN_MAX relevés de suite (minutes), votre équipe existe, compte moins que son effectif de départ
  (min(fo-npc-start, fo-player-team-npc-max)) ET son coffre garde au moins IRON_MIN plaques de fer.
  Lancement : `fo-autotest.bat nopause 216000 verif-guide <source>` (graine : FO_MAP_SEED). Journal : [FO-VERIF-GUIDE].
]]

-- Lot SCALE : la même partie avec un autre plafond d'ouvriers des factions (fo-war-workers), pour mesurer la
-- proposition P1 d'IA3-d (défaut 4 -> 30, D-14) : scenarios/scale-guide30.lua. verif-guide reste à 4 (le guide).
return function(WORKERS)
local CHECK = 214000
local RUN_MAX = 5     -- minutes de suite sous l'effectif de départ, fer au coffre : au-delà, l'équipe ne se reconstruit pas
local IRON_MIN = 100  -- plaques de fer au coffre (une recrue coûte environ 60 plaques équipée au QG)

local function count(s, type_, force)
  return s.count_entities_filtered({ type = type_, force = force })
end

return {
  description = "VERIF-NUIT : partie du guide (reglages de carte, lancement automatique, Facile, coffre d'equipe)",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local set = {
      ctx.remote("factorio-overhaul", "war_setting", "fo-war-factions", 2),
      ctx.remote("factorio-overhaul", "war_setting", "fo-war-soldiers", 30),
      ctx.remote("factorio-overhaul", "war_setting", "fo-war-workers", WORKERS),
      ctx.remote("factorio-overhaul", "war_setting", "fo-war-autostart", true),
    }
    ctx.check(set[1] == 2 and set[2] == 30 and set[3] == WORKERS and set[4] == true, "reglages de carte du guide ecrits",
      table.concat({ tostring(set[1]), tostring(set[2]), tostring(set[3]), tostring(set[4]) }, ", "))
    local ok = ctx.remote("fo-pvp", "set_difficulty", "easy")
    ctx.check(ok == true and settings.global["fo-pvp-difficulty"].value == "easy",
      "difficulte Facile ecrite dans le reglage de partie", tostring(settings.global["fo-pvp-difficulty"].value))
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
    local st = ctx.state()
    st.chest = chest
    st.floor = math.min(settings.global["fo-npc-start"].value, settings.global["fo-player-team-npc-max"].value)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.war_tick and e.tick % 60 == 0 then
      local pvp = ctx.remote("fo-pvp", "status")
      if #pvp.factions > 0 then
        st.war_tick, st.war_n = e.tick, #pvp.factions
        ctx.log(string.format("guerre lancee seule, vue au tick %d : %d factions", e.tick, #pvp.factions))
      end
    end
    if e.tick % 3600 ~= 0 or e.tick == 0 then return end
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
      parts[#parts + 1] = string.format("%s soldats %d ouvriers %d attaques-joueur %d %s", f.key, soldiers, workers,
        f.attacks, f.declared and "guerre" or "treve")
    end
    local poi = ctx.call("points_of_interest")
    local alive = poi and #poi.factions or -1
    if st.first_dead == nil and st.war_n and alive < st.war_n then st.first_dead = e.tick end
    local pw = count(s, "character", "player")
    if pw > (st.max_pworkers or 0) then st.max_pworkers = pw end
    local team = ctx.call("team_status")
    -- Reconstruction : relevés de suite sous l'effectif de départ avec du fer au coffre (équipe existante).
    local iron = (st.chest and st.chest.valid) and st.chest.get_item_count("iron-plate") or 0
    if team ~= nil and st.chest and st.chest.valid and pw < (st.floor or 8) and iron >= IRON_MIN then
      st.run = (st.run or 0) + 1
      if st.run > (st.run_max or 0) then st.run_max, st.run_end, st.run_low, st.run_iron = st.run, e.tick / 3600, pw, iron end
    else
      st.run = 0
    end
    ctx.log(string.format("minute %d | vivantes %d | %s | ouvriers du joueur %d | equipe : %s", e.tick / 3600, alive,
      table.concat(parts, " ; "), pw, tostring(team and team:sub(1, 140))))
    -- Lot IA1-b2 (mesure, hors bilan) : votre équipe minute par minute (interface fo-ia1 ; champs absents avant 0.4.27 : -1).
    st.prev_idle = st.prev_idle or {}
    for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
      local tag = r.key == "player" and "votre equipe" or r.key
      -- Inactifs de la minute (PNJ sans tâche à la pensée, critère C5-2) et raisons d'attente cumulées (IA1-b2).
      local p = st.prev_idle[r.key] or { idle = 0, n = 0 }
      local dn = (r.n_sum or 0) - p.n
      local idle_pct = dn > 0 and math.floor(100 * ((r.idle_sum or 0) - p.idle) / dn + 0.5) or 0
      st.prev_idle[r.key] = { idle = r.idle_sum or 0, n = r.n_sum or 0 }
      ctx.log(string.format("mesure minute %d | %s | n=%d recrues=%d perdus=%d tues_ennemis=%d fer=%d ap=%d defendus=%d tourelles=%d mu=%d qg=%d inactifs=%d%% attente rien=%d bloque=%d manque=%d",
        e.tick / 3600, tag, r.n, r.recruited, r.lost or -1, r.lost_enemy or -1, r.iron or iron, r.outposts,
        r.outposts_defended or -1, r.turrets or count(s, "ammo-turret", r.force), r.produced_mu, r.hq_turrets or -1,
        idle_pct, r.idle_rien or -1, r.idle_bloque or -1, r.idle_manque or -1))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.war_tick ~= nil and st.war_tick <= 1200, "guerre lancee seule (reglage de carte) avant le tick 1200",
      st.war_tick)
    ctx.check(st.war_n == 2, "2 factions au lancement", st.war_n)
    local poi = ctx.call("points_of_interest")
    ctx.check(#poi.factions >= 1, "au moins une faction vivante a 59 min", #poi.factions)
    ctx.check(st.first_dead == nil or st.first_dead >= 3600 * 60,
      "aucune faction aneantie avant 60 min (objectif d'IA2-a2)", st.first_dead)
    ctx.check((st.max_soldiers or 0) <= 30 and (st.max_soldiers or 0) > 0, "soldats par faction : 1 a 30", st.max_soldiers)
    ctx.check((st.max_workers or 0) <= WORKERS and (st.max_workers or 0) > 0, "ouvriers par faction : 1 a " .. WORKERS,
      st.max_workers)
    ctx.check(st.polls and st.easy == st.polls, "difficulte Facile a chaque releve",
      tostring(st.easy) .. "/" .. tostring(st.polls))
    ctx.check(not st.early, "aucune attaque contre le joueur avant la fin de la grace")
    local line = ctx.call("team_status")
    ctx.check(line ~= nil, "equipe du joueur active", line and line:sub(1, 160))
    ctx.check((st.max_pworkers or 0) >= 2, "ouvriers de l'equipe du joueur", st.max_pworkers)
    ctx.check((st.run_max or 0) < RUN_MAX, string.format(
      "votre equipe se reconstruit : jamais %d min de suite sous l'effectif de depart (%d) avec >= %d fer au coffre",
      RUN_MAX, st.floor or 8, IRON_MIN), st.run_max and string.format("%d min de suite, fin a la minute %d, %d ouvrier(s), %d fer",
      st.run_max, st.run_end, st.run_low, st.run_iron) or "0 min")
    ctx.check(poi.player ~= nil and #poi.player.outposts >= 2, "avant-postes de l'equipe du joueur",
      poi.player and #poi.player.outposts)
  end,
}
end
