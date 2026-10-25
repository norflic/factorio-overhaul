--[[
  Lot IA1-b « Pôles, managers, généralistes » (docs/EQUIPES_PNJ.md §16) : preuve en moteur réel, 26 min de jeu.
  Lancement : « fo-autotest.bat nopause 94600 ia1-poles <source> ». Journal : [FO-IA1-POLES].

  Votre équipe : 8 PNJ à la pose du coffre, recrues payées au coffre jusqu'à 30 (frein par le travail levé ; le fond
  ne sert que les PNJ au-delà des 8 de départ), coffre garni,
  aucune guerre (aucune menace). Relevé toutes les 60 ticks (interface « fo-ia1 », team_status) ; une pensée d'équipe
  toutes les 300 ticks.
    0 à 6 min   : orientation « equilibre » (40/40/20) ;
    6 min       : orientation changée en « ressources » (60/25/15) ;
    18 min      : CRISE injectée : 30 tâches de minage d'extraction rouvertes pendant 3 min (« avant-poste perdu ») ;
                  au moins 10 min après les changements de l'orientation (délai de garde O.MOVE_COOLDOWN : le modèle
                  pur éprouve la crise sur une équipe assise, tests/org_test.lua ; essai 3 : crise à 8 min, +2 seulement,
                  les PNJ déplacés aux minutes 3 à 7 étaient sous délai de garde) ;
    22 min      : un généraliste tué (sa place n'est pas pourvue avant 2 min : O.PROMOTION_DELAY) ;
    26 min      : contrôles.
  Contrôles (docs §16, IA1-b) :
    - orientation changée : affectations (pôles effectifs, destinations comprises) à la cible à 1 près en 2 pensées
      (10 s) ; effectifs AU TRAVAIL (pôles réels) à la cible à 1 près quand toutes les destinations différées sont
      appliquées, au plus 5 min après (la plus longue tâche : fabrication, 5 min) ;
    - crise : +3 affectés à l'extraction en 2 pensées ;
    - équipe OCCUPÉE à 85 % ou plus (PNJ avec une tâche, relevé toutes les 60 ticks, minutes 5 à 26) ;
    - aucune tâche interrompue (aucun changement immédiat sur un PNJ occupé) ;
    - au plus 6 changements de pôle par PNJ et par heure glissante ;
    - une pensée par équipe et par période (nombre de pensées attendu à 1 près, aucune pensée en double) ;
    - promotion après la mort d'un généraliste : jamais avant 2 min de vacance, au plus 2 pensées après (toutes les
      promotions sur vacance de la partie, morts au combat comprises : essai 3, une mort antérieure au tir du banc).
  Publiés (hors bilan) : part du temps occupé par type de tâche et par fond, tâches de fond ouvertes, « tâches en
  souffrance » servies, jetons refusés, durées mesurées par type, production de la force (MU), rapport des managers.
]]

local MIN = 3600
local T_CRISIS = 18 * MIN
local T_ORIENT = 6 * MIN
local T_KILL = 22 * MIN
local T_BUSY_FROM = 5 * MIN
local CHECK = 93600

