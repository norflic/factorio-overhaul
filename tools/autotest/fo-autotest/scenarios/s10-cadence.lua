--[[
  Lot X10-S10 « factions lointaines plus lentes » (décision du DC du 7/11, 17 h 47), en moteur réel. Critères écrits avant le banc :
  fo-logs/2026-11-07_X10/S10_CRITERES.md. Lecture de l'état par l'interface « fo-cadence » (script/faction/commander.lua).
    A : 2 factions à 600 tuiles du départ, joueur loin : pensées espacées de 600 ticks. Condition « calme » posée par le banc : jusqu'au
        tick 1 450, les ennemis à moins de 250 tuiles d'un QG sont retirés toutes les 60 ticks (sinon la règle réveille la faction à bon
        droit : ennemi près du QG, alerte de la prévision) ;
    B : dégât forcé sur une TOURELLE posée pour la faction 1 ENDORMIE (cause : un petit biter ennemi posé loin, puis retiré) : sa
        pensée suivante tombe au tick du dégât ou au suivant (le mod de test passe après le mod dans un tick : le guet voit la cause au
        tick suivant et pense aussitôt). Une tourelle n'a pas de classe de réparation : c'est f.hit_t qui réveille (revue de 87ac84fe,
        point 2). Puis le rythme normal : pensée suivante au plus 300 ticks plus tard, sauf le cas borné du point 3 (créneau dans les
        étapes de la pensée du réveil : laissé, pensée suivante au plus 300 + SPAN ticks plus tard) ;
    C : session avec images seulement (joueur connecté) : le joueur téléporté près du QG de la faction 2 ENDORMIE : pensée au tick de la
        téléportation ou au suivant, puis écart d'au plus 300 (même cas borné). Sans joueur (banc sans images) : partie non jouée, dite
        au journal.
  Lancement : banc.py --captures --visuel="--ticks 2600" --qui X10-S10 -- 2500 s10-cadence <source>.
]]

local CALM_R, CALM_UNTIL = 250, 1450
local P, SPAN = 300, 7 -- période des pensées des factions ; écart de la première à la dernière des 8 étapes d'une pensée (Et.SPAN de
                        -- shared/team/etapes.lua, 0.6.62)

