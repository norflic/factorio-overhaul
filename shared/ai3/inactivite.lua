--[[
  Lot ZERO-IDLE-3 (directive du DC, 8/11, 18 h 40 : « Zéro Inactivité (Zero Idle) : interdiction absolue de voir des agents wait ou
  idle alors que l'arbre technologique et la carte ne sont pas entièrement conquis ») : MESURE des causes d'inactivité, règle PURE
  (aucune API Factorio, aucune décision n'en dépend).

  Un PNJ « idle » (sans tâche, état idle) est servi toutes les ~60 ticks (script/team/worker.lua, état idle) : à chaque pensée, UNE
  issue, qui est la cause exacte de son attente jusqu'à la pensée suivante :
    - jetons              : le budget de travail de l'équipe est épuisé à ce tick (Tokens.take refusé) ;
    - sans-tache:<raison> : la place de marché n'a rien rendu ; raison = rien (aucune tâche libre) | role (le PNJ ne sait pas les
                            faire : garde sans munitions, conception, fabrication en arrière-plan pleine) | indice (indiquées à un
                            autre PNJ libre) | matiere (la matière stricte n'est pas libre au registre) | reserve (essayées, matière
                            refusée) | mixte, suivie du genre de sa meilleure tâche libre ;
    - sans-programme:<genre>:<échec> : tâche prise mais programme introuvable (minerai, chemin, avant-poste disparu) ;
    - refus-porte:<genre> : tâche prise mais refusée par la porte du danger.
  Le temps (ticks) écoulé depuis la pensée précédente du même PNJ est attribué à l'issue de la pensée présente. Cumul par équipe dans
  f.team.inact (nombres et chaînes seulement), ligne [FO-INACTIF-CAUSE] une fois par minute de partie.
]]

local I = {}

I.EVERY = 3600     -- une ligne par minute de partie
I.DT_DEFAULT = 60  -- première pensée d'une attente : une période de pensée
I.DT_MAX = 600     -- au-delà (PNJ revenu de loin, pensée espacée par les jetons), on ne compte qu'une période

--- Ticks attribués à cette pensée : écart avec la précédente du même PNJ (`seen`, nil à la première), borné.
function I.dt(seen, tick)
  if not seen then return I.DT_DEFAULT end
  local d = tick - seen
  if d <= 0 then return I.DT_DEFAULT end
  if d > I.DT_MAX then return I.DT_DEFAULT end
  return d
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

--- Raison d'une prise vide de la place de marché. `st` = { free, cannot, ranked, matiere, tried, first_kind }
--- (free : tâches libres du tableau ; cannot : parmi elles, celles que le PNJ ne sait pas faire ; ranked : tâches qu'il pourrait
--- prendre et qui ne sont pas indiquées à un autre ; matiere : parmi elles, écartées faute de matière stricte libre ; tried : essayées,
--- réservation refusée ; first_kind : genre de sa meilleure tâche).
function I.empty_reason(st)
  if (st.free or 0) <= 0 then return "rien" end
  if (st.ranked or 0) <= 0 then
    return (st.cannot or 0) * 2 >= st.free and "role" or "indice"
  end
  local why
  if (st.tried or 0) > 0 and (st.matiere or 0) == 0 then why = "reserve"
  elseif (st.tried or 0) == 0 then why = "matiere"
  else why = "mixte" end
  return why .. ":" .. tostring(st.first_kind or "?")
end

--- Note une issue (clé) d'une pensée de `dt` ticks dans l'accumulateur (créé s'il est nil) ; rend l'accumulateur.
function I.note(acc, key, dt, tick)
  acc = acc or { t0 = tick, ticks = {}, count = {}, total = 0 }
  acc.t0 = acc.t0 or tick
  acc.ticks[key] = (acc.ticks[key] or 0) + dt
  acc.count[key] = (acc.count[key] or 0) + 1
  acc.total = acc.total + dt
  return acc
end

--- La minute est-elle écoulée ?
function I.due(acc, tick)
  return acc ~= nil and acc.t0 ~= nil and tick - acc.t0 >= I.EVERY
end

--- Ligne [FO-INACTIF-CAUSE] (nil : rien à dire). `workers` : PNJ de l'équipe ; la part est celle des PNJ-secondes de la fenêtre.
function I.line(team, minute, acc, workers, window_ticks)
  if not acc or acc.total <= 0 then return nil end
  local rows = {}
  for _, k in ipairs(sorted_keys(acc.ticks)) do rows[#rows + 1] = { k = k, t = acc.ticks[k], n = acc.count[k] or 0 } end
  table.sort(rows, function(a, b)
    if a.t ~= b.t then return a.t > b.t end
    return a.k < b.k
  end)
  local parts = {}
  for i = 1, math.min(8, #rows) do
    parts[#parts + 1] = string.format("%s %.0f s (%d)", rows[i].k, rows[i].t / 60, rows[i].n)
  end
  local denom = math.max(1, (workers or 0)) * math.max(1, window_ticks or I.EVERY)
  return string.format("[FO-INACTIF-CAUSE] %s minute %d | PNJ %d | perdu %.0f PNJ-s sur %.0f (%.1f %%) | %s", team, minute, workers or 0,
    acc.total / 60, denom / 60, 100 * acc.total / denom, table.concat(parts, " ; "))
end

return I
