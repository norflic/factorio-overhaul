--[[
  Lot COMPAGNONS-ACTIFS (retour du DC du 29/10 en jouant la 0.6.18 : « la peur c'est bien, mais pour fuir si jamais ils se font
  attaquer. Mais sinon il faut revenir, il faut agir » ; « les décisions sont trop longues […] c'est vraiment du tac au tac »).
  Règles PURES (aucun appel au moteur) :
    - PEUR = attaque EN COURS : une mort de PNJ ne bloque plus une tâche PROCHE (but à moins de M.SAFE_RADIUS du QG) au-delà de
      A.FEAR_TICKS ; passé ce délai, la porte ne juge plus que les MENACES connues (fixes et mobiles) de la route et du but. Une tâche
      LOINTAINE garde la règle d'IA3-k (morts de l'heure : les PNJ meurent surtout en tournée lointaine, F239, F251).
    - RETOUR : une tâche refusée ou abandonnée pour danger revient au tableau après A.RETRY_DANGER ticks (30 s avant).
    - RÉPARATION des tourelles (toutes les équipes) : un relevé par A.TURRET_SCAN ticks, seuil A.TURRET_REPAIR_BELOW %.
    - Journal [FO-ACTIF] : délai d'affectation (création -> prise) des tâches prises, PNJ libres, tâches libres.
  Types du moteur seulement (aucun nom d'objet du jeu).
]]

local A = {}

A.FEAR_TICKS = 3600          -- 1 min : une mort plus ancienne n'est plus une attaque en cours (la menace, elle, reste jugée)
A.RETRY_DANGER = 600         -- 10 s : retour au tableau d'une tâche refusée / abandonnée pour danger (RETRY_TICKS 1800 sinon)
A.TURRET_SCAN = 600          -- 10 s : relevé des tourelles endommagées de l'équipe
A.TURRET_REPAIR_BELOW = 90   -- % : une tourelle sous 90 % de sa santé est réparée (60 % pour l'infrastructure électrique)
A.REPAIR_TYPES = { "ammo-turret", "electric-turret", "fluid-turret" } -- types du moteur (triés)
A.REPORT_EVERY = 18000       -- 5 min : bilan [FO-ACTIF] par équipe
A.LOG_GAP = 600              -- 10 s : une ligne [FO-ACTIF] de porte au plus par équipe et par cause

--- Morts de PNJ (non « home ») RÉCENTES (moins de A.FEAR_TICKS) à moins de r tuiles d'une polyligne `pts`, comptées une fois.
function A.recent_deaths(deaths, pts, r, tick, fear)
  local r2, n, w = r * r, 0, fear or A.FEAR_TICKS
  for _, d in ipairs(deaths or {}) do
    if not d.home and tick - d.t < w then
      for _, p in ipairs(pts) do
        local dx, dy = p.x - d.x, p.y - d.y
        if dx * dx + dy * dy <= r2 then n = n + 1 break end
      end
    end
  end
  return n
end

--- La porte doit-elle juger SANS les morts ? Vrai pour une tâche proche (not far) dont la route a des morts de l'heure (deaths > 0)
--- mais aucune récente (recent == 0) : l'attaque est finie, le PNJ revient agir ; la menace connue reste jugée par l'appelant.
function A.calm(far, deaths, recent)
  return (not far) and (deaths or 0) > 0 and (recent or 0) == 0
end

--- Entrée de la porte (D.gate) sans les morts : `tm` = danger des seules menaces le long de la route, `goal_t` = au but.
function A.calm_info(info, tm, goal_t, B)
  return { blocked = info.blocked and tm >= B, max_d = tm, goal_d = goal_t, deaths = 0, far = info.far }
end

--- Pause d'une tâche en échec avant son retour au tableau : `base` (RETRY_TICKS), doublée pour le fond ; A.RETRY_DANGER pour un
--- refus ou un abandon pour danger, une fuite ou une mise à l'abri (le PNJ revient dès que la menace est passée ; la porte rejuge).
A.FEAR_FAILS = { abri = true, danger = true, fuite = true } -- refus de la porte, rappel, demi-tour, fuite, mise à l'abri
function A.retry(fail, fond, base)
  if fail and A.FEAR_FAILS[fail] then return A.RETRY_DANGER end
  return fond and base * 2 or base
end

--- Délai d'affectation d'une tâche prise (cumuls dans `st`, table simple).
function A.note_claim(st, wait)
  if wait < 0 then wait = 0 end
  st.n = (st.n or 0) + 1
  st.sum = (st.sum or 0) + wait
  if wait > (st.max or 0) then st.max = wait end
  if wait <= 60 then st.fast = (st.fast or 0) + 1 end
end

--- Ligne du bilan (texte seul).
function A.report_line(key, tick, st, idle, free, gate)
  local n = st.n or 0
  return string.format("[FO-ACTIF] %s : bilan a %.1f min : %d PNJ libre(s), %d tache(s) libre(s) ; %d prise(s) en 5 min, delai d'affectation moyen %.1f s, max %.1f s, %d en moins de 1 s ; porte : %d tache(s) proche(s) jugee(s) sans morts anciennes (%d parties)",
    tostring(key), tick / 3600, idle, free, n, n > 0 and (st.sum / n) / 60 or 0, (st.max or 0) / 60, st.fast or 0, gate.calm or 0, gate.calm_go or 0)
end

return A
