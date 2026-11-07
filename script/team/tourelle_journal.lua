--[[
  Lot TOURELLE-JOURNAL (7/11, retour du DC sur 0.6.58 : « j'avais posé des tourelles tout autour de la base, tourelles qu'ils ont […]
  volontairement enlevées » ; « il a de très très fortes chances que ce soit les pnj qui les aient prise mais j'ai aucune preuve »).
  JOURNAL seulement, sauf la garde du minage (script/team/worker.lua) et le secours de l'amélioration (script/levels/levels.lua) :
    [FO-TOURELLE-MORTE]   toute tourelle de la force « player » tuée, où qu'elle soit (position, tueur, distances, portées, qui l'avait
                          posée) ; au plus une ligne par seconde de jeu, les morts sautées sont comptées dans la ligne suivante ;
    [FO-TOURELLE-RETIREE] chaque chemin du script qui retire ou déplace une tourelle (qui, pourquoi, qui l'avait posée).
  « Posée par » : le joueur qui l'a construite en dernier (LuaEntity.last_user), sinon l'équipe dont le registre des tourelles la tient
  (f.turrets, script/faction/outposts.lua), sinon « inconnu ». Aucune décision n'en dépend.
]]
local Rg = require("shared.ai3.reglages")
local State = require("script.faction.state")
local Storage = require("script.core.storage")

local Tj = {}

-- Types journalisés : ceux de shared/ai3/reglages.lua, plus l'artillerie (relecture de la 0.6.59 : « toute tourelle »). La liste partagée
-- Rg.TURRET_TYPES n'est PAS modifiée : la prévision, l'espacement des avant-postes et le reste de l'IA la lisent.
local TYPES = {}
for _, ty in ipairs(Rg.TURRET_TYPES) do TYPES[#TYPES + 1] = ty end
TYPES[#TYPES + 1] = "artillery-turret"
local TURRET = {}
for _, ty in ipairs(TYPES) do TURRET[ty] = true end
Tj.TURRET = TURRET
Tj.TURRET_TYPES = TYPES

-- sec, skipped : limite des morts ; msec, mskipped : limite des minages refusés (une ligne par seconde de jeu chacune).
Storage.declare("tourelle_journal", function() return { sec = -1, skipped = 0, msec = -1, mskipped = 0 } end)

--- L'entité est-elle une tourelle (types de shared/ai3/reglages.lua) ?
function Tj.is_turret(e)
  return e ~= nil and e.valid and TURRET[e.type] == true
end

local function registry_owner(e)
  local un = e.unit_number
  if not un then return nil end
  local p = State.faction("player")
  if p and p.turrets and p.turrets[un] == e then return "equipe " .. tostring(p.key or "player") end
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and f.turrets and f.turrets[un] == e then return "faction " .. tostring(f.key or id) end
  end
  return nil
end

--- Qui avait posé la tourelle : « joueur <nom> », « equipe player », « faction <clé> » ou « inconnu ».
function Tj.placed_by(e)
  if not (e and e.valid) then return "inconnu" end
  local ok, u = pcall(function() return e.last_user end)
  if ok and u and u.valid then return "joueur " .. tostring(u.name) end
  return registry_owner(e) or "inconnu"
end

local function range_of(ent)
  local ok, r = pcall(function() return ent.prototype.attack_parameters.range end)
  return ok and r or nil
end

local function fmt(v)
  if type(v) ~= "number" then return "?" end
  return string.format("%.1f", v)
end

--- Description d'une tourelle, lue AVANT de la retirer (l'entité n'est plus valide ensuite).
function Tj.describe(e)
  if not Tj.is_turret(e) then return nil end
  return { name = e.name, x = e.position.x, y = e.position.y, force = e.force and e.force.name or "?", by = Tj.placed_by(e), range = range_of(e) }
end

--- [FO-TOURELLE-RETIREE] : `d` = Tj.describe(entité) (nil : pas une tourelle, rien n'est écrit) ; `who` : qui la retire ; `why` : pourquoi ;
--- `what` : ce qui arrive (déplacée, remplacée, perdue, refusée...).
function Tj.removed(d, who, why, what)
  if not d then return end
  log(string.format("[FO-TOURELLE-RETIREE] minute %.1f | %s (force %s, portee %s) en (%.1f, %.1f) | par %s | raison %s | %s | posee par %s",
    (game and game.tick or 0) / 3600, d.name, d.force, fmt(d.range), d.x, d.y, tostring(who), tostring(why), tostring(what or "retiree"), d.by))
end

--- Minage à la main REFUSÉ (script/team/worker.lua) : le bâtiment `ent` (tourelle ou autre) recouvre la tuile de minerai, ou la sélection du
--- PNJ n'est pas la ressource visée. Écrit pour TOUT bâtiment (tag [FO-TOURELLE-RETIREE], « minage refusé : sélection = <nom> ») ; au plus
--- une ligne par seconde de jeu (chaque PNJ pense une fois par seconde : 30 PNJ au bord d'un champ de foreuses écriraient 30 lignes par
--- seconde), les refus sautés sont comptés dans la ligne suivante.
function Tj.mine_refused(ent, who, res_name, why)
  local st = Storage.ns("tourelle_journal")
  local sec = math.floor((game and game.tick or 0) / 60)
  if st and st.msec == sec then
    st.mskipped = (st.mskipped or 0) + 1
    return
  end
  local skipped = st and st.mskipped or 0
  if st then st.msec, st.mskipped = sec, 0 end
  local d
  if ent and ent.valid then
    d = { name = ent.name, x = ent.position.x, y = ent.position.y, force = ent.force and ent.force.name or "?", by = Tj.placed_by(ent), range = range_of(ent) }
  end
  log(string.format("[FO-TOURELLE-RETIREE] minute %.1f | minage refuse : selection = %s%s | par %s | minerai %s | %s | posee par %s%s",
    (game and game.tick or 0) / 3600, d and d.name or "aucune", d and string.format(" (force %s) en (%.1f, %.1f)", d.force, d.x, d.y) or "",
    tostring(who), tostring(res_name), tostring(why), d and d.by or "?",
    skipped > 0 and string.format(" | %d refus non journalise(s) depuis la ligne precedente (une ligne par seconde)", skipped) or ""))
end

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

--- [FO-TOURELLE-MORTE] (appelé par script/team/qg_tourelle.lua à chaque mort) : toute tourelle de la force « player », au plus une ligne
--- par seconde de jeu.
function Tj.died(e)
  local ent = e.entity
  if not (Tj.is_turret(ent) and ent.force and ent.force.name == "player") then return end
  local st = Storage.ns("tourelle_journal")
  local sec = math.floor(e.tick / 60)
  if st then
    if st.sec == sec then
      st.skipped = st.skipped + 1
      return
    end
  end
  local skipped = st and st.skipped or 0
  if st then st.sec, st.skipped = sec, 0 end
  local pos = ent.position
  local p = State.faction("player")
  local hq = p and (p.hq_pos or (p.hq and p.hq.valid and p.hq.position))
  local c = e.cause
  local cause = "inconnu"
  if c and c.valid then
    cause = string.format("%s/%s/%s a %.1f tuiles (portee de son attaque %s)", c.name, c.type, c.force and c.force.name or "?",
      dist(c.position, pos), fmt(range_of(c)))
  end
  log(string.format("[FO-TOURELLE-MORTE] minute %.1f | %s (portee %s) en (%.1f, %.1f)%s | cause %s, degats %s | posee par %s%s",
    e.tick / 3600, ent.name, fmt(range_of(ent)), pos.x, pos.y, hq and string.format(", a %.1f tuiles du coffre d'equipe", dist(pos, hq)) or "",
    cause, e.damage_type and e.damage_type.name or "?", Tj.placed_by(ent),
    skipped > 0 and string.format(" | %d mort(s) de tourelle non journalisee(s) depuis la ligne precedente (une ligne par seconde)", skipped) or ""))
end

return Tj
