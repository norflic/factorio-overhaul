--[[
  Lot EXPERIMENTAUX (3/11) : outils communs des petits (script/robots/experimentaux.lua) et des géants
  (script/robots/experimentaux_geants.lua) : stockage, comptes, journal [FO-XP], ennemis, dégâts.
  Tous les dégâts passent par `hit` : entity.damage, seulement aux forces ENNEMIES du tireur (force.is_enemy : ni amie, ni en
  cessez-le-feu), comptés par expérimental. Déterminisme : forces triées par nom, candidats triés par la règle pure (Xp.in_radius).
]]

local Storage = require("script.core.storage")
local Xp = require("shared.robots.experimentaux")

local K = {}

Storage.declare("experimentaux", function()
  return { jobs = {}, zones = {}, units = {}, last = {}, fired = {}, stats = {}, journal = false, giants = {}, gjobs = {} }
end)

--- L'espace de stockage du lot ; les champs ajoutés après le palier 1 sont créés à la première lecture (parties déjà commencées).
function K.S()
  local s = Storage.ns("experimentaux")
  if s and not s.giants then s.giants, s.gjobs = {}, {} end
  return s
end

function K.stat(id)
  local s = K.S()
  local st = s.stats[id]
  if not st then
    st = { coups = 0, degats = 0, cibles = 0, tues = 0, sauts = 0, jets = 0 }
    s.stats[id] = st
  end
  return st
end

function K.journal(fmt, ...)
  local s = K.S()
  if s and s.journal then log(Xp.LOG .. " " .. string.format(fmt, ...)) end
end

--- Forces ennemies d'une force (triées par nom).
function K.enemy_forces(force)
  local list = {}
  for _, f in pairs(game.forces) do -- trié juste après
    if f ~= force and force.is_enemy(f) then list[#list + 1] = f.name end
  end
  table.sort(list)
  return list
end

--- Entités ennemies (avec PV) autour d'un point, en candidats { x, y, id, e } (id : numéro d'unité, sinon rang).
function K.candidates(surface, force, pos, radius)
  local forces = K.enemy_forces(force)
  if #forces == 0 then return {} end
  local found = surface.find_entities_filtered({ position = pos, radius = radius, force = forces })
  local out = {}
  for i, e in ipairs(found) do
    if e.valid and e.health and e.destructible then
      out[#out + 1] = { x = e.position.x, y = e.position.y, id = e.unit_number or (1e9 + i), e = e }
    end
  end
  return out
end

--- Dégâts d'un expérimental à une entité ennemie ; rend les dégâts infligés (0 si rien).
--- Forces ennemies d'une force (objet LuaForce ou NOM), par index, mémorisées pour le TICK en cours (table du module, refaite à chaque tick
--- et à chaque chargement : jamais dans global ; même résultat que force.is_enemy, relu une fois par tick et par force qui tire, sans objet
--- LuaForce par cible). Un changement de diplomatie compte dès le tick suivant (décision du lead, 7/11).
local memo_tick, memo = -1, {}
function K.ennemis_du_tick(force)
  local t = game.tick
  if t ~= memo_tick then memo_tick, memo = t, {} end
  local cle = type(force) == "string" and force or force.name
  local en = memo[cle]
  if not en then
    local f = type(force) == "string" and game.forces[force] or force
    en = f and K.ennemis(K.enemy_forces(f)) or {}
    memo[cle] = en
  end
  return en
end
local ennemis_de = K.ennemis_du_tick

function K.hit(r, e, amount, dtype, force, src)
  if not (e and e.valid and e.health and e.destructible) or amount <= 0 then return 0 end
  if not ennemis_de(force)[e.force_index] then return 0 end
  local before = e.health
  -- le moteur refuse un 4e argument nil (« 'entity': table expected, got nil », banc p1-a) : sans tireur, 3 arguments
  local dealt
  if src and src.valid then dealt = e.damage(amount, force, dtype, src) else dealt = e.damage(amount, force, dtype) end
  dealt = dealt or 0
  local st = K.stat(r.id)
  st.degats = st.degats + dealt
  st.cibles = st.cibles + 1
  if before > 0 and (not e.valid or e.health <= 0) then st.tues = st.tues + 1 end
  return dealt
end

--- Coup d'une salve de zone SANS ALLOCATION (revue de la 0.6.57 ; mesure de design-attaques du 7/11 : chaque lecture de `e.force` crée un
--- objet LuaForce, deux par coup avec K.hit, d'où des pics du ramasse-miettes). `st` : la ligne de statistiques (K.stat, lue une fois par
--- pas) ; `force` : le NOM de la force qui tire (ForceIdentification, aucun objet) ; `ennemis` : l'ensemble des index des forces ennemies
--- DU TICK (K.ennemis_du_tick : une paix ou un cessez-le-feu déclaré pendant la salve compte dès le tick suivant). La force de la cible est
--- lue par son index (force_index). Mêmes dégâts, mêmes cibles et mêmes comptes que K.hit.
function K.frappe(st, e, amount, dtype, force, src, ennemis)
  if not (e.valid and e.health and e.destructible) or amount <= 0 or not ennemis[e.force_index] then return 0 end
  local before = e.health
  local dealt
  if src and src.valid then dealt = e.damage(amount, force, dtype, src) else dealt = e.damage(amount, force, dtype) end
  dealt = dealt or 0
  st.degats = st.degats + dealt
  st.cibles = st.cibles + 1
  if before > 0 and (not e.valid or e.health <= 0) then st.tues = st.tues + 1 end
  return dealt
end

--- Index des forces nommées (liste de K.enemy_forces) : ensemble { [index] = vrai }, pour K.frappe.
function K.ennemis(noms)
  local out = {}
  for _, n in ipairs(noms) do
    local f = game.forces[n]
    if f then out[f.index] = true end
  end
  return out
end

--- Dégâts de zone autour d'un point (chute linéaire au bord si `edge` < 1). Rend total, nombre de cibles.
function K.blast(r, surface, force, src, pos, radius, amount, dtype, edge)
  local list = Xp.in_radius(pos, K.candidates(surface, force, pos, radius + 2), radius)
  local total, n = 0, 0
  for _, it in ipairs(list) do
    local d = K.hit(r, it.c.e, Xp.falloff(amount, it.d, radius, edge or 1), dtype, force, src)
    if d > 0 then total, n = total + d, n + 1 end
  end
  return total, n
end

return K
