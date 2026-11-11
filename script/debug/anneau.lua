--[[
  Lot DEBUG-CERVEAU : ANNEAU des décisions de la capitalisation, pour la vue « Cerveau ». La capitalisation (script/ai3/capitalisation.lua,
  decide_finish) y dépose, en UN appel par décision, les ordres envoyés et les ordres refusés AVEC LEUR RAISON (portes, plafonds, pile,
  emplacements...), que le cerveau ne conserve nulle part (seul le journal [FO-CAPI] les écrit). Conditions de l'intégrateur (8/11) :
    1. un seul appel dans decide_finish ; anneau borné par force (An.MAX entrées : tick, clé, sorte, raison en chaîne), dans l'espace déclaré
       ici (Storage.declare) : nombres et chaînes seulement, jamais une fonction ;
    2. la décision n'en lit JAMAIS rien (seule la vue le lit : script/debug/lecture.lua) ;
    3. preuve : tests/debug_anneau_ab_test.lua, les décisions sont identiques octet à octet avec et sans le crochet ;
    4. dans capitalisation.lua : un champ (Capi.Anneau), aucune locale de plus.
  L'anneau est tenu en tout temps (pas seulement quand la vue est ouverte), pour que la vue montre aussi ce qui s'est passé avant son
  ouverture. Coût : au plus MAX + quelques tables par décision (une par minute et par faction).
]]

local Storage = require("script.core.storage")

local An = {}

An.MAX = 32          -- entrées gardées par force
An.KEY_MAX = 120     -- caractères gardés d'une clé
An.WHY_MAX = 200     -- caractères gardés d'une raison
An.PER_NOTE = 16     -- entrées prises au plus par décision (les refus de la règle peuvent être nombreux)

Storage.declare("debug_cerveau_anneau", function() return { v = 1, rings = {} } end)

local function ns()
  local ok, st = pcall(Storage.ns, "debug_cerveau_anneau")
  if not ok then return nil end
  return st
end

--- Une décision de l'équipe f à `tick` : sent = liste de chaînes (ordres envoyés), refused = liste de { clé, raison }. Rend le nombre
--- d'entrées ajoutées. Ne lit rien de l'état des décisions, n'écrit que dans l'anneau.
function An.note(f, tick, sent, refused)
  local st = ns()
  if not (st and st.rings) then return 0 end
  local key = tostring(f.key or "player")
  local ring = st.rings[key]
  if not ring then
    ring = {}
    st.rings[key] = ring
  end
  local n = 0
  -- une entrée identique (même sorte, clé et raison) déjà dans l'anneau est RAFRAÎCHIE (retirée puis remise en dernier, date du jour) : le
  -- même refus répété à chaque décision ne chasse pas les autres
  local function put(k, s, r)
    for i = #ring, 1, -1 do
      local e = ring[i]
      if e.k == k and e.s == s and e.r == r then table.remove(ring, i) break end
    end
    ring[#ring + 1] = { t = tick, k = k, s = s, r = r }
    n = n + 1
  end
  for _, s in ipairs(sent or {}) do
    if n < An.PER_NOTE then put(tostring(s):sub(1, An.KEY_MAX), "envoye", "") end
  end
  for _, r in ipairs(refused or {}) do
    if n < An.PER_NOTE then put(tostring(r[1]):sub(1, An.KEY_MAX), "refus", tostring(r[2]):sub(1, An.WHY_MAX)) end
  end
  while #ring > An.MAX do table.remove(ring, 1) end
  return n
end

--- Lecture pour la vue : l'anneau de l'équipe de clé `key` (liste, plus ancien d'abord), ou une liste vide.
--- Lot TELEMETRIE : retire les anneaux des équipes disparues (clés absentes de alive), au plus Te.PURGE_MAX par appel. Rend les clés retirées.
function An.purge(alive)
  local st = ns()
  if not (st and st.rings) then return {} end
  local gone = require("shared.debug.telemetrie").orphans(st.rings, alive)
  for _, k in ipairs(gone) do st.rings[k] = nil end
  return gone
end

function An.get(key)
  local st = ns()
  local ring = st and st.rings and st.rings[tostring(key)]
  return ring or {}
end

return An
