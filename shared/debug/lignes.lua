--[[
  Lot DEBUG-CERVEAU : lignes du panneau et texte des zones. Règle PURE (tests/debug_cerveau_test.lua). Les textes sont rendus en
  « chaînes localisées » ({ clé, paramètres }) : la traduction FR/EN est dans locale/*/debug_cerveau.cfg, jamais ici. Aucun nom du jeu.
]]

local Am = require("shared.debug.ameliorations")

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

--- Nom d'un objet ou d'un fluide pour un texte de la carte ou du panneau : texte riche « [item=X] » (icône + nom traduit par le jeu). Un objet qui pose une
--- entité (tapis, bras, coffre, four...) n'a PAS de clé « item-name.X » (elle est dans « entity-name »), d'où le texte riche. Un fluide : « [fluid=X] ».
--- Les textes qui le portent se dessinent avec use_rich_text = true.
function Lg.item(name)
  name = tostring(name)
  if type(game) == "table" and type(game.item_prototypes) == "table" and type(game.fluid_prototypes) == "table"
      and game.item_prototypes[name] == nil and game.fluid_prototypes[name] ~= nil then
    return "[fluid=" .. name .. "]"
  end
  return "[item=" .. name .. "]"
end

Lg.LINK_STATUS = { "actif", "chantier", "attente", "inerte", "coupe", "refuse" }
Lg.LINK_CAUSE_TEXT_MAX = 70
local LS_ETAT = { attente = true, plan = true, reserve = true, defrichage = true, fantomes = true, chantier = true, raccordement = true, fini = true, refuse = true, bloque = true }

--- Cause d'une ligne (Li.lines) -> chaîne localisée, ou nil. « texte » : le motif libre du plan directeur, recopié tel quel (coupé), jamais interprété.
function Lg.link_cause(cause)
  if type(cause) ~= "table" then return nil end
  if cause.kind == "texte" then
    local t = tostring(cause.text or "")
    if #t > Lg.LINK_CAUSE_TEXT_MAX then t = t:sub(1, Lg.LINK_CAUSE_TEXT_MAX - 1) .. "..." end
    return t
  end
  if cause.kind == "etat" then
    local c = tostring(cause.code)
    return LS_ETAT[c] and { "fo-dbg-cerveau.etat-" .. c } or c
  end
  if cause.kind == "piquage" then
    local c = tostring(cause.code)
    for _, k in ipairs(Am.PQ_CAUSES) do
      if k == c then return { "fo-dbg-cerveau.pq-cause-" .. c } end
    end
    return { "fo-dbg-cerveau.pq-cause-inconnu" }
  end
  return nil
end

--- État d'une ligne -> chaîne localisée : vide pour une ligne active ; sinon le mot d'état, suivi de la cause quand il y en a une.
function Lg.link_state(l)
  local s = l.status
  if s == "actif" or s == nil then return "" end
  local known = false
  for _, k in ipairs(Lg.LINK_STATUS) do if k == s then known = true end end
  local word = { "fo-dbg-cerveau.lien-statut-" .. (known and s or "chantier") }
  local cause = Lg.link_cause(l.cause)
  if cause == nil then return word end
  return { "fo-dbg-cerveau.lien-statut-cause", word, cause }
end

--- Texte du milieu d'une ligne : « <genre> : <objet> [état : cause] [n arrivés] ».
function Lg.link_text(l)
  local arr = (type(l.arrived) == "number" and l.arrived > 0) and { "fo-dbg-cerveau.lien-arrives", string.format("%.0f", l.arrived) } or ""
  return { "fo-dbg-cerveau.lien-ligne", { "fo-dbg-cerveau.lien-" .. tostring(l.kind) }, l.item and Lg.item(l.item) or "?", Lg.link_state(l), arr }
end

--- Texte du coffre d'arrivée (Li.buffers) : « TAMPON <- bloc p3, p5 » / « TAMPON <- tapis existant » / « TAMPON de rapatriement <- bloc p4 ».
function Lg.buffer_label(b)
  local rap = false
  for _, k in ipairs(b.kinds or {}) do if k == "rapatriement" then rap = true end end
  local src
  if #(b.sources or {}) > 0 then
    local t = {}
    for i = 1, math.min(#b.sources, 3) do t[#t + 1] = "p" .. tostring(b.sources[i]) end
    if #b.sources > 3 then t[#t + 1] = "..." end
    src = { "fo-dbg-cerveau.lien-source-blocs", table.concat(t, ", ") }
  else
    src = { "fo-dbg-cerveau.lien-source-tapis" }
  end
  return { rap and "fo-dbg-cerveau.lien-tampon-rap" or "fo-dbg-cerveau.lien-tampon", src }
end

local function rnd(v) return type(v) == "number" and string.format("%.0f", v) or "?" end

--- Texte d'une zone sur la carte : « <produit> <débit lu>/<débit visé> par min · <cause> (<sorte>) · X/N en marche » ; sans produit, la sorte.
--- z : { kind, product, rate_meas, rate_nom, color, cause, n (machines mesurées), run (machines qui travaillent) }.
function Lg.label(z)
  local cause = (z.color ~= "vert" and z.cause) and { "fo-dbg-cerveau.cause-" .. z.cause } or { "fo-dbg-cerveau.cause-aucune" }
  -- « X/N en marche » : le cas du DC (fonderie de 30 fours à 40 % de sa capacité) doit se lire sans ouvrir le panneau
  local mach = (type(z.n) == "number" and z.n > 0) and { "fo-dbg-cerveau.zone-machines", z.run or 0, z.n } or ""
  if z.product then
    return { "fo-dbg-cerveau.zone-produit", Lg.item(z.product), rnd(z.rate_meas), rnd(z.rate_nom), cause, { "fo-dbg-cerveau.sorte-" .. tostring(z.kind) }, mach }
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

-- DEFENSE-STOCK (lot DEFENSE-STOCK, champ d'état f.defstock.rows[] = { key, kind, x, y, score, have, want, dist, served, skip, why, tick }) : mots fixes.
Lg.DEF_KIND = { "qg", "prevu", "attaque", "site", "couverture" }
Lg.DEF_SKIP = { "servie", "suivante", "stock", "groupe", "munitions", "repos", "refus", "course", "plafond", "pause", "tenue", "loin" }
Lg.DEF_WHY = { "ennemi", "sans_batiment", "danger" }
Lg.DEF_MAX = 6 -- lieux montrés au plus (le champ en porte 24)
local DEF_K, DEF_S, DEF_W = {}, {}, {}
for _, w in ipairs(Lg.DEF_KIND) do DEF_K[w] = true end
for _, w in ipairs(Lg.DEF_SKIP) do DEF_S[w] = true end
for _, w in ipairs(Lg.DEF_WHY) do DEF_W[w] = true end

--- Ligne de « décisions récentes » pour un lieu de défense du stock : { tick, kind = "defense", text (clé de doublon), ltext }. nil si l'entrée n'est pas une table.
function Lg.defense_row(r)
  if type(r) ~= "table" then return nil end
  local kind = (type(r.kind) == "string" and DEF_K[r.kind]) and r.kind or "inconnu"
  local skip = (type(r.skip) == "string" and DEF_S[r.skip]) and r.skip or "inconnu"
  local why = (type(r.why) == "string" and DEF_W[r.why]) and r.why or nil
  local have = type(r.have) == "number" and string.format("%.0f", r.have) or "?"
  local want = type(r.want) == "number" and string.format("%.0f", r.want) or "?"
  local cause = { "fo-dbg-cerveau.def-skip-" .. skip }
  if why then cause = { "", cause, " (", { "fo-dbg-cerveau.def-why-" .. why }, ")" } end
  return { tick = type(r.tick) == "number" and r.tick or nil, kind = "defense",
    text = tostring(r.key) .. "|" .. kind .. "|" .. skip .. "|" .. tostring(why) .. "|" .. have .. "|" .. want,
    ltext = { "fo-dbg-cerveau.def-ligne", { "fo-dbg-cerveau.def-kind-" .. kind }, have, want, cause } }
end

-- AMELIORATION (lot AMELIORATION, champ d'état f.team.capital.refus["<bloc>|<famille>"] = { cause, tick }) : mots fixes. bloc : « p<projet> », « qg »,
-- « t<avant-poste> » ; la famille est un nom de données (paramètre, jamais une clé de traduction).
Lg.AM_CAUSES = { "plafond-centre", "sans-centre", "emprise", "sans-cout", "refus-recent", "niveau-max", "sans-gain", "reconstruction" }
local AM_C = {}
for _, w in ipairs(Lg.AM_CAUSES) do AM_C[w] = true end

--- Lit un refus d'amélioration : { bloc = LocalisedString, pid = numéro de projet ou nil, famille, cause (mot fixe ou « inconnu »), tick } ou nil.
function Lg.am_refus(key, r)
  if type(key) ~= "string" or type(r) ~= "table" then return nil end
  local bloc, famille = key:match("^(.-)|(.*)$")
  if not bloc then bloc, famille = key, "?" end
  local pid = bloc:match("^p(%d+)$")
  local label
  if pid then label = { "fo-dbg-cerveau.am-bloc-projet", pid }
  elseif bloc == "qg" then label = { "fo-dbg-cerveau.am-bloc-qg" }
  elseif bloc:match("^t%d+$") then label = { "fo-dbg-cerveau.am-bloc-tourelles", bloc:sub(2) }
  else label = { "fo-dbg-cerveau.am-bloc-inconnu" } end
  local cause = (type(r.cause) == "string" and AM_C[r.cause]) and r.cause or "inconnu"
  return { bloc = label, blocname = bloc, pid = pid and tonumber(pid) or nil, famille = famille, cause = cause, tick = type(r.tick) == "number" and r.tick or nil }
end

--- Ligne de « décisions récentes » d'un refus d'amélioration.
function Lg.am_refus_row(key, r)
  local a = Lg.am_refus(key, r)
  if not a then return nil end
  return { tick = a.tick, kind = "amelioration_refus", text = a.blocname .. "|" .. a.famille .. "|" .. a.cause,
    ltext = { "fo-dbg-cerveau.am-refus-ligne", a.bloc, a.famille, { "fo-dbg-cerveau.am-refus-" .. a.cause } } }
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
