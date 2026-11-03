--[[
  Lot MUNITIONS (retour du DC du 3/11, partie 0.6.46 : « ils ont sous-produit des balles, donc les tourelles n'étaient pas chargées
  complètement [...] ils ont pas rempli à fond les munitions et l'attaque était trop grosse et du coup ça a balayé complètement tous les
  canons »). PUR : aucune API Factorio, aucun nom d'objet ; l'appelant passe des nombres. Testé hors jeu : tests/munitions_test.lua (mutants).

  Mesuré (fo-logs/2026-11-03_RETOUR3/factorio-current.log, votre équipe) :
    * une tourelle tire 10 balles par seconde, un chargeur en contient 10 : la cible de 20 chargeurs par tourelle (T.turret_ammo_target) fait
      20 s de tir ; la recharge ne partait que sous 8 chargeurs (T.turret_ammo_low), en TOUT OU RIEN (le stock devait couvrir tout le groupe) ;
    * QG : 150 chargeurs pour 8 tourelles de 45 à 115 min, 120 à 140,2 min ; de 140,3 à 140,8 min, 7 tourelles du QG tombent, 5 à 0 chargeur,
      devant une vague d'un gros biter, 5 biters moyens, 4 cracheurs moyens (le chargeur de base fait 5 de dégâts par balle, le gros biter a
      8 de résistance fixe : environ 0,2 PV par balle, 200 chargeurs pour lui seul ; déduit des prototypes, aucun bonus de dégâts recherché) ;
    * réserve visée au coffre : max(60, menace / 40) chargeurs, 53 pour 44 tourelles à 105 min, 158 pour 40 à 117 min, alors que le coffre
      avait de 24 000 à 40 000 objets et 8 000 à 11 000 plaques de fer de 102 à 132 min.

  Règles (chacune a son lecteur nommé) :
    Mu.per_turret   chargeurs voulus par tourelle : la cible ordinaire, ou la cible RICHE quand le fer au coffre paie Mu.RICH_MARGIN fois le
                    surplus de toutes les tourelles de l'équipe (« une fois qu'une équipe roule sur l'or, elle peut se permettre d'investir une
                    partie de ses ressources dans la protection ») ; lu par script/team/team.lua (f.team.ammo_per_turret).
    Mu.group        une tourelle sous Mu.TOP_PCT % de sa cible est à RECHARGER AU PLEIN (avant : seulement sous le seuil bas) ; lu par
                    Outposts.turret_groups.
    Mu.due          le groupe mérite une tournée : une tourelle sous le seuil bas, ou au moins Mu.TRIP_MIN chargeurs à porter ; planificateur.
    Mu.take         chargeurs pris au coffre pour une tournée : tout le manque, sinon le stock s'il donne Mu.REFILL_MIN chargeurs par tourelle
                    à recharger (recharge PARTIELLE ; avant : tout ou rien hors péril) ; planificateur.
    Mu.stock_target stock visé au coffre : le manque des tourelles plus Mu.SPARE chargeurs par tourelle (au moins le plancher d'avant) ;
                    lu par shared/ai3/buts.lua (but « defense:munitions »).
  Déterminisme : entiers, aucun hasard, aucune horloge, aucun `pairs`.
]]

local Mu = {}

Mu.TOP_PCT = 75      -- % de la cible : en dessous, la tourelle est rechargée au plein. SUPPOSÉ (15 chargeurs sur 20 : 15 s de tir)
Mu.TRIP_MIN = 10     -- chargeurs à porter au moins pour une tournée sans tourelle sous le seuil bas (pas un aller-retour pour 3 chargeurs)
Mu.REFILL_MIN = 5    -- chargeurs par tourelle à recharger : en dessous, une recharge partielle ne part pas (comme Sq.REFILL_MIN)
Mu.SPARE = 10        -- chargeurs gardés au coffre par tourelle de l'équipe, en plus du manque (une demi-recharge chacune). SUPPOSÉ
Mu.RICH_MARGIN = 1   -- l'équipe est riche quand son fer paie 1 fois le surplus de chargeurs de toutes ses tourelles. SUPPOSÉ

local function num(x)
  if type(x) ~= "number" or x ~= x or x < 0 then return 0 end
  return x
end

local function ceil(x) return math.ceil(x - 1e-9) end

--- Chargeurs voulus par tourelle. a = { base (cible ordinaire), rich (cible riche), turrets (tourelles de l'équipe), iron (fer au coffre),
--- mag_iron (fer d'un chargeur) }. Rend `rich` si le fer paie Mu.RICH_MARGIN × turrets × (rich - base) chargeurs, sinon `base`.
function Mu.per_turret(a)
  a = a or {}
  local base, rich = num(a.base), num(a.rich)
  local turrets, iron, mag_iron = num(a.turrets), num(a.iron), num(a.mag_iron)
  if rich <= base or turrets <= 0 or mag_iron <= 0 then return base end
  if iron >= Mu.RICH_MARGIN * turrets * (rich - base) * mag_iron then return rich end
  return base
end

--- Seuil de recharge d'une tourelle (chargeurs) pour une cible donnée.
function Mu.top(target)
  return ceil(num(target) * Mu.TOP_PCT / 100)
end

--- État d'un groupe de tourelles. have = { chargeurs de chaque tourelle }, target = chargeurs voulus par tourelle, low = seuil bas.
--- Rend { short (tourelles sous Mu.top(target)), missing (chargeurs pour les remettre à la cible), low (tourelles sous le seuil bas) }.
function Mu.group(have, target, low)
  target, low = num(target), num(low)
  local top = Mu.top(target)
  local out = { short = 0, missing = 0, low = 0 }
  for _, h in ipairs(have or {}) do
    h = num(h)
    if h < low then out.low = out.low + 1 end
    if h < top then
      out.short = out.short + 1
      out.missing = out.missing + (target - h)
    end
  end
  return out
end

--- Le groupe mérite-t-il une tournée de recharge ? g = { short, missing, low }.
function Mu.due(g)
  g = g or {}
  if num(g.short) <= 0 or num(g.missing) <= 0 then return false end
  return num(g.low) > 0 or num(g.missing) >= Mu.TRIP_MIN
end

--- Chargeurs à prendre au coffre pour recharger un groupe : tout le manque si le stock le couvre ; sinon tout le stock s'il donne au moins
--- Mu.REFILL_MIN chargeurs à chaque tourelle à recharger ; sinon 0 (le manque est à fabriquer).
function Mu.take(missing, short, stock)
  missing, short, stock = num(missing), num(short), num(stock)
  if missing <= 0 or short <= 0 then return 0 end
  if stock >= missing then return missing end
  if stock >= short * Mu.REFILL_MIN then return stock end
  return 0
end

--- Stock de chargeurs visé au coffre. a = { turrets (tourelles de l'équipe), missing (chargeurs qui manquent dans les tourelles),
--- floor (stock visé d'avant : réserve fixe, réserve sur la menace) }.
function Mu.stock_target(a)
  a = a or {}
  local t = num(a.missing) + num(a.turrets) * Mu.SPARE
  local floor = num(a.floor)
  return t > floor and t or floor
end

return Mu
