--[[
  Lot DANGER-ACTIF : reproduction EN PETIT du défaut C1 de la partie verif-guide 271828182 (essai 2, code 55682312 : 7 repos de plus de 30 s,
  tous entre 45 et 50 min). Lu dans le journal de cette partie : la vague ap7 (44 min) attaque l'usine à 30-50 tuiles à l'est du QG ; un PNJ
  marque la MEUTE (genre « pack » de shared/ai3/danger.lua, poids 800, rayon = vue 30 + étendue du groupe) en (30, 6), à 24 tuiles de la case
  du QG (6, 9). La zone de la meute COUVRE le QG : la garde du QG (« met de cote (but) : tache garrison vers (6, 9), menace fixe au but 800 »)
  et tous les trajets qui partent du QG, même à l'opposé de l'attaque (61 « met de cote (marque) ... menace fixe au but 0 ») sont mis de côté.
  Aucune tâche : les PNJ attendent au QG.

  Banc : votre équipe seule (8 PNJ, coffre du guide), gisements de fer et de pierre à 45 tuiles à l'OUEST du coffre (travail à l'opposé de
  l'attaque). Au tick T_ATT, 6 déchiqueteurs moyens RÉELS (immobiles, indestructibles : la menace ne change pas pendant la mesure) en groupe à
  DX tuiles à l'est du coffre (QG menacé : unités à moins de 48 tuiles) ; la meute qu'un PNJ marquerait en réagissant est posée par
  l'interface « fo-ia3k » mark (même centre, même rayon que M.sense : vue + étendue) et rafraîchie toutes les REMARK ticks (les regards du jeu
  la rafraîchissent pendant l'attaque). Au tick T_END, les unités partent (la vérification des menaces par les yeux du QG oublie la meute).
  Relevé toutes les 60 ticks : PNJ sans tâche (durée de suite), but de chaque tâche, contact avec la meute ; compteurs de la porte (fo-ia3k
  status : stats.dact), tâches libres pendant les attentes (fo-ia1 team_status : sur.tot), PNJ perdus (fo-ia1 teams).
  Contrôles :
    C1     aucun PNJ sans tâche plus de 30 s de suite pendant l'attaque et après, alors que le tableau a du travail (cause « rien » nulle) ;
    C1-da  repos pour cause de danger (stats.dact : refus de la porte -> départ suivant) : aucun au-delà de 30 s ;
    C2     aucun PNJ perdu ;
    SENS   aucune tâche dont le but est dans la zone de la meute ET plus près d'elle que le coffre (vers l'attaque), hors défense du QG
           (garde, recharge, pose de tourelles) ;
    TRAV   du travail fait pendant l'attaque : au moins une tâche hors défense prise entre T_ATT + 600 et T_END.
  Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui DANGER-ACTIF -- 9700 da-meute <source>. Journal : [FO-DA-MEUTE].
]]

local T_ATT = 1800   -- 30 s : l'équipe a pris ses premières tâches
local T_END = 7800   -- 130 s : 100 s d'attaque
local CHECK = 9600
local DX = 26        -- tuiles à l'est du coffre (journal : meute à 24 tuiles de la case du QG)
local REMARK = 300
local POLL = 60
local REST = 1800    -- 30 s (critère C1)
local UNIT = "medium-biter"
local OFFS = { { -4, -4 }, { 0, -4 }, { 4, -4 }, { -4, 4 }, { 0, 4 }, { 4, 4 } }
local DEFENSE = { garrison = true, refill = true, fortify = true }

local function patch(s, name, c, r, amount)
  for _, e in ipairs(s.find_entities_filtered({ position = c, radius = r + 3 })) do
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

local function d2(a, b) return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 end

