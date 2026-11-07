--[[
  Lot VALEURS (corr-valeurs, 5/11) : la partie du DC (scénario ageblocage-dc, inchangé : mêmes réglages, mêmes relevés) plus
  une SONDE EN LECTURE SEULE, pour mesurer l'effet des prix de la chaîne du pétrole (module 80 -> 298 MU) :
    - modules posés dans les machines de chaque force (inventaires de modules des fabriques, fours, foreuses, laboratoires,
      balises), par nom de module ;
    - bâtiments faits avec des circuits avancés : entités posées par un objet dont la recette demande, directement ou par ses
      ingrédients, l'objet « advanced-circuit » (fermeture calculée sur les recettes du jeu, une fois, au premier relevé ;
      une entité dont le minage rend un tel objet compte aussi, pour les niveaux posés par script).
  Ligne [FO-VALEURS-DC] sonde min=M force=F modules {nom=n ...} total=N | batiments_ca {nom=n ...} total=N, toutes les 10 min
  (minutes 30, 60 et 150 comprises). Lecture seule : find_entities_filtered et get_module_inventory ne changent rien à la partie,
  les décisions du mod restent celles d'ageblocage-dc (même carte, F238), ce que le lecteur contrôle (première divergence).
  Lancement : banc.py --out <archive> --graine 717152950 --qui VALEURS -- 540000 valeurs-dc <source>
]]

local base = require("scenarios/ageblocage-dc")
local tick0 = base.tick

base.description = "VALEURS : partie du DC (ageblocage-dc) et sonde en lecture seule des modules poses et des batiments a circuits avances"

local AC = "advanced-circuit"
local TYPES = { "assembling-machine", "furnace", "mining-drill", "lab", "beacon", "rocket-silo" }
local probe = nil -- { names = { entités }, modules = { objets module } }, calculé une fois (données du jeu, déterministe)

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function build_probe()
  local recipes = game.recipe_prototypes
  local rnames = sorted_keys(recipes)
  -- Objets qui demandent un circuit avancé, par fermeture sur les recettes (point fixe, ordre des noms).
  local need = { [AC] = true }
  local changed = true
  while changed do
    changed = false
    for _, rn in ipairs(rnames) do
      local r = recipes[rn]
      local uses = false
      for _, ing in ipairs(r.ingredients) do if need[ing.name] then uses = true break end end
      if uses then
        for _, p in ipairs(r.products) do
          if p.type == "item" and not need[p.name] then need[p.name] = true changed = true end
        end
      end
    end
  end
  local names = {}
  for _, it in ipairs(sorted_keys(need)) do
    local ip = game.item_prototypes[it]
    if ip and ip.place_result then names[ip.place_result.name] = true end
  end
  local ents = game.entity_prototypes
  for _, en in ipairs(sorted_keys(ents)) do
    local mp = ents[en].mineable_properties
    for _, p in ipairs((mp and mp.products) or {}) do
      if need[p.name] and ents[en].type ~= "item-entity" then names[en] = true end
    end
  end
  local modules = {}
  for _, it in ipairs(sorted_keys(game.item_prototypes)) do
    if game.item_prototypes[it].type == "module" then modules[#modules + 1] = it end
  end
  return { names = sorted_keys(names), modules = modules }
end

local function teams()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  return ok and rows or {}
end

local function fmt(t)
  local parts, total = {}, 0
  for _, k in ipairs(sorted_keys(t)) do
    if t[k] > 0 then parts[#parts + 1] = k .. "=" .. t[k] total = total + t[k] end
  end
  return "{" .. table.concat(parts, " ") .. "} total=" .. total
end

local function sonde(ctx, tick)
  probe = probe or build_probe()
  local s = ctx.surface()
  for _, row in ipairs(teams()) do
    local force = game.forces[row.force]
    if force then
      local mods = {}
      for _, e in ipairs(s.find_entities_filtered({ force = force, type = TYPES })) do
        local ok, inv = pcall(function() return e.get_module_inventory() end)
        if ok and inv then
          for _, m in ipairs(probe.modules) do
            local n = inv.get_item_count(m)
            if n > 0 then mods[m] = (mods[m] or 0) + n end
          end
        end
      end
      local bat = {}
      if #probe.names > 0 then
        for _, e in ipairs(s.find_entities_filtered({ force = force, name = probe.names })) do
          bat[e.name] = (bat[e.name] or 0) + 1
        end
      end
      ctx.log(string.format("sonde min=%d force=%s modules %s | batiments_ca %s", math.floor(tick / 3600), row.key, fmt(mods), fmt(bat)))
    end
  end
end

base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick > 0 and e.tick % (10 * 3600) == 0 then sonde(ctx, e.tick) end
end

return base
