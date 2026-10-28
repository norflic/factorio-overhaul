--[[
  Interface de gestion en jeu, équipe et factions (lot IA1-i, docs/EQUIPES_PNJ.md §8, §16) : MODÈLE PUR.
  Lua pur, testable hors jeu (tests/ia1i_test.lua) : aucun appel au moteur, aucune lecture de `global`.

  Ce que le modèle décide (et rien d'autre) :
    - l'ordre des onglets et la période de rafraîchissement ;
    - le JOURNAL de l'équipe : différence entre deux relevés d'état (nombres et chaînes seulement), d'où des entrées
      { kind, a, b, c } traduites à l'affichage ; aucune décision de jeu n'en dépend ;
    - la relation d'une faction avec vous (trêve, guerre, guerre provoquée, anéantie) à partir de l'état publié par
      PvP.status ;
    - les traits saillants d'un caractère (les deux plus forts, égalités dans l'ordre fixe des traits) ;
    - les lignes des préréglages d'orientation (points normalisés par shared/team/org.lua).
  Les points des préréglages viennent de O.PRESETS : aucun chiffre recopié ici.
]]

local O = require("shared.team.org")

local M = {}

-- Onglets, dans l'ordre de la fenêtre. « Partie » : statistiques (lot PANEL-STATS). Territoire et Chantiers : « à venir »
-- (lots IA1-g et IA1-d).
M.TABS = { "equipe", "orientation", "factions", "pnj", "partie", "territoire", "chantiers" }
M.TAB_INDEX = {}
for i, k in ipairs(M.TABS) do M.TAB_INDEX[k] = i end

M.REFRESH = 60        -- ticks entre deux rafraîchissements d'une fenêtre OUVERTE (une fois par seconde au plus)
M.JOURNAL_MAX = 20    -- entrées gardées (docs §8.1 : « journal des 20 derniers événements »)
M.JOURNAL_SHOWN = 8   -- entrées montrées dans l'onglet « Mon équipe »
M.MISSING_SHOWN = 8   -- manques montrés

--- Horloge de partie « m:ss » ou « h:mm:ss » (ticks à 60 par seconde).
function M.clock(tick)
  local s = math.floor((tick or 0) / 60)
  local h = math.floor(s / 3600)
  local m = math.floor((s % 3600) / 60)
  s = s % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%d:%02d", m, s)
end

--- Minutes entières restantes (arrondi au-dessus, jamais négatif).
function M.minutes(ticks)
  if not ticks or ticks <= 0 then return 0 end
  return math.floor((ticks + 3599) / 3600)
end

---------------------------------------------------------------------------------------------------
-- Journal : différence entre deux relevés
---------------------------------------------------------------------------------------------------
--[[ Relevé (construit par script/gui/ia1i_journal.lua) :
  { team = nil | { n, max, recruited, lost, built, outposts_lost, goal, tech, orientation },
    war = { active, factions = { { key, declared, eliminated }, ... } (ordre des numéros de faction) } }
  Entrées : { kind = "...", a, b, c } ; kinds :
    team-created, team-lost, recruits (a = nouvelles, b = effectif, c = plafond), lost (a, b, c),
    outpost-built (a), outpost-lost (a), goal (a = nouvel objectif), goal-done, research (a = niveau),
    orientation (a = préréglage ou « custom »), war-started (a = factions), war-stopped,
    declared (a = clé de faction), truce (a), eliminated (a).
]]

local function delta(a, b) return (b or 0) - (a or 0) end

