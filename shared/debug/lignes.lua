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

--- Texte d'une zone sur la carte : « <produit> <débit lu>/<débit visé> par min · <cause> (<sorte>) · X/N en marche » ; sans produit, la sorte.
--- z : { kind, product, rate_meas, rate_nom, color, cause, n (machines mesurées), run (machines qui travaillent) }.
function Lg.label(z)
  local cause = (z.color ~= "vert" and z.cause) and { "fo-dbg-cerveau.cause-" .. z.cause } or { "fo-dbg-cerveau.cause-aucune" }
  -- « X/N en marche » : le cas du DC (fonderie de 30 fours à 40 % de sa capacité) doit se lire sans ouvrir le panneau
  local mach = (type(z.n) == "number" and z.n > 0) and { "fo-dbg-cerveau.zone-machines", z.run or 0, z.n } or ""
  if z.product then
    return { "fo-dbg-cerveau.zone-produit", { "item-name." .. z.product }, rnd(z.rate_meas), rnd(z.rate_nom), cause, { "fo-dbg-cerveau.sorte-" .. tostring(z.kind) }, mach }
  end
  return { "fo-dbg-cerveau.zone-simple", { "fo-dbg-cerveau.sorte-" .. tostring(z.kind) }, cause, mach }
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

-- MINAGE-MAIN (lot MINAGE-MAIN, champ d'état f.team.sources.dec[<ressource>] = { choix, raison, n, d, tick }) : mots fixes. Le champ `why` de ce lot est un
-- texte libre : jamais lu ici. Un mot hors liste s'affiche « inconnu ».
Lg.SRC_CHOIX = { "sortie", "stock", "main" }
Lg.SRC_RAISON = { "sortie", "en_marche", "stock_suffit", "stock_refuse", "aucune_sortie", "sorties_vides", "sortie_dangereuse", "tournee_en_pause", "crise" }
local SRC_C, SRC_R = {}, {}
for _, w in ipairs(Lg.SRC_CHOIX) do SRC_C[w] = true end
for _, w in ipairs(Lg.SRC_RAISON) do SRC_R[w] = true end

--- Ligne de « décisions récentes » pour une ressource : { tick, kind = "source", text (clé de doublon), ltext (chaîne localisée) }. nil si l'entrée n'est pas une table.
function Lg.source_row(resource, d)
  if type(d) ~= "table" then return nil end
  local choix = (type(d.choix) == "string" and SRC_C[d.choix]) and d.choix or "inconnu"
  local raison = (type(d.raison) == "string" and SRC_R[d.raison]) and d.raison or "inconnu"
  local n = type(d.n) == "number" and string.format("%.0f", d.n) or "?"
  local dist = type(d.d) == "number" and string.format("%.0f", d.d) or "?"
  return { tick = type(d.tick) == "number" and d.tick or nil, kind = "source", text = tostring(resource) .. "|" .. choix .. "|" .. raison .. "|" .. n .. "|" .. dist,
    ltext = { "fo-dbg-cerveau.src-ligne", { "item-name." .. tostring(resource) }, { "fo-dbg-cerveau.src-choix-" .. choix }, { "fo-dbg-cerveau.src-raison-" .. raison }, n, dist } }
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
