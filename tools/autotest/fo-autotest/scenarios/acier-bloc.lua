--[[ Lot ACIER (8/11) : la fonderie d'acier automatisée, en moteur réel.
  1. coffre de la faction garni (pièces, fours, plaques, charbon) ;
  2. un ordre de banc « chaine copper-cable » fait demander la centrale ; fantômes ravivés par le banc jusqu'à centrale FINIE (le bloc d'acier
     attend la centrale de l'équipe) ;
  3. demande de fonte d'acier imposée au plan (fo-ia1 bench_smelt_demand : 40 acier manquant, comme une demande de l'équipe) ;
  4. Acier.apply (script/team/acier.lua, étape E1c) demande SEUL la rangée dynamique de fours ; fantômes ravivés par le banc jusqu'à « fini » ;
  5. les quais d'entrée du bloc reçoivent plaques et charbon (le banc tient la place de la liaison ou du piquage : aucun PNJ, aucune main) ;
     les fours du bloc fondent l'acier par tapis et bras ; débit mesuré par l'automatisation (rate_meas) ;
  6. quand le bloc fini produit au moins la demande, les tâches manuelles d'acier sont COUPÉES (fo-acier status.cut).
  Journal du mod : [FO-ACIER], [FO-RANGEES-ASM], [FO-IA3E]. Lancement (par la file, jamais directement) :
    banc.py --out <archive> --qui acier -- 9000 acier-bloc <source>
]]
local CHECK = 8900
local EVERY = 120
local ITEM = "steel-plate"
local PARTS = { { "assembling-machine-1", 40 }, { "assembling-machine-2", 20 }, { "fast-inserter", 60 }, { "inserter", 120 },
  { "transport-belt", 600 }, { "small-electric-pole", 100 }, { "medium-electric-pole", 60 }, { "iron-chest", 30 },
  { "copper-plate", 800 }, { "iron-plate", 1200 }, { "coal", 600 }, { "offshore-pump", 2 }, { "boiler", 2 }, { "steam-engine", 4 },
  { "pipe", 40 }, { "burner-inserter", 4 }, { "steel-furnace", 12 }, { "stone-furnace", 12 } }

