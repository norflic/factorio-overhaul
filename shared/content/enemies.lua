--[[
  Déchiqueteurs : 12 paliers (1-4 vanilla, 5-12 mod) × 6 familles à mécaniques. Pur Lua.

  Contrainte moteur : l'évolution est plafonnée à 1.0. On REDISTRIBUE donc les 8 paliers sur [0, 1]
  (vanilla en concentre 4) : le palier 8 n'apparaît qu'en fin d'évolution.

  Familles (nids dédiés, plus éloignés du départ) — chacune casse une stratégie de défense différente :
  - Blindée    : PV ×1.5, très résistante au physique et aux explosions, lente.  → contre : laser/feu.
  - Ignée      : immunisée au feu, embrase le sol à sa mort.                   → contre : balles/laser.
  - Couvée     : PV ×0.8, libère 2 unités du palier inférieur à sa mort (runtime). → contre : zone.
  - Foudroyante: rapide, résiste à l'électricité/laser, ses morsures sont ÉLECTRIQUES
                 (les murs vanilla n'ont aucune résistance électrique).          → contre : balles.
]]

local E = {}

E.TIERS = 12          -- lot EQUILIBRE (31/10) : 12 paliers (8 avant) ; le mode défense de tours reste à 8 (E.TD_TIERS)
E.TD_TIERS = 8
E.VANILLA_TIERS = 4

E.tier_names = { "small", "medium", "big", "behemoth", "colossal", "titan", "apex", "primordial",
  "ancestral", "abyssal", "cataclysmic", "eternal" }

-- Paliers 5-8 : multiplicateurs relatifs au palier 4 (behemoth) vanilla.
E.new_tiers = {
  [5] = { scale = 1.45, hp = 3, damage = 2, speed = 0.97, resist = 8, poll = 2.5,
          tint1 = { r = 0.40, g = 0.10, b = 0.12 }, tint2 = { r = 1.00, g = 0.45, b = 0.20 } },
  [6] = { scale = 1.70, hp = 8, damage = 4, speed = 0.94, resist = 16, poll = 6,
          tint1 = { r = 0.10, g = 0.18, b = 0.40 }, tint2 = { r = 0.35, g = 0.80, b = 1.00 } },
  [7] = { scale = 1.95, hp = 20, damage = 7, speed = 0.90, resist = 24, poll = 15,
          tint1 = { r = 0.25, g = 0.08, b = 0.35 }, tint2 = { r = 0.95, g = 0.30, b = 1.00 } },
  [8] = { scale = 2.20, hp = 50, damage = 12, speed = 0.87, resist = 32, poll = 40,
          tint1 = { r = 0.05, g = 0.05, b = 0.05 }, tint2 = { r = 1.00, g = 0.85, b = 0.20 } },
  -- Paliers 9-12 (lot EQUILIBRE) : suite de la courbe (PV ×2,2 environ par palier, dégâts × 1,65, 2,35 de plus en
  -- résistance par palier ; échelle 0,25 de plus). Teintes : os, abysses, braise blanche, vide.
  [9]  = { scale = 2.45, hp = 110, damage = 20, speed = 0.85, resist = 40, poll = 90,
           tint1 = { r = 0.35, g = 0.30, b = 0.22 }, tint2 = { r = 0.95, g = 0.92, b = 0.78 } },
  [10] = { scale = 2.70, hp = 240, damage = 34, speed = 0.83, resist = 48, poll = 200,
           tint1 = { r = 0.02, g = 0.12, b = 0.20 }, tint2 = { r = 0.10, g = 0.95, b = 0.80 } },
  [11] = { scale = 2.95, hp = 520, damage = 56, speed = 0.81, resist = 56, poll = 450,
           tint1 = { r = 0.45, g = 0.10, b = 0.02 }, tint2 = { r = 1.00, g = 0.97, b = 0.85 } },
  [12] = { scale = 3.20, hp = 1100, damage = 90, speed = 0.79, resist = 64, poll = 1000,
           tint1 = { r = 0.02, g = 0.00, b = 0.06 }, tint2 = { r = 0.80, g = 0.55, b = 1.00 } },
}

-- Part des nids de famille face aux nids vanilla, loin du départ. Moteur réel (session 3) : sans facteur,
-- les nids de famille remplaçaient 100 % des nids à 1 800 tuiles (338 sur 338). Facteur appliqué à leur
-- probabilité d'apparition.
-- Lot EQUILIBRE : 6 familles au lieu de 4 ; 0,27 × 6 = 1,62 (0,4 × 4 = 1,6) garde la même part totale de nids de famille.
E.family_nest_share = 0.27

--- Résistance de famille à un palier : la part FIXE croît avec le palier (nulle aux paliers 1-2, pleine
--- au palier 8), la part en pourcentage atteint sa valeur au palier 4. Moteur réel (session 4, défense de
--- tours) : avec la part fixe pleine dès le palier 1, un petit blindé ignorait les chargeurs ordinaires
--- et perforants (8 dégâts - 12 fixes) et une vague 4 rasait une base de 12 tourelles sans recherche.
function E.family_resist(family, tier)
  local out = {}
  for dtype, v in pairs(family.resist) do
    out[dtype] = { v[1] * math.min(1, math.max(0, tier - 2) / 6), v[2] * math.min(1, tier / 4) }  -- plafonnée au palier 8 (lot EQUILIBRE : 12 paliers)
  end
  return out
end

E.families = {
  armored = {
    hp = 1.5, speed = 0.8, damage = 1.0,
    -- Moteur réel (session 3, banc de contenu) : à +40 % physique, la mitrailleuse perforante restait
    -- meilleure que le laser contre les blindés ; à +60 %, le laser (leur contre désigné) passe devant et
    -- le tungstène reste la réponse balistique.
    resist = { physical = { 12, 60 }, explosion = { 10, 30 }, impact = { 0, 50 } },
    tint1 = { r = 0.42, g = 0.45, b = 0.50 }, tint2 = { r = 0.80, g = 0.83, b = 0.88 },
    glow = { r = 0.70, g = 0.82, b = 1.00 }, -- reflets d'acier froid
    nest_distance = 4,
    size = 1.15,                                  -- cuirassé : bas et large
  },
  pyro = {
    hp = 1.0, speed = 1.0, damage = 1.1,
    resist = { fire = { 0, 100 } },
    death_fire = true,
    tint1 = { r = 0.55, g = 0.15, b = 0.05 }, tint2 = { r = 1.00, g = 0.60, b = 0.10 },
    glow = { r = 1.00, g = 0.42, b = 0.05 }, -- braises
    nest_distance = 5,
    size = 1.0,                                   -- tison : la taille de référence
  },
  brood = {
    hp = 0.8, speed = 1.05, damage = 0.9,
    resist = { poison = { 0, 60 } },
    brood = 2,
    tint1 = { r = 0.30, g = 0.10, b = 0.35 }, tint2 = { r = 0.75, g = 0.45, b = 0.90 },
    glow = { r = 0.80, g = 0.25, b = 1.00 }, -- poches d'œufs
    nest_distance = 6,
    size = 1.1,                                   -- nourrice : abdomen gonflé
  },
  storm = {
    hp = 1.0, speed = 1.2, damage = 1.0,
    resist = { electric = { 5, 60 }, laser = { 5, 60 } },
    damage_type = "electric",
    tint1 = { r = 0.05, g = 0.30, b = 0.40 }, tint2 = { r = 0.40, g = 0.95, b = 1.00 },
    glow = { r = 0.25, g = 0.85, b = 1.00 }, -- arcs électriques
    nest_distance = 8,
    size = 0.9,                                   -- cornu : élancé
  },
  -- Lot EQUILIBRE : deux styles de plus. Toxique : immunisée à l'acide et au poison, mord à l'acide, lente et épaisse
  -- (contre : balles, laser). Essaim : fragile, très rapide, faible à l'explosion (contre : zone, tourelles à portée).
  toxic = {
    hp = 1.3, speed = 0.9, damage = 1.0,
    resist = { acid = { 0, 100 }, poison = { 0, 100 } },
    damage_type = "acid",
    tint1 = { r = 0.18, g = 0.40, b = 0.05 }, tint2 = { r = 0.60, g = 1.00, b = 0.15 },
    glow = { r = 0.55, g = 1.00, b = 0.10 }, -- bile
    nest_distance = 7,
    size = 1.25,                                  -- bilieux : tête large, le plus gros
    -- s43 : corps 3D propre (le CORRODER, graphics/robots/titans/sprites.lua, entrée « corroder ») au lieu du déchiqueteur recoloré ;
    -- variantes : teinte du corps et de la lueur qui glisse du premier au dernier palier (E.teinte_variante), les cracheurs vers l'ambre
    corps3d = "corroder",
    corps3d_cracheur = "corroder_cracheur",       -- cracheurs : poche dorsale et trompe de crachat, et leur propre cadavre
    -- échelle de l'image 3D relative à l'échelle vanilla : mesurée sur les feuilles (silhouette moyenne des 8 directions à 32 px/tuile :
    -- déchiqueteur vanilla 112 × 106 px par unité d'échelle, Corroder 96 × 79) : × 1,35 pour couvrir l'ancienne silhouette à tout palier
    corps3d_echelle = 1.35,
    variantes = {
      biter = { de = { r = 0.80, g = 1.00, b = 0.10 }, a = { r = 0.10, g = 1.00, b = 0.70 } },   -- bile -> vert acide -> turquoise toxique
      spitter = { de = { r = 1.00, g = 0.90, b = 0.15 }, a = { r = 1.00, g = 0.40, b = 0.05 } }, -- soufre -> ambre corrosif
    },
    part_corps = 0.35,                            -- part de la teinte dans la couche du corps (le reste : couleurs du rendu)
  },
  swarm = {
    hp = 0.55, speed = 1.35, damage = 0.85,
    resist = { explosion = { 0, -30 } },
    tint1 = { r = 0.40, g = 0.32, b = 0.05 }, tint2 = { r = 1.00, g = 0.88, b = 0.25 },
    glow = { r = 1.00, g = 0.80, b = 0.15 }, -- nuées
    nest_distance = 10,
    size = 0.6,                                   -- moucheron : nain
    biter_body = "spitter",                       -- son corps de déchiqueteur est celui du petit cracheur, nain (4 pattes)
    nest = { units = 2, cooldown_div = 2 },       -- nid d'essaim : deux fois plus d'unités, naissances deux fois plus rapprochées
  },
}
E.FAMILY_ORDER = { "armored", "pyro", "brood", "storm", "toxic", "swarm" }

-- Nouvelles courbes d'apparition (évolution -> poids), 12 paliers répartis sur [0, 1] (lot EQUILIBRE : paliers 1 à 4
-- inchangés, 5 à 8 un peu plus tôt (5 : 0,75 -> 0,70 ; 6 : 0,85 -> 0,78 ; 7 : 0,95 -> 0,84 ; 8 : 1,00 -> 0,89), 9 à 12 neufs).
E.spawn_curves = {
  { { 0.00, 0.30 }, { 0.35, 0.00 } },
  { { 0.10, 0.00 }, { 0.35, 0.30 }, { 0.50, 0.05 }, { 0.60, 0.00 } },
  { { 0.30, 0.00 }, { 0.50, 0.30 }, { 0.65, 0.05 }, { 0.75, 0.00 } },
  { { 0.45, 0.00 }, { 0.62, 0.30 }, { 0.78, 0.05 }, { 0.88, 0.00 } },
  { { 0.55, 0.00 }, { 0.70, 0.30 }, { 0.82, 0.05 }, { 0.92, 0.00 } },
  { { 0.62, 0.00 }, { 0.78, 0.30 }, { 0.88, 0.05 }, { 0.96, 0.00 } },
  { { 0.72, 0.00 }, { 0.84, 0.30 }, { 0.94, 0.10 }, { 1.00, 0.03 } },
  { { 0.78, 0.00 }, { 0.89, 0.28 }, { 1.00, 0.06 } },
  { { 0.82, 0.00 }, { 0.92, 0.26 }, { 1.00, 0.10 } },
  { { 0.86, 0.00 }, { 0.95, 0.25 }, { 1.00, 0.14 } },
  { { 0.90, 0.00 }, { 0.975, 0.25 }, { 1.00, 0.18 } },
  { { 0.93, 0.00 }, { 1.00, 0.25 } },
}

-- Vers : paliers 5-12 (multiplicateurs relatifs au ver géant vanilla), exigence d'évolution pour l'expansion.
E.worm_tiers = {
  [5] = { scale = 1.15, hp = 4, damage = 2, range = 4, evo = 0.93, autoplace_distance = 10 },
  [6] = { scale = 1.30, hp = 10, damage = 4, range = 8, evo = 0.96, autoplace_distance = 12 },
  [7] = { scale = 1.45, hp = 25, damage = 7, range = 12, evo = 0.98, autoplace_distance = 14 },
  [8] = { scale = 1.60, hp = 60, damage = 12, range = 16, evo = 0.995, autoplace_distance = 16 },
  [9] = { scale = 1.75, hp = 150, damage = 20, range = 19, evo = 0.997, autoplace_distance = 18 },
  [10] = { scale = 1.90, hp = 350, damage = 34, range = 22, evo = 0.998, autoplace_distance = 20 },
  [11] = { scale = 2.05, hp = 800, damage = 56, range = 25, evo = 0.999, autoplace_distance = 22 },
  [12] = { scale = 2.20, hp = 1800, damage = 90, range = 28, evo = 0.9995, autoplace_distance = 24 },
}

-- Lot BI-0 (31/10) : TAILLES. Une famille a une échelle `size` (k) qui multiplie l'image ET la boîte de ses unités à
-- tous les paliers (k = 1 pour un déchiqueteur sans famille). La boîte de collision ne dépasse jamais BOX_HALF_MAX
-- de demi-côté (le palier 12 d'un bilieux, k = 1,25, serait à ±0,95 : plafonné à ±0,9).
E.BOX_HALF_MAX = 0.9

--- Échelle de taille k d'une famille (1 sans famille).
function E.size(family)
  local f = family and E.families[family]
  return f and f.size or 1
end

--- s43 : teintes d'une variante d'une famille à corps 3D (corps3d) : lueur = couleur du palier, interpolée de `de` (palier 1) à `a`
--- (dernier palier) ; corps = blanc mêlé à la lueur à la part `part_corps`. Rend nil pour une famille sans variantes.
function E.teinte_variante(family, kind, tier)
  local f = family and E.families[family]
  local v = f and f.variantes and f.variantes[kind]
  if not v then return nil end
  local t = math.max(0, math.min(1, (tier - 1) / (E.TIERS - 1)))
  local lueur = {
    r = v.de.r + (v.a.r - v.de.r) * t, g = v.de.g + (v.a.g - v.de.g) * t, b = v.de.b + (v.a.b - v.de.b) * t,
  }
  local p = f.part_corps or 0
  local corps = { r = 1 - p + p * lueur.r, g = 1 - p + p * lueur.g, b = 1 - p + p * lueur.b }
  return lueur, corps
end

--- s43 : corps 3D d'une unité de famille (nil sans corps 3D) : feuille du corps (cracheurs : corps3d_cracheur s'il existe), feuille
--- du cadavre (celle du même corps : chaque corps a sa carcasse) et facteur d'échelle de l'image.
function E.corps3d(family, kind)
  local f = family and E.families[family]
  if not (f and f.corps3d) then return nil end
  local id = (kind == "spitter" and f.corps3d_cracheur) or f.corps3d
  return { id = id, cadavre = id, echelle = f.corps3d_echelle or 1 }
end

--- Le corps d'un déchiqueteur de cette famille est-il celui du petit cracheur (moucheron) ? Seuls les biters en changent.
function E.spitter_body(kind, family)
  local f = family and E.families[family]
  return kind == "biter" and f ~= nil and f.biter_body == "spitter"
end

--- Facteur à appliquer aux boîtes d'une unité. `scale` : échelle d'image au palier AVANT k ; `base_half` : demi-côté de la
--- boîte de collision du modèle vanilla. Paliers 1 à 4 : la boîte vanilla ; paliers 5 et plus : suit l'image, plafonnée
--- à 1,9 ; puis k de la famille ; enfin plafond absolu de BOX_HALF_MAX sur la collision.
function E.box_factor(scale, tier, family, base_half)
  local f = (tier > E.VANILLA_TIERS) and math.min(scale / 1.2, 1.9) or 1
  f = f * E.size(family)
  if base_half and base_half > 0 then f = math.min(f, E.BOX_HALF_MAX / base_half) end
  return f
end

--- Réglages d'un nid de famille à partir de ceux du nid vanilla : { max_count_of_owned_units, max_friends_around_to_spawn,
--- spawning_cooldown = { lent, rapide } }. Une famille sans `nest` rend les mêmes valeurs. La limite d'amis alentour
--- suit le plafond d'unités, sinon le nid d'essaim s'arrêterait de pondre à 5 voisins et le doublement ne servirait à rien.
function E.nest_stats(family, base)
  local f = family and E.families[family]
  local n = f and f.nest
  local cd = {}
  for i, v in ipairs(base.spawning_cooldown) do cd[i] = n and v / n.cooldown_div or v end
  return {
    max_count_of_owned_units = n and base.max_count_of_owned_units * n.units or base.max_count_of_owned_units,
    max_friends_around_to_spawn = n and base.max_friends_around_to_spawn * n.units or base.max_friends_around_to_spawn,
    spawning_cooldown = cd,
  }
