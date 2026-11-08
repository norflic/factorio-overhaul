--[[
  Lot TV-ENERGIE (couverture de la TODO vidéo, 8/11) : MICRO-BANC en moteur réel (2 500 ticks), ce qui se prouve vite :
    G41  la première expansion d'une équipe sans centrale fait demander la centrale D'ABORD (Build.request, règle shared/team/energie_dabord.lua) :
         une demande d'expansion (remote fo-ia1d request, 3e argument vrai = une vraie expansion et non une demande de banc) place un projet de
         centrale EN TÊTE du plan directeur, derrière lui le module demandé ; une seconde expansion n'en demande pas une autre ;
    W02  le relevé du courant de la capitalisation n'est plus nil sans centrale finie (remote fo-capi power_probe) : { amorce } sans centrale,
         { fermee = texte } centrale refusée ou attendue par un module ouvert, relevé VIDE centrale finie sans capacité lue ;
    V36  la lecture du tampon de vapeur (fluidbox d'une machine à vapeur : contenu et capacité) fonctionne dans le moteur 1.1.91 ;
    V89  la dégradation graduée (remote fo-cadence degrade_feed) : l'état est dans global, le niveau monte et descend par lectures de suite,
         la période de repos des factions lointaines et calmes suit le niveau (600, 900, 1 200, 1 800), le journal [FO-DEGRADE] l'écrit ; la
         guerre (2 factions) tourne avec le guet qui lit la vraie file des travaux lourds, sans erreur.
  NE PROUVE PAS (hors micro-banc, voir RAPPORT) : l'unité de SECOURS (G65) exige une centrale finie puis détruite pendant 3 min (10 800 ticks
  au moins), le déclenchement du tampon de vapeur bas (V36) exige une centrale en marche à sec ; leurs règles sont prouvées hors jeu
  (tests/tv_energie_test.lua, avec PA.watch réel sur le moteur simulé) et leurs lectures du moteur ici (API).
  Lancement : banc.py --out <archive> --qui TV-ENERGIE -- 2500 tv-energie <source figée>   Journal : [FO-TV-ENERGIE] ; BILAN automatique.
]]

local function find_gen(projects, gen)
  for i, p in ipairs(projects or {}) do
    if p.gen == gen then return i, p end
  end
  return nil
end

