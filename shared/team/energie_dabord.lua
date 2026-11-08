--[[
  Lot TV-ENERGIE (G41, docs/TODO_VIDEO.md l.218 : « 1re mégatuile = nucléaire — L'énergie d'abord ») : règle GÉNÉRALE « la première expansion
  d'une équipe est l'énergie ». PUR (aucune API Factorio, aucun nom d'objet : la décision ne lit que la FORME de la demande), testé hors jeu
  par tests/tv_energie_test.lua.

  Avant : « centrale d'abord » existait en quatre endroits séparés, chacun pour son cas (le premier module électrique, script/ai3/
  automatisation.lua submit ; un site de pétrole, script/ai3/petrole.lua ; le champ, script/ai3/capitalisation.lua execute ; un raccord,
  shared/team/raccord.lua). Une demande d'un autre chemin (ou d'un chemin futur) passait sans centrale. Maintenant la garde est au GOULOT :
  Build.request (script/team/build.lua) demande la décision à E.decide pour TOUTE demande de projet.

  Règle : une demande d'EXPANSION (un module de production ou un site : spec.gen ou spec.site ou spec.key, hors la centrale elle-même) faite par
  une équipe qui n'a demandé AUCUNE centrale fait demander la centrale D'ABORD (Build.plant la place en tête de file) ; la demande est ensuite
  enregistrée derrière elle. Jamais pour ce qui répare ou protège (enceinte, îlot, alimentation de la centrale, liaison, raccord) ni pour les
  demandes de banc. E.ON = false rend exactement le comportement d'avant (témoin des bancs).
]]
local E = {}

E.ON = true -- ALLUMÉ par défaut ; false : comportement d'avant le lot

-- clés d'une demande qui disent « ce n'est pas une expansion » : réparer, protéger, relier, nourrir la centrale, banc
E.NOT_EXPANSION = { "bench", "enceinte", "ilot", "alim", "liaison", "raccord", "walls", "plant" }

--- La demande est-elle une expansion ? (La centrale elle-même, spec.plant posé par Build.plant et Build.grow_plant, n'en est pas une : cette
--- règle ne nomme aucun générateur.)
function E.expansion(spec)
  if type(spec) ~= "table" then return false end
  for _, k in ipairs(E.NOT_EXPANSION) do
    if spec[k] ~= nil then return false end
  end
  return spec.gen ~= nil or spec.site ~= nil or spec.key ~= nil
end

--- Faut-il demander la centrale avant cette demande ? st = { plant = numéro du projet de centrale (nil : aucune), off = réglage de banc
--- b.opts.no_energie_dabord }. Rend (vrai, raison) ou (faux, raison).
function E.decide(spec, st)
  if not E.ON then return false, "regle coupee" end
  if st == nil or st.off then return false, "reglage de banc" end
  if st.plant ~= nil then return false, "centrale deja demandee" end
  if not E.expansion(spec) then return false, "pas une expansion" end
  return true, "premiere expansion sans centrale : l'energie d'abord"
end

--- Ligne du journal [FO-ENERGIE-DABORD] (une par équipe : la centrale demandée une fois, la règle ne se redéclenche plus).
function E.line(team, tick, spec, plant)
  local what = spec.gen and ("module " .. tostring(spec.gen)) or (spec.site and ("site " .. tostring(spec.site)) or ("gabarit " .. tostring(spec.key)))
  return string.format("[FO-ENERGIE-DABORD] %s : premiere expansion de l'equipe (%s) a %.1f min : la centrale (projet %s) est demandee AVANT, en tete de file",
    tostring(team), what, (tick or 0) / 3600, tostring(plant))
end

return E
