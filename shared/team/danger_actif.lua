--[[
  Lot DANGER-ACTIF (demande du DC, 4/11, 19 h 10 : « déssactive le comportement "trop dangereux", l'idée est qu'ils continuent de travailler
  en évitant le danger. Actuellement ils font juste rien quand c'est "trop dangereux" (la moindre petite attaque même d'un avant-poste) » ;
  précision de 19 h 12 : « (continuer à travailler tout en évitant le danger ou en défandant) »).

  Règle PURE (tests/danger_actif_test.lua) : ce que devient un refus de la porte des tâches (script/ai3/comportement.lua, M.gate). La
  politique brute de la porte (shared/ai3/danger.lua, D.gate) ne change pas ; seule sa CONSÉQUENCE change :
    - le BUT est à portée d'une menace FIXE connue ou d'un lieu de morts de PNJ (partie fixe du danger au but >= seuil, ou Da.DEATHS_GOAL morts de l'heure au but) : la tâche est MISE DE CÔTÉ pour ce but
      Da.ASIDE_TICKS, le PNJ prend tout de suite une autre tâche (jamais la même refusée en boucle) ;
    - sinon (route seulement, morts de PNJ, menaces mobiles, escorte refusée) : le PNJ PART par le chemin du moindre danger, risque accepté.
    - 2e essai (5/11) : une menace dont la zone contient DÉJÀ le PNJ (meute qui couvre le QG) ne compte, au but et sur la route, que là où le trajet va
      plus près d'elle que son départ (shared/ai3/danger.lua, D.fixed_prep) ; la défense de la base ne se met pas de côté pour une meute (Da.base_defense).
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
Da.DEATHS_GOAL = 2 -- morts de l'heure au but à partir desquelles la tâche est mise de côté (docs/IA_ATTENDUS.md C5 : au plus 2 morts au même endroit par heure)
Da.DEATHS_ROUTE = 2 -- morts de l'heure sur le chemin du moindre danger à partir desquelles la tâche est mise de côté (même règle)
function Da.fixed_goal(parts, B, deaths_n)
  return ((parts and parts.fixed) or 0) >= B or (deaths_n or 0) >= Da.DEATHS_GOAL
end

--- Morts de l'heure au but RETENUES par la mise de côté (`n` = morts à moins de D.DEATH_R du but). Les exemptions déjà décidées pour la porte valent ici :
---   - `def_base` : défense dont les morts de la route sont toutes dans la base (lot PORTE-BASE, arbitrage du DC du 29/10 : « la base se défend ») : 0 ;
---   - `calm` : tâche proche aux morts toutes anciennes (lot COMPAGNONS-ACTIFS, DC 29/10 : « il faut revenir, il faut agir ») : 0 sous `cap`, le garde-fou de
---     FER-MARQUE (Fa.DEATHS_MAX, « pas de marche suicide », calme compris) ; à partir de `cap`, toutes.
function Da.goal_deaths(n, def_base, calm, cap)
  if def_base then return 0 end
  if calm and (n or 0) < (cap or 0) then return 0 end
  return n or 0
end

--- Défense de la base (relecture du lead, B4 ; DC 4/11 19 h 12 « ou en défendant » ; R-QCM-25c (b) « l'équipe le défend ») : une garde, une recharge ou une
--- pose de tourelles dont le but est DANS la zone de base (M.base_zone, lot PORTE-BASE) n'est pas mise de côté pour une MEUTE (l'attaque même qu'elle
--- défend) ; un nid, un ver ou une tourelle ennemie au but la met toujours de côté. Relecture de revue-danger (bloquant) : seulement pour un PNJ ARMÉ
--- (`armed` : munitions CHARGÉES, M.has_ammo ; la garde aussi, la place de marché compte les munitions du sac). Un désarmé qui recharge ou pose une
--- tourelle est exempté de l'abri et du rappel (Re.EXEMPT) et ne regarde pas à moins de 32 tuiles du QG : il partait en plein raid sans réflexe.
Da.DEFENSE_KINDS = { fortify = true, garrison = true, refill = true }
function Da.base_defense(kind, in_base, armed)
  return (Da.DEFENSE_KINDS[kind] and in_base and armed) and true or false
end

--- Que devient une attente de la porte ? "aside" (autre tâche) ou "go" (départ par le chemin du moindre danger, risque accepté).
--- `why` = motif de la porte : « boucle » (lot DETOUR-BOUCLE : un PNJ a tourné en rond autour de ce but) est toujours mis de côté.
--- `route` (facultatif) = { fixed = danger FIXE le plus fort le long du chemin du moindre danger, deaths = morts de l'heure sur ce chemin } : un chemin qui
--- passe forcément à portée d'une menace fixe (le PNJ ferait demi-tour à portée, puis reviendrait au tableau : boucle cachée) ou par 2 morts de l'heure
--- met la tâche de côté.
function Da.after_wait(parts, B, why, deaths_n, route)
  if why == "boucle" or Da.fixed_goal(parts, B, deaths_n) then return "aside" end
  if route and ((route.fixed or 0) >= B or (route.deaths or 0) >= Da.DEATHS_ROUTE) then return "aside" end
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

-- Mise à l'abri (script/ai3/soldats.lua, shelter) : seuls les ouvriers EXPOSÉS réagissent (distance à la MENACE, pas au QG) ; le ralliement général derrière les
-- tourelles du QG n'a lieu que pour une menace qui vise le QG lui-même.
Da.RALLY_HQ_R = 40 -- tuiles : menace à moins de 40 tuiles du QG = à portée des tourelles du QG (Re.RALLY_R)

--- Le PNJ en `p` est-il exposé à la menace `threat` (à moins de `reach` tuiles : portée de l'ennemi + marge, Re.away_distance) ?
function Da.exposed(p, threat, reach)
  local dx, dy = p.x - threat.x, p.y - threat.y
  return dx * dx + dy * dy <= reach * reach
end

--- Lot CORR-RALLIEMENT (tenue, 7/11 ; fo-logs/2026-11-05_EFFONDREMENT/RAPPORT.md §12) : état « away » d'une équipe dont le QG est débordé, posé par
--- script/ai3/soldats.lua (hq_threat) à chaque décision « away » : { x, y (menace), reach, until }. Vivant tant que tick < until : il expire seul quand
--- plus aucune décision « away » ne le renouvelle. `w` nil permis.
function Da.away_live(w, tick)
  return w ~= nil and tick < (w["until"] or -1)
end

--- Pendant « away » : coffre de dépôt hors de portée de la menace (même portée que la mise à l'abri, Da.exposed). `cs` : positions des coffres du
--- stock, dans l'ordre de l'appelant ; `p` : position du PNJ. Rend l'indice du plus proche non exposé (le premier à égalité), ou nil.
function Da.safe_chest(cs, p, w)
  local best, bd = nil, nil
  for i, c in ipairs(cs) do
    if not Da.exposed(c, w, w.reach) then
      local dx, dy = c.x - p.x, c.y - p.y
      local d = dx * dx + dy * dy
      if bd == nil or d < bd then best, bd = i, d end
    end
  end
  return best
end

--- Réponse d'équipe retenue : « rally » (tous derrière les tourelles) seulement si la menace est à portée du QG ; sinon « stand » (les seuls exposés
--- et désarmés s'écartent, les armés exposés défendent, les autres continuent).
function Da.shelter_resp(resp, threat, hq)
  if resp == "rally" then
    local dx, dy = threat.x - hq.x, threat.y - hq.y
    if dx * dx + dy * dy > Da.RALLY_HQ_R * Da.RALLY_HQ_R then return "stand" end
  end
  return resp
end

--- Type du moteur de l'auteur d'un coup : une attaque MOBILE (unité, personnage) alerte les soldats ; un nid, un ver, une tourelle : jamais (nettoyage).
function Da.mobile_cause(ctype)
  return ctype == "unit" or ctype == "character"
end

--- Alertes de SITE (un bâtiment de l'équipe touché, C.on_alert mode « site ») : relecture du lead (5/11, 17 h 34 et 17 h 41, risque relevé par le lot
--- DEPENSES2 ; F251 : les PNJ meurent surtout en route vers les avant-postes lointains, F253 : ce qu'ils portent est perdu). La SOMME des alertes de
--- site, proches comprises, ne prend que ce qui DÉPASSE la réserve du QG (`left` = soldats libres moins Sd.reserve, moins ce que le QG menacé, une alerte
--- d'armée ou les alertes de fuite ont déjà pris) ; les alertes s'y servent par distance CROISSANTE au QG, par groupe ENTIER de Da.SITE_GROUP (le groupe
--- d'une alerte), sinon rien (jamais de soldats isolés). Aucune exception près du QG : à moins de 48 tuiles (SD.HQ_THREAT_R), une unité ennemie fait du QG
--- une menace (hq_en), défendue par TOUS les soldats avant les alertes.
Da.SITE_GROUP = 4
function Da.site_send(left)
  left = left or 0
  if left >= Da.SITE_GROUP then return Da.SITE_GROUP, left - Da.SITE_GROUP end
  return 0, left
end

--- s43 scen-raid (partie du DC 0.7.96, 4 h 15 : emerald, 5 à 12 soldats libres pour une réserve de Sd.RESERVE_MIN = 8, 216 alertes de site refusées
--- sur 251, centrale détruite 12 fois, équipe rasée) : une alerte sur une pièce CRITIQUE (centrale : pompe, chaudière, générateur ; ou tourelle) est servie
--- même sous la réserve quand le QG n'est pas attaqué : ce qui manque au groupe est pris dans la réserve (`res`, soldats libres de la réserve encore au QG),
--- au moins Da.CRITICAL_MIN soldats (jamais un soldat isolé). Le QG attaqué (l'appelant passe res = 0) garde tout.
Da.CRITICAL_ROLES = { pompe = true, chauffe = true, generateur = true } -- rôles du moteur (shared/ai3/reglages.lua, R.ENTITY_ROLE)
Da.CRITICAL_MIN = 2

--- Pièce critique ? `role` = R.ENTITY_ROLE[type] (nil permis), `turret` = le type est une tourelle (R.TURRET_TYPES).
function Da.critical(role, turret)
  return (turret == true or (role ~= nil and Da.CRITICAL_ROLES[role] == true)) and true or false
end

--- Envoi pour une alerte critique : d'abord au-dessus de la réserve (Da.site_send), sinon complété par la réserve. Rend n, left, res.
function Da.critical_send(left, res)
  left, res = left or 0, res or 0
  if left >= Da.SITE_GROUP then return Da.SITE_GROUP, left - Da.SITE_GROUP, res end
  local n = math.min(Da.SITE_GROUP, left + res)
  if n < Da.CRITICAL_MIN then return 0, left, res end
  return n, 0, res - (n - left)
end

--- `list` = { { d2 = distance au QG au carré, x, y, critical, ... } } (alertes de site vivantes) ; rend { { item, n, reserve } } dans l'ordre de service
--- (CRITIQUES d'abord, puis distance croissante, puis x, puis y) et ce qui reste au-dessus de la réserve. `res` (nil : 0, comportement d'avant) :
--- soldats de la réserve prêtables aux alertes critiques ; `reserve` vrai = groupe complété par la réserve. Pur : la liste d'entrée n'est pas modifiée.
function Da.site_plan(list, left, res)
  local order = {}
  for i, it in ipairs(list or {}) do order[i] = it end
  table.sort(order, function(a, b)
    local ca, cb = a.critical and 1 or 0, b.critical and 1 or 0
    if ca ~= cb then return ca > cb end
    if a.d2 ~= b.d2 then return a.d2 < b.d2 end
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)
  res = res or 0
  local out = {}
  for i, it in ipairs(order) do
    local n
    if it.critical and res > 0 then -- res 0 (QG attaqué, ou appel d'avant) : la règle d'avant, groupe entier au-dessus de la réserve
      local before = left
      n, left, res = Da.critical_send(left, res)
      out[i] = { item = it, n = n, reserve = (n > 0 and n > before) or nil }
    else
      n, left = Da.site_send(left)
      out[i] = { item = it, n = n }
    end
  end
  return out, left
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
