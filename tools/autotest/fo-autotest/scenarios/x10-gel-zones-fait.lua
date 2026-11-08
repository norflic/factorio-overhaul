--[[
  Lot X10-GEL, FAIT MOTEUR pour la mesure (4) du lead (8/11) : find_enemy_units voit-il les MÊMES ennemis que la recherche du guet
  (count_entities_filtered{type = {"unit", "character", "car", "spider-vehicle"}, force = forces ennemies}) ? Sur la sauvegarde du DC
  (x10-gel-zones), aucune zone n'avait d'ennemi : 0 contre 0 ne prouve rien. Ici, ennemis POSÉS :
    py -3.9 -B tools/autotest/banc.py --qui X10-GEL --out <archive> -- 200 x10-gel-zones-fait <source>
  Force A (la faction), forces ennemies : « enemy » (biters), B (une autre faction, unités), « player » (personnage, voiture).
  Cercle C (rayon 42) : biter à 30 tuiles, unité de B à 20, personnage à 10, voiture à 15 (dedans) ; biter à 50 (dehors).
  Boîte D (80 × 80) : biter dans un coin de la boîte (hors du cercle inscrit), biter hors de la boîte mais dans le cercle circonscrit.
  Au tick 12 (2 ticks après la pose) : comptes de la recherche actuelle (tous types, unités seules) et de find_enemy_units, par zone.
  Cessez-le-feu dans UN SEUL sens (relecture de revue-s, 8/11 : find_enemy_units est vu du côté de l'unité, « units who would be
  interested to attack » la force, la liste du guet du côté de la faction, me.is_enemy) : force C, A.set_cease_fire(C) seul (A ne tient
  plus C pour ennemie, C tient toujours A) ; force D, D.set_cease_fire(A) seul (A tient D pour ennemie, D ne tient plus A). Une unité
  de C dans le cercle E, une de D dans le cercle F : ce que voient is_enemy et find_enemy_units est RELEVÉ (fait), sans attendu écrit.
  Le mod ne pose jamais de cessez-le-feu dans un seul sens (war.lua, pvp.lua, td/director.lua : toujours les deux sens).
]]
local X0, Y0 = 7000, 3600
local A, B, C, D = "fo-gel-za", "fo-gel-zb", "fo-gel-zc", "fo-gel-zd"
local MOBILE = { "unit", "character", "car", "spider-vehicle" }

