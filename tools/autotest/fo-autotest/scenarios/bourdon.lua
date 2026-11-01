-- Lot BOURDON (1er/11), 3 000 ticks, sans images : le Bourdon descend, pose ses ancres, sonne Le Glas (dégâts réels, jamais sur sa force, ses alliés, une trêve) ; il lève ses ancres,
-- franchit un lac de 40 tuiles, se repose ; Glas automatique sur une tourelle ennemie à portée ; il repart. Le banc crée puis rejoue la carte : preuve de relecture.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui BOURDON -- 3000 bourdon <source>
local C = require("scenarios/bourdon_commun")

local X, Y = 4000, 3000
local LAC_X = X + 90
local Fin_X = LAC_X + 110

local function etat(st) return remote.call("fo-bourdon", "etat", st.id) end

return {
  description = "BOURDON : Glas, degats par anneau, forces epargnees, vol, relecture",
  check_tick = 2960,

  init = function(ctx)
    local st = ctx.state()
    C.forces()
    st.cibles = C.site(ctx, X, Y, 70)
    local s = ctx.surface()
    -- témoins hors d'atteinte, et témoins épargnés à 20 tuiles du centre
    ctx.prepare_area(X + 70, Y - 70, Fin_X + 40, Y + 70, "dry-dirt")
    st.loin = s.create_entity({ name = "assembling-machine-2", position = { X + 63.5, Y + 40.5 }, force = C.CIBLE })
    for _, n in ipairs({ "player", C.ALLIE, C.TREVE }) do
      st[n] = {}
    end
    local function temoin(force, dx, dy)
      local trouve = s.find_entities_filtered({ area = { { X + dx - 3, Y + dy - 3 }, { X + dx + 3, Y + dy + 3 } } })
      for _, t in ipairs(trouve) do t.destroy() end
      local e = s.create_entity({ name = "lab", position = { X + dx + 0.5, Y + dy + 0.5 }, force = force })
      local l = st[force]
      l[#l + 1] = e
    end
    temoin("player", -20, -8)
    temoin("player", 12, 16)
    temoin(C.ALLIE, 20, -8)
    temoin(C.TREVE, -12, 16)
    -- lac de 40 tuiles sur la route du vol
    local tuiles = {}
    for x = LAC_X, LAC_X + 39 do
      for y = Y - 60, Y + 60 do tuiles[#tuiles + 1] = { name = "water", position = { x, y } } end
    end
    s.set_tiles(tuiles)
    st.id = remote.call("fo-bourdon", "descendre", "player", X, Y)
    ctx.check(st.id ~= nil, "descendre", tostring(st.id))
    st.prevu = {}
    for _, e in ipairs(st.cibles) do
      if e.valid then
        local dx, dy = e.position.x - X, e.position.y - Y
        st.prevu[#st.prevu + 1] = { e = e, r = math.sqrt(dx * dx + dy * dy) }
      end
    end
    ctx.log(string.format("base de la cible : %d entites", #st.cibles))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if not st.id then return end
    local b = etat(st)
    if t == 300 and b then ctx.check(b.phase == "chute" or b.phase == "descente", "t300 : descente puis chute", b.phase) end
    if not st.pose1 and b and b.phase == "pose" then
      st.pose1 = t
      ctx.check(b.ancres == 6, "6 ancres posees a l'arrivee", tostring(b.ancres) .. " au tick " .. t)
      remote.call("fo-bourdon", "muet", st.id, true)
    end
    if t == 460 then
      st.av = {}
      local q = remote.call("fo-bourdon", "glas", st.id, X + 40, Y)
      ctx.check(q == true, "Glas ordonne (a portee)", tostring(q))
      st.q = remote.call("fo-bourdon", "glas", st.id, X + 40, Y)
    end
    if t == 462 then ctx.check(not st.q, "un seul Glas a la fois (recharge)", tostring(st.q)) end
    -- le coup part au tick 530 : le front ne doit avoir touche aucun témoin lointain avant d'y etre
    if t == 545 and st.loin.valid then
      local v = 0
      for _, p in ipairs(st.prevu) do
        if p.r > 40 and not p.e.valid then v = v + 1 end
      end
      ctx.check(v == 0, "t+15 (R=13) : rien de detruit a plus de 40 tuiles", tostring(v))
    end
    if t == 700 then
      local mort_in, reste_in, mort_out, reste_out = 0, 0, 0, 0
      for _, p in ipairs(st.prevu) do
        if p.r <= 58 then
          if p.e.valid then reste_in = reste_in + 1 else mort_in = mort_in + 1 end
        elseif p.r >= 64 then
          if p.e.valid then reste_out = reste_out + 1 else mort_out = mort_out + 1 end
        end
      end
      ctx.check(mort_in > 60 and reste_in == 0, "la base dans la portee est detruite", mort_in .. " detruits, " .. reste_in .. " restent")
      ctx.check(mort_out == 0 and reste_out > 0, "rien au-dela de la portee", mort_out .. " detruits, " .. reste_out .. " intacts")
      for _, n in ipairs({ "player", C.ALLIE, C.TREVE }) do
        local ok = true
        for _, x in ipairs(st[n]) do
          if not x.valid or x.health < x.prototype.max_health then ok = false end
        end
        ctx.check(ok, "force epargnee : " .. n, #st[n] .. " laboratoire(s)")
      end
      ctx.check(b.touches > 0 and b.tues > 0, "bilan du Glas", b.touches .. " touches, " .. b.tues .. " tues")
      ctx.check(b.sante and b.sante > 59000, "le Bourdon intact", tostring(b.sante))
      -- le vol : par-dessus le lac
      remote.call("fo-bourdon", "aller", st.id, Fin_X, Y)
      st.parti = t
    end
    if st.parti and not st.vu_vol and b and b.phase == "vol" then
      st.vu_vol = t
      ctx.check(t - st.parti < 100, "ancres levees avant de partir", (t - st.parti) .. " ticks")
    end
    if st.vu_vol and not st.pose2 and b and b.phase == "pose" then
      st.pose2 = t
      ctx.check(math.abs(b.x - Fin_X) < 7 and math.abs(b.y - Y) < 7, "arrive de l'autre cote du lac", string.format("(%.1f, %.1f) au tick %d", b.x, b.y, t))
      local v = (Fin_X - X) / (t - st.vu_vol)
      ctx.log(string.format("vitesse de vol : %.3f tuile/tick", v))
      ctx.check(b.ancres == 6, "6 ancres reposees", tostring(b.ancres))
      -- une tourelle ennemie à portée : le Glas automatique
      remote.call("fo-bourdon", "muet", st.id, false)
      remote.call("fo-bourdon", "recharge_zero", st.id)
      st.t2 = ctx.surface().create_entity({ name = "gun-turret", position = { Fin_X + 30, Y }, force = "enemy" })
      st.compte = b.compte
    end
    if st.t2 and not st.auto and not st.t2.valid then
      st.auto = t
      ctx.ok("Glas automatique : tourelle ennemie a 30 tuiles detruite", "tick " .. t)
      remote.call("fo-bourdon", "muet", st.id, true)
    end
    if t == 2700 then
      remote.call("fo-bourdon", "retirer", st.id)
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.pose2 ~= nil, "la cloche a fini son vol", tostring(st.pose2))
    ctx.check(st.auto ~= nil, "le Glas automatique a tire", tostring(st.auto))
    local b = etat(st)
    ctx.check(b == nil, "retirer : l'entite a disparu", b and b.phase or "absente")
    local n = #ctx.surface().find_entities_filtered({ name = "fo-bourdon" })
    ctx.check(n == 0, "plus aucun fo-bourdon sur la carte", tostring(n))
    -- plus rien du corps : seuls restent griffes et sol fendu, qui ont une vie (time_to_live)
    local sans_vie = 0
    for _, id in ipairs(rendering.get_all_ids("factorio-overhaul")) do
      local sp = rendering.get_type(id) == "sprite" and rendering.get_sprite(id) or ""
      if type(sp) == "string" and sp:find("fo-bourdon", 1, true) and rendering.get_time_to_live(id) == 0 then
        sans_vie = sans_vie + 1
      end
    end
    ctx.check(sans_vie == 0, "aucun dessin du Bourdon sans fin de vie", tostring(sans_vie))
  end,
}
