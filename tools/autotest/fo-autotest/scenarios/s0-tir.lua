-- Scénario greffé du lot S0-suite (24/10) : le TIR de la mitrailleuse est-il JOUÉ en jeu, avec le son de son ère ?
--   & "<racine>\fo-autotest.bat" nopause 3000 s0-tir "<source>"     (contrôles, sans images ni son : F150)
--   $env:FO_AUDIO = '1' ; & "<racine>\fo-captures.bat" s0-tir "<source>" ; $env:FO_AUDIO = $null
--     (session AVEC images et son : pilote SDL disk, rien n'atteint la sortie du PC ; tools/autotest/README.md §1.3),
--   puis py -3.9 tools/sound/tirs_joues.py <racine>\fo-visual\audio-disk.raw <fo-shots>\factorio.log
--
-- SIX SITES à 240 tuiles l'un de l'autre (hors de portée d'écoute les uns des autres), joués l'un APRÈS l'autre, dans un
-- ordre MÊLÉ (ère III, vanilla, ère V, ère I, ère IV, ère II) : sur chacun, UNE tourelle (vanilla, niveau 1 ; ou le
-- niveau impair de l'âge 2, 5, 7, 10 ou 13 : ères I à V, ère = (âge − 1) // 3 + 1, prototypes/levels/gun.lua) face à
-- un ver géant ENNEMI 11 tuiles au nord (cessez-le-feu de l'ennemi, comme gun-rose ; ver recréé s'il meurt).
-- ÉCOUTEUR : au début de la fenêtre d'un site, le joueur (session avec images seulement : il n'y en a pas sans
-- images) est téléporté à DY_EC tuiles au SUD de la tourelle (même x : son centré entre les deux voies).
-- TIRS ISOLÉS : la tourelle ne reçoit qu'UNE cartouche à la fois (chargeur de 10 réduit à 1 : champ `ammo`), à des
-- ticks prévus (une toutes les DT ticks), et seulement quand la précédente est partie : chaque tir est un son seul,
-- séparé du suivant d'au moins une seconde. Le tick de chaque tir (la cartouche disparaît du chargeur) est écrit au
-- journal : « [FO-S0-TIR] TIR<TAB>site=..<TAB>niveau=..<TAB>ere=..<TAB>tick=.. » ; l'analyse de la sortie audio
-- (tools/sound/tirs_joues.py) retrouve chaque tir dans audio-disk.raw par filtre adapté, contre les 20 tirs du mod et
-- les 4 tirs vanilla, et vérifie l'ère et l'instant (droite tick -> temps ajustée sur les tirs).
-- Contrôles : prototypes, sites posés, nombre de tirs par site (N_TIRS, ni plus ni moins), chaque tir dans la fenêtre
-- de son site, écart entre deux tirs d'un site ; avec un joueur : écouteur placé sur chaque site.

local SITES = {
  -- ordre de passage mêlé : l'analyse ne peut pas « tomber juste » par une dérive monotone
  { niveau = 13, age = 7, ere = 3 },
  { niveau = 1, age = 1, ere = 0 }, -- mitrailleuse vanilla : son vanilla (ère 0 = vanilla)
  { niveau = 25, age = 13, ere = 5 },
  { niveau = 3, age = 2, ere = 1 },
  { niveau = 19, age = 10, ere = 4 },
  { niveau = 9, age = 5, ere = 2 },
}
local X0, Y0, PAS = 2600, -3200, 240
local DY_CIBLE, DY_EC = -11, 8
local T0, WIN, T_PREM, DT, N_TIRS = 60, 420, 40, 60, 6
local CHECK = T0 + #SITES * WIN + 60
local MUN = "firearm-magazine"

local function nom(n)
  if n == 1 then return "gun-turret" end
  return "fo-lvl-gun-" .. n
end

local function site_pos(k)
  return X0 + (k - 1) * PAS, Y0
end

local function compte(t)
  local inv = t.get_inventory(defines.inventory.turret_ammo)
  return inv and inv.get_item_count(MUN) or -1
end

return {
  description = "S0-suite : tir de la mitrailleuse joue en jeu, son de son ere (6 sites, tirs isoles, ecouteur sur le site)",
  base = nil,
  check_tick = CHECK,
  shots_delay = CHECK + 30, -- captures APRÈS le programme de tir : le marqueur de fin ne coupe pas la sortie audio

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.pret = false
    local manque = {}
    for _, c in ipairs(SITES) do
      if not game.entity_prototypes[nom(c.niveau)] then manque[#manque + 1] = nom(c.niveau) end
    end
    ctx.check(#manque == 0, "prototypes des 6 tourelles presents", #manque == 0 and "6" or table.concat(manque, ","))
    game.map_settings.enemy_expansion.enabled = false
    game.forces.player.set_cease_fire("enemy", false)
    game.forces.enemy.set_cease_fire("player", true)
    st.sites = {}
    local poses = 0
    for k, c in ipairs(SITES) do
      local x, y = site_pos(k)
      ctx.prepare_area(x - 24, y - 24, x + 24, y + 24, "grass-1")
      for _, e in ipairs(s.find_entities_filtered({ force = "enemy", area = { { x - 60, y - 60 }, { x + 60, y + 60 } } })) do
        e.destroy()
      end
      local t = s.create_entity({ name = nom(c.niveau), position = { x, y }, force = "player" })
      local site = { k = k, niveau = c.niveau, age = c.age, ere = c.ere, t = t, x = x, y = y, tirs = {}, armes = 0,
        debut = T0 + (k - 1) * WIN, fin = T0 + k * WIN }
      if t then
        poses = poses + 1
        pcall(function() t.orientation = 0 end) -- tête déjà vers le nord (la cible), F122
        site.cx, site.cy = t.position.x, t.position.y + DY_CIBLE
        site.ex, site.ey = t.position.x, t.position.y + DY_EC
      end
      st.sites[k] = site
      ctx.log(string.format("SITE\tsite=%d\tniveau=%d\tage=%d\tere=%d\tx=%.2f\ty=%.2f\tdebut=%d\tfin=%d", k, c.niveau,
        c.age, c.ere, t and t.position.x or x, t and t.position.y or y, site.debut, site.fin))
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
        -- cible : un ver ennemi au nord, recréé s'il meurt
        if site.cx and not (site.cible and site.cible.valid) then
          site.cible = s.create_entity({ name = "behemoth-worm-turret", position = { site.cx, site.cy }, force = "enemy" })
        end
        if t >= site.debut and t < site.fin then
          -- écouteur : le joueur (session avec images) sur le site, au début de sa fenêtre
          if t == site.debut then
            local p = game.connected_players[1]
            if p then
              local ok = p.teleport({ site.ex, site.ey }, s)
              st.ecoute[site.k] = ok and t or false
              ctx.log(string.format("ECOUTEUR\tsite=%d\tniveau=%d\tere=%d\ttick=%d\tx=%.2f\ty=%.2f\tok=%s", site.k,
                site.niveau, site.ere, t, site.ex, site.ey, tostring(ok)))
            end
          end
          -- tirs isolés : une cartouche à la fois, à partir du tick prévu, quand la précédente est partie
          local n = compte(tur)
          if site.arme_tick and n == 0 then
            site.tirs[#site.tirs + 1] = t
            ctx.log(string.format("TIR\tsite=%d\tniveau=%d\tere=%d\ttick=%d\tarme=%d", site.k, site.niveau, site.ere, t,
              site.arme_tick))
            site.arme_tick = nil
          end
          local prevu = site.debut + T_PREM + site.armes * DT
          if not site.arme_tick and site.armes < N_TIRS and t >= prevu and n == 0 then
            local ins = tur.insert({ name = MUN, count = 1, ammo = 1 })
            if ins == 1 then
              site.armes = site.armes + 1
              site.arme_tick = t
            end
          end
        elseif site.arme_tick and compte(tur) == 0 then
          -- tir hors fenêtre : compté (et refusé au contrôle)
          site.tirs[#site.tirs + 1] = t
          site.hors = (site.hors or 0) + 1
          ctx.log(string.format("TIR\tsite=%d\tniveau=%d\tere=%d\ttick=%d\tarme=%d\thors_fenetre=1", site.k, site.niveau,
            site.ere, t, site.arme_tick))
          site.arme_tick = nil
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    local ok_n, ok_f, ok_dt, lignes, dtmin = 0, 0, 0, {}, nil
    for _, site in ipairs(st.sites) do
      local n = #site.tirs
      if n == N_TIRS then ok_n = ok_n + 1 end
      local dedans = not site.hors
      for _, tk in ipairs(site.tirs) do
        if tk < site.debut or tk >= site.fin then dedans = false end
      end
      if dedans then ok_f = ok_f + 1 end
      local sep = true
      for i = 2, n do
        local d = site.tirs[i] - site.tirs[i - 1]
        if not dtmin or d < dtmin then dtmin = d end
        if d < DT - 10 then sep = false end
      end
      if sep then ok_dt = ok_dt + 1 end
      lignes[#lignes + 1] = string.format("site %d (niveau %d, ere %d) : %d tir(s) aux ticks %s", site.k, site.niveau,
        site.ere, n, table.concat(site.tirs, ","))
    end
    ctx.log("tirs : " .. table.concat(lignes, " ; "))
    ctx.check(ok_n == #SITES, "chaque tourelle a tire " .. N_TIRS .. " cartouches, une a la fois", ok_n .. " / " .. #SITES)
    ctx.check(ok_f == #SITES, "chaque tir dans la fenetre de son site", ok_f .. " / " .. #SITES)
    ctx.check(ok_dt == #SITES, "tirs d'un site separes d'au moins " .. (DT - 10) .. " ticks (sons isoles)",
      ok_dt .. " / " .. #SITES .. " ; ecart min " .. tostring(dtmin))
    local joueurs = #game.connected_players
    if joueurs > 0 then
      local places = 0
      for k = 1, #SITES do if st.ecoute[k] then places = places + 1 end end
      ctx.check(places == #SITES, "ecouteur (joueur) place sur chaque site au debut de sa fenetre", places .. " / " .. #SITES)
    else
      ctx.log("banc sans images : aucun joueur, ecouteur non place (seule la session avec images joue les sons, F150)")
    end
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if not st.pret then return end
    for _, site in ipairs(st.sites) do
      add(string.format("site%d-niv%02d-ere%d", site.k, site.niveau, site.ere), site.x, site.y - 4, 1, 0,
        { res = { 960, 960 } })
    end
  end,
}
