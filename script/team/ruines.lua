--[[
  Lot REBUILD-AVANT-POSTE : exécutant de la RUINE d'un avant-poste de ressource perdu en entier (règles pures : shared/team/ruines.lua).

  CHAÎNE (retour du DC, 29/10 : « reconstruire IMPÉRATIVEMENT tous les bâtiments détruits ») :
    la dernière foreuse meurt  -> Outposts.on_drill_lost (script/faction/outposts.lua) appelle Ruines.on_total_loss ;
    les pièces de l'avant-poste sont déjà au registre (Recon on_died : foreuses et réceptacles avec leur oid) -> la RUINE en garde l'en-tête
      (f.recon.ruins[oid]) et le site perdu est marqué « à refaire en place » (Sites.note_lost, drapeau keep : pas de pénalité de valeur
      pour CE champ, shared/faction/valeur.lua) ;
    Recon.think ne jette plus les pièces de l'avant-poste disparu tant que la ruine vit (Ruines.keeps) ;
    la tâche « rebuild » (ennemi absent, objets au stock) -> Recon.act pose la première foreuse -> Ruines.recreate RECRÉE l'enregistrement
      f.outposts[oid] (réceptacles restés sur place et tourelles survivantes repris, site revendiqué de nouveau) ;
    effet visible : le champ de foreuses et de fours est remis en place, les ouvriers le ravitaillent et en collectent la production.
  Lecteurs de chaque état écrit : f.recon.ruins[oid] -> Ruines.keeps / Ruines.step / Ruines.recreate (ici) ; f.lost_sites[*].keep ->
  V.components (valeur.lua) ; f.outposts[oid] recréé -> tout le reste de l'exécutant (service, extension, foreuse_swap, soldats).

  Rien n'est nouveau dans la sauvegarde sauf f.recon.ruins (tables simples, créé en événement, lu avec garde si absent).
  Déterminisme : listes triées, aucun temps mesuré.
]]

local State = require("script.faction.state")
local Sites = require("script.faction.sites")
local T = require("shared.team.config")
local Ru = require("shared.team.ruines")

local Ruines = {}

Ruines.LOGS = 30

local function sorted_keys(t) return State.sorted_keys(t or {}) end

local function note(f, s, what, ...)
  s.stats = s.stats or {}
  s.stats.ruin_logs = (s.stats.ruin_logs or 0) + 1
  if s.stats.ruin_logs <= Ruines.LOGS then
    log(string.format("[FO-RUINE] %s : " .. what, f.key or "player", ...))
  end
end

--- Pièces refaisables de l'avant-poste `oid` au registre (foreuses et réceptacles, non abandonnés, objet connu).
local function pending_of(s, oid)
  local n = 0
  for _, k in ipairs(sorted_keys(s.lost)) do
    local r = s.lost[k]
    if r.kind and r.oid == oid and not r.abandoned and r.item then n = n + 1 end
  end
  return n
end

--- La ruine de l'avant-poste `oid` vit-elle ? (lu par Recon.think avant de jeter une pièce d'avant-poste disparu)
function Ruines.keeps(s, oid)
  return s ~= nil and s.ruins ~= nil and s.ruins[oid] ~= nil
end

--- Avant-poste perdu en entier (dernière foreuse détruite). Rend vrai si une ruine garde le plan (le site est « à refaire en place »).
--- Sans foreuse au registre (retrait à la main, destruction sans mort), rien à refaire : faux, comportement d'avant.
function Ruines.on_total_loss(f, o, tick)
  local s = f.recon
  if not (s and s.lost and o and o.id) then return false end
  local n = pending_of(s, o.id)
  -- au moins UNE foreuse au registre : c'est la foreuse qui recrée l'avant-poste (un réceptacle seul ne le peut pas)
  local drills = 0
  for _, k in ipairs(sorted_keys(s.lost)) do
    local r = s.lost[k]
    if r.kind == "drill" and r.oid == o.id and not r.abandoned and r.item then drills = drills + 1 end
  end
  if drills == 0 then return false end
  s.ruins = s.ruins or {}
  s.ruins[o.id] = { oid = o.id, kind = o.kind, x = o.pos.x, y = o.pos.y, tick = tick, site_info = o.site_info, pieces = n }
  s.stats = s.stats or {}
  s.stats.ruined = (s.stats.ruined or 0) + 1
  note(f, s, "avant-poste %d (%s) perdu en entier en (%.0f, %.0f) a %.1f min : %d piece(s) gardee(s) au registre, a refaire en place", o.id,
    tostring(o.kind), o.pos.x, o.pos.y, tick / 3600, n)
  return true
end

