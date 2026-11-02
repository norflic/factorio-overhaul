--[[
  Lot PARITE (retour du DC du 2/11 : « elles ont même pas su s'adapter au bâtiment que j'ai posé ») : une FOREUSE à combustion posée à la
  main avec son FOUR au bout (la paire du DC : son four était adopté à 3,5 min puis rendu à 3,6 min dès la foreuse posée) devient un
  avant-poste de l'équipe : les tournées d'entretien la ravitaillent en charbon, vident son four, la production arrive au coffre.
  Le joueur de test pose (create_entity, force « player ») : un gisement de fer, un four, puis la foreuse à son flanc dans l'ordre du DC
  (four d'abord) ; une 2e paire sur LIGNE (bras entre la foreuse et le four) reste intacte. Chaque pose passe par le gestionnaire de pose
  du mod (interface fo-adopte.built : le moteur interdit à un script de lever on_built_entity).
  Le coffre est garni de charbon ET d'aucune plaque : toute plaque au coffre vient de la paire du joueur, servie par les PNJ.
  Contrôles : CRITERES.md P3.1 à P3.3. Lancement : `banc.py --qui PARITE -- 14200 parite-adopte <source>` ; journal : [FO-PARITE-ADOPTE].
]]
local TAG = "[FO-PARITE-ADOPTE] "
-- la tournee d'entretien revient au plus tard apres T.service_period (3 min) : le controle est apres la 2e tournee
local CHECK, PLACE = 14000, 120

local function patch(s, cx, cy, name)
  for dx = -4, 4 do
    for dy = -4, 4 do
      s.create_entity({ name = name, position = { x = cx + dx, y = cy + dy }, amount = 4000 })
    end
  end
end

local function put(s, name, x, y, dir)
  return s.create_entity({ name = name, position = { x = x, y = y }, force = "player", direction = dir })
end

local function state_of(drill, furnace)
  local out = { drill = false, furnace = false }
  if drill and drill.valid then out.drill = true; out.fuel = drill.get_fuel_inventory().get_item_count() end
  if furnace and furnace.valid then
    out.furnace = true
    out.src = furnace.get_inventory(defines.inventory.furnace_source).get_item_count()
    out.out = furnace.get_inventory(defines.inventory.furnace_result).get_item_count()
    out.made = furnace.products_finished or 0
  end
  return out
end

return {
  description = "PARITE : foreuse + four poses a la main, adoptes comme avant-poste (ravitaillement, production au coffre)",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local c = game.forces.player.get_spawn_position(s)
    local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
    local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
    if chest then
      for _, it in ipairs({ { "coal", 400 }, { "stone", 100 }, { "pistol", 3 }, { "firearm-magazine", 60 } }) do
        chest.insert({ name = it[1], count = it[2] })
      end
    end
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    ctx.state().chest = chest
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local chest = st.chest
    if not (chest and chest.valid) then return end
    local s = ctx.surface()
    local c = chest.position
    if e.tick == PLACE then
      st.api = remote.interfaces["fo-adopte"] ~= nil
      -- gisement de fer a 26 tuiles du coffre (dans le rayon de service de 40)
      local px, py = math.floor(c.x + 26), math.floor(c.y - 10)
      patch(s, px, py, "iron-ore")
      patch(s, px, py + 20, "iron-ore") -- 2e gisement pour la paire sur ligne
      -- paire du DC : le four d'abord, la foreuse ensuite
      st.furnace = put(s, "stone-furnace", px + 2, py)
      if st.api and st.furnace then remote.call("fo-adopte", "built", st.furnace) end
      st.drill = put(s, "burner-mining-drill", px, py, defines.direction.east)
      if st.api and st.drill then remote.call("fo-adopte", "built", st.drill) end
      ctx.log(TAG .. string.format("paire posee : foreuse %s, four %s, depot de la foreuse %s", tostring(st.drill ~= nil), tostring(st.furnace ~= nil),
        st.drill and string.format("(%.2f, %.2f)", st.drill.drop_position.x, st.drill.drop_position.y) or "-"))
      -- paire sur ligne : un bras entre la foreuse et le four (le four lui-meme est hors de toute adoption)
      st.lfurnace = put(s, "stone-furnace", px + 2, py + 20)
      st.ldrill = put(s, "burner-mining-drill", px, py + 20, defines.direction.east)
      st.linserter = put(s, "inserter", px + 4, py + 20, defines.direction.east)
      for _, ent in ipairs({ st.lfurnace, st.ldrill, st.linserter }) do
        if st.api and ent then remote.call("fo-adopte", "built", ent) end
      end
      ctx.check(st.drill ~= nil and st.furnace ~= nil and st.ldrill ~= nil and st.lfurnace ~= nil, "2 paires foreuse + four posees a la main")
      ctx.check(st.api == true, "interface fo-adopte presente")
      local stat = st.api and remote.call("fo-adopte", "status") or { drills = -1 }
      ctx.check(stat.drills == 1, "une seule paire adoptee a la pose (celle qui est isolee)", stat.drills)
    end
    if e.tick > PLACE and e.tick % 300 == 0 then
      local a, b = state_of(st.drill, st.furnace), state_of(st.ldrill, st.lfurnace)
      local stat = st.api and remote.call("fo-adopte", "status") or { drills = -1 }
      ctx.log(TAG .. string.format("tick %d | paire adoptee[foreuse comb %s, four src %s sortie %s faits %s] | paire en ligne[comb %s, src %s, faits %s] | adoptees %s | plaques au coffre %d",
        e.tick, tostring(a.fuel), tostring(a.src), tostring(a.out), tostring(a.made), tostring(b.fuel), tostring(b.src), tostring(b.made), tostring(stat.drills),
        chest.get_item_count("iron-plate")))
      st.max_fuel = math.max(st.max_fuel or 0, a.fuel or 0)
      st.max_made = math.max(st.max_made or 0, a.made or 0)
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local a, b = state_of(st.drill, st.furnace), state_of(st.ldrill, st.lfurnace)
    local stat = st.api and remote.call("fo-adopte", "status") or { drills = -1 }
    ctx.check(a.drill and a.furnace, "P3.2 la foreuse et le four du joueur sont toujours la (jamais demolis)")
    ctx.check(stat.drills == 1, "P3.1 la paire isolee est toujours adoptee a la fin", stat.drills)
    ctx.check((st.max_fuel or 0) > 0, "P3.1/P3.3 la foreuse a recu du charbon d'une tournee de l'equipe", st.max_fuel)
    ctx.check((st.max_made or 0) > 0 or (a.out or 0) > 0 or (a.src or 0) > 0, "P3.3 le four de la paire a recu du minerai de la foreuse (fonte en cours ou finie)",
      string.format("src %s sortie %s faits %s", tostring(a.src), tostring(a.out), tostring(st.max_made)))
    ctx.check(st.chest.get_item_count("iron-plate") > 0, "P3.3 des plaques de la paire du joueur sont arrivees au coffre d'equipe (aucune plaque au depart)",
      st.chest.get_item_count("iron-plate"))
    ctx.check(b.drill and b.furnace and (b.fuel or 0) == 0, "P3.2 la paire sur ligne reste au joueur : ni charbon de l'equipe", b.fuel)
    ctx.check((b.out or 0) == 0, "P3.2 la paire sur ligne : sa sortie n'est pas videe par l'equipe", b.out)
  end,
}
