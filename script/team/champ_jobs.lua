--[[
  Lot CHAMP-TRANCHES (7/11, accord du lead ; contrat de champ3 : Ch.plan_job, Ch.plan_step) : le plan d'un champ (shared/team/champ.lua,
  Ch.plan) ne se calcule plus d'un bloc dans le tick de son appelant (migration du champ en E4 de la pensée d'équipe, site « champ » du
  plan directeur) : il devient un TRAVAIL du registre, avancé à chaque tick (Events.on_nth_tick(1) : pas de dépendance à l'ordonnanceur ni à
  defines, pour les bancs hors jeu qui chargent ce module seul), Jobs.UNITS unités de travail par tick (jamais un temps mesuré), un travail à la fois, dans l'ordre d'arrivée (FIFO).

  Jobs.get(f, key, kind, make) : rend le résultat REPRIS (retiré du registre) quand le travail est fini ; sinon (nil, "calcul"), en
  créant le travail au premier appel (make() rend spec, names, sibs, ou nil et la raison, rendue telle quelle). Le résultat est
  { spec, names, sibs, p, why } : la spec est l'INSTANTANÉ pris à la création (le terrain peut avoir changé à la reprise).
  Ménage : résultat non repris en Jobs.TTL ticks, équipe disparue, changement de configuration (le code de Ch peut avoir changé) :
  travaux jetés, une ligne [FO-CHAMP-TRAVAUX] au journal. Jobs.ON = false : Ch.plan d'un bloc (ancien comportement).
  Critères : fo-logs/2026-11-07_CHAMP-TRANCHES/CRITERES.md.
]]
local Storage = require("script.core.storage")
local Profiler = require("script.core.profiler")
local Events = require("script.core.events")
local State = require("script.faction.state")
local Ch = require("shared.team.champ")

local Jobs = {}
Jobs.ON = true
Jobs.UNITS = 3 * Ch.STEP_BUDGET -- unités de travail par tick (contrat de champ3 : 1 unité ≈ 1 000 instructions Lua). Mesuré le 7/11
-- (tests/champ_jobs_test.lua, T3) : le pire pas est fait d'UNE unité lourde (r30 + rivière, souterrain rapide : 1,26 M d'instructions au
-- budget 50, 1,29 M à 150) ; le budget ne le borne pas, il règle seulement l'attente (3 pas du contrat par tick).
Jobs.TTL = 1800 -- ticks : un résultat fini que personne ne reprend est jeté
Jobs.SCOPE = { frame = "champ:frame-plan", band = "champ:band-plan" }

Storage.declare("champjobs", function()
  return { jobs = {}, queue = {}, done = {}, stats = { created = 0, taken = 0, steps = 0, expired = 0, orphans = 0, reset = 0 } }
end)

local function ns() return Storage.ns("champjobs") end

local function team_id(f) return f.is_player and "player" or f.id end

local function team_alive(tid)
  if tid == "banc" then return true end -- travaux du micro-banc (interface « fo-champ-travaux » ci-dessous)
  local f = State.faction(tid)
  return f ~= nil and not f.eliminated and f.hq ~= nil and f.hq.valid
end

local function say(text)
  log("[FO-CHAMP-TRAVAUX] " .. text)
end

--- Clé complète d'un travail : équipe + clé de l'appelant.
local function full_key(f, key) return tostring(team_id(f)) .. "|" .. key end

