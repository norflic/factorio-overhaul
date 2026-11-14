--[[
  Lot EXPANSION-LOINTAINE (axe 1 du Mode Démon, 10/11) : règle PURE du chantier PROGRESSIF d'une bande de champ neuve.
  Testée hors jeu par tests/chantier_progressif_test.lua (avec mutants). Aucune API Factorio, aucun nom d'objet du jeu.

  Mesure (graine 123456789, 90 min, fo-logs/2026-11-10_V0677-FINAL2-A) : 17 bandes demandées, 7 finies, délai plan -> fini moyen 30,7 min
  dont la plus grande part en « reserve:materiaux » : la bande 393 d'Azur (311 pièces) attend de 24 à 64 min avec plus de 90 % de son kit
  réservé au coffre (à 64 min il lui manque encore 18 tapis, 6 foreuses et 4 bras), puis se pose en 10 min.
  Cause : build.lua, état « reserve » : une bande NEUVE ne part en chantier que la réserve COMPLÈTE (reserve() vrai) ; seul un projet
  ROUVERT pour reconstruction partait avec ce qu'il avait (Rr.partial_go, lot REBUILD-RAPIDE). Tout-ou-rien : le capital réservé dort.

  Règle : une bande neuve part en chantier dès que CHAQUE objet de son kit est réservé à au moins Cp.SHARE de son besoin (plancher
  Cp.floor : arrondi au-dessus, un objet demandé une ou deux fois est attendu en entier). Le reste est pris au coffre à la prise du PNJ
  (Build.take_reserved), suivi par refresh_missing, fabriqué par le cerveau comme avant ; un lot dont aucun objet n'est là ne vaut pas un voyage
  (Rr.batch_ready). Déterminisme : clés triées, entiers, aucun hasard, aucun temps mesuré.

  Lot CC-PETROLE (F492, playtest 0.6.87 du DC, graine 3592985581) : l'EXTENSION d'un champ de puits (spec.ext d'un site de fluide)
  gardait le tout-ou-rien. Mesure : site de brut du joueur fini à 62,9 min avec 2 chevalets sur 15 puits ; extension (projet 37,
  11 chevalets, 89 tuyaux, 13 poteaux, 113 entités) en « reserve:materiaux » de 62,9 à 93,7 min, 0 entité bâtie ; tuyaux et poteaux
  réunis à 72,9 min, chevalets fabriqués un à un (acier rare : 1 remis à 76,3 min, 1 kit à 81,9 min). Chaque chevalet au coffre
  dormait pendant que 13 puits restaient libres. Règle (Cp.ready_lead) : l'extension part dès que ses objets de TÊTE (rôle
  « extracteur » du plan, lu par build.lua : aucun nom) sont réservés à Cp.LEAD_MIN au moins et chaque autre objet (collecteur,
  embranchements, poteaux) au plancher commun Cp.floor ; chaque chevalet suivant se pose à son arrivée. Une rangée de modules
  (spec.rangee) garde le tout-ou-rien : une copie de module ne produit qu'entière.
]]

local Cp = {}

