--[[
  Sprint s43, scénario de crise n° 1 (scen-energie) : RUPTURE DE CHARBON / BLACKOUT EN PLEINE MONTÉE EN CHARGE.

  MISE EN SCÈNE : la partie du guide (verif_guide_common, 30 ouvriers, comme etape1-guide). À la minute M (30 min), pour CHAQUE force qui a une
  centrale en marche (chaudière + machine à vapeur + pompe), le banc :
    - vide le combustible des chaudières (inventaire et flamme en cours) ;
    - vide le combustible des coffres d'alimentation (conteneurs à moins de R_FEED tuiles d'une chaudière) et des mains des bras voisins ;
    - vide le combustible des tapis voisins et COUPE le tapis de charbon (détruit les N_CUT tapis porteurs de combustible les plus proches des
      chaudières) ;
  le coffre du QG garde son stock (la tournée a de quoi ravitailler). « Combustible » = objet dont le prototype a une valeur de combustion
  (aucun nom en dur).

  THÉORIE (comportement attendu du cerveau, chaîne déjà câblée en 0.7.96) :
    1. DÉTECTION : script/team/plant_arms.lua:184 (PA.watch, toutes les 5 s) -> Sante.observe (script/team/sante_centrale.lua:72) lit chaque
       chaudière (is_dry : inventaire vide ET plus de flamme), les bras, les tapis, la production (energy_generated_last_tick) contre la capacité ;
       S.classify (shared/team/sante_centrale.lua:45) rend les causes « chaudiere_a_sec », « tapis_manquant » (et « coffre_vide ») ;
    2. CAUSE -> ACTION : S.confirm (3 relevés à sec, 15 s) puis S.prime (stock du QG >= 10) : tâche « amorce » prio 92 (Sante.tasks, appelée par
       build.lua:4677) : un PNJ porte S.PRIME charbons par chaudière à sec (Sante.work) ; répétée toutes les S.COOL (90 s) tant que la chaudière
       est à sec ; la reconstruction (script/team/reconstruction.lua) repose les tapis détruits ; la tournée de quai remplit le coffre ;
    3. RETOUR : la satisfaction électrique des consommateurs revient au niveau d'avant la coupe en moins de T_MAX (5 min).
  RELEVÉ (toutes les 5 s, par force concernée) : sat = Σ énergie / Σ tampon des consommateurs électriques (lu sur les entités, comme
  script/compute) ; prod = kW des machines à vapeur (la grandeur que lit Sante.observe) ; chaudières à sec ; tapis porteurs vivants.
  RÉSULTAT par force (s43 blackout-juge : seules les pièces PRÉSENTES et allumées à la coupe sont jugées ; une centrale finie après la coupe
  démarre vide, et une demande qui grandit sur une centrale saturée fait baisser la satisfaction sans défaut de reprise) : délai de retour =
  toutes les chaudières de la coupe allumées ET les machines de la coupe à 90 % des kW moyens des 2 min d'avant, 3 relevés de suite ; délai
  de la première chaudière rallumée ; verdict OK si retour <= T_MAX. La satisfaction (sat) reste relevée, pour information. Le journal du cerveau est [FO-SANTE-CENTRALE] (même fichier).
  Lancement : banc.py --out <archive> --graine <g> --qui s43-scen-energie -- 172000 scen-blackout <source>. Journal : [FO-SCEN-BLACKOUT].
]]

local base = require("scenarios/verif_guide_common")(30)
local TAG = "[FO-SCEN-BLACKOUT] "
local tick0 = base.tick
local MIN = 3600
local T_CUT = 30 * MIN
local T_MAX = 5 * MIN
local T_END = T_CUT + 15 * MIN
local STEP = 300
local R_FEED, N_CUT, R_BELT = 6, 2, 12
local MAX_CONS = 600
local CONSUMERS = { "assembling-machine", "furnace", "lab", "mining-drill", "radar", "inserter", "electric-turret", "pump", "roboport", "beacon" }

