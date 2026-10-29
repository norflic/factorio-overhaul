--[[
  Lot RESEAU-VIVANT (29/10) : ÉVÉNEMENTS PROVOQUÉS sur la partie du guide (etape1-guide, 216 300 ticks, mesures [FO-FONCTION]
  comprises). À la minute 35 (tick 126 000), le script détruit par die() (donc avec on_entity_died, comme une attaque) :
    - faction 1 (clé triée) : « site SÛR »      toutes ses chaudières et machines à vapeur (critère C2) ;
    - faction 2 (clé triée) : « site DANGEREUX » les mêmes, ET pose un ver GRAND (big-worm-turret : portée 38, 750 PV, les 15 soldats d'une faction ne le tuent pas en 20 min) à 34 tuiles du site (destructible : un ver indestructible n'est pas une cible militaire pour find_nearest_enemy, mesuré le 29/10) (critère C3) ;
    - votre équipe (player) : « PIVOT »         le poteau dont la perte éteint le plus de consommateurs parmi les 30 plus proches de
                                                 la centrale (modèle Z.measure/R.eval, critère C4).
  Relevé toutes les 10 s après l'événement : production lue, chaudières, machines, consommateurs électriques posés et ceux dont le
  réseau du moteur porte une machine à vapeur. « Courant revenu » = production > 0 ET consommateurs sur le réseau d'une centrale
  >= ceux d'avant l'événement (pour le pivot : seulement ces derniers).
  Lignes : « [FO-RESEAU-DETRUIT] ... » ; contrôles en fin de partie (scénario reseau-detruit) ; le TÉMOIN (reseau-detruit-temoin)
  joue les mêmes événements avec le réglage d'essai « sante » coupé (remote fo-ia1d set_option) et ne contrôle rien : il journalise.
]]

local Z = require("scenarios/fonction_reseau")

