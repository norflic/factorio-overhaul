--[[
  CONVOYEURS (lot CONVOYEURS, remarque 6 du DC) : le tapis des équipes de PNJ suit la technologie. Règle pure :
  shared/team/convoyeurs.lua. Ce fichier lit les DONNÉES du jeu (prototypes de type transport-belt triés par vitesse, recette
  débloquée pour la force) : aucun nom d'objet écrit ici.

    Conv.choose(f, flow)        tapis d'un nouveau tracé de l'équipe (nil : aucun tapis débloqué, l'appelant garde le sien)
    Conv.step(f, surface, tick) amélioration sur place, en tâche de fond bornée (appelée par Build.think)

  Amélioration : un segment FINI du plan (ligne de rapatriement, tronc du bus, liaison, bande de méga-fonderie, tracé de foreuses)
  dont le tapis se remplit à 60 % au moins (Cs.CFG.min_fill, shared/team/conveyor_scaling.lua) passe au niveau supérieur
  débloqué, Conv.BATCH tuiles par passage toutes les Conv.EVERY ticks (ou dès qu'une passe de scan « recherche » vient d'être
  servie : f.team.scan, lecture seule), dans l'ORDRE de Cs.rank (troncs d'abord) et sous le budget de Cs.budget (le stock de
  tapis cibles), par fast_replace (même groupe : le contenu du tapis reste). Matière : les tapis neufs sortent du stock de
  l'équipe, les anciens y retournent. Le script remplace SANS déplacement de PNJ (la main-d'oeuvre n'est pas comptée) ; sans
  tapis neuf en stock, rien n'est retiré : l'existant continue (Conv.wanted dit lesquels il faudrait fabriquer).
]]

local C = require("shared.team.convoyeurs")
local Cs = require("shared.team.conveyor_scaling") -- lot CONVEYOR-SCALING : ordre (troncs, sorties de fonderie…) et budget de la passe
local Stock = require("script.team.stock")

local Conv = {}

-- "besoin" (défaut, relecture statique) : le plus lent tapis débloqué qui ne sature pas au débit du tracé, donc le tapis d'avant
-- tant que le débit tient ; "meilleur" : le meilleur tapis débloqué (coûte ~8 fois plus, sans gain tant que les gabarits de
-- modules restent bornés sur le tapis jaune, voir le rapport du lot)
Conv.MODE = "besoin"
Conv.EVERY = 1800       -- ticks entre deux passages d'amélioration par équipe
Conv.BATCH = 8          -- tuiles remplacées au plus par passage
Conv.NEW_MIN = 24      -- lot AMELIORATION-CONTINUE : un tapis rapide au stock en cette quantité suffit pour qu'un NOUVEAU tracé le prenne (C.stocked)
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

--- Ce nom est-il un tapis des données ?
function Conv.is_belt(name)
  for _, b in ipairs(Conv.belts()) do if b.name == name then return true end end
  return false
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
--- `len` (lot FIX-P4, facultatif) : longueur du tracé en tuiles ; le tapis rapide « déjà au stock » doit la couvrir.
function Conv.choose(f, flow, len)
  local name = C.stocked(Conv.belts(), Conv.usable(f), function(item) return Stock.count(f, item) end, Conv.NEW_MIN, len)
    or C.pick(Conv.belts(), Conv.usable(f), flow, { need_only = Conv.MODE == "besoin" })
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