function M.journal_diff(prev, cur)
  local out = {}
  if not (prev and cur) then return out end
  local pt, ct = prev.team, cur.team
  if not pt and ct then
    out[#out + 1] = { kind = "team-created", a = ct.n, b = ct.max }
  elseif pt and not ct then
    out[#out + 1] = { kind = "team-lost" }
  elseif pt and ct then
    local r = delta(pt.recruited, ct.recruited)
    if r > 0 then out[#out + 1] = { kind = "recruits", a = r, b = ct.n, c = ct.max } end
    local l = delta(pt.lost, ct.lost)
    if l > 0 then out[#out + 1] = { kind = "lost", a = l, b = ct.n, c = ct.max } end
    local ob = delta(pt.built, ct.built)
    if ob > 0 then out[#out + 1] = { kind = "outpost-built", a = ob } end
    local ol = delta(pt.outposts_lost, ct.outposts_lost)
    if ol > 0 then out[#out + 1] = { kind = "outpost-lost", a = ol } end
    if ct.goal ~= pt.goal then
      if ct.goal then
        out[#out + 1] = { kind = "goal", a = ct.goal }
      else
        out[#out + 1] = { kind = "goal-done" }
      end
    end
    if (ct.tech or 0) > (pt.tech or 0) then out[#out + 1] = { kind = "research", a = ct.tech } end
    if ct.orientation ~= pt.orientation then out[#out + 1] = { kind = "orientation", a = ct.orientation } end
  end
  local pw, cw = prev.war or {}, cur.war or {}
  if cw.active and not pw.active then
    out[#out + 1] = { kind = "war-started", a = #(cw.factions or {}) }
  elseif pw.active and not cw.active then
    out[#out + 1] = { kind = "war-stopped" }
  end
  if pw.active and cw.active then
    local before = {}
    for _, f in ipairs(pw.factions or {}) do before[f.key] = f end
    for _, f in ipairs(cw.factions or {}) do
      local b = before[f.key]
      if b then
        if f.eliminated and not b.eliminated then
          out[#out + 1] = { kind = "eliminated", a = f.key }
        elseif f.declared and not b.declared then
          out[#out + 1] = { kind = "declared", a = f.key }
        elseif b.declared and not f.declared and not f.eliminated then
          out[#out + 1] = { kind = "truce", a = f.key }
        end
      end
    end
  end
  return out
end

--- Ajoute des entrées datées au journal (le plus récent à la fin), en gardant les JOURNAL_MAX dernières.
function M.journal_push(list, entries, tick)
  for _, e in ipairs(entries) do
    e.tick = tick
    list[#list + 1] = e
  end
  while #list > M.JOURNAL_MAX do table.remove(list, 1) end
  return list
end

---------------------------------------------------------------------------------------------------
-- Factions
---------------------------------------------------------------------------------------------------
--- Relation d'une faction avec vous, d'après l'état publié par PvP.status (fs) :
---   { kind = "eliminated" | "provoked" | "war" | "truce" | "truce-peaceful", minutes = n (trêve à échéance) }.
--- « truce-peaceful » : aucune fin de grâce (difficulté Paisible) ; elle n'attaque que si vous la provoquez.
function M.relation(fs, tick)
  if fs.eliminated then return { kind = "eliminated" } end
  if fs.declared then return { kind = fs.provoked and "provoked" or "war" } end
  if not fs.grace_end then return { kind = "truce-peaceful" } end
  return { kind = "truce", minutes = M.minutes(fs.grace_end - (tick or 0)) }
end

--- Les deux traits les plus forts d'un caractère (pour mille), égalités dans l'ordre `order`.
function M.salient(traits, order)
  if not traits then return {} end
  local list = {}
  for i, k in ipairs(order) do
    if traits[k] then list[#list + 1] = { key = k, v = traits[k], i = i } end
  end
  table.sort(list, function(a, b)
    if a.v ~= b.v then return a.v > b.v end
    return a.i < b.i
  end)
  local out = {}
  for i = 1, math.min(2, #list) do out[i] = list[i] end
  return out
end

--- Valeur pour mille écrite « 1,62 » (virgule décimale : texte FR et EN identiques, comme /fo-war status).
function M.permille(v)
  local n = math.floor((v or 0) / 10 + 0.5)
  return string.format("%d,%02d", math.floor(n / 100), n % 100)
end

---------------------------------------------------------------------------------------------------
-- Orientation
---------------------------------------------------------------------------------------------------
--- Lignes des préréglages : { name, pts = { extraction, base, territoire } } dans l'ordre de O.PRESET_ORDER.
function M.preset_rows()
  local rows = {}
  for _, name in ipairs(O.PRESET_ORDER) do
    rows[#rows + 1] = { name = name, pts = O.normalize(name, false) }
  end
  return rows
end

--- Préréglage courant : son nom, ou « custom » (table de points écrite par l'interface distante).
function M.current_preset(orientation)
  if type(orientation) == "string" and O.PRESETS[orientation] then return orientation end
  return "custom"
end

return M
