--[[
  Lot PREVISION : banc COURT en moteur réel de l'estimateur unique de la menace (script/ai3/prevision.lua). Il prouve la
  PLOMBERIE en moteur réel (lecture des prototypes de nids et de tourelles, pollution aux nids connus, évolution, réglages de
  carte, cadre « preparer », lignes du front, alerte de l'armée, journal [FO-PREVISION]) ; il ne mesure PAS la précision du
  modèle (banc long prev-ombre : accord du DC requis).
  Déroulé (2 factions, 10 soldats chacune) :
    - tick 120 : 6 nids de biters à 110 tuiles au nord du QG de la première faction, 6 fours près de son QG (pollueurs) ;
      évolution 0,6 ; les nids sont « vus » par l'équipe (interface du banc, comme le regard d'un PNJ en marche) ;
    - tick 180 : relevé SANS pollution aux nids : aucune vague prévue ;
    - tick 240 : pollution posée sur les nids (surface.pollute), relevé : vague imminente prévue, au-dessus de la défense :
      cadre « preparer » du QG, lignes de la pile et du front, alerte de l'armée et besoin ;
    - tick 300 : mêmes conditions chez une AUTRE faction (fours, nids pollués à 110 tuiles), mais nids que personne n'a vus :
      aucune vague chez elle (comme le joueur) ;
    - la partie continue jusqu'au contrôle (les nids peuvent attaquer : faits de calibration au journal, hors bilan).
  Lancement : `py -3.9 -B tools/autotest/banc.py --out <archive> --qui PREVISION -- 3000 prev-vague <source>`. Journal :
  [FO-PREV-VAGUE].
]]

local NEST_D = 110
local N_NESTS = 6

local function team(ctx, i)
  local list = ctx.remote("fo-prevision", "teams")
  return list and list[i] or nil
end

