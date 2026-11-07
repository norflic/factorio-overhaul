--[[
  Lot FOREUSES-THERMIQUES, point (A) (lead, 7/11 12 h 20 : « pour voir les foreuses électriques sur le vrai gisement du DC ») : la
  SAUVEGARDE de la partie du DC (copie fo-logs/2026-11-05_PARTIE-DC-ESSAI/autosave1-2121.zip, celle des mesures PERF4) rejouée avec la
  source du lot (banc.py --sauvegarde : aucune création de carte). foreuses-graine-dc (graine seule) ne donnait pas la carte du DC.
  Le scénario ne change RIEN à la partie (nom au KIT_EGAL du mod de test) ; il pose seulement la règle de la chaîne (allumée : défaut
  du lot ; coupée : témoin, comportement de 0.6.53) et relève, par le remote swap_outposts, les foreuses des avant-postes de votre
  équipe au départ, toutes les 30 s, puis à la fin (2,5 min de jeu).
  Critères (écrits avant le passage, règle allumée) :
    C1 la partie du DC se charge avec la source du lot (tick de départ > 0, relevé lisible au départ et à la fin) ;
    C2 au moins une électrique NOUVELLE (numéro d'unité absent au départ) sur un avant-poste de votre équipe en 2,5 min ;
    C3 toutes les électriques nouvelles sont reliées à un réseau électrique ;
    C4 aucun poteau posé par le remplacement (o.swap_poles) sur une tuile de couloir d'accès.
  Témoin : C1 seulement ; les chiffres sont relevés pour comparaison.
  Journal [FO-FOREUSES-PARTIE(-TEMOIN)] : ligne RESULTAT en clé=valeur, une ligne NOUVELLE par électrique nouvelle (position, reliée,
  au travail).
  Lancement (sans images, une place) :
    py -3.9 -B tools/autotest/banc.py --sauvegarde "<racine>\fo-logs\2026-11-05_PARTIE-DC-ESSAI\autosave1-2121.zip" --out <archive>
       --qui FOREUSES-TH -- 9300 foreuses-partie-dc <source>
]]

local DUR = 9000   -- 2,5 min de jeu
local EVERY = 1800 -- relevé intermédiaire toutes les 30 s

local function summary(r)
  if not r then return "nil" end
  return string.format("avant-postes=%d thermiques=%d electriques=%d reliees=%d au_travail=%d poteaux_swap=%d poteaux_swap_sur_couloir=%d",
    r.outposts, r.burners, r.electrics, r.connected, r.working, r.poles, r.poles_cor)
end

return function(rule)
  local TAG = "FOREUSES-PARTIE" .. (rule and "" or "-TEMOIN")
  local S = {
    description = "FOREUSES-THERMIQUES (A) : sauvegarde du DC, regle de la chaine " .. (rule and "ALLUMEE" or "COUPEE (temoin)"),
    base = nil,
    check_tick = -1, -- fixé à l'init : la partie ne commence pas au tick 0
  }
  S.init = function(ctx)
    local st = ctx.state()
    local t = game.tick
    S.check_tick = t + DUR
    st.t0 = t
    ctx.check(t > 0, "C1 partie du DC chargee depuis sa sauvegarde (tick de depart > 0)", t)
    local v = ctx.remote("fo-ia1", "set_regle_chaine", "player", rule)
    ctx.check(v == rule, "regle de la chaine : " .. (rule and "allumee" or "coupee"), tostring(v))
    local r0 = ctx.remote("fo-ia1", "swap_outposts", "player")
    ctx.check(r0 ~= nil, "C1 releve des avant-postes de votre equipe lisible au depart", summary(r0))
    st.known = {}
    for _, line in ipairs(r0 and r0.list or {}) do st.known[line:match("^(%d+)")] = true end
    st.r0 = r0 and summary(r0) or "nil"
    ctx.log(string.format("[FO-%s] DEPART tick %d (%.1f min de jeu) : %s ; swap=[%s]", TAG, t, t / 3600, st.r0,
      tostring(ctx.remote("fo-ia1", "swap_state", "player"))))
  end
  S.tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 or e.tick <= st.t0 or (e.tick - st.t0) % EVERY ~= 0 or e.tick - st.t0 >= DUR then return end
    ctx.log(string.format("[FO-%s] +%d s : %s ; swap=[%s]", TAG, (e.tick - st.t0) / 60, summary(ctx.remote("fo-ia1", "swap_outposts", "player")),
      tostring(ctx.remote("fo-ia1", "swap_state", "player"))))
  end
  S.finish = function(ctx)
    local st = ctx.state()
    local r1 = ctx.remote("fo-ia1", "swap_outposts", "player")
    ctx.check(r1 ~= nil, "C1 releve des avant-postes de votre equipe lisible a la fin", summary(r1))
    if not r1 then return end
    local new, linked, working = 0, 0, 0
    for _, line in ipairs(r1.list) do
      local u, x, y, c, w = line:match("^(%d+) (%S+) (%S+) (%d) (%d)$")
      if u and not st.known[u] then
        new = new + 1
        if c == "1" then linked = linked + 1 end
        if w == "1" then working = working + 1 end
        ctx.log(string.format("[FO-%s] NOUVELLE electrique %s en (%s, %s) reliee=%s au_travail=%s", TAG, u, x, y, c, w))
      end
    end
    ctx.log(string.format("[FO-%s] RESULTAT regle=%s duree=%.1f min depart=[%s] fin=[%s] nouvelles=%d reliees=%d au_travail=%d swap=[%s]",
      TAG, rule and "oui" or "non", DUR / 3600, st.r0 or "nil", summary(r1), new, linked, working,
      tostring(ctx.remote("fo-ia1", "swap_state", "player"))))
    if rule then
      ctx.check(new >= 1, "C2 au moins une electrique nouvelle sur un avant-poste de votre equipe en 2,5 min", tostring(new))
      ctx.check(new > 0 and linked == new, "C3 toutes les electriques nouvelles reliees a un reseau", linked .. "/" .. new)
      ctx.check(r1.poles_cor == 0, "C4 aucun poteau pose par le remplacement sur un couloir d'acces", tostring(r1.poles_cor))
    end
  end
  return S
end
