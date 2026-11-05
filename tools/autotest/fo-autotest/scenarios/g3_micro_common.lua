--[[
  Lot PERIMETRE2 (G3, essai 3 et relecture D1 à D5) : banc COURT de l'enceinte de VOTRE équipe (consigne du lead, 5/11 16 h : le défaut se
  reproduit dans un micro-scénario qui ÉCHOUE sur l'ancienne règle et PASSE sur la nouvelle, avant toute partie longue).
  Cause mesurée (partie du DC, lot-dc, 0.6.50) : anneau commencé avec 32 murs pour 794, segments de 8, 76 lots écartés dès le premier segment,
  rayon figé, jamais fini.

  Cadre : terrain vidé et refait en herbe (200 x 200), coffre d'équipe en (0, 0), plan directeur « seul » au rayon 1, pas de guerre ; enceinte
  de votre équipe allumée (fo-garde g3, ou g3_ancien pour la règle de l'essai 2) ; projets finis comptés au minimum de l'enceinte (fo-garde banc
  pret) ; une décision d'espace toutes les 60 ticks (fo-garde banc espace, au lieu de 30 s).
    phase A (jusqu'à T_PAY) : 100 murs au coffre, l'anneau en demande bien plus : il NE doit PAS commencer ;
    T_PAY : le coffre reçoit de quoi payer l'anneau EN ENTIER : il commence ; seuls les lots que l'anneau COUPE sont écartés ;
    T_GROW : la base « prend » ses lots libres (fo-garde banc occupe : lots écartés comme après des échecs) : le treillis doit GRANDIR pendant
             la construction de l'anneau ;
    fin : des murs sont POSÉS par les PNJ (au moins un segment fini).
  Non prouvé ici (trop long pour un banc court : un segment à la fois, 12 tronçons) : l'anneau complet et l'écartement de tous les lots dehors à la
  fin ; c'est le banc hors jeu tests/enceinte_flux_test.lua §16 (et FO_BUILD_SRC : échoue sur 8dbd3699, passe sur la règle nouvelle).
  Attendu : g3-micro : BILAN sans ECHEC ; g3-micro-ancien : ECHEC sur « pas commencé avant d'être payé », « lots tout dehors gardés » et
  « grandit pendant la construction » (preuve que le banc voit le défaut).
  Lancement : banc.py --out <archive> --qui PERIMETRE2 -- 4800 g3-micro <source> ; journal : [FO-G3-MICRO] + [FO-ESPACE] du mod.
]]
local CHECK = 4700
local T_READY = 300   -- (lots du rayon 1 évalués)
local T_PAY = 1500
local T_GROW = 2700
local W0 = 100        -- murs au coffre en phase A

local function shape(ctx)
  local s = ctx.surface()
  s.request_to_generate_chunks({ 0, 0 }, 5)
  s.force_generate_chunk_requests()
  local area = { { -100, -100 }, { 100, 100 } }
  for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
    if e.valid then e.destroy() end
  end
  local tiles = {}
  for y = -100, 99 do for x = -100, 99 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
  s.set_tiles(tiles, true)
end

local function walls_on_map(ctx)
  return ctx.surface().count_entities_filtered({ name = "stone-wall", force = "player" })
end

return function(ancien)
  local TAG = "FO-G3-MICRO" .. (ancien and "-ANCIEN" or "")
  return {
    description = "PERIMETRE2 G3 : enceinte de votre equipe, banc court" .. (ancien and " (regle de l'essai 2)" or ""),
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 12) == 12, "effectif de depart 12")
      shape(ctx)
      local chest = ctx.surface().create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      for _, it in ipairs({ { "iron-plate", 2000 }, { "copper-plate", 500 }, { "coal", 1000 }, { "stone-wall", W0 }, { "small-electric-pole", 50 } }) do
        chest.insert({ name = it[1], count = it[2] })
      end
      ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 1 }) == true, "plan directeur active au rayon 1")
      ctx.check(ctx.remote("fo-garde", ancien and "g3_ancien" or "g3") == true, "enceinte de votre equipe allumee" .. (ancien and " (regle de l'essai 2)" or ""))
      local st = ctx.state()
      st.t0, st.chest = game.tick, chest
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.t0 or e.tick % 60 ~= 0 then return end
      local t = e.tick - st.t0
      if t < T_READY then return end
      if not st.ready then
        st.ready = ctx.remote("fo-garde", "banc", "pret")
        ctx.log(string.format("[%s] tick %d : projets finis comptes %s", TAG, e.tick, tostring(st.ready)))
      end
      ctx.remote("fo-garde", "banc", "espace")
      local et = ctx.remote("fo-garde", "banc", "etat")
      if not et then return end
      st.need = et.need or (et.enc and et.enc.ring) or st.need
      if et.enc and not st.started then
        st.started = e.tick
        local cut, outside_out, out_n = 0, 0, 0
        for _, l in ipairs(et.lots) do
          if l.out then out_n = out_n + 1 end
          if l.cut then cut = cut + 1 end
          if l.out and not l.cut and not l.inside then outside_out = outside_out + 1 end
        end
        st.start_out, st.start_outside_out, st.start_cut, st.start_radius = out_n, outside_out, cut, et.radius
        ctx.log(string.format("[%s] tick %d (t %d) : anneau commence, rayon %d, contour %s ; lots ecartes %d dont tout dehors %d, coupes %d ; murs voulus %s",
          TAG, e.tick, t, et.radius, et.enc.bounds and table.concat(et.enc.bounds, ",") or "-", out_n, outside_out, cut, tostring(st.need)))
      end
      if t >= T_PAY and not st.paid then
        st.paid = e.tick
        st.before_pay = st.started
        local need = st.need or 0
        local add = math.max(0, need - W0 + 5)
        if add > 0 then st.chest.insert({ name = "stone-wall", count = add }) end
        ctx.log(string.format("[%s] tick %d : anneau de %d murs, %d murs ajoutes au coffre (paye en entier) ; commence avant : %s", TAG, e.tick, need, add,
          tostring(st.started)))
      end
      if t >= T_GROW and not st.grow_from then
        st.grow_from = et.radius
        st.enc_complete_at_grow = et.enc and et.enc.complete or false
        st.occupied = ctx.remote("fo-garde", "banc", "occupe", 99)
        ctx.log(string.format("[%s] tick %d : la base prend ses lots libres (%s ecartes), rayon %d, anneau %s", TAG, e.tick, tostring(st.occupied), et.radius,
          et.enc and string.format("%d segment(s) dont %d fini(s), complet %s", et.enc.segs, et.enc.fin, tostring(et.enc.complete)) or "aucun"))
      end
      if t > T_GROW and et.radius > (st.grow_from or 99) and not st.grew then
        st.grew = e.tick
        st.grew_complete = et.enc and et.enc.complete or false
        ctx.log(string.format("[%s] tick %d : le treillis grandit au rayon %d (anneau complet : %s)", TAG, e.tick, et.radius, tostring(st.grew_complete)))
      end
      st.last = et
    end,

    finish = function(ctx)
      local st = ctx.state()
      local et = ctx.remote("fo-garde", "banc", "etat") or st.last or {}
      local walls = walls_on_map(ctx)
      ctx.log(string.format("[%s] fin : rayon %s, anneau %s, murs poses %d, anneau voulu %s murs", TAG, tostring(et.radius),
        et.enc and string.format("%d segment(s) dont %d fini(s), complet %s, plein %s, croissance %s", et.enc.segs, et.enc.fin, tostring(et.enc.complete),
          tostring(et.enc.full), tostring(et.enc.grow)) or "aucun", walls, tostring(st.need)))
      ctx.check(st.ready ~= nil, "cadre : projets finis comptes", tostring(st.ready))
      ctx.check(st.need ~= nil and st.need > W0, "cadre : l'anneau demande plus que les murs du coffre", string.format("%s > %d", tostring(st.need), W0))
      ctx.check(st.before_pay == nil, "l'anneau ne commence pas avant d'etre paye en entier", "commence au tick " .. tostring(st.before_pay))
      ctx.check(st.started ~= nil, "l'anneau commence une fois paye", tostring(st.started))
      ctx.check(st.start_outside_out == 0, "au depart, aucun lot tout dehors n'est ecarte (seuls les lots coupes)",
        string.format("%s ecarte(s) tout dehors, %s coupe(s)", tostring(st.start_outside_out), tostring(st.start_cut)))
      ctx.check(st.grew ~= nil and not st.grew_complete, "le treillis grandit pendant la construction de l'anneau",
        string.format("rayon %s -> %s", tostring(st.grow_from), tostring(et.radius)))
      ctx.check(walls > 0 and et.enc ~= nil and (et.enc.fin or 0) >= 1, "des murs sont poses par les PNJ (au moins un segment fini)",
        string.format("%d mur(s), %s segment(s) fini(s)", walls, tostring(et.enc and et.enc.fin)))
    end,
  }
end
