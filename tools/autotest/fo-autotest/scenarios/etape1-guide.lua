--[[
  Étape 1 de la méthode du 27/10 au soir : la partie du guide du DC aux réglages livrés (30 ouvriers par faction,
  scenarios/verif_guide_common.lua), automatisation (fo-war-ia3e) et capitalisation (fo-war-capi) allumées.
  Toutes les 10 min, par faction ([FO-ETAPE1-GUIDE] « base ») : ce qui se voit sur une base (chaudières, machines à
  vapeur, poteaux, foreuses électriques et à combustion, tapis, fours, assembleurs, laboratoires, coffres posés),
  recherches faites, remplissage du coffre du QG et ce qu'il contient le plus.
  Images (session avec images) : ×8 hors des moments de photo ; à 10, 20, 40 et 60 min, par faction, la base au zoom
  0,25 et le QG au zoom 0,6.
  Lot MESURES (28/10) : à côté de ces comptes de PRÉSENCE, indicateurs FONCTIONNELS lus sur le moteur, pour toutes les
  forces avec la même fonction (scenarios/fonction_common.lua, lignes [FO-FONCTION], fenêtres de 10 min, relevés d'état
  toutes les 30 s ; ce qu'ils prouvent : docs/PORTES_MESURES.md ; lecture : tools/autotest/fonction_mesures.py).
  La colonne `tech=` des lignes « base » est désormais le nombre de technologies TERMINÉES, pour votre équipe comme
  pour les factions (avant : pour les factions, le palier du plan `f.tech`, rendu ici par `palier=`).
  Lancement : banc.py --out <archive> --qui ETAPE1 --captures --visuel="--ticks 216200 --timeout 7200" -- 216200 etape1-guide <source>.
]]

local base = require("scenarios/verif_guide_common")(30)
local Fn = require("scenarios/fonction_common")

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
    local per_target = {}
    for _, d in ipairs(s.find_entities_filtered({ force = r.force, type = "mining-drill" })) do
      if d.prototype.electric_energy_source_prototype then de = de + 1 else db = db + 1 end
      local tg = d.mining_target and d.mining_target.name or "?"
      per_target[tg] = (per_target[tg] or 0) + 1
    end
    -- Lot KIT : foreuses par minerai visé et recherches FAITES de la force (critères : au moins 6 foreuses de minerai,
    -- une centrale à 30 min, plus de 5 recherches à 40 min)
    local tnames = {}
    for tg in pairs(per_target) do tnames[#tnames + 1] = tg end
    table.sort(tnames)
    local tparts = {}
    for _, tg in ipairs(tnames) do tparts[#tparts + 1] = tg .. ":" .. per_target[tg] end
    local fr, nres = game.forces[r.force], 0
    if fr then for _, tc in pairs(fr.technologies) do if tc.researched then nres = nres + 1 end end end
    local hq0 = hq_of(s, r.force)
    local inv0 = hq0 and hq0.get_inventory(defines.inventory.chest)
    local wood = inv0 and inv0.get_item_count("wood") or 0
    log(TAG .. string.format("kit-mesure minute %d | %s | foreuses %s | recherches_faites=%d | bois_coffre=%d",
      minute, r.key, table.concat(tparts, " "), nres, wood))
    local hq = hq_of(s, r.force)
    local fill, top = "?", ""
    local inv = hq and hq.get_inventory(defines.inventory.chest)
    if inv then
      local used = #inv - inv.count_empty_stacks()
      fill = string.format("%d/%d", used, #inv)
      local cont = inv.get_contents()
      local na, ua, sa = annexes(s, hq.position, r.force, cont)
      fill = fill .. string.format(" annexes=%d(%d/%d) dormants stock_foreuses=%d stock_fours=%d", na, ua, sa,
        cont["burner-mining-drill"] or 0, cont["stone-furnace"] or 0)
      local names = {}
      for n in pairs(cont) do names[#names + 1] = n end
      table.sort(names, function(a, b) if cont[a] ~= cont[b] then return cont[a] > cont[b] end return a < b end)
      local parts = {}
      for i = 1, math.min(8, #names) do parts[#parts + 1] = names[i] .. "=" .. cont[names[i]] end
      top = table.concat(parts, " ")
    end
    log(TAG .. string.format("base minute %d | %s | chaudieres=%d vapeur=%d poteaux=%d foreuses_elec=%d foreuses_comb=%d"
      .. " tapis=%d bras=%d fours=%d assembleurs=%d labos=%d coffres=%d | tech=%d palier=%s n=%d | coffre_qg %s | %s",
      minute, r.key, c.boiler, c.generator, c["electric-pole"], de, db, c["transport-belt"], c.inserter, c.furnace,
      c["assembling-machine"], c.lab, c.container, Fn.researched(r.force), tostring(r.tech or -1), r.n or -1, fill, top))
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
    fill = fill .. string.format(" annexes=%d(%d/%d) dormants stock_foreuses=%d stock_fours=%d", na, ua, sa,
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
  local techs = Fn.researched("player")
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
  -- Lot KIT : la partie du guide RÉELLE donne aux factions le kit de votre équipe (control.lua allume le kit généreux pour tous
  -- les bancs ; ici on l'éteint, avant la fondation par le lancement automatique).
  local k = ctx.call("war_setting", "fo-war-kit-genereux", false)
  ctx.check(k == false, "kit genereux des factions eteint (kit egal a celui du joueur)", tostring(k))
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
  -- Lot MESURES : relevés d'état toutes les 30 s (dès le tick 0), rapport fonctionnel par fenêtre de 10 min
  if e.tick % Fn.SAMPLE == 0 then
    local rows = remote.call("fo-ia1", "teams") or {}
    local forces = { { key = "player", force = "player" } }
    for _, r in ipairs(rows) do if r.key ~= "player" then forces[#forces + 1] = { key = r.key, force = r.force } end end
    if e.tick > 0 and e.tick % EVERY == 0 then
      Fn.sample_all(ctx.state(), s, forces, e.tick, rows)
      Fn.report_all(ctx.state(), s, forces, e.tick / MIN, e.tick, rows)
    else
      Fn.sample_all(ctx.state(), s, forces, e.tick, rows)
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
