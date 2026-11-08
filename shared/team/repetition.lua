--[[
  REPETITION (lot FONTE-MULTI, demande du DC du 8/11 : « les gisements sont vides à 80 % », saturation totale). Règles PURES : aucune
  API Factorio, aucun nom d'objet (côtés, portées et couvertures arrivent en DONNÉES ; tests/repetition_test.lua).

  Constat (FONTE-DYN, lecture du code, 8/11) : une ligne de foreuses du plan directeur tient dans UN lot et au plus pairs_line paires
  (7 avec la foreuse électrique) : sa zone minée est Rg.area(3, 7, 1) = 207 tuiles. Un champ de 600 tuiles ne peut pas être saturé par une
  ligne. Et la couverture de P.fit compte le minerai sous la zone minée SANS retirer celui qu'une ligne déjà posée mine : une deuxième
  ligne posée contre la première peut avoir 80 % de « minerai » dont l'essentiel est déjà miné, et n'ajouter presque rien.

  Rp.zone_add(zone, tx0, ty0, side, reach)   -> marque dans `zone` (ensemble de clés) la zone minée d'un corps de foreuse dont le coin
                                                haut-gauche est (tx0, ty0) : side + 2·reach tuiles de côté.
  Rp.fresh(ores, zone, key)                  -> copie de `ores` sans les tuiles déjà minées (même axe, même `foreign`) et le nombre de
                                                tuiles restantes ; la ligne suivante se mesure sur CE minerai-là.
  Rp.size_next(fresh_n, side, reach, covers, max_pairs) -> (paires, couverture) de la ligne suivante d'après le minerai restant : la
                                                première couverture de l'échelle `covers` (80 % d'abord, puis plus bas, jusqu'au dernier
                                                essai du bord de gisement) qui tient au moins une paire ; (0, nil) sinon.
  Rp.lines_wanted(s)                         -> (lignes de plus, cause) pour couvrir le gisement ; s = { field, covered, per_line, target,
                                                free, min_free, max_lines, in_flight, last_gain, min_gain }.
  Causes : "sature", "reste_trop_petit", "sans_progres", "plafond", "ok", "invalide" : toujours écrites (aucun cas silencieux).
  Déterminisme : aucun pairs décisionnel dans les règles (le comptage de `fresh` n'en dépend pas), aucun temps mesuré.
]]
local Rg = require("shared.team.rangees")
local Rp = {}

local EPS = 1e-9
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

Rp.TARGET = 1.0            -- saturation visée : tout le minerai du gisement sous une foreuse
Rp.EPS_TILES = 8           -- sous ce nombre de tuiles non couvertes, le gisement est dit saturé (bruit de bord)
Rp.MIN_GAIN = 12           -- tuiles de plus que la dernière ligne doit avoir apportées, sinon « sans progrès » (garde-fou anti-boucle)
Rp.MAX_LINES = 8           -- plafond de sûreté de lignes de plus pour un gisement

local function num(x) return type(x) == "number" and x == x and x > -math.huge and x < math.huge end

--- Marque la zone minée d'un corps de foreuse (côté `side`, coin haut-gauche tuile (tx0, ty0)), portée `reach`. `key(tx, ty)` fabrique la clé.
function Rp.zone_add(zone, tx0, ty0, side, reach, key)
  if type(zone) ~= "table" or not (num(tx0) and num(ty0) and num(side) and num(reach)) or side < 1 or reach < 0 then return 0 end
  local n = 0
  for ty = ty0 - reach, ty0 + side - 1 + reach do
    for tx = tx0 - reach, tx0 + side - 1 + reach do
      local k = key(tx, ty)
      if not zone[k] then zone[k] = true; n = n + 1 end
    end
  end
  return n
end

--- Minerai restant : copie de `ores` (ensemble de clés, avec `axis` et `foreign` éventuels) sans les tuiles de `zone`. `keys` : liste des
--- clés de tuile du lot (ordre quelconque, comptage seulement). Rend l'ensemble et le nombre de tuiles de minerai restantes.
function Rp.fresh(ores, zone, keys)
  local out, n = {}, 0
  for _, k in ipairs(keys or {}) do
    if ores[k] and not (zone and zone[k]) then out[k] = true; n = n + 1 end
  end
  out.axis, out.foreign = ores.axis, ores.foreign
  return out, n
end

--- Ligne suivante d'après le minerai restant `fresh_n` : parcourt l'échelle de couvertures (de la plus haute à la plus basse) ; la première
--- qui donne au moins une paire gagne. `covers` : liste décroissante, par exemple { 0.8, 0.5, 0.3 }.
function Rp.size_next(fresh_n, side, reach, covers, max_pairs)
  if not (num(fresh_n) and num(side) and num(reach) and num(max_pairs)) or fresh_n <= 0 or max_pairs < 1 then return 0, nil end
  for _, cv in ipairs(covers or {}) do
    local n = Rg.pairs_for_tiles(fresh_n, side, reach, cv, max_pairs)
    if n >= 1 then return n, cv end
  end
  return 0, nil
end

--- Lignes de plus pour saturer un gisement. field : tuiles de minerai du gisement ; covered : tuiles déjà minées ; per_line : tuiles de
--- minerai qu'une ligne pleine apporte (pairs_line × couverture) ; target : part visée (Rp.TARGET) ; free : minerai restant HORS zones
--- minées, sur des lots encore posables ; min_free : plus petit reste qui vaut une ligne ; max_lines : plafond ; in_flight : lignes déjà
--- demandées et pas encore posées (comptées pour per_line chacune) ; last_gain / min_gain : tuiles qu'a apportées la dernière ligne
--- posée (nil : pas encore de mesure).
function Rp.lines_wanted(s)
  s = s or {}
  if not (num(s.field) and num(s.covered) and num(s.per_line)) or s.field <= 0 or s.per_line <= 0 then return 0, "invalide" end
  local target = num(s.target) and s.target or Rp.TARGET
  local rest = target * s.field - s.covered - (num(s.in_flight) and s.in_flight or 0) * s.per_line
  if rest <= (num(s.eps) and s.eps or Rp.EPS_TILES) then return 0, "sature" end
  if num(s.free) and s.free < (num(s.min_free) and s.min_free or Rp.EPS_TILES) then return 0, "reste_trop_petit" end
  if num(s.last_gain) and s.last_gain < (num(s.min_gain) and s.min_gain or Rp.MIN_GAIN) then return 0, "sans_progres" end
  local n = ceil(rest / s.per_line - EPS)
  if num(s.free) then n = min(n, max(1, ceil(s.free / s.per_line - EPS))) end -- jamais plus de lignes que le minerai libre n'en porte
  local cap = num(s.max_lines) and s.max_lines or Rp.MAX_LINES
  if n > cap then return cap, "plafond" end
  return max(1, n), "ok"
end

return Rp
