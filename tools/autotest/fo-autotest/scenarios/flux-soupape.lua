--[[
  Lot TV-FLUX (V42) : micro-banc EN MOTEUR RÉEL de la soupape des cuves de fluide (script/ai3/petrole.lua, Pet.valve_think), 2 400 ticks.
  Chaîne prouvée : cuve pleine (95 %) d'une raffinerie posée par le banc, consommateur à l'arrêt (usine chimique sans courant)
  -> mesure Pet.valve_think (appelée par Pet.think à la cadence naturelle du cerveau, puis accélérée par le banc : remote valve_tick)
  -> décision Fl.valve (K = 5 mesures pleines de suite) -> action (recette de surplus lue au relevé : du fluide prélevé à la cuve,
  des objets au coffre de sortie du site) -> effet (niveau de la cuve qui baisse, objets au coffre, soupape refermée sous 90 %), puis
  réglage fo-war-soupape ÉTEINT : plus aucune conversion.
  Le site est FICTIF (projet « fini » adopté par remote fo-petrole.valve_bench ; machines et coffre posés ici) : ce banc ne prouve PAS
  qu'une faction bâtit un site de pétrole (parties longues petrole-guide, accord du DC requis) ; il prouve la soupape sur les entités du moteur.
  Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui TV-FLUX -- 2400 flux-soupape <source>
  Journal : [FO-FLUX-SOUPAPE] ; lignes du mod : [FO-SOUPAPE].
]]

local X0, Y0 = 380, 380
local REFINERY = { x = X0 + 0.5, y = Y0 + 0.5 }
local PLANT = { x = X0 + 8.5, y = Y0 + 0.5 }
local CHEST = { x = X0 + 0.5, y = Y0 + 6.5 }
local SETUP, MANUAL_FROM, OFF_AT, END_AT = 400, 1000, 1700, 2350
local GAS, FUEL = "petroleum-gas", "solid-fuel"

