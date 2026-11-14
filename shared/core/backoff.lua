--[[
  shared/core/backoff.lua : ordonnanceur pur à recul exponentiel des contrôles périodiques par clé (équipe + bloc).

  L'état est une table fournie par l'appelant (dans `global`, via son module) : s[key] = { iv = intervalle, last = tick du dernier
  contrôle }. Aucune horloge mesurée, aucun pairs : seulement des nombres et des clés passées par l'appelant.
    Backoff.due(s, key, tick, base)        : vrai si le contrôle de `key` est dû (jamais contrôlé, ou tick - last >= iv).
    Backoff.report(s, key, tick, sain, base, max) : consigne un contrôle ; SAIN et inchangé double iv (base .. max), sinon iv = base.
    Backoff.wake(s, key, base)             : remet iv à base et rend le contrôle dû tout de suite.
    Backoff.interval(s, key, base)         : intervalle courant (base sans entrée).
]]
local Backoff = {}

Backoff.BASE = 600
Backoff.MAX = 36000

function Backoff.interval(s, key, base)
  local e = s and s[key]
  return (e and e.iv) or base or Backoff.BASE
end

function Backoff.due(s, key, tick, base)
  local e = s[key]
  if not e or e.last == nil then return true end
  return tick - e.last >= (e.iv or base or Backoff.BASE)
end

function Backoff.report(s, key, tick, sain, base, max)
  base, max = base or Backoff.BASE, max or Backoff.MAX
  local e = s[key] or {}
  if sain then
    e.iv = math.min(max, math.max(base, (e.iv or base) * 2))
  else
    e.iv = base
  end
  e.last = tick
  s[key] = e
  return e.iv
end

function Backoff.wake(s, key, base)
  local e = s[key]
  if not e then return end
  e.iv = base or Backoff.BASE
  e.last = nil
end

function Backoff.forget(s, key) s[key] = nil end

return Backoff