return {
  description = "TV-ENERGIE : l'energie d'abord (G41), releve du courant (W02), tampon de vapeur (V36), degradation graduee (V89)",
  base = nil,
  check_tick = 2000,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.check(ctx.call("war_setting", "fo-war-ia3e", false) == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)")
    local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if chest then
      chest.insert({ name = "iron-plate", count = 400 })
      chest.insert({ name = "coal", count = 200 })
    end
    ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 4 }) == true, "plan directeur active")
    ctx.check(ctx.has("fo-ia1d", "request") and ctx.has("fo-capi", "power_probe") and ctx.has("fo-cadence", "degrade_feed"),
      "interfaces distantes du lot disponibles (fo-ia1d request, fo-capi power_probe, fo-cadence degrade_feed)")
    st.t0 = game.tick
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local t = e.tick - st.t0
    local s = ctx.surface()

    if t == 60 then
      -- G41 : aucune centrale demandée ; la première expansion la fait demander d'abord
      local r0 = ctx.remote("fo-ia1d", "report", "player")
      st.n0 = r0 and #r0.projects or -1
      local id = ctx.remote("fo-ia1d", "request", "player", { gen = "gears", args = { 2, "assembling-machine-1" }, feed = true, prio = 60 }, true)
      local r1 = ctx.remote("fo-ia1d", "report", "player")
      st.exp_id, st.n1 = id, r1 and #r1.projects or -1
      local ip = find_gen(r1 and r1.projects, "steam")
      local ig = find_gen(r1 and r1.projects, "gears")
      st.plant_pos, st.gears_pos = ip, ig
      ctx.log(string.format("G41 : %d projet(s) avant, %d apres ; centrale au rang %s, module au rang %s", st.n0, st.n1, tostring(ip), tostring(ig)))
    elseif t == 62 then
      local id = ctx.remote("fo-ia1d", "request", "player", { gen = "gears", args = { 3, "assembling-machine-1" }, feed = true, prio = 60 }, true)
      local r2 = ctx.remote("fo-ia1d", "report", "player")
      st.n2 = r2 and #r2.projects or -1
      local plants = 0
      for _, p in ipairs(r2 and r2.projects or {}) do if p.gen == "steam" then plants = plants + 1 end end
      st.plants2 = plants
      ctx.log(string.format("G41 : seconde expansion (projet %s) : %d projet(s), %d centrale(s)", tostring(id), st.n2, plants))
    elseif t == 200 then
      -- W02 : le relevé du courant selon l'état de la centrale
      local amorce = ctx.remote("fo-capi", "power_probe", "player")
      local refuse = ctx.remote("fo-capi", "power_probe", "player", "refuse", "pas de rive libre")
      local attente = ctx.remote("fo-capi", "power_probe", "player", "attente", nil, true)
      local ferme_sans_module = ctx.remote("fo-capi", "power_probe", "player", "attente", nil, false)
      local fini = ctx.remote("fo-capi", "power_probe", "player", "fini")
      st.w02 = { amorce = amorce, refuse = refuse, attente = attente, sans_module = ferme_sans_module, fini = fini }
      ctx.log(string.format("W02 : sans centrale %s ; refusee %s ; attendue par un module %s ; attendue sans module %s ; finie sans capacite lue %s",
        tostring(amorce and amorce.amorce), tostring(refuse and refuse.fermee), tostring(attente and attente.fermee),
        tostring(ferme_sans_module and ferme_sans_module.amorce), tostring(fini ~= nil and next(fini) == nil)))
    elseif t == 300 then
      -- V36 : lecture du tampon de vapeur d'une machine à vapeur dans le moteur réel
      local pos = s.find_non_colliding_position("steam-engine", { 30, 30 }, 20, 1)
      local eng = pos and s.create_entity({ name = "steam-engine", position = pos, force = "player", direction = defines.direction.north })
      if eng then
        local fb = eng.fluidbox
        local cap = fb and #fb >= 1 and fb.get_capacity(1) or nil
        local before = fb and fb[1] and fb[1].amount or 0
        fb[1] = { name = "steam", amount = 40 }
        local after = fb[1] and fb[1].amount or nil
        st.v36 = { cap = cap, before = before, after = after }
        ctx.log(string.format("V36 : machine a vapeur, capacite du tampon %s, contenu %s -> %s (%.0f %%)", tostring(cap), tostring(before), tostring(after),
          (after and cap and cap > 0) and (after / cap * 100) or -1))
        eng.destroy()
      end
    elseif t == 400 then
      -- V89 : montée et descente des niveaux, période de repos
      local a = ctx.remote("fo-cadence", "degrade_feed", 1, 3)
      local b = ctx.remote("fo-cadence", "degrade_feed", 5, 3)
      local c = ctx.remote("fo-cadence", "degrade_feed", 20, 6)
      local d = ctx.remote("fo-cadence", "degrade_feed", 0, 9)
      st.v89 = { a = a, b = b, c = c, d = d }
      ctx.log(string.format("V89 : niveaux %s (profondeur 1) -> %s (5, repos %s) -> %s (20, repos %s) -> %s (0, repos %s)",
        tostring(a and a.level), tostring(b and b.level), tostring(b and b.slow), tostring(c and c.level), tostring(c and c.slow), tostring(d and d.level),
        tostring(d and d.slow)))
    elseif t == 600 then
      -- la guerre : le guet lit la vraie file des travaux lourds toutes les 60 ticks
      st.war = ctx.call("war_start", 2, 20, 3)
      ctx.log("guerre lancee : " .. tostring(st.war))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    -- G41
    ctx.check(st.n0 == 0, "G41 : aucun projet avant la premiere expansion", st.n0)
    ctx.check(st.n1 == 2 and st.plant_pos == 1 and st.gears_pos == 2,
      "G41 : la centrale est demandee AVANT et placee en tete, le module derriere", string.format("%s projets, centrale %s, module %s", tostring(st.n1), tostring(st.plant_pos), tostring(st.gears_pos)))
    ctx.check(st.plants2 == 1 and st.n2 == 3, "G41 : une seconde expansion ne demande pas une seconde centrale", string.format("%s centrale(s), %s projets", tostring(st.plants2), tostring(st.n2)))
    -- W02
    local w = st.w02 or {}
    ctx.check(w.amorce and w.amorce.amorce == true and w.amorce.have_kw == nil, "W02 : sans centrale finie, le releve est { amorce } (plus nil)")
    ctx.check(w.refuse and w.refuse.fermee == "centrale refusee (pas de rive libre)", "W02 : centrale refusee : releve ferme avec la cause", w.refuse and w.refuse.fermee)
    ctx.check(w.attente and w.attente.fermee == "centrale demandee, pas finie (attente)", "W02 : centrale attendue par un module ouvert : releve ferme", w.attente and w.attente.fermee)
    ctx.check(w.sans_module and w.sans_module.amorce == true, "W02 : centrale demandee sans module ouvert : amorce")
    ctx.check(w.fini ~= nil and next(w.fini) == nil, "W02 : centrale finie sans capacite lue : releve VIDE (garde fermee)")
    -- V36
    local v = st.v36 or {}
    ctx.check(type(v.cap) == "number" and v.cap > 0, "V36 : capacite du tampon de la machine a vapeur lue au moteur", v.cap)
    ctx.check(type(v.after) == "number" and v.after > 0 and v.after <= (v.cap or 0), "V36 : contenu du tampon relu apres ecriture", v.after)
    -- V89
    local d = st.v89 or {}
    ctx.check(d.a and d.a.level == 0, "V89 : profondeur 1 (sous le premier seuil) : niveau 0", d.a and d.a.level)
    ctx.check(d.b and d.b.level == 1 and d.b.slow == 900, "V89 : 3 lectures a la profondeur 5 : niveau 1, repos 900", d.b and (tostring(d.b.level) .. "/" .. tostring(d.b.slow)))
    ctx.check(d.c and d.c.level == 3 and d.c.slow == 1800, "V89 : 6 lectures a la profondeur 20 : niveau 3, repos 1800", d.c and (tostring(d.c.level) .. "/" .. tostring(d.c.slow)))
    ctx.check(d.d and d.d.level == 0 and d.d.slow == 600, "V89 : 9 lectures a 0 : retour au niveau 0, repos 600", d.d and (tostring(d.d.level) .. "/" .. tostring(d.d.slow)))
    ctx.check(d.d and d.d.changes == 6, "V89 : 6 changements de niveau au journal (3 montees, 3 descentes)", d.d and d.d.changes)
    local now = ctx.remote("fo-cadence", "degrade_state")
    ctx.check(now and now.level == 0 and now.slow == 600, "V89 : la guerre a tourne avec le guet : niveau 0, aucune file", now and (tostring(now.level) .. " / profondeur " .. tostring(now.depth)))
    ctx.check(st.war == true, "la guerre (2 factions) s'est lancee", tostring(st.war))
  end,
}
