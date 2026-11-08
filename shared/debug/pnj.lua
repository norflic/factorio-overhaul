--[[
  Lot DEBUG-CERVEAU, V2 (directive du DC, 8/11 à 14 h 40) : « TRANSPARENCE TOTALE SUR LES PNJ ». Règles PURES (tests/debug_cerveau_test.lua) qui
  disent, pour un PNJ : sa tâche en cours, les étapes qui lui restent, les tâches que le tableau lui donnerait ensuite (lecture seule, sans réserver)
  et LA CAUSE de son inactivité ou de son attente. Aucun nom du jeu. Les mots rendus sont des clés de traduction fixes ; un mot inconnu devient
  « autre » ou « inconnu », jamais un texte brut derrière une clé.

  Entrées de Pn.explain (inp) :
    state     état de la machine du PNJ (idle, step, walk, mine, craft, wait, ia1d) ;
    has_task  le PNJ porte une tâche ;
    wait_left ticks restants d'une attente chronométrée (état wait), ou nil ;
    nav_fail  mot de l'échec de marche (agent.nav_fail), ou nil ;
    free      tâches LIBRES du tableau : { key, kind, prio, pause (ticks), missing = { item, need, free } | nil, hinted = bool } ;
    now       (non utilisé : les pauses sont déjà en ticks restants).
  Sortie : { cause, key (tâche citée), item, need, free, n (tâches libres), n_pause, n_matiere }.
  Causes : en_marche (tâche en cours), attente (chronomètre), marche_echec, aucune_tache (tableau sans tâche libre), pauses (toutes en pause d'échec),
  matiere (toutes celles qui ne sont pas en pause manquent de matière), pret (une tâche est prenable : la prochaine pensée la prend), autre.
]]

local Pn = {}

Pn.CAUSES = { "en_marche", "attente", "marche_echec", "aucune_tache", "pauses", "matiere", "pret", "autre" }
Pn.STEP_KINDS = { "home", "goto", "take", "act", "ia1d", "put_depot", "mine", "wait", "take_res", "take_depot", "craft_now", "craft" }
Pn.STATES = { "idle", "step", "walk", "mine", "craft", "wait", "ia1d", "none" }
Pn.NEXT_MAX = 5
Pn.STEPS_MAX = 8

local STEP_OK, STATE_OK = {}, {}
for _, k in ipairs(Pn.STEP_KINDS) do STEP_OK[k] = true end
for _, k in ipairs(Pn.STATES) do STATE_OK[k] = true end

local function num(v) return type(v) == "number" and v == v and v or nil end

function Pn.state_word(s) return (type(s) == "string" and STATE_OK[s]) and s or "inconnu" end

--- Pourquoi un PNJ n'a pas de tâche (ou attend). Voir l'en-tête.
function Pn.explain(inp)
  inp = type(inp) == "table" and inp or {}
  if inp.has_task then
    if inp.state == "wait" and num(inp.wait_left) and inp.wait_left > 0 then return { cause = "attente", n = 0, left = inp.wait_left } end
    if type(inp.nav_fail) == "string" and inp.nav_fail ~= "" then return { cause = "marche_echec", n = 0, why = inp.nav_fail } end
    return { cause = "en_marche", n = 0 }
  end
  local free = type(inp.free) == "table" and inp.free or {}
  local n, n_pause, n_mat, first_pause, first_mat, ready = 0, 0, 0, nil, nil, nil
  for _, t in ipairs(free) do
    n = n + 1
    if (num(t.pause) or 0) > 0 then
      n_pause = n_pause + 1
      first_pause = first_pause or t
    elseif type(t.missing) == "table" then
      n_mat = n_mat + 1
      first_mat = first_mat or t
    else
      ready = ready or t
    end
  end
  if n == 0 then return { cause = "aucune_tache", n = 0, n_pause = 0, n_matiere = 0 } end
  if ready then return { cause = "pret", key = ready.key, n = n, n_pause = n_pause, n_matiere = n_mat } end
  if n_mat > 0 then
    local m = first_mat.missing
    return { cause = "matiere", key = first_mat.key, item = m.item, need = num(m.need), free = num(m.free), n = n, n_pause = n_pause, n_matiere = n_mat }
  end
  return { cause = "pauses", key = first_pause and first_pause.key, left = first_pause and num(first_pause.pause), n = n, n_pause = n_pause, n_matiere = 0 }
end

--- Argument court d'une étape (texte de paramètre, jamais une clé) : position « (x, y) », « objet n », nom, ou "".
local function step_arg(step)
  local a = step[2]
  if type(a) == "table" then
    if num(a.x) and num(a.y) then return string.format("(%.0f, %.0f)", a.x, a.y) end
    local first = a[1]
    if type(first) == "table" and type(first[1]) == "string" then
      local parts = {}
      for i, it in ipairs(a) do
        if i > 2 then parts[#parts + 1] = "…" break end
        parts[#parts + 1] = tostring(it[1]) .. " " .. tostring(num(it[2]) or "?")
      end
      return table.concat(parts, ", ")
    end
    if type(first) == "string" then return first .. " " .. tostring(num(a[2]) or "") end
    return ""
  end
  if type(a) == "string" then return a end
  if num(a) then return tostring(a) end
  return ""
end

--- Étapes restantes d'une tâche : steps (liste de { "genre", arg... }), pc (étape en cours, 1 = première). Rend { rows = { { kind, arg, current } }, total, left }.
function Pn.step_rows(steps, pc)
  local out = { rows = {}, total = 0, left = 0 }
  if type(steps) ~= "table" then return out end
  out.total = #steps
  pc = num(pc) or 1
  if pc < 1 then pc = 1 end
  out.left = math.max(0, #steps - pc + 1)
  for i = pc, #steps do
    if #out.rows >= Pn.STEPS_MAX then break end
    local s = steps[i]
    if type(s) == "table" then
      local kind = (type(s[1]) == "string" and STEP_OK[s[1]]) and s[1] or "autre"
      out.rows[#out.rows + 1] = { kind = kind, arg = step_arg(s), current = i == pc }
    end
  end
  return out
end

--- Les tâches libres que le tableau donnerait ensuite : triées par priorité décroissante puis clé, au plus Pn.NEXT_MAX ; chacune dit si elle est
--- prenable (ok), en pause d'échec (pause, ticks restants) ou sans matière (missing).
function Pn.next_rows(free)
  local list = {}
  for _, t in ipairs(type(free) == "table" and free or {}) do
    if type(t) == "table" and type(t.key) == "string" then list[#list + 1] = t end
  end
  table.sort(list, function(a, b)
    if (num(a.prio) or 0) ~= (num(b.prio) or 0) then return (num(a.prio) or 0) > (num(b.prio) or 0) end
    return a.key < b.key
  end)
  local out = {}
  for _, t in ipairs(list) do
    if #out >= Pn.NEXT_MAX then break end
    local status = "ok"
    if (num(t.pause) or 0) > 0 then status = "pause" elseif type(t.missing) == "table" then status = "matiere" end
    out[#out + 1] = { key = t.key, kind = t.kind, prio = num(t.prio), status = status, pause = num(t.pause), item = t.missing and t.missing.item,
      need = t.missing and num(t.missing.need), free = t.missing and num(t.missing.free) }
  end
  return out
end

return Pn
