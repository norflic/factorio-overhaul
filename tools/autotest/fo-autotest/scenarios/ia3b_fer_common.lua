--[[
  Lot IA3-b : LE CAS DU DC (25/10 vers 18 h 40 et 18 h 45, OBJECTIFS §5 ; capture
  fo-logs\2026-10-25_DC-captures\pnj-inactifs-fer-ignore.png) : « y en a plein qui foutent rien, et plein qui ne vont pas
  chercher le fer alors qu'ils en ont besoin » ; au-dessus du coffre « Objectif : Charbon — il manque : 62 Plaque de
  fer » ; « ils farment de la pierre et du charbon […] ils en ont a foison ».

  Reproduction : votre équipe AU DÉPART (8 PNJ, aucune guerre), coffre d'équipe avec 6 plaques de fer, 30 charbons,
  60 pierres et RIEN d'autre (l'objectif « charbon » demande 4 foreuses et 4 coffres en fer : 68 fer, il en manque 62),
  aucun four au QG ; trois gisements posés à portée du coffre : fer à 40 tuiles à l'est, charbon à 45 tuiles au sud,
  pierre à 40 tuiles au nord-ouest. Variantes : `ia3b-fer` (réglage fo-war-ia3-marche ALLUMÉ avant la pose du coffre)
  et `ia3b-fer-avant` (éteint : le cerveau d'avant le lot, même carte).
  Lancement : fo-autotest.bat nopause 54100 ia3b-fer <source>. Journal : [FO-IA3B-FER] ou [FO-IA3B-FER-AVANT].

  Relevé toutes les 60 ticks : tâche de chaque PNJ (interface « fo-ia1 », team_status) ; corps de la force : minage à la
  main et ressource minée (entité sélectionnée), immobile à 22 tuiles du coffre sans fabriquer (« attend au coffre ») ;
  plaques de fer produites par la force (statistiques) et au coffre. « En manque » : tant que la force n'a pas produit
  62 plaques de fer depuis la pose ET que l'objectif « charbon » n'est pas atteint.
  Une ligne par minute ; contrôles à la fin (15 min) :
    1. plusieurs PNJ minent le fer en même temps (au moins 2 à un relevé) pendant le manque ;
    2. les 62 plaques de fer sont produites (temps publié) ;
    3. personne n'attend au coffre pendant le manque : PNJ sans tâche ≤ 5 % des relevés PNJ du manque ;
    4. le fer passe avant la pierre et le charbon en surplus : relevés « mine le fer » ≥ relevés « mine pierre ou
       charbon » pendant le manque ;
    5. l'objectif « charbon » est atteint (premier avant-poste de charbon posé).
  Les contrôles sont les ATTENDUS du DC : la variante « avant » doit les manquer (chiffres avant / après).
]]

local MIN = 3600
local CHECK = 54000
local QG_R = 22

local function patch(s, name, c, r, amount)
  for _, e in ipairs(s.find_entities_filtered({ position = c, radius = r + 2 })) do
    if e.valid and e.type ~= "character" and e.name ~= "fo-team-chest" then e.destroy() end
  end
  local n = 0
  for dx = -r, r do
    for dy = -r, r do
      if dx * dx + dy * dy <= r * r then
        s.create_entity({ name = name, position = { c.x + dx, c.y + dy }, amount = amount })
        n = n + 1
      end
    end
  end
  return n
end