local function teams()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  local out = {}
  for _, row in ipairs(ok and type(rows) == "table" and rows or {}) do out[#out + 1] = row end
  return out
end

local function place_team_chest(ctx)
  local s = ctx.surface()
  local c = game.forces.player.get_spawn_position(s)
  local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
  local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
  if not chest then return false end
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
    { "pistol", 3 }, { "firearm-magazine", 60 }, { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  return true
end

local function gas_in(refinery)
  if not (refinery and refinery.valid) then return -1 end
  return refinery.get_fluid_count(GAS)
end

--- Indice et capacité de la boîte de SORTIE du gaz (la boîte « output » du prototype, la seule que la soupape lit).
local function out_box(refinery)
  local fb = refinery.fluidbox
  for i = 1, #fb do
    local proto = fb.get_prototype(i)
    if type(proto) == "table" and proto.production_type == nil then proto = proto[1] end
    if proto and proto.production_type == "output" then return i, fb.get_capacity(i) end
  end
  return nil, 0
end

--- Met la boîte de sortie à `amount` unités de gaz (écriture directe de la boîte : insert_fluid n'y rend que 100 sur une raffinerie sans courant).
local function set_gas(refinery, amount)
  local i = out_box(refinery)
  if not i then return false end
  refinery.fluidbox[i] = { name = GAS, amount = amount }
  return true
end

local function capacity(refinery)
  local _, cap = out_box(refinery)
  return cap
end

return {
  description = "TV-FLUX V42 : soupape des cuves de fluide en moteur reel (site fictif adopte, K=5, conversion en objets au coffre, fermeture, reglage eteint)",
  base = nil,
  check_tick = 2380,

  init = function(ctx)
    local st = ctx.state()
    if remote.interfaces["fo-pvp"] then remote.call("fo-pvp", "set_difficulty", "peaceful") end
    st.war = remote.call("factorio-overhaul", "war_start", 2, 30, 10)
    st.chest = place_team_chest(ctx)
    local sv = settings.global["fo-war-soupape"]
    st.default = sv and sv.value
    ctx.log("creation : guerre " .. tostring(st.war) .. ", fo-war-soupape = " .. tostring(st.default))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == SETUP then
      local row = nil
      for _, r in ipairs(teams()) do if r.key ~= "player" then row = row or r end end
      st.team = row and row.key
      st.force = row and row.force
      if not row then ctx.log("aucune faction") return end
      ctx.prepare_area(X0 - 6, Y0 - 6, X0 + 20, Y0 + 14)
      local force = game.forces[row.force]
      for _, rn in ipairs({ "basic-oil-processing", "plastic-bar", "solid-fuel-from-petroleum-gas" }) do
        if force.recipes[rn] then force.recipes[rn].enabled = true end
      end
      local ref = s.create_entity({ name = "oil-refinery", position = REFINERY, force = row.force, direction = defines.direction.north })
      local plant = s.create_entity({ name = "chemical-plant", position = PLANT, force = row.force, direction = defines.direction.north })
      local chest = s.create_entity({ name = "iron-chest", position = CHEST, force = row.force })
      st.made = ref ~= nil and plant ~= nil and chest ~= nil
      if not st.made then ctx.log("pose refusee") return end
      ref.set_recipe("basic-oil-processing")
      plant.set_recipe("plastic-bar")
      st.cap = capacity(ref)
      local put = 0
      -- niveau de départ voulu : 95 % de la cuve de sortie
      if set_gas(ref, math.floor(st.cap * 0.95)) then put = math.floor(st.cap * 0.95) end
      st.put = put
      st.cap = math.max(st.cap, 1)
      st.gas0 = gas_in(ref)
      st.ok_bench = remote.call("fo-petrole", "valve_bench", row.key,
        { every = 120, ents = { { name = "oil-refinery", x = REFINERY.x, y = REFINERY.y, recipe = "basic-oil-processing" },
          { name = "chemical-plant", x = PLANT.x, y = PLANT.y, recipe = "plastic-bar" } }, outs = { { x = CHEST.x, y = CHEST.y } } })
      ctx.log(string.format("tick %d : site fictif adopte par %s (%s), cuve de gaz %.0f / %.0f, insertion %.0f, statut %s", e.tick, row.key, tostring(st.ok_bench),
        st.gas0, st.cap, put, tostring(remote.call("fo-petrole", "valve_status", row.key) ~= nil)))
      return
    end
    if not st.made or not st.team then return end
    local ref = s.find_entity("oil-refinery", REFINERY)
    local chest = s.find_entity("iron-chest", CHEST)
    if not (ref and chest) then return end
    -- phase 1 : cadence naturelle de Pet.think (aucun appel du banc)
    if e.tick == MANUAL_FROM then
      local stt = remote.call("fo-petrole", "valve_status", st.team)
      st.natural_calls = stt and stt.calls or -1
      st.natural_open = stt and stt.opened or -1
      st.natural_fuel = chest.get_item_count(FUEL)
      ctx.log(string.format("tick %d : cadence naturelle : %d mesure(s) de la soupape, %d ouverture(s), %d %s au coffre, cuve a %.0f", e.tick,
        st.natural_calls, st.natural_open, st.natural_fuel, FUEL, gas_in(ref)))
    end
    -- phase 2 : mesures accélérées (une par seconde), jusqu'au réglage éteint
    if e.tick >= MANUAL_FROM and e.tick < END_AT and e.tick % 60 == 0 then
      remote.call("fo-petrole", "valve_tick", st.team)
    end
    if e.tick >= MANUAL_FROM and e.tick % 120 == 0 then
      local stt = remote.call("fo-petrole", "valve_status", st.team)
      local v = stt and stt.valves[("bench|" .. GAS)]
      local line = string.format("tick %d : cuve %.0f (%.0f %%), %s au coffre %d, soupape n=%s ouverte=%s total=%s, ouvertures %s", e.tick, gas_in(ref),
        100 * gas_in(ref) / math.max(1, st.cap), FUEL, chest.get_item_count(FUEL), v and v.n or "-", v and tostring(v.open) or "-", v and v.total or "-",
        stt and stt.opened or "-")
      ctx.log(line .. " | note : " .. tostring(stt and stt.note))
      st.timeline = st.timeline or {}
      st.timeline[#st.timeline + 1] = { tick = e.tick, gas = gas_in(ref), fuel = chest.get_item_count(FUEL), n = v and v.n or 0, open = v and v.open or false,
        opened = stt and stt.opened or 0 }
      if st.first_open == nil and v and v.open then st.first_open = e.tick; st.fuel_at_open = chest.get_item_count(FUEL); st.gas_at_open = gas_in(ref) end
      if st.first_open and st.closed == nil and v and not v.open then st.closed = e.tick; st.gas_at_close = gas_in(ref); st.fuel_at_close = chest.get_item_count(FUEL) end
    end
    -- phase 3 : réglage éteint, cuve remplie de nouveau
    if e.tick == OFF_AT then
      st.fuel_before_off = chest.get_item_count(FUEL)
      st.gas_before_off = gas_in(ref)
      set_gas(ref, math.floor(st.cap * 0.98))
      st.gas_refilled = gas_in(ref)
      st.off = remote.call("factorio-overhaul", "war_setting", "fo-war-soupape", false)
      ctx.log(string.format("tick %d : reglage fo-war-soupape eteint (%s), cuve remplie a %.0f, %s au coffre %d", e.tick, tostring(st.off), st.gas_refilled, FUEL, st.fuel_before_off))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    ctx.check(st.default == true, "reglage fo-war-soupape allume par defaut a la creation", tostring(st.default))
    ctx.check(st.made == true and st.ok_bench == true, "site fictif pose et adopte (raffinerie, usine chimique sans courant, coffre)", tostring(st.made))
    ctx.check((st.cap or 0) >= 100 and (st.gas0 or 0) / math.max(1, st.cap or 1) > 0.9, "cuve de depart au-dela de 90 %",
      string.format("%s / %s", tostring(st.gas0), tostring(st.cap)))
    -- la cadence naturelle de Pet.think appelle la soupape (câblage), sans ouvrir avant K mesures
    ctx.check((st.natural_calls or -1) >= 1, "Pet.think appelle la soupape a sa cadence naturelle (aucun appel du banc avant le tick " .. MANUAL_FROM .. ")",
      tostring(st.natural_calls))
    ctx.check((st.natural_open or -1) == 0 and (st.natural_fuel or -1) == 0, "pas d'ouverture ni d'objet avant K = 5 mesures pleines",
      string.format("ouvertures %s, %s %s", tostring(st.natural_open), FUEL, tostring(st.natural_fuel)))
    ctx.check(st.first_open ~= nil, "la soupape s'ouvre apres K mesures pleines sans debouche ouvert", tostring(st.first_open))
    local fuel_end_open = 0
    for _, t in ipairs(st.timeline or {}) do if t.tick <= (st.closed or OFF_AT) then fuel_end_open = math.max(fuel_end_open, t.fuel) end end
    -- la cuve du banc ne tient que 100 unités : une fabrication (20 unités) la fait passer de 95 % à 75 %, sous 90 % : UN objet suffit
    ctx.check(fuel_end_open >= 1, "des objets arrivent au coffre de sortie du site (carburant solide)", tostring(fuel_end_open))
    ctx.check(st.gas_at_close ~= nil and st.gas_at_close <= (st.cap or 0) * 0.9 + 1 and st.gas_at_close < st.gas0, "la cuve redescend sous 90 % et la soupape se referme",
      string.format("cuve a la fermeture %s, depart %s", tostring(st.gas_at_close), tostring(st.gas0)))
    -- le niveau baisse du fluide converti : 20 unités par objet
    if st.gas_at_close and st.fuel_at_close then
      local delta = st.gas0 - st.gas_at_close
      ctx.check(math.abs(delta - 20 * st.fuel_at_close) <= 20, "fluide pris = 20 unites par objet depose (a une fabrication pres)",
        string.format("baisse %.0f, objets %d", delta, st.fuel_at_close))
    else
      ctx.check(false, "fermeture non observee")
    end
    -- réglage éteint : plus aucune conversion
    local ref = s.find_entity("oil-refinery", REFINERY)
    local chest = s.find_entity("iron-chest", CHEST)
    ctx.check(st.off == false, "reglage eteint par le banc (war_setting)", tostring(st.off))
    ctx.check(ref ~= nil and chest ~= nil and chest.get_item_count(FUEL) == (st.fuel_before_off or -1), "reglage eteint : aucun objet de plus au coffre",
      string.format("%s avant, %s apres", tostring(st.fuel_before_off), chest and tostring(chest.get_item_count(FUEL)) or "-"))
    ctx.check(ref ~= nil and gas_in(ref) >= (st.gas_refilled or 0) - 1, "reglage eteint : la cuve reste pleine",
      string.format("%s apres remplissage a %s", ref and tostring(gas_in(ref)) or "-", tostring(st.gas_refilled)))
  end,
}
