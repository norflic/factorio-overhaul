--[[
  Tirs des tourelles par âge (lot TIRS, 27/10) : runtime. Données : shared/tirs/ages.lua ; règles : shared/tirs/regles.lua ;
  prototypes : prototypes/tirs.lua.

  Chaque tir de TOURELLE à balles lève on_script_trigger_effect (effet `script` des chargeurs, tiré par le moteur
  avec la probabilité T.probabilite ; l'événement n'a pas de filtre en 1.1.91). Le gestionnaire :
    1. rend la main tout de suite si la source n'est pas une mitrailleuse d'un âge de la table (vanilla, factions,
       autres âges : effet d'avant) ;
    2. garde `part` des événements de l'âge (accumulateur entier par âge, dans le stockage : déterministe) ;
    3. sous le quota de l'âge (A.quota par tick) et le plafond de T.plafond_tick tirs habillés par tick (toute la carte ; compteurs remis à zéro au tick
       suivant, dans le stockage) ;
    4. crée les explosions de bouche à la position source de l'effet, la traçante vers la position de la cible (son
       action crée l'impact à l'arrivée ; sans traçante, l'impact est créé tout de suite) et le trait.
  Aucune entité créée ne touche au jeu (prototypes/tirs.lua le contrôle) ; aucun `pairs`, aucune trigonométrie, aucun
  temps mesuré ; la table nom -> âge est construite au chargement du fichier (aucun require pendant un événement, F24).
  Interface « fo-tirs » (bancs) : stats(), actif(booléen).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local L = require("shared.levels.config")
local T = require("shared.tirs.ages")
local R = require("shared.tirs.regles")

local AGE = {}   -- [nom de la tourelle] = âge habillé
local NOMS = {}  -- [âge] = { bouche = { noms }, impact = { noms }, trace = nom | nil, trait = nom | nil }
for _, f in ipairs(L.families) do
  if f.key == "gun" then
    for n = 2, f.max do
      local e = L.epoch_of(f, n)
      if T.ages[e] then AGE[L.name(f, n)] = e end
    end
  end
end
for _, e in ipairs(T.temoins) do
  local A = T.ages[e]
  local x = { bouche = {}, impact = {} }
  for i = 1, #A.bouche do x.bouche[i] = R.nom(T, e, "bouche", i) end
  for i = 1, #A.impact do x.impact[i] = R.nom(T, e, "impact", i) end
  if A.trace then x.trace = R.nom(T, e, "trace") end
  if A.trait then x.trait = R.nom(T, e, "trait") end
  NOMS[e] = x
end

local JOURNAL_MAX = 40

local function stats_age()
  return { evts = 0, habilles = 0, plafond = 0, crees = 0, ratees = 0 }
end

Storage.declare("tirs", function()
  local st = {}
  for _, e in ipairs(T.temoins) do st[e] = stats_age() end
  return { actif = true, cpt = {}, plafond = { tick = -1, n = 0 }, quota = {}, stats = st, autres = 0, journal = {} }
end)

local function S() return Storage.ns("tirs") end

local function compte(st, ent)
  if ent then st.crees = st.crees + 1 else st.ratees = st.ratees + 1 end
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
  local A = T.ages[age]
  local garde, c = R.garder(s.cpt[age], A.part)
  s.cpt[age] = c
  if not garde then return end
  s.quota = s.quota or {}
  local q = s.quota[age]
  if not q then q = { tick = -1, n = 0 }; s.quota[age] = q end
  -- quota de l'âge d'abord (sans entamer le plafond commun), puis plafond commun
  if q.tick == e.tick and q.n >= A.quota then
    st.plafond = st.plafond + 1
    return
  end
  if not R.plafond(s.plafond, e.tick, T.plafond_tick) then
    st.plafond = st.plafond + 1
    return
  end
  R.plafond(q, e.tick, A.quota)
  local cible = e.target_entity
  local to = e.target_position or (cible and cible.valid and cible.position)
  if not to then return end
  local from = e.source_position or src.position
  st.habilles = st.habilles + 1
  if #s.journal < JOURNAL_MAX then
    local p = src.position
    s.journal[#s.journal + 1] = { tick = e.tick, nom = src.name, age = age, px = p.x, py = p.y,
      sx = e.source_position and e.source_position.x, sy = e.source_position and e.source_position.y,
      tx = to.x, ty = to.y, ori = src.orientation }
  end
  local surface = src.surface
  local N = NOMS[age]
  for i = 1, #N.bouche do compte(st, surface.create_entity({ name = N.bouche[i], position = from })) end
  if N.trace then
    compte(st, surface.create_entity({ name = N.trace, position = from, target = to, speed = A.trace.vitesse,
      max_range = 80 }))
  else
    for i = 1, #N.impact do compte(st, surface.create_entity({ name = N.impact[i], position = to })) end
  end
  if N.trait then
    -- le faisceau n'a pas de hauteur : départ 1 tuile au-dessus du point source (hauteur d'une explosion, F126)
    local a, b = { x = from.x, y = from.y - 1 }, { x = to.x, y = to.y - 0.5 }
    compte(st, surface.create_entity({ name = N.trait, position = a, source_position = a, target_position = b,
      duration = A.trait.duree }))
  end
end

Events.on(defines.events.on_script_trigger_effect, sur_effet)

remote.add_interface("fo-tirs", {
  --- Compteurs (copie) : par âge témoin, événements reçus, tirs habillés, refus du plafond, entités créées et ratées ;
  --- `autres` : événements d'autres tireurs ; `journal` : les premiers tirs habillés (positions source et cible).
  stats = function()
    local s = S()
    local out = { autres = s.autres, actif = s.actif, ages = {}, journal = {} }
    for _, e in ipairs(T.temoins) do
      local st = s.stats[e] or stats_age()
      out.ages[#out.ages + 1] = { age = e, evts = st.evts, habilles = st.habilles, plafond = st.plafond,
        crees = st.crees, ratees = st.ratees }
    end
    for i, j in ipairs(s.journal) do out.journal[i] = j end
    return out
  end,
  --- Allume ou éteint l'habillage (bancs de coût : témoin « événement seul »).
  actif = function(v) S().actif = v and true or false end,
  --- Âges témoins et noms des prototypes (bancs).
  noms = function()
    local out = {}
    for _, e in ipairs(T.temoins) do out[#out + 1] = { age = e, noms = NOMS[e] } end
    return out
  end,
})
