--[[
  Lot IA3-c (docs/IA3_CERVEAU.md §5.4) : une partie de main 0.4.29 (ancien cerveau, guerre et votre équipe) rechargée par
  le lot, qui joue d'abord 5 min avec l'ANCIEN cerveau (réglage éteint, valeur par défaut d'une partie existante), puis
  ALLUME le réglage fo-war-ia3-cerveau en cours de partie : chaque équipe doit passer au cerveau par besoins (migration).
  Double source OBLIGATOIRE :
    FO_CREATE_SRC = `git archive` de main 0.4.29 (927d288) + feuilles de la mitrailleuse + ce fichier recopié dans
    tools\autotest\fo-autotest\scenarios ; source = le lot.
    fo-autotest.bat nopause 42100 ia3c-migration <source du lot>
  Création (0.4.29) : PvP Paisible ; guerre de 2 factions (30 soldats, 10 ouvriers dont 8 au départ) ; coffre garni.
  Benchmark (lot) : tick 60 personnages de la création vivants ; tick 18 000 (5 min) relevé de l'ancien cerveau
  (niveau, technologies recherchées par force), réglage allumé ; contrôles au tick 42 000 : chaque équipe est passée au
  cerveau par besoins, avec migration pour celles qui avaient avancé sur l'échelle ; aucune technologie perdue, aucun
  niveau perdu ; des projets ouverts ; une recherche réelle choisie par chaque faction. Journal : [FO-IA3C-MIGRATION].
]]

local SWITCH = 18000

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

local function researched(force)
  local n = 0
  for _, t in pairs(force.technologies) do if t.researched then n = n + 1 end end
  return n
end

local function teams()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  if not ok or type(rows) ~= "table" then return {} end
  return rows
end

return {
  description = "IA3-c : partie 0.4.29 rechargee, ancien cerveau 5 min puis cerveau par besoins allume en cours de partie",
  base = nil,
  check_tick = 42000,

  init = function(ctx)
    local st = ctx.state()
    st.version_create = script.active_mods["factorio-overhaul"]
    if remote.interfaces["fo-pvp"] then remote.call("fo-pvp", "set_difficulty", "peaceful") end
    st.war = remote.call("factorio-overhaul", "war_start", 2, 30, 10)
    st.chest = place_team_chest(ctx)
    st.create_has_ia3c = remote.interfaces["fo-ia3c"] ~= nil
    ctx.log("creation : factorio-overhaul " .. tostring(st.version_create) .. ", interface fo-ia3c " ..
      tostring(st.create_has_ia3c) .. ", guerre " .. tostring(st.war) .. ", coffre " .. tostring(st.chest))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == SWITCH then
      st.before = {}
      for _, r in ipairs(teams()) do
        local force = game.forces[r.force]
        local s3 = remote.call("fo-ia3c", "status", r.key)
        st.before[r.key] = { tech = r.tech or 0, researched = force and researched(force) or 0, force = r.force,
          ia3c = s3 and s3.ia3c or false, outposts = r.outposts or 0 }
        ctx.log(string.format("ancien cerveau a 5 min : %s niveau %d, %d technologies, %d avant-postes, cerveau par besoins %s",
          r.key, r.tech or 0, st.before[r.key].researched, r.outposts or 0, tostring(s3 and s3.ia3c)))
      end
      local v = ctx.remote("factorio-overhaul", "war_setting", "fo-war-ia3-cerveau", true)
      ctx.check(v == true, "reglage fo-war-ia3-cerveau allume en cours de partie", tostring(v))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.create_has_ia3c == false, "carte creee par une source SANS le cerveau par besoins (0.4.29)",
      tostring(st.create_has_ia3c))
    local before = st.before or {}
    local keys = sorted_keys(before)
    ctx.check(#keys >= 3, "equipes relevees a 5 min (2 factions et votre equipe)", #keys)
    local off_before, all_on, migrated, kept, level_kept, with_proj, research = 0, 0, 0, 0, 0, 0, 0
    local nfac = 0
    for _, k in ipairs(keys) do
      local b = before[k]
      if not b.ia3c then off_before = off_before + 1 end
      local s3 = remote.call("fo-ia3c", "status", k)
      local row
      for _, r in ipairs(teams()) do if r.key == k then row = r end end
      local force = game.forces[b.force]
      local now = force and researched(force) or 0
      if s3 and s3.ia3c then all_on = all_on + 1 end
      if s3 and s3.migrated then migrated = migrated + 1 end
      if now >= b.researched then kept = kept + 1 end
      if row and (row.tech or 0) >= b.tech then level_kept = level_kept + 1 end
      if s3 and #(s3.projects or {}) > 0 then with_proj = with_proj + 1 end
      if k ~= "player" then
        nfac = nfac + 1
        if s3 and s3.lab then research = research + 1 end
      end
      ctx.log(string.format("a 11,7 min : %s cerveau par besoins %s (migre au tick %s), technologies %d -> %d, niveau %d -> %d, projets %d, recherche %s, laboratoires %d",
        k, tostring(s3 and s3.ia3c), tostring(s3 and s3.migrated), b.researched, now, b.tech, row and row.tech or -1,
        s3 and #(s3.projects or {}) or 0, tostring(s3 and s3.lab), s3 and s3.labs or 0))
    end
    ctx.check(off_before == #keys, "ancien cerveau pour toutes les equipes avant le reglage (5 min)", off_before .. "/" .. #keys)
    ctx.check(all_on == #keys, "toutes les equipes passees au cerveau par besoins", all_on .. "/" .. #keys)
    ctx.check(migrated >= 1, "migration d'au moins une equipe qui avait avance sur l'echelle", migrated)
    ctx.check(kept == #keys, "aucune technologie perdue", kept .. "/" .. #keys)
    ctx.check(level_kept == #keys, "aucun niveau perdu", level_kept .. "/" .. #keys)
    ctx.check(with_proj == #keys, "des projets ouverts dans chaque equipe", with_proj .. "/" .. #keys)
    ctx.check(research == nfac, "une recherche reelle choisie par chaque faction", research .. "/" .. nfac)
  end,
}
