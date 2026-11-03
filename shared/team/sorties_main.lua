--[[
  Lot CHARBON-MAIN (retour du DC du 3/11, partie de 2 h 30) : « 35 foreuses thermique qui ne sont plus alimentées, des milliers de charbons
  réunis dans les coffres (de ces mêmes foreuses) et ils minent à la main juste à côté comme des débiles pour récupérer du charbon ?! ».

  Chaîne (fo-logs/2026-11-03_CHARBONMAIN/RAPPORT.md) :
    1. le stock que voit le minage à la main est le COFFRE du QG et ses annexes (script/team/stock.lua) ; les coffres de SORTIE des
       avant-postes BRUTS (produit = ressource : le charbon, la pierre) n'y comptent pas, seule la tournée « service » les rapporte ;
    2. un minage du cerveau porte toujours son manque mesuré (`short`) : Mi.hand_verdict (shared/team/main_inventaire.lua) le laisse
       passer, coffre vide ;
    3. à la place de marché, ce minage (jusqu'à 85 × facteur de besoin 1,5) bat la tournée (70, 95 à sec ; distance retirée).
  Règles (PURES : aucune API du moteur, aucun nom d'objet ; les types d'avant-poste arrivent en DONNÉES : spec = T.outposts) :
    Sm.raw_kinds(spec)            -> { [type] = ressource } : avant-postes BRUTS (leur produit est leur ressource : sortie = la ressource).
    Sm.counted(o)                 -> ses sorties comptent-elles ? (pas meurtrier, pas dangereux, pas Sm.FAILS_MAX tournées ratées de suite,
                                     tournée pas libre depuis Sm.STALE_TICKS : personne n'y va, le minage reprend la main).
    Sm.dormant(rows, raw, item)   -> objets `item` dans les sorties des avant-postes bruts comptés, et leurs ids (le plus garni d'abord).
    Sm.hand_ok(a)                 -> mine-t-on `item` à la main ? Non quand ses sorties en ont Sm.MIN au moins : on va les chercher.
    Sm.fetch_prio(base, o, raw, have) -> priorité de la tournée d'un avant-poste brut : Sm.FETCH_PRIO (une urgence) quand ses sorties ont
                                     Sm.MIN de sa ressource et que le coffre en a moins de Sm.COVER ; sinon `base`.
    Sm.carry_fuel(need, self, own) -> combustible porté du coffre vers un avant-poste : celui de combustible ne prend que ce que ses propres
                                     sorties ne couvrent pas (avant : jamais rien, d'où un avant-poste à sec, coffres vides, qui ne repart plus).
  Interrupteur par équipe (bancs) : f.team.sorties_regle == false coupe tout (comportement de 0.6.41). Défaut : allumé.
]]
local Sm = {}

Sm.MIN = 20          -- objets d'une ressource dans les sorties à partir desquels on va les chercher plutôt que la miner à la main
Sm.COVER = 100       -- le coffre « manque » d'une ressource brute en deçà (la tournée de ses sorties devient une urgence)
Sm.FETCH_PRIO = 91   -- au-dessus de M.URGENT (90) : devant le minage (85 au plus), sous la garde du QG menacé (96)
Sm.FAILS_MAX = 3     -- tournées ratées de suite au-delà desquelles les sorties ne comptent plus (personne n'y arrive : mieux vaut miner)
Sm.STALE_TICKS = 5 * 3600 -- tournée libre depuis 5 min sans preneur : ses sorties ne comptent plus (le minage reprend la main)

local function num(v) return type(v) == "number" and v or 0 end

--- La règle est-elle allumée pour cette équipe ? flag = f.team.sorties_regle (nil : défaut, allumée).
function Sm.on(flag) return flag ~= false end

-- Lot CHARBON3 (A/B du lead, 3/11) : les TROIS parties de la règle, chacune avec son interrupteur par équipe (f.team.sorties_<partie>,
-- nil : défaut de Sm.PARTS) : « main » = refus du minage à la main (Sm.hand_ok), « prio » = tournée urgente à Sm.FETCH_PRIO
-- (Sm.fetch_prio), « porte » = combustible porté du coffre vers un avant-poste de combustible (Sm.carry_fuel).
Sm.PARTS = { main = true, prio = true, porte = false }

--- Partie `name` allumée ? all = f.team.sorties_regle (false coupe tout), flag = f.team.sorties_<name> (nil : défaut Sm.PARTS).
function Sm.part(all, flag, name)
  if all == false then return false end
  if flag ~= nil then return flag and true or false end
  return Sm.PARTS[name] == true
end

--- spec = { [type] = { resource, product, ... } } -> { [type] = ressource } des avant-postes dont le produit EST la ressource.
function Sm.raw_kinds(spec)
  local out = {}
  for kind, s in pairs(spec or {}) do
    if s.resource ~= nil and s.product == s.resource then out[kind] = s.resource end
  end
  return out
end

--- o = { lethal, unsafe, fails, free_age } : les sorties de cet avant-poste comptent-elles ?
function Sm.counted(o)
  if not o or o.lethal or o.unsafe then return false end
  if num(o.free_age) >= Sm.STALE_TICKS then return false end
  return num(o.fails) < Sm.FAILS_MAX
end

--- rows = { { id, kind, outputs = { [objet] = n }, lethal, unsafe, fails } } ; raw = Sm.raw_kinds ; item = la ressource.
--- Rend le total de `item` dans les sorties des avant-postes bruts COMPTÉS, et leurs ids (quantité décroissante, puis id croissant).
function Sm.dormant(rows, raw, item)
  local list, total = {}, 0
  for _, o in ipairs(rows or {}) do
    if raw[o.kind] == item and Sm.counted(o) then
      local n = num(o.outputs and o.outputs[item])
      if n > 0 then
        total = total + n
        list[#list + 1] = { id = o.id, n = n }
      end
    end
  end
  table.sort(list, function(a, b)
    if a.n ~= b.n then return a.n > b.n end
    return tostring(a.id) < tostring(b.id)
  end)
  local ids = {}
  for i, x in ipairs(list) do ids[i] = x.id end
  return total, ids
end

--- a = { dormant = objets dans les sorties comptées, crisis = crise injectée par un banc }. Rend ok, raison.
--- Le mode survie n'est PAS exempté : les sorties d'un avant-poste dangereux ne comptent déjà pas (Sm.counted).
function Sm.hand_ok(a)
  if a.crisis then return true, "crise" end
  if num(a.dormant) >= Sm.MIN then return false, "sorties" end
  return true, "rien"
end

--- base = priorité du planificateur ; o = { kind, outputs, lethal, unsafe, fails } ; raw = Sm.raw_kinds ; have = la ressource au coffre.
function Sm.fetch_prio(base, o, raw, have)
  local res = o and raw[o.kind]
  if not res or not Sm.counted(o) then return base end
  if num(o.outputs and o.outputs[res]) < Sm.MIN or num(have) >= Sm.COVER then return base end
  return math.max(num(base), Sm.FETCH_PRIO)
end

--- Combustible qu'une tournée PORTE du coffre du QG vers un avant-poste. need = combustible qui manque à ses brûleurs ; self_fuel = son
--- produit EST le combustible ; own = combustible déjà dans ses propres sorties. Avant le lot, un avant-poste de combustible ne recevait
--- JAMAIS de combustible du coffre (il se ravitaillait sur sa sortie) : à sec avec des coffres vides, il ne repartait plus (banc champ-longue
--- 20261020 sur main 0.6.41 : votre équipe, 12 foreuses de charbon sur 12 à sec à 150 min, sorties à 0, 24 minages de charbon à la main).
function Sm.carry_fuel(need, self_fuel, own)
  need = num(need)
  if need <= 0 then return 0 end
  if not self_fuel then return need end
  return math.max(0, need - num(own))
end

return Sm