return {
  description = "PREVISION : vague prevue par la pollution aux nids connus (plomberie en moteur reel)",
  check_tick = 2900,

  init = function(ctx)
    local ok = ctx.call("war_start", 2, 10, 3, 260)
    ctx.check(ok == true, "guerre lancee (2 factions)", tostring(ok))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == 120 then
      local t1 = team(ctx, 1)
      if not t1 then return end
      st.key, st.hx, st.hy = t1.key, t1.x, t1.y
      ctx.prepare_area(t1.x - 30, t1.y - NEST_D - 20, t1.x + 30, t1.y - NEST_D + 20, "grass-1")
      st.nests = 0
      for i = 1, N_NESTS do
        local x, y = t1.x - 25 + i * 8, t1.y - NEST_D
        local n = s.create_entity({ name = "biter-spawner", position = { x, y }, force = "enemy" })
        if n then
          st.nests = st.nests + 1
          ctx.remote("fo-prevision", "know_nest", t1.key, n.position.x, n.position.y)
        end
      end
      local force = nil
      for _, ent in ipairs(s.find_entities_filtered({ position = { t1.x, t1.y }, radius = 12, type = "container" })) do
        if ent.force.name ~= "player" and ent.force.name ~= "neutral" then force = ent.force break end
      end
      st.furnaces = 0
      if force then
        for i = 1, 6 do
          local p = s.find_non_colliding_position("stone-furnace", { t1.x - 12 + i * 3, t1.y + 18 }, 10, 1)
          if p and s.create_entity({ name = "stone-furnace", position = p, force = force }) then st.furnaces = st.furnaces + 1 end
        end
      end
      game.forces.enemy.evolution_factor = 0.3
      -- Coffre garni (fer et tourelles) : la défense réunissable dépasse la vague (cadre « preparer », pas « insurmontable »).
      local hq = s.find_entities_filtered({ position = { t1.x, t1.y }, radius = 12, type = "container", force = force })[1]
      if hq then
        hq.insert({ name = "iron-plate", count = 2000 })
        hq.insert({ name = "gun-turret", count = 6 })
      end
      ctx.log(string.format("tick 120 : faction %s, %d nid(s) vus a %d tuiles au nord, %d four(s)", tostring(st.key), st.nests, NEST_D,
        st.furnaces))
    elseif e.tick == 180 and st.key then
      st.calm = ctx.remote("fo-prevision", "relook", st.key)
    elseif e.tick == 240 and st.key then
      for i = 1, N_NESTS do s.pollute({ st.hx - 25 + i * 8, st.hy - NEST_D }, 3000) end
      st.poll = s.get_pollution({ st.hx, st.hy - NEST_D })
      st.hot = ctx.remote("fo-prevision", "relook", st.key)
    elseif e.tick == 300 then
      local t2 = team(ctx, 2)
      if t2 then
        st.key2 = t2.key
        -- Mêmes conditions que la première (fours, nids pollués à 110 tuiles, du côté opposé à la première faction), mais
        -- les nids n'entrent dans AUCUNE carte de l'équipe : relevé dans le même tick que leur pose, avant tout regard.
        local dir = (st.hx and t2.x < st.hx) and -1 or 1
        local force = nil
        for _, ent in ipairs(s.find_entities_filtered({ position = { t2.x, t2.y }, radius = 12, type = "container" })) do
          if ent.force.name ~= "player" and ent.force.name ~= "neutral" then force = ent.force break end
        end
        if force then
          for i = 1, 6 do
            local p = s.find_non_colliding_position("stone-furnace", { t2.x - 12 + i * 3, t2.y + 18 }, 10, 1)
            if p then s.create_entity({ name = "stone-furnace", position = p, force = force }) end
          end
        end
        local nx = t2.x + dir * NEST_D
        ctx.prepare_area(nx - 20, t2.y - 30, nx + 20, t2.y + 30, "grass-1")
        for i = 1, 3 do
          s.create_entity({ name = "biter-spawner", position = { nx, t2.y - 16 + i * 8 }, force = "enemy" })
          s.pollute({ nx, t2.y - 16 + i * 8 }, 3000)
        end
        st.other = ctx.remote("fo-prevision", "relook", t2.key)
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.nests == N_NESTS and (st.furnaces or 0) >= 1, "nids et fours poses", tostring(st.nests) .. " nids, " .. tostring(st.furnaces) .. " fours")
    local c = st.calm
    ctx.check(c and c.est and c.est.known >= N_NESTS and (c.est.absorbed or 0) == 0,
      "nids connus SANS pollution recue : aucun ne nous vise, aucune vague modelisee (garnison exclue de la vague vue)",
      c and c.est and string.format("%d nids connus, %d rattaches, absorbee %s/min (pollution aux cases %s, aux voisines %s), vague (vue comprise) %s PV",
        c.est.known, c.est.nests, tostring(c.est.absorbed), tostring(c.est.poll_c), tostring(c.est.poll_nb),
        tostring(c.sites.qg and c.sites.qg.w5)) or "aucun etat")
    local h = st.hot
    local q = h and h.sites and h.sites.qg
    ctx.check((st.poll or 0) > 0, "pollution lue aux nids (moteur)", st.poll)
    ctx.check(h and h.est and h.est.nests >= 1 and h.est.hbar > 0 and h.est.pbar > 0,
      "prototypes des nids lus (unite moyenne en PV et en pollution) et nids qui nous visent",
      h and h.est and string.format("%d nid(s), %.0f PV, %.0f pollution", h.est.nests, h.est.hbar, h.est.pbar) or "aucun etat")
    ctx.check(h and (h.turret_value or 0) > 0, "valeur d'une tourelle calculee depuis ses prototypes (degats, cadence, portee)",
      h and h.turret_value)
    ctx.check(q and q.w5 > 0 and q.eta and q.eta <= 5, "vague imminente prevue au QG",
      q and string.format("%.0f PV dans %.1f min", q.w5, q.eta or -1) or "aucun site")
    ctx.check(q and q.prep and h.pile_rows >= 1 and h.front_rows >= 1, "cadre PREPARER du QG : lignes de la pile et du front",
      q and string.format("preparer %s, pile %d, front %d, %s", tostring(q.prep), h.pile_rows, h.front_rows, tostring(q.why)) or "")
    ctx.check(h and h.alert and (h.need or 0) > 0, "armee en alerte, besoin estime", h and (tostring(h.alert) .. ", besoin " .. tostring(h.need)))
    ctx.check(h and (h.hp_per_emit or 0) > 0, "defense induite d'un agrandissement (capitalisation)", h and h.hp_per_emit)
    local o = st.other
    ctx.check(o and o.sites and o.sites.qg and (o.sites.qg.w5 or 0) == 0, "nids jamais vus par l'autre faction : aucune vague chez elle",
      o and o.sites and o.sites.qg and o.sites.qg.w5)
    local fin = ctx.remote("fo-prevision", "status", st.key or "")
    if fin then
      ctx.log(string.format("fin : alerte %s, besoin %s, k du QG %s, preparer %s (%s), emission %s/min, vague %s PV, defense %s PV",
        tostring(fin.alert), tostring(fin.need), tostring(fin.k and fin.k.qg), tostring(fin.sites.qg and fin.sites.qg.prep),
        tostring(fin.sites.qg and fin.sites.qg.why), tostring(fin.est and fin.est.emit), tostring(fin.sites.qg and fin.sites.qg.w5),
        tostring(fin.sites.qg and fin.sites.qg.dtot)))
    end
    if st.hot then
      ctx.log(string.format("releve pollue : emission %s/min, absorbee %s/min, part %s, vague %s PV, defense %s PV, raison %s",
        tostring(st.hot.est.emit), tostring(st.hot.est.absorbed), tostring(st.hot.est.reach), tostring(st.hot.sites.qg.w5),
        tostring(st.hot.sites.qg.dtot), tostring(st.hot.sites.qg.why)))
    end
  end,
}
