--[[
  CONVOYEURS (lot CONVOYEURS, remarque 6 du DC) : le tapis des équipes de PNJ suit la technologie. Règle pure :
  shared/team/convoyeurs.lua. Ce fichier lit les DONNÉES du jeu (prototypes de type transport-belt triés par vitesse, recette
  débloquée pour la force) : aucun nom d'objet écrit ici.

    Conv.choose(f, flow)        tapis d'un nouveau tracé de l'équipe (nil : aucun tapis débloqué, l'appelant garde le sien)
    Conv.step(f, surface, tick) amélioration sur place, en tâche de fond bornée (appelée par Build.think)

  Amélioration : un tracé de foreuses FINI dont le tapis sature (débit voulu >= 80 % d'une voie) passe au niveau supérieur
  débloqué, Conv.BATCH tuiles par passage toutes les Conv.EVERY ticks, par fast_replace (même groupe : le contenu du tapis
  reste). Matière : les tapis neufs sortent du stock de l'équipe, les anciens y retournent. Le script remplace SANS
  déplacement de PNJ (la main-d'oeuvre n'est pas comptée) ; sans tapis neuf en stock, rien ne se passe (Conv.wanted dit
  lesquels il faudrait fabriquer).
]]

local C = require("shared.team.convoyeurs")
local Stock = require("script.team.stock")

local Conv = {}

-- "besoin" (défaut, relecture statique) : le plus lent tapis débloqué qui ne sature pas au débit du tracé, donc le tapis d'avant
-- tant que le débit tient ; "meilleur" : le meilleur tapis débloqué (coûte ~8 fois plus, sans gain tant que les gabarits de
-- modules restent bornés sur le tapis jaune, voir le rapport du lot)
Conv.MODE = "besoin"
Conv.EVERY = 1800       -- ticks entre deux passages d'amélioration par équipe
Conv.BATCH = 8          -- tuiles remplacées au plus par passage
Conv.TRIES = 3          -- essais en vain par tuile avant qu'elle soit écartée

local LIST = nil -- cache local (les prototypes ne changent pas dans une session ; jamais dans global)

--- Tapis des données { name, speed, item } triés par vitesse puis nom. Les prototypes cachés ou sans objet sont ignorés.
function Conv.belts()
  if LIST then return LIST end
  local protos = game.get_filtered_entity_prototypes({ { filter = "type", type = "transport-belt" } })
  local names = {}
  for name in pairs(protos) do names[#names + 1] = name end
  table.sort(names)
  local out = {}
  for _, name in ipairs(names) do
    local pr = protos[name]
    local items = pr.items_to_place_this
    if items and items[1] and not pr.has_flag("hidden") then
      out[#out + 1] = { name = name, speed = pr.belt_speed, item = items[1].name }
    end
  end
  LIST = C.sorted(out)
  return LIST
end

--- Prédicat « ce tapis est disponible pour la force de l'équipe » : la recette de son objet est débloquée.
function Conv.usable(f)
  local force = game.forces[f.force]
  local item = {}
  for _, b in ipairs(Conv.belts()) do item[b.name] = b.item end
  return function(name)
    local it = item[name]
    local r = it and force and force.recipes[it]
    return r ~= nil and r.enabled == true
  end
end

local function item_of(name)
  for _, b in ipairs(Conv.belts()) do if b.name == name then return b.item end end
  return nil
end

--- Noms des tapis débloqués pour la force de l'équipe, du plus lent au plus rapide.
local function unlocked(f)
  local usable, out = Conv.usable(f), {}
  for _, b in ipairs(Conv.belts()) do if usable(b.name) then out[#out + 1] = b.name end end
  return out
end

--- Journal [FO-CONVOYEURS], UNE fois par équipe et par sujet (f.build.conv_noted, booléens seuls) : sans lui, une partie où
--- le tapis rapide est débloqué mais où aucun débit n'atteint la saturation d'une voie jaune (6/s) est muette, et l'on ne
--- peut pas distinguer « la règle a tourné et gardé le jaune » de « la règle n'a jamais été appelée » (parties 0.6.13 du
--- 29/10 : logistics-2 terminée par azure à 44,5 min, aucune ligne).
local function note(f, topic, text)
  local b = f.build
  if not b then return end
  b.conv_noted = b.conv_noted or {}
  if b.conv_noted[topic] then return end
  b.conv_noted[topic] = true
  log(string.format("[FO-CONVOYEURS] %s : %s a %.1f min", f.key or "player", text, (game.tick or 0) / 3600))
end

--- Tapis d'un nouveau tracé dont `flow` objets/s passent sur une voie. nil : aucun tapis débloqué.
function Conv.choose(f, flow)
  local name = C.pick(Conv.belts(), Conv.usable(f), flow, { need_only = Conv.MODE == "besoin" })
  if f.build then
    local ok = unlocked(f)
    note(f, "choix", string.format("premier choix de tapis : %s (mode %s, débit voulu %.2f/s sur une voie, un tapis jaune sature à %.1f/s ; débloqués : %s)",
      tostring(name), Conv.MODE, flow or 0, C.SATURATION * C.capacity(0.03125), #ok > 0 and table.concat(ok, ", ") or "aucun"))
  end
  return name
end

--- Objet neuf qu'il faudrait fabriquer pour la prochaine amélioration d'un tracé de l'équipe : { item, count } ou nil
--- (pour le cerveau : pas branché, voir le rapport du lot).
function Conv.wanted(f)
  return f.build and f.build.conv_wait or nil
end

local function remaining(p, idx, name)
  local n = 0
  for _, e in ipairs(p.ents) do
    if e.part == idx and e.name == name and (e.conv_fails or 0) < Conv.TRIES then n = n + 1 end
  end
  return n
end

--- Remplace jusqu'à Conv.BATCH tuiles du tracé `idx` du projet `p` par `target`. Rend le nombre remplacé.
local function upgrade(f, surface, p, idx, part, target)
  local b = f.build
  local new_item, old_item = item_of(target), item_of(part.belt)
  if not (new_item and old_item) then return 0 end
  local sub = {}
  -- tuiles déjà essayées en vain (détruite, remplacement refusé) : écartées après Conv.TRIES essais, sinon elles
  -- occuperaient seules le lot à chaque passage et le tracé ne finirait jamais (relecture statique)
  for _, e in ipairs(p.ents) do
    if e.part == idx and (e.conv_fails or 0) < Conv.TRIES then sub[#sub + 1] = e end
  end
  local done = 0
  for _, i in ipairs(C.next_batch(sub, part.belt, Conv.BATCH)) do
    local e = sub[i]
    if Stock.count(f, new_item) < 1 then
      b.conv_wait = { item = new_item, count = remaining(p, idx, part.belt) }
      break
    end
    local old = surface.find_entity(e.name, { e.x, e.y })
    if old and old.valid and old.force.name == f.force then
      local ne = surface.create_entity({ name = target, position = old.position, direction = old.direction, force = f.force,
        fast_replace = true, spill = false, raise_built = false })
      if ne then
        Stock.remove(f, new_item, 1)
        Stock.insert(f, old_item, 1)
        e.name, e.item = target, new_item
        done = done + 1
      else
        e.conv_fails = (e.conv_fails or 0) + 1
      end
    else
      e.conv_fails = (e.conv_fails or 0) + 1
    end
  end
  if remaining(p, idx, part.belt) == 0 then part.belt = target; b.conv_wait = nil end
  return done
end

function Conv.step(f, surface, tick)
  local b = f.build
  if not b or tick < (b.conv_next or 0) then return end
  b.conv_next = tick + Conv.EVERY
  local belts = Conv.belts()
  if #belts < 2 then return end
  local usable = Conv.usable(f)
  local ok = unlocked(f)
  if #ok >= 2 then
    note(f, "debloque", string.format("tapis plus rapide débloqué (%s) ; les nouveaux tracés le prennent dès que leur débit atteint %.1f/s par voie (mode %s), les tracés finis passent au niveau supérieur à ce débit, avec ses tapis au stock",
      table.concat(ok, ", "), C.SATURATION * C.capacity(0.03125), Conv.MODE))
  end
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and p.state == "fini" then
      for idx = 1, #p.parts do
        local part = p.parts[idx]
        if part.belt and part.flow then
          local target = C.upgrade_target(belts, usable, part.belt, part.flow)
          if target then
            local from = part.belt
            local n = upgrade(f, surface, p, idx, part, target)
            if n > 0 then
              log(string.format("[FO-CONVOYEURS] %s : projet %d, tracé %d : %d tuile(s) %s -> %s (débit %.2f/s sur une voie)",
                f.key or "player", p.id, idx, n, from, target, part.flow))
              return
            end
          end
        end
      end
    end
  end
end

return Conv
