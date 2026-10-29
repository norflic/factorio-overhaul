--[[
  Lot CAPI-ANNULATION « un ordre qui attend ses matériaux n'est pas bloqué » (défaut mesuré au lot POTEAUX-UNIQUES,
  graine 314159265, faction scarlet : deux projets en réserve annulés « aucun progrès en 30 min » à 34,1 min alors que
  leur manque baissait et que le témoin en terminait un à 35,3 min). PUR (aucune API Factorio), testé hors jeu
  (tests/ordre_progres_test.lua).

  Le runtime (script/ai3/capitalisation.lua) retire un ordre « module » de la capitalisation quand il n'avance plus
  depuis Op.TTL. Avant ce lot, seul le nombre d'entités POSÉES comptait comme avancement : pendant la phase de réserve
  (le chantier prend les matières au coffre au fil de l'eau), rien n'est posé, donc une réserve qui se remplit
  lentement paraissait figée. Le minuteur d'AUTO (script/ai3/automatisation.lua, reserve_clock) compte, lui, la baisse
  du manque comme un progrès : les deux minuteurs ne mesuraient pas la même chose.

  Règle, sur un enregistrement d'ordre `rec` (nombres seulement : il vit dans `global`) :
    A. PROGRÈS = le nombre d'entités posées change, OU la somme des quantités manquantes passe STRICTEMENT sous le
       minimum déjà observé pour cet ordre (une oscillation ne compte pas deux fois) ;
    B. retiré quand tick - dernier progrès > Op.TTL (le délai repart à chaque progrès) ;
    C. PLAFOND : un ordre dont le manque a été mesuré et qui n'a encore AUCUNE entité posée est retiré à plus de
       Op.MAX_UNBUILT d'âge, même s'il avance (une réserve qui garde fer et cuivre pendant des heures prive la
       recherche et l'armée ; automatisation.lua RESERVE_MAX : « réserves de 26 à 90 min »). 60 min : valeur CHOISIE
       (2 × le délai), non mesurée ;
    D. un manque qui ne baisse jamais est retiré après le même délai qu'avant.
  Un ordre sans mesure de manque (missing = nil : pas en réserve, autre sorte d'ordre) garde exactement l'ancienne
  règle (A sans la seconde moitié, B, pas de C).

  Aucun nom du jeu ici (anti-échelle, tests/iag_test.lua §8). Déterminisme : aucun hasard, aucun pairs, aucun temps
  mesuré ; l'état ajouté à `rec` est un seul nombre (best_missing).
]]

local Op = {}

Op.TTL = 30 * 3600          -- ticks sans progrès avant le retrait (30 min, comme Capi.ORDER_TTL avant ce lot)
Op.MAX_UNBUILT = 60 * 3600  -- ticks d'âge au plus pour un ordre mesuré sans aucune entité posée (60 min)

--- Enregistre une observation. `built` : entités posées (nombre) ; `missing` : somme des quantités encore manquantes de
--- ses modules EN RÉSERVE, ou nil quand aucun module n'est en réserve (pas de mesure : la valeur 0 d'une liste pas
--- encore remplie ne doit jamais devenir le minimum). Met à jour rec.built, rec.best_missing, rec.progress_tick.
function Op.observe(rec, tick, built, missing)
  if built ~= rec.built then rec.built, rec.progress_tick = built, tick end
  if missing ~= nil then
    if rec.best_missing == nil then
      rec.best_missing = missing
    elseif missing < rec.best_missing then
      rec.best_missing, rec.progress_tick = missing, tick
    end
  end
end

--- Faut-il retirer l'ordre ? Rend (vrai, "ttl" | "plafond") ou (faux).
function Op.expired(rec, tick)
  local last = rec.progress_tick or rec.opened or tick
  if tick - last > Op.TTL then return true, "ttl" end
  if rec.best_missing ~= nil and (rec.built or 0) == 0 and rec.opened and tick - rec.opened > Op.MAX_UNBUILT then
    return true, "plafond"
  end
  return false
end

--- Texte de la raison du retrait (journal [FO-CAPI] et cs.done) ; « aucun progres en 30 min » est l'ancien texte.
function Op.reason(kind)
  if kind == "plafond" then
    return "plafond de " .. math.floor(Op.MAX_UNBUILT / 3600) .. " min sans entite posee"
  end
  return "aucun progres en " .. math.floor(Op.TTL / 3600) .. " min"
end

return Op
