--[[
  Sortie de spirale (EFFONDREMENT, partie du DC sur 0.6.58, 7/11 : votre équipe tombée à 2 PNJ, fer libre à 0 de 133 à
  177 min, aucune recrue). Décision du DC (QCM, 7/11 vers 14 h 25), mot pour mot : « je veux toujours n ouvriers minimum,
  donc 12 si 12 au départ. Au delas ça coute des ressources ».
  Lecture du lead : tant que votre équipe est SOUS son effectif de départ (view.recover_floor), la recrue est GRATUITE (ni
  plaques ni kit pris au stock) et ÉQUIPÉE comme une recrue ordinaire (Worker.recruit, free : kit offert, jamais rendu au
  coffre). Au-delà de l'effectif de départ, la recrue est payée comme avant (kit + (10 + effectif) fer, shared/team/org.lua).
  Les factions (view.emergency) ne changent pas.
  Avant (0.6.58) : la recrue de reprise n'était faite que si le livre trouvait TOUTES ses plaques au stock libre
  (shared/team/planner.lua, « Correction VERIF-NUIT ») ; sans elles, rien (boucle B1 de docs/IA_WORKFLOW.md).
  Lecteurs de la règle : le planificateur (recrue de reprise), le stock virtuel et le besoin évalué du cerveau
  (shared/ai3/cerveau.lua), le budget de la pile (shared/ai3/pile.lua), le paiement en E4 (script/team/team.lua).
  Lua PUR, arithmétique seule.
]]

local Sp = {}

--- La recrue de cette vue est-elle gratuite ? v = { workers, recover_floor (votre équipe), emergency (factions) }.
function Sp.free(v)
  if not v or v.emergency then return false end
  local floor = v.recover_floor
  return floor ~= nil and (v.workers or 0) < floor
end

--- Coût d'une recrue sous la règle : liste vide si elle est gratuite, sinon `cost` tel quel.
function Sp.cost(v, cost)
  if Sp.free(v) then return {} end
  return cost
end

--[[
  Journal [FO-RECRUE] (choix (1) du lead, 7/11 : la garde QGSURVIE est GARDÉE, la recrue gratuite attend la fin de la menace) : pour
  que le DC voie pourquoi personne ne revient, une ligne « recrue gratuite retenue : garde QG (biters à N tuiles, 0 tourelle armée) »,
  au plus une par Sp.LOG_EVERY ticks. Journal seul : aucune décision ne le lit.
]]
Sp.LOG_EVERY = 3600 -- 1 min

--- Une ligne [FO-RECRUE] est-elle due ? last = tick de la dernière ligne (nil : jamais), tick = maintenant.
function Sp.log_due(last, tick)
  return last == nil or (tick or 0) - last >= Sp.LOG_EVERY
end

--- Texte de la ligne. a = { key, dist (tuiles du coffre au biter le plus proche, nil : inconnu), biters, armed, workers, floor, minutes }.
function Sp.held_text(a)
  a = a or {}
  return string.format("[FO-RECRUE] %s : recrue gratuite retenue : garde QG (biters a %s tuiles, %d tourelle(s) armee(s)) ; " ..
    "%d biter(s) a portee du coffre, effectif %d/%d a %.1f min", tostring(a.key or "?"),
    a.dist and string.format("%d", math.floor(a.dist + 0.5)) or "?", a.armed or 0, a.biters or 0, a.workers or 0, a.floor or 0,
    a.minutes or 0)
end

--[[
  Filet de RECUL de la recrue gratuite (demande du lead, 7/11 vers 17 h ; NON BRANCHÉ, en attente de garde-v4 et de la décision) :
  sans le prix en fer, rien ne freinait une boucle de recrues tuées au QG par des mitrailleurs de faction qui campent à 6 tuiles
  (partie du DC). Le DC veut toujours ses n ouvriers : le filet ne retient QUE si les recrues gratuites meurent vite.
    - une recrue gratuite morte moins de Sp.RECUL_VITE ticks après son apparition DOUBLE l'attente de la suivante (première attente
      Sp.RECUL_BASE, plafond Sp.RECUL_MAX), comptée depuis cette mort ;
    - l'attente revient à 0 quand aucune recrue gratuite n'est morte vite pendant Sp.RECUL_RESET ticks (l'effectif a tenu 5 min) ;
    - une mort lente (au-delà de Sp.RECUL_VITE) ne change rien.
  État : { wait, next_at, last_quick, quick } (nombres seulement : vit dans global). Lua PUR, arithmétique seule.
  Branchement proposé (à écrire seulement sur accord) : script/team/worker.lua, mort d'un PNJ (agent.free_born posé par E4 à une
  recrue gratuite) → Sp.recul_death ; planificateur, bloc de reprise → Sp.recul_ready (journal [FO-RECRUE] « en recul »).
]]
Sp.RECUL_VITE = 3600    -- 60 s
Sp.RECUL_BASE = 600     -- première attente : le double de la cadence d'une recrue par pensée (300 ticks)
Sp.RECUL_MAX = 3600     -- plafond : au plus une recrue gratuite par minute sous une boucle de morts
Sp.RECUL_RESET = 18000  -- 5 min sans mort rapide : attente remise à 0

