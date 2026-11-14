--[[
  s46 profileur : sonde TOUJOURS allumée et bon marché autour d'une portée RARE (jamais une portée appelée à chaque tick).
  Sonde.wrap(nom, fn) rend une fonction qui appelle fn sans rien changer (mêmes arguments, mêmes valeurs rendues), entourée d'un
  game.create_profiler() arrêté en fin de portée et écrit au journal pour l'AFFICHAGE seulement :
    [FO-PERF-PIC] <portée> <équipe> Duration: <x>ms
  Un LuaProfiler ne se compare pas en 1.1 : il est écrit à chaque appel. Aucune décision ne le lit, rien dans global.
  L'équipe est lue sur le premier argument (f.key, sinon "player").
]]
local Sonde = {}

local function pack(...) return { n = select("#", ...), ... } end

function Sonde.wrap(nom, fn)
  return function(f, ...)
    local g = game
    if not (g and g.create_profiler) then return fn(f, ...) end
    local prof = g.create_profiler()
    local r = pack(fn(f, ...))
    prof.stop()
    local equipe = (type(f) == "table" and f.key) or "player"
    log({ "", "[FO-PERF-PIC] " .. nom .. " " .. tostring(equipe) .. " ", prof })
    return table.unpack(r, 1, r.n)
  end
end

return Sonde
