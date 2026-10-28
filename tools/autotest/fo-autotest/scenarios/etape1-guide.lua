--[[
  Étape 1 de la méthode du 27/10 au soir : la partie du guide du DC aux réglages livrés (30 ouvriers par faction,
  scenarios/verif_guide_common.lua), automatisation (fo-war-ia3e) et capitalisation (fo-war-capi) allumées.
  Toutes les 10 min, par faction ([FO-ETAPE1-GUIDE] « base ») : ce qui se voit sur une base (chaudières, machines à
  vapeur, poteaux, foreuses électriques et à combustion, tapis, fours, assembleurs, laboratoires, coffres posés),
  recherches faites, remplissage du coffre du QG et ce qu'il contient le plus.
  Images (session avec images) : ×8 hors des moments de photo ; à 10, 20, 40 et 60 min, par faction, la base au zoom
  0,25 et le QG au zoom 0,6.
  Lancement : banc.py --out <archive> --qui ETAPE1 --captures --visuel="--ticks 216200 --timeout 7200" -- 216200 etape1-guide <source>.
]]

local base = require("scenarios/verif_guide_common")(30)

local MIN = 3600
local EVERY = 10 * MIN
local PHOTOS = { [10 * MIN] = "10min", [20 * MIN] = "20min", [40 * MIN] = "40min", [60 * MIN] = "60min" }
local PHOTO_TICKS = { 10 * MIN, 20 * MIN, 40 * MIN, 60 * MIN }
local TAG = "[FO-ETAPE1-GUIDE] "

local function factions()
  local out = {}
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = row end
  end
  return out
end

local function hq_of(s, force)
  return s.find_entities_filtered({ name = "fo-faction-hq", force = force, limit = 1 })[1]
end

local function snap(s, name, x, y, zoom)
  local player = game.connected_players[1]
  if not player then return end
  game.take_screenshot({ player = player, surface = s, position = { x, y }, resolution = { 1600, 900 }, zoom = zoom,
    path = "fo-shots/etape1-" .. name .. ".png", show_entity_info = true, anti_alias = true, daytime = 0,
    allow_in_replay = true, force_render = true })
  log(TAG .. string.format("capture etape1-%s (%.1f, %.1f) zoom %.2f", name, x, y, zoom))
end

-- Lot COFFRE : annexes du QG (script/team/stock.lua) : coffres posés au sud du QG (rangées T.hq_rows.annex). Rend leur
-- nombre, leurs cases prises et leurs cases, et ajoute leur contenu à `cont` (le stock est le coffre ET les annexes).
local function annexes(s, pos, force, cont)
  local n, used, size = 0, 0, 0
  for _, e in ipairs(s.find_entities_filtered({ area = { { pos.x - 8, pos.y + 3 }, { pos.x + 16, pos.y + 22 } }, force = force,
    name = { "iron-chest", "wooden-chest" } })) do
    local inv = e.get_inventory(defines.inventory.chest)
    n, used, size = n + 1, used + #inv - inv.count_empty_stacks(), size + #inv
    for k, v in pairs(inv.get_contents()) do cont[k] = (cont[k] or 0) + v end
  end
  return n, used, size
end

