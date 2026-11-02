--[[
  Lot FLUX : journal [FO-FLUX] (LECTURE SEULE : aucune décision n'en dépend). Une ligne toutes les 5 min par équipe : ce qui dort dans
  les sorties des avant-postes (plaques par objet, réceptacles pleins), les tournées libres (nombre, la plus ancienne, sa priorité),
  les brûleurs des avant-postes VITAUX à sec, et, cumulé sur les pensées où l'équipe est menacée, la part de brûleurs vitaux à sec.
  Règles : shared/team/flux.lua. État : f.team.flux (tick du dernier journal, cumul), créé ici en événement, jamais à on_load.
]]
local T = require("shared.team.config")
local Fx = require("shared.team.flux")
local Board = require("script.team.board")

local L = {}

L.EVERY = 5 * 3600 -- ticks entre deux lignes
local VITAL = Fx.vital(T.outposts, T.fuel, T.smelter_inputs)
local ONLY = Fx.plates_of(Fx.plate_map(T.OUTPOST_ORDER, T.outposts, T.smelter_inputs))

local function sorted(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Appelé à chaque pensée d'équipe, après le plan. `view` : Team.view.
function L.think(f, view, tick)
  local team = f.team
  if not team then return end
  local st = team.flux
  if not st then
    st = { t = tick, thinks = 0, thr = 0, thr_burners = 0, thr_dry = 0 }
    team.flux = st
  end
  local burners, dry, stuck, sinks = 0, 0, 0, 0
  local all_out = 0 -- tout ce qui dort dans les sorties, comptées ou non (avant-poste dangereux, tournées ratées)
  for _, o in ipairs(view.outposts or {}) do
    for _, n in pairs(o.outputs or {}) do all_out = all_out + n end
    if VITAL[o.kind] then
      burners = burners + (o.burners or 0)
      dry = dry + (o.dry or 0)
    end
    stuck = stuck + (o.stuck or 0)
  end
  st.thinks = st.thinks + 1
  if view.threatened then
    st.thr = st.thr + 1
    st.thr_burners = st.thr_burners + burners
    st.thr_dry = st.thr_dry + dry
  end
  if tick - st.t < L.EVERY then return end
  st.t = tick
  local repat, total = Fx.repatriable(view.outposts, ONLY)
  local parts = {}
  for _, k in ipairs(sorted(repat)) do parts[#parts + 1] = k .. " " .. repat[k] end
  -- tournées libres au tableau
  local free, oldest, oprio = 0, 0, 0
  for _, t in ipairs(Board.get(f).list or {}) do
    if t.kind == "service" and not t.worker then
      free = free + 1
      local age = tick - (t.created or tick)
      if age > oldest then oldest, oprio = age, t.prio or 0 end
    end
  end
  log(string.format("[FO-FLUX] %s a %.1f min : sorties comptees %d (%s) sur %d en tout ; receptacles pleins %d ; tournees libres %d (plus vieille %d s, prio %d) ; "
    .. "bruleurs vitaux %d dont %d a sec, remplissage a %d charbons ; pendant menace : %d pensee(s), %.1f %% des bruleurs vitaux a sec",
    f.key or "player", tick / 3600, total, table.concat(parts, ", "), all_out, stuck, free, oldest / 60, oprio, burners, dry,
    team.flux_fill or T.fuel_refill_to, st.thr,
    st.thr_burners > 0 and 100 * st.thr_dry / st.thr_burners or 0))
  st.thr, st.thr_burners, st.thr_dry = 0, 0, 0
end

return L
