--[[
  Lot DEBUG-CERVEAU : lignes du panneau et texte des zones. Règle PURE (tests/debug_cerveau_test.lua). Les textes sont rendus en
  « chaînes localisées » ({ clé, paramètres }) : la traduction FR/EN est dans locale/*/debug_cerveau.cfg, jamais ici. Aucun nom du jeu.
]]

local Lg = {}

Lg.DECISIONS_MAX = 24
Lg.TASKS_MAX = 8

--- Durée en ticks -> chaîne localisée « il y a 40 s » / « il y a 3 min » / « il y a 2 h ». nil (date inconnue) -> « date inconnue ».
function Lg.ago(ticks)
  if type(ticks) ~= "number" or ticks ~= ticks or ticks < 0 then return { "fo-dbg-cerveau.ago-inconnu" } end
  local s = math.floor(ticks / 60)
  if s < 90 then return { "fo-dbg-cerveau.ago-s", s } end
  local m = math.floor(s / 60 + 0.5)
  if m < 90 then return { "fo-dbg-cerveau.ago-min", m } end
  return { "fo-dbg-cerveau.ago-h", string.format("%.1f", m / 60) }
end

local function rnd(v) return type(v) == "number" and string.format("%.0f", v) or "?" end

--- Texte d'une zone sur la carte : « <produit> <débit lu>/<débit visé> par min · <cause> » ; sans produit, la sorte de la zone.
--- z : { kind, product, rate_meas, rate_nom, color, cause }.
function Lg.label(z)
  local cause = (z.color ~= "vert" and z.cause) and { "fo-dbg-cerveau.cause-" .. z.cause } or { "fo-dbg-cerveau.cause-aucune" }
  if z.product then
    return { "fo-dbg-cerveau.zone-produit", { "item-name." .. z.product }, rnd(z.rate_meas), rnd(z.rate_nom), cause, { "fo-dbg-cerveau.sorte-" .. tostring(z.kind) } }
  end
  return { "fo-dbg-cerveau.zone-simple", { "fo-dbg-cerveau.sorte-" .. tostring(z.kind) }, cause }
end

-- Tâches connues du tableau (kind, ou kind/mode pour le plan directeur) -> suffixe de clé de traduction « tache-<suffixe> ».
Lg.TASK_KEYS = {
  ["service"] = "service", ["carry/fill"] = "carry-fill", ["carry/collect"] = "carry-collect", ["ghost"] = "ghost", ["clear"] = "clear",
  ["refill"] = "refill", ["build"] = "build", ["extend"] = "extend", ["mine"] = "mine", ["craft"] = "craft", ["smelt"] = "smelt",
  ["smelters"] = "smelters", ["garrison"] = "garrison", ["fortify"] = "fortify", ["salvage"] = "salvage", ["repare"] = "repare",
  ["repair"] = "repare", ["rebuild"] = "repare",
}

--- Suffixe de clé de traduction d'une tâche : kind/mode connu, sinon kind connu, sinon « autre ».
function Lg.task_key(kind, mode)
  if mode ~= nil and Lg.TASK_KEYS[tostring(kind) .. "/" .. tostring(mode)] then return Lg.TASK_KEYS[tostring(kind) .. "/" .. tostring(mode)] end
  return Lg.TASK_KEYS[tostring(kind)] or "autre"
end

--- Tâches du tableau qui concernent une zone : prises d'abord, puis priorité décroissante, puis clé.
--- tasks : liste de { key, kind, mode, prio, taken, pid, outpost } ; zone : { pid } ou { oid }.
function Lg.tasks_for_zone(tasks, zone, max)
  local out = {}
  for _, t in ipairs(tasks or {}) do
    local hit = (zone.pid ~= nil and t.pid == zone.pid) or (zone.oid ~= nil and t.outpost == zone.oid)
    if hit then out[#out + 1] = t end
  end
  table.sort(out, function(a, b)
    if (a.taken and true or false) ~= (b.taken and true or false) then return a.taken and true or false end
    if (a.prio or 0) ~= (b.prio or 0) then return (a.prio or 0) > (b.prio or 0) end
    return tostring(a.key) < tostring(b.key)
  end)
  max = max or Lg.TASKS_MAX
  while #out > max do out[#out] = nil end
  return out
end

--- Décisions récentes : plus récentes d'abord, doublons (même sorte et même texte) retirés en gardant la plus récente, au plus `max`.
--- rows : liste de { tick, kind, text }. Une ligne sans date vient après les datées (ordre de lecture gardé).
function Lg.decisions(rows, max)
  local list = {}
  for i, r in ipairs(rows or {}) do list[#list + 1] = { r = r, i = i } end
  table.sort(list, function(a, b)
    local ta, tb = a.r.tick, b.r.tick
    if (ta ~= nil) ~= (tb ~= nil) then return ta ~= nil end
    if ta ~= tb and ta ~= nil then return ta > tb end
    return a.i < b.i
  end)
  local seen, out = {}, {}
  max = max or Lg.DECISIONS_MAX
  for _, e in ipairs(list) do
    local k = tostring(e.r.kind) .. "\1" .. tostring(e.r.text)
    if not seen[k] then
      seen[k] = true
      out[#out + 1] = e.r
      if #out >= max then break end
    end
  end
  return out
end

return Lg
