--[[ Lot s44 reparation : câblage de la règle « secteur sous attaque, sans couverture » (shared/team/secteur_attaque.lua).
  Mémoire : f.secteur_attaque (tables simples, dans la sauvegarde). Notée par on_died de script/team/reconstruction.lua ; lue par le
  relevé (script/team/rebuild_sweep.lua) et le registre (script/team/reconstruction.lua) avant d'envoyer un ouvrier.
]]

local Sa = require("shared.team.secteur_attaque")

local SaRt = {}

local TURRET_LIST = { "ammo-turret", "electric-turret", "fluid-turret" }
local COVER_SCAN = 48 -- tuiles : rayon de recherche des tourelles (au-delà de la plus longue portée courante)

local function mem_of(f)
  local m = f.secteur_attaque
  if not m then m = Sa.new() f.secteur_attaque = m end
  return m
end

--- Une pièce de l'équipe vient de mourir en `pos`.
function SaRt.note(f, pos, tick)
  local m = mem_of(f)
  Sa.prune(m, tick)
  Sa.note(m, pos.x, pos.y, tick)
end

local function turret_view(t)
  local kind = t.type
  local ammo, energy, fluid = 0, 0, 0
  if kind == "ammo-turret" then
    local inv = t.get_inventory(defines.inventory.turret_ammo)
    ammo = inv and inv.get_item_count() or 0
  elseif kind == "electric-turret" then
    energy = t.energy or 0
  elseif kind == "fluid-turret" then
    local fb = t.fluidbox and t.fluidbox[1]
    fluid = fb and fb.amount or 0
  end
  local ap = t.prototype.attack_parameters
  return { x = t.position.x, y = t.position.y, range = ap and ap.range or 0, active = Sa.turret_active(kind, ammo, energy, fluid) }
end

--- Une tourelle active de l'équipe atteint-elle (x, y) ?
function SaRt.covered(f, surface, x, y)
  local list = surface.find_entities_filtered({ position = { x, y }, radius = COVER_SCAN, type = TURRET_LIST, force = f.force })
  local views = {}
  for i = 1, #list do
    if list[i].valid then views[#views + 1] = turret_view(list[i]) end
  end
  return Sa.covered(views, x, y)
end

--- La pièce de type moteur `ty` en (x, y) doit-elle attendre (secteur sous attaque et sans couverture) ?
function SaRt.must_wait(f, surface, ty, x, y, tick)
  local m = f.secteur_attaque
  if not m then return false end
  local wait = Sa.must_wait(m, ty, x, y, tick, function() return SaRt.covered(f, surface, x, y) end)
  if wait then f.secteur_attaque.waits = (f.secteur_attaque.waits or 0) + 1 end
  return wait
end

--- Même décision à partir du nom de la pièce (type lu dans les prototypes).
function SaRt.must_wait_name(f, surface, name, x, y, tick)
  local p = name and game.entity_prototypes[name]
  return SaRt.must_wait(f, surface, p and p.type or nil, x, y, tick)
end

return SaRt
