-- Scénario greffé du lot RB-0 (31/10), essai E9 (suite 2) : l'araignée sans conducteur tire-t-elle dans toutes les directions ?
-- (rb0-portee : une tourelle seule à l'EST est tuée par toutes les araignées ; un anneau de tourelles à d'autres angles ne
-- l'est que pour certaines, le torse restant à 0,375 sans tourner.)
-- À LANCER SUR LA COPIE JETABLE : banc.py ... --qui RB0 -- 1000 rb0-arc <copie>
-- Une araignée SEULE par site (3, 5, 8 canon 60 ; 5l canon 100), une tourelle ennemie sans munitions à D tuiles, au relèvement
-- b = 0, 45, ..., 315 degrés (0 = nord, sens horaire), à 20 puis 45 tuiles. (Premier passage : à 30 tuiles, torse écrit ou non : mêmes zones mortes.)
local C = require("scenarios/rb0_common")

local NOMS = { "rb0-spider-3", "rb0-spider-5", "rb0-spider-8", "rb0-spider-5l" }
local X0, Y0, PAS = 15000, 15000, 110
local DISTS = { 20, 45 }
local CHECK = 700

return {
  description = "RB-0 E9 : relevement de la cible et tir d'une araignee sans conducteur",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    st.pret = false
    if not C.exige(ctx, NOMS, #NOMS .. " araignees") then return end
    local s = ctx.surface()
    C.force("rb0")
    ctx.prepare_area(X0 - 60, Y0 - 60, X0 + PAS * 16 + 60, Y0 + PAS * #NOMS + 60, "grass-1")
    C.sans_ennemis(s, X0 - 120, Y0 - 120, X0 + PAS * 16 + 120, Y0 + PAS * #NOMS + 120)
    st.sites = {}
    for i, nom in ipairs(NOMS) do
      for v = 0, 1 do -- v = indice de la distance (20 puis 45 tuiles)
        local D = DISTS[v + 1]
        for j = 0, 7 do
          local x, y = X0 + PAS * (v * 8 + j), Y0 + PAS * (i - 1)
          local sp = s.create_entity({ name = nom, position = { x, y }, force = "rb0" })
          local b = j * 45
          local tx, ty = x + D * math.sin(math.rad(b)), y - D * math.cos(math.rad(b))
          local site = { nom = nom, b = b, v = v, e = sp, d = D }
          if sp then
            sp.vehicle_automatic_targeting_parameters = { auto_target_without_gunner = true, auto_target_with_gunner = true }
            sp.get_inventory(defines.inventory.spider_ammo).insert({ name = "rb0-shell", count = 100 })
            site.o0 = sp.torso_orientation
          end
          site.cible = s.create_entity({ name = "gun-turret", position = { math.floor(tx + 0.5), math.floor(ty + 0.5) }, force = "enemy" })
          st.sites[#st.sites + 1] = site
        end
      end
    end
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    for _, site in ipairs(st.sites) do
      if not site.mort and site.cible and not site.cible.valid then site.mort = e.tick end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    for _, nom in ipairs(NOMS) do
      for v = 0, 1 do
        local l = {}
        for _, site in ipairs(st.sites) do
          if site.nom == nom and site.v == v then
            l[#l + 1] = site.b .. "=" .. (site.mort and ("@" .. site.mort) or "NON")
          end
        end
        local o = st.sites[1] and nil
        ctx.log(string.format("E9g %-14s cible a %d tuiles : %s", nom, DISTS[v + 1], table.concat(l, " ")))
      end
    end
    ctx.check(#st.sites == #NOMS * 16, "E9g sites poses", tostring(#st.sites))
  end,
}
