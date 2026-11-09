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
Ga.CAP = 6      -- tourelles voulues au plus par avant-poste

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

return Ga
