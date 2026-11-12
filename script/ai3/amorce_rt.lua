--[[
  Lot VIDEO L7, branchement (INTEGRATION_VIDEO.md étape 10) : la colle entre le runtime et la règle pure de l'amorce
  (shared/ai3/amorce.lua, Am, qui étend le mall Ml sans le modifier).
    - AmRt.seed (appelé par Ind.think, script/ai3/industrie.lua, avant Ml.sources) : la liste de matériel des Am.K prochains projets
      du plan directeur (pièces planifiées pas encore posées, moins ce que le projet a déjà pris : le calcul de Stock.demand), moins le
      stock BRUT du coffre (Stock.count : la liste est brute, le stock libre en retire déjà les réservations), devient la graine du mall.
    - AmRt.observe (appelé par le relevé de la capitalisation, juste après Cf.step de L5) : la 1re production est l'événement
      `confirmed_now` de la confirmation (L5 : produits finis de CHAQUE machine), JAMAIS les statistiques de la force. Piège de la force
      partagée : votre équipe EST la force du joueur, et ce que le joueur fabrique à la main entre dans
      force.item_production_statistics ; lues là, ces fabrications passeraient pour celles d'une machine et la main des PNJ serait
      retirée sans qu'aucune machine ait produit. La main des PNJ (compteurs de l'automatisation, f.team.ia3e.hand_all : hors des
      statistiques, F244) nourrit le compteur d'amorce. Le verrou tombe quand plus aucune unité du carnet de L5 ne fabrique l'objet.
    - Lot VIDEO-COUVERTURE 5 (hors amorce, même colle) : AmRt.after_decision (appelé juste après la décision, avant les portes L6) publie les
      cycles de la décision (cs.cyc : graine de AmRt.seed, critère C5.1) et RE-ÉMET le MÊME plan d'un ordre que l'exécutant occupé avait refusé
      (AmRt.defer l'a mis de côté ; Cf.RETRY plus tard, critère C5.3, TODO G58) ; AmRt.lines écrit aussi la 1re production d'une unité
      ([FO-CONFIRMATION]), qui lève la retenue du module suivant (Cf.upstream, critère C5.2).
  État : ml.amorce (règle), cs.amorce_hand (dernier relevé des compteurs de la main), cs.cyc (cycles de la dernière décision),
  cs.cfo (ordres mis de côté, carnet de confirmation à part) : nombres et chaînes, aucune fonction.
  Aucun nom d'objet (anti-échelle de tests/iag_test.lua §8). Testé hors jeu : tests/amorce_glue_test.lua.
]]

local Am = require("shared.ai3.amorce")
local Ml = require("shared.ai3.mall")
local Cf = require("shared.ai3.confirmation")
local Dm = require("shared.ai3.demande") -- Dm.BUSY_TEXT : « plan directeur occupe », le refus de l'exécutant
local Sw = require("shared.team.rebuild_sweep") -- Sw.rebuilding : projet rouvert pour reconstruction (règle pure, lot CHARBON-CENTRALE)

local AmRt = {}
AmRt.Am = Am
-- États d'un projet ROUVERT dont le chantier a repris (REBUILD-RAPIDE, Build.think) : son manque (p.missing) est tenu par refresh_missing
AmRt.REBUILD_STATES = { defrichage = true, fantomes = true, chantier = true }
AmRt.MODULE_KINDS = { couvrir = true, ouvrir = true, chaine = true, packs = true } -- les ordres que le plan directeur (le déployeur) exécute
AmRt.RELANCES_MAX = 2 -- un ordre refusé par l'exécutant occupé est re-émis au plus deux fois (Cf.RETRY chacune), puis laissé à la décision

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

