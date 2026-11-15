--[[
  Lot DEFENSE-FACTIONS (16/11) : MURS DEVANT LES TOURELLES DE GARDE d'une cible attaquée par une autre équipe.
  Mesure (fo-logs/2026-11-15_defense-longue-1, votre équipe, carte du DC) : les tourelles de garde de la centrale lointaine tombent sous des
  groupes de 12 mitrailleurs d'amber (portée 10,4 contre 18) à 88,8-98,3 min, deux fois aux mêmes places ; rien ne les couvre.

  Chaîne : une TOURELLE d'une équipe est tuée par une AUTRE ÉQUIPE (MG.note, appelé par script/team/front.lua à on_died, mêmes filtres :
  pièce de l'équipe, tueur sans cessez-le-feu) -> la place est notée avec le côté d'où venait le tueur (axe dominant du vecteur tueur -> tourelle,
  aucune trigonométrie) -> MG.step (toutes MG.EVERY ticks) demande au plan directeur un SEGMENT DE MUR droit de MG.LEN tuiles, à MG.GAP tuiles
  de la tourelle, face au tueur : projet « enceinte » de script/team/build.lua (même machinerie que les murs des îlots : spec.ilot + spec.walls,
  murs fabriqués au coffre depuis leur recette, tuiles de ressource, d'eau, réservées ou de couloir sautées).
  Un mur par place au plus toutes les MG.COOLDOWN ticks ; MG.MAX segments demandés par équipe. Le mur est le prototype T.wall de la config
  (shared/team/config.lua) ; sans recette ouverte, rien n'est demandé.

  État : f.murs_garde = { pend = { { key, tx, ty, side } }, done = { [key] = tick }, n, logs } (nombres et chaînes ; créé en événement,
  jamais à on_load). Lecteurs : MG.step (ici). Journal : « [FO-DEFENSE] mur » (demande, refus avec sa cause).
]]
local Events = require("script.core.events")
local State = require("script.faction.state")
local T = require("shared.team.config")

local MG = {}

MG.EVERY = 600       -- ticks : une demande en attente est traitée au plus toutes les 10 s
MG.COOLDOWN = 36000  -- ticks (10 min) : un seul mur par place de tourelle dans ce délai
MG.MAX = 24          -- segments demandés au plus par équipe
MG.LEN = 7           -- tuiles du segment (centré sur l'axe de la tourelle)
MG.GAP = 3           -- tuiles entre le centre de la tourelle et le mur
MG.LOGS = 60

local function state(f)
  local s = f.murs_garde
  if not s then s = { pend = {}, done = {}, n = 0, logs = 0 } f.murs_garde = s end
  return s
end

local function say(f, s, text)
  if s.logs >= MG.LOGS then return end
  s.logs = s.logs + 1
  log(text)
end

--- Tuiles du segment devant la tourelle (tx, ty : tuile de son centre), côté `side` ("E", "O", "S", "N") : liste { {x, y} }.
function MG.tiles(tx, ty, side)
  local out, h = {}, math.floor(MG.LEN / 2)
  for i = -h, h do
    if side == "E" then out[#out + 1] = { tx + MG.GAP, ty + i }
    elseif side == "O" then out[#out + 1] = { tx - MG.GAP, ty + i }
    elseif side == "S" then out[#out + 1] = { tx + i, ty + MG.GAP }
    else out[#out + 1] = { tx + i, ty - MG.GAP } end
  end
  return out
end

--- Côté du tueur vu de la tourelle (axe dominant ; égalité : l'axe x).
function MG.side(dx, dy)
  if math.abs(dx) >= math.abs(dy) then return dx >= 0 and "E" or "O" end
  return dy >= 0 and "S" or "N"
end

--- Tourelle `ent` de l'équipe `f` tuée par une autre équipe (évènement `e`, cause éventuelle).
function MG.note(f, ent, e)
  if not (ent.prototype and ent.prototype.turret_range) then return end -- tourelles seulement (portée lue au prototype)
  local cause = e.cause and e.cause.valid and e.cause or nil
  if not cause then return end
  local p, c = ent.position, cause.position
  local tx, ty = math.floor(p.x), math.floor(p.y)
  local side = MG.side(c.x - p.x, c.y - p.y)
  local key = tx .. ":" .. ty .. ":" .. side
  local s = state(f)
  if s.done[key] and e.tick - s.done[key] < MG.COOLDOWN then return end
  for _, q in ipairs(s.pend) do if q.key == key then return end end
  s.pend[#s.pend + 1] = { key = key, tx = tx, ty = ty, side = side }
end

local function step(ev)
  local tick = ev.tick
  local build = package.loaded["script.team.build"] -- (chargé par le reste du mod ; pas de require dans un évènement)
  if not build then return end
  local teams = {}
  local pt = State.faction("player")
  if pt then teams[#teams + 1] = pt end
  for _, id in ipairs(State.alive()) do teams[#teams + 1] = State.faction(id) end
  for _, f in ipairs(teams) do
    local s = f.murs_garde
    if s and #s.pend > 0 and not f.eliminated then
      local q = table.remove(s.pend, 1)
      local fo = game.forces[f.force]
      local rec = fo and fo.recipes[T.wall]
      if s.n >= MG.MAX then
        say(f, s, string.format("[FO-DEFENSE] mur %s : place %s non muree (plafond de %d segments) a %.1f min", f.key or "player", q.key, MG.MAX, tick / 3600))
      elseif not (rec and rec.enabled) then
        say(f, s, string.format("[FO-DEFENSE] mur %s : place %s non muree (recette du mur fermee) a %.1f min", f.key or "player", q.key, tick / 3600))
      else
        local tiles = MG.tiles(q.tx, q.ty, q.side)
        local id, why = build.request(f, { enceinte = true, ilot = "garde " .. q.key, walls = tiles, side = q.side, prio = (build.PRIO or 55) + 6,
          domain = "infrastructures" })
        s.done[q.key] = tick
        if id then s.n = s.n + 1 end
        say(f, s, string.format("[FO-DEFENSE] mur %s : tourelle tuee par une autre equipe en (%d, %d) : segment de %d murs cote %s %s a %.1f min (%d segment(s))",
          f.key or "player", q.tx, q.ty, #tiles, q.side, id and ("demande (projet " .. id .. ")") or ("refuse (" .. tostring(why) .. ")"), tick / 3600, s.n))
      end
    end
  end
end
Events.on_nth_tick(MG.EVERY, step)

return MG
