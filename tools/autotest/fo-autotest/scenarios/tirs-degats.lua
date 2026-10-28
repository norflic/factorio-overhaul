-- Scénario greffé du lot TIRS (28/10) : K9, la PUISSANCE de feu RÉELLE de chaque niveau de tourelle, mesurée contre une
-- cible fixe (décision D-21 du DC : « Aussi les dégâts » ; courbe C2 de shared/tirs/degats.lua).
--   banc.py --qui TIRS -- 800 tirs-degats <source>
--
-- 60 sites : la mitrailleuse (chargeur de base, 5 dégâts physiques) et la tourelle laser des 30 NIVEAUX (niveau 1 = la
-- tourelle vanilla), chacun UNE tourelle face à une cible fixe : une tourelle (mitrailleuse) de la force ennemie, SANS
-- résistance (vérifié sur data/base), inactive (elle ne tire pas) et que le script SOIGNE à chaque tick. La mesure
-- est la perte de santé entre deux appels du script, soignée aussitôt : chaque dégât reçu est compté une fois, sans
-- événement (le banc n'en abonne pas). Fenêtre : 300 ticks pour les mitrailleuses (50 tirs au tir le plus lent), 600
-- ticks pour les lasers (15 tirs), après un temps de mise en place (lancement de la tourelle, rotation).
-- Contrôles (finish) :
--   1. les 60 sites sont posés et chaque tourelle a infligé des dégâts ;
--   2. mitrailleuse niveau 1 : 45 à 55 dégâts par seconde (10 tirs par seconde × 5 : valeur vanilla, absolue) ;
--   3. rapport DPS(n) / DPS(1) = table du niveau (shared/tirs/degats.lua) à 4 % près, mitrailleuse ET laser ;
--   4. DPS strictement croissant d'un niveau au suivant (K9), puis d'un âge au suivant ;
--   5. d'un âge au suivant (niveau 2e contre niveau 2e - 2), de l'âge 4 à l'âge 15 : × 1,2 à 4 % près ;
--   6. niveau 30 : au moins 12 fois le niveau 1 (D-21 : × 12,48).
-- Journal [FO-TIRS-DEGATS] : une ligne DPS par niveau et par famille (tabulation) pour tools/autotest/tirs_degats.py.

local L = require("__factorio-overhaul__/shared/levels/config")
local D = require("__factorio-overhaul__/shared/tirs/degats")

local P0 = { x = -3400, y = -3400 }
local COLS, PAS_X, PAS_Y, DIST = 3, 44, 34, 8
local T_PRET, T_MUN = 30, 30
local DEBUT, FIN_GUN, FIN_LASER = 150, 450, 750
local MUN = "firearm-magazine"
local FAM = { "gun", "laser" }

local function nom(fam, n)
  return L.name(L.by_key[fam], n)
end

return {
  description = "TIRS : K9, DPS reel de chaque niveau de mitrailleuse et de laser contre une cible fixe soignee",
  base = nil,
  check_tick = FIN_LASER + 10,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.map_settings.enemy_expansion.enabled = false
    game.forces.player.set_cease_fire("enemy", false)
    game.forces.enemy.set_cease_fire("player", true)
    local manque = {}
    for _, fam in ipairs(FAM) do
      for n = 1, 30 do if not game.entity_prototypes[nom(fam, n)] then manque[#manque + 1] = nom(fam, n) end end
    end
    ctx.check(#manque == 0, "60 prototypes de tourelle (30 niveaux de mitrailleuse et de laser)",
      #manque == 0 and "aucun manque" or table.concat(manque, ","))
    ctx.prepare_area(P0.x - 30, P0.y - 30, P0.x + 2 * 180 + 30 + COLS * PAS_X, P0.y + 10 * PAS_Y + 30, "grass-1")
    st.sites = {}
    for k, fam in ipairs(FAM) do
      for n = 1, 30 do
        local i = n - 1
        local col, row = i % COLS, math.floor(i / COLS)
        local x, y = P0.x + (k - 1) * 180 + col * PAS_X, P0.y + row * PAS_Y
        local t = s.create_entity({ name = nom(fam, n), position = { x, y }, force = "player" })
        if t and fam == "laser" then ctx.power(x - 6, y + 6, "player") end
        local cible
        if t then
          cible = s.create_entity({ name = "gun-turret", position = { t.position.x + DIST, t.position.y }, force = "enemy" })
          if cible then cible.active = false end
          pcall(function() t.orientation = 0.25 end)
        end
        st.sites[#st.sites + 1] = { fam = fam, n = n, t = t, cible = cible, perdu = 0, coups = 0 }
      end
    end
    local poses = 0
    for _, site in ipairs(st.sites) do if site.t and site.cible then poses = poses + 1 end end
    ctx.check(poses == #st.sites, "60 tourelles posees, chacune face a sa cible", poses .. " / " .. #st.sites)
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local t = e.tick
    if t == T_MUN then
      for _, site in ipairs(st.sites) do
        if site.fam == "gun" and site.t and site.t.valid then site.t.insert({ name = MUN, count = 200 }) end
      end
    end
    if t < DEBUT - 1 then return end
    for _, site in ipairs(st.sites) do
      local c = site.cible
      if c and c.valid then
        local pv = c.prototype.max_health
        local fin = site.fam == "gun" and FIN_GUN or FIN_LASER
        if t >= DEBUT and t < fin then
          local perte = pv - c.health
          if perte > 0 then
            site.perdu = site.perdu + perte
            site.coups = site.coups + 1
          end
        end
        c.health = pv -- soignée : la cible ne meurt jamais, chaque dégât est compté une fois
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    local dps = { gun = {}, laser = {} }
    local lignes = { "famille\tniveau\tage\tdegats\tcoups\tdps\trapport\ttable" }
    local tous = 0
    for _, site in ipairs(st.sites) do
      local fenetre = (site.fam == "gun" and (FIN_GUN - DEBUT) or (FIN_LASER - DEBUT)) / 60
      dps[site.fam][site.n] = site.perdu / fenetre
      if site.perdu > 0 then tous = tous + 1 end
    end
    for _, fam in ipairs(FAM) do
      for n = 1, 30 do
        local site
        for _, x in ipairs(st.sites) do if x.fam == fam and x.n == n then site = x end end
        lignes[#lignes + 1] = string.format("%s\t%d\t%d\t%.1f\t%d\t%.2f\t%.4f\t%.2f", fam, n, math.ceil(n / 2),
          site.perdu, site.coups, dps[fam][n], dps[fam][1] > 0 and dps[fam][n] / dps[fam][1] or 0, D.par_niveau[n])
      end
    end
    ctx.log("TIRS-DEGATS-TABLE\n" .. table.concat(lignes, "\n"))
    ctx.check(tous == #st.sites, "chaque tourelle a inflige des degats a sa cible", tous .. " / " .. #st.sites)
    local g1 = dps.gun[1]
    ctx.check(g1 >= 45 and g1 <= 55, "mitrailleuse niveau 1 : 45 a 55 degats par seconde (10 tirs x 5)",
      string.format("%.2f", g1))
    for _, fam in ipairs(FAM) do
      local d = dps[fam]
      local ecart, croit, age_ok, age_det = 0, true, true, {}
      for n = 1, 30 do
        if d[1] > 0 then ecart = math.max(ecart, math.abs(d[n] / d[1] / D.par_niveau[n] - 1)) end
        if n > 1 and not (d[n] > d[n - 1]) then croit = false end
      end
      for e = 4, 15 do
        local r = d[2 * e] / d[2 * e - 2]
        if math.abs(r / 1.2 - 1) > 0.04 then age_ok = false end
        age_det[#age_det + 1] = string.format("%d:%.3f", e, r)
      end
      ctx.check(ecart <= 0.04, fam .. " : rapport DPS(n) / DPS(1) = table du niveau, a 4 % pres",
        string.format("ecart max %.2f %%", 100 * ecart))
      ctx.check(croit, fam .. " : DPS strictement croissant d'un niveau au suivant (K9)", croit and "oui" or "non")
      ctx.check(age_ok, fam .. " : DPS x 1,2 d'un age au suivant (ages 4 a 15, 4 % pres)", table.concat(age_det, " "))
      ctx.check(d[1] > 0 and d[30] >= 12 * d[1], fam .. " : niveau 30 >= 12 fois le niveau 1 (D-21 : x 12,48)",
        string.format("x %.2f", d[1] > 0 and d[30] / d[1] or 0))
    end
  end,
}