local MIN = 3600
local KILL = 35 * MIN -- défaut ; opts.kill_min le change (micro-banc d'essai)
local STEP = 600
local WORM_AT = 34          -- tuiles entre le site et le ver
local DANGER = 40           -- tuiles : portée de danger du mod (S.DANGER_R)
local LIMIT = { sur = 10, dangereux = 20, pivot = 5 } -- minutes (critères C2, C3, C4)
local TAG = "[FO-RESEAU-DETRUIT] "
local ELEC = { "mining-drill", "assembling-machine", "lab", "inserter", "furnace" }

local function dist(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

--- Lecture d'une force : production (kW), chaudières, machines, consommateurs électriques et ceux d'un réseau à machine à vapeur.
local function read(s, force)
  local nets, prod, gens = {}, 0, 0
  for _, g in ipairs(s.find_entities_filtered({ force = force, type = "generator" })) do
    gens = gens + 1
    local id = g.electric_network_id
    if id then nets[id] = true end
    prod = prod + (g.energy_generated_last_tick or 0) * 60 / 1000
  end
  local cons, on = 0, 0
  for _, e in ipairs(s.find_entities_filtered({ force = force, type = ELEC })) do
    if e.prototype.electric_energy_source_prototype then
      cons = cons + 1
      local id = e.electric_network_id
      if id and nets[id] then on = on + 1 end
    end
  end
  return { boilers = s.count_entities_filtered({ force = force, type = "boiler" }), gens = gens, prod = prod, cons = cons, on = on,
    poles = s.count_entities_filtered({ force = force, type = "electric-pole" }) }
end

local function center_of(list)
  local x, y = 0, 0
  for _, e in ipairs(list) do x, y = x + e.position.x, y + e.position.y end
  return { x = x / #list, y = y / #list }
end

--- Poteau pivot : parmi les 30 poteaux de la composante d'une centrale les plus proches de la centrale, celui dont le retrait
--- éteint le plus de consommateurs. Rend entité, consommateurs éteints, candidats examinés.
local function pivot_of(s, force, site)
  local cons_ents = {}
  for _, e in ipairs(s.find_entities_filtered({ force = force, type = ELEC })) do
    if e.prototype.electric_energy_source_prototype then cons_ents[#cons_ents + 1] = e end
  end
  local prod_ents = s.find_entities_filtered({ force = force, type = "generator" })
  local poles, cons, prods, ents = Z.read(s, force, cons_ents, prod_ents)
  local R = Z.measure(poles, cons, prods)
  local powered, _, _, comp, _, touch = R.eval({})
  local live = {}
  for i = 1, #poles do
    if touch[comp[i]] then live[#live + 1] = { i = i, d = dist(poles[i].x, poles[i].y, site.x, site.y) } end
  end
  table.sort(live, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.i < b.i end)
  local best, bestcut, seen = nil, -1, 0
  for k = 1, math.min(30, #live) do
    seen = seen + 1
    local pw = R.eval({ [live[k].i] = true })
    local cut = powered - pw
    if cut > bestcut then best, bestcut = live[k].i, cut end
  end
  return best and ents[best] or nil, math.max(bestcut, 0), seen, powered
end

local function sorted_factions()
  local out = {}
  for _, r in ipairs(remote.call("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

return function(opts)
  local temoin = opts and opts.temoin
  local KILL = ((opts and opts.kill_min) or 35) * MIN
  local sc = require("scenarios/etape1-guide")
  local init0, tick0, finish0 = sc.init, sc.tick, sc.finish
  sc.description = sc.description .. (temoin and " + evenements provoques a 35 min, TEMOIN (sante coupee)"
    or " + evenements provoques a 35 min (centrale detruite : site sur, site dangereux ; poteau pivot)")

  if opts and opts.check_tick then sc.check_tick = opts.check_tick end

  sc.init = function(ctx)
    if init0 then init0(ctx) end
    ctx.state().ev = {}
  end

  sc.tick = function(ctx, e)
    if tick0 then tick0(ctx, e) end
    local st = ctx.state()
    local s = ctx.surface()
    -- témoin : l'interrupteur d'essai coupe la santé du réseau (aucun effet sur le reste du code), posé dès que le plan existe
    if temoin and e.tick % 600 == 0 and e.tick >= 2 * MIN and e.tick <= 20 * MIN and not st.cut then
      local all = true
      for _, key in ipairs({ "player", table.unpack((function() local k = {} for _, r in ipairs(sorted_factions()) do k[#k + 1] = r.key end return k end)()) }) do
        local ok = remote.call("fo-ia1d", "set_option", key, "sante", false)
        if ok ~= false then all = false end
      end
      if all then st.cut = true log(TAG .. "temoin : sante du reseau COUPEE a la minute " .. string.format("%.1f", e.tick / MIN)) end
    end
    if e.tick == KILL then
      local fs = sorted_factions()
      local plan = {}
      if fs[1] then plan[#plan + 1] = { key = fs[1].key, force = fs[1].force, role = "sur" } end
      if fs[2] then plan[#plan + 1] = { key = fs[2].key, force = fs[2].force, role = "dangereux" } end
      plan[#plan + 1] = { key = "player", force = "player", role = "pivot" }
      for _, ev in ipairs(plan) do
        ev.pre = read(s, ev.force)
        ev.tick = e.tick
        local boilers = s.find_entities_filtered({ force = ev.force, type = "boiler" })
        local gens = s.find_entities_filtered({ force = ev.force, type = "generator" })
        if #boilers + #gens > 0 then
          local site = center_of(#boilers > 0 and boilers or gens)
          ev.site = site
          if ev.role == "pivot" then
            local pole, cut, seen, powered = pivot_of(s, ev.force, site)
            ev.cut, ev.seen = cut, seen
            if pole and pole.valid then
              ev.pole = { x = pole.position.x, y = pole.position.y }
              pole.die()
            end
            log(TAG .. string.format("%s | %s | PIVOT detruit en (%s) : %d consommateur(s) eteint(s) sur %d alimentes (%d candidats examines)",
              ev.key, ev.role, ev.pole and string.format("%.1f, %.1f", ev.pole.x, ev.pole.y) or "aucun", cut, powered, seen))
          else
            for _, b in ipairs(boilers) do if b.valid then b.die() end end
            for _, g in ipairs(gens) do if g.valid then g.die() end end
            ev.killed = #boilers + #gens
            if ev.role == "dangereux" then
              for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 0.7, 0.7 }, { -0.7, 0.7 }, { 0.7, -0.7 }, { -0.7, -0.7 } }) do
                local want = { x = site.x + d[1] * WORM_AT, y = site.y + d[2] * WORM_AT }
                local p = s.find_non_colliding_position("big-worm-turret", want, 6, 1)
                if p and dist(p.x, p.y, site.x, site.y) >= 30 and dist(p.x, p.y, site.x, site.y) < DANGER - 1 then
                  local w = s.create_entity({ name = "big-worm-turret", position = p, force = "enemy" })
                  if w then
                    ev.worm = { x = p.x, y = p.y }
                    ev.worm_ent = w
                    local fr = game.forces[ev.force]
                    local seen = s.find_nearest_enemy({ position = site, max_distance = DANGER, force = ev.force })
                    log(TAG .. string.format("%s | dangereux | le moteur voit le ver depuis le site : %s ; cessez-le-feu avec enemy=%s ; ami=%s",
                      ev.key, tostring(seen ~= nil), tostring(fr and fr.get_cease_fire("enemy")), tostring(fr and fr.get_friend("enemy"))))
                    break
                  end
                end
              end
            end
            log(TAG .. string.format("%s | %s | centrale detruite a la minute %d : %d piece(s) ; site %.0f,%.0f ; ver %s ; avant : prod %.0f kW, "
              .. "consommateurs %d dont %d sur une centrale", ev.key, ev.role, KILL / MIN, ev.killed, site.x, site.y,
              ev.worm and string.format("pose en %.0f,%.0f a %.1f tuiles", ev.worm.x, ev.worm.y, dist(ev.worm.x, ev.worm.y, site.x, site.y))
              or "NON POSE", ev.pre.prod, ev.pre.cons, ev.pre.on))
          end
        else
          log(TAG .. string.format("%s | %s | rien a detruire (aucune chaudiere ni machine a vapeur)", ev.key, ev.role))
        end
        st.ev[#st.ev + 1] = ev
      end
    end
    if e.tick > KILL and (e.tick - KILL) % STEP == 0 then
      for _, ev in ipairs(st.ev) do
        -- danger PERSISTANT : un ver tué par les soldats de la faction est reposé au même endroit (le test porte sur la décision de
        -- la centrale face à un danger qui tient, pas sur la force de l'armée) ; le nombre de reposes est au journal
        if ev.worm and not (ev.worm_ent and ev.worm_ent.valid) then
          local w2 = s.create_entity({ name = "big-worm-turret", position = ev.worm, force = "enemy" })
          if w2 then
            ev.worm_ent = w2
            ev.respawns = (ev.respawns or 0) + 1
            log(TAG .. string.format("%s | dangereux | ver tue, repose (%d) a la minute %.1f", ev.key, ev.respawns, e.tick / MIN))
          end
        end
        local r = read(s, ev.force)
        ev.last = r
        local back = (ev.role == "pivot") and (r.on >= ev.pre.on) or (r.prod > 0 and r.on >= ev.pre.on)
        if back and not ev.rec_tick then
          ev.rec_tick = e.tick
          ev.rec = r
        end
        if (e.tick - KILL) % (3 * STEP) == 0 or (back and ev.rec_tick == e.tick) then
          log(TAG .. string.format("%s | %s | +%.1f min | chaudieres %d machines %d prod %.0f kW | consommateurs %d sur centrale %d (avant %d) | poteaux %d%s",
            ev.key, ev.role, (e.tick - KILL) / MIN, r.boilers, r.gens, r.prod, r.cons, r.on, ev.pre.on, r.poles,
            (back and ev.rec_tick == e.tick) and " | COURANT REVENU" or ""))
        end
      end
    end
  end

  sc.finish = function(ctx)
    if finish0 then finish0(ctx) end
    local st = ctx.state()
    local s = ctx.surface()
    for _, ev in ipairs(st.ev or {}) do
      local mins = ev.rec_tick and (ev.rec_tick - ev.tick) / MIN or nil
      local lim = LIMIT[ev.role]
      local detail = mins and string.format("%.1f min (limite %d)", mins, lim) or ("jamais (limite " .. lim .. " min)")
      local wdist
      if ev.worm then
        wdist = 1e9
        for _, b in ipairs(s.find_entities_filtered({ force = ev.force, type = { "boiler", "generator" } })) do
          wdist = math.min(wdist, dist(b.position.x, b.position.y, ev.worm.x, ev.worm.y))
        end
      end
      log(TAG .. string.format("bilan %s | %s | retour du courant : %s | distance au ver de la centrale actuelle : %s | derniere lecture : "
        .. "chaudieres %d machines %d prod %.0f kW consommateurs %d sur centrale %d (avant %d)", ev.key, ev.role, detail,
        wdist and (wdist >= 1e9 and "aucune centrale" or string.format("%.1f tuiles", wdist)) or "-",
        ev.last and ev.last.boilers or -1, ev.last and ev.last.gens or -1, ev.last and ev.last.prod or -1, ev.last and ev.last.cons or -1,
        ev.last and ev.last.on or -1, ev.pre.on))
      if not temoin then
        if ev.role == "pivot" then
          ctx.check((ev.cut or 0) >= 3, "C4 : le poteau pivot detruit eteignait au moins 3 consommateurs (test non trivial)", tostring(ev.cut))
        end
        ctx.check(ev.rec_tick ~= nil and mins <= lim, string.format("%s (%s) : courant revenu en %d min au plus",
          ev.role == "sur" and "C2" or (ev.role == "dangereux" and "C3" or "C4"), ev.key, lim), detail)
        if ev.role == "dangereux" then
          ctx.check(ev.worm ~= nil, "C3 : le ver (danger) a ete pose a moins de 40 tuiles du site", ev.worm and "oui" or "non")
          ctx.check(ev.worm_ent ~= nil and ev.worm_ent.valid, "C3 : un ver est en place en fin de partie (danger persistant)",
            string.format("%s, %d repose(s)", (ev.worm_ent ~= nil and ev.worm_ent.valid) and "oui" or "non", ev.respawns or 0))
          ctx.check(wdist ~= nil and wdist > DANGER, "C3 : la centrale de remplacement est a plus de 40 tuiles du ver",
            wdist and string.format("%.1f", wdist) or "-")
        end
      end
    end
    ctx.check(#(st.ev or {}) >= 1, "au moins un evenement provoque", tostring(#(st.ev or {})))
  end

  return sc
end
