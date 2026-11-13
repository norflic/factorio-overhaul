--[[
  Lot TV-PILOTE, point V10 de docs/TODO_VIDEO.md (vidéo 1:37 : « not just science but also the buildings … and … ammunition » ; un seul
  mécanisme pour la science, les biens d'équipement et les munitions). FAMILLE « ARMÉE » à PARTS RÉSERVÉES dans le cerveau. PUR (aucune API
  Factorio, aucun nom d'objet : le kit d'un soldat et la matière de base viennent du livre de recettes injecté), testé hors jeu par
  tests/famille_armee_test.lua. BRANCHÉ : shared/ai3/cerveau.lua (C.think, avant le service du stock virtuel), part lue sur la capitalisation
  (ctx.capi.res : delta + alpha), journal [FO-ARMEE] (script/ai3/pilotage.lua).

  État AVANT ce lot (lu dans le code, docs/IA_WORKFLOW.md §2) : les munitions passaient par le but « defense:munitions » (shared/ai3/buts.lua),
  l'équipement des soldats par le but « armee » (EMIT.army, projets.lua), et la capitalisation retirait de son budget une part δ + α
  (Ca.character, Ca.budget) que RIEN ne réservait ensuite : les autres projets du cerveau (objectif du moment, recherche courte) pouvaient
  vider le stock de plaques avant que la défense et l'armée aient été servies. Le levier « equiper » (shared/ai3/leviers.lua) est autre chose :
  des MODULES dans les machines posées, un levier d'économie ; il n'est pas de cette famille.

  La famille :
    * membres = les buts de familles Fa.FAMILIES (donnée : « armee » et « defense ») hors armée « tardive » (g.late : l'armée de VOTRE équipe
      est servie après son économie vitale, décision du DC, lot DEPENSES2 : elle ne réserve rien) ;
    * UNE liste de besoins (Fa.wants) pour les deux voies : munitions (but de stock) et équipement des soldats (but d'armée), en objets finis ;
    * UNE part réservée (Fa.share) : δ + α de la capitalisation (‰), au plus Fa.SHARE_MAX ; absente ou illisible : AUCUNE part (garde écrite,
      jamais une part inventée) ;
    * la RÉSERVE (Fa.reserve) : pour chaque matière de base que ces besoins réclament (plan du livre, déduction faite de ce qui est au stock),
      min(stock virtuel, besoin, part × stock virtuel) est retenu pour la famille : les projets qui ne sont pas de la famille voient le stock
      MOINS la réserve (le cerveau la prête, projet par projet) ; les membres voient tout. Aucun besoin non servi : aucune réserve.
  Déterminisme : listes triées, entiers, aucun hasard, aucun pairs décisionnel, aucun temps mesuré.
]]

local Fa = {}

Fa.FAMILIES = { armee = true, defense = true } -- familles de buts (shared/ai3/buts.lua, B.FAMILIES) qui forment la famille armée
Fa.SHARE_MAX = 500                              -- ‰ du stock virtuel retenu au plus, quelle que soit la part de la capitalisation
Fa.EPS = 1e-9

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge and v or nil end

--- Ce but est-il de la famille armée (donc servi sur la réserve) ? L'armée « tardive » de votre équipe n'en est pas.
function Fa.member(goal)
  return type(goal) == "table" and Fa.FAMILIES[goal.family] == true and goal.late ~= true
end

--- Part réservée (‰) lue sur la capitalisation : parts = { delta, alpha } en ‰. Rend part, raison (part nil et raison écrite quand une des
--- deux est absente ou illisible : aucune part, jamais une part inventée).
function Fa.share(parts)
  if type(parts) ~= "table" then return nil, "parts absentes : capitalisation sans decision" end
  local d, a = num(parts.delta), num(parts.alpha)
  if d == nil or a == nil then return nil, "parts illisibles : delta ou alpha absent" end
  if d < 0 or a < 0 then return nil, "parts negatives" end
  -- lot S42-DEFENSE : parts.max (pour mille) releve le plafond quand la part de la defense est mesuree sur les pertes (nil : Fa.SHARE_MAX)
  local cap = num(parts.max) or Fa.SHARE_MAX
  return math.max(0, math.min(cap, 1000, math.floor(d + a + Fa.EPS)))
end

--- UNE liste de besoins en objets finis pour les deux voies. goals = buts du cerveau (triés par l'appelant) ; kit_of(but) rend la liste
--- { {objet, n} } d'un but d'armée (nil : aucun). Rend { { item, n, channel, key } } triée par clé de but : channel « munitions » (but de stock)
--- ou « equipement » (but d'armée).
function Fa.wants(goals, kit_of)
  local out = {}
  for _, g in ipairs(goals or {}) do
    if Fa.member(g) then
      if g.kind == "stock" and type(g.item) == "string" and (num(g.n) or 0) > 0 then
        out[#out + 1] = { item = g.item, n = g.n, channel = "munitions", key = g.key }
      elseif g.kind == "army" and kit_of then
        for _, it in ipairs(kit_of(g) or {}) do
          if type(it[1]) == "string" and (num(it[2]) or 0) > 0 then out[#out + 1] = { item = it[1], n = it[2], channel = "equipement", key = g.key } end
        end
      end
    end
  end
  return out
end

--- La réserve. avail = stock virtuel { [matière] = n } ; wants = Fa.wants ; plan_raw(liste { {objet, n} }) rend { [matière de base] = manque }
--- (le plan du livre sur le stock virtuel) ; share = Fa.share (‰ ou nil). Rend
---   { held = { [matière] = n } (réserve de départ), left (le même, qui baisse quand la famille consomme), share, wants, raw, why } ;
---   held vide et `why` écrit quand rien n'est retenu (part absente, aucun besoin, aucune matière de base réclamée).
function Fa.reserve(avail, wants, plan_raw, share, share_why)
  local res = { held = {}, left = {}, share = share, wants = wants or {}, raw = {}, why = nil }
  if share == nil then res.why = "part absente : " .. tostring(share_why or "?") return res end
  if share <= 0 then res.why = "part nulle" return res end
  if #res.wants == 0 then res.why = "aucun besoin de la famille" return res end
  local list = {}
  for _, w in ipairs(res.wants) do list[#list + 1] = { w.item, w.n } end
  local raw = plan_raw and plan_raw(list) or nil
  if type(raw) ~= "table" then res.why = "plan du livre absent" return res end
  res.raw = raw
  local any = false
  for _, k in ipairs(sorted_keys(raw)) do
    local need = num(raw[k]) or 0
    local have = num((avail or {})[k]) or 0
    local cap = math.floor(have * share / 1000 + Fa.EPS)
    local h = math.min(have, math.ceil(need - Fa.EPS), cap)
    if h > 0 then res.held[k] = h any = true end
  end
  if not any then res.why = "aucune matiere de base reclamee au stock" end
  res.left = {} -- ce qui reste retenu au fil du service du stock (Fa.spend) ; `held` garde la réserve de départ, rapportée au journal
  for _, k in ipairs(sorted_keys(res.held)) do res.left[k] = res.held[k] end
  return res
end

--- Prête la réserve à un projet qui n'est pas de la famille : retire de `avail` ce qui est retenu (au plus ce qui y est) et rend la liste
--- de ce qui a été pris { [matière] = n }, à rendre par Fa.restore. Un membre ne prête rien.
function Fa.lend(avail, held, member)
  local taken = {}
  if member then return taken end
  for _, k in ipairs(sorted_keys(held)) do
    local t = math.min(avail[k] or 0, held[k])
    if t > 0 then
      avail[k] = (avail[k] or 0) - t
      taken[k] = t
    end
  end
  return taken
end

function Fa.restore(avail, taken)
  for _, k in ipairs(sorted_keys(taken)) do avail[k] = (avail[k] or 0) + taken[k] end
end

--- Un membre vient d'être servi : ce qu'il a consommé du stock virtuel (avant -> après) sort de la réserve (elle servait à cela), jamais plus que
--- ce qu'elle retenait. Sans cela, un projet servi APRÈS l'armée verrait la réserve deux fois (une fois consommée, une fois retenue).
--- before = { [matière] = n } relevé avant l'émission du membre (Fa.snapshot) ; avail = stock virtuel après.
function Fa.spend(held, before, avail)
  for _, k in ipairs(sorted_keys(held)) do
    local used = (before[k] or 0) - (avail[k] or 0)
    if used > 0 then held[k] = math.max(0, held[k] - used) end
    if held[k] <= 0 then held[k] = nil end
  end
end

--- Relevé du stock virtuel des seules matières retenues, avant l'émission d'un membre.
function Fa.snapshot(avail, held)
  local out = {}
  for _, k in ipairs(sorted_keys(held)) do out[k] = avail[k] or 0 end
  return out
end

--- Signature d'une réserve (pour n'écrire au journal qu'aux changements) : la part et les matières retenues, SANS les quantités (qui bougent à
--- chaque pensée : le journal ne dirait rien de plus).
function Fa.signature(res)
  if not res then return "" end
  return tostring(res.share or "-") .. "|" .. table.concat(sorted_keys(res.held), ",")
end

--- Ligne du journal [FO-ARMEE] (aucune décision ne la lit).
function Fa.line(key, res, minutes)
  local held, ws = {}, {}
  for _, k in ipairs(sorted_keys(res.held)) do held[#held + 1] = k .. " " .. res.held[k] end
  for _, w in ipairs(res.wants) do ws[#ws + 1] = string.format("%s %d (%s)", w.item, math.ceil(w.n), w.channel) end
  return string.format("[FO-ARMEE] %s : famille armee, part %s pour mille ; besoins [%s] ; reserve [%s]%s a %.1f min", key,
    res.share and tostring(res.share) or "absente", table.concat(ws, ", "), table.concat(held, ", "), res.why and (" ; " .. res.why) or "", minutes or 0)
end

return Fa
