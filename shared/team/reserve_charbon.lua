--[[
  Lot CHARBON-UNIFIE (directive « Mode Démon » du DC, 10/11, priorité 1 : « une fonction de réserve unique et atomique pour le charbon
  garantissant la priorité vitale absolue : centrale électrique > ravitaillement des brûleurs > usines secondaires »).

  Avant le lot, TROIS lecteurs du coffre du QG se servaient chacun selon sa règle : le planificateur retirait du stock virtuel le déficit
  des brûleurs (shared/team/planner.lua), le quai de la centrale lisait le stock moins ce même déficit (quai_tasks), l'amorce à la main
  lisait le stock brut (script/team/sante_centrale.lua). Deux coupes successives ont montré les deux falaises (RD_LOG F445, F455) :
  la centrale qui remplit son coffre pour 20 minutes (cible Cc.FILL_S, priorité 91) vide le coffre du QG pendant que 46 brûleurs sont à
  sec (banc V0676-D) ; la réserve des brûleurs étendue à l'amorce interdit à la centrale de se rallumer pendant toute la famine
  (V0677-FINAL-A : kW moyen 98 au lieu de 1 150, 1 bande finie au lieu de 8).

  Règle PURE (aucune API Factorio, aucun nom d'objet : le combustible est T.fuel chez l'appelant, l'avant-poste « de combustible » est
  celui dont le PRODUIT est le combustible, Rc.is_fuel_outpost) : le stock est découpé en PARTS, dans un ordre fixe, chaque part
  bornée par son besoin ; ce qui reste est LIBRE (projets, fabrication).
    1. vital    : l'amorce des chaudières à sec + le coffre de la centrale jusqu'à son SEUIL D'AVANCE (Cc.refill : low, 4 min de pleine
                  charge) : le courant de toute la base ; jamais retenu par les brûleurs.
    2. bruleurs : les tournées (déficit Σ(fill − fuel) des fours de l'équipe et des brûleurs des avant-postes qui ne produisent pas le
                  combustible) + un TAMPON consommation × horizon (Rc.buffer : la tournée suivante trouve de quoi partir, F455 (2)).
    3. confort  : le coffre de la centrale du seuil jusqu'à sa CIBLE (20 min) : il attend que les brûleurs soient servis.
    4. libre    : le reste (objets d'un nouvel avant-poste, fabrication).
  Tous les lecteurs appellent Rc.parts sur le même stock et prennent LEUR part : la centrale vital + confort, l'amorce vital, le
  planificateur libre. Déterministe (ordre fixe Rc.ORDER, entiers), jamais négatif.
]]
local Rc = {}

Rc.ORDER = { "vital", "bruleurs", "confort" } -- ordre de service (fixe : pas de `pairs`)
Rc.HORIZON_S = 120 -- secondes de consommation des brûleurs gardées au coffre au-delà du déficit instantané (une tournée)
Rc.LOGS = 30       -- lignes [FO-CHARBON-PARTS] au plus (le tag [FO-CHARBON] est celui des tournées courtes) par équipe

local function whole(n) n = tonumber(n) or 0 if n < 0 then return 0 end return math.floor(n + 1e-9) end

--- Parts du stock `stock` selon les besoins `need` = { vital, bruleurs, confort } (manquants = 0). Rend { vital, bruleurs, confort, libre,
--- stock } : chaque part = min(reste, besoin) dans l'ordre Rc.ORDER ; libre = le reste. Entiers, jamais négatifs.
function Rc.parts(stock, need)
  need = need or {}
  local rest = whole(stock)
  local out = { stock = rest }
  for _, k in ipairs(Rc.ORDER) do
    local n = whole(need[k])
    local take = n < rest and n or rest
    out[k] = take
    rest = rest - take
  end
  out.libre = rest
  return out
end

--- Besoin d'une centrale nourrie à la main : `n` charbon à son coffre, `low` seuil d'avance et `target` cible (Cc.refill), `prime` charbon
--- de l'amorce des chaudières à sec (0 sans amorce due). Rend { vital, confort }.
function Rc.need_centrale(n, low, target, prime)
  n, low, target = whole(n), whole(low), whole(target)
  local vital = (low > n and low - n or 0) + whole(prime)
  local base = n > low and n or low
  local confort = target > base and target - base or 0
  return { vital = vital, confort = confort }
end

--- Tampon des brûleurs : `rate` charbon/s consommé par les brûleurs servis en tournée, sur `horizon` secondes (Rc.HORIZON_S). Entier.
function Rc.buffer(rate, horizon)
  rate = tonumber(rate) or 0
  if rate <= 0 then return 0 end
  return math.ceil(rate * (horizon or Rc.HORIZON_S) - 1e-9)
