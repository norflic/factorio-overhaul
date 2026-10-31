--[[
  Lot CALCUL-V2 (30/10) : la RÈGLE PURE du centre de calcul MODULAIRE. Plan : <racine>/fo-logs/2026-10-30_CALCUL-V2/PLAN.md §2.

  DC (30/10 ~11 h) : « il va falloir en théorie beaucoup de machines et modules différents pour le concept de calcul » ;
  « modules » = les BAIES du centre (CPU, GPU, mémoire, stockage, refroidissement, réseau, quantique) ET une machine par
  étape. AUCUN module d'effet (vitesse, productivité) dans le calcul.

  Les baies sont des objets de type « module » (catégorie fo-baie) posés dans les emplacements de modules du centre (6 au
  centre, 12 au grand centre). Le script lit l'inventaire de modules du centre toutes les 60 ticks et appelle
  Cr.evaluate : le calcul, la puissance et la chaleur ne dépendent QUE des comptes de baies (ordre indifférent), de la
  recette de refroidissement en cours, de la part du temps où elle a tourné (r) et de la satisfaction électrique (e).

  Lua PUR (tests/compute_v2_test.lua) ; aucun appel au moteur.
]]

local Cr = {}

-- Baies : calcul (unités/s), puissance (kW), chaleur (kW thermiques), rôle.
Cr.RACKS = {
  { name = "fo-server-blade", kind = "cpu",     epoch = 10, compute = 100,  kw = 1000, heat = 1000 },
  { name = "fo-memory-rack",  kind = "memory",  epoch = 10, compute = 0,    kw = 300,  heat = 300 },
  { name = "fo-storage-rack", kind = "storage", epoch = 10, compute = 0,    kw = 300,  heat = 300 },
  { name = "fo-network-rack", kind = "network", epoch = 10, compute = 0,    kw = 200,  heat = 200 },
  { name = "fo-cooling-rack", kind = "cooling", epoch = 10, compute = 0,    kw = 150,  heat = 150 },
  { name = "fo-gpu-blade",    kind = "gpu",     epoch = 11, compute = 400,  kw = 2500, heat = 2500 },
  { name = "fo-quantum-rack", kind = "quantum", epoch = 13, compute = 2000, kw = 1500, heat = 500 },
}
Cr.BY_NAME, Cr.BY_KIND = {}, {}
for _, r in ipairs(Cr.RACKS) do Cr.BY_NAME[r.name] = r; Cr.BY_KIND[r.kind] = r end

-- Parts de mémoire : une baie de mémoire en OFFRE 4 ; un CPU en DEMANDE 1, un GPU 3.
Cr.MEM_OFFER, Cr.MEM_CPU, Cr.MEM_GPU = 4, 1, 3
-- Stockage : plafond interne du calcul ; réseau : export vers la force (unités/s).
Cr.STORAGE_BASE, Cr.STORAGE_PER = 200, 600
Cr.NETWORK_BASE, Cr.NETWORK_PER = 300, 1000
-- Refroidissement : passif du bâti, et kWth évacués par baie de refroidissement quand la recette tourne (× k du fluide).
Cr.COOLING_PER_RACK = 2000

-- Centres : puissance de base (kW), refroidissement passif (kWth), emplacements de baies.
Cr.CENTERS = {
  ["fo-data-center"]   = { base_kw = 300, passive = 1500, slots = 6 },
  ["fo-data-center-2"] = { base_kw = 600, passive = 3000, slots = 12 },
}

-- Recettes de refroidissement du centre : k (coefficient du fluide), dilution (permet les baies quantiques).
Cr.COOLING = {
  ["fo-dc-chilled-water"]   = { k = 1,   dilution = false },
  ["fo-dc-liquid-nitrogen"] = { k = 2.5, dilution = false },
  ["fo-dc-dilution"]        = { k = 1,   dilution = true },
}

