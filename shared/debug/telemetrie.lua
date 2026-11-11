--[[
  Lot TELEMETRIE : règles PURES de la télémétrie des IA de faction (vue « Cerveau », onglet Décisions).
    Te.classify(f)      décision active classée en 4 catégories, en LISANT l'état existant (défense f.defstock.rows, approvisionnement
                        f.team.sources.dec, capitalisation f.team.capi.open et f.team.capital.current). Aucune logique de décision : lecture seule.
    Te.sizes(f, cap)    taille des tables de décision d'une équipe, en COMPTANT leurs entrées (borné à cap par table ; le comptage ne dépend
                        pas de l'ordre de parcours).
    Te.orphans(m, alive, max)  clés d'une table indexée par équipe dont l'équipe a disparu (clés triées, au plus max).
]]
local Te = {}

Te.CATS = { "defense", "attente_ressource", "expansion_mine", "reinvestissement" }
Te.CAP = 1000      -- entrées comptées au plus par table
Te.PURGE_MAX = 16  -- clés orphelines retirées au plus par passe

local function sorted(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

--- { cat, why } : la première règle qui tient, dans l'ordre DEFENSE, ATTENTE_RESSOURCE, EXPANSION_MINE, REINVESTISSEMENT.
function Te.classify(f)
  f = type(f) == "table" and f or {}
  local team = type(f.team) == "table" and f.team or {}
  local ds = f.defstock and f.defstock.rows
  for _, r in ipairs(type(ds) == "table" and ds or {}) do
    if type(r) == "table" and (r.kind == "attaque" or (type(r.have) == "number" and type(r.want) == "number" and r.have < r.want and r.skip ~= "servie")) then
      return { cat = "defense", why = tostring(r.key or r.kind) }
    end
  end
  local cs = team.capi
  for _, rec in ipairs(cs and type(cs.open) == "table" and cs.open or {}) do
    if type(rec) == "table" and ((type(rec.missing) == "table" and #rec.missing > 0) or rec.blocked) then
      return { cat = "attente_ressource", why = tostring(rec.item or rec.entity or rec.kind or "?") }
    end
  end
  local src = team.sources and team.sources.dec
  if type(src) == "table" then
    local keys = sorted(src)
    for _, res in ipairs(keys) do
      local d = src[res]
      if type(d) == "table" and (d.raison == "aucune_sortie" or d.raison == "sorties_vides") then return { cat = "attente_ressource", why = tostring(res) } end
    end
    for _, res in ipairs(keys) do
      local d = src[res]
      if type(d) == "table" and (d.choix == "sortie" or d.choix == "main") then return { cat = "expansion_mine", why = tostring(res) } end
    end
  end
  local cap = team.capital
  if cap and cap.current and cap.current.key then return { cat = "reinvestissement", why = tostring(cap.current.key) } end
  local first = cs and type(cs.open) == "table" and cs.open[1]
  if type(first) == "table" then return { cat = "reinvestissement", why = tostring(first.item or first.entity or first.kind or "?") } end
  return { cat = "attente_ressource", why = "-" }
end

local function count(t, cap)
  if type(t) ~= "table" then return 0 end
  local n = 0
  for _ in pairs(t) do
    n = n + 1
    if n >= cap then break end
  end
  return n
end

--- Liste triée { name, n, full } des tables de décision connues d'une équipe.
function Te.sizes(f, cap)
  cap = cap or Te.CAP
  f = type(f) == "table" and f or {}
  local team = type(f.team) == "table" and f.team or {}
  local cs, capi = team.capi or {}, team.capital or {}
  local list = {
    { "capi.open", cs.open }, { "capi.done", cs.done }, { "capi.refused", cs.refused },
    { "capital.refus", capi.refus }, { "capital.history", capi.history },
    { "sources.dec", team.sources and team.sources.dec }, { "defstock.rows", f.defstock and f.defstock.rows },
  }
  local out, total = {}, 0
  for _, e in ipairs(list) do
    local n = count(e[2], cap)
    total = total + n
    out[#out + 1] = { name = e[1], n = n, full = n >= cap }
  end
  return out, total
end

--- Clés de m (table indexée par équipe) absentes de alive (ensemble { [clé] = true }), triées, au plus max.
function Te.orphans(m, alive, max)
  max = max or Te.PURGE_MAX
  local out = {}
  if type(m) ~= "table" then return out end
  alive = alive or {}
  for _, k in ipairs(sorted(m)) do
    if #out >= max then break end
    if not alive[k] then out[#out + 1] = k end
  end
  return out
end

return Te
