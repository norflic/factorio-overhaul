--[[
  Décision du DC (QCM-7/11) : portée du mitrailleur des factions à 16 (b142714d). Micro-banc en moteur réel (demande du lead, 7/11
  à 10 h 58). Un mitrailleur de faction (fo-amber-gunner : portée lue au prototype, « bounding-box-to-bounding-box », boîte ± 0,2)
  attaque SEUL une cible, sur cinq arènes séparées de 200 tuiles :
    A : mitrailleuse de base « gun-turret » garnie (18, centre à centre, ± 0,7), approche EN DIAGONALE (du nord-est) ;
    B : la même, approche sur l'AXE (de l'est) ;
    E : la mitrailleuse à niveaux de niveau 1 (fo-lvl-gun-1) garnie, en diagonale ;
    C : une gun-turret SANS munitions (elle ne tire pas : mesure seule), en diagonale ;
    D : la même sans munitions, sur l'axe.
  Calcul (shared/ai3/reaction.lua, Re.gap ; tests/portee_mitrailleur_test.lua) : le mitrailleur frappe le centre d'une tourelle
  ± 0,7 depuis 16 + √2 × 0,9 = 17,27 en diagonale, 16 + 0,9 = 16,9 sur l'axe ; la tourelle le frappe à 18 : marge 0,73 en
  diagonale. Hypothèse DÉDUITE (la doc ne le dit pas) : distance euclidienne entre les boîtes ; C et D la mesurent.
  Attendus ÉCRITS AVANT tout passage (aussi dans fo-logs/2026-11-05_EFFONDREMENT/CRITERES.md, « Portée 16 ») :
    init : 5 cibles posées (garnies en A, B, E ; vides en C, D), prototype du mitrailleur présent, portée lue = 16 ;
    A, B, E : la tourelle touche le mitrailleur, depuis 18 tuiles au plus ; elle n'est JAMAIS touchée depuis plus de 18 (pas de
      débordement) ;
    C : premier coup du mitrailleur depuis plus de 16,9 (au-delà de l'axe) et au plus 17,32 (17,27 + 0,05) ;
    D : premier coup depuis plus de 16 et au plus 16,95.
  BILAN attendu : 7 OK au départ (5 cibles, prototype, portée 16) + 3 × 2 (A, B, E) + 2 (C, D) = 15 OK. Rapporté sans seuil : distance d'arrêt, qui meurt (le duel se
  joue aux dégâts, pas à la portée : il n'est pas jugé).
  Lancement (par la file) : py -3.9 -B tools/autotest/banc.py --out <archive> --qui EFFONDREMENT -- 3100 portee-16 <source>
]]

local Y0, XS = 2600, { A = 2600, B = 2800, E = 3000, C = 3200, D = 3400 }
local START = 60       -- tick de l'arrivée du mitrailleur
local D0 = 40          -- distance de départ (centre à centre)
local DIAG = math.sqrt(0.5)
local ARENES = {
  { key = "A", name = "gun-turret", ammo = true, dx = D0 * DIAG, dy = -D0 * DIAG },
  { key = "B", name = "gun-turret", ammo = true, dx = D0, dy = 0 },
  { key = "E", name = "fo-lvl-gun-1", ammo = true, dx = D0 * DIAG, dy = -D0 * DIAG },
  { key = "C", name = "gun-turret", ammo = false, dx = D0 * DIAG, dy = -D0 * DIAG },
  { key = "D", name = "gun-turret", ammo = false, dx = D0, dy = 0 },
}
local UNIT = "fo-amber-gunner"
local EPS = 0.05

local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

local function half(box)
  return (box.right_bottom.x - box.left_top.x) / 2, (box.right_bottom.y - box.left_top.y) / 2
end

