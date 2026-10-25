-- Scénario greffé (lot MOD-V, 25/10) : les icônes des 30 modules EN JEU, avant et après le lot.
--   & "<racine>\fo-autotest.bat" nopause 300 modv-icones "<source>"     -> « [FO-MODV-ICONES] BILAN : 5 OK, 0 ECHEC(S) »
--   & "<racine>\fo-captures.bat" modv-icones "<source>"                 -> 3 vues en mode Alt + 3 interfaces (x-modv-gui-*)
-- Effacer <racine>\fo-visual\write\atlas-cache.dat avant la session avec images quand les icônes ont changé (F210).
-- Pose : 30 assembleurs (une rangée par type, une colonne par palier) remplis du module de leur case ; 20 balises
-- (vitesse et efficacité, paliers 1 à 10 ; la productivité n'entre pas dans une balise) ; un coffre d'acier qui tient
-- les 30 modules dans l'ordre (3 rangées de 10 dans l'interface du coffre). Journal : une ligne VALEURS par module
-- (catégorie, palier, effets, pile, nombre de recettes permises) pour prouver, par différence avec main, qu'aucune
-- valeur de jeu ne change.

local X0, Y0 = 7200, -3200
local T_GUI = 200
local TYPES = { "speed", "productivity", "effectivity" }
local VANILLA = {
  speed = { "speed-module", "speed-module-2", "speed-module-3" },
  productivity = { "productivity-module", "productivity-module-2", "productivity-module-3" },
  effectivity = { "effectivity-module", "effectivity-module-2", "effectivity-module-3" },
}

local function nom(t, k)
  return k <= 3 and VANILLA[t][k] or ("fo-" .. t .. "-module-" .. k)
end

local function arrondi(v)
  if v >= 0 then return math.floor(v * 100 + 0.5) end
  return -math.floor(-v * 100 + 0.5)
end

