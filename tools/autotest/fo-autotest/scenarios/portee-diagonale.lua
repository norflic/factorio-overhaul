--[[
  Lot CORR-RALLIEMENT (5/11, demande du lead à 18 h 50) : MESURE de la règle « boîte à boîte » en moteur réel. Un mitrailleur de
  faction (fo-amber-gunner : portée 20, mode « bounding-box-to-bounding-box », boîte ± 0,2) attaque une mitrailleuse à niveaux
  garnie, seul, sur trois arènes séparées de 200 tuiles :
    A : niveau 9 (portée 21,7 au centre, 3×3, boîte ± 1,2), approche EN DIAGONALE (du nord-est) ;
    B : niveau 10 (portée 22,1), approche en diagonale ;
    C : niveau 9, approche sur l'AXE (de l'est) : témoin de la diagonale.
  Calcul (shared/ai3/reaction.lua, Re.reach_on, Re.gap ; RAPPORT EFFONDREMENT §9) : en boîte à boîte, le mitrailleur frappe le
  centre d'une tourelle depuis 20 + √2 × 1,4 = 21,98 en diagonale, 20 + 1,4 = 21,4 sur l'axe. Hypothèse DÉDUITE (la doc ne le dit
  pas) : distance euclidienne entre les boîtes. Ce banc la mesure.
  Attendus ÉCRITS AVANT tout passage (fo-logs/2026-11-05_EFFONDREMENT/CRITERES.md, « Mesure de la diagonale ») :
    A : le mitrailleur touche la tourelle depuis plus de 21,7 tuiles (centre à centre) ; la tourelle ne le touche JAMAIS ; elle meurt ;
    B : la tourelle touche le mitrailleur (il s'arrête à moins de 22,1) ; le mitrailleur meurt, la tourelle vit ;
    C : la tourelle touche le mitrailleur (axe : 21,4 < 21,7).
  Rapporté sans seuil : distances du premier coup dans chaque sens, distance d'arrêt du mitrailleur, qui frappe le premier (en B,
  l'écart d'atteinte, 0,12 tuile, est franchi en 1 tick à 0,11 tuile par tick, quand une tourelle repliée met 1 / preparing_speed
  ticks à se déplier, F120 : l'ordre des premiers coups n'est pas jugé).
  Lancement (à la reprise seulement, par la file) :
    py -3.9 -B tools/autotest/banc.py --out <archive> --qui CORR-RALLIEMENT -- 3000 portee-diagonale <source>
  MESURÉ le 5/11 (fo-logs/2026-11-05_CORR-RALLIEMENT/portee-diagonale-e0e42a60 : 8 OK, 2 ECHEC sur les attendus ci-dessus) :
    A : le mitrailleur, arrêté à 21,933, touche la tourelle (tick 238) ; la tourelle le TOUCHE aussi à 21,933 (tick 255), il meurt
    (tick 489), elle VIT. Au centre à centre, la tourelle atteint la BOÎTE de sa cible (21,656 de son centre à la boîte du
    mitrailleur). B et C comme attendu.
  7/11 (décision du lead) : les attendus de A sont ALIGNÉS SUR CETTE MESURE (pas sur un modèle) : touchée depuis plus que sa
    portée ; la tourelle riposte ; le mitrailleur meurt, la tourelle vit. Le point (C) (shared/ai3/reaction.lua) s'aligne sur la même
    mesure. PRÉMISSE : le mitrailleur a la portée 20 de la mesure ; depuis la 0.6.59 (b142714d) il est à 16 : le banc écrit alors
    « [FO-PORTEE-DIAGONALE] SANS OBJET : prémisse … », ne pose rien et ne juge ni A, ni B, ni C (aucun contrôle : BILAN 0 OK,
    0 ECHEC ; décision du lead, 7/11 : pas d'échec voulu). Critères : fo-logs/2026-11-05_EFFONDREMENT/CRITERES.md, point (C).
]]

local Y0, XS = 2600, { A = 2600, B = 2800, C = 3000 }
local START = 60       -- tick de l'arrivée du mitrailleur
local D0 = 40          -- distance de départ (centre à centre)
local DIAG = math.sqrt(0.5)
local ARENES = {
  { key = "A", level = 9, dx = D0 * DIAG, dy = -D0 * DIAG },
  { key = "B", level = 10, dx = D0 * DIAG, dy = -D0 * DIAG },
  { key = "C", level = 9, dx = D0, dy = 0 },
}
local UNIT = "fo-amber-gunner"