local function enemies_of(name)
  local me = game.forces[name]
  local names = {}
  for n in pairs(game.forces) do names[#names + 1] = n end
  table.sort(names)
  local out = {}
  for _, n in ipairs(names) do if n ~= name and me.is_enemy(game.forces[n]) then out[#out + 1] = n end end
  return out
end

return {
  description = "X10-GEL fait moteur : find_enemy_units contre count_entities_filtered, ennemis poses",
  check_tick = 120,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == 10 then
      ctx.prepare_area(X0 - 60, Y0 - 60, X0 + 300, Y0 + 60, "grass-1")
      for _, n in ipairs({ A, B, C, D }) do if not game.forces[n] then game.create_force(n) end end
      game.forces[A].set_cease_fire(C, true) -- un seul sens : A -> C
      game.forces[D].set_cease_fire(A, true) -- un seul sens : D -> A
      local function unit(name, force, dx, dy, ox)
        local u = s.create_entity({ name = name, position = { (ox or X0) + dx, Y0 + dy }, force = force })
        if u and u.type == "unit" then u.set_command({ type = defines.command.stop, ticks_to_wait = 600 }) end
        return u
      end
      st.made = {
        unit("small-biter", "enemy", 30, 0), unit("small-biter", B, 0, 20), unit("character", "player", -10, 0),
        unit("car", "player", 0, -15), unit("small-biter", "enemy", 50, 0),
        -- boîte D centrée en (X0 + 200, Y0), demi-côté 40 : coin (dedans), hors de la boîte mais dans le cercle circonscrit
        unit("small-biter", "enemy", 37, 37, X0 + 200), unit("small-biter", "enemy", 45, 0, X0 + 200),
        -- cercles E (C) et F (D), rayon 10, en (X0 + 100, Y0 - 30) et (X0 + 100, Y0 + 30)
        unit("small-biter", C, 3, -30, X0 + 100), unit("small-biter", D, 3, 30, X0 + 100),
      }
      local ok = 0
      for _, u in ipairs(st.made) do if u and u.valid then ok = ok + 1 end end
      ctx.check(ok == #st.made, "entites posees", ok .. " / " .. #st.made)
      ctx.log("forces ennemies de A : " .. table.concat(enemies_of(A), ", "))
    elseif e.tick == 12 then -- 2 ticks après la pose : personne n'a eu le temps de bouger (au plus 0,4 tuile)
      local en = enemies_of(A)
      local c = { x = X0, y = Y0 }
      local cnt_all = s.count_entities_filtered({ position = c, radius = 42, type = MOBILE, force = en })
      local cnt_unit = s.count_entities_filtered({ position = c, radius = 42, type = "unit", force = en })
      local found = s.find_enemy_units(c, 42, A)
      ctx.log(string.format("fait : cercle C : recherche actuelle %d (dont unites %d), find_enemy_units %d", cnt_all, cnt_unit, #found))
      ctx.check(cnt_all == 4 and cnt_unit == 2, "fait : la recherche actuelle voit 4 ennemis mobiles dans C (2 unites, un personnage, une voiture)",
        cnt_all .. " / " .. cnt_unit)
      ctx.check(#found == cnt_unit, "fait : find_enemy_units voit les memes UNITES que la recherche actuelle dans C (biters et unite d'une autre faction ; ni personnage ni voiture)",
        #found .. " / " .. cnt_unit)
      local area = { { X0 + 160, Y0 - 40 }, { X0 + 240, Y0 + 40 } }
      local box_all = s.count_entities_filtered({ area = area, type = MOBILE, force = en })
      local circ = s.find_enemy_units({ x = X0 + 200, y = Y0 }, math.sqrt(2) * 40, A)
      ctx.log(string.format("fait : boite D : recherche actuelle %d ; find_enemy_units dans le cercle circonscrit %d", box_all, #circ))
      ctx.check(box_all == 1 and #circ == 2, "fait : boite D : 1 ennemi dans la boite ; le cercle circonscrit en voit 2 (un de plus, hors de la boite)",
        box_all .. " / " .. #circ)
      -- cessez-le-feu dans un seul sens : relevé (fait), aucun attendu
      local fa, fc, fd = game.forces[A], game.forces[C], game.forces[D]
      local in_e = #s.find_enemy_units({ x = X0 + 100, y = Y0 - 30 }, 10, A)
      local in_f = #s.find_enemy_units({ x = X0 + 100, y = Y0 + 30 }, 10, A)
      local cnt_e = s.count_entities_filtered({ position = { x = X0 + 100, y = Y0 - 30 }, radius = 10, type = "unit", force = en })
      local cnt_f = s.count_entities_filtered({ position = { x = X0 + 100, y = Y0 + 30 }, radius = 10, type = "unit", force = en })
      ctx.log(string.format("FAIT cessez-le-feu un sens : C (A->C seul) : A.is_enemy(C) %s, C.is_enemy(A) %s ; cercle E : find_enemy_units %d, recherche du guet (ennemis de A) %d",
        tostring(fa.is_enemy(fc)), tostring(fc.is_enemy(fa)), in_e, cnt_e))
      ctx.log(string.format("FAIT cessez-le-feu un sens : D (D->A seul) : A.is_enemy(D) %s, D.is_enemy(A) %s ; cercle F : find_enemy_units %d, recherche du guet (ennemis de A) %d",
        tostring(fa.is_enemy(fd)), tostring(fd.is_enemy(fa)), in_f, cnt_f))
      ctx.check(true, "fait releve : cessez-le-feu dans un seul sens (voir les lignes FAIT)", string.format("E %d/%d F %d/%d", in_e, cnt_e, in_f, cnt_f))
    end
  end,
}
