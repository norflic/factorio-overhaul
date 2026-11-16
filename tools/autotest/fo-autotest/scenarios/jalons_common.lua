-- Lot JALONS (14/11) : partie du DC aux réglages livrés (lancement automatique, 30 ouvriers), VOTRE ÉQUIPE fondée d'office
-- et jouée par l'IA sans avantage (comme s43-parite-seule) + 4 factions = 5 équipes, sur 30 min, plus :
--  * chaque minute, une ligne [FO-JALON] par équipe : foreuses électriques EN MARCHE par ressource minée, fours en marche,
--    assembleurs (total / en marche), plaques de fer et de cuivre produites (statistiques de la force) ;
--  * la minute du 1er assembleur posé, de la 1re foreuse électrique en marche sur chaque ressource et du 1er four en
--    marche (ligne [FO-JALON-PREMIERS], preuve du verrou des tiers : aucun assembleur avant l'extraction et la fonte) ;
--  * captures du QG de chaque équipe à 15 et 30 min : fo-shots/jalon-m015-<équipe>.png (session avec images).
-- Lecture : tools/autotest/jalons.py <archive>.
return function(DUREE)
local base = require("scenarios/verif_guide_common")(30, true)
local Cc = require("scenarios/cul_classe") -- N100-IMPASSES : classe d'un tapis chargé sans sortie (règle pure)
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

-- N098 (mandat de nuit, captures 220200 et 220208 du DC) : sonde des tapis en CUL-DE-SAC (tapis sans sortie, chargé, qu'aucun bras ne
-- vide) et des lignes COUPÉES PAR UN POTEAU (tapis sans sortie dont la case suivante porte un poteau et la case d'après un tapis du même
-- sens). Une ligne [FO-CUL-DE-SAC] par équipe (compte et 5 premières positions) ; captures des 2 premiers cas du joueur en session images.
local DIRV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }

