--[[
  Lot DÉCOUPAGE-PENSÉE (7/11, accord du lead ; DC : « des freezes [...] d'une demi-seconde [...] très périodique ») : une pensée
  d'équipe (script/team/team.lua, Team.think) se joue en HUIT étapes (E.STAGES), E1a au tick T, puis une par tick jusqu'à E6 à
  T + 7, au lieu d'un seul tick. L'ordre des appels est gardé ; seuls les ticks changent (critères :
  fo-logs/2026-11-07_DECOUPAGE-PENSEE/CRITERES.md et CRITERES-E1-E4.md).

  E1a garde une copie ENTIÈRE de la vue (E.keep) et la sortie du plan du cerveau, L (Ia3.plan_a, champs de E.L), pour E1b
  (capitalisation, L.capi) et E1c (reste du plan). E2 et E3 ne lisent ni la vue ni le plan. E4 à E6 (marché, stock, recrues,
  armée, pièces, foreuses, champ, capital, fin) les lisent : ils reçoivent une COPIE, gardée dans global de E1c à E6, des seuls
  champs listés ici (E.VIEW, E.PLAN). Les listes sont relevées par la lecture du code et par un passage d'enregistrement
  (tests/decoupage_pensee_test.lua) ; en test, les copies sont STRICTES (lire un champ absent de la liste lève une erreur) et chaque
  champ retiré à tour de rôle doit faire échouer le test.

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

--- Étapes d'une pensée, dans l'ordre (une par tick). L'état gardé porte le numéro de la PROCHAINE (2 = E1b … 8 = E6).
E.STAGES = { "E1a", "E1b", "E1c", "E2", "E3", "E4", "E5", "E6" }

--- Clés de L : sortie d'Ia3.plan_a (script/ai3/cerveau.lua), plus `capi` (Ia3.plan_capi), lues par Ia3.plan_b. Liste TRIÉE.
E.L = { "army_target", "at_war", "auto", "capi", "floor_item", "harvest", "home", "iron_floor", "key", "known", "mines_open",
  "reach", "research", "spare_hands", "w" }

--- Signature des étapes et des listes, gardée avec chaque pensée en cours (script/team/team.lua, TT.config_changed) : une autre
--- signature au changement de configuration efface l'état (une étape ne rejoue pas un état d'une autre version : autres étapes,
--- ou copies aux champs d'une autre version).
E.SIG = "etapes:" .. table.concat(E.STAGES, ",") .. "|view:" .. table.concat(E.VIEW, ",") .. "|plan:" .. table.concat(E.PLAN, ",")
  .. "|L:" .. table.concat(E.L, ",")

--- Champs lus seulement dans des branches RARES : relevés par la lecture du code, qu'une courte partie peut ne pas atteindre. Le
--- banc les dit à part au lieu de les compter comme inutiles.
--- - view.workers_idle : `view.workers_waiting or view.workers_idle` (workers_waiting absent seulement pour une vue sans tableau) ;
--- - view.emergency, view.recover_floor : journal d'une recrue de survie (plan.recruit_uses) ;
--- - plan.emergency_recruit : recrue de croissance d'une faction (Effectif.grown) ;
--- - plan.emergency_unarmed : recrue sans arme quand il reste au plus un PNJ.
--- Clés de L (mutants de 10 min du banc, L non strict ; relevé des valeurs du 7/11, 602 copies, tests/decoupage_pensee_test.lua) dont
--- l'absence (nil) ne change rien sur la partie du banc, et pourquoi :
--- - L.at_war : faux toute la partie (aucune guerre déclarée au joueur) ; Ia3.plan_b lit `at_war and true or false` : nil = faux ;
--- - L.home : vrai sauf aux 13 premières pensées ; nil vaut vrai (`home ~= false`), et à ces pensées aucune exploration n'est
---   demandée (le seul effet de faux : vider E.explore) ;
--- - L.floor_item : iron-plate toute la partie, qui est aussi le repli de la règle (`ctx.floor_item or P.IRON`) sur ces données ;
--- - L.known : 4 gisements connus, tous dans la portée (L.reach) ; known ne sert qu'à ne pas explorer un gisement connu hors portée ;
--- - L.harvest : [] ou [wood], et aucun but ne demande de bois en 10 min (le seul effet : marquer le bois récoltable) ;
--- - L.capi : la capitalisation est éteinte au montage du banc, et allumée (FO_CAPI=1) elle n'ouvre AUCUN ordre en 10 min (50
---   décisions, « ouverts=0 ») : ses buts (Ca.goals des ordres ouverts) et ses tâches sont vides.
E.RARES = { ["view.workers_idle"] = true, ["view.emergency"] = true, ["view.recover_floor"] = true,
  ["plan.emergency_recruit"] = true, ["plan.emergency_unarmed"] = true,
  ["L.at_war"] = true, ["L.home"] = true, ["L.floor_item"] = true, ["L.known"] = true, ["L.harvest"] = true, ["L.capi"] = true }

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

--- Copie entière gardable dans global : rend (copie, fonctions laissées, nom de la copie s'il y en a).
function E.keep(v, name)
  local st = { lost = 0, cur = name }
  local c = copy(v, {}, st)
  return c, st.lost, st.lost > 0 and name or nil
end

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

--- Champs de la vue et de L qui SONT des tables de global (sonde du test, mode « sonde ») : gardés PAR RÉFÉRENCE, pas copiés. Une copie
--- couperait les écritures faites par la suite de la pensée à travers eux (la table vivante et la copie divergeraient) ; une référence
--- garde le sens d'avant le découpage, et global garde les références partagées à la sauvegarde (doc 1.1.91, auxiliary/global.html :
--- « Circular references are handled properly »). Vue : f.team.deferred, f.team.done (Team.view). L : f.team.iag.key (General.key),
--- f.team.ia3.known et f.team.ia3.reach (reach_of).
E.REF_VIEW = { "deferred", "done" }
E.REF_L = { "key", "known", "reach" }

--- État gardé de E1a : copie ENTIÈRE de la vue et copie des clés de L listées dans E.L (L nil : bascule éteinte), d'une seule copie
--- (mémo partagé : une table commune à la vue et à L le reste) ; champs de E.REF_VIEW et E.REF_L gardés par référence. Rend (vue, L,
--- fonctions laissées, champ où était la première).
function E.keep_e1(view, L)
  local memo, st = {}, { lost = 0, cur = "vue" }
  for _, k in ipairs(E.REF_VIEW) do
    local v = view and view[k]
    if type(v) == "table" then memo[v] = v end
  end
  for _, k in ipairs(L and E.REF_L or {}) do
    local v = L[k]
    if type(v) == "table" then memo[v] = v end
  end
  local v = copy(view, memo, st)
  local l = L and pick(L, E.L, memo, "L", st) or nil
  return v, l, st.lost, st.where
end

local function guard(t, keys, name, where)
  local ok = {}
  for _, k in ipairs(keys) do ok[k] = true end
  return setmetatable(t, { __index = function(_, k)
    if not ok[k] then error("etapes : champ non garde lu en " .. where .. " : " .. name .. "." .. tostring(k), 2) end
    return nil
  end })
end

--- Tests : rend la copie STRICTE (lire un champ hors liste lève une erreur ; un champ listé peut valoir nil).
function E.strict(fz)
  guard(fz.view, E.VIEW, "view", "E4")
  guard(fz.plan, E.PLAN, "plan", "E4")
  return fz
end

--- Tests : L STRICT (lire une clé hors E.L lève une erreur).
function E.strict_L(L)
  return guard(L, E.L, "L", "E1c")
end

return E
