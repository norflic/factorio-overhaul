--[[
  Lot IA3-0, expérience E180 (docs/IA3_CERVEAU.md §5.2, revue B2) : une force SANS JOUEUR fait-elle avancer une
  recherche du moteur ?
    A « ia3-labo »    : 4 laboratoires alimentés (source invisible du banc), 5 packs rouges chacun, add_research ;
    B « ia3-script »  : aucun laboratoire ; avancement ÉCRIT par script (voie du « laboratoire du QG ») : lecture de
                        research_progress, 0,999 puis 1, fin par `researched = true`, bonus appliqué ;
    C « ia3-temoin »  : laboratoire avec packs mais SANS courant (rien ne doit avancer) ;
    D « ia3-file »    : file de recherche activée, deux technologies ;
    E « ia3-prereq »  : add_research d'une technologie dont le prérequis manque.
  L'événement on_research_finished est écouté (mod de test seulement) : force, technologie, tick, by_script.
  Lancement : `fo-autotest.bat nopause 3700 ia3-recherche <source>`. Journal : [FO-IA3-RECHERCHE].
  Faits lus et écrits tels quels (FAIT ...) ; les contrôles ne portent que sur ce que la conception exige.
]]

local X, Y = 216.5, 216.5
local TECH = "automation"           -- coût FINAL du mod : 1 unité × 10 s (10 en vanilla) : 150 ticks avec 4 laboratoires
local BONUS_TECH = "physical-projectile-damage-1"

local registered = false            -- abonnement refait à chaque chargement (mod de test, rien dans global)

local function tech_name(t) return t and t.name or "nil" end