return {
  description = "Portee 16 : mitrailleur (boite a boite) contre la mitrailleuse de base, en diagonale et sur l'axe, et mesure sans riposte",
  check_tick = 2900,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.map_settings.enemy_expansion.enabled = false
    st.ar = {}
    for _, a in ipairs(ARENES) do
      local x = XS[a.key]
      ctx.prepare_area(x - 60, Y0 - 60, x + 60, Y0 + 60, "grass-1")
      for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { x - 200, Y0 - 200 }, { x + 200, Y0 + 200 } } })) do
        en.destroy()
      end
      local t = s.create_entity({ name = a.name, position = { x, Y0 }, force = "player" })
      if t and a.ammo then t.insert({ name = "firearm-magazine", count = 200 }) end
      ctx.check(t ~= nil, string.format("%s : %s posee (%s)", a.key, a.name, a.ammo and "garnie" or "sans munitions"))
      st.ar[#st.ar + 1] = { key = a.key, name = a.name, ammo = a.ammo, t = t, dx = a.dx, dy = a.dy, x = x }
    end
    local gp = game.entity_prototypes[UNIT]
    ctx.check(gp ~= nil and gp.attack_parameters ~= nil, "prototype " .. UNIT .. " present")
    if gp then
      local ap = gp.attack_parameters
      local ghx, ghy = half(gp.collision_box)
      ctx.check(math.abs(ap.range - 16) < 1e-6, "portee du mitrailleur lue au prototype = 16", string.format("%.2f", ap.range))
      ctx.log(string.format("%s : portee %.2f, mode %s, boite +-%.2f x +-%.2f, vitesse %.3f", UNIT, ap.range, tostring(ap.range_mode),
        ghx, ghy, gp.speed or -1))
      st.g = { r = ap.range, bb = ap.range_mode == "bounding-box-to-bounding-box", hx = ghx, hy = ghy }
    end
    for _, a in ipairs(st.ar) do
      if a.t and st.g then
        local tp = a.t.prototype
        local thx, thy = half(tp.collision_box)
        local sx, sy = st.g.hx + thx, st.g.hy + thy
        a.tr = tp.attack_parameters.range
        a.reach_diag = st.g.r + (st.g.bb and math.sqrt(sx * sx + sy * sy) or 0)
        a.reach_axis = st.g.r + (st.g.bb and math.min(sx, sy) or 0)
        ctx.log(string.format("%s : %s, portee %.2f (mode %s), boite +-%.2f ; le mitrailleur frappe son centre depuis %.2f (diagonale), %.2f (axe)",
          a.key, a.name, a.tr, tostring(tp.attack_parameters.range_mode), thx, a.reach_diag, a.reach_axis))
      end
    end
  end,

  tick = function(ctx, e)
    local t = e.tick
    local st = ctx.state()
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
          ctx.log(string.format("%s : la cible est touchee au tick %d, mitrailleur a %.3f tuiles du centre", a.key, t, d))
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
        ctx.log(string.format("%s : cible detruite au tick %d", a.key, t))
      end
      if a.g and not gv and not a.g_dead then
        a.g_dead = t
        ctx.log(string.format("%s : mitrailleur mort au tick %d", a.key, t))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local by = {}
    for _, a in ipairs(st.ar) do by[a.key] = a end
    local function fmt(v) return v and string.format("%.3f", v) or "-" end
    for _, a in ipairs(st.ar) do
      ctx.log(string.format("FAIT %s (%s, %s) : portee %s ; atteinte calculee %s (diag) %s (axe) ; arret %s ; cible touchee a %s (tick %s) ; mitrailleur touche a %s (tick %s) ; cible detruite %s ; mitrailleur mort %s",
        a.key, a.name, a.ammo and "garnie" or "vide", fmt(a.tr), fmt(a.reach_diag), fmt(a.reach_axis), fmt(a.stop_d), fmt(a.t_hit_d),
        tostring(a.t_hit_tick), fmt(a.g_hit_d), tostring(a.g_hit_tick), tostring(a.t_dead), tostring(a.g_dead)))
    end
    for _, k in ipairs({ "A", "B", "E" }) do
      local a = by[k]
      ctx.check(a and a.g_hit and a.g_hit_d and a.tr and a.g_hit_d <= a.tr + 1e-3,
        k .. " : la mitrailleuse touche le mitrailleur, depuis sa portee au plus", a and string.format("%s contre %s", fmt(a.g_hit_d), fmt(a.tr)) or "-")
      ctx.check(a and a.tr and (not a.t_hit or (a.t_hit_d and a.t_hit_d <= a.tr + 1e-3)),
        k .. " : jamais touchee depuis plus que sa portee (pas de debordement)", a and string.format("%s contre %s", fmt(a.t_hit_d), fmt(a.tr)) or "-")
    end
    local C, D = by.C, by.D
    ctx.check(C and C.t_hit_d and C.reach_axis and C.reach_diag and C.t_hit_d > C.reach_axis and C.t_hit_d <= C.reach_diag + EPS,
      "C (sans munitions, diagonale) : premier coup au-dela de l'axe, jusqu'a la diagonale",
      C and string.format("%s dans ]%s ; %s]", fmt(C.t_hit_d), fmt(C.reach_axis), fmt((C.reach_diag or 0) + EPS)) or "-")
    ctx.check(D and D.t_hit_d and D.reach_axis and st.g and D.t_hit_d > st.g.r and D.t_hit_d <= D.reach_axis + EPS,
      "D (sans munitions, axe) : premier coup jusqu'a l'axe",
      D and string.format("%s dans ]%s ; %s]", fmt(D.t_hit_d), fmt(st.g and st.g.r), fmt((D.reach_axis or 0) + EPS)) or "-")
  end,
}
