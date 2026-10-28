-- Scénario greffé du lot TIRS (27/10 ; ronde 4 du correcteur) : le TIR de chaque âge témoin se voit (bouche orientée,
-- dards, impact, trait) ; l'âge sans effet garde l'effet d'avant ; une tourelle loin de tout joueur n'est pas habillée.
--   banc.py --qui TIRS -- 1300 tirs-ages <source>                                    (contrôles, sans images)
--   banc.py --qui TIRS --captures --visuel="--no-atlas-cache --ticks 4000 --timeout 2400" -- 1300 tirs-ages <source>
--   py -3.9 -B tools/autotest/tirs_images.py <archive>\fo-shots <dossier des images>    (GIF et planches)
--
-- Sites autour de P0 (le joueur y est téléporté dans la session avec images : le filtre de proximité, 96 tuiles, les
-- laisse tous habiller), chacun UNE tourelle face à un ver géant ENNEMI (cessez-le-feu de l'ennemi, ver recréé s'il
-- meurt) et deux biters posés immobiles à côté du ver :
--   mitrailleuse des âges 1 (niveau 2), 5 (9), 8 (15, LE « niveau 15 » regardé par le DC), 10 (19), 15 (29), tir vers
--   l'EST ; âge 7 (13) : SANS effet (effet d'avant) ; âge 15 vers le nord, le sud, l'ouest et le nord-est, âge 5 vers le
--   nord (orientation de la bouche) ; tourelle laser de l'âge 15 (faisceau de l'âge) et de l'âge 8 (vanilla) ;
--   MUR : 10 mitrailleuses de l'âge 15 face à des vagues de grands biters (qui meurent) ;
--   LOIN : une mitrailleuse de l'âge 15 à 300 tuiles de P0 (avec un joueur : jamais habillée ; sans joueur : habillée).
-- Contrôles (finish) : prototypes du lot présents ; tourelles posées, chacune a tiré ; par âge témoin, événements,
-- tirs habillés (part à 5 points près hors refus de quota ou de plafond), objets de rendu dessinés (bouche, lumière),
-- entités créées (0 ratée), entités du lot VUES sur chaque site (dards, impacts, trait ; find_entities_filtered tous
-- les 2 ticks) ; site sans effet : aucune entité du lot ; site loin : aucune avec un joueur, sinon habillé ; position
-- source de l'effet = bouche de la règle F126 (journal du mod) ; laser : faisceau de l'âge vu, témoin vanilla.

local SPR_OK, SPR = pcall(require, "__factorio-overhaul__/graphics/levels/gun/sprites")

local P0 = { x = -2600, y = -2600 }
-- Grille autour de P0 (le joueur y est placé) : tout tient à moins de 96 tuiles (filtre de proximité ; 1re session de
-- la ronde 4 : une rangée à 100 tuiles, âges 1, 8 et 10 refusés « loin »). Écarts de 48 tuiles : aucune tourelle n'atteint
-- la cible d'un autre site (portée 27 au plus).
-- dir : direction du ver depuis la tourelle ; dist : distance ; (x, y) : décalage depuis P0
local SITES = {
  { cle = "a01", famille = "gun", niveau = 2, age = 1, dist = 9, dir = "E", x = -72, y = -84, serie = "pleine" },
  { cle = "a05", famille = "gun", niveau = 9, age = 5, dist = 10, dir = "E", x = -24, y = -84, serie = "pleine" },
  { cle = "a08", famille = "gun", niveau = 15, age = 8, dist = 11, dir = "E", x = 24, y = -84, serie = "pleine" },
  { cle = "a10", famille = "gun", niveau = 19, age = 10, dist = 12, dir = "E", x = 72, y = -84, serie = "pleine" },
  { cle = "a15", famille = "gun", niveau = 29, age = 15, dist = 13, dir = "E", x = -72, y = -36, serie = "pleine" },
  { cle = "a15-nord", famille = "gun", niveau = 29, age = 15, dist = 13, dir = "N", x = -24, y = -36, serie = "direction" },
  { cle = "a15-sud", famille = "gun", niveau = 29, age = 15, dist = 13, dir = "S", x = 24, y = -36, serie = "direction" },
  { cle = "a15-ouest", famille = "gun", niveau = 29, age = 15, dist = 13, dir = "O", x = 72, y = -36, serie = "direction" },
  { cle = "a15-nordest", famille = "gun", niveau = 29, age = 15, dist = 13, dir = "NE", x = -72, y = 36,
    serie = "direction" },
  { cle = "a05-nord", famille = "gun", niveau = 9, age = 5, dist = 10, dir = "N", x = -24, y = 36, serie = "direction" },
  { cle = "a07-sans-effet", famille = "gun", niveau = 13, age = 7, dist = 11, dir = "E", x = 24, y = 36,
    sans_effet = true, serie = "temoin" },
  { cle = "laser15", famille = "laser", niveau = 29, age = 15, dist = 13, dir = "E", x = 72, y = 36, serie = "pleine" },
  { cle = "laser08-temoin", famille = "laser", niveau = 15, age = 8, dist = 11, dir = "E", x = -84, y = 84, temoin = true,
    serie = "temoin" },
  { cle = "a15-loin", famille = "gun", niveau = 29, age = 15, dist = 13, dir = "E", x = 300, y = 0, loin = true,
    serie = "loin" },
}
local DIRS = { E = { 1, 0 }, O = { -1, 0 }, N = { 0, -1 }, S = { 0, 1 }, NE = { 0.7071, -0.7071 } }
-- mur : 10 mitrailleuses de l'âge 15 (6 × 6, pas de 7) au sud de P0, vagues de biters venues du sud
local MUR = { niveau = 29, n = 10, pas = 7, y = P0.y + 84, vague = 150, biters = 8, dist_vague = 30 }
local T_CIBLES, T_MUN, CHECK = 20, 30, 1200
local MUN = "firearm-magazine"
local K = 0.7071 -- F126

