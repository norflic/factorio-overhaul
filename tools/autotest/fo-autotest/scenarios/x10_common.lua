--[[
  Lot X10, part MOTEUR (7/11 ; le DC : « faire tourner le jeu en x10 naturellement ») : QUE coûte le moteur sur la SAUVEGARDE du
  DC, classe par classe ? Mesure par SOUSTRACTION : une classe d'entités du mod passe en `active = false` au tick de départ, et
  l'on compare les colonnes du MOTEUR (entityUpdate, pathFinder, ...) à un témoin rejoué sur la même sauvegarde.
  Rapport : fo-logs\2026-11-07_X10\MOTEUR.md (§5 M1, §6, §7 : attendus écrits AVANT tout passage).

  CE BANC NE MESURE QUE LE MOTEUR. Une usine figée ne produit plus, un PNJ figé ne marche plus : les DÉCISIONS du mod divergent
  du témoin (famine, chantiers, ...). Le temps du SCRIPT de ces passages ne vaut rien ; seules les colonnes du moteur se lisent.

  Sauvegarde rejouée telle quelle (banc.py --sauvegarde) : aucun réglage du mod n'est posé (nom dans KIT_EGAL de control.lua),
  profileur ÉTEINT, ligne « [FO-PERF4] debut tick D » (même format que perf4_partie_common.lua) pour que perf3.py et ses dérivés
  ramènent les lignes du benchmark aux ticks du jeu.

  CLASSES (argument CLASSE) :
    "temoin" : rien n'est figé (scénario x10-recensement) ;
    "usines" : bras, machines, foreuses, vapeur... des FACTIONS (forces « fo-* »), types USINES ci-dessous ; tourelles, PNJ,
               soldats, tapis, poteaux, coffres et murs restent actifs (scénario x10-sans-usines) ;
    "pnj"    : tous les personnages « fo-companion » (factions ET votre équipe), avec destructible = false (F321 : un personnage
               figé ne se défend plus et meurt) (scénario x10-sans-pnj) ;
    "tout"   : TOUTES les entités des forces « fo-* » + tous les « fo-companion » + les unités (soldats) de la force player ;
               destructible = false pour les personnages et les unités (scénario x10-fige-tout). Ce qui reste actif : la base de
               la force player (le DC ET la production de votre équipe, que le moteur ne sépare pas), les biters, le neutre.
  Revue : aux ticks D + 1 800 et D + 3 900, la classe est relue et toute entité neuve ou réactivée (pose, ravivage, niveau
  remplacé : levels.lua réactive) est refigée ; le nombre est écrit. Recensement complet au départ (on_init) et à la fin.
  Aucune écriture hors de `active` et `destructible` ; la sauvegarde du banc est une COPIE (fo-autotest.bat), jamais réécrite.

  Lancement (PC sans le jeu du DC, sans Blender, sans série d'un autre agent ; accord du lead) :
    py -3.9 -B tools/autotest/banc.py --seul --qui X10 --sauvegarde "<racine>\fo-logs\2026-11-05_PARTIE-DC-ESSAI\autosave1-2121.zip"
       --out "<racine>\fo-logs\2026-11-07_X10\M1-<nom>-<n>" -- 6000 x10-<recensement|sans-usines|sans-pnj|fige-tout> <source>
]]

-- Types qui travaillent dans une usine (triés) ; ni tourelles, ni personnages, ni unités, ni tapis, ni poteaux, ni coffres.
local USINES = { "assembling-machine", "boiler", "burner-generator", "furnace", "generator", "inserter", "lab", "mining-drill",
  "offshore-pump", "pump", "reactor", "rocket-silo" }
local NEUTRES = { "cliff", "fish", "resource", "simple-entity", "tree" }
local PNJ = "fo-companion"
local REVUES = { 1800, 3900 }
local FIN = 5700
local TOP_NOMS = 60

local function sorted_force_names()
  local out = {}
  for name in pairs(game.forces) do out[#out + 1] = name end
  table.sort(out)
  return out
end

local function faction_forces()
  local out = {}
  for _, name in ipairs(sorted_force_names()) do
    if name:sub(1, 3) == "fo-" then out[#out + 1] = name end
  end
  return out
end

--- « clé=valeur » triées par valeur décroissante puis par clé ; au plus `limit`.
local function tally_text(t, limit)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) if t[a] ~= t[b] then return t[a] > t[b] end return a < b end)
  local parts = {}
  for i = 1, math.min(#keys, limit or #keys) do parts[#parts + 1] = keys[i] .. "=" .. t[keys[i]] end
  if limit and #keys > limit then parts[#parts + 1] = "(+" .. (#keys - limit) .. " noms)" end
  return table.concat(parts, ", ")
end

--- Recensement de la surface : par force, total, inactives, types et noms (le neutre : comptes seuls, arbres compris).
local function census(ctx, label)
  local s = ctx.surface()
  local chunks = 0
  for _ in s.get_chunks() do chunks = chunks + 1 end
  ctx.log(string.format("RECENSEMENT %s : tick %d, chunks %d, pollution %.0f, evolution %.4f, joueurs connectes %d, vitesse %.2f",
    label, game.tick, chunks, s.get_total_pollution(), game.forces.enemy.evolution_factor, #game.connected_players, game.speed))
  local totals = {}
  for _, fname in ipairs(sorted_force_names()) do
    if fname == "neutral" then
      local parts = {}
      for _, t in ipairs(NEUTRES) do parts[#parts + 1] = t .. "=" .. s.count_entities_filtered({ force = fname, type = t }) end
      local n = s.count_entities_filtered({ force = fname })
      totals[#totals + 1] = fname .. "=" .. n
      ctx.log(string.format("RECENSEMENT %s : force %s : total %d ; %s", label, fname, n, table.concat(parts, ", ")))
    else
      local list = s.find_entities_filtered({ force = fname })
      local by_type, by_name, inactive = {}, {}, 0
      for i = 1, #list do
        local e = list[i]
        by_type[e.type] = (by_type[e.type] or 0) + 1
        by_name[e.name] = (by_name[e.name] or 0) + 1
        if not e.active then inactive = inactive + 1 end
      end
      totals[#totals + 1] = fname .. "=" .. #list
      if #list > 0 then
        ctx.log(string.format("RECENSEMENT %s : force %s : total %d, inactives %d ; types : %s", label, fname, #list, inactive,
          tally_text(by_type)))
        ctx.log(string.format("RECENSEMENT %s : force %s : noms : %s", label, fname, tally_text(by_name, TOP_NOMS)))
      end
    end
  end
  ctx.log(string.format("RECENSEMENT %s : totaux par force : %s", label, table.concat(totals, ", ")))
  return #totals
end

--- Entités de la classe, dans l'ordre du moteur (find_entities_filtered est déterministe), force par force triée.
local function members(ctx, classe)
  local s = ctx.surface()
  local out = {}
  local function add(list) for i = 1, #list do out[#out + 1] = list[i] end end
  if classe == "usines" or classe == "tout" then
    for _, f in ipairs(faction_forces()) do
      if classe == "usines" then add(s.find_entities_filtered({ force = f, type = USINES }))
      else add(s.find_entities_filtered({ force = f })) end
    end
  end
  if classe == "pnj" or classe == "tout" then
    local list = s.find_entities_filtered({ name = PNJ })
    for i = 1, #list do
      -- en « tout », les PNJ des factions sont déjà dans la liste de leur force
      if classe == "pnj" or list[i].force.name:sub(1, 3) ~= "fo-" then out[#out + 1] = list[i] end
    end
  end
  if classe == "tout" then add(s.find_entities_filtered({ force = "player", type = "unit" })) end
  return out
end

--- Fige la classe : active = false (et destructible = false pour personnages et unités). Renvoie figées, déjà figées, refus.
local function freeze(ctx, classe)
  local list = members(ctx, classe)
  local frozen, already, refused = 0, 0, 0
  local by_type = {}
  for i = 1, #list do
    local e = list[i]
    if e.valid then
      if e.active then
        local ok = pcall(function() e.active = false end)
        if ok and not e.active then
          frozen = frozen + 1
          by_type[e.type] = (by_type[e.type] or 0) + 1
        else
          refused = refused + 1
        end
      else
        already = already + 1
      end
      if e.valid and (e.type == "character" or e.type == "unit") and e.destructible then
        pcall(function() e.destructible = false end)
      end
    end
  end
  return #list, frozen, already, refused, by_type
end

return function(SCENARIO, CLASSE)
  local S = {
    description = "X10 moteur : sauvegarde du DC, classe figee " .. CLASSE .. " (" .. SCENARIO .. ")",
    check_tick = -1, -- fixé à l'init : tick de la sauvegarde + FIN
  }

  S.init = function(ctx)
    local t = game.tick
    S.check_tick = t + FIN
    local st = ctx.state()
    st.debut = t
    local mods = {}
    for name, v in pairs(script.active_mods) do mods[#mods + 1] = name .. " " .. v end
    table.sort(mods)
    -- Même ligne que perf4_partie_common.lua : perf3.py aligne le benchmark sur ce tick.
    log(string.format("[FO-PERF4] debut tick %d (%.1f min de jeu) ; mode %s ; mods : %s", t, t / 3600, SCENARIO, table.concat(mods, ", ")))
    ctx.call("profiler", false, false)
    ctx.check(t > 0, "partie chargee depuis une sauvegarde (tick de depart > 0)", t)
    local nforces = census(ctx, "depart")
    ctx.check(nforces >= 3, "recensement ecrit (forces recensees)", nforces)
    ctx.log(string.format("factions recensees (forces fo-*) : %s", table.concat(faction_forces(), ", ")))
    if CLASSE ~= "temoin" then
      local n, frozen, already, refused, by_type = freeze(ctx, CLASSE)
      st.figees = frozen
      ctx.log(string.format("FIGE %s au tick %d : %d entite(s) de la classe, %d figee(s), %d deja inactive(s), %d refus ; %s",
        CLASSE, t, n, frozen, already, refused, tally_text(by_type)))
      ctx.check(frozen > 0, "classe " .. CLASSE .. " figee au depart (au moins une entite)", frozen)
    end
  end

  S.tick = function(ctx, e)
    if CLASSE == "temoin" then return end
    local st = ctx.state()
    if not st.debut then return end
    for i = 1, #REVUES do
      if e.tick == st.debut + REVUES[i] then
        local n, frozen, already, refused, by_type = freeze(ctx, CLASSE)
        ctx.log(string.format("REVUE %s au tick %d : %d entite(s) de la classe, %d refigee(s) (neuves ou reactivees), %d refus ; %s",
          CLASSE, e.tick, n, frozen, refused, tally_text(by_type)))
      end
    end
  end

  S.finish = function(ctx)
    local poi = ctx.call("points_of_interest")
    ctx.check(poi ~= nil, "interface du mod lisible a la fin", poi and #poi.factions)
    if CLASSE ~= "temoin" then
      local list = members(ctx, CLASSE)
      local active = 0
      for i = 1, #list do if list[i].valid and list[i].active then active = active + 1 end end
      ctx.log(string.format("FIN %s : %d entite(s) de la classe, %d active(s)", CLASSE, #list, active))
      ctx.check(active <= math.max(5, math.floor(#list * 0.05)),
        "classe " .. CLASSE .. " restee figee jusqu'a la fin (au plus 5 % actives)", active .. " / " .. #list)
    end
    census(ctx, "fin")
  end

  return S
end
