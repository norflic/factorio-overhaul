--[[
  Lot VIDEO L9, branchement (INTEGRATION_VIDEO.md ; règle pure shared/team/lot_minerai.lua, Lm, du lot video-l6) : la colle du plan
  directeur (script/team/build.lua, try_place et Build.think). Requise au CHARGEMENT dans un champ de Build (`Build.LotsMinerai`) : le
  bloc principal de build.lua est à 199 locales sur 200.

  D'ABORD LA MESURE (condition de video-l6) : une ligne [FO-LOTS-MINERAI] par équipe et par minute de jeu (Lg.minute, appelée par
  Build.think) : combien de modules sont posés sur un lot « gisement » du treillis, par sorte (fabrique, énergie, fonte, extraction),
  dont combien SANS ressource (fabrique et énergie : M33, « une fabrique se pose sur le minerai ») ; combien de replis sur un gisement
  depuis la ligne précédente, et combien de replis refusés par la règle.

  LA RÈGLE, derrière un interrupteur (réglage Lg.SETTING, ALLUMÉ par défaut depuis la 0.6.60, settings/video.lua ; absent, dans le moteur
  simulé des tests : éteint, sans erreur) : allumée, try_place essaie les états de Lm.states_for(sorte) : une fabrique (chaîne, mall,
  laboratoires…) ne se replie plus sur un lot de gisement, la fonte garde son repli, l'extraction ne va que sur un gisement. Éteinte : le
  repli d'avant, à l'identique. Sorte d'un gabarit : Lg.kind (générateur du gabarit ; la centrale est passée par l'appelant, elle ne passe
  pas par try_place).

  LE BRANCHEMENT ENTIER (lot video-minerai ; « ne lance jamais une construction au hasard qui viendrait écraser un gisement de minerai
  précieux sur le chemin de croissance », Directeur Créatif), quatre crochets de script/team/build.lua :
    1. survey -> Lg.amount(s, e, seg) : les quantités des minerais SOLIDES d'un lot s'ajoutent au relevé (s.amount) ; un liquide ou une
       ressource infinie (pétrole) n'y entre pas ;
    2. eval_one (lot) -> P.classify_lot(s, Lg.seuils()) : le lot est « gisement » dès qu'un minerai passe SON seuil (tuiles, quantité) ou
       que la somme dépasse le seuil de somme (shared/team/lot_minerai_seuils.lua) ; puis Lg.evaluated : le lot de minerai neuf est
       RÉSERVÉ tout de suite (Lm.reserve, marque l.reserved = minerai, jamais lue par une crise) et une ligne [FO-LOTS-MINERAI] le dit ;
       l'état « gisement » du lot est ce qui le ferme aux fabriques, à l'énergie et aux laboratoires (Lm.allows / Lm.states_for) ;
    3. eval_one (tronçon) -> Lg.seg_changed : une rue qui se FERME (porte) est un événement qui change la place ;
    4. Build.think -> Lg.think : les événements (porte fermée, pièce détruite, ennemi vu : b.sweep.reopened et b.sweep.danger, lus à la
       pensée) font refaire le relevé des lots (Lm.needs_survey) : Lg.RESURVEY_PER_PASS lots remis à la file d'évaluation par pensée.
  État : f.build.lm = { t, repli, refus, rv, re, ev, ... } et l.reserved, l.lm_q des lots (nombres, chaînes) ; aucune fonction, aucun nom
  d'objet (anti-échelle de tests/iag_test.lua §8 bis).
]]

local Lm = require("shared.team.lot_minerai")
local Seuils = require("shared.team.lot_minerai_seuils")

local Lg = {}
Lg.Lm = Lm
Lg.SEUILS = Seuils -- seuils par ressource (données) ; jamais en dur dans la règle
Lg.SETTING = "fo-war-lots-minerai"
Lg.PERIOD = 3600     -- une ligne par équipe et par minute de jeu
Lg.LIST_MAX = 5      -- projets sans ressource cités par ligne au plus
Lg.EVENT_GAP = 3600  -- ticks : deux événements plus proches comptent pour un seul (au plus un relevé général par minute de jeu, même en plein siège)
Lg.RESURVEY_PER_PASS = 400 -- lots remis à la file d'évaluation par pensée après un événement : un treillis jusqu'au rayon 9 (361 lots) en une pensée
                           -- (C4.3 : refait « en moins de 2 passes ») ; l'évaluation elle-même reste au budget de Build.EVAL_PER_PULSE
