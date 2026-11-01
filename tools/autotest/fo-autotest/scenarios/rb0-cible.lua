-- Scénario greffé du lot RB-0 (31/10), essai E4 : les biters attaquent-ils une araignée et une unité à grosse boîte
-- comme un soldat ? (PLAN.md §3)
-- À LANCER SUR LA COPIE JETABLE : banc.py ... --qui RB0 -- 1500 rb0-cible <copie>
--
-- 8 sites espacés de 60 tuiles : une cible immobile (force « rb0 ») au centre ; 4 biters moyens ennemis partent 35 tuiles
-- à l'ouest et traversent vers 35 tuiles à l'est en passant à 3 tuiles de la cible (go_to_location, distraction =
-- by_enemy : ils ne s'arrêtent que pour une CIBLE MILITAIRE dans leur vision de 30 tuiles).
--   s1 unité ±0,4 (soldat de référence) ; s2 unité ±0,9 ; s3 araignée rb0-spider-1 ; s4 araignée sans cible militaire
--   (rb0-spider-1-nomt) ; s5 araignée géante rb0-spider-5 ; s6 mitrailleuse du joueur (témoin militaire connu) ;
--   s7 coffre en bois (témoin NON militaire : doit être ignoré) ; s8 araignée rb0-spider-3.
-- Mesures par site : santé perdue de la cible, distance minimale d'un biter, biters encore en route au tick de fin.
-- Aucune cible n'a de munitions ; les unités rb0 ont l'attaque de mêlée de leur modèle (medium-biter).

local C = require("scenarios/rb0_common")

local T0 = 60
local CHECK = 1400
local X0, Y0 = 5000, 5000
local SITES = {
  { id = "s1-unite04", nom = "rb0-u-04", force = "rb0" },
  { id = "s2-unite09", nom = "rb0-u-09", force = "rb0" },
  { id = "s3-spider1", nom = "rb0-spider-1", force = "rb0" },
  { id = "s4-spider1-nomt", nom = "rb0-spider-1-nomt", force = "rb0" },
  { id = "s5-spider5", nom = "rb0-spider-5", force = "rb0" },
  { id = "s6-mitrailleuse", nom = "gun-turret", force = "player" },
  { id = "s7-coffre", nom = "wooden-chest", force = "player" },
  { id = "s8-spider3", nom = "rb0-spider-3", force = "rb0" },
}

return {
  description = "RB-0 E4 : biters contre unite a grosse boite, araignee, araignee sans cible militaire",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    st.pret = false
    local noms = {}
    for _, d in ipairs(SITES) do if d.nom:sub(1, 3) == "rb0" then noms[#noms + 1] = d.nom end end
    if not C.exige(ctx, noms, #noms .. " cibles de test") then return end
    local s = ctx.surface()
    C.force("rb0")
    game.forces.player.set_cease_fire("enemy", false)
    game.forces.enemy.set_cease_fire("player", false)
    game.map_settings.enemy_expansion.enabled = false
    ctx.prepare_area(X0 - 60, Y0 - 20, X0 + 60, Y0 + 60 * #SITES, "grass-1")
    C.sans_ennemis(s, X0 - 80, Y0 - 40, X0 + 80, Y0 + 60 * #SITES + 20)
    st.sites = {}
    for i, d in ipairs(SITES) do
      local y = Y0 + 60 * (i - 1)
      local cible = s.create_entity({ name = d.nom, position = { X0, y }, force = d.force })
      local site = { id = d.id, nom = d.nom, y = y, cible = cible, biters = {}, dmin = 1e9 }
      if cible then
        site.pv_max = cible.health
        site.mil = tostring(cible.is_military_target)
      end
      for k = 1, 4 do
        local b = s.create_entity({ name = "medium-biter", position = { X0 - 35, y - 3 + k * 1.5 }, force = "enemy" })
        site.biters[#site.biters + 1] = b
      end
      st.sites[#st.sites + 1] = site
    end
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    if e.tick == T0 then
      for _, site in ipairs(st.sites) do
        for _, b in ipairs(site.biters) do
          if b.valid then
            b.set_command({ type = defines.command.go_to_location, destination = { x = X0 + 35, y = site.y + 3 }, radius = 3,
              distraction = defines.distraction.by_enemy })
          end
        end
      end
    end
    if e.tick >= T0 and e.tick % 5 == 0 then
      for _, site in ipairs(st.sites) do
        if site.cible and site.cible.valid then
          if not site.t_degat and site.cible.health < site.pv_max then site.t_degat = e.tick end
          for _, b in ipairs(site.biters) do
            if b.valid then
              local d = C.dist(b.position, site.cible.position)
              if d < site.dmin then site.dmin = d end
            end
          end
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    local par = {}
    for _, site in ipairs(st.sites) do
      local vivants, en_route = 0, 0
      for _, b in ipairs(site.biters) do
        if b.valid then
          vivants = vivants + 1
          if b.position.x < X0 + 30 then en_route = en_route + 1 end
        end
      end
      local pv = site.cible and site.cible.valid and site.cible.health or 0
      local perdu = (site.pv_max or 0) - pv
      par[site.id] = perdu
      ctx.log(string.format("E4 %-16s military=%s : PV perdus=%s sur %s ; premier degat=%s ; distance min d'un biter=%.1f ; biters vivants=%d, pas arrives a l'est=%d",
        site.id, tostring(site.mil), C.fmt(perdu, 0), C.fmt(site.pv_max, 0), tostring(site.t_degat and (site.t_degat - T0)), site.dmin, vivants, en_route))
    end
    ctx.check(par["s6-mitrailleuse"] and par["s6-mitrailleuse"] > 0, "E4 temoin : la mitrailleuse du joueur est attaquee", C.fmt(par["s6-mitrailleuse"], 0))
    ctx.check(par["s7-coffre"] == 0, "E4 temoin : le coffre n'est pas attaque (distraction by_enemy)", C.fmt(par["s7-coffre"], 0))
    ctx.check((par["s2-unite09"] or 0) > 0 and (par["s1-unite04"] or 0) > 0, "E4 une unite ±0,9 est attaquee comme une unite ±0,4",
      C.fmt(par["s2-unite09"], 0) .. " / " .. C.fmt(par["s1-unite04"], 0))
    ctx.check((par["s3-spider1"] or 0) > 0, "E4 une araignee avec cible militaire par defaut est attaquee", C.fmt(par["s3-spider1"], 0))
  end,
}
