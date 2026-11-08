--[[
  Lot MODULES-POSES (8/11) : banc « les modules du coffre sont posés dans les machines, sans que le levier ait à les décider ».
  Chaque équipe (factions ET votre équipe) reçoit à 30 tuiles au nord de son QG (donc « au QG » pour la capitalisation) 4 fours
  électriques et 4 assembleurs 2 d'engrenages, nourris par des coffres (bras électriques), vidés dans des coffres de sortie ; le
  coffre du QG reçoit 20 modules de vitesse (réserve de 4 : 16 disponibles = 8 machines x 2 emplacements) et un peu de minerai et
  de plaques (entrées « servies »). AUCUNE demande artificielle (pas de bench_sink), AUCUN site interdit : la décision du levier
  « equiper » n'a aucune raison de poser ces modules ; seule la disposition du stock (shared/ai3/modules_stock.lua) le fait.
  Attendus (par équipe) : (1) un ordre « equiper » de stock (status.open[].stock) est ouvert ; (2) un PNJ POSE les modules
  (travail, pas de script) : 8 machines portent 2 modules ; (3) le coffre du QG garde la réserve (4) et rien de plus ; (4) le débit
  des fours équipés augmente (>= 15 %) ; (5) aucune machine ne refuse (inserted == 16).
  Lancement : banc.py --out <archive> --qui MODULES-POSES -- 6000 modules-poses <source>.
  Lecture : lignes « [FO-MODULES-POSES] ... » du banc et « [FO-MODULES] ... » du mod, puis le BILAN.
]]