return {
  description = "E180 : recherche d'une force sans joueur (laboratoires alimentes, avancement ecrit par script)",
  check_tick = 3600,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(X - 24, Y - 16, X + 24, Y + 16, "grass-1")
    ctx.prepare_area(X + 184, Y - 8, X + 216, Y + 8, "grass-1")
    local fa = game.create_force("ia3-labo")
    local fb = game.create_force("ia3-script")
    local fc = game.create_force("ia3-temoin")
    local fd = game.create_force("ia3-file")
    local fe = game.create_force("ia3-prereq")
    st.queue_default = tostring(fa.research_queue_enabled)
    st.players_a = #fa.players
    ctx.power(X, Y, "ia3-labo")
    local labs = 0
    for _, dx in ipairs({ -9, -3, 3, 9 }) do
      local lab = s.create_entity({ name = "lab", position = { X + dx, Y + 6 }, force = fa })
      if lab and lab.insert({ name = "automation-science-pack", count = 5 }) == 5 then labs = labs + 1 end
    end
    st.labs = labs
    st.add_a = tostring(fa.add_research(TECH))
    st.cur_a = tech_name(fa.current_research)
    local lc = s.create_entity({ name = "lab", position = { X + 200, Y }, force = fc })
    st.temoin_lab = lc and lc.insert({ name = "automation-science-pack", count = 10 }) or 0
    st.add_c = tostring(fc.add_research(TECH))
    st.add_b = tostring(fb.add_research(TECH))
    st.cur_b = tech_name(fb.current_research)
    fd.research_queue_enabled = true
    st.add_d1 = tostring(fd.add_research(TECH))
    st.add_d2 = tostring(fd.add_research("logistics"))
    st.queue_d = #fd.research_queue
    st.add_e = tostring(fe.add_research(BONUS_TECH))
    st.cur_e = tech_name(fe.current_research)
    st.events = {}
    -- Durée attendue au temps réel des prototypes FINAUX (le mod réécrit les coûts : automation = 1 unité) :
    -- unités × ticks par unité ÷ laboratoires (vitesse 1, aucun bonus de vitesse pour une force neuve).
    local tp = game.technology_prototypes[TECH]
    st.unit_count, st.unit_ticks = tp.research_unit_count, tp.research_unit_energy
    st.expected = math.floor(tp.research_unit_count * tp.research_unit_energy / 4 + 0.5)
    ctx.check(labs == 4, "4 laboratoires alimentes poses pour ia3-labo, 5 packs chacun", labs)
    ctx.check(st.players_a == 0, "la force ia3-labo n'a aucun joueur", st.players_a)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not registered then
      registered = true
      script.on_event(defines.events.on_research_finished, function(ev)
        local s2 = ctx.state()
        s2.events = s2.events or {}
        local r = ev.research
        s2.events[#s2.events + 1] = string.format("%s:%s:%d:%s", r.force.name, r.name, ev.tick, tostring(ev.by_script))
      end)
    end
    local fa, fb, fc = game.forces["ia3-labo"], game.forces["ia3-script"], game.forces["ia3-temoin"]
    if not (fa and fb and fc) then return end
    if not st.done_a and fa.technologies[TECH].researched then st.done_a = e.tick end
    if e.tick == 600 then st.prog_a600 = fa.research_progress end
    local t = e.tick
    if t == 60 then
      fb.research_progress = 0.5
      st.b_read = fb.research_progress
    elseif t == 120 then
      st.b_120 = tostring(fb.technologies[TECH].researched)
      fb.research_progress = 0.999
    elseif t == 180 then
      st.b_after999 = tostring(fb.technologies[TECH].researched)
      st.b_prog180 = fb.research_progress
    elseif t == 240 then
      local ok, err = pcall(function() fb.research_progress = 1 end)
      st.b_set1 = ok and "accepte" or ("refuse : " .. tostring(err))
    elseif t == 300 then
      st.b_after1 = tostring(fb.technologies[TECH].researched)
      st.b_prog300 = fb.research_progress
      st.b_cur300 = tech_name(fb.current_research)
    elseif t == 360 then
      if not fb.technologies[TECH].researched then fb.technologies[TECH].researched = true end
      st.b_done360 = tostring(fb.technologies[TECH].researched)
      st.b_cur360 = tech_name(fb.current_research)
    elseif t == 420 then
      fb.technologies["military"].researched = true
      st.b_add_bonus = tostring(fb.add_research(BONUS_TECH))
      st.b_dmg_before = fb.get_ammo_damage_modifier("bullet")
      fb.research_progress = 0.5
    elseif t == 480 then
      fb.technologies[BONUS_TECH].researched = true
    elseif t == 540 then
      st.b_dmg_after = fb.get_ammo_damage_modifier("bullet")
      st.b_cur540 = tech_name(fb.current_research)
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local fa, fc = game.forces["ia3-labo"], game.forces["ia3-temoin"]
    ctx.log(string.format("FAIT file par defaut d'une force creee : research_queue_enabled = %s", st.queue_default))
    ctx.log(string.format("FAIT A add_research(%s) = %s, recherche en cours %s ; avancement a 600 ticks %.4f ; finie au tick %s",
      TECH, st.add_a, st.cur_a, st.prog_a600 or -1, tostring(st.done_a)))
    ctx.log(string.format("FAIT B (script) add_research = %s, en cours %s ; ecrit 0,5 relu %.6f ; 0,999 -> recherchee %s (avancement %.4f) ; ecrire 1 : %s -> recherchee %s, avancement %.4f, en cours %s ; researched = true -> %s, en cours %s",
      st.add_b, st.cur_b, st.b_read or -1, tostring(st.b_after999), st.b_prog180 or -1, tostring(st.b_set1),
      tostring(st.b_after1), st.b_prog300 or -1, tostring(st.b_cur300), tostring(st.b_done360), tostring(st.b_cur360)))
    ctx.log(string.format("FAIT B bonus %s : add_research = %s ; modificateur balles %.3f -> %.3f ; en cours apres %s",
      BONUS_TECH, tostring(st.b_add_bonus), st.b_dmg_before or -1, st.b_dmg_after or -1, tostring(st.b_cur540)))
    ctx.log(string.format("FAIT C temoin sans courant : add_research = %s, avancement %.4f, recherchee %s",
      st.add_c, fc.research_progress, tostring(fc.technologies[TECH].researched)))
    ctx.log(string.format("FAIT D file : add_research %s puis %s, longueur de file %d", st.add_d1, st.add_d2, st.queue_d or -1))
    ctx.log(string.format("FAIT E prerequis absent : add_research(%s) = %s, en cours %s", BONUS_TECH, st.add_e, st.cur_e))
    for _, ev in ipairs(st.events or {}) do ctx.log("FAIT evenement on_research_finished " .. ev) end
    local ev_a, ev_b1, ev_bs, ev_c = false, false, false, false
    for _, ev in ipairs(st.events or {}) do
      if ev:find("^ia3%-labo:" .. TECH .. ":%d+:false$") then ev_a = true end
      if ev:find("^ia3%-script:" .. TECH .. ":%d+:false$") then ev_b1 = true end
      if ev:find("^ia3%-script:military:%d+:true$") then ev_bs = true end
      if ev:find("^ia3%-temoin:") then ev_c = true end
    end
    ctx.log(string.format("FAIT cout final de %s : %s unite(s) de %s ticks ; attendu avec 4 laboratoires : %s ticks",
      TECH, tostring(st.unit_count), tostring(st.unit_ticks), tostring(st.expected)))
    ctx.check(st.add_a == "true" and st.cur_a == TECH, "add_research accepte pour une force sans joueur", st.add_a .. " / " .. st.cur_a)
    ctx.check(st.done_a ~= nil and math.abs(st.done_a - st.expected) <= 15,
      "laboratoires alimentes d'une force sans joueur : recherche finie au temps reel des prototypes finaux",
      "tick " .. tostring(st.done_a) .. " pour " .. tostring(st.expected) .. " attendus")
    ctx.check(ev_a, "on_research_finished leve pour la force sans joueur (by_script = false)")
    ctx.check(not fc.technologies[TECH].researched and fc.research_progress == 0 and not ev_c,
      "temoin sans courant : rien n'avance", string.format("%.4f", fc.research_progress))
    ctx.check(st.b_read and math.abs(st.b_read - 0.5) < 1e-6, "avancement ecrit par script relu tel quel (0,5)", st.b_read)
    ctx.check(st.b_after999 == "false", "avancement ecrit a 0,999 sans laboratoire : rien ne finit seul")
    ctx.check(st.b_after1 == "true" and st.b_cur300 == "nil" and ev_b1,
      "avancement ecrit a 1 : recherche finie, file videe, evenement leve comme pour un laboratoire (by_script = false)")
    ctx.check(ev_bs, "researched = true : evenement by_script = true")
    ctx.check(st.b_dmg_after and st.b_dmg_before and st.b_dmg_after > st.b_dmg_before + 0.05,
      "bonus de la technologie applique a la force (modificateur des balles)",
      string.format("%.3f -> %.3f", st.b_dmg_before or -1, st.b_dmg_after or -1))
  end,
}
