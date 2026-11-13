--[[
  Lot s42 causal (chantier 3.2 du DC) : câblage de l'arbre des causes (règle pure : shared/ai3/causal.lua).
  Appelé par l'audit des champs de CHAQUE équipe, factions et votre équipe (script/team/migration_champ.lua, juste après Champ.report : son
  horloge, Champ.REPORT_EVERY = 5 min ; jamais à chaque tick). Borné : au plus Rt.MAX_ENTS statuts d'entité lus hors du relevé des champs.

  Relevé (Rt.releve) :
    - bandes du champ : les comptes de Champ.report (foreuses, fours, pièces perdues), déjà lus par statut d'entité ;
    - avant-postes et fours de l'équipe : statut d'entité (defines.entity_status) des foreuses (o.drill_list), des fours (o.sinks, f.smelters) ;
    - courant : chaudières et génératrices des centrales finies ou rouvertes (statut « sans combustible », énergie produite au dernier
      tick), saturation décidée par la croissance (f.build.grow.saturated, script/team/plant_arms.lua) ;
    - combustible au stock de l'équipe (Stock.count), manque de la plaque clé (Famine.team_starved).
  Ordre : écrit dans f.build.causal (texte et nombres : { cle, cause, ordre, since, tick, logs }) et transmis au mécanisme correctif
  EXISTANT par le RÉVEIL de son horloge (Rt.LEVIERS) : aucune tâche n'est créée ici, aucun correctif n'est réécrit. Les leviers sans horloge
  (collecte, ravitaillement, extraction : ils relisent le terrain à chaque pensée) ne reçoivent que l'ordre écrit.
  Journal : une ligne [FO-CAUSAL] quand la cause CHANGE (jamais pour un premier état sain), au plus Rt.LOGS par équipe.
]]

local Ca = require("shared.ai3.causal")
local T = require("shared.team.config")
local M = require("shared.team.modules")
local Stock = require("script.team.stock")
local Famine = require("script.team.famine_fer")
local State = require("script.faction.state")

local Rt = {}

Rt.LOGS = 200      -- lignes [FO-CAUSAL] au plus par équipe et par partie
Rt.MAX_ENTS = 800  -- statuts d'entité lus au plus par audit hors des bandes du champ (avant-postes, fours, centrales)

--- Horloges réveillées par ordre : { table de f.build, champ } ; l'horloge n'est avancée que si elle existe et vise un tick futur.
--- grow : croissance et santé de la centrale (plant_arms.lua, PA.watch) ; raccord : raccord.lua (Ra.step) ; sante.net_next : consommateurs
--- sur îlot et poteaux perdus (reseau_vivant.lua) ; sweep : balayage de reconstruction (rebuild_sweep.lua).
Rt.LEVIERS = {
  amorcer_centrale = { { "grow", "next" } },
  agrandir_centrale = { { "grow", "next" } },
  raccorder = { { "raccord", "next" }, { "sante", "net_next" } },
  reconstruire = { { "sweep", "next" } },
}

local S_

local function compte(rub, s)
  if s == S_.working then rub.marche = rub.marche + 1
  elseif s == S_.no_power or s == S_.low_power then rub.sans_courant = rub.sans_courant + 1
  elseif s == S_.no_fuel then rub.sans_combustible = rub.sans_combustible + 1
  elseif s == S_.no_minable_resources then rub.epuisees = (rub.epuisees or 0) + 1
  elseif s == S_.waiting_for_space_in_destination or s == S_.full_output then rub.sortie_pleine = rub.sortie_pleine + 1
  elseif s == S_.no_ingredients then rub.sans_entree = (rub.sans_entree or 0) + 1 end
end