--- Comptes des baies { cpu, memory, storage, network, cooling, gpu, quantum } depuis un contenu { [nom] = n }
--- (LuaInventory.get_contents). Tout autre objet est ignoré (le centre n'en accepte pas : allowed_effects).
function Cr.counts(contents)
  local c = {}
  for _, r in ipairs(Cr.RACKS) do c[r.kind] = 0 end
  for _, r in ipairs(Cr.RACKS) do
    local n = contents and contents[r.name]
    if n and n > 0 then c[r.kind] = c[r.kind] + n end
  end
  return c
end

--- Part du temps où la recette de refroidissement a tourné dans la fenêtre : Δavancement × durée / durée de la fenêtre,
--- bornée à [0, 1]. Δavancement en fabrications (products_finished + crafting_progress), time en s, ticks de fenêtre.
function Cr.share(dprogress, time, speed, ticks)
  if not dprogress or dprogress <= 0 or not time or time <= 0 or not ticks or ticks <= 0 then return 0 end
  local r = dprogress * time / ((speed or 1) * ticks / 60)
  if r > 1 then r = 1 end
  return r
end

--- La règle. c : comptes (Cr.counts) ; recipe : nom de la recette en cours (ou nil) ; r : part du temps où elle a tourné
--- (0 à 1) ; e : satisfaction électrique (0 à 1) ; center : nom du centre (passif, base).
--- Rend { compute, kw, heat, cooling, f_mem, f_heat, brut, cap, export, limit }.
---   f_mem   = min(1, 4·Mém / (CPU + 3·GPU))     (1 sans demande)
---   brut    = (100·CPU + 400·GPU)·f_mem + 2 000·min(Q, CPU)·[dilution]
---   K       = passif + r·Σrefroid·2 000·k        (sans recette de refroidissement : le passif seul)
---   f_heat  = min(1, K / Σchaleur)
---   calcul  = min(export_réseau, min(plafond_stockage, brut·f_heat·e))
---   kW      = base + Σ kW des baies
function Cr.evaluate(c, recipe, r, e, center)
  local cen = Cr.CENTERS[center or "fo-data-center"] or Cr.CENTERS["fo-data-center"]
  local cool = recipe and Cr.COOLING[recipe] or nil
  r = (cool and r and r > 0) and math.min(1, r) or 0
  e = e or 0
  if e < 0 then e = 0 elseif e > 1 then e = 1 end
  local kw, heat = cen.base_kw, 0
  for _, rk in ipairs(Cr.RACKS) do
    local n = c[rk.kind] or 0
    kw = kw + n * rk.kw
    heat = heat + n * rk.heat
  end
  local demand = Cr.MEM_CPU * c.cpu + Cr.MEM_GPU * c.gpu
  local f_mem = 1
  if demand > 0 then f_mem = math.min(1, Cr.MEM_OFFER * c.memory / demand) end
  local brut = (Cr.BY_KIND.cpu.compute * c.cpu + Cr.BY_KIND.gpu.compute * c.gpu) * f_mem
  if cool and cool.dilution then brut = brut + Cr.BY_KIND.quantum.compute * math.min(c.quantum, c.cpu) end
  local K = cen.passive + r * c.cooling * Cr.COOLING_PER_RACK * (cool and cool.k or 0)
  local f_heat = 1
  if heat > 0 then f_heat = math.min(1, K / heat) end
  local cap = Cr.STORAGE_BASE + Cr.STORAGE_PER * c.storage
  local export = Cr.NETWORK_BASE + Cr.NETWORK_PER * c.network
  local raw = brut * f_heat * e
  local compute = math.min(export, math.min(cap, raw))
  -- Facteur limitant (affichage) : le premier dans cet ordre qui retient le calcul.
  local limit = "none"
  if brut <= 0 then limit = (c.cpu + c.gpu + c.quantum == 0) and "no-rack" or "memory"
  elseif e < 1 - 1e-9 then limit = "power"
  elseif f_heat < 1 - 1e-9 then limit = "heat"
  elseif f_mem < 1 - 1e-9 then limit = "memory"
  elseif raw > cap + 1e-9 and cap <= export then limit = "storage"
  elseif raw > export + 1e-9 then limit = "network" end
  return { compute = compute, kw = kw, heat = heat, cooling = K, f_mem = f_mem, f_heat = f_heat, brut = brut, cap = cap,
           export = export, limit = limit }
end

-- Bonus de recherche (Q-CALC-2, PROVISOIRE) : recalé pour qu'un centre d'âge 10 à 6 places (280 unités/s : 3 CPU,
-- 1 mémoire, 1 refroidissement, 1 stockage) donne +28 % ; plafond +200 % (inchangé depuis la v1).
Cr.LAB_BONUS_PER_UNIT = 0.001
Cr.LAB_BONUS_CAP = 2.0

--- Bonus de recherche (fraction) pour un débit de calcul (unités/s), plafonné ; jamais négatif.
function Cr.lab_bonus(rate)
  if not rate or rate <= 0 then return 0 end
  return math.min(Cr.LAB_BONUS_CAP, rate * Cr.LAB_BONUS_PER_UNIT)
end

--- Satisfaction électrique lue sur le compagnon (interface électrique cachée) : énergie du tampon / taille du tampon,
--- bornée à [0, 1] ; 1 quand rien n'est demandé (aucune baie). Hypothèse H-CV2-4 (prouvée au banc calcul-modulaire).
function Cr.satisfaction(energy, buffer, usage)
  if not usage or usage <= 0 then return 1 end
  if not buffer or buffer <= 0 or not energy then return 0 end
  local e = energy / buffer
  if e < 0 then return 0 elseif e > 1 then return 1 end
  return e
end

return Cr
