--- Lot RANGEES-ASM (suite) : rangée d'assembleurs DYNAMIQUE au plan directeur (règles pures : shared/team/rangee_dyn.lua).
--- Chaîne : script/ai3/rangees_asm.lua (ordre « chaine », spec.rangee) -> Build.request -> plan_project : Rg.full (gabarit à la borne,
--- place réservée) -> Rg.tag (colonne de chaque machine et de ses bras) -> plan_finish -> Rg.after/Rg.split (machines au-delà de n en
--- attente dans p.rangee.held) -> chantier ordinaire. Hausse de la demande : Rg.grow (pièces rendues à p.ents, projet « fini » rouvert
--- en « reserve », comme ligne_open de la ligne de fours) -> chantier ordinaire (réserve au coffre, fantômes, PNJ).
--- État écrit : p.rangee_plan (le temps d'un plan), p.rangee = { n, n_max, jn, order, held, steps, grown } ; lecteurs : Build.brief
--- (champ rangee), script/ai3/rangees_asm.lua. Projets d'avant ce lot (sans p.rangee) : inchangés.
local Rd = require("shared.team.rangee_dyn")
local M = require("shared.team.modules")
local Conv = require("script.team.convoyeurs")

local Rg = {}
Rg.SETTING = "fo-war-rangee-dyn"

-- Crochet du modèle (shared/team/modules.lua, M.spec) : un tapis des données inconnu du modèle (rangée posée avec un tapis plus
-- rapide, G.simple argument 5) est lu aux prototypes, identiques sur tous les postes ; mémoire LOCALE des noms qui ne sont pas des
-- tapis (jamais dans global). Voie = belt_speed × 240 (60 ticks/s × 4 objets par tuile et par voie).
local NOT_BELT = {}
M.belt_spec = function(name)
  if NOT_BELT[name] or type(name) ~= "string" then return nil end
  local ok, belts = pcall(Conv.belts) -- (tapis des prototypes, script/team/convoyeurs.lua : aucun nom écrit ici)
  if not (ok and belts) then return nil end -- (hors événement : game absent, rien n'est retenu)
  for _, bt in ipairs(belts) do
    if bt.name == name then return { kind = "belt", w = 1, h = 1, lane = (bt.speed or 0) * 240 } end
  end
  NOT_BELT[name] = true
  return nil
end
Rg.GENS = { simple = true, gears = true } -- générateurs d'UNE rangée d'assembleurs à extension « n »

--- Réglage fo-war-rangee-dyn (défaut : allumé ; absent, moteur simulé ou mod d'avant : allumé comme le défaut).
function Rg.on()
  local ok, v = pcall(function() return settings.global[Rg.SETTING].value end)
  if not ok then return true end
  return v ~= false
end

local function kind(name)
  local sp = M.spec(name)
  if not sp then return nil end
  if sp.kind == "assembler" then return "machine" end
  if sp.kind == "inserter" then return "inserter" end
  return nil
end

local function width(name)
  local sp = M.spec(name)
  return sp and sp.w or 1
end

--- Gabarit du plan : à la borne de son extension pour une rangée demandée dynamique (spec.rangee), sinon tel quel.
function Rg.full(p, g)
  p.rangee_plan = nil
  local spec = p.spec
  if not (spec and spec.rangee and g and Rg.GENS[g.gen] and Rg.on()) then return g end
  local ex = g.extensions and g.extensions[1]
  if not ex then return g end
  local n = tonumber((g.args or {})[ex.arg]) or 0
  if n < 1 or ex.max <= n then return g end
  local gm = M.extend(g, ex.max)
  if not gm then return g end
  p.rangee_plan = { n = n, n_max = ex.max, jn = (gm.params or {}).jn }
  return gm
end

--- Colonne de chaque machine et de ses bras (ents dans l'ordre de g.entities, gabarit NON tourné). Sans correspondance : rangée fixe.
function Rg.tag(p, ents, g)
  local rp = p.rangee_plan
  if not rp then return end
  if not (g and g.entities and #g.entities == #ents) then p.rangee_plan = nil return end
  local cols, m = Rd.columns(g.entities, kind, width)
  if m ~= rp.n_max then p.rangee_plan = nil return end
  for i, e in ipairs(ents) do e.col = cols[i] end
end

local function scale(t, k)
  for _, key in ipairs((function() local o = {} for x in pairs(t or {}) do o[#o + 1] = x end table.sort(o) return o end)()) do
    t[key] = t[key] * k
  end
end

--- Fin d'un plan réussi : machines au-delà de n en attente (place réservée), débits annoncés à n / n_max.
function Rg.split(f, p)
  local rp = p.rangee_plan
  p.rangee_plan = nil
  if not rp then return end
  local order = Rd.order(rp.n_max, rp.jn)
  local a = Rd.active(order, rp.n)
  local keep, held = {}, {}
  for _, e in ipairs(p.ents) do
    if e.part == 1 and e.col and not a[e.col] then held[#held + 1] = e else keep[#keep + 1] = e end
  end
  p.ents = keep
  p.rangee = { n = rp.n, n_max = rp.n_max, jn = rp.jn, order = order, held = held, steps = 0 }
  scale(p.outflow, rp.n / rp.n_max)
  scale(p.inflow, rp.n / rp.n_max)
  log(string.format("[FO-RANGEES-ASM] %s : projet %d, rangee dynamique %d/%d machine(s) posee(s)%s, %d piece(s) en attente (place de la rangee entiere reservee)",
    f.key or "player", p.id, rp.n, rp.n_max, rp.jn and " (sortie sur deux voies)" or "", #held))
end

--- plan_project : `return Build.Rangee.after(f, p, plan_finish(...))` (aucune locale de plus dans build.lua).
function Rg.after(f, p, ok, why, wait)
  if ok then Rg.split(f, p) else p.rangee_plan = nil end
  return ok, why, wait
end

--- Agrandit sur place une rangée dynamique FINIE à n2 machines : pièces rendues au chantier, projet rouvert en « reserve ».
--- Rend le nombre de pièces rendues (0 : rien à faire) et la raison.
function Rg.grow(f, id, n2, tick)
  local p = f and f.build and f.build.projects[id]
  local r = p and p.rangee
  if not r then return 0, "rangee fixe" end
  if p.state ~= "fini" or p.abandoned then return 0, "projet " .. tostring(p.state) end
  local old = r.n
  local t, add = Rd.grow(r.n, r.n_max, n2)
  if add <= 0 then return 0, "rangee pleine" end
  local a = Rd.active(r.order, t)
  local keep, moved = {}, 0
  for _, e in ipairs(r.held) do
    if a[e.col] then
      e.built, e.ghosted, e.fails, e.npc_blocks = false, nil, 0, 0
      p.ents[#p.ents + 1] = e
      moved = moved + 1
    else
      keep[#keep + 1] = e
    end
  end
  r.held, r.n = keep, t
  if moved == 0 then return 0, "aucune piece en attente" end
  r.steps, r.grown = (r.steps or 0) + 1, tick
  p.counted = true
  p.state, p.reason, p.reserve_next = "reserve", "rangee : agrandissement", nil
  p.retries, p.retry_at = 0, nil
  p.reopened = (p.reopened or 0) + 1
  if old > 0 then
    scale(p.outflow, t / old)
    scale(p.inflow, t / old)
  end
  log(string.format("[FO-RANGEES-ASM] %s : projet %d, rangee finie agrandie sur place de %d a %d machine(s) (%d piece(s) rendues au chantier, memes tapis)",
    f.key or "player", p.id, old, t, moved))
  return moved
end

--- Résumé pour Build.brief : { n, n_max, held } ou nil.
function Rg.brief(p)
  local r = p and p.rangee
  if not r then return nil end
  return { n = r.n, n_max = r.n_max, held = #r.held }
end

return Rg
