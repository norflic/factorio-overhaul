--[[
  Lot MELANGE2 (revue du 3/11, « NON COUVERT » n° 6) : les paires thermiques d'avant-poste (Outposts.build puis Outposts.extend,
  place_pairs) ne contrôlaient pas la zone de la foreuse à combustion (2 × 2) : une foreuse dont une tuile minée est d'un autre
  minerai en verse dans son four (four plein, foreuse figée).
  Banc en moteur réel : un gisement de FER (disque de rayon 8) qui touche un gisement de CHARBON (disque de rayon 7, 1 tuile de
  recouvrement perdue par le fer) et porte une enclave de charbon 2 × 2 ; un avant-poste de fer de votre équipe est posé puis agrandi
  jusqu'au plein (la pose réelle). Contrôle INDÉPENDANT, relu au moteur : aucune foreuse à combustion posée n'a de charbon dans sa zone
  (centre de tuile à moins de 0,99 de son centre) ; et il en reste (le fer loin du charbon est couvert). Le TÉMOIN est le même banc
  contre la source d'avant le lot : il doit voir des foreuses mêlées (sinon le banc ne prouve rien).
  Lancement : banc.py --qui MELANGE2 -- 1500 melange2-thermique <source>. Journal : [FO-MELANGE2-THERMIQUE].
]]
local TAG = "[FO-MELANGE2-THERMIQUE]"
local DRILL = "burner-mining-drill"
local CHECK = 600

return {
  description = "MELANGE2 : paires thermiques d'un avant-poste de fer au bord d'un gisement de charbon (aucune foreuse sur une zone mêlée)",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local c0 = game.forces.player.get_spawn_position(s)
    local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
    local cc = { x = math.floor(p.x) + 48, y = math.floor(p.y) }
    ctx.prepare_area(cc.x - 30, cc.y - 30, cc.x + 40, cc.y + 30, "grass-1")
    local n_i, n_c = 0, 0
    for dx = -9, 25 do
      for dy = -9, 9 do
        local in_iron = dx * dx + dy * dy <= 64
        local in_coal = (dx - 14) ^ 2 + dy * dy <= 49 or (dx >= -3 and dx <= -2 and dy >= 0 and dy <= 1)
        if in_iron and not in_coal then
          s.create_entity({ name = "iron-ore", position = { cc.x + dx + 0.5, cc.y + dy + 0.5 }, amount = 30000 }); n_i = n_i + 1
        elseif in_coal then
          s.create_entity({ name = "coal", position = { cc.x + dx + 0.5, cc.y + dy + 0.5 }, amount = 30000 }); n_c = n_c + 1
        end
      end
    end
    local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose", string.format("fer %d tuiles, charbon %d tuiles en (%d, %d)", n_i, n_c, cc.x, cc.y))
    if not chest then return end
    local o = ctx.remote("fo-ia1", "bench_outpost", "player", "iron", cc.x, cc.y)
    ctx.check(o ~= nil, "avant-poste de fer pose", o and (o.drills .. " foreuse(s)") or "nil")
    if not o then return end
    local drills = ctx.remote("fo-ia1", "bench_extend", "player", o.id, 20)
    ctx.check((drills or 0) >= 4, "avant-poste agrandi", tostring(drills) .. " foreuse(s)")
    st.cc, st.oid = cc, o.id
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.cc then return end
    local s = ctx.surface()
    local cc = st.cc
    local n, mixed, near = 0, 0, 0
    for _, d in ipairs(s.find_entities_filtered({ name = DRILL, area = { { cc.x - 30, cc.y - 30 }, { cc.x + 40, cc.y + 30 } } })) do
      n = n + 1
      local rad = d.prototype.mining_drill_radius
      local p = d.position
      local coal, iron = 0, 0
      for _, r in ipairs(s.find_entities_filtered({ area = { { p.x - rad, p.y - rad }, { p.x + rad, p.y + rad } }, type = "resource" })) do
        if math.abs(r.position.x - p.x) < rad and math.abs(r.position.y - p.y) < rad then
          if r.name == "coal" then coal = coal + 1 elseif r.name == "iron-ore" then iron = iron + 1 end
        end
      end
      if coal > 0 then mixed = mixed + 1 end
      -- foreuse « de bord » : à moins de 4 tuiles d'une tuile de charbon (la règle a de quoi mordre)
      if #s.find_entities_filtered({ area = { { p.x - 4, p.y - 4 }, { p.x + 4, p.y + 4 } }, name = "coal" }) > 0 then near = near + 1 end
      if coal > 0 then
        log(string.format("%s foreuse MELEE en (%.1f, %.1f) : %d fer, %d charbon dans sa zone", TAG, p.x, p.y, iron, coal))
      end
    end
    log(string.format("%s foreuses a combustion posees %d, dont %d sur une zone melee, %d a moins de 4 tuiles du charbon", TAG, n, mixed, near))
    ctx.check(n >= 4, "des foreuses a combustion posees sur le fer", tostring(n))
    ctx.check(near >= 1, "des foreuses posees au bord du charbon (le banc exerce la regle)", tostring(near))
    ctx.check(mixed == 0, "aucune foreuse a combustion sur une zone melee (relu au moteur)", tostring(mixed) .. " / " .. n)
  end,
}
