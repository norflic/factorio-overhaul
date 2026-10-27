--[[
  Tirs des tourelles par âge (lot TIRS, 27/10) : runtime. Données : shared/tirs/ages.lua ; règles : shared/tirs/regles.lua ;
  prototypes : prototypes/tirs.lua.

  Chaque tir de TOURELLE à balles lève on_script_trigger_effect (effet `script` des chargeurs, tiré par le moteur
  avec la probabilité T.probabilite ; l'événement n'a pas de filtre en 1.1.91 : toute tourelle à balles de la carte,
  factions et vanilla comprises, le lève). Le gestionnaire :
    1. rend la main tout de suite si la source n'est pas une mitrailleuse d'un âge de la table (compté `autres`) ;
    2. décide par R.decider (règle pure) : proximité d'un joueur connecté (relevé toutes les T.releve ticks), part
       de l'âge, quota de l'âge par tick, plafond commun par tick (compteurs dans le stockage : déterministe) ;
    3. dessine la bouche ORIENTÉE vers la cible (rendering.draw_animation, orientation_target, le pied de la flamme
       sur la bouche) et sa lumière (rendering.draw_light), crée la fumée de bouche, les dards (le premier crée
       l'impact à son arrivée) et le trait.
  Aucune entité créée ne touche au jeu (prototypes/tirs.lua le contrôle) ; aucun `pairs`, aucune trigonométrie (le
  moteur oriente la flamme), aucun temps mesuré ; les tables nom -> âge sont construites au chargement du fichier
  (aucun require pendant un événement, F24). Interface « fo-tirs » (bancs) : stats(), actif(booléen), noms(),
  releve() (relevé des joueurs tout de suite).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local L = require("shared.levels.config")
local T = require("shared.tirs.ages")
local R = require("shared.tirs.regles")

local AGE = {}   -- [nom de la tourelle] = âge habillé
local NOMS = {}  -- [âge] = noms et réglages tout prêts (aucun calcul de table pendant un tir)
for _, f in ipairs(L.families) do
  if f.key == "gun" then
    for n = 2, f.max do
      local e = L.epoch_of(f, n)
      if T.ages[e] then AGE[L.name(f, n)] = e end
    end
  end
end
local TUILE_LUMIERE = 300 / 32 -- utility/light_medium : 300 px, soit 9,375 tuiles à l'échelle 1
for _, e in ipairs(T.temoins) do
  local A = T.ages[e]
  local x = { bouche = {}, nimpact = #A.impact }
  for i, b in ipairs(A.bouche) do
    local an = T.ANIMS[b.anim]
    local n = an.variations and an.variations[b.variation].n or an.n
    -- vitesse d'animation : les n images en `duree` ticks (un peu moins, pour ne pas reboucler au dernier tick)
    x.bouche[i] = { nom = R.nom(T, e, "bouche", i), n = n, v = n / b.duree * 0.999, ttl = b.duree,
      xs = b.largeur, ys = b.longueur, avance = { 0, -an.base * b.longueur } }
  end
  if A.lumiere then
    x.lumiere = { scale = A.lumiere.taille / TUILE_LUMIERE, intensity = A.lumiere.intensite,
      color = R.couleur(A.lumiere.couleur), ttl = A.lumiere.duree }
  end
  if A.fumee then x.fumee, x.nfumee = R.nom(T, e, "fumee"), A.fumee.nombre end
  x.trace, x.vitesse = R.nom(T, e, "trace"), A.trace.vitesse
  x.ndards, x.ralenti = A.trace.nombre or 1, A.trace.ralenti or 1
  if x.ndards > 1 then x.dard = R.nom(T, e, "dard") end
  if A.trait then x.trait, x.trait_duree = R.nom(T, e, "trait"), A.trait.duree end
  NOMS[e] = x
end

local JOURNAL_MAX = 40

local function stats_age()
  return { evts = 0, habilles = 0, loin = 0, part = 0, quota = 0, plafond = 0, crees = 0, ratees = 0, rendus = 0 }
end

Storage.declare("tirs", function()
  local st = {}
  for _, e in ipairs(T.temoins) do st[e] = stats_age() end
  return { actif = true, cpt = {}, plafond = { tick = -1, n = 0 }, quota = {}, joueurs = nil, stats = st, autres = 0,
    journal = {} }
end)

local function S() return Storage.ns("tirs") end

local function compte(st, ent)
  if ent then st.crees = st.crees + 1 else st.ratees = st.ratees + 1 end
end

--- Relevé des joueurs connectés (état du jeu, identique sur toutes les machines), dans l'ordre de la liste du moteur.
local function releve()
  local s = S()
  if not s then return end
  local j = {}
  for _, p in ipairs(game.connected_players) do
    local pos = p.position
    j[#j + 1] = { s = p.surface.index, x = pos.x, y = pos.y }
  end
  s.joueurs = j
end

local function sur_effet(e)
  if e.effect_id ~= T.ID then return end
  local s = S()
  if not s or not s.actif then return end
  local src = e.source_entity
  local age = src and src.valid and AGE[src.name]
  if not age then
    s.autres = s.autres + 1
    return
  end
  local st = s.stats[age]
  if not st then st = stats_age(); s.stats[age] = st end
  st.evts = st.evts + 1
  local from = e.source_position or src.position
  local d = R.decider(s, age, e.tick, T.ages[age], T, R.proche(s.joueurs, e.surface_index, from.x, from.y, T.proximite))
  if d ~= "garde" then
    st[d] = (st[d] or 0) + 1
    return
  end
  local cible = e.target_entity
  local to = e.target_position or (cible and cible.valid and cible.position)
  if not to then return end
  st.habilles = st.habilles + 1
  if #s.journal < JOURNAL_MAX then
    local p = src.position
    s.journal[#s.journal + 1] = { tick = e.tick, nom = src.name, age = age, px = p.x, py = p.y,
      sx = e.source_position and e.source_position.x, sy = e.source_position and e.source_position.y,
      tx = to.x, ty = to.y, ori = src.orientation }
  end
  local surface = src.surface
  local N = NOMS[age]
  -- 1. bouche orientée : le moteur tourne la flamme (texture « nord ») vers la cible ; le pied sur la bouche
  for i = 1, #N.bouche do
    local b = N.bouche[i]
    local id = rendering.draw_animation({ animation = b.nom, target = from, surface = surface, orientation_target = to,
      oriented_offset = b.avance, x_scale = b.xs, y_scale = b.ys, time_to_live = b.ttl, animation_speed = b.v,
      animation_offset = R.decalage(e.tick, b.v, b.n), render_layer = "explosion" })
    if id then st.rendus = st.rendus + 1 else st.ratees = st.ratees + 1 end
  end
  local l = N.lumiere
  if l then
    local id = rendering.draw_light({ sprite = "utility/light_medium", target = from, surface = surface,
      scale = l.scale, intensity = l.intensity, color = l.color, time_to_live = l.ttl })
    if id then st.rendus = st.rendus + 1 else st.ratees = st.ratees + 1 end
  end
  -- 2. fumée de bouche : bouffées le long des premiers pas du tir (part de la distance : aucune racine)
  if N.fumee then
    local dx, dy = to.x - from.x, to.y - from.y
    for k = 1, N.nfumee do
      surface.create_trivial_smoke({ name = N.fumee, position = { from.x + dx * 0.035 * k, from.y + dy * 0.035 * k } })
    end
  end
  -- 3. dards : le premier porte l'impact, les suivants partent moins vite (rafale discontinue)
  compte(st, surface.create_entity({ name = N.trace, position = from, target = to, speed = N.vitesse, max_range = 80 }))
  local v = N.vitesse
  for _ = 2, N.ndards do
    v = v * N.ralenti
    compte(st, surface.create_entity({ name = N.dard, position = from, target = to, speed = v, max_range = 80 }))
  end
  -- 4. trait (claquement bref) : le faisceau n'a pas de hauteur ; départ 1 tuile au-dessus du point source (F126)
  if N.trait then
    local a, b = { x = from.x, y = from.y - 1 }, { x = to.x, y = to.y - 0.5 }
    compte(st, surface.create_entity({ name = N.trait, position = a, source_position = a, target_position = b,
      duration = N.trait_duree }))
  end
end

Events.on(defines.events.on_script_trigger_effect, sur_effet)
Events.on_nth_tick(T.releve, releve)

remote.add_interface("fo-tirs", {
  --- Compteurs (copie) : par âge témoin, événements reçus, tirs habillés, refus (loin, part, quota, plafond), entités
  --- créées et ratées, objets de rendu dessinés ; `autres` : événements d'autres tireurs ; `journal` : les premiers
  --- tirs habillés (positions source et cible) ; `joueurs` : dernier relevé.
  stats = function()
    local s = S()
    local out = { autres = s.autres, actif = s.actif, ages = {}, journal = {}, joueurs = s.joueurs and #s.joueurs or -1 }
    for _, e in ipairs(T.temoins) do
      local st = s.stats[e] or stats_age()
      out.ages[#out.ages + 1] = { age = e, evts = st.evts, habilles = st.habilles, loin = st.loin or 0,
        part = st.part or 0, quota = st.quota or 0, plafond = st.plafond, crees = st.crees, ratees = st.ratees,
        rendus = st.rendus or 0 }
    end
    for i, j in ipairs(s.journal) do out.journal[i] = j end
    return out
  end,
  --- Allume ou éteint l'habillage (bancs de coût : témoin « événement seul »).
  actif = function(v) S().actif = v and true or false end,
  --- Relevé des joueurs connectés tout de suite (bancs : après un téléport).
  releve = function() releve() end,
  --- Âges témoins et noms des prototypes (bancs).
  noms = function()
    local out = {}
    for _, e in ipairs(T.temoins) do
      local N = NOMS[e]
      local b = {}
      for i, x in ipairs(N.bouche) do b[i] = x.nom end
      local im = {}
      for i = 1, N.nimpact do im[i] = R.nom(T, e, "impact", i) end
      out[#out + 1] = { age = e, noms = { bouche = b, impact = im, trace = N.trace, dard = N.dard, trait = N.trait,
        fumee = N.fumee } }
    end
    return out
  end,
})
