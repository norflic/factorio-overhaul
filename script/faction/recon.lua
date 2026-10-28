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
  - envoie un SOLDAT ÉCLAIREUR (Military.scout, le mécanisme d'IA2-c) quand le chef demande une reconnaissance
    (f.chef.recon : aucune cible reconnue) : vers le dernier point connu d'une rivale périmée, sinon vers la frontière de
    la carte de connaissance de l'équipe (script/ai3/exploration.lua, Recon.pick_frontier : mêmes exclusions que les
    éclaireurs ouvriers). Un soldat seul passe sans combattre ; après une perte, une patrouille plus grosse (R.size) et un
    délai doublé (R.gap, F235).
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
  local req = st.recon
  local garrison = Military.garrison_near(f)
  local size = R.size(rs.losses)
  local ok = R.want({ recon = req, tick = tick, next_at = rs.next_at, busy = scout_busy(f), garrison = garrison, size = size,
    threat = st.last_threat, survive = st.survival })
  if not ok then return end
  -- Destination : revérifier le dernier point connu d'une rivale périmée, sinon la frontière de la carte.
  local dest, how
  if req.kind == "perimee" and req.x then
    dest, how = { x = req.x, y = req.y }, "reverifier"
  elseif Recon.pick_frontier then
    dest, how = Recon.pick_frontier(f, tick), "chercher"
  end
  if not dest then
    rs.next_at = tick + NO_DEST_WAIT
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
    rs.next_at = tick + R.gap(Character.of(f).traits and Character.of(f).traits.agressivite, rs.losses)
    rs.dest = { x = dest.x, y = dest.y }
    log(string.format("[FO-RECON] eclaireur tick %d %s : part vers (%d, %d), %s %s (%s), %d soldat(s), garnison %d", tick, f.key,
      math.floor(dest.x), math.floor(dest.y), how, label(f, req.id), req.kind, size, garrison))
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
      -- Aucun chemin : le secteur but est écarté (même règle que les éclaireurs ouvriers).
      if at and Recon.mark_bad then Recon.mark_bad(f, at.x, at.y, tick, false) end
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
