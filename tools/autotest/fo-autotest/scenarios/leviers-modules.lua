--[[
  Lot LEVIERS (27/10) : banc dédié « un module posé augmente le débit du gain annoncé ». Chaque faction reçoit, à 30 tuiles
  au nord de son QG (donc « au QG » pour la capitalisation), une usine de 6 fours électriques nourris par un coffre de
  minerai (bras électrique) et vidés dans un coffre de plaques ; le coffre du QG reçoit des modules de productivité et de
  vitesse. TOUS les gisements de la faction sont déclarés interdits (remote fo-capi block_sites : même champ que « hors du
  plan directeur ») : l'extraction n'a plus aucune option, le repli doit choisir un levier.
  Attendus : (1) un ordre « equiper » est décidé et ouvert ; (2) un PNJ POSE les modules (travail, pas de script posant
  tout seul) ; (3) la ligne « repli : pourquoi » existe (status.repli) ; (4) le débit des plaques des fours équipés augmente
  de la sortie annoncée (rec.announced.d_out, ramenée aux fours réellement équipés) à ± 10 %.
  Lancement : banc.py --out <archive> --qui LEVIERS -- 30000 leviers-modules <source>.
  Lecture : lignes « [FO-LEVIERS-MODULES] mesure ... » et le BILAN.
]]

local MIN = 3600
local T_END = 30000
local SAMPLE = 600
local FIRST = 1800
local N_FURN = 6

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
  return out
end

local function hq_of(s, force)
  return s.find_entities_filtered({ name = "fo-faction-hq", force = force, limit = 1 })[1]
end