local function place_team_chest(ctx)
  local s = ctx.surface()
  local c = game.forces.player.get_spawn_position(s)
  local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
  local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
  if not chest then return false end
  for _, it in ipairs({ { "iron-plate", 4000 }, { "copper-plate", 800 }, { "coal", 800 }, { "stone", 600 },
    { "burner-mining-drill", 16 }, { "stone-furnace", 16 }, { "iron-chest", 8 }, { "firearm-magazine", 200 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  return true
end

local POLES = { "extraction", "base", "territoire" }

local function within1(a, t)
  for p = 1, 3 do
    if math.abs((a[p] or 0) - (t[p] or 0)) > 1 then return false end
  end
  return true
end

local function fmt3(v) return string.format("%d/%d/%d", v[1] or 0, v[2] or 0, v[3] or 0) end

return {
  description = "IA1-b : poles, managers, generalistes (votre equipe a 30, 20 min)",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-recruit-idle-max", 60) == 60, "frein par le travail leve")
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-player-team-npc-max", 30) == 30, "plafond de votre equipe 30")
    -- Départ à 8 (défaut) : le travail de fond ne sert que les PNJ au-delà de l'effectif de départ (recrues payées au
    -- coffre, frein levé) ; l'équipe atteint 30 en 2 à 3 min.
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    ctx.check(place_team_chest(ctx), "coffre d'equipe pose et garni")
    local rows = ctx.remote("fo-ia1", "teams")
    local n = 0
    for _, r in ipairs(rows) do if r.key == "player" then n = r.n end end
    ctx.check(n == 8, "8 PNJ a la pose du coffre", n)
    local st = ctx.state()
    st.t0 = game.tick
    st.samples, st.busy = 0, 0
    st.by_kind = {}
    st.fond_busy = 0
    st.last_think = nil
    st.thinks_seen = 0
  end,

  tick = function(ctx, e)
    if e.tick % 60 ~= 0 or e.tick == 0 then return end
    local st = ctx.state()
    local s = ctx.remote("fo-ia1", "team_status", "player")
    if not (s and s.last) then return end
    local t = e.tick - st.t0

    -- Occupation (relevé toutes les 60 ticks).
    if t >= T_BUSY_FROM then
      for _, npc in ipairs(s.npcs) do
        st.samples = st.samples + 1
        if npc.task then
          st.busy = st.busy + 1
          st.by_kind[npc.task] = (st.by_kind[npc.task] or 0) + 1
          if npc.fond then st.fond_busy = st.fond_busy + 1 end
        end
      end
    end
    if e.tick % MIN == 0 then
      local L = s.last
      ctx.log(string.format("minute %d | n %d inactifs %d | orientation %s | cibles %s | affectes %s | reels %s | gen %s | en partance %d | besoin %d/%d/%d s | place de fond %s | fond ouvert %s | surplus %d",
        math.floor(t / MIN), L.n, L.idle, fmt3(L.pts), fmt3(L.targets), fmt3(L.assigned), fmt3(L.actual), fmt3(L.gens), L.pending,
        math.floor(L.need[1]), math.floor(L.need[2]), math.floor(L.need[3]), fmt3(L.room), fmt3(L.opened), L.surplus or 0))
    end

    -- Nouvelle pensée d'organisation ?
    local new_think = s.last.tick ~= st.last_think
    if new_think then
      st.last_think = s.last.tick
      local L = s.last
      -- Crise : avant / 2 pensées après.
      if st.crisis_at and not st.crisis_done then
        st.crisis_k = (st.crisis_k or 0) + 1
        if st.crisis_k == 2 then
          st.crisis_done = true
          st.crisis_after = L.assigned[1]
          st.crisis_targets = L.targets
        end
      end
      if not st.crisis_at then
        st.crisis_before = L.assigned[1]
        -- Lot IA1-b2 : exécutants HORS de l'extraction juste avant la crise (base + territoire).
        st.crisis_others = (L.assigned[2] or 0) + (L.assigned[3] or 0)
      end
      -- Orientation : décisions à la cible en 2 pensées ; au travail quand plus personne n'est en partance.
      if st.orient_at then
        st.orient_k = (st.orient_k or 0) + 1
        if st.orient_k <= 2 and not st.orient_dec_ok and within1(L.assigned, L.targets) then
          st.orient_dec_ok = st.orient_k
        end
        if st.orient_k == 2 then st.orient_dec_detail = fmt3(L.assigned) .. " pour " .. fmt3(L.targets) end
        if not st.orient_act_at and L.pending == 0 and within1(L.actual, L.targets) and st.orient_k >= 1 then
          st.orient_act_at = L.tick
          st.orient_act_detail = fmt3(L.actual) .. " pour " .. fmt3(L.targets)
        end
      end
      if st.kill_at and not st.promoted_at and (s.stats.promoted or 0) > st.promoted_before then
        st.promoted_at = L.tick
      end
    end

    -- Événements du banc.
    if t >= T_CRISIS and not st.crisis_at then
      st.crisis_at = e.tick
      -- Ressource : la dernière minée avec succès par l'équipe (essai 5 : « iron-ore » introuvable à 96 tuiles du coffre,
      -- les tâches de crise échouaient aussitôt et le besoin retombait en 1 pensée).
      ctx.check(ctx.remote("fo-ia1", "inject_crisis", "player", 30, 3 * MIN) == true, "crise injectee (30 taches de minage, 3 min)")
    elseif t >= T_ORIENT and not st.orient_at then
      st.orient_at = e.tick
      local pts = ctx.remote("fo-ia1", "set_orientation", "player", "ressources")
      ctx.check(pts and pts[1] == 60, "orientation changee en Ressources (60/25/15)", pts and fmt3(pts) or "nil")
      st.orient_from = fmt3(s.last.assigned)
    elseif t >= T_KILL and not st.kill_at then
      local victim
      for _, npc in ipairs(s.npcs) do
        if npc.role == "generalist" and not victim then victim = npc.id end
      end
      st.promoted_before = s.stats.promoted or 0
      st.kill_at = e.tick
      ctx.check(victim ~= nil and ctx.remote("fo-ia1", "kill_npc", "player", victim) == true, "un generaliste tue", victim)
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.remote("fo-ia1", "team_status", "player")
    ctx.check(s ~= nil, "etat d'organisation publie")
    if not s then return end
    local stats = s.stats
    local elapsed = game.tick - st.t0
    local expected = math.floor(elapsed / 300)
    ctx.check(math.abs(stats.thinks - expected) <= 1 and stats.double_think == 0,
      "une pensee par equipe et par periode", string.format("%d pensees pour %d periodes, %d en double", stats.thinks, expected, stats.double_think))
    local busy = st.samples > 0 and 100 * st.busy / st.samples or 0
    ctx.check(busy >= 85, "equipe occupee a 85 % ou plus (minutes 5 a 26, releve toutes les 60 ticks)",
      string.format("%.1f %% (%d sur %d releves) ; mesure a la pensee : %.1f %%", busy, st.busy, st.samples,
        stats.n_sum > 0 and 100 * stats.busy_sum / stats.n_sum or 0))
    -- Lot IA1-b2 (décision de l'orchestrateur, D-18) : « +3, ou tous les ouvriers déjà à l'extraction » (sans les gardes
    -- coupées par le DC, le pôle Territoire de votre équipe est vide en paix : la crise n'a souvent personne à déplacer).
    ctx.check(st.crisis_after and st.crisis_before and (st.crisis_after >= st.crisis_before + 3 or (st.crisis_others or 1) == 0),
      "crise : +3 affectes a l'extraction en 2 pensees, ou tous les ouvriers deja a l'extraction",
      string.format("%s -> %s (cibles %s ; hors extraction avant : %s)", tostring(st.crisis_before),
        tostring(st.crisis_after), st.crisis_targets and fmt3(st.crisis_targets) or "?", tostring(st.crisis_others)))
    ctx.check(st.orient_dec_ok ~= nil, "orientation : affectations a la cible a 1 pres en 2 pensees (10 s)",
      string.format("pensee %s ; %s ; avant %s", tostring(st.orient_dec_ok), tostring(st.orient_dec_detail), tostring(st.orient_from)))
    local act = st.orient_act_at and (st.orient_act_at - st.orient_at) / 60 or nil
    ctx.check(act ~= nil and act <= 300, "orientation : effectifs au travail a la cible a 1 pres a la fin des taches en cours (<= 5 min)",
      string.format("%s s ; %s", act and string.format("%.0f", act) or "jamais", tostring(st.orient_act_detail)))
    ctx.check(stats.interrupted == 0, "aucune tache interrompue (changement immediat d'un PNJ occupe)", stats.interrupted)
    local worst = 0
    for _, npc in ipairs(s.npcs) do if npc.worst_hour > worst then worst = npc.worst_hour end end
    ctx.check(worst <= 6, "au plus 6 changements de pole par PNJ et par heure glissante", worst)
    local dmin, dmax = stats.vacancy_delay_min, stats.vacancy_delay_max
    ctx.check((stats.vacancy_promotions or 0) >= 1 and dmin >= 7200 and dmax <= 7200 + 600,
      "generaliste mort : promotion apres 2 min de vacance, pas avant (toutes les vacances de la partie)",
      string.format("%d promotion(s) sur vacance, delai %s a %s s ; generaliste tue par le banc a %.1f min, promotion suivante a %s",
        stats.vacancy_promotions or 0, dmin and string.format("%.0f", dmin / 60) or "?", dmax and string.format("%.0f", dmax / 60) or "?",
        (st.kill_at - st.t0) / MIN, st.promoted_at and string.format("+%.0f s", (st.promoted_at - st.kill_at) / 60) or "aucune"))

    -- Publiés.
    local kinds = {}
    for k in pairs(st.by_kind) do kinds[#kinds + 1] = k end
    table.sort(kinds)
    local parts = {}
    for _, k in ipairs(kinds) do parts[#parts + 1] = string.format("%s %.1f%%", k, 100 * st.by_kind[k] / math.max(1, st.samples)) end
    ctx.log("temps des PNJ par type de tache (part des releves) : " .. table.concat(parts, ", "))
    ctx.log(string.format("dont travail de fond : %.1f %% des releves ; taches de fond ouvertes %d ; taches en souffrance servies %d ; jetons refuses %d ; changements immediats %d, differes %d, appliques en fin de tache %d ; promotions %d ; generalistes deplaces %d",
      100 * st.fond_busy / math.max(1, st.samples), stats.fond_opened, stats.starve_taken, stats.token_refused, stats.moves_now,
      stats.moves_deferred, stats.settled, stats.promoted, stats.gen_moves))
    local dur = {}
    local dk = {}
    for k in pairs(s.dur or {}) do dk[#dk + 1] = k end
    table.sort(dk)
    for _, k in ipairs(dk) do
      local d = s.dur[k]
      dur[#dur + 1] = string.format("%s %d s (%d)", k, d.n > 0 and math.floor(d.s / d.n) or 0, d.n)
    end
    ctx.log("durees mesurees (moyenne, nombre) : " .. table.concat(dur, ", "))
    local rows = ctx.remote("fo-ia1", "teams")
    for _, r in ipairs(rows) do
      if r.key == "player" then
        ctx.log(string.format("production de la force : %d MU (fer %d, cuivre %d, charbon %d, pierre %d) ; effectif %d ; recrues %d",
          r.produced_mu, r.produced["iron-plate"] or 0, r.produced["copper-plate"] or 0, r.produced["coal"] or 0,
          r.produced["stone"] or 0, r.n, r.recruited))
      end
    end
    local m = s.report and s.report.managers
    if m then
      ctx.log(string.format("managers : gisements %d avant-postes %d foreuses (agrandissements %d en cours) | logistique %d tournees, minage %d (plafond %d) | production %d fabrications, reserve %d foreuses %d fours | fonderie %d fours | defense %d groupes, %d garnisons",
        m.gisements.outposts, m.gisements.drills, m.gisements.grow_busy, m.logistique.service, m.logistique.mine,
        m.logistique.mine_cap, m.production.craft, m.production.drills, m.production.furnaces, m.infrastructures.smelters,
        m.defense.groups, m.defense.garrison))
    end
    for _, g in ipairs(s.report and s.report.generalists or {}) do
      ctx.log(string.format("generaliste %d : pole %s, partie %s, tache %s", g.id, g.pole, g.part, g.task))
    end
  end,
}