-- Captures (session avec images) : RAFALES, une image tous les CAD ticks ; même zoom (1) pour tous les âges, plus une
-- série au zoom 0,5 (zoom courant en défense) ; cadre centré sur le segment tourelle -> cible.
local RES = { 768, 432 }
local CAD = 2
local SERIES = {
  pleine = { { "jour", 24, 1, false }, { "nuit", 16, 1, true }, { "jour-z05", 12, 0.5, false } },
  temoin = { { "jour", 16, 1, false }, { "nuit", 8, 1, true } },
  direction = { { "jour", 16, 1, false } },
  loin = { { "jour", 8, 1, false } },
  mur = { { "jour-z05", 24, 0.5, false }, { "nuit-z05", 16, 0.5, true }, { "jour", 16, 1, false } },
}

local function nom(c) return "fo-lvl-" .. c.famille .. "-" .. c.niveau end

local function noms_du_lot(ctx)
  if not ctx.has("fo-tirs", "noms") then return {} end
  return ctx.remote("fo-tirs", "noms")
end

--- Noms d'ENTITÉS du lot pour un âge (dards, impacts, trait ; la bouche est un objet de rendu).
local function liste_noms(n)
  local l = {}
  for _, x in ipairs(n.impact) do l[#l + 1] = x end
  l[#l + 1] = n.trace
  if n.dard then l[#l + 1] = n.dard end
  if n.trait then l[#l + 1] = n.trait end
  return l
end

--- Bouche de la règle F126 pour un tir de la tourelle t vers (tx, ty) ; nil sans la feuille.
local function bouche_f126(e, px, py, tx, ty)
  local age = SPR_OK and SPR.ages and SPR.ages[e]
  if not (age and age.tir) then return nil end
  local pc, d = age.tir.projectile_center, age.tir.projectile_creation_distance
  local cx, cy = px + pc[1], py + pc[2]
  local vx, vy = tx - cx, ty - cy
  local n = math.sqrt(vx * vx + (vy / K) * (vy / K))
  if n == 0 then return cx, cy end
  return cx + d * vx / n, cy + d * vy / n
end

-- Entités du lot dont la POSITION est dans la zone : la recherche par zone rend aussi des explosions lointaines (vu au
-- 1er banc de la ronde 4 : impacts de l'âge 15 du mur comptés sur le site sans effet, à près de 30 tuiles ; boîte de
-- recherche d'une explosion plus grande que son image, cause non établie, comme F96 pour les bords).
local function dedans(en, x0, y0, x1, y1)
  local p = en.position
  return p.x >= x0 and p.x <= x1 and p.y >= y0 and p.y <= y1
end

local function vus_sur(s, st, site, x0, y0, x1, y1)
  for _, en in ipairs(s.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, name = st.tous })) do
    if dedans(en, x0, y0, x1, y1) then
      site.vus[en.name] = (site.vus[en.name] or 0) + 1
      site.n_vus = site.n_vus + 1
      if site.c.sans_effet and site.n_vus <= 6 then
        -- diagnostic : d'où vient une entité du lot vue sur le site sans effet ?
        local p = en.position
        local proches = {}
        for _, t in ipairs(s.find_entities_filtered({ type = "ammo-turret", position = p, radius = 40 })) do
          proches[#proches + 1] = string.format("%s(%.0f,%.0f)", t.name, t.position.x, t.position.y)
        end
        log(string.format("[FO-TIRS-AGES] DIAG sans effet : %s en (%.2f, %.2f) au tick %d ; tourelles a 40 tuiles : %s",
          en.name, p.x, p.y, game.tick, table.concat(proches, " ")))
      end
    else
      st.hors_zone = (st.hors_zone or 0) + 1
    end
  end
end

return {
  description = "TIRS : tir de chaque age temoin (bouche orientee, dards, impact), sans effet, loin, mur de 10 tourelles",
  base = nil,
  check_tick = CHECK,
  shots_delay = 240,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.pret = false
    game.map_settings.enemy_expansion.enabled = false
    game.forces.player.set_cease_fire("enemy", false)
    game.forces.enemy.set_cease_fire("player", true)
    local manque = {}
    for _, c in ipairs(SITES) do
      if not game.entity_prototypes[nom(c)] then manque[#manque + 1] = nom(c) end
    end
    local lot = noms_du_lot(ctx)
    st.lot, st.tous = {}, {}
    for _, a in ipairs(lot) do
      for _, n in ipairs(liste_noms(a.noms)) do
        if not game.entity_prototypes[n] then manque[#manque + 1] = n end
        st.tous[#st.tous + 1] = n
      end
      -- (les flammes sont des AnimationPrototype : l'API 1.1.91 n'en donne pas la liste ; elles sont comptées dessinées,
      -- `rendus` des compteurs du mod)
      st.lot[a.age] = liste_noms(a.noms)
    end
    table.sort(st.tous)
    if not game.entity_prototypes["fo-lvl-laser-29-faisceau"] then manque[#manque + 1] = "fo-lvl-laser-29-faisceau" end
    ctx.check(#lot == 5 and #manque == 0, "prototypes du lot presents (5 ages temoins, flammes, faisceau du laser 15)",
      #lot .. " ages ; manque : " .. (#manque == 0 and "aucun" or table.concat(manque, ",")))
    -- terrain : tout le carré des sites, le mur et ses vagues, et le site loin
    ctx.prepare_area(P0.x - 110, P0.y - 110, P0.x + 110, P0.y + 130, "grass-1")
    ctx.prepare_area(P0.x + 270, P0.y - 30, P0.x + 340, P0.y + 30, "grass-1")
    for _, e in ipairs(s.find_entities_filtered({ force = "enemy",
        area = { { P0.x - 180, P0.y - 180 }, { P0.x + 400, P0.y + 200 } } })) do
      e.destroy()
    end
    st.sites = {}
    for k, c in ipairs(SITES) do
      local x, y = P0.x + c.x, P0.y + c.y
      local t = s.create_entity({ name = nom(c), position = { x, y }, force = "player" })
      if t and c.famille == "laser" then ctx.power(x - 6, y + 6, "player") end
      local site = { k = k, c = c, t = t, x = t and t.position.x or x, y = t and t.position.y or y, vus = {}, n_vus = 0,
        faisceaux = {} }
      local d = DIRS[c.dir]
      site.cx, site.cy = site.x + c.dist * d[1], site.y + c.dist * d[2]
      if t then pcall(function() t.orientation = (c.dir == "E" and 0.25) or (c.dir == "S" and 0.5)
        or (c.dir == "O" and 0.75) or (c.dir == "NE" and 0.125) or 0 end) end
      st.sites[#st.sites + 1] = site
    end
    local poses = 0
    for _, site in ipairs(st.sites) do if site.t then poses = poses + 1 end end
    -- mur : 10 tourelles côte à côte (centre en P0.x), chargées comme les sites
    st.mur = {}
    local x0 = P0.x - (MUR.n - 1) * MUR.pas / 2
    for i = 1, MUR.n do
      local t = s.create_entity({ name = "fo-lvl-gun-" .. MUR.niveau, position = { x0 + (i - 1) * MUR.pas, MUR.y },
        force = "player" })
      if t then pcall(function() t.orientation = 0.5 end) end
      st.mur[#st.mur + 1] = t
      if t then poses = poses + 1 end
    end
    st.mur_vus, st.mur_n_vus, st.biters_tues = {}, 0, 0
    ctx.check(poses == #SITES + MUR.n, "tourelles posees (14 sites, mur de 10)", poses .. " / " .. (#SITES + MUR.n))
    st.place = false
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local s = ctx.surface()
    local t = e.tick
    -- session avec images : le joueur au centre des sites (filtre de proximité), relevé tout de suite
    if not st.place then
      local p = game.connected_players[1]
      if p then
        st.place = p.teleport({ P0.x, P0.y }, s) and t or false
        if ctx.has("fo-tirs", "releve") then ctx.remote("fo-tirs", "releve") end
        ctx.log("joueur place en P0 au tick " .. t .. " : " .. tostring(st.place))
      end
    end
    if t == T_MUN then
      for _, site in ipairs(st.sites) do
        if site.t and site.t.valid and site.c.famille == "gun" then
          site.t.insert({ name = MUN, count = 200 })
          site.mun0 = site.t.get_inventory(defines.inventory.turret_ammo).get_item_count(MUN)
        end
      end
      for _, m in ipairs(st.mur) do
        if m and m.valid then m.insert({ name = MUN, count = 200 }) end
      end
    end
    if t >= T_CIBLES then
      for _, site in ipairs(st.sites) do
        if not (site.ver and site.ver.valid) then
          site.ver = s.create_entity({ name = "behemoth-worm-turret", position = { site.cx, site.cy }, force = "enemy" })
        end
        site.biters = site.biters or {}
        local d = DIRS[site.c.dir]
        for i, off in ipairs({ -2.5, 2.5 }) do
          if not (site.biters[i] and site.biters[i].valid) then
            -- posés de part et d'autre du ver, un peu plus près de la tourelle, immobiles (la traçante garde un trajet)
            site.biters[i] = s.create_entity({ name = "big-biter", force = "enemy",
              position = { site.cx - 1.5 * d[1] - off * d[2], site.cy - 1.5 * d[2] + off * d[1] } })
            if site.biters[i] then site.biters[i].active = false end
          end
        end
      end
      -- vagues sur le mur : des grands biters partent du sud et marchent sur le mur (ils meurent sous le feu)
      if t % MUR.vague == T_CIBLES % MUR.vague then
        local x0 = P0.x - (MUR.n - 1) * MUR.pas / 2
        for i = 1, MUR.biters do
          local b = s.create_entity({ name = "big-biter", force = "enemy",
            position = { x0 + (i - 0.5) * (MUR.n - 1) * MUR.pas / MUR.biters, MUR.y + MUR.dist_vague } })
          if b then
            b.set_command({ type = defines.command.go_to_location, destination = { b.position.x, MUR.y + 4 },
              distraction = defines.distraction.none })
          end
        end
      end
    end
    -- entités du lot vues sur chaque site et sur le mur (tous les 2 ticks) ; faisceaux du laser
    if t > T_MUN and t % 2 == 0 and t < CHECK and #st.tous > 0 then
      for _, site in ipairs(st.sites) do
        local x0, x1 = math.min(site.x, site.cx) - 6, math.max(site.x, site.cx) + 6
        local y0, y1 = math.min(site.y, site.cy) - 8, math.max(site.y, site.cy) + 8
        vus_sur(s, st, site, x0, y0, x1, y1)
        if site.c.famille == "laser" then
          for _, b in ipairs(s.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, type = "beam" })) do
            site.faisceaux[b.name] = (site.faisceaux[b.name] or 0) + 1
          end
        end
      end
      local mx = (MUR.n - 1) * MUR.pas / 2 + 6
      local a = { P0.x - mx, MUR.y - 6, P0.x + mx, MUR.y + MUR.dist_vague + 4 }
      for _, en in ipairs(s.find_entities_filtered({ name = st.tous, area = { { a[1], a[2] }, { a[3], a[4] } } })) do
        if dedans(en, a[1], a[2], a[3], a[4]) then st.mur_n_vus = st.mur_n_vus + 1 end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    local avec_joueur = #game.connected_players > 0
    -- 1. chaque mitrailleuse a tiré
    local tire, l, n_gun = 0, {}, 0
    for _, site in ipairs(st.sites) do
      if site.c.famille == "gun" then
        n_gun = n_gun + 1
        local mun = site.t and site.t.valid and site.t.get_inventory(defines.inventory.turret_ammo).get_item_count(MUN)
        local conso = (site.mun0 and mun) and (site.mun0 - mun) or -1
        if conso > 0 then tire = tire + 1 end
        l[#l + 1] = site.c.cle .. ":" .. conso
      end
    end
    ctx.log("chargeurs consommes : " .. table.concat(l, " "))
    ctx.check(tire == n_gun, "chaque mitrailleuse a tire (chargeurs consommes)", tire .. " / " .. n_gun)
    -- 2. compteurs du mod, par âge témoin
    local stats = ctx.has("fo-tirs", "stats") and ctx.remote("fo-tirs", "stats") or nil
    ctx.check(stats ~= nil, "interface fo-tirs presente", stats and "oui" or "non")
    if not stats then return end
    local PART = { [1] = { 2, 5 }, [5] = { 2, 3 }, [8] = { 2, 3 }, [10] = { 2, 3 }, [15] = { 1, 1 } } -- shared/tirs/ages.lua
    local ok_evt, ok_part, ok_cree, txt = 0, 0, 0, {}
    for _, a in ipairs(stats.ages) do
      local proches = a.evts - a.loin
      local part = proches > 0 and (a.habilles + a.quota + a.plafond) / proches or 0
      local voulu = PART[a.age] and PART[a.age][1] / PART[a.age][2] or -1
      if a.evts > 0 and a.habilles > 0 then ok_evt = ok_evt + 1 end
      if math.abs(part - voulu) <= 0.05 then ok_part = ok_part + 1 end
      if a.crees > 0 and a.ratees == 0 and a.rendus > 0 then ok_cree = ok_cree + 1 end
      txt[#txt + 1] = string.format("age %d : %d evts, %d habilles, part gardee %.3f (voulu %.3f), refus loin %d part %d "
        .. "quota %d plafond %d, %d crees, %d rendus, %d ratees", a.age, a.evts, a.habilles, part, voulu, a.loin, a.part,
        a.quota, a.plafond, a.crees, a.rendus, a.ratees)
    end
    ctx.log("compteurs : " .. table.concat(txt, " ; ") .. " ; autres tireurs : " .. stats.autres .. " ; joueurs releves : "
      .. stats.joueurs)
    ctx.check(ok_evt == 5, "chaque age temoin recoit des evenements et habille des tirs", ok_evt .. " / 5")
    ctx.check(ok_part == 5, "part gardee = a / b des evenements proches (5 points)", ok_part .. " / 5")
    ctx.check(ok_cree == 5, "entites du lot creees et flammes dessinees, aucune ratee", ok_cree .. " / 5")
    ctx.check(stats.autres > 0, "l'age sans effet (7) leve des evenements sans habillage", "autres = " .. stats.autres)
    -- 3. entités du lot vues sur les sites ; aucune sur le site sans effet ; site loin selon le joueur
    local vus_ok, n_hab, sans_ok, loin_ok, v = 0, 0, true, nil, {}
    for _, site in ipairs(st.sites) do
      if site.c.famille == "gun" then
        local det, noms = {}, {}
        for n in pairs(site.vus) do noms[#noms + 1] = n end
        table.sort(noms)
        for _, n in ipairs(noms) do det[#det + 1] = n .. "=" .. site.vus[n] end
        v[#v + 1] = site.c.cle .. "[" .. table.concat(det, ",") .. "]"
        if site.c.sans_effet then
          if site.n_vus > 0 then sans_ok = false end
        elseif site.c.loin then
          loin_ok = (avec_joueur and site.n_vus == 0) or (not avec_joueur and site.n_vus > 0)
        else
          n_hab = n_hab + 1
          local tous = true
          for _, n in ipairs(st.lot[site.c.age] or {}) do if not site.vus[n] then tous = false end end
          if tous then vus_ok = vus_ok + 1 end
        end
      end
    end
    ctx.log("entites du lot vues (tous les 2 ticks) : " .. table.concat(v, " ") .. " ; mur : " .. st.mur_n_vus
      .. " ; rendues par la recherche mais posees hors de la zone (ecartees) : " .. (st.hors_zone or 0))
    ctx.check(vus_ok == n_hab, "chaque site habille : dards, impacts (et trait) vus", vus_ok .. " / " .. n_hab)
    ctx.check(sans_ok, "site sans effet (age 7, niveau 13) : aucune entite du lot", sans_ok and "0" or "vues")
    ctx.check(loin_ok == true, "site a 300 tuiles : " .. (avec_joueur and "jamais habille (joueur en P0)"
      or "habille (aucun joueur connecte : pas de filtre)"), tostring(loin_ok))
    ctx.check(st.mur_n_vus > 0, "mur de 10 tourelles de l'age 15 habille", st.mur_n_vus)
    -- 4. position source de l'effet = bouche de la règle F126 (F358), toutes directions
    local ecart_max, n_j, sans_src = 0, 0, 0
    local lignes = {}
    for _, j in ipairs(stats.journal) do
      local bx, by = bouche_f126(j.age, j.px, j.py, j.tx, j.ty)
      if j.sx == nil then
        sans_src = sans_src + 1
      elseif bx then
        local d = math.sqrt((j.sx - bx) ^ 2 + (j.sy - by) ^ 2)
        if d > ecart_max then ecart_max = d end
        n_j = n_j + 1
        if #lignes < 8 then
          lignes[#lignes + 1] = string.format("%s src(%.3f,%.3f) f126(%.3f,%.3f) tourelle(%.2f,%.2f) cible(%.2f,%.2f)",
            j.nom, j.sx, j.sy, bx, by, j.px, j.py, j.tx, j.ty)
        end
      end
    end
    ctx.log("journal (F358) : " .. table.concat(lignes, " | "))
    ctx.check(n_j > 0 and sans_src == 0 and ecart_max < 0.05,
      "position source de l'effet = bouche F126 (1/20 de tuile)",
      string.format("%d tirs, ecart max %.4f, sans position source %d", n_j, ecart_max, sans_src))
    -- 5. laser : faisceau de l'âge 15, témoin vanilla
    local fl = {}
    local laser_ok, temoin_l = false, false
    for _, site in ipairs(st.sites) do
      if site.c.famille == "laser" then
        local noms = {}
        for n in pairs(site.faisceaux) do noms[#noms + 1] = n end
        table.sort(noms)
        for _, n in ipairs(noms) do fl[#fl + 1] = site.c.cle .. ":" .. n .. "=" .. site.faisceaux[n] end
        if site.c.temoin then temoin_l = site.faisceaux["laser-beam"] ~= nil
        else laser_ok = (site.faisceaux["fo-lvl-laser-29-faisceau"] or 0) > 0 end
      end
    end
    ctx.log("faisceaux vus : " .. table.concat(fl, " "))
    ctx.check(laser_ok and temoin_l, "laser 15 : faisceau de l'age ; laser 8 : faisceau vanilla", table.concat(fl, " "))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if not st.pret then return end
    local L = { "capture\tsite\tage\tniveau\tfamille\tserie\timage\tx\ty\tzoom\tdir\tcadence" }
    local function rafales(cle, age, niveau, famille, dir, mx, my, series)
      for _, sr in ipairs(series) do
        local serie, n, zoom, nuit = sr[1], sr[2], sr[3], sr[4]
        for i = 1, n do
          local nm = string.format("%s-%s-%02d", cle, serie, i)
          add(nm, mx, my, zoom, nuit and 0.5 or 0, { res = RES, info = false, aa = false,
            cadence = (i < n) and CAD or nil })
          L[#L + 1] = string.format("%s\t%s\t%d\t%d\t%s\t%s\t%d\t%.3f\t%.3f\t%.2f\t%s\t%d", nm, cle, age, niveau, famille,
            serie, i, mx, my, zoom, dir, CAD)
        end
      end
    end
    for _, site in ipairs(st.sites) do
      local c = site.c
      rafales(c.cle, c.age, c.niveau, c.famille, c.dir, (site.x + site.cx) / 2, (site.y + site.cy) / 2 - 0.5,
        SERIES[c.serie])
    end
    rafales("mur15", 15, MUR.niveau, "gun", "S", P0.x, MUR.y + 10, SERIES.mur)
    game.write_file("fo-shots/tirs-ages-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
