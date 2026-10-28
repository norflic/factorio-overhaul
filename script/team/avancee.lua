--[[
  POSTE AVANCÉ de VOTRE équipe (lot FORTIFY) : branchement moteur de la règle pure shared/team/avancee.lua.

  - Av.note : appelé par la porte du danger (script/ai3/comportement.lua) quand une tâche est refusée par une menace ; ouvre
    une demande de poste (point d'arrêt côté QG) pour une meute MOBILE fraîche. Menace fixe : trace « soldats requis ».
  - Av.tasks : une tâche « fortify » par demande ouverte, ajoutée au tableau (Board.add) à chaque pensée ; elle n'est émise
    que si le coffre a les tourelles ET les chargeurs (jamais de fabrication forcée : la défense du QG passe d'abord).
  - Av.done : appelé par l'action de pose (script/team/worker.lua) : demande close, tourelles comptées.
  Votre équipe seulement. L'état vit dans f.team.avance (nombres et chaînes).
]]

local A = require("shared.team.avancee")
local T = require("shared.team.config")
local Rg = require("shared.ai3.reglages") -- nom de la tourelle (R.TURRET), jamais écrit ici
local Stock = require("script.team.stock")

local Av = {}

local function state(f)
  local t = f.team
  t.avance = t.avance or A.new()
  return t.avance
end

local function d2(a, b) local dx, dy = a.x - b.x, a.y - b.y; return dx * dx + dy * dy end

--- map = carte du danger de l'équipe ({ threats = { {x, y, r, k, t, fixed?} } }) ; pts = points du trajet jugé ; dest = but ;
--- goal_d / B = danger exact au but et seuil de la porte ; why = raison du refus.
function Av.note(f, map, pts, dest, goal_d, B, why, tick)
  if not (f.is_player and f.hq_pos and A.REASONS[why]) then return end
  local st = state(f)
  -- menace fraîche qui couvre le trajet, la plus proche du but (égalité : x puis y)
  local best, bd
  for _, th in ipairs(map.threats or {}) do
    for _, q in ipairs(pts) do
      if d2(q, th) <= (th.r + 16) * (th.r + 16) then
        local dd = d2(dest, th)
        if not bd or dd < bd or (dd == bd and (th.x < best.x or (th.x == best.x and th.y < best.y))) then best, bd = th, dd end
        break
      end
    end
  end
  local req
  if best then
    local fixed = best.k ~= "pack" and best.k ~= "unit" and best.k ~= "character"
    req = { x = best.x, y = best.y, fixed = fixed, seen = best.t }
  elseif (goal_d or 0) >= (B or 1e9) then
    req = { x = dest.x, y = dest.y, seen = tick } -- case mobile du but, au-dessus du seuil : observée il y a moins de 4 min
  else
    return
  end
  local key, info = A.note(st, f.hq_pos, req, tick)
  if key and type(info) == "table" and info.t == tick then
    f.stats.avance_demandes = (f.stats.avance_demandes or 0) + 1
    log(string.format("[FO-AVANCE] %s : poste demande en (%d, %d) pour %s vers (%d, %d), %s a %.1f min", f.key or "player",
      info.x, info.y, why, math.floor(dest.x), math.floor(dest.y), best and best.k or "case mobile", tick / 3600))
  elseif not key and info == "fixe" then
    st.fixed_seen = (st.fixed_seen or 0) + 1
    if st.fixed_seen == 1 or st.fixed_seen % 50 == 0 then
      log(string.format("[FO-AVANCE] %s : menace FIXE (%s) en (%d, %d) : des tourelles ne l'atteignent pas, soldats requis (%d refus) a %.1f min",
        f.key or "player", best.k, best.x, best.y, st.fixed_seen, tick / 3600))
    end
  end
end

--- Tâches « fortify » des demandes ouvertes (liste, à passer à Board.add).
function Av.tasks(f, tick)
  if not (f.is_player and f.team and f.team.avance) then return {} end
  local st = state(f)
  local out = {}
  for _, r in ipairs(A.open(st, tick)) do
    local n = A.TURRETS
    local ammo = n * T.defend_ammo
    if Stock.count(f, Rg.TURRET) >= n and Stock.count(f, T.turret_ammo) >= ammo then
      out[#out + 1] = { key = "avance:" .. r.key, kind = "fortify", prio = 74, post = { x = r.x, y = r.y }, post_key = r.key,
        items = { { Rg.TURRET, n }, { T.turret_ammo, ammo } }, defend = true }
    end
  end
  return out
end

function Av.done(f, key, tick, n)
  if not (f.team and f.team.avance) then return end
  A.done(f.team.avance, key, tick, n)
  log(string.format("[FO-AVANCE] %s : poste %s, %d tourelle(s) posee(s) a %.1f min", f.key or "player", key, n or 0, tick / 3600))
end

return Av