function Sp.recul_new()
  return { wait = 0, next_at = 0, last_quick = nil, quick = 0 }
end

--- Mort d'une recrue gratuite apparue au tick `born`, morte au tick `died`. Rend l'état (modifié sur place).
function Sp.recul_death(st, born, died)
  st = st or Sp.recul_new()
  if born == nil or died == nil or died - born >= Sp.RECUL_VITE then return st end
  local w = (st.wait or 0) > 0 and st.wait * 2 or Sp.RECUL_BASE
  if w > Sp.RECUL_MAX then w = Sp.RECUL_MAX end
  st.wait = w
  st.next_at = math.max(st.next_at or 0, died + w)
  st.last_quick = died
  st.quick = (st.quick or 0) + 1
  return st
end

--- Journal [FO-RECRUE] d'une mort rapide. a = { key, age (ticks entre l'arrivée et la mort), wait (attente qui suit), minutes }.
function Sp.recul_text(a)
  a = a or {}
  return string.format("[FO-RECRUE] %s : recrue gratuite tuee %d s apres son arrivee : recul, attente %d ticks (%d s) avant la suivante a %.1f min",
    tostring(a.key or "?"), math.floor((a.age or 0) / 60), a.wait or 0, math.floor((a.wait or 0) / 60), a.minutes or 0)
end

--- Journal [FO-RECRUE] d'une recrue gratuite retenue par le recul. a = { key, left (ticks avant la suivante), wait, workers, floor, minutes }.
function Sp.recul_held_text(a)
  a = a or {}
  return string.format("[FO-RECRUE] %s : recrue gratuite en recul : prochaine dans %d s (attente %d ticks), effectif %d/%d a %.1f min",
    tostring(a.key or "?"), math.floor((a.left or 0) / 60), a.wait or 0, a.workers or 0, a.floor or 0, a.minutes or 0)
end

--- Une recrue gratuite part au tick `tick` : en recul (attente > 0), la suivante attend aussi `wait` depuis ce départ (sans cela, deux
--- recrues partaient à une pensée d'écart avant la mort de la première : 50 recrues en 30 min sous un campeur au lieu de ~25).
function Sp.recul_spawn(st, tick)
  if st and (st.wait or 0) > 0 then st.next_at = math.max(st.next_at or 0, tick + st.wait) end
  return st
end

--- Une recrue gratuite peut-elle partir au tick `tick` ? Remet l'attente à 0 après Sp.RECUL_RESET ticks sans mort rapide.
function Sp.recul_ready(st, tick)
  if not st then return true end
  if st.last_quick and tick - st.last_quick >= Sp.RECUL_RESET then
    st.wait, st.last_quick = 0, nil
  end
  return tick >= (st.next_at or 0)
end

-- Parade du KIT OFFERT (décision du lead, 7/11 vers 19 h 05 : champ free_kit, au plus 1 pistolet et les chargeurs non payés, détruits,
-- jamais rendus au coffre). Sans elle, le kit d'une recrue gratuite tuée restait dans son corps : environ 25 pistolets et 250 chargeurs
-- à ramasser en 30 min sous un campeur. Fait moteur (micro-banc kit-cadavre, 9ee2b12d) : pendant on_entity_died, les inventaires du
-- personnage sont déjà vides ; le kit se retire du corps (inventaire character_corpse) à on_post_entity_died.
Sp.KIT_TTL = 600 -- ticks : une mort notée sans corps rendu (on_post_entity_died) est oubliée au-delà

--- Kit à retirer du corps : gift = { gun = n, ammo = n } offert à la recrue (nil : kit payé, rien), present = { gun, ammo } dans le corps,
--- paid = chargeurs PAYÉS reçus depuis (réarmement au coffre). Les chargeurs offerts partent les premiers au tir : il en reste au plus
--- present − paid ; rien d'au-delà du don. Rend (pistolets, chargeurs), jamais un objet payé.
function Sp.kit_take(gift, present, paid)
  if not gift then return 0, 0 end
  present = present or {}
  local gun = math.max(0, math.min(gift.gun or 0, present.gun or 0))
  local ammo = math.max(0, math.min(gift.ammo or 0, (present.ammo or 0) - (paid or 0)))
  return gun, ammo
end

--- Journal [FO-KIT-OFFERT] d'un corps vidé de son kit offert (a : key, unit, gun, ammo, kept, total_gun, total_ammo, minutes).
function Sp.kit_text(a)
  return string.format("[FO-KIT-OFFERT] %s : corps du PNJ %s : kit offert retire (pistolet %d, chargeurs %d ; chargeurs payes laisses %d) ; " ..
    "depuis le debut %d pistolet(s), %d chargeur(s) a %.1f min", tostring(a.key), tostring(a.unit), a.gun or 0, a.ammo or 0, a.kept or 0,
    a.total_gun or 0, a.total_ammo or 0, a.minutes or 0)
end

return Sp
