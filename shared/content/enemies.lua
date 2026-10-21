--[[
  Déchiqueteurs : 8 paliers (1-4 vanilla, 5-8 mod) × 4 familles à mécaniques. Pur Lua.

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

E.TIERS = 8
E.VANILLA_TIERS = 4

E.tier_names = { "small", "medium", "big", "behemoth", "colossal", "titan", "apex", "primordial" }

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
}

-- Part des nids de famille face aux nids vanilla, loin du départ. Moteur réel (session 3) : sans facteur,
-- les nids de famille remplaçaient 100 % des nids à 1 800 tuiles (338 sur 338). Facteur appliqué à leur
-- probabilité d'apparition.
E.family_nest_share = 0.4

--- Résistance de famille à un palier : la part FIXE croît avec le palier (nulle aux paliers 1-2, pleine
--- au palier 8), la part en pourcentage atteint sa valeur au palier 4. Moteur réel (session 4, défense de
--- tours) : avec la part fixe pleine dès le palier 1, un petit blindé ignorait les chargeurs ordinaires
--- et perforants (8 dégâts - 12 fixes) et une vague 4 rasait une base de 12 tourelles sans recherche.
function E.family_resist(family, tier)
  local out = {}
  for dtype, v in pairs(family.resist) do
    out[dtype] = { v[1] * math.max(0, tier - 2) / 6, v[2] * math.min(1, tier / 4) }
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
  },
  pyro = {
    hp = 1.0, speed = 1.0, damage = 1.1,
    resist = { fire = { 0, 100 } },
    death_fire = true,
    tint1 = { r = 0.55, g = 0.15, b = 0.05 }, tint2 = { r = 1.00, g = 0.60, b = 0.10 },
    glow = { r = 1.00, g = 0.42, b = 0.05 }, -- braises
    nest_distance = 5,
  },
  brood = {
    hp = 0.8, speed = 1.05, damage = 0.9,
    resist = { poison = { 0, 60 } },
    brood = 2,
    tint1 = { r = 0.30, g = 0.10, b = 0.35 }, tint2 = { r = 0.75, g = 0.45, b = 0.90 },
    glow = { r = 0.80, g = 0.25, b = 1.00 }, -- poches d'œufs
    nest_distance = 6,
  },
  storm = {
    hp = 1.0, speed = 1.2, damage = 1.0,
    resist = { electric = { 5, 60 }, laser = { 5, 60 } },
    damage_type = "electric",
    tint1 = { r = 0.05, g = 0.30, b = 0.40 }, tint2 = { r = 0.40, g = 0.95, b = 1.00 },
    glow = { r = 0.25, g = 0.85, b = 1.00 }, -- arcs électriques
    nest_distance = 8,
  },
}
E.FAMILY_ORDER = { "armored", "pyro", "brood", "storm" }

-- Nouvelles courbes d'apparition (évolution -> poids), 8 paliers répartis sur [0, 1].
E.spawn_curves = {
  { { 0.00, 0.30 }, { 0.35, 0.00 } },
  { { 0.10, 0.00 }, { 0.35, 0.30 }, { 0.50, 0.05 }, { 0.60, 0.00 } },
  { { 0.30, 0.00 }, { 0.50, 0.30 }, { 0.65, 0.05 }, { 0.75, 0.00 } },
  { { 0.45, 0.00 }, { 0.62, 0.30 }, { 0.78, 0.05 }, { 0.88, 0.00 } },
  { { 0.58, 0.00 }, { 0.75, 0.30 }, { 0.90, 0.05 }, { 1.00, 0.02 } },
  { { 0.70, 0.00 }, { 0.85, 0.30 }, { 1.00, 0.10 } },
  { { 0.80, 0.00 }, { 0.95, 0.25 }, { 1.00, 0.25 } },
  { { 0.90, 0.00 }, { 1.00, 0.20 } },
}

-- Vers : paliers 5-8 (multiplicateurs relatifs au ver géant vanilla), exigence d'évolution pour l'expansion.
E.worm_tiers = {
  [5] = { scale = 1.15, hp = 4, damage = 2, range = 4, evo = 0.93, autoplace_distance = 10 },
  [6] = { scale = 1.30, hp = 10, damage = 4, range = 8, evo = 0.96, autoplace_distance = 12 },
  [7] = { scale = 1.45, hp = 25, damage = 7, range = 12, evo = 0.98, autoplace_distance = 14 },
  [8] = { scale = 1.60, hp = 60, damage = 12, range = 16, evo = 0.995, autoplace_distance = 16 },
}

function E.unit_name(kind, tier, family)
  local tn = E.tier_names[tier]
  if family then return "fo-" .. family .. "-" .. tn .. "-" .. kind end
  if tier <= E.VANILLA_TIERS then return tn .. "-" .. kind end
  return "fo-" .. tn .. "-" .. kind
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
  end
  return s
end

return E