local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

local function half(box)
  return (box.right_bottom.x - box.left_top.x) / 2, (box.right_bottom.y - box.left_top.y) / 2
end

return {
  description = "CORR-RALLIEMENT : mitrailleur (20, boite a boite) contre mitrailleuses de niveau 9 et 10, en diagonale et sur l'axe",
  check_tick = 2900,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    -- Prémisse de la mesure du 5/11 (lue AVANT tout contrôle) : mitrailleur de portée 20. Sinon : SANS OBJET, rien n'est posé ni jugé.
    local gp0 = game.entity_prototypes[UNIT]
    local r0 = gp0 and gp0.attack_parameters and gp0.attack_parameters.range
    if r0 and math.abs(r0 - 20) > 1e-6 then
      st.sans_objet = string.format("premisse : mitrailleur %s de portee 20 (mesure du 5/11) ; portee lue %.2f : A, B et C ne sont pas juges", UNIT, r0)
      ctx.log("SANS OBJET : " .. st.sans_objet)
      return
    end
    game.map_settings.enemy_expansion.enabled = false
    st.ar = {}
    for _, a in ipairs(ARENES) do
      local x = XS[a.key]
      ctx.prepare_area(x - 60, Y0 - 60, x + 60, Y0 + 60, "grass-1")
      for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { x - 200, Y0 - 200 }, { x + 200, Y0 + 200 } } })) do
        en.destroy()
      end
      local name = "fo-lvl-gun-" .. a.level
      local t = s.create_entity({ name = name, position = { x, Y0 }, force = "player" })
      if t then t.insert({ name = "firearm-magazine", count = 200 }) end
      ctx.check(t ~= nil, string.format("%s : %s posee et garnie", a.key, name))
      st.ar[#st.ar + 1] = { key = a.key, level = a.level, t = t, dx = a.dx, dy = a.dy, x = x }
    end
    -- Profils lus aux prototypes (ce que lit la règle : M.attack_profile)
    local gp = game.entity_prototypes[UNIT]
    ctx.check(gp ~= nil and gp.attack_parameters ~= nil, "prototype " .. UNIT .. " present")
    if gp then
      local ap = gp.attack_parameters
      local ghx, ghy = half(gp.collision_box)
      ctx.log(string.format("%s : portee %.2f, mode %s, boite +-%.2f x +-%.2f, vitesse %.3f", UNIT, ap.range, tostring(ap.range_mode),
        ghx, ghy, gp.speed or -1))
      st.g = { r = ap.range, bb = ap.range_mode == "bounding-box-to-bounding-box", hx = ghx, hy = ghy }
    end
    for _, a in ipairs(st.ar) do
      if a.t and st.g then
        local tp = a.t.prototype
        local ap = tp.attack_parameters
        local thx, thy = half(tp.collision_box)
        local sx, sy = st.g.hx + thx, st.g.hy + thy
        a.tr = ap.range
        a.reach_diag = st.g.r + (st.g.bb and math.sqrt(sx * sx + sy * sy) or 0)
        a.reach_axis = st.g.r + (st.g.bb and math.min(sx, sy) or 0)
        ctx.log(string.format("%s : niveau %d, portee %.2f (mode %s), boite +-%.2f ; le mitrailleur frappe son centre depuis %.2f (diagonale), %.2f (axe)",
          a.key, a.level, ap.range, tostring(ap.range_mode), thx, a.reach_diag, a.reach_axis))
      end
    end
  end,

  tick = function(ctx, e)
    local t = e.tick
    local st = ctx.state()
    if st.sans_objet then return end
    local s = ctx.surface()
    if t == START then
      for _, a in ipairs(st.ar) do
        if a.t and a.t.valid then
          local p = s.find_non_colliding_position(UNIT, { x = a.x + a.dx, y = Y0 + a.dy }, 2, 0.1)
          local g = p and s.create_entity({ name = UNIT, position = p, force = "enemy" })
          if g then
            g.set_command({ type = defines.command.attack, target = a.t, distraction = defines.distraction.none })
            a.g, a.ghp, a.thp = g, g.health, a.t.health
            a.gx, a.gy, a.still = g.position.x, g.position.y, 0
          end
          ctx.log(string.format("%s : mitrailleur pose a (%.2f, %.2f), %.2f tuiles du centre", a.key, p and p.x - a.x or 0,
            p and p.y - Y0 or 0, p and dist(p, { x = a.x, y = Y0 }) or -1))
        end
      end
      return
    end
    if t <= START then return end
    for _, a in ipairs(st.ar) do
      local tv, gv = a.t and a.t.valid, a.g and a.g.valid
      if tv and gv then
        local d = dist(a.g.position, a.t.position)
        if not a.t_hit and a.t.health < a.thp - 1e-6 then
          a.t_hit, a.t_hit_d, a.t_hit_tick = true, d, t
          ctx.log(string.format("%s : la tourelle est touchee au tick %d, mitrailleur a %.3f tuiles du centre", a.key, t, d))
        end
        if not a.g_hit and a.g.health < a.ghp - 1e-6 then
          a.g_hit, a.g_hit_d, a.g_hit_tick = true, d, t
          ctx.log(string.format("%s : le mitrailleur est touche au tick %d, a %.3f tuiles du centre", a.key, t, d))
        end
        local gp = a.g.position
        if math.abs(gp.x - a.gx) + math.abs(gp.y - a.gy) < 0.005 then a.still = a.still + 1 else a.still = 0 end
        a.gx, a.gy = gp.x, gp.y
        if a.still == 10 and not a.stop_d then
          a.stop_d = d
          ctx.log(string.format("%s : mitrailleur arrete a %.3f tuiles du centre (%.2f, %.2f)", a.key, d, gp.x - a.x, gp.y - Y0))
        end
        a.thp, a.ghp = a.t.health, a.g.health
      end
      if a.t and not tv and not a.t_dead then
        a.t_dead = t
        ctx.log(string.format("%s : tourelle detruite au tick %d", a.key, t))
      end
      if a.g and not gv and not a.g_dead then
        a.g_dead = t
        ctx.log(string.format("%s : mitrailleur mort au tick %d", a.key, t))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if st.sans_objet then
      ctx.log("SANS OBJET : " .. st.sans_objet)
      return
    end
    local by = {}
    for _, a in ipairs(st.ar) do by[a.key] = a end
    local function fmt(v) return v and string.format("%.3f", v) or "-" end
    for _, a in ipairs(st.ar) do
      ctx.log(string.format("FAIT %s (niveau %d) : portee %s ; atteinte calculee %s (diag) %s (axe) ; arret %s ; tourelle touchee a %s (tick %s) ; mitrailleur touche a %s (tick %s) ; tourelle detruite %s ; mitrailleur mort %s",
        a.key, a.level, fmt(a.tr), fmt(a.reach_diag), fmt(a.reach_axis), fmt(a.stop_d), fmt(a.t_hit_d), tostring(a.t_hit_tick),
        fmt(a.g_hit_d), tostring(a.g_hit_tick), tostring(a.t_dead), tostring(a.g_dead)))
    end
    local A, B, C = by.A, by.B, by.C
    ctx.check(A and A.t_hit and A.t_hit_d and A.tr and A.t_hit_d > A.tr, "A (niveau 9, diagonale) : touchee depuis plus que sa portee",
      A and string.format("%s contre %s", fmt(A.t_hit_d), fmt(A.tr)) or "-")
    -- MESURÉ le 5/11 (point (C)) : la tourelle atteint la BOÎTE du mitrailleur : elle riposte depuis plus que sa portée de centre à centre.
    ctx.check(A and A.g_hit and A.g_hit_d and A.tr and A.g_hit_d > A.tr, "A : la tourelle riposte (touche le mitrailleur depuis plus que sa portee de centre a centre)",
      A and string.format("%s contre %s", fmt(A.g_hit_d), fmt(A.tr)) or "-")
    ctx.check(A and A.g_dead ~= nil and A.t_dead == nil, "A : le mitrailleur meurt, la tourelle vit",
      A and string.format("mitrailleur %s, tourelle %s", tostring(A.g_dead), tostring(A.t_dead)) or "-")
    ctx.check(B and B.g_hit and B.g_hit_d and B.tr and B.g_hit_d <= B.tr + 1e-3, "B (niveau 10, diagonale) : la tourelle riposte",
      B and string.format("%s contre %s", fmt(B.g_hit_d), fmt(B.tr)) or "-")
    ctx.check(B and B.g_dead ~= nil and B.t_dead == nil, "B : le mitrailleur meurt, la tourelle vit",
      B and string.format("mitrailleur %s, tourelle %s", tostring(B.g_dead), tostring(B.t_dead)) or "-")
    ctx.check(C and C.g_hit, "C (niveau 9, axe) : la tourelle riposte", C and fmt(C.g_hit_d) or "-")
  end,
}
