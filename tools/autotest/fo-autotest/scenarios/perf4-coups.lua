--[[
  Lot PERF4 (tt:repair, critère des 25 %, accord du lead du 7/11) : sur la SAUVEGARDE du DC rejouée telle quelle (banc.py
  --sauvegarde), COMPTE les coups reçus par les tourelles et l'infrastructure électrique des équipes (toutes les forces sauf
  enemy et neutral), par force et par type, et chronomètre le travail qu'un relevé par événement ferait à chaque coup (une
  lecture de force, de type, de numéro et une écriture dans une table). Rien n'est écrit dans le mod : le filtre et le
  gestionnaire sont ceux du mod de TEST (control.lua, PLUGIN.damaged).
  Une ligne « [FO-PERF4-COUPS] » cumulée par minute de jeu depuis le départ ; la dernière donne le total du banc.
  Lancement : banc.py --seul --qui PERF4 --sauvegarde <zip> --out <archive> -- 36000 perf4-coups <source>
]]
local base = require("scenarios/perf4_partie_common")("off")

local TYPES = { "ammo-turret", "electric-turret", "fluid-turret", "electric-pole", "boiler", "generator", "offshore-pump" }
local TURRET = { ["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true }

local S = {
  description = "PERF4 : coups recus par les tourelles et l'infrastructure des equipes (sauvegarde du DC)",
  check_tick = -1,
  damaged_filter = {},
}
for _, t in ipairs(TYPES) do S.damaged_filter[#S.damaged_filter + 1] = { filter = "type", type = t } end

-- Comptes en tables LOCALES (jamais lus par une décision ; perdus à un chargement, inutile ici : un banc ne recharge pas).
local count = {}  -- [force .. " " .. type] = n
local n_t, n_i = 0, 0
local acc, tmp = nil, nil
local sink = {}   -- table d'essai : le travail qu'un relevé par événement ferait

function S.damaged(e)
  local ent = e.entity
  if not (ent and ent.valid) then return end
  if not acc then
    acc = game.create_profiler(true)
    tmp = game.create_profiler(true)
  end
  tmp.restart()
  local fname = ent.force.name
  if fname ~= "enemy" and fname ~= "neutral" then
    local ty = ent.type
    local u = ent.unit_number
    if u and e.final_health > 0 then
      local t = sink[fname]
      if not t then
        t = {}
        sink[fname] = t
      end
      t[u] = ent
    end
    tmp.stop()
    acc.add(tmp)
    local k = fname .. " " .. ty
    count[k] = (count[k] or 0) + 1
    if TURRET[ty] then n_t = n_t + 1 else n_i = n_i + 1 end
  else
    tmp.stop()
  end
end

S.init = function(ctx)
  base.init(ctx)
  S.check_tick = base.check_tick
  ctx.state().debut = game.tick
end

S.tick = function(ctx, e)
  local d = ctx.state().debut
  if not d or e.tick <= d or (e.tick - d) % 3600 ~= 0 then return end
  local keys = {}
  for k in pairs(count) do keys[#keys + 1] = k end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. count[k] end
  local minutes = (e.tick - d) / 3600
  log({ "", string.format("[FO-PERF4-COUPS] %.0f min depuis le depart : tourelles %d coups (%.1f par seconde de jeu), infrastructure %d (%.1f/s) ; travail par evenement cumule ",
    minutes, n_t, n_t / (minutes * 60), n_i, n_i / (minutes * 60)), acc or "0", " ; " .. table.concat(parts, ", ") })
end

S.finish = base.finish
return S
