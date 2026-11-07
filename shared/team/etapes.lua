--[[
  Lot DÉCOUPAGE-PENSÉE (7/11, accord du lead ; DC : « des freezes [...] d'une demi-seconde [...] très périodique ») : une pensée
  d'équipe (script/team/team.lua, Team.think) se joue en QUATRE étapes, E1 au tick T, E2 à T + 1, E3 à T + 2, E4 à T + 3, au lieu
  d'un seul tick. L'ordre des appels est gardé ; seuls les ticks changent.

  E2 et E3 ne lisent ni la vue ni le plan de la pensée. E4 (marché, stock, recrues, armée, pièces, champ, capital, fin) les lit :
  il reçoit une COPIE, gardée dans global entre T et T + 3, des seuls champs listés ici (E.VIEW, E.PLAN). Les listes sont relevées
  par la lecture du code d'E4 et par un passage d'enregistrement (tests/decoupage_pensee_test.lua) ; en test, la copie est STRICTE
  (lire un champ absent de la liste lève une erreur) et chaque champ retiré à tour de rôle doit faire échouer le test.

  Lua PUR : aucune dépendance au moteur. Les objets du moteur (LuaEntity…) ne sont pas copiés : gardés tels quels (en 1.1, une
  table au champ brut `__self` ; au moteur simulé, `_lua_object`).
]]
local E = {}

--- Champs de la vue (Team.view) lus par E4 (Team.measure, Team.effectif_journal et Team.plafond_journal compris). Liste TRIÉE.
--- Relevé du 7/11 : lecture de TT.e4 et des fonctions qui reçoivent `view`, et passage d'enregistrement de 10 min.
E.VIEW = { "effectif", "emergency", "grow_due", "iron_reserve", "recover_floor", "recruit_cost", "stock", "threatened", "workers",
  "workers_idle", "workers_waiting", "workers_wanted" }

--- Champs du plan lus par E4. `ia3` (plan.ia3.pay) est lu par Capital.pay et Recon.upgrade_stock ; Ia3.measure reçoit le plan
--- sans le lire. Liste TRIÉE.
E.PLAN = { "emergency_recruit", "emergency_unarmed", "grow_short", "ia3", "missing", "recruit_blocked", "recruit_held",
  "recruit_unarmed", "recruit_uses", "recruit_workers", "research", "train" }

--- Signature des deux listes, gardée avec chaque pensée en cours (script/team/team.lua, TT.config_changed) : une autre signature
--- au changement de configuration efface l'état (E4 ne rejoue pas une copie aux champs d'une autre version).
E.SIG = "view:" .. table.concat(E.VIEW, ",") .. "|plan:" .. table.concat(E.PLAN, ",")

--- Champs lus seulement dans des branches RARES : relevés par la lecture du code, qu'une courte partie peut ne pas atteindre. Le
--- banc les dit à part au lieu de les compter comme inutiles.
--- - view.workers_idle : `view.workers_waiting or view.workers_idle` (workers_waiting absent seulement pour une vue sans tableau) ;
--- - view.emergency, view.recover_floor : journal d'une recrue de survie (plan.recruit_uses) ;
--- - plan.emergency_recruit : recrue de croissance d'une faction (Effectif.grown) ;
--- - plan.emergency_unarmed : recrue sans arme quand il reste au plus un PNJ.
E.RARES = { ["view.workers_idle"] = true, ["view.emergency"] = true, ["view.recover_floor"] = true,
  ["plan.emergency_recruit"] = true, ["plan.emergency_unarmed"] = true }

local function is_object(v)
  return rawget(v, "__self") ~= nil or rawget(v, "_lua_object") ~= nil
end

--- Copie profonde des DONNÉES (tables simples) ; objets du moteur gardés par référence ; une table partagée reste partagée dans la
--- copie (mémo). Une fonction n'est pas gardable dans global : elle est LAISSÉE de côté et comptée (st.lost, st.where : champ de
--- tête où elle était) ; E.STRICT (tests) en fait une erreur.
E.STRICT = false
local function copy(v, memo, st)
  local tv = type(v)
  if tv == "function" then
    if E.STRICT then error("etapes : fonction dans la copie (" .. st.cur .. ")") end
    st.lost = st.lost + 1
    st.where = st.where or st.cur
    return nil
  end
  if tv ~= "table" or is_object(v) then return v end
  if memo[v] then return memo[v] end
  local c = {}
  memo[v] = c
  for k, x in pairs(v) do
    local ck = copy(k, memo, st)
    if ck ~= nil then c[ck] = copy(x, memo, st) end
  end
  return c
end
E.copy = function(v) return copy(v, {}, { lost = 0, cur = "?" }) end

--- Copie des champs listés de `src` (liste `keys`), une table neuve ; `memo` partagé entre la vue et le plan.
local function pick(src, keys, memo, name, st)
  local out = {}
  for _, k in ipairs(keys) do
    st.cur = name .. "." .. k
    out[k] = copy(src[k], memo, st)
  end
  return out
end

--- État gardé d'E1 à E4 : { ia3, view, plan, lost (fonctions laissées), lost_where }, données seules (gardable dans global).
function E.freeze(view, plan, ia3)
  local memo, st = {}, { lost = 0 }
  local fz = { ia3 = ia3, view = pick(view or {}, E.VIEW, memo, "view", st), plan = pick(plan or {}, E.PLAN, memo, "plan", st) }
  if st.lost > 0 then fz.lost, fz.lost_where = st.lost, st.where end
  return fz
end

--- Tests : rend la copie STRICTE (lire un champ hors liste lève une erreur ; un champ listé peut valoir nil).
function E.strict(fz)
  local function guard(t, keys, name)
    local ok = {}
    for _, k in ipairs(keys) do ok[k] = true end
    return setmetatable(t, { __index = function(_, k)
      if not ok[k] then error("etapes : champ non garde lu en E4 : " .. name .. "." .. tostring(k), 2) end
      return nil
    end })
  end
  guard(fz.view, E.VIEW, "view")
  guard(fz.plan, E.PLAN, "plan")
  return fz
end

return E