local function lives(f)
  local list = {}
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    list[#list + 1] = { kind = o.kind, x = o.pos.x, y = o.pos.y }
  end
  return list
end

--- Lâche la ruine : les pièces suivent la règle d'avant (jetées par Recon.think), le drapeau « à refaire en place » du site perdu tombe
--- (la pénalité de valeur reprend pour le reste de ses 30 min si le champ n'a pas été refait).
function Ruines.drop(f, s, oid, why, tick)
  local x = s.ruins and s.ruins[oid]
  if not x then return end
  s.ruins[oid] = nil
  for _, l in ipairs(f.lost_sites or {}) do
    if l.keep == oid then l.keep = nil end
  end
  s.stats = s.stats or {}
  local key = "ruin_" .. why
  s.stats[key] = (s.stats[key] or 0) + 1
  note(f, s, "ruine de l'avant-poste %d lachee (%s) a %.1f min, %.1f min apres la perte", oid, why, tick / 3600, (tick - x.tick) / 3600)
end

--- Une pensée de l'équipe : verdict de chaque ruine.
function Ruines.step(f, s, tick)
  if not (s.ruins and next(s.ruins)) then return end
  local war = State.war()
  for _, oid in ipairs(sorted_keys(s.ruins)) do
    local x = s.ruins[oid]
    local owner = war and war.claims and war.claims[State.site_key(x)]
    local verdict, why = Ru.verdict(x, { tick = tick, record = f.outposts[oid] ~= nil, pending = pending_of(s, oid), live = lives(f),
      rival = owner ~= nil and owner ~= f.id })
    if verdict == "lache" then Ruines.drop(f, s, oid, why, tick) end
  end
end

--- Recrée l'enregistrement de l'avant-poste `oid` (appelé juste avant la pose de la première foreuse de la ruine). Rend l'enregistrement,
--- ou nil si la ruine n'existe plus ou vient d'être lâchée (champ déjà refait, site pris par une autre équipe).
function Ruines.recreate(f, oid, tick)
  local s = f.recon
  local x = s and s.ruins and s.ruins[oid]
  if f.outposts[oid] then return f.outposts[oid] end
  if not x then return nil end
  local war = State.war()
  local owner = war and war.claims and war.claims[State.site_key(x)]
  if owner ~= nil and owner ~= f.id then Ruines.drop(f, s, oid, "rival", tick) return nil end
  local verdict, why = Ru.verdict(x, { tick = tick, record = false, pending = 1, live = lives(f) })
  if verdict == "lache" then Ruines.drop(f, s, oid, why, tick) return nil end
  local o = {
    id = oid, kind = x.kind, pos = { x = x.x, y = x.y }, drills = 0, drill_list = {}, sinks = {}, turret_list = {}, last_service = tick,
    site_info = x.site_info, revived = tick,
  }
  -- Réceptacles restés sur la carte : repris (ils attendaient d'être démontés), à leur place, avec leur contenu.
  local keep = {}
  for _, orph in ipairs(f.orphans or {}) do
    if orph.oid == oid and orph.e and orph.e.valid then
      State.own(orph.e, f.id, "sink", oid)
      o.sinks[#o.sinks + 1] = orph.e
    else
      keep[#keep + 1] = orph
    end
  end
  if f.orphans then f.orphans = keep end
  -- Tourelles survivantes de l'avant-poste (propriété conservée à la perte) : de nouveau dans sa liste.
  for _, id in ipairs(sorted_keys(f.turrets)) do
    local t = f.turrets[id]
    local ow = t and t.valid and State.owner(id)
    if ow and ow.oid == oid then o.turret_list[#o.turret_list + 1] = t end
  end
  f.outposts[oid] = o
  f.outposts_count = (f.outposts_count or 0) + 1
  -- Le site est de nouveau le nôtre : la réserve ne le redonne pas (Sites.find écarte un site revendiqué).
  local spec = T.outposts[x.kind]
  Sites.claim(f, { x = x.x, y = x.y, resource = spec and spec.resource or nil })
  f.stats.outposts_revived = (f.stats.outposts_revived or 0) + 1
  s.stats = s.stats or {}
  s.stats.revived = (s.stats.revived or 0) + 1
  x.revived = tick
  note(f, s, "avant-poste %d (%s) recree en (%.0f, %.0f) a %.1f min, %.1f min apres la perte (%d receptacle(s) repris)", oid, tostring(x.kind),
    x.x, x.y, tick / 3600, (tick - x.tick) / 3600, #o.sinks)
  return o
end

--- La foreuse censée recréer l'avant-poste n'a pas pu être posée : l'enregistrement sans foreuse est retiré (aucun avant-poste fantôme).
function Ruines.undo(f, oid)
  local o = f.outposts[oid]
  local s = f.recon
  local x = s and s.ruins and s.ruins[oid]
  if not (o and o.revived and (o.drills or 0) <= 0) then return false end
  f.outposts[oid] = nil
  f.outposts_count = math.max(0, (f.outposts_count or 1) - 1)
  Sites.release(o.pos)
  -- Les réceptacles repris retournent à la liste des orphelins (démontage ordinaire).
  f.orphans = f.orphans or {}
  for _, e in ipairs(o.sinks or {}) do
    if e.valid then f.orphans[#f.orphans + 1] = { e = e, x = o.pos.x, y = o.pos.y, tick = x and x.tick or 0, oid = oid } end
  end
  if x then x.revived = nil end
  f.stats.outposts_revived = math.max(0, (f.stats.outposts_revived or 1) - 1)
  return true
end

return Ruines
