--[[
  Lot AMELIORATION-CONTINUE, micro-banc « matière ou ordonnancement » (demande de main, 9/11 10 h) : un tapis rapide décidé pour le remplacement
  est-il FABRIQUÉ puis PAYÉ, ou l'engagement expire-t-il ? Partie de etape1-geants (le code est réutilisé), avec :
    - au tick 60, logistics et logistics-2 recherchées pour TOUTES les forces (le tapis rapide est débloqué dès le départ : la partie de
      130 000 ticks atteint le parc de tapis de la minute 30 des longues parties) ;
    - `matiere` = true : toutes les 3 min, le coffre de chaque équipe est GARNI en tapis de base, engrenages et plaques de fer (la matière
      n'est plus un obstacle) ; false : le témoin, rien n'est donné.
  Relevé toutes les 3 min : « [FO-AMELIO-TAPIS] minute N | équipe | tapis rapides posés | tapis de base posés | stock : tapis rapide, tapis de base ».
  Lecture : lignes [FO-ENGAGEMENT], [FO-CAPITAL] « amelioration payee 'remplacer:...transport-belt... », [FO-CAPITAL-ATTENTE], [FO-ENGAGEMENT-DIAG].
  Lancement : banc.py --out <archive> --qui AMELIORATION-CONTINUE -- 130000 amelio-tapis-matiere <source> (et amelio-tapis-temoin).
]]

local TAG = "[FO-AMELIO-TAPIS] "
local MIN = 3600
local GIVE = { { "transport-belt", 600 }, { "iron-gear-wheel", 400 }, { "iron-plate", 3000 } }

return function(matiere)
  local base0 = require("scenarios/etape1-geants")
  local base = {}
  for k, v in pairs(base0) do base[k] = v end
  local init0, tick0 = base0.init, base0.tick
  base.description = "AMELIO-TAPIS : etape1-geants, tapis rapide debloque des le depart, matiere " .. (matiere and "donnee" or "non donnee (temoin)")
  base.check_tick = 129000
  base.shots_delay = 129500

  base.init = function(ctx)
    if init0 then init0(ctx) end
  end

  base.tick = function(ctx, e)
    if tick0 then tick0(ctx, e) end
    local t = e.tick
    local teams = ctx.remote("fo-ia1", "teams") or {}
    if t == 60 then
      for _, row in ipairs(teams) do
        local force = game.forces[row.force] or game.forces["fo-" .. row.key] or game.forces[row.key]
        if force then
          for _, tn in ipairs({ "logistics", "logistics-2" }) do
            if force.technologies[tn] then force.technologies[tn].researched = true end
          end
        end
      end
      local f0 = teams[1] and (game.forces[teams[1].force] or game.forces[teams[1].key])
      ctx.check(f0 ~= nil and f0.recipes["fast-transport-belt"] ~= nil and f0.recipes["fast-transport-belt"].enabled == true,
        "tapis rapide debloque des le tick 60")
    end
    if matiere and t >= 3 * MIN and t % (3 * MIN) == 0 then
      for _, row in ipairs(teams) do ctx.remote("fo-ind", "stock", row.key, GIVE) end
    end
    if t > 0 and t % (3 * MIN) == 0 then
      local s = ctx.surface()
      for _, row in ipairs(teams) do
        local fo = row.force
        local fast = #s.find_entities_filtered({ force = fo, name = "fast-transport-belt" })
        local basic = #s.find_entities_filtered({ force = fo, name = "transport-belt" })
        log(TAG .. string.format("minute %d | %s | tapis rapides poses %d | tapis de base poses %d", math.floor(t / MIN), row.key, fast, basic))
      end
    end
  end

  return base
end