local function build(ctx, s, row, st)
  local hq = hq_of(s, row.force)
  if not hq then return false end
  local x0 = math.floor(hq.position.x) - 12 + 0.5
  local y0 = math.floor(hq.position.y) - 30 + 0.5
  ctx.prepare_area(x0 - 4, y0 - 8, x0 + 4 * N_FURN + 4, y0 + 8, "grass-1")
  ctx.power(x0 + 10, y0, row.force)
  local list = {}
  for k = 0, N_FURN - 1 do
    local fx = x0 + 4 * k
    local ore = s.create_entity({ name = "iron-chest", position = { fx, y0 - 4.5 }, force = row.force })
    local i1 = s.create_entity({ name = "inserter", position = { fx, y0 - 2.5 }, force = row.force })
    local fu = s.create_entity({ name = "electric-furnace", position = { fx, y0 }, force = row.force, raise_built = true })
    local i2 = s.create_entity({ name = "inserter", position = { fx, y0 + 2.5 }, force = row.force })
    local out = s.create_entity({ name = "iron-chest", position = { fx, y0 + 4.5 }, force = row.force })
    if ore and i1 and fu and i2 and out then
      i1.pickup_position = { fx, y0 - 4.5 }
      i1.drop_position = { fx, y0 - 1.6 }
      i2.pickup_position = { fx, y0 + 1.6 }
      i2.drop_position = { fx, y0 + 4.5 }
      ore.insert({ name = "iron-ore", count = 1600 }) -- 32 cases de 50 : 40 min de minerai à 37,5 par minute
      list[#list + 1] = { fu = fu, out = out, unit = fu.unit_number }
    end
  end
  st.rows[row.key] = { list = list, x0 = x0, y0 = y0 }
  -- Modules au coffre du QG (le stock d'une faction est son coffre et ses annexes).
  local inv = hq.get_inventory(defines.inventory.chest)
  for _, m in ipairs({ { "productivity-module", 60 }, { "speed-module", 60 }, { "productivity-module-2", 60 }, { "speed-module-2", 60 } }) do
    inv.insert({ name = m[1], count = m[2] })
  end
  local blocked = ctx.remote("fo-capi", "block_sites", row.key, true)
  ctx.check(#list == N_FURN and blocked == true, row.key .. " : usine de " .. N_FURN .. " fours, sites interdits", #list)
  ctx.log(string.format("usine %s : %d fours a (%.1f, %.1f), QG (%.1f, %.1f)", row.key, #list, x0, y0, hq.position.x, hq.position.y))
  return #list == N_FURN
end

local function sample(ctx, s, st, tick)
  for _, key in ipairs(sorted_keys(st.rows)) do
    local r = st.rows[key]
    local plates, eq, mods = 0, 0, 0
    local per = {}
    for i, f in ipairs(r.list) do
      if f.out.valid and f.fu.valid then
        local n = f.out.get_inventory(defines.inventory.chest).get_item_count("iron-plate")
        local inv = f.fu.get_module_inventory()
        local m = inv and inv.get_item_count() or 0
        plates = plates + n
        per[i] = { n = n, m = m }
        if m > 0 then eq = eq + 1 mods = mods + m end
      end
    end
    r.samples[#r.samples + 1] = { tick = tick, per = per, eq = eq, mods = mods }
    local cs = ctx.remote("fo-capi", "status", key)
    local o = nil
    for _, rec in ipairs(cs and cs.open or {}) do if rec.kind == "equiper" then o = rec end end
    if o and o.announced and not r.ann then
      r.ann = { d_out = o.announced.d_out, item = o.announced.item, n = o.n, module = o.module, per = o.per, tick = tick }
      ctx.log(string.format("ordre %s : equiper %d x %s (%d par four), sortie annoncee +%.2f/min, tick %d", key, o.n, tostring(o.module),
        o.per or 0, o.announced.d_out or 0, tick))
    end
    for _, d in ipairs(cs and cs.done or {}) do
      if d.kind == "equiper" and not r.done then
        r.done = d
        ctx.log(string.format("ordre %s fini : %s (%s) apres %.1f min", d.key, d.state, tostring(d.why), (d.closed - d.opened) / MIN))
      end
    end
    if cs and cs.repli and not r.repli then
      r.repli = cs.repli
      ctx.log("repli " .. key .. " : " .. cs.repli)
    end
    ctx.log(string.format("mesure t=%d %s plaques=%d fours_equipes=%d modules=%d ordres_ouverts=%d", tick, key, plates, eq, mods,
      cs and #(cs.open or {}) or -1))
  end
end

return {
  description = "LEVIERS : modules inseres par les PNJ dans des fours, tous les sites interdits, debit mesure contre le gain annonce",
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
    local st = ctx.state()
    st.rows = {}
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == 300 then
      for _, row in ipairs(factions(ctx)) do
        st.rows[row.key] = nil
        build(ctx, s, row, st)
        if st.rows[row.key] then st.rows[row.key].samples = {} end
      end
    end
    if e.tick >= FIRST and e.tick % SAMPLE == 0 then sample(ctx, s, st, e.tick) end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local any_order, any_pose, any_ok = false, false, false
    for _, key in ipairs(sorted_keys(st.rows)) do
      local r = st.rows[key]
      local sm = r.samples
      local last = sm[#sm]
      -- Fours équipés à la fin (relevé du dernier échantillon) et date de la première pose.
      local eq_set = {}
      for i, p in ipairs(last and last.per or {}) do if p.m > 0 then eq_set[i] = p.m end end
      local n_eq = 0
      for _ in pairs(eq_set) do n_eq = n_eq + 1 end
      local t_first, t_all = nil, nil
      for _, x in ipairs(sm) do
        if x.eq > 0 and not t_first then t_first = x.tick end
        if x.eq == n_eq and n_eq > 0 and not t_all then t_all = x.tick end
      end
      ctx.log(string.format("%s : ordre %s, repli %s, fours equipes %d (premiere pose t=%s, derniere t=%s)", key,
        r.ann and "emis" or "ABSENT", r.repli and "ecrit" or "ABSENT", n_eq, tostring(t_first), tostring(t_all)))
      if r.ann then any_order = true end
      if n_eq > 0 then any_pose = true end
      ctx.check(r.repli ~= nil, key .. " : ligne repli (pourquoi) ecrite", r.repli)
      if r.ann and n_eq > 0 and t_first and t_all then
        local function total(sample_i)
          local sum = 0
          for i in pairs(eq_set) do sum = sum + ((sm[sample_i].per[i] or {}).n or 0) end
          return sum
        end
        local i_a, i_b, i_c, i_d
        for i, x in ipairs(sm) do
          if x.tick == FIRST then i_a = i end
          if x.tick == t_first - SAMPLE then i_b = i end
          if x.tick == t_all + SAMPLE then i_c = i end
          if x.tick == last.tick then i_d = i end
        end
        if i_a and i_b and i_c and i_d and i_b > i_a and i_d > i_c then
          local before = (total(i_b) - total(i_a)) / ((sm[i_b].tick - sm[i_a].tick) / MIN)
          local after = (total(i_d) - total(i_c)) / ((sm[i_d].tick - sm[i_c].tick) / MIN)
          local gain = after - before
          local want = r.ann.d_out * n_eq / math.max(1, r.ann.n)
          local err = want ~= 0 and math.abs(gain - want) / math.abs(want) or 1
          ctx.log(string.format("MESURE %s : %d fours, avant %.2f/min, apres %.2f/min, gain mesure %.2f/min, annonce %.2f/min, ecart %.1f %%",
            key, n_eq, before, after, gain, want, err * 100))
          ctx.check(err <= 0.10, key .. " : gain mesure = gain annonce a 10 %", string.format("%.2f contre %.2f", gain, want))
          if err <= 0.10 then any_ok = true end
        else
          ctx.log(string.format("%s : fenetres de mesure introuvables (a=%s b=%s c=%s d=%s)", key, tostring(i_a), tostring(i_b),
            tostring(i_c), tostring(i_d)))
          ctx.check(false, key .. " : fenetres de mesure (avant et apres la pose)")
        end
      end
    end
    ctx.check(any_order, "un ordre de module decide (au moins une faction)")
    ctx.check(any_pose, "des modules poses par les PNJ (au moins une faction)")
    ctx.check(any_ok, "le debit mesure suit la sortie annoncee a 10 % (au moins une faction)")
  end,
}
