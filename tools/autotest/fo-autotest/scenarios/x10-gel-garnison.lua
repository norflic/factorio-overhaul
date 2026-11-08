--[[
  Lot X10-GEL, garnisons (Q7) : micro-banc en moteur réel (fo-logs/2026-11-07_X10/L1_CRITERES.md §4, C12 à C17).
    py -3.9 -B tools/autotest/banc.py --qui X10-GEL --out <archive> -- 2500 x10-gel-garnison <source>

  Sept garnisons de banc (interface « fo-gel », script/faction/gel_banc.lua), une force chacune, à 300 tuiles l'une de l'autre ;
  soldats « fo-scarlet-rifleman » (prototype des factions), errance autour de leur point comme la garnison des factions. Aucun joueur
  (liste vide : « loin ») sauf G5. T3 et T4 : jumelles TÉMOINS, jamais adoptées.
    tick 10   : garnisons posées ; G1 a un blessé et un soldat loin de son poste ; G1 et G4 ont 2 gardes ; G3 et T3, 2 tourelles ;
    ~640      : soldats aptes figés (600 ticks de calme + guet) ; 690 : tous figés, sauf blessé et égaré (C16) ;
    700       : G1, coup sur un mur (C13 a) ; G2, coup sur un soldat FIGÉ (C13 c) ; G3 et T3, même vague de 5 biters à 120 tuiles (C12,
                C14) ; G4, commande par le crochet (C15) et soldat mis dans un groupe ; T4, même ordre au jumeau ; G5, joueur à 220 tuiles
                du poste (C16) ; G6, alerte d'armée (C16) ;
    chaque tick : C12 (aucun figé de G3 quand un ennemi est à 48 tuiles du QG ou qu'une tourelle tire) ;
    2 450     : bilan : pertes de G3 contre T3 (C14), arrivées de G4 contre T4 (C15), appels de on_entity_damaged par minute (C17).
  Faits relevés : un soldat figé reçoit le coup et l'événement ; entity.damage() lève l'événement pendant l'appel ; position et
  commande d'un soldat figé.
]]

local Y0 = -3000
local KEYS = { "G1", "G2", "G3", "T3", "G4", "T4", "G5", "G6" }
local X = { G1 = 5000, G2 = 5300, G3 = 5600, T3 = 5900, G4 = 6200, T4 = 6500, G5 = 6800, G6 = 7100 }
local BANC = { G1 = true, G2 = true, G3 = true, G4 = true, G5 = true, G6 = true }
local SOLDIER = "fo-scarlet-rifleman"
local HOME = 8

local function force_of(k) return "fo-gel-" .. k:lower() end

local function wander(u, r)
  u.set_command({ type = defines.command.wander, radius = r, distraction = defines.distraction.by_enemy })
end

local function build(ctx, s, k)
  local hq = { x = X[k], y = Y0 }
  local force = force_of(k)
  local g = { hq = hq, home = {}, guards = {}, turrets = {}, all = {} }
  for i = 1, HOME do
    local u = s.create_entity({ name = SOLDIER, position = { hq.x - 5 + (i % 4) * 3, hq.y + 12 + math.floor(i / 4) * 2 }, force = force })
    wander(u, 8)
    g.home[i], g.all[#g.all + 1] = u, u
  end
  if k == "G1" or k == "G4" or k == "T4" then
    for i = 1, 2 do
      local u = s.create_entity({ name = SOLDIER, position = { hq.x + 40 + i, hq.y }, force = force })
      wander(u, 3)
      g.guards[i], g.all[#g.all + 1] = u, u
    end
  end
  if k == "G1" then
    g.wounded = s.create_entity({ name = SOLDIER, position = { hq.x + 2, hq.y + 16 }, force = force })
    g.wounded.health = g.wounded.health - 30 -- écriture de script : aucun événement de dégât
    wander(g.wounded, 8)
    g.away = s.create_entity({ name = SOLDIER, position = { hq.x, hq.y + 80 }, force = force })
    g.all[#g.all + 1], g.all[#g.all + 1] = g.wounded, g.away
  end
  if k == "G3" or k == "T3" then
    for i = 1, 2 do
      local t = s.create_entity({ name = "gun-turret", position = { hq.x + 10, hq.y - 6 + 12 * (i - 1) }, force = force })
      t.insert({ name = "firearm-magazine", count = 20 })
      g.turrets[i] = t
    end
  end
  g.wall = s.create_entity({ name = "stone-wall", position = { hq.x, hq.y - 20 }, force = force })
  if BANC[k] then
    ctx.remote("fo-gel", "garnison", k, force, hq, 1)
    ctx.remote("fo-gel", "g_joueurs", k, {})
    for _, u in ipairs(g.home) do ctx.remote("fo-gel", "soldat", k, u) end
    for _, u in ipairs(g.guards) do ctx.remote("fo-gel", "soldat", k, u, "guard", hq.x + 40, hq.y) end
    if g.wounded then ctx.remote("fo-gel", "soldat", k, g.wounded); ctx.remote("fo-gel", "soldat", k, g.away) end
    for _, t in ipairs(g.turrets) do ctx.remote("fo-gel", "tourelle", k, t) end
  end
  return g
end

local function inactive(list)
  local n = 0
  for _, e in ipairs(list) do if e.valid and not e.active then n = n + 1 end end
  return n
end
local function alive(list)
  local n = 0
  for _, e in ipairs(list) do if e.valid then n = n + 1 end end
  return n
end

local function wave(s, hq)
  local p = { x = hq.x + 120, y = hq.y + 14 }
  local grp = s.create_unit_group({ position = p, force = "enemy" })
  for i = 1, 5 do
    local b = s.create_entity({ name = "medium-biter", position = { p.x + (i % 3), p.y + math.floor(i / 3) * 2 }, force = "enemy" })
    grp.add_member(b)
  end
  grp.set_command({ type = defines.command.attack_area, destination = { x = hq.x, y = hq.y + 14 }, radius = 30,
    distraction = defines.distraction.by_enemy })
  return grp
end

local function enemy_near(s, pos, r)
  return s.count_entities_filtered({ position = pos, radius = r, force = "enemy", type = "unit" }) > 0
end

local function firing(list)
  for _, t in ipairs(list) do if t.valid and t.shooting_target ~= nil then return true end end
  return false
end

local function first_contact(s, list, r)
  for _, u in ipairs(list) do
    if u.valid and s.count_entities_filtered({ position = u.position, radius = r, force = "enemy", type = "unit", limit = 1 }) > 0 then return true end
  end
  return false
end

return {
  description = "X10-GEL garnisons (Q7) : soldats au repos figes hors de vue, reveils au coup, a la menace, a l'ordre",
  check_tick = 2450,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    local t = e.tick
    if t == 10 then
      for _, k in ipairs(KEYS) do
        local wide = (k == "G3" or k == "T3") and 130 or 70 -- la vague part à 120 tuiles à l'est
        ctx.prepare_area(X[k] - 60, Y0 - 40, X[k] + wide, Y0 + 80, "grass-1")
        if not game.forces[force_of(k)] then game.create_force(force_of(k)) end
      end
      for _, a in ipairs(KEYS) do
        for _, b in ipairs(KEYS) do
          if a ~= b then game.forces[force_of(a)].set_friend(force_of(b), true) end
        end
      end
      for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { 4700, Y0 - 400 }, { 7500, Y0 + 400 } } })) do en.destroy() end
      ctx.remote("fo-gel", "g_compte", true)
      st.g = {}
      for _, k in ipairs(KEYS) do st.g[k] = build(ctx, s, k) end
      st.c12_bad, st.c12_ticks = 0, 0
      local c = ctx.remote("fo-gel", "constantes")
      ctx.log(string.format("constantes : CALM %d, GUET %d, WAKE_R %d, FREEZE_R %d", c.CALM, c.GUET, c.WAKE_R, c.FREEZE_R))
    elseif t == 690 then
      local G = st.g
      for _, k in ipairs({ "G2", "G3", "G5", "G6" }) do
        ctx.check(inactive(G[k].all) == alive(G[k].all) and alive(G[k].all) > 0, "C16 : " .. k .. " : tous les soldats figes au tick 690",
          inactive(G[k].all) .. " / " .. alive(G[k].all))
      end
      ctx.check(inactive(G.G1.home) == HOME and inactive(G.G1.guards) == 2, "C16 : G1 : 8 soldats du QG et 2 gardes figes",
        inactive(G.G1.home) .. " et " .. inactive(G.G1.guards))
      ctx.check(G.G1.wounded.active and G.G1.away.active, "C16 : G1 : le blesse et le soldat loin de son poste ne sont jamais figes")
      ctx.check(inactive(G.G4.all) == alive(G.G4.all), "C16 : G4 : tous figes", inactive(G.G4.all) .. " / " .. alive(G.G4.all))
      ctx.check(inactive(G.T3.all) == 0 and inactive(G.T4.all) == 0, "C4 : les jumelles T3 et T4 ne sont jamais figees")
      local u = G.G2.home[1]
      st.pos690, st.cmd690 = { x = u.position.x, y = u.position.y }, u.command and u.command.type
      ctx.log(string.format("fait : soldat fige : active=%s, commande %s, sante %.1f", tostring(u.active), tostring(st.cmd690), u.health))
    elseif t == 700 then
      local G = st.g
      -- C13 a : coup sur un mur de G1, relevé juste après l'appel (même tick)
      G.G1.wall.damage(10, "enemy", "physical")
      local n1 = inactive(G.G1.all)
      ctx.check(n1 == 0, "C13 a : coup sur un mur : toute la garnison G1 reveillee dans le meme tick", n1 .. " fige(s) apres l'appel")
      -- C13 c : coup sur un soldat FIGÉ de G2
      local u = G.G2.home[1]
      ctx.log(string.format("fait : soldat fige avant le coup : active=%s, deplacement depuis 690 : %.2f tuile(s)", tostring(u.active),
        math.abs(u.position.x - st.pos690.x) + math.abs(u.position.y - st.pos690.y)))
      local h0 = u.health
      u.damage(5, "enemy", "physical")
      local n2 = inactive(G.G2.all)
      ctx.check(u.health < h0, "fait : un soldat fige recoit le coup", string.format("%.1f -> %.1f", h0, u.health))
      ctx.check(n2 == 0, "C13 c : coup sur un soldat FIGE : toute la garnison G2 reveillee dans le meme tick", n2 .. " fige(s) apres l'appel")
      ctx.log(string.format("fait : soldat reveille : commande %s (avant le gel %s)", tostring(u.command and u.command.type), tostring(st.cmd690)))
      -- C12 et C14 : même vague sur G3 et T3
      wave(s, G.G3.hq)
      wave(s, G.T3.hq)
      -- C15 : commande par le crochet ; groupe ; jumeau T4
      local g4 = G.G4.guards[1]
      local act = ctx.remote("fo-gel", "g_commande", "G4", g4)
      ctx.check(act == true and inactive(G.G4.home) == HOME, "C15 : commande par le crochet : le soldat reveille dans le meme tick, les autres restent figes",
        tostring(act) .. ", " .. inactive(G.G4.home) .. " figes au QG")
      local dest4, destT = { x = G.G4.hq.x, y = G.G4.hq.y + 60 }, { x = G.T4.hq.x, y = G.T4.hq.y + 60 }
      g4.set_command({ type = defines.command.go_to_location, destination = dest4, radius = 2, distraction = defines.distraction.by_enemy })
      G.T4.guards[1].set_command({ type = defines.command.go_to_location, destination = destT, radius = 2, distraction = defines.distraction.by_enemy })
      st.dest4, st.destT = dest4, destT
      local gm = G.G4.home[2]
      st.grp = ctx.remote("fo-gel", "g_groupe", "G4", gm, G.G4.hq.x - 50, G.G4.hq.y)
      ctx.check(st.grp ~= nil and gm.active, "C15 : soldat fige mis dans un groupe par le chemin du mod : reveille avant", tostring(st.grp))
      local gt = G.T4.home[2]
      local tg = s.create_unit_group({ position = gt.position, force = gt.force })
      tg.add_member(gt)
      tg.set_command({ type = defines.command.go_to_location, destination = { x = G.T4.hq.x - 50, y = G.T4.hq.y }, radius = 2,
        distraction = defines.distraction.by_enemy })
      -- C16 : joueur à 220 tuiles du poste de G5 ; alerte d'armée de G6
      ctx.remote("fo-gel", "g_joueurs", "G5", { { x = G.G5.hq.x + 220, y = G.G5.hq.y + 14 } })
      ctx.remote("fo-gel", "g_cause", "G6", "armee", { alert = true })
      st.wave_t = t
    elseif t == 720 then
      local G = st.g
      ctx.check(inactive(G.G5.all) == 0, "C16 : joueur a 220 tuiles du poste : G5 reveillee en 20 ticks au plus", inactive(G.G5.all) .. " fige(s)")
      ctx.check(inactive(G.G6.all) == 0, "C16 : alerte d'armee : G6 reveillee en 20 ticks au plus", inactive(G.G6.all) .. " fige(s)")
    elseif t == 760 then
      local gm = st.g.G4.home[2]
      ctx.check(gm.valid and gm.unit_group ~= nil and gm.active, "C15 : 60 ticks plus tard, toujours membre du groupe et actif",
        tostring(gm.valid and gm.unit_group ~= nil))
    end
    if st.g and t > 640 then
      local G = st.g
      -- C12 : à chaque tick
      local danger = enemy_near(s, G.G3.hq, 48) or firing(G.G3.turrets)
      if danger then
        st.c12_ticks = st.c12_ticks + 1
        if inactive(G.G3.all) > 0 then st.c12_bad = st.c12_bad + 1 end
      end
      if st.wave_t then
        if not st.wake3 and inactive(G.G3.all) == 0 then st.wake3 = t end
        if not st.contact3 and first_contact(s, G.G3.all, 30) then st.contact3 = t end
        if not st.contactT and first_contact(s, G.T3.all, 30) then st.contactT = t end
        local function arrived(u, d) return u.valid and math.abs(u.position.x - d.x) + math.abs(u.position.y - d.y) <= 4 end
        if not st.arr4 and arrived(G.G4.guards[1], st.dest4) then st.arr4 = t end
        if not st.arrT and arrived(G.T4.guards[1], st.destT) then st.arrT = t end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local G = st.g
    ctx.check(st.c12_ticks > 0 and st.c12_bad == 0, "C12 : aucun soldat de G3 fige quand un ennemi est a 48 tuiles du QG ou qu'une tourelle tire",
      st.c12_bad .. " tick(s) en faute sur " .. st.c12_ticks .. " tick(s) de danger")
    ctx.check(st.wake3 ~= nil and st.contact3 ~= nil and st.contact3 - st.wake3 >= 20,
      "C14 : G3 reveillee au moins un guet (20 ticks) avant le premier biter a 30 tuiles d'un soldat",
      string.format("reveil %s, contact %s (T3 : %s)", tostring(st.wake3), tostring(st.contact3), tostring(st.contactT)))
    local l3, lt = HOME - alive(G.G3.home), HOME - alive(G.T3.home)
    ctx.check(math.abs(l3 - lt) <= 1, "C14 : pertes de G3 a +-1 de la jumelle T3", l3 .. " / " .. lt)
    ctx.check(st.arr4 ~= nil and st.arrT ~= nil and math.abs((st.arr4 - st.wave_t) - (st.arrT - st.wave_t)) <= 0.1 * (st.arrT - st.wave_t) + 2,
      "C15 : soldat reveille par son ordre arrive a +-10 % du jumeau jamais fige",
      string.format("%s / %s ticks", tostring(st.arr4 and st.arr4 - st.wave_t), tostring(st.arrT and st.arrT - st.wave_t)))
    local ga = ctx.remote("fo-gel", "g_etat", "G3")
    local span = 2450 - 700
    ctx.log(string.format("C17 : on_entity_damaged : %d appel(s), dont %d sur des soldats, en %d ticks de bataille, soit %.0f par minute (%.0f sur des soldats) ; requetes de surface : %d",
      ga.degats, ga.degats_soldats, span, ga.degats * 3600 / span, ga.degats_soldats * 3600 / span, ga.requetes))
    ctx.log(string.format("garnison G3 : soldats %d, figes %d, gels %d, reveils %d, causes [%s]", ga.soldats, ga.figes, ga.gels, ga.reveils, ga.causes))
    local all = {}
    for _, k in ipairs(KEYS) do for _, u in ipairs(G[k].all) do all[#all + 1] = u end end
    ctx.log(string.format("fin : %d soldat(s) encore fige(s) (G1, G2, G5, G6 refiges apres le calme : attendu)", inactive(all)))
  end,
}
