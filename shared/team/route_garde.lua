--[[
  GARDE DES TRACÉS DE TAPIS (s45 astar-budget). Lua PUR : aucune API du jeu (tests/s45_astar-budget_test.lua).
  1. Plafond GLOBAL par tick : tous les tracés (toutes équipes, tous projets) d'un même tick partagent TICK_MAX états.
  2. Mémo d'échec par paire source/cible (clé triée) : attente exponentielle bornée, déterministe
     (BASE, 2 BASE, 4 BASE … jusqu'à CAP ticks) ; un succès efface l'entrée.
  3. Un tracé qui repasse sur une de ses tuiles (boucle) est refusé.
]]
local G = {}

G.TICK_MAX = 16000   -- états au plus par tick, tous tracés confondus (4 × Tv.PLAN_BUDGET, le budget d'un plan)
G.BASE = 600         -- 1re attente après un échec : 10 s de jeu
G.CAP = 108000       -- attente au plus : 30 min de jeu
G.MEMO_MAX = 512     -- entrées au plus avant purge des entrées échues

local function pk(a) return tostring(a.x) .. "," .. tostring(a.y) end

--- Clé de paire indépendante du sens (triée).
function G.pair_key(s, t)
  local a, b = pk(s), pk(t)
  if a > b then a, b = b, a end
  return a .. "|" .. b
end

--- Attente (ticks) après `n` échecs consécutifs (n ≥ 1).
function G.wait(n)
  local w = G.BASE
  for _ = 2, n do
    w = w * 2
    if w >= G.CAP then return G.CAP end
  end
  return math.min(w, G.CAP)
end

--- Vrai si la paire est en attente à `tick`.
function G.blocked(memo, key, tick)
  local e = memo and memo[key]
  return e ~= nil and tick < e.until_tick
end

--- Échec enregistré : n += 1, attente G.wait(n).
function G.fail(memo, key, tick)
  local e = memo[key]
  local n = (e and e.n or 0) + 1
  memo[key] = { n = n, until_tick = tick + G.wait(n) }
  G.prune(memo, tick)
end

function G.success(memo, key) memo[key] = nil end

--- Purge des entrées échues quand le mémo dépasse MEMO_MAX (résultat indépendant de l'ordre de parcours).
function G.prune(memo, tick)
  local n = 0
  for _ in pairs(memo) do n = n + 1 end
  if n <= G.MEMO_MAX then return end
  local dead = {}
  for k, e in pairs(memo) do if tick >= e.until_tick + G.CAP then dead[#dead + 1] = k end end
  for _, k in ipairs(dead) do memo[k] = nil end
end

--- Compteur global du tick : box = { tick, spent } (table locale au module appelant, jamais dans global).
function G.tick_left(box, tick)
  if box.tick ~= tick then box.tick, box.spent = tick, 0 end
  return G.TICK_MAX - box.spent
end

function G.spend(box, tick, n)
  G.tick_left(box, tick)
  box.spent = box.spent + math.max(0, n or 0)
end

--- Vrai si le tracé repasse sur une tuile déjà prise par lui-même.
function G.has_loop(tiles)
  local seen = {}
  for _, e in ipairs(tiles or {}) do
    local k = pk(e)
    if seen[k] then return true end
    seen[k] = true
  end
  return false
end

return G
