-- Scénario greffé du lot RB-4 GAMME (1/11) : les rôles de SOUTIEN en moteur réel (PLAN.md ROBOTS, §1 « Bouclier » et « Ingénieur », §2).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui RB4 -- 1200 rb-soutien <source>
--   A  Cloche : 33 Trotte-Vapeur blessés à moitié dans son rayon de 12, un à 15 tuiles. Une impulsion (60 ticks) soigne 30 robots au plus
--      de `heal.amount` (172) chacun, les plus petits numéros d'unité d'abord ; celui hors du rayon n'est pas soigné ; la suivante
--      soigne le reste.
--   B  Chanfrein (artillerie, tir d'explosion en zone de rayon 3, portée 45, portée minimale 12) : trois déchiqueteurs du palier 12
--      immobiles (cibles inertes, distraction nulle) : T1 à 30 tuiles, T2 à 2 tuiles de T1 (dans la zone), T3 à 8 tuiles de T1 (hors zone).
--      La perte de T1 et de T2 au premier tir est comparée à la règle de résistance du modèle ((dégâts − 76) × 0,26).
--   C  Chanfrein à 6 tuiles d'une cible (moins que sa portée minimale) : il ne la touche pas tant qu'elle est trop près (information).
--   D  Truelle : un fantôme de mur ravivé à partir d'un coffre voisin (le coffre perd un mur), un mur blessé réparé de `repair` PV.
-- Journal : [FO-RB-SOUTIEN].

local C = require("scenarios/rb0_common")

local X0, Y0 = 7000, 6000
local PAS = 80
local T_BLESSE = 10
local T_P1 = 70      -- après la première impulsion (tick 60)
local T_P2 = 130     -- après la seconde (tick 120)
local T_TIR = 400    -- premier tir de l'artillerie avant ce tick
local CHECK = 1100

local function R(ctx, fn, ...) return ctx.remote("fo-robots", fn, ...) end
local function S(ctx, fn, ...) return ctx.remote("fo-robots-soutien", fn, ...) end

-- Règle de résistance du moteur (shared/robots/duel.lua Duel.after_resist) pour un déchiqueteur de palier 12 : explosion 76 fixe, 74 %.
local function degats_explosion_t12(montant) return (montant - 76) * (1 - 0.74) end
local DEGATS_CHANFREIN = 10900 -- shot.damage du Chanfrein (shared/content/robots.lua) ; contrôlé par tests/robots_duel_test.lua

return {
  description = "RB-4 : soin de la Cloche, artillerie du Chanfrein (zone, portee minimale), Truelle (ravive, repare)",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    st.pret = false
    local manque = {}
    for _, n in ipairs({ "fo-robot-player-bellwether", "fo-robot-player-chamfer", "fo-robot-player-trowel", "fo-robot-player-steam-trotter",
      "fo-eternal-biter" }) do
      if not game.entity_prototypes[n] then manque[#manque + 1] = n end
    end
    if #manque > 0 then
      ctx.fail("prototypes presents", table.concat(manque, ", "))
      return
    end
    C.force("rb-duel")
    game.map_settings.enemy_expansion.enabled = false
    ctx.call("war_setting", "fo-war-robots-cap", 400)
    ctx.prepare_area(X0 - 60, Y0 - 30, X0 + 60, Y0 + PAS * 4, "grass-1")
    C.sans_ennemis(s, X0 - 80, Y0 - 50, X0 + 80, Y0 + PAS * 4 + 30)

    -- A : Cloche et 33 Trotte-Vapeur
    local ya = Y0
    st.cloche = R(ctx, "spawn", "rb-duel", "bellwether", X0, ya)
    st.troupe = {}
    local n = 0
    for ring = 1, 3 do
      local nb = 11
      for k = 1, nb do
        local ang = (k / nb) * 2 * math.pi
        local rr = 3 + ring * 2.5
        local un = R(ctx, "spawn", "rb-duel", "steam-trotter", X0 + rr * math.cos(ang), ya + rr * math.sin(ang))
        if un then st.troupe[#st.troupe + 1] = un n = n + 1 end
      end
    end
    st.loin = R(ctx, "spawn", "rb-duel", "steam-trotter", X0 + 15, ya)
    ctx.log(string.format("A : Cloche %s, %d robot(s) dans le rayon, un a 15 tuiles (%s)", tostring(st.cloche), n, tostring(st.loin)))

    -- B : Chanfrein et trois cibles inertes de palier 12
    local yb = Y0 + PAS
    st.chanf = R(ctx, "spawn", "rb-duel", "chamfer", X0, yb)
    local function cible(x, y)
      local b = s.create_entity({ name = "fo-eternal-biter", position = { x, y }, force = "enemy" })
      if b then b.set_command({ type = defines.command.stop, distraction = defines.distraction.none, ticks_to_wait = 1000000 }) end
      return b
    end
    st.t1 = cible(X0 + 30, yb)
    st.t2 = cible(X0 + 30, yb + 2)
    st.t3 = cible(X0 + 30, yb + 8)

    -- C : Chanfrein trop près
    local yc = Y0 + 2 * PAS
    st.chanf2 = R(ctx, "spawn", "rb-duel", "chamfer", X0, yc)
    st.t4 = cible(X0 + 6, yc)

    -- D : Truelle, coffre de murs, fantôme, mur blessé
    local yd = Y0 + 3 * PAS
    st.truelle = R(ctx, "spawn", "rb-duel", "trowel", X0, yd)
    st.coffre = s.create_entity({ name = "steel-chest", position = { X0 + 4.5, yd + 0.5 }, force = "rb-duel" })
    if st.coffre then st.coffre.insert({ name = "stone-wall", count = 5 }) end
    st.fantome = s.create_entity({ name = "entity-ghost", inner_name = "stone-wall", position = { X0 - 6.5, yd + 0.5 }, force = "rb-duel" })
    st.mur = s.create_entity({ name = "stone-wall", position = { X0 - 6.5, yd + 5.5 }, force = "rb-duel" })
    if st.mur then st.mur.health = 100 end
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local t = e.tick

    if t == T_BLESSE then
      st.avant = {}
      for _, un in ipairs(st.troupe) do R(ctx, "hurt", un, 0.5) end
      R(ctx, "hurt", st.loin, 0.5)
      for _, un in ipairs(st.troupe) do
        local i = R(ctx, "unit_info", un)
        st.avant[un] = i and i.health
      end
      local i = R(ctx, "unit_info", st.loin)
      st.avant_loin = i and i.health
    end

    -- la régénération naturelle d'une unité (1,2 PV par seconde) s'ajoute : un soin compte à partir de 100 PV de gain
    local function gains()
      local soignes, total, bons = 0, 0, 0
      for _, un in ipairs(st.troupe) do
        local i = R(ctx, "unit_info", un)
        if i and st.avant[un] and i.health - st.avant[un] >= 100 then
          soignes = soignes + 1
          total = total + (i.health - st.avant[un])
          if math.abs(i.health - st.avant[un] - 172) < 3 then bons = bons + 1 end
        end
      end
      return soignes, total, bons
    end

    if t == T_P1 then
      local soignes, total, bons = gains()
      local loin = R(ctx, "unit_info", st.loin)
      ctx.check(soignes == 30 and bons == 30 and loin and math.abs(loin.health - st.avant_loin) < 5,
        "(A1) une impulsion de la Cloche soigne 30 robots de 172 PV, pas celui hors du rayon",
        string.format("soignes %d, de 172 PV exactement %d, total %.0f, loin %s -> %s", soignes, bons, total, tostring(st.avant_loin), tostring(loin and loin.health)))
    end
    if t == T_P2 then
      local soignes, total = gains()
      local loin = R(ctx, "unit_info", st.loin)
      ctx.check(soignes >= #st.troupe and math.abs(loin.health - st.avant_loin) < 5,
        "(A2) la seconde impulsion soigne le reste ; le robot hors du rayon n'est jamais soigne",
        string.format("soignes %d sur %d, total %.0f", soignes, #st.troupe, total))
    end

    -- B : premier tir sur T1 (perte constatée une seule fois)
    if t >= 30 and t <= T_TIR and t % 2 == 0 and not st.hit then
      if st.t1 and st.t1.valid and st.t1.health < st.t1.prototype.max_health - 1 then
        st.hit = { tick = t, t1 = st.t1.prototype.max_health - st.t1.health,
          t2 = st.t2 and st.t2.valid and (st.t2.prototype.max_health - st.t2.health) or -1,
          t3 = st.t3 and st.t3.valid and (st.t3.prototype.max_health - st.t3.health) or -1 }
      end
    end

    -- D : à 70 ticks, le fantôme est ravivé et le mur réparé
    if t == 200 then
      local s = ctx.surface()
      local revive = s.find_entity("stone-wall", { X0 - 6.5, Y0 + 3 * PAS + 0.5 })
      local reste = st.coffre and st.coffre.valid and st.coffre.get_item_count("stone-wall") or -1
      ctx.check(revive ~= nil and reste == 4, "(D1) la Truelle ravive le fantome de mur avec un mur pris au coffre voisin",
        string.format("mur ravive=%s, murs restant au coffre %d (5 au depart)", tostring(revive ~= nil), reste))
      ctx.check(st.mur and st.mur.valid and st.mur.health >= st.mur.prototype.max_health - 1e-6, "(D2) la Truelle repare un mur blesse de 500 PV (jusqu'au maximum)",
        string.format("sante du mur %s", tostring(st.mur and st.mur.valid and st.mur.health)))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    local attendu = degats_explosion_t12(DEGATS_CHANFREIN)
    local h = st.hit
    ctx.check(h ~= nil, "(B1) l'artillerie touche une cible a 30 tuiles",
      string.format("premier tir au tick %s", tostring(h and h.tick)))
    if h then
      ctx.check(math.abs(h.t1 - attendu) <= 0.05 * attendu, "(B2) la perte de la cible touchee suit la regle de resistance du modele",
        string.format("perte %.0f, attendu %.0f ((%d - 76) x 0,26)", h.t1, attendu, DEGATS_CHANFREIN))
      ctx.check(math.abs(h.t2 - attendu) <= 0.05 * attendu and h.t3 == 0, "(B3) la zone de rayon 3 touche la voisine a 2 tuiles, pas celle a 8",
        string.format("voisine %.0f, eloignee %.0f", h.t2, h.t3))
    end
    local t4 = st.t4 and st.t4.valid and (st.t4.prototype.max_health - st.t4.health) or -1
    local ci = R(ctx, "unit_info", st.chanf2)
    ctx.log(string.format("[FO-RB-SOUTIEN] C : cible a 6 tuiles (portee minimale 12) : perte %.0f PV, Chanfrein %s", t4,
      ci and string.format("a (%.1f, %.1f)", ci.x, ci.y) or "mort"))
    local stats = S(ctx, "stats")
    ctx.log(string.format("[FO-RB-SOUTIEN] soins %d (%d PV), fantomes ravives %d, reparations %d", stats.healed, stats.heal_hp, stats.revived, stats.repaired))
    ctx.check(R(ctx, "check") == true, "registre des robots coherent")
  end,
}
