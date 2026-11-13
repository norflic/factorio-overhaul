--[[
  Lot S42-DEFENSE (chantier 6.1) : runtime du BUDGET DE DÉFENSE DYNAMIQUE (règle pure : shared/ai3/budget_defense.lua).
  Écrit : f.def_budget = { v, t, tier, logs } (nombres et chaînes ; absent d'une ancienne sauvegarde : créé à la première perte ou à la
  première lecture, toujours en événement, jamais en on_load).
  Appelants : script/faction/commander.lua (une entité de l'équipe meurt : BdRt.note) ; script/ai3/capitalisation.lua (build_input :
  BdRt.share, la part δ de la décision) ; script/ai3/pilotage.lua (plafond de la réserve de la famille armée).
  La classe d'une perte se lit au ROLE du type du prototype (R.ENTITY_ROLE, jamais un nom) : tourelles, courant, laboratoire = critique ; mur = rien.
  Journal [FO-BUDGET-DEFENSE] : une ligne par changement de palier (base, alerte, crise), BdRt.LOGS au plus par équipe.
]]

local Bd = require("shared.ai3.budget_defense")
local Rg = require("shared.ai3.reglages")

local BdRt = {}

BdRt.LOGS = 200

-- Classe d'une perte, lue au ROLE du type (shared/ai3/reglages.lua, R.ENTITY_ROLE) : courant, laboratoire et tourelles = critique ;
-- le reste du role militaire (murs, portes) ne pese rien ; tout autre type = piece ordinaire.
local ROLE_CLASS = { pompe = "critique", chauffe = "critique", generateur = "critique", labo = "critique" }

local function class_of(ty)
  local role = Rg.ENTITY_ROLE[ty]
  if role == "militaire" then return ty:find("turret", 1, true) and "critique" or "mur" end
  return ROLE_CLASS[role] or "piece"
end

local function state(f)
  local st = f.def_budget
  if not st then st = Bd.new() f.def_budget = st end
  return st
end

local function line(f, st, tick, share, why)
  local tier = Bd.tier(share)
  if tier == (st.tier or "base") then return end -- etat neuf : palier de base, sans ligne
  st.tier = tier
  st.logs = (st.logs or 0) + 1
  if st.logs > BdRt.LOGS then return end
  log(string.format("[FO-BUDGET-DEFENSE] %s : part de la defense %d pour mille (palier %s) a %.1f min : %s ; niveau de pertes %.1f / %d, retour a la base dans %.1f min sans perte nouvelle",
    tostring(f.key or (f.is_player and "player") or "?"), share, tier, tick / 3600, tostring(why), Bd.level(st, tick), Bd.FULL,
    Bd.calm_in(st, tick) / 3600))
end

--- Une entité de l'équipe vient de mourir (événement).
function BdRt.note(f, entity, tick)
  if not (Bd.ON and f and not f.is_player and entity and entity.valid) then return end
  local st = state(f)
  local class = class_of(entity.type)
  Bd.note(st, tick, class)
  line(f, st, tick, Bd.share(st, tick), "perte de " .. tostring(entity.name) .. " (" .. class .. ")")
end

--- Part de la défense (‰) pour la décision de capitalisation ; nil : règle coupée (la part du caractère, comme avant).
function BdRt.share(f, tick)
  if not (Bd.ON and f and not f.is_player) then return nil end -- votre equipe : la part du caractere (ses pertes ne passent pas par le commandant)
  local st = state(f)
  local share = Bd.share(st, tick)
  line(f, st, tick, share, "calme mesure")
  return share
end

return BdRt
