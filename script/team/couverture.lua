--[[
  Lot COUVERTURE, exécutant : choisit où poser les tourelles d'un avant-poste ou du QG (règle pure : shared/team/couverture.lua).

  Ce que le moteur donne :
    - les BÂTIMENTS de l'équipe à moins de Couv.RADIUS tuiles du centre (find_entities_filtered, force de l'équipe), valeur
      par RÔLE du type (shared/ai3/reglages.lua : R.ENTITY_ROLE ; les lignes de tapis, poteaux et tuyaux, R.PASSIVE_TYPES, ne
      comptent pas) ; le coffre d'équipe vaut Cov.CHEST_VALUE ;
    - la PORTÉE de la tourelle, lue au prototype (turret_range) : aucune portée écrite ici ;
    - les tourelles DÉJÀ posées de l'équipe (f.turrets) autour du centre ;
    - les MENACES connues : carte du danger de l'équipe (nids, vers, morts récentes ; script/ai3/comportement.lua la tient,
      lue ici dans son espace de sauvegarde sans l'exiger : il exige l'ouvrier, qui exige les avant-postes) et les bâtiments
      détruits récemment (f.recon.hits, script/team/reconstruction.lua).
  Épreuve de chaque position par le moteur (can_place_entity) ; au plus Couv.MAX_TRIES épreuves par pose.
  Aucun nom du jeu : la tourelle est R.TURRET, les rôles viennent du moteur.
]]

local Storage = require("script.core.storage")
local State = require("script.faction.state")
local R = require("shared.ai3.reglages")
local Cov = require("shared.team.couverture")

local Couv = {}

Couv.RADIUS_HQ = 45     -- tuiles : bâtiments pris en compte autour du QG
Couv.RADIUS_OUT = 24    -- tuiles : autour d'un avant-poste
Couv.MAX_TRIES = 400    -- épreuves du moteur au plus par pose
Couv.LOGS = 60          -- lignes de journal [FO-COUV] au plus par équipe

local RANGE = {}        -- mémoire LOCALE (prototypes seulement), jamais dans global
local function range_of(name)
  local r = RANGE[name]
  if r == nil then
    local p = game.entity_prototypes[name]
    r = p and p.turret_range or 0
    RANGE[name] = r
  end
  return r
end

local function danger_map(f)
  local ok, t = pcall(function() return Storage.ns("ia3k").teams[tostring(f.id)] end)
  return ok and t and t.map or nil
end

