--[[ Lot RECHERCHE-BRAS : un module d'ENGRENAGES est posé avec des bras simples SEULEMENT (le bras rapide n'est ni au coffre ni fabricable)
  et il TOURNE.
  Défaut (parties neuves 0.6.70 et 0.6.72) : « executant : recherche : fast-inserter » refusait les chaînes de câbles, circuits et
  engrenages de la minute 9 à 24-27, parce que le gabarit choisissait ses bras sur le débit nominal de ses machines.
  Dispositif (comme rangees-dyn) :
    1. guerre à 2 factions ; au tick 300 le coffre d'une faction reçoit les pièces de la rangée et de la centrale SANS aucun
       fast-inserter, et la recette du bras rapide est FERMÉE à sa force (elle l'est de toute façon sans la technologie) ;
    2. ordre de banc (fo-capi, bench_order) chaine iron-gear-wheel à 30/min : la capitalisation fait le gabarit aux seuls bras obtenables ;
    3. fantômes de la centrale et de la rangée ravivés par le banc (fo-ind revive) jusqu'à « fini » ; le banc garnit les coffres de quai
       (fer à la rangée, charbon à la centrale) : les PNJ de ces rangs mettent plus que la durée d'un banc court ;
    4. contrôles : ordre accepté ; rangée finie ; AUCUN bras rapide dans son emprise, au moins 3 bras simples ; au moins une machine
       d'engrenages en marche ; engrenages produits (statistiques de la force) après la mise en service.
  Journal du mod : [FO-CAPI] (ordre), [FO-IA1D] (projet), [FO-BRAS]. Lancement (accord du lead requis, le DC joue) :
    banc.py --out <archive> --qui RECHERCHE-BRAS -- 6000 bras-simples <source>
  Témoin : le même scénario sur 0.6.72 ne passe pas le contrôle 1 (« executant : recherche : fast-inserter »).
]]
local CHECK = 5900
local EVERY = 120
local ITEM = "iron-gear-wheel"
local PARTS = { { "assembling-machine-1", 40 }, { "inserter", 80 },
  { "transport-belt", 400 }, { "small-electric-pole", 100 }, { "iron-chest", 20 }, { "wood", 100 },
  { "copper-plate", 400 }, { "iron-plate", 1500 }, { "coal", 400 }, { "offshore-pump", 2 }, { "boiler", 2 }, { "steam-engine", 4 },
  { "pipe", 40 }, { "burner-inserter", 4 } }

