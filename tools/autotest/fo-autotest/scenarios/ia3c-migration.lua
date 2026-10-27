--[[
  Lot IA3-c (docs/IA3_CERVEAU.md §5.4), repris au lot IA-V2 (version 0.5.0, réglages ALLUMÉS par défaut). DEUX chemins,
  choisis par la source de CRÉATION :
    (A) création = main 0.4.30 (fo-logs/2026-10-27_IA-V2/src-0.4.30 = git archive d80fd8d + feuilles), DOUBLE source :
        la vraie montée de version. La sauvegarde 0.4.30 n'a pas les réglages nouveaux : au chargement, ils prennent
        leur valeur par défaut (vrai) ; chaque équipe passe au cerveau par besoins, au marché et au registre à sa
        PREMIÈRE pensée (fait du 27/10 : des équipes pensent au tick du chargement, avant tout tick du mod de test : le
        banc ne peut pas les en empêcher). Contrôlé : toutes allumées dès 5 min.
        py -3.9 -B tools/autotest/banc.py --creation <src-0.4.30> --out <archive> -- 42100 ia3c-migration <source>
    (B) création = la branche (source unique), réglage fo-war-ia3-cerveau ÉTEINT à la création : l'ANCIEN cerveau
        joue 5 min (échelle avancée), puis le réglage est ALLUMÉ en cours de partie : même code de migration
        (script/ai3/cerveau.lua, Ia3.active) que le chargement d'une partie 0.4.30 avancée. Contrôlé : ancien cerveau
        pour toutes à 5 min, migration d'au moins une équipe avancée.
        py -3.9 -B tools/autotest/banc.py --out <archive> -- 42100 ia3c-migration <source>
  Création : PvP Paisible ; guerre de 2 factions (30 soldats, 10 ouvriers dont 8 au départ) ; coffre garni.
  Contrôles au tick 42 000 (11,7 min) : toutes les équipes au cerveau par besoins ; aucune technologie ni aucun niveau
  perdu ; des projets ouverts dans chaque FACTION (votre équipe peut n'avoir besoin de rien) ; une recherche réelle par
  faction ; marché et registre allumés, registre jamais au-delà du coffre ; carte de connaissance ouverte.
  Journal : [FO-IA3C-MIGRATION].
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
  description = "IA3-c et IA-V2 : partie 0.4.30 rechargee (A), ou ancien cerveau 5 min puis cerveau par besoins allume (B)",
  base = nil,
  check_tick = 42000,

  init = function(ctx)
    local st = ctx.state()
    st.version_create = script.active_mods["factorio-overhaul"]
    if remote.interfaces["fo-pvp"] then remote.call("fo-pvp", "set_difficulty", "peaceful") end
    st.war = remote.call("factorio-overhaul", "war_start", 2, 30, 10)
    st.chest = place_team_chest(ctx)
    st.create_has_ia3c = remote.interfaces["fo-ia3c"] ~= nil
    -- Chemin (B) : la source de création connaît le réglage : éteint AVANT la guerre (sauvegardé tel quel).
    st.path = "A"
    if st.create_has_ia3c then
      local v = remote.call("factorio-overhaul", "war_setting", "fo-war-ia3-cerveau", false)
      if v == false then st.path = "B" end
    end
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
      ctx.check(v == true, "reglage fo-war-ia3-cerveau allume (chemin " .. tostring(st.path) .. ")", tostring(v))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.log("chemin " .. tostring(st.path) .. " (A : creation 0.4.30, montee de version ; B : creation par la branche, reglage eteint)")
    if st.path == "A" then
      ctx.check(st.create_has_ia3c == false, "chemin A : carte creee par une source SANS le cerveau par besoins (0.4.30)",
        tostring(st.create_has_ia3c))
    end
    local before = st.before or {}
    local keys = sorted_keys(before)
    ctx.check(#keys >= 3, "equipes relevees a 5 min (2 factions et votre equipe)", #keys)
    local off_before, all_on, migrated, kept, level_kept, with_proj, research = 0, 0, 0, 0, 0, 0, 0
    local market, reg_ok, maps = 0, 0, 0
    local fog = remote.interfaces["fo-ia3f"] and remote.call("fo-ia3f", "status") or { teams = {} }
    local mapped = {}
    for _, r in ipairs(fog.teams or {}) do if r.open ~= false then mapped[r.key] = true end end
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
      if s3 and (k == "player" or #(s3.projects or {}) > 0) then with_proj = with_proj + 1 end
      if s3 and s3.marche == true then market = market + 1 end
      if s3 and s3.reg_ok then reg_ok = reg_ok + 1 end
      if mapped[k] then maps = maps + 1 end
      if k ~= "player" then
        nfac = nfac + 1
        if s3 and s3.lab then research = research + 1 end
      end
      ctx.log(string.format("a 11,7 min : %s cerveau par besoins %s (migre au tick %s), technologies %d -> %d, niveau %d -> %d, projets %d, recherche %s, laboratoires %d",
        k, tostring(s3 and s3.ia3c), tostring(s3 and s3.migrated), b.researched, now, b.tech, row and row.tech or -1,
        s3 and #(s3.projects or {}) or 0, tostring(s3 and s3.lab), s3 and s3.labs or 0))
    end
    if st.path == "B" then
      ctx.check(off_before == #keys, "chemin B : ancien cerveau pour toutes les equipes avant le reglage (5 min)", off_before .. "/" .. #keys)
    else
      ctx.check(off_before == 0, "chemin A : toutes les equipes au cerveau par besoins des 5 min (defaut au chargement)",
        (#keys - off_before) .. "/" .. #keys)
    end
    ctx.check(all_on == #keys, "toutes les equipes passees au cerveau par besoins", all_on .. "/" .. #keys)
    if st.path == "B" then
      ctx.check(migrated >= 1, "chemin B : migration d'au moins une equipe qui avait avance sur l'echelle", migrated)
    end
    ctx.check(kept == #keys, "aucune technologie perdue", kept .. "/" .. #keys)
    ctx.check(level_kept == #keys, "aucun niveau perdu", level_kept .. "/" .. #keys)
    ctx.check(with_proj == #keys, "des projets ouverts dans chaque faction", with_proj .. "/" .. #keys)
    ctx.check(research == nfac, "une recherche reelle choisie par chaque faction", research .. "/" .. nfac)
    -- Lot IA-V2 : marché et registre (IA3-b) allumés à la première pensée après le chargement ; carte de connaissance
    -- (IA3-f) ouverte pour chaque équipe.
    ctx.check(market == #keys, "place de marche et registre allumes pour chaque equipe (defaut 0.5.0)", market .. "/" .. #keys)
    ctx.check(reg_ok == #keys, "registre jamais au-dela du coffre", reg_ok .. "/" .. #keys)
    ctx.check(maps == #keys, "carte de connaissance ouverte pour chaque equipe (brouillard)", maps .. "/" .. #keys)
  end,
}
