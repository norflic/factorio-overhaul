-- Scénario greffé du lot QG-JEU (1/11) : MIGRATION d'une partie 0.6.27 (centres CARRÉS 4×4 à 8×8, épave = centre de niveau 1
-- marqué) vers les centres RECTANGLES 2 : 1 (8×4 à 16×8) et l'entité épave fo-command-wreck. Double source SEULEMENT
-- (tools/autotest/README.md §1.1) :
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui QG-JEU --creation "<racine>/fo-logs/2026-10-30_CALCUL-V2/src-0.6.27/factorio-overhaul" -- 700 qg-migration <source QG-JEU>
-- À la création (0.6.27) : une épave de centre (force qg-w, posée par l'interface fo-centre), un centre niveau 9 (6×6) avec
-- 77 plaques de fer (qg-c9), un centre niveau 1 (4×4) avec 55 charbons (qg-c1), un centre niveau 1 cerné par deux colonnes
-- de murs (qg-cd : aucune position libre pour 8×4, il reste en place). Au chargement par QG-JEU : on_configuration_changed →
-- emprises relevées (Levels.migrate_footprints), épave convertie (script/levels/centre.lua).

local LV = require("__factorio-overhaul__/shared/levels/config")
local CC = LV.by_key.command

local X, Y = 9800, 9800
local CAS = {
  { id = "qg-c9", name = "fo-lvl-command-9", dx = 0, dy = 0, plates = 77 },
  { id = "qg-c1", name = "fo-command-center", dx = 30, dy = 0, coal = 55 },
  { id = "qg-cd", name = "fo-command-center", dx = 60, dy = 0, murs = true },
}

local function trouver(s, force, noms)
  return s.find_entities_filtered({ force = force, name = noms })[1]
end

return {
  description = "QG-JEU : migration d'une partie 0.6.27 (centres carres, epave = niveau 1) vers les centres 2:1 et l'entite epave",
  base = nil,
  check_tick = 120,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(X - 20, Y - 20, X + 90, Y + 20, "grass-1")
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    local ok_old = game.entity_prototypes["fo-command-wreck"] == nil
    ctx.check(ok_old, "carte creee par 0.6.27 (pas d'entite fo-command-wreck)", tostring(not ok_old))
    st.cas, st.pos = {}, {}
    local bad = {}
    for _, c in ipairs(CAS) do
      local f = game.forces[c.id] or game.create_force(c.id)
      local px, py = X + c.dx, Y + c.dy
      local e = s.create_entity({ name = c.name, position = { px, py }, force = f, raise_built = true })
      if not (e and e.valid) then
        bad[#bad + 1] = c.id
      else
        local inv = e.get_inventory(defines.inventory.chest)
        if c.plates then inv.insert({ name = "iron-plate", count = c.plates }) end
        if c.coal then inv.insert({ name = "coal", count = c.coal }) end
        if c.murs then
          for _, wx in ipairs({ px - 2 - 0.5, px + 2 + 0.5 }) do
            for wy = py - 2, py + 1 do s.create_entity({ name = "stone-wall", position = { wx, wy + 0.5 }, force = "player" }) end
          end
        end
        st.pos[c.id] = { x = px, y = py }
        local sb = e.prototype.selection_box
        ctx.log(string.format("CREATION %s : %s en (%.1f, %.1f), selection %.1f x %.1f, niveau %s", c.id, e.name, px, py,
          sb.right_bottom.x - sb.left_top.x, sb.right_bottom.y - sb.left_top.y, tostring(ctx.call("levels_status", c.id).cc_level)))
      end
    end
    -- épave : posée par l'interface du centre (0.6.27 : un centre de niveau 1 marqué épave)
    local fw = game.forces["qg-w"] or game.create_force("qg-w")
    local okw = remote.call("fo-centre", "place_wreck", "qg-w", X + 90 - 8, Y)
    local w = trouver(s, "qg-w", { "fo-command-center" })
    st.pos["qg-w"] = w and { x = w.position.x, y = w.position.y } or nil
    ctx.check(okw and w and remote.call("fo-centre", "status", "qg-w").wreck == true and #bad == 0,
      "partie 0.6.27 : epave posee (centre niveau 1 marque), centres 9 et 1 poses, centre 1 cerne de murs", tostring(okw) .. " " .. table.concat(bad, ","))
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local w = game.entity_prototypes["fo-command-wreck"]
    ctx.check(w ~= nil, "partie rechargee par QG-JEU (entite fo-command-wreck)")
    local stats = ctx.call("levels_status", "player")
    ctx.log("STATS " .. serpent.line({ migrated = stats.migrated, overlap_kept = stats.overlap_kept, footprints_stale = stats.footprints_stale }))
    -- Centres 9 et 1 : 2 « deja en place » (le plus centre est libre : position inchangee, rien de repose) ; l'epave, posee hors
    -- grille par find_non_colliding_position, est la seule reposee ; le centre cerne est laisse (compte a part).
    ctx.check(stats.footprints_stale == false and (stats.migrated or 0) >= 1,
      "emprises migrees (releve a jour ; centres 9 et 1 deja en place, epave remise sur la grille)", serpent.line({ migrated = stats.migrated, stale = stats.footprints_stale }))
    -- centre 9 : 12 x 6, au centre de son ancien carre, coffre garde
    local e9 = trouver(s, "qg-c9", { "fo-lvl-command-9" })
    local p9 = st.pos["qg-c9"]
    local sb9 = e9 and e9.prototype.selection_box
    ctx.check(e9 and sb9 and math.abs(sb9.right_bottom.x - sb9.left_top.x - 12) < 1e-6 and math.abs(sb9.right_bottom.y - sb9.left_top.y - 6) < 1e-6
      and math.abs(e9.position.x - p9.x) < 0.01 and math.abs(e9.position.y - p9.y) < 0.01
      and e9.get_inventory(defines.inventory.chest).get_item_count("iron-plate") == 77 and ctx.call("levels_status", "qg-c9").cc_level == 9,
      "centre 9 : 6x6 -> 12x6 sur place, 77 plaques gardees, toujours le centre de son equipe (niveau 9)",
      e9 and string.format("(%.1f, %.1f)", e9.position.x, e9.position.y) or "absent")
    -- centre 1 : 8 x 4, charbon gardé
    local e1 = trouver(s, "qg-c1", { "fo-command-center" })
    local p1 = st.pos["qg-c1"]
    local sb1 = e1 and e1.prototype.selection_box
    ctx.check(e1 and sb1 and math.abs(sb1.right_bottom.x - sb1.left_top.x - 8) < 1e-6 and math.abs(sb1.right_bottom.y - sb1.left_top.y - 4) < 1e-6
      and math.abs(e1.position.x - p1.x) < 0.01 and math.abs(e1.position.y - p1.y) < 0.01
      and e1.get_inventory(defines.inventory.chest).get_item_count("coal") == 55 and ctx.call("levels_status", "qg-c1").cc_level == 1,
      "centre 1 : 4x4 -> 8x4 sur place, 55 charbons gardes, niveau 1", e1 and string.format("(%.1f, %.1f)", e1.position.x, e1.position.y) or "absent")
    -- centre cerné : reste en place (chevauchement toléré), toujours le centre de son équipe
    local ed = trouver(s, "qg-cd", { "fo-command-center" })
    local pd = st.pos["qg-cd"]
    ctx.check(ed and math.abs(ed.position.x - pd.x) < 0.01 and math.abs(ed.position.y - pd.y) < 0.01 and ctx.call("levels_status", "qg-cd").cc_level == 1
      and (stats.overlap_kept or 0) >= 1,
      "centre cerne de murs : laisse en place faute de place (chevauchement tolere, compte), toujours le centre de son equipe",
      ed and string.format("(%.1f, %.1f) kept %s", ed.position.x, ed.position.y, tostring(stats.overlap_kept)) or "absent")
    -- épave : devenue l'entité épave, même place, toujours épave (niveau effectif 0)
    local ew = trouver(s, "qg-w", { "fo-command-wreck" })
    local pw = st.pos["qg-w"]
    local stw = remote.call("fo-centre", "status", "qg-w")
    ctx.check(ew and pw and math.abs(ew.position.x - pw.x) <= 4 and math.abs(ew.position.y - pw.y) <= 1 and stw.wreck == true
      and ctx.call("levels_status", "qg-w").cc_level == 0 and trouver(s, "qg-w", { "fo-command-center" }) == nil,
      "epave : devenue fo-command-wreck (remise sur la grille 8x4, a 4 tuiles au plus), toujours epave (niveau effectif 0), plus de centre 1 fantome",
      ew and string.format("(%.1f, %.1f) epave %s", ew.position.x, ew.position.y, tostring(stw.wreck)) or "absente")
    -- l'épave convertie se remplace par le niveau 1 (réparation sans joueur : banc)
    local nw = ew and ctx.call("levels_swap", ew, LV.name(CC, 1))
    ctx.check(nw and nw.valid and nw.name == LV.name(CC, 1), "epave convertie -> centre niveau 1 sur place (remplacement moteur reel)",
      nw and nw.valid and nw.name or "pas de nouvelle entite")
  end,
}
