--[[
  Lot QG-ZONE (5/11) : « Toute la base qui grandit » (choix du DC) en moteur réel. Une faction (Écarlate, à 320 tuiles,
  Normal) ; la base du joueur est une LIGNE d'assembleurs (un tous les 10 tuiles, trous de 7 tuiles au plus) qui part
  du point d'apparition vers le QG de la faction et s'arrête à 80 tuiles de lui (plus de 200 tuiles du départ) ; un
  avant-poste de 4 assembleurs est posé à 95 tuiles de côté du bout de la ligne : séparé de toute la base par 47 tuiles
  au moins (mesuré sur les bâtiments posés), et PLUS LOIN du QG de la faction que le bout de la ligne. Les bâtiments du
  joueur sont indestructibles (la cible ne change pas parce qu'un bâtiment tombe). Au tick 60, le banc abat un bâtiment
  de la faction au nom du joueur (provocation : guerre déclarée sans attendre la grâce).

  Contrôles au tick 6 600 : la zone du départ (war.pvp.zone, interface « fo-pvp » in_zone) couvre toute la ligne et pas
  l'avant-poste ; la faction a vu au moins 2 secteurs du joueur ; sa cible est l'avant-poste (sans la zone, la règle de
  QG-DERNIER visait le bout de la ligne : à plus de 64 tuiles du départ, et plus proche de la faction).
  Lancement : `py -3.9 -B tools/autotest/banc.py --out <archive> --qui QG-ZONE -- 7000 qg-zone <source>`. Journal : [FO-QG-ZONE].
]]

local NAME = "assembling-machine-1"
local STEP = 10          -- un assembleur tous les 10 tuiles le long de la ligne
local END_FROM_HQ = 80   -- bout de la ligne à 80 tuiles du QG de la faction (champ du QG : 160 tuiles + 32)
local SIDE = 95          -- avant-poste à 95 tuiles de côté du bout de la ligne (en diagonale : 67 tuiles sur chaque axe)
local OUT = { { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } }

local function half(name)
  local cb = game.entity_prototypes[name].collision_box
  return math.floor(cb.right_bottom.x - cb.left_top.x + 0.999) / 2
end

--- Trou (tuiles) entre deux bâtiments posés, sur l'axe le plus écarté (la mesure de la zone : mailles reliées sur chaque axe).
local function gap(a, b, h)
  return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) - 2 * h
end

local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

local function place(s, want)
  local p = s.find_non_colliding_position(NAME, want, 6, 1)
  local e = p and s.create_entity({ name = NAME, position = p, force = "player" })
  if e then e.destructible = false end
  return e
end

