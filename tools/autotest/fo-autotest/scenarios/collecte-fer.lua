--[[
  Lot COLLECTE (7/11) : micro-banc de la collecte des coffres de sortie du fer quand le fer manque (partie du DC en 0.6.58 : 8 coffres de
  sortie du champ au-dessus du seuil de 200 pendant que le fer libre est à 0 et l'équipe à 2 PNJ).
  Scène (équipe du joueur, comme briques_common) : coffre d'équipe posé (fondation), puis, dès qu'elle compte au moins 4 PNJ, à T0 :
    - effectif de départ voulu 12 (fo-npc-start), équipe réduite à 2 PNJ, plaques de fer du coffre retirées (fer libre 0) ;
    - un projet « fini » de banc tient 3 coffres de sortie de fer : A sûr à ~75 tuiles du coffre d'équipe (600 plaques), B à ~70 tuiles
      mais avec un ennemi (ver) à 20 tuiles du coffre (500 plaques), C sûr à ~100 tuiles (400 plaques) ;
    - les tâches de minage de fer concurrentes viennent d'elles-mêmes (fer à 0 : le planificateur et le cerveau en posent).
  Une fenêtre de 3 700 ticks (> 60 s) à partir de T0 ; relevé toutes les 300 ticks (tâches de collecte, priorité, prise, plaques des coffres).
  Contrôles ÉCRITS AVANT (fo-logs/2026-11-07_COLLECTE/CRITERES.md) :
    K1 (LOT) la tâche de collecte du coffre A est PRISE moins de 60 s (3 600 ticks) après T0 ;
    K2 (LOT) le coffre B est refusé pour la cause « ennemi » (f.team.collecte.refused) et sa tâche n'est jamais prise ;
    K3 (LOT) le fer arrive au QG : fer libre >= 300 à la fin et le coffre A a perdu au moins 300 plaques ;
    K4 (LOT) la tâche choisie est à la priorité d'urgence (94, critique) tant qu'elle est libre.
  TÉMOIN (source 0e340b99 + la seule interface de banc, sans la règle) : mêmes mesures, journalisées (RESULTAT), SANS contrôle K1 à K4 :
    la règle n'y existe pas (f.team.collecte absent) ; ce qu'il montre est le délai de prise (ou l'absence de prise), la priorité 55 et
    le fer au QG, à comparer.
  Lancement (par la file, quand le lead lève le gel) :
    banc.py --out <archive> --qui COLLECTE -- 5400 collecte-fer <source>
  Journal : [FO-COLLECTE-FER] (le mod écrit [FO-COLLECTE] : choix et refus).
]]

local MIN = 3600
local EVERY = 300
local WINDOW = 3700
local T_MAX = 2400          -- au plus tard : T0 doit avoir eu lieu (équipe fondée, au moins 4 PNJ)
local CHECK = 5400

local function chest_of(ctx)
  return ctx.surface().find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
end

local function spot(ctx, hq, dx, dy)
  local s = ctx.surface()
  local p = s.find_non_colliding_position("iron-chest", { x = hq.x + dx, y = hq.y + dy }, 12, 1)
  return p or { x = hq.x + dx, y = hq.y + dy }
end

local function plates_at(ctx, pos)
  local c = ctx.surface().find_entity("iron-chest", pos)
  return (c and c.valid) and c.get_inventory(defines.inventory.chest).get_item_count("iron-plate") or -1
end

local function state_text(s)
  if not s then return "etat absent" end
  local parts = {}
  for i = 1, 3 do
    local t = s.tasks[i]
    parts[#parts + 1] = t and string.format("o%d p%d%s%s", i, t.prio or 0, t.critical and " crit" or "", t.prise and " PRISE" or " libre") or ("o" .. i .. " absente")
  end
  return string.format("%s | PNJ %d/%d | fer QG %d | regle %s | choisis [%s] refus [%s]", table.concat(parts, ", "), s.engineers, s.floor, s.iron,
    tostring(s.rule), table.concat(s.picked, ","), table.concat(s.refused, ","))
end

return {
  description = "COLLECTE : 2 PNJ sous un effectif de 12, fer libre 0, 3 coffres de sortie de fer (A sur, B pres d'un ver, C sur), minage de fer concurrent",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8 a la fondation")
    local s = ctx.surface()
    local c0 = game.forces.player.get_spawn_position(s)
    local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
    local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    local inv = chest.get_inventory(defines.inventory.chest)
    inv.insert({ name = "coal", count = 400 })
    st.hq = { x = chest.position.x, y = chest.position.y }
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.hq or e.tick < 300 then return end
    if not st.t0 and e.tick % 60 == 0 then
      local row
      for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do if r.key == "player" then row = r end end
      if (row and row.n >= 4) or e.tick >= T_MAX then
        local hq = st.hq
        st.A = spot(ctx, hq, 75, 0)
        st.B = spot(ctx, hq, -70, 10)
        st.C = spot(ctx, hq, 0, 100)
        -- ver (ennemi) à 20 tuiles du coffre B, hors du chemin du coffre A et C
        local w = ctx.surface().create_entity({ name = "small-worm-turret", position = { x = st.B.x - 20, y = st.B.y }, force = "enemy" })
        st.worm = w ~= nil
        ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 12) == 12, "effectif de depart voulu 12")
        local r = ctx.remote("fo-ia1", "bench_collecte", "player", 2, { { st.A.x, st.A.y, 600 }, { st.B.x, st.B.y, 500 }, { st.C.x, st.C.y, 400 } })
        ctx.check(r ~= nil and r.outs == 3, "projet de banc : 3 coffres de sortie", r and tostring(r.outs) or "nil")
        st.pid = r and r.project
        st.t0 = e.tick
        st.a0, st.b0, st.c0 = plates_at(ctx, st.A), plates_at(ctx, st.B), plates_at(ctx, st.C)
        ctx.log(string.format("T0=%d : PNJ gardes %s, fer QG %s, ver pose %s, A (%.0f,%.0f) %d, B (%.0f,%.0f) %d, C (%.0f,%.0f) %d", e.tick,
          r and tostring(r.kept) or "?", r and tostring(r.iron) or "?", tostring(st.worm), st.A.x, st.A.y, st.a0, st.B.x, st.B.y, st.b0, st.C.x, st.C.y, st.c0))
      end
      return
    end
    if not st.t0 then return end
    local dt = e.tick - st.t0
    if dt <= WINDOW and dt % EVERY == 0 then
      local s = ctx.remote("fo-ia1", "collecte_state", "player", st.pid)
      ctx.log(string.format("t0+%d | %s | coffres A %d B %d C %d", dt, state_text(s), plates_at(ctx, st.A), plates_at(ctx, st.B), plates_at(ctx, st.C)))
    end
    -- relevé fin : la première prise de la tâche de A / B (une pensée d'équipe tous les ~60 ticks suffit)
    if dt <= WINDOW and e.tick % 30 == 0 then
      local s = ctx.remote("fo-ia1", "collecte_state", "player", st.pid)
      if s then
        st.rule = s.rule
        local ta, tb = s.tasks[1], s.tasks[2]
        if ta and ta.prise and not st.take_a then st.take_a = dt end
        if tb and tb.prise then st.take_b = st.take_b or dt end
        if ta and ta.urgent and ta.prio == 94 and ta.critical then st.urgent_seen = true end
        for _, k in ipairs(s.refused) do if k:find(":ennemi", 1, true) then st.refus_ennemi = true end end
        if st.a0 and plates_at(ctx, st.A) < st.a0 and not st.drop_a then st.drop_a = dt end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.t0 then
      ctx.check(false, "T0 a eu lieu (equipe fondee, 4 PNJ au moins)", "tick " .. tostring(CHECK))
      return
    end
    local s = ctx.remote("fo-ia1", "collecte_state", "player", st.pid) or {}
    local a, b, c = plates_at(ctx, st.A), plates_at(ctx, st.B), plates_at(ctx, st.C)
    local rule = s.rule == true
    ctx.log(string.format("RESULTAT regle=%s prise_A=%s prise_B=%s vidage_A=%s refus_ennemi=%s urgente_vue=%s fer_QG=%s A=%d->%d B=%d->%d C=%d->%d PNJ=%s/%s",
      tostring(rule), tostring(st.take_a), tostring(st.take_b), tostring(st.drop_a), tostring(st.refus_ennemi), tostring(st.urgent_seen),
      tostring(s.iron), st.a0 or -1, a, st.b0 or -1, b, st.c0 or -1, c, tostring(s.engineers), tostring(s.floor)))
    ctx.check(s.floor == 12 and (s.engineers or 99) <= 4, "scene tenue : effectif voulu 12, equipe petite", string.format("%s/%s", tostring(s.engineers), tostring(s.floor)))
    if rule then
      ctx.check(st.take_a ~= nil and st.take_a < 3600, "K1 : collecte du coffre A prise en moins de 60 s", tostring(st.take_a))
      ctx.check(st.refus_ennemi == true and st.take_b == nil and b >= (st.b0 or 0), "K2 : coffre B refuse (ennemi), jamais pris, intact", string.format("refus %s prise %s B %d", tostring(st.refus_ennemi), tostring(st.take_b), b))
      ctx.check((s.iron or 0) >= 300 and a <= (st.a0 or 0) - 300, "K3 : le fer arrive au QG", string.format("fer %s A %d", tostring(s.iron), a))
      ctx.check(st.urgent_seen == true, "K4 : la tache choisie est a 94, critique")
    else
      ctx.log("TEMOIN : pas de regle (f.team.collecte absent) ; les controles K1 a K4 ne s'appliquent pas, lire RESULTAT")
    end
  end,
}