end

function E.unit_name(kind, tier, family)
  local tn = E.tier_names[tier]
  if family then return "fo-" .. family .. "-" .. tn .. "-" .. kind end
  if tier <= E.VANILLA_TIERS then return tn .. "-" .. kind end
  return "fo-" .. tn .. "-" .. kind
end

-- Lot BI-V1 (1/11) : ÉCRASEUR, classe neuve (PLAN §5 ter), 4 tailles, rare, dans le nid de déchiqueteurs vanilla. PV et dégâts dérivés du
-- palier × hp_mult (72 k, 450 k, 2,16 M, 9,9 M) ; coup de zone de rayon `radius`. Boîte plafonnée à BOX_HALF_MAX : l'essai E2 (±1,4) n'est pas fait.
E.crusher = {
  tiers = { 6, 8, 10, 12 },
  scale = { [6] = 1.6, [8] = 2.2, [10] = 2.7, [12] = 3.2 },
  hp_mult = 3,
  base_hp = 3000,
  base_damage = 90,
  speed = 0.10,
  radius = 3,
  cooldown = 70,
  tint = { [8] = { r = 0.50, g = 0.36, b = 0.14 }, [10] = { r = 0.10, g = 0.42, b = 0.44 }, [12] = { r = 0.30, g = 0.16, b = 0.50 } },
  glow = { r = 1.00, g = 0.45, b = 0.20 },
  curves = {
    [6] = { { 0.78, 0.00 }, { 0.86, 0.03 }, { 1.00, 0.02 } },
    [8] = { { 0.89, 0.00 }, { 0.94, 0.03 }, { 1.00, 0.02 } },
    [10] = { { 0.95, 0.00 }, { 0.98, 0.02 }, { 1.00, 0.02 } },
    [12] = { { 0.98, 0.00 }, { 1.00, 0.02 } },
  },
}

