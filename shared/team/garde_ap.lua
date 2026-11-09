--[[
  Lot DEFENSE-AP : la GARDE d'un avant-poste se dimensionne sur la MENACE, pas seulement sur ses foreuses. PUR (aucune API Factorio, aucun
  nom d'objet : l'appelant passe des nombres ; testé hors jeu par tests/garde_ap_test.lua, mutants compris).

  Mesure (fo-logs/2026-11-09_DEFENSE-AP/diag1, partie neuve etape1-guide de 40 min, votre équipe) : l'avant-poste de fer (16 à 18
  foreuses, 119 tuiles du QG, 8 nids qui visent l'équipe) n'avait que T.defend_turrets(foreuses) = 3 tourelles (574 PV chacune) ; la
  prévision lui voyait une vague de 294 PV à 5 min, 1750 PV à 10 min (défense 1724 PV : rapport 1,01) et 2457 PV à 15 min (rapport
  1,42). Les 3 tourelles d'avance du front, posées une à une, sont mortes à 12,2 à 12,5 min, celles de l'avant-poste à 15,1 min ; le
  fer de l'équipe est tombé à 0 et n'est jamais revenu : on ne livre plus de fer, donc plus de tourelle. La règle d'avant ne
  regardait que le nombre de foreuses (1 + foreuses / 8) : une vague de 1750 PV ne changeait rien à la garde voulue.

  Règle : tourelles voulues = le plus grand de (a) la règle d'avant (`base`) et (b) ce qu'il faut pour que la défense atteigne la
  PLUS GRANDE vague connue du site × la marge de la prévision (Pc.MARGE, 1,1) : vague prévue à 5 min, vague prévue à 15 min, plus
  grosse vague REÇUE par le site dans la mémoire de la prévision (Pv.mem_floor : un fait, vrai même quand le modèle ne voit plus de nid).
  Plafonnée (Ga.CAP) : une garde au-delà ne se paie pas avec le fer d'un début de partie, et l'écart restant revient à la prévision
  (cadre « préparer », soldats). Rien n'est RETIRÉ à la défense : la règle ne fait que relever le nombre voulu ; la poser et la payer
  restent le travail des postes du planificateur (fortify, priorité T.defend_prio) et de ses planchers de fer (Sq.floors).
  Entiers uniquement, aucun `pairs`, aucun hasard, aucun temps mesuré.
]]

local Ga = {}

Ga.MARGE = 1100 -- ‰ : défense visée = 1,1 × la plus grande vague connue (même valeur que Pc.MARGE, shared/ai3/prevision_choix.lua)
Ga.HQ_MARGE = 2000 -- ‰ : le QG vise 2 x la plus grosse vague reçue (mesure fonds-on-20261020 : le QG à 4-5 tourelles tombe à 59 min sous des vagues de 2 000 à 2 500 PV
                    -- qui se suivent ; les tourelles tombent une à une, 1,1 x ne suffit pas) ; la garde d'avant-poste garde la marge 1,1
Ga.CAP = 0      -- tourelles voulues au plus par avant-poste. 0 = GARDE D'AVANT-POSTE COUPÉE (décision de l'intégrateur, 9/11 : effet non prouvé sur 8 graines,
                -- voir tests/garde_ap_test.lua) ; 6 était la valeur essayée. Le QG (Ga.hq_want) ne dépend pas de cette constante.

local function num(x)
  if type(x) ~= "number" or x ~= x or x < 0 then return 0 end
  return x
end

