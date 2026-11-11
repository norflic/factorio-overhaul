--[[
  Lot ACIER (directive du DC, 8/11, 17 h 20 : « Plus aucun PNJ ne doit alimenter des fours à acier manuellement dès que les ressources
  (convoyeurs, bras) permettent de construire cette ligne automatisée »), côté RUNTIME. Règle pure : shared/team/acier.lua (lire son en-tête).

  Appelé une fois par pensée d'équipe, à l'étape E1c (script/team/team.lua), APRES le plan (planificateur ou cerveau, bancs compris) et AVANT le
  filtre des tournées de fonte :
    1. DEMANDE : l'acier demandé à la main (plan.smelt) pendant Ac.CONFIRM pensées de suite fait demander une rangée DYNAMIQUE de fours
       (G.simple avec le meilleur four dont les objets se fabriquent, shared/team/modules.lua) par la voie des rangées d'assembleurs
       (script/ai3/rangees_asm.lua : agrandir sur place ou rangée neuve ; Auto.submit -> Build.request, spec.rangee). L'entrée est un quai de
       plaques de fer que la liaison ou le piquage (script/team/liaison.lua, piquage.lua) relient à un tapis quand cela paie ; la sortie est un
       coffre tampon, vidé par les collectes ordinaires du plan directeur. La rangée grandit avec la demande (Ac.ask). Les bras sont électriques :
       le bloc attend la centrale FINIE de l'équipe (il ne la fait pas demander à lui seul) ; menace : aucune demande.
    2. TRANSITION : quand un bloc fini produit (rate_meas des fours de la rangée, mesuré chaque minute par script/ai3/automatisation.lua) au
       moins ce que l'équipe demande, l'acier est RETIRE du plan : plan.smelt et les tâches « smelt » (une tournée qui n'avait que l'acier
       à fondre disparaît si aucune sortie ni aucun combustible ne l'appelle). Reprise sous la moitié du seuil (hystérésis) ; mode survie exempté.
  État : f.team.acier (nombres, chaînes, booléens ; créé ici, en événement, jamais à on_load). Journal [FO-ACIER] : une ligne par changement.
  Réglage de carte fo-war-acier (settings/acier.lua, absent : allumé). Éteint : le plan reste tel quel (comportement d'avant).
  Aucun nom d'objet écrit ici : les produits viennent de Ac.ITEMS (T.smelter_inputs), les fours de M.BASE (kind « furnace », du plus rapide au plus lent).
  Lot COLONNES (chantier 6 du DC, 11/11) : une COLONNE DÉDIÉE par produit de Ac.ITEMS (acier, briques), état f.team.acier.by[produit] ; la
  recette vient du prototype quand le modèle ne l'a pas ; une colonne neuve se pose vers la SOURCE de son entrée (coffre de sortie d'un projet
  fini qui la contient : le bout de la colonne de fer pour l'acier, la fonderie à coffres de la pierre pour les briques), hors gisement par la
  règle des lots : la liaison de quai la sert par tapis, souterrains compris. Remplace la fonte des briques et de l'acier aux fours du QG.
]]

local Ac = require("shared.team.acier")
local M = require("shared.team.modules")
local State = require("script.faction.state")
local Auto = require("script.ai3.automatisation")
local RaRt = require("script.ai3.rangees_asm")
local Capi = require("script.ai3.capitalisation")
local Harvest = require("script.team.harvest")
local Survie = require("script.team.survie")
local T = require("shared.team.config")

local Acier = {}
Acier.SETTING = "fo-war-acier"

--- Réglage fo-war-acier (défaut : allumé ; absent, moteur simulé ou mod d'avant : allumé comme le défaut).
function Acier.on()
  local ok, v = pcall(function() return settings.global[Acier.SETTING].value end)
  if not ok then return true end
  return v ~= false
end

local function state_of(f, item)
  local t = f.team
  t.acier = t.acier or {}
  t.acier.by = t.acier.by or {}
  t.acier.by[item] = t.acier.by[item] or { count = 0, retry_at = 0, said = {}, cut = false, since = nil, dropped = 0, finished = 0 }
  return t.acier.by[item]
end

local function minutes(f, tick)
  local war = State.war()
  return (tick - (f.started or (war and war.started) or 0)) / 3600
end

local function say(f, st, tick, key, text, item)
  if st.said[key] == text then return end
  st.said[key] = text
  log(Ac.line(f.key or "player", text, minutes(f, tick), item))
end

--- Fours du modèle, du plus rapide au plus lent (à égalité par le nom) : aucun nom écrit ici.
local function furnaces()
  local out = {}
  for name, sp in pairs(M.BASE) do
    if sp.kind == "furnace" then out[#out + 1] = name end
  end
  table.sort(out, function(a, b)
    local sa, sb = M.BASE[a].speed or 0, M.BASE[b].speed or 0
    if sa ~= sb then return sa > sb end
    return a < b
  end)
  return out
end

--- Colonnes de `item` (modules de l'automatisation de ce produit) : capacité posée ou en chantier (par minute),
--- débit mesuré des blocs finis, nombre de finis, nombre de refusés.
local function blocks(f, item)
  local cap, flow, fini, open, refused, why = 0, 0, 0, 0, 0, nil
  local st = f.team.ia3e
  for _, m in ipairs(st and st.mods or {}) do
    if m.product == item then
      if m.state == "refuse" then
        refused = refused + 1
        why = m.reason
      else
        cap = cap + (m.rate_nom or 0)
        if m.state == "fini" then
          fini = fini + 1
          flow = flow + (m.rate_meas or 0)
        else
          open = open + 1
        end
      end
    end
  end
  return { cap = cap, flow = flow, fini = fini, open = open, refused = refused, why = why }
end

--- Recette de `item` pour le gabarit : son nom quand le modèle la connaît, sinon la table lue au prototype (G.simple la range au modèle).
local function recipe_arg(item)
  if M.RECIPES[item] then return item end
  local r = game.recipe_prototypes[item]
  return r and { name = r.name, category = r.category, energy = r.energy, ingredients = r.ingredients, products = r.products } or item
end

--- Source de l'entrée `input` : centre du coffre de sortie d'un projet FINI qui la contient, le plus proche du QG (nil : aucune).
local function source_of(f, input)
  local b, hq = f.build, f.hq
  local surface = hq and hq.valid and hq.surface
  if not (b and surface and input) then return nil end
  local best, bd
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    for _, o in ipairs((p and p.state == "fini" and p.outs) or {}) do
      local ch = surface.find_entities_filtered({ position = { o.x, o.y }, radius = 0.4, force = f.force, type = "container", limit = 1 })[1]
      local d = ch and ch.get_item_count(input) > 0 and (o.x - hq.position.x) ^ 2 + (o.y - hq.position.y) ^ 2
      if d and (not bd or d < bd) then best, bd = { x = o.x, y = o.y }, d end
    end
  end
  return best
end

--- Demande ou agrandit une colonne de `item` de `rate` par minute. Rend vrai si un module est demandé ou agrandi, sinon faux et la raison.
local function request(f, view, book, item, rate, tick)
  local stock = view.stock or {}
  local has_plant = Auto.plant_state(f) ~= nil
  local harvest = Harvest.reachable(f)
  local belt_flow = Auto.belt_flow(f)
  local function fit(m2, r) return Capi.fit_module(m2, r, book, stock, has_plant, harvest, belt_flow) end
  local meth, miss = nil, {}
  for _, fu in ipairs(furnaces()) do
    local m2 = { product = item, gen = "simple", args = { recipe_arg(item), 1, fu }, feed = true, generic = true }
    local g, why = fit(m2, 1e-6)
    if g then meth = m2 break end
    if #miss == 0 then miss = why or {} end -- manque du four le plus rapide : celui que la recherche doit ouvrir
  end
  if not meth then return false, "objets impossibles : " .. table.concat(miss, ",") end
  local o = { item = item, rate = rate, kind = "chaine" }
  local ids, why = RaRt.execute(f, o, meth, fit,
    function(m2, g, args, near, dyn)
      local id, w2 = Auto.submit(f, { product = item, gen = m2.gen, args = args, feed = m2.feed, rate = rate,
        rate_nom = (g.nominal[item] or 0) * 60, electric = (g.power_kw or 0) > 0, gain = 1, pole = g.pole,
        near = near or source_of(f, (T.smelter_inputs[item] or {})[1]), rangee = dyn or nil,
        why = string.format("COLONNE %s %.1f/min (rangee de fours)", item, rate) }, tick, nil)
      if not id then return nil, "plan directeur : " .. tostring(w2) end
      return { id }
    end, 1, tick)
  if ids == false then return false, "gabarit sans extension" end
  if not ids then return false, tostring(why) end
  return true, "module " .. tostring(ids[1]) .. " (" .. string.format("%.1f", rate) .. "/min)"
end

--- Retire `item` du plan : plan.smelt et les tâches « smelt ». Rend le nombre de tâches supprimées et la quantité retirée.
local function strip(view, plan, item)
  local qty = 0
  if plan.smelt and plan.smelt[item] then
    qty = plan.smelt[item]
    plan.smelt[item] = nil
  end
  local keep, dropped = {}, 0
  for _, t in ipairs(plan.tasks or {}) do
    local drop = false
    if t.kind == "smelt" and t.smelt then
      if t.smelt[item] then
        qty = math.max(qty, t.smelt[item])
        t.smelt[item] = nil
      end
      -- (`next` ne sert qu'à tester le vide) rien d'autre à fondre, aucune sortie à vider, aucun four à ravitailler : la tournée n'a plus de raison
      if next(t.smelt) == nil and (view.smelter_output or 0) == 0 and not view.smelter_fuel_low then drop = true end
    end
    if drop then dropped = dropped + 1 else keep[#keep + 1] = t end
  end
  plan.tasks = keep
  return dropped, qty
end

--- Vrai si la recette de l'acier est encore VERROUILLEE pour la force de l'équipe (recherche pas finie) : un four ne reçoit pas de plaques de
--- fer sans recette ouverte (moteur réel, banc acier-bloc : bloc posé, bras « en attente de source », four « no_ingredients » pendant 4 000 ticks).
--- Moteur simulé ou recette inconnue : faux.
local function recipe_locked(f, item)
  local ok, r = pcall(function() return game.forces[f.force].recipes[item] end)
  return ok and r ~= nil and r.enabled == false
end

--- Pensée d'équipe (E1c) : demande de la colonne d'un produit, transition, journal. Modifie `plan` sur place.
local function apply_item(f, view, book, plan, tick, item)
  local st = state_of(f, item)
  local function sayi(key, text) say(f, st, tick, key, text, item) end
  local bl = blocks(f, item)
  local short = (plan.smelt and plan.smelt[item]) or 0
  for _, t in ipairs(plan.tasks or {}) do
    if t.kind == "smelt" and t.smelt and (t.smelt[item] or 0) > short then short = t.smelt[item] end
  end
  local bilan = f.team.ia3 and f.team.ia3.bilan and f.team.ia3.bilan.items or {}
  local cons = bilan[item] and bilan[item].c or 0
  st.count = Ac.seen(st.count, short)
  -- Un bloc REFUSE par le plan directeur (moteur réel : « trop grand ») n'est pas redemandé à chaque pensée : même délai qu'un refus de la règle.
  if bl.refused > (st.refused or 0) then
    st.refused = bl.refused
    st.retry_at = tick + Ac.RETRY
    sayi("plan", string.format("bloc REFUSE par le plan directeur : %s (%d refus en tout, nouvelle tentative dans %.0f min)",
      tostring(bl.why), bl.refused, Ac.RETRY / 3600))
  end
  local need = Ac.need({ cons = cons, short = short })
  -- 1. DEMANDE d'un bloc, ou agrandissement
  local rate, why = Ac.ask({ count = st.count, need = need, cap = bl.cap, tick = tick, retry_at = st.retry_at })
  local plant = Auto.plant_state(f)
  if rate > 0 and not view.threatened then
    if plant ~= "fini" then
      -- (les bras de la rangée sont électriques : le bloc n'amorce pas la centrale à lui seul, il attend celle de l'équipe)
      sayi("ask", "bloc en attente : centrale de l'equipe non finie (etat " .. tostring(plant) .. ")")
    elseif bl.fini + bl.open == 0 and recipe_locked(f, item) then
      sayi("ask", "bloc en attente : la recette est verrouillee (recherche pas finie), un bloc posé ne fondrait rien")
    elseif bl.open > 0 then
      sayi("ask", "bloc en attente : un bloc est en chantier, il sera agrandi a sa fin (jamais un deuxieme pendant le chantier)")
    else
      local ok, w = request(f, view, book, item, rate, tick)
      if ok then
        st.asked = (st.asked or 0) + 1
        st.retry_at = 0
        sayi("ask", string.format("bloc DEMANDE : %s, besoin %.1f/min (manque %.0f, conso %.1f/min), capacite posee %.1f/min : %s",
          w, need, short, cons, bl.cap, why))
      else
        st.retry_at = tick + Ac.RETRY
        sayi("ask", string.format("bloc REFUSE : %s (besoin %.1f/min, manque %.0f, nouvelle tentative dans %.0f min)", w, need, short, Ac.RETRY / 3600))
      end
    end
  end
  if bl.fini ~= st.finished then
    sayi("fini", string.format("%d bloc(s) fini(s) (avant %d), debit mesure %.1f/min", bl.fini, st.finished, bl.flow))
    st.finished = bl.fini
  end
  -- 2. TRANSITION : la main d'acier est coupée quand un bloc fini produit au moins ce que l'équipe demande
  local survie = Survie.on(f)
  local prev = { cut = st.cut, since = st.since }
  local cut, cwhy = Ac.decide_cut(prev, { finished = bl.fini, flow = bl.flow, need = need, short = short, survie = survie, tick = tick })
  if cut ~= st.cut then
    st.cut, st.since = cut, tick
    sayi("cut", string.format("taches manuelles %s : debit du bloc %.1f/min, besoin %.1f/min, seuil %.1f/min (%s), %d tache(s) retiree(s) en tout",
      cut and "COUPEES" or "REPRISES", bl.flow, need, Ac.threshold(need), cwhy, st.dropped))
  end
  if st.cut then
    local dropped, qty = strip(view, plan, item)
    if dropped > 0 or qty > 0 then st.dropped = st.dropped + dropped end
  end
end

function Acier.apply(f, view, book, plan, tick)
  if not (f and f.team and plan and Acier.on()) then return end
  for _, item in ipairs(Ac.ITEMS) do apply_item(f, view, book, plan, tick, item) end
end

---------------------------------------------------------------------------------------------------
-- Interface distante de LECTURE (bancs seulement, jamais appelée par le mod) : état du bloc d'acier d'une équipe.
---------------------------------------------------------------------------------------------------
if remote and remote.add_interface then
  local function team_of(key)
    if key == "player" then return State.faction("player") end
    for _, id in ipairs(State.alive()) do
      local f = State.faction(id)
      if f and (f.key == key or id == key) then return f end
    end
    return nil
  end
  remote.add_interface("fo-acier", {
    status = function(key, item)
      local f = team_of(key)
      local st = f and f.team and f.team.acier and f.team.acier.by and f.team.acier.by[item or Ac.ITEMS[1]]
      if not st then return nil end
      return { cut = st.cut, since = st.since, count = st.count, asked = st.asked or 0, dropped = st.dropped, finished = st.finished, retry_at = st.retry_at }
    end,
  })
end

return Acier