return {
  description = "QG-ZONE : base en ligne au-dela de 64 tuiles et avant-poste separe : la faction vise l'avant-poste",
  base = nil,
  check_tick = 6600,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local ok = ctx.remote("fo-pvp", "set_difficulty", "normal")
    ctx.check(ok == true, "difficulte Normal imposee avant la guerre", tostring(ok))
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    local started = ctx.call("war_start", 1, 40, 2, 320)
    ctx.check(started == true, "guerre lancee (1 faction a 320 tuiles)", tostring(started))
    ctx.call("profiler", true)
    local poi = ctx.call("points_of_interest")
    local fac = poi.factions[1]
    ctx.check(fac ~= nil and poi.player == nil, "une faction, pas d'equipe du joueur (points du depart : le point d'apparition seul)",
      fac and fac.key or "aucune")
    if not fac then return end
    local sp = game.forces.player.get_spawn_position(s)
    local H = fac.hq
    local d = dist(H, sp)
    local ux, uy = (H.x - sp.x) / d, (H.y - sp.y) / d
    -- Positions voulues : la ligne, puis l'avant-poste (calé dans un seul secteur de 64 tuiles : 2 installations au moins pour
    -- qu'il soit une cible, sector_min).
    local wants = {}
    for t = STEP, d - END_FROM_HQ, STEP do wants[#wants + 1] = { x = sp.x + ux * t, y = sp.y + uy * t } end
    local E0 = wants[#wants]
    local O = { x = E0.x - uy * SIDE, y = E0.y + ux * SIDE }
    for _, k in ipairs({ "x", "y" }) do
      if math.floor((O[k] - 5) / 64) ~= math.floor((O[k] + 5) / 64) then O[k] = math.floor((O[k] + 5) / 64) * 64 + 6 end
    end
    local all = {}
    for _, w in ipairs(wants) do all[#all + 1] = w end
    for _, o in ipairs(OUT) do all[#all + 1] = { x = O.x + o[1] * 2, y = O.y + o[2] * 2 } end
    for _, w in ipairs(all) do s.request_to_generate_chunks(w, 1) end
    s.force_generate_chunk_requests()
    st.line, st.out, st.hq, st.key, st.force = {}, {}, { x = H.x, y = H.y }, fac.key, "fo-" .. fac.key
    for i, w in ipairs(all) do
      local e = place(s, w)
      local list = i <= #wants and st.line or st.out
      if e then list[#list + 1] = { x = e.position.x, y = e.position.y } end
    end
    -- Prémisses mesurées sur les bâtiments posés.
    local h = half(NAME)
    local worst_line = 0
    for i = 2, #st.line do worst_line = math.max(worst_line, gap(st.line[i - 1], st.line[i], h)) end
    local E = st.line[#st.line]
    ctx.check(#st.line == #wants and #st.line >= 15 and dist(E, sp) > 3 * 64 and worst_line < 32,
      "base en ligne posee : relie au depart sans trou de 32 tuiles", string.format("%d/%d assembleurs, bout a %.0f tuiles du depart, plus grand trou %.1f",
        #st.line, #wants, E and dist(E, sp) or -1, worst_line))
    local sep, closest_out, sectors = math.huge, math.huge, {}
    for _, o in ipairs(st.out) do
      for _, l in ipairs(st.line) do sep = math.min(sep, gap(o, l, h)) end
      closest_out = math.min(closest_out, dist(o, H))
      local k = math.floor(o.x / 64) .. "," .. math.floor(o.y / 64)
      sectors[k] = (sectors[k] or 0) + 1
    end
    local best = 0
    for _, n in pairs(sectors) do best = math.max(best, n) end
    ctx.check(#st.out == #OUT and best >= 2 and sep >= 47,
      "avant-poste pose, separe de toute la base par 47 tuiles ou plus", string.format("%d/%d assembleurs (%d dans un secteur), trou %.1f tuiles",
        #st.out, #OUT, best, sep))
    ctx.check(E ~= nil and dist(E, H) < closest_out,
      "temoin : le bout de la ligne est plus proche de la faction que l'avant-poste", string.format("%.0f contre %.0f tuiles",
        E and dist(E, H) or -1, closest_out))
    ctx.log(string.format("QG (%d, %d) ; depart (%d, %d) ; bout de la ligne (%d, %d) ; avant-poste (%d, %d)", math.floor(H.x), math.floor(H.y),
      math.floor(sp.x), math.floor(sp.y), math.floor(E.x), math.floor(E.y), math.floor(O.x), math.floor(O.y)))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.force then return end
    if e.tick == 60 then
      -- Provocation : un bâtiment (ou un soldat) de la faction abattu au nom du joueur sous cessez-le-feu.
      local s = ctx.surface()
      local victim
      for _, ent in ipairs(s.find_entities_filtered({ force = st.force })) do
        if ent.valid and ent.health and ent.type ~= "container" and dist(ent.position, st.hq) > 6 then
          if ent.type == "unit" or not victim then victim = ent end
          if ent.type == "unit" then break end
        end
      end
      st.victim = victim and victim.name or "aucune"
      if victim then victim.die(game.forces.player) end
    elseif e.tick == 120 then
      local f = ctx.remote("fo-pvp", "status").factions[1]
      st.declared = f and f.declared and f.provoked
    elseif e.tick % 300 == 0 then
      local f = ctx.remote("fo-pvp", "status").factions[1]
      local t = f and f.target
      local where = "-"
      if t then
        where = "ligne"
        for _, o in ipairs(st.out) do if dist(o, t) < 8 then where = "avant-poste" end end
      end
      if where ~= st.last_where then
        st.last_where = where
        ctx.log(string.format("tick %d : cible %s (%s), secteurs vus %d", e.tick, where, t and string.format("%d, %d", math.floor(t.x), math.floor(t.y)) or "-",
          f and f.known or 0))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.declared == true, "provocation : guerre declaree au tick 120", "abattu : " .. tostring(st.victim))
    local status = ctx.remote("fo-pvp", "status")
    local z = status.zone
    local in_line, in_out = 0, 0
    for _, l in ipairs(st.line or {}) do if ctx.remote("fo-pvp", "in_zone", l.x, l.y) then in_line = in_line + 1 end end
    for _, o in ipairs(st.out or {}) do if ctx.remote("fo-pvp", "in_zone", o.x, o.y) then in_out = in_out + 1 end end
    ctx.check(z ~= nil and not z.capped and in_line == #(st.line or {}) and in_out == 0,
      "zone du depart : toute la ligne dedans, l'avant-poste dehors", string.format("%d/%d de la ligne, %d/%d de l'avant-poste ; %s maille(s), %s comptage(s) au calcul du tick %s",
        in_line, #(st.line or {}), in_out, #(st.out or {}), tostring(z and z.n), tostring(z and z.tests), tostring(z and z.at)))
    local f = status.factions[1]
    local t = f and f.target
    local on_out = false
    for _, o in ipairs(st.out or {}) do if t and dist(o, t) < 8 then on_out = true end end
    ctx.check(f ~= nil and (f.known or 0) >= 2, "garde : la faction a vu au moins 2 secteurs du joueur", tostring(f and f.known))
    ctx.check(on_out, "cible de la faction : l'avant-poste, pas le bout de la base (« Toute la base qui grandit »)",
      t and string.format("(%d, %d)", math.floor(t.x), math.floor(t.y)) or "aucune")
    ctx.log(string.format("attaques contre le joueur : %d (%d soldats), derniere cible %s", f and f.attacks or 0, f and f.soldiers or 0,
      f and f.last_target and string.format("(%d, %d)", math.floor(f.last_target.x), math.floor(f.last_target.y)) or "-"))
    ctx.call("log_report", "qg-zone")
  end,
}
