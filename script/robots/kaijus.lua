--[[
  Lot KAIJUS-MUTANTS (10/11) : la PONTE de l'Écorcheur en jeu (règle pure : shared/robots/titans.lua, T.ECORCHEUR.ponte, T.ponte(era, k)).
  Un Écorcheur d'une ère où la ponte est ouverte (T.kaiju(era, k).ponte) met bas des ÉCORCHÉS quand un ennemi de sa force est à portée
  (ponte.radius) : base + plus_era par ère au-delà de la première, variantes en rotation (T.ponte), au plus ponte.max_vivants enfants vivants
  par Écorcheur, une ponte toutes les ponte.cooldown ticks. Les enfants rejoignent le groupe d'unités du parent (assaut, vague) ou reçoivent
  l'ordre d'attaquer l'ennemi relevé.
  Balayage toutes les SCAN ticks : les Écorcheurs sont relevés par leurs noms (T.kaiju_name, lus aux données) sur chaque surface ; l'état
  (`pontes`, une entrée par Écorcheur vivant : entité, prochain tick, enfants) est une LISTE reconstruite à chaque balayage (aucun pairs,
  aucun ordre de table). Journal [FO-KAIJU], une ligne par ponte. Requis par script/robots/titans.lua (abonnements statiques).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local T = require("shared.robots.titans")
local K = require("script.robots.experimentaux_commun")

local M = {}

Storage.declare("kaijus", function()
  return { pontes = {} }
end)

local function S() return Storage.ns("kaijus") end

local SCAN = 600
M.LOG = "[FO-KAIJU]"

local function journal(fmt, ...)
  local s = K.S()
  if s and s.journal then log(M.LOG .. " " .. string.format(fmt, ...)) end
end

--- Noms des Kaijus dont la ponte est ouverte (toutes ères, tous archétypes), lus à la règle ; calculés une fois au chargement du module.
local NOMS_PONTE = {}
for _, k in ipairs(T.KAIJUS) do
  for era = k.era_min, T.ERAS do
    local j = T.kaiju(era, k)
    if j.ponte then NOMS_PONTE[#NOMS_PONTE + 1] = j.name end
  end
end

function M.noms_ponte() return NOMS_PONTE end

--- Surfaces du jeu dans un ordre stable (index croissant).
local function surfaces()
  local out = {}
  for _, s in pairs(game.surfaces) do out[#out + 1] = s end
  table.sort(out, function(a, b) return a.index < b.index end)
  return out
end

--- Entrée d'un Écorcheur dans la liste (reconstruite à chaque balayage) : celle d'avant si elle existe (par unit_number), sinon neuve.
local function entree(anciennes, e, tick)
  for _, p in ipairs(anciennes) do
    if p.un == e.unit_number then
      p.e = e
      return p
    end
  end
  return { un = e.unit_number, e = e, next = tick, enfants = {} }
end

local function vivants(p)
  local keep = {}
  for _, c in ipairs(p.enfants) do
    if c.valid then keep[#keep + 1] = c end
  end
  p.enfants = keep
  return #keep
end

--- Une ponte : les Écorchés de T.ponte(era) autour du parent, dans son groupe (ou à l'attaque de l'ennemi relevé). Rend le nombre né.
local function pondre(p, j, ennemi, tick)
  local e = p.e
  local s = e.surface
  local groupe = e.unit_group
  local n = 0
  for _, it in ipairs(j.ponte) do
    for _ = 1, it[2] do
      local pos = s.find_non_colliding_position(it[1], e.position, 12, 0.5)
      if pos then
        local c = s.create_entity({ name = it[1], position = pos, force = e.force })
        if c then
          n = n + 1
          p.enfants[#p.enfants + 1] = c
          if groupe and groupe.valid then
            groupe.add_member(c)
          elseif ennemi and ennemi.valid then
            c.set_command({ type = defines.command.attack, target = ennemi, distraction = defines.distraction.by_anything })
          end
        end
      end
    end
  end
  journal("%s #%d ponte %d ecorche(s) en (%.0f, %.0f) tick %d (%d vivants)", j.id, e.unit_number, n, e.position.x, e.position.y, tick, #p.enfants)
  return n
end

local function scan(ev)
  local st = S()
  if not st or #NOMS_PONTE == 0 then return end
  local liste = {}
  for _, s in ipairs(surfaces()) do
    for _, e in ipairs(s.find_entities_filtered({ name = NOMS_PONTE })) do
      if e.valid then
        local p = entree(st.pontes, e, ev.tick)
        liste[#liste + 1] = p
        local k, era = T.kaiju_of_name(e.name)
        local j = k and T.kaiju(era, k)
        if j and j.ponte and ev.tick >= p.next and vivants(p) < k.ponte.max_vivants then
          local ennemi = s.find_nearest_enemy({ position = e.position, max_distance = k.ponte.radius, force = e.force })
          if ennemi then
            pondre(p, j, ennemi, ev.tick)
            p.next = ev.tick + k.ponte.cooldown
          end
        end
      end
    end
  end
  st.pontes = liste
end

--- État pour les bancs : nombre d'Écorcheurs suivis et d'enfants vivants.
function M.etat()
  local st = S()
  local n, enfants = 0, 0
  for _, p in ipairs(st and st.pontes or {}) do
    if p.e and p.e.valid then
      n = n + 1
      enfants = enfants + vivants(p)
    end
  end
  return { ecorcheurs = n, enfants = enfants, noms_ponte = NOMS_PONTE }
end

Events.on_nth_tick(SCAN, scan)

return M
