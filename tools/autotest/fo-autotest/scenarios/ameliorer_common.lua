--[[
  Lot AMELIORER (27/10) : la partie de l'étape 1 (scenarios/etape1-guide.lua : partie du guide, 30 ouvriers, automatisation
  et capitalisation allumées) AVEC le réglage fo-war-capital allumé, et, toutes les 10 min, le décompte par nom des fours
  et assembleurs de chaque équipe (factions et votre équipe) : « [FO-AMELIORER] minute N | clé | fours : nom=n … |
  assembleurs : nom=n … ». Lancement : banc.py --out <archive> --graine <N> --qui AMELIORER -- 216300 ameliorer-guide <source>.
  `ameliorer-temoin` (même partie, réglage éteint) se joue avec le même code : seule la ligne du réglage change.
]]

local TAG = "[FO-AMELIORER] "
local MIN = 3600

local function tally(s, force, ty)
  local c = {}
  for _, e in ipairs(s.find_entities_filtered({ force = force, type = ty })) do c[e.name] = (c[e.name] or 0) + 1 end
  local names = {}
  for n in pairs(c) do names[#names + 1] = n end
  table.sort(names)
  local parts = {}
  for _, n in ipairs(names) do parts[#parts + 1] = n .. "=" .. c[n] end
  return #parts > 0 and table.concat(parts, " ") or "-"
end

local function report(s, minute)
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    log(TAG .. string.format("minute %d | %s | fours : %s | assembleurs : %s", minute, row.key,
      tally(s, row.force, "furnace"), tally(s, row.force, "assembling-machine")))
  end
end

return function(rem, cap)
  cap = cap == true
  local base = require("scenarios/etape1-guide")
  local init0, tick0 = base.init, base.tick
  base.description = "AMELIORER : etape1-guide, fo-war-remplacer " .. (rem and "allume" or "eteint") .. ", fo-war-capital "
    .. (cap and "allume" or "eteint") .. ", decompte des machines"
  base.init = function(ctx)
    local r = ctx.call("war_setting", "fo-war-remplacer", rem)
    ctx.check(r == rem, "reglage fo-war-remplacer " .. (rem and "allume" or "eteint"), tostring(r))
    local c = ctx.call("war_setting", "fo-war-capital", cap)
    ctx.check(c == cap, "reglage fo-war-capital " .. (cap and "allume" or "eteint"), tostring(c))
    if init0 then init0(ctx) end
  end
  base.tick = function(ctx, e)
    if tick0 then tick0(ctx, e) end
    if e.tick > 0 and e.tick % (10 * MIN) == 0 then report(ctx.surface(), e.tick / MIN) end
  end
  return base
end
