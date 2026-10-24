--[[
  Correction du lot IA1-a (fusion avec 0.4.15) : une partie 0.4.15 avec la guerre EN COURS, rechargée par le lot.
  Repris du scénario de vérification `verif-mig` (vérificateur d'IA1-a, sauvegarde 0.4.11), adapté à 0.4.15.
  Double source OBLIGATOIRE :
    FO_CREATE_SRC = `git archive` de main 0.4.15 (+ feuilles de la mitrailleuse) ; source = le lot.
    fo-autotest.bat nopause 40000 ia1-migration <source du lot>
  Création (0.4.15) : PvP Paisible ; guerre de la partie du guide (war_start 2, 30, 4 : les nombres que le
  lancement automatique de 0.4.15 écrit dans la guerre) ; coffre d'équipe garni comme `pteam` ; relevé des
  personnages par force (numéros d'unité).
  Benchmark (lot) :
    - tick 60 : les personnages de la création existent-ils encore ?
    - tick 18 000 : fo-war-workers passe à 12 (relais war_setting) ; une guerre lancée AVEC un nombre (cas de
      0.4.15) garde son plafond de 4 (décision de la fusion : aucune migration de la taille) ;
    - relevé par minute (fo-ia1) ; contrôles au tick 36 000.
  Journal : [FO-IA1-MIGRATION].
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
  description = "IA1-a (fusion 0.4.15) : partie 0.4.15 en guerre rechargee par le lot (double source)",
  base = nil,
  check_tick = 36000,

  init = function(ctx)
    local st = ctx.state()
    st.version_create = script.active_mods["factorio-overhaul"]
    st.create_has_ia1 = remote.interfaces["fo-ia1"] ~= nil
    if remote.interfaces["fo-pvp"] then remote.call("fo-pvp", "set_difficulty", "peaceful") end
    st.war = remote.call("factorio-overhaul", "war_start", 2, 30, 4)
    st.chest = place_team_chest(ctx)
    st.chars = characters(ctx.surface())
    local parts = {}
    for _, f in ipairs(sorted_keys(st.chars)) do parts[#parts + 1] = f .. "=" .. #st.chars[f] end
    ctx.log("creation : factorio-overhaul " .. tostring(st.version_create) .. ", interface fo-ia1 "
      .. tostring(st.create_has_ia1) .. ", guerre " .. tostring(st.war) .. ", coffre " .. tostring(st.chest)
      .. ", personnages " .. table.concat(parts, " "))
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
      st.bench_has_ia1 = remote.interfaces["fo-ia1"] ~= nil
      ctx.log(string.format("tick 60 (interface fo-ia1 %s) : personnages de la creation vivants %d, perdus %d",
        tostring(st.bench_has_ia1), alive, lost))
    end
    if e.tick == 18000 then
      st.set12 = remote.call("factorio-overhaul", "war_setting", "fo-war-workers", 12)
      ctx.log("tick 18000 : fo-war-workers = " .. tostring(st.set12))
    end
    if e.tick % MIN == 0 and e.tick > 0 then
      local ok, rows = pcall(remote.call, "fo-ia1", "teams")
      if not ok then ctx.log("fo-ia1 indisponible : " .. tostring(rows)) return end
      for _, r in ipairs(rows) do
        st.max_seen = st.max_seen or {}
        st.max_seen[r.key] = math.max(st.max_seen[r.key] or 0, r.max)
        ctx.log(string.format("minute %d | %s n=%d/%d recrues=%d frein=%d cases_prises=%d cases_bloquees=%d thinks=%d nav_fail=%d",
          e.tick / MIN, r.key, r.n, r.max, r.recruited, r.held or 0, r.slots_owned, r.slots_bad, r.thinks, r.nav_fail))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.version_create ~= nil and st.create_has_ia1 == false,
      "creation faite par une source sans IA1-a (0.4.15)", tostring(st.version_create))
    ctx.check(st.bench_has_ia1 == true, "benchmark joue par le lot (interface fo-ia1)")
    ctx.check((st.lost60 or 1) == 0 and (st.alive60 or 0) > 0, "PNJ de la sauvegarde 0.4.15 vivants au tick 60",
      string.format("%s vivants, %s perdus", tostring(st.alive60), tostring(st.lost60)))
    ctx.check(st.set12 == 12, "fo-war-workers regle a 12 au tick 18000", st.set12)
    local rows = remote.call("fo-ia1", "teams")
    local player, factions = nil, 0
    for _, r in ipairs(rows) do
      if r.key == "player" then
        player = r
      else
        factions = factions + 1
        ctx.check(r.n >= 1 and r.n <= 4 and (st.max_seen[r.key] or 0) == 4,
          r.key .. " : plafond de la guerre 0.4.15 garde (4), meme apres fo-war-workers = 12",
          r.n .. "/" .. r.max .. ", plafond vu " .. tostring(st.max_seen[r.key]) .. ", recrues " .. r.recruited)
      end
      ctx.check(r.thinks > 0, r.key .. " : l'equipe pense apres la migration", r.thinks)
      ctx.check(r.slots_owned > 0, r.key .. " : cases du QG attribuees apres la migration", r.slots_owned .. " (n=" .. r.n .. ")")
    end
    ctx.check(factions == 2, "2 factions apres la migration", factions)
    ctx.check(player ~= nil and player.n > 0, "votre equipe a des PNJ apres la migration",
      player and (player.n .. "/" .. player.max .. ", recrues " .. player.recruited) or "absente")
  end,
}
