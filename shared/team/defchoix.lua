--[[
  Lot DEFENSE-CHOIX (retour du DC du 29/10 en jouant la 0.6.18, défauts 5 et 6). Règle PURE (aucune API Factorio, aucun nom d'objet :
  l'appelant passe des nombres lus au livre de recettes), déterministe, testée hors jeu par tests/defchoix_test.lua (avec mutants).

  Constat du DC (texte intégral : fo-logs/2026-10-29_RETOUR/RETOUR_DC_7_0.6.18.md) :
    (5) « ils ont encore du fer, ils ont 600 de fer en réserve, 600 environ de cuivre [...] ils peuvent faire des tourelles. Les
        tourelles, ça coûte combien ? [...] ça coûte pas si cher que ça, ils ont largement les ressources pour les faire. Et payer des
        soldats, et ben écoutez, des fois c'est peut-être pas la meilleure solution. »
    (6) « ils vont quand même pas attaquer une équipe alors qu'ils sont ils ont pas du tout ils ont pas du tout sécurisé. Bah si. »

  Cause lue dans le code (0.6.18) :
    (5) une FACTION ne voulait de tourelles au QG que si elle en avait PERDU une ET que son QG avait été occupé par les biters
        (shared/team/front.lua F.hq_post : 0 sinon, 2 au plus) ; les tourelles du front ne se posent pas tant qu'un ennemi est à moins de
        F.CALM_R tuiles de la cellule (pendant l'attaque, donc) ; pendant ce temps, la menace (`view.threatened`) faisait recruter des
        soldats en urgence (priorité 85, shared/team/planner.lua). Avec 600 de fer : des soldats, aucune tourelle.
    (6) la décision d'attaque entre factions (script/faction/pvp.lua, PvP.think -> Military.attack) ne regardait pas l'état de la base.

  Règles :
    D.base   base MENACÉE ou ENVAHIE : une perte près du QG depuis moins de D.ALERT_TICKS (l'alerte du commandant ne dure que
             D.THREAT_TICKS), le QG occupé par les biters (f.hq_lethal_tick, T.hq_lethal_ticks), ou des unités ennemies à moins de
             D.BASE_R tuiles du QG (compte fait par l'appelant).
    D.turrets  base menacée ET le fer (et le cuivre) au-dessus des planchers de la défense paient au moins UNE tourelle avec ses
             chargeurs : le QG veut des tourelles jusqu'à min(D.HQ_CAP, tourelles du QG + tourelles payables) ; les tourelles passent
             AVANT la levée de soldats d'urgence (la pensée qui commande les tourelles ne lance pas aussi la levée : elle reprend dès que la
             tâche de pose est ouverte, avec le fer qui reste).

  Coût-efficacité (documenté, simple ; chiffres vanilla lus au livre par tests/defchoix_test.lua) : une tourelle avec ses 20 chargeurs coûte
  à peu près le double d'un fusilier équipé (tourelle 40 fer + 10 cuivre, 20 chargeurs 80 fer ; fusilier : mitraillette 30 fer + 5 cuivre,
  5 chargeurs 20 fer), pour un tir du même ordre (même chargeur), mais 400 PV contre 250, aucune marche, aucune peur, aucune perte en route :
  POUR TENIR LA BASE, LES TOURELLES ; les soldats bougent : POUR LES RAIDS (et la garde ordinaire, inchangée).
]]

local D = {}

D.THREAT_TICKS = 900       -- durée de l'alerte posée par le commandant à une perte près du QG (script/faction/commander.lua la lit ICI)
D.ALERT_TICKS = 2 * 3600   -- base « menacée » tant que la dernière perte près du QG date de moins de 2 min
D.BASE_R = 48              -- tuiles : une unité ennemie à moins de cela du QG = base ENVAHIE (compte fait par l'appelant)
D.HQ_CAP = 8               -- tourelles voulues au QG au plus quand la base est menacée (les 8 emplacements autour du QG, Outposts.fortify)

D.WHY_INVADED = "envahie"
D.WHY_HQ = "qg_occupe"
D.WHY_LOSSES = "pertes"

local function num(x)
  if type(x) ~= "number" or x ~= x then return nil end
  return x
end

--- État de la base. a = { tick, threatened_until (f.threatened_until, 0 ou nil : jamais), hq_lethal_tick (nil : jamais), lethal_ticks,
--- invaders (unités ennemies comptées à moins de D.BASE_R tuiles du QG) }. Rend { insecure, why, ago (ticks depuis la dernière perte,
--- nil : aucune) }.
function D.base(a)
  a = a or {}
  local tick = num(a.tick) or 0
  local out = { insecure = false }
  local tu = num(a.threatened_until)
  if tu and tu > 0 then out.ago = tick - (tu - D.THREAT_TICKS) end
  if (num(a.invaders) or 0) > 0 then
    out.insecure, out.why = true, D.WHY_INVADED
  elseif num(a.hq_lethal_tick) and tick - a.hq_lethal_tick < (num(a.lethal_ticks) or 0) then
    out.insecure, out.why = true, D.WHY_HQ
  elseif out.ago and out.ago >= 0 and out.ago < D.ALERT_TICKS then
    out.insecure, out.why = true, D.WHY_LOSSES
  end
  return out
end

--- Tourelles voulues au QG. a = { alert (base menacée), want (tourelles voulues sans cette règle), have (tourelles du QG), ok (une tourelle
--- est fabricable ou au stock), busy (tâche de pose du QG déjà ouverte), funds_iron, cost_iron, funds_copper, cost_copper (fer et cuivre
--- AU-DESSUS des planchers de la défense ; coût d'UNE tourelle avec ses chargeurs) }.
--- Rend { want, first (des tourelles du QG manquent et se paient : elles passent avant les soldats), hold_soldiers (cette pensée ne lance
--- pas la levée d'urgence), paid (tourelles payables), why }.
function D.turrets(a)
  a = a or {}
  local want0 = num(a.want) or 0
  local have = num(a.have) or 0
  local out = { want = want0, first = false, hold_soldiers = false, paid = 0 }
  if not a.alert then out.why = "calme" return out end
  if not a.ok then out.why = "recette" return out end
  local function count(funds, cost)
    funds, cost = num(funds) or 0, num(cost) or 0
    if cost <= 0 then return math.huge end
    if funds <= 0 then return 0 end
    return math.floor(funds / cost)
  end
  local paid = math.min(count(a.funds_iron, a.cost_iron), count(a.funds_copper, a.cost_copper))
  if paid == math.huge then paid = D.HQ_CAP end
  out.paid = paid
  if paid < 1 then out.why = "fonds" return out end
  local target = math.max(want0, math.min(D.HQ_CAP, have + paid))
  out.want = target
  out.first = target > have
  out.hold_soldiers = out.first and not a.busy
  out.why = out.first and "tourelles" or "complet"
  return out
end

--- Une faction peut-elle LANCER une attaque contre une autre faction ? Non tant que sa base est menacée ou envahie (`base` : rendu de D.base).
function D.may_attack(base)
  return not (base and base.insecure)
end

return D
