-- Scénario greffé du lot TIRS (27/10) : le TIR de chaque âge témoin se voit (bouche, traçante, impact, trait) ;
-- les autres âges gardent l'effet d'avant.
--   banc.py --qui TIRS -- 1200 tirs-ages <source>                                   (contrôles, sans images)
--   banc.py --qui TIRS --captures --visuel="--no-atlas-cache" -- 1200 tirs-ages <source>   (RAFALES de captures)
--   py -3.9 tools/autotest/tirs_images.py <archive>\fo-shots <dossier des images>        (GIF et planches)
--
-- 7 sites à 160 tuiles d'écart, chacun : UNE tourelle face à un ver géant ENNEMI à l'EST (cessez-le-feu de l'ennemi,
-- comme a4-eclat ; ver recréé s'il meurt) et deux biters posés à côté du ver (recréés) :
--   mitrailleuse des âges 1 (niveau 2), 5 (9), 10 (19), 15 (29) : âges témoins de shared/tirs/ages.lua ;
--   mitrailleuse de l'âge 8 (niveau 15, celui que le DC a regardé) : TÉMOIN, effet d'avant ;
--   tourelle laser de l'âge 15 (niveau 29) alimentée : faisceau de l'âge ; tourelle laser de l'âge 8 (15) : témoin.
-- Contrôles (finish) : prototypes du lot présents ; tourelles posées, chacune a tiré ; par âge témoin, événements reçus,
-- tirs habillés (part à 5 points près de probabilite × a / b), entités créées (0 ratée), entités du lot VUES sur le
-- site (explosions, traçantes, traits, find_entities_filtered tous les 2 ticks) ; site témoin : aucune entité du lot ;
-- position source de l'effet = bouche de la règle F126 (journal du mod, feuille sprites.lua de la mitrailleuse) ;
-- laser : faisceau de l'âge vu, témoin : faisceau vanilla.

local SPR_OK, SPR = pcall(require, "__factorio-overhaul__/graphics/levels/gun/sprites")

local X0, Y0, PAS = -2600, -2600, 160
local SITES = {
  { cle = "a01", famille = "gun", niveau = 2, age = 1, dist = 9 },
  { cle = "a05", famille = "gun", niveau = 9, age = 5, dist = 10 },
  { cle = "a08-temoin", famille = "gun", niveau = 15, age = 8, dist = 11, temoin = true },
  { cle = "a10", famille = "gun", niveau = 19, age = 10, dist = 12 },
  { cle = "a15", famille = "gun", niveau = 29, age = 15, dist = 13 },
  { cle = "laser15", famille = "laser", niveau = 29, age = 15, dist = 13 },
  { cle = "laser08-temoin", famille = "laser", niveau = 15, age = 8, dist = 11, temoin = true },
}
local T_CIBLES, T_MUN, CHECK = 20, 30, 1100
local MUN = "firearm-magazine"
local K = 0.7071 -- F126

-- Captures (session avec images) : par site, une RAFALE de jour et une de nuit, une image tous les CAD ticks.
local RES = { 768, 432 }
local N_JOUR, N_NUIT, CAD = 30, 24, 2

local function nom(c) return "fo-lvl-" .. c.famille .. "-" .. c.niveau end

local function pos(k) return X0 + (k - 1) % 4 * PAS, Y0 + math.floor((k - 1) / 4) * PAS end

local function noms_du_lot(ctx)
  if not ctx.has("fo-tirs", "noms") then return {} end
  return ctx.remote("fo-tirs", "noms")
end

--- Tous les noms d'entités du lot pour un âge (bouche, impact, traçante, trait).
local function liste_noms(n)
  local l = {}
  for _, x in ipairs(n.bouche) do l[#l + 1] = x end
  for _, x in ipairs(n.impact) do l[#l + 1] = x end
  if n.trace then l[#l + 1] = n.trace end
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

return {
  description = "TIRS : tir de chaque age temoin (bouche, traçante, impact, trait), temoins de l'effet d'avant",
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
      st.lot[a.age] = liste_noms(a.noms)
    end
    table.sort(st.tous)
    if not game.entity_prototypes["fo-lvl-laser-29-faisceau"] then manque[#manque + 1] = "fo-lvl-laser-29-faisceau" end
    ctx.check(#lot == 4 and #manque == 0, "prototypes du lot presents (4 ages temoins, faisceau du laser 15)",
      #lot .. " ages ; manque : " .. (#manque == 0 and "aucun" or table.concat(manque, ",")))
    st.sites = {}
    for k, c in ipairs(SITES) do
      local x, y = pos(k)
      ctx.prepare_area(x - 30, y - 30, x + 40, y + 30, "grass-1")
      for _, e in ipairs(s.find_entities_filtered({ area = { { x - 60, y - 60 }, { x + 70, y + 60 } }, force = "enemy" })) do
        e.destroy()
      end
      local t = s.create_entity({ name = nom(c), position = { x, y }, force = "player" })
      if t and c.famille == "laser" then ctx.power(x - 6, y + 6, "player") end
      local site = { k = k, c = c, t = t, x = t and t.position.x or x, y = t and t.position.y or y, vus = {}, n_vus = 0,
        faisceaux = {} }
      site.cx, site.cy = site.x + c.dist, site.y
      st.sites[#st.sites + 1] = site
    end
    local poses = 0
    for _, site in ipairs(st.sites) do if site.t then poses = poses + 1 end end
    ctx.check(poses == #SITES, "tourelles posees (7 sites)", poses .. " / " .. #SITES)
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local s = ctx.surface()
    local t = e.tick
    if t == T_MUN then
      for _, site in ipairs(st.sites) do
        if site.t and site.t.valid and site.c.famille == "gun" then
          site.t.insert({ name = MUN, count = 200 })
          site.mun0 = site.t.get_inventory(defines.inventory.turret_ammo).get_item_count(MUN)
        end
      end
    end
    if t >= T_CIBLES then
      for _, site in ipairs(st.sites) do
        if not (site.ver and site.ver.valid) then
          site.ver = s.create_entity({ name = "behemoth-worm-turret", position = { site.cx, site.cy }, force = "enemy" })
        end
        site.biters = site.biters or {}
        for i, dy in ipairs({ -2.5, 2.5 }) do
          if not (site.biters[i] and site.biters[i].valid) then
            site.biters[i] = s.create_entity({ name = "big-biter", position = { site.cx - 1.5, site.cy + dy }, force = "enemy" })
          end
        end
      end
    end
    -- entités du lot vues sur chaque site (tous les 2 ticks) : explosions, traçantes, traits ; faisceaux du laser
    if t > T_MUN and t % 2 == 0 and t < CHECK then
      for _, site in ipairs(st.sites) do
        local area = { { site.x - 6, site.y - 8 }, { site.cx + 6, site.cy + 8 } }
        if #st.tous > 0 then
          for _, en in ipairs(s.find_entities_filtered({ area = area, name = st.tous })) do
            site.vus[en.name] = (site.vus[en.name] or 0) + 1
            site.n_vus = site.n_vus + 1
          end
        end
        if site.c.famille == "laser" then
          for _, b in ipairs(s.find_entities_filtered({ area = area, type = "beam" })) do
            site.faisceaux[b.name] = (site.faisceaux[b.name] or 0) + 1
          end
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    -- 1. chaque mitrailleuse a tiré
    local tire, l = 0, {}
    for _, site in ipairs(st.sites) do
      if site.c.famille == "gun" then
        local mun = site.t and site.t.valid and site.t.get_inventory(defines.inventory.turret_ammo).get_item_count(MUN)
        local conso = (site.mun0 and mun) and (site.mun0 - mun) or -1
        if conso > 0 then tire = tire + 1 end
        l[#l + 1] = site.c.cle .. ":" .. conso
      end
    end
    ctx.log("chargeurs consommes : " .. table.concat(l, " "))
    ctx.check(tire == 5, "chaque mitrailleuse a tire (chargeurs consommes)", tire .. " / 5")
    -- 2. compteurs du mod, par âge témoin
    local stats = ctx.has("fo-tirs", "stats") and ctx.remote("fo-tirs", "stats") or nil
    ctx.check(stats ~= nil, "interface fo-tirs presente", stats and "oui" or "non")
    if not stats then return end
    local T = { [1] = { 2, 5 }, [5] = { 1, 2 }, [10] = { 2, 3 }, [15] = { 1, 1 } } -- part de shared/tirs/ages.lua
    local ok_evt, ok_part, ok_cree, txt = 0, 0, 0, {}
    for _, a in ipairs(stats.ages) do
      local part = a.evts > 0 and a.habilles / a.evts or 0
      local voulu = T[a.age] and T[a.age][1] / T[a.age][2] or -1
      if a.evts > 0 and a.habilles > 0 then ok_evt = ok_evt + 1 end
      if math.abs(part - voulu) <= 0.05 or a.plafond > 0 then ok_part = ok_part + 1 end
      if a.crees > 0 and a.ratees == 0 then ok_cree = ok_cree + 1 end
      txt[#txt + 1] = string.format("age %d : %d evts, %d habilles (%.3f, voulu %.3f), %d plafond, %d crees, %d ratees",
        a.age, a.evts, a.habilles, part, voulu, a.plafond, a.crees, a.ratees)
    end
    ctx.log("compteurs : " .. table.concat(txt, " ; ") .. " ; autres tireurs : " .. stats.autres)
    ctx.check(ok_evt == 4, "chaque age temoin recoit des evenements et habille des tirs", ok_evt .. " / 4")
    ctx.check(ok_part == 4, "part des tirs habilles = a / b des evenements (5 points)", ok_part .. " / 4")
    ctx.check(ok_cree == 4, "entites du lot creees, aucune ratee", ok_cree .. " / 4")
    ctx.check(stats.autres > 0, "le temoin (age 8) leve des evenements sans habillage", "autres = " .. stats.autres)
    -- 3. entités du lot vues sur les sites (et aucune sur le témoin)
    local vus_ok, temoin_ok, v = 0, true, {}
    for _, site in ipairs(st.sites) do
      if site.c.famille == "gun" then
        local det = {}
        local noms = {}
        for n in pairs(site.vus) do noms[#noms + 1] = n end
        table.sort(noms)
        for _, n in ipairs(noms) do det[#det + 1] = n .. "=" .. site.vus[n] end
        v[#v + 1] = site.c.cle .. "[" .. table.concat(det, ",") .. "]"
        if site.c.temoin then
          if site.n_vus > 0 then temoin_ok = false end
        else
          -- chaque nom de l'âge vu au moins une fois
          local tous = true
          for _, n in ipairs(st.lot[site.c.age] or {}) do if not site.vus[n] then tous = false end end
          if tous then vus_ok = vus_ok + 1 end
        end
      end
    end
    ctx.log("entites du lot vues (tous les 2 ticks) : " .. table.concat(v, " "))
    ctx.check(vus_ok == 4, "chaque age temoin : bouche, impact, traçante (et trait) vus sur son site", vus_ok .. " / 4")
    ctx.check(temoin_ok, "site temoin (age 8) : aucune entite du lot", temoin_ok and "0" or "vues")
    -- 4. position source de l'effet = bouche de la règle F126 (F358)
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
    local L = { "capture\tsite\tage\tniveau\tfamille\tetat\timage\tx\ty\tzoom" }
    for _, site in ipairs(st.sites) do
      local c = site.c
      local mx = (site.x + site.cx) / 2
      local my = site.y - 1.5
      local zoom = c.niveau >= 19 and 1.25 or 1.5
      local function rafale(etat, n, nuit)
        for i = 1, n do
          local nm = string.format("%s-%s-%02d", c.cle, etat, i)
          add(nm, mx, my, zoom, nuit and 0.5 or 0, { res = RES, info = false, aa = false,
            cadence = (i < n) and CAD or nil })
          L[#L + 1] = string.format("%s\t%s\t%d\t%d\t%s\t%s\t%d\t%.3f\t%.3f\t%.2f", nm, c.cle, c.age, c.niveau, c.famille,
            etat, i, mx, my, zoom)
        end
      end
      rafale("jour", N_JOUR, false)
      rafale("nuit", N_NUIT, true)
    end
    game.write_file("fo-shots/tirs-ages-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