function E.crusher_name(tier)
  return "fo-crusher-" .. E.tier_names[tier] .. "-biter"
end

--- PV et dégâts d'un écraseur.
function E.crusher_stats(tier)
  local nt, c = E.new_tiers[tier], E.crusher
  return { hp = c.base_hp * nt.hp * c.hp_mult, damage = c.base_damage * nt.damage, poll = nt.poll * c.hp_mult, resist = nt.resist }
end

function E.worm_name(tier)
  if tier <= E.VANILLA_TIERS then return E.tier_names[tier] .. "-worm-turret" end
  return "fo-" .. E.tier_names[tier] .. "-worm-turret"
end

function E.nest_name(family)
  return "fo-" .. family .. "-nest"
end

--- Unité générée lors de la mort d'une unité "couvée" (nil au palier 1).
function E.brood_child(kind, tier)
  if tier <= 1 then return nil end
  return E.unit_name(kind, tier - 1, "brood")
end

--- Statistiques cibles d'une unité (pour BALANCE_SHEET et le générateur).
function E.stats(base, tier, family)
  local s = { hp = base.hp, damage = base.damage, speed = base.speed, scale = base.scale, resist = 0 }
  local nt = E.new_tiers[tier]
  if nt then
    s.hp, s.damage, s.speed, s.scale, s.resist = base.hp * nt.hp, base.damage * nt.damage, base.speed * nt.speed, base.scale * nt.scale / 1.2, nt.resist
  end
  local f = family and E.families[family]
  if f then
    s.hp, s.damage, s.speed = s.hp * f.hp, s.damage * f.damage, s.speed * f.speed
    s.scale = s.scale * E.size(family)
  end
  return s
end

return E
