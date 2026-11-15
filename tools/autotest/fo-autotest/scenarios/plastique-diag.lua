--[[
  Lot PLASTIQUE-0716 : banc de DIAGNOSTIC de la chaîne pétrole -> plastique (partie du DC 0.7.102 x5 : chevalets, raffinerie et usine
  de plastique bâtis, tous à 0/min pendant 40 min, « goulot plastic-bar »). Base : petrole_site_common (technologies de la chaîne du
  pack chimique et kit du site au coffre de chaque faction au tick 300). En plus :
    * tick 60 : un gisement de pétrole (5 puits) posé à ~40 tuiles du QG de chaque faction (le banc court ne trouvait pas le pétrole en
      15 min : « connus [] ») ; la garde anti-dispersion du pétrole (2 colonnes de fonderie, 6 assembleurs : la partie du DC ne l'ouvre
      que vers 56 min) est ouverte par l'interface de banc fo-petrole.bench_garde, le gisement est vu par l'exploration normale ;
    * chaque minute, par faction, une ligne [FO-PLASTIQUE-DIAG] par machine du pétrole (chevalet, raffinerie, usine chimique) : statut,
      recette, énergie (tampon électrique), contenu des boîtes à fluide, inventaire d'entrée et de sortie ; plus les coffres à 3 tuiles
      d'une usine chimique (le quai d'entrée) et le plastique produit (statistiques de la force).
  Lecture : grep « FO-PLASTIQUE-DIAG » dans benchmark.log.
]]
local base = require("scenarios/petrole_site_common")("plastique", 216000)
local MIN = 3600
local TAG = "[FO-PLASTIQUE-DIAG] "
local OIL = { "pumpjack", "oil-refinery", "chemical-plant" }

local function factions()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  local out = {}
  for _, row in ipairs(ok and rows or {}) do if row.key ~= "player" then out[#out + 1] = row end end
  return out
end

local STATUS = nil
local function status_name(e)
  if not STATUS then
    STATUS = {}
    for k, v in pairs(defines.entity_status) do STATUS[v] = k end
  end
  return STATUS[e.status] or tostring(e.status)
end

local function inv_text(inv)
  if not inv then return "-" end
  local c = inv.get_contents()
  local ks = {}
  for k in pairs(c) do ks[#ks + 1] = k end
  table.sort(ks)
  local o = {}
  for _, k in ipairs(ks) do o[#o + 1] = k .. "=" .. c[k] end
  return #o > 0 and table.concat(o, ",") or "vide"
end

local function fluids_text(e)
  local fb = e.fluidbox
  if not fb then return "-" end
  local o = {}
  for i = 1, #fb do
    local f = fb[i]
    o[#o + 1] = f and string.format("%s:%.0f", f.name, f.amount) or "0"
  end
  return table.concat(o, "|")
end

local function oil_patch(s, hq)
  local placed = 0
  for i = 0, 4 do
    for r = 40, 70, 6 do
      local p = { x = math.floor(hq.position.x) + r + i * 4 + 0.5, y = math.floor(hq.position.y) + 0.5 + i * 3 }
      if s.can_place_entity({ name = "crude-oil", position = p }) then
        s.create_entity({ name = "crude-oil", position = p, amount = 600000 })
        placed = placed + 1
        break
      end
    end
  end
  return placed
end

local function diag(ctx, tick)
  local s = ctx.surface()
  for _, row in ipairs(factions()) do
    local f = game.forces[row.force]
    local plast = f and f.item_production_statistics.get_input_count("plastic-bar") or 0
    local gas = f and f.fluid_production_statistics.get_input_count("petroleum-gas") or 0
    local crude = f and f.fluid_production_statistics.get_input_count("crude-oil") or 0
    log(TAG .. string.format("minute=%d equipe=%s plastique=%d gaz=%.0f brut=%.0f", tick / MIN, row.key, plast, gas, crude))
    local ents = s.find_entities_filtered({ name = OIL, force = row.force })
    table.sort(ents, function(a, b) return a.unit_number < b.unit_number end)
    for _, e in ipairs(ents) do
      local r = e.type == "assembling-machine" and e.get_recipe() or nil
      local inp = e.type == "assembling-machine" and e.get_inventory(defines.inventory.assembling_machine_input) or nil
      local out = e.type == "assembling-machine" and e.get_output_inventory() or nil
      local extra = ""
      if e.name == "chemical-plant" then
        local chests = s.find_entities_filtered({ type = "container", position = e.position, radius = 3.5, force = row.force })
        local cs = {}
        for _, c in ipairs(chests) do cs[#cs + 1] = string.format("(%.0f,%.0f):%s", c.position.x, c.position.y, inv_text(c.get_inventory(defines.inventory.chest))) end
        local arms = s.find_entities_filtered({ type = "inserter", position = e.position, radius = 3.5, force = row.force })
        local as = {}
        for _, a in ipairs(arms) do as[#as + 1] = status_name(a) end
        extra = " coffres[" .. table.concat(cs, " ") .. "] bras[" .. table.concat(as, ",") .. "]"
      end
      log(TAG .. string.format("minute=%d equipe=%s %s u%d (%.0f,%.0f) statut=%s recette=%s energie=%.0f fluides=%s entree=%s sortie=%s%s",
        tick / MIN, row.key, e.name, e.unit_number, e.position.x, e.position.y, status_name(e), r and r.name or "-",
        e.energy or 0, fluids_text(e), inv_text(inp), inv_text(out), extra))
    end
  end
end

local tick0 = base.tick
base.description = "PLASTIQUE-DIAG : chaine petrole -> plastique, petrole pose pres du QG, etat des machines chaque minute"
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick == 60 then
    local s = ctx.surface()
    for _, row in ipairs(factions()) do
      local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = row.force, limit = 1 })[1]
      local n = hq and oil_patch(s, hq) or 0
      local okg = pcall(remote.call, "fo-petrole", "bench_garde", row.key, true)
      log(TAG .. "puits de petrole poses equipe=" .. row.key .. " n=" .. n .. " garde anti-dispersion ouverte=" .. tostring(okg))
    end
  end
  if e.tick > 0 and e.tick % MIN == 0 then
    local ok, err = pcall(diag, ctx, e.tick)
    if not ok then log(TAG .. "ERREUR " .. tostring(err)) end
  end
end
return base
