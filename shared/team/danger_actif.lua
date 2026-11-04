--[[
  Lot DANGER-ACTIF (demande du DC, 4/11, 19 h 10 : « déssactive le comportement "trop dangereux", l'idée est qu'ils continuent de travailler
  en évitant le danger. Actuellement ils font juste rien quand c'est "trop dangereux" (la moindre petite attaque même d'un avant-poste) » ;
  précision de 19 h 12 : « (continuer à travailler tout en évitant le danger ou en défandant) »).

  Règle PURE (tests/danger_actif_test.lua) : ce que devient un refus de la porte des tâches (script/ai3/comportement.lua, M.gate). La
  politique brute de la porte (shared/ai3/danger.lua, D.gate) ne change pas ; seule sa CONSÉQUENCE change :
    - le BUT est à portée d'une menace FIXE connue ou d'un lieu de morts de PNJ (partie fixe du danger au but >= seuil, ou Da.DEATHS_GOAL morts de l'heure au but) : la tâche est MISE DE CÔTÉ pour ce but
      Da.ASIDE_TICKS, le PNJ prend tout de suite une autre tâche (jamais la même refusée en boucle) ;
    - sinon (route seulement, morts de PNJ, menaces mobiles, escorte refusée) : le PNJ PART par le chemin du moindre danger, risque accepté.
  Mesure du repos : un PNJ refusé qui n'est pas reparti depuis plus de Da.REST_MAX ticks compte comme repos pour cause de danger.
  Types du moteur seulement (aucun nom d'objet du jeu).
]]

local Da = {}

Da.ASIDE_FAIL = "danger-but" -- task.fail d'une tâche mise de côté (shared/team/actif.lua, A.retry : pause A.ASIDE_TICKS)
Da.ASIDE_TICKS = 3600        -- 1 min : pause bornée d'une tâche dont le but est sous une menace fixe
Da.REST_MAX = 1800           -- 30 s : au-delà, un PNJ refusé qui n'est pas reparti est un « repos pour danger » (critère C1)

--- Le but est-il sous une menace FIXE connue, ou un lieu où des PNJ sont morts en nombre (tueur absent de la carte : « pas de marche suicide », même
--- garde-fou que shared/team/famine.lua) ? `parts` = D.exact_parts(map, x, y, tick) (fixed, deaths, mobile) ; `B` = seuil de la porte ; `deaths_n` = morts
--- de l'heure à moins de D.DEATH_R du but. Les cases MOBILES (attaque qui passe) et les morts sur la ROUTE ne comptent pas : on part, par le moindre danger.
Da.DEATHS_GOAL = 3 -- morts de l'heure au but à partir desquelles la tâche est mise de côté
function Da.fixed_goal(parts, B, deaths_n)
  return ((parts and parts.fixed) or 0) >= B or (deaths_n or 0) >= Da.DEATHS_GOAL
end

--- Que devient une attente de la porte ? "aside" (autre tâche) ou "go" (départ par le chemin du moindre danger, risque accepté).
--- `why` = motif de la porte : « boucle » (lot DETOUR-BOUCLE : un PNJ a tourné en rond autour de ce but) est toujours mis de côté.
function Da.after_wait(parts, B, why, deaths_n)
  if why == "boucle" or Da.fixed_goal(parts, B, deaths_n) then return "aside" end
  return "go"
end

Da.SITE_R = 32 -- tuiles : un PNJ à moins de 32 tuiles d'une alerte de soldats en cours est « sur le site attaqué »

--- Le PNJ en `p` est-il sur un site de l'équipe attaqué (alerte de soldats en cours à moins de Da.SITE_R) ? `alerts` : t.alerts de script/ai3/soldats.lua
--- ({ x, y, until }, nil permis). Les ouvriers armés de ce site se défendent et restent (Re.SITE_RATIO) ; les autres fuient comme avant.
function Da.site_alert(alerts, p, tick)
  for _, a in ipairs(alerts or {}) do
    if tick < (a["until"] or 0) then
      local dx, dy = a.x - p.x, a.y - p.y
      if dx * dx + dy * dy <= Da.SITE_R * Da.SITE_R then return true end
    end
  end
  return false
end

--- Faut-il prévenir les soldats de cette atteinte portée à un bâtiment de l'équipe ? Au plus une alerte par équipe tous les Da.ALERT_GAP ticks.
Da.ALERT_GAP = 60
function Da.alert_due(last, tick)
  return last == nil or tick - last >= Da.ALERT_GAP
end

--- Suivi du repos d'un PNJ (table simple `a`, par PNJ) : ouvert au premier refus, fermé au départ. `st` = compteurs de l'équipe.
function Da.rest_open(a, tick)
  if not a.rest_since then a.rest_since = tick end
end

function Da.rest_close(a, st, tick)
  local since = a.rest_since
  if not since then return 0 end
  a.rest_since = nil
  local d = tick - since
  st.rest_n = (st.rest_n or 0) + 1
  if d > (st.rest_max or 0) then st.rest_max = d end
  if d > Da.REST_MAX then st.rest_over = (st.rest_over or 0) + 1 end
  return d
end

--- Repos encore ouverts depuis plus de Da.REST_MAX ticks (comptés au bilan sans les fermer). `agents` : { [id] = a }, ids triés par l'appelant.
function Da.rest_open_over(agents, ids, tick)
  local n, worst = 0, 0
  for _, id in ipairs(ids) do
    local a = agents[id]
    if a and a.rest_since then
      local d = tick - a.rest_since
      if d > Da.REST_MAX then n = n + 1 end
      if d > worst then worst = d end
    end
  end
  return n, worst
end

return Da
