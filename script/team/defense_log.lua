--[[
  Lot DEFENSE-FACTIONS D1 : journal des BLOCAGES de la défense d'une équipe (audit tourelles-danger du 29/10 : « les factions sans fer
  ne posent jamais les tourelles du front » était déduit du code, jamais lu au journal). LECTURE SEULE : aucune décision n'en dépend.

  Une ligne [FO-DEFENSE] au plus toutes les Fr.LOG_EVERY ticks (5 min) par équipe, quand un poste de défense (le QG, un avant-poste, la
  centrale, le front) manque de tourelles et n'est pas servi, ou qu'une cellule attaquée du front n'a pas de pose. Elle dit la CAUSE :
    recette  : la tourelle n'est ni au stock ni fabricable (recherche pas faite) ;
    fer      : le fer (ou le cuivre) au-dessus du plancher ne paie ni la commande complète ni la commande partielle (chiffres écrits) ;
    manque   : fabrication refusée, matière qui manque (écrite) ;
    tache    : la tâche « fortify » du poste est déjà prise ; « libre » : au tableau sans PNJ (porte, bras, repos) ;
    cellule  : repos / refus du moteur (ennemi sur place, aucun bâtiment à portée) / plafond / servie, pour chaque cellule du front.
  Et un cumul par cause (nombre de pensées), pour voir ce qui domine sur une longue partie.
  Le bilan de la porte des tâches (gate_why) est écrit par script/ai3/comportement.lua (M.gate_report), appelé d'ici.
  État : f.team.def_log_t (tick de la dernière ligne), f.team.def_why (cumul, nombres) ; créés ici en événement, jamais à on_load.
]]
local Fr = require("shared.team.front")
local T = require("shared.team.config")
local Board = require("script.team.board")

local D = {}

local function sorted(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function fmt_raw(raw)
  local out = {}
  for _, k in ipairs(sorted(raw)) do out[#out + 1] = k .. " " .. math.ceil(raw[k]) end
  return table.concat(out, ", ")
end

local BLOCKED = { recette = true, fer = true, manque = true }

--- Appelé à chaque pensée d'équipe, après le plan. `plan.defend.posts` : voir shared/team/planner.lua (D1).
function D.think(f, view, plan, tick)
  local team = f.team
  if not team then return end
  -- Bilan de la porte des tâches (script/ai3/comportement.lua), à son propre rythme.
  local C = package.loaded["script.ai3.comportement"]
  if C and C.gate_report then C.gate_report(f, tick) end
  local defend = plan and plan.defend
  local posts = defend and defend.posts or {}
  local rows = f.front_mem and f.front_mem.rows or nil
  local blocked = {}
  for _, p in ipairs(posts) do
    if BLOCKED[p.why] then blocked[#blocked + 1] = p end
  end
  local cells = {}
  for _, r in ipairs(rows or {}) do
    if r.missing > 0 then cells[#cells + 1] = r end
  end
  if #blocked == 0 and #cells == 0 then return end
  -- cumul par cause (une unité par pensée)
  local why = team.def_why
  if not why then
    why = {}
    team.def_why = why
  end
  for _, p in ipairs(blocked) do
    local k = p.id .. ":" .. p.why
    why[k] = (why[k] or 0) + 1
  end
  for _, r in ipairs(cells) do
    local k = "cellule:" .. (r.skip or "choisie")
    why[k] = (why[k] or 0) + 1
  end
  if team.def_log_t and tick - team.def_log_t < Fr.LOG_EVERY then return end
  team.def_log_t = tick
  local stock = view.stock or {}
  local iron, copper = stock[T.outposts.iron.product] or 0, stock[T.outposts.copper.product] or 0
  local ptxt = {}
  for _, p in ipairs(posts) do
    local s = string.format("%s %d/%d %s", p.id, p.have, p.want, p.why)
    if p.floor_i then
      s = s .. string.format(" (plancher fer %d cuivre %d%s%s)", p.floor_i, p.floor_cu or 0, p.reduced and ", reduit" or "", p.partial and ", partielle" or "")
    end
    if p.raw and next(p.raw) ~= nil then s = s .. " [manque " .. fmt_raw(p.raw) .. "]" end
    ptxt[#ptxt + 1] = s
  end
  local ctxt = {}
  for i, r in ipairs(cells) do
    if i > 4 then break end
    ctxt[#ctxt + 1] = string.format("%s %s score %d tourelles %d/%d %s", r.key, r.kind, r.score or 0, r.have, r.want, r.skip or "choisie")
  end
  local task = Board.get(f).tasks["fortify:front"]
  local task_txt = task == nil and "absente" or (task.worker and "prise" or "libre")
  local why_txt = {}
  for _, k in ipairs(sorted(why)) do why_txt[#why_txt + 1] = k .. "=" .. why[k] end
  log(string.format("[FO-DEFENSE] %s a %.1f min : fer %d, cuivre %d, tourelle fabricable %s, tourelles du QG %d (voulues %s), front pose %d ; postes [%s] ; cellules [%s] ; tache front %s ; cumul des pensees {%s}",
    f.key or "player", tick / 3600, iron, copper, tostring(defend and defend.craftable or false), view.hq_turrets or 0,
    tostring(view.hq_defend), f.front_mem and f.front_mem.placed or 0, table.concat(ptxt, " ; "), table.concat(ctxt, " ; "), task_txt,
    table.concat(why_txt, ", ")))
end

return D
