--[[
  Effets ATTENDUS d'une machine équipée de n modules identiques, pour le banc de contenu (content_test.lua,
  verify_modules). Lua PUR : aucun appel au moteur ; testé hors jeu (tests/modules_migration_test.lua).

  Deux états d'une même machine, tous deux justes (lots MOD-1 et MOD-3, décisions D-15 et D-17) :
  - machine NON SUIVIE par le mod (posée par un script sans raise_built, modules versés par script, carte neuve) :
    aucune balise de complément, le moteur ADDITIONNE les effets des modules (F190) : somme des prototypes ;
  - machine SUIVIE (toute machine du joueur, et TOUTES les machines des surfaces après une migration :
    script/modules/mult.lua, Mult.migrate à on_configuration_changed) : la balise cachée porte le complément,
    vitesse, énergie et productivité se MULTIPLIENT (shared/content/module_mult.lua), la pollution reste additive.

  Lot MODULES-MIGRATION (30/10) : l'ancien contrôle supposait toujours la somme, donc une carte neuve ; rejoué après
  une migration (carte créée par la version précédente, banc en double source), il donnait 21 ECHEC sur des valeurs
  pourtant justes (vitesse de 4 « speed-module » : 1,2^4 − 1 = +1,07, et non +0,80). Le contrôle juge désormais
  chaque machine selon son état, et EXIGE l'état « suivie » quand une migration a eu lieu.
]]

local A = {}

A.TOLERANCE = 0.011
A.FLOOR = -0.8

--- Effets d'UN module de la famille `fam`, palier `k`, en centièmes entiers (arrondi au plus proche), d'après les
--- données du mod (shared/content/modules.lua, M.families) : { speed, consumption, productivity, pollution }.
function A.cents(M, fam, k)
  local out = {}
  local effects = M.families[fam].effects
  for _, key in ipairs({ "speed", "consumption", "productivity", "pollution" }) do
    local v = effects[key] and effects[key][k] or 0
    local x = v * 100
    out[key] = x >= 0 and math.floor(x + 0.5) or -math.floor(-x + 0.5)
  end
  return out
end

local function floor80(v) return math.max(v, A.FLOOR) end

--- Effets attendus (fractions, comme LuaEntity.speed_bonus…) de n modules identiques d'effets `c` (centièmes).
--- `multiplie` : machine suivie (balise de complément) ; exige MM (shared/content/module_mult.lua).
--- Renvoie { speed, prod, cons, poll } et le besoin d'une balise (bool).
function A.attendu(MM, c, n, multiplie)
  local function sum(key) return (c[key] or 0) * n / 100 end
  local want = {
    speed = floor80(sum("speed")),
    prod = math.max(0, sum("productivity")),
    cons = floor80(sum("consumption")),
    poll = floor80(sum("pollution")),
  }
  if not multiplie then return want, false end
  local mods = {}
  local one = { speed = c.speed or 0, consumption = c.consumption or 0, productivity = c.productivity or 0 }
  for i = 1, n do mods[i] = one end
  local comp = MM.complements(mods)
  want.speed = floor80((comp.speed.t - 100) / 100)
  want.cons = floor80((comp.consumption.t - 100) / 100)
  want.prod = math.max(0, (comp.productivity.t - 100) / 100)
  return want, MM.needs_beacon(comp)
end

--- Jugement d'une machine du banc.
---   etat = { migre = bool (une migration du mod a eu lieu : stats.migrated > 0), suivie = bool (machine suivie par
---            le mod), balises = nombre de balises cachées à son centre, ou nil si non compté }
---   got  = { speed, prod, cons, poll } lus sur la machine
--- Renvoie bon (bool), want, texte du mode.
function A.juger(MM, c, n, etat, got)
  local multiplie = (etat.suivie and MM ~= nil) and true or false
  local want, besoin = A.attendu(MM, c, n, multiplie)
  local bon = true
  local mode = multiplie and "produit (balise)" or "somme (moteur)"
  -- Après une migration, Mult.migrate recense TOUTES les machines des surfaces : une machine non suivie est un défaut.
  if etat.migre and not etat.suivie then
    bon = false
    mode = mode .. ", NON recensee par la migration"
  end
  if etat.balises ~= nil then
    local voulu = besoin and 1 or 0
    if etat.balises ~= voulu then bon = false end
    mode = mode .. string.format(", %d balise(s) (att. %d)", etat.balises, voulu)
  end
  for _, key in ipairs({ "speed", "prod", "cons", "poll" }) do
    if math.abs((got[key] or 0) - want[key]) > A.TOLERANCE then bon = false end
  end
  return bon, want, mode
end

return A
