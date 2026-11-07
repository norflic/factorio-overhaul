--[[
  Lot POULS (7/11, fo-logs\2026-11-07_POULS\CRITERES.md) : JETON du tick pour les relevés lourds du pouls du chantier
  (script/team/build.lua, Build.PULSE). Au plus UN par tick, toutes équipes confondues : une bande du relevé du réseau
  (script/team/reseau_vivant.lua) ou un début de relevé du raccordement (script/team/raccord.lua). Qui le trouve pris remet son travail
  à la passe suivante. MESURÉ avant ce lot sur la sauvegarde du DC : bp:reseau 153 ms et bp:raccord 99 ms au même tick (935405).

  Revue de la 0.6.59, point 3 : le premier appelé d'un tick (équipes dans l'ordre de Build : factions, puis votre équipe) l'emportait
  toujours, et votre équipe pouvait attendre tant que des factions relevaient. Le jeton est désormais ÉQUITABLE : une FILE (premier refusé,
  premier servi). Le jeton d'un tick va au demandeur en tête de file, s'il en a une ; un autre demandeur est refusé et mis en file. Une
  entrée qui ne redemande pas au pouls suivant (J.STALE ticks) sort de la file. Avec k demandeurs à la fois, aucun n'attend plus de k − 1
  pouls de suite (tests/pouls_test.lua, P8).
  État : la file est dans global (ns « pouls_jeton » : q = demandeurs en attente, dans l'ordre ; last[demandeur] = tick de sa dernière
  demande) : elle dure d'un tick à l'autre, donc elle doit être la même sur tous les clients et après un chargement. Seul `held` (jeton
  pris à CE tick) est une table locale : un tick ne s'interrompt pas par une sauvegarde.
  Demandeur : « <équipe>:rv » ou « <équipe>:ra ». Sans demandeur (bancs d'avant ce point), le premier appel du tick l'emporte.
]]

local Storage = require("script.core.storage")

local J = {}

J.STALE = 5 -- ticks (Build.PULSE) : une demande non renouvelée au pouls suivant sort de la file

Storage.declare("pouls_jeton", function() return { q = {}, last = {} } end)

local held = -1
local purged = -1

local function S()
  local s = Storage.ns("pouls_jeton")
  if s then
    s.q = s.q or {}
    s.last = s.last or {}
  end
  return s
end

--- Une fois par tick : les demandeurs qui n'ont pas redemandé depuis plus de J.STALE ticks sortent de la file.
local function purge(s, tick)
  if purged == tick then return end
  purged = tick
  local q = {}
  for _, k in ipairs(s.q) do
    if (s.last[k] or -1) >= tick - J.STALE then q[#q + 1] = k else s.last[k] = nil end
  end
  s.q = q
end

local function index_of(q, k)
  for i = 1, #q do if q[i] == k then return i end end
  return nil
end

--- Vrai si le jeton du tick `tick` est donné à `who` (il est alors pris) ; faux s'il est déjà pris à ce tick, ou réservé au demandeur en
--- tête de file (`who` est alors mis en file).
function J.take(tick, who)
  local s = who and S()
  if not s then
    if held == tick then return false end
    held = tick
    return true
  end
  purge(s, tick)
  local i = index_of(s.q, who)
  if held == tick or (s.q[1] ~= nil and s.q[1] ~= who) then
    if not i then s.q[#s.q + 1] = who end
    s.last[who] = tick
    return false
  end
  held = tick
  if i then table.remove(s.q, i) end
  s.last[who] = nil
  return true
end

--- Bancs hors jeu seulement : rend le jeton (nouvelle partie simulée).
function J.reset()
  held, purged = -1, -1
  local s = Storage.ns("pouls_jeton")
  if s then s.q, s.last = {}, {} end
end

return J