--- Le travail `key` de l'équipe `f` : résultat repris, ou (nil, "calcul"), ou (nil, raison de make).
function Jobs.get(f, key, kind, make)
  local S = ns()
  local k = full_key(f, key)
  local rec = S.jobs[k]
  if rec then
    if not rec.ready then return nil, "calcul" end
    S.jobs[k] = nil
    S.stats.taken = S.stats.taken + 1
    return rec
  end
  local spec, names, sibs = make()
  if not spec then return nil, names end
  rec = { key = k, team = team_id(f), kind = kind, spec = spec, names = names, sibs = sibs, job = Ch.plan_job(spec),
    created = game.tick, ready = false }
  S.jobs[k] = rec
  S.queue[#S.queue + 1] = k
  S.stats.created = S.stats.created + 1
  return nil, "calcul"
end

--- Un tick de la voie : la tête de file avance de Jobs.UNITS unités ; ménage des résultats périmés.
function Jobs.tick(tick)
  local S = ns()
  if not S or (#S.queue == 0 and #S.done == 0) then return end
  -- tête de file valide (travaux jetés ou équipe disparue : retirés)
  while #S.queue > 0 do
    local k = S.queue[1]
    local rec = S.jobs[k]
    if rec and not rec.ready and team_alive(rec.team) then break end
    table.remove(S.queue, 1)
    if rec and not rec.ready then
      S.jobs[k] = nil
      S.stats.orphans = S.stats.orphans + 1
      say(string.format("travail %s jete : equipe disparue (cree au tick %d)", k, rec.created))
    end
  end
  local k = S.queue[1]
  if k then
    local rec = S.jobs[k]
    local scope = Jobs.SCOPE[rec.kind] or "champ:plan"
    Profiler.fstart(scope)
    local fin = Ch.plan_step(rec.job, Jobs.UNITS)
    Profiler.fstop(scope)
    rec.steps = (rec.steps or 0) + 1
    S.stats.steps = S.stats.steps + 1
    if fin then
      rec.p, rec.why, rec.ready, rec.ready_tick = rec.job.p, rec.job.why, true, tick
      rec.job = nil
      table.remove(S.queue, 1)
      S.done[#S.done + 1] = k
    end
  end
  -- ménage : résultats finis non repris au-delà du TTL (la liste `done` est dans l'ordre de fin)
  local keep = {}
  for _, dk in ipairs(S.done) do
    local rec = S.jobs[dk]
    if rec and rec.ready then
      if tick - rec.ready_tick > Jobs.TTL then
        S.jobs[dk] = nil
        S.stats.expired = S.stats.expired + 1
        say(string.format("resultat %s jete : non repris en %d ticks (pret au tick %d)", dk, Jobs.TTL, rec.ready_tick))
      else
        keep[#keep + 1] = dk
      end
    end
  end
  S.done = keep
end

Events.on_nth_tick(1, function(e) Jobs.tick(e.tick) end)

--- Changement de configuration : tous les travaux sont jetés (le code du plan peut avoir changé d'une version à l'autre).
function Jobs.reset(why)
  local S = ns()
  if not S then return end
  local n = 0
  for _ in pairs(S.jobs) do n = n + 1 end -- (compte seul : ordre sans effet)
  if n > 0 then
    say(string.format("%d travail(aux) jete(s) : %s", n, why))
    S.stats.reset = S.stats.reset + n
  end
  S.jobs, S.queue, S.done = {}, {}, {}
end
Events.on_configuration_changed(function() Jobs.reset("changement de configuration") end)

--- Micro-banc en jeu (C7a, scénario champ-tranches du mod de test) : des specs du corpus de champ3 soumises au registre sous l'équipe
--- « banc » ; le banc compare le plan repris à Ch.plan sur la même spec, et lit le coût de chaque pas au détail du profileur
--- (portées champ:frame-plan, champ:band-plan). Ne sert qu'aux bancs.
if remote and remote.add_interface then
  local BANC = { id = "banc" }
  remote.add_interface("fo-champ-travaux", {
    soumettre = function(key, kind, spec)
      local rec, why = Jobs.get(BANC, key, kind, function() return spec, {}, {} end)
      return rec == nil and why or "pret"
    end,
    reprendre = function(key, kind)
      local rec, why = Jobs.get(BANC, key, kind, function() return nil, "aucun travail" end)
      if not rec then return { pending = true, why = why } end -- (remote.call ne rend qu'une valeur)
      return { p = rec.p, why = rec.why, created = rec.created, ready_tick = rec.ready_tick, steps = rec.steps }
    end,
    etat = function() return Jobs.state() end,
  })
end

--- Bancs : état du registre (en cours, prêts, comptes).
function Jobs.state()
  local S = ns()
  local ready = 0
  for _, dk in ipairs(S.done) do if S.jobs[dk] then ready = ready + 1 end end
  return { queued = #S.queue, ready = ready, stats = S.stats }
end

return Jobs
