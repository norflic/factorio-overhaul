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
Cc.STEAM_COMFORT = 0.75 -- tampon de vapeur bas : remplir tant que le coffre est sous cette part de la cible (= Vt.COMFORT)
Cc.CAP_SHARE = 0.9      -- part de la place du coffre visée au plus
Cc.PRIO = 91            -- URGENCE (O.URGENT_PRIO = M.URGENT = 90) : le courant de toute la base, juste devant « défendre d'abord » (90)
Cc.EVERY = 600          -- ticks entre deux relevés des centrales (projet d'alimentation)
Cc.MAX_TRIES = 4        -- refus du projet d'alimentation à la pause courte, par centrale (ensuite : pause longue)
Cc.RETRY_TICKS = 18000  -- 5 min de pause après un refus
Cc.LONG_RETRY_TICKS = 108000 -- 30 min de pause après Cc.MAX_TRIES refus (relecture : jamais d'abandon définitif)
Cc.PROJECT_PRIO = 80    -- priorité du projet d'alimentation (ses tâches de chantier : min(80 + 30, 89) = 89, Build.FINISH_CAP)
Cc.LOGS = 40            -- lignes [FO-CHARBON-CENTRALE] au plus par équipe
Cc.BUFFER_KEEP = 60     -- charbons laissés à un tampon d'avant-poste (de quoi ravitailler ses brûleurs : il ne se vide jamais pour la centrale)
Cc.BUFFER_MIN = 40      -- en dessous de ce reste utilisable, un voyage au tampon ne vaut pas la peine
Cc.BUFFER_LOGS = 12     -- lignes « tampon » au plus par équipe
--- Consommation de charbon (objets/s) à pleine charge : `kw` = somme des puissances de combustion des chaudières (kW, données),
--- `coal_kj` = énergie d'un charbon (kJ, données). 0 si rien.
function Cc.rate(kw, coal_kj)
  if not (kw and kw > 0 and coal_kj and coal_kj > 0) then return 0 end
  return kw / coal_kj
end

--- Lot BRULEURS-A-SEC (B4, banc V0676-D graine 123456789) : combustible du coffre du QG LIBRE pour la centrale = le stock moins la réserve
--- des tournées des brûleurs (la grandeur que shared/team/planner.lua retire du stock virtuel « avant toute fabrication » : fours de
--- l'équipe, brûleurs des avant-postes qui ne produisent pas le combustible). À 36,3 min, 400 charbons au coffre, 46 brûleurs de fer à sec
--- sur 60 (besoin 588) : la centrale (prio 91, cible 1080) prenait les 400, les brûleurs restaient à sec 45 min. Jamais négatif.
function Cc.free_fuel(stock, reserve)
  stock, reserve = stock or 0, reserve or 0
  if reserve >= stock then return 0 end
  return stock - reserve
end

--- Lot CHAUDIERES (partie du DC en 0.7.3, 84 foreuses en « low power », centrale à 1 800 kW sur 14 400) : la réserve des brûleurs que
--- Cc.free_fuel retire du stock est celle des tournées DUES, pas le complément de TOUS les brûleurs. Une tournée de ravitaillement ne part
--- que pour un groupe dont un brûleur est sous le seuil bas (planificateur : o.fuel_low -> service prio 95 ; fours : smelter_fuel_low) ; elle
--- porte alors le complément du groupe jusqu'à son niveau. Avant, le complément de chaque brûleur à 4-9 charbons (aucune tournée prévue)
--- restait réservé : banc CHAUDIERES graine 2507543475, player de 8 à 19 min, coffre du QG 23 à 70 charbons, réserve 28 à 99, libre 0,
--- coffre de la centrale sous son seuil pendant 11 min. groups = { { fill = niveau visé, levels = { charbon de chaque brûleur } } } ;
--- low = seuil bas (données de la config). Somme d'entiers, aucune API.
function Cc.tour_reserve(groups, low)
  local n = 0
  for _, g in ipairs(groups or {}) do
    local due, need = false, 0
    for _, x in ipairs(g.levels or {}) do
      if x < low then due = true end
      need = need + math.max(0, (g.fill or 0) - x)
    end
    if due then n = n + need end
  end
  return n
end

--- Remplissage du coffre de la centrale. n = charbon au coffre ; rate = consommation (Cc.rate) ; have = charbon LIBRE au coffre du QG
--- (hors la réserve des brûleurs, Cc.free_fuel) ;
--- cap = place du coffre en charbon (contenu compris), nil si inconnue. steam_low (lot TV-VAPEUR, V36) : le tampon de vapeur de la
--- centrale est bas (shared/team/vapeur_tampon.lua) : le remplissage est aussi dû tant que le coffre est sous le confort de la cible
--- (Cc.STEAM_COMFORT), même au-dessus du seuil d'avance. Rend { low, target, prio, due, count, why, short, steam }.
function Cc.refill(n, rate, have, cap, steam_low, chests)
  rate = rate or 0
  -- s43 cc-garde : `chests` (facultatif) = coffres de la centrale ; les planchers Cc.MIN_LOW / Cc.MIN_FILL valent pour la CENTRALE, partagés
  -- entre ses coffres comme la consommation (Cc.chest_rate). Avant : 2 x 400 charbons immobilisés au lieu de 400 dès la première centrale.
  local share = (chests and chests > 1) and chests or 1
  local low = math.max(math.ceil(Cc.MIN_LOW / share), math.ceil(rate * Cc.LEAD_S - 1e-9))
  local target = math.max(math.ceil(Cc.MIN_FILL / share), math.ceil(rate * Cc.FILL_S - 1e-9))
  if cap and cap > 0 then
    local top = math.floor(cap * Cc.CAP_SHARE)
    if target > top then target = top end
    -- le seuil reste sous la cible (un petit coffre : la moitié de la cible)
    if low > math.floor(target / 2) then low = math.floor(target / 2) end
  end
  local r = { low = low, target = target, prio = Cc.PRIO, due = false, count = 0 }
  local trigger = low
  if steam_low then trigger = math.max(low, math.floor(target * Cc.STEAM_COMFORT)) end
  if n >= trigger then r.why = "au-dessus du seuil" return r end
  r.steam = (n >= low) or nil -- au-dessus du seuil d'avance : c'est le tampon de vapeur qui déclenche
  if not have or have <= 0 then r.why, r.short = "coffre du QG sans charbon", true return r end
  r.count = math.min(target - n, have)
  if r.count <= 0 then r.why = "rien a porter" return r end
  r.due, r.why = true, r.steam and "tampon de vapeur bas" or "sous le seuil"
  return r
end

--- Tampon de charbon (RECHERCHE-BRAS suite, COMBUSTIBLE-CENTRALE levier a, 8/11 : « les PNJ remplissent les chaudières depuis les coffres des
--- foreuses ou un tampon, priorité vitale ») : le coffre de la centrale est sous son seuil ET le coffre du QG n'a plus de charbon (Cc.refill
--- rend `short`) : les coffres de sortie des avant-postes de charbon (buffers = { { id, x, y, count, d2 }, ... }) portent le complément.
--- Un tampon garde Cc.BUFFER_KEEP charbons (ses brûleurs) ; sous Cc.BUFFER_MIN utilisables, il est écarté. Préférence : un tampon qui couvre
--- seul le besoin `want` (le plus proche, d2), sinon le plus garni ; à égalité, id puis x puis y (ordre total). Rend { buffer, count } ou nil
--- et la raison.
function Cc.pick_buffer(buffers, want, keep)
  keep = keep or Cc.BUFFER_KEEP
  if not (want and want > 0) then return nil, "rien a porter" end
  local cands = {}
  for _, b in ipairs(buffers or {}) do
    local usable = (b.count or 0) - keep
    if usable >= Cc.BUFFER_MIN then cands[#cands + 1] = { buffer = b, usable = usable, covers = usable >= want } end
  end
  if #cands == 0 then return nil, "aucun tampon utilisable" end
  table.sort(cands, function(p, q)
    if p.covers ~= q.covers then return p.covers end
    if p.covers then
      if (p.buffer.d2 or 0) ~= (q.buffer.d2 or 0) then return (p.buffer.d2 or 0) < (q.buffer.d2 or 0) end
    elseif p.usable ~= q.usable then return p.usable > q.usable end
    if tostring(p.buffer.id) ~= tostring(q.buffer.id) then return tostring(p.buffer.id) < tostring(q.buffer.id) end
    if (p.buffer.x or 0) ~= (q.buffer.x or 0) then return (p.buffer.x or 0) < (q.buffer.x or 0) end
    return (p.buffer.y or 0) < (q.buffer.y or 0)
  end)
  return { buffer = cands[1].buffer, count = math.min(want, cands[1].usable) }
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

-- Lot s42 charbon-centrale (chantier 3.1 du DC, partie de 4 h 15 en 0.7.96 : « toute l'électricité dépend d'un seul coffre et d'un bras
-- thermique ») : (a) DEUX entrées de combustible indépendantes par centrale neuve (deux coffres, deux bras ; le premier bras reste à
-- combustion pour le démarrage à froid, le second est électrique quand l'équipe en a un) ; (b) la ligne de foreuses de la centrale est
-- dimensionnée à la consommation nominale des chaudières × Cc.ALIM_MARGIN.
Cc.ALIM_MARGIN = 1.3    -- marge de la ligne de charbon dédiée (exigence du DC : besoin = consommation nominale × 1,3)
Cc.ENTRIES = 2          -- entrées de combustible (coffre + bras) d'une centrale neuve

--- Débit (objets/s) que la ligne de foreuses de la centrale doit porter : consommation nominale (Cc.rate) × Cc.ALIM_MARGIN.
function Cc.alim_rate(kw, coal_kj)
  return Cc.rate(kw, coal_kj) * Cc.ALIM_MARGIN
end

--- Entrées de combustible d'une centrale neuve. burner = nom du bras à combustion ; electric = nom du bras électrique (ou nil) ;
--- stock = bras électriques au coffre de l'équipe. Rend (nombre d'entrées, bras de la 2e entrée). Le bras de la PREMIÈRE entrée reste
--- `burner` (démarrage à froid : sans courant, un bras électrique ne bouge pas) ; la seconde prend un bras électrique s'il y en a un
--- au coffre (jamais une réserve de matériaux en attente pour lui), sinon un second bras à combustion.
function Cc.entries(burner, electric, stock)
  if electric and electric ~= burner and (stock or 0) >= 1 then return Cc.ENTRIES, electric end
  return Cc.ENTRIES, burner
end

--- s43 cc-garde (banc s43-parite-seule, 4 graines : la release perd 25 745 plaques de fer à 60 min contre le retrait du lot, -6,4 %) : la SECONDE
--- entrée d'une centrale neuve (coffre, bras, tête de tapis élargie) n'est prévue que si l'équipe a déjà une centrale FINIE, un réseau SAIN et
--- au moins Cc.SECOND_COAL charbons au stock : la première centrale, celle du départ, garde la tête d'avant (une entrée), payée plus tôt.
--- c = { plants_done (centrales finies), healthy (santé du réseau), coal (charbon au stock) }. Rend vrai si la seconde entrée est prévue.
Cc.SECOND_COAL = 0
function Cc.second_ok(c)
  return c ~= nil and (c.plants_done or 0) >= 1 and c.healthy == true and (c.coal or 0) >= Cc.SECOND_COAL
end

--- Consommation attribuée à UN coffre d'une centrale qui en a `chests` (seuil et cible de Cc.refill par coffre) : la consommation
--- partagée, pour que deux coffres ne retiennent pas deux fois l'avance. Un seul coffre (ou compte inconnu) : la consommation entière.
function Cc.chest_rate(rate, chests)
  rate = rate or 0
  if not chests or chests <= 1 then return rate end
  return rate / chests
end

--- Pièces de la tête à deux entrées (`two`) qui ne sont pas à la place d'une pièce de la tête à une entrée (`one`) : celles dont le
--- terrain est à vérifier avant de retenir les deux entrées (listes de { x, y }). Ordre de `two` gardé.
function Cc.extras(one, two)
  local seen = {}
  for _, e in ipairs(one or {}) do seen[e.x .. "," .. e.y] = true end
  local out = {}
  for _, e in ipairs(two or {}) do if not seen[e.x .. "," .. e.y] then out[#out + 1] = e end end
  return out
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

-- Lot s50 centrale-tapis (partie du DC en 0.7.107 : « foreuses : attente » = moitié des refus du tapis, centrales 7 et 8 de player à
-- la main toute la partie) : « attente » (paire du tracé en pause après un échec, Trav.route) et « budget tick » (plafond d'états du
-- tick) ne sont pas des refus du plan : le projet reste ouvert et réessaie après Cc.TRANSIENT_WAIT, sans compter vers la pause longue.
Cc.TRANSIENT_WAIT = 1800 -- (repère historique, 0.7.109) ; 0.7.110 : attente croissante Cc.transient_wait
-- 0.7.110 (partie du DC en x5 : 30 s de jeu = 6 s réelles) : attente croissante par projet, 2 min, 5 min puis 15 min (n = essais passagers déjà faits)
Cc.TRANSIENT_STEPS = { 7200, 18000, 54000 }
function Cc.transient_wait(n)
  local k = math.min((n or 0) + 1, #Cc.TRANSIENT_STEPS)
  return Cc.TRANSIENT_STEPS[k]
end
function Cc.transient(why)
  return why == "attente" or why == "budget tick"
end

return Cc
