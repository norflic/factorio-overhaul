--[[
  Lot FOREUSES-THERMIQUES, point (A) du lead (5/11 20 h 47) : MESURE sur la carte de la partie du DC (graine 464616505, journal
  fo-logs/2026-11-05_PARTIE-DC-ESSAI/factorio-current-2032.log, lecture seule). Question : pourquoi le champ de l'avant-poste 1 (fer,
  2 750 tuiles, autour de (−16, −95)) n'a eu « 0 bande » à 40,7 et 130,2 min ? Minerai mêlé (lot MELANGE : 1 970 tuiles d'une autre
  ressource minable dans le cadre), ou bâtiments (couloir 87, tourelles 16, réserve 4, petits poteaux 6, falaise 1) ?
  Ce banc ne joue RIEN : il génère les chunks de la carte autour des sites connus, vérifie que la carte est bien celle du DC (fer près de
  (−16, −95), cuivre près de (−35, −63) et de (−172, −53), sites des journaux du DC), puis écrit au journal les tuiles de TOUTES les
  ressources dans un rayon de 102 tuiles autour de (−16, −95) (rayon du champ 96 + marge d'une foreuse 6), une ligne par ressource et par
  rangée, en intervalles :  [FO-GRAINE-DC] R <ressource> <y> <x0>-<x1>,<x2>-<x3>,...
  L'analyse est HORS JEU : lua5.2 tools/autotest/champ_graine.lua <benchmark.log> (plan du champ par la règle pure, avec et sans minerai
  mêlé, avec le couloir et les bâtiments relevés au journal du DC).
  Lancement (graine du DC, quelques ticks) :
    py -3.9 -B tools/autotest/banc.py --out <archive> --graine 464616505 --qui FOREUSES-TH -- 120 foreuses-graine-dc <source>
  Les réglages de carte du DC ne sont pas connus : le banc prend ceux par défaut ; les trois contrôles de sites disent si la carte est la même.
]]

local AT = 30
local CENTER = { x = -16, y = -95 }
local RADIUS = 102
local SITES = { { name = "iron-ore", x = -16, y = -95 }, { name = "copper-ore", x = -35, y = -63 }, { name = "copper-ore", x = -172, y = -53 } }

return {
  description = "FOREUSES-THERMIQUES (A) : releve des ressources de la carte du DC (graine 464616505) autour du fer de l'avant-poste 1",
  base = nil,
  check_tick = AT + 10,

  init = function(ctx) end,

  tick = function(ctx, e)
    if e.tick ~= AT then return end
    local st = ctx.state()
    local s = ctx.surface()
    for _, p in ipairs({ CENTER, SITES[2], SITES[3] }) do s.request_to_generate_chunks({ p.x, p.y }, 5) end
    s.force_generate_chunk_requests()
    local okn = 0
    for _, site in ipairs(SITES) do
      local n = s.count_entities_filtered({ position = { site.x, site.y }, radius = 6, name = site.name })
      ctx.check(n > 0, string.format("carte du DC : %s pres de (%d, %d)", site.name, site.x, site.y), tostring(n))
      if n > 0 then okn = okn + 1 end
    end
    -- toutes les ressources du disque, par nom puis rangée (intervalles de x contigus) ; ordre fixe : noms triés, y croissant, x croissant
    local by = {}
    local names = {}
    for _, r in ipairs(s.find_entities_filtered({ position = { CENTER.x, CENTER.y }, radius = RADIUS, type = "resource" })) do
      if r.valid then
        local n = r.name
        if not by[n] then by[n] = {}; names[#names + 1] = n end
        local x, y = math.floor(r.position.x), math.floor(r.position.y)
        by[n][y] = by[n][y] or {}
        local row = by[n][y]
        row[#row + 1] = x
      end
    end
    table.sort(names)
    local lines, tiles = 0, 0
    for _, n in ipairs(names) do
      local ys = {}
      for y in pairs(by[n]) do ys[#ys + 1] = y end
      table.sort(ys)
      for _, y in ipairs(ys) do
        local xs = by[n][y]
        table.sort(xs)
        local parts, a, b = {}, xs[1], xs[1]
        for i = 2, #xs + 1 do
          local x = xs[i]
          if x ~= nil and x == b + 1 then b = x
          else
            parts[#parts + 1] = a == b and tostring(a) or (a .. "-" .. b)
            a, b = x, x
          end
        end
        tiles = tiles + #xs
        lines = lines + 1
        ctx.log(string.format("[FO-GRAINE-DC] R %s %d %s", n, y, table.concat(parts, ",")))
      end
    end
    st.done = true
    ctx.log(string.format("[FO-GRAINE-DC] RESULTAT graine=%s sites_reconnus=%d/3 ressources=%d tuiles=%d lignes=%d centre=(%d,%d) rayon=%d",
      tostring(s.map_gen_settings.seed), okn, #names, tiles, lines, CENTER.x, CENTER.y, RADIUS))
  end,

  finish = function(ctx)
    ctx.check(ctx.state().done == true, "releve ecrit")
  end,
}