local function sorted_keys(t)
  local keys = {}
  for k in pairs(t or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

local function player_row(ctx)
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key == "player" then return r end
  end
  return nil
end

local function sur_tot(ctx)
  local status = ctx.remote("fo-ia1", "team_status", "player")
  local tot = status and status.sur and status.sur.tot or {}
  local out = { idle = tot.idle or 0, menace = tot.menace or 0, bloque = tot.bloque or 0, rien = tot.rien or 0, kinds = {} }
  for _, k in ipairs(sorted_keys(tot.kinds)) do out.kinds[k] = tot.kinds[k] end
  return out
end

return function(opts)
local TAG = opts.tag
return {
  description = opts.description,
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    ctx.check(ctx.call("war_setting", "fo-war-ia3-comportement", true) == true, "reglage fo-war-ia3-comportement allume")
    ctx.call("profiler", true)
    local s = ctx.surface()
    local c0 = game.forces.player.get_spawn_position(s)
    local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
    local hq = { x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.5 }
    -- Travail à l'OUEST (opposé de l'attaque) : fer et pierre à 45 tuiles.
    local fe = { x = math.floor(hq.x) - 45, y = math.floor(hq.y) - 6 }
    local pi = { x = math.floor(hq.x) - 45, y = math.floor(hq.y) + 10 }
    local n_fe = patch(s, "iron-ore", fe, 6, 4000)
    local n_pi = patch(s, "stone", pi, 4, 3000)
    local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose", string.format("fer %d tuiles en (%d, %d), pierre %d tuiles en (%d, %d)", n_fe, fe.x, fe.y, n_pi, pi.x, pi.y))
    if not chest then return end
    -- Coffre de la partie du guide (scenarios/verif_guide_common.lua).
    for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
      { "pistol", 3 }, { "firearm-magazine", 60 }, { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
      chest.insert({ name = it[1], count = it[2] })
    end
    st.hq = { x = chest.position.x, y = chest.position.y }
    st.c = { x = st.hq.x + DX, y = st.hq.y }
    local pr = game.entity_prototypes[UNIT]
    local spread = 0
    for _, o in ipairs(OFFS) do
      local d = math.sqrt(o[1] * o[1] + o[2] * o[2])
      if d > spread then spread = d end
    end
    st.r = (pr and pr.vision_distance or 30) + spread -- rayon de la meute de M.sense : vue + étendue du groupe
    st.zone = st.r + 4                                -- D.EXACT_MARGIN : zone jugée par la porte
    st.free_since, st.streaks, st.toward, st.toward_seen = {}, {}, 0, {}
    st.max_free, st.max_free_id, st.max_free_at = 0, nil, nil
    st.work_ids, st.contact = {}, 0
    ctx.log(string.format("[FO-%s] coffre en (%.1f, %.1f) ; meute prevue en (%.1f, %.1f), rayon %.1f, zone de la porte %.1f (coffre a %d tuiles du centre)",
      TAG, st.hq.x, st.hq.y, st.c.x, st.c.y, st.r, st.zone, DX))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.hq then return end
    local t = e.tick
    local s = ctx.surface()
    if t == T_ATT then
      st.units = {}
      for _, o in ipairs(OFFS) do
        local q = s.find_non_colliding_position(UNIT, { x = st.c.x + o[1], y = st.c.y + o[2] }, 4, 0.5)
        local u = q and s.create_entity({ name = UNIT, position = q, force = "enemy" })
        if u then
          u.active = false
          u.destructible = false
          st.units[#st.units + 1] = u
        end
      end
      st.lost0 = (player_row(ctx) or {}).lost or 0
      st.sur0 = sur_tot(ctx)
      local busy = 0
      for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do if a.task then busy = busy + 1 end end
      st.busy_att = busy
      ctx.log(string.format("[FO-%s] attaque au tick %d : %d unite(s) posee(s), %d PNJ avec une tache", TAG, t, #st.units, busy))
    end
    if t >= T_ATT and t < T_END and (t - T_ATT) % REMARK == 0 then
      ctx.remote("fo-ia3k", "mark", "player", st.c.x, st.c.y, "pack", st.r)
    end
    if t == T_END then
      for _, u in ipairs(st.units or {}) do if u.valid then u.destroy() end end
      st.sur1 = sur_tot(ctx)
      ctx.log(string.format("[FO-%s] fin de l'attaque au tick %d : unites retirees", TAG, t))
    end
    if t < T_ATT or t % POLL ~= 0 then return end
    local agents = ctx.remote("fo-ia3k", "agents", "player") or {}
    for _, a in ipairs(agents) do
      if not a.task then
        if not st.free_since[a.id] then st.free_since[a.id] = t end
      else
        local since = st.free_since[a.id]
        if since then
          local d = t - since
          if d > st.max_free then st.max_free, st.max_free_id, st.max_free_at = d, a.id, since end
          if d > REST then st.streaks[#st.streaks + 1] = { id = a.id, from = since, d = d } end
          st.free_since[a.id] = nil
        end
        if t > T_ATT + 600 and t < T_END and not DEFENSE[a.task] then st.work_ids[a.id] = true end
        -- SENS : but de la tâche (destination de l'itinéraire) dans la zone de la meute ET plus près d'elle que le coffre.
        if t < T_END and a.final and not DEFENSE[a.task] then
          local df, dh = d2(a.final, st.c), d2(st.hq, st.c)
          local key = a.id .. ":" .. math.floor(a.final.x) .. ":" .. math.floor(a.final.y)
          if df <= st.zone * st.zone and df < dh and not st.toward_seen[key] then
            st.toward_seen[key] = true
            st.toward = st.toward + 1
            ctx.log(string.format("[FO-%s] PNJ %d tache %s vers (%.0f, %.0f), a %.0f tuiles de la meute (coffre a %.0f) : vers l'attaque",
              TAG, a.id, tostring(a.task), a.final.x, a.final.y, math.sqrt(df), math.sqrt(dh)))
          end
        end
      end
      if t < T_END and d2(a, st.c) <= 12 * 12 then st.contact = st.contact + 1 end
    end
    if (t - T_ATT) % 1800 == 0 then
      local free = 0
      for _, a in ipairs(agents) do if not a.task then free = free + 1 end end
      ctx.log(string.format("[FO-%s] tick %d : %d PNJ, %d sans tache, plus longue attente close %.1f s", TAG, t, #agents, free, st.max_free / 60))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local t = game.tick
    if not st.hq then
      ctx.fail("banc prepare", "coffre absent")
      return
    end
    -- Attentes encore ouvertes : closes à la fin.
    for _, id in ipairs(sorted_keys(st.free_since)) do
      local d = t - st.free_since[id]
      if d > st.max_free then st.max_free, st.max_free_id, st.max_free_at = d, id, st.free_since[id] end
      if d > REST then st.streaks[#st.streaks + 1] = { id = id, from = st.free_since[id], d = d, open = true } end
    end
    local sur1 = st.sur1 or sur_tot(ctx)
    local s0 = st.sur0 or { idle = 0, menace = 0, bloque = 0, rien = 0, kinds = {} }
    local kinds = {}
    for _, k in ipairs(sorted_keys(sur1.kinds)) do
      local dk = sur1.kinds[k] - (s0.kinds[k] or 0)
      if dk > 0 then kinds[#kinds + 1] = string.format("%s %d", k, dk) end
    end
    local rien = sur1.rien - s0.rien
    ctx.log(string.format("[FO-%s] pendant l'attaque (PNJ-pensees sans tache) : menace %d, bloque %d, rien %d ; taches libres pendant ces attentes {%s}",
      TAG, sur1.menace - s0.menace, sur1.bloque - s0.bloque, rien, table.concat(kinds, ", ")))
    local parts = {}
    for _, sk in ipairs(st.streaks) do
      parts[#parts + 1] = string.format("PNJ %d %.1f s des %.1f s%s", sk.id, sk.d / 60, sk.from / 60, sk.open and " (ouverte)" or "")
    end
    ctx.check(st.busy_att and st.busy_att > 0, "l'equipe travaille avant l'attaque", st.busy_att)
    ctx.check(#(st.units or {}) == #OFFS, "meute posee a l'est du QG (unites a moins de 48 tuiles du coffre)", #(st.units or {}))
    ctx.check(rien == 0, "du travail au tableau pendant les attentes (cause rien nulle)", rien)
    ctx.check(#st.streaks == 0, "C1 : aucun PNJ sans tache plus de 30 s de suite (attaque et apres)",
      string.format("plus longue %.1f s (PNJ %s des %.1f s) ; %s", st.max_free / 60, tostring(st.max_free_id), (st.max_free_at or 0) / 60,
        #parts > 0 and table.concat(parts, " ; ") or "aucune au-dela de 30 s"))
    local status = ctx.remote("fo-ia3k", "status", "player")
    local da = status and status.stats and status.stats.dact or {}
    local why = {}
    for _, k in ipairs(sorted_keys(da.why)) do why[#why + 1] = string.format("%s %d", k, da.why[k]) end
    ctx.check((da.rest_over or 0) == 0 and (da.rest_max or 0) <= REST, "C1-da : aucun repos pour cause de danger au-dela de 30 s (refus -> depart)",
      string.format("repos fermes %d, plus long %.1f s, au-dela de 30 s %d ; mises de cote %d, departs a risque %d {%s}", da.rest_n or 0,
        (da.rest_max or 0) / 60, da.rest_over or 0, da.aside or 0, da.go or 0, table.concat(why, ", ")))
    local lost = ((player_row(ctx) or {}).lost or 0) - (st.lost0 or 0)
    ctx.check(lost == 0, "C2 : aucun PNJ perdu", lost)
    ctx.check(st.toward == 0, "SENS : aucune tache vers l'attaque (but dans la zone de la meute, plus pres d'elle que le coffre), hors defense du QG",
      string.format("%d tache(s) vers l'attaque ; %d releve(s) de PNJ a moins de 12 tuiles de la meute", st.toward, st.contact))
    ctx.check(#sorted_keys(st.work_ids) > 0, "TRAV : du travail hors defense pendant l'attaque", #sorted_keys(st.work_ids) .. " PNJ")
  end,
}
end
