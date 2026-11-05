--[[
  Lot DEPENSES2 (4/11, demande du DC au QCM-4/11-SUITE : « Dépenses du stock dormant [...] et investir en recherche, armement ») :
  SONDE en LECTURE SEULE greffée sur une partie existante (verif-guide, ageblocage-dc). Rien n'est écrit dans le mod.
  Toutes les DIAG_EVERY ticks (et à la minute 59), pour CHAQUE équipe (factions et votre équipe, interface fo-ia1) :
    [FO-DEPENSES-DIAG] C   : coffres du QG et annexes (rayon 26, comme [FO-REGARD]) : sommes par famille et les objets les plus nombreux ;
    [FO-DEPENSES-DIAG] L   : laboratoires (nombre, en marche, sans pack), packs dedans, recherche courante, avancement, technologies faites ;
    [FO-DEPENSES-DIAG] P   : packs et munitions produits et consommés depuis le relevé précédent (statistiques de la force) ;
    [FO-DEPENSES-DIAG] A   : tourelles (par type), munitions dedans, tourelles à sec, soldats, âge (centre).
  Lu par tools/autotest/depenses_diag.py.
]]

return function(base)
local DIAG_EVERY = 5 * 3600
local RADIUS = 26
local TOP = 14

local init0, tick0 = base.init, base.tick

local function hq_position(s, force)
  local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = force, limit = 1 })[1]
  if hq and hq.valid then return hq.position end
  return game.forces.player.get_spawn_position(s)
end

local function teams()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  return ok and rows or {}
end

local function family(name)
  local p = game.item_prototypes[name]
  if not p then return "autre" end
  if name:find("science%-pack$") then return "packs" end
  if p.type == "ammo" then return "munitions" end
  local pr = p.place_result
  if pr and (pr.type == "ammo-turret" or pr.type == "electric-turret" or pr.type == "fluid-turret") then return "tourelles" end
  if name == "iron-plate" or name == "copper-plate" or name == "steel-plate" then return "plaques" end
  if name == "iron-gear-wheel" or name == "electronic-circuit" or name == "copper-cable" or name == "advanced-circuit"
    or name == "engine-unit" or name == "iron-stick" or name == "plastic-bar" then return "intermediaires" end
  if p.type == "item" and pr == nil then return "matieres" end
  return "batiments"
end