Cp.SHARE = 2 / 3 -- part du besoin de chaque objet réservée au coffre pour partir (azure p4 : 131/149 tapis = 88 % -> part à 30 min au lieu de 64)
Cp.LEAD_MIN = 1  -- objets de tête (extracteurs d'un champ de puits) réservés au moins pour partir : chacun produit dès qu'il est posé

local function sorted_keys(t)
  local keys = {}
  for k in next, t or {} do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

--- Plancher réservé d'un objet demandé `n` fois : l'arrondi au-dessus de Cp.SHARE × n (n = 1 -> 1, n = 2 -> 2, n = 3 -> 2, n = 149 -> 100).
function Cp.floor(n)
  n = math.floor(tonumber(n) or 0)
  if n <= 0 then return 0 end
  return math.ceil(n * Cp.SHARE - 1e-9)
end

--- La réserve `stock` ({ [objet] = n réservé }) couvre-t-elle `need` ({ [objet] = n demandé }) au plancher de chaque objet ?
--- Rend ok, détail { pieces = pièces réservées (bornées au besoin), total = pièces demandées, short = { { objet, manque au plancher } } }.
function Cp.ready(need, stock)
  local pieces, total, short = 0, 0, {}
  stock = stock or {}
  for _, it in ipairs(sorted_keys(need)) do
    local n = math.floor(tonumber(need[it]) or 0)
    if n > 0 then
      local have = math.min(math.floor(tonumber(stock[it]) or 0), n)
      pieces, total = pieces + have, total + n
      local fl = Cp.floor(n)
      if have < fl then short[#short + 1] = { it, fl - have } end
    end
  end
  return #short == 0 and total > 0, { pieces = pieces, total = total, short = short }
end

--- Lot CC-PETROLE : la réserve `stock` couvre-t-elle `need` pour une extension de champ de puits ? Les objets de `lead`
--- ({ [objet] = true } : rôle « extracteur » du plan) au plancher min(Cp.LEAD_MIN, demandé) ; chaque autre objet au plancher Cp.floor.
--- Sans aucun objet de tête demandé, ce n'est pas un champ de puits : refus (le tout-ou-rien reste). Rend ok, détail (comme Cp.ready).
function Cp.ready_lead(need, stock, lead)
  local pieces, total, short, leads = 0, 0, {}, 0
  stock, lead = stock or {}, lead or {}
  for _, it in ipairs(sorted_keys(need)) do
    local n = math.floor(tonumber(need[it]) or 0)
    if n > 0 then
      local have = math.min(math.floor(tonumber(stock[it]) or 0), n)
      pieces, total = pieces + have, total + n
      local fl = Cp.floor(n)
      if lead[it] then
        leads = leads + 1
        fl = math.min(Cp.LEAD_MIN, n)
      end
      if have < fl then short[#short + 1] = { it, fl - have } end
    end
  end
  return #short == 0 and leads > 0, { pieces = pieces, total = total, short = short, lead = true }
end

-- 0.7.114 (F676, cause racine de l'amorçage lent) : une bande de champ attendait TOUTE sa matière dès qu'elle dégelait des paires thermiques
-- (presque toutes : « 3 paire(s) thermique(s) dessous ») : bande de fer de 64 foreuses électriques + 24 fours (~1 500 plaques) pour une équipe
-- qui fond ~150 plaques/min : « en attente (matieres) » de 19 à 30 min, 0 foreuse électrique en marche à 20 min sur les 5 équipes (banc
-- JALONS30-ref0713-joueur). Règle : les FOREUSES de la bande (objets de tête, lus par build.lua au type de prototype : aucun nom) partent
-- dès Cp.BAND_LEAD réservées, chacune se pose à son arrivée et produit aussitôt ; tapis, bras, fours, poteaux au plancher Cp.floor, ou EN
-- ENTIER pour une bande qui dégèle des paires (garde SORTIE-PLAQUES B5 : la voie posée d'un bloc avant de retirer le fer qui produit).
Cp.BAND_LEAD = 4

--- Rend ok, détail (comme Cp.ready) : `lead` ({ [objet] = true }) au plancher min(Cp.BAND_LEAD, n), les autres au plancher Cp.floor (ou n si
--- `whole`). Sans aucun objet de tête demandé : refus.
function Cp.ready_band(need, stock, lead, whole)
  local pieces, total, short, leads = 0, 0, {}, 0
  stock, lead = stock or {}, lead or {}
  for _, it in ipairs(sorted_keys(need)) do
    local n = math.floor(tonumber(need[it]) or 0)
    if n > 0 then
      local have = math.min(math.floor(tonumber(stock[it]) or 0), n)
      pieces, total = pieces + have, total + n
      local fl = whole and n or Cp.floor(n)
      if lead[it] then
        leads = leads + 1
        fl = math.min(Cp.BAND_LEAD, n)
      end
      if have < fl then short[#short + 1] = { it, fl - have } end
    end
  end
  return #short == 0 and leads > 0, { pieces = pieces, total = total, short = short, lead = true }
end

--- Un projet `p` (vue : state, reopened, spec.champ, stock, need) peut-il partir en chantier progressif ? Seulement la BANDE elle-même,
--- neuve (spec.champ posé par le plan directeur du champ, sans `coal` ni `link` : un réseau du charbon, lié ou non, garde le tout-ou-rien :
--- son kit est surtout du combustible et sa pose partielle déroute la migration, mesure EXPANSION-C, graine 271828182 : le réseau lié de la
--- bande 1 parti à 33 min, la bande de fer suivante jamais demandée, 25 804 plaques au lieu de 42 144), en état « reserve », jamais un
--- projet rouvert (Rr.partial_go le couvre), jamais une bande qui doit encore dégeler un champ qui produit (spec.degel sans p.degele), et
--- seulement si la réserve atteint le plancher de chaque objet (Cp.ready). Rend ok, détail.
function Cp.go(p)
  if not (p and p.state == "reserve") then return false, "etat" end
  if p.reopened and p.reopened ~= 0 then return false, "rouvert" end
  local s = p.spec
  -- 0.7.114 (F676) : bande de champ dont les foreuses sont données (p.lead, build.lua) : départ par les foreuses, voie entière si dégel
  local c0 = s and s.champ
  if c0 and c0.coal == nil and c0.link == nil and p.lead and next(p.lead) ~= nil and not s.ext then
    return Cp.ready_band(p.need or {}, p.stock or {}, p.lead, s.degel ~= nil and not p.degele)
  end
  -- Lot SORTIE-PLAQUES (B5) : partir sans toute sa matière déclenchait le degel, qui retire les paires thermiques qui PRODUISENT ; la matière qui
  -- manque (tapis de la voie de charbon) ne se fabriquait plus sans leur fer (scarlet, graine 2507543475 : 23 fours sans charbon, fer 0/min).
  -- Une bande à dégeler garde le tout-ou-rien, comme Rr.partial_go (build.lua) ; la vue porte p.degele.
  if s and s.degel and not p.degele then return false, "degel" end
  if s and s.ext == true and not s.rangee then return Cp.ready_lead(p.need or {}, p.stock or {}, p.lead or {}) end -- lot CC-PETROLE
  local c = p.spec and p.spec.champ
  if not c then return false, "pas une bande" end
  if c.coal ~= nil or c.link ~= nil then return false, "reseau de charbon" end
  return Cp.ready(p.need or {}, p.stock or {})
end

--- Texte court d'un départ progressif (journal) : « 283/311 pieces reservees ; manque au plancher : a x2, b x1 ».
function Cp.describe(d)
  local parts = {}
  for _, s in ipairs(d and d.short or {}) do parts[#parts + 1] = s[1] .. " x" .. s[2] end
  return string.format("%d/%d pieces reservees%s", d and d.pieces or 0, d and d.total or 0,
    #parts > 0 and (" ; manque au plancher : " .. table.concat(parts, ", ")) or "")
end

return Cp
