--[[
  Lot CHARBON-CENTRALE (retour du DC du 29/10 vers 22 h 25, en jouant la 0.6.18, fo-logs/2026-10-29_RETOUR/RETOUR_DC_9_0.6.18.md) :
  « Il y a un coffre qui met du charbon sur le tapis pour l'électricité de toute la base et ils ont oublié de le remplir, d'où l'idée
  vraiment ou alors ils ont pas eu le temps, mais d'où l'idée d'automatiser. […] on automatise tout, le charbon […] le charbon qui
  est récolté dans l'électrique retourne dans l'usine électrique. »

  Cause lue au journal de sa partie (factorio-current.log, 0.6.18) : la centrale de scarlet « a sec » 8 fois, coffre(coal)=0 à 57,6,
  70,1, 92,4, 148,9, 207,4, 274,5 et 294,8 min. Le coffre de la centrale (quai d'entrée, script/team/build.lua quai_tasks) n'était
  rempli qu'au-dessous de 60 charbons (2,2 min d'une chaudière à pleine charge, 0,45/s), par une tâche de priorité 63 (celle du projet
  + 3), sous les packs, les kits et la reconstruction (70 à 89) ; et le bilan du charbon du planificateur (Build.burn_rate) ne comptait
  pas les chaudières. Jamais de foreuses pour la centrale : sa voie de charbon (0,45/s) restait sous P.AUTO_FLOW (1/s).

  Règles PURES (aucune API Factorio, aucun nom d'objet ; testées hors jeu par tests/charbon_centrale_test.lua) :
  1. REMPLISSAGE (Cc.refill) : seuil d'AVANCE = consommation à pleine charge × Cc.LEAD_S (jamais moins que l'ancien seuil) ; cible =
     consommation × Cc.FILL_S (jamais moins que l'ancienne charge), bornée par le coffre ; tâche URGENTE (Cc.PRIO ≥ 90, prise par
     n'importe quel PNJ) dès que le coffre passe sous le seuil, AVANT qu'il soit vide. Coffre du QG sans charbon : pas de tâche
     possible, la cause est rendue (le journal la dit ; le bilan du charbon compte les chaudières nourries à la main).
  2. AUTOMATISATION (Cc.want_alim) : une centrale finie encore nourrie par son coffre demande un projet « alimentation de la
     centrale » (foreuses sur le gisement de charbon le plus proche, tapis jusqu'à sa tête d'alimentation) ; un seul ouvert à la fois
     par équipe ; après un refus, pause de Cc.RETRY_TICKS, puis de Cc.LONG_RETRY_TICKS à partir de Cc.MAX_TRIES refus (relecture :
     JAMAIS d'abandon définitif ; un refus passager, centrale rouverte ou gisement hors du treillis qui grandit, ne doit pas laisser la
     centrale à la main pour toute la partie : « on automatise tout »). Le coffre RESTE en secours : sur un tapis plein
     (foreuses qui suffisent) son bras ne dépose rien ; il ne se vide que si les foreuses ne suffisent plus (gisement épuisé, foreuses
     détruites, centrale arrêtée : les foreuses sont électriques), et la règle 1 le remplit alors en urgence.
]]
local Cc = {}

Cc.LEAD_S = 240         -- secondes d'avance du seuil (aller du PNJ depuis le coffre du QG, attente d'un PNJ libre)
Cc.FILL_S = 1200        -- secondes de charbon visées au coffre après un remplissage (20 min à pleine charge)
Cc.MIN_LOW = 60         -- seuil jamais plus bas que celui d'avant le lot (Build.QUAI_LOW)
Cc.MIN_FILL = 400       -- cible jamais plus basse que la charge d'avant le lot (Build.QUAI_FILL)
Cc.CAP_SHARE = 0.9      -- part de la place du coffre visée au plus
Cc.PRIO = 91            -- URGENCE (O.URGENT_PRIO = M.URGENT = 90) : le courant de toute la base, juste devant « défendre d'abord » (90)
Cc.EVERY = 600          -- ticks entre deux relevés des centrales (projet d'alimentation)
Cc.MAX_TRIES = 4        -- refus du projet d'alimentation à la pause courte, par centrale (ensuite : pause longue)
Cc.RETRY_TICKS = 18000  -- 5 min de pause après un refus
Cc.LONG_RETRY_TICKS = 108000 -- 30 min de pause après Cc.MAX_TRIES refus (relecture : jamais d'abandon définitif)
Cc.PROJECT_PRIO = 80    -- priorité du projet d'alimentation (ses tâches de chantier : min(80 + 30, 89) = 89, Build.FINISH_CAP)
Cc.LOGS = 40            -- lignes [FO-CHARBON-CENTRALE] au plus par équipe

-- Lot TV-ENERGIE (V36, TODO_VIDEO.md l.102 : « check if the steam in the storage tanks has gone below a certain threshold … feed fuel cells » :
-- le combustible se règle sur le TAMPON d'énergie, pas seulement sur la consommation). Le seuil d'avance de Cc.refill suppose un tampon de
-- vapeur plein (il couvre l'aller du PNJ, Cc.LEAD_S). Quand le tampon des machines à vapeur (vapeur contenue / capacité) reste sous
-- Cc.STEAM_LOW pendant Cc.STEAM_CHECKS relevés de suite (5 s chacun : 15 s), la chaudière n'est plus alimentée assez vite : le coffre se remplit
-- AVANT le seuil de consommation, dès qu'il passe sous la moitié de la cible (Cc.STEAM_FILL). Mesure : Sante.observe (script/team/sante_centrale.lua).
Cc.STEAM_LOW = 0.25     -- part du tampon de vapeur au-dessous de laquelle il est dit bas
Cc.STEAM_CHECKS = 3     -- relevés de suite sous Cc.STEAM_LOW avant d'avancer le remplissage
Cc.STEAM_FILL = 0.5     -- part de la cible au-dessous de laquelle le coffre se remplit quand le tampon est bas

--- Consommation de charbon (objets/s) à pleine charge : `kw` = somme des puissances de combustion des chaudières (kW, données),
--- `coal_kj` = énergie d'un charbon (kJ, données). 0 si rien.
function Cc.rate(kw, coal_kj)
  if not (kw and kw > 0 and coal_kj and coal_kj > 0) then return 0 end
  return kw / coal_kj
end

--- Lot TV-ENERGIE (V36) : suivi du tampon de vapeur d'une centrale. st = mémoire { steam_n } (nombres) ; frac = vapeur contenue / capacité des
--- machines à vapeur à ce relevé (0 à 1), nil si la mesure manque. Rend vrai quand le tampon est bas depuis Cc.STEAM_CHECKS relevés de suite ;
--- une mesure absente ou un tampon rempli remet le compte à zéro (jamais d'avance sur une mesure qu'on n'a pas).
function Cc.steam_track(st, frac)
  if type(frac) == "number" and frac == frac and frac < Cc.STEAM_LOW then st.steam_n = (st.steam_n or 0) + 1 else st.steam_n = 0 end
  return st.steam_n >= Cc.STEAM_CHECKS
end

--- Remplissage du coffre de la centrale. n = charbon au coffre ; rate = consommation (Cc.rate) ; have = charbon au coffre du QG ;
--- cap = place du coffre en charbon (contenu compris), nil si inconnue ; steam_low (lot TV-ENERGIE, V36) = le tampon de vapeur est bas
--- (Cc.steam_track), nil/faux sinon. Rend { low, target, prio, due, count, why, short, by_steam }.
function Cc.refill(n, rate, have, cap, steam_low)
  rate = rate or 0
  local low = math.max(Cc.MIN_LOW, math.ceil(rate * Cc.LEAD_S - 1e-9))
  local target = math.max(Cc.MIN_FILL, math.ceil(rate * Cc.FILL_S - 1e-9))
  if cap and cap > 0 then
    local top = math.floor(cap * Cc.CAP_SHARE)
    if target > top then target = top end
    -- le seuil reste sous la cible (un petit coffre : la moitié de la cible)
    if low > math.floor(target / 2) then low = math.floor(target / 2) end
  end
  local r = { low = low, target = target, prio = Cc.PRIO, due = false, count = 0 }
  -- tampon de vapeur bas : le coffre se remplit dès qu'il passe sous la moitié de la cible, même au-dessus du seuil de consommation
  if steam_low and n >= low then
    local lift = math.floor(target * Cc.STEAM_FILL)
    if n < lift then r.low, low, r.by_steam = lift, lift, true end
  end
  if n >= low then r.why = "au-dessus du seuil" return r end
  if not have or have <= 0 then r.why, r.short = "coffre du QG sans charbon", true return r end
  r.count = math.min(target - n, have)
  if r.count <= 0 then r.why = "rien a porter" return r end
  r.due, r.why = true, r.by_steam and "tampon de vapeur bas" or "sous le seuil"
  return r
end

--- La centrale est-elle nourrie par des foreuses ? kinds = genres de ses parties (« foreuses » : prévues à son plan, débit au-delà de
--- P.AUTO_FLOW) ; alim_state = état de SON projet d'alimentation (nil sans projet). Un projet rouvert (pièces détruites) ne l'est pas.
function Cc.automated(kinds, alim_state)
  for _, k in ipairs(kinds or {}) do if k == "foreuses" then return true end end
  return alim_state == "fini"
end

--- Faut-il demander le projet d'alimentation de cette centrale ? st = sa mémoire { tries, retry_at } ; c = { automated, quai (la
--- centrale a un coffre de charbon), alim_open (son projet d'alimentation est en cours), other_open (celui d'une autre centrale),
--- tick, off (réglage de banc) }. Rend true, ou false et la raison.
function Cc.want_alim(st, c)
  if c.off then return false, "regle coupee" end
  if c.automated then return false, "deja automatisee" end
  if not c.quai then return false, "pas de coffre de charbon" end
  if c.alim_open then return false, "projet en cours" end
  if c.other_open then return false, "un autre projet d'alimentation est en cours" end
  if (c.tick or 0) < (st.retry_at or 0) then return false, "pause apres un refus" end
  return true
end

--- Pause (ticks) après le refus numéro `tries` : courte jusqu'à Cc.MAX_TRIES, longue ensuite (jamais d'abandon définitif).
function Cc.pause(tries)
  return ((tries or 0) < Cc.MAX_TRIES) and Cc.RETRY_TICKS or Cc.LONG_RETRY_TICKS
end

--- Le projet d'alimentation a été refusé (plan impossible : pas de gisement à portée, pas de tracé) ou abandonné. grew (lot ENERGIE,
--- relecture) : le refus a fait grandir le treillis ; il ne compte pas vers la pause longue, le prochain essai voit de nouveaux lots
--- (le nombre de ces refus est borné par le rayon maximal du treillis).
function Cc.refused(st, tick, grew)
  st.tries = (st.tries or 0) + (grew and 0 or 1)
  st.retry_at = tick + Cc.pause(st.tries)
  st.alim = nil
end

--- Arrivées possibles du tapis des foreuses à la tête d'alimentation (tuile x, y du dernier tapis de la tête, direction d ; dv = vecteur
--- de d ; lv = vecteur de la gauche de d) : derrière la tête, tout droit (les deux voies), puis par la gauche et par la droite (la tête
--- devient un virage). Rend { { x, y, dir } } (dir : sens de la dernière tuile du tapis qui arrive) ; dir_of(dx, dy) donne la direction.
function Cc.arrivals(x, y, dv, lv, d, dir_of)
  return {
    { x = x - dv[1], y = y - dv[2], dir = d },
    { x = x + lv[1], y = y + lv[2], dir = dir_of(-lv[1], -lv[2]) },
    { x = x - lv[1], y = y - lv[2], dir = dir_of(lv[1], lv[2]) },
  }
end

return Cc
