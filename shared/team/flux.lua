--[[
  Lot FLUX (retour du DC du 2/11 sur 0.6.34, points 4, 6, 12, 15, 17) : ce qui DORT dans les sorties des avant-postes, le minage à
  la main alors que le stock couvre, et le ravitaillement de ce qui produit. PUR : aucune API Factorio, aucun nom d'objet (les
  correspondances minerai -> plaque, le combustible et les produits arrivent en DONNÉES, lues par les appelants dans
  shared/team/config.lua ; tests/flux_test.lua).

  Le DC : « ils ont des dizaines de milliers de plaques de fer [...] il est en train de miner du fer à la main » ; « plus de 3000
  plaques de fer qui attendent dans les fours » ; « 5700 de charbon et ils l'utilisent même pas pour relancer les foreuses
  thermiques » ; « lors d'une attaque ils vont arrêter [...] de les remplir et de récolter le cuivre qui se trouve dans les fours ».

  Chaîne mesurée dans ses journaux (0.6.34, fo-logs/2026-11-02_FLUX/RAPPORT.md) :
    1. la vue de stock du cerveau est le COFFRE seul (script/team/team.lua, view.stock) : les plaques d'un four d'avant-poste (pile de
       100 au plus, puis le four s'arrête) n'y comptent pas, et seule la tournée « service » les rapporte ;
    2. cette tournée (70) perd à la note contre le minage (jusqu'à 85 × facteur de besoin) et le travail proche (la note retire la
       distance) : elle reste libre des heures, des fours pleins s'arrêtent, le coffre reste à 0, le cerveau fait miner ;
    3. le minage de fond / de la file sûre / du renfort de fer compare le MINERAI au coffre à une cible (200), jamais les plaques.

  Règles :
    Fx.repatriable(rows)             -> { [objet] = n } : ce que les sorties des avant-postes rapporteront (comptées : pas meurtrier,
                                        tournée libre depuis moins de Fx.STALE_TICKS) ; ajouté aux objets « attendus » de la vue.
    Fx.equiv(...)                    -> minerai ÉQUIVALENT d'une ressource : minerai au coffre + plaques (coffre et sorties) en minerai.
    Fx.service_prio(base, o, vital, have) -> priorité d'une tournée : ravitaillement d'un avant-poste vital (96), sorties bloquées
                                        pendant que le coffre manque du produit (88).
    Fx.aged(prio, waited, kind)      -> priorité d'une tournée qui attend : +1 par Fx.AGE_STEP ticks, plafonnée ; urgence après 3 min
                                        pour un ravitaillement vital ou des sorties pleines.
    Fx.vital(spec, fuel, inputs)     -> { [type d'avant-poste] = vrai } : ceux dont le produit est une plaque fondue au QG ou le
                                        combustible.
    Fx.refill_to(coal, burners, base, max) -> niveau de remplissage des brûleurs d'une tournée (10 à 50 selon le coffre).
    Fx.drop_service(o, dropped)      -> la tournée d'un produit saturé est-elle retirée ? Pas quand ses sorties sont pleines.
]]
local Fx = {}

Fx.STUCK_AT = 90          -- sortie de four au moins aussi pleine (pile de 100) : le four ne fond plus
Fx.STALE_TICKS = 5 * 3600 -- une tournée libre depuis 5 min : ses sorties ne sont plus comptées (le minage reprend la main)
Fx.AGE_STEP = 600         -- +1 de priorité toutes les 10 s d'attente
Fx.AGE_CAP = 80           -- plafond d'une tournée ordinaire qui vieillit
Fx.AGE_CAP_STUCK = 88     -- plafond d'une tournée dont les fours sont pleins (sous M.URGENT = 90 : ni ruée, ni préemption)
Fx.AGE_CAP_DRY = 97       -- plafond d'un ravitaillement vital qui attend (la garde du QG menacé est à 96 : jamais devant elle d'un coup)
Fx.URGENT = 90            -- M.URGENT (shared/ai3/marche.lua) : seuil des urgences
Fx.URGENT_AFTER = 3 * 3600 -- attente (3 min) au-delà de laquelle une tournée vitale ou de sorties pleines devient une urgence
Fx.VITAL_PRIO = 96        -- ravitailler ce qui produit passe devant tout sauf la défense d'urgence
Fx.FAILS_MAX = 3          -- tournées ratées de suite (chemin, danger) au-delà desquelles ses sorties ne sont plus comptées
Fx.REFILL_MAX = 50        -- charbons au plus par brûleur (la pile)
Fx.COVER = 100            -- plaques au coffre en deçà desquelles un produit « manque » à la tournée de ses sorties

--- Types d'avant-poste VITAUX : leur produit est le combustible ("fuel"), ou une plaque que le QG fond à partir de la ressource de
--- l'avant-poste ("plate") (spec = T.outposts, fuel = T.fuel, inputs = T.smelter_inputs = { produit = { entrée, quantité } }).
function Fx.vital(spec, fuel, inputs)
  local out = {}
  for kind, s in pairs(spec or {}) do
    local input = inputs and inputs[s.product]
    if s.product == fuel then out[kind] = "fuel"
    elseif input and input[1] == s.resource then out[kind] = "plate" end
  end
  return out
end

--- Objets dont les sorties comptent (Fx.repatriable) : les plaques de la carte minerai -> plaque.
function Fx.plates_of(map)
  local out = {}
  for _, m in pairs(map or {}) do out[m.plate] = true end
  return out
end

--- Correspondance minerai -> { plaque, ratio } (ratio = minerai par plaque) pour les avant-postes dont le produit est une plaque
--- fondue à partir de leur ressource. order = T.OUTPOST_ORDER (ordre stable).
function Fx.plate_map(order, spec, inputs)
  local out = {}
  for _, kind in ipairs(order or {}) do
    local s = spec[kind]
    local input = s and inputs and inputs[s.product]
    if input and input[1] == s.resource then out[s.resource] = { plate = s.product, ratio = input[2] or 1 } end
  end
  return out
end

--- Les sorties de cet avant-poste comptent-elles comme des objets à venir ? Pas un avant-poste meurtrier (un PNJ y est mort il y a
--- peu), pas une tournée libre depuis trop longtemps, ni ratée Fx.FAILS_MAX fois de suite (personne n'y arrive : mieux vaut miner que
--- compter sur elle).
function Fx.counted(o)
  if o.lethal or o.unsafe then return false end
  if (o.fails or 0) >= Fx.FAILS_MAX then return false end
  if (o.free_age or 0) >= Fx.STALE_TICKS then return false end
  return true
end

--- Objets que les sorties des avant-postes rapporteront. rows = { { outputs = { [objet] = n }, lethal, free_age, ... } } ; only = { [objet]
--- = vrai } (facultatif) : seuls ces objets comptent (les PLAQUES : le charbon d'un coffre d'avant-poste est du combustible que la centrale
--- et les brûleurs attendent AU COFFRE ; compté « attendu », il aurait masqué la pénurie : banc dc-croissance 271828182, Écarlate).
--- Rend la table et le total ; les objets sont sommés dans l'ordre des rangées puis des noms (aucun pairs dans une décision).
function Fx.repatriable(rows, only)
  local out, total = {}, 0
  for _, o in ipairs(rows or {}) do
    if Fx.counted(o) then
      local names = {}
      for k in pairs(o.outputs or {}) do names[#names + 1] = k end
      table.sort(names)
      for _, k in ipairs(names) do
        local n = o.outputs[k]
        if type(n) == "number" and n > 0 and (only == nil or only[k] == true) then
          out[k] = (out[k] or 0) + n
          total = total + n
        end
      end
    end
  end
  return out, total
end

--- Minerai ÉQUIVALENT d'une ressource : le minerai libre au coffre plus les plaques qu'elle donne (coffre et sorties), en minerai.
--- map = Fx.plate_map ; stock = objets libres du coffre ; repat = Fx.repatriable. Une ressource sans plaque : son stock seul.
function Fx.equiv(res, map, stock, repat)
  local have = math.max(0, (stock and stock[res]) or 0)
  local m = map and map[res]
  if not m then return have end
  local plates = math.max(0, (stock and stock[m.plate]) or 0) + math.max(0, (repat and repat[m.plate]) or 0)
  return have + plates * m.ratio
end

--- Priorité d'une tournée. base : celle du planificateur ; o : { fuel_low, stuck } de l'avant-poste ; vital : sa classe (Fx.vital) :
--- un avant-poste de COMBUSTIBLE à sec passe à 96 (sans son charbon, plus rien ne tourne : un brûleur de charbon rend six fois ce qu'il
--- brûle), un avant-poste de plaque à sec garde 95 et vieillit (Fx.aged) ; have : objets de son produit au coffre.
function Fx.service_prio(base, o, vital, have)
  local p = base
  if o.unsafe or o.lethal then return p end -- jamais d'urgence vers un avant-poste que la porte refuserait
  if vital == "fuel" and o.fuel_low then p = math.max(p, Fx.VITAL_PRIO) end
  if (o.stuck or 0) > 0 and (have or 0) < Fx.COVER then p = math.max(p, Fx.AGE_CAP_STUCK) end
  return p
end

--- Priorité d'une tournée qui attend depuis `waited` ticks (créée au tableau) : monte d'un cran toutes les Fx.AGE_STEP, sans jamais
--- dépasser son plafond (ni diminuer une priorité déjà au-dessus). Une tournée qui attend toujours finit par passer devant le
--- travail proche qui la battait à la note (la note retire la distance). kind = { stuck = sorties pleines, dry = brûleur vital à sec } :
--- au-delà de Fx.URGENT_AFTER d'attente, une tournée de l'un ou l'autre devient une URGENCE (M.URGENT : elle passe devant le minage).
function Fx.aged(prio, waited, kind)
  kind = kind or {}
  waited = waited or 0
  if kind.unsafe then return prio end
  local cap = Fx.AGE_CAP
  if kind.stuck then cap = Fx.AGE_CAP_STUCK end
  if kind.dry then cap = Fx.AGE_CAP_DRY end
  local p = prio
  if p < cap and waited > 0 then p = math.min(cap, p + math.floor(waited / Fx.AGE_STEP)) end
  if (kind.stuck or kind.dry) and waited >= Fx.URGENT_AFTER and p < Fx.URGENT then p = Fx.URGENT end
  return p
end

--- La tournée d'un avant-poste dont le produit est SATURÉ au coffre (ou couvert par un module) est-elle retirée ? Pas quand ses
--- sorties sont pleines : il s'arrête, et la saturation d'aujourd'hui est la pénurie de demain (les 17 fours à 100 plaques de
--- cuivre du DC). `dropped` : ce que la règle d'avant décidait.
function Fx.drop_service(o, dropped)
  if not dropped then return false end
  return (o.stuck or 0) == 0
end

--- Niveau auquel une tournée REMPLIT chaque brûleur (foreuse à combustion, four d'avant-poste) : `base` (T.fuel_refill_to) quand le coffre
--- est pauvre, jusqu'à `max` (la pile d'un brûleur) quand il est riche : au plus la moitié du charbon du coffre sert au remplissage
--- (coal / (2 × brûleurs)). « 5700 de charbon » au coffre et des foreuses thermiques à sec : à 10 charbons, un brûleur tient 4 min et
--- exige une visite toutes les 3 min ; à 25, 11 min : la production ne dépend plus d'un PNJ libre à l'instant (crise, attaque).
function Fx.refill_to(coal, burners, base, max)
  base = base or 10
  max = max or base
  if (burners or 0) <= 0 then return base end
  local per = math.floor(math.max(0, coal or 0) / (2 * burners))
  return math.max(base, math.min(max, per))
end

--- Sorties pleines : nombre de réceptacles (de `outs`, la sortie de chacun) à STUCK_AT ou plus.
function Fx.stuck_count(outs)
  local n = 0
  for _, v in ipairs(outs or {}) do if (v or 0) >= Fx.STUCK_AT then n = n + 1 end end
  return n
end

return Fx
