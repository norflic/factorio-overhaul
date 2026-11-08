--[[
  Lot X10-GEL, plantage C19 (8/11) : sur la sauvegarde du DC, un four du QG relevé SOURCE VIDE recevait la recette fictive « ? » ; figé,
  son premier pas lisait get_item_count("?") et le moteur arrêtait la partie (« Unknown item name: ? », gel_usines_jeu.lua:111 frontier,
  :215 step, :494 each_tick ; archive fo-logs/2026-11-07_X10/c19-ff5e9d8b). Correctif : un four n'est relevé qu'avec une recette connue
  (refus « recette »), et la garde ensuite (plus aucun nom fictif).
    py -3.9 -B tools/autotest/banc.py --qui X10-GEL-V --out <archive> -- 2000 x10-gel-four-vide <source>

  Fours du QG d'un GROUPE DE BANC (interface « fo-gel », même relevé que les factions : Gu.discover_four ; même pas : step, frontier),
  joueurs du groupe : aucun (loin), puis un joueur posé tout près :
    V0 : four, charbon, source VIDE : refus « recette » au relevé (le cas du DC) ;
    V1 : four, 30 minerais de fer : relevé, figé ; au tick 700, sa source est VIDÉE par script pendant le gel ;
    V2 : idem ; au tick 700, sa source passe à 10 minerais de CUIVRE alors que sa sortie tient des plaques de fer : recette changée
         pendant le gel, sortie occupée (le moteur ne fabrique rien), aucun nom inventé ;
    V3 : idem, intact : témoin positif (le pas tourne et fabrique pendant le gel).
  Fait relevé au tick 700 (premier passage, 7 h 39 : un four refuse le bois dans sa source) : insert de 5 bois dans la source vide de
  V0, rendu journalisé ; un objet sans recette de four n'entre pas dans une source, le seul cas « recette inconnue » du jeu est la
  source VIDE.
  Pas d'un îlot figé au tick t tel que t % 1200 = id % 1200 (Gu.STEP) ; T = le dernier des trois après 700. Au tick T + 5 : V1 et V2 ont
  reçu leur pas (statuts comptables « no_ingredients » et « full_output »), rien fabriqué ni consommé ; V3 a fabriqué. Au tick T + 20 : un joueur près des
  fours, réveil au guet suivant, pas dû payé (contrôle à T + 60). Le bilan (tick 1900) n'arrive que si la partie tourne encore : sans le
  correctif, elle s'arrête au premier pas de V1.
]]

local X0, Y0 = 6400, 3400
local FORCE = "fo-gel-v"

local function furnace(s, i, ore)
  local q = s.create_entity({ name = "stone-furnace", position = { X0 + 6 * i, Y0 }, force = FORCE })
  q.get_fuel_inventory().insert({ name = "coal", count = 10 })
  if ore then q.get_inventory(defines.inventory.furnace_source).insert({ name = "iron-ore", count = ore }) end
  return q
end

local function count(q, inv, name)
  local i = q.get_inventory(inv)
  return i and i.get_item_count(name) or 0
end

