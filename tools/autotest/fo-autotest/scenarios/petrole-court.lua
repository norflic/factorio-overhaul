--[[
  Lot PETROLE2-REPRISE (30/10, reprise de la branche petrole2 sur 0.6.20) : micro-banc COURT (palier 3, < 5 000 ticks) du
  branchement du lot en moteur réel, réglage fo-war-petrole ÉTEINT par défaut puis ALLUMÉ en cours de partie (comme le DC
  le ferait dans Échap > Réglages > Carte). Ce banc NE prouve PAS qu'une faction bâtit un site ni atteint le pack chimique
  (parties longues petrole-guide, petrole-site : > 10 000 ticks, accord du DC requis) ; il prouve seulement :
    1. réglage éteint par défaut à la création ;
    2. aucun état du lot tant que le réglage est éteint (sauvegardes 0.6.20 inchangées) ;
    3. allumé en cours de partie, chaque faction et votre équipe créent leur état au premier passage du cerveau, sans erreur ;
    4. les interfaces de lecture (status, tasks : plus de require pendant l'appel, F24) répondent ;
    5. aucune technologie perdue, global sérialisable par le moteur (la partie continue jusqu'au contrôle).
  Création : PvP Paisible ; guerre de 2 factions (30 soldats, 10 ouvriers dont 8 au départ) ; coffre d'équipe garni.
  Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui PETROLE2-REPRISE -- 4300 petrole-court <source>
  Sauvegarde 0.6.20 (double source) : même commande avec --creation <source de main 0.6.20, feuilles comprises> : la carte est
  créée (on_init) par main, rechargée par la branche, le réglage absent de la sauvegarde y prend son défaut (éteint).
  Journal : [FO-PETROLE-COURT].
]]

local SWITCH = 600

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
  local f = game.forces[force]
  if not f then return 0 end
  local names = {}
  for name in pairs(f.technologies) do names[#names + 1] = name end
  table.sort(names)
  local n = 0
  for _, name in ipairs(names) do if f.technologies[name].researched then n = n + 1 end end
  return n
end

local function teams()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  local out = {}
  for _, row in ipairs(ok and type(rows) == "table" and rows or {}) do out[#out + 1] = row end
  return out
end

return {
  description = "PETROLE2-REPRISE : reglage fo-war-petrole eteint par defaut, allume en cours de partie (micro-banc)",
  base = nil,
  check_tick = 4200,

  init = function(ctx)
    local st = ctx.state()
    if remote.interfaces["fo-pvp"] then remote.call("fo-pvp", "set_difficulty", "peaceful") end
    st.war = remote.call("factorio-overhaul", "war_start", 2, 30, 10)
    st.chest = place_team_chest(ctx)
    local sv = settings.global["fo-war-petrole"]
    st.create_has = sv ~= nil -- faux : carte créée par une source sans le lot (double source, main 0.6.20)
    st.default = sv and sv.value
    ctx.log("creation : guerre " .. tostring(st.war) .. ", coffre " .. tostring(st.chest) .. ", fo-war-petrole = " ..
      tostring(st.default))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == SWITCH then
      st.before, st.techs0 = {}, {}
      for _, r in ipairs(teams()) do
        local ok, s = pcall(remote.call, "fo-petrole", "status", r.key)
        st.before[#st.before + 1] = { key = r.key, ok = ok, has = ok and s ~= nil }
        st.techs0[r.key] = researched(r.force)
      end
      local v = remote.call("factorio-overhaul", "war_setting", "fo-war-petrole", true)
      st.switched = v
      ctx.log("reglage allume en cours de partie au tick " .. e.tick .. " : " .. tostring(v))
    end
    if e.tick > SWITCH and e.tick % 1200 == 0 then
      local parts = {}
      for _, r in ipairs(teams()) do
        local okp, s = pcall(remote.call, "fo-petrole", "status", r.key)
        parts[#parts + 1] = string.format("%s : etat %s, connus [%s], decisions %s, sites %s, techs %d", r.key,
          (okp and s) and "cree" or (okp and "absent" or "ERREUR"), (okp and s) and table.concat(s.known or {}, " ") or "-",
          (okp and s) and tostring(s.decisions) or "-", (okp and s) and tostring(#(s.sites or {})) or "-", researched(r.force))
      end
      ctx.log(string.format("minute %.1f | %s", e.tick / 3600, table.concat(parts, " ; ")))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.default == false or (st.default == nil and st.create_has == false),
      "reglage fo-war-petrole eteint par defaut a la creation (ou absent : sauvegarde d'une source sans le lot)",
      tostring(st.default) .. (st.create_has == false and " (absent a la creation)" or ""))
    local none, okb = true, true
    for _, b in ipairs(st.before or {}) do
      if not b.ok then okb = false end
      if b.has then none = false end
    end
    ctx.check(#(st.before or {}) >= 2 and okb and none, "aucun etat du lot tant que le reglage est eteint",
      tostring(#(st.before or {})) .. " equipe(s)")
    ctx.check(st.switched == true, "reglage allume en cours de partie", tostring(st.switched))
    ctx.check(remote.call("fo-petrole", "on") == true, "Pet.on() vrai apres l'allumage")
    local rows = teams()
    local factions, created, created_f, techs_ok, tasks_ok = 0, 0, 0, true, true
    for _, r in ipairs(rows) do
      if r.key ~= "player" then factions = factions + 1 end
      local ok, s = pcall(remote.call, "fo-petrole", "status", r.key)
      if ok and s ~= nil then
        created = created + 1
        if r.key ~= "player" then created_f = created_f + 1 end
      end
      if researched(r.force) < ((st.techs0 or {})[r.key] or 0) then techs_ok = false end
      local okt, t = pcall(remote.call, "fo-petrole", "tasks", r.key, 1)
      if not okt or (t ~= nil and type(t) ~= "table") then tasks_ok = false end
    end
    ctx.check(factions >= 2, "2 factions vivantes au controle", factions)
    ctx.check(created_f == factions, "etat du lot cree pour chaque faction apres l'allumage", created_f .. "/" .. factions)
    ctx.check(techs_ok, "aucune technologie perdue depuis l'allumage")
    ctx.check(tasks_ok, "interface fo-petrole tasks sans erreur (require hors evenement)")
    ctx.log(string.format("equipes avec etat : %d sur %d (votre equipe comprise si elle pense)", created, #rows))
  end,
}
