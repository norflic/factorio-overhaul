--[[
  Effets de tir et lumières dynamiques des armes avancées (lot POLISSAGE-FX, 10/11, axe 3 du Mode Démon). PUR Lua : aucune
  lecture de data.raw, aucun require du jeu ; les prototypes (prototypes/effets_armes.lua) et le script des titans
  (script/robots/titans.lua) lisent ce module.

  Règle : UNE recette d'effets par MODE d'attaque (Fx.MODES : cinétique, laser, arc, plasma, rail, singularité, champ, orbital,
  titan), et la COULEUR vient toujours de la table de l'arme (spec.glow, sinon spec.tint, sinon spec.lueur pour un titan) : rien
  n'est écrit en dur ici ni dans les prototypes. Fx.pack(spec) = la recette du mode, la couleur de l'arme injectée partout.
  Fx.armes(A, T) : les armes avancées lues dans shared/content/arsenal.lua (lignée Bastion, armes de poing, frappe orbitale) et
  shared/robots/titans.lua (titans alliés). Le mode « cinetique » (âge 1, chargeurs) est DÉLÉGUÉ au lot TIRS (prototypes/tirs.lua
  habille déjà les tirs des tourelles à balles par âge) : son pack le dit (delegue = true) et aucun prototype n'est doublé.

  UPS : Fx.BORNES borne chaque effet (durée, nombre d'étincelles, taille et intensité des lumières, cadence des traînées) et
  Fx.verifier(pack) refuse un pack hors bornes : aucun effet par tick côté script, tout est porté par le moteur (explosions,
  particules, fumées, lumières de projectile). La seule chose animée par script est la PULSATION de la singularité de la
  Sentinelle : une table précalculée (Fx.pulsation, onde triangulaire, sans trigonométrie), lue tous les SCAN ticks.

  Feuilles procédurales (hors git, D-6 : tools/render/pieces/effets/vortex.py -> graphics/effets/) : VORTEX (8 images d'une
  spirale lumineuse) et ONDE (8 images d'un anneau de choc qui s'élargit), blanches : la teinte du prototype leur donne la
  couleur de l'arme.
]]

local Fx = {}

Fx.PREFIXE = "fo-fx-"
Fx.VORTEX = Fx.PREFIXE .. "vortex"   -- prototype « animation » (rendering.draw_animation : singularité de la Sentinelle)
Fx.ONDE = Fx.PREFIXE .. "onde"       -- idem, onde de choc
Fx.IMAGES = 8                        -- images par feuille (vortex, onde)
Fx.FEUILLE_PX = 128                  -- côté d'une image, résolution normale (hr : × 2)

-- Bornes UPS / lisibilité (une valeur hors borne = pack refusé par Fx.verifier)
Fx.BORNES = {
  duree_max = 60,            -- ticks d'une explosion d'impact ou de bouche
  fumee_duree_max = 90,      -- ticks de vie d'une bouffée de traînée
  etincelles_max = 12,       -- particules par impact
  lumiere_taille_max = 24,   -- tuiles (la frappe orbitale garde le flash vanilla, hors pack)
  lumiere_intensite_max = 1.0,
  trainee_frequence_min = 1, -- ticks entre deux bouffées (jamais plus d'une par tick)
  pulsation_min = 0.35,
  pulsation_max = 1.0,
  vortex_echelle_max = 24.0,  -- DIAMÈTRE en tuiles d'un vortex ou d'une onde (feuille de 4 tuiles à l'échelle 1)
  -- lot ART-IMPACTS (11/11) : marque au sol éphémère, faisceau dense, feuilles en grille
  brulure_tenue_max = 1800,  -- ticks avant que la brûlure au sol ne s'efface (30 s : éphémère)
  faisceau_epaisseur_min = 0.2,
  faisceau_epaisseur_max = 3.0,
  feuille_px_max = 2048,     -- côté d'une feuille (VRAM sobre)
  feuille_images_max = 64,
}
Fx.LUMIERE_SPRITE_TUILES = 300 / 32   -- diamètre (tuiles) du sprite utility/light_medium à l'échelle 1 (rendering.draw_light)
Fx.FEUILLE_TUILES = 4                -- côté (tuiles) d'une image de feuille à l'échelle 1 (128 px à 32 px/tuile)

-- Modes d'attaque connus : la liste de shared/content/arsenal.lua (A.MODES) plus ceux des armes de poing, du cataclysme et des titans.
Fx.MODES = {
  -- âge 1 : les tirs des tourelles à balles sont habillés par le lot TIRS (flamme de bouche orientée, dards, impacts par âge)
  cinetique = { delegue = "tirs" },
  -- âge 2 : faisceau focalisé : éclat d'impact au point de contact, étincelles fines, flash de bouche. Sources vanilla NEUTRES
  -- (explosion-hit : blanc-or) : une teinte MULTIPLIE (F36) ; laser-bubble, rouge, donnait du brun sous une teinte cyan (planche du 10/11).
  laser = {
    faisceau = { epaisseur = 0.9 },   -- ART-IMPACTS : corps DENSE (cœur blanc, gaine, filaments), éclat au contact
    bouche = { taille = 5, intensite = 0.55, duree = 6 },
    impact = { source = "explosion-hit", echelle = 0.9, duree = 20, lumiere = { taille = 6, intensite = 0.6, tenue = 0.35 },
      etincelles = { source = "spark-particle", nombre = 5, vitesse = 0.06, montee = 0.03 } },
  },
  -- âge 3 : arcs en chaîne : chaque maillon frappe avec une bulle électrique et des débris d'étincelles
  arc = {
    bouche = { taille = 6, intensite = 0.7, duree = 8 },
    impact = { source = "explosion-hit", echelle = 1.1, duree = 16, lumiere = { taille = 7, intensite = 0.7, tenue = 0.3 },
      etincelles = { source = "spark-particle-debris", nombre = 8, vitesse = 0.10, montee = 0.05 } },
  },
  -- âge 4 : orbe de plasma : vortex tournant en vol, traînée, lumière portée, explosion avec onde de choc
  plasma = {
    bouche = { taille = 8, intensite = 0.8, duree = 10 },
    projectile = { lumiere = { taille = 10, intensite = 0.9 }, vortex = { echelle = 1.6 },
      trainee = { source = "smoke-fast", frequence = 2, debut = 0.5, fin = 1.4, duree = 40, alpha = 0.55 } },
    impact = { source = "big-explosion", echelle = 1.4, duree = 40, lumiere = { taille = 16, intensite = 1.0, tenue = 0.25, onde = 0.4 },
      etincelles = { source = "spark-particle-debris", nombre = 12, vitesse = 0.14, montee = 0.06 },
      choc = { echelle = 9.0, duree = 40 }, brulure = { source = "medium-scorchmark-tintable", tenue = 900 } },
  },
  -- fusil à rail : la ligne est déjà un faisceau ; impact perforant à chaque cible, flash de bouche
  rail = {
    faisceau = { epaisseur = 0.7, duree = 10 },   -- ART-IMPACTS : la trace n'est plus l'arc électrique vanilla
    bouche = { taille = 7, intensite = 0.8, duree = 6 },
    impact = { source = "explosion-hit", echelle = 1.5, duree = 12, lumiere = { taille = 5, intensite = 0.6, tenue = 0.4 },
      etincelles = { source = "spark-particle", nombre = 8, vitesse = 0.12, montee = 0.04 },
      brulure = { source = "small-scorchmark-tintable", tenue = 600 } },
  },
  -- lanceur de singularités : roquette-vortex, champ dessiné par le vortex, onde à l'ouverture
  singularite = {
    projectile = { lumiere = { taille = 8, intensite = 0.7 }, vortex = { echelle = 1.2 },
      trainee = { source = "smoke-fast", frequence = 3, debut = 0.4, fin = 1.2, duree = 36, alpha = 0.5 } },
    champ = { vortex = { echelle = 11.0 } },
    impact = { source = "medium-explosion", echelle = 1.2, duree = 30, lumiere = { taille = 12, intensite = 0.8, tenue = 0.3, onde = 0.5 },
      etincelles = { source = "spark-particle-debris", nombre = 10, vitesse = 0.12, montee = 0.05 },
      choc = { echelle = 10.0, duree = 44 }, distorsion = { echelle = 7.0, duree = 54 },
      brulure = { source = "medium-scorchmark-tintable", tenue = 900 } },
  },
  -- projecteur de champ : onde de choc autour du porteur, bulle sur chaque ennemi repoussé
  champ = {
    impact = { source = "explosion-hit", echelle = 1.0, duree = 18, lumiere = { taille = 6, intensite = 0.6, tenue = 0.3 },
      etincelles = { source = "spark-particle", nombre = 6, vitesse = 0.08, montee = 0.04 }, onde = { echelle = 18.0, duree = 36 } },
  },
  -- frappe orbitale : le flash vanilla teinté reste ; onde de choc au sol en plus, drone de marquage lumineux
  orbital = {
    impact = { choc = { echelle = 22.0, duree = 60 }, lumiere = { taille = 24, intensite = 1.0, tenue = 0.2, onde = 0.3 },
      brulure = { source = "big-scorchmark-tintable", tenue = 1500 } },
  },
  -- titans alliés : singularité pulsée (Sentinelle), tirs des drones lumineux (Léviathan), éclairs des griffes (Juggernaut)
  titan = {
    projectile = { lumiere = { taille = 8, intensite = 0.7 },
      trainee = { source = "smoke-fast", frequence = 3, debut = 0.3, fin = 0.9, duree = 30, alpha = 0.45 } },
    impact = { choc = { echelle = 12.0, duree = 44 }, lumiere = { taille = 14, intensite = 0.8, tenue = 0.3, onde = 0.4 },
      distorsion = { echelle = 8.0, duree = 54 }, brulure = { source = "medium-scorchmark-tintable", tenue = 900 } },
    singularite = { vortex = { echelle = 6.0 }, lumiere = { taille = 18, intensite = 0.7 }, pulsation = { n = 6, periode = 180 } },
  },
}

local function copie(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = copie(v) end
  return c
end

local function nombre(x, a, b) return type(x) == "number" and x >= a and x <= b end

--- Couleur d'une arme, lue dans SA table : glow (tourelles), sinon tint (armes de poing, cataclysme), sinon lueur (titans).
--- { r, g, b } entre 0 et 1 ; nil si la table n'en porte aucune (le pack est alors refusé : pas de couleur par défaut).
function Fx.couleur(spec)
  local c = spec.glow or spec.tint or spec.lueur
  if type(c) ~= "table" then return nil end
  local r, g, b = c.r or c[1], c.g or c[2], c.b or c[3]
  if not (nombre(r, 0, 1) and nombre(g, 0, 1) and nombre(b, 0, 1)) then return nil end
  return { r = r, g = g, b = b }
end

--- Couleur au format { r, g, b, a } des kits de l'étape data (prototypes/tirs_kit.lua : R.couleur).
function Fx.rgba(c, a) return { c.r, c.g, c.b, a or 1 } end

--- Nom d'un prototype d'effet d'une arme : fo-fx-<arme>-<quoi>.
function Fx.nom(pack, quoi) return Fx.PREFIXE .. pack.nom .. "-" .. quoi end

--- Le pack d'effets d'une arme : la recette de son mode, sa couleur injectée. nil, motif si le mode est inconnu ou la couleur absente.
function Fx.pack(spec)
  local m = spec and spec.mode and Fx.MODES[spec.mode]
  if not m then return nil, "mode inconnu : " .. tostring(spec and spec.mode) end
  local couleur = Fx.couleur(spec)
  if not couleur then return nil, "aucune couleur dans la table de " .. tostring(spec.name) end
  local p = copie(m)
  p.nom, p.mode, p.couleur, p.age = spec.name, spec.mode, couleur, spec.age
  for _, k in ipairs({ "bouche", "impact", "projectile", "champ", "singularite", "faisceau" }) do
    if p[k] then
      p[k].couleur = couleur
      if p[k].lumiere then p[k].lumiere.couleur = couleur end
    end
  end
  return p
end

--- Les armes avancées à habiller, dans un ordre stable (aucun pairs) : lignée Bastion (A.ages), armes de poing (A.hand_weapons :
--- une arme « existing » prend la couleur de son entrée d'origine), frappe orbitale (A.cataclysm), titans alliés (T.ALLIES).
--- Rend la liste des packs et la liste des refus (nom, motif).
function Fx.armes(A, T)
  local packs, refus = {}, {}
  local function ajoute(spec)
    local p, why = Fx.pack(spec)
    if p then packs[#packs + 1] = p else refus[#refus + 1] = { nom = spec and spec.name, motif = why } end
  end
  for _, t in ipairs(A.ages or {}) do ajoute(t) end
  for _, h in ipairs(A.hand_weapons or {}) do
    local spec = h
    if h.existing and not Fx.couleur(h) then
      for _, o in ipairs(A[h.existing] or {}) do
        if o.name == h.name then spec = { name = h.name, mode = h.mode, age = h.age, tint = o.tint, glow = o.glow, existing = h.existing } end
      end
    end
    ajoute(spec)
  end
  if A.cataclysm then ajoute(A.cataclysm) end
  for _, r in ipairs(T and T.ALLIES or {}) do ajoute({ name = r.name, mode = "titan", lueur = r.lueur, age = r.age, titan = r.id }) end
  return packs, refus
end

--- Vérifie un pack contre les bornes ; rend la liste des motifs (vide = conforme).
function Fx.verifier(pack, B)
  B = B or Fx.BORNES
  local motifs = {}
  local function m(s) motifs[#motifs + 1] = pack.nom .. " : " .. s end
  if not pack.couleur then m("sans couleur") end
  if pack.delegue then return motifs end
  local function lumiere(l, ou)
    if not l then return end
    if not nombre(l.taille, 0.5, B.lumiere_taille_max) then m(ou .. " : lumière de " .. tostring(l.taille) .. " tuiles") end
    if not nombre(l.intensite, 0.05, B.lumiere_intensite_max) then m(ou .. " : intensité " .. tostring(l.intensite)) end
    if l.couleur ~= pack.couleur then m(ou .. " : la lumière n'a pas la couleur de l'arme") end
  end
  local b = pack.bouche
  if b then
    if not nombre(b.duree, 1, B.duree_max) then m("bouche : durée " .. tostring(b.duree)) end
    lumiere({ taille = b.taille, intensite = b.intensite, couleur = b.couleur }, "bouche")
  end
  local i = pack.impact
  if i then
    if i.source and not nombre(i.duree, 1, B.duree_max) then m("impact : durée " .. tostring(i.duree)) end
    lumiere(i.lumiere, "impact")
    if i.etincelles and not nombre(i.etincelles.nombre, 1, B.etincelles_max) then m("impact : " .. tostring(i.etincelles.nombre) .. " étincelles") end
    if i.onde and not (nombre(i.onde.echelle, 0.5, B.vortex_echelle_max) and nombre(i.onde.duree, 1, B.duree_max)) then m("impact : onde hors bornes") end
    if i.choc and not (nombre(i.choc.echelle, 0.5, B.vortex_echelle_max) and nombre(i.choc.duree, 1, B.duree_max)) then m("impact : onde de choc hors bornes") end
    if i.distorsion and not (nombre(i.distorsion.echelle, 0.5, B.vortex_echelle_max) and nombre(i.distorsion.duree, 1, B.duree_max)) then m("impact : distorsion hors bornes") end
    if i.brulure and not (type(i.brulure.source) == "string" and nombre(i.brulure.tenue, 60, B.brulure_tenue_max)) then m("impact : brûlure hors bornes") end
    if not (i.source or i.onde or i.choc) then m("impact sans porteur (ni explosion, ni onde, ni choc)") end
  end
  local f = pack.faisceau
  if f then
    if not nombre(f.epaisseur, B.faisceau_epaisseur_min, B.faisceau_epaisseur_max) then m("faisceau : épaisseur " .. tostring(f.epaisseur)) end
    if f.duree ~= nil and not nombre(f.duree, 1, B.duree_max) then m("faisceau : durée " .. tostring(f.duree)) end
  end
  local p = pack.projectile
  if p then
    lumiere(p.lumiere, "projectile")
    local t = p.trainee
    if t and not nombre(t.frequence, B.trainee_frequence_min, 60) then m("traînée : cadence " .. tostring(t.frequence)) end
    if t and not nombre(t.duree, 1, B.fumee_duree_max) then m("traînée : durée " .. tostring(t.duree)) end
    if p.vortex and not nombre(p.vortex.echelle, 0.2, B.vortex_echelle_max) then m("projectile : vortex hors bornes") end
  end
  local c = pack.champ
  if c and c.vortex and not nombre(c.vortex.echelle, 0.5, B.vortex_echelle_max) then m("champ : vortex hors bornes") end
  local s = pack.singularite
  if s then
    lumiere(s.lumiere, "singularité")
    if s.vortex and not nombre(s.vortex.echelle, 0.5, B.vortex_echelle_max) then m("singularité : vortex hors bornes") end
    if s.pulsation and not (nombre(s.pulsation.n, 2, 32) and nombre(s.pulsation.periode, 30, 600)) then m("singularité : pulsation hors bornes") end
  end
  return motifs
end

--- Vérifie une feuille de graphics/effets/sprites.lua contre le budget (lot ART-IMPACTS) : nombre d'images, côté de la
--- feuille HR (colonnes × largeur, rangées × hauteur), hr = 2 × lr. Rend la liste des motifs (vide = conforme).
function Fx.verifier_feuille(cle, s, B)
  B = B or Fx.BORNES
  local motifs = {}
  local function m(x) motifs[#motifs + 1] = tostring(cle) .. " : " .. x end
  if type(s) ~= "table" or not (s.lr and s.hr) then m("entrée absente") return motifs end
  if not nombre(s.images, 1, B.feuille_images_max) then m(tostring(s.images) .. " images") end
  local cols = s.line_length or s.images
  local rows = math.ceil((s.images or 1) / (cols or 1))
  if not (s.hr.width * cols <= B.feuille_px_max and s.hr.height * rows <= B.feuille_px_max) then
    m(string.format("feuille HR de %d × %d px", s.hr.width * (cols or 0), s.hr.height * rows))
  end
  if not (s.hr.width == 2 * s.lr.width and s.hr.height == 2 * s.lr.height) then m("hr n'est pas 2 × lr") end
  return motifs
end

--- Table de pulsation : n valeurs d'une onde TRIANGULAIRE entre lo et hi (montée puis descente), sans trigonométrie.
function Fx.pulsation(n, lo, hi)
  lo = lo or Fx.BORNES.pulsation_min
  hi = hi or Fx.BORNES.pulsation_max
  local t = {}
  for i = 0, n - 1 do
    local x = 2 * i / n            -- 0 → 2 (exclu)
    if x > 1 then x = 2 - x end    -- triangle : 0 → 1 → 0
    t[i + 1] = lo + (hi - lo) * x
  end
  return t
end

--- Indice (1..n) de la pulsation au tick donné pour une période de `periode` ticks : avance d'un cran tous les periode / n ticks.
function Fx.pulse_index(tick, periode, n)
  return math.floor((tick % periode) * n / periode) + 1
end

return Fx