local function first_team(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out[1]
end

local function force_of(key) return game.forces["fo-" .. key] or game.forces[key] end

local function area(box) return { { box.x, box.y }, { box.x + box.w, box.y + box.h } } end

local function count_in(ctx, box, name)
  return #ctx.surface().find_entities_filtered({ area = area(box), name = name })
end

local function working_machines(ctx, box)
  local n = 0
  for _, e in ipairs(ctx.surface().find_entities_filtered({ area = area(box), type = "assembling-machine" })) do
    local r = e.get_recipe()
    if r and r.name == ITEM and e.status == defines.entity_status.working then n = n + 1 end
  end
  return n
end

--- Garnit les coffres de quai d'un projet (x, y, item) : le banc fait le travail des porteurs, trop lents pour un banc court.
local function fill_quais(ctx, s, amount)
  for _, q in ipairs((s and s.quais) or {}) do
    local c = ctx.surface().find_entities_filtered({ position = { q.x, q.y }, radius = 0.4, type = "container", limit = 1 })[1]
    if c and c.valid and q.item and c.get_item_count(q.item) < amount then c.insert({ name = q.item, count = amount }) end
  end
end

return {
  description = "RECHERCHE-BRAS : une rangee d'engrenages aux seuls bras simples (bras rapide ferme) est posee et tourne",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    for _, s in ipairs({ { "fo-war-ia3e", true }, { "fo-war-capi", true }, { "fo-war-workers", 30 } }) do
      local v = ctx.call("war_setting", s[1], s[2])
      ctx.check(v == s[2], "reglage " .. s[1] .. " = " .. tostring(s[2]), tostring(v))
    end
    ctx.check(ctx.remote("fo-pvp", "set_difficulty", "peaceful") == true, "difficulte Paisible imposee avant la guerre")
    ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee : 2 factions")
    st.phase = 0
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if t == 300 then
      local r = first_team(ctx)
      st.key = r and r.key
      ctx.check(st.key ~= nil, "faction relevee (" .. tostring(st.key) .. ")")
      local force = st.key and force_of(st.key)
      if force then
        if force.technologies["automation"] then force.technologies["automation"].researched = true end
        for _, rn in ipairs({ "fast-inserter", "medium-electric-pole" }) do
          if force.recipes[rn] then force.recipes[rn].enabled = false end
        end
        st.closed = not force.recipes["fast-inserter"].enabled
      end
      ctx.check(st.closed == true, "recette du bras rapide FERMEE a la force")
      ctx.check(st.key ~= nil and ctx.remote("fo-ind", "stock", st.key, PARTS) ~= nil, "coffre : pieces sans aucun bras rapide")
    end
    if not st.key then return end
    if st.phase == 0 and t > 300 and t % 60 == 0 and ctx.remote("fo-capi", "status", st.key) ~= nil then
      local ids, why = ctx.remote("fo-capi", "bench_order", st.key, "chaine", ITEM, 30)
      st.id = ids and ids[1]
      st.why = why
      st.phase = 1
      ctx.log(string.format("ordre chaine %s 30/min -> %s", ITEM, st.id and ("module " .. st.id) or ("refus : " .. tostring(why))))
    end
    if st.id and t % EVERY == 0 and st.phase >= 1 then
      local a = ctx.remote("fo-ia3e", "status", st.key)
      if a and a.plant and a.plant_state ~= "fini" then ctx.remote("fo-ind", "revive", st.key, a.plant) end
      if a and a.plant and a.plant_state == "fini" then
        fill_quais(ctx, ctx.remote("fo-ia1d", "status", st.key, a.plant), 200)
      end
      ctx.remote("fo-ind", "revive", st.key, st.id)
      local s = ctx.remote("fo-ia1d", "status", st.key, st.id)
      if s and s.state == "fini" then
        local box = s.parts and s.parts[1]
        if box and not st.fini then
          st.fini, st.box = t, box
          st.fast = count_in(ctx, box, "fast-inserter")
          st.simple = count_in(ctx, box, "inserter")
          st.base_gears = force_of(st.key).item_production_statistics.get_input_count(ITEM)
          ctx.log(string.format("tick %d : rangee %d FINIE, %d bras simple(s), %d bras rapide(s)", t, st.id, st.simple, st.fast))
        end
        fill_quais(ctx, s, 400)
        if st.box then
          local w = working_machines(ctx, st.box)
          st.max_working = math.max(st.max_working or 0, w)
        end
      end
    end
    if st.fini and t % 600 == 0 then
      local made = force_of(st.key).item_production_statistics.get_input_count(ITEM) - (st.base_gears or 0)
      st.made = made
      ctx.log(string.format("tick %d : %d engrenage(s) fabriques depuis la mise en service, machines en marche (max) %s", t, made, tostring(st.max_working)))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.id ~= nil, "ordre accepte : la capitalisation fait la rangee sans exiger le bras rapide", tostring(st.why))
    ctx.check(st.fini ~= nil, "rangee finie (ravivee par le banc)", tostring(st.fini))
    ctx.check(st.fini ~= nil and (st.fast or 0) == 0, "AUCUN bras rapide dans l'emprise de la rangee", tostring(st.fast))
    ctx.check((st.simple or 0) >= 3, "au moins 3 bras simples poses", tostring(st.simple))
    ctx.check((st.max_working or 0) >= 1, "une machine d'engrenages en marche", tostring(st.max_working))
    ctx.check((st.made or 0) >= 10, "des engrenages sont fabriques depuis la mise en service (10 au moins)", tostring(st.made))
  end,
}
