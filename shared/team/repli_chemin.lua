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

  Lot CHARBON3 (3/11, revue fo-logs/2026-11-03_REVUE/revue-charbon.md) :
    - B1 : le facteur ne vaut QUE pour un échec de chemin (R.delay) : un refus de la porte (« danger », 10 s) d'une tâche qui a des
      échecs de chemin en compte restait multiplié (160 s au lieu de 10 s ; un « programme » : 8 min au lieu de 30 s).
    - Q2 : une tâche VITALE (priorité >= R.VITAL_PRIO : ravitaillement des tourelles 90, garde du QG 96, tournée vieillie) reprend au
      plus après R.VITAL_CAP (60 s), quel que soit le compte ; le compte garde le tick du dernier échec de chemin et R.purge retire,
      au plus toutes les R.PURGE_EVERY ticks, les clés sans échec de chemin depuis R.FORGET (clés à position, `repare:...@x,y`, qui
      grossissaient sans fin dans global). Format d'avant (nombre seul, sauvegardes 0.6.43) : lu tel quel, retiré à la purge.
    - B2 : essais de marche d'un PNJ (R.walk_fail) ; l'appelant remet le compte à zéro à chaque arrivée et à chaque prise de tâche
      (script/team/worker.lua) : sinon le 4e « stuck » de la VIE du PNJ abandonnait aussitôt en « chemin ».
  PUR : aucune API Factorio, aucun nom d'objet.
]]
local R = {}

R.FAILS = { chemin = true } -- motifs comptés (script/team/worker.lua abort(..., "chemin"))
R.CAP = 16                  -- facteur au plus (base de 30 s : 8 min)
R.VITAL_PRIO = 90           -- priorité à partir de laquelle une tâche est vitale (ravitaillement des tourelles 90, garde du QG 96)
R.VITAL_CAP = 3600          -- 60 s : délai de reprise au plus d'une tâche vitale (sauf si sa base est déjà plus longue)
R.FORGET = 108000           -- 30 min sans échec de chemin : le compte d'une clé est oublié (au-delà du plus long délai, 16 min)
R.PURGE_EVERY = 18000       -- 5 min : une purge au plus par tableau
R.WALK_RETRIES = 3          -- essais de marche repris sur place avant l'abandon (stuck, timeout, busy ; jamais no_path)

--- Compte d'une entrée : { n = échecs, t = tick du dernier } ou nombre seul (format d'avant le lot CHARBON3).
function R.count(e)
  if type(e) == "table" then return e.n or 0 end
  return e or 0
end

--- Note la fin d'une tâche. counts : { [clé] = { n, t } } ; rend le compte après la note.
function R.note(counts, key, ok, fail, tick)
  if ok then
    counts[key] = nil
    return 0
  end
  if R.FAILS[fail] then
    local n = R.count(counts[key]) + 1
    counts[key] = { n = n, t = tick }
    return n
  end
  return R.count(counts[key])
end

--- Facteur du délai de reprise après n échecs « chemin » de suite.
function R.factor(n)
  if not n or n <= 1 then return 1 end
  local f = 2 ^ (n - 1)
  if f > R.CAP then f = R.CAP end
  return f
end

--- Délai de reprise (ticks) d'une tâche en échec : `base` (délai du motif, Ac.retry), `n` échecs de chemin de suite, `fail` motif de CET
--- échec, `prio` priorité de la tâche, `off` règle coupée (bancs témoins). Rend le délai et le facteur appliqué.
function R.delay(base, n, fail, prio, off)
  local k = 1
  if not off and R.FAILS[fail] then k = R.factor(n) end
  local d = base * k
  if k > 1 and (prio or 0) >= R.VITAL_PRIO then
    local cap = math.max(base, R.VITAL_CAP)
    if d > cap then d = cap end
  end
  return d, k
end

--- Clés triées d'une table (aucun ordre de pairs).
local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

--- Purge des comptes anciens : retire les clés dont le dernier échec de chemin date de R.FORGET ticks ou plus (et celles sans date,
--- format d'avant). Rend le nombre de clés retirées. Ordre des clés trié : déterministe.
function R.purge(counts, tick)
  local n = 0
  for _, k in ipairs(sorted_keys(counts)) do
    local e = counts[k]
    if type(e) ~= "table" or e.t == nil or tick - e.t >= R.FORGET then
      counts[k] = nil
      n = n + 1
    end
  end
  return n
end

--- Purge due ? (au plus une toutes les R.PURGE_EVERY ticks ; `last` : tick de la précédente, nil : jamais).
function R.purge_due(last, tick)
  return last == nil or tick - last >= R.PURGE_EVERY
end

--- Échec de marche d'un PNJ (`n` essais déjà ratés depuis la dernière arrivée ou la prise de tâche, `reason` du moteur) : rend
--- (nouvel essai sur place ?, compte après). L'abandon remet le compte à zéro.
function R.walk_fail(n, reason)
  n = (n or 0) + 1
  if n <= R.WALK_RETRIES and reason ~= "no_path" then return true, n end
  return false, 0
end

return R
