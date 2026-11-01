-- Scénario greffé du lot RB-0 (31/10), essai E9 (suite) : pourquoi une grosse araignée à canon de portée 60 ne tire-t-elle
-- plus au-delà de 20 tuiles (rb0-colosse : rb0-spider-5 tue la tourelle à 20, pas celles à 40 et plus ; rb0-spider-8 aucune ;
-- rb0-spider-3 jusqu'à 62 ; rb0-spider-5l, canon 100, jusqu'à 102) ?
-- À LANCER SUR LA COPIE JETABLE : banc.py ... --qui RB0 -- 1500 rb0-portee <copie>
-- Une araignée SEULE par site, une seule tourelle ennemie sans munitions à D tuiles à l'est (D = 15, 25, 35, 45, 55, 65),
-- toutes les araignées sur leur propre site, 100 obus par script, tir automatique sans conducteur.
-- Araignées : 3 (canon 60), 4, 5, 6, 8 (canon 60), 3l (canon 100), 5g45 (canon 45), 5l (canon 100), 8l (canon 100).
-- Mesures : tick de la mort de la tourelle, orientation du torse au tick 200 et à la fin (le torse tourne à 0,005 tour/tick).
local C = require("scenarios/rb0_common")

local NOMS = { "rb0-spider-3", "rb0-spider-4", "rb0-spider-5", "rb0-spider-6", "rb0-spider-8", "rb0-spider-3l", "rb0-spider-5g45",
  "rb0-spider-5l", "rb0-spider-8l" }
local DIST = { 15, 25, 35, 45, 55, 65 }
local X0, Y0, PX, PY = 13000, 13000, 160, 40
local CHECK = 1400

return {
  description = "RB-0 E9 suite : portee de tir d'une araignee selon sa taille et son canon",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    st.pret = false
    if not C.exige(ctx, NOMS, #NOMS .. " araignees") then return end
    local s = ctx.surface()
    C.force("rb0")
    ctx.prepare_area(X0 - 40, Y0 - 40, X0 + PX * #DIST + 40, Y0 + PY * #NOMS + 40, "grass-1")
    C.sans_ennemis(s, X0 - 60, Y0 - 60, X0 + PX * #DIST + 60, Y0 + PY * #NOMS + 60)
    st.sites = {}
    for i, nom in ipairs(NOMS) do
      for j, d in ipairs(DIST) do
        local x, y = X0 + PX * (j - 1), Y0 + PY * (i - 1)
        local sp = s.create_entity({ name = nom, position = { x, y }, force = "rb0" })
        local site = { nom = nom, d = d, e = sp, x = x, y = y }
        if sp then
          sp.vehicle_automatic_targeting_parameters = { auto_target_without_gunner = true, auto_target_with_gunner = true }
          sp.get_inventory(defines.inventory.spider_ammo).insert({ name = "rb0-shell", count = 100 })
          site.o0 = sp.torso_orientation
        end
        site.cible = s.create_entity({ name = "gun-turret", position = { x + d, y }, force = "enemy" })
        st.sites[#st.sites + 1] = site
      end
    end
    -- anneaux (comme rb0-colosse) : 5 tourelles a 20, 40, 50, 58, 62 tuiles, angles 85, 122, 159, 196, 233 degres
    st.anneaux = {}
    for i, nom in ipairs({ "rb0-spider-3", "rb0-spider-5", "rb0-spider-8", "rb0-spider-5l" }) do
      local x, y = X0 + 1100 + PX * (i - 1), Y0
      ctx.prepare_area(x - 100, y - 100, x + 100, y + 100, "grass-1")
      local sp = s.create_entity({ name = nom, position = { x, y }, force = "rb0" })
      sp.vehicle_automatic_targeting_parameters = { auto_target_without_gunner = true, auto_target_with_gunner = true }
      sp.get_inventory(defines.inventory.spider_ammo).insert({ name = "rb0-shell", count = 100 })
      local a = { nom = nom, e = sp, tourelles = {} }
      for k, d in ipairs({ 20, 40, 50, 58, 62 }) do
        local ang = math.rad(37 * k + 48)
        local t = s.create_entity({ name = "gun-turret", position = { math.floor(x + d * math.cos(ang) + 0.5), math.floor(y + d * math.sin(ang) + 0.5) }, force = "enemy" })
        a.tourelles[#a.tourelles + 1] = { e = t, d = d }
      end
      st.anneaux[#st.anneaux + 1] = a
    end
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    for _, site in ipairs(st.sites) do
      if not site.mort and site.cible and not site.cible.valid then site.mort = e.tick end
      if e.tick == 200 and site.e and site.e.valid then site.o200 = site.e.torso_orientation end
    end
    for _, a in ipairs(st.anneaux or {}) do
      for _, tu in ipairs(a.tourelles) do
        if not tu.mort and tu.e and not tu.e.valid then tu.mort = e.tick end
        if (e.tick == 300 or e.tick == 800) and tu.e and tu.e.valid then tu["pv" .. e.tick] = tu.e.health end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    local par = {}
    for _, site in ipairs(st.sites) do
      par[site.nom] = par[site.nom] or {}
      par[site.nom][#par[site.nom] + 1] = site.d .. "=" .. (site.mort and ("tuee@" .. site.mort) or "NON")
      site.o_fin = site.e and site.e.valid and site.e.torso_orientation or nil
    end
    for _, nom in ipairs(NOMS) do
      local detail = {}
      for _, site in ipairs(st.sites) do
        if site.nom == nom then
          detail[#detail + 1] = string.format("%d:o0=%s,o200=%s,ofin=%s", site.d, C.fmt(site.o0, 3), C.fmt(site.o200, 3), C.fmt(site.o_fin, 3))
        end
      end
      ctx.log(string.format("E9e %-16s : %s", nom, table.concat(par[nom], " ")))
      ctx.log(string.format("E9e torse %-16s : %s", nom, table.concat(detail, " ")))
    end
    for _, a in ipairs(st.anneaux or {}) do
      local l = {}
      for _, tu in ipairs(a.tourelles) do
        l[#l + 1] = string.format("%d=%s(pv300=%s,pv800=%s)", tu.d, tu.mort and ("tuee@" .. tu.mort) or "NON", C.fmt(tu.pv300, 0), C.fmt(tu.pv800, 0))
      end
      ctx.log(string.format("E9f anneau %-14s araignee valide=%s : %s", a.nom, tostring(a.e and a.e.valid), table.concat(l, " ")))
    end
    ctx.check(#st.sites == #NOMS * #DIST, "E9e sites poses", tostring(#st.sites))
  end,
}
