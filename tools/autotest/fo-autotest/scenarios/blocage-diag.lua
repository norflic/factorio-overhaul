--[[
  Lot BLOCAGE-SORTIE (8/11/2026) : DIAGNOSTIC en lecture seule sur la sauvegarde du DC. Qui vide les sorties des fours et des
  foreuses, et pourquoi une sortie pleine reste pleine ?
  Pour chaque force : foreuses a l'arret « waiting_for_space_in_destination » (cible : four, coffre, tapis, sol ; statut de la cible,
  coffre plein ?) et fours « full_output » (contenu de la sortie, bras qui la prennent et leur statut, coffre voisin plein ?),
  persistance entre deux releves (les memes machines restent-elles bloquees ?), cellules de 64 tuiles les plus touchees, puis
  collect_probe de l'equipe (production en attente, sinks pleins, PNJ, ages des tournees).
  Aucun reglage pose. Journal : [FO-BLOCAGE-DIAG].
  Lancement : banc.py --qui BLOCAGE-SORTIE --sauvegarde <zip> --out <archive> -- 4000 blocage-diag <source>
]]
local MIN = 3600
local T_A, T_B = 600, 3600 -- deux releves : persistance

local names_cache
local function status_name(e)
  if not names_cache then
    names_cache = {}
    for k, v in pairs(defines.entity_status) do names_cache[v] = k end
  end
  local s = e.status
  return s and names_cache[s] or "aucun"
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function top_text(t, top)
  local ks = sorted_keys(t)
  table.sort(ks, function(a, b) if t[a] ~= t[b] then return t[a] > t[b] end return a < b end)
  local parts = {}
  for i = 1, #ks do
    if top and top > 0 and i > top then break end
    parts[#parts + 1] = ks[i] .. "=" .. t[ks[i]]
  end
  return table.concat(parts, " ")
end

local function teams()
  local rows = remote.call("fo-ia1", "teams") or {}
  local forces = { { key = "player", force = "player" } }
  for _, r in ipairs(rows) do if r.key ~= "player" then forces[#forces + 1] = { key = r.key, force = r.force } end end
  return forces
end

local function chest_state(c)
  local inv = c.get_inventory(defines.inventory.chest)
  if not inv then return "?" end
  local empty = inv.count_empty_stacks()
  if empty == 0 then return "plein" end
  if empty * 4 <= #inv then return "presque" end
  return "place"
end

--- Description de la cible d'une foreuse.
local function drill_target(e)
  local t = e.drop_target
  if not (t and t.valid) then return "sol" end
  if t.type == "container" or t.type == "logistic-container" then return "coffre:" .. chest_state(t) end
  if t.type == "furnace" then return "four:" .. status_name(t) end
  if t.type == "assembling-machine" then return "assembleur:" .. status_name(t) end
  return t.type
end

--- Bras qui prennent dans le four `e` : liste de "statut->cible".
local function furnace_takers(s, e)
  local b = e.bounding_box
  local area = { { b.left_top.x - 1.6, b.left_top.y - 1.6 }, { b.right_bottom.x + 1.6, b.right_bottom.y + 1.6 } }
  local out = {}
  for _, i in ipairs(s.find_entities_filtered({ area = area, type = "inserter" })) do
    local ok, pt = pcall(function() return i.pickup_target end)
    if ok and pt and pt.valid and pt.unit_number == e.unit_number then
      local d = i.drop_target
      local dt = "sol"
      if d and d.valid then
        dt = d.type
        if d.type == "container" then dt = "coffre:" .. chest_state(d) end
      end
      out[#out + 1] = status_name(i) .. "->" .. dt
    end
  end
  table.sort(out)
  return out
end

local function furnace_content(e)
  local inv = e.get_inventory(defines.inventory.furnace_result)
  if not inv or inv.is_empty() then return "vide" end
  local c = inv.get_contents()
  local k = sorted_keys(c)
  return k[1] .. ":" .. c[k[1]]
end

local function releve(ctx, s, label)
  local st = ctx.state()
  st.seen = st.seen or {}
  local now = {}
  for _, f in ipairs(teams()) do
    local drills, furn, cells, fcontent = {}, {}, {}, {}
    local nd, nf, nfull = 0, 0, 0
    for _, e in ipairs(s.find_entities_filtered({ force = f.force, type = "mining-drill" })) do
      if not e.name:find("pumpjack", 1, true) then
        nd = nd + 1
        local sn = status_name(e)
        if sn == "waiting_for_space_in_destination" then
          local k = (e.burner and "comb" or "elec") .. " -> " .. drill_target(e)
          drills[k] = (drills[k] or 0) + 1
          now[e.unit_number] = true
          local ck = math.floor(e.position.x / 64) .. "," .. math.floor(e.position.y / 64)
          cells[ck] = (cells[ck] or 0) + 1
        end
      end
    end
    for _, e in ipairs(s.find_entities_filtered({ force = f.force, type = "furnace" })) do
      nf = nf + 1
      local sn = status_name(e)
      if sn == "full_output" then
        nfull = nfull + 1
        local tk = furnace_takers(s, e)
        local k
        if #tk == 0 then k = "aucun bras" else k = #tk .. " bras " .. table.concat(tk, "|") end
        furn[k] = (furn[k] or 0) + 1
        local c = furnace_content(e)
        fcontent[c] = (fcontent[c] or 0) + 1
        now[e.unit_number] = true
        local ck = math.floor(e.position.x / 64) .. "," .. math.floor(e.position.y / 64)
        cells[ck] = (cells[ck] or 0) + 1
      end
    end
    ctx.log(string.format("%s | %s | foreuses=%d fours=%d full_output=%d", label, f.key, nd, nf, nfull))
    ctx.log(string.format("%s | %s | FOREUSES waiting_for_space : %s", label, f.key, top_text(drills, 12)))
    ctx.log(string.format("%s | %s | FOURS full_output, bras : %s", label, f.key, top_text(furn, 12)))
    ctx.log(string.format("%s | %s | FOURS full_output, contenu : %s", label, f.key, top_text(fcontent, 8)))
    ctx.log(string.format("%s | %s | CELLULES 64 tuiles : %s", label, f.key, top_text(cells, 8)))
  end
  return now
end

local function persistance(ctx, a, b)
  local both, onlya, n = 0, 0, 0
  for u in pairs(a) do
    n = n + 1
    if b[u] then both = both + 1 else onlya = onlya + 1 end
  end
  ctx.log(string.format("PERSISTANCE | bloquees au 1er releve=%d ; encore bloquees au 2e=%d ; liberees=%d", n, both, onlya))
end

local function probe(ctx, label)
  for _, f in ipairs(teams()) do
    local ok, r = pcall(remote.call, "fo-ia1", "collect_probe", f.key)
    if ok and r then
      ctx.log(string.format("%s | %s | PROBE stock : coffres=%d cases=%d vides=%d refus_il_y_a=%s | room %s", label, f.key, r.stock.chests,
        r.stock.slots, r.stock.empty, tostring(r.stock.refused_ago), r.stock.room))
      for _, o in ipairs(r.outposts) do
        ctx.log(string.format("%s | %s | PROBE avant-poste %s %s sortie=%s stuck=%s sec=%s carb_bas=%s repos_s=%s tournee=%s age_libre=%s echecs=%s migr=%s"
          .. " thermiques{%s} electriques{%s} sinks{%s}", label, f.key, tostring(o.id), o.kind, tostring(o.output), tostring(o.stuck),
          tostring(o.dry), tostring(o.fuel_low), tostring(o.idle_s), tostring(o.task), tostring(o.free_age), tostring(o.fails), tostring(o.migr),
          o.burners, o.electrics, o.sinks))
      end
      ctx.log(string.format("%s | %s | PROBE PNJ : %s", label, f.key, table.concat(r.workers, " ")))
    else
      ctx.log(string.format("%s | %s | PROBE indisponible", label, f.key))
    end
  end
end

local S = {
  description = "BLOCAGE-DIAG : qui vide les sorties des fours et des foreuses (lecture seule, sauvegarde du DC)",
  check_tick = -1,
}

S.init = function(ctx)
  local st = ctx.state()
  st.t0 = game.tick
  S.check_tick = st.t0 + T_B + 100
  ctx.log(string.format("DEPART tick %d (%.1f min de jeu)", st.t0, st.t0 / MIN))
end

S.tick = function(ctx, e)
  local st = ctx.state()
  if not st.t0 then return end
  local dt = e.tick - st.t0
  local s = ctx.surface()
  if dt == T_A then
    st.a = releve(ctx, s, "T+10s")
    probe(ctx, "T+10s")
  elseif dt == T_B then
    st.b = releve(ctx, s, "T+60s")
    probe(ctx, "T+60s")
    persistance(ctx, st.a or {}, st.b)
  end
end

S.finish = function(ctx)
  local st = ctx.state()
  ctx.check(st.t0 ~= nil and st.t0 > 0, "sauvegarde du DC chargee (tick de depart > 0)", st.t0)
  ctx.check(st.b ~= nil, "deux releves faits", tostring(st.b))
end

return S
