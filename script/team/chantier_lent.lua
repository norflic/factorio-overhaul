--[[
  Lot AZURE : EXÉCUTANT de la trace [FO-CHANTIER-LENT] (règle pure : shared/team/chantier_lent.lua). Appelé par watch_stall
  (script/team/build.lua) au PREMIER « sans progrès depuis 10 min » d'un projet de BANDE du champ (spec.champ). LECTURE SEULE : rien n'est
  décidé, rien n'est écrit hors la mémoire f.build.cl = { logs, said = { ["id:cause"] = true } } (nombres et booléens).

  Chaîne : watch_stall (Blocage.stall dit la cause) -> Cl.report -> entités non posées par rôle (rôle, refus, dernier motif e.why posé par
  log_refusal) + Board.stall_view (tâches libres du projet, leur rang dans le marché, ce qui les précède, ce qui occupe les PNJ) -> ligne.
]]
local C = require("shared.team.chantier_lent")
local Board = require("script.team.board")
local Mq = require("shared.team.manquantes")

local Cl = {}

local function mem(f)
  local b = f.build
  b.cl = b.cl or { logs = 0, said = {} }
  return b.cl
end

--- Suffixe de [FO-BLOQUE] : les entités qui manquent, nommées avec leur état (« ; manquantes (1 sur 57) : ... »), ou "" si rien ne manque.
function Cl.missing(p)
  local d = Mq.describe(p and p.ents)
  return d and (" ; " .. d) or ""
end

--- Une ligne par projet de bande (le premier arrêt), C.LOGS lignes par équipe au plus.
function Cl.report(f, p, tick, cause, rec)
  if not (f and f.build and p and p.spec and p.spec.champ) then return false end
  local m = mem(f)
  local key = tostring(p.id) .. ":" .. tostring(cause)
  if m.said[key] or m.logs >= C.LOGS then return false end
  m.said[key] = true
  m.logs = m.logs + 1
  local roles = C.roles(p.ents)
  local built = 0
  for _, e in ipairs(p.ents or {}) do if e.built then built = built + 1 end end
  local view = Board.stall_view(f, "ia1d:" .. tostring(p.id) .. ":", tick)
  local tasks, oldest = {}, 0
  for _, t in ipairs(view.tasks) do
    local age = t.age / 3600
    if age > oldest then oldest = age end
    tasks[#tasks + 1] = { kind = t.kind, prio = t.prio, age_min = age, rank = t.rank, of = view.n, reason = C.reason(t) }
  end
  -- les plus vieilles d'abord (puis le rang, puis le genre : ordre total)
  table.sort(tasks, function(a, b)
    if a.age_min ~= b.age_min then return a.age_min > b.age_min end
    if (a.rank or 0) ~= (b.rank or 0) then return (a.rank or 0) < (b.rank or 0) end
    if a.kind ~= b.kind then return a.kind < b.kind end
    return a.prio < b.prio
  end)
  log(C.line({
    team = f.key or "player", pid = p.id, band = p.spec.champ.pr, state = p.state, reason = p.reason, minute = tick / 3600,
    cause = cause, stall_min = rec and rec.since and math.floor((tick - rec.since) / 3600) or 0, built = built, total = #(p.ents or {}),
    roles = roles, tasks = tasks, tasks_n = #view.tasks, oldest_min = oldest, ahead = view.ahead, busy = view.busy,
    fails = f.team and f.team.fail_reasons or {}, miss = Mq.describe(p.ents),
  }))
  return true
end

return Cl
