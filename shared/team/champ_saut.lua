--[[
  FONDERIE (lot FONDERIE, dernier tour du 3/11) : deux règles PURES du chantier d'une bande de champ, aucune API Factorio, aucun nom d'objet.

  Sa.split(own, shared, max) : une bande porte ses pièces propres (`own` entités) et les pièces COMMUNES des réseaux du charbon des côtés dont
    elle est la première bande (`shared` = { { side, n } }). Au-delà de `max` entités (lot6-123456789 : 1 026), les réseaux les plus gros sont
    REPORTÉS dans des projets liés à la bande (demandés juste après elle, refusés si elle l'est : jamais d'orphelin). Rend la liste triée des
    côtés reportés. Une bande dont les pièces propres seules dépassent `max` ne reporte rien de plus que tous ses réseaux.

  Sa.skip(role, reason, fails, blockers, limit) : une foreuse de BANDE (`role` = "champ-foreuse") dont le fantôme est refusé « occupe »
    pour la `limit`-ième fois, alors que tout ce qui occupe son emprise est une TOURELLE de la faction elle-même (posée après le plan ; les
    ressources ne comptent pas), est SAUTÉE : la bande finit et produit sans elle, la tourelle n'est pas déplacée (lot6-20261020 : emerald,
    bande 329, 551 entités sur 552, gun-turret fo-emerald posée sur l'emprise d'une foreuse).
    blockers = { { own_turret = vrai | faux } } : ce qui occupe l'emprise, ressources et fantômes déjà écartés par le runtime (types lus dans
    T.TURRET_TYPES : aucun nom ici).
  Déterminisme : listes triées, aucun `pairs`.
]]

local Sa = {}

Sa.LIMIT = 3 -- refus avant de sauter (Build.FAIL_LIMIT)

-- Lot VOIE-AVANT-FOURS (9/11, candidat 123456789 : bande de 46 fours finie à 51,9 min, son réseau du charbon lié (projet 9, 344 entités) à 71,8 min :
-- une vingtaine de minutes de fours sans voie). Le projet lié est demandé à la priorité de sa bande ; ses tâches (fantômes, transports) passaient après
-- celles d'autres projets. Règle : le réseau d'une bande vivante passe d'un rang devant les bandes sœurs, et de trois rangs quand sa bande est FINIE (ses
-- fours attendent la voie). Plafond : jamais au niveau des tâches de garnison (priorité de tâche = priorité du projet + 30, Build.FINISH_BONUS).
Sa.LINK_ON = true
Sa.LINK_ALIVE = 1
Sa.LINK_DONE = 3
Sa.LINK_CAP = 55

--- Priorité du projet lié d'une bande. base : priorité de la demande ; band_state : état de la bande dans le plan directeur (nil ou "refuse" : la
--- bande n'existe plus, le projet lié va être annulé : base). Pure, aucun nom d'objet.
function Sa.link_prio(base, band_state)
  if not Sa.LINK_ON or band_state == nil or band_state == "refuse" then return base end
  local bonus = (band_state == "fini") and Sa.LINK_DONE or Sa.LINK_ALIVE
  return math.min(base + bonus, math.max(base, Sa.LINK_CAP))
end

function Sa.split(own, shared, max)
  local list = {}
  local total = own or 0
  for _, s in ipairs(shared or {}) do list[#list + 1] = { side = s[1], n = s[2] or 0 }; total = total + (s[2] or 0) end
  table.sort(list, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.side < b.side end)
  local out = {}
  for _, s in ipairs(list) do
    if total <= max then break end
    out[#out + 1] = s.side
    total = total - s.n
  end
  table.sort(out)
  return out
end

function Sa.skip(role, reason, fails, blockers, limit)
  if role ~= "champ-foreuse" or reason ~= "occupe" then return false end
  if (fails or 0) + 1 < (limit or Sa.LIMIT) then return false end
  if not blockers or #blockers == 0 then return false end
  for _, b in ipairs(blockers) do if not b.own_turret then return false end end
  return true
end

return Sa
