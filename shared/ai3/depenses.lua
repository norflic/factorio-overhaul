--[[
  Lot DEPENSES2 (4/11, demande du DC au QCM-4/11-SUITE : « Dépenses du stock dormant [...] et investir en recherche, armement ») :
  le stock qui DORT s'investit. Règle PURE (aucune API Factorio, aucun nom d'objet : matières opaques données par le runtime ;
  tests/depenses2_test.lua). Diagnostic : fo-logs/2026-11-04_DEPENSES2/RAPPORT.md.

  1. EXCÉDENT d'une matière = stock libre HORS BESOIN évalué − max(Dp.FLOOR, Dp.H_SEUIL × production par minute) ; une matière dont le
     besoin n'est pas couvert n'a aucun excédent (rien sous la réserve). Elle DORT après Dp.N_DORT ticks d'excédent d'un seul tenant.
  2. Ordre (décision du lead, 4/11) : la DÉFENSE des sites sensibles d'abord, sur sa DEMANDE (want, écrite par le périmètre), au plus
     Dp.DEF_PCT % de l'excédent de chaque matière, ou tout l'excédent d'une matière « défense seule » (matière brute : la pierre des
     murs) ; puis la RECHERCHE prend le reste des plaques : laboratoires de plus (un par Dp.LAB_PLATES, au plus Dp.LABS_MAX) ; puis
     l'armement (ce qui reste, rendu au journal).
  3. Interrupteur : inp.on faux -> rien, horloges oubliées.
  Déterminisme : matières dans l'ordre de l'appelant, aucun hasard, aucun temps mesuré ; l'état ne garde que des nombres.
]]

local Dp = {}

Dp.H_SEUIL = 6         -- min de production gardées au coffre au-delà du besoin évalué
Dp.FLOOR = 100         -- unités gardées au moins par matière
Dp.N_DORT = 5 * 3600   -- ticks d'excédent continu avant que la matière « dorme »
Dp.PROD_KEEP = 700     -- ‰ de l'ancienne production gardés à chaque relevé
Dp.DEF_PCT = 30        -- % de l'excédent d'une matière offerts à la défense, au plus
Dp.LAB_PLATES = 1000   -- plaques dormantes (après la défense) par laboratoire de plus
Dp.LABS_MAX = 4        -- laboratoires de plus au plus

local function num(x) return type(x) == "number" and x == x and x or 0 end

function Dp.new() return { since = {}, prod = {} } end

function Dp.smooth(old, made, dt)
  if not dt or dt <= 0 then return num(old) end
  local per_min = num(made) * 3600 / dt
  if old == nil then return per_min end
  return (num(old) * Dp.PROD_KEEP + per_min * (1000 - Dp.PROD_KEEP)) / 1000
end

function Dp.excess(free, prod, missing)
  if missing then return 0 end
  return math.max(0, num(free) - math.max(Dp.FLOOR, Dp.H_SEUIL * math.max(0, num(prod))))
end

--- st = état (Dp.new) ; inp = { on, tick, products = { { key, free, made, missing, def_only } }, want = { [key] = n } }.
--- Rend st, res = { per = { [key] = excédent qui dort }, defense = { [key] = accordé }, research = plaques, labs, arms = plaques, why }.
function Dp.step(st, inp)
  st = st or Dp.new()
  st.since, st.prod = st.since or {}, st.prod or {}
  inp = inp or {}
  local tick = num(inp.tick)
  local res = { per = {}, defense = {}, research = 0, labs = 0, arms = 0, why = "" }
  if not inp.on then
    st.since, st.prod, st.last = {}, {}, nil
    res.why = "eteint"
    return st, res
  end
  local dt = st.last and (tick - st.last) or nil
  st.last = tick
  local parts, want = {}, inp.want or {}
  for _, p in ipairs(inp.products or {}) do
    local k = tostring(p.key)
    if dt then st.prod[k] = Dp.smooth(st.prod[k], p.made, dt) end
    local exc = Dp.excess(p.free, st.prod[k], p.missing)
    if exc > 0 then st.since[k] = st.since[k] or tick else st.since[k] = nil end
    local sleeping = st.since[k] ~= nil and tick - st.since[k] >= Dp.N_DORT
    if sleeping then
      res.per[k] = exc
      local cap = p.def_only and exc or exc * Dp.DEF_PCT / 100
      local d = math.floor(math.min(math.max(0, num(want[k])), cap))
      res.defense[k] = d
      if not p.def_only then res.research = res.research + (exc - d) end
      parts[#parts + 1] = string.format("%s dort %d (defense %d)", k, math.floor(exc), d)
    end
  end
  res.labs = math.min(Dp.LABS_MAX, math.floor(res.research / Dp.LAB_PLATES + 1e-9))
  res.arms = math.max(0, res.research - res.labs * Dp.LAB_PLATES)
  res.why = string.format("%s | recherche %d plaque(s) -> %d laboratoire(s) de plus | armement %d",
    #parts > 0 and table.concat(parts, " ; ") or "rien ne dort", math.floor(res.research), res.labs, math.floor(res.arms))
  return st, res
end

return Dp
