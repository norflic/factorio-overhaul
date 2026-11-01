--[[
  Lot C2 « DEMANDE OUVERTE » : banc court du PUITS OUVERT contre le moteur réel (demande du DC du 1/11 : « assurez moi que les bases
  s ameliore a l infini » ; Emerald à 105 min : 24 700 fer au coffre, budget 0, ordres vides pendant 60 min).
  Deux scénarios partagent ce fichier :

    c2-demande         : 2 factions financées de 20 000 fer, Paisible, avec des machines et des pièces au coffre d'équipe (de quoi qu'une
                         chaîne soit possible) ; la première faction (ordre des clés) joue le mod livré, la SECONDE a son puits éteint par
                         l'interface bancaire fo-capi.demande_off (témoin dans la MÊME partie, même graine, même stock). La décision de la
                         capitalisation est hâtée. Mesuré toutes les 300 ticks : décisions, ordres envoyés, ordres ouverts, machines relevées,
                         puits (res.puits : débit visé, stock qui dort).
    c2-demande-temoin  : les deux factions ont leur puits éteint (le mod d'avant, à stock égal).
  Contrôles (premier scénario) : le puits s'ouvre (débit visé > 0, stock dormant) chez la faction allumée seulement ; elle passe plus d'ordres
  que son témoin ; elle relève au moins autant de machines. Journal : [FO-C2-DEMANDE] (ce banc) et [FO-DEMANDE] (le mod).
  Lancement (par la file) : banc.py --out <archive> --qui C2 -- 9500 c2-demande <source>   (et c2-demande-temoin).
]]

local function set_setting(ctx, name, value)
  local v = ctx.call("war_setting", name, value)
  ctx.check(v == value, "reglage " .. name .. " = " .. tostring(value), tostring(v))
end

local PARTS = {
  { "assembling-machine-1", 12 }, { "assembling-machine-2", 6 }, { "inserter", 80 }, { "fast-inserter", 20 },
  { "transport-belt", 300 }, { "iron-chest", 30 }, { "small-electric-pole", 60 }, { "medium-electric-pole", 30 },
  { "copper-plate", 4000 }, { "stone-brick", 300 }, { "coal", 400 }, { "electronic-circuit", 600 }, { "iron-gear-wheel", 600 },
}

local function teams(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

local function machines_of(s)
  local n = 0
  for _, m in ipairs(s.machines or {}) do n = n + (m.n or 0) end
  return n
end

return function(name)
  local control_only = name == "c2-demande-temoin"
  return {
    description = "C2 (" .. name .. ") : 2 factions a 20000 fer, stock dormant : le puits ouvert contre son temoin",
    check_tick = 9400,

    init = function(ctx)
      set_setting(ctx, "fo-war-industrie", true)
      set_setting(ctx, "fo-war-ia3e", true)
      set_setting(ctx, "fo-war-capi", true)
      set_setting(ctx, "fo-war-workers", 30)
      local ok = ctx.remote("fo-pvp", "set_difficulty", "peaceful")
      ctx.check(ok == true, "difficulte Paisible imposee avant la guerre", tostring(ok))
      ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee : 2 factions")
      ctx.check(ctx.call("war_fund", 20000) == 2, "2 factions financees (20000 fer)")
      ctx.call("profiler", true)
      ctx.state().t = {}
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if e.tick == 400 then
        local tm = teams(ctx)
        st.keys = {}
        for i, r in ipairs(tm) do
          st.keys[i] = r.key
          ctx.remote("fo-ind", "stock", r.key, PARTS)
          local off = control_only or i == 2
          ctx.check(ctx.remote("fo-capi", "demande_off", r.key, off) == true, r.key .. " : puits " .. (off and "ETEINT (temoin)" or "allume"))
        end
        ctx.check(#st.keys == 2, "deux factions relevees", #st.keys)
      end
      if st.keys and e.tick >= 1000 and e.tick % 60 == 0 and not st.hastened then
        local all = true
        for _, k in ipairs(st.keys) do all = all and ctx.remote("fo-ind", "hasten", k) == true end
        if all then st.hastened = e.tick ctx.log("decisions hatees au tick " .. e.tick) end
      end
      if e.tick % 300 ~= 0 or e.tick == 0 or not st.keys then return end
      for _, k in ipairs(st.keys) do
        local s = ctx.remote("fo-capi", "status", k)
        if s then
          local t = st.t[k] or { dormant_seen = false, p_max = 0, orders_max = 0, machines_first = nil }
          st.t[k] = t
          t.dec, t.orders, t.open = s.decisions or 0, s.orders or 0, #(s.open or {})
          t.machines = machines_of(s)
          t.machines_first = t.machines_first or t.machines
          local pu = s.res and s.res.puits
          if pu then
            if pu.dormant then t.dormant_seen = true end
            if (pu.p or 0) > t.p_max then t.p_max = pu.p end
            t.left0 = pu.left0
          end
          t.budget = s.res and s.res.budget or t.budget
        end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local keys = st.keys or {}
      for _, k in ipairs(keys) do
        local t = st.t[k] or {}
        ctx.log(string.format("%s : decisions %d, ordres envoyes %d (ouverts %d), machines relevees %d (au debut %s), puits : dormant %s, debit vise max %.2f MU/min, stock qui dort au depart %s MU, budget %s",
          k, t.dec or 0, t.orders or 0, t.open or 0, t.machines or 0, tostring(t.machines_first), tostring(t.dormant_seen), t.p_max or 0,
          t.left0 and string.format("%.0f", t.left0) or "-", t.budget and string.format("%.0f", t.budget) or "-"))
      end
      local a, b = st.t[keys[1] or ""] or {}, st.t[keys[2] or ""] or {}
      ctx.check((a.dec or 0) >= 1 and (b.dec or 0) >= 1, "les deux factions ont decide au moins une fois")
      if control_only then
        ctx.check(not a.dormant_seen and not b.dormant_seen and (a.p_max or 0) == 0 and (b.p_max or 0) == 0, "temoin : aucun puits ouvert")
        ctx.log(string.format("temoin : ordres %d et %d, machines %d et %d", a.orders or 0, b.orders or 0, a.machines or 0, b.machines or 0))
      else
        ctx.check(a.dormant_seen == true and (a.p_max or 0) > 0, "faction allumee : le stock dort et un debit vise s'ouvre (" .. string.format("%.2f", a.p_max or 0) .. " MU/min)")
        ctx.check(not b.dormant_seen and (b.p_max or 0) == 0, "faction temoin : aucun puits")
        ctx.check((a.orders or 0) > (b.orders or 0), "a stock dormant la faction allumee passe plus d'ordres que son temoin (" .. (a.orders or 0) .. " contre " .. (b.orders or 0) .. ")")
        ctx.check((a.machines or 0) >= (b.machines or 0), "et releve au moins autant de machines (" .. (a.machines or 0) .. " contre " .. (b.machines or 0) .. ")")
      end
      local p = ctx.remote("fo-ia1", "path") or {}
      ctx.check((p.agents or 0) <= 300, "agents riches <= fo-agents-max (300)", p.agents)
    end,
  }
end
