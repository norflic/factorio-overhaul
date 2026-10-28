-- Scénario greffé du lot TIRS (28/10) : MIGRATION d'une sauvegarde 0.6.5 (sans le lot) vers le mod avec le lot, en DOUBLE
-- SOURCE : la carte est créée par la source de 0.6.5 (`git archive 2d0fbc5`), le benchmark la rejoue avec la source du lot
-- (prototypes de tourelle changés : AmmoType des chargeurs, couches de son, faisceaux, dégâts par niveau ; script nouveau :
-- espace de stockage « tirs » à créer en on_configuration_changed).
--   banc.py --qui TIRS --creation <racine>\fo-logs\2026-10-28_TIRS\src-0.6.5 -- 900 tirs-migration <source du lot>
-- init (création, SOURCE 0.6.5) : 6 mitrailleuses d'ÂGES variés (niveaux 2, 9, 15, 19, 25, 29) face à un ver géant ENNEMI à
-- 11 tuiles à l'est, chargées d'un chargeur, sans habillage ni interface « fo-tirs » (ils n'existent pas en 0.6.5).
-- tick / finish (benchmark, SOURCE du lot) : les tourelles sont toujours là, de même nom et à la même place ; l'interface
-- « fo-tirs » existe et son stockage a été créé ; le prototype de chaque niveau porte les dégâts de shared/tirs/degats.lua ;
-- chaque tourelle a tiré après le chargement (chargeurs consommés) et l'habillage a eu lieu (tirs habillés > 0) ; aucun
-- joueur connecté : pas de filtre de proximité.

local P0 = { x = -3000, y = -3000 }
local NIVEAUX = { 2, 9, 15, 19, 25, 29 }
local PAS, DIST = 40, 11
local MUN = "firearm-magazine"

return {
  description = "TIRS : migration d'une sauvegarde 0.6.5 (double source) : tourelles gardees, stockage cree, habillage actif",
  base = nil,
  check_tick = 880,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.map_settings.enemy_expansion.enabled = false
    game.forces.player.set_cease_fire("enemy", false)
    game.forces.enemy.set_cease_fire("player", true)
    ctx.prepare_area(P0.x - 20, P0.y - 20, P0.x + #NIVEAUX * PAS + 40, P0.y + 30, "grass-1")
    st.sites = {}
    for i, n in ipairs(NIVEAUX) do
      local x, y = P0.x + (i - 1) * PAS, P0.y
      local t = s.create_entity({ name = "fo-lvl-gun-" .. n, position = { x, y }, force = "player" })
      if t then
        t.insert({ name = MUN, count = 100 })
        pcall(function() t.orientation = 0.25 end)
      end
      local ver = s.create_entity({ name = "behemoth-worm-turret", position = { x + DIST, y }, force = "enemy" })
      st.sites[#st.sites + 1] = { n = n, x = t and t.position.x or x, y = t and t.position.y or y, t = t, vx = x + DIST, vy = y,
        mun0 = t and t.get_inventory(defines.inventory.turret_ammo).get_item_count(MUN) or -1, ver = ver }
    end
    local poses = 0
    for _, site in ipairs(st.sites) do if site.t then poses = poses + 1 end end
    ctx.check(poses == #NIVEAUX, "6 mitrailleuses posees a la creation (source 0.6.5)", poses .. " / " .. #NIVEAUX)
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    st.t0 = st.t0 or e.tick
    local s = ctx.surface()
    local dt = e.tick - st.t0
    if dt == 1 then
      -- la partie vient d'être rechargée avec le mod du lot : relevé de ce que le chargement a fait
      st.iface = ctx.has("fo-tirs", "stats")
      local D_ok, D = pcall(require, "__factorio-overhaul__/shared/tirs/degats")
      st.degats_ok, st.degats_vus = true, {}
      if D_ok then
        for _, site in ipairs(st.sites) do
          local p = game.entity_prototypes["fo-lvl-gun-" .. site.n]
          local dm = p and p.attack_parameters and p.attack_parameters.damage_modifier
          st.degats_vus[#st.degats_vus + 1] = string.format("%d:%s", site.n, tostring(dm))
          if not (dm and math.abs(dm - D.par_niveau[site.n]) < 1e-6) then st.degats_ok = false end
        end
      else
        st.degats_ok = false
      end
      st.vivantes = 0
      for _, site in ipairs(st.sites) do
        if site.t and site.t.valid and site.t.name == "fo-lvl-gun-" .. site.n then st.vivantes = st.vivantes + 1 end
      end
    end
    -- vers recréés s'ils meurent (cessez-le-feu : ils ne tirent pas)
    if dt >= 1 and dt % 30 == 1 then
      for _, site in ipairs(st.sites) do
        if not (site.ver and site.ver.valid) then
          site.ver = s.create_entity({ name = "behemoth-worm-turret", position = { site.vx, site.vy }, force = "enemy" })
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    ctx.check(st.iface == true, "interface fo-tirs presente apres la migration", tostring(st.iface))
    ctx.check(st.vivantes == #NIVEAUX, "les 6 tourelles de la sauvegarde sont toujours la, de meme nom", tostring(st.vivantes))
    ctx.check(st.degats_ok == true, "degats des prototypes = shared/tirs/degats.lua (D-21) apres le chargement",
      table.concat(st.degats_vus or {}, " "))
    local tire = 0
    for _, site in ipairs(st.sites) do
      if site.t and site.t.valid then
        local mun = site.t.get_inventory(defines.inventory.turret_ammo).get_item_count(MUN)
        if mun < site.mun0 then tire = tire + 1 end
      end
    end
    ctx.check(tire == #NIVEAUX, "chaque tourelle a tire apres le chargement (chargeurs consommes)", tire .. " / " .. #NIVEAUX)
    if not st.iface then return end
    local stats = ctx.remote("fo-tirs", "stats")
    local hab, evts, det = 0, 0, {}
    for _, a in ipairs(stats.ages) do
      hab, evts = hab + a.habilles, evts + a.evts
      if a.evts > 0 then det[#det + 1] = string.format("age %d:%d/%d", a.age, a.habilles, a.evts) end
    end
    ctx.log("compteurs apres migration : " .. table.concat(det, " ") .. " ; autres " .. stats.autres)
    ctx.check(evts > 0 and hab > 0, "le stockage du lot a ete cree et des tirs sont habilles apres la migration",
      string.format("%d habilles sur %d evenements", hab, evts))
    local ages_ok = 0
    for _, a in ipairs(stats.ages) do
      if (a.age == 1 or a.age == 5 or a.age == 8 or a.age == 10 or a.age == 13 or a.age == 15) and a.habilles > 0 and a.ratees == 0 then
        ages_ok = ages_ok + 1
      end
    end
    ctx.check(ages_ok == 6, "chacun des 6 ages de la sauvegarde habille des tirs, aucune entite ratee", ages_ok .. " / 6")
  end,
}
