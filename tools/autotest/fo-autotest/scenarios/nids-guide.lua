--[[
  Lot NIDS (nuit du 28 au 29/10) : etape1-guide (la partie du guide, 30 ouvriers par faction, 216 300 ticks) + relevés de
  l'ÉTAT MOTEUR pour juger le nettoyage des nids menaçants par les factions. OBSERVATION SEULE : aucune action sur la partie.
  Relevés (journal [FO-NIDS-MES]), par faction « fo-* » :
    - événements (comptés par le scénario, pas par le mod) : nids ennemis détruits par la force de la faction, nids détruits
      par une autre force, soldats de la faction morts (toutes causes / par l'ennemi), bâtiments et tourelles de la faction
      détruits par l'ennemi ;
    - toutes les 30 s : soldats vivants, soldats INACTIFS (sans groupe du moteur, à 100 tuiles du QG au plus), nids ennemis
      vivants à moins de 250 tuiles du QG (moteur), sites de nid CONNUS de la faction et sites menaçants (interface fo-nids
      du mod, lecture seule) ;
    - toutes les 10 min : cumuls et compteurs du mod (opérations, nids détruits selon le mod, replis, délais).
  Lecture : py -3.9 -B tools/autotest/nids_mesures.py <archive> [<archive> …] [--temoin <archive> …].
  Lancement : banc.py --out <archive> --qui NIDS -- 216300 nids-guide <source> (graine : --graine N).
  Témoin « réglage éteint » : nids-guide-temoin (même partie, fo-war-nids coupé).
]]
local base = require("scenarios/etape1-guide")
local tick0 = base.tick
local TAG = "[FO-NIDS-MES] "
local MIN = 3600
local SAMPLE = 1800
local NEAR_HQ = 100
local NEST_R = 250

local function G()
  global.nids_mes = global.nids_mes or { nests = {}, nests_other = 0, sold_dead = {}, sold_killed = {}, bld_killed = {}, tur_killed = {},
    nests_seen = 0 }
  return global.nids_mes
end

local function bump(tab, k, n) tab[k] = (tab[k] or 0) + (n or 1) end

script.on_event(defines.events.on_entity_died, function(e)
  local ent = e.entity
  if not (ent and ent.valid) then return end
  local m = G()
  local fname = ent.force and ent.force.name or ""
  local kname = e.force and e.force.name or ""
  if ent.type == "unit-spawner" then
    if kname:sub(1, 3) == "fo-" then bump(m.nests, kname) else m.nests_other = m.nests_other + 1 end
    return
  end
  if fname:sub(1, 3) ~= "fo-" then return end
  if ent.type == "unit" then
    bump(m.sold_dead, fname)
    if kname == "enemy" then bump(m.sold_killed, fname) end
  elseif kname == "enemy" then
    bump(m.bld_killed, fname)
    if ent.type == "ammo-turret" or ent.type == "electric-turret" or ent.type == "fluid-turret" or ent.type == "turret" then
      bump(m.tur_killed, fname)
    end
  end
end)

local function factions()
  local out = {}
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = row end
  end
  return out
end

local function kv(tab, force) return tab[force] or 0 end

base.description = (base.description or "") .. " + releves de l'etat moteur des nids (NIDS)"
base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick == 0 or e.tick % SAMPLE ~= 0 then return end
  local s = ctx.surface()
  local m = G()
  for _, r in ipairs(factions()) do
    local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = r.force, limit = 1 })[1]
    if hq then
      local units = s.find_entities_filtered({ type = "unit", force = r.force })
      local idle = 0
      for _, u in ipairs(units) do
        local g = u.unit_group
        local dx, dy = u.position.x - hq.position.x, u.position.y - hq.position.y
        if not (g and g.valid) and dx * dx + dy * dy <= NEAR_HQ * NEAR_HQ then idle = idle + 1 end
      end
      local nests = s.count_entities_filtered({ position = hq.position, radius = NEST_R, force = "enemy", type = "unit-spawner" })
      local ok, st = pcall(remote.call, "fo-nids", "status", r.key)
      local known, menacing, ops = -1, -1, -1
      if ok and st then known, menacing, ops = #st.sites, st.menacing, st.stats.ops or 0 end
      log(TAG .. string.format("echantillon tick %d | %s | soldats=%d inactifs=%d nids_moteur_250=%d sites_connus=%d sites_menacants=%d ops_mod=%d",
        e.tick, r.key, #units, idle, nests, known, menacing, ops))
      if e.tick % (10 * MIN) == 0 or e.tick / MIN == 12 then
        local mod = (ok and st) and st.stats or {}
        log(TAG .. string.format("minute %d | %s | soldats=%d tourelles=%d nids_detruits_moteur=%d soldats_morts=%d soldats_tues_ennemi=%d batiments_tues_ennemi=%d tourelles_tuees_ennemi=%d | mod : ops=%d fin=%d detruits=%d replis=%d delais=%d incidents=%d perdus_en_op=%d engages=%d",
          e.tick / MIN, r.key, #units, r.turrets or -1, kv(m.nests, r.force), kv(m.sold_dead, r.force), kv(m.sold_killed, r.force),
          kv(m.bld_killed, r.force), kv(m.tur_killed, r.force), mod.ops or 0, mod.ops_end or 0, mod.destroyed or 0, mod.retreat or 0,
          mod.timeout or 0, mod.incidents or 0, mod.lost or 0, mod.engaged or 0))
      end
    end
  end
end
return base
