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
      avait de 24 000 à 40 000 objets et 8 000 à 11 000 plaques de fer de 102 à 132 min ;
    * la recherche des balles perforantes est faite à 116 min et ne sert à rien : la tourelle ne reçoit que le chargeur de base.
  Essai 1 du lot (verif-guide 271828182, fo-logs/2026-11-03_MUNITIONS/guide-271828182) : la cible riche BASCULAIT avec le fer (20 <-> 50), le stock
  visé suivait le manque à la cible riche, et 988 chargeurs dormaient au coffre à 55 min pendant que les recrues manquaient de fer (14 PNJ
  contre 23). D'où l'hystérésis, la réserve comptée sur la cible ORDINAIRE avec un plafond, et le surplus riche servi APRÈS les recrues.

  Règles (chacune a son lecteur nommé) :
    Mu.per_turret   chargeurs voulus par tourelle : l'ordinaire, ou la cible RICHE (« une fois qu'une équipe roule sur l'or, elle peut se
                    permettre d'investir une partie de ses ressources dans la protection »), avec HYSTÉRÉSIS : entrée quand le fer paie
                    Mu.RICH_ENTER_PCT % du surplus de toutes les tourelles, sortie sous Mu.RICH_EXIT_PCT % ; lu par script/team/team.lua.
    Mu.group        une tourelle sous Mu.TOP_PCT % de sa cible est à RECHARGER AU PLEIN ; manque à la cible, et part URGENTE (jusqu'à la cible
                    ordinaire) ; lu par Outposts.turret_groups.
    Mu.due          le groupe mérite une tournée : une tourelle sous le seuil bas, ou au moins Mu.TRIP_MIN chargeurs à porter ; planificateur.
    Mu.take         chargeurs pris au coffre pour une tournée : tout le manque, sinon le stock s'il donne Mu.REFILL_MIN chargeurs par tourelle
                    à recharger (recharge PARTIELLE) ; planificateur (part urgente avant les recrues, surplus riche après).
    Mu.stock_target stock visé au coffre : le manque URGENT plus Mu.SPARE par tourelle, au plus Mu.CAP_PCT % d'une charge ordinaire par
                    tourelle, au moins le plancher d'avant ; lu par shared/ai3/buts.lua (but « defense:munitions »).
    Mu.best_ammo    la meilleure munition FABRICABLE (ou au coffre) parmi une échelle croissante, collante tant qu'elle reste fabricable ou
                    au coffre ; lu par script/team/team.lua (f.team.ammo_item).
  Déterminisme : entiers, aucun hasard, aucune horloge, aucun `pairs`.
]]

local Mu = {}

Mu.TOP_PCT = 75         -- % de la cible : en dessous, la tourelle est rechargée au plein. SUPPOSÉ (15 chargeurs sur 20 : 15 s de tir)
Mu.TRIP_MIN = 10        -- chargeurs à porter au moins pour une tournée sans tourelle sous le seuil bas (pas un aller-retour pour 3 chargeurs)
Mu.REFILL_MIN = 5       -- chargeurs par tourelle à recharger : en dessous, une recharge partielle ne part pas (comme Sq.REFILL_MIN)
Mu.SPARE = 10           -- chargeurs gardés au coffre par tourelle de l'équipe, en plus du manque urgent (une demi-recharge chacune). SUPPOSÉ
Mu.CAP_PCT = 100        -- plafond du stock visé : 100 % d'une charge ORDINAIRE par tourelle (essai 1 : 988 au coffre pour 29 tourelles)
Mu.RICH_ENTER_PCT = 200 -- entrée dans la cible riche : le fer paie 2 fois le surplus de toutes les tourelles. SUPPOSÉ
Mu.RICH_EXIT_PCT = 100  -- sortie : le fer ne paie plus 1 fois ce surplus (hystérésis : pas de bascule à chaque variation du fer)
Mu.SURPLUS_PRIO = 35    -- priorité de la fabrication du surplus riche : sous les recrues (55 à 89) et la recherche (40)
Mu.AMMO_SWITCH_MIN = 10 -- chargeurs d'une meilleure munition au coffre qui suffisent à la choisir sans pouvoir la fabriquer

