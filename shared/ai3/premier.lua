--[[
  Lot PORTE-PILE (9/11, ordre de l'orchestrateur) : la pile laisse passer le PREMIER module de fabrication de l'équipe (puis les deux
  suivants : le mall), même pile retenue, quand le stock libre le paie SANS rien retirer à la défense.

  Mesuré (partie neuve 0.6.72, INTEG-0672, neuve40-b36e23b2) : « améliorer SUSPENDU » 34,3 min sur 40 chez player (sommet adapter),
  14,8 min chez azure ; la retenue bascule de « budget couvert » à « noyau non couvert (manque iron-plate 10 à 40) » toutes les quelques
  dizaines de secondes. À chaque bascule, la réserve du module neuf est RENDUE au coffre (Build.reserve_suspended, objets rendus) et le
  cerveau cesse de fabriquer ses manques (shared/ai3/cerveau.lua, Pi.porte) : le module n'accumule jamais. Premier module de fabrication
  fini : jamais en 40 min chez player, à 37,4 min chez scarlet.

  Règle (Pm.eval, PURE : aucune API Factorio, aucun nom d'objet ; les listes { {objet, n} } et le livre viennent des appelants) :
    1. `done` = modules de fabrication DÉJÀ finis ; les `Pm.MAX` premiers modules de l'équipe (premier module, puis mall) sont
       concernés : places = Pm.MAX - done, prises par les candidats (modules de fabrication non finis, dans l'ordre des projets) ;
    2. un candidat est ADMIS quand son coût restant (objets qui manquent à sa réserve) se paie sur le stock RESTANT une fois le noyau
       (défense + reconstruction + recrues, majoré de Bg.MARGIN_PCT %) payé : le noyau n'est pas entamé, même quand il est lui-même
       en manque (alors le stock restant de la matière qui manque est nul : le module qui en a besoin n'est pas admis) ;
    3. hystérésis d'ÉTAT : un candidat admis à la pensée précédente (`prev`) reste admis tant que le STOCK LIBRE seul (hors noyau) couvre
       son coût restant : la réserve qu'il tient déjà n'est pas rendue pour 10 fer de moins au noyau (l'oscillation mesurée) ;
    4. les places non prises par un candidat existant restent OUVERTES au mall (`mall` vrai) : la décision du mall a sa propre règle de
       paiement (script/ai3/industrie.lua, affordable : le stock hors besoin), seule la pile ne le retient plus.
  Aucune horloge. Déterminisme : listes dans l'ordre donné, entiers, aucun `pairs` décisionnel.
]]

local Bg = require("shared.ai3.budget")

local Pm = {}

Pm.MAX = 3 -- le premier module de fabrication de l'équipe, puis deux blocs du mall

--- Ce module (gen : générateur du plan directeur) est-il de la fabrication (assembleurs) ? `not_fab` : { [générateur] = vrai } des
--- générateurs qui n'en sont pas (fonderie, foreuses, vapeur, laboratoires), DONNÉ par l'appelant (shared/team/automatisation_donnees.lua,
--- D.NOT_FAB : cette règle ne nomme rien du jeu). Sans générateur : faux.
function Pm.is_fab(gen, not_fab)
  return gen ~= nil and (not_fab or {})[gen] ~= true
end

local function concat(a, b)
  local out = {}
  for _, it in ipairs(a or {}) do out[#out + 1] = it end
  for _, it in ipairs(b or {}) do out[#out + 1] = it end
  return out
end

--- Évaluation. prem = { done = n, cands = { { key, item, cost = { {objet, n} }, prev = bool } } } (candidats DANS L'ORDRE) ;
--- book : livre de recettes (Book:plan) ; avail : stock libre { [objet] = n } ; claims = { defense, rebuild } (comme Bg.assess).
--- Rend { items = { [objet] = vrai }, admitted = { clés }, skipped = { clés }, slots, mall, why }.
function Pm.eval(prem, book, avail, claims)
  local out = { items = {}, admitted = {}, skipped = {}, slots = 0, mall = false }
  if type(prem) ~= "table" or not (book and book.plan) then out.why = "pas de livre" return out end
  local done = prem.done or 0
  out.slots = Pm.MAX - done
  if out.slots <= 0 then out.why = "les " .. Pm.MAX .. " premiers modules de fabrication sont finis" return out end
  claims = claims or {}
  local core = Bg.scaled(concat(claims.defense, claims.rebuild), Bg.MARGIN_PCT)
  local free = book:plan(core, avail or {}).avail -- stock restant une fois le noyau payé (la matière qui manque au noyau est vide)
  local used = 0
  for _, c in ipairs(prem.cands or {}) do
    if used >= out.slots then break end
    used = used + 1
    local cost = Bg.scaled(c.cost, 100)
    local ok = true
    if #cost > 0 then
      local pc = book:plan(cost, free)
      if next(pc.raw) == nil then
        free = pc.avail
      else
        ok = false
        if c.prev then -- hystérésis : le stock libre seul (hors noyau) couvre-t-il ce qui lui reste à prendre ?
          ok = next(book:plan(cost, avail or {}).raw) == nil
        end
      end
    end
    if ok then
      out.admitted[#out.admitted + 1] = c.key
      if c.item ~= nil then out.items[c.item] = true end
    else
      out.skipped[#out.skipped + 1] = c.key
    end
  end
  out.mall = (out.slots - used) > 0
  out.why = string.format("%d module(s) de fabrication fini(s), %d place(s) : %d admis, %d refuse(s) faute de stock libre%s", done, out.slots,
    #out.admitted, #out.skipped, out.mall and ", mall ouvert" or "")
  return out
end

--- Une ligne lisible (journal [FO-PILE] ; aucune décision ne la lit).
function Pm.describe(pm)
  if not pm then return "premier module : non evalue" end
  return "premier module : " .. tostring(pm.why) .. ((#pm.admitted > 0) and (" ; admis " .. table.concat(pm.admitted, ",")) or "")
end

return Pm