Lg.RESERVE_LOGS = 12 -- lignes « lot réservé » par équipe au plus (le décompte reste dans la ligne de la minute)
Lg.EVENT_LOGS = 12   -- lignes « événement » par équipe au plus

local GEN_KIND = { drills = "extraction", smelter = "fonte" } -- générateurs de shared/team/modules.lua (M.GENERATORS)

--- La règle est-elle allumée ? (réglage absent avant l'intégration : éteinte)
local function read_setting() return settings.global[Lg.SETTING].value end -- hissée : Lg.on() est appelée par entité de ressource d'un relevé, pas de fermeture neuve à chaque appel

function Lg.on()
  local ok, v = pcall(read_setting)
  return ok and v == true
end

--- Sorte d'un gabarit pour Lm : extraction (foreuses), fonte (fonderie), énergie (centrale), sinon fabrique.
function Lg.kind(gen, is_plant)
  if is_plant then return "energie" end
  return GEN_KIND[gen] or "fabrique"
end

local function state(f)
  local b = f.build
  b.lm = b.lm or { t = nil, repli = 0, refus = 0 }
  return b.lm
end

Lg.LEGACY = { { libre = true, defricher = true }, { gisement = true } } -- le repli d'avant (règle éteinte), dans cet ordre

--- try_place : états de lots essayés, dans l'ordre, pour un gabarit de générateur `gen`. Éteinte : le repli d'avant (libres, puis
--- gisement), pour toutes les sortes. Allumée : Lm.states_for(sorte) : une fabrique n'a plus de gisement, la fonte garde le sien,
--- l'extraction ne va que sur un gisement. Ne pas modifier les tables rendues (Lm.STATES).
function Lg.states(f, gen)
  if not Lg.on() then return Lg.LEGACY end
  return Lm.states_for(Lg.kind(gen))
end

--- try_place, après les essais : `m` le module posé (ou nil), `i` le rang de l'ensemble d'états qui l'a pris, `states` cet ensemble.
--- Compte un repli sur un gisement (posé sur un gisement après un premier essai refusé), et un repli REFUSÉ par la règle (aucun lot :
--- règle allumée, sorte sans gisement permis, alors que la règle éteinte aurait essayé un gisement).
function Lg.after(f, gen, m, i, states)
  local st = state(f)
  if m and i and i > 1 and states and states.gisement then st.repli = st.repli + 1 end
  if not m and Lg.on() and not Lm.allows("minerai", Lg.kind(gen)) then st.refus = st.refus + 1 end
end

--- Relevé des modules posés sur un lot « gisement » (projets ni refusés ni abandonnés ; lot lu par sa clé, état du lot d'aujourd'hui).
--- Rend { by = { [sorte] = n }, sans = n (fabrique + énergie), list = { "id:gen" } (triée par id), total = projets posés }.
function Lg.census(f)
  local b = f.build
  local out = { by = { extraction = 0, fonte = 0, energie = 0, fabrique = 0 }, sans = 0, list = {}, total = 0 }
  if not (b and b.order and b.projects and b.lots) then return out end
  for _, id in ipairs(b.order) do
    local p = b.projects[id]
    local part = p and p.parts and p.parts[1]
    if part and p.state ~= "refuse" and not p.abandoned and (part.kind == "module" or part.kind == "centrale") then
      out.total = out.total + 1
      local l = part.lot ~= nil and b.lots[part.lot] or nil
      if l and l.state == "gisement" then
        local k = Lg.kind(p.spec and p.spec.gen, part.kind == "centrale")
        out.by[k] = out.by[k] + 1
        if k == "fabrique" or k == "energie" then
          out.sans = out.sans + 1
          out.list[#out.list + 1] = string.format("%s:%s", tostring(id), tostring(p.spec and p.spec.gen))
        end
      end
    end
  end
  return out
end

--- Build.think : au plus une ligne [FO-LOTS-MINERAI] par équipe et par minute de jeu. Rend la ligne écrite, ou nil.
function Lg.minute(f, tick)
  if not f.build then return nil end
  local st = state(f)
  if st.t ~= nil and tick - st.t < Lg.PERIOD then return nil end
  st.t = tick
  local c = Lg.census(f)
  local cited = {}
  for i = 1, math.min(Lg.LIST_MAX, #c.list) do cited[i] = c.list[i] end
  local line = string.format(
    "[FO-LOTS-MINERAI] %s : modules sur un lot de gisement %d (sans ressource %d : fabrique %d, energie %d ; fonte %d, extraction %d) sur %d pose(s) ; replis sur un gisement %d, replis refuses %d (regle %s) ; lots de minerai reserves %d (neufs %d), releves refaits apres evenement %d ; projets sans ressource [%s] a %.1f min",
    f.key or "player", c.by.fabrique + c.by.energie + c.by.fonte + c.by.extraction, c.sans, c.by.fabrique, c.by.energie, c.by.fonte,
    c.by.extraction, c.total, st.repli, st.refus, Lg.on() and "allumee" or "eteinte", Lg.reserved_count(f), st.rv or 0, st.re or 0,
    table.concat(cited, " "), tick / 3600)
  st.repli, st.refus, st.rv, st.re = 0, 0, 0, 0
  log(line)
  return line
end
---------------------------------------------------------------------------------------------------
-- Branchement entier de L9 : seuils, quantités, réservation, relevé refait
---------------------------------------------------------------------------------------------------

--- Seuils par ressource (données) à passer à P.classify_lot ; règle éteinte : nil, le seuil unique d'avant.
function Lg.seuils()
  if not Lg.on() then return nil end
  return Lg.SEUILS
end

local SOLID = {} -- nom -> vrai si la ressource est un minerai SOLIDE fini (cache local de prototypes, jamais dans global)

local function solid(e)
  local ok, v = pcall(function()
    local proto = e.prototype
    if proto.infinite_resource then return false end
    local mp = proto.mineable_properties
    local prod = mp and mp.products and mp.products[1]
    return not (prod and prod.type == "fluid")
  end)
  return ok and v == true
end

--- survey (crochet 1) : ajoute la quantité de la ressource `e` au relevé `s` d'un LOT (jamais d'un tronçon : `seg`). Éteinte : rien.
function Lg.amount(s, e, seg)
  if seg or not Lg.on() then return end
  local name = e.name
  if SOLID[name] == nil then SOLID[name] = solid(e) end
  if not SOLID[name] then return end
  s.amount = s.amount or {}
  s.amount[name] = (s.amount[name] or 0) + (e.amount or 0)
end

--- Un événement qui change la place (porte fermée, pièce détruite, ennemi vu, G71) : le relevé des lots est à refaire. Deux événements à moins
--- de Lg.EVENT_GAP ticks n'en font qu'un.
function Lg.event(f, tick, why)
  local st = state(f)
  if st.ev and tick - st.ev < Lg.EVENT_GAP then return false end
  st.ev, st.ev_why = tick, why
  st.evn = (st.evn or 0) + 1
  if st.evn <= Lg.EVENT_LOGS then
    log(string.format("[FO-LOTS-MINERAI] %s : evenement (%s) a %.1f min : le releve des lots est a refaire (Lm.needs_survey)", f.key or "player",
      tostring(why), tick / 3600))
  end
  return true
end

--- Lots de minerai réservés (marque l.reserved).
function Lg.reserved_count(f)
  local n = 0
  local b = f.build
  for _, k in ipairs(b and b.lots and Lg.sorted(b.lots) or {}) do
    if b.lots[k].reserved then n = n + 1 end
  end
  return n
end

function Lg.sorted(t)
  local ks = {}
  for k in next, t do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

--- eval_one, lot évalué (crochet 2) : `l` le lot, `s` son relevé, `old` son état d'avant ('inconnu' à la première évaluation). Le lot de minerai
--- neuf est RÉSERVÉ tout de suite (Lm.reserve, aucune crise n'y entre) ; un lot refusé par un nid qui ne l'était pas est un ennemi vu.
function Lg.evaluated(f, tick, k, l, s, old)
  if not Lg.on() then return end
  local st = state(f)
  local was = l.reserved
  l.reserved, l.lm_q = nil, nil
  if l.state == "gisement" then
    local rv = Lm.reserve({ { key = k, s = s, used = l.used } }, Lg.SEUILS)
    if rv[1] then
      l.reserved = rv[1].res
      if not was then
        st.rv = (st.rv or 0) + 1
        st.logs = (st.logs or 0) + 1
        if st.logs <= Lg.RESERVE_LOGS then
          log(string.format("[FO-LOTS-MINERAI] %s : lot %s RESERVE au minerai (%s, motif %s : %d tuile(s), quantite %d) a %.1f min, meme en crise d'energie",
            f.key or "player", tostring(k), tostring(rv[1].res), tostring(rv[1].why), s.res and s.res[rv[1].res] or 0,
            s.amount and s.amount[rv[1].res] or 0, tick / 3600))
        end
      end
    end
  elseif l.state == "refuse" and l.reason == "nid" and old ~= "inconnu" and old ~= "refuse" then
    Lg.event(f, tick, "ennemi vu")
  end
end

--- eval_one, tronçon réévalué (crochet 3) : une rue qui était ouverte ou encombrée et se FERME est une porte fermée.
function Lg.seg_changed(f, tick, old, new)
  if not Lg.on() then return end
  if old ~= nil and old ~= "inconnu" and old ~= "ferme" and new == "ferme" then Lg.event(f, tick, "porte fermee") end
end

--- Un lot dont le relevé peut avoir changé : évalué, ni pris par un projet, ni le QG, ni refusé pour l'eau ou une falaise (le terrain ne bouge pas).
local function resurveyable(l)
  if l.state == "inconnu" or l.used or (l.i == 0 and l.j == 0) then return false end
  if l.state == "refuse" and (l.reason == "eau" or l.reason == "falaise") then return false end
  return true
end

local function priority(l)
  if l.state == "libre" or l.state == "defricher" or l.state == "gisement" then return 0 end
  return 1
end

--- Build.think (crochet 4) : lit les événements du relevé de reconstruction (pièces détruites, danger vu), puis remet à la file d'évaluation,
--- Lg.RESURVEY_PER_PASS lots par pensée au plus, les lots dont le relevé précède le dernier événement (Lm.needs_survey ; le QG, les lots
--- pris et les lots jamais relevés sont écartés). Rend le nombre de lots remis à la file.
function Lg.think(f, tick)
  if not Lg.on() then return 0 end
  local b = f.build
  if not (b and b.lots and b.queue) then return 0 end
  local st = state(f)
  local sw = b.sweep
  if sw then
    local re, dg = sw.reopened or 0, sw.danger or 0
    if st.s_re ~= nil and re > st.s_re then Lg.event(f, tick, "batiment detruit") end
    if st.s_dg ~= nil and dg > st.s_dg then Lg.event(f, tick, "ennemi vu") end
    st.s_re, st.s_dg = re, dg
  end
  if not st.ev or st.ev_done == st.ev then return 0 end
  local todo = {}
  for _, k in ipairs(Lg.sorted(b.lots)) do
    local l = b.lots[k]
    if resurveyable(l) and l.lm_q ~= st.ev and Lm.needs_survey(l, tick, st.ev, Lg.SEUILS.max_age) then
      todo[#todo + 1] = { k = k, l = l, p = priority(l) }
    end
  end
  if #todo == 0 then
    st.ev_done = st.ev
    return 0
  end
  table.sort(todo, function(a, c) if a.p ~= c.p then return a.p < c.p end return tostring(a.k) < tostring(c.k) end)
  local n = math.min(Lg.RESURVEY_PER_PASS, #todo)
  for i = 1, n do
    b.queue[#b.queue + 1] = { "lot", todo[i].k }
    todo[i].l.lm_q = st.ev
  end
  st.re = (st.re or 0) + n
  st.re_tot = (st.re_tot or 0) + n
  return n
end

--- Lecture pour les bancs (remote fo-ia1d.lots_minerai) : « report » = { on, reserved (lots), keys ("clé=minerai", triée), events, ev, ev_why,
--- resurveyed (lots remis à la file en tout), stale (lots dont le relevé précède le dernier événement) } ; « event » = déclenche un
--- événement à game.tick (bancs seulement : un banc ne ferme pas de porte).
function Lg.remote(f, cmd, arg)
  local b = f and f.build
  if not b then return nil end
  local st = state(f)
  if cmd == "event" then return Lg.event(f, game.tick, arg or "banc") end
  if cmd ~= "report" then return nil end
  local keys, stale = {}, 0
  for _, k in ipairs(Lg.sorted(b.lots)) do
    local l = b.lots[k]
    if l.reserved then keys[#keys + 1] = k .. "=" .. tostring(l.reserved) end
    if st.ev and resurveyable(l) and Lm.needs_survey(l, game.tick, st.ev, Lg.SEUILS.max_age) then
      stale = stale + 1
    end
  end
  return { on = Lg.on(), reserved = #keys, keys = keys, events = st.evn or 0, ev = st.ev, ev_why = st.ev_why, resurveyed = st.re_tot or 0, stale = stale }
end

return Lg