return {
  description = "X10-GEL : four du QG source vide (plantage C19) : refuse au releve, fige puis vide ou garni d'un objet sans recette",
  check_tick = 1900,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    local t = e.tick
    if t == 10 then
      ctx.prepare_area(X0 - 6, Y0 - 6, X0 + 30, Y0 + 6, "grass-1")
      if not game.forces[FORCE] then game.create_force(FORCE) end
      game.forces[FORCE].set_cease_fire("enemy", true)
      game.forces.enemy.set_cease_fire(FORCE, true)
      ctx.remote("fo-gel", "banc", "V", FORCE)
      ctx.remote("fo-gel", "joueurs", "V", {})
      st.q = { furnace(s, 0, nil), furnace(s, 1, 30), furnace(s, 2, 30), furnace(s, 3, 30) }
      local r0 = ctx.remote("fo-gel", "adopte", "V", st.q[1])
      ctx.check(r0 and r0.why == "recette", "V0 : four du QG source vide : refuse « recette » au releve (cas de la sauvegarde du DC)",
        tostring(r0 and (r0.id or r0.why)))
      local ok = 0
      st.tstep = 0
      for i = 2, 4 do
        local r = ctx.remote("fo-gel", "adopte", "V", st.q[i])
        if r and r.id then
          ok = ok + 1
          -- pas d'un îlot figé : au tick t tel que t % STEP = id % STEP ; le premier après 700
          local slot = r.id % 1200
          local tt = slot > 700 and slot or (slot + 1200)
          st.tstep = math.max(st.tstep, tt)
        end
        ctx.log(string.format("V%d : adopte -> %s", i - 1, tostring(r and (r.id or r.why))))
      end
      ctx.check(ok == 3, "V1 a V3 : fours garnis adoptes", ok .. " / 3")
      ctx.check(st.tstep > 700 and st.tstep + 60 < 1900, "pas des ilots figes entre le tick 700 et le tick 1840", tostring(st.tstep))
    elseif t == 700 then
      local fz = 0
      for i = 2, 4 do if st.q[i].active == false then fz = fz + 1 end end
      ctx.check(fz == 3, "V1 a V3 figes au tick 700 (joueurs loin, calme)", fz .. " / 3")
      local src1 = st.q[2].get_inventory(defines.inventory.furnace_source)
      src1.clear()
      local src2 = st.q[3].get_inventory(defines.inventory.furnace_source)
      src2.clear()
      st.cu = src2.insert({ name = "copper-ore", count = 10 })
      local w0 = st.q[1].get_inventory(defines.inventory.furnace_source).insert({ name = "wood", count = 5 })
      ctx.log(string.format("fait : insert de 5 bois dans la source vide d'un four : %d insere(s) ; 10 minerais de cuivre dans la source de V2 : %d", w0, st.cu))
      st.p700 = {}
      for i = 2, 4 do st.p700[i] = count(st.q[i], defines.inventory.furnace_result, "iron-plate") end
      st.ore3 = count(st.q[4], defines.inventory.furnace_source, "iron-ore")
      ctx.log(string.format("tick 700 : plaques V1 %d, V2 %d, V3 %d ; minerai V3 %d ; V1 source vide, V2 source = %d minerais de cuivre",
        st.p700[2], st.p700[3], st.p700[4], st.ore3, st.cu))
    elseif st.tstep and t == st.tstep + 5 then
      local S = defines.entity_status
      local s1, s2 = ctx.remote("fo-gel", "statut", st.q[2]), ctx.remote("fo-gel", "statut", st.q[3])
      ctx.check(s1 == S.no_ingredients and s2 == S.full_output,
        "V1 et V2 : pas recu pendant le gel (statuts comptables no_ingredients, full_output), partie en marche",
        tostring(s1) .. ", " .. tostring(s2) .. " au tick " .. t)
      local p1 = count(st.q[2], defines.inventory.furnace_result, "iron-plate")
      local p2 = count(st.q[3], defines.inventory.furnace_result, "iron-plate")
      local c2 = count(st.q[3], defines.inventory.furnace_result, "copper-plate")
      local o2 = count(st.q[3], defines.inventory.furnace_source, "copper-ore")
      ctx.check(p1 == st.p700[2] and p2 == st.p700[3] and c2 == 0 and o2 == st.cu and st.cu > 0,
        "V1 et V2 : rien fabrique ni consomme (source vide ; cuivre derriere une sortie de fer)",
        string.format("plaques %d -> %d, %d -> %d ; cuivre : plaques %d, minerai %d / %d", st.p700[2], p1, st.p700[3], p2, c2, o2, st.cu))
      local p3 = count(st.q[4], defines.inventory.furnace_result, "iron-plate")
      local o3 = count(st.q[4], defines.inventory.furnace_source, "iron-ore")
      ctx.check(st.q[4].active == false and p3 > st.p700[4] and o3 < st.ore3, "V3 (temoin) : fige, son pas a fabrique (comptabilite en marche)",
        string.format("plaques %d -> %d, minerai %d -> %d", st.p700[4], p3, st.ore3, o3))
    elseif st.tstep and t == st.tstep + 20 then
      ctx.remote("fo-gel", "joueurs", "V", { { x = X0 + 10, y = Y0 + 4 } })
    elseif st.tstep and t == st.tstep + 60 then
      local up = 0
      for i = 2, 4 do if st.q[i].active == true then up = up + 1 end end
      ctx.check(up == 3, "reveil : joueur pres des fours, V1 a V3 actifs au guet suivant (pas du paye)", up .. " / 3")
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local et = ctx.remote("fo-gel", "etat", "V")
    ctx.check(et.figes == 0 and et.pertes == 0, "bilan : partie en marche jusqu'au tick 1900 ; rien de fige, aucune perte",
      string.format("ilots %d, figes %d, pertes %d", et.ilots, et.figes, et.pertes))
    ctx.check(count(st.q[3], defines.inventory.furnace_result, "copper-plate") == 0, "V2 : aucune plaque de cuivre inventee (sortie de fer, au reveil comme pendant le gel)")
  end,
}
