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
]]

local Cp = {}

Cp.SHARE = 2 / 3 -- part du besoin de chaque objet réservée au coffre pour partir (azure p4 : 131/149 tapis = 88 % -> part à 30 min au lieu de 64)

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

--- Un projet `p` (vue : state, reopened, spec.champ, stock, need) peut-il partir en chantier progressif ? Seulement une bande de champ
--- NEUVE (spec.champ posé par le plan directeur du champ) en état « reserve », jamais un projet rouvert (Rr.partial_go le couvre), et
--- seulement si la réserve atteint le plancher de chaque objet (Cp.ready). Rend ok, détail de Cp.ready (ou raison).
function Cp.go(p)
  if not (p and p.state == "reserve") then return false, "etat" end
  if p.reopened and p.reopened ~= 0 then return false, "rouvert" end
  if not (p.spec and p.spec.champ) then return false, "pas une bande" end
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
