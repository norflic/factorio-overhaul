--- s47 axe : un seul plan de champ complet par tick. Règle pure de l'étape du cadre.
local Ch = require("shared.team.champ")
local Ax = {}

Ax.WAIT = "pas-encore"

--- Étape du cadre d'un avant-poste. `try` : o.axis_try (nil, ou { axe, tick, drills, chests, final }) ; `tick` : tick courant ;
--- `last_plan_tick` : tick du dernier Ch.plan (toutes équipes). Rend "wait" (aucun plan ce tick), "first" (plan de l'axe par défaut),
--- "other" (plan de l'axe noté, à comparer), "final" (plan de l'axe gagnant noté, sans nouvel essai).
function Ax.step(try, tick, last_plan_tick)
  if last_plan_tick == tick then return "wait" end
  if not try then return "first" end
  if try.tick >= tick then return "wait" end
  return try.final and "final" or "other"
end

--- Mémo du premier plan : comptes seulement (le plan n'est pas gardé).
function Ax.memo(plan, tick)
  return { axe = Ch.axis_other(plan.axis), first = plan.axis, tick = tick,
    drills = Ch.field_drills(plan), chests = Ch.head_chests(plan), orphans = plan.stats.orphans or 0 }
end

--- Ch.better_axis sur comptes mémorisés : vrai si le plan `b` remplace le premier plan (comptes `m`).
function Ax.better(m, b)
  if not b then return false end
  local da, db = m.drills, Ch.field_drills(b)
  if db <= da then return false end
  if Ch.head_chests(b) <= m.chests then return true end
  return not (Ch.refuse_keeps(db, da))
end

--- s49 tranches : file des avant-postes dont le plan de cadre attend son pas suivant (Ax.WAIT). `q` : liste { { key, ... } } ; une clé n'y
--- est qu'une fois (rien n'est ajouté si elle y est déjà). Rend vrai si l'entrée est ajoutée.
function Ax.push(q, e)
  for _, x in ipairs(q) do if x.key == e.key then return false end end
  q[#q + 1] = e
  return true
end

--- s49 tranches : la première entrée de la file (ordre d'arrivée), retirée ; nil si la file est vide. Une entrée par tick (appelant).
function Ax.pop(q)
  if #q == 0 then return nil end
  return table.remove(q, 1)
end

return Ax