end

--- Un avant-poste est « de combustible » quand son PRODUIT est le combustible (données, pas un nom de gisement).
function Rc.is_fuel_outpost(spec, fuel)
  return spec ~= nil and fuel ~= nil and spec.product == fuel
end

--- Le coffre du QG MANQUE-t-il de combustible : `stock` sous la somme des besoins `need` (parts de Rc.ORDER) ?
function Rc.short(stock, need)
  need = need or {}
  local sum = 0
  for _, k in ipairs(Rc.ORDER) do sum = sum + whole(need[k]) end
  return whole(stock) < sum
end

--- Lot CHARBON-TOURNEE (F477) : le PRODUCTEUR de combustible servi d'abord. Une tournée de ravitaillement porte au plus ce que le coffre du
--- QG contient ; quand il manque, la première tournée partie prend tout. Le producteur (Rc.is_fuel_outpost) à sec passe alors à
--- Rc.PRODUCER_PRIO, devant les brûleurs qu'il nourrit (une foreuse de combustible rend plusieurs fois ce qu'elle brûle) ; mesure (banc
--- CHARBON-A4, graine 123456789) : de 56,3 à 65,7 min ses quatre tournées partent à 95 comme celles des 66 brûleurs de fer, trois sur quatre
--- avec 0 charbon (coffre du QG 0), 49 brûleurs à sec à 60 min. a = { fuel = avant-poste de combustible, low = brûleurs bas (o.fuel_low),
--- short = Rc.short du coffre, safe = ni meurtrier ni dangereux }. Rend la priorité (jamais abaissée).
Rc.PRODUCER_PRIO = 96 -- = Fx.VITAL_PRIO (shared/team/flux.lua) : devant les ravitaillements (95), derrière la garde du QG menacé (96, à égalité)
function Rc.producer_prio(base, a)
  a = a or {}
  if a.fuel and a.low and a.short and a.safe and (tonumber(base) or 0) < Rc.PRODUCER_PRIO then return Rc.PRODUCER_PRIO end
  return base
end

--- Lot CHARBON-TOURNEE (F477, second maillon) : AMORCE SUR PLACE du producteur. Servi le premier, il part quand même à vide si le coffre du
--- QG est à 0 ; et le minage de fond ne trouve pas de combustible à portée du QG (banc TOURNEE-A, graine 123456789 : coffre à 0 de 57 à
--- 90 min, producteur refait à 63,6 min sans charbon, « minage a la main de 'coal' sans tuile libre ni sure (rayon 96) » à 78,8, 81,8 et
--- 84,8 min, 46 à 58 brûleurs à sec de 60 à 90 min). Son gisement EST le combustible : la tournée en mine à la main sur place, juste de quoi
--- relancer ses foreuses (Rc.PRIME_PER par foreuse, l'amorce d'un avant-poste neuf), ce que le coffre ne porte pas.
--- a = { fuel = avant-poste de combustible, carry = combustible voulu au départ (après ses coffres), stock = coffre du QG, drills = foreuses }.
--- Rend le nombre à miner sur place (0 sinon).
Rc.PRIME_PER = 2 -- combustibles par foreuse (= l'amorce d'un avant-poste de combustible neuf, shared/team/planner.lua outpost_items)
function Rc.prime_on_site(a)
  a = a or {}
  if not a.fuel then return 0 end
  local lack = whole(a.carry) - whole(a.stock)
  if lack <= 0 then return 0 end
  local cap = Rc.PRIME_PER * whole(a.drills)
  return lack < cap and lack or cap
end

--- Ce que la centrale peut prendre (vital + confort), ce que l'amorce peut prendre (vital), ce qui reste à la fabrication (libre).
function Rc.centrale(stock, need) local p = Rc.parts(stock, need) return p.vital + p.confort end
function Rc.vital(stock, need) return Rc.parts(stock, need).vital end
function Rc.libre(stock, need) return Rc.parts(stock, need).libre end

--- Ligne de journal [FO-CHARBON-PARTS] (une par changement d'état chez l'appelant).
function Rc.line(who, minute, p, need)
  need = need or {}
  return string.format("[FO-CHARBON-PARTS] %s : coffre du QG %d charbon(s) a %.1f min : vital %d/%d, bruleurs %d/%d, confort %d/%d, libre %d",
    tostring(who), p.stock or 0, minute or 0, p.vital or 0, whole(need.vital), p.bruleurs or 0, whole(need.bruleurs),
    p.confort or 0, whole(need.confort), p.libre or 0)
end

return Rc
