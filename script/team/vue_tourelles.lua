--[[
  Lot S7 (X10, queue de la vue ; critères : fo-logs/2026-11-07_X10/S7_CRITERES.md) : RELEVÉ des tourelles d'une équipe, lu UNE fois
  par vue (script/team/team.lua, Team.view) et passé à ceux qui relisaient f.turrets chacun de leur côté : le compte des tourelles de
  view:4, Outposts.turret_groups, Front.view, GardeCentrale.view et Ilots.view. Avant ce lot : 5 tris des clés et 17 à 20 appels au
  moteur par tourelle et par vue (position lue 6 fois, inventaire de munitions 3 fois) ; après : un tri et 5 à 8 appels.

  CONTRAT : chaque lecteur rend exactement ce qu'il rendait en relisant f.turrets lui-même au même instant (ombre de
  tests/x10_s7_test.lua). La vue ne pose, ne détruit et ne recharge aucune tourelle entre le relevé et ses lecteurs.

  Le relevé est une variable LOCALE de Team.view : jamais dans global, jamais gardé d'une vue à l'autre (une tourelle morte entre deux
  vues n'y est donc jamais). Comme Outposts.turret_groups, il RETIRE de f.turrets les entrées invalides (même purge : global identique).

  Entrée : { id, t (LuaEntity), x, y, oid (poste du propriétaire, State.owner, ou nil), rounds (chargeurs), rank (rang de la munition,
  Outposts.rank_of ; 0 : case vide) }, dans l'ordre des id triés (State.sorted_keys, l'ordre de tous les anciens lecteurs).
]]
local State = require("script.faction.state")

local VT = {}

--- Relevé des tourelles de `f`. `rank_of(nom)` : rang d'une munition (Outposts.rank_of, passé par l'appelant : pas de require circulaire).
function VT.releve(f, rank_of)
  local list = {}
  local turrets = f.turrets
  if not turrets then return list end
  local ammo_inv = defines.inventory.turret_ammo
  for _, id in ipairs(State.sorted_keys(turrets)) do
    local t = turrets[id]
    if t.valid then
      local pos = t.position
      local owner = State.owner(id)
      local inv = t.get_inventory(ammo_inv)
      local rounds, rank = 0, 0
      if inv then
        rounds = inv.get_item_count()
        -- (comme Outposts.ammo_rank : case vide -> 0 ; sinon le rang de la première pile)
        if not inv.is_empty() then
          local s = inv[1]
          rank = s.valid_for_read and rank_of(s.name) or 0
        end
      end
      list[#list + 1] = { id = id, t = t, x = pos.x, y = pos.y, oid = owner and owner.oid, rounds = rounds, rank = rank }
    else
      turrets[id] = nil
    end
  end
  return list
end

--- Positions { x, y } de toutes les tourelles du relevé, et nombre de celles dont le poste commence par `prefix` (Front : « front »,
--- Ilots : Il.OID) : ce que rendaient les turrets_of de script/team/front.lua et script/team/ilots.lua.
function VT.positions(releve, prefix)
  local list, placed = {}, 0
  local n = #prefix
  for i = 1, #releve do
    local r = releve[i]
    list[#list + 1] = { x = r.x, y = r.y }
    local oid = r.oid
    if type(oid) == "string" and oid:sub(1, n) == prefix then placed = placed + 1 end
  end
  return list, placed
end

--- Positions et chargeurs { x, y, rounds } : ce que rendait turrets_of de script/team/garde_centrale.lua.
function VT.armed(releve)
  local list = {}
  for i = 1, #releve do
    local r = releve[i]
    list[#list + 1] = { x = r.x, y = r.y, rounds = r.rounds }
  end
  return list
end

return VT