local function report(s, minute)
  for _, r in ipairs(factions()) do
    local c = {}
    for _, ty in ipairs({ "boiler", "generator", "electric-pole", "transport-belt", "furnace", "assembling-machine",
      "lab", "container", "inserter" }) do
      c[ty] = s.count_entities_filtered({ force = r.force, type = ty })
    end
    local de, db = 0, 0
    for _, d in ipairs(s.find_entities_filtered({ force = r.force, type = "mining-drill" })) do
      if d.prototype.electric_energy_source_prototype then de = de + 1 else db = db + 1 end
    end
    local hq = hq_of(s, r.force)
    local fill, top = "?", ""
    local inv = hq and hq.get_inventory(defines.inventory.chest)
    if inv then
      local used = #inv - inv.count_empty_stacks()
      fill = string.format("%d/%d", used, #inv)
      local cont = inv.get_contents()
      local na, ua, sa = annexes(s, hq.position, r.force, cont)
      fill = fill .. string.format(" annexes=%d(%d/%d) dormants foreuses=%d fours=%d", na, ua, sa,
        cont["burner-mining-drill"] or 0, cont["stone-furnace"] or 0)
      local names = {}
      for n in pairs(cont) do names[#names + 1] = n end
      table.sort(names, function(a, b) if cont[a] ~= cont[b] then return cont[a] > cont[b] end return a < b end)
      local parts = {}
      for i = 1, math.min(8, #names) do parts[#parts + 1] = names[i] .. "=" .. cont[names[i]] end
      top = table.concat(parts, " ")
    end
    log(TAG .. string.format("base minute %d | %s | chaudieres=%d vapeur=%d poteaux=%d foreuses_elec=%d foreuses_comb=%d"
      .. " tapis=%d bras=%d fours=%d assembleurs=%d labos=%d coffres=%d | tech=%d n=%d | coffre_qg %s | %s",
      minute, r.key, c.boiler, c.generator, c["electric-pole"], de, db, c["transport-belt"], c.inserter, c.furnace,
      c["assembling-machine"], c.lab, c.container, r.tech or -1, r.n or -1, fill, top))
  end
end

-- Votre équipe (force « player ») : même relevé que les factions, coffre d'équipe au lieu du QG
local function report_player(s, minute)
  local c = {}
  for _, ty in ipairs({ "boiler", "generator", "electric-pole", "transport-belt", "furnace", "assembling-machine",
    "lab", "container", "inserter", "character" }) do
    c[ty] = s.count_entities_filtered({ force = "player", type = ty })
  end
  local de, db = 0, 0
  for _, d in ipairs(s.find_entities_filtered({ force = "player", type = "mining-drill" })) do
    if d.prototype.electric_energy_source_prototype then de = de + 1 else db = db + 1 end
  end
  -- foreuses par minerai visé et par état (diagnostic du fer : où sont les foreuses, tournent-elles ?)
  local per = {}
  for _, d in ipairs(s.find_entities_filtered({ force = "player", type = "mining-drill" })) do
    local tgt = d.mining_target and d.mining_target.name or "?"
    local st = (d.status == defines.entity_status.working) and "ok" or "arret"
    local k = tgt .. ":" .. st
    per[k] = (per[k] or 0) + 1
  end
  local pk = {}
  for k in pairs(per) do pk[#pk + 1] = k end
  table.sort(pk)
  local pp = {}
  for _, k in ipairs(pk) do pp[#pp + 1] = k .. "=" .. per[k] end
  log(TAG .. string.format("foreuses-joueur minute %d | %s", minute, table.concat(pp, " ")))
  local chest = s.find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
  local fill, top = "?", ""
  local inv = chest and chest.get_inventory(defines.inventory.chest)
  if inv then
    fill = string.format("%d/%d", #inv - inv.count_empty_stacks(), #inv)
    local cont = inv.get_contents()
    local na, ua, sa = annexes(s, chest.position, "player", cont)
    fill = fill .. string.format(" annexes=%d(%d/%d) dormants foreuses=%d fours=%d", na, ua, sa,
      cont["burner-mining-drill"] or 0, cont["stone-furnace"] or 0)
    local names = {}
    for n in pairs(cont) do names[#names + 1] = n end
    table.sort(names, function(a, b) if cont[a] ~= cont[b] then return cont[a] > cont[b] end return a < b end)
    local parts = {}
    for i = 1, math.min(8, #names) do parts[#parts + 1] = names[i] .. "=" .. cont[names[i]] end
    top = table.concat(parts, " ")
  end
  -- Lot FANTOMES : apercu en fantomes des paires que les PNJ vont poser ; orphelins = fantomes de foreuse sur la carte que
  -- le registre de l'apercu ne connait pas.
  if remote.interfaces["fo-fantomes"] then
    local fs = remote.call("fo-fantomes", "status")
    local scan = #s.find_entities_filtered({ force = "player", name = "entity-ghost", ghost_name = "burner-mining-drill" })
    log(TAG .. string.format("fantomes minute %d | aperceus en cours %d (%d fantomes dont %d foreuses) | carte : %d fantomes de foreuse | ORPHELINS %d | montres %d arrivee %d fin %d balayage %d",
      minute, fs.entries or 0, fs.live or 0, fs.drills or 0, scan, scan - (fs.drills or 0), fs.shown, fs.arrive, fs.fin, fs.balayage))
  end
  local techs = 0
  for _, tc in pairs(game.forces.player.technologies) do if tc.researched then techs = techs + 1 end end
  log(TAG .. string.format("base minute %d | VOTRE EQUIPE | chaudieres=%d vapeur=%d poteaux=%d foreuses_elec=%d foreuses_comb=%d"
    .. " tapis=%d bras=%d fours=%d assembleurs=%d labos=%d coffres=%d | tech=%d pnj=%d | coffre_equipe %s | %s",
    minute, c.boiler, c.generator, c["electric-pole"], de, db, c["transport-belt"], c.inserter, c.furnace,
    c["assembling-machine"], c.lab, c.container, techs, c.character, fill, top))
end

local init0, tick0, shots0 = base.init, base.tick, base.shots
base.description = "ETAPE1 : partie du guide, 30 ouvriers, automatisation et capitalisation allumees, photos 10/20/40/60 min"

base.init = function(ctx)
  local a = ctx.call("war_setting", "fo-war-ia3e", true)
  ctx.check(a == true, "reglage fo-war-ia3e allume", tostring(a))
  local b = ctx.call("war_setting", "fo-war-capi", true)
  ctx.check(b == true, "reglage fo-war-capi allume", tostring(b))
  if init0 then init0(ctx) end
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  local s = ctx.surface()
  if #game.connected_players > 0 then
    local want = 8
    for _, t in ipairs(PHOTO_TICKS) do if e.tick >= t - 600 and e.tick <= t + 120 then want = 1 end end
    if game.speed ~= want then game.speed = want end
    local moment = PHOTOS[e.tick]
    if moment then
      local chest = s.find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
      if chest then
        snap(s, "equipe-" .. moment .. "-base", chest.position.x, chest.position.y, 0.25)
        snap(s, "equipe-" .. moment .. "-coffre", chest.position.x, chest.position.y, 0.6)
      end
      for _, r in ipairs(factions()) do
        local hq = hq_of(s, r.force)
        if hq then
          snap(s, r.key .. "-" .. moment .. "-base", hq.position.x, hq.position.y, 0.25)
          snap(s, r.key .. "-" .. moment .. "-qg", hq.position.x, hq.position.y, 0.6)
        end
      end
    end
  end
  if e.tick > 0 and e.tick % EVERY == 0 then
    report(s, e.tick / MIN)
    report_player(s, e.tick / MIN)
    -- Plan directeur de VOTRE EQUIPE : ce qui retient chaque projet (diagnostic, lot JOUEUR)
    if (e.tick / MIN) % 10 == 0 then
      local okr, rep = pcall(remote.call, "fo-ia1d", "report", "player")
      if okr and rep then
        for _, pr in ipairs(rep.projects or {}) do
          local ub = {}
          for _, u in ipairs(pr.unbuilt or {}) do ub[#ub + 1] = string.format("%s@%d,%d f%d npc%d", u.name, u.x, u.y, u.fails, u.npc) end
          log(TAG .. string.format("projet-joueur minute %d | #%s %s %s (%d/%d) obst %d/%d | non poses %s",
            e.tick / MIN, tostring(pr.id), tostring(pr.state), tostring(pr.reason), pr.built or 0, pr.total or 0,
            pr.open_obstacles or 0, pr.obstacles or 0, table.concat(ub, "; ")))
        end
      end
    end
  end
end

base.shots = function(ctx, add)
  if shots0 then shots0(ctx, add) end
  local s = ctx.surface()
  for _, r in ipairs(factions()) do
    local hq = hq_of(s, r.force)
    if hq then add("etape1-" .. r.key .. "-fin", hq.position.x, hq.position.y, 0.25) end
  end
end
base.shots_delay = base.shots_delay or 214100

return base
