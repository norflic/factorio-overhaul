--[[
  Lot RECON (28/10) : EXÉCUTION de la connaissance des rivales (règles pures : shared/faction/recon.lua).

  Réponse du Directeur Créatif : « les factions ne peuvent viser QUE ce qu'elles ont reconnu : elles ne peuvent pas
  viser un avant-poste qui n'a pas été vu, parce qu'elles ne savent pas s'il y a des gens ; peut-être qu'elles ont
  apporté un soldat quand même, si ça peut faire l'exploration ».

  Ce module :
  - lit le magasin de connaissance tenu par script/faction/chef.lua (f.chef.seen[id].k : QG et avant-postes VUS) :
    Recon.status / Recon.attackable ;
  - REFUSE toute attaque contre une rivale non reconnue ou périmée (Military.attack_known, filet : le chef et le
    commandant ne la désignent déjà pas) et la compte (f.stats.recon_refused, ligne [FO-RECON] refus) ;
  - RECONNAÎT RÉGULIÈREMENT, comme un joueur (précision du DC, 28/10) : envoie un SOLDAT ÉCLAIREUR (Military.scout, le
    mécanisme d'IA2-c) quand le chef demande une reconnaissance (f.chef.recon : rivale inconnue, périmée, ou vieillissante à
    revérifier avant l'assaut) OU, sans besoin précis, pour un BALAYAGE de la carte (R.sweep_gap : fréquence selon la
    curiosité, délai allongé par la menace, portée R.range). Destination : dernier point connu d'une rivale périmée ou
    vieillissante, sinon la frontière de la carte de connaissance de l'équipe (script/ai3/exploration.lua,
    Recon.pick_frontier : mêmes exclusions que les éclaireurs ouvriers + régions où un chemin de soldat a raté). Un soldat seul
    passe sans combattre ; après une perte, un petit groupe (R.size : +1 par perte, 3 au plus, 25 % de la garnison au
    plus), un délai doublé (R.gap, F235), et jamais sous la garnison gardée du caractère ni sous R.RESERVE.
  - Brouillard coupé (remote fo-ia3f set_fog(false)) : ancienne omniscience, pour les bancs avant / après.

  Les crochets de Military.scout (Military.on_scout_done / on_scout_lost, posés par script/faction/vision.lua pour les
  éclaireurs du joueur) sont enveloppés par Recon.install() : les éclaireurs de tag « recon » sont traités ici, tous les
  autres vont à Vision, inchangés.

  Crochets posés par script/ai3/exploration.lua (chargé après ce module) : Recon.fog_on, Recon.pick_frontier,
  Recon.watch, Recon.mark_bad.
]]

local R = require("shared.faction.recon")
local F = require("shared.faction.config")
local State = require("script.faction.state")
local Military = require("script.faction.military")
local Character = require("script.faction.character")
local Sites = require("script.faction.sites")

local Recon = {}

Recon.TAG = "recon"
local GEN_TRIES = 6        -- demandes de génération du but avant de l'écarter
local GEN_WAIT = 180       -- attente entre deux contrôles de génération (3 s)
local NO_DEST_WAIT = 1800  -- aucune frontière sûre : nouvel essai dans 30 s
local BUSY_WAIT = 600      -- l'éclaireur n'a pas pu partir (garnison, chemin en cours) : nouvel essai dans 10 s

-- Crochets posés par script/ai3/exploration.lua.
Recon.fog_on = function() return true end
Recon.pick_frontier = nil
Recon.watch = nil
Recon.mark_bad = nil
Recon.note_nopath = nil
Recon.ring_on = true -- a priori d'anneau pour chercher une rivale (bancs de mesure : remote recon_options)

local function label(f, rid)
  local r = rid and State.faction(rid)
  return r and r.key or tostring(rid)
end

---------------------------------------------------------------------------------------------------
-- Lecture de la connaissance
---------------------------------------------------------------------------------------------------
--- Connaissance (QG, avant-postes vus) que `f` a de la rivale `rid`, ou nil.
function Recon.known_of(f, rid)
  local st = f.chef
  local mem = st and st.seen and st.seen[rid]
  return mem and mem.k or nil
end

--- "inconnue" | "perimee" | "fraiche".
function Recon.status(f, rid, tick)
  return R.status(Recon.known_of(f, rid), tick)
end

--- Peut-on attaquer cette rivale ? Seulement si elle est reconnue, et fraîche. Brouillard coupé : toujours.
function Recon.attackable(f, rid, tick)
  if not Recon.fog_on() then return true end
  return R.fresh(Recon.known_of(f, rid), tick)
end