--- Projets du plan directeur à servir, dans l'ordre de la file, avec leur liste de matériel (pièces pas encore posées, moins p.stock).
--- Les projets finis, refusés, ou dont toutes les pièces sont posées n'y sont pas.
function AmRt.projects(f)
  local b = f.build
  local out = {}
  if not (b and b.order and b.projects) then return out end
  for _, id in ipairs(b.order) do
    local p = b.projects[id]
    if p and p.state ~= "fini" and p.state ~= "refuse" then
      local need = {}
      for _, e in ipairs(p.ents or {}) do
        if not e.built and e.item then need[e.item] = (need[e.item] or 0) + 1 end
      end
      local bom, any = {}, false
      for _, it in ipairs(sorted_keys(need)) do
        local n = need[it] - ((p.stock or {})[it] or 0)
        if n > 0 then bom[it] = n; any = true end
      end
      if any then out[#out + 1] = { id = id, bom = bom } end
    end
  end
  return out
end

--- (a) La graine. count(item) = stock BRUT (Stock.count). Rend la liste semée (Am.seed).
function AmRt.seed(f, ml, tick, book, count)
  local projets = AmRt.projects(f)
  local have = {}
  local seen = {}
  for i = 1, math.min(Am.K, #projets) do
    for _, it in ipairs(sorted_keys(projets[i].bom)) do
      if not seen[it] then seen[it] = true; have[it] = count(it) or 0 end
    end
  end
  -- C5.1 : les objets de cycle de la dernière décision (AmRt.after_decision), leur stock BRUT comme pour la liste de matériel
  local cyc = f.team and f.team.capi and f.team.capi.cyc
  for _, e in ipairs(cyc or {}) do
    if not seen[e.item] then seen[e.item] = true; have[e.item] = count(e.item) or 0 end
  end
  local out, skipped = Am.seed(ml, tick, projets, have, book, Ml, cyc)
  -- journal : la graine d'un cycle et sa cause, écrite quand elle change (jamais à l'horloge)
  local cap = f.team and f.team.capi
  if cap and cyc then
    cap.cyc_said = cap.cyc_said or {}
    for _, o in ipairs(out) do
      if tostring(o.cause):find("cycle ", 1, true) and cap.cyc_said[o.item] ~= o.need then
        cap.cyc_said[o.item] = o.need
        log(string.format("[FO-AMORCE] %s : graine de cycle %s : %d a fabriquer ; cause : %s", f.key or "?", o.item, o.need, o.cause))
      end
    end
    for _, o in ipairs(skipped or {}) do
      if cap.cyc_said[o.item] ~= -o.need then
        cap.cyc_said[o.item] = -o.need
        log(string.format("[FO-AMORCE] %s : cycle %s non seme (%d voulus) : aucune recette a la main ; cause : %s", f.key or "?", o.item, o.need, o.cause))
      end
    end
  end
  return out
end

--- Un ordre refusé par l'exécutant occupé est mis de côté (C5.3) : appelé à chaque ordre RETENU par la boucle d'envoi. Seuls les ordres de
--- module (MODULE_KINDS) refusés pour « plan directeur occupe » comptent ; un ordre déjà re-émis RELANCES_MAX fois est laissé à la
--- décision. Rend vrai s'il est mis de côté.
function AmRt.defer(cs, o, why, tick)
  if not (o and AmRt.MODULE_KINDS[o.kind] and tostring(why):find(Dm.BUSY_TEXT, 1, true)) then return false end
  if (o.relances or 0) >= AmRt.RELANCES_MAX then return false end
  cs.cfo = cs.cfo or Cf.new()
  return (Cf.defer(cs.cfo, o, tick))
end

--- Juste après la décision (avant les portes L6 et la boucle d'envoi) : publie les cycles de la décision pour la graine de l'amorce
--- (cs.cyc ; nil sans cycle, le global reste celui d'avant) et rend la liste des ordres à envoyer, les plans mis de côté dont Cf.RETRY
--- est échu EN TÊTE (le MÊME plan, relances + 1). Un plan n'est pas re-émis quand la décision l'a refait d'elle-même, qu'un ordre de
--- même clé est ouvert, qu'une AUTRE raison le refuse maintenant (danger, budget…), ou que l'épargne ne le paie plus (cout débité,
--- rendu par la boucle d'envoi s'il est refusé de nouveau, comme tout ordre). Abandon à Cf.STALL, écrit. `mn` : minutes de jeu.
function AmRt.after_decision(f, cs, res, tick, mn)
  local cy = Am.flatten(res and res.rang_cycles)
  cs.cyc = #cy > 0 and cy or nil
  local orders = (res and res.orders) or {}
  local book = cs.cfo
  if not book then return orders end
  local step = Cf.step(book, {}, tick)
  if not step then return orders end
  local who = f.key or "?"
  for _, e in ipairs(step.failed_now) do
    log(string.format("[FO-CAPI-CONF] %s : ordre %s abandonne (executant occupe, %d relance(s)) a %.1f min", who, tostring(e.id), e.tries or 0, mn or 0))
    Cf.forget(book, e.id)
  end
  local fresh, open, refus = {}, {}, {}
  for _, o in ipairs(orders) do fresh[o.key] = true end
  for _, r in ipairs(cs.open or {}) do open[r.key] = true end
  for _, r in ipairs((res and res.refus) or {}) do refus[tostring(r.key)] = tostring(r.why) end
  local front = {}
  for _, r in ipairs(step.retry) do
    local o = r.spec
    local other = refus[tostring(o.key)]
    if fresh[o.key] or open[o.key] or (other and not other:find(Dm.BUSY_TEXT, 1, true)) then
      Cf.forget(book, r.id) -- refait par la décision, déjà ouvert, ou refusé pour une autre raison : plus d'actualité
    elseif cs.st and (cs.st.bank or 0) >= (o.cost_m or 0) then
      cs.st.bank = cs.st.bank - (o.cost_m or 0)
      o.relances = (o.relances or 0) + 1
      front[#front + 1] = o
      Cf.forget(book, r.id)
      log(string.format("[FO-CAPI-CONF] %s : relance du MEME plan %s (%s x%d) apres l'executant occupe, essai %d a %.1f min", who, tostring(o.key),
        tostring(o.kind), o.n or 0, o.relances, mn or 0))
    end
  end
  if #front == 0 then return orders end
  for _, o in ipairs(orders) do front[#front + 1] = o end
  return front
end

--- (b) et (c) Relevé : cfr = résultat de Cf.step (L5) ; book = carnet de la confirmation (cs.cf). Rend les retraits de ce relevé.
function AmRt.observe(f, cs, ml, cfr, book, tick)
  if not (ml and cfr) then return {} end
  -- la main des PNJ depuis le relevé précédent (compteurs cumulés : le premier relevé ne fait que poser la base)
  local ha = (f.team and f.team.ia3e and f.team.ia3e.hand_all) or {}
  local prev = cs.amorce_hand
  local flows = {}
  local now = {}
  for _, k in ipairs(sorted_keys(ha)) do
    now[k] = ha[k]
    local d = (ha[k] or 0) - ((prev or {})[k] or 0)
    if prev and prev[k] ~= nil and d > 0 then flows[k] = { made = d, hand = d } end
  end
  cs.amorce_hand = now
  -- la 1re production d'une MACHINE : une unité confirmée à ce relevé (produits finis de la machine), jamais la force
  for _, ev in ipairs(cfr.confirmed_now or {}) do
    if ev.item then
      local fl = flows[ev.item] or { made = 0, hand = 0 }
      fl.made = (fl.hand or 0) + 1
      flows[ev.item] = fl
    end
  end
  -- objets qu'une unité du carnet fabrique encore (engagée, confirmée, arrêtée) : le verrou des autres tombe
  local alive = {}
  for _, id in ipairs((book and book.list) or {}) do
    local u = book.ids and book.ids[id]
    if u and u.item then alive[u.item] = true end
  end
  local out = Am.observe(ml, tick, flows, alive)
  out.lifts = cfr.confirmed_now or {} -- C5.2 : les 1res productions de ce relevé (lues par AmRt.lines)
  return out
end

--- Remise directe (correctif C3 de DIAG_CONSO) : appelée par le dépôt d'un PNJ au QG (script/team/worker.lua, deposit_inventory) AVANT le coffre
--- pour l'objet `name` en quantité `n` qu'il porte (inventaire `inv`). Ce qu'un module du plan directeur EN RÉSERVE attend (son manque,
--- p.missing, écrit par Build.reserve) va à p.stock du module, sans passer par le coffre : un coffre plein refuse tout objet non vital (M0), et le
--- cycle « module de chaîne -> assembleurs 2 -> circuits -> module de chaîne » (M4) ne se coupait jamais. Rend le nombre d'objets remis
--- (retirés de `inv`, comptés livrés au QG). La règle est Am.direct (shared/ai3/amorce.lua).
--- Lot KITS-VOLES : `kits` = { { pids = { id… }, n = k } }, la part de `name` que portent des KITS et les projets pour lesquels chacun a été
--- fabriqué (tâche du kit, P.want_kit). La part d'un kit n'est offerte qu'à SES projets ; ce qu'ils n'attendent pas (mort, fini, servi) reste
--- pour le coffre (stock commun). Avant, tout allait au premier projet en réserve de b.order : scarlet, graine 2507543475, le réseau du
--- charbon (projet 7) prenait les tapis des kits des modules 3, 4 et 13, refusés « materiaux introuvables » à 44,7 min.
function AmRt.deliver(f, inv, name, n, kits)
  local b = f and f.build
  if not (b and b.order and b.projects and inv) then return 0 end
  local given, free = 0, n or 0
  for _, k in ipairs(kits or {}) do
    local part = math.min(free, k.n or 0)
    if part > 0 then
      local own = {}
      for _, id in ipairs(k.pids or {}) do own[id] = true end
      local g = AmRt.give(f, inv, name, part, own)
      log(string.format("[FO-KIT-REMISE] %s : %d %s d'un kit (projets %s) : %d remis a ses projets, %d au coffre a %.1f min", f.key or "?", part, name,
        table.concat(k.pids or {}, ","), g, part - g, (game and game.tick or 0) / 3600))
      given, free = given + g, free - part
    end
  end
  if free > 0 then given = given + AmRt.give(f, inv, name, free, nil) end
  if given > 0 then f.team.delivered[name] = (f.team.delivered[name] or 0) + given end
  return given
end

--- Remet au plus `n` objets `name` aux projets de b.order qui les attendent (Am.direct) ; `own` (ensemble d'ids) : à ces projets seulement.
function AmRt.give(f, inv, name, n, own)
  local b = f.build
  local list = {}
  for _, id in ipairs(b.order) do
    local p = (own == nil or own[id]) and b.projects[id] or nil
    -- lot CHARBON-CENTRALE : un projet ROUVERT pour reconstruction (Sw.rebuilding) dont le chantier a repris (REBUILD-RAPIDE : défrichage, fantômes,
    -- chantier ; p.missing tenu par refresh_missing) attend aussi, et d'abord : ses pièces détruites (tapis du charbon de la centrale) ne sont
    -- refaites que si l'objet atteint son p.stock ou le coffre, et la réserve d'un module neuf prenait tout au dépôt
    if p and (p.state == "reserve" or (AmRt.REBUILD_STATES[p.state] and (Sw.rebuilding(p) or p.progressif))) then
      -- (p.progressif : bande de champ partie en chantier sans toute sa matière, lot EXPANSION-LOINTAINE : servie comme une réserve)
      list[#list + 1] = { id = id, state = p.state, reason = p.reason, missing = p.missing, rebuilding = Sw.rebuilding(p), progressif = p.progressif or nil }
    end
  end
  local given = 0
  for _, a in ipairs(Am.direct(list, name, n)) do
    local p = b.projects[a.id]
    local got = inv.remove({ name = name, count = a.n }) or 0
    if got > 0 then
      p.stock[name] = (p.stock[name] or 0) + got
      local rest, left = {}, got
      for _, m in ipairs(p.missing or {}) do
        if m[1] == name and left > 0 then
          local take = math.min(left, m[2])
          left = left - take
          if m[2] - take > 0 then rest[#rest + 1] = { m[1], m[2] - take } end
        else
          rest[#rest + 1] = m
        end
      end
      p.missing, p.reserve_next = rest, nil
      given = given + got
      log(string.format("[FO-AMORCE] %s : %s%s", f.key or "?", Am.describe_direct({ id = a.id, item = name, n = got, rebuild = a.rebuild }, (game and game.tick or 0) / 3600),
        own and " (kit du projet)" or ""))
    end
  end
  return given
end

--- Lignes [FO-AMORCE] des retraits.
function AmRt.lines(f, ml, retraits, minutes)
  local out = {}
  for _, r in ipairs(retraits or {}) do
    out[#out + 1] = string.format("[FO-AMORCE] %s : %s a %.1f min", f.key or "?", Am.describe(r, ml), minutes or 0)
  end
  for _, ev in ipairs((retraits and retraits.lifts) or {}) do
    out[#out + 1] = string.format("[FO-CONFIRMATION] %s : %s (unite %s) a produit pour la 1re fois a %.1f min : les modules qui le consomment ne sont plus retenus en amont",
      f.key or "?", tostring(ev.item), tostring(ev.id), minutes or 0)
  end
  return out
end

-- Interface distante (BANCS SEULEMENT) : l'état de la remise directe, et une remise comme le ferait le dépôt d'un PNJ. L'équipe est cherchée
-- dans le module d'état déjà chargé (package.loaded : require est interdit pendant un événement, F24).
if remote and remote.add_interface then
  local function team_of(key)
    local State = package.loaded["script.faction.state"]
    if not State then return nil end
    if key == "player" then return State.faction("player") end
    for _, id in ipairs(State.alive()) do
      local f = State.faction(id)
      if f and (f.key == key or id == key) then return f end
    end
    return nil
  end
  remote.add_interface("fo-amorce", {
    --- Les modules du plan directeur en réserve et ce qui leur manque : { { id, product, missing = { { objet, manque } }, stock = { [objet] = n } } }.
    reserves = function(key)
      local f = team_of(key)
      local b = f and f.build
      if not (b and b.order and b.projects) then return nil end
      local out = {}
      for _, id in ipairs(b.order) do
        local p = b.projects[id]
        if p and p.state == "reserve" then
          local miss, stock = {}, {}
          for _, m in ipairs(p.missing or {}) do miss[#miss + 1] = { m[1], m[2] } end
          for k, v in pairs(p.stock or {}) do stock[k] = v end
          out[#out + 1] = { id = id, product = p.spec and p.spec.product, reason = p.reason, missing = miss, stock = stock }
        end
      end
      return out
    end,
    --- Un PNJ qui arrive au QG avec `n` objets `name` (un inventaire temporaire) : AmRt.deliver, puis le reste est rendu. Rend le nombre remis.
    deliver = function(key, name, n)
      local f = team_of(key)
      if not (f and f.team and f.team.delivered) then return nil end
      local inv = game.create_inventory(1)
      local put = inv.insert({ name = name, count = n })
      local given = AmRt.deliver(f, inv, name, put)
      inv.destroy()
      return given
    end,
  })
end

return AmRt
