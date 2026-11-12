--[[
  FONDERIE (lot FONDERIE, dernier tour du 3/11) : deux règles PURES du chantier d'une bande de champ, aucune API Factorio, aucun nom d'objet.

  Sa.split(own, shared, max) : une bande porte ses pièces propres (`own` entités) et les pièces COMMUNES des réseaux du charbon des côtés dont
    elle est la première bande (`shared` = { { side, n } }). Au-delà de `max` entités (lot6-123456789 : 1 026), les réseaux les plus gros sont
    REPORTÉS dans des projets liés à la bande (demandés juste après elle, refusés si elle l'est : jamais d'orphelin). Rend la liste triée des
    côtés reportés. Une bande dont les pièces propres seules dépassent `max` ne reporte rien de plus que tous ses réseaux.

  Sa.skip(role, reason, fails, blockers, limit) : une foreuse de BANDE (`role` = "champ-foreuse") dont le fantôme est refusé
    pour la `limit`-ième fois, quoi qu'occupe son emprise (tourelle, poteau, arbre résiduel, bâtiment : lot CHAMP-OBSTACLES, 11/11), est SAUTÉE : la bande finit et produit sans elle, la tourelle n'est pas déplacée (lot6-20261020 : emerald,
    bande 329, 551 entités sur 552, gun-turret fo-emerald posée sur l'emprise d'une foreuse).
    blockers = { { own_turret = vrai | faux } } : ce qui occupe l'emprise, ressources et fantômes déjà écartés par le runtime (types lus dans
    T.TURRET_TYPES : aucun nom ici).
  Déterminisme : listes triées, aucun `pairs`.
]]

local Sa = {}

Sa.LIMIT = 3 -- refus avant de sauter (Build.FAIL_LIMIT)

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
  -- lot CHAMP-OBSTACLES (ordre du DC du 11/11) : branches supprimées « raison autre que occupe » et « un bloqueur qui n'est pas une tourelle
  -- de l'équipe » : un poteau, un arbre résiduel ou un bâtiment quelconque sous l'emprise faisait échouer la foreuse jusqu'à FAIL_LIMIT et
  -- bloquait la bande entière ; la tuile est sautée, la rangée continue. `reason` et `blockers` restent dans la signature (journal du runtime).
  if role ~= "champ-foreuse" then return false end
  if (fails or 0) + 1 < (limit or Sa.LIMIT) then return false end
  return true
end

--- Lot RETROFIT (F556) : reliques thermiques sous une bande. `site` : spec.site du projet ; `era` : Elec.era de l'équipe (tick, nil avant) ;
--- `blockers` = { { own, burner, power, outpost, piece } } : ce qui occupe l'emprise d'une pièce refusée « occupe ». Rend les indices (croissants) des
--- entités que le chantier DÉMONTE lui-même : de l'équipe, à brûleur, qui ne produisent pas d'énergie, sur une bande de champ, une fois
--- l'ère électrique datée. Partie du DC (0.7.3, projet 70, bande 40) : 4 paires thermiques de l'équipe sous la bande, seule la porte
--- « degel » de la migration les retirait ; le chantier sautait la foreuse et refusait le reste « occupe », la bande restait en chantier.
function Sa.relics(site, era, blockers)
  local out = {}
  if site ~= "champ" or not era then return out end
  for i, b in ipairs(blockers or {}) do
    -- lot RELIQUES-SOUS-BANDE : aussi une foreuse ou une réception d'AVANT-POSTE de l'équipe (`outpost`), électrique comprise (foreuse_swap) :
    -- le plan du champ tient ces tuiles pour libres (mine_of) ; jamais une pièce non cédée d'un plan (`piece`, une autre bande vivante)
    if b.own and not b.piece and (b.outpost or (b.burner and not b.power)) then out[#out + 1] = i end
  end
  return out
end

return Sa