base.description = "s43 scen-energie : blackout provoque a 30 min (charbon des chaudieres, coffres et tapis retire, tapis de charbon coupe)"
base.check_tick = T_END + 600

local fuel_cache = {}
local function is_fuel(name)
  local v = fuel_cache[name]
  if v == nil then
    local p = game.item_prototypes[name]
    v = (p and (p.fuel_value or 0) > 0) or false
    fuel_cache[name] = v
  end
  return v
end

local function forces_list()
  local out = { { key = "player", force = "player" } }
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = { key = row.key, force = row.force } end
  end
  return out
end

local function strip_inventory(inv)
  if not (inv and inv.valid) then return 0 end
  local n = 0
  local names = {}
  for name, _ in pairs(inv.get_contents()) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    if is_fuel(name) then n = n + inv.remove({ name = name, count = inv.get_item_count(name) }) end
  end
  return n
end

local function strip_belt(b)
  local n = 0
  for i = 1, b.get_max_transport_line_index() do
    local line = b.get_transport_line(i)
    local names = {}
    for name, _ in pairs(line.get_contents()) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
      if is_fuel(name) then n = n + line.remove_item({ name = name, count = line.get_item_count(name) }) end
    end
  end
  return n
end

local function belt_has_fuel(b)
  for i = 1, b.get_max_transport_line_index() do
    for name, _ in pairs(b.get_transport_line(i).get_contents()) do if is_fuel(name) then return true end end
  end
  return false
end

local function by_pos(a, b)
  if a.position.x ~= b.position.x then return a.position.x < b.position.x end
  return a.position.y < b.position.y
end

local function sorted(list) table.sort(list, by_pos) return list end

--- Satisfaction des consommateurs électriques d'une force (Σ énergie / Σ tampon), production kW, chaudières à sec.
local function sample(s, force)
  local en, buf, cnt = 0, 0, 0
  for _, e in ipairs(sorted(s.find_entities_filtered({ type = CONSUMERS, force = force }))) do
    if cnt >= MAX_CONS then break end
    local ok, b = pcall(function() return e.electric_buffer_size end)
    if ok and b and b > 0 then
      cnt = cnt + 1
      buf = buf + b
      en = en + math.min(e.energy or 0, b)
    end
  end
  local kw = 0
  for _, g in ipairs(s.find_entities_filtered({ type = "generator", force = force })) do kw = kw + (g.energy_generated_last_tick or 0) * 60 / 1000 end
  local dry, boilers = 0, 0
  for _, bo in ipairs(s.find_entities_filtered({ type = "boiler", force = force })) do
    boilers = boilers + 1
    local inv = bo.get_fuel_inventory()
    if inv and inv.is_empty() and ((bo.burner and bo.burner.remaining_burning_fuel) or 0) <= 0 then dry = dry + 1 end
  end
  return { sat = buf > 0 and en / buf or nil, n = cnt, kw = kw, dry = dry, boilers = boilers }
end

--- État des seules pièces présentes à la coupe : chaudières à sec (une chaudière détruite compte à sec), kW de leurs machines.
local function cut_state(r)
  local n, dry, kw = 0, 0, 0
  for _, bo in ipairs(r.boil or {}) do
    n = n + 1
    if not bo.valid then dry = dry + 1
    else
      local inv = bo.get_fuel_inventory()
      if inv and inv.is_empty() and ((bo.burner and bo.burner.remaining_burning_fuel) or 0) <= 0 then dry = dry + 1 end
    end
  end
  for _, g in ipairs(r.gens or {}) do if g.valid then kw = kw + (g.energy_generated_last_tick or 0) * 60 / 1000 end end
  return { n = n, dry = dry, kw = kw }
end

