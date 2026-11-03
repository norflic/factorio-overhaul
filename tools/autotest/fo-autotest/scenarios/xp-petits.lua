-- Lot EXPERIMENTAUX (3/11), palier 1, 2 500 ticks, sans images : les 5 petits en moteur réel.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui EXPERIMENTAUX -- 2500 xp-petits <source>
-- Pour chacun : (a) la technologie débloque la recette, l'usine de robots de son âge FABRIQUE l'objet (products_finished) ;
-- (b) posé (tourelles, create_entity raise_built) ou lancé (interface « fo-xp », même chemin que la capsule) il inflige des dégâts réels à des
-- cibles hostiles (comptes du script ET perte de PV relevée ici), jamais à un témoin de la force du joueur placé DANS la zone de l'effet ;
-- Mât-Foudre : l'arc saute ; Sarracénie : 3 jets par crachat ; Demi-Vie : une seule fusion, l'unité disparaît, la zone contaminée pique
-- une cible posée APRÈS la fusion. Journal [FO-XP] ouvert. Le banc crée puis rejoue la carte : preuve de relecture.
local C = require("scenarios/xp_commun")

local CHECK = 2450
local LANCE = 60

local function stats() return remote.call("fo-xp", "stats") end

local function perte(list)
  local p = 0
  for _, e in ipairs(list) do
    if e.valid then p = p + (e.prototype.max_health - e.health) else p = p + 400 end
  end
  return p
end

return {
  description = "EXPERIMENTAUX : les 5 petits, fabrication, effets, forces epargnees",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    C.forces()
    remote.call("fo-xp", "journal", true)
    local s = ctx.surface()
    st.sites = {}
    for i, id in ipairs(C.IDS) do
      local x = C.x(i)
      local src = C.terrain(ctx, x)
      local site = { id = id, x = x }
      site.power = src ~= nil
      local d = C.DIST[id]
      site.cibles = C.cibles(s, x + d, C.Y, 3, 3)
      if id == "geode" then
        -- un mur hostile entre la Géode et ses cibles : les pointes le traversent
        site.mur = {}
        for y = C.Y - 6, C.Y + 6 do
          local w = s.create_entity({ name = "stone-wall", position = { x + d - 7 + 0.5, y + 0.5 }, force = C.CIBLE })
          if w then site.mur[#site.mur + 1] = w end
        end
      end
      -- témoin du joueur dans la zone de l'effet (2 tuiles des cibles ; Géode : sur le chemin des pointes)
      site.temoin = C.temoin(s, x + d - (id == "geode" and 12 or 0), C.Y + (id == "geode" and 3 or 7))
      if id ~= "geode" and id ~= "demi-vie" then
        site.robot = s.create_entity({ name = "fo-xp-" .. id, position = { x, C.Y }, force = "player", raise_built = true })
        ctx.check(site.robot ~= nil, id .. " : pose", site.robot and site.robot.name or "refusee")
      end
      site.usine = C.usine(ctx, id, x + 20, C.Y + 45)
      ctx.check(site.usine.rec and site.usine.rec.enabled == true, id .. " : la technologie debloque la recette",
        site.usine.tech and site.usine.tech.name or "technologie absente")
      ctx.log(string.format("%s : usine %s, ingredients inseres %s", id, C.USINE[id], table.concat(site.usine.inserted, ", ")))
      st.sites[#st.sites + 1] = site
    end
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if t == LANCE then
      for _, site in ipairs(st.sites) do
        if site.id == "geode" or site.id == "demi-vie" then
          local un = remote.call("fo-xp", "lancer", site.id, "player", site.x, C.Y)
          ctx.check(un ~= nil, site.id .. " : lancee (meme chemin que la capsule)", tostring(un))
          site.un = un
        end
      end
    end
    -- Demi-Vie : suivre l'unité ; après la fusion, une cible neuve dans la zone
    for _, site in ipairs(st.sites) do
      if site.id == "demi-vie" and site.un and not site.fusion then
        local u = ctx.surface().find_entities_filtered({ name = "fo-xp-demi-vie", position = { site.x, C.Y }, radius = 80 })[1]
        if u then site.pos = { u.position.x, u.position.y } end
        local sd = stats()["demi-vie"]
        if sd.coups >= 1 then
          site.fusion = t
          site.zones = remote.call("fo-xp", "zones")
          ctx.log(string.format("demi-vie : fusion au tick %d pres de (%.1f, %.1f)", t, site.pos and site.pos[1] or 0, site.pos and site.pos[2] or 0))
        end
      end
      if site.id == "demi-vie" and site.fusion and t == site.fusion + 60 and site.pos then
        site.apres = ctx.surface().create_entity({ name = "gun-turret", position = { site.pos[1] + 4, site.pos[2] }, force = C.CIBLE })
        site.degats_avant = stats()["demi-vie"].degats
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local all = stats()
    for _, site in ipairs(st.sites) do
      local id = site.id
      local sx = all[id]
      local u = site.usine
      ctx.check(u.m and u.m.valid and u.m.products_finished >= 1, id .. " : fabrique par l'usine de son age (" .. C.USINE[id] .. ")",
        string.format("produits %s, sortie %d", u.m and u.m.valid and tostring(u.m.products_finished) or "?",
          u.m and u.m.valid and u.m.get_output_inventory().get_item_count("fo-xp-" .. id) or -1))
      local p = perte(site.cibles)
      ctx.check(sx.coups >= 1 and sx.degats > 0 and p > 0, id .. " : degats reels sur les cibles",
        string.format("coups %d, degats du script %.0f, cibles %d, tues %d, PV perdus par les cibles %.0f", sx.coups, sx.degats, sx.cibles, sx.tues, p))
      local tm = site.temoin
      ctx.check(tm and tm.valid and tm.health == tm.prototype.max_health, id .. " : temoin du joueur intact dans la zone",
        tm and tm.valid and string.format("%.0f / %.0f", tm.health, tm.prototype.max_health) or "detruit")
      if id == "mat-foudre" then
        ctx.check(site.power and sx.sauts >= 1, "mat-foudre : l'arc saute d'une cible a l'autre", string.format("sauts %d en %d coups", sx.sauts, sx.coups))
      elseif id == "sarracenie" then
        ctx.check(sx.jets >= 3 and sx.jets >= 2 * sx.coups, "sarracenie : trois jets par crachat", string.format("jets %d, crachats %d", sx.jets, sx.coups))
      elseif id == "geode" then
        local mur = perte(site.mur)
        ctx.check(mur > 0, "geode : les pointes entament le mur hostile", string.format("PV perdus par le mur %.0f", mur))
      elseif id == "demi-vie" then
        local vivante = ctx.surface().count_entities_filtered({ name = "fo-xp-demi-vie" })
        ctx.check(sx.coups == 1 and vivante == 0, "demi-vie : usage unique (une fusion, plus d'unite)", string.format("fusions %d, unites %d", sx.coups, vivante))
        ctx.check(site.zones == 1, "demi-vie : une zone contaminee", tostring(site.zones))
        local apres = site.degats_avant and (sx.degats - site.degats_avant) or 0
        ctx.check(apres > 0, "demi-vie : la zone pique une cible posee apres la fusion", string.format("%.0f", apres))
      end
    end
  end,
}
