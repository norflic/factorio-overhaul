--[[
  PvP : les factions IA prennent le JOUEUR pour cible d'elles-mêmes, selon un niveau de difficulté
  (OBJECTIFS.md C4 ; réponse du Directeur Créatif à Q4, 21/10 18 h 07 : « oui (et différents niveaux de
  difficulté) »). Lot IA0.

  - Réglage de partie « fo-pvp-difficulty » (runtime-global, modifiable en cours de partie) :
    Paisible, Facile, Normal (défaut), Difficile, Impitoyable. Paramètres : shared/faction/config.lua.
  - Décision PURE (shared/faction/strategy.lua, S.decide) : délai de grâce, préavis, déclaration de
    guerre, cible (le joueur quand il est « dû », sinon la rivale), effectif. Ce module ne fait que
    construire la vue et appliquer les actions.
  - Repérage des installations du joueur SOUS BROUILLARD (lot IA2-c, script/faction/vision.lua ; avant : balayage
    global d'un disque de 1 536 tuiles, lu par toutes les factions) : chaque faction ne sait que ce que ses yeux
    (QG, avant-postes, groupes, éclaireurs) ont vu ; voie « fo-pvp-scan », 1 regard (un count_entities_filtered)
    toutes les 8 ticks, les factions à tour de rôle. Rien n'est regardé en « Paisible ».
  - Cible : choisie par le style du joueur vu par la faction (shared/faction/adversaire.lua : la plus proche par
    défaut, le secteur de départ en dernier ; la moins défendue contre une tortue ; la plus isolée contre un
    expansionniste), installation (pas une tourelle) la plus proche, défense = 8 × tourelles VUES à 40 tuiles
    (+ défense apprise) ; côté d'arrivée le moins défendu, go / no-go au rassemblement (lot IA2-c).
  - Provocation : seule la destruction d'une entité de la faction SOUS cessez-le-feu en est une. En guerre
    ouverte, abattre un attaquant (tourelle, compagnon) est de la légitime défense : aucun effet.
  - Messages au joueur : préavis, déclaration de guerre, départ de chaque attaque (lien [gps]), trêve,
    changement de difficulté, hostilité héritée d'une sauvegarde plus ancienne. Lignes « [FO-PVP] » en
    clair dans le journal (bancs).

  LIMITES (documentées, non traitées) :
  - seule la force « player » est visée et repérée : en multijoueur avec plusieurs forces de joueurs
    (équipes), les autres forces ne sont jamais attaquées et leur cessez-le-feu n'est pas géré ;
  - lot IA2-c : une installation que ni les yeux ni les éclaireurs d'une faction n'ont vue n'est jamais ciblée par
    elle (les éclaireurs sondent le point de départ du joueur, puis des anneaux de 224 et 448 tuiles autour).

  Lot IA0b (base défendue) : la décision pure assiège (« siege » : la faction garde ses soldats pour le
  joueur), se dit dissuadée (« deterred ») ou se joint à un assaut coordonné (« join », Difficile et
  Impitoyable). Ce module tient la fenêtre d'assaut coordonné (war.pvp.rally_until, ouverte par une attaque
  prête contre le joueur, et war.pvp.rally_target : position et défense estimée de la cible de cette
  attaque, CIBLE COMMUNE des attaques jointes), marque les attaques jointes, retient la dernière attaque
  contre une faction (f.pvp.last_rival : fin de l'impasse de la règle du déficit) et journalise chaque
  entrée en siège ou en dissuasion (« [FO-PVP] siege », « [FO-PVP] dissuasion »). Aucun calcul par tick :
  tout se fait dans la pensée du commandant.

  État persistant : war.pvp (niveau, ancre de la grâce, secteurs repérés, curseur, pertes du joueur, fenêtre
  d'assaut coordonné et sa cible), f.pvp par faction (déclarée, provoquée, héritée, préavis, fin de grâce au
  plus tôt, dernière attaque contre le joueur et sa cible, dernière attaque contre une faction, soldats
  envoyés, plan en cours, sièges, attaques jointes), war.pvp_forced (niveau imposé par l'interface distante,
  bancs seulement). Aucune fonction dans global. Sauvegarde antérieure : champs absents lus comme nil ou 0.
]]

local Events = require("script.core.events")
local Scheduler = require("script.core.scheduler")
local Profiler = require("script.core.profiler")
local F = require("shared.faction.config")
local S = require("shared.faction.strategy")
local State = require("script.faction.state")
local Military = require("script.faction.military")
local Character = require("script.faction.character")
local Chef = require("script.faction.chef")
local Vision = require("script.faction.vision")
local A = require("shared.faction.adversaire")

local PvP = {}

PvP.SETTING = "fo-pvp-difficulty"
PvP.SCAN_LANE = "fo-pvp-scan"

local R = F.pvp_rules

local function fname(f) return { "fo-faction.name-" .. f.key } end
local function level_name(level) return { "fo-pvp.level-" .. level } end

local function say(msg, plain)
  game.print(msg)
  log(plain)
end

local function gps(surface, pos)
  local x, y = math.floor(pos.x + 0.5), math.floor(pos.y + 0.5)
  if surface and surface.name ~= "nauvis" then return string.format("[gps=%d,%d,%s]", x, y, surface.name) end
  return string.format("[gps=%d,%d]", x, y)
end

---------------------------------------------------------------------------------------------------
-- Niveau et état
---------------------------------------------------------------------------------------------------
--- Niveau en vigueur : imposé par l'interface distante (bancs), sinon le réglage de partie.
function PvP.difficulty()
  local war = State.war()
  local forced = war and war.pvp_forced
  if forced and F.pvp[forced] then return forced end
  local s = settings.global[PvP.SETTING]
  local v = s and s.value
  if F.pvp[v] then return v end
  return F.pvp_default
end

local function faction_state(f)
  local fp = f.pvp
  if not fp then
    fp = {
      declared = false, provoked = false, warned = false, declared_at = nil, last_attack = nil, due_since = nil,
      sent_player = 0, sent_total = 0, attacks = 0, soldiers = 0, kills = 0, target = nil, saves = 0,
      plan = nil, sieges = 0, deterred = 0, joins = 0,
    }
    f.pvp = fp
  end
  return fp
end
PvP.faction_state = faction_state

local function new_state(war, tick, level)
  local surface = game.surfaces[war.surface]
  local spawn = game.forces.player.get_spawn_position(surface)
  -- Lot IA2-c : plus de comptage global (`sectors`, `score`, `cursor` d'IA0) ; `sweeps` compte les regards des
  -- factions ; `tempo` et `first_done` : moment de la 1re attaque de la partie (script/faction/vision.lua).
  return {
    difficulty = level, anchor = tick, sweeps = 0, losses = 0, first_done = false,
    home = { x = math.floor(spawn.x / R.sector), y = math.floor(spawn.y / R.sector) },
  }
end

local function ceasefire_on(f)
  return game.forces[f.force].get_cease_fire(game.forces.player)
end

local function set_relations(f, ceasefire)
  local force, player = game.forces[f.force], game.forces.player
  force.set_cease_fire(player, ceasefire)
  player.set_cease_fire(force, ceasefire)
end

--- Fin de la grâce d'une faction (tick), nil en « Paisible ».
local function grace_end(p, fp, level, f)
  return S.grace_end(p.anchor, fp.grace_floor, level, Character.of(f)) -- lot IA2-0 : caractère tiré
end

--- Plus court délai de grâce parmi les factions vivantes (ticks), nil en « Paisible ».
local function earliest_grace(war, level)
  local best
  for _, id in ipairs(State.alive()) do
    local g = S.grace_ticks(level, Character.of(war.factions[id]))
    if g and (not best or g < best) then best = g end
  end
  return best
end

--- État PvP d'une guerre en cours. Une guerre lancée avant le lot IA0 (sauvegarde plus ancienne) reçoit
--- son état ici : la grâce part du chargement (pas du lancement de la guerre), et le joueur est prévenu.
--- HOSTILITÉ HÉRITÉE : une faction déjà sans cessez-le-feu avec le joueur (provocation, ou ancien réglage
--- fo-war-player-ceasefire décoché) est marquée provoquée : elle reste hostile en « Paisible » (comme avant
--- IA0) ; hors « Paisible », elle est en guerre déclarée dès la reprise, sans grâce et sans nouvelle
--- déclaration (un message dit qu'elle l'était déjà).
function PvP.ensure(tick)
  local war = State.war()
  if war.pvp then return war.pvp end
  local level = PvP.difficulty()
  local p = new_state(war, tick, level)
  war.pvp = p
  for _, id in ipairs(State.sorted_keys(war.factions)) do faction_state(war.factions[id]) end
  Scheduler.add(PvP.SCAN_LANE, 1)
  say({ "fo-pvp.resumed", level_name(level) }, "[FO-PVP] reprise d'une guerre anterieure : difficulte " .. level .. ", grace depuis le tick " .. tick)
  local aggressive = F.pvp_params(level).aggressive
  for _, id in ipairs(State.alive()) do
    local f = war.factions[id]
    if not ceasefire_on(f) then
      local fp = faction_state(f)
      fp.provoked, fp.inherited = true, true
      if aggressive then fp.declared, fp.warned, fp.declared_at = true, true, tick end
      say({ "fo-pvp.inherited", fname(f) }, string.format("[FO-PVP] hostilite heritee tick %d %s", tick, f.key))
    end
  end
  return p
end

--- Appelé par War.start_at, après la diplomatie : état neuf, repérage, message d'introduction.
function PvP.on_war_started(tick)
  local war = State.war()
  local level = PvP.difficulty()
  war.pvp = new_state(war, tick, level)
  for _, id in ipairs(State.sorted_keys(war.factions)) do
    war.factions[id].pvp = nil
    faction_state(war.factions[id])
  end
  Scheduler.add(PvP.SCAN_LANE, 1)
  local g = earliest_grace(war, level)
  if g then
    say({ "fo-pvp.intro", level_name(level), math.ceil(g / 3600) },
      string.format("[FO-PVP] guerre lancee : difficulte %s, premiere declaration possible au tick %d", level, tick + g))
  else
    say({ "fo-pvp.intro-peaceful", level_name(level) }, "[FO-PVP] guerre lancee : difficulte peaceful")
  end
end

function PvP.on_war_stopped()
  local war = State.war()
  war.pvp = nil
  Scheduler.remove(PvP.SCAN_LANE, 1)
end

---------------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------------
local function declare(f, reason, tick)
  local fp = faction_state(f)
  fp.declared, fp.warned, fp.declared_at, fp.grace_floor = true, true, tick, nil
  fp.sent_player, fp.sent_total, fp.due_since = 0, 0, nil -- la part visée se compte depuis la déclaration
  if ceasefire_on(f) then set_relations(f, false) end
  local key = reason == "provoked" and "fo-pvp.declare-provoked" or "fo-pvp.declare"
  say({ key, fname(f) }, string.format("[FO-PVP] declaration tick %d %s (%s)", tick, f.key, reason))
end

local function truce(f, tick)
  local fp = faction_state(f)
  fp.declared, fp.warned = false, false
  fp.target, fp.due_since, fp.plan = nil, nil, nil
  if not ceasefire_on(f) then set_relations(f, true) end
  Military.recall_player_groups(f, tick)
  say({ "fo-pvp.truce", fname(f) }, string.format("[FO-PVP] treve tick %d %s", tick, f.key))
end

--- Changement de niveau (réglage, interface distante) : effet immédiat et propre.
---   - vers « Paisible » : trêve des factions déclarées par la difficulté (pas des provoquées), rappel de
---     toutes les attaques en route contre le joueur ;
---   - depuis « Paisible » vers un niveau agressif : la grâce repart de maintenant ;
---   - entre niveaux agressifs : même ancre, nouveaux paramètres dès la pensée suivante ; une faction non
---     déclarée dont la nouvelle grâce finirait dans moins de warn_ticks (ou serait déjà écoulée) ne
---     déclare la guerre qu'après un préavis complet (fin de grâce au plus tôt : maintenant + warn_ticks).
function PvP.sync(tick)
  local war = State.war()
  if not war.active then return end
  local p = PvP.ensure(tick)
  local level = PvP.difficulty()
  if p.difficulty == level then return end
  local was = F.pvp_params(p.difficulty).aggressive
  p.difficulty = level
  local d = F.pvp_params(level)
  if d.aggressive and not was then p.anchor = tick end
  if S.rally_ticks(level) <= 0 then p.rally_until, p.rally_target = nil, nil end -- Difficile et Impitoyable seulement
  say({ "fo-pvp.changed", level_name(level) }, string.format("[FO-PVP] difficulte %s au tick %d", level, tick))
  for _, id in ipairs(State.alive()) do
    local f = war.factions[id]
    local fp = faction_state(f)
    if not fp.declared then
      fp.warned, fp.grace_floor = false, nil
      if d.aggressive and was and not fp.provoked and grace_end(p, fp, level, f) < tick + R.warn_ticks then
        fp.grace_floor = tick + R.warn_ticks
      end
    end
    if not d.aggressive then
      if fp.declared and not fp.provoked then
        truce(f, tick)
      else
        fp.declared = false
        Military.recall_player_groups(f, tick)
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Repérage du joueur SOUS BROUILLARD (lot IA2-c, script/faction/vision.lua) : chaque faction ne sait que ce que ses
-- yeux (QG, avant-postes, groupes, éclaireurs) ont vu. La voie « fo-pvp-scan » (toutes les 8 ticks, 1 comptage par
-- passe, comme le balayage global d'IA0 qu'elle remplace) regarde le secteur suivant de la file d'une faction.
---------------------------------------------------------------------------------------------------
Scheduler.define_lane(PvP.SCAN_LANE, R.scan_period, function(_, tick)
  local war = State.war()
  local p = war.active and war.pvp
  if not p then
    Scheduler.remove(PvP.SCAN_LANE, 1)
    return
  end
  if not F.pvp_params(p.difficulty).aggressive then return end -- « Paisible » : aucun coût
  local surface = game.surfaces[war.surface]
  if not surface then return end
  Profiler.start("pvp:scan")
  Vision.pass(surface, p, tick)
  Profiler.stop("pvp:scan")
end)

--- Vue « joueur » d'une faction, évaluée seulement quand elle peut servir (niveau agressif, guerre
--- déclarée ou grâce écoulée, intervalle entre deux attaques écoulé). nil sinon (ou si elle n'a rien vu).
local function player_view(f, surface, p, fp, tick, level)
  if not F.pvp_params(level).aggressive then return nil end
  if not fp.declared and not fp.provoked and tick < grace_end(p, fp, level, f) then return nil end
  local v = Vision.state(f)
  if fp.last_attack and tick - fp.last_attack < S.cooldown_ticks(level) then return nil end
  if Military.target_unreachable(f, "player", tick) then
    local n = #State.sorted_keys(v.known)
    if n == 0 then return nil end
    return { score = n, defense = 0, reachable = false }
  end
  return Vision.player_view(f, p, fp, tick)
end

local function player_groups(f)
  local n = 0
  for _, gid in ipairs(State.sorted_keys(f.groups)) do
    local g = f.groups[gid]
    if g.target_faction == "player" and g.state == "attack" then n = n + 1 end
  end
  if f.route_pending and f.route_pending.target_faction == "player" then n = n + 1 end
  return n
end

--- Pensée PvP d'une faction (appelée par le commandant à la place de l'ancienne décision d'attaque).
--- view, target : vue et cible faction calculées par le commandant (logique d'avant IA0).
function PvP.think(f, surface, tick, view, target)
  local war = State.war()
  PvP.sync(tick)
  local p = war.pvp
  local fp = faction_state(f)
  local level = p.difficulty
  local leader = 0
  for _, id in ipairs(State.alive()) do
    if id ~= f.id then
      local o = war.factions[id].outposts_count
      if o > leader then leader = o end
    end
  end
  view.rival = target and { id = target.id, outposts = target.outposts_count } or nil
  view.own_outposts = f.outposts_count
  view.leader_outposts = leader
  -- Lot IA2-c : brouillard. Aux niveaux agressifs, la faction prépare ses regards (file de secteurs), tient son
  -- modèle du joueur (style) et envoie ses éclaireurs ; « Paisible » : rien (aucun coût).
  Vision.state(f)
  local aggressive = F.pvp_params(level).aggressive
  if aggressive and f.hq_pos then
    Vision.plan(f, tick)
    Vision.update_model(f, tick)
    Vision.scout_policy(f, surface, p, fp, tick, grace_end(p, fp, level, f))
  end
  -- Lot IA2-c : moment de la 1re attaque de la partie (valeur du niveau × tempo de la partie, ±20 %), sauf pour une
  -- faction provoquée (représailles). (Intervalle entre deux attaques × tempo tiré à ±20 % : mesuré, NON retenu, il
  -- casse l'ordre strict des niveaux dans la campagne de tests/pvp_test.lua.)
  local first_after
  if aggressive and not Vision.first_done(p) and not fp.provoked then
    first_after = A.first_after(p.anchor, level, Vision.game_tempo(p))
  end
  view.pvp = {
    difficulty = level, tick = tick, anchor = p.anchor, grace_floor = fp.grace_floor,
    declared = fp.declared, provoked = fp.provoked,
    warned = fp.warned, last_attack = fp.last_attack, sent_player = fp.sent_player, sent_total = fp.sent_total,
    player_groups = player_groups(f), due_since = fp.due_since, last_rival = fp.last_rival,
    rally_until = p.rally_until, rally_defense = p.rally_until and p.rally_target and p.rally_target.defense or nil,
    first_after = first_after, first_prep = A.PREP,
  }
  view.player = player_view(f, surface, p, fp, tick, level)
  local a = S.decide(view)
  if a.due_since ~= nil then fp.due_since = a.due_since or nil end
  if a.plan == "save" then fp.saves = (fp.saves or 0) + 1 end
  -- Lot IA0b : entrée en siège ou en dissuasion (une ligne de journal par entrée, pas par pensée).
  if a.plan ~= fp.plan then
    if a.plan == "siege" then
      fp.sieges = (fp.sieges or 0) + 1
      log(string.format("[FO-PVP] siege tick %d %s : besoin %d, disponibles %d, defense estimee %d, tech %d",
        tick, f.key, a.need or 0, a.count or 0, view.player and view.player.defense or 0, f.tech or 0))
    elseif a.plan == "deterred" then
      fp.deterred = (fp.deterred or 0) + 1
      log(string.format("[FO-PVP] dissuasion tick %d %s : besoin %d, disponibles %d, defense estimee %d, tech %d",
        tick, f.key, a.need or 0, a.count or 0, view.player and view.player.defense or 0, f.tech or 0))
    end
  end
  fp.plan = a.plan

  if a.warn then
    fp.warned = true
    say({ "fo-pvp.warn", fname(f), a.warn }, string.format("[FO-PVP] preavis tick %d %s : %d min", tick, f.key, a.warn))
  end
  if a.declare then declare(f, a.declare, tick) end
  if a.truce then truce(f, tick) end
  if a.recall then Military.recall_player_groups(f, tick) end
  if a.attack then
    if a.attack.target == "player" and fp.target then
      -- Attaque jointe : la cible de la fenêtre (cible commune), sinon celle de la faction.
      local rt = a.attack.join and p.rally_target or nil
      local pos = rt and { x = rt.x, y = rt.y } or fp.target.pos
      local defense = rt and rt.defense or fp.target.defense
      -- Lot IA2-c : côté le moins défendu (défense VUE par octant), rassemblement avancé, go / no-go.
      local key = rt and A.key(A.sector_of(pos.x, pos.y)) or fp.target.sector
      local opts = Vision.attack_opts(f, pos, defense, key)
      if Military.attack(f, surface, { id = "player", key = "player", hq_pos = pos, outposts = {} }, a.attack.count, tick, opts)
        and f.route_pending then
        f.route_pending.join, f.route_pending.need, f.route_pending.defense = a.attack.join or nil, a.need, defense
        if a.rally then
          -- Difficile, Impitoyable : fenêtre d'assaut coordonné pour les autres factions qui assiègent ; la
          -- dernière attaque prête fixe la cible commune.
          local u = tick + S.rally_ticks(level)
          if not p.rally_until or u > p.rally_until then p.rally_until = u end
          p.rally_by = f.key
          p.rally_target = { x = pos.x, y = pos.y, defense = defense }
          log(string.format("[FO-PVP] assaut coordonne ouvert tick %d par %s jusqu'au tick %d, cible (%d, %d), defense estimee %d",
            tick, f.key, p.rally_until, math.floor(pos.x), math.floor(pos.y), defense or 0))
        end
      end
    elseif target and a.attack.target == target.id then
      -- Lot IA2-a : point visé (raid : avant-poste vu le plus faible) et côté d'arrivée choisis par le chef.
      local opts = Chef.attack_opts(f, target, a.attack, tick)
      -- Lot IA2-c : défense estimée au départ (go / no-go au rassemblement avancé).
      if opts and view.enemy_defense and view.enemy_defense < math.huge then opts.launch_def = view.enemy_defense end
      Military.attack(f, surface, target, a.attack.count, tick, opts)
    end
  end
  return a
end

--- Le joueur a détruit une entité de la faction. Sous cessez-le-feu, c'est une provocation : cessez-le-feu
--- rompu (comme avant IA0) et, hors « Paisible », la faction le prend aussitôt pour cible (fin de la grâce
--- pour elle). En guerre ouverte (déclarée par la difficulté, provoquée ou héritée), abattre un attaquant
--- est de la légitime défense : rien ne change (pas de provocation, trêve de « Paisible » toujours
--- possible, grâce intacte au retour à un niveau agressif, aucun message).
function PvP.on_provoked(f, tick)
  local war = State.war()
  if not war.active then return end
  local p = PvP.ensure(tick)
  if not ceasefire_on(f) then return end
  local fp = faction_state(f)
  fp.provoked = true
  set_relations(f, false)
  if F.pvp_params(p.difficulty).aggressive and not fp.declared then
    fp.declared, fp.warned, fp.declared_at, fp.grace_floor = true, true, tick, nil
    fp.sent_player, fp.sent_total, fp.due_since = 0, 0, nil
  end
  say({ "fo-pvp.declare-provoked", fname(f) }, string.format("[FO-PVP] declaration tick %d %s (provoked)", tick, f.key))
end

---------------------------------------------------------------------------------------------------
-- Crochets du module militaire
---------------------------------------------------------------------------------------------------
-- Lot IA2-c : go / no-go au rassemblement avancé d'une attaque contre une rivale (script/faction/chef.lua).
Vision.rally_rival = Chef.rally

--- Une route vers le joueur arrive : l'attaque part-elle encore (niveau, guerre déclarée) ?
Military.player_target_allowed = function(f)
  local p = State.war().pvp
  return p ~= nil and F.pvp_params(p.difficulty).aggressive and f.pvp ~= nil and f.pvp.declared
end

--- Un groupe part : comptes de la part visée ; message au joueur si l'attaque le vise.
Military.on_launched = function(f, target_faction, n, rp, tick)
  local fp = faction_state(f)
  -- Lot IA2-a : un RAID du chef ne compte ni dans la part visée (sent_total) ni comme attaque contre une rivale
  -- (last_rival) : la règle du déficit et la fin de l'impasse restent celles d'IA0b (campagne de pvp_test).
  if rp.raid and target_faction.id ~= "player" then return end
  fp.sent_total = fp.sent_total + n
  if target_faction.id ~= "player" then
    fp.last_rival = tick -- lot IA0b : fin de l'impasse de la règle du déficit (S.rival_stalled)
    Character.redraw(f) -- lot IA2-0 : seuil de la prochaine attaque entre factions, tiré à ±20 %
    return
  end
  fp.sent_player = fp.sent_player + n
  fp.attacks = fp.attacks + 1
  fp.soldiers = fp.soldiers + n
  fp.last_attack = tick
  fp.due_since, fp.plan = nil, nil
  fp.last_target = { x = rp.target.x, y = rp.target.y, defense = rp.defense }
  local surface = game.surfaces[State.war().surface]
  if rp.join then fp.joins = (fp.joins or 0) + 1 end
  -- Lot IA2-c : mémoire de l'attaque (secteur, octant), 1re attaque de la partie faite.
  local war = State.war()
  if war.pvp then war.pvp.first_done = true end
  local v = Vision.state(f)
  A.record_given(v.model, { gid = rp.gid, key = rp.key, octant = rp.octant, n = n, tick = tick })
  say({ rp.join and "fo-pvp.attack-joined" or "fo-pvp.attack", fname(f), n, gps(surface, rp.target) },
    string.format("[FO-PVP] attaque tick %d %s -> joueur : %d soldats vers (%d, %d), defense estimee %d, besoin %d, tech %d%s, octant %s, cote %s sur %s, direct %s, style %s, tempo %d",
      tick, f.key, n, math.floor(rp.target.x), math.floor(rp.target.y), rp.defense or (fp.target and fp.target.defense) or 0,
      rp.need or 0, f.tech or 0, rp.join and " (assaut coordonne)" or "", tostring(rp.octant or "-"), tostring(rp.side_def or "-"),
      tostring(rp.side_max or "-"), tostring(rp.direct or "-"), v.model.style or "-", war.pvp and war.pvp.tempo or 1000))
end

---------------------------------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------------------------------
Events.on(defines.events.on_runtime_mod_setting_changed, function(e)
  if e.setting ~= PvP.SETTING then return end
  local war = State.war()
  if war and war.active then PvP.sync(e.tick) end
end)

-- Pertes du joueur causées par les factions (preuve des attaques, statut). Coût : le tueur est testé
-- d'abord (champ de l'événement, puis un seul appel d'API pour son nom) ; l'entité morte n'est lue que si
-- le tueur est une faction.
Events.on(defines.events.on_entity_died, function(e)
  local killer = e.force
  if not killer then return end
  local war = State.war()
  if not (war.active and war.pvp) then return end
  local f = State.by_force(killer.name)
  if not f then return end
  local ent = e.entity
  if not (ent and ent.valid) or ent.force.name ~= "player" then return end
  war.pvp.losses = (war.pvp.losses or 0) + 1
  local fp = faction_state(f)
  fp.kills = fp.kills + 1
end)

-- Sauvegarde d'une version antérieure avec une guerre en cours : état PvP créé au chargement.
Events.on_configuration_changed(function()
  local war = State.war()
  if war and war.active and not war.pvp and not war.reset_v03 then PvP.ensure(game.tick) end
end)

---------------------------------------------------------------------------------------------------
-- Statut et interface distante
---------------------------------------------------------------------------------------------------
function PvP.status(tick)
  local war = State.war()
  local p = war.pvp
  local level = PvP.difficulty()
  local out = {
    active = war.active, difficulty = level, forced = war.pvp_forced, anchor = p and p.anchor,
    score = 0, sweeps = p and p.sweeps or 0, losses = p and p.losses or 0,
    sectors = 0, factions = {}, rally_until = p and p.rally_until,
    tempo = p and p.tempo, first_done = p and p.first_done,
    rally_target = p and p.rally_target and { x = p.rally_target.x, y = p.rally_target.y, defense = p.rally_target.defense } or nil,
  }
  -- Lot IA2-c : plus de comptage global ; `sectors` = secteurs du joueur vus par la faction qui en voit le plus,
  -- `score` = la même chose (compatibilité des bancs d'IA0).
  for _, id in ipairs(State.sorted_keys(war.factions or {})) do
    local f = war.factions[id]
    local fp = f.pvp or {}
    out.factions[#out.factions + 1] = {
      key = f.key, personality = f.personality, eliminated = f.eliminated,
      declared = fp.declared or false, provoked = fp.provoked or false, inherited = fp.inherited or false,
      declared_at = fp.declared_at,
      grace_end = p and S.grace_end(p.anchor, fp.grace_floor, level, Character.of(f)) or nil,
      attacks = fp.attacks or 0, soldiers = fp.soldiers or 0,
      sent_player = fp.sent_player or 0, sent_total = fp.sent_total or 0, last_attack = fp.last_attack,
      kills = fp.kills or 0,
      target = fp.target and { x = fp.target.pos.x, y = fp.target.pos.y, defense = fp.target.defense } or nil,
      last_target = fp.last_target and { x = fp.last_target.x, y = fp.last_target.y, defense = fp.last_target.defense } or nil,
      last_rival = fp.last_rival, plan = fp.plan, sieges = fp.sieges or 0, deterred = fp.deterred or 0, joins = fp.joins or 0, tech = f.tech,
    }
    local v = fp.vision
    local rec = out.factions[#out.factions]
    rec.known = v and #State.sorted_keys(v.known) or 0
    rec.style = v and v.model.style or "inconnu"
    rec.scouts = f.stats and f.stats.scouts or 0
    rec.renonce = f.stats and f.stats.renonce or 0
    if rec.known > out.sectors then out.sectors, out.score = rec.known, rec.known end
  end
  return out
end

function PvP.status_line(tick)
  local st = PvP.status(tick)
  local parts = {}
  for _, fs in ipairs(st.factions) do
    parts[#parts + 1] = string.format("%s %s%s att %d (%d soldats, %d jointes) sieges %d pertes infligees %d, vus %d, style %s", fs.key,
      fs.declared and "GUERRE" or "treve", fs.provoked and "*" or "", fs.attacks, fs.soldiers, fs.joins, fs.sieges, fs.kills,
      fs.known, fs.style)
  end
  return string.format("  PvP : difficulte %s | secteurs du joueur vus %d (regards %d) | pertes du joueur %d | %s",
    st.difficulty, st.sectors, st.sweeps, st.losses, table.concat(parts, " ; "))
end

--- Impose un niveau sans joueur (bancs). Écrit le réglage du mod (un mod peut changer ses propres
--- réglages) ; si le moteur le refuse, le niveau est imposé dans l'état (war.pvp_forced). nil = rendre
--- la main au réglage.
function PvP.set_difficulty(level)
  local war = State.war()
  if level == nil then
    war.pvp_forced = nil
  else
    if not F.pvp[level] then return false end
    local ok = pcall(function() settings.global[PvP.SETTING] = { value = level } end)
    if ok and settings.global[PvP.SETTING].value == level then
      war.pvp_forced = nil
    else
      war.pvp_forced = level
    end
  end
  if war.active then PvP.sync(game.tick) end
  return true
end

remote.add_interface("fo-pvp", {
  status = function() return PvP.status(game.tick) end,
  set_difficulty = function(level) return PvP.set_difficulty(level) end,
})

return PvP