return function(tag, on)
return {
  description = "IA3-b : cas du DC, fer manquant au depart (" .. (on and "reglage allume" or "reglage eteint") .. ", 15 min)",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local v = ctx.remote("factorio-overhaul", "war_setting", "fo-war-ia3-marche", on)
    ctx.check(v == on, "reglage fo-war-ia3-marche " .. (on and "allume" or "eteint") .. " avant la pose du coffre", tostring(v))
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    local s = ctx.surface()
    local c0 = game.forces.player.get_spawn_position(s)
    local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
    local hq = { x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.5 }
    local n_fe = patch(s, "iron-ore", { x = hq.x + 40, y = hq.y }, 5, 3000)
    local n_c = patch(s, "coal", { x = hq.x, y = hq.y + 45 }, 5, 3000)
    local n_s = patch(s, "stone", { x = hq.x - 32, y = hq.y - 24 }, 4, 3000)
    local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose", string.format("gisements fer %d, charbon %d, pierre %d tuiles", n_fe, n_c, n_s))
    if not chest then return end
    for _, it in ipairs({ { "iron-plate", 6 }, { "coal", 30 }, { "stone", 60 } }) do
      chest.insert({ name = it[1], count = it[2] })
    end
    local st = ctx.state()
    st.t0 = game.tick
    st.hq = { x = chest.position.x, y = chest.position.y }
    st.fe0 = game.forces.player.item_production_statistics.get_input_count("iron-plate")
    st.short_samples, st.short_idle, st.short_qg = 0, 0, 0
    st.mine_fe, st.mine_other, st.max_fe = 0, 0, 0
    st.min = {}
  end,

  tick = function(ctx, e)
    if e.tick % 60 ~= 0 or e.tick == 0 then return end
    local st = ctx.state()
    if not st.t0 then return end
    local s = ctx.surface()
    local status = ctx.remote("fo-ia1", "team_status", "player")
    if not (status and status.npcs) then return end
    local made = game.forces.player.item_production_statistics.get_input_count("iron-plate") - st.fe0
    if made >= 62 and not st.t62 then st.t62 = e.tick - st.t0 end
    local short = not st.t62 and not st.coal_done
    local idle, fe, other, qg = 0, 0, 0, 0
    for _, n in ipairs(status.npcs) do if not n.task then idle = idle + 1 end end
    for _, c in ipairs(s.find_entities_filtered({ type = "character", force = "player" })) do
      if c.valid then
        local sel = c.selected
        if c.mining_state and c.mining_state.mining then
          local r = sel and sel.valid and sel.name or "?"
          if r == "iron-ore" then fe = fe + 1 elseif r == "coal" or r == "stone" then other = other + 1 end
        elseif c.crafting_queue_size == 0 and not (c.walking_state and c.walking_state.walking) then
          local p = c.position
          if (p.x - st.hq.x) ^ 2 + (p.y - st.hq.y) ^ 2 <= QG_R * QG_R then qg = qg + 1 end
        end
      end
    end
    if short then
      st.short_samples = st.short_samples + #status.npcs
      st.short_idle = st.short_idle + idle
      st.short_qg = st.short_qg + qg
      st.mine_fe = st.mine_fe + fe
      st.mine_other = st.mine_other + other
      if fe > st.max_fe then st.max_fe = fe end
    end
    local m = st.min
    m.n, m.idle, m.fe, m.other, m.qg = (m.n or 0) + 1, (m.idle or 0) + idle, (m.fe or 0) + fe, (m.other or 0) + other, (m.qg or 0) + qg
    if (e.tick - st.t0) % MIN == 0 then
      local chest = s.find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
      local inv = chest and chest.valid and chest.get_inventory(defines.inventory.chest)
      local k = math.max(1, m.n)
      ctx.log(string.format("minute %d | pnj %d | sans tache %.2f | attend au coffre %.2f | mine le fer %.2f | mine pierre/charbon %.2f | fer produit %d | coffre fer %d charbon %d pierre %d minerai %d fours %d | en manque %s",
        math.floor((e.tick - st.t0) / MIN), #status.npcs, m.idle / k, m.qg / k, m.fe / k, m.other / k, made,
        inv and inv.get_item_count("iron-plate") or 0, inv and inv.get_item_count("coal") or 0,
        inv and inv.get_item_count("stone") or 0, inv and inv.get_item_count("iron-ore") or 0,
        s.count_entities_filtered({ name = "stone-furnace", force = "player" }), short and "oui" or "non"))
      st.min = {}
    end
  end,

  on_event = nil,

  finish = function(ctx)
    local st = ctx.state()
    if not st.t0 then return end
    -- Objectif « charbon » atteint : premier avant-poste de charbon (lu à l'interface « fo-ia1 »).
    local rows = ctx.remote("fo-ia1", "teams") or {}
    local outposts = 0
    for _, r in ipairs(rows) do if r.key == "player" then outposts = r.outposts or 0 end end
    local s = ctx.surface()
    local drills = s.count_entities_filtered({ name = "burner-mining-drill", force = "player" })
    ctx.log(string.format("fin : 62 plaques de fer produites %s ; avant-postes %d, foreuses posees %d",
      st.t62 and string.format("a %.1f min", st.t62 / MIN) or "JAMAIS (15 min)", outposts, drills))
    ctx.check(st.max_fe >= 2, "plusieurs PNJ minent le fer en meme temps pendant le manque",
      string.format("au plus %d a un releve", st.max_fe))
    ctx.check(st.t62 ~= nil, "62 plaques de fer produites", st.t62 and string.format("%.1f min", st.t62 / MIN) or "jamais en 15 min")
    local idle = st.short_samples > 0 and 100 * st.short_idle / st.short_samples or 0
    ctx.check(st.short_samples > 0 and idle <= 5, "personne n'attend pendant le manque : PNJ sans tache <= 5 % des releves",
      string.format("%.1f %% sans tache (%d sur %d releves PNJ) ; corps immobiles au coffre %.1f %%", idle, st.short_idle,
        st.short_samples, st.short_samples > 0 and 100 * st.short_qg / st.short_samples or 0))
    ctx.check(st.mine_fe > 0 and st.mine_fe >= st.mine_other, "le fer avant la pierre et le charbon pendant le manque",
      string.format("releves : mine le fer %d, mine pierre ou charbon %d", st.mine_fe, st.mine_other))
    ctx.check(drills >= 1, "objectif charbon : foreuses posees", string.format("%d foreuse(s), %d avant-poste(s)", drills, outposts))
  end,
}
end
