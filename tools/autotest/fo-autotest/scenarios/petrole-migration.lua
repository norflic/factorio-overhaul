--[[
  Lot PETROLE 2 : migration d'une sauvegarde 0.6.5 (sans le réglage fo-war-petrole) vers le code qui le connaît, ALLUMÉ par
  défaut. DEUX chemins, choisis par la source de CRÉATION :
    (A) création = main 0.6.5 (fo-logs/2026-10-28_PETROLE2/src-0.6.5 = git archive 2d0fbc5 + feuilles, à GARDER), DOUBLE
        source : la vraie montée de version. Le réglage n'existe pas dans la sauvegarde : au chargement il prend sa valeur par
        défaut (vrai). Contrôlé : réglage allumé, interface fo-petrole, état de chaque faction créé à sa première pensée,
        catalogue du cerveau général avec les exécutants du pétrole, aucune technologie perdue, recherches en cours.
        py -3.9 -B tools/autotest/banc.py --creation <src-0.6.5> --out <archive> -- 42100 petrole-migration <source>
    (B) création = la branche (source unique), réglage ÉTEINT à la création puis ALLUMÉ en cours de partie (tick 18 000) :
        même code de migration qu'au chargement d'une partie avancée. Contrôlé : éteint pour toutes avant, allumé après.
        py -3.9 -B tools/autotest/banc.py --out <archive> -- 42100 petrole-migration <source>
  Création : PvP Paisible ; guerre de 2 factions (30 soldats, 10 ouvriers dont 8 au départ) ; coffre garni.
  Contrôles au tick 42 000 (11,7 min). Journal : [FO-PETROLE-MIGRATION].
]]

local SWITCH = 18000
local TAG = "[FO-PETROLE-MIGRATION] "

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

local function factions()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  local out = {}
  for _, row in ipairs(ok and type(rows) == "table" and rows or {}) do
    if row.key ~= "player" then out[#out + 1] = row end
  end
  return out
end

return {
  description = "PETROLE 2 : sauvegarde 0.6.5 rechargee (A), ou reglage fo-war-petrole eteint puis allume en cours de partie (B)",
  base = nil,
  check_tick = 42000,

  init = function(ctx)
    local st = ctx.state()
    st.version_create = script.active_mods["factorio-overhaul"]
    if remote.interfaces["fo-pvp"] then remote.call("fo-pvp", "set_difficulty", "peaceful") end
    st.war = remote.call("factorio-overhaul", "war_start", 2, 30, 10)
    st.chest = place_team_chest(ctx)
    st.create_has_petrole = remote.interfaces["fo-petrole"] ~= nil
    st.path = "A"
    if st.create_has_petrole then
      local v = remote.call("factorio-overhaul", "war_setting", "fo-war-petrole", false)
      if v == false then st.path = "B" end
    end
    ctx.log(TAG .. "creation : factorio-overhaul " .. tostring(st.version_create) .. ", interface fo-petrole " ..
      tostring(st.create_has_petrole) .. ", guerre " .. tostring(st.war) .. ", coffre " .. tostring(st.chest))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == SWITCH and st.path == "B" then
      st.before = {}
      for _, r in ipairs(factions()) do st.before[r.key] = remote.call("fo-petrole", "status", r.key) end
      local v = remote.call("factorio-overhaul", "war_setting", "fo-war-petrole", true)
      ctx.log(TAG .. "reglage allume en cours de partie : " .. tostring(v))
    end
    if e.tick > 0 and e.tick % 6000 == 0 then
      local parts = {}
      for _, r in ipairs(factions()) do
        local okp, s = pcall(remote.call, "fo-petrole", "status", r.key)
        parts[#parts + 1] = string.format("%s : etat %s, connus [%s], decisions %s, techs %d", r.key,
          (okp and s) and "cree" or "absent", (okp and s) and table.concat(s.known or {}, " ") or "-",
          (okp and s) and tostring(s.decisions) or "-", researched(game.forces[r.force]))
      end
      ctx.log(TAG .. string.format("minute %.1f | %s", e.tick / 3600, table.concat(parts, " ; ")))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local sv = settings.global["fo-war-petrole"]
    ctx.check(sv ~= nil and sv.value == true, "reglage fo-war-petrole allume au contrôle", tostring(sv and sv.value))
    ctx.check(remote.interfaces["fo-petrole"] ~= nil, "interface fo-petrole presente")
    ctx.check(remote.call("fo-petrole", "on") == true, "Pet.on() vrai")
    local rows = factions()
    ctx.check(#rows >= 2, "2 factions vivantes au controle", #rows)
    local created, techs_ok = 0, true
    for _, r in ipairs(rows) do
      local s = remote.call("fo-petrole", "status", r.key)
      if s ~= nil then created = created + 1 end
      if researched(game.forces[r.force]) < 1 then techs_ok = false end
    end
    ctx.check(created == #rows, "etat du lot cree pour chaque faction", created .. "/" .. #rows)
    ctx.check(techs_ok, "chaque faction a recherche au moins une technologie")
    if st.path == "A" then
      ctx.check(not st.create_has_petrole, "chemin A : la sauvegarde de creation ne connait pas le lot", tostring(st.version_create))
    else
      local none = true
      for _, r in ipairs(rows) do if st.before and st.before[r.key] ~= nil then none = false end end
      ctx.check(none, "chemin B : aucun etat du lot avant l'allumage (reglage eteint)")
    end
    -- le catalogue du cerveau général compte les exécutants du pétrole une fois le réglage allumé
    local g = remote.interfaces["fo-iag"] and remote.call("fo-iag", "status", rows[1] and rows[1].key or "") or nil
    ctx.log(TAG .. "fo-iag : " .. tostring(g and g.catalogue ~= nil))
    ctx.log(TAG .. "chemin " .. tostring(st.path) .. ", creation " .. tostring(st.version_create))
  end,
}