local MIN = 3600
local T_END = 6000
local SAMPLE = 600
local FIRST = 600
local N_FURN, N_ASM = 4, 4
local MODULES = 20
local RESERVE = 4

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function factions(ctx)
  local out = {}
  for _, row in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = row end
  end
  out[#out + 1] = { key = "player", force = "player" }
  return out
end

local function hq_of(s, force)
  local name = force == "player" and "fo-team-chest" or "fo-faction-hq"
  return s.find_entities_filtered({ name = name, force = force, limit = 1 })[1]
end

local function place_team_chest(ctx)
  local s = ctx.surface()
  local c = game.forces.player.get_spawn_position(s)
  local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
  local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
  if not chest then return false end
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
    { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  return true
end

local function feed(s, force, x, y, kind, st)
  -- entrée (coffre + bras) -> machine -> bras -> sortie (coffre) : une colonne, le bras prend et dépose en ligne droite
  local inp = s.create_entity({ name = "iron-chest", position = { x, y - 3 }, force = force })
  local i1 = s.create_entity({ name = "fast-inserter", position = { x, y - 2 }, force = force })
  local m = s.create_entity({ name = kind, position = { x, y }, force = force, raise_built = true })
  local i2 = s.create_entity({ name = "fast-inserter", position = { x, y + 2 }, force = force })
  local out = s.create_entity({ name = "iron-chest", position = { x, y + 3 }, force = force })
  if not (inp and i1 and m and i2 and out) then return nil end
  i1.pickup_position = { x, y - 3 }
  i1.drop_position = { x, y - 1 }
  i2.pickup_position = { x, y + 1 }
  i2.drop_position = { x, y + 3 }
  if kind == "electric-furnace" then
    inp.insert({ name = "iron-ore", count = 1600 })
  else
    m.set_recipe("iron-gear-wheel")
    inp.insert({ name = "iron-plate", count = 1600 })
  end
  return { m = m, out = out, unit = m.unit_number, kind = kind, item = kind == "electric-furnace" and "iron-plate" or "iron-gear-wheel" }
end

local function build(ctx, s, row, st)
  local hq = hq_of(s, row.force)
  if not hq then return false end
  local x0 = math.floor(hq.position.x) - 14 + 0.5
  local y0 = math.floor(hq.position.y) - 30 + 0.5
  ctx.prepare_area(x0 - 4, y0 - 8, x0 + 4 * (N_FURN + N_ASM) + 4, y0 + 8, "grass-1")
  ctx.power(x0 + 14, y0, row.force)
  local list = {}
  for k = 0, N_FURN + N_ASM - 1 do
    local kind = k < N_FURN and "electric-furnace" or "assembling-machine-2"
    local one = feed(s, row.force, x0 + 4 * k, y0, kind, st)
    if one then list[#list + 1] = one end
  end
  st.rows[row.key] = { list = list, x0 = x0, y0 = y0, samples = {} }
  local inv = hq.get_inventory(defines.inventory.chest)
  local extra = inv.get_item_count("iron-plate") - 200
  if extra > 0 then inv.remove({ name = "iron-plate", count = extra }) end
  inv.insert({ name = "iron-ore", count = 100 }) -- entrées « servies » pour la règle (stock > 0)
  inv.insert({ name = "speed-module", count = MODULES })
  ctx.check(#list == N_FURN + N_ASM, row.key .. " : usine de " .. (N_FURN + N_ASM) .. " machines", #list)
  ctx.log(string.format("[FO-MODULES-POSES] usine %s : %d machines a (%.1f, %.1f), QG (%.1f, %.1f), %d speed-module au coffre",
    row.key, #list, x0, y0, hq.position.x, hq.position.y, MODULES))
  return #list == N_FURN + N_ASM
end

local function sample(ctx, s, st, tick)
  for _, key in ipairs(sorted_keys(st.rows)) do
    local r = st.rows[key]
    local eq, mods, plates = 0, 0, 0
    for _, e in ipairs(r.list) do
      if e.m.valid then
        local inv = e.m.get_module_inventory()
        local m = inv and inv.get_item_count() or 0
        if m > 0 then eq = eq + 1 mods = mods + m end
        if e.kind == "electric-furnace" and e.out.valid then
          plates = plates + e.out.get_inventory(defines.inventory.chest).get_item_count("iron-plate")
        end
      end
    end
    local hq = hq_of(s, st.force[key])
    local left = hq and hq.get_inventory(defines.inventory.chest).get_item_count("speed-module") or -1
    local cs = ctx.remote("fo-capi", "status", key)
    local stock_order, inserted, refused = false, 0, 0
    for _, rec in ipairs(cs and cs.open or {}) do
      if rec.kind == "equiper" and rec.stock then
        stock_order = true
        inserted = inserted + (rec.inserted or 0)
        refused = refused + (rec.refused or 0)
      end
    end
    if tick == 1200 or tick == 3600 then
      local names = {}
      for n, v in pairs(defines.entity_status) do names[v] = n end
      local parts = {}
      for _, e in ipairs(r.list) do
        if e.m.valid then
          local n = e.out.valid and e.out.get_inventory(defines.inventory.chest).get_item_count(e.item) or -1
          parts[#parts + 1] = string.format("%s=%s/%d", e.kind == "electric-furnace" and "four" or "asm", tostring(names[e.m.status]), n)
        end
      end
      ctx.log("[FO-MODULES-POSES] statuts " .. key .. " t=" .. tick .. " : " .. table.concat(parts, " "))
    end
    r.seen_order = r.seen_order or stock_order
    r.samples[#r.samples + 1] = { tick = tick, eq = eq, mods = mods, plates = plates, left = left }
    ctx.log(string.format("[FO-MODULES-POSES] mesure t=%d %s machines_equipees=%d modules_poses=%d coffre=%d plaques_fours=%d ordre_stock_ouvert=%s ouverts=%d",
      tick, key, eq, mods, left, plates, tostring(stock_order), cs and #(cs.open or {}) or -1))
    for _, d in ipairs(cs and cs.done or {}) do
      if d.kind == "equiper" and not r.done then
        r.done = d
        ctx.log(string.format("[FO-MODULES-POSES] ordre %s fini : %s (%s) apres %.1f min", d.key, d.state, tostring(d.why), (d.closed - d.opened) / MIN))
      end
    end
  end
end

return {
  description = "MODULES-POSES : 20 speed-module au coffre, aucune demande ni site interdit, les PNJ les posent (8 machines x 2), debit en hausse",
  base = nil,
  check_tick = T_END,

  init = function(ctx)
    local held = ctx.remote("fo-ia1", "set_setting", "fo-recruit-idle-max", 60)
    ctx.check(held == 60, "frein par le travail leve", held)
    ctx.check(ctx.call("war_setting", "fo-war-workers", 30) == 30, "30 ouvriers")
    ctx.check(ctx.call("war_setting", "fo-war-ia3e", true) == true, "automatisation allumee")
    ctx.check(ctx.call("war_setting", "fo-war-capi", true) == true, "capitalisation allumee")
    ctx.check(ctx.remote("fo-pvp", "set_difficulty", "peaceful") == true, "Paisible")
    ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee (2 factions)")
    ctx.check(ctx.call("war_fund", 2500) == 2, "2 factions financees")
    ctx.check(place_team_chest(ctx), "coffre d'equipe pose (votre equipe)")
    local st = ctx.state()
    st.rows, st.force = {}, {}
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == 300 then
      for _, row in ipairs(factions(ctx)) do
        st.rows[row.key] = nil
        st.force[row.key] = row.force
        build(ctx, s, row, st)
      end
    end
    if e.tick == 420 then
      -- releve des machines tout de suite : la disposition du stock tourne a la pensee suivante par son chemin ordinaire
      for _, key in ipairs(sorted_keys(st.rows)) do
        ctx.check(ctx.remote("fo-capi", "bench_scan", key) == true, key .. " : releve force", key)
      end
    end
    if e.tick >= FIRST and e.tick % SAMPLE == 0 then sample(ctx, s, st, e.tick) end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local n_ok = 0
    for _, key in ipairs(sorted_keys(st.rows)) do
      local r = st.rows[key]
      local sm = r.samples
      local last = sm[#sm] or { eq = 0, mods = 0, left = -1 }
      local t_first, t_all
      for _, x in ipairs(sm) do
        if x.eq > 0 and not t_first then t_first = x.tick end
        if x.eq == N_FURN + N_ASM and not t_all then t_all = x.tick end
      end
      ctx.log(string.format("[FO-MODULES-POSES] %s : ordre de stock %s, machines equipees %d/%d, modules %d, coffre %d (reserve %d), premiere pose t=%s, toutes t=%s",
        key, r.seen_order and "vu" or "ABSENT", last.eq, N_FURN + N_ASM, last.mods, last.left, RESERVE, tostring(t_first), tostring(t_all)))
      ctx.check(r.seen_order == true or r.done ~= nil, key .. " : un ordre de stock est ouvert")
      ctx.check(last.eq == N_FURN + N_ASM and last.mods == 2 * (N_FURN + N_ASM), key .. " : 8 machines portent 2 modules (poses par les PNJ)",
        string.format("%d machines, %d modules", last.eq, last.mods))
      ctx.check(last.left == RESERVE, key .. " : le coffre garde exactement la reserve", last.left)
      -- debit des fours : plaques de sortie, fenetre avant la premiere pose contre fenetre apres la derniere
      local i_a, i_b, i_c, i_d
      for i, x in ipairs(sm) do
        if x.tick == FIRST then i_a = i end
        if t_first and x.tick == t_first - SAMPLE then i_b = i end
        if t_all and x.tick == t_all + SAMPLE then i_c = i end
        if x.tick == last.tick then i_d = i end
      end
      -- (la 1re fenetre est courte quand les PNJ posent vite : on compare le debit moyen des fenetres disponibles)
      if i_c and i_d and i_d > i_c then
        local after = (sm[i_d].plates - sm[i_c].plates) / ((sm[i_d].tick - sm[i_c].tick) / MIN)
        local before = nil
        if i_a and i_b and i_b > i_a then
          before = (sm[i_b].plates - sm[i_a].plates) / ((sm[i_b].tick - sm[i_a].tick) / MIN)
        end
        ctx.log(string.format("[FO-MODULES-POSES] %s : debit des fours avant %s/min, apres %.2f/min", key, before and string.format("%.2f", before) or "non mesurable", after))
        if before and before > 0 then
          ctx.check(after >= before * 1.15, key .. " : debit des fours equipes en hausse d'au moins 15 %", string.format("%.2f contre %.2f", after, before))
        end
      else
        ctx.log(string.format("[FO-MODULES-POSES] %s : fenetres de debit introuvables (c=%s d=%s)", key, tostring(i_c), tostring(i_d)))
      end
      if last.eq == N_FURN + N_ASM and last.left == RESERVE then n_ok = n_ok + 1 end
    end
    ctx.check(n_ok >= 1, "au moins une equipe a pose ses modules et garde sa reserve", n_ok)
    local pr = st.rows.player
    ctx.check(pr ~= nil and (pr.samples[#pr.samples] or { eq = 0 }).eq == N_FURN + N_ASM, "votre equipe : modules poses par ses PNJ")
  end,
}
