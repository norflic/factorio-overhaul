--[[
  Lot NAV2 (3/11, dernière tâche) : délai CROISSANT avant de reprendre une tâche dont le chemin échoue de suite.

  Symptôme (champ-longue 271828182) : un PNJ de votre équipe « enfermé » au QG, toutes ses tâches en « chemin introuvable (no_path) » :
  ouvrier 121 en (9,9), 435 refus (lot) ; ouvrier 35 en (5,13), 102 refus (témoin integ-0642).
  Cause MESURÉE (rejeu déterministe du témoin avec sondes, branche diag-nav2) : le PNJ n'est PAS enfermé. Sa tuile est atteinte depuis
  le bord d'une carte de rayon 24 ; une demande de chemin depuis sa position vers une tuile à 10 tuiles RÉUSSIT (réglage du mod, et
  sans marge) ; la même demande depuis cette tuile vers le but de sa tâche ÉCHOUE : ce sont les BUTS qui sont injoignables (quai du
  plan directeur ia1d:6 en (30.8, 64.3), tournée d'un avant-poste fermé). La tâche ratée revient au tableau après 30 s (60 s pour le
  fond, script/team/board.lua) et le PNJ libre du QG la reprend aussitôt : il échoue sans fin et ne fait rien d'autre.
  Règle : par tâche (clé), on compte les échecs « chemin » de suite ; le délai de reprise est multiplié par 2^(n-1), au plus R.CAP ;
  une réussite remet le compte à zéro ; un autre motif d'échec ne le change pas.
  PUR : aucune API Factorio, aucun nom d'objet.
]]
local R = {}

R.FAILS = { chemin = true } -- motifs comptés (script/team/worker.lua abort(..., "chemin"))
R.CAP = 16                  -- facteur au plus (base de 30 s : 8 min)

--- Note la fin d'une tâche. counts : { [clé] = échecs de suite } ; rend le compte après la note.
function R.note(counts, key, ok, fail)
  if ok then
    counts[key] = nil
    return 0
  end
  if R.FAILS[fail] then
    counts[key] = (counts[key] or 0) + 1
    return counts[key]
  end
  return counts[key] or 0
end

--- Facteur du délai de reprise après n échecs « chemin » de suite.
function R.factor(n)
  if not n or n <= 1 then return 1 end
  local f = 2 ^ (n - 1)
  if f > R.CAP then f = R.CAP end
  return f
end

return R