local function cut(s, rec)
  local boilers = sorted(s.find_entities_filtered({ type = "boiler", force = rec.force }))
  local removed, chests, belts_cut = 0, 0, 0
  local seen = {}
  local cand = {}
  for _, bo in ipairs(boilers) do
    removed = removed + strip_inventory(bo.get_fuel_inventory())
    if bo.burner then bo.burner.remaining_burning_fuel = 0 end
    for _, c in ipairs(sorted(s.find_entities_filtered({ position = bo.position, radius = R_FEED, type = { "container", "logistic-container" }, force = rec.force }))) do
      if not seen[c.unit_number] then
        seen[c.unit_number] = true
        local n = strip_inventory(c.get_inventory(defines.inventory.chest))
        if n > 0 then chests = chests + 1 end
        removed = removed + n
      end
    end
    for _, ins in ipairs(sorted(s.find_entities_filtered({ position = bo.position, radius = R_FEED, type = "inserter", force = rec.force }))) do
      if ins.held_stack and ins.held_stack.valid_for_read and is_fuel(ins.held_stack.name) then
        removed = removed + ins.held_stack.count
        ins.held_stack.clear()
      end
    end
    for _, b in ipairs(sorted(s.find_entities_filtered({ position = bo.position, radius = R_BELT, type = { "transport-belt", "underground-belt", "splitter" }, force = rec.force }))) do
      if not seen[b.unit_number] then
        seen[b.unit_number] = true
        if belt_has_fuel(b) then
          local dx, dy = b.position.x - bo.position.x, b.position.y - bo.position.y
          cand[#cand + 1] = { e = b, d = dx * dx + dy * dy }
        end
        removed = removed + strip_belt(b)
      end
    end
  end
  table.sort(cand, function(a, b)
    if a.d ~= b.d then return a.d < b.d end
    return by_pos(a.e, b.e)
  end)
  for i = 1, math.min(N_CUT, #cand) do
    if cand[i].e.valid and cand[i].e.type == "transport-belt" then cand[i].e.destroy() belts_cut = belts_cut + 1 end
  end
  rec.removed, rec.chests, rec.belts_cut, rec.fuel_belts = removed, chests, belts_cut, #cand
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick % STEP ~= 0 then return end
  local st = ctx.state()
  local s = ctx.surface()
  st.bo = st.bo or {}
  if e.tick >= T_CUT - 2 * MIN and e.tick < T_CUT then
    -- niveau d'avant : moyenne des 2 dernières minutes
    for _, fr in ipairs(forces_list()) do
      local r = st.bo[fr.key] or { key = fr.key, force = fr.force, pre = {}, post = {} }
      st.bo[fr.key] = r
      local sm = sample(s, fr.force)
      if sm.sat then r.pre[#r.pre + 1] = sm.sat end
      r.pre_kw = sm.kw
      r.prekw = r.prekw or {}
      r.prekw[#r.prekw + 1] = sm.kw
    end
  elseif e.tick == T_CUT then
    for _, fr in ipairs(forces_list()) do
      local r = st.bo[fr.key] or { key = fr.key, force = fr.force, pre = {}, post = {} }
      st.bo[fr.key] = r
      local n_b = s.count_entities_filtered({ type = "boiler", force = fr.force })
      local n_g = s.count_entities_filtered({ type = "generator", force = fr.force })
      local n_p = s.count_entities_filtered({ type = "offshore-pump", force = fr.force })
      r.on = n_b >= 1 and n_g >= 1 and n_p >= 1 and (r.pre_kw or 0) > 0
      local sum = 0
      for _, v in ipairs(r.pre) do sum = sum + v end
      r.sat0 = #r.pre > 0 and sum / #r.pre or nil
      -- s43 blackout-juge : le jugement ne porte que sur les chaudières et machines PRÉSENTES à la coupe (une centrale finie après la coupe
      -- démarre vide, une demande qui grandit sur une centrale saturée n'est pas un défaut de reprise) ; production d'avant = moyenne des 2 min
      local ksum = 0
      for _, v in ipairs(r.prekw or {}) do ksum = ksum + v end
      r.kw0 = (r.prekw and #r.prekw > 0) and ksum / #r.prekw or 0
      r.boil = {}
      for _, bo in ipairs(sorted(s.find_entities_filtered({ type = "boiler", force = fr.force }))) do
        local inv = bo.get_fuel_inventory()
        local lit = not (inv and inv.is_empty()) or ((bo.burner and bo.burner.remaining_burning_fuel) or 0) > 0
        if lit then r.boil[#r.boil + 1] = bo end -- (une chaudière déjà à sec avant la coupe, centrale en chantier, n'est pas jugée)
      end
      r.gens = sorted(s.find_entities_filtered({ type = "generator", force = fr.force }))
      if r.on then cut(s, r) end
      log(TAG .. string.format("coupe a %d min | %s | centrale en marche %s (chaudieres %d machines %d pompes %d, %.0f kW) | sat avant %s | combustible retire %s | coffres vides %s | tapis porteurs %s, coupes %s",
        T_CUT / MIN, fr.key, tostring(r.on), n_b, n_g, n_p, r.pre_kw or 0, r.sat0 and string.format("%.3f", r.sat0) or "-",
        tostring(r.removed or "-"), tostring(r.chests or "-"), tostring(r.fuel_belts or "-"), tostring(r.belts_cut or "-")))
    end
  elseif e.tick > T_CUT and e.tick <= T_END then
    local dt = e.tick - T_CUT
    local keys = {}
    for k, _ in pairs(st.bo) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local r = st.bo[k]
      if r.on then
        local sm = sample(s, r.force)
        r.min = math.min(r.min or 1, sm.sat or 0)
        local c = cut_state(r)
        if not r.relit and c.dry < c.n then r.relit = dt end
        -- reprise : toutes les chaudières de la coupe allumées ET les machines de la coupe à 90 % de la production d'avant
        local good = c.dry == 0 and c.kw >= 0.9 * (r.kw0 or 0)
        if good then r.run = (r.run or 0) + 1 else r.run = 0 end
        if r.dipped == nil and not good then r.dipped = dt end
        if r.dipped and not r.back and (r.run or 0) >= 3 then r.back = dt - 2 * STEP end
        if dt % MIN == 0 then
          log(TAG .. string.format("+%d min | %s | coupe : chaudieres a sec %d/%d, %.0f kW sur %.0f avant | toute la force : sat %s, %.0f kW, chaudieres a sec %d/%d, consommateurs %d",
            dt / MIN, r.key, c.dry, c.n, c.kw, r.kw0 or 0, sm.sat and string.format("%.3f", sm.sat) or "-", sm.kw, sm.dry, sm.boilers, sm.n))
        end
      end
    end
  end
end

base.finish = function(ctx)
  local st = ctx.state()
  local keys = {}
  for k, _ in pairs(st.bo or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  local n_on, n_ok = 0, 0
  for _, k in ipairs(keys) do
    local r = st.bo[k]
    if r.on then
      n_on = n_on + 1
      local ok = (r.dipped == nil) or (r.back ~= nil and r.back - r.dipped <= T_MAX)
      if ok then n_ok = n_ok + 1 end
      log(TAG .. string.format("RESULTAT equipe=%s chaudieres_coupe=%d kw_avant=%.0f sat_avant=%s sat_min=%.3f creux_s=%s rallumee_s=%s retour_s=%s verdict=%s",
        k, #(r.boil or {}), r.kw0 or 0, r.sat0 and string.format("%.3f", r.sat0) or "-", r.min or -1, r.dipped and tostring(r.dipped / 60) or "-",
        r.relit and tostring(r.relit / 60) or "jamais", r.back and tostring((r.back - (r.dipped or 0)) / 60) or "jamais", ok and "OK" or "ECHEC"))
    end
  end
  ctx.check(n_on >= 1, "au moins une force avait une centrale en marche a la coupe", tostring(n_on))
  ctx.check(n_ok == n_on, "chaque centrale coupee : ses chaudieres rallumees et 90 % de sa production d'avant en moins de 5 min", n_ok .. "/" .. n_on)
  log(TAG .. string.format("BILAN : %d centrale(s) coupee(s), %d revenue(s) en moins de %d min", n_on, n_ok, T_MAX / MIN))
end

return base
