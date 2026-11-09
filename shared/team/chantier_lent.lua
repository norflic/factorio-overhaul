--[[
  Lot AZURE (retour du DC du 3/11 sur la 0.6.46 : « la Ligue Azur est restée en âge 1 [...] elle s'est arrêtée en plein milieu ») :
  TRACE d'un chantier de bande qui n'avance plus. PUR : aucune API Factorio, aucun nom d'objet ; testé hors jeu
  (tests/chantier_lent_test.lua).

  Constat du journal du DC (fo-logs/2026-11-03_RETOUR3, équipe azure) : les bandes p7 (575 entités) et p8 (475) restent « chantier » de
  39 à 130 min, 246 entités bâties sur 575 à 60 min, alors que les tâches libres du projet (35 poses à la priorité 82, 16 défrichages
  à 83, transport 61 et 71) restent IDENTIQUES de 59 à 149 min ; les PNJ, eux, prennent environ 7 tâches par minute. Le journal ne dit
  ni quelles entités manquent, ni pourquoi les tâches ne sont pas prises. Cette trace le dit, une fois par bande :

    [FO-CHANTIER-LENT] <équipe> : projet N (bande B, état S[/raison]) à T min, sans progrès (CAUSE), X entités bâties sur Y ;
      non posées par rôle {rôle n (m refusées), ...} ; refus {motif n, ...} ; tâches libres du projet K (plus vieille A min) {genre:prio
      âge rang R/N raison ...} ; en tête de file {genre:prio, ...} ; PNJ occupés {genre:prio xn, ...} ; échecs de l'équipe {motif n, ...}

  Raison de non-prise d'une tâche libre (`M.reason`), dans cet ordre : pause après échec, chemin raté de suite, matière non libre au
  registre, indiquée à un autre PNJ libre, en tête de file (prise imminente), sinon « derrière N » (N tâches mieux notées).
  Le danger n'a pas de trace par tâche (le refus de la porte met la tâche en pause, motif « danger » compté dans `échecs de l'équipe`).
  Lecture seule : aucun effet sur le jeu. Aucun `pairs` décisionnel, aucun hasard.
]]

local C = {}

C.MAX_ROLES = 8   -- rôles listés au plus
C.MAX_TASKS = 6   -- tâches libres du projet listées au plus (les plus vieilles d'abord)
C.MAX_AHEAD = 5   -- tâches en tête de file listées
C.MAX_BUSY = 6    -- genres:priorités des PNJ occupés listés
C.MAX_KV = 6      -- couples motif/compte listés au plus
C.LOGS = 12       -- lignes au plus par équipe

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Entités PAS ENCORE POSÉES (ni sautées ni abandonnées) groupées par rôle. ents : liste de { role, built, skipped, dropped, fails, why }.
--- Rend { { role, n, failed (entités déjà refusées au moins une fois), why = { [motif] = n } }, ... } trié par n décroissant puis rôle.
function C.roles(ents)
  local by = {}
  for _, e in ipairs(ents or {}) do
    if not e.built and not e.skipped and not e.dropped then
      local r = e.role or "?"
      local g = by[r]
      if not g then g = { role = r, n = 0, failed = 0, why = {} }; by[r] = g end
      g.n = g.n + 1
      if (e.fails or 0) > 0 then g.failed = g.failed + 1 end
      if e.why then g.why[e.why] = (g.why[e.why] or 0) + 1 end
    end
  end
  local out = {}
  for _, r in ipairs(sorted_keys(by)) do out[#out + 1] = by[r] end
  table.sort(out, function(a, b)
    if a.n ~= b.n then return a.n > b.n end
    return a.role < b.role
  end)
  return out
end

--- Motifs de refus de TOUTES les entités non posées : { { why, n }, ... } trié par n décroissant puis motif.
function C.whys(roles)
  local tot = {}
  for _, g in ipairs(roles or {}) do
    for _, w in ipairs(sorted_keys(g.why)) do tot[w] = (tot[w] or 0) + g.why[w] end
  end
  local out = {}
  for _, w in ipairs(sorted_keys(tot)) do out[#out + 1] = { w, tot[w] } end
  table.sort(out, function(a, b)
    if a[2] ~= b[2] then return a[2] > b[2] end
    return a[1] < b[1]
  end)
  return out
end

--- Raison pour laquelle une tâche LIBRE n'est pas prise. t = { worker, pause (ticks de pause restants), path_n (échecs « chemin » de suite),
--- prenable (matière stricte libre ; nil = sans objet), hinted (indiquée à un autre PNJ libre), rank (rang dans l'ordre de la place de
--- marché, 1 = en tête) }.
function C.reason(t)
  if t.worker then return "prise" end
  if (t.pause or 0) > 0 then return "pause apres echec" end
  if (t.path_n or 0) > 0 then return string.format("chemin rate x%d", t.path_n) end
  if t.prenable == false then return "matiere non libre" end
  if t.hinted then return "indiquee a un autre PNJ" end
  if not t.rank then return "hors marche" end
  if t.rank <= 1 then return "en tete (prise imminente)" end
  return string.format("derriere %d", t.rank - 1)
end

--- Compte { [clé] = n } -> liste triée de "clé n" (n décroissant puis clé), au plus `max`.
function C.kv(counts, max)
  local ks = sorted_keys(counts or {})
  table.sort(ks, function(a, b)
    if counts[a] ~= counts[b] then return counts[a] > counts[b] end
    return a < b
  end)
  local out = {}
  for i, k in ipairs(ks) do
    if i > (max or C.MAX_KV) then break end
    out[#out + 1] = k .. " " .. tostring(counts[k])
  end
  return out
end

local function braces(list) return "{" .. table.concat(list, ", ") .. "}" end

--- Ligne de journal. ev = { team, pid, band, state, reason, minute, cause, stall_min, built, total, roles (C.roles), tasks (liste de
--- { kind, prio, age_min, rank, of, reason }), tasks_n, oldest_min, ahead (liste de "genre:prio"), busy (compte "genre:prio" -> n),
--- fails (compte motif -> n) }.
function C.line(ev)
  local roles = {}
  for i, g in ipairs(ev.roles or {}) do
    if i > C.MAX_ROLES then roles[#roles + 1] = "..."; break end
    roles[#roles + 1] = string.format("%s %d (%d refusee(s))", g.role, g.n, g.failed)
  end
  local whys = {}
  for i, w in ipairs(C.whys(ev.roles)) do
    if i > C.MAX_KV then break end
    whys[#whys + 1] = w[1] .. " " .. w[2]
  end
  local tasks = {}
  for i, t in ipairs(ev.tasks or {}) do
    if i > C.MAX_TASKS then break end
    tasks[#tasks + 1] = string.format("%s:%d %.1f min rang %s/%s %s", t.kind, t.prio, t.age_min or 0, tostring(t.rank or "-"), tostring(t.of or "-"), t.reason)
  end
  local ahead = {}
  for i, a in ipairs(ev.ahead or {}) do
    if i > C.MAX_AHEAD then break end
    ahead[#ahead + 1] = a
  end
  return string.format(
    "[FO-CHANTIER-LENT] %s : projet %d (bande %s, etat %s%s) a %.1f min, sans progres depuis %d min (%s), %d entite(s) baties sur %d ; "
      .. "non posees par role %s ; refus %s ; taches libres du projet %d (plus vieille %.1f min) %s ; en tete de file %s ; PNJ occupes %s ; echecs de l'equipe %s",
    ev.team, ev.pid, tostring(ev.band), tostring(ev.state), ev.reason and ("/" .. tostring(ev.reason)) or "", ev.minute or 0,
    ev.stall_min or 0, tostring(ev.cause), ev.built or 0, ev.total or 0, braces(roles), braces(whys), ev.tasks_n or 0, ev.oldest_min or 0,
    braces(tasks), braces(ahead), braces(C.kv(ev.busy, C.MAX_BUSY)), braces(C.kv(ev.fails, C.MAX_KV)))
    .. (ev.miss and (" ; " .. ev.miss) or "")
end

return C
