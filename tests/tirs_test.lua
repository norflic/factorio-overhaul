-- Banc hors jeu du lot TIRS (27/10) : table des âges, règles pures (décision d'habillage sur une volée de 80
-- tourelles dans les deux ordres de mise à jour, proximité), son en couches (vitesse dans chaque variation), garde
-- « aucun effet de jeu » (mutants).
--   lua5.2 tests/tirs_test.lua      -> [TIRS] BILAN : N OK, 0 ECHEC(S)
package.path = "./?.lua;" .. package.path

local T = require("shared.tirs.ages")
local R = require("shared.tirs.regles")
local K = require("prototypes.tirs_kit")

local ok, ko = 0, 0
local function check(c, quoi, detail)
  if c then ok = ok + 1 else ko = ko + 1; print("ECHEC  " .. quoi .. (detail and (" : " .. tostring(detail)) or "")) end
end

local function copie(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = copie(v) end
  return c
end

-- 1. table des âges bien formée, âges témoins
local m = R.verifier_ages(T)
check(#m == 0, "table des ages bien formee", table.concat(m, " ; "))
local TEM = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 }
for i, e in ipairs(TEM) do
  check(T.temoins[i] == e, "age n" .. i .. " = " .. e, T.temoins[i])
  check(T.ages[e] ~= nil, "age " .. e .. " habille")
end
check(#T.temoins == 15, "les 15 ages sont habilles (D-21)", #T.temoins)
check(T.sans_effet == nil, "plus d'age sans effet : le site sans effet des bancs est le niveau 1 (vanilla)")
-- grandeur croissante avec l'âge (D-21 : « impacts nettement plus gros aux âges hauts »)
local lum, imp, part, quota = 0, 0, 0, 0
local ech_ok, etinc_ok, lum_imp_ok = true, true, true
local ech_prec, etinc_prec = 0, 0
for _, e in ipairs(T.temoins) do
  local A = T.ages[e]
  check(A.lumiere.taille > lum, "lumiere de bouche croissante (age " .. e .. ")", A.lumiere.taille)
  lum = A.lumiere.taille
  local li = A.impact[1].lumiere and A.impact[1].lumiere.taille or 0
  check(li >= imp, "lumiere d'impact non decroissante (age " .. e .. ")", li)
  imp = li
  local p = T.probabilite * A.part[1] / A.part[2]
  check(p >= part, "part des tirs habilles non decroissante (age " .. e .. ")", p)
  part = p
  check(A.quota >= quota, "quota non decroissant (age " .. e .. ")", A.quota)
  quota = A.quota
  check(A.impact[1].tourne == nil, "age " .. e .. " : impact jamais tourne")
  -- taille de l'impact principal en tuiles (largeur de la 1re image à l'échelle 1 × échelle demandée)
  local LARG = { ["explosion-hit"] = 1.0, ["explosion"] = 0.75, ["massive-explosion"] = 10.0, eclaboussure = 3.3 }
  local x = A.impact[1]
  local tuiles = (LARG[x.source or x.image] or 1) * x.echelle
  check(tuiles >= ech_prec - 1e-9, "taille de l'impact principal non decroissante (age " .. e .. " : " .. string.format("%.2f", tuiles) .. " tuiles)", tuiles)
  ech_prec = tuiles
  local ne = x.etincelles and x.etincelles.nombre or 0
  check(ne >= etinc_prec or e == 8, "etincelles d'impact non decroissantes (age " .. e .. ")", ne)
  if ne > 0 then etinc_prec = ne end
end
-- l'impact de l'âge 15 est NETTEMENT plus gros que celui de l'âge 10, qui l'est plus que celui de l'âge 5 (D-21)
local function tuiles_age(e)
  local LARG = { ["explosion-hit"] = 1.0, ["explosion"] = 0.75, ["massive-explosion"] = 10.0, eclaboussure = 3.3 }
  local x = T.ages[e].impact[1]
  return (LARG[x.source or x.image] or 1) * x.echelle
end
check(tuiles_age(15) >= 1.5 * tuiles_age(10) and tuiles_age(10) >= 1.5 * tuiles_age(5) and tuiles_age(5) >= 2 * tuiles_age(1),
  "impacts : age 15 >= 1,5 x age 10 >= 2,25 x age 5 >= 4,5 x age 1")
check(T.ages[15].impact[1].lumiere.taille >= 30 and T.ages[1].impact[1].lumiere.taille <= 4, "lumiere d'impact : 30+ tuiles a l'age 15, 4 au plus a l'age 1")
check(T.probabilite * T.ages[15].part[1] / T.ages[15].part[2] > T.probabilite * T.ages[1].part[1] / T.ages[1].part[2],
  "l'age 15 habille plus de tirs que l'age 1")
check((T.ages[15].trace.nombre or 1) > (T.ages[1].trace.nombre or 1), "l'age 15 tire plus de dards que l'age 1")
-- l'âge du Néant : lumière, pas de fumée (fil « de la fumée à la lumière »)
check(T.ages[15].trace.trainee == nil and T.ages[15].fumee == nil, "age 15 : ni trainee ni fumee de bouche")
check(T.ages[1].fumee ~= nil and T.ages[1].fumee.nombre >= 3, "age 1 : bouffee de poudre noire (3 fumees au moins)")
-- somme des quotas = plafond commun (aucun âge ne dépend de l'ordre de mise à jour)
local somme = 0
for _, e in ipairs(T.temoins) do somme = somme + T.ages[e].quota end
check(T.plafond_tick >= somme, "plafond commun >= somme des quotas (" .. somme .. ")", T.plafond_tick)
-- laser : un faisceau par âge de 2 à 15, de plus en plus épais, jamais plus de x1,5
local ep = 0
for e = 2, 15 do
  local Lz = T.ages[e].laser
  check(Lz ~= nil and Lz.epaisseur <= 1.5 + 1e-9 and Lz.epaisseur >= ep, "age " .. e .. " : faisceau du laser, epaisseur croissante <= 1,5", Lz and Lz.epaisseur)
  if Lz then ep = Lz.epaisseur end
end
check(T.ages[1].laser == nil, "age 1 : laser vanilla (faisceau rouge)")

-- 2. sons : couches ajoutées, vitesse DANS chaque variation (jamais sur la couche), volumes plafonnés, aggregation
for _, e in ipairs({ 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 }) do
  local c = T.ages[e].son and T.ages[e].son.couches
  check(c and #c >= 1, "age " .. e .. " : couches de son ajoutees")
  for _, x in ipairs(c or {}) do
    check(x.volume <= 0.5 and x.max <= 3, "age " .. e .. " : couche plafonnee (volume <= 0,5, max <= 3)", x.volume)
    for _, f in ipairs(R.fichiers(x.fichiers)) do
      check(f:match("^__base__/sound/fight/[%w%-]+%.ogg$") ~= nil, "son vanilla reference " .. f)
    end
  end
  local s0 = { { filename = "s0-1.ogg", volume = 0.4 }, { filename = "s0-2.ogg", volume = 0.4 } }
  local snd = K.son_tir(s0, T.ages[e])
  check(snd.layers and #snd.layers == 1 + #c and snd.layers[1].variations == s0, "age " .. e .. " : S0 en 1re couche")
  local bonne = true
  for k = 2, #snd.layers do
    local l, cc = snd.layers[k], c[k - 1]
    if l.min_speed or l.max_speed or l.speed or l.volume then bonne = false end
    for _, v in ipairs(l.variations) do
      if cc.vitesse and (v.min_speed ~= cc.vitesse[1] or v.max_speed ~= cc.vitesse[2]) then bonne = false end
      if v.volume ~= cc.volume then bonne = false end
    end
    if not (l.aggregation and l.aggregation.max_count == cc.max) then bonne = false end
  end
  check(bonne, "age " .. e .. " : vitesse et volume dans chaque variation, rien d'ignore sur la couche")
end
for _, e in ipairs({ 1, 2, 3 }) do
  check(T.ages[e].son == nil and K.son_tir({ "x" }, T.ages[e])[1] == "x", "age " .. e .. " : son S0 inchange (ere I)")
end
-- D-21 : plus grave aux âges hauts : la vitesse de lecture de la couche la plus grave baisse d'un âge à l'autre dès l'âge 8
do
  local prec = 9
  for _, e in ipairs({ 8, 9, 10, 11, 12, 13, 14, 15 }) do
    local mn = 9
    for _, c in ipairs(T.ages[e].son.couches) do if c.vitesse and c.vitesse[1] < mn then mn = c.vitesse[1] end end
    check(mn <= prec + 1e-9, "age " .. e .. " : couche la plus grave (vitesse " .. mn .. ") non plus aigue que l'age precedent", mn)
    prec = mn
  end
  check(prec <= 0.45, "age 15 : une couche a 0,45 de vitesse ou moins (plus d'une octave sous l'origine)", prec)
end

-- 3. accumulateur : a sur b exactement, sans ordre ni hasard
for _, p in ipairs({ { 2, 5 }, { 1, 2 }, { 2, 3 }, { 1, 1 }, { 1, 7 } }) do
  local c, n, last, maxgap = 0, 0, 0, 0
  for i = 1, 1000 * p[2] do
    local g
    g, c = R.garder(c, p)
    if g then
      n = n + 1
      maxgap = math.max(maxgap, i - last)
      last = i
    end
  end
  check(n == 1000 * p[1], "garder " .. p[1] .. "/" .. p[2] .. " : exact", n)
  check(maxgap <= math.ceil(p[2] / p[1]), "garder " .. p[1] .. "/" .. p[2] .. " : regulier (ecart max)", maxgap)
end
-- 4. plafond par tick
local etat = { tick = -1, n = 0 }
local passes = 0
for _ = 1, 10 do if R.plafond(etat, 100, 6) then passes = passes + 1 end end
check(passes == 6, "plafond : 6 tirs par tick", passes)
check(R.plafond(etat, 101, 6), "plafond : remis a zero au tick suivant")

-- 5. proximité (Tchebychev, même surface ; aucun joueur : pas de filtre)
check(R.proche(nil, 1, 5000, 5000, 96), "proche : relevé absent -> pas de filtre")
check(R.proche({}, 1, 5000, 5000, 96), "proche : aucun joueur connecte -> pas de filtre")
local J = { { s = 1, x = 0, y = 0 } }
check(R.proche(J, 1, 96, -96, 96), "proche : coin a 96 tuiles")
check(not R.proche(J, 1, 96.5, 0, 96), "proche : 96,5 tuiles a l'est -> loin")
check(not R.proche(J, 1, 0, -97, 96), "proche : 97 tuiles au nord -> loin")
check(not R.proche(J, 2, 0, 0, 96), "proche : autre surface -> loin")
check(R.proche({ { s = 2, x = 0, y = 0 }, { s = 1, x = 500, y = 0 } }, 1, 450, 10, 96), "proche : 2e joueur")

-- 6. décision sur une VOLÉE : 20 tourelles par âge témoin tirent au même tick toutes les 6 ticks, un événement sur
-- deux (probabilité 0,5 du moteur, ici déterministe), dans les deux ordres de mise à jour. Avec plafond >= somme des
-- quotas, chaque âge reçoit exactement son quota par volée, quel que soit l'ordre.
local function volee(Tab, ordre, proche_fn)
  local et = { cpt = {}, quota = {}, plafond = { tick = -1, n = 0 } }
  local res = {}
  for _, e in ipairs(Tab.temoins) do res[e] = { evts = 0, garde = 0, part = 0, quota = 0, plafond = 0, loin = 0 } end
  local tirs = {}
  for _, e in ipairs(ordre) do for k = 1, 20 do tirs[#tirs + 1] = { e = e, k = k } end end
  local volees = 0
  for tick = 0, 599, 6 do
    volees = volees + 1
    for i, t in ipairs(tirs) do
      if (i + tick / 6) % 2 == 0 then -- un tir sur deux lève l'événement
        local r = res[t.e]
        r.evts = r.evts + 1
        local d = R.decider(et, t.e, tick, Tab.ages[t.e], Tab, proche_fn == nil or proche_fn(t))
        r[d] = r[d] + 1
      end
    end
  end
  return res, volees
end
local function cmp(a, b)
  for _, e in ipairs(T.temoins) do if a[e].garde ~= b[e].garde then return false end end
  return true
end
local monte, descend = {}, {}
for i, e in ipairs(T.temoins) do monte[i] = e; descend[#T.temoins + 1 - i] = e end
local r1, nv = volee(T, monte)
local r2 = volee(T, descend)
check(cmp(r1, r2), "volee de 100 tourelles : memes tirs habilles par age dans les deux ordres")
local txt = {}
for _, e in ipairs(T.temoins) do
  local q = T.ages[e].quota
  check(r1[e].garde == q * nv, "volee : age " .. e .. " recoit son quota a chaque volee (" .. q .. " x " .. nv .. ")",
    r1[e].garde)
  check(r1[e].plafond == 0 and r2[e].plafond == 0, "volee : age " .. e .. " jamais refuse par le plafond commun")
  txt[#txt + 1] = string.format("age %d %d/%d", e, r1[e].garde, r1[e].evts)
end
print("  volee (habilles / evenements) : " .. table.concat(txt, ", "))
-- mutant : plafond sous la somme des quotas -> l'ordre décide (et la table est refusée)
local Tm = copie(T)
Tm.plafond_tick = 6
local m1 = volee(Tm, monte)
local m2 = volee(Tm, descend)
check(not cmp(m1, m2), "mutant plafond 6 < somme des quotas : l'ordre de mise a jour change les ages habilles")
check(#R.verifier_ages(Tm) > 0, "mutant plafond 6 < somme des quotas : table refusee")
-- proximité : une tourelle loin n'avance pas l'accumulateur de son âge (la part des tourelles proches reste exacte)
local rl = volee(T, monte, function(t) return t.k <= 10 end)
local loin_ok = true
for _, e in ipairs(T.temoins) do if rl[e].loin == 0 or rl[e].garde == 0 then loin_ok = false end end
check(loin_ok, "volee avec 10 tourelles loin par age : refusees 'loin', les proches habillees")
do
  local et = { cpt = {}, quota = {}, plafond = { tick = -1, n = 0 } }
  local A = T.ages[1]
  for _ = 1, 7 do R.decider(et, 1, 0, A, T, false) end
  check(et.cpt[1] == nil, "loin : l'accumulateur de l'age n'avance pas")
  local g = 0
  for tick = 1, 5 do if R.decider(et, 1, tick, A, T, true) == "garde" then g = g + 1 end end
  check(g == 2, "apres des tirs loin, la part reste a/b (2 sur 5)", g)
end

-- 7. décalage d'animation : image 0 au tick de création
for _, c in ipairs({ { 0, 0.5, 3 }, { 12345, 0.4995, 3 }, { 99999, 0.999, 7 }, { 7, 1.166, 7 } }) do
  local o = R.decalage(c[1], c[2], c[3])
  local img = math.floor(c[1] * c[2] + o + 1e-9) % c[3]
  check(img == 0 and o >= 0 and o < c[3], "decalage : image 0 au tick " .. c[1], img)
end

-- 8. garde : prototypes sans jeu (témoins acceptés, mutants refusés)
local permis = { ["fo-tir-15-impact-1"] = true, ["fo-tir-15-impact-1-etincelle"] = true }
local trace = { type = "projectile", name = "fo-tir-15-trace", acceleration = 0,
  action = { type = "direct", action_delivery = { type = "instant", target_effects = {
    { type = "create-explosion", entity_name = "fo-tir-15-impact-1" } } } } }
local expl = { type = "explosion", name = "fo-tir-15-impact-1", created_effect = { type = "direct",
  action_delivery = { type = "instant", target_effects = { { type = "create-particle",
    particle_name = "fo-tir-15-impact-1-etincelle", initial_height = 1 } } } } }
local trait = { type = "beam", name = "fo-tir-15-trait" }
check(R.verifier_prototype(trace, permis) == nil, "temoin : traçante sans degats acceptee")
check(R.verifier_prototype({ type = "projectile", name = "fo-tir-15-dard", acceleration = 0 }, permis) == nil,
  "temoin : dard sans action accepte")
check(R.verifier_prototype(expl, permis) == nil, "temoin : explosion a etincelles acceptee")
check(R.verifier_prototype(trait, permis) == nil, "temoin : trait sans action accepte")
check(R.verifier_prototype({ type = "trivial-smoke", name = "f" }, permis) == nil, "temoin : fumee acceptee")
check(R.verifier_prototype({ type = "animation", name = "fo-tir-15-bouche-1" }, permis) == nil,
  "temoin : flamme (animation) acceptee")

local mutants = {
  { "traçante qui blesse", function(p) table.insert(p.action.action_delivery.target_effects,
      { type = "damage", damage = { amount = 5, type = "physical" } }) end, trace },
  { "traçante a nested-result", function(p) p.action.action_delivery.target_effects[1] = { type = "nested-result",
      action = {} } end, trace },
  { "traçante qui cree une entite de jeu", function(p) p.action.action_delivery.target_effects[1] = {
      type = "create-entity", entity_name = "fire-flame" } end, trace },
  { "traçante qui cree une explosion hors liste", function(p)
      p.action.action_delivery.target_effects[1].entity_name = "explosion" end, trace },
  { "traçante a zone", function(p) p.action.type = "area" end, trace },
  { "traçante a livraison projectile", function(p) p.action.action_delivery.type = "projectile" end, trace },
  { "traçante a final_action", function(p) p.final_action = { type = "direct" } end, trace },
  { "traçante perforante", function(p) p.piercing_damage = 100 end, trace },
  { "traçante qui touche (collision_box)", function(p) p.collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } } end, trace },
  { "traçante qui pousse (push-back)", function(p) p.action.action_delivery.target_effects[1] = { type = "push-back",
      distance = 2 } end, trace },
  { "traçante qui colle (sticker)", function(p) p.action.action_delivery.target_effects[1] = {
      type = "create-sticker", sticker = "slowdown-sticker" } end, trace },
  { "traçante a effet script", function(p) p.action.action_delivery.target_effects[1] = { type = "script",
      effect_id = "x" } end, trace },
  { "explosion qui blesse", function(p) p.created_effect.action_delivery.target_effects[1] = { type = "damage",
      damage = { amount = 5, type = "fire" } } end, expl },
  { "explosion a feu", function(p) p.created_effect.action_delivery.target_effects[1] = { type = "create-fire",
      entity_name = "fire-flame" } end, expl },
  { "trait avec action", function(p) p.action = { type = "direct" } end, trait },
  { "type hors lot", function(p) p.type = "sticker" end, trait },
  { "particule a effet au sol", function(p) p.type = "optimized-particle"; p.ended_on_ground_trigger_effect = {
      type = "damage" } end, trait },
}
for _, mu in ipairs(mutants) do
  local p = copie(mu[3])
  mu[2](p)
  check(R.verifier_prototype(p, permis) ~= nil, "mutant refuse : " .. mu[1])
end

local mutants_ages = {
  { "part a > b", function(t) t.ages[5].part = { 3, 2 } end },
  { "part non entiere", function(t) t.ages[5].part = { 0.5, 1 } end },
  { "bouche vide", function(t) t.ages[10].bouche = {} end },
  { "impact vide", function(t) t.ages[10].impact = {} end },
  { "trace absente", function(t) t.ages[8].trace = nil end },
  { "anim inconnue", function(t) t.ages[15].bouche[1].anim = "rien" end },
  { "variation inconnue", function(t) t.ages[1].bouche[1].variation = 9 end },
  { "flamme basse definition x3 (tache floue)", function(t) t.ages[10].bouche[2].longueur = 3.0 end },
  { "flamme basse definition x2 en largeur", function(t) t.ages[10].bouche[1].largeur = 2.0 end },
  { "impact tourne (gerbe verticale)", function(t) t.ages[15].impact[1].tourne = true end },
  { "image d'impact inconnue", function(t) t.ages[8].impact[1].image = "rien" end },
  { "source et image", function(t) t.ages[8].impact[1].source = "explosion" end },
  { "traçante trop lente", function(t) t.ages[1].trace.vitesse = 0.3 end },
  { "dernier dard sous 1 tuile/tick", function(t) t.ages[10].trace.ralenti = 0.5 end },
  { "trait trop long", function(t) t.ages[15].trait.duree = 5 end },
  { "trait trop epais", function(t) t.ages[15].trait.epaisseur = 2.5 end },
  { "trait = faisceau du laser 15", function(t)
      t.ages[15].trait.epaisseur = 1.0; t.ages[15].laser.epaisseur = 1.0
      t.ages[15].trait.teinte = copie(t.ages[15].laser.teinte) end },
  { "teinte hors [0, 1]", function(t) t.ages[5].bouche[1].teinte = { 2, 0, 0 } end },
  { "son trop fort", function(t) t.ages[15].son.couches[1].volume = 1.5 end },
  { "son sans aggregation", function(t) t.ages[15].son.couches[1].max = nil end },
  { "son a vitesse < 1/64", function(t) t.ages[15].son.couches[1].vitesse = { 0.01, 0.02 } end },
  { "age hors liste des temoins", function(t) t.ages[16] = copie(t.ages[5]) end },
  { "frames non entier", function(t) t.ages[15].impact[1].frames = 2.5 end },
  { "probabilite nulle", function(t) t.probabilite = 0 end },
  { "quota absent", function(t) t.ages[10].quota = nil end },
  { "quota nul", function(t) t.ages[15].quota = 0 end },
  { "plafond sous la somme des quotas", function(t) t.plafond_tick = 23 end },
  { "proximite nulle", function(t) t.proximite = 0 end },
  { "lumiere de bouche sans duree", function(t) t.ages[5].lumiere.duree = nil end },
}
for _, mu in ipairs(mutants_ages) do
  local t = copie(T)
  mu[2](t)
  check(#R.verifier_ages(t) > 0, "mutant de la table refuse : " .. mu[1])
end

-- 8 bis. K9 hors jeu : la règle de la table des dégâts (shared/tirs/degats.lua), 8 mutants refusés
do
  local D = require("shared.tirs.degats")
  local m0 = D.verifier(D.par_niveau)
  check(#m0 == 0, "degats par niveau : table livree acceptee", table.concat(m0, " ; "))
  local muts = {
    { "niveau 1 change", function(t) t[1] = 1.1 end },
    { "une baisse au niveau 14", function(t) t[14] = t[13] - 0.01 end },
    { "deux niveaux egaux", function(t) t[20] = t[19] end },
    { "niveau 6 change (jeu d'avant)", function(t) t[6] = 1.5 end },
    { "age 8 trop faible (rapport 1,05)", function(t) t[16] = t[14] * 1.05 end },
    { "age 15 trop fort (rapport 1,2)", function(t) t[30] = t[28] * 1.2 end },
    { "x 1,1 par age (variante ecartee le 28/10 soir)", function(t)
        local v = { 1.47, 1.54, 1.62, 1.69, 1.78, 1.86, 1.95, 2.05, 2.15, 2.25, 2.36, 2.48, 2.60, 2.73, 2.86, 3.00, 3.15,
          3.30, 3.46, 3.63, 3.81, 3.99, 4.19, 4.39 }
        for i, x in ipairs(v) do t[6 + i] = x end end },
    { "l'ancien x 1,2 par age (D-21 avant le 28/10 soir)", function(t)
        local v = { 1.53, 1.68, 1.84, 2.02, 2.21, 2.42, 2.65, 2.90, 3.18, 3.48, 3.82, 4.18, 4.58, 5.02, 5.50, 6.02, 6.59,
          7.22, 7.91, 8.67, 9.50, 10.40, 11.39, 12.48 }
        for i, x in ipairs(v) do t[6 + i] = x end end },
    { "29 entrees", function(t) t[30] = nil end },
    { "niveau non numerique", function(t) t[12] = "2,42" end },
    { "plus 2 % par age (le jeu d'avant D-21)", function(t)
        for n = 7, 30 do t[n] = 1.4 + 0.02 * (n - 6) end end },
  }
  for _, mu in ipairs(muts) do
    local t = copie(D.par_niveau)
    mu[2](t)
    check(#D.verifier(t) > 0, "mutant refuse (degats) : " .. mu[1])
  end
end

-- 9. noms
check(R.nom(T, 5, "bouche", 1) == "fo-tir-05-bouche-1" and R.nom(T, 15, "trace") == "fo-tir-15-trace", "noms du lot")

print(string.format("[TIRS] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