local function first_team(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out[1]
end

local function area(box) return { { box.x, box.y }, { box.x + box.w, box.y + box.h } } end

--- Fours du bloc (type « furnace » dans l'emprise) : nombre, fabrications finies, acier dans leurs sorties, plaques et charbon portés.
local function furnaces(ctx, box)
  local n, done, steel, plates = 0, 0, 0, 0
  for _, e in ipairs(ctx.surface().find_entities_filtered({ area = area(box), type = "furnace" })) do
    n = n + 1
    done = done + (e.products_finished or 0)
    local out = e.get_output_inventory()
    steel = steel + (out and out.get_item_count(ITEM) or 0)
    local src = e.get_inventory(defines.inventory.furnace_source)
    plates = plates + (src and src.get_item_count("iron-plate") or 0)
  end
  return n, done, steel, plates
end

local function steel_mod(ctx, key)
  local a = ctx.remote("fo-ia3e", "status", key)
  for _, m in ipairs(a and a.mods or {}) do
    if m.product == ITEM then return m, a end
  end
  return nil, a
end

return {
  description = "ACIER : le bloc de fours d'acier est demande par la regle, nourri par tapis, et coupe les tournees manuelles",
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
      ctx.check(st.key ~= nil and ctx.remote("fo-ind", "stock", st.key, PARTS) ~= nil, "coffre : pieces, fours, plaques, charbon")
    end
    if not st.key then return end
    -- 1. centrale : un ordre de banc la fait demander
    if st.phase == 0 and t > 300 and t % 60 == 0 and ctx.remote("fo-capi", "status", st.key) ~= nil then
      local ids, why = ctx.remote("fo-capi", "bench_order", st.key, "chaine", "copper-cable", 60)
      st.cable = ids and ids[1]
      st.phase = 1
      ctx.log(string.format("ordre chaine copper-cable 60/min -> %s", st.cable and ("module " .. st.cable) or ("refus : " .. tostring(why))))
    end
    if st.phase >= 1 and t % EVERY == 0 then
      local a = ctx.remote("fo-ia3e", "status", st.key)
      if a and a.plant and a.plant_state ~= "fini" then ctx.remote("fo-ind", "revive", st.key, a.plant) end
      if st.cable then ctx.remote("fo-ind", "revive", st.key, st.cable) end
      -- 2. centrale finie : la demande d'acier est imposée au plan, la règle fait le reste
      if st.phase == 1 and a and a.plant_state == "fini" then
        st.plant_t = t
        ctx.log(string.format("tick %d : centrale FINIE ; demande de fonte d'acier imposee (40 manquants)", t))
        ctx.check(ctx.remote("fo-ia1", "bench_smelt_demand", st.key, { [ITEM] = 40 }) == true, "demande de fonte d'acier imposee au plan")
        st.phase = 2
      end
      -- 3. le bloc d'acier est demande SEUL (Acier.apply), raviver ses fantômes jusqu'à « fini »
      if st.phase >= 2 then
        local m = steel_mod(ctx, st.key)
        if m and not st.mod then
          st.mod, st.mod_t = m.id, t
          ctx.log(string.format("tick %d : bloc d'acier DEMANDE par la regle : module %d", t, m.id))
        end
        if st.mod then
          ctx.remote("fo-ind", "revive", st.key, st.mod)
          local s = ctx.remote("fo-ia1d", "status", st.key, st.mod)
          if s and s.state == "fini" and not st.fini then
            st.fini, st.box = t, s.parts and s.parts[1]
            st.quais = s.quais or {}
            ctx.log(string.format("tick %d : bloc d'acier FINI, %d quai(s) d'entree", t, #st.quais))
          end
        end
      end
    end
    -- 4. entree par quai (place de la liaison/piquage) : plaques et charbon, une fois fini, puis rechargés si le quai baisse
    if st.fini and t % 300 == 0 then
      for _, q in ipairs(st.quais or {}) do
        local chests = ctx.surface().find_entities_filtered({ position = { q.x, q.y }, radius = 0.6, type = "container" })
        local c = chests[1]
        if c then
          local want = (q.item == "coal") and 40 or 250
          local have = c.get_item_count(q.item)
          if have < want then c.insert({ name = q.item, count = want - have }) end
        end
      end
    end
    if st.fini and st.box and t % 600 == 0 then
      local n, done, steel, plates = furnaces(ctx, st.box)
      local s = ctx.remote("fo-acier", "status", st.key) or {}
      local m = steel_mod(ctx, st.key)
      st.n, st.done, st.steel = n, done, steel
      ctx.log(string.format("tick %d : %d four(s), %d acier fondu, %d dans les sorties, %d plaque(s) portee(s), debit mesure %s/min, coupe=%s",
        t, n, done, steel, plates, tostring(m and m.rate_meas), tostring(s.cut)))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = st.key and ctx.remote("fo-acier", "status", st.key) or nil
    local m = st.key and steel_mod(ctx, st.key) or nil
    local a = st.key and ctx.remote("fo-ia3e", "status", st.key) or nil
    ctx.check(a ~= nil and a.plant_state == "fini", "centrale de l'equipe finie (le bloc l'attend)", tostring(a and a.plant_state))
    ctx.check(s ~= nil and (s.asked or 0) >= 1, "le bloc a ete demande par la regle (fo-acier status.asked)", tostring(s and s.asked))
    ctx.check(st.mod ~= nil, "module d'acier relevé au suivi de l'automatisation", tostring(st.mod))
    ctx.check(st.fini ~= nil, "bloc d'acier fini (fantomes ravives par le banc)", tostring(st.fini))
    local n, done, steel, plates = 0, 0, 0, 0
    if st.box then n, done, steel, plates = furnaces(ctx, st.box) end
    ctx.check(n >= 1, "au moins un four dans l'emprise du bloc", tostring(n))
    ctx.check(done >= 3, "les fours du bloc ont fondu de l'acier (alimentes par bras et tapis depuis le quai, aucune main)", tostring(done))
    ctx.check(m ~= nil and (m.rate_meas or 0) > 0, "debit mesure du bloc > 0 (rate_meas)", tostring(m and m.rate_meas))
    ctx.check(s ~= nil and s.cut == true, "taches manuelles d'acier COUPEES (fo-acier status.cut)", tostring(s and s.cut))
    local sm = st.key and ctx.remote("fo-ia1", "smelt_stats", st.key) or nil
    ctx.log(string.format("fonte du QG (hors bilan) : visites %s, fours charges %s ; bloc : %d four(s), %d fabrications, %d plaque(s) portee(s) en fin", tostring(sm and sm.visits),
      tostring(sm and sm.loaded), n, done, plates))
  end,
}
