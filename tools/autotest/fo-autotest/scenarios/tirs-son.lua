-- Scénario greffé du lot TIRS (27/10 ; ronde 4) : le son du tir par âge, JOUÉ en jeu (session FO_AUDIO=1, pilote
-- SDL disk : rien n'atteint la sortie du PC, interdit n° 7). Variante de s0-tir (lot S0-suite) :
--   banc.py --qui TIRS --son --captures --visuel="--ticks 6600 --timeout 2400" -- 6400 tirs-son <source>
--   puis py -3.9 -B tools/sound/tirs_couches.py <archive>\audio-disk.raw <archive>\fo-shots\factorio.log
-- SIX SITES à 240 tuiles l'un de l'autre (hors de portée d'écoute), joués l'un APRÈS l'autre dans un ordre mêlé :
-- mitrailleuse vanilla (ère 0), niveaux 2 (âge 1, S0 seul), 9 (âge 5), 15 (âge 8), 19 (âge 10), 29 (âge 15). Sur chacun,
-- UNE tourelle face à un ver géant ENNEMI 11 tuiles au nord ; le joueur (écouteur) est téléporté 8 tuiles au sud.
--   1. TIRS ISOLÉS : une cartouche à la fois, 6 tirs séparés d'une seconde (journal « TIR ») ;
--   2. RAFALE : 30 cartouches d'un coup, la tourelle tire à sa cadence (journal « RAFALE debut / fin »).
-- L'HABILLAGE du lot est ÉTEINT (fo-tirs.actif(false)) : le son entendu est celui de la TOURELLE (couches de l'âge),
-- sans le son d'impact des explosions de l'âge 15.
-- Contrôles : prototypes, sites posés, 6 tirs isolés par site dans sa fenêtre, rafale tirée (au moins 20 cartouches),
-- écouteur placé (session avec images).

local SITES = {
  { niveau = 19, age = 10, ere = 4 },
  { niveau = 1, age = 1, ere = 0 }, -- vanilla
  { niveau = 29, age = 15, ere = 5 },
  { niveau = 2, age = 1, ere = 1 },
  { niveau = 15, age = 8, ere = 3 },
  { niveau = 9, age = 5, ere = 2 },
}
local X0, Y0, PAS = 2600, -3800, 240
local DY_CIBLE, DY_EC = -11, 8
local T0, WIN, T_PREM, DT, N_TIRS = 60, 900, 40, 60, 6
local T_RAFALE, N_RAFALE = 520, 30 -- tick (dans la fenêtre) où la rafale est chargée, cartouches
local CHECK = T0 + #SITES * WIN + 60
local MUN = "firearm-magazine"

local function nom(n)
  if n == 1 then return "gun-turret" end
  return "fo-lvl-gun-" .. n
end

local function compte(t)
  local inv = t.get_inventory(defines.inventory.turret_ammo)
  if not inv then return -1 end
  -- cartouches restantes : chargeurs × 10 (le chargeur entamé compte ses cartouches)
  local n = 0
  for i = 1, #inv do
    local st = inv[i]
    if st.valid_for_read then n = n + (st.count - 1) * 10 + st.ammo end
  end
  return n
end

return {
  description = "TIRS : son du tir par age joue en jeu (tirs isoles puis rafale, 6 sites, habillage eteint)",
  base = nil,
  check_tick = CHECK,
  shots_delay = CHECK + 30,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.pret = false
    local manque = {}
    for _, c in ipairs(SITES) do
      if not game.entity_prototypes[nom(c.niveau)] then manque[#manque + 1] = nom(c.niveau) end
    end
    ctx.check(#manque == 0, "prototypes des 6 tourelles presents", #manque == 0 and "6" or table.concat(manque, ","))
    if ctx.has("fo-tirs", "actif") then ctx.remote("fo-tirs", "actif", false) end
    game.map_settings.enemy_expansion.enabled = false
    game.forces.player.set_cease_fire("enemy", false)
    game.forces.enemy.set_cease_fire("player", true)
    st.sites = {}
    local poses = 0
    for k, c in ipairs(SITES) do
      local x, y = X0 + (k - 1) * PAS, Y0
      ctx.prepare_area(x - 24, y - 24, x + 24, y + 24, "grass-1")
      for _, e in ipairs(s.find_entities_filtered({ force = "enemy", area = { { x - 60, y - 60 }, { x + 60, y + 60 } } })) do
        e.destroy()
      end
      local t = s.create_entity({ name = nom(c.niveau), position = { x, y }, force = "player" })
      local site = { k = k, niveau = c.niveau, age = c.age, ere = c.ere, t = t, x = x, y = y, tirs = {}, armes = 0,
        debut = T0 + (k - 1) * WIN, fin = T0 + k * WIN }
      if t then
        poses = poses + 1
        pcall(function() t.orientation = 0 end)
        site.cx, site.cy = t.position.x, t.position.y + DY_CIBLE
        site.ex, site.ey = t.position.x, t.position.y + DY_EC
      end
      st.sites[k] = site
      ctx.log(string.format("SITE\tsite=%d\tniveau=%d\tage=%d\tere=%d\tdebut=%d\tfin=%d", k, c.niveau, c.age, c.ere,
        site.debut, site.fin))
    end
    ctx.check(poses == #SITES, "tourelles posees", poses .. " / " .. #SITES)
    st.ecoute = {}
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local s = ctx.surface()
    local t = e.tick
    for _, site in ipairs(st.sites) do
      local tur = site.t
      if tur and tur.valid then
        if site.cx and not (site.cible and site.cible.valid) then
          site.cible = s.create_entity({ name = "behemoth-worm-turret", position = { site.cx, site.cy }, force = "enemy" })
        end
        if t >= site.debut and t < site.fin then
          if t == site.debut then
            local p = game.connected_players[1]
            if p then
              local ok = p.teleport({ site.ex, site.ey }, s)
              st.ecoute[site.k] = ok and t or false
            end
          end
          local n = compte(tur)
          local r = t - site.debut
          if r < T_RAFALE then
            -- tirs isolés (comme s0-tir)
            if site.arme_tick and n == 0 then
              site.tirs[#site.tirs + 1] = t
              ctx.log(string.format("TIR\tsite=%d\tniveau=%d\tage=%d\tere=%d\ttick=%d", site.k, site.niveau, site.age,
                site.ere, t))
              site.arme_tick = nil
            end
            local prevu = site.debut + T_PREM + site.armes * DT
            if not site.arme_tick and site.armes < N_TIRS and t >= prevu and n == 0 then
              if tur.insert({ name = MUN, count = 1, ammo = 1 }) == 1 then
                site.armes = site.armes + 1
                site.arme_tick = t
              end
            end
          elseif r == T_RAFALE then
            tur.insert({ name = MUN, count = N_RAFALE / 10 })
            site.raf_debut, site.raf_n0 = t, compte(tur)
          elseif site.raf_debut and not site.raf_fin and n == 0 then
            site.raf_fin = t
            ctx.log(string.format("RAFALE\tsite=%d\tniveau=%d\tage=%d\tere=%d\tdebut=%d\tfin=%d\tcartouches=%d", site.k,
              site.niveau, site.age, site.ere, site.raf_debut, t, site.raf_n0))
          end
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    local ok_n, ok_r, lignes = 0, 0, {}
    for _, site in ipairs(st.sites) do
      local dedans = #site.tirs == N_TIRS
      for _, tk in ipairs(site.tirs) do if tk < site.debut or tk >= site.fin then dedans = false end end
      if dedans then ok_n = ok_n + 1 end
      if site.raf_fin and (site.raf_n0 or 0) >= 20 then ok_r = ok_r + 1 end
      lignes[#lignes + 1] = string.format("site %d (niveau %d, age %d) : %d tirs isoles, rafale %s-%s (%s cartouches)",
        site.k, site.niveau, site.age, #site.tirs, tostring(site.raf_debut), tostring(site.raf_fin), tostring(site.raf_n0))
    end
    ctx.log("bilan : " .. table.concat(lignes, " ; "))
    ctx.check(ok_n == #SITES, "6 tirs isoles par site, dans sa fenetre", ok_n .. " / " .. #SITES)
    ctx.check(ok_r == #SITES, "rafale tiree sur chaque site (30 cartouches)", ok_r .. " / " .. #SITES)
    if #game.connected_players > 0 then
      local places = 0
      for k = 1, #SITES do if st.ecoute[k] then places = places + 1 end end
      ctx.check(places == #SITES, "ecouteur place sur chaque site", places .. " / " .. #SITES)
    else
      ctx.log("banc sans images : aucun joueur, ecouteur non place (seule la session avec images joue les sons, F150)")
    end
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if not st.pret then return end
    for _, site in ipairs(st.sites) do
      add(string.format("site%d-niv%02d", site.k, site.niveau), site.x, site.y - 4, 1, 0, { res = { 640, 640 } })
    end
  end,
}