---------------------------------------------------------------------------------------------------
-- Lot CONVEYOR-SCALING (directive du DC du 9/11) : l'ordre de la passe vient de la règle pure Cs.rank (troncs du bus, puis sorties de
-- méga-fonderie, puis liaisons, bandes, tracés de foreuses ; à sorte égale le plus saturé d'abord) et de Cs.budget (le stock de tapis
-- cibles) ; la primitive de remplacement (upgrade, fast_replace) ne change pas. Segments lus dans les projets FINIS du plan :
--   « tronc »            ligne de rapatriement (p.spec.rapatriement) ou liaison du bus (p.spec.liaison.bus) : tapis et débit dans la spec ;
--   « liaison »          liaison d'un quai (p.spec.liaison sans bus) ;
--   « sortie-fonderie »  bande d'un champ dont le gisement a une méga-fonderie DÉCIDÉE (f.mega.deps[oid], script/team/mega_fonderie.lua) :
--                        ses tapis (rôle champ-tapis), débit nominal = max(minerai par ligne, plaques par colonne) de la décision ;
--   « bande »            bande d'un champ ordinaire : débit inconnu dans le plan (la bande est dimensionnée à son tapis, Db.belt_pairs),
--                        laissée par Cs.rank (« débit inconnu ») ;
--   « autre »            tracés de foreuses (parts à `belt` et `flow`, l'existant).
-- Le porteur (`holder`) est la table qui tient `belt` et `flow` : la part, la spec de la ligne, ou p.conv (bande ; données seules).
---------------------------------------------------------------------------------------------------

local function speed_of(name)
  for _, b in ipairs(Conv.belts()) do if b.name == name then return b.speed end end
  return nil
end

--- Palier supérieur disponible (nom, vitesse) du tapis `cur`, sans condition de saturation (Cs.rank la juge).
local function next_tier(usable, cur)
  local cs = speed_of(cur)
  if not cs then return nil end
  for _, b in ipairs(Conv.belts()) do
    if b.speed > cs and usable(b.name) then return b.name, b.speed end
  end
  return nil
end

--- Ajoute à `out` le segment du porteur `holder` (belt, flow) du tracé `idx` du projet `p`, de sorte `kind`.
local function add_segment(out, usable, p, idx, holder, kind, lanes)
  local target, tspeed = next_tier(usable, holder.belt)
  out[#out + 1] = { id = p.id, kind = kind, flow = holder.flow, len = remaining(p, idx, holder.belt), lanes = lanes,
    tier_now = speed_of(holder.belt), tier_target = tspeed, item = target and item_of(target) or nil, target = target,
    p = p, idx = idx, holder = holder }
end

--- Bande de champ : porteur p.conv = { belt = le plus LENT de ses tapis, flow } ; sortie de méga-fonderie quand le gisement est décidé.
local function champ_segment(out, f, usable, p)
  local slowest, sp
  for _, e in ipairs(p.ents) do
    if e.role == "champ-tapis" and Conv.is_belt(e.name) then
      local s = speed_of(e.name)
      if s and (not sp or s < sp) then slowest, sp = e.name, s end
    end
  end
  if not slowest then return end
  local rec = f.mega and f.mega.deps and f.mega.deps[p.spec.champ.oid]
  local flow
  if rec and rec.state == "decide" and (rec.lines or 0) > 0 then
    flow = math.max((rec.ore or 0) / rec.lines, (rec.plates or 0) / math.max(1, rec.cols or rec.lines))
  end
  p.conv = p.conv or {}
  p.conv.belt, p.conv.flow = slowest, flow
  add_segment(out, usable, p, 1, p.conv, flow and "sortie-fonderie" or "bande", 2)
end

--- Segments de l'équipe pour Cs.rank, dans l'ordre stable des projets (b.order).
local function segments(f, b, usable)
  local out = {}
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and p.state == "fini" and not p.abandoned then
      for idx = 1, #p.parts do
        local part = p.parts[idx]
        if part.belt and part.flow then add_segment(out, usable, p, idx, part, "autre", 1) end
      end
      local spec = p.spec
      if spec and spec.rapatriement and spec.rapatriement.belt and spec.rapatriement.flow then
        add_segment(out, usable, p, 1, spec.rapatriement, "tronc", 1)
      elseif spec and spec.liaison and spec.liaison.belt and spec.liaison.flow then
        add_segment(out, usable, p, 1, spec.liaison, spec.liaison.bus and "tronc" or "liaison", 1)
      elseif spec and spec.champ and p.ents then
        champ_segment(out, f, usable, p)
      end
    end
  end
  for i, s in ipairs(out) do s.ref = i end -- (Cs.rank rend des copies : `ref` retrouve le segment et son porteur)
  return out
end

--- Réveil au déblocage (lecture seule de f.team.scan, posé par script/team/scan_reveil.lua et servi par hygiene.lua) : vrai UNE fois
--- par passe « recherche » servie (b.conv_served = tick de la dernière passe vue ; donnée, jamais un temps mesuré).
local function woke(f, b)
  local sc = f.team and f.team.scan
  if not (sc and sc.why == "recherche" and sc.served) then return false end
  if b.conv_served == sc.served then return false end
  b.conv_served = sc.served
  return true
end

--- Journal « montée de palier » : une ligne quand le plan (segments payés, manques) change, pas à chaque lot.
local function say_plan(f, b, plan)
  local sig = {}
  for _, s in ipairs(plan.pay) do sig[#sig + 1] = s.kind .. ":" .. tostring(s.id) end
  for _, w in ipairs(plan.short) do sig[#sig + 1] = w.item .. "x" .. w.n end
  local key = table.concat(sig, "|")
  if key == "" or key == b.conv_plan_key then return end
  b.conv_plan_key = key
  log(Cs.line(f.key or "player", plan.pay, plan.short) .. string.format(" a %.1f min", (game.tick or 0) / 3600))
end

function Conv.step(f, surface, tick)
  local b = f.build
  if not b then return end
  local early = woke(f, b)
  if not early and tick < (b.conv_next or 0) then return end
  b.conv_next = tick + Conv.EVERY
  local belts = Conv.belts()
  if #belts < 2 then return end
  local usable = Conv.usable(f)
  local ok = unlocked(f)
  if #ok >= 2 then
    note(f, "debloque", string.format("tapis plus rapide débloqué (%s) ; les nouveaux tracés le prennent dès que leur débit atteint %.1f/s par voie (mode %s), les tracés finis passent au niveau supérieur à ce débit, avec ses tapis au stock",
      table.concat(ok, ", "), C.SATURATION * C.capacity(0.03125), Conv.MODE))
  end
  local segs = segments(f, b, usable)
  local ranked = Cs.rank(segs, Cs.CFG)
  local kit = {}
  for _, s in ipairs(ranked) do if s.item and kit[s.item] == nil then kit[s.item] = Stock.count(f, s.item) end end
  local plan = Cs.budget(ranked, kit, { min_pieces = Conv.BATCH })
  say_plan(f, b, plan)
  if plan.short[1] and not b.conv_wait then b.conv_wait = { item = plan.short[1].item, count = plan.short[1].n } end
  for _, s in ipairs(plan.pay) do
    local seg = segs[s.ref]
    if seg then
      local from = seg.holder.belt
      local n = upgrade(f, surface, seg.p, seg.idx, seg.holder, seg.target)
      if n > 0 then
        log(string.format("[FO-CONVOYEURS] %s : projet %d, tracé %d (%s) : %d tuile(s) %s -> %s (débit %.2f/s, remplissage %d %%)",
          f.key or "player", seg.p.id, seg.idx, s.kind, n, from, seg.target, seg.flow or 0, math.floor((s.fill or 0) * 100 + 0.5)))
        return
      end
    end
  end
end

return Conv
