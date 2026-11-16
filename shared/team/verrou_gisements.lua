--[[
  Lot C1-COUT (CHANTIER 1 du DC, 15/11) : VERROU DES AMÉLIORATIONS tant que les grands gisements ne sont pas couverts. Règle PURE
  (aucune API Factorio, aucun nom d'objet).
  Partie 0.9.4 du DC : le champ de fer a attendu 216 tapis rapides (0 pose de 31,8 à 53,6 min) pendant que l'équipe montait ses tapis et
  ses bras ; le DC : « tapis et bras de base tant que les grands gisements ne sont pas saturés ».

    Vg.hold(deps, big, opts) -> hold (booléen), why (texte), list (gisements jugés, triés)
      deps : gisements recensés { id, resource, tiles, covered, full, danger } (la capitalisation, f.team.capi.deps : relevé existant,
             la couverture des lignes [FO-CAPI-COUV]) ;
      big  : { [ressource] = true } les minerais des champs du plan (fonderie ou combustible : lus aux données par l'appelant) ;
      opts : { small = tuiles au plus d'un PETIT gisement (Ca.GIANT_SMALL), cover = part visée (R.COVER_HIGH, 80 % du DC) }.
    Grand gisement d'un minerai = le plus grand recensé (tuiles, puis l'identifiant), hors danger, de plus de `small` tuiles. Le verrou
    tient tant qu'UN de ces grands gisements a moins de `cover` de ses tuiles sous une foreuse, sauf s'il est « plein » (d.full : plus de
    place libre ou couvert au plafond, verdict de la capitalisation, lot PAVAGE-GEANT), ET que sa pose attend le budget.
  Lot n099-amelio (DC, 16/11, sur la 0.9.8 : « pas de phase d'amélioration massive de la base, qui devrait être automatique une fois
  que le budget le permet ») : sur la carte du DC (600 %), aucun gisement de 2000 à 5000 tuiles n'atteint 80 % en 90 min ; le verrou
  tenait toute la partie (tapis montés 0 %) alors que la pose n'attendait jamais le budget (1 refus « budget » en 90 min, 4 factions).
  d.budget_ok (posé par script/ai3/capitalisation.lua) : vrai quand la dernière décision de la capitalisation n'a refusé ni couvrir: ni
  ouvrir: de ce gisement pour le budget ; absent (pas encore de décision) ou faux : la pose attend, le verrou tient comme avant.
  Aucun réglage nouveau : les deux seuils sont ceux du dépôt. Déterminisme : identifiants triés (tostring), aucun pairs décisionnel.
]]
local Rg = require("shared.team.rangees")

local Vg = {}

local function sorted_ids(t)
  local ids = {}
  for k in pairs(t or {}) do ids[#ids + 1] = k end
  table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
  return ids
end

function Vg.hold(deps, big, opts)
  opts = opts or {}
  local small = opts.small or 0
  local cover = opts.cover or Rg.COVER_HIGH
  local best = {} -- ressource -> gisement retenu
  for _, id in ipairs(sorted_ids(deps)) do
    local d = deps[id]
    if d and big and big[d.resource] and not d.danger and (d.tiles or 0) > small then
      local b = best[d.resource]
      if not b or (d.tiles or 0) > (b.tiles or 0) then best[d.resource] = d end
    end
  end
  local list, open = {}, {}
  for _, r in ipairs(sorted_ids(best)) do
    local d = best[r]
    local tiles, covered = d.tiles or 0, d.covered or 0
    -- Lot n099-amelio : un gisement court ne retient que si sa pose attend le budget (d.budget_ok absent ou faux)
    local short = (not d.full) and covered < cover * tiles and not d.budget_ok
    list[#list + 1] = { id = d.id, resource = r, tiles = tiles, covered = covered, full = d.full or nil, short = short or nil,
      budget_ok = d.budget_ok or nil }
    if short then open[#open + 1] = string.format("%s %d/%d", tostring(r), covered, tiles) end
  end
  if #open > 0 then
    return true, string.format("grands gisements sous %d %% dont la pose attend le budget : %s", math.floor(cover * 100 + 0.5),
      table.concat(open, ", ")), list
  end
  return false, (#list > 0) and "grands gisements couverts ou leur pose payee" or "aucun grand gisement recense", list
end

return Vg
