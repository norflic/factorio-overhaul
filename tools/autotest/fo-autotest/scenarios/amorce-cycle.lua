--[[
  Lot VIDEO-COUVERTURE 5 « CONFIRMATION-AMORCE-GARDES » : micro-banc (palier 3) de l'amorce d'un CYCLE et de la capacité fantôme, contre le moteur réel.
  Critères C5.1 et C5.2 (docs : fo-logs/2026-11-07_VIDEO-COUVERTURE/SYNTHESE.txt, LOT 5). Ce banc NE prouve PAS une partie entière ; il prouve :
    1. une recette CYCLIQUE scriptée (la recette d'enrichissement, produit = ingrédient) : la technologie qui l'ouvre est donnée par le script à la
       faction, un puits d'uranium 235 est noté (fo-capi bench_sink) : la décision de la capitalisation ferme le cycle (Rg.chain), le runtime le
       publie (AmRt.after_decision) et la graine entre au mall AVEC sa cause : ligne « [FO-AMORCE] <faction> : graine de cycle … ; cause : cycle … »
       (le banc la lit au journal APRÈS coup : tools/autotest/amorce_cycle.py) ;
    2. une machine posée qui ne produit jamais (sans courant) n'est pas une capacité : le banc pose 4 assembleurs sans courant ni ingrédient
       dans la zone du QG d'une faction ; il écrit « [FO-CONFIRMATION-BANC] posees=4 produites=0 » ; le journal du mod dit « [FO-CAPI-CONF] … bilan :
       N engage(s), 0 confirme(s) » : aucune capacité fantôme (même nombre de confirmées que de machines qui ont produit).
  Le banc est le cerveau des 4 assembleurs et de la décision hâtée (fo-ind hasten) : un banc court ne peut pas attendre la première décision.
  Lancement : banc.py --out <archive> --qui video-amorce -- 2400 amorce-cycle <worktree> puis py -3.9 -B tools/autotest/amorce_cycle.py <archive>
  Journal : [FO-AMORCE-CYCLE] (ce banc) ; [FO-AMORCE], [FO-CAPI-CONF] et [FO-CONFIRMATION] (le mod).
]]

local TECH = "kovarex-enrichment-process"
local SINK_ITEM = "uranium-235"
local N_MACHINES = 4

local function teams(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

local function hq_of(ctx, key)
  for _, r in ipairs(ctx.remote("fo-prevision", "teams") or {}) do
    if r.key == key then return r end
  end
  return nil
end

return {
  description = "VIDEO-COUVERTURE 5 : amorce d'un cycle (enrichissement) et machines sans production",
  base = nil,
  check_tick = 2300,

  init = function(ctx)
    local st = ctx.state()
    local ok = ctx.remote("fo-pvp", "set_difficulty", "peaceful")
    ctx.check(ok == true, "difficulte Paisible imposee avant la guerre", tostring(ok))
    for _, s in ipairs({ { "fo-war-industrie", true }, { "fo-war-ia3e", true }, { "fo-war-capi", true } }) do
      local v = ctx.call("war_setting", s[1], s[2])
      ctx.check(v == s[2], "reglage " .. s[1] .. " = " .. tostring(s[2]), tostring(v))
    end
    ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee : 2 factions")
    ctx.check(ctx.call("war_fund", 20000) == 2, "2 factions financees")
    st.placed = {}
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    -- 1. au tick 100 : la faction témoin, ses assembleurs sans courant, la technologie du cycle, le puits d'uranium 235
    if e.tick == 100 then
      local tm = teams(ctx)
      st.key = tm[1] and tm[1].key
      st.force = tm[1] and tm[1].force
      ctx.check(st.key ~= nil and st.force ~= nil, "deux factions relevees")
      if not st.key then return end
      local hq = hq_of(ctx, st.key)
      ctx.check(hq ~= nil, st.key .. " : position du QG lue")
      local s = ctx.surface()
      if hq then
        for i = 1, N_MACHINES do
          local p = s.find_non_colliding_position("assembling-machine-1", { x = hq.x + 8 + 4 * i, y = hq.y + 8 }, 12, 1)
          local m = p and s.create_entity({ name = "assembling-machine-1", position = p, force = st.force })
          if m and m.valid then
            m.set_recipe("iron-gear-wheel")
            st.placed[#st.placed + 1] = m
          end
        end
      end
      ctx.check(#st.placed == N_MACHINES, N_MACHINES .. " assembleurs sans courant poses pres du QG (" .. #st.placed .. ")")
      local f = game.forces[st.force]
      local t = f and f.technologies[TECH]
      ctx.check(t ~= nil, "technologie du cycle connue : " .. TECH)
      if t then t.researched = true end
      ctx.check(f ~= nil and t ~= nil and f.recipes[TECH] ~= nil and f.recipes[TECH].enabled == true, "recette cyclique ouverte pour " .. st.key)
    end
    -- 2. le puits d'uranium 235 (le cerveau a créé l'état de la capitalisation au premier passage) ; la décision est hâtée ensuite
    if st.key and e.tick >= 200 and e.tick % 60 == 0 and not st.sink then
      if ctx.remote("fo-capi", "bench_sink", st.key, SINK_ITEM, 5) == true then
        st.sink = e.tick
        ctx.log("puits de " .. SINK_ITEM .. " (5/min) note au tick " .. e.tick)
      end
    end
    if st.sink and not st.hastened and e.tick >= 400 and e.tick % 60 == 0 then
      if ctx.remote("fo-ind", "hasten", st.key) == true then
        st.hastened = e.tick
        ctx.log("decision hatee au tick " .. e.tick)
      end
    end
    -- 3. une trace par minute de jeu
    if st.key and e.tick > 0 and e.tick % 600 == 0 then
      local s = ctx.remote("fo-capi", "status", st.key)
      ctx.log(string.format("tick %d : decisions %s, ordres ouverts %s, machines relevees %s", e.tick, tostring(s and s.decisions),
        tostring(s and #s.open), tostring(s and #s.machines)))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.sink ~= nil, "puits d'uranium 235 note")
    ctx.check(st.hastened ~= nil, "la decision de la capitalisation a ete hatee")
    local s = st.key and ctx.remote("fo-capi", "status", st.key) or nil
    ctx.check(s ~= nil and (s.decisions or 0) >= 1, "la capitalisation a decide au moins une fois (" .. tostring(s and s.decisions) .. ")")
    local produced, valid = 0, 0
    for _, m in ipairs(st.placed or {}) do
      if m.valid then
        valid = valid + 1
        if m.products_finished > 0 then produced = produced + 1 end
      end
    end
    ctx.check(valid == N_MACHINES, "les assembleurs sont toujours la (" .. valid .. ")")
    ctx.check(produced == 0, "aucun assembleur sans courant n'a produit (" .. produced .. ")")
    local seen = 0
    for _, m in ipairs(s and s.machines or {}) do
      if m.entity == "assembling-machine-1" and m.recipe == "iron-gear-wheel" then seen = seen + m.n end
    end
    ctx.check(seen >= N_MACHINES, "le releve de la capitalisation voit les assembleurs (" .. seen .. ")")
    -- lues APRÈS coup par tools/autotest/amorce_cycle.py (le journal du mod n'est pas lisible d'un script)
    log(string.format("[FO-CONFIRMATION-BANC] %s : posees=%d produites=%d", tostring(st.key), valid, produced))
  end,
}
