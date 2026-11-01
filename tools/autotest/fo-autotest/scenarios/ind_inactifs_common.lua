--[[
  Lot INDUSTRIE, sous-lot I2 « INACTIFS » : des factions À L'EFFECTIF de départ (fond coupé : `n > floor` faux, F241), jouées 5 000
  ticks. Variantes : `ind-inactifs` (file sûre allumée, shared/team/travail_sur.lua) et `ind-inactifs-avant` (file éteinte par
  l'interface « fo-ia1 » set_sur : le comportement de 0.6.28, même carte, même graine).
  Partie : 2 factions, 30 soldats, 8 ouvriers au plus (= l'effectif de départ : la croissance ne peut pas rouvrir le fond),
  Paisible (aucune menace sur le QG pendant la mesure), factions financées, aucune équipe du joueur.
  Relevé toutes les 60 ticks par faction (team_status) : PNJ sans tâche. Mesure à partir de la minute 1 (les PNJ naissent, les
  premières pensées ouvrent le travail ; la mesure du lot part de 20 s, le régime établi, publié à part, de 40 s). Publiés : part des PNJ sans tâche, causes (menace, bloque, rien) et file sûre
  (cumuls Poles.status().sur.tot), plaques de fer et cuivre du coffre au départ et à la fin (la file ne prend rien au coffre).
  Contrôles (variante allumée) : inactifs <= 5 % des relevés ; cause « rien » <= 2 % des PNJ-pensées ; la file a ouvert du
  travail quand des PNJ ont été affamés. Variante éteinte : mesure seulement.
  Lancement : banc.py ... --qui IND-I2 -- 5000 ind-inactifs <source>. Journal : [FO-IND-INACTIFS] (ou -AVANT).
]]
local MIN = 3600
local CHECK = 4900
local MEASURE_FROM = 1200 -- 20 s : la mesure du lot (démarrage compris)
local STEADY_FROM = 2400  -- 40 s : régime établi (publié à part ; essai 3 : tous les PNJ sans tâche entre 20 et 35 s, le temps que les projets d'extraction donnent des avant-postes)

local function hq_chest(s, force)
  return s.find_entities_filtered({ name = "fo-faction-hq", force = force, limit = 1 })[1]
end

local function chest_counts(e)
  local inv = e and e.valid and e.get_inventory(defines.inventory.chest)
  local out = {}
  for _, n in ipairs({ "iron-plate", "copper-plate", "coal", "stone" }) do out[n] = inv and inv.get_item_count(n) or 0 end
  return out
end

local function sorted_keys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

return function(tag, on)
return {
  description = "IND-I2 : PNJ de factions a l'effectif, file sure " .. (on and "allumee" or "eteinte") .. " (5 000 ticks)",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    ctx.check(ctx.remote("fo-pvp", "set_difficulty", "peaceful") == true, "difficulte Paisible imposee avant la guerre")
    local w = ctx.remote("factorio-overhaul", "war_setting", "fo-war-workers", 8)
    ctx.check(w == 8, "fo-war-workers regle a 8 (effectif de depart)", w)
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    ctx.check(ctx.call("war_start", 2, 30, 8) == true, "guerre lancee : 2 factions, 30 soldats, 8 ouvriers")
    ctx.check(ctx.call("war_fund", 2500) == 2, "2 factions financees (2 500 fer)")
    local n = ctx.remote("fo-ia1", "set_sur", "*", on)
    ctx.check(n ~= nil and n >= 2, "file sure " .. (on and "allumee" or "eteinte") .. " pour toutes les equipes", n)
    local st = ctx.state()
    st.t0 = game.tick
    st.samples, st.idle, st.by_team, st.chest0, st.buckets = 0, 0, {}, {}, {}
    st.late_samples, st.late_idle = 0, 0
  end,

  tick = function(ctx, e)
    if e.tick % 60 ~= 0 or e.tick == 0 then return end
    local st = ctx.state()
    if not st.t0 then return end
    local s = ctx.surface()
    for _, row in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
      if row.key ~= "player" then
        if not st.chest0[row.key] then st.chest0[row.key] = chest_counts(hq_chest(s, row.force)) end
        local status = ctx.remote("fo-ia1", "team_status", row.key)
        if status and status.npcs and e.tick - st.t0 >= MEASURE_FROM then
          local b = st.by_team[row.key] or { samples = 0, idle = 0, n_max = 0 }
          st.by_team[row.key] = b
          for _, npc in ipairs(status.npcs) do
            b.samples, st.samples = b.samples + 1, st.samples + 1
            local bk = math.floor((e.tick - st.t0) / 300)
            st.buckets[bk] = st.buckets[bk] or { n = 0, idle = 0 }
            st.buckets[bk].n = st.buckets[bk].n + 1
            if e.tick - st.t0 >= STEADY_FROM then st.late_samples = st.late_samples + 1 end
            if not npc.task then
              if e.tick - st.t0 >= STEADY_FROM then st.late_idle = st.late_idle + 1 end
              b.idle, st.idle = b.idle + 1, st.idle + 1
              st.buckets[bk].idle = st.buckets[bk].idle + 1
            end
          end
          if #status.npcs > b.n_max then b.n_max = #status.npcs end
        end
      end
    end
    if e.tick % MIN == 0 then
      local parts = {}
      for _, k in ipairs(sorted_keys(st.by_team)) do
        local b = st.by_team[k]
        parts[#parts + 1] = string.format("%s %d PNJ, sans tache %.1f %%", k, b.n_max, b.samples > 0 and 100 * b.idle / b.samples or 0)
      end
      ctx.log(string.format("minute %d | %s", math.floor((e.tick - st.t0) / MIN), table.concat(parts, " | ")))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local pct = st.samples > 0 and 100 * st.idle / st.samples or 0
    ctx.check(#sorted_keys(st.by_team) >= 2 and st.samples > 0, "2 factions relevees", #sorted_keys(st.by_team) .. " factions, " .. st.samples .. " releves")
    local kinds = {}
    local tot_n, tot_idle, tot_menace, tot_rien, tot_bloque, opened, done_ok, done_fail, starved = 0, 0, 0, 0, 0, 0, 0, 0, 0
    for _, row in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
      if row.key ~= "player" then
        local status = ctx.remote("fo-ia1", "team_status", row.key)
        local tot = status and status.sur and status.sur.tot or {}
        tot_n, tot_idle, tot_menace = tot_n + (tot.n or 0), tot_idle + (tot.idle or 0), tot_menace + (tot.menace or 0)
        tot_rien, tot_bloque = tot_rien + (tot.rien or 0), tot_bloque + (tot.bloque or 0)
        opened = opened + (tot.opened_service or 0) + (tot.opened_mine or 0)
        for _, k in ipairs(sorted_keys(tot.kinds or {})) do kinds[k] = (kinds[k] or 0) + tot.kinds[k] end
        done_ok, done_fail, starved = done_ok + (tot.done_ok or 0), done_fail + (tot.done_fail or 0), starved + (tot.starved or 0)
        local c0, c1 = st.chest0[row.key] or {}, chest_counts(hq_chest(s, row.force))
        ctx.log(string.format("%s : coffre au depart fer %d cuivre %d charbon %d pierre %d ; a la fin fer %d cuivre %d charbon %d pierre %d ; effectif %d/%d",
          row.key, c0["iron-plate"] or -1, c0["copper-plate"] or -1, c0.coal or -1, c0.stone or -1, c1["iron-plate"], c1["copper-plate"],
          c1.coal, c1.stone, row.n, row.max))
      end
    end
    local line = {}
    for _, bk in ipairs(sorted_keys(st.buckets)) do
      line[#line + 1] = string.format("%d:%d/%d", bk * 5, st.buckets[bk].idle, st.buckets[bk].n)
    end
    ctx.log("sans tache par tranche de 5 s (debut en s : sans tache/releves, les deux factions) : " .. table.concat(line, " "))
    local kl = {}
    for _, k in ipairs(sorted_keys(kinds)) do kl[#kl + 1] = k .. " " .. kinds[k] end
    ctx.log("taches libres au tableau pendant les attentes (genre, tache-pensees) : " .. table.concat(kl, ", "))
    local late = st.late_samples > 0 and 100 * st.late_idle / st.late_samples or 0
    ctx.log(string.format("regime etabli (des 40 s) : %.1f %% sans tache (%d sur %d releves)", late, st.late_idle, st.late_samples))
    local hors = tot_n - tot_menace > 0 and 100 * (tot_idle - tot_menace) / (tot_n - tot_menace) or 0
    local rien = tot_n > 0 and 100 * tot_rien / tot_n or 0
    ctx.log(string.format("sans tache (releves de 60 ticks, des la minute 1) : %.1f %% (%d sur %d) ; a la pensee : %.1f %% hors menace ; causes en PNJ-pensees : menace %d, bloque %d, rien %d (rien %.1f %%) ; affames %d ; file sure : %d ouverts, %d finis, %d en echec",
      pct, st.idle, st.samples, hors, tot_menace, tot_bloque, tot_rien, rien, starved, opened, done_ok, done_fail))
    if on then
      ctx.check(pct <= 5, "PNJ sans tache <= 5 % des releves (factions a l'effectif, fond coupe)", string.format("%.1f %%", pct))
      ctx.check(late <= 5, "PNJ sans tache <= 5 % des releves en regime etabli (des 40 s)", string.format("%.1f %%", late))
      ctx.check(rien <= 2, "cause « rien » <= 2 % des PNJ-pensees", string.format("%.1f %%", rien))
      ctx.check(starved == 0 or opened > 0, "des PNJ affames : la file a ouvert du travail", string.format("%d affames, %d ouverts", starved, opened))
    end
  end,
}
end