local function gaps(ticks, upto)
  local out = {}
  for i = 2, #ticks do
    if ticks[i] < upto then out[#out + 1] = ticks[i] - ticks[i - 1] end
  end
  return out
end

local function first_after(ticks, t0)
  for _, t in ipairs(ticks) do if t >= t0 then return t end end
  return nil
end

return {
  description = "X10-S10 : factions lointaines et calmes plus lentes, reveil au tick meme",
  -- La session avec images se ferme dès ses captures prises : elles viennent APRÈS le bilan (premier passage : captures à 2 300,
  -- bilan à 2 450 jamais joué).
  check_tick = 2300,
  shots_delay = 2350,

  -- Session avec images : une capture du QG de chaque faction (le joueur est près de la faction 2 depuis la partie C).
  shots = function(ctx, add)
    local poi = ctx.call("points_of_interest")
    for _, f in ipairs(poi.factions or {}) do add("s10-qg-" .. tostring(f.key), f.hq.x, f.hq.y, 0.5, 0) end
  end,

  init = function(ctx)
    local st = ctx.state()
    st.started = ctx.call("war_start", 2, 10, 4, 600)
    ctx.check(st.started == true, "guerre lancee (2 factions a 600 tuiles du depart)", tostring(st.started))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not ctx.has("fo-cadence", "list") then
      if not st.no_iface then st.no_iface = true ctx.fail("interface fo-cadence", "absente") end
      return
    end
    local list = ctx.remote("fo-cadence", "list")
    st.n = #list
    st.th = st.th or {}
    for i, r in ipairs(list) do
      local th = st.th[i]
      -- Première lecture : la valeur relevée est le tick de CRÉATION de la faction (f.last_think = game.tick, war.lua), pas une pensée
      -- (deuxième passage : « 0 7 607 » comptait 0 → 7 comme un écart) : elle n'entre pas dans la liste.
      if not th then th = { key = r.key, ticks = {}, prev = r.last } st.th[i] = th end
      if r.last and r.last ~= th.prev then th.ticks[#th.ticks + 1] = r.last th.prev = r.last end
    end
    -- A : condition « calme » (voir l'en-tête).
    if e.tick <= CALM_UNTIL and e.tick % 60 == 0 then
      local s = ctx.surface()
      local n = 0
      for _, r in ipairs(list) do
        if r.hq then
          for _, en in ipairs(s.find_entities_filtered({ position = r.hq, radius = CALM_R, force = "enemy" })) do
            if en.valid then en.destroy() n = n + 1 end
          end
        end
      end
      st.cleared = (st.cleared or 0) + n
    end
    -- B : dégât forcé sur la faction 1 endormie.
    local f1 = list[1]
    if not st.dmg and e.tick >= 1500 and f1 and f1.asleep and f1.hq then
      local s = ctx.surface()
      -- (premier passage : un petit biter posé à 220 tuiles n'a pas trouvé de place, chunks non générés ; il est posé près de la
      -- tourelle, le temps du coup, et le coup part sans cause s'il manque : f.hit_t n'a pas besoin de cause)
      local pos = s.find_non_colliding_position("gun-turret", { f1.hq.x + 12, f1.hq.y }, 30, 1)
      local tur = pos and s.create_entity({ name = "gun-turret", position = pos, force = f1.force })
      local bpos = tur and s.find_non_colliding_position("small-biter", { tur.position.x + 8, tur.position.y + 8 }, 20, 1)
      local biter = bpos and s.create_entity({ name = "small-biter", position = bpos, force = "enemy" })
      if tur then
        if biter then tur.damage(5, "enemy", "physical", biter) else tur.damage(5, "enemy", "physical") end
        if biter and biter.valid then biter.destroy() end
        st.dmg, st.dmg_key = e.tick, f1.key
        ctx.log(string.format("tick %d : degat force sur une tourelle de %s en (%.1f, %.1f), cause %s (faction endormie, derniere pensee %s)",
          e.tick, tostring(f1.key), tur.position.x, tur.position.y, biter and "petit biter" or "aucune", tostring(f1.last)))
      else
        st.dmg = -1
        ctx.fail("degat force", string.format("tourelle impossible a poser (place %s)", pos and "trouvee" or "introuvable"))
      end
    end
    -- C : le joueur (session avec images) téléporté près de la faction 2 endormie.
    local p = game.connected_players[1]
    if p then st.has_player = true end
    local f2 = list[2]
    if p and not st.tp and e.tick >= 1650 and f2 and f2.asleep and f2.hq then
      p.teleport({ f2.hq.x + 15, f2.hq.y })
      st.tp, st.tp_key = e.tick, f2.key
      ctx.log(string.format("tick %d : joueur teleporte a 15 tuiles du QG de %s (faction endormie, derniere pensee %s)", e.tick, tostring(f2.key), tostring(f2.last)))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check((st.n or 0) == 2, "2 factions lues par fo-cadence.list", tostring(st.n))
    for i = 1, 2 do
      local th = st.th and st.th[i]
      local g = th and gaps(th.ticks, 1450) or {}
      local ok = #g >= 1
      for _, d in ipairs(g) do if d ~= 600 then ok = false end end
      ctx.check(ok, string.format("A2 faction %d (%s) loin et calme : pensees espacees de 600", i, tostring(th and th.key)),
        th and table.concat(th.ticks, " ") or "aucune pensee")
    end
    ctx.log(string.format("condition calme : %d ennemi(s) retire(s) a moins de %d tuiles des QG jusqu'au tick %d", st.cleared or 0, CALM_R, CALM_UNTIL))
    local function next_of(ticks, w)
      for _, t in ipairs(ticks or {}) do if t > w then return t end end
      return nil
    end
    local t1 = st.th and st.th[1]
    local w = (st.dmg or 0) > 0 and t1 and first_after(t1.ticks, st.dmg) or nil
    ctx.check(w ~= nil and (w == st.dmg or w == st.dmg + 1), "B1 degat sur une tourelle de la faction endormie : pensee au tick du degat ou au suivant",
      string.format("degat %s, pensee %s", tostring(st.dmg), tostring(w)))
    --- Écart permis après un réveil au tick `w` (créneaux de la faction : premier créneau `s0` + k P) : 300, ou 300 + SPAN si le créneau
    --- suivant tombe dans les étapes de la pensée du réveil (le seul cas borné).
    local function allowed(s0, w)
      local to_slot = (s0 - w) % P
      if to_slot == 0 then to_slot = P end -- réveil AU tick du créneau (troisième passage : 1 507, sauté puis réveillé) : le suivant est à P
      if to_slot <= SPAN then return P + SPAN, "cas borne (creneau dans les etapes)" end
      return P, "rythme normal"
    end
    local n1 = w and next_of(t1.ticks, w)
    local lim1, why1 = P, "?"
    if w then lim1, why1 = allowed(t1.ticks[1], w) end
    ctx.check(n1 ~= nil and n1 - w > SPAN and n1 - w <= lim1, "B3 puis rythme normal : pensee suivante au plus 300 ticks apres le reveil (sauf cas borne : 300 + SPAN)",
      string.format("%s puis %s (ecart %s, limite %d : %s)", tostring(w), tostring(n1), tostring(n1 and w and n1 - w), lim1, why1))
    if st.has_player then
      local t2 = st.th and st.th[2]
      local w2 = st.tp and t2 and first_after(t2.ticks, st.tp) or nil
      ctx.check(w2 ~= nil and (w2 == st.tp or w2 == st.tp + 1), "C1 joueur teleporte pres de la faction endormie : pensee au tick meme ou au suivant",
        string.format("teleportation %s, pensee %s", tostring(st.tp), tostring(w2)))
      local nxt = w2 and next_of(t2.ticks, w2)
      local lim2, why2 = P, "?"
      if w2 then lim2, why2 = allowed(t2.ticks[1], w2) end
      ctx.check(nxt ~= nil and nxt - w2 > SPAN and nxt - w2 <= lim2, "C2 le joueur reste : rythme normal (ecart <= 300, sauf cas borne : 300 + SPAN)",
        string.format("%s puis %s (ecart %s, limite %d : %s)", tostring(w2), tostring(nxt), tostring(nxt and nxt - w2), lim2, why2))
    else
      ctx.log("aucun joueur connecte (banc sans images) : la partie C (teleportation) se joue dans la session avec images")
    end
  end,
}