return {
  description = "MOD-V : icones des 30 modules en jeu (mode Alt, balises, coffre, technologie) et valeurs inchangees",
  base = nil,
  check_tick = 120,
  shots_delay = 300,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(X0 - 46, Y0 - 30, X0 + 46, Y0 + 30, "concrete")
    ctx.power(X0, Y0)
    local machines, pleins, balises, manquants = 0, 0, 0, {}
    for ti, t in ipairs(TYPES) do
      for k = 1, 10 do
        local n = nom(t, k)
        if not game.item_prototypes[n] then manquants[#manquants + 1] = n end
        local a = s.create_entity({ name = "assembling-machine-2", position = { X0 - 40 + (k - 1) * 4 + 1.5,
          Y0 - 22 + (ti - 1) * 4 + 1.5 }, force = "player" })
        if a then
          if t == "productivity" and k == 7 then st.assembleur = a end
          machines = machines + 1
          a.set_recipe("iron-gear-wheel")
          local inv = a.get_module_inventory()
          if inv and game.item_prototypes[n] then
            local c = inv.insert({ name = n, count = #inv })
            if c == #inv and #inv > 0 then pleins = pleins + 1 end
          end
        end
      end
    end
    for ri, t in ipairs({ "speed", "effectivity" }) do
      for k = 1, 10 do
        local b = s.create_entity({ name = "beacon", position = { X0 - 40 + (k - 1) * 4 + 1.5, Y0 - 6 + (ri - 1) * 4 + 1.5 },
          force = "player" })
        if b then
          if t == "effectivity" and k == 9 then st.balise = b end
          local inv = b.get_module_inventory()
          if inv and game.item_prototypes[nom(t, k)] and inv.insert({ name = nom(t, k), count = #inv }) == #inv then
            balises = balises + 1
          end
        end
      end
    end
    local coffre = s.create_entity({ name = "steel-chest", position = { X0 + 20.5, Y0 + 10.5 }, force = "player" })
    local ranges = 0
    if coffre then
      for _, t in ipairs(TYPES) do
        for k = 1, 10 do
          if game.item_prototypes[nom(t, k)] and coffre.insert({ name = nom(t, k), count = 10 + k }) == 10 + k then
            ranges = ranges + 1
          end
        end
      end
    end
    st.coffre = coffre
    -- valeurs de jeu de chaque module (preuve par différence avec main : aucune ne doit changer)
    for _, t in ipairs(TYPES) do
      for k = 1, 10 do
        local p = game.item_prototypes[nom(t, k)]
        if p then
          local eff = p.module_effects or {}
          local parts = {}
          for _, cle in ipairs({ "speed", "productivity", "consumption", "pollution" }) do
            if eff[cle] then parts[#parts + 1] = cle .. "=" .. arrondi(eff[cle].bonus) end
          end
          local lim = p.limitations and #p.limitations or 0
          log("[FO-MODV-ICONES] VALEURS\t" .. p.name .. "\tcategorie=" .. tostring(p.category) .. "\tpalier="
            .. tostring(p.tier) .. "\t" .. table.concat(parts, " ") .. "\tpile=" .. p.stack_size .. "\tlimitations="
            .. lim .. "\tordre=" .. tostring(p.order) .. "\tsous-groupe=" .. p.subgroup.name)
        end
      end
    end
    ctx.check(#manquants == 0, "30 modules presents", #manquants == 0 and "30" or table.concat(manquants, ","))
    ctx.check(machines == 30 and pleins == 30, "30 assembleurs remplis du module de leur case", machines .. "/" .. pleins)
    ctx.check(balises == 20, "20 balises (vitesse et efficacite) remplies", balises)
    ctx.check(ranges == 30, "coffre : 30 modules ranges dans l'ordre", ranges)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local p = game.connected_players[1]
    local t = e.tick
    if not p or t < T_GUI or t >= T_GUI + 30 then return end
    -- (essai du 25/10 : « opened = technologie » n'ouvre rien ; les icônes de technologie sont sur la planche)
    local cibles = { { "coffre", st.coffre }, { "assembleur-productivite-7", st.assembleur },
      { "balise-efficacite-9", st.balise } }
    local k = math.floor((t - T_GUI) / 10) + 1
    local phase = (t - T_GUI) % 10
    local cb = cibles[k]
    if not cb then return end
    if phase == 0 then
      local ok, err = pcall(function()
        if cb[2] and cb[2].valid then
          p.teleport({ cb[2].position.x, cb[2].position.y + 4 })
          p.opened = cb[2]
        end
      end)
      if not ok then ctx.log("GUI " .. cb[1] .. " : opened refuse " .. tostring(err)) end
    elseif phase == 4 then
      game.take_screenshot({ path = "fo-shots/x-modv-gui-" .. cb[1] .. ".png", player = p, show_gui = true,
        position = p.position, zoom = 1, resolution = { 1920, 1080 }, force_render = true, allow_in_replay = true })
      ctx.log("GUI " .. cb[1] .. " : capture demandee, ouvert = " .. tostring(p.opened_gui_type))
    elseif phase == 7 then
      pcall(function() p.opened = nil end)
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local sortes = 0
    if st.coffre and st.coffre.valid then
      for _ in pairs(st.coffre.get_inventory(defines.inventory.chest).get_contents()) do sortes = sortes + 1 end
    end
    ctx.check(sortes == 30, "coffre : 30 sortes de modules a la fin", sortes)
  end,

  shots = function(ctx, add)
    -- assembleurs (3 rangées x 10) et balises (2 rangées x 10), mode Alt
    add("alt-assembleurs-z100", X0 - 20, Y0 - 16, 1.0, 0, { res = { 1400, 480 }, info = true })
    add("alt-assembleurs-z200-paliers1a5", X0 - 30, Y0 - 16, 2.0, 0, { res = { 1400, 820 }, info = true })
    add("alt-balises-z100", X0 - 20, Y0 - 2, 1.0, 0, { res = { 1400, 340 }, info = true })
  end,
}