-- N100-IMPASSES : chaque cul-de-sac (et chaque entrée de souterrain chargée sans sortie appariée) reçoit une CLASSE (scenarios/cul_classe.lua) :
-- bras qui prennent sur la ligne (la dernière tuile et l'amont), pièce de transport planifiée non posée à la case suivante, détenteur de la
-- case au plan (remote fo-ia1.plan_at). Une ligne [FO-CUL-CLASSE] par équipe (compte par classe ; « impasse » = les vraies : rien n'est pris
-- de la ligne et rien n'est prévu après) ; une ligne [FO-CUL-DETAIL] par cas (au plus 12 par équipe et par relevé, toutes les impasses).
local function pieces_txt(r)
  if not r then return "?" end
  local o = {}
  for _, q in ipairs(r.pieces or {}) do
    o[#o + 1] = string.format("p%d/%s/%s/pr%s/c%s/%s/%s/d%d/%s%s/f%d%s", q.pid, q.state, q.site, tostring(q.pr), tostring(q.coal), q.role, q.name, q.dir,
      q.built and "pose" or "nonpose", q.dropped and "/saute" or "", q.fails, q.ug and ("/" .. tostring(q.ug)) or "")
  end
  return "occ=" .. tostring(r.occ) .. "[" .. table.concat(o, ";") .. "]"
end

local BELT_T = { ["transport-belt"] = true, ["underground-belt"] = true, ["splitter"] = true }
local function transport(name)
  local pr = name and game.entity_prototypes[name]
  return pr ~= nil and BELT_T[pr.type] == true
end

-- tuiles de la ligne (le tapis et l'amont, souterrains appariés suivis), au plus 400 ; rend (tuiles, longueur, tête, boîte)
local function line_of(b)
  local tiles, cur, len, seen = {}, b, 0, {}
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  while cur and len < 400 do
    local k = string.format("%g:%g", cur.position.x, cur.position.y)
    if seen[k] then break end
    seen[k] = true
    local tx, ty = math.floor(cur.position.x), math.floor(cur.position.y)
    tiles[tx .. ":" .. ty] = true
    x0, y0, x1, y1 = math.min(x0, tx), math.min(y0, ty), math.max(x1, tx), math.max(y1, ty)
    local ins = cur.belt_neighbours.inputs
    local nx
    if #ins == 0 and cur.type == "underground-belt" and cur.belt_to_ground_type == "output" then nx = cur.neighbours
    else nx = ins[1] end
    if not nx then break end
    cur, len = nx, len + 1
  end
  return tiles, len, cur, { x0, y0, x1, y1 }
end

-- nombre de bras de l'équipe dont la prise est sur une tuile de la ligne
local function takers(s, force, tiles, box)
  local n = 0
  for _, i in ipairs(s.find_entities_filtered({ area = { { box[1] - 3, box[2] - 3 }, { box[3] + 4, box[4] + 4 } }, type = "inserter", force = force })) do
    local q = i.pickup_position
    if tiles[math.floor(q.x) .. ":" .. math.floor(q.y)] then n = n + 1 end
  end
  return n
end

local function plan_at(key, x, y)
  local ok, r = pcall(remote.call, "fo-ia1", "plan_at", key, x, y)
  return ok and r or nil
end

local function own_pid(r, x, y)
  for _, q in ipairs(r and r.pieces or {}) do if transport(q.name) then return q.pid end end
  return nil
end

local function unbuilt_transport(r)
  for _, q in ipairs(r and r.pieces or {}) do if transport(q.name) and not q.built then return true end end
  return false
end

-- Analyse d'un tapis chargé sans sortie : rend (classe, ligne de détail). Souterrain d'entrée sans paire : `ug` vrai (la case « suivante »
-- est alors cherchée jusqu'à la portée du souterrain : une sortie planifiée non posée est un chantier).
local function analyse(s, force, key, minute, b, x, y, fx, fy, ug)
  local items = {}
  for li = 1, 2 do
    for nm, c in pairs(b.get_transport_line(li).get_contents()) do items[nm] = (items[nm] or 0) + c end
  end
  local tx, ty = math.floor(fx), math.floor(fy)
  local nxt = {}
  for _, e in ipairs(s.find_entities_filtered({ area = { { tx + 0.05, ty + 0.05 }, { tx + 0.95, ty + 0.95 } } })) do
    if e.valid and e.type ~= "resource" and #nxt < 4 then
      nxt[#nxt + 1] = string.format("%s%s/%s/d%d", e.name, e.name == "entity-ghost" and (":" .. e.ghost_name) or "", e.force.name, e.direction or 0)
    end
  end
  local tiles, len, head, box = line_of(b)
  local nt = takers(s, force, tiles, box)
  local here = plan_at(key, x, y)
  local there = plan_at(key, fx, fy)
  local pending = unbuilt_transport(there)
  if ug and not pending then
    local d = DIRV[b.direction]
    local reach = (b.prototype.max_underground_distance or 0)
    for i = 2, reach do
      if unbuilt_transport(plan_at(key, x + d[1] * i, y + d[2] * i)) then pending = true break end
    end
  end
  local own = own_pid(here)
  local cl = Cc.classe({ suite_a_poser = pending, souterrain_seul = ug, preneurs = nt, occ_suiv = there and there.occ, propre = own })
  local txt = string.format("[FO-CUL-DETAIL] minute=%d equipe=%s classe=%s pos=(%g,%g) %s d%d objets=%s preneurs=%d | suiv=(%g,%g) [%s] | ici %s | suiv %s | amont=%d tete=(%g,%g)",
    minute, tostring(key), cl, x, y, b.name, b.direction, kv(items), nt, fx, fy, table.concat(nxt, ";"),
    pieces_txt(here), pieces_txt(there), len, head.position.x, head.position.y)
  return cl, txt
end

local function culs(ctx, minute)
  local s = ctx.surface()
  local p = game.connected_players[1]
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    local force = row.force and game.forces[row.force]
    if force then
      local n, cut, pos, cutpos = 0, 0, {}, {}
      local by, nd = {}, 0
      for _, b in ipairs(s.find_entities_filtered({ force = force, type = { "transport-belt", "underground-belt" } })) do
        local ug_in = b.valid and b.type == "underground-belt" and b.belt_to_ground_type == "input"
        if ug_in and b.neighbours == nil then
          -- N100-IMPASSES : entrée de souterrain sans sortie appariée (paire amputée), chargée : classée à part (la sonde d'avant l'ignorait)
          local items = b.get_transport_line(1).get_item_count() + b.get_transport_line(2).get_item_count()
          if items >= 6 then
            local d = DIRV[b.direction]
            local cl, txt = analyse(s, force, row.key, minute, b, b.position.x, b.position.y, b.position.x + d[1], b.position.y + d[2], true)
            by[cl] = (by[cl] or 0) + 1
            nd = nd + 1
            if nd <= 12 then log(txt) end
          end
        elseif b.valid and not ug_in and #b.belt_neighbours.outputs == 0 then
          local d = DIRV[b.direction]
          local x, y = b.position.x, b.position.y
          local fx, fy = x + d[1], y + d[2]
          local pole = s.find_entities_filtered({ position = { fx, fy }, radius = 0.4, type = "electric-pole", force = force, limit = 1 })[1]
          local after = pole and s.find_entities_filtered({ position = { fx + d[1], fy + d[2] }, radius = 0.4, type = { "transport-belt", "underground-belt" }, force = force, limit = 1 })[1]
          if after and after.direction == b.direction then
            cut = cut + 1
            if #cutpos < 5 then cutpos[#cutpos + 1] = string.format("(%g,%g)", fx, fy) end
            if p and cut <= 1 then
              game.take_screenshot({ player = p, surface = s, position = { fx, fy }, resolution = { 960, 720 }, zoom = 1,
                path = string.format("fo-shots/coupe-poteau-m%03d-%s-%d.png", minute, tostring(row.key), cut), show_entity_info = true,
                daytime = 0, allow_in_replay = true, force_render = true })
            end
          else
            local items = b.get_transport_line(1).get_item_count() + b.get_transport_line(2).get_item_count()
            if items >= 6 then
              local picked = false
              for _, i in ipairs(s.find_entities_filtered({ position = { x, y }, radius = 2.5, type = "inserter", force = force })) do
                local q = i.pickup_position
                if math.floor(q.x) == math.floor(x) and math.floor(q.y) == math.floor(y) then picked = true break end
              end
              if not picked then
                n = n + 1
                if #pos < 5 then pos[#pos + 1] = string.format("(%g,%g)", x, y) end
                local cl, txt = analyse(s, force, row.key, minute, b, x, y, fx, fy, false)
                by[cl] = (by[cl] or 0) + 1
                nd = nd + 1
                if nd <= 12 or cl == "impasse" then log(txt) end
                if p and n <= 2 then
                  local file = string.format("fo-shots/cul-de-sac-m%03d-%s-%d.png", minute, tostring(row.key), n)
                  game.take_screenshot({ player = p, surface = s, position = { x, y }, resolution = { 960, 720 }, zoom = 1,
                    path = file, show_entity_info = true, daytime = 0, allow_in_replay = true, force_render = true })
                end
              end
            end
          end
        end
      end
      log(string.format("[FO-CUL-DE-SAC] minute=%d equipe=%s culs_de_sac=%d %s coupes_poteau=%d %s", minute, tostring(row.key), n,
        table.concat(pos, " "), cut, table.concat(cutpos, " ")))
      -- N100-IMPASSES : les mêmes cas (et les souterrains amputés) par classe (scenarios/cul_classe.lua) ; « impasses » = les vraies
      local parts = {}
      for _, c in ipairs(Cc.CLASSES) do parts[#parts + 1] = c .. "=" .. tostring(by[c] or 0) end
      log(string.format("[FO-CUL-CLASSE] minute=%d equipe=%s %s", minute, tostring(row.key), table.concat(parts, " ")))
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
base.description = "JALONS : votre equipe (sans humain) + 4 factions, " .. DUREE .. " min, [FO-JALON] chaque minute, captures des QG a 15 et 30 min"
base.check_tick = DUREE * MIN
base.init = function(ctx)
  init0(ctx)
  ctx.check(ctx.remote("factorio-overhaul", "war_setting", "fo-war-factions", 4) == 4, "4 factions")
end
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick > 0 and e.tick % MIN == 0 and e.tick <= DUREE * MIN then
    local ok, err = pcall(jalon, ctx, e.tick)
    if not ok then log(TAG .. "ERREUR " .. tostring(err)) end
  end
  if e.tick > 0 and (e.tick % (30 * MIN) == 0 or e.tick == DUREE * MIN - 600) and e.tick <= DUREE * MIN then
    local ok, err = pcall(culs, ctx, math.floor(e.tick / MIN + 0.5))
    if not ok then log("[FO-CUL-DE-SAC] ERREUR " .. tostring(err)) end
  end
  if e.tick == 15 * MIN then
    local ok, err = pcall(shots, ctx, 15)
    if not ok then log(TAG .. "ERREUR capture " .. tostring(err)) end
  end
end
-- captures de 30 min par le pilote (shots.lua, vérifiées) : vue du QG de chaque équipe
base.shots_delay = DUREE * MIN + 400
base.shots = function(ctx, add)
  local s = ctx.surface()
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    local hq = row.force and hq_of(s, row.force)
    if hq then
      add(string.format("jalon-m%03d-%s", DUREE, tostring(row.key):gsub("[^%w%-]", "_")), hq.position.x, hq.position.y, 0.18, 0,
        { res = { 1920, 1080 }, info = true, aa = true })
    end
  end
end
return base
end
