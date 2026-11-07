--[[
  Lot VIDEO L9, branchement (INTEGRATION_VIDEO.md ; règle pure shared/team/lot_minerai.lua, Lm, du lot video-l6) : la colle du plan
  directeur (script/team/build.lua, try_place et Build.think). Requise au CHARGEMENT dans un champ de Build (`Build.LotsMinerai`) : le
  bloc principal de build.lua est à 199 locales sur 200.

  D'ABORD LA MESURE (condition de video-l6) : une ligne [FO-LOTS-MINERAI] par équipe et par minute de jeu (Lg.minute, appelée par
  Build.think) : combien de modules sont posés sur un lot « gisement » du treillis, par sorte (fabrique, énergie, fonte, extraction),
  dont combien SANS ressource (fabrique et énergie : M33, « une fabrique se pose sur le minerai ») ; combien de replis sur un gisement
  depuis la ligne précédente, et combien de replis refusés par la règle.

  LA RÈGLE, derrière un interrupteur ÉTEINT par défaut (réglage Lg.SETTING, déclaré par l'intégrateur ; absent : éteint, sans erreur) :
  allumée, try_place essaie les états de Lm.states_for(sorte) : une fabrique (chaîne, mall, laboratoires…) ne se replie plus sur un
  lot de gisement, la fonte garde son repli, l'extraction ne va que sur un gisement. Éteinte : le repli d'avant, à l'identique.
  Sorte d'un gabarit : Lg.kind (générateur du gabarit ; la centrale est passée par l'appelant, elle ne passe pas par try_place).
  État : f.build.lm = { t, repli, refus } (nombres) ; aucune fonction, aucun nom d'objet (anti-échelle de tests/iag_test.lua §8 bis).
]]

local Lm = require("shared.team.lot_minerai")

local Lg = {}
Lg.Lm = Lm
Lg.SETTING = "fo-war-lots-minerai"
Lg.PERIOD = 3600     -- une ligne par équipe et par minute de jeu
Lg.LIST_MAX = 5      -- projets sans ressource cités par ligne au plus

local GEN_KIND = { drills = "extraction", smelter = "fonte" } -- générateurs de shared/team/modules.lua (M.GENERATORS)

--- La règle est-elle allumée ? (réglage absent avant l'intégration : éteinte)
function Lg.on()
  local ok, v = pcall(function() return settings.global[Lg.SETTING].value end)
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
    "[FO-LOTS-MINERAI] %s : modules sur un lot de gisement %d (sans ressource %d : fabrique %d, energie %d ; fonte %d, extraction %d) sur %d pose(s) ; replis sur un gisement %d, replis refuses %d (regle %s) ; projets sans ressource [%s] a %.1f min",
    f.key or "player", c.by.fabrique + c.by.energie + c.by.fonte + c.by.extraction, c.sans, c.by.fabrique, c.by.energie, c.by.fonte,
    c.by.extraction, c.total, st.repli, st.refus, Lg.on() and "allumee" or "eteinte", table.concat(cited, " "), tick / 3600)
  st.repli, st.refus = 0, 0
  log(line)
  return line
end

return Lg
