-- Lot JALONS (14/11) : partie du DC aux réglages livrés (lancement automatique, 30 ouvriers), VOTRE ÉQUIPE fondée d'office
-- et jouée par l'IA sans avantage (comme s43-parite-seule) + 4 factions = 5 équipes, sur 30 min, plus :
--  * chaque minute, une ligne [FO-JALON] par équipe : foreuses électriques EN MARCHE par ressource minée, fours en marche,
--    assembleurs (total / en marche), plaques de fer et de cuivre produites (statistiques de la force) ;
--  * la minute du 1er assembleur posé, de la 1re foreuse électrique en marche sur chaque ressource et du 1er four en
--    marche (ligne [FO-JALON-PREMIERS], preuve du verrou des tiers : aucun assembleur avant l'extraction et la fonte) ;
--  * captures du QG de chaque équipe à 15 et 30 min : fo-shots/jalon-m015-<équipe>.png (session avec images).
-- Lecture : tools/autotest/jalons.py <archive>.
local base = require("scenarios/verif_guide_common")(30, true)
local MIN = 3600
local TAG = "[FO-JALON] "
local FIRST = {} -- clé d'équipe -> { asm = minute, drill = { ressource = minute }, furnace = minute }

local function hq_of(s, force)
  return s.find_entities_filtered({ name = "fo-faction-hq", force = force, limit = 1 })[1]
    or s.find_entities_filtered({ name = "fo-team-chest", force = force, limit = 1 })[1]
end

local function kv(t)
  local o = {}
  for k, v in pairs(t) do o[#o + 1] = k .. ":" .. v end
  table.sort(o)
  return #o > 0 and table.concat(o, ",") or "-"
end

local function jalon(ctx, tick)
  local s = ctx.surface()
  local minute = tick / MIN
  local W = defines.entity_status.working
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    local force = row.force and game.forces[row.force]
    if force then
      local key = tostring(row.key)
      local fst = FIRST[key] or { drill = {} }
      FIRST[key] = fst
      local elec, comb = {}, 0
      for _, d in ipairs(s.find_entities_filtered({ force = force, type = "mining-drill" })) do
        if d.prototype.electric_energy_source_prototype then
          if d.status == W and d.mining_target then
            local r = d.mining_target.name
            elec[r] = (elec[r] or 0) + 1
            if not fst.drill[r] then fst.drill[r] = minute end
          end
        elseif d.status == W then
          comb = comb + 1
        end
      end
      local fours, fours_on = 0, 0
      for _, f in ipairs(s.find_entities_filtered({ force = force, type = "furnace" })) do
        fours = fours + 1
        if f.status == W then fours_on = fours_on + 1 end
      end
      if fours_on > 0 and not fst.furnace then fst.furnace = minute end
      local asm, asm_on = 0, 0
      for _, a in ipairs(s.find_entities_filtered({ force = force, type = "assembling-machine" })) do
        asm = asm + 1
        if a.status == W then asm_on = asm_on + 1 end
      end
      if asm > 0 and not fst.asm then fst.asm = minute end
      local st = force.item_production_statistics
      log(TAG .. string.format("minute=%d equipe=%s foreuses_elec_marche=%s foreuses_comb_marche=%d fours=%d fours_marche=%d"
        .. " assembleurs=%d assembleurs_marche=%d fer_produit=%d cuivre_produit=%d",
        minute, key, kv(elec), comb, fours, fours_on, asm, asm_on, st.get_input_count("iron-plate"), st.get_input_count("copper-plate")))
      log("[FO-JALON-PREMIERS] " .. string.format("minute=%d equipe=%s premier_assembleur=%s premier_four_marche=%s premieres_foreuses_elec=%s",
        minute, key, tostring(fst.asm or "-"), tostring(fst.furnace or "-"), kv(fst.drill)))
    end
  end
end

local function shots(ctx, minute)
  local p = game.connected_players[1]
  if not p then return end
  local s = ctx.surface()
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    local hq = row.force and hq_of(s, row.force)
    if hq then
      local file = string.format("fo-shots/jalon-m%03d-%s.png", minute, tostring(row.key):gsub("[^%w%-]", "_"))
      game.take_screenshot({ player = p, surface = s, position = hq.position, resolution = { 1920, 1080 }, zoom = 0.18,
        path = file, show_entity_info = true, daytime = 0, allow_in_replay = true, force_render = true })
      log(TAG .. "capture fichier=" .. file)
    end
  end
  game.set_wait_for_screenshots_to_finish()
end

local init0, tick0 = base.init, base.tick
base.description = "JALONS : votre equipe (sans humain) + 4 factions, 30 min, [FO-JALON] chaque minute, captures des QG a 15 et 30 min"
base.check_tick = 108000
base.init = function(ctx)
  init0(ctx)
  ctx.check(ctx.remote("factorio-overhaul", "war_setting", "fo-war-factions", 4) == 4, "4 factions")
end
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick > 0 and e.tick % MIN == 0 and e.tick <= 30 * MIN then
    local ok, err = pcall(jalon, ctx, e.tick)
    if not ok then log(TAG .. "ERREUR " .. tostring(err)) end
  end
  if e.tick == 15 * MIN then
    local ok, err = pcall(shots, ctx, 15)
    if not ok then log(TAG .. "ERREUR capture " .. tostring(err)) end
  end
end
-- captures de 30 min par le pilote (shots.lua, vérifiées) : vue du QG de chaque équipe
base.shots_delay = 30 * MIN + 400
base.shots = function(ctx, add)
  local s = ctx.surface()
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    local hq = row.force and hq_of(s, row.force)
    if hq then
      add(string.format("jalon-m030-%s", tostring(row.key):gsub("[^%w%-]", "_")), hq.position.x, hq.position.y, 0.18, 0,
        { res = { 1920, 1080 }, info = true, aa = true })
    end
  end
end
return base