--- Bâtiments à protéger autour de `center` : { {x, y, v} }.
local function gather_assets(f, surface, center, radius)
  local types = {}
  for _, ty in ipairs(R.ENTITY_TYPES) do
    if not R.PASSIVE_TYPES[ty] and Cov.role_value(R.ENTITY_ROLE[ty]) > 0 then types[#types + 1] = ty end
  end
  local out = {}
  local hq_n = f.hq and f.hq.valid and f.hq.unit_number
  -- le coffre d'équipe (conteneur du QG) : type de l'entité f.hq
  local list = surface.find_entities_filtered({ position = center, radius = radius, force = f.force, type = types })
  for _, e in ipairs(list) do
    local v = Cov.role_value(R.ENTITY_ROLE[e.type])
    if hq_n and e.unit_number == hq_n then v = Cov.CHEST_VALUE end
    if v > 0 then out[#out + 1] = { x = e.position.x, y = e.position.y, v = v } end
  end
  -- Le coffre d'équipe, même s'il n'est pas d'un type de la liste.
  if hq_n and f.hq.valid then
    local p, near = f.hq.position, false
    for _, a in ipairs(out) do if a.x == p.x and a.y == p.y then near = true break end end
    if not near and (p.x - center.x) ^ 2 + (p.y - center.y) ^ 2 <= radius * radius then
      out[#out + 1] = { x = p.x, y = p.y, v = Cov.CHEST_VALUE }
    end
  end
  return out
end

local function own_turrets(f, center, reach)
  local out = {}
  local r2 = reach * reach
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t and t.valid then
      local dx, dy = t.position.x - center.x, t.position.y - center.y
      if dx * dx + dy * dy <= r2 then out[#out + 1] = { x = t.position.x, y = t.position.y } end
    end
  end
  return out
end

--- Prépare le choix des positions autour de `center` ({x, y}). `is_hq` : centre = le QG. Rend l'état du choix (pour
--- Couv.next) ou nil (rien à protéger, portée inconnue : l'appelant garde ses positions de repli).
function Couv.plan(f, surface, center, is_hq, radius_override)
  local range = range_of(R.TURRET)
  if range <= 0 then return nil end
  local radius = radius_override or (is_hq and Couv.RADIUS_HQ or Couv.RADIUS_OUT)
  local assets = gather_assets(f, surface, center, radius)
  if #assets == 0 then return nil end
  local turrets = own_turrets(f, center, radius + 2 * range)
  local tick = game.tick
  local hits = f.recon and f.recon.hits or nil
  local threats = Cov.threat_points(danger_map(f), hits, tick)
  local st = Cov.new({ assets = assets, range = range, turrets = turrets, threats = threats })
  st.tries = 0
  st.n_assets, st.n_threats, st.n_before = #assets, #threats, #turrets
  st.assets, st.before = assets, turrets
  st.center, st.is_hq = center, is_hq or false
  st.name = R.TURRET
  return st
end

--- Prochaine position libre (épreuve du moteur) : { x, y } ou nil (plus de candidat ou plus d'épreuves).
function Couv.next(st, f, surface)
  if st.tries >= Couv.MAX_TRIES then return nil end
  local p = Cov.next(st, function(x, y)
    if st.tries >= Couv.MAX_TRIES then return false end
    st.tries = st.tries + 1
    return surface.can_place_entity({ name = st.name, position = { x = x, y = y }, force = f.force })
  end)
  return p
end

--- Journal de la pose : valeur couverte avant et après, écart minimal entre tourelles.
function Couv.report(f, st, placed, fallback, label)
  f.stats = f.stats or {}
  f.stats.couv_placed = (f.stats.couv_placed or 0) + placed
  f.stats.couv_fallback = (f.stats.couv_fallback or 0) + fallback
  f.stats.couv_logs = (f.stats.couv_logs or 0) + 1
  if f.stats.couv_logs > Couv.LOGS then return end
  local after = {}
  for _, t in ipairs(st.turrets) do after[#after + 1] = t end
  local gap = Cov.min_gap(after)
  log(string.format("[FO-COUV] %s %s en (%.0f, %.0f) : %d tourelle(s) posee(s) par couverture, %d de repli ; %d batiment(s), %d menace(s), %d tourelle(s) deja la ; valeur couverte %.0f %% -> %.0f %% ; ecart minimal %s tuile(s) ; %d epreuve(s) du moteur",
    f.key or "player", label, st.center.x, st.center.y, placed, fallback, st.n_assets, st.n_threats, st.n_before,
    100 * Cov.covered_fraction(st.assets, st.before, st.range),
    100 * Cov.covered_fraction(st.assets, after, st.range), gap and string.format("%.1f", gap) or "-", st.tries))
end

-- Interface de LECTURE pour les bancs (tools/autotest/fo-autotest/scenarios/couverture-prev.lua) : les positions que la
-- couverture proposerait autour de (x, y) pour les bâtiments de la force `force_name`, avec les épreuves du moteur ; RIEN n'est posé.
remote.add_interface("fo-couverture", {
  preview = function(force_name, x, y, count, radius)
    local surface = game.surfaces["nauvis"]
    if not (surface and game.forces[force_name] and type(x) == "number" and type(y) == "number" and type(count) == "number") then return nil end
    local f = { force = force_name, id = "banc", key = "banc", turrets = {}, stats = {} }
    local st = Couv.plan(f, surface, { x = x, y = y }, true, radius)
    if not st then return { positions = {}, assets = 0, range = range_of(R.TURRET) } end
    local out = {}
    for _ = 1, count do
      local p = Couv.next(st, f, surface)
      if not p then break end
      out[#out + 1] = { x = p.x, y = p.y, gain = p.gain, relaxed = p.relaxed }
    end
    local after = {}
    for _, t in ipairs(st.turrets) do after[#after + 1] = t end
    local gap = Cov.min_gap(after)
    return { positions = out, assets = st.n_assets, threats = st.n_threats, range = st.range, tries = st.tries, gap = gap,
      covered = Cov.covered_fraction(st.assets, after, st.range), cover_pct = Cov.COVER_PCT }
  end,
})

return Couv