--- Relevé de l'équipe. rd : comptes de Champ.report ({ d, fu, lost }) ou nil.
function Rt.releve(f, surface, tick, rd)
  S_ = S_ or defines.entity_status
  local fr = { n = 0, marche = 0, sortie_pleine = 0, sans_courant = 0, sans_combustible = 0, epuisees = 0 }
  local fo = { n = 0, marche = 0, sans_entree = 0, sans_combustible = 0, sortie_pleine = 0, sans_courant = 0 }
  local tapis = 0
  if rd then
    local d, fu = rd.d or {}, rd.fu or {}
    fr.n, fr.marche, fr.sortie_pleine, fr.sans_courant = d.n or 0, d.run or 0, d.stuck or 0, d.nopow or 0
    fo.n, fo.marche, fo.sans_entree, fo.sans_combustible, fo.sortie_pleine = fu.n or 0, fu.run or 0, fu.noin or 0, fu.nofuel or 0, fu.full or 0
    for _, k in ipairs(State.sorted_keys(rd.lost or {})) do
      if k == "champ-tapis" then tapis = tapis + rd.lost[k] end
    end
  end
  local budget = Rt.MAX_ENTS
  -- avant-postes (foreuses, fours au gisement) et fours de l'équipe : statut d'entité, dans l'ordre des identifiants
  for _, id in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[id]
    for _, e in ipairs(o.drill_list or {}) do
      if budget <= 0 then break end
      if e.valid then budget = budget - 1; fr.n = fr.n + 1; compte(fr, e.status) end
    end
    for _, e in ipairs(o.sinks or {}) do
      if budget <= 0 then break end
      if e.valid and e.type == "furnace" then budget = budget - 1; fo.n = fo.n + 1; compte(fo, e.status) end
    end
  end
  for _, e in ipairs(f.smelters or {}) do
    if budget <= 0 then break end
    if e.valid then budget = budget - 1; fo.n = fo.n + 1; compte(fo, e.status) end
  end
  -- courant : centrales finies ou rouvertes
  local b = f.build
  local co = { generatrices = 0, kw = 0, chaudieres = 0, a_sec = 0, saturee = (b and b.grow and b.grow.saturated) and true or false }
  if b and b.projects then
    local ids, seen = {}, {}
    if b.plant then ids[1] = b.plant; seen[b.plant] = true end
    for _, pid in ipairs(b.extra_plants or {}) do
      if not seen[pid] then seen[pid] = true; ids[#ids + 1] = pid end
    end
    for _, pid in ipairs(ids) do
      local p = b.projects[pid]
      if p and (p.state == "fini" or (p.reopened and p.finished)) then
        for _, e in ipairs(p.ents or {}) do
          if budget <= 0 then break end
          local sp = M.spec(e.name) or {}
          local chaud = sp.water and sp.burner_kw
          if (chaud or sp.power_out) and not (e.dropped or e.gave_up) then
            budget = budget - 1
            local r = surface.find_entity(e.name, { e.x, e.y })
            if r and r.valid and r.force.name == f.force then
              if chaud then
                co.chaudieres = co.chaudieres + 1
                if r.status == S_.no_fuel then co.a_sec = co.a_sec + 1 end
              else
                co.generatrices = co.generatrices + 1
                co.kw = co.kw + (r.energy_generated_last_tick or 0) * 60 / 1000
              end
            end
          end
        end
      end
    end
  end
  local libre = nil
  if f.hq and f.hq.valid then libre = Stock.count(f, T.fuel) end
  return {
    plaques = { manque = Famine.team_starved(f, tick) == true },
    fours = fo, foreuses = fr, courant = co, combustible = { libre = libre }, pertes = { tapis = tapis },
  }
end

--- Transmet l'ordre : réveille les horloges du levier. Rend le texte de l'effet (journal).
function Rt.ordonner(f, v, tick)
  local b = f.build
  local o = Ca.ordre(v.ordre)
  local woke = {}
  for _, h in ipairs(Rt.LEVIERS[v.ordre] or {}) do
    local st = b[h[1]]
    if type(st) == "table" and type(st[h[2]]) == "number" and st[h[2]] > tick then
      st[h[2]] = tick
      woke[#woke + 1] = h[1] .. "." .. h[2]
    end
  end
  local levier = o and o.levier or "?"
  if #woke > 0 then return "levier : " .. levier .. " (horloge avancee : " .. table.concat(woke, ", ") .. ")" end
  return "levier : " .. levier
end

--- Audit d'une équipe : relevé, arbre, ordre et journal au changement de cause. Rend le verdict (ou nil sans plan directeur).
function Rt.audit(f, surface, tick, rd)
  local b = f and f.build
  if not (b and surface) or f.eliminated then return nil end
  local v = Ca.diagnostiquer(Rt.releve(f, surface, tick, rd))
  local st = b.causal
  if not st then st = { logs = 0 }; b.causal = st end
  st.tick = tick
  if st.cle == v.cle then return v end
  local first = st.cle == nil
  st.cle, st.cause, st.ordre, st.since = v.cle, v.cause, v.ordre, tick
  local effet = v.ordre ~= "aucun" and Rt.ordonner(f, v, tick) or nil
  if not (first and v.symptome == "sain") and st.logs < Rt.LOGS then
    st.logs = st.logs + 1
    log(Ca.ligne(f.key or "player", tick / 3600, v, effet))
  end
  return v
end

return Rt