local function sorted(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function kv(t)
  local parts = {}
  for _, k in ipairs(sorted(t)) do parts[#parts + 1] = k .. "=" .. math.floor(t[k] + 0.5) end
  return table.concat(parts, " ")
end

local PACK_NAMES = nil
local function pack_names()
  if PACK_NAMES then return PACK_NAMES end
  PACK_NAMES = {}
  for name, p in pairs(game.item_prototypes) do
    if p.type == "tool" and name:find("science%-pack$") then PACK_NAMES[#PACK_NAMES + 1] = name end
  end
  table.sort(PACK_NAMES)
  return PACK_NAMES
end

local AMMO_NAMES = nil
local function ammo_names()
  if AMMO_NAMES then return AMMO_NAMES end
  AMMO_NAMES = {}
  for name, p in pairs(game.item_prototypes) do
    if p.type == "ammo" then AMMO_NAMES[#AMMO_NAMES + 1] = name end
  end
  table.sort(AMMO_NAMES)
  return AMMO_NAMES
end

local function flows(force, names)
  local stats = force.item_production_statistics
  local inp, out = {}, {}
  for _, n in ipairs(names) do
    inp[n] = stats.get_input_count(n)
    out[n] = stats.get_output_count(n)
  end
  return inp, out
end

local function releve(ctx, tick)
  local s = ctx.surface()
  local st = ctx.state()
  st.prev = st.prev or {}
  local m = math.floor(tick / 3600 + 0.5)
  for _, row in ipairs(teams()) do
    local force = game.forces[row.force]
    if force then
      local key = row.key or row.force
      local hq = hq_position(s, force)
      -- C : coffres
      local items = {}
      for _, c in ipairs(s.find_entities_filtered({ type = { "container", "logistic-container" }, force = force, position = hq, radius = RADIUS })) do
        if c.valid then
          for name, n in pairs(c.get_inventory(defines.inventory.chest).get_contents()) do items[name] = (items[name] or 0) + n end
        end
      end
      local fam, total = {}, 0
      local list = {}
      for _, name in ipairs(sorted(items)) do
        local f = family(name)
        fam[f] = (fam[f] or 0) + items[name]
        total = total + items[name]
        list[#list + 1] = name
      end
      table.sort(list, function(a, b) if items[a] ~= items[b] then return items[a] > items[b] end return a < b end)
      local top = {}
      for i = 1, math.min(TOP, #list) do top[#top + 1] = list[i] .. "=" .. items[list[i]] end
      ctx.log(string.format("C min=%d eq=%s total=%d %s | top %s", m, key, total, kv(fam), table.concat(top, " ")))
      -- L : laboratoires et recherche
      local labs = s.find_entities_filtered({ force = force, type = "lab" })
      local working, empty, inlab = 0, 0, 0
      for _, l in ipairs(labs) do
        if l.status == defines.entity_status.working then working = working + 1 end
        local inv = l.get_inventory(defines.inventory.lab_input)
        local n = inv and inv.get_item_count() or 0
        inlab = inlab + n
        if n == 0 then empty = empty + 1 end
      end
      local done = 0
      for _, t in pairs(force.technologies) do if t.researched then done = done + 1 end end
      local cur = force.current_research
      local ingr = {}
      if cur then for _, it in ipairs(cur.research_unit_ingredients) do ingr[#ingr + 1] = it.name end end
      ctx.log(string.format("L min=%d eq=%s labos=%d marche=%d sans_pack=%d packs_dedans=%d courante=%s avancement=%.3f ingredients=%s faites=%d",
        m, key, #labs, working, empty, inlab, cur and cur.name or "-", force.research_progress or 0, table.concat(ingr, ","), done))
      -- P : packs et munitions, produits et consommés depuis le relevé précédent
      local names = {}
      for _, n in ipairs(pack_names()) do names[#names + 1] = n end
      for _, n in ipairs(ammo_names()) do names[#names + 1] = n end
      local inp, out = flows(force, names)
      local pv = st.prev[key] or { inp = {}, out = {}, tick = 0 }
      local dmin = math.max(0.01, (tick - pv.tick) / 3600)
      local prod, cons = {}, {}
      for _, n in ipairs(names) do
        local a = (inp[n] - (pv.inp[n] or 0)) / dmin
        local b = (out[n] - (pv.out[n] or 0)) / dmin
        if a > 0.05 then prod[n] = a end
        if b > 0.05 then cons[n] = b end
      end
      st.prev[key] = { inp = inp, out = out, tick = tick }
      ctx.log(string.format("P min=%d eq=%s par_min produits {%s} consommes {%s}", m, key, kv(prod), kv(cons)))
      -- A : armement
      local tur = s.find_entities_filtered({ force = force, type = { "ammo-turret", "electric-turret", "fluid-turret" } })
      local by, dry, inside = {}, 0, 0
      for _, t in ipairs(tur) do
        by[t.type] = (by[t.type] or 0) + 1
        if t.type == "ammo-turret" then
          local inv = t.get_inventory(defines.inventory.turret_ammo)
          local n = inv and inv.get_item_count() or 0
          inside = inside + n
          if n == 0 then dry = dry + 1 end
        end
      end
      local age = -1
      local okl, ls = pcall(ctx.call, "levels_status", row.force)
      if okl and type(ls) == "table" and ls.cc_level then age = ls.cc_level end
      ctx.log(string.format("A min=%d eq=%s tourelles=%d {%s} a_sec=%d munitions_dedans=%d soldats=%d ouvriers=%d age=%d",
        m, key, #tur, kv(by), dry, inside, row.soldiers or 0, row.n or 0, age))
    end
  end
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick > 0 and (e.tick % DIAG_EVERY == 0 or e.tick == 212400) then releve(ctx, e.tick) end
end

return base
end