--- a = { base (règle d'avant, tourelles), w5, w15 (PV prévus du site), mem (PV de la plus grosse vague reçue), tv (PV d'une
--- tourelle de plus) }. Rend (voulues, vague retenue en PV, raison) ; raison : "base" (la règle d'avant suffit ou menace inconnue),
--- "menace" (relevée par la menace), "plafond" (relevée et bornée par Ga.CAP).
function Ga.want(a)
  a = a or {}
  local base = math.floor(num(a.base))
  local tv = num(a.tv)
  local w = math.max(num(a.w5), num(a.w15), num(a.mem))
  if tv <= 0 or w <= 0 then return base, w, "base" end
  local need = math.ceil(w * Ga.MARGE / 1000 / tv - 1e-9)
  if need <= base then return base, w, "base" end
  if need > Ga.CAP then
    if Ga.CAP <= base then return base, w, "base" end
    return Ga.CAP, w, "plafond"
  end
  return need, w, "menace"
end

--- Lot DEFENSE-AP, QG : assurance du coffre quand le fer est là. Mesure (fo-logs/2026-11-09_INTEG-0673/long432-b2f727e4, graine 20261020,
--- partie de 2 h) : à 50 min une vague de 4 575 PV frappe les avant-postes (ap6), le QG entre en péril avec 3 tourelles et en veut 5 (la menace
--- reçue AILLEURS ne compte qu'à moitié pour lui), alors que le coffre tient 1 365 plaques de fer ; à 53,6 min 176 à 235 petites unités
--- attaquent le QG (4 tourelles, 62 chargeurs), qui tombe à 54,9 min : l'équipe finit. Règle : le QG veut de quoi couvrir la PLUS GROSSE vague
--- reçue n'importe où (marge Ga.MARGE), jusqu'à `cap` tourelles, mais seulement ce que le fer au-dessus de `reserve` PAIE (`cost` plaques par
--- tourelle garnie) : jamais plus que la règle d'avant sans vague connue, ni plus que le coffre ne paie. a = { base (règle d'avant), have
--- (tourelles posées), cap, threat (PV de la plus grosse vague reçue), min (PV en dessous desquels rien ne change), tv (PV d'une tourelle),
--- funds (plaques de fer), cost (plaques par tourelle garnie), reserve (plaques gardées) }. Rend (voulues, raison) : "base" | "menace" |
--- "fer" (bornée par le fer) | "plafond".
function Ga.hq_want(a)
  a = a or {}
  local base, have, cap = math.floor(num(a.base)), math.floor(num(a.have)), math.floor(num(a.cap))
  local tv, threat = num(a.tv), num(a.threat)
  if tv <= 0 or threat <= 0 or threat < num(a.min) or cap <= base then return base, "base" end
  local need = math.ceil(threat * Ga.HQ_MARGE / 1000 / tv - 1e-9)
  if need <= base then return base, "base" end
  local want, why = need, "menace"
  if want > cap then want, why = cap, "plafond" end
  local cost = num(a.cost)
  local pay = cost > 0 and math.floor(math.max(0, num(a.funds) - num(a.reserve)) / cost) or 0
  local payable = math.max(have, base) + pay
  if want > payable then want, why = payable, "fer" end
  if want <= base then return base, "base" end
  return want, why
end

--- Lot DEFENSE-AP, FONDS DE DÉFENSE. Mesure (fo-logs/2026-11-09_DEFENSE-AP/long-1618, graine 1618033988, 120 min) : l'avant-poste de FER est à
--- 0 tourelle sur 3 voulues de 40 à 75 min ([FO-DEFENSE] « 1 0/3 manque iron-plate 80 à 256 »), les 28 PNJ libres n'agrandissent rien
--- ([FO-ZERO-IDLE] « iron=non_defendu »), le fer du coffre reste à 0-23 : 60 à 90 plaques arrivent par minute et partent en chargeurs de
--- réserve (24 à 84 par minute, le coffre en tenait déjà 81 à 130), en modules et en science, par petites sommes, avant que la tourelle (40
--- plaques + plancher de 150) soit payable : une grosse dépense ne s'accumule jamais face à un flot de petites. Règle : tant que la plaque
--- clé a un avant-poste SANS AUCUNE tourelle (pas de « production d'abord »), (a) le plancher de fer et de cuivre de ce poste descend aux
--- planchers du péril, (b) le fer de la tourelle manquante (au plus `cost`) est MIS DE CÔTÉ : les projets du cerveau ne le voient pas
--- (shared/ai3/cerveau.lua, C.consumed). Rien n'est retiré à la défense : la retenue ne vise que ce que les autres dépenses prendraient.
Ga.FUND_ON = true

--- Un poste est CRITIQUE s'il garde la plaque clé (`iron`) et n'a aucune tourelle alors qu'il en veut.
function Ga.critical(iron, have, want)
  return Ga.FUND_ON and iron == true and num(have) <= 0 and num(want) > 0
end

--- Fer mis de côté : min(fer libre, coût en fer de ce qui manque) pour un poste critique hors « production d'abord », sinon 0.
function Ga.fund(a)
  a = a or {}
  if not a.critical or a.production_first then return 0 end
  return math.floor(math.min(num(a.avail), num(a.cost)))
end

return Ga
