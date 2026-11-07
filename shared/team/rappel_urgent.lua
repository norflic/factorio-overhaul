--[[
  Lot COLLECTE (7/11) : RAPPEL d'un PNJ occupé pour une tâche URGENTE que personne ne prend. PUR : aucune API Factorio, aucun nom d'objet ;
  tests/rappel_urgent_test.lua (cas, mutants, coût en instructions).

  Constat (deux micro-bancs en moteur réel, le 7/11) : une tâche du tableau à la priorité 90 ou plus reste « libre » tant qu'AUCUN PNJ n'est libre,
  car les PNJ finissent de longues tâches (minage à la main de 91 s, tournée d'exploration) et la place de marché ne rappelle personne :
    - collecte-fer (fo-logs/2026-11-07_COLLECTE/lot) : coffre de sortie de 600 plaques de fer, tâche à 94, fer libre à 0, 2 PNJ sur 12 (exploration,
      minage de pierre) : « inactifs 0/2 », la tâche n'est pas prise pendant les 3 600 ticks (60 s) du relevé ;
    - stockage-plein (fo-logs/2026-11-07_STOCKAGE-VITAL/v2-bois) : coffre en bois à 90, 4 PNJ (éclaireurs, minage de fer à 111 tuiles) :
      « inactifs 0/4, libres 23 », non pris en 70 s.
  Seule la file sûre est rappelée aujourd'hui (Poles.sur_stops, script/team/poles.lua).

  Règle (une seule, pour toute tâche urgente) :
    - une tâche libre de priorité >= R.URGENT, au tableau depuis au moins R.AGE ticks (une pensée), que son preneur éventuel pourrait faire
      (`ok` : matière libre au registre, pas une tâche de conception) ;
    - AUCUN PNJ libre (un PNJ sans tâche, ou qui rentre après un échec, prendra la tâche tout seul) ;
    - un rappel au plus toutes les R.EVERY ticks (30 s) par équipe ;
    - candidats : un PNJ qui n'est PAS en défense (garnison, fortification, `defend`) et dont la tâche est de priorité STRICTEMENT inférieure à
      celle de la tâche urgente ;
    - ordre : hors exploration d'abord (le minage à la main avant l'éclaireur, qui coûte une mission), puis priorité de la tâche croissante, puis
      distance (au carré) du PNJ à la tâche urgente croissante, puis numéro du PNJ croissant ; les tâches urgentes sont essayées par priorité
      décroissante, la plus ancienne d'abord, puis clé.
      Garde (relecture d'effondrement) : une tâche urgente DÉJÀ servie par un rappel (ctx.served = sa clé) n'en déclenche pas un second tant qu'elle
      reste libre au tableau : le PNJ rappelé ne la prend pas toujours (autre pôle, plafond d'urgences hors pôle, distance qui bat la priorité) et
      rappeler un PNJ de plus toutes les 30 s ferait faire demi-tour à l'équipe en boucle. R.rearm(served, tasks) rend la clé à garder : nil quand
      la tâche est prise ou n'est plus au tableau (la garde se réarme).
  R.pick rend { npc, urgent, dropped_prio } ou nil et la raison de l'abstention.
]]
local R = {}

R.URGENT = 90          -- M.URGENT (shared/ai3/marche.lua) : seuil des urgences
R.AGE = 300            -- ticks au tableau avant le rappel : une pensée d'équipe
R.EVERY = 30 * 60      -- un rappel par équipe toutes les 30 s

local function d2(a, b)
  local dx, dy = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

--- ctx = { tick, last_at (tick du dernier rappel, ou nil),
---         tasks = { { key, prio, created, ok (faux : personne ne peut la prendre), x, y }, ... }  (tâches LIBRES du tableau),
---         npcs  = { { id, busy (vrai : tient une tâche), prio, defending, explore (la tâche est une exploration), x, y }, ... } }
--- Rend { npc, urgent, dropped_prio } ou (nil, raison) : "pause" | "libre" | "aucune urgence" | "aucun candidat".
function R.pick(ctx)
  if ctx.last_at and ctx.tick - ctx.last_at < R.EVERY then return nil, "pause" end
  for _, n in ipairs(ctx.npcs or {}) do
    if not n.busy then return nil, "libre" end
  end
  local urgents = {}
  for _, t in ipairs(ctx.tasks or {}) do
    if (t.prio or 0) >= R.URGENT and t.ok ~= false and ctx.tick - (t.created or ctx.tick) >= R.AGE and t.key ~= ctx.served then urgents[#urgents + 1] = t end
  end
  if #urgents == 0 then return nil, "aucune urgence" end
  table.sort(urgents, function(a, b)
    if a.prio ~= b.prio then return a.prio > b.prio end
    if (a.created or 0) ~= (b.created or 0) then return (a.created or 0) < (b.created or 0) end
    return a.key < b.key
  end)
  for _, u in ipairs(urgents) do
    local cand = {}
    for _, n in ipairs(ctx.npcs or {}) do
      if n.busy and not n.defending and (n.prio or 0) < u.prio then cand[#cand + 1] = { n = n, d2 = d2(n, u), rank = n.explore and 1 or 0 } end
    end
    if #cand > 0 then
      table.sort(cand, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if (a.n.prio or 0) ~= (b.n.prio or 0) then return (a.n.prio or 0) < (b.n.prio or 0) end
        if a.d2 ~= b.d2 then return a.d2 < b.d2 end
        return a.n.id < b.n.id
      end)
      return { npc = cand[1].n.id, urgent = u.key, dropped_prio = cand[1].n.prio or 0 }
    end
  end
  return nil, "aucun candidat"
end

--- Clé servie à garder : `served` si une tâche LIBRE de cette clé est encore au tableau (tasks = tâches libres), sinon nil (prise ou partie).
function R.rearm(served, tasks)
  if served == nil then return nil end
  for _, t in ipairs(tasks or {}) do
    if t.key == served then return served end
  end
  return nil
end

return R
