--[[
  Lot IA3-d (docs/IA_ATTENDUS.md A7, critère 1) : une faction RECRUTE quand du travail attend depuis plus de 2 min et
  que le coût est couvert ; elle ne recrute PAS quand ses PNJ sont inactifs. Preuve en moteur réel par une charge de
  travail INJECTÉE (interface « fo-ia1 » inject_crisis du lot IA1-b : N tâches de minage de fer, priorité 50, rouvertes à
  chaque pensée et gardant leur date de naissance), le reste de la partie étant le cerveau ordinaire.
  4 factions, 8 PNJ au départ, plafond 30 (fo-war-workers), financées (2 500 fer : le coût est couvert), Paisible.
  Écarlate et Azur reçoivent 16 tâches de minage de la minute 3 à la minute 15 ; Émeraude et Ambre sont les TÉMOINS.
  Relevé toutes les 300 ticks par l'interface « fo-ia1 » (teams : n, eff_reason, eff_grown, eff_waiting, eff_hands).
  Lancement : banc.py … -- 90000 ia3d-charge <source>. Journal : [FO-IA3D-CHARGE].
  Contrôles :
    1. aucune recrue de croissance d'une faction chargée avant 2 min de charge (la règle attend 2 min) ;
    2. chaque faction chargée gagne au moins 2 PNJ pendant la charge (recrues de croissance) ;
    3. après la charge (minute 15 + 2 min de rythme), plus aucune recrue de croissance des factions chargées ;
    4. à chaque relevé où une recrue de croissance vient d'être faite, la raison de la pensée qui l'a faite est « recrue »
       (jamais « inactifs », « pas_de_travail ») ;
    5. plafond jamais dépassé ; agents riches ≤ 300.
  Les témoins sont mesurés (recrues de croissance, raisons), sans contrôle.
]]
local MIN = 3600
local T0, T1 = 3 * MIN, 15 * MIN -- charge de la minute 3 à la minute 15
local N_TASKS = 16
local CAP = 30
local LOADED = { scarlet = true, azure = true }

return {
  description = "IA3-d : charge de travail injectee (2 factions chargees, 2 temoins, plafond 30, 25 min)",
  check_tick = 89000,

  init = function(ctx)
    local w = ctx.remote("factorio-overhaul", "war_setting", "fo-war-workers", CAP)
    ctx.check(w == CAP, "fo-war-workers regle a " .. CAP, w)
    local ok = ctx.remote("fo-pvp", "set_difficulty", "peaceful")
    ctx.check(ok == true, "difficulte Paisible imposee avant la guerre", tostring(ok))
    ctx.check(ctx.call("war_start", 4, 100) == true, "guerre lancee : 4 factions, ouvriers par le reglage")
    ctx.check(ctx.call("war_fund", 2500) == 4, "4 factions financees (2 500 fer)")
    ctx.call("profiler", true)
    local st = ctx.state()
    st.t = {}
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == T0 then
      for _, key in ipairs({ "azure", "scarlet" }) do
        local okc = ctx.remote("fo-ia1", "inject_crisis", key, N_TASKS, T1 - T0, "iron-ore")
        ctx.check(okc == true, key .. " : charge injectee (" .. N_TASKS .. " taches de minage de fer, 12 min)")
      end
      ctx.log("charge injectee a la minute 3 (azure, scarlet)")
    end
    if e.tick % 300 ~= 0 or e.tick == 0 then return end
    local rows = ctx.remote("fo-ia1", "teams") or {}
    for _, r in ipairs(rows) do
      if r.key ~= "player" then
        local s = st.t[r.key]
        if not s then
          s = { grown = r.eff_grown or 0, first = nil, during = 0, after = 0, before = 0, bad = 0, max = r.n, over = false,
            prev_reason = r.eff_reason, start_n = r.n, reasons = {} }
          st.t[r.key] = s
        end
        local g = r.eff_grown or 0
        if g > s.grown then
          local k = g - s.grown
          if e.tick < T0 + 2 * MIN then s.before = s.before + k
          elseif e.tick <= T1 + 2 * MIN + 600 then s.during = s.during + k
          else s.after = s.after + k end
          if not s.first then s.first = e.tick end
          -- Une pensée par équipe entre deux relevés (période 300) : la raison relevée est celle de la pensée qui a recruté.
          if r.eff_reason ~= "recrue" then s.bad = s.bad + k end
        end
        s.grown = g
        s.prev_reason = r.eff_reason
        s.reasons[r.eff_reason or "?"] = (s.reasons[r.eff_reason or "?"] or 0) + 1
        if r.n > s.max then s.max = r.n end
        if r.n > CAP then s.over = true end
      end
    end
    if e.tick % MIN == 0 then
      local parts = {}
      for _, r in ipairs(rows) do
        if r.key ~= "player" then
          parts[#parts + 1] = string.format("%s n=%d/%d croissance=%d raison=%s attente=%d bras=%d fer=%d",
            r.key, r.n, r.max, r.eff_grown or 0, r.eff_reason or "?", r.eff_waiting or 0, r.eff_hands or 0, r.iron or 0)
        end
      end
      ctx.log("minute " .. (e.tick / MIN) .. " | " .. table.concat(parts, " | "))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local keys = {}
    for k in pairs(st.t or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    local ok_before, ok_during, ok_after, ok_bad, over = true, true, true, true, false
    local parts = {}
    for _, k in ipairs(keys) do
      local s = st.t[k]
      local rs = {}
      local rk = {}
      for r in pairs(s.reasons) do rk[#rk + 1] = r end
      table.sort(rk)
      for _, r in ipairs(rk) do rs[#rs + 1] = r .. ":" .. s.reasons[r] end
      parts[#parts + 1] = string.format("%s%s : depart %d, max %d, croissance avant 2 min %d, pendant %d, apres %d, premiere au tick %s, sans raison %d ; raisons {%s}",
        k, LOADED[k] and " (chargee)" or " (temoin)", s.start_n, s.max, s.before, s.during, s.after, tostring(s.first), s.bad,
        table.concat(rs, " "))
      if LOADED[k] then
        if s.before > 0 then ok_before = false end
        if s.during < 2 then ok_during = false end
        if s.after > 0 then ok_after = false end
      end
      if s.bad > 0 then ok_bad = false end
      if s.over then over = true end
    end
    for _, p in ipairs(parts) do ctx.log(p) end
    ctx.check(#keys == 4, "4 factions relevees", #keys)
    ctx.check(ok_before, "aucune recrue de croissance d'une faction chargee avant 2 min de charge")
    ctx.check(ok_during, "chaque faction chargee gagne au moins 2 PNJ de croissance pendant la charge")
    ctx.check(ok_after, "plus aucune recrue de croissance des factions chargees apres la charge")
    ctx.check(ok_bad, "chaque recrue de croissance vient d'une decision recrue (jamais inactifs)")
    ctx.check(not over, "plafond jamais depasse")
    local p = ctx.remote("fo-ia1", "path") or {}
    ctx.check((p.agents or 0) <= 300, "agents riches <= fo-agents-max (300)", p.agents)
  end,
}