--- Points de la rivale connus de `f` (QG et avant-postes, même périmés), pour les cartes de valeur : { x, y, hq }.
function Recon.points_of(f, rid)
  local k = Recon.known_of(f, rid)
  local out = {}
  if not k then return out end
  if k.hq then out[#out + 1] = { x = k.hq.x, y = k.hq.y, hq = true } end
  for _, e in ipairs(k.posts) do out[#out + 1] = { x = e.x, y = e.y } end
  return out
end

-- Cartes de valeur des sites (script/faction/sites.lua) : seulement les rivales vues.
Sites.rival_points = function(f, rid)
  if not Recon.fog_on() then return nil end
  return Recon.points_of(f, rid)
end

local function stats_of(f)
  f.stats = f.stats or {}
  return f.stats
end

---------------------------------------------------------------------------------------------------
-- Filet : aucune attaque vers un point jamais reconnu
---------------------------------------------------------------------------------------------------
Military.attack_known = function(f, target_faction, tick)
  if target_faction.id == "player" then return true end -- le joueur a son propre regard (script/faction/vision.lua)
  if Recon.attackable(f, target_faction.id, tick) then
    return true, R.age(Recon.known_of(f, target_faction.id), tick)
  end
  local s = stats_of(f)
  s.recon_refused = (s.recon_refused or 0) + 1
  log(string.format("[FO-RECON] refus tick %d %s -> %s : %s, aucune attaque vers ce qu'on n'a pas reconnu (%d refus)", tick, f.key,
    target_faction.key or tostring(target_faction.id), Recon.status(f, target_faction.id, tick), s.recon_refused))
  return false
end

---------------------------------------------------------------------------------------------------
-- Éclaireur soldat
---------------------------------------------------------------------------------------------------
local function state_of(f)
  if not f.recon then f.recon = { next_at = 0, losses = 0, sent = 0, lost = 0, gen_tries = 0 } end
  return f.recon
end

local function scout_busy(f)
  if f.scout_pending then return true end
  for _, gid in ipairs(State.sorted_keys(f.groups or {})) do
    if f.groups[gid].state == "scout" then return true end
  end
  return false
end

local function chunk_ready(surface, p)
  return surface.is_chunk_generated({ x = math.floor(p.x / 32), y = math.floor(p.y / 32) })
end

--- Pensée de reconnaissance (appelée par le commandant après le chef, pour tous les niveaux de difficulté).
function Recon.think(f, surface, tick)
  if not Recon.fog_on() then return end
  local st = f.chef
  if not st then return end
  local rs = state_of(f)
  local ch = Character.of(f)
  local traits = ch.traits or {}
  local req = st.recon
  if not req and tick >= (rs.sweep_at or 0) then req = { kind = "balayage" } end -- reconnaissance régulière, sans besoin précis
  if not req then return end
  local garrison = Military.garrison_near(f)
  local size = R.size(rs.losses, garrison)
  local keep = math.ceil(garrison * (ch.war_keep or ch.keep or 0.3) - 1e-9)
  local ok = R.want({ recon = req, tick = tick, next_at = rs.next_at, busy = scout_busy(f), garrison = garrison, size = size,
    keep = keep, threat = st.last_threat, survive = st.survival, alert = tick < (f.threatened_until or 0) })
  if not ok then return end
  -- Destination : revérifier le dernier point connu (périmée, vieillissante), sinon la frontière de la carte.
  local dest, how
  if (req.kind == "perimee" or req.kind == "vieillissante") and req.x then
    dest, how = { x = req.x, y = req.y }, "reverifier"
  elseif Recon.pick_frontier then
    if req.kind == "balayage" then
      dest, how = Recon.pick_frontier(f, tick, { ring = false, max_dist = R.range(traits.curiosite) }), "balayer"
    else
      dest, how = Recon.pick_frontier(f, tick), "chercher"
    end
  end
  if not dest then
    rs.next_at = tick + NO_DEST_WAIT
    if req.kind == "balayage" then rs.sweep_at = tick + NO_DEST_WAIT end
    return
  end
  -- Le but doit être généré (le chemin d'un soldat ne traverse pas une zone non générée) : on le fait générer et on
  -- attend un peu ; au-delà, le secteur est écarté.
  if not chunk_ready(surface, dest) then
    surface.request_to_generate_chunks(dest, 3)
    rs.gen_tries = (rs.gen_tries or 0) + 1
    if rs.gen_tries >= GEN_TRIES then
      rs.gen_tries = 0
      if Recon.mark_bad then Recon.mark_bad(f, dest.x, dest.y, tick, false) end
      rs.next_at = tick + NO_DEST_WAIT
    else
      rs.next_at = tick + GEN_WAIT
    end
    return
  end
  rs.gen_tries = 0
  local name = F.unit_name(f.key, F.best_soldier(f.tech))
  local q = surface.find_non_colliding_position(name, dest, 24, 2)
  if q then dest = { x = q.x, y = q.y } end
  if Military.scout(f, surface, dest, tick, Recon.TAG, size) then
    local s = stats_of(f)
    s.recon_scouts = (s.recon_scouts or 0) + 1
    rs.sent = rs.sent + 1
    local gap = R.gap(traits.agressivite, rs.losses)
    local sweep_gap = R.sweep_gap(traits.curiosite, st.last_threat, rs.losses)
    -- Un départ de recherche espace les suivants du délai de recherche, et le prochain balayage d'au moins la moitié du sien
    -- (la carte vient d'être regardée) ; un balayage espace tout du sien.
    if req.kind == "balayage" then
      rs.next_at, rs.sweep_at = tick + gap, tick + sweep_gap
      s.recon_sweeps = (s.recon_sweeps or 0) + 1
    else
      rs.next_at, rs.sweep_at = tick + gap, math.max(rs.sweep_at or 0, tick + math.floor(sweep_gap / 2))
    end
    rs.dest = { x = dest.x, y = dest.y }
    log(string.format("[FO-RECON] eclaireur tick %d %s : part vers (%d, %d), %s %s (%s), %d soldat(s), garnison %d", tick, f.key,
      math.floor(dest.x), math.floor(dest.y), how, req.id and label(f, req.id) or "la carte", req.kind, size, garrison))
  else
    rs.next_at = tick + BUSY_WAIT
  end
end

---------------------------------------------------------------------------------------------------
-- Crochets de Military.scout : les éclaireurs de reconnaissance sont traités ici, les autres vont à Vision
---------------------------------------------------------------------------------------------------
local installed = false

--- Appelé une fois par le commandant, APRÈS le chargement de script/faction/vision.lua (qui pose les crochets de base).
function Recon.install()
  if installed then return end
  installed = true
  local prev_done, prev_lost = Military.on_scout_done, Military.on_scout_lost
  Military.on_scout_done = function(f, g, tick, arrived)
    if g.tag ~= Recon.TAG then
      if prev_done then return prev_done(f, g, tick, arrived) end
      return
    end
    local rs = state_of(f)
    local at = g.dest
    if g.group and g.group.valid and not arrived then at = g.group.position end
    if g.nopath then
      -- Aucun chemin : la région autour du but et le cône derrière elle sont écartés (mécanisme du lot EXPLO), le secteur but
      -- aussi (même règle que les éclaireurs ouvriers).
      local s = stats_of(f)
      s.recon_nopath = (s.recon_nopath or 0) + 1
      if at and Recon.note_nopath then
        local o = f.hq_pos
        Recon.note_nopath(f, o.x, o.y, at.x, at.y, tick)
      elseif at and Recon.mark_bad then
        Recon.mark_bad(f, at.x, at.y, tick, false)
      end
      rs.next_at = tick + NO_DEST_WAIT
    elseif at and Recon.watch then
      Recon.watch(f, at.x, at.y, tick)
    end
    if arrived and rs.losses > 0 then rs.losses = rs.losses - 1 end
    log(string.format("[FO-RECON] eclaireur tick %d %s : %s (%d, %d)", tick, f.key,
      g.nopath and "sans itineraire" or (arrived and "arrive" or "arrete"), math.floor(at and at.x or 0), math.floor(at and at.y or 0)))
  end
  Military.on_scout_lost = function(f, g, tick, alive)
    if g.tag ~= Recon.TAG then
      if prev_lost then return prev_lost(f, g, tick, alive) end
      return
    end
    local rs = state_of(f)
    local s = stats_of(f)
    s.recon_lost = (s.recon_lost or 0) + 1
    rs.lost = rs.lost + 1
    if alive < (g.size or 1) then rs.losses = math.min(rs.losses + 1, R.LOSS_CAP) end
    if g.dest and Recon.mark_bad then Recon.mark_bad(f, g.dest.x, g.dest.y, tick, true) end
    rs.next_at = math.max(rs.next_at or 0, tick + R.gap(Character.of(f).traits and Character.of(f).traits.agressivite, rs.losses))
    log(string.format("[FO-RECON] eclaireur tick %d %s : PERDU, %d soldat(s) vivant(s) sur %d, delai x2^%d", tick, f.key, alive,
      g.size or 1, rs.losses))
  end
end

return Recon
