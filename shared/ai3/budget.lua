--[[
  Lot PILE-BUDGET (retour du DC du 31/10, points 8 et 9 : « plus jamais d'inactivité avec du stock »). La retenue de la pile
  (shared/ai3/pile.lua : un poste incomplet, une pièce à refaire suspendent l'AMÉLIORATION) ne vaut QUE si le budget manque.
  Si le stock couvre la défense, la reconstruction ET une amélioration, tout passe en parallèle.

  PUR (aucune API Factorio, aucun nom d'objet : les listes { {objet, n} } et le livre de recettes viennent des appelants).
  Testé hors jeu : tests/pile_budget_test.lua. Le budget est LU SUR LE STOCK, par matière, avec le livre (Book:plan) : un
  stock de 49 000 plaques de cuivre ne paie pas une tourelle de fer ; la couverture est exacte, pas une somme de valeurs.

  Règle (Bg.assess) :
    1. noyau = défense (objets des postes sous leur minimum, PAS ceux déjà pris par une tâche) + reconstruction (pièces sans
       tâche, projet rouvert), majoré de Bg.MARGIN_PCT % (marge : le stock bouge entre deux pensées) ;
    2. noyau non couvert (une matière brute manque) -> la retenue demeure : produire d'abord ;
    3. noyau couvert -> on essaie les améliorations connues dans l'ordre donné ; chacune qui se paie sur ce qui reste est ADMISE
       (le stock est entamé : la suivante doit se payer sur le reste, d'où le parallèle sans double dépense) ; une amélioration
       trop chère est sautée, la suivante peut passer (un PNJ libre prend la prochaine qui se paie) ;
    4. aucune amélioration payée (aucune au coût connu, ou toutes trop chères) : le noyau doit être couvert Bg.NEUTRAL_PCT % de plus
       (cas des modules du plan directeur et des ordres dont le coût n'est pas une liste d'objets) ;
    5. hystérésis d'ÉTAT : si la pile était déjà en parallèle et que le noyau reste couvert, elle le reste (les améliorations en
       cours ne sont pas coupées en deux par un stock qui descend). Aucune horloge.
       Lot CC-PILE (F522) : « reste couvert » se lit sur le stock libre PLUS ce que les améliorations en cours retiennent au coffre
       (`held`, objets retirés du coffre par leurs chantiers en réserve, que la retenue leur ferait rendre) ; on n'ENTRE en parallèle
       que sur le stock libre seul. Avant, la réserve d'un module admis vidait le coffre, le noyau passait « non couvert », la retenue
       faisait rendre la matière, le noyau redevenait couvert, et ainsi de suite (partie de banc 1618033988 : 39 bascules en 49 relevés
       de 30 à 44 min, « noyau non couvert (manque iron-plate 45 à 410) » une fois sur deux, modules 5, 6 et 21 à 0 posé).
  Déterminisme : listes dans l'ordre donné (le cerveau les trie), entiers, aucun hasard, aucun temps mesuré.
]]

local Bg = {}

Bg.MARGIN_PCT = 110   -- le noyau est majoré de 10 % avant de comparer au stock
Bg.NEUTRAL_PCT = 100  -- sans amélioration au coût connu : le noyau doit être couvert 100 % de plus (2 fois en tout)

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

--- Copie de `list` ({ {objet, n} }) avec n majoré de pct % (arrondi au-dessus), entrées vides retirées.
function Bg.scaled(list, pct)
  local out = {}
  for _, it in ipairs(list or {}) do
    local n = math.ceil((it[2] or 0) * pct / 100 - 1e-9)
    if it[1] and n > 0 then out[#out + 1] = { it[1], n } end
  end
  return out
end

--- Lot CC-PILE : stock libre + matière retenue par les améliorations en cours ({ [objet] = n } chacun) ; copie, entrées <= 0 ignorées.
function Bg.with_held(stock, held)
  local out = {}
  for _, k in ipairs(sorted_keys(stock)) do out[k] = stock[k] end
  for _, k in ipairs(sorted_keys(held)) do
    if (held[k] or 0) > 0 then out[k] = (out[k] or 0) + held[k] end
  end
  return out
end

local function concat(a, b)
  local out = {}
  for _, it in ipairs(a or {}) do out[#out + 1] = it end
  for _, it in ipairs(b or {}) do out[#out + 1] = it end
  return out
end

local function missing_text(raw)
  local parts = {}
  for _, k in ipairs(sorted_keys(raw)) do parts[#parts + 1] = k .. " " .. math.ceil(raw[k] - 1e-9) end
  return table.concat(parts, ", ")
end

--- Le budget. book : livre de recettes (Book:plan) ; stock : { [objet] = n } (stock libre : ce que les tâches en cours ont
--- déjà pris est retiré par l'appelant) ; claims = { defense = { {objet, n} }, rebuild = { {objet, n} },
--- upgrades = { { key, cost = { {objet, n} } } } (l'ordre est celui de l'appelant) } ; prev : la pile était en parallèle ;
--- held : { [objet] = n } retenu au coffre par les améliorations en cours (lot CC-PILE, facultatif ; lu seulement si prev).
--- Rend { covered, core_ok, admitted = { clés }, skipped = { clés }, missing = { [matière] = n }, why }.
function Bg.assess(book, stock, claims, prev, held)
  claims = claims or {}
  local out = { covered = false, core_ok = true, admitted = {}, skipped = {}, missing = {}, n_up = #(claims.upgrades or {}) }
  if not book or not book.plan then out.why = "pas de livre" return out end
  local core = Bg.scaled(concat(claims.defense, claims.rebuild), Bg.MARGIN_PCT)
  local base = book:plan(core, stock or {})
  if next(base.raw) ~= nil then
    if prev and next(held or {}) ~= nil then
      local kept = book:plan(core, Bg.with_held(stock, held))
      if next(kept.raw) == nil then
        out.covered, out.why = true, "maintenu (noyau couvert avec la matiere retenue par les ameliorations en cours)"
        return out
      end
    end
    out.core_ok, out.missing = false, base.raw
    out.why = "noyau non couvert (manque " .. missing_text(base.raw) .. ")"
    return out
  end
  local avail = base.avail
  local ups = claims.upgrades or {}
  for _, u in ipairs(ups) do
    local cost = Bg.scaled(u.cost, 100)
    if #cost > 0 then
      local pc = book:plan(cost, avail)
      if next(pc.raw) == nil then
        out.admitted[#out.admitted + 1] = u.key
        avail = pc.avail
      else
        out.skipped[#out.skipped + 1] = u.key
      end
    end
  end
  if #out.admitted > 0 then
    out.covered, out.why = true, string.format("%d amelioration(s) payee(s) sur le stock apres defense et reconstruction", #out.admitted)
  elseif prev then
    out.covered, out.why = true, "maintenu (noyau toujours couvert)"
  else
    -- Aucune amélioration payée (aucune au coût connu, ou toutes trop chères) : le noyau doit être couvert plus largement. Relecture :
    -- un ordre ouvert trop cher ne retient plus rien (sinon il interdisait d'ouvrir un ordre moins cher, à stock plein).
    local wide = book:plan(Bg.scaled(concat(claims.defense, claims.rebuild), Bg.MARGIN_PCT + Bg.NEUTRAL_PCT), stock or {})
    if next(wide.raw) == nil then
      out.covered, out.why = true, #out.skipped > 0
        and string.format("noyau couvert 2 fois (%d amelioration(s) trop chere(s) sautee(s))", #out.skipped)
        or "noyau couvert 2 fois (aucune amelioration au cout connu)"
    else
      out.missing, out.why = wide.raw, "noyau couvert une fois seulement (manque " .. missing_text(wide.raw) .. " pour la marge)"
    end
  end
  return out
end

--- Une ligne lisible du budget (journal [FO-PILE] ; aucune décision ne la lit).
function Bg.describe(b)
  if not b then return "budget : non evalue" end
  local ad = (b.admitted and #b.admitted > 0) and (" admises " .. table.concat(b.admitted, ",")) or ""
  return string.format("budget %s : %s%s", b.covered and "COUVERT (parallele)" or "manque", tostring(b.why), ad)
end

return Bg
