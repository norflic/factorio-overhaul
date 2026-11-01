--[[
  Lot INDUSTRIE I1 (RESERVE) : banc court de la réserve (fo-logs/2026-10-31_INDUSTRIE/PLAN.md §6 et §7). Deux scénarios en partagent
  la mise en place, chacun en deux variantes (réglage fo-war-industrie ALLUMÉ, ou TÉMOIN éteint : le mod d'avant) :

    ind-reserve / ind-reserve-temoin (4 100 ticks) : 2 factions financées de 20 000 fer (et le reste de War.fund), Paisible, aucune
      menace : la capitalisation décide une fois par minute (la première vers le tick 3 300). Mesuré à chaque relevé de 300 ticks par
      l'interface « fo-capi » : décisions, ordres envoyés (cs.orders), part du stock au budget (res.budget), stock libre (res.free).
      Allumé : ≥ 1 ordre envoyé à la première décision d'au moins une faction, le besoin évalué est écrit (res.free), le journal
      [FO-RESERVE] existe. Témoin : mesuré, sans contrôle (ordres, budget). À 20 000 fer le budget ne limite PAS le premier cycle
      (le premier ordre coûte 74 MU, les refus viennent d'ailleurs : machine, foreuse, laboratoire) ; la variante « -bas » (400 fer)
      fait du budget le facteur limitant : l'ancien budget (18,75 % du stock libre) refuse, le stock hors besoin paie.

    ind-recrue / ind-recrue-temoin (9 500 ticks) : le défaut mesuré en 0.6.28 (ia3d-charge : 1 recrue sous charge contre 3 en 0.6.27,
      refus « cout » doublés). 4 factions modestement financées (1 200 fer), 16 tâches de minage de fer injectées à 2 factions de
      la minute 0,1 à la fin ; relevé toutes les 300 ticks par « fo-ia1 » (n, eff_grown, eff_reason). La règle d'effectif attend 2 min de
      travail avant de recruter : la fenêtre est courte (tout au plus 1 ou 2 recrues) ; le contrôle compare les recrues et les raisons
      « cout » de la variante allumée au témoin, jouées sur la même graine.

  Lancement (par la file) : banc.py --out <archive> --qui IND-I1 -- 4100 ind-reserve <source>   (et ind-reserve-temoin) ;
                            banc.py --out <archive> --qui IND-I1 -- 9500 ind-recrue <source>     (et ind-recrue-temoin).
  Journal : [FO-IND-RESERVE] et [FO-IND-RECRUE] (+ [FO-IND-RESERVE-TEMOIN], [FO-IND-RECRUE-TEMOIN]) ; le mod écrit [FO-RESERVE] et [FO-CAPI].
]]

local MIN = 3600

local function set_setting(ctx, name, value)
  local v = ctx.call("war_setting", name, value)
  ctx.check(v == value, "reglage " .. name .. " = " .. tostring(value), tostring(v))
end

local function common_init(ctx, on, factions, fund)
  set_setting(ctx, "fo-war-industrie", on)
  set_setting(ctx, "fo-war-ia3e", true)
  set_setting(ctx, "fo-war-capi", true)
  set_setting(ctx, "fo-war-workers", 30)
  local ok = ctx.remote("fo-pvp", "set_difficulty", "peaceful")
  ctx.check(ok == true, "difficulte Paisible imposee avant la guerre", tostring(ok))
  ctx.check(ctx.call("war_start", factions, 100) == true, "guerre lancee : " .. factions .. " factions")
  ctx.check(ctx.call("war_fund", fund) == factions, factions .. " factions financees (" .. fund .. " fer)")
  ctx.call("profiler", true)
  ctx.state().t = {}
end

local function capi_status(ctx, key)
  if not ctx.has("fo-capi", "status") then return nil end
  return ctx.remote("fo-capi", "status", key)
end

local function teams(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  return out
end

--- ind-reserve : relevé de la première décision de chaque faction.
local function reserve(variant, fund, min_orders)
  local on = variant ~= "temoin"
  return {
    description = "INDUSTRIE I1 (" .. variant .. ") : 2 factions a " .. fund .. " fer, premiere decision de la capitalisation",
    check_tick = 4000,

    init = function(ctx) common_init(ctx, on, 2, fund) end,

    tick = function(ctx, e)
      if e.tick % 300 ~= 0 or e.tick == 0 then return end
      local st = ctx.state()
      for _, r in ipairs(teams(ctx)) do
        local s = capi_status(ctx, r.key)
        if s then
          local t = st.t[r.key]
          if not t then t = { dec = 0 } st.t[r.key] = t end
          if (s.decisions or 0) > t.dec then
            if t.dec == 0 then
              t.first_tick, t.first_orders, t.first_budget = e.tick, s.orders or 0, s.res and s.res.budget or 0
              t.first_free = (s.res and s.res.free) and true or false
              ctx.log(string.format("%s : premiere decision vue au tick %d : %d ordre(s) envoye(s), budget %.0f MU, besoin evalue %s, fer au coffre %d",
                r.key, e.tick, t.first_orders, t.first_budget, tostring(t.first_free), r.iron or -1))
            end
            t.dec = s.decisions
          end
          t.orders, t.budget, t.spent = s.orders or 0, s.res and s.res.budget or 0, s.res and s.res.spent or 0
        end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local keys, best = {}, 0
      for k in pairs(st.t or {}) do keys[#keys + 1] = k end
      table.sort(keys)
      local all_free, any_first = true, false
      for _, k in ipairs(keys) do
        local t = st.t[k]
        ctx.log(string.format("%s : decisions %d, premiere au tick %s avec %s ordre(s), budget de la premiere %s MU, ordres en tout %d, depense %.0f MU",
          k, t.dec, tostring(t.first_tick), tostring(t.first_orders), tostring(t.first_budget), t.orders or 0, t.spent or 0))
        if t.first_tick then any_first = true end
        if (t.first_orders or 0) > best then best = t.first_orders end
        if t.first_tick and not t.first_free then all_free = false end
      end
      ctx.check(#keys == 2, "2 factions relevees", #keys)
      ctx.check(any_first, "la capitalisation a decide au moins une fois")
      if on then
        ctx.check(all_free, "reglage allume : le besoin est evalue a chaque premiere decision (res.free)")
        ctx.check(best >= min_orders, "reglage allume : au moins " .. min_orders .. " ordre(s) envoye(s) a la premiere decision d'une faction (" .. best .. ")")
      else
        ctx.check(not all_free or not any_first, "temoin : aucun besoin evalue (reglage eteint)")
        ctx.log("temoin : meilleur premier cycle " .. best .. " ordre(s) (a comparer a la variante allumee)")
      end
    end,
  }
end

--- ind-recrue : les recrues de croissance sous charge, allumé contre témoin.
local function recrue(variant)
  local on = variant ~= "temoin"
  local T0, T1 = 360, 9300
  local LOADED = { scarlet = true, azure = true }
  return {
    description = "INDUSTRIE I1 (" .. variant .. ") : recrues sous charge injectee, 4 factions a 1 200 fer, plafond 30",
    check_tick = 9400,

    init = function(ctx) common_init(ctx, on, 4, 1200) end,

    tick = function(ctx, e)
      local st = ctx.state()
      if e.tick == T0 then
        for _, key in ipairs({ "azure", "scarlet" }) do
          local okc = ctx.remote("fo-ia1", "inject_crisis", key, 16, T1 - T0, "iron-ore")
          ctx.check(okc == true, key .. " : charge injectee (16 taches de minage de fer)")
        end
      end
      if e.tick % 300 ~= 0 or e.tick == 0 then return end
      for _, r in ipairs(teams(ctx)) do
        local s = st.t[r.key]
        if not s then
          s = { start_n = r.n, max = r.n, grown = 0, reasons = {}, iron_min = r.iron or 0, iron_max = r.iron or 0 }
          st.t[r.key] = s
        end
        s.grown = r.eff_grown or s.grown
        s.reasons[r.eff_reason or "?"] = (s.reasons[r.eff_reason or "?"] or 0) + 1
        if r.n > s.max then s.max = r.n end
        s.n = r.n
        if (r.iron or 0) < s.iron_min then s.iron_min = r.iron or 0 end
        if (r.iron or 0) > s.iron_max then s.iron_max = r.iron or 0 end
        s.last_iron = r.iron or 0
        local c = capi_status(ctx, r.key)
        if c then
          s.dec, s.orders = c.decisions or 0, c.orders or 0
          if c.res and c.res.free then s.free = true end
        end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local keys = {}
      for k in pairs(st.t or {}) do keys[#keys + 1] = k end
      table.sort(keys)
      local grown_loaded, grown_all = 0, 0
      for _, k in ipairs(keys) do
        local s = st.t[k]
        local rk, rs = {}, {}
        for r in pairs(s.reasons) do rk[#rk + 1] = r end
        table.sort(rk)
        for _, r in ipairs(rk) do rs[#rs + 1] = r .. ":" .. s.reasons[r] end
        ctx.log(string.format("%s%s : depart %d, fin %d (max %d), recrues de croissance %d, fer min %d max %d fin %d, decisions capi %d, ordres capi %d, besoin evalue %s ; raisons {%s}",
          k, LOADED[k] and " (chargee)" or " (temoin)", s.start_n, s.n or -1, s.max, s.grown, s.iron_min, s.iron_max, s.last_iron or -1,
          s.dec or 0, s.orders or 0, tostring(s.free or false), table.concat(rs, " ")))
        grown_all = grown_all + s.grown
        if LOADED[k] then grown_loaded = grown_loaded + s.grown end
        ctx.check(on == (s.free == true) or (s.dec or 0) == 0, k .. " : besoin evalue seulement si le reglage est allume")
      end
      ctx.check(#keys == 4, "4 factions relevees", #keys)
      ctx.log(string.format("recrues de croissance : chargees %d, toutes %d", grown_loaded, grown_all))
      local p = ctx.remote("fo-ia1", "path") or {}
      ctx.check((p.agents or 0) <= 300, "agents riches <= fo-agents-max (300)", p.agents)
    end,
  }
end

return function(name)
  if name == "ind-reserve" then return reserve("allume", 20000, 1) end
  if name == "ind-reserve-temoin" then return reserve("temoin", 20000, 1) end
  -- Stock bas : l'ancien budget (18,75 % du stock libre, soit moins que le prix d'un premier ordre) refuse, le stock hors besoin paie.
  if name == "ind-reserve-bas" then return reserve("allume", 400, 1) end
  if name == "ind-reserve-bas-temoin" then return reserve("temoin", 400, 1) end
  if name == "ind-recrue" then return recrue("allume") end
  if name == "ind-recrue-temoin" then return recrue("temoin") end
  error("scenario INDUSTRIE inconnu : " .. tostring(name))
end
