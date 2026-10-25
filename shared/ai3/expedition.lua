--[[
  IA3 « le cerveau des PNJ » : PROTOTYPE PUR (conception, NON BRANCHÉ) de l'ÉVALUATION D'UNE EXPÉDITION.
  docs/IA3_CERVEAU.md §4.2 et §4.3. Demande du DC (R-QCM-25g) : « pour aller chercher du pétrole les IA évaluent la
  sécurité d'abord, donc peut être s'équiper en grenade ou tourelle et munitions histoire de si ils sont attaqué ils
  peuvent les poser pour se défendre ».

  Le risque d'un site ne lit que ce que l'équipe SAIT (carte vue, IA2-c ; pertes passées, H11) :
    risque = 100 × nids vus + 40 × vers vus (64 tuiles autour du site)
           + 50 × nids vus près du chemin
           + 200 × part INCONNUE des secteurs autour du site (0 à 100 %)
           + 150 × pertes récentes sur place (décroissance appliquée par l'appelant)
           + 300 si le site est dans le territoire vu d'une faction ennemie
           + 50 par tranche de 100 tuiles de distance au QG (temps d'exposition)
    plafonné à 1 000 (pour mille).
  Décision (seuils × prudence du caractère, IA2-0 : 500 = neutre ; 800 = prudent, seuils − 30 % ; 200 = audacieux,
  seuils + 30 %) :
    < 150 léger (constructeurs seuls) ; < 400 équipé (tourelles, munitions, grenades portées) ;
    < 700 escorté (équipement + soldats devant) ; au-delà, ou perte attendue > moitié de la valeur : NETTOYER si le
    caractère est agressif et l'armée suffit, sinon ATTENDRE (et chercher un autre site).
    Un équipement voulu mais pas encore payable : PRÉPARER d'abord (comme un joueur qui fabrique ses tourelles avant
    de partir).
  Équipement tiré des DONNÉES (catalogue : tourelles, munitions, grenades payables, avec leur puissance) : aucun nom
  d'objet dans ce module.

  Entiers seulement (pour mille, MU) ; aucun hasard ; aucun pairs décisionnel.
]]

local E = {}

E.W = { spawner = 100, worm = 40, path_nest = 50, unknown = 200, loss = 150, enemy_zone = 300, per_100 = 50 }
E.CAP = 1000
E.BANDS = { { 150, "leger" }, { 400, "equipe" }, { 700, "escorte" } }
E.KIT = {
  leger = { turrets = 0, ammo_per_turret = 0, grenades = 0, escort = 0 },
  equipe = { turrets = 2, ammo_per_turret = 20, grenades = 5, escort = 0 },
  escorte = { turrets = 4, ammo_per_turret = 30, grenades = 10, escort = 8 },
}
E.AGGRESSIVE = 600       -- agressivité (pour mille) à partir de laquelle on nettoie plutôt qu'attendre
E.PNJ_VALUE = 60         -- MU d'un PNJ (équipement et recrue ; ordre de grandeur de O.recruit_cost)

--- site = { spawners, worms, path_nests, seen_pct (0..100), losses, enemy_zone (bool), distance (tuiles) }
function E.risk(site)
  local w = E.W
  local parts = {
    nids = w.spawner * (site.spawners or 0) + w.worm * (site.worms or 0),
    chemin = w.path_nest * (site.path_nests or 0),
    inconnu = math.floor(w.unknown * (100 - (site.seen_pct or 0)) / 100),
    pertes = w.loss * (site.losses or 0),
    ennemi = site.enemy_zone and w.enemy_zone or 0,
    distance = math.floor((site.distance or 0) / 100) * w.per_100,
  }
  local r = parts.nids + parts.chemin + parts.inconnu + parts.pertes + parts.ennemi + parts.distance
  if r > E.CAP then r = E.CAP end
  return r, parts
end

local function threshold(base, prudence)
  -- prudence 500 → × 1 ; 800 → × 0,7 ; 200 → × 1,3 (entiers).
  return math.floor(base * (1500 - (prudence or 500)) / 1000)
end

--- Meilleure entrée payable d'une liste du catalogue (puissance décroissante, puis nom).
local function best(list, filter)
  local b
  for _, e in ipairs(list or {}) do
    if e.payable and (not filter or filter(e)) then
      if not b or e.power > b.power or (e.power == b.power and e.name < b.name) then b = e end
    end
  end
  return b
end

--- Équipement d'une bande de risque, tiré du catalogue { turrets = {{name, power, ammo_category, payable}},
--- ammo = {{name, power, category, payable}}, grenades = {{name, power, payable}} }. Renvoie liste, manque.
function E.kit(band, catalog)
  local k = E.KIT[band]
  local items, missing = {}, {}
  if k.turrets > 0 then
    local t = best(catalog.turrets)
    if not t then
      missing[#missing + 1] = "tourelle"
    else
      items[#items + 1] = { t.name, k.turrets }
      local a = best(catalog.ammo, function(e) return e.category == t.ammo_category end)
      if a then items[#items + 1] = { a.name, k.turrets * k.ammo_per_turret } else missing[#missing + 1] = "munition" end
    end
  end
  if k.grenades > 0 then
    local g = best(catalog.grenades)
    if g then items[#items + 1] = { g.name, k.grenades } end -- les grenades aident, elles ne bloquent pas le départ
  end
  return items, missing, k.escort
end

--- Décision. value = MU des buts que le site débloque ; traits = { prudence, aggression } (pour mille) ;
--- means = { catalog, soldiers (disponibles), crew (PNJ du convoi) }.
function E.decide(site, value, traits, means)
  traits = traits or {}
  means = means or {}
  local r, parts = E.risk(site)
  local band
  for _, b in ipairs(E.BANDS) do
    if r < threshold(b[1], traits.prudence) then band = b[2] break end
  end
  local crew = means.crew or 2
  local kit_value = band and (E.KIT[band].turrets * 20 + E.KIT[band].escort * E.PNJ_VALUE) or 0
  local exposed = crew * E.PNJ_VALUE + kit_value
  local expected_loss = math.floor(r * exposed / 1000)
  local out = { risk = r, parts = parts, expected_loss = expected_loss, band = band }
  if not band or expected_loss * 2 > value then
    local need = 2 * ((site.spawners or 0) + (site.worms or 0)) + 5
    if (traits.aggression or 500) >= E.AGGRESSIVE and (means.soldiers or 0) >= need then
      out.action, out.escort = "nettoyer", need
    else
      out.action = "attendre"
    end
    return out
  end
  local items, missing, escort = E.kit(band, means.catalog or {})
  out.items, out.escort = items, escort
  if #missing > 0 or (escort > 0 and (means.soldiers or 0) < escort) then
    out.action = "preparer"
    out.missing = missing
  else
    out.action = band
  end
  return out
end

return E
