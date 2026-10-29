--[[
  Lot PRIORITE-RESSOURCES : ordre entre la PRODUCTION de ressources et la DÉFENSE quand l'équipe manque de fer. PUR (aucune
  API Factorio, aucun nom d'objet : l'appelant passe des nombres ; shared/team/planner.lua et shared/ai3/projets.lua l'utilisent).

  Remarque du Directeur Créatif (29/10, vers 15 h) : « si on manque cruellement de ressources, l'objectif est justement ces
  ressources, pas la défense, la défense viendra tout juste après du coup, mais si on peut pas se l'acheter, on investit les
  ressources dans la production de plus de ressources ».

  Avant ce lot, « défendre d'abord » (lot IA1-b2) faisait l'inverse quand le fer baissait : un avant-poste sans sa tourelle ne
  s'agrandissait pas, un nouvel avant-poste d'un type déjà exploité attendait ses tourelles, la tâche de pose des tourelles
  (priorité 90) prenait le fer avant la reconstruction et l'objectif (80), et l'échelle d'objectifs restait sur « armée » ou
  « fortifier » avant « fer II ».

  Règle (Pr.decide), tout en unités de la plaque clé (le fer), mesurées par l'appelant sur le livre de recettes :
    funds           fer disponible (stock virtuel)
    defense_cost    fer qu'il faut pour TOUTE la défense voulue (tourelles manquantes et leurs chargeurs, objectif militaire en cours)
    production_cost fer du PROCHAIN pas de production utile (le moins cher : 2 paires foreuse + four, ou reconstruction minimale) ;
                    nil : aucun pas de production à faire ; 0 : un pas qui ne coûte pas de fer (objets déjà au stock)
    survival        l'équipe est sous son effectif de départ : la survie (recrues équipées) garde la main, règle d'avant
    survie          lot SURVIE-PENURIE : mode survie de l'équipe (pénurie durable d'une matière clé) : la production d'abord, toujours
  Modes :
    survie              règle d'avant (rien ne change)
    rien                ni défense ni production à faire
    defense             rien à produire : la défense comme avant
    production          rien à défendre : la production comme avant
    defense_d_abord     le fer paie les DEUX (funds >= defense_cost + production_cost) : la défense d'abord, comme avant
    production_d_abord  le fer ne paie pas les deux : la PRODUCTION d'abord. Alors (1) un avant-poste sans sa tourelle s'agrandit
                        quand même et un nouvel avant-poste se bâtit sans ses tourelles, (2) le pas de production est réservé
                        pendant l'achat de la défense (`hold`) : la défense ne dépense que le fer AU-DELÀ (`defense_budget`) ;
                        la défense s'achète donc dès que le fer dépasse le coût du pas (« tout juste après »), (3) les objectifs
                        militaires de l'échelle (armée, fortifier, munitions) passent après les objectifs de production.
  Ce n'est PAS un plancher de réserve : la réservation ne vaut que le temps de l'achat de la défense (le fer revient aussitôt au
  stock pour la reconstruction et l'objectif), elle est bornée au prix d'UN pas, et la défense n'est jamais retenue quand le
  fer paie les deux.
]]

local Pr = {}

Pr.MODE_SURVIE = "survie"
Pr.MODE_RIEN = "rien"
Pr.MODE_DEFENSE = "defense"
Pr.MODE_PRODUCTION = "production"
Pr.MODE_DEFENSE_D_ABORD = "defense_d_abord"
Pr.MODE_PRODUCTION_D_ABORD = "production_d_abord"
Pr.MODE_SURVIE_PENURIE = "survie_penurie" -- lot SURVIE-PENURIE (shared/team/survie.lua) : la production d'abord, même si le fer paie les deux

local function num(x)
  if type(x) ~= "number" or x ~= x or x < 0 then return 0 end
  return x
end

--- a = { funds, defense_cost, production_cost (nil : aucun pas), survival }.
--- Rend { mode, production_first (vrai : la production passe avant la défense), hold (fer réservé à la production pendant
--- l'achat de la défense), defense_budget (fer que la défense peut dépenser), funds, defense_cost, production_cost }.
function Pr.decide(a)
  a = a or {}
  local funds, cd = num(a.funds), num(a.defense_cost)
  local has_step = a.production_cost ~= nil
  local cp = num(a.production_cost)
  local out = { mode = Pr.MODE_RIEN, production_first = false, hold = 0, defense_budget = funds, funds = funds,
    defense_cost = cd, production_cost = has_step and cp or nil }
  if a.survival then
    out.mode = Pr.MODE_SURVIE
  elseif not has_step then
    out.mode = cd > 0 and Pr.MODE_DEFENSE or Pr.MODE_RIEN
  elseif cd <= 0 then
    out.mode = Pr.MODE_PRODUCTION
  elseif funds >= cd + cp then
    out.mode = Pr.MODE_DEFENSE_D_ABORD
  else
    out.mode = Pr.MODE_PRODUCTION_D_ABORD
    out.production_first = true
    out.hold = math.min(funds, cp)
    out.defense_budget = funds - out.hold
  end
  -- Lot SURVIE-PENURIE (`survie` : l'équipe est en mode survie, une matière clé lui manque durablement) : la production passe d'abord
  -- QUEL QUE SOIT l'état du fer, dès qu'un pas de production existe ; le pas est réservé, la défense a le reste. La survie des
  -- effectifs (`survival`) garde la main : une équipe décimée équipe d'abord ses recrues.
  if a.survie and not a.survival and has_step then
    out.mode = Pr.MODE_SURVIE_PENURIE
    out.production_first = true
    out.hold = math.min(funds, cp)
    out.defense_budget = funds - out.hold
  end
  return out
end

--- Un objectif de l'échelle est-il MILITAIRE (soldats, tourelles d'avant-poste, réserve de la seule munition `ammo`) ? `need` :
--- le champ `need` de l'objectif (shared/team/config.lua, T.ladder). `ammo` : le nom de la munition (T.turret_ammo), donné par
--- l'appelant.
function Pr.military_need(need, ammo)
  if type(need) ~= "table" then return false end
  if need.soldiers or need.outpost_turrets then return true end
  if need.stock then
    local any = false
    for item in pairs(need.stock) do
      if item ~= ammo then return false end
      any = true
    end
    return any and not (need.outposts or need.smelters or need.tech)
  end
  return false
end

--- L'objectif est-il sauté ? Seulement quand la production passe d'abord et que l'objectif est militaire.
function Pr.skip_goal(pri, need, ammo)
  return pri ~= nil and pri.production_first == true and Pr.military_need(need, ammo)
end

--- Le plus petit coût d'une liste de pas de production ({ n, n, ... }, nil ignorés) ; nil si la liste est vide.
function Pr.cheapest(costs)
  local best
  for _, c in ipairs(costs or {}) do
    if type(c) == "number" and (best == nil or c < best) then best = c end
  end
  return best
end

return Pr
