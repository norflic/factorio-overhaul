--[[
  Lot PARITE (retour du DC du 2/11, point 19) : le départ de votre équipe est celui d'une faction. La guerre part SEULE (réglages de carte
  du guide : lancement automatique), SANS aucun coffre posé par le banc : le mod pose le coffre d'équipe d'office (script/faction/war.lua,
  PlayerTeam.found_default), l'équipe naît avec les 4 tourelles de QG d'une faction (shared/team/depart.lua), le coffre garni du stock de depart (lot DEFAUTS-DC).
  Contrôles : voir fo-logs/2026-11-02_PARITE/CRITERES.md, P1.1 à P1.4 (P1.5 et P1.6 : tests/parite_test.lua et parite-migration).
  Lancement : `banc.py --qui PARITE -- 1500 parite-depart <source>` ; journal : [FO-PARITE-DEPART].
]]
local TAG = "[FO-PARITE-DEPART] "
local CHECK = 1400

local function ammo_of(t)
  local inv = t.get_inventory(defines.inventory.turret_ammo)
  return inv and inv.get_item_count() or 0
end

return {
  description = "PARITE : coffre d'equipe pose d'office au lancement automatique, 4 tourelles de QG armees, coffre garni du stock de depart",
  check_tick = CHECK,

  init = function(ctx)
    local set = {
      ctx.remote("factorio-overhaul", "war_setting", "fo-war-factions", 2),
      ctx.remote("factorio-overhaul", "war_setting", "fo-war-soldiers", 30),
      ctx.remote("factorio-overhaul", "war_setting", "fo-war-workers", 4),
      ctx.remote("factorio-overhaul", "war_setting", "fo-war-autostart", true),
    }
    ctx.check(set[4] == true, "reglages de carte du guide ecrits (lancement automatique)")
    local s = ctx.surface()
    ctx.check(#s.find_entities_filtered({ name = "fo-team-chest" }) == 0, "aucun coffre d'equipe avant le lancement : le banc n'en pose pas")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    -- Le coffre apparait au lancement automatique (tick 600) : on le releve a son premier tick visible, avant tout travail.
    if not st.chest and e.tick > 0 and e.tick % 10 == 0 then
      local c = s.find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
      if c then
        st.chest, st.born = c, e.tick
        st.items_at_birth = c.get_inventory(defines.inventory.chest).get_item_count()
        ctx.log(TAG .. string.format("coffre vu au tick %d en (%.1f, %.1f), %d objet(s) dedans", e.tick, c.position.x, c.position.y, st.items_at_birth))
      end
    end
    if st.chest and not st.second and e.tick >= (st.born or 0) + 300 then
      -- Fabriquer un coffre reste possible : un second coffre pose a la main ne fonde rien et n'offre rien.
      st.turrets_before = #s.find_entities_filtered({ name = "gun-turret", force = "player" })
      local p = s.find_non_colliding_position("fo-team-chest", { x = st.chest.position.x + 12, y = st.chest.position.y + 12 }, 20, 1)
      st.second = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true }) or false
      ctx.log(TAG .. "second coffre pose a la main : " .. tostring(st.second ~= false and st.second ~= nil))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    ctx.check(st.chest ~= nil and st.born ~= nil and st.born <= 1200, "P1.1 coffre d'equipe pose d'office au plus tard au tick 1200", st.born)
    ctx.check(st.chest and st.chest.valid and st.chest.force.name == "player", "P1.1 force player")
    local turrets = s.find_entities_filtered({ name = "gun-turret", force = "player" })
    local low, near = 99999, true
    for _, t in ipairs(turrets) do
      low = math.min(low, ammo_of(t))
      local dx, dy = t.position.x - st.chest.position.x, t.position.y - st.chest.position.y
      if dx * dx + dy * dy > 16 * 16 then near = false end
    end
    ctx.check(#turrets == 4, "P1.2 exactement 4 tourelles de QG a votre equipe", #turrets)
    ctx.check(#turrets > 0 and low >= 15, "P1.2 chacune armee (au moins 15 chargeurs restants ; 20 offerts)", low)
    ctx.check(near, "P1.2 tourelles a moins de 16 tuiles du coffre")
    -- Lot DEFAUTS-DC (QCM du DC 9/11) : le coffre pose d'office est GARNI a sa naissance du stock de depart du guide (883 objets : 400 fer, 100 cuivre,
    -- 200 charbon, 100 pierre, 3 pistolets, 60 chargeurs, 8 foreuses, 8 fours, 4 coffres), une seule fois (shared/team/depart_coffre.lua).
    ctx.check(st.items_at_birth == 883, "P1.3 le coffre est garni du stock de depart a sa naissance (883 objets)", st.items_at_birth)
    local poi = ctx.call("points_of_interest")
    ctx.check(poi.player ~= nil, "P1.3 equipe du joueur active")
    local workers = #s.find_entities_filtered({ name = "fo-companion", force = "player" })
    ctx.check(workers >= 2, "P1.3 PNJ offerts a la fondation", workers)
    -- Les factions : meme nombre de tourelles de QG (parite)
    local same = 0
    for _, f in ipairs(poi.factions or {}) do
      local n = #s.find_entities_filtered({ name = "gun-turret", force = "fo-" .. f.key })
      if n >= 4 then same = same + 1 end
    end
    ctx.check(same == #(poi.factions or {}) and same >= 1, "P1.2 chaque faction vivante a au moins 4 tourelles (parite)", same)
    ctx.check(#s.find_entities_filtered({ name = "fo-team-chest", force = "player" }) == 2 and st.second ~= false,
      "P1.4 le second coffre est pose (rien ne l'empeche) ...")
    ctx.check(#turrets == (st.turrets_before or -1), "P1.4 ... mais il n'offre aucune tourelle de plus", #turrets .. " / " .. tostring(st.turrets_before))
    local team = ctx.call("team_status")
    ctx.check(team ~= nil and not team:find("aucune", 1, true), "P1.4 un seul coffre fonde l'equipe (le second ne remplace pas le premier)", team and team:sub(1, 120))
  end,
}
