--[[
  IA3 (conception) : test hors jeu du PROTOTYPE d'évaluation des expéditions (shared/ai3/expedition.lua, NON BRANCHÉ).
  docs/IA3_CERVEAU.md §4.2, §4.3, §7.

  Ce qu'il prouve : risque monotone (plus de nids, plus loin, plus de pertes, moins vu : jamais moins risqué), plafonné ;
  bandes léger / équipé / escorté / attendre ; le caractère (prudence, agressivité) déplace les seuils et le choix ;
  « préparer » quand l'équipement n'est pas payable ; équipement tiré du catalogue (meilleure tourelle payable,
  munition de SA catégorie) ; l'exemple du pétrole du §4.5 ; aucun nom d'objet dans le module ; déterminisme.

  Usage : lua5.2 tests/ai3_expedition_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local E = require("shared.ai3.expedition")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[AI3-EXPEDITION] ECHEC : " .. msg) end
end

-- Catalogue de test (en jeu : prototypes des tourelles, munitions et capsules, « payable » par le dépliage, §3.2).
local catalog = {
  turrets = { { name = "gun-turret", power = 100, ammo_category = "bullet", payable = true },
              { name = "laser-turret", power = 300, ammo_category = nil, payable = false } },
  ammo = { { name = "firearm-magazine", power = 5, category = "bullet", payable = true },
           { name = "piercing-rounds-magazine", power = 8, category = "bullet", payable = true },
           { name = "shotgun-shell", power = 6, category = "shotgun-shell", payable = true } },
  grenades = { { name = "grenade", power = 35, payable = true } },
}

local calm = { spawners = 0, worms = 0, path_nests = 0, seen_pct = 100, losses = 0, enemy_zone = false, distance = 80 }

-- Monotonie (1 000 couples tirés de façon déterministe : on augmente un facteur, le risque ne baisse jamais).
do
  local s, bad = 7, 0
  local function rnd(n) s = (s * 16807) % 2147483647; return s % n end
  local keys = { "spawners", "worms", "path_nests", "losses", "distance" }
  for _ = 1, 1000 do
    local site = { spawners = rnd(4), worms = rnd(6), path_nests = rnd(3), seen_pct = rnd(101), losses = rnd(3),
      enemy_zone = rnd(4) == 0, distance = rnd(800) }
    local r0 = E.risk(site)
    local k = keys[rnd(#keys) + 1]
    local s2 = {}
    for a, b in pairs(site) do s2[a] = b end
    s2[k] = s2[k] + (k == "distance" and 100 or 1)
    if E.risk(s2) < r0 then bad = bad + 1 end
    s2 = {}
    for a, b in pairs(site) do s2[a] = b end
    s2.seen_pct = math.max(0, site.seen_pct - 30)
    if E.risk(s2) < r0 then bad = bad + 1 end
    if r0 > E.CAP then bad = bad + 1 end
  end
  check(bad == 0, "risque monotone et plafonné (" .. bad .. " écart(s))")
end

-- Bandes.
do
  local d = E.decide(calm, 500, {}, { catalog = catalog, soldiers = 0, crew = 2 })
  check(d.action == "leger", "site calme, vu, proche : léger (" .. tostring(d.action) .. ", risque " .. d.risk .. ")")
  local mid = { spawners = 1, worms = 1, path_nests = 0, seen_pct = 80, losses = 0, distance = 250 }
  d = E.decide(mid, 500, {}, { catalog = catalog, soldiers = 0, crew = 2 })
  check(d.action == "equipe", "un nid, un ver, 250 tuiles : équipé (" .. tostring(d.action) .. ", risque " .. d.risk .. ")")
  local turret, ammo = false, false
  for _, it in ipairs(d.items or {}) do
    if it[1] == "gun-turret" and it[2] == 2 then turret = true end
    if it[1] == "piercing-rounds-magazine" and it[2] == 40 then ammo = true end
  end
  check(turret and ammo, "équipé : 2 tourelles payables et 40 munitions de LEUR catégorie (la meilleure)")
end

-- L'exemple du pétrole (§4.5) : 2 nids, 3 vers à 50 tuiles, 380 tuiles, secteurs autour vus à 60 %.
local oil = { spawners = 2, worms = 3, path_nests = 1, seen_pct = 60, losses = 0, distance = 380 }
do
  local d = E.decide(oil, 2000, { prudence = 500, aggression = 500 }, { catalog = catalog, soldiers = 3, crew = 3 })
  check(d.band == "escorte", "pétrole : bande escortée (risque " .. d.risk .. ")")
  check(d.action == "preparer", "pétrole : 3 soldats pour 8 voulus : préparer d'abord (" .. tostring(d.action) .. ")")
  d = E.decide(oil, 2000, { prudence = 500, aggression = 500 }, { catalog = catalog, soldiers = 10, crew = 3 })
  check(d.action == "escorte" and d.escort == 8, "pétrole : 10 soldats disponibles : départ escorté de 8")
  print(string.format("[AI3-EXPEDITION] pétrole : risque %d (nids %d, chemin %d, inconnu %d, distance %d), perte attendue %d MU, action %s",
    d.risk, d.parts.nids, d.parts.chemin, d.parts.inconnu, d.parts.distance, d.expected_loss, d.action))
end

-- Le caractère.
do
  local site = { spawners = 1, worms = 2, path_nests = 1, seen_pct = 70, losses = 0, distance = 300 }
  local bold = E.decide(site, 2000, { prudence = 200 }, { catalog = catalog, soldiers = 20, crew = 2 })
  local prudent = E.decide(site, 2000, { prudence = 800 }, { catalog = catalog, soldiers = 20, crew = 2 })
  local order = { leger = 1, equipe = 2, escorte = 3, attendre = 4, nettoyer = 4 }
  check(order[prudent.action] > order[bold.action], "même site : le prudent s'équipe davantage que l'audacieux ("
    .. prudent.action .. " contre " .. bold.action .. ")")
  local hell = { spawners = 6, worms = 6, path_nests = 3, seen_pct = 40, losses = 2, distance = 500 }
  local a = E.decide(hell, 2000, { aggression = 800 }, { catalog = catalog, soldiers = 40, crew = 2 })
  local b = E.decide(hell, 2000, { aggression = 200 }, { catalog = catalog, soldiers = 40, crew = 2 })
  check(a.action == "nettoyer" and b.action == "attendre", "site infesté : l'agressif nettoie (" .. a.action
    .. "), le pacifique attend (" .. b.action .. ")")
  local poor = E.decide(hell, 2000, { aggression = 800 }, { catalog = catalog, soldiers = 5, crew = 2 })
  check(poor.action == "attendre", "site infesté, armée trop petite : attendre même agressif")
end

-- Perte attendue supérieure à la moitié de la valeur : attendre.
do
  local d = E.decide({ spawners = 2, worms = 1, seen_pct = 60, distance = 300 }, 50, {}, { catalog = catalog, soldiers = 20, crew = 3 })
  check(d.action == "attendre", "valeur faible (50 MU) contre perte attendue " .. d.expected_loss .. " : attendre")
end

-- Équipement impayable : préparer.
do
  local nocat = { turrets = { { name = "gun-turret", power = 100, ammo_category = "bullet", payable = false } }, ammo = {}, grenades = {} }
  local d = E.decide({ spawners = 1, worms = 1, seen_pct = 80, distance = 250 }, 500, {}, { catalog = nocat, soldiers = 0, crew = 2 })
  check(d.action == "preparer" and d.missing and d.missing[1] == "tourelle", "tourelle non payable : préparer (fabriquer) d'abord")
end

-- Inconnu autour du site : plus risqué qu'un site vu.
do
  local seen = { spawners = 0, worms = 0, seen_pct = 100, distance = 200 }
  local unseen = { spawners = 0, worms = 0, seen_pct = 0, distance = 200 }
  check(E.risk(unseen) - E.risk(seen) == E.W.unknown, "secteurs non vus : + 200 de risque (prudence face à l'inconnu)")
end

-- Généricité : aucun nom d'objet du catalogue dans le module.
do
  local f = assert(io.open("shared/ai3/expedition.lua", "rb"))
  local src = f:read("*a")
  f:close()
  local hits = {}
  for _, group in pairs(catalog) do
    for _, e in ipairs(group) do if src:find('"' .. e.name .. '"', 1, true) then hits[#hits + 1] = e.name end end
  end
  check(#hits == 0, "généricité : noms d'objets dans le module : " .. table.concat(hits, ", "))
end

-- Déterminisme.
do
  local a = E.decide(oil, 2000, { prudence = 600 }, { catalog = catalog, soldiers = 12, crew = 3 })
  local b = E.decide(oil, 2000, { prudence = 600 }, { catalog = catalog, soldiers = 12, crew = 3 })
  check(a.action == b.action and a.risk == b.risk and a.expected_loss == b.expected_loss, "déterminisme")
end

-- Lot IA3-0 (revue M4) : la distance seule ne fait plus attendre ; l'attente a une sortie.
do
  local far = { spawners = 0, worms = 0, path_nests = 0, seen_pct = 60, losses = 0, distance = 1000 }
  local r = E.risk(far)
  local d = E.decide(far, 5000, { prudence = 800 }, { catalog = catalog, soldiers = 10, crew = 3 })
  check(r == 280 and d.action ~= "attendre",
    string.format("pétrole à 1 000 tuiles, rien de vu autour, prudent : risque %d (580 sans plafond), action %s (pas « attendre »)", r, tostring(d.action)))
  local nest = { spawners = 6, worms = 6, path_nests = 1, seen_pct = 70, losses = 0, distance = 400, blocks_age = true }
  local w0 = E.decide(nest, 3000, { prudence = 500, aggression = 200 }, { catalog = catalog, soldiers = 3, crew = 3 })
  nest.waits = 2
  local w2 = E.decide(nest, 3000, { prudence = 500, aggression = 200 }, { catalog = catalog, soldiers = 3, crew = 3 })
  check(w0.action == "attendre" and w2.escalated and w2.action == "preparer" and w2.escort == 2 * 12 + 5,
    string.format("site infesté, seule ressource de l'âge suivant : attendre, puis après 2 attentes escalade (%s, escorte %s)",
      tostring(w2.action), tostring(w2.escort)))
  local w3 = E.decide(nest, 3000, { prudence = 500, aggression = 200 }, { catalog = catalog, soldiers = 40, crew = 3 })
  check(w3.escalated and w3.action == "escorte", "escalade avec l'armée suffisante : départ escorté (" .. tostring(w3.action) .. ")")
  nest.blocks_age = false
  local w4 = E.decide(nest, 3000, { prudence = 500, aggression = 200 }, { catalog = catalog, soldiers = 40, crew = 3 })
  check(w4.action == "attendre", "sans blocage d'âge, un site infesté reste « attendre » (chercher un autre site)")
end

print(string.format("[AI3-EXPEDITION] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
