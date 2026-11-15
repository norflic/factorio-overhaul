--[[
  Lot POTEAU-CHANTIER (0716) : preuve du repli des poteaux d'un CHANTIER. Partie de plastique-diag (60 min, technos et kit du site au
  tick 300) ; jusqu'à DRY_MIN, l'acier et le poteau moyen sont retirés des coffres du QG de chaque faction toutes les 10 s (pénurie d'acier,
  comme « manque medium-electric-pole 26 » en 0.7.122) : le site du pétrole, planifié en poteaux moyens (recette ouverte), attend en réserve.
  Attendu : [FO-POTEAU-CHANTIER] « ... remplace(s) par ... » puis le site passe en chantier et fini ; ligne [FO-POTEAU-CHANTIER-BANC] chaque
  minute : état des sites du pétrole de chaque faction (interface fo-petrole.status).
  Les noms d'objets sont ceux du jeu de base : fichier de TEST (iag_test §8 ne lit que le cerveau).
]]
local base = require("scenarios/plastique-diag")
local MIN = 3600
local DRY_MIN = 40
local TAG = "[FO-POTEAU-CHANTIER-BANC] "
local DRY = { "steel-plate", "medium-electric-pole" }

local function factions()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  local out = {}
  for _, row in ipairs(ok and rows or {}) do if row.key ~= "player" then out[#out + 1] = row end end
  return out
end

local REMOVED = {}
local function dry(ctx)
  local s = ctx.surface()
  for _, row in ipairs(factions()) do
    for _, hq in ipairs(s.find_entities_filtered({ name = { "fo-faction-hq", "fo-team-chest" }, force = row.force })) do
      local inv = hq.get_inventory(defines.inventory.chest)
      for _, it in ipairs(DRY) do
        local n = inv and inv.remove({ name = it, count = 100000 }) or 0
        REMOVED[row.key] = (REMOVED[row.key] or 0) + n
      end
    end
  end
end

local function watch(tick)
  for _, row in ipairs(factions()) do
    local ok, st = pcall(remote.call, "fo-petrole", "status", row.key)
    local sites = {}
    for _, x in ipairs((ok and st and st.sites) or {}) do
      sites[#sites + 1] = string.format("%s:%s(%s/%s)%s", x.key, tostring(x.state), tostring(x.built), tostring(x.total),
        (x.missing and #x.missing > 0) and ("{" .. table.concat(x.missing, ",") .. "}") or "")
    end
    log(TAG .. string.format("minute=%d equipe=%s retires=%d sites[%s]", tick / MIN, row.key, REMOVED[row.key] or 0, table.concat(sites, " ")))
  end
end

local tick0 = base.tick
base.description = "POTEAU-CHANTIER : plastique-diag, acier et poteaux moyens retires du QG jusqu'a " .. DRY_MIN .. " min"
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick > 300 and e.tick <= DRY_MIN * MIN and e.tick % 600 == 1 then
    local ok, err = pcall(dry, ctx)
    if not ok then log(TAG .. "ERREUR " .. tostring(err)) end
  end
  if e.tick > 0 and e.tick % MIN == 20 then
    local ok, err = pcall(watch, e.tick)
    if not ok then log(TAG .. "ERREUR " .. tostring(err)) end
  end
end
return base