local function num(x)
  if type(x) ~= "number" or x ~= x or x < 0 then return 0 end
  return x
end

local function ceil(x) return math.ceil(x - 1e-9) end

--- Chargeurs voulus par tourelle. a = { base (cible ordinaire), rich (cible riche), turrets (tourelles de l'équipe), iron (fer au coffre),
--- mag_iron (fer d'un chargeur), was (vrai : riche à la pensée d'avant) }. Rend la cible et `rich` (booléen, à garder pour la pensée suivante).
function Mu.per_turret(a)
  a = a or {}
  local base, rich = num(a.base), num(a.rich)
  local turrets, iron, mag_iron = num(a.turrets), num(a.iron), num(a.mag_iron)
  if rich <= base or turrets <= 0 or mag_iron <= 0 then return base, false end
  local cost = turrets * (rich - base) * mag_iron
  local pct = a.was and Mu.RICH_EXIT_PCT or Mu.RICH_ENTER_PCT
  if iron * 100 >= cost * pct then return rich, true end
  return base, false
end

--- Seuil de recharge d'une tourelle (chargeurs) pour une cible donnée.
function Mu.top(target)
  return ceil(num(target) * Mu.TOP_PCT / 100)
end

--- État d'un groupe de tourelles. have = { chargeurs de chaque tourelle }, target = chargeurs voulus par tourelle, low = seuil bas, base = cible
--- ordinaire (absente : `target`). Rend { short (tourelles sous Mu.top(target)), missing (chargeurs pour les remettre à la cible), low (sous le
--- seuil bas), missing_base (part URGENTE de missing : jusqu'à la cible ordinaire), short_base (tourelles à recharger sous la cible ordinaire) }.
function Mu.group(have, target, low, base)
  target, low = num(target), num(low)
  base = base == nil and target or math.min(num(base), target)
  local top = Mu.top(target)
  local out = { short = 0, missing = 0, low = 0, missing_base = 0, short_base = 0 }
  for _, h in ipairs(have or {}) do
    h = num(h)
    if h < low then out.low = out.low + 1 end
    if h < top then
      out.short = out.short + 1
      out.missing = out.missing + (target - h)
      if h < base then
        out.short_base = out.short_base + 1
        out.missing_base = out.missing_base + (base - h)
      end
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

--- Stock de chargeurs visé au coffre. a = { turrets (tourelles de l'équipe), missing (manque URGENT : jusqu'à la cible ordinaire), base (cible
--- ordinaire par tourelle), floor (stock visé d'avant : réserve fixe, réserve sur la menace) }. Le surplus de la cible riche n'y entre jamais.
function Mu.stock_target(a)
  a = a or {}
  local turrets = num(a.turrets)
  local t = num(a.missing) + turrets * Mu.SPARE
  local cap = math.floor(turrets * num(a.base) * Mu.CAP_PCT / 100)
  if a.base ~= nil and t > cap then t = cap end
  local floor = num(a.floor)
  return t > floor and t or floor
end

--- La munition à fabriquer et à porter. list = { { enabled (recette ouverte), makeable (fabricable depuis le coffre), stock (au coffre) }, ... }
--- dans l'ordre CROISSANT de qualité (l'indice 1 est la munition de base) ; current = indice choisi à la pensée d'avant. Rend l'indice choisi et
--- la raison. Une meilleure munition est prise si elle est ouverte et fabricable, ou au coffre (Mu.AMMO_SWITCH_MIN) ; la munition courante
--- est gardée tant qu'elle reste ouverte et fabricable ou au coffre (pas de va-et-vient à chaque variation du stock).
function Mu.best_ammo(list, current)
  list = list or {}
  for i = #list, 2, -1 do
    local c = list[i] or {}
    if c.enabled then
      if c.makeable then return i, "fabricable" end
      if num(c.stock) >= Mu.AMMO_SWITCH_MIN then return i, "au coffre" end
      if i == current and num(c.stock) > 0 then return i, "gardee (au coffre)" end
    end
  end
  return 1, "base"
end

return Mu
